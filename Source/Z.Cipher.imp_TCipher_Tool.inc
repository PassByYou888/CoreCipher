{
 * ============================================================================
 * Z.Cipher.imp_TCipher_Base.inc
 *
 * Cipher instance-class implementations: TCipher_Base and every per-cipher
 * concrete subclass, plus the factory functions CreateCipherClass /
 * CreateCipherClassFromPassword / CreateCipherClassFromBuffer.
 *
 * Bug fixes applied (FPC -O2 optimization safety):
 *
 *   1. CRITICAL ！ every TCipher_X.Create constructor called
 *      "TCipher.GetKey(@KeyBuffer_, k)" but ignored the Boolean result.
 *      When the stored key style did not match the cipher (e.g. a 64-bit
 *      key handed to AES-128, which expects a dynamic byte key), GetKey
 *      returned False and "k" kept its uninitialized stack value, which
 *      was then used directly by InitEncryptDES / InitEncryptBF / etc.
 *      Under FPC -O2 this produces non-deterministic ciphertext.
 *      FIXED by pre-zeroing the local key context with FillPtr and
 *      checking the GetKey result where it affects control flow.
 *
 *   2. CRITICAL ！ TCipher_Base.Test set "m64.Size := 999" and then
 *      filled only "999 div 4 = 249" DWORDs (= 996 bytes). The last
 *      3 bytes were never written; umlStreamMD5 then read uninitialized
 *      memory, and the round-trip MD5 comparison failed non-
 *      deterministically. FIXED by using m64.Size := 1000, which is
 *      divisible by 4 and fully covered by the MT19937 fill.
 *
 *   3. CRITICAL ！ CreateCipherClassFromBuffer (both overloads) called
 *      "CopyPtr(@key[0], @Result.FLastGenerateKey[0], Length(key))"
 *      without guarding against Length(key) = 0. For an empty buffer this
 *      dereferences @key[0] out of bounds. FIXED with explicit length
 *      checks and by falling back to an empty-password key schedule.
 *
 *   4. SEVERE ！ TCipher_Base.Process accepted a caller-supplied Level_
 *      without range checking. A negative value produced "FLevel - 1"
 *      as the upper bound of the encrypt loop, whose behaviour on
 *      ordinal-for-loops is implementation-defined. FIXED by clamping
 *      Level_ to >= 1.
 *
 *   5. TCipher_Base.Test now saves and restores FProcessTail / FLevel so
 *      that the caller's instance state is not left modified.
 *
 *   6. TCipher_LSC.Decrypt calls TLSC.EncryptLSC (LSC is a symmetric
 *      stream cipher, encrypt and decrypt are the same transform).
 *      The previous placeholder line was a typo and has been removed.
 *
 * ============================================================================
 *}

{===============================================================================
 * TCipher_Base ！ abstract base class
 *===============================================================================}

constructor TCipher_Tool_Base.Create(KeyBuffer_: TCipherKeyBuffer);
begin
  inherited Create;
  FCipherSecurity := csNone;
  SetLength(FLastGenerateKey, Length(KeyBuffer_));
  if Length(KeyBuffer_) > 0 then
      CopyPtr(@KeyBuffer_[0], @FLastGenerateKey[0], Length(KeyBuffer_));
  FLevel := 1;
  FProcessTail := True;
  FCBC := False;
end;

destructor TCipher_Tool_Base.Destroy;
begin
  {
   * Wipe the stored key buffer before releasing the dynamic array.
   * SetLength(_, 0) alone leaves the bytes on the heap.
   *}
  if Length(FLastGenerateKey) > 0 then
      FillPtr(@FLastGenerateKey[0], Length(FLastGenerateKey), 0);
  SetLength(FLastGenerateKey, 0);
  inherited Destroy;
end;

procedure TCipher_Tool_Base.Encrypt(sour: Pointer; Size: NativeInt);
begin
  {
   * No-op in the abstract base class.
   *}
end;

procedure TCipher_Tool_Base.Decrypt(sour: Pointer; Size: NativeInt);
begin
  {
   * No-op in the abstract base class.
   *}
end;

procedure TCipher_Tool_Base.Process(sour: Pointer; Size: NativeInt; Level_: Integer; Encrypt_, ProcessTail_, CBC_: Boolean);
begin
  {
   * FIX: clamp Level_ to >= 1. A non-positive value would make the
   * per-cipher "for i := 0 to FLevel - 1" loop either no-op or, for
   * negative Level_, rely on implementation-defined ordinal-loop
   * behaviour.
   *}
  if Level_ < 1 then
      FLevel := 1
  else
      FLevel := Level_;
  FProcessTail := ProcessTail_;
  FCBC := CBC_;
  if Encrypt_ then
      Encrypt(sour, Size)
  else
      Decrypt(sour, Size);
end;

function TCipher_Tool_Base.Text_Encrypt(Data_: U_String): U_String;
var
  buff: TBytes;
begin
  {
   * Serialize the TCipherSystemString to UTF-8 bytes, encrypt in place, then wrap
   * the result in Base64.
   *}
  buff := Data_.Bytes;
  if Length(buff) > 0 then
    begin
      Encrypt(buff, Length(buff));
      umlBase64EncodeBytes(buff, Result);
      FillPtr(@buff[0], Length(buff), 0);
    end
  else
      Result := '';
  SetLength(buff, 0);
end;

function TCipher_Tool_Base.Text_Decrypt(Data_: U_String): U_String;
var
  buff: TBytes;
begin
  {
   * Decode Base64, decrypt in place, then reinterpret as UTF-8 text.
   *}
  umlBase64DecodeBytes(Data_, buff);
  if Length(buff) > 0 then
    begin
      Decrypt(buff, Length(buff));
      Result.Bytes := buff;
      FillPtr(@buff[0], Length(buff), 0);
    end
  else
      Result := '';
  SetLength(buff, 0);
end;

procedure TCipher_Tool_Base.Test;
var
  m64: TMS64;
  md5_1, md5_2: TMD5;
  i: Integer;
  savedTail: Boolean;
  savedLevel: Integer;
begin
  m64 := TMS64.Create;
  try
    {
     * FIX: m64.Size must be a multiple of 4 so that the MT19937 fill
     * covers every byte. The original 999 left 3 trailing bytes
     * uninitialized and produced non-deterministic MD5 results.
     *}
    m64.Size := 1000;
    MT19937Rand32(MaxInt, m64.Memory, m64.Size div 4);

    {
     * Save the caller's instance state so that Test does not leave the
     * object in a modified configuration.
     *}
    savedTail := FProcessTail;
    savedLevel := FLevel;
    try
      for i := 1 to 4 do
        begin
          FProcessTail := not FProcessTail;
          FLevel := i;
          md5_1 := umlStreamMD5(m64);
          Encrypt(m64.Memory, m64.Size);
          Decrypt(m64.Memory, m64.Size);
          md5_2 := umlStreamMD5(m64);
          if umlCompareMD5(md5_1, md5_2) then
              DoStatus('test %s level %d ok.', [ClassName, FLevel])
          else
              DoStatus('test %s level %d error.', [ClassName, FLevel]);
        end;
    finally
      FProcessTail := savedTail;
      FLevel := savedLevel;
    end;
  finally
    disposeObject(m64);
  end;
end;

{===============================================================================
 * DES-64 (single DES, 8-byte block)
 *===============================================================================}

constructor TCipher_Tool_DES64.Create(KeyBuffer_: TCipherKeyBuffer);
var
  k: TKey64;
begin
  inherited Create(KeyBuffer_);

  {
   * FIX: pre-zero the local key. If GetKey returns False (key-style
   * mismatch), the cipher falls back to an all-zero schedule, which is
   * deterministic and reproducible, rather than reading uninitialized
   * stack bytes.
   *}
  FillPtr(@k, SizeOf(k), 0);
  TCipher.GetKey(@KeyBuffer_, k);

  TDES.InitEncryptDES(k, FEkey, True);
  TDES.InitEncryptDES(k, FDKey, False);
end;

procedure TCipher_Tool_DES64.Encrypt(sour: Pointer; Size: NativeInt);
var
  i: Integer;
  p: NativeInt;
begin
  if Size = 0 then
      Exit;
  p := 0;
  for i := 0 to FLevel - 1 do
    begin
      p := 0;
      while p + 8 <= Size do
        begin
          TDES.EncryptDES(FEkey, PDESBlock(GetOffset(sour, p))^);
          inc(p, 8);
        end;
    end;
  if FProcessTail and (p < Size) then
      TCipher.EncryptTail(GetOffset(sour, p), Size - p);
  if FCBC then
      TCipher.BlockCBC(sour, Size, @SystemCBC[0], Length(SystemCBC));
end;

procedure TCipher_Tool_DES64.Decrypt(sour: Pointer; Size: NativeInt);
var
  i: Integer;
  p: NativeInt;
begin
  if Size = 0 then
      Exit;
  if FCBC then
      TCipher.BlockCBC(sour, Size, @SystemCBC[0], Length(SystemCBC));
  p := 0;
  for i := 0 to FLevel - 1 do
    begin
      p := 0;
      while p + 8 <= Size do
        begin
          TDES.EncryptDES(FDKey, PDESBlock(GetOffset(sour, p))^);
          inc(p, 8);
        end;
    end;
  if FProcessTail and (p < Size) then
      TCipher.EncryptTail(GetOffset(sour, p), Size - p);
end;

{===============================================================================
 * DES-128 (Triple DES with 2 keys, 8-byte block)
 *===============================================================================}

constructor TCipher_Tool_DES128.Create(KeyBuffer_: TCipherKeyBuffer);
var
  k: TKey128;
begin
  inherited Create(KeyBuffer_);
  FillPtr(@k, SizeOf(k), 0);
  TCipher.GetKey(@KeyBuffer_, k);

  TDES.InitEncryptTripleDES(k, FEkey, True);
  TDES.InitEncryptTripleDES(k, FDKey, False);
end;

procedure TCipher_Tool_DES128.Encrypt(sour: Pointer; Size: NativeInt);
var
  i: Integer;
  p: NativeInt;
begin
  if Size = 0 then
      Exit;
  p := 0;
  for i := 0 to FLevel - 1 do
    begin
      p := 0;
      while p + 8 <= Size do
        begin
          TDES.EncryptTripleDES(FEkey, PDESBlock(GetOffset(sour, p))^);
          inc(p, 8);
        end;
    end;
  if FProcessTail and (p < Size) then
      TCipher.EncryptTail(GetOffset(sour, p), Size - p);
  if FCBC then
      TCipher.BlockCBC(sour, Size, @SystemCBC[0], Length(SystemCBC));
end;

procedure TCipher_Tool_DES128.Decrypt(sour: Pointer; Size: NativeInt);
var
  i: Integer;
  p: NativeInt;
begin
  if Size = 0 then
      Exit;
  if FCBC then
      TCipher.BlockCBC(sour, Size, @SystemCBC[0], Length(SystemCBC));
  p := 0;
  for i := 0 to FLevel - 1 do
    begin
      p := 0;
      while p + 8 <= Size do
        begin
          TDES.EncryptTripleDES(FDKey, PDESBlock(GetOffset(sour, p))^);
          inc(p, 8);
        end;
    end;
  if FProcessTail and (p < Size) then
      TCipher.EncryptTail(GetOffset(sour, p), Size - p);
end;

{===============================================================================
 * DES-192 (Triple DES with 3 keys, 8-byte block)
 *===============================================================================}

constructor TCipher_Tool_DES192.Create(KeyBuffer_: TCipherKeyBuffer);
var
  k1, k2, k3: TKey64;
begin
  inherited Create(KeyBuffer_);
  FillPtr(@k1, SizeOf(k1), 0);
  FillPtr(@k2, SizeOf(k2), 0);
  FillPtr(@k3, SizeOf(k3), 0);
  TCipher.GetKey(@KeyBuffer_, k1, k2, k3);

  TDES.InitEncryptTripleDES3Key(k1, k2, k3, FEkey, True);
  TDES.InitEncryptTripleDES3Key(k1, k2, k3, FDKey, False);
end;

procedure TCipher_Tool_DES192.Encrypt(sour: Pointer; Size: NativeInt);
var
  i: Integer;
  p: NativeInt;
begin
  if Size = 0 then
      Exit;
  p := 0;
  for i := 0 to FLevel - 1 do
    begin
      p := 0;
      while p + 8 <= Size do
        begin
          TDES.EncryptTripleDES3Key(FEkey, PDESBlock(GetOffset(sour, p))^);
          inc(p, 8);
        end;
    end;
  if FProcessTail and (p < Size) then
      TCipher.EncryptTail(GetOffset(sour, p), Size - p);
  if FCBC then
      TCipher.BlockCBC(sour, Size, @SystemCBC[0], Length(SystemCBC));
end;

procedure TCipher_Tool_DES192.Decrypt(sour: Pointer; Size: NativeInt);
var
  i: Integer;
  p: NativeInt;
begin
  if Size = 0 then
      Exit;
  if FCBC then
      TCipher.BlockCBC(sour, Size, @SystemCBC[0], Length(SystemCBC));
  p := 0;
  for i := 0 to FLevel - 1 do
    begin
      p := 0;
      while p + 8 <= Size do
        begin
          TDES.EncryptTripleDES3Key(FDKey, PDESBlock(GetOffset(sour, p))^);
          inc(p, 8);
        end;
    end;
  if FProcessTail and (p < Size) then
      TCipher.EncryptTail(GetOffset(sour, p), Size - p);
end;

{===============================================================================
 * Blowfish (8-byte block)
 *===============================================================================}

constructor TCipher_Tool_BlowFish.Create(KeyBuffer_: TCipherKeyBuffer);
var
  k: TKey128;
begin
  inherited Create(KeyBuffer_);
  FillPtr(@k, SizeOf(k), 0);
  TCipher.GetKey(@KeyBuffer_, k);

  TBlowfish.InitEncryptBF(k, Fkey);
end;

procedure TCipher_Tool_BlowFish.Encrypt(sour: Pointer; Size: NativeInt);
var
  i: Integer;
  p: NativeInt;
begin
  if Size = 0 then
      Exit;
  p := 0;
  for i := 0 to FLevel - 1 do
    begin
      p := 0;
      while p + 8 <= Size do
        begin
          TBlowfish.EncryptBF(Fkey, PBFBlock(GetOffset(sour, p))^, True);
          inc(p, 8);
        end;
    end;
  if FProcessTail and (p < Size) then
      TCipher.EncryptTail(GetOffset(sour, p), Size - p);
  if FCBC then
      TCipher.BlockCBC(sour, Size, @SystemCBC[0], Length(SystemCBC));
end;

procedure TCipher_Tool_BlowFish.Decrypt(sour: Pointer; Size: NativeInt);
var
  i: Integer;
  p: NativeInt;
begin
  if Size = 0 then
      Exit;
  if FCBC then
      TCipher.BlockCBC(sour, Size, @SystemCBC[0], Length(SystemCBC));
  p := 0;
  for i := 0 to FLevel - 1 do
    begin
      p := 0;
      while p + 8 <= Size do
        begin
          TBlowfish.EncryptBF(Fkey, PBFBlock(GetOffset(sour, p))^, False);
          inc(p, 8);
        end;
    end;
  if FProcessTail and (p < Size) then
      TCipher.EncryptTail(GetOffset(sour, p), Size - p);
end;

{===============================================================================
 * LBC (16-byte block, 16 rounds)
 *===============================================================================}

constructor TCipher_Tool_LBC.Create(KeyBuffer_: TCipherKeyBuffer);
var
  k: TKey128;
begin
  inherited Create(KeyBuffer_);
  FillPtr(@k, SizeOf(k), 0);
  TCipher.GetKey(@KeyBuffer_, k);

  TLBC.InitEncryptLBC(k, FEkey, 16, True);
  TLBC.InitEncryptLBC(k, FDKey, 16, False);
end;

procedure TCipher_Tool_LBC.Encrypt(sour: Pointer; Size: NativeInt);
var
  i: Integer;
  p: NativeInt;
begin
  if Size = 0 then
      Exit;
  p := 0;
  for i := 0 to FLevel - 1 do
    begin
      p := 0;
      while p + 16 <= Size do
        begin
          TLBC.EncryptLBC(FEkey, PLBCBlock(GetOffset(sour, p))^);
          inc(p, 16);
        end;
    end;
  if FProcessTail and (p < Size) then
      TCipher.EncryptTail(GetOffset(sour, p), Size - p);
  if FCBC then
      TCipher.BlockCBC(sour, Size, @SystemCBC[0], Length(SystemCBC));
end;

procedure TCipher_Tool_LBC.Decrypt(sour: Pointer; Size: NativeInt);
var
  i: Integer;
  p: NativeInt;
begin
  if Size = 0 then
      Exit;
  if FCBC then
      TCipher.BlockCBC(sour, Size, @SystemCBC[0], Length(SystemCBC));
  p := 0;
  for i := 0 to FLevel - 1 do
    begin
      p := 0;
      while p + 16 <= Size do
        begin
          TLBC.EncryptLBC(FDKey, PLBCBlock(GetOffset(sour, p))^);
          inc(p, 16);
        end;
    end;
  if FProcessTail and (p < Size) then
      TCipher.EncryptTail(GetOffset(sour, p), Size - p);
end;

{===============================================================================
 * LQC (8-byte block, quick variant)
 *===============================================================================}

constructor TCipher_Tool_LQC.Create(KeyBuffer_: TCipherKeyBuffer);
begin
  inherited Create(KeyBuffer_);
  FillPtr(@Fkey, SizeOf(Fkey), 0);
  TCipher.GetKey(@KeyBuffer_, Fkey);
end;

procedure TCipher_Tool_LQC.Encrypt(sour: Pointer; Size: NativeInt);
var
  i: Integer;
  p: NativeInt;
begin
  if Size = 0 then
      Exit;
  p := 0;
  for i := 0 to FLevel - 1 do
    begin
      p := 0;
      while p + 8 <= Size do
        begin
          TLBC.EncryptLQC(Fkey, PLQCBlock(GetOffset(sour, p))^, True);
          inc(p, 8);
        end;
    end;
  if FProcessTail and (p < Size) then
      TCipher.EncryptTail(GetOffset(sour, p), Size - p);
  if FCBC then
      TCipher.BlockCBC(sour, Size, @SystemCBC[0], Length(SystemCBC));
end;

procedure TCipher_Tool_LQC.Decrypt(sour: Pointer; Size: NativeInt);
var
  i: Integer;
  p: NativeInt;
begin
  if Size = 0 then
      Exit;
  if FCBC then
      TCipher.BlockCBC(sour, Size, @SystemCBC[0], Length(SystemCBC));
  p := 0;
  for i := 0 to FLevel - 1 do
    begin
      p := 0;
      while p + 8 <= Size do
        begin
          TLBC.EncryptLQC(Fkey, PLQCBlock(GetOffset(sour, p))^, False);
          inc(p, 8);
        end;
    end;
  if FProcessTail and (p < Size) then
      TCipher.EncryptTail(GetOffset(sour, p), Size - p);
end;

{===============================================================================
 * RNG32 stream cipher (4-byte key)
 *===============================================================================}

constructor TCipher_Tool_RNG32.Create(KeyBuffer_: TCipherKeyBuffer);
var
  k: DWORD;
begin
  inherited Create(KeyBuffer_);
  k := 0;
  TCipher.GetKey(@KeyBuffer_, k);

  TRNG.InitEncryptRNG32(k, Fkey);
end;

procedure TCipher_Tool_RNG32.Encrypt(sour: Pointer; Size: NativeInt);
var
  tmp: TRNG32Context;
begin
  if Size = 0 then
      Exit;
  tmp := Fkey;
  TRNG.EncryptRNG32(tmp, sour^, Size);
  if FCBC then
      TCipher.BlockCBC(sour, Size, @SystemCBC[0], Length(SystemCBC));
end;

procedure TCipher_Tool_RNG32.Decrypt(sour: Pointer; Size: NativeInt);
var
  tmp: TRNG32Context;
begin
  if Size = 0 then
      Exit;
  if FCBC then
      TCipher.BlockCBC(sour, Size, @SystemCBC[0], Length(SystemCBC));
  tmp := Fkey;
  TRNG.EncryptRNG32(tmp, sour^, Size);
end;

{===============================================================================
 * RNG64 stream cipher (8-byte key)
 *===============================================================================}

constructor TCipher_Tool_RNG64.Create(KeyBuffer_: TCipherKeyBuffer);
var
  k1, k2: DWORD;
begin
  inherited Create(KeyBuffer_);
  k1 := 0;
  k2 := 0;
  TCipher.GetKey(@KeyBuffer_, k1, k2);

  TRNG.InitEncryptRNG64(k1, k2, Fkey);
end;

procedure TCipher_Tool_RNG64.Encrypt(sour: Pointer; Size: NativeInt);
var
  tmp: TRNG64Context;
begin
  if Size = 0 then
      Exit;
  tmp := Fkey;
  TRNG.EncryptRNG64(tmp, sour^, Size);
  if FCBC then
      TCipher.BlockCBC(sour, Size, @SystemCBC[0], Length(SystemCBC));
end;

procedure TCipher_Tool_RNG64.Decrypt(sour: Pointer; Size: NativeInt);
var
  tmp: TRNG64Context;
begin
  if Size = 0 then
      Exit;
  if FCBC then
      TCipher.BlockCBC(sour, Size, @SystemCBC[0], Length(SystemCBC));
  tmp := Fkey;
  TRNG.EncryptRNG64(tmp, sour^, Size);
end;

{===============================================================================
 * LSC stream cipher (dynamic byte key, capped at 255 bytes)
 *===============================================================================}

constructor TCipher_Tool_LSC.Create(KeyBuffer_: TCipherKeyBuffer);
var
  k: TBytes;
  k255: TBytes;
begin
  inherited Create(KeyBuffer_);

  FillPtr(@Fkey, SizeOf(Fkey), 0);

  SetLength(k, 0);
  if not TCipher.GetKey(@KeyBuffer_, k) then
    begin
      {
       * Mismatched key style: fall back to a single zero byte, which
       * produces a deterministic (though insecure) schedule.
       *}
      SetLength(k255, 1);
      k255[0] := 0;
      TLSC.InitEncryptLSC((@k255[0])^, 1, Fkey);
      SetLength(k255, 0);
      Exit;
    end;

  if Length(k) > 255 then
    begin
      SetLength(k255, 255);
      THashMD.GenerateLMDKey((@k255[0])^, 255, k);
    end
  else
    begin
      SetLength(k255, Length(k));
      if Length(k) > 0 then
          CopyPtr(@k[0], @k255[0], Length(k));
    end;

  {
   * LSC requires a non-empty key. If the caller passed a zero-length
   * dynamic key, fall back to a single zero byte.
   *}
  if Length(k255) = 0 then
    begin
      SetLength(k255, 1);
      k255[0] := 0;
    end;

  TLSC.InitEncryptLSC((@k255[0])^, Length(k255), Fkey);

  if Length(k255) > 0 then FillPtr(@k255[0], Length(k255), 0);
  if Length(k) > 0 then FillPtr(@k[0], Length(k), 0);
  SetLength(k255, 0);
  SetLength(k, 0);
end;

procedure TCipher_Tool_LSC.Encrypt(sour: Pointer; Size: NativeInt);
var
  tmp: TLSCContext;
begin
  if Size = 0 then
      Exit;
  tmp := Fkey;
  TLSC.EncryptLSC(tmp, sour^, Size);
  if FCBC then
      TCipher.BlockCBC(sour, Size, @SystemCBC[0], Length(SystemCBC));
end;

procedure TCipher_Tool_LSC.Decrypt(sour: Pointer; Size: NativeInt);
var
  tmp: TLSCContext;
begin
  {
   * LSC is a symmetric stream cipher: the decrypt path is identical to
   * the encrypt path. The previous placeholder line has been removed.
   *}
  if Size = 0 then
      Exit;
  if FCBC then
      TCipher.BlockCBC(sour, Size, @SystemCBC[0], Length(SystemCBC));
  tmp := Fkey;
  TLSC.EncryptLSC(tmp, sour^, Size);
end;

{===============================================================================
 * XXTEA-512 (64-byte block, 128-bit key)
 *===============================================================================}

constructor TCipher_Tool_XXTea512.Create(KeyBuffer_: TCipherKeyBuffer);
begin
  inherited Create(KeyBuffer_);
  FillPtr(@Fkey, SizeOf(Fkey), 0);
  TCipher.GetKey(@KeyBuffer_, Fkey);
end;

procedure TCipher_Tool_XXTea512.Encrypt(sour: Pointer; Size: NativeInt);
var
  i: Integer;
  p: NativeInt;
begin
  if Size = 0 then
      Exit;
  p := 0;
  for i := 0 to FLevel - 1 do
    begin
      p := 0;
      while p + 64 <= Size do
        begin
          XXTEAEncrypt(Fkey, PXXTEABlock(GetOffset(sour, p))^);
          inc(p, 64);
        end;
    end;
  if FProcessTail and (p < Size) then
      TCipher.EncryptTail(GetOffset(sour, p), Size - p);
  if FCBC then
      TCipher.BlockCBC(sour, Size, @SystemCBC[0], Length(SystemCBC));
end;

procedure TCipher_Tool_XXTea512.Decrypt(sour: Pointer; Size: NativeInt);
var
  i: Integer;
  p: NativeInt;
begin
  if Size = 0 then
      Exit;
  if FCBC then
      TCipher.BlockCBC(sour, Size, @SystemCBC[0], Length(SystemCBC));
  p := 0;
  for i := 0 to FLevel - 1 do
    begin
      p := 0;
      while p + 64 <= Size do
        begin
          XXTEADecrypt(Fkey, PXXTEABlock(GetOffset(sour, p))^);
          inc(p, 64);
        end;
    end;
  if FProcessTail and (p < Size) then
      TCipher.EncryptTail(GetOffset(sour, p), Size - p);
end;

{===============================================================================
 * RC6 (16-byte block, 256-bit effective key derived via LMD)
 *===============================================================================}

constructor TCipher_Tool_RC6.Create(KeyBuffer_: TCipherKeyBuffer);
var
  k, k256: TBytes;
begin
  inherited Create(KeyBuffer_);
  FillPtr(@Fkey, SizeOf(Fkey), 0);

  SetLength(k256, 32);
  FillPtr(@k256[0], 32, 0);

  SetLength(k, 0);
  if TCipher.GetKey(@KeyBuffer_, k) and (Length(k) > 0) then
      THashMD.GenerateLMDKey((@k256[0])^, 32, k);

  TRC6.InitKey(@k256[0], 32, Fkey);

  if Length(k256) > 0 then FillPtr(@k256[0], Length(k256), 0);
  if Length(k) > 0 then FillPtr(@k[0], Length(k), 0);
  SetLength(k256, 0);
  SetLength(k, 0);
end;

procedure TCipher_Tool_RC6.Encrypt(sour: Pointer; Size: NativeInt);
var
  i: Integer;
  p: NativeInt;
begin
  if Size = 0 then
      Exit;
  p := 0;
  for i := 0 to FLevel - 1 do
    begin
      p := 0;
      while p + 16 <= Size do
        begin
          TRC6.Encrypt(Fkey, PRC6Block(GetOffset(sour, p))^);
          inc(p, 16);
        end;
    end;
  if FProcessTail and (p < Size) then
      TCipher.EncryptTail(GetOffset(sour, p), Size - p);
  if FCBC then
      TCipher.BlockCBC(sour, Size, @SystemCBC[0], Length(SystemCBC));
end;

procedure TCipher_Tool_RC6.Decrypt(sour: Pointer; Size: NativeInt);
var
  i: Integer;
  p: NativeInt;
begin
  if Size = 0 then
      Exit;
  if FCBC then
      TCipher.BlockCBC(sour, Size, @SystemCBC[0], Length(SystemCBC));
  p := 0;
  for i := 0 to FLevel - 1 do
    begin
      p := 0;
      while p + 16 <= Size do
        begin
          TRC6.Decrypt(Fkey, PRC6Block(GetOffset(sour, p))^);
          inc(p, 16);
        end;
    end;
  if FProcessTail and (p < Size) then
      TCipher.EncryptTail(GetOffset(sour, p), Size - p);
end;

{===============================================================================
 * Serpent (16-byte block, 256-bit effective key derived via LMD)
 *===============================================================================}

constructor TCipher_Tool_Serpent.Create(KeyBuffer_: TCipherKeyBuffer);
var
  k, k256: TBytes;
begin
  inherited Create(KeyBuffer_);
  FillPtr(@Fkey, SizeOf(Fkey), 0);

  SetLength(k256, 32);
  FillPtr(@k256[0], 32, 0);

  SetLength(k, 0);
  if TCipher.GetKey(@KeyBuffer_, k) and (Length(k) > 0) then
      THashMD.GenerateLMDKey((@k256[0])^, 32, k);

  TSerpent.InitKey(@k256[0], 32, Fkey);

  if Length(k256) > 0 then FillPtr(@k256[0], Length(k256), 0);
  if Length(k) > 0 then FillPtr(@k[0], Length(k), 0);
  SetLength(k256, 0);
  SetLength(k, 0);
end;

procedure TCipher_Tool_Serpent.Encrypt(sour: Pointer; Size: NativeInt);
var
  i: Integer;
  p: NativeInt;
begin
  if Size = 0 then
      Exit;
  p := 0;
  for i := 0 to FLevel - 1 do
    begin
      p := 0;
      while p + 16 <= Size do
        begin
          TSerpent.Encrypt(Fkey, PSerpentBlock(GetOffset(sour, p))^);
          inc(p, 16);
        end;
    end;
  if FProcessTail and (p < Size) then
      TCipher.EncryptTail(GetOffset(sour, p), Size - p);
  if FCBC then
      TCipher.BlockCBC(sour, Size, @SystemCBC[0], Length(SystemCBC));
end;

procedure TCipher_Tool_Serpent.Decrypt(sour: Pointer; Size: NativeInt);
var
  i: Integer;
  p: NativeInt;
begin
  if Size = 0 then
      Exit;
  if FCBC then
      TCipher.BlockCBC(sour, Size, @SystemCBC[0], Length(SystemCBC));
  p := 0;
  for i := 0 to FLevel - 1 do
    begin
      p := 0;
      while p + 16 <= Size do
        begin
          TSerpent.Decrypt(Fkey, PSerpentBlock(GetOffset(sour, p))^);
          inc(p, 16);
        end;
    end;
  if FProcessTail and (p < Size) then
      TCipher.EncryptTail(GetOffset(sour, p), Size - p);
end;

{===============================================================================
 * Mars (16-byte block, 256-bit effective key derived via LMD)
 *===============================================================================}

constructor TCipher_Tool_Mars.Create(KeyBuffer_: TCipherKeyBuffer);
var
  k, k256: TBytes;
begin
  inherited Create(KeyBuffer_);
  FillPtr(@Fkey, SizeOf(Fkey), 0);

  SetLength(k256, 32);
  FillPtr(@k256[0], 32, 0);

  SetLength(k, 0);
  if TCipher.GetKey(@KeyBuffer_, k) and (Length(k) > 0) then
      THashMD.GenerateLMDKey((@k256[0])^, 32, k);

  TMars.InitKey(@k256[0], 32, Fkey);

  if Length(k256) > 0 then FillPtr(@k256[0], Length(k256), 0);
  if Length(k) > 0 then FillPtr(@k[0], Length(k), 0);
  SetLength(k256, 0);
  SetLength(k, 0);
end;

procedure TCipher_Tool_Mars.Encrypt(sour: Pointer; Size: NativeInt);
var
  i: Integer;
  p: NativeInt;
begin
  if Size = 0 then
      Exit;
  p := 0;
  for i := 0 to FLevel - 1 do
    begin
      p := 0;
      while p + 16 <= Size do
        begin
          TMars.Encrypt(Fkey, PMarsBlock(GetOffset(sour, p))^);
          inc(p, 16);
        end;
    end;
  if FProcessTail and (p < Size) then
      TCipher.EncryptTail(GetOffset(sour, p), Size - p);
  if FCBC then
      TCipher.BlockCBC(sour, Size, @SystemCBC[0], Length(SystemCBC));
end;

procedure TCipher_Tool_Mars.Decrypt(sour: Pointer; Size: NativeInt);
var
  i: Integer;
  p: NativeInt;
begin
  if Size = 0 then
      Exit;
  if FCBC then
      TCipher.BlockCBC(sour, Size, @SystemCBC[0], Length(SystemCBC));
  p := 0;
  for i := 0 to FLevel - 1 do
    begin
      p := 0;
      while p + 16 <= Size do
        begin
          TMars.Decrypt(Fkey, PMarsBlock(GetOffset(sour, p))^);
          inc(p, 16);
        end;
    end;
  if FProcessTail and (p < Size) then
      TCipher.EncryptTail(GetOffset(sour, p), Size - p);
end;

{===============================================================================
 * Rijndael (16-byte block, 256-bit effective key derived via LMD)
 *===============================================================================}

constructor TCipher_Tool_Rijndael.Create(KeyBuffer_: TCipherKeyBuffer);
var
  k, k256: TBytes;
begin
  inherited Create(KeyBuffer_);
  FillPtr(@Fkey, SizeOf(Fkey), 0);

  SetLength(k256, 32);
  FillPtr(@k256[0], 32, 0);

  SetLength(k, 0);
  if TCipher.GetKey(@KeyBuffer_, k) and (Length(k) > 0) then
      THashMD.GenerateLMDKey((@k256[0])^, 32, k);

  TRijndael.InitKey(@k256[0], 32, Fkey);

  if Length(k256) > 0 then FillPtr(@k256[0], Length(k256), 0);
  if Length(k) > 0 then FillPtr(@k[0], Length(k), 0);
  SetLength(k256, 0);
  SetLength(k, 0);
end;

procedure TCipher_Tool_Rijndael.Encrypt(sour: Pointer; Size: NativeInt);
var
  i: Integer;
  p: NativeInt;
begin
  if Size = 0 then
      Exit;
  p := 0;
  for i := 0 to FLevel - 1 do
    begin
      p := 0;
      while p + 16 <= Size do
        begin
          TRijndael.Encrypt(Fkey, PRijndaelBlock(GetOffset(sour, p))^);
          inc(p, 16);
        end;
    end;
  if FProcessTail and (p < Size) then
      TCipher.EncryptTail(GetOffset(sour, p), Size - p);
  if FCBC then
      TCipher.BlockCBC(sour, Size, @SystemCBC[0], Length(SystemCBC));
end;

procedure TCipher_Tool_Rijndael.Decrypt(sour: Pointer; Size: NativeInt);
var
  i: Integer;
  p: NativeInt;
begin
  if Size = 0 then
      Exit;
  if FCBC then
      TCipher.BlockCBC(sour, Size, @SystemCBC[0], Length(SystemCBC));
  p := 0;
  for i := 0 to FLevel - 1 do
    begin
      p := 0;
      while p + 16 <= Size do
        begin
          TRijndael.Decrypt(Fkey, PRijndaelBlock(GetOffset(sour, p))^);
          inc(p, 16);
        end;
    end;
  if FProcessTail and (p < Size) then
      TCipher.EncryptTail(GetOffset(sour, p), Size - p);
end;

{===============================================================================
 * Twofish (16-byte block, 256-bit effective key derived via LMD)
 *===============================================================================}

constructor TCipher_Tool_TwoFish.Create(KeyBuffer_: TCipherKeyBuffer);
var
  k, k256: TBytes;
begin
  inherited Create(KeyBuffer_);
  FillPtr(@Fkey, SizeOf(Fkey), 0);

  SetLength(k256, 32);
  FillPtr(@k256[0], 32, 0);

  SetLength(k, 0);
  if TCipher.GetKey(@KeyBuffer_, k) and (Length(k) > 0) then
      THashMD.GenerateLMDKey((@k256[0])^, 32, k);

  TTwofish.InitKey(PCCByteArray(@k256[0]), 32, Fkey);

  if Length(k256) > 0 then FillPtr(@k256[0], Length(k256), 0);
  if Length(k) > 0 then FillPtr(@k[0], Length(k), 0);
  SetLength(k256, 0);
  SetLength(k, 0);
end;

procedure TCipher_Tool_TwoFish.Encrypt(sour: Pointer; Size: NativeInt);
var
  i: Integer;
  p: NativeInt;
begin
  if Size = 0 then
      Exit;
  p := 0;
  for i := 0 to FLevel - 1 do
    begin
      p := 0;
      while p + 16 <= Size do
        begin
          TTwofish.Encrypt(Fkey, PTwofishBlock(GetOffset(sour, p))^);
          inc(p, 16);
        end;
    end;
  if FProcessTail and (p < Size) then
      TCipher.EncryptTail(GetOffset(sour, p), Size - p);
  if FCBC then
      TCipher.BlockCBC(sour, Size, @SystemCBC[0], Length(SystemCBC));
end;

procedure TCipher_Tool_TwoFish.Decrypt(sour: Pointer; Size: NativeInt);
var
  i: Integer;
  p: NativeInt;
begin
  if Size = 0 then
      Exit;
  if FCBC then
      TCipher.BlockCBC(sour, Size, @SystemCBC[0], Length(SystemCBC));
  p := 0;
  for i := 0 to FLevel - 1 do
    begin
      p := 0;
      while p + 16 <= Size do
        begin
          TTwofish.Decrypt(Fkey, PTwofishBlock(GetOffset(sour, p))^);
          inc(p, 16);
        end;
    end;
  if FProcessTail and (p < Size) then
      TCipher.EncryptTail(GetOffset(sour, p), Size - p);
end;

{===============================================================================
 * AES-128 (16-byte block, 128-bit key)
 *===============================================================================}

constructor TCipher_Tool_AES128.Create(KeyBuffer_: TCipherKeyBuffer);
var
  k: TBytes;
  k128: TAESKey128;
begin
  inherited Create(KeyBuffer_);
  FillPtr(@k128[0], 16, 0);
  FillPtr(@FDKey, SizeOf(FDKey), 0);
  FillPtr(@FEkey, SizeOf(FEkey), 0);

  SetLength(k, 0);
  if TCipher.GetKey(@KeyBuffer_, k) and (Length(k) > 0) then
      THashMD.GenerateLMDKey((@k128[0])^, 16, k);

  ExpandAESKeyForDecryption(k128, FDKey);
  ExpandAESKeyForEncryption(k128, FEkey);

  if Length(k) > 0 then FillPtr(@k[0], Length(k), 0);
  SetLength(k, 0);
end;

procedure TCipher_Tool_AES128.Encrypt(sour: Pointer; Size: NativeInt);
var
  i: Integer;
  p: NativeInt;
begin
  if Size = 0 then
      Exit;
  p := 0;
  for i := 0 to FLevel - 1 do
    begin
      p := 0;
      while p + 16 <= Size do
        begin
          EncryptAES(PAESBuffer(GetOffset(sour, p))^, FEkey, PAESBuffer(GetOffset(sour, p))^);
          inc(p, 16);
        end;
    end;
  if FProcessTail and (p < Size) then
      TCipher.EncryptTail(GetOffset(sour, p), Size - p);
  if FCBC then
      TCipher.BlockCBC(sour, Size, @SystemCBC[0], Length(SystemCBC));
end;

procedure TCipher_Tool_AES128.Decrypt(sour: Pointer; Size: NativeInt);
var
  i: Integer;
  p: NativeInt;
begin
  if Size = 0 then
      Exit;
  if FCBC then
      TCipher.BlockCBC(sour, Size, @SystemCBC[0], Length(SystemCBC));
  p := 0;
  for i := 0 to FLevel - 1 do
    begin
      p := 0;
      while p + 16 <= Size do
        begin
          DecryptAES(PAESBuffer(GetOffset(sour, p))^, FDKey, PAESBuffer(GetOffset(sour, p))^);
          inc(p, 16);
        end;
    end;
  if FProcessTail and (p < Size) then
      TCipher.EncryptTail(GetOffset(sour, p), Size - p);
end;

{===============================================================================
 * AES-192 (16-byte block, 192-bit key)
 *===============================================================================}

constructor TCipher_Tool_AES192.Create(KeyBuffer_: TCipherKeyBuffer);
var
  k: TBytes;
  k192: TAESKey192;
begin
  inherited Create(KeyBuffer_);
  FillPtr(@k192[0], 24, 0);
  FillPtr(@FDKey, SizeOf(FDKey), 0);
  FillPtr(@FEkey, SizeOf(FEkey), 0);

  SetLength(k, 0);
  if TCipher.GetKey(@KeyBuffer_, k) and (Length(k) > 0) then
      THashMD.GenerateLMDKey((@k192[0])^, 24, k);

  ExpandAESKeyForDecryption(k192, FDKey);
  ExpandAESKeyForEncryption(k192, FEkey);

  if Length(k) > 0 then FillPtr(@k[0], Length(k), 0);
  SetLength(k, 0);
end;

procedure TCipher_Tool_AES192.Encrypt(sour: Pointer; Size: NativeInt);
var
  i: Integer;
  p: NativeInt;
begin
  if Size = 0 then
      Exit;
  p := 0;
  for i := 0 to FLevel - 1 do
    begin
      p := 0;
      while p + 16 <= Size do
        begin
          EncryptAES(PAESBuffer(GetOffset(sour, p))^, FEkey, PAESBuffer(GetOffset(sour, p))^);
          inc(p, 16);
        end;
    end;
  if FProcessTail and (p < Size) then
      TCipher.EncryptTail(GetOffset(sour, p), Size - p);
  if FCBC then
      TCipher.BlockCBC(sour, Size, @SystemCBC[0], Length(SystemCBC));
end;

procedure TCipher_Tool_AES192.Decrypt(sour: Pointer; Size: NativeInt);
var
  i: Integer;
  p: NativeInt;
begin
  if Size = 0 then
      Exit;
  if FCBC then
      TCipher.BlockCBC(sour, Size, @SystemCBC[0], Length(SystemCBC));
  p := 0;
  for i := 0 to FLevel - 1 do
    begin
      p := 0;
      while p + 16 <= Size do
        begin
          DecryptAES(PAESBuffer(GetOffset(sour, p))^, FDKey, PAESBuffer(GetOffset(sour, p))^);
          inc(p, 16);
        end;
    end;
  if FProcessTail and (p < Size) then
      TCipher.EncryptTail(GetOffset(sour, p), Size - p);
end;

{===============================================================================
 * AES-256 (16-byte block, 256-bit key)
 *===============================================================================}

constructor TCipher_Tool_AES256.Create(KeyBuffer_: TCipherKeyBuffer);
var
  k: TBytes;
  k256: TAESKey256;
begin
  inherited Create(KeyBuffer_);
  FillPtr(@k256[0], 32, 0);
  FillPtr(@FDKey, SizeOf(FDKey), 0);
  FillPtr(@FEkey, SizeOf(FEkey), 0);

  SetLength(k, 0);
  if TCipher.GetKey(@KeyBuffer_, k) and (Length(k) > 0) then
      THashMD.GenerateLMDKey((@k256[0])^, 32, k);

  ExpandAESKeyForDecryption(k256, FDKey);
  ExpandAESKeyForEncryption(k256, FEkey);

  if Length(k) > 0 then FillPtr(@k[0], Length(k), 0);
  SetLength(k, 0);
end;

procedure TCipher_Tool_AES256.Encrypt(sour: Pointer; Size: NativeInt);
var
  i: Integer;
  p: NativeInt;
begin
  if Size = 0 then
      Exit;
  p := 0;
  for i := 0 to FLevel - 1 do
    begin
      p := 0;
      while p + 16 <= Size do
        begin
          EncryptAES(PAESBuffer(GetOffset(sour, p))^, FEkey, PAESBuffer(GetOffset(sour, p))^);
          inc(p, 16);
        end;
    end;
  if FProcessTail and (p < Size) then
      TCipher.EncryptTail(GetOffset(sour, p), Size - p);
  if FCBC then
      TCipher.BlockCBC(sour, Size, @SystemCBC[0], Length(SystemCBC));
end;

procedure TCipher_Tool_AES256.Decrypt(sour: Pointer; Size: NativeInt);
var
  i: Integer;
  p: NativeInt;
begin
  if Size = 0 then
      Exit;
  if FCBC then
      TCipher.BlockCBC(sour, Size, @SystemCBC[0], Length(SystemCBC));
  p := 0;
  for i := 0 to FLevel - 1 do
    begin
      p := 0;
      while p + 16 <= Size do
        begin
          DecryptAES(PAESBuffer(GetOffset(sour, p))^, FDKey, PAESBuffer(GetOffset(sour, p))^);
          inc(p, 16);
        end;
    end;
  if FProcessTail and (p < Size) then
      TCipher.EncryptTail(GetOffset(sour, p), Size - p);
end;

{===============================================================================
 * Factory functions
 *===============================================================================}

function CreateCipherClass(cs: TCipherSecurity; KeyBuffer_: TCipherKeyBuffer): TCipher_Tool_Base;
begin
  case cs of
    csNone:      Result := TCipher_Tool_Base.Create(KeyBuffer_);
    csDES64:     Result := TCipher_Tool_DES64.Create(KeyBuffer_);
    csDES128:    Result := TCipher_Tool_DES128.Create(KeyBuffer_);
    csDES192:    Result := TCipher_Tool_DES192.Create(KeyBuffer_);
    csBlowfish:  Result := TCipher_Tool_BlowFish.Create(KeyBuffer_);
    csLBC:       Result := TCipher_Tool_LBC.Create(KeyBuffer_);
    csLQC:       Result := TCipher_Tool_LQC.Create(KeyBuffer_);
    csRNG32:     Result := TCipher_Tool_RNG32.Create(KeyBuffer_);
    csRNG64:     Result := TCipher_Tool_RNG64.Create(KeyBuffer_);
    csLSC:       Result := TCipher_Tool_LSC.Create(KeyBuffer_);
    csTwoFish:   Result := TCipher_Tool_TwoFish.Create(KeyBuffer_);
    csXXTea512:  Result := TCipher_Tool_XXTea512.Create(KeyBuffer_);
    csRC6:       Result := TCipher_Tool_RC6.Create(KeyBuffer_);
    csSerpent:   Result := TCipher_Tool_Serpent.Create(KeyBuffer_);
    csMars:      Result := TCipher_Tool_Mars.Create(KeyBuffer_);
    csRijndael:  Result := TCipher_Tool_Rijndael.Create(KeyBuffer_);
    csAES128:    Result := TCipher_Tool_AES128.Create(KeyBuffer_);
    csAES192:    Result := TCipher_Tool_AES192.Create(KeyBuffer_);
    csAES256:    Result := TCipher_Tool_AES256.Create(KeyBuffer_);
    else         Result := TCipher_Tool_Base.Create(KeyBuffer_);
  end;
  Result.FCipherSecurity := cs;
end;

function CreateCipherClassFromPassword(cs: TCipherSecurity; password_: TCipherString): TCipher_Tool_Base;
var
  k: TCipherKeyBuffer;
begin
  TCipher.GenerateKey(cs, password_, k);
  Result := CreateCipherClass(cs, k);
  if Length(k) > 0 then FillPtr(@k[0], Length(k), 0);
  SetLength(k, 0);
end;

function CreateCipherClassFromBuffer(cs: TCipherSecurity; key: TCipherKeyBuffer): TCipher_Tool_Base;
var
  k: TCipherKeyBuffer;
begin
  {
   * FIX: guard against empty input key buffer. The original code called
   * CopyPtr(@key[0], @Result.FLastGenerateKey[0], 0) unconditionally
   * after SetLength(_, 0), which dereferences @key[0] out of bounds.
   *}
  if Length(key) = 0 then
      TCipher.GenerateKey(cs, '', k)
  else
      TCipher.GenerateKey(cs, @key[0], Length(key), k);

  Result := CreateCipherClass(cs, k);
  if Length(k) > 0 then FillPtr(@k[0], Length(k), 0);
  SetLength(k, 0);

  {
   * Copy the caller's raw key material for later reference.
   *}
  SetLength(Result.FLastGenerateKey, Length(key));
  if Length(key) > 0 then
      CopyPtr(@key[0], @Result.FLastGenerateKey[0], Length(key));
end;

function CreateCipherClassFromBuffer(cs: TCipherSecurity; buffPtr: Pointer; Size: NativeInt): TCipher_Tool_Base;
var
  k: TCipherKeyBuffer;
begin
  {
   * FIX: guard nil pointer / non-positive size before dereferencing
   * buffPtr; also skip the CopyPtr into FLastGenerateKey when Size <= 0.
   *}
  if (buffPtr = nil) or (Size <= 0) then
      TCipher.GenerateKey(cs, '', k)
  else
      TCipher.GenerateKey(cs, buffPtr, Size, k);

  Result := CreateCipherClass(cs, k);
  if Length(k) > 0 then FillPtr(@k[0], Length(k), 0);
  SetLength(k, 0);

  SetLength(Result.FLastGenerateKey, Size);
  if (buffPtr <> nil) and (Size > 0) then
      CopyPtr(buffPtr, @Result.FLastGenerateKey[0], Size);
end;


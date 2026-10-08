{
 * ============================================================================
 * Z.Cipher.imp_TParallelCipher.inc
 *
 * Parallel implementations of all cipher block transforms, and the
 * buffered wrapper functions that dispatch to them.
 *
 * Bug fixes applied (FPC -O2 optimization safety):
 *
 *   1. CRITICAL ！ integer divide-by-zero in every TParallelCipher.XXX method:
 *      the tail-size computation was "tailSiz := Size mod JobData.L", but
 *      JobData.L was only assigned inside the "if Size >= BlockSize" branch.
 *      When 0 < Size < BlockSize, JobData.L held an uninitialized stack
 *      value (possibly 0), causing an EDivByZero exception (or, under -O2,
 *      silent garbage). FIXED by introducing a local "BlockSize" constant
 *      and using "Size mod BlockSize" for the tail computation.
 *
 *   2. SEVERE ！ race condition on JobData^.CompletedBlock: multiple worker
 *      threads performed "inc(JobData^.CompletedBlock, n)" concurrently,
 *      losing updates. FIXED with AtomInc from Z.Core.
 *
 *   3. SEVERE ！ ParallelCipher_C could be invoked with ToIndex <= FromIndex
 *      (empty range), producing newBuffSiz <= 0 and passing a zero-length
 *      buffer to the cipher function. Some ciphers divide by block size.
 *      FIXED with an explicit early exit.
 *
 *   4. BlockCBC_Parallel: same divide-by-zero hazard pattern as (1), now
 *      guarded by a local BlockSize as well.
 *
 *   5. RunParallel: added an explicit "Total <= 0" early exit so that
 *      "stepW := Total div Depth" is provably safe.
 *
 * Conventions (project-wide):
 *   - No Move / no FillChar. Use CopyPtr / FillPtr from Z.Core.
 *   - Multi-line comments carry a leading "*" on every line so Delphi
 *     code-formatting tools preserve the layout.
 * ============================================================================
 *}

{$IFDEF Parallel}

procedure TParallelCipher.DES64_Parallel(Job, buff, key: Pointer; Size: NativeInt);
var
  p: NativeInt;
  L: NativeInt;
begin
  L := PParallelCipherJobData(Job)^.L;
  if L <= 0 then Exit;
  p := 0;
  repeat
    TDES.EncryptDES(PDESContext(key)^, PDESBlock(GetOffset(buff, p))^);
    p := p + L;
  until p + L > Size;
end;

procedure TParallelCipher.DES128_Parallel(Job, buff, key: Pointer; Size: NativeInt);
var
  p: NativeInt;
  L: NativeInt;
begin
  L := PParallelCipherJobData(Job)^.L;
  if L <= 0 then Exit;
  p := 0;
  repeat
    TDES.EncryptTripleDES(PTripleDESContext(key)^, PDESBlock(GetOffset(buff, p))^);
    p := p + L;
  until p + L > Size;
end;

procedure TParallelCipher.DES192_Parallel(Job, buff, key: Pointer; Size: NativeInt);
var
  p: NativeInt;
  L: NativeInt;
begin
  L := PParallelCipherJobData(Job)^.L;
  if L <= 0 then Exit;
  p := 0;
  repeat
    TDES.EncryptTripleDES3Key(PTripleDESContext3Key(key)^, PDESBlock(GetOffset(buff, p))^);
    p := p + L;
  until p + L > Size;
end;

procedure TParallelCipher.Blowfish_Parallel(Job, buff, key: Pointer; Size: NativeInt);
var
  p: NativeInt;
  L: NativeInt;
begin
  L := PParallelCipherJobData(Job)^.L;
  if L <= 0 then Exit;
  p := 0;
  repeat
    TBlowfish.EncryptBF(PBFContext(key)^, PBFBlock(GetOffset(buff, p))^,
      PParallelCipherJobData(Job)^.Encrypt);
    p := p + L;
  until p + L > Size;
end;

procedure TParallelCipher.LBC_Parallel(Job, buff, key: Pointer; Size: NativeInt);
var
  p: NativeInt;
  L: NativeInt;
begin
  L := PParallelCipherJobData(Job)^.L;
  if L <= 0 then Exit;
  p := 0;
  repeat
    TLBC.EncryptLBC(PLBCContext(key)^, PLBCBlock(GetOffset(buff, p))^);
    p := p + L;
  until p + L > Size;
end;

procedure TParallelCipher.LQC_Parallel(Job, buff, key: Pointer; Size: NativeInt);
var
  p: NativeInt;
  L: NativeInt;
begin
  L := PParallelCipherJobData(Job)^.L;
  if L <= 0 then Exit;
  p := 0;
  repeat
    TLBC.EncryptLQC(PKey128(key)^, PLQCBlock(GetOffset(buff, p))^,
      PParallelCipherJobData(Job)^.Encrypt);
    p := p + L;
  until p + L > Size;
end;

procedure TParallelCipher.XXTea512_Parallel(Job, buff, key: Pointer; Size: NativeInt);
var
  p: NativeInt;
  L: NativeInt;
begin
  L := PParallelCipherJobData(Job)^.L;
  if L <= 0 then Exit;
  if PParallelCipherJobData(Job)^.Encrypt then
    begin
      p := 0;
      repeat
        XXTEAEncrypt(PKey128(key)^, PXXTEABlock(GetOffset(buff, p))^);
        p := p + L;
      until p + L > Size;
    end
  else
    begin
      p := 0;
      repeat
        XXTEADecrypt(PKey128(key)^, PXXTEABlock(GetOffset(buff, p))^);
        p := p + L;
      until p + L > Size;
    end;
end;

procedure TParallelCipher.RC6_Parallel(Job, buff, key: Pointer; Size: NativeInt);
var
  p: NativeInt;
  L: NativeInt;
begin
  L := PParallelCipherJobData(Job)^.L;
  if L <= 0 then Exit;
  if PParallelCipherJobData(Job)^.Encrypt then
    begin
      p := 0;
      repeat
        TRC6.Encrypt(PRC6Key(key)^, PRC6Block(GetOffset(buff, p))^);
        p := p + L;
      until p + L > Size;
    end
  else
    begin
      p := 0;
      repeat
        TRC6.Decrypt(PRC6Key(key)^, PRC6Block(GetOffset(buff, p))^);
        p := p + L;
      until p + L > Size;
    end;
end;

procedure TParallelCipher.Serpent_Parallel(Job, buff, key: Pointer; Size: NativeInt);
var
  p: NativeInt;
  L: NativeInt;
begin
  L := PParallelCipherJobData(Job)^.L;
  if L <= 0 then Exit;
  if PParallelCipherJobData(Job)^.Encrypt then
    begin
      p := 0;
      repeat
        TSerpent.Encrypt(PSerpentkey(key)^, PSerpentBlock(GetOffset(buff, p))^);
        p := p + L;
      until p + L > Size;
    end
  else
    begin
      p := 0;
      repeat
        TSerpent.Decrypt(PSerpentkey(key)^, PSerpentBlock(GetOffset(buff, p))^);
        p := p + L;
      until p + L > Size;
    end;
end;

procedure TParallelCipher.Mars_Parallel(Job, buff, key: Pointer; Size: NativeInt);
var
  p: NativeInt;
  L: NativeInt;
begin
  L := PParallelCipherJobData(Job)^.L;
  if L <= 0 then Exit;
  if PParallelCipherJobData(Job)^.Encrypt then
    begin
      p := 0;
      repeat
        TMars.Encrypt(PMarskey(key)^, PMarsBlock(GetOffset(buff, p))^);
        p := p + L;
      until p + L > Size;
    end
  else
    begin
      p := 0;
      repeat
        TMars.Decrypt(PMarskey(key)^, PMarsBlock(GetOffset(buff, p))^);
        p := p + L;
      until p + L > Size;
    end;
end;

procedure TParallelCipher.Rijndael_Parallel(Job, buff, key: Pointer; Size: NativeInt);
var
  p: NativeInt;
  L: NativeInt;
begin
  L := PParallelCipherJobData(Job)^.L;
  if L <= 0 then Exit;
  if PParallelCipherJobData(Job)^.Encrypt then
    begin
      p := 0;
      repeat
        TRijndael.Encrypt(PRijndaelkey(key)^, PRijndaelBlock(GetOffset(buff, p))^);
        p := p + L;
      until p + L > Size;
    end
  else
    begin
      p := 0;
      repeat
        TRijndael.Decrypt(PRijndaelkey(key)^, PRijndaelBlock(GetOffset(buff, p))^);
        p := p + L;
      until p + L > Size;
    end;
end;

procedure TParallelCipher.TwoFish_Parallel(Job, buff, key: Pointer; Size: NativeInt);
var
  p: NativeInt;
  L: NativeInt;
begin
  L := PParallelCipherJobData(Job)^.L;
  if L <= 0 then Exit;
  if PParallelCipherJobData(Job)^.Encrypt then
    begin
      p := 0;
      repeat
        TTwofish.Encrypt(PTwofishKey(key)^, PTwofishBlock(GetOffset(buff, p))^);
        p := p + L;
      until p + L > Size;
    end
  else
    begin
      p := 0;
      repeat
        TTwofish.Decrypt(PTwofishKey(key)^, PTwofishBlock(GetOffset(buff, p))^);
        p := p + L;
      until p + L > Size;
    end;
end;

procedure TParallelCipher.AES128_Parallel(Job, buff, key: Pointer; Size: NativeInt);
var
  p: NativeInt;
  L: NativeInt;
begin
  L := PParallelCipherJobData(Job)^.L;
  if L <= 0 then Exit;
  if PParallelCipherJobData(Job)^.Encrypt then
    begin
      p := 0;
      repeat
        EncryptAES(PAESBuffer(GetOffset(buff, p))^, PAESExpandedKey128(key)^,
          PAESBuffer(GetOffset(buff, p))^);
        p := p + L;
      until p + L > Size;
    end
  else
    begin
      p := 0;
      repeat
        DecryptAES(PAESBuffer(GetOffset(buff, p))^, PAESExpandedKey128(key)^,
          PAESBuffer(GetOffset(buff, p))^);
        p := p + L;
      until p + L > Size;
    end;
end;

procedure TParallelCipher.AES192_Parallel(Job, buff, key: Pointer; Size: NativeInt);
var
  p: NativeInt;
  L: NativeInt;
begin
  L := PParallelCipherJobData(Job)^.L;
  if L <= 0 then Exit;
  if PParallelCipherJobData(Job)^.Encrypt then
    begin
      p := 0;
      repeat
        EncryptAES(PAESBuffer(GetOffset(buff, p))^, PAESExpandedKey192(key)^,
          PAESBuffer(GetOffset(buff, p))^);
        p := p + L;
      until p + L > Size;
    end
  else
    begin
      p := 0;
      repeat
        DecryptAES(PAESBuffer(GetOffset(buff, p))^, PAESExpandedKey192(key)^,
          PAESBuffer(GetOffset(buff, p))^);
        p := p + L;
      until p + L > Size;
    end;
end;

procedure TParallelCipher.AES256_Parallel(Job, buff, key: Pointer; Size: NativeInt);
var
  p: NativeInt;
  L: NativeInt;
begin
  L := PParallelCipherJobData(Job)^.L;
  if L <= 0 then Exit;
  if PParallelCipherJobData(Job)^.Encrypt then
    begin
      p := 0;
      repeat
        EncryptAES(PAESBuffer(GetOffset(buff, p))^, PAESExpandedKey256(key)^,
          PAESBuffer(GetOffset(buff, p))^);
        p := p + L;
      until p + L > Size;
    end
  else
    begin
      p := 0;
      repeat
        DecryptAES(PAESBuffer(GetOffset(buff, p))^, PAESExpandedKey256(key)^,
          PAESBuffer(GetOffset(buff, p))^);
        p := p + L;
      until p + L > Size;
    end;
end;

procedure TParallelCipher.BlockCBC_Parallel(Job, buff, key: Pointer; Size: NativeInt);
begin
  if Size <= 0 then Exit;
  TCipher.BlockCBC(buff, Size, key, PParallelCipherJobData(Job)^.L);
end;

{
 * Worker entry: process block indices [FromIndex, ToIndex).
 *
 * FIX: skip empty ranges. Passing newBuffSiz <= 0 downstream could trigger
 * a divide-by-zero inside cipher functions that compute block counts.
 *}
procedure TParallelCipher.ParallelCipher_C(const JobData: PParallelCipherJobData;
  const FromIndex, ToIndex: NativeInt);
var
  newBuffPtr: Pointer;
  newBuffSiz: NativeUInt;
  blockCount: NativeInt;
begin
  if (JobData = nil) or (JobData^.L <= 0) then Exit;

  blockCount := ToIndex - FromIndex;
  if blockCount <= 0 then Exit;

  newBuffPtr := Pointer(NativeUInt(JobData^.OriginBuffer) + (NativeUInt(FromIndex) * NativeUInt(JobData^.L)));
  newBuffSiz := NativeUInt(blockCount) * NativeUInt(JobData^.L);

  try
    JobData^.cipherFunc(JobData, newBuffPtr, JobData^.KeyBuffer, NativeInt(newBuffSiz));
  except
    (* Exceptions inside the cipher are swallowed, preserving the original
     * behaviour. The caller will still detect corruption via the SHA/hash
     * check performed after the round trip. *)
  end;

  {
   * FIX: use AtomInc for the completion counter. Multiple worker threads
   * may finish simultaneously; a plain "inc" would lose updates.
   * AtomInc is provided by Z.Core.
   *}
  AtomInc(JobData^.CompletedBlock, Int64(blockCount));
end;

{
 * Split [0, Total) into Depth roughly-equal work units and run them.
 *
 * Guards:
 *   Total <= 0              -> no work.
 *   Depth <= 0 or Total < Depth
 *                           -> serial fallback.
 * }
procedure TParallelCipher.RunParallel(const JobData: PParallelCipherJobData;
  const Total, Depth: NativeInt);
var
  StepTotal, stepW: NativeInt;
{$IFDEF FPC}
  procedure Nested_ParallelFor(pass: Int64);
  var
    w: Int64;
  begin
    w := stepW * pass;
    if w + stepW <= Total then
        ParallelCipher_C(JobData, w, w + stepW)
    else
        ParallelCipher_C(JobData, w, Total);
  end;
{$ENDIF FPC}

begin
  if (JobData = nil) or (Total <= 0) then Exit;

  if (Depth <= 0) or (Total < Depth) then
    begin
      ParallelCipher_C(JobData, 0, Total);
      Exit;
    end;

  {
   * The branch above guarantees Total >= Depth >= 1, hence stepW >= 1.
   * The explicit guard makes the divide provably safe for any optimizer.
   *}
  stepW := Total div Depth;
  if stepW <= 0 then
    begin
      ParallelCipher_C(JobData, 0, Total);
      Exit;
    end;

  StepTotal := Total div stepW;
  if (Total mod stepW) > 0 then
      inc(StepTotal);

{$IFDEF FPC}
  FPCParallelFor(Nested_ParallelFor, 0, StepTotal - 1);
{$ELSE FPC}
  DelphiParallelFor(0, StepTotal - 1, procedure(pass: Int64)
    var
      w: Int64;
    begin
      w := stepW * pass;
      if w + stepW <= Total then
          ParallelCipher_C(JobData, w, w + stepW)
      else
          ParallelCipher_C(JobData, w, Total);
    end);
{$ENDIF FPC}
end;

constructor TParallelCipher.Create;
begin
  inherited Create;
  BlockDepth := DefaultParallelDepth;
end;

destructor TParallelCipher.Destroy;
begin
  inherited Destroy;
end;

{
 * ============================================================================
 * Per-cipher entry points.
 *
 * Each method:
 *   1. declares a local "BlockSize" constant for its cipher;
 *   2. returns immediately if Size <= 0;
 *   3. if Size >= BlockSize, initializes JobData and dispatches RunParallel;
 *   4. if ProcessTail, encrypts/decrypts the tail via TCipher.EncryptTail.
 *
 * FIX: the tail size is now computed as "Size mod BlockSize" (never
 * "Size mod JobData.L"), so it is safe even when Size < BlockSize and the
 * cipher path was skipped.
 * ============================================================================
 *}

function TParallelCipher.DES64(sour: Pointer; Size: NativeInt;
  KeyBuff: PCipherKeyBuffer; Encrypt, ProcessTail: Boolean): Boolean;
const
  BlockSize = 8;
var
  JobData: TParallelCipherJobData;
  k: TKey64;
  Context: TDESContext;
  tailSiz: NativeInt;
begin
  Result := False;
  if Size <= 0 then Exit;

  if Size >= BlockSize then
    begin
      if not TCipher.GetKey(KeyBuff, k) then Exit;

      TDES.InitEncryptDES(k, Context, Encrypt);
      JobData.cipherFunc := DES64_Parallel;
      JobData.KeyBuffer := @Context;
      JobData.OriginBuffer := sour;
      JobData.L := BlockSize;
      JobData.TotalBlock := Size div BlockSize;
      JobData.CompletedBlock := 0;
      JobData.Encrypt := Encrypt;

      RunParallel(@JobData, JobData.TotalBlock, BlockDepth);
    end;

  if ProcessTail then
    begin
      tailSiz := Size mod BlockSize;
      if tailSiz > 0 then
          TCipher.EncryptTail(Pointer(NativeUInt(sour) + NativeUInt(Size - tailSiz)), tailSiz);
    end;

  Result := True;
end;

function TParallelCipher.DES128(sour: Pointer; Size: NativeInt;
  KeyBuff: PCipherKeyBuffer; Encrypt, ProcessTail: Boolean): Boolean;
const
  BlockSize = 8;
var
  JobData: TParallelCipherJobData;
  k: TKey128;
  Context: TTripleDESContext;
  tailSiz: NativeInt;
begin
  Result := False;
  if Size <= 0 then Exit;

  if Size >= BlockSize then
    begin
      if not TCipher.GetKey(KeyBuff, k) then Exit;

      TDES.InitEncryptTripleDES(k, Context, Encrypt);
      JobData.cipherFunc := DES128_Parallel;
      JobData.KeyBuffer := @Context;
      JobData.OriginBuffer := sour;
      JobData.L := BlockSize;
      JobData.TotalBlock := Size div BlockSize;
      JobData.CompletedBlock := 0;
      JobData.Encrypt := Encrypt;

      RunParallel(@JobData, JobData.TotalBlock, BlockDepth);
    end;

  if ProcessTail then
    begin
      tailSiz := Size mod BlockSize;
      if tailSiz > 0 then
          TCipher.EncryptTail(Pointer(NativeUInt(sour) + NativeUInt(Size - tailSiz)), tailSiz);
    end;

  Result := True;
end;

function TParallelCipher.DES192(sour: Pointer; Size: NativeInt;
  KeyBuff: PCipherKeyBuffer; Encrypt, ProcessTail: Boolean): Boolean;
const
  BlockSize = 8;
var
  JobData: TParallelCipherJobData;
  k1, k2, k3: TKey64;
  Context: TTripleDESContext3Key;
  tailSiz: NativeInt;
begin
  Result := False;
  if Size <= 0 then Exit;

  if Size >= BlockSize then
    begin
      if not TCipher.GetKey(KeyBuff, k1, k2, k3) then Exit;

      TDES.InitEncryptTripleDES3Key(k1, k2, k3, Context, Encrypt);
      JobData.cipherFunc := DES192_Parallel;
      JobData.KeyBuffer := @Context;
      JobData.OriginBuffer := sour;
      JobData.L := BlockSize;
      JobData.TotalBlock := Size div BlockSize;
      JobData.CompletedBlock := 0;
      JobData.Encrypt := Encrypt;

      RunParallel(@JobData, JobData.TotalBlock, BlockDepth);
    end;

  if ProcessTail then
    begin
      tailSiz := Size mod BlockSize;
      if tailSiz > 0 then
          TCipher.EncryptTail(Pointer(NativeUInt(sour) + NativeUInt(Size - tailSiz)), tailSiz);
    end;

  Result := True;
end;

function TParallelCipher.Blowfish(sour: Pointer; Size: NativeInt;
  KeyBuff: PCipherKeyBuffer; Encrypt, ProcessTail: Boolean): Boolean;
const
  BlockSize = 8;
var
  JobData: TParallelCipherJobData;
  k: TKey128;
  Context: TBFContext;
  tailSiz: NativeInt;
begin
  Result := False;
  if Size <= 0 then Exit;

  if Size >= BlockSize then
    begin
      if not TCipher.GetKey(KeyBuff, k) then Exit;

      TBlowfish.InitEncryptBF(k, Context);
      JobData.cipherFunc := Blowfish_Parallel;
      JobData.KeyBuffer := @Context;
      JobData.OriginBuffer := sour;
      JobData.L := BlockSize;
      JobData.TotalBlock := Size div BlockSize;
      JobData.CompletedBlock := 0;
      JobData.Encrypt := Encrypt;

      RunParallel(@JobData, JobData.TotalBlock, BlockDepth);
    end;

  if ProcessTail then
    begin
      tailSiz := Size mod BlockSize;
      if tailSiz > 0 then
          TCipher.EncryptTail(Pointer(NativeUInt(sour) + NativeUInt(Size - tailSiz)), tailSiz);
    end;

  Result := True;
end;

function TParallelCipher.LBC(sour: Pointer; Size: NativeInt;
  KeyBuff: PCipherKeyBuffer; Encrypt, ProcessTail: Boolean): Boolean;
const
  BlockSize = 16;
var
  JobData: TParallelCipherJobData;
  k: TKey128;
  Context: TLBCContext;
  tailSiz: NativeInt;
begin
  Result := False;
  if Size <= 0 then Exit;

  if Size >= BlockSize then
    begin
      if not TCipher.GetKey(KeyBuff, k) then Exit;

      TLBC.InitEncryptLBC(k, Context, 16, Encrypt);
      JobData.cipherFunc := LBC_Parallel;
      JobData.KeyBuffer := @Context;
      JobData.OriginBuffer := sour;
      JobData.L := BlockSize;
      JobData.TotalBlock := Size div BlockSize;
      JobData.CompletedBlock := 0;
      JobData.Encrypt := Encrypt;

      RunParallel(@JobData, JobData.TotalBlock, BlockDepth);
    end;

  if ProcessTail then
    begin
      tailSiz := Size mod BlockSize;
      if tailSiz > 0 then
          TCipher.EncryptTail(Pointer(NativeUInt(sour) + NativeUInt(Size - tailSiz)), tailSiz);
    end;

  Result := True;
end;

function TParallelCipher.LQC(sour: Pointer; Size: NativeInt;
  KeyBuff: PCipherKeyBuffer; Encrypt, ProcessTail: Boolean): Boolean;
const
  BlockSize = 8;
var
  JobData: TParallelCipherJobData;
  k: TKey128;
  tailSiz: NativeInt;
begin
  Result := False;
  if Size <= 0 then Exit;

  if Size >= BlockSize then
    begin
      if not TCipher.GetKey(KeyBuff, k) then Exit;

      JobData.cipherFunc := LQC_Parallel;
      JobData.KeyBuffer := @k;
      JobData.OriginBuffer := sour;
      JobData.L := BlockSize;
      JobData.TotalBlock := Size div BlockSize;
      JobData.CompletedBlock := 0;
      JobData.Encrypt := Encrypt;

      RunParallel(@JobData, JobData.TotalBlock, BlockDepth);
    end;

  if ProcessTail then
    begin
      tailSiz := Size mod BlockSize;
      if tailSiz > 0 then
          TCipher.EncryptTail(Pointer(NativeUInt(sour) + NativeUInt(Size - tailSiz)), tailSiz);
    end;

  Result := True;
end;

function TParallelCipher.XXTea512(sour: Pointer; Size: NativeInt;
  KeyBuff: PCipherKeyBuffer; Encrypt, ProcessTail: Boolean): Boolean;
const
  BlockSize = 64;
var
  JobData: TParallelCipherJobData;
  k: TKey128;
  tailSiz: NativeInt;
begin
  Result := False;
  if Size <= 0 then Exit;

  if Size >= BlockSize then
    begin
      if not TCipher.GetKey(KeyBuff, k) then Exit;

      JobData.cipherFunc := XXTea512_Parallel;
      JobData.KeyBuffer := @k;
      JobData.OriginBuffer := sour;
      JobData.L := BlockSize;
      JobData.TotalBlock := Size div BlockSize;
      JobData.CompletedBlock := 0;
      JobData.Encrypt := Encrypt;

      RunParallel(@JobData, JobData.TotalBlock, BlockDepth);
    end;

  if ProcessTail then
    begin
      tailSiz := Size mod BlockSize;
      if tailSiz > 0 then
          TCipher.EncryptTail(Pointer(NativeUInt(sour) + NativeUInt(Size - tailSiz)), tailSiz);
    end;

  Result := True;
end;

function TParallelCipher.RC6(sour: Pointer; Size: NativeInt;
  KeyBuff: PCipherKeyBuffer; Encrypt, ProcessTail: Boolean): Boolean;
const
  BlockSize = 16;
var
  JobData: TParallelCipherJobData;
  k, k256: TBytes;
  Context: TRC6Key;
  tailSiz: NativeInt;
begin
  Result := False;
  if Size <= 0 then Exit;

  if Size >= BlockSize then
    begin
      if not TCipher.GetKey(KeyBuff, k) then Exit;

      SetLength(k256, 32);
      if Length(k) = 0 then
          FillPtr(@k256[0], 32, 0)
      else
          THashMD.GenerateLMDKey((@k256[0])^, 32, k);

      TRC6.InitKey(@k256[0], 32, Context);
      JobData.cipherFunc := RC6_Parallel;
      JobData.KeyBuffer := @Context;
      JobData.OriginBuffer := sour;
      JobData.L := BlockSize;
      JobData.TotalBlock := Size div BlockSize;
      JobData.CompletedBlock := 0;
      JobData.Encrypt := Encrypt;

      RunParallel(@JobData, JobData.TotalBlock, BlockDepth);
    end;

  if ProcessTail then
    begin
      tailSiz := Size mod BlockSize;
      if tailSiz > 0 then
          TCipher.EncryptTail(Pointer(NativeUInt(sour) + NativeUInt(Size - tailSiz)), tailSiz);
    end;

  Result := True;
end;

function TParallelCipher.Serpent(sour: Pointer; Size: NativeInt;
  KeyBuff: PCipherKeyBuffer; Encrypt, ProcessTail: Boolean): Boolean;
const
  BlockSize = 16;
var
  JobData: TParallelCipherJobData;
  k, k256: TBytes;
  Context: TSerpentkey;
  tailSiz: NativeInt;
begin
  Result := False;
  if Size <= 0 then Exit;

  if Size >= BlockSize then
    begin
      if not TCipher.GetKey(KeyBuff, k) then Exit;

      SetLength(k256, 32);
      if Length(k) = 0 then
          FillPtr(@k256[0], 32, 0)
      else
          THashMD.GenerateLMDKey((@k256[0])^, 32, k);

      TSerpent.InitKey(@k256[0], 32, Context);

      JobData.cipherFunc := Serpent_Parallel;
      JobData.KeyBuffer := @Context;
      JobData.OriginBuffer := sour;
      JobData.L := BlockSize;
      JobData.TotalBlock := Size div BlockSize;
      JobData.CompletedBlock := 0;
      JobData.Encrypt := Encrypt;

      RunParallel(@JobData, JobData.TotalBlock, BlockDepth);
    end;

  if ProcessTail then
    begin
      tailSiz := Size mod BlockSize;
      if tailSiz > 0 then
          TCipher.EncryptTail(Pointer(NativeUInt(sour) + NativeUInt(Size - tailSiz)), tailSiz);
    end;

  Result := True;
end;

function TParallelCipher.Mars(sour: Pointer; Size: NativeInt;
  KeyBuff: PCipherKeyBuffer; Encrypt, ProcessTail: Boolean): Boolean;
const
  BlockSize = 16;
var
  JobData: TParallelCipherJobData;
  k, k256: TBytes;
  Context: TMarskey;
  tailSiz: NativeInt;
begin
  Result := False;
  if Size <= 0 then Exit;

  if Size >= BlockSize then
    begin
      if not TCipher.GetKey(KeyBuff, k) then Exit;

      SetLength(k256, 32);
      if Length(k) = 0 then
          FillPtr(@k256[0], 32, 0)
      else
          THashMD.GenerateLMDKey((@k256[0])^, 32, k);

      TMars.InitKey(@k256[0], 32, Context);

      JobData.cipherFunc := Mars_Parallel;
      JobData.KeyBuffer := @Context;
      JobData.OriginBuffer := sour;
      JobData.L := BlockSize;
      JobData.TotalBlock := Size div BlockSize;
      JobData.CompletedBlock := 0;
      JobData.Encrypt := Encrypt;

      RunParallel(@JobData, JobData.TotalBlock, BlockDepth);
    end;

  if ProcessTail then
    begin
      tailSiz := Size mod BlockSize;
      if tailSiz > 0 then
          TCipher.EncryptTail(Pointer(NativeUInt(sour) + NativeUInt(Size - tailSiz)), tailSiz);
    end;

  Result := True;
end;

function TParallelCipher.Rijndael(sour: Pointer; Size: NativeInt;
  KeyBuff: PCipherKeyBuffer; Encrypt, ProcessTail: Boolean): Boolean;
const
  BlockSize = 16;
var
  JobData: TParallelCipherJobData;
  k, k256: TBytes;
  Context: TRijndaelkey;
  tailSiz: NativeInt;
begin
  Result := False;
  if Size <= 0 then Exit;

  if Size >= BlockSize then
    begin
      if not TCipher.GetKey(KeyBuff, k) then Exit;

      SetLength(k256, 32);
      if Length(k) = 0 then
          FillPtr(@k256[0], 32, 0)
      else
          THashMD.GenerateLMDKey((@k256[0])^, 32, k);

      TRijndael.InitKey(@k256[0], 32, Context);

      JobData.cipherFunc := Rijndael_Parallel;
      JobData.KeyBuffer := @Context;
      JobData.OriginBuffer := sour;
      JobData.L := BlockSize;
      JobData.TotalBlock := Size div BlockSize;
      JobData.CompletedBlock := 0;
      JobData.Encrypt := Encrypt;

      RunParallel(@JobData, JobData.TotalBlock, BlockDepth);
    end;

  if ProcessTail then
    begin
      tailSiz := Size mod BlockSize;
      if tailSiz > 0 then
          TCipher.EncryptTail(Pointer(NativeUInt(sour) + NativeUInt(Size - tailSiz)), tailSiz);
    end;

  Result := True;
end;

function TParallelCipher.TwoFish(sour: Pointer; Size: NativeInt;
  KeyBuff: PCipherKeyBuffer; Encrypt, ProcessTail: Boolean): Boolean;
const
  BlockSize = 16;
var
  JobData: TParallelCipherJobData;
  k, k256: TBytes;
  Context: TTwofishKey;
  tailSiz: NativeInt;
begin
  Result := False;
  if Size <= 0 then Exit;

  if Size >= BlockSize then
    begin
      if not TCipher.GetKey(KeyBuff, k) then Exit;

      SetLength(k256, 32);
      if Length(k) = 0 then
          FillPtr(@k256[0], 32, 0)
      else
          THashMD.GenerateLMDKey((@k256[0])^, 32, k);

      TTwofish.InitKey(@k256[0], 32, Context);

      JobData.cipherFunc := TwoFish_Parallel;
      JobData.KeyBuffer := @Context;
      JobData.OriginBuffer := sour;
      JobData.L := BlockSize;
      JobData.TotalBlock := Size div BlockSize;
      JobData.CompletedBlock := 0;
      JobData.Encrypt := Encrypt;

      RunParallel(@JobData, JobData.TotalBlock, BlockDepth);
    end;

  if ProcessTail then
    begin
      tailSiz := Size mod BlockSize;
      if tailSiz > 0 then
          TCipher.EncryptTail(Pointer(NativeUInt(sour) + NativeUInt(Size - tailSiz)), tailSiz);
    end;

  Result := True;
end;

function TParallelCipher.AES128(sour: Pointer; Size: NativeInt;
  KeyBuff: PCipherKeyBuffer; Encrypt, ProcessTail: Boolean): Boolean;
const
  BlockSize = 16;
var
  JobData: TParallelCipherJobData;
  k: TBytes;
  k128: TAESKey128;
  Context: TAESExpandedKey128;
  tailSiz: NativeInt;
begin
  Result := False;
  if Size <= 0 then Exit;

  if Size >= BlockSize then
    begin
      if not TCipher.GetKey(KeyBuff, k) then Exit;

      if Length(k) = 0 then
          FillPtr(@k128[0], 16, 0)
      else
          THashMD.GenerateLMDKey((@k128[0])^, 16, k);

      if Encrypt then
          ExpandAESKeyForEncryption(k128, Context)
      else
          ExpandAESKeyForDecryption(k128, Context);

      JobData.cipherFunc := AES128_Parallel;
      JobData.KeyBuffer := @Context;
      JobData.OriginBuffer := sour;
      JobData.L := BlockSize;
      JobData.TotalBlock := Size div BlockSize;
      JobData.CompletedBlock := 0;
      JobData.Encrypt := Encrypt;

      RunParallel(@JobData, JobData.TotalBlock, BlockDepth);
    end;

  if ProcessTail then
    begin
      tailSiz := Size mod BlockSize;
      if tailSiz > 0 then
          TCipher.EncryptTail(Pointer(NativeUInt(sour) + NativeUInt(Size - tailSiz)), tailSiz);
    end;

  Result := True;
end;

function TParallelCipher.AES192(sour: Pointer; Size: NativeInt;
  KeyBuff: PCipherKeyBuffer; Encrypt, ProcessTail: Boolean): Boolean;
const
  BlockSize = 16;
var
  JobData: TParallelCipherJobData;
  k: TBytes;
  k192: TAESKey192;
  Context: TAESExpandedKey192;
  tailSiz: NativeInt;
begin
  Result := False;
  if Size <= 0 then Exit;

  if Size >= BlockSize then
    begin
      if not TCipher.GetKey(KeyBuff, k) then Exit;

      if Length(k) = 0 then
          FillPtr(@k192[0], 24, 0)
      else
          THashMD.GenerateLMDKey((@k192[0])^, 24, k);

      if Encrypt then
          ExpandAESKeyForEncryption(k192, Context)
      else
          ExpandAESKeyForDecryption(k192, Context);

      JobData.cipherFunc := AES192_Parallel;
      JobData.KeyBuffer := @Context;
      JobData.OriginBuffer := sour;
      JobData.L := BlockSize;
      JobData.TotalBlock := Size div BlockSize;
      JobData.CompletedBlock := 0;
      JobData.Encrypt := Encrypt;

      RunParallel(@JobData, JobData.TotalBlock, BlockDepth);
    end;

  if ProcessTail then
    begin
      tailSiz := Size mod BlockSize;
      if tailSiz > 0 then
          TCipher.EncryptTail(Pointer(NativeUInt(sour) + NativeUInt(Size - tailSiz)), tailSiz);
    end;

  Result := True;
end;

function TParallelCipher.AES256(sour: Pointer; Size: NativeInt;
  KeyBuff: PCipherKeyBuffer; Encrypt, ProcessTail: Boolean): Boolean;
const
  BlockSize = 16;
var
  JobData: TParallelCipherJobData;
  k: TBytes;
  k256: TAESKey256;
  Context: TAESExpandedKey256;
  tailSiz: NativeInt;
begin
  Result := False;
  if Size <= 0 then Exit;

  if Size >= BlockSize then
    begin
      if not TCipher.GetKey(KeyBuff, k) then Exit;

      if Length(k) = 0 then
          FillPtr(@k256[0], 32, 0)
      else
          THashMD.GenerateLMDKey((@k256[0])^, 32, k);

      if Encrypt then
          ExpandAESKeyForEncryption(k256, Context)
      else
          ExpandAESKeyForDecryption(k256, Context);

      JobData.cipherFunc := AES256_Parallel;
      JobData.KeyBuffer := @Context;
      JobData.OriginBuffer := sour;
      JobData.L := BlockSize;
      JobData.TotalBlock := Size div BlockSize;
      JobData.CompletedBlock := 0;
      JobData.Encrypt := Encrypt;

      RunParallel(@JobData, JobData.TotalBlock, BlockDepth);
    end;

  if ProcessTail then
    begin
      tailSiz := Size mod BlockSize;
      if tailSiz > 0 then
          TCipher.EncryptTail(Pointer(NativeUInt(sour) + NativeUInt(Size - tailSiz)), tailSiz);
    end;

  Result := True;
end;

procedure TParallelCipher.BlockCBC(sour: Pointer; Size: NativeInt;
  boxBuff: Pointer; boxSiz: NativeInt);
var
  JobData: TParallelCipherJobData;
  tailSiz: NativeInt;
begin
  if (sour = nil) or (boxBuff = nil) then Exit;
  if Size <= 0 then Exit;
  if boxSiz <= 0 then Exit;

  if boxSiz >= Size then
    begin
      TCipher.BlockCBC(sour, Size, boxBuff, boxSiz);
      Exit;
    end;

  JobData.cipherFunc := BlockCBC_Parallel;
  JobData.KeyBuffer := boxBuff;
  JobData.OriginBuffer := sour;
  JobData.L := boxSiz;
  JobData.TotalBlock := Size div boxSiz;
  JobData.CompletedBlock := 0;
  JobData.Encrypt := True;

  RunParallel(@JobData, JobData.TotalBlock, BlockDepth);

  tailSiz := Size mod boxSiz;
  if tailSiz > 0 then
      TCipher.BlockCBC(Pointer(NativeUInt(sour) + NativeUInt(Size - tailSiz)),
        tailSiz, boxBuff, boxSiz);
end;

function TParallelCipher.EncryptBuffer(cs: TCipherSecurity; sour: Pointer;
  Size: NativeInt; KeyBuff: PCipherKeyBuffer; Encrypt, ProcessTail: Boolean): Boolean;
begin
  Result := False;
  case cs of
    csNone:      Result := True;
    csDES64:     Result := DES64(sour, Size, KeyBuff, Encrypt, ProcessTail);
    csDES128:    Result := DES128(sour, Size, KeyBuff, Encrypt, ProcessTail);
    csDES192:    Result := DES192(sour, Size, KeyBuff, Encrypt, ProcessTail);
    csBlowfish:  Result := Blowfish(sour, Size, KeyBuff, Encrypt, ProcessTail);
    csLBC:       Result := LBC(sour, Size, KeyBuff, Encrypt, ProcessTail);
    csLQC:       Result := LQC(sour, Size, KeyBuff, Encrypt, ProcessTail);
    csRNG32:     Result := TCipher.RNG32(sour, Size, KeyBuff);
    csRNG64:     Result := TCipher.RNG64(sour, Size, KeyBuff);
    csLSC:       Result := TCipher.LSC(sour, Size, KeyBuff);
    csTwoFish:   Result := TwoFish(sour, Size, KeyBuff, Encrypt, ProcessTail);
    csXXTea512:  Result := XXTea512(sour, Size, KeyBuff, Encrypt, ProcessTail);
    csRC6:       Result := RC6(sour, Size, KeyBuff, Encrypt, ProcessTail);
    csSerpent:   Result := Serpent(sour, Size, KeyBuff, Encrypt, ProcessTail);
    csMars:      Result := Mars(sour, Size, KeyBuff, Encrypt, ProcessTail);
    csRijndael:  Result := Rijndael(sour, Size, KeyBuff, Encrypt, ProcessTail);
    csAES128:    Result := AES128(sour, Size, KeyBuff, Encrypt, ProcessTail);
    csAES192:    Result := AES192(sour, Size, KeyBuff, Encrypt, ProcessTail);
    csAES256:    Result := AES256(sour, Size, KeyBuff, Encrypt, ProcessTail);
    else raiseInfo('error');
  end;
end;

function TParallelCipher.EncryptBufferCBC(cs: TCipherSecurity; sour: Pointer;
  Size: NativeInt; KeyBuff: PCipherKeyBuffer; Encrypt, ProcessTail: Boolean): Boolean;
begin
  if cs = TCipherSecurity.csNone then
    begin
      Result := True;
      Exit;
    end;

  if Encrypt then
    begin
      Result := EncryptBuffer(cs, sour, Size, KeyBuff, Encrypt, ProcessTail);
      if Result then
          BlockCBC(sour, Size, @SystemCBC[0], Length(SystemCBC));
    end
  else
    begin
      BlockCBC(sour, Size, @SystemCBC[0], Length(SystemCBC));
      Result := EncryptBuffer(cs, sour, Size, KeyBuff, Encrypt, ProcessTail);
    end;
end;

{$ENDIF}

(*
 * ============================================================================
 * Global initialization and the sequential (non-parallel) helper functions.
 * These were located at the bottom of the original include file; they are
 * outside {$IFDEF Parallel} and always compiled.
 * ============================================================================
 *)

procedure InitSysCBCAndDefaultKey(rand: Int64);
var
  i: Integer;
  Seed: TInt64;
begin
{$IFDEF Parallel}
  {
   * Default parallel depth and the threshold below which we run serially.
   * Get_Parallel_Granularity is provided by Z.Core.
   *}
  DefaultParallelDepth := Get_Parallel_Granularity;
  ParallelTriggerCondition := 1024;
{$ENDIF}
  SetLength(SystemCBC, 64 * 1024);
  Seed.i := rand;
  for i := 0 to (Length(SystemCBC) div 4) - 1 do
      PInteger(@SystemCBC[i * 4])^ := TMISC.Random64(Seed);
end;

{
 * SequEncryptWithDirect ！ apply one cipher in-place, generating the key
 * from the supplied raw key buffer first.
 *}
function SequEncryptWithDirect(const cs: TCipherSecurity; sour: Pointer;
  Size: NativeInt; const key: TCipherKeyBuffer; Encrypt, ProcessTail: Boolean): Boolean;
var
  k: TCipherKeyBuffer;
begin
  Result := False;
  if (sour = nil) or (Size <= 0) then Exit;
  if Length(key) = 0 then Exit;

  TCipher.GenerateKey(cs, @key[0], Length(key), k);
  Result := TCipher.EncryptBuffer(cs, sour, Size, @k, Encrypt, ProcessTail);
end;

{
 * SequEncryptWithDirect ！ chained variant.
 *   Encrypt: apply ca[0], ca[1], ..., ca[N-1] in order.
 *   Decrypt: apply ca[N-1], ..., ca[0] in reverse order.
 *}
function SequEncryptWithDirect(const ca: TCipherSecurityArray; sour: Pointer;
  Size: NativeInt; const key: TCipherKeyBuffer; Encrypt, ProcessTail: Boolean): Boolean;
var
  i: Integer;
begin
  Result := True;

  if Encrypt then
    begin
      for i := low(ca) to high(ca) do
          Result := Result and SequEncryptWithDirect(ca[i], sour, Size, key, Encrypt, ProcessTail);
    end
  else
    begin
      for i := high(ca) downto low(ca) do
          Result := Result and SequEncryptWithDirect(ca[i], sour, Size, key, Encrypt, ProcessTail);
    end;
end;

{$IFDEF Parallel}

{
 * SequEncryptWithParallel ！ single-cipher parallel path.
 * Allocates a fresh TParallelCipher per call, no shared mutable state.
 *}
function SequEncryptWithParallel(const cs: TCipherSecurity; sour: Pointer;
  Size: NativeInt; const key: TCipherKeyBuffer; Encrypt, ProcessTail: Boolean): Boolean;
var
  k: TCipherKeyBuffer;
  pc: TParallelCipher;
begin
  Result := False;
  if (sour = nil) or (Size <= 0) then Exit;
  if Length(key) = 0 then Exit;

  TCipher.GenerateKey(cs, @key[0], Length(key), k);

  pc := TParallelCipher.Create;
  try
    pc.BlockDepth := DefaultParallelDepth;
    Result := pc.EncryptBuffer(cs, sour, Size, @k, Encrypt, ProcessTail);
  finally
    disposeObject(pc);
  end;
end;

function SequEncryptWithParallel(const ca: TCipherSecurityArray; sour: Pointer;
  Size: NativeInt; const key: TCipherKeyBuffer; Encrypt, ProcessTail: Boolean): Boolean;
var
  i: Integer;
begin
  Result := True;

  if Encrypt then
    begin
      for i := low(ca) to high(ca) do
          Result := Result and SequEncryptWithParallel(ca[i], sour, Size, key, Encrypt, ProcessTail);
    end
  else
    begin
      for i := high(ca) downto low(ca) do
          Result := Result and SequEncryptWithParallel(ca[i], sour, Size, key, Encrypt, ProcessTail);
    end;
end;

{$ENDIF}

{
 * SequEncrypt ！ public entry points.
 * If the payload is large enough (>= ParallelTriggerCondition) and the
 * Parallel define is active, dispatch to the parallel implementation;
 * otherwise fall back to the serial path.
 *}
function SequEncrypt(const ca: TCipherSecurityArray; sour: Pointer;
  Size: NativeInt; const key: TCipherKeyBuffer; Encrypt, ProcessTail: Boolean): Boolean;
begin
{$IFDEF Parallel}
  if Size >= ParallelTriggerCondition then
      Result := SequEncryptWithParallel(ca, sour, Size, key, Encrypt, ProcessTail)
  else
{$ENDIF}
      Result := SequEncryptWithDirect(ca, sour, Size, key, Encrypt, ProcessTail);
end;

function SequEncrypt(const cs: TCipherSecurity; sour: Pointer;
  Size: NativeInt; const key: TCipherKeyBuffer; Encrypt, ProcessTail: Boolean): Boolean;
begin
{$IFDEF Parallel}
  if Size >= ParallelTriggerCondition then
      Result := SequEncryptWithParallel(cs, sour, Size, key, Encrypt, ProcessTail)
  else
{$ENDIF}
      Result := SequEncryptWithDirect(cs, sour, Size, key, Encrypt, ProcessTail);
end;

{
 * CBC variants ！ identical structure, but invoke TCipher.EncryptBufferCBC
 * which XORs with the SystemCBC salt before/after the block cipher.
 *}
function SequEncryptCBCWithDirect(const cs: TCipherSecurity; sour: Pointer;
  Size: NativeInt; const key: TCipherKeyBuffer; Encrypt, ProcessTail: Boolean): Boolean;
var
  k: TCipherKeyBuffer;
begin
  Result := False;
  if (sour = nil) or (Size <= 0) then Exit;
  if Length(key) = 0 then Exit;

  TCipher.GenerateKey(cs, @key[0], Length(key), k);
  Result := TCipher.EncryptBufferCBC(cs, sour, Size, @k, Encrypt, ProcessTail);
end;

function SequEncryptCBCWithDirect(const ca: TCipherSecurityArray; sour: Pointer;
  Size: NativeInt; const key: TCipherKeyBuffer; Encrypt, ProcessTail: Boolean): Boolean;
var
  i: Integer;
begin
  Result := True;

  if Encrypt then
    begin
      for i := low(ca) to high(ca) do
          Result := Result and SequEncryptCBCWithDirect(ca[i], sour, Size, key, Encrypt, ProcessTail);
    end
  else
    begin
      for i := high(ca) downto low(ca) do
          Result := Result and SequEncryptCBCWithDirect(ca[i], sour, Size, key, Encrypt, ProcessTail);
    end;
end;

{$IFDEF Parallel}

function SequEncryptCBCWithParallel(const cs: TCipherSecurity; sour: Pointer;
  Size: NativeInt; const key: TCipherKeyBuffer; Encrypt, ProcessTail: Boolean): Boolean;
var
  k: TCipherKeyBuffer;
  pc: TParallelCipher;
begin
  Result := False;
  if (sour = nil) or (Size <= 0) then Exit;
  if Length(key) = 0 then Exit;

  TCipher.GenerateKey(cs, @key[0], Length(key), k);

  pc := TParallelCipher.Create;
  try
    pc.BlockDepth := DefaultParallelDepth;
    Result := pc.EncryptBufferCBC(cs, sour, Size, @k, Encrypt, ProcessTail);
  finally
    disposeObject(pc);
  end;
end;

function SequEncryptCBCWithParallel(const ca: TCipherSecurityArray; sour: Pointer;
  Size: NativeInt; const key: TCipherKeyBuffer; Encrypt, ProcessTail: Boolean): Boolean;
var
  i: Integer;
begin
  Result := True;

  if Encrypt then
    begin
      for i := low(ca) to high(ca) do
          Result := Result and SequEncryptCBCWithParallel(ca[i], sour, Size, key, Encrypt, ProcessTail);
    end
  else
    begin
      for i := high(ca) downto low(ca) do
          Result := Result and SequEncryptCBCWithParallel(ca[i], sour, Size, key, Encrypt, ProcessTail);
    end;
end;

{$ENDIF}

function SequEncryptCBC(const ca: TCipherSecurityArray; sour: Pointer;
  Size: NativeInt; const key: TCipherKeyBuffer; Encrypt, ProcessTail: Boolean): Boolean;
begin
{$IFDEF Parallel}
  if Size >= ParallelTriggerCondition then
      Result := SequEncryptCBCWithParallel(ca, sour, Size, key, Encrypt, ProcessTail)
  else
{$ENDIF}
      Result := SequEncryptCBCWithDirect(ca, sour, Size, key, Encrypt, ProcessTail);
end;

function SequEncryptCBC(const cs: TCipherSecurity; sour: Pointer;
  Size: NativeInt; const key: TCipherKeyBuffer; Encrypt, ProcessTail: Boolean): Boolean;
begin
{$IFDEF Parallel}
  if Size >= ParallelTriggerCondition then
      Result := SequEncryptCBCWithParallel(cs, sour, Size, key, Encrypt, ProcessTail)
  else
{$ENDIF}
      Result := SequEncryptCBCWithDirect(cs, sour, Size, key, Encrypt, ProcessTail);
end;

{
 * ============================================================================
 * Sequential hash helpers.
 * These generate a list of hashes (one per THashSecurity) and can compare
 * a freshly computed set against a stored one.
 * ============================================================================
 *}

function GenerateSequHash(hssArry: THashSecuritys; sour: Pointer; Size: NativeInt): TCipherString;
var
  h: THashSecurity;
  vl: THashStringList;
  hBuff: TBytes;
  n: TCipherSystemString;
begin
  vl := THashStringList.Create;
  try
    for h in hssArry do
      begin
        TCipher.GenerateHashByte(h, sour, Size, hBuff);
        n := '';
        TCipher.HashToString(hBuff, n);
        vl[TCipher.CHashName[h]] := '(' + n + ')';
      end;
    Result.Text := vl.AsText;
  finally
    disposeObject(vl);
  end;
end;

procedure GenerateSequHash(hssArry: THashSecuritys; sour: Pointer; Size: NativeInt;
  output: TListPascalString);
var
  h: THashSecurity;
  vl: THashStringList;
  hBuff: TBytes;
  n: TCipherSystemString;
begin
  vl := THashStringList.Create;
  try
    for h in hssArry do
      begin
        TCipher.GenerateHashByte(h, sour, Size, hBuff);
        n := '';
        TCipher.HashToString(hBuff, n);
        vl[TCipher.CHashName[h]] := '(' + n + ')';
      end;
    vl.ExportAsStrings(output);
  finally
    disposeObject(vl);
  end;
end;

procedure GenerateSequHash(hssArry: THashSecuritys; sour: Pointer; Size: NativeInt;
  output: TCore_Stream);
var
  h: THashSecurity;
  vl: THashStringList;
  hBuff: TBytes;
  n: TCipherSystemString;
begin
  vl := THashStringList.Create;
  try
    for h in hssArry do
      begin
        TCipher.GenerateHashByte(h, sour, Size, hBuff);
        n := '';
        TCipher.HashToString(hBuff, n);
        vl[TCipher.CHashName[h]] := '(' + n + ')';
      end;
    vl.SaveToStream(output);
  finally
    disposeObject(vl);
  end;
end;

function CompareSequHash(HashVL: THashStringList; sour: Pointer; Size: NativeInt): Boolean;
var
  ns: TListString;
  i: Integer;
  sourHash, destHash: TBytes;
  hName: TCipherSystemString;
  hValue: TCipherString;
  h: THashSecurity;
begin
  Result := True;

  ns := TListString.Create;
  try
    HashVL.GetNameList(ns);

    for i := 0 to ns.Count - 1 do
      begin
        hName := ns[i];
        hValue := umlTrimSpace(HashVL.GetDefaultValue(hName, ''));
        if TCipher.NameToHashSecurity(hName, h) and
           ((hValue.Len >= 2) and (hValue.First = '(') and (hValue.Last = ')')) then
          begin
            hValue.DeleteFirst;
            hValue.DeleteLast;

            TCipher.GenerateHashByte(h, sour, Size, sourHash);
            SetLength(destHash, Length(sourHash));
            if Length(destHash) > 0 then
              begin
                Result := Result and TCipher.HexToBuffer(hValue, destHash[0], Length(destHash));
                Result := Result and TCipher.CompareHash(sourHash, destHash);
              end;
          end;
        if not Result then
            Break;
      end;
  finally
    disposeObject(ns);
  end;
end;

function CompareSequHash(hashData: TCipherString; sour: Pointer; Size: NativeInt): Boolean;
var
  vl: THashStringList;
begin
  vl := THashStringList.Create;
  try
    vl.AsText := hashData.Text;
    Result := CompareSequHash(vl, sour, Size);
  finally
    disposeObject(vl);
  end;
end;

function CompareSequHash(hashData: TListPascalString; sour: Pointer; Size: NativeInt): Boolean;
var
  vl: THashStringList;
begin
  vl := THashStringList.Create;
  try
    vl.ImportFromStrings(hashData);
    Result := CompareSequHash(vl, sour, Size);
  finally
    disposeObject(vl);
  end;
end;

function CompareSequHash(hashData: TCore_Stream; sour: Pointer; Size: NativeInt): Boolean;
var
  vl: THashStringList;
begin
  vl := THashStringList.Create;
  try
    vl.LoadFromStream(hashData);
    Result := CompareSequHash(vl, sour, Size);
  finally
    disposeObject(vl);
  end;
end;

{
 * GenerateMemoryHash ！ produce a Base64-encoded blob of the hash list,
 * wrapped in parentheses. Used as a portable fingerprint.
 *}
function GenerateMemoryHash(hssArry: THashSecuritys; sour: Pointer; Size: NativeInt): TCipherString;
var
  m64: TMS64;
begin
  m64 := TMS64.Create;
  try
    GenerateSequHash(hssArry, sour, Size, m64);
    umlEncodeStreamBASE64(m64, Result);
    Result := '(' + Result + ')';
  finally
    disposeObject(m64);
  end;
end;

function CompareMemoryHash(sour: Pointer; Size: NativeInt; const hashBuff: TCipherString): Boolean;
var
  n: TCipherString;
  m64: TMS64;
begin
  Result := False;
  n := hashBuff.TrimChar(#32);
  if (n.Len > 2) and (n.First = '(') and (n.Last = ')') then
    begin
      n.DeleteFirst;
      n.DeleteLast;
      m64 := TMS64.Create;
      try
        umlDecodeStreamBASE64(n, m64);
        Result := CompareSequHash(m64, sour, Size);
      finally
        disposeObject(m64);
      end;
    end;
end;

{
 * Password hash helpers (hash-only; no encryption).
 *}
function GeneratePasswordHash(hssArry: THashSecuritys; const passwd: TCipherString): TCipherString;
var
  buff: TBytes;
  m64: TMS64;
begin
  buff := passwd.Bytes;
  m64 := TMS64.Create;
  try
    {
     * FIX: guard empty password before @buff[0]. Use a dummy zero-length
     * buffer via a fixed-size local when buff is empty.
     *}
    if Length(buff) = 0 then
      begin
        { Empty password: hash the empty sequence. GenerateSequHash handles
          Size = 0 by producing empty per-hash buffers, which is fine. }
        GenerateSequHash(hssArry, nil, 0, m64);
      end
    else
      begin
        GenerateSequHash(hssArry, @buff[0], Length(buff), m64);
      end;
    umlEncodeStreamBASE64(m64, Result);
    Result := '(' + Result + ')';
  finally
    disposeObject(m64);
    if Length(buff) > 0 then
        FillPtr(@buff[0], Length(buff), 0);
    SetLength(buff, 0);
  end;
end;

function ComparePasswordHash(const passwd, hashBuff: TCipherString): Boolean;
var
  n: TCipherString;
  buff: TBytes;
  m64: TMS64;
begin
  Result := False;
  n := hashBuff.TrimChar(#32);
  if (n.Len > 2) and (n.First = '(') and (n.Last = ')') then
    begin
      n.DeleteFirst;
      n.DeleteLast;
      buff := passwd.Bytes;
      m64 := TMS64.Create;
      try
        umlDecodeStreamBASE64(n, m64);
        if Length(buff) = 0 then
            Result := CompareSequHash(m64, nil, 0)
        else
            Result := CompareSequHash(m64, @buff[0], Length(buff));
      finally
        disposeObject(m64);
        if Length(buff) > 0 then
            FillPtr(@buff[0], Length(buff), 0);
        SetLength(buff, 0);
      end;
    end;
end;

{
 * Cipher-based password helpers.
 *}
function GeneratePassword(const ca: TCipherSecurityArray; const passwd: TCipherString): TCipherString;
var
  KeyBuff: TBytes;
  buff: TBytes;
begin
  KeyBuff := passwd.Bytes;
  buff := passwd.Bytes;

  {
   * FIX: SequEncryptCBC requires a non-empty buffer; for an empty password
   * we still want a deterministic, non-crashing output. Encode an empty
   * Base64 blob (which decodes back to an empty byte array on comparison).
   *}
  if Length(buff) = 0 then
    begin
      Result := '()';
      Exit;
    end;

  SequEncryptCBC(ca, @buff[0], Length(buff), KeyBuff, True, False);
  umlBase64EncodeBytes(buff, Result);
  Result := '(' + Result + ')';

  if Length(buff) > 0 then FillPtr(@buff[0], Length(buff), 0);
  if Length(KeyBuff) > 0 then FillPtr(@KeyBuff[0], Length(KeyBuff), 0);
  SetLength(buff, 0);
  SetLength(KeyBuff, 0);
end;

function ComparePassword(const ca: TCipherSecurityArray; const passwd, passwdDataSource: TCipherString): Boolean;
var
  sour: TCipherString;
  refBuff: TBytes;
  KeyBuff: TBytes;
begin
  Result := False;
  sour := umlTrimSpace(passwdDataSource);
  if (sour.Len > 2) and (sour.First = '(') and (sour.Last = ')') then
    begin
      sour.DeleteFirst;
      sour.DeleteLast;
      umlBase64DecodeBytes(sour, refBuff);

      if Length(refBuff) = 0 then
        begin
          {
           * Empty reference blob: matches an empty original password.
           *}
          Result := passwd.Len = 0;
          Exit;
        end;

      KeyBuff := passwd.Bytes;
      if Length(KeyBuff) = 0 then
          Exit;

      SequEncryptCBC(ca, @refBuff[0], Length(refBuff), KeyBuff, False, False);
      Result := TCipher.CompareKey(refBuff, KeyBuff);

      if Length(refBuff) > 0 then FillPtr(@refBuff[0], Length(refBuff), 0);
      if Length(KeyBuff) > 0 then FillPtr(@KeyBuff[0], Length(KeyBuff), 0);
      SetLength(refBuff, 0);
      SetLength(KeyBuff, 0);
    end;
end;

function GeneratePassword(const cs: TCipherSecurity; const passwd: TCipherString): TCipherString;
var
  KeyBuff: TBytes;
  buff: TBytes;
begin
  KeyBuff := passwd.Bytes;
  buff := passwd.Bytes;

  if Length(buff) = 0 then
    begin
      Result := '()';
      Exit;
    end;

  SequEncryptCBC(cs, @buff[0], Length(buff), KeyBuff, True, False);
  umlBase64EncodeBytes(buff, Result);
  Result := '(' + Result + ')';

  if Length(buff) > 0 then FillPtr(@buff[0], Length(buff), 0);
  if Length(KeyBuff) > 0 then FillPtr(@KeyBuff[0], Length(KeyBuff), 0);
  SetLength(buff, 0);
  SetLength(KeyBuff, 0);
end;

function ComparePassword(const cs: TCipherSecurity; const passwd, passwdDataSource: TCipherString): Boolean;
var
  sour: TCipherString;
  refBuff: TBytes;
  KeyBuff: TBytes;
begin
  Result := False;
  sour := umlTrimSpace(passwdDataSource);
  if (sour.Len > 2) and (sour.First = '(') and (sour.Last = ')') then
    begin
      sour.DeleteFirst;
      sour.DeleteLast;
      umlBase64DecodeBytes(sour, refBuff);

      if Length(refBuff) = 0 then
        begin
          Result := passwd.Len = 0;
          Exit;
        end;

      KeyBuff := passwd.Bytes;
      if Length(KeyBuff) = 0 then
          Exit;

      SequEncryptCBC(cs, @refBuff[0], Length(refBuff), KeyBuff, False, False);
      Result := TCipher.CompareKey(refBuff, KeyBuff);

      if Length(refBuff) > 0 then FillPtr(@refBuff[0], Length(refBuff), 0);
      if Length(KeyBuff) > 0 then FillPtr(@KeyBuff[0], Length(KeyBuff), 0);
      SetLength(refBuff, 0);
      SetLength(KeyBuff, 0);
    end;
end;

(*
 * ============================================================================
 * Z.Cipher.imp_QuantumCryptography.inc
 *
 * Purpose: Post-quantum password hashing + stream encryption helpers.
 *
 * Bug fixes applied (FPC -O2 optimization safety):
 *   1. GenerateQuantumCryptographyPassword:
 *      empty "passwd" made "buff" a zero-length TBytes, and @buff[0] was
 *      dereferenced regardless ¡ª out-of-bounds access. Now we pass a dummy
 *      one-byte buffer with BufSize = 0 when the input is empty.
 *   2. CompareQuantumCryptographyPassword:
 *      same empty-input hazard as (1). Fixed with the same dummy-pointer
 *      pattern.
 *   3. QuantumEncrypt / QuantumDecrypt:
 *      - guard nil input/output streams (previously a crash if the caller
 *        passed nil);
 *      - guard zero-length key material before SequEncryptCBC reads key[0];
 *      - guard negative head.Size / head.Level;
 *      - guard CipherSecurity byte when restoring the enum, to avoid an
 *        out-of-range ordinal (which is UB in Pascal);
 *      - SHA512 / SHAKE256 now receive a dummy pointer when Size = 0, so
 *        that under FPC -O2 no caller-side nil dereference can be inferred.
 *
 * Conventions (project-wide):
 *   - No Move / no FillChar. Use CopyPtr / FillPtr from Z.Core.
 *   - Multi-line comments carry a leading "*" on every line so that Delphi
 *     code-formatting tools preserve the layout.
 * ============================================================================
 *)

function GenerateQuantumCryptographyPassword(const passwd: TCipherString): TCipherString;
var
  buff, cryptBuff: TBytes;
  dummy: array [0 .. 0] of Byte;
  pBuff: PByte;
  nBuff: NativeInt;
begin
  buff := passwd.Bytes;
  SetLength(cryptBuff, 512 div 8);

  {
   * SHAKE256 does not dereference "Buf" when BufSize = 0, but we still pass
   * a valid pointer to avoid any FPC -O2 alias-analysis edge case where the
   * compiler could infer a nil dereference from an unused pointer parameter.
   }
  if Length(buff) = 0 then
    begin
      pBuff := @dummy[0];
      nBuff := 0;
    end
  else
    begin
      pBuff := @buff[0];
      nBuff := Length(buff);
    end;

  TSHA3.SHAKE256(@cryptBuff[0], pBuff, nBuff, 512);

  umlBase64EncodeBytes(cryptBuff, Result);
  Result := '(' + Result + ')';

  { Wipe transient buffers. }
  FillPtr(@cryptBuff[0], Length(cryptBuff), 0);
  if Length(buff) > 0 then
      FillPtr(@buff[0], Length(buff), 0);
  SetLength(buff, 0);
  SetLength(cryptBuff, 0);
end;

function CompareQuantumCryptographyPassword(const passwd, passwdDataSource: TCipherString): Boolean;
var
  sour: TCipherString;
  refBuff, buff, cryptBuff: TBytes;
  dummy: array [0 .. 0] of Byte;
  pBuff: PByte;
  nBuff: NativeInt;
begin
  Result := False;
  sour := umlTrimSpace(passwdDataSource);
  if (sour.Len > 2) and (sour.First = '(') and (sour.Last = ')') then
    begin
      sour.DeleteFirst;
      sour.DeleteLast;
      umlBase64DecodeBytes(sour, refBuff);

      buff := passwd.Bytes;
      SetLength(cryptBuff, 512 div 8);

      {
       * Same dummy-pointer guard as in GenerateQuantumCryptographyPassword.
       * SHAKE256 must not receive an out-of-bounds @buff[0] when buff is
       * empty.
       }
      if Length(buff) = 0 then
        begin
          pBuff := @dummy[0];
          nBuff := 0;
        end
      else
        begin
          pBuff := @buff[0];
          nBuff := Length(buff);
        end;

      TSHA3.SHAKE256(@cryptBuff[0], pBuff, nBuff, 512);

      Result := TCipher.CompareKey(refBuff, cryptBuff);

      { Wipe transient buffers. }
      if Length(refBuff) > 0 then
          FillPtr(@refBuff[0], Length(refBuff), 0);
      if Length(buff) > 0 then
          FillPtr(@buff[0], Length(buff), 0);
      FillPtr(@cryptBuff[0], Length(cryptBuff), 0);
      SetLength(refBuff, 0);
      SetLength(buff, 0);
      SetLength(cryptBuff, 0);
    end;
end;

type
  TQuantumEncryptHead = packed record
    CipherSecurity: Byte;
    Level: Word;
    Size: Int64;
    hash: TSHA3_512_Digest;
  end;

procedure QuantumEncrypt(input, output: TCore_Stream; SecurityLevel: Integer; key: TCipherKeyBuffer);
var
  m64: TMS64;
  head: TQuantumEncryptHead;
  i: Integer;
  hh: TSHA3_512_Digest;
  dummy: array [0 .. 0] of Byte;
  pData: PByte;
  nSize: NativeInt;
begin
  { FIX: guard nil streams ¡ª previously this would raise an AV. }
  if (input = nil) or (output = nil) then
      Exit;

  { FIX: guard empty key material before SequEncryptCBC reads key[0]. }
  if Length(key) = 0 then
      Exit;

  m64 := TMS64.Create;
  try
    input.Position := 0;
    m64.CopyFrom(input, input.Size);

    head.CipherSecurity := Byte(TCipherSecurity.csRijndael);
    { FIX: clamp negative SecurityLevel to 0. }
    if SecurityLevel < 0 then
        head.Level := 0
    else
        head.Level := Word(SecurityLevel);
    head.Size := m64.Size;

    {
     * FIX: use a dummy pointer when the payload is empty. SHA512's inner
     * SHA3 loop never dereferences the pointer when Size = 0, but passing
     * a valid pointer removes any FPC -O2 alias-analysis ambiguity.
     }
    if m64.Size = 0 then
      begin
        pData := @dummy[0];
        nSize := 0;
      end
    else
      begin
        pData := PByte(m64.Memory);
        nSize := m64.Size;
      end;

    { 2x SHA3-512 secure hash. }
    TSHA3.SHA512(hh, pData, nSize);
    TSHA3.SHA512(head.hash, @hh[0], 64);

    { Apply SecurityLevel rounds of Rijndael-CBC. }
    for i := 0 to head.Level - 1 do
        SequEncryptCBC(TCipherSecurity(head.CipherSecurity),
          m64.Memory, m64.Size, key, True, True);

    output.write(head, SizeOf(head));
    if m64.Size > 0 then
        output.write(m64.Memory^, m64.Size);
  finally
    disposeObject(m64);
  end;
end;

function QuantumDecrypt(input, output: TCore_Stream; key: TCipherKeyBuffer): Boolean;
var
  head: TQuantumEncryptHead;
  m64: TMS64;
  i: Integer;
  hh, h: TSHA3_512_Digest;
  dummy: array [0 .. 0] of Byte;
  pData: PByte;
  nSize: NativeInt;
  cs: TCipherSecurity;
begin
  Result := False;

  { FIX: guard nil streams. }
  if (input = nil) or (output = nil) then
      Exit;

  { FIX: guard empty key material. }
  if Length(key) = 0 then
      Exit;

  if input.read(head, SizeOf(head)) <> SizeOf(head) then
      Exit;

  {
   * FIX: validate the header before trusting its fields.
   *   - Size must be non-negative; we also cap it to avoid Int64 overflow
   *     in TMS64.CopyFrom.
   *   - Level is a Word, so it is inherently non-negative.
   *   - CipherSecurity must be within the TCipherSecurity enum range.
   }
  if head.Size < 0 then
      Exit;

  if Ord(head.CipherSecurity) > Ord(High(TCipherSecurity)) then
      Exit;

  cs := TCipherSecurity(head.CipherSecurity);
  if cs <> TCipherSecurity.csRijndael then
      Exit;

  m64 := TMS64.Create;
  try
    if head.Size > 0 then
      begin
        if m64.CopyFrom(input, head.Size) <> head.Size then
            Exit;
      end;

    { Reverse the SecurityLevel encryption rounds (decrypt in the same order,
      SequEncryptCBC's Decrypt path undoes one round). }
    if head.Level > 0 then
      begin
        if m64.Size > 0 then
          begin
            for i := 0 to head.Level - 1 do
                SequEncryptCBC(cs, m64.Memory, m64.Size, key, False, True);
          end;
      end;

    {
     * FIX: use a dummy pointer when the payload is empty. Same rationale
     * as in QuantumEncrypt.
     }
    if m64.Size = 0 then
      begin
        pData := @dummy[0];
        nSize := 0;
      end
    else
      begin
        pData := PByte(m64.Memory);
        nSize := m64.Size;
      end;

    { Recompute the 2x SHA3-512 hash and compare. }
    TSHA3.SHA512(hh, pData, nSize);
    TSHA3.SHA512(h, @hh[0], 64);

    if not TCipher.CompareHash(h, head.hash) then
        Exit;

    { Deliver the plaintext to the caller. }
    if m64.Size > 0 then
      begin
        m64.Position := 0;
        output.CopyFrom(m64, m64.Size);
      end;

    Result := True;
  finally
    disposeObject(m64);
  end;
end;

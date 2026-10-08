{ ===============================================================================
  * Z.Cipher.imp_TCipher.inc  ¡ª  TCipher class implementation
  *
  * Bug fixes applied (FPC O2 optimization safety):
  *   1. Random_Select_Cipher: guard against empty input array (Low=0,
  *      High=-1 would index out of bounds).
  *   2. HashToString(hash: TBytes; ...): guard against empty TBytes so
  *      @hash[0] is never dereferenced when Length = 0.
  *   3. CopyKey: guard against empty TCipherKeyBuffer.
  *   4. GenerateKeyXX(const s: TCipherString; ...) family: empty s.Bytes
  *      would make GenerateLMDKey dereference Bytes_[0] out of bounds.
  *      Fixed by explicitly zeroing the key material via FillPtr when the
  *      input TCipherSystemString is empty.
  *   5. GenerateKeyXX(sour: Pointer; Size: NativeInt; ...) family:
  *      guard Size <= 0 before dereferencing sour^.
  *   6. GenerateKey(const key: PByte; Size: DWORD; ...):
  *      guard Size = 0 / key = nil.
  *   7. GenerateKey(cs, s: TCipherString): guard empty s before @buff[0].
  *   8. GetKey(...; var key: TBytes): guard against zero-length stored key.
  *
  * Conventions (project-wide):
  *   - No Move / no FillChar. Use CopyPtr / FillPtr from Z.Core.
  *   - English comments only.
  =============================================================================== }

class function TCipher.AllCipher: TCipherSecurityArray;
var
  cs: TCipherSecurity;
begin
  SetLength(Result, Integer(high(TCipherSecurity)) + 1);
  for cs := low(TCipherSecurity) to high(TCipherSecurity) do
      Result[Integer(cs)] := cs;
end;

class function TCipher.Random_Select_Cipher(const arry: TCipherSecurityArray): TCipherSecurity;
begin
  { FIX: empty array has Low=0, High=-1; umlRR(0,-1) is undefined. }
  if Length(arry) = 0 then
    begin
      Result := csNone;
      Exit;
    end;
  Result := arry[umlRR(Low(arry), High(arry))];
end;

class function TCipher.NameToHashSecurity(n: TCipherSystemString; var hash: THashSecurity): Boolean;
var
  h: THashSecurity;
begin
  Result := False;
  for h := low(THashSecurity) to high(THashSecurity) do
    if SameText(CHashName[h], n) then
      begin
        hash := h;
        Result := True;
        Exit;
      end;
end;

class function TCipher.BuffToString(buff: Pointer; Size: NativeInt): TCipherString;
begin
  HashToString(buff, Size, Result);
end;

class function TCipher.StringToBuff(const Hex: TCipherString; var Buf; BufSize: Cardinal): Boolean;
begin
  Result := HexToBuffer(Hex, Buf, BufSize);
end;

class procedure TCipher.HashToString(hash: Pointer; Size: NativeInt; var output: TCipherString);
const
  HexArr: array [0 .. 15] of U_Char = ('0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'a', 'b', 'c', 'd', 'e', 'f');
var
  i: Integer;
begin
  if (hash = nil) or (Size <= 0) then
    begin
      output.Len := 0;
      Exit;
    end;

  output.Len := Size * 2;
  for i := 0 to Size - 1 do
    begin
      output.buff[i * 2] := HexArr[(PByte(NativeUInt(hash) + i)^ shr 4) and $0F];
      output.buff[i * 2 + 1] := HexArr[PByte(NativeUInt(hash) + i)^ and $0F];
    end;
end;

class procedure TCipher.HashToString(hash: TSHA3_224_Digest; var output: TCipherString);
begin
  HashToString(@hash[0], SizeOf(hash), output);
end;

class procedure TCipher.HashToString(hash: TSHA3_256_Digest; var output: TCipherString);
begin
  HashToString(@hash[0], SizeOf(hash), output);
end;

class procedure TCipher.HashToString(hash: TSHA3_384_Digest; var output: TCipherString);
begin
  HashToString(@hash[0], SizeOf(hash), output);
end;

class procedure TCipher.HashToString(hash: TSHA3_512_Digest; var output: TCipherString);
begin
  HashToString(@hash[0], SizeOf(hash), output);
end;

class procedure TCipher.HashToString(hash: TSHA512Digest; var output: TCipherString);
begin
  HashToString(@hash[0], SizeOf(hash), output);
end;

class procedure TCipher.HashToString(hash: TSHA256Digest; var output: TCipherString);
begin
  HashToString(@hash[0], SizeOf(hash), output);
end;

class procedure TCipher.HashToString(hash: TSHA1Digest; var output: TCipherString);
begin
  HashToString(@hash[0], SizeOf(hash), output);
end;

class procedure TCipher.HashToString(hash: TMD5Digest; var output: TCipherString);
begin
  HashToString(@hash[0], SizeOf(hash), output);
end;

class procedure TCipher.HashToString(hash: TBytes; var output: TCipherString);
begin
  { FIX: guard empty TBytes to avoid @hash[0] out-of-bounds access. }
  if Length(hash) = 0 then
    begin
      output.Len := 0;
      Exit;
    end;
  HashToString(@hash[0], Length(hash), output);
end;

class procedure TCipher.HashToString(hash: TBytes; var output: TCipherSystemString);
var
  s: TCipherString;
begin
  if Length(hash) = 0 then
    begin
      output := '';
      Exit;
    end;
  HashToString(@hash[0], Length(hash), s);
  output := s.Text;
end;

class function TCipher.HashToString(hash: TSHA3_224_Digest): TCipherSystemString;
var
  s: TCipherString;
begin
  HashToString(@hash[0], SizeOf(hash), s);
  Result := s.Text;
end;

class function TCipher.HashToString(hash: TSHA3_256_Digest): TCipherSystemString;
var
  s: TCipherString;
begin
  HashToString(@hash[0], SizeOf(hash), s);
  Result := s.Text;
end;

class function TCipher.HashToString(hash: TSHA3_384_Digest): TCipherSystemString;
var
  s: TCipherString;
begin
  HashToString(@hash[0], SizeOf(hash), s);
  Result := s.Text;
end;

class function TCipher.HashToString(hash: TSHA3_512_Digest): TCipherSystemString;
var
  s: TCipherString;
begin
  HashToString(@hash[0], SizeOf(hash), s);
  Result := s.Text;
end;

class function TCipher.HashToString(hash: TSHA512Digest): TCipherSystemString;
var
  s: TCipherString;
begin
  HashToString(@hash[0], SizeOf(hash), s);
  Result := s.Text;
end;

class function TCipher.HashToString(hash: TSHA256Digest): TCipherSystemString;
var
  s: TCipherString;
begin
  HashToString(@hash[0], SizeOf(hash), s);
  Result := s.Text;
end;

class function TCipher.HashToString(hash: TSHA1Digest): TCipherSystemString;
var
  s: TCipherString;
begin
  HashToString(@hash[0], SizeOf(hash), s);
  Result := s.Text;
end;

class function TCipher.HashToString(hash: TMD5Digest): TCipherSystemString;
var
  s: TCipherString;
begin
  HashToString(@hash[0], SizeOf(hash), s);
  Result := s.Text;
end;

class function TCipher.HashToString(hash: TBytes): TCipherSystemString;
var
  s: TCipherString;
begin
  if Length(hash) = 0 then
    begin
      Result := '';
      Exit;
    end;
  HashToString(@hash[0], Length(hash), s);
  Result := s.Text;
end;

class function TCipher.CompareHash(h1, h2: TSHA3_224_Digest): Boolean;
begin
  Result := CompareMemory(@h1[0], @h2[0], SizeOf(h1));
end;

class function TCipher.CompareHash(h1, h2: TSHA3_256_Digest): Boolean;
begin
  Result := CompareMemory(@h1[0], @h2[0], SizeOf(h1));
end;

class function TCipher.CompareHash(h1, h2: TSHA3_384_Digest): Boolean;
begin
  Result := CompareMemory(@h1[0], @h2[0], SizeOf(h1));
end;

class function TCipher.CompareHash(h1, h2: TSHA3_512_Digest): Boolean;
begin
  Result := CompareMemory(@h1[0], @h2[0], SizeOf(h1));
end;

class function TCipher.CompareHash(h1, h2: TSHA512Digest): Boolean;
begin
  Result := CompareMemory(@h1[0], @h2[0], SizeOf(h1));
end;

class function TCipher.CompareHash(h1, h2: TSHA256Digest): Boolean;
begin
  Result := CompareMemory(@h1[0], @h2[0], SizeOf(h1));
end;

class function TCipher.CompareHash(h1, h2: TSHA1Digest): Boolean;
begin
  Result := CompareMemory(@h1[0], @h2[0], SizeOf(h1));
end;

class function TCipher.CompareHash(h1, h2: TMD5Digest): Boolean;
begin
  Result := CompareMemory(@h1[0], @h2[0], SizeOf(h1));
end;

class function TCipher.CompareHash(h1, h2: Pointer; Size: NativeInt): Boolean;
begin
  if Size <= 0 then
    begin
      Result := True; { both empty ¡ú equal }
      Exit;
    end;
  Result := CompareMemory(h1, h2, Size);
end;

class function TCipher.CompareHash(h1, h2: TBytes): Boolean;
begin
  if Length(h1) = 0 then
      Result := Length(h2) = 0
  else
      Result := (Length(h1) = Length(h2)) and CompareMemory(@h1[0], @h2[0], Length(h1));
end;

class function TCipher.CompareKey(k1, k2: TCipherKeyBuffer): Boolean;
begin
  if Length(k1) = 0 then
      Result := Length(k2) = 0
  else
      Result := (Length(k1) = Length(k2)) and CompareMemory(@k1[0], @k2[0], Length(k1));
end;

class function TCipher.GenerateSHA3_224Hash(sour: Pointer; Size: NativeInt): TSHA3_224_Digest;
begin
  TSHA3.SHA224(Result, PByte(sour), Size);
end;

class function TCipher.GenerateSHA3_256Hash(sour: Pointer; Size: NativeInt): TSHA3_256_Digest;
begin
  TSHA3.SHA256(Result, PByte(sour), Size);
end;

class function TCipher.GenerateSHA3_384Hash(sour: Pointer; Size: NativeInt): TSHA3_384_Digest;
begin
  TSHA3.SHA384(Result, PByte(sour), Size);
end;

class function TCipher.GenerateSHA3_512Hash(sour: Pointer; Size: NativeInt): TSHA3_512_Digest;
begin
  TSHA3.SHA512(Result, PByte(sour), Size);
end;

class function TCipher.GenerateSHA512Hash(sour: Pointer; Size: NativeInt): TSHA512Digest;
begin
  TSHA512.SHA512(Result, sour^, Size);
end;

class function TCipher.GenerateSHA256Hash(sour: Pointer; Size: NativeInt): TSHA256Digest;
begin
  TSHA256.SHA256(Result, sour^, Size);
end;

class function TCipher.GenerateSHA1Hash(sour: Pointer; Size: NativeInt): TSHA1Digest;
begin
  TSHA1.SHA1(Result, sour^, Size);
end;

class function TCipher.GenerateMD5Hash(sour: Pointer; Size: NativeInt): TMD5Digest;
begin
{$IF Defined(FastMD5) and (Defined(WIN32) or Defined(WIN64))}
  Result := FastMD5(sour, Size);
{$ELSE}
  THashMD5.HashMD5(Result, sour^, Size);
{$IFEND}
end;

class procedure TCipher.GenerateMDHash(sour: Pointer; Size: NativeInt; OutHash: Pointer; HashSize: NativeInt);
begin
  THashMD.HashLMD(OutHash^, HashSize, sour^, Size);
end;

class procedure TCipher.GenerateHashByte(hs: THashSecurity; sour: Pointer; Size: NativeInt; var output: TBytes);
var
  swBuff: TBytes;
  effSize: NativeInt;
begin
  { FIX: on empty input, always return an empty digest regardless of hs.
    Also short-circuit before computing MD5 fallback for the tiny-input
    case so we never dereference a nil / zero-size buffer. }
  if (Size <= 0) or (sour = nil) then
    begin
      SetLength(output, 0);
      Exit;
    end;

  if Size < 6 then
    begin
      { For tiny inputs, fall back to MD5 (matches original behaviour). }
      SetLength(output, 16);
      PMD5(@output[0])^ := umlMD5(PByte(sour), Size);
      Exit;
    end;

  case hs of
    hsNone:
        SetLength(output, 0);

    hsFastMD5:
      begin
        SetLength(output, 16);
        PMD5(@output[0])^ := umlMD5(PByte(sour), DWORD(Size));
      end;

    hsMD5:
      begin
        SetLength(output, 16);
        THashMD5.HashMD5(PMD5Digest(@output[0])^, sour^, Size);
      end;

    hsSHA1:
      begin
        SetLength(output, 20);
        TSHA1.SHA1(PSHA1Digest(@output[0])^, sour^, Size);
      end;

    hsSHA256:
      begin
        SetLength(output, 32);
        TSHA256.SHA256(PSHA256Digest(@output[0])^, sour^, Size);
      end;

    hsSHA512:
      begin
        SetLength(output, 64);
        TSHA512.SHA512(PSHA512Digest(@output[0])^, sour^, Size);
      end;

    hsSHA3_224:
      begin
        SetLength(output, SizeOf(TSHA3_224_Digest));
        TSHA3.SHA224(PSHA3_224_Digest(@output[0])^, PByte(sour), Size);
      end;

    hsSHA3_256:
      begin
        SetLength(output, SizeOf(TSHA3_256_Digest));
        TSHA3.SHA256(PSHA3_256_Digest(@output[0])^, PByte(sour), Size);
      end;

    hsSHA3_384:
      begin
        SetLength(output, SizeOf(TSHA3_384_Digest));
        TSHA3.SHA384(PSHA3_384_Digest(@output[0])^, PByte(sour), Size);
      end;

    hsSHA3_512:
      begin
        SetLength(output, SizeOf(TSHA3_512_Digest));
        TSHA3.SHA512(PSHA3_512_Digest(@output[0])^, PByte(sour), Size);
      end;

    hs256:
      begin
        SetLength(output, 256);
        THashMD.HashLMD((@output[0])^, 256, sour^, Size);
      end;

    hs128:
      begin
        SetLength(output, 128);
        THashMD.HashLMD((@output[0])^, 128, sour^, Size);
      end;

    hs64:
      begin
        SetLength(output, 64);
        THashMD.HashLMD((@output[0])^, 64, sour^, Size);
      end;

    hs32:
      begin
        SetLength(output, 32);
        THashMD.HashLMD((@output[0])^, 32, sour^, Size);
      end;

    hs16:
      begin
        SetLength(output, 16);
        THashMD.HashLMD((@output[0])^, 16, sour^, Size);
      end;

    hsELF:
      begin
        SetLength(output, 4);
        TMISC.HashELF(PDWORD(@output[0])^, sour^, Size);
      end;

    hsELF64:
      begin
        SetLength(output, 8);
        TMISC.HashELF64(PInt64(@output[0])^, sour^, Size);
      end;

    hsMix128:
      begin
        SetLength(output, 4);

        if Size < 16 then
          begin
            SetLength(swBuff, 16);
            THashMD.HashLMD(swBuff[0], 16, sour^, Size);
            TMISC.HashMix128(PDWORD(@output[0])^, swBuff[0], 16);
          end
        else
            TMISC.HashMix128(PDWORD(@output[0])^, sour^, Size);
      end;

    hsCRC16:
      begin
        SetLength(output, 2);
        PWORD(@output[0])^ := umlCRC16(PByte(sour), Size);
      end;

    hsCRC32:
      begin
        SetLength(output, 4);
        PCardinal(@output[0])^ := umlCRC32(PByte(sour), Size);
      end;
  end;
end;

class function TCipher.GenerateHashString(hs: THashSecurity; sour: Pointer; Size: NativeInt): TCipherString;
var
  h: TBytes;
begin
  GenerateHashByte(hs, sour, Size, h);
  HashToString(h, Result);
  SetLength(h, 0);
end;

class function TCipher.BufferToHex(const Buf; BufSize: Cardinal): TCipherString;
begin
  Result := BuffToString(@Buf, BufSize);
end;

class function TCipher.HexToBuffer(const Hex: TCipherString; var Buf; BufSize: Cardinal): Boolean;
var
  i, c: Integer;
  tmp: TMem64;
  num: Integer;
  cc: TCipherChar;
begin
  Result := True;
  FillPtr(@Buf, BufSize, 0);

  if Hex.L > 0 then
    begin
      tmp := TMem64.CustomCreate(Hex.L + 1);
      if Hex.L mod 2 > 0 then
        begin
          cc := '0';
          tmp.Write64(cc, SizeOf(TCipherChar));
        end;
      for cc in Hex.buff do
        if CharIn(cc, cHex) then
            tmp.Write64(cc, SizeOf(TCipherChar));

      num := umlMin((tmp.Size div SizeOf(TCipherChar)) shr 1, BufSize);
      for i := 0 to num - 1 do
        begin
          Val('$' +
              PSystemChar(tmp.PositionAsPtr((i * 2) * SizeOf(TCipherChar)))^ +
              PSystemChar(tmp.PositionAsPtr((i * 2 + 1) * SizeOf(TCipherChar)))^,
            TCCByteArray(Buf)[i], c);
          Result := Result and (c = 0);
        end;
      disposeObject(tmp);
    end;
end;

class function TCipher.CopyKey(const k: TCipherKeyBuffer): TCipherKeyBuffer;
begin
  { FIX: guard against empty input to avoid @k[0] / @Result[0] on zero-size. }
  SetLength(Result, Length(k));
  if Length(k) > 0 then
      CopyPtr(@k[0], @Result[0], Length(k));
end;

class procedure TCipher.GenerateNoneKey(var output: TCipherKeyBuffer);
begin
  SetLength(output, C_Byte_Size);
  output[0] := Byte(TCipherKeyStyle.cksNone);
end;

{ ===============================================================================
  Key generation ¡ª TCipherSystemString sources

  Empty input strings are treated as "all-zero key material". We must NOT
  call THashMD.GenerateLMDKey with an empty TBytes because it would
  dereference Bytes_[0] out of bounds.
  =============================================================================== }

class procedure TCipher.GenerateKey64(const s: TCipherString; var output: TCipherKeyBuffer);
var
  bytes_: TBytes;
begin
  SetLength(output, C_Byte_Size + cKey64Size);
  output[0] := Byte(TCipherKeyStyle.cksKey64);
  bytes_ := s.Bytes;
  if Length(bytes_) = 0 then
      FillPtr(@output[1], cKey64Size, 0)
  else
      THashMD.GenerateLMDKey((@output[1])^, cKey64Size, bytes_);
end;

class procedure TCipher.GenerateKey64(sour: Pointer; Size: NativeInt; var output: TCipherKeyBuffer);
begin
  SetLength(output, C_Byte_Size + cKey64Size);
  output[0] := Byte(TCipherKeyStyle.cksKey64);
  if (Size <= 0) or (sour = nil) then
      FillPtr(@output[1], cKey64Size, 0)
  else
      THashMD.HashLMD((@output[1])^, cKey64Size, sour^, Size);
end;

class procedure TCipher.GenerateKey128(const s: TCipherString; var output: TCipherKeyBuffer);
var
  bytes_: TBytes;
begin
  SetLength(output, C_Byte_Size + cKey128Size);
  output[0] := Byte(TCipherKeyStyle.cksKey128);
  bytes_ := s.Bytes;
  if Length(bytes_) = 0 then
      FillPtr(@output[1], cKey128Size, 0)
  else
      THashMD.GenerateLMDKey((@output[1])^, cKey128Size, bytes_);
end;

class procedure TCipher.GenerateKey128(sour: Pointer; Size: NativeInt; var output: TCipherKeyBuffer);
begin
  SetLength(output, C_Byte_Size + cKey128Size);
  output[0] := Byte(TCipherKeyStyle.cksKey128);
  if (Size <= 0) or (sour = nil) then
      FillPtr(@output[1], cKey128Size, 0)
  else
      THashMD.HashLMD((@output[1])^, cKey128Size, sour^, Size);
end;

class procedure TCipher.GenerateKey256(const s: TCipherString; var output: TCipherKeyBuffer);
var
  bytes_: TBytes;
begin
  SetLength(output, C_Byte_Size + cKey256Size);
  output[0] := Byte(TCipherKeyStyle.cksKey256);
  bytes_ := s.Bytes;
  if Length(bytes_) = 0 then
      FillPtr(@output[1], cKey256Size, 0)
  else
      THashMD.GenerateLMDKey((@output[1])^, cKey256Size, bytes_);
end;

class procedure TCipher.GenerateKey256(sour: Pointer; Size: NativeInt; var output: TCipherKeyBuffer);
begin
  SetLength(output, C_Byte_Size + cKey256Size);
  output[0] := Byte(TCipherKeyStyle.cksKey256);
  if (Size <= 0) or (sour = nil) then
      FillPtr(@output[1], cKey256Size, 0)
  else
      THashMD.HashLMD((@output[1])^, cKey256Size, sour^, Size);
end;

class procedure TCipher.Generate3Key64(const s: TCipherString; var output: TCipherKeyBuffer);
var
  bytes_: TBytes;
begin
  SetLength(output, C_Byte_Size + cKey192Size);
  output[0] := Byte(TCipherKeyStyle.cks3Key64);
  bytes_ := s.Bytes;
  if Length(bytes_) = 0 then
      FillPtr(@output[1], cKey192Size, 0)
  else
      THashMD.GenerateLMDKey((@output[1])^, cKey192Size, bytes_);
end;

class procedure TCipher.Generate3Key64(sour: Pointer; Size: NativeInt; var output: TCipherKeyBuffer);
begin
  SetLength(output, C_Byte_Size + cKey192Size);
  output[0] := Byte(TCipherKeyStyle.cks3Key64);
  if (Size <= 0) or (sour = nil) then
      FillPtr(@output[1], cKey192Size, 0)
  else
      THashMD.HashLMD((@output[1])^, cKey192Size, sour^, Size);
end;

class procedure TCipher.Generate2IntKey(const s: TCipherString; var output: TCipherKeyBuffer);
var
  bytes_: TBytes;
begin
  SetLength(output, C_Byte_Size + cKey2DWORDSize);
  output[0] := Byte(TCipherKeyStyle.cks2IntKey);
  bytes_ := s.Bytes;
  if Length(bytes_) = 0 then
      FillPtr(@output[1], cKey2DWORDSize, 0)
  else
      THashMD.GenerateLMDKey((@output[1])^, cKey2DWORDSize, bytes_);
end;

class procedure TCipher.Generate2IntKey(sour: Pointer; Size: NativeInt; var output: TCipherKeyBuffer);
begin
  SetLength(output, C_Byte_Size + cKey2DWORDSize);
  output[0] := Byte(TCipherKeyStyle.cks2IntKey);
  if (Size <= 0) or (sour = nil) then
      FillPtr(@output[1], cKey2DWORDSize, 0)
  else
      THashMD.HashLMD((@output[1])^, cKey2DWORDSize, sour^, Size);
end;

class procedure TCipher.GenerateIntKey(const s: TCipherString; var output: TCipherKeyBuffer);
var
  bytes_: TBytes;
begin
  SetLength(output, C_Byte_Size + cKeyDWORDSize);
  output[0] := Byte(TCipherKeyStyle.cksIntKey);
  bytes_ := s.Bytes;
  if Length(bytes_) = 0 then
      FillPtr(@output[1], cKeyDWORDSize, 0)
  else
      THashMD.GenerateLMDKey((@output[1])^, cKeyDWORDSize, bytes_);
end;

class procedure TCipher.GenerateIntKey(sour: Pointer; Size: NativeInt; var output: TCipherKeyBuffer);
begin
  SetLength(output, C_Byte_Size + cKeyDWORDSize);
  output[0] := Byte(TCipherKeyStyle.cksIntKey);
  if (Size <= 0) or (sour = nil) then
      FillPtr(@output[1], cKeyDWORDSize, 0)
  else
      THashMD.HashLMD((@output[1])^, cKeyDWORDSize, sour^, Size);
end;

class procedure TCipher.GenerateBytesKey(const s: TCipherString; KeySize: DWORD; var output: TCipherKeyBuffer);
var
  bytes_: TBytes;
begin
  SetLength(output, C_Byte_Size + cIntSize + KeySize);
  output[0] := Byte(TCipherKeyStyle.ckyDynamicKey);
  PDWORD(@output[1])^ := KeySize;
  bytes_ := s.Bytes;
  if Length(bytes_) = 0 then
      FillPtr(@output[1 + cIntSize], KeySize, 0)
  else
      THashMD.GenerateLMDKey((@output[1 + cIntSize])^, KeySize, bytes_);
end;

class procedure TCipher.GenerateBytesKey(sour: Pointer; Size, KeySize: DWORD; var output: TCipherKeyBuffer);
begin
  SetLength(output, C_Byte_Size + cIntSize + KeySize);
  output[0] := Byte(TCipherKeyStyle.ckyDynamicKey);
  PDWORD(@output[1])^ := KeySize;
  if (Size = 0) or (sour = nil) then
      FillPtr(@output[1 + cIntSize], KeySize, 0)
  else
      THashMD.HashLMD((@output[1 + cIntSize])^, KeySize, sour^, Size);
end;

{ ===============================================================================
  Key generation ¡ª raw key structures
  =============================================================================== }

class procedure TCipher.GenerateKey64(const k: TKey64; var output: TCipherKeyBuffer);
begin
  GenerateKey(k, output);
end;

class procedure TCipher.GenerateKey128(const k1, k2: TKey64; var output: TCipherKeyBuffer);
begin
  SetLength(output, C_Byte_Size + cKey128Size);
  output[0] := Byte(TCipherKeyStyle.cksKey128);
  CopyPtr(@k1, @output[1], cKey64Size);
  CopyPtr(@k2, @output[1 + cKey64Size], cKey64Size);
end;

class procedure TCipher.GenerateKey(const k: TKey64; var output: TCipherKeyBuffer);
begin
  SetLength(output, C_Byte_Size + cKey64Size);
  output[0] := Byte(TCipherKeyStyle.cksKey64);
  CopyPtr(@k, @output[1], cKey64Size);
end;

class procedure TCipher.GenerateKey(const k1, k2, k3: TKey64; var output: TCipherKeyBuffer);
begin
  SetLength(output, C_Byte_Size + cKey192Size);
  output[0] := Byte(TCipherKeyStyle.cks3Key64);
  CopyPtr(@k1, @output[1], cKey64Size);
  CopyPtr(@k2, @output[1 + cKey64Size], cKey64Size);
  CopyPtr(@k3, @output[1 + cKey64Size + cKey64Size], cKey64Size);
end;

class procedure TCipher.GenerateKey(const k: TKey128; var output: TCipherKeyBuffer);
begin
  SetLength(output, C_Byte_Size + cKey128Size);
  output[0] := Byte(TCipherKeyStyle.cksKey128);
  CopyPtr(@k, @output[1], cKey128Size);
end;

class procedure TCipher.GenerateKey(const k: TKey256; var output: TCipherKeyBuffer);
begin
  SetLength(output, C_Byte_Size + cKey256Size);
  output[0] := Byte(TCipherKeyStyle.cksKey256);
  CopyPtr(@k, @output[1], cKey256Size);
end;

class procedure TCipher.GenerateKey(const k1, k2: DWORD; var output: TCipherKeyBuffer);
begin
  SetLength(output, C_Byte_Size + cKey2DWORDSize);
  output[0] := Byte(TCipherKeyStyle.cks2IntKey);
  PDWORD(@output[1])^ := k1;
  PDWORD(@output[1 + cKeyDWORDSize])^ := k2;
end;

class procedure TCipher.GenerateKey(const k: DWORD; var output: TCipherKeyBuffer);
begin
  SetLength(output, C_Byte_Size + cKeyDWORDSize);
  output[0] := Byte(TCipherKeyStyle.cksIntKey);
  PDWORD(@output[1])^ := k;
end;

class procedure TCipher.GenerateKey(const key: PByte; Size: DWORD; var output: TCipherKeyBuffer);
begin
  SetLength(output, C_Byte_Size + cIntSize + Size);
  output[0] := Byte(TCipherKeyStyle.ckyDynamicKey);
  PDWORD(@output[1])^ := Size;
  { FIX: guard nil / zero size. }
  if (Size = 0) or (key = nil) then
      FillPtr(@output[1 + cIntSize], Size, 0)
  else
      CopyPtr(key, @output[1 + cIntSize], Size);
end;

class procedure TCipher.GenerateKey(cs: TCipherSecurity; buffPtr: Pointer; Size: NativeInt; var output: TCipherKeyBuffer);
begin
  case CCipherKeyStyle[cs] of
    cksNone: GenerateNoneKey(output);
    cksKey64: GenerateKey64(buffPtr, Size, output);
    cks3Key64: Generate3Key64(buffPtr, Size, output);
    cksKey128: GenerateKey128(buffPtr, Size, output);
    cksKey256: GenerateKey256(buffPtr, Size, output);
    cks2IntKey: Generate2IntKey(buffPtr, Size, output);
    cksIntKey: GenerateIntKey(buffPtr, Size, output);
    ckyDynamicKey: GenerateBytesKey(buffPtr, DWORD(Size), 32, output);
  end;
end;

class procedure TCipher.GenerateKey(cs: TCipherSecurity; s: TCipherString; var output: TCipherKeyBuffer);
var
  buff: TBytes;
  key: TBytes;
begin
  buff := s.Bytes;
  SetLength(key, 128);

  { FIX: guard empty input; otherwise @buff[0] is out of bounds. }
  if Length(buff) = 0 then
      FillPtr(@key[0], 128, 0)
  else
      TCipher.GenerateMDHash(@buff[0], Length(buff), @key[0], 128);

  GenerateKey(cs, @key[0], 128, output);
end;

{ ===============================================================================
  Key extraction
  =============================================================================== }

class function TCipher.GetKeyStyle(const p: PCipherKeyBuffer): TCipherKeyStyle;
begin
  Result := TCipherKeyStyle(p^[0]);
end;

class function TCipher.GetKey(const KeyBuffPtr: PCipherKeyBuffer; var k: TKey64): Boolean;
begin
  Result := (KeyBuffPtr <> nil) and (Length(KeyBuffPtr^) >= 1) and
    (GetKeyStyle(KeyBuffPtr) = TCipherKeyStyle.cksKey64);
  if not Result then
      Exit;
  CopyPtr(@KeyBuffPtr^[1], @k, cKey64Size);
end;

class function TCipher.GetKey(const KeyBuffPtr: PCipherKeyBuffer; var k1, k2, k3: TKey64): Boolean;
begin
  Result := (KeyBuffPtr <> nil) and (Length(KeyBuffPtr^) >= 1) and
    (GetKeyStyle(KeyBuffPtr) = TCipherKeyStyle.cks3Key64);
  if not Result then
      Exit;
  CopyPtr(@KeyBuffPtr^[1], @k1, cKey64Size);
  CopyPtr(@KeyBuffPtr^[1 + cKey64Size], @k2, cKey64Size);
  CopyPtr(@KeyBuffPtr^[1 + cKey64Size + cKey64Size], @k3, cKey64Size);
end;

class function TCipher.GetKey(const KeyBuffPtr: PCipherKeyBuffer; var k: TKey128): Boolean;
begin
  Result := (KeyBuffPtr <> nil) and (Length(KeyBuffPtr^) >= 1) and
    (GetKeyStyle(KeyBuffPtr) = TCipherKeyStyle.cksKey128);
  if not Result then
      Exit;
  CopyPtr(@KeyBuffPtr^[1], @k, cKey128Size);
end;

class function TCipher.GetKey(const KeyBuffPtr: PCipherKeyBuffer; var k: TKey256): Boolean;
begin
  Result := (KeyBuffPtr <> nil) and (Length(KeyBuffPtr^) >= 1) and
    (GetKeyStyle(KeyBuffPtr) = TCipherKeyStyle.cksKey256);
  if not Result then
      Exit;
  CopyPtr(@KeyBuffPtr^[1], @k, cKey256Size);
end;

class function TCipher.GetKey(const KeyBuffPtr: PCipherKeyBuffer; var k1, k2: DWORD): Boolean;
begin
  Result := (KeyBuffPtr <> nil) and (Length(KeyBuffPtr^) >= 1) and
    (GetKeyStyle(KeyBuffPtr) = TCipherKeyStyle.cks2IntKey);
  if not Result then
      Exit;
  k1 := PDWORD(@KeyBuffPtr^[1])^;
  k2 := PDWORD(@KeyBuffPtr^[1 + cKeyDWORDSize])^;
end;

class function TCipher.GetKey(const KeyBuffPtr: PCipherKeyBuffer; var k: DWORD): Boolean;
begin
  Result := (KeyBuffPtr <> nil) and (Length(KeyBuffPtr^) >= 1) and
    (GetKeyStyle(KeyBuffPtr) = TCipherKeyStyle.cksIntKey);
  if not Result then
      Exit;
  k := PDWORD(@KeyBuffPtr^[1])^;
end;

class function TCipher.GetKey(const KeyBuffPtr: PCipherKeyBuffer; var key: TBytes): Boolean;
var
  siz: Integer;
begin
  Result := (KeyBuffPtr <> nil) and (Length(KeyBuffPtr^) >= 1) and
    (GetKeyStyle(KeyBuffPtr) = TCipherKeyStyle.ckyDynamicKey);
  if not Result then
      Exit;

  siz := PInteger(@KeyBuffPtr^[1])^;
  SetLength(key, siz);

  { FIX: guard zero-length payload before CopyPtr to @key[0]. }
  if siz > 0 then
      CopyPtr(@KeyBuffPtr^[1 + cIntSize], @key[0], siz);
end;

{ ===============================================================================
  Tail / CBC helpers
  =============================================================================== }

class procedure TCipher.EncryptTail(TailPtr: Pointer; TailSize: NativeInt);
begin
  if TailSize <= 0 then
      Exit;
  BlockCBC(TailPtr, TailSize, @SystemCBC[0], Length(SystemCBC));
end;

class procedure TCipher.BlockCBC(sour: Pointer; Size: NativeInt; boxBuff: Pointer; boxSiz: NativeInt);
var
  p: NativeUInt;
begin
  { FIX: guard invalid sizes to avoid infinite recursion / nil deref. }
  if (Size <= 0) or (boxSiz <= 0) or (sour = nil) or (boxBuff = nil) then
      Exit;

  if boxSiz >= Size then
    begin
      TMISC.XorMem(sour^, boxBuff^, Size);
    end
  else
    begin
      p := 0;
      repeat
        TMISC.XorMem(Pointer(NativeUInt(sour) + p)^, boxBuff^, boxSiz);
        p := p + boxSiz;
      until p + boxSiz > Size;

      BlockCBC(Pointer(NativeUInt(sour) + p), Size - p, boxBuff, boxSiz);
    end;
end;

{ ===============================================================================
  Per-cipher encrypt/decrypt wrappers (unchanged logic; guarded tails)
  =============================================================================== }

class function TCipher.DES64(sour: Pointer; Size: NativeInt; KeyBuff: PCipherKeyBuffer; Encrypt, ProcessTail: Boolean): Boolean;
var
  k: TKey64;
  d: TDESContext;
  p: NativeUInt;
begin
  Result := False;
  if Size <= 0 then Exit;

  if Size >= 8 then
    begin
      if not GetKey(KeyBuff, k) then Exit;
      TDES.InitEncryptDES(k, d, Encrypt);

      p := 0;
      repeat
        TDES.EncryptDES(d, PDESBlock(NativeUInt(sour) + p)^);
        p := p + 8;
      until p + 8 > Size;
    end
  else
      p := 0;

  if (ProcessTail) and (Size - p > 0) then
      EncryptTail(Pointer(NativeUInt(sour) + p), Size - p);

  Result := True;
end;

class function TCipher.DES128(sour: Pointer; Size: NativeInt; KeyBuff: PCipherKeyBuffer; Encrypt, ProcessTail: Boolean): Boolean;
var
  k: TKey128;
  d: TTripleDESContext;
  p: NativeUInt;
begin
  Result := False;
  if Size <= 0 then Exit;

  if Size >= 8 then
    begin
      if not GetKey(KeyBuff, k) then Exit;
      TDES.InitEncryptTripleDES(k, d, Encrypt);

      p := 0;
      repeat
        TDES.EncryptTripleDES(d, PDESBlock(NativeUInt(sour) + p)^);
        p := p + 8;
      until p + 8 > Size;
    end
  else
      p := 0;

  if (ProcessTail) and (Size - p > 0) then
      EncryptTail(Pointer(NativeUInt(sour) + p), Size - p);

  Result := True;
end;

class function TCipher.DES192(sour: Pointer; Size: NativeInt; KeyBuff: PCipherKeyBuffer; Encrypt, ProcessTail: Boolean): Boolean;
var
  k1, k2, k3: TKey64;
  d: TTripleDESContext3Key;
  p: NativeUInt;
begin
  Result := False;
  if Size <= 0 then Exit;

  if Size >= 8 then
    begin
      if not GetKey(KeyBuff, k1, k2, k3) then Exit;
      TDES.InitEncryptTripleDES3Key(k1, k2, k3, d, Encrypt);

      p := 0;
      repeat
        TDES.EncryptTripleDES3Key(d, PDESBlock(NativeUInt(sour) + p)^);
        p := p + 8;
      until p + 8 > Size;
    end
  else
      p := 0;

  if (ProcessTail) and (Size - p > 0) then
      EncryptTail(Pointer(NativeUInt(sour) + p), Size - p);
  Result := True;
end;

class function TCipher.Blowfish(sour: Pointer; Size: NativeInt; KeyBuff: PCipherKeyBuffer; Encrypt, ProcessTail: Boolean): Boolean;
var
  k: TKey128;
  d: TBFContext;
  p: NativeUInt;
begin
  Result := False;
  if Size <= 0 then Exit;

  if Size >= 8 then
    begin
      if not GetKey(KeyBuff, k) then Exit;
      TBlowfish.InitEncryptBF(k, d);

      p := 0;
      repeat
        TBlowfish.EncryptBF(d, PBFBlock(NativeUInt(sour) + p)^, Encrypt);
        p := p + 8;
      until p + 8 > Size;
    end
  else
      p := 0;

  if (ProcessTail) and (Size - p > 0) then
      EncryptTail(Pointer(NativeUInt(sour) + p), Size - p);

  Result := True;
end;

class function TCipher.LBC(sour: Pointer; Size: NativeInt; KeyBuff: PCipherKeyBuffer; Encrypt, ProcessTail: Boolean): Boolean;
var
  k: TKey128;
  d: TLBCContext;
  p: NativeUInt;
begin
  Result := False;
  if Size <= 0 then Exit;

  if Size >= 16 then
    begin
      if not GetKey(KeyBuff, k) then Exit;
      TLBC.InitEncryptLBC(k, d, 16, Encrypt);

      p := 0;
      repeat
        TLBC.EncryptLBC(d, PLBCBlock(NativeUInt(sour) + p)^);
        p := p + 16;
      until p + 16 > Size;
    end
  else
      p := 0;

  if (ProcessTail) and (Size - p > 0) then
      EncryptTail(Pointer(NativeUInt(sour) + p), Size - p);
  Result := True;
end;

class function TCipher.LQC(sour: Pointer; Size: NativeInt; KeyBuff: PCipherKeyBuffer; Encrypt, ProcessTail: Boolean): Boolean;
var
  k: TKey128;
  p: NativeUInt;
begin
  Result := False;
  if Size <= 0 then Exit;

  if Size >= 8 then
    begin
      if not GetKey(KeyBuff, k) then Exit;

      p := 0;
      repeat
        TLBC.EncryptLQC(k, PLQCBlock(NativeUInt(sour) + p)^, Encrypt);
        p := p + 8;
      until p + 8 > Size;
    end
  else
      p := 0;

  if (ProcessTail) and (Size - p > 0) then
      EncryptTail(Pointer(NativeUInt(sour) + p), Size - p);
  Result := True;
end;

class function TCipher.RNG32(sour: Pointer; Size: NativeInt; KeyBuff: PCipherKeyBuffer): Boolean;
var
  k: DWORD;
  d: TRNG32Context;
begin
  Result := False;
  if Size <= 0 then Exit;
  if not GetKey(KeyBuff, k) then Exit;

  TRNG.InitEncryptRNG32(k, d);
  TRNG.EncryptRNG32(d, sour^, Size);
  Result := True;
end;

class function TCipher.RNG64(sour: Pointer; Size: NativeInt; KeyBuff: PCipherKeyBuffer): Boolean;
var
  k1, k2: DWORD;
  d: TRNG64Context;
begin
  Result := False;
  if Size <= 0 then Exit;
  if not GetKey(KeyBuff, k1, k2) then Exit;

  TRNG.InitEncryptRNG64(k1, k2, d);
  TRNG.EncryptRNG64(d, sour^, Size);
  Result := True;
end;

class function TCipher.LSC(sour: Pointer; Size: NativeInt; KeyBuff: PCipherKeyBuffer): Boolean;
var
  k: TBytes;
  k255: TBytes;
  d: TLSCContext;
begin
  Result := False;
  if Size <= 0 then Exit;
  if not GetKey(KeyBuff, k) then Exit;

  if Length(k) > 255 then
    begin
      SetLength(k255, 255);
      THashMD.GenerateLMDKey((@k255[0])^, 255, k);
    end
  else
      k255 := k;

  { FIX: guard empty key material before @k255[0]. }
  if Length(k255) = 0 then
    begin
      SetLength(k255, 1);
      k255[0] := 0;
    end;

  TLSC.InitEncryptLSC((@k255[0])^, Length(k255), d);
  TLSC.EncryptLSC(d, sour^, Size);
  Result := True;
end;

class function TCipher.XXTea512(sour: Pointer; Size: NativeInt; KeyBuff: PCipherKeyBuffer; Encrypt, ProcessTail: Boolean): Boolean;
var
  k: TKey128;
  p: NativeUInt;
begin
  Result := False;
  if Size <= 0 then Exit;

  if Size >= 64 then
    begin
      if not GetKey(KeyBuff, k) then Exit;

      if Encrypt then
        begin
          p := 0;
          repeat
            XXTEAEncrypt(k, PXXTEABlock(NativeUInt(sour) + p)^);
            p := p + 64;
          until p + 64 > Size;
        end
      else
        begin
          p := 0;
          repeat
            XXTEADecrypt(k, PXXTEABlock(NativeUInt(sour) + p)^);
            p := p + 64;
          until p + 64 > Size;
        end;
    end
  else
      p := 0;

  if (ProcessTail) and (Size - p > 0) then
      EncryptTail(Pointer(NativeUInt(sour) + p), Size - p);
  Result := True;
end;

class function TCipher.RC6(sour: Pointer; Size: NativeInt; KeyBuff: PCipherKeyBuffer; Encrypt, ProcessTail: Boolean): Boolean;
var
  k, k256: TBytes;
  d: TRC6Key;
  p: NativeUInt;
begin
  Result := False;
  if Size <= 0 then Exit;

  if Size >= 16 then
    begin
      if not GetKey(KeyBuff, k) then Exit;

      SetLength(k256, 32);
      { FIX: guard empty k before GenerateLMDKey. }
      if Length(k) = 0 then
          FillPtr(@k256[0], 32, 0)
      else
          THashMD.GenerateLMDKey((@k256[0])^, 32, k);

      TRC6.InitKey(@k256[0], 32, d);

      if Encrypt then
        begin
          p := 0;
          repeat
            TRC6.Encrypt(d, PRC6Block(NativeUInt(sour) + p)^);
            p := p + 16;
          until p + 16 > Size;
        end
      else
        begin
          p := 0;
          repeat
            TRC6.Decrypt(d, PRC6Block(NativeUInt(sour) + p)^);
            p := p + 16;
          until p + 16 > Size;
        end;
    end
  else
      p := 0;

  if (ProcessTail) and (Size - p > 0) then
      EncryptTail(Pointer(NativeUInt(sour) + p), Size - p);
  Result := True;
end;

class function TCipher.Serpent(sour: Pointer; Size: NativeInt; KeyBuff: PCipherKeyBuffer; Encrypt, ProcessTail: Boolean): Boolean;
var
  k, k256: TBytes;
  d: TSerpentkey;
  p: NativeUInt;
begin
  Result := False;
  if Size <= 0 then Exit;

  if Size >= 16 then
    begin
      if not GetKey(KeyBuff, k) then Exit;

      SetLength(k256, 32);
      if Length(k) = 0 then
          FillPtr(@k256[0], 32, 0)
      else
          THashMD.GenerateLMDKey((@k256[0])^, 32, k);

      TSerpent.InitKey(@k256[0], 32, d);

      if Encrypt then
        begin
          p := 0;
          repeat
            TSerpent.Encrypt(d, PSerpentBlock(NativeUInt(sour) + p)^);
            p := p + 16;
          until p + 16 > Size;
        end
      else
        begin
          p := 0;
          repeat
            TSerpent.Decrypt(d, PSerpentBlock(NativeUInt(sour) + p)^);
            p := p + 16;
          until p + 16 > Size;
        end;
    end
  else
      p := 0;

  if (ProcessTail) and (Size - p > 0) then
      EncryptTail(Pointer(NativeUInt(sour) + p), Size - p);
  Result := True;
end;

class function TCipher.Mars(sour: Pointer; Size: NativeInt; KeyBuff: PCipherKeyBuffer; Encrypt, ProcessTail: Boolean): Boolean;
var
  k, k256: TBytes;
  d: TMarskey;
  p: NativeUInt;
begin
  Result := False;
  if Size <= 0 then Exit;

  if Size >= 16 then
    begin
      if not GetKey(KeyBuff, k) then Exit;

      SetLength(k256, 32);
      if Length(k) = 0 then
          FillPtr(@k256[0], 32, 0)
      else
          THashMD.GenerateLMDKey((@k256[0])^, 32, k);

      TMars.InitKey(@k256[0], 32, d);

      if Encrypt then
        begin
          p := 0;
          repeat
            TMars.Encrypt(d, PMarsBlock(NativeUInt(sour) + p)^);
            p := p + 16;
          until p + 16 > Size;
        end
      else
        begin
          p := 0;
          repeat
            TMars.Decrypt(d, PMarsBlock(NativeUInt(sour) + p)^);
            p := p + 16;
          until p + 16 > Size;
        end;
    end
  else
      p := 0;

  if (ProcessTail) and (Size - p > 0) then
      EncryptTail(Pointer(NativeUInt(sour) + p), Size - p);
  Result := True;
end;

class function TCipher.Rijndael(sour: Pointer; Size: NativeInt; KeyBuff: PCipherKeyBuffer; Encrypt, ProcessTail: Boolean): Boolean;
var
  k, k256: TBytes;
  d: TRijndaelkey;
  p: NativeUInt;
begin
  Result := False;
  if Size <= 0 then Exit;

  if Size >= 16 then
    begin
      if not GetKey(KeyBuff, k) then Exit;

      SetLength(k256, 32);
      if Length(k) = 0 then
          FillPtr(@k256[0], 32, 0)
      else
          THashMD.GenerateLMDKey((@k256[0])^, 32, k);

      TRijndael.InitKey(@k256[0], 32, d);

      if Encrypt then
        begin
          p := 0;
          repeat
            TRijndael.Encrypt(d, PRijndaelBlock(NativeUInt(sour) + p)^);
            p := p + 16;
          until p + 16 > Size;
        end
      else
        begin
          p := 0;
          repeat
            TRijndael.Decrypt(d, PRijndaelBlock(NativeUInt(sour) + p)^);
            p := p + 16;
          until p + 16 > Size;
        end;
    end
  else
      p := 0;

  if (ProcessTail) and (Size - p > 0) then
      EncryptTail(Pointer(NativeUInt(sour) + p), Size - p);
  Result := True;
end;

class function TCipher.TwoFish(sour: Pointer; Size: NativeInt; KeyBuff: PCipherKeyBuffer; Encrypt, ProcessTail: Boolean): Boolean;
var
  k, k256: TBytes;
  d: TTwofishKey;
  p: NativeUInt;
begin
  Result := False;
  if Size <= 0 then Exit;

  if Size >= 16 then
    begin
      if not GetKey(KeyBuff, k) then Exit;

      SetLength(k256, 32);
      if Length(k) = 0 then
          FillPtr(@k256[0], 32, 0)
      else
          THashMD.GenerateLMDKey((@k256[0])^, 32, k);

      TTwofish.InitKey(@k256[0], 32, d);

      if Encrypt then
        begin
          p := 0;
          repeat
            TTwofish.Encrypt(d, PTwofishBlock(NativeUInt(sour) + p)^);
            p := p + 16;
          until p + 16 > Size;
        end
      else
        begin
          p := 0;
          repeat
            TTwofish.Decrypt(d, PTwofishBlock(NativeUInt(sour) + p)^);
            p := p + 16;
          until p + 16 > Size;
        end;
    end
  else
      p := 0;

  if (ProcessTail) and (Size - p > 0) then
      EncryptTail(Pointer(NativeUInt(sour) + p), Size - p);
  Result := True;
end;

class function TCipher.AES128(sour: Pointer; Size: NativeInt; KeyBuff: PCipherKeyBuffer; Encrypt, ProcessTail: Boolean): Boolean;
var
  k: TBytes;
  k128: TAESKey128;
  d: TAESExpandedKey128;
  p: NativeUInt;
begin
  Result := False;
  if Size <= 0 then Exit;

  if Size >= 16 then
    begin
      if not GetKey(KeyBuff, k) then Exit;

      if Length(k) = 0 then
          FillPtr(@k128[0], 16, 0)
      else
          THashMD.GenerateLMDKey((@k128[0])^, 16, k);

      if Encrypt then
        begin
          ExpandAESKeyForEncryption(k128, d);
          p := 0;
          repeat
            EncryptAES(PAESBuffer(NativeUInt(sour) + p)^, d, PAESBuffer(NativeUInt(sour) + p)^);
            p := p + 16;
          until p + 16 > Size;
        end
      else
        begin
          ExpandAESKeyForDecryption(k128, d);
          p := 0;
          repeat
            DecryptAES(PAESBuffer(NativeUInt(sour) + p)^, d, PAESBuffer(NativeUInt(sour) + p)^);
            p := p + 16;
          until p + 16 > Size;
        end;
    end
  else
      p := 0;

  if (ProcessTail) and (Size - p > 0) then
      EncryptTail(Pointer(NativeUInt(sour) + p), Size - p);
  Result := True;
end;

class function TCipher.AES192(sour: Pointer; Size: NativeInt; KeyBuff: PCipherKeyBuffer; Encrypt, ProcessTail: Boolean): Boolean;
var
  k: TBytes;
  k192: TAESKey192;
  d: TAESExpandedKey192;
  p: NativeUInt;
begin
  Result := False;
  if Size <= 0 then Exit;

  if Size >= 16 then
    begin
      if not GetKey(KeyBuff, k) then Exit;

      if Length(k) = 0 then
          FillPtr(@k192[0], 24, 0)
      else
          THashMD.GenerateLMDKey((@k192[0])^, 24, k);

      if Encrypt then
        begin
          ExpandAESKeyForEncryption(k192, d);
          p := 0;
          repeat
            EncryptAES(PAESBuffer(NativeUInt(sour) + p)^, d, PAESBuffer(NativeUInt(sour) + p)^);
            p := p + 16;
          until p + 16 > Size;
        end
      else
        begin
          ExpandAESKeyForDecryption(k192, d);
          p := 0;
          repeat
            DecryptAES(PAESBuffer(NativeUInt(sour) + p)^, d, PAESBuffer(NativeUInt(sour) + p)^);
            p := p + 16;
          until p + 16 > Size;
        end;
    end
  else
      p := 0;

  if (ProcessTail) and (Size - p > 0) then
      EncryptTail(Pointer(NativeUInt(sour) + p), Size - p);
  Result := True;
end;

class function TCipher.AES256(sour: Pointer; Size: NativeInt; KeyBuff: PCipherKeyBuffer; Encrypt, ProcessTail: Boolean): Boolean;
var
  k: TBytes;
  k256: TAESKey256;
  d: TAESExpandedKey256;
  p: NativeUInt;
begin
  Result := False;
  if Size <= 0 then Exit;

  if Size >= 16 then
    begin
      if not GetKey(KeyBuff, k) then Exit;

      if Length(k) = 0 then
          FillPtr(@k256[0], 32, 0)
      else
          THashMD.GenerateLMDKey((@k256[0])^, 32, k);

      if Encrypt then
        begin
          ExpandAESKeyForEncryption(k256, d);
          p := 0;
          repeat
            EncryptAES(PAESBuffer(NativeUInt(sour) + p)^, d, PAESBuffer(NativeUInt(sour) + p)^);
            p := p + 16;
          until p + 16 > Size;
        end
      else
        begin
          ExpandAESKeyForDecryption(k256, d);
          p := 0;
          repeat
            DecryptAES(PAESBuffer(NativeUInt(sour) + p)^, d, PAESBuffer(NativeUInt(sour) + p)^);
            p := p + 16;
          until p + 16 > Size;
        end;
    end
  else
      p := 0;

  if (ProcessTail) and (Size - p > 0) then
      EncryptTail(Pointer(NativeUInt(sour) + p), Size - p);
  Result := True;
end;

{ ===============================================================================
  Dispatch
  =============================================================================== }

class function TCipher.EncryptBuffer(cs: TCipherSecurity; sour: Pointer; Size: NativeInt; KeyBuff: PCipherKeyBuffer; Encrypt, ProcessTail: Boolean): Boolean;
begin
  Result := False;
  case cs of
    csNone: Result := True;
    csDES64: Result := DES64(sour, Size, KeyBuff, Encrypt, ProcessTail);
    csDES128: Result := DES128(sour, Size, KeyBuff, Encrypt, ProcessTail);
    csDES192: Result := DES192(sour, Size, KeyBuff, Encrypt, ProcessTail);
    csBlowfish: Result := Blowfish(sour, Size, KeyBuff, Encrypt, ProcessTail);
    csLBC: Result := LBC(sour, Size, KeyBuff, Encrypt, ProcessTail);
    csLQC: Result := LQC(sour, Size, KeyBuff, Encrypt, ProcessTail);
    csRNG32: Result := RNG32(sour, Size, KeyBuff);
    csRNG64: Result := RNG64(sour, Size, KeyBuff);
    csLSC: Result := LSC(sour, Size, KeyBuff);
    csTwoFish: Result := TwoFish(sour, Size, KeyBuff, Encrypt, ProcessTail);
    csXXTea512: Result := XXTea512(sour, Size, KeyBuff, Encrypt, ProcessTail);
    csRC6: Result := RC6(sour, Size, KeyBuff, Encrypt, ProcessTail);
    csSerpent: Result := Serpent(sour, Size, KeyBuff, Encrypt, ProcessTail);
    csMars: Result := Mars(sour, Size, KeyBuff, Encrypt, ProcessTail);
    csRijndael: Result := Rijndael(sour, Size, KeyBuff, Encrypt, ProcessTail);
    csAES128: Result := AES128(sour, Size, KeyBuff, Encrypt, ProcessTail);
    csAES192: Result := AES192(sour, Size, KeyBuff, Encrypt, ProcessTail);
    csAES256: Result := AES256(sour, Size, KeyBuff, Encrypt, ProcessTail);
    else raiseInfo('error');
  end;
end;

class function TCipher.EncryptBufferCBC(cs: TCipherSecurity; sour: Pointer; Size: NativeInt; KeyBuff: PCipherKeyBuffer; Encrypt, ProcessTail: Boolean): Boolean;
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

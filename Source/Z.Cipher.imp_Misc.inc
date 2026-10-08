class procedure TRNG.EncryptRNG32(var Context: TRNG32Context; var Buf; BufSize: Integer);
var
  i: Integer;
begin
  for i := 0 to BufSize - 1 do
      TCCByteArray(Buf)[i] := TCCByteArray(Buf)[i] xor { !!.01 }
    TMISC.Random32Byte(Integer(Context));
end;

class procedure TRNG.EncryptRNG64(var Context: TRNG64Context; var Buf; BufSize: Integer);
var
  i: Integer;
begin
  for i := 0 to BufSize - 1 do
      TCCByteArray(Buf)[i] := TCCByteArray(Buf)[i] xor { !!.01 }
    TMISC.Random64Byte(TInt64(Context));
end;

class procedure TRNG.InitEncryptRNG32(key: DWORD; var Context: TRNG32Context);
begin
  DWORD(Context) := key;
end;

class procedure TRNG.InitEncryptRNG64(KeyHi, KeyLo: DWORD; var Context: TRNG64Context);
begin
  TInt64(Context).Lo := Integer(KeyLo);
  TInt64(Context).Hi := Integer(KeyHi);
end;

class procedure THashMD.GenerateLMDKey(var key; KeySize: Integer; const Bytes_: TBytes);
begin
  HashLMD(key, KeySize, Bytes_[0], length(Bytes_));
end;

class procedure THashMD.HashLMD(var Digest; DigestSize: Integer; const Buf; BufSize: NativeInt);
var
  Context: TLMDContext;
begin
  InitLMD(Context);
  UpdateLMD(Context, Buf, BufSize);
  FinalizeLMD(Context, Digest, DigestSize);
end;

class procedure THashMD.ByteBuffHashLMD(var Digest; DigestSize: Integer; const Bytes_: TBytes);
begin
  HashLMD(Digest, DigestSize, Bytes_[0], length(Bytes_));
end;

class procedure THashMD.InitLMD(var Context: TLMDContext);
begin
  Context.DigestIndex := 0;
  TBlock2048(Context.Digest) := TBlock2048(Pi2048);

  Context.KeyIndex := 0;
  Context.KeyInts[0] := $55555555;
  Context.KeyInts[1] := $55555555;
  Context.KeyInts[2] := $55555555;
  Context.KeyInts[3] := $55555555;
end;

class procedure THashMD.UpdateLMD(var Context: TLMDContext; const Buf; BufSize: NativeInt);
var
  AA, BB, cc, DD: DWORD;
  i, R: NativeInt;
begin
  for i := 0 to BufSize - 1 do
    with Context do begin
        { update Digest }
        Digest[DigestIndex] := Digest[DigestIndex] xor
          TCCByteArray(Buf)[i]; { !!.01 }
        DigestIndex := DigestIndex + 1;
        if (DigestIndex = SizeOf(Digest)) then
            DigestIndex := 0;

        { update BlockKey }
        key[KeyIndex] := key[KeyIndex] xor TCCByteArray(Buf)[i]; { !!.01 }
        KeyIndex := KeyIndex + 1;
        if (KeyIndex = SizeOf(key) div 2) then begin
            AA := KeyInts[3];
            BB := KeyInts[2];
            cc := KeyInts[1];
            DD := KeyInts[0];

            { mix all the bits around for 4 rounds }
            { achieves avalanche and eliminates funnels }
            for R := 0 to 3 do
              begin
                inc(AA, DD);
                inc(DD, AA);
                AA := AA xor (AA shr 7);
                inc(BB, AA);
                inc(AA, BB);
                BB := BB xor (BB shl 13);
                inc(cc, BB);
                inc(BB, cc);
                cc := cc xor (cc shr 17);
                inc(DD, cc);
                inc(cc, DD);
                DD := DD xor (DD shl 9);
                inc(AA, DD);
                inc(DD, AA);
                AA := AA xor (AA shr 3);
                inc(BB, AA);
                inc(AA, BB);
                BB := BB xor (BB shl 7);
                inc(cc, BB);
                inc(BB, cc);
                cc := cc xor (DD shr 15);
                inc(DD, cc);
                inc(cc, DD);
                DD := DD xor (DD shl 11);
              end;

            KeyInts[0] := AA;
            KeyInts[1] := BB;
            KeyInts[2] := cc;
            KeyInts[3] := DD;

            KeyIndex := 0;
          end;
      end;
end;

class procedure THashMD.FinalizeLMD(var Context: TLMDContext; var Digest; DigestSize: Integer);
const
  Padding: array [0 .. 7] of Byte = (1, 0, 0, 0, 0, 0, 0, 0);
var
  BCContext: TLBCContext;
  i: Integer;
begin
  { pad with "1", followed by as many "0"s as needed to fill the block }
  UpdateLMD(Context, Padding, SizeOf(Padding) - Context.KeyIndex);

  { mix context using block cipher }
  TLBC.InitEncryptLBC(Context.key, BCContext, 8, True);
  for i := 0 to (SizeOf(Context.Digest) div SizeOf(TLBCBlock)) - 1 do
      TLBC.EncryptLBC(BCContext, PLBCBlock(@Context.Digest[i * SizeOf(TLBCBlock)])^);

  { return Digest of requested DigestSize }
  { max digest is 2048-bit, although it could be greater if Pi2048 was larger }
  if DigestSize > SizeOf(Context.Digest) then
      FillPtrByte(@Digest, DigestSize, 0);
  CopyPtr(@Context.Digest, @Digest, Min(SizeOf(Context.Digest), DigestSize));
end;

class procedure TLSC.EncryptLSC(var Context: TLSCContext; var Buf; BufSize: Integer);
var
  L, y, x: Integer;
  i, a: Integer;
begin
  i := Context.index;
  a := Context.Accumulator;

  for L := 0 to BufSize - 1 do
    begin
      i := i + 1;

      x := Context.SBox[Byte(i)];
      y := Context.SBox[Byte(x)] + x;
      Context.SBox[Byte(i)] := Context.SBox[Byte(y)];
      Context.SBox[Byte(y)] := x;

      a := a + Context.SBox[Byte(Byte(y shr 8) + Byte(y))];
      TCCByteArray(Buf)[L] := TCCByteArray(Buf)[L] xor Byte(a); { !!.01 }
    end;

  Context.index := i;
  Context.Accumulator := a;
end;

class procedure TLSC.InitEncryptLSC(const key; KeySize: Integer; var Context: TLSCContext);
var
  R, i, a: Integer;
  x: Byte;
begin
  { initialize SBox }
  for i := 0 to 255 do
      Context.SBox[i] := i;

  a := 0;
  for R := 0 to 2 do { 3 rounds - "A" accumulates }
    for i := 0 to 255 do
      begin
        a := a + Context.SBox[i] + TCCByteArray(key)[i mod KeySize]; { !!.01 }
        x := Context.SBox[i];
        Context.SBox[i] := Context.SBox[Byte(a)];
        Context.SBox[Byte(a)] := x;
      end;

  Context.index := 0;
  Context.Accumulator := a;
end;

class procedure TMISC.GenerateRandomKey(var key; KeySize: Integer);
var
  i: Integer;
begin
  MT19937Randomize;
  for i := 0 to KeySize - 1 do
      TCCByteArray(key)[i] := MT19937Rand32(256); { !!.01 }
end;

class procedure TMISC.HashELF(var Digest: DWORD; const Buf; BufSize: NativeUInt);
var
  i: NativeUInt;
  x: DWORD;
begin
  Digest := 0;
  for i := 0 to BufSize - 1 do begin
      Digest := (Digest shl 4) + TCCByteArray(Buf)[i]; { !!.01 }
      x := Digest and $F0000000;
      if (x <> 0) then
          Digest := Digest xor (x shr 24);
      Digest := Digest and (not x);
    end;
end;

class procedure TMISC.HashELF64(var Digest: Int64; const Buf; BufSize: NativeUInt);
var
  i: NativeUInt;
  x: Int64;
begin
  Digest := 0;
  for i := 0 to BufSize - 1 do begin
      Digest := (Digest shl 4) + TCCByteArray(Buf)[i]; { !!.01 }
      x := Digest and Int64($F000000000000000);
      if (x <> 0) then
          Digest := Digest xor (x shr 56);
      Digest := Digest and (not x);
    end;
end;

class procedure TMISC.HashMix128(var Digest: DWORD; const Buf; BufSize: NativeInt);
type
  T128BitArray = array [0 .. MaxStructSize div SizeOf(T128Bit) - 1] of T128Bit;
var
  Temp: T128Bit;
  PTemp: PCCByteArray;
  i, L: NativeInt;
begin
{$IFDEF RangeCheck}{$R-}{$ENDIF}
  Temp[0] := $243F6A88; { first 16 bytes of Pi in binary }
  Temp[1] := $93F40317;
  Temp[2] := $0C110496;
  Temp[3] := $C709C289;

  L := BufSize div SizeOf(T128Bit);
  for i := 0 to L - 1 do begin
      Temp[0] := Temp[0] + T128BitArray(Buf)[i][0]; { !!.01 }
      Temp[1] := Temp[1] + T128BitArray(Buf)[i][1]; { !!.01 }
      Temp[2] := Temp[2] + T128BitArray(Buf)[i][2]; { !!.01 }
      Temp[3] := Temp[3] + T128BitArray(Buf)[i][3]; { !!.01 }
      Mix128(Temp);
    end;

  PTemp := @Temp;
  if (BufSize > L * SizeOf(T128Bit)) then
    begin
      for i := 0 to (BufSize - L * SizeOf(T128Bit)) - 1 do
          inc(PTemp^[i], PCCByteArray(@Buf)^[(L * SizeOf(T128Bit)) + i]); { !!.01 }
      Mix128(Temp);
    end;

  Digest := Temp[3];
{$IFDEF RangeCheck}{$R+}{$ENDIF}
end;

class procedure TMISC.Mix128(var x: T128Bit);
var
  AA, BB, cc, DD: DWORD;
begin
  AA := x[0];
  BB := x[1];
  cc := x[2];
  DD := x[3];

  AA := AA + DD;
  DD := DD + AA;
  AA := AA xor (AA shr 7);
  BB := BB + AA;
  AA := AA + BB;
  BB := BB xor (BB shl 13);
  cc := cc + BB;
  BB := BB + cc;
  cc := cc xor (cc shr 17);
  DD := DD + cc;
  cc := cc + DD;
  DD := DD xor (DD shl 9);
  AA := AA + DD;
  DD := DD + AA;
  AA := AA xor (AA shr 3);
  BB := BB + AA;
  AA := AA + BB;
  BB := BB xor (BB shl 7);
  cc := cc + BB;
  BB := BB + cc;
  cc := cc xor (DD shr 15);
  DD := DD + cc;
  cc := cc + DD;
  DD := DD xor (DD shl 11);

  x[0] := AA;
  x[1] := BB;
  x[2] := cc;
  x[3] := DD;
end;

class function TMISC.Ran01(var Seed: Integer): Integer;
begin
  Result := Ran0Prim(Seed, 16807, 127773, 2836);
end;

class function TMISC.Ran02(var Seed: Integer): Integer;
begin
  Result := Ran0Prim(Seed, 48271, 44488, 3399);
end;

class function TMISC.Ran03(var Seed: Integer): Integer;
begin
  Result := Ran0Prim(Seed, 69621, 30845, 23902);
end;

class function TMISC.Ran0Prim(var Seed: Integer; IA, IQ, IR: Integer): Integer;
const
  IM = 2147483647;
  MA = 123459876;
var
  i, k: Integer;
begin
  { XORing with mask avoids seeds of zero }
  i := Seed xor MA;
  k := i div IQ;
  i := (IA * (i - (k * IQ))) - (IR * k);
  if i < 0 then
      i := i + IM;
  Result := i xor MA;
  Seed := Result;
end;

class function TMISC.Random32Byte(var Seed: Integer): Byte;
var
  L: Integer;
  R: TInt32;
begin
  L := Ran01(Seed);
  R := TInt32(L);
  Result := R.LoLo xor R.LoHi xor R.HiLo xor R.HiHi;
end;

class function TMISC.Random64(var Seed: TInt64): Integer;
begin
  Ran01(Seed.Lo);
  Ran01(Seed.Hi);
  Result := Seed.Lo xor Seed.Hi;
end;

class function TMISC.Random64Byte(var Seed: TInt64): Byte;
var
  L: Integer;
  R: TInt32;
begin
  L := Random64(Seed);
  R := TInt32(L);
  Result := R.LoLo xor R.LoHi xor R.HiLo xor R.HiHi;
end;

class function TMISC.RolX(i, c: DWORD): DWORD;
begin
  Result := (i shl (c and 31)) or (i shr (32 - (c and 31)));
end;

class procedure TMISC.ByteBuffHashELF(var Digest: DWORD; const Bytes_: TBytes);
begin
  HashELF(Digest, Bytes_[0], length(Bytes_));
end;

class procedure TMISC.ByteBuffHashMix128(var Digest: DWORD; const Bytes_: TBytes);
begin
  HashMix128(Digest, Bytes_[0], length(Bytes_));
end;

class procedure TMISC.Transform(var OutputBuffer: TTransformOutput; var InBuf: TTransformInput);
const
  S11 = 7;
  S12 = 12;
  S13 = 17;
  S14 = 22;
  S21 = 5;
  S22 = 9;
  S23 = 14;
  S24 = 20;
  S31 = 4;
  S32 = 11;
  S33 = 16;
  S34 = 23;
  S41 = 6;
  S42 = 10;
  S43 = 15;
  S44 = 21;
var
  a: DWORD;
  b: DWORD;
  c: DWORD;
  d: DWORD;

  procedure FF(var a: DWORD; const b, c, d, x, s, AC: DWORD);
  begin
    a := RolX(a + ((b and c) or (not b and d)) + x + AC, s) + b;
  end;

  procedure GG(var a: DWORD; const b, c, d, x, s, AC: DWORD);
  begin
    a := RolX(a + ((b and d) or (c and not d)) + x + AC, s) + b;
  end;

  procedure hh(var a: DWORD; const b, c, d, x, s, AC: DWORD);
  begin
    a := RolX(a + (b xor c xor d) + x + AC, s) + b;
  end;

  procedure II(var a: DWORD; const b, c, d, x, s, AC: DWORD);
  begin
    a := RolX(a + (c xor (b or not d)) + x + AC, s) + b;
  end;

begin
  a := OutputBuffer[0];
  b := OutputBuffer[1];
  c := OutputBuffer[2];
  d := OutputBuffer[3];

  { round 1 }
  FF(a, b, c, d, InBuf[0], S11, $D76AA478); { 1 }
  FF(d, a, b, c, InBuf[1], S12, $E8C7B756); { 2 }
  FF(c, d, a, b, InBuf[2], S13, $242070DB); { 3 }
  FF(b, c, d, a, InBuf[3], S14, $C1BDCEEE); { 4 }
  FF(a, b, c, d, InBuf[4], S11, $F57C0FAF); { 5 }
  FF(d, a, b, c, InBuf[5], S12, $4787C62A); { 6 }
  FF(c, d, a, b, InBuf[6], S13, $A8304613); { 7 }
  FF(b, c, d, a, InBuf[7], S14, $FD469501); { 8 }
  FF(a, b, c, d, InBuf[8], S11, $698098D8); { 9 }
  FF(d, a, b, c, InBuf[9], S12, $8B44F7AF); { 10 }
  FF(c, d, a, b, InBuf[10], S13, $FFFF5BB1); { 11 }
  FF(b, c, d, a, InBuf[11], S14, $895CD7BE); { 12 }
  FF(a, b, c, d, InBuf[12], S11, $6B901122); { 13 }
  FF(d, a, b, c, InBuf[13], S12, $FD987193); { 14 }
  FF(c, d, a, b, InBuf[14], S13, $A679438E); { 15 }
  FF(b, c, d, a, InBuf[15], S14, $49B40821); { 16 }

  { round 2 }
  GG(a, b, c, d, InBuf[1], S21, $F61E2562); { 17 }
  GG(d, a, b, c, InBuf[6], S22, $C040B340); { 18 }
  GG(c, d, a, b, InBuf[11], S23, $265E5A51); { 19 }
  GG(b, c, d, a, InBuf[0], S24, $E9B6C7AA); { 20 }
  GG(a, b, c, d, InBuf[5], S21, $D62F105D); { 21 }
  GG(d, a, b, c, InBuf[10], S22, $02441453); { 22 }
  GG(c, d, a, b, InBuf[15], S23, $D8A1E681); { 23 }
  GG(b, c, d, a, InBuf[4], S24, $E7D3FBC8); { 24 }
  GG(a, b, c, d, InBuf[9], S21, $21E1CDE6); { 25 }
  GG(d, a, b, c, InBuf[14], S22, $C33707D6); { 26 }
  GG(c, d, a, b, InBuf[3], S23, $F4D50D87); { 27 }
  GG(b, c, d, a, InBuf[8], S24, $455A14ED); { 28 }
  GG(a, b, c, d, InBuf[13], S21, $A9E3E905); { 29 }
  GG(d, a, b, c, InBuf[2], S22, $FCEFA3F8); { 30 }
  GG(c, d, a, b, InBuf[7], S23, $676F02D9); { 31 }
  GG(b, c, d, a, InBuf[12], S24, $8D2A4C8A); { 32 }

  { round 3 }
  hh(a, b, c, d, InBuf[5], S31, $FFFA3942); { 33 }
  hh(d, a, b, c, InBuf[8], S32, $8771F681); { 34 }
  hh(c, d, a, b, InBuf[11], S33, $6D9D6122); { 35 }
  hh(b, c, d, a, InBuf[14], S34, $FDE5380C); { 36 }
  hh(a, b, c, d, InBuf[1], S31, $A4BEEA44); { 37 }
  hh(d, a, b, c, InBuf[4], S32, $4BDECFA9); { 38 }
  hh(c, d, a, b, InBuf[7], S33, $F6BB4B60); { 39 }
  hh(b, c, d, a, InBuf[10], S34, $BEBFBC70); { 40 }
  hh(a, b, c, d, InBuf[13], S31, $289B7EC6); { 41 }
  hh(d, a, b, c, InBuf[0], S32, $EAA127FA); { 42 }
  hh(c, d, a, b, InBuf[3], S33, $D4EF3085); { 43 }
  hh(b, c, d, a, InBuf[6], S34, $4881D05); { 44 }
  hh(a, b, c, d, InBuf[9], S31, $D9D4D039); { 45 }
  hh(d, a, b, c, InBuf[12], S32, $E6DB99E5); { 46 }
  hh(c, d, a, b, InBuf[15], S33, $1FA27CF8); { 47 }
  hh(b, c, d, a, InBuf[2], S34, $C4AC5665); { 48 }

  { round 4 }
  II(a, b, c, d, InBuf[0], S41, $F4292244); { 49 }
  II(d, a, b, c, InBuf[7], S42, $432AFF97); { 50 }
  II(c, d, a, b, InBuf[14], S43, $AB9423A7); { 51 }
  II(b, c, d, a, InBuf[5], S44, $FC93A039); { 52 }
  II(a, b, c, d, InBuf[12], S41, $655B59C3); { 53 }
  II(d, a, b, c, InBuf[3], S42, $8F0CCC92); { 54 }
  II(c, d, a, b, InBuf[10], S43, $FFEFF47D); { 55 }
  II(b, c, d, a, InBuf[1], S44, $85845DD1); { 56 }
  II(a, b, c, d, InBuf[8], S41, $6FA87E4F); { 57 }
  II(d, a, b, c, InBuf[15], S42, $FE2CE6E0); { 58 }
  II(c, d, a, b, InBuf[6], S43, $A3014314); { 59 }
  II(b, c, d, a, InBuf[13], S44, $4E0811A1); { 60 }
  II(a, b, c, d, InBuf[4], S41, $F7537E82); { 61 }
  II(d, a, b, c, InBuf[11], S42, $BD3AF235); { 62 }
  II(c, d, a, b, InBuf[2], S43, $2AD7D2BB); { 63 }
  II(b, c, d, a, InBuf[9], S44, $EB86D391); { 64 }

  inc(OutputBuffer[0], a);
  inc(OutputBuffer[1], b);
  inc(OutputBuffer[2], c);
  inc(OutputBuffer[3], d);
end;

class procedure TMISC.XorMem(var Mem1; const Mem2; Count: NativeInt);
var
  siz: Byte;
  i: Integer;
  p1, p2: NativeUInt;
begin
  p1 := NativeUInt(@Mem1);
  p2 := NativeUInt(@Mem2);
  siz := SizeOf(NativeUInt);

  for i := 1 to Count div siz do
    begin
      PNativeUInt(p1)^ := PNativeUInt(p1)^ xor PNativeUInt(p2)^;
      p1 := p1 + siz;
      p2 := p2 + siz;
    end;
  for i := 1 to Count mod siz do
    begin
      PByte(p1)^ := PByte(p1)^ xor PByte(p2)^;
      p1 := p1 + 1;
      p2 := p2 + 1;
    end;
end;

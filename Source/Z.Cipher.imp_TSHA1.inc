{===============================================================================
 * Z.Cipher.imp_TSHA1.inc  ¡ª  SHA-1 message digest implementation
 *
 * Bug fixes applied (FPC O2 optimization safety):
 *   1. CRITICAL: "CopyPtr(@sdBuf, @w, SizeOf(w))" in SHA1Hash read 320 bytes
 *      from a 64-byte source buffer, overflowing 256 bytes into adjacent
 *      stack variables. Under FPC -O2 this causes non-deterministic hash
 *      values (or crashes) because the stack layout differs from -O0.
 *      FIXED: use "CopyPtr(@sdBuf[0], @w[0], SizeOf(sdBuf))" ¡ª copy exactly
 *      64 bytes (16 DWORDs). The remaining w[16..79] are computed by the
 *      message-schedule expansion loop.
 *   2. Explicitly zero-fill the entire w[] array before use (FillPtr), so
 *      that under -O2 no stale register/stack data can leak into the
 *      schedule.
 *   3. Explicit DWORD() casts in SHA1UpdateLen to make the shift+mask
 *      behaviour unambiguous across FPC optimization levels.
 *
 * Conventions (project-wide):
 *   - No Move / no FillChar. Use CopyPtr / FillPtr from Z.Core.
 *   - English comments only.
===============================================================================}

class procedure TSHA1.SHA1Clear(var Context: TSHA1Context);
begin
  FillPtr(@Context, SizeOf(Context), $00);
end;

class procedure TSHA1.SHA1Hash(var Context: TSHA1Context);
var
  a: DWORD;
  b: DWORD;
  c: DWORD;
  d: DWORD;
  E: DWORD;

  x: DWORD;
  w: array [0 .. 79] of DWORD;

  i: Integer;
begin
  with Context do
    begin
      sdIndex := 0;

      { FIX: zero the whole 80-DWORD work array first (no FillChar),
        then copy exactly the 16 DWORDs (= 64 bytes) that live in sdBuf.
        The previous code copied SizeOf(w) = 320 bytes from a 64-byte
        buffer, which is a stack overflow. }
      FillPtr(@w[0], SizeOf(w), 0);
      CopyPtr(@sdBuf[0], @w[0], SizeOf(sdBuf));

      { W[0..15] := M[t], byte-swapped to little-endian }
      for i := 0 to 15 do
          w[i] := SHA1SwapByteOrder(w[i]);

      { Expand W[16..79]:
        W[t] = ROL1( W[t-3] xor W[t-8] xor W[t-14] xor W[t-16] ) }
      for i := 16 to 79 do
          w[i] := TMISC.RolX(w[i - 3] xor w[i - 8] xor w[i - 14] xor w[i - 16], 1);

      a := sdHash[0];
      b := sdHash[1];
      c := sdHash[2];
      d := sdHash[3];
      E := sdHash[4];

      { Round 1: t = 0..19 }
      for i := 0 to 19 do
        begin
          x := TMISC.RolX(a, 5) + (d xor (b and (c xor d))) + E + w[i] + SHA1_K1;
          E := d;
          d := c;
          c := TMISC.RolX(b, 30);
          b := a;
          a := x;
        end;

      { Round 2: t = 20..39 }
      for i := 20 to 39 do
        begin
          x := TMISC.RolX(a, 5) + (b xor c xor d) + E + w[i] + SHA1_K2;
          E := d;
          d := c;
          c := TMISC.RolX(b, 30);
          b := a;
          a := x;
        end;

      { Round 3: t = 40..59 }
      for i := 40 to 59 do
        begin
          x := TMISC.RolX(a, 5) + ((b and c) or (d and (b or c))) + E + w[i] + SHA1_K3;
          E := d;
          d := c;
          c := TMISC.RolX(b, 30);
          b := a;
          a := x;
        end;

      { Round 4: t = 60..79 }
      for i := 60 to 79 do
        begin
          x := TMISC.RolX(a, 5) + (b xor c xor d) + E + w[i] + SHA1_K4;
          E := d;
          d := c;
          c := TMISC.RolX(b, 30);
          b := a;
          a := x;
        end;

      sdHash[0] := sdHash[0] + a;
      sdHash[1] := sdHash[1] + b;
      sdHash[2] := sdHash[2] + c;
      sdHash[3] := sdHash[3] + d;
      sdHash[4] := sdHash[4] + E;

      { Wipe the transient schedule and the block buffer }
      FillPtr(@w[0], SizeOf(w), $00);
      FillPtr(@sdBuf[0], SizeOf(sdBuf), $00);
    end;
end;

class function TSHA1.SHA1SwapByteOrder(n: DWORD): DWORD;
begin
  { Byte-swap a 32-bit word: B0<->B3, B1<->B2.
    Note: LBMASK_LO ($0000FF00) and LBMASK_HI ($00FF0000) are actually
    byte-permutation masks here, not endianness masks. Names kept for
    ABI/unit compatibility. }
  n := (n shr 24) or ((n shr 8) and LBMASK_LO) or ((n shl 8) and LBMASK_HI) or (n shl 24);
  Result := n;
end;

class procedure TSHA1.SHA1UpdateLen(var Context: TSHA1Context; Len: DWORD);
var
  bitsLo: DWORD;
begin
  { Compute the 64-bit bit-length counter (sdHi:sdLo).
    Use explicit DWORD() casts so FPC -O2 does not widen the shift
    to 64-bit and change masking behaviour. }
  bitsLo := DWORD(Len shl 3);
  inc(Context.sdLo, bitsLo);
  if Context.sdLo < bitsLo then
      inc(Context.sdHi);
  inc(Context.sdHi, DWORD(Len shr 29));
end;

class procedure TSHA1.SHA1(var Digest: TSHA1Digest; const Buf; BufSize: NativeUInt);
var
  Context: TSHA1Context;
begin
  InitSHA1(Context);
  UpdateSHA1(Context, Buf, BufSize);
  FinalizeSHA1(Context, Digest);
end;

class procedure TSHA1.ByteBuffSHA1(var Digest: TSHA1Digest; const Bytes_: TBytes);
begin
  SHA1(Digest, Bytes_[0], length(Bytes_));
end;

class procedure TSHA1.InitSHA1(var Context: TSHA1Context);
begin
  SHA1Clear(Context);
  Context.sdHash[0] := SHA1_A;
  Context.sdHash[1] := SHA1_B;
  Context.sdHash[2] := SHA1_C;
  Context.sdHash[3] := SHA1_D;
  Context.sdHash[4] := SHA1_E;
end;

class procedure TSHA1.UpdateSHA1(var Context: TSHA1Context; const Buf; BufSize: NativeUInt);
var
  PBuf: PByte;
  Chunk: NativeUInt;
begin
  with Context do
    begin
      SHA1UpdateLen(Context, DWORD(BufSize));
      PBuf := @Buf;
      while BufSize > 0 do
        begin
          Chunk := SizeOf(sdBuf) - sdIndex;
          if Chunk <= BufSize then
            begin
              CopyPtr(PBuf, @sdBuf[sdIndex], Chunk);
              dec(BufSize, Chunk);
              inc(PBuf, Chunk);
              SHA1Hash(Context);
              { After SHA1Hash, sdIndex is reset to 0 internally. }
            end
          else
            begin
              CopyPtr(PBuf, @sdBuf[sdIndex], BufSize);
              inc(sdIndex, BufSize);
              BufSize := 0;
            end;
        end;
    end;
end;

class procedure TSHA1.FinalizeSHA1(var Context: TSHA1Context; var Digest: TSHA1Digest);
begin
  with Context do
    begin
      { Append the 0x80 terminator }
      sdBuf[sdIndex] := $80;

      { If there is no room for the 8-byte length field, flush the block }
      if sdIndex >= 56 then
          SHA1Hash(Context);

      { Write the 64-bit bit-length, big-endian }
      PDWORD(@sdBuf[56])^ := SHA1SwapByteOrder(sdHi);
      PDWORD(@sdBuf[60])^ := SHA1SwapByteOrder(sdLo);

      SHA1Hash(Context);

      { Convert the final state to big-endian for the digest }
      sdHash[0] := SHA1SwapByteOrder(sdHash[0]);
      sdHash[1] := SHA1SwapByteOrder(sdHash[1]);
      sdHash[2] := SHA1SwapByteOrder(sdHash[2]);
      sdHash[3] := SHA1SwapByteOrder(sdHash[3]);
      sdHash[4] := SHA1SwapByteOrder(sdHash[4]);

      CopyPtr(@sdHash[0], @Digest, SizeOf(Digest));
      SHA1Clear(Context);
    end;
end;

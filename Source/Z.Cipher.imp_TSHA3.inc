{
  * ============================================================================
  * Z.Cipher.imp_TSHA3.inc
  *
  * SHA-3 (FIPS 202) family implementation: SHA3-224/256/384/512 and
  * SHAKE128/256 extendable-output functions.
  *
  * Bug fixes applied (FPC -O2 optimization safety):
  *
  *   1. CRITICAL ！ the padding fill length formula in FinalizeSHA3 and
  *      FinalizeSHAKE was "(BlockLen - 2) - (BufSize + 1)", which is one
  *      byte short of the region that must be zeroed. As a result, the
  *      byte at index (BlockLen - 2) retained whatever value it had from
  *      the previous block (or, on the very first call, an uninitialized
  *      dynamic-array byte). This corrupted the padding and made the
  *      digest non-deterministic. FIXED: the correct length is
  *      "BlockLen - BufSize - 2".
  *
  *   2. CRITICAL ！ FinalizeSHA3 wrote whole 8-byte lanes without checking
  *      the remaining HashLength. For SHA3-224 (HashLength = 28) the last
  *      lane write touched bytes [24..31] of a 28-byte destination,
  *      overflowing by 4 bytes. FIXED: each iteration writes
  *      "Min(8, HashLength - i)" bytes.
  *
  *   3. CRITICAL ！ FinalizeSHAKE computed the per-chunk output length as
  *      "Min(Size, Limit - k)" where "Limit" is decremented each round
  *      (remaining bytes) and "k" is incremented (bytes written so far).
  *      Their difference is meaningless; from the second round onward it
  *      went negative, and as an unsigned NativeUInt it wrapped to a huge
  *      value, causing an enormous out-of-bounds write. FIXED: use the
  *      current round's "Size" (already clamped by Min(Remaining,BlockLen)).
  *
  *   4. SEVERE ！ both "PUInt64(@Context.Buffer[i])^" and
  *      "PUInt64(@output^[i])^" assumed 8-byte alignment. Buffer is a
  *      dynamic byte array (alignment not guaranteed by the language) and
  *      output^ points into a caller-supplied byte buffer. On strict-
  *      alignment targets (ARM) an unaligned 64-bit read is a SIGBUS, and
  *      under FPC -O2 on x86 the compiler may vectorise the read assuming
  *      alignment. FIXED by staging every 8-byte transfer through a local
  *      UInt64 with CopyPtr.
  *
  *   5. SEVERE ！ Context.Buffer was SetLength'd but never zeroed. Since
  *      SHA3_BlockSHA3 consumes the full BlockLen bytes, any byte not written
  *      by the absorber would be XORed into the state as garbage. FIXED
  *      with an explicit FillPtr immediately after SetLength.
  *
  *   6. Context.Buffer is now wiped with FillPtr before SetLength(_, 0),
  *      so sensitive intermediate state does not linger on the heap.
  *
  *   7. FillPtrByte replaced with FillPtr to match the project convention.
  *
  * ============================================================================
  * }

{$IFDEF RangeCheck}{$R-}{$ENDIF}
{$IFDEF OverflowCheck}{$Q-}{$ENDIF}


function SHA3_ComputeX(const x: Integer): Integer; {$IFDEF INLINE_ASM} inline; {$ENDIF INLINE_ASM}
begin
  {
    * Modular reduction of x into [0, 4].
    *
    * The callers of SHA3_ComputeX / SHA3_ComputeXY pass arguments in the range
    * [-4, 20], so the recursion depth is at most 4. Kept recursive for
    * behavioural fidelity with the reference implementation.
    * }
  if x < 0 then
      Result := SHA3_ComputeX(x + 5)
  else
      Result := x mod 5;
end;

function SHA3_ComputeXY(const x, y: Integer): Integer; {$IFDEF INLINE_ASM} inline; {$ENDIF INLINE_ASM}
begin
  {
    * Flat index into the 5x5 lane array: index = x + 5*y.
    * }
  Result := SHA3_ComputeX(x) + 5 * SHA3_ComputeX(y);
end;

procedure SHA3_BlockSHA3(var Context: TSHA3.TSHA3Context); {$IFDEF INLINE_ASM} inline; {$ENDIF INLINE_ASM}
const
  {
    * Round constants for the Keccak-f[1600] permutation.
  }
  // Round constants
  RC: array [0 .. 23] of UInt64 = (
    $0000000000000001, $0000000000008082, $800000000000808A, $8000000080008000,
    $000000000000808B, $0000000080000001, $8000000080008081, $8000000000008009,
    $000000000000008A, $0000000000000088, $0000000080008009, $000000008000000A,
    $000000008000808B, $800000000000008B, $8000000000008089, $8000000000008003,
    $8000000000008002, $8000000000000080, $000000000000800A, $800000008000000A,
    $8000000080008081, $8000000000008080, $0000000080000001, $8000000080008008);

  {
    * Rho rotation offsets for the Keccak-f[1600] permutation.
  }
  // Rotation offsets
  RO: array [0 .. 24] of Integer = (0, 1, 62, 28, 27, 36, 44, 6, 55, 20, 3, 10, 43, 25, 39, 41, 45, 15, 21, 8, 18, 2, 61, 56, 14);

var
  i, x, y: Integer;
  lane: UInt64;
begin
  {
    * Absorb the current block into the state lanes. The rate is
    * BlockLen bytes, i.e. BlockLen div 8 64-bit lanes (BlockLen is always
    * a multiple of 8 for every SHA-3 variant).
    *
    * FIX: use CopyPtr into a local UInt64 instead of PUInt64(@Buffer[i])^,
    * so no 8-byte alignment is assumed on the dynamic Buffer.
    * }
  i := 0;
  while i < Context.BlockLen do
    begin
      lane := 0;
      CopyPtr(@Context.Buffer[i], @lane, 8);
      Context.a[i shr 3] := Context.a[i shr 3] Xor lane;
      inc(i, 8);
    end;

  {
    * Keccak-f[1600] permutation: 24 rounds.
    * }
  for i := 0 to 23 do
    begin
      {
        * Theta step: column parities.
        * }
      for x := 0 to 4 do
          Context.c[x] :=
          Context.a[SHA3_ComputeXY(x, 0)] Xor
          Context.a[SHA3_ComputeXY(x, 1)] Xor
          Context.a[SHA3_ComputeXY(x, 2)] Xor
          Context.a[SHA3_ComputeXY(x, 3)] Xor
          Context.a[SHA3_ComputeXY(x, 4)];

      for x := 0 to 4 do
        begin
          Context.d[x] := Context.c[SHA3_ComputeX(x - 1)] Xor ROL64(Context.c[SHA3_ComputeX(x + 1)], 1);
          for y := 0 to 4 do
              Context.a[SHA3_ComputeXY(x, y)] := Context.a[SHA3_ComputeXY(x, y)] Xor Context.d[x];
        end;

      {
        * Rho and Pi steps: rotate and permute the lanes into Context.b.
        * }
      for x := 0 to 4 do
        for y := 0 to 4 do
            Context.b[SHA3_ComputeXY(y, x * 2 + 3 * y)] :=
            ROL64(Context.a[SHA3_ComputeXY(x, y)], RO[SHA3_ComputeXY(x, y)]);

      {
        * Chi step: non-linear mixing.
        * }
      for x := 0 to 4 do
        for y := 0 to 4 do
            Context.a[SHA3_ComputeXY(x, y)] :=
            Context.b[SHA3_ComputeXY(x, y)]
            Xor ((not Context.b[SHA3_ComputeXY(x + 1, y)]) And Context.b[SHA3_ComputeXY(x + 2, y)]);

      {
        * Iota step: XOR the round constant into lane (0, 0).
        * }
      Context.a[0] := Context.a[0] Xor RC[i];
    end;

  Context.BufSize := 0;
end;

{$IFDEF RangeCheck}{$R+}{$ENDIF}
{$IFDEF OverflowCheck}{$Q+}{$ENDIF}


class procedure TSHA3.InitializeSHA3(var Context: TSHA3Context; HashLength: Integer);
var
  i: Integer;
begin
  Context.HashLength := HashLength;
  Context.BlockLen := 200 - 2 * HashLength;

  SetLength(Context.Buffer, Context.BlockLen);
  {
    * FIX: SetLength does not zero the freshly allocated dynamic array.
    * SHA3_BlockSHA3 consumes the entire BlockLen bytes, so any byte the
    * absorber did not write would be XORed into the state as garbage.
    * }
  FillPtr(@Context.Buffer[0], Context.BlockLen, 0);

  Context.BufSize := 0;

  for i := 0 to 24 do
    begin
      Context.a[i] := 0;
      Context.b[i] := 0;
    end;

  for i := 0 to 4 do
    begin
      Context.c[i] := 0;
      Context.d[i] := 0;
    end;
end;

class procedure TSHA3.SHA3(var Context: TSHA3Context; Chunk: PByte; Size: NativeInt);
var
  Needed: NativeInt;
begin
  while Size > 0 do
    begin
      Needed := Min(NativeInt(Context.BlockLen - Context.BufSize), Size);
      CopyPtr(Chunk, @Context.Buffer[Context.BufSize], Needed);
      inc(Context.BufSize, Needed);
      dec(Size, Needed);

      if Context.BufSize = Context.BlockLen then
        begin
          SHA3_BlockSHA3(Context);
          Context.BufSize := 0;
          inc(Chunk, Needed);
        end;
    end;
end;

class procedure TSHA3.FinalizeSHA3(var Context: TSHA3Context; const output: PCCByteArray);
var
  i: Integer;
  bytes: Integer;
  lane: UInt64;
begin
  {
    * Apply the SHA-3 domain-separation padding (0x06 ... 0x80).
    *
    * FIX: the original fill length was "(BlockLen - 2) - (BufSize + 1)",
    * which left the byte at index (BlockLen - 2) untouched. The correct
    * number of bytes to zero is "BlockLen - BufSize - 2".
    * }
  if Context.BufSize = Context.BlockLen - 1 then
      Context.Buffer[Context.BufSize] := Byte($81)
  else
    begin
      Context.Buffer[Context.BufSize] := Byte($06);
      FillPtr(@Context.Buffer[Context.BufSize + 1],
        Context.BlockLen - Context.BufSize - 2, 0);
      Context.Buffer[Context.BlockLen - 1] := Byte($80);
    end;

  SHA3_BlockSHA3(Context);

  {
    * Squeeze the digest. Each 64-bit lane is transferred via a local
    * UInt64 + CopyPtr to avoid the alignment assumption of PUInt64().
    *
    * FIX: for HashLength not divisible by 8 (SHA3-224: 28 bytes), the
    * final iteration must write only the remaining bytes, not a full
    * 8-byte lane, otherwise the caller's buffer is overrun.
    * }
  i := 0;
  while i < Context.HashLength do
    begin
      lane := Context.a[i shr 3];
      bytes := Min(8, Context.HashLength - i);
      CopyPtr(@lane, @output^[i], bytes);
      inc(i, 8);
    end;

  {
    * Wipe the state and release the rate buffer. SetLength(_, 0) does not
    * scrub the heap contents, so clear them explicitly first.
    * }
  for i := 0 to 24 do
      Context.a[i] := 0;

  Context.BufSize := 0;
  FillPtr(@Context.Buffer[0], Context.BlockLen, 0);
  SetLength(Context.Buffer, 0);
end;

class procedure TSHA3.FinalizeSHAKE(var Context: TSHA3Context; Limit: Integer; const output: PCCByteArray);
var
  tmp: array of Byte;
  i, j, k, ChunkSize, Remaining: Integer;
  lane: UInt64;
begin
  {
    * Apply the SHAKE domain-separation padding (0x1F ... 0x80).
    *
    * FIX: same one-byte-short fill-length bug as in FinalizeSHA3.
    * }
  if Context.BufSize = Context.BlockLen - 1 then
      Context.Buffer[Context.BufSize] := Byte($9F)
  else
    begin
      Context.Buffer[Context.BufSize] := Byte($1F);
      FillPtr(@Context.Buffer[Context.BufSize + 1],
        Context.BlockLen - Context.BufSize - 2, 0);
      Context.Buffer[Context.BlockLen - 1] := Byte($80);
    end;

  SHA3_BlockSHA3(Context);

  FillPtr(@Context.Buffer[0], Context.BlockLen, 0);

  {
    * Prepare the squeezing buffer. BlockLen is always a multiple of 8,
    * so the per-lane CopyPtr writes fill it exactly.
    * }
  SetLength(tmp, Context.BlockLen);
  FillPtr(@tmp[0], Context.BlockLen, 0);

  k := 0; { bytes written to output }
  Remaining := Limit; { bytes still to be produced }

  while Remaining > 0 do
    begin
      {
        * Serialize the current state lanes into tmp (little-endian).
        * }
      j := 0;
      while j < Context.BlockLen do
        begin
          lane := Context.a[j shr 3];
          CopyPtr(@lane, @tmp[j], 8);
          inc(j, 8);
        end;

      {
        * FIX: the original code computed the copy length as
        * "Min(Size, Limit - k)", which produced a negative (and then
        * unsigned-wrapped) value from the second round onward. The
        * correct length is simply the per-round chunk size.
        * }
      ChunkSize := Min(Remaining, Context.BlockLen);
      CopyPtr(@tmp[0], @output^[k], ChunkSize);
      dec(Remaining, ChunkSize);
      inc(k, ChunkSize);

      if Remaining > 0 then
          SHA3_BlockSHA3(Context);
    end;

  {
    * Wipe the state and the temporary buffer.
    * }
  for i := 0 to 24 do
      Context.a[i] := 0;

  Context.BufSize := 0;
  FillPtr(@tmp[0], Context.BlockLen, 0);
  SetLength(tmp, 0);
  FillPtr(@Context.Buffer[0], Context.BlockLen, 0);
  SetLength(Context.Buffer, 0);
end;

class procedure TSHA3.SHA224(var Digest: TSHA3_224_Digest; Buf: PByte; BufSize: NativeInt);
var
  Ctx: TSHA3Context;
begin
  InitializeSHA3(Ctx, 224 div 8);
  SHA3(Ctx, Buf, BufSize);
  FinalizeSHA3(Ctx, @Digest[0]);
end;

class procedure TSHA3.SHA256(var Digest: TSHA3_256_Digest; Buf: PByte; BufSize: NativeInt);
var
  Ctx: TSHA3Context;
begin
  InitializeSHA3(Ctx, 256 div 8);
  SHA3(Ctx, Buf, BufSize);
  FinalizeSHA3(Ctx, @Digest[0]);
end;

class procedure TSHA3.SHA384(var Digest: TSHA3_384_Digest; Buf: PByte; BufSize: NativeInt);
var
  Ctx: TSHA3Context;
begin
  InitializeSHA3(Ctx, 384 div 8);
  SHA3(Ctx, Buf, BufSize);
  FinalizeSHA3(Ctx, @Digest[0]);
end;

class procedure TSHA3.SHA512(var Digest: TSHA3_512_Digest; Buf: PByte; BufSize: NativeInt);
var
  Ctx: TSHA3Context;
begin
  InitializeSHA3(Ctx, 512 div 8);
  SHA3(Ctx, Buf, BufSize);
  FinalizeSHA3(Ctx, @Digest[0]);
end;

class procedure TSHA3.SHAKE128(const Digest: PCCByteArray; Buf: PByte; BufSize: NativeInt; Limit: Integer);
var
  Ctx: TSHA3Context;
begin
  InitializeSHA3(Ctx, 128 div 8);
  SHA3(Ctx, Buf, BufSize);
  FinalizeSHAKE(Ctx, Limit div 8, Digest);
end;

class procedure TSHA3.SHAKE256(const Digest: PCCByteArray; Buf: PByte; BufSize: NativeInt; Limit: Integer);
var
  Ctx: TSHA3Context;
begin
  InitializeSHA3(Ctx, 256 div 8);
  SHA3(Ctx, Buf, BufSize);
  FinalizeSHAKE(Ctx, Limit div 8, Digest);
end;

{$IFDEF RangeCheck}{$R+}{$ENDIF}
{$IFDEF OverflowCheck}{$Q+}{$ENDIF}

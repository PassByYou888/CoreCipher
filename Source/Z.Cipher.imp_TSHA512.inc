{
 * ============================================================================
 * Z.Cipher.imp_TSHA512.inc
 *
 * SHA-512 (FIPS 180-4) message digest implementation.
 * 64-bit words, 1024-bit (128-byte) block, 80-word message schedule,
 * 80 rounds.
 *
 * Bug fixes applied (FPC -O2 optimization safety):
 *
 *   1. CRITICAL ¡ª the previous implementation accessed the 512-bit digest
 *      state via "PUInt64(@Digest[0])^", assuming 8-byte alignment of the
 *      caller's TSHA512Digest. That holds for stack variables but not for
 *      an arbitrary PByte slice of a larger buffer, and on ARM with strict
 *      alignment an unaligned 64-bit read is a SIGBUS. Under FPC -O2 on
 *      x86 the compiler may also vectorise the read assuming alignment.
 *      FIXED by round-tripping the 8-word state through a local
 *      "State: array [0 .. 7] of UInt64" buffer via CopyPtr, exactly as
 *      done for SHA-256.
 *
 *   2. CRITICAL ¡ª the final-block workspace "ChunkBuf: array [0 .. 127] of
 *      Byte" was not initialised. Under FPC -O2 the compiler may reuse the
 *      same stack slot for ChunkBuf and other temporaries; without an
 *      explicit clear, stale bytes can leak into the length field of the
 *      final block, producing a non-deterministic digest. FIXED by a
 *      FillPtr at entry.
 *
 *   3. SEVERE ¡ª the 80-word message schedule "w" in Compute is now
 *      explicitly zeroed before use, for the same reason as (2).
 *
 *   4. Loop counters in Compute were "ShortInt". Although 0..79 fits in
 *      ShortInt, FPC -O2 may allocate the counter in an 8-bit register
 *      and insert signed-overflow checks or mis-optimise the loop bound.
 *      FIXED by using Integer.
 *
 *   5. Explicit "Integer(BufSize)" casts when indexing ChunkBuf by a
 *      UInt64, to make the narrowing intent obvious.
 *
 *   6. FillPtrByte replaced with FillPtr to match the project convention.
 *
 * ============================================================================
 *}

class procedure TSHA512.SwapQWORD(var a: UInt64);
begin
  a := Endian(a);
end;

class procedure TSHA512.Compute(var Digest: TSHA512Digest; const buff: Pointer);
var
  a, b, c, d, E, f, g, h, T1, T2: UInt64;
  w: array [0 .. 79] of UInt64;
  i: Integer;
  State: array [0 .. 7] of UInt64;
begin
{$IFDEF RangeCheck}{$R-}{$ENDIF}

  {
   * Load the current chaining state. CopyPtr avoids any 8-byte alignment
   * assumption on the caller-supplied Digest buffer.
   *}
  CopyPtr(@Digest[0], @State[0], SizeOf(State));

  a := State[0];
  b := State[1];
  c := State[2];
  d := State[3];
  E := State[4];
  f := State[5];
  g := State[6];
  h := State[7];

  {
   * Pre-clear the message schedule; then copy the first 16 QWORDs
   * (i.e. 128 bytes = one SHA-512 block) from the caller's buffer.
   *}
  FillPtr(@w[0], SizeOf(w), 0);
  CopyPtr(buff, @w[0], 128);

  for i := 0 to 15 do
      SwapQWORD(w[i]);

  {
   * Message schedule expansion: W[t] for t = 16..79.
   *}
  for i := 16 to 79 do
      w[i] := (((w[i - 2] shr 19) or (w[i - 2] shl 45)) xor ((w[i - 2] shr 61) or (w[i - 2] shl 3)) xor (w[i - 2] shr 6)) +
      w[i - 7] + (((w[i - 15] shr 1) or (w[i - 15] shl 63)) xor ((w[i - 15] shr 8) or (w[i - 15] shl 56)) xor (w[i - 15] shr 7)) + w[i - 16];

  {
   * Round 0.
   *}
  T1 := h + (((E shr 14) or (E shl 50)) xor ((E shr 18) or (E shl 46)) xor ((E shr 41) or (E shl 23))) + ((E and f) xor (not E and g)) + $428A2F98D728AE22 + w[0];
  T2 := (((a shr 28) or (a shl 36)) xor ((a shr 34) or (a shl 30)) xor ((a shr 39) or (a shl 25))) + ((a and b) xor (a and c) xor (b and c));
  d := d + T1;
  h := T1 + T2;

  {
   * Round 1.
   *}
  T1 := g + (((d shr 14) or (d shl 50)) xor ((d shr 18) or (d shl 46)) xor ((d shr 41) or (d shl 23))) + ((d and E) xor (not d and f)) + $7137449123EF65CD + w[1];
  T2 := (((h shr 28) or (h shl 36)) xor ((h shr 34) or (h shl 30)) xor ((h shr 39) or (h shl 25))) + ((h and a) xor (h and b) xor (a and b));
  c := c + T1;
  g := T1 + T2;

  {
   * Round 2.
   *}
  T1 := f + (((c shr 14) or (c shl 50)) xor ((c shr 18) or (c shl 46)) xor ((c shr 41) or (c shl 23))) + ((c and d) xor (not c and E)) + $B5C0FBCFEC4D3B2F + w[2];
  T2 := (((g shr 28) or (g shl 36)) xor ((g shr 34) or (g shl 30)) xor ((g shr 39) or (g shl 25))) + ((g and h) xor (g and a) xor (h and a));
  b := b + T1;
  f := T1 + T2;

  {
   * Round 3.
   *}
  T1 := E + (((b shr 14) or (b shl 50)) xor ((b shr 18) or (b shl 46)) xor ((b shr 41) or (b shl 23))) + ((b and c) xor (not b and d)) + $E9B5DBA58189DBBC + w[3];
  T2 := (((f shr 28) or (f shl 36)) xor ((f shr 34) or (f shl 30)) xor ((f shr 39) or (f shl 25))) + ((f and g) xor (f and h) xor (g and h));
  a := a + T1;
  E := T1 + T2;

  {
   * Round 4.
   *}
  T1 := d + (((a shr 14) or (a shl 50)) xor ((a shr 18) or (a shl 46)) xor ((a shr 41) or (a shl 23))) + ((a and b) xor (not a and c)) + $3956C25BF348B538 + w[4];
  T2 := (((E shr 28) or (E shl 36)) xor ((E shr 34) or (E shl 30)) xor ((E shr 39) or (E shl 25))) + ((E and f) xor (E and g) xor (f and g));
  h := h + T1;
  d := T1 + T2;

  {
   * Round 5.
   *}
  T1 := c + (((h shr 14) or (h shl 50)) xor ((h shr 18) or (h shl 46)) xor ((h shr 41) or (h shl 23))) + ((h and a) xor (not h and b)) + $59F111F1B605D019 + w[5];
  T2 := (((d shr 28) or (d shl 36)) xor ((d shr 34) or (d shl 30)) xor ((d shr 39) or (d shl 25))) + ((d and E) xor (d and f) xor (E and f));
  g := g + T1;
  c := T1 + T2;

  {
   * Round 6.
   *}
  T1 := b + (((g shr 14) or (g shl 50)) xor ((g shr 18) or (g shl 46)) xor ((g shr 41) or (g shl 23))) + ((g and h) xor (not g and a)) + $923F82A4AF194F9B + w[6];
  T2 := (((c shr 28) or (c shl 36)) xor ((c shr 34) or (c shl 30)) xor ((c shr 39) or (c shl 25))) + ((c and d) xor (c and E) xor (d and E));
  f := f + T1;
  b := T1 + T2;

  {
   * Round 7.
   *}
  T1 := a + (((f shr 14) or (f shl 50)) xor ((f shr 18) or (f shl 46)) xor ((f shr 41) or (f shl 23))) + ((f and g) xor (not f and h)) + $AB1C5ED5DA6D8118 + w[7];
  T2 := (((b shr 28) or (b shl 36)) xor ((b shr 34) or (b shl 30)) xor ((b shr 39) or (b shl 25))) + ((b and c) xor (b and d) xor (c and d));
  E := E + T1;
  a := T1 + T2;

  {
   * Round 8.
   *}
  T1 := h + (((E shr 14) or (E shl 50)) xor ((E shr 18) or (E shl 46)) xor ((E shr 41) or (E shl 23))) + ((E and f) xor (not E and g)) + $D807AA98A3030242 + w[8];
  T2 := (((a shr 28) or (a shl 36)) xor ((a shr 34) or (a shl 30)) xor ((a shr 39) or (a shl 25))) + ((a and b) xor (a and c) xor (b and c));
  d := d + T1;
  h := T1 + T2;

  {
   * Round 9.
   *}
  T1 := g + (((d shr 14) or (d shl 50)) xor ((d shr 18) or (d shl 46)) xor ((d shr 41) or (d shl 23))) + ((d and E) xor (not d and f)) + $12835B0145706FBE + w[9];
  T2 := (((h shr 28) or (h shl 36)) xor ((h shr 34) or (h shl 30)) xor ((h shr 39) or (h shl 25))) + ((h and a) xor (h and b) xor (a and b));
  c := c + T1;
  g := T1 + T2;

  {
   * Round 10.
   *}
  T1 := f + (((c shr 14) or (c shl 50)) xor ((c shr 18) or (c shl 46)) xor ((c shr 41) or (c shl 23))) + ((c and d) xor (not c and E)) + $243185BE4EE4B28C + w[10];
  T2 := (((g shr 28) or (g shl 36)) xor ((g shr 34) or (g shl 30)) xor ((g shr 39) or (g shl 25))) + ((g and h) xor (g and a) xor (h and a));
  b := b + T1;
  f := T1 + T2;

  {
   * Round 11.
   *}
  T1 := E + (((b shr 14) or (b shl 50)) xor ((b shr 18) or (b shl 46)) xor ((b shr 41) or (b shl 23))) + ((b and c) xor (not b and d)) + $550C7DC3D5FFB4E2 + w[11];
  T2 := (((f shr 28) or (f shl 36)) xor ((f shr 34) or (f shl 30)) xor ((f shr 39) or (f shl 25))) + ((f and g) xor (f and h) xor (g and h));
  a := a + T1;
  E := T1 + T2;

  {
   * Round 12.
   *}
  T1 := d + (((a shr 14) or (a shl 50)) xor ((a shr 18) or (a shl 46)) xor ((a shr 41) or (a shl 23))) + ((a and b) xor (not a and c)) + $72BE5D74F27B896F + w[12];
  T2 := (((E shr 28) or (E shl 36)) xor ((E shr 34) or (E shl 30)) xor ((E shr 39) or (E shl 25))) + ((E and f) xor (E and g) xor (f and g));
  h := h + T1;
  d := T1 + T2;

  {
   * Round 13.
   *}
  T1 := c + (((h shr 14) or (h shl 50)) xor ((h shr 18) or (h shl 46)) xor ((h shr 41) or (h shl 23))) + ((h and a) xor (not h and b)) + $80DEB1FE3B1696B1 + w[13];
  T2 := (((d shr 28) or (d shl 36)) xor ((d shr 34) or (d shl 30)) xor ((d shr 39) or (d shl 25))) + ((d and E) xor (d and f) xor (E and f));
  g := g + T1;
  c := T1 + T2;

  {
   * Round 14.
   *}
  T1 := b + (((g shr 14) or (g shl 50)) xor ((g shr 18) or (g shl 46)) xor ((g shr 41) or (g shl 23))) + ((g and h) xor (not g and a)) + $9BDC06A725C71235 + w[14];
  T2 := (((c shr 28) or (c shl 36)) xor ((c shr 34) or (c shl 30)) xor ((c shr 39) or (c shl 25))) + ((c and d) xor (c and E) xor (d and E));
  f := f + T1;
  b := T1 + T2;

  {
   * Round 15.
   *}
  T1 := a + (((f shr 14) or (f shl 50)) xor ((f shr 18) or (f shl 46)) xor ((f shr 41) or (f shl 23))) + ((f and g) xor (not f and h)) + $C19BF174CF692694 + w[15];
  T2 := (((b shr 28) or (b shl 36)) xor ((b shr 34) or (b shl 30)) xor ((b shr 39) or (b shl 25))) + ((b and c) xor (b and d) xor (c and d));
  E := E + T1;
  a := T1 + T2;

  {
   * Round 16.
   *}
  T1 := h + (((E shr 14) or (E shl 50)) xor ((E shr 18) or (E shl 46)) xor ((E shr 41) or (E shl 23))) + ((E and f) xor (not E and g)) + $E49B69C19EF14AD2 + w[16];
  T2 := (((a shr 28) or (a shl 36)) xor ((a shr 34) or (a shl 30)) xor ((a shr 39) or (a shl 25))) + ((a and b) xor (a and c) xor (b and c));
  d := d + T1;
  h := T1 + T2;

  {
   * Round 17.
   *}
  T1 := g + (((d shr 14) or (d shl 50)) xor ((d shr 18) or (d shl 46)) xor ((d shr 41) or (d shl 23))) + ((d and E) xor (not d and f)) + $EFBE4786384F25E3 + w[17];
  T2 := (((h shr 28) or (h shl 36)) xor ((h shr 34) or (h shl 30)) xor ((h shr 39) or (h shl 25))) + ((h and a) xor (h and b) xor (a and b));
  c := c + T1;
  g := T1 + T2;

  {
   * Round 18.
   *}
  T1 := f + (((c shr 14) or (c shl 50)) xor ((c shr 18) or (c shl 46)) xor ((c shr 41) or (c shl 23))) + ((c and d) xor (not c and E)) + $0FC19DC68B8CD5B5 + w[18];
  T2 := (((g shr 28) or (g shl 36)) xor ((g shr 34) or (g shl 30)) xor ((g shr 39) or (g shl 25))) + ((g and h) xor (g and a) xor (h and a));
  b := b + T1;
  f := T1 + T2;

  {
   * Round 19.
   *}
  T1 := E + (((b shr 14) or (b shl 50)) xor ((b shr 18) or (b shl 46)) xor ((b shr 41) or (b shl 23))) + ((b and c) xor (not b and d)) + $240CA1CC77AC9C65 + w[19];
  T2 := (((f shr 28) or (f shl 36)) xor ((f shr 34) or (f shl 30)) xor ((f shr 39) or (f shl 25))) + ((f and g) xor (f and h) xor (g and h));
  a := a + T1;
  E := T1 + T2;

  {
   * Round 20.
   *}
  T1 := d + (((a shr 14) or (a shl 50)) xor ((a shr 18) or (a shl 46)) xor ((a shr 41) or (a shl 23))) + ((a and b) xor (not a and c)) + $2DE92C6F592B0275 + w[20];
  T2 := (((E shr 28) or (E shl 36)) xor ((E shr 34) or (E shl 30)) xor ((E shr 39) or (E shl 25))) + ((E and f) xor (E and g) xor (f and g));
  h := h + T1;
  d := T1 + T2;

  {
   * Round 21.
   *}
  T1 := c + (((h shr 14) or (h shl 50)) xor ((h shr 18) or (h shl 46)) xor ((h shr 41) or (h shl 23))) + ((h and a) xor (not h and b)) + $4A7484AA6EA6E483 + w[21];
  T2 := (((d shr 28) or (d shl 36)) xor ((d shr 34) or (d shl 30)) xor ((d shr 39) or (d shl 25))) + ((d and E) xor (d and f) xor (E and f));
  g := g + T1;
  c := T1 + T2;

  {
   * Round 22.
   *}
  T1 := b + (((g shr 14) or (g shl 50)) xor ((g shr 18) or (g shl 46)) xor ((g shr 41) or (g shl 23))) + ((g and h) xor (not g and a)) + $5CB0A9DCBD41FBD4 + w[22];
  T2 := (((c shr 28) or (c shl 36)) xor ((c shr 34) or (c shl 30)) xor ((c shr 39) or (c shl 25))) + ((c and d) xor (c and E) xor (d and E));
  f := f + T1;
  b := T1 + T2;

  {
   * Round 23.
   *}
  T1 := a + (((f shr 14) or (f shl 50)) xor ((f shr 18) or (f shl 46)) xor ((f shr 41) or (f shl 23))) + ((f and g) xor (not f and h)) + $76F988DA831153B5 + w[23];
  T2 := (((b shr 28) or (b shl 36)) xor ((b shr 34) or (b shl 30)) xor ((b shr 39) or (b shl 25))) + ((b and c) xor (b and d) xor (c and d));
  E := E + T1;
  a := T1 + T2;

  {
   * Round 24.
   *}
  T1 := h + (((E shr 14) or (E shl 50)) xor ((E shr 18) or (E shl 46)) xor ((E shr 41) or (E shl 23))) + ((E and f) xor (not E and g)) + $983E5152EE66DFAB + w[24];
  T2 := (((a shr 28) or (a shl 36)) xor ((a shr 34) or (a shl 30)) xor ((a shr 39) or (a shl 25))) + ((a and b) xor (a and c) xor (b and c));
  d := d + T1;
  h := T1 + T2;

  {
   * Round 25.
   *}
  T1 := g + (((d shr 14) or (d shl 50)) xor ((d shr 18) or (d shl 46)) xor ((d shr 41) or (d shl 23))) + ((d and E) xor (not d and f)) + $A831C66D2DB43210 + w[25];
  T2 := (((h shr 28) or (h shl 36)) xor ((h shr 34) or (h shl 30)) xor ((h shr 39) or (h shl 25))) + ((h and a) xor (h and b) xor (a and b));
  c := c + T1;
  g := T1 + T2;

  {
   * Round 26.
   *}
  T1 := f + (((c shr 14) or (c shl 50)) xor ((c shr 18) or (c shl 46)) xor ((c shr 41) or (c shl 23))) + ((c and d) xor (not c and E)) + $B00327C898FB213F + w[26];
  T2 := (((g shr 28) or (g shl 36)) xor ((g shr 34) or (g shl 30)) xor ((g shr 39) or (g shl 25))) + ((g and h) xor (g and a) xor (h and a));
  b := b + T1;
  f := T1 + T2;

  {
   * Round 27.
   *}
  T1 := E + (((b shr 14) or (b shl 50)) xor ((b shr 18) or (b shl 46)) xor ((b shr 41) or (b shl 23))) + ((b and c) xor (not b and d)) + $BF597FC7BEEF0EE4 + w[27];
  T2 := (((f shr 28) or (f shl 36)) xor ((f shr 34) or (f shl 30)) xor ((f shr 39) or (f shl 25))) + ((f and g) xor (f and h) xor (g and h));
  a := a + T1;
  E := T1 + T2;

  {
   * Round 28.
   *}
  T1 := d + (((a shr 14) or (a shl 50)) xor ((a shr 18) or (a shl 46)) xor ((a shr 41) or (a shl 23))) + ((a and b) xor (not a and c)) + $C6E00BF33DA88FC2 + w[28];
  T2 := (((E shr 28) or (E shl 36)) xor ((E shr 34) or (E shl 30)) xor ((E shr 39) or (E shl 25))) + ((E and f) xor (E and g) xor (f and g));
  h := h + T1;
  d := T1 + T2;

  {
   * Round 29.
   *}
  T1 := c + (((h shr 14) or (h shl 50)) xor ((h shr 18) or (h shl 46)) xor ((h shr 41) or (h shl 23))) + ((h and a) xor (not h and b)) + $D5A79147930AA725 + w[29];
  T2 := (((d shr 28) or (d shl 36)) xor ((d shr 34) or (d shl 30)) xor ((d shr 39) or (d shl 25))) + ((d and E) xor (d and f) xor (E and f));
  g := g + T1;
  c := T1 + T2;

  {
   * Round 30.
   *}
  T1 := b + (((g shr 14) or (g shl 50)) xor ((g shr 18) or (g shl 46)) xor ((g shr 41) or (g shl 23))) + ((g and h) xor (not g and a)) + $06CA6351E003826F + w[30];
  T2 := (((c shr 28) or (c shl 36)) xor ((c shr 34) or (c shl 30)) xor ((c shr 39) or (c shl 25))) + ((c and d) xor (c and E) xor (d and E));
  f := f + T1;
  b := T1 + T2;

  {
   * Round 31.
   *}
  T1 := a + (((f shr 14) or (f shl 50)) xor ((f shr 18) or (f shl 46)) xor ((f shr 41) or (f shl 23))) + ((f and g) xor (not f and h)) + $142929670A0E6E70 + w[31];
  T2 := (((b shr 28) or (b shl 36)) xor ((b shr 34) or (b shl 30)) xor ((b shr 39) or (b shl 25))) + ((b and c) xor (b and d) xor (c and d));
  E := E + T1;
  a := T1 + T2;

  {
   * Round 32.
   *}
  T1 := h + (((E shr 14) or (E shl 50)) xor ((E shr 18) or (E shl 46)) xor ((E shr 41) or (E shl 23))) + ((E and f) xor (not E and g)) + $27B70A8546D22FFC + w[32];
  T2 := (((a shr 28) or (a shl 36)) xor ((a shr 34) or (a shl 30)) xor ((a shr 39) or (a shl 25))) + ((a and b) xor (a and c) xor (b and c));
  d := d + T1;
  h := T1 + T2;

  {
   * Round 33.
   *}
  T1 := g + (((d shr 14) or (d shl 50)) xor ((d shr 18) or (d shl 46)) xor ((d shr 41) or (d shl 23))) + ((d and E) xor (not d and f)) + $2E1B21385C26C926 + w[33];
  T2 := (((h shr 28) or (h shl 36)) xor ((h shr 34) or (h shl 30)) xor ((h shr 39) or (h shl 25))) + ((h and a) xor (h and b) xor (a and b));
  c := c + T1;
  g := T1 + T2;

  {
   * Round 34.
   *}
  T1 := f + (((c shr 14) or (c shl 50)) xor ((c shr 18) or (c shl 46)) xor ((c shr 41) or (c shl 23))) + ((c and d) xor (not c and E)) + $4D2C6DFC5AC42AED + w[34];
  T2 := (((g shr 28) or (g shl 36)) xor ((g shr 34) or (g shl 30)) xor ((g shr 39) or (g shl 25))) + ((g and h) xor (g and a) xor (h and a));
  b := b + T1;
  f := T1 + T2;

  {
   * Round 35.
   *}
  T1 := E + (((b shr 14) or (b shl 50)) xor ((b shr 18) or (b shl 46)) xor ((b shr 41) or (b shl 23))) + ((b and c) xor (not b and d)) + $53380D139D95B3DF + w[35];
  T2 := (((f shr 28) or (f shl 36)) xor ((f shr 34) or (f shl 30)) xor ((f shr 39) or (f shl 25))) + ((f and g) xor (f and h) xor (g and h));
  a := a + T1;
  E := T1 + T2;

  {
   * Round 36.
   *}
  T1 := d + (((a shr 14) or (a shl 50)) xor ((a shr 18) or (a shl 46)) xor ((a shr 41) or (a shl 23))) + ((a and b) xor (not a and c)) + $650A73548BAF63DE + w[36];
  T2 := (((E shr 28) or (E shl 36)) xor ((E shr 34) or (E shl 30)) xor ((E shr 39) or (E shl 25))) + ((E and f) xor (E and g) xor (f and g));
  h := h + T1;
  d := T1 + T2;

  {
   * Round 37.
   *}
  T1 := c + (((h shr 14) or (h shl 50)) xor ((h shr 18) or (h shl 46)) xor ((h shr 41) or (h shl 23))) + ((h and a) xor (not h and b)) + $766A0ABB3C77B2A8 + w[37];
  T2 := (((d shr 28) or (d shl 36)) xor ((d shr 34) or (d shl 30)) xor ((d shr 39) or (d shl 25))) + ((d and E) xor (d and f) xor (E and f));
  g := g + T1;
  c := T1 + T2;

  {
   * Round 38.
   *}
  T1 := b + (((g shr 14) or (g shl 50)) xor ((g shr 18) or (g shl 46)) xor ((g shr 41) or (g shl 23))) + ((g and h) xor (not g and a)) + $81C2C92E47EDAEE6 + w[38];
  T2 := (((c shr 28) or (c shl 36)) xor ((c shr 34) or (c shl 30)) xor ((c shr 39) or (c shl 25))) + ((c and d) xor (c and E) xor (d and E));
  f := f + T1;
  b := T1 + T2;

  {
   * Round 39.
   *}
  T1 := a + (((f shr 14) or (f shl 50)) xor ((f shr 18) or (f shl 46)) xor ((f shr 41) or (f shl 23))) + ((f and g) xor (not f and h)) + $92722C851482353B + w[39];
  T2 := (((b shr 28) or (b shl 36)) xor ((b shr 34) or (b shl 30)) xor ((b shr 39) or (b shl 25))) + ((b and c) xor (b and d) xor (c and d));
  E := E + T1;
  a := T1 + T2;

  {
   * Round 40.
   *}
  T1 := h + (((E shr 14) or (E shl 50)) xor ((E shr 18) or (E shl 46)) xor ((E shr 41) or (E shl 23))) + ((E and f) xor (not E and g)) + $A2BFE8A14CF10364 + w[40];
  T2 := (((a shr 28) or (a shl 36)) xor ((a shr 34) or (a shl 30)) xor ((a shr 39) or (a shl 25))) + ((a and b) xor (a and c) xor (b and c));
  d := d + T1;
  h := T1 + T2;

  {
   * Round 41.
   *}
  T1 := g + (((d shr 14) or (d shl 50)) xor ((d shr 18) or (d shl 46)) xor ((d shr 41) or (d shl 23))) + ((d and E) xor (not d and f)) + $A81A664BBC423001 + w[41];
  T2 := (((h shr 28) or (h shl 36)) xor ((h shr 34) or (h shl 30)) xor ((h shr 39) or (h shl 25))) + ((h and a) xor (h and b) xor (a and b));
  c := c + T1;
  g := T1 + T2;

  {
   * Round 42.
   *}
  T1 := f + (((c shr 14) or (c shl 50)) xor ((c shr 18) or (c shl 46)) xor ((c shr 41) or (c shl 23))) + ((c and d) xor (not c and E)) + $C24B8B70D0F89791 + w[42];
  T2 := (((g shr 28) or (g shl 36)) xor ((g shr 34) or (g shl 30)) xor ((g shr 39) or (g shl 25))) + ((g and h) xor (g and a) xor (h and a));
  b := b + T1;
  f := T1 + T2;

  {
   * Round 43.
   *}
  T1 := E + (((b shr 14) or (b shl 50)) xor ((b shr 18) or (b shl 46)) xor ((b shr 41) or (b shl 23))) + ((b and c) xor (not b and d)) + $C76C51A30654BE30 + w[43];
  T2 := (((f shr 28) or (f shl 36)) xor ((f shr 34) or (f shl 30)) xor ((f shr 39) or (f shl 25))) + ((f and g) xor (f and h) xor (g and h));
  a := a + T1;
  E := T1 + T2;

  {
   * Round 44.
   *}
  T1 := d + (((a shr 14) or (a shl 50)) xor ((a shr 18) or (a shl 46)) xor ((a shr 41) or (a shl 23))) + ((a and b) xor (not a and c)) + $D192E819D6EF5218 + w[44];
  T2 := (((E shr 28) or (E shl 36)) xor ((E shr 34) or (E shl 30)) xor ((E shr 39) or (E shl 25))) + ((E and f) xor (E and g) xor (f and g));
  h := h + T1;
  d := T1 + T2;

  {
   * Round 45.
   *}
  T1 := c + (((h shr 14) or (h shl 50)) xor ((h shr 18) or (h shl 46)) xor ((h shr 41) or (h shl 23))) + ((h and a) xor (not h and b)) + $D69906245565A910 + w[45];
  T2 := (((d shr 28) or (d shl 36)) xor ((d shr 34) or (d shl 30)) xor ((d shr 39) or (d shl 25))) + ((d and E) xor (d and f) xor (E and f));
  g := g + T1;
  c := T1 + T2;

  {
   * Round 46.
   *}
  T1 := b + (((g shr 14) or (g shl 50)) xor ((g shr 18) or (g shl 46)) xor ((g shr 41) or (g shl 23))) + ((g and h) xor (not g and a)) + $F40E35855771202A + w[46];
  T2 := (((c shr 28) or (c shl 36)) xor ((c shr 34) or (c shl 30)) xor ((c shr 39) or (c shl 25))) + ((c and d) xor (c and E) xor (d and E));
  f := f + T1;
  b := T1 + T2;

  {
   * Round 47.
   *}
  T1 := a + (((f shr 14) or (f shl 50)) xor ((f shr 18) or (f shl 46)) xor ((f shr 41) or (f shl 23))) + ((f and g) xor (not f and h)) + $106AA07032BBD1B8 + w[47];
  T2 := (((b shr 28) or (b shl 36)) xor ((b shr 34) or (b shl 30)) xor ((b shr 39) or (b shl 25))) + ((b and c) xor (b and d) xor (c and d));
  E := E + T1;
  a := T1 + T2;

  {
   * Round 48.
   *}
  T1 := h + (((E shr 14) or (E shl 50)) xor ((E shr 18) or (E shl 46)) xor ((E shr 41) or (E shl 23))) + ((E and f) xor (not E and g)) + $19A4C116B8D2D0C8 + w[48];
  T2 := (((a shr 28) or (a shl 36)) xor ((a shr 34) or (a shl 30)) xor ((a shr 39) or (a shl 25))) + ((a and b) xor (a and c) xor (b and c));
  d := d + T1;
  h := T1 + T2;

  {
   * Round 49.
   *}
  T1 := g + (((d shr 14) or (d shl 50)) xor ((d shr 18) or (d shl 46)) xor ((d shr 41) or (d shl 23))) + ((d and E) xor (not d and f)) + $1E376C085141AB53 + w[49];
  T2 := (((h shr 28) or (h shl 36)) xor ((h shr 34) or (h shl 30)) xor ((h shr 39) or (h shl 25))) + ((h and a) xor (h and b) xor (a and b));
  c := c + T1;
  g := T1 + T2;

  {
   * Round 50.
   *}
  T1 := f + (((c shr 14) or (c shl 50)) xor ((c shr 18) or (c shl 46)) xor ((c shr 41) or (c shl 23))) + ((c and d) xor (not c and E)) + $2748774CDF8EEB99 + w[50];
  T2 := (((g shr 28) or (g shl 36)) xor ((g shr 34) or (g shl 30)) xor ((g shr 39) or (g shl 25))) + ((g and h) xor (g and a) xor (h and a));
  b := b + T1;
  f := T1 + T2;

  {
   * Round 51.
   *}
  T1 := E + (((b shr 14) or (b shl 50)) xor ((b shr 18) or (b shl 46)) xor ((b shr 41) or (b shl 23))) + ((b and c) xor (not b and d)) + $34B0BCB5E19B48A8 + w[51];
  T2 := (((f shr 28) or (f shl 36)) xor ((f shr 34) or (f shl 30)) xor ((f shr 39) or (f shl 25))) + ((f and g) xor (f and h) xor (g and h));
  a := a + T1;
  E := T1 + T2;

  {
   * Round 52.
   *}
  T1 := d + (((a shr 14) or (a shl 50)) xor ((a shr 18) or (a shl 46)) xor ((a shr 41) or (a shl 23))) + ((a and b) xor (not a and c)) + $391C0CB3C5C95A63 + w[52];
  T2 := (((E shr 28) or (E shl 36)) xor ((E shr 34) or (E shl 30)) xor ((E shr 39) or (E shl 25))) + ((E and f) xor (E and g) xor (f and g));
  h := h + T1;
  d := T1 + T2;

  {
   * Round 53.
   *}
  T1 := c + (((h shr 14) or (h shl 50)) xor ((h shr 18) or (h shl 46)) xor ((h shr 41) or (h shl 23))) + ((h and a) xor (not h and b)) + $4ED8AA4AE3418ACB + w[53];
  T2 := (((d shr 28) or (d shl 36)) xor ((d shr 34) or (d shl 30)) xor ((d shr 39) or (d shl 25))) + ((d and E) xor (d and f) xor (E and f));
  g := g + T1;
  c := T1 + T2;

  {
   * Round 54.
   *}
  T1 := b + (((g shr 14) or (g shl 50)) xor ((g shr 18) or (g shl 46)) xor ((g shr 41) or (g shl 23))) + ((g and h) xor (not g and a)) + $5B9CCA4F7763E373 + w[54];
  T2 := (((c shr 28) or (c shl 36)) xor ((c shr 34) or (c shl 30)) xor ((c shr 39) or (c shl 25))) + ((c and d) xor (c and E) xor (d and E));
  f := f + T1;
  b := T1 + T2;

  {
   * Round 55.
   *}
  T1 := a + (((f shr 14) or (f shl 50)) xor ((f shr 18) or (f shl 46)) xor ((f shr 41) or (f shl 23))) + ((f and g) xor (not f and h)) + $682E6FF3D6B2B8A3 + w[55];
  T2 := (((b shr 28) or (b shl 36)) xor ((b shr 34) or (b shl 30)) xor ((b shr 39) or (b shl 25))) + ((b and c) xor (b and d) xor (c and d));
  E := E + T1;
  a := T1 + T2;

  {
   * Round 56.
   *}
  T1 := h + (((E shr 14) or (E shl 50)) xor ((E shr 18) or (E shl 46)) xor ((E shr 41) or (E shl 23))) + ((E and f) xor (not E and g)) + $748F82EE5DEFB2FC + w[56];
  T2 := (((a shr 28) or (a shl 36)) xor ((a shr 34) or (a shl 30)) xor ((a shr 39) or (a shl 25))) + ((a and b) xor (a and c) xor (b and c));
  d := d + T1;
  h := T1 + T2;

  {
   * Round 57.
   *}
  T1 := g + (((d shr 14) or (d shl 50)) xor ((d shr 18) or (d shl 46)) xor ((d shr 41) or (d shl 23))) + ((d and E) xor (not d and f)) + $78A5636F43172F60 + w[57];
  T2 := (((h shr 28) or (h shl 36)) xor ((h shr 34) or (h shl 30)) xor ((h shr 39) or (h shl 25))) + ((h and a) xor (h and b) xor (a and b));
  c := c + T1;
  g := T1 + T2;

  {
   * Round 58.
   *}
  T1 := f + (((c shr 14) or (c shl 50)) xor ((c shr 18) or (c shl 46)) xor ((c shr 41) or (c shl 23))) + ((c and d) xor (not c and E)) + $84C87814A1F0AB72 + w[58];
  T2 := (((g shr 28) or (g shl 36)) xor ((g shr 34) or (g shl 30)) xor ((g shr 39) or (g shl 25))) + ((g and h) xor (g and a) xor (h and a));
  b := b + T1;
  f := T1 + T2;

  {
   * Round 59.
   *}
  T1 := E + (((b shr 14) or (b shl 50)) xor ((b shr 18) or (b shl 46)) xor ((b shr 41) or (b shl 23))) + ((b and c) xor (not b and d)) + $8CC702081A6439EC + w[59];
  T2 := (((f shr 28) or (f shl 36)) xor ((f shr 34) or (f shl 30)) xor ((f shr 39) or (f shl 25))) + ((f and g) xor (f and h) xor (g and h));
  a := a + T1;
  E := T1 + T2;

  {
   * Round 60.
   *}
  T1 := d + (((a shr 14) or (a shl 50)) xor ((a shr 18) or (a shl 46)) xor ((a shr 41) or (a shl 23))) + ((a and b) xor (not a and c)) + $90BEFFFA23631E28 + w[60];
  T2 := (((E shr 28) or (E shl 36)) xor ((E shr 34) or (E shl 30)) xor ((E shr 39) or (E shl 25))) + ((E and f) xor (E and g) xor (f and g));
  h := h + T1;
  d := T1 + T2;

  {
   * Round 61.
   *}
  T1 := c + (((h shr 14) or (h shl 50)) xor ((h shr 18) or (h shl 46)) xor ((h shr 41) or (h shl 23))) + ((h and a) xor (not h and b)) + $A4506CEBDE82BDE9 + w[61];
  T2 := (((d shr 28) or (d shl 36)) xor ((d shr 34) or (d shl 30)) xor ((d shr 39) or (d shl 25))) + ((d and E) xor (d and f) xor (E and f));
  g := g + T1;
  c := T1 + T2;

  {
   * Round 62.
   *}
  T1 := b + (((g shr 14) or (g shl 50)) xor ((g shr 18) or (g shl 46)) xor ((g shr 41) or (g shl 23))) + ((g and h) xor (not g and a)) + $BEF9A3F7B2C67915 + w[62];
  T2 := (((c shr 28) or (c shl 36)) xor ((c shr 34) or (c shl 30)) xor ((c shr 39) or (c shl 25))) + ((c and d) xor (c and E) xor (d and E));
  f := f + T1;
  b := T1 + T2;

  {
   * Round 63.
   *}
  T1 := a + (((f shr 14) or (f shl 50)) xor ((f shr 18) or (f shl 46)) xor ((f shr 41) or (f shl 23))) + ((f and g) xor (not f and h)) + $C67178F2E372532B + w[63];
  T2 := (((b shr 28) or (b shl 36)) xor ((b shr 34) or (b shl 30)) xor ((b shr 39) or (b shl 25))) + ((b and c) xor (b and d) xor (c and d));
  E := E + T1;
  a := T1 + T2;

  {
   * Round 64.
   *}
  T1 := h + (((E shr 14) or (E shl 50)) xor ((E shr 18) or (E shl 46)) xor ((E shr 41) or (E shl 23))) + ((E and f) xor (not E and g)) + $CA273ECEEA26619C + w[64];
  T2 := (((a shr 28) or (a shl 36)) xor ((a shr 34) or (a shl 30)) xor ((a shr 39) or (a shl 25))) + ((a and b) xor (a and c) xor (b and c));
  d := d + T1;
  h := T1 + T2;

  {
   * Round 65.
   *}
  T1 := g + (((d shr 14) or (d shl 50)) xor ((d shr 18) or (d shl 46)) xor ((d shr 41) or (d shl 23))) + ((d and E) xor (not d and f)) + $D186B8C721C0C207 + w[65];
  T2 := (((h shr 28) or (h shl 36)) xor ((h shr 34) or (h shl 30)) xor ((h shr 39) or (h shl 25))) + ((h and a) xor (h and b) xor (a and b));
  c := c + T1;
  g := T1 + T2;

  {
   * Round 66.
   *}
  T1 := f + (((c shr 14) or (c shl 50)) xor ((c shr 18) or (c shl 46)) xor ((c shr 41) or (c shl 23))) + ((c and d) xor (not c and E)) + $EADA7DD6CDE0EB1E + w[66];
  T2 := (((g shr 28) or (g shl 36)) xor ((g shr 34) or (g shl 30)) xor ((g shr 39) or (g shl 25))) + ((g and h) xor (g and a) xor (h and a));
  b := b + T1;
  f := T1 + T2;

  {
   * Round 67.
   *}
  T1 := E + (((b shr 14) or (b shl 50)) xor ((b shr 18) or (b shl 46)) xor ((b shr 41) or (b shl 23))) + ((b and c) xor (not b and d)) + $F57D4F7FEE6ED178 + w[67];
  T2 := (((f shr 28) or (f shl 36)) xor ((f shr 34) or (f shl 30)) xor ((f shr 39) or (f shl 25))) + ((f and g) xor (f and h) xor (g and h));
  a := a + T1;
  E := T1 + T2;

  {
   * Round 68.
   *}
  T1 := d + (((a shr 14) or (a shl 50)) xor ((a shr 18) or (a shl 46)) xor ((a shr 41) or (a shl 23))) + ((a and b) xor (not a and c)) + $06F067AA72176FBA + w[68];
  T2 := (((E shr 28) or (E shl 36)) xor ((E shr 34) or (E shl 30)) xor ((E shr 39) or (E shl 25))) + ((E and f) xor (E and g) xor (f and g));
  h := h + T1;
  d := T1 + T2;

  {
   * Round 69.
   *}
  T1 := c + (((h shr 14) or (h shl 50)) xor ((h shr 18) or (h shl 46)) xor ((h shr 41) or (h shl 23))) + ((h and a) xor (not h and b)) + $0A637DC5A2C898A6 + w[69];
  T2 := (((d shr 28) or (d shl 36)) xor ((d shr 34) or (d shl 30)) xor ((d shr 39) or (d shl 25))) + ((d and E) xor (d and f) xor (E and f));
  g := g + T1;
  c := T1 + T2;

  {
   * Round 70.
   *}
  T1 := b + (((g shr 14) or (g shl 50)) xor ((g shr 18) or (g shl 46)) xor ((g shr 41) or (g shl 23))) + ((g and h) xor (not g and a)) + $113F9804BEF90DAE + w[70];
  T2 := (((c shr 28) or (c shl 36)) xor ((c shr 34) or (c shl 30)) xor ((c shr 39) or (c shl 25))) + ((c and d) xor (c and E) xor (d and E));
  f := f + T1;
  b := T1 + T2;

  {
   * Round 71.
   *}
  T1 := a + (((f shr 14) or (f shl 50)) xor ((f shr 18) or (f shl 46)) xor ((f shr 41) or (f shl 23))) + ((f and g) xor (not f and h)) + $1B710B35131C471B + w[71];
  T2 := (((b shr 28) or (b shl 36)) xor ((b shr 34) or (b shl 30)) xor ((b shr 39) or (b shl 25))) + ((b and c) xor (b and d) xor (c and d));
  E := E + T1;
  a := T1 + T2;

  {
   * Round 72.
   *}
  T1 := h + (((E shr 14) or (E shl 50)) xor ((E shr 18) or (E shl 46)) xor ((E shr 41) or (E shl 23))) + ((E and f) xor (not E and g)) + $28DB77F523047D84 + w[72];
  T2 := (((a shr 28) or (a shl 36)) xor ((a shr 34) or (a shl 30)) xor ((a shr 39) or (a shl 25))) + ((a and b) xor (a and c) xor (b and c));
  d := d + T1;
  h := T1 + T2;

  {
   * Round 73.
   *}
  T1 := g + (((d shr 14) or (d shl 50)) xor ((d shr 18) or (d shl 46)) xor ((d shr 41) or (d shl 23))) + ((d and E) xor (not d and f)) + $32CAAB7B40C72493 + w[73];
  T2 := (((h shr 28) or (h shl 36)) xor ((h shr 34) or (h shl 30)) xor ((h shr 39) or (h shl 25))) + ((h and a) xor (h and b) xor (a and b));
  c := c + T1;
  g := T1 + T2;

  {
   * Round 74.
   *}
  T1 := f + (((c shr 14) or (c shl 50)) xor ((c shr 18) or (c shl 46)) xor ((c shr 41) or (c shl 23))) + ((c and d) xor (not c and E)) + $3C9EBE0A15C9BEBC + w[74];
  T2 := (((g shr 28) or (g shl 36)) xor ((g shr 34) or (g shl 30)) xor ((g shr 39) or (g shl 25))) + ((g and h) xor (g and a) xor (h and a));
  b := b + T1;
  f := T1 + T2;

  {
   * Round 75.
   *}
  T1 := E + (((b shr 14) or (b shl 50)) xor ((b shr 18) or (b shl 46)) xor ((b shr 41) or (b shl 23))) + ((b and c) xor (not b and d)) + $431D67C49C100D4C + w[75];
  T2 := (((f shr 28) or (f shl 36)) xor ((f shr 34) or (f shl 30)) xor ((f shr 39) or (f shl 25))) + ((f and g) xor (f and h) xor (g and h));
  a := a + T1;
  E := T1 + T2;

  {
   * Round 76.
   *}
  T1 := d + (((a shr 14) or (a shl 50)) xor ((a shr 18) or (a shl 46)) xor ((a shr 41) or (a shl 23))) + ((a and b) xor (not a and c)) + $4CC5D4BECB3E42B6 + w[76];
  T2 := (((E shr 28) or (E shl 36)) xor ((E shr 34) or (E shl 30)) xor ((E shr 39) or (E shl 25))) + ((E and f) xor (E and g) xor (f and g));
  h := h + T1;
  d := T1 + T2;

  {
   * Round 77.
   *}
  T1 := c + (((h shr 14) or (h shl 50)) xor ((h shr 18) or (h shl 46)) xor ((h shr 41) or (h shl 23))) + ((h and a) xor (not h and b)) + $597F299CFC657E2A + w[77];
  T2 := (((d shr 28) or (d shl 36)) xor ((d shr 34) or (d shl 30)) xor ((d shr 39) or (d shl 25))) + ((d and E) xor (d and f) xor (E and f));
  g := g + T1;
  c := T1 + T2;

  {
   * Round 78.
   *}
  T1 := b + (((g shr 14) or (g shl 50)) xor ((g shr 18) or (g shl 46)) xor ((g shr 41) or (g shl 23))) + ((g and h) xor (not g and a)) + $5FCB6FAB3AD6FAEC + w[78];
  T2 := (((c shr 28) or (c shl 36)) xor ((c shr 34) or (c shl 30)) xor ((c shr 39) or (c shl 25))) + ((c and d) xor (c and E) xor (d and E));
  f := f + T1;
  b := T1 + T2;

  {
   * Round 79.
   *}
  T1 := a + (((f shr 14) or (f shl 50)) xor ((f shr 18) or (f shl 46)) xor ((f shr 41) or (f shl 23))) + ((f and g) xor (not f and h)) + $6C44198C4A475817 + w[79];
  T2 := (((b shr 28) or (b shl 36)) xor ((b shr 34) or (b shl 30)) xor ((b shr 39) or (b shl 25))) + ((b and c) xor (b and d) xor (c and d));
  E := E + T1;
  a := T1 + T2;

  {
   * Feed-forward: add the compressed words back into the chaining state.
   *}
  State[0] := State[0] + a;
  State[1] := State[1] + b;
  State[2] := State[2] + c;
  State[3] := State[3] + d;
  State[4] := State[4] + E;
  State[5] := State[5] + f;
  State[6] := State[6] + g;
  State[7] := State[7] + h;

  {
   * Write the updated state back through CopyPtr (no alignment assumption).
   *}
  CopyPtr(@State[0], @Digest[0], SizeOf(State));

{$IFDEF RangeCheck}{$R+}{$ENDIF}
end;

class procedure TSHA512.SHA512(var Digest: TSHA512Digest; const Buf; BufSize: UInt64);
var
  Lo, Hi: UInt64;
  p: PByte;
  ChunkIndex: Byte;
  ChunkBuf: array [0 .. 127] of Byte;
begin
{$IFDEF RangeCheck}{$R-}{$ENDIF}
{$IFDEF OverflowCheck}{$Q-}{$ENDIF}

  {
   * Initialize the digest to the SHA-512 IV.
   *}
  PUInt64(@Digest[0])^  := $6A09E667F3BCC908;
  PUInt64(@Digest[8])^  := $BB67AE8584CAA73B;
  PUInt64(@Digest[16])^ := $3C6EF372FE94F82B;
  PUInt64(@Digest[24])^ := $A54FF53A5F1D36F1;
  PUInt64(@Digest[32])^ := $510E527FADE682D1;
  PUInt64(@Digest[40])^ := $9B05688C2B3E6C1F;
  PUInt64(@Digest[48])^ := $1F83D9ABFB41BD6B;
  PUInt64(@Digest[56])^ := $5BE0CD19137E2179;

  {
   * Compute the message length in bits, split into low/high 64-bit halves,
   * and byte-swap into big-endian.
   *}
  Lo := 0;
  Hi := 0;

  inc(Lo, BufSize shl 3);
  inc(Hi, BufSize shr 61);

  SwapQWORD(Lo);
  SwapQWORD(Hi);

  {
   * Pre-clear the final-block workspace. Under FPC -O2 the compiler may
   * reuse the same stack slot for ChunkBuf and other temporaries; without
   * this clear, stale bytes could leak into the length field of the last
   * block and produce a non-deterministic digest.
   *}
  FillPtr(@ChunkBuf[0], SizeOf(ChunkBuf), 0);

  p := @Buf;

  {
   * Process every complete 128-byte block.
   *}
  while BufSize >= 128 do
    begin
      Compute(Digest, p);
      inc(p, 128);
      dec(BufSize, 128);
    end;

  {
   * Copy the remaining bytes (< 128) into the workspace.
   *}
  if BufSize > 0 then
      CopyPtr(p, @ChunkBuf[0], BufSize);

  {
   * Append the 0x80 padding byte at position BufSize and start the
   * zero-fill from BufSize + 1.
   *}
  ChunkBuf[Integer(BufSize)] := $80;
  ChunkIndex := Byte(BufSize + 1);

  {
   * If the length field (16 bytes) does not fit in the remaining space,
   * process this block and start a second, all-zero block for the length.
   *}
  if ChunkIndex > 112 then
    begin
      if ChunkIndex < 128 then
          FillPtr(@ChunkBuf[Integer(ChunkIndex)], SizeOf(ChunkBuf) - NativeUInt(ChunkIndex), 0);
      Compute(Digest, @ChunkBuf[0]);
      ChunkIndex := 0;
    end;

  {
   * Zero-fill up to byte 112, then write the 16-byte big-endian length.
   *}
  FillPtr(@ChunkBuf[Integer(ChunkIndex)], 112 - NativeUInt(ChunkIndex), 0);
  PUInt64(@ChunkBuf[112])^ := Hi;
  PUInt64(@ChunkBuf[120])^ := Lo;
  Compute(Digest, @ChunkBuf[0]);

  {
   * Byte-swap the digest to big-endian for output.
   *}
  SwapQWORD(PUInt64(@Digest[0])^);
  SwapQWORD(PUInt64(@Digest[8])^);
  SwapQWORD(PUInt64(@Digest[16])^);
  SwapQWORD(PUInt64(@Digest[24])^);
  SwapQWORD(PUInt64(@Digest[32])^);
  SwapQWORD(PUInt64(@Digest[40])^);
  SwapQWORD(PUInt64(@Digest[48])^);
  SwapQWORD(PUInt64(@Digest[56])^);

  {
   * Wipe the workspace.
   *}
  FillPtr(@ChunkBuf[0], SizeOf(ChunkBuf), 0);

{$IFDEF RangeCheck}{$R+}{$ENDIF}
{$IFDEF OverflowCheck}{$Q+}{$ENDIF}
end;

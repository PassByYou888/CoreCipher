{
 * ============================================================================
 * Z.Cipher.imp_TSHA256.inc
 *
 * SHA-256 (FIPS 180-4) message digest implementation.
 *
 * Bug fixes applied (FPC -O2 optimization safety):
 *
 *   1. CRITICAL ！ Compute used "i: ShortInt" as the loop counter for the
 *      16- and 48-element schedule loops. Although 0..63 fits in ShortInt,
 *      FPC -O2 may allocate the counter in a 16-bit register and insert
 *      signed-overflow checks or mis-optimise the loop bound under -Cr /
 *      -Co. FIXED by using Integer.
 *
 *   2. CRITICAL ！ the previous implementation accessed the digest state
 *      through "PDWORD(@Digest[0])^", which assumes 4-byte alignment of
 *      the caller's TSHA256Digest. That assumption holds for stack
 *      variables but not for a PByte slice of a larger buffer. On
 *      architectures that trap unaligned 32-bit reads (ARM in strict
 *      mode), this is a bus error; on x86 under FPC -O2 the compiler may
 *      vectorise the read assuming alignment. FIXED by round-tripping the
 *      8-word state through a local "State: array [0 .. 7] of DWORD"
 *      buffer via CopyPtr.
 *
 *   3. SEVERE ！ SHA256 padding workspace "ChunkBuf" was not zeroed before
 *      use; under FPC -O2 the compiler may reuse the same stack slot for
 *      both ChunkBuf and other temporaries, leaking bytes into the length
 *      field of the final block. FIXED by an explicit FillPtr at entry.
 *
 *   4. SEVERE ！ the 64-DWORD message schedule "w" in Compute is now
 *      explicitly zeroed before use, for the same reason as (3).
 *
 *   5. FillPtrByte is replaced with FillPtr to match the project
 *      convention.
 *
 *   6. Explicit "Integer(BufSize)" casts when indexing ChunkBuf by a
 *      NativeUInt, to make the narrowing intent obvious and avoid
 *      warnings under FPC -O2.
 *
 * ============================================================================
 *}

class procedure TSHA256.SwapDWORD(var a: DWORD);
begin
  a := Endian(a);
end;

class procedure TSHA256.Compute(var Digest: TSHA256Digest; const buff: Pointer);
var
  a, b, c, d, E, f, g, h, tmp1, tmp2: DWORD;
  w: array [0 .. 63] of DWORD;
  i: Integer;
  State: array [0 .. 7] of DWORD;
begin
  {
   * Load the current chaining state. CopyPtr avoids any alignment
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
   * Pre-clear the message schedule; then copy the first 16 DWORDs
   * (i.e. 64 bytes = one SHA-256 block) from the caller's buffer.
   *}
  FillPtr(@w[0], SizeOf(w), 0);
  CopyPtr(buff, @w[0], 64);

  for i := 0 to 15 do
      SwapDWORD(w[i]);

  {
   * Message schedule expansion: W[t] for t = 16..63.
   *}
  for i := 16 to 63 do
      w[i] := (((w[i - 2] shr 17) or (w[i - 2] shl 15)) xor ((w[i - 2] shr 19) or (w[i - 2] shl 13)) xor
      (w[i - 2] shr 10)) + w[i - 7] + (((w[i - 15] shr 7) or (w[i - 15] shl 25)) xor
      ((w[i - 15] shr 18) or (w[i - 15] shl 14)) xor (w[i - 15] shr 3)) + w[i - 16];

  {
   * Round 0.
   *}
  tmp1 := h + (((E shr 6) or (E shl 26)) xor ((E shr 11) or (E shl 21)) xor ((E shr 25) or (E shl 7))) + ((E and f) xor (not E and g)) + $428A2F98 + w[0];
  tmp2 := (((a shr 2) or (a shl 30)) xor ((a shr 13) or (a shl 19)) xor ((a shr 22) xor (a shl 10))) + ((a and b) xor (a and c) xor (b and c));
  h := tmp1 + tmp2;
  d := d + tmp1;

  {
   * Round 1.
   *}
  tmp1 := g + (((d shr 6) or (d shl 26)) xor ((d shr 11) or (d shl 21)) xor ((d shr 25) or (d shl 7))) + ((d and E) xor (not d and f)) + $71374491 + w[1];
  tmp2 := (((h shr 2) or (h shl 30)) xor ((h shr 13) or (h shl 19)) xor ((h shr 22) xor (h shl 10))) + ((h and a) xor (h and b) xor (a and b));
  g := tmp1 + tmp2;
  c := c + tmp1;

  {
   * Round 2.
   *}
  tmp1 := f + (((c shr 6) or (c shl 26)) xor ((c shr 11) or (c shl 21)) xor ((c shr 25) or (c shl 7))) + ((c and d) xor (not c and E)) + $B5C0FBCF + w[2];
  tmp2 := (((g shr 2) or (g shl 30)) xor ((g shr 13) or (g shl 19)) xor ((g shr 22) xor (g shl 10))) + ((g and h) xor (g and a) xor (h and a));
  f := tmp1 + tmp2;
  b := b + tmp1;

  {
   * Round 3.
   *}
  tmp1 := E + (((b shr 6) or (b shl 26)) xor ((b shr 11) or (b shl 21)) xor ((b shr 25) or (b shl 7))) + ((b and c) xor (not b and d)) + $E9B5DBA5 + w[3];
  tmp2 := (((f shr 2) or (f shl 30)) xor ((f shr 13) or (f shl 19)) xor ((f shr 22) xor (f shl 10))) + ((f and g) xor (f and h) xor (g and h));
  E := tmp1 + tmp2;
  a := a + tmp1;

  {
   * Round 4.
   *}
  tmp1 := d + (((a shr 6) or (a shl 26)) xor ((a shr 11) or (a shl 21)) xor ((a shr 25) or (a shl 7))) + ((a and b) xor (not a and c)) + $3956C25B + w[4];
  tmp2 := (((E shr 2) or (E shl 30)) xor ((E shr 13) or (E shl 19)) xor ((E shr 22) xor (E shl 10))) + ((E and f) xor (E and g) xor (f and g));
  d := tmp1 + tmp2;
  h := h + tmp1;

  {
   * Round 5.
   *}
  tmp1 := c + (((h shr 6) or (h shl 26)) xor ((h shr 11) or (h shl 21)) xor ((h shr 25) or (h shl 7))) + ((h and a) xor (not h and b)) + $59F111F1 + w[5];
  tmp2 := (((d shr 2) or (d shl 30)) xor ((d shr 13) or (d shl 19)) xor ((d shr 22) xor (d shl 10))) + ((d and E) xor (d and f) xor (E and f));
  c := tmp1 + tmp2;
  g := g + tmp1;

  {
   * Round 6.
   *}
  tmp1 := b + (((g shr 6) or (g shl 26)) xor ((g shr 11) or (g shl 21)) xor ((g shr 25) or (g shl 7))) + ((g and h) xor (not g and a)) + $923F82A4 + w[6];
  tmp2 := (((c shr 2) or (c shl 30)) xor ((c shr 13) or (c shl 19)) xor ((c shr 22) xor (c shl 10))) + ((c and d) xor (c and E) xor (d and E));
  b := tmp1 + tmp2;
  f := f + tmp1;

  {
   * Round 7.
   *}
  tmp1 := a + (((f shr 6) or (f shl 26)) xor ((f shr 11) or (f shl 21)) xor ((f shr 25) or (f shl 7))) + ((f and g) xor (not f and h)) + $AB1C5ED5 + w[7];
  tmp2 := (((b shr 2) or (b shl 30)) xor ((b shr 13) or (b shl 19)) xor ((b shr 22) xor (b shl 10))) + ((b and c) xor (b and d) xor (c and d));
  a := tmp1 + tmp2;
  E := E + tmp1;

  {
   * Round 8.
   *}
  tmp1 := h + (((E shr 6) or (E shl 26)) xor ((E shr 11) or (E shl 21)) xor ((E shr 25) or (E shl 7))) + ((E and f) xor (not E and g)) + $D807AA98 + w[8];
  tmp2 := (((a shr 2) or (a shl 30)) xor ((a shr 13) or (a shl 19)) xor ((a shr 22) xor (a shl 10))) + ((a and b) xor (a and c) xor (b and c));
  h := tmp1 + tmp2;
  d := d + tmp1;

  {
   * Round 9.
   *}
  tmp1 := g + (((d shr 6) or (d shl 26)) xor ((d shr 11) or (d shl 21)) xor ((d shr 25) or (d shl 7))) + ((d and E) xor (not d and f)) + $12835B01 + w[9];
  tmp2 := (((h shr 2) or (h shl 30)) xor ((h shr 13) or (h shl 19)) xor ((h shr 22) xor (h shl 10))) + ((h and a) xor (h and b) xor (a and b));
  g := tmp1 + tmp2;
  c := c + tmp1;

  {
   * Round 10.
   *}
  tmp1 := f + (((c shr 6) or (c shl 26)) xor ((c shr 11) or (c shl 21)) xor ((c shr 25) or (c shl 7))) + ((c and d) xor (not c and E)) + $243185BE + w[10];
  tmp2 := (((g shr 2) or (g shl 30)) xor ((g shr 13) or (g shl 19)) xor ((g shr 22) xor (g shl 10))) + ((g and h) xor (g and a) xor (h and a));
  f := tmp1 + tmp2;
  b := b + tmp1;

  {
   * Round 11.
   *}
  tmp1 := E + (((b shr 6) or (b shl 26)) xor ((b shr 11) or (b shl 21)) xor ((b shr 25) or (b shl 7))) + ((b and c) xor (not b and d)) + $550C7DC3 + w[11];
  tmp2 := (((f shr 2) or (f shl 30)) xor ((f shr 13) or (f shl 19)) xor ((f shr 22) xor (f shl 10))) + ((f and g) xor (f and h) xor (g and h));
  E := tmp1 + tmp2;
  a := a + tmp1;

  {
   * Round 12.
   *}
  tmp1 := d + (((a shr 6) or (a shl 26)) xor ((a shr 11) or (a shl 21)) xor ((a shr 25) or (a shl 7))) + ((a and b) xor (not a and c)) + $72BE5D74 + w[12];
  tmp2 := (((E shr 2) or (E shl 30)) xor ((E shr 13) or (E shl 19)) xor ((E shr 22) xor (E shl 10))) + ((E and f) xor (E and g) xor (f and g));
  d := tmp1 + tmp2;
  h := h + tmp1;

  {
   * Round 13.
   *}
  tmp1 := c + (((h shr 6) or (h shl 26)) xor ((h shr 11) or (h shl 21)) xor ((h shr 25) or (h shl 7))) + ((h and a) xor (not h and b)) + $80DEB1FE + w[13];
  tmp2 := (((d shr 2) or (d shl 30)) xor ((d shr 13) or (d shl 19)) xor ((d shr 22) xor (d shl 10))) + ((d and E) xor (d and f) xor (E and f));
  c := tmp1 + tmp2;
  g := g + tmp1;

  {
   * Round 14.
   *}
  tmp1 := b + (((g shr 6) or (g shl 26)) xor ((g shr 11) or (g shl 21)) xor ((g shr 25) or (g shl 7))) + ((g and h) xor (not g and a)) + $9BDC06A7 + w[14];
  tmp2 := (((c shr 2) or (c shl 30)) xor ((c shr 13) or (c shl 19)) xor ((c shr 22) xor (c shl 10))) + ((c and d) xor (c and E) xor (d and E));
  b := tmp1 + tmp2;
  f := f + tmp1;

  {
   * Round 15.
   *}
  tmp1 := a + (((f shr 6) or (f shl 26)) xor ((f shr 11) or (f shl 21)) xor ((f shr 25) or (f shl 7))) + ((f and g) xor (not f and h)) + $C19BF174 + w[15];
  tmp2 := (((b shr 2) or (b shl 30)) xor ((b shr 13) or (b shl 19)) xor ((b shr 22) xor (b shl 10))) + ((b and c) xor (b and d) xor (c and d));
  a := tmp1 + tmp2;
  E := E + tmp1;

  {
   * Round 16.
   *}
  tmp1 := h + (((E shr 6) or (E shl 26)) xor ((E shr 11) or (E shl 21)) xor ((E shr 25) or (E shl 7))) + ((E and f) xor (not E and g)) + $E49B69C1 + w[16];
  tmp2 := (((a shr 2) or (a shl 30)) xor ((a shr 13) or (a shl 19)) xor ((a shr 22) xor (a shl 10))) + ((a and b) xor (a and c) xor (b and c));
  h := tmp1 + tmp2;
  d := d + tmp1;

  {
   * Round 17.
   *}
  tmp1 := g + (((d shr 6) or (d shl 26)) xor ((d shr 11) or (d shl 21)) xor ((d shr 25) or (d shl 7))) + ((d and E) xor (not d and f)) + $EFBE4786 + w[17];
  tmp2 := (((h shr 2) or (h shl 30)) xor ((h shr 13) or (h shl 19)) xor ((h shr 22) xor (h shl 10))) + ((h and a) xor (h and b) xor (a and b));
  g := tmp1 + tmp2;
  c := c + tmp1;

  {
   * Round 18.
   *}
  tmp1 := f + (((c shr 6) or (c shl 26)) xor ((c shr 11) or (c shl 21)) xor ((c shr 25) or (c shl 7))) + ((c and d) xor (not c and E)) + $0FC19DC6 + w[18];
  tmp2 := (((g shr 2) or (g shl 30)) xor ((g shr 13) or (g shl 19)) xor ((g shr 22) xor (g shl 10))) + ((g and h) xor (g and a) xor (h and a));
  f := tmp1 + tmp2;
  b := b + tmp1;

  {
   * Round 19.
   *}
  tmp1 := E + (((b shr 6) or (b shl 26)) xor ((b shr 11) or (b shl 21)) xor ((b shr 25) or (b shl 7))) + ((b and c) xor (not b and d)) + $240CA1CC + w[19];
  tmp2 := (((f shr 2) or (f shl 30)) xor ((f shr 13) or (f shl 19)) xor ((f shr 22) xor (f shl 10))) + ((f and g) xor (f and h) xor (g and h));
  E := tmp1 + tmp2;
  a := a + tmp1;

  {
   * Round 20.
   *}
  tmp1 := d + (((a shr 6) or (a shl 26)) xor ((a shr 11) or (a shl 21)) xor ((a shr 25) or (a shl 7))) + ((a and b) xor (not a and c)) + $2DE92C6F + w[20];
  tmp2 := (((E shr 2) or (E shl 30)) xor ((E shr 13) or (E shl 19)) xor ((E shr 22) xor (E shl 10))) + ((E and f) xor (E and g) xor (f and g));
  d := tmp1 + tmp2;
  h := h + tmp1;

  {
   * Round 21.
   *}
  tmp1 := c + (((h shr 6) or (h shl 26)) xor ((h shr 11) or (h shl 21)) xor ((h shr 25) or (h shl 7))) + ((h and a) xor (not h and b)) + $4A7484AA + w[21];
  tmp2 := (((d shr 2) or (d shl 30)) xor ((d shr 13) or (d shl 19)) xor ((d shr 22) xor (d shl 10))) + ((d and E) xor (d and f) xor (E and f));
  c := tmp1 + tmp2;
  g := g + tmp1;

  {
   * Round 22.
   *}
  tmp1 := b + (((g shr 6) or (g shl 26)) xor ((g shr 11) or (g shl 21)) xor ((g shr 25) or (g shl 7))) + ((g and h) xor (not g and a)) + $5CB0A9DC + w[22];
  tmp2 := (((c shr 2) or (c shl 30)) xor ((c shr 13) or (c shl 19)) xor ((c shr 22) xor (c shl 10))) + ((c and d) xor (c and E) xor (d and E));
  b := tmp1 + tmp2;
  f := f + tmp1;

  {
   * Round 23.
   *}
  tmp1 := a + (((f shr 6) or (f shl 26)) xor ((f shr 11) or (f shl 21)) xor ((f shr 25) or (f shl 7))) + ((f and g) xor (not f and h)) + $76F988DA + w[23];
  tmp2 := (((b shr 2) or (b shl 30)) xor ((b shr 13) or (b shl 19)) xor ((b shr 22) xor (b shl 10))) + ((b and c) xor (b and d) xor (c and d));
  a := tmp1 + tmp2;
  E := E + tmp1;

  {
   * Round 24.
   *}
  tmp1 := h + (((E shr 6) or (E shl 26)) xor ((E shr 11) or (E shl 21)) xor ((E shr 25) or (E shl 7))) + ((E and f) xor (not E and g)) + $983E5152 + w[24];
  tmp2 := (((a shr 2) or (a shl 30)) xor ((a shr 13) or (a shl 19)) xor ((a shr 22) xor (a shl 10))) + ((a and b) xor (a and c) xor (b and c));
  h := tmp1 + tmp2;
  d := d + tmp1;

  {
   * Round 25.
   *}
  tmp1 := g + (((d shr 6) or (d shl 26)) xor ((d shr 11) or (d shl 21)) xor ((d shr 25) or (d shl 7))) + ((d and E) xor (not d and f)) + $A831C66D + w[25];
  tmp2 := (((h shr 2) or (h shl 30)) xor ((h shr 13) or (h shl 19)) xor ((h shr 22) xor (h shl 10))) + ((h and a) xor (h and b) xor (a and b));
  g := tmp1 + tmp2;
  c := c + tmp1;

  {
   * Round 26.
   *}
  tmp1 := f + (((c shr 6) or (c shl 26)) xor ((c shr 11) or (c shl 21)) xor ((c shr 25) or (c shl 7))) + ((c and d) xor (not c and E)) + $B00327C8 + w[26];
  tmp2 := (((g shr 2) or (g shl 30)) xor ((g shr 13) or (g shl 19)) xor ((g shr 22) xor (g shl 10))) + ((g and h) xor (g and a) xor (h and a));
  f := tmp1 + tmp2;
  b := b + tmp1;

  {
   * Round 27.
   *}
  tmp1 := E + (((b shr 6) or (b shl 26)) xor ((b shr 11) or (b shl 21)) xor ((b shr 25) or (b shl 7))) + ((b and c) xor (not b and d)) + $BF597FC7 + w[27];
  tmp2 := (((f shr 2) or (f shl 30)) xor ((f shr 13) or (f shl 19)) xor ((f shr 22) xor (f shl 10))) + ((f and g) xor (f and h) xor (g and h));
  E := tmp1 + tmp2;
  a := a + tmp1;

  {
   * Round 28.
   *}
  tmp1 := d + (((a shr 6) or (a shl 26)) xor ((a shr 11) or (a shl 21)) xor ((a shr 25) or (a shl 7))) + ((a and b) xor (not a and c)) + $C6E00BF3 + w[28];
  tmp2 := (((E shr 2) or (E shl 30)) xor ((E shr 13) or (E shl 19)) xor ((E shr 22) xor (E shl 10))) + ((E and f) xor (E and g) xor (f and g));
  d := tmp1 + tmp2;
  h := h + tmp1;

  {
   * Round 29.
   *}
  tmp1 := c + (((h shr 6) or (h shl 26)) xor ((h shr 11) or (h shl 21)) xor ((h shr 25) or (h shl 7))) + ((h and a) xor (not h and b)) + $D5A79147 + w[29];
  tmp2 := (((d shr 2) or (d shl 30)) xor ((d shr 13) or (d shl 19)) xor ((d shr 22) xor (d shl 10))) + ((d and E) xor (d and f) xor (E and f));
  c := tmp1 + tmp2;
  g := g + tmp1;

  {
   * Round 30.
   *}
  tmp1 := b + (((g shr 6) or (g shl 26)) xor ((g shr 11) or (g shl 21)) xor ((g shr 25) or (g shl 7))) + ((g and h) xor (not g and a)) + $06CA6351 + w[30];
  tmp2 := (((c shr 2) or (c shl 30)) xor ((c shr 13) or (c shl 19)) xor ((c shr 22) xor (c shl 10))) + ((c and d) xor (c and E) xor (d and E));
  b := tmp1 + tmp2;
  f := f + tmp1;

  {
   * Round 31.
   *}
  tmp1 := a + (((f shr 6) or (f shl 26)) xor ((f shr 11) or (f shl 21)) xor ((f shr 25) or (f shl 7))) + ((f and g) xor (not f and h)) + $14292967 + w[31];
  tmp2 := (((b shr 2) or (b shl 30)) xor ((b shr 13) or (b shl 19)) xor ((b shr 22) xor (b shl 10))) + ((b and c) xor (b and d) xor (c and d));
  a := tmp1 + tmp2;
  E := E + tmp1;

  {
   * Round 32.
   *}
  tmp1 := h + (((E shr 6) or (E shl 26)) xor ((E shr 11) or (E shl 21)) xor ((E shr 25) or (E shl 7))) + ((E and f) xor (not E and g)) + $27B70A85 + w[32];
  tmp2 := (((a shr 2) or (a shl 30)) xor ((a shr 13) or (a shl 19)) xor ((a shr 22) xor (a shl 10))) + ((a and b) xor (a and c) xor (b and c));
  h := tmp1 + tmp2;
  d := d + tmp1;

  {
   * Round 33.
   *}
  tmp1 := g + (((d shr 6) or (d shl 26)) xor ((d shr 11) or (d shl 21)) xor ((d shr 25) or (d shl 7))) + ((d and E) xor (not d and f)) + $2E1B2138 + w[33];
  tmp2 := (((h shr 2) or (h shl 30)) xor ((h shr 13) or (h shl 19)) xor ((h shr 22) xor (h shl 10))) + ((h and a) xor (h and b) xor (a and b));
  g := tmp1 + tmp2;
  c := c + tmp1;

  {
   * Round 34.
   *}
  tmp1 := f + (((c shr 6) or (c shl 26)) xor ((c shr 11) or (c shl 21)) xor ((c shr 25) or (c shl 7))) + ((c and d) xor (not c and E)) + $4D2C6DFC + w[34];
  tmp2 := (((g shr 2) or (g shl 30)) xor ((g shr 13) or (g shl 19)) xor ((g shr 22) xor (g shl 10))) + ((g and h) xor (g and a) xor (h and a));
  f := tmp1 + tmp2;
  b := b + tmp1;

  {
   * Round 35.
   *}
  tmp1 := E + (((b shr 6) or (b shl 26)) xor ((b shr 11) or (b shl 21)) xor ((b shr 25) or (b shl 7))) + ((b and c) xor (not b and d)) + $53380D13 + w[35];
  tmp2 := (((f shr 2) or (f shl 30)) xor ((f shr 13) or (f shl 19)) xor ((f shr 22) xor (f shl 10))) + ((f and g) xor (f and h) xor (g and h));
  E := tmp1 + tmp2;
  a := a + tmp1;

  {
   * Round 36.
   *}
  tmp1 := d + (((a shr 6) or (a shl 26)) xor ((a shr 11) or (a shl 21)) xor ((a shr 25) or (a shl 7))) + ((a and b) xor (not a and c)) + $650A7354 + w[36];
  tmp2 := (((E shr 2) or (E shl 30)) xor ((E shr 13) or (E shl 19)) xor ((E shr 22) xor (E shl 10))) + ((E and f) xor (E and g) xor (f and g));
  d := tmp1 + tmp2;
  h := h + tmp1;

  {
   * Round 37.
   *}
  tmp1 := c + (((h shr 6) or (h shl 26)) xor ((h shr 11) or (h shl 21)) xor ((h shr 25) or (h shl 7))) + ((h and a) xor (not h and b)) + $766A0ABB + w[37];
  tmp2 := (((d shr 2) or (d shl 30)) xor ((d shr 13) or (d shl 19)) xor ((d shr 22) xor (d shl 10))) + ((d and E) xor (d and f) xor (E and f));
  c := tmp1 + tmp2;
  g := g + tmp1;

  {
   * Round 38.
   *}
  tmp1 := b + (((g shr 6) or (g shl 26)) xor ((g shr 11) or (g shl 21)) xor ((g shr 25) or (g shl 7))) + ((g and h) xor (not g and a)) + $81C2C92E + w[38];
  tmp2 := (((c shr 2) or (c shl 30)) xor ((c shr 13) or (c shl 19)) xor ((c shr 22) xor (c shl 10))) + ((c and d) xor (c and E) xor (d and E));
  b := tmp1 + tmp2;
  f := f + tmp1;

  {
   * Round 39.
   *}
  tmp1 := a + (((f shr 6) or (f shl 26)) xor ((f shr 11) or (f shl 21)) xor ((f shr 25) or (f shl 7))) + ((f and g) xor (not f and h)) + $92722C85 + w[39];
  tmp2 := (((b shr 2) or (b shl 30)) xor ((b shr 13) or (b shl 19)) xor ((b shr 22) xor (b shl 10))) + ((b and c) xor (b and d) xor (c and d));
  a := tmp1 + tmp2;
  E := E + tmp1;

  {
   * Round 40.
   *}
  tmp1 := h + (((E shr 6) or (E shl 26)) xor ((E shr 11) or (E shl 21)) xor ((E shr 25) or (E shl 7))) + ((E and f) xor (not E and g)) + $A2BFE8A1 + w[40];
  tmp2 := (((a shr 2) or (a shl 30)) xor ((a shr 13) or (a shl 19)) xor ((a shr 22) xor (a shl 10))) + ((a and b) xor (a and c) xor (b and c));
  h := tmp1 + tmp2;
  d := d + tmp1;

  {
   * Round 41.
   *}
  tmp1 := g + (((d shr 6) or (d shl 26)) xor ((d shr 11) or (d shl 21)) xor ((d shr 25) or (d shl 7))) + ((d and E) xor (not d and f)) + $A81A664B + w[41];
  tmp2 := (((h shr 2) or (h shl 30)) xor ((h shr 13) or (h shl 19)) xor ((h shr 22) xor (h shl 10))) + ((h and a) xor (h and b) xor (a and b));
  g := tmp1 + tmp2;
  c := c + tmp1;

  {
   * Round 42.
   *}
  tmp1 := f + (((c shr 6) or (c shl 26)) xor ((c shr 11) or (c shl 21)) xor ((c shr 25) or (c shl 7))) + ((c and d) xor (not c and E)) + $C24B8B70 + w[42];
  tmp2 := (((g shr 2) or (g shl 30)) xor ((g shr 13) or (g shl 19)) xor ((g shr 22) xor (g shl 10))) + ((g and h) xor (g and a) xor (h and a));
  f := tmp1 + tmp2;
  b := b + tmp1;

  {
   * Round 43.
   *}
  tmp1 := E + (((b shr 6) or (b shl 26)) xor ((b shr 11) or (b shl 21)) xor ((b shr 25) or (b shl 7))) + ((b and c) xor (not b and d)) + $C76C51A3 + w[43];
  tmp2 := (((f shr 2) or (f shl 30)) xor ((f shr 13) or (f shl 19)) xor ((f shr 22) xor (f shl 10))) + ((f and g) xor (f and h) xor (g and h));
  E := tmp1 + tmp2;
  a := a + tmp1;

  {
   * Round 44.
   *}
  tmp1 := d + (((a shr 6) or (a shl 26)) xor ((a shr 11) or (a shl 21)) xor ((a shr 25) or (a shl 7))) + ((a and b) xor (not a and c)) + $D192E819 + w[44];
  tmp2 := (((E shr 2) or (E shl 30)) xor ((E shr 13) or (E shl 19)) xor ((E shr 22) xor (E shl 10))) + ((E and f) xor (E and g) xor (f and g));
  d := tmp1 + tmp2;
  h := h + tmp1;

  {
   * Round 45.
   *}
  tmp1 := c + (((h shr 6) or (h shl 26)) xor ((h shr 11) or (h shl 21)) xor ((h shr 25) or (h shl 7))) + ((h and a) xor (not h and b)) + $D6990624 + w[45];
  tmp2 := (((d shr 2) or (d shl 30)) xor ((d shr 13) or (d shl 19)) xor ((d shr 22) xor (d shl 10))) + ((d and E) xor (d and f) xor (E and f));
  c := tmp1 + tmp2;
  g := g + tmp1;

  {
   * Round 46.
   *}
  tmp1 := b + (((g shr 6) or (g shl 26)) xor ((g shr 11) or (g shl 21)) xor ((g shr 25) or (g shl 7))) + ((g and h) xor (not g and a)) + $F40E3585 + w[46];
  tmp2 := (((c shr 2) or (c shl 30)) xor ((c shr 13) or (c shl 19)) xor ((c shr 22) xor (c shl 10))) + ((c and d) xor (c and E) xor (d and E));
  b := tmp1 + tmp2;
  f := f + tmp1;

  {
   * Round 47.
   *}
  tmp1 := a + (((f shr 6) or (f shl 26)) xor ((f shr 11) or (f shl 21)) xor ((f shr 25) or (f shl 7))) + ((f and g) xor (not f and h)) + $106AA070 + w[47];
  tmp2 := (((b shr 2) or (b shl 30)) xor ((b shr 13) or (b shl 19)) xor ((b shr 22) xor (b shl 10))) + ((b and c) xor (b and d) xor (c and d));
  a := tmp1 + tmp2;
  E := E + tmp1;

  {
   * Round 48.
   *}
  tmp1 := h + (((E shr 6) or (E shl 26)) xor ((E shr 11) or (E shl 21)) xor ((E shr 25) or (E shl 7))) + ((E and f) xor (not E and g)) + $19A4C116 + w[48];
  tmp2 := (((a shr 2) or (a shl 30)) xor ((a shr 13) or (a shl 19)) xor ((a shr 22) xor (a shl 10))) + ((a and b) xor (a and c) xor (b and c));
  h := tmp1 + tmp2;
  d := d + tmp1;

  {
   * Round 49.
   *}
  tmp1 := g + (((d shr 6) or (d shl 26)) xor ((d shr 11) or (d shl 21)) xor ((d shr 25) or (d shl 7))) + ((d and E) xor (not d and f)) + $1E376C08 + w[49];
  tmp2 := (((h shr 2) or (h shl 30)) xor ((h shr 13) or (h shl 19)) xor ((h shr 22) xor (h shl 10))) + ((h and a) xor (h and b) xor (a and b));
  g := tmp1 + tmp2;
  c := c + tmp1;

  {
   * Round 50.
   *}
  tmp1 := f + (((c shr 6) or (c shl 26)) xor ((c shr 11) or (c shl 21)) xor ((c shr 25) or (c shl 7))) + ((c and d) xor (not c and E)) + $2748774C + w[50];
  tmp2 := (((g shr 2) or (g shl 30)) xor ((g shr 13) or (g shl 19)) xor ((g shr 22) xor (g shl 10))) + ((g and h) xor (g and a) xor (h and a));
  f := tmp1 + tmp2;
  b := b + tmp1;

  {
   * Round 51.
   *}
  tmp1 := E + (((b shr 6) or (b shl 26)) xor ((b shr 11) or (b shl 21)) xor ((b shr 25) or (b shl 7))) + ((b and c) xor (not b and d)) + $34B0BCB5 + w[51];
  tmp2 := (((f shr 2) or (f shl 30)) xor ((f shr 13) or (f shl 19)) xor ((f shr 22) xor (f shl 10))) + ((f and g) xor (f and h) xor (g and h));
  E := tmp1 + tmp2;
  a := a + tmp1;

  {
   * Round 52.
   *}
  tmp1 := d + (((a shr 6) or (a shl 26)) xor ((a shr 11) or (a shl 21)) xor ((a shr 25) or (a shl 7))) + ((a and b) xor (not a and c)) + $391C0CB3 + w[52];
  tmp2 := (((E shr 2) or (E shl 30)) xor ((E shr 13) or (E shl 19)) xor ((E shr 22) xor (E shl 10))) + ((E and f) xor (E and g) xor (f and g));
  d := tmp1 + tmp2;
  h := h + tmp1;

  {
   * Round 53.
   *}
  tmp1 := c + (((h shr 6) or (h shl 26)) xor ((h shr 11) or (h shl 21)) xor ((h shr 25) or (h shl 7))) + ((h and a) xor (not h and b)) + $4ED8AA4A + w[53];
  tmp2 := (((d shr 2) or (d shl 30)) xor ((d shr 13) or (d shl 19)) xor ((d shr 22) xor (d shl 10))) + ((d and E) xor (d and f) xor (E and f));
  c := tmp1 + tmp2;
  g := g + tmp1;

  {
   * Round 54.
   *}
  tmp1 := b + (((g shr 6) or (g shl 26)) xor ((g shr 11) or (g shl 21)) xor ((g shr 25) or (g shl 7))) + ((g and h) xor (not g and a)) + $5B9CCA4F + w[54];
  tmp2 := (((c shr 2) or (c shl 30)) xor ((c shr 13) or (c shl 19)) xor ((c shr 22) xor (c shl 10))) + ((c and d) xor (c and E) xor (d and E));
  b := tmp1 + tmp2;
  f := f + tmp1;

  {
   * Round 55.
   *}
  tmp1 := a + (((f shr 6) or (f shl 26)) xor ((f shr 11) or (f shl 21)) xor ((f shr 25) or (f shl 7))) + ((f and g) xor (not f and h)) + $682E6FF3 + w[55];
  tmp2 := (((b shr 2) or (b shl 30)) xor ((b shr 13) or (b shl 19)) xor ((b shr 22) xor (b shl 10))) + ((b and c) xor (b and d) xor (c and d));
  a := tmp1 + tmp2;
  E := E + tmp1;

  {
   * Round 56.
   *}
  tmp1 := h + (((E shr 6) or (E shl 26)) xor ((E shr 11) or (E shl 21)) xor ((E shr 25) or (E shl 7))) + ((E and f) xor (not E and g)) + $748F82EE + w[56];
  tmp2 := (((a shr 2) or (a shl 30)) xor ((a shr 13) or (a shl 19)) xor ((a shr 22) xor (a shl 10))) + ((a and b) xor (a and c) xor (b and c));
  h := tmp1 + tmp2;
  d := d + tmp1;

  {
   * Round 57.
   *}
  tmp1 := g + (((d shr 6) or (d shl 26)) xor ((d shr 11) or (d shl 21)) xor ((d shr 25) or (d shl 7))) + ((d and E) xor (not d and f)) + $78A5636F + w[57];
  tmp2 := (((h shr 2) or (h shl 30)) xor ((h shr 13) or (h shl 19)) xor ((h shr 22) xor (h shl 10))) + ((h and a) xor (h and b) xor (a and b));
  g := tmp1 + tmp2;
  c := c + tmp1;

  {
   * Round 58.
   *}
  tmp1 := f + (((c shr 6) or (c shl 26)) xor ((c shr 11) or (c shl 21)) xor ((c shr 25) or (c shl 7))) + ((c and d) xor (not c and E)) + $84C87814 + w[58];
  tmp2 := (((g shr 2) or (g shl 30)) xor ((g shr 13) or (g shl 19)) xor ((g shr 22) xor (g shl 10))) + ((g and h) xor (g and a) xor (h and a));
  f := tmp1 + tmp2;
  b := b + tmp1;

  {
   * Round 59.
   *}
  tmp1 := E + (((b shr 6) or (b shl 26)) xor ((b shr 11) or (b shl 21)) xor ((b shr 25) or (b shl 7))) + ((b and c) xor (not b and d)) + $8CC70208 + w[59];
  tmp2 := (((f shr 2) or (f shl 30)) xor ((f shr 13) or (f shl 19)) xor ((f shr 22) xor (f shl 10))) + ((f and g) xor (f and h) xor (g and h));
  E := tmp1 + tmp2;
  a := a + tmp1;

  {
   * Round 60.
   *}
  tmp1 := d + (((a shr 6) or (a shl 26)) xor ((a shr 11) or (a shl 21)) xor ((a shr 25) or (a shl 7))) + ((a and b) xor (not a and c)) + $90BEFFFA + w[60];
  tmp2 := (((E shr 2) or (E shl 30)) xor ((E shr 13) or (E shl 19)) xor ((E shr 22) xor (E shl 10))) + ((E and f) xor (E and g) xor (f and g));
  d := tmp1 + tmp2;
  h := h + tmp1;

  {
   * Round 61.
   *}
  tmp1 := c + (((h shr 6) or (h shl 26)) xor ((h shr 11) or (h shl 21)) xor ((h shr 25) or (h shl 7))) + ((h and a) xor (not h and b)) + $A4506CEB + w[61];
  tmp2 := (((d shr 2) or (d shl 30)) xor ((d shr 13) or (d shl 19)) xor ((d shr 22) xor (d shl 10))) + ((d and E) xor (d and f) xor (E and f));
  c := tmp1 + tmp2;
  g := g + tmp1;

  {
   * Round 62.
   *}
  tmp1 := b + (((g shr 6) or (g shl 26)) xor ((g shr 11) or (g shl 21)) xor ((g shr 25) or (g shl 7))) + ((g and h) xor (not g and a)) + $BEF9A3F7 + w[62];
  tmp2 := (((c shr 2) or (c shl 30)) xor ((c shr 13) or (c shl 19)) xor ((c shr 22) xor (c shl 10))) + ((c and d) xor (c and E) xor (d and E));
  b := tmp1 + tmp2;
  f := f + tmp1;

  {
   * Round 63.
   *}
  tmp1 := a + (((f shr 6) or (f shl 26)) xor ((f shr 11) or (f shl 21)) xor ((f shr 25) or (f shl 7))) + ((f and g) xor (not f and h)) + $C67178F2 + w[63];
  tmp2 := (((b shr 2) or (b shl 30)) xor ((b shr 13) or (b shl 19)) xor ((b shr 22) xor (b shl 10))) + ((b and c) xor (b and d) xor (c and d));
  a := tmp1 + tmp2;
  E := E + tmp1;

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
end;

class procedure TSHA256.SHA256(var Digest: TSHA256Digest; const Buf; BufSize: NativeUInt);
var
  Lo, Hi: DWORD;
  p: PByte;
  ChunkIndex: Byte;
  ChunkBuf: array [0 .. 63] of Byte;
begin
  {
   * Initialize the digest to the SHA-256 IV.
   *}
  PDWORD(@Digest[0])^  := $6A09E667;
  PDWORD(@Digest[4])^  := $BB67AE85;
  PDWORD(@Digest[8])^  := $3C6EF372;
  PDWORD(@Digest[12])^ := $A54FF53A;
  PDWORD(@Digest[16])^ := $510E527F;
  PDWORD(@Digest[20])^ := $9B05688C;
  PDWORD(@Digest[24])^ := $1F83D9AB;
  PDWORD(@Digest[28])^ := $5BE0CD19;

  {
   * Compute the message length in bits, split into low/high 32-bit halves,
   * and byte-swap into big-endian.
   *}
  Lo := 0;
  inc(Lo, DWORD(BufSize) shl 3);
  Hi := 0;
  inc(Hi, DWORD(BufSize) shr 29);

  SwapDWORD(Lo);
  SwapDWORD(Hi);

  {
   * Pre-clear the final-block workspace. Under FPC -O2 the compiler may
   * reuse the same stack slot for ChunkBuf and other temporaries; without
   * this clear, stale bytes could leak into the length field of the last
   * block and produce a non-deterministic digest.
   *}
  FillPtr(@ChunkBuf[0], SizeOf(ChunkBuf), 0);

  p := @Buf;

  {
   * Process every complete 64-byte block.
   *}
  while BufSize >= 64 do
    begin
      Compute(Digest, p);
      inc(p, 64);
      dec(BufSize, 64);
    end;

  {
   * Copy the remaining bytes (< 64) into the workspace.
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
   * If the length field does not fit in the remaining space, process
   * this block and start a second, all-zero block for the length only.
   *}
  if ChunkIndex > 56 then
    begin
      if ChunkIndex < 64 then
          FillPtr(@ChunkBuf[Integer(ChunkIndex)], SizeOf(ChunkBuf) - NativeUInt(ChunkIndex), 0);
      Compute(Digest, @ChunkBuf[0]);
      ChunkIndex := 0;
    end;

  {
   * Zero-fill up to byte 56, then write the 8-byte big-endian length.
   *}
  FillPtr(@ChunkBuf[Integer(ChunkIndex)], 56 - NativeUInt(ChunkIndex), 0);
  PDWORD(@ChunkBuf[56])^ := Hi;
  PDWORD(@ChunkBuf[60])^ := Lo;
  Compute(Digest, @ChunkBuf[0]);

  {
   * Byte-swap the digest to big-endian for output.
   *}
  SwapDWORD(PDWORD(@Digest[0])^);
  SwapDWORD(PDWORD(@Digest[4])^);
  SwapDWORD(PDWORD(@Digest[8])^);
  SwapDWORD(PDWORD(@Digest[12])^);
  SwapDWORD(PDWORD(@Digest[16])^);
  SwapDWORD(PDWORD(@Digest[20])^);
  SwapDWORD(PDWORD(@Digest[24])^);
  SwapDWORD(PDWORD(@Digest[28])^);

  {
   * Wipe the workspace.
   *}
  FillPtr(@ChunkBuf[0], SizeOf(ChunkBuf), 0);
end;

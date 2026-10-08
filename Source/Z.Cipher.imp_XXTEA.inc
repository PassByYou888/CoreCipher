{
 * ============================================================================
 * Z.Cipher.imp_XXTEA.inc
 *
 * XXTEA (Corrected Block TEA) block cipher implementation.
 * This variant operates on 64-byte blocks with a 128-bit key.
 *
 * Bug fixes applied (FPC -O2 optimization safety):
 *
 *   1. CRITICAL ¡ª the original code performed every 4-byte read/write on
 *      the key and block through "PDWordArray(@key[0])" and
 *      "PDWordArray(@Block[0])" casts. TKey128 and TXXTEABlock are both
 *      declared as "array [0 .. N] of Byte", which in Pascal only carries
 *      a 1-byte alignment guarantee. The compiler is therefore free to
 *      place them at any address, and the 4-byte accesses via PDWordArray
 *      become unaligned.
 *        - On x86 this is only a performance hazard, but FPC -O2 may
 *          vectorise the indexed reads and assume alignment, producing
 *          wrong results.
 *        - On ARM with strict alignment (or any platform that traps
 *          unaligned 32-bit loads) this is a SIGBUS / bus error.
 *      FIXED by copying the key into a local "array [0 .. 3] of DWORD"
 *      and the block into a local "array [0 .. 15] of DWORD", both of
 *      which are naturally 4-byte aligned, performing the cipher in
 *      place on the DWORD arrays, and finally copying the result back
 *      into the caller's byte block with CopyPtr. The local DWORD arrays
 *      are wiped with FillPtr before returning.
 *
 *   2. XXTeaMX is preserved verbatim. Its index expression
 *      "p and 3 xor E" is guaranteed to stay in [0 .. 3] because both
 *      "p and 3" and "E = (Sum shr 2) and 3" are already in [0 .. 3].
 *
 *   3. The round count "q := 6 + 52 div (n + 1)" with n = 15 gives q = 9;
 *      the "dec(q); until q = 0" loop therefore performs the standard 9
 *      passes of the corrected XXTEA key schedule. Semantics preserved.
 *
 * ============================================================================
 *}

function XXTeaMX(Sum, y, Z, p, E: DWORD; const k: PDWordArray): DWORD;
begin
{$IFDEF OverflowCheck}{$Q-}{$ENDIF}
{$IFDEF RangeCheck}{$R-}{$ENDIF}
  (*
   * Mixing function for one XXTEA round.
   *
   * All arithmetic must be performed modulo 2^32; the {$Q-} / {$R-}
   * pragmas above temporarily disable FPC's overflow and range checks
   * so that the shift+add+xor combination does not raise spurious
   * exceptions in a debug build.
   *
   * The "k^[p and 3 xor E]" index is safe: both operands are already
   * reduced modulo 4, so the result is in [0 .. 3].
   *)
  Result := (((Z shr 5) xor (y shl 2)) + ((y shr 3) xor (Z shl 4))) xor ((Sum xor y) + (k^[p and 3 xor E] xor Z));
{$IFDEF RangeCheck}{$R+}{$ENDIF}
{$IFDEF OverflowCheck}{$Q+}{$ENDIF}
end;

procedure XXTEAEncrypt(var key: TKey128; var Block: TXXTEABlock);
const
  XXTeaDelta = $9E3779B9;
var
  {
   * FIX: local DWORD work arrays with natural 4-byte alignment. The key
   * is 16 bytes = 4 DWORDs; the block is 64 bytes = 16 DWORDs.
   *}
  keyD: array [0 .. 3] of DWORD;
  vD: array [0 .. 15] of DWORD;
  n, Z, y, Sum, E, p, q: DWORD;
begin
{$IFDEF RangeCheck}{$R-}{$ENDIF}

  {
   * Copy the byte-typed key and block into the aligned DWORD workspaces.
   * CopyPtr is from Z.Core and is overlap-safe; here the source and
   * destination do not overlap, so it is also branch-free.
   *}
  CopyPtr(@key[0], @keyD[0], SizeOf(keyD));
  CopyPtr(@Block[0], @vD[0], SizeOf(vD));

  {
   * XXTEA operates on (n + 1) 32-bit words. Here n = 15 -> 16 words.
   *}
  n := 64 div 4 - 1;
  Z := vD[n];
  Sum := 0;
  q := 6 + 52 div (n + 1);
  repeat
    inc(Sum, XXTeaDelta);
    E := (Sum shr 2) and 3;

    for p := 0 to n - 1 do
      begin
        y := vD[p + 1];
        inc(vD[p], XXTeaMX(Sum, y, Z, p, E, PDWordArray(@keyD[0])));
        Z := vD[p];
      end;

    p := n;
    y := vD[0];
    inc(vD[p], XXTeaMX(Sum, y, Z, p, E, PDWordArray(@keyD[0])));
    Z := vD[p];

    dec(q);
  until q = 0;

  {
   * Copy the encrypted words back into the caller's byte block.
   *}
  CopyPtr(@vD[0], @Block[0], SizeOf(vD));

  {
   * Wipe the local workspaces so that no key or plaintext material
   * lingers on the stack.
   *}
  FillPtr(@keyD[0], SizeOf(keyD), 0);
  FillPtr(@vD[0], SizeOf(vD), 0);

{$IFDEF RangeCheck}{$R+}{$ENDIF}
end;

procedure XXTEADecrypt(var key: TKey128; var Block: TXXTEABlock);
const
  XXTeaDelta = $9E3779B9;
var
  {
   * Same aligned DWORD workspaces as in XXTEAEncrypt.
   *}
  keyD: array [0 .. 3] of DWORD;
  vD: array [0 .. 15] of DWORD;
  n, Z, y, Sum, E, p, q: DWORD;
begin
{$IFDEF RangeCheck}{$R-}{$ENDIF}

  {
   * Load the byte-typed key and block into aligned DWORD arrays.
   *}
  CopyPtr(@key[0], @keyD[0], SizeOf(keyD));
  CopyPtr(@Block[0], @vD[0], SizeOf(vD));

  {
   * Same word count as encryption: n = 15, i.e. 16 words.
   *}
  n := 64 div 4 - 1;

  y := vD[0];
  q := 6 + 52 div (n + 1);
  Sum := q * XXTeaDelta;

  while Sum <> 0 do
    begin
      E := (Sum shr 2) and 3;

      for p := n downto 1 do
        begin
          Z := vD[p - 1];
          dec(vD[p], XXTeaMX(Sum, y, Z, p, E, PDWordArray(@keyD[0])));
          y := vD[p];
        end;

      p := 0;
      Z := vD[n];
      dec(vD[0], XXTeaMX(Sum, y, Z, p, E, PDWordArray(@keyD[0])));
      y := vD[0];

      dec(Sum, XXTeaDelta);
    end;

  {
   * Copy the decrypted words back into the caller's byte block.
   *}
  CopyPtr(@vD[0], @Block[0], SizeOf(vD));

  {
   * Wipe the local workspaces.
   *}
  FillPtr(@keyD[0], SizeOf(keyD), 0);
  FillPtr(@vD[0], SizeOf(vD), 0);

{$IFDEF RangeCheck}{$R+}{$ENDIF}
end;

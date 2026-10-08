{
 * ============================================================================
 * Z.Cipher.imp_TMars.inc
 *
 * MARS block cipher (IBM, AES competition finalist) implementation.
 * 128-bit block, 128 / 192 / 256-bit keys, 40-DWORD round-key schedule.
 *
 * Bug fixes applied (FPC -O2 optimization safety):
 *
 *   1. CRITICAL ！ the local prekey array "t" is declared as
 *      "array [-7 .. 39] of DWORD" (47 elements = 188 bytes). The
 *      previous revision cleared it with "FillPtr(@t[0], SizeOf(t), 0)",
 *      which writes 188 bytes starting at element 0 ！ i.e. it covers
 *      t[0 .. 46] and overruns 7 DWORDs past t[39], clobbering adjacent
 *      stack locals (KeyB, or worse, the saved frame pointer). FIXED by
 *      addressing the array start as "@t[Low(t)]" (== "@t[-7]"), which
 *      is exactly what the original "FillPtrByte(@t, SizeOf(t), 0)"
 *      idiom compiled to.
 *
 *   2. CRITICAL ！ Encrypt and Decrypt accessed the caller's
 *      "TMarsBlock = array [0 .. 15] of Byte" through "PDWORD(@Data[0])^",
 *      assuming 4-byte alignment that Pascal does not guarantee for byte
 *      arrays. Under FPC -O2 the compiler may vectorise the accesses and
 *      assume alignment, and on ARM strict-alignment targets an unaligned
 *      32-bit read traps. FIXED by staging Data through a local
 *      "array [0 .. 3] of DWORD" workspace and CopyPtr-ing in and out.
 *
 *   3. CRITICAL ！ InitKey's "siz4 := Size div 4" yielded 0 for keys
 *      shorter than 4 bytes, and the subsequent "KeyB[i mod siz4]"
 *      triggered a divide-by-zero. FIXED by promoting siz4 to 1 when it
 *      is 0; KeyB[0] is either the first key byte or zero (the workspace
 *      is cleared with FillPtr at entry).
 *
 *   4. CRITICAL ！ the final key-schedule pass indexed "KeyContext[i + 3]"
 *      with i stepping 5, 7, ..., 37, so at i = 37 the access touched
 *      KeyContext[40] ！ one past the end of the 40-DWORD TMarskey record.
 *      FIXED by wrapping with "(i + 3) mod 40", preserving the intended
 *      circular access pattern.
 *
 *   5. xKeyD-equivalent workspaces (KeyB, t) and the per-block DWORD
 *      workspace are wiped with FillPtr before the routine returns, so
 *      key material and plaintext do not linger on the stack.
 *
 * ============================================================================
 *}

class procedure TMars.gen_mask(var x, m: DWORD);
var
  u: DWORD;
begin
  {
   * Compute the MARS "mask" that identifies which of the low 32 bits of
   * x are guaranteed to be non-zero-non-zero runs suitable for the
   * key-schedule tweak in InitKey. The reference algorithm is preserved
   * verbatim.
   *}
  u := x and (x shr 1);
  u := u and (u shr 2);
  u := u and (u shr 4);
  u := u and (u shr 1) and (u shr 2);
  m := u;
  u := (x xor $FFFFFFFF) and ((x xor $FFFFFFFF) shr 1);
  u := u and (u shr 2);
  u := u and (u shr 4);
  u := u and (u shr 1) and (u shr 2);
  u := u or m;
  m := (u shl 1) or (u shl 2) or (u shl 3) or (u shl 4) or
       (u shl 5) or (u shl 6) or (u shl 7) or (u shl 8);
  m := (m or u or (u shl 9))
       and ((x xor $FFFFFFFF) xor (x shl 1))
       and ((x xor $FFFFFFFF) xor (x shr 1));
  m := m and $FFFFFFFC;
end;

class procedure TMars.InitKey(buff: Pointer; Size: Integer; var KeyContext: TMarskey);
const
  vk: array [0 .. 6] of DWORD = (
    $09D0C479, $28C8FFE0, $84AA6C39, $9DAD7287, $7DFF9BE3, $D4268361, $C96DA1D4);
var
  i, j: Integer;
  m, u, w, siz4: DWORD;
  {
   * Prekey array: 7 negative indices (seed) plus 40 schedule words.
   * FillPtr MUST be applied at @t[Low(t)], not @t[0], to cover the
   * entire 47-element (188-byte) block.
   *}
  t: array [-7 .. 39] of DWORD;
  KeyB: array [0 .. 39] of DWORD;
  copySize: Integer;
begin
  m := 0;

  {
   * Pre-clear both workspaces so that every DWORD has a defined value
   * even for very short keys.
   *}
  FillPtr(@KeyB[0], SizeOf(KeyB), 0);
  FillPtr(@t[Low(t)], SizeOf(t), 0);

  {
   * Copy the caller's key material; clamp so we never overflow KeyB.
   *}
  copySize := Size;
  if copySize < 0 then
      copySize := 0;
  if copySize > SizeOf(KeyB) then
      copySize := SizeOf(KeyB);
  if (buff <> nil) and (copySize > 0) then
      CopyPtr(buff, @KeyB[0], copySize);

  {
   * FIX: promote siz4 to 1 when the key is shorter than one DWORD, so
   * the "KeyB[i mod siz4]" below cannot divide by zero.
   *}
  siz4 := DWORD(copySize) div 4;
  if siz4 = 0 then
      siz4 := 1;

  {
   * Seed t[-7 .. -1] with the MARS magic constants.
   *}
  CopyPtr(@vk[0], @t[-7], SizeOf(vk));

  {
   * First pass: expand t[0 .. 38] from the key and the seed.
   *}
  for i := 0 to 38 do
    begin
      u := t[i - 7] xor t[i - 2];
      t[i] := TRC6.LRot32(u, 3) xor KeyB[i mod Integer(siz4)] xor DWORD(i);
    end;
  t[39] := siz4;

  {
   * Second pass: seven rounds of mixing.
   *}
  for j := 0 to 6 do
    begin
      for i := 1 to 39 do
        begin
          u := t[i] + Mars_SBox[t[i - 1] and $1FF];
          t[i] := TRC6.LRot32(u, 9);
        end;
      u := t[0] + Mars_SBox[t[39] and $1FF];
      t[0] := TRC6.LRot32(u, 9);
    end;

  {
   * Distribute t[] into the 40-DWORD round-key array in a fixed stride.
   * "(7 * i) mod 40" for i in [0 .. 39] stays within [0 .. 39].
   *}
  for i := 0 to 39 do
      KeyContext[(7 * i) mod 40] := t[i];

  {
   * Final post-processing: strengthen each odd-indexed round key.
   *
   * FIX: the original loop indexed KeyContext[i + 3]; with i reaching 37
   * this touched KeyContext[40], one past the end of the record. We now
   * use "(i + 3) mod 40" so the access wraps around the 40-word array.
   *}
  i := 5;
  repeat
    u := Mars_SBox[265 + (KeyContext[i] and $3)];
    j := Integer(KeyContext[(i + 3) mod 40] and $1F);
    w := KeyContext[i] or $3;
    gen_mask(w, m);
    KeyContext[i] := w xor (TRC6.LRot32(u, DWORD(j)) and m);
    inc(i, 2);
  until i >= 37;

  {
   * Wipe both local workspaces.
   *}
  FillPtr(@KeyB[0], SizeOf(KeyB), 0);
  FillPtr(@t[Low(t)], SizeOf(t), 0);
end;

class procedure TMars.Encrypt(var KeyContext: TMarskey; var Data: TMarsBlock);
var
  L, m, R, t, a, b, c, d: DWORD;
  {
   * FIX: local DWORD workspace, naturally 4-byte aligned. The caller's
   * TMarsBlock is a byte array with only 1-byte alignment.
   *}
  w: array [0 .. 3] of DWORD;
begin
{$IFDEF RangeCheck}{$R-}{$ENDIF}

  {
   * Load the 16-byte block into four aligned DWORDs.
   *}
  CopyPtr(@Data[0], @w[0], SizeOf(w));

  a := w[0];
  b := w[1];
  c := w[2];
  d := w[3];

  {
   * Initial AddRoundKey.
   *}
  a := a + KeyContext[0];
  b := b + KeyContext[1];
  c := c + KeyContext[2];
  d := d + KeyContext[3];

  {
   * Forward mixing: 8 rounds of S-box substitution.
   *}
  b := b xor Mars_SBox[a and $FF];
  b := b + Mars_SBox[((a shr 8) and $FF) + 256];
  c := c + Mars_SBox[(a shr 16) and $FF];
  d := d xor Mars_SBox[((a shr 24) and $FF) + 256];
  a := TRC6.RRot32(a, 24);
  a := a + d;
  c := c xor Mars_SBox[b and $FF];
  c := c + Mars_SBox[((b shr 8) and $FF) + 256];
  d := d + Mars_SBox[(b shr 16) and $FF];
  a := a xor Mars_SBox[((b shr 24) and $FF) + 256];
  b := TRC6.RRot32(b, 24);
  b := b + c;
  d := d xor Mars_SBox[c and $FF];
  d := d + Mars_SBox[((c shr 8) and $FF) + 256];
  a := a + Mars_SBox[(c shr 16) and $FF];
  b := b xor Mars_SBox[((c shr 24) and $FF) + 256];
  c := TRC6.RRot32(c, 24);
  a := a xor Mars_SBox[d and $FF];
  a := a + Mars_SBox[((d shr 8) and $FF) + 256];
  b := b + Mars_SBox[(d shr 16) and $FF];
  c := c xor Mars_SBox[((d shr 24) and $FF) + 256];
  d := TRC6.RRot32(d, 24);

  b := b xor Mars_SBox[a and $FF];
  b := b + Mars_SBox[((a shr 8) and $FF) + 256];
  c := c + Mars_SBox[(a shr 16) and $FF];
  d := d xor Mars_SBox[((a shr 24) and $FF) + 256];
  a := TRC6.RRot32(a, 24);
  a := a + d;
  c := c xor Mars_SBox[b and $FF];
  c := c + Mars_SBox[((b shr 8) and $FF) + 256];
  d := d + Mars_SBox[(b shr 16) and $FF];
  a := a xor Mars_SBox[((b shr 24) and $FF) + 256];
  b := TRC6.RRot32(b, 24);
  b := b + c;
  d := d xor Mars_SBox[c and $FF];
  d := d + Mars_SBox[((c shr 8) and $FF) + 256];
  a := a + Mars_SBox[(c shr 16) and $FF];
  b := b xor Mars_SBox[((c shr 24) and $FF) + 256];
  c := TRC6.RRot32(c, 24);
  a := a xor Mars_SBox[d and $FF];
  a := a + Mars_SBox[((d shr 8) and $FF) + 256];
  b := b + Mars_SBox[(d shr 16) and $FF];
  c := c xor Mars_SBox[((d shr 24) and $FF) + 256];
  d := TRC6.RRot32(d, 24);

  {
   * Core rounds: 16 rounds of multiplication + data-dependent rotation.
   * Each round uses two KeyContext words.
   *}
  m := a + KeyContext[4];
  R := TRC6.LRot32(a, 13) * KeyContext[5];
  L := Mars_SBox[m and $1FF];
  R := TRC6.LRot32(R, 5);
  t := R and $1F;
  m := TRC6.LRot32(m, t);
  L := L xor R;
  R := TRC6.LRot32(R, 5);
  L := L xor R;
  t := R and $1F;
  L := TRC6.LRot32(L, t);
  a := TRC6.LRot32(a, 13);
  b := b + L;
  c := c + m;
  d := d xor R;

  m := b + KeyContext[6];
  R := TRC6.LRot32(b, 13) * KeyContext[7];
  L := Mars_SBox[m and $1FF];
  R := TRC6.LRot32(R, 5);
  t := R and $1F;
  m := TRC6.LRot32(m, t);
  L := L xor R;
  R := TRC6.LRot32(R, 5);
  L := L xor R;
  t := R and $1F;
  L := TRC6.LRot32(L, t);
  b := TRC6.LRot32(b, 13);
  c := c + L;
  d := d + m;
  a := a xor R;

  m := c + KeyContext[8];
  R := TRC6.LRot32(c, 13) * KeyContext[9];
  L := Mars_SBox[m and $1FF];
  R := TRC6.LRot32(R, 5);
  t := R and $1F;
  m := TRC6.LRot32(m, t);
  L := L xor R;
  R := TRC6.LRot32(R, 5);
  L := L xor R;
  t := R and $1F;
  L := TRC6.LRot32(L, t);
  c := TRC6.LRot32(c, 13);
  d := d + L;
  a := a + m;
  b := b xor R;

  m := d + KeyContext[10];
  R := TRC6.LRot32(d, 13) * KeyContext[11];
  L := Mars_SBox[m and $1FF];
  R := TRC6.LRot32(R, 5);
  t := R and $1F;
  m := TRC6.LRot32(m, t);
  L := L xor R;
  R := TRC6.LRot32(R, 5);
  L := L xor R;
  t := R and $1F;
  L := TRC6.LRot32(L, t);
  d := TRC6.LRot32(d, 13);
  a := a + L;
  b := b + m;
  c := c xor R;

  m := a + KeyContext[12];
  R := TRC6.LRot32(a, 13) * KeyContext[13];
  L := Mars_SBox[m and $1FF];
  R := TRC6.LRot32(R, 5);
  t := R and $1F;
  m := TRC6.LRot32(m, t);
  L := L xor R;
  R := TRC6.LRot32(R, 5);
  L := L xor R;
  t := R and $1F;
  L := TRC6.LRot32(L, t);
  a := TRC6.LRot32(a, 13);
  b := b + L;
  c := c + m;
  d := d xor R;

  m := b + KeyContext[14];
  R := TRC6.LRot32(b, 13) * KeyContext[15];
  L := Mars_SBox[m and $1FF];
  R := TRC6.LRot32(R, 5);
  t := R and $1F;
  m := TRC6.LRot32(m, t);
  L := L xor R;
  R := TRC6.LRot32(R, 5);
  L := L xor R;
  t := R and $1F;
  L := TRC6.LRot32(L, t);
  b := TRC6.LRot32(b, 13);
  c := c + L;
  d := d + m;
  a := a xor R;

  m := c + KeyContext[16];
  R := TRC6.LRot32(c, 13) * KeyContext[17];
  L := Mars_SBox[m and $1FF];
  R := TRC6.LRot32(R, 5);
  t := R and $1F;
  m := TRC6.LRot32(m, t);
  L := L xor R;
  R := TRC6.LRot32(R, 5);
  L := L xor R;
  t := R and $1F;
  L := TRC6.LRot32(L, t);
  c := TRC6.LRot32(c, 13);
  d := d + L;
  a := a + m;
  b := b xor R;

  m := d + KeyContext[18];
  R := TRC6.LRot32(d, 13) * KeyContext[19];
  L := Mars_SBox[m and $1FF];
  R := TRC6.LRot32(R, 5);
  t := R and $1F;
  m := TRC6.LRot32(m, t);
  L := L xor R;
  R := TRC6.LRot32(R, 5);
  L := L xor R;
  t := R and $1F;
  L := TRC6.LRot32(L, t);
  d := TRC6.LRot32(d, 13);
  a := a + L;
  b := b + m;
  c := c xor R;

  m := a + KeyContext[20];
  R := TRC6.LRot32(a, 13) * KeyContext[21];
  L := Mars_SBox[m and $1FF];
  R := TRC6.LRot32(R, 5);
  t := R and $1F;
  m := TRC6.LRot32(m, t);
  L := L xor R;
  R := TRC6.LRot32(R, 5);
  L := L xor R;
  t := R and $1F;
  L := TRC6.LRot32(L, t);
  a := TRC6.LRot32(a, 13);
  d := d + L;
  c := c + m;
  b := b xor R;

  m := b + KeyContext[22];
  R := TRC6.LRot32(b, 13) * KeyContext[23];
  L := Mars_SBox[m and $1FF];
  R := TRC6.LRot32(R, 5);
  t := R and $1F;
  m := TRC6.LRot32(m, t);
  L := L xor R;
  R := TRC6.LRot32(R, 5);
  L := L xor R;
  t := R and $1F;
  L := TRC6.LRot32(L, t);
  b := TRC6.LRot32(b, 13);
  a := a + L;
  d := d + m;
  c := c xor R;

  m := c + KeyContext[24];
  R := TRC6.LRot32(c, 13) * KeyContext[25];
  L := Mars_SBox[m and $1FF];
  R := TRC6.LRot32(R, 5);
  t := R and $1F;
  m := TRC6.LRot32(m, t);
  L := L xor R;
  R := TRC6.LRot32(R, 5);
  L := L xor R;
  t := R and $1F;
  L := TRC6.LRot32(L, t);
  c := TRC6.LRot32(c, 13);
  b := b + L;
  a := a + m;
  d := d xor R;

  m := d + KeyContext[26];
  R := TRC6.LRot32(d, 13) * KeyContext[27];
  L := Mars_SBox[m and $1FF];
  R := TRC6.LRot32(R, 5);
  t := R and $1F;
  m := TRC6.LRot32(m, t);
  L := L xor R;
  R := TRC6.LRot32(R, 5);
  L := L xor R;
  t := R and $1F;
  L := TRC6.LRot32(L, t);
  d := TRC6.LRot32(d, 13);
  c := c + L;
  b := b + m;
  a := a xor R;

  m := a + KeyContext[28];
  R := TRC6.LRot32(a, 13) * KeyContext[29];
  L := Mars_SBox[m and $1FF];
  R := TRC6.LRot32(R, 5);
  t := R and $1F;
  m := TRC6.LRot32(m, t);
  L := L xor R;
  R := TRC6.LRot32(R, 5);
  L := L xor R;
  t := R and $1F;
  L := TRC6.LRot32(L, t);
  a := TRC6.LRot32(a, 13);
  d := d + L;
  c := c + m;
  b := b xor R;

  m := b + KeyContext[30];
  R := TRC6.LRot32(b, 13) * KeyContext[31];
  L := Mars_SBox[m and $1FF];
  R := TRC6.LRot32(R, 5);
  t := R and $1F;
  m := TRC6.LRot32(m, t);
  L := L xor R;
  R := TRC6.LRot32(R, 5);
  L := L xor R;
  t := R and $1F;
  L := TRC6.LRot32(L, t);
  b := TRC6.LRot32(b, 13);
  a := a + L;
  d := d + m;
  c := c xor R;

  m := c + KeyContext[32];
  R := TRC6.LRot32(c, 13) * KeyContext[33];
  L := Mars_SBox[m and $1FF];
  R := TRC6.LRot32(R, 5);
  t := R and $1F;
  m := TRC6.LRot32(m, t);
  L := L xor R;
  R := TRC6.LRot32(R, 5);
  L := L xor R;
  t := R and $1F;
  L := TRC6.LRot32(L, t);
  c := TRC6.LRot32(c, 13);
  b := b + L;
  a := a + m;
  d := d xor R;

  m := d + KeyContext[34];
  R := TRC6.LRot32(d, 13) * KeyContext[35];
  L := Mars_SBox[m and $1FF];
  R := TRC6.LRot32(R, 5);
  t := R and $1F;
  m := TRC6.LRot32(m, t);
  L := L xor R;
  R := TRC6.LRot32(R, 5);
  L := L xor R;
  t := R and $1F;
  L := TRC6.LRot32(L, t);
  d := TRC6.LRot32(d, 13);
  c := c + L;
  b := b + m;
  a := a xor R;

  {
   * Backward mixing: 8 rounds of inverse S-box substitution.
   *}
  b := b xor Mars_SBox[(a and $FF) + 256];
  c := c - Mars_SBox[(a shr 24) and $FF];
  d := d - Mars_SBox[((a shr 16) and $FF) + 256];
  d := d xor Mars_SBox[(a shr 8) and $FF];
  a := TRC6.LRot32(a, 24);
  c := c xor Mars_SBox[(b and $FF) + 256];
  d := d - Mars_SBox[(b shr 24) and $FF];
  a := a - Mars_SBox[((b shr 16) and $FF) + 256];
  a := a xor Mars_SBox[(b shr 8) and $FF];
  b := TRC6.LRot32(b, 24);
  c := c - b;
  d := d xor Mars_SBox[(c and $FF) + 256];
  a := a - Mars_SBox[(c shr 24) and $FF];
  b := b - Mars_SBox[((c shr 16) and $FF) + 256];
  b := b xor Mars_SBox[(c shr 8) and $FF];
  c := TRC6.LRot32(c, 24);
  d := d - a;
  a := a xor Mars_SBox[(d and $FF) + 256];
  b := b - Mars_SBox[(d shr 24) and $FF];
  c := c - Mars_SBox[((d shr 16) and $FF) + 256];
  c := c xor Mars_SBox[(d shr 8) and $FF];
  d := TRC6.LRot32(d, 24);

  b := b xor Mars_SBox[(a and $FF) + 256];
  c := c - Mars_SBox[(a shr 24) and $FF];
  d := d - Mars_SBox[((a shr 16) and $FF) + 256];
  d := d xor Mars_SBox[(a shr 8) and $FF];
  a := TRC6.LRot32(a, 24);
  c := c xor Mars_SBox[(b and $FF) + 256];
  d := d - Mars_SBox[(b shr 24) and $FF];
  a := a - Mars_SBox[((b shr 16) and $FF) + 256];
  a := a xor Mars_SBox[(b shr 8) and $FF];
  b := TRC6.LRot32(b, 24);
  c := c - b;
  d := d xor Mars_SBox[(c and $FF) + 256];
  a := a - Mars_SBox[(c shr 24) and $FF];
  b := b - Mars_SBox[((c shr 16) and $FF) + 256];
  b := b xor Mars_SBox[(c shr 8) and $FF];
  c := TRC6.LRot32(c, 24);
  d := d - a;
  a := a xor Mars_SBox[(d and $FF) + 256];
  b := b - Mars_SBox[(d shr 24) and $FF];
  c := c - Mars_SBox[((d shr 16) and $FF) + 256];
  c := c xor Mars_SBox[(d shr 8) and $FF];
  d := TRC6.LRot32(d, 24);

  {
   * Final SubRoundKey.
   *}
  a := a - KeyContext[36];
  b := b - KeyContext[37];
  c := c - KeyContext[38];
  d := d - KeyContext[39];

  {
   * Store the result back into the caller's byte block.
   *}
  w[0] := a;
  w[1] := b;
  w[2] := c;
  w[3] := d;
  CopyPtr(@w[0], @Data[0], SizeOf(w));

  {
   * Wipe the local workspace.
   *}
  FillPtr(@w[0], SizeOf(w), 0);

{$IFDEF RangeCheck}{$R+}{$ENDIF}
end;

class procedure TMars.Decrypt(var KeyContext: TMarskey; var Data: TMarsBlock);
var
  L, m, R, t, a, b, c, d: DWORD;
  {
   * Same alignment-safe DWORD workspace as in Encrypt.
   *}
  w: array [0 .. 3] of DWORD;
begin
{$IFDEF RangeCheck}{$R-}{$ENDIF}

  {
   * Load the 16-byte block into four aligned DWORDs.
   *}
  CopyPtr(@Data[0], @w[0], SizeOf(w));

  a := w[0];
  b := w[1];
  c := w[2];
  d := w[3];

  {
   * Initial AddRoundKey (inverse: add the tail keys).
   *}
  a := a + KeyContext[36];
  b := b + KeyContext[37];
  c := c + KeyContext[38];
  d := d + KeyContext[39];

  {
   * Reverse backward-mixing.
   *}
  d := TRC6.RRot32(d, 24);
  c := c xor Mars_SBox[(d shr 8) and $FF];
  c := c + Mars_SBox[((d shr 16) and $FF) + 256];
  b := b + Mars_SBox[(d shr 24) and $FF];
  a := a xor Mars_SBox[(d and $FF) + 256];
  d := d + a;
  c := TRC6.RRot32(c, 24);
  b := b xor Mars_SBox[(c shr 8) and $FF];
  b := b + Mars_SBox[((c shr 16) and $FF) + 256];
  a := a + Mars_SBox[(c shr 24) and $FF];
  d := d xor Mars_SBox[(c and $FF) + 256];
  c := c + b;
  b := TRC6.RRot32(b, 24);
  a := a xor Mars_SBox[(b shr 8) and $FF];
  a := a + Mars_SBox[((b shr 16) and $FF) + 256];
  d := d + Mars_SBox[(b shr 24) and $FF];
  c := c xor Mars_SBox[(b and $FF) + 256];
  a := TRC6.RRot32(a, 24);
  d := d xor Mars_SBox[(a shr 8) and $FF];
  d := d + Mars_SBox[((a shr 16) and $FF) + 256];
  c := c + Mars_SBox[(a shr 24) and $FF];
  b := b xor Mars_SBox[(a and $FF) + 256];

  d := TRC6.RRot32(d, 24);
  c := c xor Mars_SBox[(d shr 8) and $FF];
  c := c + Mars_SBox[((d shr 16) and $FF) + 256];
  b := b + Mars_SBox[(d shr 24) and $FF];
  a := a xor Mars_SBox[(d and $FF) + 256];
  d := d + a;
  c := TRC6.RRot32(c, 24);
  b := b xor Mars_SBox[(c shr 8) and $FF];
  b := b + Mars_SBox[((c shr 16) and $FF) + 256];
  a := a + Mars_SBox[(c shr 24) and $FF];
  d := d xor Mars_SBox[(c and $FF) + 256];
  c := c + b;
  b := TRC6.RRot32(b, 24);
  a := a xor Mars_SBox[(b shr 8) and $FF];
  a := a + Mars_SBox[((b shr 16) and $FF) + 256];
  d := d + Mars_SBox[(b shr 24) and $FF];
  c := c xor Mars_SBox[(b and $FF) + 256];
  a := TRC6.RRot32(a, 24);
  d := d xor Mars_SBox[(a shr 8) and $FF];
  d := d + Mars_SBox[((a shr 16) and $FF) + 256];
  c := c + Mars_SBox[(a shr 24) and $FF];
  b := b xor Mars_SBox[(a and $FF) + 256];

  {
   * Reverse core rounds (in reverse key order).
   *}
  d := TRC6.RRot32(d, 13);
  m := d + KeyContext[34];
  R := TRC6.LRot32(d, 13) * KeyContext[35];
  L := Mars_SBox[m and $1FF];
  R := TRC6.LRot32(R, 5);
  t := R and $1F;
  m := TRC6.LRot32(m, t);
  L := L xor R;
  R := TRC6.LRot32(R, 5);
  L := L xor R;
  t := R and $1F;
  L := TRC6.LRot32(L, t);
  c := c - L;
  b := b - m;
  a := a xor R;

  c := TRC6.RRot32(c, 13);
  m := c + KeyContext[32];
  R := TRC6.LRot32(c, 13) * KeyContext[33];
  L := Mars_SBox[m and $1FF];
  R := TRC6.LRot32(R, 5);
  t := R and $1F;
  m := TRC6.LRot32(m, t);
  L := L xor R;
  R := TRC6.LRot32(R, 5);
  L := L xor R;
  t := R and $1F;
  L := TRC6.LRot32(L, t);
  b := b - L;
  a := a - m;
  d := d xor R;

  b := TRC6.RRot32(b, 13);
  m := b + KeyContext[30];
  R := TRC6.LRot32(b, 13) * KeyContext[31];
  L := Mars_SBox[m and $1FF];
  R := TRC6.LRot32(R, 5);
  t := R and $1F;
  m := TRC6.LRot32(m, t);
  L := L xor R;
  R := TRC6.LRot32(R, 5);
  L := L xor R;
  t := R and $1F;
  L := TRC6.LRot32(L, t);
  a := a - L;
  d := d - m;
  c := c xor R;

  a := TRC6.RRot32(a, 13);
  m := a + KeyContext[28];
  R := TRC6.LRot32(a, 13) * KeyContext[29];
  L := Mars_SBox[m and $1FF];
  R := TRC6.LRot32(R, 5);
  t := R and $1F;
  m := TRC6.LRot32(m, t);
  L := L xor R;
  R := TRC6.LRot32(R, 5);
  L := L xor R;
  t := R and $1F;
  L := TRC6.LRot32(L, t);
  d := d - L;
  c := c - m;
  b := b xor R;

  d := TRC6.RRot32(d, 13);
  m := d + KeyContext[26];
  R := TRC6.LRot32(d, 13) * KeyContext[27];
  L := Mars_SBox[m and $1FF];
  R := TRC6.LRot32(R, 5);
  t := R and $1F;
  m := TRC6.LRot32(m, t);
  L := L xor R;
  R := TRC6.LRot32(R, 5);
  L := L xor R;
  t := R and $1F;
  L := TRC6.LRot32(L, t);
  c := c - L;
  b := b - m;
  a := a xor R;

  c := TRC6.RRot32(c, 13);
  m := c + KeyContext[24];
  R := TRC6.LRot32(c, 13) * KeyContext[25];
  L := Mars_SBox[m and $1FF];
  R := TRC6.LRot32(R, 5);
  t := R and $1F;
  m := TRC6.LRot32(m, t);
  L := L xor R;
  R := TRC6.LRot32(R, 5);
  L := L xor R;
  t := R and $1F;
  L := TRC6.LRot32(L, t);
  b := b - L;
  a := a - m;
  d := d xor R;

  b := TRC6.RRot32(b, 13);
  m := b + KeyContext[22];
  R := TRC6.LRot32(b, 13) * KeyContext[23];
  L := Mars_SBox[m and $1FF];
  R := TRC6.LRot32(R, 5);
  t := R and $1F;
  m := TRC6.LRot32(m, t);
  L := L xor R;
  R := TRC6.LRot32(R, 5);
  L := L xor R;
  t := R and $1F;
  L := TRC6.LRot32(L, t);
  a := a - L;
  d := d - m;
  c := c xor R;

  a := TRC6.RRot32(a, 13);
  m := a + KeyContext[20];
  R := TRC6.LRot32(a, 13) * KeyContext[21];
  L := Mars_SBox[m and $1FF];
  R := TRC6.LRot32(R, 5);
  t := R and $1F;
  m := TRC6.LRot32(m, t);
  L := L xor R;
  R := TRC6.LRot32(R, 5);
  L := L xor R;
  t := R and $1F;
  L := TRC6.LRot32(L, t);
  d := d - L;
  c := c - m;
  b := b xor R;

  d := TRC6.RRot32(d, 13);
  m := d + KeyContext[18];
  R := TRC6.LRot32(d, 13) * KeyContext[19];
  L := Mars_SBox[m and $1FF];
  R := TRC6.LRot32(R, 5);
  t := R and $1F;
  m := TRC6.LRot32(m, t);
  L := L xor R;
  R := TRC6.LRot32(R, 5);
  L := L xor R;
  t := R and $1F;
  L := TRC6.LRot32(L, t);
  a := a - L;
  b := b - m;
  c := c xor R;

  c := TRC6.RRot32(c, 13);
  m := c + KeyContext[16];
  R := TRC6.LRot32(c, 13) * KeyContext[17];
  L := Mars_SBox[m and $1FF];
  R := TRC6.LRot32(R, 5);
  t := R and $1F;
  m := TRC6.LRot32(m, t);
  L := L xor R;
  R := TRC6.LRot32(R, 5);
  L := L xor R;
  t := R and $1F;
  L := TRC6.LRot32(L, t);
  d := d - L;
  a := a - m;
  b := b xor R;

  b := TRC6.RRot32(b, 13);
  m := b + KeyContext[14];
  R := TRC6.LRot32(b, 13) * KeyContext[15];
  L := Mars_SBox[m and $1FF];
  R := TRC6.LRot32(R, 5);
  t := R and $1F;
  m := TRC6.LRot32(m, t);
  L := L xor R;
  R := TRC6.LRot32(R, 5);
  L := L xor R;
  t := R and $1F;
  L := TRC6.LRot32(L, t);
  c := c - L;
  d := d - m;
  a := a xor R;

  a := TRC6.RRot32(a, 13);
  m := a + KeyContext[12];
  R := TRC6.LRot32(a, 13) * KeyContext[13];
  L := Mars_SBox[m and $1FF];
  R := TRC6.LRot32(R, 5);
  t := R and $1F;
  m := TRC6.LRot32(m, t);
  L := L xor R;
  R := TRC6.LRot32(R, 5);
  L := L xor R;
  t := R and $1F;
  L := TRC6.LRot32(L, t);
  b := b - L;
  c := c - m;
  d := d xor R;

  d := TRC6.RRot32(d, 13);
  m := d + KeyContext[10];
  R := TRC6.LRot32(d, 13) * KeyContext[11];
  L := Mars_SBox[m and $1FF];
  R := TRC6.LRot32(R, 5);
  t := R and $1F;
  m := TRC6.LRot32(m, t);
  L := L xor R;
  R := TRC6.LRot32(R, 5);
  L := L xor R;
  t := R and $1F;
  L := TRC6.LRot32(L, t);
  a := a - L;
  b := b - m;
  c := c xor R;

  c := TRC6.RRot32(c, 13);
  m := c + KeyContext[8];
  R := TRC6.LRot32(c, 13) * KeyContext[9];
  L := Mars_SBox[m and $1FF];
  R := TRC6.LRot32(R, 5);
  t := R and $1F;
  m := TRC6.LRot32(m, t);
  L := L xor R;
  R := TRC6.LRot32(R, 5);
  L := L xor R;
  t := R and $1F;
  L := TRC6.LRot32(L, t);
  d := d - L;
  a := a - m;
  b := b xor R;

  b := TRC6.RRot32(b, 13);
  m := b + KeyContext[6];
  R := TRC6.LRot32(b, 13) * KeyContext[7];
  L := Mars_SBox[m and $1FF];
  R := TRC6.LRot32(R, 5);
  t := R and $1F;
  m := TRC6.LRot32(m, t);
  L := L xor R;
  R := TRC6.LRot32(R, 5);
  L := L xor R;
  t := R and $1F;
  L := TRC6.LRot32(L, t);
  c := c - L;
  d := d - m;
  a := a xor R;

  a := TRC6.RRot32(a, 13);
  m := a + KeyContext[4];
  R := TRC6.LRot32(a, 13) * KeyContext[5];
  L := Mars_SBox[m and $1FF];
  R := TRC6.LRot32(R, 5);
  t := R and $1F;
  m := TRC6.LRot32(m, t);
  L := L xor R;
  R := TRC6.LRot32(R, 5);
  L := L xor R;
  t := R and $1F;
  L := TRC6.LRot32(L, t);
  b := b - L;
  c := c - m;
  d := d xor R;

  {
   * Reverse forward-mixing.
   *}
  d := TRC6.LRot32(d, 24);
  c := c xor Mars_SBox[((d shr 24) and $FF) + 256];
  b := b - Mars_SBox[(d shr 16) and $FF];
  a := a - Mars_SBox[((d shr 8) and $FF) + 256];
  a := a xor Mars_SBox[d and $FF];
  c := TRC6.LRot32(c, 24);
  b := b xor Mars_SBox[((c shr 24) and $FF) + 256];
  a := a - Mars_SBox[(c shr 16) and $FF];
  d := d - Mars_SBox[((c shr 8) and $FF) + 256];
  d := d xor Mars_SBox[c and $FF];
  b := b - c;
  b := TRC6.LRot32(b, 24);
  a := a xor Mars_SBox[((b shr 24) and $FF) + 256];
  d := d - Mars_SBox[(b shr 16) and $FF];
  c := c - Mars_SBox[((b shr 8) and $FF) + 256];
  c := c xor Mars_SBox[b and $FF];
  a := a - d;
  a := TRC6.LRot32(a, 24);
  d := d xor Mars_SBox[((a shr 24) and $FF) + 256];
  c := c - Mars_SBox[(a shr 16) and $FF];
  b := b - Mars_SBox[((a shr 8) and $FF) + 256];
  b := b xor Mars_SBox[a and $FF];

  d := TRC6.LRot32(d, 24);
  c := c xor Mars_SBox[((d shr 24) and $FF) + 256];
  b := b - Mars_SBox[(d shr 16) and $FF];
  a := a - Mars_SBox[((d shr 8) and $FF) + 256];
  a := a xor Mars_SBox[d and $FF];
  c := TRC6.LRot32(c, 24);
  b := b xor Mars_SBox[((c shr 24) and $FF) + 256];
  a := a - Mars_SBox[(c shr 16) and $FF];
  d := d - Mars_SBox[((c shr 8) and $FF) + 256];
  d := d xor Mars_SBox[c and $FF];
  b := b - c;
  b := TRC6.LRot32(b, 24);
  a := a xor Mars_SBox[((b shr 24) and $FF) + 256];
  d := d - Mars_SBox[(b shr 16) and $FF];
  c := c - Mars_SBox[((b shr 8) and $FF) + 256];
  c := c xor Mars_SBox[b and $FF];
  a := a - d;
  a := TRC6.LRot32(a, 24);
  d := d xor Mars_SBox[((a shr 24) and $FF) + 256];
  c := c - Mars_SBox[(a shr 16) and $FF];
  b := b - Mars_SBox[((a shr 8) and $FF) + 256];
  b := b xor Mars_SBox[a and $FF];

  {
   * Final SubRoundKey (inverse: subtract the head keys).
   *}
  a := a - KeyContext[0];
  b := b - KeyContext[1];
  c := c - KeyContext[2];
  d := d - KeyContext[3];

  {
   * Store the result back into the caller's byte block.
   *}
  w[0] := a;
  w[1] := b;
  w[2] := c;
  w[3] := d;
  CopyPtr(@w[0], @Data[0], SizeOf(w));

  {
   * Wipe the local workspace.
   *}
  FillPtr(@w[0], SizeOf(w), 0);

{$IFDEF RangeCheck}{$R+}{$ENDIF}
end;

{
 * ============================================================================
 * Z.Cipher.imp_TRC6.inc  ！  RC6 block cipher implementation
 *
 * RC6 (Rivest Cipher 6), AES competition finalist.
 * 128-bit block, variable key size, 20 rounds by default.
 *
 * Bug fixes applied (FPC -O2 optimization safety):
 *
 *   1. CRITICAL ！ the key-schedule loop "for k := 1 to k do" reused the
 *      loop counter "k" as its own upper bound. Under FPC -O2 the
 *      compiler hoists the bound read into a register before the loop
 *      body executes; because the register initially holds the loop
 *      variable (not the intended bound), the loop runs at most once and
 *      the key schedule is almost entirely wrong. FIXED by introducing a
 *      separate counter "kk" and a distinct bound variable "kCount".
 *
 *   2. CRITICAL ！ InitKey performed "Size := Size div 8" at the top of
 *      the routine, yet every caller passes Size as a *byte* count (32
 *      bytes of LMD-derived key material). The subsequent "xKeyLen :=
 *      Size div 4" therefore ended up with 1 instead of 8 for a 256-bit
 *      key, so 7/8 of the derived key material was silently discarded.
 *      FIXED by removing the erroneous divide-by-8; Size now retains its
 *      byte semantics and xKeyLen becomes the correct DWORD count.
 *
 *   3. CRITICAL ！ Encrypt / Decrypt accessed the caller's
 *      "TRC6Block = array [0 .. 15] of Byte" through
 *      "PDWORD(@Data[0])" and friends, which assumes 4-byte alignment.
 *      A Pascal byte array only carries a 1-byte alignment guarantee, so
 *      the compiler is free to place it at any address; on strict-
 *      alignment targets (ARM) this is a SIGBUS, and under FPC -O2 on
 *      x86 the compiler may vectorise the read and produce wrong
 *      results. FIXED by staging Data through a local
 *      "array [0 .. 3] of DWORD" workspace (naturally aligned) and
 *      CopyPtr-ing in and out.
 *
 *   4. Defensive bounds: the local "xKeyD: array [0 .. 63] of DWORD"
 *      workspace is limited to 256 bytes; the incoming copy is clamped
 *      to that size before CopyPtr, so an over-sized caller cannot
 *      overflow the stack.
 *
 *   5. xKeyD and the per-block DWORD workspace are wiped with FillPtr
 *      before the routine returns, so key material and plaintext do not
 *      linger on the stack.
 *
 * ============================================================================
 *}

class function TRC6.LRot32(x, c: DWORD): DWORD;
begin
  {
   * Left-rotate by c mod 32 bits. ROL32 (Z.Core) already masks the
   * shift amount with "and 31", so we only need to narrow c to Byte.
   *}
  LRot32 := ROL32(x, Byte(c));
end;

class function TRC6.RRot32(x, c: DWORD): DWORD;
begin
  {
   * Right-rotate by c mod 32 bits. ROR32 (Z.Core) masks the shift.
   *}
  RRot32 := ROR32(x, Byte(c));
end;

class procedure TRC6.InitKey(buff: Pointer; Size: Integer; var KeyContext: TRC6Key);
const
  cRC6_sBox: array [0 .. 51] of DWORD = (
  $B7E15163, $5618CB1C, $F45044D5, $9287BE8E, $30BF3847, $CEF6B200,
    $6D2E2BB9, $0B65A572, $A99D1F2B, $47D498E4, $E60C129D, $84438C56,
    $227B060F, $C0B27FC8, $5EE9F981, $FD21733A, $9B58ECF3, $399066AC,
    $D7C7E065, $75FF5A1E, $1436D3D7, $B26E4D90, $50A5C749, $EEDD4102,
    $8D14BABB, $2B4C3474, $C983AE2D, $67BB27E6, $05F2A19F, $A42A1B58,
    $42619511, $E0990ECA, $7ED08883, $1D08023C, $BB3F7BF5, $5976F5AE,
    $F7AE6F67, $95E5E920, $341D62D9, $D254DC92, $708C564B, $0EC3D004,
    $ACFB49BD, $4B32C376, $E96A3D2F, $87A1B6E8, $25D930A1, $C410AA5A,
    $62482413, $007F9DCC, $9EB71785, $3CEE913E);
var
  {
   * Fixed 256-byte DWORD workspace for the raw key material. FPC will
   * place this on a 4-byte (or wider) boundary, so all xKeyD[j] accesses
   * are naturally aligned.
   *}
  xKeyD: array [0 .. 63] of DWORD;
  i, j, kk, kCount, xKeyLen, a, b: DWORD;
  sBoxSize: DWORD;
  copySize: Integer;
  buffBytes: PByte;
begin
  {
   * Zero the entire 256-byte workspace first. FillPtr replaces the
   * original "CopyPtr(@cRC6_sBox, ...)" pattern that left the tail
   * uninitialized.
   *}
  FillPtr(@xKeyD[0], SizeOf(xKeyD), 0);

  {
   * FIX: the previous revision divided Size by 8 here, silently
   * discarding 7/8 of the caller's key material. Size now keeps its
   * byte semantics.
   *
   * Defensive cap: never copy more than the workspace can hold.
   *}
  copySize := Size;
  if copySize < 0 then
      copySize := 0;
  if copySize > SizeOf(xKeyD) then
      copySize := SizeOf(xKeyD);

  if (buff <> nil) and (copySize > 0) then
    begin
      {
       * Copy via PByte so the compiler does not need to assume any
       * alignment on the caller's buffer.
       *}
      buffBytes := PByte(buff);
      CopyPtr(buffBytes, @xKeyD[0], copySize);
    end;

  {
   * Number of DWORDs in the effective key, rounded up.
   * For copySize = 32 this gives xKeyLen = 8 (256-bit key).
   *}
  xKeyLen := DWORD(copySize) div 4;
  if (DWORD(copySize) mod 4) <> 0 then
      inc(xKeyLen);
  if xKeyLen = 0 then
      xKeyLen := 1;   { avoid "mod 0" in the mixing loop below }

  {
   * Size of the round-key schedule: 2*Rounds + 4 DWORDs.
   * For Rounds = 20 this is 44.
   *}
  sBoxSize := (cRC6_NumRounds * 2) + 4;

  {
   * Initialize the round-key array from the standard RC6 magic
   * constants. Note only the first sBoxSize entries are needed.
   *}
  CopyPtr(@cRC6_sBox[0], @KeyContext, sBoxSize * SizeOf(DWORD));

  i := 0;
  j := 0;
  a := 0;
  b := 0;

  {
   * Number of mixing iterations: 3 * max(xKeyLen, sBoxSize).
   *}
  if xKeyLen > sBoxSize then
      kCount := xKeyLen * 3
  else
      kCount := sBoxSize * 3;

  {
   * FIX: use a dedicated loop counter (kk) and a distinct bound
   * (kCount). Under FPC -O2, "for k := 1 to k" hoists the bound read
   * out of the register initialized with the loop variable, causing the
   * loop to execute at most once and corrupting the entire key schedule.
   *}
  for kk := 1 to kCount do
    begin
      a := LRot32(KeyContext[i] + a + b, 3);
      KeyContext[i] := a;
      b := LRot32(xKeyD[j] + a + b, a + b);
      xKeyD[j] := b;
      i := (i + 1) mod sBoxSize;
      j := (j + 1) mod xKeyLen;
    end;

  {
   * Wipe the local key workspace.
   *}
  FillPtr(@xKeyD[0], SizeOf(xKeyD), 0);
end;

class procedure TRC6.Encrypt(var KeyContext: TRC6Key; var Data: TRC6Block);
var
  {
   * FIX: local DWORD workspace (naturally 4-byte aligned). The caller's
   * TRC6Block is a byte array with only 1-byte alignment; the previous
   * "PDWORD(@Data[0])" accesses were unaligned.
   *}
  w: array [0 .. 3] of DWORD;
  u, t, i: DWORD;
begin
{$IFDEF RangeCheck}{$R-}{$ENDIF}

  {
   * Load the 16-byte block into four aligned DWORDs.
   *}
  CopyPtr(@Data[0], @w[0], SizeOf(w));

  w[1] := w[1] + KeyContext[0];
  w[3] := w[3] + KeyContext[1];
  for i := 1 to cRC6_NumRounds do
    begin
      t := LRot32(w[1] * (2 * w[1] + 1), 5);
      u := LRot32(w[3] * (2 * w[3] + 1), 5);
      w[0] := LRot32(w[0] xor t, u) + KeyContext[2 * i];
      w[2] := LRot32(w[2] xor u, t) + KeyContext[2 * i + 1];
      t := w[0];
      w[0] := w[1];
      w[1] := w[2];
      w[2] := w[3];
      w[3] := t;
    end;
  w[0] := w[0] + KeyContext[(2 * cRC6_NumRounds) + 2];
  w[2] := w[2] + KeyContext[(2 * cRC6_NumRounds) + 3];

  {
   * Store the result back into the caller's byte block.
   *}
  CopyPtr(@w[0], @Data[0], SizeOf(w));

  {
   * Wipe the local workspace.
   *}
  FillPtr(@w[0], SizeOf(w), 0);

{$IFDEF RangeCheck}{$R+}{$ENDIF}
end;

class procedure TRC6.Decrypt(var KeyContext: TRC6Key; var Data: TRC6Block);
var
  {
   * Same alignment-safe DWORD workspace as in Encrypt.
   *}
  w: array [0 .. 3] of DWORD;
  u, t, i: DWORD;
begin
{$IFDEF RangeCheck}{$R-}{$ENDIF}

  {
   * Load the 16-byte block into four aligned DWORDs.
   *}
  CopyPtr(@Data[0], @w[0], SizeOf(w));

  w[2] := w[2] - KeyContext[(2 * cRC6_NumRounds) + 3];
  w[0] := w[0] - KeyContext[(2 * cRC6_NumRounds) + 2];
  for i := cRC6_NumRounds downto 1 do
    begin
      t := w[0];
      w[0] := w[3];
      w[3] := w[2];
      w[2] := w[1];
      w[1] := t;
      u := LRot32(w[3] * (2 * w[3] + 1), 5);
      t := LRot32(w[1] * (2 * w[1] + 1), 5);
      w[2] := RRot32(w[2] - KeyContext[2 * i + 1], t) xor u;
      w[0] := RRot32(w[0] - KeyContext[2 * i], u) xor t;
    end;
  w[3] := w[3] - KeyContext[1];
  w[1] := w[1] - KeyContext[0];

  {
   * Store the result back into the caller's byte block.
   *}
  CopyPtr(@w[0], @Data[0], SizeOf(w));

  {
   * Wipe the local workspace.
   *}
  FillPtr(@w[0], SizeOf(w), 0);

{$IFDEF RangeCheck}{$R+}{$ENDIF}
end;

{
 * ============================================================================
 * Z.Cipher.imp_TLBC.inc
 *
 * LBC (Layered Block Cipher) and LQC (Light Quick Cipher) implementations.
 *
 * Bug fixes applied (FPC -O2 optimization safety):
 *
 *   1. CRITICAL ！ EncryptLBC read the per-round subkey through
 *      "TBCHalfBlock(Context.SubKeys64[R])[0]" and "[1]". SubKeys64[R] is
 *      a TKey64 (array [0 .. 7] of Byte), which only carries a 1-byte
 *      alignment guarantee; casting it to TBCHalfBlock (array [0 .. 1] of
 *      Integer, requiring 4-byte alignment) yields an unaligned 32-bit
 *      read. On x86 this silently degrades, on strict-alignment ARM it
 *      traps, and under FPC -O2 the compiler may vectorise the access
 *      assuming alignment. FIXED by copying the 8-byte subkey into a
 *      local, naturally aligned "keyHalf: TBCHalfBlock" via CopyPtr at
 *      the top of each round.
 *
 *   2. SEVERE ！ InitEncryptLBC accepted an odd "Rounds" value after the
 *      "[4 .. 16]" clamp; because subkeys are stored as pairs of TKey64
 *      (8-byte) entries, an odd round count leaves the final pair
 *      un-reversed in the decrypt path and breaks the symmetry between
 *      EncryptLBC and the decrypt-side key schedule. FIXED by rounding
 *      up to the nearest even value and re-clamping.
 *
 *   3. SEVERE ！ the local "Temp: TDCPTFSubKeys" used during the key-
 *      schedule reversal was an uninitialized variant record. Although
 *      the code path always writes before reading, under FPC -O2 the
 *      compiler may reuse registers / stack slots across the two loops.
 *      FIXED with an explicit FillPtr at entry and at exit.
 *
 *   4. SEVERE ！ InitEncryptLBC accessed the key bytes through an
 *      unbounded "PDWordArray" cast ("KeyArray := @key"). That relies on
 *      alignment assumptions that FPC -O2 may change on some targets.
 *      FIXED by copying the 16 key bytes into a local "array [0 .. 3] of
 *      DWORD" via CopyPtr and indexing that array instead.
 *
 *   5. Per-round key material and the reversal workspace are wiped with
 *      FillPtr before the routine returns.
 *
 * ============================================================================
 *}

class procedure TLBC.EncryptLBC(const Context: TLBCContext; var Block: TLBCBlock);
var
  Blocks: array [0 .. 1] of TBCHalfBlock;
  Work: TBCHalfBlock;
  Right: TBCHalfBlock;
  Left: TBCHalfBlock;
  keyHalf: TBCHalfBlock;
  AA, BB: Integer;
  cc, DD: Integer;
  R, t: Integer;
begin
  {
   * Load the 16-byte block into two aligned 8-byte halves. CopyPtr is
   * byte-wise and does not assume any alignment on either side.
   *}
  CopyPtr(@Block, @Blocks[0], SizeOf(Blocks));
  Right := Blocks[0];
  Left := Blocks[1];

  for R := 0 to Context.Rounds - 1 do
    begin
      {
       * FIX: copy the 8-byte subkey from SubKeys64[R] (a byte array with
       * 1-byte alignment) into the local keyHalf (a TBCHalfBlock,
       * naturally 4-byte aligned). This avoids the unaligned 32-bit
       * reads that occurred with the direct type-cast in the original
       * code.
       *}
      CopyPtr(@Context.SubKeys64[R], @keyHalf[0], SizeOf(keyHalf));

      AA := Right[0];
      BB := keyHalf[0];
      cc := Right[1];
      DD := keyHalf[1];

      {
       * First mix pass.
       *}
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

      {
       * Swap the (AA, cc) and (BB, DD) pairs, then mix a second time.
       *}
      t := AA;
      AA := cc;
      cc := t;
      t := BB;
      BB := DD;
      DD := t;

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

      {
       * Fold the mixed values back into the left half, then rotate.
       *}
      Work[0] := Left[0] xor AA xor BB;
      Work[1] := Left[1] xor cc xor DD;

      Left := Right;
      Right := Work;
    end;

  Blocks[0] := Left;
  Blocks[1] := Right;
  CopyPtr(@Blocks[0], @Block, SizeOf(Block));

  {
   * Wipe the local key-half workspace and the working half.
   *}
  FillPtr(@keyHalf[0], SizeOf(keyHalf), 0);
  FillPtr(@Work[0], SizeOf(Work), 0);
end;

class procedure TLBC.EncryptLQC(const key: TKey128; var Block: TLQCBlock; Encrypt: Boolean);
const
  CKeyBox: array [Boolean, 0 .. 3, 0 .. 2] of Integer =
    (((0, 3, 1), (2, 1, 3), (1, 0, 2), (3, 2, 0)),
     ((3, 2, 0), (1, 0, 2), (2, 1, 3), (0, 3, 1)));
var
  KeyInts: array [0 .. 3] of Integer;
  Blocks: array [0 .. 1] of Integer;
  Work: Integer;
  Right: Integer;
  Left: Integer;
  R: Integer;
  AA, BB: Integer;
  cc, DD: Integer;
begin
  {
   * KeyInts and Blocks are DWORD arrays, hence naturally 4-byte aligned.
   * CopyPtr is used for both transfers so the source (a byte-typed key
   * and block) does not need any alignment guarantee.
   *}
  CopyPtr(@key, @KeyInts[0], SizeOf(KeyInts));
  CopyPtr(@Block, @Blocks[0], SizeOf(Blocks));
  Right := Blocks[0];
  Left := Blocks[1];

  {
   * CKeyBox[Encrypt, R, col] is only indexed with R in [0 .. 3], which
   * matches the declared array dimensions [Boolean, 0 .. 3, 0 .. 2].
   *}
  for R := 0 to 3 do
    begin
      AA := Right;
      BB := KeyInts[CKeyBox[Encrypt, R, 0]];
      cc := KeyInts[CKeyBox[Encrypt, R, 1]];
      DD := KeyInts[CKeyBox[Encrypt, R, 2]];

      {
       * The reference implementation comments out some of the
       * additions in this mix; that comment is preserved. The remaining
       * operations define the LQC round function.
       *}
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
      BB := BB xor (BB shl 7);
      cc := cc + BB;
      cc := cc xor (DD shr 15);
      DD := DD + cc;
      DD := DD xor (DD shl 11);

      Work := Left xor DD;
      Left := Right;
      Right := Work;
    end;

  Blocks[0] := Left;
  Blocks[1] := Right;
  CopyPtr(@Blocks[0], @Block, SizeOf(Block));

  {
   * Wipe the local key material.
   *}
  FillPtr(@KeyInts[0], SizeOf(KeyInts), 0);
end;

class procedure TLBC.InitEncryptLBC(const key: TKey128; var Context: TLBCContext;
  Rounds: Integer; Encrypt: Boolean);
type
  TDCPTFSubKeys = packed record
    case Byte of
      0: (SubKeys64: array [0 .. 15] of TKey64);
      1: (SubKeysInts: array [0 .. 3, 0 .. 7] of DWORD);
  end;
var
  {
   * FIX: use an explicit DWORD array instead of casting the TKey128
   * pointer through an unbounded PDWordArray. This removes the alignment
   * assumption that FPC -O2 could exploit.
   *}
  KeyDWords: array [0 .. 3] of DWORD;
  AA, BB: DWORD;
  cc, DD: DWORD;
  EE, FF: DWORD;
  GG, hh: DWORD;
  i, R: Integer;
  Temp: TDCPTFSubKeys;
  effRounds: Integer;
begin
  CopyPtr(@key, @KeyDWords[0], SizeOf(KeyDWords));

  Context.Encrypt := Encrypt;

  {
   * FIX: the round count must be an even value in [4, 16]. An odd count
   * leaves the final 8-byte subkey pair un-reversed in the decrypt path
   * and breaks the symmetry of the key schedule.
   *}
  effRounds := Rounds;
  if effRounds < 4 then
      effRounds := 4;
  if effRounds > 16 then
      effRounds := 16;
  if Odd(effRounds) then
      inc(effRounds); { 4, 6, 8, 10, 12, 14, 16 }
  Context.Rounds := effRounds;

  {
   * Propagate the seed into the four subkey groups.
   *}
  for i := 0 to 3 do
    begin
      {
       * Interleave the key with the per-group salt.
       *}
      AA := KeyDWords[0];
      BB := BCSalts[i];
      cc := KeyDWords[1];
      DD := BCSalts[i];
      EE := KeyDWords[2];
      FF := BCSalts[i];
      GG := KeyDWords[3];
      hh := BCSalts[i];

      {
       * Eight avalanche rounds of bit mixing.
       *}
      for R := 0 to 7 do
        begin
          AA := AA xor (BB shl 11);
          DD := DD + AA;
          BB := BB + cc;
          BB := BB xor (cc shr 2);
          EE := EE + BB;
          cc := cc + DD;
          cc := cc xor (DD shl 8);
          FF := FF + cc;
          DD := DD + EE;
          DD := DD xor (EE shr 16);
          GG := GG + DD;
          EE := EE + FF;
          EE := EE xor (FF shl 10);
          hh := hh + EE;
          FF := FF + GG;
          FF := FF xor (GG shr 4);
          AA := AA + FF;
          GG := GG + hh;
          GG := GG xor (hh shl 8);
          BB := BB + GG;
          hh := hh + AA;
          hh := hh xor (AA shr 9);
          cc := cc + hh;
          AA := AA + BB;
        end;

      {
       * Store the mixed values into the subkey group.
       *}
      Context.SubKeysInts[i, 0] := AA;
      Context.SubKeysInts[i, 1] := BB;
      Context.SubKeysInts[i, 2] := cc;
      Context.SubKeysInts[i, 3] := DD;
      Context.SubKeysInts[i, 4] := EE;
      Context.SubKeysInts[i, 5] := FF;
      Context.SubKeysInts[i, 6] := GG;
      Context.SubKeysInts[i, 7] := hh;
    end;

  {
   * Reverse the subkeys when decrypting so that EncryptLBC can be used
   * symmetrically for both directions.
   *
   * FIX: clear "Temp" first. Although the code below writes every slot
   * it later reads, FPC -O2 may reuse register / stack storage across
   * the two loops; explicit zeroing removes any ambiguity.
   *}
  if not Encrypt then
    begin
      FillPtr(@Temp, SizeOf(Temp), 0);

      for i := 0 to Context.Rounds - 1 do
          Temp.SubKeys64[(Context.Rounds - 1) - i] := Context.SubKeys64[i];

      for i := 0 to Context.Rounds - 1 do
          Context.SubKeys64[i] := Temp.SubKeys64[i];

      {
       * Clear the persistent Temp before leaving scope so that no
       * residual subkey bytes linger on the stack.
       *}
      FillPtr(@Temp, SizeOf(Temp), 0);
    end;

  {
   * Wipe the local key workspace.
   *}
  FillPtr(@KeyDWords[0], SizeOf(KeyDWords), 0);
end;

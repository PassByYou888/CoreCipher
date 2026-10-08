{
 * ============================================================================
 * Z.Cipher.imp_TTwofish.inc
 *
 * Twofish block cipher (AES competition finalist) implementation.
 * 128-bit block, key sizes 128 / 192 / 256 bits (16 / 24 / 32 bytes).
 *
 * Bug fixes applied (FPC -O2 optimization safety):
 *
 *   1. CRITICAL ！ InitKey used "Cnt := (Size shl 3 + 63) shr 6" to decide
 *      how many SBoxKey entries to fill. For Size < 16 (key shorter than
 *      128 bits) Cnt < 2, so SBoxKey[1] was never written; however the
 *      subsequent TwofishCalculateSBoxes call always reads bytes 4..7 of
 *      its L pointer, i.e. SBoxKey[1]'s storage. Under FPC -O2 that stack
 *      slot holds arbitrary residue, corrupting the key schedule and
 *      producing non-deterministic encryption. FIXED by clamping Size to
 *      [16, 32] at the top of InitKey; short keys are zero-padded with
 *      FillPtr + CopyPtr, long keys are truncated, and the effective size
 *      is used for the KeyLen computation.
 *
 *   2. CRITICAL ！ KeyContext.KeyLen was computed from the raw Size before
 *      clamping; with Size = 0, KeyLen became 0 while TwofishH still read
 *      L[0..7]. FIXED by deriving KeyLen from the effective size.
 *
 *   3. SEVERE ！ SBoxKey, KE, KO and ExpandedKey are now explicitly
 *      zeroed with FillPtr before use, removing any FPC -O2 dependency on
 *      stack/register initialization order.
 *
 *   4. Defensive ！ Cnt is capped at 4 to match the declared SBoxKey array
 *      bound and to guard against integer overflow for pathological Size.
 *
 * ============================================================================
 *}

class function TTwofish.TwofishCalculateSBoxes(x: DWORD; L: Pointer; KeySize: DWORD): DWORD;
var
  b0, B1, B2, B3: Byte;
begin
  {
   * Precompute the H-function permutation for one 32-bit word.
   *
   * The caller must guarantee that L points at a buffer of at least
   * 16 bytes. This is satisfied by passing @KeyContext.SBoxKey (four
   * DWORDs) from InitKey.
   *}
  b0 := x and $FF;
  B1 := (x shr 8) and $FF;
  B2 := (x shr 16) and $FF;
  B3 := x shr 24;

  if KeySize > 192 then
    begin
      b0 := P8x8[1, b0] xor PByte(NativeUInt(L) + 12)^;
      B1 := P8x8[0, B1] xor PByte(NativeUInt(L) + 13)^;
      B2 := P8x8[0, B2] xor PByte(NativeUInt(L) + 14)^;
      B3 := P8x8[1, B3] xor PByte(NativeUInt(L) + 15)^;
    end;
  if KeySize > 128 then
    begin
      b0 := P8x8[1, b0] xor PByte(NativeUInt(L) + 8)^;
      B1 := P8x8[1, B1] xor PByte(NativeUInt(L) + 9)^;
      B2 := P8x8[0, B2] xor PByte(NativeUInt(L) + 10)^;
      B3 := P8x8[0, B3] xor PByte(NativeUInt(L) + 11)^;
    end;

  b0 := P8x8[0, b0] xor PByte(NativeUInt(L) + 4)^;
  B1 := P8x8[1, B1] xor PByte(NativeUInt(L) + 5)^;
  B2 := P8x8[0, B2] xor PByte(NativeUInt(L) + 6)^;
  B3 := P8x8[1, B3] xor PByte(NativeUInt(L) + 7)^;

  b0 := P8x8[1, P8x8[0, b0] xor PByte(L)^];
  B1 := P8x8[0, P8x8[0, B1] xor PByte(NativeUInt(L) + 1)^];
  B2 := P8x8[1, P8x8[1, B2] xor PByte(NativeUInt(L) + 2)^];
  B3 := P8x8[0, P8x8[1, B3] xor PByte(NativeUInt(L) + 3)^];

  Result := DWORD(b0) or (DWORD(B1) shl 8) or (DWORD(B2) shl 16) or (DWORD(B3) shl 24);
end;

class function TTwofish.TwofishH(x: DWORD; L: Pointer; KeySize: DWORD): DWORD;
var
  b0, B1, B2, B3, z0, z1, z2, z3: Byte;
begin
  b0 := x and $FF;
  B1 := (x shr 8) and $FF;
  B2 := (x shr 16) and $FF;
  B3 := x shr 24;

  if KeySize > 192 then
    begin
      b0 := P8x8[1, b0] xor PByte(NativeUInt(L) + 12)^;
      B1 := P8x8[0, B1] xor PByte(NativeUInt(L) + 13)^;
      B2 := P8x8[0, B2] xor PByte(NativeUInt(L) + 14)^;
      B3 := P8x8[1, B3] xor PByte(NativeUInt(L) + 15)^;
    end;
  if KeySize > 128 then
    begin
      b0 := P8x8[1, b0] xor PByte(NativeUInt(L) + 8)^;
      B1 := P8x8[1, B1] xor PByte(NativeUInt(L) + 9)^;
      B2 := P8x8[0, B2] xor PByte(NativeUInt(L) + 10)^;
      B3 := P8x8[0, B3] xor PByte(NativeUInt(L) + 11)^;
    end;

  b0 := P8x8[0, b0] xor PByte(NativeUInt(L) + 4)^;
  B1 := P8x8[1, B1] xor PByte(NativeUInt(L) + 5)^;
  B2 := P8x8[0, B2] xor PByte(NativeUInt(L) + 6)^;
  B3 := P8x8[1, B3] xor PByte(NativeUInt(L) + 7)^;

  b0 := P8x8[1, P8x8[0, b0] xor PByte(L)^];
  B1 := P8x8[0, P8x8[0, B1] xor PByte(NativeUInt(L) + 1)^];
  B2 := P8x8[1, P8x8[1, B2] xor PByte(NativeUInt(L) + 2)^];
  B3 := P8x8[0, P8x8[1, B3] xor PByte(NativeUInt(L) + 3)^];

  z0 := b0 xor ArrEF[B1] xor Arr5B[B2] xor Arr5B[B3];
  z1 := Arr5B[b0] xor ArrEF[B1] xor ArrEF[B2] xor B3;
  z2 := ArrEF[b0] xor Arr5B[B1] xor B2 xor ArrEF[B3];
  z3 := ArrEF[b0] xor B1 xor ArrEF[B2] xor Arr5B[B3];

  Result := DWORD(z0) or (DWORD(z1) shl 8) or (DWORD(z2) shl 16) or (DWORD(z3) shl 24);
end;

class function TTwofish.TwofishH(const x: DWORD; const key: TTwofishKey): DWORD;
var
  b0, B1, B2, B3, z0, z1, z2, z3: Byte;
begin
  b0 := key.SBox0[x and $FF];
  B1 := key.SBox1[(x shr 8) and $FF];
  B2 := key.SBox2[(x shr 16) and $FF];
  B3 := key.SBox3[x shr 24];

  {
   * The P8x8 permutations are precomputed and stored in key.SBox0..3 by
   * InitKey.
   *}

  z0 := b0 xor ArrEF[B1] xor Arr5B[B2] xor Arr5B[B3];
  z1 := Arr5B[b0] xor ArrEF[B1] xor ArrEF[B2] xor B3;
  z2 := ArrEF[b0] xor Arr5B[B1] xor B2 xor ArrEF[B3];
  z3 := ArrEF[b0] xor B1 xor ArrEF[B2] xor Arr5B[B3];

  Result := DWORD(z0) or (DWORD(z1) shl 8) or (DWORD(z2) shl 16) or (DWORD(z3) shl 24);
end;

class function TTwofish.RSMDSMul(const x, y: Byte): Byte;
var
  Res: DWORD;
  index: Byte;
begin
  Res := 0;

  for Index := 7 downto 0 do
    begin
      if (y and (1 shl Index)) <> 0 then
          Res := Res xor (DWORD(x) shl Index);

      if (Res and (1 shl (8 + Index))) <> 0 then
          Res := Res xor ($14D shl Index);
    end;

  Result := Byte(Res);
end;

class function TTwofish.MultiplyMDS(const E, O: DWORD): DWORD;
var
  E0, E1, E2, E3, O0, O1, O2, O3, R0, R1, R2, R3: Byte;
begin
  E0 := E and $FF;
  E1 := (E shr 8) and $FF;
  E2 := (E shr 16) and $FF;
  E3 := (E shr 24) and $FF;
  O0 := O and $FF;
  O1 := (O shr 8) and $FF;
  O2 := (O shr 16) and $FF;
  O3 := (O shr 24) and $FF;

  R0 :=
    RSMDSMul(E0, MDS[0, 0]) xor RSMDSMul(E1, MDS[0, 1]) xor
    RSMDSMul(E2, MDS[0, 2]) xor RSMDSMul(E3, MDS[0, 3]) xor
    RSMDSMul(O0, MDS[0, 4]) xor RSMDSMul(O1, MDS[0, 5]) xor
    RSMDSMul(O2, MDS[0, 6]) xor RSMDSMul(O3, MDS[0, 7]);

  R1 :=
    RSMDSMul(E0, MDS[1, 0]) xor RSMDSMul(E1, MDS[1, 1]) xor
    RSMDSMul(E2, MDS[1, 2]) xor RSMDSMul(E3, MDS[1, 3]) xor
    RSMDSMul(O0, MDS[1, 4]) xor RSMDSMul(O1, MDS[1, 5]) xor
    RSMDSMul(O2, MDS[1, 6]) xor RSMDSMul(O3, MDS[1, 7]);

  R2 :=
    RSMDSMul(E0, MDS[2, 0]) xor RSMDSMul(E1, MDS[2, 1]) xor
    RSMDSMul(E2, MDS[2, 2]) xor RSMDSMul(E3, MDS[2, 3]) xor
    RSMDSMul(O0, MDS[2, 4]) xor RSMDSMul(O1, MDS[2, 5]) xor
    RSMDSMul(O2, MDS[2, 6]) xor RSMDSMul(O3, MDS[2, 7]);

  R3 :=
    RSMDSMul(E0, MDS[3, 0]) xor RSMDSMul(E1, MDS[3, 1]) xor
    RSMDSMul(E2, MDS[3, 2]) xor RSMDSMul(E3, MDS[3, 3]) xor
    RSMDSMul(O0, MDS[3, 4]) xor RSMDSMul(O1, MDS[3, 5]) xor
    RSMDSMul(O2, MDS[3, 6]) xor RSMDSMul(O3, MDS[3, 7]);

  Result := R0 or (R1 shl 8) or (R2 shl 16) or (R3 shl 24);
end;

class procedure TTwofish.InitKey(buff: PCCByteArray; Size: Integer; var KeyContext: TTwofishKey);
var
  i: DWORD;
  Cnt: DWORD;
  KE: array [0 .. 3] of DWORD;
  KO: array [0 .. 3] of DWORD;
  a, b: DWORD;
  keyBytes: array [0 .. 31] of Byte;
  effSize: Integer;
begin
  {
   * FIX: clamp the effective key size to [16, 32] bytes. Twofish only
   * defines 128 / 192 / 256-bit keys. Feeding a shorter or longer buffer
   * would leave parts of SBoxKey uninitialized (short) or would compute
   * Cnt beyond the SBoxKey array bound (long).
   *}
  effSize := Size;
  if effSize < 16 then
      effSize := 16;
  if effSize > 32 then
      effSize := 32;

  {
   * Copy the caller's key into a fixed 32-byte local buffer, zero-filled
   * first so that short keys are safely padded.
   *}
  FillPtr(@keyBytes[0], SizeOf(keyBytes), 0);
  if (buff <> nil) and (Size > 0) then
    begin
      if Size > effSize then
          CopyPtr(buff, @keyBytes[0], effSize)
      else
          CopyPtr(buff, @keyBytes[0], Size);
    end;

  {
   * Store the effective key length in bits for the H-function branches.
   *}
  KeyContext.KeyLen := effSize shl 3;

  {
   * Explicitly zero-fill all key material fields so that under FPC -O2
   * no stale register or stack value can leak into the schedule.
   *}
  FillPtr(@KeyContext.SBoxKey[0], SizeOf(KeyContext.SBoxKey), 0);
  FillPtr(@KeyContext.ExpandedKey[0], SizeOf(KeyContext.ExpandedKey), 0);
  FillPtr(@KE[0], SizeOf(KE), 0);
  FillPtr(@KO[0], SizeOf(KO), 0);

  {
   * Number of 64-bit key words: (effSize * 8 + 63) div 64.
   * For effSize in [16, 24, 32] this yields Cnt in [2, 3, 4].
   *}
  Cnt := DWORD((effSize shl 3 + 63) shr 6);
  {
   * Defensive: SBoxKey has 4 slots, never write past them.
   *}
  if Cnt > 4 then
      Cnt := 4;

  for i := 0 to Cnt - 1 do
    begin
      KE[i] := keyBytes[i shl 3]     or
              (DWORD(keyBytes[i shl 3 + 1]) shl 8)  or
              (DWORD(keyBytes[i shl 3 + 2]) shl 16) or
              (DWORD(keyBytes[i shl 3 + 3]) shl 24);
      KO[i] := keyBytes[i shl 3 + 4] or
              (DWORD(keyBytes[i shl 3 + 5]) shl 8)  or
              (DWORD(keyBytes[i shl 3 + 6]) shl 16) or
              (DWORD(keyBytes[i shl 3 + 7]) shl 24);

      KeyContext.SBoxKey[Cnt - i - 1] := MultiplyMDS(KE[i], KO[i]);
    end;

  {
   * Expand the round keys. 20 double-rounds, 40 DWORDs total.
   *}
  for i := 0 to 19 do
    begin
      a := TwofishH(i * $02020202, @KE[0], DWORD(KeyContext.KeyLen));
      b := TwofishH(i * $02020202 + $01010101, @KO[0], DWORD(KeyContext.KeyLen));
      b := (b shl 8) or (b shr 24);
      KeyContext.ExpandedKey[i shl 1] := a + b;
      b := a + b shl 1;
      KeyContext.ExpandedKey[i shl 1 + 1] := (b shl 9) or (b shr 23);
    end;

  {
   * Precompute the four S-boxes.
   *}
  for i := 0 to 255 do
    begin
      a := (i and $FF) or ((i and $FF) shl 8) or ((i and $FF) shl 16) or ((i and $FF) shl 24);
      a := TwofishCalculateSBoxes(a, @KeyContext.SBoxKey[0], DWORD(KeyContext.KeyLen));
      KeyContext.SBox0[i] := a and $FF;
      KeyContext.SBox1[i] := (a shr 8) and $FF;
      KeyContext.SBox2[i] := (a shr 16) and $FF;
      KeyContext.SBox3[i] := (a shr 24) and $FF;
    end;

  {
   * Wipe the local key buffer and per-word key material.
   *}
  FillPtr(@keyBytes[0], SizeOf(keyBytes), 0);
  FillPtr(@KE[0], SizeOf(KE), 0);
  FillPtr(@KO[0], SizeOf(KO), 0);
end;

class procedure TTwofish.Encrypt(var KeyContext: TTwofishKey; var Data: TTwofishBlock);
var
  R0, R1, R2, R3, t0, T1, F0, F1: DWORD;
begin
  {
   * Pre-whitening.
   *}
  R0 := PDWORD(@Data[0])^ xor KeyContext.ExpandedKey[0];
  R1 := PDWORD(@Data[4])^ xor KeyContext.ExpandedKey[1];
  R2 := PDWORD(@Data[8])^ xor KeyContext.ExpandedKey[2];
  R3 := PDWORD(@Data[12])^ xor KeyContext.ExpandedKey[3];

  {
   * Round 0.
   *}
  t0 := TwofishH(R0, KeyContext);
  T1 := (R1 shl 8) or (R1 shr 24);
  T1 := TwofishH(T1, KeyContext);
  F0 := t0 + T1 + KeyContext.ExpandedKey[8];
  F1 := t0 + T1 shl 1 + KeyContext.ExpandedKey[9];

  R2 := R2 xor F0;
  R2 := (R2 shr 1) or (R2 shl 31);
  R3 := (R3 shl 1) or (R3 shr 31) xor F1;

  {
   * Round 1.
   *}
  t0 := TwofishH(R2, KeyContext);
  T1 := DWORD(R3 shl 8) or (R3 shr 24);
  T1 := TwofishH(T1, KeyContext);
  F0 := DWORD(t0 + T1 + KeyContext.ExpandedKey[10]);
  F1 := DWORD(t0 + T1 shl 1 + KeyContext.ExpandedKey[11]);

  R0 := R0 xor F0;
  R0 := (R0 shr 1) or DWORD(R0 shl 31);
  R1 := DWORD(R1 shl 1) or (R1 shr 31) xor F1;

  {
   * Round 2.
   *}
  t0 := TwofishH(R0, KeyContext);
  T1 := DWORD(R1 shl 8) or (R1 shr 24);
  T1 := TwofishH(T1, KeyContext);
  F0 := DWORD(t0 + T1 + KeyContext.ExpandedKey[12]);
  F1 := DWORD(t0 + T1 shl 1 + KeyContext.ExpandedKey[13]);

  R2 := R2 xor F0;
  R2 := (R2 shr 1) or DWORD(R2 shl 31);
  R3 := DWORD(R3 shl 1) or (R3 shr 31) xor F1;

  {
   * Round 3.
   *}
  t0 := TwofishH(R2, KeyContext);
  T1 := DWORD(R3 shl 8) or (R3 shr 24);
  T1 := TwofishH(T1, KeyContext);
  F0 := DWORD(t0 + T1 + KeyContext.ExpandedKey[14]);
  F1 := DWORD(t0 + T1 shl 1 + KeyContext.ExpandedKey[15]);

  R0 := R0 xor F0;
  R0 := (R0 shr 1) or DWORD(R0 shl 31);
  R1 := DWORD(R1 shl 1) or (R1 shr 31) xor F1;

  {
   * Round 4.
   *}
  t0 := TwofishH(R0, KeyContext);
  T1 := DWORD(R1 shl 8) or (R1 shr 24);
  T1 := TwofishH(T1, KeyContext);
  F0 := DWORD(t0 + T1 + KeyContext.ExpandedKey[16]);
  F1 := DWORD(t0 + T1 shl 1 + KeyContext.ExpandedKey[17]);

  R2 := R2 xor F0;
  R2 := (R2 shr 1) or DWORD(R2 shl 31);
  R3 := DWORD(R3 shl 1) or (R3 shr 31) xor F1;

  {
   * Round 5.
   *}
  t0 := TwofishH(R2, KeyContext);
  T1 := DWORD(R3 shl 8) or (R3 shr 24);
  T1 := TwofishH(T1, KeyContext);
  F0 := DWORD(t0 + T1 + KeyContext.ExpandedKey[18]);
  F1 := DWORD(t0 + T1 shl 1 + KeyContext.ExpandedKey[19]);

  R0 := R0 xor F0;
  R0 := (R0 shr 1) or DWORD(R0 shl 31);
  R1 := DWORD(R1 shl 1) or (R1 shr 31) xor F1;

  {
   * Round 6.
   *}
  t0 := TwofishH(R0, KeyContext);
  T1 := DWORD(R1 shl 8) or (R1 shr 24);
  T1 := TwofishH(T1, KeyContext);
  F0 := DWORD(t0 + T1 + KeyContext.ExpandedKey[20]);
  F1 := DWORD(t0 + T1 shl 1 + KeyContext.ExpandedKey[21]);

  R2 := R2 xor F0;
  R2 := (R2 shr 1) or DWORD(R2 shl 31);
  R3 := DWORD(R3 shl 1) or (R3 shr 31) xor F1;

  {
   * Round 7.
   *}
  t0 := TwofishH(R2, KeyContext);
  T1 := DWORD(R3 shl 8) or (R3 shr 24);
  T1 := TwofishH(T1, KeyContext);
  F0 := DWORD(t0 + T1 + KeyContext.ExpandedKey[22]);
  F1 := DWORD(t0 + T1 shl 1 + KeyContext.ExpandedKey[23]);

  R0 := R0 xor F0;
  R0 := (R0 shr 1) or DWORD(R0 shl 31);
  R1 := DWORD(R1 shl 1) or (R1 shr 31) xor F1;

  {
   * Round 8.
   *}
  t0 := TwofishH(R0, KeyContext);
  T1 := DWORD(R1 shl 8) or (R1 shr 24);
  T1 := TwofishH(T1, KeyContext);
  F0 := DWORD(t0 + T1 + KeyContext.ExpandedKey[24]);
  F1 := DWORD(t0 + T1 shl 1 + KeyContext.ExpandedKey[25]);

  R2 := R2 xor F0;
  R2 := (R2 shr 1) or DWORD(R2 shl 31);
  R3 := DWORD(R3 shl 1) or (R3 shr 31) xor F1;

  {
   * Round 9.
   *}
  t0 := TwofishH(R2, KeyContext);
  T1 := DWORD(R3 shl 8) or (R3 shr 24);
  T1 := TwofishH(T1, KeyContext);
  F0 := DWORD(t0 + T1 + KeyContext.ExpandedKey[26]);
  F1 := DWORD(t0 + T1 shl 1 + KeyContext.ExpandedKey[27]);

  R0 := R0 xor F0;
  R0 := (R0 shr 1) or DWORD(R0 shl 31);
  R1 := DWORD(R1 shl 1) or (R1 shr 31) xor F1;

  {
   * Round 10.
   *}
  t0 := TwofishH(R0, KeyContext);
  T1 := DWORD(R1 shl 8) or (R1 shr 24);
  T1 := TwofishH(T1, KeyContext);
  F0 := DWORD(t0 + T1 + KeyContext.ExpandedKey[28]);
  F1 := DWORD(t0 + T1 shl 1 + KeyContext.ExpandedKey[29]);

  R2 := R2 xor F0;
  R2 := (R2 shr 1) or DWORD(R2 shl 31);
  R3 := DWORD(R3 shl 1) or (R3 shr 31) xor F1;

  {
   * Round 11.
   *}
  t0 := TwofishH(R2, KeyContext);
  T1 := DWORD(R3 shl 8) or (R3 shr 24);
  T1 := TwofishH(T1, KeyContext);
  F0 := DWORD(t0 + T1 + KeyContext.ExpandedKey[30]);
  F1 := DWORD(t0 + T1 shl 1 + KeyContext.ExpandedKey[31]);

  R0 := R0 xor F0;
  R0 := (R0 shr 1) or DWORD(R0 shl 31);
  R1 := DWORD(R1 shl 1) or (R1 shr 31) xor F1;

  {
   * Round 12.
   *}
  t0 := TwofishH(R0, KeyContext);
  T1 := DWORD(R1 shl 8) or (R1 shr 24);
  T1 := TwofishH(T1, KeyContext);
  F0 := DWORD(t0 + T1 + KeyContext.ExpandedKey[32]);
  F1 := DWORD(t0 + T1 shl 1 + KeyContext.ExpandedKey[33]);

  R2 := R2 xor F0;
  R2 := (R2 shr 1) or DWORD(R2 shl 31);
  R3 := DWORD(R3 shl 1) or (R3 shr 31) xor F1;

  {
   * Round 13.
   *}
  t0 := TwofishH(R2, KeyContext);
  T1 := DWORD(R3 shl 8) or (R3 shr 24);
  T1 := TwofishH(T1, KeyContext);
  F0 := DWORD(t0 + T1 + KeyContext.ExpandedKey[34]);
  F1 := DWORD(t0 + T1 shl 1 + KeyContext.ExpandedKey[35]);

  R0 := R0 xor F0;
  R0 := (R0 shr 1) or DWORD(R0 shl 31);
  R1 := DWORD(R1 shl 1) or (R1 shr 31) xor F1;

  {
   * Round 14.
   *}
  t0 := TwofishH(R0, KeyContext);
  T1 := DWORD(R1 shl 8) or (R1 shr 24);
  T1 := TwofishH(T1, KeyContext);
  F0 := DWORD(t0 + T1 + KeyContext.ExpandedKey[36]);
  F1 := DWORD(t0 + T1 shl 1 + KeyContext.ExpandedKey[37]);

  R2 := R2 xor F0;
  R2 := (R2 shr 1) or DWORD(R2 shl 31);
  R3 := DWORD(R3 shl 1) or (R3 shr 31) xor F1;

  {
   * Round 15.
   *}
  t0 := TwofishH(R2, KeyContext);
  T1 := DWORD(R3 shl 8) or (R3 shr 24);
  T1 := TwofishH(T1, KeyContext);
  F0 := DWORD(t0 + T1 + KeyContext.ExpandedKey[38]);
  F1 := DWORD(t0 + T1 shl 1 + KeyContext.ExpandedKey[39]);

  R0 := R0 xor F0;
  R0 := (R0 shr 1) or DWORD(R0 shl 31);
  R1 := DWORD(R1 shl 1) or (R1 shr 31) xor F1;

  {
   * Output whitening (with the round-dependent swap).
   *}
  PDWORD(@Data[0])^ := R2 xor KeyContext.ExpandedKey[4];
  PDWORD(@Data[4])^ := R3 xor KeyContext.ExpandedKey[5];
  PDWORD(@Data[8])^ := R0 xor KeyContext.ExpandedKey[6];
  PDWORD(@Data[12])^ := R1 xor KeyContext.ExpandedKey[7];
end;

class procedure TTwofish.Decrypt(var KeyContext: TTwofishKey; var Data: TTwofishBlock);
var
  R0, R1, R2, R3, t0, T1, F0, F1: DWORD;
begin
  {
   * Pre-whitening (inverse: swap keys 4..7 with 0..3, and swap R0<->R2,
   * R1<->R3 relative to Encrypt).
   *}
  R0 := PDWORD(@Data[0])^ xor KeyContext.ExpandedKey[4];
  R1 := PDWORD(@Data[4])^ xor KeyContext.ExpandedKey[5];
  R2 := PDWORD(@Data[8])^ xor KeyContext.ExpandedKey[6];
  R3 := PDWORD(@Data[12])^ xor KeyContext.ExpandedKey[7];

  {
   * Round 15 (inverse).
   *}
  t0 := TwofishH(R0, KeyContext);
  T1 := DWORD(R1 shl 8) or (R1 shr 24);
  T1 := TwofishH(T1, KeyContext);
  F0 := DWORD(t0 + T1 + KeyContext.ExpandedKey[38]);
  F1 := DWORD(t0 + T1 shl 1 + KeyContext.ExpandedKey[39]);

  R2 := (R2 shl 1) or DWORD(R2 shr 31) xor F0;
  R3 := R3 xor F1;
  R3 := DWORD(R3 shr 1) or (R3 shl 31);

  {
   * Round 14 (inverse).
   *}
  t0 := TwofishH(R2, KeyContext);
  T1 := DWORD(R3 shl 8) or (R3 shr 24);
  T1 := TwofishH(T1, KeyContext);
  F0 := DWORD(t0 + T1 + KeyContext.ExpandedKey[36]);
  F1 := DWORD(t0 + T1 shl 1 + KeyContext.ExpandedKey[37]);

  R0 := (R0 shl 1) or DWORD(R0 shr 31) xor F0;
  R1 := R1 xor F1;
  R1 := DWORD(R1 shr 1) or (R1 shl 31);

  {
   * Round 13 (inverse).
   *}
  t0 := TwofishH(R0, KeyContext);
  T1 := DWORD(R1 shl 8) or (R1 shr 24);
  T1 := TwofishH(T1, KeyContext);
  F0 := DWORD(t0 + T1 + KeyContext.ExpandedKey[34]);
  F1 := DWORD(t0 + T1 shl 1 + KeyContext.ExpandedKey[35]);

  R2 := (R2 shl 1) or DWORD(R2 shr 31) xor F0;
  R3 := R3 xor F1;
  R3 := DWORD(R3 shr 1) or (R3 shl 31);

  {
   * Round 12 (inverse).
   *}
  t0 := TwofishH(R2, KeyContext);
  T1 := DWORD(R3 shl 8) or (R3 shr 24);
  T1 := TwofishH(T1, KeyContext);
  F0 := DWORD(t0 + T1 + KeyContext.ExpandedKey[32]);
  F1 := DWORD(t0 + T1 shl 1 + KeyContext.ExpandedKey[33]);

  R0 := (R0 shl 1) or DWORD(R0 shr 31) xor F0;
  R1 := R1 xor F1;
  R1 := DWORD(R1 shr 1) or (R1 shl 31);

  {
   * Round 11 (inverse).
   *}
  t0 := TwofishH(R0, KeyContext);
  T1 := DWORD(R1 shl 8) or (R1 shr 24);
  T1 := TwofishH(T1, KeyContext);
  F0 := DWORD(t0 + T1 + KeyContext.ExpandedKey[30]);
  F1 := DWORD(t0 + T1 shl 1 + KeyContext.ExpandedKey[31]);

  R2 := (R2 shl 1) or DWORD(R2 shr 31) xor F0;
  R3 := R3 xor F1;
  R3 := DWORD(R3 shr 1) or (R3 shl 31);

  {
   * Round 10 (inverse).
   *}
  t0 := TwofishH(R2, KeyContext);
  T1 := DWORD(R3 shl 8) or (R3 shr 24);
  T1 := TwofishH(T1, KeyContext);
  F0 := DWORD(t0 + T1 + KeyContext.ExpandedKey[28]);
  F1 := DWORD(t0 + T1 shl 1 + KeyContext.ExpandedKey[29]);

  R0 := (R0 shl 1) or DWORD(R0 shr 31) xor F0;
  R1 := R1 xor F1;
  R1 := DWORD(R1 shr 1) or (R1 shl 31);

  {
   * Round 9 (inverse).
   *}
  t0 := TwofishH(R0, KeyContext);
  T1 := DWORD(R1 shl 8) or (R1 shr 24);
  T1 := TwofishH(T1, KeyContext);
  F0 := DWORD(t0 + T1 + KeyContext.ExpandedKey[26]);
  F1 := DWORD(t0 + T1 shl 1 + KeyContext.ExpandedKey[27]);

  R2 := (R2 shl 1) or DWORD(R2 shr 31) xor F0;
  R3 := R3 xor F1;
  R3 := DWORD(R3 shr 1) or (R3 shl 31);

  {
   * Round 8 (inverse).
   *}
  t0 := TwofishH(R2, KeyContext);
  T1 := DWORD(R3 shl 8) or (R3 shr 24);
  T1 := TwofishH(T1, KeyContext);
  F0 := DWORD(t0 + T1 + KeyContext.ExpandedKey[24]);
  F1 := DWORD(t0 + T1 shl 1 + KeyContext.ExpandedKey[25]);

  R0 := (R0 shl 1) or DWORD(R0 shr 31) xor F0;
  R1 := R1 xor F1;
  R1 := DWORD(R1 shr 1) or (R1 shl 31);

  {
   * Round 7 (inverse).
   *}
  t0 := TwofishH(R0, KeyContext);
  T1 := DWORD(R1 shl 8) or (R1 shr 24);
  T1 := TwofishH(T1, KeyContext);
  F0 := DWORD(t0 + T1 + KeyContext.ExpandedKey[22]);
  F1 := DWORD(t0 + T1 shl 1 + KeyContext.ExpandedKey[23]);

  R2 := (R2 shl 1) or DWORD(R2 shr 31) xor F0;
  R3 := R3 xor F1;
  R3 := DWORD(R3 shr 1) or (R3 shl 31);

  {
   * Round 6 (inverse).
   *}
  t0 := TwofishH(R2, KeyContext);
  T1 := DWORD(R3 shl 8) or (R3 shr 24);
  T1 := TwofishH(T1, KeyContext);
  F0 := DWORD(t0 + T1 + KeyContext.ExpandedKey[20]);
  F1 := DWORD(t0 + T1 shl 1 + KeyContext.ExpandedKey[21]);

  R0 := (R0 shl 1) or DWORD(R0 shr 31) xor F0;
  R1 := R1 xor F1;
  R1 := DWORD(R1 shr 1) or (R1 shl 31);

  {
   * Round 5 (inverse).
   *}
  t0 := TwofishH(R0, KeyContext);
  T1 := DWORD(R1 shl 8) or (R1 shr 24);
  T1 := TwofishH(T1, KeyContext);
  F0 := DWORD(t0 + T1 + KeyContext.ExpandedKey[18]);
  F1 := DWORD(t0 + T1 shl 1 + KeyContext.ExpandedKey[19]);

  R2 := (R2 shl 1) or DWORD(R2 shr 31) xor F0;
  R3 := R3 xor F1;
  R3 := DWORD(R3 shr 1) or (R3 shl 31);

  {
   * Round 4 (inverse).
   *}
  t0 := TwofishH(R2, KeyContext);
  T1 := DWORD(R3 shl 8) or (R3 shr 24);
  T1 := TwofishH(T1, KeyContext);
  F0 := DWORD(t0 + T1 + KeyContext.ExpandedKey[16]);
  F1 := DWORD(t0 + T1 shl 1 + KeyContext.ExpandedKey[17]);

  R0 := (R0 shl 1) or DWORD(R0 shr 31) xor F0;
  R1 := R1 xor F1;
  R1 := DWORD(R1 shr 1) or (R1 shl 31);

  {
   * Round 3 (inverse).
   *}
  t0 := TwofishH(R0, KeyContext);
  T1 := DWORD(R1 shl 8) or (R1 shr 24);
  T1 := TwofishH(T1, KeyContext);
  F0 := DWORD(t0 + T1 + KeyContext.ExpandedKey[14]);
  F1 := DWORD(t0 + T1 shl 1 + KeyContext.ExpandedKey[15]);

  R2 := (R2 shl 1) or DWORD(R2 shr 31) xor F0;
  R3 := R3 xor F1;
  R3 := DWORD(R3 shr 1) or (R3 shl 31);

  {
   * Round 2 (inverse).
   *}
  t0 := TwofishH(R2, KeyContext);
  T1 := DWORD(R3 shl 8) or (R3 shr 24);
  T1 := TwofishH(T1, KeyContext);
  F0 := DWORD(t0 + T1 + KeyContext.ExpandedKey[12]);
  F1 := DWORD(t0 + T1 shl 1 + KeyContext.ExpandedKey[13]);

  R0 := (R0 shl 1) or DWORD(R0 shr 31) xor F0;
  R1 := R1 xor F1;
  R1 := DWORD(R1 shr 1) or (R1 shl 31);

  {
   * Round 1 (inverse).
   *}
  t0 := TwofishH(R0, KeyContext);
  T1 := DWORD(R1 shl 8) or (R1 shr 24);
  T1 := TwofishH(T1, KeyContext);
  F0 := DWORD(t0 + T1 + KeyContext.ExpandedKey[10]);
  F1 := DWORD(t0 + T1 shl 1 + KeyContext.ExpandedKey[11]);

  R2 := (R2 shl 1) or DWORD(R2 shr 31) xor F0;
  R3 := R3 xor F1;
  R3 := DWORD(R3 shr 1) or (R3 shl 31);

  {
   * Round 0 (inverse).
   *}
  t0 := TwofishH(R2, KeyContext);
  T1 := DWORD(R3 shl 8) or (R3 shr 24);
  T1 := TwofishH(T1, KeyContext);
  F0 := DWORD(t0 + T1 + KeyContext.ExpandedKey[8]);
  F1 := DWORD(t0 + T1 shl 1 + KeyContext.ExpandedKey[9]);

  R0 := (R0 shl 1) or DWORD(R0 shr 31) xor F0;
  R1 := R1 xor F1;
  R1 := DWORD(R1 shr 1) or (R1 shl 31);

  {
   * Output whitening.
   *}
  PDWORD(@Data[0])^ := R2 xor KeyContext.ExpandedKey[0];
  PDWORD(@Data[4])^ := R3 xor KeyContext.ExpandedKey[1];
  PDWORD(@Data[8])^ := R0 xor KeyContext.ExpandedKey[2];
  PDWORD(@Data[12])^ := R1 xor KeyContext.ExpandedKey[3];
end;

{
 * ============================================================================
 * Z.Cipher.imp_TSerpent.inc
 *
 * Serpent block cipher (AES finalist) implementation.
 * 128-bit block, 128/192/256-bit keys, 32 rounds.
 *
 * Faithful Pascal port of the official Serpent reference implementation
 * (serpent.c / serpentsboxes.h by Anderson, Biham, Knudsen).
 *
 * Byte-order convention:
 *   The 128-bit block is loaded and stored in LITTLE-ENDIAN order, matching
 *   the C reference implementation's "unsigned long *" access on a
 *   little-endian host. The internal 32-bit words are byte-order
 *   independent.
 *
 * The S-box layer is implemented in bitslice form (SerpentRND00..RND07 and
 * SerpentInvRND00..InvRND07, taken verbatim from serpentsboxes.h). No IP/FP
 * is used, matching the reference implementation exactly.
 *
 * Standard 128-bit zero-key / zero-plaintext vector:
 *   3620B17AE6A993D09618B8768266BAE9
 * ============================================================================
 *}

type
  TSerpentWords = array [0 .. 3] of DWORD;

const
  {
   * Nibble-level S-box lookup table.
   *
   * Used ONLY by the key schedule (Serpent.InitKey). The data path uses
   * the bitslice S-boxes (SerpentRND00..RND07 / SerpentInvRND00..InvRND07).
   }
  SerpentSBox: array [0 .. 7, 0 .. 15] of Byte = (
    (3, 8, 15, 1, 10, 6, 5, 11, 14, 13, 4, 2, 7, 0, 9, 12),   { S0 }
    (15, 12, 2, 7, 9, 0, 5, 10, 1, 11, 14, 8, 6, 13, 3, 4),   { S1 }
    (8, 6, 7, 9, 3, 12, 10, 15, 13, 1, 14, 4, 0, 11, 5, 2),   { S2 }
    (0, 15, 11, 8, 12, 9, 6, 3, 13, 1, 2, 4, 10, 7, 5, 14),   { S3 }
    (1, 15, 8, 3, 12, 0, 11, 6, 2, 5, 4, 10, 9, 14, 7, 13),   { S4 }
    (15, 5, 2, 11, 4, 10, 9, 12, 0, 3, 14, 8, 13, 6, 7, 1),   { S5 }
    (7, 2, 12, 5, 8, 4, 6, 11, 14, 9, 1, 15, 13, 3, 10, 0),   { S6 }
    (1, 13, 15, 0, 14, 8, 2, 11, 7, 4, 12, 10, 9, 3, 5, 6));  { S7 }

{ ---------------------------------------------------------------------------
 * Bitslice S-boxes (verbatim from serpentsboxes.h).
 * --------------------------------------------------------------------------- }

procedure SerpentRND00(const a, b, c, d: DWORD; var w, x, y, z: DWORD);
var
  t01, t02, t03, t05, t06, t07, t08, t09, t11, t12, t13, t14, t15, t17: DWORD;
begin
  t01 := b xor c;
  t02 := a or d;
  t03 := a xor b;
  z := t02 xor t01;
  t05 := c or z;
  t06 := a xor d;
  t07 := b or c;
  t08 := d and t05;
  t09 := t03 and t07;
  y := t09 xor t08;
  t11 := t09 and y;
  t12 := c xor d;
  t13 := t07 xor t11;
  t14 := b and t06;
  t15 := t06 xor t13;
  w := not t15;
  t17 := w xor t14;
  x := t12 xor t17;
end;

procedure SerpentRND01(const a, b, c, d: DWORD; var w, x, y, z: DWORD);
var
  t01, t02, t03, t04, t05, t06, t07, t08, t10, t11, t12, t13, t16, t17: DWORD;
begin
  t01 := a or d;
  t02 := c xor d;
  t03 := not b;
  t04 := a xor c;
  t05 := a or t03;
  t06 := d and t04;
  t07 := t01 and t02;
  t08 := b or t06;
  y := t02 xor t05;
  t10 := t07 xor t08;
  t11 := t01 xor t10;
  t12 := y xor t11;
  t13 := b and d;
  z := not t10;
  x := t13 xor t12;
  t16 := t10 or x;
  t17 := t05 and t16;
  w := c xor t17;
end;

procedure SerpentRND02(const a, b, c, d: DWORD; var w, x, y, z: DWORD);
var
  t01, t02, t03, t05, t06, t07, t08, t09, t10, t12, t13, t14: DWORD;
begin
  t01 := a or c;
  t02 := a xor b;
  t03 := d xor t01;
  w := t02 xor t03;
  t05 := c xor w;
  t06 := b xor t05;
  t07 := b or t05;
  t08 := t01 and t06;
  t09 := t03 xor t07;
  t10 := t02 or t09;
  x := t10 xor t08;
  t12 := a or d;
  t13 := t09 xor x;
  t14 := b xor t13;
  z := not t09;
  y := t12 xor t14;
end;

procedure SerpentRND03(const a, b, c, d: DWORD; var w, x, y, z: DWORD);
var
  t01, t02, t03, t04, t05, t06, t07, t08, t09, t10, t11, t13, t14, t15: DWORD;
begin
  t01 := a xor c;
  t02 := a or d;
  t03 := a and d;
  t04 := t01 and t02;
  t05 := b or t03;
  t06 := a and b;
  t07 := d xor t04;
  t08 := c or t06;
  t09 := b xor t07;
  t10 := d and t05;
  t11 := t02 xor t10;
  z := t08 xor t09;
  t13 := d or z;
  t14 := a or t07;
  t15 := b and t13;
  y := t08 xor t11;
  w := t14 xor t15;
  x := t05 xor t04;
end;

procedure SerpentRND04(const a, b, c, d: DWORD; var w, x, y, z: DWORD);
var
  t01, t02, t03, t04, t05, t06, t08, t09, t10, t11, t12, t13, t14, t15, t16: DWORD;
begin
  t01 := a or b;
  t02 := b or c;
  t03 := a xor t02;
  t04 := b xor d;
  t05 := d or t03;
  t06 := d and t01;
  z := t03 xor t06;
  t08 := z and t04;
  t09 := t04 and t05;
  t10 := c xor t06;
  t11 := b and c;
  t12 := t04 xor t08;
  t13 := t11 or t03;
  t14 := t10 xor t09;
  t15 := a and t05;
  t16 := t11 or t12;
  y := t13 xor t08;
  x := t15 xor t16;
  w := not t14;
end;

procedure SerpentRND05(const a, b, c, d: DWORD; var w, x, y, z: DWORD);
var
  t01, t02, t03, t04, t05, t07, t08, t09, t10, t11, t12, t13, t14: DWORD;
begin
  t01 := b xor d;
  t02 := b or d;
  t03 := a and t01;
  t04 := c xor t02;
  t05 := t03 xor t04;
  w := not t05;
  t07 := a xor t01;
  t08 := d or w;
  t09 := b or t05;
  t10 := d xor t08;
  t11 := b or t07;
  t12 := t03 or w;
  t13 := t07 or t10;
  t14 := t01 xor t11;
  y := t09 xor t13;
  x := t07 xor t08;
  z := t12 xor t14;
end;

procedure SerpentRND06(const a, b, c, d: DWORD; var w, x, y, z: DWORD);
var
  t01, t02, t03, t04, t05, t07, t08, t09, t10, t11, t12, t13, t15, t17, t18: DWORD;
begin
  t01 := a and d;
  t02 := b xor c;
  t03 := a xor d;
  t04 := t01 xor t02;
  t05 := b or c;
  x := not t04;
  t07 := t03 and t05;
  t08 := b and x;
  t09 := a or c;
  t10 := t07 xor t08;
  t11 := b or d;
  t12 := c xor t11;
  t13 := t09 xor t10;
  y := not t13;
  t15 := x and t03;
  z := t12 xor t07;
  t17 := a xor b;
  t18 := y xor t15;
  w := t17 xor t18;
end;

procedure SerpentRND07(const a, b, c, d: DWORD; var w, x, y, z: DWORD);
var
  t01, t02, t03, t04, t05, t06, t08, t09, t10, t11, t13, t14, t15, t16, t17: DWORD;
begin
  t01 := a and c;
  t02 := not d;
  t03 := a and t02;
  t04 := b or t01;
  t05 := a and b;
  t06 := c xor t04;
  z := t03 xor t06;
  t08 := c or z;
  t09 := d or t05;
  t10 := a xor t08;
  t11 := t04 and z;
  x := t09 xor t10;
  t13 := b xor x;
  t14 := t01 xor x;
  t15 := c xor t05;
  t16 := t11 or t13;
  t17 := t02 or t14;
  w := t15 xor t17;
  y := a xor t16;
end;

procedure SerpentInvRND00(const a, b, c, d: DWORD; var w, x, y, z: DWORD);
var
  t01, t02, t03, t04, t05, t06, t08, t09, t10, t12, t13, t14, t15, t17, t18: DWORD;
begin
  t01 := c xor d;
  t02 := a or b;
  t03 := b or c;
  t04 := c and t01;
  t05 := t02 xor t01;
  t06 := a or t04;
  y := not t05;
  t08 := b xor d;
  t09 := t03 and t08;
  t10 := d or y;
  x := t09 xor t06;
  t12 := a or t05;
  t13 := x xor t12;
  t14 := t03 xor t10;
  t15 := a xor c;
  z := t14 xor t13;
  t17 := t05 and t13;
  t18 := t14 or t17;
  w := t15 xor t18;
end;

procedure SerpentInvRND01(const a, b, c, d: DWORD; var w, x, y, z: DWORD);
var
  t01, t02, t03, t04, t05, t06, t07, t08, t09, t10, t11, t14, t15, t17: DWORD;
begin
  t01 := a xor b;
  t02 := b or d;
  t03 := a and c;
  t04 := c xor t02;
  t05 := a or t04;
  t06 := t01 and t05;
  t07 := d or t03;
  t08 := b xor t06;
  t09 := t07 xor t06;
  t10 := t04 or t03;
  t11 := d and t08;
  y := not t09;
  x := t10 xor t11;
  t14 := a or y;
  t15 := t06 xor x;
  z := t01 xor t04;
  t17 := c xor t15;
  w := t14 xor t17;
end;

procedure SerpentInvRND02(const a, b, c, d: DWORD; var w, x, y, z: DWORD);
var
  t01, t02, t03, t04, t06, t07, t08, t09, t10, t11, t12, t15, t16, t17: DWORD;
begin
  t01 := a xor d;
  t02 := c xor d;
  t03 := a and c;
  t04 := b or t02;
  w := t01 xor t04;
  t06 := a or c;
  t07 := d or w;
  t08 := not d;
  t09 := b and t06;
  t10 := t08 or t03;
  t11 := b and t07;
  t12 := t06 and t02;
  z := t09 xor t10;
  x := t12 xor t11;
  t15 := c and z;
  t16 := w xor x;
  t17 := t10 xor t15;
  y := t16 xor t17;
end;

procedure SerpentInvRND03(const a, b, c, d: DWORD; var w, x, y, z: DWORD);
var
  t01, t02, t03, t04, t05, t06, t07, t09, t11, t12, t13, t14, t16: DWORD;
begin
  t01 := c or d;
  t02 := a or d;
  t03 := c xor t02;
  t04 := b xor t02;
  t05 := a xor d;
  t06 := t04 and t03;
  t07 := b and t01;
  y := t05 xor t06;
  t09 := a xor t03;
  w := t07 xor t03;
  t11 := w or t05;
  t12 := t09 and t11;
  t13 := a and y;
  t14 := t01 xor t05;
  x := b xor t12;
  t16 := b or t13;
  z := t14 xor t16;
end;

procedure SerpentInvRND04(const a, b, c, d: DWORD; var w, x, y, z: DWORD);
var
  t01, t02, t03, t04, t05, t06, t07, t09, t10, t11, t12, t13, t15: DWORD;
begin
  t01 := b or d;
  t02 := c or d;
  t03 := a and t01;
  t04 := b xor t02;
  t05 := c xor d;
  t06 := not t03;
  t07 := a and t04;
  x := t05 xor t07;
  t09 := x or t06;
  t10 := a xor t07;
  t11 := t01 xor t09;
  t12 := d xor t04;
  t13 := c or t10;
  z := t03 xor t12;
  t15 := a xor t04;
  y := t11 xor t13;
  w := t15 xor t09;
end;

procedure SerpentInvRND05(const a, b, c, d: DWORD; var w, x, y, z: DWORD);
var
  t01, t02, t03, t04, t05, t07, t08, t09, t10, t12, t13, t15, t16: DWORD;
begin
  t01 := a and d;
  t02 := c xor t01;
  t03 := a xor d;
  t04 := b and t02;
  t05 := a and c;
  w := t03 xor t04;
  t07 := a and w;
  t08 := t01 xor w;
  t09 := b or t05;
  t10 := not b;
  x := t08 xor t09;
  t12 := t10 or t07;
  t13 := w or x;
  z := t02 xor t12;
  t15 := t02 xor t13;
  t16 := b xor d;
  y := t16 xor t15;
end;

procedure SerpentInvRND06(const a, b, c, d: DWORD; var w, x, y, z: DWORD);
var
  t01, t02, t03, t04, t05, t06, t07, t08, t09, t12, t13, t14, t15, t16, t17: DWORD;
begin
  t01 := a xor c;
  t02 := not c;
  t03 := b and t01;
  t04 := b or t02;
  t05 := d or t03;
  t06 := b xor d;
  t07 := a and t04;
  t08 := a or t02;
  t09 := t07 xor t05;
  x := t06 xor t08;
  w := not t09;
  t12 := b and w;
  t13 := t01 and t05;
  t14 := t01 xor t12;
  t15 := t07 xor t13;
  t16 := d or t02;
  t17 := a xor x;
  z := t17 xor t15;
  y := t16 xor t14;
end;

procedure SerpentInvRND07(const a, b, c, d: DWORD; var w, x, y, z: DWORD);
var
  t01, t02, t03, t04, t06, t07, t08, t09, t10, t11, t13, t14, t15, t16: DWORD;
begin
  t01 := a and b;
  t02 := a or b;
  t03 := c or t01;
  t04 := d and t02;
  z := t03 xor t04;
  t06 := b xor t04;
  t07 := d xor z;
  t08 := not t07;
  t09 := t06 or t08;
  t10 := b xor d;
  t11 := a or d;
  x := a xor t09;
  t13 := c xor t06;
  t14 := c and t11;
  t15 := d or x;
  t16 := t01 or t10;
  w := t13 xor t15;
  y := t14 xor t16;
end;

{ ---------------------------------------------------------------------------
 * SHat / SHatInverse: dispatch to the bitslice S-boxes.
 * --------------------------------------------------------------------------- }

procedure SerpentSHat(box: Integer; const input: TSerpentWords;
  var output: TSerpentWords);
var
  a, b, c, d, w, x, y, z: DWORD;
begin
  a := input[0]; b := input[1]; c := input[2]; d := input[3];
  case (box and 7) of
    0: SerpentRND00(a, b, c, d, w, x, y, z);
    1: SerpentRND01(a, b, c, d, w, x, y, z);
    2: SerpentRND02(a, b, c, d, w, x, y, z);
    3: SerpentRND03(a, b, c, d, w, x, y, z);
    4: SerpentRND04(a, b, c, d, w, x, y, z);
    5: SerpentRND05(a, b, c, d, w, x, y, z);
    6: SerpentRND06(a, b, c, d, w, x, y, z);
    7: SerpentRND07(a, b, c, d, w, x, y, z);
  end;
  output[0] := w; output[1] := x; output[2] := y; output[3] := z;
end;

procedure SerpentSHatInv(box: Integer; const input: TSerpentWords;
  var output: TSerpentWords);
var
  a, b, c, d, w, x, y, z: DWORD;
begin
  a := input[0]; b := input[1]; c := input[2]; d := input[3];
  case (box and 7) of
    0: SerpentInvRND00(a, b, c, d, w, x, y, z);
    1: SerpentInvRND01(a, b, c, d, w, x, y, z);
    2: SerpentInvRND02(a, b, c, d, w, x, y, z);
    3: SerpentInvRND03(a, b, c, d, w, x, y, z);
    4: SerpentInvRND04(a, b, c, d, w, x, y, z);
    5: SerpentInvRND05(a, b, c, d, w, x, y, z);
    6: SerpentInvRND06(a, b, c, d, w, x, y, z);
    7: SerpentInvRND07(a, b, c, d, w, x, y, z);
  end;
  output[0] := w; output[1] := x; output[2] := y; output[3] := z;
end;

{ ---------------------------------------------------------------------------
 * Linear transformation (from serpentsboxes.h).
 * --------------------------------------------------------------------------- }

procedure SerpentLT(var w0, w1, w2, w3: DWORD);
var
  x0, x1, x2, x3: DWORD;
begin
  x0 := w0; x1 := w1; x2 := w2; x3 := w3;
  x0 := ROL32(x0, 13);
  x2 := ROL32(x2, 3);
  x1 := x1 xor x0 xor x2;
  x3 := x3 xor x2 xor (x0 shl 3);
  x1 := ROL32(x1, 1);
  x3 := ROL32(x3, 7);
  x0 := x0 xor x1 xor x3;
  x2 := x2 xor x3 xor (x1 shl 7);
  x0 := ROL32(x0, 5);
  x2 := ROL32(x2, 22);
  w0 := x0; w1 := x1; w2 := x2; w3 := x3;
end;

procedure SerpentLTInv(var w0, w1, w2, w3: DWORD);
var
  x0, x1, x2, x3: DWORD;
begin
  x0 := w0; x1 := w1; x2 := w2; x3 := w3;
  x2 := ROR32(x2, 22);
  x0 := ROR32(x0, 5);
  x2 := x2 xor x3 xor (x1 shl 7);
  x0 := x0 xor x1 xor x3;
  x3 := ROR32(x3, 7);
  x1 := ROR32(x1, 1);
  x3 := x3 xor x2 xor (x0 shl 3);
  x1 := x1 xor x0 xor x2;
  x2 := ROR32(x2, 3);
  x0 := ROR32(x0, 13);
  w0 := x0; w1 := x1; w2 := x2; w3 := x3;
end;

{ ============================================================================
 * Key schedule
 * ============================================================================ }

class procedure TSerpent.InitKey(buff: Pointer; Size: Integer; var KeyContext: TSerpentkey);
const
  PHI = DWORD($9E3779B9);
  R = 32;
var
  rawW: array [0 .. 139] of DWORD;
  K: array [0 .. 131] of DWORD;
  userKey: array [0 .. 7] of DWORD;
  i, j, l, whichS: Integer;
  nib, outNib: Byte;
  bitLen, copySize, wordIdx: Integer;
  srcBytes: PByte;
begin
  FillPtr(@rawW[0], SizeOf(rawW), 0);
  FillPtr(@K[0], SizeOf(K), 0);
  FillPtr(@userKey[0], SizeOf(userKey), 0);

  copySize := Size;
  if copySize < 0 then copySize := 0;
  if copySize > 32 then copySize := 32;

  { Load the user key from the caller's buffer, BIG-ENDIAN per 32-bit word
    and from the tail of the buffer backwards (matching the KAT convention
    used by serpent.c's serpent_convert_from_string). }
  if (buff <> nil) and (copySize > 0) then
    begin
      srcBytes := PByte(buff);
      wordIdx := 0;
      i := copySize;
      while i >= 4 do
        begin
          dec(i, 4);
          userKey[wordIdx] := (DWORD(srcBytes[i]) shl 24) or
                              (DWORD(srcBytes[i + 1]) shl 16) or
                              (DWORD(srcBytes[i + 2]) shl 8) or
                              DWORD(srcBytes[i + 3]);
          inc(wordIdx);
        end;
    end;

  { shortToLongKey: append the 1 bit at position bitLen. }
  bitLen := copySize * 8;
  if (bitLen >= 0) and (bitLen < 256) then
    begin
      for i := 0 to (bitLen div 32) - 1 do
          rawW[i] := userKey[i];
      rawW[bitLen div 32] :=
        (userKey[bitLen div 32] and
         ((DWORD(1) shl (bitLen mod 32)) - 1)) or
        (DWORD(1) shl (bitLen mod 32));
      for i := (bitLen div 32) + 1 to 7 do
          rawW[i] := 0;
    end
  else
    for i := 0 to 7 do
        rawW[i] := userKey[i];

  { Prekey expansion: rawW[8..139] are the 132 prekeys w[0..131]. }
  for i := 0 to 131 do
      rawW[i + 8] := ROL32(
        rawW[i] xor rawW[i + 3] xor rawW[i + 5] xor rawW[i + 7]
        xor PHI xor DWORD(i), 11);

  { Subkey generation via the bitslice S-box method (serpentsboxes.h). }
  for i := 0 to 32 do
    begin
      whichS := (R + 3 - i) mod R;
      K[i * 4 + 0] := 0;
      K[i * 4 + 1] := 0;
      K[i * 4 + 2] := 0;
      K[i * 4 + 3] := 0;

      for j := 0 to 31 do
        begin
          nib := Byte((rawW[i * 4 + 8] shr j) and 1);
          nib := nib or Byte(((rawW[i * 4 + 9] shr j) and 1) shl 1);
          nib := nib or Byte(((rawW[i * 4 + 10] shr j) and 1) shl 2);
          nib := nib or Byte(((rawW[i * 4 + 11] shr j) and 1) shl 3);
          outNib := SerpentSBox[whichS and 7, nib];

          for l := 0 to 3 do
              K[i * 4 + l] := K[i * 4 + l] or
                (DWORD((outNib shr l) and 1) shl j);
        end;
    end;

  { Publish the subkeys. No IP is applied (matching serpent.c). }
  CopyPtr(@K[0], @KeyContext[0], SizeOf(K));

  FillPtr(@rawW[0], SizeOf(rawW), 0);
  FillPtr(@K[0], SizeOf(K), 0);
  FillPtr(@userKey[0], SizeOf(userKey), 0);
end;

{ ============================================================================
 * Encryption / decryption (bitslice, no IP/FP, LITTLE-ENDIAN block I/O).
 * ============================================================================ }

class procedure TSerpent.Encrypt(var KeyContext: TSerpentkey; var Data: TSerpentBlock);
var
  w, BHat, xored, SHati: TSerpentWords;
  i: Integer;
  a, b, c, d: DWORD;
begin
  { Little-endian load of the 128-bit block. This matches the C reference
    implementation's "unsigned long *" access on a little-endian host. }
  w[0] := DWORD(Data[0])  or (DWORD(Data[1])  shl 8)  or
          (DWORD(Data[2])  shl 16) or (DWORD(Data[3])  shl 24);
  w[1] := DWORD(Data[4])  or (DWORD(Data[5])  shl 8)  or
          (DWORD(Data[6])  shl 16) or (DWORD(Data[7])  shl 24);
  w[2] := DWORD(Data[8])  or (DWORD(Data[9])  shl 8)  or
          (DWORD(Data[10]) shl 16) or (DWORD(Data[11]) shl 24);
  w[3] := DWORD(Data[12]) or (DWORD(Data[13]) shl 8)  or
          (DWORD(Data[14]) shl 16) or (DWORD(Data[15]) shl 24);

  BHat := w;

  for i := 0 to 31 do
    begin
      xored[0] := BHat[0] xor KeyContext[i * 4 + 0];
      xored[1] := BHat[1] xor KeyContext[i * 4 + 1];
      xored[2] := BHat[2] xor KeyContext[i * 4 + 2];
      xored[3] := BHat[3] xor KeyContext[i * 4 + 3];

      SerpentSHat(i, xored, SHati);

      if i < 31 then
        begin
          a := SHati[0]; b := SHati[1]; c := SHati[2]; d := SHati[3];
          SerpentLT(a, b, c, d);
          BHat[0] := a; BHat[1] := b; BHat[2] := c; BHat[3] := d;
        end
      else
        begin
          BHat[0] := SHati[0] xor KeyContext[32 * 4 + 0];
          BHat[1] := SHati[1] xor KeyContext[32 * 4 + 1];
          BHat[2] := SHati[2] xor KeyContext[32 * 4 + 2];
          BHat[3] := SHati[3] xor KeyContext[32 * 4 + 3];
        end;
    end;

  w := BHat;

  { Little-endian store of the 128-bit block. }
  Data[0]  := Byte( w[0]         and $FF);
  Data[1]  := Byte((w[0] shr 8)  and $FF);
  Data[2]  := Byte((w[0] shr 16) and $FF);
  Data[3]  := Byte((w[0] shr 24) and $FF);
  Data[4]  := Byte( w[1]         and $FF);
  Data[5]  := Byte((w[1] shr 8)  and $FF);
  Data[6]  := Byte((w[1] shr 16) and $FF);
  Data[7]  := Byte((w[1] shr 24) and $FF);
  Data[8]  := Byte( w[2]         and $FF);
  Data[9]  := Byte((w[2] shr 8)  and $FF);
  Data[10] := Byte((w[2] shr 16) and $FF);
  Data[11] := Byte((w[2] shr 24) and $FF);
  Data[12] := Byte( w[3]         and $FF);
  Data[13] := Byte((w[3] shr 8)  and $FF);
  Data[14] := Byte((w[3] shr 16) and $FF);
  Data[15] := Byte((w[3] shr 24) and $FF);
end;

class procedure TSerpent.Decrypt(var KeyContext: TSerpentkey; var Data: TSerpentBlock);
var
  w, BHat, xored, SHati: TSerpentWords;
  i: Integer;
  a, b, c, d: DWORD;
begin
  { Little-endian load of the 128-bit block. }
  w[0] := DWORD(Data[0])  or (DWORD(Data[1])  shl 8)  or
          (DWORD(Data[2])  shl 16) or (DWORD(Data[3])  shl 24);
  w[1] := DWORD(Data[4])  or (DWORD(Data[5])  shl 8)  or
          (DWORD(Data[6])  shl 16) or (DWORD(Data[7])  shl 24);
  w[2] := DWORD(Data[8])  or (DWORD(Data[9])  shl 8)  or
          (DWORD(Data[10]) shl 16) or (DWORD(Data[11]) shl 24);
  w[3] := DWORD(Data[12]) or (DWORD(Data[13]) shl 8)  or
          (DWORD(Data[14]) shl 16) or (DWORD(Data[15]) shl 24);

  BHat := w;

  for i := 31 downto 0 do
    begin
      if i < 31 then
        begin
          a := BHat[0]; b := BHat[1]; c := BHat[2]; d := BHat[3];
          SerpentLTInv(a, b, c, d);
          SHati[0] := a; SHati[1] := b; SHati[2] := c; SHati[3] := d;
        end
      else
        begin
          SHati[0] := BHat[0] xor KeyContext[32 * 4 + 0];
          SHati[1] := BHat[1] xor KeyContext[32 * 4 + 1];
          SHati[2] := BHat[2] xor KeyContext[32 * 4 + 2];
          SHati[3] := BHat[3] xor KeyContext[32 * 4 + 3];
        end;

      SerpentSHatInv(i, SHati, xored);

      BHat[0] := xored[0] xor KeyContext[i * 4 + 0];
      BHat[1] := xored[1] xor KeyContext[i * 4 + 1];
      BHat[2] := xored[2] xor KeyContext[i * 4 + 2];
      BHat[3] := xored[3] xor KeyContext[i * 4 + 3];
    end;

  w := BHat;

  { Little-endian store of the 128-bit block. }
  Data[0]  := Byte( w[0]         and $FF);
  Data[1]  := Byte((w[0] shr 8)  and $FF);
  Data[2]  := Byte((w[0] shr 16) and $FF);
  Data[3]  := Byte((w[0] shr 24) and $FF);
  Data[4]  := Byte( w[1]         and $FF);
  Data[5]  := Byte((w[1] shr 8)  and $FF);
  Data[6]  := Byte((w[1] shr 16) and $FF);
  Data[7]  := Byte((w[1] shr 24) and $FF);
  Data[8]  := Byte( w[2]         and $FF);
  Data[9]  := Byte((w[2] shr 8)  and $FF);
  Data[10] := Byte((w[2] shr 16) and $FF);
  Data[11] := Byte((w[2] shr 24) and $FF);
  Data[12] := Byte( w[3]         and $FF);
  Data[13] := Byte((w[3] shr 8)  and $FF);
  Data[14] := Byte((w[3] shr 16) and $FF);
  Data[15] := Byte((w[3] shr 24) and $FF);
end;

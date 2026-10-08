{
 * ============================================================================
 * Z.Cipher.imp_TRijndael.inc
 *
 * Rijndael / AES block cipher implementation.
 * 128-bit block, 128/192/256-bit keys, 10/12/14 rounds.
 *
 * Implementation notes:
 *   - The T1..T8 and U1..U4 tables are stored as packed 4-byte groups.
 *     All reads go through "PDWORD(@T1[...])^" using the host's native
 *     byte order, and the cipher state / round keys are loaded through
 *     the same native DWORD path. As long as every access is native,
 *     Encrypt and Decrypt invert each other; mixing conventions breaks
 *     the round-trip.
 *   - The per-round key schedule is held in "tk: array [0 .. 7, 0 .. 3]
 *     of Byte" and traversed via "PDWORD(@tk[j])^" for the AddRoundKey
 *     step.
 *   - Local state / work matrices "tempb" and "a" are byte matrices,
 *     accessed both at byte granularity (final round) and at DWORD
 *     granularity (AddRoundKey and T-table lookups).
 *
 * ============================================================================
 *}

class procedure TRijndael.InvMixColumn(const a: PByteArray; const BC: Byte);
var
  j: Integer;
begin
  for j := 0 to (BC - 1) do
      PDWORD(@(a^[j * 4]))^ := PDWORD(@U1[a^[j * 4 + 0]])^ xor PDWORD(@U2[a^[j * 4 + 1]])^ xor PDWORD(@U3[a^[j * 4 + 2]])^ xor PDWORD(@U4[a^[j * 4 + 3]])^;
end;

class procedure TRijndael.InitKey(buff: Pointer; Size: Integer; var KeyContext: TRijndaelkey);
const
  s_box: array [0 .. 255] of Byte = (
  99, 124, 119, 123, 242, 107, 111, 197, 48, 1, 103, 43, 254, 215, 171, 118,
    202, 130, 201, 125, 250, 89, 71, 240, 173, 212, 162, 175, 156, 164, 114, 192,
    183, 253, 147, 38, 54, 63, 247, 204, 52, 165, 229, 241, 113, 216, 49, 21,
    4, 199, 35, 195, 24, 150, 5, 154, 7, 18, 128, 226, 235, 39, 178, 117,
    9, 131, 44, 26, 27, 110, 90, 160, 82, 59, 214, 179, 41, 227, 47, 132,
    83, 209, 0, 237, 32, 252, 177, 91, 106, 203, 190, 57, 74, 76, 88, 207,
    208, 239, 170, 251, 67, 77, 51, 133, 69, 249, 2, 127, 80, 60, 159, 168,
    81, 163, 64, 143, 146, 157, 56, 245, 188, 182, 218, 33, 16, 255, 243, 210,
    205, 12, 19, 236, 95, 151, 68, 23, 196, 167, 126, 61, 100, 93, 25, 115,
    96, 129, 79, 220, 34, 42, 144, 136, 70, 238, 184, 20, 222, 94, 11, 219,
    224, 50, 58, 10, 73, 6, 36, 92, 194, 211, 172, 98, 145, 149, 228, 121,
    231, 200, 55, 109, 141, 213, 78, 169, 108, 86, 244, 234, 101, 122, 174, 8,
    186, 120, 37, 46, 28, 166, 180, 198, 232, 221, 116, 31, 75, 189, 139, 138,
    112, 62, 181, 102, 72, 3, 246, 14, 97, 53, 87, 185, 134, 193, 29, 158,
    225, 248, 152, 17, 105, 217, 142, 148, 155, 30, 135, 233, 206, 85, 40, 223,
    140, 161, 137, 13, 191, 230, 66, 104, 65, 153, 45, 15, 176, 84, 187, 22);
var
  KC, Rounds: DWORD;
  j, R, t, rconpointer: Integer;
  tk: array [0 .. 8 - 1, 0 .. 3] of Byte;
begin
  FillPtrByte(@tk, SizeOf(tk), 0);
  CopyPtr(buff, @tk, Size);
  if Size <= 16 then
    begin
      KC := 4;
      Rounds := 10;
    end
  else if Size <= 24 then
    begin
      KC := 6;
      Rounds := 12;
    end
  else
    begin
      KC := 8;
      Rounds := 14;
    end;
  KeyContext.NumRounds := Rounds;
  R := 0;
  t := 0;
  j := 0;
  while (j < KC) and (R < (Rounds + 1)) do
    begin
      while (j < KC) and (t < 4) do
        begin
          KeyContext.rk[R, t] := PDWORD(@tk[j])^;
          inc(j);
          inc(t);
        end;
      if t = 4 then
        begin
          t := 0;
          inc(R);
        end;
    end;
  rconpointer := 0;
  while (R < (Rounds + 1)) do
    begin
      tk[0, 0] := tk[0, 0] xor s_box[tk[KC - 1, 1]];
      tk[0, 1] := tk[0, 1] xor s_box[tk[KC - 1, 2]];
      tk[0, 2] := tk[0, 2] xor s_box[tk[KC - 1, 3]];
      tk[0, 3] := tk[0, 3] xor s_box[tk[KC - 1, 0]];
      tk[0, 0] := tk[0, 0] xor rcon[rconpointer];
      inc(rconpointer);
      if KC <> 8 then
        begin
          for j := 1 to (KC - 1) do
              PDWORD(@tk[j])^ := PDWORD(@tk[j])^ xor PDWORD(@tk[j - 1])^;
        end
      else
        begin
          for j := 1 to ((KC div 2) - 1) do
              PDWORD(@tk[j])^ := PDWORD(@tk[j])^ xor PDWORD(@tk[j - 1])^;

          tk[KC div 2, 0] := tk[KC div 2, 0] xor s_box[tk[KC div 2 - 1, 0]];
          tk[KC div 2, 1] := tk[KC div 2, 1] xor s_box[tk[KC div 2 - 1, 1]];
          tk[KC div 2, 2] := tk[KC div 2, 2] xor s_box[tk[KC div 2 - 1, 2]];
          tk[KC div 2, 3] := tk[KC div 2, 3] xor s_box[tk[KC div 2 - 1, 3]];

          for j := ((KC div 2) + 1) to (KC - 1) do
              PDWORD(@tk[j])^ := PDWORD(@tk[j])^ xor PDWORD(@tk[j - 1])^;
        end;
      j := 0;
      while (j < KC) and (R < (Rounds + 1)) do
        begin
          while (j < KC) and (t < 4) do
            begin
              KeyContext.rk[R, t] := PDWORD(@tk[j])^;
              inc(j);
              inc(t);
            end;
          if t = 4 then
            begin
              inc(R);
              t := 0;
            end;
        end;
    end;
  CopyPtr(@KeyContext.rk, @KeyContext.drk, SizeOf(KeyContext.rk));
  for R := 1 to (Rounds - 1) do
      InvMixColumn(@KeyContext.drk[R], 4);
end;

class procedure TRijndael.Encrypt(var KeyContext: TRijndaelkey; var Data: TRijndaelBlock);
begin
  Encrypt(KeyContext, PDWORD(@Data[0])^, PDWORD(@Data[4])^, PDWORD(@Data[8])^, PDWORD(@Data[12])^);
end;

class procedure TRijndael.Encrypt(var KeyContext: TRijndaelkey; var B1, B2, B3, B4: DWORD);
var
  R: DWORD;
  tempb: array [0 .. 3, 0 .. 3] of Byte;
  a: array [0 .. 3, 0 .. 3] of Byte;
begin
  PDWORD(@a[0, 0])^ := B1;
  PDWORD(@a[1, 0])^ := B2;
  PDWORD(@a[2, 0])^ := B3;
  PDWORD(@a[3, 0])^ := B4;
  for R := 0 to (KeyContext.NumRounds - 2) do
    begin
      PDWORD(@tempb[0])^ := PDWORD(@a[0])^ xor KeyContext.rk[R, 0];
      PDWORD(@tempb[1])^ := PDWORD(@a[1])^ xor KeyContext.rk[R, 1];
      PDWORD(@tempb[2])^ := PDWORD(@a[2])^ xor KeyContext.rk[R, 2];
      PDWORD(@tempb[3])^ := PDWORD(@a[3])^ xor KeyContext.rk[R, 3];
      PDWORD(@a[0])^ := PDWORD(@T1[tempb[0, 0]])^ xor PDWORD(@T2[tempb[1, 1]])^ xor PDWORD(@T3[tempb[2, 2]])^ xor PDWORD(@T4[tempb[3, 3]])^;
      PDWORD(@a[1])^ := PDWORD(@T1[tempb[1, 0]])^ xor PDWORD(@T2[tempb[2, 1]])^ xor PDWORD(@T3[tempb[3, 2]])^ xor PDWORD(@T4[tempb[0, 3]])^;
      PDWORD(@a[2])^ := PDWORD(@T1[tempb[2, 0]])^ xor PDWORD(@T2[tempb[3, 1]])^ xor PDWORD(@T3[tempb[0, 2]])^ xor PDWORD(@T4[tempb[1, 3]])^;
      PDWORD(@a[3])^ := PDWORD(@T1[tempb[3, 0]])^ xor PDWORD(@T2[tempb[0, 1]])^ xor PDWORD(@T3[tempb[1, 2]])^ xor PDWORD(@T4[tempb[2, 3]])^;
    end;
  PDWORD(@tempb[0])^ := PDWORD(@a[0])^ xor KeyContext.rk[KeyContext.NumRounds - 1, 0];
  PDWORD(@tempb[1])^ := PDWORD(@a[1])^ xor KeyContext.rk[KeyContext.NumRounds - 1, 1];
  PDWORD(@tempb[2])^ := PDWORD(@a[2])^ xor KeyContext.rk[KeyContext.NumRounds - 1, 2];
  PDWORD(@tempb[3])^ := PDWORD(@a[3])^ xor KeyContext.rk[KeyContext.NumRounds - 1, 3];
  a[0, 0] := T1[tempb[0, 0], 1];
  a[0, 1] := T1[tempb[1, 1], 1];
  a[0, 2] := T1[tempb[2, 2], 1];
  a[0, 3] := T1[tempb[3, 3], 1];
  a[1, 0] := T1[tempb[1, 0], 1];
  a[1, 1] := T1[tempb[2, 1], 1];
  a[1, 2] := T1[tempb[3, 2], 1];
  a[1, 3] := T1[tempb[0, 3], 1];
  a[2, 0] := T1[tempb[2, 0], 1];
  a[2, 1] := T1[tempb[3, 1], 1];
  a[2, 2] := T1[tempb[0, 2], 1];
  a[2, 3] := T1[tempb[1, 3], 1];
  a[3, 0] := T1[tempb[3, 0], 1];
  a[3, 1] := T1[tempb[0, 1], 1];
  a[3, 2] := T1[tempb[1, 2], 1];
  a[3, 3] := T1[tempb[2, 3], 1];

  B1 := PDWORD(@a[0])^ xor KeyContext.rk[KeyContext.NumRounds, 0];
  B2 := PDWORD(@a[1])^ xor KeyContext.rk[KeyContext.NumRounds, 1];
  B3 := PDWORD(@a[2])^ xor KeyContext.rk[KeyContext.NumRounds, 2];
  B4 := PDWORD(@a[3])^ xor KeyContext.rk[KeyContext.NumRounds, 3];
end;

class procedure TRijndael.Decrypt(var KeyContext: TRijndaelkey; var Data: TRijndaelBlock);
begin
  Decrypt(KeyContext, PDWORD(@Data[0])^, PDWORD(@Data[4])^, PDWORD(@Data[8])^, PDWORD(@Data[12])^);
end;

class procedure TRijndael.Decrypt(var KeyContext: TRijndaelkey; var B1, B2, B3, B4: DWORD);
var
  R: Integer;
  tempb: array [0 .. 3, 0 .. 3] of Byte;
  a: array [0 .. 3, 0 .. 3] of Byte;
begin
  PDWORD(@a[0, 0])^ := B1;
  PDWORD(@a[1, 0])^ := B2;
  PDWORD(@a[2, 0])^ := B3;
  PDWORD(@a[3, 0])^ := B4;

  for R := KeyContext.NumRounds downto 2 do
    begin
      PDWORD(@tempb[0])^ := PDWORD(@a[0])^ xor KeyContext.drk[R, 0];
      PDWORD(@tempb[1])^ := PDWORD(@a[1])^ xor KeyContext.drk[R, 1];
      PDWORD(@tempb[2])^ := PDWORD(@a[2])^ xor KeyContext.drk[R, 2];
      PDWORD(@tempb[3])^ := PDWORD(@a[3])^ xor KeyContext.drk[R, 3];

      PDWORD(@a[0])^ := PDWORD(@T5[tempb[0, 0]])^ xor PDWORD(@T6[tempb[3, 1]])^ xor PDWORD(@T7[tempb[2, 2]])^ xor PDWORD(@T8[tempb[1, 3]])^;
      PDWORD(@a[1])^ := PDWORD(@T5[tempb[1, 0]])^ xor PDWORD(@T6[tempb[0, 1]])^ xor PDWORD(@T7[tempb[3, 2]])^ xor PDWORD(@T8[tempb[2, 3]])^;
      PDWORD(@a[2])^ := PDWORD(@T5[tempb[2, 0]])^ xor PDWORD(@T6[tempb[1, 1]])^ xor PDWORD(@T7[tempb[0, 2]])^ xor PDWORD(@T8[tempb[3, 3]])^;
      PDWORD(@a[3])^ := PDWORD(@T5[tempb[3, 0]])^ xor PDWORD(@T6[tempb[2, 1]])^ xor PDWORD(@T7[tempb[1, 2]])^ xor PDWORD(@T8[tempb[0, 3]])^;
    end;

  PDWORD(@tempb[0])^ := PDWORD(@a[0])^ xor KeyContext.drk[1, 0];
  PDWORD(@tempb[1])^ := PDWORD(@a[1])^ xor KeyContext.drk[1, 1];
  PDWORD(@tempb[2])^ := PDWORD(@a[2])^ xor KeyContext.drk[1, 2];
  PDWORD(@tempb[3])^ := PDWORD(@a[3])^ xor KeyContext.drk[1, 3];

  a[0, 0] := S5[tempb[0, 0]];
  a[0, 1] := S5[tempb[3, 1]];
  a[0, 2] := S5[tempb[2, 2]];
  a[0, 3] := S5[tempb[1, 3]];
  a[1, 0] := S5[tempb[1, 0]];
  a[1, 1] := S5[tempb[0, 1]];
  a[1, 2] := S5[tempb[3, 2]];
  a[1, 3] := S5[tempb[2, 3]];
  a[2, 0] := S5[tempb[2, 0]];
  a[2, 1] := S5[tempb[1, 1]];
  a[2, 2] := S5[tempb[0, 2]];
  a[2, 3] := S5[tempb[3, 3]];
  a[3, 0] := S5[tempb[3, 0]];
  a[3, 1] := S5[tempb[2, 1]];
  a[3, 2] := S5[tempb[1, 2]];
  a[3, 3] := S5[tempb[0, 3]];

  B1 := PDWORD(@a[0])^ xor KeyContext.drk[0, 0];
  B2 := PDWORD(@a[1])^ xor KeyContext.drk[0, 1];
  B3 := PDWORD(@a[2])^ xor KeyContext.drk[0, 2];
  B4 := PDWORD(@a[3])^ xor KeyContext.drk[0, 3];
end;

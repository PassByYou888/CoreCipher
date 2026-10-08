{ TDES }

class procedure TDES.EncryptDES(const Context: TDESContext; var Block: TDESBlock);
const
  SPBox: array [0 .. 7, 0 .. 63] of DWORD =
    (($01010400, $00000000, $00010000, $01010404, $01010004, $00010404, $00000004, $00010000,
    $00000400, $01010400, $01010404, $00000400, $01000404, $01010004, $01000000, $00000004,
    $00000404, $01000400, $01000400, $00010400, $00010400, $01010000, $01010000, $01000404,
    $00010004, $01000004, $01000004, $00010004, $00000000, $00000404, $00010404, $01000000,
    $00010000, $01010404, $00000004, $01010000, $01010400, $01000000, $01000000, $00000400,
    $01010004, $00010000, $00010400, $01000004, $00000400, $00000004, $01000404, $00010404,
    $01010404, $00010004, $01010000, $01000404, $01000004, $00000404, $00010404, $01010400,
    $00000404, $01000400, $01000400, $00000000, $00010004, $00010400, $00000000, $01010004),
    ($80108020, $80008000, $00008000, $00108020, $00100000, $00000020, $80100020, $80008020,
    $80000020, $80108020, $80108000, $80000000, $80008000, $00100000, $00000020, $80100020,
    $00108000, $00100020, $80008020, $00000000, $80000000, $00008000, $00108020, $80100000,
    $00100020, $80000020, $00000000, $00108000, $00008020, $80108000, $80100000, $00008020,
    $00000000, $00108020, $80100020, $00100000, $80008020, $80100000, $80108000, $00008000,
    $80100000, $80008000, $00000020, $80108020, $00108020, $00000020, $00008000, $80000000,
    $00008020, $80108000, $00100000, $80000020, $00100020, $80008020, $80000020, $00100020,
    $00108000, $00000000, $80008000, $00008020, $80000000, $80100020, $80108020, $00108000),
    ($00000208, $08020200, $00000000, $08020008, $08000200, $00000000, $00020208, $08000200,
    $00020008, $08000008, $08000008, $00020000, $08020208, $00020008, $08020000, $00000208,
    $08000000, $00000008, $08020200, $00000200, $00020200, $08020000, $08020008, $00020208,
    $08000208, $00020200, $00020000, $08000208, $00000008, $08020208, $00000200, $08000000,
    $08020200, $08000000, $00020008, $00000208, $00020000, $08020200, $08000200, $00000000,
    $00000200, $00020008, $08020208, $08000200, $08000008, $00000200, $00000000, $08020008,
    $08000208, $00020000, $08000000, $08020208, $00000008, $00020208, $00020200, $08000008,
    $08020000, $08000208, $00000208, $08020000, $00020208, $00000008, $08020008, $00020200),
    ($00802001, $00002081, $00002081, $00000080, $00802080, $00800081, $00800001, $00002001,
    $00000000, $00802000, $00802000, $00802081, $00000081, $00000000, $00800080, $00800001,
    $00000001, $00002000, $00800000, $00802001, $00000080, $00800000, $00002001, $00002080,
    $00800081, $00000001, $00002080, $00800080, $00002000, $00802080, $00802081, $00000081,
    $00800080, $00800001, $00802000, $00802081, $00000081, $00000000, $00000000, $00802000,
    $00002080, $00800080, $00800081, $00000001, $00802001, $00002081, $00002081, $00000080,
    $00802081, $00000081, $00000001, $00002000, $00800001, $00002001, $00802080, $00800081,
    $00002001, $00002080, $00800000, $00802001, $00000080, $00800000, $00002000, $00802080),
    ($00000100, $02080100, $02080000, $42000100, $00080000, $00000100, $40000000, $02080000,
    $40080100, $00080000, $02000100, $40080100, $42000100, $42080000, $00080100, $40000000,
    $02000000, $40080000, $40080000, $00000000, $40000100, $42080100, $42080100, $02000100,
    $42080000, $40000100, $00000000, $42000000, $02080100, $02000000, $42000000, $00080100,
    $00080000, $42000100, $00000100, $02000000, $40000000, $02080000, $42000100, $40080100,
    $02000100, $40000000, $42080000, $02080100, $40080100, $00000100, $02000000, $42080000,
    $42080100, $00080100, $42000000, $42080100, $02080000, $00000000, $40080000, $42000000,
    $00080100, $02000100, $40000100, $00080000, $00000000, $40080000, $02080100, $40000100),
    ($20000010, $20400000, $00004000, $20404010, $20400000, $00000010, $20404010, $00400000,
    $20004000, $00404010, $00400000, $20000010, $00400010, $20004000, $20000000, $00004010,
    $00000000, $00400010, $20004010, $00004000, $00404000, $20004010, $00000010, $20400010,
    $20400010, $00000000, $00404010, $20404000, $00004010, $00404000, $20404000, $20000000,
    $20004000, $00000010, $20400010, $00404000, $20404010, $00400000, $00004010, $20000010,
    $00400000, $20004000, $20000000, $00004010, $20000010, $20404010, $00404000, $20400000,
    $00404010, $20404000, $00000000, $20400010, $00000010, $00004000, $20400000, $00404010,
    $00004000, $00400010, $20004010, $00000000, $20404000, $20000000, $00400010, $20004010),
    ($00200000, $04200002, $04000802, $00000000, $00000800, $04000802, $00200802, $04200800,
    $04200802, $00200000, $00000000, $04000002, $00000002, $04000000, $04200002, $00000802,
    $04000800, $00200802, $00200002, $04000800, $04000002, $04200000, $04200800, $00200002,
    $04200000, $00000800, $00000802, $04200802, $00200800, $00000002, $04000000, $00200800,
    $04000000, $00200800, $00200000, $04000802, $04000802, $04200002, $04200002, $00000002,
    $00200002, $04000000, $04000800, $00200000, $04200800, $00000802, $00200802, $04200800,
    $00000802, $04000002, $04200802, $04200000, $00200800, $00000000, $00000002, $04200802,
    $00000000, $00200802, $04200000, $00000800, $04000002, $04000800, $00000800, $00200002),
    ($10001040, $00001000, $00040000, $10041040, $10000000, $10001040, $00000040, $10000000,
    $00040040, $10040000, $10041040, $00041000, $10041000, $00041040, $00001000, $00000040,
    $10040000, $10000040, $10001000, $00001040, $00041000, $00040040, $10040040, $10041000,
    $00001040, $00000000, $00000000, $10040040, $10000040, $10001000, $00041040, $00040000,
    $00041040, $00040000, $10041000, $00001000, $00000040, $10040040, $00001000, $00041040,
    $10001000, $00000040, $10000040, $10040000, $10040040, $10000000, $00040000, $10001040,
    $00000000, $10041040, $00040040, $10000040, $10040000, $10001000, $10001040, $00000000,
    $10041040, $00041000, $00041000, $00001040, $00001040, $00040040, $10000000, $10041000));
var
  i, L, R, Work: DWORD;
  CPtr: PDWORD;
  {
   * FIX: aligned local copy of the round keys. TDESContext is a packed
   * record, so Context.TransformedKey may live at a non-4-byte-aligned
   * address. Iterating over this local copy eliminates the unaligned
   * DWORD reads that occurred when CPtr started at @Context.
   *}
  localKey: array [0 .. 31] of DWORD;

  procedure IPerm(var L, R: DWORD);
  var
    Work: DWORD;
  begin
    Work := ((L shr 4) xor R) and $0F0F0F0F;
    R := R xor Work;
    L := L xor Work shl 4;

    Work := ((L shr 16) xor R) and $0000FFFF;
    R := R xor Work;
    L := L xor Work shl 16;

    Work := ((R shr 2) xor L) and $33333333;
    L := L xor Work;
    R := R xor Work shl 2;

    Work := ((R shr 8) xor L) and $00FF00FF;
    L := L xor Work;
    R := R xor Work shl 8;

    R := (R shl 1) or (R shr 31);
    Work := (L xor R) and $AAAAAAAA;
    L := L xor Work;
    R := R xor Work;
    L := (L shl 1) or (L shr 31);
  end;

  procedure FPerm(var L, R: DWORD);
  var
    Work: DWORD;
  begin
    L := L;

    R := (R shl 31) or (R shr 1);
    Work := (L xor R) and $AAAAAAAA;
    L := L xor Work;
    R := R xor Work;
    L := (L shr 1) or (L shl 31);

    Work := ((L shr 8) xor R) and $00FF00FF;
    R := R xor Work;
    L := L xor Work shl 8;

    Work := ((L shr 2) xor R) and $33333333;
    R := R xor Work;
    L := L xor Work shl 2;

    Work := ((R shr 16) xor L) and $0000FFFF;
    L := L xor Work;
    R := R xor Work shl 16;

    Work := ((R shr 4) xor L) and $0F0F0F0F;
    L := L xor Work;
    R := R xor Work shl 4;
  end;

begin
  {
   * FIX: copy the round keys into a locally aligned DWORD array before
   * traversing them with a DWORD pointer.
   *}
  CopyPtr(@Context.TransformedKey[0], @localKey[0], SizeOf(localKey));

  SplitBlock(Block, L, R);
  IPerm(L, R);

  CPtr := @localKey[0];
  for i := 0 to 7 do
    begin
      Work := (((R shr 4) or (R shl 28)) xor CPtr^);
      inc(CPtr);
      L := L xor SPBox[6, Work and $3F];
      L := L xor SPBox[4, Work shr 8 and $3F];
      L := L xor SPBox[2, Work shr 16 and $3F];
      L := L xor SPBox[0, Work shr 24 and $3F];

      Work := (R xor CPtr^);
      inc(CPtr);
      L := L xor SPBox[7, Work and $3F];
      L := L xor SPBox[5, Work shr 8 and $3F];
      L := L xor SPBox[3, Work shr 16 and $3F];
      L := L xor SPBox[1, Work shr 24 and $3F];

      Work := (((L shr 4) or (L shl 28)) xor CPtr^);
      inc(CPtr);
      R := R xor SPBox[6, Work and $3F];
      R := R xor SPBox[4, Work shr 8 and $3F];
      R := R xor SPBox[2, Work shr 16 and $3F];
      R := R xor SPBox[0, Work shr 24 and $3F];

      Work := (L xor CPtr^);
      inc(CPtr);
      R := R xor SPBox[7, Work and $3F];
      R := R xor SPBox[5, Work shr 8 and $3F];
      R := R xor SPBox[3, Work shr 16 and $3F];
      R := R xor SPBox[1, Work shr 24 and $3F];
    end;

  FPerm(L, R);
  JoinBlock(L, R, Block);

  {
   * Wipe the aligned local copy of the schedule.
   *}
  FillPtr(@localKey[0], SizeOf(localKey), 0);
end;

class procedure TDES.EncryptTripleDES(const Context: TTripleDESContext; var Block: TDESBlock);
begin
  EncryptDES(Context[0], Block);
  EncryptDES(Context[1], Block);
  EncryptDES(Context[0], Block);
end;

{ !!.01 }
class procedure TDES.EncryptTripleDES3Key(const Context: TTripleDESContext3Key; var Block: TDESBlock);
begin
  EncryptDES(Context[2], Block);
  EncryptDES(Context[1], Block);
  EncryptDES(Context[0], Block);
end;

class procedure TDES.InitEncryptDES(const key: TKey64; var Context: TDESContext; Encrypt: Boolean);
const
  PC1: array [0 .. 55] of Byte =
    (56, 48, 40, 32, 24, 16, 8, 0, 57, 49, 41, 33, 25, 17, 9, 1, 58, 50, 42, 34, 26,
    18, 10, 2, 59, 51, 43, 35, 62, 54, 46, 38, 30, 22, 14, 6, 61, 53, 45, 37, 29, 21,
    13, 5, 60, 52, 44, 36, 28, 20, 12, 4, 27, 19, 11, 3);
  PC2: array [0 .. 47] of Byte =
    (13, 16, 10, 23, 0, 4, 2, 27, 14, 5, 20, 9, 22, 18, 11, 3, 25, 7,
    15, 6, 26, 19, 12, 1, 40, 51, 30, 36, 46, 54, 29, 39, 50, 44, 32, 47,
    43, 48, 38, 55, 33, 52, 45, 41, 49, 35, 28, 31);
  CTotRot: array [0 .. 15] of Byte = (1, 2, 4, 6, 8, 10, 12, 14, 15, 17, 19, 21, 23, 25, 27, 28);
  CBitMask: array [0 .. 7] of Byte = (128, 64, 32, 16, 8, 4, 2, 1);
var
  PC1M: array [0 .. 55] of Byte;
  PC1R: array [0 .. 55] of Byte;
  KS: array [0 .. 7] of Byte;
  i, j, L, m: Integer;
  {
   * FIX: build the 32-entry round-key schedule in an aligned local array,
   * then CopyPtr it into Context.TransformedKey. This avoids the
   * unaligned DWORD stores that occurred when writing directly into the
   * packed TDESContext record.
   *}
  localKey: array [0 .. 31] of DWORD;
begin
  FillPtr(@localKey[0], SizeOf(localKey), 0);

  { convert PC1 to bits of key }
  for j := 0 to 55 do begin
      L := PC1[j];
      m := L mod 8;
      PC1M[j] := Ord((key[L div 8] and CBitMask[m]) <> 0);
    end;

  { key chunk for each iteration }
  for i := 0 to 15 do begin
      { rotate PC1 the right amount }
      for j := 0 to 27 do begin
          L := j + CTotRot[i];
          if (L < 28) then begin
              PC1R[j] := PC1M[L];
              PC1R[j + 28] := PC1M[L + 28];
            end
          else begin
              PC1R[j] := PC1M[L - 28];
              PC1R[j + 28] := PC1M[L];
            end;
        end;

      { select bits individually }
      FillPtrByte(@KS, SizeOf(KS), 0);
      for j := 0 to 47 do
        if Boolean(PC1R[PC2[j]]) then begin
            L := j div 6;
            KS[L] := KS[L] or CBitMask[j mod 6] shr 2;
          end;

      { now convert to odd/even interleaved form for use in F }
      if Encrypt then begin
          localKey[i * 2] := (DWORD(KS[0]) shl 24) or (DWORD(KS[2]) shl 16) or
            (DWORD(KS[4]) shl 8) or (DWORD(KS[6]));
          localKey[i * 2 + 1] := (DWORD(KS[1]) shl 24) or (DWORD(KS[3]) shl 16) or
            (DWORD(KS[5]) shl 8) or (DWORD(KS[7]));
        end
      else begin
          localKey[31 - (i * 2 + 1)] := (DWORD(KS[0]) shl 24) or (DWORD(KS[2]) shl 16) or
            (DWORD(KS[4]) shl 8) or (DWORD(KS[6]));
          localKey[31 - (i * 2)] := (DWORD(KS[1]) shl 24) or (DWORD(KS[3]) shl 16) or
            (DWORD(KS[5]) shl 8) or (DWORD(KS[7]));
        end;
    end;

  CopyPtr(@localKey[0], @Context.TransformedKey[0], SizeOf(localKey));

  Context.Encrypt := Encrypt;

  FillPtr(@localKey[0], SizeOf(localKey), 0);
  FillPtr(@KS[0], SizeOf(KS), 0);
  FillPtr(@PC1M[0], SizeOf(PC1M), 0);
  FillPtr(@PC1R[0], SizeOf(PC1R), 0);
end;

class procedure TDES.InitEncryptTripleDES(const key: TKey128; var Context: TTripleDESContext; Encrypt: Boolean);
var
  KeyArray: array [0 .. 1] of TKey64;
begin
  FillPtr(@KeyArray[0], SizeOf(KeyArray), 0);
  CopyPtr(@key, @KeyArray, SizeOf(KeyArray));
  if Encrypt then begin
      InitEncryptDES(KeyArray[0], Context[0], True);
      InitEncryptDES(KeyArray[1], Context[1], False);
    end
  else begin
      InitEncryptDES(KeyArray[0], Context[0], False);
      InitEncryptDES(KeyArray[1], Context[1], True);
    end;
  FillPtr(@KeyArray[0], SizeOf(KeyArray), 0);
end;

{ !!.01 }
class procedure TDES.InitEncryptTripleDES3Key(const Key1, Key2, Key3: TKey64; var Context: TTripleDESContext3Key; Encrypt: Boolean);
begin
  if Encrypt then begin
      InitEncryptDES(Key1, Context[0], True);
      InitEncryptDES(Key2, Context[1], False);
      InitEncryptDES(Key3, Context[2], True);
    end
  else begin
      InitEncryptDES(Key1, Context[2], False);
      InitEncryptDES(Key2, Context[1], True);
      InitEncryptDES(Key3, Context[0], False);
    end;
end;

class procedure TDES.JoinBlock(const L, R: DWORD; var Block: TDESBlock);
begin
  {
   * FIX: this is the direct byte-level expansion of the original
   *
   *   Temp.DWords[0] := DWORD(L);
   *   Temp.DWords[1] := DWORD(R);
   *   for i := low(Block) to high(Block) do Block[i] := Temp.Bytes[7 - i];
   *
   * On a little-endian host this means:
   *   Block[0..3] = big-endian representation of R
   *   Block[4..7] = big-endian representation of L
   * (R comes first, because the final Feistel round swaps L and R.)
   *}
  Block[0] := Byte((R shr 24) and $FF);
  Block[1] := Byte((R shr 16) and $FF);
  Block[2] := Byte((R shr 8)  and $FF);
  Block[3] := Byte( R         and $FF);
  Block[4] := Byte((L shr 24) and $FF);
  Block[5] := Byte((L shr 16) and $FF);
  Block[6] := Byte((L shr 8)  and $FF);
  Block[7] := Byte( L         and $FF);
end;

class procedure TDES.ShrinkDESKey(var key: TKey64);
const
  SK1: TKey64 = ($C4, $08, $B0, $54, $0B, $A1, $E0, $AE);
  SK2: TKey64 = ($EF, $2C, $04, $1C, $E6, $38, $2F, $E6);
var
  i: Integer;
  Work1: TKey64;
  Work2: TKey64;
  Context: TDESContext;
  {
   * FIX: stage the two 4-byte halves through aligned DWORDs instead of
   * "TInt64(Work1).Lo / .Hi", which was an unaligned 32-bit view of a
   * 1-byte-aligned byte array.
   *}
  Lo, Hi: DWORD;
begin
  { step #1 zero the parity bits - 8, 16, 24, ..., 64 }
  for i := 0 to 7 do
      Work1[i] := key[i] and $FE;

  { step #2 encrypt output of #1 with SK1 and xor with output of #1 }
  InitEncryptDES(SK1, Context, True);
  Work2 := Work1; { make copy }
  EncryptDES(Context, TDESBlock(Work2));
  for i := 0 to 7 do
      Work1[i] := Work1[i] xor Work2[i];

  { step #3 zero bits 1,2,3,4,8,16,17,18,19,20,24,32,33,34,35,36,40,48,49,50,51,52,56,64 }
  CopyPtr(@Work1[0], @Lo, 4);
  CopyPtr(@Work1[4], @Hi, 4);
  Lo := Lo and $F101F101;
  Hi := Hi and $F101F101;
  CopyPtr(@Lo, @Work1[0], 4);
  CopyPtr(@Hi, @Work1[4], 4);

  { step #4 encrypt output of #3 with SK2 }
  InitEncryptDES(SK2, Context, True);
  EncryptDES(Context, TDESBlock(Work1));

  key := Work1;

  FillPtr(@Work2[0], SizeOf(Work2), 0);
  FillPtr(@Context, SizeOf(Context), 0);
  Lo := 0;
  Hi := 0;
end;

class procedure TDES.SplitBlock(const Block: TDESBlock; var L, R: DWORD);
begin
  {
   * FIX: this is the direct byte-level expansion of the original
   *
   *   for i := low(Block) to high(Block) do Temp.Bytes[7 - i] := Block[i];
   *   L := Temp.DWords[1];
   *   R := Temp.DWords[0];
   *
   * On a little-endian host this means:
   *   L = big-endian representation of Block[0..3]
   *   R = big-endian representation of Block[4..7]
   *}
  L := (DWORD(Block[0]) shl 24) or (DWORD(Block[1]) shl 16) or
       (DWORD(Block[2]) shl 8)  or  DWORD(Block[3]);
  R := (DWORD(Block[4]) shl 24) or (DWORD(Block[5]) shl 16) or
       (DWORD(Block[6]) shl 8)  or  DWORD(Block[7]);
end;

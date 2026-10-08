{$IFDEF OverflowCheck}{$Q-}{$ENDIF}
{$IFDEF RangeCheck}{$R-}{$ENDIF}


function ROL8(const Value: Byte; Shift: Byte): Byte;
begin
  Shift := Shift and $07;
  Result := Byte((Value shl Shift) or (Value shr (8 - Shift)));
end;

function ROL16(const Value: Word; Shift: Byte): Word;
begin
  Shift := Shift and $0F;
  Result := Word((Value shl Shift) or (Value shr (16 - Shift)));
end;

function ROL32(const Value: Cardinal; Shift: Byte): Cardinal;
begin
  Shift := Shift and $1F;
  Result := Cardinal((Value shl Shift) or (Value shr (32 - Shift)));
end;

function ROL64(const Value: UInt64; Shift: Byte): UInt64;
begin
  Shift := Shift and $3F;
  Result := UInt64((Value shl Shift) or (Value shr (64 - Shift)));
end;

function ROR8(const Value: Byte; Shift: Byte): Byte;
begin
  Shift := Shift and $07;
  Result := UInt8((Value shr Shift) or (Value shl (8 - Shift)));
end;

function ROR16(const Value: Word; Shift: Byte): Word;
begin
  Shift := Shift and $0F;
  Result := Word((Value shr Shift) or (Value shl (16 - Shift)));
end;

function ROR32(const Value: Cardinal; Shift: Byte): Cardinal;
begin
  Shift := Shift and $1F;
  Result := Cardinal((Value shr Shift) or (Value shl (32 - Shift)));
end;

function ROR64(const Value: UInt64; Shift: Byte): UInt64;
begin
  Shift := Shift and $3F;
  Result := UInt64((Value shr Shift) or (Value shl (64 - Shift)));
end;

function Endian(const Value: SmallInt): SmallInt;
begin
  { the extra Word type cast is necessary because the "Value shr 8" }
  { is turned into "Integer(Value) shr 8", so if Value < 0 then }
  { the sign bits from the upper 16 bits are shifted in rather than }
  { zeroes. }
  Result := SmallInt((Word(Value) shr 8) or (Word(Value) shl 8));
end;

function Endian(const Value: Word): Word;
begin
  Result := Word((Value shr 8) or (Value shl 8));
end;

function Endian(const Value: Integer): Integer;
begin
  Result := ((Cardinal(Value) shl 8) and $FF00FF00) or ((Cardinal(Value) shr 8) and $00FF00FF);
  Result := (Cardinal(Result) shl 16) or (Cardinal(Result) shr 16);
end;

function Endian(const Value: Cardinal): Cardinal;
begin
  Result := ((Value shl 8) and $FF00FF00) or ((Value shr 8) and $00FF00FF);
  Result := (Result shl 16) or (Result shr 16);
end;

function Endian(const Value: Int64): Int64;
begin
  Result := ((UInt64(Value) shl 8) and $FF00FF00FF00FF00) or ((UInt64(Value) shr 8) and $00FF00FF00FF00FF);
  Result := ((UInt64(Result) shl 16) and $FFFF0000FFFF0000) or ((UInt64(Result) shr 16) and $0000FFFF0000FFFF);
  Result := (UInt64(Result) shl 32) or ((UInt64(Result) shr 32));
end;

function Endian(const Value: UInt64): UInt64;
begin
  Result := ((Value shl 8) and $FF00FF00FF00FF00) or ((Value shr 8) and $00FF00FF00FF00FF);
  Result := ((Result shl 16) and $FFFF0000FFFF0000) or ((Result shr 16) and $0000FFFF0000FFFF);
  Result := (Result shl 32) or ((Result shr 32));
end;

function BE2N(const Value: SmallInt): SmallInt;
begin
{$IFDEF BIG_ENDIAN}
  Result := Value;
{$ELSE}
  Result := Endian(Value);
{$ENDIF}
end;

function BE2N(const Value: Word): Word;
begin
{$IFDEF BIG_ENDIAN}
  Result := Value;
{$ELSE}
  Result := Endian(Value);
{$ENDIF}
end;

function BE2N(const Value: Integer): Integer;
begin
{$IFDEF BIG_ENDIAN}
  Result := Value;
{$ELSE}
  Result := Endian(Value);
{$ENDIF}
end;

function BE2N(const Value: Cardinal): Cardinal;
begin
{$IFDEF BIG_ENDIAN}
  Result := Value;
{$ELSE}
  Result := Endian(Value);
{$ENDIF}
end;

function BE2N(const Value: Int64): Int64;
begin
{$IFDEF BIG_ENDIAN}
  Result := Value;
{$ELSE}
  Result := Endian(Value);
{$ENDIF}
end;

function BE2N(const Value: UInt64): UInt64;
begin
{$IFDEF BIG_ENDIAN}
  Result := Value;
{$ELSE}
  Result := Endian(Value);
{$ENDIF}
end;

function LE2N(const Value: SmallInt): SmallInt;
begin
{$IFDEF LITTLE_ENDIAN}
  Result := Value;
{$ELSE}
  Result := Endian(Value);
{$ENDIF}
end;

function LE2N(const Value: Word): Word;
begin
{$IFDEF LITTLE_ENDIAN}
  Result := Value;
{$ELSE}
  Result := Endian(Value);
{$ENDIF}
end;

function LE2N(const Value: Integer): Integer;
begin
{$IFDEF LITTLE_ENDIAN}
  Result := Value;
{$ELSE}
  Result := Endian(Value);
{$ENDIF}
end;

function LE2N(const Value: Cardinal): Cardinal;
begin
{$IFDEF LITTLE_ENDIAN}
  Result := Value;
{$ELSE}
  Result := Endian(Value);
{$ENDIF}
end;

function LE2N(const Value: Int64): Int64;
begin
{$IFDEF LITTLE_ENDIAN}
  Result := Value;
{$ELSE}
  Result := Endian(Value);
{$ENDIF}
end;

function LE2N(const Value: UInt64): UInt64;
begin
{$IFDEF LITTLE_ENDIAN}
  Result := Value;
{$ELSE}
  Result := Endian(Value);
{$ENDIF}
end;

function N2BE(const Value: SmallInt): SmallInt;
begin
{$IFDEF BIG_ENDIAN}
  Result := Value;
{$ELSE}
  Result := Endian(Value);
{$ENDIF}
end;

function N2BE(const Value: Word): Word;
begin
{$IFDEF BIG_ENDIAN}
  Result := Value;
{$ELSE}
  Result := Endian(Value);
{$ENDIF}
end;

function N2BE(const Value: Integer): Integer;
begin
{$IFDEF BIG_ENDIAN}
  Result := Value;
{$ELSE}
  Result := Endian(Value);
{$ENDIF}
end;

function N2BE(const Value: Cardinal): Cardinal;
begin
{$IFDEF BIG_ENDIAN}
  Result := Value;
{$ELSE}
  Result := Endian(Value);
{$ENDIF}
end;

function N2BE(const Value: Int64): Int64;
begin
{$IFDEF BIG_ENDIAN}
  Result := Value;
{$ELSE}
  Result := Endian(Value);
{$ENDIF}
end;

function N2BE(const Value: UInt64): UInt64;
begin
{$IFDEF BIG_ENDIAN}
  Result := Value;
{$ELSE}
  Result := Endian(Value);
{$ENDIF}
end;

function N2LE(const Value: SmallInt): SmallInt;
begin
{$IFDEF LITTLE_ENDIAN}
  Result := Value;
{$ELSE}
  Result := Endian(Value);
{$ENDIF}
end;

function N2LE(const Value: Word): Word;
begin
{$IFDEF LITTLE_ENDIAN}
  Result := Value;
{$ELSE}
  Result := Endian(Value);
{$ENDIF}
end;

function N2LE(const Value: Integer): Integer;
begin
{$IFDEF LITTLE_ENDIAN}
  Result := Value;
{$ELSE}
  Result := Endian(Value);
{$ENDIF}
end;

function N2LE(const Value: Cardinal): Cardinal;
begin
{$IFDEF LITTLE_ENDIAN}
  Result := Value;
{$ELSE}
  Result := Endian(Value);
{$ENDIF}
end;

function N2LE(const Value: Int64): Int64;
begin
{$IFDEF LITTLE_ENDIAN}
  Result := Value;
{$ELSE}
  Result := Endian(Value);
{$ENDIF}
end;

function N2LE(const Value: UInt64): UInt64;
begin
{$IFDEF LITTLE_ENDIAN}
  Result := Value;
{$ELSE}
  Result := Endian(Value);
{$ENDIF}
end;

function SAR16(const Value: SmallInt; const Shift: Byte): SmallInt;
begin
  Result := SmallInt(
    Word(Word(Word(Value) shr (Shift and 15)) or
        (Word(SmallInt(Word(0 - Word(Word(Value) shr 15)) and Word(SmallInt(0 - (Ord((Shift and 15) <> 0)))))) shl (16 - (Shift and 15)))));
end;

function SAR32(const Value: Integer; Shift: Byte): Integer;
begin
  Result := Integer(
    Cardinal(Cardinal(Cardinal(Value) shr (Shift and 31)) or
        (Cardinal(Integer(Cardinal(0 - Cardinal(Cardinal(Value) shr 31)) and Cardinal(Integer(0 - (Ord((Shift and 31) <> 0)))))) shl (32 - (Shift and 31)))));
end;

function SAR64(const Value: Int64; Shift: Byte): Int64;
begin
  Result := Int64(
    UInt64(UInt64(UInt64(Value) shr (Shift and 63)) or
        (UInt64(Int64(UInt64(0 - UInt64(UInt64(Value) shr 63)) and UInt64(Int64(0 - (Ord((Shift and 63) <> 0)))))) shl (64 - (Shift and 63)))));
end;

function MemoryAlign(addr: Pointer; alignment_: NativeUInt): Pointer;
var
  tmp: NativeUInt;
begin
  tmp := NativeUInt(addr) + (alignment_ - 1);
  Result := Pointer(tmp - (tmp mod alignment_));
end;

{$IFDEF OverflowCheck}{$Q+}{$ENDIF}
{$IFDEF RangeCheck}{$R+}{$ENDIF}


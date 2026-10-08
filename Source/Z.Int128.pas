(*
MIT License

Copyright (c) 2026 by.LaoZhang qq600585

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
*)
{
  ******************************************************************************
  * Z.Int128 - 128-bit Integer Support
  *
  * This unit provides signed and unsigned 128-bit integer types (Int128 and
  * UInt128) with full operator overloading, variant support, and atomic
  * synchronization helpers. It extends the Z-framework with high-precision
  * arithmetic capabilities for cryptography, hashing, unique ID generation,
  * and any application requiring values beyond the 64-bit range.
  *
  * Key Features:
  *   - UInt128 and Int128 records with variant storage (byte, word, dword,
  *     qword access).
  *   - Full arithmetic, bitwise, comparison, and shift operators.
  *   - Implicit/explicit conversions to/from all built-in numeric types
  *     and strings (decimal).
  *   - Custom variant types for seamless integration with Delphi/FPC Variant.
  *   - Thread-safe read/modify operations via TCritical helper.
  *   - Standard math functions: Max, Min, Clamp, InRange overloaded for 128-bit.
  *
  * Design Notes:
  *   - Values are stored in little-endian order.
  *   - Division/modulo use shift-subtract algorithm; overflow and division
  *     by zero raise exceptions.
  *   - Signed Int128 uses two's complement representation.
  *   - Variant types manage their own heap-allocated data to avoid
  *     reference-counting issues.
  *
  * Reference: Based on https://github.com/eStreamSoftware/delphi-int128
  *            with fixes for FPC and Z-framework integration.
  ******************************************************************************
}
unit Z.Int128;

{$DEFINE FPC_DELPHI_MODE}
{$I Z.Define.inc}

interface

uses Z.Core, Z.PascalStrings, Z.UPascalStrings;

type
  {$IFDEF FPC}
    TInt128_String = TUPascalString;
  {$ELSE FPC}
    TInt128_String = TPascalString;
  {$ENDIF FPC}

  { 16-byte raw storage for a 128-bit unsigned integer. }
  TUInt128_Buffer = array [0 .. 15] of UInt8;
  PUInt128_Buffer = ^TUInt128_Buffer;
  PUInt128 = ^UInt128; { Pointer to a UInt128 value. }

  {
    * UInt128 – Unsigned 128-bit integer.
    *
    * This record provides a complete set of operations for unsigned 128-bit
    * arithmetic. It uses a variant record layout to allow flexible low-level
    * access (byte, word, dword, or qword views), and overloads all standard
    * operators so you can use it just like a native integer type.
    *
    * @Example:
    *   var
    *     a, b, c: UInt128;
    *   begin
    *     a := 12345678901234567890;          // Implicit from UInt64
    *     b := '18446744073709551615';        // From decimal string
    *     c := a + b;                         // Addition
    *     if c > a then Writeln('Overflow');  // Comparison
    *     c := c shr 3;                       // Bit shift
    *     Writeln(c.ToString);                // Decimal string output
    *   end;
    *
    * Note: All operations check for overflow and raise an exception if it occurs.
    * Division by zero also raises an exception.
  }
  UInt128 = packed record
  private
    {
      * Performs unsigned division of a by b, returning both quotient and remainder.
      * Uses a shift-subtract algorithm. This is a low-level helper used by the
      * `div` and `mod` operators.
      * @param a          Dividend.
      * @param b          Divisor (must not be zero).
      * @param DivResult  Receives the quotient.
      * @param Remainder  Receives the remainder.
    }
    class procedure DivModU128(a, b: UInt128; out DivResult: UInt128; out Remainder: UInt128); static;

    {
      * Sets the bit at position `numBit` in `a` to 1.
      * Used internally by division to build the quotient.
      * @param a        The value to modify.
      * @param numBit   The bit index (0 = least significant).
    }
    class procedure SetBit128(var a: UInt128; numBit: integer); static;

  public
    {
      * Returns the decimal string representation of this value (no leading zeros).
      * @Example: (12345).ToString -> '12345'
    }
    function ToString: TInt128_String;

    {
      * Returns the decimal string representation prefixed with 'L'.
      * Useful for disambiguation in contexts where a plain number might be ambiguous.
      * @Example: (12345).ToLString -> 'L12345'
    }
    function ToLString: TInt128_String;

    { Extracts the low 64 bits as a UInt64 (truncates high bits). }
    function ToUInt64: UInt64;

    { Extracts the low 64 bits as a signed Int64 (sign-extends from bit 63). }
    function ToInt64: Int64;

    { Extracts the low 32 bits as a UInt32. }
    function ToUInt32: UInt32;

    { Extracts the low 32 bits as a signed Int32. }
    function ToInt32: Int32;

    { Extracts the low 16 bits as a UInt16. }
    function ToUInt16: UInt16;

    { Extracts the low 16 bits as a signed Int16. }
    function ToInt16: Int16;

    { Extracts the low 8 bits as a UInt8. }
    function ToUInt8: UInt8;

    { Extracts the low 8 bits as a signed Int8. }
    function ToInt8: Int8;

    { Implicitly converts a UInt8 to UInt128. }
    class operator Implicit(a: UInt8): UInt128;
    { Implicitly converts a UInt16 to UInt128. }
    class operator Implicit(a: UInt16): UInt128;
    { Implicitly converts a UInt32 to UInt128. }
    class operator Implicit(a: UInt32): UInt128;
    { Implicitly converts a UInt64 to UInt128. }
    class operator Implicit(a: UInt64): UInt128;
    {
      * Implicitly converts a Single to UInt128 (rounds to nearest integer).
      * Only the absolute value is used; negative values raise an overflow.
    }
    class operator Implicit(a: Single): UInt128;
    {
      * Implicitly converts a Double to UInt128 (rounds to nearest integer).
      * Only the absolute value is used; negative values raise an overflow.
    }
    class operator Implicit(a: Double): UInt128;

    {
      * Implicitly converts a decimal string to UInt128.
      * Supports an optional leading 'L' (case-insensitive).
      * @Example: s := '18446744073709551615'; a := UInt128(s);
    }
    class operator Implicit(a: TInt128_String): UInt128;
    class operator Implicit(a: SystemString): UInt128;

    { Implicitly converts this UInt128 to a decimal string. }
    class operator Implicit(a: UInt128): TInt128_String;
    { Implicitly converts this UInt128 to a SystemString (AnsiString in FPC, UnicodeString in Delphi). }
    class operator Implicit(a: UInt128): SystemString;

    { Explicitly converts to UInt64 (truncates high bits). }
    class operator Explicit(a: UInt128): UInt64;
    { Explicitly converts to UInt32 (truncates high bits). }
    class operator Explicit(a: UInt128): UInt32;
    { Explicitly converts to Int32 (truncates high bits, sign-extends from bit 31). }
    class operator Explicit(a: UInt128): Int32;

    { Bitwise NOT (one's complement). }
    class operator LogicalNot(a: UInt128): UInt128;
    {
      * Unary minus (raises overflow, as unsigned numbers cannot be negative).
      * Provided for completeness; using it will always raise an exception.
    }
    class operator Negative(a: UInt128): UInt128;

    { Equality comparison. }
    class operator Equal(a, b: UInt128): Boolean;
    { Inequality comparison. }
    class operator NotEqual(a, b: UInt128): Boolean;
    { Greater-than-or-equal comparison. }
    class operator GreaterThanOrEqual(a, b: UInt128): Boolean;
    { Greater-than comparison. }
    class operator GreaterThan(a, b: UInt128): Boolean;
    { Less-than-or-equal comparison. }
    class operator LessThanOrEqual(a, b: UInt128): Boolean;
    { Less-than comparison. }
    class operator LessThan(a, b: UInt128): Boolean;

    {
      * Right shift by an Int64 count.
      * If count >= 128, the result is 0 (modulo shift is applied as per compiler).
    }
    class operator RightShift(a: UInt128; b: Int64): UInt128;
    {
      * Right shift by a UInt128 count.
      * The effective shift is (b mod 128).
    }
    class operator RightShift(a, b: UInt128): UInt128;
    {
      * Left shift by an Int64 count.
      * If count >= 128, the result is 0 (modulo shift is applied as per compiler).
    }
    class operator LeftShift(a: UInt128; b: Int64): UInt128;
    {
      * Left shift by a UInt128 count.
      * The effective shift is (b mod 128).
    }
    class operator LeftShift(a, b: UInt128): UInt128;

    { Addition (raises overflow if result exceeds 2^128-1). }
    class operator Add(a, b: UInt128): UInt128;
    { Subtraction (raises overflow if b > a). }
    class operator Subtract(a, b: UInt128): UInt128;
    { Multiplication (raises overflow if result exceeds 2^128-1). }
    class operator Multiply(a, b: UInt128): UInt128;
    { Integer division (raises division by zero if b = 0). }
    class operator IntDivide(a, b: UInt128): UInt128;
    { Modulo (remainder after division; raises division by zero if b = 0). }
    class operator Modulus(a, b: UInt128): UInt128;
    {
      * Modulo with a signed Int64 divisor.
      * The divisor's absolute value is used; negative divisors become positive.
    }
    class operator Modulus(a: UInt128; b: Int64): UInt128;

    { Bitwise AND. }
    class operator BitWiseAnd(a, b: UInt128): UInt128;
    { Bitwise OR. }
    class operator BitWiseOr(a, b: UInt128): UInt128;
    { Bitwise XOR. }
    class operator BitWiseXor(a, b: UInt128): UInt128;

    { Increment by 1 (raises overflow if result exceeds 2^128-1). }
    class operator Inc(a: UInt128): UInt128;
    { Decrement by 1 (raises overflow if result would be negative). }
    class operator Dec(a: UInt128): UInt128;

  public
    {
      * Variant record layout for direct access to the 128-bit storage.
      * This allows you to read or write individual bytes, words, dwords, or qwords.
      * The layout is little-endian.
      *
      * Example:
      *   var x: UInt128;
      *   begin
      *     x := 0x112233445566778899AABBCCDDEEFF00;
      *     WriteLn(HexStr(x.b[0], 2));   // 00 (least significant byte)
      *     WriteLn(HexStr(x.w0, 4));     // FF00
      *     WriteLn(HexStr(x.c0, 8));     // DDEEFF00
      *     WriteLn(HexStr(x.dc0, 16));   // 5566778899AABBCCDDEEFF00
      *   end;
    }
    case Byte of
      0: (b: TUInt128_Buffer); // 16 bytes
      1: (w: array [0 .. 7] of UInt16); // 8 words
      2: (w0, w1, w2, w3, w4, w5, w6, w7: UInt16); // individual words
      3: (c0, c1, c2, c3: UInt32); // 4 dwords
      4: (c: array [0 .. 3] of UInt32); // dword array
      5: (dc0, dc1: UInt64); // 2 qwords
      6: (dc: array [0 .. 1] of UInt64); // qword array
  end;

  { Dynamic array of UInt128 values. }
  TUInt128_Array = array of UInt128;
  { Atomic wrapper for UInt128, using a critical section for thread-safety. }
  TAtomUInt128 = TAtomVar<UInt128>;

  { Type aliases for Int128 (signed variant). }
  TInt128_Buffer = TUInt128_Buffer;
  PInt128_Buffer = PUInt128_Buffer;
  PInt128 = ^Int128;

  {
    * Int128 – Signed 128-bit integer.
    *
    * This record provides signed 128-bit arithmetic using two's complement
    * representation. All operators are overloaded with overflow checking.
    *
    * @Example:
    *   var
    *     a, b, c: Int128;
    *   begin
    *     a := -12345678901234567890;         // From negative integer literal
    *     b := '12345678901234567890';        // From decimal string
    *     c := a + b;                         // Addition
    *     if c < a then Writeln('Overflow');  // Comparison
    *     c := c shl 2;                       // Left shift
    *     Writeln(c.ToString);                // Decimal string output
    *   end;
    *
    * Note: All operations check for overflow and raise an exception if it occurs.
    * Division by zero also raises an exception.
  }
  Int128 = packed record
  private
    {
      * Performs signed division of Value1 by Value2, returning quotient and remainder.
      * Uses a shift-subtract algorithm. Handles negative divisors and dividends.
      * @param Value1     Dividend.
      * @param Value2     Divisor (must not be zero).
      * @param DivResult  Receives the quotient.
      * @param Remainder  Receives the remainder (has the same sign as the dividend).
    }
    class procedure DivMod128(const Value1: Int128; const Value2: Int128; out DivResult: Int128; out Remainder: Int128); static;

    {
      * Increments a by 1 without overflow checking.
      * Used internally for subtraction via two's complement.
    }
    class procedure Inc128(var a: Int128); static;

    {
      * Sets the bit at position `numBit` in `a` to 1.
      * Used internally by division to build the quotient.
    }
    class procedure SetBit128(var a: Int128; numBit: integer); static;

    {
      * Converts a TInt128_String to Int128.
      * Handles an optional leading '-' for negative numbers and optional 'L' prefix.
    }
    class function StrToInt128(a: TInt128_String): Int128; static; inline;

    {
      * Returns the bitwise NOT of this value (one's complement).
      * Used internally for negation.
    }
    function Invert: Int128;

  public
    {
      * Returns the decimal string representation of this value (no leading zeros).
      * Negative values are prefixed with '-'.
      * @Example: (-12345).ToString -> '-12345'
    }
    function ToString: TInt128_String;

    {
      * Returns the decimal string representation prefixed with 'L'.
      * Useful for disambiguation in contexts where a plain number might be ambiguous.
    }
    function ToLString: TInt128_String;

    { Extracts the low 64 bits as a UInt64 (truncates high bits, sign-extends from bit 63). }
    function ToUInt64: UInt64;

    { Extracts the low 64 bits as a signed Int64 (truncates high bits). }
    function ToInt64: Int64;

    { Extracts the low 32 bits as a UInt32 (truncates high bits). }
    function ToUInt32: UInt32;

    { Extracts the low 32 bits as a signed Int32 (truncates high bits). }
    function ToInt32: Int32;

    { Extracts the low 16 bits as a UInt16 (truncates high bits). }
    function ToUInt16: UInt16;

    { Extracts the low 16 bits as a signed Int16 (truncates high bits). }
    function ToInt16: Int16;

    { Extracts the low 8 bits as a UInt8 (truncates high bits). }
    function ToUInt8: UInt8;

    { Extracts the low 8 bits as a signed Int8 (truncates high bits). }
    function ToInt8: Int8;

    { Addition (raises overflow if result exceeds signed 128-bit range). }
    class operator Add(a, b: Int128): Int128;

    { Equality comparison. }
    class operator Equal(a, b: Int128): Boolean;
    { Greater-than comparison. }
    class operator GreaterThan(a, b: Int128): Boolean;
    { Greater-than-or-equal comparison. }
    class operator GreaterThanOrEqual(a, b: Int128): Boolean;

    { Implicit conversion from Int8 (sign-extended). }
    class operator Implicit(a: Int8): Int128;
    { Implicit conversion from UInt8 (zero-extended). }
    class operator Implicit(a: UInt8): Int128;
    { Implicit conversion from Int16 (sign-extended). }
    class operator Implicit(a: Int16): Int128;
    { Implicit conversion from UInt16 (zero-extended). }
    class operator Implicit(a: UInt16): Int128;
    { Implicit conversion from Int32 (sign-extended). }
    class operator Implicit(a: Int32): Int128;
    { Implicit conversion from UInt32 (zero-extended). }
    class operator Implicit(a: UInt32): Int128;
    { Implicit conversion from Int64 (sign-extended). }
    class operator Implicit(a: Int64): Int128;
    { Implicit conversion from UInt64 (zero-extended). }
    class operator Implicit(a: UInt64): Int128;
    {
      * Implicit conversion from Single (rounds to nearest integer).
      * The value is sign-extended as needed.
    }
    class operator Implicit(a: Single): Int128;
    {
      * Implicit conversion from Double (rounds to nearest integer).
      * The value is sign-extended as needed.
    }
    class operator Implicit(a: Double): Int128;

    { Implicit conversion from this Int128 to a decimal string. }
    class operator Implicit(a: Int128): TInt128_String;
    { Implicit conversion from this Int128 to a SystemString. }
    class operator Implicit(a: Int128): SystemString;

    {
      * Implicit conversion from a decimal string to Int128.
      * Supports an optional leading '-' for negative numbers.
      * @Example: s := '-123'; a := Int128(s);
    }
    class operator Implicit(a: TInt128_String): Int128;
    class operator Implicit(a: SystemString): Int128;

    {
      * Implicit conversion from UInt128 to Int128.
      * Raises range error if the unsigned value exceeds the signed 128-bit range.
    }
    class operator Implicit(a: UInt128): Int128;
    {
      * Implicit conversion from Int128 to UInt128.
      * Raises range error if the signed value is negative.
    }
    class operator Implicit(a: Int128): UInt128;

    { Explicit conversion from UInt128 to Int128 (range-checked). }
    class operator Explicit(a: UInt128): Int128;
    { Explicit conversion from Int128 to UInt128 (range-checked). }
    class operator Explicit(a: Int128): UInt128;
    { Explicit conversion to Int32 (truncates high bits). }
    class operator Explicit(a: Int128): Int32;

    {
      * Left shift by an Int64 count.
      * If count >= 128, the result is 0 (modulo shift is applied as per compiler).
    }
    class operator LeftShift(a: Int128; Shift: Int64): Int128;
    {
      * Left shift by an Int128 count.
      * The effective shift is (Shift mod 128).
    }
    class operator LeftShift(a, Shift: Int128): Int128;

    { Less-than comparison. }
    class operator LessThan(a, b: Int128): Boolean;
    { Less-than-or-equal comparison. }
    class operator LessThanOrEqual(a, b: Int128): Boolean;

    { Bitwise NOT (one's complement). }
    class operator LogicalNot(a: Int128): Int128;
    { Multiplication (raises overflow if result exceeds signed 128-bit range). }
    class operator Multiply(a, b: Int128): Int128;
    { Inequality comparison. }
    class operator NotEqual(a, b: Int128): Boolean;
    {
      * Right shift by an Int64 count.
      * If count >= 128, the result is 0 (modulo shift is applied as per compiler).
    }
    class operator RightShift(a: Int128; Shift: Int64): Int128;
    {
      * Right shift by an Int128 count.
      * The effective shift is (Shift mod 128).
    }
    class operator RightShift(a, Shift: Int128): Int128;
    { Subtraction (raises overflow if result outside signed 128-bit range). }
    class operator Subtract(a, b: Int128): Int128;
    { Integer division (raises division by zero if b = 0). }
    class operator IntDivide(a, b: Int128): Int128;
    { Modulo (remainder; raises division by zero if b = 0, result sign follows dividend). }
    class operator Modulus(a, b: Int128): Int128;
    { Bitwise OR. }
    class operator BitWiseOr(a, b: Int128): Int128;
    { Bitwise XOR. }
    class operator BitWiseXor(a, b: Int128): Int128;
    { Bitwise AND. }
    class operator BitWiseAnd(a, b: Int128): Int128;
    {
      * Unary minus (negates the value).
      * Raises overflow if value = -2^127 (the minimum representable value).
    }
    class operator Negative(a: Int128): Int128;
    { Increment by 1 (raises overflow if result exceeds 2^127-1). }
    class operator Inc(a: Int128): Int128;
    { Decrement by 1 (raises overflow if result goes below -2^127). }
    class operator Dec(a: Int128): Int128;

  public
    {
      * Variant record layout for direct access to the 128-bit storage.
      * This allows you to read or write individual bytes, words, dwords, or qwords.
      * The layout is little-endian and the value is stored in two's complement.
      *
      * Example:
      *   var x: Int128;
      *   begin
      *     x := -1;
      *     WriteLn(HexStr(x.b[0], 2));   // FF
      *     WriteLn(HexStr(x.w0, 4));     // FFFF
      *     WriteLn(HexStr(x.c0, 8));     // FFFFFFFF
      *     WriteLn(HexStr(x.dc0, 16));   // FFFFFFFFFFFFFFFF
      *   end;
    }
    case Byte of
      0: (b: TInt128_Buffer); // 16 bytes
      1: (w: array [0 .. 7] of UInt16); // 8 words
      2: (w0, w1, w2, w3, w4, w5, w6, w7: UInt16); // individual words
      3: (c0, c1, c2, c3: UInt32); // 4 dwords
      4: (c: array [0 .. 3] of UInt32); // dword array
      5: (dc0, dc1: UInt64); // 2 qwords
      6: (dc: array [0 .. 1] of UInt64); // qword array
  end;

  { Dynamic array of Int128 values. }
  TInt128_Array = array of Int128;
  { Atomic wrapper for Int128, using a critical section for thread-safety. }
  TAtomInt128 = TAtomVar<Int128>;

  { -------------------- Standard Math Functions (overloaded for 128-bit) -------------------- }

  { ----------------------------------------------------------------------------
    Comparison functions for primitive types. They return:
    -1 if first < second,
    0 if equal,
    1 if first > second.
    Used for sorting and ordering.
  }
function CompareCardinal(const c1, c2: Cardinal): integer;
function CompareInteger(const Int1, Int2: integer): integer;
function CompareInt64(const Int1, Int2: Int64): integer;
function CompareUInt64(const Int1, Int2: UInt64): integer;
function ComparePointer(const Item1, Item2: pointer): integer;
function CompareBool(const Bool1, Bool2: Boolean): integer;
function CompareDouble(const Double1, Double2: Double): integer;
function CompareInt128(const Int1, Int2: Int128): integer;
function CompareUInt128(const Int1, Int2: UInt128): integer;

{ Returns the larger of two UInt64 values. }
function Max(const v1, v2: UInt64): UInt64; overload;
{ Returns the larger of two Cardinal values. }
function Max(const v1, v2: Cardinal): Cardinal; overload;
{ Returns the larger of two Word values. }
function Max(const v1, v2: Word): Word; overload;
{ Returns the larger of two Byte values. }
function Max(const v1, v2: Byte): Byte; overload;
{ Returns the larger of two Int64 values. }
function Max(const v1, v2: Int64): Int64; overload;
{ Returns the larger of two Integer values. }
function Max(const v1, v2: integer): integer; overload;
{ Returns the larger of two SmallInt values. }
function Max(const v1, v2: SmallInt): SmallInt; overload;
{ Returns the larger of two ShortInt values. }
function Max(const v1, v2: ShortInt): ShortInt; overload;
{ Returns the larger of two Double values. }
function Max(const v1, v2: Double): Double; overload;
{ Returns the larger of two Single values. }
function Max(const v1, v2: Single): Single; overload;
{ Returns the larger of two UInt128 values. }
function Max(const v1, v2: UInt128): UInt128; overload;
{ Returns the larger of two Int128 values. }
function Max(const v1, v2: Int128): Int128; overload;

{ Returns the smaller of two UInt64 values. }
function Min(const v1, v2: UInt64): UInt64; overload;
{ Returns the smaller of two Cardinal values. }
function Min(const v1, v2: Cardinal): Cardinal; overload;
{ Returns the smaller of two Word values. }
function Min(const v1, v2: Word): Word; overload;
{ Returns the smaller of two Byte values. }
function Min(const v1, v2: Byte): Byte; overload;
{ Returns the smaller of two Int64 values. }
function Min(const v1, v2: Int64): Int64; overload;
{ Returns the smaller of two Integer values. }
function Min(const v1, v2: integer): integer; overload;
{ Returns the smaller of two SmallInt values. }
function Min(const v1, v2: SmallInt): SmallInt; overload;
{ Returns the smaller of two ShortInt values. }
function Min(const v1, v2: ShortInt): ShortInt; overload;
{ Returns the smaller of two Double values. }
function Min(const v1, v2: Double): Double; overload;
{ Returns the smaller of two Single values. }
function Min(const v1, v2: Single): Single; overload;
{ Returns the smaller of two UInt128 values. }
function Min(const v1, v2: UInt128): UInt128; overload;
{ Returns the smaller of two Int128 values. }
function Min(const v1, v2: Int128): Int128; overload;

{
  * Clamps an integer value between min_ and max_ (inclusive).
  * If min_ > max_, the function swaps them before clamping.
}
function Clamp(const v, min_, max_: integer): integer; overload;
{
  * Clamps a UInt64 value between min_ and max_ (inclusive).
  * If min_ > max_, the function swaps them before clamping.
}
function Clamp(const v, min_, max_: UInt64): UInt64; overload;
{
  * Clamps a Cardinal value between min_ and max_ (inclusive).
  * If min_ > max_, the function swaps them before clamping.
}
function Clamp(const v, min_, max_: Cardinal): Cardinal; overload;
{
  * Clamps a Word value between min_ and max_ (inclusive).
  * If min_ > max_, the function swaps them before clamping.
}
function Clamp(const v, min_, max_: Word): Word; overload;
{
  * Clamps a Byte value between min_ and max_ (inclusive).
  * If min_ > max_, the function swaps them before clamping.
}
function Clamp(const v, min_, max_: Byte): Byte; overload;
{
  * Clamps an Int64 value between min_ and max_ (inclusive).
  * If min_ > max_, the function swaps them before clamping.
}
function Clamp(const v, min_, max_: Int64): Int64; overload;
{
  * Clamps a SmallInt value between min_ and max_ (inclusive).
  * If min_ > max_, the function swaps them before clamping.
}
function Clamp(const v, min_, max_: SmallInt): SmallInt; overload;
{
  * Clamps a ShortInt value between min_ and max_ (inclusive).
  * If min_ > max_, the function swaps them before clamping.
}
function Clamp(const v, min_, max_: ShortInt): ShortInt; overload;
{
  * Clamps a Double value between min_ and max_ (inclusive).
  * If min_ > max_, the function swaps them before clamping.
}
function Clamp(const v, min_, max_: Double): Double; overload;
{
  * Clamps a Single value between min_ and max_ (inclusive).
  * If min_ > max_, the function swaps them before clamping.
}
function Clamp(const v, min_, max_: Single): Single; overload;
{
  * Clamps a UInt128 value between min_ and max_ (inclusive).
  * If min_ > max_, the function swaps them before clamping.
}
function Clamp(const v, min_, max_: UInt128): UInt128; overload;
{
  * Clamps an Int128 value between min_ and max_ (inclusive).
  * If min_ > max_, the function swaps them before clamping.
}
function Clamp(const v, min_, max_: Int128): Int128; overload;

{ Checks if an integer value is within [min_, max_] (inclusive). }
function InRange(const v, min_, max_: integer): Boolean; overload;
{ Checks if a UInt64 value is within [min_, max_] (inclusive). }
function InRange(const v, min_, max_: UInt64): Boolean; overload;
{ Checks if a Cardinal value is within [min_, max_] (inclusive). }
function InRange(const v, min_, max_: Cardinal): Boolean; overload;
{ Checks if a Word value is within [min_, max_] (inclusive). }
function InRange(const v, min_, max_: Word): Boolean; overload;
{ Checks if a Byte value is within [min_, max_] (inclusive). }
function InRange(const v, min_, max_: Byte): Boolean; overload;
{ Checks if an Int64 value is within [min_, max_] (inclusive). }
function InRange(const v, min_, max_: Int64): Boolean; overload;
{ Checks if a SmallInt value is within [min_, max_] (inclusive). }
function InRange(const v, min_, max_: SmallInt): Boolean; overload;
{ Checks if a ShortInt value is within [min_, max_] (inclusive). }
function InRange(const v, min_, max_: ShortInt): Boolean; overload;
{ Checks if a Double value is within [min_, max_] (inclusive). }
function InRange(const v, min_, max_: Double): Boolean; overload;
{ Checks if a Single value is within [min_, max_] (inclusive). }
function InRange(const v, min_, max_: Single): Boolean; overload;
{ Checks if a UInt128 value is within [min_, max_] (inclusive). }
function InRange(const v, min_, max_: UInt128): Boolean; overload;
{ Checks if an Int128 value is within [min_, max_] (inclusive). }
function InRange(const v, min_, max_: Int128): Boolean; overload;

const
  {
    * Custom variant type code for UInt128.
    * This constant is registered in the initialization section.
    * You can use this with VarType to check if a Variant holds a UInt128.
    * @Example:
    *   if VarType(V) = varType_UInt128 then ...
  }
  varType_UInt128 = $187;

  {
    * Constant 10 as a UInt128. Used internally for decimal string conversion.
    * You can use this constant for multiplication or addition in your own code.
  }
  Ten: UInt128 = (dc0: $A; dc1: 0);

  {
    * Constant -1 as an Int128. Used internally for overflow checks.
    * This is the minimum negative value representable in 128-bit two's complement.
  }
  Neg1: Int128 = (dc0: 0; dc1: $8000000000000000);

implementation

class procedure UInt128.DivModU128(a, b: UInt128; out DivResult: UInt128; out Remainder: UInt128);
var
  Shift: integer;
begin
  if b = 0 then
      RaiseInfo('Division by zero');

  if a = 0 then
    begin
      DivResult := 0;
      Remainder := 0;
      Exit;
    end;

  if a < b then
    begin
      DivResult := 0;
      Remainder := a;
      Exit;
    end;

  DivResult := 0;
  Remainder := a;
  Shift := 0;

  while (b < Remainder) and (b.c3 and $80000000 = 0) do
    begin
      if Shift = 124 then
          break;
      b := b shl 1;
      Inc(Shift);
      if b > Remainder then
        begin
          b := b shr 1;
          Dec(Shift);
          break;
        end;
    end;

  while True do
    begin
      if b <= Remainder then
        begin
          Remainder := Remainder - b;
          SetBit128(DivResult, Shift);
        end;

      if Shift > 0 then
        begin
          b := b shr 1;
          Dec(Shift);
        end
      else
          break;

    end;
end;

class procedure UInt128.SetBit128(var a: UInt128; numBit: integer);
begin
  a.c[numBit shr 5] := a.c[numBit shr 5] or longword(1 shl (numBit and 31));
end;

function UInt128.ToString: TInt128_String;
begin
  Result := Self;
end;

function UInt128.ToLString: TInt128_String;
begin
  Result := 'L' + ToString;
end;

function UInt128.ToUInt64: UInt64;
begin
  Result := dc0;
end;

function UInt128.ToInt64: Int64;
begin
  Result := dc0;
end;

function UInt128.ToUInt32: UInt32;
begin
  Result := c0;
end;

function UInt128.ToInt32: Int32;
begin
  Result := c0;
end;

function UInt128.ToUInt16: UInt16;
begin
  Result := w0;
end;

function UInt128.ToInt16: Int16;
begin
  Result := w0;
end;

function UInt128.ToUInt8: UInt8;
begin
  Result := b[0];
end;

function UInt128.ToInt8: Int8;
begin
  Result := b[0];
end;

class operator UInt128.Implicit(a: UInt8): UInt128;
begin
  Result.b[0] := a;
  FillPtr(@Result.b[1], SizeOf(Result) - SizeOf(Result.b[0]), 0);
end;

class operator UInt128.Implicit(a: UInt16): UInt128;
begin
  Result.w[0] := a;
  FillPtr(@Result.w[1], SizeOf(Result) - SizeOf(Result.w[0]), 0);
end;

class operator UInt128.Implicit(a: UInt32): UInt128;
begin
  Result.c[0] := a;
  FillPtr(@Result.c[1], SizeOf(Result) - SizeOf(Result.c[0]), 0);
end;

class operator UInt128.Implicit(a: UInt64): UInt128;
begin
  Result.dc0 := a;
  Result.dc1 := 0;
end;

class operator UInt128.Implicit(a: Single): UInt128;
begin
  Result.dc0 := round(abs(a));
  Result.dc1 := 0;
end;

class operator UInt128.Implicit(a: Double): UInt128;
begin
  Result.dc0 := round(abs(a));
  Result.dc1 := 0;
end;

class operator UInt128.Implicit(a: TInt128_String): UInt128;
var
  i: integer;
begin
  Result := 0;

  if CharIn(a.First, ['L', 'l']) then
      a.DeleteFirst;

  for i := 1 to a.L do
    begin
      if CharIn(a[i], c0to9) then
        begin
          Result := Result * Ten;
          Result := Result + UInt32(Ord(a[i]) - Ord('0'));
        end
      else
          RaiseInfo(a + ' is not a valid Int128 a.');
    end;
end;

class operator UInt128.Implicit(a: SystemString): UInt128;
begin
  Result := TInt128_String(a);
end;

class operator UInt128.Implicit(a: UInt128): TInt128_String;
var
  digit: UInt128;
begin
  Result := '';

  while a <> 0 do
    begin
      DivModU128(a, Ten, a, digit);
      Result := Chr(Ord('0') + digit.c0) + Result;
    end;

  if Result = '' then
      Result := '0';
end;

class operator UInt128.Implicit(a: UInt128): SystemString;
begin
  Result := TInt128_String(a).Text;
end;

class operator UInt128.Explicit(a: UInt128): UInt64;
begin
  Result := a.dc0;
end;

class operator UInt128.Explicit(a: UInt128): UInt32;
begin
  Result := a.c0;
end;

class operator UInt128.Explicit(a: UInt128): Int32;
begin
  Result := a.c0;
end;

class operator UInt128.LogicalNot(a: UInt128): UInt128;
begin
  Result.dc0 := not a.dc0;
  Result.dc1 := not a.dc1;
end;

class operator UInt128.Negative(a: UInt128): UInt128;
begin
  RaiseInfo('Integer overflow');
end;

class operator UInt128.Equal(a: UInt128; b: UInt128): Boolean;
begin
  Result := True;
  if a.dc0 <> b.dc0 then
      Result := false;
  if a.dc1 <> b.dc1 then
      Result := false;
end;

class operator UInt128.NotEqual(a: UInt128; b: UInt128): Boolean;
begin
  Result := (a.dc0 <> b.dc0) or (a.dc1 <> b.dc1);
end;

class operator UInt128.GreaterThanOrEqual(a, b: UInt128): Boolean;
begin
  Result := (a = b) or (a > b);
end;

class operator UInt128.GreaterThan(a, b: UInt128): Boolean;
begin
  Result := false;
  if a.dc1 > b.dc1 then
      Result := True;
  if a.dc1 = b.dc1 then
    if a.dc0 > b.dc0 then
        Result := True;
end;

class operator UInt128.LessThanOrEqual(a, b: UInt128): Boolean;
begin
  Result := (a = b) or (a < b);
end;

class operator UInt128.LessThan(a, b: UInt128): Boolean;
begin
  Result := false;
  if a.dc1 < b.dc1 then
      Result := True
  else if a.dc1 = b.dc1 then
    if a.dc0 < b.dc0 then
        Result := True;
end;

class operator UInt128.RightShift(a: UInt128; b: Int64): UInt128;
begin
  if b >= 128 then
      Result := a shr (b mod 128) // follow compiler
  else if b >= 64 then
    begin
      Result.dc1 := 0;
      Result.dc0 := a.dc1 shr (b - 64);
    end
  else if b > 0 then
    begin
      Result.dc0 := (a.dc0 shr b) or (a.dc1 shl (64 - b));
      Result.dc1 := a.dc1 shr b;
    end
  else if b = 0 then
      Result := a
  else if b < 0 then
      Result := a shr (128 - (abs(b) mod 128)); // follow compiler
end;

class operator UInt128.RightShift(a: UInt128; b: UInt128): UInt128;
begin
  Result := a shr UInt32(b mod 128);
end;

class operator UInt128.LeftShift(a: UInt128; b: Int64): UInt128;
begin
  if b >= 128 then
      Result := a shl (b mod 128) // follow compiler
  else if b >= 64 then
    begin
      Result.dc0 := 0;
      Result.dc1 := a.dc0 shl (b - 64);
    end
  else if b > 0 then
    begin
      Result.dc1 := (a.dc1 shl b) or (a.dc0 shr (64 - b));
      Result.dc0 := a.dc0 shl b;
    end
  else if b = 0 then
      Result := a
  else if b < 0 then
      Result := a shl (128 - (abs(b) mod 128)); // follow compiler
end;

class operator UInt128.LeftShift(a: UInt128; b: UInt128): UInt128;
begin
  Result := a shl UInt32(b mod 128);
end;

class operator UInt128.Add(a, b: UInt128): UInt128;
  procedure inc3;
  begin
    if Result.c3 = High(Result.c3) then
      begin
        RaiseInfo('Integer overflow');
      end
    else
        Inc(Result.c3);
  end;

  procedure inc2;
  begin
    if Result.c2 = High(Result.c2) then
      begin
        Result.c2 := 0;
        inc3;
      end
    else
        Inc(Result.c2);
  end;

  procedure inc1;
  begin
    if Result.c1 = High(Result.c1) then
      begin
        Result.c1 := 0;
        inc2;
      end
    else
        Inc(Result.c1);
  end;

var
  qw: UInt64;
  c0, c1, c2, c3: Boolean;
begin
  qw := UInt64(a.c0) + UInt64(b.c0);
  Result.c0 := qw and High(Result.c0);
  c0 := (qw shr 32) = 1;
  qw := UInt64(a.c1) + UInt64(b.c1);
  Result.c1 := qw and High(Result.c1);
  c1 := (qw shr 32) = 1;
  qw := UInt64(a.c2) + UInt64(b.c2);
  Result.c2 := qw and High(Result.c2);
  c2 := (qw shr 32) = 1;
  qw := UInt64(a.c3) + UInt64(b.c3);
  Result.c3 := qw and High(Result.c3);
  c3 := (qw shr 32) = 1;
  if c0 then
      inc1;
  if c1 then
      inc2;
  if c2 then
      inc3;
  if c3 then
      RaiseInfo('Integer overflow');
end;

class operator UInt128.Subtract(a, b: UInt128): UInt128;
begin
  if b > a then
      RaiseInfo('Integer overflow')
  else
    begin
      Result.dc0 := a.dc0 - b.dc0;
      Result.dc1 := a.dc1 - b.dc1;

      if Result.dc0 > a.dc0 then
          Dec(Result.dc1);
    end;
end;

class operator UInt128.Multiply(a: UInt128; b: UInt128): UInt128;
var
  qw: UInt64;
  v: UInt128;
  over: Boolean;
begin
  over := false;

  qw := UInt64(a.c0) * UInt64(b.c0);
  Result.c0 := qw and High(Result.c0);
  Result.c1 := qw shr 32;
  Result.c2 := 0;
  Result.c3 := 0;

  qw := UInt64(a.c0) * UInt64(b.c1);
  v.c0 := 0;
  v.c1 := qw and High(v.c1);
  v.c2 := qw shr 32;
  v.c3 := 0;
  Result := Result + v;

  qw := UInt64(a.c1) * UInt64(b.c0);
  v.c0 := 0;
  v.c1 := qw and High(v.c1);
  v.c2 := qw shr 32;
  v.c3 := 0;
  Result := Result + v;

  qw := UInt64(a.c0) * UInt64(b.c2);
  v.c0 := 0;
  v.c1 := 0;
  v.c2 := qw and High(v.c2);
  v.c3 := qw shr 32;
  Result := Result + v;

  qw := UInt64(a.c1) * UInt64(b.c1);
  v.c0 := 0;
  v.c1 := 0;
  v.c2 := qw and High(v.c2);
  v.c3 := qw shr 32;
  Result := Result + v;

  qw := UInt64(a.c2) * UInt64(b.c0);
  v.c0 := 0;
  v.c1 := 0;
  v.c2 := qw and High(v.c2);
  v.c3 := qw shr 32;
  Result := Result + v;

  qw := UInt64(a.c0) * UInt64(b.c3);
  v.c0 := 0;
  v.c1 := 0;
  v.c2 := 0;
  v.c3 := qw and High(v.c3);
  if qw shr 32 <> 0 then
      over := True;
  Result := Result + v;

  qw := UInt64(a.c1) * UInt64(b.c2);
  v.c0 := 0;
  v.c1 := 0;
  v.c2 := 0;
  v.c3 := qw and High(v.c3);
  if qw shr 32 <> 0 then
      over := True;
  Result := Result + v;

  qw := UInt64(a.c2) * UInt64(b.c1);
  v.c0 := 0;
  v.c1 := 0;
  v.c2 := 0;
  v.c3 := qw and High(v.c3);
  if qw shr 32 <> 0 then
      over := True;
  Result := Result + v;

  qw := UInt64(a.c3) * UInt64(b.c0);
  v.c0 := 0;
  v.c1 := 0;
  v.c2 := 0;
  v.c3 := qw and High(v.c3);
  if qw shr 32 <> 0 then
      over := True;
  Result := Result + v;

  if over then
      RaiseInfo('Integer overflow');
  if (Result = 0) and (a <> 0) and (b <> 0) then
      RaiseInfo('Integer overflow');
end;

class operator UInt128.IntDivide(a: UInt128; b: UInt128): UInt128;
var
  temp: UInt128;
begin
  DivModU128(a, b, Result, temp);
end;

class operator UInt128.Modulus(a, b: UInt128): UInt128;
var
  temp: UInt128;
begin
  DivModU128(a, b, temp, Result);
end;

class operator UInt128.Modulus(a: UInt128; b: Int64): UInt128;
var
  temp: UInt128;
begin
  if b < 0 then
      b := -b;
  DivModU128(a, b, temp, Result);
end;

class operator UInt128.BitWiseAnd(a, b: UInt128): UInt128;
begin
  Result.dc0 := a.dc0 and b.dc0;
  Result.dc1 := a.dc1 and b.dc1;
end;

class operator UInt128.BitWiseOr(a, b: UInt128): UInt128;
begin
  Result.dc0 := a.dc0 or b.dc0;
  Result.dc1 := a.dc1 or b.dc1;
end;

class operator UInt128.BitWiseXor(a, b: UInt128): UInt128;
begin
  Result.dc0 := a.dc0 xor b.dc0;
  Result.dc1 := a.dc1 xor b.dc1;
end;

class operator UInt128.Inc(a: UInt128): UInt128;
begin
  Result := a + UInt128(1);
end;

class operator UInt128.Dec(a: UInt128): UInt128;
begin
  Result := a - UInt128(1);
end;

class procedure Int128.DivMod128(const Value1: Int128; const Value2: Int128; out DivResult: Int128; out Remainder: Int128);
var
  curShift: integer;
  sub: Int128;
  neg, bIsNeg1: Boolean;
begin
  if Value2 = 0 then
      RaiseInfo('Division by zero');

  sub := Value2;
  Remainder := Value1;
  DivResult := 0;

  neg := (sub.c3 and $80000000 <> 0) xor (Remainder.c3 and $80000000 <> 0);

  if (sub.c3 and $80000000 <> 0) then
      sub := -sub;

  bIsNeg1 := Remainder = Neg1;

  if bIsNeg1 then
      Remainder := Remainder.Invert
  else if (Remainder.c3 and $80000000 <> 0) then
      Remainder := -Remainder;

  // if divisor = 1
  if sub = 1 then
    begin
      if (Value1 < 0) and neg then
          DivResult := Value1
      else if (Value1 > 0) and neg then
          DivResult := -Value1
      else if Value1 < 0 then
          DivResult := -Value1
      else
          DivResult := Value1;
      Remainder := 0;
      Exit;
    end;

  curShift := 0;
  while (sub.c3 and $80000000 = 0) and (sub < Remainder) do
    begin
      if curShift = 123 then
          break;
      sub := sub shl 1;
      Inc(curShift);
      if (sub > Remainder) then
        begin
          sub := sub shr 1;
          Dec(curShift);
          break;
        end;
    end;

  while True do
    begin
      if sub <= Remainder then
        begin
          Remainder := Remainder - sub;
          SetBit128(DivResult, curShift);
        end;
      if curShift > 0 then
        begin
          sub := sub shr 1;
          Dec(curShift);
        end
      else
          break;
    end;

  if neg then
      DivResult := -DivResult;

  if bIsNeg1 then
      Remainder := Remainder + 1;
end;

class procedure Int128.Inc128(var a: Int128);
begin
  if a.c0 <> High(a.c0) then
      Inc(a.c0)
  else
    begin
      a.c0 := 0;
      if a.c1 <> High(a.c1) then
          Inc(a.c1)
      else
        begin
          a.c1 := 0;
          if a.c2 <> High(a.c2) then
              Inc(a.c2)
          else
            begin
              a.c2 := 0;
              if a.c3 <> High(a.c3) then
                  Inc(a.c3)
              else
                  a.c3 := 0;
            end;
        end;
    end;
end;

class procedure Int128.SetBit128(var a: Int128; numBit: integer);
begin
  a.c[numBit shr 5] := a.c[numBit shr 5] or UInt32(1 shl (numBit and 31));
end;

class function Int128.StrToInt128(a: TInt128_String): Int128;
var
  IsNeg: Boolean;
  i: integer;
  iDigit: Int128;
begin
  if a.L = 0 then
    begin
      Result := 0;
      Exit;
    end;

  if CharIn(a.First, ['L', 'l']) then
      a.DeleteFirst;

  Result := 0;
  IsNeg := a[1] = '-';
  i := 1;
  if IsNeg then
      i := 2;

  for i := i to a.L - 1 do
    begin
      if CharIn(a[i], c0to9) then
          Result := Result * Ten + (Ord(a[i]) - Ord('0'))
      else
          RaiseInfo(a + ' is not a valid Int128 a.');
    end;

  i := a.L;
  if CharIn(a[i], c0to9) then
    begin
      Result := Result * Ten;
      iDigit := Ord(a[i]) - Ord('0');
      if IsNeg then
          Result := -Result - iDigit
      else
          Result := Result + iDigit;
    end
  else
      RaiseInfo(a + ' is not a valid Int128 a.');
end;

function Int128.Invert: Int128;
begin
  Result.dc0 := Self.dc0 xor High(Self.dc0);
  Result.dc1 := Self.dc1 xor High(Self.dc1);
end;

function Int128.ToString: TInt128_String;
begin
  Result := Self;
end;

function Int128.ToLString: TInt128_String;
begin
  Result := 'L' + ToString;
end;

function Int128.ToUInt64: UInt64;
begin
  Result := dc0;
end;

function Int128.ToInt64: Int64;
begin
  Result := dc0;
end;

function Int128.ToUInt32: UInt32;
begin
  Result := c0;
end;

function Int128.ToInt32: Int32;
begin
  Result := c0;
end;

function Int128.ToUInt16: UInt16;
begin
  Result := w0;
end;

function Int128.ToInt16: Int16;
begin
  Result := w0;
end;

function Int128.ToUInt8: UInt8;
begin
  Result := b[0];
end;

function Int128.ToInt8: Int8;
begin
  Result := b[0];
end;

class operator Int128.Add(a, b: Int128): Int128;
  procedure inc3;
  begin
    if Result.c3 = High(Result.c3) then
      begin
        Result.c3 := 0;
      end
    else
        Inc(Result.c3);
  end;

  procedure inc2;
  begin
    if Result.c2 = High(Result.c2) then
      begin
        Result.c2 := 0;
        inc3;
      end
    else
        Inc(Result.c2);
  end;

  procedure inc1;
  begin
    if Result.c1 = High(Result.c1) then
      begin
        Result.c1 := 0;
        inc2;
      end
    else
        Inc(Result.c1);
  end;

var
  qw: UInt64;
  c0, c1, c2: Boolean;
begin
  qw := UInt64(a.c0) + UInt64(b.c0);
  Result.c0 := qw and High(Result.c0);
  c0 := (qw shr 32) = 1;

  qw := UInt64(a.c1) + UInt64(b.c1);
  Result.c1 := qw and High(Result.c1);
  c1 := (qw shr 32) = 1;

  qw := UInt64(a.c2) + UInt64(b.c2);
  Result.c2 := qw and High(Result.c2);
  c2 := (qw shr 32) = 1;

  qw := UInt64(a.c3) + UInt64(b.c3);
  Result.c3 := qw and High(Result.c3);

  if c0 then
      inc1;
  if c1 then
      inc2;
  if c2 then
      inc3;

  if (Result < 0) and (a > 0) and (b > 0) then
      RaiseInfo('Integer overflow');

  if (Result > 0) and (a < 0) and (b < 0) then
      RaiseInfo('Integer overflow');
end;

class operator Int128.Equal(a, b: Int128): Boolean;
begin
  Result := (a.dc0 = b.dc0) and (a.dc1 = b.dc1);
end;

class operator Int128.GreaterThan(a, b: Int128): Boolean;
begin
  Result := false;
  if Int64(a.dc1) > Int64(b.dc1) then
      Result := True
  else if a.dc1 = b.dc1 then
    begin
      if a.dc0 > b.dc0 then
          Result := True;
    end;
end;

class operator Int128.GreaterThanOrEqual(a, b: Int128): Boolean;
begin
  Result := (a = b) or (a > b);
end;

class operator Int128.Implicit(a: Int8): Int128;
var
  Sign: Byte;
begin
  Sign := 0;
  Result.b[0] := UInt8(a);
  if a < 0 then
      Sign := $FF;
  FillPtr(@Result.b[1], SizeOf(Result) - SizeOf(Result.b[0]), Sign);
end;

class operator Int128.Implicit(a: UInt8): Int128;
begin
  Result.b[0] := a;
  FillPtr(@Result.b[1], SizeOf(Result) - SizeOf(Result.b[0]), 0);
end;

class operator Int128.Implicit(a: Int16): Int128;
var
  Sign: Byte;
begin
  Sign := 0;
  Result.w[0] := UInt16(a);
  if a < 0 then
      Sign := $FF;
  FillPtr(@Result.w[1], SizeOf(Result) - SizeOf(Result.w[0]), Sign);
end;

class operator Int128.Implicit(a: UInt16): Int128;
begin
  Result.w[0] := a;
  FillPtr(@Result.w[1], SizeOf(Result) - SizeOf(Result.w[0]), 0);
end;

class operator Int128.Implicit(a: Int32): Int128;
var
  Sign: Byte;
begin
  Sign := 0;
  Result.c[0] := UInt32(a);
  if a < 0 then
      Sign := $FF;
  FillPtr(@Result.c[1], SizeOf(Result) - SizeOf(Result.c[0]), Sign);
end;

class operator Int128.Implicit(a: UInt32): Int128;
begin
  Result.c[0] := a;
  FillPtr(@Result.c[1], SizeOf(Result) - SizeOf(Result.c[0]), 0);
end;

class operator Int128.Implicit(a: Int64): Int128;
var
  Sign: Byte;
begin
  Sign := 0;
  Result.dc[0] := UInt64(a);
  if a < 0 then
      Sign := $FF;
  FillPtr(@Result.dc[1], SizeOf(Result) - SizeOf(Result.dc[0]), Sign);
end;

class operator Int128.Implicit(a: UInt64): Int128;
begin
  Result.dc0 := a;
  Result.dc1 := 0;
end;

class operator Int128.Implicit(a: Single): Int128;
var
  Sign: Byte;
begin
  Sign := 0;
  Result.dc[0] := round(abs(a));
  if a < 0 then
      Sign := $FF;
  FillPtr(@Result.dc[1], SizeOf(Result) - SizeOf(Result.dc[0]), Sign);
end;

class operator Int128.Implicit(a: Double): Int128;
var
  Sign: Byte;
begin
  Sign := 0;
  Result.dc[0] := round(abs(a));
  if a < 0 then
      Sign := $FF;
  FillPtr(@Result.dc[1], SizeOf(Result) - SizeOf(Result.dc[0]), Sign);
end;

class operator Int128.Implicit(a: Int128): TInt128_String;
var
  digit, curValue, nextValue: Int128;
  neg: Boolean;
begin
  Result := '';
  if a.b[15] shr 7 = 1 then
    begin
      curValue := UInt128(a.Invert()) + 1;
      neg := True;
    end
  else
    begin
      curValue := a;
      neg := false;
    end;

  while curValue <> 0 do
    begin
      DivMod128(curValue, Ten, nextValue, digit);
      Result := Chr(Ord('0') + digit.c0) + Result;
      curValue := nextValue;
    end;

  if Result = '' then
      Result := '0';
  if neg then
      Result := '-' + Result;
end;

class operator Int128.Implicit(a: Int128): SystemString;
begin
  Result := TInt128_String(a).Text;
end;

class operator Int128.Implicit(a: TInt128_String): Int128;
begin
  Result := StrToInt128(a);
end;

class operator Int128.Implicit(a: SystemString): Int128;
begin
  Result := StrToInt128(a);
end;

class operator Int128.Implicit(a: UInt128): Int128;
begin
  Result.dc0 := UInt64(a and High(UInt64));
  Result.dc1 := UInt64(a shr 64);
end;

class operator Int128.Implicit(a: Int128): UInt128;
begin
  // if a is -ve, implicit not able to convert
  // if (a.c3 and $80000000) <> 0 then
  // RaiseInfo('Range Check Error');

  Result := TInt128_String(a);
end;

class operator Int128.Explicit(a: UInt128): Int128;
begin
  Result := a;
end;

class operator Int128.Explicit(a: Int128): UInt128;
begin
  Result := UInt128(a.dc0);
  Result := Result or (UInt128(a.dc1) shl 64);
end;

class operator Int128.Explicit(a: Int128): Int32;
begin
  Result := a.c0;
end;

class operator Int128.LeftShift(a: Int128; Shift: Int64): Int128;
begin
  if Shift >= 128 then
      Result := a shl (Shift mod 128)
  else if Shift >= 64 then
    begin
      Result.dc1 := a.dc0;
      Result.dc0 := 0;
      Result := Result shl (Shift - 64);
    end
  else if Shift > 0 then
    begin
      Result.dc1 := (a.dc1 shl Shift) or (a.dc0 shr (64 - Shift));
      Result.dc0 := a.dc0 shl Shift;
    end
  else if Shift = 0 then
      Result := a
  else if Shift < 0 then
      Result := a shl (128 - (abs(Shift) mod 128));
end;

class operator Int128.LeftShift(a, Shift: Int128): Int128;
begin
  if Shift < 0 then
      Result := a shl Int32(128 - ((-Shift) mod 128))
  else
      Result := a shl Int32(Shift mod 128);
end;

class operator Int128.LessThan(a, b: Int128): Boolean;
begin
  Result := false;
  if Int64(a.dc1) < Int64(b.dc1) then
      Result := True
  else if a.dc1 = b.dc1 then
    begin
      if a.dc0 < b.dc0 then
          Result := True;
    end;
end;

class operator Int128.LessThanOrEqual(a, b: Int128): Boolean;
begin
  Result := (a = b) or (a < b);
end;

class operator Int128.LogicalNot(a: Int128): Int128;
begin
  Result.dc0 := not a.dc0;
  Result.dc1 := not a.dc1;
end;

class operator Int128.Multiply(a, b: Int128): Int128;
var
  qw: UInt64;
  v: Int128;
  neg, over: Boolean;
begin
  neg := false;
  over := false;
  if (a < 0) xor (b < 0) then
      neg := True;

  if a < 0 then
      a := -a;
  if b < 0 then
      b := -b;

  qw := UInt64(a.c0) * UInt64(b.c0);
  Result.c0 := qw and High(Result.c0);
  Result.c1 := qw shr 32;
  Result.c2 := 0;
  Result.c3 := 0;

  qw := UInt64(a.c0) * UInt64(b.c1);
  v.c0 := 0;
  v.c1 := qw and High(v.c1);
  v.c2 := qw shr 32;
  v.c3 := 0;
  Result := Result + v;

  qw := UInt64(a.c1) * UInt64(b.c0);
  v.c0 := 0;
  v.c1 := qw and High(v.c1);
  v.c2 := qw shr 32;
  v.c3 := 0;
  Result := Result + v;

  qw := UInt64(a.c0) * UInt64(b.c2);
  v.c0 := 0;
  v.c1 := 0;
  v.c2 := qw and High(v.c2);
  v.c3 := qw shr 32;
  Result := Result + v;

  qw := UInt64(a.c1) * UInt64(b.c1);
  v.c0 := 0;
  v.c1 := 0;
  v.c2 := qw and High(v.c2);
  v.c3 := qw shr 32;
  Result := Result + v;

  qw := UInt64(a.c2) * UInt64(b.c0);
  v.c0 := 0;
  v.c1 := 0;
  v.c2 := qw and High(v.c2);
  v.c3 := qw shr 32;
  Result := Result + v;

  qw := UInt64(a.c0) * UInt64(b.c3);
  v.c0 := 0;
  v.c1 := 0;
  v.c2 := 0;
  v.c3 := qw and High(v.c3);
  if qw shr 32 <> 0 then
      over := True;
  Result := Result + v;

  qw := UInt64(a.c1) * UInt64(b.c2);
  v.c0 := 0;
  v.c1 := 0;
  v.c2 := 0;
  v.c3 := qw and High(v.c3);
  if qw shr 32 <> 0 then
      over := True;
  Result := Result + v;

  qw := UInt64(a.c2) * UInt64(b.c1);
  v.c0 := 0;
  v.c1 := 0;
  v.c2 := 0;
  v.c3 := qw and High(v.c3);
  if qw shr 32 <> 0 then
      over := True;
  Result := Result + v;

  qw := UInt64(a.c3) * UInt64(b.c0);
  v.c0 := 0;
  v.c1 := 0;
  v.c2 := 0;
  v.c3 := qw and High(v.c3);
  if qw shr 32 <> 0 then
      over := True;
  Result := Result + v;

  if (Result < a) and (Result < b) then
      RaiseInfo('Integer overflow');
  if (Result = 0) and (a <> 0) and (b <> 0) then
      RaiseInfo('Integer overflow');
  if over then
      RaiseInfo('Integer overflow');
  if neg then
      Result := -Result;
end;

class operator Int128.NotEqual(a, b: Int128): Boolean;
begin
  Result := not(a = b);
end;

class operator Int128.RightShift(a: Int128; Shift: Int64): Int128;
begin
  if Shift >= 128 then
      Result := a shr (Shift mod 128)
  else if Shift >= 64 then
    begin
      Result.dc0 := a.dc1;
      Result.dc1 := 0;
      Result := Result shr (Shift - 64);
    end
  else if Shift > 0 then
    begin
      Result.dc0 := (a.dc0 shr Shift) or (a.dc1 shl (64 - Shift));
      Result.dc1 := a.dc1 shr Shift;
    end
  else if Shift = 0 then
      Result := a
  else if Shift < 0 then
      Result := a shr (128 - (abs(Shift) mod 128))
end;

class operator Int128.RightShift(a, Shift: Int128): Int128;
begin
  if Shift < 0 then
      Result := a shr Int32(128 - ((-Shift) mod 128))
  else
      Result := a shr Int32(Shift mod 128);
end;

class operator Int128.Subtract(a, b: Int128): Int128;
var
  c: Int128;
begin
  c := not b;
  Inc128(c);
  Result := a + c;
end;

class operator Int128.IntDivide(a, b: Int128): Int128;
var
  temp: Int128;
begin
  DivMod128(a, b, Result, temp);
end;

class operator Int128.Modulus(a: Int128; b: Int128): Int128;
var
  temp: Int128;
begin
  DivMod128(a, b, temp, Result);
  if a < 0 then
      Result := -Result;
end;

class operator Int128.BitWiseOr(a, b: Int128): Int128;
begin
  Result.dc0 := a.dc0 or b.dc0;
  Result.dc1 := a.dc1 or b.dc1;
end;

class operator Int128.BitWiseXor(a, b: Int128): Int128;
begin
  Result.dc0 := a.dc0 xor b.dc0;
  Result.dc1 := a.dc1 xor b.dc1;
end;

class operator Int128.BitWiseAnd(a, b: Int128): Int128;
begin
  Result.dc0 := a.dc0 and b.dc0;
  Result.dc1 := a.dc1 and b.dc1;
end;

class operator Int128.Negative(a: Int128): Int128;
begin
  Result := not a + 1;
end;

class operator Int128.Inc(a: Int128): Int128;
begin
  Result := a + Int128(1);
end;

class operator Int128.Dec(a: Int128): Int128;
begin
  Result := a - Int128(1);
end;

function CompareCardinal(const c1, c2: Cardinal): integer;
begin
  if c1 < c2 then
      Result := -1
  else
    if c1 > c2 then
      Result := 1
  else
      Result := 0;
end;

function CompareInteger(const Int1, Int2: integer): integer;
begin
  if Int1 < Int2 then
      Result := -1
  else
    if Int1 > Int2 then
      Result := 1
  else
      Result := 0;
end;

function CompareInt64(const Int1, Int2: Int64): integer;
begin
  if Int1 < Int2 then
      Result := -1
  else
    if Int1 > Int2 then
      Result := 1
  else
      Result := 0;
end;

function CompareUInt64(const Int1, Int2: UInt64): integer;
begin
  if Int1 < Int2 then
      Result := -1
  else
    if Int1 > Int2 then
      Result := 1
  else
      Result := 0;
end;

function ComparePointer(const Item1, Item2: pointer): integer;
begin
  if NativeUInt(Item1) < NativeUInt(Item2) then
      Result := -1
  else
    if NativeUInt(Item1) > NativeUInt(Item2) then
      Result := 1
  else
      Result := 0;
end;

function CompareBool(const Bool1, Bool2: Boolean): integer;
begin
  if Bool1 < Bool2 then
      Result := -1
  else
    if Bool1 > Bool2 then
      Result := 1
  else
      Result := 0;
end;

function CompareDouble(const Double1, Double2: Double): integer;
begin
  if Double1 < Double2 then
      Result := -1
  else
    if Double1 > Double2 then
      Result := 1
  else
      Result := 0;
end;

function CompareInt128(const Int1, Int2: Int128): integer;
begin
  if Int1 < Int2 then
      Result := -1
  else
    if Int1 > Int2 then
      Result := 1
  else
      Result := 0;
end;

function CompareUInt128(const Int1, Int2: UInt128): integer;
begin
  if Int1 < Int2 then
      Result := -1
  else
    if Int1 > Int2 then
      Result := 1
  else
      Result := 0;
end;

function Max(const v1, v2: UInt64): UInt64;
begin
  if v1 > v2 then
      Result := v1
  else
      Result := v2;
end;

function Max(const v1, v2: Cardinal): Cardinal;
begin
  if v1 > v2 then
      Result := v1
  else
      Result := v2;
end;

function Max(const v1, v2: Word): Word;
begin
  if v1 > v2 then
      Result := v1
  else
      Result := v2;
end;

function Max(const v1, v2: Byte): Byte;
begin
  if v1 > v2 then
      Result := v1
  else
      Result := v2;
end;

function Max(const v1, v2: Int64): Int64;
begin
  if v1 > v2 then
      Result := v1
  else
      Result := v2;
end;

function Max(const v1, v2: integer): integer;
begin
  if v1 > v2 then
      Result := v1
  else
      Result := v2;
end;

function Max(const v1, v2: SmallInt): SmallInt;
begin
  if v1 > v2 then
      Result := v1
  else
      Result := v2;
end;

function Max(const v1, v2: ShortInt): ShortInt;
begin
  if v1 > v2 then
      Result := v1
  else
      Result := v2;
end;

function Max(const v1, v2: Double): Double;
begin
  if v1 > v2 then
      Result := v1
  else
      Result := v2;
end;

function Max(const v1, v2: Single): Single;
begin
  if v1 > v2 then
      Result := v1
  else
      Result := v2;
end;

function Max(const v1, v2: UInt128): UInt128;
begin
  if v1 > v2 then
      Result := v1
  else
      Result := v2;
end;

function Max(const v1, v2: Int128): Int128;
begin
  if v1 > v2 then
      Result := v1
  else
      Result := v2;
end;

function Min(const v1, v2: UInt64): UInt64;
begin
  if v1 < v2 then
      Result := v1
  else
      Result := v2;
end;

function Min(const v1, v2: Cardinal): Cardinal;
begin
  if v1 < v2 then
      Result := v1
  else
      Result := v2;
end;

function Min(const v1, v2: Word): Word;
begin
  if v1 < v2 then
      Result := v1
  else
      Result := v2;
end;

function Min(const v1, v2: Byte): Byte;
begin
  if v1 < v2 then
      Result := v1
  else
      Result := v2;
end;

function Min(const v1, v2: Int64): Int64;
begin
  if v1 < v2 then
      Result := v1
  else
      Result := v2;
end;

function Min(const v1, v2: integer): integer;
begin
  if v1 < v2 then
      Result := v1
  else
      Result := v2;
end;

function Min(const v1, v2: SmallInt): SmallInt;
begin
  if v1 < v2 then
      Result := v1
  else
      Result := v2;
end;

function Min(const v1, v2: ShortInt): ShortInt;
begin
  if v1 < v2 then
      Result := v1
  else
      Result := v2;
end;

function Min(const v1, v2: Double): Double;
begin
  if v1 < v2 then
      Result := v1
  else
      Result := v2;
end;

function Min(const v1, v2: Single): Single;
begin
  if v1 < v2 then
      Result := v1
  else
      Result := v2;
end;

function Min(const v1, v2: UInt128): UInt128;
begin
  if v1 < v2 then
      Result := v1
  else
      Result := v2;
end;

function Min(const v1, v2: Int128): Int128;
begin
  if v1 < v2 then
      Result := v1
  else
      Result := v2;
end;

function Clamp(const v, min_, max_: integer): integer;
begin
  if min_ > max_ then
      Result := Clamp(v, max_, min_)
  else if v > max_ then
      Result := max_
  else if v < min_ then
      Result := min_
  else
      Result := v;
end;

function Clamp(const v, min_, max_: UInt64): UInt64;
begin
  if min_ > max_ then
      Result := Clamp(v, max_, min_)
  else if v > max_ then
      Result := max_
  else if v < min_ then
      Result := min_
  else
      Result := v;
end;

function Clamp(const v, min_, max_: Cardinal): Cardinal;
begin
  if min_ > max_ then
      Result := Clamp(v, max_, min_)
  else if v > max_ then
      Result := max_
  else if v < min_ then
      Result := min_
  else
      Result := v;
end;

function Clamp(const v, min_, max_: Word): Word;
begin
  if min_ > max_ then
      Result := Clamp(v, max_, min_)
  else if v > max_ then
      Result := max_
  else if v < min_ then
      Result := min_
  else
      Result := v;
end;

function Clamp(const v, min_, max_: Byte): Byte;
begin
  if min_ > max_ then
      Result := Clamp(v, max_, min_)
  else if v > max_ then
      Result := max_
  else if v < min_ then
      Result := min_
  else
      Result := v;
end;

function Clamp(const v, min_, max_: Int64): Int64;
begin
  if min_ > max_ then
      Result := Clamp(v, max_, min_)
  else if v > max_ then
      Result := max_
  else if v < min_ then
      Result := min_
  else
      Result := v;
end;

function Clamp(const v, min_, max_: SmallInt): SmallInt;
begin
  if min_ > max_ then
      Result := Clamp(v, max_, min_)
  else if v > max_ then
      Result := max_
  else if v < min_ then
      Result := min_
  else
      Result := v;
end;

function Clamp(const v, min_, max_: ShortInt): ShortInt;
begin
  if min_ > max_ then
      Result := Clamp(v, max_, min_)
  else if v > max_ then
      Result := max_
  else if v < min_ then
      Result := min_
  else
      Result := v;
end;

function Clamp(const v, min_, max_: Double): Double;
begin
  if min_ > max_ then
      Result := Clamp(v, max_, min_)
  else if v > max_ then
      Result := max_
  else if v < min_ then
      Result := min_
  else
      Result := v;
end;

function Clamp(const v, min_, max_: Single): Single;
begin
  if min_ > max_ then
      Result := Clamp(v, max_, min_)
  else if v > max_ then
      Result := max_
  else if v < min_ then
      Result := min_
  else
      Result := v;
end;

function Clamp(const v, min_, max_: UInt128): UInt128;
begin
  if min_ > max_ then
      Result := Clamp(v, max_, min_)
  else if v > max_ then
      Result := max_
  else if v < min_ then
      Result := min_
  else
      Result := v;
end;

function Clamp(const v, min_, max_: Int128): Int128;
begin
  if min_ > max_ then
      Result := Clamp(v, max_, min_)
  else if v > max_ then
      Result := max_
  else if v < min_ then
      Result := min_
  else
      Result := v;
end;

function InRange(const v, min_, max_: integer): Boolean;
begin
  Result := (v >= Min(min_, max_)) and (v <= Max(min_, max_));
end;

function InRange(const v, min_, max_: UInt64): Boolean;
begin
  Result := (v >= Min(min_, max_)) and (v <= Max(min_, max_));
end;

function InRange(const v, min_, max_: Cardinal): Boolean;
begin
  Result := (v >= Min(min_, max_)) and (v <= Max(min_, max_));
end;

function InRange(const v, min_, max_: Word): Boolean;
begin
  Result := (v >= Min(min_, max_)) and (v <= Max(min_, max_));
end;

function InRange(const v, min_, max_: Byte): Boolean;
begin
  Result := (v >= Min(min_, max_)) and (v <= Max(min_, max_));
end;

function InRange(const v, min_, max_: Int64): Boolean;
begin
  Result := (v >= Min(min_, max_)) and (v <= Max(min_, max_));
end;

function InRange(const v, min_, max_: SmallInt): Boolean;
begin
  Result := (v >= Min(min_, max_)) and (v <= Max(min_, max_));
end;

function InRange(const v, min_, max_: ShortInt): Boolean;
begin
  Result := (v >= Min(min_, max_)) and (v <= Max(min_, max_));
end;

function InRange(const v, min_, max_: Double): Boolean;
begin
  Result := (v >= Min(min_, max_)) and (v <= Max(min_, max_));
end;

function InRange(const v, min_, max_: Single): Boolean;
begin
  Result := (v >= Min(min_, max_)) and (v <= Max(min_, max_));
end;

function InRange(const v, min_, max_: UInt128): Boolean;
begin
  Result := (v >= Min(min_, max_)) and (v <= Max(min_, max_));
end;

function InRange(const v, min_, max_: Int128): Boolean;
begin
  Result := (v >= Min(min_, max_)) and (v <= Max(min_, max_));
end;

end.
 

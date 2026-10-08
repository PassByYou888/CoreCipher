{ ******************************************************************************
  * Z.UPascalStrings – Unicode String Type with Extended Utilities
  *
  * This unit defines TUPascalString, a custom Unicode string record that
  * provides a high‑performance alternative to native string types while
  * remaining fully compatible with Delphi and Free Pascal. It stores data
  * as a dynamic array of USystemChar (UTF‑16 code units) and offers a rich
  * set of operations including concatenation, slicing, searching, case
  * conversion, encoding conversion (UTF‑8, ANSI, platform default), character
  * classification, Smith‑Waterman sequence alignment, random generation, and
  * C‑style pointer handling.
  *
  * ===========================================================================*
  * Key design principles
  * ===========================================================================*
  *   – Value type (record) – no reference counting overhead, stack‑allocated.
  *   – Direct memory access – internal buffer is a dynamic array, enabling
  *     fast block operations.
  *   – Operator overloading – behaves like a native string (+, =, <, >, etc.)*
  *     but with extra features.
  *   – Cross‑compiler – abstracts Delphi and FPC Unicode types.
  *   – Unicode‑aware – fully supports UTF‑16, including surrogate pairs.
  *
  * ===========================================================================*
  * Typical usage
  * ===========================================================================*
  *   var
  *     s, t: TUPascalString;
  *     i: Integer;
  *   begin
  *     s := 'Hello, 世界';                   // Implicit conversion from native
  *     t := s.Copy(1, 5);                    // 'Hello'
  *     if s.Same('HELLO') then ...           // Case‑insensitive compare
  *     i := s.GetPos('世');                  // Find character position
  *     s.Append('!');                        // In‑place append
  *     s.Bytes := UTF8Bytes;                 // Decode from UTF‑8
  *   end;
  *
  * ===========================================================================*
  * Smith‑Waterman alignment example
  * ===========================================================================*
  *   var
  *     a, b, diff1, diff2: TUPascalString;
  *     score: Double;
  *   begin
  *     a := 'kitten'; b := 'sitting';
  *     score := USmithWatermanCompare(a, b, diff1, diff2, False, '-');
  *     // diff1 and diff2 show the alignment with '-' for gaps.
  *   end;
  ****************************************************************************** }
unit Z.UPascalStrings;

{$UNDEF FPC_DELPHI_MODE}
{$I Z.Define.inc}

interface

uses Z.Core, Z.PascalStrings;

type
{$IFDEF FPC}
  { Under Free Pascal we use explicit Unicode types (2‑byte chars, UTF‑16 strings). }
  USystemChar = UnicodeChar;
  USystemString = UnicodeString;
  TUArrayChar = array of USystemChar;
  PUSystemString = ^USystemString;
  PUPascalString = ^TUPascalString;
{$ELSE FPC}
  { Under Delphi the native char/string types are already Unicode (WideChar/UnicodeString). }
  USystemChar = Z.PascalStrings.SystemChar;
  USystemString = Z.PascalStrings.SystemString;
  TUArrayChar = Z.PascalStrings.TArrayChar;
  PUSystemString = Z.PascalStrings.PSystemString;
  PUPascalString = Z.PascalStrings.PPascalString;
{$ENDIF FPC}
  PUSystemChar = ^USystemChar;

  { ----------------------------------------------------------------------------
    TUOrdChar – Character category enumeration for fast classification.
    Used with UCharIn() and TextIs() to test character properties.
  }
  TUOrdChar = (
    uc0to9, // '0'..'9'
    uc1to9, // '1'..'9'
    uc0to32, // ASCII 0..31 plus space (32)
    uc0to32no10, // Same as uc0to32 but excluding line feed (#10)
    ucLoAtoF, // 'a'..'f'
    ucHiAtoF, // 'A'..'F'
    ucLoAtoZ, // 'a'..'z'
    ucHiAtoZ, // 'A'..'Z'
    ucHex, // 0..9, a..f, A..F
    ucAtoF, // a..f, A..F
    ucAtoZ, // a..z, A..Z
    ucVisibled, // Printable ASCII (0x20‑0x7E) or any Unicode above 255
    ucDoubleChar // Ordinal > 255 (surrogate pairs / supplementary)
    );
  TUOrdChars = set of TUOrdChar; // Set of categories.

  { ----------------------------------------------------------------------------
    TUPascalString – Core Unicode string record.
    It stores characters in a dynamic array (buff) and provides a full set of
    string manipulation methods. All operations are efficient and Unicode‑safe.
  }
  TUPascalString = record
  private
    // ----- Property getters and setters --------------------------------------
    function GetText: USystemString;
    procedure SetText(const Value: USystemString);
    function GetLen: Integer;
    procedure SetLen(const Value: Integer);
    function GetChars(index: Integer): USystemChar;
    procedure SetChars(index: Integer; const Value: USystemChar);
    function GetUTF8: TBytes;
    procedure SetUTF8(const Value: TBytes);
    function GetPlatformBytes: TBytes;
    procedure SetPlatformBytes(const Value: TBytes);
    function GetANSI: TBytes;
    procedure SetANSI(const Value: TBytes);
    function GetLast: USystemChar;
    procedure SetLast(const Value: USystemChar);
    function GetFirst: USystemChar;
    procedure SetFirst(const Value: USystemChar);
    function GetUpperChar(index: Integer): USystemChar;
    procedure SetUpperChar(index: Integer; const Value: USystemChar);
    function GetLowerChar(index: Integer): USystemChar;
    procedure SetLowerChar(index: Integer; const Value: USystemChar);

  public
    buff: TUArrayChar; // Internal storage (0‑based dynamic array).

{$IFDEF DELPHI}
    // ----- Comparison operators (Delphi) ------------------------------------
    class operator Equal(const Lhs, Rhs: TUPascalString): Boolean;
    class operator NotEqual(const Lhs, Rhs: TUPascalString): Boolean;
    class operator GreaterThan(const Lhs, Rhs: TUPascalString): Boolean;
    class operator GreaterThanOrEqual(const Lhs, Rhs: TUPascalString): Boolean;
    class operator LessThan(const Lhs, Rhs: TUPascalString): Boolean;
    class operator LessThanOrEqual(const Lhs, Rhs: TUPascalString): Boolean;

    // ----- Concatenation operators (Delphi) ---------------------------------
    class operator Add(const Lhs, Rhs: TUPascalString): TUPascalString;
    class operator Add(const Lhs: USystemString; const Rhs: TUPascalString): TUPascalString;
    class operator Add(const Lhs: TUPascalString; const Rhs: USystemString): TUPascalString;
    class operator Add(const Lhs: USystemChar; const Rhs: TUPascalString): TUPascalString;
    class operator Add(const Lhs: TUPascalString; const Rhs: USystemChar): TUPascalString;

    // ----- Implicit conversions (Delphi) ------------------------------------
    class operator Implicit(Value: RawByteString): TUPascalString;
    class operator Implicit(Value: TPascalString): TUPascalString;
    class operator Implicit(Value: USystemString): TUPascalString;
    class operator Implicit(Value: USystemChar): TUPascalString;
    class operator Implicit(Value: TUPascalString): USystemString;
    class operator Implicit(Value: TUPascalString): Variant;

    // ----- Explicit conversions (Delphi) ------------------------------------
    class operator Explicit(Value: TUPascalString): RawByteString;
    class operator Explicit(Value: TUPascalString): TPascalString;
    class operator Explicit(Value: TUPascalString): USystemString;
    class operator Explicit(Value: TUPascalString): Variant;
    class operator Explicit(Value: USystemString): TUPascalString;
    class operator Explicit(Value: USystemChar): TUPascalString;
{$ENDIF}
    { * Swaps the internal buffer with another TUPascalString instance.
      * Efficient O(1) exchange without copying memory.
      * @param source The other string to swap with.
      * @Example:
      *   var a, b: TUPascalString;
      *   begin a := 'one'; b := 'two'; a.SwapInstance(b); // a='two', b='one'
    }
    procedure SwapInstance(var source: TUPascalString);

    { * Returns a substring of the current string.
      * @param index 1‑based start position.
      * @param Count Number of characters to copy; automatically truncated if
      *              beyond the end.
      * @return New TUPascalString containing the extracted substring.
      * @Example:
      *   var s := 'abcdef'; t := s.Copy(2, 3); // t = 'bcd'
    }
    function Copy(index, Count: NativeInt): TUPascalString;

    // ----- Case‑insensitive equality tests (ASCII only) --------------------

    { * Checks if this string equals another, ignoring ASCII case.
      * Multiple overloads allow comparing against one or more strings.
      * @param p / t The other string(s) to compare.
      * @return True if any of the provided strings matches ignoring case.
      * @Example:
      *   var s := 'Hello';
      *   if s.Same('HELLO', 'world') then ... // true because 'Hello' = 'HELLO'
    }
    function Same(const p: PUPascalString): Boolean; overload;
    function Same(const t: TUPascalString): Boolean; overload;
    function Same(const t1, t2: TUPascalString): Boolean; overload;
    function Same(const t1, t2, t3: TUPascalString): Boolean; overload;
    function Same(const t1, t2, t3, t4: TUPascalString): Boolean; overload;
    function Same(const t1, t2, t3, t4, t5: TUPascalString): Boolean; overload;
    function Same(const t1, t2, t3, t4, t5, t6: TUPascalString): Boolean; overload;
    function Same(const t1, t2, t3, t4, t5, t6, t7: TUPascalString): Boolean; overload;
    function Same(const t1, t2, t3, t4, t5, t6, t7, t8: TUPascalString): Boolean; overload;
    function Same(const t1, t2, t3, t4, t5, t6, t7, t8, t9: TUPascalString): Boolean; overload;
    { * Case‑sensitive or insensitive equality test.
      * @param IgnoreCase if True, ignore ASCII case differences.
      * @param t The string to compare against.
    }
    function Same(const IgnoreCase: Boolean; const t: TUPascalString): Boolean; overload;

    // ----- Position‑based comparison (for fast substring checks) ------------

    { * Checks whether a substring occurs at a specific offset.
      * @param Offset 1‑based starting position in this string.
      * @param p / t   Substring to look for.
      * @param IgnoreCase if True, ignore case.
      * @return True if the substring exactly matches at that offset.
      * @Example:
      *   var s := 'Hello World';
      *   if s.ComparePos(7, 'World') then ... // true
    }
    function ComparePos(const Offset: Integer; const p: PUPascalString): Boolean; overload;
    function ComparePos(const Offset: Integer; const t: TUPascalString): Boolean; overload;
    function ComparePos(const Offset: Integer; const p: PUPascalString; IgnoreCase: Boolean): Boolean; overload;
    function ComparePos(const Offset: Integer; const t: TUPascalString; IgnoreCase: Boolean): Boolean; overload;

    // ----- Substring search -------------------------------------------------

    { * Finds the first occurrence of a substring, starting from an offset.
      * @param s / p substring to locate.
      * @param Offset 1‑based position to start searching from (default 1).
      * @return 1‑based index of the first occurrence, or 0 if not found.
      * @Example:
      *   var s := 'abcabc';
      *   p := s.GetPos('bc', 2); // p = 4 (position of second 'bc')
    }
    function GetPos(const s: TUPascalString; const Offset: Integer = 1): Integer; overload;
    function GetPos(const s: PUPascalString; const Offset: Integer = 1): Integer; overload;

    // ----- Character existence tests ---------------------------------------

    { * Checks if a single character or any of a set appears in the string.
      * @param c character (or array) to test.
      * @return True if the character(s) are present.
    }
    function Exists(c: USystemChar): Boolean; overload;
    function Exists(c: array of USystemChar): Boolean; overload;

    { * Checks if a substring exists in the string.
      * @param s substring to search.
      * @return True if s appears.
    }
    function StrExists(const s: TUPascalString): Boolean;

    { * Counts how many times a specific character appears.
      * @param c character to count.
      * @return number of occurrences.
    }
    function GetCharCount(c: USystemChar): Integer;

    { * Checks if all characters are printable ASCII or >255.
      * @return True if every character is visible (non‑control).
    }
    function IsVisibledASCII: Boolean;

    // ----- Hashing ---------------------------------------------------------

    { * Computes a 32‑bit hash (case‑insensitive, ASCII only).
      * @return THash (32‑bit) value.
    }
    function hash: THash;

    { * Computes a 64‑bit hash (case‑insensitive, ASCII only).
      * @return THash64 (64‑bit) value.
    }
    function Hash64: THash64;

    // ----- Properties for first/last character (read/write) ----------------

    property Last: USystemChar read GetLast write SetLast; // The last character.
    property First: USystemChar read GetFirst write SetFirst; // The first character.

    // ----- Deletion operations ---------------------------------------------

    procedure DeleteLast; // Remove the last character.
    procedure DeleteFirst; // Remove the first character.

    { * Removes a range of characters.
      * @param idx 1‑based start index.
      * @param cnt number of characters to delete.
    }
    procedure Delete(idx, cnt: Integer);

    // ----- Clear / reset ---------------------------------------------------

    procedure Clear; // Set length to zero.
    procedure Reset; // Same as Clear.

    // ----- Append operations ----------------------------------------------

    { * Appends content to the end of the string.
      * Overloaded for TUPascalString, USystemChar, and formatted text.
      * @Example:
      *   var s: TUPascalString; s := 'Hello';
      *   s.Append(' World');      // 'Hello World'
      *   s.Append(' number %d', [42]); // 'Hello World number 42'
    }
    procedure Append(t: TUPascalString); overload;
    procedure Append(c: USystemChar); overload;
    procedure Append(const Fmt: USystemString; const Args: array of const); overload;

    // ----- Substring extraction -------------------------------------------

    { * Returns a substring from bPos to ePos‑1 (half‑open interval).
      * @param bPos 1‑based start position.
      * @param ePos 1‑based end position (exclusive).
      * @return substring from bPos to ePos‑1.
    }
    function GetString(bPos, ePos: NativeInt): TUPascalString;

    // ----- Insertion ------------------------------------------------------

    { * Inserts a USystemString at the given 1‑based index.
      * @param Text_ text to insert.
      * @param idx insertion position; if idx > length, appended.
    }
    procedure Insert(Text_: USystemString; idx: Integer);

    // ----- Fast conversions (avoid temporary allocations) -----------------

    { * Fills the output with the string data (pre‑allocated output).
      * @param output variable to receive the data.
    }
    procedure FastAsText(var output: USystemString);

    { * Fills the output with UTF‑8 bytes (pre‑allocated output).
      * @param output TBytes variable to receive the UTF‑8 data.
    }
    procedure FastGetBytes(var output: TBytes);

    // ----- Case conversion -------------------------------------------------

    property Text: USystemString read GetText write SetText; // Native string representation.

    { * Returns a lower‑case copy (using SysUtils).
      * @return lower‑case USystemString.
    }
    function LowerText: USystemString;

    { * Returns an upper‑case copy (using SysUtils).
      * @return upper‑case USystemString.
    }
    function UpperText: USystemString;

    { * ShortText
      * Returns a shortened representation of the string.
      *
      * When the string length L exceeds MaxL and MaxL is greater than
      * LL_ + RL_, the result is formed by taking the first LL_ characters,
      * adding ' ... ', and then appending the last RL_ characters.
      * Otherwise, the original string is returned unchanged.
      *
      * @param MaxL  Maximum length threshold for truncation.
      * @param LL_   Number of characters to keep from the left side.
      * @param RL_   Number of characters to keep from the right side.
      * @return      The shortened string, or the original string.
    }
    function ShortText(MaxL, LL_, RL_: Integer): TUPascalString;

    // ----- Inversion (reverse) --------------------------------------------

    { * Returns a reversed copy of the string.
      * @return new TUPascalString with characters in reverse order.
    }
    function Invert: TUPascalString;

    // ----- Trimming and filtering -----------------------------------------

    { * Removes all leading/trailing characters that belong to the given set.
      * @param Chars set of characters to trim.
      * @return new string with trimmed ends.
    }
    function TrimChar(const Chars: TUPascalString): TUPascalString;
    { * Removes all leading characters that belong to the given set.
      * @param Chars set of characters to trim from the beginning.
      * @return new string with leading characters removed.
    }
    function TrimLeftChar(const Chars: TUPascalString): TUPascalString;

    { * Removes all trailing characters that belong to the given set.
      * @param Chars set of characters to trim from the end.
      * @return new string with trailing characters removed.
    }
    function TrimRightChar(const Chars: TUPascalString): TUPascalString;

    { * Removes all characters that belong to a set (explicit or category).
      * @param Chars set of characters to delete (as TUPascalString or TUOrdChars).
      * @return new string with those characters removed.
    }
    function DeleteChar(const Chars: TUPascalString): TUPascalString; overload;
    function DeleteChar(const Chars: TUOrdChars): TUPascalString; overload;

    { * Replaces all characters matching a set with a new character.
      * @param Chars characters to replace (string, single char, or category set).
      * @param newChar replacement character.
      * @return new string with replacements.
    }
    function ReplaceChar(const Chars: TUPascalString; const newChar: USystemChar): TUPascalString; overload;
    function ReplaceChar(const Chars, newChar: USystemChar): TUPascalString; overload;
    function ReplaceChar(const Chars: TUOrdChars; const newChar: USystemChar): TUPascalString; overload;

    // ----- C‑string pointer handling (ANSI) --------------------------------

    { * Allocates a null‑terminated ANSI (Windows codepage) buffer.
      * The caller must free it with FreeAnsiChar.
      * @return pointer to the allocated buffer.
    }
    function BuildAnsiChar(var siz: Integer): Pointer; overload;
    function BuildAnsiChar: Pointer; overload;

    { * Fills the string from a null‑terminated ANSI buffer.
      * @param p pointer to the buffer.
    }
    procedure ReadAnsiChar(p: Pointer; MaxSiz: NativeInt); overload;
    procedure ReadAnsiChar(p: Pointer); overload;

    { * Class method that creates a TUPascalString from an ANSI buffer.
      * @param p pointer to the buffer.
      * @return TUPascalString instance.
    }
    class function ReadAnsiCharTo(p: Pointer; MaxSiz: NativeInt): TUPascalString; overload; static;
    class function ReadAnsiCharTo(p: Pointer): TUPascalString; overload; static;

    { * Allocates a zero‑filled ANSI buffer of given size.
      * @param size_ number of bytes.
      * @return pointer to allocated memory.
    }
    class function AllocAnsiChar(size_: NativeInt): Pointer; static;

    class procedure FreeAnsiChar(p: Pointer); static; // Frees memory allocated by AllocAnsiChar.

    // ----- C‑string pointer handling (WideChar / UTF‑16) ------------------

    { * Allocates a null‑terminated WideChar (UTF‑16) buffer.
      * The caller must free it with FreeWideChar.
      * @return pointer to the allocated buffer.
    }
    function BuildWideChar(var siz: Integer): Pointer; overload;
    function BuildWideChar: Pointer; overload;

    { * Fills the string from a null‑terminated WideChar buffer.
      * @param p pointer to the buffer.
    }
    procedure ReadWideChar(p: Pointer; MaxSiz: NativeInt); overload;
    procedure ReadWideChar(p: Pointer); overload;

    { * Class method that creates a TUPascalString from a WideChar buffer.
      * @param p pointer to the buffer.
      * @return TUPascalString instance.
    }
    class function ReadWideCharTo(p: Pointer; MaxSiz: NativeInt): TUPascalString; overload; static;
    class function ReadWideCharTo(p: Pointer): TUPascalString; overload; static;

    { * Allocates a zero‑filled WideChar buffer of given size (in characters).
      * @param size_ number of characters.
      * @return pointer to allocated memory.
    }
    class function AllocWideChar(size_: NativeInt): Pointer; static;
    class procedure FreeWideChar(p: Pointer); static; // Frees memory allocated by AllocWideChar.

    function BuildUTF8AnsiChar(var siz: Integer): Pointer; overload; // Allocates a null-terminated UTF‑8 buffer; returns pointer and sets siz to allocated size (caller must free unless autofree used).
    function BuildUTF8AnsiChar: Pointer; overload; // Allocates a null-terminated UTF‑8 buffer; returns pointer (caller must free unless autofree used).
    procedure ReadUTF8AnsiChar(p: Pointer; MaxSiz: NativeInt); overload; // Reads a null-terminated UTF‑8 buffer up to MaxSiz bytes into the string; stops at null terminator or MaxSiz.
    procedure ReadUTF8AnsiChar(p: Pointer); overload; // Reads a null-terminated UTF‑8 buffer into the string; stops at null terminator.
    class function ReadUTF8AnsiCharTo(p: Pointer; MaxSiz: NativeInt): TUPascalString; overload; static; // Creates a TUPascalString from a null-terminated UTF‑8 buffer up to MaxSiz bytes.
    class function ReadUTF8AnsiCharTo(p: Pointer): TUPascalString; overload; static; // Creates a TUPascalString from a null-terminated UTF‑8 buffer.
    class function AllocUTF8AnsiChar(size_: NativeInt): Pointer; static; // Allocates a zero-filled memory block of size_ bytes for a UTF‑8 buffer.
    class procedure FreeUTF8AnsiChar(p: Pointer); static; // Frees memory allocated by AllocUTF8AnsiChar or BuildUTF8AnsiChar (when manually managed).

    // ----- Random string generation ---------------------------------------

    { * Generates a random string of given length using a custom random generator.
      * @param rnd a TRandom instance (e.g., TMT19937Random).
      * @param L_ desired length.
      * @param Chars_ optional set of allowed character categories; if omitted,
      *               uses printable ASCII (0x20‑0x7E).
      * @return new TUPascalString filled with random characters.
      * @Example:
      *   var rnd := TMT19937Random.Create;
      *   s := TUPascalString.RandomString(rnd, 10, [ucAtoZ, uc0to9]); // alphanumeric
    }
    class function RandomString(rnd: TRandom; L_: Integer): TUPascalString; overload; static;
    class function RandomString(L_: Integer): TUPascalString; overload; static;
    class function RandomString(rnd: TRandom; L_: Integer; Chars_: TUOrdChars): TUPascalString; overload; static;
    class function RandomString(L_: Integer; Chars_: TUOrdChars): TUPascalString; overload; static;

    // ----- Smith‑Waterman similarity --------------------------------------

    { * Computes the similarity score (0..1) between this string and another.
      * Uses the Smith‑Waterman algorithm with match=1, mismatch=-1, gap=-1.
      * @param p / s the other string to compare.
      * @return similarity ratio (matches / alignment length), or -1 if error
      *         (e.g., matrix too large).
      * @Example:
      *   var a := 'kitten'; b := 'sitting';
      *   score := a.SmithWaterman(b); // returns approx 0.33 (3 matches / 9)
    }
    function SmithWaterman(const p: PUPascalString): Double; overload;
    function SmithWaterman(const s: TUPascalString): Double; overload;

    // ----- Length and character access ------------------------------------

    property Len: Integer read GetLen write SetLen; // Character count.
    property L: Integer read GetLen write SetLen; // Alias for Len.
    property Chars[index: Integer]: USystemChar read GetChars write SetChars; default; // 1‑based access.
    property UpperChar[index: Integer]: USystemChar read GetUpperChar write SetUpperChar; // 1‑based, uppercase.
    property LowerChar[index: Integer]: USystemChar read GetLowerChar write SetLowerChar; // 1‑based, lowercase.

    // ----- Encoding properties --------------------------------------------

    property Bytes: TBytes read GetUTF8 write SetUTF8; // UTF‑8 encoded bytes.
    property UTF8: TBytes read GetUTF8 write SetUTF8; // Alias for Bytes.
    property PlatformBytes: TBytes read GetPlatformBytes write SetPlatformBytes; // System‑default encoding.
    property ANSI: TBytes read GetANSI write SetANSI; // Windows ANSI encoding.

    // ----- BOM‑prefixed UTF‑8 bytes --------------------------------------

    { * Returns UTF‑8 bytes with a BOM (on Delphi) or without (on FPC).
      * @return TBytes containing the UTF‑8 representation.
    }
    function BOMBytes: TBytes;
  end;

  { Type aliases for dynamic arrays of TUPascalString and pointers. }
  TUArrayPascalString = array of TUPascalString;
  PUArrayPascalString = ^TUArrayPascalString;
  TUArrayPascalStringPtr = array of PUPascalString;
  PUArrayPascalStringPtr = ^TUArrayPascalStringPtr;

  { Short aliases for convenience. }
  TUP_String = TUPascalString;
  PUP_String = PUPascalString;
  TUPS = TUPascalString;

  { Atomic variant types for multi‑threaded access. }
  TAtomUSystemString = {$IFDEF FPC}specialize {$ENDIF FPC}TAtomVar<USystemString>;
  TAtomUPascalString = {$IFDEF FPC}specialize {$ENDIF FPC}TAtomVar<TUPascalString>;

  // ----- Global helper functions for character testing ---------------------

  { * Overloaded UCharIn function – tests if a character belongs to a set.
    * Supports explicit array, single char, TUPascalString, pointer,
    * TUOrdChar category, or combination.
    * @Example:
    *   if UCharIn('x', ['a'..'z']) then ... // true
  }
function UCharIn(c: USystemChar; const SomeChars: array of USystemChar): Boolean; overload;
function UCharIn(c: USystemChar; const SomeChar: USystemChar): Boolean; overload;
function UCharIn(c: USystemChar; const s: TUPascalString): Boolean; overload;
function UCharIn(c: USystemChar; const p: PUPascalString): Boolean; overload;
function UCharIn(c: USystemChar; const SomeCharsets: TUOrdChars): Boolean; overload;
function UCharIn(c: USystemChar; const SomeCharset: TUOrdChar): Boolean; overload;
function UCharIn(c: USystemChar; const SomeCharsets: TUOrdChars; const SomeChars: TUPascalString): Boolean; overload;
function UCharIn(c: USystemChar; const SomeCharsets: TUOrdChars; const p: PUPascalString): Boolean; overload;

{ * Checks whether every character in the string belongs to a given set.
  * @param t the string to examine.
  * @param SomeCharsets set of character categories.
  * @param SomeChars additional characters (optional).
  * @return True if all characters satisfy the condition.
  * @Example:
  *   if TextIs(s, [uc0to9, ucAtoZ]) then ... // s is alphanumeric
}
function TextIs(t: TUPascalString; const SomeCharsets: TUOrdChars): Boolean; overload;
function TextIs(t: TUPascalString; const SomeCharsets: TUOrdChars; const SomeChars: TUPascalString): Boolean; overload;

// ----- Fast hash functions (case‑insensitive for ASCII letters) ------------

function UFastHashSystemString(const s: USystemString): THash;
function UFastHash64SystemString(const s: USystemString): THash64;
function UFastHashPPascalString(const s: PUPascalString): THash;
function UFastHash64PPascalString(const s: PUPascalString): THash64;

// ----- Safe formatting wrapper ---------------------------------------------

function UFormat(const Fmt: USystemString; const Args: array of const): USystemString;

{$IFDEF FPC}
// ----- FPC operator overloads (similar to Delphi) -------------------------
operator := (const s: Variant)r: TUPascalString;
operator := (const s: AnsiString)r: TUPascalString;
operator := (const s: RawByteString)r: TUPascalString;
operator := (const s: UnicodeString)r: TUPascalString;
operator := (const s: WideString)r: TUPascalString;
operator := (const s: ShortString)r: TUPascalString;
operator := (const c: USystemChar)r: TUPascalString;
operator := (const c: SystemChar)r: TUPascalString;
operator := (const c: TPascalString)r: TUPascalString;

operator := (const s: TUPascalString)r: AnsiString;
operator := (const s: TUPascalString)r: RawByteString;
operator := (const s: TUPascalString)r: UnicodeString;
operator := (const s: TUPascalString)r: WideString;
operator := (const s: TUPascalString)r: ShortString;
operator := (const s: TUPascalString)r: Variant;
operator := (const s: TUPascalString)r: TPascalString;

operator = (const a: TUPascalString; const b: TUPascalString): Boolean;
operator = (const a: TUPascalString; const b: USystemString): Boolean;
operator <> (const a: TUPascalString; const b: TUPascalString): Boolean;
operator > (const a: TUPascalString; const b: TUPascalString): Boolean;
operator >= (const a: TUPascalString; const b: TUPascalString): Boolean;
operator < (const a: TUPascalString; const b: TUPascalString): Boolean;
operator <= (const a: TUPascalString; const b: TUPascalString): Boolean;

operator + (const a: TUPascalString; const b: TUPascalString): TUPascalString;
operator + (const a: TUPascalString; const b: USystemString): TUPascalString;
operator + (const a: USystemString; const b: TUPascalString): TUPascalString;
operator + (const a: TUPascalString; const b: USystemChar): TUPascalString;
operator + (const a: USystemChar; const b: TUPascalString): TUPascalString;
{$ENDIF}

// ----- Smith‑Waterman alignment with diff output --------------------------

{ * Computes similarity and produces two strings showing the alignment differences.
  * The diff strings indicate inserted/deleted characters with a designated diffChar.
  * @param seq1, seq2 strings to compare (as PUPascalString or TUPascalString).
  * @param diff1, diff2 output alignment strings.
  * @param NoDiffChar if True, identical positions are replaced by diffChar;
  *                   otherwise original characters kept.
  * @param diffChar character used to indicate gaps/differences.
  * @return similarity ratio, or -1 if error.
  * @Example:
  *   var d1,d2: TUPascalString;
  *   score := USmithWatermanCompare('kitten','sitting', d1, d2, False, '-');
  *   // d1 and d2 will show alignment with '-' for gaps.
}
function USmithWatermanCompare(const seq1, seq2: PUPascalString; var diff1, diff2: TUPascalString;
  const NoDiffChar: Boolean; const diffChar: USystemChar): Double; overload;
function USmithWatermanCompare(const seq1, seq2: PUPascalString; var diff1, diff2: TUPascalString): Double; overload;
function USmithWatermanCompare(const seq1, seq2: TUPascalString; var diff1, diff2: TUPascalString;
  const NoDiffChar: Boolean; const diffChar: USystemChar): Double; overload;
function USmithWatermanCompare(const seq1, seq2: TUPascalString; var diff1, diff2: TUPascalString): Double; overload;

// ----- Smith‑Waterman similarity only (no diff output) -------------------

function USmithWatermanCompare(const seq1, seq2: PUPascalString; out Same, Diff: Integer): Double; overload;
function USmithWatermanCompare(const seq1, seq2: PUPascalString): Double; overload;
function USmithWatermanCompare(const seq1, seq2: TUPascalString): Double; overload;
function USmithWatermanCompare(const seq1: TUArrayPascalString; const seq2: TUPascalString): Double; overload;

// ----- Smith‑Waterman for raw memory buffers (byte‑wise) -----------------

{ * Compares two memory blocks as byte sequences.
  * @param seq1, seq2 pointers to the memory blocks.
  * @param siz1, siz2 sizes in bytes.
  * @param Same, Diff output counts of matches and mismatches.
  * @return similarity ratio (Same / (Same+Diff)).
}
function USmithWatermanCompare(const seq1: Pointer; siz1: Integer; const seq2: Pointer; siz2: Integer;
  out Same, Diff: Integer): Double; overload;
function USmithWatermanCompare(const seq1: Pointer; siz1: Integer; const seq2: Pointer; siz2: Integer): Double; overload;

// ----- Smith‑Waterman for long multi‑line texts (line‑wise) --------------

{ * Splits texts into lines, compares line‑wise, and uses a threshold to decide
  * if lines match. Useful for comparing structured documents.
  * @param t1, t2 full texts.
  * @param MinDiffCharWithPeerLine maximum allowed differences within a line
  *        to consider it a match.
  * @param Same, Diff total matches and differences.
  * @return overall similarity ratio.
}
function USmithWatermanCompareLongString(const t1, t2: TUPascalString; const MinDiffCharWithPeerLine: Integer; out Same, Diff: Integer): Double; overload;
function USmithWatermanCompareLongString(const t1, t2: TUPascalString): Double; overload;

const
  USystemCharSize = SizeOf(USystemChar);

var
{$IFDEF CPU64}
  UMaxSmithWatermanMatrix: NativeInt = 10000 * 10; // Maximum matrix dimension (64‑bit).
{$ELSE CPU64}
  UMaxSmithWatermanMatrix: NativeInt = 8192; // Maximum matrix dimension (32‑bit).
{$ENDIF CPU64}


const
{$IFDEF FirstCharInZero}
  UFirstCharPos = 0; // Native string index base (0 for FPC, 1 for Delphi).
{$ELSE FirstCharInZero}
  UFirstCharPos = 1;
{$ENDIF FirstCharInZero}

implementation

uses SysUtils, Variants;

{ *****************************************************************************
  * Internal helper routines for efficient concatenation of character arrays
  * and native strings. These functions are used by operator overloads and
  * Append methods. They minimize temporary allocations by directly copying
  * memory blocks.
  ***************************************************************************** }

{ * Concatenate two dynamic arrays of USystemChar into output. }
procedure CombineCharsPP(const c1, c2: TUArrayChar; var output: TUArrayChar);
var
  LL, rl: Integer;
begin
  LL := length(c1);
  rl := length(c2);
  SetLength(output, LL + rl);
  if LL > 0 then
      CopyPtr(@c1[0], @output[0], LL * USystemCharSize);
  if rl > 0 then
      CopyPtr(@c2[0], @output[LL], rl * USystemCharSize);
end;

{ * Concatenate a native USystemString (left) with an array (right). }
procedure CombineCharsSP(const c1: USystemString; const c2: TUArrayChar; var output: TUArrayChar);
var
  LL, rl: Integer;
begin
  LL := length(c1);
  rl := length(c2);
  SetLength(output, LL + rl);
  if LL > 0 then
      CopyPtr(@c1[UFirstCharPos], @output[0], LL * USystemCharSize);
  if rl > 0 then
      CopyPtr(@c2[0], @output[LL], rl * USystemCharSize);
end;

{ * Concatenate an array (left) with a native USystemString (right). }
procedure CombineCharsPS(const c1: TUArrayChar; const c2: USystemString; var output: TUArrayChar);
var
  LL, rl: Integer;
begin
  LL := length(c1);
  rl := length(c2);
  SetLength(output, LL + rl);
  if LL > 0 then
      CopyPtr(@c1[0], @output[0], LL * USystemCharSize);
  if rl > 0 then
      CopyPtr(@c2[UFirstCharPos], @output[LL], rl * USystemCharSize);
end;

{ * Concatenate a single character (left) with an array. }
procedure CombineCharsCP(const c1: USystemChar; const c2: TUArrayChar; var output: TUArrayChar);
var
  rl: Integer;
begin
  rl := length(c2);
  SetLength(output, rl + 1);
  output[0] := c1;
  if rl > 0 then
      CopyPtr(@c2[0], @output[1], rl * USystemCharSize);
end;

{ * Concatenate an array (left) with a single character. }
procedure CombineCharsPC(const c1: TUArrayChar; const c2: USystemChar; var output: TUArrayChar);
var
  LL: Integer;
begin
  LL := length(c1);
  SetLength(output, LL + 1);
  if LL > 0 then
      CopyPtr(@c1[0], @output[0], LL * USystemCharSize);
  output[LL] := c2;
end;

{ *************** Global UCharIn functions (overloaded) *********************** }

function UCharIn(c: USystemChar; const SomeChars: array of USystemChar): Boolean;
// Test if c is in the given array.
var
  AChar: USystemChar;
begin
  Result := True;
  for AChar in SomeChars do
    if AChar = c then
        Exit;
  Result := False;
end;

function UCharIn(c: USystemChar; const SomeChar: USystemChar): Boolean;
// Test if c equals a single character.
begin
  Result := c = SomeChar;
end;

function UCharIn(c: USystemChar; const s: TUPascalString): Boolean;
// Test if c is present in the TUPascalString.
begin
  Result := s.Exists(c);
end;

function UCharIn(c: USystemChar; const p: PUPascalString): Boolean;
// Test if c is present in the string pointed by p.
begin
  Result := p^.Exists(c);
end;

function UCharIn(c: USystemChar; const SomeCharset: TUOrdChar): Boolean;
// Test if c belongs to one character category (using ordinal ranges).
const
  ord0 = Ord('0');
  ord1 = Ord('1');
  ord9 = Ord('9');
  ordLA = Ord('a');
  ordHA = Ord('A');
  ordLF = Ord('f');
  ordHF = Ord('F');
  ordLZ = Ord('z');
  ordHZ = Ord('Z');
var
  v: Word;
begin
  v := Ord(c);
  case SomeCharset of
    uc0to9: Result := (v >= ord0) and (v <= ord9);
    uc1to9: Result := (v >= ord1) and (v <= ord9);
    uc0to32: Result := ((v >= 0) and (v <= 32));
    uc0to32no10: Result := ((v >= 0) and (v <= 32) and (v <> 10));
    ucLoAtoF: Result := (v >= ordLA) and (v <= ordLF);
    ucHiAtoF: Result := (v >= ordHA) and (v <= ordHF);
    ucLoAtoZ: Result := (v >= ordLA) and (v <= ordLZ);
    ucHiAtoZ: Result := (v >= ordHA) and (v <= ordHZ);
    ucHex: Result := ((v >= ordLA) and (v <= ordLF)) or ((v >= ordHA) and (v <= ordHF)) or ((v >= ord0) and (v <= ord9));
    ucAtoF: Result := ((v >= ordLA) and (v <= ordLF)) or ((v >= ordHA) and (v <= ordHF));
    ucAtoZ: Result := ((v >= ordLA) and (v <= ordLZ)) or ((v >= ordHA) and (v <= ordHZ));
    ucVisibled: Result := ((v >= $20) and (v <= $7E)) or (v > $FF);
    ucDoubleChar: Result := v > $FF;
    else Result := False;
  end;
end;

function UCharIn(c: USystemChar; const SomeCharsets: TUOrdChars): Boolean;
// Test if c belongs to any of the categories in the set.
var
  i: TUOrdChar;
begin
  Result := True;
  for i in SomeCharsets do
    if UCharIn(c, i) then
        Exit;
  Result := False;
end;

function UCharIn(c: USystemChar; const SomeCharsets: TUOrdChars; const SomeChars: TUPascalString): Boolean;
// Test if c belongs to a category or is in the explicit string.
begin
  if UCharIn(c, SomeCharsets) then
      Result := True
  else
      Result := UCharIn(c, SomeChars);
end;

function UCharIn(c: USystemChar; const SomeCharsets: TUOrdChars; const p: PUPascalString): Boolean;
// Same but with pointer.
begin
  if UCharIn(c, SomeCharsets) then
      Result := True
  else
      Result := UCharIn(c, p);
end;

function TextIs(t: TUPascalString; const SomeCharsets: TUOrdChars): Boolean;
// Verify every character of t belongs to some category.
var
  c: USystemChar;
begin
  Result := False;
  for c in t.buff do
    if not UCharIn(c, SomeCharsets) then
        Exit;
  Result := True;
end;

function TextIs(t: TUPascalString; const SomeCharsets: TUOrdChars; const SomeChars: TUPascalString): Boolean;
// Verify every character of t belongs to a category or is in SomeChars.
var
  c: USystemChar;
begin
  Result := False;
  for c in t.buff do
    if not UCharIn(c, SomeCharsets, SomeChars) then
        Exit;
  Result := True;
end;

{ *************** Fast hash functions (case‑insensitive) ********************* }

function UFastHashSystemString(const s: USystemString): THash;
// Compute 32‑bit hash of a USystemString (ASCII letters folded to lower case).
var
  i: Integer;
  c: USystemChar;
begin
  FillPtr(@Result, SizeOf(THash), length(s) mod 2);
{$IFDEF FirstCharInZero}
  for i := 0 to length(s) - 1 do
{$ELSE FirstCharInZero}
  for i := 1 to length(s) do
{$ENDIF FirstCharInZero}
    begin
      c := s[i];
      if UCharIn(c, ucHiAtoZ) then
          inc(c, 32);
      Result := ((Result shl 7) or (Result shr 25)) + THash(c);
    end;
end;

function UFastHash64SystemString(const s: USystemString): THash64;
// Compute 64‑bit hash of a USystemString (ASCII letters folded to lower case).
var
  i: Integer;
  c: USystemChar;
begin
  FillPtr(@Result, SizeOf(THash64), length(s) mod 2);
{$IFDEF FirstCharInZero}
  for i := 0 to length(s) - 1 do
{$ELSE FirstCharInZero}
  for i := 1 to length(s) do
{$ENDIF FirstCharInZero}
    begin
      c := s[i];
      if UCharIn(c, ucHiAtoZ) then
          inc(c, 32);
      Result := ((Result shl 7) or (Result shr 57)) + THash64(c);
    end;
end;

function UFastHashPPascalString(const s: PUPascalString): THash;
// 32‑bit hash of a TUPascalString pointed by s.
var
  i: Integer;
  c: USystemChar;
begin
  FillPtr(@Result, SizeOf(THash), s^.L mod 2);
  for i := 1 to s^.L do
    begin
      c := s^[i];
      if UCharIn(c, ucHiAtoZ) then
          inc(c, 32);
      Result := ((Result shl 7) or (Result shr 25)) + THash(c);
    end;
end;

function UFastHash64PPascalString(const s: PUPascalString): THash64;
// 64‑bit hash of a TUPascalString pointed by s.
var
  i: Integer;
  c: USystemChar;
begin
  FillPtr(@Result, SizeOf(THash64), s^.L mod 2);
  for i := 1 to s^.L do
    begin
      c := s^[i];
      if UCharIn(c, ucHiAtoZ) then
          inc(c, 32);
      Result := ((Result shl 7) or (Result shr 57)) + THash64(c);
    end;
end;

function UFormat(const Fmt: USystemString; const Args: array of const): USystemString;
// Safe wrapper for SysUtils.Format (or UnicodeFormat under FPC); returns Fmt on any exception.
begin
  try
{$IFDEF FPC}
    Result := UnicodeFormat(Fmt, Args);
{$ELSE FPC}
    Result := Format(Fmt, Args);
{$ENDIF FPC}
  except
      Result := Fmt;
  end;
end;

{ *************** Smith‑Waterman matrix helpers ****************************** }

function GetSWMVMemory(const xLen, yLen: NativeInt): Pointer;
// Allocate a matrix of (xLen+1)*(yLen+1) NativeInts.
begin
  Result := System.AllocMem((xLen + 1) * (yLen + 1) * SizeOf(NativeInt));
end;

function GetSWMV(const p: Pointer; const w, x, y: NativeInt): NativeInt;
// Read value at (x,y) in matrix p with row stride (w+1).
begin
  Result := PNativeInt(nativeUInt(p) + ((x + y * (w + 1)) * SizeOf(NativeInt)))^;
end;

procedure SetSWMV(const p: Pointer; const w, x, y: NativeInt; const v: NativeInt);
// Write value v at (x,y) in matrix p with row stride (w+1).
begin
  PNativeInt(nativeUInt(p) + ((x + y * (w + 1)) * SizeOf(NativeInt)))^ := v;
end;

function GetMax(const i1, i2: NativeInt): NativeInt;
// Return the maximum of two integers.
begin
  if i1 > i2 then
      Result := i1
  else
      Result := i2;
end;

const
  SmithWaterman_MatchOk = 1;
  mismatch_penalty = -1;
  gap_penalty = -1;

  { *************** Smith‑Waterman with diff output **************************** }

function USmithWatermanCompare(const seq1, seq2: PUPascalString; var diff1, diff2: TUPascalString;
  const NoDiffChar: Boolean; const diffChar: USystemChar): Double;
// Align seq1 and seq2, produce diff1 and diff2 strings, return similarity.

  function InlineMatch(alphaC, betaC: USystemChar; const diffC: USystemChar): Integer;
  // Score for matching two characters: match=1, mismatch=-1, gap=-1 if either is diffChar.
  begin
    if UCharIn(alphaC, ucLoAtoZ) then
        dec(alphaC, 32);
    if UCharIn(betaC, ucLoAtoZ) then
        dec(betaC, 32);
    if alphaC = betaC then
        Result := SmithWaterman_MatchOk
    else if (alphaC = diffC) or (betaC = diffC) then
        Result := gap_penalty
    else
        Result := mismatch_penalty;
  end;

var
  swMatrixPtr: Pointer;
  i, j, L1, l2: NativeInt;
  matched, deleted, inserted: NativeInt;
  score_current, score_diagonal, score_left, score_right: NativeInt;
  identity: NativeInt;
  align1, align2: TUPascalString;
begin
  L1 := seq1^.Len;
  l2 := seq2^.Len;
  // Check for zero length or exceeding maximum matrix size.
  if (L1 = 0) or (l2 = 0) or (L1 > UMaxSmithWatermanMatrix) or (l2 > UMaxSmithWatermanMatrix) then
    begin
      Result := -1;
      Exit;
    end;
  swMatrixPtr := GetSWMVMemory(L1, l2);
  if swMatrixPtr = nil then
    begin
      diff1 := ''; diff2 := '';
      Result := -1;
      Exit;
    end;
  // Initialize first row and column with gap penalties.
  i := 0;
  while i <= L1 do
    begin
      SetSWMV(swMatrixPtr, L1, i, 0, gap_penalty * i);
      inc(i);
    end;
  j := 0;
  while j <= l2 do
    begin
      SetSWMV(swMatrixPtr, L1, 0, j, gap_penalty * j);
      inc(j);
    end;
  // Fill matrix using dynamic programming.
  i := 1;
  while i <= L1 do
    begin
      j := 1;
      while j <= l2 do
        begin
          matched := GetSWMV(swMatrixPtr, L1, i - 1, j - 1) + InlineMatch(seq1^[i], seq2^[j], diffChar);
          deleted := GetSWMV(swMatrixPtr, L1, i - 1, j) + gap_penalty;
          inserted := GetSWMV(swMatrixPtr, L1, i, j - 1) + gap_penalty;
          SetSWMV(swMatrixPtr, L1, i, j, GetMax(matched, GetMax(deleted, inserted)));
          inc(j);
        end;
      inc(i);
    end;
  // Traceback to build alignment strings.
  i := L1; j := l2;
  align1 := ''; align2 := '';
  identity := 0;
  while (i > 0) and (j > 0) do
    begin
      score_current := GetSWMV(swMatrixPtr, L1, i, j);
      score_diagonal := GetSWMV(swMatrixPtr, L1, i - 1, j - 1);
      score_left := GetSWMV(swMatrixPtr, L1, i - 1, j);
      score_right := GetSWMV(swMatrixPtr, L1, i, j - 1);
      matched := InlineMatch(seq1^[i], seq2^[j], diffChar);
      if score_current = score_diagonal + matched then
        begin
          if matched = SmithWaterman_MatchOk then
            begin
              inc(identity);
              align1.Append(seq1^[i]);
              align2.Append(seq2^[j]);
            end
          else if NoDiffChar then
            begin
              align1.Append(diffChar);
              align2.Append(diffChar);
            end
          else
            begin
              align1.Append(seq1^[i]);
              align2.Append(seq2^[j]);
            end;
          dec(i); dec(j);
        end
      else if score_current = score_left + gap_penalty then
        begin
          if NoDiffChar then
              align1.Append(diffChar)
          else
              align1.Append(seq1^[i]);
          align2.Append(diffChar);
          dec(i);
        end
      else if score_current = score_right + gap_penalty then
        begin
          if NoDiffChar then
              align2.Append(diffChar)
          else
              align2.Append(seq2^[j]);
          align1.Append(diffChar);
          dec(j);
        end
      else
          raise Exception.Create('matrix error');
    end;
  System.FreeMemory(swMatrixPtr);
  // Append remaining characters.
  while i > 0 do
    begin
      if NoDiffChar then
          align1.Append(diffChar)
      else
          align1.Append(seq1^[i]);
      align2.Append(diffChar);
      dec(i);
    end;
  while j > 0 do
    begin
      if NoDiffChar then
          align2.Append(diffChar)
      else
          align2.Append(seq2^[j]);
      align1.Append(diffChar);
      dec(j);
    end;
  if identity > 0 then
      Result := identity / align1.Len
  else
      Result := -1;
  diff1 := align1.Invert;
  diff2 := align2.Invert;
end;

function USmithWatermanCompare(const seq1, seq2: PUPascalString; var diff1, diff2: TUPascalString): Double;
// Wrapper with default NoDiffChar=False, diffChar='-'.
begin
  Result := USmithWatermanCompare(seq1, seq2, diff1, diff2, False, '-');
end;

function USmithWatermanCompare(const seq1, seq2: TUPascalString; var diff1, diff2: TUPascalString;
  const NoDiffChar: Boolean; const diffChar: USystemChar): Double;
// Wrapper for TUPascalString parameters.
begin
  Result := USmithWatermanCompare(@seq1, @seq2, diff1, diff2, NoDiffChar, diffChar);
end;

function USmithWatermanCompare(const seq1, seq2: TUPascalString; var diff1, diff2: TUPascalString): Double;
begin
  Result := USmithWatermanCompare(seq1, seq2, diff1, diff2, False, '-');
end;

{ *************** Smith‑Waterman similarity only (out Same, Diff) *********** }

function USmithWatermanCompare(const seq1, seq2: PUPascalString; out Same, Diff: Integer): Double;
// Return similarity ratio and counts of matches (Same) and mismatches (Diff).

  function InlineMatch(alphaC, betaC: USystemChar): NativeInt;
  begin
    if UCharIn(alphaC, ucLoAtoZ) then
        dec(alphaC, 32);
    if UCharIn(betaC, ucLoAtoZ) then
        dec(betaC, 32);
    if alphaC = betaC then
        Result := SmithWaterman_MatchOk
    else
        Result := mismatch_penalty;
  end;

var
  swMatrixPtr: Pointer;
  i, j, L1, l2: NativeInt;
  matched, deleted, inserted: NativeInt;
  score_current, score_diagonal, score_left, score_right: NativeInt;
  identity, L_: NativeInt;
begin
  L1 := seq1^.Len; l2 := seq2^.Len;
  if (L1 = 0) or (l2 = 0) or (L1 > UMaxSmithWatermanMatrix) or (l2 > UMaxSmithWatermanMatrix) then
    begin
      Result := -1; Same := 0; Diff := L1 + l2; Exit;
    end;
  swMatrixPtr := GetSWMVMemory(L1, l2);
  if swMatrixPtr = nil then
    begin
      Result := -1; Exit;
    end;
  // Initialize first row and column.
  i := 0;
  while i <= L1 do
    begin
      SetSWMV(swMatrixPtr, L1, i, 0, gap_penalty * i); inc(i);
    end;
  j := 0;
  while j <= l2 do
    begin
      SetSWMV(swMatrixPtr, L1, 0, j, gap_penalty * j); inc(j);
    end;
  // Fill matrix.
  i := 1;
  while i <= L1 do
    begin
      j := 1;
      while j <= l2 do
        begin
          matched := GetSWMV(swMatrixPtr, L1, i - 1, j - 1) + InlineMatch(seq1^[i], seq2^[j]);
          deleted := GetSWMV(swMatrixPtr, L1, i - 1, j) + gap_penalty;
          inserted := GetSWMV(swMatrixPtr, L1, i, j - 1) + gap_penalty;
          SetSWMV(swMatrixPtr, L1, i, j, GetMax(matched, GetMax(deleted, inserted)));
          inc(j);
        end;
      inc(i);
    end;
  // Traceback to compute match count.
  i := L1; j := l2; identity := 0; L_ := 0;
  while (i > 0) and (j > 0) do
    begin
      score_current := GetSWMV(swMatrixPtr, L1, i, j);
      score_diagonal := GetSWMV(swMatrixPtr, L1, i - 1, j - 1);
      score_left := GetSWMV(swMatrixPtr, L1, i - 1, j);
      score_right := GetSWMV(swMatrixPtr, L1, i, j - 1);
      matched := InlineMatch(seq1^[i], seq2^[j]);
      if score_current = score_diagonal + matched then
        begin
          if matched = SmithWaterman_MatchOk then
              inc(identity);
          inc(L_); dec(i); dec(j);
        end
      else if score_current = score_left + gap_penalty then
        begin
          inc(L_); dec(i);
        end
      else if score_current = score_right + gap_penalty then
        begin
          inc(L_); dec(j);
        end
      else
          raise Exception.Create('matrix error');
    end;
  System.FreeMemory(swMatrixPtr);
  if identity > 0 then
    begin
      Result := identity / (L_ + i + j);
      Same := identity;
      Diff := (L_ + i + j) - identity;
    end
  else
    begin
      Result := -1;
      Same := 0;
      Diff := L_ + i + j;
    end;
end;

function USmithWatermanCompare(const seq1, seq2: PUPascalString): Double;
// Wrapper returning only similarity ratio.
var Same, Diff: Integer;
begin
  Result := USmithWatermanCompare(seq1, seq2, Same, Diff);
end;

function USmithWatermanCompare(const seq1, seq2: TUPascalString): Double;
begin
  Result := USmithWatermanCompare(@seq1, @seq2);
end;

function USmithWatermanCompare(const seq1: TUArrayPascalString; const seq2: TUPascalString): Double;
// Compare an array of strings against a single one, return the best similarity.
var i: Integer; r: Double;
begin
  Result := -1;
  for i := 0 to length(seq1) - 1 do
    begin
      r := USmithWatermanCompare(seq1[i], seq2);
      if r > Result then
          Result := r;
    end;
end;

{ *************** Smith‑Waterman for raw memory (byte arrays) *************** }

function USmithWatermanCompare(const seq1: Pointer; siz1: Integer; const seq2: Pointer; siz2: Integer;
  out Same, Diff: Integer): Double;
// Compare two memory blocks as byte sequences.

  function InlineMatch(const alphaB, betaB: Byte): NativeInt;
  begin
    if alphaB = betaB then
        Result := SmithWaterman_MatchOk
    else
        Result := mismatch_penalty;
  end;

var
  swMatrixPtr: Pointer;
  i, j, L1, l2: NativeInt;
  matched, deleted, inserted: NativeInt;
  score_current, score_diagonal, score_left, score_right: NativeInt;
  identity, L_: NativeInt;
begin
  L1 := siz1; l2 := siz2;
  if (L1 = 0) or (l2 = 0) or (L1 > UMaxSmithWatermanMatrix) or (l2 > UMaxSmithWatermanMatrix) then
    begin
      Result := -1; Same := 0; Diff := L1 + l2; Exit;
    end;
  swMatrixPtr := GetSWMVMemory(L1, l2);
  if swMatrixPtr = nil then
    begin
      Result := -1; Exit;
    end;
  i := 0;
  while i <= L1 do
    begin
      SetSWMV(swMatrixPtr, L1, i, 0, gap_penalty * i); inc(i);
    end;
  j := 0;
  while j <= l2 do
    begin
      SetSWMV(swMatrixPtr, L1, 0, j, gap_penalty * j); inc(j);
    end;
  i := 1;
  while i <= L1 do
    begin
      j := 1;
      while j <= l2 do
        begin
          matched := GetSWMV(swMatrixPtr, L1, i - 1, j - 1) + InlineMatch(PByte(nativeUInt(seq1) + (i - 1))^, PByte(nativeUInt(seq2) + (j - 1))^);
          deleted := GetSWMV(swMatrixPtr, L1, i - 1, j) + gap_penalty;
          inserted := GetSWMV(swMatrixPtr, L1, i, j - 1) + gap_penalty;
          SetSWMV(swMatrixPtr, L1, i, j, GetMax(matched, GetMax(deleted, inserted)));
          inc(j);
        end;
      inc(i);
    end;
  i := L1; j := l2; identity := 0; L_ := 0;
  while (i > 0) and (j > 0) do
    begin
      score_current := GetSWMV(swMatrixPtr, L1, i, j);
      score_diagonal := GetSWMV(swMatrixPtr, L1, i - 1, j - 1);
      score_left := GetSWMV(swMatrixPtr, L1, i - 1, j);
      score_right := GetSWMV(swMatrixPtr, L1, i, j - 1);
      matched := InlineMatch(PByte(nativeUInt(seq1) + (i - 1))^, PByte(nativeUInt(seq2) + (j - 1))^);
      if score_current = score_diagonal + matched then
        begin
          if matched = SmithWaterman_MatchOk then
              inc(identity);
          inc(L_); dec(i); dec(j);
        end
      else if score_current = score_left + gap_penalty then
        begin
          inc(L_); dec(i);
        end
      else if score_current = score_right + gap_penalty then
        begin
          inc(L_); dec(j);
        end
      else
          raise Exception.Create('matrix error');
    end;
  System.FreeMemory(swMatrixPtr);
  if identity > 0 then
    begin
      Result := identity / (L_ + i + j);
      Same := identity;
      Diff := (L_ + i + j) - identity;
    end
  else
    begin
      Result := -1;
      Same := 0;
      Diff := L_ + i + j;
    end;
end;

function USmithWatermanCompare(const seq1: Pointer; siz1: Integer; const seq2: Pointer; siz2: Integer): Double;
// Wrapper for raw memory compare (similarity only).
var Same, Diff: Integer;
begin
  Result := USmithWatermanCompare(seq1, siz1, seq2, siz2, Same, Diff);
end;

{ *************** Smith‑Waterman for long texts (line‑wise) ***************** }

function USmithWatermanCompareLongString(const t1, t2: TUPascalString; const MinDiffCharWithPeerLine: Integer; out Same, Diff: Integer): Double;
// Split texts into lines, compare line by line with a tolerance threshold.

type
  PSRec = ^TSRec;

  TSRec = record
    s: TUPascalString;
  end;

  procedure _FillText(psPtr: PUPascalString; outLst: TCore_List);
  // Extract non‑empty lines (ignoring spaces/tabs) and store as TSRec.
  var
    L_, i: Integer;
    n: TUPascalString;
    p: PSRec;
  begin
    L_ := psPtr^.Len;
    i := 1;
    n := '';
    while i <= L_ do
      begin
        if UCharIn(psPtr^[i], [#13, #10]) then
          begin
            n := n.DeleteChar(#32#9);
            if n.Len > 0 then
              begin
                new(p);
                p^.s := n;
                outLst.Add(p);
                n := '';
              end;
            repeat
                inc(i);
            until (i > L_) or (not UCharIn(psPtr^[i], [#13, #10, #32, #9]));
          end
        else
          begin
            n.Append(psPtr^[i]);
            inc(i);
          end;
      end;
    n := n.DeleteChar(#32#9);
    if n.Len > 0 then
      begin
        new(p);
        p^.s := n;
        outLst.Add(p);
      end;
  end;

  function InlineMatch(const alpha, beta: PSRec; const MinDiffCharWithPeerLine: Integer; var cSame, cDiff: Integer): NativeInt;
  // Compare two lines; if their similarity score >0 and cDiff < threshold, treat as match.
  begin
    if USmithWatermanCompare(@alpha^.s, @beta^.s, cSame, cDiff) > 0 then
      begin
        if cDiff < MinDiffCharWithPeerLine then
            Result := SmithWaterman_MatchOk
        else
            Result := mismatch_penalty;
      end
    else
        Result := mismatch_penalty;
  end;

var
  lst1, lst2: TCore_List;
  procedure _Init;
  begin
    lst1 := TCore_List.Create; lst2 := TCore_List.Create; _FillText(@t1, lst1); _FillText(@t2, lst2);
  end;
  procedure _Free;
  var i: Integer;
  begin
    for i := 0 to lst1.Count - 1 do
        Dispose(PSRec(lst1[i]));
    for i := 0 to lst2.Count - 1 do
        Dispose(PSRec(lst2[i]));
    DisposeObject([lst1, lst2]);
  end;

var
  swMatrixPtr: Pointer;
  i, j, L1, l2: NativeInt;
  matched, deleted, inserted: NativeInt;
  score_current, score_diagonal, score_left, score_right: NativeInt;
  cSame, cDiff, TotalSame, TotalDiff: Integer;
begin
  _Init;
  L1 := lst1.Count; l2 := lst2.Count;
  if (L1 = 0) or (l2 = 0) or (L1 > UMaxSmithWatermanMatrix) or (l2 > UMaxSmithWatermanMatrix) then
    begin
      Result := -1; Same := 0; Diff := L1 + l2; _Free; Exit;
    end;
  swMatrixPtr := GetSWMVMemory(L1, l2);
  if swMatrixPtr = nil then
    begin
      Result := -1; _Free; Exit;
    end;
  i := 0;
  while i <= L1 do
    begin
      SetSWMV(swMatrixPtr, L1, i, 0, gap_penalty * i); inc(i);
    end;
  j := 0;
  while j <= l2 do
    begin
      SetSWMV(swMatrixPtr, L1, 0, j, gap_penalty * j); inc(j);
    end;
  i := 1;
  while i <= L1 do
    begin
      j := 1;
      while j <= l2 do
        begin
          matched := GetSWMV(swMatrixPtr, L1, i - 1, j - 1) + InlineMatch(PSRec(lst1[i - 1]), PSRec(lst2[j - 1]), MinDiffCharWithPeerLine, cSame, cDiff);
          deleted := GetSWMV(swMatrixPtr, L1, i - 1, j) + gap_penalty;
          inserted := GetSWMV(swMatrixPtr, L1, i, j - 1) + gap_penalty;
          SetSWMV(swMatrixPtr, L1, i, j, GetMax(matched, GetMax(deleted, inserted)));
          inc(j);
        end;
      inc(i);
    end;
  i := L1; j := l2; TotalSame := 0; TotalDiff := 0;
  while (i > 0) and (j > 0) do
    begin
      score_current := GetSWMV(swMatrixPtr, L1, i, j);
      score_diagonal := GetSWMV(swMatrixPtr, L1, i - 1, j - 1);
      score_left := GetSWMV(swMatrixPtr, L1, i - 1, j);
      score_right := GetSWMV(swMatrixPtr, L1, i, j - 1);
      matched := InlineMatch(PSRec(lst1[i - 1]), PSRec(lst2[j - 1]), MinDiffCharWithPeerLine, cSame, cDiff);
      inc(TotalSame, cSame);
      inc(TotalDiff, cDiff);
      if score_current = score_diagonal + matched then
        begin
          dec(i); dec(j);
        end
      else if score_current = score_left + gap_penalty then
        begin
          dec(i);
        end
      else if score_current = score_right + gap_penalty then
        begin
          dec(j);
        end
      else
          raise Exception.Create('matrix error');
    end;
  System.FreeMemory(swMatrixPtr);
  _Free;
  if TotalSame > 0 then
    begin
      Result := TotalSame / (TotalSame + TotalDiff);
      Same := TotalSame;
      Diff := TotalDiff;
    end
  else
    begin
      Result := -1;
      Same := 0;
      Diff := t2.Len + t1.Len;
    end;
end;

function USmithWatermanCompareLongString(const t1, t2: TUPascalString): Double;
// Wrapper with default MinDiffCharWithPeerLine = 5.
var Same, Diff: Integer;
begin
  Result := USmithWatermanCompareLongString(t1, t2, 5, Same, Diff);
end;

{$IFDEF FPC}

// ----- FPC operator overload implementations --------------------------------

operator := (const s: Variant)r: TUPascalString;
begin
  r.Text := s;
end;

operator := (const s: AnsiString)r: TUPascalString;
begin
  r.Text := s;
end;

operator := (const s: RawByteString)r: TUPascalString;
begin
  r.Text := s;
end;

operator := (const s: UnicodeString)r: TUPascalString;
begin
  r.Text := s;
end;

operator := (const s: WideString)r: TUPascalString;
begin
  r.Text := s;
end;

operator := (const s: ShortString)r: TUPascalString;
begin
  r.Text := s;
end;

operator := (const c: USystemChar)r: TUPascalString;
begin
  r.Text := c;
end;

operator := (const c: SystemChar)r: TUPascalString;
begin
  r.Text := c;
end;

operator := (const c: TPascalString)r: TUPascalString;
begin
  Result.Bytes := c.Bytes;
end;

operator := (const s: TUPascalString)r: AnsiString;
begin
  r := s.Text;
end;

operator := (const s: TUPascalString)r: RawByteString;
begin
  r := s.Text;
end;

operator := (const s: TUPascalString)r: UnicodeString;
begin
  r := s.Text;
end;

operator := (const s: TUPascalString)r: WideString;
begin
  r := s.Text;
end;

operator := (const s: TUPascalString)r: ShortString;
begin
  r := s.Text;
end;

operator := (const s: TUPascalString)r: Variant;
begin
  r := s.Text;
end;

operator := (const s: TUPascalString)r: TPascalString;
begin
  Result.Bytes := s.Bytes;
end;

operator = (const a: TUPascalString; const b: TUPascalString): Boolean;
begin
  Result := a.Text = b.Text;
end;

operator = (const a: TUPascalString; const b: USystemString): Boolean;
begin
  Result := a.Text = b;
end;

operator <> (const a: TUPascalString; const b: TUPascalString): Boolean;
begin
  Result := a.Text <> b.Text;
end;

operator > (const a: TUPascalString; const b: TUPascalString): Boolean;
begin
  Result := a.Text > b.Text;
end;

operator >= (const a: TUPascalString; const b: TUPascalString): Boolean;
begin
  Result := a.Text >= b.Text;
end;

operator < (const a: TUPascalString; const b: TUPascalString): Boolean;
begin
  Result := a.Text < b.Text;
end;

operator <= (const a: TUPascalString; const b: TUPascalString): Boolean;
begin
  Result := a.Text <= b.Text;
end;

operator + (const a: TUPascalString; const b: TUPascalString): TUPascalString;
begin
  CombineCharsPP(a.buff, b.buff, Result.buff);
end;

operator + (const a: TUPascalString; const b: USystemString): TUPascalString;
begin
  CombineCharsPS(a.buff, b, Result.buff);
end;

operator + (const a: USystemString; const b: TUPascalString): TUPascalString;
begin
  CombineCharsSP(a, b.buff, Result.buff);
end;

operator + (const a: TUPascalString; const b: USystemChar): TUPascalString;
begin
  CombineCharsPC(a.buff, b, Result.buff);
end;

operator + (const a: USystemChar; const b: TUPascalString): TUPascalString;
begin
  CombineCharsCP(a, b.buff, Result.buff);
end;
{$ENDIF}

{ *************** TUPascalString methods implementation *********************** }

function TUPascalString.GetText: USystemString;
// Convert internal buff to USystemString (copy).
begin
  SetLength(Result, length(buff));
  if length(buff) > 0 then
      CopyPtr(@buff[0], @Result[UFirstCharPos], length(buff) * USystemCharSize);
end;

procedure TUPascalString.SetText(const Value: USystemString);
// Set internal buff from a USystemString.
begin
  SetLength(buff, length(Value));
  if length(buff) > 0 then
      CopyPtr(@Value[UFirstCharPos], @buff[0], length(buff) * USystemCharSize);
end;

function TUPascalString.GetLen: Integer;
begin
  Result := length(buff);
end;

procedure TUPascalString.SetLen(const Value: Integer);
begin
  SetLength(buff, Value);
end;

function TUPascalString.GetChars(index: Integer): USystemChar;
// 1‑based access; returns #0 if index out of range.
begin
  if (index > length(buff)) or (index <= 0) then
      Result := #0
  else
      Result := buff[index - 1];
end;

procedure TUPascalString.SetChars(index: Integer; const Value: USystemChar);
begin
  buff[index - 1] := Value;
end;

function TUPascalString.GetUTF8: TBytes;
// Convert to UTF‑8 bytes.
begin
  SetLength(Result, 0);
  if length(buff) = 0 then
      Exit;
{$IFDEF FPC}
  Result := SysUtils.TEncoding.UTF8.GetBytes(buff);
{$ELSE}
  Result := SysUtils.TEncoding.UTF8.GetBytes(buff);
{$ENDIF}
end;

procedure TUPascalString.SetUTF8(const Value: TBytes);
// Set content from UTF‑8 bytes; fallback to platform encoding on error.
begin
  SetLength(buff, 0);
  if length(Value) = 0 then
      Exit;
  try
      Text := SysUtils.TEncoding.UTF8.GetString(Value);
  except
      SetPlatformBytes(Value);
  end;
end;

function TUPascalString.GetPlatformBytes: TBytes;
// Convert to system default encoding bytes.
begin
  SetLength(Result, 0);
  if length(buff) = 0 then
      Exit;
{$IFDEF FPC}
  Result := SysUtils.TEncoding.Default.GetBytes(buff);
{$ELSE}
  Result := SysUtils.TEncoding.Default.GetBytes(buff);
{$ENDIF}
end;

procedure TUPascalString.SetPlatformBytes(const Value: TBytes);
// Set content from system default encoded bytes.
begin
  SetLength(buff, 0);
  if length(Value) = 0 then
      Exit;
  try
      Text := SysUtils.TEncoding.Default.GetString(Value);
  except
      SetLength(buff, 0);
  end;
end;

function TUPascalString.GetANSI: TBytes;
// Convert to Windows ANSI bytes.
begin
  SetLength(Result, 0);
  if length(buff) = 0 then
      Exit;
{$IFDEF FPC}
  Result := SysUtils.TEncoding.ANSI.GetBytes(Text);
{$ELSE}
  Result := SysUtils.TEncoding.ANSI.GetBytes(buff);
{$ENDIF}
end;

procedure TUPascalString.SetANSI(const Value: TBytes);
// Set content from Windows ANSI bytes.
begin
  SetLength(buff, 0);
  if length(Value) = 0 then
      Exit;
  try
      Text := SysUtils.TEncoding.ANSI.GetString(Value);
  except
      SetLength(buff, 0);
  end;
end;

function TUPascalString.GetLast: USystemChar;
begin
  if length(buff) > 0 then
      Result := buff[length(buff) - 1]
  else
      Result := #0;
end;

procedure TUPascalString.SetLast(const Value: USystemChar);
begin
  buff[length(buff) - 1] := Value;
end;

function TUPascalString.GetFirst: USystemChar;
begin
  if length(buff) > 0 then
      Result := buff[0]
  else
      Result := #0;
end;

procedure TUPascalString.SetFirst(const Value: USystemChar);
begin
  buff[0] := Value;
end;

function TUPascalString.GetUpperChar(index: Integer): USystemChar;
// Return character at index converted to uppercase (ASCII).
begin
  Result := GetChars(index);
  if UCharIn(Result, ucLoAtoZ) then
      Result := USystemChar(Word(Result) xor $0020);
end;

procedure TUPascalString.SetUpperChar(index: Integer; const Value: USystemChar);
// Set character at index after converting to uppercase (ASCII).
begin
  if UCharIn(Value, ucLoAtoZ) then
      SetChars(index, USystemChar(Word(Value) xor $0020))
  else
      SetChars(index, Value);
end;

function TUPascalString.GetLowerChar(index: Integer): USystemChar;
// Return character at index converted to lowercase (ASCII).
begin
  Result := GetChars(index);
  if UCharIn(Result, ucHiAtoZ) then
      Result := USystemChar(Word(Result) or $0020);
end;

procedure TUPascalString.SetLowerChar(index: Integer; const Value: USystemChar);
// Set character at index after converting to lowercase (ASCII).
begin
  if UCharIn(Value, ucHiAtoZ) then
      SetChars(index, USystemChar(Word(Value) or $0020))
  else
      SetChars(index, Value);
end;

{$IFDEF DELPHI}

// ----- Delphi operator overload implementations ----------------------------

class operator TUPascalString.Equal(const Lhs, Rhs: TUPascalString): Boolean;
begin
  Result := (Lhs.Len = Rhs.Len) and (Lhs.Text = Rhs.Text);
end;

class operator TUPascalString.NotEqual(const Lhs, Rhs: TUPascalString): Boolean;
begin
  Result := not(Lhs = Rhs);
end;

class operator TUPascalString.GreaterThan(const Lhs, Rhs: TUPascalString): Boolean;
begin
  Result := Lhs.Text > Rhs.Text;
end;

class operator TUPascalString.GreaterThanOrEqual(const Lhs, Rhs: TUPascalString): Boolean;
begin
  Result := Lhs.Text >= Rhs.Text;
end;

class operator TUPascalString.LessThan(const Lhs, Rhs: TUPascalString): Boolean;
begin
  Result := Lhs.Text < Rhs.Text;
end;

class operator TUPascalString.LessThanOrEqual(const Lhs, Rhs: TUPascalString): Boolean;
begin
  Result := Lhs.Text <= Rhs.Text;
end;

class operator TUPascalString.Add(const Lhs, Rhs: TUPascalString): TUPascalString;
begin
  CombineCharsPP(Lhs.buff, Rhs.buff, Result.buff);
end;

class operator TUPascalString.Add(const Lhs: USystemString; const Rhs: TUPascalString): TUPascalString;
begin
  CombineCharsSP(Lhs, Rhs.buff, Result.buff);
end;

class operator TUPascalString.Add(const Lhs: TUPascalString; const Rhs: USystemString): TUPascalString;
begin
  CombineCharsPS(Lhs.buff, Rhs, Result.buff);
end;

class operator TUPascalString.Add(const Lhs: USystemChar; const Rhs: TUPascalString): TUPascalString;
begin
  CombineCharsCP(Lhs, Rhs.buff, Result.buff);
end;

class operator TUPascalString.Add(const Lhs: TUPascalString; const Rhs: USystemChar): TUPascalString;
begin
  CombineCharsPC(Lhs.buff, Rhs, Result.buff);
end;

class operator TUPascalString.Implicit(Value: RawByteString): TUPascalString;
begin
  Result.Text := Value;
end;

class operator TUPascalString.Implicit(Value: TPascalString): TUPascalString;
begin
  Result.Bytes := Value.Bytes;
end;

class operator TUPascalString.Implicit(Value: USystemString): TUPascalString;
begin
  Result.Text := Value;
end;

class operator TUPascalString.Implicit(Value: USystemChar): TUPascalString;
begin
  Result.Len := 1; Result.buff[0] := Value;
end;

class operator TUPascalString.Implicit(Value: TUPascalString): USystemString;
begin
  Result := Value.Text;
end;

class operator TUPascalString.Implicit(Value: TUPascalString): Variant;
begin
  Result := Value.Text;
end;

class operator TUPascalString.Explicit(Value: TUPascalString): RawByteString;
begin
  Result := Value.Text;
end;

class operator TUPascalString.Explicit(Value: TUPascalString): TPascalString;
begin
  Result.Bytes := Value.Bytes;
end;

class operator TUPascalString.Explicit(Value: TUPascalString): USystemString;
begin
  Result := Value.Text;
end;

class operator TUPascalString.Explicit(Value: TUPascalString): Variant;
begin
  Result := Value.Text;
end;

class operator TUPascalString.Explicit(Value: USystemString): TUPascalString;
begin
  Result.Text := Value;
end;

class operator TUPascalString.Explicit(Value: USystemChar): TUPascalString;
begin
  Result.Len := 1; Result.buff[0] := Value;
end;
{$ENDIF}


procedure TUPascalString.SwapInstance(var source: TUPascalString);
// Exchange internal buffers.
var tmp: TUArrayChar;
begin
  tmp := buff;
  buff := source.buff;
  source.buff := tmp;
end;

function TUPascalString.Copy(index, Count: NativeInt): TUPascalString;
// Extract substring; adjust Count if it exceeds length.
var L_: NativeInt;
begin
  L_ := length(buff);
  if (index - 1) + Count > L_ then
      Count := L_ - (index - 1);
  SetLength(Result.buff, Count);
  if Count > 0 then
      CopyPtr(@buff[index - 1], @Result.buff[0], USystemCharSize * Count);
end;

function TUPascalString.Same(const p: PUPascalString): Boolean;
// Case‑insensitive equality with pointer.
var i: Integer; s, d: USystemChar;
begin
  Result := (p^.Len = Len);
  if not Result then
      Exit;
  for i := 0 to Len - 1 do
    begin
      s := buff[i];
      if UCharIn(s, ucHiAtoZ) then
          inc(s, 32);
      d := p^.buff[i];
      if UCharIn(d, ucHiAtoZ) then
          inc(d, 32);
      if s <> d then
          Exit(False);
    end;
end;

function TUPascalString.Same(const t: TUPascalString): Boolean;
// Case‑insensitive equality with TUPascalString.
var i: Integer; s, d: USystemChar;
begin
  Result := (t.Len = Len);
  if not Result then
      Exit;
  for i := 0 to Len - 1 do
    begin
      s := buff[i];
      if UCharIn(s, ucHiAtoZ) then
          inc(s, 32);
      d := t.buff[i];
      if UCharIn(d, ucHiAtoZ) then
          inc(d, 32);
      if s <> d then
          Exit(False);
    end;
end;

function TUPascalString.Same(const t1, t2: TUPascalString): Boolean;
// True if this string matches any of the two (case‑insensitive).
begin
  Result := Same(@t1) or Same(@t2);
end;

function TUPascalString.Same(const t1, t2, t3: TUPascalString): Boolean;
begin
  Result := Same(@t1) or Same(@t2) or Same(@t3);
end;

function TUPascalString.Same(const t1, t2, t3, t4: TUPascalString): Boolean;
begin
  Result := Same(@t1) or Same(@t2) or Same(@t3) or Same(@t4);
end;

function TUPascalString.Same(const t1, t2, t3, t4, t5: TUPascalString): Boolean;
begin
  Result := Same(@t1) or Same(@t2) or Same(@t3) or Same(@t4) or Same(@t5);
end;

function TUPascalString.Same(const t1, t2, t3, t4, t5, t6: TUPascalString): Boolean;
begin
  Result := Same(@t1) or Same(@t2) or Same(@t3) or Same(@t4) or Same(@t5) or Same(@t6);
end;

function TUPascalString.Same(const t1, t2, t3, t4, t5, t6, t7: TUPascalString): Boolean;
begin
  Result := Same(@t1) or Same(@t2) or Same(@t3) or Same(@t4) or Same(@t5) or Same(@t6) or Same(@t7);
end;

function TUPascalString.Same(const t1, t2, t3, t4, t5, t6, t7, t8: TUPascalString): Boolean;
begin
  Result := Same(@t1) or Same(@t2) or Same(@t3) or Same(@t4) or Same(@t5) or Same(@t6) or Same(@t7) or Same(@t8);
end;

function TUPascalString.Same(const t1, t2, t3, t4, t5, t6, t7, t8, t9: TUPascalString): Boolean;
begin
  Result := Same(@t1) or Same(@t2) or Same(@t3) or Same(@t4) or Same(@t5) or Same(@t6) or Same(@t7) or Same(@t8) or Same(@t9);
end;

function TUPascalString.Same(const IgnoreCase: Boolean; const t: TUPascalString): Boolean;
// Equality with optional case sensitivity.
var i: Integer; s, d: USystemChar;
begin
  Result := (t.Len = Len);
  if not Result then
      Exit;
  for i := 0 to Len - 1 do
    begin
      s := buff[i];
      if IgnoreCase and UCharIn(s, ucHiAtoZ) then
          inc(s, 32);
      d := t.buff[i];
      if IgnoreCase and UCharIn(d, ucHiAtoZ) then
          inc(d, 32);
      if s <> d then
          Exit(False);
    end;
end;

function TUPascalString.ComparePos(const Offset: Integer; const p: PUPascalString): Boolean;
// Compare substring at Offset with p (case‑insensitive).
begin
  Result := ComparePos(Offset, p, True);
end;

function TUPascalString.ComparePos(const Offset: Integer; const t: TUPascalString): Boolean;
begin
  Result := ComparePos(Offset, @t, True);
end;

function TUPascalString.ComparePos(const Offset: Integer; const p: PUPascalString; IgnoreCase: Boolean): Boolean;
// Implementation with IgnoreCase flag.
var i, L_: Integer; sourChar, destChar: USystemChar;
begin
  Result := False;
  i := 1;
  L_ := p^.Len;
  if (Offset + L_ - 1) > Len then
      Exit;
  while i <= L_ do
    begin
      sourChar := GetChars(Offset + i - 1);
      destChar := p^[i];
      if IgnoreCase and UCharIn(sourChar, ucLoAtoZ) then
          dec(sourChar, 32);
      if IgnoreCase and UCharIn(destChar, ucLoAtoZ) then
          dec(destChar, 32);
      if sourChar <> destChar then
          Exit;
      inc(i);
    end;
  Result := True;
end;

function TUPascalString.ComparePos(const Offset: Integer; const t: TUPascalString; IgnoreCase: Boolean): Boolean;
begin
  Result := ComparePos(Offset, @t, IgnoreCase);
end;

function TUPascalString.GetPos(const s: TUPascalString; const Offset: Integer = 1): Integer;
// Find first occurrence of s, starting from Offset.
var i: Integer;
begin
  Result := 0;
  if s.Len > 0 then
    for i := Offset to Len - s.Len + 1 do
      if ComparePos(i, @s) then
          Exit(i);
end;

function TUPascalString.GetPos(const s: PUPascalString; const Offset: Integer = 1): Integer;
var i: Integer;
begin
  Result := 0;
  if s^.Len > 0 then
    for i := Offset to Len - s^.Len + 1 do
      if ComparePos(i, s) then
          Exit(i);
end;

function TUPascalString.Exists(c: USystemChar): Boolean;
// Check if a single character exists.
var i: Integer;
begin
  for i := low(buff) to high(buff) do
    if buff[i] = c then
        Exit(True);
  Result := False;
end;

function TUPascalString.Exists(c: array of USystemChar): Boolean;
// Check if any character in the array exists.
var i: Integer;
begin
  for i := low(buff) to high(buff) do
    if UCharIn(buff[i], c) then
        Exit(True);
  Result := False;
end;

function TUPascalString.StrExists(const s: TUPascalString): Boolean;
// Check if substring exists.
begin
  Result := GetPos(@s, 1) > 0;
end;

function TUPascalString.GetCharCount(c: USystemChar): Integer;
// Count occurrences of character c.
var i: Integer;
begin
  Result := 0;
  for i := low(buff) to high(buff) do
    if UCharIn(buff[i], c) then
        inc(Result);
end;

function TUPascalString.IsVisibledASCII: Boolean;
// Check if all characters are visible (printable or >255).
var c: USystemChar;
begin
  Result := False;
  for c in buff do
    if not UCharIn(c, ucVisibled) then
        Exit;
  Result := True;
end;

function TUPascalString.hash: THash;
begin
  Result := UFastHashPPascalString(@Self);
end;

function TUPascalString.Hash64: THash64;
begin
  Result := UFastHash64PPascalString(@Self);
end;

procedure TUPascalString.DeleteLast;
begin
  if Len > 0 then
      SetLength(buff, length(buff) - 1);
end;

procedure TUPascalString.DeleteFirst;
begin
  if Len > 0 then
      buff := System.Copy(buff, 1, Len);
end;

procedure TUPascalString.Delete(idx, cnt: Integer);
// Remove cnt characters starting at idx.
begin
  if (idx + cnt <= Len) then
      Text := GetString(1, idx) + GetString(idx + cnt, Len + 1)
  else
      Text := GetString(1, idx);
end;

procedure TUPascalString.Clear;
begin
  SetLength(buff, 0);
end;

procedure TUPascalString.Reset;
begin
  SetLength(buff, 0);
end;

procedure TUPascalString.Append(t: TUPascalString);
// Append another TUPascalString.
var r, L_: Integer;
begin
  L_ := length(t.buff);
  if L_ > 0 then
    begin
      r := length(buff);
      SetLength(buff, r + L_);
      CopyPtr(@t.buff[0], @buff[r], L_ * USystemCharSize);
    end;
end;

procedure TUPascalString.Append(c: USystemChar);
// Append a single character.
begin
  SetLength(buff, length(buff) + 1);
  buff[length(buff) - 1] := c;
end;

procedure TUPascalString.Append(const Fmt: USystemString; const Args: array of const);
// Append formatted text.
begin
  Append(UFormat(Fmt, Args));
end;

function TUPascalString.GetString(bPos, ePos: NativeInt): TUPascalString;
// Extract substring from bPos to ePos-1.
begin
  if ePos > length(buff) then
      Result := Self.Copy(bPos, length(buff) - bPos + 1)
  else
      Result := Self.Copy(bPos, (ePos - bPos));
end;

procedure TUPascalString.Insert(Text_: USystemString; idx: Integer);
// Insert USystemString at position idx.
begin
  Text := GetString(1, idx) + Text_ + GetString(idx + 1, Len);
end;

procedure TUPascalString.FastAsText(var output: USystemString);
// Fast copy to output without additional allocation (output must be pre-allocated).
begin
  SetLength(output, length(buff));
  if length(buff) > 0 then
      CopyPtr(@buff[0], @output[UFirstCharPos], length(buff) * USystemCharSize);
end;

procedure TUPascalString.FastGetBytes(var output: TBytes);
// Fast UTF-8 conversion.
begin
{$IFDEF FPC}
  output := SysUtils.TEncoding.UTF8.GetBytes(buff);
{$ELSE}
  output := SysUtils.TEncoding.UTF8.GetBytes(buff);
{$ENDIF}
end;

function TUPascalString.LowerText: USystemString;
begin
  Result := LowerCase(Text);
end;

function TUPascalString.UpperText: USystemString;
begin
  Result := UpperCase(Text);
end;

function TUPascalString.ShortText(MaxL, LL_, RL_: Integer): TUPascalString;
begin
  if (L > MaxL) and (MaxL > (LL_ + RL_)) then
      Result.Text := GetString(1, LL_).Text + ' ... ' + GetString(L - RL_, L).Text
  else Result := Self;
end;

function TUPascalString.Invert: TUPascalString;
// Reverse the string.
var i, j: Integer;
begin
  SetLength(Result.buff, length(buff));
  j := low(Result.buff);
  for i := high(buff) downto low(buff) do
    begin
      Result.buff[j] := buff[i];
      inc(j);
    end;
end;

function TUPascalString.TrimChar(const Chars: TUPascalString): TUPascalString;
// Trim leading/trailing characters that are in Chars.
var L_, bp, EP: Integer;
begin
  Result := '';
  L_ := Len;
  if L_ > 0 then
    begin
      bp := 1;
      while UCharIn(GetChars(bp), @Chars) do
        begin
          inc(bp);
          if (bp > L_) then
            begin
              Result := ''; Exit;
            end;
        end;
      if bp > L_ then
          Result := ''
      else
        begin
          EP := L_;
          while UCharIn(GetChars(EP), @Chars) do
            begin
              dec(EP);
              if (EP < 1) then
                begin
                  Result := ''; Exit;
                end;
            end;
          Result := GetString(bp, EP + 1);
        end;
    end;
end;

function TUPascalString.TrimLeftChar(const Chars: TUPascalString): TUPascalString;
var
  L_, bp: Integer;
begin
  L_ := Len;
  if L_ = 0 then
      Exit('');

  bp := 1;
  while (bp <= L_) and CharIn(GetChars(bp), @Chars) do
      inc(bp);

  if bp > L_ then
      Result := ''
  else
      Result := GetString(bp, L_ + 1);
end;

function TUPascalString.TrimRightChar(const Chars: TUPascalString): TUPascalString;
var
  L_, EP: Integer;
begin
  L_ := Len;
  if L_ = 0 then
      Exit('');

  EP := L_;
  while (EP >= 1) and CharIn(GetChars(EP), @Chars) do
      dec(EP);

  if EP < 1 then
      Result := ''
  else
      Result := GetString(1, EP + 1);
end;

function TUPascalString.DeleteChar(const Chars: TUPascalString): TUPascalString;
// Remove all characters found in Chars.
var c: USystemChar;
begin
  Result := '';
  for c in buff do
    if not UCharIn(c, @Chars) then
        Result.Append(c);
end;

function TUPascalString.DeleteChar(const Chars: TUOrdChars): TUPascalString;
// Remove all characters matching any category in Chars.
var c: USystemChar;
begin
  Result := '';
  for c in buff do
    if not UCharIn(c, Chars) then
        Result.Append(c);
end;

function TUPascalString.ReplaceChar(const Chars: TUPascalString; const newChar: USystemChar): TUPascalString;
// Replace all characters in Chars with newChar.
var i: Integer;
begin
  Result.Len := Len;
  for i := low(buff) to high(buff) do
    if UCharIn(buff[i], Chars) then
        Result.buff[i] := newChar
    else
        Result.buff[i] := buff[i];
end;

function TUPascalString.ReplaceChar(const Chars, newChar: USystemChar): TUPascalString;
// Replace a single character with newChar.
var i: Integer;
begin
  Result.Len := Len;
  for i := low(buff) to high(buff) do
    if UCharIn(buff[i], Chars) then
        Result.buff[i] := newChar
    else
        Result.buff[i] := buff[i];
end;

function TUPascalString.ReplaceChar(const Chars: TUOrdChars; const newChar: USystemChar): TUPascalString;
// Replace all characters matching any category in Chars with newChar.
var i: Integer;
begin
  Result.Len := Len;
  for i := low(buff) to high(buff) do
    if UCharIn(buff[i], Chars) then
        Result.buff[i] := newChar
    else
        Result.buff[i] := buff[i];
end;

{$IFDEF RangeCheck}{$R-}{$ENDIF}


function TUPascalString.BuildAnsiChar(var siz: Integer): Pointer;
// Allocate null‑terminated ANSI buffer; caller must free.
type
  TAnsiChar_Buff = array [0 .. 0] of Byte;
  PAnsiChar_Buff = ^TAnsiChar_Buff;
var swap_buff: TBytes; buff_P: PAnsiChar_Buff;
begin
  swap_buff := ANSI;
  siz := DeltaStep(length(swap_buff) + 1, 16);
  buff_P := GetMemory(siz);
  if length(swap_buff) > 0 then
      CopyPtr(@swap_buff[0], buff_P, length(swap_buff));
  buff_P^[length(swap_buff)] := 0;
  SetLength(swap_buff, 0);
  Result := buff_P;
end;

function TUPascalString.BuildAnsiChar: Pointer;
var
  siz: Integer;
begin
  Result := BuildAnsiChar(siz);
end;

procedure TUPascalString.ReadAnsiChar(p: Pointer; MaxSiz: NativeInt);
// Read null‑terminated ANSI buffer into string.
var n: NativeInt; buff_: TBytes;
begin
  n := 0;
  while (PByte(GetPtr(p, n))^ <> 0) and (n < MaxSiz) do
      inc(n);
  SetLength(buff_, n);
  CopyPtr(p, @buff_[0], n);
  ANSI := buff_;
  SetLength(buff_, 0);
end;

procedure TUPascalString.ReadAnsiChar(p: Pointer);
// Read null‑terminated ANSI buffer into string.
var n: NativeInt; buff_: TBytes;
begin
  n := 0;
  while PByte(GetPtr(p, n))^ <> 0 do
    begin
      inc(n);
    end;
  SetLength(buff_, n);
  CopyPtr(p, @buff_[0], n);
  ANSI := buff_;
  SetLength(buff_, 0);
end;

class function TUPascalString.ReadAnsiCharTo(p: Pointer; MaxSiz: NativeInt): TUPascalString;
begin
  Result.ReadAnsiChar(p, MaxSiz);
end;

class function TUPascalString.ReadAnsiCharTo(p: Pointer): TUPascalString;
begin
  Result.ReadAnsiChar(p);
end;

class function TUPascalString.AllocAnsiChar(size_: NativeInt): Pointer;
begin
  Result := GetMemory(size_);
  FillPtr(Result, size_, 0);
end;

class procedure TUPascalString.FreeAnsiChar(p: Pointer);
begin
  if p <> nil then
      FreeMemory(p);
end;

function TUPascalString.BuildWideChar(var siz: Integer): Pointer;
// Allocate null‑terminated WideChar (UTF‑16) buffer.
type
  PWord_ = ^Word;
var p_: PWord_;
begin
  siz := DeltaStep(length(buff) + 1, 16) * 2;
  p_ := GetMemory(siz);
  if length(buff) > 0 then
      CopyPtr(@buff[0], p_, length(buff) shl 1);
  PWord_(GetPtr(p_, length(buff) shl 1))^ := 0;
  Result := p_;
end;

function TUPascalString.BuildWideChar: Pointer;
var
  siz: Integer;
begin
  Result := BuildWideChar(siz);
end;

procedure TUPascalString.ReadWideChar(p: Pointer; MaxSiz: NativeInt);
// Read null‑terminated WideChar buffer.
var n: NativeInt;
begin
  n := 0;
  while (PWord(GetPtr(p, n))^ <> 0) and (n < MaxSiz) do
      inc(n, 2);

  if n > MaxSiz then
      n := MaxSiz;

  SetLength(buff, n shr 1);
  CopyPtr(p, @buff[0], n);
end;

procedure TUPascalString.ReadWideChar(p: Pointer);
// Read null‑terminated WideChar buffer.
var n: NativeInt;
begin
  n := 0;
  while PWord(GetPtr(p, n))^ <> 0 do
      inc(n, 2);
  SetLength(buff, n shr 1);
  CopyPtr(p, @buff[0], n);
end;

class function TUPascalString.ReadWideCharTo(p: Pointer; MaxSiz: NativeInt): TUPascalString;
begin
  Result.ReadWideChar(p, MaxSiz);
end;

class function TUPascalString.ReadWideCharTo(p: Pointer): TUPascalString;
begin
  Result.ReadWideChar(p);
end;

class function TUPascalString.AllocWideChar(size_: NativeInt): Pointer;
begin
  Result := GetMemory(size_ * 2);
  FillPtr(Result, size_ * 2, 0);
end;

class procedure TUPascalString.FreeWideChar(p: Pointer);
begin
  if p <> nil then
      FreeMemory(p);
end;

function TUPascalString.BuildUTF8AnsiChar(var siz: Integer): Pointer;
type
  TAnsiChar_Buff = array [0 .. 0] of Byte;
  PAnsiChar_Buff = ^TAnsiChar_Buff;
var swap_buff: TBytes; buff_P: PAnsiChar_Buff;
begin
  swap_buff := UTF8;
  siz := DeltaStep(length(swap_buff) + 1, 16);
  buff_P := GetMemory(siz);
  if length(swap_buff) > 0 then
      CopyPtr(@swap_buff[0], buff_P, length(swap_buff));
  buff_P^[length(swap_buff)] := 0;
  SetLength(swap_buff, 0);
  Result := buff_P;
end;

function TUPascalString.BuildUTF8AnsiChar: Pointer;
var
  siz: Integer;
begin
  Result := BuildUTF8AnsiChar(siz);
end;

procedure TUPascalString.ReadUTF8AnsiChar(p: Pointer; MaxSiz: NativeInt);
var n: NativeInt; buff_: TBytes;
begin
  n := 0;
  while (PByte(GetPtr(p, n))^ <> 0) and (n < MaxSiz) do
      inc(n);
  SetLength(buff_, n);
  CopyPtr(p, @buff_[0], n);
  UTF8 := buff_;
  SetLength(buff_, 0);
end;

procedure TUPascalString.ReadUTF8AnsiChar(p: Pointer);
var n: NativeInt; buff_: TBytes;
begin
  n := 0;
  while PByte(GetPtr(p, n))^ <> 0 do
      inc(n);
  SetLength(buff_, n);
  CopyPtr(p, @buff_[0], n);
  UTF8 := buff_;
  SetLength(buff_, 0);
end;

class function TUPascalString.ReadUTF8AnsiCharTo(p: Pointer; MaxSiz: NativeInt): TUPascalString;
begin
  Result.ReadUTF8AnsiChar(p, MaxSiz);
end;

class function TUPascalString.ReadUTF8AnsiCharTo(p: Pointer): TUPascalString;
begin
  Result.ReadUTF8AnsiChar(p);
end;

class function TUPascalString.AllocUTF8AnsiChar(size_: NativeInt): Pointer;
begin
  Result := GetMemory(size_);
  FillPtr(Result, size_, 0);
end;

class procedure TUPascalString.FreeUTF8AnsiChar(p: Pointer);
begin
  if p <> nil then
      FreeMemory(p);
end;

{$IFDEF RangeCheck}{$R+}{$ENDIF}


class function TUPascalString.RandomString(rnd: TRandom; L_: Integer): TUPascalString;
// Generate random printable ASCII string using given random generator.
var i: Integer;
begin
  Result.L := L_;
  for i := 1 to L_ do
      Result[i] := USystemChar(rnd.Rand32($7E - $20) + $20);
end;

class function TUPascalString.RandomString(L_: Integer): TUPascalString;
// Generate random printable ASCII string using a new Mersenne Twister.
var i: Integer; rnd: TMT19937Random;
begin
  Result.L := L_;
  rnd := TMT19937Random.Create;
  for i := 1 to L_ do
      Result[i] := USystemChar(rnd.Rand32($7E - $20) + $20);
  DisposeObject(rnd);
end;

class function TUPascalString.RandomString(rnd: TRandom; L_: Integer; Chars_: TUOrdChars): TUPascalString;
// Generate random string restricted to character categories.
var i: Integer; tmp: USystemChar;
begin
  Result.L := L_;
  for i := 1 to L_ do
    begin
      repeat
          tmp := USystemChar(rnd.Rand32($7E - $20) + $20);
      until UCharIn(tmp, Chars_);
      Result[i] := tmp;
    end;
end;

class function TUPascalString.RandomString(L_: Integer; Chars_: TUOrdChars): TUPascalString;
// Generate random string using a new Mersenne Twister with category restriction.
var i: Integer; rnd: TMT19937Random; tmp: USystemChar;
begin
  Result.L := L_;
  rnd := TMT19937Random.Create;
  for i := 1 to L_ do
    begin
      repeat
          tmp := USystemChar(rnd.Rand32($7E - $20) + $20);
      until UCharIn(tmp, Chars_);
      Result[i] := tmp;
    end;
  DisposeObject(rnd);
end;

function TUPascalString.SmithWaterman(const p: PUPascalString): Double;
begin
  Result := USmithWatermanCompare(@Self, @p);
end;

function TUPascalString.SmithWaterman(const s: TUPascalString): Double;
begin
  Result := USmithWatermanCompare(@Self, @s);
end;

function TUPascalString.BOMBytes: TBytes;
// Return UTF‑8 bytes with BOM on Delphi; FPC returns plain UTF‑8.
var
  Preamble_Buff, UTF8_Buff: TBytes;
begin
  Preamble_Buff := SysUtils.TEncoding.UTF8.GetPreamble;
  UTF8_Buff := UTF8;
  SetLength(Result, length(Preamble_Buff) + length(UTF8_Buff));
  CopyPtr(@Preamble_Buff[0], @Result[0], length(Preamble_Buff));
  CopyPtr(@UTF8_Buff[0], @Result[length(Preamble_Buff)], length(UTF8_Buff));
  SetLength(Preamble_Buff, 0);
  SetLength(UTF8_Buff, 0);
end;

end.

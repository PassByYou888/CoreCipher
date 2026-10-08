{ ******************************************************************************
  * Z.PascalStrings – High‑Performance String Type with Cross‑Compiler Support
  *
  * This unit defines TPascalString, a custom string record designed for
  * maximum performance and portability across Delphi and Free Pascal. Unlike
  * native string types (which may be reference‑counted under some compilers),
  * TPascalString is a value type stored on the stack, with direct access to
  * its internal character buffer. This makes it ideal for high‑throughput
  * text processing, parsing, and network applications.
  *
  * ===========================================================================
  * Key design principles
  * ===========================================================================
  *   – Cross‑compiler abstraction – under FPC, SystemChar = AnsiChar (1 byte);
  *     under Delphi, SystemChar = Char (2 bytes, UTF‑16). All operations
  *     adapt to the underlying representation.
  *   – Value type – no reference counting, no hidden allocations on copy.
  *   – Direct buffer access – internal buff is a dynamic array of SystemChar,
  *     enabling fast block operations with CopyPtr.
  *   – Operator overloading – behaves like a native string (+ for concat,
  *     = for comparison, etc.) while providing extra features.
  *   – Encoding‑aware – built‑in conversion to/from UTF‑8, ANSI, and platform
  *     default encodings.
  *   – Algorithmic support – Smith‑Waterman sequence alignment for similarity
  *     scoring, random generation, and fast hashing.
  *
  * ===========================================================================
  * Typical usage
  * ===========================================================================
  *   var
  *     s, t: TPascalString;
  *     i: Integer;
  *     bytes: TBytes;
  *   begin
  *     s := 'Hello, World!';              // Implicit conversion from native string
  *     t := s.Copy(1, 5);                 // t = 'Hello'
  *     s.Chars[1] := 'h';                 // Direct character access (1‑based)
  *     i := s.GetPos('World');            // Returns position (1‑based) or 0
  *     bytes := s.Bytes;                  // UTF‑8 encoded bytes
  *     s.Append(' number %d', [42]);      // Formatted append
  *     if s.SmithWaterman(t) > 0.8 then   // Similarity check
  *       DoStatus('Strings are similar');
  *   end;
  *
  * ===========================================================================
  * Smith‑Waterman alignment example
  * ===========================================================================
  *   var
  *     a, b, diff1, diff2: TPascalString;
  *     score: Double;
  *   begin
  *     a := 'kitten';
  *     b := 'sitting';
  *     // Compute alignment and difference strings
  *     score := SmithWatermanCompare(a, b, diff1, diff2, False, '-');
  *     // diff1 and diff2 show the alignment with '-' indicating gaps.
  *   end;
  ****************************************************************************** }
unit Z.PascalStrings;

{$UNDEF FPC_DELPHI_MODE}
{$I Z.Define.inc}

interface

uses Z.Core;

type
{$IFDEF FPC}
  { Under Free Pascal, the native character type is AnsiChar (1 byte). }
  SystemChar = AnsiChar;
  { Under Free Pascal, the native string type is AnsiString (single‑byte). }
  SystemString = AnsiString;
{$ELSE FPC}
  { Under Delphi, the native character type is Char (WideChar, 2 bytes, UTF‑16). }
  SystemChar = Char;
  { Under Delphi, the native string type is string (UnicodeString). }
  SystemString = string;
{$ENDIF FPC}
  PSystemChar = ^SystemChar; // Pointer to a character.
  TArrayChar = array of SystemChar; // Dynamic array of characters.
  PSystemString = ^SystemString; // Pointer to a native string.
  PPascalString = ^TPascalString; // Pointer to a TPascalString.

  { ----------------------------------------------------------------------------
    TOrdChar – Character category enumeration for fast classification.

    These constants are used with CharIn() and TextIs() to quickly test
    whether a character belongs to a certain group (digits, letters, control
    characters, etc.) without requiring regular expressions or complex
    conditionals.

    Values:
    c0to9        – '0'..'9'
    c1to9        – '1'..'9'
    c0to32       – ASCII 0..31 plus space (32)
    c0to32no10   – Same as c0to32 but excluding line feed (#10)
    cLoAtoF      – 'a'..'f'
    cHiAtoF      – 'A'..'F'
    cLoAtoZ      – 'a'..'z'
    cHiAtoZ      – 'A'..'Z'
    cHex         – 0..9, a..f, A..F (hexadecimal digits)
    cAtoF        – a..f, A..F
    cAtoZ        – a..z, A..Z
    cVisibled    – Printable ASCII (0x20‑0x7E) or any character > 255
    cDoubleChar  – Characters with ordinal > 255 (only relevant under Delphi)

    @Example:
    if CharIn('A', cHiAtoZ) then ...      // true
    if TextIs(s, [c0to9, cAtoZ]) then ... // s contains only alphanumerics
  }
  TOrdChar = (c0to9, c1to9, c0to32, c0to32no10,
    cLoAtoF, cHiAtoF, cLoAtoZ, cHiAtoZ,
    cHex, cAtoF, cAtoZ, cVisibled, cDoubleChar);
  TOrdChars = set of TOrdChar; // A set of character categories.

  { ----------------------------------------------------------------------------
    TPascalString – Core string record.

    This is the primary type of the unit. It stores characters in a dynamic
    array (buff) and provides a comprehensive set of methods for string
    manipulation, encoding conversion, hashing, and similarity scoring.

    All operations are efficient and use block memory copying where possible.
    The record is a value type, so assignment copies the buffer (but can be
    optimised with SwapInstance for exchanging without copying).

    @Example:
    var s: TPascalString;
    begin
    s := 'test';
    s.Chars[2] := 'o';   // s = 'tost'
    s.Append('!');       // s = 'tost!'
    s.Bytes := UTF8Bytes; // Decode from UTF‑8
    end;
  }
  TPascalString = record
  private
    // ----- Property getters and setters (internal) --------------------------

    function GetText: SystemString;
    procedure SetText(const Value: SystemString);

    function GetLen: Integer;
    procedure SetLen(const Value: Integer);

    function GetChars(index: Integer): SystemChar;
    procedure SetChars(index: Integer; const Value: SystemChar);

    function GetUTF8: TBytes;
    procedure SetUTF8(const Value: TBytes);

    function GetPlatformBytes: TBytes;
    procedure SetPlatformBytes(const Value: TBytes);

    function GetANSI: TBytes;
    procedure SetANSI(const Value: TBytes);

    function GetLast: SystemChar;
    procedure SetLast(const Value: SystemChar);

    function GetFirst: SystemChar;
    procedure SetFirst(const Value: SystemChar);

    function GetUpperChar(index: Integer): SystemChar;
    procedure SetUpperChar(index: Integer; const Value: SystemChar);

    function GetLowerChar(index: Integer): SystemChar;
    procedure SetLowerChar(index: Integer; const Value: SystemChar);

  public
    buff: TArrayChar; // Internal storage – 0‑based dynamic array of characters.

{$IFDEF DELPHI}
    // ----- Comparison operators (Delphi only) -----------------------------
    // These enable natural syntax: if s1 = s2 then ...
    class operator Equal(const Lhs, Rhs: TPascalString): Boolean;
    class operator NotEqual(const Lhs, Rhs: TPascalString): Boolean;
    class operator GreaterThan(const Lhs, Rhs: TPascalString): Boolean;
    class operator GreaterThanOrEqual(const Lhs, Rhs: TPascalString): Boolean;
    class operator LessThan(const Lhs, Rhs: TPascalString): Boolean;
    class operator LessThanOrEqual(const Lhs, Rhs: TPascalString): Boolean;

    // ----- Concatenation operators (Delphi only) ---------------------------
    // Enable natural syntax: s := 'Hello' + ' ' + 'World';
    class operator Add(const Lhs, Rhs: TPascalString): TPascalString;
    class operator Add(const Lhs: SystemString; const Rhs: TPascalString): TPascalString;
    class operator Add(const Lhs: TPascalString; const Rhs: SystemString): TPascalString;
    class operator Add(const Lhs: SystemChar; const Rhs: TPascalString): TPascalString;
    class operator Add(const Lhs: TPascalString; const Rhs: SystemChar): TPascalString;

    // ----- Implicit conversions (Delphi only) ------------------------------
    // Allow automatic conversion from native strings and characters.
    class operator Implicit(Value: RawByteString): TPascalString;
    class operator Implicit(Value: SystemString): TPascalString;
    class operator Implicit(Value: SystemChar): TPascalString;
    class operator Implicit(Value: TPascalString): SystemString;
    class operator Implicit(Value: TPascalString): Variant;

    // ----- Explicit conversions (Delphi only) ------------------------------
    // Allow explicit casting when needed.
    class operator Explicit(Value: TPascalString): RawByteString;
    class operator Explicit(Value: TPascalString): SystemString;
    class operator Explicit(Value: SystemString): TPascalString;
    class operator Explicit(Value: SystemChar): TPascalString;
    class operator Explicit(Value: TPascalString): Variant;
{$ENDIF}
    { * Efficiently exchanges the internal buffer with another instance.
      * This is an O(1) operation – only pointers are swapped, no data is copied.
      * @param source The other TPascalString to swap with.
      * @Example:
      *   var a, b: TPascalString;
      *   begin a := 'one'; b := 'two'; a.SwapInstance(b); // a='two', b='one'
    }
    procedure SwapInstance(var source: TPascalString);

    { * Extracts a substring from the current string.
      * @param index 1‑based start position (must be >= 1).
      * @param Count Number of characters to copy. If Count extends beyond the
      *              end of the string, it is automatically truncated.
      * @return A new TPascalString containing the extracted substring.
      * @Example:
      *   var s := 'abcdef';
      *   t := s.Copy(2, 3); // t = 'bcd'
    }
    function Copy(index, Count: NativeInt): TPascalString;

    // ----- Case‑insensitive equality tests (ASCII only) --------------------

    { * Checks if this string equals another, ignoring ASCII case differences.
      * Multiple overloads allow comparing against one or more strings.
      * @param p / t The other string(s) to compare.
      * @return True if any of the provided strings matches this one ignoring case.
      * @Example:
      *   var s := 'Hello';
      *   if s.Same('HELLO', 'world') then ... // true because 'Hello' = 'HELLO'
    }
    function Same(const p: PPascalString): Boolean; overload;
    function Same(const t: TPascalString): Boolean; overload;
    function Same(const t1, t2: TPascalString): Boolean; overload;
    function Same(const t1, t2, t3: TPascalString): Boolean; overload;
    function Same(const t1, t2, t3, t4: TPascalString): Boolean; overload;
    function Same(const t1, t2, t3, t4, t5: TPascalString): Boolean; overload;
    function Same(const t1, t2, t3, t4, t5, t6: TPascalString): Boolean; overload;
    function Same(const t1, t2, t3, t4, t5, t6, t7: TPascalString): Boolean; overload;
    function Same(const t1, t2, t3, t4, t5, t6, t7, t8: TPascalString): Boolean; overload;
    function Same(const t1, t2, t3, t4, t5, t6, t7, t8, t9: TPascalString): Boolean; overload;

    { * Equality test with optional case sensitivity.
      * @param IgnoreCase if True, ignore ASCII case differences.
      * @param t The string to compare against.
      * @return True if the strings are equal according to the IgnoreCase flag.
    }
    function Same(const IgnoreCase: Boolean; const t: TPascalString): Boolean; overload;

    // ----- Position‑based comparison (for fast substring checks) -----------

    { * Checks whether a given substring occurs at a specific offset.
      * This is faster than GetPos when you already know the approximate location.
      * @param Offset 1‑based starting position in this string.
      * @param p / t   Substring to look for.
      * @param IgnoreCase if True, ignore case.
      * @return True if the substring exactly matches at that offset.
      * @Example:
      *   var s := 'Hello World';
      *   if s.ComparePos(7, 'World') then ... // true
    }
    function ComparePos(const Offset: Integer; const p: PPascalString): Boolean; overload;
    function ComparePos(const Offset: Integer; const t: TPascalString): Boolean; overload;
    function ComparePos(const Offset: Integer; const p: PPascalString; IgnoreCase: Boolean): Boolean; overload;
    function ComparePos(const Offset: Integer; const t: TPascalString; IgnoreCase: Boolean): Boolean; overload;

    // ----- Substring search -------------------------------------------------

    { * Finds the first occurrence of a substring, starting from an offset.
      * @param s / p Substring to locate.
      * @param Offset 1‑based position to start searching from (default 1).
      * @return 1‑based index of the first occurrence, or 0 if not found.
      * @Example:
      *   var s := 'abcabc';
      *   p := s.GetPos('bc', 2); // p = 4 (position of second 'bc')
    }
    function GetPos(const s: TPascalString; const Offset: Integer = 1): Integer; overload;
    function GetPos(const s: PPascalString; const Offset: Integer = 1): Integer; overload;

    // ----- Character existence tests ---------------------------------------

    { * Checks if a single character exists in the string.
      * @param c character to test.
      * @return True if c appears at least once.
    }
    function Exists(c: SystemChar): Boolean; overload;

    { * Checks if any character from an array exists in the string.
      * @param c array of characters to test.
      * @return True if any character from the array appears.
    }
    function Exists(c: array of SystemChar): Boolean; overload;

    { * Checks if a substring exists in the string.
      * @param s substring to search.
      * @return True if s appears.
    }
    function StrExists(const s: TPascalString): Boolean;

    { * Counts how many times a specific character appears.
      * @param c character to count.
      * @return number of occurrences.
    }
    function GetCharCount(c: SystemChar): Integer;

    { * Checks if all characters are printable ASCII (0x20‑0x7E) or > 255.
      * @return True if every character is visible (non‑control).
    }
    function IsVisibledASCII: Boolean;

    // ----- Hashing ---------------------------------------------------------

    { * Computes a 32‑bit hash of the string (ASCII letters folded to lower case).
      * The hash is case‑insensitive for A‑Z letters.
      * @return THash (32‑bit) value.
    }
    function hash: THash;

    { * Computes a 64‑bit hash (case‑insensitive for ASCII letters).
      * @return THash64 (64‑bit) value.
    }
    function Hash64: THash64;

    // ----- Properties for first/last character (read/write) ----------------

    property Last: SystemChar read GetLast write SetLast; // The last character.
    property First: SystemChar read GetFirst write SetFirst; // The first character.

    // ----- Deletion operations ---------------------------------------------

    procedure DeleteLast; // Remove the last character.
    procedure DeleteFirst; // Remove the first character.

    { * Removes a range of characters from the string.
      * @param idx 1‑based start index.
      * @param cnt number of characters to delete.
    }
    procedure Delete(idx, cnt: Integer);

    // ----- Clear / reset ---------------------------------------------------

    procedure Clear; // Set length to zero.
    procedure Reset; // Same as Clear.

    // ----- Append operations ----------------------------------------------

    { * Appends content to the end of the string. Multiple overloads allow
      * appending another TPascalString, a single character, or formatted text.
      * @param t Another TPascalString to append.
      * @param c A single character to append.
      * @param Fmt Format string with arguments.
      * @Example:
      *   var s: TPascalString; s := 'Hello';
      *   s.Append(' World');      // s = 'Hello World'
      *   s.Append(' number %d', [42]); // s = 'Hello World number 42'
    }
    procedure Append(t: TPascalString); overload;
    procedure Append(c: SystemChar); overload;
    procedure Append(const Fmt: SystemString; const Args: array of const); overload;

    // ----- Substring extraction -------------------------------------------

    { * Returns a substring from bPos to ePos‑1 (half‑open interval).
      * @param bPos 1‑based start position.
      * @param ePos 1‑based end position (exclusive).
      * @return substring from bPos to ePos‑1.
    }
    function GetString(bPos, ePos: NativeInt): TPascalString;

    // ----- Insertion ------------------------------------------------------

    { * Inserts a native SystemString at the given 1‑based index.
      * @param Text_ text to insert.
      * @param idx insertion position; if idx > length, text is appended.
    }
    procedure Insert(Text_: SystemString; idx: Integer);

    // ----- Fast conversions (avoid temporary allocations) -----------------

    { * Fills a pre‑allocated SystemString with the string data.
      * This avoids an extra copy when the output variable already has capacity.
      * @param output SystemString variable to receive the data.
    }
    procedure FastAsText(var output: SystemString);

    { * Fills a pre‑allocated TBytes with UTF‑8 encoded data.
      * @param output TBytes variable to receive the UTF‑8 data.
    }
    procedure FastGetBytes(var output: TBytes);

    // ----- Case conversion -------------------------------------------------

    property Text: SystemString read GetText write SetText; // Native string representation.

    { * Returns a lower‑case copy of the string (using SysUtils.LowerCase).
      * @return lower‑case SystemString.
    }
    function LowerText: SystemString;

    { * Returns an upper‑case copy of the string (using SysUtils.UpperCase).
      * @return upper‑case SystemString.
    }
    function UpperText: SystemString;

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
    function ShortText(MaxL, LL_, RL_: Integer): TPascalString;

    // ----- Inversion (reverse) --------------------------------------------

    { * Returns a reversed copy of the string.
      * @return new TPascalString with characters in reverse order.
    }
    function Invert: TPascalString;

    // ----- Trimming and filtering -----------------------------------------

    { * Removes all leading and trailing characters that belong to the given set.
      * @param Chars set of characters to trim.
      * @return new string with trimmed ends.
    }
    function TrimChar(const Chars: TPascalString): TPascalString;
    { * Removes all leading characters that belong to the given set.
      * @param Chars set of characters to trim from the beginning.
      * @return new string with leading characters removed.
    }
    function TrimLeftChar(const Chars: TPascalString): TPascalString;
    { * Removes all trailing characters that belong to the given set.
      * @param Chars set of characters to trim from the end.
      * @return new string with trailing characters removed.
    }
    function TrimRightChar(const Chars: TPascalString): TPascalString;

    { * Removes all characters that belong to a set (either explicit or category).
      * @param Chars characters to delete (as TPascalString or TOrdChars).
      * @return new string with those characters removed.
    }
    function DeleteChar(const Chars: TPascalString): TPascalString; overload;
    function DeleteChar(const Chars: TOrdChars): TPascalString; overload;

    { * Replaces all characters matching a set with a new character.
      * @param Chars characters to replace (string, single char, or category set).
      * @param newChar replacement character.
      * @return new string with replacements.
    }
    function ReplaceChar(const Chars: TPascalString; const newChar: SystemChar): TPascalString; overload;
    function ReplaceChar(const Chars, newChar: SystemChar): TPascalString; overload;
    function ReplaceChar(const Chars: TOrdChars; const newChar: SystemChar): TPascalString; overload;

    // ----- C‑string pointer handling (ANSI) --------------------------------

    { * Allocates a null‑terminated ANSI (Windows codepage) buffer.
      * The caller is responsible for freeing it with FreeAnsiChar.
      * @return pointer to the allocated buffer.
    }
    function BuildAnsiChar(var siz: Integer): Pointer; overload;
    function BuildAnsiChar: Pointer; overload;

    { * Fills the string from a null‑terminated ANSI buffer.
      * @param p pointer to the buffer.
    }
    procedure ReadAnsiChar(p: Pointer; MaxSiz: NativeInt); overload;
    procedure ReadAnsiChar(p: Pointer); overload;

    { * Class method that creates a TPascalString from an ANSI buffer.
      * @param p pointer to the buffer.
      * @return TPascalString instance.
    }
    class function ReadAnsiCharTo(p: Pointer; MaxSiz: NativeInt): TPascalString; overload; static;
    class function ReadAnsiCharTo(p: Pointer): TPascalString; overload; static;

    { * Allocates a zero‑filled ANSI buffer of the given size.
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

    { * Class method that creates a TPascalString from a WideChar buffer.
      * @param p pointer to the buffer.
      * @return TPascalString instance.
    }
    class function ReadWideCharTo(p: Pointer; MaxSiz: NativeInt): TPascalString; overload; static;
    class function ReadWideCharTo(p: Pointer): TPascalString; overload; static;

    { * Allocates a zero‑filled WideChar buffer of the given size (in characters).
      * @param size_ number of characters.
      * @return pointer to allocated memory.
    }
    class function AllocWideChar(size_: NativeInt): Pointer; static;
    class procedure FreeWideChar(p: Pointer); static; // Frees memory allocated by AllocWideChar.

    function BuildUTF8AnsiChar(var siz: Integer): Pointer; overload; // Allocates a null-terminated UTF‑8 buffer; returns pointer and sets siz to allocated size (caller must free unless autofree used).
    function BuildUTF8AnsiChar: Pointer; overload; // Allocates a null-terminated UTF‑8 buffer; returns pointer (caller must free unless autofree used).
    procedure ReadUTF8AnsiChar(p: Pointer; MaxSiz: NativeInt); overload; // Reads a null-terminated UTF‑8 buffer up to MaxSiz bytes into the string; stops at null terminator or MaxSiz.
    procedure ReadUTF8AnsiChar(p: Pointer); overload; // Reads a null-terminated UTF‑8 buffer into the string; stops at null terminator.
    class function ReadUTF8AnsiCharTo(p: Pointer; MaxSiz: NativeInt): TPascalString; overload; static; // Creates a TPascalString from a null-terminated UTF‑8 buffer up to MaxSiz bytes.
    class function ReadUTF8AnsiCharTo(p: Pointer): TPascalString; overload; static; // Creates a TPascalString from a null-terminated UTF‑8 buffer.
    class function AllocUTF8AnsiChar(size_: NativeInt): Pointer; static; // Allocates a zero-filled memory block of size_ bytes for a UTF‑8 buffer.
    class procedure FreeUTF8AnsiChar(p: Pointer); static; // Frees memory allocated by AllocUTF8AnsiChar or BuildUTF8AnsiChar (when manually managed).

    // ----- Random string generation ---------------------------------------

    { * Generates a random string of a given length using a custom random generator.
      * @param rnd a TRandom instance (e.g., TMT19937Random).
      * @param L_ desired length.
      * @param Chars_ optional set of allowed character categories; if omitted,
      *               uses printable ASCII (0x20‑0x7E).
      * @return new TPascalString filled with random characters.
      * @Example:
      *   var rnd := TMT19937Random.Create;
      *   s := TPascalString.RandomString(rnd, 10, [cAtoZ, c0to9]); // alphanumeric
    }
    class function RandomString(rnd: TRandom; L_: Integer): TPascalString; overload; static;
    class function RandomString(L_: Integer): TPascalString; overload; static;
    class function RandomString(rnd: TRandom; L_: Integer; Chars_: TOrdChars): TPascalString; overload; static;
    class function RandomString(L_: Integer; Chars_: TOrdChars): TPascalString; overload; static;

    // ----- Smith‑Waterman similarity --------------------------------------

    { * Computes the similarity score (0..1) between this string and another.
      * Uses the Smith‑Waterman algorithm with match=1, mismatch=-1, gap=-1.
      * @param p / s the other string to compare.
      * @return similarity ratio (matches / alignment length), or -1 if error
      *         (e.g., matrix too large or empty input).
      * @Example:
      *   var a := 'kitten'; b := 'sitting';
      *   score := a.SmithWaterman(b); // returns approx 0.33 (3 matches / 9)
    }
    function SmithWaterman(const p: PPascalString): Double; overload;
    function SmithWaterman(const s: TPascalString): Double; overload;

    // ----- Length and character access ------------------------------------

    property Len: Integer read GetLen write SetLen; // Character count.
    property L: Integer read GetLen write SetLen; // Alias for Len.
    property Chars[index: Integer]: SystemChar read GetChars write SetChars; default; // 1‑based access.
    property UpperChar[index: Integer]: SystemChar read GetUpperChar write SetUpperChar; // 1‑based, uppercase.
    property LowerChar[index: Integer]: SystemChar read GetLowerChar write SetLowerChar; // 1‑based, lowercase.

    // ----- Encoding properties --------------------------------------------

    property Bytes: TBytes read GetUTF8 write SetUTF8; // UTF‑8 encoded bytes.
    property UTF8: TBytes read GetUTF8 write SetUTF8; // Alias for Bytes.
    property PlatformBytes: TBytes read GetPlatformBytes write SetPlatformBytes; // System‑default encoding.
    property ANSI: TBytes read GetANSI write SetANSI; // Windows ANSI encoding.

    // ----- BOM‑prefixed UTF‑8 bytes --------------------------------------

    { * Returns UTF‑8 bytes with a BOM (byte order mark) on Delphi,
      * or plain UTF‑8 on FPC (where BOM is not required).
      * @return TBytes containing the UTF‑8 representation.
    }
    function BOMBytes: TBytes;
  end;

  { Type aliases for dynamic arrays of TPascalString and pointers. }
  TArrayPascalString = array of TPascalString;
  PArrayPascalString = ^TArrayPascalString;
  TArrayPascalStringPtr = array of PPascalString;
  PArrayPascalStringPtr = ^TArrayPascalStringPtr;

  { Short aliases for convenience. }
  TP_String = TPascalString;
  PP_String = PPascalString;
  TPS = TPascalString;

  { Atomic variant types for multi‑threaded access. }
  TAtomSystemString = {$IFDEF FPC}specialize {$ENDIF FPC}TAtomVar<SystemString>;
  TAtomPascalString = {$IFDEF FPC}specialize {$ENDIF FPC}TAtomVar<TPascalString>;

  // ----- Global helper functions for character testing ---------------------

  { * Overloaded CharIn function – tests if a character belongs to a set.
    * Supports explicit arrays, single characters, TPascalString, pointer,
    * TOrdChar category, or combinations thereof.
    * @Example:
    *   if CharIn('x', ['a'..'z']) then ... // true
  }
function CharIn(c: SystemChar; const SomeChars: array of SystemChar): Boolean; overload;
function CharIn(c: SystemChar; const SomeChar: SystemChar): Boolean; overload;
function CharIn(c: SystemChar; const s: TPascalString): Boolean; overload;
function CharIn(c: SystemChar; const p: PPascalString): Boolean; overload;
function CharIn(c: SystemChar; const SomeCharsets: TOrdChars): Boolean; overload;
function CharIn(c: SystemChar; const SomeCharset: TOrdChar): Boolean; overload;
function CharIn(c: SystemChar; const SomeCharsets: TOrdChars; const SomeChars: TPascalString): Boolean; overload;
function CharIn(c: SystemChar; const SomeCharsets: TOrdChars; const p: PPascalString): Boolean; overload;

{ * Checks whether every character in the string belongs to a given set.
  * @param t the string to examine.
  * @param SomeCharsets set of character categories.
  * @param SomeChars additional characters (optional).
  * @return True if all characters satisfy the condition.
  * @Example:
  *   if TextIs(s, [c0to9, cAtoZ]) then ... // s is alphanumeric
}
function TextIs(t: TPascalString; const SomeCharsets: TOrdChars): Boolean; overload;
function TextIs(t: TPascalString; const SomeCharsets: TOrdChars; const SomeChars: TPascalString): Boolean; overload;

// ----- Fast hash functions (case‑insensitive for ASCII letters) ------------

function FastHashSystemString(const s: SystemString): THash;
function FastHash64SystemString(const s: SystemString): THash64;
function FastHashPPascalString(const s: PPascalString): THash;
function FastHash64PPascalString(const s: PPascalString): THash64;

// ----- Safe formatting wrapper ---------------------------------------------

function PFormat(const Fmt: SystemString; const Args: array of const): SystemString;

{$IFDEF FPC}
// ----- FPC operator overloads (similar to Delphi) -------------------------
operator := (const s: Variant)r: TPascalString;
operator := (const s: AnsiString)r: TPascalString;
operator := (const s: RawByteString)r: TPascalString;
operator := (const s: UnicodeString)r: TPascalString;
operator := (const s: WideString)r: TPascalString;
operator := (const s: ShortString)r: TPascalString;
operator := (const c: SystemChar)r: TPascalString;

operator := (const s: TPascalString)r: AnsiString;
operator := (const s: TPascalString)r: RawByteString;
operator := (const s: TPascalString)r: UnicodeString;
operator := (const s: TPascalString)r: WideString;
operator := (const s: TPascalString)r: ShortString;
operator := (const s: TPascalString)r: Variant;

operator = (const a: TPascalString; const b: TPascalString): Boolean;
operator <> (const a: TPascalString; const b: TPascalString): Boolean;
operator > (const a: TPascalString; const b: TPascalString): Boolean;
operator >= (const a: TPascalString; const b: TPascalString): Boolean;
operator < (const a: TPascalString; const b: TPascalString): Boolean;
operator <= (const a: TPascalString; const b: TPascalString): Boolean;

operator + (const a: TPascalString; const b: TPascalString): TPascalString;
operator + (const a: TPascalString; const b: SystemString): TPascalString;
operator + (const a: SystemString; const b: TPascalString): TPascalString;
operator + (const a: TPascalString; const b: SystemChar): TPascalString;
operator + (const a: SystemChar; const b: TPascalString): TPascalString;
{$ENDIF}

// ----- Smith‑Waterman alignment with diff output --------------------------

{ * Computes similarity and produces two strings showing the alignment differences.
  * The diff strings indicate inserted/deleted characters with a designated diffChar.
  * @param seq1, seq2 strings to compare (as PPascalString or TPascalString).
  * @param diff1, diff2 output alignment strings.
  * @param NoDiffChar if True, identical positions are replaced by diffChar;
  *                   otherwise original characters are kept.
  * @param diffChar character used to indicate gaps/differences.
  * @return similarity ratio, or -1 if error.
  * @Example:
  *   var d1,d2: TPascalString;
  *   score := SmithWatermanCompare('kitten','sitting', d1, d2, False, '-');
  *   // d1 and d2 will show alignment with '-' for gaps.
}
function SmithWatermanCompare(const seq1, seq2: PPascalString; var diff1, diff2: TPascalString;
  const NoDiffChar: Boolean; const diffChar: SystemChar): Double; overload;
function SmithWatermanCompare(const seq1, seq2: PPascalString; var diff1, diff2: TPascalString): Double; overload;
function SmithWatermanCompare(const seq1, seq2: TPascalString; var diff1, diff2: TPascalString;
  const NoDiffChar: Boolean; const diffChar: SystemChar): Double; overload;
function SmithWatermanCompare(const seq1, seq2: TPascalString; var diff1, diff2: TPascalString): Double; overload;

// ----- Smith‑Waterman similarity only (no diff output) -------------------

function SmithWatermanCompare(const seq1, seq2: PPascalString; out Same, Diff: Integer): Double; overload;
function SmithWatermanCompare(const seq1, seq2: PPascalString): Double; overload;
function SmithWatermanCompare(const seq1, seq2: TPascalString): Double; overload;
function SmithWatermanCompare(const seq1: TArrayPascalString; const seq2: TPascalString): Double; overload;

// ----- Smith‑Waterman for raw memory buffers (byte‑wise) -----------------

{ * Compares two memory blocks as byte sequences using Smith‑Waterman.
  * @param seq1, seq2 pointers to the memory blocks.
  * @param siz1, siz2 sizes in bytes.
  * @param Same, Diff output counts of matches and mismatches.
  * @return similarity ratio (Same / (Same+Diff)).
}
function SmithWatermanCompare(const seq1: Pointer; siz1: Integer; const seq2: Pointer; siz2: Integer;
  out Same, Diff: Integer): Double; overload;
function SmithWatermanCompare(const seq1: Pointer; siz1: Integer; const seq2: Pointer; siz2: Integer): Double; overload;

// ----- Smith‑Waterman for long multi‑line texts (line‑wise) --------------

{ * Splits texts into lines, compares line‑wise, and uses a threshold to decide
  * if lines match. Useful for comparing structured documents.
  * @param t1, t2 full texts.
  * @param MinDiffCharWithPeerLine maximum allowed differences within a line
  *        to consider it a match.
  * @param Same, Diff total matches and differences.
  * @return overall similarity ratio.
}
function SmithWatermanCompareLongString(const t1, t2: TPascalString; const MinDiffCharWithPeerLine: Integer; out Same, Diff: Integer): Double; overload;
function SmithWatermanCompareLongString(const t1, t2: TPascalString): Double; overload;

const
  SystemCharSize = SizeOf(SystemChar); // Size of SystemChar in bytes.

var
{$IFDEF CPU64}
  MaxSmithWatermanMatrix: NativeInt = 10000 * 10; // Maximum matrix dimension (64‑bit).
{$ELSE CPU64}
  MaxSmithWatermanMatrix: NativeInt = 8192; // Maximum matrix dimension (32‑bit).
{$ENDIF CPU64}


const
{$IFDEF FirstCharInZero}
  FirstCharPos = 0; // Native string index base: 0 for FPC, 1 for Delphi.
{$ELSE FirstCharInZero}
  FirstCharPos = 1;
{$ENDIF FirstCharInZero}

implementation

uses SysUtils, Variants;

{ *****************************************************************************
  * Internal helper routines for efficient concatenation of character arrays
  * and native strings. These functions are used by operator overloads and
  * Append methods. They minimise temporary allocations by directly copying
  * memory blocks using CopyPtr.
  ***************************************************************************** }

{ * Concatenate two dynamic arrays of SystemChar into output. }
procedure CombineCharsPP(const c1, c2: TArrayChar; var output: TArrayChar);
var
  LL, rl: Integer;
begin
  LL := length(c1);
  rl := length(c2);
  SetLength(output, LL + rl);
  if LL > 0 then
      CopyPtr(@c1[0], @output[0], LL * SystemCharSize);
  if rl > 0 then
      CopyPtr(@c2[0], @output[LL], rl * SystemCharSize);
end;

{ * Concatenate a native SystemString (left) with an array (right). }
procedure CombineCharsSP(const c1: SystemString; const c2: TArrayChar; var output: TArrayChar);
var
  LL, rl: Integer;
begin
  LL := length(c1);
  rl := length(c2);
  SetLength(output, LL + rl);
  if LL > 0 then
      CopyPtr(@c1[FirstCharPos], @output[0], LL * SystemCharSize);
  if rl > 0 then
      CopyPtr(@c2[0], @output[LL], rl * SystemCharSize);
end;

{ * Concatenate an array (left) with a native SystemString (right). }
procedure CombineCharsPS(const c1: TArrayChar; const c2: SystemString; var output: TArrayChar);
var
  LL, rl: Integer;
begin
  LL := length(c1);
  rl := length(c2);
  SetLength(output, LL + rl);
  if LL > 0 then
      CopyPtr(@c1[0], @output[0], LL * SystemCharSize);
  if rl > 0 then
      CopyPtr(@c2[FirstCharPos], @output[LL], rl * SystemCharSize);
end;

{ * Concatenate a single character (left) with an array. }
procedure CombineCharsCP(const c1: SystemChar; const c2: TArrayChar; var output: TArrayChar);
var
  rl: Integer;
begin
  rl := length(c2);
  SetLength(output, rl + 1);
  output[0] := c1;
  if rl > 0 then
      CopyPtr(@c2[0], @output[1], rl * SystemCharSize);
end;

{ * Concatenate an array (left) with a single character. }
procedure CombineCharsPC(const c1: TArrayChar; const c2: SystemChar; var output: TArrayChar);
var
  LL: Integer;
begin
  LL := length(c1);
  SetLength(output, LL + 1);
  if LL > 0 then
      CopyPtr(@c1[0], @output[0], LL * SystemCharSize);
  output[LL] := c2;
end;

{ *************** Global CharIn functions (overloaded) *********************** }

function CharIn(c: SystemChar; const SomeChars: array of SystemChar): Boolean;
// Test if c is in the given array.
var
  AChar: SystemChar;
begin
  Result := True;
  for AChar in SomeChars do
    if AChar = c then
        Exit;
  Result := False;
end;

function CharIn(c: SystemChar; const SomeChar: SystemChar): Boolean;
// Test if c equals a single character.
begin
  Result := c = SomeChar;
end;

function CharIn(c: SystemChar; const s: TPascalString): Boolean;
// Test if c is present in the TPascalString.
begin
  Result := s.Exists(c);
end;

function CharIn(c: SystemChar; const p: PPascalString): Boolean;
// Test if c is present in the string pointed by p.
begin
  Result := p^.Exists(c);
end;

function CharIn(c: SystemChar; const SomeCharset: TOrdChar): Boolean;
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
    c0to9: Result := (v >= ord0) and (v <= ord9);
    c1to9: Result := (v >= ord1) and (v <= ord9);
    c0to32: Result := ((v >= 0) and (v <= 32));
    c0to32no10: Result := ((v >= 0) and (v <= 32) and (v <> 10));
    cLoAtoF: Result := (v >= ordLA) and (v <= ordLF);
    cHiAtoF: Result := (v >= ordHA) and (v <= ordHF);
    cLoAtoZ: Result := (v >= ordLA) and (v <= ordLZ);
    cHiAtoZ: Result := (v >= ordHA) and (v <= ordHZ);
    cHex: Result := ((v >= ordLA) and (v <= ordLF)) or ((v >= ordHA) and (v <= ordHF)) or ((v >= ord0) and (v <= ord9));
    cAtoF: Result := ((v >= ordLA) and (v <= ordLF)) or ((v >= ordHA) and (v <= ordHF));
    cAtoZ: Result := ((v >= ordLA) and (v <= ordLZ)) or ((v >= ordHA) and (v <= ordHZ));
    cVisibled: Result := ((v >= $20) and (v <= $7E)) or (v > $FF);
    cDoubleChar: Result := v > $FF;
    else Result := False;
  end;
end;

function CharIn(c: SystemChar; const SomeCharsets: TOrdChars): Boolean;
// Test if c belongs to any of the categories in the set.
var
  i: TOrdChar;
begin
  Result := True;
  for i in SomeCharsets do
    if CharIn(c, i) then
        Exit;
  Result := False;
end;

function CharIn(c: SystemChar; const SomeCharsets: TOrdChars; const SomeChars: TPascalString): Boolean;
// Test if c belongs to a category or is in the explicit string.
begin
  if CharIn(c, SomeCharsets) then
      Result := True
  else
      Result := CharIn(c, SomeChars);
end;

function CharIn(c: SystemChar; const SomeCharsets: TOrdChars; const p: PPascalString): Boolean;
// Same but with pointer.
begin
  if CharIn(c, SomeCharsets) then
      Result := True
  else
      Result := CharIn(c, p);
end;

function TextIs(t: TPascalString; const SomeCharsets: TOrdChars): Boolean;
// Verify every character of t belongs to some category.
var
  c: SystemChar;
begin
  Result := False;
  for c in t.buff do
    if not CharIn(c, SomeCharsets) then
        Exit;
  Result := True;
end;

function TextIs(t: TPascalString; const SomeCharsets: TOrdChars; const SomeChars: TPascalString): Boolean;
// Verify every character of t belongs to a category or is in SomeChars.
var
  c: SystemChar;
begin
  Result := False;
  for c in t.buff do
    if not CharIn(c, SomeCharsets, SomeChars) then
        Exit;
  Result := True;
end;

{ *************** Fast hash functions (case‑insensitive) ********************* }

function FastHashSystemString(const s: SystemString): THash;
// Compute 32‑bit hash of a SystemString (ASCII letters folded to lower case).
var
  i: Integer;
  c: SystemChar;
begin
  FillPtr(@Result, SizeOf(THash), length(s) mod 2);
{$IFDEF FirstCharInZero}
  for i := 0 to length(s) - 1 do
{$ELSE FirstCharInZero}
  for i := 1 to length(s) do
{$ENDIF FirstCharInZero}
    begin
      c := s[i];
      if CharIn(c, cHiAtoZ) then
          inc(c, 32);
      Result := ((Result shl 7) or (Result shr 25)) + THash(c);
    end;
end;

function FastHash64SystemString(const s: SystemString): THash64;
// Compute 64‑bit hash of a SystemString (ASCII letters folded to lower case).
var
  i: Integer;
  c: SystemChar;
begin
  FillPtr(@Result, SizeOf(THash64), length(s) mod 2);
{$IFDEF FirstCharInZero}
  for i := 0 to length(s) - 1 do
{$ELSE FirstCharInZero}
  for i := 1 to length(s) do
{$ENDIF FirstCharInZero}
    begin
      c := s[i];
      if CharIn(c, cHiAtoZ) then
          inc(c, 32);
      Result := ((Result shl 7) or (Result shr 57)) + THash64(c);
    end;
end;

function FastHashPPascalString(const s: PPascalString): THash;
// 32‑bit hash of a TPascalString pointed by s.
var
  i: Integer;
  c: SystemChar;
begin
  FillPtr(@Result, SizeOf(THash), s^.L mod 2);
  for i := 1 to s^.L do
    begin
      c := s^[i];
      if CharIn(c, cHiAtoZ) then
          inc(c, 32);
      Result := ((Result shl 7) or (Result shr 25)) + THash(c);
    end;
end;

function FastHash64PPascalString(const s: PPascalString): THash64;
// 64‑bit hash of a TPascalString pointed by s.
var
  i: Integer;
  c: SystemChar;
begin
  FillPtr(@Result, SizeOf(THash64), s^.L mod 2);
  for i := 1 to s^.L do
    begin
      c := s^[i];
      if CharIn(c, cHiAtoZ) then
          inc(c, 32);
      Result := ((Result shl 7) or (Result shr 57)) + THash64(c);
    end;
end;

function PFormat(const Fmt: SystemString; const Args: array of const): SystemString;
// Safe wrapper for SysUtils.Format; returns Fmt on any exception.
begin
  try
      Result := Format(Fmt, Args);
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
  SmithWaterman_MatchOk = 1; // Score for a matching character pair.
  mismatch_penalty = -1; // Penalty for a mismatch.
  gap_penalty = -1; // Penalty for inserting a gap.

  { *************** Smith‑Waterman with diff output **************************** }

function SmithWatermanCompare(const seq1, seq2: PPascalString; var diff1, diff2: TPascalString;
  const NoDiffChar: Boolean; const diffChar: SystemChar): Double;
// Align seq1 and seq2, produce diff1 and diff2 strings, return similarity.

  function InlineMatch(alphaC, betaC: SystemChar; const diffC: SystemChar): Integer;
  // Score for matching two characters: match=1, mismatch=-1, gap=-1 if either is diffChar.
  begin
    if CharIn(alphaC, cLoAtoZ) then
        dec(alphaC, 32);
    if CharIn(betaC, cLoAtoZ) then
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
  align1, align2: TPascalString;
begin
  L1 := seq1^.Len;
  l2 := seq2^.Len;
  // Check for zero length or exceeding maximum matrix size.
  if (L1 = 0) or (l2 = 0) or (L1 > MaxSmithWatermanMatrix) or (l2 > MaxSmithWatermanMatrix) then
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

function SmithWatermanCompare(const seq1, seq2: PPascalString; var diff1, diff2: TPascalString): Double;
// Wrapper with default NoDiffChar=False, diffChar='-'.
begin
  Result := SmithWatermanCompare(seq1, seq2, diff1, diff2, False, '-');
end;

function SmithWatermanCompare(const seq1, seq2: TPascalString; var diff1, diff2: TPascalString;
  const NoDiffChar: Boolean; const diffChar: SystemChar): Double;
// Wrapper for TPascalString parameters.
begin
  Result := SmithWatermanCompare(@seq1, @seq2, diff1, diff2, NoDiffChar, diffChar);
end;

function SmithWatermanCompare(const seq1, seq2: TPascalString; var diff1, diff2: TPascalString): Double;
begin
  Result := SmithWatermanCompare(seq1, seq2, diff1, diff2, False, '-');
end;

{ *************** Smith‑Waterman similarity only (out Same, Diff) *********** }

function SmithWatermanCompare(const seq1, seq2: PPascalString; out Same, Diff: Integer): Double;
// Return similarity ratio and counts of matches (Same) and mismatches (Diff).

  function InlineMatch(alphaC, betaC: SystemChar): NativeInt;
  begin
    if CharIn(alphaC, cLoAtoZ) then
        dec(alphaC, 32);
    if CharIn(betaC, cLoAtoZ) then
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
  if (L1 = 0) or (l2 = 0) or (L1 > MaxSmithWatermanMatrix) or (l2 > MaxSmithWatermanMatrix) then
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

function SmithWatermanCompare(const seq1, seq2: PPascalString): Double;
// Wrapper returning only similarity ratio.
var Same, Diff: Integer;
begin
  Result := SmithWatermanCompare(seq1, seq2, Same, Diff);
end;

function SmithWatermanCompare(const seq1, seq2: TPascalString): Double;
begin
  Result := SmithWatermanCompare(@seq1, @seq2);
end;

function SmithWatermanCompare(const seq1: TArrayPascalString; const seq2: TPascalString): Double;
// Compare an array of strings against a single one, return the best similarity.
var i: Integer; r: Double;
begin
  Result := -1;
  for i := 0 to length(seq1) - 1 do
    begin
      r := SmithWatermanCompare(seq1[i], seq2);
      if r > Result then
          Result := r;
    end;
end;

{ *************** Smith‑Waterman for raw memory (byte arrays) *************** }

function SmithWatermanCompare(const seq1: Pointer; siz1: Integer; const seq2: Pointer; siz2: Integer;
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
  if (L1 = 0) or (l2 = 0) or (L1 > MaxSmithWatermanMatrix) or (l2 > MaxSmithWatermanMatrix) then
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

function SmithWatermanCompare(const seq1: Pointer; siz1: Integer; const seq2: Pointer; siz2: Integer): Double;
// Wrapper for raw memory compare (similarity only).
var Same, Diff: Integer;
begin
  Result := SmithWatermanCompare(seq1, siz1, seq2, siz2, Same, Diff);
end;

{ *************** Smith‑Waterman for long texts (line‑wise) ***************** }

function SmithWatermanCompareLongString(const t1, t2: TPascalString; const MinDiffCharWithPeerLine: Integer; out Same, Diff: Integer): Double;
// Split texts into lines, compare line by line with a tolerance threshold.

type
  PSRec = ^TSRec;

  TSRec = record
    s: TPascalString;
  end;

  procedure _FillText(psPtr: PPascalString; outLst: TCore_List);
  // Extract non‑empty lines (ignoring spaces/tabs) and store as TSRec.
  var
    L_, i: Integer;
    n: TPascalString;
    p: PSRec;
  begin
    L_ := psPtr^.Len;
    i := 1;
    n := '';
    while i <= L_ do
      begin
        if CharIn(psPtr^[i], [#13, #10]) then
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
            until (i > L_) or (not CharIn(psPtr^[i], [#13, #10, #32, #9]));
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
    if SmithWatermanCompare(@alpha^.s, @beta^.s, cSame, cDiff) > 0 then
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
  if (L1 = 0) or (l2 = 0) or (L1 > MaxSmithWatermanMatrix) or (l2 > MaxSmithWatermanMatrix) then
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

function SmithWatermanCompareLongString(const t1, t2: TPascalString): Double;
// Wrapper with default MinDiffCharWithPeerLine = 5.
var Same, Diff: Integer;
begin
  Result := SmithWatermanCompareLongString(t1, t2, 5, Same, Diff);
end;

{$IFDEF FPC}

// ----- FPC operator overload implementations --------------------------------

operator := (const s: Variant)r: TPascalString;
begin
  r.Text := s;
end;

operator := (const s: AnsiString)r: TPascalString;
begin
  r.Text := s;
end;

operator := (const s: RawByteString)r: TPascalString;
begin
  r.Text := s;
end;

operator := (const s: UnicodeString)r: TPascalString;
begin
  r.Text := s;
end;

operator := (const s: WideString)r: TPascalString;
begin
  r.Text := s;
end;

operator := (const s: ShortString)r: TPascalString;
begin
  r.Text := s;
end;

operator := (const c: SystemChar)r: TPascalString;
begin
  r.Text := c;
end;

operator := (const s: TPascalString)r: AnsiString;
begin
  r := s.Text;
end;

operator := (const s: TPascalString)r: RawByteString;
begin
  r := s.Text;
end;

operator := (const s: TPascalString)r: UnicodeString;
begin
  r := s.Text;
end;

operator := (const s: TPascalString)r: WideString;
begin
  r := s.Text;
end;

operator := (const s: TPascalString)r: ShortString;
begin
  r := s.Text;
end;

operator := (const s: TPascalString)r: Variant;
begin
  r := s.Text;
end;

operator = (const a: TPascalString; const b: TPascalString): Boolean;
begin
  Result := a.Text = b.Text;
end;

operator <> (const a: TPascalString; const b: TPascalString): Boolean;
begin
  Result := a.Text <> b.Text;
end;

operator > (const a: TPascalString; const b: TPascalString): Boolean;
begin
  Result := a.Text > b.Text;
end;

operator >= (const a: TPascalString; const b: TPascalString): Boolean;
begin
  Result := a.Text >= b.Text;
end;

operator < (const a: TPascalString; const b: TPascalString): Boolean;
begin
  Result := a.Text < b.Text;
end;

operator <= (const a: TPascalString; const b: TPascalString): Boolean;
begin
  Result := a.Text <= b.Text;
end;

operator + (const a: TPascalString; const b: TPascalString): TPascalString;
begin
  CombineCharsPP(a.buff, b.buff, Result.buff);
end;

operator + (const a: TPascalString; const b: SystemString): TPascalString;
begin
  CombineCharsPS(a.buff, b, Result.buff);
end;

operator + (const a: SystemString; const b: TPascalString): TPascalString;
begin
  CombineCharsSP(a, b.buff, Result.buff);
end;

operator + (const a: TPascalString; const b: SystemChar): TPascalString;
begin
  CombineCharsPC(a.buff, b, Result.buff);
end;

operator + (const a: SystemChar; const b: TPascalString): TPascalString;
begin
  CombineCharsCP(a, b.buff, Result.buff);
end;
{$ENDIF}

{ *************** TPascalString methods implementation *********************** }

function TPascalString.GetText: SystemString;
// Convert internal buff to SystemString (copy).
begin
  SetLength(Result, length(buff));
  if length(buff) > 0 then
      CopyPtr(@buff[0], @Result[FirstCharPos], length(buff) * SystemCharSize);
end;

procedure TPascalString.SetText(const Value: SystemString);
// Set internal buff from a SystemString.
begin
  SetLength(buff, length(Value));
  if length(buff) > 0 then
      CopyPtr(@Value[FirstCharPos], @buff[0], length(buff) * SystemCharSize);
end;

function TPascalString.GetLen: Integer;
begin
  Result := length(buff);
end;

procedure TPascalString.SetLen(const Value: Integer);
begin
  SetLength(buff, Value);
end;

function TPascalString.GetChars(index: Integer): SystemChar;
// 1‑based access; returns #0 if index out of range.
begin
  if (index > length(buff)) or (index <= 0) then
      Result := #0
  else
      Result := buff[index - 1];
end;

procedure TPascalString.SetChars(index: Integer; const Value: SystemChar);
begin
  buff[index - 1] := Value;
end;

function TPascalString.GetUTF8: TBytes;
// Convert to UTF‑8 bytes.
begin
  SetLength(Result, 0);
  if length(buff) = 0 then
      Exit;
{$IFDEF FPC}
  Result := SysUtils.TEncoding.UTF8.GetBytes(Text);
{$ELSE}
  Result := SysUtils.TEncoding.UTF8.GetBytes(buff);
{$ENDIF}
end;

procedure TPascalString.SetUTF8(const Value: TBytes);
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

function TPascalString.GetPlatformBytes: TBytes;
// Convert to system default encoding bytes.
begin
  SetLength(Result, 0);
  if length(buff) = 0 then
      Exit;
{$IFDEF FPC}
  Result := SysUtils.TEncoding.Default.GetBytes(Text);
{$ELSE}
  Result := SysUtils.TEncoding.Default.GetBytes(buff);
{$ENDIF}
end;

procedure TPascalString.SetPlatformBytes(const Value: TBytes);
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

function TPascalString.GetANSI: TBytes;
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

procedure TPascalString.SetANSI(const Value: TBytes);
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

function TPascalString.GetLast: SystemChar;
begin
  if length(buff) > 0 then
      Result := buff[length(buff) - 1]
  else
      Result := #0;
end;

procedure TPascalString.SetLast(const Value: SystemChar);
begin
  buff[length(buff) - 1] := Value;
end;

function TPascalString.GetFirst: SystemChar;
begin
  if length(buff) > 0 then
      Result := buff[0]
  else
      Result := #0;
end;

procedure TPascalString.SetFirst(const Value: SystemChar);
begin
  buff[0] := Value;
end;

function TPascalString.GetUpperChar(index: Integer): SystemChar;
// Return character at index converted to uppercase (ASCII).
begin
  Result := GetChars(index);
  if CharIn(Result, cLoAtoZ) then
      Result := SystemChar(Word(Result) xor $0020);
end;

procedure TPascalString.SetUpperChar(index: Integer; const Value: SystemChar);
// Set character at index after converting to uppercase (ASCII).
begin
  if CharIn(Value, cLoAtoZ) then
      SetChars(index, SystemChar(Word(Value) xor $0020))
  else
      SetChars(index, Value);
end;

function TPascalString.GetLowerChar(index: Integer): SystemChar;
// Return character at index converted to lowercase (ASCII).
begin
  Result := GetChars(index);
  if CharIn(Result, cHiAtoZ) then
      Result := SystemChar(Word(Result) or $0020);
end;

procedure TPascalString.SetLowerChar(index: Integer; const Value: SystemChar);
// Set character at index after converting to lowercase (ASCII).
begin
  if CharIn(Value, cHiAtoZ) then
      SetChars(index, SystemChar(Word(Value) or $0020))
  else
      SetChars(index, Value);
end;

{$IFDEF DELPHI}

// ----- Delphi operator overload implementations ----------------------------

class operator TPascalString.Equal(const Lhs, Rhs: TPascalString): Boolean;
begin
  Result := (Lhs.Len = Rhs.Len) and (Lhs.Text = Rhs.Text);
end;

class operator TPascalString.NotEqual(const Lhs, Rhs: TPascalString): Boolean;
begin
  Result := not(Lhs = Rhs);
end;

class operator TPascalString.GreaterThan(const Lhs, Rhs: TPascalString): Boolean;
begin
  Result := Lhs.Text > Rhs.Text;
end;

class operator TPascalString.GreaterThanOrEqual(const Lhs, Rhs: TPascalString): Boolean;
begin
  Result := Lhs.Text >= Rhs.Text;
end;

class operator TPascalString.LessThan(const Lhs, Rhs: TPascalString): Boolean;
begin
  Result := Lhs.Text < Rhs.Text;
end;

class operator TPascalString.LessThanOrEqual(const Lhs, Rhs: TPascalString): Boolean;
begin
  Result := Lhs.Text <= Rhs.Text;
end;

class operator TPascalString.Add(const Lhs, Rhs: TPascalString): TPascalString;
begin
  CombineCharsPP(Lhs.buff, Rhs.buff, Result.buff);
end;

class operator TPascalString.Add(const Lhs: SystemString; const Rhs: TPascalString): TPascalString;
begin
  CombineCharsSP(Lhs, Rhs.buff, Result.buff);
end;

class operator TPascalString.Add(const Lhs: TPascalString; const Rhs: SystemString): TPascalString;
begin
  CombineCharsPS(Lhs.buff, Rhs, Result.buff);
end;

class operator TPascalString.Add(const Lhs: SystemChar; const Rhs: TPascalString): TPascalString;
begin
  CombineCharsCP(Lhs, Rhs.buff, Result.buff);
end;

class operator TPascalString.Add(const Lhs: TPascalString; const Rhs: SystemChar): TPascalString;
begin
  CombineCharsPC(Lhs.buff, Rhs, Result.buff);
end;

class operator TPascalString.Implicit(Value: RawByteString): TPascalString;
begin
  Result.Text := Value;
end;

class operator TPascalString.Implicit(Value: SystemString): TPascalString;
begin
  Result.Text := Value;
end;

class operator TPascalString.Implicit(Value: SystemChar): TPascalString;
begin
  Result.Len := 1; Result.buff[0] := Value;
end;

class operator TPascalString.Implicit(Value: TPascalString): SystemString;
begin
  Result := Value.Text;
end;

class operator TPascalString.Implicit(Value: TPascalString): Variant;
begin
  Result := Value.Text;
end;

class operator TPascalString.Explicit(Value: TPascalString): RawByteString;
begin
  Result := Value.Text;
end;

class operator TPascalString.Explicit(Value: TPascalString): SystemString;
begin
  Result := Value.Text;
end;

class operator TPascalString.Explicit(Value: TPascalString): Variant;
begin
  Result := Value.Text;
end;

class operator TPascalString.Explicit(Value: SystemString): TPascalString;
begin
  Result.Text := Value;
end;

class operator TPascalString.Explicit(Value: SystemChar): TPascalString;
begin
  Result.Len := 1; Result.buff[0] := Value;
end;
{$ENDIF}


procedure TPascalString.SwapInstance(var source: TPascalString);
// Exchange internal buffers.
var tmp: TArrayChar;
begin
  tmp := buff;
  buff := source.buff;
  source.buff := tmp;
end;

function TPascalString.Copy(index, Count: NativeInt): TPascalString;
// Extract substring; adjust Count if it exceeds length.
var L_: NativeInt;
begin
  L_ := length(buff);
  if (index - 1) + Count > L_ then
      Count := L_ - (index - 1);
  SetLength(Result.buff, Count);
  if Count > 0 then
      CopyPtr(@buff[index - 1], @Result.buff[0], SystemCharSize * Count);
end;

function TPascalString.Same(const p: PPascalString): Boolean;
// Case‑insensitive equality with pointer.
var i: Integer; s, d: SystemChar;
begin
  Result := (p^.Len = Len);
  if not Result then
      Exit;
  for i := 0 to Len - 1 do
    begin
      s := buff[i];
      if CharIn(s, cHiAtoZ) then
          inc(s, 32);
      d := p^.buff[i];
      if CharIn(d, cHiAtoZ) then
          inc(d, 32);
      if s <> d then
          Exit(False);
    end;
end;

function TPascalString.Same(const t: TPascalString): Boolean;
// Case‑insensitive equality with TPascalString.
var i: Integer; s, d: SystemChar;
begin
  Result := (t.Len = Len);
  if not Result then
      Exit;
  for i := 0 to Len - 1 do
    begin
      s := buff[i];
      if CharIn(s, cHiAtoZ) then
          inc(s, 32);
      d := t.buff[i];
      if CharIn(d, cHiAtoZ) then
          inc(d, 32);
      if s <> d then
          Exit(False);
    end;
end;

function TPascalString.Same(const t1, t2: TPascalString): Boolean;
// True if this string matches any of the two (case‑insensitive).
begin
  Result := Same(@t1) or Same(@t2);
end;

function TPascalString.Same(const t1, t2, t3: TPascalString): Boolean;
begin
  Result := Same(@t1) or Same(@t2) or Same(@t3);
end;

function TPascalString.Same(const t1, t2, t3, t4: TPascalString): Boolean;
begin
  Result := Same(@t1) or Same(@t2) or Same(@t3) or Same(@t4);
end;

function TPascalString.Same(const t1, t2, t3, t4, t5: TPascalString): Boolean;
begin
  Result := Same(@t1) or Same(@t2) or Same(@t3) or Same(@t4) or Same(@t5);
end;

function TPascalString.Same(const t1, t2, t3, t4, t5, t6: TPascalString): Boolean;
begin
  Result := Same(@t1) or Same(@t2) or Same(@t3) or Same(@t4) or Same(@t5) or Same(@t6);
end;

function TPascalString.Same(const t1, t2, t3, t4, t5, t6, t7: TPascalString): Boolean;
begin
  Result := Same(@t1) or Same(@t2) or Same(@t3) or Same(@t4) or Same(@t5) or Same(@t6) or Same(@t7);
end;

function TPascalString.Same(const t1, t2, t3, t4, t5, t6, t7, t8: TPascalString): Boolean;
begin
  Result := Same(@t1) or Same(@t2) or Same(@t3) or Same(@t4) or Same(@t5) or Same(@t6) or Same(@t7) or Same(@t8);
end;

function TPascalString.Same(const t1, t2, t3, t4, t5, t6, t7, t8, t9: TPascalString): Boolean;
begin
  Result := Same(@t1) or Same(@t2) or Same(@t3) or Same(@t4) or Same(@t5) or Same(@t6) or Same(@t7) or Same(@t8) or Same(@t9);
end;

function TPascalString.Same(const IgnoreCase: Boolean; const t: TPascalString): Boolean;
// Equality with optional case sensitivity.
var i: Integer; s, d: SystemChar;
begin
  Result := (t.Len = Len);
  if not Result then
      Exit;
  for i := 0 to Len - 1 do
    begin
      s := buff[i];
      if IgnoreCase and CharIn(s, cHiAtoZ) then
          inc(s, 32);
      d := t.buff[i];
      if IgnoreCase and CharIn(d, cHiAtoZ) then
          inc(d, 32);
      if s <> d then
          Exit(False);
    end;
end;

function TPascalString.ComparePos(const Offset: Integer; const p: PPascalString): Boolean;
// Compare substring at Offset with p (case‑insensitive).
begin
  Result := ComparePos(Offset, p, True);
end;

function TPascalString.ComparePos(const Offset: Integer; const t: TPascalString): Boolean;
begin
  Result := ComparePos(Offset, @t, True);
end;

function TPascalString.ComparePos(const Offset: Integer; const p: PPascalString; IgnoreCase: Boolean): Boolean;
// Implementation with IgnoreCase flag.
var i, L_: Integer; sourChar, destChar: SystemChar;
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
      if IgnoreCase and CharIn(sourChar, cLoAtoZ) then
          dec(sourChar, 32);
      if IgnoreCase and CharIn(destChar, cLoAtoZ) then
          dec(destChar, 32);
      if sourChar <> destChar then
          Exit;
      inc(i);
    end;
  Result := True;
end;

function TPascalString.ComparePos(const Offset: Integer; const t: TPascalString; IgnoreCase: Boolean): Boolean;
begin
  Result := ComparePos(Offset, @t, IgnoreCase);
end;

function TPascalString.GetPos(const s: TPascalString; const Offset: Integer = 1): Integer;
// Find first occurrence of s, starting from Offset.
var i: Integer;
begin
  Result := 0;
  if s.Len > 0 then
    for i := Offset to Len - s.Len + 1 do
      if ComparePos(i, @s) then
          Exit(i);
end;

function TPascalString.GetPos(const s: PPascalString; const Offset: Integer = 1): Integer;
var i: Integer;
begin
  Result := 0;
  if s^.Len > 0 then
    for i := Offset to Len - s^.Len + 1 do
      if ComparePos(i, s) then
          Exit(i);
end;

function TPascalString.Exists(c: SystemChar): Boolean;
// Check if a single character exists.
var i: Integer;
begin
  for i := low(buff) to high(buff) do
    if buff[i] = c then
        Exit(True);
  Result := False;
end;

function TPascalString.Exists(c: array of SystemChar): Boolean;
// Check if any character in the array exists.
var i: Integer;
begin
  for i := low(buff) to high(buff) do
    if CharIn(buff[i], c) then
        Exit(True);
  Result := False;
end;

function TPascalString.StrExists(const s: TPascalString): Boolean;
// Check if substring exists.
begin
  Result := GetPos(@s, 1) > 0;
end;

function TPascalString.GetCharCount(c: SystemChar): Integer;
// Count occurrences of character c.
var i: Integer;
begin
  Result := 0;
  for i := low(buff) to high(buff) do
    if CharIn(buff[i], c) then
        inc(Result);
end;

function TPascalString.IsVisibledASCII: Boolean;
// Check if all characters are visible (printable or >255).
var c: SystemChar;
begin
  Result := False;
  for c in buff do
    if not CharIn(c, cVisibled) then
        Exit;
  Result := True;
end;

function TPascalString.hash: THash;
begin
  Result := FastHashPPascalString(@Self);
end;

function TPascalString.Hash64: THash64;
begin
  Result := FastHash64PPascalString(@Self);
end;

procedure TPascalString.DeleteLast;
begin
  if Len > 0 then
      SetLength(buff, length(buff) - 1);
end;

procedure TPascalString.DeleteFirst;
begin
  if Len > 0 then
      buff := System.Copy(buff, 1, Len);
end;

procedure TPascalString.Delete(idx, cnt: Integer);
// Remove cnt characters starting at idx.
begin
  if (idx + cnt <= Len) then
      Text := GetString(1, idx) + GetString(idx + cnt, Len + 1)
  else
      Text := GetString(1, idx);
end;

procedure TPascalString.Clear;
begin
  SetLength(buff, 0);
end;

procedure TPascalString.Reset;
begin
  SetLength(buff, 0);
end;

procedure TPascalString.Append(t: TPascalString);
// Append another TPascalString.
var r, L_: Integer;
begin
  L_ := length(t.buff);
  if L_ > 0 then
    begin
      r := length(buff);
      SetLength(buff, r + L_);
      CopyPtr(@t.buff[0], @buff[r], L_ * SystemCharSize);
    end;
end;

procedure TPascalString.Append(c: SystemChar);
// Append a single character.
begin
  SetLength(buff, length(buff) + 1);
  buff[length(buff) - 1] := c;
end;

procedure TPascalString.Append(const Fmt: SystemString; const Args: array of const);
// Append formatted text.
begin
  Append(PFormat(Fmt, Args));
end;

function TPascalString.GetString(bPos, ePos: NativeInt): TPascalString;
// Extract substring from bPos to ePos-1.
begin
  if ePos > length(buff) then
      Result := Self.Copy(bPos, length(buff) - bPos + 1)
  else
      Result := Self.Copy(bPos, (ePos - bPos));
end;

procedure TPascalString.Insert(Text_: SystemString; idx: Integer);
// Insert SystemString at position idx.
begin
  Text := GetString(1, idx) + Text_ + GetString(idx + 1, Len);
end;

procedure TPascalString.FastAsText(var output: SystemString);
// Fast copy to output without additional allocation (output must be pre‑allocated).
begin
  SetLength(output, length(buff));
  if length(buff) > 0 then
      CopyPtr(@buff[0], @output[FirstCharPos], length(buff) * SystemCharSize);
end;

procedure TPascalString.FastGetBytes(var output: TBytes);
// Fast UTF‑8 conversion.
begin
{$IFDEF FPC}
  output := SysUtils.TEncoding.UTF8.GetBytes(Text);
{$ELSE}
  output := SysUtils.TEncoding.UTF8.GetBytes(buff);
{$ENDIF}
end;

function TPascalString.LowerText: SystemString;
begin
  Result := LowerCase(Text);
end;

function TPascalString.UpperText: SystemString;
begin
  Result := UpperCase(Text);
end;

function TPascalString.ShortText(MaxL, LL_, RL_: Integer): TPascalString;
begin
  if (L > MaxL) and (MaxL > (LL_ + RL_)) then
      Result.Text := GetString(1, LL_).Text + ' ... ' + GetString(L - RL_, L).Text
  else Result := Self;
end;

function TPascalString.Invert: TPascalString;
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

function TPascalString.TrimChar(const Chars: TPascalString): TPascalString;
// Trim leading/trailing characters that are in Chars.
var L_, bp, ep: Integer;
begin
  Result := '';
  L_ := Len;
  if L_ > 0 then
    begin
      bp := 1;
      while CharIn(GetChars(bp), @Chars) do
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
          ep := L_;
          while CharIn(GetChars(ep), @Chars) do
            begin
              dec(ep);
              if (ep < 1) then
                begin
                  Result := ''; Exit;
                end;
            end;
          Result := GetString(bp, ep + 1);
        end;
    end;
end;

function TPascalString.TrimLeftChar(const Chars: TPascalString): TPascalString;
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

function TPascalString.TrimRightChar(const Chars: TPascalString): TPascalString;
var
  L_, ep: Integer;
begin
  L_ := Len;
  if L_ = 0 then
      Exit('');

  ep := L_;
  while (ep >= 1) and CharIn(GetChars(ep), @Chars) do
      dec(ep);

  if ep < 1 then
      Result := ''
  else
      Result := GetString(1, ep + 1);
end;

function TPascalString.DeleteChar(const Chars: TPascalString): TPascalString;
// Remove all characters found in Chars.
var c: SystemChar;
begin
  Result := '';
  for c in buff do
    if not CharIn(c, @Chars) then
        Result.Append(c);
end;

function TPascalString.DeleteChar(const Chars: TOrdChars): TPascalString;
// Remove all characters matching any category in Chars.
var c: SystemChar;
begin
  Result := '';
  for c in buff do
    if not CharIn(c, Chars) then
        Result.Append(c);
end;

function TPascalString.ReplaceChar(const Chars: TPascalString; const newChar: SystemChar): TPascalString;
// Replace all characters in Chars with newChar.
var i: Integer;
begin
  Result.Len := Len;
  for i := low(buff) to high(buff) do
    if CharIn(buff[i], Chars) then
        Result.buff[i] := newChar
    else
        Result.buff[i] := buff[i];
end;

function TPascalString.ReplaceChar(const Chars, newChar: SystemChar): TPascalString;
// Replace a single character with newChar.
var i: Integer;
begin
  Result.Len := Len;
  for i := low(buff) to high(buff) do
    if CharIn(buff[i], Chars) then
        Result.buff[i] := newChar
    else
        Result.buff[i] := buff[i];
end;

function TPascalString.ReplaceChar(const Chars: TOrdChars; const newChar: SystemChar): TPascalString;
// Replace all characters matching any category in Chars with newChar.
var i: Integer;
begin
  Result.Len := Len;
  for i := low(buff) to high(buff) do
    if CharIn(buff[i], Chars) then
        Result.buff[i] := newChar
    else
        Result.buff[i] := buff[i];
end;

{$IFDEF RangeCheck}{$R-}{$ENDIF}


function TPascalString.BuildAnsiChar(var siz: Integer): Pointer;
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

function TPascalString.BuildAnsiChar: Pointer;
var
  siz: Integer;
begin
  Result := BuildAnsiChar(siz);
end;

procedure TPascalString.ReadAnsiChar(p: Pointer; MaxSiz: NativeInt);
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

procedure TPascalString.ReadAnsiChar(p: Pointer);
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

class function TPascalString.ReadAnsiCharTo(p: Pointer; MaxSiz: NativeInt): TPascalString;
begin
  Result.ReadAnsiChar(p, MaxSiz);
end;

class function TPascalString.ReadAnsiCharTo(p: Pointer): TPascalString;
begin
  Result.ReadAnsiChar(p);
end;

class function TPascalString.AllocAnsiChar(size_: NativeInt): Pointer;
begin
  Result := GetMemory(size_);
  FillPtr(Result, size_, 0);
end;

class procedure TPascalString.FreeAnsiChar(p: Pointer);
begin
  if p <> nil then
      FreeMemory(p);
end;

function TPascalString.BuildWideChar(var siz: Integer): Pointer;
// Allocate null‑terminated WideChar buffer.
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

function TPascalString.BuildWideChar: Pointer;
var
  siz: Integer;
begin
  Result := BuildWideChar(siz);
end;

procedure TPascalString.ReadWideChar(p: Pointer; MaxSiz: NativeInt);
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

procedure TPascalString.ReadWideChar(p: Pointer);
// Read null‑terminated WideChar buffer.
var n: NativeInt;
begin
  n := 0;
  while PWord(GetPtr(p, n))^ <> 0 do
    begin
      inc(n, 2);
    end;
  SetLength(buff, n shr 1);
  CopyPtr(p, @buff[0], n);
end;

class function TPascalString.ReadWideCharTo(p: Pointer; MaxSiz: NativeInt): TPascalString;
begin
  Result.ReadWideChar(p, MaxSiz);
end;

class function TPascalString.ReadWideCharTo(p: Pointer): TPascalString;
begin
  Result.ReadWideChar(p);
end;

class function TPascalString.AllocWideChar(size_: NativeInt): Pointer;
begin
  Result := GetMemory(size_ * 2);
  FillPtr(Result, size_ * 2, 0);
end;

class procedure TPascalString.FreeWideChar(p: Pointer);
begin
  if p <> nil then
      FreeMemory(p);
end;

function TPascalString.BuildUTF8AnsiChar(var siz: Integer): Pointer;
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

function TPascalString.BuildUTF8AnsiChar: Pointer;
var
  siz: Integer;
begin
  Result := BuildUTF8AnsiChar(siz);
end;

procedure TPascalString.ReadUTF8AnsiChar(p: Pointer; MaxSiz: NativeInt);
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

procedure TPascalString.ReadUTF8AnsiChar(p: Pointer);
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

class function TPascalString.ReadUTF8AnsiCharTo(p: Pointer; MaxSiz: NativeInt): TPascalString;
begin
  Result.ReadUTF8AnsiChar(p, MaxSiz);
end;

class function TPascalString.ReadUTF8AnsiCharTo(p: Pointer): TPascalString;
begin
  Result.ReadUTF8AnsiChar(p);
end;

class function TPascalString.AllocUTF8AnsiChar(size_: NativeInt): Pointer;
begin
  Result := GetMemory(size_);
  FillPtr(Result, size_, 0);
end;

class procedure TPascalString.FreeUTF8AnsiChar(p: Pointer);
begin
  if p <> nil then
      FreeMemory(p);
end;

{$IFDEF RangeCheck}{$R+}{$ENDIF}


class function TPascalString.RandomString(rnd: TRandom; L_: Integer): TPascalString;
// Generate random printable ASCII string using given random generator.
var i: Integer;
begin
  Result.L := L_;
  for i := 1 to L_ do
      Result[i] := SystemChar(rnd.Rand32($7E - $20) + $20);
end;

class function TPascalString.RandomString(L_: Integer): TPascalString;
// Generate random printable ASCII string using a new Mersenne Twister.
var i: Integer; rnd: TMT19937Random;
begin
  Result.L := L_;
  rnd := TMT19937Random.Create;
  for i := 1 to L_ do
      Result[i] := SystemChar(rnd.Rand32($7E - $20) + $20);
  DisposeObject(rnd);
end;

class function TPascalString.RandomString(rnd: TRandom; L_: Integer; Chars_: TOrdChars): TPascalString;
// Generate random string restricted to character categories.
var i: Integer; tmp: SystemChar;
begin
  Result.L := L_;
  for i := 1 to L_ do
    begin
      repeat
          tmp := SystemChar(rnd.Rand32($7E - $20) + $20);
      until CharIn(tmp, Chars_);
      Result[i] := tmp;
    end;
end;

class function TPascalString.RandomString(L_: Integer; Chars_: TOrdChars): TPascalString;
// Generate random string using a new Mersenne Twister with category restriction.
var i: Integer; rnd: TMT19937Random; tmp: SystemChar;
begin
  Result.L := L_;
  rnd := TMT19937Random.Create;
  for i := 1 to L_ do
    begin
      repeat
          tmp := SystemChar(rnd.Rand32($7E - $20) + $20);
      until CharIn(tmp, Chars_);
      Result[i] := tmp;
    end;
  DisposeObject(rnd);
end;

function TPascalString.SmithWaterman(const p: PPascalString): Double;
begin
  Result := SmithWatermanCompare(@Self, @p);
end;

function TPascalString.SmithWaterman(const s: TPascalString): Double;
begin
  Result := SmithWatermanCompare(@Self, @s);
end;

function TPascalString.BOMBytes: TBytes;
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

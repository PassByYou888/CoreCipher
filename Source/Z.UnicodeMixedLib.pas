(*
  *******************************************************************************
  * Z.UnicodeMixedLib - Multi-purpose Utility Library (Unicode Mixed Library)   *
  *                                                                             *
  * This unit is a core collection of general-purpose utilities for the         *
  * Z-framework. It provides cross-platform, cross-compiler (Delphi/FPC)        *
  * functions covering the following major areas:                               *
  *                                                                             *
  *   - File system operations: existence checks, creation, deletion, copying,  *
  *     renaming, directory traversal, path normalisation, combination,         *
  *     splitting, and retrieval of file times and sizes.                       *
  *   - Advanced file I/O: stream-based reading/writing via TIOHnd with         *
  *     read/write caching, prefetch, bulk writes, fixed-length string fields,  *
  *     and reliable file streams (with backup/restore).                        *
  *   - String handling: case conversion, splitting (continuous or              *
  *     discontinuity), replacement, deletion, trimming, substring extraction,  *
  *     word extraction, wildcard matching * and ?, multi-pattern matching,     *
  *     and batch substitution.                                                 *
  *   - Type conversion and formatting: numbers ↔ strings (integer, float,      *
  *     hex), booleans, date/time, variants, pointers, and smart formatting     *
  *     of sizes (bytes/KB/MB/GB).                                              *
  *   - Encoding and hashing: Base64 encoding/decoding, URL encoding/decoding,  *
  *     HTML entity encoding, MD5 (incremental, file/stream/string),            *
  *     and CRC16/CRC32 checksums.                                              *
  *   - Random number generation: thread-safe MT19937-based random integers,    *
  *     floats, and ranges.                                                     *
  *   - File MD5 caching: asynchronous precomputation of file MD5 hashes,       *
  *     with support for batch directory caching to avoid redundant             *
  *     recomputation.                                                          *
  *   - Network URL parsing: RTSP/RTMP URL decomposition and composition,       *
  *     including user/password separation.                                     *
  *   - Component persistence: reading/writing Delphi/FPC components            *
  *     (TComponent) to/from streams, and copying component data.               *
  *   - CSV parsing: callback-based CSV import with flexible header and         *
  *     data row handling.                                                      *
  *   - Dynamic library loading: cross-platform loading of shared libraries     *
  *     (.dll/.so/.dylib) with caching of loaded handles.                       *
  *   - Miscellaneous utilities: percentage calculation, timestamp formatting,  *
  *     binary-string ↔ integer conversion, memory ASCII detection,             *
  *     and memory buffer saving to file.                                       *
  *                                                                             *
  * Design goals:                                                               *
  *   - Provide a unified, highly portable set of low-level tools to reduce     *
  *     code duplication.                                                       *
  *   - Performance-oriented, with optimisations for I/O and string             *
  *     operations (caching, block processing).                                 *
  *   - Seamless integration with Z.Core and other foundational libraries,      *
  *     forming a complete Z-framework ecosystem.                               *
  *******************************************************************************
*)
unit Z.UnicodeMixedLib;

{$DEFINE FPC_DELPHI_MODE}
{$I Z.Define.inc}

interface

uses
  Dateutils,
{$IFDEF FPC}
  Dynlibs,
  Z.FPC.GenericList,
{$IFDEF MSWINDOWS} Windows, {$ENDIF MSWINDOWS}
{$ELSE FPC}
{$IFDEF MSWINDOWS} Windows, {$ENDIF MSWINDOWS}
  System.IOUtils,
{$ENDIF FPC}
  SysUtils, Types, Math, Variants,
  Z.Core, Z.PascalStrings, Z.UPascalStrings, Z.Int128, Z.ListEngine, Z.MemoryStream;

{
  Constant definitions for common data type sizes and error codes.
  These constants provide portable size information and standardised
  error codes for file I/O operations.
}
const
  C_Max_UInt32 = $FFFFFFFF; // Maximum 32-bit unsigned integer.
  C_Address_Size = SizeOf(Pointer); // Size of a pointer (4 or 8 bytes).
  C_Pointer_Size = C_Address_Size; // Alias for pointer size.
  C_Integer_Size = 4; // Size of Integer type.
  C_Int64_Size = 8; // Size of Int64.
  C_UInt64_Size = 8; // Size of UInt64.
  C_Int128_Size = 16; // Size of Int128.
  C_UInt128_Size = 16; // Size of UInt128.
  C_Single_Size = 4; // Size of Single.
  C_Double_Size = 8; // Size of Double.
  C_Small_Int_Size = 2; // Size of SmallInt.
  C_Byte_Size = 1; // Size of Byte.
  C_Short_Int_Size = 1; // Size of ShortInt.
  C_Word_Size = 2; // Size of Word.
  C_DWord_Size = 4; // Size of DWord.
  C_Cardinal_Size = 4; // Size of Cardinal.
  C_Boolean_Size = 1; // Size of Boolean.
  C_Bool_Size = 1; // Size of Bool.
  C_MD5_Size = 16; // Size of MD5 digest (16 bytes).

  C_PrepareReadCacheSize = 512; // Size of read-ahead cache for file I/O.
  C_Buffer_Chunk_Size = $F000; // Chunk size for buffered I/O operations (61440 bytes).

  { Error codes for TIOHnd operations. All negative to distinguish from success. }
  C_Flush_And_Seek_Error = -912; // Error during flush and seek.
  C_StringError = -911; // String conversion error.
  C_SeekError = -910; // Seek operation failed.
  C_FileWriteError = -909; // Write operation failed.
  C_FileReadError = -908; // Read operation failed.
  C_FileHandleError = -907; // Invalid file handle.
  C_OpenFileError = -905; // File open failed.
  C_NotOpenFile = -904; // File not open.
  C_CreateFileError = -903; // File creation failed.
  C_FileIsActive = -902; // File is already open.
  C_NotFindFile = -901; // File not found.
  C_NotError = -900; // No error.

type
  { Alias for SystemString to avoid naming conflicts. }
  U_SystemString = SystemString;
  { Alias for TPascalString as a unified string type. }
  U_String = TPascalString;
  { Alias for SystemChar as a unified character type. }
  U_Char = SystemChar;
  { Dynamic array of system strings. }
  U_StringArray = array of U_SystemString;
  { Alias for U_StringArray. }
  U_ArrayString = U_StringArray;
  { Alias for TBytes. }
  U_Bytes = TBytes;

  { Alias for TSearchRec used in file search operations. }
  TSR = TSearchRec;
  { Alias for TCore_Stream as a unified stream type. }
  U_Stream = TCore_Stream;

  {
    TReliableFileStream – a file stream that creates a backup copy on write
    operations to prevent data loss. When the stream is closed, the original
    file is replaced by the backup (if write operations occurred). This
    provides atomic file updates.
  }
  TReliableFileStream = class(TCore_Stream)
  protected
    FSource_IO, FBackup_IO: TCore_FileStream; // Original and backup file streams.
    FActivted: Boolean; // True if backup is active (write mode).
    FFileName, Backup_FileName: SystemString; // Original and backup filenames.

    procedure InitIO; // Initialise backup stream and copy original data.
    procedure FreeIO; // Finalise backup and replace original file.

    procedure SetSize(const NewSize: Int64); overload; override;
    procedure SetSize(NewSize: longint); overload; override;
  public
    constructor Create(const FileName_: SystemString; IsNew_, IsWrite_: Boolean);
    destructor Destroy; override;

    property FileName: SystemString read FFileName;
    property BackupFileName: SystemString read Backup_FileName;
    property Activted: Boolean read FActivted;

    function Write(const buffer; Count: longint): longint; override;
    function Read(var buffer; Count: longint): longint; override;
    function Seek(const Offset: Int64; origin: TSeekOrigin): Int64; override;
  end;

  { Pointer to a TIOHnd record. }
  PIOHnd = ^TIOHnd;

  {
    TIOHnd_Cache – internal cache management for I/O handles.
    Supports both read and write caching to reduce system calls.
  }
  TIOHnd_Cache = record
  private
    PrepareWriteBuff: U_Stream; // Buffer for buffered writes.
    PrepareReadPosition: Int64; // Current position in the read cache.
    PrepareReadBuff: U_Stream; // Buffer for buffered reads.
  public
    UsedWriteCache: Boolean; // True if write caching is enabled.
    UsedReadCache: Boolean; // True if read caching is enabled.
  end;

  {
    TIOHnd – a record representing an open file or stream handle with
    associated metadata and caching support. This is the core of the
    portable I/O subsystem.
  }
  TIOHnd = record
  public
    IsOnlyRead: Boolean; // True if the handle is read-only.
    IsOpen: Boolean; // True if the handle is open.
    AutoFree: Boolean; // True if the underlying stream should be freed on close.
    Handle: U_Stream; // Underlying stream object.
    Time: TDateTime; // Last modification time.
    Size: Int64; // Total size of the file/stream.
    Position: Int64; // Current position.
    FileName: U_String; // File name (if any).
    Cache: TIOHnd_Cache; // Caching information.
    IORead, IOWrite: Int64; // Total bytes read/written.
    ChangeFromWrite: Boolean; // True if the file has been written to.
    FixedStringL: Byte; // Fixed length for fixed-length string fields.
    Data: Pointer; // User-defined data pointer.
    Return: Integer; // Last error code (negative value).

    { Convert a fixed-length byte array (with length prefix) to a Pascal string. }
    function FixedString2Pascal(S: TBytes): TPascalString;
    { Convert a Pascal string to a fixed-length byte array (with length prefix). }
    procedure Pascal2FixedString(var n: TPascalString; var out_: TBytes);
    { Check if a Pascal string would overflow the fixed-length buffer. }
    function CheckFixedStringLoss(S: TPascalString): Boolean;
  end;

  { Type for a byte array that can be indexed beyond the declared size. }
  U_ByteArray = array [0 .. MaxInt div SizeOf(Byte) - 1] of Byte;
  P_ByteArray = ^U_ByteArray;

  { Helper class for TListPascalString to fill arrays and import from arrays. }
  TListPascalString_Helper_ = class helper for TListPascalString
  public
    procedure FillToArry(var Output_: U_StringArray);
    procedure InputArray(arry: U_StringArray);
    procedure Add_Arry(arry: U_StringArray);
  end;

  { Helper class for TStringBigList to fill arrays and import from arrays. }
  TStringBigList_Helper_ = class helper for TStringBigList
  public
    procedure FillToArry(var Output_: U_StringArray);
    procedure InputArray(arry: U_StringArray);
    procedure Add_Arry(arry: U_StringArray);
  end;

function umlBytesOf(const S: TPascalString): TBytes; { Convert a TPascalString to a TBytes (UTF-8 encoded). }
function umlStringOf(const S: TBytes): TPascalString; overload; { Convert a TBytes (UTF-8) to a TPascalString. }
function umlNewString(const S: TPascalString): PPascalString; { Allocate a new TPascalString on the heap and initialise it. }
procedure umlFreeString(const p: PPascalString); { Free a PPascalString allocated with umlNewString. }
function umlComparePosStr(const S: TPascalString; Offset: Integer; const t: TPascalString): Boolean; { Compare a substring of S (starting at Offset) with t, case-sensitive. }
function umlPos(const SubStr, S: TPascalString; const Offset: Integer = 1): Integer; { Find the position of SubStr in S, starting from Offset (1-based). Returns 0 if not found. }

function umlVarToStr(const v: Variant; const Base64Conver: Boolean): TPascalString; overload; { Convert a Variant to a TPascalString, optionally encoding non-printable characters in Base64. }
function umlVarToStr(const v: Variant): TPascalString; overload; { Convert a Variant to a TPascalString with Base64 conversion enabled by default. }
function umlStrToVar(const S: TPascalString): Variant; { Convert a TPascalString back to a Variant, decoding Base64 if present. }

function umlMax(const v1, v2: UInt64): UInt64; {$IFDEF INLINE_ASM} inline; {$ENDIF INLINE_ASM} overload; { Return the maximum of two unsigned 64-bit values. }
function umlMax(const v1, v2: Cardinal): Cardinal; {$IFDEF INLINE_ASM} inline; {$ENDIF INLINE_ASM} overload; { Return the maximum of two 32-bit Cardinals. }
function umlMax(const v1, v2: Word): Word; {$IFDEF INLINE_ASM} inline; {$ENDIF INLINE_ASM} overload; { Return the maximum of two Words. }
function umlMax(const v1, v2: Byte): Byte; {$IFDEF INLINE_ASM} inline; {$ENDIF INLINE_ASM} overload; { Return the maximum of two Bytes. }
function umlMax(const v1, v2: Int64): Int64; {$IFDEF INLINE_ASM} inline; {$ENDIF INLINE_ASM} overload; { Return the maximum of two 64-bit signed integers. }
function umlMax(const v1, v2: Integer): Integer; {$IFDEF INLINE_ASM} inline; {$ENDIF INLINE_ASM} overload; { Return the maximum of two Integers. }
function umlMax(const v1, v2: SmallInt): SmallInt; {$IFDEF INLINE_ASM} inline; {$ENDIF INLINE_ASM} overload; { Return the maximum of two SmallInts. }
function umlMax(const v1, v2: ShortInt): ShortInt; {$IFDEF INLINE_ASM} inline; {$ENDIF INLINE_ASM} overload; { Return the maximum of two ShortInts. }
function umlMax(const v1, v2: Double): Double; {$IFDEF INLINE_ASM} inline; {$ENDIF INLINE_ASM} overload; { Return the maximum of two Double values. }
function umlMax(const v1, v2: Single): Single; {$IFDEF INLINE_ASM} inline; {$ENDIF INLINE_ASM} overload; { Return the maximum of two Single values. }
function umlMax(const v1, v2: UInt128): UInt128; {$IFDEF INLINE_ASM} inline; {$ENDIF INLINE_ASM} overload; { Return the maximum of two UInt128 values. }
function umlMax(const v1, v2: Int128): Int128; {$IFDEF INLINE_ASM} inline; {$ENDIF INLINE_ASM} overload; { Return the maximum of two Int128 values. }

{ Return the minimum of two values (overloaded for all numeric types). }
function umlMin(const v1, v2: UInt64): UInt64; {$IFDEF INLINE_ASM} inline; {$ENDIF INLINE_ASM} overload;
function umlMin(const v1, v2: Cardinal): Cardinal; {$IFDEF INLINE_ASM} inline; {$ENDIF INLINE_ASM} overload;
function umlMin(const v1, v2: Word): Word; {$IFDEF INLINE_ASM} inline; {$ENDIF INLINE_ASM} overload;
function umlMin(const v1, v2: Byte): Byte; {$IFDEF INLINE_ASM} inline; {$ENDIF INLINE_ASM} overload;
function umlMin(const v1, v2: Int64): Int64; {$IFDEF INLINE_ASM} inline; {$ENDIF INLINE_ASM} overload;
function umlMin(const v1, v2: Integer): Integer; {$IFDEF INLINE_ASM} inline; {$ENDIF INLINE_ASM} overload;
function umlMin(const v1, v2: SmallInt): SmallInt; {$IFDEF INLINE_ASM} inline; {$ENDIF INLINE_ASM} overload;
function umlMin(const v1, v2: ShortInt): ShortInt; {$IFDEF INLINE_ASM} inline; {$ENDIF INLINE_ASM} overload;
function umlMin(const v1, v2: Double): Double; {$IFDEF INLINE_ASM} inline; {$ENDIF INLINE_ASM} overload;
function umlMin(const v1, v2: Single): Single; {$IFDEF INLINE_ASM} inline; {$ENDIF INLINE_ASM} overload;
function umlMin(const v1, v2: UInt128): UInt128; {$IFDEF INLINE_ASM} inline; {$ENDIF INLINE_ASM} overload;
function umlMin(const v1, v2: Int128): Int128; {$IFDEF INLINE_ASM} inline; {$ENDIF INLINE_ASM} overload;

{ Clamp a value between min and max (overloaded for numeric types). }
function umlClamp(const v, min_, max_: Integer): Integer; {$IFDEF INLINE_ASM} inline; {$ENDIF INLINE_ASM} overload;
function umlClamp(const v, min_, max_: UInt64): UInt64; {$IFDEF INLINE_ASM} inline; {$ENDIF INLINE_ASM} overload;
function umlClamp(const v, min_, max_: Cardinal): Cardinal; {$IFDEF INLINE_ASM} inline; {$ENDIF INLINE_ASM} overload;
function umlClamp(const v, min_, max_: Word): Word; {$IFDEF INLINE_ASM} inline; {$ENDIF INLINE_ASM} overload;
function umlClamp(const v, min_, max_: Byte): Byte; {$IFDEF INLINE_ASM} inline; {$ENDIF INLINE_ASM} overload;
function umlClamp(const v, min_, max_: Int64): Int64; {$IFDEF INLINE_ASM} inline; {$ENDIF INLINE_ASM} overload;
function umlClamp(const v, min_, max_: SmallInt): SmallInt; {$IFDEF INLINE_ASM} inline; {$ENDIF INLINE_ASM} overload;
function umlClamp(const v, min_, max_: ShortInt): ShortInt; {$IFDEF INLINE_ASM} inline; {$ENDIF INLINE_ASM} overload;
function umlClamp(const v, min_, max_: Double): Double; {$IFDEF INLINE_ASM} inline; {$ENDIF INLINE_ASM} overload;
function umlClamp(const v, min_, max_: Single): Single; {$IFDEF INLINE_ASM} inline; {$ENDIF INLINE_ASM} overload;
function umlClamp(const v, min_, max_: UInt128): UInt128; {$IFDEF INLINE_ASM} inline; {$ENDIF INLINE_ASM} overload;
function umlClamp(const v, min_, max_: Int128): Int128; {$IFDEF INLINE_ASM} inline; {$ENDIF INLINE_ASM} overload;

{ Check if v is within [min, max] (inclusive) for various types. }
function umlInRange(const v, min_, max_: Integer): Boolean; {$IFDEF INLINE_ASM} inline; {$ENDIF INLINE_ASM} overload; { Check if v is within [min, max] (inclusive) for various types. }
function umlInRange(const v, min_, max_: UInt64): Boolean; {$IFDEF INLINE_ASM} inline; {$ENDIF INLINE_ASM} overload;
function umlInRange(const v, min_, max_: Cardinal): Boolean; {$IFDEF INLINE_ASM} inline; {$ENDIF INLINE_ASM} overload;
function umlInRange(const v, min_, max_: Word): Boolean; {$IFDEF INLINE_ASM} inline; {$ENDIF INLINE_ASM} overload;
function umlInRange(const v, min_, max_: Byte): Boolean; {$IFDEF INLINE_ASM} inline; {$ENDIF INLINE_ASM} overload;
function umlInRange(const v, min_, max_: Int64): Boolean; {$IFDEF INLINE_ASM} inline; {$ENDIF INLINE_ASM} overload;
function umlInRange(const v, min_, max_: SmallInt): Boolean; {$IFDEF INLINE_ASM} inline; {$ENDIF INLINE_ASM} overload;
function umlInRange(const v, min_, max_: ShortInt): Boolean; {$IFDEF INLINE_ASM} inline; {$ENDIF INLINE_ASM} overload;
function umlInRange(const v, min_, max_: Double): Boolean; {$IFDEF INLINE_ASM} inline; {$ENDIF INLINE_ASM} overload;
function umlInRange(const v, min_, max_: Single): Boolean; {$IFDEF INLINE_ASM} inline; {$ENDIF INLINE_ASM} overload;
function umlInRange(const v, min_, max_: UInt128): Boolean; {$IFDEF INLINE_ASM} inline; {$ENDIF INLINE_ASM} overload;
function umlInRange(const v, min_, max_: Int128): Boolean; {$IFDEF INLINE_ASM} inline; {$ENDIF INLINE_ASM} overload;

function umlCompareText(s1, s2: TPascalString): Integer; { Perform a case-insensitive comparison of two TPascalStrings, returning -1, 0, or 1. }
function umlGetResourceStream(const FileName: TPascalString): TCore_Stream; { Obtain a resource stream from the executable's resources by name. }

function umlSameVarValue(const v1, v2: Variant): Boolean; { Compare two Variants for equality (using VarSameValue). }
function umlSameVariant(const v1, v2: Variant): Boolean; { Alias for umlSameVarValue. }

function umlRandom(const rnd: TMT19937Random): Integer; {$IFDEF INLINE_ASM} inline; {$ENDIF INLINE_ASM} overload; { Generate a random integer using a given TRandom instance (range 0..MaxInt). }
function umlRandom: Integer; {$IFDEF INLINE_ASM} inline; {$ENDIF INLINE_ASM} overload; { Generate a random integer using the global MT19937 generator (range 0..MaxInt). }
function umlRandomRange(const rnd: TMT19937Random; const min_, max_: Integer): Integer; {$IFDEF INLINE_ASM} inline; {$ENDIF INLINE_ASM} overload; { Generate a random integer in [min_, max_] using a given TRandom instance. }
function umlRandomRange64(const rnd: TMT19937Random; const min_, max_: Int64): Int64; {$IFDEF INLINE_ASM} inline; {$ENDIF INLINE_ASM} overload; { Generate a random Int64 in [min_, max_] using a given TRandom. }
function umlRandomRangeS(const rnd: TMT19937Random; const min_, max_: Single): Single; {$IFDEF INLINE_ASM} inline; {$ENDIF INLINE_ASM} overload; { Generate a random Single in [min_, max_] using a given TRandom. }
function umlRandomRangeD(const rnd: TMT19937Random; const min_, max_: Double): Double; {$IFDEF INLINE_ASM} inline; {$ENDIF INLINE_ASM} overload; { Generate a random Double in [min_, max_] using a given TRandom. }
function umlRandomRangeF(const rnd: TMT19937Random; const min_, max_: Double): Double; {$IFDEF INLINE_ASM} inline; {$ENDIF INLINE_ASM} overload; { Generate a random Double in [min_, max_] using a given TRandom (alias). }
function umlRandomRange(const min_, max_: Integer): Integer; {$IFDEF INLINE_ASM} inline; {$ENDIF INLINE_ASM} overload; { Generate a random integer in [min_, max_] using the global MT19937 generator. }
function umlRandomRange64(const min_, max_: Int64): Int64; {$IFDEF INLINE_ASM} inline; {$ENDIF INLINE_ASM} overload; { Generate a random Int64 in [min_, max_] using the global generator. }
function umlRandomRangeS(const min_, max_: Single): Single; {$IFDEF INLINE_ASM} inline; {$ENDIF INLINE_ASM} overload; { Generate a random Single in [min_, max_] using the global generator. }
function umlRandomRangeD(const min_, max_: Double): Double; {$IFDEF INLINE_ASM} inline; {$ENDIF INLINE_ASM} overload; { Generate a random Double in [min_, max_] using the global generator. }
function umlRandomRangeF(const min_, max_: Double): Double; {$IFDEF INLINE_ASM} inline; {$ENDIF INLINE_ASM} overload; { Alias for umlRandomRangeD. }
function umlRR(const rnd: TMT19937Random; const min_, max_: Integer): Integer; {$IFDEF INLINE_ASM} inline; {$ENDIF INLINE_ASM} overload; { Shorter alias for umlRandomRange (with TRandom). }
function umlRR64(const rnd: TMT19937Random; const min_, max_: Int64): Int64; {$IFDEF INLINE_ASM} inline; {$ENDIF INLINE_ASM} overload; { Shorter alias for umlRandomRange64 (with TRandom). }
function umlRRS(const rnd: TMT19937Random; const min_, max_: Single): Single; {$IFDEF INLINE_ASM} inline; {$ENDIF INLINE_ASM} overload; { Shorter alias for umlRandomRangeS (with TRandom). }
function umlRRD(const rnd: TMT19937Random; const min_, max_: Double): Double; {$IFDEF INLINE_ASM} inline; {$ENDIF INLINE_ASM} overload; { Shorter alias for umlRandomRangeD (with TRandom). }
function umlRRF(const rnd: TMT19937Random; const min_, max_: Double): Double; {$IFDEF INLINE_ASM} inline; {$ENDIF INLINE_ASM} overload; { Shorter alias for umlRandomRangeF (with TRandom). }
function umlRR(const min_, max_: Integer): Integer; {$IFDEF INLINE_ASM} inline; {$ENDIF INLINE_ASM} overload; { Shorter alias for umlRandomRange (global generator). }
function umlRR64(const min_, max_: Int64): Int64; {$IFDEF INLINE_ASM} inline; {$ENDIF INLINE_ASM} overload; { Shorter alias for umlRandomRange64 (global). }
function umlRRS(const min_, max_: Single): Single; {$IFDEF INLINE_ASM} inline; {$ENDIF INLINE_ASM} overload; { Shorter alias for umlRandomRangeS (global). }
function umlRRD(const min_, max_: Double): Double; {$IFDEF INLINE_ASM} inline; {$ENDIF INLINE_ASM} overload; { Shorter alias for umlRandomRangeD (global). }
function umlRRF(const min_, max_: Double): Double; {$IFDEF INLINE_ASM} inline; {$ENDIF INLINE_ASM} overload; { Shorter alias for umlRandomRangeF (global). }

function umlDefaultTime: Double; { Return the current date/time as a TDateTime (alias for Now). }
function umlNow: Double; { Return the current date/time. }
function umlTime: Double; { Return the current time portion (alias for Time). }
function umlDate: Double; { Return the current date portion (alias for Date). }

function umlDefaultAttrib: Integer; { Return a default file attribute (0). }

function umlBoolToStr(const Value: Boolean): TPascalString; { Convert a Boolean to a TPascalString ('True' or 'False'). }
function umlStrToBool(const Value: TPascalString; Default_: Boolean): Boolean; overload; { Convert a TPascalString to Boolean, using a default if conversion fails. }
function umlStrToBool(const Value: TPascalString): Boolean; overload; { Convert a TPascalString to Boolean, defaulting to False. }

function umlFileExists(const FileName: TPascalString): Boolean; { Check if a file exists. }
function umlDirectoryExists(const DirectoryName: TPascalString): Boolean; { Check if a directory exists. }
function umlCreateDirectory(const DirectoryName: TPascalString): Boolean; { Create a directory (including intermediate directories if needed). Returns True if successful or already exists. }
function umlCurrentDirectory: TPascalString; { Return the current working directory as a TPascalString. }
function umlCurrentPath: TPascalString; { Return the current working directory with a trailing path separator. }
function umlGetCurrentPath: TPascalString; { Alias for umlCurrentPath. }
procedure umlSetCurrentPath(ph: TPascalString); { Set the current working directory. }

function umlFindFirstFile(const FileName: TPascalString; var SR: TSR): Boolean; { Find the first file matching a pattern (SR is a TSearchRec). Returns True if found. }
function umlFindNextFile(var SR: TSR): Boolean; { Find the next file in a search initiated by umlFindFirstFile. }
function umlFindFirstDir(const DirName: TPascalString; var SR: TSR): Boolean; { Find the first directory matching a pattern. }
function umlFindNextDir(var SR: TSR): Boolean; { Find the next directory in a search. }
procedure umlFindClose(var SR: TSR); { Close a search handle (SR). }

function uml_Get_File_To_List(const FullPath: TPascalString; AsLst: TCore_Strings): Integer; overload; { Add all files in a directory to a TCore_Strings list. Returns count. }
function uml_Get_Dir_To_List(const FullPath: TPascalString; AsLst: TCore_Strings): Integer; overload; { Add all subdirectories to a TCore_Strings list. Returns count. }
function uml_Get_File_To_List(const FullPath: TPascalString; AsLst: TPascalStringList): Integer; overload; { Add all files in a directory to a TPascalStringList. Returns count. }
function uml_Get_Dir_To_List(const FullPath: TPascalString; AsLst: TPascalStringList): Integer; overload; { Add all subdirectories to a TPascalStringList. Returns count. }
function umlGet_File_Full_Array(const FullPath: TPascalString): U_StringArray; { Return an array of full paths of all files in a directory (excluding subdirectories). }
function umlGet_Path_Full_Array(const FullPath: TPascalString): U_StringArray; { Return an array of full paths of all subdirectories. }
function umlGet_File_Array(const FullPath: TPascalString): U_StringArray; { Return an array of file names (without path) in a directory. }
function umlGet_Path_Array(const FullPath: TPascalString): U_StringArray; { Return an array of directory names (without path) in a directory. }

function umlFixedPath(S: TPascalString): TPascalString; { Normalise a path to the current platform's preferred separator and ensure trailing separator. }
function umlCombinePath(const s1, s2: TPascalString): TPascalString; { Combine two path components using the platform's path separator. }
function umlCombineFileName(const pathName, FileName: TPascalString): TPascalString; { Combine a path and a file name using the platform's separator. }
function umlCombineUnixPath(const s1, s2: TPascalString): TPascalString; { Combine two path components using Unix '/' separator. }
function umlCombineUnixFileName(const pathName, FileName: TPascalString): TPascalString; { Combine a Unix path and file name. }
function umlCombineWinPath(const s1, s2: TPascalString): TPascalString; { Combine two path components using Windows '\' separator. }
function umlCombineWinFileName(const pathName, FileName: TPascalString): TPascalString; { Combine a Windows path and file name. }
function umlGetFileName(platform_: TExecutePlatform; const S: TPascalString): TPascalString; overload; { Extract the file name from a path, given a specific platform. }
function umlGetFileName(const S: TPascalString): TPascalString; overload; { Extract the file name from a path using the current platform. }
function umlGetWindowsFileName(const S: TPascalString): TPascalString; { Extract the file name from a Windows path. }
function umlGetUnixFileName(const S: TPascalString): TPascalString; { Extract the file name from a Unix path. }
function umlGetFilePath(platform_: TExecutePlatform; const S: TPascalString): TPascalString; overload; { Extract the directory path from a path, given a platform. }
function umlGetFilePath(const S: TPascalString): TPascalString; overload; { Extract the directory path from a path using the current platform. }
function umlGetWindowsFilePath(const S: TPascalString): TPascalString; { Extract the directory path from a Windows path. }
function umlGetUnixFilePath(const S: TPascalString): TPascalString; { Extract the directory path from a Unix path. }
function umlChangeFileExt(const S, ext: TPascalString): TPascalString; { Change the file extension of a path. If ext does not start with '.', it is added. }
function umlGetFileExt(const S: TPascalString): TPascalString; { Return the file extension (including the dot) of a path. }

{ FileIO }
procedure InitIOHnd(var IOHnd: TIOHnd); { Initialise a TIOHnd record to a safe default state. }
function umlFileCreateAsStream(const FileName: TPascalString; stream: U_Stream; var IOHnd: TIOHnd; OnlyRead_: Boolean): Boolean; overload; { Create an I/O handle from an existing stream, associating it with a file name. Optionally read-only. }
function umlFileCreateAsStream(const FileName: TPascalString; stream: U_Stream; var IOHnd: TIOHnd): Boolean; overload; { Create an I/O handle from an existing stream with read/write access. }
function umlFileCreateAsStream(stream: U_Stream; var IOHnd: TIOHnd): Boolean; overload; { Create an I/O handle from an existing stream with read/write access (no file name). }
function umlFileCreateAsStream(stream: U_Stream; var IOHnd: TIOHnd; OnlyRead_: Boolean): Boolean; overload; { Create an I/O handle from an existing stream, optionally read-only. }
function umlFileOpenAsStream(const FileName: TPascalString; stream: U_Stream; var IOHnd: TIOHnd; OnlyRead_: Boolean): Boolean; { Open an existing stream and associate with a file name, optionally read-only. }
function umlFileCreateAsMemory(var IOHnd: TIOHnd): Boolean; { Create an in-memory I/O handle (using a TMS64 stream). }
function umlFileCreate(const FileName: TPascalString; var IOHnd: TIOHnd): Boolean; { Create a new file on disk and open it for writing. }
function umlFileOpen(const FileName: TPascalString; var IOHnd: TIOHnd; OnlyRead_: Boolean): Boolean; { Open an existing file on disk, optionally read-only. }
function umlFileClose(var IOHnd: TIOHnd): Boolean; { Close the I/O handle and free the underlying stream if AutoFree is True. }
function umlFileUpdate(var IOHnd: TIOHnd): Boolean; { Flush any pending writes and update the handle's Size and Position. }
function umlFileTest(var IOHnd: TIOHnd): Boolean; { Test if the handle is open and valid. }
procedure umlResetPrepareRead(var IOHnd: TIOHnd); { Reset the read cache for the handle. }
function umlFilePrepareRead(var IOHnd: TIOHnd; Size: Int64; var buff): Boolean; { Prepare to read Size bytes into buff, using read-ahead cache if possible. Returns True on success. }
function umlFileRead(var IOHnd: TIOHnd; const Size: Int64; var buff): Boolean; { Read Size bytes from the handle into buff. Returns True on success. }
function umlBlockRead(var IOHnd: TIOHnd; var buff; const Size: Int64): Boolean; { Alias for umlFileRead. }
function umlFilePrepareWrite(var IOHnd: TIOHnd): Boolean; { Prepare the write cache for the handle (if enabled). }
function umlFileFlushWriteCache(var IOHnd: TIOHnd): Boolean; { Flush the write cache to the underlying stream. }
function umlFileWrite(var IOHnd: TIOHnd; const Size: Int64; const buff): Boolean; { Write Size bytes from buff to the handle. Returns True on success. }
function umlBlockWrite(var IOHnd: TIOHnd; const buff; const Size: Int64): Boolean; { Alias for umlFileWrite. }
function umlFileWriteFixedString(var IOHnd: TIOHnd; var Value: TPascalString): Boolean; { Write a Pascal string as a fixed-length field (length prefix + data). }
function umlFileReadFixedString(var IOHnd: TIOHnd; var Value: TPascalString): Boolean; { Read a fixed-length Pascal string field. }
function umlCheckSeedPos(var IOHnd: TIOHnd; Pos_: Int64): Boolean; { Check if a given position is valid within the file (0 <= Pos_ <= Size). }
function umlFileSeek(var IOHnd: TIOHnd; const Pos_: Int64): Boolean; { Seek to an absolute position in the file. Returns True on success. }
function umlFileSetSize(var IOHnd: TIOHnd; siz_: Int64): Boolean; { Set the file size (truncate or extend). }
function umlFileGetPOS(var IOHnd: TIOHnd): Int64; { Return the current position in the file. }
function umlFilePOS(var IOHnd: TIOHnd): Int64; { Alias for umlFileGetPOS. }
function umlFileGetSize(var IOHnd: TIOHnd): Int64; { Return the file size. }
function umlFileSize(var IOHnd: TIOHnd): Int64; { Alias for umlFileGetSize. }
function umlGetFileTime(const FileName: TPascalString): TDateTime; { Return the modification time of a file as TDateTime. }
procedure umlSetFileTime(const FileName: TPascalString; newTime: TDateTime); { Set the modification time of a file. }
function umlGetFileSize(const FileName: TPascalString): Int64; { Return the size of a file (or total size of multiple files if wildcard). }
function umlGetFileCount(const FileName: TPascalString): Integer; { Count the number of files matching a pattern. }
function umlGetFileDateTime(const FileName: TPascalString): TDateTime; { Return the last modification time of a file (using FileAge). }
function umlDeleteFile(const FileName: TPascalString; const _VerifyCheck: Boolean): Boolean; overload; { Delete a file or files (wildcards). Optionally verify deletion. }
function umlDeleteFile(const FileName: TPascalString): Boolean; overload; { Delete a file without verification. }
function umlCopyFile(const SourFile, DestFile: TPascalString): Boolean; { Copy a file, preserving timestamps. }
function umlRenameFile(const OldName, NewName: TPascalString): Boolean; { Rename a file. }

procedure umlSetLength(var sVal: TPascalString; L: Integer); overload; { Set the length of a TPascalString (number of characters). }
procedure umlSetLength(var sVal: U_Bytes; L: Integer); overload; { Set the length of a TBytes array. }
procedure umlSetLength(var sVal: TArrayPascalString; L: Integer); overload; { Set the length of a TArrayPascalString array. }
function umlGetLength(const sVal: TPascalString): Integer; overload; { Return the length of a TPascalString. }
function umlGetLength(const sVal: U_Bytes): Integer; overload; { Return the length of a TBytes array. }
function umlGetLength(const sVal: TArrayPascalString): Integer; overload; { Return the length of a TArrayPascalString array. }
function umlUpperCase(const S: TPascalString): TPascalString; overload; { Convert a string to uppercase. }
function umlUpperCase(const S: PPascalString): TPascalString; overload; { Convert a pointer to string to uppercase. }
function umlLowerCase(const S: TPascalString): TPascalString; overload; { Convert a string to lowercase. }
function umlLowerCase(const S: PPascalString): TPascalString; overload; { Convert a pointer to string to lowercase. }
function umlCopyStr(const sVal: TPascalString; MainPosition, LastPosition: Integer): TPascalString; { Extract a substring from MainPosition to LastPosition (1-based). }
function umlSameText(const s1, s2: TPascalString): Boolean; overload; { Case-insensitive comparison of two strings. }
function umlSameText(const s1, s2: PPascalString): Boolean; overload; { Case-insensitive comparison of two string pointers. }
function umlDeleteChar(const SText, Ch: TPascalString): TPascalString; overload; { Delete all occurrences of characters in Ch from SText. }
function umlDeleteChar(const SText: TPascalString; const SomeChars: TArrayChar): TPascalString; overload; { Delete characters from a set of characters. }
function umlDeleteChar(const SText: TPascalString; const SomeCharsets: TOrdChars): TPascalString; overload; { Delete characters matching a character set. }

function umlGetNumberCharInText(const n: TPascalString): TPascalString; { Extract the first numeric sequence found in n (digits only). }
function umlMatchChar(CharValue: U_Char; cVal: PPascalString): Boolean; overload; { Check if CharValue is in a string (via pointer). }
function umlMatchChar(CharValue: U_Char; cVal: TPascalString): Boolean; overload; { Check if CharValue is in a string. }
function umlExistsChar(StrValue: TPascalString; cVal: TPascalString): Boolean; overload; { Check if any character of cVal appears in StrValue. }
function umlExistsChar(StrValue, cVal: PPascalString): Boolean; overload; { Check if any character of cVal appears in StrValue (pointer variant). }
function umlTrimChar(const S, trim_s: TPascalString): TPascalString; { Trim characters in trim_s from both ends of S. }

function umlGetFirstStr(const sVal, trim_s: TPascalString): TPascalString; { Get the first token delimited by trim_s. }
function umlGetLastStr(const sVal, trim_s: TPascalString): TPascalString; { Get the last token delimited by trim_s. }
function umlDeleteFirstStr(const sVal, trim_s: TPascalString): TPascalString; { Remove the first token and return the remainder. }
function umlDeleteLastStr(const sVal, trim_s: TPascalString): TPascalString; { Remove the last token and return the remainder. }
function umlGetIndexStrCount(const sVal, trim_s: TPascalString): Integer; { Count the number of tokens delimited by trim_s. }
function umlGetIndexStr(const sVal: TPascalString; trim_s: TPascalString; index: Integer): TPascalString; { Get the index-th token (1-based) from sVal delimited by trim_s. }
procedure umlGetSplitArray(const sour: TPascalString; var dest: TArrayPascalString; const splitC: TPascalString); overload; { Split sour into an array of TPascalString using splitC as delimiter (treat consecutive delimiters as one). }
procedure umlGetSplitArray(const sour: TPascalString; var dest: U_StringArray; const splitC: TPascalString); overload; { Split sour into an array of system strings using splitC. }
function ArrayStringToText(var ary: TArrayPascalString; const splitC: TPascalString): TPascalString; { Convert an array of TPascalString to a single string with splitC as separator. }
function umlStringsToSplitText(lst: TCore_Strings; const splitC: TPascalString): TPascalString; overload; { Convert a TCore_Strings list to a delimited string. }
function umlStringsToSplitText(lst: TListPascalString; const splitC: TPascalString): TPascalString; overload; { Convert a TListPascalString list to a delimited string. }
function umlGetFirstStr___(const sVal, trim_s: TPascalString): TPascalString; { Get the first token, skipping leading delimiters (discontinuity version). }
function umlDeleteFirstStr___(const sVal, trim_s: TPascalString): TPascalString; { Delete the first token (discontinuity version). }
function umlGetLastStr___(const sVal, trim_s: TPascalString): TPascalString; { Get the last token (discontinuity version). }
function umlDeleteLastStr___(const sVal, trim_s: TPascalString): TPascalString; { Delete the last token (discontinuity version). }
function umlGetIndexStrCount___(const sVal, trim_s: TPascalString): Integer; { Count tokens (discontinuity version). }
function umlGetIndexStr___(const sVal: TPascalString; trim_s: TPascalString; index: Integer): TPascalString; { Get index-th token (discontinuity version). }
function umlGetFirstTextPos(const S: TPascalString; const TextArry: TArrayPascalString; var OutText: TPascalString): Integer; { Find the first occurrence of any text in TextArry within S, and output the matched text. Returns position (1-based). }
function umlDeleteText(const sour: TPascalString; const bToken, eToken: TArrayPascalString; ANeedBegin, ANeedEnd: Boolean): TPascalString; { Delete text between matching begin/end tokens (bToken/eToken). }
function umlGetTextContent(const sour: TPascalString; const bToken, eToken: TArrayPascalString): TPascalString; { Extract text between begin/end tokens. }

type
  TTextType = (ntBool, ntInt, ntInt64, ntUInt64, ntWord, ntByte, ntSmallInt, ntShortInt, ntUInt, ntSingle, ntDouble, ntCurrency, ntUnknow); { TTextType – enumeration of possible numeric text types for type detection. }
function umlGetNumTextType(const S: TPascalString): TTextType; { Determine the numeric type of a string (e.g., integer, float, hex, etc.). }

function umlIsHex(const sVal: TPascalString): Boolean; { Check if a string is a hexadecimal number (with $ prefix). }
function umlIsNumber(const sVal: TPascalString): Boolean; { Check if a string is a valid number (integer or float). }
function umlIsIntNumber(const sVal: TPascalString): Boolean; { Check if a string is an integer (not floating point). }
function umlIsFloatNumber(const sVal: TPascalString): Boolean; { Check if a string is a floating-point number. }
function umlIsBool(const sVal: TPascalString): Boolean; { Check if a string is a boolean ('true'/'false' etc.). }
function umlNumberCount(const sVal: TPascalString): Integer; { Count the number of digit characters in a string. }

function umlPercentageToFloat(OriginMax, OriginMin, ProcressParameter: Double): Double; { Compute percentage of ProcressParameter relative to range [OriginMin, OriginMax]. }
function umlPercentageToInt64(OriginParameter, ProcressParameter: Int64): Integer; { Compute percentage (0-100) of ProcressParameter relative to OriginParameter. }
function umlPercentageToInt(OriginParameter, ProcressParameter: Integer): Integer; { Compute percentage as integer. }
function umlPercentageToStr(OriginParameter, ProcressParameter: Integer): TPascalString; { Return a string representation of the percentage. }
function umlSmartSizeToStr(Size: Int64): TPascalString; { Convert a size (in bytes) to a human-readable string (e.g., '1.5Kb'). }

function umlIntToStr(Parameter: Single): TPascalString; overload; { Convert various numeric types to a TPascalString (integer part only). }
function umlIntToStr(Parameter: Double): TPascalString; overload; { Convert various numeric types to a TPascalString (integer part only). }
function umlIntToStr(Parameter: Int64): TPascalString; overload; { Convert various numeric types to a TPascalString (integer part only). }
function umlIntToStr(Parameter: UInt64): TPascalString; overload; { Convert various numeric types to a TPascalString (integer part only). }
function umlIntToStr(Parameter: Int128): TPascalString; overload; { Convert various numeric types to a TPascalString (integer part only). }
function umlIntToStr(Parameter: UInt128): TPascalString; overload; { Convert various numeric types to a TPascalString (integer part only). }
function umlIntToStr(Parameter: Integer): TPascalString; overload; { Convert various numeric types to a TPascalString (integer part only). }
function umlIntToStr(Parameter: Cardinal): TPascalString; overload; { Convert various numeric types to a TPascalString (integer part only). }
function umlPointerToStr(param: Pointer): TPascalString; { Convert a pointer to a hex string. }
function umlMBPSToStr(Size: Int64): TPascalString; { Convert a data rate (bytes per second) to a human-readable string (Kbps/Mbps). }
function umlSizeToStr(Parameter: Int64): TPascalString; { Alias for umlSmartSizeToStr. }
function umlGSizeToStr(Parameter: Int64): TPascalString; { Convert a size to a string with bigger units (GB, etc.). }

function umlStrToTime(S: TPascalString): TDateTime; { Convert a string to TDateTime using the library's format settings. }
function umlTimeToStr(t: TDateTime): TPascalString; { Convert a TDateTime to a time string. }
function umlStrToDateTime(S: TPascalString): TDateTime; { Convert a string to TDateTime (date+time). }
function umlDateTimeToStr(t: TDateTime): TPascalString; { Convert a TDateTime to a date+time string. }
function umlDT(t: TDateTime): TPascalString; overload; { Shortcut for umlDateTimeToStr. }
function umlDT(S: TPascalString): TDateTime; overload; { Convert a string to TDateTime (date+time). }
function umlDT(S: TPascalString; Default_: TDateTime): TDateTime; overload; { Convert a string to TDateTime with a default value. }
function umlT(t: TDateTime): TPascalString; overload; { Shortcut for umlTimeToStr. }
function umlT(S: TPascalString): TDateTime; overload; { Convert a string to time. }
function umlT(S: TPascalString; Default_: TDateTime): TDateTime; overload; { Convert a string to time with default. }
function umlTimeTickToStr(const t: TTimeTick): TPascalString; { Convert a time tick (milliseconds) to a human-readable string (days:hours:minutes:seconds.ms). }
function umlDateToStr(t: TDateTime): TPascalString; { Convert a TDateTime to a date string. }

function umlFloatToStr(const f: Double): TPascalString; { Convert a Double to a string. }
function umlShortFloatToStr(const f: Double): TPascalString; { Convert a Double to a string with default formatting. }

function umlStrToInt(const V_: TPascalString): Integer; overload; { Convert a string to Integer (default 0). }
function umlStrToInt(const V_: TPascalString; _Def: Integer): Integer; overload; { Convert a string to Integer with a default. }
function umlStrToInt64(const V_: TPascalString; _Def: Int64): Int64; overload; { Convert a string to Int64 with a default. }
function umlStrToInt64(const V_: TPascalString): Int64; overload; { Convert a string to Int64 (default 0). }
function umlStrToInt128(const V_: TPascalString; _Def: Int128): Int128; overload; { Convert a string to Int128 with a default. }
function umlStrToInt128(const V_: TPascalString): Int128; overload; { Convert a string to Int128 (default 0). }
function umlStrToFloat(const V_: TPascalString; _Def: Double): Double; overload; { Convert a string to Double with a default. }
function umlStrToFloat(const V_: TPascalString): Double; overload; { Convert a string to Double (default 0). }

function umlMultipleMatch(IgnoreCase: Boolean; const source, target, Multiple_, Character_: TPascalString): Boolean; overload; { Wildcard matching with custom wildcard and single-character placeholders. }
function umlMultipleMatch(IgnoreCase: Boolean; const source, target: TPascalString): Boolean; overload; { Wildcard matching using '*' and '?' as default. }
function umlMultipleMatch(const source, target: TPascalString): Boolean; overload; { Wildcard matching with case-insensitive default, and support for multiple patterns separated by ';'. }
function umlMultipleMatch(const source: array of TPascalString; const target: TPascalString): Boolean; overload; { Match an array of source patterns against target. }
function umlMultipleMatch(const source: TPascalStringList; const target: TPascalString): Boolean; overload; { Match a TPascalStringList of patterns against target. }
function umlSearchMatch(const source, target: TPascalString): Boolean; overload; { Search for a substring (or pattern) in target, using ';' as separator for multiple patterns. }
function umlSearchMatch(const source, exclude, target: TPascalString): Boolean; overload; { Search with an exclude list. }
function umlSearchMatch(const source: TArrayPascalString; target: TPascalString): Boolean; overload; { Search using arrays of patterns. }
function umlSearchMatch(const source, exclude: TArrayPascalString; target: TPascalString): Boolean; overload; { Search with exclude array. }

function umlMatchFileInfo(const exp_, sour_, dest_: TPascalString): Boolean; { Match a file name pattern using <prefix> and <postfix> placeholders. }

function umlGetDateTimeStr(NowDateTime: TDateTime): TPascalString; { Get a date/time string in a fixed format (YYYY-MM-DD HH-MM-SS-MS). }
function umlDecodeTimeToStr(NowDateTime: TDateTime): TPascalString; { Get a date/time string in a hexadecimal-compact format. }

function umlGenerate_Random_Name: TPascalString; overload; { Generate a random name (MD5 of current time + random values). }
function umlGenerate_Random_Name(rand_data: Int64): TPascalString; overload; { Generate a random name with a user-supplied random seed. }

function umlDecodeDateTimeToInt64(NowDateTime: TDateTime): Int64; { Convert a TDateTime to Unix timestamp (Int64). }

type
  TBatch = record
  private
    procedure Swap_(var inst: TBatch);
  public
    sour, dest: TPascalString; // Source and destination strings.
    sum: Integer; // Number of replacements.
  end; { TBatch – a record representing a substitution pair (sour -> dest) with a count of occurrences. }

  PBatch = ^TBatch;
  TArrayBatch = array of TBatch; { Dynamic array of TBatch. }

  TBatchInfo = record
    Batch: Integer; // Index into the batch array.
    sour_bPos, sour_ePos: Integer; // Start and end position in source.
    dest_bPos, dest_ePos: Integer; // Start and end position in destination.
  end; { TBatchInfo – stores position information for a single batch replacement. Used to report where replacements occurred. }

  TBatchInfoList = TGenericsList<TBatchInfo>; { List of TBatchInfo items. }
{$IFDEF FPC}
  TOnBatchProc = procedure(bPos, ePos: Integer; sour, dest: PPascalString; var Accept: Boolean) is nested;
{$ELSE FPC}
  TOnBatchProc = reference to procedure(bPos, ePos: Integer; sour, dest: PPascalString; var Accept: Boolean);
{$ENDIF FPC}
  { TOnBatchProc – callback for batch replacement, invoked for each match. Parameters: bPos, ePos (source positions), sour, dest (pointers to the matched pattern and its replacement), and Accept (can be used to abort). }
function umlBuildBatch(L: THashStringList): TArrayBatch; overload; { Build a batch array from a THashStringList (key->value). }
function umlBuildBatch(L: THashVariantList): TArrayBatch; overload; { Build a batch array from a THashVariantList (key->value). }
procedure umlClearBatch(var arry: TArrayBatch); { Clear a batch array (free memory). }
procedure umlSortBatch(var arry: TArrayBatch); { Sort batch array by source string length (descending) to ensure longest match first. }
function umlCharIsSymbol(C: SystemChar): Boolean; overload; { Check if a character is a symbol (punctuation, whitespace, etc.). }
function umlCharIsSymbol(C: SystemChar; const CustomSymbol_: TArrayChar): Boolean; overload; { Check if a character is in a custom set of symbols. }
function umlIsWord(p: PPascalString; bPos, ePos: Integer): Boolean; overload; { Check if the substring from bPos to ePos in p is a whole word (bounded by symbols or string ends). }
function umlIsWord(S: TPascalString; bPos, ePos: Integer): Boolean; overload; { Overload for a string value. }
function umlExtractWord(S: TPascalString): TArrayPascalString; overload; { Extract all words (tokens separated by symbols) from S. }
function umlExtractWord(S: TPascalString; const CustomSymbol_: TArrayChar): TArrayPascalString; overload; { Extract words using a custom set of symbol characters. }
function umlBatchSum(p: PPascalString; var arry: TArrayBatch; OnlyWord, IgnoreCase: Boolean; bPos, ePos: Integer; Info: TBatchInfoList): Integer; overload; { Count occurrences of each batch pattern in a string (p). }
function umlBatchSum(S: TPascalString; var arry: TArrayBatch; OnlyWord, IgnoreCase: Boolean; bPos, ePos: Integer; Info: TBatchInfoList): Integer; overload; { Overload for a string value. }
function umlBatchSum(S: TPascalString; var arry: TArrayBatch; OnlyWord, IgnoreCase: Boolean; bPos, ePos: Integer): Integer; overload; { Count occurrences without Info. }
function umlBatchReplace(p: PPascalString; var arry: TArrayBatch; OnlyWord, IgnoreCase: Boolean; bPos, ePos: Integer; Info: TBatchInfoList; On_P: TOnBatchProc): TPascalString; overload; { Perform batch replacement on a string (p). Returns the new string. }
function umlBatchReplace(S: TPascalString; var arry: TArrayBatch; OnlyWord, IgnoreCase: Boolean; bPos, ePos: Integer; Info: TBatchInfoList; On_P: TOnBatchProc): TPascalString; overload; { Overload for a string value. }
function umlBatchReplace(S: TPascalString; var arry: TArrayBatch; OnlyWord, IgnoreCase: Boolean; bPos, ePos: Integer; Info: TBatchInfoList): TPascalString; overload; { Batch replace without callback. }
function umlBatchReplace(S: TPascalString; var arry: TArrayBatch; OnlyWord, IgnoreCase: Boolean; bPos, ePos: Integer): TPascalString; overload; { Batch replace without Info or callback. }
function umlReplaceSum(p: PPascalString; Pattern: TPascalString; OnlyWord, IgnoreCase: Boolean; bPos, ePos: Integer; Info: TBatchInfoList): Integer; overload; { Count occurrences of a single pattern. }
function umlReplaceSum(S, Pattern: TPascalString; OnlyWord, IgnoreCase: Boolean; bPos, ePos: Integer; Info: TBatchInfoList): Integer; overload; { Overload for string value. }
function umlReplace(p: PPascalString; OldPattern, NewPattern: TPascalString; OnlyWord, IgnoreCase: Boolean; bPos, ePos: Integer; Info: TBatchInfoList; On_P: TOnBatchProc): TPascalString; overload; { Replace a single pattern with another, with callback. }
function umlReplace(S, OldPattern, NewPattern: TPascalString; OnlyWord, IgnoreCase: Boolean; bPos, ePos: Integer; Info: TBatchInfoList; On_P: TOnBatchProc): TPascalString; overload; { Overload for string value. }
function umlReplace(S, OldPattern, NewPattern: TPascalString; OnlyWord, IgnoreCase: Boolean; bPos, ePos: Integer; Info: TBatchInfoList): TPascalString; overload; { Replace without callback. }
function umlReplace(p: PPascalString; OldPattern, NewPattern: TPascalString; OnlyWord, IgnoreCase: Boolean): TPascalString; overload; { Replace in the entire string (no bounds). }
function umlReplace(S, OldPattern, NewPattern: TPascalString; OnlyWord, IgnoreCase: Boolean): TPascalString; overload; { Overload for string value. }
function umlComputeTextPoint(p: PPascalString; Pos_: Integer): TPoint; { Compute the line and column position of a character index in a string. }

function umlStringReplace(const S, OldPattern, NewPattern: TPascalString; IgnoreCase: Boolean): TPascalString; { Replace all occurrences using RTL's StringReplace with IgnoreCase flag. }
function umlReplaceString(const S, OldPattern, NewPattern: TPascalString; IgnoreCase: Boolean): TPascalString; { Alias for umlStringReplace. }
function umlCharReplace(const S: TPascalString; OldPattern, NewPattern: U_Char): TPascalString; { Replace a character with another (character-level). }
function umlReplaceChar(const S: TPascalString; OldPattern, NewPattern: U_Char): TPascalString; { Alias for umlCharReplace. }

function umlEncodeText2HTML(const psSrc: TPascalString): TPascalString; { Encode a string to HTML entities (e.g., '<' becomes '&lt;'). }
function umlURLEncode(const Data: TPascalString): TPascalString; { URL-encode a string (percent-encoding). }
function umlURLDecode(const Data: TPascalString; FormEncoded: Boolean): TPascalString; { URL-decode a string, optionally handling form-encoded '+' as space. }

type
  TRTSP_RTMP_URL = record
    prefix, user, passwd, host, port, path: TPascalString;
    procedure Init;
    function Encode: U_String;
    procedure Decode(Data_: U_String);
  end; { TRTSP_RTMP_URL – structure to hold parsed RTSP/RTMP URL components. }

function umlExtract_RTSP_RTMP_URL(const URL: TPascalString; var prefix, user, passwd, host, port, path: TPascalString): Boolean; overload; { Extract RTSP/RTMP URL components into separate strings. }
function umlExtract_RTSP_RTMP_URL(const URL: TPascalString; var To_: TRTSP_RTMP_URL): Boolean; overload; { Extract RTSP/RTMP URL into a TRTSP_RTMP_URL record. }
function umlEncode_RTSP_RTMP_URL(prefix, user, passwd, host, port, path: TPascalString): TPascalString; { Encode RTSP/RTMP components back to a URL. }
function umlRemove_Passwd_RTSP_RTMP_URL(const URL: TPascalString): TPascalString; { Remove password from an RTSP/RTMP URL. }

type
  TBase64Context = record
    Tail: array [0 .. 3] of Byte;
    TailBytes: Integer;
    LineWritten: Integer;
    LineSize: Integer;
    TrailingEol: Boolean;
    PutFirstEol: Boolean;
    LiberalMode: Boolean;
    fEOL: array [0 .. 3] of Byte;
    EOLSize: Integer;
    OutBuf: array [0 .. 3] of Byte;
    EQUCount: Integer;
    UseUrlAlphabet: Boolean;
  end; { TBase64Context – internal state for streaming Base64 encoding/decoding. }

  TBase64EOLMarker = (emCRLF, emCR, emLF, emNone);
  TBase64ByteArray = array [0 .. MaxInt div SizeOf(Byte) - 1] of Byte;
  PBase64ByteArray = ^TBase64ByteArray;

const
  BASE64_DECODE_OK = 0;
  BASE64_DECODE_INVALID_CHARACTER = 1;
  BASE64_DECODE_WRONG_DATA_SIZE = 2;
  BASE64_DECODE_NOT_ENOUGH_SPACE = 3;
  Base64Symbols: array [0 .. 63] of Byte = (
    $41, $42, $43, $44, $45, $46, $47, $48, $49, $4A, $4B, $4C, $4D, $4E, $4F, $50,
    $51, $52, $53, $54, $55, $56, $57, $58, $59, $5A, $61, $62, $63, $64, $65, $66,
    $67, $68, $69, $6A, $6B, $6C, $6D, $6E, $6F, $70, $71, $72, $73, $74, $75, $76,
    $77, $78, $79, $7A, $30, $31, $32, $33, $34, $35, $36, $37, $38, $39, $2B, $2F);
  Base64Values: array [0 .. 255] of Byte = (
    $FE, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FE, $FE, $FF, $FF, $FE, $FF, $FF,
    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF,
    $FE, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $3E, $FF, $FF, $FF, $3F,
    $34, $35, $36, $37, $38, $39, $3A, $3B, $3C, $3D, $FF, $FF, $FF, $FD, $FF, $FF,
    $FF, $00, $01, $02, $03, $04, $05, $06, $07, $08, $09, $0A, $0B, $0C, $0D, $0E,
    $0F, $10, $11, $12, $13, $14, $15, $16, $17, $18, $19, $FF, $FF, $FF, $FF, $FF,
    $FF, $1A, $1B, $1C, $1D, $1E, $1F, $20, $21, $22, $23, $24, $25, $26, $27, $28,
    $29, $2A, $2B, $2C, $2D, $2E, $2F, $30, $31, $32, $33, $FF, $FF, $FF, $FF, $FF,
    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF,
    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF,
    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF,
    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF,
    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF,
    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF,
    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF,
    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF);

function B64EstimateEncodedSize(cont: TBase64Context; InSize: Integer): Integer; { Estimate the encoded size for Base64 output given input size and context. }
function B64InitializeDecoding(var cont: TBase64Context; LiberalMode: Boolean): Boolean; { Initialise a Base64 decoding context. }
function B64InitializeEncoding(var cont: TBase64Context; LineSize: Integer; fEOL: TBase64EOLMarker; TrailingEol: Boolean): Boolean; { Initialise a Base64 encoding context with line wrapping settings. }
function B64Encode(var cont: TBase64Context; buffer: PByte; Size: Integer; OutBuffer: PByte; var OutSize: Integer): Boolean; { Encode a chunk of data into Base64, updating context. }
function B64Decode(var cont: TBase64Context; buffer: PByte; Size: Integer; OutBuffer: PByte; var OutSize: Integer): Boolean; { Decode a chunk of Base64 data, updating context. }
function B64FinalizeEncoding(var cont: TBase64Context; OutBuffer: PByte; var OutSize: Integer): Boolean; { Finalise encoding (write padding and trailing EOL). }
function B64FinalizeDecoding(var cont: TBase64Context; OutBuffer: PByte; var OutSize: Integer): Boolean; { Finalise decoding (process remaining data and padding). }
function umlBase64Encode(InBuffer: PByte; InSize: Integer; OutBuffer: PByte; var OutSize: Integer; WrapLines: Boolean): Boolean; { High-level Base64 encode with optional line wrapping. }
function umlBase64Decode(InBuffer: PByte; InSize: Integer; OutBuffer: PByte; var OutSize: Integer; LiberalMode: Boolean): Integer; { High-level Base64 decode with liberal mode (ignore invalid chars). }
procedure umlBase64EncodeBytes(var sour, dest: TBytes); overload; { Base64 encode a TBytes array to another TBytes. }
procedure umlBase64DecodeBytes(var sour, dest: TBytes); overload; { Base64 decode a TBytes array to another TBytes. }

// typ TPascalString
procedure umlBase64EncodeBytes(var sour: TBytes; var dest: TPascalString); overload; { Base64 encode a TBytes array to a TPascalString. }
procedure umlBase64DecodeBytes(const sour: TPascalString; var dest: TBytes); overload; { Base64 decode a TPascalString to a TBytes. }
procedure umlDecodeLineBASE64(const buffer: TPascalString; var output: TPascalString); overload; { Decode a Base64 string and store result in output TPascalString. }
procedure umlEncodeLineBASE64(const buffer: TPascalString; var output: TPascalString); overload; { Encode a TPascalString to Base64. }
function umlDecodeLineBASE64(const buffer: TPascalString): TPascalString; overload; { Return decoded Base64 string as TPascalString. }
function umlEncodeLineBASE64(const buffer: TPascalString): TPascalString; overload; { Return encoded Base64 string. }
procedure umlDecodeStreamBASE64(const buffer: TPascalString; output: TCore_Stream); overload; { Decode Base64 from a TPascalString and write decoded bytes to a stream. }
procedure umlEncodeStreamBASE64(buffer: TCore_Stream; var output: TPascalString); overload; { Encode a stream's content to Base64 and return as a string. }
function umlDivisionBase64Text(const buffer: TPascalString; width: Integer; DivisionAsPascalString: Boolean): TPascalString; overload; { Format a Base64 string with line breaks at specified width, optionally as Pascal string literal. }
function umlTestBase64(const text: TPascalString): Boolean; overload; { Test if a string appears to be valid Base64 (can decode without error). }

// typ TUPascalString
procedure umlBase64EncodeBytes(var sour: TBytes; var dest: TUPascalString); overload; { Base64 encode a TBytes array to a TUPascalString. }
procedure umlBase64DecodeBytes(const sour: TUPascalString; var dest: TBytes); overload; { Base64 decode a TUPascalString to a TBytes. }
procedure umlDecodeLineBASE64(const buffer: TUPascalString; var output: TUPascalString); overload; { Decode a Base64 string and store result in output TUPascalString. }
procedure umlEncodeLineBASE64(const buffer: TUPascalString; var output: TUPascalString); overload; { Encode a TUPascalString to Base64. }
function umlDecodeLineBASE64(const buffer: TUPascalString): TUPascalString; overload; { Return decoded Base64 string as TUPascalString. }
function umlEncodeLineBASE64(const buffer: TUPascalString): TUPascalString; overload; { Return encoded Base64 string. }
procedure umlDecodeStreamBASE64(const buffer: TUPascalString; output: TCore_Stream); overload; { Decode Base64 from a TUPascalString and write decoded bytes to a stream. }
procedure umlEncodeStreamBASE64(buffer: TCore_Stream; var output: TUPascalString); overload; { Encode a stream's content to Base64 and return as a string. }
function umlDivisionBase64Text(const buffer: TUPascalString; width: Integer; DivisionAsPascalString: Boolean): TUPascalString; overload; { Format a Base64 string with line breaks at specified width, optionally as Pascal string literal. }
function umlTestBase64(const text: TUPascalString): Boolean; overload; { Test if a string appears to be valid Base64 (can decode without error). }

type
  TMD5_Pool = TGenericsList<TMD5>; { TMD5_Pool – generic list of MD5 digests. }
  TMD5_Big_Pool = TBigList<TMD5>;
  TArrayMD5 = array of TMD5;
  TMD5_Pair_Pool_Decl = TBig_Hash_Pair_Pool<TMD5, TMD5>;

  TMD5_Tool = class(TCore_Object_Intermediate)
  private
    Mem: TMem64;
    Digest: TMD5;
    FCompleted_Size: Int64;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Update(buff: Pointer; Size__: Int64);
    function FinalizeMD5: TMD5;
    property Completed_Size: Int64 read FCompleted_Size;
  end; { TMD5_Tool – incremental MD5 calculation using a memory buffer. }

  TMD5_Pair_Pool = class(TMD5_Pair_Pool_Decl)
  public
    IsChanged: Boolean;
    constructor Create(HashSize_: Integer);
    procedure DoFree(var Key: TMD5; var Value: TMD5); override;
    procedure DoAdd(var Key: TMD5; var Value: TMD5); override;
    procedure LoadFromStream(stream: TCore_Stream);
    procedure SaveToStream(stream: TCore_Stream);
  end; { TMD5_Pair_Pool – a hash map with MD5 keys and MD5 values, with change tracking. }

const
  NULL_MD5: TMD5 = (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0);
  Zero_MD5: TMD5 = (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0);
  NULLMD5: TMD5 = (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0);
  ZeroMD5: TMD5 = (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0);
  umlNULLMD5: TMD5 = (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0);
  umlZeroMD5: TMD5 = (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0);
  NULL_Buff_MD5: TMD5 = (212, 29, 140, 217, 143, 0, 178, 4, 233, 128, 9, 152, 236, 248, 66, 126);

function umlStrIsMD5(hex: TPascalString): Boolean; { Check if a hex string is a valid MD5 (32 hex characters). }
function umlStrToMD5(hex: TPascalString): TMD5; { Convert a hex string to an MD5 digest. }
procedure umlTransformMD5(var Accu; const Buf); { One MD5 transform block (used internally). }
function umlMD5(const buffPtr: PByte; bufSiz: NativeUInt): TMD5; { Compute MD5 of a memory buffer. }
function umlMD5Char(const buffPtr: PByte; const BuffSize: NativeUInt): TPascalString; { Compute MD5 and return as hex string. }
function umlMD5String(const buffPtr: PByte; const BuffSize: NativeUInt): TPascalString; { Alias for umlMD5Char. }
function umlMD5Str(const buffPtr: PByte; const BuffSize: NativeUInt): TPascalString; { Alias for umlMD5Char. }
function umlStreamMD5(stream: TCore_Stream; StartPos, EndPos: Int64): TMD5; overload; { Compute MD5 of a stream range. }
function umlStreamMD5(stream: TCore_Stream): TMD5; overload; { Compute MD5 of the entire stream. }
function umlStreamMD5Char(stream: TCore_Stream): TPascalString; overload; { Stream MD5 as hex string. }
function umlStreamMD5String(stream: TCore_Stream): TPascalString; overload; { Alias. }
function umlStreamMD5Str(stream: TCore_Stream): TPascalString; overload; { Alias. }
function umlStringMD5(const Value: TPascalString): TPascalString; { Compute MD5 of a Pascal string. }
function umlFileMD5___(FileName: TPascalString): TMD5; overload; { Internal file MD5 (no caching). }
function umlFileMD5(FileName: TPascalString; StartPos, EndPos: Int64): TMD5; overload; { Compute MD5 of a file range. }
function umlCombineMD5(const m1: TMD5): TMD5; overload; { Combine MD5 digests: MD5(m1). }
function umlCombineMD5(const m1, m2: TMD5): TMD5; overload; { Combine two MD5 digests: MD5(m1 + m2). }
function umlCombineMD5(const m1, m2, m3: TMD5): TMD5; overload; { Combine three MD5 digests. }
function umlCombineMD5(const m1, m2, m3, m4: TMD5): TMD5; overload; { Combine four MD5 digests. }
function umlCombineMD5(const buff: array of TMD5): TMD5; overload; { Combine an array of MD5 digests. }
function umlMD5ToStr(md5: TMD5): TPascalString; overload; { Convert MD5 to hex string. }
function umlMD5ToStr(const buffPtr: PByte; bufSiz: NativeUInt): TPascalString; overload; { Compute MD5 of a buffer and return hex. }
function umlMD5ToString(md5: TMD5): TPascalString; overload; { Alias for umlMD5ToStr. }
function umlMD5ToString(const buffPtr: PByte; bufSiz: NativeUInt): TPascalString; overload; { Alias. }
function umlMD52String(md5: TMD5): TPascalString; overload; { Alias. }
function umlMD5Compare(const m1, m2: TMD5): Boolean; { Compare two MD5 digests for equality. }
function umlCompareMD5(const m1, m2: TMD5): Boolean; { Alias. }
function umlIsNullMD5(M: TMD5): Boolean; { Check if an MD5 is all zeros. }
function umlWasNullMD5(M: TMD5): Boolean; { Alias. }
function umlFileMD5(FileName: TPascalString): TMD5; overload; { Cached MD5 computation for files (caches results based on timestamp and size). }
procedure Do_ThCacheFileMD5(ThSender: TCompute); { Background thread procedure to cache file MD5. }
procedure umlCacheFileMD5(FileName: U_String); { Asynchronously cache MD5 of a file. }
procedure umlCacheFileMD5FromDirectory(Directory_, Filter_: U_String); { Asynchronously cache MD5 of all files in a directory matching a filter. }

{$REGION 'crc16define'}


const
  CRC16Table: array [0 .. 255] of Word = (
    $0000, $C0C1, $C181, $0140, $C301, $03C0, $0280, $C241, $C601, $06C0, $0780,
    $C741, $0500, $C5C1, $C481, $0440, $CC01, $0CC0, $0D80, $CD41, $0F00, $CFC1,
    $CE81, $0E40, $0A00, $CAC1, $CB81, $0B40, $C901, $09C0, $0880, $C841, $D801,
    $18C0, $1980, $D941, $1B00, $DBC1, $DA81, $1A40, $1E00, $DEC1, $DF81, $1F40,
    $DD01, $1DC0, $1C80, $DC41, $1400, $D4C1, $D581, $1540, $D701, $17C0, $1680,
    $D641, $D201, $12C0, $1380, $D341, $1100, $D1C1, $D081, $1040, $F001, $30C0,
    $3180, $F141, $3300, $F3C1, $F281, $3240, $3600, $F6C1, $F781, $3740, $F501,
    $35C0, $3480, $F441, $3C00, $FCC1, $FD81, $3D40, $FF01, $3FC0, $3E80, $FE41,
    $FA01, $3AC0, $3B80, $FB41, $3900, $F9C1, $F881, $3840, $2800, $E8C1, $E981,
    $2940, $EB01, $2BC0, $2A80, $EA41, $EE01, $2EC0, $2F80, $EF41, $2D00, $EDC1,
    $EC81, $2C40, $E401, $24C0, $2580, $E541, $2700, $E7C1, $E681, $2640, $2200,
    $E2C1, $E381, $2340, $E101, $21C0, $2080, $E041, $A001, $60C0, $6180, $A141,
    $6300, $A3C1, $A281, $6240, $6600, $A6C1, $A781, $6740, $A501, $65C0, $6480,
    $A441, $6C00, $ACC1, $AD81, $6D40, $AF01, $6FC0, $6E80, $AE41, $AA01, $6AC0,
    $6B80, $AB41, $6900, $A9C1, $A881, $6840, $7800, $B8C1, $B981, $7940, $BB01,
    $7BC0, $7A80, $BA41, $BE01, $7EC0, $7F80, $BF41, $7D00, $BDC1, $BC81, $7C40,
    $B401, $74C0, $7580, $B541, $7700, $B7C1, $B681, $7640, $7200, $B2C1, $B381,
    $7340, $B101, $71C0, $7080, $B041, $5000, $90C1, $9181, $5140, $9301, $53C0,
    $5280, $9241, $9601, $56C0, $5780, $9741, $5500, $95C1, $9481, $5440, $9C01,
    $5CC0, $5D80, $9D41, $5F00, $9FC1, $9E81, $5E40, $5A00, $9AC1, $9B81, $5B40,
    $9901, $59C0, $5880, $9841, $8801, $48C0, $4980, $8941, $4B00, $8BC1, $8A81,
    $4A40, $4E00, $8EC1, $8F81, $4F40, $8D01, $4DC0, $4C80, $8C41, $4400, $84C1,
    $8581, $4540, $8701, $47C0, $4680, $8641, $8201, $42C0, $4380, $8341, $4100,
    $81C1, $8081, $4040
    );
{$ENDREGION 'crc16define'}

function umlCRC16(const Value: PByte; const Count: NativeUInt): Word; { Compute CRC16 of a memory buffer. }
function umlStringCRC16(const Value: TPascalString): Word; { Compute CRC16 of a Pascal string. }
function umlStreamCRC16(stream: U_Stream; StartPos, EndPos: Int64): Word; overload; { Compute CRC16 of a stream range. }
function umlStreamCRC16(stream: U_Stream): Word; overload; { Compute CRC16 of entire stream. }

function umlCRC32(const Value: PByte; const Count: NativeUInt): Cardinal; { Compute CRC32 of a memory buffer. }
function umlString2CRC32(const Value: TPascalString): Cardinal; { Compute CRC32 of a Pascal string. }
function umlStreamCRC32(stream: U_Stream; StartPos, EndPos: Int64): Cardinal; overload; { Compute CRC32 of a stream range. }
function umlStreamCRC32(stream: U_Stream): Cardinal; overload; { Compute CRC32 of entire stream. }

function umlTrimSpace(const S: TPascalString): TPascalString; { Trim leading/trailing spaces (and #0) from a string. }

function umlSeparatorText(Text_: TPascalString; dest: TCore_Strings; SeparatorChar: TPascalString): Integer; overload; { Split Text_ by SeparatorChar and add to a TCore_Strings list. Returns count. }
function umlSeparatorText(Text_: TPascalString; dest: THashVariantList; SeparatorChar: TPascalString): Integer; overload; { Split and add to a THashVariantList (increment value for each occurrence). }
function umlSeparatorText(Text_: TPascalString; dest: TListPascalString; SeparatorChar: TPascalString): Integer; overload; { Split and add to a TListPascalString. }
function umlSeparatorText(Text_: TPascalString; var dest: U_StringArray; SeparatorChar: TPascalString): Integer; overload; { Split and return as a U_StringArray. }
function umlStringsMatchText(OriginValue: TCore_Strings; DestValue: TPascalString; IgnoreCase: Boolean): Boolean; { Check if any string in OriginValue matches DestValue using wildcard matching. }
function umlStringsInExists(dest: TListPascalString; SText: TPascalString; IgnoreCase: Boolean): Boolean; overload; { Check if SText exists in a TListPascalString (case-sensitive/insensitive). }
function umlStringsInExists(dest: TCore_Strings; SText: TPascalString; IgnoreCase: Boolean): Boolean; overload; { Check if SText exists in a TCore_Strings. }
function umlStringsInExists(dest: TCore_Strings; SText: TPascalString): Boolean; overload; { Check with case-insensitive default. }
function umlTextInStrings(const SText: TPascalString; dest: TListPascalString; IgnoreCase: Boolean): Boolean; overload; { Alias for umlStringsInExists. }
function umlTextInStrings(const SText: TPascalString; dest: TCore_Strings; IgnoreCase: Boolean): Boolean; overload; { Alias for umlStringsInExists. }
function umlTextInStrings(const SText: TPascalString; dest: TCore_Strings): Boolean; overload; { Alias for umlStringsInExists. }
function umlAddNewStrTo(source: TPascalString; dest: TListPascalString; IgnoreCase: Boolean): Boolean; overload; { Add source to dest if not already present. Returns True if added. }
function umlAddNewStrTo(source: TPascalString; dest: TCore_Strings; IgnoreCase: Boolean): Boolean; overload; { Add source to dest if not already present. Returns True if added. }
function umlAddNewStrTo(source: TPascalString; dest: TCore_Strings): Boolean; overload; { Add source to dest if not already present. Returns True if added. }
function umlAddNewStrTo(source, dest: TCore_Strings): Integer; overload; { Add all unique strings from source to dest. Returns number added. }
function umlDeleteStrings(const SText: TPascalString; dest: TCore_Strings; IgnoreCase: Boolean): Integer; { Delete all strings from dest that match SText (wildcard). Returns count. }
function umlDeleteStringsNot(const SText: TPascalString; dest: TCore_Strings; IgnoreCase: Boolean): Integer; { Delete all strings that do NOT match SText. }
function umlMergeStrings(source, dest: TCore_Strings; IgnoreCase: Boolean): Integer; overload; { Merge unique strings from source into dest. Returns number added. }
function umlMergeStrings(source, dest: TListPascalString; IgnoreCase: Boolean): Integer; overload; { Merge unique strings from source into dest. Returns number added. }
function umlMergeStrings(source: TListPascalString; dest: TCore_Strings; IgnoreCase: Boolean): Integer; overload; { Merge unique strings from source into dest. Returns number added. }
function umlConverStrToFileName(const Value: TPascalString): TPascalString; { Convert a string to a safe file name (replace illegal characters with spaces). }
function umlSplitTextMatch(const SText, Limit, MatchText: TPascalString; IgnoreCase: Boolean): Boolean; { Check if any token in SText (split by Limit) matches MatchText (wildcard). }
function umlSplitTextTrimSpaceMatch(const SText, Limit, MatchText: TPascalString; IgnoreCase: Boolean): Boolean; { Same as above but trims spaces from tokens. }
function umlSplitDeleteText(const SText, Limit, MatchText: TPascalString; IgnoreCase: Boolean): TPascalString; { Remove tokens that match MatchText and return the remaining string. }
function umlSplitTextAsList(const SText, Limit: TPascalString; AsLst: TCore_Strings): Boolean; { Split SText by Limit and populate AsLst. Returns True if any tokens. }
function umlSplitTextAsListAndTrimSpace(const SText, Limit: TPascalString; AsLst: TCore_Strings): Boolean; { Split and trim each token. }
function umlListAsSplitText(const List: TCore_Strings; Limit: TPascalString): TPascalString; overload; { Join a TCore_Strings list with Limit as separator. }
function umlListAsSplitText(const List: TListPascalString; Limit: TPascalString): TPascalString; overload; { Join a TListPascalString. }
function umlDivisionText(const buffer: TPascalString; width: Integer; DivisionAsPascalString: Boolean): TPascalString; { Format text with line breaks at width, optionally as Pascal string literal. }

function umlUpdateComponentName(const Name: TPascalString): TPascalString; { Sanitise a component name (keep only alphanumeric and hyphen). }
function umlMakeComponentName(Owner: TCore_Component; RefrenceName: TPascalString): TPascalString; { Generate a unique component name based on Owner and a reference name. }
procedure umlReadComponent(stream: TCore_Stream; comp: TCore_Component); { Read a component from a stream. }
procedure umlWriteComponent(stream: TCore_Stream; comp: TCore_Component); { Write a component to a stream. }
procedure umlCopyComponentDataTo(comp, copyto: TCore_Component); { Copy data from one component to another of the same class. }

function umlProcessCycleValue(CurrentVal, DeltaVal, StartVal, OverVal: Single; var EndFlag: Boolean): Single; { Compute a cyclic value that oscillates between StartVal and OverVal. }

{ CSV utilities }
type
  TCSVGetLine_C = procedure(var L: TPascalString; var IsEnd: Boolean);
  TCSVSave_C = procedure(const sour: TPascalString; const king, Data: TArrayPascalString);
  TCSVGetLine_M = procedure(var L: TPascalString; var IsEnd: Boolean) of object;
  TCSVSave_M = procedure(const sour: TPascalString; const king, Data: TArrayPascalString) of object;
{$IFDEF FPC}
  TCSVGetLine_P = procedure(var L: TPascalString; var IsEnd: Boolean) is nested;
  TCSVSave_P = procedure(const sour: TPascalString; const king, Data: TArrayPascalString) is nested;
{$ELSE FPC}
  TCSVGetLine_P = reference to procedure(var L: TPascalString; var IsEnd: Boolean);
  TCSVSave_P = reference to procedure(const sour: TPascalString; const king, Data: TArrayPascalString);
{$ENDIF FPC}
procedure ImportCSV_C(const sour: TArrayPascalString; OnNotify: TCSVSave_C); { Import CSV from an array of strings, using a C-style callback. }
procedure CustomImportCSV_C(const OnGetLine: TCSVGetLine_C; OnNotify: TCSVSave_C); { Custom CSV import with a line-reading callback (C). }
procedure ImportCSV_M(const sour: TArrayPascalString; OnNotify: TCSVSave_M); { Import CSV with a method callback. }
procedure CustomImportCSV_M(const OnGetLine: TCSVGetLine_M; OnNotify: TCSVSave_M); { Custom CSV import with method line reader. }
procedure ImportCSV_P(const sour: TArrayPascalString; OnNotify: TCSVSave_P); { Import CSV with a nested/reference callback. }
procedure CustomImportCSV_P(const OnGetLine: TCSVGetLine_P; OnNotify: TCSVSave_P); { Custom CSV import with nested/reference line reader. }

{ Dynamic library loading }
function GetExtLib(LibName: SystemString): HMODULE; { Load a dynamic library by name (cached). }
function FreeExtLib(LibName: SystemString): Boolean; { Unload a dynamic library (removes from cache). }
function GetExtProc(const LibName, ProcName: SystemString): Pointer; { Get a procedure address from a library (cached). }

{ Raw byte array utilities }
type
  TArrayRawByte = array [0 .. MaxInt - 1] of Byte;
  PArrayRawByte = ^TArrayRawByte;
function umlCompareByteString(const s1: TPascalString; const s2: PArrayRawByte): Boolean; overload; { Compare a Pascal string with a raw byte array. }
function umlCompareByteString(const s2: PArrayRawByte; const s1: TPascalString): Boolean; overload; { Compare raw byte array with Pascal string. }
procedure umlSetByteString(const sour: TPascalString; const dest: PArrayRawByte); overload; { Copy a Pascal string to a raw byte array. }
procedure umlSetByteString(const dest: PArrayRawByte; const sour: TPascalString); overload; { Copy raw byte array to Pascal string. }
function umlGetByteString(const sour: PArrayRawByte; const L: Integer): TPascalString; { Read a Pascal string from a raw byte array of given length. }

{ Save memory to file }
procedure SaveMemory(p: Pointer; siz: NativeInt; DestFile: TPascalString); { Save a memory buffer to a file. }

{ Binary string conversions }
function umlBinToUInt8(Value: U_String): Byte; { Convert a binary string (e.g., '1010') to a Byte. }
function umlBinToUInt16(Value: U_String): Word; { Convert binary string to Word. }
function umlBinToUInt32(Value: U_String): Cardinal; { Convert binary string to Cardinal. }
function umlBinToUInt64(Value: U_String): UInt64; { Convert binary string to UInt64. }
function umlUInt8ToBin(v: Byte): U_String; { Convert a Byte to its binary string representation. }
function umlUInt16ToBin(v: Word): U_String; { Convert Word to binary string. }
function umlUInt32ToBin(v: Cardinal): U_String; { Convert Cardinal to binary string. }
function umlUInt64ToBin(v: UInt64): U_String; { Convert UInt64 to binary string. }

{ ASCII detection }
function umlBufferIsASCII(buffer: Pointer; siz: NativeUInt): Boolean; { Check if a memory buffer contains only ASCII characters (0..127). }

var
  Lib_DateTimeFormatSettings: TFormatSettings; { Global format settings used for date/time conversions (ISO-like). }

implementation

uses
{$IF Defined(WIN32) or Defined(WIN64)}
  Z.md5,
{$ENDIF}
  Z.Cipher, Z.Status, Z.FragmentBuffer, Z.Json, Z.HashList.Templet;

procedure TReliableFileStream.InitIO;
begin
  if not FActivted then
      exit;

  DoStatus(PFormat('Reliable IO Open : %s', [umlGetFileName(FileName).text]));
  DoStatus(PFormat('Create Backup %s size: %s', [umlGetFileName(FileName).text, umlSizeToStr(FSource_IO.Size).text]));

  FBackup_IO := TCore_FileStream.Create(Backup_FileName, fmCreate);
  FBackup_IO.Size := FSource_IO.Size;
  FSource_IO.Position := 0;
  FBackup_IO.Position := 0;
  FBackup_IO.CopyFrom(FSource_IO, FSource_IO.Size);
  FBackup_IO.Position := 0;
  DisposeObject(FSource_IO);
  FSource_IO := nil;
end;

procedure TReliableFileStream.FreeIO;
begin
  if not FActivted then
      exit;

  DisposeObject(FBackup_IO);
  FBackup_IO := nil;
  try
    umlDeleteFile(FFileName);
    umlRenameFile(Backup_FileName, FileName);
  except
  end;
  DoStatus(PFormat('Reliable IO Close : %s', [umlGetFileName(FileName).text]));
end;

procedure TReliableFileStream.SetSize(const NewSize: Int64);
begin
  FSource_IO.Size := NewSize;
end;

procedure TReliableFileStream.SetSize(NewSize: longint);
begin
  SetSize(Int64(NewSize));
end;

constructor TReliableFileStream.Create(const FileName_: SystemString; IsNew_, IsWrite_: Boolean);
var
  M: Word;
begin
  inherited Create;
  if IsNew_ then
      M := fmCreate
  else if IsWrite_ then
      M := fmOpenReadWrite
  else
      M := fmOpenRead or fmShareDenyNone;
{$IFDEF ZDB_BACKUP}
  FActivted := IsNew_ or IsWrite_;
{$ELSE ZDB_BACKUP}
  FActivted := False;
{$ENDIF ZDB_BACKUP}
  FSource_IO := TCore_FileStream.Create(FileName_, M);

  FBackup_IO := nil;
  FFileName := FileName_;
  Backup_FileName := FileName_ + '.save';
  umlDeleteFile(Backup_FileName);
  InitIO;
end;

destructor TReliableFileStream.Destroy;
begin
  DisposeObject(FSource_IO);
  FreeIO;
  inherited Destroy;
end;

function TReliableFileStream.Write(const buffer; Count: longint): longint;
begin
  if FActivted then
    begin
      Result := FBackup_IO.Write(buffer, Count);
    end
  else
    begin
      Result := FSource_IO.Write(buffer, Count);
    end;
end;

function TReliableFileStream.Read(var buffer; Count: longint): longint;
begin
  if FActivted then
    begin
      Result := FBackup_IO.Read(buffer, Count);
    end
  else
    begin
      Result := FSource_IO.Read(buffer, Count);
    end;
end;

function TReliableFileStream.Seek(const Offset: Int64; origin: TSeekOrigin): Int64;
begin
  if FActivted then
    begin
      Result := FBackup_IO.Seek(Offset, origin);
    end
  else
    begin
      Result := FSource_IO.Seek(Offset, origin);
    end;
end;

function TIOHnd.FixedString2Pascal(S: TBytes): TPascalString;
var
  buff: TBytes;
begin
  if (length(S) > 0) and (S[0] > 0) then
    begin
      SetLength(buff, S[0]);
      CopyPtr(@S[1], @buff[0], length(buff));
      Result.Bytes := buff;
      SetLength(buff, 0);
    end
  else
      Result := '';
end;

procedure TIOHnd.Pascal2FixedString(var n: TPascalString; var out_: TBytes);
var
  buff: TBytes;
begin
  while True do
    begin
      buff := n.Bytes;
      if length(buff) > FixedStringL - 1 then
          n.DeleteLast
      else
          break;
    end;

  SetLength(out_, FixedStringL);
  out_[0] := length(buff);
  if out_[0] > 0 then
      CopyPtr(@buff[0], @out_[1], out_[0]);
  SetLength(buff, 0);
end;

function TIOHnd.CheckFixedStringLoss(S: TPascalString): Boolean;
var
  buff: TBytes;
begin
  buff := S.Bytes;
  Result := length(buff) > FixedStringL - 1;
  SetLength(buff, 0);
end;

procedure TListPascalString_Helper_.FillToArry(var Output_: U_StringArray);
var
  i: Integer;
begin
  SetLength(Output_, Count);
  for i := 0 to Count - 1 do
      Output_[i] := Items[i];
end;

procedure TListPascalString_Helper_.InputArray(arry: U_StringArray);
var
  i: Integer;
begin
  for i := low(arry) to high(arry) do
      add(arry[i]);
end;

procedure TListPascalString_Helper_.Add_Arry(arry: U_StringArray);
var
  i: Integer;
begin
  for i := low(arry) to high(arry) do
      add(arry[i]);
end;

procedure TStringBigList_Helper_.FillToArry(var Output_: U_StringArray);
begin
  SetLength(Output_, Num);
  if Num > 0 then
    with repeat_ do
      repeat
          Output_[I__] := Queue^.Data;
      until not Next;
end;

procedure TStringBigList_Helper_.InputArray(arry: U_StringArray);
var
  i: Integer;
begin
  for i := low(arry) to high(arry) do
      add(arry[i]);
end;

procedure TStringBigList_Helper_.Add_Arry(arry: U_StringArray);
var
  i: Integer;
begin
  for i := low(arry) to high(arry) do
      add(arry[i]);
end;

function umlBytesOf(const S: TPascalString): TBytes;
begin
  Result := S.Bytes
end;

function umlStringOf(const S: TBytes): TPascalString;
begin
  Result.Bytes := S;
end;

function umlNewString(const S: TPascalString): PPascalString;
var
  p: PPascalString;
begin
  new(p);
  p^ := S;
  Result := p;
end;

procedure umlFreeString(const p: PPascalString);
begin
  if p <> nil then
    begin
      p^ := '';
      Dispose(p);
    end;
end;

function umlComparePosStr(const S: TPascalString; Offset: Integer; const t: TPascalString): Boolean;
begin
  Result := S.ComparePos(Offset, @t);
end;

function umlPos(const SubStr, S: TPascalString; const Offset: Integer = 1): Integer;
begin
  Result := S.GetPos(SubStr, Offset);
end;

function umlVarToStr(const v: Variant; const Base64Conver: Boolean): TPascalString; overload;
var
  n, b64: TPascalString;
begin
  try
    case VarType(v) of
      varSmallInt, varInteger, varShortInt, varByte, varWord, varLongWord: Result := IntToStr(v);
      varInt64: Result := IntToStr(Int64(v));
      varUInt64: {$IFDEF FPC} Result := IntToStr(UInt64(v)); {$ELSE} Result := UIntToStr(UInt64(v)); {$ENDIF}
      varSingle, varDouble, varCurrency, varDate: Result := FloatToStr(v);
      varOleStr, varString, varUString:
        begin
          n.text := VarToStr(v);

          if Base64Conver and umlExistsChar(n, #10#13#9#8#0) then
            begin
              umlEncodeLineBASE64(n, b64);
              Result := '___base64:' + b64.text;
            end
          else
              Result := n.text;
        end;
      varBoolean: Result := umlBoolToStr(v);
      else
          Result := VarToStr(v);
    end;
  except
    try
        Result := VarToStr(v);
    except
        Result := '';
    end;
  end;
end;

function umlVarToStr(const v: Variant): TPascalString;
begin
  Result := umlVarToStr(v, True);
end;

function umlStrToVar(const S: TPascalString): Variant;
var
  b64: TPascalString;
begin
  if S.Exists([#10, #13, #9, #8, #0]) then
    begin
      umlEncodeLineBASE64(S, b64);
      Result := '___base64:' + b64.text;
    end
  else
      Result := S.text;
end;

function umlMax(const v1, v2: UInt64): UInt64;
begin
  if v1 > v2 then
      Result := v1
  else
      Result := v2;
end;

function umlMax(const v1, v2: Cardinal): Cardinal;
begin
  if v1 > v2 then
      Result := v1
  else
      Result := v2;
end;

function umlMax(const v1, v2: Word): Word;
begin
  if v1 > v2 then
      Result := v1
  else
      Result := v2;
end;

function umlMax(const v1, v2: Byte): Byte;
begin
  if v1 > v2 then
      Result := v1
  else
      Result := v2;
end;

function umlMax(const v1, v2: Int64): Int64;
begin
  if v1 > v2 then
      Result := v1
  else
      Result := v2;
end;

function umlMax(const v1, v2: Integer): Integer;
begin
  if v1 > v2 then
      Result := v1
  else
      Result := v2;
end;

function umlMax(const v1, v2: SmallInt): SmallInt;
begin
  if v1 > v2 then
      Result := v1
  else
      Result := v2;
end;

function umlMax(const v1, v2: ShortInt): ShortInt;
begin
  if v1 > v2 then
      Result := v1
  else
      Result := v2;
end;

function umlMax(const v1, v2: Double): Double;
begin
  if v1 > v2 then
      Result := v1
  else
      Result := v2;
end;

function umlMax(const v1, v2: Single): Single;
begin
  if v1 > v2 then
      Result := v1
  else
      Result := v2;
end;

function umlMax(const v1, v2: UInt128): UInt128;
begin
  if v1 > v2 then
      Result := v1
  else
      Result := v2;
end;

function umlMax(const v1, v2: Int128): Int128;
begin
  if v1 > v2 then
      Result := v1
  else
      Result := v2;
end;

function umlMin(const v1, v2: UInt64): UInt64;
begin
  if v1 < v2 then
      Result := v1
  else
      Result := v2;
end;

function umlMin(const v1, v2: Cardinal): Cardinal;
begin
  if v1 < v2 then
      Result := v1
  else
      Result := v2;
end;

function umlMin(const v1, v2: Word): Word;
begin
  if v1 < v2 then
      Result := v1
  else
      Result := v2;
end;

function umlMin(const v1, v2: Byte): Byte;
begin
  if v1 < v2 then
      Result := v1
  else
      Result := v2;
end;

function umlMin(const v1, v2: Int64): Int64;
begin
  if v1 < v2 then
      Result := v1
  else
      Result := v2;
end;

function umlMin(const v1, v2: Integer): Integer;
begin
  if v1 < v2 then
      Result := v1
  else
      Result := v2;
end;

function umlMin(const v1, v2: SmallInt): SmallInt;
begin
  if v1 < v2 then
      Result := v1
  else
      Result := v2;
end;

function umlMin(const v1, v2: ShortInt): ShortInt;
begin
  if v1 < v2 then
      Result := v1
  else
      Result := v2;
end;

function umlMin(const v1, v2: Double): Double;
begin
  if v1 < v2 then
      Result := v1
  else
      Result := v2;
end;

function umlMin(const v1, v2: Single): Single;
begin
  if v1 < v2 then
      Result := v1
  else
      Result := v2;
end;

function umlMin(const v1, v2: UInt128): UInt128;
begin
  if v1 < v2 then
      Result := v1
  else
      Result := v2;
end;

function umlMin(const v1, v2: Int128): Int128;
begin
  if v1 < v2 then
      Result := v1
  else
      Result := v2;
end;

function umlClamp(const v, min_, max_: Integer): Integer;
begin
  if min_ > max_ then
      Result := umlClamp(v, max_, min_)
  else if v > max_ then
      Result := max_
  else if v < min_ then
      Result := min_
  else
      Result := v;
end;

function umlClamp(const v, min_, max_: UInt64): UInt64;
begin
  if min_ > max_ then
      Result := umlClamp(v, max_, min_)
  else if v > max_ then
      Result := max_
  else if v < min_ then
      Result := min_
  else
      Result := v;
end;

function umlClamp(const v, min_, max_: Cardinal): Cardinal;
begin
  if min_ > max_ then
      Result := umlClamp(v, max_, min_)
  else if v > max_ then
      Result := max_
  else if v < min_ then
      Result := min_
  else
      Result := v;
end;

function umlClamp(const v, min_, max_: Word): Word;
begin
  if min_ > max_ then
      Result := umlClamp(v, max_, min_)
  else if v > max_ then
      Result := max_
  else if v < min_ then
      Result := min_
  else
      Result := v;
end;

function umlClamp(const v, min_, max_: Byte): Byte;
begin
  if min_ > max_ then
      Result := umlClamp(v, max_, min_)
  else if v > max_ then
      Result := max_
  else if v < min_ then
      Result := min_
  else
      Result := v;
end;

function umlClamp(const v, min_, max_: Int64): Int64;
begin
  if min_ > max_ then
      Result := umlClamp(v, max_, min_)
  else if v > max_ then
      Result := max_
  else if v < min_ then
      Result := min_
  else
      Result := v;
end;

function umlClamp(const v, min_, max_: SmallInt): SmallInt;
begin
  if min_ > max_ then
      Result := umlClamp(v, max_, min_)
  else if v > max_ then
      Result := max_
  else if v < min_ then
      Result := min_
  else
      Result := v;
end;

function umlClamp(const v, min_, max_: ShortInt): ShortInt;
begin
  if min_ > max_ then
      Result := umlClamp(v, max_, min_)
  else if v > max_ then
      Result := max_
  else if v < min_ then
      Result := min_
  else
      Result := v;
end;

function umlClamp(const v, min_, max_: Double): Double;
begin
  if min_ > max_ then
      Result := umlClamp(v, max_, min_)
  else if v > max_ then
      Result := max_
  else if v < min_ then
      Result := min_
  else
      Result := v;
end;

function umlClamp(const v, min_, max_: Single): Single;
begin
  if min_ > max_ then
      Result := umlClamp(v, max_, min_)
  else if v > max_ then
      Result := max_
  else if v < min_ then
      Result := min_
  else
      Result := v;
end;

function umlClamp(const v, min_, max_: UInt128): UInt128;
begin
  if min_ > max_ then
      Result := umlClamp(v, max_, min_)
  else if v > max_ then
      Result := max_
  else if v < min_ then
      Result := min_
  else
      Result := v;
end;

function umlClamp(const v, min_, max_: Int128): Int128;
begin
  if min_ > max_ then
      Result := umlClamp(v, max_, min_)
  else if v > max_ then
      Result := max_
  else if v < min_ then
      Result := min_
  else
      Result := v;
end;

function umlInRange(const v, min_, max_: Integer): Boolean;
begin
  Result := (v >= umlMin(min_, max_)) and (v <= umlMax(min_, max_));
end;

function umlInRange(const v, min_, max_: UInt64): Boolean;
begin
  Result := (v >= umlMin(min_, max_)) and (v <= umlMax(min_, max_));
end;

function umlInRange(const v, min_, max_: Cardinal): Boolean;
begin
  Result := (v >= umlMin(min_, max_)) and (v <= umlMax(min_, max_));
end;

function umlInRange(const v, min_, max_: Word): Boolean;
begin
  Result := (v >= umlMin(min_, max_)) and (v <= umlMax(min_, max_));
end;

function umlInRange(const v, min_, max_: Byte): Boolean;
begin
  Result := (v >= umlMin(min_, max_)) and (v <= umlMax(min_, max_));
end;

function umlInRange(const v, min_, max_: Int64): Boolean;
begin
  Result := (v >= umlMin(min_, max_)) and (v <= umlMax(min_, max_));
end;

function umlInRange(const v, min_, max_: SmallInt): Boolean;
begin
  Result := (v >= umlMin(min_, max_)) and (v <= umlMax(min_, max_));
end;

function umlInRange(const v, min_, max_: ShortInt): Boolean;
begin
  Result := (v >= umlMin(min_, max_)) and (v <= umlMax(min_, max_));
end;

function umlInRange(const v, min_, max_: Double): Boolean;
begin
  Result := (v >= umlMin(min_, max_)) and (v <= umlMax(min_, max_));
end;

function umlInRange(const v, min_, max_: Single): Boolean;
begin
  Result := (v >= umlMin(min_, max_)) and (v <= umlMax(min_, max_));
end;

function umlInRange(const v, min_, max_: UInt128): Boolean;
begin
  Result := (v >= umlMin(min_, max_)) and (v <= umlMax(min_, max_));
end;

function umlInRange(const v, min_, max_: Int128): Boolean;
begin
  Result := (v >= umlMin(min_, max_)) and (v <= umlMax(min_, max_));
end;

function umlCompareText(s1, s2: TPascalString): Integer;
  function comp_size(const A, B: Integer): Integer;
  begin
    if A = B then
        Result := 0
    else if A < B then
        Result := -1
    else
        Result := 1;
  end;

  function IsWide_(p: PPascalString): Byte;
  var
    C: SystemChar;
  begin
    for C in p^.buff do
      if Ord(C) > 127 then
          exit(1);
    Result := 0;
  end;

begin
  Result := comp_size(IsWide_(@s1), IsWide_(@s2));
  if Result = 0 then
    begin
      Result := comp_size(s1.L, s2.L);
      if Result = 0 then
          Result := CompareText(s1, s2);
    end;
end;

function umlGetResourceStream(const FileName: TPascalString): TCore_Stream;
var
  n: TPascalString;
begin
  if FileName.Exists('.') then
      n := umlDeleteLastStr(FileName, '.')
  else
      n := FileName;

  Result := TCore_ResourceStream.Create(HInstance, n.text, RT_RCDATA);
end;

function umlSameVarValue(const v1, v2: Variant): Boolean;
begin
  try
      Result := VarSameValue(v1, v2);
  except
      Result := False;
  end;
end;

function umlSameVariant(const v1, v2: Variant): Boolean;
begin
  try
      Result := VarSameValue(v1, v2);
  except
      Result := False;
  end;
end;

function umlRandom(const rnd: TMT19937Random): Integer;
begin
  Result := rnd.Rand32(MaxInt);
end;

function umlRandom: Integer;
begin
  Result := MT19937Rand32(MaxInt);
end;

function umlRandomRange(const rnd: TMT19937Random; const min_, max_: Integer): Integer;
begin
  Result := TMT19937.RandomRange(rnd, min_, max_);
end;

function umlRandomRange64(const rnd: TMT19937Random; const min_, max_: Int64): Int64;
begin
  Result := TMT19937.RandomRange64(rnd, min_, max_);
end;

function umlRandomRangeS(const rnd: TMT19937Random; const min_, max_: Single): Single;
begin
  Result := TMT19937.RandomRangeS(rnd, min_, max_);
end;

function umlRandomRangeD(const rnd: TMT19937Random; const min_, max_: Double): Double;
begin
  Result := TMT19937.RandomRangeD(rnd, min_, max_);
end;

function umlRandomRangeF(const rnd: TMT19937Random; const min_, max_: Double): Double;
begin
  Result := TMT19937.RandomRangeF(rnd, min_, max_);
end;

function umlRandomRange(const min_, max_: Integer): Integer;
begin
  Result := TMT19937.RandomRange(min_, max_);
end;

function umlRandomRange64(const min_, max_: Int64): Int64;
begin
  Result := TMT19937.RandomRange64(min_, max_);
end;

function umlRandomRangeS(const min_, max_: Single): Single;
begin
  Result := TMT19937.RandomRangeS(min_, max_);
end;

function umlRandomRangeD(const min_, max_: Double): Double;
begin
  Result := TMT19937.RandomRangeD(min_, max_);
end;

function umlRandomRangeF(const min_, max_: Double): Double;
begin
  Result := TMT19937.RandomRangeF(min_, max_);
end;

function umlRR(const rnd: TMT19937Random; const min_, max_: Integer): Integer;
begin
  Result := TMT19937.RR(rnd, min_, max_);
end;

function umlRR64(const rnd: TMT19937Random; const min_, max_: Int64): Int64;
begin
  Result := TMT19937.RR64(rnd, min_, max_);
end;

function umlRRS(const rnd: TMT19937Random; const min_, max_: Single): Single;
begin
  Result := TMT19937.RRS(rnd, min_, max_);
end;

function umlRRD(const rnd: TMT19937Random; const min_, max_: Double): Double;
begin
  Result := TMT19937.RRD(rnd, min_, max_);
end;

function umlRRF(const rnd: TMT19937Random; const min_, max_: Double): Double;
begin
  Result := TMT19937.RRF(rnd, min_, max_);
end;

function umlRR(const min_, max_: Integer): Integer;
begin
  Result := TMT19937.RR(min_, max_);
end;

function umlRR64(const min_, max_: Int64): Int64;
begin
  Result := TMT19937.RR64(min_, max_);
end;

function umlRRS(const min_, max_: Single): Single;
begin
  Result := TMT19937.RRS(min_, max_);
end;

function umlRRD(const min_, max_: Double): Double;
begin
  Result := TMT19937.RRD(min_, max_);
end;

function umlRRF(const min_, max_: Double): Double;
begin
  Result := TMT19937.RRF(min_, max_);
end;

function umlDefaultTime: Double;
begin
  Result := Now;
end;

function umlNow: Double;
begin
  Result := Now();
end;

function umlTime: Double;
begin
  Result := Time();
end;

function umlDate: Double;
begin
  Result := Date();
end;

function umlDefaultAttrib: Integer;
begin
  Result := 0;
end;

function umlBoolToStr(const Value: Boolean): TPascalString;
begin
  if Value then
      Result := 'True'
  else
      Result := 'False';
end;

function umlStrToBool(const Value: TPascalString; Default_: Boolean): Boolean;
var
  NewValue: TPascalString;
begin
  NewValue := umlTrimSpace(Value);
  if NewValue.Same('Yes', 'ON') then
      Result := True
  else if NewValue.Same('No', 'OFF') then
      Result := False
  else if NewValue.Same('True') then
      Result := True
  else if NewValue.Same('False') then
      Result := False
  else if NewValue.Same('1') then
      Result := True
  else if NewValue.Same('0') then
      Result := False
  else
      Result := Default_;
end;

function umlStrToBool(const Value: TPascalString): Boolean;
begin
  Result := umlStrToBool(Value, False);
end;

function umlFileExists(const FileName: TPascalString): Boolean;
begin
  if FileName.L > 0 then
      Result := FileExists(FileName.text)
  else
      Result := False;
end;

function umlDirectoryExists(const DirectoryName: TPascalString): Boolean;
begin
  if DirectoryName.L > 0 then
      Result := DirectoryExists(DirectoryName.text)
  else
      Result := False;
end;

function umlCreateDirectory(const DirectoryName: TPascalString): Boolean;
begin
  Result := umlDirectoryExists(DirectoryName);
  if Result then
      exit;

  try
      Result := ForceDirectories(DirectoryName.text);
  except
    try
        Result := CreateDir(DirectoryName.text);
    except
        Result := False;
    end;
  end;
end;

function umlCurrentDirectory: TPascalString;
begin
  Result.text := GetCurrentDir;
end;

function umlCurrentPath: TPascalString;
begin
  Result.text := GetCurrentDir;
  case CurrentPlatform of
    epWin32, epWin64: if (Result.L = 0) or (Result.Last <> '\') then
          Result := Result.text + '\';
    else
      if (Result.L = 0) or (Result.Last <> '/') then
          Result := Result.text + '/';
  end;
end;

function umlGetCurrentPath: TPascalString;
begin
  Result := umlCurrentPath();
end;

procedure umlSetCurrentPath(ph: TPascalString);
begin
  SetCurrentDir(ph.text);
end;

function umlFindFirstFile(const FileName: TPascalString; var SR: TSR): Boolean;
label SearchPoint;
begin
  if FindFirst(FileName.text, faAnyFile, SR) <> 0 then
    begin
      Result := False;
      exit;
    end;
  if ((SR.Attr and faDirectory) <> faDirectory) then
    begin
      Result := True;
      exit;
    end;
SearchPoint:
  if FindNext(SR) <> 0 then
    begin
      Result := False;
      exit;
    end;
  if ((SR.Attr and faDirectory) <> faDirectory) then
    begin
      Result := True;
      exit;
    end;
  goto SearchPoint;
end;

function umlFindNextFile(var SR: TSR): Boolean;
label SearchPoint;
begin
SearchPoint:
  if FindNext(SR) <> 0 then
    begin
      Result := False;
      exit;
    end;
  if ((SR.Attr and faDirectory) <> faDirectory) then
    begin
      Result := True;
      exit;
    end;
  goto SearchPoint;
end;

function umlFindFirstDir(const DirName: TPascalString; var SR: TSR): Boolean;
label SearchPoint;
begin
  if FindFirst(DirName.text, faAnyFile, SR) <> 0 then
    begin
      Result := False;
      exit;
    end;
  if ((SR.Attr and faDirectory) = faDirectory) and (SR.Name <> '.') and (SR.Name <> '..') then
    begin
      Result := True;
      exit;
    end;
SearchPoint:
  if FindNext(SR) <> 0 then
    begin
      Result := False;
      exit;
    end;
  if ((SR.Attr and faDirectory) = faDirectory) and (SR.Name <> '.') and (SR.Name <> '..') then
    begin
      Result := True;
      exit;
    end;
  goto SearchPoint;
end;

function umlFindNextDir(var SR: TSR): Boolean;
label SearchPoint;
begin
SearchPoint:
  if FindNext(SR) <> 0 then
    begin
      Result := False;
      exit;
    end;
  if ((SR.Attr and faDirectory) = faDirectory) and (SR.Name <> '.') and (SR.Name <> '..') then
    begin
      Result := True;
      exit;
    end;
  goto SearchPoint;
end;

procedure umlFindClose(var SR: TSR);
begin
  FindClose(SR);
end;

function uml_Get_File_To_List(const FullPath: TPascalString; AsLst: TCore_Strings): Integer;
var
  _SR: TSR;
begin
  Result := 0;
  if umlFindFirstFile(umlCombineFileName(FullPath, '*'), _SR) then
    begin
      repeat
        AsLst.add(_SR.Name);
        inc(Result);
      until not umlFindNextFile(_SR);
    end;
  umlFindClose(_SR);
end;

function uml_Get_Dir_To_List(const FullPath: TPascalString; AsLst: TCore_Strings): Integer;
var
  _SR: TSR;
begin
  Result := 0;
  if umlFindFirstDir(umlCombineFileName(FullPath, '*'), _SR) then
    begin
      repeat
        AsLst.add(_SR.Name);
        inc(Result);
      until not umlFindNextDir(_SR);
    end;
  umlFindClose(_SR);
end;

function uml_Get_File_To_List(const FullPath: TPascalString; AsLst: TPascalStringList): Integer;
var
  _SR: TSR;
begin
  Result := 0;
  if umlFindFirstFile(umlCombineFileName(FullPath, '*'), _SR) then
    begin
      repeat
        AsLst.add(_SR.Name);
        inc(Result);
      until not umlFindNextFile(_SR);
    end;
  umlFindClose(_SR);
end;

function uml_Get_Dir_To_List(const FullPath: TPascalString; AsLst: TPascalStringList): Integer;
var
  _SR: TSR;
begin
  Result := 0;
  if umlFindFirstDir(umlCombineFileName(FullPath, '*'), _SR) then
    begin
      repeat
        AsLst.add(_SR.Name);
        inc(Result);
      until not umlFindNextDir(_SR);
    end;
  umlFindClose(_SR);
end;

function umlGet_File_Full_Array(const FullPath: TPascalString): U_StringArray;
var
  ph: TPascalString;
  L: TPascalStringList;
  i: Integer;
begin
  ph := FullPath;
  L := TPascalStringList.Create;
  uml_Get_File_To_List(FullPath, L);
  SetLength(Result, L.Count);
  for i := 0 to L.Count - 1 do
      Result[i] := umlCombineFileName(ph, L[i]).text;
  DisposeObject(L);
end;

function umlGet_Path_Full_Array(const FullPath: TPascalString): U_StringArray;
var
  ph: TPascalString;
  L: TPascalStringList;
  i: Integer;
begin
  ph := FullPath;
  L := TPascalStringList.Create;
  uml_Get_Dir_To_List(FullPath, L);
  SetLength(Result, L.Count);
  for i := 0 to L.Count - 1 do
      Result[i] := umlCombinePath(ph, L[i]).text;
  DisposeObject(L);
end;

function umlGet_File_Array(const FullPath: TPascalString): U_StringArray;
var
  ph: TPascalString;
  L: TPascalStringList;
  i: Integer;
begin
  ph := FullPath;
  L := TPascalStringList.Create;
  uml_Get_File_To_List(FullPath, L);
  SetLength(Result, L.Count);
  for i := 0 to L.Count - 1 do
      Result[i] := L[i];
  DisposeObject(L);
end;

function umlGet_Path_Array(const FullPath: TPascalString): U_StringArray;
var
  ph: TPascalString;
  L: TPascalStringList;
  i: Integer;
begin
  ph := FullPath;
  L := TPascalStringList.Create;
  uml_Get_Dir_To_List(FullPath, L);
  SetLength(Result, L.Count);
  for i := 0 to L.Count - 1 do
      Result[i] := L[i];
  DisposeObject(L);
end;

function umlFixedPath(S: TPascalString): TPascalString;
begin
  if CurrentPlatform in [epWin32, epWin64] then
    begin
      Result := umlCharReplace(S, '/', '\');
      if Result.Last <> '\' then
          Result.Append('\');
    end
  else
    begin
      Result := umlCharReplace(S, '\', '/');
      if Result.Last <> '/' then
          Result.Append('/');
    end;
end;

function umlCombinePath(const s1, s2: TPascalString): TPascalString;
begin
  if CurrentPlatform in [epWin32, epWin64] then
      Result := umlCombineWinPath(s1, s2)
  else
      Result := umlCombineUnixPath(s1, s2);
end;

function umlCombineFileName(const pathName, FileName: TPascalString): TPascalString;
begin
  if CurrentPlatform in [epWin32, epWin64] then
      Result := umlCombineWinFileName(pathName, FileName)
  else
      Result := umlCombineUnixFileName(pathName, FileName);
end;

function umlCombineUnixPath(const s1, s2: TPascalString): TPascalString;
var
  n1, n2, n: TPascalString;
begin
  n1 := umlTrimSpace(s1);
  n2 := umlTrimSpace(s2);

  n1 := umlCharReplace(n1, '\', '/');
  n2 := umlCharReplace(n2, '\', '/');

  if (n2.L > 0) and (n2.First = '/') then
      n2.DeleteFirst;

  if n1.L > 0 then
    begin
      if n1.Last = '/' then
          Result := n1.text + n2.text
      else
          Result := n1.text + '/' + n2.text;
    end
  else
      Result := n2;

  repeat
    n := Result;
    Result := umlStringReplace(Result, '//', '/', True);
  until Result.Same(n);
  if (Result.L > 0) and (Result.Last <> '/') then
      Result.Append('/');
end;

function umlCombineUnixFileName(const pathName, FileName: TPascalString): TPascalString;
var
  pn, fn, n: TPascalString;
begin
  pn := umlTrimSpace(pathName);
  fn := umlTrimSpace(FileName);

  pn := umlCharReplace(pn, '\', '/');
  fn := umlCharReplace(fn, '\', '/');

  if (fn.L > 0) and (fn.First = '/') then
      fn.DeleteFirst;
  if (fn.L > 0) and (fn.Last = '/') then
      fn.DeleteLast;

  if pn.L > 0 then
    begin
      if pn.Last = '/' then
          Result := pn.text + fn.text
      else
          Result := pn.text + '/' + fn.text;
    end
  else
      Result := fn;

  repeat
    n := Result;
    Result := umlStringReplace(Result, '//', '/', True);
  until Result.Same(n);
end;

function umlCombineWinPath(const s1, s2: TPascalString): TPascalString;
var
  n1, n2, n: TPascalString;
begin
  n1 := umlTrimSpace(s1);
  n2 := umlTrimSpace(s2);

  n1 := umlCharReplace(n1, '/', '\');
  n2 := umlCharReplace(n2, '/', '\');

  if (n2.L > 0) and (n2.First = '\') then
      n2.DeleteFirst;

  if n1.L > 0 then
    begin
      if n1.Last = '\' then
          Result := n1.text + n2.text
      else
          Result := n1.text + '\' + n2.text;
    end
  else
      Result := n2;

  repeat
    n := Result;
    Result := umlStringReplace(Result, '\\', '\', True);
  until Result.Same(n);
  if (Result.L > 0) and (Result.Last <> '\') then
      Result.Append('\');
end;

function umlCombineWinFileName(const pathName, FileName: TPascalString): TPascalString;
var
  pn, fn, n: TPascalString;
begin
  pn := umlTrimSpace(pathName);
  fn := umlTrimSpace(FileName);

  pn := umlCharReplace(pn, '/', '\');
  fn := umlCharReplace(fn, '/', '\');

  if (fn.L > 0) and (fn.First = '\') then
      fn.DeleteFirst;
  if (fn.L > 0) and (fn.Last = '\') then
      fn.DeleteLast;

  if pn.L > 0 then
    begin
      if pn.Last = '\' then
          Result := pn.text + fn.text
      else
          Result := pn.text + '\' + fn.text;
    end
  else
      Result := fn;

  repeat
    n := Result;
    Result := umlStringReplace(Result, '\\', '\', True);
  until Result.Same(n);

  if Result.Last = '\' then
      Result.DeleteLast;
end;

function umlGetFileName(platform_: TExecutePlatform; const S: TPascalString): TPascalString;
var
  n: TPascalString;
begin
  case platform_ of
    epWin32, epWin64:
      begin
        n := umlCharReplace(umlTrimSpace(S), '/', '\');
        if n.L = 0 then
            Result := ''
        else if (n.Last = '\') then
            Result := ''
        else if n.Exists('\') then
            Result := umlGetLastStr(n, '\')
        else
            Result := n;
      end;
    else
      begin
        n := umlCharReplace(umlTrimSpace(S), '\', '/');
        if n.L = 0 then
            Result := ''
        else if (n.Last = '/') then
            Result := ''
        else if n.Exists('/') then
            Result := umlGetLastStr(n, '/')
        else
            Result := n;
      end;
  end;
end;

function umlGetFileName(const S: TPascalString): TPascalString;
begin
  Result := umlGetFileName(CurrentPlatform, S);
end;

function umlGetWindowsFileName(const S: TPascalString): TPascalString;
var
  n: TPascalString;
begin
  n := umlCharReplace(umlTrimSpace(S), '/', '\');
  if n.L = 0 then
      Result := ''
  else if (n.Last = '\') then
      Result := ''
  else if n.Exists('\') then
      Result := umlGetLastStr(n, '\')
  else
      Result := n;
end;

function umlGetUnixFileName(const S: TPascalString): TPascalString;
var
  n: TPascalString;
begin
  n := umlCharReplace(umlTrimSpace(S), '\', '/');
  if n.L = 0 then
      Result := ''
  else if (n.Last = '/') then
      Result := ''
  else if n.Exists('/') then
      Result := umlGetLastStr(n, '/')
  else
      Result := n;
end;

function umlGetFilePath(platform_: TExecutePlatform; const S: TPascalString): TPascalString;
var
  n: TPascalString;
begin
  case platform_ of
    epWin32, epWin64:
      begin
        n := umlCharReplace(umlTrimSpace(S), '/', '\');
        if n.L = 0 then
            Result := ''
        else if not n.Exists('\') then
            Result := ''
        else if (n.Last <> '\') then
            Result := umlDeleteLastStr(n, '\')
        else
            Result := n;
        if umlMultipleMatch('?:', Result) then
            Result.Append('\');
      end;
    else
      begin
        n := umlCharReplace(umlTrimSpace(S), '\', '/');
        if n.L = 0 then
            Result := ''
        else if not n.Exists('/') then
            Result := ''
        else if (n.Last <> '/') then
            Result := umlDeleteLastStr(n, '/')
        else
            Result := n;
      end;
  end;
end;

function umlGetFilePath(const S: TPascalString): TPascalString;
begin
  Result := umlGetFilePath(CurrentPlatform, S);
end;

function umlGetWindowsFilePath(const S: TPascalString): TPascalString;
var
  n: TPascalString;
begin
  n := umlCharReplace(umlTrimSpace(S), '/', '\');
  if n.L = 0 then
      Result := ''
  else if not n.Exists('\') then
      Result := ''
  else if (n.Last <> '\') then
      Result := umlDeleteLastStr(n, '\')
  else
      Result := n;
  if umlMultipleMatch('?:', Result) then
      Result.Append('\');
end;

function umlGetUnixFilePath(const S: TPascalString): TPascalString;
var
  n: TPascalString;
begin
  n := umlCharReplace(umlTrimSpace(S), '\', '/');
  if n.L = 0 then
      Result := ''
  else if not n.Exists('/') then
      Result := ''
  else if (n.Last <> '/') then
      Result := umlDeleteLastStr(n, '/')
  else
      Result := n;
end;

function umlChangeFileExt(const S, ext: TPascalString): TPascalString;
var
  ph, fn: TPascalString;
  n: TPascalString;
begin
  if S.L = 0 then
    begin
      Result := ext;
      exit;
    end;

  ph := umlGetFilePath(S);
  fn := umlGetFileName(S);

  n := ext;
  if (n.L > 0) and (n.First <> '.') then
      n.text := '.' + n.text;
  if umlExistsChar(fn, '.') then
      Result := umlDeleteLastStr(fn, '.') + n
  else
      Result := fn + n;

  if ph.L > 0 then
      Result := umlCombineFileName(ph, Result);
end;

function umlGetFileExt(const S: TPascalString): TPascalString;
begin
  if (S.L > 0) and (umlExistsChar(S, '.')) then
      Result := '.' + umlGetLastStr(S, '.')
  else
      Result := '';
end;

procedure InitIOHnd(var IOHnd: TIOHnd);
begin
  IOHnd.IsOnlyRead := True;
  IOHnd.IsOpen := False;
  IOHnd.AutoFree := False;
  IOHnd.Handle := nil;
  IOHnd.Time := 0;
  IOHnd.Size := 0;
  IOHnd.Position := 0;
  IOHnd.FileName := '';
  IOHnd.Cache.UsedWriteCache := False;
  IOHnd.Cache.PrepareWriteBuff := nil;
  IOHnd.Cache.UsedReadCache := False;
  IOHnd.Cache.PrepareReadPosition := -1;
  IOHnd.Cache.PrepareReadBuff := nil;
  IOHnd.IORead := 0;
  IOHnd.IOWrite := 0;
  IOHnd.ChangeFromWrite := False;
  IOHnd.FixedStringL := 64 + 1;
  IOHnd.Data := nil;
  IOHnd.Return := C_NotError;
end;

function umlFileCreateAsStream(const FileName: TPascalString; stream: U_Stream; var IOHnd: TIOHnd; OnlyRead_: Boolean): Boolean;
begin
  if IOHnd.IsOpen = True then
    begin
      IOHnd.Return := C_FileIsActive;
      Result := False;
      exit;
    end;
  stream.Position := 0;
  IOHnd.Handle := stream;
  IOHnd.Cache.UsedWriteCache := (IOHnd.Handle is TCore_FileStream) or (IOHnd.Handle is TReliableFileStream);
  IOHnd.Cache.UsedReadCache := IOHnd.Cache.UsedWriteCache;
  IOHnd.Return := C_NotError;
  IOHnd.Size := stream.Size;
  IOHnd.Position := stream.Position;
  IOHnd.Time := umlDefaultTime;
  IOHnd.FileName := FileName;
  IOHnd.IsOpen := True;
  IOHnd.IsOnlyRead := OnlyRead_;
  IOHnd.AutoFree := False;
  Result := True;
  if IOHnd.FileName = '' then
    begin
      if IOHnd.Handle is TCore_FileStream then
          IOHnd.FileName := TCore_FileStream(IOHnd.Handle).FileName
      else if IOHnd.Handle is TReliableFileStream then
          IOHnd.FileName := TReliableFileStream(IOHnd.Handle).FileName
      else if IOHnd.Handle is TSafe_Flush_Stream then
          IOHnd.FileName := TSafe_Flush_Stream(IOHnd.Handle).FileName;
    end;
end;

function umlFileCreateAsStream(const FileName: TPascalString; stream: U_Stream; var IOHnd: TIOHnd): Boolean;
begin
  Result := umlFileCreateAsStream(FileName, stream, IOHnd, False);
end;

function umlFileCreateAsStream(stream: U_Stream; var IOHnd: TIOHnd): Boolean;
begin
  Result := umlFileCreateAsStream('', stream, IOHnd, False);
end;

function umlFileCreateAsStream(stream: U_Stream; var IOHnd: TIOHnd; OnlyRead_: Boolean): Boolean;
begin
  Result := umlFileCreateAsStream('', stream, IOHnd, OnlyRead_);
end;

function umlFileOpenAsStream(const FileName: TPascalString; stream: U_Stream; var IOHnd: TIOHnd; OnlyRead_: Boolean): Boolean;
begin
  if IOHnd.IsOpen = True then
    begin
      IOHnd.Return := C_FileIsActive;
      Result := False;
      exit;
    end;
  stream.Position := 0;
  IOHnd.Handle := stream;
  IOHnd.Cache.UsedWriteCache := (IOHnd.Handle is TCore_FileStream) or (IOHnd.Handle is TReliableFileStream);
  IOHnd.Cache.UsedReadCache := IOHnd.Cache.UsedWriteCache;
  IOHnd.Return := C_NotError;
  IOHnd.Size := stream.Size;
  IOHnd.Position := stream.Position;
  IOHnd.Time := umlDefaultTime;
  IOHnd.FileName := FileName;
  IOHnd.IsOpen := True;
  IOHnd.IsOnlyRead := OnlyRead_;
  IOHnd.AutoFree := False;
  Result := True;
  if IOHnd.FileName = '' then
    begin
      if IOHnd.Handle is TCore_FileStream then
          IOHnd.FileName := TCore_FileStream(IOHnd.Handle).FileName
      else if IOHnd.Handle is TReliableFileStream then
          IOHnd.FileName := TReliableFileStream(IOHnd.Handle).FileName
      else if IOHnd.Handle is TSafe_Flush_Stream then
          IOHnd.FileName := TSafe_Flush_Stream(IOHnd.Handle).FileName;
    end;
end;

function umlFileCreateAsMemory(var IOHnd: TIOHnd): Boolean;
begin
  if IOHnd.IsOpen = True then
    begin
      IOHnd.Return := C_FileIsActive;
      Result := False;
      exit;
    end;
  IOHnd.Handle := TMS64.CustomCreate(8192);
  IOHnd.Cache.UsedWriteCache := False;
  IOHnd.Cache.UsedReadCache := False;
  IOHnd.Return := C_NotError;
  IOHnd.Size := IOHnd.Handle.Size;
  IOHnd.Position := IOHnd.Handle.Position;
  IOHnd.Time := umlDefaultTime;
  IOHnd.FileName := 'Memory';
  IOHnd.IsOpen := True;
  IOHnd.IsOnlyRead := False;
  IOHnd.AutoFree := True;
  Result := True;
end;

function umlFileCreate(const FileName: TPascalString; var IOHnd: TIOHnd): Boolean;
begin
  if IOHnd.IsOpen = True then
    begin
      IOHnd.Return := C_FileIsActive;
      Result := False;
      exit;
    end;
  try
      IOHnd.Handle := TReliableFileStream.Create(FileName.text, True, True);
  except
    IOHnd.Handle := nil;
    IOHnd.Return := C_CreateFileError;
    Result := False;
    exit;
  end;
  IOHnd.Cache.UsedWriteCache := True;
  IOHnd.Cache.UsedReadCache := True;
  IOHnd.Return := C_NotError;
  IOHnd.Size := 0;
  IOHnd.Position := 0;
  IOHnd.Time := Now;
  IOHnd.FileName := FileName;
  IOHnd.IsOpen := True;
  IOHnd.IsOnlyRead := False;
  IOHnd.AutoFree := True;
  Result := True;
end;

function umlFileOpen(const FileName: TPascalString; var IOHnd: TIOHnd; OnlyRead_: Boolean): Boolean;
begin
  if IOHnd.IsOpen = True then
    begin
      IOHnd.Return := C_FileIsActive;
      Result := False;
      exit;
    end;
  if not umlFileExists(FileName) then
    begin
      IOHnd.Return := C_NotFindFile;
      Result := False;
      exit;
    end;
  try
      IOHnd.Handle := TReliableFileStream.Create(FileName.text, False, not OnlyRead_);
  except
    IOHnd.Handle := nil;
    IOHnd.Return := C_OpenFileError;
    Result := False;
    exit;
  end;
  IOHnd.Cache.UsedWriteCache := True;
  IOHnd.Cache.UsedReadCache := True;
  IOHnd.IsOnlyRead := OnlyRead_;
  IOHnd.Return := C_NotError;
  IOHnd.Size := IOHnd.Handle.Size;
  IOHnd.Position := 0;
  IOHnd.Time := umlGetFileTime(FileName);
  IOHnd.FileName := FileName;
  IOHnd.IsOpen := True;
  IOHnd.AutoFree := True;
  Result := True;
end;

function umlFileClose(var IOHnd: TIOHnd): Boolean;
begin
  if IOHnd.IsOpen = False then
    begin
      IOHnd.Return := C_NotOpenFile;
      Result := False;
      exit;
    end;
  if IOHnd.Handle = nil then
    begin
      IOHnd.Return := C_FileHandleError;
      Result := False;
      exit;
    end;

  umlFileFlushWriteCache(IOHnd);

  if IOHnd.Cache.PrepareReadBuff <> nil then
      DisposeObject(IOHnd.Cache.PrepareReadBuff);
  IOHnd.Cache.PrepareReadBuff := nil;
  IOHnd.Cache.PrepareReadPosition := -1;

  try
    if IOHnd.AutoFree then
        DisposeObject(IOHnd.Handle)
    else
        IOHnd.Handle := nil;
  except
  end;
  IOHnd.Handle := nil;
  IOHnd.Return := C_NotError;
  IOHnd.Time := umlDefaultTime;
  IOHnd.FileName := '';
  IOHnd.IsOpen := False;
  IOHnd.ChangeFromWrite := False;
  Result := True;
end;

function umlFileUpdate(var IOHnd: TIOHnd): Boolean;
begin
  if (IOHnd.IsOpen = False) or (IOHnd.Handle = nil) then
    begin
      IOHnd.Return := C_FileHandleError;
      Result := False;
      exit;
    end;

  umlFileFlushWriteCache(IOHnd);
  umlResetPrepareRead(IOHnd);

  if IOHnd.Handle is TSafe_Flush_Stream then
      TSafe_Flush_Stream(IOHnd.Handle).Flush
  else if IOHnd.Handle is TCore_FileStream then
    begin
{$IFDEF MSWINDOWS}
      FlushFileBuffers(TCore_FileStream(IOHnd.Handle).Handle);
{$ENDIF MSWINDOWS}
    end;

  IOHnd.ChangeFromWrite := False;
  Result := True;
end;

function umlFileTest(var IOHnd: TIOHnd): Boolean;
begin
  if (IOHnd.IsOpen = False) or (IOHnd.Handle = nil) then
    begin
      IOHnd.Return := C_FileHandleError;
      Result := False;
      exit;
    end;
  IOHnd.Return := C_NotError;
  Result := True;
end;

procedure umlResetPrepareRead(var IOHnd: TIOHnd);
begin
  if IOHnd.Cache.PrepareReadBuff <> nil then
      DisposeObject(IOHnd.Cache.PrepareReadBuff);
  IOHnd.Cache.PrepareReadBuff := nil;
  IOHnd.Cache.PrepareReadPosition := -1;
end;

function umlFilePrepareRead(var IOHnd: TIOHnd; Size: Int64; var buff): Boolean;
var
  m64: TMS64;
  preRedSiz: Int64;
begin
  Result := False;

  if not IOHnd.Cache.UsedReadCache then
      exit;

  if Size > C_PrepareReadCacheSize then
    begin
      umlResetPrepareRead(IOHnd);
      IOHnd.Handle.Position := IOHnd.Position;
      exit;
    end;

  if IOHnd.Cache.PrepareReadBuff = nil then
      IOHnd.Cache.PrepareReadBuff := TMS64.Create;

  m64 := TMS64(IOHnd.Cache.PrepareReadBuff);

  if (IOHnd.Position < IOHnd.Cache.PrepareReadPosition) or (IOHnd.Cache.PrepareReadPosition + m64.Size < IOHnd.Position + Size) then
    begin
      // prepare read buffer
      IOHnd.Handle.Position := IOHnd.Position;
      IOHnd.Cache.PrepareReadPosition := IOHnd.Position;

      m64.Clear;
      IOHnd.Cache.PrepareReadPosition := IOHnd.Handle.Position;
      if IOHnd.Handle.Size - IOHnd.Handle.Position >= C_PrepareReadCacheSize then
        begin
          Result := m64.CopyFrom(IOHnd.Handle, C_PrepareReadCacheSize) = C_PrepareReadCacheSize;
          inc(IOHnd.IORead, C_PrepareReadCacheSize);
        end
      else
        begin
          preRedSiz := IOHnd.Handle.Size - IOHnd.Handle.Position;
          Result := m64.CopyFrom(IOHnd.Handle, preRedSiz) = preRedSiz;
          inc(IOHnd.IORead, preRedSiz);
        end;
    end;

  if (IOHnd.Position >= IOHnd.Cache.PrepareReadPosition) and (IOHnd.Cache.PrepareReadPosition + m64.Size >= IOHnd.Position + Size) then
    begin
      CopyPtr(GetOffset(m64.Memory, IOHnd.Position - IOHnd.Cache.PrepareReadPosition), @buff, Size);
      inc(IOHnd.Position, Size);
      Result := True;
    end
  else
    begin
      // safe process
      umlResetPrepareRead(IOHnd);
      IOHnd.Handle.Position := IOHnd.Position;
      exit;
    end;
end;

function umlFileRead(var IOHnd: TIOHnd; const Size: Int64; var buff): Boolean;
var
  BuffPointer: Pointer;
  i: Int64;
begin
  if not umlFileFlushWriteCache(IOHnd) then
    begin
      Result := False;
      exit;
    end;

  if Size = 0 then
    begin
      IOHnd.Return := C_NotError;
      Result := True;
      exit;
    end;

  if umlFilePrepareRead(IOHnd, Size, buff) then
    begin
      IOHnd.Return := C_NotError;
      Result := True;
      exit;
    end;

  try
    if Size > C_Buffer_Chunk_Size then
      begin
        // process Chunk buffer
        BuffPointer := @buff;
        i := Size;
        while i >= C_Buffer_Chunk_Size do
          begin
            if IOHnd.Handle.Read(BuffPointer^, C_Buffer_Chunk_Size) <> C_Buffer_Chunk_Size then
              begin
                IOHnd.Return := C_FileReadError;
                Result := False;
                exit;
              end;
            BuffPointer := GetOffset(BuffPointer, C_Buffer_Chunk_Size);
            dec(i, C_Buffer_Chunk_Size);
          end;
        // process buffer rest
        if i > 0 then
          if IOHnd.Handle.Read(BuffPointer^, i) <> i then
            begin
              IOHnd.Return := C_FileReadError;
              Result := False;
              exit;
            end;
        inc(IOHnd.Position, Size);
        IOHnd.Return := C_NotError;
        Result := True;
        inc(IOHnd.IORead, Size);
        exit;
      end;
    if IOHnd.Handle.Read(buff, Size) <> Size then
      begin
        IOHnd.Return := C_FileReadError;
        Result := False;
        exit;
      end;
    inc(IOHnd.Position, Size);
    IOHnd.Return := C_NotError;
    Result := True;
    inc(IOHnd.IORead, Size);
  except
    IOHnd.Return := C_FileReadError;
    Result := False;
  end;
end;

function umlBlockRead(var IOHnd: TIOHnd; var buff; const Size: Int64): Boolean;
begin
  Result := umlFileRead(IOHnd, Size, buff);
end;

function umlFilePrepareWrite(var IOHnd: TIOHnd): Boolean;
begin
  Result := True;
  if umlFileTest(IOHnd) and IOHnd.Cache.UsedWriteCache and (IOHnd.Cache.PrepareWriteBuff = nil) then
      IOHnd.Cache.PrepareWriteBuff := TMS64.CustomCreate(1024 * 1024 * 8);
end;

function umlFileFlushWriteCache(var IOHnd: TIOHnd): Boolean;
var
  m64: TMS64;
begin
  if IOHnd.Cache.PrepareWriteBuff <> nil then
    begin
      m64 := TMS64(IOHnd.Cache.PrepareWriteBuff);
      IOHnd.Cache.PrepareWriteBuff := nil;
      if IOHnd.Handle.Write(m64.Memory^, m64.Size) <> m64.Size then
        begin
          IOHnd.Return := C_FileWriteError;
          Result := False;
          exit;
        end;
      inc(IOHnd.IOWrite, m64.Size);
      DisposeObject(m64);
      IOHnd.Handle.Position := IOHnd.Position;
    end;
  Result := True;
end;

function umlFileWrite(var IOHnd: TIOHnd; const Size: Int64; const buff): Boolean;
var
  BuffPointer: Pointer;
  i: Int64;
begin
  if (IOHnd.IsOnlyRead) or (not IOHnd.IsOpen) then
    begin
      IOHnd.Return := C_FileWriteError;
      Result := False;
      exit;
    end;
  if Size = 0 then
    begin
      IOHnd.Return := C_NotError;
      Result := True;
      exit;
    end;

  IOHnd.ChangeFromWrite := True;

  umlResetPrepareRead(IOHnd);

  if Size <= $F000 then
      umlFilePrepareWrite(IOHnd);

  if IOHnd.Cache.PrepareWriteBuff <> nil then
    begin
      if TMS64(IOHnd.Cache.PrepareWriteBuff).Write64(buff, Size) <> Size then
        begin
          IOHnd.Return := C_FileWriteError;
          Result := False;
          exit;
        end;

      inc(IOHnd.Position, Size);
      if IOHnd.Position > IOHnd.Size then
          IOHnd.Size := IOHnd.Position;
      IOHnd.Return := C_NotError;
      Result := True;

      // 8M flush buffer
      if IOHnd.Cache.PrepareWriteBuff.Size > 8 * 1024 * 1024 then
          umlFileFlushWriteCache(IOHnd);
      exit;
    end;

  try
    if Size > C_Buffer_Chunk_Size then
      begin
        // process buffer chunk
        BuffPointer := @buff;
        i := Size;
        while i >= C_Buffer_Chunk_Size do
          begin
            if IOHnd.Handle.Write(BuffPointer^, C_Buffer_Chunk_Size) <> C_Buffer_Chunk_Size then
              begin
                IOHnd.Return := C_FileWriteError;
                Result := False;
                exit;
              end;
            BuffPointer := GetOffset(BuffPointer, C_Buffer_Chunk_Size);
            dec(i, C_Buffer_Chunk_Size);
          end;
        // process buffer rest
        if i > 0 then
          if IOHnd.Handle.Write(BuffPointer^, i) <> i then
            begin
              IOHnd.Return := C_FileWriteError;
              Result := False;
              exit;
            end;

        inc(IOHnd.Position, Size);
        if IOHnd.Position > IOHnd.Size then
            IOHnd.Size := IOHnd.Position;
        IOHnd.Return := C_NotError;
        Result := True;
        inc(IOHnd.IOWrite, Size);
        exit;
      end;
    if IOHnd.Handle.Write(buff, Size) <> Size then
      begin
        IOHnd.Return := C_FileWriteError;
        Result := False;
        exit;
      end;

    inc(IOHnd.Position, Size);
    if IOHnd.Position > IOHnd.Size then
        IOHnd.Size := IOHnd.Position;
    IOHnd.Return := C_NotError;
    Result := True;
    inc(IOHnd.IOWrite, Size);
  except
    IOHnd.Return := C_FileWriteError;
    Result := False;
  end;
end;

function umlBlockWrite(var IOHnd: TIOHnd; const buff; const Size: Int64): Boolean;
begin
  Result := umlFileWrite(IOHnd, Size, buff);
end;

function umlFileWriteFixedString(var IOHnd: TIOHnd; var Value: TPascalString): Boolean;
var
  buff: TBytes;
begin
  IOHnd.Pascal2FixedString(Value, buff);
  if umlFileWrite(IOHnd, IOHnd.FixedStringL, buff[0]) = False then
    begin
      IOHnd.Return := C_FileWriteError;
      Result := False;
      exit;
    end;

  IOHnd.Return := C_NotError;
  Result := True;
end;

function umlFileReadFixedString(var IOHnd: TIOHnd; var Value: TPascalString): Boolean;
var
  buff: TBytes;
begin
  try
    SetLength(buff, IOHnd.FixedStringL);
    if umlFileRead(IOHnd, IOHnd.FixedStringL, buff[0]) = False then
      begin
        IOHnd.Return := C_FileReadError;
        Result := False;
        exit;
      end;
    Value := IOHnd.FixedString2Pascal(buff);
    SetLength(buff, 0);
    IOHnd.Return := C_NotError;
    Result := True;
  except
    Value.text := '';
    IOHnd.Return := C_StringError;
    Result := False;
  end;
end;

function umlCheckSeedPos(var IOHnd: TIOHnd; Pos_: Int64): Boolean;
begin
  Result := (Pos_ >= 0) and (Pos_ <= IOHnd.Size);
end;

function umlFileSeek(var IOHnd: TIOHnd; const Pos_: Int64): Boolean;
begin
  if Pos_ < 0 then
    begin
      IOHnd.Return := C_SeekError;
      Result := False;
      exit;
    end;

  if not umlFileFlushWriteCache(IOHnd) then
    begin
      IOHnd.Return := C_Flush_And_Seek_Error;
      Result := False;
      exit;
    end;

  if (Pos_ = IOHnd.Position) and (Pos_ = IOHnd.Handle.Position) then
    begin
      IOHnd.Return := C_NotError;
      Result := True;
      exit;
    end;

  IOHnd.Return := C_SeekError;
  Result := False;
  if Pos_ > IOHnd.Size then
      exit;
  try
    IOHnd.Position := IOHnd.Handle.Seek(Pos_, TSeekOrigin.soBeginning);
    Result := IOHnd.Position <> -1;
    if Result then
        IOHnd.Return := C_NotError;
  except
  end;
end;

function umlFileSetSize(var IOHnd: TIOHnd; siz_: Int64): Boolean;
begin
  if not umlFileFlushWriteCache(IOHnd) then
    begin
      Result := False;
      exit;
    end;

  IOHnd.Handle.Size := siz_;
  IOHnd.Size := siz_;
  IOHnd.Position := IOHnd.Position;
  Result := True;
  IOHnd.Return := C_NotError;
end;

function umlFileGetPOS(var IOHnd: TIOHnd): Int64;
begin
  umlFileFlushWriteCache(IOHnd);
  Result := IOHnd.Position;
end;

function umlFilePOS(var IOHnd: TIOHnd): Int64;
begin
  Result := umlFileGetPOS(IOHnd);
end;

function umlFileGetSize(var IOHnd: TIOHnd): Int64;
begin
  umlFileFlushWriteCache(IOHnd);
  Result := IOHnd.Size;
end;

function umlFileSize(var IOHnd: TIOHnd): Int64;
begin
  Result := umlFileGetSize(IOHnd);
end;

function umlGetFileTime(const FileName: TPascalString): TDateTime;
{$IFDEF MSWINDOWS}
  function CovFileDate_(Fd: TFileTime): TDateTime;
  var
    Tct: _SystemTime;
    t: TFileTime;
  begin
    FileTimeToLocalFileTime(Fd, t);
    FileTimeToSystemTime(t, Tct);
    CovFileDate_ := SystemTimeToDateTime(Tct);
  end;

var
  SR: TSR;
begin
  try
    if umlFindFirstFile(FileName, SR) then
        Result := CovFileDate_(SR.FindData.ftLastWriteTime)
    else
        Result := 0;
    umlFindClose(SR);
  except
      Result := 0;
  end;
end;
{$ELSE MSWINDOWS}


var
  f: THandle;
begin
  try
    f := FileOpen(FileName.text, fmOpenRead or fmShareDenyNone);
    if f <> THandle(-1) then
      begin
        Result := FileDateToDateTime(FileGetDate(f));
        FileClose(f);
      end
    else
        Result := 0;
  except
      Result := 0;
  end;
end;
{$ENDIF MSWINDOWS}


procedure umlSetFileTime(const FileName: TPascalString; newTime: TDateTime);
begin
  try
      FileSetDate(FileName.text, DateTimeToFileDate(newTime));
  except
  end;
end;

function umlGetFileSize(const FileName: TPascalString): Int64;
var
  SR: TSR;
begin
  Result := 0;
  try
    if umlFindFirstFile(FileName, SR) = True then
      begin
        Result := SR.Size;
        while umlFindNextFile(SR) do
            Result := Result + SR.Size;
      end;
    umlFindClose(SR);
  except
  end;
end;

function umlGetFileCount(const FileName: TPascalString): Integer;
var
  SR: TSR;
begin
  Result := 0;
  if umlFindFirstFile(FileName, SR) = True then
    begin
      Result := Result + 1;
      while umlFindNextFile(SR) = True do
          Result := Result + 1;
    end;
  umlFindClose(SR);
end;

function umlGetFileDateTime(const FileName: TPascalString): TDateTime;
begin
  if not FileAge(FileName.text, Result, False) then
      Result := Now;
end;

function umlDeleteFile(const FileName: TPascalString; const _VerifyCheck: Boolean): Boolean;
var
  _SR: TSR;
  ph: TPascalString;
begin
  if umlExistsChar(FileName, '*?') then
    begin
      ph := umlGetFilePath(FileName);
      if umlFindFirstFile(FileName, _SR) then
        begin
          repeat
            try
                DeleteFile(umlCombineFileName(ph, _SR.Name).text);
            except
            end;
          until not umlFindNextFile(_SR);
        end;
      umlFindClose(_SR);
      Result := True;
    end
  else
    begin
      try
          Result := DeleteFile(FileName.text);
      except
          Result := False;
      end;
      if Result and _VerifyCheck then
          Result := not umlFileExists(FileName)
      else
          Result := True;
    end;
end;

function umlDeleteFile(const FileName: TPascalString): Boolean;
begin
  Result := umlDeleteFile(FileName, False);
end;

function umlCopyFile(const SourFile, DestFile: TPascalString): Boolean;
var
  SH_, DH_: TCore_FileStream;
begin
  Result := False;
  SH_ := nil;
  DH_ := nil;
  try
    if not umlFileExists(SourFile) then
        exit;
    if umlMultipleMatch(True, ExpandFileName(SourFile.text), ExpandFileName(DestFile.text)) then
        exit;
    SH_ := TCore_FileStream.Create(SourFile.text, fmOpenRead or fmShareDenyNone);
    DH_ := TCore_FileStream.Create(DestFile.text, fmCreate);
    Result := DH_.CopyFrom(SH_, SH_.Size) = SH_.Size;
    DisposeObject(SH_);
    DisposeObject(DH_);
    umlSetFileTime(DestFile, umlGetFileTime(SourFile));
  except
    if SH_ <> nil then
        DisposeObject(SH_);
    if DH_ <> nil then
        DisposeObject(DH_);
  end;
end;

function umlRenameFile(const OldName, NewName: TPascalString): Boolean;
begin
  Result := RenameFile(OldName.text, NewName.text);
end;

procedure umlSetLength(var sVal: TPascalString; L: Integer);
begin
  sVal.L := L;
end;

procedure umlSetLength(var sVal: U_Bytes; L: Integer);
begin
  SetLength(sVal, L);
end;

procedure umlSetLength(var sVal: TArrayPascalString; L: Integer);
begin
  SetLength(sVal, L);
end;

function umlGetLength(const sVal: TPascalString): Integer;
begin
  Result := sVal.L;
end;

function umlGetLength(const sVal: U_Bytes): Integer;
begin
  Result := length(sVal);
end;

function umlGetLength(const sVal: TArrayPascalString): Integer;
begin
  Result := length(sVal);
end;

function umlUpperCase(const S: TPascalString): TPascalString;
begin
  Result := S.UpperText;
end;

function umlUpperCase(const S: PPascalString): TPascalString;
begin
  Result := S^.UpperText;
end;

function umlLowerCase(const S: TPascalString): TPascalString;
begin
  Result := S.LowerText;
end;

function umlLowerCase(const S: PPascalString): TPascalString;
begin
  Result := S^.LowerText;
end;

function umlCopyStr(const sVal: TPascalString; MainPosition, LastPosition: Integer): TPascalString;
begin
  Result := sVal.GetString(MainPosition, LastPosition);
end;

function umlSameText(const s1, s2: TPascalString): Boolean;
begin
  Result := s1.Same(@s2);
end;

function umlSameText(const s1, s2: PPascalString): Boolean;
begin
  Result := s1^.Same(s2);
end;

function umlDeleteChar(const SText, Ch: TPascalString): TPascalString;
var
  i: Integer;
begin
  Result := '';
  if SText.L > 0 then
    for i := 1 to SText.L do
      if not CharIn(SText[i], Ch) then
          Result.Append(SText[i]);
end;

function umlDeleteChar(const SText: TPascalString; const SomeChars: TArrayChar): TPascalString;
var
  i: Integer;
begin
  Result := '';
  if SText.L > 0 then
    for i := 1 to SText.L do
      if not CharIn(SText[i], SomeChars) then
          Result.Append(SText[i]);
end;

function umlDeleteChar(const SText: TPascalString; const SomeCharsets: TOrdChars): TPascalString; overload;
var
  i: Integer;
begin
  Result := '';
  if SText.L > 0 then
    for i := 1 to SText.L do
      if not CharIn(SText[i], SomeCharsets) then
          Result.Append(SText[i]);
end;

function umlGetNumberCharInText(const n: TPascalString): TPascalString;
var
  i: Integer;
begin
  Result := '';
  i := 0;
  if n.L = 0 then
      exit;

  while i <= n.L do
    begin
      if (not CharIn(n[i], c0to9)) then
        begin
          if (Result.L = 0) then
              inc(i)
          else
              exit;
        end
      else
        begin
          Result.Append(n[i]);
          inc(i);
        end;
    end;
end;

function umlMatchChar(CharValue: U_Char; cVal: PPascalString): Boolean;
begin
  Result := CharIn(CharValue, cVal);
end;

function umlMatchChar(CharValue: U_Char; cVal: TPascalString): Boolean;
begin
  Result := CharIn(CharValue, @cVal);
end;

function umlExistsChar(StrValue: TPascalString; cVal: TPascalString): Boolean;
var
  C: SystemChar;
begin
  Result := True;
  for C in StrValue.buff do
    if CharIn(C, @cVal) then
        exit;
  Result := False;
end;

function umlExistsChar(StrValue, cVal: PPascalString): Boolean;
var
  C: SystemChar;
begin
  Result := True;
  for C in StrValue^.buff do
    if CharIn(C, cVal) then
        exit;
  Result := False;
end;

function umlTrimChar(const S, trim_s: TPascalString): TPascalString;
var
  L, BP, EP: Integer;
begin
  Result := '';
  L := S.L;
  if L > 0 then
    begin
      BP := 1;
      while CharIn(S[BP], @trim_s) do
        begin
          inc(BP);
          if (BP > L) then
            begin
              Result := '';
              exit;
            end;
        end;
      if BP > L then
          Result := ''
      else
        begin
          EP := L;

          while CharIn(S[EP], @trim_s) do
            begin
              dec(EP);
              if (EP < 1) then
                begin
                  Result := '';
                  exit;
                end;
            end;
          Result := S.GetString(BP, EP + 1);
        end;
    end;
end;

function umlGetFirstStr(const sVal, trim_s: TPascalString): TPascalString;
var
  Next_Pos_, First_Pos_: Integer;
begin
  Result := sVal;
  if Result.L <= 0 then
    begin
      exit;
    end;
  First_Pos_ := 1;
  while umlMatchChar(Result[First_Pos_], @trim_s) do
    begin
      if First_Pos_ = Result.L then
        begin
          Result := '';
          exit;
        end;
      inc(First_Pos_);
    end;
  Next_Pos_ := First_Pos_;
  while not umlMatchChar(Result[First_Pos_], @trim_s) do
    begin
      if First_Pos_ = Result.L then
        begin
          Result := umlCopyStr(Result, Next_Pos_, First_Pos_ + 1);
          exit;
        end;
      inc(First_Pos_);
    end;
  Result := umlCopyStr(Result, Next_Pos_, First_Pos_);
end;

function umlGetLastStr(const sVal, trim_s: TPascalString): TPascalString;
var
  Prev_Pos_, Last_Pos_: Integer;
begin
  Result := sVal;
  Last_Pos_ := Result.L;
  if Last_Pos_ <= 0 then
    begin
      exit;
    end;
  while umlMatchChar(Result[Last_Pos_], @trim_s) do
    begin
      if Last_Pos_ = 1 then
        begin
          Result := '';
          exit;
        end;
      dec(Last_Pos_);
    end;
  Prev_Pos_ := Last_Pos_;
  while not umlMatchChar(Result[Last_Pos_], @trim_s) do
    begin
      if Last_Pos_ = 1 then
        begin
          Result := umlCopyStr(Result, Last_Pos_, Prev_Pos_ + 1);
          exit;
        end;
      dec(Last_Pos_);
    end;
  Result := umlCopyStr(Result, Last_Pos_ + 1, Prev_Pos_ + 1);
end;

function umlDeleteFirstStr(const sVal, trim_s: TPascalString): TPascalString;
var
  First_Pos_: Integer;
begin
  Result := sVal;
  if Result.L <= 0 then
    begin
      Result := '';
      exit;
    end;
  First_Pos_ := 1;
  while umlMatchChar(Result[First_Pos_], @trim_s) do
    begin
      if First_Pos_ = Result.L then
        begin
          Result := '';
          exit;
        end;
      inc(First_Pos_);
    end;
  while not umlMatchChar(Result[First_Pos_], @trim_s) do
    begin
      if First_Pos_ = Result.L then
        begin
          Result := '';
          exit;
        end;
      inc(First_Pos_);
    end;
  while umlMatchChar(Result[First_Pos_], @trim_s) do
    begin
      if First_Pos_ = Result.L then
        begin
          Result := '';
          exit;
        end;
      inc(First_Pos_);
    end;
  Result := umlCopyStr(Result, First_Pos_, Result.L + 1);
end;

function umlDeleteLastStr(const sVal, trim_s: TPascalString): TPascalString;
var
  Last_Pos_: Integer;
begin
  Result := sVal;
  Last_Pos_ := Result.L;
  if Last_Pos_ <= 0 then
    begin
      Result := '';
      exit;
    end;
  while umlMatchChar(Result[Last_Pos_], @trim_s) do
    begin
      if Last_Pos_ = 1 then
        begin
          Result := '';
          exit;
        end;
      dec(Last_Pos_);
    end;
  while not umlMatchChar(Result[Last_Pos_], @trim_s) do
    begin
      if Last_Pos_ = 1 then
        begin
          Result := '';
          exit;
        end;
      dec(Last_Pos_);
    end;
  while umlMatchChar(Result[Last_Pos_], @trim_s) do
    begin
      if Last_Pos_ = 1 then
        begin
          Result := '';
          exit;
        end;
      dec(Last_Pos_);
    end;
  umlSetLength(Result, Last_Pos_);
end;

function umlGetIndexStrCount(const sVal, trim_s: TPascalString): Integer;
var
  S: TPascalString;
  Pos_: Integer;
begin
  S := sVal;
  Result := 0;
  if S.L = 0 then
      exit;
  Pos_ := 1;
  while True do
    begin
      while umlMatchChar(S[Pos_], @trim_s) do
        begin
          if Pos_ >= S.L then
              exit;
          inc(Pos_);
        end;
      inc(Result);
      while not umlMatchChar(S[Pos_], @trim_s) do
        begin
          if Pos_ >= S.L then
              exit;
          inc(Pos_);
        end;
    end;
end;

function umlGetIndexStr(const sVal: TPascalString; trim_s: TPascalString; index: Integer): TPascalString;
var
  umlGetIndexName_Repeat: Integer;
begin
  case index of
    - 1:
      begin
        Result := '';
        exit;
      end;
    0, 1:
      begin
        Result := umlGetFirstStr(sVal, trim_s);
        exit;
      end;
  end;
  if index >= umlGetIndexStrCount(sVal, trim_s) then
    begin
      Result := umlGetLastStr(sVal, trim_s);
      exit;
    end;
  Result := sVal;
  for umlGetIndexName_Repeat := 2 to index do
    begin
      Result := umlDeleteFirstStr(Result, trim_s);
    end;
  Result := umlGetFirstStr(Result, trim_s);
end;

procedure umlGetSplitArray(const sour: TPascalString; var dest: TArrayPascalString; const splitC: TPascalString);
var
  i, idxCount: Integer;
  SText: TPascalString;
begin
  SText := sour;
  idxCount := umlGetIndexStrCount(SText, splitC);
  if (idxCount = 0) and (sour.L > 0) then
    begin
      SetLength(dest, 1);
      dest[0] := sour;
    end
  else
    begin
      SetLength(dest, idxCount);
      i := low(dest);
      while i < idxCount do
        begin
          dest[i] := umlGetFirstStr(SText, splitC);
          SText := umlDeleteFirstStr(SText, splitC);
          inc(i);
        end;
    end;
end;

procedure umlGetSplitArray(const sour: TPascalString; var dest: U_StringArray; const splitC: TPascalString);
var
  i, idxCount: Integer;
  SText: TPascalString;
begin
  SText := sour;
  idxCount := umlGetIndexStrCount(SText, splitC);
  if (idxCount = 0) and (sour.L > 0) then
    begin
      SetLength(dest, 1);
      dest[0] := sour;
    end
  else
    begin
      SetLength(dest, idxCount);
      i := low(dest);
      while i < idxCount do
        begin
          dest[i] := umlGetFirstStr(SText, splitC);
          SText := umlDeleteFirstStr(SText, splitC);
          inc(i);
        end;
    end;
end;

function ArrayStringToText(var ary: TArrayPascalString; const splitC: TPascalString): TPascalString;
var
  i: Integer;
begin
  Result := '';
  for i := low(ary) to high(ary) do
    if i < high(ary) then
        Result := Result + ary[i] + splitC
    else
        Result := Result + ary[i];
end;

function umlStringsToSplitText(lst: TCore_Strings; const splitC: TPascalString): TPascalString;
var
  i: Integer;
begin
  Result := '';
  for i := 0 to lst.Count - 1 do
    if i > 0 then
        Result.Append(splitC.text + lst[i])
    else
        Result := lst[i];
end;

function umlStringsToSplitText(lst: TListPascalString; const splitC: TPascalString): TPascalString;
var
  i: Integer;
begin
  Result := '';
  for i := 0 to lst.Count - 1 do
    if i > 0 then
        Result.Append(splitC.text + lst[i])
    else
        Result := lst[i];
end;

function umlGetFirstStr___(const sVal, trim_s: TPascalString): TPascalString;
var
  Next_Pos_, First_Pos_: Integer;
begin
  Result := sVal;
  if Result.L <= 0 then
      exit;
  First_Pos_ := 1;
  if umlMatchChar(Result[First_Pos_], @trim_s) then
    begin
      inc(First_Pos_);
      Next_Pos_ := First_Pos_;
    end
  else
    begin
      Next_Pos_ := First_Pos_;
      while not umlMatchChar(Result[First_Pos_], @trim_s) do
        begin
          if First_Pos_ = Result.L then
            begin
              Result := umlCopyStr(Result, Next_Pos_, First_Pos_ + 1);
              exit;
            end;
          inc(First_Pos_);
        end;
    end;
  Result := umlCopyStr(Result, Next_Pos_, First_Pos_);
end;

function umlDeleteFirstStr___(const sVal, trim_s: TPascalString): TPascalString;
var
  First_Pos_: Integer;
begin
  Result := sVal;
  if Result.L <= 0 then
    begin
      Result := '';
      exit;
    end;
  First_Pos_ := 1;
  while not umlMatchChar(Result[First_Pos_], @trim_s) do
    begin
      if First_Pos_ = Result.L then
        begin
          Result := '';
          exit;
        end;
      inc(First_Pos_);
    end;
  if umlMatchChar(Result[First_Pos_], @trim_s) then
      inc(First_Pos_);
  Result := umlCopyStr(Result, First_Pos_, Result.L + 1);
end;

function umlGetLastStr___(const sVal, trim_s: TPascalString): TPascalString;
var
  Prev_Pos_, Last_Pos_: Integer;
begin
  Result := sVal;
  Last_Pos_ := Result.L;
  if Last_Pos_ <= 0 then
      exit;
  if Result[Last_Pos_] = trim_s then
      dec(Last_Pos_);
  Prev_Pos_ := Last_Pos_;
  while not umlMatchChar(Result[Last_Pos_], @trim_s) do
    begin
      if Last_Pos_ = 1 then
        begin
          Result := umlCopyStr(Result, Last_Pos_, Prev_Pos_ + 1);
          exit;
        end;
      dec(Last_Pos_);
    end;
  Result := umlCopyStr(Result, Last_Pos_ + 1, Prev_Pos_ + 1);
end;

function umlDeleteLastStr___(const sVal, trim_s: TPascalString): TPascalString;
var
  Last_Pos_: Integer;
begin
  Result := sVal;
  Last_Pos_ := Result.L;
  if Last_Pos_ <= 0 then
    begin
      Result := '';
      exit;
    end;
  if umlMatchChar(Result[Last_Pos_], @trim_s) then
      dec(Last_Pos_);
  while not umlMatchChar(Result[Last_Pos_], @trim_s) do
    begin
      if Last_Pos_ = 1 then
        begin
          Result := '';
          exit;
        end;
      dec(Last_Pos_);
    end;
  umlSetLength(Result, Last_Pos_);
end;

function umlGetIndexStrCount___(const sVal, trim_s: TPascalString): Integer;
var
  S: TPascalString;
  Pos_: Integer;
begin
  S := sVal;
  Result := 0;
  if S.L = 0 then
      exit;
  Pos_ := 1;
  Result := 1;
  while True do
    begin
      while not umlMatchChar(S[Pos_], @trim_s) do
        begin
          if Pos_ = S.L then
              exit;
          inc(Pos_);
        end;
      inc(Result);
      if Pos_ = S.L then
          exit;
      inc(Pos_);
    end;
end;

function umlGetIndexStr___(const sVal: TPascalString; trim_s: TPascalString; index: Integer): TPascalString;
var
  umlGetIndexName_Repeat: Integer;
begin
  case index of
    - 1:
      begin
        Result := '';
        exit;
      end;
    0, 1:
      begin
        Result := umlGetFirstStr___(sVal, trim_s);
        exit;
      end;
  end;
  if index >= umlGetIndexStrCount___(sVal, trim_s) then
    begin
      Result := umlGetLastStr___(sVal, trim_s);
      exit;
    end;
  Result := sVal;
  for umlGetIndexName_Repeat := 2 to index do
      Result := umlDeleteFirstStr___(Result, trim_s);
  Result := umlGetFirstStr___(Result, trim_s);
end;

function umlGetFirstTextPos(const S: TPascalString; const TextArry: TArrayPascalString; var OutText: TPascalString): Integer;
var
  i, j: Integer;
begin
  Result := -1;
  for i := 1 to S.L do
    begin
      for j := low(TextArry) to high(TextArry) do
        begin
          if S.ComparePos(i, @TextArry[j]) then
            begin
              OutText := TextArry[j];
              Result := i;
              exit;
            end;
        end;
    end;
end;

function umlDeleteText(const sour: TPascalString; const bToken, eToken: TArrayPascalString; ANeedBegin, ANeedEnd: Boolean): TPascalString;
var
  ABeginPos, AEndPos: Integer;
  ABeginText, AEndText, ANewStr: TPascalString;
begin
  Result := sour;
  if sour.L > 0 then
    begin
      ABeginPos := umlGetFirstTextPos(sour, bToken, ABeginText);
      if ABeginPos > 0 then
          ANewStr := umlCopyStr(sour, ABeginPos + ABeginText.L, sour.L + 1)
      else if ANeedBegin then
          exit
      else
          ANewStr := sour;

      AEndPos := umlGetFirstTextPos(ANewStr, eToken, AEndText);
      if AEndPos > 0 then
          ANewStr := umlCopyStr(ANewStr, (AEndPos + AEndText.L), ANewStr.L + 1)
      else if ANeedEnd then
          exit
      else
          ANewStr := '';

      if ABeginPos > 0 then
        begin
          if AEndPos > 0 then
              Result := umlCopyStr(sour, 0, ABeginPos - 1) + umlDeleteText(ANewStr, bToken, eToken, ANeedBegin, ANeedEnd)
          else
              Result := umlCopyStr(sour, 0, ABeginPos - 1) + ANewStr;
        end
      else if AEndPos > 0 then
          Result := ANewStr;
    end;
end;

function umlGetTextContent(const sour: TPascalString; const bToken, eToken: TArrayPascalString): TPascalString;
var
  ABeginPos, AEndPos: Integer;
  ABeginText, AEndText, ANewStr: TPascalString;
begin
  Result := '';
  if sour.L > 0 then
    begin
      ABeginPos := umlGetFirstTextPos(sour, bToken, ABeginText);
      if ABeginPos > 0 then
          ANewStr := umlCopyStr(sour, ABeginPos + ABeginText.L, sour.L + 1)
      else
          ANewStr := sour;

      AEndPos := umlGetFirstTextPos(ANewStr, eToken, AEndText);
      if AEndPos > 0 then
          Result := umlCopyStr(ANewStr, 0, AEndPos - 1)
      else
          Result := ANewStr;
    end;
end;

function umlGetNumTextType(const S: TPascalString): TTextType;
type
  TValSym = (vsSymSub, vsSymAdd, vsSymAddSub, vsSymDollar, vsDot, vsDotBeforNum, vsDotAfterNum, vsNum, vsAtoF, vsE, vsUnknow);
var
  cnt: array [TValSym] of Integer;
  n: TPascalString;
  v: TValSym;
  C: SystemChar;
  i: Integer;
begin
  n := umlTrimSpace(S);
  if n.Same('true') or n.Same('false') then
      exit(ntBool);

  for v := low(TValSym) to high(TValSym) do
      cnt[v] := 0;

  for i := 1 to n.L do
    begin
      C := n[i];
      if CharIn(C, [c0to9]) then
        begin
          inc(cnt[vsNum]);
          if cnt[vsDot] > 0 then
              inc(cnt[vsDotAfterNum]);
        end
      else if CharIn(C, [cLoAtoF, cHiAtoF]) then
        begin
          inc(cnt[vsAtoF]);
          if CharIn(C, 'eE') then
              inc(cnt[vsE]);
        end
      else if C = '.' then
        begin
          inc(cnt[vsDot]);
          cnt[vsDotBeforNum] := cnt[vsNum];
        end
      else if CharIn(C, '-') then
        begin
          inc(cnt[vsSymSub]);
          inc(cnt[vsSymAddSub]);
        end
      else if CharIn(C, '+') then
        begin
          inc(cnt[vsSymAdd]);
          inc(cnt[vsSymAddSub]);
        end
      else if CharIn(C, '$') and (i = 1) then
        begin
          inc(cnt[vsSymDollar]);
          if i <> 1 then
              exit(ntUnknow);
        end
      else
          exit(ntUnknow);
    end;

  if cnt[vsDot] > 1 then
      exit(ntUnknow);
  if cnt[vsSymDollar] > 1 then
      exit(ntUnknow);
  if (cnt[vsSymDollar] = 0) and (cnt[vsNum] = 0) then
      exit(ntUnknow);
  if (cnt[vsSymAdd] > 1) and (cnt[vsE] = 0) and (cnt[vsSymDollar] = 0) then
      exit(ntUnknow);

  if (cnt[vsSymDollar] = 0) and
    ((cnt[vsDot] = 1) or ((cnt[vsE] = 1) and ((cnt[vsSymAddSub] >= 1) and (cnt[vsSymDollar] = 0)))) then
    begin
      if cnt[vsSymDollar] > 0 then
          exit(ntUnknow);
      if (cnt[vsAtoF] <> cnt[vsE]) then
          exit(ntUnknow);

      if cnt[vsE] = 1 then
        begin
          Result := ntDouble
        end
      else if ((cnt[vsDotBeforNum] > 0)) and (cnt[vsDotAfterNum] > 0) then
        begin
          if cnt[vsDotAfterNum] < 5 then
              Result := ntCurrency
          else if cnt[vsNum] > 7 then
              Result := ntDouble
          else
              Result := ntSingle;
        end
      else
          exit(ntUnknow);
    end
  else
    begin
      if cnt[vsSymDollar] = 1 then
        begin
          if cnt[vsSymSub] > 0 then
            begin
              if cnt[vsNum] + cnt[vsAtoF] = 0 then
                  Result := ntUnknow
              else if cnt[vsNum] + cnt[vsAtoF] < 2 then
                  Result := ntShortInt
              else if cnt[vsNum] + cnt[vsAtoF] < 4 then
                  Result := ntSmallInt
              else if cnt[vsNum] + cnt[vsAtoF] < 7 then
                  Result := ntInt
              else if cnt[vsNum] + cnt[vsAtoF] < 13 then
                  Result := ntInt64
              else
                  Result := ntUnknow;
            end
          else
            begin
              if cnt[vsNum] + cnt[vsAtoF] = 0 then
                  Result := ntUnknow
              else if cnt[vsNum] + cnt[vsAtoF] < 3 then
                  Result := ntByte
              else if cnt[vsNum] + cnt[vsAtoF] < 5 then
                  Result := ntWord
              else if cnt[vsNum] + cnt[vsAtoF] < 8 then
                  Result := ntUInt
              else if cnt[vsNum] + cnt[vsAtoF] < 14 then
                  Result := ntUInt64
              else
                  Result := ntUnknow;
            end;
        end
      else if cnt[vsAtoF] > 0 then
          exit(ntUnknow)
      else if cnt[vsSymSub] > 0 then
        begin
          if cnt[vsNum] = 0 then
              Result := ntUnknow
          else if cnt[vsNum] < 3 then
              Result := ntShortInt
          else if cnt[vsNum] < 5 then
              Result := ntSmallInt
          else if cnt[vsNum] < 8 then
              Result := ntInt
          else if cnt[vsNum] < 15 then
              Result := ntInt64
          else
              Result := ntUnknow;
        end
      else
        begin
          if cnt[vsNum] = 0 then
              Result := ntUnknow
          else if cnt[vsNum] < 3 then
              Result := ntByte
          else if cnt[vsNum] < 5 then
              Result := ntWord
          else if cnt[vsNum] < 8 then
              Result := ntUInt
          else if cnt[vsNum] < 16 then
              Result := ntUInt64
          else
              Result := ntUnknow;
        end;
    end;
end;

function umlIsHex(const sVal: TPascalString): Boolean;
begin
  Result := umlGetNumTextType(sVal) in
    [ntInt, ntInt64, ntUInt64, ntWord, ntByte, ntSmallInt, ntShortInt, ntUInt];
end;

function umlIsNumber(const sVal: TPascalString): Boolean;
begin
  Result := umlGetNumTextType(sVal) <> ntUnknow;
end;

function umlIsIntNumber(const sVal: TPascalString): Boolean;
begin
  Result := umlGetNumTextType(sVal) in
    [ntInt, ntInt64, ntUInt64, ntWord, ntByte, ntSmallInt, ntShortInt, ntUInt];
end;

function umlIsFloatNumber(const sVal: TPascalString): Boolean;
begin
  Result := umlGetNumTextType(sVal) in [ntSingle, ntDouble, ntCurrency];
end;

function umlIsBool(const sVal: TPascalString): Boolean;
begin
  Result := umlGetNumTextType(sVal) = ntBool;
end;

function umlNumberCount(const sVal: TPascalString): Integer;
var
  i: Integer;
begin
  Result := 0;
  for i := 1 to sVal.L do
    if CharIn(sVal[i], [c0to9]) then
        inc(Result);
end;

function umlPercentageToFloat(OriginMax, OriginMin, ProcressParameter: Double): Double;
begin
  Result := (ProcressParameter - OriginMin) * 100.0 / (OriginMax - OriginMin);
end;

function umlPercentageToInt64(OriginParameter, ProcressParameter: Int64): Integer;
begin
  if OriginParameter = 0 then
      Result := 0
  else
      Result := Round((ProcressParameter * 100.0) / OriginParameter);
end;

function umlPercentageToInt(OriginParameter, ProcressParameter: Integer): Integer;
begin
  if OriginParameter = 0 then
      Result := 0
  else
      Result := Round((ProcressParameter * 100.0) / OriginParameter);
end;

function umlPercentageToStr(OriginParameter, ProcressParameter: Integer): TPascalString;
begin
  Result := IntToStr(umlPercentageToInt(OriginParameter, ProcressParameter)) + '%';
end;

function umlSmartSizeToStr(Size: Int64): TPascalString;
begin
  if Size < 1 shl 10 then
      Result := Format('%d', [Size])
  else if Size < 1 shl 20 then
      Result := Format('%fKb', [Size / (1 shl 10)])
  else
      Result := Format('%fM', [Size / (1 shl 20)]);
end;

function umlIntToStr(Parameter: Single): TPascalString;
begin
  Result := IntToStr(Round(Parameter));
end;

function umlIntToStr(Parameter: Double): TPascalString;
begin
  Result := IntToStr(Round(Parameter));
end;

function umlIntToStr(Parameter: Int64): TPascalString;
begin
  Result := IntToStr(Parameter);
end;

function umlIntToStr(Parameter: UInt64): TPascalString;
begin
  Result := UIntToStr(Parameter);
end;

function umlIntToStr(Parameter: Int128): TPascalString;
begin
  Result := Parameter.ToString;
end;

function umlIntToStr(Parameter: UInt128): TPascalString;
begin
  Result := Parameter.ToString;
end;

function umlIntToStr(Parameter: Integer): TPascalString;
begin
  Result := IntToStr(Parameter);
end;

function umlIntToStr(Parameter: Cardinal): TPascalString;
begin
  Result := UIntToStr(Parameter);
end;

function umlPointerToStr(param: Pointer): TPascalString;
begin
  Result := '0x' + IntToHex(NativeUInt(param), SizeOf(Pointer) * 2);
end;

function umlMBPSToStr(Size: Int64): TPascalString;
begin
  if Size < 1 shl 10 then
      Result := Format('%dBps', [Size * 10])
  else if Size < 1 shl 20 then
      Result := Format('%fKbps', [Size / (1 shl 10) * 10])
  else
      Result := Format('%fMbps', [Size / (1 shl 20) * 10]);
end;

function umlSizeToStr(Parameter: Int64): TPascalString;
begin
  try
      Result := umlSmartSizeToStr(Parameter);
  except
      Result := IntToStr(Parameter) + ' B';
  end;
end;

function umlGSizeToStr(Parameter: Int64): TPascalString;
begin
  try
    if Parameter < 1 shl 10 then
        Result := Format('%d', [Parameter])
    else if Parameter < 1 shl 20 then
        Result := Format('%fKb', [Parameter / (1 shl 10)])
    else if Parameter < 1 shl 30 then
        Result := Format('%fM', [Parameter / (1 shl 20)])
    else
        Result := Format('%fG', [Parameter / (1 shl 30)])
  except
      Result := IntToStr(Parameter);
  end;
end;

function umlStrToTime(S: TPascalString): TDateTime;
begin
  Result := StrToTime(S.text, Lib_DateTimeFormatSettings);
end;

function umlTimeToStr(t: TDateTime): TPascalString;
begin
  Result.text := TimeToStr(t, Lib_DateTimeFormatSettings);
end;

function umlStrToDateTime(S: TPascalString): TDateTime;
begin
  Result := StrToDateTime(S.text, Lib_DateTimeFormatSettings);
end;

function umlDateTimeToStr(t: TDateTime): TPascalString;
begin
  Result.text := DateTimeToStr(t, Lib_DateTimeFormatSettings);
end;

function umlDT(t: TDateTime): TPascalString;
begin
  Result := umlDateTimeToStr(t);
end;

function umlDT(S: TPascalString): TDateTime;
begin
  Result := umlStrToDateTime(S);
end;

function umlDT(S: TPascalString; Default_: TDateTime): TDateTime;
begin
  try
      Result := umlDT(S);
  except
      Result := Default_;
  end;
end;

function umlT(t: TDateTime): TPascalString;
begin
  Result := umlTimeToStr(t);
end;

function umlT(S: TPascalString): TDateTime;
begin
  Result := umlStrToTime(S);
end;

function umlT(S: TPascalString; Default_: TDateTime): TDateTime;
begin
  try
      Result := umlT(S);
  except
      Result := Default_;
  end;
end;

function umlTimeTickToStr(const t: TTimeTick): TPascalString;
var
  Tmp, D, H, M, S: TTimeTick;
begin
{$IFDEF FPC}
  D := t div C_Tick_Day;
  Tmp := t mod C_Tick_Day;

  H := Tmp div C_Tick_Hour;
  Tmp := t mod C_Tick_Hour;

  M := Tmp div C_Tick_Minute;
  Tmp := t mod C_Tick_Minute;

  S := Tmp div C_Tick_Second;
  Tmp := t mod C_Tick_Second;
{$ELSE FPC}
  DivMod(t, C_Tick_Day, D, Tmp);
  DivMod(Tmp, C_Tick_Hour, H, Tmp);
  DivMod(Tmp, C_Tick_Minute, M, Tmp);
  DivMod(Tmp, C_Tick_Second, S, Tmp);
{$ENDIF FPC}
  Result := '';
  if (D > 0) then
      Result.Append(IntToStr(D) + ' Day ');
  if (Result.L > 0) or (H > 0) then
      Result.Append(IntToStr(H) + ':');
  if (Result.L > 0) or (M > 0) then
      Result.Append(IntToStr(M) + ':');

  if (Result.L > 0) or (S > 0) then
      Result.Append(PFormat('%2.2f', [S + Tmp / 1000]))
  else
      Result.Append('0');
end;

function umlDateToStr(t: TDateTime): TPascalString;
begin
  Result := DateToStr(t, Lib_DateTimeFormatSettings);
end;

function umlFloatToStr(const f: Double): TPascalString;
begin
  Result := FloatToStr(f);
end;

function umlShortFloatToStr(const f: Double): TPascalString;
begin
  Result := Format('%f', [f]);
end;

function umlStrToInt(const V_: TPascalString): Integer;
begin
  Result := umlStrToInt(V_, 0);
end;

function umlStrToInt(const V_: TPascalString; _Def: Integer): Integer;
begin
  if umlIsNumber(V_) then
    begin
      try
          Result := StrToInt(V_.text);
      except
          Result := _Def;
      end;
    end
  else
      Result := _Def;
end;

function umlStrToInt64(const V_: TPascalString; _Def: Int64): Int64;
begin
  if umlIsNumber(V_) then
    begin
      try
          Result := StrToInt64(V_.text);
      except
          Result := _Def;
      end;
    end
  else
      Result := _Def;
end;

function umlStrToInt64(const V_: TPascalString): Int64;
begin
  Result := umlStrToInt64(V_, 0);
end;

function umlStrToInt128(const V_: TPascalString; _Def: Int128): Int128;
begin
  try
      Result := Int128(V_.text);
  except
      Result := _Def;
  end;
end;

function umlStrToInt128(const V_: TPascalString): Int128;
begin
  Result := umlStrToInt128(V_, 0);
end;

function umlStrToFloat(const V_: TPascalString; _Def: Double): Double;
begin
  if umlIsNumber(V_) then
    begin
      try
          Result := StrToFloat(V_.text);
      except
          Result := _Def;
      end;
    end
  else
      Result := _Def;
end;

function umlStrToFloat(const V_: TPascalString): Double;
begin
  Result := umlStrToFloat(V_, 0);
end;

function umlMultipleMatch(IgnoreCase: Boolean; const source, target, Multiple_, Character_: TPascalString): Boolean;
label C_Proc_, MC_Proc_, MS_Proc_;
var
  uS, uT, swap_S: TPascalString;
  sC, tC, swap_C: U_Char;
  sI, tI, swap_I, sL, tL, swap_L: Integer;
begin
  sL := source.L;
  if sL = 0 then
    begin
      Result := True;
      exit;
    end;

  tL := target.L;
  if tL = 0 then
    begin
      Result := False;
      exit;
    end;

  if IgnoreCase then
    begin
      uS := source.UpperText;
      uT := target.UpperText;
    end
  else
    begin
      uS := source;
      uT := target;
    end;

  if (not umlExistsChar(@source, @Character_)) and (not umlExistsChar(@source, @Multiple_)) then
    begin
      Result := (sL = tL) and (uS = uT);
      exit;
    end;
  if sL = 1 then
    begin
      if umlMatchChar(uS[1], @Multiple_) then
          Result := True
      else
          Result := False;
      exit;
    end;
  sI := 1;
  tI := 1;
  sC := uS[sI];
  tC := uT[tI];

C_Proc_:
  while (sC = tC) and (not umlMatchChar(sC, @Character_)) and (not umlMatchChar(sC, @Multiple_)) do
    begin
      if sI = sL then
        begin
          if tI = tL then
            begin
              Result := True;
              exit;
            end;
          Result := False;
          exit;
        end;
      if tI = tL then
        begin
          inc(sI);
          if sI = sL then
            begin
              sC := uS[sI];
              Result := umlMatchChar(sC, @Multiple_) or umlMatchChar(sC, @Character_);
              exit;
            end;
          Result := False;
          exit;
        end;
      inc(sI);
      inc(tI);
      sC := uS[sI];
      tC := uT[tI];
    end;

MC_Proc_:
  while umlMatchChar(sC, @Character_) do
    begin
      if sI = sL then
        begin
          if tI = tL then
            begin
              Result := True;
              exit;
            end;
          Result := False;
          exit;
        end;
      if tI = tL then
        begin
          inc(sI);
          sC := uS[sI];
          if (sI = sL) and ((umlMatchChar(sC, @Multiple_)) or (umlMatchChar(sC, @Character_))) then
            begin
              Result := True;
              exit;
            end;
          Result := False;
          exit;
        end;
      inc(sI);
      inc(tI);
      sC := uS[sI];
      tC := uT[tI];
    end;

MS_Proc_:
  if umlMatchChar(sC, @Multiple_) then
    begin
      if sI = sL then
        begin
          Result := True;
          exit;
        end;
      inc(sI);
      sC := uS[sI];

      while (umlMatchChar(sC, @Multiple_)) or (umlMatchChar(sC, @Character_)) do
        begin
          if sI = sL then
            begin
              Result := True;
              exit;
            end;
          inc(sI);
          sC := uS[sI];
          while umlMatchChar(sC, @Character_) do
            begin
              if sI = sL then
                begin
                  Result := True;
                  exit;
                end;
              inc(sI);
              sC := uS[sI];
            end;
        end;
      swap_S := umlCopyStr(uS, sI, sL + 1);
      swap_L := swap_S.L;
      if swap_L = 0 then
        begin
          Result := (uS[sI] = Multiple_);
          exit;
        end;
      swap_I := 1;
      swap_C := swap_S[swap_I];
      while (not umlMatchChar(swap_C, @Character_)) and (not umlMatchChar(swap_C, @Multiple_)) and (swap_I < swap_L) do
        begin
          inc(swap_I);
          swap_C := swap_S[swap_I];
        end;
      if (umlMatchChar(swap_C, @Character_)) or (umlMatchChar(swap_C, @Multiple_)) then
          swap_S := umlCopyStr(swap_S, 1, swap_I)
      else
        begin
          swap_S := umlCopyStr(swap_S, 1, swap_I + 1);
          if swap_S = '' then
            begin
              Result := False;
              exit;
            end;
          swap_L := swap_S.L;
          swap_I := 1;
          swap_C := swap_S[swap_L];
          tC := uT[tL];
          while swap_C = tC do
            begin
              if swap_I = swap_L then
                begin
                  Result := True;
                  exit;
                end;
              if swap_I = tL then
                begin
                  Result := False;
                  exit;
                end;
              swap_C := swap_S[(swap_L) - swap_I];
              tC := uT[(tL) - swap_I];
              inc(swap_I);
            end;
          Result := False;
          exit;
        end;
      swap_C := swap_S[1];
      swap_I := 1;
      swap_L := swap_S.L;
      while swap_I <= swap_L do
        begin
          if (tI - 1) + swap_I > tL then
            begin
              Result := False;
              exit;
            end;
          swap_C := swap_S[swap_I];
          tC := uT[(tI - 1) + swap_I];
          while swap_C <> tC do
            begin
              if (tI + swap_L) > tL then
                begin
                  Result := False;
                  exit;
                end;
              inc(tI);
              swap_I := 1;
              swap_C := swap_S[swap_I];
              tC := uT[(tI - 1) + swap_I];
            end;
          inc(swap_I);
        end;
      tI := (tI - 1) + swap_L;
      sI := (sI - 1) + swap_L;
      tC := swap_C;
      sC := swap_C;
    end;

  if sC = tC then
      goto C_Proc_
  else if umlMatchChar(sC, @Character_) then
      goto MC_Proc_
  else if umlMatchChar(sC, @Multiple_) then
      goto MS_Proc_
  else
      Result := False;
end;

function umlMultipleMatch(IgnoreCase: Boolean; const source, target: TPascalString): Boolean;
begin
  if (source.L > 0) and (source.text <> '*') then
      Result := umlMultipleMatch(IgnoreCase, source, target, '*', '?')
  else
      Result := True;
end;

function umlMultipleMatch(const source, target: TPascalString): Boolean;
var
  fi: TArrayPascalString;
begin
  if (source.L > 0) and (source.text <> '*') then
    begin
      umlGetSplitArray(source, fi, ';');
      Result := umlMultipleMatch(fi, target);
    end
  else
      Result := True;
end;

function umlMultipleMatch(const source: array of TPascalString; const target: TPascalString): Boolean;
var
  i: Integer;
begin
  Result := False;
  if target.L > 0 then
    begin
      if high(source) >= 0 then
        begin
          Result := False;
          for i := low(source) to high(source) do
            begin
              Result := umlMultipleMatch(True, source[i], target);
              if Result then
                  exit;
            end;
        end
      else
          Result := True;
    end;
end;

function umlMultipleMatch(const source: TPascalStringList; const target: TPascalString): Boolean;
var
  i: Integer;
begin
  Result := False;
  if target.L > 0 then
    begin
      if source.Count > 0 then
        begin
          Result := False;
          for i := 0 to source.Count - 1 do
            begin
              Result := umlMultipleMatch(True, source[i], target);
              if Result then
                  exit;
            end;
        end
      else
          Result := True;
    end;
end;

function umlSearchMatch(const source, target: TPascalString): Boolean;
var
  sArry: TArrayPascalString;
begin
  if (source.L > 0) and (source.text <> '*') then
    begin
      umlGetSplitArray(source, sArry, ';,');
      Result := umlSearchMatch(sArry, target);
    end
  else
      Result := True;
end;

function umlSearchMatch(const source, exclude, target: TPascalString): Boolean;
var
  sArry, eArry: TArrayPascalString;
begin
  if (source.L > 0) and (source.text <> '*') then
      umlGetSplitArray(source, sArry, ';,')
  else
      SetLength(sArry, 0);

  if (exclude.L > 0) and (exclude.text <> '*') then
      umlGetSplitArray(exclude, eArry, ';,')
  else
      SetLength(eArry, 0);

  Result := umlSearchMatch(sArry, eArry, target);
  SetLength(sArry, 0);
  SetLength(eArry, 0);
end;

function umlSearchMatch(const source: TArrayPascalString; target: TPascalString): Boolean;
var
  i: Integer;
begin
  Result := False;
  if target.L > 0 then
    begin
      if length(source) > 0 then
        begin
          for i := low(source) to high(source) do
            begin
              Result := (target.GetPos(source[i]) > 0) or (umlMultipleMatch(True, source[i], target));
              if Result then
                  exit;
            end;
        end
      else
          Result := True;
    end;
end;

function umlSearchMatch(const source, exclude: TArrayPascalString; target: TPascalString): Boolean;
var
  i: Integer;
begin
  Result := False;
  if target.L > 0 then
    begin
      if length(exclude) > 0 then
        for i := low(exclude) to high(exclude) do
          if (target.GetPos(exclude[i]) > 0) or (umlMultipleMatch(True, exclude[i], target)) then
              exit;

      if length(source) > 0 then
        begin
          for i := low(source) to high(source) do
            if (target.GetPos(source[i]) > 0) or (umlMultipleMatch(True, source[i], target)) then
                exit(True);
        end
      else
          Result := True;
    end;
end;

function umlMatchFileInfo(const exp_, sour_, dest_: TPascalString): Boolean;
const
  prefix = '<prefix>';
  postfix = '<postfix>';
var
  sour, dest, dest_prefix, dest_postfix, n: TPascalString;
begin
  sour := umlGetFileName(sour_);
  dest := umlGetFileName(dest_);
  dest_prefix := umlChangeFileExt(dest, '');
  dest_postfix := umlGetFileExt(dest);
  n := umlStringReplace(exp_, prefix, dest_prefix, True);
  n := umlStringReplace(n, postfix, dest_postfix, True);
  Result := umlMultipleMatch(n, sour);
  sour := '';
  dest := '';
  dest_prefix := '';
  dest_postfix := '';
  n := '';
end;

function umlGetDateTimeStr(NowDateTime: TDateTime): TPascalString;
var
  Year, Month, Day: Word;
  Hour, min_, Sec, MSec: Word;
begin
  DecodeDate(NowDateTime, Year, Month, Day);
  DecodeTime(NowDateTime, Hour, min_, Sec, MSec);
  Result := IntToStr(Year) + '-' + IntToStr(Month) + '-' + IntToStr(Day) + ' ' + IntToStr(Hour) + '-' + IntToStr(min_) + '-' + IntToStr(Sec) + '-' + IntToStr(MSec);
end;

function umlDecodeTimeToStr(NowDateTime: TDateTime): TPascalString;
var
  Year, Month, Day: Word;
  Hour, min_, Sec, MSec: Word;
begin
  DecodeDate(NowDateTime, Year, Month, Day);
  DecodeTime(NowDateTime, Hour, min_, Sec, MSec);
  Result := IntToHex(Year, 4) + IntToHex(Month, 2) +
    IntToHex(Day, 2) + IntToHex(Hour, 1) + IntToHex(min_, 2) +
    IntToHex(Sec, 2) + IntToHex(MSec, 3);
end;

function umlGenerate_Random_Name: TPascalString;
type
  TDecode_Data_ = packed record
    Year, Month, Day: Word;
    Hour, min_, Sec, MSec: Word;
    i64: Int64;
    i32: Integer;
  end;
var
  D: TDateTime;
  R: TDecode_Data_;
begin
  D := umlNow();
  with R do
    begin
      DecodeDate(D, Year, Month, Day);
      DecodeTime(D, Hour, min_, Sec, MSec);
      i64 := TMT19937.Rand64;
      i32 := TMT19937.Rand32;
    end;
  Result := umlMD5String(@R, SizeOf(TDecode_Data_));
end;

function umlGenerate_Random_Name(rand_data: Int64): TPascalString;
type
  TDecode_Data_ = packed record
    Year, Month, Day: Word;
    Hour, min_, Sec, MSec: Word;
    i64: Int64;
    i32: Integer;
    user: Int64;
  end;
var
  D: TDateTime;
  R: TDecode_Data_;
begin
  D := umlNow();
  with R do
    begin
      DecodeDate(D, Year, Month, Day);
      DecodeTime(D, Hour, min_, Sec, MSec);
      i64 := TMT19937.Rand64;
      i32 := TMT19937.Rand32;
      user := rand_data;
    end;
  Result := umlMD5String(@R, SizeOf(TDecode_Data_));
end;

function umlDecodeDateTimeToInt64(NowDateTime: TDateTime): Int64;
begin
  Result := DateTimeToUnix(NowDateTime, True);
end;

procedure TBatch.Swap_(var inst: TBatch);
begin
  sour.SwapInstance(inst.sour);
  dest.SwapInstance(inst.dest);
  TSwap<Integer>.Do_(sum, inst.sum);
end;

function umlBuildBatch(L: THashStringList): TArrayBatch;
var
  arry: TArrayBatch;
  i: Integer;
  p: PHashListData;
begin
  SetLength(arry, L.Count);
  if L.HashList.Count > 0 then
    begin
      i := 0;
      p := L.HashList.FirstPtr;
      while i < L.HashList.Count do
        begin
          arry[i].sour := p^.OriginName;
          arry[i].dest := PHashStringListData(p^.Data)^.v;
          inc(i);
          p := p^.Next;
        end;
    end;
  Result := arry;
end;

function umlBuildBatch(L: THashVariantList): TArrayBatch;
var
  arry: TArrayBatch;
  i: Integer;
  p: PHashListData;
begin
  SetLength(arry, L.Count);
  if L.HashList.Count > 0 then
    begin
      i := 0;
      p := L.HashList.FirstPtr;
      while i < L.HashList.Count do
        begin
          arry[i].sour := p^.OriginName;
          arry[i].dest := VarToStr(PHashVariantListData(p^.Data)^.v);
          inc(i);
          p := p^.Next;
        end;
    end;
  Result := arry;
end;

procedure umlClearBatch(var arry: TArrayBatch);
var
  i: Integer;
begin
  for i := low(arry) to high(arry) do
    begin
      arry[i].sour := '';
      arry[i].dest := '';
    end;
  SetLength(arry, 0);
end;

procedure umlSortBatch(var arry: TArrayBatch);

  function CompareInt_(const i1, i2: Integer): ShortInt;
  begin
    if i1 = i2 then
        Result := 0
    else if i1 < i2 then
        Result := -1
    else
        Result := 1;
  end;

  function Compare_(var Left, Right: TBatch): ShortInt;
  begin
    Result := CompareInt_(Right.sour.L, Left.sour.L);
  end;

  procedure fastSort_(L, R: Integer);
  var
    i, j: Integer;
    p: TBatch;
  begin
    if L < R then
      begin
        repeat
          if (R - L) = 1 then
            begin
              if Compare_(arry[L], arry[R]) > 0 then
                  arry[L].Swap_(arry[R]);
              break;
            end;
          i := L;
          j := R;
          p := arry[(L + R) shr 1];
          repeat
            while Compare_(arry[i], p) < 0 do
                inc(i);
            while Compare_(arry[j], p) > 0 do
                dec(j);
            if i <= j then
              begin
                if i <> j then
                    arry[i].Swap_(arry[j]);
                inc(i);
                dec(j);
              end;
          until i > j;
          if (j - L) > (R - i) then
            begin
              if i < R then
                  fastSort_(i, R);
              R := j;
            end
          else
            begin
              if L < j then
                  fastSort_(L, j);
              L := i;
            end;
        until L >= R;
      end;
  end;

begin
  if length(arry) > 1 then
      fastSort_(0, length(arry) - 1);
end;

function umlCharIsSymbol(C: SystemChar): Boolean;
begin
  Result := CharIn(C,
    [#13, #10, #9, #32, #46, #44, #43, #45, #42, #47, #40, #41, #59, #58, #61, #35, #64, #94,
      #38, #37, #33, #34, #91, #93, #60, #62, #63, #123, #125, #39, #36, #124]);
end;

function umlCharIsSymbol(C: SystemChar; const CustomSymbol_: TArrayChar): Boolean;
begin
  Result := CharIn(C, CustomSymbol_);
end;

function umlIsWord(p: PPascalString; bPos, ePos: Integer): Boolean;
begin
  if (bPos > ePos) or (bPos < 1) or (ePos > p^.L) then
      Result := False
  else if bPos = 1 then
    begin
      if ePos = p^.L then
          Result := True
      else
          Result := umlCharIsSymbol(p^[ePos + 1]);
    end
  else if ePos = p^.L then
      Result := umlCharIsSymbol(p^[bPos - 1])
  else
      Result := umlCharIsSymbol(p^[bPos - 1]) and umlCharIsSymbol(p^[ePos + 1]);
end;

function umlIsWord(S: TPascalString; bPos, ePos: Integer): Boolean;
begin
  Result := umlIsWord(@S, bPos, ePos);
end;

function umlExtractWord(S: TPascalString): TArrayPascalString;
var
  i, bPos, ePos, j: Integer;
begin
  SetLength(Result, 0);
  if S.L = 0 then
      exit;

  // compute buff size
  j := 0;
  i := 1;
  while i <= S.L do
    begin
      bPos := i;
      while bPos <= S.L do
        if umlCharIsSymbol(S[bPos]) then
            inc(bPos)
        else
            break;

      ePos := bPos;
      while ePos <= S.L do
        if not umlCharIsSymbol(S[ePos]) then
            inc(ePos)
        else
            break;

      if ePos > bPos then
          inc(j);
      i := ePos;
    end;

  if j = 0 then
      exit;

  // fill buff
  SetLength(Result, j);
  j := 0;
  i := 1;
  while i <= S.L do
    begin
      bPos := i;
      while bPos <= S.L do
        if umlCharIsSymbol(S[bPos]) then
            inc(bPos)
        else
            break;

      ePos := bPos;
      while ePos <= S.L do
        if not umlCharIsSymbol(S[ePos]) then
            inc(ePos)
        else
            break;

      if ePos > bPos then
        begin
          Result[j] := S.GetString(bPos, ePos);
          inc(j);
        end;
      i := ePos;
    end;
end;

function umlExtractWord(S: TPascalString; const CustomSymbol_: TArrayChar): TArrayPascalString;
var
  i, bPos, ePos, j: Integer;
begin
  SetLength(Result, 0);
  if S.L = 0 then
      exit;

  // compute buff size
  j := 0;
  i := 1;
  while i <= S.L do
    begin
      bPos := i;
      while bPos <= S.L do
        if umlCharIsSymbol(S[bPos], CustomSymbol_) then
            inc(bPos)
        else
            break;

      ePos := bPos;
      while ePos <= S.L do
        if not umlCharIsSymbol(S[ePos], CustomSymbol_) then
            inc(ePos)
        else
            break;

      if ePos > bPos then
          inc(j);
      i := ePos;
    end;

  if j = 0 then
      exit;

  // fill buff
  SetLength(Result, j);
  j := 0;
  i := 1;
  while i <= S.L do
    begin
      bPos := i;
      while bPos <= S.L do
        if umlCharIsSymbol(S[bPos], CustomSymbol_) then
            inc(bPos)
        else
            break;

      ePos := bPos;
      while ePos <= S.L do
        if not umlCharIsSymbol(S[ePos], CustomSymbol_) then
            inc(ePos)
        else
            break;

      if ePos > bPos then
        begin
          Result[j] := S.GetString(bPos, ePos);
          inc(j);
        end;
      i := ePos;
    end;
end;

function umlBatchSum(p: PPascalString; var arry: TArrayBatch; OnlyWord, IgnoreCase: Boolean; bPos, ePos: Integer; Info: TBatchInfoList): Integer;
  function Match_(Pos_: Integer): Integer;
  var
    i: Integer;
  begin
    Result := -1;
    for i := Low(arry) to high(arry) do
      if (arry[i].sour.L > 0) and ((not OnlyWord) or umlIsWord(p, Pos_, Pos_ + arry[i].sour.L - 1))
        and p^.ComparePos(Pos_, @arry[i].sour, IgnoreCase) then
          exit(i);
  end;

var
  i, R, BP, EP: Integer;
  found_: Boolean;
  BatchInfo: TBatchInfo;
begin
  Result := 0;
  if p^.L = 0 then
      exit;

  if (ePos <= 0) or (ePos > p^.L) then
      EP := p^.L
  else
      EP := ePos;

  if bPos < 1 then
      BP := 1
  else if bPos > EP then
      BP := EP
  else
      BP := bPos;

  for i := low(arry) to high(arry) do
      arry[i].sum := 0;

  i := 1;
  while i <= p^.L do
    begin
      found_ := False;
      if (i >= BP) and (i <= EP) then
        begin
          R := Match_(i);
          found_ := R >= 0;
          if found_ then
            begin
              if Info <> nil then
                begin
                  BatchInfo.Batch := R;
                  BatchInfo.sour_bPos := i;
                  BatchInfo.sour_ePos := i + arry[R].sour.L - 1;
                  BatchInfo.dest_bPos := BatchInfo.sour_bPos;
                  BatchInfo.dest_ePos := BatchInfo.sour_ePos;
                  Info.add(BatchInfo);
                end;
              inc(i, arry[R].sour.L);
              inc(arry[R].sum);
              inc(Result);
            end;
        end;
      if not found_ then
        begin
          inc(i);
        end;
    end;
end;

function umlBatchSum(S: TPascalString; var arry: TArrayBatch; OnlyWord, IgnoreCase: Boolean; bPos, ePos: Integer; Info: TBatchInfoList): Integer;
begin
  Result := umlBatchSum(@S, arry, OnlyWord, IgnoreCase, bPos, ePos, Info);
end;

function umlBatchSum(S: TPascalString; var arry: TArrayBatch; OnlyWord, IgnoreCase: Boolean; bPos, ePos: Integer): Integer;
begin
  Result := umlBatchSum(@S, arry, OnlyWord, IgnoreCase, bPos, ePos, nil);
end;

function umlBatchReplace(p: PPascalString; var arry: TArrayBatch; OnlyWord, IgnoreCase: Boolean; bPos, ePos: Integer; Info: TBatchInfoList; On_P: TOnBatchProc): TPascalString;
  function Match_(Pos_: Integer): Integer;
  var
    i: Integer;
  begin
    Result := -1;
    for i := Low(arry) to high(arry) do
      if (arry[i].sour.L > 0) and ((not OnlyWord) or umlIsWord(p, Pos_, Pos_ + arry[i].sour.L - 1))
        and p^.ComparePos(Pos_, @arry[i].sour, IgnoreCase) then
          exit(i);
  end;

var
  i, R, BP, EP: Integer;
  found_: Boolean;
  m64: TMem64;
  BatchInfo: TBatchInfo;
begin
  Result := '';
  if p^.L = 0 then
      exit;
  m64 := TMem64.CustomCreate(p^.L);

  if (ePos <= 0) or (ePos > p^.L) then
      EP := p^.L
  else
      EP := ePos;

  if bPos < 1 then
      BP := 1
  else if bPos > EP then
      BP := EP
  else
      BP := bPos;

  for i := low(arry) to high(arry) do
      arry[i].sum := 0;

  i := 1;
  while i <= p^.L do
    begin
      found_ := False;
      if (i >= BP) and (i <= EP) then
        begin
          R := Match_(i);
          found_ := R >= 0;
          if found_ and Assigned(On_P) then
              On_P(i, i + (arry[R].sour.L - 1), @arry[R].sour, @arry[R].dest, found_);
          if found_ then
            begin
              if Info <> nil then
                begin
                  BatchInfo.Batch := R;
                  BatchInfo.sour_bPos := i;
                  BatchInfo.sour_ePos := i + (arry[R].sour.L - 1);
                  BatchInfo.dest_bPos := m64.Size div SystemCharSize + 1;
                  BatchInfo.dest_ePos := BatchInfo.dest_bPos + (arry[R].dest.L - 1);
                  Info.add(BatchInfo);
                end;
              if arry[R].dest.L > 0 then
                  m64.Write64(arry[R].dest.buff[0], SystemCharSize * arry[R].dest.L);
              inc(arry[R].sum);
              inc(i, arry[R].sour.L);
            end;
        end;
      if not found_ then
        begin
          m64.Write64(p^.buff[i - 1], SystemCharSize);
          inc(i);
        end;
    end;
  Result.L := m64.Size div SystemCharSize;
  if Result.L > 0 then
      CopyPtr(m64.Memory, @Result.buff[0], m64.Size);
  DisposeObject(m64);
end;

function umlBatchReplace(S: TPascalString; var arry: TArrayBatch; OnlyWord, IgnoreCase: Boolean; bPos, ePos: Integer; Info: TBatchInfoList; On_P: TOnBatchProc): TPascalString;
begin
  Result := umlBatchReplace(@S, arry, OnlyWord, IgnoreCase, bPos, ePos, Info, On_P);
end;

function umlBatchReplace(S: TPascalString; var arry: TArrayBatch; OnlyWord, IgnoreCase: Boolean; bPos, ePos: Integer; Info: TBatchInfoList): TPascalString;
begin
  Result := umlBatchReplace(@S, arry, OnlyWord, IgnoreCase, bPos, ePos, Info, nil);
end;

function umlBatchReplace(S: TPascalString; var arry: TArrayBatch; OnlyWord, IgnoreCase: Boolean; bPos, ePos: Integer): TPascalString;
begin
  Result := umlBatchReplace(@S, arry, OnlyWord, IgnoreCase, bPos, ePos, nil, nil);
end;

function umlReplaceSum(p: PPascalString; Pattern: TPascalString; OnlyWord, IgnoreCase: Boolean; bPos, ePos: Integer; Info: TBatchInfoList): Integer;
var
  i, BP, EP: Integer;
  found_: Boolean;
  BatchInfo: TBatchInfo;
begin
  Result := 0;
  if p^.L = 0 then
      exit;

  if (ePos <= 0) or (ePos > p^.L) then
      EP := p^.L
  else
      EP := ePos;

  if bPos < 1 then
      BP := 1
  else if bPos > EP then
      BP := EP
  else
      BP := bPos;

  i := 1;
  while i <= p^.L do
    begin
      found_ := False;
      if (i >= BP) and (i <= EP) then
        begin
          found_ := ((not OnlyWord) or umlIsWord(p, i, i + Pattern.L - 1)) and p^.ComparePos(i, @Pattern, IgnoreCase);
          if found_ then
            begin
              if Info <> nil then
                begin
                  BatchInfo.Batch := -1;
                  BatchInfo.sour_bPos := i;
                  BatchInfo.sour_ePos := BatchInfo.sour_bPos + (Pattern.L - 1);
                  BatchInfo.dest_bPos := BatchInfo.sour_bPos;
                  BatchInfo.dest_ePos := BatchInfo.sour_ePos;
                  Info.add(BatchInfo);
                end;
              inc(i, Pattern.L);
              inc(Result);
            end;
        end;
      if not found_ then
        begin
          inc(i);
        end;
    end;
end;

function umlReplaceSum(S, Pattern: TPascalString; OnlyWord, IgnoreCase: Boolean; bPos, ePos: Integer; Info: TBatchInfoList): Integer;
begin
  Result := umlReplaceSum(@S, Pattern, OnlyWord, IgnoreCase, bPos, ePos, Info);
end;

function umlReplace(p: PPascalString; OldPattern, NewPattern: TPascalString; OnlyWord, IgnoreCase: Boolean; bPos, ePos: Integer; Info: TBatchInfoList; On_P: TOnBatchProc): TPascalString;
var
  i, BP, EP: Integer;
  found_: Boolean;
  m64: TMem64;
  BatchInfo: TBatchInfo;
begin
  Result := '';
  if p^.L = 0 then
      exit;
  if OldPattern.L = 0 then
    begin
      Result := p^;
      exit;
    end;
  m64 := TMem64.CustomCreate(p^.L);

  if (ePos <= 0) or (ePos > p^.L) then
      EP := p^.L
  else
      EP := ePos;

  if bPos < 1 then
      BP := 1
  else if bPos > EP then
      BP := EP
  else
      BP := bPos;

  i := 1;
  while i <= p^.L do
    begin
      found_ := False;
      if (i >= BP) and (i <= EP) then
        begin
          found_ := ((not OnlyWord) or umlIsWord(p, i, i + OldPattern.L - 1)) and p^.ComparePos(i, @OldPattern, IgnoreCase);
          if found_ and Assigned(On_P) then
              On_P(i, i + (OldPattern.L - 1), @OldPattern, @NewPattern, found_);
          if found_ then
            begin
              if Info <> nil then
                begin
                  BatchInfo.Batch := -1;
                  BatchInfo.sour_bPos := i;
                  BatchInfo.sour_ePos := i + (OldPattern.L - 1);
                  BatchInfo.dest_bPos := m64.Size div SystemCharSize + 1;
                  BatchInfo.dest_ePos := BatchInfo.dest_bPos + (NewPattern.L - 1);
                  Info.add(BatchInfo);
                end;
              m64.Write64(NewPattern.buff[0], SystemCharSize * NewPattern.L);
              inc(i, OldPattern.L);
            end;
        end;
      if not found_ then
        begin
          m64.Write64(p^.buff[i - 1], SystemCharSize);
          inc(i);
        end;
    end;
  Result.L := m64.Size div SystemCharSize;
  if Result.L > 0 then
      CopyPtr(m64.Memory, @Result.buff[0], m64.Size);
  DisposeObject(m64);
end;

function umlReplace(S, OldPattern, NewPattern: TPascalString; OnlyWord, IgnoreCase: Boolean; bPos, ePos: Integer; Info: TBatchInfoList; On_P: TOnBatchProc): TPascalString;
begin
  Result := umlReplace(@S, OldPattern, NewPattern, OnlyWord, IgnoreCase, bPos, ePos, Info, On_P);
end;

function umlReplace(S, OldPattern, NewPattern: TPascalString; OnlyWord, IgnoreCase: Boolean; bPos, ePos: Integer; Info: TBatchInfoList): TPascalString;
begin
  Result := umlReplace(@S, OldPattern, NewPattern, OnlyWord, IgnoreCase, bPos, ePos, Info, nil);
end;

function umlReplace(p: PPascalString; OldPattern, NewPattern: TPascalString; OnlyWord, IgnoreCase: Boolean): TPascalString;
var
  i, R: Integer;
  m64: TMem64;
begin
  Result := '';
  if p^.L = 0 then
      exit;
  if OldPattern.L = 0 then
    begin
      Result := p^;
      exit;
    end;
  m64 := TMem64.CustomCreate(p^.L);
  i := 1;
  while i <= p^.L do
    begin
      if ((not OnlyWord) or umlIsWord(p, i, i + OldPattern.L - 1)) and p^.ComparePos(i, @OldPattern, IgnoreCase) then
        begin
          m64.Write64(NewPattern.buff[0], SystemCharSize * NewPattern.L);
          inc(i, OldPattern.L);
        end
      else
        begin
          m64.Write64(p^.buff[i - 1], SystemCharSize);
          inc(i);
        end;
    end;
  Result.L := m64.Size div SystemCharSize;
  if Result.L > 0 then
      CopyPtr(m64.Memory, @Result.buff[0], m64.Size);
  DisposeObject(m64);
end;

function umlReplace(S, OldPattern, NewPattern: TPascalString; OnlyWord, IgnoreCase: Boolean): TPascalString;
begin
  Result := umlReplace(@S, OldPattern, NewPattern, OnlyWord, IgnoreCase);
end;

function umlComputeTextPoint(p: PPascalString; Pos_: Integer): TPoint;
var
  i, j: Integer;
begin
  Result.X := 1;
  Result.Y := 1;
  if Pos_ < p^.L then
      j := Pos_
  else
      j := p^.L;
  for i := 1 to j do
    if p^[i] = #10 then
      begin
        Result.X := 1;
        inc(Result.Y);
      end
    else if p^[i] = #13 then
        Result.X := 0
    else
        inc(Result.X);
end;

function umlStringReplace(const S, OldPattern, NewPattern: TPascalString; IgnoreCase: Boolean): TPascalString;
var
  f: TReplaceFlags;
begin
  f := [rfReplaceAll];
  if IgnoreCase then
      f := f + [rfIgnoreCase];
  Result.text := StringReplace(S.text, OldPattern.text, NewPattern.text, f);
end;

function umlReplaceString(const S, OldPattern, NewPattern: TPascalString; IgnoreCase: Boolean): TPascalString;
begin
  Result := umlStringReplace(S, OldPattern, NewPattern, IgnoreCase);
end;

function umlCharReplace(const S: TPascalString; OldPattern, NewPattern: U_Char): TPascalString;
begin
  Result := S.ReplaceChar(OldPattern, NewPattern);
end;

function umlReplaceChar(const S: TPascalString; OldPattern, NewPattern: U_Char): TPascalString;
begin
  Result := S.ReplaceChar(OldPattern, NewPattern);
end;

function umlEncodeText2HTML(const psSrc: TPascalString): TPascalString;
var
  i: Integer;
begin
  Result := '';
  if psSrc.L > 0 then
    begin
      i := 1;
      while i <= psSrc.L do
        begin
          case psSrc[i] of
            ' ': Result.Append('&nbsp;');
            '<': Result.Append('&lt;');
            '>': Result.Append('&gt;');
            '&': Result.Append('&amp;');
            '"': Result.Append('&quot;');
            #9: Result.Append('&nbsp;&nbsp;&nbsp;&nbsp;');
            #13:
              begin
                if i + 1 <= psSrc.L then
                  begin
                    if psSrc[i + 1] = #10 then
                        inc(i);
                    Result.Append('<br>');
                  end
                else
                  begin
                    Result.Append('<br>');
                  end;
              end;
            #10:
              begin
                if i + 1 <= psSrc.L then
                  begin
                    if psSrc[i + 1] = #13 then
                        inc(i);
                    Result.Append('<br>');
                  end
                else
                  begin
                    Result.Append('<br>');
                  end;
              end;
            else
                Result.Append(psSrc[i]);
          end;
          inc(i);
        end;
    end;
end;

function umlURLEncode(const Data: TPascalString): TPascalString;
var
  UTF8Src: TBytes;
  B: Byte;
  Tmp: TMem64;
  S: TPascalString;
  C: SystemChar;
begin
  Tmp := TMem64.CustomCreate(Data.L);
  UTF8Src := Data.Bytes;
  for B in UTF8Src do
    if ((B >= $41) and (B <= $5A))
      or ((B >= $61) and (B <= $7A))
      or ((B >= $30) and (B <= $39))
      or (B = $2D)
      or (B = $2E)
      or (B = $5F)
      or (B = $7E)
      or (B = $2F)
      or (B = $3A) then
        Tmp.WriteUInt8(B)
    else
      begin
        S := '%' + IntToHex(B, 2);
        for C in S.buff do
            Tmp.WriteUInt8(Byte(C));
      end;
  UTF8Src := Tmp.ToBytes;
  Result.Bytes := UTF8Src;
  SetLength(UTF8Src, 0);
  DisposeObject(Tmp);
end;

function umlURLDecode(const Data: TPascalString; FormEncoded: Boolean): TPascalString;
var
  i: Integer;
  State: Byte;
  B, BV, B1: Byte;
  arry: TBytes;
  Tmp: TMem64;
const
  STATE_READ_DATA = 0;
  STATE_READ_PERCENT_ENCODED_BYTE_1 = 1;
  STATE_READ_PERCENT_ENCODED_BYTE_2 = 2;
begin
  B1 := 0;
  State := STATE_READ_DATA;
  arry := Data.Bytes;
  Tmp := TMem64.CustomCreate(length(arry));
  for i := 0 to length(arry) - 1 do
    begin
      B := arry[i];
      if State = STATE_READ_DATA then
        begin
          if B = $25 then
              State := STATE_READ_PERCENT_ENCODED_BYTE_1
          else if FormEncoded and (B = $2B) then // + sign
              Tmp.WriteUInt8($20)
          else
              Tmp.WriteUInt8(Byte(Data[FirstCharPos + i]));
        end
      else if (State = STATE_READ_PERCENT_ENCODED_BYTE_1) or (State = STATE_READ_PERCENT_ENCODED_BYTE_2) then
        begin
          if (B >= 65) and (B <= 70) then
              BV := B - 55
          else if (B >= 97) and (B <= 102) then
              BV := B - 87
          else if (B >= $30) and (B <= $39) then
              BV := B - $30
          else
              raiseInfo('Unexpected character: 0x' + IntToHex(B, 2));

          if State = STATE_READ_PERCENT_ENCODED_BYTE_1 then
            begin
              B1 := BV;
              State := STATE_READ_PERCENT_ENCODED_BYTE_2;
            end
          else
            begin
              B := (B1 shl 4) or BV;
              Tmp.WriteUInt8(B);
              State := STATE_READ_DATA;
            end;
        end;
    end;
  arry := Tmp.ToBytes;
  Result.Bytes := arry;
  SetLength(arry, 0);
  DisposeObject(Tmp);
end;

function TRTSP_RTMP_URL.Encode: U_String;
var
  zj: TZJ;
begin
  zj := TZJ.Create;
  zj.S['prefix'] := prefix;
  zj.S['user'] := user;
  zj.S['passwd'] := passwd;
  zj.S['host'] := host;
  zj.S['port'] := port;
  zj.S['path'] := path;
  Result := zj.ToJSONString(True);
  DisposeObject(zj);
end;

procedure TRTSP_RTMP_URL.Init;
begin
  prefix := '';
  user := '';
  passwd := '';
  host := '';
  port := '';
  path := '';
end;

procedure TRTSP_RTMP_URL.Decode(Data_: U_String);
var
  zj: TZJ;
begin
  Init();
  try
    zj := TZJ.Create;
    zj.ParseText(Data_);
    prefix := zj.S['prefix'];
    user := zj.S['user'];
    passwd := zj.S['passwd'];
    host := zj.S['host'];
    port := zj.S['port'];
    path := zj.S['path'];
    DisposeObject(zj);
  except
  end;
end;

function umlExtract_RTSP_RTMP_URL(const URL: TPascalString; var prefix, user, passwd, host, port, path: TPascalString): Boolean;
var
  n: U_String;
begin
  Result := False;
  n := umlTrimSpace(URL);
  if umlMultipleMatch('RTSP://*', n) then
      port := '554'
  else if umlMultipleMatch('RTMP://*', n) then
      port := '1935'
  else
      exit;
  prefix := umlGetFirstStr(n, '/') + '//';
  user := '';
  passwd := '';
  host := '';
  path := '';
  n := umlDeleteFirstStr(n, '/');
  if umlMultipleMatch('*:*@*', n) then
    begin
      { rtsp://user:password@192.168.0.1:554/media/video1 }
      { rtsp://user:password@192.168.0.1/media/video1 }
      { rtsp://user:password@192.168.0.1:554 }
      { rtsp://user:password@192.168.0.1 }
      user := umlGetFirstStr(n, ':');
      n := umlDeleteFirstStr(n, ':');
      passwd := umlGetFirstStr(n, '@');
      n := umlDeleteFirstStr(n, '@');
      if umlMultipleMatch('*:*', n) then
        begin
          host := umlGetFirstStr(n, ':');
          n := umlDeleteFirstStr(n, ':');
          if n.Exists('/') then
            begin
              port := umlGetFirstStr(n, '/');
              path := umlDeleteFirstStr(n, '/');
            end
          else
            begin
              port := n;
            end;
        end
      else
        begin
          if n.Exists('/') then
            begin
              host := umlGetFirstStr(n, '/');
              path := umlDeleteFirstStr(n, '/');
            end
          else
            begin
              host := n;
            end;
        end;
      Result := True;
    end
  else if umlMultipleMatch('*:*', n) then
    begin
      { rtsp://192.168.0.1:554 }
      { rtsp://192.168.0.1:554/media/video1 }
      host := umlGetFirstStr(n, ':');
      n := umlDeleteFirstStr(n, ':');
      if n.Exists('/') then
        begin
          port := umlGetFirstStr(n, '/');
          path := umlDeleteFirstStr(n, '/');
        end
      else
        begin
          port := n;
        end;
      Result := True;
    end
  else
    begin
      { rtsp://192.168.0.1 }
      if n.Exists('/') then
        begin
          host := umlGetFirstStr(n, '/');
          path := umlDeleteFirstStr(n, '/');
        end
      else
        begin
          host := n;
        end;
      Result := True;
    end;
end;

function umlExtract_RTSP_RTMP_URL(const URL: TPascalString; var To_: TRTSP_RTMP_URL): Boolean;
begin
  Result := umlExtract_RTSP_RTMP_URL(URL, To_.prefix, To_.user, To_.passwd, To_.host, To_.port, To_.path);
end;

function umlEncode_RTSP_RTMP_URL(prefix, user, passwd, host, port, path: TPascalString): TPascalString;
begin
  Result := prefix;
  if not umlMultipleMatch('*://', Result) then
      Result.Append('://');
  if (user <> '') and (passwd <> '') then
      Result.Append('%s:%s@', [user.text, passwd.text]);
  Result.Append(host);
  if port <> '' then
      Result.Append(':' + port);
  if path <> '' then
    begin
      if (Result.Last <> '/') and (path.First <> '/') then
          Result.Append('/' + path)
      else
          Result.Append(path);
    end;
end;

function umlRemove_Passwd_RTSP_RTMP_URL(const URL: TPascalString): TPascalString;
var
  prefix, user, passwd, host, port, path: TPascalString;
begin
  if umlExtract_RTSP_RTMP_URL(URL, prefix, user, passwd, host, port, path) then
      Result := umlEncode_RTSP_RTMP_URL(prefix, '', '', host, port, path)
  else
      Result := URL;
end;

function B64EstimateEncodedSize(cont: TBase64Context; InSize: Integer): Integer;
begin
  Result := ((InSize + 2) div 3) shl 2;
  if (cont.EOLSize > 0) and (cont.LineSize > 0) then
    begin
      Result := Result + ((Result + cont.LineSize - 1) div cont.LineSize) * cont.EOLSize;
      if not cont.TrailingEol then
          Result := Result - cont.EOLSize;
    end;
end;

function B64InitializeDecoding(var cont: TBase64Context; LiberalMode: Boolean): Boolean;
begin
  cont.TailBytes := 0;
  cont.EQUCount := 0;
  cont.LiberalMode := LiberalMode;

  Result := True;
end;

function B64InitializeEncoding(var cont: TBase64Context; LineSize: Integer; fEOL: TBase64EOLMarker; TrailingEol: Boolean): Boolean;
begin

  Result := False;
  cont.TailBytes := 0;
  cont.LineSize := LineSize;
  cont.LineWritten := 0;
  cont.EQUCount := 0;
  cont.TrailingEol := TrailingEol;
  cont.PutFirstEol := False;

  if LineSize < 4 then
      exit;

  case fEOL of
    emCRLF:
      begin
        cont.fEOL[0] := $0D;
        cont.fEOL[1] := $0A;
        cont.EOLSize := 2;
      end;
    emCR:
      begin
        cont.fEOL[0] := $0D;
        cont.EOLSize := 1;
      end;
    emLF:
      begin
        cont.fEOL[0] := $0A;
        cont.EOLSize := 1;
      end;
    else
        cont.EOLSize := 0;
  end;

  Result := True;
end;

function B64Encode(var cont: TBase64Context; buffer: PByte; Size: Integer; OutBuffer: PByte; var OutSize: Integer): Boolean;
var
  EstSize, i, Chunks: Integer;
  PreserveLastEol: Boolean;
begin
  PreserveLastEol := False;

  EstSize := ((Size + cont.TailBytes) div 3) shl 2;
  if (cont.LineSize > 0) and (cont.EOLSize > 0) then
    begin
      if (EstSize > 0) and ((cont.LineWritten + EstSize) mod cont.LineSize = 0) and
        ((cont.TailBytes + Size) mod 3 = 0) then
          PreserveLastEol := True;
      EstSize := EstSize + ((EstSize + cont.LineWritten) div cont.LineSize) * cont.EOLSize;
      if PreserveLastEol then
          EstSize := EstSize - cont.EOLSize;
    end;
  if cont.PutFirstEol then
      EstSize := EstSize + cont.EOLSize;

  if OutSize < EstSize then
    begin
      OutSize := EstSize;
      Result := False;
      exit;
    end;

  OutSize := EstSize;

  if cont.PutFirstEol then
    begin
      CopyPtr(@cont.fEOL[0], OutBuffer, cont.EOLSize);
      inc(OutBuffer, cont.EOLSize);
      cont.PutFirstEol := False;
    end;

  if Size + cont.TailBytes < 3 then
    begin
      for i := 0 to Size - 1 do
          cont.Tail[cont.TailBytes + i] := PBase64ByteArray(buffer)^[i];
      inc(cont.TailBytes, Size);
      Result := True;
      exit;
    end;

  if cont.TailBytes > 0 then
    begin
      for i := 0 to 2 - cont.TailBytes do
          cont.Tail[cont.TailBytes + i] := PBase64ByteArray(buffer)^[i];

      inc(buffer, 3 - cont.TailBytes);
      dec(Size, 3 - cont.TailBytes);

      cont.TailBytes := 0;

      cont.OutBuf[0] := Base64Symbols[cont.Tail[0] shr 2];
      cont.OutBuf[1] := Base64Symbols[((cont.Tail[0] and 3) shl 4) or (cont.Tail[1] shr 4)];
      cont.OutBuf[2] := Base64Symbols[((cont.Tail[1] and $F) shl 2) or (cont.Tail[2] shr 6)];
      cont.OutBuf[3] := Base64Symbols[cont.Tail[2] and $3F];

      if (cont.LineSize = 0) or (cont.LineWritten + 4 < cont.LineSize) then
        begin
          CopyPtr(@cont.OutBuf[0], OutBuffer, 4);
          inc(OutBuffer, 4);
          inc(cont.LineWritten, 4);
        end
      else
        begin
          i := cont.LineSize - cont.LineWritten;
          CopyPtr(@cont.OutBuf[0], OutBuffer, i);
          inc(OutBuffer, i);
          if (Size > 0) or (i < 4) or (not PreserveLastEol) then
            begin
              CopyPtr(@cont.fEOL[0], OutBuffer, cont.EOLSize);
              inc(OutBuffer, cont.EOLSize);
            end;
          CopyPtr(@cont.OutBuf[i], OutBuffer, 4 - i);
          inc(OutBuffer, 4 - i);
          cont.LineWritten := 4 - i;
        end;
    end;

  while Size >= 3 do
    begin
      if cont.LineSize > 0 then
        begin
          Chunks := (cont.LineSize - cont.LineWritten) shr 2;
          if Chunks > Size div 3 then
              Chunks := Size div 3;
        end
      else
          Chunks := Size div 3;

      for i := 0 to Chunks - 1 do
        begin
          OutBuffer^ := Base64Symbols[PBase64ByteArray(buffer)^[0] shr 2];
          inc(OutBuffer);
          PByte(OutBuffer)^ := Base64Symbols[((PBase64ByteArray(buffer)^[0] and 3) shl 4) or (PBase64ByteArray(buffer)^[1] shr 4)];
          inc(OutBuffer);
          PByte(OutBuffer)^ := Base64Symbols[((PBase64ByteArray(buffer)^[1] and $F) shl 2) or (PBase64ByteArray(buffer)^[2] shr 6)];
          inc(OutBuffer);
          PByte(OutBuffer)^ := Base64Symbols[PBase64ByteArray(buffer)^[2] and $3F];
          inc(OutBuffer);
          inc(buffer, 3);
        end;

      dec(Size, 3 * Chunks);

      if cont.LineSize > 0 then
        begin
          inc(cont.LineWritten, Chunks shl 2);

          if (Size >= 3) and (cont.LineSize - cont.LineWritten > 0) then
            begin
              cont.OutBuf[0] := Base64Symbols[PBase64ByteArray(buffer)^[0] shr 2];
              cont.OutBuf[1] := Base64Symbols[((PBase64ByteArray(buffer)^[0] and 3) shl 4) or (PBase64ByteArray(buffer)^[1] shr 4)];
              cont.OutBuf[2] := Base64Symbols[((PBase64ByteArray(buffer)^[1] and $F) shl 2) or (PBase64ByteArray(buffer)^[2] shr 6)];
              cont.OutBuf[3] := Base64Symbols[PBase64ByteArray(buffer)^[2] and $3F];
              inc(buffer, 3);

              dec(Size, 3);

              i := cont.LineSize - cont.LineWritten;

              CopyPtr(@cont.OutBuf[0], OutBuffer, i);
              inc(OutBuffer, i);
              if (cont.EOLSize > 0) and ((i < 4) or (Size > 0) or (not PreserveLastEol)) then
                begin
                  CopyPtr(@cont.fEOL[0], OutBuffer, cont.EOLSize);
                  inc(OutBuffer, cont.EOLSize);
                end;

              CopyPtr(@cont.OutBuf[i], OutBuffer, 4 - i);
              inc(OutBuffer, 4 - i);

              cont.LineWritten := 4 - i;
            end
          else
            if cont.LineWritten = cont.LineSize then
            begin
              cont.LineWritten := 0;
              if (cont.EOLSize > 0) and ((Size > 0) or (not PreserveLastEol)) then
                begin
                  CopyPtr(@cont.fEOL[0], OutBuffer, cont.EOLSize);
                  inc(OutBuffer, cont.EOLSize);
                end;
            end;
        end;
    end;

  if Size > 0 then
    begin
      CopyPtr(buffer, @cont.Tail[0], Size);
      cont.TailBytes := Size;
    end
  else
    if PreserveLastEol then
      cont.PutFirstEol := True;

  Result := True;
end;

function B64Decode(var cont: TBase64Context; buffer: PByte; Size: Integer; OutBuffer: PByte; var OutSize: Integer): Boolean;
var
  i, EstSize, EQUCount: Integer;
  BufPtr: PByte;
  C: Byte;
begin
  if Size = 0 then
    begin
      Result := True;
      OutSize := 0;
      exit;
    end;

  EQUCount := cont.EQUCount;
  EstSize := cont.TailBytes;
  BufPtr := buffer;

  for i := 0 to Size - 1 do
    begin
      C := Base64Values[PByte(BufPtr)^];
      if C < 64 then
          inc(EstSize)
      else
        if C = $FF then
        begin
          if not cont.LiberalMode then
            begin
              Result := False;
              OutSize := 0;
              exit;
            end;
        end
      else
        if C = $FD then
        begin
          if EQUCount > 1 then
            begin
              Result := False;
              OutSize := 0;
              exit;
            end;
          inc(EQUCount);
        end;
      inc(BufPtr);
    end;

  EstSize := (EstSize shr 2) * 3;
  if OutSize < EstSize then
    begin
      OutSize := EstSize;
      Result := False;
      exit;
    end;

  cont.EQUCount := EQUCount;
  OutSize := EstSize;

  while Size > 0 do
    begin
      C := Base64Values[PByte(buffer)^];
      if C < 64 then
        begin
          cont.Tail[cont.TailBytes] := C;
          inc(cont.TailBytes);

          if cont.TailBytes = 4 then
            begin
              PByte(OutBuffer)^ := (cont.Tail[0] shl 2) or (cont.Tail[1] shr 4);
              inc(OutBuffer);

              PByte(OutBuffer)^ := ((cont.Tail[1] and $F) shl 4) or (cont.Tail[2] shr 2);
              inc(OutBuffer);

              PByte(OutBuffer)^ := ((cont.Tail[2] and $3) shl 6) or cont.Tail[3];
              inc(OutBuffer);

              cont.TailBytes := 0;
            end;
        end;
      inc(buffer);
      dec(Size);
    end;
  Result := True;
end;

function B64FinalizeEncoding(var cont: TBase64Context; OutBuffer: PByte; var OutSize: Integer): Boolean;
var
  EstSize: Integer;
begin
  if cont.TailBytes > 0 then
      EstSize := 4
  else
      EstSize := 0;

  if cont.TrailingEol then
      EstSize := EstSize + cont.EOLSize;

  if OutSize < EstSize then
    begin
      OutSize := EstSize;
      Result := False;
      exit;
    end;

  OutSize := EstSize;

  if cont.TailBytes = 0 then
    begin
      { writing trailing EOL }
      Result := True;
      if (cont.EOLSize > 0) and cont.TrailingEol then
        begin
          OutSize := cont.EOLSize;
          CopyPtr(@cont.fEOL[0], OutBuffer, cont.EOLSize);
        end;
      exit;
    end;

  if cont.TailBytes = 1 then
    begin
      PBase64ByteArray(OutBuffer)^[0] := Base64Symbols[cont.Tail[0] shr 2];
      PBase64ByteArray(OutBuffer)^[1] := Base64Symbols[((cont.Tail[0] and 3) shl 4)];
      PBase64ByteArray(OutBuffer)^[2] := $3D; // '='
      PBase64ByteArray(OutBuffer)^[3] := $3D; // '='
    end
  else if cont.TailBytes = 2 then
    begin
      PBase64ByteArray(OutBuffer)^[0] := Base64Symbols[cont.Tail[0] shr 2];
      PBase64ByteArray(OutBuffer)^[1] := Base64Symbols[((cont.Tail[0] and 3) shl 4) or (cont.Tail[1] shr 4)];
      PBase64ByteArray(OutBuffer)^[2] := Base64Symbols[((cont.Tail[1] and $F) shl 2)];
      PBase64ByteArray(OutBuffer)^[3] := $3D; // '='
    end;

  if (cont.EOLSize > 0) and (cont.TrailingEol) then
      CopyPtr(@cont.fEOL[0], @PBase64ByteArray(OutBuffer)^[4], cont.EOLSize);

  Result := True;
end;

function B64FinalizeDecoding(var cont: TBase64Context; OutBuffer: PByte; var OutSize: Integer): Boolean;
begin
  if (cont.EQUCount = 0) then
    begin
      OutSize := 0;
      Result := cont.TailBytes = 0;
      exit;
    end
  else
    if (cont.EQUCount = 1) then
    begin
      if cont.TailBytes <> 3 then
        begin
          Result := False;
          OutSize := 0;
          exit;
        end;

      if OutSize < 2 then
        begin
          OutSize := 2;
          Result := False;
          exit;
        end;

      PByte(OutBuffer)^ := (cont.Tail[0] shl 2) or (cont.Tail[1] shr 4);
      inc(OutBuffer);
      PByte(OutBuffer)^ := ((cont.Tail[1] and $F) shl 4) or (cont.Tail[2] shr 2);
      OutSize := 2;
      Result := True;
    end
  else if (cont.EQUCount = 2) then
    begin
      if cont.TailBytes <> 2 then
        begin
          Result := False;
          OutSize := 0;
          exit;
        end;

      if OutSize < 1 then
        begin
          OutSize := 1;
          Result := False;
          exit;
        end;

      PByte(OutBuffer)^ := (cont.Tail[0] shl 2) or (cont.Tail[1] shr 4);

      OutSize := 1;
      Result := True;
    end
  else
    begin
      Result := False;
      OutSize := 0;
    end;
end;

function umlBase64Encode(InBuffer: PByte; InSize: Integer; OutBuffer: PByte; var OutSize: Integer; WrapLines: Boolean): Boolean;
var
  cont: TBase64Context;
  TmpSize: Integer;
begin
  if WrapLines then
      B64InitializeEncoding(cont, 64, emCRLF, False)
  else
      B64InitializeEncoding(cont, 0, emNone, False);

  TmpSize := B64EstimateEncodedSize(cont, InSize);

  if (OutSize < TmpSize) then
    begin
      OutSize := TmpSize;
      Result := False;
      exit;
    end;

  TmpSize := OutSize;
  B64Encode(cont, InBuffer, InSize, OutBuffer, TmpSize);
  OutSize := OutSize - TmpSize;
  B64FinalizeEncoding(cont, PByte(NativeUInt(OutBuffer) + UInt32(TmpSize)), OutSize);
  OutSize := OutSize + TmpSize;

  Result := True;
end;

function umlBase64Decode(InBuffer: PByte; InSize: Integer; OutBuffer: PByte; var OutSize: Integer; LiberalMode: Boolean): Integer;
var
  i, TmpSize: Integer;
  ExtraSyms: Integer;
  cont: TBase64Context;
begin
  ExtraSyms := 0;
  try
    for i := 0 to InSize - 1 do
      if (PBase64ByteArray(InBuffer)^[i] in [$0D, $0A, $0]) then // some buggy software products insert 0x00 characters to BASE64 they produce
          inc(ExtraSyms);
  except
  end;

  if not LiberalMode then
    begin
      if ((InSize - ExtraSyms) and $3) <> 0 then
        begin
          Result := BASE64_DECODE_WRONG_DATA_SIZE;
          OutSize := 0;
          exit;
        end;
    end;

  TmpSize := ((InSize - ExtraSyms) shr 2) * 3;
  if OutSize < TmpSize then
    begin
      Result := BASE64_DECODE_NOT_ENOUGH_SPACE;
      OutSize := TmpSize;
      exit;
    end;

  B64InitializeDecoding(cont, LiberalMode);
  TmpSize := OutSize;
  if not B64Decode(cont, InBuffer, InSize, OutBuffer, TmpSize) then
    begin
      Result := BASE64_DECODE_INVALID_CHARACTER;
      OutSize := 0;
      exit;
    end;
  OutSize := OutSize - TmpSize;
  if not B64FinalizeDecoding(cont, @PBase64ByteArray(OutBuffer)^[TmpSize], OutSize) then
    begin
      Result := BASE64_DECODE_INVALID_CHARACTER;
      OutSize := 0;
      exit;
    end;
  OutSize := OutSize + TmpSize;
  Result := BASE64_DECODE_OK;
end;

procedure umlBase64EncodeBytes(var sour, dest: TBytes);
var
  Size: Integer;
begin
  if length(sour) = 0 then
      exit;

  Size := 0;
  SetLength(dest, 0);
  umlBase64Encode(@sour[0], length(sour), nil, Size, False);
  SetLength(dest, Size);
  umlBase64Encode(@sour[0], length(sour), @dest[0], Size, False);
  SetLength(dest, Size);
end;

procedure umlBase64DecodeBytes(var sour, dest: TBytes);
var
  Size: Integer;
begin
  if length(sour) = 0 then
    begin
      SetLength(dest, 0);
      exit;
    end;

  Size := 0;
  umlBase64Decode(@sour[0], length(sour), nil, Size, True);
  SetLength(dest, Size);
  umlBase64Decode(@sour[0], length(sour), @dest[0], Size, True);
  SetLength(dest, Size);
end;

procedure umlBase64EncodeBytes(var sour: TBytes; var dest: TPascalString);
var
  buff: TBytes;
begin
  umlBase64EncodeBytes(sour, buff);
  dest.Bytes := buff;
end;

procedure umlBase64DecodeBytes(const sour: TPascalString; var dest: TBytes);
var
  buff: TBytes;
begin
  buff := sour.Bytes;
  umlBase64DecodeBytes(buff, dest);
end;

procedure umlDecodeLineBASE64(const buffer: TPascalString; var output: TPascalString);
var
  B, nb: TBytes;
begin
  B := umlBytesOf(buffer);
  umlBase64DecodeBytes(B, nb);
  output := umlStringOf(nb);
end;

procedure umlEncodeLineBASE64(const buffer: TPascalString; var output: TPascalString);
var
  B, nb: TBytes;
begin
  B := umlBytesOf(buffer);
  umlBase64EncodeBytes(B, nb);
  output := umlStringOf(nb);
end;

function umlDecodeLineBASE64(const buffer: TPascalString): TPascalString;
begin
  umlDecodeLineBASE64(buffer, Result);
end;

function umlEncodeLineBASE64(const buffer: TPascalString): TPascalString;
begin
  umlEncodeLineBASE64(buffer, Result);
end;

procedure umlDecodeStreamBASE64(const buffer: TPascalString; output: TCore_Stream);
var
  B, nb: TBytes;
  bak: Int64;
begin
  B := umlBytesOf(buffer);
  umlBase64DecodeBytes(B, nb);
  bak := output.Position;
  output.WriteBuffer(nb[0], length(nb));
  output.Position := bak;
end;

procedure umlEncodeStreamBASE64(buffer: TCore_Stream; var output: TPascalString);
var
  B, nb: TBytes;
  bak: Int64;
begin
  bak := buffer.Position;

  buffer.Position := 0;
  SetLength(B, buffer.Size);
  buffer.ReadBuffer(B[0], buffer.Size);
  umlBase64EncodeBytes(B, nb);
  output := umlStringOf(nb);

  buffer.Position := bak;
end;

function umlDivisionBase64Text(const buffer: TPascalString; width: Integer; DivisionAsPascalString: Boolean): TPascalString;
var
  i, n: Integer;
begin
  Result := '';
  n := 0;
  for i := 1 to buffer.L do
    begin
      if (DivisionAsPascalString) and (n = 0) then
          Result.Append(#39);

      Result.Append(buffer[i]);
      inc(n);
      if n >= width - 1 then
        begin
          if DivisionAsPascalString then
              Result.Append(#39 + '+' + #13#10)
          else
              Result.Append(#13#10);
          n := 0;
        end;
    end;
  if DivisionAsPascalString and (n > 0) then
      Result.Append(#39);
end;

function umlTestBase64(const text: TPascalString): Boolean;
var
  sour, dest: TBytes;
begin
  sour := text.Bytes;
  SetLength(dest, 0);
  try
      umlBase64DecodeBytes(sour, dest);
  except
  end;
  Result := length(dest) > 0;
  if Result then
      SetLength(dest, 0);
end;

procedure umlBase64EncodeBytes(var sour: TBytes; var dest: TUPascalString);
var
  buff: TBytes;
begin
  umlBase64EncodeBytes(sour, buff);
  dest.Bytes := buff;
end;

procedure umlBase64DecodeBytes(const sour: TUPascalString; var dest: TBytes);
var
  buff: TBytes;
begin
  buff := sour.Bytes;
  umlBase64DecodeBytes(buff, dest);
end;

procedure umlDecodeLineBASE64(const buffer: TUPascalString; var output: TUPascalString);
var
  B, nb: TBytes;
begin
  B := umlBytesOf(buffer.text);
  umlBase64DecodeBytes(B, nb);
  output.text := umlStringOf(nb);
end;

procedure umlEncodeLineBASE64(const buffer: TUPascalString; var output: TUPascalString);
var
  B, nb: TBytes;
begin
  B := umlBytesOf(buffer.text);
  umlBase64EncodeBytes(B, nb);
  output.text := umlStringOf(nb);
end;

function umlDecodeLineBASE64(const buffer: TUPascalString): TUPascalString;
begin
  umlDecodeLineBASE64(buffer, Result);
end;

function umlEncodeLineBASE64(const buffer: TUPascalString): TUPascalString;
begin
  umlEncodeLineBASE64(buffer, Result);
end;

procedure umlDecodeStreamBASE64(const buffer: TUPascalString; output: TCore_Stream);
var
  B, nb: TBytes;
  bak: Int64;
begin
  B := umlBytesOf(buffer.text);
  umlBase64DecodeBytes(B, nb);
  bak := output.Position;
  output.WriteBuffer(nb[0], length(nb));
  output.Position := bak;
end;

procedure umlEncodeStreamBASE64(buffer: TCore_Stream; var output: TUPascalString);
var
  B, nb: TBytes;
  bak: Int64;
begin
  bak := buffer.Position;

  buffer.Position := 0;
  SetLength(B, buffer.Size);
  buffer.ReadBuffer(B[0], buffer.Size);
  umlBase64EncodeBytes(B, nb);
  output := umlStringOf(nb);

  buffer.Position := bak;
end;

function umlDivisionBase64Text(const buffer: TUPascalString; width: Integer; DivisionAsPascalString: Boolean): TUPascalString;
var
  i, n: Integer;
begin
  Result := '';
  n := 0;
  for i := 1 to buffer.L do
    begin
      if (DivisionAsPascalString) and (n = 0) then
          Result.Append(#39);

      Result.Append(buffer[i]);
      inc(n);
      if n >= width - 1 then
        begin
          if DivisionAsPascalString then
              Result.Append(#39 + '+' + #13#10)
          else
              Result.Append(#13#10);
          n := 0;
        end;
    end;
  if DivisionAsPascalString and (n > 0) then
      Result.Append(#39);
end;

function umlTestBase64(const text: TUPascalString): Boolean;
var
  sour, dest: TBytes;
begin
  sour := text.Bytes;
  SetLength(dest, 0);
  try
      umlBase64DecodeBytes(sour, dest);
  except
  end;
  Result := length(dest) > 0;
  if Result then
      SetLength(dest, 0);
end;

constructor TMD5_Tool.Create;
begin
  inherited Create;
  Mem := TMem64.Create;
  PCardinal(@Digest[0])^ := $67452301;
  PCardinal(@Digest[4])^ := $EFCDAB89;
  PCardinal(@Digest[8])^ := $98BADCFE;
  PCardinal(@Digest[12])^ := $10325476;
  FCompleted_Size := 0;
end;

destructor TMD5_Tool.Destroy;
begin
  DisposeObject(Mem);
  inherited Destroy;
end;

procedure TMD5_Tool.Update(buff: Pointer; Size__: Int64);
var
  p, sI: Int64;
  Tmp: TMem64;
begin
  if Size__ <= 0 then
      exit;

  Mem.Position := Mem.Size;
  Mem.WritePtr(buff, Size__);

  sI := Mem.Size;

  if sI < $40 then
      exit;

  // chunk
  p := 0;
  while p + $40 <= sI do
    begin
      umlTransformMD5(Digest, Mem.PosAsPtr(p)^);
      inc(p, $40);
      inc(FCompleted_Size, $40);
    end;

  // remaining
  Tmp := TMem64.Create;
  if sI - p > 0 then
      Tmp.WritePtr(Mem.PosAsPtr(p), sI - p);
  DisposeObject(Mem);
  Mem := Tmp;
end;

function TMD5_Tool.FinalizeMD5: TMD5;
var
  sI: Int64;
  ChunkIndex: Byte;
  ChunkBuff: array [0 .. 63] of Byte;
begin
  sI := Mem.Size;
  inc(FCompleted_Size, sI);
  if sI > 0 then
      CopyPtr(Mem.Memory, @ChunkBuff[0], sI);

  Result := PMD5(@Digest[0])^;
  ChunkBuff[sI] := $80;
  ChunkIndex := sI + 1;
  if ChunkIndex > $38 then
    begin
      if ChunkIndex < $40 then
          FillPtr(@ChunkBuff[ChunkIndex], $40 - ChunkIndex, 0);
      umlTransformMD5(Result, ChunkBuff);
      ChunkIndex := 0
    end;
  FillPtr(@ChunkBuff[ChunkIndex], $38 - ChunkIndex, 0);
  PCardinal(@ChunkBuff[$38])^ := FCompleted_Size shl 3;
  PCardinal(@ChunkBuff[$3C])^ := FCompleted_Size shr 29;
  umlTransformMD5(Result, ChunkBuff);
  Mem.Clear;
end;

constructor TMD5_Pair_Pool.Create(HashSize_: Integer);
begin
  inherited Create(HashSize_, NULLMD5);
  IsChanged := False;
end;

procedure TMD5_Pair_Pool.DoFree(var Key: TMD5; var Value: TMD5);
begin
  inherited;
  IsChanged := True;
end;

procedure TMD5_Pair_Pool.DoAdd(var Key: TMD5; var Value: TMD5);
begin
  inherited;
  IsChanged := True;
end;

procedure TMD5_Pair_Pool.LoadFromStream(stream: TCore_Stream);
begin
  Clear;
  while stream.Position + 32 <= stream.Size do
      add(StreamReadMD5(stream), StreamReadMD5(stream), False);
end;

procedure TMD5_Pair_Pool.SaveToStream(stream: TCore_Stream);
begin
  with repeat_ do
    repeat
      StreamWriteMD5(stream, Queue^.Data^.Data.Primary);
      StreamWriteMD5(stream, Queue^.Data^.Data.Second);
    until not Right;
end;

function umlStrIsMD5(hex: TPascalString): Boolean;
var
  C: SystemChar;
begin
  Result := False;
  if hex.L <> 32 then
      exit;
  for C in hex.buff do
    if not CharIn(C, cHex) then
        exit;
  Result := True;
end;

function umlStrToMD5(hex: TPascalString): TMD5;
begin
  TCipher.HexToBuffer(hex, Result[0], SizeOf(TMD5));
end;

procedure umlTransformMD5(var Accu; const Buf);
{$IF Defined(FastMD5) and Defined(Delphi) and (Defined(WIN32) or Defined(WIN64))}
begin
  MD5_Transform(Accu, Buf);
end;
{$ELSE}
  function ROL(const X: Cardinal; const n: Byte): Cardinal;
  begin
    Result := (X shl n) or (X shr (32 - n))
  end;

  function FF(const A, B, C, D, X: Cardinal; const S: Byte; const AC: Cardinal): Cardinal;
  begin
    Result := ROL(A + X + AC + (B and C or not B and D), S) + B
  end;

  function GG(const A, B, C, D, X: Cardinal; const S: Byte; const AC: Cardinal): Cardinal;
  begin
    Result := ROL(A + X + AC + (B and D or C and not D), S) + B
  end;

  function HH(const A, B, C, D, X: Cardinal; const S: Byte; const AC: Cardinal): Cardinal;
  begin
    Result := ROL(A + X + AC + (B xor C xor D), S) + B
  end;

  function II(const A, B, C, D, X: Cardinal; const S: Byte; const AC: Cardinal): Cardinal;
  begin
    Result := ROL(A + X + AC + (C xor (B or not D)), S) + B
  end;

type
  TDigestCardinal = array [0 .. 3] of Cardinal;
  TCardinalBuf = array [0 .. 15] of Cardinal;
var
  A, B, C, D: Cardinal;
begin
  A := TDigestCardinal(Accu)[0];
  B := TDigestCardinal(Accu)[1];
  C := TDigestCardinal(Accu)[2];
  D := TDigestCardinal(Accu)[3];

  A := FF(A, B, C, D, TCardinalBuf(Buf)[0], 7, $D76AA478); { 1 }
  D := FF(D, A, B, C, TCardinalBuf(Buf)[1], 12, $E8C7B756); { 2 }
  C := FF(C, D, A, B, TCardinalBuf(Buf)[2], 17, $242070DB); { 3 }
  B := FF(B, C, D, A, TCardinalBuf(Buf)[3], 22, $C1BDCEEE); { 4 }
  A := FF(A, B, C, D, TCardinalBuf(Buf)[4], 7, $F57C0FAF); { 5 }
  D := FF(D, A, B, C, TCardinalBuf(Buf)[5], 12, $4787C62A); { 6 }
  C := FF(C, D, A, B, TCardinalBuf(Buf)[6], 17, $A8304613); { 7 }
  B := FF(B, C, D, A, TCardinalBuf(Buf)[7], 22, $FD469501); { 8 }
  A := FF(A, B, C, D, TCardinalBuf(Buf)[8], 7, $698098D8); { 9 }
  D := FF(D, A, B, C, TCardinalBuf(Buf)[9], 12, $8B44F7AF); { 10 }
  C := FF(C, D, A, B, TCardinalBuf(Buf)[10], 17, $FFFF5BB1); { 11 }
  B := FF(B, C, D, A, TCardinalBuf(Buf)[11], 22, $895CD7BE); { 12 }
  A := FF(A, B, C, D, TCardinalBuf(Buf)[12], 7, $6B901122); { 13 }
  D := FF(D, A, B, C, TCardinalBuf(Buf)[13], 12, $FD987193); { 14 }
  C := FF(C, D, A, B, TCardinalBuf(Buf)[14], 17, $A679438E); { 15 }
  B := FF(B, C, D, A, TCardinalBuf(Buf)[15], 22, $49B40821); { 16 }
  A := GG(A, B, C, D, TCardinalBuf(Buf)[1], 5, $F61E2562); { 17 }
  D := GG(D, A, B, C, TCardinalBuf(Buf)[6], 9, $C040B340); { 18 }
  C := GG(C, D, A, B, TCardinalBuf(Buf)[11], 14, $265E5A51); { 19 }
  B := GG(B, C, D, A, TCardinalBuf(Buf)[0], 20, $E9B6C7AA); { 20 }
  A := GG(A, B, C, D, TCardinalBuf(Buf)[5], 5, $D62F105D); { 21 }
  D := GG(D, A, B, C, TCardinalBuf(Buf)[10], 9, $02441453); { 22 }
  C := GG(C, D, A, B, TCardinalBuf(Buf)[15], 14, $D8A1E681); { 23 }
  B := GG(B, C, D, A, TCardinalBuf(Buf)[4], 20, $E7D3FBC8); { 24 }
  A := GG(A, B, C, D, TCardinalBuf(Buf)[9], 5, $21E1CDE6); { 25 }
  D := GG(D, A, B, C, TCardinalBuf(Buf)[14], 9, $C33707D6); { 26 }
  C := GG(C, D, A, B, TCardinalBuf(Buf)[3], 14, $F4D50D87); { 27 }
  B := GG(B, C, D, A, TCardinalBuf(Buf)[8], 20, $455A14ED); { 28 }
  A := GG(A, B, C, D, TCardinalBuf(Buf)[13], 5, $A9E3E905); { 29 }
  D := GG(D, A, B, C, TCardinalBuf(Buf)[2], 9, $FCEFA3F8); { 30 }
  C := GG(C, D, A, B, TCardinalBuf(Buf)[7], 14, $676F02D9); { 31 }
  B := GG(B, C, D, A, TCardinalBuf(Buf)[12], 20, $8D2A4C8A); { 32 }
  A := HH(A, B, C, D, TCardinalBuf(Buf)[5], 4, $FFFA3942); { 33 }
  D := HH(D, A, B, C, TCardinalBuf(Buf)[8], 11, $8771F681); { 34 }
  C := HH(C, D, A, B, TCardinalBuf(Buf)[11], 16, $6D9D6122); { 35 }
  B := HH(B, C, D, A, TCardinalBuf(Buf)[14], 23, $FDE5380C); { 36 }
  A := HH(A, B, C, D, TCardinalBuf(Buf)[1], 4, $A4BEEA44); { 37 }
  D := HH(D, A, B, C, TCardinalBuf(Buf)[4], 11, $4BDECFA9); { 38 }
  C := HH(C, D, A, B, TCardinalBuf(Buf)[7], 16, $F6BB4B60); { 39 }
  B := HH(B, C, D, A, TCardinalBuf(Buf)[10], 23, $BEBFBC70); { 40 }
  A := HH(A, B, C, D, TCardinalBuf(Buf)[13], 4, $289B7EC6); { 41 }
  D := HH(D, A, B, C, TCardinalBuf(Buf)[0], 11, $EAA127FA); { 42 }
  C := HH(C, D, A, B, TCardinalBuf(Buf)[3], 16, $D4EF3085); { 43 }
  B := HH(B, C, D, A, TCardinalBuf(Buf)[6], 23, $04881D05); { 44 }
  A := HH(A, B, C, D, TCardinalBuf(Buf)[9], 4, $D9D4D039); { 45 }
  D := HH(D, A, B, C, TCardinalBuf(Buf)[12], 11, $E6DB99E5); { 46 }
  C := HH(C, D, A, B, TCardinalBuf(Buf)[15], 16, $1FA27CF8); { 47 }
  B := HH(B, C, D, A, TCardinalBuf(Buf)[2], 23, $C4AC5665); { 48 }
  A := II(A, B, C, D, TCardinalBuf(Buf)[0], 6, $F4292244); { 49 }
  D := II(D, A, B, C, TCardinalBuf(Buf)[7], 10, $432AFF97); { 50 }
  C := II(C, D, A, B, TCardinalBuf(Buf)[14], 15, $AB9423A7); { 51 }
  B := II(B, C, D, A, TCardinalBuf(Buf)[5], 21, $FC93A039); { 52 }
  A := II(A, B, C, D, TCardinalBuf(Buf)[12], 6, $655B59C3); { 53 }
  D := II(D, A, B, C, TCardinalBuf(Buf)[3], 10, $8F0CCC92); { 54 }
  C := II(C, D, A, B, TCardinalBuf(Buf)[10], 15, $FFEFF47D); { 55 }
  B := II(B, C, D, A, TCardinalBuf(Buf)[1], 21, $85845DD1); { 56 }
  A := II(A, B, C, D, TCardinalBuf(Buf)[8], 6, $6FA87E4F); { 57 }
  D := II(D, A, B, C, TCardinalBuf(Buf)[15], 10, $FE2CE6E0); { 58 }
  C := II(C, D, A, B, TCardinalBuf(Buf)[6], 15, $A3014314); { 59 }
  B := II(B, C, D, A, TCardinalBuf(Buf)[13], 21, $4E0811A1); { 60 }
  A := II(A, B, C, D, TCardinalBuf(Buf)[4], 6, $F7537E82); { 61 }
  D := II(D, A, B, C, TCardinalBuf(Buf)[11], 10, $BD3AF235); { 62 }
  C := II(C, D, A, B, TCardinalBuf(Buf)[2], 15, $2AD7D2BB); { 63 }
  B := II(B, C, D, A, TCardinalBuf(Buf)[9], 21, $EB86D391); { 64 }

  inc(TDigestCardinal(Accu)[0], A);
  inc(TDigestCardinal(Accu)[1], B);
  inc(TDigestCardinal(Accu)[2], C);
  inc(TDigestCardinal(Accu)[3], D)
end;
{$ENDIF}


function umlMD5(const buffPtr: PByte; bufSiz: NativeUInt): TMD5;
{$IF Defined(FastMD5) and Defined(Delphi) and (Defined(WIN32) or Defined(WIN64))}
begin
  Result := FastMD5(buffPtr, bufSiz);
end;
{$ELSE}


var
  Digest: TMD5;
  Lo, Hi: Cardinal;
  p: PByte;
  ChunkIndex: Byte;
  ChunkBuff: array [0 .. 63] of Byte;
begin
  PCardinal(@Digest[0])^ := $67452301;
  PCardinal(@Digest[4])^ := $EFCDAB89;
  PCardinal(@Digest[8])^ := $98BADCFE;
  PCardinal(@Digest[12])^ := $10325476;
  Lo := bufSiz shl 3;
  Hi := bufSiz shr 29;

  p := buffPtr;

  while bufSiz >= $40 do
    begin
      umlTransformMD5(Digest, p^);
      inc(p, $40);
      dec(bufSiz, $40);
    end;
  if bufSiz > 0 then
      CopyPtr(p, @ChunkBuff[0], bufSiz);

  Result := PMD5(@Digest[0])^;
  ChunkBuff[bufSiz] := $80;
  ChunkIndex := bufSiz + 1;
  if ChunkIndex > $38 then
    begin
      if ChunkIndex < $40 then
          FillPtrByte(@ChunkBuff[ChunkIndex], $40 - ChunkIndex, 0);
      umlTransformMD5(Result, ChunkBuff);
      ChunkIndex := 0
    end;
  FillPtrByte(@ChunkBuff[ChunkIndex], $38 - ChunkIndex, 0);
  PCardinal(@ChunkBuff[$38])^ := Lo;
  PCardinal(@ChunkBuff[$3C])^ := Hi;
  umlTransformMD5(Result, ChunkBuff);
end;
{$ENDIF}


function umlMD5Char(const buffPtr: PByte; const BuffSize: NativeUInt): TPascalString;
begin
  Result := umlMD5ToStr(umlMD5(buffPtr, BuffSize));
end;

function umlMD5String(const buffPtr: PByte; const BuffSize: NativeUInt): TPascalString;
begin
  Result := umlMD5ToStr(umlMD5(buffPtr, BuffSize));
end;

function umlMD5Str(const buffPtr: PByte; const BuffSize: NativeUInt): TPascalString;
begin
  Result := umlMD5ToStr(umlMD5(buffPtr, BuffSize));
end;

function umlStreamMD5(stream: TCore_Stream; StartPos, EndPos: Int64): TMD5;
{$IF Defined(FastMD5) and Defined(Delphi) and (Defined(WIN32) or Defined(WIN64))}
begin
  Result := FastMD5(stream, StartPos, EndPos);
end;
{$ELSE}


const
  deltaSize: Cardinal = $40 * $FFFF;

var
  Digest: TMD5;
  Lo, Hi: Cardinal;
  DeltaBuf: Pointer;
  bufSiz: Int64;
  Rest: Cardinal;
  p: PByte;
  ChunkIndex: Byte;
  ChunkBuff: array [0 .. 63] of Byte;
begin
  if StartPos > EndPos then
      TSwap<Int64>.Do_(StartPos, EndPos);
  StartPos := umlClamp(StartPos, 0, stream.Size);
  EndPos := umlClamp(EndPos, 0, stream.Size);
  if EndPos - StartPos <= 0 then
    begin
      Result := umlMD5(nil, 0);
      exit;
    end;
{$IFDEF OptimizationMemoryStreamMD5}
  if stream is TCore_MemoryStream then
    begin
      Result := umlMD5(GetOffset(TCore_MemoryStream(stream).Memory, StartPos), EndPos - StartPos);
      exit;
    end;
  if stream is TMS64 then
    begin
      Result := umlMD5(TMS64(stream).PositionAsPtr(StartPos), EndPos - StartPos);
      exit;
    end;
{$ENDIF OptimizationMemoryStreamMD5}
  //
  PCardinal(@Digest[0])^ := $67452301;
  PCardinal(@Digest[4])^ := $EFCDAB89;
  PCardinal(@Digest[8])^ := $98BADCFE;
  PCardinal(@Digest[12])^ := $10325476;

  bufSiz := EndPos - StartPos;
  Rest := 0;
  Lo := bufSiz shl 3;
  Hi := bufSiz shr 29;

  DeltaBuf := GetMemory(deltaSize);
  stream.Position := StartPos;

  if bufSiz < $40 then
    begin
      if stream.Read(DeltaBuf^, bufSiz) <> bufSiz then
        begin
          FreeMemory(DeltaBuf);
          exit(NULLMD5);
        end;
      p := DeltaBuf;
    end
  else
    while bufSiz >= $40 do
      begin
        if Rest = 0 then
          begin
            if bufSiz >= deltaSize then
                Rest := deltaSize
            else
                Rest := bufSiz;
            if stream.Read(DeltaBuf^, Rest) <> Rest then
              begin
                FreeMemory(DeltaBuf);
                exit(NULLMD5);
              end;

            p := DeltaBuf;
          end;
        umlTransformMD5(Digest, p^);
        inc(p, $40);
        dec(bufSiz, $40);
        dec(Rest, $40);
      end;

  if bufSiz > 0 then
      CopyPtr(p, @ChunkBuff[0], bufSiz);

  FreeMemory(DeltaBuf);

  Result := PMD5(@Digest[0])^;
  ChunkBuff[bufSiz] := $80;
  ChunkIndex := bufSiz + 1;
  if ChunkIndex > $38 then
    begin
      if ChunkIndex < $40 then
          FillPtrByte(@ChunkBuff[ChunkIndex], $40 - ChunkIndex, 0);
      umlTransformMD5(Result, ChunkBuff);
      ChunkIndex := 0
    end;
  FillPtrByte(@ChunkBuff[ChunkIndex], $38 - ChunkIndex, 0);
  PCardinal(@ChunkBuff[$38])^ := Lo;
  PCardinal(@ChunkBuff[$3C])^ := Hi;
  umlTransformMD5(Result, ChunkBuff);
end;
{$ENDIF}


function umlStreamMD5(stream: TCore_Stream): TMD5;
begin
  if stream.Size <= 0 then
    begin
      Result := NULLMD5;
      exit;
    end;
  stream.Position := 0;
  Result := umlStreamMD5(stream, 0, stream.Size);
  stream.Position := 0;
end;

function umlStreamMD5Char(stream: TCore_Stream): TPascalString;
begin
  Result := umlMD5ToStr(umlStreamMD5(stream));
end;

function umlStreamMD5String(stream: TCore_Stream): TPascalString;
begin
  Result := umlMD5ToStr(umlStreamMD5(stream));
end;

function umlStreamMD5Str(stream: TCore_Stream): TPascalString;
begin
  Result := umlMD5ToStr(umlStreamMD5(stream));
end;

function umlStringMD5(const Value: TPascalString): TPascalString;
var
  B: TBytes;
begin
  B := umlBytesOf(Value);
  Result := umlMD5ToStr(umlMD5(@B[0], length(B)));
end;

function umlFileMD5___(FileName: TPascalString): TMD5;
var
  fs: TCore_FileStream;
begin
  try
      fs := TCore_FileStream.Create(FileName, fmOpenRead or fmShareDenyNone);
  except
    Result := NULLMD5;
    exit;
  end;
  try
      Result := umlStreamMD5(fs);
  finally
      DisposeObject(fs);
  end;
end;

function umlFileMD5(FileName: TPascalString; StartPos, EndPos: Int64): TMD5;
var
  fs: TCore_FileStream;
begin
  if not umlFileExists(FileName) then
    begin
      Result := NULLMD5;
      exit;
    end;

  if (StartPos = 0) and (EndPos = umlGetFileSize(FileName)) then
    begin
      Result := umlFileMD5(FileName);
      exit;
    end;

  try
      fs := TCore_FileStream.Create(FileName, fmOpenRead or fmShareDenyNone);
  except
    Result := NULLMD5;
    exit;
  end;
  try
      Result := umlStreamMD5(fs, StartPos, EndPos);
  finally
      DisposeObject(fs);
  end;
end;

function umlCombineMD5(const m1: TMD5): TMD5;
begin
  Result := umlMD5(@m1, SizeOf(TMD5));
end;

function umlCombineMD5(const m1, m2: TMD5): TMD5;
var
  buff: array [0 .. 1] of TMD5;
begin
  buff[0] := m1;
  buff[1] := m2;
  Result := umlMD5(@buff[0], SizeOf(TMD5) * 2);
end;

function umlCombineMD5(const m1, m2, m3: TMD5): TMD5;
var
  buff: array [0 .. 2] of TMD5;
begin
  buff[0] := m1;
  buff[1] := m2;
  buff[2] := m3;
  Result := umlMD5(@buff[0], SizeOf(TMD5) * 3);
end;

function umlCombineMD5(const m1, m2, m3, m4: TMD5): TMD5;
var
  buff: array [0 .. 3] of TMD5;
begin
  buff[0] := m1;
  buff[1] := m2;
  buff[2] := m3;
  buff[3] := m4;
  Result := umlMD5(@buff[0], SizeOf(TMD5) * 4);
end;

function umlCombineMD5(const buff: array of TMD5): TMD5;
begin
  Result := umlMD5(@buff[0], length(buff) * SizeOf(TMD5));
end;

function umlMD5ToStr(md5: TMD5): TPascalString;
const
  HexArr: array [0 .. 15] of U_Char = ('0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'a', 'b', 'c', 'd', 'e', 'f');
var
  i: Integer;
begin
  Result.L := 32;
  for i := 0 to 15 do
    begin
      Result.buff[i * 2] := HexArr[(md5[i] shr 4) and $0F];
      Result.buff[i * 2 + 1] := HexArr[md5[i] and $0F];
    end;
end;

function umlMD5ToStr(const buffPtr: PByte; bufSiz: NativeUInt): TPascalString;
begin
  Result := umlMD5ToStr(umlMD5(buffPtr, bufSiz));
end;

function umlMD5ToString(md5: TMD5): TPascalString;
const
  HexArr: array [0 .. 15] of U_Char = ('0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'a', 'b', 'c', 'd', 'e', 'f');
var
  i: Integer;
begin
  Result.L := 32;
  for i := 0 to 15 do
    begin
      Result.buff[i * 2] := HexArr[(md5[i] shr 4) and $0F];
      Result.buff[i * 2 + 1] := HexArr[md5[i] and $0F];
    end;
end;

function umlMD5ToString(const buffPtr: PByte; bufSiz: NativeUInt): TPascalString;
begin
  Result := umlMD5ToString(umlMD5(buffPtr, bufSiz));
end;

function umlMD52String(md5: TMD5): TPascalString;
const
  HexArr: array [0 .. 15] of U_Char = ('0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'a', 'b', 'c', 'd', 'e', 'f');
var
  i: Integer;
begin
  Result.L := 32;
  for i := 0 to 15 do
    begin
      Result.buff[i * 2] := HexArr[(md5[i] shr 4) and $0F];
      Result.buff[i * 2 + 1] := HexArr[md5[i] and $0F];
    end;
end;

function umlMD5Compare(const m1, m2: TMD5): Boolean;
begin
  Result := (PUInt64(@m1[0])^ = PUInt64(@m2[0])^) and (PUInt64(@m1[8])^ = PUInt64(@m2[8])^);
end;

function umlCompareMD5(const m1, m2: TMD5): Boolean;
begin
  Result := (PUInt64(@m1[0])^ = PUInt64(@m2[0])^) and (PUInt64(@m1[8])^ = PUInt64(@m2[8])^);
end;

function umlIsNullMD5(M: TMD5): Boolean;
begin
  Result := umlCompareMD5(M, NULLMD5);
end;

function umlWasNullMD5(M: TMD5): Boolean;
begin
  Result := umlCompareMD5(M, NULLMD5);
end;

type
  TFileMD5_CacheData = record
    Time_: TDateTime;
    Size_: Int64;
    md5: TMD5;
  end;

  PFileMD5_CacheData = ^TFileMD5_CacheData;

  TFileMD5Cache = class(TCore_Object_Intermediate)
  private
    Critical: TCritical;
    FHash: THashList;
    procedure DoDataFreeProc(p: Pointer);
    function DoGetFileMD5(FileName: U_String): TMD5;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Clear;
  end;

var
  FileMD5Cache: TFileMD5Cache = nil;

procedure TFileMD5Cache.DoDataFreeProc(p: Pointer);
begin
  Dispose(PFileMD5_CacheData(p));
end;

function TFileMD5Cache.DoGetFileMD5(FileName: U_String): TMD5;
var
  p: PFileMD5_CacheData;
  ft: TDateTime;
  fs: Int64;
begin
  if not umlFileExists(FileName) then
    begin
      Critical.Lock;
      FHash.Delete(FileName);
      Critical.UnLock;
      Result := NULLMD5;
      exit;
    end;

  ft := umlGetFileTime(FileName);
  fs := umlGetFileSize(FileName);
  Critical.Lock;
  p := FHash[FileName];
  if p = nil then
    begin
      new(p);
      p^.Time_ := ft;
      p^.Size_ := fs;
      try
          p^.md5 := umlFileMD5___(FileName);
      except
          p^.md5 := NULL_Buff_MD5;
      end;
      FHash.add(FileName, p, False);
      Result := p^.md5;
    end
  else
    begin
      if (ft <> p^.Time_) or (fs <> p^.Size_) then
        begin
          p^.Time_ := ft;
          p^.Size_ := fs;
          try
              p^.md5 := umlFileMD5___(FileName);
          except
              p^.md5 := NULL_Buff_MD5;
          end;
        end;
      Result := p^.md5;
    end;
  Critical.UnLock;
end;

constructor TFileMD5Cache.Create;
begin
  inherited Create;
  FHash := THashList.CustomCreate($FFFF);
  FHash.OnFreePtr := DoDataFreeProc;
  FHash.IgnoreCase := True;
  FHash.AccessOptimization := True;
  Critical := TCritical.Create('TFileMD5Cache.Critical');
end;

destructor TFileMD5Cache.Destroy;
begin
  DisposeObject(Critical);
  DisposeObject(FHash);
  inherited Destroy;
end;

procedure TFileMD5Cache.Clear;
begin
  FHash.Clear;
end;

function umlFileMD5(FileName: TPascalString): TMD5;
begin
  Result := FileMD5Cache.DoGetFileMD5(FileName);
end;

procedure Do_ThCacheFileMD5(ThSender: TCompute);
var
  p: PPascalString;
begin
  p := ThSender.UserData;
  FileMD5Cache.DoGetFileMD5(p^);
  Dispose(p);
end;

procedure umlCacheFileMD5(FileName: U_String);
var
  p: PPascalString;
begin
  new(p);
  p^ := FileName;
  TCompute.RunC(p, nil, Do_ThCacheFileMD5);
end;

type
  TCacheFileMD5FromDirectoryData_ = record
    Directory_, Filter_: U_String;
  end;

  PCacheFileMD5FromDirectoryData_ = ^TCacheFileMD5FromDirectoryData_;

var
  CacheThreadIsAcivted: Boolean = True;
  CacheFileMD5FromDirectory_Num: Integer = 0;

procedure DoCacheFileMD5FromDirectory(ThSender: TCompute);
var
  p: PCacheFileMD5FromDirectoryData_;
  arry: U_StringArray;
  n: U_SystemString;
begin
  p := ThSender.UserData;
  try
    arry := umlGet_File_Full_Array(p^.Directory_);
    for n in arry do
      begin
        if umlMultipleMatch(p^.Filter_, umlGetFileName(n)) then
          if umlFileExists(n) then
              FileMD5Cache.DoGetFileMD5(n);
        if not CacheThreadIsAcivted then
            break;
      end;
    SetLength(arry, 0);
  except
  end;
  p^.Directory_ := '';
  p^.Filter_ := '';
  Dispose(p);
  AtomDec(CacheFileMD5FromDirectory_Num);
end;

procedure umlCacheFileMD5FromDirectory(Directory_, Filter_: U_String);
var
  p: PCacheFileMD5FromDirectoryData_;
begin
  AtomInc(CacheFileMD5FromDirectory_Num);
  new(p);
  p^.Directory_ := Directory_;
  p^.Filter_ := Filter_;
  TCompute.RunC(p, nil, DoCacheFileMD5FromDirectory);
end;

function umlCRC16(const Value: PByte; const Count: NativeUInt): Word;
var
  i: NativeUInt;
  p: PByte;
begin
  p := Value;
  Result := 0;
  i := 0;
  while i < Count do
    begin
      Result := (Result shr 8) xor CRC16Table[p^ xor (Result and $00FF)];
      inc(i);
      inc(p);
    end;
end;

function umlStringCRC16(const Value: TPascalString): Word;
var
  B: TBytes;
begin
  B := umlBytesOf(Value);
  Result := umlCRC16(@B[0], length(B));
end;

function umlStreamCRC16(stream: U_Stream; StartPos, EndPos: Int64): Word;
const
  ChunkSize = 1024 * 1024;
  procedure CRC16BUpdate(var crc: Word; const Buf: Pointer; L: NativeUInt);
  var
    p: PByte;
    i: Integer;
  begin
    p := Buf;
    i := 0;
    while i < L do
      begin
        crc := (crc shr 8) xor CRC16Table[p^ xor (crc and $00FF)];
        inc(p);
        inc(i);
      end;
  end;

var
  j: NativeUInt;
  Num: NativeUInt;
  Rest: NativeUInt;
  Buf: Pointer;
  FSize: Int64;
begin
  if stream is TCore_MemoryStream then
    begin
      Result := umlCRC16(GetOffset(TCore_MemoryStream(stream).Memory, StartPos), EndPos - StartPos);
      exit;
    end;
  if stream is TMS64 then
    begin
      Result := umlCRC16(TMS64(stream).PositionAsPtr(StartPos), EndPos - StartPos);
      exit;
    end;
  { Allocate buffer to read file }
  Buf := GetMemory(ChunkSize);
  { Initialize CRC }
  Result := 0;

  { V1.03 calculate how much of the file we are processing }
  FSize := stream.Size;
  if (StartPos >= FSize) then
      StartPos := 0;
  if (EndPos > FSize) or (EndPos = 0) then
      EndPos := FSize;

  { Calculate number of full chunks that will fit into the buffer }
  Num := EndPos div ChunkSize;
  { Calculate remaining bytes }
  Rest := EndPos mod ChunkSize;

  { Set the stream to the beginning of the file }
  stream.Position := StartPos;

  { Process full chunks }
  for j := 0 to Num - 1 do
    begin
      stream.Read(Buf^, ChunkSize);
      CRC16BUpdate(Result, Buf, ChunkSize);
    end;

  { Process remaining bytes }
  if Rest > 0 then
    begin
      stream.Read(Buf^, Rest);
      CRC16BUpdate(Result, Buf, Rest);
    end;

  FreeMem(Buf, ChunkSize);
end;

function umlStreamCRC16(stream: U_Stream): Word;
begin
  stream.Position := 0;
  Result := umlStreamCRC16(stream, 0, stream.Size);
  stream.Position := 0;
end;

function umlCRC32(const Value: PByte; const Count: NativeUInt): Cardinal;
var
  i: NativeUInt;
  p: PByte;
begin
  p := Value;
  Result := $FFFFFFFF;
  i := 0;
  while i < Count do
    begin
      Result := ((Result shr 8) and $00FFFFFF) xor C_CRC32Table[(Result xor p^) and $000000FF];
      inc(i);
      inc(p);
    end;
  Result := Result xor $FFFFFFFF;
end;

function umlString2CRC32(const Value: TPascalString): Cardinal;
var
  B: TBytes;
begin
  B := umlBytesOf(Value);
  Result := umlCRC32(@B[0], length(B));
end;

function umlStreamCRC32(stream: U_Stream; StartPos, EndPos: Int64): Cardinal;
const
  ChunkSize = 1024 * 1024;

  procedure CRC32BUpdate(var crc: Cardinal; const Buf: Pointer; L: NativeUInt);
  var
    p: PByte;
    i: Integer;
  begin
    p := Buf;
    i := 0;
    while i < L do
      begin
        crc := ((crc shr 8) and $00FFFFFF) xor C_CRC32Table[(crc xor p^) and $000000FF];
        inc(p);
        inc(i);
      end;
  end;

var
  j: NativeUInt;
  Num: NativeUInt;
  Rest: NativeUInt;
  Buf: Pointer;
  FSize: Int64;
begin
  if stream is TCore_MemoryStream then
    begin
      Result := umlCRC32(GetOffset(TCore_MemoryStream(stream).Memory, StartPos), EndPos - StartPos);
      exit;
    end;
  if stream is TMS64 then
    begin
      Result := umlCRC32(TMS64(stream).PositionAsPtr(StartPos), EndPos - StartPos);
      exit;
    end;

  { Allocate buffer to read file }
  Buf := GetMemory(ChunkSize);

  { Initialize CRC }
  Result := $FFFFFFFF;

  { V1.03 calculate how much of the file we are processing }
  FSize := stream.Size;
  if (StartPos >= FSize) then
      StartPos := 0;
  if (EndPos > FSize) or (EndPos = 0) then
      EndPos := FSize;

  { Calculate number of full chunks that will fit into the buffer }
  Num := EndPos div ChunkSize;
  { Calculate remaining bytes }
  Rest := EndPos mod ChunkSize;

  { Set the stream to the beginning of the file }
  stream.Position := StartPos;

  { Process full chunks }
  for j := 0 to Num - 1 do
    begin
      stream.Read(Buf^, ChunkSize);
      CRC32BUpdate(Result, Buf, ChunkSize);
    end;

  { Process remaining bytes }
  if Rest > 0 then
    begin
      stream.Read(Buf^, Rest);
      CRC32BUpdate(Result, Buf, Rest);
    end;

  FreeMem(Buf, ChunkSize);

  Result := Result xor $FFFFFFFF;
end;

function umlStreamCRC32(stream: U_Stream): Cardinal;
begin
  stream.Position := 0;
  Result := umlStreamCRC32(stream, 0, stream.Size);
  stream.Position := 0;
end;

function umlTrimSpace(const S: TPascalString): TPascalString;
var
  L, BP, EP: Integer;
begin
  Result := '';
  L := S.L;
  if L > 0 then
    begin
      BP := 1;
      while CharIn(S[BP], [#32, #0]) do
        begin
          inc(BP);
          if (BP > L) then
            begin
              Result := '';
              exit;
            end;
        end;
      if BP > L then
          Result := ''
      else
        begin
          EP := L;

          while CharIn(S[EP], [#32, #0]) do
            begin
              dec(EP);
              if (EP < 1) then
                begin
                  Result := '';
                  exit;
                end;
            end;
          Result := S.GetString(BP, EP + 1);
        end;
    end;
end;

function umlSeparatorText(Text_: TPascalString; dest: TCore_Strings; SeparatorChar: TPascalString): Integer;
var
  NewText_, SeparatorText_: TPascalString;
begin
  Result := 0;
  if Assigned(dest) then
    begin
      NewText_ := Text_;
      SeparatorText_ := umlGetFirstStr(NewText_, SeparatorChar);
      while (SeparatorText_.L > 0) and (NewText_.L > 0) do
        begin
          dest.add(SeparatorText_.text);
          inc(Result);
          NewText_ := umlDeleteFirstStr(NewText_, SeparatorChar);
          SeparatorText_ := umlGetFirstStr(NewText_, SeparatorChar);
        end;
    end;
end;

function umlSeparatorText(Text_: TPascalString; dest: THashVariantList; SeparatorChar: TPascalString): Integer;
var
  NewText_, SeparatorText_: TPascalString;
begin
  Result := 0;
  if Assigned(dest) then
    begin
      NewText_ := Text_;
      SeparatorText_ := umlGetFirstStr(NewText_, SeparatorChar);
      while (SeparatorText_.L > 0) and (NewText_.L > 0) do
        begin
          dest.IncValue(SeparatorText_.text, 1);
          inc(Result);
          NewText_ := umlDeleteFirstStr(NewText_, SeparatorChar);
          SeparatorText_ := umlGetFirstStr(NewText_, SeparatorChar);
        end;
    end;
end;

function umlSeparatorText(Text_: TPascalString; dest: TListPascalString; SeparatorChar: TPascalString): Integer;
var
  NewText_, SeparatorText_: TPascalString;
begin
  Result := 0;
  if Assigned(dest) then
    begin
      NewText_ := Text_;
      SeparatorText_ := umlGetFirstStr(NewText_, SeparatorChar);
      while (SeparatorText_.L > 0) and (NewText_.L > 0) do
        begin
          dest.add(SeparatorText_);
          inc(Result);
          NewText_ := umlDeleteFirstStr(NewText_, SeparatorChar);
          SeparatorText_ := umlGetFirstStr(NewText_, SeparatorChar);
        end;
    end;
end;

function umlSeparatorText(Text_: TPascalString; var dest: U_StringArray; SeparatorChar: TPascalString): Integer;
var
  L: TListPascalString;
  i: Integer;
begin
  L := TListPascalString.Create;
  Result := umlSeparatorText(Text_, L, SeparatorChar);
  SetLength(dest, L.Count);
  for i := 0 to L.Count - 1 do
      dest[i] := L[i];
  DisposeObject(L);
end;

function umlStringsMatchText(OriginValue: TCore_Strings; DestValue: TPascalString; IgnoreCase: Boolean): Boolean;
var
  i: Integer;
begin
  Result := False;
  if not Assigned(OriginValue) then
      exit;
  if OriginValue.Count > 0 then
    begin
      for i := 0 to OriginValue.Count - 1 do
        begin
          if umlMultipleMatch(IgnoreCase, OriginValue[i], DestValue) then
            begin
              Result := True;
              exit;
            end;
        end;
    end;
end;

function umlStringsInExists(dest: TListPascalString; SText: TPascalString; IgnoreCase: Boolean): Boolean;
var
  i: Integer;
  ns: TPascalString;
begin
  Result := False;
  if IgnoreCase then
      ns := umlUpperCase(SText)
  else
      ns := SText;
  if Assigned(dest) then
    begin
      if dest.Count > 0 then
        begin
          for i := 0 to dest.Count - 1 do
            begin
              if ((not IgnoreCase) and (SText = dest[i])) or ((IgnoreCase) and (umlSameText(SText, dest[i]))) then
                begin
                  Result := True;
                  exit;
                end;
            end;
        end;
    end;
end;

function umlStringsInExists(dest: TCore_Strings; SText: TPascalString; IgnoreCase: Boolean): Boolean;
var
  i: Integer;
  ns: TPascalString;
begin
  Result := False;
  if IgnoreCase then
      ns := umlUpperCase(SText)
  else
      ns := SText;
  if Assigned(dest) then
    begin
      if dest.Count > 0 then
        begin
          for i := 0 to dest.Count - 1 do
            begin
              if ((not IgnoreCase) and (SText = dest[i])) or ((IgnoreCase) and (umlSameText(SText, dest[i]))) then
                begin
                  Result := True;
                  exit;
                end;
            end;
        end;
    end;
end;

function umlStringsInExists(dest: TCore_Strings; SText: TPascalString): Boolean;
begin
  Result := umlStringsInExists(dest, SText, True);
end;

function umlTextInStrings(const SText: TPascalString; dest: TListPascalString; IgnoreCase: Boolean): Boolean;
begin
  Result := umlStringsInExists(dest, SText, IgnoreCase);
end;

function umlTextInStrings(const SText: TPascalString; dest: TCore_Strings; IgnoreCase: Boolean): Boolean;
begin
  Result := umlStringsInExists(dest, SText, IgnoreCase);
end;

function umlTextInStrings(const SText: TPascalString; dest: TCore_Strings): Boolean;
begin
  Result := umlStringsInExists(dest, SText);
end;

function umlAddNewStrTo(source: TPascalString; dest: TListPascalString; IgnoreCase: Boolean): Boolean;
begin
  Result := not umlStringsInExists(dest, source, IgnoreCase);
  if Result then
      dest.Append(source.text);
end;

function umlAddNewStrTo(source: TPascalString; dest: TCore_Strings; IgnoreCase: Boolean): Boolean;
begin
  Result := not umlStringsInExists(dest, source, IgnoreCase);
  if Result then
      dest.Append(source.text);
end;

function umlAddNewStrTo(source: TPascalString; dest: TCore_Strings): Boolean;
begin
  Result := not umlStringsInExists(dest, source, True);
  if Result then
      dest.Append(source.text);
end;

function umlAddNewStrTo(source, dest: TCore_Strings): Integer;
var
  i: Integer;
begin
  Result := 0;
  for i := 0 to source.Count - 1 do
    if umlAddNewStrTo(source[i], dest) then
        inc(Result);
end;

function umlDeleteStrings(const SText: TPascalString; dest: TCore_Strings; IgnoreCase: Boolean): Integer;
var
  i: Integer;
begin
  Result := 0;
  if Assigned(dest) then
    begin
      if dest.Count > 0 then
        begin
          i := 0;
          while i < dest.Count do
            begin
              if ((not IgnoreCase) and (SText = dest[i])) or ((IgnoreCase) and (umlMultipleMatch(IgnoreCase, SText, dest[i]))) then
                begin
                  dest.Delete(i);
                  inc(Result);
                end
              else
                  inc(i);
            end;
        end;
    end;
end;

function umlDeleteStringsNot(const SText: TPascalString; dest: TCore_Strings; IgnoreCase: Boolean): Integer;
var
  i: Integer;
begin
  Result := 0;
  if Assigned(dest) then
    begin
      if dest.Count > 0 then
        begin
          i := 0;
          while i < dest.Count do
            begin
              if ((not IgnoreCase) and (SText <> dest[i])) or ((IgnoreCase) and (not umlMultipleMatch(IgnoreCase, SText, dest[i]))) then
                begin
                  dest.Delete(i);
                  inc(Result);
                end
              else
                  inc(i);
            end;
        end;
    end;
end;

function umlMergeStrings(source, dest: TCore_Strings; IgnoreCase: Boolean): Integer;
var
  i: Integer;
begin
  Result := 0;
  if (source = nil) or (dest = nil) then
      exit;
  if source.Count > 0 then
    begin
      for i := 0 to source.Count - 1 do
        begin
          umlAddNewStrTo(source[i], dest, IgnoreCase);
          inc(Result);
        end;
    end;
end;

function umlMergeStrings(source, dest: TListPascalString; IgnoreCase: Boolean): Integer;
var
  i: Integer;
begin
  Result := 0;
  if (source = nil) or (dest = nil) then
      exit;
  if source.Count > 0 then
    begin
      for i := 0 to source.Count - 1 do
        begin
          umlAddNewStrTo(source[i], dest, IgnoreCase);
          inc(Result);
        end;
    end;
end;

function umlMergeStrings(source: TListPascalString; dest: TCore_Strings; IgnoreCase: Boolean): Integer;
var
  i: Integer;
begin
  Result := 0;
  if (source = nil) or (dest = nil) then
      exit;
  if source.Count > 0 then
    begin
      for i := 0 to source.Count - 1 do
        begin
          umlAddNewStrTo(source[i], dest, IgnoreCase);
          inc(Result);
        end;
    end;
end;

function umlConverStrToFileName(const Value: TPascalString): TPascalString;
var
  i: Integer;
begin
  Result := Value;
  for i := 1 to umlGetLength(Result) do
    begin
      if CharIn(Result[i], '":;/\|<>?*%') then
          Result[i] := ' ';
    end;
end;

function umlSplitTextMatch(const SText, Limit, MatchText: TPascalString; IgnoreCase: Boolean): Boolean;
var
  n, t: TPascalString;
begin
  Result := True;
  if MatchText = '' then
      exit;
  n := SText;
  //
  if umlExistsChar(n, Limit) then
    begin
      repeat
        t := umlGetFirstStr(n, Limit);
        if umlMultipleMatch(IgnoreCase, MatchText, t) then
            exit;
        n := umlDeleteFirstStr(n, Limit);
      until n = '';
    end
  else
    begin
      t := n;
      if umlMultipleMatch(IgnoreCase, MatchText, t) then
          exit;
    end;
  //
  Result := False;
end;

function umlSplitTextTrimSpaceMatch(const SText, Limit, MatchText: TPascalString; IgnoreCase: Boolean): Boolean;
var
  n, t: TPascalString;
begin
  Result := True;
  if MatchText = '' then
      exit;
  n := SText;

  if umlExistsChar(n, Limit) then
    begin
      repeat
        t := umlTrimSpace(umlGetFirstStr(n, Limit));
        if umlMultipleMatch(IgnoreCase, MatchText, t) then
            exit;
        n := umlDeleteFirstStr(n, Limit);
      until n = '';
    end
  else
    begin
      t := umlTrimSpace(n);
      if umlMultipleMatch(IgnoreCase, MatchText, t) then
          exit;
    end;

  Result := False;
end;

function umlSplitDeleteText(const SText, Limit, MatchText: TPascalString; IgnoreCase: Boolean): TPascalString;
var
  n, t: TPascalString;
begin
  if (MatchText = '') or (Limit = '') then
    begin
      Result := SText;
      exit;
    end;
  Result := '';
  n := SText;
  //
  if umlExistsChar(n, Limit) then
    begin
      repeat
        t := umlGetFirstStr(n, Limit);
        if not umlMultipleMatch(IgnoreCase, MatchText, t) then
          begin
            if Result <> '' then
                Result := Result + Limit[1] + t
            else
                Result := t;
          end;
        n := umlDeleteFirstStr(n, Limit);
      until n = '';
    end
  else
    begin
      t := n;
      if not umlMultipleMatch(IgnoreCase, MatchText, t) then
          Result := SText;
    end;
end;

function umlSplitTextAsList(const SText, Limit: TPascalString; AsLst: TCore_Strings): Boolean;
var
  n, t: TPascalString;
begin
  AsLst.Clear;
  n := SText;
  //
  if umlExistsChar(n, Limit) then
    begin
      repeat
        t := umlGetFirstStr(n, Limit);
        AsLst.Append(t.text);
        n := umlDeleteFirstStr(n, Limit);
      until n = '';
    end
  else
    begin
      t := n;
      if umlGetLength(t) > 0 then
          AsLst.Append(t.text);
    end;
  //
  Result := AsLst.Count > 0;
end;

function umlSplitTextAsListAndTrimSpace(const SText, Limit: TPascalString; AsLst: TCore_Strings): Boolean;
var
  n, t: TPascalString;
begin
  AsLst.Clear;
  n := SText;
  //
  if umlExistsChar(n, Limit) then
    begin
      repeat
        t := umlGetFirstStr(n, Limit);
        AsLst.Append(umlTrimSpace(t).text);
        n := umlDeleteFirstStr(n, Limit);
      until n = '';
    end
  else
    begin
      t := n;
      if umlGetLength(t) > 0 then
          AsLst.Append(umlTrimSpace(t).text);
    end;
  //
  Result := AsLst.Count > 0;
end;

function umlListAsSplitText(const List: TCore_Strings; Limit: TPascalString): TPascalString;
var
  i: Integer;
begin
  Result := '';
  for i := 0 to List.Count - 1 do
    if Result = '' then
        Result := List[i]
    else
        Result := Result + Limit + List[i];
end;

function umlListAsSplitText(const List: TListPascalString; Limit: TPascalString): TPascalString;
var
  i: Integer;
begin
  Result := '';
  for i := 0 to List.Count - 1 do
    if Result = '' then
        Result := List[i]
    else
        Result.Append(Limit + List[i]);
end;

function umlDivisionText(const buffer: TPascalString; width: Integer; DivisionAsPascalString: Boolean): TPascalString;
var
  i, n: Integer;
begin
  Result := '';
  n := 0;
  for i := 1 to buffer.L do
    begin
      if (DivisionAsPascalString) and (n = 0) then
          Result.Append(#39);

      Result.Append(buffer[i]);
      inc(n);
      if n = width then
        begin
          if DivisionAsPascalString then
              Result.Append(#39 + '+' + #13#10)
          else
              Result.Append(#13#10);
          n := 0;
        end;
    end;
  if DivisionAsPascalString then
      Result.Append(#39);
end;

function umlUpdateComponentName(const Name: TPascalString): TPascalString;
var
  i: Integer;
begin
  Result := '';
  for i := 1 to umlGetLength(name) do
    if umlGetLength(Result) > 0 then
      begin
        if CharIn(name[i], [c0to9, cLoAtoZ, cHiAtoZ], '-') then
            Result := Result + name[i];
      end
    else if CharIn(name[i], [cLoAtoZ, cHiAtoZ]) then
        Result := Result + name[i];
end;

function umlMakeComponentName(Owner: TCore_Component; RefrenceName: TPascalString): TPascalString;
var
  C: Cardinal;
begin
  C := 1;
  RefrenceName := umlUpdateComponentName(RefrenceName);
  Result := RefrenceName;
  while Owner.FindComponent(Result.text) <> nil do
    begin
      Result := RefrenceName + IntToStr(C);
      inc(C);
    end;
end;

procedure umlReadComponent(stream: TCore_Stream; comp: TCore_Component);
var
  R: TCore_Reader;
  needClearName: Boolean;
begin
  R := TCore_Reader.Create(stream, 4096);
  R.IgnoreChildren := True;
  try
    needClearName := (comp.Name = '');
    R.ReadRootComponent(comp);
    if needClearName then
        comp.Name := '';
  except
  end;
  DisposeObject(R);
end;

procedure umlWriteComponent(stream: TCore_Stream; comp: TCore_Component);
var
  w: TCore_Writer;
begin
  w := TCore_Writer.Create(stream, 4096);
  w.IgnoreChildren := True;
  w.WriteDescendent(comp, nil);
  DisposeObject(w);
end;

procedure umlCopyComponentDataTo(comp, copyto: TCore_Component);
var
  ms: TCore_MemoryStream;
begin
  if comp.ClassType <> copyto.ClassType then
      exit;
  ms := TCore_MemoryStream.Create;
  try
    umlWriteComponent(ms, comp);
    ms.Position := 0;
    umlReadComponent(ms, copyto);
  except
  end;
  DisposeObject(ms);
end;

function umlProcessCycleValue(CurrentVal, DeltaVal, StartVal, OverVal: Single; var EndFlag: Boolean): Single;
  function IfOut(Cur, Delta, dest: Single): Boolean;
  begin
    if Cur > dest then
        Result := Cur - Delta < dest
    else
        Result := Cur + Delta > dest;
  end;

  function GetOutValue(Cur, Delta, dest: Single): Single;
  begin
    if IfOut(Cur, Delta, dest) then
      begin
        if Cur > dest then
            Result := dest - (Cur - Delta)
        else
            Result := Cur + Delta - dest;
      end
    else
        Result := 0;
  end;

  function GetDeltaValue(Cur, Delta, dest: Single): Single;
  begin
    if Cur > dest then
        Result := Cur - Delta
    else
        Result := Cur + Delta;
  end;

begin
  if (DeltaVal > 0) and (StartVal <> OverVal) then
    begin
      if EndFlag then
        begin
          if IfOut(CurrentVal, DeltaVal, OverVal) then
            begin
              EndFlag := False;
              Result := umlProcessCycleValue(OverVal, GetOutValue(CurrentVal, DeltaVal, OverVal), StartVal, OverVal, EndFlag);
            end
          else
              Result := GetDeltaValue(CurrentVal, DeltaVal, OverVal);
        end
      else
        begin
          if IfOut(CurrentVal, DeltaVal, StartVal) then
            begin
              EndFlag := True;
              Result := umlProcessCycleValue(StartVal, GetOutValue(CurrentVal, DeltaVal, StartVal), StartVal, OverVal, EndFlag);
            end
          else
              Result := GetDeltaValue(CurrentVal, DeltaVal, StartVal);
        end
    end
  else
      Result := CurrentVal;
end;

procedure ImportCSV_C(const sour: TArrayPascalString; OnNotify: TCSVSave_C);
var
  i, j, BP, hc: NativeInt;
  n: TPascalString;
  king, buff: TArrayPascalString;
begin
  // csv head
  BP := -1;
  for i := low(sour) to high(sour) do
    begin
      n := sour[i];
      if n.L <> 0 then
        begin
          BP := i + 1;
          hc := n.GetCharCount(',') + 1;
          SetLength(buff, hc);
          SetLength(king, hc);

          for j := low(king) to high(king) do
              king[j] := '';
          j := 0;
          while (j < length(king)) and (n.L > 0) do
            begin
              king[j] := umlGetFirstStr___(n, ',');
              n := umlDeleteFirstStr___(n, ',');
              inc(j);
            end;

          break;
        end;
    end;

  // csv body
  if BP > 0 then
    for i := BP to high(sour) do
      begin
        n := sour[i];
        if n.L > 0 then
          begin
            for j := low(buff) to high(buff) do
                buff[j] := '';
            j := 0;
            while (j < length(buff)) and (n.L > 0) do
              begin
                buff[j] := umlGetFirstStr___(n, ',');
                n := umlDeleteFirstStr___(n, ',');
                inc(j);
              end;
            OnNotify(sour[i], king, buff);
          end;
      end;

  SetLength(buff, 0);
  SetLength(king, 0);
  n := '';
end;

procedure CustomImportCSV_C(const OnGetLine: TCSVGetLine_C; OnNotify: TCSVSave_C);
var
  IsEnd: Boolean;
  i, j, hc: NativeInt;
  n, S: TPascalString;
  king, buff: TArrayPascalString;
begin
  // csv head
  while True do
    begin
      IsEnd := False;
      n := '';
      OnGetLine(n, IsEnd);
      if IsEnd then
          exit;
      if n.L <> 0 then
        begin
          hc := n.GetCharCount(',') + 1;
          SetLength(buff, hc);
          SetLength(king, hc);

          for j := low(king) to high(king) do
              king[j] := '';
          j := 0;
          while (j < length(king)) and (n.L > 0) do
            begin
              king[j] := umlGetFirstStr___(n, ',');
              n := umlDeleteFirstStr___(n, ',');
              inc(j);
            end;

          break;
        end;
    end;

  // csv body
  while True do
    begin
      IsEnd := False;
      n := '';
      OnGetLine(n, IsEnd);
      if IsEnd then
          exit;
      if n.L > 0 then
        begin
          S := n;
          for j := low(buff) to high(buff) do
              buff[j] := '';
          j := 0;
          while (j < length(buff)) and (n.L > 0) do
            begin
              buff[j] := umlGetFirstStr___(n, ',');
              n := umlDeleteFirstStr___(n, ',');
              inc(j);
            end;
          OnNotify(S, king, buff);
        end;
    end;

  SetLength(buff, 0);
  SetLength(king, 0);
  n := '';
end;

procedure ImportCSV_M(const sour: TArrayPascalString; OnNotify: TCSVSave_M);
var
  i, j, BP, hc: NativeInt;
  n: TPascalString;
  king, buff: TArrayPascalString;
begin
  // csv head
  BP := -1;
  for i := low(sour) to high(sour) do
    begin
      n := sour[i];
      if n.L <> 0 then
        begin
          BP := i + 1;
          hc := n.GetCharCount(',') + 1;
          SetLength(buff, hc);
          SetLength(king, hc);

          for j := low(king) to high(king) do
              king[j] := '';
          j := 0;
          while (j < length(king)) and (n.L > 0) do
            begin
              king[j] := umlGetFirstStr___(n, ',');
              n := umlDeleteFirstStr___(n, ',');
              inc(j);
            end;

          break;
        end;
    end;

  // csv body
  if BP > 0 then
    for i := BP to high(sour) do
      begin
        n := sour[i];
        if n.L > 0 then
          begin
            for j := low(buff) to high(buff) do
                buff[j] := '';
            j := 0;
            while (j < length(buff)) and (n.L > 0) do
              begin
                buff[j] := umlGetFirstStr___(n, ',');
                n := umlDeleteFirstStr___(n, ',');
                inc(j);
              end;
            OnNotify(sour[i], king, buff);
          end;
      end;

  SetLength(buff, 0);
  SetLength(king, 0);
  n := '';
end;

procedure CustomImportCSV_M(const OnGetLine: TCSVGetLine_M; OnNotify: TCSVSave_M);
var
  IsEnd: Boolean;
  i, j, hc: NativeInt;
  n, S: TPascalString;
  king, buff: TArrayPascalString;
begin
  // csv head
  while True do
    begin
      IsEnd := False;
      n := '';
      OnGetLine(n, IsEnd);
      if IsEnd then
          exit;
      if n.L <> 0 then
        begin
          hc := n.GetCharCount(',') + 1;
          SetLength(buff, hc);
          SetLength(king, hc);

          for j := low(king) to high(king) do
              king[j] := '';
          j := 0;
          while (j < length(king)) and (n.L > 0) do
            begin
              king[j] := umlGetFirstStr___(n, ',');
              n := umlDeleteFirstStr___(n, ',');
              inc(j);
            end;

          break;
        end;
    end;

  // csv body
  while True do
    begin
      IsEnd := False;
      n := '';
      OnGetLine(n, IsEnd);
      if IsEnd then
          exit;
      if n.L > 0 then
        begin
          S := n;
          for j := low(buff) to high(buff) do
              buff[j] := '';
          j := 0;
          while (j < length(buff)) and (n.L > 0) do
            begin
              buff[j] := umlGetFirstStr___(n, ',');
              n := umlDeleteFirstStr___(n, ',');
              inc(j);
            end;
          OnNotify(S, king, buff);
        end;
    end;

  SetLength(buff, 0);
  SetLength(king, 0);
  n := '';
end;

procedure ImportCSV_P(const sour: TArrayPascalString; OnNotify: TCSVSave_P);
var
  i, j, BP, hc: NativeInt;
  n: TPascalString;
  king, buff: TArrayPascalString;
begin
  // csv head
  BP := -1;
  for i := low(sour) to high(sour) do
    begin
      n := sour[i];
      if n.L <> 0 then
        begin
          BP := i + 1;
          hc := n.GetCharCount(',') + 1;
          SetLength(buff, hc);
          SetLength(king, hc);

          for j := low(king) to high(king) do
              king[j] := '';
          j := 0;
          while (j < length(king)) and (n.L > 0) do
            begin
              king[j] := umlGetFirstStr___(n, ',');
              n := umlDeleteFirstStr___(n, ',');
              inc(j);
            end;

          break;
        end;
    end;

  // csv body
  if BP > 0 then
    for i := BP to high(sour) do
      begin
        n := sour[i];
        if n.L > 0 then
          begin
            for j := low(buff) to high(buff) do
                buff[j] := '';
            j := 0;
            while (j < length(buff)) and (n.L > 0) do
              begin
                buff[j] := umlGetFirstStr___(n, ',');
                n := umlDeleteFirstStr___(n, ',');
                inc(j);
              end;
            OnNotify(sour[i], king, buff);
          end;
      end;

  SetLength(buff, 0);
  SetLength(king, 0);
  n := '';
end;

procedure CustomImportCSV_P(const OnGetLine: TCSVGetLine_P; OnNotify: TCSVSave_P);
var
  IsEnd: Boolean;
  i, j, hc: NativeInt;
  n, S: TPascalString;
  king, buff: TArrayPascalString;
begin
  // csv head
  while True do
    begin
      IsEnd := False;
      n := '';
      OnGetLine(n, IsEnd);
      if IsEnd then
          exit;
      if n.L <> 0 then
        begin
          hc := n.GetCharCount(',') + 1;
          SetLength(buff, hc);
          SetLength(king, hc);

          for j := low(king) to high(king) do
              king[j] := '';
          j := 0;
          while (j < length(king)) and (n.L > 0) do
            begin
              king[j] := umlGetFirstStr___(n, ',');
              n := umlDeleteFirstStr___(n, ',');
              inc(j);
            end;

          break;
        end;
    end;

  // csv body
  while True do
    begin
      IsEnd := False;
      n := '';
      OnGetLine(n, IsEnd);
      if IsEnd then
          exit;
      if n.L > 0 then
        begin
          S := n;
          for j := low(buff) to high(buff) do
              buff[j] := '';
          j := 0;
          while (j < length(buff)) and (n.L > 0) do
            begin
              buff[j] := umlGetFirstStr___(n, ',');
              n := umlDeleteFirstStr___(n, ',');
              inc(j);
            end;
          OnNotify(S, king, buff);
        end;
    end;

  SetLength(buff, 0);
  SetLength(king, 0);
  n := '';
end;

type
  THash_ExtLibs = class(TString_Big_Hash_Pair_Pool<HMODULE>)
  end;

var
  __ExLibs__: THash_ExtLibs = nil;

function GetExtLib(LibName: SystemString): HMODULE;
begin
  Result := 0;
{$IF not(Defined(IOS) and Defined(CPUARM))}
  if __ExLibs__ = nil then
      __ExLibs__ := THash_ExtLibs.Create($FF);
  if not __ExLibs__.Exists(LibName) then
    begin
      try
{$IFNDEF FPC}
{$IFDEF ANDROID}
        Result := LoadLibrary(PChar(umlCombineFileName(System.IOUtils.TPath.GetLibraryPath, LibName).text));
{$ELSE ANDROID}
        Result := LoadLibrary(PChar(LibName));
{$ENDIF ANDROID}
{$ELSE FPC}
        Result := LoadLibrary(PAnsiChar(LibName));
{$ENDIF FPC}
        __ExLibs__.add(LibName, Result, False);
      except
        FreeExtLib(LibName);
        Result := 0;
      end;
    end
  else
      Result := __ExLibs__[LibName];
{$ENDIF}
end;

function FreeExtLib(LibName: SystemString): Boolean;
begin
  Result := False;
{$IF not(Defined(IOS) and Defined(CPUARM))}
  if __ExLibs__ = nil then
      __ExLibs__ := THash_ExtLibs.Create;
  if __ExLibs__.Exists(LibName) then
    begin
      try
          FreeLibrary(__ExLibs__[LibName]);
      except
      end;
      __ExLibs__.Delete(LibName);
      Result := True;
    end;
{$ENDIF}
end;

function GetExtProc(const LibName, ProcName: SystemString): Pointer;
{$IF not(Defined(IOS) and Defined(CPUARM))}
var
  H: HMODULE;
{$ENDIF}
begin
  Result := nil;
{$IF not(Defined(IOS) and Defined(CPUARM))}
  H := GetExtLib(LibName);
  if H <> 0 then
    begin
      Result := GetProcAddress(H, PChar(ProcName));
      if Result = nil then
          DoStatus('error external libray: %s - %s', [LibName, ProcName]);
    end;
{$ENDIF}
end;

{$IFDEF RangeCheck}{$R-}{$ENDIF}


function umlCompareByteString(const s1: TPascalString; const s2: PArrayRawByte): Boolean;
var
  Tmp: TBytes;
  i: Integer;
begin
  SetLength(Tmp, s1.L);
  for i := 0 to s1.L - 1 do
      Tmp[i] := Byte(s1.buff[i]);

  Result := CompareMemory(@Tmp[0], @s2^[0], s1.L);
end;

function umlCompareByteString(const s2: PArrayRawByte; const s1: TPascalString): Boolean;
var
  Tmp: TBytes;
  i: Integer;
begin
  SetLength(Tmp, s1.L);
  for i := 0 to s1.L - 1 do
      Tmp[i] := Byte(s1.buff[i]);

  Result := CompareMemory(@Tmp[0], @s2^[0], s1.L);
end;

procedure umlSetByteString(const sour: TPascalString; const dest: PArrayRawByte);
var
  i: Integer;
begin
  for i := 0 to sour.L - 1 do
      dest^[i] := Byte(sour.buff[i]);
end;

procedure umlSetByteString(const dest: PArrayRawByte; const sour: TPascalString);
var
  i: Integer;
begin
  for i := 0 to sour.L - 1 do
      dest^[i] := Byte(sour.buff[i]);
end;

function umlGetByteString(const sour: PArrayRawByte; const L: Integer): TPascalString;
var
  i: Integer;
begin
  Result.L := L;
  for i := 0 to L - 1 do
      Result.buff[i] := SystemChar(sour^[i]);
end;

{$IFDEF RangeCheck}{$R+}{$ENDIF}


procedure SaveMemory(p: Pointer; siz: NativeInt; DestFile: TPascalString);
var
  m64: TMem64;
begin
  m64 := TMem64.Create;
  m64.SetPointerWithProtectedMode(p, siz);
  m64.SaveToFile(DestFile);
  DisposeObject(m64);
end;

function umlBinToUInt8(Value: U_String): Byte;
var
  i, Size: Integer;
begin
  Result := 0;
  Size := Value.L;
  for i := Size downto 1 do
    begin
      if Value[i] = '1' then
          Result := Result + (1 shl (Size - i));
    end;
end;

function umlBinToUInt16(Value: U_String): Word;
var
  i, Size: Integer;
begin
  Result := 0;
  Size := Value.L;
  for i := Size downto 1 do
    begin
      if Value[i] = '1' then
          Result := Result + (1 shl (Size - i));
    end;
end;

function umlBinToUInt32(Value: U_String): Cardinal;
var
  i, Size: Integer;
begin
  Result := 0;
  Size := Value.L;
  for i := Size downto 1 do
    begin
      if Value[i] = '1' then
          Result := Result + (1 shl (Size - i));
    end;
end;

function umlBinToUInt64(Value: U_String): UInt64;
var
  i, Size: Integer;
begin
  Result := 0;
  Size := Value.L;
  for i := Size downto 1 do
    begin
      if Value[i] = '1' then
          Result := Result + (1 shl (Size - i));
    end;
end;

function umlUInt8ToBin(v: Byte): U_String;
begin
  if v = 0 then
    begin
      Result := '0';
      exit;
    end;
  Result := '';
  while v > 0 do
    begin
      if v and $1 = 1 then
          Result := '1' + Result
      else
          Result := '0' + Result;
      v := v shr 1;
    end;
  while Result.First = '0' do
      Result.DeleteFirst;
end;

function umlUInt16ToBin(v: Word): U_String;
begin
  if v = 0 then
    begin
      Result := '0';
      exit;
    end;
  Result := '';
  while v > 0 do
    begin
      if v and $1 = 1 then
          Result := '1' + Result
      else
          Result := '0' + Result;
      v := v shr 1;
    end;
  while Result.First = '0' do
      Result.DeleteFirst;
end;

function umlUInt32ToBin(v: Cardinal): U_String;
begin
  if v = 0 then
    begin
      Result := '0';
      exit;
    end;
  Result := '';
  while v > 0 do
    begin
      if v and $1 = 1 then
          Result := '1' + Result
      else
          Result := '0' + Result;
      v := v shr 1;
    end;
  while Result.First = '0' do
      Result.DeleteFirst;
end;

function umlUInt64ToBin(v: UInt64): U_String;
begin
  if v = 0 then
    begin
      Result := '0';
      exit;
    end;
  Result := '';
  while v > 0 do
    begin
      if v and $1 = 1 then
          Result := '1' + Result
      else
          Result := '0' + Result;
      v := v shr 1;
    end;
  while Result.First = '0' do
      Result.DeleteFirst;
end;

function umlBufferIsASCII(buffer: Pointer; siz: NativeUInt): Boolean;
var
  i: NativeInt;
  p: PByte;
begin
  Result := False;
  i := 0;
  p := buffer;
  while i < siz do
    begin
      if p^ > $80 then
          exit;
      inc(p);
      inc(i);
    end;
  Result := True;
end;

initialization

FileMD5Cache := TFileMD5Cache.Create;
CacheFileMD5FromDirectory_Num := 0;
CacheThreadIsAcivted := True;

Lib_DateTimeFormatSettings := FormatSettings;
Lib_DateTimeFormatSettings.ShortDateFormat := 'yyyy-MM-dd';
Lib_DateTimeFormatSettings.LongDateFormat := 'yyyy-MM-dd';
Lib_DateTimeFormatSettings.DateSeparator := '-';
Lib_DateTimeFormatSettings.TimeSeparator := ':';
Lib_DateTimeFormatSettings.DecimalSeparator := '.';
Lib_DateTimeFormatSettings.LongTimeFormat := 'hh:mm:ss.zz';
Lib_DateTimeFormatSettings.ShortTimeFormat := 'hh:mm:ss.zz';

__ExLibs__ := nil;

finalization

CacheThreadIsAcivted := False;
while CacheFileMD5FromDirectory_Num > 0 do
    TCompute.Sleep(1);

if __ExLibs__ <> nil then
    DisposeObjectAndNil(__ExLibs__);
DisposeObject(FileMD5Cache);

end.

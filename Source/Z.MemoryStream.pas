{
  * ****************************************************************************
  * Z.MemoryStream
  * ==============
  * High‑performance 64‑bit memory stream and compression library for Delphi/FPC.
  *
  * Provides two main stream classes:
  *   - TMS64  : inherits from TCore_Stream (TStream), suitable as a drop‑in
  *              replacement for TMemoryStream with 64‑bit addressing.
  *   - TMem64 : independent object, also 64‑bit, but not derived from TStream.
  *
  * Both support:
  *   - 64‑bit capacity (up to >2GB)
  *   - Delta‑based incremental expansion (customisable growth step)
  *   - Zero‑copy memory mapping (read‑only or read‑write)
  *   - Protected (read‑only) mode
  *   - Built‑in LZ4, Snappy and ZLIB compression/decompression
  *   - Rich serialisation methods for basic types, strings, MD5, etc.
  *
  * Additionally, the unit provides global compression/decompression routines,
  * parallel compression, stream‑based serialisation helpers and trigger
  * interfaces for monitoring I/O.
  *
  * @Example (basic usage):
  *   var
  *     ms: TMS64;
  *   begin
  *     ms := TMS64.Create;
  *     ms.WriteString('Hello, world!');
  *     ms.Position := 0;
  *     WriteLn(ms.ReadString); // prints the string
  *     ms.Free;
  *   end;
  * ****************************************************************************
  * }
unit Z.MemoryStream;

{$DEFINE FPC_DELPHI_MODE}
{$I Z.Define.inc}

interface

uses
  SysUtils,
{$IFDEF FPC}
  zstream,
  Z.FPC.GenericList,
{$ELSE FPC}
  ZLib,
{$ENDIF FPC}
  Z.Core, Z.PascalStrings, Z.UPascalStrings, Z.Int128;

type
  { *
    * TMem64: Forward declaration needed for cross‑references between TMS64 and
    * TMem64, as they can map to each other.
  }
  TMem64 = class;

  { *
    * TMS64: 64‑bit memory stream that inherits from TCore_Stream (TStream).
    * It can be used anywhere a TStream is expected, but offers extended
    * capabilities: 64‑bit addressing, delta expansion, mapping, compression,
    * and typed serialisation.
    *
    * @Note: The stream is not thread‑safe; external locking is required for
    *        concurrent access.
    *
    * @Example (create, write, read, compress):
    *   var
    *     ms, compressed: TMS64;
    *   begin
    *     ms := TMS64.Create;
    *     ms.WriteInt32(12345);           // write integer
    *     ms.WriteString('data');         // write string (UTF‑8)
    *     compressed := ms.LZ4;           // compress with LZ4
    *     // ... use compressed ...
    *     compressed.Free;
    *     ms.Free;
    *   end;
  }
  TMS64 = class(TCore_Stream)
  private
    FDelta: NativeInt; // Growth step size (clamped 64..1MB)
    FMemory: Pointer; // Pointer to the raw memory buffer
    FSize: NativeUInt; // Current used size (bytes)
    FPosition: NativeUInt; // Current read/write position (bytes)
    FCapacity: NativeUInt; // Allocated buffer size (bytes)
    FProtectedMode: Boolean; // If True, the stream is read‑only (mapped)
    FMem64: TMem64; // Cached TMem64 mapping instance (if any)
  protected
    { *
      * SetPointer: Assigns an external buffer to the stream, updating FMemory
      * and FSize. Used internally by Mapping and SetPointerWithProtectedMode.
    }
    procedure SetPointer(buffPtr: Pointer; const BuffSize: NativeUInt);

    { *
      * SetCapacity: Reallocates the buffer to NewCapacity bytes (if not in
      * protected mode). The actual allocation is performed by Realloc.
    }
    procedure SetCapacity(NewCapacity: NativeUInt);

    { *
      * Realloc: Performs the low‑level memory allocation or reallocation.
      * Returns the new pointer. If NewCapacity=0, frees the buffer.
      * Uses DeltaStep to round up NewCapacity to a multiple of FDelta.
      * Raises an exception on out‑of‑memory.
    }
    function Realloc(var NewCapacity: NativeUInt): Pointer; virtual;

    { *
      * SetDelta: Sets the growth step (clamped to 64..1MB). The value is
      * applied via DeltaStep when expanding the buffer.
    }
    procedure SetDelta(const Value: NativeInt);

    { *
      * Capacity: The currently allocated buffer size (read‑only through
      * property, but can be set via SetCapacity).
    }
    property Capacity: NativeUInt read FCapacity write SetCapacity;
  public
    { * Default constructor, uses Delta = 256. }
    constructor Create;

    { *
      * CustomCreate: Creates the stream with a specified Delta growth step.
      * @param customDelta: initial growth step (will be clamped).
    }
    constructor CustomCreate(const customDelta: NativeInt);

    { * Destructor: frees the buffer and any cached TMem64 instance. }
    destructor Destroy; override;

    { *
      * Mem64: Returns a TMem64 object that maps to this stream's data.
      * If Mapping_Begin_As_Position_=True, the mapping starts at the current
      * position and covers the remaining bytes; otherwise it maps the entire
      * stream. The TMem64 is cached and reused.
      * @param Mapping_Begin_As_Position_: if True, maps from current position
      *        to end; if False, maps the whole stream.
      * @return a TMem64 instance referencing the same memory.
    }
    function Mem64(Mapping_Begin_As_Position_: Boolean): TMem64; overload;

    { * Overloaded version: maps the whole stream (calls Mem64(False)). }
    function Mem64: TMem64; overload;

    { *
      * NewClone: Creates an independent deep copy of the stream.
      * The clone has its own buffer and the same Delta, size, and position.
    }
    function NewClone: TMS64;

    { *
      * Create_Mapping_Instance: Creates a new TMS64 that maps (zero‑copy) to
      * this stream's buffer. The new stream is read‑only and shares the same
      * memory. The caller must not free the original while the mapping is used.
    }
    function Create_Mapping_Instance: TMS64;

    { * Same as Create_Mapping_Instance but returns a TMem64 instead. }
    function Create_Mapping_Instance_Mem64: TMem64;

    { *
      * Swap_To_New_Instance: Creates a new, empty TMS64 and swaps its internal
      * data with this stream. After the call, this stream becomes empty and
      * the new instance holds the original data.
    }
    function Swap_To_New_Instance: TMS64;

    { *
      * DiscardMemory: Releases the internal buffer pointer without freeing it.
      * Use with extreme caution – the memory becomes inaccessible and the
      * stream is left in an invalid state. Typically used when the buffer is
      * owned externally and must not be freed by the stream.
    }
    procedure DiscardMemory;

    { *
      * Clear: Frees the buffer and resets size and position to 0. No‑op in
      * protected mode.
    }
    procedure Clear;

    { *
      * NewParam: Replaces the stream's internal state with another TMS64.
      * The current buffer is cleared first, then the internal fields are copied.
      * The source stream remains unchanged.
    }
    procedure NewParam(source: TMS64); overload;

    { * Same as above, but copies from a TMem64. }
    procedure NewParam(source: TMem64); overload;

    { *
      * SwapInstance: Efficiently exchanges the entire internal state (buffer,
      * size, position, capacity, delta, protected mode) with another TMS64.
      * O(1) operation, no data copying.
    }
    procedure SwapInstance(source: TMS64); overload;

    { * Same as above, but with a TMem64. }
    procedure SwapInstance(source: TMem64); overload;

    { *
      * ToBytes: Copies the stream's data into a dynamic TBytes array.
      * The caller receives a separate copy.
    }
    function ToBytes: TBytes;

    { * ToMD5: Computes the MD5 hash of the entire stream content. }
    function ToMD5: TMD5;

    { *
      * Same: Compares this stream's content with a TMem64 for equality.
      * Returns True if both have the same size and identical byte content.
    }
    function Same(source: TMem64): Boolean;

    { *
      * LZ4: Compresses the stream's data using the LZ4 algorithm.
      * Returns a new TMS64 containing the compressed data in the format:
      *   [OriginalSize: Int64][CompressedSize: Int64][CompressedData].
    }
    function LZ4: TMS64;

    { *
      * UnLZ4: Decompresses data that was compressed with LZ4 (format above).
      * Returns a new TMS64 with the original data.
    }
    function UnLZ4: TMS64;

    { *
      * Snappy_Pas: Compresses the stream using Snappy (pure Pascal
      * implementation). Output format same as LZ4.
    }
    function Snappy_Pas: TMS64;

    { * UnSnappy_Pas: Decompresses Snappy‑compressed data. }
    function UnSnappy_Pas: TMS64;

    { * Delta: The growth step (can be read or set). }
    property Delta: NativeInt read FDelta write SetDelta;

    { * ProtectedMode: True if the stream is read‑only (mapped). }
    property ProtectedMode: Boolean read FProtectedMode;

    { *
      * SetPointerWithProtectedMode: Same as Mapping, sets the stream to
      * point to an external buffer with read‑only protection.
    }
    procedure SetPointerWithProtectedMode(buffPtr: Pointer; const BuffSize: Int64);

    { *
      * Mapping: Makes the stream point to an external buffer. The stream
      * becomes protected (read‑only) and will not own the memory.
      * @param buffPtr: pointer to the external buffer.
      * @param BuffSize: size in bytes.
    }
    procedure Mapping(buffPtr: Pointer; const BuffSize: Int64); overload;

    { * Maps the stream to another TMS64's buffer. }
    procedure Mapping(m64: TMS64); overload;

    { * Maps the stream to a TMem64's buffer. }
    procedure Mapping(m64: TMem64); overload;

    { *
      * PositionAsPtr: Returns a pointer to the byte at the given position.
      * Does not change the current position.
    }
    function PositionAsPtr(const Position_: Int64): Pointer; overload;

    { * Returns a pointer to the current position. }
    function PositionAsPtr: Pointer; overload;

    { * Alias for PositionAsPtr. }
    function PosAsPtr(const Position_: Int64): Pointer; overload;
    function PosAsPtr: Pointer; overload;

    { *
      * LoadFromStream: Reads the entire content of another stream into this
      * one, replacing its current data. The source stream is read from position 0.
    }
    procedure LoadFromStream(stream: TCore_Stream); virtual;

    { * Loads data from a file (binary). }
    procedure LoadFromFile(FileName: SystemString);

    { *
      * SaveToStream: Writes the stream's data to another stream. If the
      * destination is a TMS64, it uses zero‑copy for efficiency. Otherwise,
      * writes in chunks of 64MB to handle large sizes.
    }
    procedure SaveToStream(stream: TCore_Stream); virtual;

    { * Saves the stream's data to a file. }
    procedure SaveToFile(FileName: SystemString);

    { *
      * SetSize: Changes the stream's size. If the new size is larger, the
      * buffer is expanded (if not protected). If smaller, the size is truncated.
      * Position is adjusted if it exceeds the new size.
    }
    procedure SetSize(const NewSize: Int64); overload; override;
    procedure SetSize(NewSize: longint); overload; override;

    { *
      * Write64: Writes Count bytes from buffer to the stream at the current
      * position. Expands the stream if necessary. Returns the number of bytes
      * written (should equal Count on success, 0 if protected mode or invalid).
    }
    function Write64(const buffer; Count: Int64): Int64; virtual;

    { * WritePtr: Writes Count bytes from the given pointer. }
    function WritePtr(const p: Pointer; Count: Int64): Int64;

    { * Override of TStream.Write (32‑bit Count). }
    function write(const buffer; Count: longint): longint; overload; override;

    { * WriteBytes: Writes a TBytes array. }
    procedure WriteBytes(const buff: TBytes);

    { *
      * Read64: Reads up to Count bytes from the stream into buffer at the
      * current position. Returns the actual number of bytes read (may be less
      * than Count if end of stream).
    }
    function Read64(var buffer; Count: Int64): Int64; virtual;

    { * ReadPtr: Reads Count bytes into the given pointer. }
    function ReadPtr(const p: Pointer; Count: Int64): Int64;

    { * Override of TStream.Read (32‑bit Count). }
    function read(var buffer; Count: longint): longint; overload; override;

{$IFDEF DELPHI}
    { * Delphi‑specific overloads for TBytes with offset/count. }
    function write(const buffer: TBytes; Offset, Count: longint): longint; overload; override;
    function read(buffer: TBytes; Offset, Count: longint): longint; overload; override;
{$ENDIF DELPHI}
    { *
      * Seek: Changes the current position. Returns the new position.
      * @param Offset: offset relative to origin.
      * @param origin: soBeginning, soCurrent, or soEnd.
    }
    function Seek(const Offset: Int64; origin: TSeekOrigin): Int64; override;

    { * Memory: Pointer to the raw buffer (read‑only). }
    property Memory: Pointer read FMemory;

    { *
      * CopyMem64: Copies Count bytes from a TMem64's current position into
      * this stream, advancing both positions. Returns number of bytes copied.
    }
    function CopyMem64(const source: TMem64; Count: Int64): Int64;

    { *
      * CopyFrom: Copies data from another stream. If Count is negative, copies
      * the entire source stream from position 0. Returns bytes copied.
    }
    function CopyFrom(const source: TCore_Stream; Count: Int64): Int64; overload;
    function CopyFrom(const source: TMem64; Count: Int64): Int64; overload;

    { ****** Typed write methods ********** }
    procedure WriteBool(const buff: Boolean);
    procedure WriteInt8(const buff: ShortInt);
    procedure WriteInt16(const buff: SmallInt);
    procedure WriteInt32(const buff: Integer);
    procedure WriteInt64(const buff: Int64);
    procedure WriteInt128(const buff: Int128);
    procedure WriteUInt8(const buff: Byte);
    procedure WriteUInt16(const buff: Word);
    procedure WriteUInt32(const buff: Cardinal);
    procedure WriteUInt64(const buff: UInt64);
    procedure WriteUInt128(const buff: UInt128);
    procedure WriteSingle(const buff: Single);
    procedure WriteDouble(const buff: Double);
    procedure WriteCurrency(const buff: Currency);
    procedure WriteString(const buff: TPascalString); overload;
    procedure WriteANSI(const buff: TPascalString); overload;
    procedure WriteANSI(const buff: TPascalString; const L: Integer); overload;
    procedure WriteString(const buff: TUPascalString); overload;
    procedure WriteANSI(const buff: TUPascalString); overload;
    procedure WriteANSI(const buff: TUPascalString; const L: Integer); overload;

    procedure WriteMD5(const buff: TMD5);

    { ****** Typed read methods ********** }
    function ReadBool: Boolean;
    function ReadInt8: ShortInt;
    function ReadInt16: SmallInt;
    function ReadInt32: Integer;
    function ReadInt64: Int64;
    function ReadInt128: Int128;
    function ReadUInt8: Byte;
    function ReadUInt16: Word;
    function ReadUInt32: Cardinal;
    function ReadUInt64: UInt64;
    function ReadUInt128: UInt128;
    function ReadSingle: Single;
    function ReadDouble: Double;
    function ReadCurrency: Currency;

    { *
      * PrepareReadString: Checks that there are at least 4 bytes for the length
      * and that the full string fits in the stream. Returns True if safe.
    }
    function PrepareReadString: Boolean;

    { *
      * ReadString: Reads a string that was written with WriteString.
      * Returns the decoded UTF‑8 string.
    }
    function ReadString: TPascalString;

    { *
      * ReadStringAsBuff: Reads the string but returns the raw UTF‑8 bytes
      * without decoding.
    }
    function ReadStringAsBuff: TBytes;

    { *
      * IgnoreReadString: Skips over a string without reading its content.
    }
    procedure IgnoreReadString;

    { *
      * ReadANSI: Reads L bytes as ANSI and returns them as a TPascalString.
      * No length prefix is expected.
    }
    function ReadANSI(L: Integer): TPascalString;

    function ReadMD5: TMD5;
  end;

  TMS64_Array = array of TMS64;
  TStream64_Array = TMS64_Array;
  TMemoryStream64_Array = TMS64_Array;
  TStream64 = TMS64;
  TMemoryStream64 = TMS64;

  { *
    * TMemoryStream64List_Decl: Alias for TGenericsList<TMS64>.
  }
  TMemoryStream64List_Decl = TGenericsList<TMS64>;

  { *
    * TMemoryStream64List: A simple list of TMS64 objects. Provides Clean to
    * free all contained streams.
  }
  TMemoryStream64List = class(TMemoryStream64List_Decl)
  public
    { * Clean: Frees all streams in the list and clears the list. }
    procedure Clean;
    { * To_Array: Returns a dynamic array of the contained streams. }
    function To_Array: TMS64_Array;
  end;

  TStream64List = TMemoryStream64List;
  TMS64List = TMemoryStream64List;

  { * TMS64_Pool: Object pool (TBig_Object_List) for TMS64. }
  TMS64_Pool = TBig_Object_List<TMS64>;

  { *
    * TMemoryStream64ThreadList: Thread‑safe list of TMS64 streams, using a
    * critical section. Optionally auto‑frees streams when removed.
  }
  TMemoryStream64ThreadList = class(TMemoryStream64List_Decl)
  private
    FCritical: TCritical; // Lock for thread safety
  public
    AutoFree_Stream: Boolean; // If True, streams are freed on removal
    constructor Create;
    destructor Destroy; override;
    procedure Lock;
    procedure UnLock;
    procedure Remove(obj: TMS64);
    procedure Delete(index: Integer);
    procedure Clear;
    procedure Clean; // Frees all streams and clears list
    function To_Array: TMS64_Array;
  end;

  TStream64CriticalList = TMemoryStream64ThreadList;
  TMS64CriticalList = TMemoryStream64ThreadList;
  TStream64ThreadList = TMemoryStream64ThreadList;
  TMS64ThreadList = TMemoryStream64ThreadList;

  { *
    * IMemoryStream64WriteTrigger: Interface for write notifications.
  }
  IMemoryStream64WriteTrigger = interface
    procedure TriggerWrite64(Count: Int64);
  end;

  { *
    * TMemoryStream64OfWriteTrigger: A TMS64 that calls a trigger on every write.
  }
  TMemoryStream64OfWriteTrigger = class(TMS64)
  public
    Trigger: IMemoryStream64WriteTrigger;
    constructor Create(ATrigger: IMemoryStream64WriteTrigger);
    function Write64(const buffer; Count: Int64): Int64; override;
  end;

  IMemoryStream64ReadTrigger = interface
    procedure TriggerRead64(Count: Int64);
  end;

  TMemoryStream64OfReadTrigger = class(TMS64)
  public
    Trigger: IMemoryStream64ReadTrigger;
    constructor Create(ATrigger: IMemoryStream64ReadTrigger);
    function Read64(var buffer; Count: Int64): Int64; override;
  end;

  IMemoryStream64ReadWriteTrigger = interface
    procedure TriggerWrite64(Count: Int64);
    procedure TriggerRead64(Count: Int64);
  end;

  TMemoryStream64OfReadWriteTrigger = class(TMS64)
  public
    Trigger: IMemoryStream64ReadWriteTrigger;
    constructor Create(ATrigger: IMemoryStream64ReadWriteTrigger);
    function Read64(var buffer; Count: Int64): Int64; override;
    function Write64(const buffer; Count: Int64): Int64; override;
  end;

  { *
    * TMem64: 64‑bit memory buffer that does not inherit from TStream.
    * It offers the same capabilities as TMS64 but is a standalone object.
    * It can be converted to TMS64 via Stream64().
    *
    * @Note: Unlike TMS64, its Size/Position properties are Int64 (signed),
    *        but they still support >2GB.
    *
    * @Example:
    *   var
    *     mem: TMem64;
    *   begin
    *     mem := TMem64.Create;
    *     mem.WriteString('Hello');
    *     WriteLn(mem.Size); // 9 (4 bytes length + 5 bytes UTF‑8)
    *     mem.Free;
    *   end;
  }
  TMem64 = class(TCore_Object)
  private
    FDelta: NativeInt; // growth step
    FMemory: Pointer; // pointer to buffer
    FSize: Int64; // current used size (signed)
    FPosition: Int64; // current position (signed)
    FCapacity: Int64; // allocated buffer size (signed)
    FProtectedMode: Boolean; // read‑only flag
    FStream64: TMS64; // cached TMS64 mapping
  protected
    procedure SetPointer(buffPtr: Pointer; const BuffSize: Int64);
    procedure SetCapacity(NewCapacity: Int64);
    function Realloc(var NewCapacity: Int64): Pointer;
    property Capacity: Int64 read FCapacity write SetCapacity;
    function GetDelta: NativeInt;
    procedure SetDelta(const Value: NativeInt);
    function GetMemory_: Pointer;
    function GetPosition: Int64;
    procedure SetPosition(const Value: Int64);
    function GetSize: Int64;
    procedure SetSize(const NewSize: Int64);
  public
    constructor Create;
    constructor CustomCreate(const customDelta: NativeInt);
    destructor Destroy; override;

    { * Stream64: Returns a TMS64 that maps to this buffer. }
    function Stream64(Mapping_Begin_As_Position_: Boolean): TMS64; overload;
    function Stream64: TMS64; overload;

    { * NewClone: Deep copy. }
    function NewClone: TMem64;

    { * Create_Mapping_Instance: Zero‑copy mapping (read‑only). }
    function Create_Mapping_Instance: TMem64;
    function Create_Mapping_Instance_MS64: TMS64;

    { * Swap_To_New_Instance: Creates new empty instance and swaps data. }
    function Swap_To_New_Instance: TMem64;

    procedure DiscardMemory;
    procedure Clear;
    procedure NewParam(source: TMS64); overload;
    procedure NewParam(source: TMem64); overload;
    procedure SwapInstance(source: TMS64); overload;
    procedure SwapInstance(source: TMem64); overload;

    function ToBytes: TBytes;
    function ToMD5: TMD5;
    function Same(source: TMem64): Boolean;

    { * Compression methods, same format as TMS64. }
    function LZ4: TMem64;
    function UnLZ4: TMem64;
    function Snappy_Pas: TMem64;
    function UnSnappy_Pas: TMem64;

    property Delta: NativeInt read GetDelta write SetDelta;
    property Memory: Pointer read GetMemory_;
    property Position: Int64 read GetPosition write SetPosition;
    property Size: Int64 read GetSize write SetSize;
    property ProtectedMode: Boolean read FProtectedMode;

    procedure SetPointerWithProtectedMode(buffPtr: Pointer; const BuffSize: Int64);
    procedure Mapping(buffPtr: Pointer; const BuffSize: Int64); overload;
    procedure Mapping(m64: TMS64); overload;
    procedure Mapping(m64: TMem64); overload;

    function PositionAsPtr(const Position_: Int64): Pointer; overload;
    function PositionAsPtr: Pointer; overload;
    function PosAsPtr(const Position_: Int64): Pointer; overload;
    function PosAsPtr: Pointer; overload;

    procedure LoadFromStream(stream: TCore_Stream);
    procedure LoadFromFile(FileName: SystemString);
    procedure SaveToStream(stream: TCore_Stream);
    procedure SaveToFile(FileName: SystemString);

    { * I/O methods (no override, but similar to TMS64). }
    function Write64(const buffer; Count: Int64): Int64;
    function WritePtr(const p: Pointer; Count: Int64): Int64;
    function write(const buffer; Count: Int64): Int64;
    function WriteBytes(const buffer: TBytes): Int64;
    function Read64(var buffer; Count: Int64): Int64;
    function ReadPtr(const p: Pointer; Count: Int64): Int64;
    function read(var buffer; Count: Int64): Int64;
    function Seek(const Offset: Int64; origin: TSeekOrigin): Int64;

    function CopyFrom(const source: TCore_Stream; Count: Int64): Int64; overload;
    function CopyFrom(const source: TMem64; Count: Int64): Int64; overload;

    { ****** Typed write/read (same as TMS64) ********** }
    procedure WriteBool(const buff: Boolean);
    procedure WriteInt8(const buff: ShortInt);
    procedure WriteInt16(const buff: SmallInt);
    procedure WriteInt32(const buff: Integer);
    procedure WriteInt64(const buff: Int64);
    procedure WriteInt128(const buff: Int128);
    procedure WriteUInt8(const buff: Byte);
    procedure WriteUInt16(const buff: Word);
    procedure WriteUInt32(const buff: Cardinal);
    procedure WriteUInt64(const buff: UInt64);
    procedure WriteUInt128(const buff: UInt128);
    procedure WriteSingle(const buff: Single);
    procedure WriteDouble(const buff: Double);
    procedure WriteCurrency(const buff: Currency);
    procedure WriteString(const buff: TPascalString); overload;
    procedure WriteANSI(const buff: TPascalString); overload;
    procedure WriteANSI(const buff: TPascalString; const L: Integer); overload;
    procedure WriteString(const buff: TUPascalString); overload;
    procedure WriteANSI(const buff: TUPascalString); overload;
    procedure WriteANSI(const buff: TUPascalString; const L: Integer); overload;
    procedure WriteMD5(const buff: TMD5);

    function ReadBool: Boolean;
    function ReadInt8: ShortInt;
    function ReadInt16: SmallInt;
    function ReadInt32: Integer;
    function ReadInt64: Int64;
    function ReadInt128: Int128;
    function ReadUInt8: Byte;
    function ReadUInt16: Word;
    function ReadUInt32: Cardinal;
    function ReadUInt64: UInt64;
    function ReadUInt128: UInt128;
    function ReadSingle: Single;
    function ReadDouble: Double;
    function ReadCurrency: Currency;
    function PrepareReadString: Boolean;
    function ReadString: TPascalString;
    function ReadStringAsBuff: TBytes;
    procedure IgnoreReadString;
    function ReadANSI(L: Integer): TPascalString;
    function ReadMD5: TMD5;
  end;

  TMem64_Array = array of TMem64;
  TM64 = TMem64;

  { * TMem64List: List of TMem64 with Clean method. }
  TMem64List_Decl = TGenericsList<TMem64>;

  TMem64List = class(TMem64List_Decl)
  public
    procedure Clean;
  end;

  TM64List = TMem64List;
  TMem64_Pool = TBig_Object_List<TMem64>;

  { *
    * TDecompressionStream and TCompressionStream are aliases to the ZLib
    * implementations. Under FPC, we use zstream; under Delphi, ZLib.
  }
{$IFDEF FPC}

  TDecompressionStream = class(zstream.TDecompressionStream)
  public
  end;

  TCompressionStream = class(zstream.TCompressionStream)
  public
    constructor Create(stream: TCore_Stream); overload;
    constructor Create(level: Tcompressionlevel; stream: TCore_Stream); overload;
  end;
{$ELSE}

  TDecompressionStream = ZLib.TZDecompressionStream;
  TCompressionStream = ZLib.TZCompressionStream;
{$ENDIF}
  { *
    * TSelectCompressionMethod: Enumeration of supported compression algorithms.
  }
  TSelectCompressionMethod = (scmNone, scmZLIB, scmZLIB_Fast, scmZLIB_Max,
    scmDeflate, scmBRRC, scmLZ4, scmSnappy_Pas);

  { ****** Global compression/decompression functions ********** }

  { *
    * MaxCompressStream: Compresses sour into dest using ZLIB with maximum
    * compression. Writes the original size (8 bytes) before the compressed data.
    * Returns True on success.
  }
function MaxCompressStream(sour, dest: TCore_Stream): Boolean;

{ *
  * FastCompressStream: Compresses using ZLIB with fastest compression.
}
function FastCompressStream(sour, dest: TCore_Stream): Boolean;

{ *
  * CompressStream: Compresses using ZLIB with default compression.
}
function CompressStream(sour, dest: TCore_Stream): Boolean; overload;

{ *
  * DecompressStream: Decompresses data from a pointer or stream.
  * Overloads accept pointer+size, source stream, and can output to a stream
  * or a pointer (allocated by the function).
}
function DecompressStream(DataPtr: Pointer; siz: NativeInt; dest: TCore_Stream): Boolean; overload;
function DecompressStream(sour: TCore_Stream; dest: TCore_Stream): Boolean; overload;
function DecompressStreamToPtr(sour: TCore_Stream; var dest: Pointer): Boolean; overload;

{ * CompressFile / DecompressFile: File‑to‑file compression (ZLIB). }
function CompressFile(sour, dest: SystemString): Boolean;
function DecompressFile(sour, dest: SystemString): Boolean;

{ *
  * SelectCompressStream: Compresses using a specified method. The first byte
  * written is the method ID, so SelectDecompressStream can auto‑detect.
}
function SelectCompressStream(const scm: TSelectCompressionMethod; const sour, dest: TCore_Stream): Boolean;

{ *
  * SelectDecompressStream: Reads the method ID and decompresses accordingly.
  * Returns True on success. Optionally returns the method used.
}
function SelectDecompressStream(const sour, dest: TCore_Stream): Boolean; overload;
function SelectDecompressStream(const sour, dest: TCore_Stream; var scm: TSelectCompressionMethod): Boolean; overload;

{ ****** Parallel compression/decompression ********** }

{ *
  * ParallelCompressMemory: Splits the source TMS64 into strips and compresses
  * each strip in parallel (using the thread pool). The output format is:
  *   [StripCount: Integer]
  *   for each strip: [StripSize: Int64][CompressedData]
  * The dest stream receives the concatenated output.
}
procedure ParallelCompressMemory(const ThNum: Integer; const scm: TSelectCompressionMethod; const StripNum_: Integer; const sour: TMS64; const dest: TCore_Stream); overload;
procedure ParallelCompressMemory(const scm: TSelectCompressionMethod; const StripNum_: Integer; const sour: TMS64; const dest: TCore_Stream); overload;
procedure ParallelCompressMemory(const scm: TSelectCompressionMethod; const sour: TMS64; const dest: TCore_Stream); overload;
procedure ParallelCompressMemory(const sour: TMS64; const dest: TCore_Stream); overload;

{ * ParallelDecompressStream: Decompresses a stream that was created with ParallelCompressMemory. }
procedure ParallelDecompressStream(const ThNum: Integer; const sour_, dest_: TCore_Stream); overload;
procedure ParallelDecompressStream(const sour_, dest_: TCore_Stream); overload;

{ * File‑based parallel compress/decompress. }
procedure ParallelCompressFile(const sour, dest: SystemString);
procedure ParallelDecompressFile(const sour, dest: SystemString);

{ *
  * CompressUTF8 / DecompressUTF8: Utility to compress a TBytes using ZLIB
  * max, with a header (0xFF,0xFF, original size) if compression is beneficial.
  * If compression does not reduce size, the original is returned.
}
function CompressUTF8(const sour_: TBytes): TBytes;
function DecompressUTF8(const sour_: TBytes): TBytes;

{ ****** Stream serialisation helpers (work on any TCore_Stream) ********** }
procedure StreamWriteBool(const stream: TCore_Stream; const buff: Boolean);
procedure StreamWriteInt8(const stream: TCore_Stream; const buff: ShortInt);
procedure StreamWriteInt16(const stream: TCore_Stream; const buff: SmallInt);
procedure StreamWriteInt32(const stream: TCore_Stream; const buff: Integer);
procedure StreamWriteInt64(const stream: TCore_Stream; const buff: Int64);
procedure StreamWriteInt128(const stream: TCore_Stream; const buff: Int128);
procedure StreamWriteUInt8(const stream: TCore_Stream; const buff: Byte);
procedure StreamWriteUInt16(const stream: TCore_Stream; const buff: Word);
procedure StreamWriteUInt32(const stream: TCore_Stream; const buff: Cardinal);
procedure StreamWriteUInt64(const stream: TCore_Stream; const buff: UInt64);
procedure StreamWriteUInt128(const stream: TCore_Stream; const buff: UInt128);
procedure StreamWriteSingle(const stream: TCore_Stream; const buff: Single);
procedure StreamWriteDouble(const stream: TCore_Stream; const buff: Double);
procedure StreamWriteCurrency(const stream: TCore_Stream; const buff: Currency);
procedure StreamWriteString(const stream: TCore_Stream; const buff: TPascalString);
function ComputeStreamWriteStringSize(buff: TPascalString): Integer;
procedure StreamWriteMD5(const stream: TCore_Stream; const buff: TMD5);

function StreamReadBool(const stream: TCore_Stream): Boolean;
function StreamReadInt8(const stream: TCore_Stream): ShortInt;
function StreamReadInt16(const stream: TCore_Stream): SmallInt;
function StreamReadInt32(const stream: TCore_Stream): Integer;
function StreamReadInt64(const stream: TCore_Stream): Int64;
function StreamReadInt128(const stream: TCore_Stream): Int128;
function StreamReadUInt8(const stream: TCore_Stream): Byte;
function StreamReadUInt16(const stream: TCore_Stream): Word;
function StreamReadUInt32(const stream: TCore_Stream): Cardinal;
function StreamReadUInt64(const stream: TCore_Stream): UInt64;
function StreamReadUInt128(const stream: TCore_Stream): UInt128;
function StreamReadSingle(const stream: TCore_Stream): Single;
function StreamReadDouble(const stream: TCore_Stream): Double;
function StreamReadCurrency(const stream: TCore_Stream): Currency;
function StreamReadString(const stream: TCore_Stream): TPascalString;
function StreamReadStringAsBuff(const stream: TCore_Stream): TBytes;
procedure StreamIgnoreReadString(const stream: TCore_Stream);
function StreamReadMD5(const stream: TCore_Stream): TMD5;

{ * DoStatus overloads for debugging: print stream content as hex bytes. }
procedure DoStatus(const v: TMS64); overload;
procedure DoStatus(const v: TMem64); overload;

implementation

uses Z.Status, Z.Compress, Z.Instance.Tool, Z.LZ4_Pas, Z.Snappy_Pas, Z.MD5;

{ * TMS64 implementation }

procedure TMS64.SetPointer(buffPtr: Pointer; const BuffSize: NativeUInt);
{ *
  * Assigns the internal buffer pointer and size without affecting capacity.
  * Used internally by Mapping and when taking over external buffers.
}
begin
  FMemory := buffPtr;
  FSize := BuffSize;
end;

procedure TMS64.SetCapacity(NewCapacity: NativeUInt);
{ *
  * Reallocates the buffer to NewCapacity bytes. If in protected mode, does nothing.
  * The actual allocation is performed by Realloc, which may round up the size.
}
begin
  if FProtectedMode then
      Exit;
  SetPointer(Realloc(NewCapacity), FSize);
  FCapacity := NewCapacity;
end;

function TMS64.Realloc(var NewCapacity: NativeUInt): Pointer;
{ *
  * Low‑level memory allocation.
  * If NewCapacity is > 0 and not equal to current size, it is rounded up to
  * a multiple of FDelta (via DeltaStep). Then:
  *   - If NewCapacity = 0, frees the current buffer and returns nil.
  *   - If current Capacity = 0, gets new memory; else reallocates.
  * Raises an exception on failure.
  * Returns the new pointer (may be nil if NewCapacity = 0).
}
begin
  if FProtectedMode then
      Exit(nil);
  if (NewCapacity > 0) and (NewCapacity <> FSize) then
      NewCapacity := DeltaStep(NewCapacity, FDelta);
  Result := Memory;
  if NewCapacity <> FCapacity then
    begin
      if NewCapacity = 0 then
        begin
          System.FreeMemory(Memory);
          Result := nil;
        end
      else
        begin
          if Capacity = 0 then
              Result := System.GetMemory(NewCapacity)
          else
              Result := System.ReallocMemory(Result, NewCapacity);
          if Result = nil then
              RaiseInfo('%d Out of memory while expanding memory stream', [NewCapacity]);
        end;
    end;
end;

procedure TMS64.SetDelta(const Value: NativeInt);
{ * Clamps the delta between 64 and 1MB (1024*1024). }
begin
  FDelta := Clamp(Value, 64, 1024 * 1024);
end;

constructor TMS64.Create;
{ * Creates with default delta = 256. }
begin
  CustomCreate(256);
end;

constructor TMS64.CustomCreate(const customDelta: NativeInt);
{ * Creates with specified delta. Initialises all fields to zero/nil. }
begin
  inherited Create;
  Delta := customDelta;
  FMemory := nil;
  FSize := 0;
  FPosition := 0;
  FCapacity := 0;
  FProtectedMode := False;
  FMem64 := nil;
end;

destructor TMS64.Destroy;
{ * Frees the cached TMem64 (if any) and clears the buffer. }
begin
  if FMem64 <> nil then
      DisposeObject(FMem64);
  Clear;
  inherited Destroy;
end;

function TMS64.Mem64(Mapping_Begin_As_Position_: Boolean): TMem64;
{ *
  * Returns a TMem64 that maps to this stream.
  * If Mapping_Begin_As_Position_ = True, the mapping starts at current position
  * and covers the remaining data; otherwise the entire stream.
  * The TMem64 is cached and reused on subsequent calls.
}
begin
  if FMem64 = nil then
      FMem64 := TMem64.Create;
  if Mapping_Begin_As_Position_ then
      FMem64.Mapping(PosAsPtr, Size - Position)
  else
      FMem64.Mapping(self);
  Result := FMem64;
end;

function TMS64.Mem64: TMem64;
{ * Maps the entire stream (calls Mem64(False)). }
begin
  Result := Mem64(False);
end;

function TMS64.NewClone: TMS64;
{ * Creates a deep copy: allocates new buffer and copies all bytes. }
begin
  Result := TMS64.CustomCreate(FDelta);
  Result.Size := Size;
  CopyPtr(Memory, Result.Memory, Size);
  Result.Position := Position;
end;

function TMS64.Create_Mapping_Instance: TMS64;
{ * Returns a new TMS64 that shares the same buffer (zero‑copy, read‑only). }
begin
  Result := TMS64.Create;
  Result.Mapping(self);
end;

function TMS64.Create_Mapping_Instance_Mem64: TMem64;
{ * Same but returns a TMem64. }
begin
  Result := TMem64.Create;
  Result.Mapping(self);
end;

function TMS64.Swap_To_New_Instance: TMS64;
{ * Creates a new empty TMS64 and swaps data with this one. }
begin
  Result := TMS64.Create;
  SwapInstance(Result);
end;

procedure TMS64.DiscardMemory;
{ * Releases the internal pointer without freeing memory. }
begin
  if FProtectedMode then
      Exit;
  FMemory := nil;
  FSize := 0;
  FPosition := 0;
  FCapacity := 0;
end;

procedure TMS64.Clear;
{ * Frees the buffer and resets size/position. No‑op if protected. }
begin
  if FProtectedMode then
      Exit;
  SetCapacity(0);
  FSize := 0;
  FPosition := 0;
end;

procedure TMS64.NewParam(source: TMS64);
{ * Copies the entire state from another TMS64, after clearing this one. }
begin
  Clear;
  FDelta := source.FDelta;
  FMemory := source.FMemory;
  FSize := source.FSize;
  FPosition := source.FPosition;
  FCapacity := source.FCapacity;
  FProtectedMode := source.FProtectedMode;
end;

procedure TMS64.NewParam(source: TMem64);
{ * Same, but from TMem64. }
begin
  Clear;
  FDelta := source.FDelta;
  FMemory := source.FMemory;
  FSize := source.FSize;
  FPosition := source.FPosition;
  FCapacity := source.FCapacity;
  FProtectedMode := source.FProtectedMode;
end;

procedure TMS64.SwapInstance(source: TMS64);
{ * Swaps all internal fields with another TMS64 in O(1). }
var
  FDelta_: NativeInt;
  FMemory_: Pointer;
  FSize_: NativeUInt;
  FPosition_: NativeUInt;
  FCapacity_: NativeUInt;
  FProtectedMode_: Boolean;
begin
  FDelta_ := FDelta;
  FMemory_ := FMemory;
  FSize_ := FSize;
  FPosition_ := FPosition;
  FCapacity_ := FCapacity;
  FProtectedMode_ := FProtectedMode;

  FDelta := source.FDelta;
  FMemory := source.FMemory;
  FSize := source.FSize;
  FPosition := source.FPosition;
  FCapacity := source.FCapacity;
  FProtectedMode := source.FProtectedMode;

  source.FDelta := FDelta_;
  source.FMemory := FMemory_;
  source.FSize := FSize_;
  source.FPosition := FPosition_;
  source.FCapacity := FCapacity_;
  source.FProtectedMode := FProtectedMode_;
end;

procedure TMS64.SwapInstance(source: TMem64);
{ * Swaps with a TMem64 (fields are compatible). }
var
  FDelta_: NativeInt;
  FMemory_: Pointer;
  FSize_: NativeUInt;
  FPosition_: NativeUInt;
  FCapacity_: NativeUInt;
  FProtectedMode_: Boolean;
begin
  FDelta_ := FDelta;
  FMemory_ := FMemory;
  FSize_ := FSize;
  FPosition_ := FPosition;
  FCapacity_ := FCapacity;
  FProtectedMode_ := FProtectedMode;

  FDelta := source.FDelta;
  FMemory := source.FMemory;
  FSize := source.FSize;
  FPosition := source.FPosition;
  FCapacity := source.FCapacity;
  FProtectedMode := source.FProtectedMode;

  source.FDelta := FDelta_;
  source.FMemory := FMemory_;
  source.FSize := FSize_;
  source.FPosition := FPosition_;
  source.FCapacity := FCapacity_;
  source.FProtectedMode := FProtectedMode_;
end;

function TMS64.ToBytes: TBytes;
{ * Copies all data into a new TBytes array. }
begin
  SetLength(Result, Size);
  if Size > 0 then
      CopyPtr(Memory, @Result[0], Size);
end;

function TMS64.ToMD5: TMD5;
{ * Computes MD5 over the entire buffer. }
begin
  Result := FastMD5(Memory, Size);
end;

function TMS64.Same(source: TMem64): Boolean;
{ * Compares size and content with a TMem64. }
begin
  Result := (Size = source.Size) and CompareMemory(Memory, source.Memory, Size);
end;

function TMS64.LZ4: TMS64;
{ *
  * Compresses using LZ4.
  * Output format: [OriginalSize: Int64][CompressedSize: Int64][CompressedData].
  * The new stream is allocated with enough space for the worst‑case compressed size.
}
var
  comp_size: Int64;
begin
  Result := TMS64.Create;
  Result.Size := LZ4_compressBound64(Size) + 16; // worst‑case + header
  PInt64(Result.PosAsPtr(0))^ := Size; // store original size
  comp_size := LZ4_compress_default64(Memory^, Size, Result.PosAsPtr(16)^, LZ4_compressBound64(Size));
  PInt64(Result.PosAsPtr(8))^ := comp_size; // store actual compressed size
  Result.Size := comp_size + 16; // trim to actual size
end;

function TMS64.UnLZ4: TMS64;
{ * Decompresses LZ4 data (format from LZ4 method). }
var
  comp_size: Int64;
begin
  Result := TMS64.Create;
  Result.Size := PInt64(PosAsPtr(0))^; // original size
  comp_size := PInt64(PosAsPtr(8))^; // compressed size
  LZ4_decompress_safe64(PosAsPtr(16)^, comp_size, Result.Memory^, Result.Size);
end;

function TMS64.Snappy_Pas: TMS64;
{ * Compresses using Snappy (pure Pascal). Same header format as LZ4. }
var
  comp_size: Int64;
begin
  Result := TMS64.Create;
  Result.Size := SnappyMaxCompressedLength64(Size) + 16;
  PInt64(Result.PosAsPtr(0))^ := Size;
  comp_size := Result.Size;
  SnappyCompress(Memory, Size, Result.PosAsPtr(16), comp_size);
  PInt64(Result.PosAsPtr(8))^ := comp_size;
  Result.Size := comp_size + 16;
end;

function TMS64.UnSnappy_Pas: TMS64;
{ * Decompresses Snappy data. }
var
  OutputSize: Int64;
  comp_size: Int64;
begin
  Result := TMS64.Create;
  Result.Size := PInt64(PosAsPtr(0))^;
  OutputSize := Result.Size;
  comp_size := PInt64(PosAsPtr(8))^;
  SnappyDecompress(PosAsPtr(16), comp_size, Result.Memory, OutputSize);
end;

procedure TMS64.SetPointerWithProtectedMode(buffPtr: Pointer; const BuffSize: Int64);
{ * Convenience: calls Mapping. }
begin
  Mapping(buffPtr, BuffSize);
end;

procedure TMS64.Mapping(buffPtr: Pointer; const BuffSize: Int64);
{ *
  * Makes the stream point to an external buffer and enters protected mode.
  * The stream will not own the memory; any write attempt will fail.
}
begin
  Clear;
  FMemory := buffPtr;
  FSize := BuffSize;
  FPosition := 0;
  FProtectedMode := True;
end;

procedure TMS64.Mapping(m64: TMS64);
{ * Maps to another TMS64's buffer. }
begin
  Mapping(m64.Memory, m64.Size);
end;

procedure TMS64.Mapping(m64: TMem64);
{ * Maps to a TMem64's buffer. }
begin
  Mapping(m64.Memory, m64.Size);
end;

function TMS64.PositionAsPtr(const Position_: Int64): Pointer;
{ * Returns a pointer to the byte at the specified absolute position. }
begin
  Result := GetOffset(FMemory, Position_);
end;

function TMS64.PositionAsPtr: Pointer;
{ * Returns a pointer to the current position. }
begin
  Result := GetOffset(FMemory, FPosition);
end;

function TMS64.PosAsPtr(const Position_: Int64): Pointer;
begin
  Result := PositionAsPtr(Position_);
end;

function TMS64.PosAsPtr: Pointer;
begin
  Result := PositionAsPtr();
end;

procedure TMS64.LoadFromStream(stream: TCore_Stream);
{ * Replaces the stream content with the entire content of another stream. }
begin
  if FProtectedMode then
      Exit;
  Clear;
  stream.Position := 0;
  if CopyFrom(stream, stream.Size) <> stream.Size then
      RaiseInfo('load stream error.');
  Position := 0;
end;

procedure TMS64.LoadFromFile(FileName: SystemString);
{ * Loads binary data from a file. }
var
  stream: TCore_Stream;
begin
  stream := TCore_FileStream.Create(FileName, fmOpenRead or fmShareDenyNone);
  try
      LoadFromStream(stream);
  finally
      DisposeObject(stream);
  end;
end;

procedure TMS64.SaveToStream(stream: TCore_Stream);
{ *
  * Writes the stream's data to another stream.
  * If the destination is a TMS64, it uses zero‑copy (direct pointer copy).
  * Otherwise, writes in 64MB chunks to avoid large allocations.
}
const
  ChunkSize = 64 * 1024 * 1024;
var
  p: Pointer;
  j: NativeInt;
  Num: NativeInt;
  Rest: NativeInt;
begin
  if stream is TMS64 then
    begin
      TMS64(stream).Clear;
      if Size > 0 then
          TMS64(stream).WritePtr(Memory, Size);
      TMS64(stream).Position := 0;
      Exit;
    end;

  if Size > 0 then
    begin
      p := FMemory;
      if Size > ChunkSize then
        begin
          Num := Size div ChunkSize;
          Rest := Size mod ChunkSize;
          for j := 0 to Num - 1 do
            begin
              stream.WriteBuffer(p^, ChunkSize);
              p := GetOffset(p, ChunkSize);
            end;
          if Rest > 0 then
            begin
              stream.WriteBuffer(p^, Rest);
              p := GetOffset(p, Rest);
            end;
        end
      else
          stream.WriteBuffer(p^, Size);
    end;
end;

procedure TMS64.SaveToFile(FileName: SystemString);
{ * Saves data to a binary file. }
var
  stream: TCore_Stream;
begin
  stream := TCore_FileStream.Create(FileName, fmCreate);
  try
      SaveToStream(stream);
  finally
      DisposeObject(stream);
  end;
end;

procedure TMS64.SetSize(const NewSize: Int64);
{ *
  * Changes the stream's size. If increasing, the buffer is expanded.
  * If the current position exceeds the new size, it is moved to the end.
}
var
  OldPosition: Int64;
begin
  if FProtectedMode then
      Exit;
  OldPosition := FPosition;
  SetCapacity(NewSize);
  FSize := NewSize;
  if OldPosition > NewSize then
      Seek(0, TSeekOrigin.soEnd);
end;

procedure TMS64.SetSize(NewSize: longint);
begin
  SetSize(Int64(NewSize));
end;

function TMS64.Write64(const buffer; Count: Int64): Int64;
{ *
  * Writes Count bytes from buffer at the current position.
  * Expands the stream if needed. Returns Count on success, 0 if protected mode
  * or invalid parameters.
}
var
  p: Int64;
begin
  if (Count > 0) then
    begin
      p := FPosition;
      p := p + Count;
      if p > 0 then
        begin
          if p > FSize then
            begin
              if FProtectedMode then
                begin
                  Result := 0;
                  Exit;
                end;
              if p > FCapacity then
                  SetCapacity(p);
              FSize := p;
            end;
          CopyPtr(@buffer, GetOffset(FMemory, FPosition), Count);
          FPosition := p;
          Result := Count;
          Exit;
        end;
    end;
  Result := 0;
end;

function TMS64.WritePtr(const p: Pointer; Count: Int64): Int64;
{ * Writes from a pointer. }
begin
  Result := Write64(p^, Count);
end;

function TMS64.write(const buffer; Count: longint): longint;
{ * 32‑bit override of TStream.Write. }
begin
  Result := Write64(buffer, Count);
end;

procedure TMS64.WriteBytes(const buff: TBytes);
{ * Writes a dynamic byte array. }
begin
  if Length(buff) > 0 then
      WritePtr(@buff[0], Length(buff));
end;

function TMS64.Read64(var buffer; Count: Int64): Int64;
{ *
  * Reads up to Count bytes into buffer at current position.
  * Returns the actual number of bytes read (may be less if EOF).
}
begin
  if Count > 0 then
    begin
      Result := FSize - FPosition;
      if Result > 0 then
        begin
          if Result > Count then
              Result := Count;
          CopyPtr(GetOffset(FMemory, FPosition), @buffer, Result);
          inc(FPosition, Result);
          Exit;
        end;
    end;
  Result := 0;
end;

function TMS64.ReadPtr(const p: Pointer; Count: Int64): Int64;
{ * Reads into a pointer. }
begin
  Result := Read64(p^, Count);
end;

function TMS64.read(var buffer; Count: longint): longint;
{ * 32‑bit override. }
begin
  Result := Read64(buffer, Count);
end;

{$IFDEF DELPHI}


function TMS64.write(const buffer: TBytes; Offset, Count: longint): longint;
{ * Delphi's TStream.Write overload for TBytes with offset. }
var
  p: Int64;
begin
  if Count > 0 then
    begin
      p := FPosition;
      p := p + Count;
      if p > 0 then
        begin
          if p > FSize then
            begin
              if FProtectedMode then
                begin
                  Result := 0;
                  Exit;
                end;
              if p > FCapacity then
                  SetCapacity(p);
              FSize := p;
            end;
          CopyPtr(@buffer[Offset], GetOffset(FMemory, FPosition), Count);
          FPosition := p;
          Result := Count;
          Exit;
        end;
    end;
  Result := 0;
end;

function TMS64.read(buffer: TBytes; Offset, Count: longint): longint;
{ * Delphi's TStream.Read overload for TBytes with offset. }
var
  p: Int64;
begin
  if Count > 0 then
    begin
      p := FSize - FPosition;
      if p > 0 then
        begin
          if p > Count then
              p := Count;
          CopyPtr(GetOffset(FMemory, FPosition), @buffer[Offset], p);
          inc(FPosition, p);
          Result := p;
          Exit;
        end;
    end;
  Result := 0;
end;
{$ENDIF DELPHI}


function TMS64.Seek(const Offset: Int64; origin: TSeekOrigin): Int64;
{ * Changes the current position. Returns the new position. }
begin
  case origin of
    TSeekOrigin.soBeginning: FPosition := Offset;
    TSeekOrigin.soCurrent: inc(FPosition, Offset);
    TSeekOrigin.soEnd: FPosition := FSize + Offset;
  end;
  Result := FPosition;
end;

function TMS64.CopyMem64(const source: TMem64; Count: Int64): Int64;
{ * Copies from a TMem64's current position into this stream. }
begin
  if FProtectedMode then
      RaiseInfo('protected mode');
  WritePtr(source.PositionAsPtr, Count);
  source.Position := source.FPosition + Count;
  Result := Count;
end;

function TMS64.CopyFrom(const source: TCore_Stream; Count: Int64): Int64;
{ *
  * Copies Count bytes from source stream. If Count < 0, copies entire source.
  * Uses chunked reading to handle large data.
}
const
  MaxBufSize = $F000;
var
  BufSize, n, p: Int64;
begin
  if FProtectedMode then
      RaiseInfo('protected mode');
  if Count = 0 then
      Exit(0);
  if Count < 0 then
    begin
      source.Position := 0;
      Count := source.Size;
    end;

  if source is TMS64 then
    begin
      WritePtr(TMS64(source).PositionAsPtr, Count);
      TMS64(source).Position := TMS64(source).FPosition + Count;
      Result := Count;
      Exit;
    end;

  Result := Count;
  if Count > MaxBufSize then
      BufSize := MaxBufSize
  else
      BufSize := Count;

  p := Position;
  if p + Count > Size then
      Size := p + Count;

  while Count <> 0 do
    begin
      if Count > BufSize then
          n := BufSize
      else
          n := Count;
      if source.read(PosAsPtr(p)^, n) <> n then
          RaiseInfo('stream read error.');
      inc(p, n);
      dec(Count, n);
    end;
  Position := p;
end;

function TMS64.CopyFrom(const source: TMem64; Count: Int64): Int64;
{ * Copies from a TMem64. }
begin
  if FProtectedMode then
      RaiseInfo('protected mode');
  WritePtr(source.PositionAsPtr, Count);
  source.Position := source.FPosition + Count;
  Result := Count;
end;

{ ****** Typed write methods ********** }
procedure TMS64.WriteBool(const buff: Boolean);
begin
  WritePtr(@buff, 1);
end;

procedure TMS64.WriteInt8(const buff: ShortInt);
begin
  WritePtr(@buff, 1);
end;

procedure TMS64.WriteInt16(const buff: SmallInt);
begin
  WritePtr(@buff, 2);
end;

procedure TMS64.WriteInt32(const buff: Integer);
begin
  WritePtr(@buff, 4);
end;

procedure TMS64.WriteInt64(const buff: Int64);
begin
  WritePtr(@buff, 8);
end;

procedure TMS64.WriteInt128(const buff: Int128);
begin
  WritePtr(@buff.b[0], 16);
end;

procedure TMS64.WriteUInt8(const buff: Byte);
begin
  WritePtr(@buff, 1);
end;

procedure TMS64.WriteUInt16(const buff: Word);
begin
  WritePtr(@buff, 2);
end;

procedure TMS64.WriteUInt32(const buff: Cardinal);
begin
  WritePtr(@buff, 4);
end;

procedure TMS64.WriteUInt64(const buff: UInt64);
begin
  WritePtr(@buff, 8);
end;

procedure TMS64.WriteUInt128(const buff: UInt128);
begin
  WritePtr(@buff.b[0], 16);
end;

procedure TMS64.WriteSingle(const buff: Single);
begin
  WritePtr(@buff, 4);
end;

procedure TMS64.WriteDouble(const buff: Double);
begin
  WritePtr(@buff, 8);
end;

procedure TMS64.WriteCurrency(const buff: Currency);
begin
  WriteDouble(buff);
end;

procedure TMS64.WriteString(const buff: TPascalString);
{ *
  * Writes a TPascalString as UTF‑8 with a 4‑byte length prefix.
  * Example:
  *   ms.WriteString('Hello'); // writes length=5 then bytes.
}
var
  b: TBytes;
begin
  b := buff.Bytes;
  WriteUInt32(Length(b));
  if Length(b) > 0 then
    begin
      WritePtr(@b[0], Length(b));
      SetLength(b, 0);
    end;
end;

procedure TMS64.WriteANSI(const buff: TPascalString);
{ * Writes the ANSI bytes without length prefix. }
var
  b: TBytes;
begin
  b := buff.ANSI;
  if Length(b) > 0 then
    begin
      WritePtr(@b[0], Length(b));
      SetLength(b, 0);
    end;
end;

procedure TMS64.WriteANSI(const buff: TPascalString; const L: Integer);
{ * Writes exactly L ANSI bytes (truncates or pads if necessary). }
var
  b: TBytes;
begin
  b := buff.ANSI;
  if L > 0 then
    begin
      WritePtr(@b[0], L);
      SetLength(b, 0);
    end;
end;

procedure TMS64.WriteString(const buff: TUPascalString);
{ *
  * Writes a TUPascalString as UTF‑8 with a 4‑byte length prefix.
  * Example:
  *   ms.WriteString('Hello'); // writes length=5 then bytes.
}
var
  b: TBytes;
begin
  b := buff.Bytes;
  WriteUInt32(Length(b));
  if Length(b) > 0 then
    begin
      WritePtr(@b[0], Length(b));
      SetLength(b, 0);
    end;
end;

procedure TMS64.WriteANSI(const buff: TUPascalString);
{ * Writes the ANSI bytes without length prefix. }
var
  b: TBytes;
begin
  b := buff.ANSI;
  if Length(b) > 0 then
    begin
      WritePtr(@b[0], Length(b));
      SetLength(b, 0);
    end;
end;

procedure TMS64.WriteANSI(const buff: TUPascalString; const L: Integer);
{ * Writes exactly L ANSI bytes (truncates or pads if necessary). }
var
  b: TBytes;
begin
  b := buff.ANSI;
  if L > 0 then
    begin
      WritePtr(@b[0], L);
      SetLength(b, 0);
    end;
end;

procedure TMS64.WriteMD5(const buff: TMD5);
begin
  WritePtr(@buff, 16);
end;

{ ****** Typed read methods ********** }
function TMS64.ReadBool: Boolean;
begin
  ReadPtr(@Result, 1);
end;

function TMS64.ReadInt8: ShortInt;
begin
  ReadPtr(@Result, 1);
end;

function TMS64.ReadInt16: SmallInt;
begin
  ReadPtr(@Result, 2);
end;

function TMS64.ReadInt32: Integer;
begin
  ReadPtr(@Result, 4);
end;

function TMS64.ReadInt64: Int64;
begin
  ReadPtr(@Result, 8);
end;

function TMS64.ReadInt128: Int128;
begin
  ReadPtr(@Result.b[0], 16);
end;

function TMS64.ReadUInt8: Byte;
begin
  ReadPtr(@Result, 1);
end;

function TMS64.ReadUInt16: Word;
begin
  ReadPtr(@Result, 2);
end;

function TMS64.ReadUInt32: Cardinal;
begin
  ReadPtr(@Result, 4);
end;

function TMS64.ReadUInt64: UInt64;
begin
  ReadPtr(@Result, 8);
end;

function TMS64.ReadUInt128: UInt128;
begin
  ReadPtr(@Result.b[0], 16);
end;

function TMS64.ReadSingle: Single;
begin
  ReadPtr(@Result, 4);
end;

function TMS64.ReadDouble: Double;
begin
  ReadPtr(@Result, 8);
end;

function TMS64.ReadCurrency: Currency;
begin
  Result := ReadDouble();
end;

function TMS64.PrepareReadString: Boolean;
{ *
  * Checks if there is enough data to read a string: at least 4 bytes for
  * the length and then the full string.
}
begin
  Result := (Position + 4 <= Size) and (Position + 4 + PCardinal(PositionAsPtr())^ <= Size);
end;

function TMS64.ReadString: TPascalString;
{ *
  * Reads a string written with WriteString: reads length, then UTF‑8 bytes,
  * and returns the decoded TPascalString.
  * Returns empty string on error.
}
var
  L: Cardinal;
  b: TBytes;
begin
  try
    L := ReadUInt32;
    L := Min(L, Max(Size - Position, 0));
    if L > 0 then
      begin
        SetLength(b, L);
        ReadPtr(@b[0], L);
        Result.Bytes := b;
        SetLength(b, 0);
      end;
  except
      Result := '';
  end;
end;

function TMS64.ReadStringAsBuff: TBytes;
{ * Reads the string but returns raw UTF‑8 bytes. }
var
  L: Cardinal;
begin
  try
    L := ReadUInt32;
    L := Min(L, Max(Size - Position, 0));
    if L > 0 then
      begin
        SetLength(Result, L);
        ReadPtr(@Result[0], L);
      end
    else
        SetLength(Result, 0);
  except
      SetLength(Result, 0);
  end;
end;

procedure TMS64.IgnoreReadString;
{ * Skips over a string without reading its data. }
var
  L: Cardinal;
begin
  try
    L := ReadUInt32;
    L := Min(L, Max(Size - Position, 0));
    if L > 0 then
        Position := Position + L;
  except
  end;
end;

function TMS64.ReadANSI(L: Integer): TPascalString;
{ * Reads L bytes as ANSI and returns a TPascalString. }
var
  b: TBytes;
begin
  if L > 0 then
    begin
      SetLength(b, L);
      ReadPtr(@b[0], L);
      Result.ANSI := b;
      SetLength(b, 0);
    end;
end;

function TMS64.ReadMD5: TMD5;
begin
  ReadPtr(@Result, 16);
end;

{ * TMemoryStream64List implementation }

procedure TMemoryStream64List.Clean;
{ * Frees all streams in the list and clears it. }
var
  i: Integer;
begin
  for i := 0 to Count - 1 do
      DisposeObject(Items[i]);
  Clear;
end;

function TMemoryStream64List.To_Array: TMS64_Array;
{ * Copies the list contents to a dynamic array. }
var
  i: Integer;
begin
  SetLength(Result, Count);
  for i := 0 to Count - 1 do
      Result[i] := Items[i];
end;

{ * TMemoryStream64ThreadList implementation }

constructor TMemoryStream64ThreadList.Create;
{ * Initialises the critical section. }
begin
  inherited Create;
  FCritical := TCritical.Create('TMemoryStream64ThreadList.FCritical');
  AutoFree_Stream := False;
end;

destructor TMemoryStream64ThreadList.Destroy;
{ * Frees the critical section and clears the list. }
begin
  DisposeObject(FCritical);
  Clear;
  inherited Destroy;
end;

procedure TMemoryStream64ThreadList.Lock;
begin
  FCritical.Lock;
end;

procedure TMemoryStream64ThreadList.UnLock;
begin
  FCritical.UnLock;
end;

procedure TMemoryStream64ThreadList.Remove(obj: TMS64);
{ * Removes an object; if AutoFree_Stream, frees it. }
begin
  if AutoFree_Stream then
      DisposeObject(obj);
  inherited Remove(obj);
end;

procedure TMemoryStream64ThreadList.Delete(index: Integer);
{ * Deletes at index, optionally freeing the object. }
begin
  if (index >= 0) and (index < Count) then
    begin
      if AutoFree_Stream then
          DisposeObject(Items[index]);
      inherited Delete(index);
    end;
end;

procedure TMemoryStream64ThreadList.Clear;
{ * Clears the list, freeing all streams if AutoFree_Stream is True. }
var
  i: Integer;
begin
  if AutoFree_Stream then
    for i := 0 to Count - 1 do
        DisposeObject(Items[i]);
  inherited Clear;
end;

procedure TMemoryStream64ThreadList.Clean;
{ * Frees all streams regardless of AutoFree_Stream and clears. }
var
  i: Integer;
begin
  for i := 0 to Count - 1 do
      DisposeObject(Items[i]);
  inherited Clear;
end;

function TMemoryStream64ThreadList.To_Array: TMS64_Array;
{ * Returns a dynamic array of contained streams. }
var
  i: Integer;
begin
  SetLength(Result, Count);
  for i := 0 to Count - 1 do
      Result[i] := Items[i];
end;

{ * Trigger‑based streams }

constructor TMemoryStream64OfWriteTrigger.Create(ATrigger: IMemoryStream64WriteTrigger);
begin
  inherited Create;
  Trigger := ATrigger;
end;

function TMemoryStream64OfWriteTrigger.Write64(const buffer; Count: Int64): Int64;
{ * Overrides Write64 to call the trigger after writing. }
begin
  Result := inherited Write64(buffer, Count);
  if Assigned(Trigger) then
      Trigger.TriggerWrite64(Count);
end;

constructor TMemoryStream64OfReadTrigger.Create(ATrigger: IMemoryStream64ReadTrigger);
begin
  inherited Create;
  Trigger := ATrigger;
end;

function TMemoryStream64OfReadTrigger.Read64(var buffer; Count: Int64): Int64;
begin
  Result := inherited Read64(buffer, Count);
  if Assigned(Trigger) then
      Trigger.TriggerRead64(Count);
end;

constructor TMemoryStream64OfReadWriteTrigger.Create(ATrigger: IMemoryStream64ReadWriteTrigger);
begin
  inherited Create;
  Trigger := ATrigger;
end;

function TMemoryStream64OfReadWriteTrigger.Read64(var buffer; Count: Int64): Int64;
begin
  Result := inherited Read64(buffer, Count);
  if Assigned(Trigger) then
      Trigger.TriggerRead64(Count);
end;

function TMemoryStream64OfReadWriteTrigger.Write64(const buffer; Count: Int64): Int64;
begin
  Result := inherited Write64(buffer, Count);
  if Assigned(Trigger) then
      Trigger.TriggerWrite64(Count);
end;

{ * TMem64 implementation }

procedure TMem64.SetPointer(buffPtr: Pointer; const BuffSize: Int64);
begin
  FMemory := buffPtr;
  FSize := BuffSize;
end;

procedure TMem64.SetCapacity(NewCapacity: Int64);
begin
  if FProtectedMode then
      Exit;
  SetPointer(Realloc(NewCapacity), FSize);
  FCapacity := NewCapacity;
end;

function TMem64.Realloc(var NewCapacity: Int64): Pointer;
{ * Same as TMS64.Realloc but works with Int64 sizes. }
begin
  if FProtectedMode then
      Exit(nil);
  if (NewCapacity > 0) and (NewCapacity <> FSize) then
      NewCapacity := DeltaStep(NewCapacity, FDelta);
  Result := Memory;
  if NewCapacity <> FCapacity then
    begin
      if NewCapacity = 0 then
        begin
          System.FreeMemory(Memory);
          Result := nil;
        end
      else
        begin
          if Capacity = 0 then
              Result := System.GetMemory(NewCapacity)
          else
              Result := System.ReallocMemory(Result, NewCapacity);
          if Result = nil then
              RaiseInfo('%d Out of memory while expanding memory stream', [NewCapacity]);
        end;
    end;
end;

function TMem64.GetDelta: NativeInt;
begin
  Result := FDelta;
end;

procedure TMem64.SetDelta(const Value: NativeInt);
begin
  FDelta := Clamp(Value, 64, 1024 * 1024);
end;

function TMem64.GetMemory_: Pointer;
begin
  Result := FMemory;
end;

function TMem64.GetPosition: Int64;
begin
  Result := Seek(0, TSeekOrigin.soCurrent);
end;

procedure TMem64.SetPosition(const Value: Int64);
begin
  Seek(Value, TSeekOrigin.soBeginning);
end;

function TMem64.GetSize: Int64;
{ * Computes size by seeking to end and back. }
var
  Pos_: Int64;
begin
  Pos_ := Seek(0, TSeekOrigin.soCurrent);
  Result := Seek(0, TSeekOrigin.soEnd);
  Seek(Pos_, TSeekOrigin.soBeginning);
end;

procedure TMem64.SetSize(const NewSize: Int64);
{ * Sets the size, expanding if needed and adjusting position. }
var
  OldPosition: Int64;
begin
  if FProtectedMode then
      Exit;
  OldPosition := FPosition;
  SetCapacity(NewSize);
  FSize := NewSize;
  if OldPosition > NewSize then
      Seek(0, TSeekOrigin.soEnd);
end;

constructor TMem64.Create;
begin
  CustomCreate(256);
end;

constructor TMem64.CustomCreate(const customDelta: NativeInt);
begin
  inherited Create;
  Delta := customDelta;
  FMemory := nil;
  FSize := 0;
  FPosition := 0;
  FCapacity := 0;
  FProtectedMode := False;
  FStream64 := nil;
end;

destructor TMem64.Destroy;
begin
  if FStream64 <> nil then
      DisposeObject(FStream64);
  Clear;
  inherited Destroy;
end;

function TMem64.Stream64(Mapping_Begin_As_Position_: Boolean): TMS64;
{ * Returns a TMS64 that maps to this buffer. }
begin
  if FStream64 = nil then
      FStream64 := TMS64.Create;
  if Mapping_Begin_As_Position_ then
      FStream64.Mapping(PosAsPtr, Size - Position)
  else
      FStream64.Mapping(self);
  Result := FStream64;
end;

function TMem64.Stream64: TMS64;
begin
  Result := Stream64(False);
end;

function TMem64.NewClone: TMem64;
{ * Deep copy. }
begin
  Result := TMem64.CustomCreate(FDelta);
  Result.Size := Size;
  CopyPtr(Memory, Result.Memory, Size);
  Result.Position := Position;
end;

function TMem64.Create_Mapping_Instance: TMem64;
begin
  Result := TMem64.Create;
  Result.Mapping(self);
end;

function TMem64.Create_Mapping_Instance_MS64: TMS64;
begin
  Result := TMS64.Create;
  Result.Mapping(self);
end;

function TMem64.Swap_To_New_Instance: TMem64;
begin
  Result := TMem64.Create;
  SwapInstance(Result);
end;

procedure TMem64.DiscardMemory;
begin
  if FProtectedMode then Exit;
  FMemory := nil;
  FSize := 0;
  FPosition := 0;
  FCapacity := 0;
end;

procedure TMem64.Clear;
begin
  if FProtectedMode then Exit;
  SetCapacity(0);
  FSize := 0;
  FPosition := 0;
end;

procedure TMem64.NewParam(source: TMS64);
begin
  Clear;
  FDelta := source.FDelta;
  FMemory := source.FMemory;
  FSize := source.FSize;
  FPosition := source.FPosition;
  FCapacity := source.FCapacity;
  FProtectedMode := source.FProtectedMode;
end;

procedure TMem64.NewParam(source: TMem64);
begin
  Clear;
  FDelta := source.FDelta;
  FMemory := source.FMemory;
  FSize := source.FSize;
  FPosition := source.FPosition;
  FCapacity := source.FCapacity;
  FProtectedMode := source.FProtectedMode;
end;

procedure TMem64.SwapInstance(source: TMS64);
var
  FDelta_: NativeInt;
  FMemory_: Pointer;
  FSize_: Int64;
  FPosition_: Int64;
  FCapacity_: Int64;
  FProtectedMode_: Boolean;
begin
  FDelta_ := FDelta;
  FMemory_ := FMemory;
  FSize_ := FSize;
  FPosition_ := FPosition;
  FCapacity_ := FCapacity;
  FProtectedMode_ := FProtectedMode;

  FDelta := source.FDelta;
  FMemory := source.FMemory;
  FSize := source.FSize;
  FPosition := source.FPosition;
  FCapacity := source.FCapacity;
  FProtectedMode := source.FProtectedMode;

  source.FDelta := FDelta_;
  source.FMemory := FMemory_;
  source.FSize := FSize_;
  source.FPosition := FPosition_;
  source.FCapacity := FCapacity_;
  source.FProtectedMode := FProtectedMode_;
end;

procedure TMem64.SwapInstance(source: TMem64);
var
  FDelta_: NativeInt;
  FMemory_: Pointer;
  FSize_: Int64;
  FPosition_: Int64;
  FCapacity_: Int64;
  FProtectedMode_: Boolean;
begin
  FDelta_ := FDelta;
  FMemory_ := FMemory;
  FSize_ := FSize;
  FPosition_ := FPosition;
  FCapacity_ := FCapacity;
  FProtectedMode_ := FProtectedMode;

  FDelta := source.FDelta;
  FMemory := source.FMemory;
  FSize := source.FSize;
  FPosition := source.FPosition;
  FCapacity := source.FCapacity;
  FProtectedMode := source.FProtectedMode;

  source.FDelta := FDelta_;
  source.FMemory := FMemory_;
  source.FSize := FSize_;
  source.FPosition := FPosition_;
  source.FCapacity := FCapacity_;
  source.FProtectedMode := FProtectedMode_;
end;

function TMem64.ToBytes: TBytes;
begin
  SetLength(Result, Size);
  if Size > 0 then
      CopyPtr(Memory, @Result[0], Size);
end;

function TMem64.ToMD5: TMD5;
begin
  Result := FastMD5(Memory, Size);
end;

function TMem64.Same(source: TMem64): Boolean;
begin
  Result := (Size = source.Size) and CompareMemory(Memory, source.Memory, Size);
end;

function TMem64.LZ4: TMem64;
var
  comp_size: Int64;
begin
  Result := TMem64.Create;
  Result.Size := LZ4_compressBound64(Size) + 16;
  PInt64(Result.PosAsPtr(0))^ := Size;
  comp_size := LZ4_compress_default64(Memory^, Size, Result.PosAsPtr(16)^, LZ4_compressBound64(Size));
  PInt64(Result.PosAsPtr(8))^ := comp_size;
  Result.Size := comp_size + 16;
end;

function TMem64.UnLZ4: TMem64;
var
  comp_size: Int64;
begin
  Result := TMem64.Create;
  Result.Size := PInt64(PosAsPtr(0))^;
  comp_size := PInt64(PosAsPtr(8))^;
  LZ4_decompress_safe64(PosAsPtr(16)^, comp_size, Result.Memory^, Result.Size);
end;

function TMem64.Snappy_Pas: TMem64;
var
  comp_size: Int64;
begin
  Result := TMem64.Create;
  Result.Size := SnappyMaxCompressedLength64(Size) + 16;
  comp_size := Result.Size;
  PInt64(Result.PosAsPtr(0))^ := Size;
  SnappyCompress(Memory, Size, Result.PosAsPtr(16), comp_size);
  PInt64(Result.PosAsPtr(8))^ := comp_size;
  Result.Size := comp_size + 16;
end;

function TMem64.UnSnappy_Pas: TMem64;
var
  OutputSize: Int64;
  comp_size: Int64;
begin
  Result := TMem64.Create;
  Result.Size := PInt64(PosAsPtr(0))^;
  OutputSize := Result.Size;
  comp_size := PInt64(PosAsPtr(8))^;
  SnappyDecompress(PosAsPtr(16), comp_size, Result.Memory, OutputSize);
end;

procedure TMem64.SetPointerWithProtectedMode(buffPtr: Pointer; const BuffSize: Int64);
begin
  Mapping(buffPtr, BuffSize);
end;

procedure TMem64.Mapping(buffPtr: Pointer; const BuffSize: Int64);
begin
  Clear;
  FMemory := buffPtr;
  FSize := BuffSize;
  FPosition := 0;
  FProtectedMode := True;
end;

procedure TMem64.Mapping(m64: TMS64);
begin
  Mapping(m64.Memory, m64.Size);
end;

procedure TMem64.Mapping(m64: TMem64);
begin
  Mapping(m64.Memory, m64.Size);
end;

function TMem64.PositionAsPtr(const Position_: Int64): Pointer;
begin
  Result := GetOffset(FMemory, Position_);
end;

function TMem64.PositionAsPtr: Pointer;
begin
  Result := GetOffset(FMemory, FPosition);
end;

function TMem64.PosAsPtr(const Position_: Int64): Pointer;
begin
  Result := PositionAsPtr(Position_);
end;

function TMem64.PosAsPtr: Pointer;
begin
  Result := PositionAsPtr();
end;

procedure TMem64.LoadFromStream(stream: TCore_Stream);
begin
  if FProtectedMode then Exit;
  Clear;
  stream.Position := 0;
  if CopyFrom(stream, stream.Size) <> stream.Size then
      RaiseInfo('load stream error.');
  Position := 0;
end;

procedure TMem64.LoadFromFile(FileName: SystemString);
var
  stream: TCore_Stream;
begin
  stream := TCore_FileStream.Create(FileName, fmOpenRead or fmShareDenyNone);
  try
      LoadFromStream(stream);
  finally
      DisposeObject(stream);
  end;
end;

procedure TMem64.SaveToStream(stream: TCore_Stream);
const
  ChunkSize = 64 * 1024 * 1024;
var
  p: Pointer;
  j: NativeInt;
  Num: NativeInt;
  Rest: NativeInt;
begin
  if Size > 0 then
    begin
      p := FMemory;
      if Size > ChunkSize then
        begin
          Num := Size div ChunkSize;
          Rest := Size mod ChunkSize;
          for j := 0 to Num - 1 do
            begin
              stream.WriteBuffer(p^, ChunkSize);
              p := GetOffset(p, ChunkSize);
            end;
          if Rest > 0 then
            begin
              stream.WriteBuffer(p^, Rest);
              p := GetOffset(p, Rest);
            end;
        end
      else
          stream.WriteBuffer(p^, Size);
    end;
end;

procedure TMem64.SaveToFile(FileName: SystemString);
var
  stream: TCore_Stream;
begin
  stream := TCore_FileStream.Create(FileName, fmCreate);
  try
      SaveToStream(stream);
  finally
      DisposeObject(stream);
  end;
end;

function TMem64.Write64(const buffer; Count: Int64): Int64;
var
  p: Int64;
begin
  if (Count > 0) then
    begin
      p := FPosition;
      p := p + Count;
      if p > 0 then
        begin
          if p > FSize then
            begin
              if FProtectedMode then
                begin
                  Result := 0;
                  Exit;
                end;
              if p > FCapacity then
                  SetCapacity(p);
              FSize := p;
            end;
          CopyPtr(@buffer, GetOffset(FMemory, FPosition), Count);
          FPosition := p;
          Result := Count;
          Exit;
        end;
    end;
  Result := 0;
end;

function TMem64.WritePtr(const p: Pointer; Count: Int64): Int64;
begin
  Result := Write64(p^, Count);
end;

function TMem64.write(const buffer; Count: Int64): Int64;
begin
  Result := Write64(buffer, Count);
end;

function TMem64.WriteBytes(const buffer: TBytes): Int64;
begin
  if Length(buffer) > 0 then
      Result := WritePtr(@buffer[0], Length(buffer))
  else
      Result := 0;
end;

function TMem64.Read64(var buffer; Count: Int64): Int64;
begin
  if Count > 0 then
    begin
      Result := FSize - FPosition;
      if Result > 0 then
        begin
          if Result > Count then
              Result := Count;
          CopyPtr(GetOffset(FMemory, FPosition), @buffer, Result);
          inc(FPosition, Result);
          Exit;
        end;
    end;
  Result := 0;
end;

function TMem64.ReadPtr(const p: Pointer; Count: Int64): Int64;
begin
  Result := Read64(p^, Count);
end;

function TMem64.read(var buffer; Count: Int64): Int64;
begin
  Result := Read64(buffer, Count);
end;

function TMem64.Seek(const Offset: Int64; origin: TSeekOrigin): Int64;
begin
  case origin of
    TSeekOrigin.soBeginning: FPosition := Offset;
    TSeekOrigin.soCurrent: inc(FPosition, Offset);
    TSeekOrigin.soEnd: FPosition := FSize + Offset;
  end;
  Result := FPosition;
end;

function TMem64.CopyFrom(const source: TCore_Stream; Count: Int64): Int64;
const
  MaxBufSize = $F000;
var
  BufSize, n, p: Int64;
begin
  if FProtectedMode then
      RaiseInfo('protected mode');
  if Count = 0 then
      Exit(0);
  if Count < 0 then
    begin
      source.Position := 0;
      Count := source.Size;
    end;
  if source is TMS64 then
    begin
      WritePtr(TMS64(source).PositionAsPtr, Count);
      TMS64(source).Position := TMS64(source).FPosition + Count;
      Result := Count;
      Exit;
    end;
  Result := Count;
  if Count > MaxBufSize then
      BufSize := MaxBufSize
  else
      BufSize := Count;
  p := Position;
  if p + Count > Size then
      Size := p + Count;
  while Count <> 0 do
    begin
      if Count > BufSize then
          n := BufSize
      else
          n := Count;
      if source.read(PosAsPtr(p)^, n) <> n then
          RaiseInfo('stream read error.');
      inc(p, n);
      dec(Count, n);
    end;
  Position := p;
end;

function TMem64.CopyFrom(const source: TMem64; Count: Int64): Int64;
begin
  if FProtectedMode then
      RaiseInfo('protected mode');
  WritePtr(source.PositionAsPtr, Count);
  source.Position := source.FPosition + Count;
  Result := Count;
end;

{ ****** Typed write/read for TMem64 (identical to TMS64) ********** }
procedure TMem64.WriteBool(const buff: Boolean);
begin
  WritePtr(@buff, 1);
end;

procedure TMem64.WriteInt8(const buff: ShortInt);
begin
  WritePtr(@buff, 1);
end;

procedure TMem64.WriteInt16(const buff: SmallInt);
begin
  WritePtr(@buff, 2);
end;

procedure TMem64.WriteInt32(const buff: Integer);
begin
  WritePtr(@buff, 4);
end;

procedure TMem64.WriteInt64(const buff: Int64);
begin
  WritePtr(@buff, 8);
end;

procedure TMem64.WriteInt128(const buff: Int128);
begin
  WritePtr(@buff.b[0], 16);
end;

procedure TMem64.WriteUInt8(const buff: Byte);
begin
  WritePtr(@buff, 1);
end;

procedure TMem64.WriteUInt16(const buff: Word);
begin
  WritePtr(@buff, 2);
end;

procedure TMem64.WriteUInt32(const buff: Cardinal);
begin
  WritePtr(@buff, 4);
end;

procedure TMem64.WriteUInt64(const buff: UInt64);
begin
  WritePtr(@buff, 8);
end;

procedure TMem64.WriteUInt128(const buff: UInt128);
begin
  WritePtr(@buff.b[0], 16);
end;

procedure TMem64.WriteSingle(const buff: Single);
begin
  WritePtr(@buff, 4);
end;

procedure TMem64.WriteDouble(const buff: Double);
begin
  WritePtr(@buff, 8);
end;

procedure TMem64.WriteCurrency(const buff: Currency);
begin
  WriteDouble(buff);
end;

procedure TMem64.WriteString(const buff: TPascalString);
var
  b: TBytes;
begin
  b := buff.Bytes;
  WriteUInt32(Length(b));
  if Length(b) > 0 then
    begin
      WritePtr(@b[0], Length(b));
      SetLength(b, 0);
    end;
end;

procedure TMem64.WriteANSI(const buff: TPascalString);
var
  b: TBytes;
begin
  b := buff.ANSI;
  if Length(b) > 0 then
    begin
      WritePtr(@b[0], Length(b));
      SetLength(b, 0);
    end;
end;

procedure TMem64.WriteANSI(const buff: TPascalString; const L: Integer);
var
  b: TBytes;
begin
  b := buff.ANSI;
  if L > 0 then
    begin
      WritePtr(@b[0], L);
      SetLength(b, 0);
    end;
end;

procedure TMem64.WriteString(const buff: TUPascalString);
var
  b: TBytes;
begin
  b := buff.Bytes;
  WriteUInt32(Length(b));
  if Length(b) > 0 then
    begin
      WritePtr(@b[0], Length(b));
      SetLength(b, 0);
    end;
end;

procedure TMem64.WriteANSI(const buff: TUPascalString);
var
  b: TBytes;
begin
  b := buff.ANSI;
  if Length(b) > 0 then
    begin
      WritePtr(@b[0], Length(b));
      SetLength(b, 0);
    end;
end;

procedure TMem64.WriteANSI(const buff: TUPascalString; const L: Integer);
var
  b: TBytes;
begin
  b := buff.ANSI;
  if L > 0 then
    begin
      WritePtr(@b[0], L);
      SetLength(b, 0);
    end;
end;

procedure TMem64.WriteMD5(const buff: TMD5);
begin
  WritePtr(@buff, 16);
end;

function TMem64.ReadBool: Boolean;
begin
  ReadPtr(@Result, 1);
end;

function TMem64.ReadInt8: ShortInt;
begin
  ReadPtr(@Result, 1);
end;

function TMem64.ReadInt16: SmallInt;
begin
  ReadPtr(@Result, 2);
end;

function TMem64.ReadInt32: Integer;
begin
  ReadPtr(@Result, 4);
end;

function TMem64.ReadInt64: Int64;
begin
  ReadPtr(@Result, 8);
end;

function TMem64.ReadInt128: Int128;
begin
  ReadPtr(@Result.b[0], 16);
end;

function TMem64.ReadUInt8: Byte;
begin
  ReadPtr(@Result, 1);
end;

function TMem64.ReadUInt16: Word;
begin
  ReadPtr(@Result, 2);
end;

function TMem64.ReadUInt32: Cardinal;
begin
  ReadPtr(@Result, 4);
end;

function TMem64.ReadUInt64: UInt64;
begin
  ReadPtr(@Result, 8);
end;

function TMem64.ReadUInt128: UInt128;
begin
  ReadPtr(@Result.b[0], 16);
end;

function TMem64.ReadSingle: Single;
begin
  ReadPtr(@Result, 4);
end;

function TMem64.ReadDouble: Double;
begin
  ReadPtr(@Result, 8);
end;

function TMem64.ReadCurrency: Currency;
begin
  Result := ReadDouble();
end;

function TMem64.PrepareReadString: Boolean;
begin
  Result := (Position + 4 <= Size) and (Position + 4 + PCardinal(PositionAsPtr())^ <= Size);
end;

function TMem64.ReadString: TPascalString;
var
  L: Cardinal;
  b: TBytes;
begin
  L := ReadUInt32;
  L := Min(L, Max(Size - Position, 0));
  if L > 0 then
    begin
      try
        SetLength(b, L);
        ReadPtr(@b[0], L);
        Result.Bytes := b;
        SetLength(b, 0);
      except
          Result := '';
      end;
    end;
end;

function TMem64.ReadStringAsBuff: TBytes;
var
  L: Cardinal;
begin
  try
    L := ReadUInt32;
    L := Min(L, Max(Size - Position, 0));
    if L > 0 then
      begin
        SetLength(Result, L);
        ReadPtr(@Result[0], L);
      end
    else
        SetLength(Result, 0);
  except
      SetLength(Result, 0);
  end;
end;

procedure TMem64.IgnoreReadString;
var
  L: Cardinal;
begin
  L := ReadUInt32;
  L := Min(L, Max(Size - Position, 0));
  if L > 0 then
      Position := Position + L;
end;

function TMem64.ReadANSI(L: Integer): TPascalString;
var
  b: TBytes;
begin
  if L > 0 then
    begin
      SetLength(b, L);
      ReadPtr(@b[0], L);
      Result.ANSI := b;
      SetLength(b, 0);
    end;
end;

function TMem64.ReadMD5: TMD5;
begin
  ReadPtr(@Result, 16);
end;

procedure TMem64List.Clean;
var
  i: Integer;
begin
  for i := 0 to Count - 1 do
      DisposeObject(Items[i]);
  Clear;
end;

{$IFDEF FPC}


constructor TCompressionStream.Create(stream: TCore_Stream);
{ * FPC: Creates a compression stream with fastest level. }
begin
  inherited Create(clFastest, stream);
end;

constructor TCompressionStream.Create(level: Tcompressionlevel; stream: TCore_Stream);
{ * FPC: Creates with specified compression level. }
begin
  inherited Create(level, stream);
end;
{$ENDIF}

{ ****** Global compression functions ********** }

function MaxCompressStream(sour, dest: TCore_Stream): Boolean;
{ *
  * Compresses sour with ZLIB maximum compression.
  * Writes 8‑byte original size then compressed data.
}
var
  cStream: TCompressionStream;
  siz_: Int64;
begin
  Result := False;
  try
    siz_ := sour.Size;
    dest.WriteBuffer(siz_, 8);
    if sour.Size > 0 then
      begin
        sour.Position := 0;
        cStream := TCompressionStream.Create(clMax, dest);
        Result := cStream.CopyFrom(sour, siz_) = siz_;
        DisposeObject(cStream);
      end;
  except
  end;
end;

function FastCompressStream(sour, dest: TCore_Stream): Boolean;
{ * Same but with fastest compression. }
var
  cStream: TCompressionStream;
  siz_: Int64;
begin
  Result := False;
  try
    siz_ := sour.Size;
    dest.WriteBuffer(siz_, 8);
    if sour.Size > 0 then
      begin
        sour.Position := 0;
        cStream := TCompressionStream.Create(clFastest, dest);
        Result := cStream.CopyFrom(sour, siz_) = siz_;
        DisposeObject(cStream);
      end;
  except
  end;
end;

function CompressStream(sour, dest: TCore_Stream): Boolean;
{ * Default ZLIB compression. }
var
  cStream: TCompressionStream;
  siz_: Int64;
begin
  Result := False;
  try
    siz_ := sour.Size;
    dest.WriteBuffer(siz_, 8);
    if sour.Size > 0 then
      begin
        sour.Position := 0;
        cStream := TCompressionStream.Create(clDefault, dest);
        Result := cStream.CopyFrom(sour, siz_) = siz_;
        DisposeObject(cStream);
      end;
  except
  end;
end;

function DecompressStream(DataPtr: Pointer; siz: NativeInt; dest: TCore_Stream): Boolean;
{ * Decompresses from a memory pointer using a temporary TMS64. }
var
  m64: TMS64;
begin
  m64 := TMS64.Create;
  m64.SetPointer(DataPtr, siz);
  Result := DecompressStream(m64, dest);
  DisposeObject(m64);
end;

function DecompressStream(sour: TCore_Stream; dest: TCore_Stream): Boolean;
{ *
  * Decompresses ZLIB data (format: 8‑byte original size, then compressed data).
  * Reads the size, expands dest, and decompresses.
}
var
  dcStream: TDecompressionStream;
  dSiz: Int64;
  iPos: Int64;
begin
  Result := False;
  sour.ReadBuffer(dSiz, 8);
  if dSiz > 0 then
    begin
      iPos := dest.Position;
      dest.Size := iPos + dSiz;
      dest.Position := iPos;
      try
        dcStream := TDecompressionStream.Create(sour);
        Result := dest.CopyFrom(dcStream, dSiz) = dSiz;
        DisposeObject(dcStream);
      except
      end;
    end;
end;

function DecompressStreamToPtr(sour: TCore_Stream; var dest: Pointer): Boolean;
{ * Decompresses into a newly allocated pointer (caller must free). }
var
  dcStream: TDecompressionStream;
  dSiz: Int64;
begin
  Result := False;
  try
    sour.ReadBuffer(dSiz, 8);
    if dSiz > 0 then
      begin
        dcStream := TDecompressionStream.Create(sour);
        dest := System.GetMemory(dSiz);
        Result := dcStream.read(dest^, dSiz) = dSiz;
        DisposeObject(dcStream);
      end;
  except
  end;
end;

function CompressFile(sour, dest: SystemString): Boolean;
var
  s_fs, d_fs: TCore_FileStream;
begin
  s_fs := TCore_FileStream.Create(sour, fmOpenRead or fmShareDenyNone);
  d_fs := TCore_FileStream.Create(dest, fmCreate);
  Result := CompressStream(s_fs, d_fs);
  DisposeObject(s_fs);
  DisposeObject(d_fs);
end;

function DecompressFile(sour, dest: SystemString): Boolean;
var
  s_fs, d_fs: TCore_FileStream;
begin
  s_fs := TCore_FileStream.Create(sour, fmOpenRead or fmShareDenyNone);
  d_fs := TCore_FileStream.Create(dest, fmCreate);
  Result := DecompressStream(s_fs, d_fs);
  DisposeObject(s_fs);
  DisposeObject(d_fs);
end;

function SelectCompressStream(const scm: TSelectCompressionMethod; const sour, dest: TCore_Stream): Boolean;
{ *
  * Compresses sour using the selected method.
  * Writes a method ID byte first, then the compressed data in that method's format.
  * For LZ4/Snappy, the stream is temporarily loaded into a TMS64 for compression.
}
var
  scm_b: Byte;
  siz_: Int64;
  tmpSour, tmpDest: TMS64;
begin
  Result := False;
  scm_b := Byte(scm);
  if dest.write(scm_b, 1) <> 1 then
      Exit;
  sour.Position := 0;
  try
    case scm of
      scmNone:
        begin
          siz_ := sour.Size;
          dest.write(siz_, 8);
          Result := dest.CopyFrom(sour, siz_) = siz_;
        end;
      scmZLIB: Result := CompressStream(sour, dest);
      scmZLIB_Fast: Result := FastCompressStream(sour, dest);
      scmZLIB_Max: Result := MaxCompressStream(sour, dest);
      scmDeflate: Result := DeflateCompressStream(sour, dest);
      scmBRRC: Result := BRRCCompressStream(sour, dest);
      scmLZ4:
        begin
          tmpSour := TMS64.Create;
          if sour is TMS64 then
              tmpSour.Mapping(TMS64(sour))
          else
              tmpSour.LoadFromStream(sour);
          tmpDest := tmpSour.LZ4;
          DisposeObject(tmpSour);
          dest.write(tmpDest.Memory^, tmpDest.Size);
          DisposeObject(tmpDest);
          Result := True;
        end;
      scmSnappy_Pas:
        begin
          tmpSour := TMS64.Create;
          if sour is TMS64 then
              tmpSour.Mapping(TMS64(sour))
          else
              tmpSour.LoadFromStream(sour);
          tmpDest := tmpSour.Snappy_Pas;
          DisposeObject(tmpSour);
          dest.write(tmpDest.Memory^, tmpDest.Size);
          DisposeObject(tmpDest);
          Result := True;
        end;
    end;
  except
  end;
end;

function SelectDecompressStream(const sour, dest: TCore_Stream): Boolean;
{ * Auto‑detect and decompress (no method returned). }
var
  scm: TSelectCompressionMethod;
begin
  Result := SelectDecompressStream(sour, dest, scm);
end;

function SelectDecompressStream(const sour, dest: TCore_Stream; var scm: TSelectCompressionMethod): Boolean;
{ *
  * Reads the method ID byte, then decompresses accordingly.
  * Supports all methods in TSelectCompressionMethod.
}
var
  scm_: Byte;
  siz_: Int64;
  tmpSour, tmpDest: TMS64;
begin
  Result := False;
  if sour.read(scm_, 1) <> 1 then
      Exit;
  scm := TSelectCompressionMethod(scm_);
  try
    case scm of
      scmNone:
        begin
          if sour.read(siz_, 8) <> 8 then
              Exit;
          Result := dest.CopyFrom(sour, siz_) = siz_;
        end;
      scmZLIB, scmZLIB_Fast, scmZLIB_Max: Result := DecompressStream(sour, dest);
      scmDeflate: Result := DeflateDecompressStream(sour, dest);
      scmBRRC: Result := BRRCDecompressStream(sour, dest);
      scmLZ4:
        begin
          tmpSour := TMS64.Create;
          if sour is TMS64 then
              tmpSour.Mapping(TMS64(sour).PosAsPtr, TMS64(sour).Size - TMS64(sour).Position)
          else
              tmpSour.CopyFrom(sour, sour.Size - sour.Position);
          tmpDest := tmpSour.UnLZ4;
          DisposeObject(tmpSour);
          if dest is TMS64 then
              TMS64(dest).SwapInstance(tmpDest)
          else
              tmpDest.SaveToStream(dest);
          DisposeObject(tmpDest);
          Result := True;
        end;
      scmSnappy_Pas:
        begin
          tmpSour := TMS64.Create;
          if sour is TMS64 then
              tmpSour.Mapping(TMS64(sour).PosAsPtr, TMS64(sour).Size - TMS64(sour).Position)
          else
              tmpSour.CopyFrom(sour, sour.Size - sour.Position);
          tmpDest := tmpSour.UnSnappy_Pas;
          DisposeObject(tmpSour);
          if dest is TMS64 then
              TMS64(dest).SwapInstance(tmpDest)
          else
              tmpDest.SaveToStream(dest);
          DisposeObject(tmpDest);
          Result := True;
        end;
    end;
  except
  end;
end;

{ ****** Parallel compression/decompression ********** }

procedure ParallelCompressMemory(const ThNum: Integer; const scm: TSelectCompressionMethod; const StripNum_: Integer; const sour: TMS64; const dest: TCore_Stream);
{ *
  * Splits sour into StripNum_ strips and compresses each in parallel.
  * Output format:
  *   [StripCount: Integer]
  *   for each strip: [StripSize: Int64][CompressedData]
  * The number of threads is limited by ThNum.
}
var
  StripNum: Integer;
  sourStrips: TStream64List;
  StripArry: array of TMS64;
{$IFDEF Parallel}
{$IFDEF FPC}
  procedure Nested_ParallelFor(pass: Integer);
  begin
    SelectCompressStream(scm, sourStrips[pass], StripArry[pass]);
  end;
{$ENDIF FPC}
{$ENDIF Parallel}
  procedure DoFor;
  var
    pass: Integer;
  begin
    for pass := 0 to Length(StripArry) - 1 do
        SelectCompressStream(scm, sourStrips[pass], StripArry[pass]);
  end;
  procedure BuildBuff;
  var
    strip_siz, strip_m: Int64;
    p: Int64;
    m64: TMS64;
    i: Integer;
  begin
    sourStrips := TStream64List.Create;
    strip_siz := sour.Size div StripNum;
    p := 0;
    while True do
      begin
        if p + strip_siz < sour.Size then
          begin
            m64 := TMS64.Create;
            m64.SetPointerWithProtectedMode(sour.PositionAsPtr(p), strip_siz);
            sourStrips.Add(m64);
            inc(p, strip_siz);
          end
        else
          begin
            if sour.Size - p > 0 then
              begin
                m64 := TMS64.Create;
                m64.SetPointerWithProtectedMode(sour.PositionAsPtr(p), sour.Size - p);
                sourStrips.Add(m64);
              end;
            break;
          end;
      end;
    SetLength(StripArry, sourStrips.Count);
    for i := 0 to sourStrips.Count - 1 do
        StripArry[i] := TMS64.CustomCreate(1024);
  end;
  procedure BuildOutput;
  var
    L: Integer;
    siz_: Int64;
    i: Integer;
  begin
    L := Length(StripArry);
    dest.write(L, 4);
    for i := 0 to L - 1 do
      begin
        siz_ := StripArry[i].Size;
        dest.write(siz_, 8);
        dest.write(StripArry[i].Memory^, StripArry[i].Size);
        DisposeObject(sourStrips[i]);
        DisposeObject(StripArry[i]);
      end;
  end;
  procedure FreeBuff;
  begin
    DisposeObject(sourStrips);
    SetLength(StripArry, 0);
  end;

begin
  if StripNum_ <= 0 then
      StripNum := 1
  else
      StripNum := StripNum_;
  BuildBuff;
  if Length(StripArry) < ThNum then
    begin
      DoFor;
    end
  else
    begin
{$IFDEF Parallel}
{$IFDEF FPC}
      FPCParallelFor(ThNum, True, 0, Length(StripArry) - 1, Nested_ParallelFor);
{$ELSE FPC}
      DelphiParallelFor(ThNum, True, 0, Length(StripArry) - 1,
          procedure(pass: Integer)
        begin
          SelectCompressStream(scm, sourStrips[pass], StripArry[pass]);
        end);
{$ENDIF FPC}
{$ELSE Parallel}
      DoFor;
{$ENDIF Parallel}
    end;
  BuildOutput;
  FreeBuff;
end;

procedure ParallelCompressMemory(const scm: TSelectCompressionMethod; const StripNum_: Integer; const sour: TMS64; const dest: TCore_Stream);
{ * Uses up to 4 threads (or ParallelGranularity). }
begin
  ParallelCompressMemory(Min(4, Get_Parallel_Granularity), scm, StripNum_, sour, dest);
end;

procedure ParallelCompressMemory(const scm: TSelectCompressionMethod; const sour: TMS64; const dest: TCore_Stream);
{ * Automatically chooses strip number based on size (16KB strips). }
begin
  ParallelCompressMemory(scm, sour.Size div (16 * 1024), sour, dest);
end;

procedure ParallelCompressMemory(const sour: TMS64; const dest: TCore_Stream);
{ * Default: uses ZLIB. }
begin
  ParallelCompressMemory(scmZLIB, sour, dest);
end;

procedure ParallelDecompressStream(const ThNum: Integer; const sour_, dest_: TCore_Stream);
{ *
  * Decompresses a stream produced by ParallelCompressMemory.
  * It reads the strip count and each strip's compressed data, decompresses
  * each in parallel, and writes the results to dest_ in order.
}
type
  TPara_strip_ = record
    sour, dest: TMS64;
  end;

  PPara_strip_ = ^TPara_strip_;
var
  StripArry: array of TPara_strip_;
{$IFDEF Parallel}
{$IFDEF FPC}
  procedure Nested_ParallelFor(pass: Integer);
  begin
    SelectDecompressStream(StripArry[pass].sour, StripArry[pass].dest);
  end;
{$ENDIF FPC}
{$ELSE Parallel}
{$ENDIF Parallel}
  procedure DoFor;
  var
    pass: Integer;
  begin
    for pass := 0 to Length(StripArry) - 1 do
        SelectDecompressStream(StripArry[pass].sour, StripArry[pass].dest);
  end;
  function BuildBuff_Stream64(stream: TMS64): Boolean;
  var
    strip_num: Integer;
    i: Integer;
    p, siz_, ss: Int64;
  begin
    Result := False;
    ss := stream.Size;
    p := stream.Position;
    if p + 4 > ss then
        Exit;
    strip_num := PInteger(stream.PositionAsPtr(p))^;
    inc(p, 4);
    SetLength(StripArry, strip_num);
    for i := 0 to strip_num - 1 do
      begin
        StripArry[i].sour := TMS64.Create;
        if p + 4 > ss then
            Exit;
        siz_ := PInt64(stream.PositionAsPtr(p))^;
        inc(p, 8);
        if p + siz_ > ss then
            Exit;
        StripArry[i].sour.SetPointerWithProtectedMode(stream.PositionAsPtr(p), siz_);
        inc(p, siz_);
        StripArry[i].sour.Position := 0;
        StripArry[i].dest := TMS64.CustomCreate(1024);
      end;
    stream.Position := p;
    Result := True;
  end;
  function BuildBuff_Stream(stream: TCore_Stream): Boolean;
  var
    strip_num: Integer;
    i: Integer;
    siz_: Int64;
  begin
    Result := False;
    if stream.read(strip_num, 4) <> 4 then
        Exit;
    SetLength(StripArry, strip_num);
    for i := 0 to strip_num - 1 do
      begin
        StripArry[i].sour := TMS64.CustomCreate(1024);
        StripArry[i].dest := TMS64.CustomCreate(1024);
      end;
    for i := 0 to strip_num - 1 do
      begin
        if stream.read(siz_, 8) <> 8 then
            Exit;
        if StripArry[i].sour.CopyFrom(stream, siz_) <> siz_ then
            Exit;
        StripArry[i].sour.Position := 0;
      end;
    Result := True;
  end;
  procedure BuildOutput;
  var
    i: Integer;
  begin
    for i := 0 to Length(StripArry) - 1 do
      begin
        dest_.write(StripArry[i].dest.Memory^, StripArry[i].dest.Size);
        DisposeObject(StripArry[i].sour);
        DisposeObject(StripArry[i].dest);
      end;
  end;
  procedure FreeBuff;
  begin
    SetLength(StripArry, 0);
  end;

var
  preDone: Boolean;
begin
  if sour_ is TMS64 then
      preDone := BuildBuff_Stream64(TMS64(sour_))
  else
      preDone := BuildBuff_Stream(sour_);
  if not preDone then
    begin
      FreeBuff;
      Exit;
    end;
  if Length(StripArry) < ThNum then
    begin
      DoFor;
    end
  else
    begin
{$IFDEF Parallel}
{$IFDEF FPC}
      FPCParallelFor(ThNum, True, 0, Length(StripArry) - 1, Nested_ParallelFor);
{$ELSE FPC}
      DelphiParallelFor(ThNum, True, 0, Length(StripArry) - 1,
        procedure(pass: Integer)
        begin
          SelectDecompressStream(StripArry[pass].sour, StripArry[pass].dest);
        end);
{$ENDIF FPC}
{$ELSE Parallel}
      DoFor;
{$ENDIF Parallel}
    end;
  BuildOutput;
  FreeBuff;
end;

procedure ParallelDecompressStream(const sour_, dest_: TCore_Stream);
{ * Uses up to 4 threads. }
begin
  ParallelDecompressStream(Min(4, Get_Parallel_Granularity), sour_, dest_);
end;

procedure ParallelCompressFile(const sour, dest: SystemString);
{ * Parallel compress a file: loads entire file into TMS64, then parallel compress. }
var
  s_fs: TMS64;
  d_fs: TCore_FileStream;
begin
  s_fs := TMS64.Create;
  s_fs.LoadFromFile(sour);
  d_fs := TCore_FileStream.Create(dest, fmCreate);
  ParallelCompressMemory(s_fs, d_fs);
  DisposeObject(s_fs);
  DisposeObject(d_fs);
end;

procedure ParallelDecompressFile(const sour, dest: SystemString);
{ * Parallel decompress a file. }
var
  s_fs: TMS64;
  d_fs: TCore_FileStream;
begin
  s_fs := TMS64.Create;
  s_fs.LoadFromFile(sour);
  d_fs := TCore_FileStream.Create(dest, fmCreate);
  ParallelDecompressStream(s_fs, d_fs);
  DisposeObject(s_fs);
  DisposeObject(d_fs);
end;

function CompressUTF8(const sour_: TBytes): TBytes;
{ *
  * Compresses a TBytes using ZLIB max. If compression does not reduce size,
  * returns the original. Output format: if compressed, header [0xFF,0xFF] +
  * 4‑byte original size + compressed data.
}
var
  cStream: TCompressionStream;
  dest: TMS64;
begin
  if Length(sour_) > 10 then
    begin
      dest := TMS64.Create;
      cStream := TCompressionStream.Create(clMax, dest);
      cStream.write(sour_[0], Length(sour_));
      DisposeObject(cStream);
      if dest.Size + 6 < Length(sour_) then
        begin
          SetLength(Result, dest.Size + 6);
          Result[0] := $FF;
          Result[1] := $FF;
          PInteger(@Result[2])^ := Length(sour_);
          CopyPtr(dest.Memory, @Result[6], dest.Size);
        end
      else
          Result := sour_;
      DisposeObject(dest);
    end
  else
      Result := sour_;
end;

function DecompressUTF8(const sour_: TBytes): TBytes;
{ *
  * Decompresses data created by CompressUTF8. If it does not have the
  * [0xFF,0xFF] header, returns the original data (not compressed).
}
var
  dcStream: TDecompressionStream;
  sour: TMS64;
  siz: Integer;
begin
  if Length(sour_) > 6 then
    begin
      if (sour_[0] = $FF) and (sour_[1] = $FF) then
        begin
          siz := PInteger(@sour_[2])^;
          sour := TMS64.Create();
          sour.SetPointer(@sour_[6], Length(sour_) - 6);
          dcStream := TDecompressionStream.Create(sour);
          SetLength(Result, siz);
          dcStream.read(Result[0], siz);
          DisposeObject(sour);
          DisposeObject(dcStream);
        end
      else
          Result := sour_;
    end
  else
      Result := sour_;
end;

{ ****** Stream serialisation helpers ********** }
{ *
  * These helpers provide typed read/write on any TCore_Stream, using its
  * built‑in read/write methods. They are used by TMS64/TMem64 internally.
  *
  * @Example:
  *   var
  *     st: TMemoryStream;
  *   begin
  *     st := TMemoryStream.Create;
  *     StreamWriteInt32(st, 123);
  *     st.Position := 0;
  *     WriteLn(StreamReadInt32(st)); // prints 123
  *     st.Free;
  *   end;
  * }
procedure StreamWriteBool(const stream: TCore_Stream; const buff: Boolean);
begin
  stream.write(buff, 1);
end;

procedure StreamWriteInt8(const stream: TCore_Stream; const buff: ShortInt);
begin
  stream.write(buff, 1);
end;

procedure StreamWriteInt16(const stream: TCore_Stream; const buff: SmallInt);
begin
  stream.write(buff, 2);
end;

procedure StreamWriteInt32(const stream: TCore_Stream; const buff: Integer);
begin
  stream.write(buff, 4);
end;

procedure StreamWriteInt64(const stream: TCore_Stream; const buff: Int64);
begin
  stream.write(buff, 8);
end;

procedure StreamWriteInt128(const stream: TCore_Stream; const buff: Int128);
begin
  stream.write(buff.b[0], 16);
end;

procedure StreamWriteUInt8(const stream: TCore_Stream; const buff: Byte);
begin
  stream.write(buff, 1);
end;

procedure StreamWriteUInt16(const stream: TCore_Stream; const buff: Word);
begin
  stream.write(buff, 2);
end;

procedure StreamWriteUInt32(const stream: TCore_Stream; const buff: Cardinal);
begin
  stream.write(buff, 4);
end;

procedure StreamWriteUInt64(const stream: TCore_Stream; const buff: UInt64);
begin
  stream.write(buff, 8);
end;

procedure StreamWriteUInt128(const stream: TCore_Stream; const buff: UInt128);
begin
  stream.write(buff.b[0], 16);
end;

procedure StreamWriteSingle(const stream: TCore_Stream; const buff: Single);
begin
  stream.write(buff, 4);
end;

procedure StreamWriteDouble(const stream: TCore_Stream; const buff: Double);
begin
  stream.write(buff, 8);
end;

procedure StreamWriteCurrency(const stream: TCore_Stream; const buff: Currency);
begin
  StreamWriteDouble(stream, buff);
end;

procedure StreamWriteString(const stream: TCore_Stream; const buff: TPascalString);
{ * Writes a TPascalString as UTF‑8 with 4‑byte length. }
var
  b: TBytes;
begin
  b := buff.Bytes;
  StreamWriteUInt32(stream, Length(b));
  if Length(b) > 0 then
    begin
      stream.write(b[0], Length(b));
      SetLength(b, 0);
    end;
end;

function ComputeStreamWriteStringSize(buff: TPascalString): Integer;
{ * Computes the number of bytes that would be written by StreamWriteString. }
var
  b: TBytes;
begin
  b := buff.Bytes;
  Result := 4 + Length(b);
  SetLength(b, 0);
end;

procedure StreamWriteMD5(const stream: TCore_Stream; const buff: TMD5);
begin
  stream.write(buff, 16);
end;

function StreamReadBool(const stream: TCore_Stream): Boolean;
begin
  stream.read(Result, 1);
end;

function StreamReadInt8(const stream: TCore_Stream): ShortInt;
begin
  stream.read(Result, 1);
end;

function StreamReadInt16(const stream: TCore_Stream): SmallInt;
begin
  stream.read(Result, 2);
end;

function StreamReadInt32(const stream: TCore_Stream): Integer;
begin
  stream.read(Result, 4);
end;

function StreamReadInt64(const stream: TCore_Stream): Int64;
begin
  stream.read(Result, 8);
end;

function StreamReadInt128(const stream: TCore_Stream): Int128;
begin
  stream.read(Result.b[0], 16);
end;

function StreamReadUInt8(const stream: TCore_Stream): Byte;
begin
  stream.read(Result, 1);
end;

function StreamReadUInt16(const stream: TCore_Stream): Word;
begin
  stream.read(Result, 2);
end;

function StreamReadUInt32(const stream: TCore_Stream): Cardinal;
begin
  stream.read(Result, 4);
end;

function StreamReadUInt64(const stream: TCore_Stream): UInt64;
begin
  stream.read(Result, 8);
end;

function StreamReadUInt128(const stream: TCore_Stream): UInt128;
begin
  stream.read(Result.b[0], 16);
end;

function StreamReadSingle(const stream: TCore_Stream): Single;
begin
  stream.read(Result, 4);
end;

function StreamReadDouble(const stream: TCore_Stream): Double;
begin
  stream.read(Result, 8);
end;

function StreamReadCurrency(const stream: TCore_Stream): Currency;
begin
  Result := StreamReadDouble(stream);
end;

function StreamReadString(const stream: TCore_Stream): TPascalString;
{ * Reads a string written by StreamWriteString. }
var
  L: Cardinal;
  b: TBytes;
begin
  try
    L := StreamReadUInt32(stream);
    if L > 0 then
      begin
        SetLength(b, L);
        stream.read(b[0], L);
        Result.Bytes := b;
        SetLength(b, 0);
      end;
  except
      Result := '';
  end;
end;

function StreamReadStringAsBuff(const stream: TCore_Stream): TBytes;
{ * Reads raw UTF‑8 bytes. }
var
  L: Cardinal;
begin
  try
    L := StreamReadUInt32(stream);
    if L > 0 then
      begin
        SetLength(Result, L);
        stream.read(Result[0], L);
      end
    else
        SetLength(Result, 0);
  except
      SetLength(Result, 0);
  end;
end;

procedure StreamIgnoreReadString(const stream: TCore_Stream);
{ * Skips a string. }
var
  L: Cardinal;
  b: TBytes;
begin
  try
    L := StreamReadUInt32(stream);
    if L > 0 then
      begin
        SetLength(b, L);
        stream.read(b[0], L);
        SetLength(b, 0);
      end;
  except
  end;
end;

function StreamReadMD5(const stream: TCore_Stream): TMD5;
begin
  stream.read(Result, 16);
end;

{ ****** Debug helpers ********** }
procedure DoStatus(const v: TMS64);
{ * Prints the stream's memory content as comma‑separated hex values. }
var
  p: PByte;
  i: Integer;
  n: SystemString;
begin
  p := v.Memory;
  for i := 0 to v.Size - 1 do
    begin
      if n <> '' then
          n := n + ',' + IntToStr(p^)
      else
          n := IntToStr(p^);
      inc(p);
    end;
  DoStatus(IntToHex(NativeInt(v), SizeOf(Pointer)) + ':' + n);
end;

procedure DoStatus(const v: TMem64);
{ * Same but for TMem64. }
var
  p: PByte;
  i: Integer;
  n: SystemString;
begin
  p := v.Memory;
  for i := 0 to v.Size - 1 do
    begin
      if n <> '' then
          n := n + ',' + IntToStr(p^)
      else
          n := IntToStr(p^);
      inc(p);
    end;
  DoStatus(IntToHex(NativeInt(v), SizeOf(Pointer)) + ':' + n);
end;

initialization

end.

{ ******************************************************************************
  * Z.DFE - Data Frame Engine
  *
  * This unit provides a comprehensive binary serialization framework called
  * "Data Frame Engine" (DFE). It allows you to store, retrieve, compress,
  * encrypt, and convert between binary and JSON representations of complex
  * data structures.
  *
  * Core Concepts:
  *   - Data Frame: A single typed data item (e.g., Integer, String, Array,
  *     Stream, Variant, etc.). Each frame has a type ID and a payload.
  *   - TDFE: The main container that holds a list of frames. It provides
  *     methods to write/read frames, encode/decode to/from binary streams,
  *     compress, encrypt, and export/import JSON.
  *   - Serialization Format: A binary stream consisting of a header (version,
  *     size, compression info, MD5) followed by a sequence of frames.
  *   - Compression: Supports ZLib, Deflate, BRRC, LZ4, Snappy, and an
  *     automatic selector based on data size.
  *   - Encryption: Quantum Cryptography (via Z.Cipher) to protect data.
  *   - JSON Interop: DFE can be exported to JSON arrays and imported back.
  *
  * This engine is deeply integrated with the Z-framework, supporting all
  * core data types including geometry, OpCode, text engines, and hash lists.
  ****************************************************************************** }
unit Z.DFE;

{$DEFINE FPC_DELPHI_MODE}
{$I Z.Define.inc}

interface

uses
  Types,
  Z.Core, Z.UnicodeMixedLib, Z.PascalStrings, Z.UPascalStrings,
{$IFDEF FPC}
  Z.FPC.GenericList,
{$ELSE FPC}
  Z.Delphi.JsonDataObjects,
{$ENDIF FPC}
  Z.ListEngine,
  Z.MemoryStream, Z.Cipher,
  Z.Status, Z.Geometry.Low, Z.Geometry2D, Z.Geometry3D, Z.Json,
  Z.Expression, Z.OpCode, Z.TextDataEngine, Z.Number,
  Z.Compress, Z.Int128;

type
  { Type aliases for convenience }
  TDFE = class; { Main Data Frame Engine class }
  TDataFrameEngine = TDFE; { Alias }
  TDFEngine = TDFE; { Alias }
  TDF = TDFE; { Alias }
  TDataFrame = TDFE; { Alias }

  {
    TDF_Base is the abstract base class for all data frames.
    Each frame has a unique ID byte that identifies its data type.
    Derived classes implement serialization, JSON conversion, and size computation.
  }
  TDF_Base = class(TCore_Object)
  protected
    FID: Byte; { Type identifier for this frame }
  public
    constructor Create(ID: Byte);
    destructor Destroy; override;

    { Loads the frame's data from a binary stream }
    procedure LoadFromStream(stream: TCore_Stream); virtual; abstract;

    { Writes the frame's data to a binary stream }
    procedure SaveToStream(stream: TCore_Stream); virtual; abstract;

    { Loads the frame's data from a JSON array (at index index_) }
    procedure LoadFromJson(jarry: TZ_JsonArray; index_: Integer); virtual; abstract;

    { Saves the frame's data to a JSON array (appends a new element) }
    procedure SaveToJson(jarry: TZ_JsonArray; index_: Integer); virtual; abstract;

    { Computes the exact size (in bytes) that this frame will occupy when serialized }
    function ComputeEncodeSize: Int64; virtual; abstract;
  end;

  { Concrete frame types for various data kinds }
  TDF_String = class sealed(TDF_Base) { UTF-8 string }
  public
    Buffer: TBytes; { Raw UTF-8 bytes }
    constructor Create(ID: Byte);
    destructor Destroy; override;
    procedure LoadFromStream(stream: TCore_Stream); override;
    procedure SaveToStream(stream: TCore_Stream); override;
    procedure LoadFromJson(jarry: TZ_JsonArray; index_: Integer); override;
    procedure SaveToJson(jarry: TZ_JsonArray; index_: Integer); override;
    function ComputeEncodeSize: Int64; override;
  end;

  TDF_Integer = class sealed(TDF_Base) { 32-bit signed integer }
  protected
    FBuffer: Integer;
  public
    constructor Create(ID: Byte);
    destructor Destroy; override;
    procedure LoadFromStream(stream: TCore_Stream); override;
    procedure SaveToStream(stream: TCore_Stream); override;
    procedure LoadFromJson(jarry: TZ_JsonArray; index_: Integer); override;
    procedure SaveToJson(jarry: TZ_JsonArray; index_: Integer); override;
    function ComputeEncodeSize: Int64; override;
    property Buffer: Integer read FBuffer write FBuffer;
  end;

  TDF_Cardinal = class sealed(TDF_Base) { 32-bit unsigned integer }
  protected
    FBuffer: Cardinal;
  public
    constructor Create(ID: Byte);
    destructor Destroy; override;
    procedure LoadFromStream(stream: TCore_Stream); override;
    procedure SaveToStream(stream: TCore_Stream); override;
    procedure LoadFromJson(jarry: TZ_JsonArray; index_: Integer); override;
    procedure SaveToJson(jarry: TZ_JsonArray; index_: Integer); override;
    function ComputeEncodeSize: Int64; override;
    property Buffer: Cardinal read FBuffer write FBuffer;
  end;

  TDF_Word = class sealed(TDF_Base) { 16-bit unsigned integer }
  protected
    FBuffer: Word;
  public
    constructor Create(ID: Byte);
    destructor Destroy; override;
    procedure LoadFromStream(stream: TCore_Stream); override;
    procedure SaveToStream(stream: TCore_Stream); override;
    procedure LoadFromJson(jarry: TZ_JsonArray; index_: Integer); override;
    procedure SaveToJson(jarry: TZ_JsonArray; index_: Integer); override;
    function ComputeEncodeSize: Int64; override;
    property Buffer: Word read FBuffer write FBuffer;
  end;

  TDF_Byte = class sealed(TDF_Base) { 8-bit unsigned integer }
  protected
    FBuffer: Byte;
  public
    constructor Create(ID: Byte);
    destructor Destroy; override;
    procedure LoadFromStream(stream: TCore_Stream); override;
    procedure SaveToStream(stream: TCore_Stream); override;
    procedure LoadFromJson(jarry: TZ_JsonArray; index_: Integer); override;
    procedure SaveToJson(jarry: TZ_JsonArray; index_: Integer); override;
    function ComputeEncodeSize: Int64; override;
    property Buffer: Byte read FBuffer write FBuffer;
  end;

  TDF_Single = class sealed(TDF_Base) { 32-bit floating point }
  protected
    FBuffer: Single;
  public
    constructor Create(ID: Byte);
    destructor Destroy; override;
    procedure LoadFromStream(stream: TCore_Stream); override;
    procedure SaveToStream(stream: TCore_Stream); override;
    procedure LoadFromJson(jarry: TZ_JsonArray; index_: Integer); override;
    procedure SaveToJson(jarry: TZ_JsonArray; index_: Integer); override;
    function ComputeEncodeSize: Int64; override;
    property Buffer: Single read FBuffer write FBuffer;
  end;

  TDF_Double = class sealed(TDF_Base) { 64-bit floating point }
  protected
    FBuffer: Double;
  public
    constructor Create(ID: Byte);
    destructor Destroy; override;
    procedure LoadFromStream(stream: TCore_Stream); override;
    procedure SaveToStream(stream: TCore_Stream); override;
    procedure LoadFromJson(jarry: TZ_JsonArray; index_: Integer); override;
    procedure SaveToJson(jarry: TZ_JsonArray; index_: Integer); override;
    function ComputeEncodeSize: Int64; override;
    property Buffer: Double read FBuffer write FBuffer;
  end;

  TDF_ArrayInteger = class sealed(TDF_Base) { Dynamic array of 32-bit signed integers }
  protected
    FBuffer: TMS64; { Internal memory stream storing the array }
  public
    constructor Create(ID: Byte);
    destructor Destroy; override;
    procedure Clear;
    procedure Add(v: Integer);
    function Count: Integer;
    procedure WriteArray(const arry_: array of Integer);
    procedure LoadFromStream(stream: TCore_Stream); override;
    procedure SaveToStream(stream: TCore_Stream); override;
    procedure LoadFromJson(jarry: TZ_JsonArray; index_: Integer); override;
    procedure SaveToJson(jarry: TZ_JsonArray; index_: Integer); override;
    function ComputeEncodeSize: Int64; override;
    function GetBuffer(index_: Integer): Integer;
    procedure SetBuffer(index_: Integer; Value: Integer);
    property Buffer[index_: Integer]: Integer read GetBuffer write SetBuffer; default;
    property Buffer__: TMS64 read FBuffer;
  end;

  TDF_ArrayShortInt = class sealed(TDF_Base) { Dynamic array of 8-bit signed integers }
  protected
    FBuffer: TMS64;
  public
    constructor Create(ID: ShortInt);
    destructor Destroy; override;
    procedure Clear;
    procedure Add(v: ShortInt);
    function Count: Integer;
    procedure WriteArray(const arry_: array of ShortInt);
    procedure LoadFromStream(stream: TCore_Stream); override;
    procedure SaveToStream(stream: TCore_Stream); override;
    procedure LoadFromJson(jarry: TZ_JsonArray; index_: Integer); override;
    procedure SaveToJson(jarry: TZ_JsonArray; index_: Integer); override;
    function ComputeEncodeSize: Int64; override;
    function GetBuffer(index_: Integer): ShortInt;
    procedure SetBuffer(index_: Integer; Value: ShortInt);
    property Buffer[index_: Integer]: ShortInt read GetBuffer write SetBuffer; default;
    property Buffer__: TMS64 read FBuffer;
  end;

  TDF_ArrayByte = class sealed(TDF_Base) { Dynamic byte array (raw binary) }
  protected
    FBuffer: TMS64;
  public
    constructor Create(ID: Byte);
    destructor Destroy; override;
    procedure Clear;
    procedure Add(v: Byte);
    procedure AddPtrBuff(p: PByte; Size_: Integer);
    procedure AddI64(v: Int64);
    procedure AddU64(v: UInt64);
    procedure Addi(v: Integer);
    procedure AddWord(v: Word);
    function Count: Int64;
    property Size: Int64 read Count;
    procedure WriteArray(const arry_: array of Byte);
    procedure SetArray(const arry_: array of Byte);
    procedure SetBuff(p: PByte; Size_: Integer);
    procedure GetBuff(p: PByte);
    procedure LoadFromStream(stream: TCore_Stream); override;
    procedure SaveToStream(stream: TCore_Stream); override;
    procedure LoadFromJson(jarry: TZ_JsonArray; index_: Integer); override;
    procedure SaveToJson(jarry: TZ_JsonArray; index_: Integer); override;
    function ComputeEncodeSize: Int64; override;
    function GetBuffer(index_: Integer): Byte;
    procedure SetBuffer(index_: Integer; Value: Byte);
    property Buffer[index_: Integer]: Byte read GetBuffer write SetBuffer; default;
    property Buffer__: TMS64 read FBuffer;
  end;

  TDF_ArraySingle = class sealed(TDF_Base) { Dynamic array of 32-bit floats }
  protected
    FBuffer: TMS64;
  public
    constructor Create(ID: Byte);
    destructor Destroy; override;
    procedure Clear;
    procedure Add(v: Single);
    function Count: Integer;
    procedure WriteArray(const arry_: array of Single);
    procedure LoadFromStream(stream: TCore_Stream); override;
    procedure SaveToStream(stream: TCore_Stream); override;
    procedure LoadFromJson(jarry: TZ_JsonArray; index_: Integer); override;
    procedure SaveToJson(jarry: TZ_JsonArray; index_: Integer); override;
    function ComputeEncodeSize: Int64; override;
    function GetBuffer(index_: Integer): Single;
    procedure SetBuffer(index_: Integer; Value: Single);
    property Buffer[index_: Integer]: Single read GetBuffer write SetBuffer; default;
    property Buffer__: TMS64 read FBuffer;
  end;

  TDF_ArrayDouble = class sealed(TDF_Base) { Dynamic array of 64-bit floats }
  protected
    FBuffer: TMS64;
  public
    constructor Create(ID: Byte);
    destructor Destroy; override;
    procedure Clear;
    procedure Add(v: Double);
    function Count: Integer;
    procedure WriteArray(const arry_: array of Double);
    procedure LoadFromStream(stream: TCore_Stream); override;
    procedure SaveToStream(stream: TCore_Stream); override;
    procedure LoadFromJson(jarry: TZ_JsonArray; index_: Integer); override;
    procedure SaveToJson(jarry: TZ_JsonArray; index_: Integer); override;
    function ComputeEncodeSize: Int64; override;
    function GetBuffer(index_: Integer): Double;
    procedure SetBuffer(index_: Integer; Value: Double);
    property Buffer[index_: Integer]: Double read GetBuffer write SetBuffer; default;
    property Buffer__: TMS64 read FBuffer;
  end;

  TDF_ArrayInt64 = class sealed(TDF_Base) { Dynamic array of 64-bit signed integers }
  protected
    FBuffer: TMS64;
  public
    constructor Create(ID: Byte);
    destructor Destroy; override;
    procedure Clear;
    procedure Add(v: Int64);
    function Count: Integer;
    procedure WriteArray(const arry_: array of Int64);
    procedure LoadFromStream(stream: TCore_Stream); override;
    procedure SaveToStream(stream: TCore_Stream); override;
    procedure LoadFromJson(jarry: TZ_JsonArray; index_: Integer); override;
    procedure SaveToJson(jarry: TZ_JsonArray; index_: Integer); override;
    function ComputeEncodeSize: Int64; override;
    function GetBuffer(index_: Integer): Int64;
    procedure SetBuffer(index_: Integer; Value: Int64);
    property Buffer[index_: Integer]: Int64 read GetBuffer write SetBuffer; default;
    property Buffer__: TMS64 read FBuffer;
  end;

  TDF_ArrayInt128 = class sealed(TDF_Base) { Dynamic array of 128-bit signed integers }
  protected
    FBuffer: TMS64;
  public
    constructor Create(ID: Byte);
    destructor Destroy; override;
    procedure Clear;
    procedure Add(v: Int128);
    function Count: Integer;
    procedure WriteArray(const arry_: array of Int128);
    procedure LoadFromStream(stream: TCore_Stream); override;
    procedure SaveToStream(stream: TCore_Stream); override;
    procedure LoadFromJson(jarry: TZ_JsonArray; index_: Integer); override;
    procedure SaveToJson(jarry: TZ_JsonArray; index_: Integer); override;
    function ComputeEncodeSize: Int64; override;
    function GetBuffer(index_: Integer): Int128;
    procedure SetBuffer(index_: Integer; Value: Int128);
    property Buffer[index_: Integer]: Int128 read GetBuffer write SetBuffer; default;
    property Buffer__: TMS64 read FBuffer;
  end;

  TDF_Stream = class sealed(TDF_Base) { Arbitrary binary stream (raw bytes) }
  protected
    FBuffer: TMS64; { Internal memory stream }
  public
    constructor Create(ID: Byte);
    destructor Destroy; override;
    procedure Clear;
    procedure LoadFromStream(stream: TCore_Stream); override;
    procedure SaveToStream(stream: TCore_Stream); override;
    procedure LoadFromJson(jarry: TZ_JsonArray; index_: Integer); override;
    procedure SaveToJson(jarry: TZ_JsonArray; index_: Integer); override;
    function ComputeEncodeSize: Int64; override;
    function GetBuffer: TCore_Stream;
    procedure SetBuffer(Value_: TCore_Stream);
    property Buffer: TCore_Stream read GetBuffer write SetBuffer;
    property Buffer64: TMS64 read FBuffer;
  end;

  TDF_Variant = class sealed(TDF_Base) { Delphi/FPC Variant type }
  protected
    FBuffer: Variant;
  public
    constructor Create(ID: Byte);
    destructor Destroy; override;
    procedure LoadFromStream(stream: TCore_Stream); override;
    procedure SaveToStream(stream: TCore_Stream); override;
    procedure LoadFromJson(jarry: TZ_JsonArray; index_: Integer); override;
    procedure SaveToJson(jarry: TZ_JsonArray; index_: Integer); override;
    function ComputeEncodeSize: Int64; override;
    property Buffer: Variant read FBuffer write FBuffer;
  end;

  TDF_Int64 = class sealed(TDF_Base) { 64-bit signed integer }
  protected
    FBuffer: Int64;
  public
    constructor Create(ID: Byte);
    destructor Destroy; override;
    procedure LoadFromStream(stream: TCore_Stream); override;
    procedure SaveToStream(stream: TCore_Stream); override;
    procedure LoadFromJson(jarry: TZ_JsonArray; index_: Integer); override;
    procedure SaveToJson(jarry: TZ_JsonArray; index_: Integer); override;
    function ComputeEncodeSize: Int64; override;
    property Buffer: Int64 read FBuffer write FBuffer;
  end;

  TDF_UInt64 = class sealed(TDF_Base) { 64-bit unsigned integer }
  protected
    FBuffer: UInt64;
  public
    constructor Create(ID: Byte);
    destructor Destroy; override;
    procedure LoadFromStream(stream: TCore_Stream); override;
    procedure SaveToStream(stream: TCore_Stream); override;
    procedure LoadFromJson(jarry: TZ_JsonArray; index_: Integer); override;
    procedure SaveToJson(jarry: TZ_JsonArray; index_: Integer); override;
    function ComputeEncodeSize: Int64; override;
    property Buffer: UInt64 read FBuffer write FBuffer;
  end;

  TDF_Int128 = class sealed(TDF_Base) { 128-bit signed integer }
  protected
    FBuffer: Int128;
  public
    constructor Create(ID: Byte);
    destructor Destroy; override;
    procedure LoadFromStream(stream: TCore_Stream); override;
    procedure SaveToStream(stream: TCore_Stream); override;
    procedure LoadFromJson(jarry: TZ_JsonArray; index_: Integer); override;
    procedure SaveToJson(jarry: TZ_JsonArray; index_: Integer); override;
    function ComputeEncodeSize: Int64; override;
    property Buffer: Int128 read FBuffer write FBuffer;
  end;

  TDF_UInt128 = class sealed(TDF_Base) { 128-bit unsigned integer }
  protected
    FBuffer: UInt128;
  public
    constructor Create(ID: Byte);
    destructor Destroy; override;
    procedure LoadFromStream(stream: TCore_Stream); override;
    procedure SaveToStream(stream: TCore_Stream); override;
    procedure LoadFromJson(jarry: TZ_JsonArray; index_: Integer); override;
    procedure SaveToJson(jarry: TZ_JsonArray; index_: Integer); override;
    function ComputeEncodeSize: Int64; override;
    property Buffer: UInt128 read FBuffer write FBuffer;
  end;

  {
    TDFE_Reader is a sequential reader for a TDFE instance.
    It maintains an internal index and provides methods to read each frame
    in order, automatically advancing the index.
  }
  TDFE_Reader = class sealed(TCore_Object)
  private
    FOwner: TDFE;
    FIndex: Integer;
  public
    constructor Create(Owner_: TDFE);
    destructor Destroy; override;
    property Index: Integer read FIndex write FIndex;
    property Owner: TDFE read FOwner;

    { Checks if the reader has reached the end of the frame list }
    function IsEnd: Boolean;
    function NotEnd: Boolean;

    { Advances the internal index to the next frame }
    procedure Next;
    procedure GoNext; { Alias }

    { Read methods: each reads the current frame's data and then advances. }
    function ReadString: SystemString;
    function ReadInteger: Integer;
    function ReadCardinal: Cardinal;
    function ReadWord: Word;
    function ReadBool: Boolean;
    function ReadBoolean: Boolean;
    function ReadByte: Byte;
    function ReadSingle: Single;
    function ReadDouble: Double;
    function ReadArrayInteger: TDF_ArrayInteger;
    function ReadArrayShortInt: TDF_ArrayShortInt;
    function ReadArrayByte: TDF_ArrayByte;
    function ReadMD5: TMD5;
    function ReadArraySingle: TDF_ArraySingle;
    function ReadArrayDouble: TDF_ArrayDouble;
    function ReadArrayInt64: TDF_ArrayInt64;
    procedure ReadMem64(output: TMem64);
    procedure ReadMem64_As_Mapping(output: TMem64);
    procedure ReadMS64_As_Mapping(output: TMS64);
    procedure ReadStream(output: TCore_Stream);
    function ReadVariant: Variant;
    function ReadInt64: Int64;
    function ReadUInt64: UInt64;
    function ReadArrayInt128: TDF_ArrayInt128;
    function ReadInt128: Int128;
    function ReadUInt128: UInt128;
    procedure ReadStrings(output: TCore_Strings);
    procedure ReadListStrings(output: TListString);
    procedure ReadPascalStrings(output: TPascalStringList); overload;
    procedure ReadPascalStrings(var output: U_StringArray); overload;
    procedure ReadDataFrame(output: TDFE);
    procedure ReadDF(output: TDFE); { Alias }
    procedure ReadDFE(output: TDFE); { Alias }
    procedure ReadHashStringList(output: THashStringList);
    procedure ReadVariantList(output: THashVariantList);
    procedure ReadJson(output: TZ_JsonObject); overload;
{$IFDEF DELPHI} procedure ReadJson(output: TJsonObject); overload; {$ENDIF DELPHI}
    function ReadRect: TRect;
    function ReadRectf: TRectf;
    function ReadPoint: TPoint;
    function ReadPointf: TPointf;
    function ReadVector: TVector;
    function ReadAffineVector: TAffineVector;
    function ReadVec3: TVec3;
    function ReadVec4: TVec4;
    function ReadVector3: TVector3;
    function ReadVector4: TVector4;
    function ReadMat4: TMat4;
    function ReadMatrix4: TMatrix4;
    function Read2DPoint: T2DPoint;
    function ReadVec2: TVec2;
    function ReadRectV2: TRectV2;
    function ReadPointer: UInt64;
    function ReadPtr: UInt64;
    procedure Read(var Buf_; Count_: Int64); overload;
    procedure ReadNM(output: TNumberModule);
    procedure ReadNMPool(output: TNumberModulePool);
    procedure ReadOpCode(output: TOpCode);
    procedure ReadSectionText(output: THashTextEngine);
    procedure ReadTextSection(output: THashTextEngine);
    function Read: TDF_Base; overload; { Returns the current frame as TDF_Base }
    function Current: TDF_Base; { Returns current frame without advancing }
  end;

  { Runtime data type enumeration for frame IDs }
  TRunTimeDataType = (
    rdtString, rdtInteger, rdtLongWord, rdtWORD, rdtByte, rdtSingle, rdtDouble,
    rdtArrayInteger, rdtArraySingle, rdtArrayDouble, rdtStream, rdtVariant,
    rdtInt64, rdtArrayShortInt, rdtCardinal, rdtUInt64, rdtArrayByte,
    rdtArrayInt64,
    rdtArrayInt128, rdtInt128, rdtUInt128
    );

  { Internal list of TDF_Base frames }
  TDFE_DataList_ = class(TGenericsList<TDF_Base>);

  { Extended list with owner reference and helper methods }
  TDFE_DataList = class(TDFE_DataList_)
  public
    Owner: TDFE;
    function Add_DFBase(Data_: TDF_Base): TDF_Base;
    procedure Clear;
  end;

  {
    TDFE (Data Frame Engine) is the main container and manipulator.
    It holds a list of data frames and provides methods to:
    - Write/read individual frames (WriteString, ReadInteger, etc.)
    - Encode/decode to/from binary streams (with compression/encryption)
    - Convert to/from JSON
    - Compute MD5, compare, clone, append, delete, etc.
    - Load/save from/to files.
  }
  TDFE = class(TCore_Object)
  private
    FBit_64_Condition: Int64; { Threshold: if encoded size > this, use 64-bit header }
    FDataList: TDFE_DataList; { The actual frame list }
    FReader: TDFE_Reader; { Built-in reader for sequential access }
    FCompressorDeflate: TCompressorDeflate; { Reusable Deflate compressor }
    FCompressorBRRC: TCompressorBRRC; { Reusable BRRC compressor }
    FIsChanged: Boolean; { Dirty flag for changes }
    function DataTypeToByte(v: TRunTimeDataType): Byte;
    function ByteToDataType(v: Byte): TRunTimeDataType;
  public
    constructor Create;
    destructor Destroy; override;
    function DelayFree: TDFE; { Schedules the instance for delayed destruction }

    property Reader: TDFE_Reader read FReader;
    property R: TDFE_Reader read FReader;
    property IsChanged: Boolean read FIsChanged write FIsChanged;

    { When encoding, if total size exceeds FBit_64_Condition, use 64-bit header }
    property Bit_64_Condition: Int64 read FBit_64_Condition write FBit_64_Condition;

    { Efficiently swaps the entire contents with another TDFE instance }
    procedure SwapInstance(source: TDFE);

    { Clears all frames }
    procedure Clear;

    { Adds a new empty frame of a given type; returns the frame }
    function AddData(v: TRunTimeDataType): TDF_Base;

    { Accesses a frame by index }
    function GetData(index_: Integer): TDF_Base;
    function GetDataInfo(Obj_: TDF_Base): SystemString;
    function Count: Integer;
    function Delete(index_: Integer): Boolean;
    function DeleteFirst: Boolean;
    function DeleteLast: Boolean; overload;
    function DeleteLastCount(num_: Integer): Boolean; overload;
    function DeleteCount(index_, Count_: Integer): Boolean;

    { Appends all frames from source to self (deep copy) }
    function Append(source: TDFE): TDFE;

    { Copies all frames from source to self (replaces current content) }
    function Assign(source: TDFE): TDFE;

    { Creates a deep copy of this DFE }
    function NewClone: TDFE;

    { ---------- Write methods ---------- }
    { Each method appends a new frame of the appropriate type and sets its value. }
    function WriteString(v: SystemString): TDFE; overload;
    function WriteString(v: TPascalString): TDFE; overload;
    function WriteString(v: TUPascalString): TDFE; overload;
    function WriteString(const Fmt: SystemString; const Args: array of const): TDFE; overload;
    function WriteInteger(v: Integer): TDFE;
    function WriteCardinal(v: Cardinal): TDFE;
    function WriteWORD(v: Word): TDFE;
    function WriteBool(v: Boolean): TDFE;
    function WriteBoolean(v: Boolean): TDFE;
    function WriteByte(v: Byte): TDFE;
    function WriteSingle(v: Single): TDFE;
    function WriteDouble(v: Double): TDFE;
    function WriteArrayInteger: TDF_ArrayInteger; { Returns frame; caller adds elements }
    function WriteArrayShortInt: TDF_ArrayShortInt;
    function WriteArrayByte: TDF_ArrayByte;
    function WriteMD5(md5: TMD5): TDFE;
    function WriteArraySingle: TDF_ArraySingle;
    function WriteArrayDouble: TDF_ArrayDouble;
    function WriteArrayInt64: TDF_ArrayInt64;
    function WriteMem64(v: TMem64): TDFE;
    function WriteStream(v: TCore_Stream): TDFE; overload;
    function WriteStream(v: TMS64; bPos_, Size_: Int64): TDFE; overload;
    function WriteVariant(v: Variant): TDFE;
    function WriteInt64(v: Int64): TDFE;
    function WriteUInt64(v: UInt64): TDFE;
    function WriteArrayInt128: TDF_ArrayInt128;
    function WriteInt128(v: Int128): TDFE;
    function WriteUInt128(v: UInt128): TDFE;
    function WriteStrings(v: TCore_Strings): TDFE;
    function WriteListStrings(v: TListString): TDFE;
    function WritePascalStrings(v: TPascalStringList): TDFE; overload;
    function WritePascalStrings(v: U_StringArray): TDFE; overload;
    function WriteDataFrame(v: TDFE): TDFE; { Nests another DFE as a binary stream }
    function WriteDataFrameCompressed(v: TDFE): TDFE; { Nests compressed DFE }
    function WriteDataFrameZLib(v: TDFE): TDFE; { Nests ZLib-compressed DFE }
    function WriteDF(v: TDFE): TDFE; { Alias }
    function WriteDFE(v: TDFE): TDFE; { Alias }
    function WriteHashStringList(v: THashStringList): TDFE;
    function WriteVariantList(v: THashVariantList): TDFE;
    function WriteJson(v: TZ_JsonObject): TDFE; overload;
    function WriteJson(v: TZ_JsonObject; Formated_: Boolean): TDFE; overload;
{$IFDEF DELPHI} function WriteJson(v: TJsonObject): TDFE; overload; {$ENDIF DELPHI}
    function WriteFile(fn: SystemString): TDFE; { Reads file and writes its content as stream }
    function WriteRect(v: TRect): TDFE;
    function WriteRectf(v: TRectf): TDFE;
    function WritePoint(v: TPoint): TDFE;
    function WritePointf(v: TPointf): TDFE;
    function WriteVector(v: TVector): TDFE;
    function WriteAffineVector(v: TAffineVector): TDFE;
    function WriteVec4(v: TVec4): TDFE;
    function WriteVec3(v: TVec3): TDFE;
    function WriteVector4(v: TVector4): TDFE;
    function WriteVector3(v: TVector3): TDFE;
    function WriteMat4(v: TMat4): TDFE;
    function WriteMatrix4(v: TMatrix4): TDFE;
    function Write2DPoint(v: T2DPoint): TDFE;
    function WriteVec2(v: TVec2): TDFE;
    function WriteRectV2(v: TRectV2): TDFE;
    function WritePointer(v: Pointer): TDFE; overload;
    function WritePointer(v: UInt64): TDFE; overload;
    function WritePtr(v: Pointer): TDFE; overload;
    function WritePtr(v: UInt64): TDFE; overload;
    function write(const Buf_; Count_: Int64): TDFE; { Writes raw binary data as stream }
    function WriteNM(NM: TNumberModule): TDFE;
    function WriteNMPool(NMPool: TNumberModulePool): TDFE;
    function WriteOpCode(v: TOpCode): TDFE;
    function WriteSectionText(v: THashTextEngine): TDFE;
    function WriteTextSection(v: THashTextEngine): TDFE;

    { ---------- Read methods (indexed access) ---------- }
    { These read a specific frame by index and return its value. }
    function ReadString(index_: Integer): SystemString;
    function ReadInteger(index_: Integer): Integer;
    function ReadCardinal(index_: Integer): Cardinal;
    function ReadWord(index_: Integer): Word;
    function ReadBool(index_: Integer): Boolean;
    function ReadBoolean(index_: Integer): Boolean;
    function ReadByte(index_: Integer): Byte;
    function ReadSingle(index_: Integer): Single;
    function ReadDouble(index_: Integer): Double;
    function ReadArrayInteger(index_: Integer): TDF_ArrayInteger;
    function ReadArrayShortInt(index_: Integer): TDF_ArrayShortInt;
    function ReadArrayByte(index_: Integer): TDF_ArrayByte;
    function ReadMD5(index_: Integer): TMD5;
    function ReadArraySingle(index_: Integer): TDF_ArraySingle;
    function ReadArrayDouble(index_: Integer): TDF_ArrayDouble;
    function ReadArrayInt64(index_: Integer): TDF_ArrayInt64;
    procedure ReadMem64(index_: Integer; output: TMem64);
    procedure ReadMem64_As_Mapping(index_: Integer; output: TMem64);
    procedure ReadMS64_As_Mapping(index_: Integer; output: TMS64);
    procedure ReadStream(index_: Integer; output: TCore_Stream);
    function ReadVariant(index_: Integer): Variant;
    function ReadInt64(index_: Integer): Int64;
    function ReadUInt64(index_: Integer): UInt64;
    function ReadArrayInt128(index_: Integer): TDF_ArrayInt128;
    function ReadInt128(index_: Integer): Int128;
    function ReadUInt128(index_: Integer): UInt128;
    procedure ReadStrings(index_: Integer; output: TCore_Strings);
    procedure ReadListStrings(index_: Integer; output: TListString);
    procedure ReadPascalStrings(index_: Integer; output: TPascalStringList); overload;
    procedure ReadPascalStrings(index_: Integer; var output: U_StringArray); overload;
    procedure ReadDataFrame(index_: Integer; output: TDFE);
    procedure ReadDF(index_: Integer; output: TDFE);
    procedure ReadDFE(index_: Integer; output: TDFE);
    procedure ReadHashStringList(index_: Integer; output: THashStringList);
    procedure ReadVariantList(index_: Integer; output: THashVariantList);
    procedure ReadJson(index_: Integer; output: TZ_JsonObject); overload;
{$IFDEF DELPHI} procedure ReadJson(index_: Integer; output: TJsonObject); overload; {$ENDIF DELPHI}
    function ReadRect(index_: Integer): TRect;
    function ReadRectf(index_: Integer): TRectf;
    function ReadPoint(index_: Integer): TPoint;
    function ReadPointf(index_: Integer): TPointf;
    function ReadVector(index_: Integer): TVector;
    function ReadAffineVector(index_: Integer): TAffineVector;
    function ReadVec3(index_: Integer): TVec3;
    function ReadVec4(index_: Integer): TVec4;
    function ReadVector3(index_: Integer): TVector3;
    function ReadVector4(index_: Integer): TVector4;
    function ReadMat4(index_: Integer): TMat4;
    function ReadMatrix4(index_: Integer): TMatrix4;
    function Read2DPoint(index_: Integer): T2DPoint;
    function ReadVec2(index_: Integer): TVec2;
    function ReadRectV2(index_: Integer): TRectV2;
    function ReadPointer(index_: Integer): UInt64;
    function ReadPtr(index_: Integer): UInt64;
    procedure Read(index_: Integer; var Buf_; Count_: Int64); overload;
    procedure ReadNM(index_: Integer; output: TNumberModule);
    procedure ReadNMPool(index_: Integer; output: TNumberModulePool);
    procedure ReadOpCode(index_: Integer; output: TOpCode);
    procedure ReadSectionText(index_: Integer; output: THashTextEngine);
    procedure ReadTextSection(index_: Integer; output: THashTextEngine);
    function Read(index_: Integer): TDF_Base; overload; { Returns the frame as TDF_Base }

    { ---------- Encoding / Decoding ---------- }
    { Computes the total serialized size of all frames }
    function ComputeEncodeSize: Int64;

    { Creates an empty DFE stream (header with zero frames) }
    class procedure BuildEmptyStream(output: TCore_Stream);

    { Fast encoding: writes directly without MD5 checks; uses 32/64-bit header based on size }
    function FastEncode32To(output: TCore_Stream; SizeInfo32: Cardinal): Integer;
    function FastEncode64To(output: TCore_Stream; SizeInfo64: Int64): Integer;
    function FastEncodeTo(output: TCore_Stream): Integer;

    { Full encoding with optional compression and MD5 }
    function EncodeTo(output: TCore_Stream; const FastMode, AutoCompressed: Boolean): Integer; overload;
    function EncodeTo(output: TCore_Stream; const FastMode: Boolean): Integer; overload;
    function EncodeTo(output: TCore_Stream): Integer; overload;

    { Encryption support (Quantum Cryptography) }
    procedure Encrypt(output: TCore_Stream; Compressed_: Boolean; SecurityLevel: Integer; Key: TCipherKeyBuffer);
    function Decrypt(input: TCore_Stream; Key: TCipherKeyBuffer): Boolean;

    { JSON export/import }
    procedure EncodeAsPublicJson(var output: TPascalString); overload; { Human-readable JSON }
    procedure EncodeAsPublicJson(output: TCore_Stream); overload;
    procedure EncodeAsJson(output: TCore_Stream); overload; { Compact JSON with data arrays }
    procedure EncodeAsJson(Json: TZ_JsonObject); overload;
    procedure DecodeFromJson(stream: TCore_Stream); overload;
    procedure DecodeFromJson(const s: TPascalString); overload;
    procedure DecodeFromJson(Json: TZ_JsonObject); overload;

    { Compression methods }
    function EncodeAsSelectCompressor(scm: TSelectCompressionMethod; output: TCore_Stream; const FastMode: Boolean): Integer; overload;
    function EncodeAsSelectCompressor(output: TCore_Stream; const FastMode: Boolean): Integer; overload;
    function EncodeAsSelectCompressor(output: TCore_Stream): Integer; overload;
    function EncodeAsZLib(output: TCore_Stream; const FastMode, AutoCompressed: Boolean): Integer; overload;
    function EncodeAsZLib(output: TCore_Stream; const FastMode: Boolean): Integer; overload;
    function EncodeAsZLib(output: TCore_Stream): Integer; overload;
    function EncodeAsDeflate(output: TCore_Stream; const FastMode, AutoCompressed: Boolean): Integer; overload;
    function EncodeAsDeflate(output: TCore_Stream; const FastMode: Boolean): Integer; overload;
    function EncodeAsDeflate(output: TCore_Stream): Integer; overload;
    function EncodeAsBRRC(output: TCore_Stream; const FastMode, AutoCompressed: Boolean): Integer; overload;
    function EncodeAsBRRC(output: TCore_Stream; const FastMode: Boolean): Integer; overload;
    function EncodeAsBRRC(output: TCore_Stream): Integer; overload;
    function EncodeAsLZ4(output: TCore_Stream; const FastMode: Boolean): Integer; overload;
    function EncodeAsLZ4(output: TCore_Stream): Integer; overload;
    function EncodeAsSnappy(output: TCore_Stream; const FastMode: Boolean): Integer; overload;
    function EncodeAsSnappy(output: TCore_Stream): Integer; overload;

    { Checks if a stream contains compressed DFE data }
    function IsCompressed(source: TCore_Stream): Boolean;

    { Decoding from stream or memory }
    function DecodeFrom(source: TCore_Stream; const FastMode: Boolean; const Max_Limit_Decode: Integer): Integer; overload;
    function DecodeFrom(source: TCore_Stream; const FastMode: Boolean): Integer; overload;
    function DecodeFrom(source: TCore_Stream): Integer; overload;
    function DecodeFromMemory(memory_: Pointer; mSize: Int64; const FastMode: Boolean): Integer; overload;
    function DecodeFromMemory(memory_: Pointer; mSize: Int64): Integer; overload;
    function DecodeFromMemory(stream: TMS64; const FastMode: Boolean): Integer; overload;
    function DecodeFromMemory(stream: TMem64; const FastMode: Boolean): Integer; overload;

    { Convert to/from raw bytes (with optional compression) }
    procedure EncodeToBytes(const Compressed, FastMode: Boolean; var output: TBytes);
    procedure DecodeFromBytes(var buff: TBytes); overload;
    procedure DecodeFromBytes(var buff: TBytes; const FastMode: Boolean); overload;

    { MD5 calculation and comparison }
    function GetMD5(const FastMode: Boolean): TMD5;
    function Compare(source: TDFE): Boolean; { Deep compare all frames }

    { File I/O }
    procedure LoadFromStream(stream: TCore_Stream);
    procedure SaveToStream(stream: TCore_Stream);
    procedure LoadFromFile(fileName_: U_String);
    procedure SaveToFile(fileName_: U_String);

    { Indexed access to frames }
    property Data[index_: Integer]: TDF_Base read GetData; default;
    property List: TDFE_DataList read FDataList;

    { Unit test procedure }
    class procedure Test();
  end;

  {
    TDataWriter is a helper class that simplifies writing a DFE to a stream.
    It internally builds a TDFE, then writes it to the target stream on destruction.
    The stream format includes a version flag, compression flag, size, and the DFE data.
  }
  TDataWriter = class sealed(TCore_Object)
  private
    FEngine: TDFE;
    FStream: TCore_Stream;
  public
    property Engine: TDFE read FEngine;
    constructor Create(Stream_: TCore_Stream);
    destructor Destroy; override;

    procedure Clear;

    { Write methods correspond to TDFE.WriteXXX, but they write to the internal engine }
    function WriteString(v: SystemString): TDFE;
    function WriteInteger(v: Integer): TDFE;
    function WriteCardinal(v: Cardinal): TDFE;
    function WriteWORD(v: Word): TDFE;
    function WriteBool(v: Boolean): TDFE;
    function WriteBoolean(v: Boolean): TDFE;
    function WriteByte(v: Byte): TDFE;
    function WriteSingle(v: Single): TDFE;
    function WriteDouble(v: Double): TDFE;
    function WriteArrayInteger(v: array of Integer): TDFE;
    function WriteArrayShortInt(v: array of ShortInt): TDFE;
    function WriteArrayByte(v: array of Byte): TDFE;
    function WriteArraySingle(v: array of Single): TDFE;
    function WriteArrayDouble(v: array of Double): TDFE;
    function WriteArrayInt64(v: array of Int64): TDFE;
    function WriteStream(v: TCore_Stream): TDFE; overload;
    function WriteStream(v: TMS64; bPos_, Size_: Int64): TDFE; overload;
    function WriteVariant(v: Variant): TDFE;
    function WriteInt64(v: Int64): TDFE;
    function WriteUInt64(v: UInt64): TDFE;
    function WriteArrayInt128(v: array of Int128): TDFE;
    function WriteInt128(v: Int128): TDFE;
    function WriteUInt128(v: UInt128): TDFE;
    function WriteStrings(v: TCore_Strings): TDFE;
    function WriteListStrings(v: TListString): TDFE;
    function WritePascalStrings(v: TPascalStringList): TDFE; overload;
    function WritePascalStrings(v: U_StringArray): TDFE; overload;
    function WriteDataFrame(v: TDFE): TDFE;
    function WriteDataFrameCompressed(v: TDFE): TDFE;
    function WriteHashStringList(v: THashStringList): TDFE;
    function WriteVariantList(v: THashVariantList): TDFE;
    function WriteJson(v: TZ_JsonObject): TDFE; overload;
{$IFDEF DELPHI} function WriteJson(v: TJsonObject): TDFE; overload; {$ENDIF DELPHI}
    function WriteRect(v: TRect): TDFE;
    function WriteRectf(v: TRectf): TDFE;
    function WritePoint(v: TPoint): TDFE;
    function WritePointf(v: TPointf): TDFE;
    function WriteVector(v: TVector): TDFE;
    function WriteAffineVector(v: TAffineVector): TDFE;
    function WriteVec4(v: TVec4): TDFE;
    function WriteVec3(v: TVec3): TDFE;
    function WriteVector4(v: TVector4): TDFE;
    function WriteVector3(v: TVector3): TDFE;
    function WriteMat4(v: TMat4): TDFE;
    function WriteMatrix4(v: TMatrix4): TDFE;
    function Write2DPoint(v: T2DPoint): TDFE;
    function WriteVec2(v: TVec2): TDFE;
    function WriteRectV2(v: TRectV2): TDFE;
    function WritePointer(v: Pointer): TDFE;
    function write(const Buf_; Count_: Int64): TDFE;
    function WriteNM(NM: TNumberModule): TDFE;
    function WriteNMPool(NMPool: TNumberModulePool): TDFE;
    function WriteOpCode(v: TOpCode): TDFE;
    function WriteSectionText(v: THashTextEngine): TDFE;
    function WriteTextSection(v: THashTextEngine): TDFE;
  end;

  {
    TDataReader is a helper class that reads a DFE from a stream.
    It decodes the stream header and provides read methods for the frames.
  }
  TDataReader = class sealed(TCore_Object)
  private
    FEngine: TDFE;
  public
    property Engine: TDFE read FEngine;
    constructor Create(Stream_: TCore_Stream);
    destructor Destroy; override;

    { Read methods mirror those of TDFE_Reader }
    function ReadString: SystemString;
    function ReadInteger: Integer;
    function ReadCardinal: Cardinal;
    function ReadWord: Word;
    function ReadBool: Boolean;
    function ReadBoolean: Boolean;
    function ReadByte: Byte;
    function ReadSingle: Single;
    function ReadDouble: Double;
    procedure ReadArrayInteger(var Data: array of Integer);
    procedure ReadArrayShortInt(var Data: array of ShortInt);
    procedure ReadArrayByte(var Data: array of Byte);
    procedure ReadArraySingle(var Data: array of Single);
    procedure ReadArrayDouble(var Data: array of Double);
    procedure ReadArrayInt64(var Data: array of Int64);
    procedure ReadStream(output: TCore_Stream);
    function ReadVariant: Variant;
    function ReadInt64: Int64;
    function ReadUInt64: UInt64;
    procedure ReadArrayInt128(var Data: array of Int128);
    function ReadInt128: Int128;
    function ReadUInt128: UInt128;
    procedure ReadStrings(output: TCore_Strings);
    procedure ReadListStrings(output: TListString);
    procedure ReadPascalStrings(output: TPascalStringList); overload;
    procedure ReadPascalStrings(var output: U_StringArray); overload;
    procedure ReadDataFrame(output: TDFE);
    procedure ReadHashStringList(output: THashStringList);
    procedure ReadVariantList(output: THashVariantList);
    procedure ReadJson(output: TZ_JsonObject); overload;
{$IFDEF DELPHI} procedure ReadJson(output: TJsonObject); overload; {$ENDIF DELPHI}
    function ReadRect: TRect;
    function ReadRectf: TRectf;
    function ReadPoint: TPoint;
    function ReadPointf: TPointf;
    function ReadVector: TVector;
    function ReadAffineVector: TAffineVector;
    function ReadVec3: TVec3;
    function ReadVec4: TVec4;
    function ReadVector3: TVector3;
    function ReadVector4: TVector4;
    function ReadMat4: TMat4;
    function ReadMatrix4: TMatrix4;
    function Read2DPoint: T2DPoint;
    function ReadVec2: TVec2;
    function ReadRectV2: TRectV2;
    function ReadPointer: UInt64;
    procedure ReadNM(output: TNumberModule);
    procedure ReadNMPool(output: TNumberModulePool);
    procedure ReadOpCode(output: TOpCode);
    procedure ReadSectionText(output: THashTextEngine);
    procedure ReadTextSection(output: THashTextEngine);
    procedure Read(var Buf_; Count_: Int64);
  end;

{$REGION 'compatible'}

  { Legacy type aliases for backward compatibility }
  TDFString = TDF_String;
  TDFInteger = TDF_Integer;
  TDFCardinal = TDF_Cardinal;
  TDFWord = TDF_Word;
  TDFByte = TDF_Byte;
  TDFSingle = TDF_Single;
  TDFDouble = TDF_Double;
  TDFArrayInteger = TDF_ArrayInteger;
  TDFArrayShortInt = TDF_ArrayShortInt;
  TDFArrayByte = TDF_ArrayByte;
  TDFArraySingle = TDF_ArraySingle;
  TDFArrayDouble = TDF_ArrayDouble;
  TDFArrayInt64 = TDF_ArrayInt64;
  TDFArrayInt128 = TDF_ArrayInt128;
  TDFStream = TDF_Stream;
  TDFVariant = TDF_Variant;
  TDFInt64 = TDF_Int64;
  TDFUInt64 = TDF_UInt64;
  TDFInt128 = TDF_Int128;
  TDFUInt128 = TDF_UInt128;
  TDFBase = TDF_Base;
{$ENDREGION 'compatible'}

implementation

uses SysUtils, Variants, Z.Notify;

const
  // data label
  C_Bit_32 = $FF;
  C_Bit_64 = $FA;
  C_None_Compress = 0;
  C_ZLIB_32_Compress = 1;
  C_ZLIB_64_Compress = 11;
  C_Deflate_32_Compress = 2;
  C_Deflate_64_Compress = 22;
  C_BRRC_32_Compress = 3;
  C_BRRC_64_Compress = 33;
  C_Parallel_32_Compress = 4;
  C_Parallel_64_Compress = 44;
  C_SNAPPY_PAS_32_Compress = 5;
  C_SNAPPY_PAS_64_Compress = 55;
  C_LZ4_32_Compress = 6;
  C_LZ4_64_Compress = 66;

constructor TDF_Base.Create(ID: Byte);
begin
  inherited Create;
  FID := ID;
end;

destructor TDF_Base.Destroy;
begin
  inherited Destroy;
end;

constructor TDF_String.Create(ID: Byte);
begin
  inherited Create(ID);
  Buffer:=nil;
  SetLength(Buffer, 0);
end;

destructor TDF_String.Destroy;
begin
  SetLength(Buffer, 0);
  inherited Destroy;
end;

procedure TDF_String.LoadFromStream(stream: TCore_Stream);
var
  Size_: Integer;
begin
  stream.Read(Size_, C_Integer_Size);
  SetLength(Buffer, Size_);
  if (Size_ > 0) then
      stream.Read(Buffer[0], Size_);
end;

procedure TDF_String.SaveToStream(stream: TCore_Stream);
var
  Size_: Integer;
begin
  Size_ := length(Buffer);
  stream.write(Size_, C_Integer_Size);
  if Size_ > 0 then
      stream.write(Buffer[0], Size_);
end;

procedure TDF_String.LoadFromJson(jarry: TZ_JsonArray; index_: Integer);
begin
  Buffer := umlBytesOf(jarry.s[index_]);
end;

procedure TDF_String.SaveToJson(jarry: TZ_JsonArray; index_: Integer);
begin
  jarry.Add(umlStringOf(Buffer).Text);
end;

function TDF_String.ComputeEncodeSize: Int64;
begin
  Result := C_Integer_Size + length(Buffer);
end;

constructor TDF_Integer.Create(ID: Byte);
begin
  inherited Create(ID);
  Buffer := 0;
end;

destructor TDF_Integer.Destroy;
begin
  inherited Destroy;
end;

procedure TDF_Integer.LoadFromStream(stream: TCore_Stream);
begin
  stream.Read(FBuffer, C_Integer_Size);
end;

procedure TDF_Integer.SaveToStream(stream: TCore_Stream);
begin
  stream.write(FBuffer, C_Integer_Size);
end;

procedure TDF_Integer.LoadFromJson(jarry: TZ_JsonArray; index_: Integer);
begin
  FBuffer := jarry.i[index_];
end;

procedure TDF_Integer.SaveToJson(jarry: TZ_JsonArray; index_: Integer);
begin
  jarry.Add(FBuffer);
end;

function TDF_Integer.ComputeEncodeSize: Int64;
begin
  Result := C_Integer_Size;
end;

constructor TDF_Cardinal.Create(ID: Byte);
begin
  inherited Create(ID);
  Buffer := 0;
end;

destructor TDF_Cardinal.Destroy;
begin
  inherited Destroy;
end;

procedure TDF_Cardinal.LoadFromStream(stream: TCore_Stream);
begin
  stream.Read(FBuffer, C_Cardinal_Size);
end;

procedure TDF_Cardinal.SaveToStream(stream: TCore_Stream);
begin
  stream.write(FBuffer, C_Cardinal_Size);
end;

procedure TDF_Cardinal.LoadFromJson(jarry: TZ_JsonArray; index_: Integer);
begin
  FBuffer := jarry.i[index_];
end;

procedure TDF_Cardinal.SaveToJson(jarry: TZ_JsonArray; index_: Integer);
begin
  jarry.Add(FBuffer);
end;

function TDF_Cardinal.ComputeEncodeSize: Int64;
begin
  Result := C_Cardinal_Size;
end;

constructor TDF_Word.Create(ID: Byte);
begin
  inherited Create(ID);
  Buffer := 0;
end;

destructor TDF_Word.Destroy;
begin
  inherited Destroy;
end;

procedure TDF_Word.LoadFromStream(stream: TCore_Stream);
begin
  stream.Read(FBuffer, C_Word_Size);
end;

procedure TDF_Word.SaveToStream(stream: TCore_Stream);
begin
  stream.write(FBuffer, C_Word_Size);
end;

procedure TDF_Word.LoadFromJson(jarry: TZ_JsonArray; index_: Integer);
begin
  FBuffer := jarry.i[index_];
end;

procedure TDF_Word.SaveToJson(jarry: TZ_JsonArray; index_: Integer);
begin
  jarry.Add(FBuffer);
end;

function TDF_Word.ComputeEncodeSize: Int64;
begin
  Result := C_Word_Size;
end;

constructor TDF_Byte.Create(ID: Byte);
begin
  inherited Create(ID);
  Buffer := 0;
end;

destructor TDF_Byte.Destroy;
begin
  inherited Destroy;
end;

procedure TDF_Byte.LoadFromStream(stream: TCore_Stream);
begin
  stream.Read(FBuffer, C_Byte_Size);
end;

procedure TDF_Byte.SaveToStream(stream: TCore_Stream);
begin
  stream.write(FBuffer, C_Byte_Size);
end;

procedure TDF_Byte.LoadFromJson(jarry: TZ_JsonArray; index_: Integer);
begin
  FBuffer := jarry.i[index_];
end;

procedure TDF_Byte.SaveToJson(jarry: TZ_JsonArray; index_: Integer);
begin
  jarry.Add(FBuffer);
end;

function TDF_Byte.ComputeEncodeSize: Int64;
begin
  Result := C_Byte_Size;
end;

constructor TDF_Single.Create(ID: Byte);
begin
  inherited Create(ID);
  Buffer := 0;
end;

destructor TDF_Single.Destroy;
begin
  inherited Destroy;
end;

procedure TDF_Single.LoadFromStream(stream: TCore_Stream);
begin
  stream.Read(FBuffer, C_Single_Size);
end;

procedure TDF_Single.SaveToStream(stream: TCore_Stream);
begin
  stream.write(FBuffer, C_Single_Size);
end;

procedure TDF_Single.LoadFromJson(jarry: TZ_JsonArray; index_: Integer);
begin
  FBuffer := jarry.f[index_];
end;

procedure TDF_Single.SaveToJson(jarry: TZ_JsonArray; index_: Integer);
begin
  jarry.AddF(FBuffer);
end;

function TDF_Single.ComputeEncodeSize: Int64;
begin
  Result := C_Single_Size;
end;

constructor TDF_Double.Create(ID: Byte);
begin
  inherited Create(ID);
  Buffer := 0;
end;

destructor TDF_Double.Destroy;
begin
  inherited Destroy;
end;

procedure TDF_Double.LoadFromStream(stream: TCore_Stream);
begin
  stream.Read(FBuffer, C_Double_Size);
end;

procedure TDF_Double.SaveToStream(stream: TCore_Stream);
begin
  stream.write(FBuffer, C_Double_Size);
end;

procedure TDF_Double.LoadFromJson(jarry: TZ_JsonArray; index_: Integer);
begin
  FBuffer := jarry.f[index_];
end;

procedure TDF_Double.SaveToJson(jarry: TZ_JsonArray; index_: Integer);
begin
  jarry.AddF(FBuffer);
end;

function TDF_Double.ComputeEncodeSize: Int64;
begin
  Result := C_Double_Size;
end;

constructor TDF_ArrayInteger.Create(ID: Byte);
begin
  inherited Create(ID);
  FBuffer := TMS64.CustomCreate(128);
end;

destructor TDF_ArrayInteger.Destroy;
begin
  Clear;
  DisposeObject(FBuffer);
  inherited Destroy;
end;

procedure TDF_ArrayInteger.Clear;
begin
  FBuffer.Clear;
end;

procedure TDF_ArrayInteger.Add(v: Integer);
begin
  FBuffer.Position := FBuffer.Size;
  FBuffer.WriteInt32(v);
end;

function TDF_ArrayInteger.Count: Integer;
begin
  Result := FBuffer.Size div C_Integer_Size;
end;

procedure TDF_ArrayInteger.WriteArray(const arry_: array of Integer);
begin
  if length(arry_) > 0 then
    begin
      FBuffer.Position := FBuffer.Size;
      FBuffer.WritePtr(@arry_[0], length(arry_) * C_Integer_Size);
    end;
end;

procedure TDF_ArrayInteger.LoadFromStream(stream: TCore_Stream);
var
  L: Integer;
begin
  Clear;
  stream.Read(L, C_Integer_Size);
  FBuffer.CopyFrom(stream, L * C_Integer_Size);
end;

procedure TDF_ArrayInteger.SaveToStream(stream: TCore_Stream);
var
  L: Integer;
begin
  L := Count;
  stream.write(L, C_Integer_Size);
  stream.write(FBuffer.Memory^, L * C_Integer_Size);
end;

procedure TDF_ArrayInteger.LoadFromJson(jarry: TZ_JsonArray; index_: Integer);
var
  ja: TZ_JsonArray;
  i: Integer;
begin
  ja := jarry.A[index_];
  for i := 0 to ja.Count - 1 do
      Add(ja.i[i]);
end;

procedure TDF_ArrayInteger.SaveToJson(jarry: TZ_JsonArray; index_: Integer);
var
  ja: TZ_JsonArray;
  i: Integer;
begin
  ja := jarry.AddArray;
  for i := 0 to Count - 1 do
      ja.Add(Buffer[i]);
end;

function TDF_ArrayInteger.ComputeEncodeSize: Int64;
begin
  Result := C_Integer_Size + C_Integer_Size * Count;
end;

function TDF_ArrayInteger.GetBuffer(index_: Integer): Integer;
begin
  Result := PInteger(FBuffer.PositionAsPtr(index_ * C_Integer_Size))^;
end;

procedure TDF_ArrayInteger.SetBuffer(index_: Integer; Value: Integer);
begin
  PInteger(FBuffer.PositionAsPtr(index_ * C_Integer_Size))^ := Value;
end;

constructor TDF_ArrayShortInt.Create(ID: ShortInt);
begin
  inherited Create(ID);
  FBuffer := TMS64.CustomCreate(128);
end;

destructor TDF_ArrayShortInt.Destroy;
begin
  Clear;
  DisposeObject(FBuffer);
  inherited Destroy;
end;

procedure TDF_ArrayShortInt.Clear;
begin
  FBuffer.Clear;
end;

procedure TDF_ArrayShortInt.Add(v: ShortInt);
begin
  FBuffer.Position := FBuffer.Size;
  FBuffer.WriteInt8(v);
end;

function TDF_ArrayShortInt.Count: Integer;
begin
  Result := FBuffer.Size;
end;

procedure TDF_ArrayShortInt.WriteArray(const arry_: array of ShortInt);
begin
  if length(arry_) > 0 then
    begin
      FBuffer.Position := FBuffer.Size;
      FBuffer.WritePtr(@arry_[0], length(arry_));
    end;
end;

procedure TDF_ArrayShortInt.LoadFromStream(stream: TCore_Stream);
var
  L: Integer;
begin
  Clear;
  stream.Read(L, C_Integer_Size);
  FBuffer.CopyFrom(stream, L);
end;

procedure TDF_ArrayShortInt.SaveToStream(stream: TCore_Stream);
var
  L: Integer;
begin
  L := Count;
  stream.write(L, C_Integer_Size);
  stream.write(FBuffer.Memory^, L);
end;

procedure TDF_ArrayShortInt.LoadFromJson(jarry: TZ_JsonArray; index_: Integer);
var
  ja: TZ_JsonArray;
  i: Integer;
begin
  ja := jarry.A[index_];
  for i := 0 to ja.Count - 1 do
      Add(ja.i[i]);
end;

procedure TDF_ArrayShortInt.SaveToJson(jarry: TZ_JsonArray; index_: Integer);
var
  ja: TZ_JsonArray;
  i: Integer;
begin
  ja := jarry.AddArray;
  for i := 0 to Count - 1 do
      ja.Add(Buffer[i]);
end;

function TDF_ArrayShortInt.ComputeEncodeSize: Int64;
begin
  Result := C_Integer_Size + C_Short_Int_Size * Count;
end;

function TDF_ArrayShortInt.GetBuffer(index_: Integer): ShortInt;
begin
  Result := PShortInt(FBuffer.PositionAsPtr(index_))^;
end;

procedure TDF_ArrayShortInt.SetBuffer(index_: Integer; Value: ShortInt);
begin
  PShortInt(FBuffer.PositionAsPtr(index_))^ := Value;
end;

constructor TDF_ArrayByte.Create(ID: Byte);
begin
  inherited Create(ID);
  FBuffer := TMS64.CustomCreate(128);
end;

destructor TDF_ArrayByte.Destroy;
begin
  Clear;
  DisposeObject(FBuffer);
  inherited Destroy;
end;

procedure TDF_ArrayByte.Clear;
begin
  FBuffer.Clear;
end;

procedure TDF_ArrayByte.Add(v: Byte);
begin
  FBuffer.Position := FBuffer.Size;
  FBuffer.WriteUInt8(v);
end;

procedure TDF_ArrayByte.AddPtrBuff(p: PByte; Size_: Integer);
begin
  FBuffer.Position := FBuffer.Size;
  FBuffer.WritePtr(p, Size_);
end;

procedure TDF_ArrayByte.AddI64(v: Int64);
begin
  AddPtrBuff(@v, C_Int64_Size);
end;

procedure TDF_ArrayByte.AddU64(v: UInt64);
begin
  AddPtrBuff(@v, C_UInt64_Size);
end;

procedure TDF_ArrayByte.Addi(v: Integer);
begin
  AddPtrBuff(@v, C_Integer_Size);
end;

procedure TDF_ArrayByte.AddWord(v: Word);
begin
  AddPtrBuff(@v, C_Word_Size);
end;

function TDF_ArrayByte.Count: Int64;
begin
  Result := FBuffer.Size;
end;

procedure TDF_ArrayByte.WriteArray(const arry_: array of Byte);
begin
  if length(arry_) > 0 then
      AddPtrBuff(@arry_[0], length(arry_));
end;

procedure TDF_ArrayByte.SetArray(const arry_: array of Byte);
begin
  Clear;
  if length(arry_) > 0 then
      AddPtrBuff(@arry_[0], length(arry_));
end;

procedure TDF_ArrayByte.SetBuff(p: PByte; Size_: Integer);
begin
  Clear;
  AddPtrBuff(p, Size_);
end;

procedure TDF_ArrayByte.GetBuff(p: PByte);
begin
  CopyPtr(FBuffer.Memory, p, FBuffer.Size);
end;

procedure TDF_ArrayByte.LoadFromStream(stream: TCore_Stream);
var
  L: Integer;
begin
  Clear;
  stream.Read(L, C_Integer_Size);
  FBuffer.CopyFrom(stream, L);
end;

procedure TDF_ArrayByte.SaveToStream(stream: TCore_Stream);
var
  L: Integer;
begin
  L := Count;
  stream.write(L, C_Integer_Size);
  stream.write(FBuffer.Memory^, L);
end;

procedure TDF_ArrayByte.LoadFromJson(jarry: TZ_JsonArray; index_: Integer);
var
  ja: TZ_JsonArray;
  i: Integer;
begin
  ja := jarry.A[index_];
  for i := 0 to ja.Count - 1 do
      Add(ja.i[i]);
end;

procedure TDF_ArrayByte.SaveToJson(jarry: TZ_JsonArray; index_: Integer);
var
  ja: TZ_JsonArray;
  i: Integer;
begin
  ja := jarry.AddArray;
  for i := 0 to Count - 1 do
      ja.Add(Buffer[i]);
end;

function TDF_ArrayByte.ComputeEncodeSize: Int64;
begin
  Result := C_Integer_Size + C_Byte_Size * Count;
end;

function TDF_ArrayByte.GetBuffer(index_: Integer): Byte;
begin
  Result := PByte(FBuffer.PositionAsPtr(index_))^;
end;

procedure TDF_ArrayByte.SetBuffer(index_: Integer; Value: Byte);
begin
  PByte(FBuffer.PositionAsPtr(index_))^ := Value;
end;

constructor TDF_ArraySingle.Create(ID: Byte);
begin
  inherited Create(ID);
  FBuffer := TMS64.CustomCreate(128);
end;

destructor TDF_ArraySingle.Destroy;
begin
  Clear;
  DisposeObject(FBuffer);
  inherited Destroy;
end;

procedure TDF_ArraySingle.Clear;
begin
  FBuffer.Clear;
end;

procedure TDF_ArraySingle.Add(v: Single);
begin
  FBuffer.Position := FBuffer.Size;
  FBuffer.WriteSingle(v);
end;

function TDF_ArraySingle.Count: Integer;
begin
  Result := FBuffer.Size div C_Single_Size;
end;

procedure TDF_ArraySingle.WriteArray(const arry_: array of Single);
begin
  if length(arry_) > 0 then
    begin
      FBuffer.Position := FBuffer.Size;
      FBuffer.WritePtr(@arry_[0], length(arry_) * C_Single_Size);
    end;
end;

procedure TDF_ArraySingle.LoadFromStream(stream: TCore_Stream);
var
  L: Integer;
begin
  Clear;
  stream.Read(L, C_Integer_Size);
  FBuffer.CopyFrom(stream, L * C_Single_Size);
end;

procedure TDF_ArraySingle.SaveToStream(stream: TCore_Stream);
var
  L: Integer;
begin
  L := Count;
  stream.write(L, C_Integer_Size);
  stream.write(FBuffer.Memory^, L * C_Single_Size);
end;

procedure TDF_ArraySingle.LoadFromJson(jarry: TZ_JsonArray; index_: Integer);
var
  ja: TZ_JsonArray;
  i: Integer;
begin
  ja := jarry.A[index_];
  for i := 0 to ja.Count - 1 do
      Add(ja.f[i]);
end;

procedure TDF_ArraySingle.SaveToJson(jarry: TZ_JsonArray; index_: Integer);
var
  ja: TZ_JsonArray;
  i: Integer;
begin
  ja := jarry.AddArray;
  for i := 0 to Count - 1 do
      ja.AddF(Buffer[i]);
end;

function TDF_ArraySingle.ComputeEncodeSize: Int64;
begin
  Result := C_Integer_Size + C_Single_Size * Count;
end;

function TDF_ArraySingle.GetBuffer(index_: Integer): Single;
begin
  Result := PSingle(FBuffer.PositionAsPtr(index_ * C_Single_Size))^;
end;

procedure TDF_ArraySingle.SetBuffer(index_: Integer; Value: Single);
begin
  PSingle(FBuffer.PositionAsPtr(index_ * C_Single_Size))^ := Value;
end;

constructor TDF_ArrayDouble.Create(ID: Byte);
begin
  inherited Create(ID);
  FBuffer := TMS64.CustomCreate($FF);
end;

destructor TDF_ArrayDouble.Destroy;
begin
  Clear;
  DisposeObject(FBuffer);
  inherited Destroy;
end;

procedure TDF_ArrayDouble.Clear;
begin
  FBuffer.Clear;
end;

procedure TDF_ArrayDouble.Add(v: Double);
begin
  FBuffer.Position := FBuffer.Size;
  FBuffer.WriteDouble(v);
end;

function TDF_ArrayDouble.Count: Integer;
begin
  Result := FBuffer.Size div C_Double_Size;
end;

procedure TDF_ArrayDouble.WriteArray(const arry_: array of Double);
begin
  if length(arry_) > 0 then
    begin
      FBuffer.Position := FBuffer.Size;
      FBuffer.WritePtr(@arry_[0], length(arry_) * C_Double_Size);
    end;
end;

procedure TDF_ArrayDouble.LoadFromStream(stream: TCore_Stream);
var
  L: Integer;
begin
  Clear;
  stream.Read(L, C_Integer_Size);
  FBuffer.CopyFrom(stream, L * C_Double_Size);
end;

procedure TDF_ArrayDouble.SaveToStream(stream: TCore_Stream);
var
  L: Integer;
begin
  L := Count;
  stream.write(L, C_Integer_Size);
  stream.write(FBuffer.Memory^, L * C_Double_Size);
end;

procedure TDF_ArrayDouble.LoadFromJson(jarry: TZ_JsonArray; index_: Integer);
var
  ja: TZ_JsonArray;
  i: Integer;
begin
  ja := jarry.A[index_];
  for i := 0 to ja.Count - 1 do
      Add(ja.f[i]);
end;

procedure TDF_ArrayDouble.SaveToJson(jarry: TZ_JsonArray; index_: Integer);
var
  ja: TZ_JsonArray;
  i: Integer;
begin
  ja := jarry.AddArray;
  for i := 0 to Count - 1 do
      ja.AddF(Buffer[i]);
end;

function TDF_ArrayDouble.ComputeEncodeSize: Int64;
begin
  Result := C_Integer_Size + C_Double_Size * Count;
end;

function TDF_ArrayDouble.GetBuffer(index_: Integer): Double;
begin
  Result := PDouble(FBuffer.PositionAsPtr(index_ * C_Double_Size))^;
end;

procedure TDF_ArrayDouble.SetBuffer(index_: Integer; Value: Double);
begin
  PDouble(FBuffer.PositionAsPtr(index_ * C_Double_Size))^ := Value;
end;

constructor TDF_ArrayInt64.Create(ID: Byte);
begin
  inherited Create(ID);
  FBuffer := TMS64.CustomCreate($FF);
end;

destructor TDF_ArrayInt64.Destroy;
begin
  Clear;
  DisposeObject(FBuffer);
  inherited Destroy;
end;

procedure TDF_ArrayInt64.Clear;
begin
  FBuffer.Clear;
end;

procedure TDF_ArrayInt64.Add(v: Int64);
begin
  FBuffer.Position := FBuffer.Size;
  FBuffer.WriteInt64(v);
end;

function TDF_ArrayInt64.Count: Integer;
begin
  Result := FBuffer.Size div C_Int64_Size;
end;

procedure TDF_ArrayInt64.WriteArray(const arry_: array of Int64);
begin
  if length(arry_) > 0 then
    begin
      FBuffer.Position := FBuffer.Size;
      FBuffer.WritePtr(@arry_[0], length(arry_) * C_Int64_Size);
    end;
end;

procedure TDF_ArrayInt64.LoadFromStream(stream: TCore_Stream);
var
  L: Integer;
begin
  Clear;
  stream.Read(L, C_Integer_Size);
  FBuffer.CopyFrom(stream, L * C_Int64_Size);
end;

procedure TDF_ArrayInt64.SaveToStream(stream: TCore_Stream);
var
  L: Integer;
begin
  L := Count;
  stream.write(L, C_Integer_Size);
  stream.write(FBuffer.Memory^, L * C_Int64_Size);
end;

procedure TDF_ArrayInt64.LoadFromJson(jarry: TZ_JsonArray; index_: Integer);
var
  ja: TZ_JsonArray;
  i: Integer;
begin
  ja := jarry.A[index_];
  for i := 0 to ja.Count - 1 do
      Add(ja.L[i]);
end;

procedure TDF_ArrayInt64.SaveToJson(jarry: TZ_JsonArray; index_: Integer);
var
  ja: TZ_JsonArray;
  i: Integer;
begin
  ja := jarry.AddArray;
  for i := 0 to Count - 1 do
      ja.Add(Buffer[i]);
end;

function TDF_ArrayInt64.ComputeEncodeSize: Int64;
begin
  Result := C_Integer_Size + C_Int64_Size * Count;
end;

function TDF_ArrayInt64.GetBuffer(index_: Integer): Int64;
begin
  Result := PInt64(FBuffer.PositionAsPtr(index_ * C_Int64_Size))^;
end;

procedure TDF_ArrayInt64.SetBuffer(index_: Integer; Value: Int64);
begin
  PInt64(FBuffer.PositionAsPtr(index_ * C_Int64_Size))^ := Value;
end;

constructor TDF_ArrayInt128.Create(ID: Byte);
begin
  inherited Create(ID);
  FBuffer := TMS64.CustomCreate($FF);
end;

destructor TDF_ArrayInt128.Destroy;
begin
  Clear;
  DisposeObject(FBuffer);
  inherited Destroy;
end;

procedure TDF_ArrayInt128.Clear;
begin
  FBuffer.Clear;
end;

procedure TDF_ArrayInt128.Add(v: Int128);
begin
  FBuffer.Position := FBuffer.Size;
  FBuffer.WriteInt128(v);
end;

function TDF_ArrayInt128.Count: Integer;
begin
  Result := FBuffer.Size div C_Int128_Size;
end;

procedure TDF_ArrayInt128.WriteArray(const arry_: array of Int128);
var
  i: Integer;
begin
  if length(arry_) > 0 then
    begin
      FBuffer.Position := FBuffer.Size;
      for i := 0 to length(arry_) - 1 do
          FBuffer.WriteInt128(arry_[i]);
    end;
end;

procedure TDF_ArrayInt128.LoadFromStream(stream: TCore_Stream);
var
  L: Integer;
begin
  Clear;
  stream.Read(L, C_Integer_Size);
  FBuffer.CopyFrom(stream, L * C_Int128_Size);
end;

procedure TDF_ArrayInt128.SaveToStream(stream: TCore_Stream);
var
  L: Integer;
begin
  L := Count;
  stream.write(L, C_Integer_Size);
  stream.write(FBuffer.Memory^, L * C_Int128_Size);
end;

procedure TDF_ArrayInt128.LoadFromJson(jarry: TZ_JsonArray; index_: Integer);
var
  ja: TZ_JsonArray;
  i: Integer;
begin
  ja := jarry.A[index_];
  for i := 0 to ja.Count - 1 do
      Add(ja.I128[i]);
end;

procedure TDF_ArrayInt128.SaveToJson(jarry: TZ_JsonArray; index_: Integer);
var
  ja: TZ_JsonArray;
  i: Integer;
begin
  ja := jarry.AddArray;
  for i := 0 to Count - 1 do
      ja.Add(Buffer[i]);
end;

function TDF_ArrayInt128.ComputeEncodeSize: Int64;
begin
  Result := C_Integer_Size + C_Int128_Size * Count;
end;

function TDF_ArrayInt128.GetBuffer(index_: Integer): Int128;
begin
  Result.b := PInt128_Buffer(FBuffer.PositionAsPtr(index_ * C_Int128_Size))^;
end;

procedure TDF_ArrayInt128.SetBuffer(index_: Integer; Value: Int128);
begin
  PInt128_Buffer(FBuffer.PositionAsPtr(index_ * C_Int128_Size))^ := Value.b;
end;

constructor TDF_Stream.Create(ID: Byte);
begin
  inherited Create(ID);
  FBuffer := TMS64.Create;
end;

destructor TDF_Stream.Destroy;
begin
  DisposeObject(FBuffer);
  inherited Destroy;
end;

procedure TDF_Stream.Clear;
begin
  FBuffer.Clear;
end;

procedure TDF_Stream.LoadFromStream(stream: TCore_Stream);
var
  Size_: Integer;
begin
  FBuffer.Clear;
  stream.Read(Size_, C_Integer_Size);
  if (Size_ > 0) then
      FBuffer.CopyFrom(stream, Size_);
end;

procedure TDF_Stream.SaveToStream(stream: TCore_Stream);
var
  Size_: Integer;
begin
  Size_ := FBuffer.Size;
  stream.write(Size_, C_Integer_Size);
  if Size_ > 0 then
    begin
      FBuffer.Position := 0;
      stream.CopyFrom(FBuffer, Size_);
    end;
end;

procedure TDF_Stream.LoadFromJson(jarry: TZ_JsonArray; index_: Integer);
var
  b64: TPascalString;
begin
  FBuffer.Clear;
  b64.Text := jarry.s[index_];
  umlDecodeStreamBASE64(b64, FBuffer);
end;

procedure TDF_Stream.SaveToJson(jarry: TZ_JsonArray; index_: Integer);
var
  b64: TPascalString;
begin
  umlEncodeStreamBASE64(FBuffer, b64);
  jarry.Add(b64.Text);
end;

function TDF_Stream.ComputeEncodeSize: Int64;
begin
  Result := C_Integer_Size + FBuffer.Size;
end;

function TDF_Stream.GetBuffer: TCore_Stream;
begin
  Result := FBuffer;
end;

procedure TDF_Stream.SetBuffer(Value_: TCore_Stream);
var
  p_: Int64;
begin
  p_ := Value_.Position;
  FBuffer.LoadFromStream(Value_);
  Value_.Position := p_;
end;

constructor TDF_Variant.Create(ID: Byte);
begin
  inherited Create(ID);
end;

destructor TDF_Variant.Destroy;
begin
  inherited Destroy;
end;

procedure TDF_Variant.LoadFromStream(stream: TCore_Stream);
var
  vt: TVarType;
begin
  vt := TVarType(StreamReadUInt16(stream));
  case vt of
    varEmpty, varNull: FBuffer := NULL;
    varSmallInt: FBuffer := StreamReadInt16(stream);
    varInteger: FBuffer := StreamReadInt32(stream);
    varSingle: FBuffer := StreamReadSingle(stream);
    varDouble: FBuffer := StreamReadDouble(stream);
    varCurrency: FBuffer := StreamReadCurrency(stream);
    varBoolean: FBuffer := StreamReadBool(stream);
    varShortInt: FBuffer := StreamReadInt8(stream);
    varByte: FBuffer := StreamReadUInt8(stream);
    varWord: FBuffer := StreamReadUInt16(stream);
    varLongWord: FBuffer := StreamReadUInt32(stream);
    varInt64: FBuffer := StreamReadInt64(stream);
    varUInt64: FBuffer := StreamReadUInt64(stream);
    varOleStr, varString, varUString: FBuffer := StreamReadString(stream).Text;
    else RaiseInfo('error variant type');
  end;
end;

procedure TDF_Variant.SaveToStream(stream: TCore_Stream);
var
  vt: TVarType;
begin
  vt := TVarData(FBuffer).VType;
  StreamWriteUInt16(stream, Word(vt));
  case vt of
    varEmpty, varNull:;
    varSmallInt: StreamWriteInt16(stream, FBuffer);
    varInteger: StreamWriteInt32(stream, FBuffer);
    varSingle: StreamWriteSingle(stream, FBuffer);
    varDouble: StreamWriteDouble(stream, FBuffer);
    varCurrency: StreamWriteCurrency(stream, FBuffer);
    varBoolean: StreamWriteBool(stream, FBuffer);
    varShortInt: StreamWriteInt8(stream, FBuffer);
    varByte: StreamWriteUInt8(stream, FBuffer);
    varWord: StreamWriteUInt16(stream, FBuffer);
    varLongWord: StreamWriteUInt32(stream, FBuffer);
    varInt64: StreamWriteInt64(stream, FBuffer);
    varUInt64: StreamWriteUInt64(stream, FBuffer);
    varOleStr, varString, varUString: StreamWriteString(stream, SystemString(FBuffer));
    else
        RaiseInfo('error variant type');
  end;
end;

procedure TDF_Variant.LoadFromJson(jarry: TZ_JsonArray; index_: Integer);
begin
  FBuffer := umlStrToVar(jarry.s[index_]);
end;

procedure TDF_Variant.SaveToJson(jarry: TZ_JsonArray; index_: Integer);
begin
  jarry.Add(umlVarToStr(FBuffer, True).Text);
end;

function TDF_Variant.ComputeEncodeSize: Int64;
begin
  case TVarData(FBuffer).VType of
    varEmpty, varNull: Result := 2 + 0;
    varSmallInt: Result := 2 + 2;
    varInteger: Result := 2 + 4;
    varSingle: Result := 2 + 4;
    varDouble: Result := 2 + 8;
    varCurrency: Result := 2 + 8;
    varBoolean: Result := 2 + 1;
    varShortInt: Result := 2 + 1;
    varByte: Result := 2 + 1;
    varWord: Result := 2 + 2;
    varLongWord: Result := 2 + 4;
    varInt64: Result := 2 + 8;
    varUInt64: Result := 2 + 8;
    varOleStr, varString, varUString: Result := 2 + ComputeStreamWriteStringSize(SystemString(FBuffer));
    else
        RaiseInfo('error variant type');
  end;
end;

constructor TDF_Int64.Create(ID: Byte);
begin
  inherited Create(ID);
  Buffer := 0;
end;

destructor TDF_Int64.Destroy;
begin
  inherited Destroy;
end;

procedure TDF_Int64.LoadFromStream(stream: TCore_Stream);
begin
  stream.Read(FBuffer, C_Int64_Size);
end;

procedure TDF_Int64.SaveToStream(stream: TCore_Stream);
begin
  stream.write(FBuffer, C_Int64_Size);
end;

procedure TDF_Int64.LoadFromJson(jarry: TZ_JsonArray; index_: Integer);
begin
  FBuffer := jarry.L[index_];
end;

procedure TDF_Int64.SaveToJson(jarry: TZ_JsonArray; index_: Integer);
begin
  jarry.Add(FBuffer);
end;

function TDF_Int64.ComputeEncodeSize: Int64;
begin
  Result := C_Int64_Size;
end;

constructor TDF_UInt64.Create(ID: Byte);
begin
  inherited Create(ID);
  Buffer := 0;
end;

destructor TDF_UInt64.Destroy;
begin
  inherited Destroy;
end;

procedure TDF_UInt64.LoadFromStream(stream: TCore_Stream);
begin
  stream.Read(FBuffer, C_UInt64_Size);
end;

procedure TDF_UInt64.SaveToStream(stream: TCore_Stream);
begin
  stream.write(FBuffer, C_UInt64_Size);
end;

procedure TDF_UInt64.LoadFromJson(jarry: TZ_JsonArray; index_: Integer);
begin
  FBuffer := jarry.u[index_];
end;

procedure TDF_UInt64.SaveToJson(jarry: TZ_JsonArray; index_: Integer);
begin
  jarry.Add(FBuffer);
end;

function TDF_UInt64.ComputeEncodeSize: Int64;
begin
  Result := C_UInt64_Size;
end;

constructor TDF_Int128.Create(ID: Byte);
begin
  inherited Create(ID);
  Buffer := 0;
end;

destructor TDF_Int128.Destroy;
begin
  inherited Destroy;
end;

procedure TDF_Int128.LoadFromStream(stream: TCore_Stream);
begin
  stream.Read(FBuffer, C_Int128_Size);
end;

procedure TDF_Int128.SaveToStream(stream: TCore_Stream);
begin
  stream.write(FBuffer, C_Int128_Size);
end;

procedure TDF_Int128.LoadFromJson(jarry: TZ_JsonArray; index_: Integer);
begin
  FBuffer := jarry.I128[index_];
end;

procedure TDF_Int128.SaveToJson(jarry: TZ_JsonArray; index_: Integer);
begin
  jarry.Add(FBuffer);
end;

function TDF_Int128.ComputeEncodeSize: Int64;
begin
  Result := C_Int128_Size;
end;

constructor TDF_UInt128.Create(ID: Byte);
begin
  inherited Create(ID);
  Buffer := 0;
end;

destructor TDF_UInt128.Destroy;
begin
  inherited Destroy;
end;

procedure TDF_UInt128.LoadFromStream(stream: TCore_Stream);
begin
  stream.Read(FBuffer, C_UInt128_Size);
end;

procedure TDF_UInt128.SaveToStream(stream: TCore_Stream);
begin
  stream.write(FBuffer, C_UInt128_Size);
end;

procedure TDF_UInt128.LoadFromJson(jarry: TZ_JsonArray; index_: Integer);
begin
  FBuffer := jarry.U128[index_];
end;

procedure TDF_UInt128.SaveToJson(jarry: TZ_JsonArray; index_: Integer);
begin
  jarry.Add(FBuffer);
end;

function TDF_UInt128.ComputeEncodeSize: Int64;
begin
  Result := C_UInt128_Size;
end;

constructor TDFE_Reader.Create(Owner_: TDFE);
begin
  inherited Create;
  FOwner := Owner_;
  FIndex := 0;
end;

destructor TDFE_Reader.Destroy;
begin
  inherited Destroy;
end;

function TDFE_Reader.IsEnd: Boolean;
begin
  Result := FIndex >= FOwner.Count;
end;

function TDFE_Reader.NotEnd: Boolean;
begin
  Result := FIndex < FOwner.Count;
end;

procedure TDFE_Reader.Next;
begin
  inc(FIndex);
end;

procedure TDFE_Reader.GoNext;
begin
  Next;
end;

function TDFE_Reader.ReadString: SystemString;
begin
  Result := Owner.ReadString(Index);
  Next;
end;

function TDFE_Reader.ReadInteger: Integer;
begin
  Result := Owner.ReadInteger(Index);
  Next;
end;

function TDFE_Reader.ReadCardinal: Cardinal;
begin
  Result := Owner.ReadCardinal(Index);
  Next;
end;

function TDFE_Reader.ReadWord: Word;
begin
  Result := Owner.ReadWord(Index);
  Next;
end;

function TDFE_Reader.ReadBool: Boolean;
begin
  Result := Owner.ReadBool(Index);
  Next;
end;

function TDFE_Reader.ReadBoolean: Boolean;
begin
  Result := ReadBool;
end;

function TDFE_Reader.ReadByte: Byte;
begin
  Result := Owner.ReadByte(Index);
  Next;
end;

function TDFE_Reader.ReadSingle: Single;
begin
  Result := Owner.ReadSingle(Index);
  Next;
end;

function TDFE_Reader.ReadDouble: Double;
begin
  Result := Owner.ReadDouble(Index);
  Next;
end;

function TDFE_Reader.ReadArrayInteger: TDF_ArrayInteger;
begin
  Result := Owner.ReadArrayInteger(Index);
  Next;
end;

function TDFE_Reader.ReadArrayShortInt: TDF_ArrayShortInt;
begin
  Result := Owner.ReadArrayShortInt(Index);
  Next;
end;

function TDFE_Reader.ReadArrayByte: TDF_ArrayByte;
begin
  Result := Owner.ReadArrayByte(Index);
  Next;
end;

function TDFE_Reader.ReadMD5: TMD5;
begin
  Result := Owner.ReadMD5(Index);
  Next;
end;

function TDFE_Reader.ReadArraySingle: TDF_ArraySingle;
begin
  Result := Owner.ReadArraySingle(Index);
  Next;
end;

function TDFE_Reader.ReadArrayDouble: TDF_ArrayDouble;
begin
  Result := Owner.ReadArrayDouble(Index);
  Next;
end;

function TDFE_Reader.ReadArrayInt64: TDF_ArrayInt64;
begin
  Result := Owner.ReadArrayInt64(Index);
  Next;
end;

procedure TDFE_Reader.ReadMem64(output: TMem64);
begin
  Owner.ReadMem64(Index, output);
  Next;
end;

procedure TDFE_Reader.ReadMem64_As_Mapping(output: TMem64);
begin
  Owner.ReadMem64_As_Mapping(Index, output);
  Next;
end;

procedure TDFE_Reader.ReadMS64_As_Mapping(output: TMS64);
begin
  Owner.ReadMS64_As_Mapping(Index, output);
  Next;
end;

procedure TDFE_Reader.ReadStream(output: TCore_Stream);
begin
  Owner.ReadStream(Index, output);
  Next;
end;

function TDFE_Reader.ReadVariant: Variant;
begin
  Result := Owner.ReadVariant(Index);
  Next;
end;

function TDFE_Reader.ReadInt64: Int64;
begin
  Result := Owner.ReadInt64(Index);
  Next;
end;

function TDFE_Reader.ReadUInt64: UInt64;
begin
  Result := Owner.ReadUInt64(Index);
  Next;
end;

function TDFE_Reader.ReadArrayInt128: TDF_ArrayInt128;
begin
  Result := Owner.ReadArrayInt128(Index);
  Next;
end;

function TDFE_Reader.ReadInt128: Int128;
begin
  Result := Owner.ReadInt128(Index);
  Next;
end;

function TDFE_Reader.ReadUInt128: UInt128;
begin
  Result := Owner.ReadUInt128(Index);
  Next;
end;

procedure TDFE_Reader.ReadStrings(output: TCore_Strings);
begin
  Owner.ReadStrings(Index, output);
  Next;
end;

procedure TDFE_Reader.ReadListStrings(output: TListString);
begin
  Owner.ReadListStrings(Index, output);
  Next;
end;

procedure TDFE_Reader.ReadPascalStrings(output: TPascalStringList);
begin
  Owner.ReadPascalStrings(Index, output);
  Next;
end;

procedure TDFE_Reader.ReadPascalStrings(var output: U_StringArray);
begin
  Owner.ReadPascalStrings(Index, output);
  Next;
end;

procedure TDFE_Reader.ReadDataFrame(output: TDFE);
begin
  Owner.ReadDataFrame(Index, output);
  Next;
end;

procedure TDFE_Reader.ReadDF(output: TDFE);
begin
  Owner.ReadDF(Index, output);
  Next;
end;

procedure TDFE_Reader.ReadDFE(output: TDFE);
begin
  Owner.ReadDFE(Index, output);
  Next;
end;

procedure TDFE_Reader.ReadHashStringList(output: THashStringList);
begin
  Owner.ReadHashStringList(Index, output);
  Next;
end;

procedure TDFE_Reader.ReadVariantList(output: THashVariantList);
begin
  Owner.ReadVariantList(Index, output);
  Next;
end;

procedure TDFE_Reader.ReadJson(output: TZ_JsonObject);
begin
  Owner.ReadJson(Index, output);
  Next;
end;

{$IFDEF DELPHI}


procedure TDFE_Reader.ReadJson(output: TJsonObject);
begin
  Owner.ReadJson(Index, output);
  Next;
end;
{$ENDIF DELPHI}


function TDFE_Reader.ReadRect: TRect;
begin
  Result := Owner.ReadRect(Index);
  Next;
end;

function TDFE_Reader.ReadRectf: TRectf;
begin
  Result := Owner.ReadRectf(Index);
  Next;
end;

function TDFE_Reader.ReadPoint: TPoint;
begin
  Result := Owner.ReadPoint(Index);
  Next;
end;

function TDFE_Reader.ReadPointf: TPointf;
begin
  Result := Owner.ReadPointf(Index);
  Next;
end;

function TDFE_Reader.ReadVector: TVector;
begin
  Result := Owner.ReadVector(Index);
  Next;
end;

function TDFE_Reader.ReadAffineVector: TAffineVector;
begin
  Result := Owner.ReadAffineVector(Index);
  Next;
end;

function TDFE_Reader.ReadVec3: TVec3;
begin
  Result := Owner.ReadVec3(Index);
  Next;
end;

function TDFE_Reader.ReadVec4: TVec4;
begin
  Result := Owner.ReadVec4(Index);
  Next;
end;

function TDFE_Reader.ReadVector3: TVector3;
begin
  Result := Owner.ReadVector3(Index);
  Next;
end;

function TDFE_Reader.ReadVector4: TVector4;
begin
  Result := Owner.ReadVector4(Index);
  Next;
end;

function TDFE_Reader.ReadMat4: TMat4;
begin
  Result := Owner.ReadMat4(Index);
  Next;
end;

function TDFE_Reader.ReadMatrix4: TMatrix4;
begin
  Result := Owner.ReadMatrix4(Index);
  Next;
end;

function TDFE_Reader.Read2DPoint: T2DPoint;
begin
  Result := Owner.Read2DPoint(Index);
  Next;
end;

function TDFE_Reader.ReadVec2: TVec2;
begin
  Result := Owner.ReadVec2(Index);
  Next;
end;

function TDFE_Reader.ReadRectV2: TRectV2;
begin
  Result := Owner.ReadRectV2(Index);
  Next;
end;

function TDFE_Reader.ReadPointer: UInt64;
begin
  Result := Owner.ReadPointer(Index);
  Next;
end;

function TDFE_Reader.ReadPtr: UInt64;
begin
  Result := Owner.ReadPointer(Index);
  Next;
end;

procedure TDFE_Reader.Read(var Buf_; Count_: Int64);
begin
  Owner.Read(Index, Buf_, Count_);
  Next;
end;

procedure TDFE_Reader.ReadNM(output: TNumberModule);
begin
  Owner.ReadNM(Index, output);
  Next;
end;

procedure TDFE_Reader.ReadNMPool(output: TNumberModulePool);
begin
  Owner.ReadNMPool(Index, output);
  Next;
end;

procedure TDFE_Reader.ReadOpCode(output: TOpCode);
begin
  Owner.ReadOpCode(Index, output);
  Next;
end;

procedure TDFE_Reader.ReadSectionText(output: THashTextEngine);
begin
  Owner.ReadSectionText(Index, output);
  Next;
end;

procedure TDFE_Reader.ReadTextSection(output: THashTextEngine);
begin
  Owner.ReadTextSection(Index, output);
  Next;
end;

function TDFE_Reader.Read: TDF_Base;
begin
  Result := Owner.Read(Index);
  Next;
end;

function TDFE_Reader.Current: TDF_Base;
begin
  Result := Owner.Read(Index);
end;

function TDFE_DataList.Add_DFBase(Data_: TDF_Base): TDF_Base;
begin
  inherited Add(Data_);
  Result := Data_;
  Owner.FIsChanged := True;
end;

procedure TDFE_DataList.Clear;
begin
  inherited Clear;
  Owner.FIsChanged := True;
end;

function TDFE.DataTypeToByte(v: TRunTimeDataType): Byte;
begin
  Result := Byte(v);
end;

function TDFE.ByteToDataType(v: Byte): TRunTimeDataType;
begin
  Result := TRunTimeDataType(v);
end;

constructor TDFE.Create;
begin
  inherited Create;
  FBit_64_Condition := C_Max_UInt32;
  FDataList := TDFE_DataList.Create;
  FDataList.Owner := Self;
  FReader := TDFE_Reader.Create(Self);
  FCompressorDeflate := nil;
  FCompressorBRRC := nil;
  FIsChanged := False;
end;

destructor TDFE.Destroy;
begin
  Clear;
  DisposeObject(FDataList);
  DisposeObject(FReader);
  if FCompressorDeflate <> nil then
      DisposeObject(FCompressorDeflate);
  if FCompressorBRRC <> nil then
      DisposeObject(FCompressorBRRC);
  inherited Destroy;
end;

function TDFE.DelayFree: TDFE;
begin
  DelayFreeObj(5.0, Self);
  Result := Self;
end;

procedure TDFE.SwapInstance(source: TDFE);
var
  tmp_DataList: TDFE_DataList;
  tmp_Reader: TDFE_Reader;
begin
  if Self = source then
      exit;
  tmp_DataList := FDataList;
  tmp_Reader := FReader;

  FDataList := source.FDataList;
  FReader := source.FReader;

  source.FDataList := tmp_DataList;
  source.FReader := tmp_Reader;

  FDataList.Owner := Self;
  source.FDataList.Owner := source;

  FReader.FOwner := Self;
  source.FReader.FOwner := source;

  TSwap<Integer>.Do_(Reader.FIndex, source.Reader.FIndex);
  TSwap<Int64>.Do_(FBit_64_Condition, source.FBit_64_Condition);

  FIsChanged := True;
  source.FIsChanged := True;
end;

procedure TDFE.Clear;
var
  i: Integer;
begin
  for i := 0 to FDataList.Count - 1 do
      DisposeObject(FDataList[i]);

  try
      FDataList.Clear;
  except
  end;

  FIsChanged := True;
  FReader.index := 0;
end;

function TDFE.AddData(v: TRunTimeDataType): TDF_Base;
begin
  case v of
    rdtString: Result := TDF_String.Create(DataTypeToByte(v));
    rdtInteger: Result := TDF_Integer.Create(DataTypeToByte(v));
    rdtCardinal: Result := TDF_Cardinal.Create(DataTypeToByte(v));
    rdtWORD: Result := TDF_Word.Create(DataTypeToByte(v));
    rdtByte: Result := TDF_Byte.Create(DataTypeToByte(v));
    rdtSingle: Result := TDF_Single.Create(DataTypeToByte(v));
    rdtDouble: Result := TDF_Double.Create(DataTypeToByte(v));
    rdtArrayInteger: Result := TDF_ArrayInteger.Create(DataTypeToByte(v));
    rdtArrayShortInt: Result := TDF_ArrayShortInt.Create(DataTypeToByte(v));
    rdtArrayByte: Result := TDF_ArrayByte.Create(DataTypeToByte(v));
    rdtArraySingle: Result := TDF_ArraySingle.Create(DataTypeToByte(v));
    rdtArrayDouble: Result := TDF_ArrayDouble.Create(DataTypeToByte(v));
    rdtArrayInt64: Result := TDF_ArrayInt64.Create(DataTypeToByte(v));
    rdtStream: Result := TDF_Stream.Create(DataTypeToByte(v));
    rdtVariant: Result := TDF_Variant.Create(DataTypeToByte(v));
    rdtInt64: Result := TDF_Int64.Create(DataTypeToByte(v));
    rdtUInt64: Result := TDF_UInt64.Create(DataTypeToByte(v));
    rdtArrayInt128: Result := TDF_ArrayInt128.Create(DataTypeToByte(v));
    rdtInt128: Result := TDF_Int128.Create(DataTypeToByte(v));
    rdtUInt128: Result := TDF_UInt128.Create(DataTypeToByte(v));
    else
        Result := nil;
  end;
  if Result <> nil then
      FDataList.Add_DFBase(Result);
  FIsChanged := True;
end;

function TDFE.GetData(index_: Integer): TDF_Base;
begin
  if (index_ >= 0) and (index_ < FDataList.Count) then
      Result := TDF_Base(FDataList[index_])
  else
      Result := nil;
end;

function TDFE.GetDataInfo(Obj_: TDF_Base): SystemString;
begin
  case ByteToDataType(Obj_.FID) of
    rdtString: Result := 'SystemString';
    rdtInteger: Result := 'Integer';
    rdtCardinal: Result := 'Cardinal';
    rdtWORD: Result := 'WORD';
    rdtByte: Result := 'Byte';
    rdtSingle: Result := 'Single';
    rdtDouble: Result := 'Double';
    rdtArrayInteger: Result := 'ArrayInteger';
    rdtArrayShortInt: Result := 'ShortInt';
    rdtArrayByte: Result := 'Byte';
    rdtArraySingle: Result := 'ArraySingle';
    rdtArrayDouble: Result := 'ArrayDouble';
    rdtArrayInt64: Result := 'ArrayInt64';
    rdtStream: Result := 'Stream';
    rdtVariant: Result := 'Variant';
    rdtInt64: Result := 'Int64';
    rdtUInt64: Result := 'UInt64';
    else
        Result := '';
  end;
end;

function TDFE.Count: Integer;
begin
  Result := FDataList.Count;
end;

function TDFE.Delete(index_: Integer): Boolean;
begin
  try
    DisposeObject(FDataList[index_]);
    FDataList.Delete(index_);
    FIsChanged := True;
    Result := True;
  except
      Result := False;
  end;
end;

function TDFE.DeleteFirst: Boolean;
begin
  Result := Delete(0);
end;

function TDFE.DeleteLast: Boolean;
begin
  Result := Delete(Count - 1);
end;

function TDFE.DeleteLastCount(num_: Integer): Boolean;
begin
  Result := True;
  while num_ > 0 do
    begin
      Result := Result and DeleteLast;
      dec(num_);
    end;
end;

function TDFE.DeleteCount(index_, Count_: Integer): Boolean;
var
  i: Integer;
begin
  Result := True;
  for i := 0 to Count_ - 1 do
      Result := Result and Delete(index_);
end;

function TDFE.Append(source: TDFE): TDFE;
var
  m64: TMS64;
  i: Integer;
  DataFrame_: TDF_Base;
begin
  Result := Self;
  if Self = source then
      exit;
  m64 := TMS64.CustomCreate(64 * 1024);
  for i := 0 to source.Count - 1 do
    begin
      DataFrame_ := AddData(ByteToDataType(source[i].FID));
      source[i].SaveToStream(m64);
      m64.Position := 0;
      DataFrame_.LoadFromStream(m64);
      m64.Position := 0;
    end;
  DisposeObject(m64);
end;

function TDFE.Assign(source: TDFE): TDFE;
var
  m64: TMS64;
  i: Integer;
  DataFrame_: TDF_Base;
begin
  Result := Self;
  if Self = source then
      exit;
  Clear;
  m64 := TMS64.CustomCreate(64 * 1024);
  for i := 0 to source.Count - 1 do
    begin
      DataFrame_ := AddData(ByteToDataType(source[i].FID));
      source[i].SaveToStream(m64);
      m64.Position := 0;
      DataFrame_.LoadFromStream(m64);
      m64.Position := 0;
    end;
  DisposeObject(m64);
  FBit_64_Condition := source.FBit_64_Condition;
end;

function TDFE.NewClone: TDFE;
begin
  Result := TDFE.Create;
  Result.Assign(Self);
end;

function TDFE.WriteString(v: SystemString): TDFE;
var
  Obj_: TDF_String;
begin
  Obj_ := TDF_String.Create(DataTypeToByte(rdtString));
  Obj_.Buffer := umlBytesOf(v);
  FDataList.Add_DFBase(Obj_);
  Result := Self;
end;

function TDFE.WriteString(v: TPascalString): TDFE;
var
  Obj_: TDF_String;
begin
  Obj_ := TDF_String.Create(DataTypeToByte(rdtString));
  Obj_.Buffer := v.Bytes;
  FDataList.Add_DFBase(Obj_);
  Result := Self;
end;

function TDFE.WriteString(v: TUPascalString): TDFE;
var
  Obj_: TDF_String;
begin
  Obj_ := TDF_String.Create(DataTypeToByte(rdtString));
  Obj_.Buffer := v.Bytes;
  FDataList.Add_DFBase(Obj_);
  Result := Self;
end;

function TDFE.WriteString(const Fmt: SystemString; const Args: array of const): TDFE;
begin
  Result := WriteString(PFormat(Fmt, Args));
end;

function TDFE.WriteInteger(v: Integer): TDFE;
var
  Obj_: TDF_Integer;
begin
  Obj_ := TDF_Integer.Create(DataTypeToByte(rdtInteger));
  Obj_.Buffer := v;
  FDataList.Add_DFBase(Obj_);
  Result := Self;
end;

function TDFE.WriteCardinal(v: Cardinal): TDFE;
var
  Obj_: TDF_Cardinal;
begin
  Obj_ := TDF_Cardinal.Create(DataTypeToByte(rdtCardinal));
  Obj_.Buffer := v;
  FDataList.Add_DFBase(Obj_);
  Result := Self;
end;

function TDFE.WriteWORD(v: Word): TDFE;
var
  Obj_: TDF_Word;
begin
  Obj_ := TDF_Word.Create(DataTypeToByte(rdtWORD));
  Obj_.Buffer := v;
  FDataList.Add_DFBase(Obj_);
  Result := Self;
end;

function TDFE.WriteBool(v: Boolean): TDFE;
begin
  if v then
      WriteByte(1)
  else
      WriteByte(0);
  Result := Self;
end;

function TDFE.WriteBoolean(v: Boolean): TDFE;
begin
  Result := WriteBool(v);
end;

function TDFE.WriteByte(v: Byte): TDFE;
var
  Obj_: TDF_Byte;
begin
  Obj_ := TDF_Byte.Create(DataTypeToByte(rdtByte));
  Obj_.Buffer := v;
  FDataList.Add_DFBase(Obj_);
  Result := Self;
end;

function TDFE.WriteSingle(v: Single): TDFE;
var
  Obj_: TDF_Single;
begin
  Obj_ := TDF_Single.Create(DataTypeToByte(rdtSingle));
  Obj_.Buffer := v;
  FDataList.Add_DFBase(Obj_);
  Result := Self;
end;

function TDFE.WriteDouble(v: Double): TDFE;
var
  Obj_: TDF_Double;
begin
  Obj_ := TDF_Double.Create(DataTypeToByte(rdtDouble));
  Obj_.Buffer := v;
  FDataList.Add_DFBase(Obj_);
  Result := Self;
end;

function TDFE.WriteArrayInteger: TDF_ArrayInteger;
begin
  Result := TDF_ArrayInteger.Create(DataTypeToByte(rdtArrayInteger));
  FDataList.Add_DFBase(Result);
end;

function TDFE.WriteArrayShortInt: TDF_ArrayShortInt;
begin
  Result := TDF_ArrayShortInt.Create(DataTypeToByte(rdtArrayShortInt));
  FDataList.Add_DFBase(Result);
end;

function TDFE.WriteArrayByte: TDF_ArrayByte;
begin
  Result := TDF_ArrayByte.Create(DataTypeToByte(rdtArrayByte));
  FDataList.Add_DFBase(Result);
end;

function TDFE.WriteMD5(md5: TMD5): TDFE;
begin
  WriteArrayByte.SetBuff(@md5[0], SizeOf(TMD5));
  Result := Self;
end;

function TDFE.WriteArraySingle: TDF_ArraySingle;
begin
  Result := TDF_ArraySingle.Create(DataTypeToByte(rdtArraySingle));
  FDataList.Add_DFBase(Result);
end;

function TDFE.WriteArrayDouble: TDF_ArrayDouble;
begin
  Result := TDF_ArrayDouble.Create(DataTypeToByte(rdtArrayDouble));
  FDataList.Add_DFBase(Result);
end;

function TDFE.WriteArrayInt64: TDF_ArrayInt64;
begin
  Result := TDF_ArrayInt64.Create(DataTypeToByte(rdtArrayInt64));
  FDataList.Add_DFBase(Result);
end;

function TDFE.WriteMem64(v: TMem64): TDFE;
var
  Obj_: TDF_Stream;
begin
  Obj_ := TDF_Stream.Create(DataTypeToByte(rdtStream));
  v.Position := 0;
  Obj_.Buffer64.CopyMem64(v, v.Size);
  FDataList.Add_DFBase(Obj_);
  Result := Self;
end;

function TDFE.WriteStream(v: TCore_Stream): TDFE;
var
  Obj_: TDF_Stream;
begin
  Obj_ := TDF_Stream.Create(DataTypeToByte(rdtStream));
  Obj_.Buffer := v;
  FDataList.Add_DFBase(Obj_);
  Result := Self;
end;

function TDFE.WriteStream(v: TMS64; bPos_, Size_: Int64): TDFE;
var
  Obj_: TDF_Stream;
begin
  Obj_ := TDF_Stream.Create(DataTypeToByte(rdtStream));
  Obj_.Buffer64.Clear;
  Obj_.Buffer64.WritePtr(v.PosAsPtr(bPos_), Size_);
  FDataList.Add_DFBase(Obj_);
  Result := Self;
end;

function TDFE.WriteVariant(v: Variant): TDFE;
var
  Obj_: TDF_Variant;
begin
  Obj_ := TDF_Variant.Create(DataTypeToByte(rdtVariant));
  Obj_.Buffer := v;
  FDataList.Add_DFBase(Obj_);
  Result := Self;
end;

function TDFE.WriteInt64(v: Int64): TDFE;
var
  Obj_: TDF_Int64;
begin
  Obj_ := TDF_Int64.Create(DataTypeToByte(rdtInt64));
  Obj_.Buffer := v;
  FDataList.Add_DFBase(Obj_);
  Result := Self;
end;

function TDFE.WriteUInt64(v: UInt64): TDFE;
var
  Obj_: TDF_UInt64;
begin
  Obj_ := TDF_UInt64.Create(DataTypeToByte(rdtUInt64));
  Obj_.Buffer := v;
  FDataList.Add_DFBase(Obj_);
  Result := Self;
end;

function TDFE.WriteArrayInt128: TDF_ArrayInt128;
begin
  Result := TDF_ArrayInt128.Create(DataTypeToByte(rdtArrayInt128));
  FDataList.Add_DFBase(Result);
end;

function TDFE.WriteInt128(v: Int128): TDFE;
var
  Obj_: TDF_Int128;
begin
  Obj_ := TDF_Int128.Create(DataTypeToByte(rdtInt128));
  Obj_.Buffer := v;
  FDataList.Add_DFBase(Obj_);
  Result := Self;
end;

function TDFE.WriteUInt128(v: UInt128): TDFE;
var
  Obj_: TDF_UInt128;
begin
  Obj_ := TDF_UInt128.Create(DataTypeToByte(rdtUInt128));
  Obj_.Buffer := v;
  FDataList.Add_DFBase(Obj_);
  Result := Self;
end;

function TDFE.WriteStrings(v: TCore_Strings): TDFE;
var
  m64: TMS64;
begin
  m64 := TMS64.CustomCreate(umlMax(8192, v.Count * 10));
{$IFDEF FPC}
  v.SaveToStream(m64);
{$ELSE}
  v.SaveToStream(m64, TEncoding.UTF8);
{$ENDIF}
  m64.Position := 0;
  Result := WriteStream(m64);
  DisposeObject(m64);
end;

function TDFE.WriteListStrings(v: TListString): TDFE;
var
  m64: TMS64;
begin
  m64 := TMS64.CustomCreate(umlMax(8192, v.Count * 10));
  v.SaveToStream(m64);
  m64.Position := 0;
  Result := WriteStream(m64);
  DisposeObject(m64);
end;

function TDFE.WritePascalStrings(v: TPascalStringList): TDFE;
var
  m64: TMS64;
begin
  m64 := TMS64.CustomCreate(umlMax(8192, v.Count * 10));
  v.SaveToStream(m64);
  m64.Position := 0;
  Result := WriteStream(m64);
  DisposeObject(m64);
end;

function TDFE.WritePascalStrings(v: U_StringArray): TDFE;
var
  L: TPascalStringList;
  i: Integer;
begin
  L := TPascalStringList.Create;
  for i := low(v) to high(v) do
      L.Add(v[i]);
  WritePascalStrings(L);
  DisposeObject(L);
  Result := Self;
end;

function TDFE.WriteDataFrame(v: TDFE): TDFE;
var
  Obj_: TDF_Stream;
begin
  Obj_ := TDF_Stream.Create(DataTypeToByte(rdtStream));
  v.FastEncodeTo(Obj_.Buffer);
  FDataList.Add_DFBase(Obj_);
  Result := Self;
end;

function TDFE.WriteDataFrameCompressed(v: TDFE): TDFE;
var
  Obj_: TDF_Stream;
begin
  Obj_ := TDF_Stream.Create(DataTypeToByte(rdtStream));
  v.EncodeAsSelectCompressor(Obj_.Buffer, True);
  FDataList.Add_DFBase(Obj_);
  Result := Self;
end;

function TDFE.WriteDataFrameZLib(v: TDFE): TDFE;
var
  Obj_: TDF_Stream;
begin
  Obj_ := TDF_Stream.Create(DataTypeToByte(rdtStream));
  v.EncodeAsZLib(Obj_.Buffer, True);
  FDataList.Add_DFBase(Obj_);
  Result := Self;
end;

function TDFE.WriteDF(v: TDFE): TDFE;
begin
  Result := WriteDataFrame(v);
end;

function TDFE.WriteDFE(v: TDFE): TDFE;
begin
  Result := WriteDataFrame(v);
end;

function TDFE.WriteHashStringList(v: THashStringList): TDFE;
var
  m64: TMS64;
  hash_: THashStringTextStream;
begin
  m64 := TMS64.Create;
  hash_ := THashStringTextStream.Create(v);
  hash_.SaveToStream(m64);
  DisposeObject(hash_);
  m64.Position := 0;
  Result := WriteStream(m64);
  DisposeObject(m64);
end;

function TDFE.WriteVariantList(v: THashVariantList): TDFE;
var
  m64: TMS64;
  hash_: THashVariantTextStream;
begin
  m64 := TMS64.Create;
  hash_ := THashVariantTextStream.Create(v);
  hash_.SaveToStream(m64);
  DisposeObject(hash_);
  m64.Position := 0;
  Result := WriteStream(m64);
  DisposeObject(m64);
end;

function TDFE.WriteJson(v: TZ_JsonObject): TDFE;
begin
  Result := WriteJson(v, False);
end;

function TDFE.WriteJson(v: TZ_JsonObject; Formated_: Boolean): TDFE;
var
  m64: TMS64;
begin
  m64 := TMS64.Create;
  v.SaveToStream(m64, Formated_);
  m64.Position := 0;
  Result := WriteStream(m64);
  DisposeObject(m64);
end;

{$IFDEF DELPHI}


function TDFE.WriteJson(v: TJsonObject): TDFE;
var
  m64: TMS64;
begin
  m64 := TMS64.Create;
  v.SaveToStream(m64, True, TEncoding.UTF8, True);
  m64.Position := 0;
  Result := WriteStream(m64);
  DisposeObject(m64);
end;
{$ENDIF DELPHI}


function TDFE.WriteFile(fn: SystemString): TDFE;
var
  fs: TCore_FileStream;
begin
  if umlFileExists(fn) then
    begin
      fs := TCore_FileStream.Create(fn, fmOpenRead or fmShareDenyNone);
      fs.Position := 0;
      Result := WriteStream(fs);
      DisposeObject(fs);
    end
  else
      Result := Self;
end;

function TDFE.WriteRect(v: TRect): TDFE;
begin
  with WriteArrayInteger do
    begin
      Add(v.Left);
      Add(v.Top);
      Add(v.Right);
      Add(v.Bottom);
    end;
  Result := Self;
end;

function TDFE.WriteRectf(v: TRectf): TDFE;
begin
  with WriteArraySingle do
    begin
      Add(v.Left);
      Add(v.Top);
      Add(v.Right);
      Add(v.Bottom);
    end;
  Result := Self;
end;

function TDFE.WritePoint(v: TPoint): TDFE;
begin
  with WriteArrayInteger do
    begin
      Add(v.x);
      Add(v.y);
    end;
  Result := Self;
end;

function TDFE.WritePointf(v: TPointf): TDFE;
begin
  with WriteArraySingle do
    begin
      Add(v.x);
      Add(v.y);
    end;
  Result := Self;
end;

function TDFE.WriteVector(v: TVector): TDFE;
begin
  WriteArraySingle.WriteArray(v);
  Result := Self;
end;

function TDFE.WriteAffineVector(v: TAffineVector): TDFE;
begin
  WriteArraySingle.WriteArray(v);
  Result := Self;
end;

function TDFE.WriteVec4(v: TVec4): TDFE;
begin
  WriteArraySingle.WriteArray(v);
  Result := Self;
end;

function TDFE.WriteVec3(v: TVec3): TDFE;
begin
  WriteArraySingle.WriteArray(v);
  Result := Self;
end;

function TDFE.WriteVector4(v: TVector4): TDFE;
begin
  WriteArraySingle.WriteArray(v.buff);
  Result := Self;
end;

function TDFE.WriteVector3(v: TVector3): TDFE;
begin
  WriteArraySingle.WriteArray(v.buff);
  Result := Self;
end;

function TDFE.WriteMat4(v: TMat4): TDFE;
begin
  with WriteArraySingle do
    begin
      WriteArray(v[0]);
      WriteArray(v[1]);
      WriteArray(v[2]);
      WriteArray(v[3]);
    end;
  Result := Self;
end;

function TDFE.WriteMatrix4(v: TMatrix4): TDFE;
begin
  Result := WriteMat4(v.buff);
end;

function TDFE.Write2DPoint(v: T2DPoint): TDFE;
begin
  with WriteArraySingle do
      WriteArray(v);
  Result := Self;
end;

function TDFE.WriteVec2(v: TVec2): TDFE;
begin
  Result := Write2DPoint(v);
end;

function TDFE.WriteRectV2(v: TRectV2): TDFE;
begin
  with WriteArraySingle do
    begin
      WriteArray(v[0]);
      WriteArray(v[1]);
    end;
  Result := Self;
end;

function TDFE.WritePointer(v: Pointer): TDFE;
begin
  Result := WriteUInt64(UInt64(v));
end;

function TDFE.WritePointer(v: UInt64): TDFE;
begin
  Result := WriteUInt64(v);
end;

function TDFE.WritePtr(v: Pointer): TDFE;
begin
  Result := WriteUInt64(UInt64(v));
end;

function TDFE.WritePtr(v: UInt64): TDFE;
begin
  Result := WriteUInt64(v);
end;

// append new stream and write
function TDFE.write(const Buf_; Count_: Int64): TDFE;
var
  s: TMS64;
begin
  s := TMS64.Create;
  s.Write64(Buf_, Count_);
  Result := WriteStream(s);
  DisposeObject(s);
end;

function TDFE.WriteNM(NM: TNumberModule): TDFE;
var
  D_: TDFE;
begin
  D_ := TDFE.Create;
  D_.WriteString(NM.Name);
  D_.WriteVariant(NM.Origin);
  D_.WriteVariant(NM.Value);
  Result := WriteDataFrame(D_);
  DisposeObject(D_);
end;

function TDFE.WriteNMPool(NMPool: TNumberModulePool): TDFE;
var
  D_: TDFE;
{$IFDEF FPC}
  procedure fpc_progress_(const Name: PSystemString; NM: TNumberModule);
  var
    Tmp_: TDFE;
  begin
    Tmp_ := TDFE.Create;
    Tmp_.WriteString(NM.Name);
    Tmp_.WriteVariant(NM.Origin);
    Tmp_.WriteVariant(NM.Value);
    D_.WriteDataFrame(Tmp_);
    DisposeObject(Tmp_);
  end;
{$ENDIF FPC}


begin
  D_ := TDFE.Create;

{$IFDEF FPC}
  NMPool.List.ProgressP(fpc_progress_);
{$ELSE FPC}
  NMPool.List.ProgressP(procedure(const Name: PSystemString; NM: TNumberModule)
    var
      Tmp_: TDFE;
    begin
      Tmp_ := TDFE.Create;
      Tmp_.WriteString(NM.Name);
      Tmp_.WriteVariant(NM.Origin);
      Tmp_.WriteVariant(NM.Value);
      D_.WriteDataFrame(Tmp_);
      DisposeObject(Tmp_);
    end);
{$ENDIF FPC}
  Result := WriteDataFrame(D_);
  DisposeObject(D_);
end;

function TDFE.WriteOpCode(v: TOpCode): TDFE;
var
  m64: TMS64;
begin
  m64 := TMS64.Create;
  v.SaveToStream(m64);
  m64.Position := 0;
  Result := WriteStream(m64);
  DisposeObject(m64);
end;

function TDFE.WriteSectionText(v: THashTextEngine): TDFE;
var
  m64: TMS64;
begin
  m64 := TMS64.Create;
  v.SaveToStream(m64);
  m64.Position := 0;
  Result := WriteStream(m64);
  DisposeObject(m64);
end;

function TDFE.WriteTextSection(v: THashTextEngine): TDFE;
begin
  Result := WriteSectionText(v);
end;

function TDFE.ReadString(index_: Integer): SystemString;
var
  Obj_: TDF_Base;
  i: Integer;
begin
  Obj_ := Data[index_];
  if Obj_ is TDF_String then
      Result := umlStringOf(TDF_String(Obj_).Buffer).Text
  else if Obj_ is TDF_Integer then
      Result := IntToStr(TDF_Integer(Obj_).Buffer)
  else if Obj_ is TDF_Cardinal then
      Result := IntToStr(TDF_Cardinal(Obj_).Buffer)
  else if Obj_ is TDF_Word then
      Result := IntToStr(TDF_Word(Obj_).Buffer)
  else if Obj_ is TDF_Byte then
      Result := IntToStr(TDF_Byte(Obj_).Buffer)
  else if Obj_ is TDF_Single then
      Result := FloatToStr(TDF_Single(Obj_).Buffer)
  else if Obj_ is TDF_Double then
      Result := FloatToStr(TDF_Double(Obj_).Buffer)
  else if Obj_ is TDF_ArrayInteger then
    begin
      Result := '(';
      with TDF_ArrayInteger(Obj_) do
        begin
          for i := 0 to Count - 1 do
            if Result <> '(' then
                Result := Result + ',' + IntToStr(Buffer[i])
            else
                Result := Result + IntToStr(Buffer[i]);
        end;
      Result := Result + ')';
    end
  else if Obj_ is TDF_ArrayShortInt then
    begin
      Result := '(';
      with TDF_ArrayShortInt(Obj_) do
        begin
          for i := 0 to Count - 1 do
            if Result <> '(' then
                Result := Result + ',' + IntToStr(Buffer[i])
            else
                Result := Result + IntToStr(Buffer[i]);
        end;
      Result := Result + ')';
    end
  else if Obj_ is TDF_ArrayByte then
    begin
      Result := '(';
      with TDF_ArrayByte(Obj_) do
        begin
          for i := 0 to Count - 1 do
            if Result <> '(' then
                Result := Result + ',' + IntToStr(Buffer[i])
            else
                Result := Result + IntToStr(Buffer[i]);
        end;
      Result := Result + ')';
    end
  else if Obj_ is TDF_ArraySingle then
    begin
      Result := '(';
      with TDF_ArraySingle(Obj_) do
        begin
          for i := 0 to Count - 1 do
            if Result <> '(' then
                Result := Result + ',' + FloatToStr(Buffer[i])
            else
                Result := Result + FloatToStr(Buffer[i]);
        end;
      Result := Result + ')';
    end
  else if Obj_ is TDF_ArrayDouble then
    begin
      Result := '(';
      with TDF_ArrayDouble(Obj_) do
        begin
          for i := 0 to Count - 1 do
            if Result <> '(' then
                Result := Result + ',' + FloatToStr(Buffer[i])
            else
                Result := Result + FloatToStr(Buffer[i]);
        end;
      Result := Result + ')';
    end
  else if Obj_ is TDF_ArrayInt64 then
    begin
      Result := '(';
      with TDF_ArrayInt64(Obj_) do
        begin
          for i := 0 to Count - 1 do
            if Result <> '(' then
                Result := Result + ',' + IntToStr(Buffer[i])
            else
                Result := Result + IntToStr(Buffer[i]);
        end;
      Result := Result + ')';
    end
  else if Obj_ is TDF_Variant then
      Result := umlVarToStr(TDF_Variant(Obj_).Buffer)
  else if Obj_ is TDF_Int64 then
      Result := IntToStr(TDF_Int64(Obj_).Buffer)
  else if Obj_ is TDF_UInt64 then
{$IFDEF FPC}
    Result := IntToStr(TDF_UInt64(Obj_).Buffer)
{$ELSE}
    Result := UIntToStr(TDF_UInt64(Obj_).Buffer)
{$ENDIF}
  else if Obj_ is TDF_Int128 then
      Result := TDF_Int128(Obj_).Buffer.ToString.Text
  else if Obj_ is TDF_UInt128 then
      Result := TDF_UInt128(Obj_).Buffer.ToString.Text
  else
      Result := '';
end;

function TDFE.ReadInteger(index_: Integer): Integer;
var
  Obj_: TDF_Base;
begin
  Obj_ := Data[index_];
  if Obj_ is TDF_Integer then
      Result := TDF_Integer(Obj_).Buffer
  else if Obj_ is TDF_String then
      Result := umlStrToInt(umlStringOf(TDF_String(Obj_).Buffer), 0)
  else if Obj_ is TDF_Cardinal then
      Result := TDF_Cardinal(Obj_).Buffer
  else if Obj_ is TDF_Word then
      Result := TDF_Word(Obj_).Buffer
  else if Obj_ is TDF_Byte then
      Result := TDF_Byte(Obj_).Buffer
  else if Obj_ is TDF_Single then
      Result := Trunc(TDF_Single(Obj_).Buffer)
  else if Obj_ is TDF_Double then
      Result := Trunc(TDF_Double(Obj_).Buffer)
  else if Obj_ is TDF_Variant then
      Result := (TDF_Variant(Obj_).Buffer)
  else if Obj_ is TDF_Int64 then
      Result := (TDF_Int64(Obj_).Buffer)
  else if Obj_ is TDF_UInt64 then
      Result := (TDF_UInt64(Obj_).Buffer)
  else if Obj_ is TDF_Int128 then
      Result := TDF_Int128(Obj_).Buffer.ToInt32
  else if Obj_ is TDF_UInt128 then
      Result := TDF_UInt128(Obj_).Buffer.ToInt32
  else
      Result := 0;
end;

function TDFE.ReadCardinal(index_: Integer): Cardinal;
var
  Obj_: TDF_Base;
begin
  Obj_ := Data[index_];
  if Obj_ is TDF_Cardinal then
      Result := TDF_Cardinal(Obj_).Buffer
  else if Obj_ is TDF_String then
      Result := umlStrToInt(umlStringOf(TDF_String(Obj_).Buffer), 0)
  else if Obj_ is TDF_Integer then
      Result := TDF_Integer(Obj_).Buffer
  else if Obj_ is TDF_Word then
      Result := TDF_Word(Obj_).Buffer
  else if Obj_ is TDF_Byte then
      Result := TDF_Byte(Obj_).Buffer
  else if Obj_ is TDF_Single then
      Result := Trunc(TDF_Single(Obj_).Buffer)
  else if Obj_ is TDF_Double then
      Result := Trunc(TDF_Double(Obj_).Buffer)
  else if Obj_ is TDF_Variant then
      Result := (TDF_Variant(Obj_).Buffer)
  else if Obj_ is TDF_Int64 then
      Result := (TDF_Int64(Obj_).Buffer)
  else if Obj_ is TDF_UInt64 then
      Result := (TDF_UInt64(Obj_).Buffer)
  else if Obj_ is TDF_Int128 then
      Result := TDF_Int128(Obj_).Buffer.ToUInt32
  else if Obj_ is TDF_UInt128 then
      Result := TDF_UInt128(Obj_).Buffer.ToUInt32
  else
      Result := 0;
end;

function TDFE.ReadWord(index_: Integer): Word;
var
  Obj_: TDF_Base;
begin
  Obj_ := Data[index_];
  if Obj_ is TDF_Word then
      Result := TDF_Word(Obj_).Buffer
  else if Obj_ is TDF_String then
      Result := umlStrToInt(umlStringOf(TDF_String(Obj_).Buffer), 0)
  else if Obj_ is TDF_Integer then
      Result := TDF_Integer(Obj_).Buffer
  else if Obj_ is TDF_Cardinal then
      Result := TDF_Cardinal(Obj_).Buffer
  else if Obj_ is TDF_Byte then
      Result := TDF_Byte(Obj_).Buffer
  else if Obj_ is TDF_Single then
      Result := Trunc(TDF_Single(Obj_).Buffer)
  else if Obj_ is TDF_Double then
      Result := Trunc(TDF_Double(Obj_).Buffer)
  else if Obj_ is TDF_Variant then
      Result := (TDF_Variant(Obj_).Buffer)
  else if Obj_ is TDF_Int64 then
      Result := (TDF_Int64(Obj_).Buffer)
  else if Obj_ is TDF_UInt64 then
      Result := (TDF_UInt64(Obj_).Buffer)
  else if Obj_ is TDF_Int128 then
      Result := TDF_Int128(Obj_).Buffer.ToUInt16
  else if Obj_ is TDF_UInt128 then
      Result := TDF_UInt128(Obj_).Buffer.ToUInt16
  else
      Result := 0;
end;

function TDFE.ReadBool(index_: Integer): Boolean;
begin
  Result := ReadByte(index_) = 1;
end;

function TDFE.ReadBoolean(index_: Integer): Boolean;
begin
  Result := ReadBool(index_);
end;

function TDFE.ReadByte(index_: Integer): Byte;
var
  Obj_: TDF_Base;
begin
  Obj_ := Data[index_];
  if Obj_ is TDF_Byte then
      Result := TDF_Byte(Obj_).Buffer
  else if Obj_ is TDF_String then
      Result := umlStrToInt(umlStringOf(TDF_String(Obj_).Buffer), 0)
  else if Obj_ is TDF_Integer then
      Result := TDF_Integer(Obj_).Buffer
  else if Obj_ is TDF_Cardinal then
      Result := TDF_Cardinal(Obj_).Buffer
  else if Obj_ is TDF_Word then
      Result := TDF_Word(Obj_).Buffer
  else if Obj_ is TDF_Single then
      Result := Trunc(TDF_Single(Obj_).Buffer)
  else if Obj_ is TDF_Double then
      Result := Trunc(TDF_Double(Obj_).Buffer)
  else if Obj_ is TDF_Variant then
      Result := (TDF_Variant(Obj_).Buffer)
  else if Obj_ is TDF_Int64 then
      Result := (TDF_Int64(Obj_).Buffer)
  else if Obj_ is TDF_UInt64 then
      Result := (TDF_UInt64(Obj_).Buffer)
  else if Obj_ is TDF_Int128 then
      Result := TDF_Int128(Obj_).Buffer.ToUInt8
  else if Obj_ is TDF_UInt128 then
      Result := TDF_UInt128(Obj_).Buffer.ToUInt8
  else
      Result := 0;
end;

function TDFE.ReadSingle(index_: Integer): Single;
var
  Obj_: TDF_Base;
begin
  Obj_ := Data[index_];
  if Obj_ is TDF_Single then
      Result := TDF_Single(Obj_).Buffer
  else if Obj_ is TDF_String then
      Result := umlStrToFloat(umlStringOf(TDF_String(Obj_).Buffer), 0)
  else if Obj_ is TDF_Integer then
      Result := TDF_Integer(Obj_).Buffer
  else if Obj_ is TDF_Cardinal then
      Result := TDF_Cardinal(Obj_).Buffer
  else if Obj_ is TDF_Word then
      Result := TDF_Word(Obj_).Buffer
  else if Obj_ is TDF_Byte then
      Result := TDF_Byte(Obj_).Buffer
  else if Obj_ is TDF_Double then
      Result := TDF_Double(Obj_).Buffer
  else if Obj_ is TDF_Variant then
      Result := (TDF_Variant(Obj_).Buffer)
  else if Obj_ is TDF_Int64 then
      Result := (TDF_Int64(Obj_).Buffer)
  else if Obj_ is TDF_UInt64 then
      Result := (TDF_UInt64(Obj_).Buffer)
  else if Obj_ is TDF_Int128 then
      Result := TDF_Int128(Obj_).Buffer.ToInt32
  else if Obj_ is TDF_UInt128 then
      Result := TDF_UInt128(Obj_).Buffer.ToInt32
  else
      Result := 0;
end;

function TDFE.ReadDouble(index_: Integer): Double;
var
  Obj_: TDF_Base;
begin
  Obj_ := Data[index_];
  if Obj_ is TDF_Double then
      Result := TDF_Double(Obj_).Buffer
  else if Obj_ is TDF_String then
      Result := umlStrToFloat(umlStringOf(TDF_String(Obj_).Buffer), 0)
  else if Obj_ is TDF_Integer then
      Result := TDF_Integer(Obj_).Buffer
  else if Obj_ is TDF_Cardinal then
      Result := TDF_Cardinal(Obj_).Buffer
  else if Obj_ is TDF_Word then
      Result := TDF_Word(Obj_).Buffer
  else if Obj_ is TDF_Byte then
      Result := TDF_Byte(Obj_).Buffer
  else if Obj_ is TDF_Single then
      Result := TDF_Single(Obj_).Buffer
  else if Obj_ is TDF_Variant then
      Result := (TDF_Variant(Obj_).Buffer)
  else if Obj_ is TDF_Int64 then
      Result := (TDF_Int64(Obj_).Buffer)
  else if Obj_ is TDF_UInt64 then
      Result := (TDF_UInt64(Obj_).Buffer)
  else if Obj_ is TDF_Int128 then
      Result := TDF_Int128(Obj_).Buffer.ToInt64
  else if Obj_ is TDF_UInt128 then
      Result := TDF_UInt128(Obj_).Buffer.ToInt64
  else
      Result := 0;
end;

function TDFE.ReadArrayInteger(index_: Integer): TDF_ArrayInteger;
var
  Obj_: TDF_Base;
begin
  Obj_ := Data[index_];
  if Obj_ is TDF_ArrayInteger then
      Result := TDF_ArrayInteger(Obj_)
  else
      Result := nil;
end;

function TDFE.ReadArrayShortInt(index_: Integer): TDF_ArrayShortInt;
var
  Obj_: TDF_Base;
begin
  Obj_ := Data[index_];
  if Obj_ is TDF_ArrayShortInt then
      Result := TDF_ArrayShortInt(Obj_)
  else
      Result := nil;
end;

function TDFE.ReadArrayByte(index_: Integer): TDF_ArrayByte;
var
  Obj_: TDF_Base;
begin
  Obj_ := Data[index_];
  if Obj_ is TDF_ArrayByte then
      Result := TDF_ArrayByte(Obj_)
  else
      Result := nil;
end;

function TDFE.ReadMD5(index_: Integer): TMD5;
begin
  with ReadArrayByte(index_) do
      GetBuff(@Result[0]);
end;

function TDFE.ReadArraySingle(index_: Integer): TDF_ArraySingle;
var
  Obj_: TDF_Base;
begin
  Obj_ := Data[index_];
  if Obj_ is TDF_ArraySingle then
      Result := TDF_ArraySingle(Obj_)
  else
      Result := nil;
end;

function TDFE.ReadArrayDouble(index_: Integer): TDF_ArrayDouble;
var
  Obj_: TDF_Base;
begin
  Obj_ := Data[index_];
  if Obj_ is TDF_ArrayDouble then
      Result := TDF_ArrayDouble(Obj_)
  else
      Result := nil;
end;

function TDFE.ReadArrayInt64(index_: Integer): TDF_ArrayInt64;
var
  Obj_: TDF_Base;
begin
  Obj_ := Data[index_];
  if Obj_ is TDF_ArrayInt64 then
      Result := TDF_ArrayInt64(Obj_)
  else
      Result := nil;
end;

procedure TDFE.ReadMem64(index_: Integer; output: TMem64);
var
  Obj_: TDF_Base;
  LNeedResetPos: Boolean;
begin
  Obj_ := Data[index_];
  LNeedResetPos := output.Size = 0;
  if Obj_ is TDF_Stream then
    begin
      with TDF_Stream(Obj_) do
        begin
          Buffer64.Position := 0;
          output.CopyFrom(Buffer64, Buffer64.Size);
          Buffer64.Position := 0;
        end;
    end
  else
      RaiseInfo('no support');
  if LNeedResetPos then
      output.Position := 0;
end;

procedure TDFE.ReadMem64_As_Mapping(index_: Integer; output: TMem64);
var
  Obj_: TDF_Base;
begin
  Obj_ := Data[index_];
  if Obj_ is TDF_Stream then
    begin
      with TDF_Stream(Obj_) do
        begin
          output.Mapping(Buffer64.Memory, Buffer64.Size);
        end;
    end
  else
      RaiseInfo('no support');
end;

procedure TDFE.ReadMS64_As_Mapping(index_: Integer; output: TMS64);
var
  Obj_: TDF_Base;
begin
  Obj_ := Data[index_];
  if Obj_ is TDF_Stream then
    begin
      with TDF_Stream(Obj_) do
        begin
          output.Mapping(Buffer64.Memory, Buffer64.Size);
        end;
    end
  else
      RaiseInfo('no support');
end;

procedure TDFE.ReadStream(index_: Integer; output: TCore_Stream);
var
  Obj_: TDF_Base;
  LNeedResetPos: Boolean;
begin
  Obj_ := Data[index_];
  LNeedResetPos := output.Size = 0;
  if Obj_ is TDF_Stream then
    begin
      with TDF_Stream(Obj_) do
        begin
          if (output is TMS64) and (output.Size = 0) then
            begin
              output.Size := Buffer.Size;
              output.Position := 0;
            end;
          Buffer64.Position := 0;
          output.CopyFrom(Buffer64, Buffer64.Size);
          Buffer64.Position := 0;
        end;
    end
  else if output is TMS64 then
      Obj_.SaveToStream(TMS64(output))
  else
      RaiseInfo('no support');
  if LNeedResetPos then
      output.Position := 0;
end;

function TDFE.ReadVariant(index_: Integer): Variant;
var
  Obj_: TDF_Base;
begin
  Obj_ := Data[index_];
  if Obj_ is TDF_Variant then
      Result := TDF_Variant(Obj_).Buffer
  else if Obj_ is TDF_String then
      Result := TDF_String(Obj_).Buffer
  else if Obj_ is TDF_Integer then
      Result := TDF_Integer(Obj_).Buffer
  else if Obj_ is TDF_Cardinal then
      Result := TDF_Cardinal(Obj_).Buffer
  else if Obj_ is TDF_Word then
      Result := TDF_Word(Obj_).Buffer
  else if Obj_ is TDF_Byte then
      Result := TDF_Byte(Obj_).Buffer
  else if Obj_ is TDF_Single then
      Result := TDF_Single(Obj_).Buffer
  else if Obj_ is TDF_Double then
      Result := TDF_Double(Obj_).Buffer
  else if Obj_ is TDF_Int64 then
      Result := (TDF_Int64(Obj_).Buffer)
  else if Obj_ is TDF_Int128 then
      Result := TDF_Int128(Obj_).Buffer.ToString.Text
  else if Obj_ is TDF_UInt128 then
      Result := TDF_UInt128(Obj_).Buffer.ToString.Text
  else
      Result := 0;
end;

function TDFE.ReadInt64(index_: Integer): Int64;
var
  Obj_: TDF_Base;
begin
  Obj_ := Data[index_];
  if Obj_ is TDF_Int64 then
      Result := TDF_Int64(Obj_).Buffer
  else if Obj_ is TDF_UInt64 then
      Result := TDF_UInt64(Obj_).Buffer
  else if Obj_ is TDF_Int128 then
      Result := TDF_Int128(Obj_).Buffer.ToInt64
  else if Obj_ is TDF_UInt128 then
      Result := TDF_UInt128(Obj_).Buffer.ToInt64
  else if Obj_ is TDF_Integer then
      Result := TDF_Integer(Obj_).Buffer
  else if Obj_ is TDF_Cardinal then
      Result := TDF_Cardinal(Obj_).Buffer
  else if Obj_ is TDF_Word then
      Result := TDF_Word(Obj_).Buffer
  else if Obj_ is TDF_Byte then
      Result := TDF_Byte(Obj_).Buffer
  else if Obj_ is TDF_Single then
      Result := Trunc(TDF_Single(Obj_).Buffer)
  else if Obj_ is TDF_Double then
      Result := Trunc(TDF_Double(Obj_).Buffer)
  else if Obj_ is TDF_Variant then
      Result := TDF_Variant(Obj_).Buffer
  else
      Result := 0;
end;

function TDFE.ReadUInt64(index_: Integer): UInt64;
var
  Obj_: TDF_Base;
begin
  Obj_ := Data[index_];
  if Obj_ is TDF_UInt64 then
      Result := TDF_UInt64(Obj_).Buffer
  else if Obj_ is TDF_Int64 then
      Result := TDF_Int64(Obj_).Buffer
  else if Obj_ is TDF_Int128 then
      Result := TDF_Int128(Obj_).Buffer.ToUInt64
  else if Obj_ is TDF_UInt128 then
      Result := TDF_UInt128(Obj_).Buffer.ToUInt64
  else if Obj_ is TDF_Integer then
      Result := TDF_Integer(Obj_).Buffer
  else if Obj_ is TDF_Cardinal then
      Result := TDF_Cardinal(Obj_).Buffer
  else if Obj_ is TDF_Word then
      Result := TDF_Word(Obj_).Buffer
  else if Obj_ is TDF_Byte then
      Result := TDF_Byte(Obj_).Buffer
  else if Obj_ is TDF_Single then
      Result := Trunc(TDF_Single(Obj_).Buffer)
  else if Obj_ is TDF_Double then
      Result := Trunc(TDF_Double(Obj_).Buffer)
  else if Obj_ is TDF_Variant then
      Result := TDF_Variant(Obj_).Buffer
  else
      Result := 0;
end;

function TDFE.ReadArrayInt128(index_: Integer): TDF_ArrayInt128;
var
  Obj_: TDF_Base;
begin
  Obj_ := Data[index_];
  if Obj_ is TDF_ArrayInt128 then
      Result := TDF_ArrayInt128(Obj_)
  else
      Result := nil;
end;

function TDFE.ReadInt128(index_: Integer): Int128;
var
  Obj_: TDF_Base;
begin
  Obj_ := Data[index_];
  if Obj_ is TDF_Int128 then
      Result := TDF_Int128(Obj_).Buffer
  else if Obj_ is TDF_UInt128 then
      Result := TDF_UInt128(Obj_).Buffer
  else if Obj_ is TDF_String then
      Result := umlStringOf(TDF_String(Obj_).Buffer).Text
  else if Obj_ is TDF_Int64 then
      Result := TDF_Int64(Obj_).Buffer
  else if Obj_ is TDF_UInt64 then
      Result := TDF_UInt64(Obj_).Buffer
  else if Obj_ is TDF_Integer then
      Result := TDF_Integer(Obj_).Buffer
  else if Obj_ is TDF_Cardinal then
      Result := TDF_Cardinal(Obj_).Buffer
  else if Obj_ is TDF_Word then
      Result := TDF_Word(Obj_).Buffer
  else if Obj_ is TDF_Byte then
      Result := TDF_Byte(Obj_).Buffer
  else if Obj_ is TDF_Single then
      Result := Trunc(TDF_Single(Obj_).Buffer)
  else if Obj_ is TDF_Double then
      Result := Trunc(TDF_Double(Obj_).Buffer)
  else if Obj_ is TDF_Variant then
      Result := VarToStr(TDF_Variant(Obj_).Buffer)
  else
      Result := 0;
end;

function TDFE.ReadUInt128(index_: Integer): UInt128;
var
  Obj_: TDF_Base;
begin
  Obj_ := Data[index_];
  if Obj_ is TDF_UInt128 then
      Result := TDF_UInt128(Obj_).Buffer
  else if Obj_ is TDF_Int128 then
      Result := TDF_Int128(Obj_).Buffer
  else if Obj_ is TDF_String then
      Result := umlStringOf(TDF_String(Obj_).Buffer).Text
  else if Obj_ is TDF_Int64 then
      Result := TDF_Int64(Obj_).Buffer
  else if Obj_ is TDF_UInt64 then
      Result := TDF_UInt64(Obj_).Buffer
  else if Obj_ is TDF_Integer then
      Result := TDF_Integer(Obj_).Buffer
  else if Obj_ is TDF_Cardinal then
      Result := TDF_Cardinal(Obj_).Buffer
  else if Obj_ is TDF_Word then
      Result := TDF_Word(Obj_).Buffer
  else if Obj_ is TDF_Byte then
      Result := TDF_Byte(Obj_).Buffer
  else if Obj_ is TDF_Single then
      Result := Trunc(TDF_Single(Obj_).Buffer)
  else if Obj_ is TDF_Double then
      Result := Trunc(TDF_Double(Obj_).Buffer)
  else if Obj_ is TDF_Variant then
      Result := VarToStr(TDF_Variant(Obj_).Buffer)
  else
      Result := 0;
end;

procedure TDFE.ReadStrings(index_: Integer; output: TCore_Strings);
var
  m64: TMS64;
begin
  m64 := TMS64.Create;
  ReadMS64_As_Mapping(index_, m64);
  m64.Position := 0;

{$IFDEF FPC}
  output.LoadFromStream(m64);
{$ELSE}
  output.LoadFromStream(m64, TEncoding.UTF8);
{$ENDIF}
  DisposeObject(m64);
end;

procedure TDFE.ReadListStrings(index_: Integer; output: TListString);
var
  m64: TMS64;
begin
  m64 := TMS64.Create;
  ReadMS64_As_Mapping(index_, m64);
  m64.Position := 0;

  output.LoadFromStream(m64);
  DisposeObject(m64);
end;

procedure TDFE.ReadPascalStrings(index_: Integer; output: TPascalStringList);
var
  m64: TMS64;
begin
  m64 := TMS64.Create;
  ReadMS64_As_Mapping(index_, m64);
  m64.Position := 0;

  output.LoadFromStream(m64);
  DisposeObject(m64);
end;

procedure TDFE.ReadPascalStrings(index_: Integer; var output: U_StringArray);
var
  L: TPascalStringList;
  i: Integer;
begin
  L := TPascalStringList.Create;
  ReadPascalStrings(index_, L);
  SetLength(output, L.Count);
  for i := 0 to L.Count - 1 do
      output[i] := L[i];
  DisposeObject(L);
end;

procedure TDFE.ReadDataFrame(index_: Integer; output: TDFE);
var
  Obj_: TDF_Base;
  m64: TMS64;
begin
  Obj_ := Data[index_];
  if Obj_ is TDF_Stream then
    begin
      TDF_Stream(Obj_).Buffer.Position := 0;
      output.DecodeFrom(TDF_Stream(Obj_).Buffer, True);
      TDF_Stream(Obj_).Buffer.Position := 0;
    end
  else
    begin
      m64 := TMS64.Create;
      ReadStream(index_, m64);
      m64.Position := 0;
      output.DecodeFrom(m64, True);
      DisposeObject(m64);
    end;
end;

procedure TDFE.ReadDF(index_: Integer; output: TDFE);
begin
  ReadDataFrame(index_, output);
end;

procedure TDFE.ReadDFE(index_: Integer; output: TDFE);
begin
  ReadDataFrame(index_, output);
end;

procedure TDFE.ReadHashStringList(index_: Integer; output: THashStringList);
var
  m64: TMS64;
  hash_: THashStringTextStream;
begin
  m64 := TMS64.Create;
  ReadMS64_As_Mapping(index_, m64);
  m64.Position := 0;
  hash_ := THashStringTextStream.Create(output);
  hash_.LoadFromStream(m64);
  DisposeObject(hash_);
  DisposeObject(m64);
end;

procedure TDFE.ReadVariantList(index_: Integer; output: THashVariantList);
var
  m64: TMS64;
  hash_: THashVariantTextStream;
begin
  m64 := TMS64.Create;
  ReadMS64_As_Mapping(index_, m64);
  m64.Position := 0;
  hash_ := THashVariantTextStream.Create(output);
  hash_.LoadFromStream(m64);
  DisposeObject(hash_);
  DisposeObject(m64);
end;

procedure TDFE.ReadJson(index_: Integer; output: TZ_JsonObject);
var
  m64: TMS64;
begin
  m64 := TMS64.Create;
  ReadMS64_As_Mapping(index_, m64);
  m64.Position := 0;
  output.Clear;
  output.LoadFromStream(m64);
  DisposeObject(m64);
end;

{$IFDEF DELPHI}


procedure TDFE.ReadJson(index_: Integer; output: TJsonObject);
var
  m64: TMS64;
begin
  m64 := TMS64.Create;
  ReadMS64_As_Mapping(index_, m64);
  m64.Position := 0;
  output.Clear;
  output.LoadFromStream(m64, TEncoding.UTF8, True);
  DisposeObject(m64);
end;

{$ENDIF DELPHI}


function TDFE.ReadRect(index_: Integer): TRect;
begin
  with ReadArrayInteger(index_) do
    begin
      Result := Rect(Buffer[0], Buffer[1], Buffer[2], Buffer[3]);
    end;
end;

function TDFE.ReadRectf(index_: Integer): TRectf;
begin
  with ReadArraySingle(index_) do
    begin
      Result := Rectf(Buffer[0], Buffer[1], Buffer[2], Buffer[3]);
    end;
end;

function TDFE.ReadPoint(index_: Integer): TPoint;
begin
  with ReadArrayInteger(index_) do
    begin
      Result := Point(Buffer[0], Buffer[1]);
    end;
end;

function TDFE.ReadPointf(index_: Integer): TPointf;
begin
  with ReadArraySingle(index_) do
    begin
      Result := Pointf(Buffer[0], Buffer[1]);
    end;
end;

function TDFE.ReadVector(index_: Integer): TVector;
begin
  with ReadArraySingle(index_) do
    begin
      Result[0] := Buffer[0];
      Result[1] := Buffer[1];
      Result[2] := Buffer[2];
      Result[3] := Buffer[3];
    end;
end;

function TDFE.ReadAffineVector(index_: Integer): TAffineVector;
begin
  with ReadArraySingle(index_) do
    begin
      Result[0] := Buffer[0];
      Result[1] := Buffer[1];
      Result[2] := Buffer[2];
    end;
end;

function TDFE.ReadVec3(index_: Integer): TVec3;
begin
  with ReadArraySingle(index_) do
    begin
      Result[0] := Buffer[0];
      Result[1] := Buffer[1];
      Result[2] := Buffer[2];
    end;
end;

function TDFE.ReadVec4(index_: Integer): TVec4;
begin
  with ReadArraySingle(index_) do
    begin
      Result[0] := Buffer[0];
      Result[1] := Buffer[1];
      Result[2] := Buffer[2];
      Result[3] := Buffer[3];
    end;
end;

function TDFE.ReadVector3(index_: Integer): TVector3;
begin
  with ReadArraySingle(index_) do
    begin
      Result := Vector3(Buffer[0], Buffer[1], Buffer[2]);
    end;
end;

function TDFE.ReadVector4(index_: Integer): TVector4;
begin
  with ReadArraySingle(index_) do
    begin
      Result := Vector4(Buffer[0], Buffer[1], Buffer[2], Buffer[3]);
    end;
end;

function TDFE.ReadMat4(index_: Integer): TMat4;
var
  i, j: Integer;
begin
  with ReadArraySingle(index_) do
    begin
      for i := 0 to 3 do
        for j := 0 to 3 do
            Result[i][j] := Buffer[i * 4 + j];
    end;
end;

function TDFE.ReadMatrix4(index_: Integer): TMatrix4;
begin
  Result.buff := ReadMat4(index_);
end;

function TDFE.Read2DPoint(index_: Integer): T2DPoint;
begin
  with ReadArraySingle(index_) do
    begin
      Result[0] := Buffer[0];
      Result[1] := Buffer[1];
    end;
end;

function TDFE.ReadVec2(index_: Integer): TVec2;
begin
  Result := Read2DPoint(index_);
end;

function TDFE.ReadRectV2(index_: Integer): TRectV2;
begin
  with ReadArraySingle(index_) do
    begin
      Result[0][0] := Buffer[0];
      Result[0][1] := Buffer[1];
      Result[1][0] := Buffer[2];
      Result[1][1] := Buffer[3];
    end;
end;

function TDFE.ReadPointer(index_: Integer): UInt64;
begin
  Result := ReadUInt64(index_);
end;

function TDFE.ReadPtr(index_: Integer): UInt64;
begin
  Result := ReadUInt64(index_);
end;

procedure TDFE.Read(index_: Integer; var Buf_; Count_: Int64);
var
  s: TMS64;
begin
  s := TMS64.Create;
  ReadStream(index_, s);
  s.Read64(Buf_, Count_);
  DisposeObject(s);
end;

procedure TDFE.ReadNM(index_: Integer; output: TNumberModule);
var
  D_: TDFE;
begin
  D_ := TDFE.Create;
  ReadDataFrame(index_, D_);
  output.Name := D_.Reader.ReadString;
  output.DirectOrigin := D_.Reader.ReadVariant;
  output.DirectValue := D_.Reader.ReadVariant;
  DisposeObject(D_);
end;

procedure TDFE.ReadNMPool(index_: Integer; output: TNumberModulePool);
var
  D_, Tmp_: TDFE;
  DM: TNumberModule;
  N_: SystemString;
  L_: TCore_ListForObj;
  i: Integer;
begin
  L_ := TCore_ListForObj.Create;
  D_ := TDFE.Create;
  ReadDataFrame(index_, D_);
  while D_.Reader.NotEnd do
    begin
      Tmp_ := TDFE.Create;
      D_.Reader.ReadDataFrame(Tmp_);
      N_ := Tmp_.Reader.ReadString;
      DM := output[N_];
      DM.Name := N_;
      DM.DirectOrigin := Tmp_.Reader.ReadVariant;
      DM.DirectValue := Tmp_.Reader.ReadVariant;
      L_.Add(DM);
      DisposeObject(Tmp_);
    end;
  DisposeObject(D_);
  for i := 0 to L_.Count - 1 do
    begin
      DM := TNumberModule(L_[i]);
      DM.DoChange;
    end;
  DisposeObject(L_);
end;

procedure TDFE.ReadOpCode(index_: Integer; output: TOpCode);
var
  m64: TMS64;
begin
  m64 := TMS64.Create;
  ReadMS64_As_Mapping(index_, m64);
  m64.Position := 0;
  TOpCode.LoadFromStream(m64, output);
  DisposeObject(m64);
end;

procedure TDFE.ReadSectionText(index_: Integer; output: THashTextEngine);
var
  m64: TMS64;
begin
  m64 := TMS64.Create;
  ReadMS64_As_Mapping(index_, m64);
  m64.Position := 0;
  output.LoadFromStream(m64);
  DisposeObject(m64);
end;

procedure TDFE.ReadTextSection(index_: Integer; output: THashTextEngine);
begin
  ReadSectionText(index_, output);
end;

function TDFE.Read(index_: Integer): TDF_Base;
begin
  Result := Data[index_];
end;

function TDFE.ComputeEncodeSize: Int64;
var
  i: Integer;
begin
  Result := C_Integer_Size;
  for i := 0 to Count - 1 do
      Result := Result + C_Byte_Size + GetData(i).ComputeEncodeSize;
end;

class procedure TDFE.BuildEmptyStream(output: TCore_Stream);
type
  THead32_ = packed record
    EditionToken: Byte;
    sizeInfo: Cardinal;
    compToken: Byte;
    md5: TMD5;
    num: Integer;
  end;
var
  head_: THead32_;
begin
  // make header
  head_.EditionToken := C_Bit_32;
  head_.sizeInfo := C_Integer_Size;
  head_.compToken := C_None_Compress;
  head_.md5 := NullMD5;
  head_.num := 0;
  output.write(head_, SizeOf(THead32_));
end;

function TDFE.FastEncode32To(output: TCore_Stream; SizeInfo32: Cardinal): Integer;
type
  THead32_ = packed record
    EditionToken: Byte;
    SizeInfo32: Cardinal;
    compToken: Byte;
    md5: TMD5;
  end;
var
  head_: THead32_;
  i: Integer;
  DataFrame_: TDF_Base;
  ID: Byte;
begin
  Result := Count;

  if Result = 0 then
    begin
      BuildEmptyStream(output);
      exit;
    end;

  // make header
  head_.EditionToken := C_Bit_32;
  head_.SizeInfo32 := SizeInfo32;
  head_.compToken := C_None_Compress;
  head_.md5 := NullMD5;

  // write header
  output.write(head_, SizeOf(THead32_));

  // write body
  output.write(Result, C_Integer_Size);
  for i := 0 to Count - 1 do
    begin
      DataFrame_ := GetData(i);
      ID := DataFrame_.FID;
      output.write(DataFrame_.FID, C_Byte_Size);
      DataFrame_.SaveToStream(output);
    end;
end;

function TDFE.FastEncode64To(output: TCore_Stream; SizeInfo64: Int64): Integer;
type
  THead64_ = packed record
    EditionToken: Byte;
    SizeInfo64: Int64;
    compToken: Byte;
    md5: TMD5;
  end;
var
  head_: THead64_;
  i: Integer;
  DataFrame_: TDF_Base;
  ID: Byte;
begin
  Result := Count;

  if Result = 0 then
    begin
      BuildEmptyStream(output);
      exit;
    end;

  // make header
  head_.EditionToken := C_Bit_64;
  head_.SizeInfo64 := SizeInfo64;
  head_.compToken := C_None_Compress;
  head_.md5 := NullMD5;

  // write header
  output.write(head_, SizeOf(THead64_));

  // write body
  output.write(Result, C_Integer_Size);
  for i := 0 to Count - 1 do
    begin
      DataFrame_ := GetData(i);
      ID := DataFrame_.FID;
      output.write(DataFrame_.FID, C_Byte_Size);
      DataFrame_.SaveToStream(output);
    end;
end;

function TDFE.FastEncodeTo(output: TCore_Stream): Integer;
var
  SizeInfo64: Int64;
begin
  SizeInfo64 := ComputeEncodeSize;
  if (output is TMS64) then
      TMS64(output).Delta := umlMax(TMS64(output).Delta, SizeInfo64);
  if SizeInfo64 > FBit_64_Condition then
      Result := FastEncode64To(output, SizeInfo64)
  else
      Result := FastEncode32To(output, SizeInfo64);
end;

function TDFE.EncodeTo(output: TCore_Stream; const FastMode, AutoCompressed: Boolean): Integer;
var
  i: Integer;
  DataFrame_: TDF_Base;
  StoreStream, nStream: TMS64;
  ID: Byte;

  EditionToken: Byte;
  SizeInfo32: Cardinal;
  SizeInfo64: Int64;
  compToken: Byte;
  md5: TMD5;
begin
  Result := Count;

  if Result = 0 then
    begin
      BuildEmptyStream(output);
      exit;
    end;

  // if encode size too large(>1M), we use EncodeAsSelectCompressor
  if (AutoCompressed) and (ComputeEncodeSize > 1024 * 1024) then
    begin
      Result := EncodeAsSelectCompressor(TSelectCompressionMethod.scmZLIB_Fast, output, FastMode);
      exit;
    end;

  if FastMode and (not AutoCompressed) then
    begin
      Result := FastEncodeTo(output);
      exit;
    end;

  StoreStream := TMS64.CustomCreate(8192);

  // make body
  StoreStream.Write64(Result, C_Integer_Size);

  nStream := TMS64.Create;
  for i := 0 to Count - 1 do
    begin
      DataFrame_ := GetData(i);
      ID := DataFrame_.FID;
      DataFrame_.SaveToStream(nStream);

      StoreStream.Write64(ID, C_Byte_Size);
      nStream.Position := 0;
      StoreStream.CopyFrom(nStream, nStream.Size);
      nStream.Clear;
    end;

  // make header
  SizeInfo32 := Cardinal(StoreStream.Size);
  SizeInfo64 := StoreStream.Size;
  if SizeInfo64 > FBit_64_Condition then
      EditionToken := C_Bit_64
  else
      EditionToken := C_Bit_32;
  compToken := C_None_Compress;
  StoreStream.Position := 0;
  if FastMode then
      md5 := NullMD5
  else
      md5 := umlMD5(StoreStream.Memory, StoreStream.Size);

  // prepare write header
  nStream.Clear;
  nStream.write(EditionToken, C_Byte_Size);
  if SizeInfo64 > FBit_64_Condition then
      nStream.write(SizeInfo64, C_Int64_Size)
  else
      nStream.write(SizeInfo32, C_Cardinal_Size);
  nStream.write(compToken, C_Byte_Size);
  nStream.write(md5[0], C_MD5_Size);

  // write header
  nStream.Position := 0;
  output.CopyFrom(nStream, nStream.Size);
  DisposeObject(nStream);

  // write body
  StoreStream.Position := 0;
  output.CopyFrom(StoreStream, StoreStream.Size);
  DisposeObject(StoreStream);
end;

function TDFE.EncodeTo(output: TCore_Stream; const FastMode: Boolean): Integer;
begin
  Result := EncodeTo(output, FastMode, True);
end;

function TDFE.EncodeTo(output: TCore_Stream): Integer;
begin
  Result := EncodeTo(output, False);
end;

procedure TDFE.Encrypt(output: TCore_Stream; Compressed_: Boolean; SecurityLevel: Integer; Key: TCipherKeyBuffer);
var
  m64: TMS64;
begin
  m64 := TMS64.Create;
  if Compressed_ then
      EncodeAsSelectCompressor(m64, True)
  else
      EncodeTo(m64, True);

  QuantumEncrypt(m64, output, SecurityLevel, Key);
  DisposeObject(m64);
end;

function TDFE.Decrypt(input: TCore_Stream; Key: TCipherKeyBuffer): Boolean;
var
  m64: TMS64;
begin
  if input.Size = 0 then
    begin
      Result := False;
      exit;
    end;
  m64 := TMS64.Create;
  Result := QuantumDecrypt(input, m64, Key);
  if Result then
    begin
      m64.Position := 0;
      DecodeFrom(m64, True);
    end;

  DisposeObject(m64);
end;

procedure TDFE.EncodeAsPublicJson(var output: TPascalString);
var
  m64: TMS64;
  buff: TBytes;
begin
  m64 := TMS64.Create;
  EncodeAsPublicJson(m64);
  SetLength(buff, m64.Size);
  CopyPtr(m64.Memory, @buff[0], m64.Size);
  DisposeObject(m64);
  output.Bytes := buff;
  SetLength(buff, 0);
end;

procedure TDFE.EncodeAsPublicJson(output: TCore_Stream);
var
  j: TZ_JsonObject;
  i: Integer;
begin
  j := TZ_JsonObject.Create;
  j.s['help'] := 'This JSON with TDFE encode';

  for i := 0 to Count - 1 do
    begin
      j.A['Ref'].Add(TDF_Base(FDataList[i]).FID);
      TDF_Base(FDataList[i]).SaveToJson(j.A['Data'], i);
    end;

  j.SaveToStream(output, True);

  DisposeObject(j);
end;

procedure TDFE.EncodeAsJson(output: TCore_Stream);
var
  j: TZ_JsonObject;
  i: Integer;
  DataFrame_: TDF_Base;
begin
  j := TZ_JsonObject.Create;

  for i := 0 to Count - 1 do
    begin
      DataFrame_ := TDF_Base(FDataList[i]);
      DataFrame_.SaveToJson(j.A['Data'], i);
      j.A['Ref'].Add(DataFrame_.FID);
    end;

  j.SaveToStream(output, False);

  DisposeObject(j);
end;

procedure TDFE.EncodeAsJson(Json: TZ_JsonObject);
var
  i: Integer;
  DataFrame_: TDF_Base;
begin
  Json.Clear;
  for i := 0 to Count - 1 do
    begin
      DataFrame_ := TDF_Base(FDataList[i]);
      DataFrame_.SaveToJson(Json.A['Data'], i);
      Json.A['Ref'].Add(DataFrame_.FID);
    end;
end;

procedure TDFE.DecodeFromJson(stream: TCore_Stream);
var
  j: TZ_JsonObject;
  t: Byte;
  i: Integer;
  DataFrame_: TDF_Base;
begin
  Clear;
  j := TZ_JsonObject.Create;
  try
      j.LoadFromStream(stream);
  except
    DisposeObject(j);
    exit;
  end;

  try
    for i := 0 to j.A['Ref'].Count - 1 do
      begin
        t := j.A['Ref'].i[i];
        DataFrame_ := AddData(ByteToDataType(t));
        DataFrame_.LoadFromJson(j.A['Data'], i);
      end;
  except
    DisposeObject(j);
    exit;
  end;

  DisposeObject(j);
end;

procedure TDFE.DecodeFromJson(const s: TPascalString);
var
  buff: TBytes;
  m64: TMS64;
begin
  buff := s.Bytes;
  m64 := TMS64.Create;
  m64.SetPointerWithProtectedMode(@buff[0], length(buff));
  m64.Position := 0;
  DecodeFromJson(m64);
  DisposeObject(m64);
  SetLength(buff, 0);
end;

procedure TDFE.DecodeFromJson(Json: TZ_JsonObject);
var
  t: Byte;
  i: Integer;
  DataFrame_: TDF_Base;
begin
  Clear;

  for i := 0 to Json.A['Ref'].Count - 1 do
    begin
      t := Json.A['Ref'].i[i];
      DataFrame_ := AddData(ByteToDataType(t));
      DataFrame_.LoadFromJson(Json.A['Data'], i);
    end;
end;

function TDFE.EncodeAsSelectCompressor(scm: TSelectCompressionMethod; output: TCore_Stream; const FastMode: Boolean): Integer;
var
  i: Integer;
  DataFrame_: TDF_Base;
  StoreStream, nStream, compStream: TMS64;
  ID: Byte;

  EditionToken: Byte;
  SizeInfo32: Cardinal;
  SizeInfo64: Int64;
  compToken: Byte;
  CompSizeInfo32: Cardinal;
  CompSizeInfo64: Int64;
  md5: TMD5;
begin
  Result := Count;

  if Result = 0 then
    begin
      BuildEmptyStream(output);
      exit;
    end;

  StoreStream := TMS64.CustomCreate(8192);

  // make body
  StoreStream.Write64(Result, C_Integer_Size);

  nStream := TMS64.Create;
  for i := 0 to Count - 1 do
    begin
      DataFrame_ := GetData(i);
      ID := DataFrame_.FID;
      DataFrame_.SaveToStream(nStream);

      StoreStream.Write64(ID, C_Byte_Size);
      nStream.Position := 0;
      StoreStream.CopyFrom(nStream, nStream.Size);
      nStream.Clear;
    end;

  // compress body and make header
  CompSizeInfo32 := Cardinal(StoreStream.Size);
  CompSizeInfo64 := StoreStream.Size;
  StoreStream.Position := 0;
  if FastMode then
      md5 := NullMD5
  else
      md5 := umlMD5(StoreStream.Memory, StoreStream.Size);

  compStream := TMS64.CustomCreate(64 * 1024);
  ParallelCompressMemory(scm, StoreStream, compStream);
  DisposeObject(StoreStream);

  // make header
  SizeInfo32 := Cardinal(compStream.Size);
  SizeInfo64 := compStream.Size;
  if SizeInfo64 > FBit_64_Condition then
      EditionToken := C_Bit_64
  else
      EditionToken := C_Bit_32;
  if CompSizeInfo64 > FBit_64_Condition then
      compToken := C_Parallel_64_Compress
  else
      compToken := C_Parallel_32_Compress;

  // prepare write header
  nStream.Clear;
  nStream.write(EditionToken, C_Byte_Size);
  if SizeInfo64 > FBit_64_Condition then
      nStream.write(SizeInfo64, C_Int64_Size)
  else
      nStream.write(SizeInfo32, C_Cardinal_Size);
  nStream.write(compToken, C_Byte_Size);
  if CompSizeInfo64 > FBit_64_Condition then
      nStream.write(CompSizeInfo64, C_Int64_Size)
  else
      nStream.write(CompSizeInfo32, C_Cardinal_Size);
  nStream.write(md5[0], C_MD5_Size);

  // write header
  nStream.Position := 0;
  output.CopyFrom(nStream, nStream.Size);
  DisposeObject(nStream);

  // write body
  compStream.Position := 0;
  output.CopyFrom(compStream, compStream.Size);
  DisposeObject(compStream);
end;

function TDFE.EncodeAsSelectCompressor(output: TCore_Stream; const FastMode: Boolean): Integer;
var
  scm: TSelectCompressionMethod;
begin
  if ComputeEncodeSize > 64 * 1024 then
    begin
      if FastMode then
          scm := TSelectCompressionMethod.scmZLIB_Fast
      else
          scm := TSelectCompressionMethod.scmZLIB_Max;
      Result := EncodeAsSelectCompressor(scm, output, FastMode);
    end
  else
      Result := EncodeAsZLib(output, FastMode);
end;

function TDFE.EncodeAsSelectCompressor(output: TCore_Stream): Integer;
begin
  Result := EncodeAsSelectCompressor(output, False);
end;

function TDFE.EncodeAsZLib(output: TCore_Stream; const FastMode, AutoCompressed: Boolean): Integer;
var
  i: Integer;
  DataFrame_: TDF_Base;
  StoreStream, nStream, compStream: TMS64;
  ZCompStream: TCompressionStream;
  ID: Byte;

  EditionToken: Byte;
  SizeInfo32: Cardinal;
  SizeInfo64: Int64;
  compToken: Byte;
  CompSizeInfo32: Cardinal;
  CompSizeInfo64: Int64;
  md5: TMD5;
begin
  Result := Count;

  if Result = 0 then
    begin
      BuildEmptyStream(output);
      exit;
    end;

  // if encode size too large(>1M), we use EncodeAsSelectCompressor
  if AutoCompressed and (ComputeEncodeSize > 1024 * 1024) then
    begin
      Result := EncodeAsSelectCompressor(TSelectCompressionMethod.scmZLIB, output, FastMode);
      exit;
    end;

  StoreStream := TMS64.CustomCreate(8192);

  // make body
  StoreStream.Write64(Result, C_Integer_Size);

  nStream := TMS64.Create;
  for i := 0 to Count - 1 do
    begin
      DataFrame_ := GetData(i);
      ID := DataFrame_.FID;
      DataFrame_.SaveToStream(nStream);

      StoreStream.Write64(ID, C_Byte_Size);
      nStream.Position := 0;
      StoreStream.CopyFrom(nStream, nStream.Size);
      nStream.Clear;
    end;

  // compress body and make header
  CompSizeInfo32 := Cardinal(StoreStream.Size);
  CompSizeInfo64 := StoreStream.Size;
  StoreStream.Position := 0;
  if FastMode then
      md5 := NullMD5
  else
      md5 := umlMD5(StoreStream.Memory, StoreStream.Size);

  compStream := TMS64.CustomCreate(64 * 1024);
  ZCompStream := TCompressionStream.Create(compStream);
  StoreStream.Position := 0;
  ZCompStream.CopyFrom(StoreStream, StoreStream.Size);
  DisposeObject(ZCompStream);
  DisposeObject(StoreStream);

  // make header
  SizeInfo32 := compStream.Size;
  SizeInfo64 := compStream.Size;
  if SizeInfo64 > FBit_64_Condition then
      EditionToken := C_Bit_64
  else
      EditionToken := C_Bit_32;
  if CompSizeInfo64 > FBit_64_Condition then
      compToken := C_ZLIB_64_Compress
  else
      compToken := C_ZLIB_32_Compress;

  // prepare write header
  nStream.Clear;
  nStream.write(EditionToken, C_Byte_Size);
  if SizeInfo64 > FBit_64_Condition then
      nStream.write(SizeInfo64, C_Int64_Size)
  else
      nStream.write(SizeInfo32, C_Cardinal_Size);
  nStream.write(compToken, C_Byte_Size);
  if CompSizeInfo64 > FBit_64_Condition then
      nStream.write(CompSizeInfo64, C_Int64_Size)
  else
      nStream.write(CompSizeInfo32, C_Cardinal_Size);
  nStream.write(md5[0], C_MD5_Size);

  // write header
  nStream.Position := 0;
  output.CopyFrom(nStream, nStream.Size);
  DisposeObject(nStream);

  // write body
  compStream.Position := 0;
  output.CopyFrom(compStream, compStream.Size);
  DisposeObject(compStream);
end;

function TDFE.EncodeAsZLib(output: TCore_Stream; const FastMode: Boolean): Integer;
begin
  Result := EncodeAsZLib(output, FastMode, True);
end;

function TDFE.EncodeAsZLib(output: TCore_Stream): Integer;
begin
  Result := EncodeAsZLib(output, False);
end;

function TDFE.EncodeAsDeflate(output: TCore_Stream; const FastMode, AutoCompressed: Boolean): Integer;
var
  i: Integer;
  DataFrame_: TDF_Base;
  StoreStream, nStream, compStream: TMS64;
  ID: Byte;

  EditionToken: Byte;
  SizeInfo32: Cardinal;
  SizeInfo64: Int64;
  compToken: Byte;
  CompSizeInfo32: Cardinal;
  CompSizeInfo64: Int64;
  md5: TMD5;
begin
  Result := Count;

  if Result = 0 then
    begin
      BuildEmptyStream(output);
      exit;
    end;

  // if encode size too large(>1M), we use EncodeAsSelectCompressor
  if AutoCompressed and (ComputeEncodeSize > 1024 * 1024) then
    begin
      Result := EncodeAsSelectCompressor(TSelectCompressionMethod.scmZLIB, output, FastMode);
      exit;
    end;

  StoreStream := TMS64.CustomCreate(8192);

  // make body
  StoreStream.Write64(Result, C_Integer_Size);

  nStream := TMS64.Create;
  for i := 0 to Count - 1 do
    begin
      DataFrame_ := GetData(i);
      ID := DataFrame_.FID;
      DataFrame_.SaveToStream(nStream);

      StoreStream.Write64(ID, C_Byte_Size);
      nStream.Position := 0;
      StoreStream.CopyFrom(nStream, nStream.Size);
      nStream.Clear;
    end;

  // compress body and make header
  CompSizeInfo32 := Cardinal(StoreStream.Size);
  CompSizeInfo64 := StoreStream.Size;
  StoreStream.Position := 0;
  if FastMode then
      md5 := NullMD5
  else
      md5 := umlMD5(StoreStream.Memory, StoreStream.Size);

  compStream := TMS64.Create;
  StoreStream.Position := 0;

  if FCompressorDeflate = nil then
      FCompressorDeflate := TCompressorDeflate.Create;

  CoreCompressStream(FCompressorDeflate, StoreStream, compStream);
  DisposeObject(StoreStream);

  // make header
  SizeInfo32 := Cardinal(compStream.Size);
  SizeInfo64 := compStream.Size;
  if SizeInfo64 > FBit_64_Condition then
      EditionToken := C_Bit_64
  else
      EditionToken := C_Bit_32;
  if CompSizeInfo64 > FBit_64_Condition then
      compToken := C_Deflate_64_Compress
  else
      compToken := C_Deflate_32_Compress;

  // prepare write header
  nStream.Clear;
  nStream.write(EditionToken, C_Byte_Size);
  if SizeInfo64 > FBit_64_Condition then
      nStream.write(SizeInfo64, C_Int64_Size)
  else
      nStream.write(SizeInfo32, C_Cardinal_Size);
  nStream.write(compToken, C_Byte_Size);
  if CompSizeInfo64 > FBit_64_Condition then
      nStream.write(CompSizeInfo64, C_Int64_Size)
  else
      nStream.write(CompSizeInfo32, C_Cardinal_Size);
  nStream.write(md5[0], C_MD5_Size);

  // write header
  nStream.Position := 0;
  output.CopyFrom(nStream, nStream.Size);
  DisposeObject(nStream);

  // write body
  compStream.Position := 0;
  output.CopyFrom(compStream, compStream.Size);
  DisposeObject(compStream);
end;

function TDFE.EncodeAsDeflate(output: TCore_Stream; const FastMode: Boolean): Integer;
begin
  Result := EncodeAsDeflate(output, FastMode, True);
end;

function TDFE.EncodeAsDeflate(output: TCore_Stream): Integer;
begin
  Result := EncodeAsDeflate(output, False);
end;

function TDFE.EncodeAsBRRC(output: TCore_Stream; const FastMode, AutoCompressed: Boolean): Integer;
var
  i: Integer;
  DataFrame_: TDF_Base;
  StoreStream, nStream, compStream: TMS64;
  ID: Byte;
  EditionToken: Byte;
  SizeInfo32: Cardinal;
  SizeInfo64: Int64;
  compToken: Byte;
  CompSizeInfo32: Cardinal;
  CompSizeInfo64: Int64;
  md5: TMD5;
begin
  Result := Count;

  if Result = 0 then
    begin
      BuildEmptyStream(output);
      exit;
    end;

  // if encode size too large(>1M), we use EncodeAsSelectCompressor
  if AutoCompressed and (ComputeEncodeSize > 1024 * 1024) then
    begin
      Result := EncodeAsSelectCompressor(TSelectCompressionMethod.scmZLIB, output, FastMode);
      exit;
    end;

  StoreStream := TMS64.CustomCreate(8192);

  // make body
  StoreStream.Write64(Result, C_Integer_Size);

  nStream := TMS64.Create;
  for i := 0 to Count - 1 do
    begin
      DataFrame_ := GetData(i);
      ID := DataFrame_.FID;
      DataFrame_.SaveToStream(nStream);

      StoreStream.Write64(ID, C_Byte_Size);
      nStream.Position := 0;
      StoreStream.CopyFrom(nStream, nStream.Size);
      nStream.Clear;
    end;

  // compress body and make header
  CompSizeInfo32 := Cardinal(StoreStream.Size);
  CompSizeInfo64 := StoreStream.Size;
  StoreStream.Position := 0;
  if FastMode then
      md5 := NullMD5
  else
      md5 := umlMD5(StoreStream.Memory, StoreStream.Size);

  compStream := TMS64.Create;
  StoreStream.Position := 0;

  if FCompressorBRRC = nil then
      FCompressorBRRC := TCompressorBRRC.Create;

  CoreCompressStream(FCompressorBRRC, StoreStream, compStream);
  DisposeObject(StoreStream);

  // make header
  SizeInfo32 := Cardinal(compStream.Size);
  SizeInfo64 := compStream.Size;
  if SizeInfo64 > FBit_64_Condition then
      EditionToken := C_Bit_64
  else
      EditionToken := C_Bit_32;
  if CompSizeInfo64 > FBit_64_Condition then
      compToken := C_BRRC_64_Compress
  else
      compToken := C_BRRC_32_Compress;

  // prepare write header
  nStream.Clear;
  nStream.write(EditionToken, C_Byte_Size);
  if SizeInfo64 > FBit_64_Condition then
      nStream.write(SizeInfo64, C_Int64_Size)
  else
      nStream.write(SizeInfo32, C_Cardinal_Size);
  nStream.write(compToken, C_Byte_Size);
  if CompSizeInfo64 > FBit_64_Condition then
      nStream.write(CompSizeInfo64, C_Int64_Size)
  else
      nStream.write(CompSizeInfo32, C_Cardinal_Size);
  nStream.write(md5[0], C_MD5_Size);

  // write header
  nStream.Position := 0;
  output.CopyFrom(nStream, nStream.Size);
  DisposeObject(nStream);

  // write body
  compStream.Position := 0;
  output.CopyFrom(compStream, compStream.Size);
  DisposeObject(compStream);
end;

function TDFE.EncodeAsBRRC(output: TCore_Stream; const FastMode: Boolean): Integer;
begin
  Result := EncodeAsBRRC(output, FastMode, True);
end;

function TDFE.EncodeAsBRRC(output: TCore_Stream): Integer;
begin
  Result := EncodeAsBRRC(output, False);
end;

function TDFE.EncodeAsLZ4(output: TCore_Stream; const FastMode: Boolean): Integer;
var
  i: Integer;
  DataFrame_: TDF_Base;
  StoreStream, nStream, compStream: TMS64;
  ID: Byte;

  EditionToken: Byte;
  SizeInfo32: Cardinal;
  SizeInfo64: Int64;
  compToken: Byte;
  CompSizeInfo32: Cardinal;
  CompSizeInfo64: Int64;
  md5: TMD5;
begin
  Result := Count;

  if Result = 0 then
    begin
      BuildEmptyStream(output);
      exit;
    end;

  StoreStream := TMS64.CustomCreate(8192);

  // make body
  StoreStream.Write64(Result, C_Integer_Size);

  nStream := TMS64.Create;
  for i := 0 to Count - 1 do
    begin
      DataFrame_ := GetData(i);
      ID := DataFrame_.FID;
      DataFrame_.SaveToStream(nStream);

      StoreStream.Write64(ID, C_Byte_Size);
      nStream.Position := 0;
      StoreStream.CopyFrom(nStream, nStream.Size);
      nStream.Clear;
    end;

  // compress body and make header
  CompSizeInfo32 := Cardinal(StoreStream.Size);
  CompSizeInfo64 := StoreStream.Size;
  StoreStream.Position := 0;
  if FastMode then
      md5 := NullMD5
  else
      md5 := umlMD5(StoreStream.Memory, StoreStream.Size);

  compStream := StoreStream.LZ4;
  DisposeObject(StoreStream);

  // make header
  SizeInfo32 := compStream.Size;
  SizeInfo64 := compStream.Size;
  if SizeInfo64 > FBit_64_Condition then
      EditionToken := C_Bit_64
  else
      EditionToken := C_Bit_32;

  if CompSizeInfo64 > FBit_64_Condition then
      compToken := C_LZ4_64_Compress
  else
      compToken := C_LZ4_32_Compress;

  // prepare write header
  nStream.Clear;
  nStream.write(EditionToken, C_Byte_Size);
  if SizeInfo64 > FBit_64_Condition then
      nStream.write(SizeInfo64, C_Int64_Size)
  else
      nStream.write(SizeInfo32, C_Cardinal_Size);
  nStream.write(compToken, C_Byte_Size);
  if CompSizeInfo64 > FBit_64_Condition then
      nStream.write(CompSizeInfo64, C_Int64_Size)
  else
      nStream.write(CompSizeInfo32, C_Cardinal_Size);
  nStream.write(md5[0], C_MD5_Size);

  // write header
  nStream.Position := 0;
  output.CopyFrom(nStream, nStream.Size);
  DisposeObject(nStream);

  // write body
  compStream.Position := 0;
  output.CopyFrom(compStream, compStream.Size);
  DisposeObject(compStream);
end;

function TDFE.EncodeAsLZ4(output: TCore_Stream): Integer;
begin
  Result := EncodeAsLZ4(output, False);
end;

function TDFE.EncodeAsSnappy(output: TCore_Stream; const FastMode: Boolean): Integer;
var
  i: Integer;
  DataFrame_: TDF_Base;
  StoreStream, nStream, compStream: TMS64;
  ID: Byte;

  EditionToken: Byte;
  SizeInfo32: Cardinal;
  SizeInfo64: Int64;
  compToken: Byte;
  CompSizeInfo32: Cardinal;
  CompSizeInfo64: Int64;
  md5: TMD5;
begin
  Result := Count;

  if Result = 0 then
    begin
      BuildEmptyStream(output);
      exit;
    end;

  StoreStream := TMS64.CustomCreate(8192);

  // make body
  StoreStream.Write64(Result, C_Integer_Size);

  nStream := TMS64.Create;
  for i := 0 to Count - 1 do
    begin
      DataFrame_ := GetData(i);
      ID := DataFrame_.FID;
      DataFrame_.SaveToStream(nStream);

      StoreStream.Write64(ID, C_Byte_Size);
      nStream.Position := 0;
      StoreStream.CopyFrom(nStream, nStream.Size);
      nStream.Clear;
    end;

  // compress body and make header
  CompSizeInfo32 := Cardinal(StoreStream.Size);
  CompSizeInfo64 := StoreStream.Size;
  StoreStream.Position := 0;
  if FastMode then
      md5 := NullMD5
  else
      md5 := umlMD5(StoreStream.Memory, StoreStream.Size);

  compStream := StoreStream.Snappy_Pas;
  DisposeObject(StoreStream);

  // make header
  SizeInfo32 := compStream.Size;
  SizeInfo64 := compStream.Size;
  if SizeInfo64 > FBit_64_Condition then
      EditionToken := C_Bit_64
  else
      EditionToken := C_Bit_32;

  if CompSizeInfo64 > FBit_64_Condition then
      compToken := C_SNAPPY_PAS_64_Compress
  else
      compToken := C_SNAPPY_PAS_32_Compress;

  // prepare write header
  nStream.Clear;
  nStream.write(EditionToken, C_Byte_Size);
  if SizeInfo64 > FBit_64_Condition then
      nStream.write(SizeInfo64, C_Int64_Size)
  else
      nStream.write(SizeInfo32, C_Cardinal_Size);
  nStream.write(compToken, C_Byte_Size);
  if CompSizeInfo64 > FBit_64_Condition then
      nStream.write(CompSizeInfo64, C_Int64_Size)
  else
      nStream.write(CompSizeInfo32, C_Cardinal_Size);
  nStream.write(md5[0], C_MD5_Size);

  // write header
  nStream.Position := 0;
  output.CopyFrom(nStream, nStream.Size);
  DisposeObject(nStream);

  // write body
  compStream.Position := 0;
  output.CopyFrom(compStream, compStream.Size);
  DisposeObject(compStream);
end;

function TDFE.EncodeAsSnappy(output: TCore_Stream): Integer;
begin
  Result := EncodeAsSnappy(output, False);
end;

function TDFE.IsCompressed(source: TCore_Stream): Boolean;
var
  bakPos: Int64;
  EditionToken: Byte;
  SizeInfo32: Cardinal;
  SizeInfo64, sizeInfo: Int64;
  compToken: Byte;
begin
  bakPos := source.Position;
  Result := False;

  source.Read(EditionToken, C_Byte_Size);
  if (EditionToken in [C_Bit_32, C_Bit_64]) then
    begin
      if EditionToken = C_Bit_32 then
        begin
          source.Read(SizeInfo32, C_Cardinal_Size);
          sizeInfo := SizeInfo32;
        end
      else
        begin
          source.Read(SizeInfo64, C_Int64_Size);
          sizeInfo := SizeInfo64;
        end;

      source.Read(compToken, C_Byte_Size);

      Result := compToken in [
        C_ZLIB_32_Compress, C_ZLIB_64_Compress,
        C_Deflate_32_Compress, C_Deflate_64_Compress,
        C_BRRC_32_Compress, C_BRRC_64_Compress,
        C_Parallel_32_Compress, C_Parallel_64_Compress,
        C_LZ4_32_Compress, C_LZ4_64_Compress,
        C_SNAPPY_PAS_32_Compress, C_SNAPPY_PAS_64_Compress
        ]
    end;

  source.Position := bakPos;
end;

function TDFE.DecodeFrom(source: TCore_Stream; const FastMode: Boolean; const Max_Limit_Decode: Integer): Integer;
var
  i, num_: Integer;
  ID: Byte;
  StoreStream: TMS64;
  tmpStream: TMS64;
  ZDecompStream: TDecompressionStream;
  DataFrame_: TDF_Base;

  EditionToken: Byte;
  SizeInfo32: Cardinal;
  SizeInfo64, sizeInfo: Int64;
  compToken: Byte;
  CompSizeInfo32: Cardinal;
  CompSizeInfo64, compsizeInfo: Int64;
  MD5_: TMD5;
begin
  Clear;

  Result := -1;
  if source.Read(EditionToken, C_Byte_Size) <> C_Byte_Size then
      exit;

  StoreStream := TMS64.CustomCreate(64 * 1024);

  if (EditionToken in [C_Bit_32, C_Bit_64]) then
    begin
      if EditionToken = C_Bit_32 then
        begin
          if source.Read(SizeInfo32, C_Cardinal_Size) <> C_Cardinal_Size then
            begin
              DisposeObject(StoreStream);
              exit;
            end;
          sizeInfo := SizeInfo32;
        end
      else
        begin
          if source.Read(SizeInfo64, C_Int64_Size) <> C_Int64_Size then
            begin
              DisposeObject(StoreStream);
              exit;
            end;
          sizeInfo := SizeInfo64;
        end;

      source.Read(compToken, C_Byte_Size);

      if compToken = C_None_Compress then
        begin
          if source.Read(MD5_[0], 16) <> 16 then
            begin
              DisposeObject(StoreStream);
              exit;
            end;

          if source is TMS64 then
            begin
              StoreStream.Mapping(TMS64(source).PositionAsPtr, sizeInfo);
              TMS64(source).Position := TMS64(source).Position + sizeInfo;
            end
          else
            begin
              if sizeInfo > 0 then
                  StoreStream.CopyFrom(source, sizeInfo);
            end;

          StoreStream.Position := 0;
          if (not FastMode) and (not umlIsNullMD5(MD5_)) then
            if not umlMD5Compare(umlMD5(StoreStream.Memory, StoreStream.Size), MD5_) then
              begin
                DoStatus('MD5 error!');
                DisposeObject(StoreStream);
                exit;
              end;
        end
      else if compToken in [C_ZLIB_32_Compress, C_ZLIB_64_Compress] then
        begin
          if compToken = C_ZLIB_32_Compress then
            begin
              if source.Read(CompSizeInfo32, C_Cardinal_Size) <> C_Cardinal_Size then
                begin
                  DisposeObject(StoreStream);
                  exit;
                end;
              compsizeInfo := CompSizeInfo32;
            end
          else
            begin
              if source.Read(CompSizeInfo64, C_Int64_Size) <> C_Int64_Size then
                begin
                  DisposeObject(StoreStream);
                  exit;
                end;
              compsizeInfo := CompSizeInfo64;
            end;

          if source.Read(MD5_[0], 16) <> 16 then
            begin
              DisposeObject(StoreStream);
              exit;
            end;

          ZDecompStream := TDecompressionStream.Create(source);
          StoreStream.CopyFrom(ZDecompStream, compsizeInfo);
          DisposeObject(ZDecompStream);

          StoreStream.Position := 0;
          if (not FastMode) and (not umlIsNullMD5(MD5_)) then
            if not umlMD5Compare(umlMD5(StoreStream.Memory, StoreStream.Size), MD5_) then
              begin
                DoStatus('ZLIB MD5 error!');
                DisposeObject(StoreStream);
                exit;
              end;
        end
      else if compToken in [C_Deflate_32_Compress, C_Deflate_64_Compress] then
        begin
          if compToken = C_Deflate_32_Compress then
            begin
              if source.Read(CompSizeInfo32, C_Cardinal_Size) <> C_Cardinal_Size then
                begin
                  DisposeObject(StoreStream);
                  exit;
                end;
              compsizeInfo := CompSizeInfo32;
            end
          else
            begin
              if source.Read(CompSizeInfo64, C_Int64_Size) <> C_Int64_Size then
                begin
                  DisposeObject(StoreStream);
                  exit;
                end;
              compsizeInfo := CompSizeInfo64;
            end;

          if source.Read(MD5_[0], 16) <> 16 then
            begin
              DisposeObject(StoreStream);
              exit;
            end;

          if FCompressorDeflate = nil then
              FCompressorDeflate := TCompressorDeflate.Create;
          CoreDecompressStream(FCompressorDeflate, source, StoreStream);

          StoreStream.Position := 0;
          if (not FastMode) and (not umlIsNullMD5(MD5_)) then
            if not umlMD5Compare(umlMD5(StoreStream.Memory, StoreStream.Size), MD5_) then
              begin
                DoStatus('Deflate MD5 error!');
                DisposeObject(StoreStream);
                exit;
              end;
        end
      else if compToken in [C_BRRC_32_Compress, C_BRRC_64_Compress] then
        begin
          if compToken = C_BRRC_32_Compress then
            begin
              if source.Read(CompSizeInfo32, C_Cardinal_Size) <> C_Cardinal_Size then
                begin
                  DisposeObject(StoreStream);
                  exit;
                end;
              compsizeInfo := CompSizeInfo32;
            end
          else
            begin
              if source.Read(CompSizeInfo64, C_Int64_Size) <> C_Int64_Size then
                begin
                  DisposeObject(StoreStream);
                  exit;
                end;
              compsizeInfo := CompSizeInfo64;
            end;

          if source.Read(MD5_[0], 16) <> 16 then
            begin
              DisposeObject(StoreStream);
              exit;
            end;

          if FCompressorBRRC = nil then
              FCompressorBRRC := TCompressorBRRC.Create;
          CoreDecompressStream(FCompressorBRRC, source, StoreStream);

          StoreStream.Position := 0;
          if (not FastMode) and (not umlIsNullMD5(MD5_)) then
            if not umlMD5Compare(umlMD5(StoreStream.Memory, StoreStream.Size), MD5_) then
              begin
                DoStatus('BRRC MD5 error!');
                DisposeObject(StoreStream);
                exit;
              end;
        end
      else if compToken in [C_Parallel_32_Compress, C_Parallel_64_Compress] then
        begin
          if compToken = C_Parallel_32_Compress then
            begin
              if source.Read(CompSizeInfo32, C_Cardinal_Size) <> C_Cardinal_Size then
                begin
                  DisposeObject(StoreStream);
                  exit;
                end;
              compsizeInfo := CompSizeInfo32;
            end
          else
            begin
              if source.Read(CompSizeInfo64, C_Int64_Size) <> C_Int64_Size then
                begin
                  DisposeObject(StoreStream);
                  exit;
                end;
              compsizeInfo := CompSizeInfo64;
            end;

          if source.Read(MD5_[0], 16) <> 16 then
            begin
              DisposeObject(StoreStream);
              exit;
            end;

          ParallelDecompressStream(source, StoreStream);

          StoreStream.Position := 0;
          if (not FastMode) and (not umlIsNullMD5(MD5_)) then
            if not umlMD5Compare(umlMD5(StoreStream.Memory, StoreStream.Size), MD5_) then
              begin
                DoStatus('select compression MD5 error!');
                DisposeObject(StoreStream);
                exit;
              end;
        end
      else if compToken in [C_LZ4_32_Compress, C_LZ4_64_Compress] then
        begin
          if compToken = C_LZ4_32_Compress then
            begin
              if source.Read(CompSizeInfo32, C_Cardinal_Size) <> C_Cardinal_Size then
                begin
                  DisposeObject(StoreStream);
                  exit;
                end;
              compsizeInfo := CompSizeInfo32;
            end
          else
            begin
              if source.Read(CompSizeInfo64, C_Int64_Size) <> C_Int64_Size then
                begin
                  DisposeObject(StoreStream);
                  exit;
                end;
              compsizeInfo := CompSizeInfo64;
            end;

          if source.Read(MD5_[0], 16) <> 16 then
            begin
              DisposeObject(StoreStream);
              exit;
            end;

          tmpStream := TMS64.Create;
          if (source is TMS64) then
              tmpStream.Mapping(TMS64(source).PosAsPtr, TMS64(source).Size - TMS64(source).Position)
          else
              tmpStream.CopyFrom(source, source.Size - source.Position);
          with tmpStream.UnLZ4 do
            begin
              SwapInstance(StoreStream);
              Free;
            end;
          DisposeObject(tmpStream);

          StoreStream.Position := 0;
          if (not FastMode) and (not umlIsNullMD5(MD5_)) then
            if not umlMD5Compare(umlMD5(StoreStream.Memory, StoreStream.Size), MD5_) then
              begin
                DoStatus('lz4 compression MD5 error!');
                DisposeObject(StoreStream);
                exit;
              end;
        end
      else if compToken in [C_SNAPPY_PAS_32_Compress, C_SNAPPY_PAS_64_Compress] then
        begin
          if compToken = C_SNAPPY_PAS_32_Compress then
            begin
              if source.Read(CompSizeInfo32, C_Cardinal_Size) <> C_Cardinal_Size then
                begin
                  DisposeObject(StoreStream);
                  exit;
                end;
              compsizeInfo := CompSizeInfo32;
            end
          else
            begin
              if source.Read(CompSizeInfo64, C_Int64_Size) <> C_Int64_Size then
                begin
                  DisposeObject(StoreStream);
                  exit;
                end;
              compsizeInfo := CompSizeInfo64;
            end;

          if source.Read(MD5_[0], 16) <> 16 then
            begin
              DisposeObject(StoreStream);
              exit;
            end;

          tmpStream := TMS64.Create;
          if (source is TMS64) then
              tmpStream.Mapping(TMS64(source).PosAsPtr, TMS64(source).Size - TMS64(source).Position)
          else
              tmpStream.CopyFrom(source, source.Size - source.Position);
          with tmpStream.UnSnappy_Pas do
            begin
              SwapInstance(StoreStream);
              Free;
            end;
          DisposeObject(tmpStream);

          StoreStream.Position := 0;
          if (not FastMode) and (not umlIsNullMD5(MD5_)) then
            if not umlMD5Compare(umlMD5(StoreStream.Memory, StoreStream.Size), MD5_) then
              begin
                DoStatus('snappy compression MD5 error!');
                DisposeObject(StoreStream);
                exit;
              end;
        end;

      StoreStream.Position := 0;

      StoreStream.Read64(num_, C_Integer_Size);

      if Max_Limit_Decode > 0 then
          num_ := umlMin(num_ - 1, Max_Limit_Decode);

      for i := 0 to num_ - 1 do
        begin
          StoreStream.Read64(ID, C_Byte_Size);
          DataFrame_ := AddData(ByteToDataType(ID));
          DataFrame_.LoadFromStream(StoreStream);
        end;
      DisposeObject(StoreStream);
      Result := num_;
    end
  else
    begin
      DoStatus('TDFE decode error!');
      DisposeObject(StoreStream);
      exit;
    end;
end;

function TDFE.DecodeFrom(source: TCore_Stream; const FastMode: Boolean): Integer;
begin
  Result := DecodeFrom(source, FastMode, 0);
end;

function TDFE.DecodeFrom(source: TCore_Stream): Integer;
begin
  Result := DecodeFrom(source, False);
end;

function TDFE.DecodeFromMemory(memory_: Pointer; mSize: Int64; const FastMode: Boolean): Integer;
var
  m64: TMS64;
begin
  m64 := TMS64.Create;
  m64.Mapping(memory_, mSize);
  Result := DecodeFrom(m64, FastMode);
  DisposeObject(m64);
end;

function TDFE.DecodeFromMemory(memory_: Pointer; mSize: Int64): Integer;
var
  m64: TMS64;
begin
  m64 := TMS64.Create;
  m64.Mapping(memory_, mSize);
  Result := DecodeFrom(m64, False);
  DisposeObject(m64);
end;

function TDFE.DecodeFromMemory(stream: TMS64; const FastMode: Boolean): Integer;
var
  m64: TMS64;
begin
  m64 := TMS64.Create;
  m64.Mapping(stream);
  Result := DecodeFrom(m64, FastMode);
  DisposeObject(m64);
end;

function TDFE.DecodeFromMemory(stream: TMem64; const FastMode: Boolean): Integer;
var
  m64: TMS64;
begin
  m64 := TMS64.Create;
  m64.Mapping(stream);
  Result := DecodeFrom(m64, FastMode);
  DisposeObject(m64);
end;

procedure TDFE.EncodeToBytes(const Compressed, FastMode: Boolean; var output: TBytes);
var
  enStream: TMS64;
begin
  enStream := TMS64.Create;
  if Compressed then
      EncodeAsSelectCompressor(enStream, FastMode)
  else
      EncodeTo(enStream, FastMode);

  SetLength(output, enStream.Size);
  CopyPtr(enStream.Memory, @output[0], enStream.Size);
  DisposeObject(enStream);
end;

procedure TDFE.DecodeFromBytes(var buff: TBytes);
begin
  DecodeFromBytes(buff, False);
end;

procedure TDFE.DecodeFromBytes(var buff: TBytes; const FastMode: Boolean);
var
  enStream: TMS64;
begin
  enStream := TMS64.Create;
  enStream.SetPointerWithProtectedMode(@buff[0], length(buff));
  DecodeFrom(enStream, FastMode);
  DisposeObject(enStream);
end;

function TDFE.GetMD5(const FastMode: Boolean): TMD5;
var
  enStream: TMS64;
begin
  enStream := TMS64.Create;
  FastEncodeTo(enStream);

  Result := umlMD5(enStream.Memory, enStream.Size);
  DisposeObject(enStream);
end;

function TDFE.Compare(source: TDFE): Boolean;
var
  i: Integer;
  s1, s2: TMS64;
begin
  Result := False;

  if Count <> source.Count then
      exit;

  s1 := TMS64.CustomCreate(8192);
  s2 := TMS64.CustomCreate(8192);
  try
    for i := 0 to Count - 1 do
      begin
        if FDataList[i].ClassType <> source[i].ClassType then
            exit;
        if TDF_Base(FDataList[i]).FID <> TDF_Base(source[i]).FID then
            exit;
        if TDF_Base(FDataList[i]).ComputeEncodeSize <> TDF_Base(source[i]).ComputeEncodeSize then
            exit;

        s1.Clear;
        s2.Clear;
        TDF_Base(FDataList[i]).SaveToStream(s1);
        TDF_Base(source[i]).SaveToStream(s2);
        if s1.Size <> s2.Size then
            exit;
        if not CompareMemory(s1.Memory, s2.Memory, s1.Size) then
            exit;
        s1.Clear;
        s2.Clear;
      end;
    Result := True;
  finally
    DisposeObject(s1);
    DisposeObject(s2);
  end;
end;

procedure TDFE.LoadFromStream(stream: TCore_Stream);
begin
  try
      DecodeFrom(stream);
  except
  end;
end;

procedure TDFE.SaveToStream(stream: TCore_Stream);
var
  siz: Integer;
begin
  try
    siz := ComputeEncodeSize;
    if siz > 1024 then
        EncodeAsSelectCompressor(stream)
    else
        EncodeTo(stream);
  except
  end;
end;

procedure TDFE.LoadFromFile(fileName_: U_String);
var
  fs: TCore_FileStream;
begin
  fs := TCore_FileStream.Create(fileName_, fmOpenRead or fmShareDenyNone);
  LoadFromStream(fs);
  DisposeObject(fs);
end;

procedure TDFE.SaveToFile(fileName_: U_String);
var
  fs: TCore_FileStream;
begin
  fs := TCore_FileStream.Create(fileName_, fmCreate);
  SaveToStream(fs);
  DisposeObject(fs);
end;

class procedure TDFE.Test();
  procedure Test_Encode_1(d: TDFE; m5: TMD5);
  var
    inst: TDFE;
    m64: TMS64;
  begin
    inst := d.NewClone;
    m64 := TMS64.Create;
    m64.Size := 64 * 1024;
    inst.EncodeTo(m64, True, True);
    inst.Clear;
    m64.Position := 0;
    inst.DecodeFrom(m64);
    if not umlMD5Compare(m5, inst.GetMD5(True)) then
        DoStatus('encode error.');
    DisposeObject(m64);
    DisposeObject(inst);
  end;

  procedure Test_Encode_2(d: TDFE; m5: TMD5);
  var
    inst: TDFE;
    m64: TMS64;
  begin
    inst := d.NewClone;
    m64 := TMS64.Create;
    m64.Size := 64 * 1024;
    inst.EncodeTo(m64, False, True);
    inst.Clear;
    m64.Position := 0;
    inst.DecodeFrom(m64);
    if not umlMD5Compare(m5, inst.GetMD5(True)) then
        DoStatus('encode error.');
    DisposeObject(m64);
    DisposeObject(inst);
  end;

  procedure Test_Encode_3(d: TDFE; m5: TMD5);
  var
    inst: TDFE;
    m64: TMS64;
  begin
    inst := d.NewClone;
    m64 := TMS64.Create;
    m64.Size := 64 * 1024;
    inst.EncodeTo(m64, False, False);
    inst.Clear;
    m64.Position := 0;
    inst.DecodeFrom(m64);
    if not umlMD5Compare(m5, inst.GetMD5(True)) then
        DoStatus('encode error.');
    DisposeObject(m64);
    DisposeObject(inst);
  end;

  procedure Test_Fast_Encode32(d: TDFE; m5: TMD5);
  var
    inst: TDFE;
    m64: TMS64;
  begin
    inst := d.NewClone;
    m64 := TMS64.Create;
    m64.Size := 64 * 1024;
    inst.FastEncode32To(m64, inst.ComputeEncodeSize);
    inst.Clear;
    m64.Position := 0;
    inst.DecodeFrom(m64);
    if not umlMD5Compare(m5, inst.GetMD5(True)) then
        DoStatus('encode error.');
    DisposeObject(m64);
    DisposeObject(inst);
  end;

  procedure Test_Fast_Encode64(d: TDFE; m5: TMD5);
  var
    inst: TDFE;
    m64: TMS64;
  begin
    inst := d.NewClone;
    m64 := TMS64.Create;
    m64.Size := 64 * 1024;
    inst.FastEncode64To(m64, inst.ComputeEncodeSize);
    inst.Clear;
    m64.Position := 0;
    inst.DecodeFrom(m64);
    if not umlMD5Compare(m5, inst.GetMD5(True)) then
        DoStatus('encode error.');
    DisposeObject(m64);
    DisposeObject(inst);
  end;

  procedure Test_SelectCompressor_Encode(d: TDFE; m5: TMD5);
  var
    inst: TDFE;
    m64: TMS64;
  begin
    inst := d.NewClone;
    m64 := TMS64.Create;
    m64.Size := 64 * 1024;
    inst.EncodeAsSelectCompressor(m64, True);
    inst.Clear;
    m64.Position := 0;
    inst.DecodeFrom(m64);
    if not umlMD5Compare(m5, inst.GetMD5(True)) then
        DoStatus('encode error.');
    DisposeObject(m64);
    DisposeObject(inst);
  end;

  procedure Test_ZLIB_Encode(d: TDFE; m5: TMD5);
  var
    inst: TDFE;
    m64: TMS64;
  begin
    inst := d.NewClone;
    m64 := TMS64.Create;
    m64.Size := 64 * 1024;
    inst.EncodeAsZLib(m64, True, False);
    inst.Clear;
    m64.Position := 0;
    inst.DecodeFrom(m64);
    if not umlMD5Compare(m5, inst.GetMD5(True)) then
        DoStatus('encode error.');
    DisposeObject(m64);
    DisposeObject(inst);
  end;

  procedure Test_BRRC_Encode(d: TDFE; m5: TMD5);
  var
    inst: TDFE;
    m64: TMS64;
  begin
    inst := d.NewClone;
    m64 := TMS64.Create;
    m64.Size := 64 * 1024;
    inst.EncodeAsBRRC(m64, True, False);
    inst.Clear;
    m64.Position := 0;
    inst.DecodeFrom(m64);
    if not umlMD5Compare(m5, inst.GetMD5(True)) then
        DoStatus('encode error.');
    DisposeObject(m64);
    DisposeObject(inst);
  end;

  procedure Test_Deflate_Encode(d: TDFE; m5: TMD5);
  var
    inst: TDFE;
    m64: TMS64;
  begin
    inst := d.NewClone;
    m64 := TMS64.Create;
    m64.Size := 64 * 1024;
    inst.EncodeAsDeflate(m64, True, False);
    inst.Clear;
    m64.Position := 0;
    inst.DecodeFrom(m64);
    if not umlMD5Compare(m5, inst.GetMD5(True)) then
        DoStatus('encode error.');
    DisposeObject(m64);
    DisposeObject(inst);
  end;

  procedure Test_LZ4_Encode(d: TDFE; m5: TMD5);
  var
    inst: TDFE;
    m64: TMS64;
  begin
    inst := d.NewClone;
    m64 := TMS64.Create;
    m64.Size := 64 * 1024;
    inst.EncodeAsLZ4(m64, False);
    inst.Clear;
    m64.Position := 0;
    inst.DecodeFrom(m64);
    if not umlMD5Compare(m5, inst.GetMD5(True)) then
        DoStatus('encode error.');
    DisposeObject(m64);
    DisposeObject(inst);
  end;

  procedure Test_Snappy_Encode(d: TDFE; m5: TMD5);
  var
    inst: TDFE;
    m64: TMS64;
  begin
    inst := d.NewClone;
    m64 := TMS64.Create;
    m64.Size := 64 * 1024;
    inst.EncodeAsSnappy(m64, False);
    inst.Clear;
    m64.Position := 0;
    inst.DecodeFrom(m64);
    if not umlMD5Compare(m5, inst.GetMD5(True)) then
        DoStatus('encode error.');
    DisposeObject(m64);
    DisposeObject(inst);
  end;

var
  inst: TDFE;
  m64: TMS64;
  m5: TMD5;
begin
  inst := TDFE.Create;
  inst.WriteString('hello world');
  inst.WriteInteger(1);
  inst.WriteCardinal(2);
  inst.WriteWORD(3);
  inst.WriteBool(True);
  inst.WriteByte(5);
  inst.WriteSingle(6);
  inst.WriteDouble(7);
  inst.WriteArrayInteger.WriteArray([1, 2, 3, 4, 5]);
  inst.WriteArrayShortInt.WriteArray([1, 2, 3, 4, 5]);
  inst.WriteArrayByte.WriteArray([1, 2, 3, 4, 5]);
  inst.WriteArraySingle.WriteArray([1, 2, 3, 4, 5]);
  inst.WriteArrayDouble.WriteArray([1, 2, 3, 4, 5]);
  inst.WriteArrayInt64.WriteArray([1, 2, 3, 4, 5]);
  inst.WriteArrayInt128.WriteArray([1, 2, 3, 4, 5]);
  inst.WriteInt64(8);
  inst.WriteUInt64(9);
  inst.WriteInt128(10);
  inst.WriteUInt128(11);
  m64 := TMS64.Create;
  m64.Size := 1024 * 32;
  TMT19937.Rand32($FFFF, m64.Memory, m64.Size div 4);
  inst.WriteStream(m64);
  DisposeObject(m64);
  m5 := inst.GetMD5(True);

  // test 32 Bit
  inst.FBit_64_Condition := 1024 * 1024;
  Test_Encode_1(inst, m5);
  Test_Encode_2(inst, m5);
  Test_Encode_3(inst, m5);
  Test_Fast_Encode32(inst, m5);
  Test_Fast_Encode64(inst, m5);
  Test_SelectCompressor_Encode(inst, m5);
  Test_ZLIB_Encode(inst, m5);
  Test_BRRC_Encode(inst, m5);
  Test_Deflate_Encode(inst, m5);
  Test_LZ4_Encode(inst, m5);
  Test_Snappy_Encode(inst, m5);

  // simulate test 64 Bit
  inst.FBit_64_Condition := 1024;
  m5 := inst.GetMD5(True);
  Test_Encode_1(inst, m5);
  Test_Encode_2(inst, m5);
  Test_Encode_3(inst, m5);
  Test_Fast_Encode32(inst, m5);
  Test_Fast_Encode64(inst, m5);
  Test_SelectCompressor_Encode(inst, m5);
  Test_ZLIB_Encode(inst, m5);
  Test_BRRC_Encode(inst, m5);
  Test_Deflate_Encode(inst, m5);
  Test_LZ4_Encode(inst, m5);
  Test_Snappy_Encode(inst, m5);

  DisposeObject(inst);

  DoStatus('DFE test done.');
end;

constructor TDataWriter.Create(Stream_: TCore_Stream);
begin
  inherited Create;
  FEngine := TDFE.Create;
  FStream := Stream_;
end;

destructor TDataWriter.Destroy;
var
  FlagCompressed: Boolean;
  verflag: TBytes;
  siz: Int64;
  M: TMS64;
begin
  if FStream <> nil then
    begin
      M := TMS64.Create;
      FEngine.FastEncodeTo(M);
      siz := M.Size;

      // write version flag
      verflag := umlBytesOf('0001');
      FStream.write(verflag, 4);

      // write compressed flag
      FlagCompressed := False;
      FStream.write(FlagCompressed, C_Boolean_Size);

      // write siz info
      FStream.write(siz, C_Int64_Size);

      // write buffer
      M.Position := 0;
      FStream.CopyFrom(M, siz);
      DisposeObject(M);
    end;

  DisposeObject(FEngine);
  inherited Destroy;
end;

procedure TDataWriter.Clear;
begin
  FEngine.Clear;
end;

function TDataWriter.WriteString(v: SystemString): TDFE;
begin
  Result := FEngine.WriteString(v);
end;

function TDataWriter.WriteInteger(v: Integer): TDFE;
begin
  Result := FEngine.WriteInteger(v);
end;

function TDataWriter.WriteCardinal(v: Cardinal): TDFE;
begin
  Result := FEngine.WriteCardinal(v);
end;

function TDataWriter.WriteWORD(v: Word): TDFE;
begin
  Result := FEngine.WriteWORD(v);
end;

function TDataWriter.WriteBool(v: Boolean): TDFE;
begin
  Result := FEngine.WriteBool(v);
end;

function TDataWriter.WriteBoolean(v: Boolean): TDFE;
begin
  Result := FEngine.WriteBoolean(v);
end;

function TDataWriter.WriteByte(v: Byte): TDFE;
begin
  Result := FEngine.WriteByte(v);
end;

function TDataWriter.WriteSingle(v: Single): TDFE;
begin
  Result := FEngine.WriteSingle(v);
end;

function TDataWriter.WriteDouble(v: Double): TDFE;
begin
  Result := FEngine.WriteDouble(v);
end;

function TDataWriter.WriteArrayInteger(v: array of Integer): TDFE;
begin
  FEngine.WriteArrayInteger.WriteArray(v);
  Result := FEngine;
end;

function TDataWriter.WriteArrayShortInt(v: array of ShortInt): TDFE;
begin
  FEngine.WriteArrayShortInt.WriteArray(v);
  Result := FEngine;
end;

function TDataWriter.WriteArrayByte(v: array of Byte): TDFE;
begin
  FEngine.WriteArrayByte.WriteArray(v);
  Result := FEngine;
end;

function TDataWriter.WriteArraySingle(v: array of Single): TDFE;
begin
  FEngine.WriteArraySingle.WriteArray(v);
  Result := FEngine;
end;

function TDataWriter.WriteArrayDouble(v: array of Double): TDFE;
begin
  FEngine.WriteArrayDouble.WriteArray(v);
  Result := FEngine;
end;

function TDataWriter.WriteArrayInt64(v: array of Int64): TDFE;
begin
  FEngine.WriteArrayInt64.WriteArray(v);
  Result := FEngine;
end;

function TDataWriter.WriteStream(v: TCore_Stream): TDFE;
begin
  Result := FEngine.WriteStream(v);
end;

function TDataWriter.WriteStream(v: TMS64; bPos_, Size_: Int64): TDFE;
begin
  Result := FEngine.WriteStream(v, bPos_, Size_);
end;

function TDataWriter.WriteVariant(v: Variant): TDFE;
begin
  Result := FEngine.WriteVariant(v);
end;

function TDataWriter.WriteInt64(v: Int64): TDFE;
begin
  Result := FEngine.WriteInt64(v);
end;

function TDataWriter.WriteUInt64(v: UInt64): TDFE;
begin
  Result := FEngine.WriteUInt64(v);
end;

function TDataWriter.WriteArrayInt128(v: array of Int128): TDFE;
begin
  FEngine.WriteArrayInt128.WriteArray(v);
  Result := FEngine;
end;

function TDataWriter.WriteInt128(v: Int128): TDFE;
begin
  Result := FEngine.WriteInt128(v);
end;

function TDataWriter.WriteUInt128(v: UInt128): TDFE;
begin
  Result := FEngine.WriteUInt128(v);
end;

function TDataWriter.WriteStrings(v: TCore_Strings): TDFE;
begin
  Result := FEngine.WriteStrings(v);
end;

function TDataWriter.WriteListStrings(v: TListString): TDFE;
begin
  Result := FEngine.WriteListStrings(v);
end;

function TDataWriter.WritePascalStrings(v: TPascalStringList): TDFE;
begin
  Result := FEngine.WritePascalStrings(v);
end;

function TDataWriter.WritePascalStrings(v: U_StringArray): TDFE;
begin
  Result := FEngine.WritePascalStrings(v);
end;

function TDataWriter.WriteDataFrame(v: TDFE): TDFE;
begin
  Result := FEngine.WriteDataFrame(v);
end;

function TDataWriter.WriteDataFrameCompressed(v: TDFE): TDFE;
begin
  Result := FEngine.WriteDataFrameCompressed(v);
end;

function TDataWriter.WriteHashStringList(v: THashStringList): TDFE;
begin
  Result := FEngine.WriteHashStringList(v);
end;

function TDataWriter.WriteVariantList(v: THashVariantList): TDFE;
begin
  Result := FEngine.WriteVariantList(v);
end;

function TDataWriter.WriteJson(v: TZ_JsonObject): TDFE;
begin
  Result := FEngine.WriteJson(v);
end;

{$IFDEF DELPHI}


function TDataWriter.WriteJson(v: TJsonObject): TDFE;
begin
  Result := FEngine.WriteJson(v);
end;
{$ENDIF DELPHI}


function TDataWriter.WriteRect(v: TRect): TDFE;
begin
  Result := FEngine.WriteRect(v);
end;

function TDataWriter.WriteRectf(v: TRectf): TDFE;
begin
  Result := FEngine.WriteRectf(v);
end;

function TDataWriter.WritePoint(v: TPoint): TDFE;
begin
  Result := FEngine.WritePoint(v);
end;

function TDataWriter.WritePointf(v: TPointf): TDFE;
begin
  Result := FEngine.WritePointf(v);
end;

function TDataWriter.WriteVector(v: TVector): TDFE;
begin
  Result := FEngine.WriteVector(v);
end;

function TDataWriter.WriteAffineVector(v: TAffineVector): TDFE;
begin
  Result := FEngine.WriteAffineVector(v);
end;

function TDataWriter.WriteVec4(v: TVec4): TDFE;
begin
  Result := FEngine.WriteVec4(v);
end;

function TDataWriter.WriteVec3(v: TVec3): TDFE;
begin
  Result := FEngine.WriteVec3(v);
end;

function TDataWriter.WriteVector4(v: TVector4): TDFE;
begin
  Result := FEngine.WriteVector4(v);
end;

function TDataWriter.WriteVector3(v: TVector3): TDFE;
begin
  Result := FEngine.WriteVector3(v);
end;

function TDataWriter.WriteMat4(v: TMat4): TDFE;
begin
  Result := FEngine.WriteMat4(v);
end;

function TDataWriter.WriteMatrix4(v: TMatrix4): TDFE;
begin
  Result := FEngine.WriteMatrix4(v);
end;

function TDataWriter.Write2DPoint(v: T2DPoint): TDFE;
begin
  Result := FEngine.Write2DPoint(v);
end;

function TDataWriter.WriteVec2(v: TVec2): TDFE;
begin
  Result := FEngine.WriteVec2(v);
end;

function TDataWriter.WriteRectV2(v: TRectV2): TDFE;
begin
  Result := FEngine.WriteRectV2(v);
end;

function TDataWriter.WritePointer(v: Pointer): TDFE;
begin
  Result := FEngine.WritePointer(v);
end;

function TDataWriter.write(const Buf_; Count_: Int64): TDFE;
begin
  Result := FEngine.write(Buf_, Count_);
end;

function TDataWriter.WriteNM(NM: TNumberModule): TDFE;
begin
  Result := FEngine.WriteNM(NM);
end;

function TDataWriter.WriteNMPool(NMPool: TNumberModulePool): TDFE;
begin
  Result := FEngine.WriteNMPool(NMPool);
end;

function TDataWriter.WriteOpCode(v: TOpCode): TDFE;
begin
  Result := FEngine.WriteOpCode(v);
end;

function TDataWriter.WriteSectionText(v: THashTextEngine): TDFE;
begin
  Result := FEngine.WriteSectionText(v);
end;

function TDataWriter.WriteTextSection(v: THashTextEngine): TDFE;
begin
  Result := FEngine.WriteTextSection(v);
end;

constructor TDataReader.Create(Stream_: TCore_Stream);
var
  verflag: TBytes;
  FlagCompressed: Boolean;
  siz: Int64;
  M: TMS64;
begin
  inherited Create;
  FEngine := TDFE.Create;
  if Stream_ <> nil then
    begin
      // read version flag
      SetLength(verflag, 4);
      Stream_.Read(verflag, 4);
      if umlStringOf(verflag) <> '0001' then
          raise Exception.Create('Version flag Does not match!');

      // read compressed flag
      Stream_.Read(FlagCompressed, C_Boolean_Size);

      // read size info
      Stream_.Read(siz, C_Int64_Size);

      // read buffer
      M := TMS64.Create;
      M.CopyFrom(Stream_, siz);
      M.Position := 0;
      FEngine.DecodeFrom(M);
      DisposeObject(M);
    end;
end;

destructor TDataReader.Destroy;
begin
  DisposeObject(FEngine);
  inherited Destroy;
end;

function TDataReader.ReadString: SystemString;
begin
  Result := FEngine.Reader.ReadString;
end;

function TDataReader.ReadInteger: Integer;
begin
  Result := FEngine.Reader.ReadInteger;
end;

function TDataReader.ReadCardinal: Cardinal;
begin
  Result := FEngine.Reader.ReadCardinal;
end;

function TDataReader.ReadWord: Word;
begin
  Result := FEngine.Reader.ReadWord;
end;

function TDataReader.ReadBool: Boolean;
begin
  Result := FEngine.Reader.ReadBool;
end;

function TDataReader.ReadBoolean: Boolean;
begin
  Result := FEngine.Reader.ReadBoolean;
end;

function TDataReader.ReadByte: Byte;
begin
  Result := FEngine.Reader.ReadByte;
end;

function TDataReader.ReadSingle: Single;
begin
  Result := FEngine.Reader.ReadSingle;
end;

function TDataReader.ReadDouble: Double;
begin
  Result := FEngine.Reader.ReadDouble;
end;

procedure TDataReader.ReadArrayInteger(var Data: array of Integer);
var
  i: Integer;
  rb: TDF_ArrayInteger;
begin
  rb := FEngine.Reader.ReadArrayInteger;
  for i := low(Data) to high(Data) do
      Data[i] := rb[i];
end;

procedure TDataReader.ReadArrayShortInt(var Data: array of ShortInt);
var
  i: Integer;
  rb: TDF_ArrayShortInt;
begin
  rb := FEngine.Reader.ReadArrayShortInt;
  for i := low(Data) to high(Data) do
      Data[i] := rb[i];
end;

procedure TDataReader.ReadArrayByte(var Data: array of Byte);
var
  i: Integer;
  rb: TDF_ArrayByte;
begin
  rb := FEngine.Reader.ReadArrayByte;
  for i := low(Data) to high(Data) do
      Data[i] := rb[i];
end;

procedure TDataReader.ReadArraySingle(var Data: array of Single);
var
  i: Integer;
  rb: TDF_ArraySingle;
begin
  rb := FEngine.Reader.ReadArraySingle;
  for i := low(Data) to high(Data) do
      Data[i] := rb[i];
end;

procedure TDataReader.ReadArrayDouble(var Data: array of Double);
var
  i: Integer;
  rb: TDF_ArrayDouble;
begin
  rb := FEngine.Reader.ReadArrayDouble;
  for i := low(Data) to high(Data) do
      Data[i] := rb[i];
end;

procedure TDataReader.ReadArrayInt64(var Data: array of Int64);
var
  i: Integer;
  rb: TDF_ArrayInt64;
begin
  rb := FEngine.Reader.ReadArrayInt64;
  for i := low(Data) to high(Data) do
      Data[i] := rb[i];
end;

procedure TDataReader.ReadStream(output: TCore_Stream);
begin
  FEngine.Reader.ReadStream(output);
end;

function TDataReader.ReadVariant: Variant;
begin
  Result := FEngine.Reader.ReadVariant;
end;

function TDataReader.ReadInt64: Int64;
begin
  Result := FEngine.Reader.ReadInt64;
end;

function TDataReader.ReadUInt64: UInt64;
begin
  Result := FEngine.Reader.ReadUInt64;
end;

procedure TDataReader.ReadArrayInt128(var Data: array of Int128);
var
  i: Integer;
  rb: TDF_ArrayInt128;
begin
  rb := FEngine.Reader.ReadArrayInt128;
  for i := low(Data) to high(Data) do
      Data[i] := rb[i];
end;

function TDataReader.ReadInt128: Int128;
begin
  Result := FEngine.Reader.ReadInt128;
end;

function TDataReader.ReadUInt128: UInt128;
begin
  Result := FEngine.Reader.ReadUInt128;
end;

procedure TDataReader.ReadStrings(output: TCore_Strings);
begin
  FEngine.Reader.ReadStrings(output);
end;

procedure TDataReader.ReadListStrings(output: TListString);
begin
  FEngine.Reader.ReadListStrings(output);
end;

procedure TDataReader.ReadPascalStrings(output: TPascalStringList);
begin
  FEngine.Reader.ReadPascalStrings(output);
end;

procedure TDataReader.ReadPascalStrings(var output: U_StringArray);
begin
  FEngine.Reader.ReadPascalStrings(output);
end;

procedure TDataReader.ReadDataFrame(output: TDFE);
begin
  FEngine.Reader.ReadDataFrame(output);
end;

procedure TDataReader.ReadHashStringList(output: THashStringList);
begin
  FEngine.Reader.ReadHashStringList(output);
end;

procedure TDataReader.ReadVariantList(output: THashVariantList);
begin
  FEngine.Reader.ReadVariantList(output);
end;

procedure TDataReader.ReadJson(output: TZ_JsonObject);
begin
  FEngine.Reader.ReadJson(output);
end;

{$IFDEF DELPHI}


procedure TDataReader.ReadJson(output: TJsonObject);
begin
  FEngine.Reader.ReadJson(output);
end;
{$ENDIF DELPHI}


function TDataReader.ReadRect: TRect;
begin
  Result := FEngine.Reader.ReadRect;
end;

function TDataReader.ReadRectf: TRectf;
begin
  Result := FEngine.Reader.ReadRectf;
end;

function TDataReader.ReadPoint: TPoint;
begin
  Result := FEngine.Reader.ReadPoint;
end;

function TDataReader.ReadPointf: TPointf;
begin
  Result := FEngine.Reader.ReadPointf;
end;

function TDataReader.ReadVector: TVector;
begin
  Result := FEngine.Reader.ReadVector;
end;

function TDataReader.ReadAffineVector: TAffineVector;
begin
  Result := FEngine.Reader.ReadAffineVector;
end;

function TDataReader.ReadVec3: TVec3;
begin
  Result := FEngine.Reader.ReadVec3;
end;

function TDataReader.ReadVec4: TVec4;
begin
  Result := FEngine.Reader.ReadVec4;
end;

function TDataReader.ReadVector3: TVector3;
begin
  Result := FEngine.Reader.ReadVector3;
end;

function TDataReader.ReadVector4: TVector4;
begin
  Result := FEngine.Reader.ReadVector4;
end;

function TDataReader.ReadMat4: TMat4;
begin
  Result := FEngine.Reader.ReadMat4;
end;

function TDataReader.ReadMatrix4: TMatrix4;
begin
  Result := FEngine.Reader.ReadMatrix4;
end;

function TDataReader.Read2DPoint: T2DPoint;
begin
  Result := FEngine.Reader.Read2DPoint;
end;

function TDataReader.ReadVec2: TVec2;
begin
  Result := FEngine.Reader.ReadVec2;
end;

function TDataReader.ReadRectV2: TRectV2;
begin
  Result := FEngine.Reader.ReadRectV2;
end;

function TDataReader.ReadPointer: UInt64;
begin
  Result := FEngine.Reader.ReadPointer;
end;

procedure TDataReader.ReadNM(output: TNumberModule);
begin
  FEngine.Reader.ReadNM(output);
end;

procedure TDataReader.ReadNMPool(output: TNumberModulePool);
begin
  FEngine.Reader.ReadNMPool(output);
end;

procedure TDataReader.ReadOpCode(output: TOpCode);
begin
  FEngine.Reader.ReadOpCode(output);
end;

procedure TDataReader.ReadSectionText(output: THashTextEngine);
begin
  FEngine.Reader.ReadSectionText(output);
end;

procedure TDataReader.ReadTextSection(output: THashTextEngine);
begin
  FEngine.Reader.ReadTextSection(output);
end;

procedure TDataReader.Read(var Buf_; Count_: Int64);
begin
  FEngine.Reader.Read(Buf_, Count_);
end;

end.

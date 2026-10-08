(*
  * ******************************************************************************
  * json object library for delphi/objfpc
  * ******************************************************************************
  *
  * ==============================================================================
  * CRITICAL PITFALLS - READ BEFORE USE
  * ==============================================================================
  *
  * [P10-1]  TZ_JsonObject IS A TREE, NOT A FLAT CONTAINER
  * ------------------------------------------------------------------------------
  * A child object's FInstance points INTO the parent's underlying JSON tree
  * node. The methods Parae / Assign / LoadFromStream / ParseText internally
  * call DisposeObjectAndNil(FInstance) and create a NEW instance that is NOT
  * re-attached to the parent tree.
  *
  * Calling any of these on ANY child / grandchild object leaves DANGLING
  * POINTERS in the parent tree. The consequences are:
  *
  *   - Random crashes / access violations (often delayed until ToBytes)
  *   - Lost fields (for example options.response_format disappears)
  *   - schema field becomes null
  *   - Serialization corrupts silently
  *
  * ALLOWED  :  Parae / Assign / LoadFromStream / ParseText on ROOT objects
  *             only (Parent = nil).
  * FORBIDDEN:  the same calls on any child / grandchild object.
  *
  * Correct pattern to inject parsed JSON into a child:
  *   1. Parse in an INDEPENDENT ROOT object.
  *   2. Extract compact JSON string via ToJSONString(False).
  *   3. Concatenate in Unicode space using TZ_JsonString.
  *   4. Convert to UTF-8 bytes with .Bytes as the LAST step.
  *
  * Audit checklist (grep before every commit):
  *   - "<obj>.Parae("          -> left side must be a ROOT object
  *   - "<obj>.Assign("         -> left side must be a ROOT object
  *   - "<obj>.LoadFromStream(" -> left side must be a ROOT object
  *   - "<obj>.ParseText("      -> left side must be a ROOT object
  *
  * ------------------------------------------------------------------------------
  * [P10-2]  JSON ASSEMBLY MUST STAY IN UNICODE SPACE
  * ------------------------------------------------------------------------------
  * Do NOT route JSON text through a plain `string` (AnsiString on FPC)
  * variable. On Windows with code page CP936 / CP1252 etc., emoji, Korean,
  * rare CJK characters silently turn into '?' before reaching the server.
  *
  * Use TZ_JsonString as the intermediate container. Call .Bytes only at the
  * very last step before sending over the wire.
  *
  * Wrong:
  *   var s: string;
  *   s := jo.ToJSONString(False).Text;          // lossy on FPC Windows
  *   reqBytes := TEncoding.UTF8.GetBytes(s);
  *
  * Right:
  *   var s: TZ_JsonString;
  *   s := jo.ToJSONString(False);
  *   reqBytes := s.Bytes;                       // direct UTF-8 output
  *
  * ------------------------------------------------------------------------------
  * [P10-3]  GBK / LATIN-1 FALLBACK MUST USE USystemString
  * ------------------------------------------------------------------------------
  * When decoding unknown encodings byte by byte, the target variable MUST
  * be USystemString (UTF-16). Using AnsiString plus SetLength plus Move
  * mixes byte units with UTF-16 container sizes and silently corrupts data.
  *
  * ==============================================================================
  * OTHER PITFALLS
  * ==============================================================================
  *
  * [src]  1.  TZ_JsonArray.Create(nil) leaves FInstance = nil. Any method
  *            call on such an instance crashes. Always obtain arrays via
  *            TZ_JsonObject.A['name'], AddArray, InsertArray, GetArray.
  *
  * [src]  2.  TZ_JsonObject.Create(Parent) with Parent <> nil does NOT
  *            create FInstance. It is expected to be assigned by
  *            GetObject / AddObject / InsertObject.
  *
  * [src]  3.  GetArray / GetObject AUTO-CREATE the key if missing. A
  *            "read" operation can silently mutate the tree. Use Exists()
  *            before access if you need non-mutating lookup.
  *
  * [src]  4.  GetArray / GetObject do NOT check the value type. Using the
  *            wrong accessor on an existing key may crash or behave
  *            differently across FPC / Delphi.
  *
  * [src]  5.  Add(Int128) / Add(UInt128) / Add(TDateTime) store STRINGS,
  *            not numbers. JSON output contains quoted strings. Round-trip
  *            requires manual conversion.
  *
  * [src]  6.  Set_Default_S is a WRITE, not a "set default". It
  *            overwrites any existing value. Use Get_Default_S for
  *            read-with-default semantics.
  *
  * [src]  7.  SaveToStream(stream) defaults to FORMATTED output. Pass
  *            Formated_ = False for compact output.
  *
  * [src]  8.  Parae is a typo for Parse. The name is preserved for
  *            backward compatibility. Empty TBytes will crash at
  *            @buff[0]. Check Length(buff) > 0 first.
  *
  * [src]  9.  LoadFromFile fails SILENTLY on missing / malformed files.
  *            ParseText leaves state UNDEFINED on failure. Re-create the
  *            object after a failed ParseText.
  *
  * [doc]  10. FPC and Delphi SaveToStream / LoadFromStream implementations
  *            differ. GetMD5 cross-compiler consistency is NOT guaranteed.
  *
  * [src]  11. TZ_JsonObject_List with AutoFreeObj = False leaks on
  *            Destroy. Use AutoFreeObj = True, or call Clean explicitly.
  *
  * [src]  12. TZ_JsonString is TUPascalString on FPC and TPascalString
  *            on Delphi. Never assume it is `string`.
  *
  * [src]  13. NOT thread-safe. External locking required for instances
  *            shared between threads.
  *
  * [src]  14. SwapInstance only works on ROOT objects. Child objects
  *            raise 'error.'.
  *
  * [doc]  15. TZ_JsonObject.Create(Parent_) when Parent <> nil: children
  *            are auto-registered into Parent.FList (AutoFreeObj = True).
  *            Do NOT manually free a child that has a parent.
  *
  * [doc]  16. MD5 is computed on UNFORMATTED serialization. Byte-level
  *            output may differ between FPC and Delphi.
  *
  * ==============================================================================
*)

unit Z.Json;

{$DEFINE FPC_DELPHI_MODE}
{$I Z.Define.inc}

interface

uses SysUtils,
{$IFDEF DELPHI}
  Z.Delphi.JsonDataObjects,
{$ELSE DELPHI}
  Z.FPC.GenericList,
  fpjson, jsonparser, jsonscanner,
{$ENDIF DELPHI}
  Z.Core, Z.PascalStrings, Z.UPascalStrings, Z.Status,
  Z.UnicodeMixedLib,
  Z.MemoryStream,
  Z.Int128;

type
  TZ_JsonObject = class;

  (*
    * Cross-compiler backend aliases.
    *
    * [PITFALL] TZ_JsonString is NOT `string`:
    *   - FPC    : TUPascalString (UTF-16)
    *   - Delphi : TPascalString
    *
    * Never assume it is a plain system string. Use .Text / .Bytes
    * explicitly when converting to / from native string or byte buffers.
  *)
{$IFDEF DELPHI}
  TZ_Instance_JsonArray = TJsonArray;
  TZ_Instance_JsonObject = TJsonObject;
  TZ_JsonString = TPascalString;
{$ELSE DELPHI}
  TZ_Instance_JsonArray = TJsonArray;
  TZ_Instance_JsonObject = TJsonObject;
  TZ_JsonString = TUPascalString;
{$ENDIF DELPHI}

  (*
    * TZ_JsonBase - lifecycle / parent-child ownership base.
    *
    * A child object created with a non-nil Parent is automatically
    * registered into Parent.FList (AutoFreeObj = True). When the parent
    * is destroyed, all registered children are freed automatically.
    *
    * [PITFALL] Do NOT hold a strong reference from a child back to its
    * parent outside FParent, and NEVER create a reference cycle.
    *
    * [PITFALL] Do NOT manually free a child that has a parent. The
    * parent will free it, and you would double-free.
  *)
  TZ_JsonBase = class(TCore_Object_Intermediate)
  protected
    FParent: TZ_JsonBase;
    FList: TCore_ObjectList;
  public
    property Parent: TZ_JsonBase read FParent;
    constructor Create(Parent_: TZ_JsonBase); virtual;
    destructor Destroy; override;
  end;

  (*
    * TZ_JsonArray - array wrapper.
    *
    * [PITFALL] TZ_JsonArray.Create(nil) leaves FInstance = nil. Any
    * method call on such an instance crashes with access violation.
    *
    * Always obtain arrays through one of these paths:
    *   - TZ_JsonObject.A['name']           (auto-create)
    *   - TZ_JsonObject.GetArray('name')    (auto-create)
    *   - TZ_JsonArray.AddArray             (child of existing array)
    *   - TZ_JsonArray.InsertArray          (child of existing array)
  *)
  TZ_JsonArray = class(TZ_JsonBase)
  private
    FInstance: TZ_Instance_JsonArray;
  public
    property Instance: TZ_Instance_JsonArray read FInstance;
    constructor Create(Parent_: TZ_JsonBase); override;
    destructor Destroy; override;

    procedure Clear;

    (*
      * Delete(Index) removes element at Index. No bounds check.
      * Passing an out-of-range Index is undefined behavior.
    *)
    procedure Delete(Index: integer);

    (*
      * [PITFALL] Add(Int128) / Add(UInt128) / Add(TDateTime) store
      * STRINGS, not numbers. JSON output contains quoted strings such as
      * "123456789012345678901234567890". Round-trip requires manual
      * conversion via Int128(...) / UInt128(...) / umlStrToDateTime(...).
    *)
    procedure Add(const v_: string); overload;
    procedure Add(const v_: TZ_JsonString); overload;
    procedure Add(const v_: integer); overload;
    procedure Add(const v_: int64); overload;
    procedure Add(const v_: uint64); overload;
    procedure Add(const v_: Int128); overload;
    procedure Add(const v_: UInt128); overload;
    procedure AddF(const v_: double); overload;
    procedure Add(const v_: TDateTime); overload;
    procedure Add(const v_: boolean); overload;
    function AddArray: TZ_JsonArray;
    function AddObject: TZ_JsonObject; overload;

    procedure Insert(Index: integer; const v_: string); overload;
    procedure Insert(Index: integer; const v_: TZ_JsonString); overload;
    procedure Insert(Index: integer; const v_: integer); overload;
    procedure Insert(Index: integer; const v_: int64); overload;
    procedure Insert(Index: integer; const v_: uint64); overload;
    procedure Insert(Index: integer; const v_: Int128); overload;
    procedure Insert(Index: integer; const v_: UInt128); overload;
    procedure Insert(Index: integer; const v_: double); overload;
    procedure Insert(Index: integer; const v_: TDateTime); overload;
    procedure Insert(Index: integer; const v_: boolean); overload;
    function InsertArray(Index: integer): TZ_JsonArray;
    function InsertObject(Index: integer): TZ_JsonObject; overload;

    (*
      * Index-based readers / writers.
      *
      * [PITFALL] No bounds check. Out-of-range Index is undefined
      * behavior (crash or garbage value).
      *
      * [PITFALL] Type mismatches (for example reading an int with S[]) are
      * handled differently between FPC and Delphi. Verify the element
      * type before calling a typed getter.
    *)
    function GetString(Index: integer): string;
    procedure SetString(Index: integer; const Value: string);
    function GetInt(Index: integer): integer;
    procedure SetInt(Index: integer; const Value: integer);
    function GetLong(Index: integer): int64;
    procedure SetLong(Index: integer; const Value: int64);
    function GetULong(Index: integer): uint64;
    procedure SetULong(Index: integer; const Value: uint64);

    function GetInt128(Index: integer): Int128;
    procedure SetInt128(Index: integer; const Value: Int128);
    function GetUInt128(Index: integer): UInt128;
    procedure SetUInt128(Index: integer; const Value: UInt128);

    function GetFloat(Index: integer): double;
    procedure SetFloat(Index: integer; const Value: double);
    function GetDateTime(Index: integer): TDateTime;
    procedure SetDateTime(Index: integer; const Value: TDateTime);
    function GetBool(Index: integer): boolean;
    procedure SetBool(Index: integer; const Value: boolean);

    (*
      * [PITFALL] GetArray / GetObject do NOT perform type checks.
      * Using the wrong accessor on a value of a different type may
      * crash or behave differently between FPC and Delphi backends.
    *)
    function GetArray(Index: integer): TZ_JsonArray;
    function GetObject(Index: integer): TZ_JsonObject;

    (*
      * Property shortcuts.
      *
      * [PITFALL] "A" and "O" accessors assume the element IS an array /
      * object. If the element holds a different type, the call may
      * crash (FPC) or silently misbehave (Delphi).
      *
      * [PITFALL] "I128" and "U128" are STRING-backed. Setting them
      * writes a quoted string into the JSON output.
    *)
    property S[Index: integer]: string read GetString write SetString;
    property I[Index: integer]: integer read GetInt write SetInt;
    property I32[Index: integer]: integer read GetInt write SetInt;
    property L[Index: integer]: int64 read GetLong write SetLong;
    property I64[Index: integer]: int64 read GetLong write SetLong;
    property I128[Index: integer]: Int128 read GetInt128 write SetInt128;
    property U[Index: integer]: uint64 read GetULong write SetULong;
    property U64[Index: integer]: uint64 read GetULong write SetULong;
    property U128[Index: integer]: UInt128 read GetUInt128 write SetUInt128;
    property F[Index: integer]: double read GetFloat write SetFloat;
    property D[Index: integer]: TDateTime read GetDateTime write SetDateTime;
    property B[Index: integer]: boolean read GetBool write SetBool;
    property A[Index: integer]: TZ_JsonArray read GetArray;
    property O[Index: integer]: TZ_JsonObject read GetObject;

    function GetCount: integer;
    property Count: integer read GetCount;
  end;

  (*
    * TZ_JsonObject - the tree node.
    *
    * ==============================================================================
    * [P10-1] TZ_JsonObject IS A TREE NODE, NOT A FLAT MAP
    * ==============================================================================
    *
    * Root objects (Parent = nil):
    *   - Own FInstance and free it on destroy.
    *   - Parae / Assign / LoadFromStream / ParseText ARE allowed.
    *
    * Child objects (Parent <> nil):
    *   - Do NOT own FInstance. FInstance points into the parent tree.
    *   - Parae / Assign / LoadFromStream / ParseText are FORBIDDEN. Any
    *     of them will orphan the parent tree node and leave dangling
    *     pointers, causing delayed crashes during ToBytes / serialization,
    *     silent field loss, or corrupted output.
    *
    * If you must inject parsed JSON into a child, do this instead:
    *   1. Parse in an INDEPENDENT ROOT object.
    *   2. Extract compact JSON string via ToJSONString(False).
    *   3. Concatenate in Unicode space using TZ_JsonString.
    *   4. Convert to bytes with .Bytes as the LAST step.
    *
    * ==============================================================================
    * [PITFALL] GetArray / GetObject AUTO-CREATE missing keys
    * ==============================================================================
    *
    * Reading js.A['maybe'] silently inserts an empty array into the JSON.
    * Use Exists() first if you want read-only access that does not mutate.
    *
    * ==============================================================================
    * [PITFALL] Set_Default_S is a WRITE, not a "set default"
    * ==============================================================================
    *
    * Despite the name, Set_Default_S overwrites the existing value. Use
    * Get_Default_S for read-with-default semantics.
    *
    * ==============================================================================
    * [PITFALL] SaveToStream(stream) defaults to FORMATTED output
    * ==============================================================================
    *
    * Pass Formated_ = False explicitly for compact output.
  *)
  TZ_JsonObject = class(TZ_JsonBase)
  private
    FInstance: TZ_Instance_JsonObject;
    FTag: integer;
  public
    property Tag: integer read FTag write FTag;

    (*
      * Underlying backend instance. Do NOT touch unless you fully
      * understand the tree ownership rules.
    *)
    property Instance: TZ_Instance_JsonObject read FInstance;

    (*
      * Root constructor.
      *
      * Creates a fresh empty backend object. FInstance is owned by this
      * object and freed in the destructor.
    *)
    constructor Create(); overload;

    (*
      * Child constructor.
      *
      * [PITFALL - P10-1] With Parent <> nil this constructor does NOT
      * create FInstance. The instance is expected to be assigned
      * externally by GetObject / AddObject / InsertObject. Manually
      * creating a child object and then calling any accessor will
      * crash. Likewise, do not attach a manually created instance to
      * a child unless you fully understand the tree.
      *
      * [PITFALL] The child is auto-registered into Parent.FList with
      * AutoFreeObj = True. Do not free it manually.
    *)
    constructor Create(Parent_: TZ_JsonBase); overload; override;
    destructor Destroy; override;

    (*
      * [PITFALL] SwapInstance raises 'error.' if called on a child.
      * Only valid on ROOT objects.
    *)
    procedure SwapInstance(source_: TZ_JsonObject);

    (*
      * [PITFALL - P10-1] Assign internally does:
      *   source_.SaveToStream(m64);
      *   m64.Position := 0;
      *   LoadFromStream(m64);
      *
      * LoadFromStream replaces FInstance. On a CHILD object this leaves
      * dangling pointers in the parent tree and later crashes during
      * ToBytes or serialization.
      *
      * ONLY call Assign on ROOT objects.
    *)
    procedure Assign(source_: TZ_JsonObject);

    (*
      * Deep clone via a fresh root object. Safe on any object because
      * the result is itself a ROOT.
    *)
    function Clone: TZ_JsonObject;

    procedure Clear;

    (*
      * Key lookup.
      *
      * IndexOf returns -1 when the key is missing.
      * Exists is IndexOf(Name) >= 0.
    *)
    function IndexOf(const Name: string): integer;
    function Exists(const Name: string): boolean;

    (*
      * [PITFALL] Int128 / UInt128 are stored as STRINGS, not numbers.
      * See TZ_JsonArray.Add for the same warning.
    *)
    function GetInt128(const Name: string): Int128;
    procedure SetInt128(const Name: string; const Value: Int128);
    function GetUInt128(const Name: string): UInt128;
    procedure SetUInt128(const Name: string; const Value: UInt128);

    (*
      * Named readers / writers.
      *
      * [PITFALL] Reading a missing key returns a backend default:
      *   - S[missing] returns ''   (empty string)
      *   - I[missing] returns 0
      *   - F[missing] returns 0.0
      *   - B[missing] returns False
      * This behavior is not guaranteed to be identical between FPC and
      * Delphi backends. Prefer Exists() when the distinction between
      * "missing" and "empty" matters.
      *
      * [PITFALL] Writing a value creates the key if missing.
    *)
    function GetString(const Name: string): string;
    procedure SetString(const Name, Value: string);
    function GetInt(const Name: string): integer;
    procedure SetInt(const Name: string; const Value: integer);
    function GetLong(const Name: string): int64;
    procedure SetLong(const Name: string; const Value: int64);
    function GetULong(const Name: string): uint64;
    procedure SetULong(const Name: string; const Value: uint64);
    function GetFloat(const Name: string): double;
    procedure SetFloat(const Name: string; const Value: double);
    function GetDateTime(const Name: string): TDateTime;
    procedure SetDateTime(const Name: string; const Value: TDateTime);
    function GetBool(const Name: string): boolean;
    procedure SetBool(const Name: string; const Value: boolean);

    (*
      * [PITFALL - AUTO-CREATE] GetArray(Name) / GetObject(Name) create
      * the key if it is missing. A "read" call therefore mutates the
      * tree. Use Exists() if you need non-mutating lookup.
      *
      * [PITFALL] No type check. If the existing value is not the
      * requested kind, behavior is backend-dependent:
      *   - FPC    : may create a new node, overwriting the old value
      *   - Delphi : may raise an exception or return a broken wrapper
      *
      * Always confirm the type with Exists() plus a manual check if the
      * value could have been produced by external code.
    *)
    function GetArray(const Name: string): TZ_JsonArray;
    function GetObject(const Name: string): TZ_JsonObject;

    (*
      * Property shortcuts.
      *
      * [PITFALL] "A" and "O" AUTO-CREATE the key on first read. If you
      * write "if js.A['maybe'].Count > 0 then ..." as a read-only probe
      * you will silently insert an empty array.
      *
      * [PITFALL] "I128" / "U128" are STRING-backed. Setting them writes
      * a quoted string into the JSON output. Round-trip conversion
      * requires manual Int128(...) / UInt128(...) calls.
      *
      * [PITFALL] "D" (TDateTime) is stored as a string, NOT ISO 8601.
      * The umlDateTimeToStr format is used, which is "yyyy-MM-dd
      * hh:mm:ss.zzz" and is not interchangeable with RFC 3339 or the
      * ISO 8601 T-separator form used by many external systems.
    *)
    property S[const Name: string]: string read GetString write SetString;
    property I[const Name: string]: integer read GetInt write SetInt;
    property I32[const Name: string]: integer read GetInt write SetInt;
    property L[const Name: string]: int64 read GetLong write SetLong;
    property I64[const Name: string]: int64 read GetLong write SetLong;
    property I128[const Name: string]: Int128 read GetInt128 write SetInt128;
    property U[const Name: string]: uint64 read GetULong write SetULong;
    property U64[const Name: string]: uint64 read GetULong write SetULong;
    property U128[const Name: string]: UInt128 read GetUInt128 write SetUInt128;
    property F[const Name: string]: double read GetFloat write SetFloat;
    property D[const Name: string]: TDateTime read GetDateTime write SetDateTime;
    property B[const Name: string]: boolean read GetBool write SetBool;
    property A[const Name: string]: TZ_JsonArray read GetArray;
    property O[const Name: string]: TZ_JsonObject read GetObject;

    (*
      * Key enumeration by index. Order of iteration follows the backend
      * insertion order and is not guaranteed to be identical between
      * FPC and Delphi.
    *)
    function GetName(Index: integer): string;
    property Names[Index: integer]: string read GetName; default;
    function GetCount: integer;
    property Count: integer read GetCount;

    (*
      * [PITFALL] Get_Default_S is a READ-with-default: returns the
      * existing value or Value without inserting anything.
      *
      * [PITFALL] Set_Default_S is a WRITE: overwrites any existing value
      * despite the "default" in the name. Get_Default_S and
      * GetDefault_S behave identically; Set_Default_S and SetDefault_S
      * behave identically. The duplicated names are historical; they
      * are not two different operations.
    *)
    function Get_Default_S(const Name, Value: string): string;
    procedure Set_Default_S(const Name, Value: string);

    function GetDefault_S(const Name, Value: string): string;
    procedure SetDefault_S(const Name, Value: string);

    (*
      * Serialization.
      *
      * [PITFALL - P10-1] LoadFromStream REPLACES FInstance. On a CHILD
      * object this leaves dangling pointers in the parent tree.
      * ONLY call LoadFromStream on ROOT objects.
      *
      * [PITFALL] SaveToStream(stream) defaults to FORMATTED output.
      * Pass Formated_ = False for compact.
      *
      * [PITFALL] LoadFromFile fails SILENTLY on missing / malformed
      * files: the exception branch just exits and leaves the object
      * untouched. Always verify with Count / Exists afterwards.
    *)
    procedure SaveToStream(stream: TCore_Stream; Formated_: boolean); overload;
    procedure SaveToStream(stream: TCore_Stream); overload;
    procedure LoadFromStream(stream: TCore_Stream);
    procedure SaveToFile(FileName: SystemString);
    procedure LoadFromFile(FileName: SystemString);

    (*
      * MD5 of the UNFORMATTED serialization.
      *
      * [PITFALL] Byte-level output may differ between FPC and Delphi
      * (key order, whitespace, encoding). Do not assume the digest is
      * stable across compilers.
    *)
    function GetMD5: TMD5;
    property MD5: TMD5 read GetMD5;

    (*
      * [PITFALL - P10-1] Parae (typo for Parse) REPLACES FInstance by
      * calling LoadFromStream.
      *
      *   - ONLY valid on ROOT objects.
      *   - NEVER call on a child / grandchild; it leaves the parent
      *     tree with dangling pointers => crash on next ToBytes or
      *     serialization, lost fields, corrupted output.
      *
      * To inject parsed JSON into a child, do:
      *   1. Parse in an INDEPENDENT ROOT object.
      *   2. Extract compact JSON string via ToJSONString(False).
      *   3. Concatenate in Unicode space using TZ_JsonString.
      *   4. Convert to bytes with .Bytes as the LAST step.
      *
      * [PITFALL] Empty TBytes: @buff[0] is out of range. Guard with
      * Length(buff) > 0 before calling.
      *
      * [PITFALL] The return value only reports whether the operation
      * threw an exception. It does NOT report JSON validity. Always
      * follow up with a structural check (Count > 0, Exists('key')).
    *)
    function Parae(buff: TBytes): boolean;

    (*
      * Serialize to bytes. Uses the FORMATTED form internally.
      * Exceptions are swallowed; the result may be an empty array on
      * failure. This is the same code path used by SaveToStream.
    *)
    function ToBytes: TBytes;

    (*
      * [PITFALL - P10-1] ParseText on a CHILD object has the same
      * orphaning problem as Parae. ONLY call on ROOT objects.
      *
      * [PITFALL] On failure the object's state is UNDEFINED:
      *   - FPC    : FInstance is replaced with a fresh empty object.
      *   - Delphi : FInstance may be left partially modified.
      * Re-create the object after a failed ParseText.
      *
      * [PITFALL] UseUTF8 = True forces UTF-8 decoding. For plain ASCII
      * content either True or False works, but mixing encodings across
      * calls leads to inconsistent results.
    *)
    function ParseText(Text_: TZ_JsonString; UseUTF8: boolean): boolean; overload;
    function ParseText(Text_: TZ_JsonString): boolean; overload;

    (*
      * Serialize to TZ_JsonString.
      *
      * [PITFALL - P10-2] The result is UTF-16 on FPC (TUPascalString)
      * and TPascalString on Delphi. NEVER assign the result to a plain
      * `string` variable before the final byte conversion. On Windows
      * with CP936, emoji / Korean / rare CJK characters silently
      * become '?'.
      *
      * Correct pattern:
      *   var s: TZ_JsonString;
      *   s := jo.ToJSONString(False);
      *   reqBytes := s.Bytes;    // UTF-8 bytes, lossless
      *
      * [PITFALL] FPC uses FormatJSON([], 2) for Formated_=True (2-space
      * indent). Delphi uses FInstance.ToJson(not Formated_) and its
      * formatting may differ. Cross-compiler byte-level consistency of
      * the formatted output is NOT guaranteed.
      *
      * [PITFALL] When Formated_=False the compact forms also differ
      * slightly between compilers (spacing, key order). For stable
      * bytes across compilers, always re-parse then re-serialize.
    *)
    function ToJSONString(Formated_: boolean): TZ_JsonString; overload;
    function ToJSONString: TZ_JsonString; overload;
    property ToJson: TZ_JsonString read ToJSONString;

    class procedure Test;
  end;

  TZ_JsonObject_List_Decl = TGenericsList<TZ_JsonObject>;

  (*
    * TZ_JsonObject_List - list of root TZ_JsonObject.
    *
    * [PITFALL] With AutoFreeObj = False, Destroy calls Clear which does
    * NOT free the elements => memory leak. Either set AutoFreeObj =
    * True, or call Clean explicitly before destruction.
  *)
  TZ_JsonObject_List = class(TZ_JsonObject_List_Decl)
  public
    AutoFreeObj: boolean;
    constructor Create(AutoFreeObj_: boolean);
    destructor Destroy; override;

    (*
      * [PITFALL] AddFromText / AddFromStream / AddFromFile add the
      * newly created object to the list even if parsing fails. The
      * returned object may be empty. Verify with Count / Exists.
    *)
    function AddFromText(Text_: TZ_JsonString): TZ_JsonObject;
    function AddFromStream(stream: TCore_Stream): TZ_JsonObject;
    function AddFromFile(FileName: U_String): TZ_JsonObject;

    procedure Remove(obj: TZ_JsonObject);
    procedure Delete(Index: integer);

    (*
      * Clear respects AutoFreeObj. With AutoFreeObj = False the
      * elements are removed from the list but NOT freed.
    *)
    procedure Clear;

    (*
      * Clean ALWAYS frees every element, regardless of AutoFreeObj.
      * Use it to force release when AutoFreeObj = False.
    *)
    procedure Clean;
  end;

  TZJArry = TZ_JsonArray;
  TZJ = TZ_JsonObject;
  TZJList = TZ_JsonObject_List;
  TZJL = TZ_JsonObject_List;

implementation

{$IFDEF DELPHI}
{$I Z.Json_delphi.inc}
{$ELSE DELPHI}
{$I Z.Json_fpc.inc}
{$ENDIF DELPHI}


(*
  * TZ_JsonBase.Create
  *
  * Registers the child into Parent.FList (AutoFreeObj = True). The
  * parent takes ownership of every child created via this constructor.
  *
  * [PITFALL] Do NOT manually free a child that has a parent; the parent
  * will free it and you would double-free.
*)
constructor TZ_JsonBase.Create(Parent_: TZ_JsonBase);
begin
  inherited Create;
  FParent := Parent_;
  if FParent <> nil then
      FParent.FList.Add(self);

  FList := TCore_ObjectList.Create;
  FList.AutoFreeObj := True;
end;

(*
  * TZ_JsonBase.Destroy
  *
  * Releases all registered children through FList.Free.
*)
destructor TZ_JsonBase.Destroy;
begin
  FList.Free;
  inherited Destroy;
end;

(*
  * TZ_JsonArray.Create
  *
  * [PITFALL] Does NOT create FInstance. The underlying array is
  * attached externally by AddArray / InsertArray / GetArray. A
  * manually constructed TZ_JsonArray without an external FInstance
  * assignment will crash on first use.
*)
constructor TZ_JsonArray.Create(Parent_: TZ_JsonBase);
begin
  inherited Create(Parent_);
end;

destructor TZ_JsonArray.Destroy;
begin
  inherited Destroy;
end;

(*
  * [PITFALL] Int128 is stored as a STRING, not a number. JSON output
  * contains a quoted string such as "1234567890". Reading back requires
  * manual conversion via Int128(...).
*)
procedure TZ_JsonArray.Add(const v_: Int128);
begin
  Add(v_.ToLString.Text);
end;

(*
  * [PITFALL] UInt128 is stored as a STRING, not a number. See
  * TZ_JsonArray.Add(Int128) for the same warning.
*)
procedure TZ_JsonArray.Add(const v_: UInt128);
begin
  Add(v_.ToLString.Text);
end;

procedure TZ_JsonArray.Insert(Index: integer; const v_: Int128);
begin
  Insert(Index, v_.ToLString.Text);
end;

procedure TZ_JsonArray.Insert(Index: integer; const v_: UInt128);
begin
  Insert(Index, v_.ToLString.Text);
end;

(*
  * [PITFALL] Reading an Int128 from an empty / missing string may raise
  * or return 0 depending on the backend. Guard with a length check.
*)
function TZ_JsonArray.GetInt128(Index: integer): Int128;
begin
  Result := Int128(TZ_JsonString(GetString(Index)).Text);
end;

procedure TZ_JsonArray.SetInt128(Index: integer; const Value: Int128);
begin
  SetString(Index, Value.ToLString.Text);
end;

function TZ_JsonArray.GetUInt128(Index: integer): UInt128;
begin
  Result := UInt128(TZ_JsonString(GetString(Index)).Text);
end;

procedure TZ_JsonArray.SetUInt128(Index: integer; const Value: UInt128);
begin
  SetString(Index, Value.ToLString.Text);
end;

(*
  * Root constructor. Creates the underlying backend object.
*)
constructor TZ_JsonObject.Create;
begin
  Create(nil);
end;

(*
  * [PITFALL - P10-1] Child constructor does NOT create FInstance. It
  * is expected to be assigned externally via GetObject / AddObject /
  * InsertObject. Do NOT manually assign FInstance unless you fully
  * understand the tree ownership rules.
*)
constructor TZ_JsonObject.Create(Parent_: TZ_JsonBase);
begin
  inherited Create(Parent_);
  FTag := 0;
  if Parent = nil then
      FInstance := TZ_Instance_JsonObject.Create;
end;

(*
  * [PITFALL] Only the ROOT object frees FInstance. Child objects do NOT
  * own their instance; it belongs to the parent tree.
*)
destructor TZ_JsonObject.Destroy;
begin
  if Parent = nil then
      FInstance.Free;
  inherited Destroy;
end;

(*
  * [PITFALL] Raises 'error.' if called on a child object. Only ROOT
  * objects are allowed to swap instances.
*)
procedure TZ_JsonObject.SwapInstance(source_: TZ_JsonObject);
var
  bak_FParent: TZ_JsonBase;
  bak_FList: TCore_ObjectList;
  bak_FInstance: TZ_Instance_JsonObject;
  bak_FTag: integer;
begin
  if FParent <> nil then
      raiseInfo('error.');
  bak_FParent := FParent;
  bak_FList := FList;
  bak_FInstance := FInstance;
  bak_FTag := FTag;

  FParent := source_.FParent;
  FList := source_.FList;
  FInstance := source_.FInstance;
  FTag := source_.FTag;

  source_.FParent := bak_FParent;
  source_.FList := bak_FList;
  source_.FInstance := bak_FInstance;
  source_.FTag := bak_FTag;
end;

(*
  * [PITFALL - P10-1] Assign internally does:
  *   source_.SaveToStream(m64);
  *   m64.Position := 0;
  *   LoadFromStream(m64);
  *
  * LoadFromStream REPLACES FInstance. On a CHILD object this leaves
  * dangling pointers in the parent tree and later crashes during
  * ToBytes or serialization.
  *
  * ONLY call Assign on ROOT objects.
*)
procedure TZ_JsonObject.Assign(source_: TZ_JsonObject);
var
  m64: TMS64;
begin
  m64 := TMS64.Create;
  source_.SaveToStream(m64);
  m64.Position := 0;
  LoadFromStream(m64);
  disposeObject(m64);
end;

(*
  * Deep clone via a fresh root object. The result is itself a ROOT, so
  * Clone is safe to call on any object (root or child).
*)
function TZ_JsonObject.Clone: TZ_JsonObject;
begin
  Result := TZ_JsonObject.Create;
  Result.Assign(self);
end;

function TZ_JsonObject.Exists(const Name: string): boolean;
begin
  Result := IndexOf(Name) >= 0;
end;

(*
  * [PITFALL] Int128 is stored as a STRING, not a number.
*)
function TZ_JsonObject.GetInt128(const Name: string): Int128;
begin
  Result := Int128(TZ_JsonString(GetString(Name)).Text);
end;

procedure TZ_JsonObject.SetInt128(const Name: string; const Value: Int128);
begin
  SetString(Name, Value.ToLString);
end;

(*
  * [PITFALL] UInt128 is stored as a STRING, not a number.
*)
function TZ_JsonObject.GetUInt128(const Name: string): UInt128;
begin
  Result := UInt128(TZ_JsonString(GetString(Name)).Text);
end;

procedure TZ_JsonObject.SetUInt128(const Name: string; const Value: UInt128);
begin
  SetString(Name, Value.ToLString);
end;

(*
  * [PITFALL] Despite the name, this is a READ-with-default. If the key
  * exists its value is returned; otherwise Value is returned WITHOUT
  * inserting it. The name's "Set" pair below is the counterpart.
*)
function TZ_JsonObject.Get_Default_S(const Name, Value: string): string;
begin
  if Exists(Name) then
      Result := S[Name]
  else
      Result := Value;
end;

(*
  * [PITFALL] Despite the name, this is a WRITE. It OVERWRITES any
  * existing value. Do not use it to "seed a default".
*)
procedure TZ_JsonObject.Set_Default_S(const Name, Value: string);
begin
  S[Name] := Value;
end;

(*
  * Identical to Get_Default_S. The duplicated name is historical, not
  * a semantic difference.
*)
function TZ_JsonObject.GetDefault_S(const Name, Value: string): string;
begin
  if Exists(Name) then
      Result := S[Name]
  else
      Result := Value;
end;

(*
  * Identical to Set_Default_S. The duplicated name is historical, not
  * a semantic difference.
*)
procedure TZ_JsonObject.SetDefault_S(const Name, Value: string);
begin
  S[Name] := Value;
end;

(*
  * [PITFALL] Default overload is FORMATTED output. Use
  * SaveToStream(stream, False) for compact JSON.
*)
procedure TZ_JsonObject.SaveToStream(stream: TCore_Stream);
begin
  SaveToStream(stream, True);
end;

procedure TZ_JsonObject.SaveToFile(FileName: SystemString);
var
  m64: TMS64;
begin
  m64 := TMS64.Create;
  try
    SaveToStream(m64);
    m64.SaveToFile(FileName);
  finally
      disposeObject(m64);
  end;
end;

(*
  * [PITFALL] LoadFromFile fails SILENTLY:
  *   - Missing file: the exception branch exits and leaves the object
  *     untouched.
  *   - Malformed file: LoadFromStream may set FInstance to nil on FPC.
  *
  * Always verify with Count / Exists afterwards.
*)
procedure TZ_JsonObject.LoadFromFile(FileName: SystemString);
var
  m64: TMS64;
begin
  m64 := TMS64.Create;
  try
      m64.LoadFromFile(FileName);
  except
    disposeObject(m64);
    Exit;
  end;

  try
      LoadFromStream(m64);
  finally
      disposeObject(m64);
  end;
end;

(*
  * [PITFALL] MD5 is computed on the UNFORMATTED serialization. Byte-level
  * output may differ between FPC and Delphi, so cross-compiler digest
  * consistency is NOT guaranteed.
*)
function TZ_JsonObject.GetMD5: TMD5;
var
  m64: TMS64;
begin
  m64 := TMS64.Create;
  SaveToStream(m64, False);
  Result := umlStreamMD5(m64);
  disposeObject(m64);
end;

(*
  * ==============================================================================
  * [P10-1] Parae - CRITICAL PITFALL
  * ==============================================================================
  *
  * Parae (typo for Parse) REPLACES FInstance by calling LoadFromStream
  * internally. It therefore inherits the same orphaning problem:
  *
  *   - ONLY valid on ROOT objects.
  *   - NEVER call on a child / grandchild. It will leave the parent tree
  *     with dangling pointers, causing:
  *       - random crashes / access violations
  *       - lost fields (for example options.response_format disappears)
  *       - schema field becomes null
  *       - delayed crash during ToBytes / serialization
  *
  * To inject parsed JSON into a child, do:
  *   1. Parse in an INDEPENDENT ROOT object.
  *   2. Extract compact JSON string via ToJSONString(False).
  *   3. Concatenate in Unicode space using TZ_JsonString.
  *   4. Convert to bytes with .Bytes as the LAST step.
  *
  * ------------------------------------------------------------------------------
  * [PITFALL] Empty TBytes: @buff[0] is out of range. Guard with
  * Length(buff) > 0 before calling.
  *
  * [PITFALL] The boolean result only reports whether an exception was
  * raised. It does NOT report JSON validity. Follow up with a structural
  * check (Count > 0, Exists('key')) if you need to trust the content.
  * ------------------------------------------------------------------------------
*)
function TZ_JsonObject.Parae(buff: TBytes): boolean;
var
  m64: TMS64;
begin
  try
    m64 := TMS64.Create;
    m64.Mapping(@buff[0], length(buff));
    LoadFromStream(m64);
    disposeObject(m64);
    Result := True;
  except
      Result := False;
  end;
end;

(*
  * Serialize to bytes. Uses the FORMATTED form internally through
  * SaveToStream. Exceptions are swallowed; the result may be an empty
  * array on failure.
*)
function TZ_JsonObject.ToBytes: TBytes;
var
  m64: TMS64;
begin
  try
    m64 := TMS64.Create;
    SaveToStream(m64);
    Result := m64.ToBytes;
    disposeObject(m64);
  except
  end;
end;

(*
  * ==============================================================================
  * [P10-1] ParseText - CRITICAL PITFALL
  * ==============================================================================
  *
  * ParseText on a CHILD object has the same orphaning problem as Parae.
  * The FPC branch explicitly calls DisposeObjectAndNil(FInstance) and
  * creates a fresh instance; the Delphi branch delegates to
  * FromJSON / FromUtf8JSON which replaces the internal tree as well.
  *
  * ONLY call on ROOT objects.
  *
  * ------------------------------------------------------------------------------
  * [PITFALL] On failure the object's state is UNDEFINED:
  *   - FPC    : FInstance is replaced with a fresh empty object.
  *   - Delphi : FInstance may be left partially modified.
  * Re-create the object after a failed ParseText.
  *
  * [PITFALL] UseUTF8 = True forces UTF-8 decoding. For plain ASCII
  * content either True or False works, but mixing encodings across
  * calls leads to inconsistent results.
  * ------------------------------------------------------------------------------
*)
function TZ_JsonObject.ParseText(Text_: TZ_JsonString; UseUTF8: boolean): boolean;
{$IFDEF FPC}
var j: TJSONData;
{$ENDIF FPC}
begin
  try
{$IFDEF FPC}
    DisposeObjectAndNil(FInstance);
    j := GetJSON(Text_.Text, UseUTF8);
    if Assigned(j) and (j is TZ_Instance_JsonObject) then
        FInstance := TZ_Instance_JsonObject(j)
    else
      begin
        FInstance := nil;
        DisposeObjectAndNil(j);
      end;
    Result := FInstance <> nil;
    if FInstance = nil then
        FInstance := TZ_Instance_JsonObject.Create;
{$ELSE FPC}
    if UseUTF8 then
        FInstance.FromUtf8JSON(Text_.Text)
    else
        FInstance.FromJSON(Text_.Text);
{$ENDIF FPC}
    Result := True;
  except
      Result := False;
  end;
end;

function TZ_JsonObject.ParseText(Text_: TZ_JsonString): boolean;
begin
  Result := ParseText(Text_, False);
end;

(*
  * ==============================================================================
  * [P10-2] ToJSONString - CRITICAL PITFALL
  * ==============================================================================
  *
  * The result is TZ_JsonString, which is:
  *   - FPC    : TUPascalString (UTF-16)
  *   - Delphi : TPascalString
  *
  * NEVER assign the result to a plain `string` variable before the final
  * byte conversion. On Windows with CP936 (Chinese Simplified), emoji,
  * Korean, and rare CJK characters silently become '?'.
  *
  * Correct pattern:
  *   var s: TZ_JsonString;
  *   s := jo.ToJSONString(False);
  *   reqBytes := s.Bytes;    // UTF-8 bytes, lossless
  *
  * The wrong pattern:
  *   var s: string;
  *   s := jo.ToJSONString(False).Text;      // lossy on FPC Windows
  *   reqBytes := TEncoding.UTF8.GetBytes(s); // double loss
  *
  * ------------------------------------------------------------------------------
  * [PITFALL] Formatting differences between compilers:
  *   - FPC    : FormatJSON([], 2) for Formated_=True (2-space indent)
  *   - Delphi : FInstance.ToJson(not Formated_) with its own formatting
  *
  * Cross-compiler byte-level consistency of the formatted output is
  * NOT guaranteed. If you need stable bytes across compilers, always
  * re-parse then re-serialize, or hash only the parsed structure.
  * ------------------------------------------------------------------------------
*)
function TZ_JsonObject.ToJSONString(Formated_: boolean): TZ_JsonString;
begin
{$IFDEF FPC}
  if Formated_ then
      Result.Text := FInstance.FormatJSON([], 2)
  else
      Result.Text := FInstance.AsJSON;
{$ELSE}
  Result.Text := FInstance.ToJson(not Formated_);
{$ENDIF}
end;

function TZ_JsonObject.ToJSONString: TZ_JsonString;
begin
  Result := ToJSONString(True);
end;

(*
  * Self-test / demo. Educational only; not for production use.
  *
  * [PITFALL - P10-1] The line marked below calls LoadFromStream on a
  * CHILD object (js.O['obj']). This is FORBIDDEN in production code
  * because it orphans the parent tree. It is preserved here only as a
  * historical example and MUST NOT be reproduced in new code.
  *
  * To do the same thing correctly, parse into an independent ROOT
  * object and merge the fields explicitly.
*)
class procedure TZ_JsonObject.Test;
var
  js: TZ_JsonObject;
  ii: integer;
  m64: TMS64;
begin
  js := TZ_JsonObject.Create();
  js.S['abc'] := '123';
  DoStatus(js.S['abc']);

  for ii := 1 to 3 do
      js.A['arry'].Add(ii);

  for ii := 0 to js.A['arry'].Count - 1 do
    begin
      DoStatus(js.A['arry'].I[ii]);
    end;

  js.A['arry'].AddObject.S['tt'] := 'inobj';

  js.O['obj'].S['fff'] := '999';

  DoStatus(js.ToJSONString(True));
  DoStatus('');
  DoStatus(js.O['obj'].ToJSONString(True));

  (*
    * [PITFALL - P10-1] DEMO ONLY - DO NOT COPY.
    *
    * The call below is js.O['obj'].LoadFromStream(m64). Because
    * js.O['obj'] is a CHILD of js, this replaces its FInstance and
    * leaves js with a dangling pointer. New code must use an
    * independent ROOT object and merge the fields explicitly.
  *)
  m64 := TMS64.Create;
  js.SaveToStream(m64);
  m64.Position := 0;
  js.O['obj'].LoadFromStream(m64);
  DoStatus(js.ToJSONString(True));
  js.Free;
end;

constructor TZ_JsonObject_List.Create(AutoFreeObj_: boolean);
begin
  inherited Create;
  AutoFreeObj := AutoFreeObj_;
end;

(*
  * [PITFALL] Destroy calls Clear which honors AutoFreeObj. With
  * AutoFreeObj = False, the elements are NOT freed => memory leak.
  * Either set AutoFreeObj = True, or call Clean explicitly before
  * destruction.
*)
destructor TZ_JsonObject_List.Destroy;
begin
  Clear;
  inherited Destroy;
end;

(*
  * [PITFALL] The new object is added to the list even if parsing fails.
  * The returned object may be empty. Verify with Count / Exists.
*)
function TZ_JsonObject_List.AddFromText(Text_: TZ_JsonString): TZ_JsonObject;
begin
  Result := TZ_JsonObject.Create(nil);
  Result.ParseText(Text_);
  Add(Result);
end;

(*
  * [PITFALL] The new object is added even if stream parsing fails.
*)
function TZ_JsonObject_List.AddFromStream(stream: TCore_Stream): TZ_JsonObject;
begin
  Result := TZ_JsonObject.Create(nil);
  Result.LoadFromStream(stream);
  Add(Result);
end;

(*
  * [PITFALL] The new object is added even if the file is missing or
  * malformed. LoadFromFile fails silently; verify the result.
*)
function TZ_JsonObject_List.AddFromFile(FileName: U_String): TZ_JsonObject;
begin
  Result := TZ_JsonObject.Create(nil);
  Result.LoadFromFile(FileName);
  Add(Result);
end;

procedure TZ_JsonObject_List.Remove(obj: TZ_JsonObject);
begin
  if AutoFreeObj then
      disposeObject(obj);
  inherited Remove(obj);
end;

procedure TZ_JsonObject_List.Delete(Index: integer);
begin
  if (Index >= 0) and (Index < Count) then
    begin
      if AutoFreeObj then
          disposeObject(Items[Index]);
      inherited Delete(Index);
    end;
end;

(*
  * [PITFALL] Clear respects AutoFreeObj. With AutoFreeObj = False, the
  * elements are removed from the list but NOT freed. Use Clean to force
  * release regardless of the flag.
*)
procedure TZ_JsonObject_List.Clear;
var
  I: integer;
begin
  if AutoFreeObj then
    for I := 0 to Count - 1 do
        disposeObject(Items[I]);
  inherited Clear;
end;

(*
  * Clean ALWAYS frees every element, regardless of AutoFreeObj. Use it
  * to force release when AutoFreeObj = False.
*)
procedure TZ_JsonObject_List.Clean;
var
  I: integer;
begin
  for I := 0 to Count - 1 do
      disposeObject(Items[I]);
  inherited Clear;
end;

initialization

end.

{
  * Z.TextDataEngine – INI‑style text configuration engine.
  * ========================================================
  * This unit provides a flexible, high‑performance INI‑like text data engine
  * that stores key‑value pairs organised into sections. It supports both
  * Variant and string values, automatic lazy loading/parsing, import/export
  * to/from plain text, and stream/file persistence. The engine maintains
  * three parallel storage layers:
  *   – Raw string lists (TCore_Strings) for sections.
  *   – Optimised hash variant lists (THashVariantList) for fast Variant access.
  *   – Optimised hash string lists (THashStringList) for fast string access.
  *
  * The engine lazily converts between layers: when a section is first accessed
  * via variant or string hash, it parses the raw string list and caches the
  * result, improving subsequent access performance. All modifications are
  * tracked via the IsChanged property.
  *
  * ============================================================================
  *  TWO OPERATING MODES – CHOOSE ONE AND STICK WITH IT
  * ============================================================================
  * The engine provides two independent access modes that share the same
  * underlying data. You should choose ONE mode for each section and use it
  * consistently. Mixing modes on the same section can lead to unexpected
  * behaviour because each mode maintains its own cache.
  *
  *   ┌───────────────────────────────────────────────────────────────────────┐
  *   │  VARIANT MODE (preferred for mixed data types)                        │
  *   │  – Use: Hit[], HitVariant[], VariantList[], HVariantList[]            │
  *   │  – Stores values as Variant (supports Integer, Float, String, etc.)   │
  *   │  – Values are automatically typed when read                           │
  *   │  – Best for: configuration with mixed types (numbers, booleans)       │
  *   │  – Example:                                                           │
  *   │      engine.Hit['Settings', 'Timeout'] := 5000;    // Integer         │
  *   │      engine.Hit['Settings', 'Enabled'] := True;   // Boolean          │
  *   │      v := engine.Hit['Settings', 'Timeout'];      // returns Variant  │
  *   └───────────────────────────────────────────────────────────────────────┘
  *
  *   ┌───────────────────────────────────────────────────────────────────────┐
  *   │  TEXT MODE (for pure string storage)                                  │
  *   │  – Use: HitString[], HitS[], SHit[], StringList[], HStringList[]      │
  *   │  – Stores values as plain SystemString                                │
  *   │  – All values are strings; you parse them manually                    │
  *   │  – Best for: INI files where all values are naturally strings         │
  *   │  – Example:                                                           │
  *   │      engine.HitString['Settings', 'Timeout'] := '5000';   // String   │
  *   │      engine.HitString['Settings', 'Enabled'] := 'True';   // String   │
  *   │      s := engine.HitString['Settings', 'Timeout'];       // string    │
  *   └───────────────────────────────────────────────────────────────────────┘
  *
  *  IMPORTANT: Do NOT use Hit[] and HitString[] on the same section/key
  *  combination. The two caches are independent and will not stay in sync.
  *
  * ============================================================================
  *  COMMENT HANDLING DURING IMPORT
  * ============================================================================
  * When importing from a TPascalStringList (via DataImport), the engine
  * automatically removes everything after a semicolon (';') on each line.
  * This mimics the standard INI comment behaviour where ';' marks the start
  * of a comment.
  *
  *  Example input:
  *    [Server]
  *    Port=8080  ; Listen port for HTTP traffic
  *    Host=0.0.0.0  ; Bind to all interfaces
  *
  *  After import, the stored values will be:
  *    Port=8080
  *    Host=0.0.0.0
  *
  *  The ';' and everything after it are discarded and NOT stored.
  *
  *  Lines outside any section that do NOT start with ';' are treated as
  *  global comments and preserved in the Comment property.
  *
  *  Lines that start with ';' (outside sections) are ignored entirely.
  *
  * ============================================================================
  *  TYPED GETTERS (Auto‑parsing helpers)
  * ============================================================================
  * The engine provides typed getters that automatically parse string values
  * into the requested type. These work with BOTH modes because they read
  * from the string cache (HStringList), which is always kept in sync.
  *
  *   – GetDefaultText_I32()   → Integer (32‑bit)
  *   – GetDefaultText_I64()   → Int64  (64‑bit)
  *   – GetDefaultText_I128()  → Int128 (128‑bit)
  *   – GetDefaultText_Float() → Double
  *   – GetDefaultText_Bool()  → Boolean
  *   – GetDefaultText_DT()    → TDateTime
  *
  *  These are safe: if the value is missing or cannot be parsed, the
  *  default value is returned. They are recommended for reading typed
  *  configuration values.
  *
  * @Example:
  *   var
  *     cfg: THashTextEngine;
  *   begin
  *     cfg := THashTextEngine.Create;
  *
  *     // --- Variant mode example ---
  *     cfg.Hit['Network', 'Port'] := 8080;                        // Integer
  *     cfg.Hit['Network', 'Enabled'] := True;                    // Boolean
  *     cfg.Hit['Network', 'Name'] := 'MyServer';                 // String
  *     Port := cfg.GetDefaultText_I32('Network', 'Port', 80);   // 8080
  *
  *     // --- Text mode example ---
  *     cfg.HitString['Database', 'Host'] := 'localhost';
  *     cfg.HitString['Database', 'Port'] := '5432';
  *     Host := cfg.HitString['Database', 'Host'];              // 'localhost'
  *     DbPort := cfg.GetDefaultText_I32('Database', 'Port', 5432); // 5432
  *
  *     cfg.SaveToFile('config.ini');
  *     cfg.Free;
  *   end;
}
unit Z.TextDataEngine;

{$DEFINE FPC_DELPHI_MODE}
{$I Z.Define.inc}

interface

uses SysUtils, Variants,
{$IFDEF FPC}
  Z.FPC.GenericList,
{$ENDIF FPC}
  Z.Core,
  Z.UnicodeMixedLib,
  Z.PascalStrings,
  Z.ListEngine,
  Z.MemoryStream,
  Z.Int128;

type
  {
    * THashTextEngine – INI‑style text data engine.
    * ================================================
    * This class manages a collection of sections, each containing key‑value
    * pairs. It provides three views of the data:
    *   1. Raw string lists (the original text representation).
    *   2. Hash variant lists (for Variant values, optimised for fast lookup).
    *   3. Hash string lists (for string values, optimised for fast lookup).
    *
    * The engine lazily converts between views: when a section is accessed
    * as a hash list (via VariantList or StringList), it parses the raw
    * string list and caches the result. Subsequent accesses are fast.
    * This design balances memory usage with performance.
    *
    * The class supports default values, typed getters/setters, file/stream
    * persistence, and full import/export of INI‑style text. Comments are
    * stored separately and preserved during export.
    *
    * ==========================================================================
    *  MODE SELECTION – IMPORTANT
    * ==========================================================================
    * Choose ONE mode per section and use it consistently:
    *
    *   • Variant mode:  Use Hit[], HitVariant[], VariantList[]
    *   • Text mode:     Use HitString[], HitS[], SHit[], StringList[]
    *
    * Do NOT mix modes on the same section. The engine will NOT keep them
    * in sync automatically.
    *
    * ==========================================================================
    *  COMMENT HANDLING
    * ==========================================================================
    * When importing from TPascalStringList, any text after ';' on a line is
    * automatically stripped and discarded. This is the standard INI comment
    * behaviour. Global comments (lines outside sections that don't start
    * with ';') are preserved in the Comment property.
    *
    * @Example:
    *   var
    *     eng: THashTextEngine;
    *   begin
    *     eng := THashTextEngine.Create;
    *     eng.HitString['User', 'Name'] := 'Alice';          // Text mode
    *     eng.Hit['User', 'Age'] := 30;                      // Variant mode
    *     eng.GetDefaultText('User', 'City', 'Unknown');     // Read with default
    *     eng.SaveToFile('settings.ini');
    *     eng.Free;
    *   end;
  }
  THashTextEngine = class(TCore_Object_Intermediate)
  private
    FComment: TCore_Strings; { * Global comment lines (outside any section). }
    FSectionList, { * Raw string list per section (lazy‑loaded). }
    FSectionHashVariantList, { * Variant hash list per section (cached). }
    FSectionHashStringList: THashObjectList; { * String hash list per section (cached). }
    FAutoUpdateDefaultValue: Boolean; { * If True, missing keys return default and store it. }
    FSectionPoolSize, FListPoolSize: Integer; { * Initial hash table sizes (section and list pools). }
    FIsChanged: Boolean; { * True if data has been modified since last rebuild/save. }

    { * Returns the raw string list for a section, creating it if missing. }
    function GetNames(N_: SystemString): TCore_Strings;
    { * Replaces the raw string list for a section. }
    procedure SetNames(N_: SystemString; const Value: TCore_Strings);

    { * Gets a Variant value from a section/key, creating the hash cache if needed. }
    function GetHitVariant(SName, VName: SystemString): Variant;
    { * Sets a Variant value in a section/key. }
    procedure SetHitVariant(SName, VName: SystemString; const Value: Variant);

    { * Gets a string value from a section/key, creating the hash cache if needed. }
    function GetHitString(SName, VName: SystemString): SystemString;
    { * Sets a string value in a section/key. }
    procedure SetHitString(SName, VName: SystemString; const Value: SystemString);

    { * Returns the Variant hash list for a section, creating it if missing. }
    function GetHVariantList(N_: SystemString): THashVariantList;
    { * Returns the String hash list for a section, creating it if missing. }
    function GetHStringList(N_: SystemString): THashStringList;

    { * Internal helper: adds a section with a raw string list (used during import). }
    procedure AddDataSection(Section_: SystemString; TextList_: TCore_Strings);
  public
    { * Creates a new engine with default pool sizes (16 for sections and lists). }
    constructor Create; overload;
    { * Creates with custom section pool size (list pool defaults to 16). }
    constructor Create(SectionPoolSize_: Integer); overload;
    { * Creates with custom section and list pool sizes. }
    constructor Create(SectionPoolSize_, ListPoolSize_: Integer); overload;
    destructor Destroy; override;

    { * True if the data has been modified since the last rebuild or save. }
    property IsChanged: Boolean read FIsChanged write FIsChanged;

    { * Rebuilds all raw string lists from the hash caches (synchronises views). }
    procedure Rebuild;
    { * Clears all sections, keys, and comments. }
    procedure Clear;
    { * Deletes an entire section. }
    procedure Delete(Section_: SystemString);
    { * Deletes a specific key from a section. }
    procedure DeleteKey(Section_, Key_: SystemString);

    { * Checks if a section exists. }
    function Exists(Section_: SystemString): Boolean;
    { * Checks if a key exists within a section. }
    function ExistsKey(Section_, Key_: SystemString): Boolean;

    { * Gets a Variant value with a default if the key is missing. }
    function GetDefaultValue(const SectionName, KeyName: SystemString; const DefaultValue: Variant): Variant;
    { * Sets a Variant value (same as Hit[Section, Key] := Value). }
    procedure SetDefaultValue(const SectionName, KeyName: SystemString; const Value: Variant);

    { * Gets a string value with a default. }
    function GetDefaultText(const SectionName, KeyName: SystemString; const DefaultValue: SystemString): SystemString;
    { * Sets a string value (same as HitString[Section, Key] := Value). }
    procedure SetDefaultText(const SectionName, KeyName: SystemString; const Value: SystemString);

    { * Gets a 32‑bit integer with default. }
    function GetDefaultText_I32(const SectionName, KeyName: SystemString; const DefaultValue: Integer): Integer;
    { * Sets a 32‑bit integer. }
    procedure SetDefaultText_I32(const SectionName, KeyName: SystemString; const Value: Integer);

    { * Gets a 64‑bit integer with default. }
    function GetDefaultText_I64(const SectionName, KeyName: SystemString; const DefaultValue: Int64): Int64;
    { * Sets a 64‑bit integer. }
    procedure SetDefaultText_I64(const SectionName, KeyName: SystemString; const Value: Int64);

    { * Gets a 128‑bit integer (Int128) with default. }
    function GetDefaultText_I128(const SectionName, KeyName: SystemString; const DefaultValue: Int128): Int128;
    { * Sets a 128‑bit integer. }
    procedure SetDefaultText_I128(const SectionName, KeyName: SystemString; const Value: Int128);

    { * Gets a floating point value (Double) with default. }
    function GetDefaultText_Float(const SectionName, KeyName: SystemString; const DefaultValue: Double): Double;
    { * Sets a floating point value. }
    procedure SetDefaultText_Float(const SectionName, KeyName: SystemString; const Value: Double);

    { * Gets a Boolean with default. }
    function GetDefaultText_Bool(const SectionName, KeyName: SystemString; const DefaultValue: Boolean): Boolean;
    { * Sets a Boolean. }
    procedure SetDefaultText_Bool(const SectionName, KeyName: SystemString; const Value: Boolean);

    { * Gets a TDateTime with default. }
    function GetDefaultText_DT(const SectionName, KeyName: SystemString; const DefaultValue: TDateTime): TDateTime;
    { * Sets a TDateTime. }
    procedure SetDefaultText_DT(const SectionName, KeyName: SystemString; const Value: TDateTime);

    { * Imports sections from a TCore_Strings list. Returns True if any section was found. }
    function DataImport(TextList_: TCore_Strings): Boolean; overload;
    { * Imports from a TPascalStringList. When importing from TPascalStringList,
      * the engine automatically strips everything after ';' on each line
      * (standard INI comment handling). }
    function DataImport(TextList_: TPascalStringList): Boolean; overload;

    { * Exports all sections and comments to a TCore_Strings list. }
    procedure DataExport(TextList_: TCore_Strings); overload;
    { * Exports to a TPascalStringList. }
    procedure DataExport(TextList_: TPascalStringList); overload;

    { * Efficiently swaps internal data with another engine. }
    procedure SwapInstance(sour: THashTextEngine);
    { * Merges data from another engine into this one (overwrites conflicting keys). }
    procedure Merge(sour: THashTextEngine);
    { * Copies (assigns) data from another engine. }
    procedure Assign(sour: THashTextEngine);
    { * Checks if this engine has the same data as another. }
    function Same(sour: THashTextEngine): Boolean;
    { * Creates a deep copy of this engine. }
    function Clone: THashTextEngine;

    { * Loads data from a stream (text format). }
    procedure LoadFromStream(stream: TCore_Stream);
    { * Saves data to a stream. }
    procedure SaveToStream(stream: TCore_Stream);

    { * Loads data from a file. }
    procedure LoadFromFile(FileName: SystemString);
    { * Saves data to a file. }
    procedure SaveToFile(FileName: SystemString);

    { * Total number of key‑value pairs across all sections. }
    function TotalCount: Integer;
    { * Alias for TotalCount. }
    property Count: Integer read TotalCount;

    { * Maximum length of a section name (across all storage layers). }
    function MaxSectionNameSize: Integer;
    { * Alias for MaxSectionNameSize. }
    property MaxSectionNameLen: Integer read MaxSectionNameSize;

    { * Minimum length of a section name (across all storage layers). }
    function MinSectionNameSize: Integer;
    { * Alias for MinSectionNameSize. }
    property MinSectionNameLen: Integer read MinSectionNameSize;

    { * Returns the entire content as a single text string. }
    function GetAsText: SystemString;
    { * Replaces the entire content from a text string. }
    procedure SetAsText(const Value: SystemString);
    { * Property to get/set the whole configuration as plain text. }
    property AsText: SystemString read GetAsText write SetAsText;

    { * Returns an array of all section names. }
    function GetSectionNameArry: U_StringArray;
    { * Populates a TCore_Strings with all section names. }
    procedure GetSectionList(dest: TCore_Strings); overload;
    { * Populates a TListString. }
    procedure GetSectionList(dest: TListString); overload;
    { * Populates a TPascalStringList. }
    procedure GetSectionList(dest: TPascalStringList); overload;

    { * Gets the section name that owns a given THashVariantList object. }
    function GetSectionObjectName(Obj_: THashVariantList): SystemString; overload;
    { * Gets the section name that owns a given THashStringList object. }
    function GetSectionObjectName(Obj_: THashStringList): SystemString; overload;

    { * If True, accessing a missing key with GetDefaultValue will store the default. }
    property AutoUpdateDefaultValue: Boolean read FAutoUpdateDefaultValue write FAutoUpdateDefaultValue;

    { * The global comment lines (outside any section). }
    property Comment: TCore_Strings read FComment write FComment;

    { * Default indexed property: get/set a Variant value by section and key.
      * Use this for VARIANT MODE. Do NOT mix with HitString on the same key. }
    property Hit[SName, VName: SystemString]: Variant read GetHitVariant write SetHitVariant; default;

    { * Alias for Hit. }
    property HitVariant[SName, VName: SystemString]: Variant read GetHitVariant write SetHitVariant;

    { * Get/set a string value by section and key.
      * Use this for TEXT MODE. Do NOT mix with Hit on the same key. }
    property HitString[SName, VName: SystemString]: SystemString read GetHitString write SetHitString;

    { * Short aliases for HitString. }
    property HitS[SName, VName: SystemString]: SystemString read GetHitString write SetHitString;
    property SHit[SName, VName: SystemString]: SystemString read GetHitString write SetHitString;

    { * Get or set the raw string list for a section (creates if missing). }
    property Names[N_: SystemString]: TCore_Strings read GetNames write SetNames;
    { * Alias for Names. }
    property Strings[N_: SystemString]: TCore_Strings read GetNames write SetNames;

    { * Get or create a THashVariantList for a section (VARIANT MODE). }
    property VariantList[N_: SystemString]: THashVariantList read GetHVariantList;
    property HVariantList[N_: SystemString]: THashVariantList read GetHVariantList;

    { * Get or create a THashStringList for a section (TEXT MODE). }
    property StringList[N_: SystemString]: THashStringList read GetHStringList;
    property HStringList[N_: SystemString]: THashStringList read GetHStringList;
  end;

  { * Alias for THashTextEngine. }
  TTextDataEngine = THashTextEngine;
  { * Alias for THashTextEngine. }
  TSectionTextData = THashTextEngine;

  { * A generic list of THashTextEngine objects. }
  THashTextEngineList = TGenericsList<THashTextEngine>;

implementation

{ * Gets the raw string list for a section, creating it if missing. }
function THashTextEngine.GetNames(N_: SystemString): TCore_Strings;
var
  h: THashVariantTextStream;
begin
  { If the section does not exist in the raw list, create an empty one. }
  if not FSectionList.Exists(N_) then
      FSectionList[N_] := TCore_StringList.Create;

  { If a variant hash list exists for this section, convert it back to raw strings
    and replace the raw list, then mark as changed. }
  if FSectionHashVariantList.Exists(N_) then
    begin
      Result := TCore_StringList.Create;
      h := THashVariantTextStream.Create(THashVariantList(FSectionHashVariantList[N_]));
      h.DataExport(Result);
      DisposeObject(h);

      FSectionList[N_] := Result;
      FIsChanged := True;
    end;

  { Return the raw list (newly created or existing). }
  Result := TCore_Strings(FSectionList[N_]);
end;

{ * Replaces the raw string list for a section. }
procedure THashTextEngine.SetNames(N_: SystemString; const Value: TCore_Strings);
var
  ns: TCore_Strings;
begin
  { Create a copy of the provided list. }
  ns := TCore_StringList.Create;
  ns.Assign(Value);
  { Store it in the raw list. }
  FSectionList[N_] := ns;
  { Remove any cached hash variant list for this section to force rebuild. }
  FSectionHashVariantList.Delete(N_);
  FIsChanged := True;
end;

{ * Gets a Variant value from a section/key, creating the hash cache if needed.
  * This is the core implementation for VARIANT MODE (Hit[] property).
  * It lazily creates a Variant hash cache for the section if one does not exist. }
function THashTextEngine.GetHitVariant(SName, VName: SystemString): Variant;
var
  nsl: TCore_Strings;
  vl: THashVariantList;
  vt: THashVariantTextStream;
begin
  Result := Null;
  { Try to get existing variant hash list. }
  vl := THashVariantList(FSectionHashVariantList[SName]);
  if vl = nil then
    begin
      { No cache: get the raw strings for this section. }
      nsl := Names[SName];
      if nsl = nil then
          Exit;
      if nsl.Count = 0 then
          Exit;
      { Create a new variant hash list and populate it from the raw strings. }
      vl := THashVariantList.CustomCreate(FListPoolSize);
      vl.AutoUpdateDefaultValue := AutoUpdateDefaultValue;

      vt := THashVariantTextStream.Create(vl);
      vt.DataImport(nsl);
      DisposeObject(vt);

      { Cache it. }
      FSectionHashVariantList[SName] := vl;
      FIsChanged := True;
    end;
  { Return the value from the cache. }
  Result := vl[VName];
end;

{ * Sets a Variant value in a section/key.
  * This is the core implementation for VARIANT MODE (Hit[] property). }
procedure THashTextEngine.SetHitVariant(SName, VName: SystemString; const Value: Variant);
var
  nsl: TCore_Strings;
  vl: THashVariantList;
  vt: THashVariantTextStream;
begin
  { Try to get existing variant hash list. }
  vl := THashVariantList(FSectionHashVariantList[SName]);
  if vl = nil then
    begin
      { No cache: create a new one. }
      vl := THashVariantList.CustomCreate(FListPoolSize);
      vl.AutoUpdateDefaultValue := AutoUpdateDefaultValue;

      { If raw strings exist, import them to initialise the hash. }
      nsl := Names[SName];
      if nsl <> nil then
        begin
          vt := THashVariantTextStream.Create(vl);
          vt.DataImport(nsl);
          DisposeObject(vt);
        end;
      FSectionHashVariantList[SName] := vl;
    end;
  { Set the value in the hash. }
  vl[VName] := Value;
  FIsChanged := True;
end;

{ * Gets a string value from a section/key, creating the hash cache if needed.
  * This is the core implementation for TEXT MODE (HitString[] property).
  * It lazily creates a String hash cache for the section if one does not exist. }
function THashTextEngine.GetHitString(SName, VName: SystemString): SystemString;
var
  nsl: TCore_Strings;
  sl: THashStringList;
  st: THashStringTextStream;
begin
  Result := '';
  { Try to get existing string hash list. }
  sl := THashStringList(FSectionHashStringList[SName]);
  if sl = nil then
    begin
      { No cache: get the raw strings for this section. }
      nsl := Names[SName];
      if nsl = nil then
          Exit;
      if nsl.Count = 0 then
          Exit;
      { Create a new string hash list and populate it from raw strings. }
      sl := THashStringList.CustomCreate(FListPoolSize);
      sl.AutoUpdateDefaultValue := AutoUpdateDefaultValue;

      st := THashStringTextStream.Create(sl);
      st.DataImport(nsl);
      DisposeObject(st);

      { Cache it. }
      FSectionHashStringList[SName] := sl;
      FIsChanged := True;
    end;
  { Return the value from the cache. }
  Result := sl[VName];
end;

{ * Sets a string value in a section/key.
  * This is the core implementation for TEXT MODE (HitString[] property). }
procedure THashTextEngine.SetHitString(SName, VName: SystemString; const Value: SystemString);
var
  nsl: TCore_Strings;
  sl: THashStringList;
  st: THashStringTextStream;
begin
  { Try to get existing string hash list. }
  sl := THashStringList(FSectionHashStringList[SName]);
  if sl = nil then
    begin
      { No cache: create a new one. }
      sl := THashStringList.CustomCreate(FListPoolSize);
      sl.AutoUpdateDefaultValue := AutoUpdateDefaultValue;

      { If raw strings exist, import them to initialise the hash. }
      nsl := Names[SName];
      if nsl <> nil then
        begin
          st := THashStringTextStream.Create(sl);
          st.DataImport(nsl);
          DisposeObject(st);
        end;
      FSectionHashStringList[SName] := sl;
    end;
  { Set the value in the hash. }
  sl[VName] := Value;
  FIsChanged := True;
end;

{ * Returns the Variant hash list for a section, creating it if missing.
  * Use this to access the raw Variant hash list directly (VARIANT MODE). }
function THashTextEngine.GetHVariantList(N_: SystemString): THashVariantList;
var
  nsl: TCore_Strings;
  vt: THashVariantTextStream;
begin
  Result := THashVariantList(FSectionHashVariantList[N_]);
  if Result = nil then
    begin
      { Create a new variant hash list. }
      Result := THashVariantList.CustomCreate(FListPoolSize);
      Result.AutoUpdateDefaultValue := FAutoUpdateDefaultValue;
      { Import existing raw strings if present. }
      nsl := Names[N_];
      if nsl <> nil then
        begin
          vt := THashVariantTextStream.Create(Result);
          vt.DataImport(nsl);
          DisposeObject(vt);
        end;

      FSectionHashVariantList[N_] := Result;
      FIsChanged := True;
    end;
end;

{ * Returns the String hash list for a section, creating it if missing.
  * Use this to access the raw String hash list directly (TEXT MODE). }
function THashTextEngine.GetHStringList(N_: SystemString): THashStringList;
var
  nsl: TCore_Strings;
  st: THashStringTextStream;
begin
  Result := THashStringList(FSectionHashStringList[N_]);
  if Result = nil then
    begin
      { Create a new string hash list. }
      Result := THashStringList.CustomCreate(FListPoolSize);
      Result.AutoUpdateDefaultValue := FAutoUpdateDefaultValue;
      { Import existing raw strings if present. }
      nsl := Names[N_];
      if nsl <> nil then
        begin
          st := THashStringTextStream.Create(Result);
          st.DataImport(nsl);
          DisposeObject(st);
        end;

      FSectionHashStringList[N_] := Result;
      FIsChanged := True;
    end;
end;

{ * Internal helper: adds a section with a raw string list (used during import). }
procedure THashTextEngine.AddDataSection(Section_: SystemString; TextList_: TCore_Strings);
begin
  { Remove leading/trailing empty lines to clean up. }
  while (TextList_.Count > 0) and (TextList_[0] = '') do
      TextList_.Delete(0);
  while (TextList_.Count > 0) and (TextList_[TextList_.Count - 1] = '') do
      TextList_.Delete(TextList_.Count - 1);

  FSectionList.Add(Section_, TextList_);
end;

{ * Creates a new engine with default pool sizes (16). }
constructor THashTextEngine.Create;
begin
  Create(16, 16);
end;

{ * Creates with custom section pool size (list pool defaults to 16). }
constructor THashTextEngine.Create(SectionPoolSize_: Integer);
begin
  Create(SectionPoolSize_, 16);
end;

{ * Creates with custom section and list pool sizes. }
constructor THashTextEngine.Create(SectionPoolSize_, ListPoolSize_: Integer);
begin
  inherited Create;
  FSectionPoolSize := SectionPoolSize_;
  FListPoolSize := ListPoolSize_;

  FComment := TCore_StringList.Create;
  FSectionList := THashObjectList.CustomCreate(True, FSectionPoolSize);
  FSectionHashVariantList := THashObjectList.CustomCreate(True, FSectionPoolSize);
  FSectionHashStringList := THashObjectList.CustomCreate(True, FSectionPoolSize);
  FAutoUpdateDefaultValue := False;

  FIsChanged := False;
end;

{ * Destructor: frees all owned objects. }
destructor THashTextEngine.Destroy;
begin
  Clear;
  DisposeObject(FSectionList);
  DisposeObject(FSectionHashVariantList);
  DisposeObject(FSectionHashStringList);
  DisposeObject(FComment);
  inherited Destroy;
end;

{ * Rebuilds all raw string lists from the hash caches (synchronises views). }
procedure THashTextEngine.Rebuild;
var
  i: Integer;
  tmpSecLst: TPascalStringList;
  nsl: TCore_Strings;
  hv: THashVariantTextStream;
  hs: THashStringTextStream;
begin
  tmpSecLst := TPascalStringList.Create;

  { Convert all variant hash lists to raw strings and replace the raw list. }
  if FSectionHashVariantList.Count > 0 then
    begin
      FSectionHashVariantList.GetListData(tmpSecLst);
      for i := 0 to tmpSecLst.Count - 1 do
        begin
          nsl := TCore_StringList.Create;
          hv := THashVariantTextStream.Create(THashVariantList(tmpSecLst.Objects[i]));
          hv.DataExport(nsl);
          DisposeObject(hv);
          FSectionList[tmpSecLst[i]] := nsl;
        end;
      FSectionHashVariantList.Clear;
    end;

  { Convert all string hash lists to raw strings and replace the raw list. }
  if FSectionHashStringList.Count > 0 then
    begin
      FSectionHashStringList.GetListData(tmpSecLst);
      for i := 0 to tmpSecLst.Count - 1 do
        begin
          nsl := TCore_StringList.Create;
          hs := THashStringTextStream.Create(THashStringList(tmpSecLst.Objects[i]));
          hs.DataExport(nsl);
          DisposeObject(hs);
          FSectionList[tmpSecLst[i]] := nsl;
        end;
      FSectionHashStringList.Clear;
    end;

  DisposeObject(tmpSecLst);
  FIsChanged := True;
end;

{ * Clears all sections, keys, and comments. }
procedure THashTextEngine.Clear;
begin
  FSectionList.Clear;
  FSectionHashVariantList.Clear;
  FSectionHashStringList.Clear;
  FComment.Clear;
  FIsChanged := True;
end;

{ * Deletes an entire section (across all storage layers). }
procedure THashTextEngine.Delete(Section_: SystemString);
begin
  FSectionList.Delete(Section_);
  FSectionHashVariantList.Delete(Section_);
  FSectionHashStringList.Delete(Section_);
  FIsChanged := True;
end;

{ * Deletes a specific key from a section. }
procedure THashTextEngine.DeleteKey(Section_, Key_: SystemString);
var
  found_: Boolean;
begin
  found_ := False;
  { Try to delete from variant hash cache. }
  if FSectionHashVariantList.Exists(Section_) then
    begin
      found_ := THashVariantList(FSectionHashVariantList[Section_]).Exists(Key_);
      THashVariantList(FSectionHashVariantList[Section_]).Delete(Key_);
    end;
  { Try to delete from string hash cache. }
  if FSectionHashStringList.Exists(Section_) then
    begin
      found_ := THashStringList(FSectionHashStringList[Section_]).Exists(Key_);
      THashStringList(FSectionHashStringList[Section_]).Delete(Key_);
    end;
  { If not found in any cache, rebuild raw list and delete from string hash. }
  if not found_ then
    begin
      Rebuild;
      HStringList[Section_].Delete(Key_);
      Rebuild;
    end;

  FIsChanged := True;
end;

{ * Checks if a section exists (in any storage layer). }
function THashTextEngine.Exists(Section_: SystemString): Boolean;
begin
  Result := FSectionList.Exists(Section_) or FSectionHashVariantList.Exists(Section_) or FSectionHashStringList.Exists(Section_);
end;

{ * Checks if a key exists within a section. }
function THashTextEngine.ExistsKey(Section_, Key_: SystemString): Boolean;
begin
  Result := False;
  if FSectionHashVariantList.Exists(Section_) then
      Result := THashVariantList(FSectionHashVariantList[Section_]).Exists(Key_);
  if FSectionHashStringList.Exists(Section_) then
      Result := THashStringList(FSectionHashStringList[Section_]).Exists(Key_)
  else if FSectionList.Exists(Section_) then
    begin
      { If only raw list exists, create string hash to check. }
      Result := GetHStringList(Section_).Exists(Key_);
      FSectionHashStringList.Delete(Section_); { Delete temporary cache to avoid clutter. }
    end;
end;

{ * Gets a Variant value with a default if the key is missing. }
function THashTextEngine.GetDefaultValue(const SectionName, KeyName: SystemString; const DefaultValue: Variant): Variant;
begin
  Result := VariantList[SectionName].GetDefaultValue(KeyName, DefaultValue);
end;

{ * Sets a Variant value (same as Hit[Section, Key] := Value). }
procedure THashTextEngine.SetDefaultValue(const SectionName, KeyName: SystemString; const Value: Variant);
begin
  Hit[SectionName, KeyName] := Value;
end;

{ * Gets a string value with a default. }
function THashTextEngine.GetDefaultText(const SectionName, KeyName: SystemString; const DefaultValue: SystemString): SystemString;
begin
  Result := HStringList[SectionName].GetDefaultValue(KeyName, DefaultValue);
end;

{ * Sets a string value (same as HitString[Section, Key] := Value). }
procedure THashTextEngine.SetDefaultText(const SectionName, KeyName: SystemString; const Value: SystemString);
begin
  HitString[SectionName, KeyName] := Value;
end;

{ * Gets a 32‑bit integer with default. }
function THashTextEngine.GetDefaultText_I32(const SectionName, KeyName: SystemString; const DefaultValue: Integer): Integer;
begin
  Result := umlStrToInt(HStringList[SectionName].GetDefaultValue(KeyName, umlIntToStr(DefaultValue)), DefaultValue);
end;

{ * Sets a 32‑bit integer. }
procedure THashTextEngine.SetDefaultText_I32(const SectionName, KeyName: SystemString; const Value: Integer);
begin
  HitString[SectionName, KeyName] := umlIntToStr(Value);
end;

{ * Gets a 64‑bit integer with default. }
function THashTextEngine.GetDefaultText_I64(const SectionName, KeyName: SystemString; const DefaultValue: Int64): Int64;
begin
  Result := umlStrToInt64(HStringList[SectionName].GetDefaultValue(KeyName, umlIntToStr(DefaultValue)), DefaultValue);
end;

{ * Sets a 64‑bit integer. }
procedure THashTextEngine.SetDefaultText_I64(const SectionName, KeyName: SystemString; const Value: Int64);
begin
  HitString[SectionName, KeyName] := umlIntToStr(Value);
end;

{ * Gets a 128‑bit integer (Int128) with default. }
function THashTextEngine.GetDefaultText_I128(const SectionName, KeyName: SystemString; const DefaultValue: Int128): Int128;
begin
  Result := umlStrToInt128(HStringList[SectionName].GetDefaultValue(KeyName, umlIntToStr(DefaultValue)), DefaultValue);
end;

{ * Sets a 128‑bit integer. }
procedure THashTextEngine.SetDefaultText_I128(const SectionName, KeyName: SystemString; const Value: Int128);
begin
  HitString[SectionName, KeyName] := umlIntToStr(Value);
end;

{ * Gets a floating point value (Double) with default. }
function THashTextEngine.GetDefaultText_Float(const SectionName, KeyName: SystemString; const DefaultValue: Double): Double;
begin
  Result := umlStrToFloat(HStringList[SectionName].GetDefaultValue(KeyName, umlFloatToStr(DefaultValue)), DefaultValue);
end;

{ * Sets a floating point value. }
procedure THashTextEngine.SetDefaultText_Float(const SectionName, KeyName: SystemString; const Value: Double);
begin
  HitString[SectionName, KeyName] := umlFloatToStr(Value);
end;

{ * Gets a Boolean with default. }
function THashTextEngine.GetDefaultText_Bool(const SectionName, KeyName: SystemString; const DefaultValue: Boolean): Boolean;
begin
  Result := umlStrToBool(HStringList[SectionName].GetDefaultValue(KeyName, umlBoolToStr(DefaultValue)), DefaultValue);
end;

{ * Sets a Boolean. }
procedure THashTextEngine.SetDefaultText_Bool(const SectionName, KeyName: SystemString; const Value: Boolean);
begin
  HitString[SectionName, KeyName] := umlBoolToStr(Value);
end;

{ * Gets a TDateTime with default. }
function THashTextEngine.GetDefaultText_DT(const SectionName, KeyName: SystemString; const DefaultValue: TDateTime): TDateTime;
begin
  Result := umlDT(HStringList[SectionName].GetDefaultValue(KeyName, umlDT(DefaultValue)), DefaultValue);
end;

{ * Sets a TDateTime. }
procedure THashTextEngine.SetDefaultText_DT(const SectionName, KeyName: SystemString; const Value: TDateTime);
begin
  HitString[SectionName, KeyName] := umlDT(Value);
end;

{ * Imports sections from a TCore_Strings list. Returns True if any section was found. }
function THashTextEngine.DataImport(TextList_: TCore_Strings): Boolean;
var
  i: Integer;
  ln: U_String;
  nsect: SystemString;
  ntLst: TCore_Strings;
begin
  { First rebuild to ensure raw lists are up‑to‑date. }
  Rebuild;

  ntLst := nil;
  nsect := '';
  Result := False;
  if Assigned(TextList_) then
    begin
      if TextList_.Count > 0 then
        begin
          i := 0;
          while i < TextList_.Count do
            begin
              ln := umlTrimChar(TextList_[i], ' ');
              { Detect section header: [SectionName] }
              if (ln.Len > 0) and (ln.First = '[') and (ln.Last = ']') then
                begin
                  { Save previous section if any. }
                  if Result then
                      AddDataSection(nsect, ntLst);
                  ntLst := TCore_StringList.Create;
                  nsect := umlGetFirstStr(ln, '[]').Text;
                  Result := True;
                end
              else if Result then
                begin
                  { Inside a section: add line to current section. }
                  ntLst.Append(ln);
                end
              else
                begin
                  { Outside any section: treat as global comment (unless it starts with ';' which we skip). }
                  if (ln.Len > 0) and (not CharIn(ln.First, [';'])) then
                      FComment.Append(ln);
                end;
              inc(i);
            end;
          { Add the last section. }
          if Result then
              AddDataSection(nsect, ntLst);
        end;

      { Trim empty lines from comments. }
      while (FComment.Count > 0) and (FComment[0] = '') do
          FComment.Delete(0);
      while (FComment.Count > 0) and (FComment[FComment.Count - 1] = '') do
          FComment.Delete(FComment.Count - 1);
    end;
end;

{ * Imports from a TPascalStringList.
  * When importing from TPascalStringList, the engine automatically removes
  * everything after a semicolon (';') on each line. This is the standard
  * INI comment behaviour where ';' marks the start of a comment.
  *
  * Example:
  *   Input:   "Port=8080  ; Listen port"
  *   Stored:  "Port=8080"
  *
  * The ';' and everything after it are discarded and NOT stored. }
function THashTextEngine.DataImport(TextList_: TPascalStringList): Boolean;
var
  i: Integer;
  ln: U_String;
  nsect: SystemString;
  ntLst: TCore_Strings;
begin
  Rebuild;

  ntLst := nil;
  nsect := '';
  Result := False;
  if Assigned(TextList_) then
    begin
      if TextList_.Count > 0 then
        begin
          i := 0;
          while i < TextList_.Count do
            begin
              ln := TextList_[i].TrimChar(#32);
              if (ln.Len > 0) and (ln.First = '[') and (ln.Last = ']') then
                begin
                  if Result then
                      AddDataSection(nsect, ntLst);
                  ntLst := TCore_StringList.Create;
                  nsect := umlGetFirstStr(ln, '[]').Text;
                  Result := True;
                end
              else if Result then
                begin
                  ntLst.Append(ln);
                end
              else
                begin
                  if (ln.Len > 0) and (not CharIn(ln.First, [';'])) then
                      FComment.Append(ln);
                end;
              inc(i);
            end;
          if Result then
              AddDataSection(nsect, ntLst);
        end;

      while (FComment.Count > 0) and (FComment[0] = '') do
          FComment.Delete(0);
      while (FComment.Count > 0) and (FComment[FComment.Count - 1] = '') do
          FComment.Delete(FComment.Count - 1);
    end;
  FIsChanged := False;
end;

{ * Exports all sections and comments to a TCore_Strings list. }
procedure THashTextEngine.DataExport(TextList_: TCore_Strings);
var
  i: Integer;
  tmpSecLst: TPascalStringList;
  nsl: TCore_Strings;
begin
  { Rebuild to ensure raw lists contain latest data. }
  Rebuild;

  { Add global comments first. }
  TextList_.AddStrings(FComment);
  if FComment.Count > 0 then
      TextList_.Append('');

  tmpSecLst := TPascalStringList.Create;

  { Iterate over all sections in the raw list. }
  FSectionList.GetListData(tmpSecLst);
  if tmpSecLst.Count > 0 then
    for i := 0 to tmpSecLst.Count - 1 do
      if (tmpSecLst.Objects[i] is TCore_Strings) then
        begin
          nsl := TCore_Strings(tmpSecLst.Objects[i]);
          if nsl <> nil then
            begin
              TextList_.Append('[' + tmpSecLst[i] + ']');
              TextList_.AddStrings(nsl);
              TextList_.Append('');
            end;
        end;

  DisposeObject(tmpSecLst);
end;

{ * Exports to a TPascalStringList. }
procedure THashTextEngine.DataExport(TextList_: TPascalStringList);
var
  i: Integer;
  tmpSecLst: TPascalStringList;
  nsl: TCore_Strings;
begin
  Rebuild;

  TextList_.AddStrings(FComment);
  if FComment.Count > 0 then
      TextList_.Append('');

  tmpSecLst := TPascalStringList.Create;

  FSectionList.GetListData(tmpSecLst);
  if tmpSecLst.Count > 0 then
    for i := 0 to tmpSecLst.Count - 1 do
      if (tmpSecLst.Objects[i] is TCore_Strings) then
        begin
          nsl := TCore_Strings(tmpSecLst.Objects[i]);
          if nsl <> nil then
            begin
              TextList_.Append('[' + tmpSecLst[i].Text + ']');
              TextList_.AddStrings(nsl);
              TextList_.Append('');
            end;
        end;

  DisposeObject(tmpSecLst);
end;

{ * Efficiently swaps internal data with another engine. }
procedure THashTextEngine.SwapInstance(sour: THashTextEngine);
var
  bak_FComment: TCore_Strings;
  bak_FSectionList, bak_FSectionHashVariantList, bak_FSectionHashStringList: THashObjectList;
  bak_FAutoUpdateDefaultValue: Boolean;
  bak_FSectionPoolSize, bak_FListPoolSize: Integer;
begin
  { Save current state. }
  bak_FComment := FComment;
  bak_FSectionList := FSectionList;
  bak_FSectionHashVariantList := FSectionHashVariantList;
  bak_FSectionHashStringList := FSectionHashStringList;
  bak_FAutoUpdateDefaultValue := FAutoUpdateDefaultValue;
  bak_FSectionPoolSize := FSectionPoolSize;
  bak_FListPoolSize := FListPoolSize;

  { Replace with source's data. }
  FComment := sour.FComment;
  FSectionList := sour.FSectionList;
  FSectionHashVariantList := sour.FSectionHashVariantList;
  FSectionHashStringList := sour.FSectionHashStringList;
  FAutoUpdateDefaultValue := sour.FAutoUpdateDefaultValue;
  FSectionPoolSize := sour.FSectionPoolSize;
  FListPoolSize := sour.FListPoolSize;

  { Put old data back into source. }
  sour.FComment := bak_FComment;
  sour.FSectionList := bak_FSectionList;
  sour.FSectionHashVariantList := bak_FSectionHashVariantList;
  sour.FSectionHashStringList := bak_FSectionHashStringList;
  sour.FAutoUpdateDefaultValue := bak_FAutoUpdateDefaultValue;
  sour.FSectionPoolSize := bak_FSectionPoolSize;
  sour.FListPoolSize := bak_FListPoolSize;

  IsChanged := True;
  sour.IsChanged := True;
end;

{ * Merges data from another engine into this one (overwrites conflicting keys). }
procedure THashTextEngine.Merge(sour: THashTextEngine);
var
  ns: TCore_StringList;
begin
  try
    Rebuild;
    ns := TCore_StringList.Create;
    sour.Rebuild;
    sour.DataExport(ns);
    DataImport(ns);
    DisposeObject(ns);
    Rebuild;
    FIsChanged := True;
  except
  end;
end;

{ * Copies (assigns) data from another engine. }
procedure THashTextEngine.Assign(sour: THashTextEngine);
var
  L: TPascalStringList;
begin
  try
    L := TPascalStringList.Create;
    sour.Rebuild;
    sour.DataExport(L);
    Clear;
    DataImport(L);
    DisposeObject(L);
    Rebuild;
    FIsChanged := True;
  except
  end;
end;

{ * Checks if this engine has the same data as another. }
function THashTextEngine.Same(sour: THashTextEngine): Boolean;
var
  i: Integer;
  ns: TCore_StringList;
  N_: SystemString;
begin
  Result := False;
  Rebuild;
  sour.Rebuild;

  { Quick check: same number of sections. }
  if FSectionList.Count <> sour.FSectionList.Count then
      Exit;

  { Get list of section names. }
  ns := TCore_StringList.Create;
  FSectionList.GetListData(ns);

  { Check that every section exists in source. }
  for i := 0 to ns.Count - 1 do
    begin
      N_ := ns[i];
      if not sour.Exists(N_) then
        begin
          DisposeObject(ns);
          Exit;
        end;
    end;

  { Compare each section's raw text content. }
  for i := 0 to ns.Count - 1 do
    begin
      N_ := ns[i];
      if not SameText(Strings[N_].Text, sour.Strings[N_].Text) then
        begin
          DisposeObject(ns);
          Exit;
        end;
    end;

  DisposeObject(ns);
  Result := True;
end;

{ * Creates a deep copy of this engine. }
function THashTextEngine.Clone: THashTextEngine;
begin
  Result := THashTextEngine.Create;
  Result.Assign(Self);
end;

{ * Loads data from a stream (text format). }
procedure THashTextEngine.LoadFromStream(stream: TCore_Stream);
var
  N_: TPascalStringList;
begin
  Clear;
  N_ := TPascalStringList.Create;
  N_.LoadFromStream(stream);
  DataImport(N_);
  DisposeObject(N_);
end;

{ * Saves data to a stream. }
procedure THashTextEngine.SaveToStream(stream: TCore_Stream);
var
  N_: TPascalStringList;
begin
  N_ := TPascalStringList.Create;
  DataExport(N_);
  N_.SaveToStream(stream);
  DisposeObject(N_);
end;

{ * Loads data from a file. }
procedure THashTextEngine.LoadFromFile(FileName: SystemString);
var
  m64: TMS64;
begin
  m64 := TMS64.Create;
  try
      m64.LoadFromFile(FileName);
  except
    DisposeObject(m64);
    Exit;
  end;

  try
      LoadFromStream(m64);
  finally
      DisposeObject(m64);
  end;
end;

{ * Saves data to a file. }
procedure THashTextEngine.SaveToFile(FileName: SystemString);
var
  m64: TMS64;
begin
  m64 := TMS64.Create;
  try
    SaveToStream(m64);
    m64.SaveToFile(FileName);
  finally
      DisposeObject(m64);
  end;
end;

{ * Total number of key‑value pairs across all sections. }
function THashTextEngine.TotalCount: Integer;
var
  i: Integer;
  tmpSecLst: TPascalStringList;
begin
  Result := 0;
  tmpSecLst := TPascalStringList.Create;

  { Count items in raw lists that are not shadowed by caches. }
  FSectionList.GetListData(tmpSecLst);
  if tmpSecLst.Count > 0 then
    for i := 0 to tmpSecLst.Count - 1 do
      if (not FSectionHashVariantList.Exists(tmpSecLst[i])) and (not FSectionHashStringList.Exists(tmpSecLst[i])) then
          inc(Result, TCore_Strings(tmpSecLst.Objects[i]).Count);

  { Count items in variant cache. }
  FSectionHashVariantList.GetListData(tmpSecLst);
  if tmpSecLst.Count > 0 then
    for i := 0 to tmpSecLst.Count - 1 do
        inc(Result, THashVariantList(tmpSecLst.Objects[i]).Count);

  { Count items in string cache. }
  FSectionHashStringList.GetListData(tmpSecLst);
  if tmpSecLst.Count > 0 then
    for i := 0 to tmpSecLst.Count - 1 do
        inc(Result, THashStringList(tmpSecLst.Objects[i]).Count);

  DisposeObject(tmpSecLst);
end;

{ * Maximum length of a section name (across all storage layers). }
function THashTextEngine.MaxSectionNameSize: Integer;
begin
  Result := umlMax(FSectionList.HashList.MaxNameSize,
    umlMax(FSectionHashVariantList.HashList.MaxNameSize, FSectionHashStringList.HashList.MaxNameSize));
end;

{ * Minimum length of a section name (across all storage layers). }
function THashTextEngine.MinSectionNameSize: Integer;
begin
  Result := umlMin(FSectionList.HashList.MinNameSize,
    umlMin(FSectionHashVariantList.HashList.MinNameSize, FSectionHashStringList.HashList.MinNameSize));
end;

{ * Returns the entire content as a single text string. }
function THashTextEngine.GetAsText: SystemString;
var
  ns: TPascalStringList;
begin
  ns := TPascalStringList.Create;
  DataExport(ns);
  Result := ns.AsText;
  DisposeObject(ns);
end;

{ * Replaces the entire content from a text string. }
procedure THashTextEngine.SetAsText(const Value: SystemString);
var
  ns: TPascalStringList;
begin
  Clear;
  ns := TPascalStringList.Create;
  ns.AsText := Value;
  DataImport(ns);
  DisposeObject(ns);
  FIsChanged := True;
end;

{ * Returns an array of all section names. }
function THashTextEngine.GetSectionNameArry: U_StringArray;
var
  L: TPascalStringList;
  i: Integer;
begin
  L := TPascalStringList.Create;
  GetSectionList(L);
  SetLength(Result, L.Count);
  for i := 0 to L.Count - 1 do
      Result[i] := L[i];
  DisposeObject(L);
end;

{ * Populates a TCore_Strings with all section names. }
procedure THashTextEngine.GetSectionList(dest: TCore_Strings);
begin
  Rebuild;
  FSectionList.GetListData(dest);
end;

{ * Populates a TListString. }
procedure THashTextEngine.GetSectionList(dest: TListString);
begin
  Rebuild;
  FSectionList.GetListData(dest);
end;

{ * Populates a TPascalStringList. }
procedure THashTextEngine.GetSectionList(dest: TPascalStringList);
begin
  Rebuild;
  FSectionList.GetListData(dest);
end;

{ * Gets the section name that owns a given THashVariantList object. }
function THashTextEngine.GetSectionObjectName(Obj_: THashVariantList): SystemString;
begin
  Result := FSectionHashVariantList.GetObjAsName(Obj_);
end;

{ * Gets the section name that owns a given THashStringList object. }
function THashTextEngine.GetSectionObjectName(Obj_: THashStringList): SystemString;
begin
  Result := FSectionHashStringList.GetObjAsName(Obj_);
end;

end.

{ ****************************************************************************** }
{ * Instance State and Analysis Tool                                           * }
{ * Provides runtime instance tracking and analysis for debugging and          * }
{ * monitoring object/class instance lifecycles in large programs.             * }
{ ****************************************************************************** }
unit Z.Instance.Tool;

{$DEFINE FPC_DELPHI_MODE}
{$I Z.Define.inc}

interface

uses
  SysUtils,
{$IFDEF FPC}
  Z.FPC.GenericList,
{$ENDIF FPC}
  Z.Core, Z.PascalStrings;

type
  {
    Core_Instance_Count_Tool is used to count active instances, which can
    affect performance after startup. This tool helps debug and analyze the
    state of large programs by tracking instance creation and destruction
    patterns.

    @note Requires the "Intermediate_Instance_Tool" compiler define to be
          enabled in Z.Define.inc for full functionality.

    The tool hooks into the Z.Core instance counting system (Inc_Instance_Num
    and Dec_Instance_Num) and maintains a database of instance counts keyed
    by class name or unit name. This enables:
      - Detection of memory leaks (instances not properly freed)
      - Analysis of instance lifetime patterns
      - Identification of frequently created/destroyed objects
      - Performance profiling of object allocation patterns

    @warning Enabling this tool may have a minor performance impact due to
             the overhead of tracking every instance creation/destruction.
  }

  {
    TInstance_State_ records the current state of instance tracking for
    a specific key (typically a class name or unit name).

    @field Update_Time   The timestamp of the last update to this record
    @field Update_Num    The total number of updates performed on this record
    @field Instance_Num  The current number of live instances for this key
  }
  TInstance_State_ = record
    Update_Time: TTimeTick;   { Last update timestamp in milliseconds }
    Update_Num, Instance_Num: Int64; { Update counter and current instance count }
  end;

  {
    TInstance_State_Tool__ is the underlying hash map type that stores
    state information keyed by string identifiers.
  }
  TInstance_State_Tool__ = class(TBig_Hash_Pair_Pool<SystemString, TInstance_State_>)
  end;

  {
    TInstance_State_Tool is the main class for tracking and analyzing
    instance states across the application.

    It extends the hash pair pool with specialized methods for:
      - Incrementing/decrementing instance counts
      - Sorting results by various criteria (time, count, updates)
      - Cloning state for snapshot comparisons
      - Comparing two states to detect changes

    This class is thread-safe for read operations but should be used
    with caution during write operations.
  }
  TInstance_State_Tool = class(TInstance_State_Tool__)
  private
    IsLock_: Boolean;  { Internal flag to prevent recursive hook calls }
  public
    {
      Creates a new instance state tool with the specified hash table size.
      Larger hash sizes reduce collision probability but use more memory.

      @param HashSize_ The number of buckets in the hash table. A prime
                       number near the expected number of keys is recommended.
    }
    constructor Create(const HashSize_: integer);

    { Overrides the hash key generation for string keys }
    function Get_Key_Hash(const Key_: SystemString): THash; override;

    { Overrides key comparison to use case-insensitive matching }
    function Compare_Key(const Key_1, Key_2: SystemString): Boolean; override;

    { Frees the key and value when an entry is removed }
    procedure DoFree(var Key: SystemString; var Value: TInstance_State_); override;

    {
      Increments or decrements the instance count for a specific key.

      @param Key_   The identifier (typically class name or unit name)
      @param Value_ The amount to add (positive for creation, negative for destruction)
    }
    procedure IncValue(Key_: SystemString; Value_: Int64);

    { Sorting comparators }
    function Do_Sort_By_Time(var L, R: TInstance_State_): integer;
    procedure Sort_By_Time();

    function Do_Sort_By_Instance(var L, R: TInstance_State_): integer;
    procedure Sort_By_Instance();

    function Do_Sort_By_Update(var L, R: TInstance_State_): integer;
    procedure Sort_By_Update();

    {
      Creates a deep copy of the current state tool.

      @return A new TInstance_State_Tool instance with the same data.
    }
    function Clone: TInstance_State_Tool;

    {
      Compares this state tool with another and returns the differences.
      The resulting tool contains delta values (difference between this
      state and the other).

      @param Tool_ The other state tool to compare against.
      @return A new TInstance_State_Tool containing the differences.
    }
    function Compare_State(Tool_: TInstance_State_Tool): TInstance_State_Tool;
  end;

var
  {
    Global instance state tool that tracks all instance activity in the
    application. This is the primary instance tracking database.

    It is automatically initialized at program startup and can be used
    to query instance counts, detect leaks, and analyze allocation patterns.
  }
  Instance_State_Tool: TInstance_State_Tool;

  {
    When set to True, each instance creation or destruction will print
    a debug message to the status console. Useful for real-time monitoring
    of instance activity.

    @note This can generate a large volume of output in active applications.
  }
  Print_Intermediate_Instance_Status: Boolean;

implementation

uses Z.Status;

var
  Instance_Hook_Busy: Boolean;  { Prevents re-entrant hook calls }

{
  Constructor for TInstance_State_Tool.
  Initializes the hash map with the specified size and sets up
  the initial state for new entries.

  @param HashSize_ The number of buckets in the hash table.
}
constructor TInstance_State_Tool.Create(const HashSize_: integer);
var
  tmp: TInstance_State_;
begin
  tmp.Update_Time := GetTimeTick();
  tmp.Update_Num := 0;
  tmp.Instance_Num := 0;
  inherited Create(HashSize_, tmp);
  IsLock_ := False;
end;

{
  Computes the hash for a string key.
  Uses a two-stage approach: first fast hash, then CRC32 for distribution.

  @param Key_ The string key to hash.
  @return A 32-bit hash value.
}
function TInstance_State_Tool.Get_Key_Hash(const Key_: SystemString): THash;
begin
  Result := FastHashSystemString(Key_);
  Result := Get_CRC32(@Result, SizeOf(THash));
end;

{
  Compares two string keys using case-insensitive comparison.

  @param Key_1 The first key.
  @param Key_2 The second key.
  @return True if the keys are equal (case-insensitive).
}
function TInstance_State_Tool.Compare_Key(const Key_1, Key_2: SystemString): Boolean;
begin
  Result := SameText(Key_1, Key_2);
end;

{
  Frees the key and value when an entry is removed from the hash map.
  Clears the string key to release its memory.

  @param Key_   The key to free.
  @param Value_ The value to free (cleared, but not disposed).
}
procedure TInstance_State_Tool.DoFree(var Key: SystemString; var Value: TInstance_State_);
begin
  Key := '';
  inherited DoFree(Key, Value);
end;

{
  Increments or decrements the instance count for a key.
  This is the core method called by the instance hook functions.

  @param Key_   The identifier (class or unit name).
  @param Value_ The delta value (1 for creation, -1 for destruction).
}
procedure TInstance_State_Tool.IncValue(Key_: SystemString; Value_: Int64);
var
  p: TInstance_State_Tool__.PValue;
begin
  if Value_ = 0 then
      Exit;
  p := Get_Value_Ptr(Key_);
  p^.Instance_Num := p^.Instance_Num + Value_;
  if p^.Instance_Num < 0 then
      p^.Instance_Num := 0;
  Inc(p^.Update_Num);
  p^.Update_Time := GetTimeTick();
end;

{ Comparators for sorting by various criteria }
function TInstance_State_Tool.Do_Sort_By_Time(var L, R: TInstance_State_): integer;
begin
  if L.Update_Time < R.Update_Time then
      Result := -1
  else if L.Update_Time > R.Update_Time then
      Result := 1
  else
      Result := 0;
end;

procedure TInstance_State_Tool.Sort_By_Time;
begin
  Sort_Value_M(Do_Sort_By_Time);
end;

function TInstance_State_Tool.Do_Sort_By_Instance(var L, R: TInstance_State_): integer;
begin
  if L.Instance_Num < R.Instance_Num then
      Result := -1
  else if L.Instance_Num > R.Instance_Num then
      Result := 1
  else
      Result := 0;
end;

procedure TInstance_State_Tool.Sort_By_Instance;
begin
  Sort_Value_M(Do_Sort_By_Instance);
end;

function TInstance_State_Tool.Do_Sort_By_Update(var L, R: TInstance_State_): integer;
begin
  if L.Update_Num < R.Update_Num then
      Result := -1
  else if L.Update_Num > R.Update_Num then
      Result := 1
  else
      Result := 0;
end;

procedure TInstance_State_Tool.Sort_By_Update;
begin
  Sort_Value_M(Do_Sort_By_Update);
end;

{
  Creates a shallow clone of the state tool.
  All entries are copied by value into a new tool instance.

  @return A new TInstance_State_Tool with the same data.
}
function TInstance_State_Tool.Clone: TInstance_State_Tool;
begin
  Result := TInstance_State_Tool.Create(GetHashSize);
  if Num > 0 then
    with Repeat_ do
      repeat
        Result.Add(queue^.Data^.Data.Primary, queue^.Data^.Data.Second, False);
      until not Next;
end;

{
  Computes the difference between two state tools.
  For each key present in this tool, subtracts the value from the other
  tool and stores the delta.

  @param Tool_ The other state tool to compare against.
  @return A new TInstance_State_Tool containing delta values.
}
function TInstance_State_Tool.Compare_State(Tool_: TInstance_State_Tool): TInstance_State_Tool;
var
  v1, v2, v3: TInstance_State_;
begin
  Result := TInstance_State_Tool.Create(GetHashSize);
  if Num > 0 then
    with Repeat_ do
      repeat
        v1 := queue^.Data^.Data.Second;
        v2 := Tool_.Get_Key_Value(queue^.Data^.Data.Primary);
        v3.Update_Time := v1.Update_Time - v2.Update_Time;
        v3.Update_Num := v1.Update_Num - v2.Update_Num;
        v3.Instance_Num := v1.Instance_Num - v2.Instance_Num;
        Result.Add(queue^.Data^.Data.Primary, v3, False);
      until not Next;
end;

{
  Hook function called when an instance is created.
  Increments the instance count for the specified class/unit.

  @param Instance_ The identifier string (class or unit name).
}
procedure Inc_Instance_Num___(const Instance_: string);
begin
  if Instance_State_Tool.IsLock_ then
      Exit;
  if Instance_Hook_Busy then
      Exit;
  Instance_Hook_Busy := True;
  try
    Instance_State_Tool.Queue_Pool.Lock;
    Instance_State_Tool.IsLock_ := True;
    Instance_State_Tool.IncValue(Instance_, 1);
    Instance_State_Tool.IsLock_ := False;
    Instance_State_Tool.Queue_Pool.UnLock;
    if Print_Intermediate_Instance_Status then
        DoStatus('%s created', [Instance_]);
  finally
    Instance_Hook_Busy := False;
  end;
end;

{
  Hook function called when an instance is destroyed.
  Decrements the instance count for the specified class/unit.

  @param Instance_ The identifier string (class or unit name).
}
procedure Dec_Instance_Num___(const Instance_: string);
begin
  if Instance_State_Tool.IsLock_ then
      Exit;
  if Instance_Hook_Busy then
      Exit;
  Instance_Hook_Busy := True;
  try
    Instance_State_Tool.Queue_Pool.Lock;
    Instance_State_Tool.IsLock_ := True;
    Instance_State_Tool.IncValue(Instance_, -1);
    Instance_State_Tool.IsLock_ := False;
    Instance_State_Tool.Queue_Pool.UnLock;
    if Print_Intermediate_Instance_Status then
        DoStatus('%s destroy', [Instance_]);
  finally
    Instance_Hook_Busy := False;
  end;
end;

var
  { Backups of the original hook functions for restoration on finalization }
  Backup_Inc_Instance_Num: TOn_Instance_Info = nil;
  Backup_Dec_Instance_Num: TOn_Instance_Info = nil;

initialization
  { Initialize the global instance state tool }
  Instance_State_Tool := TInstance_State_Tool.Create($FFFF);

  { Save and replace the global instance hooks }
  Backup_Inc_Instance_Num := Inc_Instance_Num;
  Backup_Dec_Instance_Num := Dec_Instance_Num;
  Z.Core.Inc_Instance_Num := Inc_Instance_Num___;
  Z.Core.Dec_Instance_Num := Dec_Instance_Num___;
  Print_Intermediate_Instance_Status := False;
  Instance_Hook_Busy := False;

finalization
  { Restore the original hooks }
  Inc_Instance_Num := Backup_Inc_Instance_Num;
  Dec_Instance_Num := Backup_Dec_Instance_Num;

  { Clean up the global tool }
  DisposeObjectAndNil(Instance_State_Tool);

end.

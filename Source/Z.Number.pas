{ ******************************************************************************
  * Z.Number – Dynamic Named Variable System with Expression Integration
  *
  * This unit provides a flexible, runtime‑managed variable system that
  * allows you to create, access, and manipulate named variables (modules)
  * dynamically. Each variable stores a Variant value and offers a rich set
  * of typed accessors, change hooks, events, and seamless integration with
  * the Z.Expression engine for script‑based evaluation and modification.
  *
  * Core Features:
  *   - Named Variable Storage: Create and access variables by name using
  *     a pool (TNumberModulePool). Missing variables are automatically
  *     created on demand.
  *   - Typed Accessors: Read and write values as Integer, Double, String,
  *     Boolean, Int64, Cardinal, etc., with automatic type conversion.
  *   - Origin Value: Each module maintains a separate "origin" value,
  *     useful for tracking baseline or initial values independently from
  *     the current value.
  *   - Pre‑Change Hooks: Register callbacks (TNumberModuleHook) that are
  *     invoked before a value change, allowing validation, transformation,
  *     or logging. Hooks can modify the proposed new value.
  *   - Post‑Change Events: Register callbacks (TNumberModuleEvent) that
  *     are invoked after a value change, ideal for side effects, UI
  *     updates, or logging.
  *   - Expression Integration: Every module is automatically exposed as a
  *     function in the pool’s expression runtime. Calling the function
  *     with parameters sets the value; calling it without parameters
  *     returns the current value.
  *   - Built‑in Script Functions: The pool provides "Set(name, value)"
  *     and "Get(name, default)" functions for use in expressions.
  *   - Vector Script Support: Evaluate comma‑separated expressions in a
  *     single call, returning an array of results.
  *   - Serialization: Save and load the entire pool state to/from a
  *     stream using the Z.DFE (Data Frame Engine) format.
  *   - Dirty Flag: The pool tracks changes, simplifying persistence logic.
  *
  * Architecture:
  *   The pool (TNumberModulePool) owns a hash table of modules
  *   (TNumberModule). Each module stores its current value, origin value,
  *   lists of hooks and events, and a reference back to the pool.
  *
  *   When a module’s value is set (via Value, AsInteger, etc.):
  *     1. All registered hooks are executed in registration order.
  *        Each hook can modify the proposed new value.
  *     2. The (possibly modified) value is stored.
  *     3. All registered events are executed.
  *     4. The OnChange callback (if assigned) is triggered.
  *     5. The pool’s OnNMChange event (if assigned) is triggered.
  *
  *   The pool also lazily creates an expression runtime (TOpCustomRunTime)
  *   when first used. It registers the "Set" and "Get" functions, and
  *   automatically registers every module as a function with the module’s
  *   name. This allows expressions like:
  *     - "myVar"            -> returns the current value.
  *     - "myVar(42)"        -> sets the value to 42.
  *     - "Set('x', 10)"     -> sets module "x" to 10.
  *     - "Get('y', 0)"      -> returns y’s value, or 0 if y doesn’t exist.
  *
  * Use Cases:
  *   - Configuration Management: Store application settings as named
  *     variables with typed access.
  *   - Game Development: Manage game state (health, score, position) and
  *     use expressions for dynamic calculations.
  *   - Scripting Environments: Expose internal variables to a scripting
  *     layer for runtime tuning and automation.
  *   - Data Binding: Connect variables to UI controls, updating them
  *     automatically via events.
  *   - Debugging: Use hooks to log or trace all value changes.
  *
  * Example (basic usage):
  *   var Pool: TNumberModulePool;
  *   begin
  *     Pool := TNumberModulePool.Create;
  *     Pool['health'].AsInteger := 100;
  *     Pool['damage'].AsDouble := 15.5;
  *     Pool['health'] := Pool['health'] - Pool['damage']; // arithmetic
  *     ShowMessage(Pool['health'].AsString); // '84.5'
  *
  *     // Expression script
  *     Pool.RunScript('health := health - damage * 2');
  *     ShowMessage(Pool['health'].AsString);
  *   end;
  *
  * Example (using hooks for validation):
  *   var Hook: TNumberModuleHookPool;
  *   begin
  *     Hook := Pool['speed'].RegisterCurrentValueHook;
  *     Hook.OnCurrentDMHook :=
  *       procedure(Sender: TNumberModuleHookPool; OLD_: Variant; var New_: Variant)
  *       begin
  *         if VarIsNumeric(New_) and (New_ < 0) then
  *           New_ := 0;   // clamp negative speed to zero
  *       end;
  *   end;
  *
  * Dependencies:
  *   - Z.Core          : For threading, critical sections, and object disposal.
  *   - Z.HashList.Templet : For the underlying generic hash map.
  *   - Z.ListEngine    : For string lists and hash tables.
  *   - Z.PascalStrings : For Pascal‑style string handling.
  *   - Z.Parsing       : For text parsing (used by expression engine).
  *   - Z.Expression    : For expression parsing and evaluation.
  *   - Z.OpCode        : For the expression runtime.
  *   - Z.DFE           : For serialization of the pool state.
  *
  * This unit is a powerful tool for runtime‑managed variable systems,
  * blending the simplicity of named variables with the flexibility of
  * dynamic scripting.
  ****************************************************************************** }
unit Z.Number;

{$DEFINE FPC_DELPHI_MODE}
{$I Z.Define.inc}

interface

uses
{$IFDEF FPC}
  Z.FPC.GenericList,
{$ENDIF FPC}
  Z.Core, Z.HashList.Templet, Z.ListEngine, Z.PascalStrings, Z.Parsing, Z.Expression, Z.OpCode;

type
  { Forward declarations for mutually dependent types }
  TNumberModuleHookPool = class;
  TNumberModuleEventPool = class;
  TNumberModulePool = class;
  TNumberModule = class;
  TNumberModuleHookPoolList = TGenericsList<TNumberModuleHookPool>;
  TNumberModuleEventPoolList = TGenericsList<TNumberModuleEventPool>;

  {
    * TNumberModuleHook – Callback signature for value modification hooks.
    * This callback is invoked before a value change is applied, allowing the
    * hook to intercept and modify the proposed new value.
    *
    * @param Sender  The hook pool instance that triggered the callback.
    * @param OLD_    The current value before modification.
    * @param New_    The proposed new value. The hook can modify this parameter
    *                to change the value that will actually be set.
    *
    * @Example:
    *   procedure MyHook(Sender: TNumberModuleHookPool; OLD_: Variant; var New_: Variant);
    *   begin
    *     if VarIsNumeric(New_) then
    *       New_ := New_ * 2;   // Double any numeric assignment
    *   end;
  }
  TNumberModuleHook = procedure(Sender: TNumberModuleHookPool; OLD_: Variant; var New_: Variant) of object;

  {
    * TNumberModuleHookPool represents a single registered hook on a TNumberModule.
    * Hooks are executed before a value change, in the order they were registered.
    * They can be used for validation, transformation, or logging.
    *
    * Each hook has an associated callback and an optional tag for identification.
    *
    * @Example:
    *   var Hook: TNumberModuleHookPool;
    *   begin
    *     Hook := MyModule.RegisterCurrentValueHook;
    *     Hook.OnCurrentDMHook := MyHook;
    *     Hook.Tag := 'ValidationHook';
    *   end;
  }
  TNumberModuleHookPool = class(TCore_Object_Intermediate)
  private
    FOwner: TNumberModule; // The module this hook belongs to
    FOwnerList: TNumberModuleHookPoolList; // The list containing this hook
    FOnCurrentDMHook: TNumberModuleHook; // The callback to execute
    FTag: SystemString; // Optional identifier tag
  protected
  public
    constructor Create(Owner_: TNumberModule; OwnerList_: TNumberModuleHookPoolList);
    destructor Destroy; override;

    { The TNumberModule that owns this hook. }
    property Owner: TNumberModule read FOwner;

    { The callback function to be executed when the module's value changes. }
    property OnCurrentDMHook: TNumberModuleHook read FOnCurrentDMHook write FOnCurrentDMHook;

    { An optional tag string for identification and debugging. }
    property Tag: SystemString read FTag write FTag;
  end;

  {
    * TNumberModuleEvent – Callback signature for value change events.
    * This callback is invoked after a value change has been applied.
    *
    * @param Sender  The event pool instance that triggered the callback.
    * @param New_    The new value that was set.
    *
    * @Example:
    *   procedure MyEvent(Sender: TNumberModuleEventPool; New_: Variant);
    *   begin
    *     DoStatus('Value changed to ' + VarToStr(New_));
    *   end;
  }
  TNumberModuleEvent = procedure(Sender: TNumberModuleEventPool; New_: Variant) of object;

  {
    * TNumberModuleEventPool represents a single registered event on a TNumberModule.
    * Events are triggered after a value change, in contrast to hooks which are
    * triggered before the change.
    *
    * Events can be used for side effects, UI updates, or logging after a value
    * has been modified.
    *
    * @Example:
    *   var Evt: TNumberModuleEventPool;
    *   begin
    *     Evt := MyModule.RegisterCurrentValueChangeAfterEvent;
    *     Evt.OnCurrentDMEvent := MyEvent;
    *     Evt.Tag := 'LogEvent';
    *   end;
  }
  TNumberModuleEventPool = class(TCore_Object_Intermediate)
  private
    FOwner: TNumberModule; // The module this event belongs to
    FOwnerList: TNumberModuleEventPoolList; // The list containing this event
    FOnCurrentDMEvent: TNumberModuleEvent; // The callback to execute
    FTag: SystemString; // Optional identifier tag
  protected
  public
    constructor Create(Owner_: TNumberModule; OwnerList_: TNumberModuleEventPoolList);
    destructor Destroy; override;

    { The TNumberModule that owns this event. }
    property Owner: TNumberModule read FOwner;

    { The callback function to be executed after the module's value changes. }
    property OnCurrentDMEvent: TNumberModuleEvent read FOnCurrentDMEvent write FOnCurrentDMEvent;

    { An optional tag string for identification and debugging. }
    property Tag: SystemString read FTag write FTag;
  end;

  {
    * TNumberModuleChangeEvent – Callback for value changes on a TNumberModule.
    * Provides both the old and new values for more detailed handling.
    *
    * @param Sender The TNumberModule whose value changed.
    * @param OLD_   The previous value.
    * @param New_   The new value.
  }
  TNumberModuleChangeEvent = procedure(Sender: TNumberModule; OLD_, New_: Variant);

  {
    * TNumberModule – A dynamic named variable that stores a Variant value.
    * It provides a rich set of features:
    *   - Typed accessors: AsInteger, AsDouble, AsString, AsBool, etc.
    *   - Origin value: A separate storage for a baseline or initial value.
    *   - Hook mechanism: Intercept and modify value changes before they occur.
    *   - Event mechanism: React to value changes after they occur.
    *   - Expression integration: The module's name can be used as a function
    *     in expressions (e.g., "myVar(42)" sets the value, "myVar" reads it).
    *   - OnChange event: A simple callback for value changes.
    *
    * The module is designed to be used within a TNumberModulePool, which
    * manages the lifecycle and provides access by name.
    *
    * @Example:
    *   var NM: TNumberModule;
    *   begin
    *     NM := Pool['MyVar'];
    *     NM.AsInteger := 42;             // Set integer value
    *     NM.Origin := 0;                // Set baseline
    *     NM.OnChange := MyChangeHandler;
    *     // In expressions: MyVar(100) sets value to 100; MyVar returns current.
    *   end;
  }
  TNumberModule = class(TCore_Object_Intermediate)
  private
    FOwner: TNumberModulePool; // The pool that owns this module
    FName: SystemString; // Unique name within the pool
    FCurrentValueHookPool: TNumberModuleHookPoolList; // Registered hooks
    FCurrentValueChangeAfterEventPool: TNumberModuleEventPoolList; // Registered events
    FCurrentValue: Variant; // Current value
    FOriginValue: Variant; // Baseline/origin value
    FEnabledHook: Boolean; // If False, hooks are skipped
    FEnabledEvent: Boolean; // If False, events are skipped
    FOnChange: TNumberModuleChangeEvent; // Simple change callback

  private
    { Internal property accessors }
    procedure SetName(const Value_: SystemString);
    function GetCurrentValue: Variant;
    procedure SetCurrentValue(const Value_: Variant);
    function GetOriginValue: Variant;
    procedure SetOriginValue(const Value_: Variant);
    procedure DoCurrentValueHook(const OLD_, New_: Variant);
    procedure Clear;
    procedure DoRegOpProc();
    function OP_DoProc(Sender: TOpCustomRunTime; OP_RT_Data: POpRTData; var OP_Param: TOpParam): Variant;

  private
    { Typed accessors for Current value }
    function GetCurrentAsDouble: Double;
    procedure SetCurrentAsDouble(const Value_: Double);
    function GetCurrentAsSingle: Single;
    procedure SetCurrentAsSingle(const Value_: Single);
    function GetCurrentAsInt64: Int64;
    procedure SetCurrentAsInt64(const Value_: Int64);
    function GetCurrentAsInteger: Integer;
    procedure SetCurrentAsInteger(const Value_: Integer);
    function GetCurrentAsCardinal: Cardinal;
    procedure SetCurrentAsCardinal(const Value_: Cardinal);
    procedure SetCurrentAsString(const Value_: SystemString);
    function GetCurrentAsString: SystemString;
    function GetCurrentAsBool: Boolean;
    procedure SetCurrentAsBool(const Value_: Boolean);

    { Typed accessors for Origin value }
    function GetOriginAsDouble: Double;
    procedure SetOriginAsDouble(const Value_: Double);
    function GetOriginAsSingle: Single;
    procedure SetOriginAsSingle(const Value_: Single);
    function GetOriginAsInt64: Int64;
    procedure SetOriginAsInt64(const Value_: Int64);
    function GetOriginAsInteger: Integer;
    procedure SetOriginAsInteger(const Value_: Integer);
    function GetOriginAsCardinal: Cardinal;
    procedure SetOriginAsCardinal(const Value_: Cardinal);
    function GetOriginAsString: SystemString;
    procedure SetOriginAsString(const Value_: SystemString);
    function GetOriginAsBool: Boolean;
    procedure SetOriginAsBool(const Value_: Boolean);

  public
    constructor Create(Owner_: TNumberModulePool);
    destructor Destroy; override;

    { Called when the value changes. Can be overridden for custom handling. }
    property OnChange: TNumberModuleChangeEvent read FOnChange write FOnChange;

    { If False, hooks are not executed during value changes. Default is True. }
    property EnabledHook: Boolean read FEnabledHook write FEnabledHook;

    { If False, events are not executed during value changes. Default is True. }
    property EnabledEvent: Boolean read FEnabledEvent write FEnabledEvent;

    { The TNumberModulePool that owns this module. }
    property Owner: TNumberModulePool read FOwner;

    { The unique name of this module within its pool. }
    property Name: SystemString read FName write SetName;

    {
      * Triggers a change notification without changing the value.
      * Useful for propagating state changes from the origin value.
      *
      * @Example:
      *   MyModule.DoChange;   // Triggers hooks/events even if value unchanged.
    }
    procedure DoChange;

    {
      * Registers a new hook on this module.
      * The hook will be called before value changes.
      * Returns the hook pool instance for further configuration.
      *
      * @Example:
      *   var Hook: TNumberModuleHookPool;
      *   begin
      *     Hook := MyModule.RegisterCurrentValueHook;
      *     Hook.OnCurrentDMHook := MyHookFunction;
      *   end;
    }
    function RegisterCurrentValueHook: TNumberModuleHookPool;

    {
      * Copies all hook interfaces from another module.
      * @param sour The source module to copy hooks from.
    }
    procedure CopyHookInterfaceFrom(sour: TNumberModule);

    {
      * Registers a new event on this module.
      * The event will be called after value changes.
      * Returns the event pool instance for further configuration.
      *
      * @Example:
      *   var Evt: TNumberModuleEventPool;
      *   begin
      *     Evt := MyModule.RegisterCurrentValueChangeAfterEvent;
      *     Evt.OnCurrentDMEvent := MyEventHandler;
      *   end;
    }
    function RegisterCurrentValueChangeAfterEvent: TNumberModuleEventPool;

    {
      * Copies all event interfaces from another module.
      * @param sour The source module to copy events from.
    }
    procedure CopyChangeAfterEventInterfaceFrom(sour: TNumberModule);

    {
      * Copies the value and name from another module.
      * @param sour The source module to copy from.
    }
    procedure Assign(sour: TNumberModule);

    { ----- Current Value Properties ----- }

    { The current value as a Variant. }
    property Value: Variant read GetCurrentValue write SetCurrentValue;
    property AsValue: Variant read GetCurrentValue write SetCurrentValue;
    property AsSingle: Single read GetCurrentAsSingle write SetCurrentAsSingle;
    property AsDouble: Double read GetCurrentAsDouble write SetCurrentAsDouble;
    property AsInteger: Integer read GetCurrentAsInteger write SetCurrentAsInteger;
    property AsInt64: Int64 read GetCurrentAsInt64 write SetCurrentAsInt64;
    property AsCardinal: Cardinal read GetCurrentAsCardinal write SetCurrentAsCardinal;
    property AsString: SystemString read GetCurrentAsString write SetCurrentAsString;
    property AsBool: Boolean read GetCurrentAsBool write SetCurrentAsBool;
    property CurrentAsSingle: Single read GetCurrentAsSingle write SetCurrentAsSingle;
    property CurrentAsDouble: Double read GetCurrentAsDouble write SetCurrentAsDouble;
    property CurrentAsInteger: Integer read GetCurrentAsInteger write SetCurrentAsInteger;
    property CurrentAsInt64: Int64 read GetCurrentAsInt64 write SetCurrentAsInt64;
    property CurrentAsCardinal: Cardinal read GetCurrentAsCardinal write SetCurrentAsCardinal;
    property CurrentAsString: SystemString read GetCurrentAsString write SetCurrentAsString;
    property CurrentAsBool: Boolean read GetCurrentAsBool write SetCurrentAsBool;

    { ----- Origin Value Properties ----- }
    {
      * The origin/baseline value. This can be used to track the initial
      * value separately from the current value.
    }
    property Origin: Variant read GetOriginValue write SetOriginValue;
    property OriginAsSingle: Single read GetOriginAsSingle write SetOriginAsSingle;
    property OriginAsDouble: Double read GetOriginAsDouble write SetOriginAsDouble;
    property OriginAsInteger: Integer read GetOriginAsInteger write SetOriginAsInteger;
    property OriginAsInt64: Int64 read GetOriginAsInt64 write SetOriginAsInt64;
    property OriginAsCardinal: Cardinal read GetOriginAsCardinal write SetOriginAsCardinal;
    property OriginAsString: SystemString read GetOriginAsString write SetOriginAsString;
    property OriginAsBool: Boolean read GetOriginAsBool write SetOriginAsBool;

    {
      * Direct access to underlying Variant storage. Use with caution.
      * These properties bypass hooks and events.
    }
    property DirectValue: Variant read FCurrentValue write FCurrentValue;
    property DirectOrigin: Variant read FOriginValue write FOriginValue;
  end;

  { Declaration types for TNumberModulePool }
  TNumberModulePool_Decl = TGeneric_String_Object_Hash<TNumberModule>;

  {
    * TOnNMChange – Callback for value changes in a TNumberModulePool.
    * Triggered whenever any module in the pool changes its value.
    *
    * @param Sender The pool that triggered the event.
    * @param NM_    The module whose value changed.
    * @param OLD_   The previous value.
    * @param New_   The new value.
  }
  TOnNMChange = procedure(Sender: TNumberModulePool; NM_: TNumberModule; OLD_, New_: Variant) of object;

  {
    * TOnNMCreateOpRunTime – Callback for when the pool's expression runtime
    * is created. Allows external code to register additional functions
    * or modify the runtime before it is used.
    *
    * @param Sender The pool that created the runtime.
    * @param OP_    The expression runtime instance.
  }
  TOnNMCreateOpRunTime = procedure(Sender: TNumberModulePool; OP_: TOpCustomRunTime) of object;

  {
    * TNumberModulePool – A container that manages a collection of TNumberModule
    * instances, indexed by name. It provides:
    *
    *   - Automatic module creation: Accessing Items['name'] creates the module
    *     if it doesn't already exist.
    *   - Expression integration: Modules can be used in expressions via
    *     the pool's ExpOpRunTime.
    *   - Built-in script functions: "Set(name, value)" and "Get(name, default)"
    *   - Serialization: Load and save the entire pool state to/from a stream.
    *   - Script execution: Run expressions that reference modules by name.
    *   - Vector expression support: Evaluate multiple expressions at once.
    *
    * This is the primary interface for using the Number Module system.
    *
    * @Example:
    *   var Pool: TNumberModulePool;
    *   begin
    *     Pool := TNumberModulePool.Create;
    *     Pool['X'].AsInteger := 10;
    *     Pool['Y'].AsInteger := 20;
    *     Pool.RunScript('Z := X + Y');       // Z becomes 30
    *     ShowMessage(Pool['Z'].AsString);   // '30'
    *   end;
  }
  TNumberModulePool = class(TCore_Object_Intermediate)
  protected
    FOnNMChange: TOnNMChange;
    FOnNMCreateOpRunTime: TOnNMCreateOpRunTime;
    FList: TNumberModulePool_Decl; // The underlying hash table of modules
    FIsChanged: Boolean; // Dirty flag for serialization
    FExpOpRunTime: TOpCustomRunTime; // Expression runtime with modules registered

    { Internal expression function: Set(name, value) }
    function OP_DoNewNM(Sender: TOpCustomRunTime; OP_RT_Data: POpRTData; var OP_Param: TOpParam): Variant;

    { Internal expression function: Get(name, default) }
    function OP_DoGetNM(Sender: TOpCustomRunTime; OP_RT_Data: POpRTData; var OP_Param: TOpParam): Variant;

    procedure DoSwapInstance_Progress(const Name: PSystemString; Obj: TNumberModule);
    procedure DoRebuildOpRunTime_Progress(const Name: PSystemString; Obj: TNumberModule);
    procedure DoChangeAll_Progress(const Name: PSystemString; Obj: TNumberModule);
    function GetExpOpRunTime: TOpCustomRunTime;
  public
    { Triggered when any module in the pool changes its value. }
    property OnNMChange: TOnNMChange read FOnNMChange write FOnNMChange;

    { Triggered when the expression runtime is created. }
    property OnNMCreateOpRunTime: TOnNMCreateOpRunTime read FOnNMCreateOpRunTime write FOnNMCreateOpRunTime;

    constructor Create; virtual;
    destructor Destroy; override;

    {
      * Efficiently swaps the entire state with another pool.
      * @param source The pool to swap with.
    }
    procedure SwapInstance(source: TNumberModulePool);

    { Called when a module's value changes. Forwards to OnNMChange. }
    procedure DoNMChange(Sender: TNumberModule; OLD_, New_: Variant); virtual;

    {
      * Deletes a module by name.
      * @param Name_ The name of the module to delete.
    }
    procedure Delete(Name_: SystemString); virtual;

    {
      * Checks if a module with the given name exists.
      * @param Name_ The name to check.
      * @returns True if a module with that name exists.
    }
    function Exists(Name_: SystemString): Boolean; virtual;

    {
      * Checks if a specific TNumberModule instance belongs to this pool.
      * @param NM_ The module instance to check.
      * @returns True if the module is owned by this pool.
    }
    function ExistsIntf(NM_: TNumberModule): Boolean; virtual;

    { Removes all modules from the pool. }
    procedure Clear; virtual;

    {
      * Copies all values from another pool.
      * @param source The source pool to copy from.
    }
    procedure Assign(source: TNumberModulePool); virtual;

    { Triggers a change notification for all modules. }
    procedure DoChangeAll; virtual;

    {
      * Loads the pool state from a stream (DFE format).
      * @param stream The stream to read from.
    }
    procedure LoadFromStream(stream: TCore_Stream); virtual;

    {
      * Saves the pool state to a stream (DFE format).
      * @param stream The stream to write to.
    }
    procedure SaveToStream(stream: TCore_Stream); virtual;

    {
      * Gets a module by name, creating it if it doesn't exist.
      * @param Name_ The name of the module.
      * @returns The TNumberModule instance.
    }
    function GetItems(Name_: SystemString): TNumberModule; virtual;

    { Indexed access to modules. Creates the module if it doesn't exist. }
    property Items[Name_: SystemString]: TNumberModule read GetItems; default;

    { The underlying hash table. Use with caution. }
    property List: TNumberModulePool_Decl read FList;

    { Dirty flag indicating whether the pool has been modified. }
    property IsChanged: Boolean read FIsChanged write FIsChanged;

    { ----- Script/Expression Integration ----- }

    {
      * Rebuilds the expression runtime. Call after adding many modules.
    }
    procedure RebuildOpRunTime;

    { The expression runtime that provides module access in scripts. }
    property ExpOpRunTime: TOpCustomRunTime read GetExpOpRunTime;

    {
      * Checks if an expression is a vector expression (contains commas).
      * @param ExpressionText_ The expression text.
      * @param TS_ The text style (Pascal or C).
      * @returns True if the expression is a vector.
    }
    function IsVectorScript(ExpressionText_: SystemString; TS_: TTextStyle): Boolean; overload;

    {
      * Checks if an expression is a vector expression (using Pascal style).
      * @param ExpressionText_ The expression text.
      * @returns True if the expression is a vector.
    }
    function IsVectorScript(ExpressionText_: SystemString): Boolean; overload;

    {
      * Evaluates a single expression and returns the result.
      * Modules can be referenced by name in the expression.
      * @param ExpressionText_ The expression to evaluate.
      * @param TS_ The text style.
      * @returns The computed Variant result.
      *
      * @Example:
      *   var Result: Variant;
      *   begin
      *     Pool['X'] := 10;
      *     Pool['Y'] := 20;
      *     Result := Pool.RunScript('X + Y * 2', tsPascal);  // Result = 50
      *   end;
    }
    function RunScript(ExpressionText_: SystemString; TS_: TTextStyle): Variant; overload;

    {
      * Evaluates a single expression using Pascal style.
      * @param ExpressionText_ The expression to evaluate.
      * @returns The computed Variant result.
    }
    function RunScript(ExpressionText_: SystemString): Variant; overload;

    {
      * Evaluates a vector expression and returns an array of results.
      * @param ExpressionText_ The expression containing comma-separated sub-expressions.
      * @param TS_ The text style.
      * @returns An array of Variant results.
      *
      * @Example:
      *   var Results: TExpressionValueVector;
      *   begin
      *     Results := Pool.RunVectorScript('X+1, Y*2, X-Y', tsPascal);
      *     // Results[0] = X+1, Results[1] = Y*2, Results[2] = X-Y
      *   end;
    }
    function RunVectorScript(ExpressionText_: SystemString; TS_: TTextStyle): TExpressionValueVector; overload;

    {
      * Evaluates a vector expression using Pascal style.
      * @param ExpressionText_ The expression containing comma-separated sub-expressions.
      * @returns An array of Variant results.
    }
    function RunVectorScript(ExpressionText_: SystemString): TExpressionValueVector; overload;

    { Unit test for the Number Module system. }
    class procedure test;
  end;

implementation

uses Variants, Z.UnicodeMixedLib, Z.DFE, Z.Notify, Z.Status;

{
  * Creates a TNumberModuleHookPool instance.
  * The hook is added to the owner's hook list automatically.
}
constructor TNumberModuleHookPool.Create(Owner_: TNumberModule; OwnerList_: TNumberModuleHookPoolList);
begin
  inherited Create;
  FOwner := Owner_;
  FOwnerList := OwnerList_;
  FOnCurrentDMHook := nil;
  FTag := '';
  if FOwnerList <> nil then
      FOwnerList.Add(Self);
end;

{
  * Destroys the hook pool and removes itself from its owner's hook list.
}
destructor TNumberModuleHookPool.Destroy;
var
  i: Integer;
begin
  i := 0;
  if FOwnerList <> nil then
    while i < FOwnerList.Count do
      begin
        if FOwnerList[i] = Self then
            FOwnerList.Delete(i)
        else
            inc(i);
      end;
  inherited Destroy;
end;

{
  * Creates a TNumberModuleEventPool instance.
  * The event is added to the owner's event list automatically.
}
constructor TNumberModuleEventPool.Create(Owner_: TNumberModule; OwnerList_: TNumberModuleEventPoolList);
begin
  inherited Create;
  FOwner := Owner_;
  FOwnerList := OwnerList_;
  FOnCurrentDMEvent := nil;
  FTag := '';
  if FOwnerList <> nil then
      FOwnerList.Add(Self);
end;

{
  * Destroys the event pool and removes itself from its owner's event list.
}
destructor TNumberModuleEventPool.Destroy;
var
  i: Integer;
begin
  i := 0;
  if FOwnerList <> nil then
    while i < FOwnerList.Count do
      begin
        if FOwnerList[i] = Self then
            FOwnerList.Delete(i)
        else
            inc(i);
      end;
  inherited Destroy;
end;

{
  * Changes the module's name.
  * If the module belongs to a pool, it renames the entry in the pool and
  * rebuilds the expression runtime.
}
procedure TNumberModule.SetName(const Value_: SystemString);
begin
  if Value_ <> FName then
    begin
      if FOwner <> nil then
        begin
          if FOwner.FList.ReName(FName, Value_) then
              FName := Value_;
          FOwner.RebuildOpRunTime;
        end
      else
          FName := Value_;
    end;
end;

{ Returns the current value as a Variant. }
function TNumberModule.GetCurrentValue: Variant;
begin
  Result := FCurrentValue;
end;

{
  * Sets the current value.
  * If the origin is null, it is initialized to the new value.
  * Then hooks, events, and change callbacks are triggered.
}
procedure TNumberModule.SetCurrentValue(const Value_: Variant);
begin
  if VarIsNull(FOriginValue) then
    begin
      FOriginValue := Value_;
      DoCurrentValueHook(FCurrentValue, FOriginValue);
    end
  else
      DoCurrentValueHook(FCurrentValue, Value_);
end;

{ Returns the origin value as Variant. }
function TNumberModule.GetOriginValue: Variant;
begin
  Result := FOriginValue;
end;

{
  * Sets the origin value and triggers a value change (with hooks/events)
  * using the new origin as the proposed new value.
}
procedure TNumberModule.SetOriginValue(const Value_: Variant);
begin
  FOriginValue := Value_;
  DoCurrentValueHook(FCurrentValue, FOriginValue);
end;

{
  * Internal method that executes all hooks, applies the new value,
  * triggers all events, and calls the OnChange callback.
  * It also notifies the owning pool.
}
procedure TNumberModule.DoCurrentValueHook(const OLD_, New_: Variant);
var
  i: Integer;
  H_: TNumberModuleHookPool;
  E_: TNumberModuleEventPool;
  N_: Variant;
begin
  N_ := New_;
  if (FEnabledHook) then
    for i := 0 to FCurrentValueHookPool.Count - 1 do
      begin
        H_ := TNumberModuleHookPool(FCurrentValueHookPool[i]);
        if Assigned(H_.FOnCurrentDMHook) then
          begin
            try
                H_.FOnCurrentDMHook(H_, FCurrentValue, N_);
            except
            end;
          end;
      end;
  FCurrentValue := N_;
  // trigger change event
  if (FEnabledEvent) then
    for i := 0 to FCurrentValueChangeAfterEventPool.Count - 1 do
      begin
        E_ := FCurrentValueChangeAfterEventPool[i];
        if Assigned(E_.FOnCurrentDMEvent) then
          begin
            try
                E_.FOnCurrentDMEvent(E_, FCurrentValue);
            except
            end;
          end;
      end;

  if Assigned(FOnChange) then
    begin
      try
          FOnChange(Self, OLD_, N_);
      except
      end;
    end;

  if FOwner <> nil then
    begin
      try
          Owner.DoNMChange(Self, OLD_, N_);
      except
      end;
    end;
end;

{ Clears all hooks and events registered on this module. }
procedure TNumberModule.Clear;
begin
  while FCurrentValueHookPool.Count > 0 do
      DisposeObject(FCurrentValueHookPool[0]);
  while FCurrentValueChangeAfterEventPool.Count > 0 do
      DisposeObject(FCurrentValueChangeAfterEventPool[0]);
end;

{
  * Registers this module as a function in the owning pool's expression runtime.
  * The function name is the module's name; calling it with parameters sets
  * the value, and calling without parameters returns the current value.
}
procedure TNumberModule.DoRegOpProc;
begin
  if Owner <> nil then
      Owner.ExpOpRunTime.Reg_RT_OpM(Name, '', OP_DoProc);
end;

{
  * The actual expression function implementation.
  * If parameters are passed, the first parameter becomes the new value
  * (and additional parameters are concatenated). Otherwise, returns the current value.
}
function TNumberModule.OP_DoProc(Sender: TOpCustomRunTime; OP_RT_Data: POpRTData; var OP_Param: TOpParam): Variant;
var
  i: Integer;
begin
  if Length(OP_Param) > 0 then
    begin
      Result := OP_Param[0];
      for i := 1 to Length(OP_Param) - 1 do
          Result := Result + OP_Param[i];
      AsValue := Result;
    end
  else
      Result := AsValue;
end;

{ Typed accessors for Current value }
function TNumberModule.GetCurrentAsDouble: Double;
begin Result := Value;
end;

procedure TNumberModule.SetCurrentAsDouble(const Value_: Double);
begin Value := Value_;
end;

function TNumberModule.GetCurrentAsSingle: Single;
begin Result := Value;
end;

procedure TNumberModule.SetCurrentAsSingle(const Value_: Single);
begin Value := Value_;
end;

function TNumberModule.GetCurrentAsInt64: Int64;
begin Result := Value;
end;

procedure TNumberModule.SetCurrentAsInt64(const Value_: Int64);
begin Value := Value_;
end;

function TNumberModule.GetCurrentAsInteger: Integer;
begin Result := Value;
end;

procedure TNumberModule.SetCurrentAsInteger(const Value_: Integer);
begin Value := Value_;
end;

function TNumberModule.GetCurrentAsCardinal: Cardinal;
begin Result := Value;
end;

procedure TNumberModule.SetCurrentAsCardinal(const Value_: Cardinal);
begin Value := Value_;
end;

procedure TNumberModule.SetCurrentAsString(const Value_: SystemString);
begin Value := Value_;
end;

function TNumberModule.GetCurrentAsString: SystemString;
begin Result := VarToStr(Value);
end;

function TNumberModule.GetCurrentAsBool: Boolean;
begin Result := Value;
end;

procedure TNumberModule.SetCurrentAsBool(const Value_: Boolean);
begin Value := Value_;
end;

{ Typed accessors for Origin value }
function TNumberModule.GetOriginAsDouble: Double;
begin Result := Origin;
end;

procedure TNumberModule.SetOriginAsDouble(const Value_: Double);
begin Origin := Value_;
end;

function TNumberModule.GetOriginAsSingle: Single;
begin Result := Origin;
end;

procedure TNumberModule.SetOriginAsSingle(const Value_: Single);
begin Origin := Value_;
end;

function TNumberModule.GetOriginAsInt64: Int64;
begin Result := Origin;
end;

procedure TNumberModule.SetOriginAsInt64(const Value_: Int64);
begin Origin := Value_;
end;

function TNumberModule.GetOriginAsInteger: Integer;
begin Result := Origin;
end;

procedure TNumberModule.SetOriginAsInteger(const Value_: Integer);
begin Origin := Value_;
end;

function TNumberModule.GetOriginAsCardinal: Cardinal;
begin Result := Origin;
end;

procedure TNumberModule.SetOriginAsCardinal(const Value_: Cardinal);
begin Origin := Value_;
end;

function TNumberModule.GetOriginAsString: SystemString;
begin Result := VarToStr(Origin);
end;

procedure TNumberModule.SetOriginAsString(const Value_: SystemString);
begin Origin := Value_;
end;

function TNumberModule.GetOriginAsBool: Boolean;
begin Result := OriginAsInteger > 0;
end;

procedure TNumberModule.SetOriginAsBool(const Value_: Boolean);
begin
  if Value_ then
      OriginAsInteger := 1
  else
      OriginAsInteger := 0;
end;

{
  * Creates a new TNumberModule instance.
  * It initializes internal lists and sets default flag values.
}
constructor TNumberModule.Create(Owner_: TNumberModulePool);
begin
  inherited Create;
  FOwner := Owner_;
  FName := '';
  FCurrentValueHookPool := TNumberModuleHookPoolList.Create;
  FCurrentValueChangeAfterEventPool := TNumberModuleEventPoolList.Create;
  FCurrentValue := NULL;
  FOriginValue := NULL;
  FEnabledHook := True;
  FEnabledEvent := True;
  FOnChange := nil;
end;

{
  * Destroys the module.
  * Removes its function from the pool's expression runtime and clears all hooks/events.
}
destructor TNumberModule.Destroy;
begin
  if (Name <> '') and (Owner <> nil) and (Owner.FExpOpRunTime <> nil) then
      Owner.FExpOpRunTime.ProcList.Delete(Name);
  Clear;
  DisposeObject(FCurrentValueChangeAfterEventPool);
  DisposeObject(FCurrentValueHookPool);
  inherited Destroy;
end;

{
  * Triggers a change notification using the current value.
  * Useful when the origin changes without the current value changing.
}
procedure TNumberModule.DoChange;
begin
  DoCurrentValueHook(FCurrentValue, FCurrentValue);
  if Owner <> nil then
      Owner.FIsChanged := True;
end;

{ Creates and registers a new hook pool, returning it for configuration. }
function TNumberModule.RegisterCurrentValueHook: TNumberModuleHookPool;
begin
  Result := TNumberModuleHookPool.Create(Self, FCurrentValueHookPool);
end;

{
  * Copies all hook callbacks from the source module.
  * The new hooks are appended to the existing hook list.
}
procedure TNumberModule.CopyHookInterfaceFrom(sour: TNumberModule);
var
  i: Integer;
begin
  // copy new interface
  for i := 0 to sour.FCurrentValueHookPool.Count - 1 do
      RegisterCurrentValueHook.OnCurrentDMHook := TNumberModuleHookPool(sour.FCurrentValueHookPool[i]).OnCurrentDMHook;
end;

{ Creates and registers a new event pool, returning it for configuration. }
function TNumberModule.RegisterCurrentValueChangeAfterEvent: TNumberModuleEventPool;
begin
  Result := TNumberModuleEventPool.Create(Self, FCurrentValueChangeAfterEventPool);
end;

{
  * Copies all event callbacks from the source module.
  * The new events are appended to the existing event list.
}
procedure TNumberModule.CopyChangeAfterEventInterfaceFrom(sour: TNumberModule);
var
  i: Integer;
begin
  // copy new interface
  for i := 0 to sour.FCurrentValueChangeAfterEventPool.Count - 1 do
      RegisterCurrentValueChangeAfterEvent.OnCurrentDMEvent := sour.FCurrentValueChangeAfterEventPool[i].OnCurrentDMEvent;
end;

{
  * Copies the value and name from the source module.
  * Does not copy hooks or events.
}
procedure TNumberModule.Assign(sour: TNumberModule);
begin
  FCurrentValue := sour.FCurrentValue;
  FOriginValue := sour.FOriginValue;
  FName := sour.FName;
end;

{
  * Internal implementation of the "Set" function in expressions.
  * It sets the named module's value to the second parameter and returns it.
}
function TNumberModulePool.OP_DoNewNM(Sender: TOpCustomRunTime; OP_RT_Data: POpRTData; var OP_Param: TOpParam): Variant;
var
  N_: SystemString;
begin
  N_ := VarToStr(OP_Param[0]);
  if FList.Exists(N_) then
      Items[N_].AsValue := OP_Param[1]
  else
      Items[N_].Origin := OP_Param[1];
  Result := OP_Param[1];
end;

{
  * Internal implementation of the "Get" function in expressions.
  * It returns the value of the named module, or a default if provided.
}
function TNumberModulePool.OP_DoGetNM(Sender: TOpCustomRunTime; OP_RT_Data: POpRTData; var OP_Param: TOpParam): Variant;
var
  N_: SystemString;
begin
  N_ := VarToStr(OP_Param[0]);
  if FList.Exists(N_) then
      Result := Items[N_].AsValue
  else if Length(OP_Param) = 2 then
      Result := OP_Param[1]
  else
      Result := 0;
end;

{ Progress callback used during SwapInstance to update module owners. }
procedure TNumberModulePool.DoSwapInstance_Progress(const Name: PSystemString; Obj: TNumberModule);
begin
  Obj.FOwner := Self;
end;

{ Progress callback used to register each module as a function in the expression runtime. }
procedure TNumberModulePool.DoRebuildOpRunTime_Progress(const Name: PSystemString; Obj: TNumberModule);
begin
  Obj.DoRegOpProc;
end;

{ Progress callback used to trigger a change notification on all modules. }
procedure TNumberModulePool.DoChangeAll_Progress(const Name: PSystemString; Obj: TNumberModule);
begin
  Obj.DoChange;
end;

{
  * Lazily creates the expression runtime if it doesn't exist.
  * Registers built-in functions "Set" and "Get", then registers all modules.
}
function TNumberModulePool.GetExpOpRunTime: TOpCustomRunTime;
begin
  if FExpOpRunTime = nil then
    begin
      FExpOpRunTime := TOpCustomRunTime.CustomCreate(64);
      FExpOpRunTime.Reg_RT_OpM('Set', '', OP_DoNewNM);
      FExpOpRunTime.Reg_RT_OpM('Get', '', OP_DoGetNM);
      FList.ProgressM(DoRebuildOpRunTime_Progress);
      if Assigned(OnNMCreateOpRunTime) then
          OnNMCreateOpRunTime(Self, FExpOpRunTime);
    end;
  Result := FExpOpRunTime;
end;

{ Creates the pool, initializes the module hash table and sets dirty flag. }
constructor TNumberModulePool.Create;
begin
  inherited Create;
  FList := TNumberModulePool_Decl.Create(True, 1024, nil);
  FIsChanged := False;
  FExpOpRunTime := nil;
  FOnNMChange := nil;
  FOnNMCreateOpRunTime := nil;
end;

{
  * Destroys the pool, freeing all modules and the expression runtime.
}
destructor TNumberModulePool.Destroy;
begin
  DisposeObjectAndNil(FList);
  DisposeObjectAndNil(FExpOpRunTime);
  inherited Destroy;
end;

{
  * Efficiently swaps the internal list and expression runtime with another pool.
  * Updates owner references for all modules in both pools.
}
procedure TNumberModulePool.SwapInstance(source: TNumberModulePool);
var
  tmp_FList: TNumberModulePool_Decl;
  tmp_FExpOpRunTime: TOpCustomRunTime;
begin
  tmp_FList := FList;
  tmp_FExpOpRunTime := FExpOpRunTime;
  FList := source.FList;
  FExpOpRunTime := source.FExpOpRunTime;
  source.FList := tmp_FList;
  source.FExpOpRunTime := tmp_FExpOpRunTime;
  // Update Owner
  FList.ProgressM(DoSwapInstance_Progress);
  source.FList.ProgressM(source.DoSwapInstance_Progress);
end;

{
  * Called when a module changes its value.
  * Forwards the event to the OnNMChange callback if assigned.
}
procedure TNumberModulePool.DoNMChange(Sender: TNumberModule; OLD_, New_: Variant);
begin
  try
    if Assigned(OnNMChange) then
        OnNMChange(Self, Sender, OLD_, New_);
  except
  end;
end;

{
  * Deletes a module by name.
  * The module object is freed automatically by the hash table.
}
procedure TNumberModulePool.Delete(Name_: SystemString);
begin
  FList.Delete(Name_);
end;

{
  * Checks if a module with the given name exists.
  * Returns True if found.
}
function TNumberModulePool.Exists(Name_: SystemString): Boolean;
begin
  Result := FList.Exists(Name_);
end;

{
  * Checks if a specific TNumberModule instance is owned by this pool.
}
function TNumberModulePool.ExistsIntf(NM_: TNumberModule): Boolean;
begin
  Result := FList.ExistsObject(NM_);
end;

{ Clears all modules from the pool. }
procedure TNumberModulePool.Clear;
begin
  FList.Clear;
end;

{
  * Copies all modules and their values from the source pool.
  * Existing modules are overwritten; new modules are created as needed.
}
procedure TNumberModulePool.Assign(source: TNumberModulePool);
var
  lst: TCore_ListForObj;
  i: Integer;
  NewDM, NM: TNumberModule;
begin
  lst := TCore_ListForObj.Create;
  source.FList.GetAsList(lst);
  for i := 0 to lst.Count - 1 do
    begin
      NM := lst[i] as TNumberModule;
      NewDM := Items[NM.Name];
      NewDM.Assign(NM);
    end;

  for i := 0 to lst.Count - 1 do
    begin
      NM := lst[i] as TNumberModule;
      NM.DoChange;
    end;
  DisposeObject(lst);
end;

{ Triggers a change notification for every module in the pool. }
procedure TNumberModulePool.DoChangeAll;
begin
  FList.ProgressM(DoChangeAll_Progress);
end;

{
  * Loads the pool state from a stream.
  * Format: for each module: name, origin value, current value.
  * After loading, all modules are notified of the change.
}
procedure TNumberModulePool.LoadFromStream(stream: TCore_Stream);
var
  D: TDFE;
  NM: TNumberModule;
  n: SystemString;
  lst: TCore_ListForObj;
  i: Integer;
begin
  // format
  // name,current Value,origin Value
  lst := TCore_ListForObj.Create;
  D := TDFE.Create;
  D.DecodeFrom(stream);
  while not D.Reader.IsEnd do
    begin
      n := D.Reader.ReadString;
      NM := GetItems(n);
      NM.DirectOrigin := D.Reader.ReadVariant;
      NM.DirectValue := D.Reader.ReadVariant;
      lst.Add(NM);
    end;
  DisposeObject(D);
  for i := 0 to lst.Count - 1 do
    begin
      NM := TNumberModule(lst[i]);
      NM.DoChange;
    end;
  DisposeObject(lst);
end;

{
  * Saves the pool state to a stream.
  * Format: for each module: name, origin value, current value.
}
procedure TNumberModulePool.SaveToStream(stream: TCore_Stream);
var
  D: TDFE;
  lst: TCore_ListForObj;
  i: Integer;
  NM: TNumberModule;
begin
  // format
  // name,current Value,origin Value
  lst := TCore_ListForObj.Create;
  FList.GetAsList(lst);
  D := TDFE.Create;
  for i := 0 to lst.Count - 1 do
    begin
      NM := TNumberModule(lst[i]);
      D.WriteString(NM.Name);
      D.WriteVariant(NM.Origin);
      D.WriteVariant(NM.Value);
    end;
  D.FastEncodeTo(stream);
  DisposeObject(D);
  DisposeObject(lst);
end;

{
  * Returns a module by name, creating it if it does not exist.
  * The module is also registered in the expression runtime if it already exists.
}
function TNumberModulePool.GetItems(Name_: SystemString): TNumberModule;
begin
  Result := FList[Name_];
  if Result = nil then
    begin
      Result := TNumberModule.Create(Self);
      FList.FastAdd(Name_, Result);
      Result.FName := Name_;
      if FExpOpRunTime <> nil then
          Result.DoRegOpProc;
      FIsChanged := True;
    end;
end;

{
  * Rebuilds the expression runtime by freeing and recreating it.
  * This forces re-registration of all modules.
}
procedure TNumberModulePool.RebuildOpRunTime;
begin
  DisposeObjectAndNil(FExpOpRunTime);
end;

{
  * Checks if an expression is a vector (contains comma separators).
  * Uses the expression parser's vector detection.
}
function TNumberModulePool.IsVectorScript(ExpressionText_: SystemString; TS_: TTextStyle): Boolean;
begin
  try
      Result := IsSymbolVectorExpression(ExpressionText_, TS_, nil);
  except
      Result := False;
  end;
end;

{ Overloaded version using Pascal text style. }
function TNumberModulePool.IsVectorScript(ExpressionText_: SystemString): Boolean;
begin
  Result := IsVectorScript(ExpressionText_, tsPascal);
end;

{
  * Evaluates a single expression using the pool's runtime.
  * Returns the result as a Variant.
}
function TNumberModulePool.RunScript(ExpressionText_: SystemString; TS_: TTextStyle): Variant;
begin
  try
      Result := EvaluateExpressionValue(True, TS_, ExpressionText_, ExpOpRunTime);
  except
      Result := NULL;
  end;
end;

{ Overloaded version using Pascal text style. }
function TNumberModulePool.RunScript(ExpressionText_: SystemString): Variant;
begin
  Result := RunScript(ExpressionText_, tsPascal);
end;

{
  * Evaluates a vector expression (comma-separated sub-expressions).
  * Returns an array of Variant results.
}
function TNumberModulePool.RunVectorScript(ExpressionText_: SystemString; TS_: TTextStyle): TExpressionValueVector;
begin
  try
      Result := EvaluateExpressionVector(False, True, nil, TS_, ExpressionText_, ExpOpRunTime, nil);
  except
      SetLength(Result, 0);
  end;
end;

{ Overloaded version using Pascal text style. }
function TNumberModulePool.RunVectorScript(ExpressionText_: SystemString): TExpressionValueVector;
begin
  Result := RunVectorScript(ExpressionText_, tsPascal);
end;

{
  * Unit test for the Number Module system.
  * Demonstrates creation, value assignment, script execution, and vector scripts.
}
class procedure TNumberModulePool.test;
var
  NMPool: TNumberModulePool;
begin
  NMPool := TNumberModulePool.Create;
  NMPool['a'].Origin := 33.14;
  NMPool['b'].Origin := 100;
  NMPool['c'].Origin := 200;
  NMPool['e'].Origin := 0;
  NMPool.RunScript('e(a+b+c)');

  DoStatus('NM test: %s', [VarToStr(NMPool.RunScript('a(a*100)*b+c', tsPascal))]);
  DoStatus('NM test: %s', [VarToStr(NMPool.RunScript('a(33.14)', tsPascal))]);
  DoStatus('NM vector test: %s', [ExpressionValueVectorToStr(NMPool.RunVectorScript('a(a*100)*b+c, a*c+99,e', tsPascal)).Text]);
  DisposeObject(NMPool);
end;

end.

{ ******************************************************************************
  * Z.Notify – Lightweight Time-Driven Task Scheduling Engine                  *
  *                                                                            *
  * This unit provides a flexible, high-level task scheduler for delayed       *
  * execution of procedures, methods, or anonymous callbacks.  It is built     *
  * on top of the Z-framework's core threading and timing infrastructure,      *
  * offering a simple yet powerful way to schedule one-shot tasks with         *
  * configurable delays.                                                       *
  *                                                                            *
  * Core Features:                                                             *
  *   - Delayed Execution: Schedule any callback to run after a specified      *
  *     number of seconds (floating-point precision).                          *
  *   - Multiple Callback Styles: Supports procedural (C), method-of-object    *
  *     (M), and anonymous/nested (P) callbacks, each with or without a        *
  *     sender parameter.                                                      *
  *   - Automatic Object Lifetime Management: Tasks can carry a pool of        *
  *     objects that are automatically freed after the task executes,          *
  *     simplifying resource cleanup.                                          *
  *   - Embedded Data Container: Each task includes a TDFE (Data Frame         *
  *     Engine) instance, allowing arbitrary structured data to be passed to   *
  *     the callback.                                                          *
  *   - FIFO Execution: Tasks are executed in the order they become ready.     *
  *   - Pause/Resume: The scheduler can be paused globally, suspending all     *
  *     pending tasks.                                                         *
  *   - Thread-Safe Design: The internal task queue is protected by a          *
  *     critical section, making it safe for use in multi-threaded             *
  *     environments (though tasks are executed in the caller's thread).       *
  *   - Global System Scheduler: A ready-to-use global instance is provided    *
  *     and automatically progresses during the main thread's synchronisation  *
  *     check, making it trivial to integrate into any application.            *
  *   - Optional Debug Tracking: When enabled, delayed object freeing is       *
  *     logged to the status console, aiding in debugging object lifetimes.    *
  *                                                                            *
  * Architecture:                                                              *
  *   The scheduler (TN_Progress_Tool) maintains a queue of tasks              *
  *   (TN_Post_Execute).  Each task stores a delay, an accumulated time        *
  *   counter, a callback, and optional user data.  The user repeatedly        *
  *   calls Progress(deltaTime) to advance time; when a task's accumulated     *
  *   time reaches its delay, the callback is executed and the task is         *
  *   automatically removed and freed.                                         *
  *                                                                            *
  *   The TCadencer_N_Progress_Tool variant integrates an internal TCadencer   *
  *   timer, removing the need for manual deltaTime calculations – it          *
  *   drives itself when its Progress() method is called.                      *
  *                                                                            *
  * Use Cases:                                                                 *
  *   - Game development: schedule power-ups, AI reactions, or animation       *
  *     events after a delay.                                                  *
  *   - UI applications: defer updates, tooltips, or notifications.            *
  *   - Network services: implement timeouts, retries, or heartbeat tasks.     *
  *   - General automation: run cleanup routines, periodic checks, or          *
  *     deferred initialisation.                                               *
  *                                                                            *
  * Example (using the global scheduler):                                      *
  *   begin                                                                    *
  *     // Schedule a simple procedure to run after 2.5 seconds                *
  *     SysPost.PostExecuteC_NP(2.5,                                           *
  *       procedure                                                            *
  *       begin                                                                *
  *         DoStatus('Delayed task executed!');                                *
  *       end                                                                  *
  *     );                                                                     *
  *     // In your main loop, call SysPost.Progress; or rely on the            *
  *     // automatic hook in Z.Core.OnCheckThreadSynchronize.                  *
  *   end;                                                                     *
  *                                                                            *
  * The global instance (SystemPostProgress) is automatically progressed       *
  * during Z.Core's thread synchronisation hook, so in most applications       *
  * you don't even need to call Progress() manually – it just works.           *
  *                                                                            *
  * Dependencies:                                                              *
  *   - Z.Core          : For threading, critical sections, and object disposal*
  *   - Z.DFE           : For the embedded data container in each task.        *
  *   - Z.Cadencer      : For the integrated timer in TCadencer_N_Progress_Tool*
  *   - Z.PascalStrings : For string handling.                                 *
  *                                                                            *
  * This unit is a fundamental building block for any application that         *
  * requires simple, reliable delayed execution without the overhead of        *
  * a full-featured job scheduler.                                             *
  **************************************************************************** }
unit Z.Notify;

{$DEFINE FPC_DELPHI_MODE}
{$I Z.Define.inc}

interface

uses
  SysUtils, Classes, Variants,
{$IFDEF FPC}
  Z.FPC.GenericList,
{$ENDIF FPC}
  Z.Core, Z.PascalStrings, Z.UPascalStrings, Z.DFE, Z.Cadencer;

type
  { Forward declarations for mutually dependent types }
  TN_Progress_Tool = class;
  TN_Post_Execute = class;
  TNProgressPost = TN_Progress_Tool;
  TNPostExecute = TN_Post_Execute;

  {
    * Callback signatures for TN_Post_Execute tasks.
    * Three styles are provided:
    *   C  – plain procedural (standalone function or class static method)
    *   M  – object method (of object)
    *   P  – anonymous or nested procedure (reference to procedure or is nested)
    * Each style has a version that receives the sender (the task itself) and
    * a version that takes no parameters (NP = No Parameters).
    *
    * @Example C style with sender:
    *   procedure MyCallback(Sender: TN_Post_Execute);
    *   begin
    *     DoStatus('Task executed!');
    *   end;
    *
    * @Example M style (method of object):
    *   procedure TMyClass.MyMethod(Sender: TN_Post_Execute);
    *   begin
    *     FValue := FValue + 1;
    *   end;
    *
    * @Example P style (anonymous) with sender:
    *   PostExec := PostTool.PostExecuteP(1.0,
    *     procedure(Sender: TN_Post_Execute)
    *     begin
    *       DoStatus('Anonymous task run');
    *     end
    *   );
  }
  TN_Post_Execute_C = procedure(Sender: TN_Post_Execute); // Procedural with sender
  TN_Post_Execute_C_NP = procedure(); // Procedural without sender (NP)
  TN_Post_Execute_M = procedure(Sender: TN_Post_Execute) of object; // Object method with sender
  TN_Post_Execute_M_NP = procedure() of object; // Object method without sender
{$IFDEF FPC}
  TN_Post_Execute_P = procedure(Sender: TN_Post_Execute) is nested; // Nested procedure with sender
  TN_Post_Execute_P_NP = procedure() is nested; // Nested procedure without sender
{$ELSE FPC}
  TN_Post_Execute_P = reference to procedure(Sender: TN_Post_Execute); // Reference to procedure with sender
  TN_Post_Execute_P_NP = reference to procedure(); // Reference to procedure without sender
{$ENDIF FPC}
  {
    * TN_Post_Execute_List_Struct is a thread-safe list that manages
    * TN_Post_Execute instances.  It extends TCritical_BigList to provide
    * lock-protected operations, making it safe for use in multi-threaded
    * environments.
  }
  TN_Post_Execute_List_Struct = TCritical_BigList<TN_Post_Execute>;

  {
    * TN_Post_Execute_Temp_Order_Struct is a temporary FIFO queue used
    * internally during the execution phase of Progress().  It holds
    * tasks that are ready to be executed, allowing the scheduler to
    * process them in order without interference from the main pool.
  }
  TN_Post_Execute_Temp_Order_Struct = TOrderStruct<TN_Post_Execute>;

  {
    * TN_FreeMemory_Pool is a simple FIFO queue that stores pointers to
    * memory blocks that should be freed after a task completes.
  }
  TN_FreeMemory_Pool = class(TOrderStruct<Pointer>)
  public
    procedure DoFree(var Data: Pointer); override;
  end;

{$IFDEF Tracking_Dealy_Free_Object}

  {
    * When Tracking_Dealy_Free_Object is defined, this pool overrides
    * DoAdd to log each object that is scheduled for delayed freeing.
    * This is useful for debugging object lifetimes and detecting leaks.
  }
  TN_Post_Execute_Auto_Free_Pool_ = TCritical_Big_Object_List<TObject>;

  TN_Post_Execute_Auto_Free_Pool = class(TN_Post_Execute_Auto_Free_Pool_)
  public
    procedure DoAdd(var Data: TObject); override;
  end;
{$ELSE Tracking_Dealy_Free_Object}

  {
    * When tracking is disabled, the pool is a simple thread-safe list
    * of TObject without any logging overhead.
  }
  TN_Post_Execute_Auto_Free_Pool = TCritical_Big_Object_List<TObject>;
{$ENDIF Tracking_Dealy_Free_Object}

  {
    * TN_Post_Execute represents a single delayed execution task.
    * It encapsulates a callback (in one of three styles), a delay time,
    * optional data (via TDFE), and a pool of objects to be freed after
    * execution.
    *
    * Lifecycle:
    *   1. Create via TN_Progress_Tool.PostExecute* methods.
    *   2. Optionally set DataEng, Data1-Data5, Delay, and callbacks.
    *   3. Call Ready() to mark the task as ready for scheduling.
    *   4. The owner's Progress() method accumulates time; when
    *      NewTime >= Delay, Execute() is called.
    *   5. After Execute() returns, the task is automatically freed.
    *
    * The IsRuning and IsExit flags are useful for external synchronisation,
    * e.g., a worker thread can wait for a task to finish.
    *
    * @Example:
    *   var Task: TN_Post_Execute;
    *   begin
    *     Task := MyProgressTool.PostExecute(False, 2.5);
    *     Task.OnExecute_C := MyCallback;
    *     Task.Data1 := SomeObject;
    *     Task.Ready;   // Now the task will be executed after 2.5 seconds.
    *   end;
  }
  TN_Post_Execute = class(TCore_Object_Intermediate)
  private
    FOwner: TN_Progress_Tool; // The progress tool that owns this task
    FPool_Data_Ptr: TN_Post_Execute_List_Struct.PQueueStruct; // Pointer to the task's node in the queue
    FDFE_Inst: TDFE; // Data frame engine for arbitrary data
    FNewTime: Double; // Accumulated elapsed time since Ready()
    FIsRuning, FIsExit: PBoolean; // External synchronisation flags
    FIsReady: Boolean; // True when the task is ready to be scheduled
    FDiscard: Boolean; // If True, the task will be skipped on execution
    procedure SetIsExit(const Value: PBoolean);
    procedure SetIsRuning(const Value: PBoolean);
  public
    Info: SystemString; // Descriptive debug info
    Data1: TCore_Object; // User data object 1
    Data2: TCore_Object; // User data object 2
    Data3: Variant; // User data variant 1
    Data4: Variant; // User data variant 2
    Data5: Pointer; // User data pointer
    Delay: Double; // Delay in seconds before execution
    Auto_Free_Pool: TN_Post_Execute_Auto_Free_Pool; // Objects to be freed after execution
    Auto_Free_Memory: TN_FreeMemory_Pool; // Memory pointers to be freed after execution

    { Callbacks – only one of these should be assigned }
    OnExecute_C: TN_Post_Execute_C;
    OnExecute_C_NP: TN_Post_Execute_C_NP;
    OnExecute_M: TN_Post_Execute_M;
    OnExecute_M_NP: TN_Post_Execute_M_NP;
    OnExecute_P: TN_Post_Execute_P;
    OnExecute_P_NP: TN_Post_Execute_P_NP;

    property DataEng: TDFE read FDFE_Inst; // Access to the internal TDFE
    property DFE_Inst: TDFE read FDFE_Inst; // Alias
    property Owner: TN_Progress_Tool read FOwner; // The owning progress tool
    property IsRuning: PBoolean read FIsRuning write SetIsRuning; // Set to True before execution, False after
    property IsExit: PBoolean read FIsExit write SetIsExit; // Set to True after execution
    property IsReady: Boolean read FIsReady; // True if Ready() has been called
    property NewTime: Double read FNewTime; // Accumulated time since Ready()

    constructor Create; virtual;
    destructor Destroy; override;

    {
      * Executes the task.  If a callback is assigned, it is invoked.
      * The internal TDFE is reset to position 0 before execution.
      * After execution, IsRuning is set to False and IsExit to True.
      *
      * @Example:
      *   MyTask.Execute;   // Manually run the task (normally called by the scheduler)
    }
    procedure Execute; virtual;

    {
      * Marks the task as ready for scheduling.  After calling Ready,
      * the task will begin accumulating time in the next Progress() call.
      * Once NewTime reaches Delay, Execute() will be invoked.
    }
    procedure Ready;

    {
      * Marks the task to be discarded.  When its turn comes, it will be
      * skipped and immediately freed without executing any callback.
    }
    procedure DoDiscard;
  end;

  { Meta-class for TN_Post_Execute, used for dynamic instantiation. }
  TN_Post_ExecuteClass = class of TN_Post_Execute;

  {
    * TN_Progress_Tool is the core task scheduler.  It manages a queue of
    * TN_Post_Execute tasks and drives their execution through repeated
    * calls to Progress(deltaTime).
    *
    * The scheduler is single-thread friendly: all tasks are executed
    * in the same thread that calls Progress(), typically the main thread.
    *
    * Tasks are executed in FIFO order.  If a task has a delay, it remains
    * in the queue until the accumulated time reaches the delay.
    *
    * @Example:
    *   var Progress: TN_Progress_Tool;
    *   begin
    *     Progress := TN_Progress_Tool.Create;
    *     // Schedule a task after 5 seconds
    *     Progress.PostExecuteC(5.0, MyCallback);
    *     // In the main loop:
    *     while Running do
    *     begin
    *       Progress.Progress(DeltaTime);
    *       Sleep(10);
    *     end;
    *   end;
  }
  TN_Progress_Tool = class(TCore_InterfacedObject_Intermediate)
  protected
    FPostIsRunning: Boolean; // Prevents re-entrant progress
    FPostExecute_Pool: TN_Post_Execute_List_Struct; // Queue of all tasks
    FPostClass: TN_Post_ExecuteClass; // Class used to create new tasks
    FBusy: Boolean; // True during task execution
    FCurrentExecute: TN_Post_Execute; // The currently executing task
    FPaused: Boolean; // If True, Progress() does nothing
    procedure Do_Free(var Inst_: TN_Post_Execute);
  public
    constructor Create;
    destructor Destroy; override;

    { Clears all pending tasks. }
    procedure ResetPost;
    procedure Clear;
    procedure Clean;

    { ----- Task Creation (PostExecute overloads) ----- }
    { All methods return a TN_Post_Execute instance.  The caller can further
      configure it (set callbacks, data, etc.) before calling Ready. }

    { Basic creation }
    function PostExecute(ready_: Boolean): TN_Post_Execute; overload;
    function PostExecute(ready_: Boolean; DataEng: TDFE): TN_Post_Execute; overload;
    function PostExecute(ready_: Boolean; Delay: Double): TN_Post_Execute; overload;
    function PostExecute(ready_: Boolean; Delay: Double; DataEng: TDFE): TN_Post_Execute; overload;

    { backcall-style callbacks (procedural) }
    function PostExecuteC(DataEng: TDFE; OnExecute_C: TN_Post_Execute_C): TN_Post_Execute; overload;
    function PostExecuteC(Delay: Double; DataEng: TDFE; OnExecute_C: TN_Post_Execute_C): TN_Post_Execute; overload;
    function PostExecuteC(Delay: Double; OnExecute_C: TN_Post_Execute_C): TN_Post_Execute; overload;
    function PostExecuteC_NP(Delay: Double; OnExecute_C: TN_Post_Execute_C_NP): TN_Post_Execute; overload;
    function PostExecuteC(ready_: Boolean; DataEng: TDFE; OnExecute_C: TN_Post_Execute_C): TN_Post_Execute; overload;
    function PostExecuteC(ready_: Boolean; Delay: Double; DataEng: TDFE; OnExecute_C: TN_Post_Execute_C): TN_Post_Execute; overload;
    function PostExecuteC(ready_: Boolean; Delay: Double; OnExecute_C: TN_Post_Execute_C): TN_Post_Execute; overload;
    function PostExecuteC_NP(ready_: Boolean; Delay: Double; OnExecute_C: TN_Post_Execute_C_NP): TN_Post_Execute; overload;

    { object method-style callbacks (methods of object) }
    function PostExecuteM(DataEng: TDFE; OnExecute_M: TN_Post_Execute_M): TN_Post_Execute; overload;
    function PostExecuteM(Delay: Double; DataEng: TDFE; OnExecute_M: TN_Post_Execute_M): TN_Post_Execute; overload;
    function PostExecuteM(Delay: Double; OnExecute_M: TN_Post_Execute_M): TN_Post_Execute; overload;
    function PostExecuteM_NP(Delay: Double; OnExecute_M: TN_Post_Execute_M_NP): TN_Post_Execute; overload;
    function PostExecuteM(ready_: Boolean; DataEng: TDFE; OnExecute_M: TN_Post_Execute_M): TN_Post_Execute; overload;
    function PostExecuteM(ready_: Boolean; Delay: Double; DataEng: TDFE; OnExecute_M: TN_Post_Execute_M): TN_Post_Execute; overload;
    function PostExecuteM(ready_: Boolean; Delay: Double; OnExecute_M: TN_Post_Execute_M): TN_Post_Execute; overload;
    function PostExecuteM_NP(ready_: Boolean; Delay: Double; OnExecute_M: TN_Post_Execute_M_NP): TN_Post_Execute; overload;

    { anonymous/nested-style callbacks (anonymous/nested procedures) }
    function PostExecuteP(DataEng: TDFE; OnExecute_P: TN_Post_Execute_P): TN_Post_Execute; overload;
    function PostExecuteP(Delay: Double; DataEng: TDFE; OnExecute_P: TN_Post_Execute_P): TN_Post_Execute; overload;
    function PostExecuteP(Delay: Double; OnExecute_P: TN_Post_Execute_P): TN_Post_Execute; overload;
    function PostExecuteP_NP(Delay: Double; OnExecute_P: TN_Post_Execute_P_NP): TN_Post_Execute; overload;
    function PostExecuteP(ready_: Boolean; DataEng: TDFE; OnExecute_P: TN_Post_Execute_P): TN_Post_Execute; overload;
    function PostExecuteP(ready_: Boolean; Delay: Double; DataEng: TDFE; OnExecute_P: TN_Post_Execute_P): TN_Post_Execute; overload;
    function PostExecuteP(ready_: Boolean; Delay: Double; OnExecute_P: TN_Post_Execute_P): TN_Post_Execute; overload;
    function PostExecuteP_NP(ready_: Boolean; Delay: Double; OnExecute_P: TN_Post_Execute_P_NP): TN_Post_Execute; overload;

    { ----- Delayed Object Freeing ----- }
    {
      * Schedules objects to be freed after the specified delay.
      * Objects are added to the task's Auto_Free_Pool and are freed
      * after the task executes.
      *
      * @Example:
      *   Progress.PostDelayFreeObject(2.0, [MyObj1, MyObj2]);
      *   // After 2 seconds, both objects will be freed.
    }
    procedure PostDelayFreeObject(Delay: Double; Arry: array of TCore_Object); overload;
    procedure PostDelayFreeObject(Delay: Double; Obj1_, Obj2_, Obj3_, Obj4_: TCore_Object); overload;
    procedure PostDelayFreeObject(Delay: Double; Obj1_, Obj2_, Obj3_: TCore_Object); overload;
    procedure PostDelayFreeObject(Delay: Double; Obj1_, Obj2_: TCore_Object); overload;
    procedure PostDelayFreeObject(Delay: Double; Obj1_: TCore_Object); overload;

    procedure PostDelayFreeMemory(Delay: Double; Arry: array of Pointer); overload;
    procedure PostDelayFreeMemory(Delay: Double; p1_, p2_, p3_, p4_: Pointer); overload;
    procedure PostDelayFreeMemory(Delay: Double; p1_, p2_, p3_: Pointer); overload;
    procedure PostDelayFreeMemory(Delay: Double; p1_, p2_: Pointer); overload;
    procedure PostDelayFreeMemory(Delay: Double; p1_: Pointer); overload;

    { Removes a task from the queue and frees it immediately. }
    procedure Remove(Inst_: TN_Post_Execute); overload; virtual;

    { ----- Progress and State ----- }
    {
      * Advances the scheduler by deltaTime seconds.  All ready tasks have their
      * NewTime incremented.  Tasks whose NewTime >= Delay are executed.
      * This method should be called regularly from the main loop.
      *
      * @param deltaTime The elapsed time in seconds since the last call.
    }
    procedure Progress(deltaTime: Double); overload;

    { If True, Progress() does nothing.  Useful for temporarily suspending tasks. }
    property Paused: Boolean read FPaused write FPaused;

    { True if a task is currently executing. }
    property Busy: Boolean read FBusy;

    { The currently executing task (if any). }
    property CurrentExecute: TN_Post_Execute read FCurrentExecute;

    { The class used to create new task instances.  Can be overridden for custom tasks. }
    property PostClass: TN_Post_ExecuteClass read FPostClass write FPostClass;
  end;

  {
    * TCadencer_N_Progress_Tool extends TN_Progress_Tool with an internal
    * TCadencer timer.  Instead of requiring external calls to Progress(deltaTime),
    * it automatically drives progress using the timer's OnProgress event.
    *
    * This is the recommended scheduler for most applications as it integrates
    * seamlessly with the Z-framework's timing system.
    *
    * @Example:
    *   var Scheduler: TCadencer_N_Progress_Tool;
    *   begin
    *     Scheduler := TCadencer_N_Progress_Tool.Create;
    *     Scheduler.PostExecuteC(2.0, MyCallback);
    *     // In the main loop:
    *     while Running do
    *     begin
    *       Scheduler.Progress;   // Automatically uses internal timer
    *       Sleep(10);
    *     end;
    *   end;
  }
  TCadencer_N_Progress_Tool = class(TN_Progress_Tool, ICadencerProgressInterface)
  protected
    FCadencerEngine: TCadencer;
    procedure CadencerProgress(const deltaTime, NewTime: Double);
  public
    constructor Create;
    destructor Destroy; override;

    { Drives the internal timer.  This method must be called in the main loop. }
    procedure Progress; overload;

    property CadencerEngine: TCadencer read FCadencerEngine;
  end;

  { Type aliases for convenience }
  TN_Progress_ToolWithCadencer = TCadencer_N_Progress_Tool;
  TCadencerPost = TCadencer_N_Progress_Tool;
  TCadencerNProgressPost = TCadencer_N_Progress_Tool;
  TNProgressPostWithCadencer = TCadencerNProgressPost;

var
  {
    * Global system-wide progress tool.  This instance is automatically
    * hooked into Z.Core.OnCheckThreadSynchronize and will progress during
    * the main thread's synchronisation check.
    *
    * Use SysPostProgress() or SysPost() to access it.
  }
  SystemPostProgress: TCadencer_N_Progress_Tool;

  { If True, delayed free operations will print debug information to the status console. }
  Print_Tracking_Delay_Free: Boolean;

  { ---------- Global Helper Functions ---------- }

  { Returns the global system progress tool. }
function SysPostProgress: TCadencer_N_Progress_Tool;

{ Alias for SysPostProgress. }
function SysPost: TCadencer_N_Progress_Tool;

{
  * Schedules one or two objects for delayed freeing using the global
  * system scheduler.
  *
  * @Example:
  *   DelayFreeObject(5.0, MyObject);   // Free MyObject after 5 seconds.
}
procedure DelayFreeObject(Delay: Double; Obj1_, Obj2_: TCore_Object); overload;
procedure DelayFreeObject(Delay: Double; Obj1_: TCore_Object); overload;
{ Alias for DelayFreeObject. }
procedure DelayFreeObj(Delay: Double; Obj1_, Obj2_: TCore_Object); overload;
procedure DelayFreeObj(Delay: Double; Obj1_: TCore_Object); overload;

procedure DelayFreeMemory(Delay: Double; p1, p2, p3, p4: Pointer); overload;
procedure DelayFreeMemory(Delay: Double; p1, p2, p3: Pointer); overload;
procedure DelayFreeMemory(Delay: Double; p1, p2: Pointer); overload;
procedure DelayFreeMemory(Delay: Double; p1: Pointer); overload;

procedure DelayFreeMem(Delay: Double; p1, p2, p3, p4: Pointer); overload;
procedure DelayFreeMem(Delay: Double; p1, p2, p3: Pointer); overload;
procedure DelayFreeMem(Delay: Double; p1, p2: Pointer); overload;
procedure DelayFreeMem(Delay: Double; p1: Pointer); overload;

{ alloc and delay free }
function DelayFreeGetMem(Delay: Double; Size: NativeInt): Pointer;
function DelayGetMem(Delay: Double; Size: NativeInt): Pointer;

implementation

uses Z.Status, Z.UnicodeMixedLib;

var
  Hooked_OnCheckThreadSynchronize: TOn_Check_Thread_Synchronize;

  {
    * Hook callback installed into Z.Core.OnCheckThreadSynchronize.
    * It calls the previously installed hook (if any) and then progresses
    * the global SystemPostProgress scheduler.
  }
procedure DoCheckThreadSynchronize();
begin
  if Assigned(Hooked_OnCheckThreadSynchronize) then
    begin
      try
          Hooked_OnCheckThreadSynchronize();
      except
      end;
    end;
  SystemPostProgress.Progress;
end;

{ Returns the global system progress tool instance. }
function SysPostProgress: TCadencer_N_Progress_Tool;
begin
  Result := SystemPostProgress;
end;

{ Alias for SysPostProgress. }
function SysPost: TCadencer_N_Progress_Tool;
begin
  Result := SystemPostProgress;
end;

{ Schedules two objects for delayed freeing using the global scheduler. }
procedure DelayFreeObject(Delay: Double; Obj1_, Obj2_: TCore_Object);
begin
  SystemPostProgress.PostDelayFreeObject(Delay, Obj1_, Obj2_);
end;

{ Schedules one object for delayed freeing. }
procedure DelayFreeObject(Delay: Double; Obj1_: TCore_Object);
begin
  SystemPostProgress.PostDelayFreeObject(Delay, Obj1_, nil);
end;

{ Alias for DelayFreeObject with two objects. }
procedure DelayFreeObj(Delay: Double; Obj1_, Obj2_: TCore_Object);
begin
  SystemPostProgress.PostDelayFreeObject(Delay, Obj1_, Obj2_);
end;

{ Alias for DelayFreeObject with one object. }
procedure DelayFreeObj(Delay: Double; Obj1_: TCore_Object);
begin
  SystemPostProgress.PostDelayFreeObject(Delay, Obj1_, nil);
end;

procedure DelayFreeMemory(Delay: Double; p1, p2, p3, p4: Pointer);
begin
  SystemPostProgress.PostDelayFreeMemory(Delay, p1, p2, p3, p4);
end;

procedure DelayFreeMemory(Delay: Double; p1, p2, p3: Pointer);
begin
  SystemPostProgress.PostDelayFreeMemory(Delay, p1, p2, p3);
end;

procedure DelayFreeMemory(Delay: Double; p1, p2: Pointer);
begin
  SystemPostProgress.PostDelayFreeMemory(Delay, p1, p2);
end;

procedure DelayFreeMemory(Delay: Double; p1: Pointer);
begin
  SystemPostProgress.PostDelayFreeMemory(Delay, p1);
end;

procedure DelayFreeMem(Delay: Double; p1, p2, p3, p4: Pointer);
begin
  SystemPostProgress.PostDelayFreeMemory(Delay, p1, p2, p3, p4);
end;

procedure DelayFreeMem(Delay: Double; p1, p2, p3: Pointer);
begin
  SystemPostProgress.PostDelayFreeMemory(Delay, p1, p2, p3);
end;

procedure DelayFreeMem(Delay: Double; p1, p2: Pointer);
begin
  SystemPostProgress.PostDelayFreeMemory(Delay, p1, p2);
end;

procedure DelayFreeMem(Delay: Double; p1: Pointer);
begin
  SystemPostProgress.PostDelayFreeMemory(Delay, p1);
end;

function DelayFreeGetMem(Delay: Double; Size: NativeInt): Pointer;
begin
  Result := GetMemory(Size);
  DelayFreeMem(Delay, Result);
end;

function DelayGetMem(Delay: Double; Size: NativeInt): Pointer;
begin
  Result := GetMemory(Size);
  DelayFreeMem(Delay, Result);
end;

procedure TN_FreeMemory_Pool.DoFree(var Data: Pointer);
begin
  try
      FreeMemory(Data);
  except
  end;
  Data := nil;
  inherited DoFree(Data);
end;

{$IFDEF Tracking_Dealy_Free_Object}


{
  * When tracking is enabled, this overridden DoAdd prints debug information
  * about the object being added to the free pool.
}
procedure TN_Post_Execute_Auto_Free_Pool.DoAdd(var Data: TObject);
begin
  inherited DoAdd(Data);
  if Data <> nil then
    begin
      try
        if Print_Tracking_Delay_Free then
            DoStatus('delay free Object: %s (0x%s)', [Data.ClassName, umlPointerToStr(Data).Text]);
      except
        on E: Exception do
          begin
            if Assigned(On_Raise_Info) then
                On_Raise_Info('delay free Object error ' + E.Message);
          end;
      end;
    end;
end;
{$ENDIF Tracking_Dealy_Free_Object}


{
  * Sets the IsExit pointer.  The referenced boolean is initialised to False.
}
procedure TN_Post_Execute.SetIsExit(const Value: PBoolean);
begin
  FIsExit := Value;
  if FIsExit <> nil then
      FIsExit^ := False;
end;

{
  * Sets the IsRuning pointer.  The referenced boolean is initialised to True.
}
procedure TN_Post_Execute.SetIsRuning(const Value: PBoolean);
begin
  FIsRuning := Value;
  if FIsRuning <> nil then
      FIsRuning^ := True;
end;

{
  * Constructor: initialises the task with default values.
  * Creates a TDFE instance and an Auto_Free_Pool.
}
constructor TN_Post_Execute.Create;
begin
  inherited Create;
  FOwner := nil;
  FPool_Data_Ptr := nil;

  FDFE_Inst := TDFE.Create;
  FNewTime := 0;
  Info := '';
  Data1 := nil;
  Data2 := nil;
  Data3 := Null;
  Data4 := Null;
  Data5 := nil;
  Delay := 0;
  Auto_Free_Pool := TN_Post_Execute_Auto_Free_Pool.Create(True);
  Auto_Free_Memory := TN_FreeMemory_Pool.Create;
  FIsRuning := nil;
  FIsExit := nil;
  FIsReady := False;
  FDiscard := False;

  OnExecute_C := nil;
  OnExecute_C_NP := nil;
  OnExecute_M := nil;
  OnExecute_M_NP := nil;
  OnExecute_P := nil;
  OnExecute_P_NP := nil;
end;

{
  * Destructor: cleans up the task and removes it from its owner's queue.
}
destructor TN_Post_Execute.Destroy;
begin
  if FOwner <> nil then
    begin
      if FOwner.FCurrentExecute = Self then
        begin
          FOwner.FCurrentExecute := nil;
        end;

      if FPool_Data_Ptr <> nil then
        begin
          FPool_Data_Ptr^.Data := nil;
          FOwner.FPostExecute_Pool.Remove_P(FPool_Data_Ptr);
        end;
      FOwner := nil;
    end;
  DisposeObject(FDFE_Inst);
  DisposeObject(Auto_Free_Pool);
  DisposeObject(Auto_Free_Memory);
  inherited Destroy;
end;

{
  * Executes the task.  The callback (whichever is assigned) is invoked.
  * The DFE is reset to position 0 before execution.
  * After execution, the IsRuning flag is set to False and IsExit to True.
}
procedure TN_Post_Execute.Execute;
begin
  if FIsRuning <> nil then
      FIsRuning^ := True;
  if FIsExit <> nil then
      FIsExit^ := False;

  if Assigned(OnExecute_C) then
    begin
      FDFE_Inst.Reader.index := 0;
      try
          OnExecute_C(Self);
      except
      end;
    end;

  if Assigned(OnExecute_C_NP) then
    begin
      FDFE_Inst.Reader.index := 0;
      try
          OnExecute_C_NP();
      except
      end;
    end;

  if Assigned(OnExecute_M) then
    begin
      FDFE_Inst.Reader.index := 0;
      try
          OnExecute_M(Self);
      except
      end;
    end;

  if Assigned(OnExecute_M_NP) then
    begin
      FDFE_Inst.Reader.index := 0;
      try
          OnExecute_M_NP();
      except
      end;
    end;

  if Assigned(OnExecute_P) then
    begin
      FDFE_Inst.Reader.index := 0;
      try
          OnExecute_P(Self);
      except
      end;
    end;
  if Assigned(OnExecute_P_NP) then
    begin
      FDFE_Inst.Reader.index := 0;
      try
          OnExecute_P_NP();
      except
      end;
    end;

  if FIsRuning <> nil then
      FIsRuning^ := False;
  if FIsExit <> nil then
      FIsExit^ := True;
end;

{ Marks the task as ready to be scheduled. }
procedure TN_Post_Execute.Ready;
begin
  FIsReady := True;
end;

{ Marks the task to be discarded (skipped on execution). }
procedure TN_Post_Execute.DoDiscard;
begin
  FDiscard := True;
end;

{
  * Free callback used by the pool to properly free a task instance.
}
procedure TN_Progress_Tool.Do_Free(var Inst_: TN_Post_Execute);
begin
  if Inst_ <> nil then
    begin
      Inst_.FPool_Data_Ptr := nil;
      DisposeObjectAndNil(Inst_);
    end;
end;

{
  * Constructor: initialises the scheduler with an empty pool and default
  * task class.
}
constructor TN_Progress_Tool.Create;
begin
  inherited Create;
  FPostIsRunning := False;
  FPostExecute_Pool := TN_Post_Execute_List_Struct.Create;
  FPostExecute_Pool.OnFree := Do_Free;
  FPostClass := TN_Post_Execute;
  FBusy := False;
  FCurrentExecute := nil;
  FPaused := False;
end;

{
  * Destructor: clears all pending tasks and frees the pool.
}
destructor TN_Progress_Tool.Destroy;
begin
  ResetPost;
  DisposeObject(FPostExecute_Pool);
  inherited Destroy;
end;

{ Removes all tasks from the pool. }
procedure TN_Progress_Tool.ResetPost;
begin
  FPostExecute_Pool.Clear;
end;

{ Alias for ResetPost. }
procedure TN_Progress_Tool.Clear;
begin
  ResetPost;
end;

{ Alias for ResetPost. }
procedure TN_Progress_Tool.Clean;
begin
  ResetPost;
end;

{ ----- Task Creation Overloads ----- }

{ Basic creation with optional immediate ready state. }
function TN_Progress_Tool.PostExecute(ready_: Boolean): TN_Post_Execute;
begin
  Result := FPostClass.Create;
  Result.FOwner := Self;
  Result.FPool_Data_Ptr := FPostExecute_Pool.Add(Result);
  if ready_ then
      Result.Ready;
end;

{ Creation with a data engine (copied into the task). }
function TN_Progress_Tool.PostExecute(ready_: Boolean; DataEng: TDFE): TN_Post_Execute;
begin
  Result := PostExecute(False);
  if DataEng <> nil then
      Result.FDFE_Inst.Assign(DataEng);
  if ready_ then
      Result.Ready;
end;

{ Creation with a delay. }
function TN_Progress_Tool.PostExecute(ready_: Boolean; Delay: Double): TN_Post_Execute;
begin
  Result := PostExecute(False);
  Result.Delay := Delay;
  if ready_ then
      Result.Ready;
end;

{ Creation with delay and data engine. }
function TN_Progress_Tool.PostExecute(ready_: Boolean; Delay: Double; DataEng: TDFE): TN_Post_Execute;
begin
  Result := PostExecute(False, Delay);
  if DataEng <> nil then
      Result.FDFE_Inst.Assign(DataEng);
  if ready_ then
      Result.Ready;
end;

{ ----- C-style callback creation (procedural) ----- }

function TN_Progress_Tool.PostExecuteC(DataEng: TDFE; OnExecute_C: TN_Post_Execute_C): TN_Post_Execute;
begin
  Result := PostExecute(False, DataEng);
  Result.OnExecute_C := OnExecute_C;
  Result.Ready;
end;

function TN_Progress_Tool.PostExecuteC(Delay: Double; DataEng: TDFE; OnExecute_C: TN_Post_Execute_C): TN_Post_Execute;
begin
  Result := PostExecute(False, Delay, DataEng);
  Result.OnExecute_C := OnExecute_C;
  Result.Ready;
end;

function TN_Progress_Tool.PostExecuteC(Delay: Double; OnExecute_C: TN_Post_Execute_C): TN_Post_Execute;
begin
  Result := PostExecute(False, Delay);
  Result.OnExecute_C := OnExecute_C;
  Result.Ready;
end;

function TN_Progress_Tool.PostExecuteC_NP(Delay: Double; OnExecute_C: TN_Post_Execute_C_NP): TN_Post_Execute;
begin
  Result := PostExecute(False, Delay);
  Result.OnExecute_C_NP := OnExecute_C;
  Result.Ready;
end;

function TN_Progress_Tool.PostExecuteC(ready_: Boolean; DataEng: TDFE; OnExecute_C: TN_Post_Execute_C): TN_Post_Execute;
begin
  Result := PostExecute(False, DataEng);
  Result.OnExecute_C := OnExecute_C;
  if ready_ then
      Result.Ready;
end;

function TN_Progress_Tool.PostExecuteC(ready_: Boolean; Delay: Double; DataEng: TDFE; OnExecute_C: TN_Post_Execute_C): TN_Post_Execute;
begin
  Result := PostExecute(False, Delay, DataEng);
  Result.OnExecute_C := OnExecute_C;
  if ready_ then
      Result.Ready;
end;

function TN_Progress_Tool.PostExecuteC(ready_: Boolean; Delay: Double; OnExecute_C: TN_Post_Execute_C): TN_Post_Execute;
begin
  Result := PostExecute(False, Delay);
  Result.OnExecute_C := OnExecute_C;
  if ready_ then
      Result.Ready;
end;

function TN_Progress_Tool.PostExecuteC_NP(ready_: Boolean; Delay: Double; OnExecute_C: TN_Post_Execute_C_NP): TN_Post_Execute;
begin
  Result := PostExecute(False, Delay);
  Result.OnExecute_C_NP := OnExecute_C;
  if ready_ then
      Result.Ready;
end;

{ ----- M-style callback creation (method of object) ----- }

function TN_Progress_Tool.PostExecuteM(DataEng: TDFE; OnExecute_M: TN_Post_Execute_M): TN_Post_Execute;
begin
  Result := PostExecute(False, DataEng);
  Result.OnExecute_M := OnExecute_M;
  Result.Ready;
end;

function TN_Progress_Tool.PostExecuteM(Delay: Double; DataEng: TDFE; OnExecute_M: TN_Post_Execute_M): TN_Post_Execute;
begin
  Result := PostExecute(False, Delay, DataEng);
  Result.OnExecute_M := OnExecute_M;
  Result.Ready;
end;

function TN_Progress_Tool.PostExecuteM(Delay: Double; OnExecute_M: TN_Post_Execute_M): TN_Post_Execute;
begin
  Result := PostExecute(False, Delay);
  Result.OnExecute_M := OnExecute_M;
  Result.Ready;
end;

function TN_Progress_Tool.PostExecuteM_NP(Delay: Double; OnExecute_M: TN_Post_Execute_M_NP): TN_Post_Execute;
begin
  Result := PostExecute(False, Delay);
  Result.OnExecute_M_NP := OnExecute_M;
  Result.Ready;
end;

function TN_Progress_Tool.PostExecuteM(ready_: Boolean; DataEng: TDFE; OnExecute_M: TN_Post_Execute_M): TN_Post_Execute;
begin
  Result := PostExecute(False, DataEng);
  Result.OnExecute_M := OnExecute_M;
  if ready_ then
      Result.Ready;
end;

function TN_Progress_Tool.PostExecuteM(ready_: Boolean; Delay: Double; DataEng: TDFE; OnExecute_M: TN_Post_Execute_M): TN_Post_Execute;
begin
  Result := PostExecute(False, Delay, DataEng);
  Result.OnExecute_M := OnExecute_M;
  if ready_ then
      Result.Ready;
end;

function TN_Progress_Tool.PostExecuteM(ready_: Boolean; Delay: Double; OnExecute_M: TN_Post_Execute_M): TN_Post_Execute;
begin
  Result := PostExecute(False, Delay);
  Result.OnExecute_M := OnExecute_M;
  if ready_ then
      Result.Ready;
end;

function TN_Progress_Tool.PostExecuteM_NP(ready_: Boolean; Delay: Double; OnExecute_M: TN_Post_Execute_M_NP): TN_Post_Execute;
begin
  Result := PostExecute(False, Delay);
  Result.OnExecute_M_NP := OnExecute_M;
  if ready_ then
      Result.Ready;
end;

{ ----- P-style callback creation (anonymous/nested) ----- }

function TN_Progress_Tool.PostExecuteP(DataEng: TDFE; OnExecute_P: TN_Post_Execute_P): TN_Post_Execute;
begin
  Result := PostExecute(False, DataEng);
  Result.OnExecute_P := OnExecute_P;
  Result.Ready;
end;

function TN_Progress_Tool.PostExecuteP(Delay: Double; DataEng: TDFE; OnExecute_P: TN_Post_Execute_P): TN_Post_Execute;
begin
  Result := PostExecute(False, Delay, DataEng);
  Result.OnExecute_P := OnExecute_P;
  Result.Ready;
end;

function TN_Progress_Tool.PostExecuteP(Delay: Double; OnExecute_P: TN_Post_Execute_P): TN_Post_Execute;
begin
  Result := PostExecute(False, Delay);
  Result.OnExecute_P := OnExecute_P;
  Result.Ready;
end;

function TN_Progress_Tool.PostExecuteP_NP(Delay: Double; OnExecute_P: TN_Post_Execute_P_NP): TN_Post_Execute;
begin
  Result := PostExecute(False, Delay);
  Result.OnExecute_P_NP := OnExecute_P;
  Result.Ready;
end;

function TN_Progress_Tool.PostExecuteP(ready_: Boolean; DataEng: TDFE; OnExecute_P: TN_Post_Execute_P): TN_Post_Execute;
begin
  Result := PostExecute(False, DataEng);
  Result.OnExecute_P := OnExecute_P;
  if ready_ then
      Result.Ready;
end;

function TN_Progress_Tool.PostExecuteP(ready_: Boolean; Delay: Double; DataEng: TDFE; OnExecute_P: TN_Post_Execute_P): TN_Post_Execute;
begin
  Result := PostExecute(False, Delay, DataEng);
  Result.OnExecute_P := OnExecute_P;
  if ready_ then
      Result.Ready;
end;

function TN_Progress_Tool.PostExecuteP(ready_: Boolean; Delay: Double; OnExecute_P: TN_Post_Execute_P): TN_Post_Execute;
begin
  Result := PostExecute(False, Delay);
  Result.OnExecute_P := OnExecute_P;
  if ready_ then
      Result.Ready;
end;

function TN_Progress_Tool.PostExecuteP_NP(ready_: Boolean; Delay: Double; OnExecute_P: TN_Post_Execute_P_NP): TN_Post_Execute;
begin
  Result := PostExecute(False, Delay);
  Result.OnExecute_P_NP := OnExecute_P;
  if ready_ then
      Result.Ready;
end;

{ ----- Delayed Object Freeing Methods ----- }

{
  * Schedules an array of objects to be freed after the specified delay.
}
procedure TN_Progress_Tool.PostDelayFreeObject(Delay: Double; Arry: array of TCore_Object);
var
  tmp: TN_Post_Execute;
  i: Integer;
begin
  tmp := PostExecute(False, Delay);
  for i := low(Arry) to high(Arry) do
    if Arry[i] <> nil then
        tmp.Auto_Free_Pool.Add(Arry[i]);
  tmp.Ready;
end;

{ Schedules up to four objects to be freed. }
procedure TN_Progress_Tool.PostDelayFreeObject(Delay: Double; Obj1_, Obj2_, Obj3_, Obj4_: TCore_Object);
var
  tmp: TN_Post_Execute;
begin
  tmp := PostExecute(False, Delay);
  if Obj1_ <> nil then
      tmp.Auto_Free_Pool.Add(Obj1_);
  if Obj2_ <> nil then
      tmp.Auto_Free_Pool.Add(Obj2_);
  if Obj3_ <> nil then
      tmp.Auto_Free_Pool.Add(Obj3_);
  if Obj4_ <> nil then
      tmp.Auto_Free_Pool.Add(Obj4_);
  tmp.Ready;
end;

{ Schedules up to three objects to be freed. }
procedure TN_Progress_Tool.PostDelayFreeObject(Delay: Double; Obj1_, Obj2_, Obj3_: TCore_Object);
var
  tmp: TN_Post_Execute;
begin
  tmp := PostExecute(False, Delay);
  if Obj1_ <> nil then
      tmp.Auto_Free_Pool.Add(Obj1_);
  if Obj2_ <> nil then
      tmp.Auto_Free_Pool.Add(Obj2_);
  if Obj3_ <> nil then
      tmp.Auto_Free_Pool.Add(Obj3_);
  tmp.Ready;
end;

{ Schedules two objects to be freed. }
procedure TN_Progress_Tool.PostDelayFreeObject(Delay: Double; Obj1_, Obj2_: TCore_Object);
var
  tmp: TN_Post_Execute;
begin
  tmp := PostExecute(False, Delay);
  if Obj1_ <> nil then
      tmp.Auto_Free_Pool.Add(Obj1_);
  if Obj2_ <> nil then
      tmp.Auto_Free_Pool.Add(Obj2_);
  tmp.Ready;
end;

{ Schedules one object to be freed. }
procedure TN_Progress_Tool.PostDelayFreeObject(Delay: Double; Obj1_: TCore_Object);
var
  tmp: TN_Post_Execute;
begin
  tmp := PostExecute(False, Delay);
  if Obj1_ <> nil then
      tmp.Auto_Free_Pool.Add(Obj1_);
  tmp.Ready;
end;

procedure TN_Progress_Tool.PostDelayFreeMemory(Delay: Double; Arry: array of Pointer);
var
  tmp: TN_Post_Execute;
  i: Integer;
begin
  tmp := PostExecute(False, Delay);
  for i := low(Arry) to high(Arry) do
    if Arry[i] <> nil then
        tmp.Auto_Free_Memory.Push(Arry[i]);
  tmp.Ready;
end;

procedure TN_Progress_Tool.PostDelayFreeMemory(Delay: Double; p1_, p2_, p3_, p4_: Pointer);
var
  tmp: TN_Post_Execute;
begin
  tmp := PostExecute(False, Delay);
  if p1_ <> nil then
      tmp.Auto_Free_Memory.Push(p1_);
  if p2_ <> nil then
      tmp.Auto_Free_Memory.Push(p2_);
  if p3_ <> nil then
      tmp.Auto_Free_Memory.Push(p3_);
  if p4_ <> nil then
      tmp.Auto_Free_Memory.Push(p4_);
  tmp.Ready;
end;

procedure TN_Progress_Tool.PostDelayFreeMemory(Delay: Double; p1_, p2_, p3_: Pointer);
var
  tmp: TN_Post_Execute;
begin
  tmp := PostExecute(False, Delay);
  if p1_ <> nil then
      tmp.Auto_Free_Memory.Push(p1_);
  if p2_ <> nil then
      tmp.Auto_Free_Memory.Push(p2_);
  if p3_ <> nil then
      tmp.Auto_Free_Memory.Push(p3_);
  tmp.Ready;
end;

procedure TN_Progress_Tool.PostDelayFreeMemory(Delay: Double; p1_, p2_: Pointer);
var
  tmp: TN_Post_Execute;
begin
  tmp := PostExecute(False, Delay);
  if p1_ <> nil then
      tmp.Auto_Free_Memory.Push(p1_);
  if p2_ <> nil then
      tmp.Auto_Free_Memory.Push(p2_);
  tmp.Ready;
end;

procedure TN_Progress_Tool.PostDelayFreeMemory(Delay: Double; p1_: Pointer);
var
  tmp: TN_Post_Execute;
begin
  tmp := PostExecute(False, Delay);
  if p1_ <> nil then
      tmp.Auto_Free_Memory.Push(p1_);
  tmp.Ready;
end;

{
  * Immediately removes a task from the queue and frees it.
  * @param Inst_ The task instance to remove.
}
procedure TN_Progress_Tool.Remove(Inst_: TN_Post_Execute);
begin
  DisposeObject(Inst_);
end;

{
  * Advances the scheduler by deltaTime seconds.
  * All ready tasks accumulate time; those whose NewTime >= Delay are
  * executed in FIFO order.  Executed tasks are automatically freed.
}
procedure TN_Progress_Tool.Progress(deltaTime: Double);
var
  tmp_Order: TN_Post_Execute_Temp_Order_Struct;

  procedure Do_Run;
  begin
    while tmp_Order.Num > 0 do
      begin
        FCurrentExecute := tmp_Order.First^.Data;
        if not FCurrentExecute.FDiscard then
          begin
            FBusy := True;
            try
                FCurrentExecute.Execute;
            except
            end;
            FBusy := False;
          end;
        DisposeObject(FCurrentExecute);
        tmp_Order.Next;
      end;
  end;

var
  __Repeat__: TN_Post_Execute_List_Struct.TRepeat___;
begin
  if FPaused then
      Exit;
  if FPostIsRunning then
      Exit;
  if FPostExecute_Pool.Num <= 0 then
      Exit;

  FPostIsRunning := True;

  tmp_Order := nil; // progress optimized
  try
    __Repeat__ := FPostExecute_Pool.Repeat_;
    repeat
      if __Repeat__.Queue^.Data.IsReady then
        begin
          __Repeat__.Queue^.Data.FNewTime := __Repeat__.Queue^.Data.FNewTime + deltaTime;
          if (__Repeat__.Queue^.Data.FNewTime >= __Repeat__.Queue^.Data.Delay) then
            begin
              if tmp_Order = nil then // progress optimized
                  tmp_Order := TN_Post_Execute_Temp_Order_Struct.Create;
              tmp_Order.Push(__Repeat__.Queue^.Data);
            end;
        end;
    until not __Repeat__.Next;
    if tmp_Order <> nil then // progress optimized
      begin
        Do_Run();
        tmp_Order.Free;
      end;
  finally
      FPostIsRunning := False;
  end;
end;

{
  * TCadencer_N_Progress_Tool – callback from the internal timer.
  * Forwards the deltaTime to the inherited Progress() method.
}
procedure TCadencer_N_Progress_Tool.CadencerProgress(const deltaTime, NewTime: Double);
begin
  inherited Progress(deltaTime);
end;

{ Constructor: creates the internal timer and sets the interface. }
constructor TCadencer_N_Progress_Tool.Create;
begin
  inherited Create;
  FCadencerEngine := TCadencer.Create;
  FCadencerEngine.OnProgressInterface := Self;
end;

{ Destructor: clears the timer interface and frees the engine. }
destructor TCadencer_N_Progress_Tool.Destroy;
begin
  FCadencerEngine.OnProgressInterface := nil;
  DisposeObject(FCadencerEngine);
  inherited Destroy;
end;

{ Drives the internal timer. }
procedure TCadencer_N_Progress_Tool.Progress;
begin
  FCadencerEngine.Progress;
end;

initialization

{ Save the original OnCheckThreadSynchronize hook and install ours. }
Hooked_OnCheckThreadSynchronize := Z.Core.OnCheckThreadSynchronize;
Z.Core.OnCheckThreadSynchronize := DoCheckThreadSynchronize;
SystemPostProgress := TCadencer_N_Progress_Tool.Create;
Print_Tracking_Delay_Free := False;

finalization

{ Restore the original hook and free the global scheduler. }
Z.Core.OnCheckThreadSynchronize := Hooked_OnCheckThreadSynchronize;
DisposeObject(SystemPostProgress);

end.

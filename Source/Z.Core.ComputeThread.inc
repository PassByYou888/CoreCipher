{ *
  * Z.Core.ComputeThread.inc
  * ------------------------
  * Core thread-pool and task-dispatch subsystem for the Z framework.
  *
  * This file implements a self-scaling thread pool (TCompute workers) and a
  * central dispatcher thread that schedules asynchronous tasks posted via
  * TCompute.Run* methods. It is designed for high-throughput, concurrent
  * execution of both CPU-bound and I/O-bound work.
  *
  * Key concepts:
  *   - Dispatcher thread (TCore_Dispatch_Order_Thread) continuously polls a
  *     global task queue (Core_Dispatch_Order__). Tasks are TComputeDispatch
  *     records holding callbacks and user data.
  *   - When a task is posted, the dispatcher either assigns it to an idle
  *     worker or creates a new one (up to a configurable limit).
  *   - Workers execute the task, then wait for new tasks. If idle longer than
  *     Core_Thread_Life_Time_Tick__, they terminate, shrinking the pool.
  *   - A global critical section (Core_Thread_Dispatch_Critical__) protects
  *     all shared structures.
  *   - Soft synchronisation (user-space) is used for cross-thread calls,
  *     avoiding OS context switches.
  *   - Parallel for loops (block/fold) are built on top of this pool with
  *     overflow control.
  *
  * This infrastructure is used throughout the Z framework for CPU-bound and
  * I/O-bound parallelism, as well as background job processing.
  * }

type
  { * Pointer to a TComputeDispatch record. }
  PComputeDispatchData = ^TComputeDispatch;

  { * Big list that holds pending dispatch records while waiting for idle
    * workers. Each element is a pointer to a TComputeDispatch. }
  TCompute_Dispatch_Queue_Pool = TBigList<PComputeDispatchData>;

  { * TComputeDispatch – a task descriptor containing all callbacks and user
    * data for a single unit of work. It is posted to the dispatch order and
    * later assigned to a TCompute worker thread.
    *
    * Only one of the OnRun_* fields (C, M, P, or NP variants) will be set.
    * The OnDone_* callbacks are executed on the main thread via soft sync.
    *
    * @Example:
    *   var Dispatch: TComputeDispatch;
    *   Dispatch.Init;
    *   Dispatch.OnRun_C := MyProcedure;   // procedure(Th: TCompute)
    *   Dispatch.UserData := Pointer(123);
    *   PostComputeDispatchData(Dispatch); // enqueue for execution
    * }
  TComputeDispatch = record
    OnRun_C: TRun_Thread_C; // procedure(ThSender: TCompute)
    OnRun_M: TRun_Thread_M; // procedure(ThSender: TCompute) of object
    OnRun_P: TRun_Thread_P; // reference to procedure(ThSender: TCompute)
    OnRun_C_NP: TRun_Thread_C_NP; // procedure() – no parameters (C-style)
    OnRun_M_NP: TRun_Thread_M_NP; // procedure() of object (M-style)
    OnRun_P_NP: TRun_Thread_P_NP; // reference to procedure() (P-style)

    OnDone_C: TRun_Thread_C; // completion callback (C-style)
    OnDone_M: TRun_Thread_M; // completion callback (M-style)
    OnDone_P: TRun_Thread_P; // completion callback (P-style)

    UserData: Pointer; // arbitrary user pointer
    UserObject: TCore_Object; // arbitrary user object

    IsRuning_: PBoolean; // set to True while task runs, False after
    IsExit_: PBoolean; // set to True when task finishes

    IsPicked__: PBoolean; // internal: set to True when a worker picks this task
    Pool_Queue_Ptr__: TCompute_Dispatch_Queue_Pool.PQueueStruct; // internal: pointer in the pending queue

    procedure Init; // zeroes all fields
    procedure AssignTo(Th: TCompute); // copies callbacks and data into a worker thread
  end;

  { * Thread-safe FIFO queue of TComputeDispatch records. }
  TCompute_Dispatch_Order = TCriticalOrderStruct<TComputeDispatch>;

  { * TParallelOverflow – a simple counter used to limit the number of
    * concurrently executing parallel loops, preventing over-subscription.
    * It uses a busy-wait loop in Acquire until the limit is not exceeded.
    *
    * @Example:
    *   Parallel_Overflow__.Acquire;
    *   try
    *     // run parallel loop
    *   finally
    *     Parallel_Overflow__.Release;
    *   end;
    * }
  TParallelOverflow = record
  public
    ActivtedParallel: Integer; // number of active parallel loops
    procedure Acquire; // wait until not busy, then increment
    procedure Release; // decrement the counter
    function Busy(): Boolean; // True if the limit has been reached
  end;

  { * Global state for the thread pool and dispatch system. }
var
  Core_Dispatch_Order__: TCompute_Dispatch_Order; // task queue for new tasks
  Core_Dispatch_Order_Activted__, Core_Dispatch_Order_IsExit__: TAtomBool; // dispatcher status flags
  Core_Thread_Pool__: TCoreCompute_Thread_Pool; // pool of worker threads
  Core_Thread_Dispatch_Critical__: TCritical; // protects shared data
  Core_Thread_Task_Runing__: TAtomInt; // number of active workers
  Core_Thread_Dispatch_Queue_Pool__: TCompute_Dispatch_Queue_Pool; // pending tasks waiting for idle workers
  Core_Thread_Wait_Sum__: TAtomInt; // number of workers waiting for tasks
  Core_Thread_Life_Time_Tick__: TTimeTick; // idle timeout (ms) before worker exits
  Parallel_Granularity__: Integer; // default thread count for parallel loops
  Max_Activted_Parallel__: Integer; // maximum concurrent parallel loops (0 = unlimited)
  Parallel_Overflow__: TParallelOverflow; // overflow controller

  { * TComputeDispatch.Init – zeroes all fields of the record. }
procedure TComputeDispatch.Init;
begin
  OnRun_C := nil;
  OnRun_M := nil;
  OnRun_P := nil;
  OnRun_C_NP := nil;
  OnRun_M_NP := nil;
  OnRun_P_NP := nil;
  OnDone_C := nil;
  OnDone_M := nil;
  OnDone_P := nil;
  UserData := nil;
  UserObject := nil;
  IsRuning_ := nil;
  IsExit_ := nil;
  IsPicked__ := nil;
  Pool_Queue_Ptr__ := nil;
end;

{ * TComputeDispatch.AssignTo – copies all callbacks and data into a worker thread.
  * Called by the dispatcher or a worker when the task is about to be executed.
  * }
procedure TComputeDispatch.AssignTo(Th: TCompute);
begin
  Th.OnRun_C := OnRun_C;
  Th.OnRun_M := OnRun_M;
  Th.OnRun_P := OnRun_P;
  Th.OnRun_C_NP := OnRun_C_NP;
  Th.OnRun_M_NP := OnRun_M_NP;
  Th.OnRun_P_NP := OnRun_P_NP;
  Th.OnDone_C := OnDone_C;
  Th.OnDone_M := OnDone_M;
  Th.OnDone_P := OnDone_P;
  Th.UserData := UserData;
  Th.UserObject := UserObject;
  Th.IsRuning := IsRuning_;
  Th.IsExit := IsExit_;
end;

{ * TParallelOverflow.Acquire – blocks until the parallel limit is not exceeded,
  * then increments the counter. Uses a busy-wait loop to avoid kernel transitions.
  * }
procedure TParallelOverflow.Acquire;
begin
  while Busy() do
      TCore_Thread.Sleep(1);
  AtomInc(ActivtedParallel);
end;

{ * TParallelOverflow.Release – decrements the counter. }
procedure TParallelOverflow.Release;
begin
  AtomDec(ActivtedParallel);
end;

{ * TParallelOverflow.Busy – returns True if we have reached the maximum allowed
  * parallel loops.
  * }
function TParallelOverflow.Busy(): Boolean;
begin
  Result := (Max_Activted_Parallel__ > 0) and (ActivtedParallel >= Max_Activted_Parallel__);
end;

{ * Pick_Or_Create_Compute_Thread – creates a new worker thread and adds it to
  * the global pool. Called by the dispatcher when no idle worker is available.
  * }
function Pick_Or_Create_Compute_Thread(): TCompute;
begin
  Result := TCompute.Create;
  Result.Thread_Pool_Queue_Data_Ptr := Core_Thread_Pool__.Add(Result);
end;

{ * PostComputeDispatchData – adds a task to the dispatch order queue.
  * This is the entry point for submitting work to the thread pool.
  * }
procedure PostComputeDispatchData(var Data: TComputeDispatch);
begin
  Core_Dispatch_Order__.Push(Data);
end;

{ * Max_Thread_Supported – returns the maximum number of worker threads allowed,
  * based on Parallel_Granularity__. Used when LimitMaxComputeThread is defined.
  * }
function Max_Thread_Supported: Integer;
begin
  Result := Parallel_Granularity__ * 10;
end;

{ ****************************************************************************
  * TCore_Dispatch_Order_Thread – the dispatcher thread.
  *
  * This thread runs a loop that picks tasks from Core_Dispatch_Order__ and
  * assigns them to idle workers or creates new ones. It also handles the case
  * where a task is posted but no idle worker exists – it places the task in a
  * separate queue (Core_Thread_Dispatch_Queue_Pool__) that waiting workers
  * check.
  *
  * The loop checks Core_Dispatch_Order_Activted__ to know when to exit.
  * }
type
  TCore_Dispatch_Order_Thread = class(TCore_Thread)
  protected
    procedure Execute; override;
  public
    constructor Create;
    destructor Destroy; override;
  end;

var
  Core_Dispatch_Order_Thread: TCore_Dispatch_Order_Thread = nil;

  { * TCore_Dispatch_Order_Thread.Execute – the main dispatch loop.
    * It repeatedly processes tasks from the dispatch order, using an inner
    * Do_Pick procedure to handle each task.
    * }
procedure TCore_Dispatch_Order_Thread.Execute;
{ * Do_Pick – processes a single task from the order queue.
  * It first tries to find an idle worker. If none exists, it adds the task
  * to the pending queue and waits for a worker to pick it up. If no worker
  * picks it within the idle timeout, the dispatcher creates a new worker.
  *
  * The waiting logic uses a busy-check with a timeout to avoid busy-waiting
  * indefinitely.
  *
  * @param Data_ : The task record to be scheduled.
  * }
  procedure Do_Pick(var Data_: TComputeDispatch);
  var
    Tick: TTimeTick;
    IsPicked_: Boolean;
    Th: TCompute;
  begin
    // Try to find an idle worker (waiting threads count > 0) and also respect
    // the maximum thread limit if defined.
    while (Core_Thread_Wait_Sum__.V > 0)
{$IFDEF LimitMaxComputeThread}
      or (Core_Thread_Task_Runing__.V > Max_Thread_Supported)
{$ENDIF LimitMaxComputeThread}
      do
      begin
        // Mark the task as not yet picked.
        IsPicked_ := False;
        Core_Thread_Dispatch_Critical__.Acquire;
        Data_.IsPicked__ := @IsPicked_;
        Data_.Pool_Queue_Ptr__ := Core_Thread_Dispatch_Queue_Pool__.Add(@Data_);
        Tick := GetTimeTick();
        Core_Thread_Dispatch_Critical__.Release;

        // Wait for an idle worker to pick this task, but not longer than the
        // life-time tick. If it is picked, we exit immediately.
        while (Core_Thread_Wait_Sum__.V > 0) and (GetTimeTick() - Tick < Core_Thread_Life_Time_Tick__) do
          begin
            Core_Thread_Dispatch_Critical__.Acquire;
            if IsPicked_ then
              begin
                Core_Thread_Dispatch_Critical__.Release;
                exit;
              end
            else
              begin
                Core_Thread_Dispatch_Critical__.Release;
              end;
          end;

        // Timeout – remove the task from the pending queue and fall back to
        // creating a new worker.
        Core_Thread_Dispatch_Critical__.Acquire;
        if IsPicked_ then
          begin
            Core_Thread_Dispatch_Critical__.Release;
            exit;
          end
        else
          begin
            Core_Thread_Dispatch_Queue_Pool__.Remove_P(Data_.Pool_Queue_Ptr__);
            Data_.IsPicked__ := nil;
            Core_Thread_Dispatch_Critical__.Release;
          end;
      end;

    // No idle worker found and we are allowed to create a new one.
    Core_Thread_Dispatch_Critical__.Acquire;
    inc(Core_Thread_Task_Runing__.LockP()^);
    Core_Thread_Task_Runing__.Unlock;
    Th := Pick_Or_Create_Compute_Thread();
    Data_.AssignTo(Th);
    Th.Start();
    Core_Thread_Dispatch_Critical__.Release;
  end;

var
  Last_TK, IDLE_TK: TTimeTick;
begin
  Last_TK := GetTimeTick();
  while Core_Dispatch_Order_Activted__.V do
    begin
      if Core_Dispatch_Order__.Num > 0 then
        begin
          Do_Pick(Core_Dispatch_Order__.First^.Data);
          Core_Dispatch_Order__.Next;
          Last_TK := GetTimeTick()
        end
      else
        begin
          IDLE_TK := GetTimeTick() - Last_TK;
          if IDLE_TK > 5000 then
              TCompute.Sleep(100)
          else if IDLE_TK > 1000 then
              TCompute.Sleep(10)
          else if IDLE_TK > 100 then
              TCompute.Sleep(1);
        end;
    end;

  Core_Dispatch_Order_IsExit__.V := True;
end;

constructor TCore_Dispatch_Order_Thread.Create;
begin
  inherited Create(True); // create suspended
  FreeOnTerminate := True;
end;

destructor TCore_Dispatch_Order_Thread.Destroy;
begin
  Core_Dispatch_Order_Thread := nil;
  inherited Destroy;
end;

{ * ----------------------------------------------------------------------------
  * Public configuration functions
  * ---------------------------------------------------------------------------- }
function Get_Parallel_Granularity: Integer;
begin
  Result := Parallel_Granularity__;
end;

procedure Set_Parallel_Granularity(Thread_Num: Integer);
begin
  Parallel_Granularity__ := Thread_Num;
end;

procedure Set_IDLE_Compute_Wait_Time_Tick(Tick_: TTimeTick);
begin
  Core_Thread_Life_Time_Tick__ := Tick_;
end;

{ * InitCoreThreadPool – initialises the entire thread pool and dispatch system.
  * Must be called once at application startup before using any thread-pool
  * features.
  *
  * @Param Thread_Num : number of threads to pre-create (currently unused, but
  *                     kept for compatibility).
  * @Param Parallel_Granularity_ : default number of threads used by parallel
  *                                for loops.
  *
  * @Example:
  *   InitCoreThreadPool(CpuCount * 2, CpuCount * 2);
  * }
procedure InitCoreThreadPool(Thread_Num, Parallel_Granularity_: Integer);
begin
{$IFDEF DEBUG}
  if IsConsole then
      Write('Init Compute.');
{$ENDIF DEBUG}
  Core_Dispatch_Order__ := TCompute_Dispatch_Order.Create;
  Core_Dispatch_Order_Activted__ := TAtomBool.Create(True);
  Core_Dispatch_Order_IsExit__ := TAtomBool.Create(False);
  Core_Thread_Pool__ := TCoreCompute_Thread_Pool.Create;
  Core_Thread_Task_Runing__ := TAtomInt.Create(0);
  Core_Thread_Dispatch_Queue_Pool__ := TCompute_Dispatch_Queue_Pool.Create;
  Core_Thread_Wait_Sum__ := TAtomInt.Create(0);
  Core_Thread_Life_Time_Tick__ := 1000;
  Parallel_Granularity__ := Parallel_Granularity_;
  Core_Thread_Dispatch_Critical__ := TCritical.Create('Core_Thread_Dispatch_Critical__');
  Max_Activted_Parallel__ := 0;
  Parallel_Overflow__.ActivtedParallel := 0;

  Core_Dispatch_Order_Thread := TCore_Dispatch_Order_Thread.Create;
  Core_Dispatch_Order_Thread.Start();
{$IFDEF DEBUG}
  if IsConsole then
      WriteLn(Format('CPU_Thread=%d, Max_Thread=%s, Parallel_Granularity=%d IDLE_Thread_Time=%dms',
        [Thread_Num,
{$IFDEF LimitMaxComputeThread}
          IntToStr(Max_Thread_Supported),
{$ELSE LimitMaxComputeThread}
          'infinite',
{$ENDIF LimitMaxComputeThread}
          Parallel_Granularity__,
          Core_Thread_Life_Time_Tick__]));
{$ENDIF DEBUG}
end;

{ ****************************************************************************
  * Open/Close Core Dispatch Thread – safe start/stop for libraries and apps.
  *
  * These procedures provide a robust way to start and stop the dispatcher
  * thread, with explicit timeouts to prevent deadlocks during library unloading.
  * }
{ * Open_Core_Dispatch_Thread:
  * - Stops any previous dispatcher (by calling Close first).
  * - Marks the system as active and creates a new dispatcher thread.
  * }
procedure Open_Core_Dispatch_Thread();
begin
  if Core_Dispatch_Order_Activted__.V then
      exit;

  Core_Dispatch_Order_Activted__.V := True;
  Core_Dispatch_Order_IsExit__.V := False;

  Core_Dispatch_Order_Thread := TCore_Dispatch_Order_Thread.Create;
  Core_Dispatch_Order_Thread.Start();
end;

{ * Close_Core_Dispatch_Thread:
  * - Signals the dispatcher to exit and waits up to 1 second for it.
  * - Then waits up to another second for all active worker tasks to finish,
  *   while pumping soft synchronisation calls to avoid deadlocks.
  * - If timeouts expire, it forces continuation (preferring a small leak
  *   over a process hang).
  * }
procedure Close_Core_Dispatch_Thread();
var
  tk: TTimeTick;
begin
  if not Core_Dispatch_Order_Activted__.V then
      exit;
  if Core_Dispatch_Order_IsExit__.V then
      exit;
  Core_Dispatch_Order_Activted__.V := False;

  tk := GetTimeTick() + 1000;
  while not Core_Dispatch_Order_IsExit__.V do
    begin
      TCompute.Sleep(100);
      if GetTimeTick() > tk then
          Break;
    end;

  tk := GetTimeTick() + 1000;
  while (TCompute.ActivtedTask() > 0) do
    begin
      Check_Soft_Thread_Synchronize(100);
      if GetTimeTick() > tk then
          Break;
    end;

  // force reset Core_Dispatch_Order_IsExit__.V
  Core_Dispatch_Order_IsExit__.V := True;
end;

function Core_Dispatch_Order_Activted: Boolean;
begin
  Result := Core_Dispatch_Order_Activted__.V and Core_Dispatch_Order_IsExit__.V;
end;

{ * FreeCoreThreadPool – final cleanup.
  *
  * This procedure is called during application/library finalisation.
  * It signals the dispatcher to exit, waits (with timeouts) for tasks to finish,
  * and then frees all global objects.
  *
  * It is designed to be safe even if some threads refuse to exit: it will
  * release resources and return, preventing a deadlock.
  * }
procedure FreeCoreThreadPool;
var
  tk: TTimeTick;
begin
{$IFDEF DEBUG}
  if IsConsole then WriteLn('Free Compute Pool.');
{$ENDIF DEBUG}
  if Core_Dispatch_Order_Activted__.V then
    begin
      Core_Dispatch_Order_Activted__.V := False;

      tk := GetTimeTick() + 1000;
      while not Core_Dispatch_Order_IsExit__.V do
        begin
          TCompute.Sleep(100);
          if GetTimeTick() > tk then Break;
        end;

      tk := GetTimeTick() + 1000;
      while (TCompute.ActivtedTask() > 0) do
        begin
          Check_Soft_Thread_Synchronize(100);
          if GetTimeTick() > tk then Break;
        end;

      // force reset Core_Dispatch_Order_IsExit__.V
      Core_Dispatch_Order_IsExit__.V := True;
    end;

  Core_Thread_Pool__.Free;
  Core_Thread_Pool__ := nil;

  Core_Dispatch_Order__.Free;
  Core_Dispatch_Order__ := nil;

  Core_Thread_Task_Runing__.Free;
  Core_Thread_Task_Runing__ := nil;

  Core_Thread_Dispatch_Critical__.Free;
  Core_Thread_Dispatch_Critical__ := nil;

  Core_Thread_Dispatch_Queue_Pool__.Free;
  Core_Thread_Dispatch_Queue_Pool__ := nil;

  Core_Thread_Wait_Sum__.Free;
  Core_Thread_Wait_Sum__ := nil;

  Core_Dispatch_Order_Activted__.Free;
  Core_Dispatch_Order_Activted__ := nil;

  Core_Dispatch_Order_IsExit__.Free;
  Core_Dispatch_Order_IsExit__ := nil;
end;

{ ****************************************************************************
  * TCompute – the worker thread class.
  *
  * Each TCompute thread executes a single task (the callbacks stored in its
  * fields) and then enters a wait loop for new tasks. If it remains idle for
  * longer than Core_Thread_Life_Time_Tick__, it terminates.
  *
  * The thread also maintains a per‑thread MT19937 random generator (FRndInstance)
  * to avoid contention.
  *
  * @Example:
  *   TCompute.RunC(MyProcedure);  // non-blocking
  *   TCompute.Sync(MyProcedure);  // blocks until executed on main thread
  * }
procedure TCompute.Execute;
var
  Tick: TTimeTick;
  NoTask: Boolean;
begin
  FRndInstance := InternalMT19937__();
  AtomInc(PMD19937Core(FRndInstance)^.Instance_TMT19937Random__);
  FStart_Time_Tick := GetTimeTick();

  while True do
    begin
{$IFDEF MT19937SeedOnTComputeThreadIs0} SetMT19937Seed(0); {$ELSE MT19937SeedOnTComputeThreadIs0} MT19937Randomize(); {$ENDIF MT19937SeedOnTComputeThreadIs0}
      if IsRuning <> nil then
          IsRuning^ := True;
      if IsExit <> nil then
          IsExit^ := False;

      FThread_Info := '<none>';

      try
        if Assigned(OnRun_C) then
            OnRun_C(Self)
        else if Assigned(OnRun_M) then
            OnRun_M(Self)
        else if Assigned(OnRun_P) then
            OnRun_P(Self)
        else if Assigned(OnRun_C_NP) then
            OnRun_C_NP()
        else if Assigned(OnRun_M_NP) then
            OnRun_M_NP()
        else if Assigned(OnRun_P_NP) then
            OnRun_P_NP();
      except
      end;

      if Assigned(OnDone_C) or Assigned(OnDone_M) or Assigned(OnDone_P) then
          SyncM(Self, Done_Sync);

      if IsRuning <> nil then
          IsRuning^ := False;
      if IsExit <> nil then
          IsExit^ := True;

      // Wait for new tasks, but exit if idle too long.
      NoTask := True;
      Core_Thread_Wait_Sum__.Critical.Inc_(Core_Thread_Wait_Sum__.P^);
      Tick := GetTimeTick;
      repeat
        Core_Thread_Dispatch_Critical__.Acquire;
        if Core_Thread_Dispatch_Queue_Pool__.Num > 0 then
          begin
            Core_Thread_Dispatch_Queue_Pool__.First^.Data^.AssignTo(Self);
            if Core_Thread_Dispatch_Queue_Pool__.First^.Data^.IsPicked__ <> nil then
                Core_Thread_Dispatch_Queue_Pool__.First^.Data^.IsPicked__^ := True;
            Core_Thread_Dispatch_Queue_Pool__.Next;
            NoTask := False;
          end;
        Core_Thread_Dispatch_Critical__.Release;
        if NoTask then
            Sleep(1);
      until (not NoTask) or (GetTimeTick - Tick > Core_Thread_Life_Time_Tick__);
      Core_Thread_Wait_Sum__.Critical.Dec_(Core_Thread_Wait_Sum__.P^);
      if NoTask then
          Break;
    end;

  Core_Thread_Dispatch_Critical__.Acquire;
  Core_Thread_Pool__.Remove_P(Thread_Pool_Queue_Data_Ptr);
  Core_Thread_Dispatch_Critical__.Release;

  AtomDec(PMD19937Core(FRndInstance)^.Instance_TMT19937Random__);
  FRndInstance := nil;
  RemoveMT19937Thread(Self);

  dec(Core_Thread_Task_Runing__.LockP()^);
  Core_Thread_Task_Runing__.Unlock();
end;

{ * Done_Sync – executed on the main thread via soft synchronisation
  * to run the OnDone callbacks. This ensures completion callbacks run
  * in the main thread context.
  * }
procedure TCompute.Done_Sync;
begin
  try
    if Assigned(OnDone_C) then
        OnDone_C(Self)
    else if Assigned(OnDone_M) then
        OnDone_M(Self)
    else if Assigned(OnDone_P) then
        OnDone_P(Self);
  except
  end;
end;

{ * TCompute.Set_Thread_Info – sets the current thread's info string (for debugging).
  * If the current thread is a TCompute, its FThread_Info is updated.
  * }
class procedure TCompute.Set_Thread_Info(Thread_Info_: string);
var
  Th: TCore_Thread;
begin
  Th := TCore_Thread.CurrentThread;
  if (Th is TCompute) then
      TCompute(Th).FThread_Info := Thread_Info_;
end;

class procedure TCompute.Set_Thread_Info(const Fmt: string; const Args: array of const);
var
  n: string;
begin
  try
      n := Format(Fmt, Args);
  except
      n := Fmt;
  end;
  TCompute.Set_Thread_Info(n);
end;

constructor TCompute.Create;
begin
  inherited Create(True); // create suspended
  FreeOnTerminate := True;
  FSync_Tool := nil;
  Thread_Pool_Queue_Data_Ptr := nil;
  OnRun_C := nil;
  OnRun_M := nil;
  OnRun_P := nil;
  OnRun_C_NP := nil;
  OnRun_M_NP := nil;
  OnRun_P_NP := nil;
  OnDone_C := nil;
  OnDone_M := nil;
  OnDone_P := nil;
  FRndInstance := nil;
  FStart_Time_Tick := GetTimeTick();
  FThread_Info := '<none>';
  IsRuning := nil;
  IsExit := nil;
  UserData := nil;
  UserObject := nil;
end;

destructor TCompute.Destroy;
begin
  DisposeObjectAndNil(FSync_Tool);
  inherited Destroy;
end;

{ * Sync_Tool – returns a soft synchronisation tool for this thread.
  * If the thread is the main thread, returns the global main thread tool;
  * otherwise, creates a per‑thread tool on demand.
  * }
function TCompute.Sync_Tool: TSoft_Synchronize_Tool;
begin
  if Self = Main_Thread then
      Result := Main_Thread_Sync_Tool
  else
    begin
      if FSync_Tool = nil then
          Sync_Tool := TSoft_Synchronize_Tool.Create(Self);
      Result := Sync_Tool;
    end;
end;

class function TCompute.Get_Core_Thread_Pool: TCoreCompute_Thread_Pool;
begin
  Result := Core_Thread_Pool__;
end;

class function TCompute.Get_Core_Thread_Dispatch_Critical: TCritical;
begin
  Result := Core_Thread_Dispatch_Critical__;
end;

class function TCompute.Wait_Thread(): NativeInt;
begin
  Result := Core_Thread_Wait_Sum__.V;
end;

class function TCompute.ActivtedTask(): NativeInt;
begin
  Result := Core_Thread_Task_Runing__.V;
end;

class function TCompute.WaitTask(): NativeInt;
begin
  Result := Core_Dispatch_Order__.Num;
end;

class function TCompute.TotalTask(): NativeInt;
begin
  Result := Core_Thread_Task_Runing__.V + Core_Dispatch_Order__.Num;
end;

class function TCompute.State(): string;
begin
  Result := Format('Task:%d Thread:%d/%d Wait:%d/%d Critical:%d/%d 19937:%d Atom:%d Parallel:%d/%d Post:%d Sync:%d',
    [TotalTask(), ActivtedTask(), Max_Thread_Supported, WaitTask(), Wait_Thread(),
      Get_System_Critical_Num - Get_System_Critical_Recycle_Pool_Num, Get_System_Critical_Recycle_Pool_Num,
      Get_MT19937_POOL_Num(), Get_Atom_Lock_Pool_Num(),
      Parallel_Overflow__.ActivtedParallel, Max_Activted_Parallel__,
      MainThreadProgress.Num, Main_Thread_Sync_Tool.SyncQueue__.Num]);
end;

class function TCompute.GetParallelGranularity: Integer;
begin
  Result := Parallel_Granularity__;
end;

class function TCompute.GetMaxActivtedParallel: Integer;
begin
  Result := Max_Activted_Parallel__;
end;

{ * ----------------------------------------------------------------------------
  * Synchronisation helpers – allow any thread to execute code on the main
  * thread (or on a specific TCompute thread) using either soft (user‑space)
  * or system (OS) synchronisation.
  * ---------------------------------------------------------------------------- }

type
  { * TSyncTmp – internal helper that wraps a callback and frees itself after
    * execution. Used by the Sync* methods to post a procedure to the main thread.
    * }
  TSyncTmp = class
  private
    OnRunC: TRun_Thread_C_NP;
    OnRunM: TRun_Thread_M_NP;
    OnRunP: TRun_Thread_P_NP;
    procedure DoSync;
  public
    constructor Create;
  end;

procedure TSyncTmp.DoSync;
begin
  try
    if Assigned(OnRunC) then
        OnRunC()
    else if Assigned(OnRunM) then
        OnRunM()
    else if Assigned(OnRunP) then
        OnRunP();
  except
  end;
  Free;
end;

constructor TSyncTmp.Create;
begin
  inherited Create;
  OnRunC := nil;
  OnRunM := nil;
  OnRunP := nil;
end;

class procedure TCompute.Sync(OnRun_: TRun_Thread_P_NP);
var
  tmp: TSyncTmp;
begin
  tmp := TSyncTmp.Create;
  tmp.OnRunP := OnRun_;
  if Main_Thread_Soft_Synchronize then
      Main_Thread_Sync_Tool.Synchronize_M(TCompute.CurrentThread, tmp.DoSync)
  else
      TCompute.Synchronize(TCompute.CurrentThread, tmp.DoSync);
end;

class procedure TCompute.Sync(Thread_: TThread; OnRun_: TRun_Thread_P_NP);
var
  tmp: TSyncTmp;
begin
  tmp := TSyncTmp.Create;
  tmp.OnRunP := OnRun_;
  if Main_Thread_Soft_Synchronize then
      Main_Thread_Sync_Tool.Synchronize_M(Thread_, tmp.DoSync)
  else
      TCompute.Synchronize(Thread_, tmp.DoSync);
end;

class procedure TCompute.SyncC(OnRun_: TRun_Thread_C_NP);
var
  tmp: TSyncTmp;
begin
  tmp := TSyncTmp.Create;
  tmp.OnRunC := OnRun_;
  if Main_Thread_Soft_Synchronize then
      Main_Thread_Sync_Tool.Synchronize_M(TCompute.CurrentThread, tmp.DoSync)
  else
      TCompute.Synchronize(TCompute.CurrentThread, tmp.DoSync);
end;

class procedure TCompute.SyncC(Thread_: TThread; OnRun_: TRun_Thread_C_NP);
var
  tmp: TSyncTmp;
begin
  tmp := TSyncTmp.Create;
  tmp.OnRunC := OnRun_;
  if Main_Thread_Soft_Synchronize then
      Main_Thread_Sync_Tool.Synchronize_M(Thread_, tmp.DoSync)
  else
      TCompute.Synchronize(Thread_, tmp.DoSync);
end;

class procedure TCompute.SyncM(OnRun_: TRun_Thread_M_NP);
var
  tmp: TSyncTmp;
begin
  tmp := TSyncTmp.Create;
  tmp.OnRunM := OnRun_;
  if Main_Thread_Soft_Synchronize then
      Main_Thread_Sync_Tool.Synchronize_M(TCompute.CurrentThread, tmp.DoSync)
  else
      TCompute.Synchronize(TCompute.CurrentThread, tmp.DoSync);
end;

class procedure TCompute.SyncM(Thread_: TThread; OnRun_: TRun_Thread_M_NP);
var
  tmp: TSyncTmp;
begin
  tmp := TSyncTmp.Create;
  tmp.OnRunM := OnRun_;
  if Main_Thread_Soft_Synchronize then
      Main_Thread_Sync_Tool.Synchronize_M(Thread_, tmp.DoSync)
  else
      TCompute.Synchronize(Thread_, tmp.DoSync);
end;

class procedure TCompute.SyncP(OnRun_: TRun_Thread_P_NP);
var
  tmp: TSyncTmp;
begin
  tmp := TSyncTmp.Create;
  tmp.OnRunP := OnRun_;
  if Main_Thread_Soft_Synchronize then
      Main_Thread_Sync_Tool.Synchronize_M(TCompute.CurrentThread, tmp.DoSync)
  else
      TCompute.Synchronize(TCompute.CurrentThread, tmp.DoSync);
end;

class procedure TCompute.SyncP(Thread_: TThread; OnRun_: TRun_Thread_P_NP);
var
  tmp: TSyncTmp;
begin
  tmp := TSyncTmp.Create;
  tmp.OnRunP := OnRun_;
  if Main_Thread_Soft_Synchronize then
      Main_Thread_Sync_Tool.Synchronize_M(Thread_, tmp.DoSync)
  else
      TCompute.Synchronize(Thread_, tmp.DoSync);
end;

class procedure TCompute.Sync_To(Dest_Thread_: TCompute; OnRun_: TRun_Thread_P_NP);
begin
  Dest_Thread_.Sync_Tool.Synchronize(TCompute.CurrentThread, OnRun_);
end;

class procedure TCompute.SyncC_To(Dest_Thread_: TCompute; OnRun_: TRun_Thread_C_NP);
begin
  Dest_Thread_.Sync_Tool.Synchronize_C(TCompute.CurrentThread, OnRun_);
end;

class procedure TCompute.SyncM_To(Dest_Thread_: TCompute; OnRun_: TRun_Thread_M_NP);
begin
  Dest_Thread_.Sync_Tool.Synchronize_M(TCompute.CurrentThread, OnRun_);
end;

class procedure TCompute.SyncP_To(Dest_Thread_: TCompute; OnRun_: TRun_Thread_P_NP);
begin
  Dest_Thread_.Sync_Tool.Synchronize_P(TCompute.CurrentThread, OnRun_);
end;

{ * ----------------------------------------------------------------------------
  * Task posting – asynchronous execution.
  * Multiple overloads are provided for different callback signatures.
  * Each method creates a TComputeDispatch record, initialises it, and posts it
  * to the dispatch order. The task will be executed on a worker thread.
  *
  * @Example:
  *   TCompute.RunC(MyProcedure);  // MyProcedure: procedure(Th: TCompute)
  *   TCompute.RunC_NP(MyProcNoParam); // MyProcNoParam: procedure()
  *   TCompute.RunM(MyObj.MyMethod); // method of object
  *   TCompute.RunP(procedure(Th) begin ... end); // anonymous
  * ---------------------------------------------------------------------------- }

class procedure TCompute.RunC(const Data: Pointer; const Obj: TObject; const OnRun, OnDone: TRun_Thread_C);
var
  Dispatch_: TComputeDispatch;
begin
  Dispatch_.Init;
  Dispatch_.OnRun_C := OnRun;
  Dispatch_.OnDone_C := OnDone;
  Dispatch_.UserData := Data;
  Dispatch_.UserObject := Obj;
  PostComputeDispatchData(Dispatch_);
end;

class procedure TCompute.RunC(const Data: Pointer; const Obj: TObject; const OnRun, OnDone: TRun_Thread_C; IsRuning_, IsExit_: PBoolean);
var
  Dispatch_: TComputeDispatch;
begin
  if IsRuning_ <> nil then
      IsRuning_^ := True;
  if IsExit_ <> nil then
      IsExit_^ := False;

  Dispatch_.Init;
  Dispatch_.OnRun_C := OnRun;
  Dispatch_.OnDone_C := OnDone;
  Dispatch_.UserData := Data;
  Dispatch_.UserObject := Obj;
  Dispatch_.IsRuning_ := IsRuning_;
  Dispatch_.IsExit_ := IsExit_;
  PostComputeDispatchData(Dispatch_);
end;

class procedure TCompute.RunC(const Data: Pointer; const Obj: TObject; const OnRun: TRun_Thread_C);
var
  Dispatch_: TComputeDispatch;
begin
  Dispatch_.Init;
  Dispatch_.OnRun_C := OnRun;
  Dispatch_.UserData := Data;
  Dispatch_.UserObject := Obj;
  PostComputeDispatchData(Dispatch_);
end;

class procedure TCompute.RunC(const Data: Pointer; const Obj: TObject; const OnRun: TRun_Thread_C; IsRuning_, IsExit_: PBoolean);
var
  Dispatch_: TComputeDispatch;
begin
  if IsRuning_ <> nil then
      IsRuning_^ := True;
  if IsExit_ <> nil then
      IsExit_^ := False;

  Dispatch_.Init;
  Dispatch_.OnRun_C := OnRun;
  Dispatch_.UserData := Data;
  Dispatch_.UserObject := Obj;
  Dispatch_.IsRuning_ := IsRuning_;
  Dispatch_.IsExit_ := IsExit_;
  PostComputeDispatchData(Dispatch_);
end;

class procedure TCompute.RunC_NP(const OnRun: TRun_Thread_C_NP);
var
  Dispatch_: TComputeDispatch;
begin
  Dispatch_.Init;
  Dispatch_.OnRun_C_NP := OnRun;
  Dispatch_.UserData := nil;
  Dispatch_.UserObject := nil;
  PostComputeDispatchData(Dispatch_);
end;

class procedure TCompute.RunC_NP(const OnRun: TRun_Thread_C_NP; IsRuning_, IsExit_: PBoolean);
var
  Dispatch_: TComputeDispatch;
begin
  if IsRuning_ <> nil then
      IsRuning_^ := True;
  if IsExit_ <> nil then
      IsExit_^ := False;

  Dispatch_.Init;
  Dispatch_.OnRun_C_NP := OnRun;
  Dispatch_.UserData := nil;
  Dispatch_.UserObject := nil;
  Dispatch_.IsRuning_ := IsRuning_;
  Dispatch_.IsExit_ := IsExit_;
  PostComputeDispatchData(Dispatch_);
end;

class procedure TCompute.RunM(const Data: Pointer; const Obj: TObject; const OnRun, OnDone: TRun_Thread_M);
var
  Dispatch_: TComputeDispatch;
begin
  Dispatch_.Init;
  Dispatch_.OnRun_M := OnRun;
  Dispatch_.OnDone_M := OnDone;
  Dispatch_.UserData := Data;
  Dispatch_.UserObject := Obj;
  PostComputeDispatchData(Dispatch_);
end;

class procedure TCompute.RunM(const Data: Pointer; const Obj: TObject; const OnRun, OnDone: TRun_Thread_M; IsRuning_, IsExit_: PBoolean);
var
  Dispatch_: TComputeDispatch;
begin
  if IsRuning_ <> nil then
      IsRuning_^ := True;
  if IsExit_ <> nil then
      IsExit_^ := False;

  Dispatch_.Init;
  Dispatch_.OnRun_M := OnRun;
  Dispatch_.OnDone_M := OnDone;
  Dispatch_.UserData := Data;
  Dispatch_.UserObject := Obj;
  Dispatch_.IsRuning_ := IsRuning_;
  Dispatch_.IsExit_ := IsExit_;
  PostComputeDispatchData(Dispatch_);
end;

class procedure TCompute.RunM(const Data: Pointer; const Obj: TObject; const OnRun: TRun_Thread_M);
var
  Dispatch_: TComputeDispatch;
begin
  Dispatch_.Init;
  Dispatch_.OnRun_M := OnRun;
  Dispatch_.UserData := Data;
  Dispatch_.UserObject := Obj;
  PostComputeDispatchData(Dispatch_);
end;

class procedure TCompute.RunM(const Data: Pointer; const Obj: TObject; const OnRun: TRun_Thread_M; IsRuning_, IsExit_: PBoolean);
var
  Dispatch_: TComputeDispatch;
begin
  if IsRuning_ <> nil then
      IsRuning_^ := True;
  if IsExit_ <> nil then
      IsExit_^ := False;

  Dispatch_.Init;
  Dispatch_.OnRun_M := OnRun;
  Dispatch_.UserData := Data;
  Dispatch_.UserObject := Obj;
  Dispatch_.IsRuning_ := IsRuning_;
  Dispatch_.IsExit_ := IsExit_;
  PostComputeDispatchData(Dispatch_);
end;

class procedure TCompute.RunM_NP(const OnRun: TRun_Thread_M_NP);
var
  Dispatch_: TComputeDispatch;
begin
  Dispatch_.Init;
  Dispatch_.OnRun_M_NP := OnRun;
  Dispatch_.UserData := nil;
  Dispatch_.UserObject := nil;
  PostComputeDispatchData(Dispatch_);
end;

class procedure TCompute.RunM_NP(const OnRun: TRun_Thread_M_NP; IsRuning_, IsExit_: PBoolean);
var
  Dispatch_: TComputeDispatch;
begin
  if IsRuning_ <> nil then
      IsRuning_^ := True;
  if IsExit_ <> nil then
      IsExit_^ := False;

  Dispatch_.Init;
  Dispatch_.OnRun_M_NP := OnRun;
  Dispatch_.UserData := nil;
  Dispatch_.UserObject := nil;
  Dispatch_.IsRuning_ := IsRuning_;
  Dispatch_.IsExit_ := IsExit_;
  PostComputeDispatchData(Dispatch_);
end;

class procedure TCompute.RunP(const Data: Pointer; const Obj: TObject; const OnRun, OnDone: TRun_Thread_P);
var
  Dispatch_: TComputeDispatch;
begin
  Dispatch_.Init;
  Dispatch_.OnRun_P := OnRun;
  Dispatch_.OnDone_P := OnDone;
  Dispatch_.UserData := Data;
  Dispatch_.UserObject := Obj;
  PostComputeDispatchData(Dispatch_);
end;

class procedure TCompute.RunP(const Data: Pointer; const Obj: TObject; const OnRun, OnDone: TRun_Thread_P; IsRuning_, IsExit_: PBoolean);
var
  Dispatch_: TComputeDispatch;
begin
  if IsRuning_ <> nil then
      IsRuning_^ := True;
  if IsExit_ <> nil then
      IsExit_^ := False;

  Dispatch_.Init;
  Dispatch_.OnRun_P := OnRun;
  Dispatch_.OnDone_P := OnDone;
  Dispatch_.UserData := Data;
  Dispatch_.UserObject := Obj;
  Dispatch_.IsRuning_ := IsRuning_;
  Dispatch_.IsExit_ := IsExit_;
  PostComputeDispatchData(Dispatch_);
end;

class procedure TCompute.RunP(const Data: Pointer; const Obj: TObject; const OnRun: TRun_Thread_P);
var
  Dispatch_: TComputeDispatch;
begin
  Dispatch_.Init;
  Dispatch_.OnRun_P := OnRun;
  Dispatch_.UserData := Data;
  Dispatch_.UserObject := Obj;
  PostComputeDispatchData(Dispatch_);
end;

class procedure TCompute.RunP(const Data: Pointer; const Obj: TObject; const OnRun: TRun_Thread_P; IsRuning_, IsExit_: PBoolean);
var
  Dispatch_: TComputeDispatch;
begin
  if IsRuning_ <> nil then
      IsRuning_^ := True;
  if IsExit_ <> nil then
      IsExit_^ := False;

  Dispatch_.Init;
  Dispatch_.OnRun_P := OnRun;
  Dispatch_.UserData := Data;
  Dispatch_.UserObject := Obj;
  Dispatch_.IsRuning_ := IsRuning_;
  Dispatch_.IsExit_ := IsExit_;
  PostComputeDispatchData(Dispatch_);
end;

class procedure TCompute.RunP_NP(const OnRun: TRun_Thread_P_NP);
var
  Dispatch_: TComputeDispatch;
begin
  Dispatch_.Init;
  Dispatch_.OnRun_P_NP := OnRun;
  Dispatch_.UserData := nil;
  Dispatch_.UserObject := nil;
  PostComputeDispatchData(Dispatch_);
end;

class procedure TCompute.RunP_NP(const OnRun: TRun_Thread_P_NP; IsRuning_, IsExit_: PBoolean);
var
  Dispatch_: TComputeDispatch;
begin
  if IsRuning_ <> nil then
      IsRuning_^ := True;
  if IsExit_ <> nil then
      IsExit_^ := False;

  Dispatch_.Init;
  Dispatch_.OnRun_P_NP := OnRun;
  Dispatch_.UserData := nil;
  Dispatch_.UserObject := nil;
  Dispatch_.IsRuning_ := IsRuning_;
  Dispatch_.IsExit_ := IsExit_;
  PostComputeDispatchData(Dispatch_);
end;

{ * ----------------------------------------------------------------------------
  * PostFreeObjectInThread – asynchronously frees an object on a worker thread.
  * This avoids blocking the caller and ensures the object is freed in a thread‑safe
  * context.
  * ---------------------------------------------------------------------------- }

procedure Do_PostFreeObjectInThread(ThSender: TCompute);
begin
  DisposeObject(ThSender.UserObject);
end;

class procedure TCompute.PostFreeObjectInThread(const Obj: TObject);
begin
  if Obj = nil then
      exit;
  TCompute.RunC(nil, Obj, Do_PostFreeObjectInThread, nil);
end;

class procedure TCompute.PostFreeObjectInThreadAndNil(var Obj);
begin
  if TObject(Obj) <> nil then
    begin
      TCompute.PostFreeObjectInThread(TObject(Obj));
      TObject(Obj) := nil;
    end;
end;

{ * ----------------------------------------------------------------------------
  * Main thread progress – pumps the main thread's TThreadPost queue.
  * ---------------------------------------------------------------------------- }
class procedure TCompute.ProgressPost();
begin
  MainThreadProgress.Progress();
end;

{ * ----------------------------------------------------------------------------
  * Posting to the main thread – these are convenience wrappers around
  * MainThreadProgress.Post* methods. They allow posting a procedure to be
  * executed on the main thread asynchronously (non-blocking).
  * ---------------------------------------------------------------------------- }

class procedure TCompute.PostC1(OnSync: TThreadPost_C1);
begin
  MainThreadProgress.PostC1(OnSync);
end;

class procedure TCompute.PostC1(OnSync: TThreadPost_C1; IsRuning_, IsExit_: PBoolean);
begin
  MainThreadProgress.PostC1(OnSync, IsRuning_, IsExit_);
end;

class procedure TCompute.PostC2(Data1: Pointer; OnSync: TThreadPost_C2);
begin
  MainThreadProgress.PostC2(Data1, OnSync);
end;

class procedure TCompute.PostC2(Data1: Pointer; OnSync: TThreadPost_C2; IsRuning_, IsExit_: PBoolean);
begin
  MainThreadProgress.PostC2(Data1, OnSync, IsRuning_, IsExit_);
end;

class procedure TCompute.PostC3(Data1: Pointer; Data2: TObject; Data3: Variant; OnSync: TThreadPost_C3);
begin
  MainThreadProgress.PostC3(Data1, Data2, Data3, OnSync);
end;

class procedure TCompute.PostC3(Data1: Pointer; Data2: TObject; Data3: Variant; OnSync: TThreadPost_C3; IsRuning_, IsExit_: PBoolean);
begin
  MainThreadProgress.PostC3(Data1, Data2, Data3, OnSync, IsRuning_, IsExit_);
end;

class procedure TCompute.PostC4(Data1: Pointer; Data2: TObject; OnSync: TThreadPost_C4);
begin
  MainThreadProgress.PostC4(Data1, Data2, OnSync);
end;

class procedure TCompute.PostC4(Data1: Pointer; Data2: TObject; OnSync: TThreadPost_C4; IsRuning_, IsExit_: PBoolean);
begin
  MainThreadProgress.PostC4(Data1, Data2, OnSync, IsRuning_, IsExit_);
end;

class procedure TCompute.PostM1(OnSync: TThreadPost_M1);
begin
  MainThreadProgress.PostM1(OnSync);
end;

class procedure TCompute.PostM1(OnSync: TThreadPost_M1; IsRuning_, IsExit_: PBoolean);
begin
  MainThreadProgress.PostM1(OnSync, IsRuning_, IsExit_);
end;

class procedure TCompute.PostM2(Data1: Pointer; OnSync: TThreadPost_M2);
begin
  MainThreadProgress.PostM2(Data1, OnSync);
end;

class procedure TCompute.PostM2(Data1: Pointer; OnSync: TThreadPost_M2; IsRuning_, IsExit_: PBoolean);
begin
  MainThreadProgress.PostM2(Data1, OnSync, IsRuning_, IsExit_);
end;

class procedure TCompute.PostM3(Data1: Pointer; Data2: TObject; Data3: Variant; OnSync: TThreadPost_M3);
begin
  MainThreadProgress.PostM3(Data1, Data2, Data3, OnSync);
end;

class procedure TCompute.PostM3(Data1: Pointer; Data2: TObject; Data3: Variant; OnSync: TThreadPost_M3; IsRuning_, IsExit_: PBoolean);
begin
  MainThreadProgress.PostM3(Data1, Data2, Data3, OnSync, IsRuning_, IsExit_);
end;

class procedure TCompute.PostM4(Data1: Pointer; Data2: TObject; OnSync: TThreadPost_M4);
begin
  MainThreadProgress.PostM4(Data1, Data2, OnSync);
end;

class procedure TCompute.PostM4(Data1: Pointer; Data2: TObject; OnSync: TThreadPost_M4; IsRuning_, IsExit_: PBoolean);
begin
  MainThreadProgress.PostM4(Data1, Data2, OnSync, IsRuning_, IsExit_);
end;

class procedure TCompute.PostP1(OnSync: TThreadPost_P1);
begin
  MainThreadProgress.PostP1(OnSync);
end;

class procedure TCompute.PostP1(OnSync: TThreadPost_P1; IsRuning_, IsExit_: PBoolean);
begin
  MainThreadProgress.PostP1(OnSync, IsRuning_, IsExit_);
end;

class procedure TCompute.PostP2(Data1: Pointer; OnSync: TThreadPost_P2);
begin
  MainThreadProgress.PostP2(Data1, OnSync);
end;

class procedure TCompute.PostP2(Data1: Pointer; OnSync: TThreadPost_P2; IsRuning_, IsExit_: PBoolean);
begin
  MainThreadProgress.PostP2(Data1, OnSync, IsRuning_, IsExit_);
end;

class procedure TCompute.PostP3(Data1: Pointer; Data2: TObject; Data3: Variant; OnSync: TThreadPost_P3);
begin
  MainThreadProgress.PostP3(Data1, Data2, Data3, OnSync);
end;

class procedure TCompute.PostP3(Data1: Pointer; Data2: TObject; Data3: Variant; OnSync: TThreadPost_P3; IsRuning_, IsExit_: PBoolean);
begin
  MainThreadProgress.PostP3(Data1, Data2, Data3, OnSync, IsRuning_, IsExit_);
end;

class procedure TCompute.PostP4(Data1: Pointer; Data2: TObject; OnSync: TThreadPost_P4);
begin
  MainThreadProgress.PostP4(Data1, Data2, OnSync);
end;

class procedure TCompute.PostP4(Data1: Pointer; Data2: TObject; OnSync: TThreadPost_P4; IsRuning_, IsExit_: PBoolean);
begin
  MainThreadProgress.PostP4(Data1, Data2, OnSync, IsRuning_, IsExit_);
end;

{ * ----------------------------------------------------------------------------
  * Synchronous post – blocks the caller until the posted procedure has been
  * executed on the main thread. This is useful when you need to ensure that
  * the main thread has processed the procedure before continuing.
  *
  * @Example:
  *   TCompute.Sync_Wait_PostC1(procedure begin ShowMessage('Done'); end);
  * ---------------------------------------------------------------------------- }

class procedure TCompute.Sync_Wait_PostC1(OnSync: TThreadPost_C1);
begin
  MainThreadProgress.Sync_Wait_PostC1(OnSync);
end;

class procedure TCompute.Sync_Wait_PostC2(Data1: Pointer; OnSync: TThreadPost_C2);
begin
  MainThreadProgress.Sync_Wait_PostC2(Data1, OnSync);
end;

class procedure TCompute.Sync_Wait_PostC3(Data1: Pointer; Data2: TObject; Data3: Variant; OnSync: TThreadPost_C3);
begin
  MainThreadProgress.Sync_Wait_PostC3(Data1, Data2, Data3, OnSync);
end;

class procedure TCompute.Sync_Wait_PostC4(Data1: Pointer; Data2: TObject; OnSync: TThreadPost_C4);
begin
  MainThreadProgress.Sync_Wait_PostC4(Data1, Data2, OnSync);
end;

class procedure TCompute.Sync_Wait_PostM1(OnSync: TThreadPost_M1);
begin
  MainThreadProgress.Sync_Wait_PostM1(OnSync);
end;

class procedure TCompute.Sync_Wait_PostM2(Data1: Pointer; OnSync: TThreadPost_M2);
begin
  MainThreadProgress.Sync_Wait_PostM2(Data1, OnSync);
end;

class procedure TCompute.Sync_Wait_PostM3(Data1: Pointer; Data2: TObject; Data3: Variant; OnSync: TThreadPost_M3);
begin
  MainThreadProgress.Sync_Wait_PostM3(Data1, Data2, Data3, OnSync);
end;

class procedure TCompute.Sync_Wait_PostM4(Data1: Pointer; Data2: TObject; OnSync: TThreadPost_M4);
begin
  MainThreadProgress.Sync_Wait_PostM4(Data1, Data2, OnSync);
end;

class procedure TCompute.Sync_Wait_PostP1(OnSync: TThreadPost_P1);
begin
  MainThreadProgress.Sync_Wait_PostP1(OnSync);
end;

class procedure TCompute.Sync_Wait_PostP2(Data1: Pointer; OnSync: TThreadPost_P2);
begin
  MainThreadProgress.Sync_Wait_PostP2(Data1, OnSync);
end;

class procedure TCompute.Sync_Wait_PostP3(Data1: Pointer; Data2: TObject; Data3: Variant; OnSync: TThreadPost_P3);
begin
  MainThreadProgress.Sync_Wait_PostP3(Data1, Data2, Data3, OnSync);
end;

class procedure TCompute.Sync_Wait_PostP4(Data1: Pointer; Data2: TObject; OnSync: TThreadPost_P4);
begin
  MainThreadProgress.Sync_Wait_PostP4(Data1, Data2, OnSync);
end;

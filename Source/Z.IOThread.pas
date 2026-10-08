{ ******************************************************************************
  * Z.IOThread – Thread‑pooled and direct IO execution engine.
  *
  * This unit provides three levels of asynchronous/synchronous task execution:
  *
  *   1. TIO_Thread      – multi‑worker threaded queue. Tasks (TIO_Thread_Data)
  *                        are processed by a pool of background threads.
  *   2. TIO_Direct      – same API but executes tasks immediately on the caller’s
  *                        thread. Useful for debugging or when threading is not
  *                        needed.
  *   3. TThread_Pool    – advanced pool of dedicated threads, each with its own
  *                        TThreadPost message queue. Offers load‑balancing and
  *                        round‑robin dispatching.
  *
  * All classes use Z.Core primitives (TCompute, TCritical, TOrderStruct) and
  * are designed for high‑throughput, low‑overhead background processing.
  *
  * @Example (using TIO_Thread):
  *   var
  *     Thread: TIO_Thread;
  *     Data: TIO_Thread_Data;
  *   begin
  *     Thread := TIO_Thread.Create(4);              // 4 worker threads
  *     Data := TIO_Thread_Data.Create;             // create a task
  *     Data.On_C := MyTaskHandler;                 // assign a callback
  *     Thread.Enqueue(Data);                       // submit for background execution
  *     // ... later ...
  *     while Thread.Count > 0 do                   // wait for all tasks to finish
  *       TCompute.Sleep(1);
  *     Thread.Free;
  *   end;
  ****************************************************************************** }
unit Z.IOThread;

{$DEFINE FPC_DELPHI_MODE}
{$I Z.Define.inc}

interface

uses
{$IFDEF FPC}
  Z.FPC.GenericList,
{$ENDIF FPC}
  Z.Core;

type
  TIO_Thread_Data = class;
  TIO_Thread_Data_State = (idsDone, idsRunning, idsReady, idsInited);
  { * State machine for an IO task:
    *   idsInited  – just created, not yet enqueued.
    *   idsReady   – enqueued and waiting for a worker.
    *   idsRunning – currently being executed by a worker.
    *   idsDone    – execution finished, ready to be dequeued. }

  { Callback signatures for task completion/execution.
    C – plain procedure, M – method of object, P – nested/reference (anonymous). }
  TIO_Thread_On_C = procedure(Sender: TIO_Thread_Data);
  TIO_Thread_On_M = procedure(Sender: TIO_Thread_Data) of object;
{$IFDEF FPC}
  TIO_Thread_On_P = procedure(Sender: TIO_Thread_Data) is nested;
{$ELSE FPC}
  TIO_Thread_On_P = reference to procedure(Sender: TIO_Thread_Data);
{$ENDIF FPC}

  { * TIO_Thread_Data – a single work item for the IO queue.
    *
    * It holds a user‑supplied pointer (Data) and one of three callback types.
    * The state (FState) tracks its lifecycle. When a worker thread picks it up,
    * it calls the assigned callback and then marks it as idsDone.
    *
    * @Example:
    *   var Task: TIO_Thread_Data;
    *   begin
    *     Task := TIO_Thread_Data.Create;
    *     Task.Data := Pointer(123);                // attach custom data
    *     Task.On_C := MyProc;                     // set callback
    *     Thread.Enqueue(Task);                    // submit
    *   end;
  }
  TIO_Thread_Data = class(TCore_Object_Intermediate)
  private
    FState: TIO_Thread_Data_State; // Current state of the task.
    FOn_C: TIO_Thread_On_C; // Plain procedure callback.
    FOn_M: TIO_Thread_On_M; // Method callback.
    FOn_P: TIO_Thread_On_P; // Nested/anonymous callback.
  public
    Data: Pointer; // User‑defined data (not owned).
    constructor Create; virtual; // Initialises state to idsInited.
    destructor Destroy; override;
    procedure Process; virtual; // Executes the assigned callback.
    property On_C: TIO_Thread_On_C read FOn_C write FOn_C;
    property On_M: TIO_Thread_On_M read FOn_M write FOn_M;
    property On_P: TIO_Thread_On_P read FOn_P write FOn_P;
  end;

  { FIFO queue of TIO_Thread_Data (non‑thread‑safe; use external locking). }
  TIO_Thread_Queue = TOrderStruct<TIO_Thread_Data>;

  { Abstract base class for an IO execution engine. }
  TIO_Thread_Base = class(TCore_Object_Intermediate)
  public
    function Count(): Integer; virtual; abstract; // Total pending + done tasks.
    procedure Enqueue(IOData: TIO_Thread_Data); virtual; abstract; // Submit a task.
    procedure Enqueue_C(IOData: TIO_Thread_Data; Data: Pointer; On_C: TIO_Thread_On_C); virtual; abstract; // Shorthand: set Data and callback and enqueue.
    procedure Enqueue_M(IOData: TIO_Thread_Data; Data: Pointer; On_M: TIO_Thread_On_M); virtual; abstract;
    procedure Enqueue_P(IOData: TIO_Thread_Data; Data: Pointer; On_P: TIO_Thread_On_P); virtual; abstract;
    function Dequeue(): TIO_Thread_Data; virtual; abstract; // Retrieve a finished task (nil if none).
    procedure Wait; virtual; abstract; // Block until all tasks finished.
  end;

  { * TIO_Thread – multi‑threaded queue with a fixed number of worker threads.
    *
    * Workers (TCompute threads) continuously scan the queue for tasks in idsReady
    * state. Each task is executed exactly once, then moved to a separate done queue
    * for later retrieval by the main thread.
    *
    * The queue is protected by a critical section. Tasks are not freed automatically;
    * the caller must dequeue and free them after they are done.
    *
    * @Example:
    *   var
    *     Thread: TIO_Thread;
    *     i: Integer;
    *     Task: TIO_Thread_Data;
    *   begin
    *     Thread := TIO_Thread.Create(2);   // two workers
    *     for i := 1 to 100 do
    *     begin
    *       Task := TIO_Thread_Data.Create;
    *       Task.Data := Pointer(i);
    *       Task.On_C := MyHandler;
    *       Thread.Enqueue(Task);
    *     end;
    *     Thread.Wait;                     // wait for all tasks
    *     while True do
    *     begin
    *       Task := Thread.Dequeue;
    *       if Task = nil then Break;
    *       Task.Free;                     // free finished tasks
    *     end;
    *     Thread.Free;
    *   end;
  }
  TIO_Thread = class(TIO_Thread_Base)
  protected
    FCritical: TCritical; // Protects FQueue and FDoneQueue.
    FThRunning: TAtomBool; // Set to False to stop workers.
    FThNum: Integer; // Number of currently active workers.
    FQueue: TIO_Thread_Queue; // Queue of tasks waiting to be processed.
    FDoneQueue: TIO_Thread_Queue; // Queue of tasks that have been processed.
    procedure ThRun(Sender: TCompute); // Worker thread main loop.
  public
    constructor Create(ThNum_: Integer); // Creates ThNum_ worker threads.
    destructor Destroy; override;
    procedure Reset(); // Restarts all workers (stops and re‑creates them).
    procedure ThEnd(); // Stops all workers and clears queues.

    function QueueCount(): Integer; // Number of tasks in the waiting queue.
    function DoneCount(): Integer; // Number of finished tasks ready to be dequeued.
    function Count(): Integer; override; // Total QueueCount + DoneCount.
    procedure Enqueue(IOData: TIO_Thread_Data); override;
    procedure Enqueue_C(IOData: TIO_Thread_Data; Data: Pointer; On_C: TIO_Thread_On_C); override;
    procedure Enqueue_M(IOData: TIO_Thread_Data; Data: Pointer; On_M: TIO_Thread_On_M); override;
    procedure Enqueue_P(IOData: TIO_Thread_Data; Data: Pointer; On_P: TIO_Thread_On_P); override;
    function Dequeue(): TIO_Thread_Data; override; // Returns a finished task (nil if none).
    procedure Wait; override; // Blocks until Count = 0.

    class procedure Test(); // Unit test (enqueues 1M tasks and verifies order).
  end;

  { * TIO_Direct – synchronous in‑place execution.
    *
    * Implements the same interface as TIO_Thread but executes every task
    * immediately on the caller’s thread, then places it into a done queue.
    * This is useful for testing, debugging, or scenarios where threading
    * overhead is undesirable.
    *
    * @Example:
    *   var Direct: TIO_Direct;
    *       Task: TIO_Thread_Data;
    *   begin
    *     Direct := TIO_Direct.Create;
    *     Task := TIO_Thread_Data.Create;
    *     Task.On_C := MyHandler;
    *     Direct.Enqueue(Task);          // MyHandler runs immediately.
    *     Task := Direct.Dequeue;        // Get the finished task.
    *     Task.Free;
    *     Direct.Free;
    *   end;
  }
  TIO_Direct = class(TIO_Thread_Base)
  protected
    FCritical: TCritical; // Protects FQueue.
    FQueue: TIO_Thread_Queue; // Queue of finished tasks (since they are executed immediately).
  public
    constructor Create;
    destructor Destroy; override;
    procedure Reset(); // Clears the queue.
    function Count(): Integer; override; // Number of finished tasks waiting.
    property QueueCount: Integer read Count;
    procedure Enqueue(IOData: TIO_Thread_Data); override; // Executes immediately.
    procedure Enqueue_C(IOData: TIO_Thread_Data; Data: Pointer; On_C: TIO_Thread_On_C); override;
    procedure Enqueue_M(IOData: TIO_Thread_Data; Data: Pointer; On_M: TIO_Thread_On_M); override;
    procedure Enqueue_P(IOData: TIO_Thread_Data; Data: Pointer; On_P: TIO_Thread_On_P); override;
    function Dequeue(): TIO_Thread_Data; override; // Returns finished tasks.
    procedure Wait; override; // Waits until Count = 0.
    class procedure Test(); // Unit test (enqueues 1M tasks).
  end;

  TThread_Event_Pool__ = class; // Forward declaration for TThread_Pool.

  { Underlying list type for TThread_Pool. }
  TThread_Pool_Decl = TBigList<TThread_Event_Pool__>;

  { * TThread_Pool – advanced thread pool with per‑thread message queues.
    *
    * Unlike TIO_Thread (which shares a single queue), this pool creates a fixed
    * number of dedicated threads (TCompute), each owning its own TThreadPost
    * message queue. Tasks are posted to a specific thread using either a
    * round‑robin (Next_Thread) or load‑balancing (MinLoad_Thread) strategy.
    *
    * Each thread runs an internal loop that processes its TThreadPost queue.
    * This design reduces contention and is ideal for workloads where tasks
    * should be pinned to a particular thread or when fair distribution is needed.
    *
    * @Example:
    *   var Pool: TThread_Pool;
    *   begin
    *     Pool := TThread_Pool.Create(4);          // 4 worker threads
    *     // Post a task (method) to the next thread in round‑robin order:
    *     Pool.Next_Thread.PostM1(MyMethod);
    *     // Post to the thread with the smallest backlog:
    *     Pool.MinLoad_Thread.PostM1(MyMethod);
    *     Pool.Wait;                               // wait for all tasks to finish
    *     Pool.Free;
    *   end;
  }
  TThread_Pool = class(TThread_Pool_Decl)
  private
    FCritical: TCritical; // Protects the list of threads.
    FQueueOptimized: Boolean; // If True, Next_Thread uses round‑robin; otherwise (unused) – for future extensibility.
  public
    constructor Create(ThNum_: Integer); // Creates ThNum_ threads.
    destructor Destroy; override;
    property QueueOptimized: Boolean read FQueueOptimized write FQueueOptimized;

    function ThNum: NativeInt; // Number of worker threads.
    function TaskNum: NativeInt; // Total pending tasks across all threads.

    procedure Wait(); overload; // Wait for all tasks on all threads to finish.
    procedure Wait(Th: TThread_Event_Pool__); overload; // Wait for a specific thread's queue to empty.

    function Next_Thread: TThread_Event_Pool__; // Returns next thread in round‑robin order.
    function MinLoad_Thread: TThread_Event_Pool__; // Returns thread with the fewest pending tasks.

    procedure DoTest_C(); // Dummy test callback that sleeps 16 ms.
    class procedure Test(); // Unit test.
  end;

  { * TThread_Event_Pool__ – a single worker thread inside a TThread_Pool.
    *
    * This object is owned by TThread_Pool and runs a TCompute thread.
    * It contains a TThreadPost instance that receives posted tasks.
    * The thread’s main loop (ThRun) processes these tasks until deactivated.
    *
    * @Example:
    *   (Normally not used directly; use TThread_Pool methods.)
  }
  TThread_Event_Pool__ = class(TCore_Object_Intermediate)
  private
    FOwner: TThread_Pool; // The pool that owns this thread.
    FBindTh: TCompute; // The underlying TCompute thread.
    FPost: TThreadPost; // The message queue.
    FActivted: TAtomBool; // False signals the thread to exit.
    FPool_Data_Ptr: TThread_Pool_Decl.PQueueStruct; // Pointer to this object in the pool's list.
    procedure ThRun(ThSender: TCompute); // Main execution loop.
  public
    constructor Create(Owner_: TThread_Pool); // Creates and starts the thread.
    destructor Destroy; override;

    property Post: TThreadPost read FPost; // The message queue.

    // Convenience methods to post tasks to this thread (C, M, P versions).
    procedure PostC1(OnSync: TThreadPost_C1); overload;
    procedure PostC1(OnSync: TThreadPost_C1; IsRuning_, IsExit_: PBoolean); overload;
    procedure PostC2(Data1: Pointer; OnSync: TThreadPost_C2); overload;
    procedure PostC2(Data1: Pointer; OnSync: TThreadPost_C2; IsRuning_, IsExit_: PBoolean); overload;
    procedure PostC3(Data1: Pointer; Data2: TCore_Object; Data3: Variant; OnSync: TThreadPost_C3); overload;
    procedure PostC3(Data1: Pointer; Data2: TCore_Object; Data3: Variant; OnSync: TThreadPost_C3; IsRuning_, IsExit_: PBoolean); overload;
    procedure PostC4(Data1: Pointer; Data2: TCore_Object; OnSync: TThreadPost_C4); overload;
    procedure PostC4(Data1: Pointer; Data2: TCore_Object; OnSync: TThreadPost_C4; IsRuning_, IsExit_: PBoolean); overload;

    procedure PostM1(OnSync: TThreadPost_M1); overload;
    procedure PostM1(OnSync: TThreadPost_M1; IsRuning_, IsExit_: PBoolean); overload;
    procedure PostM2(Data1: Pointer; OnSync: TThreadPost_M2); overload;
    procedure PostM2(Data1: Pointer; OnSync: TThreadPost_M2; IsRuning_, IsExit_: PBoolean); overload;
    procedure PostM3(Data1: Pointer; Data2: TCore_Object; Data3: Variant; OnSync: TThreadPost_M3); overload;
    procedure PostM3(Data1: Pointer; Data2: TCore_Object; Data3: Variant; OnSync: TThreadPost_M3; IsRuning_, IsExit_: PBoolean); overload;
    procedure PostM4(Data1: Pointer; Data2: TCore_Object; OnSync: TThreadPost_M4); overload;
    procedure PostM4(Data1: Pointer; Data2: TCore_Object; OnSync: TThreadPost_M4; IsRuning_, IsExit_: PBoolean); overload;

    procedure PostP1(OnSync: TThreadPost_P1); overload;
    procedure PostP1(OnSync: TThreadPost_P1; IsRuning_, IsExit_: PBoolean); overload;
    procedure PostP2(Data1: Pointer; OnSync: TThreadPost_P2); overload;
    procedure PostP2(Data1: Pointer; OnSync: TThreadPost_P2; IsRuning_, IsExit_: PBoolean); overload;
    procedure PostP3(Data1: Pointer; Data2: TCore_Object; Data3: Variant; OnSync: TThreadPost_P3); overload;
    procedure PostP3(Data1: Pointer; Data2: TCore_Object; Data3: Variant; OnSync: TThreadPost_P3; IsRuning_, IsExit_: PBoolean); overload;
    procedure PostP4(Data1: Pointer; Data2: TCore_Object; OnSync: TThreadPost_P4); overload;
    procedure PostP4(Data1: Pointer; Data2: TCore_Object; OnSync: TThreadPost_P4; IsRuning_, IsExit_: PBoolean); overload;
  end;

  { Global test callback – does nothing. }
procedure Test_IOData__C(Sender: TIO_Thread_Data);

implementation

uses Z.Notify;

procedure Test_IOData__C(Sender: TIO_Thread_Data);
begin
  // Intentionally empty – used for unit testing.
end;

{ TIO_Thread_Data }

constructor TIO_Thread_Data.Create;
{ *
  * Initialises the task to idsInited state with no callbacks.
}
begin
  inherited Create;
  FState := idsInited;
  FOn_C := nil;
  FOn_M := nil;
  FOn_P := nil;
  Data := nil;
end;

destructor TIO_Thread_Data.Destroy;
begin
  inherited Destroy;
end;

procedure TIO_Thread_Data.Process;
{ *
  * Executes the assigned callback (C, M, or P) in priority order:
  *   C > M > P.
  * Any exceptions are silently ignored.
}
begin
  try
    if Assigned(FOn_C) then
        FOn_C(Self)
    else if Assigned(FOn_M) then
        FOn_M(Self)
    else if Assigned(FOn_P) then
        FOn_P(Self);
  except
  end;
end;

{ TIO_Thread }

procedure TIO_Thread.ThRun(Sender: TCompute);
{ *
  * Worker thread main loop.
  * It scans the queue for tasks in idsReady state. When found, it marks them
  * as idsRunning, executes Process, then marks as idsDone and moves them to
  * the done queue. If no tasks are available, it sleeps for a short time.
  * The loop runs until FThRunning becomes False.
}
var
  d: TIO_Thread_Data;
  LTK, L: TTimeTick;
  p: TIO_Thread_Queue.POrderStruct;
begin
  Sender.Thread_Info := ClassName;

  AtomInc(FThNum);
  LTK := GetTimeTick();
  while FThRunning.V do
    begin
      FCritical.Lock;
      d := nil;

      // Clear any tasks already marked as done from the front of the main queue.
      while (FQueue.First <> nil) and (FQueue.First^.Data.FState = idsDone) do
        begin
          FDoneQueue.Push(FQueue.First^.Data);
          FQueue.Next;
        end;

      // Find the first task in the queue that is ready.
      p := FQueue.First;
      while p <> nil do
        begin
          if p^.Data.FState = idsReady then
            begin
              d := p^.Data;
              break;
            end;
          p := p^.Next;
        end;

      if d <> nil then
        begin
          d.FState := idsRunning;
          FCritical.UnLock;
          d.Process;
          FCritical.Lock;
          d.FState := idsDone;
          FCritical.UnLock;
          LTK := GetTimeTick();
        end
      else
        begin
          FCritical.UnLock;
          L := GetTimeTick() - LTK;
          if L > 100 then
              TCompute.Sleep(10)
          else
              TCompute.Sleep(1);
        end;
    end;
  AtomDec(FThNum);
end;

constructor TIO_Thread.Create(ThNum_: Integer);
{ *
  * Creates a pool of ThNum_ worker threads.
  * The threads start immediately and begin scanning the queue.
}
var
  n, i: Integer;
begin
  inherited Create;
  FCritical := TCritical.Create('TIO_Thread.FCritical');
  FThRunning := TAtomBool.Create(True);
  FThNum := 0;
  FQueue := TIO_Thread_Queue.Create;
  FDoneQueue := TIO_Thread_Queue.Create;

  n := if_(ThNum_ < 2, 1, ThNum_);

  for i := 0 to n - 1 do
      TCompute.RunM(nil, nil, ThRun);
  while FThNum < n do
      TCompute.Sleep(1);
end;

destructor TIO_Thread.Destroy;
begin
  ThEnd();
  FCritical.Free;
  FThRunning.Free;
  DisposeObject(FQueue);
  DisposeObject(FDoneQueue);
  inherited Destroy;
end;

procedure TIO_Thread.Reset;
{ *
  * Stops all current workers and re‑creates the same number of new ones.
  * This is useful after a catastrophic error or to clear stale state.
}
var
  n, i: Integer;
begin
  n := FThNum;
  ThEnd();
  FThNum := 0;
  for i := 0 to n - 1 do
      TCompute.RunM(nil, nil, ThRun);
  while FThNum < n do
      TCompute.Sleep(1);
end;

procedure TIO_Thread.ThEnd();
{ *
  * Signals all workers to exit, waits for them to finish, and clears both queues.
}
begin
  FThRunning.V := False;
  while FThNum > 0 do
      TCompute.Sleep(1);
  FCritical.Lock;
  FQueue.Clear;
  FDoneQueue.Clear;
  FCritical.UnLock;
end;

function TIO_Thread.QueueCount(): Integer;
begin
  FCritical.Lock;
  Result := FQueue.Num;
  FCritical.UnLock;
end;

function TIO_Thread.DoneCount(): Integer;
begin
  FCritical.Lock;
  Result := FDoneQueue.Num;
  FCritical.UnLock;
end;

function TIO_Thread.Count(): Integer;
begin
  FCritical.Lock;
  Result := FQueue.Num + FDoneQueue.Num;
  FCritical.UnLock;
end;

procedure TIO_Thread.Enqueue(IOData: TIO_Thread_Data);
{ *
  * Adds a task to the ready queue. The task must be in idsInited state.
  * After enqueuing, its state becomes idsReady.
}
begin
  if IOData.FState <> idsInited then
      RaiseInfo('illegal error.');
  IOData.FState := idsReady;
  FCritical.Lock;
  FQueue.Push(IOData);
  FCritical.UnLock;
end;

procedure TIO_Thread.Enqueue_C(IOData: TIO_Thread_Data; Data: Pointer; On_C: TIO_Thread_On_C);
{ *
  * Convenience: sets IOData.Data and FOn_C, then enqueues it.
}
begin
  IOData.Data := Data;
  IOData.FOn_C := On_C;
  Enqueue(IOData);
end;

procedure TIO_Thread.Enqueue_M(IOData: TIO_Thread_Data; Data: Pointer; On_M: TIO_Thread_On_M);
begin
  IOData.Data := Data;
  IOData.FOn_M := On_M;
  Enqueue(IOData);
end;

procedure TIO_Thread.Enqueue_P(IOData: TIO_Thread_Data; Data: Pointer; On_P: TIO_Thread_On_P);
begin
  IOData.Data := Data;
  IOData.FOn_P := On_P;
  Enqueue(IOData);
end;

function TIO_Thread.Dequeue(): TIO_Thread_Data;
{ *
  * Retrieves a finished task from the done queue.
  * Returns nil if the done queue is empty.
  * The caller is responsible for freeing the task.
}
begin
  Result := nil;
  FCritical.Lock;
  if FDoneQueue.Num > 0 then
    begin
      Result := FDoneQueue.First^.Data;
      FDoneQueue.Next;
    end;
  FCritical.UnLock;
end;

procedure TIO_Thread.Wait;
{ *
  * Busy‑waits until both queues are empty.
  * This is a blocking call; use with care in the main thread.
}
begin
  while Count > 0 do
      TCompute.Sleep(1);
end;

class procedure TIO_Thread.Test();
{ *
  * Enqueues 1,000,000 tasks, each with a sequential integer as Data.
  * Then dequeues and verifies that they come out in the correct order.
  * If the order is incorrect, an exception is raised.
}
var
  i, j: Integer;
  d: TIO_Thread_Data;
begin
  with TIO_Thread.Create(Get_Parallel_Granularity) do
    begin
      for i := 1 to 1000000 do
          Enqueue_C(TIO_Thread_Data.Create, Pointer(i), Test_IOData__C);

      j := 1;
      while Count > 0 do
        begin
          d := Dequeue();
          if d <> nil then
            begin
              if Integer(d.Data) = j then
                  inc(j)
              else
                  RaiseInfo('IO Thread test error.');
              d.Free;
            end;
        end;
      Free;
    end;
end;

{ TIO_Direct }

constructor TIO_Direct.Create;
begin
  inherited Create;
  FCritical := TCritical.Create('TIO_Direct.FCritical');
  FQueue := TIO_Thread_Queue.Create;
end;

destructor TIO_Direct.Destroy;
begin
  Reset;
  FCritical.Free;
  DisposeObject(FQueue);
  inherited Destroy;
end;

procedure TIO_Direct.Reset;
{ * Clears the queue of finished tasks. }
begin
  FCritical.Lock;
  FQueue.Clear;
  FCritical.UnLock;
end;

function TIO_Direct.Count: Integer;
begin
  FCritical.Lock;
  Result := FQueue.Num;
  FCritical.UnLock;
end;

procedure TIO_Direct.Enqueue(IOData: TIO_Thread_Data);
{ *
  * Immediately executes the task on the calling thread, then places it
  * into the done queue. The task is marked idsRunning during execution
  * and idsDone afterwards.
}
begin
  if IOData.FState <> idsInited then
      RaiseInfo('illegal error.');

  IOData.FState := idsRunning;
  IOData.Process;
  IOData.FState := idsDone;
  FCritical.Lock;
  FQueue.Push(IOData);
  FCritical.UnLock;
end;

procedure TIO_Direct.Enqueue_C(IOData: TIO_Thread_Data; Data: Pointer; On_C: TIO_Thread_On_C);
begin
  IOData.Data := Data;
  IOData.FOn_C := On_C;
  Enqueue(IOData);
end;

procedure TIO_Direct.Enqueue_M(IOData: TIO_Thread_Data; Data: Pointer; On_M: TIO_Thread_On_M);
begin
  IOData.Data := Data;
  IOData.FOn_M := On_M;
  Enqueue(IOData);
end;

procedure TIO_Direct.Enqueue_P(IOData: TIO_Thread_Data; Data: Pointer; On_P: TIO_Thread_On_P);
begin
  IOData.Data := Data;
  IOData.FOn_P := On_P;
  Enqueue(IOData);
end;

function TIO_Direct.Dequeue(): TIO_Thread_Data;
{ *
  * Retrieves a finished task from the internal queue.
  * Returns nil if none.
}
begin
  Result := nil;
  FCritical.Lock;
  if FQueue.Num > 0 then
    begin
      if FQueue.First^.Data.FState = idsDone then
        begin
          Result := FQueue.First^.Data;
          FQueue.Next;
        end;
    end;
  FCritical.UnLock;
end;

procedure TIO_Direct.Wait;
begin
  while Count > 0 do
      TCompute.Sleep(1);
end;

class procedure TIO_Direct.Test;
{ *
  * Enqueues 1,000,000 tasks and immediately dequeues and frees them
  * to verify the direct execution path.
}
var
  i: Integer;
  d: TIO_Thread_Data;
begin
  with TIO_Direct.Create do
    begin
      for i := 1 to 1000000 do
          Enqueue_C(TIO_Thread_Data.Create, nil, Test_IOData__C);
      while Count > 0 do
        begin
          d := Dequeue;
          if d <> nil then
              d.Free;
        end;
      Free;
    end;
end;

{ TThread_Pool }

constructor TThread_Pool.Create(ThNum_: Integer);
{ *
  * Creates ThNum_ dedicated threads, each running TThread_Event_Pool__.
  * The threads start immediately and are added to the internal list.
}
var
  i: Integer;
begin
  inherited Create;
  FCritical := TCritical.Create('TThread_Pool.FCritical');
  FQueueOptimized := True;

  for i := 0 to ThNum_ - 1 do
      TThread_Event_Pool__.Create(Self);

  while ThNum() < ThNum_ do
      TCompute.Sleep(1);
end;

destructor TThread_Pool.Destroy;
{ *
  * Waits for all tasks to finish, then signals all threads to exit and
  * waits for them to terminate.
}
var
  __Repeat__: TThread_Pool_Decl.TRepeat___;
begin
  Wait();

  if Num > 0 then
    begin
      FCritical.Lock;
      __Repeat__ := Repeat_;
      repeat
          __Repeat__.Queue^.Data.FActivted.V := False;
      until not __Repeat__.Next;
      FCritical.UnLock;
    end;

  while ThNum > 0 do
      TCompute.Sleep(1);

  DisposeObject(FCritical);
  inherited Destroy;
end;

function TThread_Pool.ThNum: NativeInt;
begin
  FCritical.Lock;
  Result := Num;
  FCritical.UnLock;
end;

function TThread_Pool.TaskNum: NativeInt;
{ *
  * Counts all pending tasks across all thread queues.
  * This is a linear scan and may be slow for many threads.
}
var
  R_: NativeInt;
begin
  R_ := 0;
  FCritical.Lock;
  try
    if Num > 0 then
      with Repeat_ do
        repeat
            inc(R_, Queue^.Data.FPost.Num);
        until not Next;
  finally
      FCritical.UnLock;
  end;
  Result := R_;
end;

procedure TThread_Pool.Wait;
{ * Busy‑waits until all tasks on all threads are processed. }
begin
  while TaskNum > 0 do
      TCompute.Sleep(1);
end;

procedure TThread_Pool.Wait(Th: TThread_Event_Pool__);
{ * Busy‑waits until the given thread's queue is empty. }
begin
  while Th.FPost.Count > 0 do
      TCompute.Sleep(1);
end;

function TThread_Pool.Next_Thread: TThread_Event_Pool__;
{ *
  * Returns the next thread in a round‑robin order.
  * The selected thread is moved to the end of the list to achieve fair rotation.
}
begin
  Result := nil;
  if Num > 0 then
    begin
      FCritical.Acquire;
      try
        Result := First^.Data;
        MoveToLast(First);
      finally
          FCritical.Release;
      end;
    end;
end;

function TThread_Pool.MinLoad_Thread: TThread_Event_Pool__;
{ *
  * Returns the thread with the fewest pending tasks.
  * This helps balance the load across threads.
}
var
  Eng_: PQueueStruct;
begin
  Result := nil;
  if Num > 0 then
    begin
      FCritical.Acquire;
      try
        Eng_ := nil;
        with Repeat_ do
          repeat
            if Eng_ = nil then
                Eng_ := Queue
            else if Queue^.Data.FPost.Num < Eng_^.Data.FPost.Num then
                Eng_ := Queue;
          until not Next;
        if Eng_ <> nil then
          begin
            Result := Eng_^.Data;
            MoveToLast(First);
          end;
      finally
          FCritical.Release;
      end;
    end;
end;

procedure TThread_Pool.DoTest_C;
{ * Dummy callback that sleeps 16 ms (used in unit test). }
begin
  TCompute.Sleep(16);
end;

class procedure TThread_Pool.Test;
{ *
  * Creates a pool with 2 threads, posts a few dummy tasks, and waits.
  * Tests both Next_Thread and MinLoad_Thread distribution.
}
var
  pool: TThread_Pool;
  i: Integer;
begin
  pool := TThread_Pool.Create(2);
  for i := 0 to 9 do
      pool.Next_Thread.PostM1(pool.DoTest_C);
  pool.Wait;
  for i := 0 to 9 do
      pool.MinLoad_Thread.PostM1(pool.DoTest_C);
  pool.Wait;
  DisposeObject(pool);
end;

{ TThread_Event_Pool__ }

procedure TThread_Event_Pool__.ThRun(ThSender: TCompute);
{ *
  * Main loop of a dedicated worker thread.
  * It processes its TThreadPost queue. When idle for more than 1 second,
  * it sleeps for 100 ms to reduce CPU usage.
  * When deactivated (FActivted = False), it removes itself from the pool,
  * frees its resources, and schedules itself for delayed destruction.
}
var
  L: NativeInt;
  Last_TK, IDLE_TK: TTimeTick;
begin
  ThSender.Thread_Info := ClassName;
  FBindTh := ThSender;
  FPost := TThreadPost.Create(ThSender.ThreadID);
  FPost.OneStep := False;
  FPost.ResetRandomSeed := False;
  FActivted := TAtomBool.Create(True);

  FOwner.FCritical.Lock;
  FPool_Data_Ptr := FOwner.Add(Self);
  FOwner.FCritical.UnLock;

  Last_TK := GetTimeTick();
  while FActivted.V do
    begin
      L := FPost.Progress(FPost.ThreadID);
      if L > 0 then
          Last_TK := GetTimeTick()
      else
        begin
          IDLE_TK := GetTimeTick() - Last_TK;
          if IDLE_TK > 1000 then
              TCompute.Sleep(100)
          else
              TCompute.Sleep(1);
        end;
    end;

  FOwner.FCritical.Lock;
  FOwner.Remove_P(FPool_Data_Ptr);
  FOwner.FCritical.UnLock;

  FBindTh := nil;
  DisposeObjectAndNil(FPost);
  DisposeObjectAndNil(FActivted);
  DelayFreeObj(1.0, Self);
end;

constructor TThread_Event_Pool__.Create(Owner_: TThread_Pool);
{ *
  * Creates and starts a background thread. The thread immediately begins
  * processing its message queue.
}
begin
  inherited Create;
  FOwner := Owner_;
  FBindTh := nil;
  FPost := nil;
  FActivted := nil;
  TCompute.RunM(nil, Self, ThRun);
end;

destructor TThread_Event_Pool__.Destroy;
begin
  inherited Destroy;
end;

{ The following Post* methods are thin wrappers around FPost (TThreadPost).
  They forward the call to the underlying thread's message queue.
  Overloaded versions with IsRuning_/IsExit_ allow the caller to monitor
  execution status. }

procedure TThread_Event_Pool__.PostC1(OnSync: TThreadPost_C1);
begin
  FPost.PostC1(OnSync);
end;

procedure TThread_Event_Pool__.PostC1(OnSync: TThreadPost_C1; IsRuning_, IsExit_: PBoolean);
begin
  FPost.PostC1(OnSync, IsRuning_, IsExit_);
end;

procedure TThread_Event_Pool__.PostC2(Data1: Pointer; OnSync: TThreadPost_C2);
begin
  FPost.PostC2(Data1, OnSync);
end;

procedure TThread_Event_Pool__.PostC2(Data1: Pointer; OnSync: TThreadPost_C2; IsRuning_, IsExit_: PBoolean);
begin
  FPost.PostC2(Data1, OnSync, IsRuning_, IsExit_);
end;

procedure TThread_Event_Pool__.PostC3(Data1: Pointer; Data2: TCore_Object; Data3: Variant; OnSync: TThreadPost_C3);
begin
  FPost.PostC3(Data1, Data2, Data3, OnSync);
end;

procedure TThread_Event_Pool__.PostC3(Data1: Pointer; Data2: TCore_Object; Data3: Variant; OnSync: TThreadPost_C3; IsRuning_, IsExit_: PBoolean);
begin
  FPost.PostC3(Data1, Data2, Data3, OnSync, IsRuning_, IsExit_);
end;

procedure TThread_Event_Pool__.PostC4(Data1: Pointer; Data2: TCore_Object; OnSync: TThreadPost_C4);
begin
  FPost.PostC4(Data1, Data2, OnSync);
end;

procedure TThread_Event_Pool__.PostC4(Data1: Pointer; Data2: TCore_Object; OnSync: TThreadPost_C4; IsRuning_, IsExit_: PBoolean);
begin
  FPost.PostC4(Data1, Data2, OnSync, IsRuning_, IsExit_);
end;

procedure TThread_Event_Pool__.PostM1(OnSync: TThreadPost_M1);
begin
  FPost.PostM1(OnSync);
end;

procedure TThread_Event_Pool__.PostM1(OnSync: TThreadPost_M1; IsRuning_, IsExit_: PBoolean);
begin
  FPost.PostM1(OnSync, IsRuning_, IsExit_);
end;

procedure TThread_Event_Pool__.PostM2(Data1: Pointer; OnSync: TThreadPost_M2);
begin
  FPost.PostM2(Data1, OnSync);
end;

procedure TThread_Event_Pool__.PostM2(Data1: Pointer; OnSync: TThreadPost_M2; IsRuning_, IsExit_: PBoolean);
begin
  FPost.PostM2(Data1, OnSync, IsRuning_, IsExit_);
end;

procedure TThread_Event_Pool__.PostM3(Data1: Pointer; Data2: TCore_Object; Data3: Variant; OnSync: TThreadPost_M3);
begin
  FPost.PostM3(Data1, Data2, Data3, OnSync);
end;

procedure TThread_Event_Pool__.PostM3(Data1: Pointer; Data2: TCore_Object; Data3: Variant; OnSync: TThreadPost_M3; IsRuning_, IsExit_: PBoolean);
begin
  FPost.PostM3(Data1, Data2, Data3, OnSync, IsRuning_, IsExit_);
end;

procedure TThread_Event_Pool__.PostM4(Data1: Pointer; Data2: TCore_Object; OnSync: TThreadPost_M4);
begin
  FPost.PostM4(Data1, Data2, OnSync);
end;

procedure TThread_Event_Pool__.PostM4(Data1: Pointer; Data2: TCore_Object; OnSync: TThreadPost_M4; IsRuning_, IsExit_: PBoolean);
begin
  FPost.PostM4(Data1, Data2, OnSync, IsRuning_, IsExit_);
end;

procedure TThread_Event_Pool__.PostP1(OnSync: TThreadPost_P1);
begin
  FPost.PostP1(OnSync);
end;

procedure TThread_Event_Pool__.PostP1(OnSync: TThreadPost_P1; IsRuning_, IsExit_: PBoolean);
begin
  FPost.PostP1(OnSync, IsRuning_, IsExit_);
end;

procedure TThread_Event_Pool__.PostP2(Data1: Pointer; OnSync: TThreadPost_P2);
begin
  FPost.PostP2(Data1, OnSync);
end;

procedure TThread_Event_Pool__.PostP2(Data1: Pointer; OnSync: TThreadPost_P2; IsRuning_, IsExit_: PBoolean);
begin
  FPost.PostP2(Data1, OnSync, IsRuning_, IsExit_);
end;

procedure TThread_Event_Pool__.PostP3(Data1: Pointer; Data2: TCore_Object; Data3: Variant; OnSync: TThreadPost_P3);
begin
  FPost.PostP3(Data1, Data2, Data3, OnSync);
end;

procedure TThread_Event_Pool__.PostP3(Data1: Pointer; Data2: TCore_Object; Data3: Variant; OnSync: TThreadPost_P3; IsRuning_, IsExit_: PBoolean);
begin
  FPost.PostP3(Data1, Data2, Data3, OnSync, IsRuning_, IsExit_);
end;

procedure TThread_Event_Pool__.PostP4(Data1: Pointer; Data2: TCore_Object; OnSync: TThreadPost_P4);
begin
  FPost.PostP4(Data1, Data2, OnSync);
end;

procedure TThread_Event_Pool__.PostP4(Data1: Pointer; Data2: TCore_Object; OnSync: TThreadPost_P4; IsRuning_, IsExit_: PBoolean);
begin
  FPost.PostP4(Data1, Data2, OnSync, IsRuning_, IsExit_);
end;

end.

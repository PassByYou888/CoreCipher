{ ******************************************************************************
  * Z.Expression.Sequence - Non-Blocking Sequential Expression Execution Engine
  *
  * This unit provides the ability to execute a sequence of expressions (code
  * lines) in a non-blocking, asynchronous manner. It leverages the non-linear
  * execution capabilities of TOpCode_NonLinear to allow each expression to
  * pause and resume (e.g., for delays, I/O, or external events) without
  * blocking the main thread.
  *
  * Architecture:
  *   - TExpression_Sequence: Container and controller for a list of runtime
  *     instances. It parses source text, checks syntax, runs the sequence,
  *     and drives progress.
  *   - TExpression_Sequence_RunTime: Represents a single expression instance.
  *     It holds the compiled non-linear OpCode, manages its execution state,
  *     and provides methods to begin, end, or error the operation.
  *   - TExpression_Sequence_Pool: A pool for managing multiple sequences,
  *     allowing centralized progress processing.
  *
  * Typical Use:
  *   1. Create a TExpression_Sequence instance.
  *   2. Call Extract_Code to load the script (text) into the sequence.
  *   3. Optionally call Check_Syntax to validate.
  *   4. Call Run to start execution.
  *   5. In the main loop, call Progress periodically to drive execution.
  *   6. Use Wait to block until completion (if needed).
  *
  * Asynchronous Support: Expressions can contain custom functions that call
  * Do_Begin (to pause) and later Do_End (to resume), enabling non-blocking
  * operations like delays, network waits, or user input.
  ****************************************************************************** }
unit Z.Expression.Sequence;

{$DEFINE FPC_DELPHI_MODE}
{$I Z.Define.inc}

interface

uses
  SysUtils, Variants, Math,
  Z.Core, TypInfo, Z.Parsing, Z.PascalStrings, Z.UPascalStrings, Z.UnicodeMixedLib,
  Z.Notify, Z.Status, Z.ListEngine, Z.Expression, Z.OpCode;

type
  TExpression_Sequence = class;
  TExpression_Sequence_RunTime = class;
  TExpression_Sequence_RunTime_Class = class of TExpression_Sequence_RunTime;

  { Event callbacks for sequence lifecycle }
  TOn_Expression_Sequence_Create_RunTime = procedure(Sender: TExpression_Sequence; NewRunTime: TExpression_Sequence_RunTime) of object;
  TOn_Expression_Sequence_Step = procedure(Sender: TExpression_Sequence; Current_Step: TExpression_Sequence_RunTime) of object;
  TOn_Expression_Sequence_Done = procedure(Sender: TExpression_Sequence) of object;

  {
    TExpression_Sequence manages a list of TExpression_Sequence_RunTime objects
    that represent sequential expressions. It orchestrates parsing, validation,
    execution, and progress monitoring.
  }
  TExpression_Sequence = class(TBig_Object_List<TExpression_Sequence_RunTime>)
  private
    FDebugMode: Boolean; { Enables debug output of executed expressions }
    FRun_Num, FRun_Done_Num: Integer; { Total runs initiated and completed }
    FFocus: TExpression_Sequence_RunTime; { Currently executing runtime instance }
    FError: Boolean; { True if any error occurred during execution }
    FPost___: TThreadPost; { Thread post dispatcher for main-thread tasks }
    FN_Progress: TCadencer_N_Progress_Tool; { Timer tool for delayed operations (e.g., Do_End) }
    FSequence_Class: TExpression_Sequence_RunTime_Class; { Class type used to create runtime instances }
    FOn_Expression_Sequence_Create_RunTime: TOn_Expression_Sequence_Create_RunTime;
    FOn_Expression_Sequence_Step: TOn_Expression_Sequence_Step;
    FOn_Expression_Sequence_Done: TOn_Expression_Sequence_Done;
    procedure Do_Step; virtual; { Advances to the next expression after current one finishes }
  public
    property DebugMode: Boolean read FDebugMode write FDebugMode;
    property Sequence_Class: TExpression_Sequence_RunTime_Class read FSequence_Class write FSequence_Class;
    property On_Expression_Sequence_Create_RunTime: TOn_Expression_Sequence_Create_RunTime read FOn_Expression_Sequence_Create_RunTime write FOn_Expression_Sequence_Create_RunTime;
    property On_Expression_Sequence_Step: TOn_Expression_Sequence_Step read FOn_Expression_Sequence_Step write FOn_Expression_Sequence_Step;
    property On_Expression_Sequence_Done: TOn_Expression_Sequence_Done read FOn_Expression_Sequence_Done write FOn_Expression_Sequence_Done;
    property Run_Num: Integer read FRun_Num;
    property Run_Done_Num: Integer read FRun_Done_Num;

    constructor Create;
    destructor Destroy; override;

    { Parses source code from a TCore_Strings list (each line is an expression or vector).
      Returns True if all lines are valid. }
    function Extract_Code(Style: TTextStyle; Code: TCore_Strings): Boolean; overload;

    { Parses source code from a single U_String (multi-line string).
      Returns True on success. }
    function Extract_Code(Style: TTextStyle; Code: U_String): Boolean; overload;

    { Validates the syntax of all parsed expressions without executing them.
      Returns True if all expressions are syntactically correct. }
    function Check_Syntax: Boolean;

    { Starts the execution of the sequence. If already running, does nothing. }
    procedure Run;

    { Blocks the calling thread until the sequence finishes execution. }
    procedure Wait;

    { Returns True if the sequence is currently executing. }
    function Is_Running: Boolean;

    { Returns True if any error occurred during execution. }
    property Is_Error: Boolean read FError;

    { Returns the currently executing runtime instance, or nil if idle. }
    property Focus: TExpression_Sequence_RunTime read FFocus;

    { Called internally when a sequence finishes; outputs debug info if DebugMode. }
    procedure Do_End; virtual;

    { Drives the execution progress of the sequence. Should be called in the main loop.
      Also processes posted tasks and timer events. }
    procedure Progress; virtual;

    { Provides access to the timer tool for scheduling delayed callbacks. }
    property Post_Progress: TCadencer_N_Progress_Tool read FN_Progress;
    property N_Progress: TCadencer_N_Progress_Tool read FN_Progress;

    { Unit test procedure demonstrating sequence execution with Direct and Delay functions. }
    class procedure Test();
  end;

  {
    TExpression_Sequence_Pool_ is the base list type for managing multiple
    TExpression_Sequence instances.
  }
  TExpression_Sequence_Pool_ = TBig_Object_List<TExpression_Sequence>;

  {
    TExpression_Sequence_Pool provides a centralized manager for multiple
    sequences, allowing them all to be progressed with a single call.
  }
  TExpression_Sequence_Pool = class(TExpression_Sequence_Pool_)
  public
    procedure Progress; { Calls Progress on every sequence in the pool }
  end;

  {
    TExpression_Sequence_RunTime represents a single expression within a sequence.
    It acts as the runtime context for the OpCode execution, handling the
    non-linear flow (pause/resume) and interfacing with the owner sequence.

    Each runtime instance can be paused via Do_Begin and resumed via Do_End,
    enabling asynchronous operations within a single expression.
  }
  TExpression_Sequence_RunTime = class(TOpCustomRunTime)
  private
    Queue_Data: TExpression_Sequence.PQueueStruct; { Pointer to this item in the owner's list }
    NonLinear_Tool: TOpCode_NonLinear; { Non-linear OpCode executor for the expression }
    Done: Boolean; { True when expression has completed successfully }
    Error: Boolean; { True when expression ended with an error }
    procedure Do_NonLinear_Done(Sender: TOpCode_NonLinear);
    procedure Do_Run__; { Thread-posted entry point to start execution }
    procedure Do_End__; { Thread-posted handler for successful completion }
    procedure Do_Error__; { Thread-posted handler for error completion }
  public
    Owner: TExpression_Sequence; { The sequence that owns this runtime }
    Line: Integer; { Source line number (for debugging) }
    Style: TTextStyle; { Text style (Pascal/C/XML) used for parsing }
    Code_: U_String; { The expression source code string }

    constructor Create(Owner_: TExpression_Sequence); virtual;
    destructor Destroy; override;

    { Override this method to register custom functions or APIs for this runtime.
      Called during construction. }
    procedure Reg_RunTime; virtual;

    { Starts the execution of the expression. This method is non-blocking;
      the actual work is performed by the NonLinear_Tool. }
    procedure Do_Run;

    { Pauses execution and enters a waiting state. Must be paired with a later
      Do_End call to resume. }
    procedure Do_Begin;

    { Resumes execution after a pause, marking the expression as completed successfully. }
    procedure Do_End; overload;

    { Resumes execution and sets the result value. }
    procedure Do_End(Result_: Variant); overload;

    { Alias for Do_End(Result_) }
    procedure Do_End_And_Result(Result_: Variant);

    { Returns True if the expression is currently executing (not yet done). }
    function Running: Boolean;

    { Returns True if the expression is waiting for Do_End to be called. }
    function Is_Wait_End: Boolean;

    { Gets/Sets the result value of the expression. }
    function Get_Code_Result: Variant;
    procedure Set_Code_Result(Value: Variant);
    property Code_Result: Variant read Get_Code_Result write Set_Code_Result;
    property Enb_Result: Variant read Get_Code_Result write Set_Code_Result;
    property Result_: Variant read Get_Code_Result write Set_Code_Result;

    { Signals an error and terminates the expression abnormally. }
    procedure Do_Error;

    { Drives the non-linear execution progress. Should be called periodically. }
    procedure Progress; virtual;
  end;

  {
    TTest_Expression_Sequence_RunTime is a demonstration subclass that registers
    two custom functions:
    - Direct: executes immediately.
    - Delay: delays for a specified number of seconds before completing.
  }
  TTest_Expression_Sequence_RunTime = class(TExpression_Sequence_RunTime)
  public
    function OP_Test_Direct_Execute(Sender: TOpCustomRunTime; OP_RT_Data: POpRTData; OP_Code: TOpCode; var OP_Param: TOpParam): Variant;
    function OP_Test_Delay_Execute(Sender: TOpCustomRunTime; OP_RT_Data: POpRTData; OP_Code: TOpCode; var OP_Param: TOpParam): Variant;
    procedure Reg_RunTime; override;
  end;

implementation

procedure TExpression_Sequence.Do_Step;
begin
  if FFocus = nil then
      exit;
  if FFocus.Running then
      exit;
  if FFocus.Error then
    begin
      FError := True;
      FFocus := nil;
      exit;
    end;

  if FFocus.Done then
    begin
      if Assigned(FOn_Expression_Sequence_Step) then
          FOn_Expression_Sequence_Step(self, FFocus);

      if FFocus.Queue_Data <> Last then
        begin
          FFocus := FFocus.Queue_Data^.Next^.Data;
          FFocus.Do_Run;
        end
      else
        begin
          FFocus := nil;
          Inc(FRun_Done_Num);
          Do_End();
          if Assigned(FOn_Expression_Sequence_Done) then
              FOn_Expression_Sequence_Done(self);
        end;
    end;
end;

constructor TExpression_Sequence.Create;
begin
  inherited Create(True);
  FDebugMode := {$IFDEF Print_OPCode_Debug}True{$ELSE Print_OPCode_Debug}False{$ENDIF Print_OPCode_Debug};
  FRun_Num := 0;
  FRun_Done_Num := 0;
  FFocus := nil;
  FError := False;
  FPost___ := TThreadPost.Create(0);
  FN_Progress := TCadencer_N_Progress_Tool.Create;
  FSequence_Class := TExpression_Sequence_RunTime;
  FOn_Expression_Sequence_Create_RunTime := nil;
  FOn_Expression_Sequence_Step := nil;
  FOn_Expression_Sequence_Done := nil;
end;

destructor TExpression_Sequence.Destroy;
begin
  DisposeObject(FPost___);
  DisposeObject(FN_Progress);
  inherited Destroy;
end;

function TExpression_Sequence.Extract_Code(Style: TTextStyle; Code: TCore_Strings): Boolean;
var
  i, j: Integer;
  inst: TExpression_Sequence_RunTime;
  n: U_String;
  T: TTextParsing;
  L: TPascalStringList;
begin
  FRun_Num := 0;
  FRun_Done_Num := 0;
  Result := False;
  for i := 0 to Code.Count - 1 do
    begin
      n := Code[i];
      if IsNullExpression(n, Style) then
          continue;
      if IsSymbolVectorExpression(n, Style) then
        begin
          T := TTextParsing.Create(n, Style, nil, SpacerSymbol.V);
          L := TPascalStringList.Create;
          if T.Extract_Symbol_Vector(L) then
            begin
              for j := 0 to L.Count - 1 do
                begin
                  inst := FSequence_Class.Create(self);
                  inst.Line := i;
                  inst.Style := Style;
                  inst.Code_ := L[j];
                  inst.Queue_Data := Add(inst);
                  if Assigned(FOn_Expression_Sequence_Create_RunTime) then
                      FOn_Expression_Sequence_Create_RunTime(self, inst);
                end;
              DisposeObject(T);
              DisposeObject(L);
            end
          else
            begin
              DisposeObject(T);
              DisposeObject(L);
              DoStatus('error line:%d, code: %s', [i, n.Text]);
              exit;
            end;
        end
      else
        begin
          inst := FSequence_Class.Create(self);
          inst.Line := i;
          inst.Style := Style;
          inst.Code_ := n;
          inst.Queue_Data := Add(inst);
          if Assigned(FOn_Expression_Sequence_Create_RunTime) then
              FOn_Expression_Sequence_Create_RunTime(self, inst);
        end;
    end;
  Result := True;
end;

function TExpression_Sequence.Extract_Code(Style: TTextStyle; Code: U_String): Boolean;
var
  tmp: TCore_Strings;
begin
  tmp := TCore_StringList.Create;
  tmp.Text := Code;
  Result := Extract_Code(Style, tmp);
  DisposeObject(tmp);
end;

function TExpression_Sequence.Check_Syntax: Boolean;
var
  tmp: TSymbolExpression;
begin
  Result := True;
  if Num > 0 then
    begin
      with repeat_ do
        repeat
          tmp := ParseTextExpressionAsSymbol(queue^.Data.Style, '', queue^.Data.Code_, nil, queue^.Data);
          if tmp <> nil then
              DisposeObjectAndNil(tmp)
          else
            begin
              Result := False;
              exit;
            end;
        until not Next;
    end;
end;

procedure TExpression_Sequence.Run;
var
  i: Integer;
begin
  if Is_Running then
      exit;

  Inc(FRun_Num);

  // reset error state
  FError := False;

  if Num > 0 then
    begin
      with repeat_ do
        repeat
          queue^.Data.Done := False;
          queue^.Data.Error := False;
        until not Next;

      FFocus := First^.Data;
      FFocus.Do_Run;
    end;
end;

procedure TExpression_Sequence.Wait;
begin
  while Is_Running do
      Progress();
end;

function TExpression_Sequence.Is_Running: Boolean;
begin
  Result := FFocus <> nil;
end;

procedure TExpression_Sequence.Do_End;
begin
  if not FDebugMode then
      exit;
  if Num > 0 then
    with repeat_ do
      repeat
          DoStatus('%s = %s', [queue^.Data.Code_.Text, VarToStr(queue^.Data.Code_Result)]);
      until not Next;
end;

procedure TExpression_Sequence.Progress;
begin
  if (FFocus <> nil) and (Num > 0) then
      FFocus.Progress;
  FPost___.Progress(FPost___.ThreadID);
  FN_Progress.Progress;
end;

class procedure TExpression_Sequence.Test;
var
  L: TCore_Strings;
  inst: TExpression_Sequence;
begin
  L := TCore_StringList.Create;
  L.Add('Direct()');
  L.Add('Delay()');
  L.Add('Direct()');
  L.Add('Delay()');
  L.Add('Direct(),Delay(1.1),Delay(1.2),Direct()');
  inst := TExpression_Sequence.Create;
  inst.DebugMode := True;
  inst.Sequence_Class := TTest_Expression_Sequence_RunTime;
  inst.Extract_Code(tsPascal, L);
  DoStatus('Check_Syntax=%s', [umlBoolToStr(inst.Check_Syntax()).Text]);
  DisposeObject(L);
  inst.Run;
  inst.Wait();
  DisposeObject(inst);
end;

procedure TExpression_Sequence_Pool.Progress;
begin
  if Num > 0 then
    with repeat_ do
      repeat
          queue^.Data.Progress;
      until not Next;
end;

procedure TExpression_Sequence_RunTime.Do_NonLinear_Done(Sender: TOpCode_NonLinear);
begin
  if VarIsNull(Code_Result) then
      Owner.FPost___.PostM1(Do_Error__)
  else
      Owner.FPost___.PostM1(Do_End__);
end;

procedure TExpression_Sequence_RunTime.Do_Run__;
begin
  if Owner.FDebugMode then
      DoStatus('Debug Mode ' + Code_);
  Done := False;
  Error := False;
  if NonLinear_Tool = nil then
    begin
      NonLinear_Tool := TOpCode_NonLinear.Create_From_Expression(Style, Code_, self);
      NonLinear_Tool.On_Done_M := Do_NonLinear_Done;
    end
  else
    begin
      NonLinear_Tool.Reinit;
    end;
  NonLinear_Tool.Execute;
end;

procedure TExpression_Sequence_RunTime.Do_End__;
begin
  Done := True;
  Error := False;
  Owner.Do_Step;
end;

procedure TExpression_Sequence_RunTime.Do_Error__;
begin
  Done := False;
  Error := True;
  DoStatus('error line:%d, code: %s', [Line, Code_.Text]);
  Owner.Do_Step;
end;

constructor TExpression_Sequence_RunTime.Create(Owner_: TExpression_Sequence);
begin
  inherited CustomCreate($FF);
  Queue_Data := nil;
  NonLinear_Tool := nil;
  Done := False;
  Error := False;
  Owner := Owner_;
  Line := 0;
  Style := TTextStyle.tsPascal;
  Code_ := '';
  Reg_RunTime();
end;

destructor TExpression_Sequence_RunTime.Destroy;
begin
  Code_ := '';
  DisposeObjectAndNil(NonLinear_Tool);
  inherited Destroy;
end;

procedure TExpression_Sequence_RunTime.Reg_RunTime;
begin
end;

procedure TExpression_Sequence_RunTime.Do_Run;
begin
  Done := False;
  Error := False;
  Owner.FPost___.PostM1(Do_Run__);
end;

procedure TExpression_Sequence_RunTime.Do_Begin;
begin
  NonLinear_Tool.Do_Begin;
end;

procedure TExpression_Sequence_RunTime.Do_End;
begin
  NonLinear_Tool.Do_End;
end;

procedure TExpression_Sequence_RunTime.Do_End(Result_: Variant);
begin
  NonLinear_Tool.Do_End(Result_);
end;

procedure TExpression_Sequence_RunTime.Do_End_And_Result(Result_: Variant);
begin
  Do_End(Result_);
end;

function TExpression_Sequence_RunTime.Running: Boolean;
begin
  if NonLinear_Tool <> nil then
      Result := NonLinear_Tool.Is_Running
  else
      Result := False;
end;

function TExpression_Sequence_RunTime.Is_Wait_End: Boolean;
begin
  if NonLinear_Tool <> nil then
      Result := NonLinear_Tool.Is_Wait_End
  else
      Result := False;
end;

function TExpression_Sequence_RunTime.Get_Code_Result: Variant;
begin
  if NonLinear_Tool <> nil then
      Result := NonLinear_Tool.Result_
  else
      Result := NULL;
end;

procedure TExpression_Sequence_RunTime.Set_Code_Result(Value: Variant);
begin
  if NonLinear_Tool <> nil then
      NonLinear_Tool.Result_ := Value;
end;

procedure TExpression_Sequence_RunTime.Do_Error;
begin
  NonLinear_Tool.Do_Error;
end;

procedure TExpression_Sequence_RunTime.Progress;
begin
  if NonLinear_Tool <> nil then
      NonLinear_Tool.Process;
end;

function TTest_Expression_Sequence_RunTime.OP_Test_Direct_Execute(Sender: TOpCustomRunTime; OP_RT_Data: POpRTData; OP_Code: TOpCode; var OP_Param: TOpParam): Variant;
begin
  Do_Begin();
  Result := 1;
  Do_End();
end;

function TTest_Expression_Sequence_RunTime.OP_Test_Delay_Execute(Sender: TOpCustomRunTime; OP_RT_Data: POpRTData; OP_Code: TOpCode; var OP_Param: TOpParam): Variant;
var
  d: Double;
begin
  Do_Begin();
  Result := 2;
  if length(OP_Param) > 0 then
      d := OP_Param[0]
  else
      d := 1.0;
  Owner.Post_Progress.PostExecuteM_NP(d, Do_End);
end;

procedure TTest_Expression_Sequence_RunTime.Reg_RunTime;
begin
  inherited Reg_RunTime;
  Reg_Code_OpM('Direct', '', OP_Test_Direct_Execute);
  Reg_Code_OpM('Delay', '', OP_Test_Delay_Execute);
end;

end.

var
  Simulator_Main_Thread_Activted___: Boolean = False;

type
  TSimulator_Main_Thread = class
  public
    Running: Boolean;
    bak_ThreadID: TThreadID;
    bak_Thread: TCore_Thread;
    Simulator_Main_Proc: TOnSynchronize_C_NP;
    constructor Create(Simulator_Main_Proc_: TOnSynchronize_C_NP);
    procedure Do_Execute_Main_Thread(Sender: TCompute);
  end;

constructor TSimulator_Main_Thread.Create(Simulator_Main_Proc_: TOnSynchronize_C_NP);
begin
  if (not Main_Thread_Soft_Synchronize) or (Simulator_Main_Thread_Activted___) then
      RaiseInfo('Main-Thread Simulator error!');
  inherited Create;
  Running := False;
  MainThreadProgress.Progress();
  Do_Check_System_Thread_Synchronize(0, True);
  bak_ThreadID := Main_Thread_ID;
  bak_Thread := Main_Thread;
  Simulator_Main_Proc := Simulator_Main_Proc_;
  Simulator_Main_Thread_Activted___ := True;
  On_Check_System_Thread_Synchronize := Do_Check_Soft_Thread_Synchronize; // close Check_System_Thread_Synchronize
  CPS_Check_Soft_Thread.Reset;
  CPS_Check_System_Thread.Reset;
  TCompute.RunM(nil, nil, Do_Execute_Main_Thread, @Simulator_Main_Thread_Activted___, nil);
end;

procedure TSimulator_Main_Thread.Do_Execute_Main_Thread(Sender: TCompute);
begin
  TCompute.Set_Thread_Info('Main-Thread Simulator');
  Main_Thread_ID := Sender.ThreadID;
  Main_Thread := Sender;
  MainThreadProgress.ThreadID := Sender.ThreadID;
  Main_Thread_Sync_Tool.Soft_Synchronize_Main_Thread := Sender;
  try
      Simulator_Main_Proc();
  except
  end;
  Do_Check_Soft_Thread_Synchronize(100, True);
  Main_Thread_ID := bak_ThreadID;
  Main_Thread := bak_Thread;
  MainThreadProgress.ThreadID := Main_Thread_ID;
  Main_Thread_Sync_Tool.Soft_Synchronize_Main_Thread := Main_Thread;
  On_Check_System_Thread_Synchronize := Do_Check_System_Thread_Synchronize; // open Check_System_Thread_Synchronize
  CPS_Check_Soft_Thread.Reset;
  CPS_Check_System_Thread.Reset;
  Free;
end;

procedure Begin_Simulator_Main_Thread(Simulator_Main_Proc_: TOnSynchronize_C_NP);
begin
  if not Simulator_Main_Thread_Activted___ then
      TSimulator_Main_Thread.Create(Simulator_Main_Proc_);
end;

function Simulator_Main_Thread_Activted: Boolean;
begin
  Result := Simulator_Main_Thread_Activted___;
end;

constructor TSoft_Synchronize_Tool.Create(Soft_Synchronize_Main_Thread_: TCore_Thread);
begin
  inherited Create;
  SyncQueue__ := TSynchronize_Queue___.Create;
  Critical__ := TCritical.Create(ClassName + '.Critical__');
  Soft_Synchronize_Main_Thread := Soft_Synchronize_Main_Thread_;
end;

destructor TSoft_Synchronize_Tool.Destroy;
begin
  DisposeObjectAndNil(SyncQueue__);
  DisposeObjectAndNil(Critical__);
  inherited Destroy;
end;

function TSoft_Synchronize_Tool.Check_Synchronize(Check_Time_: TTimeTick): NativeInt;
var
  tk: TTimeTick;
  Temp_SyncQueue__: TSynchronize_Queue___;
  sync_: PSynchronize_Data___;
begin
  Result := 0;
  if (TCore_Thread.CurrentThread <> Soft_Synchronize_Main_Thread) then
      exit;

  if Check_Time_ > 0 then tk := GetTimeTick
  else tk := 0;

  Temp_SyncQueue__ := TSynchronize_Queue___.Create;
  while True do
    begin
      Critical__.Lock;
      Temp_SyncQueue__.SwapInstance(SyncQueue__);
      Critical__.UnLock;

      while Temp_SyncQueue__.Num > 0 do
        begin
          sync_ := Temp_SyncQueue__.First^.Data;
          try
            if Assigned(sync_^.Primary) then
                sync_^.Primary()
            else if Assigned(sync_^.Second) then
                sync_^.Second()
            else if Assigned(sync_^.Third) then
                sync_^.Third();
          except
          end;
          sync_^.Fourth := False;
          inc(Result);
          Temp_SyncQueue__.Next;
        end;

      if Check_Time_ = 0 then break;
      if GetTimeTick - tk > Check_Time_ then break;
      TCompute.Sleep(1);
    end;
  DisposeObject(Temp_SyncQueue__);
end;

procedure TSoft_Synchronize_Tool.Synchronize(OnSync: TOnSynchronize_P_NP);
begin
  Synchronize_P(TCore_Thread.CurrentThread, OnSync);
end;

procedure TSoft_Synchronize_Tool.Synchronize_C(OnSync: TOnSynchronize_C_NP);
begin
  Synchronize_C(TCore_Thread.CurrentThread, OnSync);
end;

procedure TSoft_Synchronize_Tool.Synchronize_M(OnSync: TOnSynchronize_M_NP);
begin
  Synchronize_M(TCore_Thread.CurrentThread, OnSync);
end;

procedure TSoft_Synchronize_Tool.Synchronize_P(OnSync: TOnSynchronize_P_NP);
begin
  Synchronize_P(TCore_Thread.CurrentThread, OnSync);
end;

procedure TSoft_Synchronize_Tool.Synchronize(Thread_: TCore_Thread; OnSync: TOnSynchronize_P_NP);
begin
  Synchronize_P(Thread_, OnSync);
end;

procedure TSoft_Synchronize_Tool.Synchronize_C(Thread_: TCore_Thread; OnSync: TOnSynchronize_C_NP);
var
  tmp: TSynchronize_Data___;
begin
  if Thread_ = Soft_Synchronize_Main_Thread then
    begin
      try
        Check_Synchronize(0);
        OnSync();
      except
      end;
    end
  else
    begin
      tmp := TSynchronize_Data___.Init(OnSync, nil, nil, True);
      Critical__.Lock;
      SyncQueue__.Push(@tmp);
      Critical__.UnLock;
      while tmp.Fourth do
          TCompute.Sleep(1);
    end;
end;

procedure TSoft_Synchronize_Tool.Synchronize_M(Thread_: TCore_Thread; OnSync: TOnSynchronize_M_NP);
var
  tmp: TSynchronize_Data___;
begin
  if Thread_ = Soft_Synchronize_Main_Thread then
    begin
      try
        Check_Synchronize(0);
        OnSync();
      except
      end;
    end
  else
    begin
      tmp := TSynchronize_Data___.Init(nil, OnSync, nil, True);
      Critical__.Lock;
      SyncQueue__.Push(@tmp);
      Critical__.UnLock;
      while tmp.Fourth do
          TCompute.Sleep(1);
    end;
end;

procedure TSoft_Synchronize_Tool.Synchronize_P(Thread_: TCore_Thread; OnSync: TOnSynchronize_P_NP);
var
  tmp: TSynchronize_Data___;
begin
  if Thread_ = Soft_Synchronize_Main_Thread then
    begin
      try
        Check_Synchronize(0);
        OnSync();
      except
      end;
    end
  else
    begin
      tmp := TSynchronize_Data___.Init(nil, nil, OnSync, True);
      Critical__.Lock;
      SyncQueue__.Push(@tmp);
      Critical__.UnLock;
      while tmp.Fourth do
          TCompute.Sleep(1);
    end;
end;

function Do_Check_Soft_Thread_Synchronize(Timeout: TTimeTick; Run_Hook_Event_: Boolean): Boolean;
begin
  Result := False;
  if Main_Thread_Soft_Synchronize then
    begin
      if (TCore_Thread.CurrentThread <> Main_Thread_Sync_Tool.Soft_Synchronize_Main_Thread) then
        begin
          if TCore_Thread.CurrentThread.ThreadID = MainThreadID then
              Result := CheckSynchronize(Timeout)
          else if Timeout > 0 then
              TCore_Thread.Sleep(Timeout);
        end
      else if not Main_Thread_Synchronize_Running then
        begin
          Main_Thread_Synchronize_Running := True;
          CPS_Check_Soft_Thread.Begin_Caller;
          MainThreadProgress.Progress(Main_Thread_ID);
          Timer_Event_Pool__.Progress();

          Main_Thread_Sync_Tool.Check_Synchronize(Timeout);

          if Run_Hook_Event_ then
            begin
              try
                if Assigned(OnCheckThreadSynchronize) then
                    OnCheckThreadSynchronize();
              except
              end;
            end;

          if Main_Thread_ID = MainThreadID then
            begin
              try
                  Result := CheckSynchronize(if_(Timeout > 0, 1, 0)) or Result;
              except
              end;
            end;

          CPS_Check_Soft_Thread.End_Caller;
          Main_Thread_Synchronize_Running := False;
        end;
    end
  else
      Result := Check_System_Thread_Synchronize(Timeout, Run_Hook_Event_);
end;

function Do_Check_System_Thread_Synchronize(Timeout: TTimeTick; Run_Hook_Event_: Boolean): Boolean;
begin
  Result := False;
  if (TCore_Thread.CurrentThread.ThreadID <> Main_Thread_ID) then
    begin
      if Main_Thread_Soft_Synchronize and (TCore_Thread.CurrentThread = Main_Thread_Sync_Tool.Soft_Synchronize_Main_Thread) then
          Result := (Main_Thread_Sync_Tool.Check_Synchronize(Timeout) > 0)
      else if Timeout > 0 then
          TCore_Thread.Sleep(Timeout);
    end
  else if Enabled_Check_Thread_Synchronize_System then
    begin
      if not Main_Thread_Synchronize_Running then
        begin
          Main_Thread_Synchronize_Running := True;

          CPS_Check_System_Thread.Begin_Caller;
          MainThreadProgress.Progress(Main_Thread_ID);
          Timer_Event_Pool__.Progress();

          if Main_Thread_ID = MainThreadID then
            begin
              try
                  Result := CheckSynchronize(Timeout);
              except
              end;
            end;

          if Main_Thread_Soft_Synchronize and (Main_Thread_Sync_Tool.Soft_Synchronize_Main_Thread = Main_Thread) then
            begin
              Result := (Main_Thread_Sync_Tool.Check_Synchronize(if_(Timeout > 0, 1, 0)) > 0) or Result;
            end;

          if Run_Hook_Event_ then
            begin
              try
                if Assigned(OnCheckThreadSynchronize) then
                    OnCheckThreadSynchronize();
              except
              end;
            end;

          CPS_Check_System_Thread.End_Caller;

          Main_Thread_Synchronize_Running := False;
        end;
    end;
end;


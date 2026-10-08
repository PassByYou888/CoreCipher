procedure TThreadPost.TThread_Post_Data.Init;
begin
  On_C1 := nil;
  On_C2 := nil;
  On_C3 := nil;
  On_C4 := nil;
  On_M1 := nil;
  On_M2 := nil;
  On_M3 := nil;
  On_M4 := nil;
  On_P1 := nil;
  On_P2 := nil;
  On_P3 := nil;
  On_P4 := nil;
  Data1 := nil;
  Data2 := nil;
  Data3 := NULL;
  IsRuning := nil;
  IsExit := nil;
end;

procedure TThreadPost.FreeThreadProgressPostData(p: TThread_Post_Data_Order_Struct__.PT_);
begin
  Dispose(p);
end;

constructor TThreadPost.Create(ThreadID_: TThreadID);
begin
  inherited Create;
  FCritical := TCritical.Create('TThreadPost.FCritical');
  FThreadID := ThreadID_;
  FSyncPool := TThread_Post_Data_Order_Struct__.Create;
  FSyncPool.OnFree := FreeThreadProgressPostData;
  FProgressing := TAtomBool.Create(False);
  FOneStep := True;
  FResetRandomSeed := False;
end;

destructor TThreadPost.Destroy;
begin
  FCritical.Acquire;
  FSyncPool.Clear;
  FSyncPool.Clear;
  FCritical.Release;
  DisposeObject(FSyncPool);
  FCritical.Free;
  FProgressing.Free;
  inherited Destroy;
end;

function TThreadPost.Count: NativeInt;
begin
  FCritical.Acquire;
  Result := FSyncPool.Num;
  FCritical.Release;
end;

function TThreadPost.Busy: Boolean;
begin
  Result := (Count > 0) or (FProgressing.V);
end;

function TThreadPost.Progress(ThreadID_: TThreadID): NativeInt;
var
  i: Integer;
  temp: TThread_Post_Data_Order_Struct__;
  t_: TThread_Post_Data;
begin
  Result := 0;
  if ThreadID_ <> FThreadID then
      exit;

  if FOneStep then
    begin
      if FSyncPool.Current <> nil then
        begin
          FProgressing.V := True;
          FCritical.Acquire;
          t_ := FSyncPool.Current^.Data^;
          FSyncPool.Next;
          FCritical.Release;

          if FResetRandomSeed then
              SetMT19937Seed(0);

          try
            if t_.IsRuning <> nil then
                t_.IsRuning^ := True;
            if t_.IsExit <> nil then
                t_.IsExit^ := False;
          except
          end;

          try
            if Assigned(t_.On_C1) then
                t_.On_C1()
            else if Assigned(t_.On_C2) then
                t_.On_C2(t_.Data1)
            else if Assigned(t_.On_C3) then
                t_.On_C3(t_.Data1, t_.Data2, t_.Data3);
            if Assigned(t_.On_C4) then
                t_.On_C4(t_.Data1, t_.Data2)
            else if Assigned(t_.On_M1) then
                t_.On_M1()
            else if Assigned(t_.On_M2) then
                t_.On_M2(t_.Data1)
            else if Assigned(t_.On_M3) then
                t_.On_M3(t_.Data1, t_.Data2, t_.Data3)
            else if Assigned(t_.On_M4) then
                t_.On_M4(t_.Data1, t_.Data2)
            else if Assigned(t_.On_P1) then
                t_.On_P1();
            if Assigned(t_.On_P2) then
                t_.On_P2(t_.Data1)
            else if Assigned(t_.On_P3) then
                t_.On_P3(t_.Data1, t_.Data2, t_.Data3);
            if Assigned(t_.On_P4) then
                t_.On_P4(t_.Data1, t_.Data2);
          except
          end;

          try
            if t_.IsRuning <> nil then
                t_.IsRuning^ := False;
            if t_.IsExit <> nil then
                t_.IsExit^ := True;
          except
          end;

          FProgressing.V := False;
          Result := 1;
        end;
    end
  else
    while (not FProgressing.V) and (Count > 0) do
      begin
        FProgressing.V := True;
        FCritical.Acquire;
        temp := FSyncPool;
        FSyncPool := TThread_Post_Data_Order_Struct__.Create;
        FCritical.Release;
        Result := temp.Num;
        while temp.Current <> nil do
          begin
            if FResetRandomSeed then
                SetMT19937Seed(0);

            try
              if temp.Current^.Data^.IsRuning <> nil then
                  temp.Current^.Data^.IsRuning^ := True;
              if temp.Current^.Data^.IsExit <> nil then
                  temp.Current^.Data^.IsExit^ := False;
            except
            end;

            try
              if Assigned(temp.Current^.Data^.On_C1) then
                  temp.Current^.Data^.On_C1()
              else if Assigned(temp.Current^.Data^.On_C2) then
                  temp.Current^.Data^.On_C2(temp.Current^.Data^.Data1)
              else if Assigned(temp.Current^.Data^.On_C3) then
                  temp.Current^.Data^.On_C3(temp.Current^.Data^.Data1, temp.Current^.Data^.Data2, temp.Current^.Data^.Data3)
              else if Assigned(temp.Current^.Data^.On_C4) then
                  temp.Current^.Data^.On_C4(temp.Current^.Data^.Data1, temp.Current^.Data^.Data2)
              else if Assigned(temp.Current^.Data^.On_M1) then
                  temp.Current^.Data^.On_M1()
              else if Assigned(temp.Current^.Data^.On_M2) then
                  temp.Current^.Data^.On_M2(temp.Current^.Data^.Data1)
              else if Assigned(temp.Current^.Data^.On_M3) then
                  temp.Current^.Data^.On_M3(temp.Current^.Data^.Data1, temp.Current^.Data^.Data2, temp.Current^.Data^.Data3)
              else if Assigned(temp.Current^.Data^.On_M4) then
                  temp.Current^.Data^.On_M4(temp.Current^.Data^.Data1, temp.Current^.Data^.Data2)
              else if Assigned(temp.Current^.Data^.On_P1) then
                  temp.Current^.Data^.On_P1()
              else if Assigned(temp.Current^.Data^.On_P2) then
                  temp.Current^.Data^.On_P2(temp.Current^.Data^.Data1)
              else if Assigned(temp.Current^.Data^.On_P3) then
                  temp.Current^.Data^.On_P3(temp.Current^.Data^.Data1, temp.Current^.Data^.Data2, temp.Current^.Data^.Data3)
              else if Assigned(temp.Current^.Data^.On_P4) then
                  temp.Current^.Data^.On_P4(temp.Current^.Data^.Data1, temp.Current^.Data^.Data2);
            except
            end;

            try
              if temp.Current^.Data^.IsRuning <> nil then
                  temp.Current^.Data^.IsRuning^ := False;
              if temp.Current^.Data^.IsExit <> nil then
                  temp.Current^.Data^.IsExit^ := True;
            except
            end;
            temp.Next;
          end;
        DisposeObject(temp);
        FProgressing.V := False;
      end;
end;

function TThreadPost.Progress(Thread_: TThread): NativeInt;
begin
  Result := Progress(Thread_.ThreadID);
end;

function TThreadPost.Progress(): Integer;
begin
  Result := Progress(TThread.CurrentThread);
end;

procedure TThreadPost.PostC_NP(OnSync: TThreadPost_C1);
begin
  PostC1(OnSync);
end;

procedure TThreadPost.PostM_NP(OnSync: TThreadPost_M1);
begin
  PostM1(OnSync);
end;

procedure TThreadPost.PostP_NP(OnSync: TThreadPost_P1);
begin
  PostP1(OnSync);
end;

procedure TThreadPost.PostC1(OnSync: TThreadPost_C1);
var
  t_: TThread_Post_Data;
begin
  t_.Init();
  t_.On_C1 := OnSync;
  FCritical.Acquire;
  FSyncPool.Push(t_);
  FCritical.Release;
end;

procedure TThreadPost.PostC1(OnSync: TThreadPost_C1; IsRuning_, IsExit_: PBoolean);
var
  t_: TThread_Post_Data;
begin
  t_.Init();
  t_.On_C1 := OnSync;

  t_.IsRuning := IsRuning_;
  t_.IsExit := IsExit_;

  try
    if t_.IsRuning <> nil then
        t_.IsRuning^ := True;
    if t_.IsExit <> nil then
        t_.IsExit^ := False;
  except
  end;

  FCritical.Acquire;
  FSyncPool.Push(t_);
  FCritical.Release;
end;

procedure TThreadPost.PostC2(Data1: Pointer; OnSync: TThreadPost_C2);
var
  t_: TThread_Post_Data;
begin
  t_.Init();
  t_.Data1 := Data1;
  t_.On_C2 := OnSync;
  FCritical.Acquire;
  FSyncPool.Push(t_);
  FCritical.Release;
end;

procedure TThreadPost.PostC2(Data1: Pointer; OnSync: TThreadPost_C2; IsRuning_, IsExit_: PBoolean);
var
  t_: TThread_Post_Data;
begin
  t_.Init();
  t_.Data1 := Data1;
  t_.On_C2 := OnSync;

  t_.IsRuning := IsRuning_;
  t_.IsExit := IsExit_;

  try
    if t_.IsRuning <> nil then
        t_.IsRuning^ := True;
    if t_.IsExit <> nil then
        t_.IsExit^ := False;
  except
  end;

  FCritical.Acquire;
  FSyncPool.Push(t_);
  FCritical.Release;
end;

procedure TThreadPost.PostC3(Data1: Pointer; Data2: TCore_Object; Data3: Variant; OnSync: TThreadPost_C3);
var
  t_: TThread_Post_Data;
begin
  t_.Init();
  t_.Data1 := Data1;
  t_.Data2 := Data2;
  t_.Data3 := Data3;
  t_.On_C3 := OnSync;
  FCritical.Acquire;
  FSyncPool.Push(t_);
  FCritical.Release;
end;

procedure TThreadPost.PostC3(Data1: Pointer; Data2: TCore_Object; Data3: Variant; OnSync: TThreadPost_C3; IsRuning_, IsExit_: PBoolean);
var
  t_: TThread_Post_Data;
begin
  t_.Init();
  t_.Data1 := Data1;
  t_.Data2 := Data2;
  t_.Data3 := Data3;
  t_.On_C3 := OnSync;

  t_.IsRuning := IsRuning_;
  t_.IsExit := IsExit_;

  try
    if t_.IsRuning <> nil then
        t_.IsRuning^ := True;
    if t_.IsExit <> nil then
        t_.IsExit^ := False;
  except
  end;

  FCritical.Acquire;
  FSyncPool.Push(t_);
  FCritical.Release;
end;

procedure TThreadPost.PostC4(Data1: Pointer; Data2: TCore_Object; OnSync: TThreadPost_C4);
var
  t_: TThread_Post_Data;
begin
  t_.Init();
  t_.Data1 := Data1;
  t_.Data2 := Data2;
  t_.On_C4 := OnSync;
  FCritical.Acquire;
  FSyncPool.Push(t_);
  FCritical.Release;
end;

procedure TThreadPost.PostC4(Data1: Pointer; Data2: TCore_Object; OnSync: TThreadPost_C4; IsRuning_, IsExit_: PBoolean);
var
  t_: TThread_Post_Data;
begin
  t_.Init();
  t_.Data1 := Data1;
  t_.Data2 := Data2;
  t_.On_C4 := OnSync;

  t_.IsRuning := IsRuning_;
  t_.IsExit := IsExit_;

  try
    if t_.IsRuning <> nil then
        t_.IsRuning^ := True;
    if t_.IsExit <> nil then
        t_.IsExit^ := False;
  except
  end;

  FCritical.Acquire;
  FSyncPool.Push(t_);
  FCritical.Release;
end;

procedure TThreadPost.PostM1(OnSync: TThreadPost_M1);
var
  t_: TThread_Post_Data;
begin
  t_.Init();
  t_.On_M1 := OnSync;
  FCritical.Acquire;
  FSyncPool.Push(t_);
  FCritical.Release;
end;

procedure TThreadPost.PostM1(OnSync: TThreadPost_M1; IsRuning_, IsExit_: PBoolean);
var
  t_: TThread_Post_Data;
begin
  t_.Init();
  t_.On_M1 := OnSync;

  t_.IsRuning := IsRuning_;
  t_.IsExit := IsExit_;

  try
    if t_.IsRuning <> nil then
        t_.IsRuning^ := True;
    if t_.IsExit <> nil then
        t_.IsExit^ := False;
  except
  end;

  FCritical.Acquire;
  FSyncPool.Push(t_);
  FCritical.Release;
end;

procedure TThreadPost.PostM2(Data1: Pointer; OnSync: TThreadPost_M2);
var
  t_: TThread_Post_Data;
begin
  t_.Init();
  t_.Data1 := Data1;
  t_.On_M2 := OnSync;
  FCritical.Acquire;
  FSyncPool.Push(t_);
  FCritical.Release;
end;

procedure TThreadPost.PostM2(Data1: Pointer; OnSync: TThreadPost_M2; IsRuning_, IsExit_: PBoolean);
var
  t_: TThread_Post_Data;
begin
  t_.Init();
  t_.Data1 := Data1;
  t_.On_M2 := OnSync;

  t_.IsRuning := IsRuning_;
  t_.IsExit := IsExit_;

  try
    if t_.IsRuning <> nil then
        t_.IsRuning^ := True;
    if t_.IsExit <> nil then
        t_.IsExit^ := False;
  except
  end;

  FCritical.Acquire;
  FSyncPool.Push(t_);
  FCritical.Release;
end;

procedure TThreadPost.PostM3(Data1: Pointer; Data2: TCore_Object; Data3: Variant; OnSync: TThreadPost_M3);
var
  t_: TThread_Post_Data;
begin
  t_.Init();
  t_.Data1 := Data1;
  t_.Data2 := Data2;
  t_.Data3 := Data3;
  t_.On_M3 := OnSync;
  FCritical.Acquire;
  FSyncPool.Push(t_);
  FCritical.Release;
end;

procedure TThreadPost.PostM3(Data1: Pointer; Data2: TCore_Object; Data3: Variant; OnSync: TThreadPost_M3; IsRuning_, IsExit_: PBoolean);
var
  t_: TThread_Post_Data;
begin
  t_.Init();
  t_.Data1 := Data1;
  t_.Data2 := Data2;
  t_.Data3 := Data3;
  t_.On_M3 := OnSync;

  t_.IsRuning := IsRuning_;
  t_.IsExit := IsExit_;

  try
    if t_.IsRuning <> nil then
        t_.IsRuning^ := True;
    if t_.IsExit <> nil then
        t_.IsExit^ := False;
  except
  end;

  FCritical.Acquire;
  FSyncPool.Push(t_);
  FCritical.Release;
end;

procedure TThreadPost.PostM4(Data1: Pointer; Data2: TCore_Object; OnSync: TThreadPost_M4);
var
  t_: TThread_Post_Data;
begin
  t_.Init();
  t_.Data1 := Data1;
  t_.Data2 := Data2;
  t_.On_M4 := OnSync;
  FCritical.Acquire;
  FSyncPool.Push(t_);
  FCritical.Release;
end;

procedure TThreadPost.PostM4(Data1: Pointer; Data2: TCore_Object; OnSync: TThreadPost_M4; IsRuning_, IsExit_: PBoolean);
var
  t_: TThread_Post_Data;
begin
  t_.Init();
  t_.Data1 := Data1;
  t_.Data2 := Data2;
  t_.On_M4 := OnSync;

  t_.IsRuning := IsRuning_;
  t_.IsExit := IsExit_;

  try
    if t_.IsRuning <> nil then
        t_.IsRuning^ := True;
    if t_.IsExit <> nil then
        t_.IsExit^ := False;
  except
  end;

  FCritical.Acquire;
  FSyncPool.Push(t_);
  FCritical.Release;
end;

procedure TThreadPost.PostP1(OnSync: TThreadPost_P1);
var
  t_: TThread_Post_Data;
begin
  t_.Init();
  t_.On_P1 := OnSync;
  FCritical.Acquire;
  FSyncPool.Push(t_);
  FCritical.Release;
end;

procedure TThreadPost.PostP1(OnSync: TThreadPost_P1; IsRuning_, IsExit_: PBoolean);
var
  t_: TThread_Post_Data;
begin
  t_.Init();
  t_.On_P1 := OnSync;

  t_.IsRuning := IsRuning_;
  t_.IsExit := IsExit_;

  try
    if t_.IsRuning <> nil then
        t_.IsRuning^ := True;
    if t_.IsExit <> nil then
        t_.IsExit^ := False;
  except
  end;

  FCritical.Acquire;
  FSyncPool.Push(t_);
  FCritical.Release;
end;

procedure TThreadPost.PostP2(Data1: Pointer; OnSync: TThreadPost_P2);
var
  t_: TThread_Post_Data;
begin
  t_.Init();
  t_.Data1 := Data1;
  t_.On_P2 := OnSync;
  FCritical.Acquire;
  FSyncPool.Push(t_);
  FCritical.Release;
end;

procedure TThreadPost.PostP2(Data1: Pointer; OnSync: TThreadPost_P2; IsRuning_, IsExit_: PBoolean);
var
  t_: TThread_Post_Data;
begin
  t_.Init();
  t_.Data1 := Data1;
  t_.On_P2 := OnSync;

  t_.IsRuning := IsRuning_;
  t_.IsExit := IsExit_;

  try
    if t_.IsRuning <> nil then
        t_.IsRuning^ := True;
    if t_.IsExit <> nil then
        t_.IsExit^ := False;
  except
  end;

  FCritical.Acquire;
  FSyncPool.Push(t_);
  FCritical.Release;
end;

procedure TThreadPost.PostP3(Data1: Pointer; Data2: TCore_Object; Data3: Variant; OnSync: TThreadPost_P3);
var
  t_: TThread_Post_Data;
begin
  t_.Init();
  t_.Data1 := Data1;
  t_.Data2 := Data2;
  t_.Data3 := Data3;
  t_.On_P3 := OnSync;
  FCritical.Acquire;
  FSyncPool.Push(t_);
  FCritical.Release;
end;

procedure TThreadPost.PostP3(Data1: Pointer; Data2: TCore_Object; Data3: Variant; OnSync: TThreadPost_P3; IsRuning_, IsExit_: PBoolean);
var
  t_: TThread_Post_Data;
begin
  t_.Init();
  t_.Data1 := Data1;
  t_.Data2 := Data2;
  t_.Data3 := Data3;
  t_.On_P3 := OnSync;

  t_.IsRuning := IsRuning_;
  t_.IsExit := IsExit_;

  try
    if t_.IsRuning <> nil then
        t_.IsRuning^ := True;
    if t_.IsExit <> nil then
        t_.IsExit^ := False;
  except
  end;

  FCritical.Acquire;
  FSyncPool.Push(t_);
  FCritical.Release;
end;

procedure TThreadPost.PostP4(Data1: Pointer; Data2: TCore_Object; OnSync: TThreadPost_P4);
var
  t_: TThread_Post_Data;
begin
  t_.Init();
  t_.Data1 := Data1;
  t_.Data2 := Data2;
  t_.On_P4 := OnSync;
  FCritical.Acquire;
  FSyncPool.Push(t_);
  FCritical.Release;
end;

procedure TThreadPost.PostP4(Data1: Pointer; Data2: TCore_Object; OnSync: TThreadPost_P4; IsRuning_, IsExit_: PBoolean);
var
  t_: TThread_Post_Data;
begin
  t_.Init();
  t_.Data1 := Data1;
  t_.Data2 := Data2;
  t_.On_P4 := OnSync;

  t_.IsRuning := IsRuning_;
  t_.IsExit := IsExit_;

  try
    if t_.IsRuning <> nil then
        t_.IsRuning^ := True;
    if t_.IsExit <> nil then
        t_.IsExit^ := False;
  except
  end;

  FCritical.Acquire;
  FSyncPool.Push(t_);
  FCritical.Release;
end;

//
procedure TThreadPost.Sync_Wait_PostC1(OnSync: TThreadPost_C1);
var
  Current_Thread_ID_: TThreadID;
  IsRuning_, IsExit_: Boolean;
begin
  Current_Thread_ID_ := TCore_Thread.CurrentThread.ThreadID;
  PostC1(OnSync, @IsRuning_, @IsExit_);
  while IsRuning_ do
    if Current_Thread_ID_ = FThreadID then
        Progress(Current_Thread_ID_)
    else if Current_Thread_ID_ = Main_Thread_ID then
        CheckThread(1)
    else
        TCompute.Sleep(1);
end;

procedure TThreadPost.Sync_Wait_PostC2(Data1: Pointer; OnSync: TThreadPost_C2);
var
  Current_Thread_ID_: TThreadID;
  IsRuning_, IsExit_: Boolean;
begin
  Current_Thread_ID_ := TCore_Thread.CurrentThread.ThreadID;
  PostC2(Data1, OnSync, @IsRuning_, @IsExit_);
  while IsRuning_ do
    if Current_Thread_ID_ = FThreadID then
        Progress(Current_Thread_ID_)
    else if Current_Thread_ID_ = Main_Thread_ID then
        CheckThread(1)
    else
        TCompute.Sleep(1);
end;

procedure TThreadPost.Sync_Wait_PostC3(Data1: Pointer; Data2: TCore_Object; Data3: Variant; OnSync: TThreadPost_C3);
var
  Current_Thread_ID_: TThreadID;
  IsRuning_, IsExit_: Boolean;
begin
  Current_Thread_ID_ := TCore_Thread.CurrentThread.ThreadID;
  PostC3(Data1, Data2, Data3, OnSync, @IsRuning_, @IsExit_);
  while IsRuning_ do
    if Current_Thread_ID_ = FThreadID then
        Progress(Current_Thread_ID_)
    else if Current_Thread_ID_ = Main_Thread_ID then
        CheckThread(1)
    else
        TCompute.Sleep(1);
end;

procedure TThreadPost.Sync_Wait_PostC4(Data1: Pointer; Data2: TCore_Object; OnSync: TThreadPost_C4);
var
  Current_Thread_ID_: TThreadID;
  IsRuning_, IsExit_: Boolean;
begin
  Current_Thread_ID_ := TCore_Thread.CurrentThread.ThreadID;
  PostC4(Data1, Data2, OnSync, @IsRuning_, @IsExit_);
  while IsRuning_ do
    if Current_Thread_ID_ = FThreadID then
        Progress(Current_Thread_ID_)
    else if Current_Thread_ID_ = Main_Thread_ID then
        CheckThread(1)
    else
        TCompute.Sleep(1);
end;

procedure TThreadPost.Sync_Wait_PostM1(OnSync: TThreadPost_M1);
var
  Current_Thread_ID_: TThreadID;
  IsRuning_, IsExit_: Boolean;
begin
  Current_Thread_ID_ := TCore_Thread.CurrentThread.ThreadID;
  PostM1(OnSync, @IsRuning_, @IsExit_);
  while IsRuning_ do
    if Current_Thread_ID_ = FThreadID then
        Progress(Current_Thread_ID_)
    else if Current_Thread_ID_ = Main_Thread_ID then
        CheckThread(1)
    else
        TCompute.Sleep(1);
end;

procedure TThreadPost.Sync_Wait_PostM2(Data1: Pointer; OnSync: TThreadPost_M2);
var
  Current_Thread_ID_: TThreadID;
  IsRuning_, IsExit_: Boolean;
begin
  Current_Thread_ID_ := TCore_Thread.CurrentThread.ThreadID;
  PostM2(Data1, OnSync, @IsRuning_, @IsExit_);
  while IsRuning_ do
    if Current_Thread_ID_ = FThreadID then
        Progress(Current_Thread_ID_)
    else if Current_Thread_ID_ = Main_Thread_ID then
        CheckThread(1)
    else
        TCompute.Sleep(1);
end;

procedure TThreadPost.Sync_Wait_PostM3(Data1: Pointer; Data2: TCore_Object; Data3: Variant; OnSync: TThreadPost_M3);
var
  Current_Thread_ID_: TThreadID;
  IsRuning_, IsExit_: Boolean;
begin
  Current_Thread_ID_ := TCore_Thread.CurrentThread.ThreadID;
  PostM3(Data1, Data2, Data3, OnSync, @IsRuning_, @IsExit_);
  while IsRuning_ do
    if Current_Thread_ID_ = FThreadID then
        Progress(Current_Thread_ID_)
    else if Current_Thread_ID_ = Main_Thread_ID then
        CheckThread(1)
    else
        TCompute.Sleep(1);
end;

procedure TThreadPost.Sync_Wait_PostM4(Data1: Pointer; Data2: TCore_Object; OnSync: TThreadPost_M4);
var
  Current_Thread_ID_: TThreadID;
  IsRuning_, IsExit_: Boolean;
begin
  Current_Thread_ID_ := TCore_Thread.CurrentThread.ThreadID;
  PostM4(Data1, Data2, OnSync, @IsRuning_, @IsExit_);
  while IsRuning_ do
    if Current_Thread_ID_ = FThreadID then
        Progress(Current_Thread_ID_)
    else if Current_Thread_ID_ = Main_Thread_ID then
        CheckThread(1)
    else
        TCompute.Sleep(1);
end;

procedure TThreadPost.Sync_Wait_PostP1(OnSync: TThreadPost_P1);
var
  Current_Thread_ID_: TThreadID;
  IsRuning_, IsExit_: Boolean;
begin
  Current_Thread_ID_ := TCore_Thread.CurrentThread.ThreadID;
  PostP1(OnSync, @IsRuning_, @IsExit_);
  while IsRuning_ do
    if Current_Thread_ID_ = FThreadID then
        Progress(Current_Thread_ID_)
    else if Current_Thread_ID_ = Main_Thread_ID then
        CheckThread(1)
    else
        TCompute.Sleep(1);
end;

procedure TThreadPost.Sync_Wait_PostP2(Data1: Pointer; OnSync: TThreadPost_P2);
var
  Current_Thread_ID_: TThreadID;
  IsRuning_, IsExit_: Boolean;
begin
  Current_Thread_ID_ := TCore_Thread.CurrentThread.ThreadID;
  PostP2(Data1, OnSync, @IsRuning_, @IsExit_);
  while IsRuning_ do
    if Current_Thread_ID_ = FThreadID then
        Progress(Current_Thread_ID_)
    else if Current_Thread_ID_ = Main_Thread_ID then
        CheckThread(1)
    else
        TCompute.Sleep(1);
end;

procedure TThreadPost.Sync_Wait_PostP3(Data1: Pointer; Data2: TCore_Object; Data3: Variant; OnSync: TThreadPost_P3);
var
  Current_Thread_ID_: TThreadID;
  IsRuning_, IsExit_: Boolean;
begin
  Current_Thread_ID_ := TCore_Thread.CurrentThread.ThreadID;
  PostP3(Data1, Data2, Data3, OnSync, @IsRuning_, @IsExit_);
  while IsRuning_ do
    if Current_Thread_ID_ = FThreadID then
        Progress(Current_Thread_ID_)
    else if Current_Thread_ID_ = Main_Thread_ID then
        CheckThread(1)
    else
        TCompute.Sleep(1);
end;

procedure TThreadPost.Sync_Wait_PostP4(Data1: Pointer; Data2: TCore_Object; OnSync: TThreadPost_P4);
var
  Current_Thread_ID_: TThreadID;
  IsRuning_, IsExit_: Boolean;
begin
  Current_Thread_ID_ := TCore_Thread.CurrentThread.ThreadID;
  PostP4(Data1, Data2, OnSync, @IsRuning_, @IsExit_);
  while IsRuning_ do
    if Current_Thread_ID_ = FThreadID then
        Progress(Current_Thread_ID_)
    else if Current_Thread_ID_ = Main_Thread_ID then
        CheckThread(1)
    else
        TCompute.Sleep(1);
end;

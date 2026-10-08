type
  TTimer_Data__ = record
    Interval: TTimeTick;
    LastTimer: TTimeTick;
    OnTimer_C: TOn_Timer_C;
    OnTimer_M: TOn_Timer_M;
    OnTimer_P: TOn_Timer_P;
    procedure Init_();
    procedure DoTimer();
    class function Init: TTimer_Data__; static;
  end;

  TTimer_Event_Pool__ = class(TCritical_Big_Hash_Pair_Pool<TCore_Object, TTimer_Data__>)
  public
    procedure DoFree(var Key: TCore_Object; var Value: TTimer_Data__); override;
    procedure Progress;
  end;

var
  Timer_Event_Pool__: TTimer_Event_Pool__ = nil;

procedure TTimer_Data__.Init_();
begin
  Interval := 1000;
  LastTimer := 0;
  OnTimer_C := nil;
  OnTimer_M := nil;
  OnTimer_P := nil;
end;

procedure TTimer_Data__.DoTimer();
begin
  try
    if Assigned(OnTimer_C) then
        OnTimer_C()
    else if Assigned(OnTimer_M) then
        OnTimer_M()
    else if Assigned(OnTimer_P) then
        OnTimer_P();
  except
  end;
end;

class function TTimer_Data__.Init: TTimer_Data__;
begin
  Result.Init_();
end;

procedure TTimer_Event_Pool__.DoFree(var Key: TCore_Object; var Value: TTimer_Data__);
begin
  Key := nil;
  Value.Init_;
  inherited DoFree(Key, Value);
end;

procedure TTimer_Event_Pool__.Progress;
var
  tk: TTimeTick;
begin
  tk := GetTimeTick();
  Lock;
  try
    if num > 0 then
      with repeat_ do
        repeat
          try
            if tk - Queue^.Data^.Data.Second.LastTimer > Queue^.Data^.Data.Second.Interval then
              begin
                Queue^.Data^.Data.Second.DoTimer();
                Queue^.Data^.Data.Second.LastTimer := tk;
              end;
          except
          end;
        until not Next;
  finally
      UnLock;
  end;
end;

procedure Subscribe_Timer_C(Bind_: TCore_Object; Interval_: TTimeTick; OnTimer: TOn_Timer_C);
var
  tmp: TTimer_Data__;
begin
  tmp.Init_;
  tmp.Interval := Interval_;
  tmp.LastTimer := GetTimeTick();
  tmp.OnTimer_C := OnTimer;
  Timer_Event_Pool__.Add(Bind_, tmp, True);
end;

procedure Subscribe_Timer_M(Bind_: TCore_Object; Interval_: TTimeTick; OnTimer: TOn_Timer_M);
var
  tmp: TTimer_Data__;
begin
  tmp.Init_;
  tmp.Interval := Interval_;
  tmp.LastTimer := GetTimeTick();
  tmp.OnTimer_M := OnTimer;
  Timer_Event_Pool__.Add(Bind_, tmp, True);
end;

procedure Subscribe_Timer_P(Bind_: TCore_Object; Interval_: TTimeTick; OnTimer: TOn_Timer_P);
var
  tmp: TTimer_Data__;
begin
  tmp.Init_;
  tmp.Interval := Interval_;
  tmp.LastTimer := GetTimeTick();
  tmp.OnTimer_P := OnTimer;
  Timer_Event_Pool__.Add(Bind_, tmp, True);
end;

procedure Remove_Timer(Bind_: TCore_Object);
begin
  Timer_Event_Pool__.Delete(Bind_);
end;

procedure Reset_Timer(Bind_: TCore_Object);
var
  p: TTimer_Event_Pool__.PValue_;
begin
  p := Timer_Event_Pool__.Get_Value_Ptr(Bind_);
  if p <> nil then
      p^.LastTimer := GetTimeTick();
end;

procedure Init_Core_Timer();
begin
  Timer_Event_Pool__ := TTimer_Event_Pool__.Create($FF, TTimer_Data__.Init());
end;

procedure Free_Core_Timer();
begin
  DisposeObject(Timer_Event_Pool__);
end;

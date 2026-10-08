{ ****************************************************************************** }
{ * CPS tool                                                                   * }
{ ****************************************************************************** }
procedure TCPS_Tool.Reset;
begin
  First_Caller_Time := 0;
  Last_Begin_Caller_Time := 0;
  Last_End_Caller_Time := 0;
  Last_Analysis_Time := 0;
  Caller_Num := 0;
  CPS := 0;
  CPU_Time := 0;
end;

procedure TCPS_Tool.Begin_Caller;
begin
  Last_Begin_Caller_Time := GetTimeTick;
  if First_Caller_Time = 0 then
      First_Caller_Time := Last_Begin_Caller_Time;
  if Last_End_Caller_Time = 0 then
      Last_End_Caller_Time := Last_Begin_Caller_Time;
  if Last_Analysis_Time = 0 then
      Last_Analysis_Time := Last_Begin_Caller_Time;
end;

procedure TCPS_Tool.End_Caller;
var
  f: Double;
begin
  Last_End_Caller_Time := GetTimeTick();
  if First_Caller_Time = 0 then
      First_Caller_Time := Last_End_Caller_Time;
  if Last_Begin_Caller_Time = 0 then
      Last_Begin_Caller_Time := Last_End_Caller_Time;
  if Last_Analysis_Time = 0 then
      Last_Analysis_Time := Last_End_Caller_Time;

  Inc(Caller_Num);

  if (Last_End_Caller_Time - Last_Analysis_Time) > 1000 then
    begin
      f := (Last_End_Caller_Time - Last_Analysis_Time) * 0.001;
      CPS := Caller_Num / f;
      Caller_Num := 0;
      Last_Analysis_Time := Last_End_Caller_Time;
    end;

  CPU_Time := Max(Last_End_Caller_Time - Last_Begin_Caller_Time, CPU_Time);
end;

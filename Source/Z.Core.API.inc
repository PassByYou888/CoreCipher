function DisposeObject(const Obj: TObject): Boolean;
begin
  Result := False;
  if Obj = nil then
      exit;
  try
{$IFDEF AUTOREFCOUNT}Obj.DisposeOf; {$ELSE AUTOREFCOUNT}Obj.Free; {$ENDIF AUTOREFCOUNT}
    Result := True;
  except
{$IFDEF FPC} // fixed fpc 3.2.2 compiler internal error, by.qq600585
    if Assigned(On_Raise_Info) then
        On_Raise_Info('DisposeObject error');
    Result := False;
{$ELSE FPC}
    on E: Exception do
      begin
        if Assigned(On_Raise_Info) then
            On_Raise_Info('DisposeObject error ' + E.Message);
        Result := False;
      end;
{$ENDIF FPC}
  end;
end;

procedure DisposeObject(const objs: array of TObject);
var
  Obj: TObject;
begin
  for Obj in objs do
      DisposeObject(Obj);
end;

function FreeObj(const Obj: TObject): Boolean;
begin
  Result := DisposeObject(Obj);
end;

function FreeObject(const Obj: TObject): Boolean;
begin
  Result := DisposeObject(Obj);
end;

procedure FreeObject(const objs: array of TObject);
var
  Obj: TObject;
begin
  for Obj in objs do
      DisposeObject(Obj);
end;

function DisposeObjectAndNil(var Obj): Boolean;
begin
  Result := False;
  if TObject(Obj) <> nil then
    begin
      Result := DisposeObject(TObject(Obj));
      TObject(Obj) := nil;
    end;
end;

function FreeObjAndNil(var Obj): Boolean;
begin
  Result := DisposeObjectAndNil(Obj);
end;

procedure LockObject(Obj: TObject);
{$IFNDEF CriticalSimulateAtomic}
{$IFDEF ANTI_DEAD_ATOMIC_LOCK}
var
  d: TTimeTick;
{$ENDIF ANTI_DEAD_ATOMIC_LOCK}
{$ENDIF CriticalSimulateAtomic}
begin
{$IFDEF FPC}
  Lock_Critical_Obj__(Obj);
{$ELSE FPC}
{$IFDEF CriticalSimulateAtomic}
  Lock_Critical_Obj__(Obj);
{$ELSE CriticalSimulateAtomic}
{$IFDEF ANTI_DEAD_ATOMIC_LOCK}
  d := GetTimeTick;
  TMonitor.Enter(Obj, 5000);
  if GetTimeTick - d >= 5000 then
      RaiseInfo('dead');
{$ELSE ANTI_DEAD_ATOMIC_LOCK}
  TMonitor.Enter(Obj);
{$ENDIF ANTI_DEAD_ATOMIC_LOCK}
{$ENDIF CriticalSimulateAtomic}
{$ENDIF FPC}
end;

procedure UnLockObject(Obj: TObject);
begin
{$IFDEF FPC}
  UnLock_Critical_Obj__(Obj);
{$ELSE FPC}
{$IFDEF CriticalSimulateAtomic}
  UnLock_Critical_Obj__(Obj);
{$ELSE CriticalSimulateAtomic}
  TMonitor.exit(Obj);
{$ENDIF CriticalSimulateAtomic}
{$ENDIF FPC}
end;

procedure FillPtrByte(const dest: Pointer; Size: NativeUInt; const Value: Byte);
{$IFDEF FillPtr_Used_FillChar}
begin
  FillChar(dest^, Size, Value);
end;
{$ELSE FillPtr_Used_FillChar}


var
  d: PByte;
  v: UInt64;
begin
  if Size = 0 then
      exit;
  v := Value or (Value shl 8) or (Value shl 16) or (Value shl 24);
  v := v or (v shl 32);
  d := dest;
  while Size >= 8 do
    begin
      PUInt64(d)^ := v;
      dec(Size, 8);
      inc(d, 8);
    end;
  if Size >= 4 then
    begin
      PCardinal(d)^ := PCardinal(@v)^;
      dec(Size, 4);
      inc(d, 4);
    end;
  if Size >= 2 then
    begin
      PWORD(d)^ := PWORD(@v)^;
      dec(Size, 2);
      inc(d, 2);
    end;
  if Size > 0 then
      d^ := Value;
end;
{$ENDIF FillPtr_Used_FillChar}


procedure FillPtr(const dest: Pointer; Size: NativeUInt; const Value: Byte);
begin
  FillPtrByte(dest, Size, Value);
end;

procedure FillByte(const dest: Pointer; Size: NativeUInt; const Value: Byte);
begin
  FillPtrByte(dest, Size, Value);
end;

function CompareMemory(const p1, p2: Pointer; Size: NativeUInt): Boolean;
var
  b1, b2: PByte;
begin;
  if Size = 0 then
    begin
      Result := True;
      exit;
    end;
  Result := False;
  b1 := p1;
  b2 := p2;
  while (Size >= 8) do
    begin
      if PUInt64(b2)^ <> PUInt64(b1)^ then
          exit;
      dec(Size, 8);
      inc(b2, 8);
      inc(b1, 8);
    end;
  if Size >= 4 then
    begin
      if PCardinal(b2)^ <> PCardinal(b1)^ then
          exit;
      dec(Size, 4);
      inc(b2, 4);
      inc(b1, 4);
    end;
  if Size >= 2 then
    begin
      if PWORD(b2)^ <> PWORD(b1)^ then
          exit;
      dec(Size, 2);
      inc(b2, 2);
      inc(b1, 2);
    end;
  if Size > 0 then
    if b2^ <> b1^ then
        exit;
  Result := True;
end;

function CompareMemoryIs0(const p: Pointer; Size: NativeUInt): Boolean;
var
  b: PByte;
begin
  if Size = 0 then
    begin
      Result := True;
      exit;
    end;
  Result := False;
  b := p;
  while Size >= 8 do
    begin
      if PUInt64(b)^ <> 0 then
          exit;
      dec(Size, 8);
      inc(b, 8);
    end;
  if Size >= 4 then
    begin
      if PCardinal(b)^ <> 0 then
          exit;
      dec(Size, 4);
      inc(b, 4);
    end;
  if Size >= 2 then
    begin
      if PWORD(b)^ <> 0 then
          exit;
      dec(Size, 2);
      inc(b, 2);
    end;
  if Size > 0 then
    if b^ <> 0 then
        exit;
  Result := True;
end;

procedure CopyPtr(const sour, dest: Pointer; Size: NativeUInt);
{$IFDEF CopyPtr_Used_Move}
begin
  Move(sour^, dest^, Size);
end;
{$ELSE CopyPtr_Used_Move}


var
  s, d: NativeUInt;
begin
  if Size = 0 then
      exit;
  if sour = dest then
      exit;

  s := NativeUInt(sour);
  d := NativeUInt(dest);
  // overlap solve
  // thanks,qq122742470,laowang
  // thanks,qq4700653,LOK
  if d > s then
    begin
      inc(s, Size);
      inc(d, Size);
      while Size >= 8 do
        begin
          dec(d, 8);
          dec(s, 8);
          dec(Size, 8);
          PUInt64(d)^ := PUInt64(s)^;
        end;
      if Size >= 4 then
        begin
          dec(d, 4);
          dec(s, 4);
          dec(Size, 4);
          PCardinal(d)^ := PCardinal(s)^;
        end;
      if Size >= 2 then
        begin
          dec(d, 2);
          dec(s, 2);
          dec(Size, 2);
          PWORD(d)^ := PWORD(s)^;
        end;
      if Size > 0 then
          PByte(d - 1)^ := PByte(s - 1)^;
    end
  else
    begin
      while Size >= 8 do
        begin
          PUInt64(d)^ := PUInt64(s)^;
          dec(Size, 8);
          inc(d, 8);
          inc(s, 8);
        end;
      if Size >= 4 then
        begin
          PCardinal(d)^ := PCardinal(s)^;
          dec(Size, 4);
          inc(d, 4);
          inc(s, 4);
        end;
      if Size >= 2 then
        begin
          PWORD(d)^ := PWORD(s)^;
          dec(Size, 2);
          inc(d, 2);
          inc(s, 2);
        end;
      if Size > 0 then
          PByte(d)^ := PByte(s)^;
    end;
end;
{$ENDIF CopyPtr_Used_Move}


type
  EZCoreError = class(Exception)
  public
    // Address of the caller that invoked RaiseInfo. Captured inside
    // RaiseInfo so that the exception helper can resolve the user's
    // call site instead of the internal 'raise' line in Z.Core.
    Caller_Address: Pointer;
  end;

  (*
    * Z_Get_Caller_Address
    *
    * Returns the return address of the caller of the function that
    * calls this helper. When RaiseInfo invokes it, the result is the
    * address in user code that invoked RaiseInfo.
    *
    * Why this works cross-platform, without assembly
    * -----------------------------------------------
    * FPC exposes three compiler intrinsics:
    *
    *   System.get_frame          - frame pointer of the current function
    *   System.get_caller_frame   - frame pointer of the caller
    *   System.get_caller_addr    - return address stored in a frame
    *
    * They are implemented by the compiler itself for every supported
    * target (x86, x64, ARM32, AArch64, ...), so this helper contains
    * no target-specific code.
    *
    * The only requirement is that a real stack frame exists for this
    * function. FPC normally omits the frame for leaf functions (a
    * function whose body calls nothing but intrinsics), in which case
    * get_frame would return garbage.
    *
    * To prevent that, three measures are taken together:
    *
    *   {$INLINE OFF}                  - prevent inlining into RaiseInfo,
    *                                    otherwise get_frame would
    *                                    return the caller's frame
    *   {$OPTIMIZATION NOOPTIMIZATION} - disable every optimization for
    *                                    the body of this function,
    *                                    including any frame-elision
    *                                    pass the optimizer might run
    *   local variables F0 / F1        - force real stack activity
    *
    * NOTE: the optimization name used here is NOOPTIMIZATION, not
    * NOSTACKFRAME. NOFRAMEPOINTER is not a valid name at all and is
    * rejected by FPC 3.2.x with "Illegal optimization specified".
  *)
{$IFDEF FPC}
{$PUSH}
{$INLINE OFF}
{$O-}


function Z_Get_Caller_Address: Pointer;
var
  F0, F1: Pointer;
begin
  F0 := System.get_frame; // frame of this function
  F1 := System.get_caller_frame(F0); // frame of RaiseInfo
  Result := System.get_caller_addr(F1); // return address into user code
end;
{$POP}
{$ENDIF}


procedure RaiseInfo(const n: string);
var
  E: EZCoreError;
  Caller_Addr: Pointer;
begin
  if Assigned(On_Raise_Info) then
      On_Raise_Info(n);

  E := EZCoreError.Create('[Z.Core] ' + n);

  { *
    * Capture the caller's return address.
    *
    * Delphi: System.ReturnAddress returns the return address of the
    * *containing* function, i.e. of the function whose body includes
    * this call. When called directly inside RaiseInfo, the containing
    * function is RaiseInfo itself, so the returned pointer is the
    * user's call site. It MUST NOT be moved into a helper function -
    * doing so would make the containing function the helper, and the
    * reported address would point inside RaiseInfo.
    *
    * FPC: ReturnAddress does not exist. Use the frame-walking helper
    * instead, which internally exploits get_frame to walk up exactly
    * the required number of frames. The helper is written so that FPC
    * emits a frame pointer for it, making the walk reliable.
    * }
{$IFDEF FPC}
  Caller_Addr := Z_Get_Caller_Address;
{$ELSE}
  Caller_Addr := System.ReturnAddress;
{$ENDIF}
  E.Caller_Address := Caller_Addr;

  if Assigned(On_Raise_Info_Detail) then
    begin
      try
          On_Raise_Info_Detail(n, E.Caller_Address);
      except
      end;
    end;

  raise E;
end;

procedure RaiseInfo(const n: string; const Args: array of const);
begin
  RaiseInfo(Format(n, Args));
end;

function IsMobile: Boolean;
begin
  case CurrentPlatform of
    epIOS, epIOSSIM, epANDROID32, epANDROID64: Result := True;
    else Result := False;
  end;
end;

var
  Core_RunTime_Tick: TTimeTick;
{$IFDEF MSWINDOWS}
  Core_Step_Tick: TTimeTick;
{$ELSE MSWINDOWS}
  Core_Step_Tick: Cardinal;
{$ENDIF MSWINDOWS}


procedure Init_Time_Tick();
begin
  Core_RunTime_Tick := C_Tick_Day * 3;
{$IFDEF MSWINDOWS}
  Core_Step_Tick := TTimeTick(GetTickCount64);
{$ELSE MSWINDOWS}
  Core_Step_Tick := TCore_Thread.GetTickCount();
{$ENDIF MSWINDOWS}
end;

function GetTimeTick(): TTimeTick;
{$IFDEF MSWINDOWS}
begin
  Result := Core_RunTime_Tick + TTimeTick(GetTickCount64);
end;
{$ELSE MSWINDOWS}


var
  Sys_Tick: Cardinal;
begin
  TimeTick_Critical__.Acquire;
  Sys_Tick := TCore_Thread.GetTickCount();
  inc(Core_RunTime_Tick, Sys_Tick - Core_Step_Tick);
  Core_Step_Tick := Sys_Tick;
  Result := Core_RunTime_Tick;
  TimeTick_Critical__.Release;
end;
{$ENDIF MSWINDOWS}


function GetTimeTickCount(): TTimeTick;
begin
  Result := GetTimeTick();
end;

function GetCrashTimeTick(): TTimeTick;
begin
  Result := TTimeTick($FFFFFFFFFFFFFFFF) - GetTimeTick();
end;

function GetTimeTickDiff(t1, t2: TTimeTick): TTimeTick;
begin
  if t1 < t2 then TSwap<TTimeTick>.Do_(t1, t2);
  Result := t1 - t2;
end;

function SameF(const A, b: Double; Epsilon: Double = 0): Boolean;
const
  C_DoubleResolution = 1E-15 * 1000;
begin
  if Epsilon = 0 then
      Epsilon := Max(Min(Abs(A), Abs(b)) * C_DoubleResolution, C_DoubleResolution);
  if A > b then
      Result := (A - b) <= Epsilon
  else
      Result := (b - A) <= Epsilon;
end;

function SameF(const A, b: Single; Epsilon: Single = 0): Boolean;
const
  C_SingleResolution = 1E-7 * 1000;
begin
  if Epsilon = 0 then
      Epsilon := Max(Min(Abs(A), Abs(b)) * C_SingleResolution, C_SingleResolution);
  if A > b then
      Result := (A - b) <= Epsilon
  else
      Result := (b - A) <= Epsilon;
end;

procedure Nop;
begin
end;

function IsDebuging: Boolean;
begin
  Result := False;
{$IFDEF DELPHI}
{$IFDEF MSWINDOWS}
  Result := DebugHook > 0;
{$ELSE MSWINDOWS}
{$IFDEF DEBUG}
  Result := True;
{$ENDIF DEBUG}
{$ENDIF MSWINDOWS}
{$ENDIF DELPHI}
end;

function Check_Soft_Thread_Synchronize: Boolean;
begin
  Result := Check_Soft_Thread_Synchronize(0);
end;

function Check_Soft_Thread_Synchronize(Timeout: TTimeTick): Boolean;
begin
  Result := Check_Soft_Thread_Synchronize(Timeout, True);
end;

function Check_Soft_Thread_Synchronize(Timeout: TTimeTick; Run_Hook_Event_: Boolean): Boolean;
begin
  if Assigned(On_Check_Soft_Thread_Synchronize) then
      Result := On_Check_Soft_Thread_Synchronize(Timeout, Run_Hook_Event_)
  else
    begin
      TCompute.Sleep(Timeout);
      Result := False;
    end;
end;

procedure Check_System_Thread_Synchronize;
begin
  Check_System_Thread_Synchronize(0);
end;

function Check_System_Thread_Synchronize(Timeout: TTimeTick): Boolean;
begin
  Check_System_Thread_Synchronize(Timeout, True);
end;

function Check_System_Thread_Synchronize(Timeout: TTimeTick; Run_Hook_Event_: Boolean): Boolean;
begin
  if Assigned(On_Check_System_Thread_Synchronize) then
      Result := On_Check_System_Thread_Synchronize(Timeout, Run_Hook_Event_)
  else
    begin
      TCompute.Sleep(Timeout);
      Result := False;
    end;
end;

procedure CheckThreadSynchronize;
begin
  if Main_Thread_Soft_Synchronize then
      Check_Soft_Thread_Synchronize(0)
  else
      Check_System_Thread_Synchronize(0);
end;

function CheckThreadSynchronize(Timeout: TTimeTick): Boolean;
begin
  if Main_Thread_Soft_Synchronize then
      Result := Check_Soft_Thread_Synchronize(Timeout)
  else
      Result := Check_System_Thread_Synchronize(Timeout);
end;

procedure CheckThreadSync;
begin
  if Main_Thread_Soft_Synchronize then
      Check_Soft_Thread_Synchronize(0)
  else
      Check_System_Thread_Synchronize(0);
end;

function CheckThreadSync(Timeout: TTimeTick): Boolean;
begin
  if Main_Thread_Soft_Synchronize then
      Result := Check_Soft_Thread_Synchronize(Timeout)
  else
      Result := Check_System_Thread_Synchronize(Timeout);
end;

procedure CheckThread;
begin
  if Main_Thread_Soft_Synchronize then
      Check_Soft_Thread_Synchronize(0)
  else
      Check_System_Thread_Synchronize(0);
end;

function CheckThread(Timeout: TTimeTick): Boolean;
begin
  if Main_Thread_Soft_Synchronize then
      Result := Check_Soft_Thread_Synchronize(Timeout)
  else
      Result := Check_System_Thread_Synchronize(Timeout);
end;

function if_(const bool_: Boolean; const True_, False_: Boolean): Boolean;
begin
  if bool_ then
      Result := True_
  else
      Result := False_;
end;

function if_(const bool_: Boolean; const True_, False_: ShortInt): ShortInt;
begin
  if bool_ then
      Result := True_
  else
      Result := False_;
end;

function if_(const bool_: Boolean; const True_, False_: SmallInt): SmallInt;
begin
  if bool_ then
      Result := True_
  else
      Result := False_;
end;

function if_(const bool_: Boolean; const True_, False_: Integer): Integer;
begin
  if bool_ then
      Result := True_
  else
      Result := False_;
end;

function if_(const bool_: Boolean; const True_, False_: Int64): Int64;
begin
  if bool_ then
      Result := True_
  else
      Result := False_;
end;

function if_(const bool_: Boolean; const True_, False_: Byte): Byte;
begin
  if bool_ then
      Result := True_
  else
      Result := False_;
end;

function if_(const bool_: Boolean; const True_, False_: Word): Word;
begin
  if bool_ then
      Result := True_
  else
      Result := False_;
end;

function if_(const bool_: Boolean; const True_, False_: Cardinal): Cardinal;
begin
  if bool_ then
      Result := True_
  else
      Result := False_;
end;

function if_(const bool_: Boolean; const True_, False_: UInt64): UInt64;
begin
  if bool_ then
      Result := True_
  else
      Result := False_;
end;

function if_(const bool_: Boolean; const True_, False_: Single): Single;
begin
  if bool_ then
      Result := True_
  else
      Result := False_;
end;

function if_(const bool_: Boolean; const True_, False_: Double): Double;
begin
  if bool_ then
      Result := True_
  else
      Result := False_;
end;

function if_(const bool_: Boolean; const True_, False_: string): string;
begin
  if bool_ then
      Result := True_
  else
      Result := False_;
end;

function ifv_(const bool_: Boolean; const True_, False_: Variant): Variant;
begin
  if bool_ then
      Result := True_
  else
      Result := False_;
end;

function GetOffset(const p_: Pointer; const offset_: NativeInt): Pointer;
begin
  Result := Pointer(NativeUInt(p_) + offset_);
end;

function GetPtr(const p_: Pointer; const offset_: NativeInt): Pointer;
begin
  Result := Pointer(NativeUInt(p_) + offset_);
end;

function IsValidUTF8Bytes(const Data: TBytes): Boolean;
var
  i: Integer;
  b: Byte;
  bytes_needed: Integer;
begin
  Result := False;
  bytes_needed := 0;
  for i := 0 to length(Data) - 1 do
    begin
      b := Data[i];
      if bytes_needed = 0 then
        begin
          if b <= $7F then
            // µ¥×Ö½Ú
          else if b >= $C2 then
            begin
              if b <= $DF then
                  bytes_needed := 1
              else if b <= $EF then
                  bytes_needed := 2
              else if b <= $F4 then
                  bytes_needed := 3
              else
                  exit(False);
            end
          else
              exit(False);
        end
      else
        begin
          if (b and $C0) <> $80 then
              exit(False);
          dec(bytes_needed);
        end;
    end;
  Result := (bytes_needed = 0);
end;

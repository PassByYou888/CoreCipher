type
  PCritical_Struct = ^TCritical_Struct;
  TCritical_Struct_Pool_Decl__ = class(TBigList<PCritical_Struct>)
  end;

  TCritical_Struct_Pool__ = class(TCritical_Struct_Pool_Decl__)
  public
    procedure DoFree(var Data: PCritical_Struct); override;
  end;

  TCritical_Struct = record
    Obj: TObject;
    LEnter: Integer;
    Critical: TCritical;
    Pool_Ptr: TCritical_Struct_Pool_Decl__.PQueueStruct;
  end;

var
  Lock_Pool_Cirtical__: TCritical;
  Atom_Num_Critical__: TCritical;
  TimeTick_Critical__: TCritical;
  Lock_Pool__: TCritical_Struct_Pool__;

procedure TCritical_Struct_Pool__.DoFree(var Data: PCritical_Struct);
begin
  if Data = nil then
      exit;
  DisposeObject(Data^.Critical);
  Dispose(Data);
end;

procedure Init_Critical_System;
begin
{$IFDEF DEBUG}
  if IsConsole then
      Writeln('Init Critical');
{$ENDIF DEBUG}
  Lock_Pool_Cirtical__ := TCritical.Create('Lock_Pool_Cirtical__');
  Atom_Num_Critical__ := TCritical.Create('Atom_Num_Critical__');
  TimeTick_Critical__ := TCritical.Create('TimeTick_Critical__');
  Lock_Pool__ := TCritical_Struct_Pool__.Create;
end;

procedure Free_Critical_System;
begin
{$IFDEF DEBUG}
  if IsConsole then
      Write('Free Critical');
{$ENDIF DEBUG}
  Lock_Pool__.Free;
  Lock_Pool__ := nil;
  Lock_Pool_Cirtical__.Free;
  Lock_Pool_Cirtical__ := nil;
  Atom_Num_Critical__.Free;
  Atom_Num_Critical__ := nil;
  TimeTick_Critical__.Free;
  TimeTick_Critical__ := nil;
{$IFDEF DEBUG}
  if IsConsole then
      Writeln('Done');
{$ENDIF DEBUG}
end;

function Get_Atom_Lock_Pool_Num: NativeInt;
begin
  Lock_Pool_Cirtical__.Acquire;
  Result := Lock_Pool__.Num;
  Lock_Pool_Cirtical__.Release;
end;

procedure Get_Critical_Lock__(const Obj: TObject; var Critical_Result: PCritical_Struct; const Optimize: Boolean);
begin
  if Lock_Pool__.Num > 0 then
    with Lock_Pool__.Repeat_ do
      repeat
        if Queue^.Data^.Obj = Obj then
          begin
            if Optimize then
                Lock_Pool__.MoveToFirst(Queue);
            Critical_Result := Queue^.Data;
            exit;
          end;
      until not Next;

  new(Critical_Result);
  Critical_Result^.Obj := Obj;
  Critical_Result^.LEnter := 0;
  Critical_Result^.Critical := TCritical.Create('Get_Critical_Lock__');
  if Lock_Pool__.Num > 0 then
      Critical_Result^.Pool_Ptr := Lock_Pool__.Insert(Critical_Result, Lock_Pool__.First)
  else
      Critical_Result^.Pool_Ptr := Lock_Pool__.Add(Critical_Result);
end;

procedure Lock_Critical_Obj__(Obj: TObject);
var
  p: PCritical_Struct;
begin
  Lock_Pool_Cirtical__.Acquire;
  Get_Critical_Lock__(Obj, p, True);
  Inc(p^.LEnter);
  Lock_Pool_Cirtical__.Release;
  p^.Critical.Acquire;
end;

procedure UnLock_Critical_Obj__(Obj: TObject);
var
  p: PCritical_Struct;
begin
  Lock_Pool_Cirtical__.Acquire;
  Get_Critical_Lock__(Obj, p, False);
  Dec(p^.LEnter);
  if p^.LEnter = 0 then
    begin
      p^.Pool_Ptr^.Data := nil;
      Lock_Pool__.Remove_P(p^.Pool_Ptr);
      Lock_Pool_Cirtical__.Release;
      p^.Critical.Release;
      p^.Critical.Free;
      Dispose(p);
    end
  else if p^.LEnter > 0 then
    begin
      Lock_Pool_Cirtical__.Release;
      p^.Critical.Release;
    end
  else
    begin
      Lock_Pool_Cirtical__.Release;
      RaiseInfo('error: unlock failed: illegal unlock');
    end;
end;

function Get_CRC32(const Data: PByte; const Size: NativeInt): THash;
var
  p: PByte;
  Count: NativeInt;
  hash: THash;
begin
  p := Data;
  Count := Size;
  hash := $FFFFFFFF;
  if Size > 0 then
    while Count > 0 do
      begin
        hash := ((hash shr 8) and $00FFFFFF) xor C_CRC32Table[(hash xor p^) and $000000FF];
        Inc(p);
        Dec(Count);
      end
  else
    while Count < 0 do
      begin
        hash := ((hash shr 8) and $00FFFFFF) xor C_CRC32Table[(hash xor p^) and $000000FF];
        Dec(p);
        Inc(Count);
      end;
  Result := hash xor $FFFFFFFF;
end;

function Hash_Key_Mod(const hash: THash; const Num: Integer): Integer;
begin
  Result := 0;
  if (Num > 0) and (hash > 0) then
    begin
      Result := hash mod Num;
      if Result > Num - 1 then
          Result := Num - 1;
    end;
end;

function DeltaNum(const value_, Delta_: NativeInt): NativeInt;
begin
  if Delta_ > 0 then
      Result := (value_ + (Delta_ - 1)) and (not(Delta_ - 1))
  else
      Result := value_;
end;

function DeltaStep(const value_, Delta_: NativeInt): NativeInt;
begin
  if Delta_ > 0 then
      Result := (value_ + (Delta_ - 1)) and (not(Delta_ - 1))
  else
      Result := value_;
end;

procedure Wait_All_Signal(var arry: TBool_Signal_Array; const signal_: Boolean);
var
  i: Boolean;
  r: Boolean;
begin
  repeat
    r := True;
    for i in arry do
        r := r and (i = signal_);
    if not r then
        TCompute.Sleep(1);
  until r;
end;

procedure Wait_All_Signal(const arry: PBool_Signal_Array; const signal_: Boolean);
var
  p: PBoolean;
  r: Boolean;
begin
  repeat
    r := True;
    for p in arry do
        r := r and (p^ = signal_);
    if not r then
        TCompute.Sleep(1);
  until r;
end;

procedure Wait_All_Signal(var arry: TInteger_Signal_Array; const signal_: Integer);
var
  i: Integer;
  r: Boolean;
begin
  repeat
    r := True;
    for i in arry do
        r := r and (i = signal_);
    if not r then
        TCompute.Sleep(1);
  until r;
end;

procedure Wait_All_Signal(const arry: PInteger_Signal_Array; const signal_: Integer);
var
  p: PInteger;
  r: Boolean;
begin
  repeat
    r := True;
    for p in arry do
        r := r and (p^ = signal_);
    if not r then
        TCompute.Sleep(1);
  until r;
end;

function AtomInc(var x: Int64): Int64;
begin
{$IFDEF FPC}
  {$IFDEF USED_INTERLOCK}
    // Atomically increment by 1, return the new value
    Result := InterlockedExchangeAdd64(x, 1) + 1;
  {$ELSE}
    Atom_Num_Critical__.Acquire;
    Inc(x);
    Result := x;
    Atom_Num_Critical__.Release;
  {$ENDIF}
{$ELSE FPC}
  Result := System.AtomicIncrement(x);
{$ENDIF FPC}
end;

function AtomInc(var x: Int64; const v: Int64): Int64;
begin
{$IFDEF FPC}
  {$IFDEF USED_INTERLOCK}
    // Atomically add v, return the new value
    Result := InterlockedExchangeAdd64(x, v) + v;
  {$ELSE}
    Atom_Num_Critical__.Acquire;
    Inc(x, v);
    Result := x;
    Atom_Num_Critical__.Release;
  {$ENDIF}
{$ELSE FPC}
  Result := System.AtomicIncrement(x, v);
{$ENDIF FPC}
end;

function AtomDec(var x: Int64): Int64;
begin
{$IFDEF FPC}
  {$IFDEF USED_INTERLOCK}
    // Atomically decrement by 1, return the new value
    Result := InterlockedExchangeAdd64(x, -1) - 1;
  {$ELSE}
    Atom_Num_Critical__.Acquire;
    Dec(x);
    Result := x;
    Atom_Num_Critical__.Release;
  {$ENDIF}
{$ELSE FPC}
  Result := System.AtomicDecrement(x);
{$ENDIF FPC}
end;

function AtomDec(var x: Int64; const v: Int64): Int64;
begin
{$IFDEF FPC}
  {$IFDEF USED_INTERLOCK}
    // Atomically subtract v, return the new value
    Result := InterlockedExchangeAdd64(x, -v) - v;
  {$ELSE}
    Atom_Num_Critical__.Acquire;
    Dec(x, v);
    Result := x;
    Atom_Num_Critical__.Release;
  {$ENDIF}
{$ELSE FPC}
  Result := System.AtomicDecrement(x, v);
{$ENDIF FPC}
end;

// ---------- UInt64 versions ----------
function AtomInc(var x: UInt64): UInt64;
begin
{$IFDEF FPC}
  {$IFDEF USED_INTERLOCK}
    // Treat UInt64 as Int64 for atomic operation, convert back to UInt64
    Result := UInt64(InterlockedExchangeAdd64(PInt64(@x)^, 1) + 1);
  {$ELSE}
    Atom_Num_Critical__.Acquire;
    Inc(x);
    Result := x;
    Atom_Num_Critical__.Release;
  {$ENDIF}
{$ELSE FPC}
  Result := System.AtomicIncrement(x);
{$ENDIF FPC}
end;

function AtomInc(var x: UInt64; const v: UInt64): UInt64;
begin
{$IFDEF FPC}
  {$IFDEF USED_INTERLOCK}
    Result := UInt64(InterlockedExchangeAdd64(PInt64(@x)^, Int64(v)) + Int64(v));
  {$ELSE}
    Atom_Num_Critical__.Acquire;
    Inc(x, v);
    Result := x;
    Atom_Num_Critical__.Release;
  {$ENDIF}
{$ELSE FPC}
  Result := System.AtomicIncrement(x, v);
{$ENDIF FPC}
end;

function AtomDec(var x: UInt64): UInt64;
begin
{$IFDEF FPC}
  {$IFDEF USED_INTERLOCK}
    Result := UInt64(InterlockedExchangeAdd64(PInt64(@x)^, -1) - 1);
  {$ELSE}
    Atom_Num_Critical__.Acquire;
    Dec(x);
    Result := x;
    Atom_Num_Critical__.Release;
  {$ENDIF}
{$ELSE FPC}
  Result := System.AtomicDecrement(x);
{$ENDIF FPC}
end;

function AtomDec(var x: UInt64; const v: UInt64): UInt64;
begin
{$IFDEF FPC}
  {$IFDEF USED_INTERLOCK}
    Result := UInt64(InterlockedExchangeAdd64(PInt64(@x)^, -Int64(v)) - Int64(v));
  {$ELSE}
    Atom_Num_Critical__.Acquire;
    Dec(x, v);
    Result := x;
    Atom_Num_Critical__.Release;
  {$ENDIF}
{$ELSE FPC}
  Result := System.AtomicDecrement(x, v);
{$ENDIF FPC}
end;

// ---------- Integer versions ----------
function AtomInc(var x: Integer): Integer;
begin
{$IFDEF FPC}
  {$IFDEF USED_INTERLOCK}
    Result := InterlockedExchangeAdd(x, 1) + 1;
  {$ELSE}
    Atom_Num_Critical__.Acquire;
    Inc(x);
    Result := x;
    Atom_Num_Critical__.Release;
  {$ENDIF}
{$ELSE FPC}
  Result := System.AtomicIncrement(x);
{$ENDIF FPC}
end;

function AtomInc(var x: Integer; const v: Integer): Integer;
begin
{$IFDEF FPC}
  {$IFDEF USED_INTERLOCK}
    Result := InterlockedExchangeAdd(x, v) + v;
  {$ELSE}
    Atom_Num_Critical__.Acquire;
    Inc(x, v);
    Result := x;
    Atom_Num_Critical__.Release;
  {$ENDIF}
{$ELSE FPC}
  Result := System.AtomicIncrement(x, v);
{$ENDIF FPC}
end;

function AtomDec(var x: Integer): Integer;
begin
{$IFDEF FPC}
  {$IFDEF USED_INTERLOCK}
    Result := InterlockedExchangeAdd(x, -1) - 1;
  {$ELSE}
    Atom_Num_Critical__.Acquire;
    Dec(x);
    Result := x;
    Atom_Num_Critical__.Release;
  {$ENDIF}
{$ELSE FPC}
  Result := System.AtomicDecrement(x);
{$ENDIF FPC}
end;

function AtomDec(var x: Integer; const v: Integer): Integer;
begin
{$IFDEF FPC}
  {$IFDEF USED_INTERLOCK}
    Result := InterlockedExchangeAdd(x, -v) - v;
  {$ELSE}
    Atom_Num_Critical__.Acquire;
    Dec(x, v);
    Result := x;
    Atom_Num_Critical__.Release;
  {$ENDIF}
{$ELSE FPC}
  Result := System.AtomicDecrement(x, v);
{$ENDIF FPC}
end;

// ---------- Cardinal versions ----------
function AtomInc(var x: Cardinal): Cardinal;
begin
{$IFDEF FPC}
  {$IFDEF USED_INTERLOCK}
    // FPC provides an overload for Cardinal
    Result := InterlockedExchangeAdd(x, 1) + 1;
  {$ELSE}
    Atom_Num_Critical__.Acquire;
    Inc(x);
    Result := x;
    Atom_Num_Critical__.Release;
  {$ENDIF}
{$ELSE FPC}
  Result := System.AtomicIncrement(x);
{$ENDIF FPC}
end;

function AtomInc(var x: Cardinal; const v: Cardinal): Cardinal;
begin
{$IFDEF FPC}
  {$IFDEF USED_INTERLOCK}
    Result := InterlockedExchangeAdd(x, v) + v;
  {$ELSE}
    Atom_Num_Critical__.Acquire;
    Inc(x, v);
    Result := x;
    Atom_Num_Critical__.Release;
  {$ENDIF}
{$ELSE FPC}
  Result := System.AtomicIncrement(x, v);
{$ENDIF FPC}
end;

function AtomDec(var x: Cardinal): Cardinal;
begin
{$IFDEF FPC}
  {$IFDEF USED_INTERLOCK}
    // Decrement by 1 is equivalent to adding Cardinal(-1)
    Result := InterlockedExchangeAdd(x, Cardinal(-1)) + Cardinal(-1);
  {$ELSE}
    Atom_Num_Critical__.Acquire;
    Dec(x);
    Result := x;
    Atom_Num_Critical__.Release;
  {$ENDIF}
{$ELSE FPC}
  Result := System.AtomicDecrement(x);
{$ENDIF FPC}
end;

function AtomDec(var x: Cardinal; const v: Cardinal): Cardinal;
begin
{$IFDEF FPC}
  {$IFDEF USED_INTERLOCK}
    // Subtract v is equivalent to adding Cardinal(-v)
    Result := InterlockedExchangeAdd(x, Cardinal(-v)) + Cardinal(-v);
  {$ELSE}
    Atom_Num_Critical__.Acquire;
    Dec(x, v);
    Result := x;
    Atom_Num_Critical__.Release;
  {$ENDIF}
{$ELSE FPC}
  Result := System.AtomicDecrement(x, v);
{$ENDIF FPC}
end;

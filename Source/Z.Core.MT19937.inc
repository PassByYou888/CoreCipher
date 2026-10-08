(*
  paper: Mersenne Twister: A 623-dimensionallyequidistributed uniformpseudorandom number generator
  post by 2002

  reference material
  https://baike.baidu.com/item/%E6%A2%85%E6%A3%AE%E7%B4%A0%E6%95%B0
  https://baike.baidu.com/item/%E6%A2%85%E6%A3%AE%E6%97%8B%E8%BD%AC%E7%AE%97%E6%B3%95
  https://www.cnblogs.com/lfri/p/11461695.html
  https://en.wikipedia.org/wiki/Mersenne_twister
*)
const
  MT19937N = 624;
  MT19937M = 397;
  Mag01: array [0 .. 1] of Integer = (0, Integer($9908B0DF));
  MT19937UPPER_MASK = Integer($80000000); // most significant r/w bits
  MT19937LOWER_MASK = Integer($7FFFFFFF); // least significant r bits
  TEMPERING_MASK_B = Integer($9D2C5680);
  TEMPERING_MASK_C = Integer($EFC60000);

type
  TMTVector = array [0 .. MT19937N - 1] of Integer;
  PMD19937Core = ^TMT19937Core;
  TMT19937_Pool_Decl__ = TBigList<PMD19937Core>;

  TMT19937_Pool__ = class(TMT19937_Pool_Decl__)
  public
    procedure DoFree(var Data: PMD19937Core); override;
  end;

  TMT19937Core = record
    MT: TMTVector; // the array for the state vector
    MTI: Integer;
    InternalRndSeed, InternalOldRndSeed: Cardinal;
    Thread: TCore_Thread;
    LastActivtedTime: TTimeTick;
    Busy: Boolean;
    Instance_TMT19937Random__: Integer;
    Queue_Data_Ptr__: TMT19937_Pool_Decl__.PQueueStruct;
    procedure BuildMT(Seed_: Integer);
    function GenRand_MT19937(): Integer;
    procedure Init(Thread_: TCore_Thread; LastActivtedTime_: TTimeTick);
    procedure Serialize(stream: TCore_Stream);
    procedure Unserialize(stream: TCore_Stream);
  end;

procedure TMT19937_Pool__.DoFree(var Data: PMD19937Core);
begin
  if Data <> nil then
    begin
      Dispose(Data);
      Data := nil;
    end;
end;

{ Initializing the array with a seed }
procedure TMT19937Core.BuildMT(Seed_: Integer);
var
  i: Integer;
begin
  MT[0] := Integer(Seed_);
  for i := 1 to MT19937N - 1 do
    begin
      MT[i] := 1812433253 * (MT[i - 1] xor (MT[i - 1] shr 30)) + i;
      { See Knuth TAOCP Vol2. 3rd Ed. P.106 for multiplier. }
      { In the previous versions, MSBs of the seed affect }
      { only MSBs of the array mt[]. }
      { 2002/01/09 modified by Makoto Matsumoto }
    end;
  MTI := MT19937N;
end;

function TMT19937Core.GenRand_MT19937(): Integer;
var
  Y, K: Integer;
begin
  if InternalRndSeed <> InternalOldRndSeed then
      MTI := MT19937N + 1;

  { generate MT19937N longints at one time }
  if (MTI >= MT19937N) then
    begin
      { if BuildMT() has not been called }
      if MTI = (MT19937N + 1) then
        begin
          { default initial seed is used }
          BuildMT(Integer(InternalRndSeed));

          { hack: InternalRndSeed is not used more than once in this algorithm. Most }
          { user changes are re-initialising reandseed with the value it had }
          { at the start -> with the "not", we will detect this change. }
          { Detecting other changes is not useful, since the generated }
          { numbers will be different anyway. }
          InternalRndSeed := not(InternalRndSeed);
          InternalOldRndSeed := InternalRndSeed;
        end;

      for K := 0 to MT19937N - MT19937M - 1 do
        begin
          Y := (MT[K] and MT19937UPPER_MASK) or (MT[K + 1] and MT19937LOWER_MASK);
          MT[K] := MT[K + MT19937M] xor (Y shr 1) xor Mag01[Y and $00000001];
        end;

      for K := MT19937N - MT19937M to MT19937N - 2 do
        begin
          Y := (MT[K] and MT19937UPPER_MASK) or (MT[K + 1] and MT19937LOWER_MASK);
          MT[K] := MT[K + (MT19937M - MT19937N)] xor (Y shr 1) xor Mag01[Y and $00000001];
        end;

      Y := (MT[MT19937N - 1] and MT19937UPPER_MASK) or (MT[0] and MT19937LOWER_MASK);
      MT[MT19937N - 1] := MT[MT19937M - 1] xor (Y shr 1) xor Mag01[Y and $00000001];
      MTI := 0;
    end;

  Y := MT[MTI];
  inc(MTI);
  Y := Y xor (Y shr 11);
  Y := Y xor (Y shl 7) and TEMPERING_MASK_B;
  Y := Y xor (Y shl 15) and TEMPERING_MASK_C;
  Y := Y xor (Y shr 18);
  Result := Y;
end;

procedure TMT19937Core.Init(Thread_: TCore_Thread; LastActivtedTime_: TTimeTick);
begin
  InternalRndSeed := 0;
  InternalOldRndSeed := 0;
  BuildMT(0);
  Thread := Thread_;
  LastActivtedTime := LastActivtedTime_;
  Busy := False;
  Instance_TMT19937Random__ := 0;
  Queue_Data_Ptr__ := nil;
end;

procedure TMT19937Core.Serialize(stream: TCore_Stream);
begin
  stream.WriteBuffer(MT[0], SizeOf(TMTVector));
  stream.WriteBuffer(MTI, 4);
  stream.WriteBuffer(InternalRndSeed, 4);
  stream.WriteBuffer(InternalOldRndSeed, 4);
end;

procedure TMT19937Core.Unserialize(stream: TCore_Stream);
begin
  stream.ReadBuffer(MT[0], SizeOf(TMTVector));
  stream.ReadBuffer(MTI, 4);
  stream.ReadBuffer(InternalRndSeed, 4);
  stream.ReadBuffer(InternalOldRndSeed, 4);
end;

var
  MT19937InternalCritical: TCritical;
  MT19937_POOL__: TMT19937_Pool__;
  MT19937CoreToDelphi_: Boolean;
  Randomize_Seed__: Integer;

function Get_MT19937_POOL_Num: NativeInt;
begin
  MT19937InternalCritical.Acquire;
  Result := MT19937_POOL__.Num;
  MT19937InternalCritical.Release;
end;

function InternalMT19937__(): PMD19937Core;
var
  Th: TCore_Thread;
  R_: PMD19937Core;
  tk: TTimeTick;
begin
  Th := TCore_Thread.CurrentThread;
  if (Th is TCompute) and (TCompute(Th).FRndInstance <> nil) then
    begin
      Result := TCompute(Th).FRndInstance;
      Result^.LastActivtedTime := GetTimeTick();
      exit;
    end;

  R_ := nil;
  MT19937InternalCritical.Acquire;
  try
    MT19937_POOL__.Free_Recycle_Pool;

    if MT19937_POOL__.Num > 0 then
      begin
        tk := GetTimeTick();
        with MT19937_POOL__.Repeat_ do
          repeat
            if queue^.Data^.Thread = Th then
              begin
                queue^.Data^.LastActivtedTime := tk;
                R_ := queue^.Data;
              end
            else if (not queue^.Data^.Busy) and (queue^.Data^.Instance_TMT19937Random__ <= 0) and
              (tk - queue^.Data^.LastActivtedTime > MT19937LifeTime) then
              begin
                MT19937_POOL__.Push_To_Recycle_Pool(queue);
              end;
          until not Next;
      end;

    MT19937_POOL__.Free_Recycle_Pool;

    if R_ = nil then
      begin
        New(R_);
        R_^.Init(Th, GetTimeTick);
        R_^.Queue_Data_Ptr__ := MT19937_POOL__.Add(R_);
      end;
    MT19937_POOL__.MoveToFirst(R_^.Queue_Data_Ptr__);
  finally
    Result := R_;
    MT19937InternalCritical.Release;
  end;
end;

procedure RemoveMT19937Thread(Th: TCore_Thread);
begin
  MT19937InternalCritical.Acquire;
  try
    MT19937_POOL__.Free_Recycle_Pool;
    if MT19937_POOL__.Num > 0 then
      with MT19937_POOL__.Repeat_ do
        repeat
          if (queue^.Data^.Thread = Th) or
            ((not queue^.Data^.Busy) and (queue^.Data^.Instance_TMT19937Random__ <= 0) and
              (GetTimeTick - queue^.Data^.LastActivtedTime > MT19937LifeTime)) then
              MT19937_POOL__.Push_To_Recycle_Pool(queue);
        until not Next;
    MT19937_POOL__.Free_Recycle_Pool;
  finally
      MT19937InternalCritical.Release;
  end;
end;

{$IFDEF DELPHI}

{$IFDEF InstallMT19937CoreToDelphi}


function DelphiRandom32Proc: UInt32;
begin
  Result := UInt32(InternalMT19937__()^.GenRand_MT19937());
end;

procedure DelphiRandomizeProc(NewSeed: UInt64);
begin
  InternalMT19937__()^.InternalRndSeed := Cardinal(NewSeed);
end;

procedure MT19937Install();
begin
  Random32Proc := DelphiRandom32Proc;
  RandomizeProc := DelphiRandomizeProc;
  MT19937CoreToDelphi_ := True;
end;
{$ENDIF InstallMT19937CoreToDelphi}

{$ENDIF DELPHI}


procedure InitMT19937Rand;
begin
{$IFDEF DEBUG}
  if IsConsole then
      Writeln('Init MT19937');
{$ENDIF DEBUG}
  MT19937InternalCritical := TCritical.Create('MT19937InternalCritical');
  MT19937_POOL__ := TMT19937_Pool__.Create;
  MT19937CoreToDelphi_ := False;
  Randomize_Seed__ := 1;

{$IFDEF DELPHI}
{$IFDEF InstallMT19937CoreToDelphi}
  MT19937Install();
{$ENDIF InstallMT19937CoreToDelphi}
{$ENDIF DELPHI}
  MT19937LifeTime := 10 * 1000;
end;

procedure FreeMT19937Rand;
begin
{$IFDEF DEBUG}
  if IsConsole then
      Writeln('Free MT19937');
{$ENDIF DEBUG}
  MT19937_POOL__.Free;
  MT19937_POOL__ := nil;
  MT19937InternalCritical.Free;
  MT19937InternalCritical := nil;
end;

function MT19937CoreToDelphi: Boolean;
begin
  Result := MT19937CoreToDelphi_;
end;

function MT19937InstanceNum(): Integer;
begin
  MT19937InternalCritical.Acquire;
  Result := MT19937_POOL__.Num;
  MT19937InternalCritical.Release;
end;

procedure SetMT19937Seed(seed: Integer);
begin
  with InternalMT19937__()^ do
    begin
      MT19937InternalCritical.Acquire;
      InternalRndSeed := seed;
      InternalOldRndSeed := seed;
      BuildMT(seed);
      Thread := TCore_Thread.CurrentThread;
      LastActivtedTime := GetTimeTick();
      MT19937InternalCritical.Release;
    end;
end;

function GetMT19937Seed(): Integer;
begin
  Result := InternalMT19937__()^.InternalRndSeed;
end;

procedure MT19937Randomize();
var
  seed: Integer;
begin
  MT19937InternalCritical.Acquire;
  seed := Randomize_Seed__;
{$IFDEF OverflowCheck}{$Q-}{$ENDIF}
  inc(Randomize_Seed__);
{$IFDEF OverflowCheck}{$Q+}{$ENDIF}
  MT19937InternalCritical.Release;
  SetMT19937Seed(seed);
end;

function MT19937Rand32: Integer;
begin
  Result := MT19937Rand32($7FFFFFFF);
end;

function MT19937Rand32(L: Integer): Integer;
begin
  { otherwise we can return values = L (JM) }
  if (L < 0) then
      inc(L);
  Result := Integer((Int64(Cardinal(InternalMT19937__()^.GenRand_MT19937())) * L) shr 32);
end;

procedure MT19937Rand32(L: Integer; dest: PInteger; Num: NativeInt);
begin
  { otherwise we can return values = L (JM) }
  if (L < 0) then
      inc(L);

  with InternalMT19937__()^ do
    begin
      Busy := True;
      try
        while Num > 0 do
          begin
            dest^ := Integer((Int64(Cardinal(GenRand_MT19937())) * L) shr 32);
            dec(Num);
            inc(dest);
          end;
      finally
        LastActivtedTime := GetTimeTick();
        Busy := False;
      end;
    end;
end;

function MT19937Rand64: Int64;
begin
  Result := MT19937Rand64($7FFFFFFFFFFFFFFF);
end;

function MT19937Rand64(L: Int64): Int64;
begin
  { always call random, so the random generator cycles (TP-compatible) (JM) }
  with InternalMT19937__()^ do
      Result := Int64((UInt64(Cardinal(GenRand_MT19937())) or ((UInt64(Cardinal(GenRand_MT19937())) shl 32))) and $7FFFFFFFFFFFFFFF);
  if (L <> 0) then
      Result := Result mod L
  else
      Result := 0;
end;

procedure MT19937Rand64(L: Int64; dest: PInt64; Num: NativeInt);
begin
  with InternalMT19937__()^ do
    begin
      Busy := True;
      try
        while Num > 0 do
          begin
            dest^ := Int64((UInt64(Cardinal(GenRand_MT19937())) or ((UInt64(Cardinal(GenRand_MT19937())) shl 32))) and $7FFFFFFFFFFFFFFF);
            if (dest^ <> 0) then
                dest^ := dest^ mod L
            else
                dest^ := 0;
            dec(Num);
            inc(dest);
          end;
      finally
        LastActivtedTime := GetTimeTick();
        Busy := False;
      end;
    end;
end;

function MT19937RandE: Extended;
const
  f: Extended = 1.0 / (Int64(1) shl 32);
begin
  Result := f * Cardinal(InternalMT19937__()^.GenRand_MT19937());
end;

procedure MT19937RandE(dest: PExtended; Num: NativeInt);
const
  f: Extended = 1.0 / (Int64(1) shl 32);
begin
  with InternalMT19937__()^ do
    begin
      Busy := True;
      try
        while Num > 0 do
          begin
            dest^ := f * Cardinal(GenRand_MT19937());
            dec(Num);
            inc(dest);
          end;
      finally
        LastActivtedTime := GetTimeTick();
        Busy := False;
      end;
    end;
end;

function MT19937RandF: Single;
const
  f: Single = 1.0 / (Int64(1) shl 32);
begin
  Result := f * Cardinal(InternalMT19937__()^.GenRand_MT19937());
end;

procedure MT19937RandF(dest: PSingle; Num: NativeInt);
const
  f: Single = 1.0 / (Int64(1) shl 32);
begin
  with InternalMT19937__()^ do
    begin
      Busy := True;
      try
        while Num > 0 do
          begin
            dest^ := f * Cardinal(GenRand_MT19937());
            dec(Num);
            inc(dest);
          end;
      finally
        LastActivtedTime := GetTimeTick();
        Busy := False;
      end;
    end;
end;

function MT19937RandD: Double;
const
  f: Double = 1.0 / (Int64(1) shl 32);
begin
  Result := f * Cardinal(InternalMT19937__()^.GenRand_MT19937());
end;

procedure MT19937RandD(dest: PDouble; Num: NativeInt);
const
  f: Double = 1.0 / (Int64(1) shl 32);
begin
  with InternalMT19937__()^ do
    begin
      Busy := True;
      try
        while Num > 0 do
          begin
            dest^ := f * Cardinal(GenRand_MT19937());
            dec(Num);
            inc(dest);
          end;
      finally
        LastActivtedTime := GetTimeTick();
        Busy := False;
      end;
    end;
end;

procedure MT19937SaveToStream(stream: TCore_Stream);
begin
  InternalMT19937__()^.Serialize(stream);
end;

procedure MT19937LoadFromStream(stream: TCore_Stream);
begin
  InternalMT19937__()^.Unserialize(stream);
end;

{ ****************************************************************************** }
{ * TMT19937 classes                                                           * }
{ ****************************************************************************** }
function TMT19937Random.GetSeed: Integer;
begin
  with PMD19937Core(FRndInstance)^ do
      Result := InternalRndSeed;
end;

procedure TMT19937Random.SetSeed(const Value: Integer);
begin
  with PMD19937Core(FRndInstance)^ do
    begin
      InternalRndSeed := Value;
      InternalOldRndSeed := Value;
      BuildMT(Value);
    end;
end;

constructor TMT19937Random.Create;
begin
  inherited Create;
  FInternalCritical := TCritical.Create('TMT19937Random.InternalCritical');
  FRndInstance := InternalMT19937__();
  AtomInc(PMD19937Core(FRndInstance)^.Instance_TMT19937Random__);
end;

destructor TMT19937Random.Destroy;
begin
  FInternalCritical.Free;
  AtomDec(PMD19937Core(FRndInstance)^.Instance_TMT19937Random__);
  inherited Destroy;
end;

procedure TMT19937Random.Rndmize;
begin
  FInternalCritical.Acquire;
  with PMD19937Core(FRndInstance)^ do
      InternalRndSeed := GetTimeTick();
  FInternalCritical.Release;
end;

function TMT19937Random.Rand32(L: Integer): Integer;
begin
  FInternalCritical.Acquire;
  { otherwise we can return values = L (JM) }
  if (L < 0) then
      inc(L);
  with PMD19937Core(FRndInstance)^ do
      Result := Integer((Int64(Cardinal(GenRand_MT19937())) * L) shr 32);
  FInternalCritical.Release;
end;

procedure TMT19937Random.Rand32(L: Integer; dest: PInteger; Num: NativeInt);
begin
  FInternalCritical.Acquire;
  { otherwise we can return values = L (JM) }
  if (L < 0) then
      inc(L);

  with PMD19937Core(FRndInstance)^ do
    begin
      while Num > 0 do
        begin
          dest^ := Integer((Int64(Cardinal(GenRand_MT19937())) * L) shr 32);
          dec(Num);
          inc(dest);
        end;
    end;
  FInternalCritical.Release;
end;

function TMT19937Random.Rand64(L: Int64): Int64;
begin
  FInternalCritical.Acquire;
  { always call random, so the random generator cycles (TP-compatible) (JM) }
  with PMD19937Core(FRndInstance)^ do
      Result := Int64((UInt64(Cardinal(GenRand_MT19937())) or ((UInt64(Cardinal(GenRand_MT19937())) shl 32))) and $7FFFFFFFFFFFFFFF);
  if (L <> 0) then
      Result := Result mod L
  else
      Result := 0;
  FInternalCritical.Release;
end;

procedure TMT19937Random.Rand64(L: Int64; dest: PInt64; Num: NativeInt);
begin
  FInternalCritical.Acquire;
  with PMD19937Core(FRndInstance)^ do
    begin
      while Num > 0 do
        begin
          dest^ := Int64((UInt64(Cardinal(GenRand_MT19937())) or ((UInt64(Cardinal(GenRand_MT19937())) shl 32))) and $7FFFFFFFFFFFFFFF);
          if (dest^ <> 0) then
              dest^ := dest^ mod L
          else
              dest^ := 0;
          dec(Num);
          inc(dest);
        end;
    end;
  FInternalCritical.Release;
end;

function TMT19937Random.RandE: Extended;
const
  f: Extended = 1.0 / (Int64(1) shl 32);
begin
  FInternalCritical.Acquire;
  with PMD19937Core(FRndInstance)^ do
      Result := f * Cardinal(GenRand_MT19937());
  FInternalCritical.Release;
end;

procedure TMT19937Random.RandE(dest: PExtended; Num: NativeInt);
const
  f: Extended = 1.0 / (Int64(1) shl 32);
begin
  FInternalCritical.Acquire;
  with PMD19937Core(FRndInstance)^ do
    begin
      while Num > 0 do
        begin
          dest^ := f * Cardinal(GenRand_MT19937());
          dec(Num);
          inc(dest);
        end;
    end;
  FInternalCritical.Release;
end;

function TMT19937Random.RandF: Single;
const
  f: Single = 1.0 / (Int64(1) shl 32);
begin
  FInternalCritical.Acquire;
  with PMD19937Core(FRndInstance)^ do
      Result := f * Cardinal(GenRand_MT19937());
  FInternalCritical.Release;
end;

procedure TMT19937Random.RandF(dest: PSingle; Num: NativeInt);
const
  f: Single = 1.0 / (Int64(1) shl 32);
begin
  FInternalCritical.Acquire;
  with PMD19937Core(FRndInstance)^ do
    begin
      while Num > 0 do
        begin
          dest^ := f * Cardinal(GenRand_MT19937());
          dec(Num);
          inc(dest);
        end;
    end;
  FInternalCritical.Release;
end;

function TMT19937Random.RandD: Double;
const
  f: Double = 1.0 / (Int64(1) shl 32);
begin
  FInternalCritical.Acquire;
  with PMD19937Core(FRndInstance)^ do
      Result := f * Cardinal(GenRand_MT19937());
  FInternalCritical.Release;
end;

procedure TMT19937Random.RandD(dest: PDouble; Num: NativeInt);
const
  f: Double = 1.0 / (Int64(1) shl 32);
begin
  FInternalCritical.Acquire;
  with PMD19937Core(FRndInstance)^ do
    begin
      while Num > 0 do
        begin
          dest^ := f * Cardinal(GenRand_MT19937());
          dec(Num);
          inc(dest);
        end;
    end;
  FInternalCritical.Release;
end;

function TMT19937Random.RandBool: Boolean;
begin
  Result := ODD(Rand32(MaxInt));
end;

class function TMT19937.CoreToDelphi: Boolean;
begin
  Result := MT19937CoreToDelphi();
end;

class function TMT19937.InstanceNum(): Integer;
begin
  Result := MT19937InstanceNum();
end;

class procedure TMT19937.SetSeed(seed: Integer);
begin
  SetMT19937Seed(seed);
end;

class function TMT19937.GetSeed(): Integer;
begin
  Result := GetMT19937Seed();
end;

class procedure TMT19937.Randomize();
begin
  MT19937Randomize();
end;

class function TMT19937.Rand32: Integer;
begin
  Result := MT19937Rand32();
end;

class function TMT19937.Rand32(L: Integer): Integer;
begin
  Result := MT19937Rand32(L);
end;

class procedure TMT19937.Rand32(L: Integer; dest: PInteger; Num: NativeInt);
begin
  MT19937Rand32(L, dest, Num);
end;

class function TMT19937.Rand64: Int64;
begin
  Result := MT19937Rand64();
end;

class function TMT19937.Rand64(L: Int64): Int64;
begin
  Result := MT19937Rand64(L);
end;

class procedure TMT19937.Rand64(L: Int64; dest: PInt64; Num: NativeInt);
begin
  MT19937Rand64(L, dest, Num);
end;

class function TMT19937.RandE: Extended;
begin
  Result := MT19937RandE();
end;

class procedure TMT19937.RandE(dest: PExtended; Num: NativeInt);
begin
  MT19937RandE(dest, Num);
end;

class function TMT19937.RandF: Single;
begin
  Result := MT19937RandF();
end;

class procedure TMT19937.RandF(dest: PSingle; Num: NativeInt);
begin
  MT19937RandF(dest, Num);
end;

class function TMT19937.RandD: Double;
begin
  Result := MT19937RandD();
end;

class procedure TMT19937.RandD(dest: PDouble; Num: NativeInt);
begin
  MT19937RandD(dest, Num);
end;

class function TMT19937.Random: Extended;
const
  f: Extended = 1.0 / (Int64(1) shl 32);
begin
  Result := f * Cardinal(InternalMT19937__()^.GenRand_MT19937());
end;

class function TMT19937.RandomRange(const rnd: TMT19937Random; const min_, max_: Integer): Integer;
var
  mn, mx: Integer;
begin
  if min_ = max_ then
    begin
      Result := min_;
      exit;
    end;

  mn := min_;
  mx := max_;

  if mn > mx then
      inc(mn)
  else
      inc(mx);

  if mn > mx then
      Result := rnd.Rand32(mn - mx) + mx
  else
      Result := rnd.Rand32(mx - mn) + mn;
end;

class function TMT19937.RandomRange64(const rnd: TMT19937Random; const min_, max_: Int64): Int64;
var
  mn, mx: Int64;
begin
  if min_ = max_ then
    begin
      Result := min_;
      exit;
    end;

  mn := min_;
  mx := max_;

  if mn > mx then
      inc(mn)
  else
      inc(mx);

  if mn > mx then
      Result := rnd.Rand64(mn - mx) + mx
  else
      Result := rnd.Rand64(mx - mn) + mn;
end;

class function TMT19937.RandomRangeS(const rnd: TMT19937Random; const min_, max_: Single): Single;
begin
  Result := (TMT19937.RandomRange64(rnd, Trunc(min_ * 1000), Trunc(max_ * 1000))) * 0.001;
end;

class function TMT19937.RandomRangeD(const rnd: TMT19937Random; const min_, max_: Double): Double;
begin
  Result := (TMT19937.RandomRange64(rnd, Trunc(min_ * 10000), Trunc(max_ * 10000))) * 0.0001;
end;

class function TMT19937.RandomRangeF(const rnd: TMT19937Random; const min_, max_: Double): Double;
begin
  Result := (TMT19937.RandomRange64(rnd, Trunc(min_ * 10000), Trunc(max_ * 10000))) * 0.0001;
end;

class function TMT19937.RandomRange(const min_, max_: Integer): Integer;
var
  mn, mx: Integer;
begin
  if min_ = max_ then
    begin
      Result := min_;
      exit;
    end;
  mn := min_;
  mx := max_;

  if mn > mx then
      inc(mn)
  else
      inc(mx);

  if mn > mx then
      Result := MT19937Rand32(mn - mx) + mx
  else
      Result := MT19937Rand32(mx - mn) + mn;
end;

class function TMT19937.RandomRange64(const min_, max_: Int64): Int64;
var
  mn, mx: Int64;
begin
  if min_ = max_ then
    begin
      Result := min_;
      exit;
    end;
  mn := min_;
  mx := max_;

  if mn > mx then
      inc(mn)
  else
      inc(mx);

  if mn > mx then
      Result := MT19937Rand64(mn - mx) + mx
  else
      Result := MT19937Rand64(mx - mn) + mn;
end;

class function TMT19937.RandomRangeS(const min_, max_: Single): Single;
begin
  Result := (TMT19937.RandomRange64(Trunc(min_ * 1000), Trunc(max_ * 1000))) * 0.001;
end;

class function TMT19937.RandomRangeD(const min_, max_: Double): Double;
begin
  Result := (TMT19937.RandomRange64(Trunc(min_ * 10000), Trunc(max_ * 10000))) * 0.0001;
end;

class function TMT19937.RandomRangeF(const min_, max_: Double): Double;
begin
  Result := (TMT19937.RandomRange64(Trunc(min_ * 10000), Trunc(max_ * 10000))) * 0.0001;
end;

class function TMT19937.RR(const rnd: TMT19937Random; const min_, max_: Integer): Integer;
var
  mn, mx: Integer;
begin
  if min_ = max_ then
    begin
      Result := min_;
      exit;
    end;

  mn := min_;
  mx := max_;

  if mn > mx then
      inc(mn)
  else
      inc(mx);

  if mn > mx then
      Result := rnd.Rand32(mn - mx) + mx
  else
      Result := rnd.Rand32(mx - mn) + mn;
end;

class function TMT19937.RR64(const rnd: TMT19937Random; const min_, max_: Int64): Int64;
var
  mn, mx: Int64;
begin
  if min_ = max_ then
    begin
      Result := min_;
      exit;
    end;

  mn := min_;
  mx := max_;

  if mn > mx then
      inc(mn)
  else
      inc(mx);

  if mn > mx then
      Result := rnd.Rand64(mn - mx) + mx
  else
      Result := rnd.Rand64(mx - mn) + mn;
end;

class function TMT19937.RRS(const rnd: TMT19937Random; const min_, max_: Single): Single;
begin
  Result := (TMT19937.RR64(rnd, Trunc(min_ * 1000), Trunc(max_ * 1000))) * 0.001;
end;

class function TMT19937.RRD(const rnd: TMT19937Random; const min_, max_: Double): Double;
begin
  Result := (TMT19937.RR64(rnd, Trunc(min_ * 10000), Trunc(max_ * 10000))) * 0.0001;
end;

class function TMT19937.RRF(const rnd: TMT19937Random; const min_, max_: Double): Double;
begin
  Result := (TMT19937.RR64(rnd, Trunc(min_ * 10000), Trunc(max_ * 10000))) * 0.0001;
end;

class function TMT19937.RR(const min_, max_: Integer): Integer;
var
  mn, mx: Integer;
begin
  if min_ = max_ then
    begin
      Result := min_;
      exit;
    end;
  mn := min_;
  mx := max_;

  if mn > mx then
      inc(mn)
  else
      inc(mx);

  if mn > mx then
      Result := MT19937Rand32(mn - mx) + mx
  else
      Result := MT19937Rand32(mx - mn) + mn;
end;

class function TMT19937.RR64(const min_, max_: Int64): Int64;
var
  mn, mx: Int64;
begin
  if min_ = max_ then
    begin
      Result := min_;
      exit;
    end;
  mn := min_;
  mx := max_;

  if mn > mx then
      inc(mn)
  else
      inc(mx);

  if mn > mx then
      Result := MT19937Rand64(mn - mx) + mx
  else
      Result := MT19937Rand64(mx - mn) + mn;
end;

class function TMT19937.RRS(const min_, max_: Single): Single;
begin
  Result := (TMT19937.RR64(Trunc(min_ * 1000), Trunc(max_ * 1000))) * 0.001;
end;

class function TMT19937.RRD(const min_, max_: Double): Double;
begin
  Result := (TMT19937.RR64(Trunc(min_ * 10000), Trunc(max_ * 10000))) * 0.0001;
end;

class function TMT19937.RRF(const min_, max_: Double): Double;
begin
  Result := (TMT19937.RR64(Trunc(min_ * 10000), Trunc(max_ * 10000))) * 0.0001;
end;

class procedure TMT19937.SaveToStream(stream: TCore_Stream);
begin
  MT19937SaveToStream(stream);
end;

class procedure TMT19937.LoadFromStream(stream: TCore_Stream);
begin
  MT19937LoadFromStream(stream);
end;

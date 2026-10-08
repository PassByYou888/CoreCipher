{ ****************************************************************************** }
{ * Generic hash List Library                                                  * }
{ ****************************************************************************** }
unit Z.HashList.Templet;

{$DEFINE FPC_DELPHI_MODE}
{$I Z.Define.inc}

interface

uses
{$IFDEF FPC}
  Z.FPC.GenericList,
{$ENDIF FPC}
  Z.Core,
  Z.Status, Z.PascalStrings, Z.UPascalStrings, Z.UnicodeMixedLib, Z.ListEngine, Z.Int128;

function IsEqual__(const Val1, Val2, Epsilon_: Single): Boolean; overload;
function IsEqual__(const Val1, Val2, Epsilon_: Double): Boolean; overload;

type
  TString_Num_Analysis_Tool = class;

  TPascalString_Hash_Pool = class(TBig_Hash_Pair_Pool<TPascalString, TPascalString>)
  private
    FMaxNameSize: Integer;
    FMinNameSize: Integer;
  public
    procedure CreateAfter; override;
    function Get_Key_Hash(const Key_: TPascalString): THash; override;
    function Compare_Key(const Key_1, Key_2: TPascalString): Boolean; override;
    procedure DoFree(var Key: TPascalString; var Value: TPascalString); override;
    function Compare_Value(const Value_1, Value_2: TPascalString): Boolean; override;
    property MaxKeySize: Integer read FMaxNameSize;
    property MinKeySize: Integer read FMinNameSize;
  end;

  TString_Big_Hash_Pair_Pool<T_> = class(TBig_Hash_Pair_Pool<SystemString, T_>)
  private
    FMaxNameSize: Integer;
    FMinNameSize: Integer;
  public
    procedure CreateAfter; override;
    function Get_Key_Hash(const Key_: SystemString): THash; override;
    function Compare_Key(const Key_1, Key_2: SystemString): Boolean; override;
    procedure DoFree(var Key: SystemString; var Value: T_); override;
    property MaxKeySize: Integer read FMaxNameSize;
    property MinKeySize: Integer read FMinNameSize;
  end;

  TPascalString_Big_Hash_Pair_Pool<T_> = class(TBig_Hash_Pair_Pool<TPascalString, T_>)
  private
    FMaxNameSize: Integer;
    FMinNameSize: Integer;
  public
    procedure CreateAfter; override;
    function Get_Key_Hash(const Key_: TPascalString): THash; override;
    function Compare_Key(const Key_1, Key_2: TPascalString): Boolean; override;
    procedure DoFree(var Key: TPascalString; var Value: T_); override;
    property MaxKeySize: Integer read FMaxNameSize;
    property MinKeySize: Integer read FMinNameSize;
  end;

  TSingle_Big_Hash_Pair_Pool<T_> = class(TBig_Hash_Pair_Pool<Single, T_>)
  public
    Epsilon: Single;
    constructor Create(const HashSize_: Integer; const NULL_VALUE_: T_; const Epsilon_: Single);
    function Get_Key_Hash(const Key_: Single): THash; override;
    function Compare_Key(const Key_1, Key_2: Single): Boolean; override;
  end;

  TDouble_Big_Hash_Pair_Pool<T_> = class(TBig_Hash_Pair_Pool<Double, T_>)
  public
    Epsilon: Double;
    constructor Create(const HashSize_: Integer; const NULL_VALUE_: T_; const Epsilon_: Double);
    function Get_Key_Hash(const Key_: Double): THash; override;
    function Compare_Key(const Key_1, Key_2: Double): Boolean; override;
  end;

  TPointer_Big_Hash_Pair_Pool<T_> = class(TBig_Hash_Pair_Pool<Pointer, T_>)
  end;

  TInt32_Big_Hash_Pair_Pool<T_> = class(TBig_Hash_Pair_Pool<Integer, T_>)
  end;

  TInt64_Big_Hash_Pair_Pool<T_> = class(TBig_Hash_Pair_Pool<Int64, T_>)
  end;

  TUInt32_Big_Hash_Pair_Pool<T_> = class(TBig_Hash_Pair_Pool<Cardinal, T_>)
  end;

  TUInt64_Big_Hash_Pair_Pool<T_> = class(TBig_Hash_Pair_Pool<UInt64, T_>)
  end;

  TMD5_Big_Hash_Pair_Pool<T_> = class(TBig_Hash_Pair_Pool<TMD5, T_>)
  end;

  TCritical_PascalString_Hash_Pool = class(TCritical_Big_Hash_Pair_Pool<TPascalString, TPascalString>)
  public
    function Get_Key_Hash(const Key_: TPascalString): THash; override;
    function Compare_Key(const Key_1, Key_2: TPascalString): Boolean; override;
    procedure DoFree(var Key: TPascalString; var Value: TPascalString); override;
    function Compare_Value(const Value_1, Value_2: TPascalString): Boolean; override;
  end;

  TCritical_String_Big_Hash_Pair_Pool<T_> = class(TCritical_Big_Hash_Pair_Pool<SystemString, T_>)
  public
    function Get_Key_Hash(const Key_: SystemString): THash; override;
    function Compare_Key(const Key_1, Key_2: SystemString): Boolean; override;
    procedure DoFree(var Key: SystemString; var Value: T_); override;
  end;

  TCritical_PascalString_Big_Hash_Pair_Pool<T_> = class(TCritical_Big_Hash_Pair_Pool<TPascalString, T_>)
  public
    function Get_Key_Hash(const Key_: TPascalString): THash; override;
    function Compare_Key(const Key_1, Key_2: TPascalString): Boolean; override;
    procedure DoFree(var Key: TPascalString; var Value: T_); override;
  end;

  TCritical_Single_Big_Hash_Pair_Pool<T_> = class(TCritical_Big_Hash_Pair_Pool<Single, T_>)
  public
    Epsilon: Single;
    constructor Create(const HashSize_: Integer; const NULL_VALUE_: T_; const Epsilon_: Single);
    function Get_Key_Hash(const Key_: Single): THash; override;
    function Compare_Key(const Key_1, Key_2: Single): Boolean; override;
  end;

  TCritical_Double_Big_Hash_Pair_Pool<T_> = class(TCritical_Big_Hash_Pair_Pool<Double, T_>)
  public
    Epsilon: Double;
    constructor Create(const HashSize_: Integer; const NULL_VALUE_: T_; const Epsilon_: Double);
    function Get_Key_Hash(const Key_: Double): THash; override;
    function Compare_Key(const Key_1, Key_2: Double): Boolean; override;
  end;

  TCritical_MD5_Big_Hash_Pair_Pool<T_> = class(TCritical_Big_Hash_Pair_Pool<TMD5, T_>)
  end;

  TCritical_Pointer_Big_Hash_Pair_Pool<T_> = class(TCritical_Big_Hash_Pair_Pool<Pointer, T_>)
  end;

  TCritical_Int32_Big_Hash_Pair_Pool<T_> = class(TCritical_Big_Hash_Pair_Pool<Integer, T_>)
  end;

  TCritical_Int64_Big_Hash_Pair_Pool<T_> = class(TCritical_Big_Hash_Pair_Pool<Int64, T_>)
  end;

  TCritical_UInt32_Big_Hash_Pair_Pool<T_> = class(TCritical_Big_Hash_Pair_Pool<Cardinal, T_>)
  end;

  TCritical_UInt64_Big_Hash_Pair_Pool<T_> = class(TCritical_Big_Hash_Pair_Pool<UInt64, T_>)
  end;

  TString_Num_Analysis_Tool_ = TString_Big_Hash_Pair_Pool<Integer>;

  TString_Num_Analysis_Tool = class(TString_Num_Analysis_Tool_)
  public
    procedure IncValue(Key_: SystemString; Value_: Integer); overload;
    procedure IncValue(source: TString_Num_Analysis_Tool); overload;
    function Get_Max_Key_And_Value(var k: SystemString; var v: Integer): Boolean;
    function Get_Max_Key(): SystemString;
    function Get_Min_Key(): SystemString;
    function Do_Sort_By_Num(var L, R: Integer): Integer;
    procedure Sort_By_Num();
  end;

  TString_Num64_Analysis_Tool_ = TString_Big_Hash_Pair_Pool<Int64>;

  TString_Num64_Analysis_Tool = class(TString_Num64_Analysis_Tool_)
  public
    procedure IncValue(Key_: SystemString; Value_: Int64); overload;
    procedure IncValue(source: TString_Num64_Analysis_Tool); overload;
    function Get_Max_Key_And_Value(var k: SystemString; var v: Int64): Boolean;
    function Get_Max_Key(): SystemString;
    function Get_Min_Key(): SystemString;
    function Do_Sort_By_Num(var L, R: Int64): Integer;
    procedure Sort_By_Num();
  end;

  TGeneric_String_Object_Hash<T_: class> = class(TCore_Object_Intermediate)
  public type
    TRefClass_ = TGeneric_String_Object_Hash<T_>;
    TGebnericHashChangeEvent = procedure(Sender: TCore_Object; Name: SystemString; OLD_, New_: T_) of object;
    PGebnericHashListData = ^TGebnericHashListData;

    TGebnericHashListData = record
      Obj: T_;
      OnChnage: TGebnericHashChangeEvent;
    end;

    TGebnericHashListLoop_C = procedure(const Name_: PSystemString; Obj_: T_);
    TGebnericHashListLoop_M = procedure(const Name_: PSystemString; Obj_: T_) of object;
{$IFDEF FPC}
    TGebnericHashListLoop_P = procedure(const Name_: PSystemString; Obj_: T_) is nested;
{$ELSE FPC}
    TGebnericHashListLoop_P = reference to procedure(const Name_: PSystemString; Obj_: T_);
{$ENDIF FPC}
    TOnFree = procedure(var Obj_: T_) of object;
  private
    FAutoFreeObject: Boolean;
    FHashList: THashList;
    FIncremental: NativeInt;
    Default_NULL_VALUE: T_;

    function GetCount: NativeInt;

    function GetIgnoreCase: Boolean;
    procedure SetIgnoreCase(const Value: Boolean);

    function GetKeyValue(const Name: SystemString): T_;
    procedure SetKeyValue(const Name: SystemString; const Value: T_);

    function GetOnChange(const Name: SystemString): TGebnericHashChangeEvent;
    procedure SetOnChange(const Name: SystemString; const AValue: TGebnericHashChangeEvent);

    function GetAccessOptimization: Boolean;
    procedure SetAccessOptimization(const Value: Boolean);

    procedure Do_HashList_DataFree(p: Pointer);
    procedure Do_Free_Obj(var Obj_: T_);
  protected
  public
    OnFree: TOnFree;
    procedure DoInited; virtual;
    constructor Create(AutoFreeData_: Boolean; HashPoolSize_: Integer; Default_NULL_VALUE_: T_);
    destructor Destroy; override;

    procedure Assign(sour: TRefClass_);

    procedure ProgressC(const OnProgress: TGebnericHashListLoop_C);
    procedure ProgressM(const OnProgress: TGebnericHashListLoop_M);
    procedure ProgressP(const OnProgress: TGebnericHashListLoop_P);

    procedure Clear;
    procedure GetNameList(OutputList: TCore_Strings); overload;
    procedure GetNameList(OutputList: TListString); overload;
    procedure GetNameList(OutputList: TListPascalString); overload;
    procedure GetListData(OutputList: TCore_Strings); overload;
    procedure GetListData(OutputList: TListString); overload;
    procedure GetListData(OutputList: TListPascalString); overload;
    procedure GetAsList(OutputList: TCore_ListForObj);
    function GetObjAsName(Obj: T_): SystemString;
    procedure Delete(const Name: SystemString);
    function Add(const Name: SystemString; Obj_: T_): T_;
    function FastAdd(const Name: SystemString; Obj_: T_): T_;
    function Find(const Name: SystemString): T_;
    function Exists(const Name: SystemString): Boolean;
    function ExistsObject(Obj: T_): Boolean;
    procedure CopyFrom(const source: TRefClass_);
    function ReName(OLD_, New_: SystemString): Boolean;
    function MakeName: SystemString;
    function MakeRefName(RefrenceName: SystemString): SystemString;

    property AccessOptimization: Boolean read GetAccessOptimization write SetAccessOptimization;
    property IgnoreCase: Boolean read GetIgnoreCase write SetIgnoreCase;
    property AutoFreeObject: Boolean read FAutoFreeObject write FAutoFreeObject;
    property Count: NativeInt read GetCount;

    property KeyValue[const Name: SystemString]: T_ read GetKeyValue write SetKeyValue; default;
    property NameValue[const Name: SystemString]: T_ read GetKeyValue write SetKeyValue;
    property OnChange[const Name: SystemString]: TGebnericHashChangeEvent read GetOnChange write SetOnChange;
    property HashList: THashList read FHashList;
  end;

procedure Test_Generic_String_Object_Hash;
procedure Test_Single_Big_Hash_Pair_Pool();

implementation

uses SysUtils;

function IsEqual__(const Val1, Val2, Epsilon_: Single): Boolean;
var
  Diff: Single;
begin
  Diff := Val1 - Val2;
  Result := ((-Epsilon_ <= Diff) and (Diff <= Epsilon_));
end;

function IsEqual__(const Val1, Val2, Epsilon_: Double): Boolean;
var
  Diff: Single;
begin
  Diff := Val1 - Val2;
  Result := ((-Epsilon_ <= Diff) and (Diff <= Epsilon_));
end;

procedure TPascalString_Hash_Pool.CreateAfter;
begin
  FMaxNameSize := 0;
  FMinNameSize := 0;
end;

function TPascalString_Hash_Pool.Get_Key_Hash(const Key_: TPascalString): THash;
begin
  if Key_.L > FMaxNameSize then
      FMaxNameSize := Key_.L;
  if Key_.L < FMinNameSize then
      FMinNameSize := Key_.L;
  Result := FastHashPPascalString(@Key_);
  Result := Get_CRC32(@Result, SizeOf(THash));
end;

function TPascalString_Hash_Pool.Compare_Key(const Key_1, Key_2: TPascalString): Boolean;
begin
  Result := Key_1.Same(@Key_2);
end;

procedure TPascalString_Hash_Pool.DoFree(var Key: TPascalString; var Value: TPascalString);
begin
  Key := '';
  Value := '';
end;

function TPascalString_Hash_Pool.Compare_Value(const Value_1, Value_2: TPascalString): Boolean;
begin
  Result := Value_1.Same(@Value_2);
end;

procedure TString_Big_Hash_Pair_Pool<T_>.CreateAfter;
begin
  FMaxNameSize := 0;
  FMinNameSize := 0;
end;

function TString_Big_Hash_Pair_Pool<T_>.Get_Key_Hash(const Key_: SystemString): THash;
var
  L_: Integer;
begin
  L_ := Length(Key_);
  if L_ > FMaxNameSize then
      FMaxNameSize := L_;
  if L_ < FMinNameSize then
      FMinNameSize := L_;
  Result := FastHashSystemString(Key_);
  Result := Get_CRC32(@Result, SizeOf(THash));
end;

function TString_Big_Hash_Pair_Pool<T_>.Compare_Key(const Key_1, Key_2: SystemString): Boolean;
begin
  Result := SameText(Key_1, Key_2);
end;

procedure TString_Big_Hash_Pair_Pool<T_>.DoFree(var Key: SystemString; var Value: T_);
begin
  Key := '';
  inherited DoFree(Key, Value);
end;

procedure TPascalString_Big_Hash_Pair_Pool<T_>.CreateAfter;
begin
  FMaxNameSize := 0;
  FMinNameSize := 0;
end;

function TPascalString_Big_Hash_Pair_Pool<T_>.Get_Key_Hash(const Key_: TPascalString): THash;
begin
  if Key_.L > FMaxNameSize then
      FMaxNameSize := Key_.L;
  if Key_.L < FMinNameSize then
      FMinNameSize := Key_.L;
  Result := FastHashPPascalString(@Key_);
  Result := Get_CRC32(@Result, SizeOf(THash));
end;

function TPascalString_Big_Hash_Pair_Pool<T_>.Compare_Key(const Key_1, Key_2: TPascalString): Boolean;
begin
  Result := Key_1.Same(@Key_2);
end;

procedure TPascalString_Big_Hash_Pair_Pool<T_>.DoFree(var Key: TPascalString; var Value: T_);
begin
  Key := '';
  inherited DoFree(Key, Value);
end;

constructor TSingle_Big_Hash_Pair_Pool<T_>.Create(const HashSize_: Integer; const NULL_VALUE_: T_; const Epsilon_: Single);
begin
  inherited Create(HashSize_, NULL_VALUE_);
  Epsilon := Epsilon_;
end;

function TSingle_Big_Hash_Pair_Pool<T_>.Get_Key_Hash(const Key_: Single): THash;
var
  tmp: Int64;
begin
  tmp := Round(Key_ * (1.0 / Epsilon));
  Result := Get_CRC32(@tmp, 8);
end;

function TSingle_Big_Hash_Pair_Pool<T_>.Compare_Key(const Key_1, Key_2: Single): Boolean;
begin
  Result := IsEqual__(Key_1, Key_2, Epsilon);
end;

constructor TDouble_Big_Hash_Pair_Pool<T_>.Create(const HashSize_: Integer; const NULL_VALUE_: T_; const Epsilon_: Double);
begin
  inherited Create(HashSize_, NULL_VALUE_);
  Epsilon := Epsilon_;
end;

function TDouble_Big_Hash_Pair_Pool<T_>.Get_Key_Hash(const Key_: Double): THash;
var
  tmp: Int64;
begin
  tmp := Round(Key_ * (1.0 / Epsilon));
  Result := Get_CRC32(@tmp, 8);
end;

function TDouble_Big_Hash_Pair_Pool<T_>.Compare_Key(const Key_1, Key_2: Double): Boolean;
begin
  Result := IsEqual__(Key_1, Key_2, Epsilon);
end;

function TCritical_PascalString_Hash_Pool.Get_Key_Hash(const Key_: TPascalString): THash;
begin
  Result := FastHashPPascalString(@Key_);
  Result := Get_CRC32(@Result, SizeOf(THash));
end;

function TCritical_PascalString_Hash_Pool.Compare_Key(const Key_1, Key_2: TPascalString): Boolean;
begin
  Result := Key_1.Same(@Key_2);
end;

procedure TCritical_PascalString_Hash_Pool.DoFree(var Key: TPascalString; var Value: TPascalString);
begin
  Key := '';
  Value := '';
end;

function TCritical_PascalString_Hash_Pool.Compare_Value(const Value_1, Value_2: TPascalString): Boolean;
begin
  Result := Value_1.Same(@Value_2);
end;

function TCritical_String_Big_Hash_Pair_Pool<T_>.Get_Key_Hash(const Key_: SystemString): THash;
begin
  Result := FastHashSystemString(Key_);
  Result := Get_CRC32(@Result, SizeOf(THash));
end;

function TCritical_String_Big_Hash_Pair_Pool<T_>.Compare_Key(const Key_1, Key_2: SystemString): Boolean;
begin
  Result := SameText(Key_1, Key_2);
end;

procedure TCritical_String_Big_Hash_Pair_Pool<T_>.DoFree(var Key: SystemString; var Value: T_);
begin
  Key := '';
  inherited DoFree(Key, Value);
end;

function TCritical_PascalString_Big_Hash_Pair_Pool<T_>.Get_Key_Hash(const Key_: TPascalString): THash;
begin
  Result := FastHashPPascalString(@Key_);
  Result := Get_CRC32(@Result, SizeOf(THash));
end;

function TCritical_PascalString_Big_Hash_Pair_Pool<T_>.Compare_Key(const Key_1, Key_2: TPascalString): Boolean;
begin
  Result := Key_1.Same(@Key_2);
end;

procedure TCritical_PascalString_Big_Hash_Pair_Pool<T_>.DoFree(var Key: TPascalString; var Value: T_);
begin
  Key := '';
  inherited DoFree(Key, Value);
end;

constructor TCritical_Single_Big_Hash_Pair_Pool<T_>.Create(const HashSize_: Integer; const NULL_VALUE_: T_; const Epsilon_: Single);
begin
  inherited Create(HashSize_, NULL_VALUE_);
  Epsilon := Epsilon_;
end;

function TCritical_Single_Big_Hash_Pair_Pool<T_>.Get_Key_Hash(const Key_: Single): THash;
var
  tmp: Int64;
begin
  tmp := Round(Key_ * (1.0 / Epsilon));
  Result := Get_CRC32(@tmp, 8);
end;

function TCritical_Single_Big_Hash_Pair_Pool<T_>.Compare_Key(const Key_1, Key_2: Single): Boolean;
begin
  Result := IsEqual__(Key_1, Key_2, Epsilon);
end;

constructor TCritical_Double_Big_Hash_Pair_Pool<T_>.Create(const HashSize_: Integer; const NULL_VALUE_: T_; const Epsilon_: Double);
begin
  inherited Create(HashSize_, NULL_VALUE_);
  Epsilon := Epsilon_;
end;

function TCritical_Double_Big_Hash_Pair_Pool<T_>.Get_Key_Hash(const Key_: Double): THash;
var
  tmp: Int64;
begin
  tmp := Round(Key_ * (1.0 / Epsilon));
  Result := Get_CRC32(@tmp, 8);
end;

function TCritical_Double_Big_Hash_Pair_Pool<T_>.Compare_Key(const Key_1, Key_2: Double): Boolean;
begin
  Result := IsEqual__(Key_1, Key_2, Epsilon);
end;

procedure TString_Num_Analysis_Tool.IncValue(Key_: SystemString; Value_: Integer);
var
  p: TString_Num_Analysis_Tool_.PValue;
begin
  if Value_ = 0 then
      exit;
  p := Get_Value_Ptr(Key_);
  p^ := p^ + Value_;
end;

procedure TString_Num_Analysis_Tool.IncValue(source: TString_Num_Analysis_Tool);
var
  __repeat__: TString_Num_Analysis_Tool_.TRepeat___;
begin
  if source.num <= 0 then
      exit;
  __repeat__ := source.Repeat_;
  repeat
      IncValue(__repeat__.queue^.Data^.Data.Primary, __repeat__.queue^.Data^.Data.Second);
  until not __repeat__.Next;
end;

function TString_Num_Analysis_Tool.Get_Max_Key_And_Value(var k: SystemString; var v: Integer): Boolean;
var
  tmp: Integer;
begin
  Result := False;
  if num > 0 then
    begin
      k := Queue_Pool.First^.Data^.Data.Primary;
      tmp := Queue_Pool.First^.Data^.Data.Second;
      v := tmp;
      with Queue_Pool.Repeat_ do
        repeat
          if queue^.Data^.Data.Second > tmp then
            begin
              k := queue^.Data^.Data.Primary;
              tmp := queue^.Data^.Data.Second;
              v := tmp;
            end;
        until not Next;
      Result := True;
    end;
end;

function TString_Num_Analysis_Tool.Get_Max_Key: SystemString;
var
  tmp: Integer;
begin
  if num > 0 then
    begin
      Result := Queue_Pool.First^.Data^.Data.Primary;
      tmp := Queue_Pool.First^.Data^.Data.Second;
      with Queue_Pool.Repeat_ do
        repeat
          if queue^.Data^.Data.Second > tmp then
            begin
              Result := queue^.Data^.Data.Primary;
              tmp := queue^.Data^.Data.Second;
            end;
        until not Next;
    end;
end;

function TString_Num_Analysis_Tool.Get_Min_Key: SystemString;
var
  tmp: Integer;
begin
  Result := '';
  if num > 0 then
    begin
      Result := Queue_Pool.First^.Data^.Data.Primary;
      tmp := Queue_Pool.First^.Data^.Data.Second;
      with Queue_Pool.Repeat_ do
        repeat
          if queue^.Data^.Data.Second < tmp then
            begin
              Result := queue^.Data^.Data.Primary;
              tmp := queue^.Data^.Data.Second;
            end;
        until not Next;
    end;
end;

function TString_Num_Analysis_Tool.Do_Sort_By_Num(var L, R: Integer): Integer;
begin
  Result := CompareInteger(L, R);
end;

procedure TString_Num_Analysis_Tool.Sort_By_Num;
begin
  Sort_Value_M(Do_Sort_By_Num);
end;

procedure TString_Num64_Analysis_Tool.IncValue(Key_: SystemString; Value_: Int64);
var
  p: TString_Num64_Analysis_Tool_.PValue;
begin
  if Value_ = 0 then
      exit;
  p := Get_Value_Ptr(Key_);
  p^ := p^ + Value_;
end;

procedure TString_Num64_Analysis_Tool.IncValue(source: TString_Num64_Analysis_Tool);
var
  __repeat__: TString_Num64_Analysis_Tool_.TRepeat___;
begin
  if source.num <= 0 then
      exit;
  __repeat__ := source.Repeat_;
  repeat
      IncValue(__repeat__.queue^.Data^.Data.Primary, __repeat__.queue^.Data^.Data.Second);
  until not __repeat__.Next;
end;

function TString_Num64_Analysis_Tool.Get_Max_Key_And_Value(var k: SystemString; var v: Int64): Boolean;
var
  tmp: Int64;
begin
  Result := False;
  if num > 0 then
    begin
      k := Queue_Pool.First^.Data^.Data.Primary;
      tmp := Queue_Pool.First^.Data^.Data.Second;
      v := tmp;
      with Queue_Pool.Repeat_ do
        repeat
          if queue^.Data^.Data.Second > tmp then
            begin
              k := queue^.Data^.Data.Primary;
              tmp := queue^.Data^.Data.Second;
              v := tmp;
            end;
        until not Next;
      Result := True;
    end;
end;

function TString_Num64_Analysis_Tool.Get_Max_Key: SystemString;
var
  tmp: Int64;
begin
  if num > 0 then
    begin
      Result := Queue_Pool.First^.Data^.Data.Primary;
      tmp := Queue_Pool.First^.Data^.Data.Second;
      with Queue_Pool.Repeat_ do
        repeat
          if queue^.Data^.Data.Second > tmp then
            begin
              Result := queue^.Data^.Data.Primary;
              tmp := queue^.Data^.Data.Second;
            end;
        until not Next;
    end;
end;

function TString_Num64_Analysis_Tool.Get_Min_Key: SystemString;
var
  tmp: Int64;
begin
  Result := '';
  if num > 0 then
    begin
      Result := Queue_Pool.First^.Data^.Data.Primary;
      tmp := Queue_Pool.First^.Data^.Data.Second;
      with Queue_Pool.Repeat_ do
        repeat
          if queue^.Data^.Data.Second < tmp then
            begin
              Result := queue^.Data^.Data.Primary;
              tmp := queue^.Data^.Data.Second;
            end;
        until not Next;
    end;
end;

function TString_Num64_Analysis_Tool.Do_Sort_By_Num(var L, R: Int64): Integer;
begin
  Result := CompareInt64(L, R);
end;

procedure TString_Num64_Analysis_Tool.Sort_By_Num;
begin
  Sort_Value_M(Do_Sort_By_Num);
end;

function TGeneric_String_Object_Hash<T_>.GetCount: NativeInt;
begin
  Result := FHashList.Count;
end;

function TGeneric_String_Object_Hash<T_>.GetIgnoreCase: Boolean;
begin
  Result := FHashList.IgnoreCase;
end;

procedure TGeneric_String_Object_Hash<T_>.SetIgnoreCase(const Value: Boolean);
begin
  FHashList.IgnoreCase := Value;
end;

function TGeneric_String_Object_Hash<T_>.GetKeyValue(const Name: SystemString): T_;
var
  pObjData: PGebnericHashListData;
begin
  pObjData := FHashList.NameValue[Name];
  if pObjData <> nil then
      Result := pObjData^.Obj as T_
  else
      Result := Default_NULL_VALUE;
end;

procedure TGeneric_String_Object_Hash<T_>.SetKeyValue(const Name: SystemString; const Value: T_);
begin
  Add(Name, Value);
end;

function TGeneric_String_Object_Hash<T_>.GetOnChange(const Name: SystemString): TGebnericHashChangeEvent;
var
  pObjData: PGebnericHashListData;
begin
  pObjData := FHashList.NameValue[Name];
  if pObjData <> nil then
      Result := pObjData^.OnChnage
  else
      Result := nil;
end;

procedure TGeneric_String_Object_Hash<T_>.SetOnChange(const Name: SystemString; const AValue: TGebnericHashChangeEvent);
var
  pObjData: PGebnericHashListData;
begin
  pObjData := FHashList.NameValue[Name];
  if pObjData = nil then
    begin
      new(pObjData);
      pObjData^.OnChnage := AValue;
      pObjData^.Obj := Default_NULL_VALUE;
      FHashList.Add(Name, pObjData, False);
    end
  else
      pObjData^.OnChnage := AValue;
end;

function TGeneric_String_Object_Hash<T_>.GetAccessOptimization: Boolean;
begin
  Result := FHashList.AccessOptimization;
end;

procedure TGeneric_String_Object_Hash<T_>.SetAccessOptimization(const Value: Boolean);
begin
  FHashList.AccessOptimization := Value;
end;

procedure TGeneric_String_Object_Hash<T_>.Do_HashList_DataFree(p: Pointer);
begin
  Dispose(PGebnericHashListData(p));
end;

procedure TGeneric_String_Object_Hash<T_>.Do_Free_Obj(var Obj_: T_);
begin
  if Assigned(OnFree) then
      OnFree(Obj_);
  DisposeObject(Obj_);
end;

procedure TGeneric_String_Object_Hash<T_>.DoInited;
begin
end;

constructor TGeneric_String_Object_Hash<T_>.Create(AutoFreeData_: Boolean; HashPoolSize_: Integer; Default_NULL_VALUE_: T_);
begin
  inherited Create;
  FHashList := THashList.CustomCreate(HashPoolSize_);
  FHashList.AutoFreeData := True;
  FHashList.OnFreePtr := Do_HashList_DataFree;
  FAutoFreeObject := AutoFreeData_;
  FIncremental := 0;
  Default_NULL_VALUE := Default_NULL_VALUE_;
  OnFree := nil;
  DoInited();
end;

destructor TGeneric_String_Object_Hash<T_>.Destroy;
begin
  Clear;
  DisposeObject(FHashList);
  inherited Destroy;
end;

procedure TGeneric_String_Object_Hash<T_>.Assign(sour: TRefClass_);
var
  i: Integer;
  p: PHashListData;
begin
  Clear;
  if sour.HashList.Count > 0 then
    begin
      i := 0;
      p := sour.HashList.FirstPtr;
      while i < sour.HashList.Count do
        begin
          FastAdd(p^.OriginName, PGebnericHashListData(p^.Data)^.Obj);
          inc(i);
          p := p^.Next;
        end;
    end;
end;

procedure TGeneric_String_Object_Hash<T_>.ProgressC(const OnProgress: TGebnericHashListLoop_C);
var
  i: Integer;
  p: PHashListData;
begin
  if HashList.Count > 0 then
    begin
      i := 0;
      p := HashList.FirstPtr;
      while i < HashList.Count do
        begin
          try
              OnProgress(@p^.OriginName, PGebnericHashListData(p^.Data)^.Obj);
          except
          end;
          inc(i);
          p := p^.Next;
        end;
    end;
end;

procedure TGeneric_String_Object_Hash<T_>.ProgressM(const OnProgress: TGebnericHashListLoop_M);
var
  i: Integer;
  p: PHashListData;
begin
  if HashList.Count > 0 then
    begin
      i := 0;
      p := HashList.FirstPtr;
      while i < HashList.Count do
        begin
          try
              OnProgress(@p^.OriginName, PGebnericHashListData(p^.Data)^.Obj);
          except
          end;
          inc(i);
          p := p^.Next;
        end;
    end;
end;

procedure TGeneric_String_Object_Hash<T_>.ProgressP(const OnProgress: TGebnericHashListLoop_P);
var
  i: Integer;
  p: PHashListData;
begin
  if HashList.Count > 0 then
    begin
      i := 0;
      p := HashList.FirstPtr;
      while i < HashList.Count do
        begin
          try
              OnProgress(@p^.OriginName, PGebnericHashListData(p^.Data)^.Obj);
          except
          end;
          inc(i);
          p := p^.Next;
        end;
    end;
end;

procedure TGeneric_String_Object_Hash<T_>.Clear;
var
  lst: TCore_List;
  pObjData: PGebnericHashListData;
  i: Integer;
begin
  if FAutoFreeObject then
    begin
      lst := TCore_List.Create;
      FHashList.GetListData(lst);
      if lst.Count > 0 then
        for i := 0 to lst.Count - 1 do
          with PHashListData(lst[i])^ do
            begin
              pObjData := Data;
              if pObjData <> nil then
                if pObjData^.Obj <> Default_NULL_VALUE then
                  begin
                    try
                        Do_Free_Obj(pObjData^.Obj);
                    except
                    end;
                  end;
            end;
      DisposeObject(lst);
    end;
  FHashList.Clear;
  FIncremental := 0;
end;

procedure TGeneric_String_Object_Hash<T_>.GetNameList(OutputList: TCore_Strings);
var
  i: Integer;
  p: PHashListData;
begin
  OutputList.Clear;
  if HashList.Count > 0 then
    begin
      i := 0;
      p := HashList.FirstPtr;
      while i < HashList.Count do
        begin
          OutputList.AddObject(p^.OriginName, PGebnericHashListData(p^.Data)^.Obj);
          inc(i);
          p := p^.Next;
        end;
    end;
end;

procedure TGeneric_String_Object_Hash<T_>.GetNameList(OutputList: TListString);
var
  i: Integer;
  p: PHashListData;
begin
  OutputList.Clear;
  if HashList.Count > 0 then
    begin
      i := 0;
      p := HashList.FirstPtr;
      while i < HashList.Count do
        begin
          OutputList.Add(p^.OriginName, PGebnericHashListData(p^.Data)^.Obj);
          inc(i);
          p := p^.Next;
        end;
    end;
end;

procedure TGeneric_String_Object_Hash<T_>.GetNameList(OutputList: TListPascalString);
var
  i: Integer;
  p: PHashListData;
begin
  OutputList.Clear;
  if HashList.Count > 0 then
    begin
      i := 0;
      p := HashList.FirstPtr;
      while i < HashList.Count do
        begin
          OutputList.Add(p^.OriginName, PGebnericHashListData(p^.Data)^.Obj);
          inc(i);
          p := p^.Next;
        end;
    end;
end;

procedure TGeneric_String_Object_Hash<T_>.GetListData(OutputList: TCore_Strings);
var
  i: Integer;
  p: PHashListData;
begin
  OutputList.Clear;
  if HashList.Count > 0 then
    begin
      i := 0;
      p := HashList.FirstPtr;
      while i < HashList.Count do
        begin
          OutputList.AddObject(p^.OriginName, PGebnericHashListData(p^.Data)^.Obj);
          inc(i);
          p := p^.Next;
        end;
    end;
end;

procedure TGeneric_String_Object_Hash<T_>.GetListData(OutputList: TListString);
var
  i: Integer;
  p: PHashListData;
begin
  OutputList.Clear;
  if HashList.Count > 0 then
    begin
      i := 0;
      p := HashList.FirstPtr;
      while i < HashList.Count do
        begin
          OutputList.Add(p^.OriginName, PGebnericHashListData(p^.Data)^.Obj);
          inc(i);
          p := p^.Next;
        end;
    end;
end;

procedure TGeneric_String_Object_Hash<T_>.GetListData(OutputList: TListPascalString);
var
  i: Integer;
  p: PHashListData;
begin
  OutputList.Clear;
  if HashList.Count > 0 then
    begin
      i := 0;
      p := HashList.FirstPtr;
      while i < HashList.Count do
        begin
          OutputList.Add(p^.OriginName, PGebnericHashListData(p^.Data)^.Obj);
          inc(i);
          p := p^.Next;
        end;
    end;
end;

procedure TGeneric_String_Object_Hash<T_>.GetAsList(OutputList: TCore_ListForObj);
var
  i: Integer;
  p: PHashListData;
begin
  OutputList.Clear;
  if HashList.Count > 0 then
    begin
      OutputList.Count := HashList.Count;
      i := 0;
      p := HashList.FirstPtr;
      while i < HashList.Count do
        begin
          OutputList[i] := PGebnericHashListData(p^.Data)^.Obj;
          inc(i);
          p := p^.Next;
        end;
    end;
end;

function TGeneric_String_Object_Hash<T_>.GetObjAsName(Obj: T_): SystemString;
var
  i: Integer;
  p: PHashListData;
begin
  Result := '';
  if HashList.Count > 0 then
    begin
      i := 0;
      p := HashList.FirstPtr;
      while i < HashList.Count do
        begin
          if PGebnericHashListData(p^.Data)^.Obj = Obj then
            begin
              Result := p^.OriginName;
              exit;
            end;
          inc(i);
          p := p^.Next;
        end;
    end;
end;

procedure TGeneric_String_Object_Hash<T_>.Delete(const Name: SystemString);
var
  pObjData: PGebnericHashListData;
begin
  if FAutoFreeObject then
    begin
      pObjData := FHashList.NameValue[Name];
      if pObjData <> nil then
        begin
          if pObjData^.Obj <> Default_NULL_VALUE then
            begin
              try
                Do_Free_Obj(pObjData^.Obj);
                pObjData^.Obj := Default_NULL_VALUE;
              except
              end;
            end;
        end;
    end;
  FHashList.Delete(Name);
end;

function TGeneric_String_Object_Hash<T_>.Add(const Name: SystemString; Obj_: T_): T_;
var
  pObjData: PGebnericHashListData;
begin
  pObjData := FHashList.NameValue[Name];
  if pObjData <> nil then
    begin
      try
        if Assigned(pObjData^.OnChnage) then
            pObjData^.OnChnage(Self, Name, pObjData^.Obj, Obj_);
      except
      end;

      if (FAutoFreeObject) and (pObjData^.Obj <> Default_NULL_VALUE) then
        begin
          try
            Do_Free_Obj(pObjData^.Obj);
            pObjData^.Obj := Default_NULL_VALUE;
          except
          end;
        end;
    end
  else
    begin
      new(pObjData);
      pObjData^.OnChnage := nil;
      FHashList.Add(Name, pObjData, False);
    end;

  pObjData^.Obj := Obj_;
  Result := Obj_;
end;

function TGeneric_String_Object_Hash<T_>.FastAdd(const Name: SystemString; Obj_: T_): T_;
var
  pObjData: PGebnericHashListData;
begin
  new(pObjData);
  pObjData^.OnChnage := nil;
  FHashList.Add(Name, pObjData, False);

  pObjData^.Obj := Obj_;
  Result := Obj_;
end;

function TGeneric_String_Object_Hash<T_>.Find(const Name: SystemString): T_;
var
  pObjData: PGebnericHashListData;
begin
  pObjData := FHashList.Find(Name);
  if pObjData <> nil then
      Result := pObjData^.Obj
  else
      Result := Default_NULL_VALUE;
end;

function TGeneric_String_Object_Hash<T_>.Exists(const Name: SystemString): Boolean;
begin
  Result := FHashList.Exists(Name);
end;

function TGeneric_String_Object_Hash<T_>.ExistsObject(Obj: T_): Boolean;
var
  lst: TCore_List;
  i: Integer;
begin
  Result := False;
  lst := TCore_List.Create;
  FHashList.GetListData(lst);
  if lst.Count > 0 then
    for i := 0 to lst.Count - 1 do
      begin
        with PHashListData(lst[i])^ do
          begin
            if PGebnericHashListData(Data)^.Obj = Obj then
              begin
                Result := True;
                Break;
              end;
          end;
      end;
  DisposeObject(lst);
end;

procedure TGeneric_String_Object_Hash<T_>.CopyFrom(const source: TRefClass_);
var
  lst: TCore_List;
  pObjData: PGebnericHashListData;
  i: Integer;
begin
  lst := TCore_List.Create;
  source.HashList.GetListData(lst);
  if lst.Count > 0 then
    for i := 0 to lst.Count - 1 do
      begin
        with PHashListData(lst[i])^ do
          if Data <> nil then
            begin
              pObjData := Data;
              NameValue[OriginName] := pObjData^.Obj;
            end;
      end;
  DisposeObject(lst);
end;

function TGeneric_String_Object_Hash<T_>.ReName(OLD_, New_: SystemString): Boolean;
var
  pObjData: PGebnericHashListData;
begin
  pObjData := FHashList.NameValue[OLD_];
  Result := (OLD_ <> New_) and (pObjData <> nil) and (FHashList.NameValue[New_] = nil);
  if Result then
    begin
      Add(New_, pObjData^.Obj);
      FHashList.Delete(OLD_);
    end;
end;

function TGeneric_String_Object_Hash<T_>.MakeName: SystemString;
begin
  repeat
    inc(FIncremental);
    Result := umlIntToStr(FIncremental);
  until not Exists(Result);
end;

function TGeneric_String_Object_Hash<T_>.MakeRefName(RefrenceName: SystemString): SystemString;
begin
  Result := RefrenceName;
  if not Exists(Result) then
      exit;

  repeat
    inc(FIncremental);
    Result := RefrenceName + umlIntToStr(FIncremental);
  until not Exists(Result);
end;

procedure Test_Generic_String_Object_Hash;
type
  TSL = TGeneric_String_Object_Hash<TCore_StringList>;
var
  L: TSL;
begin
  L := TSL.Create(True, 100, nil);
  L.Add('abc', TCore_StringList.Create).Text := '1'#10'2'#10'3';
  L.Add('abc1', TCore_StringList.Create).Text := '11'#10'222'#10'33';
  L.Add('abc2', TCore_StringList.Create).Text := '111'#10'222'#10'333';
  L.Add('abc3', TCore_StringList.Create).Text := '1111'#10'2222'#10'3333';
  DoStatus(L['abc'][0]);
  DoStatus(L['abc'][1]);
  DoStatus(L['abc'][2]);
  DoStatus(L['abc1'][0]);
  DoStatus(L['abc2'][0]);
  DoStatus(L['abc3'][0]);

  if not L.Exists('Abc') then
    begin
      raiseInfo('error');
    end;
  DisposeObject(L);
end;

procedure Test_Single_Big_Hash_Pair_Pool();
type
  T_Test = TSingle_Big_Hash_Pair_Pool<Integer>;
var
  tmp: T_Test;
  i: Integer;
begin
  tmp := T_Test.Create(1000, 0, 0.01);
  for i := 1 to 10000 do
      tmp[i * 0.01] := i;
  for i := 1 to 10000 do
    if tmp[i * 0.01] <> i then
        raiseInfo('error');
  tmp.Free;
end;

end.

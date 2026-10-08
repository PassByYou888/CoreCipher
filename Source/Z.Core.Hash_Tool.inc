function TBig_Hash_Pair_Pool<TKey_, TValue_>.Get_Critical__: TCritical;
begin
  if FCritical__ = nil then
      FCritical__ := TCritical.Create('TBig_Hash_Pair_Pool.FCritical__');
  Result := FCritical__;
end;

function TBig_Hash_Pair_Pool<TKey_, TValue_>.Get_Value_List(const Key_: TKey_; var Key_Hash_: THash): TValue_Pair_Pool__;
var
  i: integer;
begin
  Key_Hash_ := Get_Key_Hash(Key_);
  i := Hash_Key_Mod(Key_Hash_, FHash_Buffer.Count);
  if FHash_Buffer[i] = nil then
    begin
      FHash_Buffer[i] := TValue_Pair_Pool__.Create;
      FHash_Buffer[i].L.FOnFree := Internal_Do_Free;
    end;
  Result := FHash_Buffer[i];
end;

procedure TBig_Hash_Pair_Pool<TKey_, TValue_>.Free_Value_List(Key_Hash_: THash);
begin
  DisposeObject(FHash_Buffer[Hash_Key_Mod(Key_Hash_, FHash_Buffer.Count)]);
  FHash_Buffer[Hash_Key_Mod(Key_Hash_, FHash_Buffer.Count)] := nil;
end;

procedure TBig_Hash_Pair_Pool<TKey_, TValue_>.Get_Key_Data_Ptr(const Key_P: PKey_; var p: PByte; var Size: NativeInt);
begin
  p := PByte(Key_P);
  Size := SizeOf(TKey_);
end;

procedure TBig_Hash_Pair_Pool<TKey_, TValue_>.Internal_Do_Queue_Pool_Free(var Data: PPair_Pool_Value__);
begin
  if Data <> nil then
    begin
      Data^.Data.Third := nil;
      Data^.Instance___.Remove_P(Data);
    end;
end;

procedure TBig_Hash_Pair_Pool<TKey_, TValue_>.Internal_Do_Free(var Data: TPair);
begin
  if Data.Third <> nil then
    begin
      TPool_Queue_Ptr___(Data.Third)^.Data := nil;
      FQueue_Pool.Remove_P(TPool_Queue_Ptr___(Data.Third));
    end;
  DoFree(Data.Primary, Data.Second);
end;

class function TBig_Hash_Pair_Pool<TKey_, TValue_>.Null_Key: TKey_;
begin
  FillPtr(@Result, SizeOf(TKey_), 0);
end;

class function TBig_Hash_Pair_Pool<TKey_, TValue_>.NULL_VALUE: TValue_;
begin
  FillPtr(@Result, SizeOf(TValue_), 0);
end;

constructor TBig_Hash_Pair_Pool<TKey_, TValue_>.Create(const HashSize_: integer; const NULL_VALUE_: TValue_);
var
  i: integer;
begin
  inherited Create;
  CreateBefore();
  FCritical__ := nil;
  FQueue_Pool := TPool___.Create;
  FQueue_Pool.FOnFree := Internal_Do_Queue_Pool_Free;
  FHash_Buffer := TKey_Hash_Buffer.Create;
  FHash_Buffer.Count := HashSize_;
  for i := 0 to FHash_Buffer.Count - 1 do
      FHash_Buffer[i] := nil;
  FNULL_VALUE := NULL_VALUE_;
  FOnAdd := nil;
  FOnFree := nil;
  FOn_Get_Key := nil;
  FOn_Compare_Key := nil;
  FOn_Compare_Value := nil;
  CreateAfter();
end;

constructor TBig_Hash_Pair_Pool<TKey_, TValue_>.Create(const HashSize_: integer);
begin
  Create(HashSize_, T___.NULL_VALUE);
end;

destructor TBig_Hash_Pair_Pool<TKey_, TValue_>.Destroy;
begin
  Clear;
  FQueue_Pool.Free;
  DisposeObjectAndNil(FHash_Buffer);
  DisposeObjectAndNil(FCritical__);
  inherited Destroy;
end;

procedure TBig_Hash_Pair_Pool<TKey_, TValue_>.CreateBefore;
begin
end;

procedure TBig_Hash_Pair_Pool<TKey_, TValue_>.CreateAfter;
begin
end;

procedure TBig_Hash_Pair_Pool<TKey_, TValue_>.DoFree(var Key: TKey_; var Value: TValue_);
begin
  if Assigned(FOnFree) then
      FOnFree(Key, Value);
end;

procedure TBig_Hash_Pair_Pool<TKey_, TValue_>.DoAdd(var Key: TKey_; var Value: TValue_);
begin
  if Assigned(FOnAdd) then
      FOnAdd(Key, Value);
end;

function TBig_Hash_Pair_Pool<TKey_, TValue_>.Get_Key_Hash(const Key_: TKey_): THash;
var
  p: PByte;
  Size: NativeInt;
begin
  if Assigned(FOn_Get_Key) then
      FOn_Get_Key(@Key_, Result)
  else
    begin
      Get_Key_Data_Ptr(@Key_, p, Size);
      Result := Get_CRC32(p, Size);
    end;
end;

function TBig_Hash_Pair_Pool<TKey_, TValue_>.Compare_Key(const Key_1, Key_2: TKey_): Boolean;
var
  p1, p2: PByte;
  s1, s2: NativeInt;
begin
  if Assigned(FOn_Compare_Key) then
    begin
      Result := False;
      FOn_Compare_Key(@Key_1, @Key_2, Result);
    end
  else
    begin
      Get_Key_Data_Ptr(@Key_1, p1, s1);
      Get_Key_Data_Ptr(@Key_2, p2, s2);
      Result := CompareMemory(p1, p2, Min(s1, s2));
    end;
end;

function TBig_Hash_Pair_Pool<TKey_, TValue_>.Compare_Value(const Value_1, Value_2: TValue_): Boolean;
begin
  if Assigned(FOn_Compare_Value) then
    begin
      Result := False;
      FOn_Compare_Value(@Value_1, @Value_2, Result);
    end
  else
      Result := CompareMemory(@Value_1, @Value_2, SizeOf(TValue_));
end;

procedure TBig_Hash_Pair_Pool<TKey_, TValue_>.Lock;
begin
  Critical__.Lock;
end;

procedure TBig_Hash_Pair_Pool<TKey_, TValue_>.UnLock;
begin
  Critical__.UnLock;
end;

procedure TBig_Hash_Pair_Pool<TKey_, TValue_>.Extract_Queue_Pool_Third;
begin
  if FQueue_Pool.Num > 0 then
    with FQueue_Pool.Repeat_ do
      repeat
          Queue^.Data^.Data.Third := Queue;
      until not Next;
end;

function TBig_Hash_Pair_Pool<TKey_, TValue_>.GetHashSize: integer;
begin
  Result := FHash_Buffer.Count;
end;

procedure TBig_Hash_Pair_Pool<TKey_, TValue_>.Clear;
var
  i: integer;
begin
  for i := 0 to FHash_Buffer.Count - 1 do
    begin
      DisposeObject(FHash_Buffer[i]);
      FHash_Buffer[i] := nil;
    end;
end;

function TBig_Hash_Pair_Pool<TKey_, TValue_>.Exists_Key(const Key: TKey_): Boolean;
var
  Key_Hash_: THash;
  L: TValue_Pair_Pool__;
  i: NativeInt;
  p: PPair_Pool_Value__;
begin
  Result := False;
  L := Get_Value_List(Key, Key_Hash_);
  if L.L.Num > 0 then
    begin
      i := 0;
      p := L.L.First;
      while i < L.L.Num do
        begin
          if (Key_Hash_ = p^.Data.Fourth) and Compare_Key(Key, p^.Data.Primary) then
            begin
              L.L.MoveToFirst(p);
              Result := True;
              Exit;
            end;
          Inc(i);
          p := p^.Next;
        end;
    end;
end;

function TBig_Hash_Pair_Pool<TKey_, TValue_>.Exists_Value(const Data: TValue_): Boolean;
var
  L: TValue_Pair_Pool__;
  i, j: NativeInt;
  p: PPair_Pool_Value__;
begin
  Result := False;
  for i := 0 to FHash_Buffer.Count - 1 do
    begin
      L := FHash_Buffer[i];
      if (L <> nil) and (L.L.Num > 0) then
        begin
          j := 0;
          p := L.L.First;
          while j < L.L.Num do
            begin
              if Compare_Value(Data, p^.Data.Second) then
                begin
                  Result := True;
                  Exit;
                end;
              Inc(j);
              p := p^.Next;
            end;
        end;
    end;
end;

function TBig_Hash_Pair_Pool<TKey_, TValue_>.Exists(const Key: TKey_): Boolean;
begin
  Result := Exists_Key(Key);
end;

function TBig_Hash_Pair_Pool<TKey_, TValue_>.Add(const Key: TKey_; const Value: TValue_; Overwrite_: Boolean): PPair_Pool_Value__;
var
  Key_Hash_: THash;
  L: TValue_Pair_Pool__;
  i: integer;
  p: PPair_Pool_Value__;
begin
  L := Get_Value_List(Key, Key_Hash_);

  if Overwrite_ and (L.L.Num > 0) then
    begin
      i := 0;
      p := L.L.First;
      while i < L.L.Num do
        begin
          if (Key_Hash_ = p^.Data.Fourth) and Compare_Key(Key, p^.Data.Primary) then
              L.L.Push_To_Recycle_Pool(p);
          Inc(i);
          p := p^.Next;
        end;
      L.L.Free_Recycle_Pool;
    end;

  L := Get_Value_List(Key, Key_Hash_);
  p := L.L.Add_Null();
  p^.Data.Primary := Key;
  p^.Data.Second := Value;
  p^.Data.Third := FQueue_Pool.Add(p);
  p^.Data.Fourth := Key_Hash_;
  L.L.MoveToFirst(p);
  Result := p;
  DoAdd(p^.Data.Primary, p^.Data.Second);
end;

function TBig_Hash_Pair_Pool<TKey_, TValue_>.Get_Key_Value(const Key: TKey_): TValue_;
var
  Key_Hash_: THash;
  L: TValue_Pair_Pool__;
  R: TValue_;
  i: NativeInt;
  p: PPair_Pool_Value__;
begin
  R := FNULL_VALUE;
  L := Get_Value_List(Key, Key_Hash_);
  if L.L.Num > 0 then
    begin
      i := 0;
      p := L.L.First;
      while i < L.L.Num do
        begin
          if (Key_Hash_ = p^.Data.Fourth) and Compare_Key(Key, p^.Data.Primary) then
            begin
              L.L.MoveToFirst(p);
              R := p^.Data.Second;
              break;
            end;
          Inc(i);
          p := p^.Next;
        end;
    end;
  Result := R;
end;

procedure TBig_Hash_Pair_Pool<TKey_, TValue_>.Set_Key_Value(const Key: TKey_; const Value: TValue_);
begin
  Add(Key, Value, True);
end;

procedure TBig_Hash_Pair_Pool<TKey_, TValue_>.Delete(const Key: TKey_);
var
  Key_Hash_: THash;
  L: TValue_Pair_Pool__;
  i: NativeInt;
  p: PPair_Pool_Value__;
begin
  L := Get_Value_List(Key, Key_Hash_);
  if L.L.Num > 0 then
    begin
      i := 0;
      p := L.L.First;
      while i < L.L.Num do
        begin
          if (Key_Hash_ = p^.Data.Fourth) and Compare_Key(Key, p^.Data.Primary) then
              L.L.Push_To_Recycle_Pool(p);
          Inc(i);
          p := p^.Next;
        end;
    end;
  L.L.Free_Recycle_Pool;
  if L.L.Num <= 0 then
      Free_Value_List(Key_Hash_);
end;

procedure TBig_Hash_Pair_Pool<TKey_, TValue_>.Remove(p: PPair_Pool_Value__);
begin
  Remove(p, True);
end;

procedure TBig_Hash_Pair_Pool<TKey_, TValue_>.Remove(p: PPair_Pool_Value__; Do_Free_Recycle_Pool_: Boolean);
var
  inst_: TValue_Pair_Pool__.TPair_BigList__;
begin
  inst_ := p^.Instance___;
  inst_.Remove_P(p);
  if (Do_Free_Recycle_Pool_) and (inst_.Num <= 0) then
      Free_Recycle_Pool();
end;

function TBig_Hash_Pair_Pool<TKey_, TValue_>.Num: NativeInt;
begin
  Result := FQueue_Pool.Num;
end;

function TBig_Hash_Pair_Pool<TKey_, TValue_>.GetSum: NativeInt;
var
  i: integer;
begin
  Result := 0;
  for i := 0 to FHash_Buffer.Count - 1 do
    if FHash_Buffer[i] <> nil then
        Inc(Result, FHash_Buffer[i].L.Num);
end;

function TBig_Hash_Pair_Pool<TKey_, TValue_>.Get_Value_Ptr(const Key: TKey_): PValue_;
begin
  Result := Get_Value_Ptr(Key, FNULL_VALUE);
end;

function TBig_Hash_Pair_Pool<TKey_, TValue_>.Get_Value_Ptr(const Key: TKey_; const Default_: TValue_): PValue_;
var
  Key_Hash_: THash;
  L: TValue_Pair_Pool__;
  i: NativeInt;
  p: PPair_Pool_Value__;
begin
  Result := nil;
  L := Get_Value_List(Key, Key_Hash_);
  if L.L.Num > 0 then
    begin
      i := 0;
      p := L.L.First;
      while i < L.L.Num do
        begin
          if (Key_Hash_ = p^.Data.Fourth) and Compare_Key(Key, p^.Data.Primary) then
            begin
              L.L.MoveToFirst(p);
              Result := @p^.Data.Second;
              Exit;
            end;
          Inc(i);
          p := p^.Next;
        end;
    end;

  if Result = nil then
    begin
      p := Add(Key, Default_, False);
      Result := @p^.Data.Second;
    end;
end;

function TBig_Hash_Pair_Pool<TKey_, TValue_>.Get_Default_Value(const Key: TKey_; const Default_: TValue_): TValue_;
var
  Key_Hash_: THash;
  L: TValue_Pair_Pool__;
  R: TValue_;
  i: NativeInt;
  p: PPair_Pool_Value__;
begin
  R := Default_;
  L := Get_Value_List(Key, Key_Hash_);
  if L.L.Num > 0 then
    begin
      i := 0;
      p := L.L.First;
      while i < L.L.Num do
        begin
          if (Key_Hash_ = p^.Data.Fourth) and Compare_Key(Key, p^.Data.Primary) then
            begin
              L.L.MoveToFirst(p);
              R := p^.Data.Second;
              break;
            end;
          Inc(i);
          p := p^.Next;
        end;
    end;
  Result := R;
end;

procedure TBig_Hash_Pair_Pool<TKey_, TValue_>.Set_Default_Value(const Key: TKey_; const Default_: TValue_);
begin
  Add(Key, Default_, True);
end;

function TBig_Hash_Pair_Pool<TKey_, TValue_>.Repeat_(): TRepeat___;
begin
  Result := FQueue_Pool.Repeat_();
end;

function TBig_Hash_Pair_Pool<TKey_, TValue_>.Repeat_(BI_, EI_: NativeInt): TRepeat___;
begin
  Result := FQueue_Pool.Repeat_(BI_, EI_);
end;

function TBig_Hash_Pair_Pool<TKey_, TValue_>.Invert_Repeat_(): TInvert_Repeat___;
begin
  Result := FQueue_Pool.Invert_Repeat_();
end;

function TBig_Hash_Pair_Pool<TKey_, TValue_>.Invert_Repeat_(BI_, EI_: NativeInt): TInvert_Repeat___;
begin
  Result := FQueue_Pool.Invert_Repeat_(BI_, EI_);
end;

procedure TBig_Hash_Pair_Pool<TKey_, TValue_>.For_C(OnFor: TBig_Hash_Pool_For_C);
var
  i: integer;
  L: TValue_Pair_Pool__;
  j: NativeInt;
  p: PPair_Pool_Value__;
  Aborted: Boolean;
begin
  Aborted := False;
  for i := 0 to FHash_Buffer.Count - 1 do
    begin
      L := FHash_Buffer[i];
      if (L <> nil) and (L.L.Num > 0) then
        begin
          j := 0;
          p := L.L.First;
          while j < L.L.Num do
            begin
              OnFor(p, Aborted);
              if Aborted then
                  Exit;
              Inc(j);
              p := p^.Next;
            end;
        end;
    end;
end;

procedure TBig_Hash_Pair_Pool<TKey_, TValue_>.For_M(OnFor: TBig_Hash_Pool_For_M);
var
  i: integer;
  L: TValue_Pair_Pool__;
  j: NativeInt;
  p: PPair_Pool_Value__;
  Aborted: Boolean;
begin
  Aborted := False;
  for i := 0 to FHash_Buffer.Count - 1 do
    begin
      L := FHash_Buffer[i];
      if (L <> nil) and (L.L.Num > 0) then
        begin
          j := 0;
          p := L.L.First;
          while j < L.L.Num do
            begin
              OnFor(p, Aborted);
              if Aborted then
                  Exit;
              Inc(j);
              p := p^.Next;
            end;
        end;
    end;
end;

procedure TBig_Hash_Pair_Pool<TKey_, TValue_>.For_P(OnFor: TBig_Hash_Pool_For_P);
var
  i: integer;
  L: TValue_Pair_Pool__;
  j: NativeInt;
  p: PPair_Pool_Value__;
  Aborted: Boolean;
begin
  Aborted := False;
  for i := 0 to FHash_Buffer.Count - 1 do
    begin
      L := FHash_Buffer[i];
      if (L <> nil) and (L.L.Num > 0) then
        begin
          j := 0;
          p := L.L.First;
          while j < L.L.Num do
            begin
              OnFor(p, Aborted);
              if Aborted then
                  Exit;
              Inc(j);
              p := p^.Next;
            end;
        end;
    end;
end;

procedure TBig_Hash_Pair_Pool<TKey_, TValue_>.Push_To_Recycle_Pool(p: PPair_Pool_Value__);
begin
  p^.Instance___.Push_To_Recycle_Pool(p);
end;

procedure TBig_Hash_Pair_Pool<TKey_, TValue_>.Push_To_Recycle_Pool2(p: TPool_Queue_Ptr___);
begin
  p^.Data.Instance___.Push_To_Recycle_Pool(p^.Data);
end;

procedure TBig_Hash_Pair_Pool<TKey_, TValue_>.Free_Recycle_Pool;
var
  i: integer;
  L: TValue_Pair_Pool__;
begin
  for i := 0 to FHash_Buffer.Count - 1 do
    begin
      L := FHash_Buffer[i];
      if (L <> nil) then
        begin
          L.L.Free_Recycle_Pool();
          if L.L.Num <= 0 then
            begin
              DisposeObject(FHash_Buffer[i]);
              FHash_Buffer[i] := nil;
            end;
        end;
    end;
end;

procedure TBig_Hash_Pair_Pool<TKey_, TValue_>.Sort_Key_C(OnSort: TOn_Sort_Key_C);
{$IFDEF FPC}
  function Do_Run_FPC_Sort_(var L, R: PPair_Pool_Value__): integer;
  begin
    Result := OnSort(L^.Data.Primary, R^.Data.Primary);
  end;
{$ENDIF FPC}


begin
{$IFDEF FPC}
  FQueue_Pool.Sort_P(Do_Run_FPC_Sort_);
{$ELSE FPC}
  FQueue_Pool.Sort_P(function(var L, R: PPair_Pool_Value__): integer
    begin
      Result := OnSort(L^.Data.Primary, R^.Data.Primary);
    end);
{$ENDIF FPC}
  Extract_Queue_Pool_Third();
end;

procedure TBig_Hash_Pair_Pool<TKey_, TValue_>.Sort_Key_M(OnSort: TOn_Sort_Key_M);
{$IFDEF FPC}
  function Do_Run_FPC_Sort_(var L, R: PPair_Pool_Value__): integer;
  begin
    Result := OnSort(L^.Data.Primary, R^.Data.Primary);
  end;
{$ENDIF FPC}


begin
{$IFDEF FPC}
  FQueue_Pool.Sort_P(Do_Run_FPC_Sort_);
{$ELSE FPC}
  FQueue_Pool.Sort_P(function(var L, R: PPair_Pool_Value__): integer
    begin
      Result := OnSort(L^.Data.Primary, R^.Data.Primary);
    end);
{$ENDIF FPC}
  Extract_Queue_Pool_Third();
end;

procedure TBig_Hash_Pair_Pool<TKey_, TValue_>.Sort_Key_P(OnSort: TOn_Sort_Key_P);
{$IFDEF FPC}
  function Do_Run_FPC_Sort_(var L, R: PPair_Pool_Value__): integer;
  begin
    Result := OnSort(L^.Data.Primary, R^.Data.Primary);
  end;
{$ENDIF FPC}


begin
{$IFDEF FPC}
  FQueue_Pool.Sort_P(Do_Run_FPC_Sort_);
{$ELSE FPC}
  FQueue_Pool.Sort_P(function(var L, R: PPair_Pool_Value__): integer
    begin
      Result := OnSort(L^.Data.Primary, R^.Data.Primary);
    end);
{$ENDIF FPC}
  Extract_Queue_Pool_Third();
end;

procedure TBig_Hash_Pair_Pool<TKey_, TValue_>.Sort_Value_C(OnSort: TOn_Sort_Value_C);
{$IFDEF FPC}
  function Do_Run_FPC_Sort_(var L, R: PPair_Pool_Value__): integer;
  begin
    Result := OnSort(L^.Data.Second, R^.Data.Second);
  end;
{$ENDIF FPC}


begin
{$IFDEF FPC}
  FQueue_Pool.Sort_P(Do_Run_FPC_Sort_);
{$ELSE FPC}
  FQueue_Pool.Sort_P(function(var L, R: PPair_Pool_Value__): integer
    begin
      Result := OnSort(L^.Data.Second, R^.Data.Second);
    end);
{$ENDIF FPC}
  Extract_Queue_Pool_Third();
end;

procedure TBig_Hash_Pair_Pool<TKey_, TValue_>.Sort_Value_M(OnSort: TOn_Sort_Value_M);
{$IFDEF FPC}
  function Do_Run_FPC_Sort_(var L, R: PPair_Pool_Value__): integer;
  begin
    Result := OnSort(L^.Data.Second, R^.Data.Second);
  end;
{$ENDIF FPC}


begin
{$IFDEF FPC}
  FQueue_Pool.Sort_P(Do_Run_FPC_Sort_);
{$ELSE FPC}
  FQueue_Pool.Sort_P(function(var L, R: PPair_Pool_Value__): integer
    begin
      Result := OnSort(L^.Data.Second, R^.Data.Second);
    end);
{$ENDIF FPC}
  Extract_Queue_Pool_Third();
end;

procedure TBig_Hash_Pair_Pool<TKey_, TValue_>.Sort_Value_P(OnSort: TOn_Sort_Value_P);
{$IFDEF FPC}
  function Do_Run_FPC_Sort_(var L, R: PPair_Pool_Value__): integer;
  begin
    Result := OnSort(L^.Data.Second, R^.Data.Second);
  end;
{$ENDIF FPC}


begin
{$IFDEF FPC}
  FQueue_Pool.Sort_P(Do_Run_FPC_Sort_);
{$ELSE FPC}
  FQueue_Pool.Sort_P(function(var L, R: PPair_Pool_Value__): integer
    begin
      Result := OnSort(L^.Data.Second, R^.Data.Second);
    end);
{$ENDIF FPC}
  Extract_Queue_Pool_Third();
end;

function TBig_Hash_Pair_Pool<TKey_, TValue_>.ToPool(): TPool___;
var
  i: integer;
  L: TValue_Pair_Pool__;
  j: NativeInt;
  p: PPair_Pool_Value__;
begin
  Result := TPool___.Create;
  for i := 0 to FHash_Buffer.Count - 1 do
    begin
      L := FHash_Buffer[i];
      if (L <> nil) and (L.L.Num > 0) then
        begin
          j := 0;
          p := L.L.First;
          while j < L.L.Num do
            begin
              Result.Add(@p^.Data);
              Inc(j);
              p := p^.Next;
            end;
        end;
    end;
end;

function TBig_Hash_Pair_Pool<TKey_, TValue_>.ToArray_Key(): TArray_Key;
var
  i, k: integer;
  L: TValue_Pair_Pool__;
  j: NativeInt;
  p: PPair_Pool_Value__;
begin
  k := 0;
  SetLength(Result, Num);
  for i := 0 to FHash_Buffer.Count - 1 do
    begin
      L := FHash_Buffer[i];
      if (L <> nil) and (L.L.Num > 0) then
        begin
          j := 0;
          p := L.L.First;
          while j < L.L.Num do
            begin
              Result[k] := p^.Data.Primary;
              Inc(k);
              Inc(j);
              p := p^.Next;
            end;
        end;
    end;
end;

function TBig_Hash_Pair_Pool<TKey_, TValue_>.ToOrder_Key(): TOrder_Key;
var
  i: integer;
  L: TValue_Pair_Pool__;
  j: NativeInt;
  p: PPair_Pool_Value__;
begin
  Result := TOrder_Key.Create;
  for i := 0 to FHash_Buffer.Count - 1 do
    begin
      L := FHash_Buffer[i];
      if (L <> nil) and (L.L.Num > 0) then
        begin
          j := 0;
          p := L.L.First;
          while j < L.L.Num do
            begin
              Result.Push(p^.Data.Primary);
              Inc(j);
              p := p^.Next;
            end;
        end;
    end;
end;

function TBig_Hash_Pair_Pool<TKey_, TValue_>.ToArray_Value(): TArray_Value;
var
  i, k: integer;
  L: TValue_Pair_Pool__;
  j: NativeInt;
  p: PPair_Pool_Value__;
begin
  k := 0;
  SetLength(Result, Num);
  for i := 0 to FHash_Buffer.Count - 1 do
    begin
      L := FHash_Buffer[i];
      if (L <> nil) and (L.L.Num > 0) then
        begin
          j := 0;
          p := L.L.First;
          while j < L.L.Num do
            begin
              Result[k] := p^.Data.Second;
              Inc(k);
              Inc(j);
              p := p^.Next;
            end;
        end;
    end;
end;

function TBig_Hash_Pair_Pool<TKey_, TValue_>.ToOrder_Value(): TOrder_Value;
var
  i: integer;
  L: TValue_Pair_Pool__;
  j: NativeInt;
  p: PPair_Pool_Value__;
begin
  Result := TOrder_Value.Create;
  for i := 0 to FHash_Buffer.Count - 1 do
    begin
      L := FHash_Buffer[i];
      if (L <> nil) and (L.L.Num > 0) then
        begin
          j := 0;
          p := L.L.First;
          while j < L.L.Num do
            begin
              Result.Push(p^.Data.Second);
              Inc(j);
              p := p^.Next;
            end;
        end;
    end;
end;

// *****************************************************************************************************************

function TCritical_Big_Hash_Pair_Pool<TKey_, TValue_>.Get_Value_List(const Key_: TKey_; var Key_Hash_: THash): TValue_Pair_Pool__;
var
  i: integer;
begin
  Key_Hash_ := Get_Key_Hash(Key_);
  i := Hash_Key_Mod(Key_Hash_, FHash_Buffer.Count);
  if FHash_Buffer[i] = nil then
    begin
      FHash_Buffer[i] := TValue_Pair_Pool__.Create;
      FHash_Buffer[i].L.FOnFree := Internal_Do_Free;
    end;
  Result := FHash_Buffer[i];
end;

procedure TCritical_Big_Hash_Pair_Pool<TKey_, TValue_>.Free_Value_List(Key_Hash_: THash);
begin
  DisposeObject(FHash_Buffer[Hash_Key_Mod(Key_Hash_, FHash_Buffer.Count)]);
  FHash_Buffer[Hash_Key_Mod(Key_Hash_, FHash_Buffer.Count)] := nil;
end;

procedure TCritical_Big_Hash_Pair_Pool<TKey_, TValue_>.Get_Key_Data_Ptr(const Key_P: PKey_; var p: PByte; var Size: NativeInt);
begin
  p := PByte(Key_P);
  Size := SizeOf(TKey_);
end;

procedure TCritical_Big_Hash_Pair_Pool<TKey_, TValue_>.Internal_Do_Queue_Pool_Free(var Data: PPair_Pool_Value__);
begin
  if Data <> nil then
    begin
      Data^.Data.Third := nil;
      Data^.Instance___.Remove_P(Data);
    end;
end;

procedure TCritical_Big_Hash_Pair_Pool<TKey_, TValue_>.Internal_Do_Free(var Data: TPair);
begin
  if Data.Third <> nil then
    begin
      TPool_Queue_Ptr___(Data.Third)^.Data := nil;
      FQueue_Pool.Remove_P(TPool_Queue_Ptr___(Data.Third));
    end;
  DoFree(Data.Primary, Data.Second);
end;

class function TCritical_Big_Hash_Pair_Pool<TKey_, TValue_>.Null_Key: TKey_;
begin
  FillPtr(@Result, SizeOf(TKey_), 0);
end;

class function TCritical_Big_Hash_Pair_Pool<TKey_, TValue_>.NULL_VALUE: TValue_;
begin
  FillPtr(@Result, SizeOf(TValue_), 0);
end;

constructor TCritical_Big_Hash_Pair_Pool<TKey_, TValue_>.Create(const HashSize_: integer; const NULL_VALUE_: TValue_);
var
  i: integer;
begin
  inherited Create;
  CreateBefore();
  FCritical__ := TCritical.Create('TCritical_Big_Hash_Pair_Pool.FCritical__');
  FQueue_Pool := TPool___.Create;
  FQueue_Pool.FOnFree := Internal_Do_Queue_Pool_Free;
  FHash_Buffer := TKey_Hash_Buffer.Create;
  FHash_Buffer.Count := HashSize_;
  for i := 0 to FHash_Buffer.Count - 1 do
      FHash_Buffer[i] := nil;
  FNULL_VALUE := NULL_VALUE_;
  FOnAdd := nil;
  FOnFree := nil;
  FOn_Get_Key := nil;
  FOn_Compare_Key := nil;
  FOn_Compare_Value := nil;
  CreateAfter();
end;

constructor TCritical_Big_Hash_Pair_Pool<TKey_, TValue_>.Create(const HashSize_: integer);
begin
  Create(HashSize_, T___.NULL_VALUE);
end;

destructor TCritical_Big_Hash_Pair_Pool<TKey_, TValue_>.Destroy;
begin
  Clear;
  FQueue_Pool.Free;
  DisposeObjectAndNil(FHash_Buffer);
  FCritical__.Free;
  inherited Destroy;
end;

procedure TCritical_Big_Hash_Pair_Pool<TKey_, TValue_>.CreateBefore;
begin
end;

procedure TCritical_Big_Hash_Pair_Pool<TKey_, TValue_>.CreateAfter;
begin
end;

procedure TCritical_Big_Hash_Pair_Pool<TKey_, TValue_>.DoFree(var Key: TKey_; var Value: TValue_);
begin
  if Assigned(FOnFree) then
      FOnFree(Key, Value);
end;

procedure TCritical_Big_Hash_Pair_Pool<TKey_, TValue_>.DoAdd(var Key: TKey_; var Value: TValue_);
begin
  if Assigned(FOnAdd) then
      FOnAdd(Key, Value);
end;

function TCritical_Big_Hash_Pair_Pool<TKey_, TValue_>.Get_Key_Hash(const Key_: TKey_): THash;
var
  p: PByte;
  Size: NativeInt;
begin
  if Assigned(FOn_Get_Key) then
      FOn_Get_Key(@Key_, Result)
  else
    begin
      Get_Key_Data_Ptr(@Key_, p, Size);
      Result := Get_CRC32(p, Size);
    end;
end;

function TCritical_Big_Hash_Pair_Pool<TKey_, TValue_>.Compare_Key(const Key_1, Key_2: TKey_): Boolean;
var
  p1, p2: PByte;
  s1, s2: NativeInt;
begin
  if Assigned(FOn_Compare_Key) then
    begin
      Result := False;
      FOn_Compare_Key(@Key_1, @Key_2, Result);
    end
  else
    begin
      Get_Key_Data_Ptr(@Key_1, p1, s1);
      Get_Key_Data_Ptr(@Key_2, p2, s2);
      Result := CompareMemory(p1, p2, Min(s1, s2));
    end;
end;

function TCritical_Big_Hash_Pair_Pool<TKey_, TValue_>.Compare_Value(const Value_1, Value_2: TValue_): Boolean;
begin
  if Assigned(FOn_Compare_Value) then
    begin
      Result := False;
      FOn_Compare_Value(@Value_1, @Value_2, Result);
    end
  else
      Result := CompareMemory(@Value_1, @Value_2, SizeOf(TValue_));
end;

procedure TCritical_Big_Hash_Pair_Pool<TKey_, TValue_>.Lock;
begin
  FCritical__.Lock;
end;

procedure TCritical_Big_Hash_Pair_Pool<TKey_, TValue_>.UnLock;
begin
  FCritical__.UnLock;
end;

procedure TCritical_Big_Hash_Pair_Pool<TKey_, TValue_>.Extract_Queue_Pool_Third;
begin
  if FQueue_Pool.Num > 0 then
    with FQueue_Pool.Repeat_ do
      repeat
          Queue^.Data^.Data.Third := Queue;
      until not Next;
end;

function TCritical_Big_Hash_Pair_Pool<TKey_, TValue_>.GetHashSize: integer;
begin
  Result := FHash_Buffer.Count;
end;

procedure TCritical_Big_Hash_Pair_Pool<TKey_, TValue_>.Clear;
var
  i: integer;
begin
  FCritical__.Lock;
  try
    for i := 0 to FHash_Buffer.Count - 1 do
      begin
        DisposeObject(FHash_Buffer[i]);
        FHash_Buffer[i] := nil;
      end;
  finally
      FCritical__.UnLock;
  end;
end;

function TCritical_Big_Hash_Pair_Pool<TKey_, TValue_>.Exists_Key(const Key: TKey_): Boolean;
var
  Key_Hash_: THash;
  L: TValue_Pair_Pool__;
  i: NativeInt;
  p: PPair_Pool_Value__;
begin
  Result := False;
  FCritical__.Lock;
  try
    L := Get_Value_List(Key, Key_Hash_);
    if L.L.Num > 0 then
      begin
        i := 0;
        p := L.L.First;
        while i < L.L.Num do
          begin
            if (Key_Hash_ = p^.Data.Fourth) and Compare_Key(Key, p^.Data.Primary) then
              begin
                L.L.MoveToFirst(p);
                Result := True;
                Exit;
              end;
            Inc(i);
            p := p^.Next;
          end;
      end;
  finally
      FCritical__.UnLock;
  end;
end;

function TCritical_Big_Hash_Pair_Pool<TKey_, TValue_>.Exists_Value(const Data: TValue_): Boolean;
var
  L: TValue_Pair_Pool__;
  i, j: NativeInt;
  p: PPair_Pool_Value__;
begin
  Result := False;
  FCritical__.Lock;
  try
    for i := 0 to FHash_Buffer.Count - 1 do
      begin
        L := FHash_Buffer[i];
        if (L <> nil) and (L.L.Num > 0) then
          begin
            j := 0;
            p := L.L.First;
            while j < L.L.Num do
              begin
                if Compare_Value(Data, p^.Data.Second) then
                  begin
                    Result := True;
                    Exit;
                  end;
                Inc(j);
                p := p^.Next;
              end;
          end;
      end;
  finally
      FCritical__.UnLock;
  end;
end;

function TCritical_Big_Hash_Pair_Pool<TKey_, TValue_>.Exists(const Key: TKey_): Boolean;
begin
  Result := Exists_Key(Key);
end;

function TCritical_Big_Hash_Pair_Pool<TKey_, TValue_>.Add(const Key: TKey_; const Value: TValue_; Overwrite_: Boolean): PPair_Pool_Value__;
var
  Key_Hash_: THash;
  L: TValue_Pair_Pool__;
  i: integer;
  p: PPair_Pool_Value__;
begin
  FCritical__.Lock;
  try
    L := Get_Value_List(Key, Key_Hash_);

    if Overwrite_ and (L.L.Num > 0) then
      begin
        i := 0;
        p := L.L.First;
        while i < L.L.Num do
          begin
            if (Key_Hash_ = p^.Data.Fourth) and Compare_Key(Key, p^.Data.Primary) then
                L.L.Push_To_Recycle_Pool(p);
            Inc(i);
            p := p^.Next;
          end;
        L.L.Free_Recycle_Pool;
      end;

    L := Get_Value_List(Key, Key_Hash_);
    p := L.L.Add_Null();
    p^.Data.Primary := Key;
    p^.Data.Second := Value;
    p^.Data.Third := FQueue_Pool.Add(p);
    p^.Data.Fourth := Key_Hash_;
    L.L.MoveToFirst(p);
  finally
      FCritical__.UnLock;
  end;
  Result := p;
  DoAdd(p^.Data.Primary, p^.Data.Second);
end;

function TCritical_Big_Hash_Pair_Pool<TKey_, TValue_>.Get_Key_Value(const Key: TKey_): TValue_;
var
  Key_Hash_: THash;
  L: TValue_Pair_Pool__;
  R: TValue_;
  i: NativeInt;
  p: PPair_Pool_Value__;
begin
  R := FNULL_VALUE;
  FCritical__.Lock;
  try
    L := Get_Value_List(Key, Key_Hash_);
    if L.L.Num > 0 then
      begin
        i := 0;
        p := L.L.First;
        while i < L.L.Num do
          begin
            if (Key_Hash_ = p^.Data.Fourth) and Compare_Key(Key, p^.Data.Primary) then
              begin
                L.L.MoveToFirst(p);
                R := p^.Data.Second;
                break;
              end;
            Inc(i);
            p := p^.Next;
          end;
      end;
  finally
      FCritical__.UnLock;
  end;
  Result := R;
end;

procedure TCritical_Big_Hash_Pair_Pool<TKey_, TValue_>.Set_Key_Value(const Key: TKey_; const Value: TValue_);
begin
  Add(Key, Value, True);
end;

procedure TCritical_Big_Hash_Pair_Pool<TKey_, TValue_>.Delete(const Key: TKey_);
var
  Key_Hash_: THash;
  L: TValue_Pair_Pool__;
  i: NativeInt;
  p: PPair_Pool_Value__;
begin
  FCritical__.Lock;
  try
    L := Get_Value_List(Key, Key_Hash_);
    if L.L.Num > 0 then
      begin
        i := 0;
        p := L.L.First;
        while i < L.L.Num do
          begin
            if (Key_Hash_ = p^.Data.Fourth) and Compare_Key(Key, p^.Data.Primary) then
                L.L.Push_To_Recycle_Pool(p);
            Inc(i);
            p := p^.Next;
          end;
      end;
    L.L.Free_Recycle_Pool;
    if L.L.Num <= 0 then
        Free_Value_List(Key_Hash_);
  finally
      FCritical__.UnLock;
  end;
end;

procedure TCritical_Big_Hash_Pair_Pool<TKey_, TValue_>.Remove(p: PPair_Pool_Value__);
begin
  Remove(p, True);
end;

procedure TCritical_Big_Hash_Pair_Pool<TKey_, TValue_>.Remove(p: PPair_Pool_Value__; Do_Free_Recycle_Pool_: Boolean);
var
  inst_: TValue_Pair_Pool__.TPair_BigList__;
begin
  FCritical__.Lock;
  try
    inst_ := p^.Instance___;
    inst_.Remove_P(p);
  finally
      FCritical__.UnLock;
  end;
  if (Do_Free_Recycle_Pool_) and (inst_.Num <= 0) then
      Free_Recycle_Pool();
end;

function TCritical_Big_Hash_Pair_Pool<TKey_, TValue_>.Num: NativeInt;
begin
  Result := FQueue_Pool.Num;
end;

function TCritical_Big_Hash_Pair_Pool<TKey_, TValue_>.GetSum: NativeInt;
var
  i: integer;
begin
  Result := 0;
  FCritical__.Lock;
  try
    for i := 0 to FHash_Buffer.Count - 1 do
      if FHash_Buffer[i] <> nil then
          Inc(Result, FHash_Buffer[i].L.Num);
  finally
      FCritical__.UnLock;
  end;
end;

function TCritical_Big_Hash_Pair_Pool<TKey_, TValue_>.Get_Value_Ptr(const Key: TKey_): PValue_;
begin
  Result := Get_Value_Ptr(Key, FNULL_VALUE);
end;

function TCritical_Big_Hash_Pair_Pool<TKey_, TValue_>.Get_Value_Ptr(const Key: TKey_; const Default_: TValue_): PValue_;
var
  Key_Hash_: THash;
  L: TValue_Pair_Pool__;
  i: NativeInt;
  p: PPair_Pool_Value__;
begin
  Result := nil;
  FCritical__.Lock;
  try
    L := Get_Value_List(Key, Key_Hash_);
    if L.L.Num > 0 then
      begin
        i := 0;
        p := L.L.First;
        while i < L.L.Num do
          begin
            if (Key_Hash_ = p^.Data.Fourth) and Compare_Key(Key, p^.Data.Primary) then
              begin
                L.L.MoveToFirst(p);
                Result := @p^.Data.Second;
                Exit;
              end;
            Inc(i);
            p := p^.Next;
          end;
      end;

    if Result = nil then
      begin
        p := Add(Key, Default_, False);
        Result := @p^.Data.Second;
      end;
  finally
      FCritical__.UnLock;
  end;
end;

function TCritical_Big_Hash_Pair_Pool<TKey_, TValue_>.Get_Default_Value(const Key: TKey_; const Default_: TValue_): TValue_;
var
  Key_Hash_: THash;
  L: TValue_Pair_Pool__;
  R: TValue_;
  i: NativeInt;
  p: PPair_Pool_Value__;
begin
  R := Default_;
  FCritical__.Lock;
  try
    L := Get_Value_List(Key, Key_Hash_);
    if L.L.Num > 0 then
      begin
        i := 0;
        p := L.L.First;
        while i < L.L.Num do
          begin
            if (Key_Hash_ = p^.Data.Fourth) and Compare_Key(Key, p^.Data.Primary) then
              begin
                L.L.MoveToFirst(p);
                R := p^.Data.Second;
                break;
              end;
            Inc(i);
            p := p^.Next;
          end;
      end;
  finally
      FCritical__.UnLock;
  end;
  Result := R;
end;

procedure TCritical_Big_Hash_Pair_Pool<TKey_, TValue_>.Set_Default_Value(const Key: TKey_; const Default_: TValue_);
begin
  Add(Key, Default_, True);
end;

function TCritical_Big_Hash_Pair_Pool<TKey_, TValue_>.Repeat_(): TRepeat___;
begin
  Result := FQueue_Pool.Repeat_();
end;

function TCritical_Big_Hash_Pair_Pool<TKey_, TValue_>.Repeat_(BI_, EI_: NativeInt): TRepeat___;
begin
  Result := FQueue_Pool.Repeat_(BI_, EI_);
end;

function TCritical_Big_Hash_Pair_Pool<TKey_, TValue_>.Invert_Repeat_(): TInvert_Repeat___;
begin
  Result := FQueue_Pool.Invert_Repeat_();
end;

function TCritical_Big_Hash_Pair_Pool<TKey_, TValue_>.Invert_Repeat_(BI_, EI_: NativeInt): TInvert_Repeat___;
begin
  Result := FQueue_Pool.Invert_Repeat_(BI_, EI_);
end;

procedure TCritical_Big_Hash_Pair_Pool<TKey_, TValue_>.For_C(OnFor: TBig_Hash_Pool_For_C);
var
  i: integer;
  L: TValue_Pair_Pool__;
  j: NativeInt;
  p: PPair_Pool_Value__;
  Aborted: Boolean;
begin
  Aborted := False;
  FCritical__.Lock;
  try
    for i := 0 to FHash_Buffer.Count - 1 do
      begin
        L := FHash_Buffer[i];
        if (L <> nil) and (L.L.Num > 0) then
          begin
            j := 0;
            p := L.L.First;
            while j < L.L.Num do
              begin
                OnFor(p, Aborted);
                if Aborted then
                    Exit;
                Inc(j);
                p := p^.Next;
              end;
          end;
      end;
  finally
      FCritical__.UnLock;
  end;
end;

procedure TCritical_Big_Hash_Pair_Pool<TKey_, TValue_>.For_M(OnFor: TBig_Hash_Pool_For_M);
var
  i: integer;
  L: TValue_Pair_Pool__;
  j: NativeInt;
  p: PPair_Pool_Value__;
  Aborted: Boolean;
begin
  Aborted := False;
  FCritical__.Lock;
  try
    for i := 0 to FHash_Buffer.Count - 1 do
      begin
        L := FHash_Buffer[i];
        if (L <> nil) and (L.L.Num > 0) then
          begin
            j := 0;
            p := L.L.First;
            while j < L.L.Num do
              begin
                OnFor(p, Aborted);
                if Aborted then
                    Exit;
                Inc(j);
                p := p^.Next;
              end;
          end;
      end;
  finally
      FCritical__.UnLock;
  end;
end;

procedure TCritical_Big_Hash_Pair_Pool<TKey_, TValue_>.For_P(OnFor: TBig_Hash_Pool_For_P);
var
  i: integer;
  L: TValue_Pair_Pool__;
  j: NativeInt;
  p: PPair_Pool_Value__;
  Aborted: Boolean;
begin
  Aborted := False;
  FCritical__.Lock;
  try
    for i := 0 to FHash_Buffer.Count - 1 do
      begin
        L := FHash_Buffer[i];
        if (L <> nil) and (L.L.Num > 0) then
          begin
            j := 0;
            p := L.L.First;
            while j < L.L.Num do
              begin
                OnFor(p, Aborted);
                if Aborted then
                    Exit;
                Inc(j);
                p := p^.Next;
              end;
          end;
      end;
  finally
      FCritical__.UnLock;
  end;
end;

procedure TCritical_Big_Hash_Pair_Pool<TKey_, TValue_>.Push_To_Recycle_Pool(p: PPair_Pool_Value__);
begin
  p^.Instance___.Push_To_Recycle_Pool(p);
end;

procedure TCritical_Big_Hash_Pair_Pool<TKey_, TValue_>.Push_To_Recycle_Pool2(p: TPool_Queue_Ptr___);
begin
  p^.Data.Instance___.Push_To_Recycle_Pool(p^.Data);
end;

procedure TCritical_Big_Hash_Pair_Pool<TKey_, TValue_>.Free_Recycle_Pool;
var
  i: integer;
  L: TValue_Pair_Pool__;
begin
  FCritical__.Lock;
  try
    for i := 0 to FHash_Buffer.Count - 1 do
      begin
        L := FHash_Buffer[i];
        if (L <> nil) then
          begin
            L.L.Free_Recycle_Pool();
            if L.L.Num <= 0 then
              begin
                DisposeObject(FHash_Buffer[i]);
                FHash_Buffer[i] := nil;
              end;
          end;
      end;
  finally
      FCritical__.UnLock;
  end;
end;

procedure TCritical_Big_Hash_Pair_Pool<TKey_, TValue_>.Sort_Key_C(OnSort: TOn_Sort_Key_C);
{$IFDEF FPC}
  function Do_Run_FPC_Sort_(var L, R: PPair_Pool_Value__): integer;
  begin
    Result := OnSort(L^.Data.Primary, R^.Data.Primary);
  end;
{$ENDIF FPC}


begin
  FCritical__.Lock;
  try
{$IFDEF FPC}
    FQueue_Pool.Sort_P(Do_Run_FPC_Sort_);
{$ELSE FPC}
    FQueue_Pool.Sort_P(function(var L, R: PPair_Pool_Value__): integer
      begin
        Result := OnSort(L^.Data.Primary, R^.Data.Primary);
      end);
{$ENDIF FPC}
    Extract_Queue_Pool_Third();
  finally
      FCritical__.UnLock;
  end;
end;

procedure TCritical_Big_Hash_Pair_Pool<TKey_, TValue_>.Sort_Key_M(OnSort: TOn_Sort_Key_M);
{$IFDEF FPC}
  function Do_Run_FPC_Sort_(var L, R: PPair_Pool_Value__): integer;
  begin
    Result := OnSort(L^.Data.Primary, R^.Data.Primary);
  end;
{$ENDIF FPC}


begin
  FCritical__.Lock;
  try
{$IFDEF FPC}
    FQueue_Pool.Sort_P(Do_Run_FPC_Sort_);
{$ELSE FPC}
    FQueue_Pool.Sort_P(function(var L, R: PPair_Pool_Value__): integer
      begin
        Result := OnSort(L^.Data.Primary, R^.Data.Primary);
      end);
{$ENDIF FPC}
    Extract_Queue_Pool_Third();
  finally
      FCritical__.UnLock;
  end;
end;

procedure TCritical_Big_Hash_Pair_Pool<TKey_, TValue_>.Sort_Key_P(OnSort: TOn_Sort_Key_P);
{$IFDEF FPC}
  function Do_Run_FPC_Sort_(var L, R: PPair_Pool_Value__): integer;
  begin
    Result := OnSort(L^.Data.Primary, R^.Data.Primary);
  end;
{$ENDIF FPC}


begin
  FCritical__.Lock;
  try
{$IFDEF FPC}
    FQueue_Pool.Sort_P(Do_Run_FPC_Sort_);
{$ELSE FPC}
    FQueue_Pool.Sort_P(function(var L, R: PPair_Pool_Value__): integer
      begin
        Result := OnSort(L^.Data.Primary, R^.Data.Primary);
      end);
{$ENDIF FPC}
    Extract_Queue_Pool_Third();
  finally
      FCritical__.UnLock;
  end;
end;

procedure TCritical_Big_Hash_Pair_Pool<TKey_, TValue_>.Sort_Value_C(OnSort: TOn_Sort_Value_C);
{$IFDEF FPC}
  function Do_Run_FPC_Sort_(var L, R: PPair_Pool_Value__): integer;
  begin
    Result := OnSort(L^.Data.Second, R^.Data.Second);
  end;
{$ENDIF FPC}


begin
  FCritical__.Lock;
  try
{$IFDEF FPC}
    FQueue_Pool.Sort_P(Do_Run_FPC_Sort_);
{$ELSE FPC}
    FQueue_Pool.Sort_P(function(var L, R: PPair_Pool_Value__): integer
      begin
        Result := OnSort(L^.Data.Second, R^.Data.Second);
      end);
{$ENDIF FPC}
    Extract_Queue_Pool_Third();
  finally
      FCritical__.UnLock;
  end;
end;

procedure TCritical_Big_Hash_Pair_Pool<TKey_, TValue_>.Sort_Value_M(OnSort: TOn_Sort_Value_M);
{$IFDEF FPC}
  function Do_Run_FPC_Sort_(var L, R: PPair_Pool_Value__): integer;
  begin
    Result := OnSort(L^.Data.Second, R^.Data.Second);
  end;
{$ENDIF FPC}


begin
  FCritical__.Lock;
  try
{$IFDEF FPC}
    FQueue_Pool.Sort_P(Do_Run_FPC_Sort_);
{$ELSE FPC}
    FQueue_Pool.Sort_P(function(var L, R: PPair_Pool_Value__): integer
      begin
        Result := OnSort(L^.Data.Second, R^.Data.Second);
      end);
{$ENDIF FPC}
    Extract_Queue_Pool_Third();
  finally
      FCritical__.UnLock;
  end;
end;

procedure TCritical_Big_Hash_Pair_Pool<TKey_, TValue_>.Sort_Value_P(OnSort: TOn_Sort_Value_P);
{$IFDEF FPC}
  function Do_Run_FPC_Sort_(var L, R: PPair_Pool_Value__): integer;
  begin
    Result := OnSort(L^.Data.Second, R^.Data.Second);
  end;
{$ENDIF FPC}


begin
  FCritical__.Lock;
  try
{$IFDEF FPC}
    FQueue_Pool.Sort_P(Do_Run_FPC_Sort_);
{$ELSE FPC}
    FQueue_Pool.Sort_P(function(var L, R: PPair_Pool_Value__): integer
      begin
        Result := OnSort(L^.Data.Second, R^.Data.Second);
      end);
{$ENDIF FPC}
    Extract_Queue_Pool_Third();
  finally
      FCritical__.UnLock;
  end;
end;

function TCritical_Big_Hash_Pair_Pool<TKey_, TValue_>.ToPool(): TPool___;
var
  i: integer;
  L: TValue_Pair_Pool__;
  j: NativeInt;
  p: PPair_Pool_Value__;
begin
  Result := TPool___.Create;
  FCritical__.Lock;
  try
    for i := 0 to FHash_Buffer.Count - 1 do
      begin
        L := FHash_Buffer[i];
        if (L <> nil) and (L.L.Num > 0) then
          begin
            j := 0;
            p := L.L.First;
            while j < L.L.Num do
              begin
                Result.Add(@p^.Data);
                Inc(j);
                p := p^.Next;
              end;
          end;
      end;
  finally
      FCritical__.UnLock;
  end;
end;

function TCritical_Big_Hash_Pair_Pool<TKey_, TValue_>.ToArray_Key(): TArray_Key;
var
  i, k: integer;
  L: TValue_Pair_Pool__;
  j: NativeInt;
  p: PPair_Pool_Value__;
begin
  FCritical__.Lock;
  try
    k := 0;
    SetLength(Result, FQueue_Pool.Num);
    for i := 0 to FHash_Buffer.Count - 1 do
      begin
        L := FHash_Buffer[i];
        if (L <> nil) and (L.L.Num > 0) then
          begin
            j := 0;
            p := L.L.First;
            while j < L.L.Num do
              begin
                Result[k] := p^.Data.Primary;
                Inc(k);
                Inc(j);
                p := p^.Next;
              end;
          end;
      end;
  finally
      FCritical__.UnLock;
  end;
end;

function TCritical_Big_Hash_Pair_Pool<TKey_, TValue_>.ToOrder_Key(): TOrder_Key;
var
  i: integer;
  L: TValue_Pair_Pool__;
  j: NativeInt;
  p: PPair_Pool_Value__;
begin
  FCritical__.Lock;
  try
    Result := TOrder_Key.Create;
    for i := 0 to FHash_Buffer.Count - 1 do
      begin
        L := FHash_Buffer[i];
        if (L <> nil) and (L.L.Num > 0) then
          begin
            j := 0;
            p := L.L.First;
            while j < L.L.Num do
              begin
                Result.Push(p^.Data.Primary);
                Inc(j);
                p := p^.Next;
              end;
          end;
      end;
  finally
      FCritical__.UnLock;
  end;
end;

function TCritical_Big_Hash_Pair_Pool<TKey_, TValue_>.ToArray_Value(): TArray_Value;
var
  i, k: integer;
  L: TValue_Pair_Pool__;
  j: NativeInt;
  p: PPair_Pool_Value__;
begin
  FCritical__.Lock;
  try
    k := 0;
    SetLength(Result, FQueue_Pool.Num);
    for i := 0 to FHash_Buffer.Count - 1 do
      begin
        L := FHash_Buffer[i];
        if (L <> nil) and (L.L.Num > 0) then
          begin
            j := 0;
            p := L.L.First;
            while j < L.L.Num do
              begin
                Result[k] := p^.Data.Second;
                Inc(k);
                Inc(j);
                p := p^.Next;
              end;
          end;
      end;
  finally
      FCritical__.UnLock;
  end;
end;

function TCritical_Big_Hash_Pair_Pool<TKey_, TValue_>.ToOrder_Value(): TOrder_Value;
var
  i: integer;
  L: TValue_Pair_Pool__;
  j: NativeInt;
  p: PPair_Pool_Value__;
begin
  FCritical__.Lock;
  try
    Result := TOrder_Value.Create;
    for i := 0 to FHash_Buffer.Count - 1 do
      begin
        L := FHash_Buffer[i];
        if (L <> nil) and (L.L.Num > 0) then
          begin
            j := 0;
            p := L.L.First;
            while j < L.L.Num do
              begin
                Result.Push(p^.Data.Second);
                Inc(j);
                p := p^.Next;
              end;
          end;
      end;
  finally
      FCritical__.UnLock;
  end;
end;

constructor TBig_Hash_Object_Pool<TKey_, TValue_>.Create(const HashSize_: integer; const AutoFree_: Boolean);
begin
  inherited Create(HashSize_, nil);
  AutoFree := AutoFree_;
end;

procedure TBig_Hash_Object_Pool<TKey_, TValue_>.DoFree(var Key: TKey_; var Value: TValue_);
begin
  if AutoFree then
      DisposeObjectAndNil(Value);
  inherited DoFree(Key, Value);
end;

constructor TCritical_Big_Hash_Object_Pool<TKey_, TValue_>.Create(const HashSize_: integer; const AutoFree_: Boolean);
begin
  inherited Create(HashSize_, nil);
  AutoFree := AutoFree_;
end;

procedure TCritical_Big_Hash_Object_Pool<TKey_, TValue_>.DoFree(var Key: TKey_; var Value: TValue_);
begin
  if AutoFree then
      DisposeObjectAndNil(Value);
  inherited DoFree(Key, Value);
end;

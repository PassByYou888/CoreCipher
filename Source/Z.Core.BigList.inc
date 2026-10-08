procedure TBigList<T_>.TRepeat___.Init_(Instance_: T___);
begin
  // Begin Index
  BI___ := 0;
  // End Index
  EI___ := Instance_.Num - 1;
  // Current index
  I___ := 0;
  Instance___ := Instance_;
  p___ := Instance___.First;
  while I___ < BI___ do
    begin
      p___ := p___^.Next;
      inc(I___);
    end;
  Is_Discard___ := False;
end;

procedure TBigList<T_>.TRepeat___.Init_(Instance_: T___; BI_, EI_: NativeInt);
begin
  // Begin Index
  BI___ := BI_;
  // End Index
  EI___ := EI_;
  // check
  if BI___ > EI___ then
      TSwap<NativeInt>.Do_(BI___, EI___);
  // Current index
  I___ := 0;
  Instance___ := Instance_;
  p___ := Instance___.First;
  while I___ < BI___ do
    begin
      p___ := p___^.Next;
      inc(I___);
    end;
  Is_Discard___ := False;
end;

procedure TBigList<T_>.TRepeat___.Discard;
begin
  Is_Discard___ := True;
end;

function TBigList<T_>.TRepeat___.Next: Boolean;
begin
  Result := False;
  if I___ > EI___ then
    begin
      p___ := nil;
      exit;
    end;
  p___ := p___^.Next;
  Result := I___ < EI___;
  if Is_Discard___ then
    begin
      Is_Discard___ := False;
      Instance___.Remove_P(p___^.Prev);
      Dec(EI___);
    end
  else
      inc(I___);
end;

procedure TBigList<T_>.TInvert_Repeat___.Init_(Instance_: T___);
begin
  // Begin Index
  BI___ := Instance_.Num - 1;
  // End Index
  EI___ := 0;
  // Current index
  I___ := Instance_.Num - 1;
  Instance___ := Instance_;
  p___ := Instance___.Last;
  while I___ > BI___ do
    begin
      p___ := p___^.Prev;
      Dec(I___);
    end;
  Is_Discard___ := False;
end;

procedure TBigList<T_>.TInvert_Repeat___.Init_(Instance_: T___; BI_, EI_: NativeInt);
begin
  // Begin Index
  BI___ := BI_;
  // End Index
  EI___ := EI_;
  // check
  if BI___ < EI___ then
      TSwap<NativeInt>.Do_(BI___, EI___);
  // Current index
  I___ := Instance_.Num - 1;
  Instance___ := Instance_;
  p___ := Instance___.Last;
  while I___ > BI___ do
    begin
      p___ := p___^.Prev;
      Dec(I___);
    end;
  Is_Discard___ := False;
end;

procedure TBigList<T_>.TInvert_Repeat___.Discard;
begin
  Is_Discard___ := True;
end;

function TBigList<T_>.TInvert_Repeat___.Prev: Boolean;
begin
  Result := False;
  if I___ < EI___ then
    begin
      p___ := nil;
      exit;
    end;
  p___ := p___^.Prev;
  Result := I___ > EI___;
  if Is_Discard___ then
    begin
      Is_Discard___ := False;
      Instance___.Remove_P(p___^.Next);
      Dec(BI___);
    end;
  Dec(I___);
end;

procedure TBigList<T_>.DoInternalFree(p: PQueueStruct);
begin
{$IFDEF DEBUG}
  if p^.Instance___ <> Self then
      raiseInfo('error');
{$ENDIF DEBUG}
  try
    DoFree(p^.Data);
    Dispose(p);
  except
  end;
end;

function TBigList<T_>.Get_Critical__: TCritical;
begin
  if FCritical__ = nil then
      FCritical__ := TCritical.Create('TBigList.FCritical__');
  Result := FCritical__;
end;

constructor TBigList<T_>.Create;
begin
  inherited Create;
  FCritical__ := nil;
  FRecycle_Pool__ := nil;
  FFirst := nil;
  FLast := nil;
  FNum := 0;
  FOnAdd := nil;
  FOnFree := nil;
  FOnFree_For_Pair_Tool := nil;
  FEnabled_Sort := True;
  FChanged := False;
  FList := nil;
end;

destructor TBigList<T_>.Destroy;
begin
  Clear;
  DisposeObjectAndNil(FCritical__);
  inherited Destroy;
end;

procedure TBigList<T_>.DoFree(var Data: T_);
begin
  if Assigned(FOnFree_For_Pair_Tool) then
      FOnFree_For_Pair_Tool(Data);
  if Assigned(FOnFree) then
      FOnFree(Data);
end;

procedure TBigList<T_>.DoAdd(var Data: T_);
begin
  if Assigned(FOnAdd) then
      FOnAdd(Data);
end;

function TBigList<T_>.CompareData(const Data_1, Data_2: T_): Boolean;
begin
  Result := CompareMemory(@Data_1, @Data_2, SizeOf(T_));
end;

procedure TBigList<T_>.Lock;
begin
  Critical__.Lock;
end;

procedure TBigList<T_>.UnLock;
begin
  Critical__.UnLock;
end;

function TBigList<T_>.Get_Recycle_Pool_Num: NativeInt;
begin
  if FRecycle_Pool__ <> nil then
      Result := FRecycle_Pool__.Num
  else
      Result := 0;
end;

procedure TBigList<T_>.Push_To_Recycle_Pool(p: PQueueStruct);
begin
{$IFDEF DEBUG}
  if p^.Instance___ <> Self then
      raiseInfo('error');
{$ENDIF DEBUG}
  if FRecycle_Pool__ = nil then
      FRecycle_Pool__ := TRecycle_Pool__.Create;

  if not p^.Recycle___ then
    begin
      p^.Recycle___ := True;
      FRecycle_Pool__.Push(p);
    end;
end;

procedure TBigList<T_>.Free_Recycle_Pool;
begin
  if FRecycle_Pool__ <> nil then
    begin
      while FRecycle_Pool__.Num > 0 do
        begin
          Remove_P(FRecycle_Pool__.First^.Data);
          FRecycle_Pool__.Next;
        end;
      FRecycle_Pool__.Free;
      FRecycle_Pool__ := nil;
    end;
end;

procedure TBigList<T_>.Clear;
var
  i: NativeInt;
  p, N_P: PQueueStruct;
begin
  if FRecycle_Pool__ <> nil then
    begin
      FRecycle_Pool__.Free;
      FRecycle_Pool__ := nil;
    end;
  if FNum > 0 then
    begin
      i := 0;
      p := FFirst;
      while i < FNum do
        begin
          N_P := p^.Next;
          DoInternalFree(p);
          inc(i);
          p := N_P;
        end;
    end;
  FNum := 0;
  if FList <> nil then
    begin
      System.FreeMemory(FList);
      FList := nil;
    end;
  FFirst := nil;
  FLast := nil;
  FChanged := True;
end;

procedure TBigList<T_>.Next;
begin
  if FFirst <> nil then
      Remove_P(FFirst);
end;

function TBigList<T_>.Add(const Data: T_): PQueueStruct;
var
  p: PQueueStruct;
begin
  new(p);
  p^.Data := Data;
  if (FFirst = nil) or (FLast = nil) then
    begin
      FFirst := p;
      FLast := p;
      p^.Prev := p;
      p^.Next := p;
    end
  else if FFirst = FLast then
    begin
      FLast := p;
      FFirst^.Prev := FLast;
      FFirst^.Next := FLast;
      FLast^.Next := FFirst;
      FLast^.Prev := FFirst;
    end
  else
    begin
      FFirst^.Prev := p;
      FLast^.Next := p;
      p^.Next := FFirst;
      p^.Prev := FLast;
      FLast := p;
    end;
  p^.Instance___ := Self;
  p^.Recycle___ := False;
  inc(FNum);
  FChanged := True;
  Result := p;
  DoAdd(p^.Data);
end;

procedure TBigList<T_>.AddL(L_: T___);
begin
  if L_.Num > 0 then
    with L_.Repeat_ do
      repeat
          Add(Queue^.Data);
      until not Next;
end;

function TBigList<T_>.Add_Null(): PQueueStruct;
var
  p: PQueueStruct;
begin
  new(p);
  if (FFirst = nil) or (FLast = nil) then
    begin
      FFirst := p;
      FLast := p;
      p^.Prev := p;
      p^.Next := p;
    end
  else if FFirst = FLast then
    begin
      FLast := p;
      FFirst^.Prev := FLast;
      FFirst^.Next := FLast;
      FLast^.Next := FFirst;
      FLast^.Prev := FFirst;
    end
  else
    begin
      FFirst^.Prev := p;
      FLast^.Next := p;
      p^.Next := FFirst;
      p^.Prev := FLast;
      FLast := p;
    end;
  p^.Instance___ := Self;
  p^.Recycle___ := False;
  inc(FNum);
  FChanged := True;
  Result := p;
  DoAdd(p^.Data);
end;

function TBigList<T_>.Insert(const Data: T_; To_: PQueueStruct): PQueueStruct;
var
  p: PQueueStruct;
  P_P: PQueueStruct;
begin
{$IFDEF DEBUG}
  if To_^.Instance___ <> Self then
      raiseInfo('error');
{$ENDIF DEBUG}
  new(p);
  p^.Data := Data;

  if FFirst = To_ then
      FFirst := p;
  P_P := To_^.Prev;
  if P_P^.Next = To_ then
      P_P^.Next := p;
  if To_^.Next = To_ then
      To_^.Next := p;
  To_^.Prev := p;
  p^.Prev := P_P;
  p^.Next := To_;
  p^.Instance___ := Self;
  p^.Recycle___ := False;
  inc(FNum);
  FChanged := True;
  Result := p;
  DoAdd(p^.Data);
end;

function TBigList<T_>.CopyFrom(Source_: T___): NativeInt;
begin
  Result := Source_.Num;
  if Result > 0 then
    with Source_.Repeat_ do
      repeat
          Add(Queue^.Data);
      until not Next;
end;

procedure TBigList<T_>.Remove_P(p: PQueueStruct);
var
  P_P, N_P: PQueueStruct;
begin
{$IFDEF DEBUG}
  if p^.Instance___ <> Self then
      raiseInfo('error');
{$ENDIF DEBUG}
  P_P := p^.Prev;
  N_P := p^.Next;
  if p = FFirst then
      FFirst := N_P;
  if p = FLast then
      FLast := P_P;
  if (FFirst = FLast) and (FLast = p) then
    begin
      FFirst := nil;
      FLast := nil;
      FNum := 0;
    end
  else
    begin
      P_P^.Next := N_P;
      N_P^.Prev := P_P;
      Dec(FNum);
    end;
  FChanged := True;
  DoInternalFree(p);
end;

procedure TBigList<T_>.Remove_T(const Data: T_);
begin
  Remove_Data(Data);
end;

procedure TBigList<T_>.Move_Before(p, To_: PQueueStruct);
var
  P_P, N_P: PQueueStruct;
  tmp: T_;
begin
{$IFDEF DEBUG}
  if p^.Instance___ <> Self then
      raiseInfo('error');
  if To_^.Instance___ <> Self then
      raiseInfo('error');
{$ENDIF DEBUG}
  if p = To_ then
      exit;
  // step 1: remove
  P_P := p^.Prev;
  N_P := p^.Next;
  if p = FFirst then
      FFirst := N_P;
  if p = FLast then
      FLast := P_P;
  if (FFirst = FLast) and (FLast = p) then
    begin
      FFirst := nil;
      FLast := nil;
    end
  else
    begin
      P_P^.Next := N_P;
      N_P^.Prev := P_P;
    end;

  // step 2: insert
  if FFirst = To_ then
      FFirst := p;
  P_P := To_^.Prev;
  if P_P^.Next = To_ then
      P_P^.Next := p;
  if To_^.Next = To_ then
      To_^.Next := p;
  To_^.Prev := p;
  p^.Prev := P_P;
  p^.Next := To_;

  FChanged := True;
end;

procedure TBigList<T_>.MoveToFirst(p: PQueueStruct);
begin
  Move_Before(p, First);
end;

procedure TBigList<T_>.MoveToLast(p: PQueueStruct);
var
  P_P, N_P: PQueueStruct;
  tmp: T_;
begin
{$IFDEF DEBUG}
  if p^.Instance___ <> Self then
      raiseInfo('error');
{$ENDIF DEBUG}
  if p = Last then
      exit;
  // step 1: remove
  P_P := p^.Prev;
  N_P := p^.Next;
  if p = FFirst then
      FFirst := N_P;
  if p = FLast then
      FLast := P_P;
  if (FFirst = FLast) and (FLast = p) then
    begin
      FFirst := nil;
      FLast := nil;
    end
  else
    begin
      P_P^.Next := N_P;
      N_P^.Prev := P_P;
    end;

  // step 2: append
  if (FFirst = nil) or (FLast = nil) then
    begin
      FFirst := p;
      FLast := p;
      p^.Prev := p;
      p^.Next := p;
    end
  else if FFirst = FLast then
    begin
      FLast := p;
      FFirst^.Prev := FLast;
      FFirst^.Next := FLast;
      FLast^.Next := FFirst;
      FLast^.Prev := FFirst;
    end
  else
    begin
      FFirst^.Prev := p;
      FLast^.Next := p;
      p^.Next := FFirst;
      p^.Prev := FLast;
      FLast := p;
    end;

  FChanged := True;
end;

procedure TBigList<T_>.Exchange(p1, p2: PQueueStruct);
var
  tmp: T_;
begin
{$IFDEF DEBUG}
  if p1^.Instance___ <> Self then
      raiseInfo('error');
  if p2^.Instance___ <> Self then
      raiseInfo('error');
{$ENDIF DEBUG}
  if p1 = p2 then
      exit;
  tmp := p1^.Data;
  p1^.Data := p2^.Data;
  p2^.Data := tmp;
end;

function TBigList<T_>.Found(p1: PQueueStruct): NativeInt;
var
  i: NativeInt;
  p: PQueueStruct;
begin
  if FNum > 0 then
    begin
      i := 0;
      p := FFirst;
      while i < FNum do
        begin
          if p = p1 then
            begin
              Result := i; exit;
            end;
          inc(i);
          p := p^.Next;
        end;
    end;
  Result := -1;
end;

function TBigList<T_>.Find_Data(const Data: T_): PQueueStruct;
var
  i: NativeInt;
  p: PQueueStruct;
begin
  Result := nil;
  if FNum > 0 then
    begin
      i := 0;
      p := FFirst;
      while i < FNum do
        begin
          if CompareData(Data, p^.Data) then
            begin
              Result := p; exit;
            end;
          inc(i);
          p := p^.Next;
        end;
    end;
end;

function TBigList<T_>.Find_Data_Ptr(const Data_Ptr: P_): PQueueStruct;
var
  i: NativeInt;
  p: PQueueStruct;
begin
  Result := nil;
  if FNum > 0 then
    begin
      i := 0;
      p := FFirst;
      while i < FNum do
        begin
          if Data_Ptr = @p^.Data then
            begin
              Result := p; exit;
            end;
          inc(i);
          p := p^.Next;
        end;
    end;
end;

function TBigList<T_>.Search_Data_As_Array(const Data: T_): TArray_T_;
var
  L: TOrder_Data_Pool;
  i: Integer;
begin
  L := Search_Data_As_Order(Data);
  SetLength(Result, L.Num);
  i := 0;
  while L.Num > 0 do
    begin
      Result[i] := L.First^.Data;
      L.Next;
    end;
  DisposeObject(L);
end;

function TBigList<T_>.Search_Data_As_Order(const Data: T_): TOrder_Data_Pool;
var
  i: NativeInt;
  p: PQueueStruct;
begin
  Result := TOrder_Data_Pool.Create;
  if FNum > 0 then
    begin
      i := 0;
      p := FFirst;
      while i < FNum do
        begin
          if CompareData(Data, p^.Data) then
              Result.Push(p^.Data);
          inc(i);
          p := p^.Next;
        end;
    end;
end;

function TBigList<T_>.Remove_Data(const Data: T_): Integer;
var
  i: NativeInt;
  p: PQueueStruct;
begin
  if FNum > 0 then
    begin
      i := 0;
      p := FFirst;
      while i < FNum do
        begin
          if CompareData(Data, p^.Data) then
              Push_To_Recycle_Pool(p);
          inc(i);
          p := p^.Next;
        end;
    end;
  Result := FRecycle_Pool__.Num;
  Free_Recycle_Pool();
end;

function TBigList<T_>.Repeat_(): TRepeat___;
begin
  if Num <= 0 then
      raiseInfo('List is Null');
  Result.Init_(Self);
end;

function TBigList<T_>.Repeat_(BI_, EI_: NativeInt): TRepeat___;
begin
  if Num <= 0 then
      raiseInfo('List is Null');
  Result.Init_(Self, BI_, EI_);
end;

function TBigList<T_>.Invert_Repeat_(): TInvert_Repeat___;
begin
  if Num <= 0 then
      raiseInfo('List is Null');
  Result.Init_(Self);
end;

function TBigList<T_>.Invert_Repeat_(BI_, EI_: NativeInt): TInvert_Repeat___;
begin
  if Num <= 0 then
      raiseInfo('List is Null');
  Result.Init_(Self, BI_, EI_);
end;

procedure TBigList<T_>.For_C(BP_, EP_: PQueueStruct; OnFor: TQueneStructFor_C);
var
  i: NativeInt;
  p, N_P: PQueueStruct;
  Aborted: Boolean;
begin
{$IFDEF DEBUG}
  if BP_^.Instance___ <> Self then
      raiseInfo('error');
  if EP_^.Instance___ <> Self then
      raiseInfo('error');
{$ENDIF DEBUG}
  i := 0;
  p := BP_;
  Aborted := False;
  repeat
    N_P := p^.Next;
    OnFor(i, p, Aborted);
    p := N_P;
    inc(i);
  until Aborted or (p = EP_) or (BP_ = EP_) or (i >= FNum);
  if (p = EP_) and (p <> BP_) then
      OnFor(i, p, Aborted);
end;

procedure TBigList<T_>.For_M(BP_, EP_: PQueueStruct; OnFor: TQueneStructFor_M);
var
  i: NativeInt;
  p, N_P: PQueueStruct;
  Aborted: Boolean;
begin
{$IFDEF DEBUG}
  if BP_^.Instance___ <> Self then
      raiseInfo('error');
  if EP_^.Instance___ <> Self then
      raiseInfo('error');
{$ENDIF DEBUG}
  i := 0;
  p := BP_;
  Aborted := False;
  repeat
    N_P := p^.Next;
    OnFor(i, p, Aborted);
    p := N_P;
    inc(i);
  until Aborted or (p = EP_) or (BP_ = EP_) or (i >= FNum);
  if (p = EP_) and (p <> BP_) then
      OnFor(i, p, Aborted);
end;

procedure TBigList<T_>.For_P(BP_, EP_: PQueueStruct; OnFor: TQueneStructFor_P);
var
  i: NativeInt;
  p, N_P: PQueueStruct;
  Aborted: Boolean;
begin
{$IFDEF DEBUG}
  if BP_^.Instance___ <> Self then
      raiseInfo('error');
  if EP_^.Instance___ <> Self then
      raiseInfo('error');
{$ENDIF DEBUG}
  i := 0;
  p := BP_;
  Aborted := False;
  repeat
    N_P := p^.Next;
    OnFor(i, p, Aborted);
    p := N_P;
    inc(i);
  until Aborted or (p = EP_) or (BP_ = EP_) or (i >= FNum);
  if (p = EP_) and (p <> BP_) then
      OnFor(i, p, Aborted);
end;

procedure TBigList<T_>.For_C(OnFor: TQueneStructFor_C);
var
  i: NativeInt;
  p, N_P: PQueueStruct;
  Aborted: Boolean;
begin
  if FNum > 0 then
    begin
      i := 0;
      p := FFirst;
      Aborted := False;
      while (i < FNum) and (not Aborted) do
        begin
          N_P := p^.Next;
          OnFor(i, p, Aborted);
          p := N_P;
          inc(i);
        end;
    end;
end;

procedure TBigList<T_>.For_M(OnFor: TQueneStructFor_M);
var
  i: NativeInt;
  p, N_P: PQueueStruct;
  Aborted: Boolean;
begin
  if FNum > 0 then
    begin
      i := 0;
      p := FFirst;
      Aborted := False;
      while (i < FNum) and (not Aborted) do
        begin
          N_P := p^.Next;
          OnFor(i, p, Aborted);
          p := N_P;
          inc(i);
        end;
    end;
end;

procedure TBigList<T_>.For_P(OnFor: TQueneStructFor_P);
var
  i: NativeInt;
  p, N_P: PQueueStruct;
  Aborted: Boolean;
begin
  if FNum > 0 then
    begin
      i := 0;
      p := FFirst;
      Aborted := False;
      while (i < FNum) and (not Aborted) do
        begin
          N_P := p^.Next;
          OnFor(i, p, Aborted);
          p := N_P;
          inc(i);
        end;
    end;
end;

function TBigList<T_>.ToArray(): TArray_T_;
var
  i: NativeInt;
  p: PQueueStruct;
begin
  SetLength(Result, FNum);
  // copy to order buffer
  if FNum > 0 then
    begin
      i := 0;
      p := FFirst;
      while i < FNum do
        begin
          Result[i] := p^.Data;
          inc(i);
          p := p^.Next;
        end;
    end;
end;

function TBigList<T_>.ToOrder(): TOrder_Data_Pool;
var
  i: NativeInt;
  p: PQueueStruct;
begin
  Result := TOrder_Data_Pool.Create;
  // copy to order buffer
  if FNum > 0 then
    begin
      i := 0;
      p := FFirst;
      while i < FNum do
        begin
          Result.Push(p^.Data);
          inc(i);
          p := p^.Next;
        end;
    end;
end;

procedure TBigList<T_>.Sort_C(Arry_: PQueueArrayStruct; L, R: NativeInt; OnSort: TSort_C);
var
  i, j: NativeInt;
  p: T_;
begin
  if L < R then
    begin
      repeat
        if (R - L) = 1 then
          begin
            if OnSort(Arry_^[L]^.Data, Arry_^[R]^.Data) > 0 then
                TSwap<T_>.Do_(Arry_^[L]^.Data, Arry_^[R]^.Data);
            break;
          end;
        i := L;
        j := R;
        p := Arry_^[(L + R) shr 1]^.Data;
        repeat
          while OnSort(Arry_^[i]^.Data, p) < 0 do
              inc(i);
          while OnSort(Arry_^[j]^.Data, p) > 0 do
              Dec(j);
          if i <= j then
            begin
              if i <> j then
                  TSwap<T_>.Do_(Arry_^[i]^.Data, Arry_^[j]^.Data);
              inc(i);
              Dec(j);
            end;
        until i > j;
        if (j - L) > (R - i) then
          begin
            if i < R then
                Sort_C(Arry_, i, R, OnSort);
            R := j;
          end
        else
          begin
            if L < j then
                Sort_C(Arry_, L, j, OnSort);
            L := i;
          end;
      until L >= R;
    end;
end;

procedure TBigList<T_>.Sort_C(OnSort: TSort_C);
var
  tmp: PQueueArrayStruct;
begin
  if (FEnabled_Sort) and (Num > 1) and (Assigned(OnSort)) then
    begin
      tmp := BuildArrayMemory;
      Sort_C(tmp, 0, Num - 1, OnSort);
      System.FreeMemory(tmp);
    end;
end;

procedure TBigList<T_>.Sort_M(Arry_: PQueueArrayStruct; L, R: NativeInt; OnSort: TSort_M);
var
  i, j: NativeInt;
  p: T_;
begin
  if L < R then
    begin
      repeat
        if (R - L) = 1 then
          begin
            if OnSort(Arry_^[L]^.Data, Arry_^[R]^.Data) > 0 then
                TSwap<T_>.Do_(Arry_^[L]^.Data, Arry_^[R]^.Data);
            break;
          end;
        i := L;
        j := R;
        p := Arry_^[(L + R) shr 1]^.Data;
        repeat
          while OnSort(Arry_^[i]^.Data, p) < 0 do
              inc(i);
          while OnSort(Arry_^[j]^.Data, p) > 0 do
              Dec(j);
          if i <= j then
            begin
              if i <> j then
                  TSwap<T_>.Do_(Arry_^[i]^.Data, Arry_^[j]^.Data);
              inc(i);
              Dec(j);
            end;
        until i > j;
        if (j - L) > (R - i) then
          begin
            if i < R then
                Sort_M(Arry_, i, R, OnSort);
            R := j;
          end
        else
          begin
            if L < j then
                Sort_M(Arry_, L, j, OnSort);
            L := i;
          end;
      until L >= R;
    end;
end;

procedure TBigList<T_>.Sort_M(OnSort: TSort_M);
var
  tmp: PQueueArrayStruct;
begin
  if (FEnabled_Sort) and (Num > 1) and (Assigned(OnSort)) then
    begin
      tmp := BuildArrayMemory;
      Sort_M(tmp, 0, Num - 1, OnSort);
      System.FreeMemory(tmp);
    end;
end;

procedure TBigList<T_>.Sort_P(Arry_: PQueueArrayStruct; L, R: NativeInt; OnSort: TSort_P);
var
  i, j: NativeInt;
  p: T_;
begin
  if L < R then
    begin
      repeat
        if (R - L) = 1 then
          begin
            if OnSort(Arry_^[L]^.Data, Arry_^[R]^.Data) > 0 then
                TSwap<T_>.Do_(Arry_^[L]^.Data, Arry_^[R]^.Data);
            break;
          end;
        i := L;
        j := R;
        p := Arry_^[(L + R) shr 1]^.Data;
        repeat
          while OnSort(Arry_^[i]^.Data, p) < 0 do
              inc(i);
          while OnSort(Arry_^[j]^.Data, p) > 0 do
              Dec(j);
          if i <= j then
            begin
              if i <> j then
                  TSwap<T_>.Do_(Arry_^[i]^.Data, Arry_^[j]^.Data);
              inc(i);
              Dec(j);
            end;
        until i > j;
        if (j - L) > (R - i) then
          begin
            if i < R then
                Sort_P(Arry_, i, R, OnSort);
            R := j;
          end
        else
          begin
            if L < j then
                Sort_P(Arry_, L, j, OnSort);
            L := i;
          end;
      until L >= R;
    end;
end;

procedure TBigList<T_>.Sort_P(OnSort: TSort_P);
var
  tmp: PQueueArrayStruct;
begin
  if (FEnabled_Sort) and (Num > 1) and (Assigned(OnSort)) then
    begin
      tmp := BuildArrayMemory;
      Sort_P(tmp, 0, Num - 1, OnSort);
      System.FreeMemory(tmp);
    end;
end;

function TBigList<T_>.BuildArrayMemory: PQueueArrayStruct;
var
  i: NativeInt;
  p: PQueueStruct;
  tmp: PPQueueStruct;
begin
  Result := nil;
  // copy to order buffer
  if FNum > 0 then
    begin
      Result := System.GetMemory(DeltaStep(SizeOf(PQueueStruct) * FNum, 8));
      i := 0;
      p := FFirst;
      tmp := PPQueueStruct(Result);
      while i < FNum do
        begin
          tmp^ := p;
          inc(tmp);
          inc(i);
          p := p^.Next;
        end;
    end;
end;

function TBigList<T_>.CheckList: PQueueArrayStruct;
begin
  // check change
  if FChanged then
    begin
      if FList <> nil then
        begin
          System.FreeMemory(FList);
          FList := nil;
        end;
      FChanged := False;
    end;

  if FList = nil then
      FList := BuildArrayMemory();

  Result := PQueueArrayStruct(FList);
end;

function TBigList<T_>.GetList(const Index: NativeInt): PQueueStruct;
begin
  if (index >= 0) and (index < FNum) then
    begin
      Result := PPQueueStruct(GetOffset(CheckList(), SizeOf(PQueueStruct) * index))^;
    end
  else
      raiseInfo('error');
end;

procedure TBigList<T_>.SetList(const Index: NativeInt; const Value: PQueueStruct);
begin
  if (index >= 0) and (index < FNum) then
    begin
      PPQueueStruct(GetOffset(CheckList(), SizeOf(PQueueStruct) * index))^ := Value;
    end
  else
      raiseInfo('error');
end;

function TBigList<T_>.GetItems(const Index: NativeInt): T_;
begin
  if (index >= 0) and (index < FNum) then
    begin
      Result := PPQueueStruct(GetOffset(CheckList(), SizeOf(PQueueStruct) * index))^^.Data;
    end
  else
      raiseInfo('error');
end;

procedure TBigList<T_>.SetItems(const Index: NativeInt; const Value: T_);
begin
  if (index >= 0) and (index < FNum) then
    begin
      PPQueueStruct(GetOffset(CheckList(), SizeOf(PQueueStruct) * index))^^.Data := Value;
    end
  else
      raiseInfo('error');
end;

class function TBigList<T_>.Null_Data: T_;
begin
  FillPtr(@Result, SizeOf(T_), 0);
end;

// *****************************************************************************************************************

procedure TCritical_BigList<T_>.TRepeat___.Init_(Instance_: T___);
begin
  // Begin Index
  BI___ := 0;
  // End Index
  EI___ := Instance_.Num - 1;
  // Current index
  I___ := 0;
  Instance___ := Instance_;
  p___ := Instance___.First;
  while I___ < BI___ do
    begin
      p___ := p___^.Next;
      inc(I___);
    end;
  Is_Discard___ := False;
end;

procedure TCritical_BigList<T_>.TRepeat___.Init_(Instance_: T___; BI_, EI_: NativeInt);
begin
  // Begin Index
  BI___ := BI_;
  // End Index
  EI___ := EI_;
  // check
  if BI___ > EI___ then
      TSwap<NativeInt>.Do_(BI___, EI___);
  // Current index
  I___ := 0;
  Instance___ := Instance_;
  p___ := Instance___.First;
  while I___ < BI___ do
    begin
      p___ := p___^.Next;
      inc(I___);
    end;
  Is_Discard___ := False;
end;

procedure TCritical_BigList<T_>.TRepeat___.Discard;
begin
  Is_Discard___ := True;
end;

function TCritical_BigList<T_>.TRepeat___.Next: Boolean;
begin
  Result := False;
  if I___ > EI___ then
    begin
      p___ := nil;
      exit;
    end;
  p___ := p___^.Next;
  Result := I___ < EI___;
  if Is_Discard___ then
    begin
      Is_Discard___ := False;
      Instance___.Remove_P(p___^.Prev, False); // Remove_P is UnLock
      Dec(EI___);
    end
  else
      inc(I___);
end;

procedure TCritical_BigList<T_>.TInvert_Repeat___.Init_(Instance_: T___);
begin
  // Begin Index
  BI___ := Instance_.Num - 1;
  // End Index
  EI___ := 0;
  // Current index
  I___ := Instance_.Num - 1;
  Instance___ := Instance_;
  p___ := Instance___.Last;
  while I___ > BI___ do
    begin
      p___ := p___^.Prev;
      Dec(I___);
    end;
  Is_Discard___ := False;
end;

procedure TCritical_BigList<T_>.TInvert_Repeat___.Init_(Instance_: T___; BI_, EI_: NativeInt);
begin
  // Begin Index
  BI___ := BI_;
  // End Index
  EI___ := EI_;
  // check
  if BI___ < EI___ then
      TSwap<NativeInt>.Do_(BI___, EI___);
  // Current index
  I___ := Instance_.Num - 1;
  Instance___ := Instance_;
  p___ := Instance___.Last;
  while I___ > BI___ do
    begin
      p___ := p___^.Prev;
      Dec(I___);
    end;
  Is_Discard___ := False;
end;

procedure TCritical_BigList<T_>.TInvert_Repeat___.Discard;
begin
  Is_Discard___ := True;
end;

function TCritical_BigList<T_>.TInvert_Repeat___.Prev: Boolean;
begin
  Result := False;
  if I___ < EI___ then
    begin
      p___ := nil;
      exit;
    end;
  p___ := p___^.Prev;
  Result := I___ > EI___;
  if Is_Discard___ then
    begin
      Is_Discard___ := False;
      Instance___.Remove_P(p___^.Next, False); // Remove_P is UnLock
      Dec(BI___);
    end;
  Dec(I___);
end;

procedure TCritical_BigList<T_>.DoInternalFree(p: PQueueStruct);
begin
{$IFDEF DEBUG}
  if p^.Instance___ <> Self then
      raiseInfo('error');
{$ENDIF DEBUG}
  try
    DoFree(p^.Data);
    Dispose(p);
  except
  end;
end;

function TCritical_BigList<T_>.Get_Critical__: TCritical;
begin
  if FCritical__ = nil then
      FCritical__ := TCritical.Create('TCritical_BigList.FCritical__');
  Result := FCritical__;
end;

constructor TCritical_BigList<T_>.Create;
begin
  inherited Create;
  FCritical__ := nil;
  FRecycle_Pool__ := nil;
  FFirst := nil;
  FLast := nil;
  FNum := 0;
  FOnAdd := nil;
  FOnFree := nil;
  FOnFree_For_Pair_Tool := nil;
  FEnabled_Sort := True;
  FChanged := False;
  FList := nil;
end;

destructor TCritical_BigList<T_>.Destroy;
begin
  Clear;
  DisposeObjectAndNil(FCritical__);
  inherited Destroy;
end;

procedure TCritical_BigList<T_>.DoFree(var Data: T_);
begin
  if Assigned(FOnFree_For_Pair_Tool) then
      FOnFree_For_Pair_Tool(Data);
  if Assigned(FOnFree) then
      FOnFree(Data);
end;

procedure TCritical_BigList<T_>.DoAdd(var Data: T_);
begin
  if Assigned(FOnAdd) then
      FOnAdd(Data);
end;

function TCritical_BigList<T_>.CompareData(const Data_1, Data_2: T_): Boolean;
begin
  Result := CompareMemory(@Data_1, @Data_2, SizeOf(T_));
end;

procedure TCritical_BigList<T_>.Lock;
begin
  Critical__.Lock;
end;

procedure TCritical_BigList<T_>.UnLock;
begin
  Critical__.UnLock;
end;

function TCritical_BigList<T_>.Get_Recycle_Pool_Num: NativeInt;
begin
  if FRecycle_Pool__ <> nil then
      Result := FRecycle_Pool__.Num
  else
      Result := 0;
end;

procedure TCritical_BigList<T_>.Push_To_Recycle_Pool(p: PQueueStruct);
begin
{$IFDEF DEBUG}
  if p^.Instance___ <> Self then
      raiseInfo('error');
{$ENDIF DEBUG}
  if FRecycle_Pool__ = nil then
      FRecycle_Pool__ := TRecycle_Pool__.Create;

  if not p^.Recycle___ then
    begin
      p^.Recycle___ := True;
      FRecycle_Pool__.Push(p);
    end;
end;

procedure TCritical_BigList<T_>.Free_Recycle_Pool(Lock_: Boolean);
begin
  if FRecycle_Pool__ <> nil then
    begin
      while FRecycle_Pool__.Num > 0 do
        begin
          Remove_P(FRecycle_Pool__.First^.Data, Lock_);
          FRecycle_Pool__.Next;
        end;
      FRecycle_Pool__.Free;
      FRecycle_Pool__ := nil;
    end;
end;

procedure TCritical_BigList<T_>.Free_Recycle_Pool;
begin
  Free_Recycle_Pool(False);
end;

procedure TCritical_BigList<T_>.Clear;
var
  i: NativeInt;
  p, N_P: PQueueStruct;
begin
  if FRecycle_Pool__ <> nil then
    begin
      FRecycle_Pool__.Free;
      FRecycle_Pool__ := nil;
    end;
  Critical__.Lock;
  if FNum > 0 then
    begin
      i := 0;
      p := FFirst;
      while i < FNum do
        begin
          N_P := p^.Next;
          DoInternalFree(p);
          inc(i);
          p := N_P;
        end;
    end;
  FNum := 0;
  if FList <> nil then
    begin
      System.FreeMemory(FList);
      FList := nil;
    end;
  FFirst := nil;
  FLast := nil;
  FChanged := True;
  Critical__.UnLock;
end;

procedure TCritical_BigList<T_>.Next(Lock_: Boolean);
begin
  if FFirst <> nil then
      Remove_P(FFirst, Lock_);
end;

procedure TCritical_BigList<T_>.Next;
begin
  if FFirst <> nil then
      Remove_P(FFirst);
end;

function TCritical_BigList<T_>.Add(const Data: T_): PQueueStruct;
var
  p: PQueueStruct;
begin
  Critical__.Lock;

  new(p);
  p^.Data := Data;
  if (FFirst = nil) or (FLast = nil) then
    begin
      FFirst := p;
      FLast := p;
      p^.Prev := p;
      p^.Next := p;
    end
  else if FFirst = FLast then
    begin
      FLast := p;
      FFirst^.Prev := FLast;
      FFirst^.Next := FLast;
      FLast^.Next := FFirst;
      FLast^.Prev := FFirst;
    end
  else
    begin
      FFirst^.Prev := p;
      FLast^.Next := p;
      p^.Next := FFirst;
      p^.Prev := FLast;
      FLast := p;
    end;
  p^.Instance___ := Self;
  p^.Recycle___ := False;
  inc(FNum);
  FChanged := True;
  Critical__.UnLock;
  Result := p;
  DoAdd(p^.Data);
end;

procedure TCritical_BigList<T_>.AddL(L_: T___);
begin
  L_.Lock;
  if L_.Num > 0 then
    with L_.Repeat_ do
      repeat
          Add(Queue^.Data);
      until not Next;
  L_.UnLock;
end;

function TCritical_BigList<T_>.Add_Null(Lock_: Boolean): PQueueStruct;
var
  p: PQueueStruct;
begin
  if Lock_ then
      Critical__.Lock;
  new(p);
  if (FFirst = nil) or (FLast = nil) then
    begin
      FFirst := p;
      FLast := p;
      p^.Prev := p;
      p^.Next := p;
    end
  else if FFirst = FLast then
    begin
      FLast := p;
      FFirst^.Prev := FLast;
      FFirst^.Next := FLast;
      FLast^.Next := FFirst;
      FLast^.Prev := FFirst;
    end
  else
    begin
      FFirst^.Prev := p;
      FLast^.Next := p;
      p^.Next := FFirst;
      p^.Prev := FLast;
      FLast := p;
    end;
  p^.Instance___ := Self;
  p^.Recycle___ := False;
  inc(FNum);
  FChanged := True;
  if Lock_ then
      Critical__.UnLock;
  Result := p;
  DoAdd(p^.Data);
end;

function TCritical_BigList<T_>.Add_Null(): PQueueStruct;
begin
  Result := Add_Null(True);
end;

function TCritical_BigList<T_>.Insert(const Data: T_; To_: PQueueStruct): PQueueStruct;
var
  p: PQueueStruct;
  P_P: PQueueStruct;
begin
{$IFDEF DEBUG}
  if To_^.Instance___ <> Self then
      raiseInfo('error');
{$ENDIF DEBUG}
  Critical__.Lock;
  new(p);
  p^.Data := Data;

  if FFirst = To_ then
      FFirst := p;
  P_P := To_^.Prev;
  if P_P^.Next = To_ then
      P_P^.Next := p;
  if To_^.Next = To_ then
      To_^.Next := p;
  To_^.Prev := p;
  p^.Prev := P_P;
  p^.Next := To_;
  p^.Instance___ := Self;
  p^.Recycle___ := False;
  inc(FNum);
  FChanged := True;
  Critical__.UnLock;
  Result := p;
  DoAdd(p^.Data);
end;

function TCritical_BigList<T_>.CopyFrom(Source_: T___): NativeInt;
begin
  Result := Source_.Num;
  if Result > 0 then
    with Source_.Repeat_ do
      repeat
          Add(Queue^.Data);
      until not Next;
end;

procedure TCritical_BigList<T_>.Remove_P(p: PQueueStruct; Lock_: Boolean);
var
  P_P, N_P: PQueueStruct;
begin
{$IFDEF DEBUG}
  if p^.Instance___ <> Self then
      raiseInfo('error');
{$ENDIF DEBUG}
  if Lock_ then
      Critical__.Lock;

  P_P := p^.Prev;
  N_P := p^.Next;
  if p = FFirst then
      FFirst := N_P;
  if p = FLast then
      FLast := P_P;
  if (FFirst = FLast) and (FLast = p) then
    begin
      FFirst := nil;
      FLast := nil;
      FNum := 0;
    end
  else
    begin
      P_P^.Next := N_P;
      N_P^.Prev := P_P;
      Dec(FNum);
    end;
  FChanged := True;

  if Lock_ then
      Critical__.UnLock;

  DoInternalFree(p);
end;

procedure TCritical_BigList<T_>.Remove_P(p: PQueueStruct);
begin
  Remove_P(p, True);
end;

procedure TCritical_BigList<T_>.Remove_T(const Data: T_);
begin
  Remove_Data(Data);
end;

procedure TCritical_BigList<T_>.Move_Before(p, To_: PQueueStruct);
var
  P_P, N_P: PQueueStruct;
  tmp: T_;
begin
{$IFDEF DEBUG}
  if p^.Instance___ <> Self then
      raiseInfo('error');
  if To_^.Instance___ <> Self then
      raiseInfo('error');
{$ENDIF DEBUG}
  if p = To_ then
      exit;

  Critical__.Lock;
  // step 1: remove
  P_P := p^.Prev;
  N_P := p^.Next;
  if p = FFirst then
      FFirst := N_P;
  if p = FLast then
      FLast := P_P;
  if (FFirst = FLast) and (FLast = p) then
    begin
      FFirst := nil;
      FLast := nil;
    end
  else
    begin
      P_P^.Next := N_P;
      N_P^.Prev := P_P;
    end;

  // step 2: insert
  if FFirst = To_ then
      FFirst := p;
  P_P := To_^.Prev;
  if P_P^.Next = To_ then
      P_P^.Next := p;
  if To_^.Next = To_ then
      To_^.Next := p;
  To_^.Prev := p;
  p^.Prev := P_P;
  p^.Next := To_;

  FChanged := True;
  Critical__.UnLock;
end;

procedure TCritical_BigList<T_>.MoveToFirst(p: PQueueStruct);
begin
  Move_Before(p, First);
end;

procedure TCritical_BigList<T_>.MoveToLast(p: PQueueStruct);
var
  P_P, N_P: PQueueStruct;
  tmp: T_;
begin
{$IFDEF DEBUG}
  if p^.Instance___ <> Self then
      raiseInfo('error');
{$ENDIF DEBUG}
  if p = Last then
      exit;

  Critical__.Lock;
  // step 1: remove
  P_P := p^.Prev;
  N_P := p^.Next;
  if p = FFirst then
      FFirst := N_P;
  if p = FLast then
      FLast := P_P;
  if (FFirst = FLast) and (FLast = p) then
    begin
      FFirst := nil;
      FLast := nil;
    end
  else
    begin
      P_P^.Next := N_P;
      N_P^.Prev := P_P;
    end;

  // step 2: append
  if (FFirst = nil) or (FLast = nil) then
    begin
      FFirst := p;
      FLast := p;
      p^.Prev := p;
      p^.Next := p;
    end
  else if FFirst = FLast then
    begin
      FLast := p;
      FFirst^.Prev := FLast;
      FFirst^.Next := FLast;
      FLast^.Next := FFirst;
      FLast^.Prev := FFirst;
    end
  else
    begin
      FFirst^.Prev := p;
      FLast^.Next := p;
      p^.Next := FFirst;
      p^.Prev := FLast;
      FLast := p;
    end;

  FChanged := True;
  Critical__.UnLock;
end;

procedure TCritical_BigList<T_>.Exchange(p1, p2: PQueueStruct);
var
  tmp: T_;
begin
{$IFDEF DEBUG}
  if p1^.Instance___ <> Self then
      raiseInfo('error');
  if p2^.Instance___ <> Self then
      raiseInfo('error');
{$ENDIF DEBUG}
  if p1 = p2 then
      exit;
  Critical__.Lock;
  tmp := p1^.Data;
  p1^.Data := p2^.Data;
  p2^.Data := tmp;
  Critical__.UnLock;
end;

function TCritical_BigList<T_>.Found(p1: PQueueStruct): NativeInt;
var
  i: NativeInt;
  p: PQueueStruct;
begin
  Result := -1;
  Critical__.Lock;
  try
    if FNum > 0 then
      begin
        i := 0;
        p := FFirst;
        while i < FNum do
          begin
            if p = p1 then
              begin
                Result := i; exit;
              end;
            inc(i);
            p := p^.Next;
          end;
      end;
  finally
      Critical__.UnLock;
  end;
end;

function TCritical_BigList<T_>.Find_Data(const Data: T_): PQueueStruct;
var
  i: NativeInt;
  p: PQueueStruct;
begin
  Result := nil;
  Critical__.Lock;
  try
    if FNum > 0 then
      begin
        i := 0;
        p := FFirst;
        while i < FNum do
          begin
            if CompareData(Data, p^.Data) then
              begin
                Result := p; exit;
              end;
            inc(i);
            p := p^.Next;
          end;
      end;
  finally
      Critical__.UnLock;
  end;
end;

function TCritical_BigList<T_>.Find_Data_Ptr(const Data_Ptr: P_): PQueueStruct;
var
  i: NativeInt;
  p: PQueueStruct;
begin
  Result := nil;
  Critical__.Lock;
  try
    if FNum > 0 then
      begin
        i := 0;
        p := FFirst;
        while i < FNum do
          begin
            if Data_Ptr = @p^.Data then
              begin
                Result := p; exit;
              end;
            inc(i);
            p := p^.Next;
          end;
      end;
  finally
      Critical__.UnLock;
  end;
end;

function TCritical_BigList<T_>.Search_Data_As_Array(const Data: T_): TArray_T_;
var
  L: TOrder_Data_Pool;
  i: Integer;
begin
  L := Search_Data_As_Order(Data);
  SetLength(Result, L.Num);
  i := 0;
  while L.Num > 0 do
    begin
      Result[i] := L.First^.Data;
      L.Next;
    end;
  DisposeObject(L);
end;

function TCritical_BigList<T_>.Search_Data_As_Order(const Data: T_): TOrder_Data_Pool;
var
  i: NativeInt;
  p: PQueueStruct;
begin
  Result := TOrder_Data_Pool.Create;
  Critical__.Lock;
  try
    if FNum > 0 then
      begin
        i := 0;
        p := FFirst;
        while i < FNum do
          begin
            if CompareData(Data, p^.Data) then
                Result.Push(p^.Data);
            inc(i);
            p := p^.Next;
          end;
      end;
  finally
      Critical__.UnLock;
  end;
end;

function TCritical_BigList<T_>.Remove_Data(const Data: T_): Integer;
var
  i: NativeInt;
  p: PQueueStruct;
begin
  Critical__.Lock;
  try
    if FNum > 0 then
      begin
        i := 0;
        p := FFirst;
        while i < FNum do
          begin
            if CompareData(Data, p^.Data) then
                Push_To_Recycle_Pool(p);
            inc(i);
            p := p^.Next;
          end;
      end;
    Result := FRecycle_Pool__.Num;
    Free_Recycle_Pool();
  finally
      Critical__.UnLock;
  end;
end;

function TCritical_BigList<T_>.Repeat_(): TRepeat___;
begin
  if Num <= 0 then
      raiseInfo('List is Null');
  Result.Init_(Self);
end;

function TCritical_BigList<T_>.Repeat_(BI_, EI_: NativeInt): TRepeat___;
begin
  if Num <= 0 then
      raiseInfo('List is Null');
  Result.Init_(Self, BI_, EI_);
end;

function TCritical_BigList<T_>.Invert_Repeat_(): TInvert_Repeat___;
begin
  if Num <= 0 then
      raiseInfo('List is Null');
  Result.Init_(Self);
end;

function TCritical_BigList<T_>.Invert_Repeat_(BI_, EI_: NativeInt): TInvert_Repeat___;
begin
  if Num <= 0 then
      raiseInfo('List is Null');
  Result.Init_(Self, BI_, EI_);
end;

procedure TCritical_BigList<T_>.For_C(BP_, EP_: PQueueStruct; OnFor: TQueneStructFor_C);
var
  i: NativeInt;
  p, N_P: PQueueStruct;
  Aborted: Boolean;
begin
{$IFDEF DEBUG}
  if BP_^.Instance___ <> Self then
      raiseInfo('error');
  if EP_^.Instance___ <> Self then
      raiseInfo('error');
{$ENDIF DEBUG}
  Critical__.Lock;
  try
    i := 0;
    p := BP_;
    Aborted := False;
    repeat
      N_P := p^.Next;
      OnFor(i, p, Aborted);
      p := N_P;
      inc(i);
    until Aborted or (p = EP_) or (BP_ = EP_) or (i >= FNum);
    if (p = EP_) and (p <> BP_) then
        OnFor(i, p, Aborted);
  finally
      Critical__.UnLock;
  end;
end;

procedure TCritical_BigList<T_>.For_M(BP_, EP_: PQueueStruct; OnFor: TQueneStructFor_M);
var
  i: NativeInt;
  p, N_P: PQueueStruct;
  Aborted: Boolean;
begin
{$IFDEF DEBUG}
  if BP_^.Instance___ <> Self then
      raiseInfo('error');
  if EP_^.Instance___ <> Self then
      raiseInfo('error');
{$ENDIF DEBUG}
  Critical__.Lock;
  try
    i := 0;
    p := BP_;
    Aborted := False;
    repeat
      N_P := p^.Next;
      OnFor(i, p, Aborted);
      p := N_P;
      inc(i);
    until Aborted or (p = EP_) or (BP_ = EP_) or (i >= FNum);
    if (p = EP_) and (p <> BP_) then
        OnFor(i, p, Aborted);
  finally
      Critical__.UnLock;
  end;
end;

procedure TCritical_BigList<T_>.For_P(BP_, EP_: PQueueStruct; OnFor: TQueneStructFor_P);
var
  i: NativeInt;
  p, N_P: PQueueStruct;
  Aborted: Boolean;
begin
{$IFDEF DEBUG}
  if BP_^.Instance___ <> Self then
      raiseInfo('error');
  if EP_^.Instance___ <> Self then
      raiseInfo('error');
{$ENDIF DEBUG}
  Critical__.Lock;
  try
    i := 0;
    p := BP_;
    Aborted := False;
    repeat
      N_P := p^.Next;
      OnFor(i, p, Aborted);
      p := N_P;
      inc(i);
    until Aborted or (p = EP_) or (BP_ = EP_) or (i >= FNum);
    if (p = EP_) and (p <> BP_) then
        OnFor(i, p, Aborted);
  finally
      Critical__.UnLock;
  end;
end;

procedure TCritical_BigList<T_>.For_C(OnFor: TQueneStructFor_C);
var
  i: NativeInt;
  p, N_P: PQueueStruct;
  Aborted: Boolean;
begin
  if FNum > 0 then
    begin
      Critical__.Lock;
      try
        i := 0;
        p := FFirst;
        Aborted := False;
        while (i < FNum) and (not Aborted) do
          begin
            N_P := p^.Next;
            OnFor(i, p, Aborted);
            p := N_P;
            inc(i);
          end;
      finally
          Critical__.UnLock;
      end;
    end;
end;

procedure TCritical_BigList<T_>.For_M(OnFor: TQueneStructFor_M);
var
  i: NativeInt;
  p, N_P: PQueueStruct;
  Aborted: Boolean;
begin
  if FNum > 0 then
    begin
      Critical__.Lock;
      try
        i := 0;
        p := FFirst;
        Aborted := False;
        while (i < FNum) and (not Aborted) do
          begin
            N_P := p^.Next;
            OnFor(i, p, Aborted);
            p := N_P;
            inc(i);
          end;
      finally
          Critical__.UnLock;
      end;
    end;
end;

procedure TCritical_BigList<T_>.For_P(OnFor: TQueneStructFor_P);
var
  i: NativeInt;
  p, N_P: PQueueStruct;
  Aborted: Boolean;
begin
  if FNum > 0 then
    begin
      Critical__.Lock;
      try
        i := 0;
        p := FFirst;
        Aborted := False;
        while (i < FNum) and (not Aborted) do
          begin
            N_P := p^.Next;
            OnFor(i, p, Aborted);
            p := N_P;
            inc(i);
          end;
      finally
          Critical__.UnLock;
      end;
    end;
end;

function TCritical_BigList<T_>.ToArray(): TArray_T_;
var
  i: NativeInt;
  p: PQueueStruct;
begin
  Critical__.Lock;
  try
    SetLength(Result, FNum);
    // copy to order buffer
    if FNum > 0 then
      begin
        i := 0;
        p := FFirst;
        while i < FNum do
          begin
            Result[i] := p^.Data;
            inc(i);
            p := p^.Next;
          end;
      end;
  finally
      Critical__.UnLock;
  end;
end;

function TCritical_BigList<T_>.ToOrder(): TOrder_Data_Pool;
var
  i: NativeInt;
  p: PQueueStruct;
begin
  Result := TOrder_Data_Pool.Create;
  Critical__.Lock;
  try
    // copy to order buffer
    if FNum > 0 then
      begin
        i := 0;
        p := FFirst;
        while i < FNum do
          begin
            Result.Push(p^.Data);
            inc(i);
            p := p^.Next;
          end;
      end;
  finally
      Critical__.UnLock;
  end;
end;

procedure TCritical_BigList<T_>.Sort_C(Arry_: PQueueArrayStruct; L, R: NativeInt; OnSort: TSort_C);
var
  i, j: NativeInt;
  p: T_;
begin
  if L < R then
    begin
      repeat
        if (R - L) = 1 then
          begin
            if OnSort(Arry_^[L]^.Data, Arry_^[R]^.Data) > 0 then
                TSwap<T_>.Do_(Arry_^[L]^.Data, Arry_^[R]^.Data);
            break;
          end;
        i := L;
        j := R;
        p := Arry_^[(L + R) shr 1]^.Data;
        repeat
          while OnSort(Arry_^[i]^.Data, p) < 0 do
              inc(i);
          while OnSort(Arry_^[j]^.Data, p) > 0 do
              Dec(j);
          if i <= j then
            begin
              if i <> j then
                  TSwap<T_>.Do_(Arry_^[i]^.Data, Arry_^[j]^.Data);
              inc(i);
              Dec(j);
            end;
        until i > j;
        if (j - L) > (R - i) then
          begin
            if i < R then
                Sort_C(Arry_, i, R, OnSort);
            R := j;
          end
        else
          begin
            if L < j then
                Sort_C(Arry_, L, j, OnSort);
            L := i;
          end;
      until L >= R;
    end;
end;

procedure TCritical_BigList<T_>.Sort_C(OnSort: TSort_C);
var
  tmp: PQueueArrayStruct;
begin
  if (FEnabled_Sort) and (Num > 1) and (Assigned(OnSort)) then
    begin
      Critical__.Lock;
      tmp := BuildArrayMemory;
      Sort_C(tmp, 0, Num - 1, OnSort);
      System.FreeMemory(tmp);
      Critical__.UnLock;
    end;
end;

procedure TCritical_BigList<T_>.Sort_M(Arry_: PQueueArrayStruct; L, R: NativeInt; OnSort: TSort_M);
var
  i, j: NativeInt;
  p: T_;
begin
  if L < R then
    begin
      repeat
        if (R - L) = 1 then
          begin
            if OnSort(Arry_^[L]^.Data, Arry_^[R]^.Data) > 0 then
                TSwap<T_>.Do_(Arry_^[L]^.Data, Arry_^[R]^.Data);
            break;
          end;
        i := L;
        j := R;
        p := Arry_^[(L + R) shr 1]^.Data;
        repeat
          while OnSort(Arry_^[i]^.Data, p) < 0 do
              inc(i);
          while OnSort(Arry_^[j]^.Data, p) > 0 do
              Dec(j);
          if i <= j then
            begin
              if i <> j then
                  TSwap<T_>.Do_(Arry_^[i]^.Data, Arry_^[j]^.Data);
              inc(i);
              Dec(j);
            end;
        until i > j;
        if (j - L) > (R - i) then
          begin
            if i < R then
                Sort_M(Arry_, i, R, OnSort);
            R := j;
          end
        else
          begin
            if L < j then
                Sort_M(Arry_, L, j, OnSort);
            L := i;
          end;
      until L >= R;
    end;
end;

procedure TCritical_BigList<T_>.Sort_M(OnSort: TSort_M);
var
  tmp: PQueueArrayStruct;
begin
  if (FEnabled_Sort) and (Num > 1) and (Assigned(OnSort)) then
    begin
      Critical__.Lock;
      tmp := BuildArrayMemory;
      Sort_M(tmp, 0, Num - 1, OnSort);
      System.FreeMemory(tmp);
      Critical__.UnLock;
    end;
end;

procedure TCritical_BigList<T_>.Sort_P(Arry_: PQueueArrayStruct; L, R: NativeInt; OnSort: TSort_P);
var
  i, j: NativeInt;
  p: T_;
begin
  if L < R then
    begin
      repeat
        if (R - L) = 1 then
          begin
            if OnSort(Arry_^[L]^.Data, Arry_^[R]^.Data) > 0 then
                TSwap<T_>.Do_(Arry_^[L]^.Data, Arry_^[R]^.Data);
            break;
          end;
        i := L;
        j := R;
        p := Arry_^[(L + R) shr 1]^.Data;
        repeat
          while OnSort(Arry_^[i]^.Data, p) < 0 do
              inc(i);
          while OnSort(Arry_^[j]^.Data, p) > 0 do
              Dec(j);
          if i <= j then
            begin
              if i <> j then
                  TSwap<T_>.Do_(Arry_^[i]^.Data, Arry_^[j]^.Data);
              inc(i);
              Dec(j);
            end;
        until i > j;
        if (j - L) > (R - i) then
          begin
            if i < R then
                Sort_P(Arry_, i, R, OnSort);
            R := j;
          end
        else
          begin
            if L < j then
                Sort_P(Arry_, L, j, OnSort);
            L := i;
          end;
      until L >= R;
    end;
end;

procedure TCritical_BigList<T_>.Sort_P(OnSort: TSort_P);
var
  tmp: PQueueArrayStruct;
begin
  if (FEnabled_Sort) and (Num > 1) and (Assigned(OnSort)) then
    begin
      Critical__.Lock;
      tmp := BuildArrayMemory;
      Sort_P(tmp, 0, Num - 1, OnSort);
      System.FreeMemory(tmp);
      Critical__.UnLock;
    end;
end;

function TCritical_BigList<T_>.BuildArrayMemory: PQueueArrayStruct;
var
  i: NativeInt;
  p: PQueueStruct;
  tmp: PPQueueStruct;
begin
  Result := nil;
  // copy to order buffer
  if FNum > 0 then
    begin
      Result := System.GetMemory(DeltaStep(SizeOf(PQueueStruct) * FNum, 8));
      i := 0;
      p := FFirst;
      tmp := PPQueueStruct(Result);
      while i < FNum do
        begin
          tmp^ := p;
          inc(tmp);
          inc(i);
          p := p^.Next;
        end;
    end;
end;

function TCritical_BigList<T_>.CheckList: PQueueArrayStruct;
begin
  // check change
  Critical__.Lock;
  try
    if FChanged then
      begin
        if FList <> nil then
          begin
            System.FreeMemory(FList);
            FList := nil;
          end;
        FChanged := False;
      end;

    if FList = nil then
        FList := BuildArrayMemory();

    Result := PQueueArrayStruct(FList);
  finally
      Critical__.UnLock;
  end;
end;

function TCritical_BigList<T_>.GetList(const Index: NativeInt): PQueueStruct;
begin
  if (index >= 0) and (index < FNum) then
    begin
      Critical__.Lock;
      try
          Result := PPQueueStruct(GetOffset(CheckList(), SizeOf(PQueueStruct) * index))^;
      finally
          Critical__.UnLock;
      end;
    end
  else
      raiseInfo('error');
end;

procedure TCritical_BigList<T_>.SetList(const Index: NativeInt; const Value: PQueueStruct);
begin
  if (index >= 0) and (index < FNum) then
    begin
      Critical__.Lock;
      try
          PPQueueStruct(GetOffset(CheckList(), SizeOf(PQueueStruct) * index))^ := Value;
      finally
          Critical__.UnLock;
      end;
    end
  else
      raiseInfo('error');
end;

function TCritical_BigList<T_>.GetItems(const Index: NativeInt): T_;
begin
  if (index >= 0) and (index < FNum) then
    begin
      Result := PPQueueStruct(GetOffset(CheckList(), SizeOf(PQueueStruct) * index))^^.Data;
    end
  else
      raiseInfo('error');
end;

procedure TCritical_BigList<T_>.SetItems(const Index: NativeInt; const Value: T_);
begin
  if (index >= 0) and (index < FNum) then
    begin
      PPQueueStruct(GetOffset(CheckList(), SizeOf(PQueueStruct) * index))^^.Data := Value;
    end
  else
      raiseInfo('error');
end;

class function TCritical_BigList<T_>.Null_Data: T_;
begin
  FillPtr(@Result, SizeOf(T_), 0);
end;

constructor TBig_Object_List<T_>.Create(AutoFreeObject_: Boolean);
begin
  inherited Create;
  AutoFreeObject := AutoFreeObject_;
end;

procedure TBig_Object_List<T_>.DoFree(var Data: T_);
begin
  inherited DoFree(Data);
  if AutoFreeObject then
      DisposeObjectAndNil(Data);
end;

constructor TCritical_Big_Object_List<T_>.Create(AutoFreeObject_: Boolean);
begin
  inherited Create;
  AutoFreeObject := AutoFreeObject_;
end;

procedure TCritical_Big_Object_List<T_>.DoFree(var Data: T_);
begin
  inherited DoFree(Data);
  if AutoFreeObject then
      DisposeObjectAndNil(Data)
end;

procedure TOrderStruct<T_>.DoInternalFree(const p: POrderStruct);
begin
  try
    DoFree(p^.Data);
    Dispose(p);
  except
  end;
end;

constructor TOrderStruct<T_>.Create;
begin
  inherited Create;
  FFirst := nil;
  FLast := nil;
  FNum := 0;
  FOnFreeOrderStruct := nil;
end;

destructor TOrderStruct<T_>.Destroy;
begin
  Clear;
  inherited Destroy;
end;

procedure TOrderStruct<T_>.DoFree(var Data: T_);
begin
  if Assigned(FOnFreeOrderStruct) then
      FOnFreeOrderStruct(Data);
end;

procedure TOrderStruct<T_>.SwapInstance(source: TOrderStruct<T_>);
var
  FFirst_: POrderStruct;
  FLast_: POrderStruct;
  FNum_: NativeInt;
begin
  FFirst_ := FFirst;
  FLast_ := FLast;
  FNum_ := FNum;

  FFirst := source.FFirst;
  FLast := source.FLast;
  FNum := source.FNum;

  source.FFirst := FFirst_;
  source.FLast := FLast_;
  source.FNum := FNum_;
end;

procedure TOrderStruct<T_>.Clear;
var
  p, N_P: POrderStruct;
begin
  p := FFirst;
  while p <> nil do
    begin
      N_P := p^.Next;
      try
          DoInternalFree(p);
      except
      end;
      p := N_P;
    end;
  FFirst := nil;
  FLast := nil;
  FNum := 0;
end;

procedure TOrderStruct<T_>.Next;
var
  N_P: POrderStruct;
begin
  if FFirst <> nil then
    begin
      N_P := FFirst^.Next;
      try
          DoInternalFree(FFirst);
      except
      end;
      FFirst := N_P;
      if FFirst = nil then
          FLast := nil;
      Dec(FNum);
    end;
end;

function TOrderStruct<T_>.Push(const Data: T_): POrderStruct;
var
  p: POrderStruct;
begin
  new(p);
  p^.Data := Data;
  p^.Next := nil;

  Inc(FNum);
  if (FFirst = nil) and (FLast = nil) then
    begin
      FFirst := p;
      FLast := p;
    end
  else if FLast <> nil then
    begin
      FLast^.Next := p;
      FLast := p;
    end;
  Result := p;
end;

function TOrderStruct<T_>.Push_Null: POrderStruct;
var
  p: POrderStruct;
begin
  new(p);
  FillPtr(p, SizeOf(TOrderStruct_), 0);
  p^.Next := nil;

  Inc(FNum);
  if (FFirst = nil) and (FLast = nil) then
    begin
      FFirst := p;
      FLast := p;
    end
  else if FLast <> nil then
    begin
      FLast^.Next := p;
      FLast := p;
    end;
  Result := p;
end;

procedure TOrderPtrStruct<T_>.DoInternalFree(const p: POrderPtrStruct);
begin
  try
    DoFree(p^.Data);
    Dispose(p);
  except
  end;
end;

constructor TOrderPtrStruct<T_>.Create;
begin
  inherited Create;
  FFirst := nil;
  FLast := nil;
  FNum := 0;
  FOnFreeOrderStruct := nil;
end;

destructor TOrderPtrStruct<T_>.Destroy;
begin
  Clear;
  inherited Destroy;
end;

procedure TOrderPtrStruct<T_>.DoFree(Data: PT_);
begin
  if Assigned(FOnFreeOrderStruct) then
      FOnFreeOrderStruct(Data)
  else
      Dispose(Data);
end;

procedure TOrderPtrStruct<T_>.SwapInstance(source: TOrderPtrStruct<T_>);
var
  FFirst_: POrderPtrStruct;
  FLast_: POrderPtrStruct;
  FNum_: NativeInt;
begin
  FFirst_ := FFirst;
  FLast_ := FLast;
  FNum_ := FNum;

  FFirst := source.FFirst;
  FLast := source.FLast;
  FNum := source.FNum;

  source.FFirst := FFirst_;
  source.FLast := FLast_;
  source.FNum := FNum_;
end;

procedure TOrderPtrStruct<T_>.Clear;
var
  p, N_P: POrderPtrStruct;
begin
  p := FFirst;
  while p <> nil do
    begin
      N_P := p^.Next;
      try
          DoInternalFree(p);
      except
      end;
      p := N_P;
    end;
  FFirst := nil;
  FLast := nil;
  FNum := 0;
end;

procedure TOrderPtrStruct<T_>.Next;
var
  N_P: POrderPtrStruct;
begin
  if FFirst <> nil then
    begin
      N_P := FFirst^.Next;
      try
          DoInternalFree(FFirst);
      except
      end;
      FFirst := N_P;
      if FFirst = nil then
          FLast := nil;
      Dec(FNum);
    end;
end;

function TOrderPtrStruct<T_>.Push(const Data: T_): POrderPtrStruct;
var
  p: POrderPtrStruct;
begin
  new(p);
  new(p^.Data);
  p^.Data^ := Data;
  p^.Next := nil;

  Inc(FNum);
  if (FFirst = nil) and (FLast = nil) then
    begin
      FFirst := p;
      FLast := p;
    end
  else if FLast <> nil then
    begin
      FLast^.Next := p;
      FLast := p;
    end;
  Result := p;
end;

function TOrderPtrStruct<T_>.PushPtr(Data: PT_): POrderPtrStruct;
var
  p: POrderPtrStruct;
begin
  new(p);
  p^.Data := Data;
  p^.Next := nil;

  Inc(FNum);
  if (FFirst = nil) and (FLast = nil) then
    begin
      FFirst := p;
      FLast := p;
    end
  else if FLast <> nil then
    begin
      FLast^.Next := p;
      FLast := p;
    end;
  Result := p;
end;

procedure TCriticalOrderStruct<T_>.DoInternalFree(const p: POrderStruct);
begin
  try
    DoFree(p^.Data);
    Dispose(p);
  except
  end;
end;

constructor TCriticalOrderStruct<T_>.Create;
begin
  inherited Create;
  FCritical__ := TCritical.Create(ClassName + '.Critical__');
  FFirst := nil;
  FLast := nil;
  FNum := 0;
  FOnFreeCriticalOrderStruct := nil;
end;

destructor TCriticalOrderStruct<T_>.Destroy;
begin
  Clear;
  FCritical__.Free;
  inherited Destroy;
end;

procedure TCriticalOrderStruct<T_>.DoFree(var Data: T_);
begin
  if Assigned(FOnFreeCriticalOrderStruct) then
      FOnFreeCriticalOrderStruct(Data);
end;

procedure TCriticalOrderStruct<T_>.SwapInstance(source: TCriticalOrderStruct<T_>);
var
  FFirst_: POrderStruct;
  FLast_: POrderStruct;
  FNum_: NativeInt;
begin
  FCritical__.Lock;
  source.FCritical__.Lock;

  FFirst_ := FFirst;
  FLast_ := FLast;
  FNum_ := FNum;

  FFirst := source.FFirst;
  FLast := source.FLast;
  FNum := source.FNum;

  source.FFirst := FFirst_;
  source.FLast := FLast_;
  source.FNum := FNum_;

  FCritical__.UnLock;
  source.FCritical__.UnLock;
end;

procedure TCriticalOrderStruct<T_>.Clear;
var
  p, N_P: POrderStruct;
begin
  FCritical__.Lock;
  p := FFirst;
  while p <> nil do
    begin
      N_P := p^.Next;
      try
          DoInternalFree(p);
      except
      end;
      p := N_P;
    end;
  FFirst := nil;
  FLast := nil;
  FNum := 0;
  FCritical__.UnLock;
end;

function TCriticalOrderStruct<T_>.GetCurrent: POrderStruct;
begin
  FCritical__.Lock;
  Result := FFirst;
  FCritical__.UnLock;
end;

procedure TCriticalOrderStruct<T_>.Next;
var
  N_P: POrderStruct;
begin
  FCritical__.Lock;
  if FFirst <> nil then
    begin
      N_P := FFirst^.Next;
      try
          DoInternalFree(FFirst);
      except
      end;
      FFirst := N_P;
      if FFirst = nil then
          FLast := nil;
      Dec(FNum);
    end;
  FCritical__.UnLock;
end;

function TCriticalOrderStruct<T_>.Push(const Data: T_): POrderStruct;
var
  p: POrderStruct;
begin
  new(p);
  p^.Data := Data;
  p^.Next := nil;

  FCritical__.Lock;
  Inc(FNum);
  if (FFirst = nil) and (FLast = nil) then
    begin
      FFirst := p;
      FLast := p;
    end
  else if FLast <> nil then
    begin
      FLast^.Next := p;
      FLast := p;
    end;
  FCritical__.UnLock;
  Result := p;
end;

function TCriticalOrderStruct<T_>.Push_Null: POrderStruct;
var
  p: POrderStruct;
begin
  new(p);
  FillPtr(p, SizeOf(TOrderStruct_), 0);
  p^.Next := nil;

  FCritical__.Lock;
  Inc(FNum);
  if (FFirst = nil) and (FLast = nil) then
    begin
      FFirst := p;
      FLast := p;
    end
  else if FLast <> nil then
    begin
      FLast^.Next := p;
      FLast := p;
    end;
  FCritical__.UnLock;
  Result := p;
end;

function TCriticalOrderStruct<T_>.GetNum: NativeInt;
begin
  FCritical__.Lock;
  Result := FNum;
  FCritical__.UnLock;
end;

procedure TCriticalOrderPtrStruct<T_>.DoInternalFree(const p: POrderPtrStruct);
begin
  try
    DoFree(p^.Data);
    Dispose(p);
  except
  end;
end;

constructor TCriticalOrderPtrStruct<T_>.Create;
begin
  inherited Create;
  FCritical__ := TCritical.Create(ClassName + '.Critical__');
  FFirst := nil;
  FLast := nil;
  FNum := 0;
  FOnFreeCriticalOrderStruct := nil;
end;

destructor TCriticalOrderPtrStruct<T_>.Destroy;
begin
  Clear;
  FCritical__.Free;
  inherited Destroy;
end;

procedure TCriticalOrderPtrStruct<T_>.DoFree(Data: PT_);
begin
  if Assigned(FOnFreeCriticalOrderStruct) then
      FOnFreeCriticalOrderStruct(Data)
  else
      Dispose(Data);
end;

procedure TCriticalOrderPtrStruct<T_>.SwapInstance(source: TCriticalOrderPtrStruct<T_>);
var
  FFirst_: POrderPtrStruct;
  FLast_: POrderPtrStruct;
  FNum_: NativeInt;
begin
  FCritical__.Lock;
  source.FCritical__.Lock;

  FFirst_ := FFirst;
  FLast_ := FLast;
  FNum_ := FNum;

  FFirst := source.FFirst;
  FLast := source.FLast;
  FNum := source.FNum;

  source.FFirst := FFirst_;
  source.FLast := FLast_;
  source.FNum := FNum_;

  FCritical__.UnLock;
  source.FCritical__.UnLock;
end;

procedure TCriticalOrderPtrStruct<T_>.Clear;
var
  p, N_P: POrderPtrStruct;
begin
  FCritical__.Lock;
  p := FFirst;
  while p <> nil do
    begin
      N_P := p^.Next;
      try
          DoInternalFree(p);
      except
      end;
      p := N_P;
    end;
  FFirst := nil;
  FLast := nil;
  FNum := 0;
  FCritical__.UnLock;
end;

function TCriticalOrderPtrStruct<T_>.GetCurrent: POrderPtrStruct;
begin
  FCritical__.Lock;
  Result := FFirst;
  FCritical__.UnLock;
end;

procedure TCriticalOrderPtrStruct<T_>.Next;
var
  N_P: POrderPtrStruct;
begin
  FCritical__.Lock;
  if FFirst <> nil then
    begin
      N_P := FFirst^.Next;
      try
          DoInternalFree(FFirst);
      except
      end;
      FFirst := N_P;
      if FFirst = nil then
          FLast := nil;
      Dec(FNum);
    end;
  FCritical__.UnLock;
end;

function TCriticalOrderPtrStruct<T_>.Push(const Data: T_): POrderPtrStruct;
var
  p: POrderPtrStruct;
begin
  new(p);
  new(p^.Data);
  p^.Data^ := Data;
  p^.Next := nil;

  FCritical__.Lock;
  Inc(FNum);
  if (FFirst = nil) and (FLast = nil) then
    begin
      FFirst := p;
      FLast := p;
    end
  else if FLast <> nil then
    begin
      FLast^.Next := p;
      FLast := p;
    end;
  FCritical__.UnLock;
  Result := p;
end;

function TCriticalOrderPtrStruct<T_>.PushPtr(Data: PT_): POrderPtrStruct;
var
  p: POrderPtrStruct;
begin
  new(p);
  p^.Data := Data;
  p^.Next := nil;

  FCritical__.Lock;
  Inc(FNum);
  if (FFirst = nil) and (FLast = nil) then
    begin
      FFirst := p;
      FLast := p;
    end
  else if FLast <> nil then
    begin
      FLast^.Next := p;
      FLast := p;
    end;
  FCritical__.UnLock;
  Result := p;
end;

function TCriticalOrderPtrStruct<T_>.GetNum: NativeInt;
begin
  FCritical__.Lock;
  Result := FNum;
  FCritical__.UnLock;
end;

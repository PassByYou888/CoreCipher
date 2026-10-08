function TAtomVar<T_>.GetValue: T_;
begin
  FCritical.Acquire;
  Result := FValue__;
  FCritical.Release;
end;

procedure TAtomVar<T_>.SetValue(const Value_: T_);
begin
  FCritical.Acquire;
  FValue__ := Value_;
  FCritical.Release;
end;

function TAtomVar<T_>.GetValueP: PT_;
begin
  Result := @FValue__;
end;

constructor TAtomVar<T_>.Create(Value_: T_);
begin
  inherited Create;
  FValue__ := Value_;
  FCritical := TCritical.Create(ClassName + '.Critical');
end;

destructor TAtomVar<T_>.Destroy;
begin
  FCritical.Free;
  inherited Destroy;
end;

function TAtomVar<T_>.Lock: T_;
begin
  FCritical.Acquire;
  Result := FValue__;
end;

function TAtomVar<T_>.LockP: PT_;
begin
  FCritical.Acquire;
  Result := @FValue__;
end;

procedure TAtomVar<T_>.UnLock(const Value_: T_);
begin
  FValue__ := Value_;
  FCritical.Release;
end;

procedure TAtomVar<T_>.UnLock(const Value_: PT_);
begin
  FValue__ := Value_^;
  FCritical.Release;
end;

procedure TAtomVar<T_>.UnLock();
begin
  FCritical.Release;
end;

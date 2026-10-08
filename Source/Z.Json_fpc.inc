{ ****************************************************************************** }
{ * json object library objfpc                                                 * }
{ ****************************************************************************** }
procedure TZ_JsonArray.Clear;
begin
  FInstance.Clear;
end;

procedure TZ_JsonArray.Delete(Index: integer);
begin
  FInstance.Delete(Index);
end;

procedure TZ_JsonArray.Add(const v_: string);
begin
  FInstance.Add(v_);
end;

procedure TZ_JsonArray.Add(const v_: TZ_JsonString);
begin
  FInstance.Add(v_.Text);
end;

procedure TZ_JsonArray.Add(const v_: integer);
begin
  FInstance.Add(v_);
end;

procedure TZ_JsonArray.Add(const v_: int64);
begin
  FInstance.Add(v_);
end;

procedure TZ_JsonArray.Add(const v_: uint64);
begin
  FInstance.Add(v_);
end;

procedure TZ_JsonArray.AddF(const v_: double);
begin
  FInstance.Add(v_);
end;

procedure TZ_JsonArray.Add(const v_: TDateTime);
begin
  FInstance.Add(umlDateTimeToStr(v_).Text);
end;

procedure TZ_JsonArray.Add(const v_: boolean);
begin
  FInstance.Add(v_);
end;

function TZ_JsonArray.AddArray: TZ_JsonArray;
begin
  Result := TZ_JsonArray.Create(self);
  Result.FInstance := TZ_Instance_JsonArray.Create;
  FInstance.Add(Result.FInstance);
end;

function TZ_JsonArray.AddObject: TZ_JsonObject;
begin
  Result := TZ_JsonObject.Create(self);
  Result.FInstance := TZ_Instance_JsonObject.Create;
  FInstance.Add(Result.FInstance);
end;

procedure TZ_JsonArray.Insert(Index: integer; const v_: string);
begin
  FInstance.Insert(Index, v_);
end;

procedure TZ_JsonArray.Insert(Index: integer; const v_: TZ_JsonString);
begin
  FInstance.Insert(Index, v_.Text);
end;

procedure TZ_JsonArray.Insert(Index: integer; const v_: integer);
begin
  FInstance.Insert(Index, v_);
end;

procedure TZ_JsonArray.Insert(Index: integer; const v_: int64);
begin
  FInstance.Insert(Index, v_);
end;

procedure TZ_JsonArray.Insert(Index: integer; const v_: uint64);
begin
  FInstance.Insert(Index, v_);
end;

procedure TZ_JsonArray.Insert(Index: integer; const v_: double);
begin
  FInstance.Insert(Index, v_);
end;

procedure TZ_JsonArray.Insert(Index: integer; const v_: TDateTime);
begin
  FInstance.Insert(Index, umlDateTimeToStr(v_).Text);
end;

procedure TZ_JsonArray.Insert(Index: integer; const v_: boolean);
begin
  FInstance.Insert(Index, v_);
end;

function TZ_JsonArray.InsertArray(Index: integer): TZ_JsonArray;
begin
  Result := TZ_JsonArray.Create(self);
  Result.FInstance := TZ_Instance_JsonArray.Create;
  FInstance.Insert(Index, Result.FInstance);
end;

function TZ_JsonArray.InsertObject(Index: integer): TZ_JsonObject;
begin
  Result := TZ_JsonObject.Create(self);
  Result.FInstance := TZ_Instance_JsonObject.Create;
  FInstance.Insert(Index, Result.FInstance);
end;

function TZ_JsonArray.GetString(Index: integer): string;
begin
  Result := FInstance.Strings[Index];
end;

procedure TZ_JsonArray.SetString(Index: integer; const Value: string);
begin
  FInstance.Strings[Index] := Value;
end;

function TZ_JsonArray.GetInt(Index: integer): integer;
begin
  Result := FInstance.Integers[Index];
end;

procedure TZ_JsonArray.SetInt(Index: integer; const Value: integer);
begin
  FInstance.Integers[Index] := Value;
end;

function TZ_JsonArray.GetLong(Index: integer): int64;
begin
  Result := FInstance.Int64s[Index];
end;

procedure TZ_JsonArray.SetLong(Index: integer; const Value: int64);
begin
  FInstance.Int64s[Index] := Value;
end;

function TZ_JsonArray.GetULong(Index: integer): uint64;
begin
  Result := FInstance.QWords[Index];
end;

procedure TZ_JsonArray.SetULong(Index: integer; const Value: uint64);
begin
  FInstance.QWords[Index] := Value;
end;

function TZ_JsonArray.GetFloat(Index: integer): double;
begin
  Result := FInstance.Floats[Index];
end;

procedure TZ_JsonArray.SetFloat(Index: integer; const Value: double);
begin
  FInstance.Floats[Index] := Value;
end;

function TZ_JsonArray.GetDateTime(Index: integer): TDateTime;
begin
  Result := umlStrToDateTime(FInstance.Strings[Index]);
end;

procedure TZ_JsonArray.SetDateTime(Index: integer; const Value: TDateTime);
begin
  FInstance.Strings[Index] := umlDateTimeToStr(Value).Text;
end;

function TZ_JsonArray.GetBool(Index: integer): boolean;
begin
  Result := FInstance.Booleans[Index];
end;

procedure TZ_JsonArray.SetBool(Index: integer; const Value: boolean);
begin
  FInstance.Booleans[Index] := Value;
end;

function TZ_JsonArray.GetArray(Index: integer): TZ_JsonArray;
var
  arry: TZ_Instance_JsonArray;
  j: integer;
begin
  arry := FInstance.Arrays[Index];
  for j := FList.Count - 1 downto 0 do
    if (FList[j] is TZ_JsonArray) and (TZ_JsonArray(FList[j]).FInstance = arry) then
    begin
      Result := TZ_JsonArray(FList[j]);
      exit;
    end;
  Result := TZ_JsonArray.Create(self);
  Result.FInstance := arry;
end;

function TZ_JsonArray.GetObject(Index: integer): TZ_JsonObject;
var
  Obj_: TZ_Instance_JsonObject;
  j: integer;
begin
  Obj_ := FInstance.Objects[Index];
  for j := FList.Count - 1 downto 0 do
    if (FList[j] is TZ_JsonObject) and (TZ_JsonObject(FList[j]).FInstance = Obj_) then
    begin
      Result := TZ_JsonObject(FList[j]);
      exit;
    end;
  Result := TZ_JsonObject.Create(self);
  Result.FInstance := Obj_;
end;

function TZ_JsonArray.GetCount: integer;
begin
  Result := FInstance.Count;
end;

procedure TZ_JsonObject.Clear;
begin
  FInstance.Clear;
end;

function TZ_JsonObject.IndexOf(const Name: string): integer;
begin
  Result := FInstance.IndexOfName(Name);
end;

function TZ_JsonObject.GetString(const Name: string): string;
begin
  Result := FInstance.Strings[Name];
end;

procedure TZ_JsonObject.SetString(const Name, Value: string);
begin
  FInstance.Strings[Name] := Value;
end;

function TZ_JsonObject.GetInt(const Name: string): integer;
begin
  Result := FInstance.Integers[Name];
end;

procedure TZ_JsonObject.SetInt(const Name: string; const Value: integer);
begin
  FInstance.Integers[Name] := Value;
end;

function TZ_JsonObject.GetLong(const Name: string): int64;
begin
  Result := FInstance.Int64s[Name];
end;

procedure TZ_JsonObject.SetLong(const Name: string; const Value: int64);
begin
  FInstance.Int64s[Name] := Value;
end;

function TZ_JsonObject.GetULong(const Name: string): uint64;
begin
  Result := FInstance.QWords[Name];
end;

procedure TZ_JsonObject.SetULong(const Name: string; const Value: uint64);
begin
  FInstance.QWords[Name] := Value;
end;

function TZ_JsonObject.GetFloat(const Name: string): double;
begin
  Result := FInstance.Floats[Name];
end;

procedure TZ_JsonObject.SetFloat(const Name: string; const Value: double);
begin
  FInstance.Floats[Name] := Value;
end;

function TZ_JsonObject.GetDateTime(const Name: string): TDateTime;
begin
  Result := umlStrToDateTime(FInstance.Strings[Name]);
end;

procedure TZ_JsonObject.SetDateTime(const Name: string; const Value: TDateTime);
begin
  FInstance.Strings[Name] := umlDateTimeToStr(Value).Text;
end;

function TZ_JsonObject.GetBool(const Name: string): boolean;
begin
  Result := FInstance.Booleans[Name];
end;

procedure TZ_JsonObject.SetBool(const Name: string; const Value: boolean);
begin
  FInstance.Booleans[Name] := Value;
end;

function TZ_JsonObject.GetArray(const Name: string): TZ_JsonArray;
var
  arry: TZ_Instance_JsonArray;
  j: integer;
  idx: integer;
begin
  idx := FInstance.IndexOfName(Name);
  if idx <> -1 then
  begin
    if FInstance.Items[idx].JSONType = jtArray then
      arry := TJSONArray(FInstance.Items[idx])
    else
      arry := nil;
    if arry <> nil then
    begin
      for j := FList.Count - 1 downto 0 do
        if (FList[j] is TZ_JsonArray) and (TZ_JsonArray(FList[j]).FInstance = arry) then
        begin
          Result := TZ_JsonArray(FList[j]);
          exit;
        end;
      Result := TZ_JsonArray.Create(self);
      Result.FInstance := arry;
      exit;
    end;
  end;

  arry := TZ_Instance_JsonArray.Create();
  FInstance.Add(Name, arry);
  Result := TZ_JsonArray.Create(self);
  Result.FInstance := arry;
end;

function TZ_JsonObject.GetObject(const Name: string): TZ_JsonObject;
var
  Obj_: TZ_Instance_JsonObject;
  j: integer;
  idx: integer;
begin
  idx := FInstance.IndexOfName(Name);
  if idx <> -1 then
  begin
    if FInstance.Items[idx].JSONType = jtObject then
      Obj_ := TJSONObject(FInstance.Items[idx])
    else
      Obj_ := nil;
    if Obj_ <> nil then
    begin
      for j := FList.Count - 1 downto 0 do
        if (FList[j] is TZ_JsonObject) and (TZ_JsonObject(FList[j]).FInstance = Obj_) then
        begin
          Result := TZ_JsonObject(FList[j]);
          exit;
        end;
      Result := TZ_JsonObject.Create(self);
      Result.FInstance := Obj_;
      exit;
    end;
  end;

  Obj_ := TZ_Instance_JsonObject.Create();
  FInstance.Add(Name, Obj_);
  Result := TZ_JsonObject.Create(self);
  Result.FInstance := Obj_;
end;

function TZ_JsonObject.GetName(Index: integer): string;
begin
  Result := FInstance.Names[Index];
end;

function TZ_JsonObject.GetCount: integer;
begin
  Result := FInstance.Count;
end;

procedure TZ_JsonObject.SaveToStream(stream: TCore_Stream; Formated_: boolean);
var
  s_: TZ_JsonString;
  buff: TBytes;
begin
  try
    if Formated_ then
      s_.Text := FInstance.FormatJSON()
    else
      s_.Text := FInstance.AsJSON;
  except
    s_.Text := '{}';
  end;
  buff := s_.Bytes;
  s_ := '';
  stream.Write(buff[0], length(buff));
  SetLength(buff, 0);
end;

procedure TZ_JsonObject.LoadFromStream(stream: TCore_Stream);
var
  j: TJSONData;
begin
  DisposeObjectAndNil(FInstance);
  if (stream = nil) or (stream.Size - stream.Position <= 0) then
  begin
    FInstance := TZ_Instance_JsonObject.Create;
    exit;
  end;

  j := GetJSON(stream);
  if Assigned(j) and (j is TZ_Instance_JsonObject) then
    FInstance := TZ_Instance_JsonObject(j)
  else
  begin
    FInstance := nil;
    DisposeObjectAndNil(j);
  end;

  if FInstance = nil then
    FInstance := TZ_Instance_JsonObject.Create;
end;

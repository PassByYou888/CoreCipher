class function TPair2<T1, T2>.Init(Primary_: T1; Second_: T2): TPair2<T1, T2>;
begin
  Result.Primary := Primary_;
  Result.Second := Second_;
end;

class function TPair3<T1, T2, T3>.Init(Primary_: T1; Second_: T2; Third_: T3): TPair3<T1, T2, T3>;
begin
  Result.Primary := Primary_;
  Result.Second := Second_;
  Result.Third := Third_;
end;

class function TPair4<T1, T2, T3, T4>.Init(Primary_: T1; Second_: T2; Third_: T3; Fourth_: T4): TPair4<T1, T2, T3, T4>;
begin
  Result.Primary := Primary_;
  Result.Second := Second_;
  Result.Third := Third_;
  Result.Fourth := Fourth_;
end;

class function TPair5<T1, T2, T3, T4, T5>.Init(Primary_: T1; Second_: T2; Third_: T3; Fourth_: T4; Five_: T5): TPair5<T1, T2, T3, T4, T5>;
begin
  Result.Primary := Primary_;
  Result.Second := Second_;
  Result.Third := Third_;
  Result.Fourth := Fourth_;
  Result.Five := Five_;
end;

class function TPair6<T1, T2, T3, T4, T5, T6>.Init(Primary_: T1; Second_: T2; Third_: T3; Fourth_: T4; Five_: T5; Six_: T6): TPair6<T1, T2, T3, T4, T5, T6>;
begin
  Result.Primary := Primary_;
  Result.Second := Second_;
  Result.Third := Third_;
  Result.Fourth := Fourth_;
  Result.Five := Five_;
  Result.Six := Six_;
end;

// *****************************************************************************************************************

constructor TPair2_Tool<T1_, T2_>.Create;
begin
  inherited Create;
  List := TPair_BigList__.Create;
  List.FOnFree_For_Pair_Tool := DoFree;
  List.FOnAdd := DoAdd;
end;

destructor TPair2_Tool<T1_, T2_>.Destroy;
begin
  List.Free;
  inherited Destroy;
end;

procedure TPair2_Tool<T1_, T2_>.DoFree(var Data: TPair);
begin
end;

procedure TPair2_Tool<T1_, T2_>.DoAdd(var Data: TPair);
begin
end;

function TPair2_Tool<T1_, T2_>.Add_Pair(Primary: T1_; Second: T2_): PPair__;
begin
  Result := List.Add_Null();
  Result^.Data.Primary := Primary;
  Result^.Data.Second := Second;
end;

// *****************************************************************************************************************

constructor TPair3_Tool<T1_, T2_, T3_>.Create;
begin
  inherited Create;
  List := TPair_BigList__.Create;
  List.FOnFree_For_Pair_Tool := DoFree;
  List.FOnAdd := DoAdd;
end;

destructor TPair3_Tool<T1_, T2_, T3_>.Destroy;
begin
  List.Free;
  inherited Destroy;
end;

procedure TPair3_Tool<T1_, T2_, T3_>.DoFree(var Data: TPair);
begin
end;

procedure TPair3_Tool<T1_, T2_, T3_>.DoAdd(var Data: TPair);
begin
end;

function TPair3_Tool<T1_, T2_, T3_>.Add_Pair(Primary: T1_; Second: T2_; Third: T3_): PPair__;
begin
  Result := List.Add_Null();
  Result^.Data.Primary := Primary;
  Result^.Data.Second := Second;
  Result^.Data.Third := Third;
end;

// *****************************************************************************************************************

constructor TPair4_Tool<T1_, T2_, T3_, T4_>.Create;
begin
  inherited Create;
  List := TPair_BigList__.Create;
  List.FOnFree_For_Pair_Tool := DoFree;
  List.FOnAdd := DoAdd;
end;

destructor TPair4_Tool<T1_, T2_, T3_, T4_>.Destroy;
begin
  List.Free;
  inherited Destroy;
end;

procedure TPair4_Tool<T1_, T2_, T3_, T4_>.DoFree(var Data: TPair);
begin
end;

procedure TPair4_Tool<T1_, T2_, T3_, T4_>.DoAdd(var Data: TPair);
begin
end;

function TPair4_Tool<T1_, T2_, T3_, T4_>.Add_Pair(Primary: T1_; Second: T2_; Third: T3_; Fourth: T4_): PPair__;
begin
  Result := List.Add_Null();
  Result^.Data.Primary := Primary;
  Result^.Data.Second := Second;
  Result^.Data.Third := Third;
  Result^.Data.Fourth := Fourth;
end;

// *****************************************************************************************************************

constructor TPair5_Tool<T1_, T2_, T3_, T4_, T5_>.Create;
begin
  inherited Create;
  List := TPair_BigList__.Create;
  List.FOnFree_For_Pair_Tool := DoFree;
  List.FOnAdd := DoAdd;
end;

destructor TPair5_Tool<T1_, T2_, T3_, T4_, T5_>.Destroy;
begin
  List.Free;
  inherited Destroy;
end;

procedure TPair5_Tool<T1_, T2_, T3_, T4_, T5_>.DoFree(var Data: TPair);
begin
end;

procedure TPair5_Tool<T1_, T2_, T3_, T4_, T5_>.DoAdd(var Data: TPair);
begin
end;

function TPair5_Tool<T1_, T2_, T3_, T4_, T5_>.Add_Pair(Primary: T1_; Second: T2_; Third: T3_; Fourth: T4_; Five: T5_): PPair__;
begin
  Result := List.Add_Null();
  Result^.Data.Primary := Primary;
  Result^.Data.Second := Second;
  Result^.Data.Third := Third;
  Result^.Data.Fourth := Fourth;
  Result^.Data.Five := Five;
end;

// *****************************************************************************************************************

constructor TPair6_Tool<T1_, T2_, T3_, T4_, T5_, T6_>.Create;
begin
  inherited Create;
  List := TPair_BigList__.Create;
  List.FOnFree_For_Pair_Tool := DoFree;
  List.FOnAdd := DoAdd;
end;

destructor TPair6_Tool<T1_, T2_, T3_, T4_, T5_, T6_>.Destroy;
begin
  List.Free;
  inherited Destroy;
end;

procedure TPair6_Tool<T1_, T2_, T3_, T4_, T5_, T6_>.DoFree(var Data: TPair);
begin
end;

procedure TPair6_Tool<T1_, T2_, T3_, T4_, T5_, T6_>.DoAdd(var Data: TPair);
begin
end;

function TPair6_Tool<T1_, T2_, T3_, T4_, T5_, T6_>.Add_Pair(Primary: T1_; Second: T2_; Third: T3_; Fourth: T4_; Five: T5_; Six: T6_): PPair__;
begin
  Result := List.Add_Null();
  Result^.Data.Primary := Primary;
  Result^.Data.Second := Second;
  Result^.Data.Third := Third;
  Result^.Data.Fourth := Fourth;
  Result^.Data.Five := Five;
  Result^.Data.Six := Six;
end;

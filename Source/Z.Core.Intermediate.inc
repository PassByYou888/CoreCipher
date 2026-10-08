{ ****************************************************************************** }
{ * Core Object Intermediate Tool                                              * }
{ ****************************************************************************** }
procedure ___Inc_Instance_Num___(const Instance_: string); // null
begin
end;

procedure ___Dec_Instance_Num___(const Instance_: string); // null
begin
end;

constructor TCore_Object_Intermediate.Create;
begin
  inherited Create;
{$IFDEF Intermediate_Instance_Tool}
  Inc_Instance_Num(UnitName + '.pas (' + ClassName + ')');
{$ENDIF Intermediate_Instance_Tool}
end;

destructor TCore_Object_Intermediate.Destroy;
begin
{$IFDEF Intermediate_Instance_Tool}
  Dec_Instance_Num(UnitName + '.pas (' + ClassName + ')');
{$ENDIF Intermediate_Instance_Tool}
  inherited Destroy;
end;

constructor TCore_InterfacedObject_Intermediate.Create;
begin
  inherited Create;
{$IFDEF Intermediate_Instance_Tool}
  Inc_Instance_Num(UnitName + '.pas (' + ClassName + ')');
{$ENDIF Intermediate_Instance_Tool}
end;

destructor TCore_InterfacedObject_Intermediate.Destroy;
begin
{$IFDEF Intermediate_Instance_Tool}
  Dec_Instance_Num(UnitName + '.pas (' + ClassName + ')');
{$ENDIF Intermediate_Instance_Tool}
  inherited Destroy;
end;

constructor TCore_Persistent_Intermediate.Create;
begin
  inherited Create;
{$IFDEF Intermediate_Instance_Tool}
  Inc_Instance_Num(UnitName + '.pas (' + ClassName + ')');
{$ENDIF Intermediate_Instance_Tool}
end;

destructor TCore_Persistent_Intermediate.Destroy;
begin
{$IFDEF Intermediate_Instance_Tool}
  Dec_Instance_Num(UnitName + '.pas (' + ClassName + ')');
{$ENDIF Intermediate_Instance_Tool}
  inherited Destroy;
end;

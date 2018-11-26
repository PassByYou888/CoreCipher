{
  Based on FPC FGL unit, copyright by FPC team.
  License of FPC RTL is the same as our engine (modified LGPL,
  see COPYING.txt for details).
  Fixed to compile also under FPC 2.4.0 and 2.2.4.
  Some small comfortable methods added.
}

{ Generic list of any type (TGenericStructList). }
unit FPCGenericStructlist;

{$IFDEF FPC}
{$mode objfpc}{$H+}

{$IF defined(VER2_2)} {$DEFINE OldSyntax} {$IFEND}
{$IF defined(VER2_4)} {$DEFINE OldSyntax} {$IFEND}

{$define HAS_ENUMERATOR}
{$ifdef VER2_2} {$undef HAS_ENUMERATOR} {$endif}
{$ifdef VER2_4_0} {$undef HAS_ENUMERATOR} {$endif}
{ Just undef enumerator always, in FPC 2.7.1 it's either broken
  or I shouldn't overuse TFPGListEnumeratorSpec. }
{$undef HAS_ENUMERATOR}

{ FPC < 2.6.0 had buggy version of the Extract function,
  also with different interface, see http://bugs.freepascal.org/view.php?id=19960. }
{$define HAS_EXTRACT}
{$ifdef VER2_2} {$undef HAS_EXTRACT} {$endif}
{$ifdef VER2_4} {$undef HAS_EXTRACT} {$endif}
{$ENDIF FPC}

interface

{$IFDEF FPC}

uses fgl;

type
  { Generic list of types that are compared by CompareByte.

    This is equivalent to TFPGList, except it doesn't override IndexOf,
    so your type doesn't need to have a "=" operator built-in inside FPC.
    When calling IndexOf or Remove, it will simply compare values using
    CompareByte, this is what TFPSList.IndexOf uses.
    This way it works to create lists of records, vectors (constant size arrays),
    old-style TP objects, and also is suitable to create a list of methods
    (since for methods, the "=" is broken, for Delphi compatibility,
    see http://bugs.freepascal.org/view.php?id=9228).

    We also add some trivial helper methods like @link(Add) and @link(L). }
  generic TGenericStructList<t> = class(TFPSList)
  private
    type
      TCompareFunc = function(const Item1, Item2: t): Integer;
      TTypeList = array[0..MaxGListSize] of t;
      PTypeList = ^TTypeList;
      pt = ^t;
  {$ifdef HAS_ENUMERATOR} TFPGListEnumeratorSpec = specialize TFPGListEnumerator<t>; {$endif}

  {$ifndef OldSyntax}protected var{$else}
      {$ifdef PASDOC}protected var{$else} { PasDoc can't handle "var protected", and I don't know how/if they should be handled? }
                     var protected{$endif}{$endif} FOnCompare: TCompareFunc;

    procedure CopyItem(Src, dest: Pointer); override;
    procedure Deref(Item: Pointer); override;
    function  Get(index: Integer): t; {$ifdef CLASSESINLINE} inline; {$endif}
    function  GetList: PTypeList; {$ifdef CLASSESINLINE} inline; {$endif}
    function  ItemPtrCompare(Item1, Item2: Pointer): Integer;
    procedure Put(index: Integer; const Item: t); {$ifdef CLASSESINLINE} inline; {$endif}
  public
    constructor Create;
    function Add(const Item: t): Integer; {$ifdef CLASSESINLINE} inline; {$endif}
    {$ifdef HAS_EXTRACT} function Extract(const Item: t): t; {$ifdef CLASSESINLINE} inline; {$endif} {$endif}
    function First: t; {$ifdef CLASSESINLINE} inline; {$endif}
    {$ifdef HAS_ENUMERATOR} function GetEnumerator: TFPGListEnumeratorSpec; {$ifdef CLASSESINLINE} inline; {$endif} {$endif}
    function IndexOf(const Item: t): Integer;
    procedure Insert(index: Integer; const Item: t); {$ifdef CLASSESINLINE} inline; {$endif}
    function Last: t; {$ifdef CLASSESINLINE} inline; {$endif}
{$ifndef OldSyntax}
    procedure Assign(Source: TGenericStructList);
{$endif OldSyntax}
    function Remove(const Item: t): Integer; {$ifdef CLASSESINLINE} inline; {$endif}
    procedure Sort(Compare: TCompareFunc);
    property Items[index: Integer]: t read Get write Put; default;
    property List: PTypeList read GetList;
  end;

{$ENDIF FPC}

implementation

{$IFDEF FPC}
constructor TGenericStructList.Create;
begin
  inherited Create(SizeOf(t));
end;

procedure TGenericStructList.CopyItem(Src, dest: Pointer);
begin
  t(dest^) := t(Src^);
end;

procedure TGenericStructList.Deref(Item: Pointer);
begin
  Finalize(t(Item^));
end;

function TGenericStructList.Get(index: Integer): t;
begin
  Result := t(inherited Get(index)^);
end;

function TGenericStructList.GetList: PTypeList;
begin
  Result := PTypeList(FList);
end;

function TGenericStructList.ItemPtrCompare(Item1, Item2: Pointer): Integer;
begin
  Result := FOnCompare(t(Item1^), t(Item2^));
end;

procedure TGenericStructList.Put(index: Integer; const Item: t);
begin
  inherited Put(index, @Item);
end;

function TGenericStructList.Add(const Item: t): Integer;
begin
  Result := inherited Add(@Item);
end;

{$ifdef HAS_EXTRACT}
function TGenericStructList.Extract(const Item: t): t;
begin
  inherited Extract(@Item, @Result);
end;
{$endif}

function TGenericStructList.First: t;
begin
  Result := t(inherited First^);
end;

{$ifdef HAS_ENUMERATOR}
function TGenericStructList.GetEnumerator: TFPGListEnumeratorSpec;
begin
  Result := TFPGListEnumeratorSpec.Create(Self);
end;
{$endif}

function TGenericStructList.IndexOf(const Item: t): Integer;
begin
  Result := inherited IndexOf(@Item);
end;

procedure TGenericStructList.Insert(index: Integer; const Item: t);
begin
  t(inherited Insert(index)^) := Item;
end;

function TGenericStructList.Last: t;
begin
  Result := t(inherited Last^);
end;

{$ifndef OldSyntax}
procedure TGenericStructList.Assign(Source: TGenericStructList);
var
  i: Integer;
begin
  Clear;
  for i := 0 to Source.Count - 1 do
    Add(Source[i]);
end;
{$endif OldSyntax}

function TGenericStructList.Remove(const Item: t): Integer;
begin
  Result := IndexOf(Item);
  if Result >= 0 then
    Delete(Result);
end;

procedure TGenericStructList.Sort(Compare: TCompareFunc);
begin
  FOnCompare := Compare;
  inherited Sort(@ItemPtrCompare);
end;

{$ENDIF FPC}

end.




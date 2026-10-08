(* ******************************************************************************
  Z.FPC.GenericList.pas - Generic List Backend for Free Pascal

  This unit provides a generic list (TGenericsList<T>) that stores elements
  by value and compares them via byte-wise memory comparison (CompareByte)
  rather than relying on the '=' operator. This design is essential for
  records, method pointers, and other types where '=' may be ambiguous.

  The implementation inherits from TFPSList (FCL) and is optimized for
  FPC 3.0.0 and newer.

  -----------------------------------------------------------------------------
  Important: This unit is **only** for Free Pascal. When compiled under
  Delphi (where FPC is not defined), the unit becomes a dummy stub with
  no content, allowing Delphi projects to safely reference it without
  breaking the build. This is achieved by placing all FPC-specific code
  inside an {$IFDEF FPC} block.
  ****************************************************************************** *)

unit Z.FPC.GenericList;

{$IFDEF FPC}
  // ----------------------------------------------------------------
  // Free Pascal specific settings and implementation
  // ----------------------------------------------------------------
  {$mode objfpc}{$H+}
  {$MODESWITCH AdvancedRecords}
  {$MODESWITCH NestedProcVars}
  {$MODESWITCH NESTEDCOMMENTS}
  {$NOTES OFF}
  {$STACKFRAMES OFF}
  {$COPERATORS OFF}
  {$GOTO ON}
  {$INLINE ON}
  {$MACRO ON}
  {$HINTS ON}
  {$IEEEERRORS OFF}
  {$R-}
  {$I-}
  {$S-}

  // Enumerator support is stable since FPC 3.0.0
  {$define HAS_ENUMERATOR}
  // Extract method is available in all supported versions
  {$define HAS_EXTRACT}

{$ENDIF FPC}

interface

{$IFDEF FPC}
uses
  fgl;   // provides TFPSList and TFPGListEnumerator

type
  { Generic list that stores elements by value and compares using memory (CompareByte).

    This class overcomes FPC's generic limitation where IndexOf and Remove
    rely on the '=' operator, which may be broken for certain types (e.g.,
    method pointers, records with variant parts). It is ideal for:
      - Records and packed structures
      - Static arrays (vectors)
      - Old-style TP objects (when stored by value)
      - Method pointers (TMethod)

    All operations are performed by raw memory copy, and IndexOf uses a
    byte-wise comparison of the entire element size.

    @warning This list is not thread-safe. External locking required for
             concurrent access.
  }
  generic TGenericsList<t> = class(TFPSList)
  private
    type
      // Comparison function for sorting.
      TCompareFunc = function(const Item1, Item2: t): Integer;

      // Internal type for fast pointer access to the buffer.
      TTypeList = array[0..(MaxInt div SizeOf(t))-1] of t;
      PTypeList = ^TTypeList;

      // Enumerator type – must use 'specialize' because FPC requires explicit
      // instantiation of generic types, even when the type parameter is the
      // enclosing generic's own type parameter.
      TEnumerator = specialize TFPGListEnumerator<t>;

  private
    FOnCompare: TCompareFunc;     // Temporary comparator storage for Sort.

    // Overrides of TFPSList's virtual methods.
    procedure CopyItem(Src, dest: Pointer); override;
    procedure Deref(Item: Pointer); override;

    // Internal helpers.
    function  GetItem(index: Integer): t;
    function  GetListPtr: PTypeList;
    procedure PutItem(index: Integer; const Item: t);
    function  ItemPtrCompare(Item1, Item2: Pointer): Integer;

  public
    constructor Create;

    // Adds an element to the end. Returns the new index.
    function Add(const Item: t): Integer;

    // Removes the first occurrence of Item and returns a copy of it.
    // If not found, the result is default-initialized (uninitialized).
    {$ifdef HAS_EXTRACT}
    function Extract(const Item: t): t;
    {$endif}

    // Returns the first element. Raises an exception if list empty.
    function First: t;

    // Enumerator for 'for in' loops.
    {$ifdef HAS_ENUMERATOR}
    function GetEnumerator: TEnumerator;
    {$endif}

    // Finds the index of the first matching element; -1 if not found.
    function IndexOf(const Item: t): Integer;

    // Inserts an element at the given index.
    procedure Insert(index: Integer; const Item: t);

    // Returns the last element. Raises an exception if list empty.
    function Last: t;

    // Copies all elements from Source into this list, replacing current contents.
    procedure Assign(Source: TGenericsList);

    // Removes the first matching element. Returns its index, or -1 if not found.
    function Remove(const Item: t): Integer;

    // Sorts the list using a custom comparison function.
    // @warning The comparator is stored in a temporary field, so this method
    //          is not reentrant; must be externally synchronized.
    procedure Sort(Compare: TCompareFunc);

    // Reduces internal capacity to match the current Count, reclaiming memory.
    procedure TrimExcess;

    // Indexed access to elements (0-based). Raises exception on out‑of‑bounds.
    property Items[index: Integer]: t read GetItem write PutItem; default;

    // Direct pointer to the underlying buffer (for raw access).
    property List: PTypeList read GetListPtr;
    property ListData: PTypeList read GetListPtr;
  end;

{$ELSE}
  // ----------------------------------------------------------------
  // Delphi (or non-FPC) fallback: empty unit stub.
  // This allows Delphi projects to reference this unit without errors.
  // ----------------------------------------------------------------
  // No declarations or implementations – the unit is essentially a
  // placeholder. Delphi will not attempt to compile any FPC-specific
  // code because the entire FPC block is skipped.
{$ENDIF FPC}

implementation

{$IFDEF FPC}

constructor TGenericsList.Create;
begin
  inherited Create(SizeOf(t));
end;

procedure TGenericsList.CopyItem(Src, dest: Pointer);
begin
  t(dest^) := t(Src^);
end;

procedure TGenericsList.Deref(Item: Pointer);
begin
  Finalize(t(Item^));
end;

function TGenericsList.GetItem(index: Integer): t;
begin
  Result := t(inherited Get(index)^);
end;

function TGenericsList.GetListPtr: PTypeList;
begin
  Result := PTypeList(FList);
end;

function TGenericsList.ItemPtrCompare(Item1, Item2: Pointer): Integer;
begin
  Result := FOnCompare(t(Item1^), t(Item2^));
end;

procedure TGenericsList.PutItem(index: Integer; const Item: t);
begin
  inherited Put(index, @Item);
end;

function TGenericsList.Add(const Item: t): Integer;
begin
  Result := inherited Add(@Item);
end;

{$ifdef HAS_EXTRACT}
function TGenericsList.Extract(const Item: t): t;
begin
  inherited Extract(@Item, @Result);
end;
{$endif}

function TGenericsList.First: t;
begin
  Result := t(inherited First^);
end;

{$ifdef HAS_ENUMERATOR}
function TGenericsList.GetEnumerator: TEnumerator;
begin
  Result := TEnumerator.Create(Self);
end;
{$endif}

function TGenericsList.IndexOf(const Item: t): Integer;
begin
  Result := inherited IndexOf(@Item);
end;

procedure TGenericsList.Insert(index: Integer; const Item: t);
begin
  t(inherited Insert(index)^) := Item;
end;

function TGenericsList.Last: t;
begin
  Result := t(inherited Last^);
end;

procedure TGenericsList.Assign(Source: TGenericsList);
var
  i: Integer;
begin
  Clear;
  for i := 0 to Source.Count - 1 do
    Add(Source[i]);
end;

function TGenericsList.Remove(const Item: t): Integer;
begin
  Result := IndexOf(Item);
  if Result >= 0 then
    Delete(Result);
end;

procedure TGenericsList.Sort(Compare: TCompareFunc);
begin
  FOnCompare := Compare;
  inherited Sort(@ItemPtrCompare);
end;

procedure TGenericsList.TrimExcess;
begin
  SetCount(Count);   // forces reallocation to exactly fit current Count
end;

{$ENDIF FPC}

end.

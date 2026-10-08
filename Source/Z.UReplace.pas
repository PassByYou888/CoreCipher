{
  * Z.UReplace – Batch search and replace engine for TUPascalString
  *
  * This unit provides powerful batch replacement and word extraction utilities
  * specifically designed for the TUPascalString (Unicode) type. It mirrors the
  * functionality found in Z.UnicodeMixedLib but operates on the Unicode string
  * type defined in Z.UPascalStrings.
  *
  * Main features:
  *   – Batch replacement: replace multiple search patterns simultaneously.
  *   – Word‑aware matching: optionally restrict replacements to whole words.
  *   – Case‑sensitive or case‑insensitive matching.
  *   – Customisable symbol sets for word boundary detection.
  *   – Position tracking via TBatchInfo for detailed replacement reports.
  *   – Pattern counting (U_BatchSum) and replacement (U_BatchReplace).
  *   – Single‑pattern replacement (U_Replace) with the same options.
  *   – Word extraction from text, respecting symbols.
  *   – Text position calculation (line/column) for a given character index.
  *
  * The unit is designed to be used alongside Z.UPascalStrings and Z.ListEngine
  * for efficient text processing in Unicode environments.
}

unit Z.UReplace;

{$DEFINE FPC_DELPHI_MODE}
{$I Z.Define.inc}

interface

uses
{$IFDEF FPC}
  Z.FPC.GenericList,
{$ENDIF FPC}
  Z.Core, Z.UPascalStrings, Z.ListEngine;

type
  {
   * TU_Batch – a single batch replacement entry.
   *
   * Represents a substitution pair (sour → dest) along with a counter
   * that tracks how many times the pattern was matched during a batch
   * operation.
  }
  TU_Batch = record
  private
    procedure Swap_(var inst: TU_Batch);   // Exchange contents with another record.
  public
    sour: TUPascalString;                 // The pattern to search for.
    dest: TUPascalString;                 // The replacement string.
    sum: Integer;                         // Number of occurrences found during the last batch operation.
  end;

  PU_Batch = ^TU_Batch;                   // Pointer to a batch entry.

  TU_ArrayBatch = array of TU_Batch;      // Dynamic array of batch entries.

  {
   * TU_BatchInfo – detailed information about a single replacement within a batch.
   *
   * Records the starting and ending positions of both the source pattern and
   * the destination replacement in the processed text. Useful for reporting
   * or further processing.
  }
  TU_BatchInfo = record
    Batch: Integer;           // Index into the batch array for this match.
    sour_bPos, sour_ePos: Integer; // Start and end positions of the matched pattern (1‑based).
    dest_bPos, dest_ePos: Integer; // Start and end positions of the replacement text (1‑based).
  end;

  TU_BatchInfoList = TGenericsList<TU_BatchInfo>; // List for storing TU_BatchInfo records.

  {
   * TOnUBatchProc – callback procedure for batch replacement.
   *
   * Called for each match during a batch replace operation. Allows the caller
   * to inspect or modify the replacement process.
   * @param bPos         Starting position of the match in the source text (1‑based).
   * @param ePos         Ending position of the match (1‑based).
   * @param sour         Pointer to the matched pattern string.
   * @param dest         Pointer to the replacement string (can be altered).
   * @param Accept       Set to False to abort the replacement process.
  }
{$IFDEF FPC}
  TOnUBatchProc = procedure(bPos, ePos: Integer; sour, dest: PUPascalString; var Accept: Boolean) is nested;
{$ELSE FPC}
  TOnUBatchProc = reference to procedure(bPos, ePos: Integer; sour, dest: PUPascalString; var Accept: Boolean);
{$ENDIF FPC}

{
 * Build a batch array from a THashStringList.
 *
 * Each key in the hash list becomes a search pattern, and its corresponding
 * value becomes the replacement string.
 * @param L  The hash string list containing key-value pairs.
 * @return   A TU_ArrayBatch with all entries copied from L.
 *
 * @example:
 *   var
 *     dict: THashStringList;
 *     batch: TU_ArrayBatch;
 *   begin
 *     dict := THashStringList.Create;
 *     dict['old'] := 'new';
 *     dict['foo'] := 'bar';
 *     batch := U_BuildBatch(dict);   // batch[0].sour='old', dest='new'; batch[1].sour='foo', dest='bar'
 *     dict.Free;
 *   end;
}
function U_BuildBatch(L: THashStringList): TU_ArrayBatch; overload;

{
 * Build a batch array from a THashVariantList.
 *
 * Similar to the THashStringList overload, but the replacement values are
 * converted from Variant to string using VarToStr.
 * @param L  The hash variant list containing key-value pairs.
 * @return   A TU_ArrayBatch with all entries converted.
}
function U_BuildBatch(L: THashVariantList): TU_ArrayBatch; overload;

{
 * Free the memory used by a batch array.
 *
 * Sets the length of the array to 0 and clears each entry.
 * @param arry  The batch array to clear.
}
procedure U_ClearBatch(var arry: TU_ArrayBatch);

{
 * Sort a batch array by pattern length (descending).
 *
 * This ensures that longer patterns are matched before shorter ones,
 * which is important for correct replacement when one pattern is a prefix
 * of another (e.g., "hello" and "hell"). Sorting places the longer pattern
 * first so it can be matched before the shorter one.
 * @param arry  The batch array to sort in place.
}
procedure U_SortBatch(var arry: TU_ArrayBatch); overload;

{
 * Check if a character is a symbol using a default set.
 *
 * The default symbol set includes whitespace, punctuation, and operators
 * commonly used as word boundaries.
 * @param c  The character to test.
 * @return   True if the character is considered a symbol.
}
function U_CharIsSymbol(c: USystemChar): Boolean; overload;

{
 * Check if a character is a symbol using a custom set.
 *
 * @param c              The character to test.
 * @param CustomSymbol_  An array of characters that should be treated as symbols.
 * @return               True if c is in CustomSymbol_.
}
function U_CharIsSymbol(c: USystemChar; const CustomSymbol_: TUArrayChar): Boolean; overload;

{
 * Determine if a substring is a whole word.
 *
 * A substring is considered a whole word if it is bounded by symbols or by
 * the start/end of the string. Symbol detection uses the default symbol set.
 * @param p     Pointer to the source string.
 * @param bPos  Start position (1‑based) of the substring.
 * @param ePos  End position (1‑based) of the substring.
 * @return      True if the substring forms a whole word.
}
function U_IsWord(p: PUPascalString; bPos, ePos: Integer): Boolean; overload;

{
 * Same as above but for a TUPascalString value.
}
function U_IsWord(s: TUPascalString; bPos, ePos: Integer): Boolean; overload;

{
 * Extract all words from a string using the default symbol set.
 *
 * Words are substrings separated by characters that are considered symbols.
 * @param s  The input string.
 * @return   An array of all words found.
}
function U_ExtractWord(s: TUPascalString): TUArrayPascalString; overload;

{
 * Extract all words from a string using a custom symbol set.
 *
 * @param s              The input string.
 * @param CustomSymbol_  An array of characters to treat as word separators.
 * @return               An array of all words found.
}
function U_ExtractWord(s: TUPascalString; const CustomSymbol_: TUArrayChar): TUArrayPascalString; overload;

{
 * Count occurrences of each batch pattern in a string (pointer version).
 *
 * This function scans the source text and counts how many times each pattern
 * appears. The sum field of each TU_Batch entry is updated with its count.
 * @param p           Pointer to the source text.
 * @param arry        Batch array (patterns and destinations). The sum field is updated.
 * @param OnlyWord    If True, only match whole words.
 * @param IgnoreCase  If True, perform case‑insensitive matching.
 * @param bPos        Start position for scanning (1‑based).
 * @param ePos        End position for scanning (1‑based).
 * @param Info        Optional list to receive detailed position information for each match.
 * @return Total number of matches found across all patterns.
}
function U_BatchSum(p: PUPascalString; var arry: TU_ArrayBatch; OnlyWord, IgnoreCase: Boolean; bPos, ePos: Integer; Info: TU_BatchInfoList): Integer; overload;

{
 * Same as above but for a TUPascalString value.
}
function U_BatchSum(s: TUPascalString; var arry: TU_ArrayBatch; OnlyWord, IgnoreCase: Boolean; bPos, ePos: Integer; Info: TU_BatchInfoList): Integer; overload;

{
 * Simplified version without Info list.
}
function U_BatchSum(s: TUPascalString; var arry: TU_ArrayBatch; OnlyWord, IgnoreCase: Boolean; bPos, ePos: Integer): Integer; overload;

{
 * Perform batch replacement (pointer version).
 *
 * Replaces all occurrences of each pattern in the batch with its corresponding
 * replacement. Patterns are matched in the order they appear in the batch array
 * (but sorting is recommended). The function updates the sum field of each
 * entry with the number of replacements made.
 * @param p           Pointer to the source text (read-only; the result is returned as a new string).
 * @param arry        Batch array. sum fields are updated.
 * @param OnlyWord    If True, only replace whole words.
 * @param IgnoreCase  If True, case‑insensitive matching.
 * @param bPos        Start position for scanning.
 * @param ePos        End position for scanning.
 * @param Info        Optional list to receive position info for each replacement.
 * @param On_P        Optional callback for each match.
 * @return The resulting string after all replacements.
}
function U_BatchReplace(p: PUPascalString; var arry: TU_ArrayBatch; OnlyWord, IgnoreCase: Boolean; bPos, ePos: Integer; Info: TU_BatchInfoList; On_P: TOnUBatchProc): TUPascalString; overload;

{
 * Same as above but for a TUPascalString value.
}
function U_BatchReplace(s: TUPascalString; var arry: TU_ArrayBatch; OnlyWord, IgnoreCase: Boolean; bPos, ePos: Integer; Info: TU_BatchInfoList; On_P: TOnUBatchProc): TUPascalString; overload;

{
 * Batch replacement without callback.
}
function U_BatchReplace(s: TUPascalString; var arry: TU_ArrayBatch; OnlyWord, IgnoreCase: Boolean; bPos, ePos: Integer; Info: TU_BatchInfoList): TUPascalString; overload;

{
 * Batch replacement without Info or callback.
}
function U_BatchReplace(s: TUPascalString; var arry: TU_ArrayBatch; OnlyWord, IgnoreCase: Boolean; bPos, ePos: Integer): TUPascalString; overload;

{
 * Count occurrences of a single pattern (pointer version).
 *
 * Similar to U_BatchSum but for one pattern.
 * @param p           Pointer to the source text.
 * @param Pattern     The pattern to search for.
 * @param OnlyWord    If True, only match whole words.
 * @param IgnoreCase  If True, case‑insensitive matching.
 * @param bPos        Start position for scanning.
 * @param ePos        End position for scanning.
 * @param Info        Optional list to receive position information.
 * @return The total number of matches found.
}
function U_ReplaceSum(p: PUPascalString; Pattern: TUPascalString; OnlyWord, IgnoreCase: Boolean; bPos, ePos: Integer; Info: TU_BatchInfoList): Integer; overload;

{
 * Same for a TUPascalString value.
}
function U_ReplaceSum(s, Pattern: TUPascalString; OnlyWord, IgnoreCase: Boolean; bPos, ePos: Integer; Info: TU_BatchInfoList): Integer; overload;

{
 * Replace a single pattern (pointer version) with callback.
 *
 * Replaces all occurrences of OldPattern with NewPattern.
 * @param p           Pointer to the source text.
 * @param OldPattern  The pattern to search for.
 * @param NewPattern  The replacement string.
 * @param OnlyWord    If True, only replace whole words.
 * @param IgnoreCase  If True, case‑insensitive matching.
 * @param bPos        Start position for scanning.
 * @param ePos        End position for scanning.
 * @param Info        Optional list to receive position information.
 * @param On_P        Optional callback for each match.
 * @return The resulting string.
}
function U_Replace(p: PUPascalString; OldPattern, NewPattern: TUPascalString; OnlyWord, IgnoreCase: Boolean; bPos, ePos: Integer; Info: TU_BatchInfoList; On_P: TOnUBatchProc): TUPascalString; overload;

{
 * Same for TUPascalString.
}
function U_Replace(s, OldPattern, NewPattern: TUPascalString; OnlyWord, IgnoreCase: Boolean; bPos, ePos: Integer; Info: TU_BatchInfoList; On_P: TOnUBatchProc): TUPascalString; overload;

{
 * Single replace without callback.
}
function U_Replace(s, OldPattern, NewPattern: TUPascalString; OnlyWord, IgnoreCase: Boolean; bPos, ePos: Integer; Info: TU_BatchInfoList): TUPascalString; overload;

{
 * Simplified single replace (entire string).
}
function U_Replace(p: PUPascalString; OldPattern, NewPattern: TUPascalString; OnlyWord, IgnoreCase: Boolean): TUPascalString; overload;
function U_Replace(s, OldPattern, NewPattern: TUPascalString; OnlyWord, IgnoreCase: Boolean): TUPascalString; overload;

{
 * Compute the line and column position (1‑based) of a character index in a string.
 *
 * Useful for error reporting.
 * @param p     Pointer to the string.
 * @param Pos_  Character index (1‑based).
 * @return A TPoint with X = column, Y = line.
}
function U_ComputeTextPoint(p: PUPascalString; Pos_: Integer): TPoint;

implementation

uses Z.MemoryStream, Variants;

{ TU_Batch.Swap_ }
procedure TU_Batch.Swap_(var inst: TU_Batch);
{ *
  * Efficiently exchanges the contents of two batch records by swapping their
  * string instances and the sum counter.
}
begin
  sour.SwapInstance(inst.sour);
  dest.SwapInstance(inst.dest);
  TSwap<Integer>.Do_(sum, inst.sum);
end;

{ U_BuildBatch (THashStringList) }
function U_BuildBatch(L: THashStringList): TU_ArrayBatch;
{ *
  * Iterates over the hash list and copies each key/value pair into a batch array.
  * The origin name becomes the source pattern, and the stored string becomes the destination.
}
var
  arry: TU_ArrayBatch;
  i: Integer;
  p: PHashListData;
begin
  SetLength(arry, L.Count);
  if L.HashList.Count > 0 then
    begin
      i := 0;
      p := L.HashList.FirstPtr;
      while i < L.HashList.Count do
        begin
          arry[i].sour := p^.OriginName;
          arry[i].dest := PHashStringListData(p^.Data)^.v;
          inc(i);
          p := p^.Next;
        end;
    end;
  Result := arry;
end;

{ U_BuildBatch (THashVariantList) }
function U_BuildBatch(L: THashVariantList): TU_ArrayBatch;
{ *
  * Similar to the string version, but converts Variant values to string via VarToStr.
}
var
  arry: TU_ArrayBatch;
  i: Integer;
  p: PHashListData;
begin
  SetLength(arry, L.Count);
  if L.HashList.Count > 0 then
    begin
      i := 0;
      p := L.HashList.FirstPtr;
      while i < L.HashList.Count do
        begin
          arry[i].sour := p^.OriginName;
          arry[i].dest := VarToStr(PHashVariantListData(p^.Data)^.v);
          inc(i);
          p := p^.Next;
        end;
    end;
  Result := arry;
end;

{ U_ClearBatch }
procedure U_ClearBatch(var arry: TU_ArrayBatch);
{ *
  * Frees each entry's strings and resets the array length to zero.
}
var
  i: Integer;
begin
  for i := low(arry) to high(arry) do
    begin
      arry[i].sour := '';
      arry[i].dest := '';
    end;
  SetLength(arry, 0);
end;

{ U_SortBatch }
procedure U_SortBatch(var arry: TU_ArrayBatch);
{ *
  * Sorts the batch array in descending order of source pattern length.
  * Uses a quick sort internally with a comparison that prioritises longer strings.
}

  { Helper: compare two integers for sorting }
  function CompareInt_(const i1, i2: Integer): ShortInt;
  begin
    if i1 = i2 then
        Result := 0
    else if i1 < i2 then
        Result := -1
    else
        Result := 1;
  end;

  { Compare two batch entries by their sour length (longer first) }
  function Compare_(var Left, Right: TU_Batch): ShortInt;
  begin
    Result := CompareInt_(Right.sour.L, Left.sour.L);
  end;

  { Recursive quick sort implementation }
  procedure fastSort_(L, r: Integer);
  var
    i, j: Integer;
    p: TU_Batch;
  begin
    if L < r then
      begin
        repeat
          if (r - L) = 1 then
            begin
              if Compare_(arry[L], arry[r]) > 0 then
                  arry[L].Swap_(arry[r]);
              break;
            end;
          i := L;
          j := r;
          p := arry[(L + r) shr 1];   // Choose middle element as pivot
          repeat
            while Compare_(arry[i], p) < 0 do
                inc(i);
            while Compare_(arry[j], p) > 0 do
                dec(j);
            if i <= j then
              begin
                if i <> j then
                    arry[i].Swap_(arry[j]);
                inc(i);
                dec(j);
              end;
          until i > j;
          // Recurse on smaller partition first to limit stack depth
          if (j - L) > (r - i) then
            begin
              if i < r then
                  fastSort_(i, r);
              r := j;
            end
          else
            begin
              if L < j then
                  fastSort_(L, j);
              L := i;
            end;
        until L >= r;
      end;
  end;

begin
  if length(arry) > 1 then
      fastSort_(0, length(arry) - 1);
end;

{ U_CharIsSymbol (default) }
function U_CharIsSymbol(c: USystemChar): Boolean;
{ *
  * Tests if a character is a symbol using a predefined set that includes
  * whitespace, punctuation, and common operators.
}
begin
  Result := UCharIn(c,
    [#13, #10, #9, #32, #46, #44, #43, #45, #42, #47, #40, #41, #59, #58, #61, #35, #64, #94,
      #38, #37, #33, #34, #91, #93, #60, #62, #63, #123, #125, #39, #36, #124]);
end;

{ U_CharIsSymbol (custom) }
function U_CharIsSymbol(c: USystemChar; const CustomSymbol_: TUArrayChar): Boolean;
{ *
  * Tests if a character is a symbol by checking membership in the provided array.
}
begin
  Result := UCharIn(c, CustomSymbol_);
end;

{ U_IsWord (pointer) }
function U_IsWord(p: PUPascalString; bPos, ePos: Integer): Boolean;
{ *
  * Determines if a substring is a whole word by checking that the characters
  * immediately before and after (if any) are symbols or string boundaries.
}
begin
  if (bPos > ePos) or (bPos < 1) or (ePos > p^.L) then
      Result := False
  else if bPos = 1 then
    begin
      if ePos = p^.L then
          Result := True          // substring covers whole string
      else
          Result := U_CharIsSymbol(p^[ePos + 1]);   // must be followed by symbol
    end
  else if ePos = p^.L then
      Result := U_CharIsSymbol(p^[bPos - 1])        // must be preceded by symbol
  else
      Result := U_CharIsSymbol(p^[bPos - 1]) and U_CharIsSymbol(p^[ePos + 1]);
end;

{ U_IsWord (value) }
function U_IsWord(s: TUPascalString; bPos, ePos: Integer): Boolean;
begin
  Result := U_IsWord(@s, bPos, ePos);
end;

{ U_ExtractWord (default) }
function U_ExtractWord(s: TUPascalString): TUArrayPascalString;
{ *
  * Extracts all words from the string using the default symbol set.
  * First pass counts the number of words to allocate the result array,
  * second pass fills it.
}
var
  i, bPos, ePos, j: Integer;
begin
  SetLength(Result, 0);
  if s.L = 0 then
      exit;

  // First pass: count words
  j := 0;
  i := 1;
  while i <= s.L do
    begin
      // Skip leading symbols
      bPos := i;
      while bPos <= s.L do
        if U_CharIsSymbol(s[bPos]) then
            inc(bPos)
        else
            break;

      // Find end of word (non‑symbol)
      ePos := bPos;
      while ePos <= s.L do
        if not U_CharIsSymbol(s[ePos]) then
            inc(ePos)
        else
            break;

      if ePos > bPos then
          inc(j);
      i := ePos;
    end;

  if j = 0 then
      exit;

  // Second pass: fill array
  SetLength(Result, j);
  j := 0;
  i := 1;
  while i <= s.L do
    begin
      bPos := i;
      while bPos <= s.L do
        if U_CharIsSymbol(s[bPos]) then
            inc(bPos)
        else
            break;

      ePos := bPos;
      while ePos <= s.L do
        if not U_CharIsSymbol(s[ePos]) then
            inc(ePos)
        else
            break;

      if ePos > bPos then
        begin
          Result[j] := s.GetString(bPos, ePos);
          inc(j);
        end;
      i := ePos;
    end;
end;

{ U_ExtractWord (custom) }
function U_ExtractWord(s: TUPascalString; const CustomSymbol_: TUArrayChar): TUArrayPascalString;
{ *
  * Same as default but uses a user‑defined set of symbols.
}
var
  i, bPos, ePos, j: Integer;
begin
  SetLength(Result, 0);
  if s.L = 0 then
      exit;

  // First pass: count words
  j := 0;
  i := 1;
  while i <= s.L do
    begin
      bPos := i;
      while bPos <= s.L do
        if U_CharIsSymbol(s[bPos], CustomSymbol_) then
            inc(bPos)
        else
            break;

      ePos := bPos;
      while ePos <= s.L do
        if not U_CharIsSymbol(s[ePos], CustomSymbol_) then
            inc(ePos)
        else
            break;

      if ePos > bPos then
          inc(j);
      i := ePos;
    end;

  if j = 0 then
      exit;

  // Second pass: fill array
  SetLength(Result, j);
  j := 0;
  i := 1;
  while i <= s.L do
    begin
      bPos := i;
      while bPos <= s.L do
        if U_CharIsSymbol(s[bPos], CustomSymbol_) then
            inc(bPos)
        else
            break;

      ePos := bPos;
      while ePos <= s.L do
        if not U_CharIsSymbol(s[ePos], CustomSymbol_) then
            inc(ePos)
        else
            break;

      if ePos > bPos then
        begin
          Result[j] := s.GetString(bPos, ePos);
          inc(j);
        end;
      i := ePos;
    end;
end;

{ U_BatchSum (pointer) }
function U_BatchSum(p: PUPascalString; var arry: TU_ArrayBatch; OnlyWord, IgnoreCase: Boolean; bPos, ePos: Integer; Info: TU_BatchInfoList): Integer;
{ *
  * Counts matches for all patterns in the batch.
  * For each position, tries to match any pattern in the batch (in array order).
  * If a match is found, increments its sum and advances the scan position.
  * If multiple patterns overlap, the first one matched wins.
}
  function Match_(Pos_: Integer): Integer;
  { * Tries to match any pattern at the current position. Returns the batch index or -1. }
  var
    i: Integer;
  begin
    Result := -1;
    for i := Low(arry) to high(arry) do
      if (arry[i].sour.L > 0) and ((not OnlyWord) or U_IsWord(p, Pos_, Pos_ + arry[i].sour.L - 1))
        and p^.ComparePos(Pos_, @arry[i].sour, IgnoreCase) then
          exit(i);
  end;

var
  i, r, BP, EP: Integer;
  found_: Boolean;
  BatchInfo: TU_BatchInfo;
begin
  Result := 0;
  if p^.L = 0 then
      exit;

  // Normalise search bounds
  if (ePos <= 0) or (ePos > p^.L) then
      EP := p^.L
  else
      EP := ePos;

  if bPos < 1 then
      BP := 1
  else if bPos > EP then
      BP := EP
  else
      BP := bPos;

  // Reset counters
  for i := low(arry) to high(arry) do
      arry[i].sum := 0;

  i := 1;
  while i <= p^.L do
    begin
      found_ := False;
      if (i >= BP) and (i <= EP) then
        begin
          r := Match_(i);
          found_ := r >= 0;
          if found_ then
            begin
              // Record info if requested
              if Info <> nil then
                begin
                  BatchInfo.Batch := r;
                  BatchInfo.sour_bPos := i;
                  BatchInfo.sour_ePos := i + arry[r].sour.L - 1;
                  BatchInfo.dest_bPos := BatchInfo.sour_bPos;   // Not applicable for count
                  BatchInfo.dest_ePos := BatchInfo.sour_ePos;
                  Info.Add(BatchInfo);
                end;
              inc(i, arry[r].sour.L);
              inc(arry[r].sum);
              inc(Result);
            end;
        end;
      if not found_ then
        begin
          inc(i);
        end;
    end;
end;

{ U_BatchSum (value) }
function U_BatchSum(s: TUPascalString; var arry: TU_ArrayBatch; OnlyWord, IgnoreCase: Boolean; bPos, ePos: Integer; Info: TU_BatchInfoList): Integer;
begin
  Result := U_BatchSum(@s, arry, OnlyWord, IgnoreCase, bPos, ePos, Info);
end;

{ U_BatchSum (simplified) }
function U_BatchSum(s: TUPascalString; var arry: TU_ArrayBatch; OnlyWord, IgnoreCase: Boolean; bPos, ePos: Integer): Integer;
begin
  Result := U_BatchSum(@s, arry, OnlyWord, IgnoreCase, bPos, ePos, nil);
end;

{ U_BatchReplace (pointer) }
function U_BatchReplace(p: PUPascalString; var arry: TU_ArrayBatch; OnlyWord, IgnoreCase: Boolean; bPos, ePos: Integer; Info: TU_BatchInfoList; On_P: TOnUBatchProc): TUPascalString;
{ *
  * Performs batch replacement. The result is built in a TMem64 buffer to
  * efficiently accumulate characters and replacements.
  * Patterns are matched in array order; after a match, scanning continues
  * after the matched pattern.
}
  function Match_(Pos_: Integer): Integer;
  { * Finds a matching pattern at the current position. }
  var
    i: Integer;
  begin
    Result := -1;
    for i := Low(arry) to high(arry) do
      if (arry[i].sour.L > 0) and ((not OnlyWord) or U_IsWord(p, Pos_, Pos_ + arry[i].sour.L - 1))
        and p^.ComparePos(Pos_, @arry[i].sour, IgnoreCase) then
          exit(i);
  end;

var
  i, r, BP, EP: Integer;
  found_: Boolean;
  m64: TMem64;                               // Accumulator for the result string
  BatchInfo: TU_BatchInfo;
begin
  Result := '';
  if p^.L = 0 then
      exit;
  m64 := TMem64.CustomCreate(p^.L);          // Pre‑allocate approximately source size

  // Normalise bounds
  if (ePos <= 0) or (ePos > p^.L) then
      EP := p^.L
  else
      EP := ePos;

  if bPos < 1 then
      BP := 1
  else if bPos > EP then
      BP := EP
  else
      BP := bPos;

  // Reset counters
  for i := low(arry) to high(arry) do
      arry[i].sum := 0;

  i := 1;
  while i <= p^.L do
    begin
      found_ := False;
      if (i >= BP) and (i <= EP) then
        begin
          r := Match_(i);
          found_ := r >= 0;
          // Invoke callback if provided
          if found_ and Assigned(On_P) then
              On_P(i, i + (arry[r].sour.L - 1), @arry[r].sour, @arry[r].dest, found_);
          if found_ then
            begin
              // Record replacement info
              if Info <> nil then
                begin
                  BatchInfo.Batch := r;
                  BatchInfo.sour_bPos := i;
                  BatchInfo.sour_ePos := i + (arry[r].sour.L - 1);
                  BatchInfo.dest_bPos := m64.Size div USystemCharSize + 1;   // Position after current buffer
                  BatchInfo.dest_ePos := BatchInfo.dest_bPos + (arry[r].dest.L - 1);
                  Info.Add(BatchInfo);
                end;
              // Append replacement string
              if arry[r].dest.L > 0 then
                  m64.Write64(arry[r].dest.buff[0], USystemCharSize * arry[r].dest.L);
              inc(arry[r].sum);
              inc(i, arry[r].sour.L);
            end;
        end;
      if not found_ then
        begin
          // Append original character
          m64.Write64(p^.buff[i - 1], USystemCharSize);
          inc(i);
        end;
    end;
  // Convert accumulated buffer to a TUPascalString
  Result.L := m64.Size div USystemCharSize;
  if Result.L > 0 then
      CopyPtr(m64.Memory, @Result.buff[0], m64.Size);
  DisposeObject(m64);
end;

{ U_BatchReplace (value, with callback) }
function U_BatchReplace(s: TUPascalString; var arry: TU_ArrayBatch; OnlyWord, IgnoreCase: Boolean; bPos, ePos: Integer; Info: TU_BatchInfoList; On_P: TOnUBatchProc): TUPascalString;
begin
  Result := U_BatchReplace(@s, arry, OnlyWord, IgnoreCase, bPos, ePos, Info, On_P);
end;

{ U_BatchReplace (value, no callback) }
function U_BatchReplace(s: TUPascalString; var arry: TU_ArrayBatch; OnlyWord, IgnoreCase: Boolean; bPos, ePos: Integer; Info: TU_BatchInfoList): TUPascalString;
begin
  Result := U_BatchReplace(@s, arry, OnlyWord, IgnoreCase, bPos, ePos, Info, nil);
end;

{ U_BatchReplace (simplified) }
function U_BatchReplace(s: TUPascalString; var arry: TU_ArrayBatch; OnlyWord, IgnoreCase: Boolean; bPos, ePos: Integer): TUPascalString;
begin
  Result := U_BatchReplace(@s, arry, OnlyWord, IgnoreCase, bPos, ePos, nil, nil);
end;

{ U_ReplaceSum (pointer) }
function U_ReplaceSum(p: PUPascalString; Pattern: TUPascalString; OnlyWord, IgnoreCase: Boolean; bPos, ePos: Integer; Info: TU_BatchInfoList): Integer;
{ *
  * Counts occurrences of a single pattern. Similar logic to U_BatchSum
  * but for one pattern.
}
var
  i, BP, EP: Integer;
  found_: Boolean;
  BatchInfo: TU_BatchInfo;
begin
  Result := 0;
  if p^.L = 0 then
      exit;

  if (ePos <= 0) or (ePos > p^.L) then
      EP := p^.L
  else
      EP := ePos;

  if bPos < 1 then
      BP := 1
  else if bPos > EP then
      BP := EP
  else
      BP := bPos;

  i := 1;
  while i <= p^.L do
    begin
      found_ := False;
      if (i >= BP) and (i <= EP) then
        begin
          found_ := ((not OnlyWord) or U_IsWord(p, i, i + Pattern.L - 1)) and p^.ComparePos(i, @Pattern, IgnoreCase);
          if found_ then
            begin
              if Info <> nil then
                begin
                  BatchInfo.Batch := -1;               // Single pattern has no batch index
                  BatchInfo.sour_bPos := i;
                  BatchInfo.sour_ePos := BatchInfo.sour_bPos + (Pattern.L - 1);
                  BatchInfo.dest_bPos := BatchInfo.sour_bPos;
                  BatchInfo.dest_ePos := BatchInfo.sour_ePos;
                  Info.Add(BatchInfo);
                end;
              inc(i, Pattern.L);
              inc(Result);
            end;
        end;
      if not found_ then
          inc(i);
    end;
end;

{ U_ReplaceSum (value) }
function U_ReplaceSum(s, Pattern: TUPascalString; OnlyWord, IgnoreCase: Boolean; bPos, ePos: Integer; Info: TU_BatchInfoList): Integer;
begin
  Result := U_ReplaceSum(@s, Pattern, OnlyWord, IgnoreCase, bPos, ePos, Info);
end;

{ U_Replace (pointer, with callback) }
function U_Replace(p: PUPascalString; OldPattern, NewPattern: TUPascalString; OnlyWord, IgnoreCase: Boolean; bPos, ePos: Integer; Info: TU_BatchInfoList; On_P: TOnUBatchProc): TUPascalString;
{ *
  * Replaces a single pattern. Similar to U_BatchReplace but for one pattern.
  * If OldPattern is empty, the source string is returned unchanged.
}
var
  i, BP, EP: Integer;
  found_: Boolean;
  m64: TMem64;
  BatchInfo: TU_BatchInfo;
begin
  Result := '';
  if p^.L = 0 then
      exit;
  if OldPattern.L = 0 then
    begin
      Result := p^;
      exit;
    end;
  m64 := TMem64.CustomCreate(p^.L);

  // Normalise bounds
  if (ePos <= 0) or (ePos > p^.L) then
      EP := p^.L
  else
      EP := ePos;

  if bPos < 1 then
      BP := 1
  else if bPos > EP then
      BP := EP
  else
      BP := bPos;

  i := 1;
  while i <= p^.L do
    begin
      found_ := False;
      if (i >= BP) and (i <= EP) then
        begin
          found_ := ((not OnlyWord) or U_IsWord(p, i, i + OldPattern.L - 1)) and p^.ComparePos(i, @OldPattern, IgnoreCase);
          if found_ and Assigned(On_P) then
              On_P(i, i + (OldPattern.L - 1), @OldPattern, @NewPattern, found_);
          if found_ then
            begin
              if Info <> nil then
                begin
                  BatchInfo.Batch := -1;
                  BatchInfo.sour_bPos := i;
                  BatchInfo.sour_ePos := i + (OldPattern.L - 1);
                  BatchInfo.dest_bPos := m64.Size div USystemCharSize + 1;
                  BatchInfo.dest_ePos := BatchInfo.dest_bPos + (NewPattern.L - 1);
                  Info.Add(BatchInfo);
                end;
              m64.Write64(NewPattern.buff[0], USystemCharSize * NewPattern.L);
              inc(i, OldPattern.L);
            end;
        end;
      if not found_ then
        begin
          m64.Write64(p^.buff[i - 1], USystemCharSize);
          inc(i);
        end;
    end;
  Result.L := m64.Size div USystemCharSize;
  if Result.L > 0 then
      CopyPtr(m64.Memory, @Result.buff[0], m64.Size);
  DisposeObject(m64);
end;

{ U_Replace (value, with callback) }
function U_Replace(s, OldPattern, NewPattern: TUPascalString; OnlyWord, IgnoreCase: Boolean; bPos, ePos: Integer; Info: TU_BatchInfoList; On_P: TOnUBatchProc): TUPascalString;
begin
  Result := U_Replace(@s, OldPattern, NewPattern, OnlyWord, IgnoreCase, bPos, ePos, Info, On_P);
end;

{ U_Replace (value, no callback) }
function U_Replace(s, OldPattern, NewPattern: TUPascalString; OnlyWord, IgnoreCase: Boolean; bPos, ePos: Integer; Info: TU_BatchInfoList): TUPascalString;
begin
  Result := U_Replace(@s, OldPattern, NewPattern, OnlyWord, IgnoreCase, bPos, ePos, Info, nil);
end;

{ U_Replace (simplified, pointer) }
function U_Replace(p: PUPascalString; OldPattern, NewPattern: TUPascalString; OnlyWord, IgnoreCase: Boolean): TUPascalString;
{ *
  * Simplified version without bounds or callback. Scans the entire string.
}
var
  i, r: Integer;
  m64: TMem64;
begin
  Result := '';
  if p^.L = 0 then
      exit;
  if OldPattern.L = 0 then
    begin
      Result := p^;
      exit;
    end;
  m64 := TMem64.CustomCreate(p^.L);
  i := 1;
  while i <= p^.L do
    begin
      if ((not OnlyWord) or U_IsWord(p, i, i + OldPattern.L - 1)) and p^.ComparePos(i, @OldPattern, IgnoreCase) then
        begin
          m64.Write64(NewPattern.buff[0], USystemCharSize * NewPattern.L);
          inc(i, OldPattern.L);
        end
      else
        begin
          m64.Write64(p^.buff[i - 1], USystemCharSize);
          inc(i);
        end;
    end;
  Result.L := m64.Size div USystemCharSize;
  if Result.L > 0 then
      CopyPtr(m64.Memory, @Result.buff[0], m64.Size);
  DisposeObject(m64);
end;

{ U_Replace (simplified, value) }
function U_Replace(s, OldPattern, NewPattern: TUPascalString; OnlyWord, IgnoreCase: Boolean): TUPascalString;
begin
  Result := U_Replace(@s, OldPattern, NewPattern, OnlyWord, IgnoreCase);
end;

{ U_ComputeTextPoint }
function U_ComputeTextPoint(p: PUPascalString; Pos_: Integer): TPoint;
{ *
  * Computes the line (Y) and column (X) of a given character index.
  * Lines are separated by #10 (LF) or #13 (CR) – CR is handled as a line break
  * but columns are not incremented for CR.
}
var
  i, j: Integer;
begin
  Result.X := 1;
  Result.Y := 1;
  if Pos_ < p^.L then
      j := Pos_
  else
      j := p^.L;
  for i := 1 to j do
    if p^[i] = #10 then
      begin
        Result.X := 1;
        inc(Result.Y);
      end
    else if p^[i] = #13 then
        Result.X := 0
    else
        inc(Result.X);
end;

end.

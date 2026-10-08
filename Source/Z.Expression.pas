{ ******************************************************************************
  * Z.Expression - Dynamic Expression Parser and Evaluation Engine
  *
  * This unit provides a complete infrastructure for parsing, compiling, and
  * executing runtime string-based expressions. It transforms human-readable
  * formulas (e.g., 'sin(x) * 10 + 5') into executable OpCodes.
  *
  * Architecture Overview:
  *   1. Lexical Analysis & Parsing: Converts raw text into a flat list of
  *      symbols, values, and identifiers using a recursive descent parser.
  *   2. Precedence Rebuilding: Re-organizes the flat list into a hierarchical
  *      AST by injecting virtual parentheses based on operator priorities.
  *   3. Code Generation: Maps the AST to native TOpCode objects (Add, Sub,
  *      Proc, etc.) which are executable by the Z.OpCode runtime.
  *   4. Caching: Compiled OpCodes are cached by the expression string to avoid
  *      redundant parsing and compilation for repeated calls.
  *
  * Callback Styles:
  *   The parser supports three styles of callbacks for resolving unknown
  *   identifiers (variables/functions):
  *     - _C: Plain procedural/global function pointers.
  *     - _M: Object methods (of object).
  *     - _P: Anonymous methods / nested procedures / references.
  ****************************************************************************** }
unit Z.Expression;

{$DEFINE FPC_DELPHI_MODE}
{$I Z.Define.inc}

interface

uses
  SysUtils, Variants,
{$IFDEF FPC}
  Z.FPC.GenericList,
{$ENDIF FPC}
  Z.Core, TypInfo, Z.Parsing, Z.PascalStrings, Z.UPascalStrings, Z.UnicodeMixedLib,
  Z.Status, Z.ListEngine, Z.OpCode;

type
{$REGION 'internal define'}
  {
    TSymbolOperation enumerates all possible operators and structural tokens
    supported by the expression engine.
    @value soAdd            Addition operator (+)
    @value soSub            Subtraction operator (-)
    @value soMul            Multiplication operator (*)
    @value soDiv            Floating-point division operator (/)
    @value soMod            Modulo operator (mod or %)
    @value soIntDiv         Integer division operator (div or idiv)
    @value soPow            Power operator (^)
    @value soOr             Logical OR (or or ||)
    @value soAnd            Logical AND (and or &&)
    @value soXor            Logical XOR (xor)
    @value soEqual          Equality comparison (== or =)
    @value soLessThan       Less than comparison (<)
    @value soEqualOrLessThan Less than or equal to comparison (<=)
    @value soGreaterThan    Greater than comparison (>)
    @value soEqualOrGreaterThan Greater than or equal to comparison (=> or >=)
    @value soNotEqual       Inequality comparison (<> or !=)
    @value soShl            Bitwise shift left (shl or <<)
    @value soShr            Bitwise shift right (shr or >>)
    @value soBlockIndentBegin Left parenthesis for expression grouping
    @value soBlockIndentEnd Right parenthesis for expression grouping
    @value soPropIndentBegin Left bracket for property/index grouping
    @value soPropIndentEnd Right bracket for property/index grouping
    @value soDotSymbol      Dot operator for member access
    @value soCommaSymbol    Comma used for separating parameters or vector elements
    @value soEolSymbol      End-of-line marker (semicolon)
    @value soProc           Marker indicating a procedure/function call
    @value soParameter      Marker for parameter separation inside function calls
    @value soUnknow         Unknown or invalid symbol
  }
  TSymbolOperation = (
    soAdd, soSub, soMul, soDiv, soMod, soIntDiv, soPow, soOr, soAnd, soXor,
    soEqual, soLessThan, soEqualOrLessThan, soGreaterThan, soEqualOrGreaterThan,
    soNotEqual,
    soShl, soShr,
    soBlockIndentBegin, soBlockIndentEnd,
    soPropIndentBegin, soPropIndentEnd,
    soDotSymbol, soCommaSymbol,
    soEolSymbol,
    soProc, soParameter,
    soUnknow
    );

  TSymbolOperations = set of TSymbolOperation;

  {
    TExpressionDeclType defines the data type of a parsed value or identifier.
    This is used internally to determine how to store the variant and which
    OpCode value type to generate.
  }
  TExpressionDeclType = (
    edtSymbol, { Purely a structural symbol (e.g., operator) }
    edtBool, edtInt, edtInt64, edtUInt64, edtWord, edtByte, edtSmallInt,
    edtShortInt, edtUInt, { Integer/Fixed-size numeric types }
    edtSingle, edtDouble, edtCurrency, { Floating-point and currency types }
    edtString, { String literal }
    edtProcExp, { Function/Procedure call }
    edtExpressionAsValue, { A sub-expression treated as a value (parentheses) }
    edtUnknow { Unknown or unresolved type }
    );
  TExpressionDeclTypes = set of TExpressionDeclType;

  { Forward declaration for recursive expression structures }
  TSymbolExpression = class;

  {
    TExpressionListData represents a single node in the flat parsed expression list.
    It holds the token type, its position in the source string, the associated
    symbol (if any), the raw variant value, and a reference to any nested
    sub-expression (e.g., for function arguments or parenthesis groups).
  }
  TExpressionListData = record
    dType: TExpressionDeclType; { The classified type of this token }
    cPos: Integer; { Character position in the original text }
    Symbol: TSymbolOperation; { The operator/symbol if this node is a symbol }
    Value: Variant; { The actual value (number, string, or function name) }
    Expression: TSymbolExpression; { Sub-expression (e.g., inside parentheses or function params) }
    ExpressionAutoFree: Boolean; { Indicates if the sub-expression should be auto-freed }
  end;

  PExpressionListData = ^TExpressionListData;

  {
    TNumTextType is used internally by the lexer to automatically detect the
    most appropriate numeric type from a string representation (e.g., '255' ->
    Byte, '3.14' -> Single/Double).
  }
  TNumTextType = (nttBool, nttInt, nttInt64, nttUInt64, nttWord, nttByte,
    nttSmallInt, nttShortInt, nttUInt,
    nttSingle, nttDouble, nttCurrency,
    nttUnknow);

  TExpressionData_Pool = TGenericsList<PExpressionListData>;

  {
    TSymbolExpression is the core container for a parsed expression.
    It holds a list of tokens (TExpressionListData) and serves as the
    intermediate representation (IR) between the parser and the code generator.
    It can represent a simple value, a complex formula, or a function call tree.
  }
  TSymbolExpression = class sealed(TCore_Object)
  protected
    FList: TExpressionData_Pool;
    FTextStyle: TTextStyle; { Defines string quoting and comment styles }
  public
    constructor Create(const TextStyle_: TTextStyle);
    destructor Destroy; override;

    property TextStyle: TTextStyle read FTextStyle;

    { Clears all data and frees any owned sub-expressions }
    procedure Clear;

    { Debug utilities: prints the structure and tokens to the status output }
    procedure PrintDebug(const detail: Boolean; const prefix: SystemString); overload;
    procedure PrintDebug(const detail: Boolean); overload;

    { Reconstructs the original source string from the parsed tree }
    function Decl(): SystemString;

    { Queries statistics about the contained tokens }
    function GetCount(t: TExpressionDeclTypes): Integer;
    function GetSymbolCount(Operations: TSymbolOperations): Integer;
    function AvailValueCount: Integer; { Count of actual data tokens }
    function Count: Integer;

    { Insertion methods for building the expression tree }
    function InsertSymbol(const idx: Integer; v: TSymbolOperation; cPos: Integer): PExpressionListData;
    function Insert(const idx: Integer; v: TExpressionListData): PExpressionListData;

    { Appends the entire content of another expression to this one }
    procedure AddExpression(const exp_: TSymbolExpression);

    { Concrete value/symbol appenders }
    function AddSymbol(const v: TSymbolOperation; cPos: Integer): PExpressionListData;
    function AddBool(const v: Boolean; cPos: Integer): PExpressionListData;
    function AddInt(const v: Integer; cPos: Integer): PExpressionListData;
    function AddUInt(const v: Cardinal; cPos: Integer): PExpressionListData;
    function AddInt64(const v: Int64; cPos: Integer): PExpressionListData;
    function AddUInt64(const v: UInt64; cPos: Integer): PExpressionListData;
    function AddWord(const v: Word; cPos: Integer): PExpressionListData;
    function AddByte(const v: Byte; cPos: Integer): PExpressionListData;
    function AddSmallInt(const v: SmallInt; cPos: Integer): PExpressionListData;
    function AddShortInt(const v: ShortInt; cPos: Integer): PExpressionListData;
    function AddSingle(const v: Single; cPos: Integer): PExpressionListData;
    function AddDouble(const v: Double; cPos: Integer): PExpressionListData;
    function AddCurrency(const v: Currency; cPos: Integer): PExpressionListData;
    function AddString(const v: SystemString; cPos: Integer): PExpressionListData;

    { Add a function/procedure identifier }
    function AddFunc(const v: SystemString; cPos: Integer): PExpressionListData;

    { Add a sub-expression as a value (typically wrapped in parentheses or brackets) }
    function AddExpressionAsValue(AutoFree: Boolean; Expression: TSymbolExpression;
      Symbol: TSymbolOperation; Value: Variant; cPos: Integer): PExpressionListData;

    function Add(var v: TExpressionListData): PExpressionListData;
    function AddCopy(var v: TExpressionListData): PExpressionListData;

    { Deletion utilities }
    procedure Delete(const idx: Integer);
    procedure DeleteLast;

    function Last: PExpressionListData;
    function First: PExpressionListData;

    { Finds the index of a specific node pointer }
    function IndexOf(p: PExpressionListData): Integer;

    { Indexed access to the underlying list }
    function GetItems(index: Integer): PExpressionListData;
    property Items[index: Integer]: PExpressionListData read GetItems; default;
  end;

  {
    Callback definitions for resolving unknown identifiers during parsing.
    These delegates are invoked when the parser encounters a variable or
    function name that is not a built-in literal.
    @param Decl  The identifier string (e.g., "PlayerHealth", "Sin")
    @param ValType  Must be set to the detected data type (edtInt, edtString, etc.)
    @param Value   Must be set to the actual variant value.
  }
  TOnDeclValue_C = procedure(const Decl: SystemString; var ValType: TExpressionDeclType; var Value: Variant);
  TOnDeclValue_M = procedure(const Decl: SystemString; var ValType: TExpressionDeclType; var Value: Variant) of object;
{$IFDEF FPC}
  TOnDeclValue_P = procedure(const Decl: SystemString; var ValType: TExpressionDeclType; var Value: Variant) is nested;
{$ELSE FPC}
  TOnDeclValue_P = reference to procedure(const Decl: SystemString; var ValType: TExpressionDeclType; var Value: Variant);
{$ENDIF FPC}
  { State flags used during the parsing state machine }
  TExpressionParsingState = set of (esFirst, esWaitOp, esWaitIndentEnd, esWaitPropParamIndentEnd, esWaitValue);
  PExpressionParsingState = ^TExpressionParsingState;

  { Array and Matrix types for vectorized expression evaluation }
  TExpressionValueVector = array of Variant;
  PExpressionValueVector = ^TExpressionValueVector;
  TExpressionValueMatrix = array of TExpressionValueVector;
  PExpressionValueMatrix = ^TExpressionValueMatrix;

  {
    Determines the most accurate numeric data type from a string representation.
    Used internally to select the smallest possible storage type (Byte, Word,
    Integer, Single, etc.) based on the text content.
  }
function NumTextType(s: TPascalString): TNumTextType;

{ Initializes an empty expression list record }
procedure InitExp(var v: TExpressionListData);

{ Converts an expression declaration type to the corresponding OpCode value type }
function dt2op(const v: TExpressionDeclType): TOpValueType;

{ Infers the expression declaration type from a variant's internal type }
function VariantToExpressionDeclType(var v: Variant): TExpressionDeclType;

{ Helper to parse a logical operation state from the text parser }
function ParseOperationState(ParsingTool_: TTextParsing;
  var cPos, bPos, ePos, BlockIndent, PropIndent: Integer;
  var pStates: TExpressionParsingState): TSymbolOperation;

{ Main procedural parser that populates a TSymbolExpression }
function ParseSymbol(ParsingTool_: TTextParsing; WorkSym: TSymbolExpression;
  var cPos, bPos, ePos, BlockIndent, PropIndent: Integer;
  pStates: PExpressionParsingState): Boolean;

{ Overloaded entry points for parsing text into a TSymbolExpression.
  These use the anonymous internal parser and accept different callback styles. }
function ParseTextExpressionAsSymbol__(ParsingTool_: TTextParsing; const uName: SystemString;
  const OnDeclValue_C: TOnDeclValue_C; const OnDeclValue_M: TOnDeclValue_M;
  const OnDeclValue_P: TOnDeclValue_P; RefrenceOpRT: TOpCustomRunTime): TSymbolExpression;

{ Public API: Parse text into Symbol Expression (Callback C style) }
function ParseTextExpressionAsSymbol_C(ParsingTool_: TTextParsing; const uName: SystemString;
  const OnGetValue: TOnDeclValue_C; RefrenceOpRT: TOpCustomRunTime): TSymbolExpression; overload;

{ Public API: Parse text into Symbol Expression (Callback M style) }
function ParseTextExpressionAsSymbol_M(ParsingTool_: TTextParsing; const uName: SystemString;
  const OnGetValue: TOnDeclValue_M; RefrenceOpRT: TOpCustomRunTime): TSymbolExpression; overload;

{ Public API: Parse text into Symbol Expression (Callback P style) }
function ParseTextExpressionAsSymbol_P(ParsingTool_: TTextParsing; const uName: SystemString;
  const OnGetValue: TOnDeclValue_P; RefrenceOpRT: TOpCustomRunTime): TSymbolExpression; overload;

{ Overloaded convenience wrappers for parsing with different parameter sets }
function ParseTextExpressionAsSymbol(Special_ASCII_: TListPascalString;
  TextStyle: TTextStyle; const uName, ExpressionText: SystemString;
  const OnGetValue: TOnDeclValue_M; RefrenceOpRT: TOpCustomRunTime): TSymbolExpression; overload;
function ParseTextExpressionAsSymbol(TextStyle: TTextStyle; const uName, ExpressionText: SystemString;
  const OnGetValue: TOnDeclValue_M; RefrenceOpRT: TOpCustomRunTime): TSymbolExpression; overload;
function ParseTextExpressionAsSymbol(Special_ASCII_: TListPascalString; ExpressionText: SystemString;
  RefrenceOpRT: TOpCustomRunTime): TSymbolExpression; overload;
function ParseTextExpressionAsSymbol(ExpressionText: SystemString; RefrenceOpRT: TOpCustomRunTime): TSymbolExpression; overload;
function ParseTextExpressionAsSymbol(Special_ASCII_: TListPascalString; ExpressionText: SystemString): TSymbolExpression; overload;
function ParseTextExpressionAsSymbol(ExpressionText: SystemString): TSymbolExpression; overload;

{ More overloaded versions allowing specification of the TextParsing class }
function ParseTextExpressionAsSymbol_M(Special_ASCII_: TListPascalString;
  TextEngClass: TTextParsingClass; TextStyle: TTextStyle; const uName, ExpressionText: SystemString;
  const OnGetValue: TOnDeclValue_M; RefrenceOpRT: TOpCustomRunTime): TSymbolExpression; overload;
function ParseTextExpressionAsSymbol_M(TextEngClass: TTextParsingClass; TextStyle: TTextStyle;
  const uName, ExpressionText: SystemString; const OnGetValue: TOnDeclValue_M;
  RefrenceOpRT: TOpCustomRunTime): TSymbolExpression; overload;
function ParseTextExpressionAsSymbol_C(Special_ASCII_: TListPascalString;
  TextEngClass: TTextParsingClass; TextStyle: TTextStyle; const uName, ExpressionText: SystemString;
  const OnGetValue: TOnDeclValue_C; RefrenceOpRT: TOpCustomRunTime): TSymbolExpression; overload;
function ParseTextExpressionAsSymbol_C(TextEngClass: TTextParsingClass; TextStyle: TTextStyle;
  const uName, ExpressionText: SystemString; const OnGetValue: TOnDeclValue_C;
  RefrenceOpRT: TOpCustomRunTime): TSymbolExpression; overload;
function ParseTextExpressionAsSymbol_P(Special_ASCII_: TListPascalString;
  TextEngClass: TTextParsingClass; TextStyle: TTextStyle; const uName, ExpressionText: SystemString;
  const OnGetValue: TOnDeclValue_P; RefrenceOpRT: TOpCustomRunTime): TSymbolExpression; overload;
function ParseTextExpressionAsSymbol_P(TextEngClass: TTextParsingClass; TextStyle: TTextStyle;
  const uName, ExpressionText: SystemString; const OnGetValue: TOnDeclValue_P;
  RefrenceOpRT: TOpCustomRunTime): TSymbolExpression; overload;

{
  Applies standard mathematical precedence to a flat symbol list.
  This is the first step of code optimization. It analyzes the list and inserts
  virtual parentheses based on the priority table (e.g., multiplication before
  addition).
}
function RebuildLogicalPrioritySymbol(Exps: TSymbolExpression): TSymbolExpression;

{
  Full structural rebuild of the expression.
  Handles nested parentheses, function arguments, and then delegates to
  RebuildLogicalPrioritySymbol to resolve precedence. This produces a fully
  hierarchical tree ready for OpCode generation.
}
function RebuildAllSymbol(Exps: TSymbolExpression): TSymbolExpression;

{
  Converts a TSymbolExpression into a compiled TOpCode object.
  This is the core code generation phase. It walks the hierarchical symbol tree
  and instantiates corresponding operator/procedure OpCode classes.
}
function BuildAsOpCode(DebugMode: Boolean; SymbExps: TSymbolExpression;
  const uName: SystemString; LineNo: Integer): TOpCode; overload;
function BuildAsOpCode(SymbExps: TSymbolExpression): TOpCode; overload;
function BuildAsOpCode(DebugMode: Boolean; SymbExps: TSymbolExpression): TOpCode; overload;
function BuildAsOpCode(DebugMode: Boolean; TextStyle: TTextStyle;
  ExpressionText: SystemString): TOpCode; overload;
function BuildAsOpCode(TextStyle: TTextStyle; ExpressionText: SystemString): TOpCode; overload;
function BuildAsOpCode(ExpressionText: SystemString): TOpCode; overload;
function BuildAsOpCode(DebugMode: Boolean; TextStyle: TTextStyle;
  ExpressionText: SystemString; RefrenceOpRT: TOpCustomRunTime): TOpCode; overload;
function BuildAsOpCode(TextStyle: TTextStyle; ExpressionText: SystemString;
  RefrenceOpRT: TOpCustomRunTime): TOpCode; overload;
function BuildAsOpCode(ExpressionText: SystemString; RefrenceOpRT: TOpCustomRunTime): TOpCode; overload;

{
  Evaluates a text expression and returns the computed Variant result.
  These functions combine parsing, rebuilding, compilation, and execution
  into a single call. They utilize a global cache to skip recompilation.
}
function EvaluateExpressionValue_M(UsedCache: Boolean; Special_ASCII_: TListPascalString;
  TextEngClass: TTextParsingClass; TextStyle: TTextStyle; ExpressionText: SystemString;
  const OnGetValue: TOnDeclValue_M): Variant;
function EvaluateExpressionValue_C(UsedCache: Boolean; Special_ASCII_: TListPascalString;
  TextEngClass: TTextParsingClass; TextStyle: TTextStyle; ExpressionText: SystemString;
  const OnGetValue: TOnDeclValue_C): Variant;
function EvaluateExpressionValue_P(UsedCache: Boolean; Special_ASCII_: TListPascalString;
  TextEngClass: TTextParsingClass; TextStyle: TTextStyle; ExpressionText: SystemString;
  const OnGetValue: TOnDeclValue_P): Variant;
{$ENDREGION 'internal define'}

{
  Returns the global OpCode cache pool instance.
  This cache stores compiled TOpCode objects keyed by their source string,
  dramatically improving performance for repeated expressions.
}
function OpCache: TOpCode_Pool;

{ Clears all items from the global OpCode cache. Useful for freeing memory. }
procedure CleanOpCache();

{
  ----------------------------------------------------------------------------
  High-Level Public API for Expression Evaluation
  ----------------------------------------------------------------------------
}

{ Checks if an expression string is effectively empty or contains only whitespace/comments }
function IsNullExpression(ExpressionText: SystemString; TextStyle: TTextStyle): Boolean;

{ Checks if the expression is a vector (contains commas or semicolons as top-level delimiters) }
function IsSymbolVectorExpression(ExpressionText: SystemString; TextStyle: TTextStyle;
  Special_ASCII_: TListPascalString): Boolean; overload;
function IsSymbolVectorExpression(ExpressionText: SystemString; TextStyle: TTextStyle): Boolean; overload;

{
  The main workhorse evaluation function.
  Supports optional OpCode caching, custom ASCII symbol lists, debug output,
  text styles, custom runtime contexts, and constant variant lists.
}
function EvaluateExpressionValue(UsedCache: Boolean;
  Special_ASCII_: TListPascalString; DebugMode: Boolean; TextStyle: TTextStyle;
  ExpressionText: SystemString; opRT: TOpCustomRunTime; const_vl: THashVariantList): Variant; overload;

function EvaluateExpressionValue(UsedCache: Boolean; Special_ASCII_: TListPascalString;
  DebugMode: Boolean; TextStyle: TTextStyle; ExpressionText: SystemString;
  opRT: TOpCustomRunTime): Variant; overload;

{ Simplified overloads assuming default Pascal style and system runtime }
function EvaluateExpressionValue(UsedCache: Boolean; ExpressionText: SystemString;
  opRT: TOpCustomRunTime): Variant; overload;
function EvaluateExpressionValue(UsedCache: Boolean; ExpressionText: SystemString): Variant; overload;
function EvaluateExpressionValue(UsedCache: Boolean; TextStyle: TTextStyle;
  ExpressionText: SystemString): Variant; overload;
function EvaluateExpressionValue(UsedCache: Boolean; TextStyle: TTextStyle;
  ExpressionText: SystemString; opRT: TOpCustomRunTime): Variant; overload;
function EvaluateExpressionValue(UsedCache: Boolean; Special_ASCII_: TListPascalString;
  DebugMode: Boolean; ExpressionText: SystemString; opRT: TOpCustomRunTime): Variant; overload;
function EvaluateExpressionValue(UsedCache: Boolean; Special_ASCII_: TListPascalString;
  ExpressionText: SystemString; opRT: TOpCustomRunTime): Variant; overload;
function EvaluateExpressionValue(UsedCache: Boolean; Special_ASCII_: TListPascalString;
  DebugMode: Boolean; ExpressionText: SystemString): Variant; overload;
function EvaluateExpressionValue(UsedCache: Boolean; Special_ASCII_: TListPascalString;
  ExpressionText: SystemString): Variant; overload;
function EvaluateExpressionValue(UsedCache: Boolean; Special_ASCII_: TListPascalString;
  TextStyle: TTextStyle; ExpressionText: SystemString; opRT: TOpCustomRunTime): Variant; overload;

{ Non-cached default calls (UsedCache is implicitly True in most overloads below) }
function EvaluateExpressionValue(ExpressionText: SystemString; opRT: TOpCustomRunTime): Variant; overload;
function EvaluateExpressionValue(ExpressionText: SystemString): Variant; overload;
function EvaluateExpressionValue(TextStyle: TTextStyle; ExpressionText: SystemString): Variant; overload;
function EvaluateExpressionValue(TextStyle: TTextStyle; ExpressionText: SystemString;
  opRT: TOpCustomRunTime): Variant; overload;
function EvaluateExpressionValue(Special_ASCII_: TListPascalString; DebugMode: Boolean;
  ExpressionText: SystemString; opRT: TOpCustomRunTime): Variant; overload;
function EvaluateExpressionValue(Special_ASCII_: TListPascalString; ExpressionText: SystemString;
  opRT: TOpCustomRunTime): Variant; overload;
function EvaluateExpressionValue(Special_ASCII_: TListPascalString; DebugMode: Boolean;
  ExpressionText: SystemString): Variant; overload;
function EvaluateExpressionValue(Special_ASCII_: TListPascalString; ExpressionText: SystemString): Variant; overload;
function EvaluateExpressionValue(Special_ASCII_: TListPascalString; TextStyle: TTextStyle;
  ExpressionText: SystemString; opRT: TOpCustomRunTime): Variant; overload;

{
  Vector Evaluation: Splits the input text by comma/semicolon and evaluates
  each segment separately, returning an array of Variants.
}
function EvaluateExpressionVector(DebugMode, UsedCache: Boolean;
  Special_ASCII_: TListPascalString; TextStyle: TTextStyle; ExpressionText: SystemString;
  opRT: TOpCustomRunTime; const_vl: THashVariantList): TExpressionValueVector; overload;
function EvaluateExpressionVector(UsedCache: Boolean; Special_ASCII_: TListPascalString;
  TextStyle: TTextStyle; ExpressionText: SystemString; opRT: TOpCustomRunTime;
  const_vl: THashVariantList): TExpressionValueVector; overload;
function EvaluateExpressionVector(Special_ASCII_: TListPascalString; TextStyle: TTextStyle;
  ExpressionText: SystemString; opRT: TOpCustomRunTime;
  const_vl: THashVariantList): TExpressionValueVector; overload;
function EvaluateExpressionVector(ExpressionText: SystemString; opRT: TOpCustomRunTime;
  const_vl: THashVariantList): TExpressionValueVector; overload;
function EvaluateExpressionVector(ExpressionText: SystemString;
  const_vl: THashVariantList): TExpressionValueVector; overload;
function EvaluateExpressionVector(ExpressionText: SystemString;
  TextStyle: TTextStyle): TExpressionValueVector; overload;
function EvaluateExpressionVector(ExpressionText: SystemString): TExpressionValueVector; overload;

{
  Matrix Evaluation: Extracts a flat vector from the expression and re-shapes
  it into a 2D matrix of size Width x Height.
}
function EvaluateExpressionMatrix(W, H: Integer; Special_ASCII_: TListPascalString;
  TextStyle: TTextStyle; ExpressionText: SystemString; opRT: TOpCustomRunTime;
  const_vl: THashVariantList): TExpressionValueMatrix; overload;
function EvaluateExpressionMatrix(W, H: Integer; ExpressionText: SystemString;
  opRT: TOpCustomRunTime; const_vl: THashVariantList): TExpressionValueMatrix; overload;
function EvaluateExpressionMatrix(W, H: Integer; ExpressionText: SystemString;
  const_vl: THashVariantList): TExpressionValueMatrix; overload;
function EvaluateExpressionMatrix(W, H: Integer; ExpressionText: SystemString;
  TextStyle: TTextStyle): TExpressionValueMatrix; overload;
function EvaluateExpressionMatrix(W, H: Integer; ExpressionText: SystemString): TExpressionValueMatrix; overload;

{
  ----------------------------------------------------------------------------
  Ultra-simple Helper Functions (EStr = Expression String)
  These provide one-liner evaluation for common data types with default fallbacks.
  ----------------------------------------------------------------------------
}
function EStr(s: U_String): U_String;
function EStrToBool(s: U_String; default: Boolean): Boolean; overload;
function EStrToBool(s: U_String): Boolean; overload;
function EStrToInt(s: U_String; default: Integer): Integer; overload;
function EStrToInt(s: U_String): Integer; overload;
function EStrToInt64(s: U_String; default: Int64): Int64; overload;
function EStrToInt64(s: U_String): Int64; overload;
function EStrToUInt64(s: U_String; default: UInt64): UInt64; overload;
function EStrToUInt64(s: U_String): UInt64; overload;
function EStrToFloat(s: U_String; default: Double): Double; overload;
function EStrToFloat(s: U_String): Double; overload;
function EStrToSingle(s: U_String; default: Single): Single; overload;
function EStrToSingle(s: U_String): Single; overload;
function EStrToDouble(s: U_String; default: Double): Double; overload;
function EStrToDouble(s: U_String): Double; overload;

{ Checks if a variant result is null/error }
function ExpressionValueIsError(v: Variant): Boolean;

{ Checks if any element in a vector is null/error }
function ExpressionValueVectorIsError(v: TExpressionValueVector): Boolean;

{ Converts a variant vector back to a readable string }
function ExpressionValueVectorToStr(v: TExpressionValueVector): TPascalString;

{ Outputs vector/matrix results to the status console (debugging) }
procedure DoStatusE(v: TExpressionValueVector); overload;
procedure DoStatusE(v: TExpressionValueMatrix); overload;

{ Unit test procedure for validating vector and matrix evaluation }
procedure EvaluateExpressionVectorAndMatrix_test_;

implementation

var
  OpCache___: TOpCode_Pool = nil;

{$REGION 'internal imp'}


type
  TSymbolOperationType = record
    State: TSymbolOperation;
    Decl: SystemString;
  end;

const
  MethodToken: TExpressionDeclTypes = ([edtProcExp]);

  AllExpressionValueType: TExpressionDeclTypes = ([
      edtBool, edtInt, edtInt64, edtUInt64, edtWord, edtByte, edtSmallInt, edtShortInt, edtUInt,
      edtSingle, edtDouble, edtCurrency,
      edtString, edtProcExp,
      edtExpressionAsValue]);

  SymbolOperationPriority: array [0 .. 4] of TSymbolOperations = (
    ([soAnd]),
    ([soOr, soXor]),
    ([soEqual, soLessThan, soEqualOrLessThan, soGreaterThan, soEqualOrGreaterThan, soNotEqual]),
    ([soAdd, soSub]),
    ([soMul, soDiv, soMod, soIntDiv, soShl, soShr, soPow])
    );

  AllowPrioritySymbol: TSymbolOperations = ([
      soAdd, soSub, soMul, soDiv, soMod, soIntDiv, soPow, soOr, soAnd, soXor,
      soEqual, soLessThan, soEqualOrLessThan, soGreaterThan, soEqualOrGreaterThan, soNotEqual,
      soShl, soShr,
      soDotSymbol, soCommaSymbol]);

  OpLogicalSymbol: TSymbolOperations = ([
      soAdd, soSub, soMul, soDiv, soMod, soIntDiv, soPow, soOr, soAnd, soXor,
      soEqual, soLessThan, soEqualOrLessThan, soGreaterThan, soEqualOrGreaterThan, soNotEqual,
      soShl, soShr]);

  SymbolOperationTextDecl: array [TSymbolOperation] of TSymbolOperationType = (
    (State: soAdd; Decl: '+'),
    (State: soSub; Decl: '-'),
    (State: soMul; Decl: '*'),
    (State: soDiv; Decl: '/'),
    (State: soMod; Decl: ' mod '),
    (State: soIntDiv; Decl: ' div '),
    (State: soPow; Decl: '^'),
    (State: soOr; Decl: ' or '),
    (State: soAnd; Decl: ' and '),
    (State: soXor; Decl: ' xor '),
    (State: soEqual; Decl: ' = '),
    (State: soLessThan; Decl: ' < '),
    (State: soEqualOrLessThan; Decl: ' <= '),
    (State: soGreaterThan; Decl: ' > '),
    (State: soEqualOrGreaterThan; Decl: ' => '),
    (State: soNotEqual; Decl: ' <> '),
    (State: soShl; Decl: ' shl '),
    (State: soShr; Decl: ' shr '),
    (State: soBlockIndentBegin; Decl: '('),
    (State: soBlockIndentEnd; Decl: ')'),
    (State: soPropIndentBegin; Decl: '['),
    (State: soPropIndentEnd; Decl: ']'),
    (State: soDotSymbol; Decl: '.'),
    (State: soCommaSymbol; Decl: ','),
    (State: soEolSymbol; Decl: ';'),
    (State: soProc; Decl: '|Proc|'),
    (State: soParameter; Decl: ','),
    (State: soUnknow; Decl: '?')
    );

function NumTextType(s: TPascalString): TNumTextType;
type
  TValSym = (vsSymSub, vsSymAdd, vsSymAddSub, vsSymDollar, vsDot, vsDotBeforNum, vsDotAfterNum, vsNum, vsAtoF, vsE, vsUnknow);
var
  cnt: array [TValSym] of Integer;
  v: TValSym;
  c: SystemChar;
  i: Integer;
begin
  if s.Same('true') or s.Same('false') then
      Exit(nttBool);

  for v := low(TValSym) to high(TValSym) do
      cnt[v] := 0;

  for i := 1 to s.L do
    begin
      c := s[i];
      if CharIn(c, [c0to9]) then
        begin
          inc(cnt[vsNum]);
          if cnt[vsDot] > 0 then
              inc(cnt[vsDotAfterNum]);
        end
      else if CharIn(c, [cLoAtoF, cHiAtoF]) then
        begin
          inc(cnt[vsAtoF]);
          if CharIn(c, 'eE') then
              inc(cnt[vsE]);
        end
      else if c = '.' then
        begin
          inc(cnt[vsDot]);
          cnt[vsDotBeforNum] := cnt[vsNum];
        end
      else if CharIn(c, '-') then
        begin
          inc(cnt[vsSymSub]);
          inc(cnt[vsSymAddSub]);
        end
      else if CharIn(c, '+') then
        begin
          inc(cnt[vsSymAdd]);
          inc(cnt[vsSymAddSub]);
        end
      else if CharIn(c, '$') and (i = 1) then
        begin
          inc(cnt[vsSymDollar]);
          if i <> 1 then
              Exit(nttUnknow);
        end
      else
          Exit(nttUnknow);
    end;

  if cnt[vsDot] > 1 then
      Exit(nttUnknow);
  if cnt[vsSymDollar] > 1 then
      Exit(nttUnknow);
  if (cnt[vsSymDollar] = 0) and (cnt[vsNum] = 0) then
      Exit(nttUnknow);
  if (cnt[vsSymAdd] > 1) and (cnt[vsE] = 0) and (cnt[vsSymDollar] = 0) then
      Exit(nttUnknow);

  if (cnt[vsSymDollar] = 0) and
    ((cnt[vsDot] = 1) or ((cnt[vsE] = 1) and ((cnt[vsSymAddSub] >= 1) and (cnt[vsSymDollar] = 0)))) then
    begin
      if cnt[vsSymDollar] > 0 then
          Exit(nttUnknow);
      if (cnt[vsAtoF] <> cnt[vsE]) then
          Exit(nttUnknow);

      if cnt[vsE] = 1 then
        begin
          Result := nttDouble
        end
      else if ((cnt[vsDotBeforNum] > 0)) and (cnt[vsDotAfterNum] > 0) then
        begin
          if cnt[vsDotAfterNum] < 5 then
              Result := nttCurrency
          else if cnt[vsNum] > 7 then
              Result := nttDouble
          else
              Result := nttSingle;
        end
      else
          Exit(nttUnknow);
    end
  else
    begin
      if cnt[vsSymDollar] = 1 then
        begin
          if cnt[vsSymSub] > 0 then
            begin
              if cnt[vsNum] + cnt[vsAtoF] = 0 then
                  Result := nttUnknow
              else if cnt[vsNum] + cnt[vsAtoF] < 2 then
                  Result := nttShortInt
              else if cnt[vsNum] + cnt[vsAtoF] < 4 then
                  Result := nttSmallInt
              else if cnt[vsNum] + cnt[vsAtoF] < 7 then
                  Result := nttInt
              else if cnt[vsNum] + cnt[vsAtoF] < 13 then
                  Result := nttInt64
              else
                  Result := nttUnknow;
            end
          else
            begin
              if cnt[vsNum] + cnt[vsAtoF] = 0 then
                  Result := nttUnknow
              else if cnt[vsNum] + cnt[vsAtoF] < 3 then
                  Result := nttByte
              else if cnt[vsNum] + cnt[vsAtoF] < 5 then
                  Result := nttWord
              else if cnt[vsNum] + cnt[vsAtoF] < 8 then
                  Result := nttUInt
              else if cnt[vsNum] + cnt[vsAtoF] < 14 then
                  Result := nttUInt64
              else
                  Result := nttUnknow;
            end;
        end
      else if cnt[vsAtoF] > 0 then
          Exit(nttUnknow)
      else if cnt[vsSymSub] > 0 then
        begin
          if cnt[vsNum] = 0 then
              Result := nttUnknow
          else if cnt[vsNum] < 3 then
              Result := nttShortInt
          else if cnt[vsNum] < 5 then
              Result := nttSmallInt
          else if cnt[vsNum] < 8 then
              Result := nttInt
          else if cnt[vsNum] < 15 then
              Result := nttInt64
          else
              Result := nttUnknow;
        end
      else
        begin
          if cnt[vsNum] = 0 then
              Result := nttUnknow
          else if cnt[vsNum] < 3 then
              Result := nttByte
          else if cnt[vsNum] < 5 then
              Result := nttWord
          else if cnt[vsNum] < 8 then
              Result := nttUInt
          else if cnt[vsNum] < 16 then
              Result := nttUInt64
          else
              Result := nttUnknow;
        end;
    end;
end;

procedure InitExp(var v: TExpressionListData);
begin
  v.dType := edtUnknow;
  v.cPos := -1;
  v.Symbol := soUnknow;
  v.Value := NULL;
  v.Expression := nil;
  v.ExpressionAutoFree := False;
end;

function dt2op(const v: TExpressionDeclType): TOpValueType;
begin
  case v of
    edtBool: Result := ovtBool;
    edtInt: Result := ovtInt;
    edtInt64: Result := ovtInt64;
    edtUInt64: Result := ovtUInt64;
    edtWord: Result := ovtWord;
    edtByte: Result := ovtByte;
    edtSmallInt: Result := ovtSmallInt;
    edtShortInt: Result := ovtShortInt;
    edtUInt: Result := ovtUInt;
    edtSingle: Result := ovtSingle;
    edtDouble: Result := ovtDouble;
    edtCurrency: Result := ovtCurrency;
    edtString: Result := ovtString;
    edtProcExp: Result := ovtProc;
    else Result := ovtUnknow;
  end;
end;

function VariantToExpressionDeclType(var v: Variant): TExpressionDeclType;
begin
  case VarType(v) of
    varSmallInt: Result := edtSmallInt;
    varInteger: Result := edtInt;
    varSingle: Result := edtSingle;
    varDouble: Result := edtDouble;
    varCurrency: Result := edtCurrency;
    varBoolean: Result := edtBool;
    varShortInt: Result := edtShortInt;
    varByte: Result := edtByte;
    varWord: Result := edtWord;
    varLongWord: Result := edtUInt;
    varInt64: Result := edtInt64;
    varUInt64: Result := edtUInt64;
    else
      begin
        if VarIsStr(v) then
            Result := edtString
        else
            Result := edtUnknow;
      end;
  end;
end;

constructor TSymbolExpression.Create(const TextStyle_: TTextStyle);
begin
  inherited Create;
  FList := TExpressionData_Pool.Create;
  FTextStyle := TextStyle_;
end;

destructor TSymbolExpression.Destroy;
begin
  Clear;
  DisposeObject(FList);
  inherited Destroy;
end;

procedure TSymbolExpression.Clear;
var
  i: Integer;
begin
  for i := 0 to FList.Count - 1 do
    begin
      if (FList[i]^.ExpressionAutoFree) and (FList[i]^.Expression <> nil) then
          DisposeObject(FList[i]^.Expression);

      Dispose(FList[i]);
    end;

  FList.Clear;
end;

procedure TSymbolExpression.PrintDebug(const detail: Boolean; const prefix: SystemString);
var
  i: Integer;
  p: PExpressionListData;
begin
  DoStatus(prefix + ' decl: ' + Decl());

  if detail then
    begin
      for i := 0 to Count - 1 do
        begin
          p := GetItems(i);

          DoStatus(prefix + ' id:%d exp:%s symbol:%s val:%s', [i,
              GetEnumName(TypeInfo(TExpressionDeclType), Ord(p^.dType)),
              GetEnumName(TypeInfo(TSymbolOperation), Ord(p^.Symbol)),
              VarToStr(p^.Value)]);

        end;

      DoStatus('');

      for i := 0 to Count - 1 do
        begin
          p := GetItems(i);
          if p^.Expression <> nil then
            if p^.Expression.Count > 0 then
                p^.Expression.PrintDebug(detail, prefix + ' -> ' + VarToStr(p^.Value));
        end;
    end;
end;

procedure TSymbolExpression.PrintDebug(const detail: Boolean);
begin
  PrintDebug(detail, '');
end;

function TSymbolExpression.Decl(): SystemString;
var
  i, j: Integer;
  p: PExpressionListData;
begin
  Result := '';
  for i := 0 to FList.Count - 1 do
    begin
      p := FList[i];
      case p^.dType of
        edtSymbol:
          Result := Result + SymbolOperationTextDecl[p^.Symbol].Decl;
        edtSingle, edtDouble, edtCurrency:
          Result := Result + FloatToStr(p^.Value);
        edtProcExp:
          begin
            Result := Result + VarToStr(p^.Value) + '(';
            for j := 0 to p^.Expression.Count - 1 do
              begin
                if j = 0 then
                    Result := Result + p^.Expression[j]^.Expression.Decl
                else
                    Result := Result + ',' + p^.Expression[j]^.Expression.Decl;
              end;
            Result := Result + ')';
          end;
        edtString:
          begin
            case FTextStyle of
              tsPascal: Result := Result + TTextParsing.Translate_Text_To_Pascal_Decl(VarToStr(p^.Value));
              tsC: Result := Result + TTextParsing.Translate_Text_To_C_Decl(VarToStr(p^.Value));
              else Result := Result + VarToStr(p^.Value);
            end;
          end;
        edtExpressionAsValue:
          begin
            case p^.Symbol of
              soBlockIndentBegin:
                Result := Format('%s%s%s%s',
                  [Result,
                    SymbolOperationTextDecl[soBlockIndentBegin].Decl,
                    p^.Expression.Decl,
                    SymbolOperationTextDecl[soBlockIndentEnd].Decl
                    ]);
              soPropIndentBegin:
                Result := Format('%s%s%s%s',
                  [Result,
                    SymbolOperationTextDecl[soPropIndentBegin].Decl,
                    p^.Expression.Decl,
                    SymbolOperationTextDecl[soPropIndentEnd].Decl
                    ]);
              soParameter:
                begin
                  Result := Format('%s%s%s%s',
                    [Result,
                      SymbolOperationTextDecl[soBlockIndentBegin].Decl,
                      p^.Expression.Decl,
                      SymbolOperationTextDecl[soBlockIndentEnd].Decl
                      ]);
                end;
              else
                Result := Result + ' !error! ';
            end;
          end;
        edtUnknow: Result := Result + ' !error! ';
        else
          Result := Result + VarToStr(p^.Value);
      end;
    end;
end;

function TSymbolExpression.GetCount(t: TExpressionDeclTypes): Integer;
var
  i: Integer;
  p: PExpressionListData;
begin
  Result := 0;
  for i := 0 to FList.Count - 1 do
    begin
      p := FList[i];
      if p^.dType in t then
          inc(Result);
    end;
end;

function TSymbolExpression.GetSymbolCount(Operations: TSymbolOperations): Integer;
var
  i: Integer;
  p: PExpressionListData;
begin
  Result := 0;
  for i := 0 to FList.Count - 1 do
    begin
      p := FList[i];
      if p^.dType = edtSymbol then
        begin
          if p^.Symbol in Operations then
              inc(Result);
        end;
    end;
end;

function TSymbolExpression.AvailValueCount: Integer;
begin
  Result := GetCount(AllExpressionValueType);
end;

function TSymbolExpression.Count: Integer;
begin
  Result := FList.Count;
end;

function TSymbolExpression.InsertSymbol(const idx: Integer; v: TSymbolOperation; cPos: Integer): PExpressionListData;
var
  p: PExpressionListData;
begin
  new(p);
  InitExp(p^);
  p^.dType := edtSymbol;
  p^.cPos := cPos;
  p^.Symbol := v;
  p^.Value := v;
  FList.Insert(idx, p);
  Result := p;
end;

function TSymbolExpression.Insert(const idx: Integer; v: TExpressionListData): PExpressionListData;
var
  p: PExpressionListData;
begin
  new(p);
  p^ := v;
  FList.Insert(idx, p);
  Result := p;
end;

procedure TSymbolExpression.AddExpression(const exp_: TSymbolExpression);
var
  i: Integer;
begin
  for i := 0 to exp_.Count - 1 do
      AddCopy(exp_[i]^);
end;

function TSymbolExpression.AddSymbol(const v: TSymbolOperation; cPos: Integer): PExpressionListData;
var
  p: PExpressionListData;
begin
  new(p);
  InitExp(p^);
  p^.dType := edtSymbol;
  p^.cPos := cPos;
  p^.Symbol := v;
  p^.Value := SymbolOperationTextDecl[v].Decl;
  FList.Add(p);
  Result := p;
end;

function TSymbolExpression.AddBool(const v: Boolean; cPos: Integer): PExpressionListData;
var
  p: PExpressionListData;
begin
  new(p);
  InitExp(p^);
  p^.dType := edtBool;
  p^.cPos := cPos;
  p^.Value := v;
  FList.Add(p);
  Result := p;
end;

function TSymbolExpression.AddInt(const v: Integer; cPos: Integer): PExpressionListData;
var
  p: PExpressionListData;
begin
  new(p);
  InitExp(p^);
  p^.dType := edtInt;
  p^.cPos := cPos;
  p^.Value := v;
  FList.Add(p);
  Result := p;
end;

function TSymbolExpression.AddUInt(const v: Cardinal; cPos: Integer): PExpressionListData;
var
  p: PExpressionListData;
begin
  new(p);
  InitExp(p^);
  p^.dType := edtUInt;
  p^.cPos := cPos;
  p^.Value := v;
  FList.Add(p);
  Result := p;
end;

function TSymbolExpression.AddInt64(const v: Int64; cPos: Integer): PExpressionListData;
var
  p: PExpressionListData;
begin
  new(p);
  InitExp(p^);
  p^.dType := edtInt64;
  p^.cPos := cPos;
  p^.Value := v;
  FList.Add(p);
  Result := p;
end;

function TSymbolExpression.AddUInt64(const v: UInt64; cPos: Integer): PExpressionListData;
var
  p: PExpressionListData;
begin
  new(p);
  InitExp(p^);
  p^.dType := edtUInt64;
  p^.cPos := cPos;
  p^.Value := v;
  FList.Add(p);
  Result := p;
end;

function TSymbolExpression.AddWord(const v: Word; cPos: Integer): PExpressionListData;
var
  p: PExpressionListData;
begin
  new(p);
  InitExp(p^);
  p^.dType := edtWord;
  p^.cPos := cPos;
  p^.Value := v;
  FList.Add(p);
  Result := p;
end;

function TSymbolExpression.AddByte(const v: Byte; cPos: Integer): PExpressionListData;
var
  p: PExpressionListData;
begin
  new(p);
  InitExp(p^);
  p^.dType := edtByte;
  p^.cPos := cPos;
  p^.Value := v;
  FList.Add(p);
  Result := p;
end;

function TSymbolExpression.AddSmallInt(const v: SmallInt; cPos: Integer): PExpressionListData;
var
  p: PExpressionListData;
begin
  new(p);
  InitExp(p^);
  p^.dType := edtSmallInt;
  p^.cPos := cPos;
  p^.Value := v;
  FList.Add(p);
  Result := p;
end;

function TSymbolExpression.AddShortInt(const v: ShortInt; cPos: Integer): PExpressionListData;
var
  p: PExpressionListData;
begin
  new(p);
  InitExp(p^);
  p^.dType := edtShortInt;
  p^.cPos := cPos;
  p^.Value := v;
  FList.Add(p);
  Result := p;
end;

function TSymbolExpression.AddSingle(const v: Single; cPos: Integer): PExpressionListData;
var
  p: PExpressionListData;
begin
  new(p);
  InitExp(p^);
  p^.dType := edtSingle;
  p^.cPos := cPos;
  p^.Value := v;
  FList.Add(p);
  Result := p;
end;

function TSymbolExpression.AddDouble(const v: Double; cPos: Integer): PExpressionListData;
var
  p: PExpressionListData;
begin
  new(p);
  InitExp(p^);
  p^.dType := edtDouble;
  p^.cPos := cPos;
  p^.Value := v;
  FList.Add(p);
  Result := p;
end;

function TSymbolExpression.AddCurrency(const v: Currency; cPos: Integer): PExpressionListData;
var
  p: PExpressionListData;
begin
  new(p);
  InitExp(p^);
  p^.dType := edtCurrency;
  p^.cPos := cPos;
  p^.Value := v;
  FList.Add(p);
  Result := p;
end;

function TSymbolExpression.AddString(const v: SystemString; cPos: Integer): PExpressionListData;
var
  p: PExpressionListData;
begin
  new(p);
  InitExp(p^);
  p^.dType := edtString;
  p^.cPos := cPos;
  p^.Value := v;
  FList.Add(p);
  Result := p;
end;

function TSymbolExpression.AddFunc(const v: SystemString; cPos: Integer): PExpressionListData;
var
  p: PExpressionListData;
begin
  new(p);
  InitExp(p^);
  p^.dType := edtProcExp;
  p^.cPos := cPos;
  p^.Symbol := soProc;
  p^.Value := v;
  p^.Expression := TSymbolExpression.Create(FTextStyle);
  p^.ExpressionAutoFree := True;
  FList.Add(p);
  Result := p;
end;

function TSymbolExpression.AddExpressionAsValue(AutoFree: Boolean; Expression: TSymbolExpression; Symbol: TSymbolOperation; Value: Variant; cPos: Integer): PExpressionListData;
var
  p: PExpressionListData;
begin
  new(p);
  InitExp(p^);
  p^.dType := edtExpressionAsValue;
  p^.cPos := cPos;
  p^.Symbol := Symbol;
  p^.Value := Value;
  p^.Expression := Expression;
  p^.ExpressionAutoFree := AutoFree;
  FList.Add(p);
  Result := p;
end;

function TSymbolExpression.Add(var v: TExpressionListData): PExpressionListData;
var
  p: PExpressionListData;
begin
  new(p);
  p^ := v;
  p^.ExpressionAutoFree := False;
  FList.Add(p);
  Result := p;
end;

function TSymbolExpression.AddCopy(var v: TExpressionListData): PExpressionListData;
var
  p: PExpressionListData;
  i: Integer;
begin
  new(p);
  p^ := v;
  p^.ExpressionAutoFree := False;
  if v.Expression <> nil then
    begin
      p^.Expression := TSymbolExpression.Create(FTextStyle);
      p^.ExpressionAutoFree := True;
      for i := 0 to v.Expression.Count - 1 do
          p^.Expression.AddCopy(v.Expression[i]^)
    end;
  FList.Add(p);
  Result := p;
end;

procedure TSymbolExpression.Delete(const idx: Integer);
var
  p: PExpressionListData;
begin
  p := FList[idx];
  if (p^.ExpressionAutoFree) and (p^.Expression <> nil) then
      DisposeObject(p^.Expression);
  Dispose(p);
  FList.Delete(idx);
end;

procedure TSymbolExpression.DeleteLast;
begin
  Delete(Count - 1);
end;

function TSymbolExpression.Last: PExpressionListData;
begin
  Result := FList.Last;
end;

function TSymbolExpression.First: PExpressionListData;
begin
  Result := FList.First;
end;

function TSymbolExpression.IndexOf(p: PExpressionListData): Integer;
var
  i: Integer;
begin
  for i := FList.Count - 1 downto 0 do
    if FList[i] = p then
        Exit(i);
  Exit(-1);
end;

function TSymbolExpression.GetItems(index: Integer): PExpressionListData;
begin
  Result := FList[index];
end;

function ParseOperationState(ParsingTool_: TTextParsing;
  var cPos, bPos, ePos, BlockIndent, PropIndent: Integer; var pStates: TExpressionParsingState): TSymbolOperation;
var
  c: SystemChar;
  Decl: TPascalString;
  p: PExpressionListData;
begin
  Result := soUnknow;
  if not(esWaitOp in pStates) then
      Exit;

  while cPos <= ParsingTool_.Len do
    begin
      if ParsingTool_.isComment(cPos) then
        begin
          cPos := ParsingTool_.GetCommentEndPos(cPos);
          Continue;
        end;

      c := ParsingTool_.ParsingData.Text[cPos];
      bPos := cPos;

      if (CharIn(c, ';')) then
        begin
          inc(cPos);
          Result := soEolSymbol;
          Exit;
        end;

      if (CharIn(c, ',')) then
        begin
          inc(cPos);
          pStates := pStates - [esWaitOp] + [esWaitValue];
          Result := soCommaSymbol;
          Exit;
        end;

      if CharIn(c, ')') then
        begin
          inc(cPos);
          if (esWaitIndentEnd in pStates) then
            begin
              dec(BlockIndent);
              if BlockIndent < 0 then
                begin
                  pStates := pStates - [esWaitOp, esWaitIndentEnd];
                  Result := soBlockIndentEnd;
                  Exit;
                end
              else if BlockIndent = 0 then
                  pStates := pStates - [esWaitIndentEnd];

              pStates := pStates + [esWaitOp];
              Result := soBlockIndentEnd;
              Exit;
            end
          else
            begin
              pStates := pStates - [esWaitOp, esWaitIndentEnd];
              Result := soBlockIndentEnd;
              Exit;
            end;
        end;

      if CharIn(c, ']') then
        begin
          inc(cPos);
          if (esWaitPropParamIndentEnd in pStates) then
            begin
              dec(PropIndent);
              if PropIndent < 0 then
                begin
                  pStates := pStates - [esWaitOp, esWaitPropParamIndentEnd];
                  Result := soPropIndentEnd;
                  Exit;
                end
              else if PropIndent = 0 then
                  pStates := pStates - [esWaitPropParamIndentEnd];

              pStates := pStates + [esWaitOp];
              Result := soPropIndentEnd;
              Exit;
            end
          else
            begin
              pStates := pStates - [esWaitOp, esWaitPropParamIndentEnd];
              Result := soPropIndentEnd;
              Exit;
            end;
        end;

      if CharIn(c, '(') then
        begin
          inc(cPos);
          inc(BlockIndent);
          pStates := pStates - [esWaitOp];
          pStates := pStates + [esWaitValue, esWaitIndentEnd];

          Result := soBlockIndentBegin;
          Exit;
        end;

      if CharIn(c, '[') then
        begin
          inc(cPos);
          inc(PropIndent);
          Result := soPropIndentBegin;
          pStates := pStates - [esWaitOp];
          pStates := pStates + [esWaitValue, esWaitPropParamIndentEnd];
          Exit;
        end;

      if (ParsingTool_.ComparePosStr(cPos, '>=')) or (ParsingTool_.ComparePosStr(cPos, '=>')) then
        begin
          inc(cPos, 2);
          Result := soEqualOrGreaterThan;
          pStates := pStates - [esWaitOp];
          pStates := pStates + [esWaitValue];
          Exit;
        end;
      if (ParsingTool_.ComparePosStr(cPos, '<=')) or (ParsingTool_.ComparePosStr(cPos, '=<')) then
        begin
          inc(cPos, 2);
          Result := soEqualOrLessThan;
          pStates := pStates - [esWaitOp];
          pStates := pStates + [esWaitValue];
          Exit;
        end;
      if (ParsingTool_.ComparePosStr(cPos, '<>')) or (ParsingTool_.ComparePosStr(cPos, '><')) or (ParsingTool_.ComparePosStr(cPos, '!=')) then
        begin
          inc(cPos, 2);
          Result := soNotEqual;
          pStates := pStates - [esWaitOp];
          pStates := pStates + [esWaitValue];
          Exit;
        end;
      if (ParsingTool_.ComparePosStr(cPos, '==')) then
        begin
          inc(cPos, 2);
          Result := soEqual;
          pStates := pStates - [esWaitOp];
          pStates := pStates + [esWaitValue];
          Exit;
        end;
      if (ParsingTool_.ComparePosStr(cPos, '&&')) then
        begin
          inc(cPos, 2);
          Result := soAnd;
          pStates := pStates - [esWaitOp];
          pStates := pStates + [esWaitValue];
          Exit;
        end;
      if (ParsingTool_.ComparePosStr(cPos, '||')) then
        begin
          inc(cPos, 2);
          Result := soOr;
          pStates := pStates - [esWaitOp];
          pStates := pStates + [esWaitValue];
          Exit;
        end;
      if (ParsingTool_.ComparePosStr(cPos, '<<')) then
        begin
          inc(cPos, 2);
          Result := soShl;
          pStates := pStates - [esWaitOp];
          pStates := pStates + [esWaitValue];
          Exit;
        end;
      if (ParsingTool_.ComparePosStr(cPos, '>>')) then
        begin
          inc(cPos, 2);
          Result := soShr;
          pStates := pStates - [esWaitOp];
          pStates := pStates + [esWaitValue];
          Exit;
        end;

      if CharIn(c, '+-*/^=><.,&|%') then
        begin
          if c = '+' then
              Result := soAdd
          else if c = '-' then
              Result := soSub
          else if c = '*' then
              Result := soMul
          else if c = '/' then
              Result := soDiv
          else if c = '^' then
              Result := soPow
          else if c = '=' then
              Result := soEqual
          else if c = '>' then
              Result := soGreaterThan
          else if c = '<' then
              Result := soLessThan
          else if c = '.' then
              Result := soDotSymbol
          else if c = ',' then
              Result := soCommaSymbol
          else if c = '&' then
              Result := soAnd
          else if c = '|' then
              Result := soOr
          else if c = '%' then
              Result := soMod;
          inc(cPos);
          pStates := pStates - [esWaitOp];
          pStates := pStates + [esWaitValue];
          Exit;
        end;

      if (ParsingTool_.isAscii(cPos)) then
        begin
          bPos := cPos;
          ePos := ParsingTool_.GetAsciiEndPos(cPos);
          Decl := ParsingTool_.GetStr(bPos, ePos);

          if Decl.Same('or') then
              Result := soOr
          else if Decl.Same('and') then
              Result := soAnd
          else if Decl.Same('xor') then
              Result := soXor
          else if Decl.Same('div', 'idiv', 'intdiv') then
              Result := soIntDiv
          else if Decl.Same('fdiv', 'floatdiv') then
              Result := soDiv
          else if Decl.Same('mod') then
              Result := soMod
          else if Decl.Same('shl') then
              Result := soShl
          else if Decl.Same('shr') then
              Result := soShr
          else
            begin
              Result := soUnknow;
              Exit;
            end;

          cPos := ePos;
          pStates := pStates - [esWaitOp];
          pStates := pStates + [esWaitValue];
          Exit;
        end;

      if ParsingTool_.isNumber(cPos) then
        begin
          Result := soUnknow;
          Exit;
        end;

      inc(cPos);
    end;
  pStates := [];
  Result := soEolSymbol;
end;

function ParseSymbol(ParsingTool_: TTextParsing; WorkSym: TSymbolExpression;
  var cPos, bPos, ePos, BlockIndent, PropIndent: Integer; pStates: PExpressionParsingState): Boolean;
var
  bak_cPos: Integer;
  Decl: SystemString;
  OpState: TSymbolOperation;
  RV: Variant;
  robj: TCore_Object;
  p: PExpressionListData;
begin
  while cPos <= ParsingTool_.Len do
    begin
      pStates^ := pStates^ - [esWaitValue, esFirst];
      pStates^ := pStates^ + [esWaitOp];

      bak_cPos := cPos;
      OpState := ParseOperationState(ParsingTool_, cPos, bPos, ePos, BlockIndent, PropIndent, pStates^);

      case OpState of
        soUnknow, soEolSymbol:
          begin
            Result := False;
            Exit;
          end;
        soDotSymbol:
          begin
            Result := False;
            Exit;
          end;
        soCommaSymbol:
          begin
            WorkSym.AddSymbol(OpState, bak_cPos);
            Result := True;
            Exit;
          end;
        soPropIndentBegin:
          begin
            WorkSym.AddSymbol(OpState, bak_cPos);
            Result := True;
            Exit;
          end;
        soPropIndentEnd:
          begin
            WorkSym.AddSymbol(OpState, bak_cPos);
            Result := True;
            Exit;
          end;
        soBlockIndentEnd:
          begin
            WorkSym.AddSymbol(OpState, bak_cPos);
            Result := True;
            Exit;
          end;
        soBlockIndentBegin:
          begin
            WorkSym.AddSymbol(OpState, bak_cPos);
            Result := True;
            Exit;
          end;
        else
          begin
            WorkSym.AddSymbol(OpState, bak_cPos);
            Result := True;
            Exit;
          end;
      end;
    end;
  Result := False;
end;

function ParseTextExpressionAsSymbol__(ParsingTool_: TTextParsing; const uName: SystemString;
  const OnDeclValue_C: TOnDeclValue_C; const OnDeclValue_M: TOnDeclValue_M;
  const OnDeclValue_P: TOnDeclValue_P;
  RefrenceOpRT: TOpCustomRunTime): TSymbolExpression;

  procedure PrintError(const s: SystemString);
  begin
    if isDebug then
      begin
        if s = '' then
            DoStatus('declaration error "%s"', [ParsingTool_.Text.Text])
        else
            DoStatus('declaration error "%s" -> [%s]', [ParsingTool_.Text.Text, s]);
        DoStatus('');
      end;
  end;

  function DeclValDefine(const Decl: SystemString; var v: Variant): TExpressionDeclType;
  begin
    v := Decl;
    Result := edtProcExp;

    if Assigned(OnDeclValue_C) then
        OnDeclValue_C(Decl, Result, v);
    if Assigned(OnDeclValue_M) then
        OnDeclValue_M(Decl, Result, v);
    if Assigned(OnDeclValue_P) then
        OnDeclValue_P(Decl, Result, v);
  end;

  function ExtractProc_(var ExpIndex: Integer; const Exps, procExp: TSymbolExpression): TSymbolExpression;
  var
    WasProc: Boolean;
    LocalExp, ResExp: TSymbolExpression;
    p1, p2, p: PExpressionListData;
  begin
    if ExpIndex >= Exps.Count then
      begin
        Result := nil;
        Exit;
      end;

    WasProc := procExp <> nil;

    if WasProc then
        LocalExp := procExp.AddExpressionAsValue(
        True, TSymbolExpression.Create(ParsingTool_.TextStyle), soParameter, 'param_1', Exps[ExpIndex]^.cPos)^.Expression
    else
        LocalExp := TSymbolExpression.Create(ParsingTool_.TextStyle);

    Result := LocalExp;

    while ExpIndex < Exps.Count do
      begin
        p1 := Exps[ExpIndex];

        if ExpIndex + 1 < Exps.Count then
            p2 := Exps[ExpIndex + 1]
        else
            p2 := nil;

        if (p1^.dType = edtProcExp) then
          begin
            if p2 <> nil then
              begin
                if (p2^.dType = edtSymbol) and (p2^.Symbol in [soBlockIndentBegin, soPropIndentBegin]) then
                  begin
                    inc(ExpIndex, 2);
                    p := LocalExp.AddFunc(p1^.Value, p1^.cPos);
                    ExtractProc_(ExpIndex, Exps, p^.Expression);
                    Continue;
                  end;
              end
            else
              begin
                Result.AddFunc(p1^.Value, p1^.cPos);
                inc(ExpIndex);
                Continue;
              end;
          end;

        if (p1^.dType = edtSymbol) then
          begin
            if p1^.Symbol in [soBlockIndentBegin, soPropIndentBegin] then
              begin
                inc(ExpIndex);
                ResExp := ExtractProc_(ExpIndex, Exps, nil);
                if ResExp <> nil then
                    LocalExp.AddExpressionAsValue(True, ResExp, soBlockIndentBegin, p1^.Symbol, p1^.cPos);
                Continue;
              end;
            if p1^.Symbol in [soBlockIndentEnd, soPropIndentEnd] then
              begin
                inc(ExpIndex);
                Exit;
              end;
            if (p1^.Symbol in [soCommaSymbol]) then
              begin
                if not WasProc then
                  begin
                    PrintError('comma Illegal');
                    Exit;
                  end;

                LocalExp := procExp.AddExpressionAsValue(True,
                  TSymbolExpression.Create(ParsingTool_.TextStyle), soParameter, 'param_' + IntToStr(procExp.Count + 1),
                  Exps[ExpIndex]^.cPos)^.Expression;
                inc(ExpIndex);
                Continue;
              end;
          end;

        LocalExp.AddCopy(p1^);
        inc(ExpIndex);
      end;
  end;

var
  cPos, bPos, ePos, i: Integer;
  td: PTokenData;
  State: TExpressionParsingState;
  BlockIndent, PropIndent: Integer;
  Container: TSymbolExpression;
  te: TTextParsing;
  Decl: TPascalString;
  OpState: TSymbolOperation;
  isNumber, isSpecialSymbol, isAscii, isTextDecl, isSymbol: Boolean;
  RV: Variant;
  p: PExpressionListData;
begin
  Result := nil;

  if ParsingTool_.Len < 1 then
      Exit;
  if ParsingTool_.TokenCountT([ttTextDecl, ttNumber, ttAscii]) = 0 then
      Exit;

  cPos := 1;
  BlockIndent := 0;
  PropIndent := 0;
  State := [esFirst];
  Container := TSymbolExpression.Create(ParsingTool_.TextStyle);

  while cPos <= ParsingTool_.Len do
    begin
      if ParsingTool_.isComment(cPos) then
        begin
          cPos := ParsingTool_.GetCommentEndPos(cPos) + 1;
          Continue;
        end;

      { check esWaitOp state }
      if (esWaitOp in State) and (CharIn(ParsingTool_.GetChar(cPos), ParsingTool_.SymbolTable)) then
        begin
          isSpecialSymbol := False;
          isNumber := False;
          isTextDecl := False;
          isAscii := False;
          isSymbol := True;
          bPos := cPos;
          ePos := bPos + 1;
        end
      else
        begin
          td := ParsingTool_.TokenPos[cPos];
          isSpecialSymbol := td^.tokenType = ttSpecialSymbol;
          if isSpecialSymbol then
            begin
              isNumber := False;
              isTextDecl := False;
              isAscii := False;
              isSymbol := False;
            end
          else if (td^.tokenType = ttAscii) and
            (
            td^.Text.Same('and', 'or', 'xor', 'shl', 'shr')
              or
              td^.Text.Same('div', 'idiv', 'intdiv', 'fdiv', 'floatdiv')
              or
              td^.Text.Same('mod')
            ) then
            begin
              isSymbol := True;
              isNumber := False;
              isTextDecl := False;
              isAscii := False;
            end
          else
            begin
              isNumber := td^.tokenType = ttNumber;
              isTextDecl := td^.tokenType = ttTextDecl;
              isAscii := td^.tokenType = ttAscii;
              isSymbol := td^.tokenType = ttSymbol;
            end;
        end;

      if (not(esWaitOp in State)) and (isSpecialSymbol or isNumber or isTextDecl or isAscii) then
        begin
          if not((esWaitValue in State) or (esFirst in State)) then
            begin
              PrintError('');
              Break;
            end;

          bPos := cPos;
          ePos := td^.ePos;
          if (isSpecialSymbol) and (ParsingTool_.GetAsciiBeginPos(ePos) <= ePos) then
              ePos := ParsingTool_.GetSpecialSymbolEndPos(ParsingTool_.GetAsciiEndPos(ePos));
          cPos := ePos;

          Decl := ParsingTool_.GetStr(bPos, ePos);
          if isNumber then
            begin
              if Decl.ComparePos(1, '0x') then
                begin
                  Decl.DeleteFirst;
                  Decl[1] := '$';
                end;
              case NumTextType(Decl) of
                nttBool: Container.AddBool(StrToBool(Decl), bPos);
                nttInt: Container.AddInt(StrToInt(Decl), bPos);
                nttInt64: Container.AddInt64(StrToInt64(Decl), bPos);
{$IFDEF FPC}
                nttUInt64: Container.AddUInt64(StrToQWord(Decl), bPos);
{$ELSE FPC}
                nttUInt64: Container.AddUInt64(StrToUInt64(Decl), bPos);
{$ENDIF FPC}
                nttWord: Container.AddWord(StrToInt(Decl), bPos);
                nttByte: Container.AddByte(StrToInt(Decl), bPos);
                nttSmallInt: Container.AddSmallInt(StrToInt(Decl), bPos);
                nttShortInt: Container.AddShortInt(StrToInt(Decl), bPos);
                nttUInt: Container.AddUInt(StrToInt(Decl), bPos);
                nttSingle: Container.AddSingle(StrToFloat(Decl), bPos);
                nttDouble: Container.AddDouble(StrToFloat(Decl), bPos);
                nttCurrency: Container.AddCurrency(StrToFloat(Decl), bPos);
                else
                  begin
                    PrintError(Format('number expression "%s" Illegal', [Decl.Text]));
                    Break;
                  end;
              end;
            end
          else if isTextDecl then
            begin
              Container.AddString(ParsingTool_.GetTextBody(Decl), bPos);
            end
          else
            case NumTextType(Decl) of
              nttBool: Container.AddBool(StrToBool(Decl), bPos);
              nttInt: Container.AddInt(StrToInt(Decl), bPos);
              nttInt64: Container.AddInt64(StrToInt64(Decl), bPos);
{$IFDEF FPC}
              nttUInt64: Container.AddUInt64(StrToQWord(Decl), bPos);
{$ELSE}
              nttUInt64: Container.AddUInt64(StrToUInt64(Decl), bPos);
{$ENDIF}
              nttWord: Container.AddWord(StrToInt(Decl), bPos);
              nttByte: Container.AddByte(StrToInt(Decl), bPos);
              nttSmallInt: Container.AddSmallInt(StrToInt(Decl), bPos);
              nttShortInt: Container.AddShortInt(StrToInt(Decl), bPos);
              nttUInt: Container.AddUInt(StrToInt(Decl), bPos);
              nttSingle: Container.AddSingle(StrToFloat(Decl), bPos);
              nttDouble: Container.AddDouble(StrToFloat(Decl), bPos);
              nttCurrency: Container.AddCurrency(StrToFloat(Decl), bPos);
              else
                begin
                  case DeclValDefine(Decl, RV) of
                    edtBool: Container.AddBool(RV, bPos);
                    edtInt: Container.AddInt(RV, bPos);
                    edtInt64: Container.AddInt64(RV, bPos);
                    edtUInt64: Container.AddUInt64(RV, bPos);
                    edtWord: Container.AddWord(RV, bPos);
                    edtByte: Container.AddByte(RV, bPos);
                    edtSmallInt: Container.AddSmallInt(RV, bPos);
                    edtShortInt: Container.AddShortInt(RV, bPos);
                    edtUInt: Container.AddUInt(RV, bPos);
                    edtSingle: Container.AddSingle(RV, bPos);
                    edtDouble: Container.AddDouble(RV, bPos);
                    edtCurrency: Container.AddCurrency(RV, bPos);
                    edtString: Container.AddString(RV, bPos);
                    edtProcExp:
                      begin
                        if (RefrenceOpRT <> nil) and (not RefrenceOpRT.ProcList.Exists(RV)) then
                          if (SystemOpRunTime <> RefrenceOpRT) and (not SystemOpRunTime.ProcList.Exists(RV)) then
                            begin
                              PrintError(Format('function "%s" Illegal', [RV]));
                              Break;
                            end;
                        Container.AddFunc(RV, bPos);
                      end;
                    else
                      begin
                        PrintError(Format('define "%s" Illegal', [Decl.Text]));
                        Break;
                      end;
                  end;
                end;
            end;
          if not ParseSymbol(ParsingTool_, Container, cPos, bPos, ePos, BlockIndent, PropIndent, @State) then
              Break
          else
              Continue;
        end;

      if (isSymbol) then
        begin
          if not ParseSymbol(ParsingTool_, Container, cPos, bPos, ePos, BlockIndent, PropIndent, @State) then
              Break
          else
              Continue;
        end;

      inc(cPos);
    end;

  if (BlockIndent + PropIndent = 0) then
    begin
      i := 0;
      Result := ExtractProc_(i, Container, nil);
      if Result = nil then
          PrintError('indent error');
    end
  else
      PrintError('indent error');

  DisposeObject(Container);
end;

function ParseTextExpressionAsSymbol_C(ParsingTool_: TTextParsing; const uName: SystemString;
  const OnGetValue: TOnDeclValue_C; RefrenceOpRT: TOpCustomRunTime): TSymbolExpression;
begin
  Result := ParseTextExpressionAsSymbol__(ParsingTool_, uName, OnGetValue, nil, nil, RefrenceOpRT);
end;

function ParseTextExpressionAsSymbol_M(ParsingTool_: TTextParsing; const uName: SystemString;
  const OnGetValue: TOnDeclValue_M; RefrenceOpRT: TOpCustomRunTime): TSymbolExpression;
begin
  Result := ParseTextExpressionAsSymbol__(ParsingTool_, uName, nil, OnGetValue, nil, RefrenceOpRT);
end;

function ParseTextExpressionAsSymbol_P(ParsingTool_: TTextParsing; const uName: SystemString;
  const OnGetValue: TOnDeclValue_P; RefrenceOpRT: TOpCustomRunTime): TSymbolExpression;
begin
  Result := ParseTextExpressionAsSymbol__(ParsingTool_, uName, nil, nil, OnGetValue, RefrenceOpRT);
end;

function ParseTextExpressionAsSymbol(Special_ASCII_: TListPascalString;
  TextStyle: TTextStyle; const uName, ExpressionText: SystemString;
  const OnGetValue: TOnDeclValue_M; RefrenceOpRT: TOpCustomRunTime): TSymbolExpression;
var
  ParsingTool_: TTextParsing;
begin
  ParsingTool_ := TTextParsing.Create(ExpressionText, TextStyle, Special_ASCII_);
  Result := ParseTextExpressionAsSymbol_M(ParsingTool_, uName, OnGetValue, RefrenceOpRT);
  DisposeObject(ParsingTool_);
end;

function ParseTextExpressionAsSymbol(TextStyle: TTextStyle; const uName, ExpressionText: SystemString;
  const OnGetValue: TOnDeclValue_M; RefrenceOpRT: TOpCustomRunTime): TSymbolExpression;
begin
  Result := ParseTextExpressionAsSymbol(nil, TextStyle, uName, ExpressionText, OnGetValue, RefrenceOpRT);
end;

function ParseTextExpressionAsSymbol(Special_ASCII_: TListPascalString;
  ExpressionText: SystemString; RefrenceOpRT: TOpCustomRunTime): TSymbolExpression;
var
  ParsingTool_: TTextParsing;
  tmp: TOnDeclValue_M; // fixed DCC < XE8
begin
  ParsingTool_ := TTextParsing.Create(ExpressionText, tsPascal, Special_ASCII_);
  tmp := nil;
  Result := ParseTextExpressionAsSymbol_M(ParsingTool_, '', tmp, RefrenceOpRT);
  DisposeObject(ParsingTool_);
end;

function ParseTextExpressionAsSymbol(ExpressionText: SystemString; RefrenceOpRT: TOpCustomRunTime): TSymbolExpression;
begin
  Result := ParseTextExpressionAsSymbol(nil, ExpressionText, RefrenceOpRT);
end;

function ParseTextExpressionAsSymbol(Special_ASCII_: TListPascalString; ExpressionText: SystemString): TSymbolExpression;
var
  ParsingTool_: TTextParsing;
  tmp: TOnDeclValue_M; // fixed DCC < XE8
begin
  ParsingTool_ := TTextParsing.Create(ExpressionText, tsPascal, Special_ASCII_);
  tmp := nil;
  Result := ParseTextExpressionAsSymbol_M(ParsingTool_, '', tmp, SystemOpRunTime);
  DisposeObject(ParsingTool_);
end;

function ParseTextExpressionAsSymbol(ExpressionText: SystemString): TSymbolExpression;
begin
  Result := ParseTextExpressionAsSymbol(nil, ExpressionText);
end;

function ParseTextExpressionAsSymbol_M(Special_ASCII_: TListPascalString;
  TextEngClass: TTextParsingClass; TextStyle: TTextStyle; const uName, ExpressionText: SystemString;
  const OnGetValue: TOnDeclValue_M; RefrenceOpRT: TOpCustomRunTime): TSymbolExpression;
var
  ParsingTool_: TTextParsing;
begin
  ParsingTool_ := TextEngClass.Create(ExpressionText, TextStyle, Special_ASCII_);
  Result := ParseTextExpressionAsSymbol_M(ParsingTool_, '', OnGetValue, RefrenceOpRT);
  DisposeObject(ParsingTool_);
end;

function ParseTextExpressionAsSymbol_M(TextEngClass: TTextParsingClass; TextStyle: TTextStyle; const uName, ExpressionText: SystemString;
  const OnGetValue: TOnDeclValue_M; RefrenceOpRT: TOpCustomRunTime): TSymbolExpression;
var
  ParsingTool_: TTextParsing;
begin
  ParsingTool_ := TextEngClass.Create(ExpressionText, TextStyle, nil);
  Result := ParseTextExpressionAsSymbol_M(ParsingTool_, '', OnGetValue, RefrenceOpRT);
  DisposeObject(ParsingTool_);
end;

function ParseTextExpressionAsSymbol_C(Special_ASCII_: TListPascalString;
  TextEngClass: TTextParsingClass; TextStyle: TTextStyle; const uName, ExpressionText: SystemString;
  const OnGetValue: TOnDeclValue_C; RefrenceOpRT: TOpCustomRunTime): TSymbolExpression;
var
  ParsingTool_: TTextParsing;
begin
  ParsingTool_ := TextEngClass.Create(ExpressionText, TextStyle, Special_ASCII_);
  Result := ParseTextExpressionAsSymbol_C(ParsingTool_, '', OnGetValue, RefrenceOpRT);
  DisposeObject(ParsingTool_);
end;

function ParseTextExpressionAsSymbol_C(TextEngClass: TTextParsingClass; TextStyle: TTextStyle; const uName, ExpressionText: SystemString;
  const OnGetValue: TOnDeclValue_C; RefrenceOpRT: TOpCustomRunTime): TSymbolExpression;
begin
  Result := ParseTextExpressionAsSymbol_C(nil, TextEngClass, TextStyle, uName, ExpressionText, OnGetValue, RefrenceOpRT);
end;

function ParseTextExpressionAsSymbol_P(Special_ASCII_: TListPascalString;
  TextEngClass: TTextParsingClass; TextStyle: TTextStyle; const uName, ExpressionText: SystemString;
  const OnGetValue: TOnDeclValue_P; RefrenceOpRT: TOpCustomRunTime): TSymbolExpression;
var
  ParsingTool_: TTextParsing;
begin
  ParsingTool_ := TextEngClass.Create(ExpressionText, TextStyle, Special_ASCII_);
  Result := ParseTextExpressionAsSymbol_P(ParsingTool_, '', OnGetValue, RefrenceOpRT);
  DisposeObject(ParsingTool_);
end;

function ParseTextExpressionAsSymbol_P(TextEngClass: TTextParsingClass; TextStyle: TTextStyle; const uName, ExpressionText: SystemString;
  const OnGetValue: TOnDeclValue_P; RefrenceOpRT: TOpCustomRunTime): TSymbolExpression;
begin
  Result := ParseTextExpressionAsSymbol_P(nil, TextEngClass, TextStyle, uName, ExpressionText, OnGetValue, RefrenceOpRT);
end;

function RebuildLogicalPrioritySymbol(Exps: TSymbolExpression): TSymbolExpression;
  function SymbolPriority(s1, s2: TSymbolOperation): Integer;

    function FindSymbol(s: TSymbolOperation): Integer;
    var
      i: Integer;
    begin
      for i := low(SymbolOperationPriority) to high(SymbolOperationPriority) do
        if s in SymbolOperationPriority[i] then
            Exit(i);
      raise Exception.Create('no define symbol');
    end;

  begin
    if (s1 in [soUnknow, soCommaSymbol]) or (s2 in [soUnknow, soCommaSymbol]) then
        Exit(0);
    Result := FindSymbol(s2) - FindSymbol(s1);
  end;

var
  SymbolIndex: Integer;
  newExpression: TSymbolExpression;
  ParseAborted: Boolean;

  procedure PrintError(const s: SystemString);
  begin
    ParseAborted := True;
    if isDebug then
      begin
        if s <> '' then
            DoStatus(Format('Priority symbol failed : %s', [s]))
        else
            DoStatus('Priority symbol failed');
      end;
  end;

  procedure ProcessSymbol(OwnerSym: TSymbolOperation);
  var
    p1, p2, startIndent, lastIndent: PExpressionListData;
    LastSym, lastIndentSym: TSymbolOperation;
    LastSymbolPriority, LastOwnerSymbolPriority: Integer;
  begin
    if ParseAborted then
        Exit;
    if SymbolIndex >= Exps.Count then
        Exit;

    if newExpression.Count > 0 then
        startIndent := newExpression.Last
    else
        startIndent := nil;

    LastSym := OwnerSym;
    lastIndent := nil;
    lastIndentSym := OwnerSym;

    while True do
      begin
        if ParseAborted then
            Break;

        if SymbolIndex >= Exps.Count then
            Break;

        p1 := Exps[SymbolIndex];

        if (p1^.dType in AllExpressionValueType) then
          begin
            inc(SymbolIndex);
            if SymbolIndex >= Exps.Count then
              begin
                newExpression.Add(p1^);
                Break;
              end;

            p2 := Exps[SymbolIndex];

            if (p1^.dType in MethodToken) and (p2^.dType = edtExpressionAsValue) then
              begin
                newExpression.Add(p1^);
                newExpression.Add(p2^);
              end
            else if p2^.dType = edtSymbol then
              begin
                if p2^.Symbol in AllowPrioritySymbol then
                  begin
                    LastOwnerSymbolPriority := SymbolPriority(p2^.Symbol, OwnerSym);
                    LastSymbolPriority := SymbolPriority(p2^.Symbol, LastSym);

                    if LastOwnerSymbolPriority > 0 then
                      begin
                        newExpression.Add(p1^);
                        Break;
                      end;

                    if LastSymbolPriority < 0 then
                      begin
                        lastIndent := newExpression.AddSymbol(soBlockIndentBegin, p1^.cPos);
                        lastIndentSym := LastSym;
                        newExpression.Add(p1^);
                        newExpression.Add(p2^);

                        inc(SymbolIndex);
                        ProcessSymbol(p2^.Symbol);
                        newExpression.AddSymbol(soBlockIndentEnd, p2^.cPos);

                        Continue;
                      end
                    else if LastSymbolPriority > 0 then
                      begin
                        if startIndent = nil then
                            startIndent := newExpression.First;

                        newExpression.InsertSymbol(newExpression.IndexOf(startIndent), soBlockIndentBegin, startIndent^.cPos);
                        newExpression.Add(p1^);
                        newExpression.AddSymbol(soBlockIndentEnd, p2^.cPos);
                        newExpression.Add(p2^);
                      end
                    else
                      begin
                        newExpression.Add(p1^);
                        newExpression.Add(p2^);
                      end;
                    LastSym := p2^.Symbol;
                  end
                else
                  begin
                    PrintError(SymbolOperationTextDecl[p2^.Symbol].Decl);
                    Exit;
                  end;
              end;
          end
        else if (p1^.dType = edtSymbol) then
          begin
            inc(SymbolIndex);
            if SymbolIndex >= Exps.Count then
              begin
                newExpression.Add(p1^);
                Break;
              end;

            p2 := Exps[SymbolIndex];

            if (p2^.dType in AllExpressionValueType) then
              begin
                if p1^.Symbol in AllowPrioritySymbol then
                  begin
                    LastSymbolPriority := SymbolPriority(p1^.Symbol, lastIndentSym);

                    if LastSymbolPriority < 0 then
                      begin
                        newExpression.InsertSymbol(newExpression.IndexOf(lastIndent), soBlockIndentBegin, lastIndent^.cPos);
                        newExpression.Add(p1^);
                        LastSym := p1^.Symbol;
                        ProcessSymbol(p1^.Symbol);
                        newExpression.AddSymbol(soBlockIndentEnd, p2^.cPos);
                        Continue;
                      end
                    else
                      begin
                        newExpression.Add(p1^);
                        Continue;
                      end;
                  end
                else
                  begin
                    PrintError(SymbolOperationTextDecl[p1^.Symbol].Decl);
                    Exit;
                  end;
              end
            else
              begin
                PrintError('expression structor Illegal');
                Exit;
              end;
          end;

        inc(SymbolIndex);
      end;
  end;

begin
  Result := nil;
  if Exps.AvailValueCount = 0 then
      Exit;

  if Exps.GetSymbolCount([
      soBlockIndentBegin, soBlockIndentEnd,
      soPropIndentBegin, soPropIndentEnd,
      soEolSymbol, soUnknow]) > 0 then
    begin
      PrintError('Illegal symbol');
      Exit;
    end;

  SymbolIndex := 0;
  newExpression := TSymbolExpression.Create(Exps.FTextStyle);
  ParseAborted := False;

  ProcessSymbol(soUnknow);

  if ParseAborted then
    begin
      newExpression.Free;
      PrintError('Illegal');
    end
  else
      Result := newExpression;
end;

function RebuildAllSymbol(Exps: TSymbolExpression): TSymbolExpression;
var
  SymbolIndex: Integer;
  ParseAborted: Boolean;

  procedure PrintError(const s: SystemString);
  begin
    ParseAborted := True;
    if isDebug then
      begin
        if s <> '' then
            DoStatus(Format('indent symbol failed : %s', [s]))
        else
            DoStatus('indent symbol failed');
      end;
  end;

  function ProcessIndent(OwnerIndentSym: TSymbolOperation): TSymbolExpression;
  var
    p1, p2: PExpressionListData;
    LocalExp, ResExp: TSymbolExpression;
  begin
    LocalExp := TSymbolExpression.Create(Exps.FTextStyle);
    Result := LocalExp;
    while True do
      begin
        if SymbolIndex >= Exps.Count then
            Break;

        p1 := Exps[SymbolIndex];

        if (p1^.dType in [edtSymbol]) then
          begin
            if p1^.Symbol in [soBlockIndentBegin, soPropIndentBegin] then
              begin
                inc(SymbolIndex);

                ResExp := ProcessIndent(p1^.Symbol);
                LocalExp.AddExpressionAsValue(True, ResExp, p1^.Symbol, SymbolOperationTextDecl[p1^.Symbol].Decl, p1^.cPos);

                if SymbolIndex >= Exps.Count then
                  begin
                    PrintError('indent Illegal');
                    Exit;
                  end;
              end
            else if ((OwnerIndentSym = soBlockIndentBegin) and (p1^.Symbol = soBlockIndentEnd)) or
              ((OwnerIndentSym = soPropIndentBegin) and (p1^.Symbol = soPropIndentEnd)) then
              begin
                Exit;
              end
            else if p1^.Symbol in [soCommaSymbol] then
              begin
                LocalExp.Add(p1^);
              end
            else
              begin
                LocalExp.Add(p1^);
              end;
          end
        else if (p1^.dType in AllExpressionValueType) then
          begin
            if p1^.dType = edtProcExp then
              begin
                LocalExp.Add(p1^);
                inc(SymbolIndex);
                Continue;
              end;

            inc(SymbolIndex);
            if SymbolIndex >= Exps.Count then
              begin
                LocalExp.Add(p1^);
                Break;
              end;

            p2 := Exps[SymbolIndex];

            if p2^.dType = edtSymbol then
              begin
                if (p2^.Symbol in [soBlockIndentBegin, soPropIndentBegin]) then
                  begin
                    if (p1^.dType in MethodToken) then
                      begin
                        PrintError('method Illegal');
                        Exit;
                      end;

                    LocalExp.Add(p1^);
                    inc(SymbolIndex);

                    ResExp := ProcessIndent(p2^.Symbol);
                    LocalExp.AddExpressionAsValue(True, ResExp, p2^.Symbol, SymbolOperationTextDecl[p2^.Symbol].Decl, p2^.cPos);

                    if SymbolIndex >= Exps.Count then
                      begin
                        PrintError('indent Illegal');
                        Exit;
                      end;

                  end
                else if ((OwnerIndentSym = soBlockIndentBegin) and (p2^.Symbol = soBlockIndentEnd)) or
                  ((OwnerIndentSym = soPropIndentBegin) and (p2^.Symbol = soPropIndentEnd)) then
                  begin
                    LocalExp.Add(p1^);
                    Exit;
                  end
                else if p2^.Symbol = soCommaSymbol then
                  begin
                    PrintError('Comma Illegal');
                    Exit;
                  end
                else
                  begin
                    LocalExp.Add(p1^);
                    LocalExp.Add(p2^);
                  end;
              end
            else
              begin
                PrintError('expression structor Illegal');
                Exit;
              end;
          end;

        inc(SymbolIndex);
      end;
  end;

  function ProcessPriority(exp_: TSymbolExpression): TSymbolExpression;
  var
    i, j: Integer;
    tmp, ResExp: TSymbolExpression;
    p, funcP: PExpressionListData;
  begin
    tmp := RebuildLogicalPrioritySymbol(exp_);
    if tmp = nil then
      begin
        Result := nil;
        PrintError('parse priority failed');
        Exit;
      end;

    Result := TSymbolExpression.Create(tmp.FTextStyle);

    for i := 0 to tmp.Count - 1 do
      begin
        p := tmp[i];
        if p^.dType = edtExpressionAsValue then
          begin
            case p^.Symbol of
              soBlockIndentBegin:
                begin
                  Result.AddSymbol(soBlockIndentBegin, p^.cPos);
                  ResExp := ProcessPriority(p^.Expression);
                  if ResExp <> nil then
                    begin
                      Result.AddExpression(ResExp);
                      DisposeObject(ResExp);
                    end;
                  Result.AddSymbol(soBlockIndentEnd, p^.cPos);
                end;
              soPropIndentBegin:
                begin
                  Result.AddSymbol(soPropIndentBegin, p^.cPos);
                  ResExp := ProcessPriority(p^.Expression);
                  if ResExp <> nil then
                    begin
                      Result.AddExpression(ResExp);
                      DisposeObject(ResExp);
                    end;
                  Result.AddSymbol(soPropIndentEnd, p^.cPos);
                end;
              else
                begin
                  Break;
                end;
            end;
          end
        else if p^.dType = edtProcExp then
          begin
            funcP := Result.AddFunc(VarToStr(p^.Value), p^.cPos);
            if (p^.Expression.Count > 0) and (p^.Expression.First^.Expression.Count > 0) then
              for j := 0 to p^.Expression.Count - 1 do
                begin
                  ResExp := RebuildAllSymbol(p^.Expression[j]^.Expression);
                  if ResExp <> nil then
                      funcP^.Expression.AddExpressionAsValue(True, ResExp, soParameter, VarToStr(p^.Expression[j]^.Value), p^.Expression[j]^.cPos);
                end;
          end
        else
          begin
            Result.Add(p^);
          end;
      end;
    DisposeObject(tmp);
  end;

var
  rse: TSymbolExpression;
begin
  Result := nil;
  SymbolIndex := 0;
  ParseAborted := False;

  rse := ProcessIndent(soUnknow);
  Result := ProcessPriority(rse);
  DisposeObject(rse);
end;

function BuildAsOpCode(DebugMode: Boolean; SymbExps: TSymbolExpression; const uName: SystemString; LineNo: Integer): TOpCode;
var
  NewSymbExps: TSymbolExpression;
  SymbolIndex: Integer;
  BuildAborted: Boolean;
  OpContainer: TCore_ListForObj;

  procedure PrintError(const s: SystemString);
  begin
    BuildAborted := True;
    if isDebug then
      begin
        if s <> '' then
            DoStatus(Format('build op failed : %s', [s]))
        else
            DoStatus('build op failed');
      end;
  end;

  function NewOpValue(uName: SystemString): TOpCode;
  begin
    Result := op_Value.Create(False);
    Result.Parsed_Info := uName;
    Result.Parsed_Line_Num := LineNo;
    OpContainer.Add(Result);
  end;

  function NewOpProc(uName: SystemString): TOpCode;
  begin
    Result := op_Proc.Create(False);
    Result.Parsed_Info := uName;
    Result.Parsed_Line_Num := LineNo;
    OpContainer.Add(Result);
  end;

  function NewOpPrefixFromSym(sym: TSymbolOperation; const uName: SystemString): TOpCode;
  begin
    case sym of
      soAdd: Result := op_Add_Prefix.Create(False);
      soSub: Result := op_Sub_Prefix.Create(False);
      else Result := nil;
    end;
    if Result <> nil then
      begin
        Result.Parsed_Info := uName;
        Result.Parsed_Line_Num := LineNo;
        OpContainer.Add(Result);
      end;
  end;

  function NewOpFromSym(sym: TSymbolOperation; const uName: SystemString): TOpCode;
  begin
    case sym of
      soAdd: Result := op_Add.Create(False);
      soSub: Result := op_Sub.Create(False);
      soMul: Result := op_Mul.Create(False);
      soDiv: Result := op_Div.Create(False);
      soMod: Result := op_Mod.Create(False);
      soIntDiv: Result := op_IntDiv.Create(False);
      soPow: Result := op_Pow.Create(False);
      soOr: Result := op_Or.Create(False);
      soAnd: Result := op_And.Create(False);
      soXor: Result := op_Xor.Create(False);
      soEqual: Result := op_Equal.Create(False);
      soLessThan: Result := op_LessThan.Create(False);
      soEqualOrLessThan: Result := op_EqualOrLessThan.Create(False);
      soGreaterThan: Result := op_GreaterThan.Create(False);
      soEqualOrGreaterThan: Result := op_EqualOrGreaterThan.Create(False);
      soNotEqual: Result := op_NotEqual.Create(False);
      soShl: Result := op_Shl.Create(False);
      soShr: Result := op_Shr.Create(False);
      else Result := nil;
    end;
    if Result <> nil then
      begin
        Result.Parsed_Info := uName;
        Result.Parsed_Line_Num := LineNo;
        OpContainer.Add(Result);
      end;
  end;

  function ProcessIndent(OwnerIndentSym: TSymbolOperation): TOpCode;
  var
    i: Integer;
    p1, p2: PExpressionListData;
    LocalOp, OldOp, ResOp, ProcOp: TOpCode;
  begin
    LocalOp := nil;
    OldOp := nil;
    ResOp := nil;
    Result := nil;

    while True do
      begin
        if SymbolIndex >= NewSymbExps.Count then
          begin
            if LocalOp <> nil then
                Result := LocalOp;
            Break;
          end;

        p1 := NewSymbExps[SymbolIndex];

        if (p1^.dType in [edtSymbol]) then
          begin
            if p1^.Symbol in [soBlockIndentBegin, soPropIndentBegin] then
              begin
                inc(SymbolIndex);
                ResOp := ProcessIndent(p1^.Symbol);
                if ResOp <> nil then
                  begin
                    if LocalOp <> nil then
                      begin
                        LocalOp.AddLink(ResOp);
                      end
                    else
                      begin
                        LocalOp := NewOpValue(uName);
                        LocalOp.AddLink(ResOp);
                      end;
                  end
                else
                  begin
                    PrintError('logical operotion Illegal');
                    Break;
                  end;
              end
            else if ((OwnerIndentSym = soBlockIndentBegin) and (p1^.Symbol = soBlockIndentEnd)) or
              ((OwnerIndentSym = soPropIndentBegin) and (p1^.Symbol = soPropIndentEnd)) then
              begin
                Result := LocalOp;
                Break;
              end
            else if p1^.Symbol in OpLogicalSymbol then
              begin
                if LocalOp <> nil then
                  begin
                    OldOp := LocalOp;
                    LocalOp := NewOpFromSym(p1^.Symbol, uName);
                    if LocalOp = nil then
                      begin
                        PrintError('prefix symbol Illegal');
                        Break;
                      end;
                    LocalOp.AddLink(OldOp);
                  end
                else
                  begin
                    { fixed symbol prefix, -(operation), -proc(xx)... }
                    if (SymbolIndex + 1 < NewSymbExps.Count) then
                      begin
                        p2 := NewSymbExps[SymbolIndex + 1];
                        if (p1^.Symbol in [soAdd, soSub]) then
                          begin
                            if (p2^.dType = edtSymbol) and (p2^.Symbol in [soBlockIndentBegin, soPropIndentBegin]) then
                              begin
                                inc(SymbolIndex);
                                ResOp := ProcessIndent(p2^.Symbol);
                                if ResOp <> nil then
                                  begin
                                    LocalOp := NewOpPrefixFromSym(p1^.Symbol, uName);
                                    if LocalOp = nil then
                                      begin
                                        PrintError('prefix symbol Illegal');
                                        Break;
                                      end;
                                    LocalOp.AddLink(ResOp);
                                  end
                                else
                                  begin
                                    PrintError('logical operation Illegal');
                                    Break;
                                  end;
                                Continue;
                              end
                            else if (p2^.dType = edtProcExp) and (p2^.Symbol = soProc) then
                              begin
                                ProcOp := NewOpProc(uName);
                                ProcOp.AddValue(p2^.Value);
                                for i := 0 to p2^.Expression.Count - 1 do
                                  begin
                                    ResOp := BuildAsOpCode(False, p2^.Expression[i]^.Expression, uName, LineNo);
                                    if ResOp <> nil then
                                        ProcOp.AddLink(ResOp)
                                    else
                                      begin
                                        PrintError('method Illegal');
                                        Break;
                                      end;
                                  end;

                                LocalOp := NewOpPrefixFromSym(p1^.Symbol, uName);
                                LocalOp.AddLink(ProcOp);

                                inc(SymbolIndex, 2);
                                Continue;
                              end;
                          end;
                      end;
                    PrintError('logical operotion Illegal');
                    Break;
                  end;
              end
            else
              begin
                PrintError('logical operotion Illegal');
                Break;
              end;
          end
        else if (p1^.dType in AllExpressionValueType) then
          begin
            if p1^.dType = edtProcExp then
              begin
                ProcOp := NewOpProc(uName);
                ProcOp.AddValue(p1^.Value);
                for i := 0 to p1^.Expression.Count - 1 do
                  begin
                    ResOp := BuildAsOpCode(False, p1^.Expression[i]^.Expression, uName, LineNo);
                    if ResOp <> nil then
                        ProcOp.AddLink(ResOp)
                    else
                      begin
                        PrintError('method Illegal');
                        Break;
                      end;
                  end;

                if LocalOp <> nil then
                  begin
                    LocalOp.AddLink(ProcOp);
                  end
                else
                  begin
                    LocalOp := NewOpValue(uName);
                    LocalOp.AddLink(ProcOp);
                  end;
                inc(SymbolIndex);
                Continue;
              end;

            inc(SymbolIndex);
            if SymbolIndex >= NewSymbExps.Count then
              begin
                if LocalOp <> nil then
                  begin
                    LocalOp.AddValueT(p1^.Value, dt2op(p1^.dType));
                  end
                else
                  begin
                    LocalOp := NewOpValue(uName);
                    LocalOp.AddValueT(p1^.Value, dt2op(p1^.dType));
                  end;
                Result := LocalOp;
                Break;
              end;

            p2 := NewSymbExps[SymbolIndex];

            if p2^.dType = edtSymbol then
              begin
                if (p2^.Symbol in [soBlockIndentBegin, soPropIndentBegin]) then
                  begin
                    { function call }
                    if not(p1^.dType in MethodToken) then
                      begin
                        PrintError('method Illegal');
                        Break;
                      end
                    else
                      begin
                      end;

                    inc(SymbolIndex);
                    ResOp := ProcessIndent(p2^.Symbol);
                  end
                else if ((OwnerIndentSym = soBlockIndentBegin) and (p2^.Symbol = soBlockIndentEnd)) or
                  ((OwnerIndentSym = soPropIndentBegin) and (p2^.Symbol = soPropIndentEnd)) then
                  begin
                    if LocalOp <> nil then
                      begin
                        LocalOp.AddValueT(p1^.Value, dt2op(p1^.dType));
                      end
                    else
                      begin
                        LocalOp := NewOpValue(uName);
                        LocalOp.AddValueT(p1^.Value, dt2op(p1^.dType));
                      end;
                    Result := LocalOp;
                    Break;
                  end
                else if p2^.Symbol in OpLogicalSymbol then
                  begin
                    if LocalOp <> nil then
                      begin
                        OldOp := LocalOp;
                        OldOp.AddValueT(p1^.Value, dt2op(p1^.dType));
                        LocalOp := NewOpFromSym(p2^.Symbol, uName);
                        LocalOp.AddLink(OldOp);
                      end
                    else
                      begin
                        LocalOp := NewOpFromSym(p2^.Symbol, uName);
                        LocalOp.AddValueT(p1^.Value, dt2op(p1^.dType));
                      end;
                  end
                else
                  begin
                    PrintError('Illegal');
                    Break;
                  end;
              end
            else
              begin
                PrintError('Illegal');
                Break;
              end;
          end;

        inc(SymbolIndex);
      end;
  end;

  procedure ProcessOpContainer(Successed: Boolean);
  var
    i: Integer;
  begin
    for i := 0 to OpContainer.Count - 1 do
      if Successed then
          TOpCode(OpContainer[i]).AutoFreeLink := True
      else
          DisposeObject(TOpCode(OpContainer[i]));
    OpContainer.Clear;
  end;

begin
  Result := nil;
  if SymbExps <> nil then
    begin
      NewSymbExps := RebuildAllSymbol(SymbExps);
      if NewSymbExps <> nil then
        begin
          if DebugMode then
              NewSymbExps.PrintDebug(True);

          if NewSymbExps.GetSymbolCount([soBlockIndentBegin, soPropIndentBegin]) = NewSymbExps.GetSymbolCount([soBlockIndentEnd, soPropIndentEnd]) then
            begin
              OpContainer := TCore_ListForObj.Create;
              SymbolIndex := 0;
              BuildAborted := False;
              Result := ProcessIndent(soUnknow);
              ProcessOpContainer(Result <> nil);
              DisposeObject(OpContainer);
            end;
          DisposeObject(NewSymbExps);
        end;
    end;
end;

function BuildAsOpCode(SymbExps: TSymbolExpression): TOpCode;
begin
  Result := BuildAsOpCode(False, SymbExps, 'Main', -1);
end;

function BuildAsOpCode(DebugMode: Boolean; SymbExps: TSymbolExpression): TOpCode;
begin
  Result := BuildAsOpCode(DebugMode, SymbExps, 'Main', -1);
end;

function BuildAsOpCode(DebugMode: Boolean; TextStyle: TTextStyle; ExpressionText: SystemString): TOpCode;
var
  sym: TSymbolExpression;
  tmp: TOnDeclValue_M; // fixed DCC < XE8
begin
  tmp := nil;
  sym := ParseTextExpressionAsSymbol(TextStyle, '', ExpressionText, tmp, SystemOpRunTime);
  Result := BuildAsOpCode(DebugMode, sym, 'Main', -1);
  DisposeObject(sym);
end;

function BuildAsOpCode(TextStyle: TTextStyle; ExpressionText: SystemString): TOpCode;
var
  sym: TSymbolExpression;
  tmp: TOnDeclValue_M; // fixed DCC < XE8
begin
  tmp := nil;
  sym := ParseTextExpressionAsSymbol(TextStyle, '', ExpressionText, tmp, SystemOpRunTime);
  Result := BuildAsOpCode(False, sym, 'Main', -1);
  DisposeObject(sym);
end;

function BuildAsOpCode(ExpressionText: SystemString): TOpCode;
var
  sym: TSymbolExpression;
begin
  sym := ParseTextExpressionAsSymbol(ExpressionText);
  Result := BuildAsOpCode(False, sym, 'Main', -1);
  DisposeObject(sym);
end;

function BuildAsOpCode(DebugMode: Boolean; TextStyle: TTextStyle; ExpressionText: SystemString; RefrenceOpRT: TOpCustomRunTime): TOpCode;
var
  sym: TSymbolExpression;
  tmp: TOnDeclValue_M; // fixed DCC < XE8
begin
  tmp := nil;
  sym := ParseTextExpressionAsSymbol(TextStyle, '', ExpressionText, tmp, RefrenceOpRT);
  Result := BuildAsOpCode(DebugMode, sym, 'Main', -1);
  DisposeObject(sym);
end;

function BuildAsOpCode(TextStyle: TTextStyle; ExpressionText: SystemString; RefrenceOpRT: TOpCustomRunTime): TOpCode;
var
  sym: TSymbolExpression;
  tmp: TOnDeclValue_M; // fixed DCC < XE8
begin
  tmp := nil;
  sym := ParseTextExpressionAsSymbol(TextStyle, '', ExpressionText, tmp, RefrenceOpRT);
  Result := BuildAsOpCode(False, sym, 'Main', -1);
  DisposeObject(sym);
end;

function BuildAsOpCode(ExpressionText: SystemString; RefrenceOpRT: TOpCustomRunTime): TOpCode;
var
  sym: TSymbolExpression;
begin
  sym := ParseTextExpressionAsSymbol(ExpressionText, RefrenceOpRT);
  Result := BuildAsOpCode(False, sym, 'Main', -1);
  DisposeObject(sym);
end;

function EvaluateExpressionValue_M(UsedCache: Boolean; Special_ASCII_: TListPascalString;
  TextEngClass: TTextParsingClass; TextStyle: TTextStyle; ExpressionText: SystemString; const OnGetValue: TOnDeclValue_M): Variant;
var
  sym: TSymbolExpression;
  Op: TOpCode;
  i: Integer;
begin
  Op := nil;
  if UsedCache then
    begin
      Op := OpCache[ExpressionText];
    end;

  if (Op <> nil) and (UsedCache) then
    begin
      try
        with Op.Clone do
          begin
            Result := OpCode_Execute(SystemOpRunTime);
            Free;
          end;
      except
          Result := NULL;
      end;
    end
  else
    begin
      Result := NULL;
      sym := ParseTextExpressionAsSymbol_M(Special_ASCII_, TextEngClass, TextStyle, '', ExpressionText, OnGetValue, SystemOpRunTime);

      if sym <> nil then
        begin
          Op := BuildAsOpCode(False, sym, 'Main', -1);
          if Op <> nil then
            begin
              try
                Result := Op.OpCode_Execute(SystemOpRunTime);
                if UsedCache then
                  begin
                    OpCache.Add(ExpressionText, Op, True);
                  end
                else
                    DisposeObject(Op);
              except
                  Result := NULL;
              end;
            end;
          DisposeObject(sym);
        end;
    end;
end;

function EvaluateExpressionValue_C(UsedCache: Boolean; Special_ASCII_: TListPascalString;
  TextEngClass: TTextParsingClass; TextStyle: TTextStyle; ExpressionText: SystemString; const OnGetValue: TOnDeclValue_C): Variant;
var
  sym: TSymbolExpression;
  Op: TOpCode;
  i: Integer;
begin
  Op := nil;
  if UsedCache then
    begin
      Op := OpCache[ExpressionText];
    end;

  if (Op <> nil) and (UsedCache) then
    begin
      try
        with Op.Clone do
          begin
            Result := Op.OpCode_Execute(SystemOpRunTime);
            Free;
          end;
      except
          Result := NULL;
      end;
    end
  else
    begin
      Result := NULL;
      sym := ParseTextExpressionAsSymbol_C(Special_ASCII_, TextEngClass, TextStyle, '', ExpressionText, OnGetValue, SystemOpRunTime);

      if sym <> nil then
        begin
          Op := BuildAsOpCode(False, sym, 'Main', -1);
          if Op <> nil then
            begin
              try
                Result := Op.OpCode_Execute(SystemOpRunTime);
                if UsedCache then
                  begin
                    OpCache.Add(ExpressionText, Op, True);
                  end
                else
                    DisposeObject(Op);
              except
                  Result := NULL;
              end;
            end;
          DisposeObject(sym);
        end;
    end;
end;

function EvaluateExpressionValue_P(UsedCache: Boolean; Special_ASCII_: TListPascalString;
  TextEngClass: TTextParsingClass; TextStyle: TTextStyle; ExpressionText: SystemString; const OnGetValue: TOnDeclValue_P): Variant;
var
  sym: TSymbolExpression;
  Op: TOpCode;
  i: Integer;
begin
  Op := nil;
  if UsedCache then
    begin
      Op := OpCache[ExpressionText];
    end;

  if (Op <> nil) and (UsedCache) then
    begin
      try
        with Op.Clone do
          begin
            Result := Op.OpCode_Execute(SystemOpRunTime);
            Free;
          end;
      except
          Result := NULL;
      end;
    end
  else
    begin
      Result := NULL;
      sym := ParseTextExpressionAsSymbol_P(Special_ASCII_, TextEngClass, TextStyle, '', ExpressionText, OnGetValue, SystemOpRunTime);

      if sym <> nil then
        begin
          Op := BuildAsOpCode(False, sym, 'Main', -1);
          if Op <> nil then
            begin
              try
                Result := Op.OpCode_Execute(SystemOpRunTime);
                if UsedCache then
                  begin
                    OpCache.Add(ExpressionText, Op, True);
                  end
                else
                    DisposeObject(Op);
              except
                  Result := NULL;
              end;
            end;
          DisposeObject(sym);
        end;
    end;
end;

{$ENDREGION 'internal imp'}


function OpCache: TOpCode_Pool;
begin
  Result := OpCache___;
end;

procedure CleanOpCache();
begin
  OpCache.Clear;
end;

type
  TExpression_ConstVL = class(TCore_Object_Intermediate)
  public
    VL: THashVariantList;
    procedure GetValue(const Decl: SystemString; var ValType: TExpressionDeclType; var Value: Variant);
  end;

procedure TExpression_ConstVL.GetValue(const Decl: SystemString; var ValType: TExpressionDeclType; var Value: Variant);
begin
  if (VL <> nil) and (VL.Exists(Decl)) then
    begin
      Value := VL[Decl];
      ValType := VariantToExpressionDeclType(Value);
    end
end;

function IsNullExpression(ExpressionText: SystemString; TextStyle: TTextStyle): Boolean;
var
  t: TTextParsing;
  n: U_String;
begin
  t := TTextParsing.Create(ExpressionText, TextStyle, nil, SpacerSymbol.v);
  t.DeletedComment;
  n := t.FastRebuildTokenTo;
  DisposeObject(t);
  Result := n.TrimChar(#13#10#9#32) = '';
  n := '';
end;

function IsSymbolVectorExpression(ExpressionText: SystemString; TextStyle: TTextStyle; Special_ASCII_: TListPascalString): Boolean;
var
  t: TTextParsing;
  L: TPascalStringList;
begin
  Result := False;
  t := TTextParsing.Create(umlDeleteChar(ExpressionText, #13#10#32#9), TextStyle, Special_ASCII_, SpacerSymbol.v);
  L := TPascalStringList.Create;
  if t.Extract_Symbol_Vector(L) then
    begin
      if (L.Count = 2) and (L[1].L = 0) then
          Result := False
      else
          Result := L.Count > 1;
    end;
  DisposeObject(t);
  DisposeObject(L);
end;

function IsSymbolVectorExpression(ExpressionText: SystemString; TextStyle: TTextStyle): Boolean;
begin
  Result := IsSymbolVectorExpression(ExpressionText, TextStyle, nil);
end;

function EvaluateExpressionValue(UsedCache: Boolean;
  Special_ASCII_: TListPascalString; DebugMode: Boolean; TextStyle: TTextStyle; ExpressionText: SystemString;
  opRT: TOpCustomRunTime; const_vl: THashVariantList): Variant;
var
  v: TExpressionValueVector;
  sym: TSymbolExpression;
  Op: TOpCode;
  i: Integer;
  exp_const_vl: TExpression_ConstVL;
begin
  if IsSymbolVectorExpression(ExpressionText, TextStyle, Special_ASCII_) then
    begin
      v := EvaluateExpressionVector(DebugMode, UsedCache, Special_ASCII_, TextStyle, ExpressionText, opRT, const_vl);
      Result := ExpressionValueVectorToStr(v).Text;
      SetLength(v, 0);
      Exit;
    end;

  Op := nil;
  if (UsedCache) and (const_vl = nil) then
    begin
      Op := OpCache[ExpressionText];
    end;

  if (Op <> nil) and (UsedCache) and (const_vl = nil) then
    begin
      try
        with Op.Clone do
          begin
            Result := Op.OpCode_Execute(opRT);
            Free;
          end;
      except
          Result := NULL;
      end;
    end
  else
    begin
      exp_const_vl := TExpression_ConstVL.Create;
      exp_const_vl.VL := const_vl;

      Result := NULL;
      sym := ParseTextExpressionAsSymbol(Special_ASCII_, TextStyle, '', ExpressionText, exp_const_vl.GetValue, opRT);

      if sym <> nil then
        begin
          Op := BuildAsOpCode(DebugMode, sym, 'Main', -1);
          if Op <> nil then
            begin
              try
                Result := Op.OpCode_Execute(opRT);

                if (UsedCache) and (const_vl = nil) then
                  begin
                    OpCache.Add(ExpressionText, Op, True);
                  end
                else
                    DisposeObject(Op);
              except
                  Result := NULL;
              end;
            end;
          DisposeObject(sym);
        end
      else
        begin
        end;
      DisposeObject(exp_const_vl);
    end;
end;

function EvaluateExpressionValue(UsedCache: Boolean; Special_ASCII_: TListPascalString;
  DebugMode: Boolean; TextStyle: TTextStyle; ExpressionText: SystemString; opRT: TOpCustomRunTime): Variant;
begin
  Result := EvaluateExpressionValue(UsedCache, Special_ASCII_, DebugMode, TextStyle, ExpressionText, opRT, nil);
end;

function EvaluateExpressionValue(UsedCache: Boolean; ExpressionText: SystemString; opRT: TOpCustomRunTime): Variant;
begin
  Result := EvaluateExpressionValue(UsedCache, nil, False, tsPascal, ExpressionText, opRT, nil);
end;

function EvaluateExpressionValue(UsedCache: Boolean; ExpressionText: SystemString): Variant;
begin
  Result := EvaluateExpressionValue(UsedCache, nil, False, tsPascal, ExpressionText, SystemOpRunTime, nil);
end;

function EvaluateExpressionValue(UsedCache: Boolean; TextStyle: TTextStyle; ExpressionText: SystemString): Variant;
begin
  Result := EvaluateExpressionValue(UsedCache, nil, False, TextStyle, ExpressionText, SystemOpRunTime, nil);
end;

function EvaluateExpressionValue(UsedCache: Boolean; TextStyle: TTextStyle; ExpressionText: SystemString; opRT: TOpCustomRunTime): Variant;
begin
  Result := EvaluateExpressionValue(UsedCache, nil, False, TextStyle, ExpressionText, opRT, nil);
end;

function EvaluateExpressionValue(UsedCache: Boolean; Special_ASCII_: TListPascalString; DebugMode: Boolean; ExpressionText: SystemString; opRT: TOpCustomRunTime): Variant;
begin
  Result := EvaluateExpressionValue(UsedCache, Special_ASCII_, DebugMode, tsPascal, ExpressionText, opRT, nil);
end;

function EvaluateExpressionValue(UsedCache: Boolean; Special_ASCII_: TListPascalString; ExpressionText: SystemString; opRT: TOpCustomRunTime): Variant;
begin
  Result := EvaluateExpressionValue(UsedCache, Special_ASCII_, False, tsPascal, ExpressionText, opRT, nil);
end;

function EvaluateExpressionValue(UsedCache: Boolean; Special_ASCII_: TListPascalString; DebugMode: Boolean; ExpressionText: SystemString): Variant;
begin
  Result := EvaluateExpressionValue(UsedCache, Special_ASCII_, DebugMode, tsPascal, ExpressionText, SystemOpRunTime, nil);
end;

function EvaluateExpressionValue(UsedCache: Boolean; Special_ASCII_: TListPascalString; ExpressionText: SystemString): Variant;
begin
  Result := EvaluateExpressionValue(UsedCache, Special_ASCII_, False, tsPascal, ExpressionText, SystemOpRunTime, nil);
end;

function EvaluateExpressionValue(UsedCache: Boolean; Special_ASCII_: TListPascalString; TextStyle: TTextStyle; ExpressionText: SystemString; opRT: TOpCustomRunTime): Variant;
begin
  Result := EvaluateExpressionValue(UsedCache, Special_ASCII_, False, TextStyle, ExpressionText, opRT, nil);
end;

function EvaluateExpressionValue(ExpressionText: SystemString; opRT: TOpCustomRunTime): Variant;
begin
  Result := EvaluateExpressionValue(True, ExpressionText, opRT);
end;

function EvaluateExpressionValue(ExpressionText: SystemString): Variant;
begin
  Result := EvaluateExpressionValue(True, ExpressionText);
end;

function EvaluateExpressionValue(TextStyle: TTextStyle; ExpressionText: SystemString): Variant;
begin
  Result := EvaluateExpressionValue(True, nil, False, TextStyle, ExpressionText, SystemOpRunTime);
end;

function EvaluateExpressionValue(TextStyle: TTextStyle; ExpressionText: SystemString; opRT: TOpCustomRunTime): Variant;
begin
  Result := EvaluateExpressionValue(True, nil, False, TextStyle, ExpressionText, opRT);
end;

function EvaluateExpressionValue(Special_ASCII_: TListPascalString; DebugMode: Boolean; ExpressionText: SystemString; opRT: TOpCustomRunTime): Variant;
begin
  Result := EvaluateExpressionValue(True, Special_ASCII_, DebugMode, tsPascal, ExpressionText, opRT);
end;

function EvaluateExpressionValue(Special_ASCII_: TListPascalString; ExpressionText: SystemString; opRT: TOpCustomRunTime): Variant;
begin
  Result := EvaluateExpressionValue(True, Special_ASCII_, False, tsPascal, ExpressionText, opRT);
end;

function EvaluateExpressionValue(Special_ASCII_: TListPascalString; DebugMode: Boolean; ExpressionText: SystemString): Variant;
begin
  Result := EvaluateExpressionValue(True, Special_ASCII_, DebugMode, tsPascal, ExpressionText, SystemOpRunTime);
end;

function EvaluateExpressionValue(Special_ASCII_: TListPascalString; ExpressionText: SystemString): Variant;
begin
  Result := EvaluateExpressionValue(True, Special_ASCII_, False, tsPascal, ExpressionText, SystemOpRunTime);
end;

function EvaluateExpressionValue(Special_ASCII_: TListPascalString; TextStyle: TTextStyle; ExpressionText: SystemString; opRT: TOpCustomRunTime): Variant;
begin
  Result := EvaluateExpressionValue(True, Special_ASCII_, False, TextStyle, ExpressionText, opRT);
end;

function EvaluateExpressionVector(DebugMode, UsedCache: Boolean; Special_ASCII_: TListPascalString; TextStyle: TTextStyle; ExpressionText: SystemString;
  opRT: TOpCustomRunTime; const_vl: THashVariantList): TExpressionValueVector;
var
  t: TTextParsing;
  L: TPascalStringList;
  i: Integer;
begin
  SetLength(Result, 0);
  if ExpressionText = '' then
      Exit;
  t := TTextParsing.Create(ExpressionText, TextStyle, Special_ASCII_, SpacerSymbol.v);
  L := TPascalStringList.Create;
  if t.Extract_Symbol_Vector(L) then
    begin
      SetLength(Result, L.Count);
      for i := 0 to L.Count - 1 do
        begin
          try
              Result[i] := EvaluateExpressionValue(UsedCache, Special_ASCII_, DebugMode, TextStyle, L[i], opRT, const_vl);
          except
              Result[i] := NULL;
          end;
        end;
    end;
  DisposeObject(L);
  DisposeObject(t);
end;

function EvaluateExpressionVector(UsedCache: Boolean; Special_ASCII_: TListPascalString; TextStyle: TTextStyle; ExpressionText: SystemString;
  opRT: TOpCustomRunTime; const_vl: THashVariantList): TExpressionValueVector;
begin
  Result := EvaluateExpressionVector(False, UsedCache, Special_ASCII_, TextStyle, ExpressionText, opRT, const_vl);
end;

function EvaluateExpressionVector(Special_ASCII_: TListPascalString; TextStyle: TTextStyle; ExpressionText: SystemString;
  opRT: TOpCustomRunTime; const_vl: THashVariantList): TExpressionValueVector;
begin
  Result := EvaluateExpressionVector(False, False, Special_ASCII_, TextStyle, ExpressionText, opRT, const_vl);
end;

function EvaluateExpressionVector(ExpressionText: SystemString; opRT: TOpCustomRunTime; const_vl: THashVariantList): TExpressionValueVector;
begin
  Result := EvaluateExpressionVector(nil, tsPascal, ExpressionText, opRT, const_vl);
end;

function EvaluateExpressionVector(ExpressionText: SystemString; const_vl: THashVariantList): TExpressionValueVector;
begin
  Result := EvaluateExpressionVector(ExpressionText, SystemOpRunTime, const_vl);
end;

function EvaluateExpressionVector(ExpressionText: SystemString; TextStyle: TTextStyle): TExpressionValueVector;
begin
  Result := EvaluateExpressionVector(nil, TextStyle, ExpressionText, nil, nil);
end;

function EvaluateExpressionVector(ExpressionText: SystemString): TExpressionValueVector;
begin
  Result := EvaluateExpressionVector(ExpressionText, nil);
end;

function EvaluateExpressionMatrix(W, H: Integer;
  Special_ASCII_: TListPascalString; TextStyle: TTextStyle; ExpressionText: SystemString;
  opRT: TOpCustomRunTime; const_vl: THashVariantList): TExpressionValueMatrix; overload;
var
  buff: TExpressionValueVector;
  i, j, k: Integer;
begin
  SetLength(Result, 0, 0);
  buff := EvaluateExpressionVector(Special_ASCII_, TextStyle, ExpressionText, opRT, const_vl);
  if length(buff) >= W * H then
    begin
      SetLength(Result, H, W);
      k := 0;
      for j := 0 to H - 1 do
        for i := 0 to W - 1 do
          begin
            Result[j, i] := buff[k];
            inc(k);
          end;
    end;
end;

function EvaluateExpressionMatrix(W, H: Integer; ExpressionText: SystemString; opRT: TOpCustomRunTime; const_vl: THashVariantList): TExpressionValueMatrix;
begin
  Result := EvaluateExpressionMatrix(W, H, nil, tsPascal, ExpressionText, opRT, const_vl);
end;

function EvaluateExpressionMatrix(W, H: Integer; ExpressionText: SystemString; const_vl: THashVariantList): TExpressionValueMatrix;
begin
  Result := EvaluateExpressionMatrix(W, H, ExpressionText, SystemOpRunTime, const_vl);
end;

function EvaluateExpressionMatrix(W, H: Integer; ExpressionText: SystemString; TextStyle: TTextStyle): TExpressionValueMatrix;
begin
  Result := EvaluateExpressionMatrix(W, H, nil, TextStyle, ExpressionText, nil, nil);
end;

function EvaluateExpressionMatrix(W, H: Integer; ExpressionText: SystemString): TExpressionValueMatrix;
begin
  Result := EvaluateExpressionMatrix(W, H, ExpressionText, SystemOpRunTime, nil);
end;

function EStr(s: U_String): U_String;
begin
  try
      Result := umlVarToStr(EvaluateExpressionValue(s), False);
  except
      Result := '';
  end;
end;

function EStrToBool(s: U_String; default: Boolean): Boolean;
begin
  try
      Result := EvaluateExpressionValue(s);
  except
      Result := Default;
  end;
end;

function EStrToBool(s: U_String): Boolean;
begin
  Result := EStrToBool(s, False);
end;

function EStrToInt(s: U_String; default: Integer): Integer;
var
  v: Variant;
begin
  try
    v := EvaluateExpressionValue(s);
    if VarIsNumeric(v) then
        Result := v
    else
        Result := default;
  except
      Result := default;
  end;
end;

function EStrToInt(s: U_String): Integer;
begin
  Result := EStrToInt(s, 0);
end;

function EStrToInt64(s: U_String; default: Int64): Int64;
var
  v: Variant;
begin
  try
    v := EvaluateExpressionValue(s);
    if VarIsNumeric(v) then
        Result := v
    else
        Result := default;
  except
      Result := default;
  end;
end;

function EStrToInt64(s: U_String): Int64;
begin
  Result := EStrToInt64(s, 0);
end;

function EStrToUInt64(s: U_String; default: UInt64): UInt64;
var
  v: Variant;
begin
  try
    v := EvaluateExpressionValue(s);
    if VarIsNumeric(v) then
        Result := v
    else
        Result := default;
  except
      Result := default;
  end;
end;

function EStrToUInt64(s: U_String): UInt64;
begin
  Result := EStrToUInt64(s, 0);
end;

function EStrToFloat(s: U_String; default: Double): Double;
begin
  Result := EStrToDouble(s, default);
end;

function EStrToFloat(s: U_String): Double;
begin
  Result := EStrToFloat(s, 0);
end;

function EStrToSingle(s: U_String; default: Single): Single;
var
  v: Variant;
begin
  try
    v := EvaluateExpressionValue(s);
    if VarIsNumeric(v) then
        Result := v
    else
        Result := default;
  except
      Result := default;
  end;
end;

function EStrToSingle(s: U_String): Single;
begin
  Result := EStrToSingle(s, 0);
end;

function EStrToDouble(s: U_String; default: Double): Double;
var
  v: Variant;
begin
  try
    v := EvaluateExpressionValue(s);
    if VarIsNumeric(v) then
        Result := v
    else
        Result := default;
  except
      Result := default;
  end;
end;

function EStrToDouble(s: U_String): Double;
begin
  Result := EStrToDouble(s, 0);
end;

function ExpressionValueIsError(v: Variant): Boolean;
begin
  Result := VarIsNull(v);
end;

function ExpressionValueVectorIsError(v: TExpressionValueVector): Boolean;
var
  i: Integer;
begin
  Result := True;
  for i := low(v) to high(v) do
    if VarIsNull(v[i]) then
        Exit;
  Result := False;
end;

function ExpressionValueVectorToStr(v: TExpressionValueVector): TPascalString;
var
  i: Integer;
begin
  Result := '';
  for i := low(v) to high(v) do
    begin
      if VarIsNull(v[i]) then
          Result.Append('error, ')
      else if VarIsStr(v[i]) then
          Result.Append(VarToStr(v[i]) + ', ')
      else
          Result.Append(VarToStr(v[i]) + ', ');
    end;
  Result := Result.TrimChar(', ');
end;

procedure DoStatusE(v: TExpressionValueVector);
var
  i: Integer;
begin
  for i := low(v) to high(v) do
      DoStatusNoLn(umlVarToStr(v[i]) + ' ');
  DoStatusNoLn;
end;

procedure DoStatusE(v: TExpressionValueMatrix);
var
  i: Integer;
begin
  for i := low(v) to high(v) do
      DoStatusE(v[i]);
end;

procedure EvaluateExpressionVectorAndMatrix_test_;
var
  VL: THashVariantList;
  buff: TExpressionValueVector;
  EM: TExpressionValueMatrix;
begin
  VL := THashVariantList.Create;
  VL['a1'] := 10;
  VL['a2'] := 20;
  VL['a3'] := 30;
  buff := EvaluateExpressionVector(False, True, nil, tsPascal, 'a1,a2,a3,a1*a2,a1+a2+a3,min(a1,a2,a3)*a3', nil, VL);
  EM := EvaluateExpressionMatrix(3, 2, 'a1,a2,a3,a1*a2,a1+a2+a3,min(a1,a2,a3)*a3', VL);
  DoStatus(VarToStr(EvaluateExpressionValue(True, nil, False, tsPascal, 'min(1,2,3),min(1,2,3)', nil, VL)));
  DisposeObject(VL);
  SetLength(buff, 0);
  SetLength(EM, 0, 0);
end;

initialization

OpCache___ := TOpCode_Pool.Create(True, 1024 * 1024);

finalization

DisposeObject(OpCache___);

end.

{ *******************************************************************************
  * Z.Status.Exception_Helper
  *
  * Cross-platform fatal-exception capture for Z.Status.
  *
  * Add this unit to the uses clause and it installs a global
  * unhandled-exception / signal handler automatically. No API calls
  * are required. The interface section intentionally exposes nothing.
  *
  * Platform support
  *   Windows (Delphi, FPC)      - SEH SetUnhandledExceptionFilter
  *   Linux / macOS / FreeBSD
  *     (FPC, Delphi)            - POSIX signal handlers
  *   iOS / Android / other      - no-op (still compiles and links)
  *
  * Source location
  *   Delphi Windows             - parsed from the .map file
  *                                (enable Detailed Map generation)
  *   FPC                        - provided by lineinfo (-gl)
  *   Other                      - raw $Address fallback
  *
  * Output
  *   On a fatal event the handler tries DoStatus first. If that
  *   fails (Z.Status locks or queues may be inconsistent while the
  *   process is being torn down), it falls back to ErrOutput.
  *
  *   After logging, the handler restores the default disposition and
  *   re-raises, so the OS still produces its usual exit code and
  *   core dump behaviour.
  *
  *   Additionally, this unit registers a detail hook on
  *   Z.Core.On_Raise_Info_Detail. That hook fires from Z.Core.RaiseInfo
  *   just before the exception is raised, so every RaiseInfo call is
  *   reported with its source location even when the caller wraps it
  *   in a bare `except end`.
  *
  * Requirements for full location info
  *   Delphi: Project Options -> Linking -> Map file = Detailed.
  *   FPC:    Compile with -gl.
  *
  * Sample output
  *   [Fatal] Unhandled exception code=$C0000005 location=Unit1.pas:78
  *   [Fatal] SIGSEGV
  *   [Exception] Type=EZCoreError Message='[Z.Core] bad input' Location=Unit1.pas:42
  *
  * Notes
  *   The SEH structures and the SetUnhandledExceptionFilter entry
  *   point are declared locally in this unit, because RAD Studio
  *   10.4 and later removed them from the Windows unit. The local
  *   declarations are prefixed with ZH_ to avoid any name clash.
  *
  *   On POSIX targets the signal handler uses fpSignal / fpKill from
  *   BaseUnix. SIG_DFL is a constant whose underlying type is not
  *   always signalhandler_t across FPC versions, so it is converted
  *   explicitly wherever it is passed to fpSignal.
  ******************************************************************************* }

unit Z.Status.Exception_Helper;

{$DEFINE FPC_DELPHI_MODE}
{$I Z.Define.inc}

interface

{*
  * This unit exposes no public API.
  *
  * Adding it to the uses clause is sufficient to install a global
  * fatal-exception / signal handler. See the unit header comment for
  * platform support, behaviour, and requirements.
  *}

implementation

uses
  SysUtils, Classes,
  Z.Core, Z.Status, Z.PascalStrings
{$IFDEF MSWINDOWS}
    , Windows
{$ENDIF}
{$IFDEF FPC}
    , lineinfo
  {$IFDEF UNIX}
      , BaseUnix
  {$ENDIF}
{$ENDIF}
    ;

{*
  * Defines ZHAS_POSIX_SIGNALS for desktop Unix-like targets that
  * support the signal mechanism we use (Linux / macOS / FreeBSD),
  * excluding mobile targets.
  *}
{$IFDEF UNIX}
  {$IFNDEF IOS}
    {$IFNDEF ANDROID}
      {$DEFINE ZHAS_POSIX_SIGNALS}
    {$ENDIF}
  {$ENDIF}
{$ENDIF}

{ ==============================================================================
  Output
  ============================================================================== }

{*
  * Emit_Fatal
  *
  * Attempts to write a report line to Z.Status. If DoStatus raises,
  * or if Z.Status is unusable because we are already unwinding, the
  * line is written directly to ErrOutput.
  *
  * This routine must never raise.
  *}
procedure Emit_Fatal(const Line: string);
begin
  try
    DoStatus(Line);
    Exit;
  except
  end;
  try
    WriteLn(ErrOutput, Line);
  except
  end;
end;

{ ==============================================================================
  Address resolution
  ============================================================================== }

{$IFDEF DELPHI}
{$IFDEF MSWINDOWS}

type
  {*
    * One entry in the parsed .map file: a runtime code address, the
    * corresponding source line number, and the source unit name.
    *}
  TMap_Line_Rec = record
    Addr: NativeUInt;
    Line: Integer;
    Unit_: string;
  end;

var
  G_Map_Entries: array of TMap_Line_Rec;
  G_Map_Loaded_For: string = '';
  G_Map_Base: NativeUInt = 0;
  G_Map_Text_RVA: NativeUInt = $1000;

{*
  * Split a string on runs of spaces and tabs. Empty tokens are
  * discarded. Used by the .map parser.
  *}
function Split_WS(const S: string): TArray<string>;
var
  i, j, N: Integer;
begin
  SetLength(Result, 0);
  N := Length(S);
  i := 1;
  while i <= N do
    begin
      while (i <= N) and (S[i] in [' ', #9]) do
        Inc(i);
      if i > N then
        Break;
      j := i;
      while (j <= N) and not (S[j] in [' ', #9]) do
        Inc(j);
      SetLength(Result, Length(Result) + 1);
      Result[High(Result)] := Copy(S, i, j - i);
      i := j;
    end;
end;

{*
  * Load and parse the .map file next to the current executable. The
  * result is cached by executable path; parsing happens only once.
  *
  * Two sections are used:
  *   - The .text segment header, to determine the ImageBase-relative
  *     base address of code.
  *   - The 'Line numbers for ...' sections, to obtain line entries.
  *
  * Assumes the default ImageBase ($400000 for 32-bit and
  * $140000000 for 64-bit) with no runtime relocation. With a custom
  * /BASE: linker option or with ASLR enabled the computed addresses
  * may be off.
  *}
procedure Load_Map_File_Once;
var
  ExePath, MapPath: string;
  SL: TStringList;
  i, P, Q, N, k: Integer;
  S: string;
  Tokens: TArray<string>;
  LineNum: Integer;
  SegHex: string;
  InLineSection: Boolean;
  UnitName: string;
begin
  ExePath := GetModuleName(HInstance);
  if ExePath = G_Map_Loaded_For then
    Exit;
  G_Map_Loaded_For := ExePath;
  SetLength(G_Map_Entries, 0);
  G_Map_Base := NativeUInt(GetModuleHandle(nil));
  G_Map_Text_RVA := $1000;

  MapPath := ChangeFileExt(ExePath, '.map');
  if not FileExists(MapPath) then
    Exit;

  SL := TStringList.Create;
  try
    try
      SL.LoadFromFile(MapPath);
    except
      Exit;
    end;

    {*
      * Phase 1: locate the .text segment header. Example line:
      *   0001:00401000 0009D044H .text  CODE
      * The RVA is computed as segment_start - ImageBase.
      *}
    for i := 0 to SL.Count - 1 do
      begin
        S := SL[i];
        if (Pos('.text', S) > 0) and (Pos('CODE', S) > 0) then
          begin
            Tokens := Split_WS(Trim(S));
            if Length(Tokens) >= 1 then
              begin
                P := Pos(':', Tokens[0]);
                if P > 0 then
                  begin
                    SegHex := Copy(Tokens[0], P + 1, MaxInt);
                    if TryStrToInt('$' + SegHex, N) then
                      begin
                        if SizeOf(Pointer) = 8 then
                          G_Map_Text_RVA :=
                            NativeUInt(N) - NativeUInt($140000000)
                        else
                          G_Map_Text_RVA :=
                            NativeUInt(N) - NativeUInt($400000);
                      end;
                  end;
              end;
            Break;
          end;
      end;

    {*
      * Phase 2: walk the 'Line numbers for ...' sections. Each entry
      * looks like '  123 0001:00001234'; several entries may appear
      * on a single line.
      *}
    InLineSection := False;
    UnitName := '';
    for i := 0 to SL.Count - 1 do
      begin
        S := SL[i];
        if Trim(S) = '' then
          Continue;

        {*
          * Section header, e.g.:
          *   Line numbers for Unit1(Unit1.pas) segment .text
          *}
        if Pos('Line numbers for ', S) = 1 then
          begin
            InLineSection := True;
            P := Pos('(', S);
            if P > 0 then
              begin
                Q := Pos(')', S);
                if Q > P then
                  UnitName := Copy(S, P + 1, Q - P - 1);
              end;
            Continue;
          end;

        if not InLineSection then
          Continue;

        {*
          * Section terminator. Detailed map files use lines starting
          * with 'Detailed' or 'Publics'.
          *}
        if (Pos('Detailed', S) = 1) or (Pos('Publics', S) = 1) then
          begin
            InLineSection := False;
            Continue;
          end;

        Tokens := Split_WS(S);
        k := 0;
        while k + 1 < Length(Tokens) do
          begin
            if TryStrToInt(Tokens[k], LineNum)
               and (Pos(':', Tokens[k + 1]) > 0) then
              begin
                SegHex := Copy(Tokens[k + 1],
                               Pos(':', Tokens[k + 1]) + 1,
                               MaxInt);
                if TryStrToInt('$' + SegHex, N) then
                  begin
                    SetLength(G_Map_Entries,
                              Length(G_Map_Entries) + 1);
                    with G_Map_Entries[High(G_Map_Entries)] do
                      begin
                        Addr  := G_Map_Base + G_Map_Text_RVA + NativeUInt(N);
                        Line  := LineNum;
                        Unit_ := UnitName;
                      end;
                  end;
                Inc(k, 2);
              end
            else
              Inc(k);
          end;
      end;
  finally
    SL.Free;
  end;
end;

{*
  * Translate a runtime code address to 'Unit.pas:Line' using the
  * parsed .map file. Returns '$Address' when no matching entry is
  * found, or '<nil>' for a null pointer.
  *}
function Resolve_Address_To_Location(Addr: Pointer): string;
var
  i, Best: Integer;
  BestAddr, Target: NativeUInt;
begin
  if Addr = nil then
    begin
      Result := '<nil>';
      Exit;
    end;

  try
    Load_Map_File_Once;
  except
    Result := '$' + IntToHex(NativeUInt(Addr), SizeOf(Pointer) * 2);
    Exit;
  end;

  Target   := NativeUInt(Addr);
  Best     := -1;
  BestAddr := 0;

  {*
    * Linear scan for the entry with the largest address that does
    * not exceed Target. We do not rely on the entries being sorted.
    *}
  for i := 0 to High(G_Map_Entries) do
    begin
      if (G_Map_Entries[i].Addr <= Target)
         and (G_Map_Entries[i].Addr > BestAddr) then
        begin
          BestAddr := G_Map_Entries[i].Addr;
          Best     := i;
        end;
    end;

  if Best >= 0 then
    Result := G_Map_Entries[Best].Unit_ + ':' +
              IntToStr(G_Map_Entries[Best].Line)
  else
    Result := '$' + IntToHex(Target, SizeOf(Pointer) * 2);
end;

{$ELSE DELPHI}

{*
  * Delphi on a non-Windows platform: the .map parser is not
  * available, so return the raw address.
  *}
function Resolve_Address_To_Location(Addr: Pointer): string;
begin
  if Addr = nil then
    Result := '<nil>'
  else
    Result := '$' + IntToHex(NativeUInt(Addr), SizeOf(Pointer) * 2);
end;
{$ENDIF}
{$ENDIF}

{$IFDEF FPC}

{*
  * FPC: use the lineinfo unit. If the program was not compiled with
  * -gl, GetLineInfo returns False and the raw address is returned.
  *
  * FPC's GetLineInfo signature on Win64 / Linux x86_64 is:
  *   function GetLineInfo(addr: QWord;
  *                        var func: ShortString;
  *                        var source: ShortString;
  *                        var line: LongInt): Boolean;
  *
  * On 32-bit targets the first parameter is LongWord; the cast via
  * NativeUInt keeps the same source valid everywhere.
  *}
function Resolve_Address_To_Location(Addr: Pointer): string;
var
  FuncName: ShortString;
  SourceName: ShortString;
  LineNum: LongInt;
  HexAddr: string;
begin
  if Addr = nil then
    begin
      Result := '<nil>';
      Exit;
    end;

  HexAddr := '$' + IntToHex(NativeUInt(Addr), SizeOf(Pointer) * 2);

  try
    if GetLineInfo(QWord(NativeUInt(Addr)), FuncName, SourceName, LineNum)
       and (SourceName <> '') then
      Result := string(SourceName) + ':' + IntToStr(LineNum)
    else
      Result := HexAddr;
  except
    Result := HexAddr;
  end;
end;
{$ENDIF}

{ ==============================================================================
  Windows: SEH unhandled exception filter
  ============================================================================== }

{$IFDEF MSWINDOWS}

type
  {*
    * Local declaration of the SEH structures.
    *
    * RAD Studio 10.4 and later removed TUnhandledExceptionFilterProc
    * and PExceptionPointers from the Windows unit, so we declare our
    * own copies here. The ZH_ prefix avoids any clash with symbols
    * that may still exist in older RTLs or in FPC's Windows unit.
    *}
  PZH_Exception_Pointers = ^TZH_Exception_Pointers;
  TZH_Exception_Pointers = record
    ExceptionRecord: Pointer;
    ContextRecord:   Pointer;
  end;

  PZH_Exception_Record = ^TZH_Exception_Record;
  TZH_Exception_Record = record
    ExceptionCode:        LongWord;
    ExceptionFlags:       LongWord;
    ExceptionRecord:      PZH_Exception_Record;
    ExceptionAddress:     Pointer;
    NumberParameters:     LongWord;
    ExceptionInformation: array[0..14] of NativeUInt;
  end;

  {*
    * The unhandled-exception filter prototype, matching the Win32
    * LPTOP_LEVEL_EXCEPTION_FILTER signature.
    *}
  TZH_Unhandled_Filter = function(
    ep: PZH_Exception_Pointers): LongInt; stdcall;

const
  {*
    * Win32 EXCEPTION_CONTINUE_SEARCH. Defined locally because newer
    * RTLs may not export it.
    *}
  ZH_EXCEPTION_CONTINUE_SEARCH = 0;

{*
  * Import kernel32!SetUnhandledExceptionFilter under a private alias
  * to avoid any clash with the RTL's own declaration.
  *}
function ZH_SetUnhandledExceptionFilter(
  lpTopLevelExceptionFilter: TZH_Unhandled_Filter): TZH_Unhandled_Filter;
  stdcall; external 'kernel32.dll' name 'SetUnhandledExceptionFilter';

var
  Prev_Unhandled_Filter: TZH_Unhandled_Filter = nil;

{*
  * Windows_Unhandled_Filter
  *
  * Called by the OS when an unhandled SEH exception reaches the top
  * of the thread. Reports the exception code and, when possible, the
  * source location of the faulting instruction, then chains to the
  * previously installed filter (or continues the search so the
  * default OS behaviour, including WER / core dump, still runs).
  *}
function Windows_Unhandled_Filter(
  ep: PZH_Exception_Pointers): LongInt; stdcall;
var
  Code: LongWord;
  Addr: Pointer;
  Loc:  string;
begin
  try
    if (ep <> nil) and (ep^.ExceptionRecord <> nil) then
      begin
        Code := PZH_Exception_Record(ep^.ExceptionRecord)^.ExceptionCode;
        Addr := PZH_Exception_Record(ep^.ExceptionRecord)^.ExceptionAddress;

        Loc := '';
        try
          Loc := Resolve_Address_To_Location(Addr);
        except
        end;

        Emit_Fatal(Format(
          '[Fatal] Unhandled exception code=$%.8x location=%s',
          [Code, Loc]));
      end;
  except
    {*
      * Never raise from an unhandled exception filter.
      *}
  end;

  if Assigned(Prev_Unhandled_Filter) then
    Result := Prev_Unhandled_Filter(ep)
  else
    Result := ZH_EXCEPTION_CONTINUE_SEARCH;
end;
{$ENDIF}

{ ==============================================================================
  POSIX: signal handlers
  ============================================================================== }

{$IFDEF ZHAS_POSIX_SIGNALS}
{$IFDEF FPC}

const
  {*
    * POSIX signal numbers. Stable across Linux, macOS, and BSDs.
    *}
  CSIG_ILL  = 4;
  CSIG_ABRT = 6;
  CSIG_FPE  = 8;
  CSIG_SEGV = 11;
{$ELSE}

type
  {*
    * The libc 'signal' and 'raise' entry points. Declared directly to
    * keep the unit self-contained; libc is linked implicitly on the
    * relevant targets.
    *}
  TC_Signal_Handler = procedure(sig: cint); cdecl;

function c_signal(signum: cint;
                  handler: TC_Signal_Handler): TC_Signal_Handler;
  cdecl; external 'c' name 'signal';
function c_raise(sig: cint): cint;
  cdecl; external 'c' name 'raise';

const
  CSIG_ILL  = 4;
  CSIG_ABRT = 6;
  CSIG_FPE  = 8;
  CSIG_SEGV = 11;
{$ENDIF}

var
  In_Signal_Handler: Boolean = False;

{*
  * Posix_Signal_Handler
  *
  * Reports the signal, then restores the default disposition and
  * re-raises so the OS can terminate the process with its usual
  * exit code and (if enabled) produce a core dump.
  *
  * If a signal arrives while we are already inside the handler, the
  * default disposition is restored immediately to avoid infinite
  * recursion.
  *
  * Note on SIG_DFL
  *   In some FPC versions SIG_DFL is just the integer constant 0,
  *   whose inferred type (ShortInt) does not match the signalhandler_t
  *   parameter expected by fpSignal. The explicit cast to
  *   signalhandler_t resolves the mismatch and is a no-op at the
  *   machine level.
  *}
procedure Posix_Signal_Handler(sig: cint); cdecl;
var
  SigName: string;
begin
  if In_Signal_Handler then
    begin
{$IFDEF FPC}
      fpSignal(sig, signalhandler_t(SIG_DFL));
      fpKill(fpGetPid, sig);
{$ELSE}
      c_signal(sig, nil);
      c_raise(sig);
{$ENDIF}
      Exit;
    end;

  In_Signal_Handler := True;
  try
    case sig of
      CSIG_ILL:  SigName := 'SIGILL';
      CSIG_ABRT: SigName := 'SIGABRT';
      CSIG_FPE:  SigName := 'SIGFPE';
      CSIG_SEGV: SigName := 'SIGSEGV';
    else
      SigName := 'Signal(' + IntToStr(sig) + ')';
    end;

    Emit_Fatal('[Fatal] ' + SigName);
  except
  end;

{$IFDEF FPC}
  fpSignal(sig, signalhandler_t(SIG_DFL));
  fpKill(fpGetPid, sig);
{$ELSE}
  c_signal(sig, nil);
  c_raise(sig);
{$ENDIF}
end;
{$ENDIF}

{ ==============================================================================
  Hook installation
  ============================================================================== }

{$IFDEF MSWINDOWS}

procedure Install_Platform_Hooks;
begin
  Prev_Unhandled_Filter :=
    ZH_SetUnhandledExceptionFilter(@Windows_Unhandled_Filter);
end;

procedure Uninstall_Platform_Hooks;
begin
  if Assigned(Prev_Unhandled_Filter) then
    ZH_SetUnhandledExceptionFilter(Prev_Unhandled_Filter);
  Prev_Unhandled_Filter := nil;
end;
{$ELSE}
  {$IFDEF ZHAS_POSIX_SIGNALS}

procedure Install_Platform_Hooks;
begin
{$IFDEF FPC}
  fpSignal(CSIG_ILL,  @Posix_Signal_Handler);
  fpSignal(CSIG_ABRT, @Posix_Signal_Handler);
  fpSignal(CSIG_FPE,  @Posix_Signal_Handler);
  fpSignal(CSIG_SEGV, @Posix_Signal_Handler);
{$ELSE}
  c_signal(CSIG_ILL,  Posix_Signal_Handler);
  c_signal(CSIG_ABRT, Posix_Signal_Handler);
  c_signal(CSIG_FPE,  Posix_Signal_Handler);
  c_signal(CSIG_SEGV, Posix_Signal_Handler);
{$ENDIF}
end;

procedure Uninstall_Platform_Hooks;
begin
{$IFDEF FPC}
  fpSignal(CSIG_ILL,  signalhandler_t(SIG_DFL));
  fpSignal(CSIG_ABRT, signalhandler_t(SIG_DFL));
  fpSignal(CSIG_FPE,  signalhandler_t(SIG_DFL));
  fpSignal(CSIG_SEGV, signalhandler_t(SIG_DFL));
{$ELSE}
  c_signal(CSIG_ILL,  nil);
  c_signal(CSIG_ABRT, nil);
  c_signal(CSIG_FPE,  nil);
  c_signal(CSIG_SEGV, nil);
{$ENDIF}
end;
  {$ELSE}

{*
  * No supported platform-specific mechanism on this target. The unit
  * still compiles and links; the hooks are no-ops.
  *}
procedure Install_Platform_Hooks;
begin
end;

procedure Uninstall_Platform_Hooks;
begin
end;
  {$ENDIF}
{$ENDIF}

{ ==============================================================================
  Z.Core RaiseInfo detail hook
  ============================================================================== }

{*
  * On_Core_Raise_Info_Detail
  *
  * Registered into Z.Core.On_Raise_Info_Detail during unit init.
  * It is called by Z.Core.RaiseInfo just before the exception is
  * raised. Emitting the report here ensures that a caller writing a
  * bare `except end` still gets a log line with source location.
  *
  * Never raises - the surrounding code in Z.Core also wraps this in
  * try/except, but we are defensive here as well.
  *}
procedure On_Core_Raise_Info_Detail(const Msg: string;
  Caller_Address: Pointer);
var
  Loc: string;
begin
  try
    Loc := Resolve_Address_To_Location(Caller_Address);
    Emit_Fatal(Format(
      '[Exception] Type=EZCoreError Message=''[Z.Core] %s'' Location=%s',
      [Msg, Loc]));
  except
  end;
end;

initialization
  {*
    * Register the detailed RaiseInfo hook before installing the
    * platform hooks so that even a very early RaiseInfo call is
    * reported. The order does not affect correctness, but it is
    * clearer this way.
    *}
  Z.Core.On_Raise_Info_Detail := On_Core_Raise_Info_Detail;
  Install_Platform_Hooks;

finalization
  Z.Core.On_Raise_Info_Detail := nil;
  Uninstall_Platform_Hooks;

end.

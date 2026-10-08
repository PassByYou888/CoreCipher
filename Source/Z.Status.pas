{ ******************************************************************************
  * Z.Status – Thread‑safe status/logging subsystem with queued output,        *
  *            multiple hook types, and optional console echoing.              *
  *                                                                            *
  * This unit provides a centralised way to emit status messages from any      *
  * thread.  Messages are stored in a thread‑safe queue and are delivered      *
  * asynchronously (or synchronously from the main thread) to registered       *
  * hooks.  Hooks can be methods, plain procedures, or nested/reference        *
  * procedures.  Additionally, the unit supports buffered “no‑line” output     *
  * (DoStatusNoLn) for building a line incrementally, and it can display       *
  * memory dumps, string lists, and various primitive types.                   *
  *                                                                            *
  * The global OnDoStatusHook can be replaced to intercept all messages,       *
  * but the default implementation (InternalDoStatus) handles queuing and      *
  * dispatch.  Console output can be enabled/disabled independently.           *
  *                                                                            *
  * @Note All public routines are thread‑safe.  The queue is processed         *
  *       automatically when the main thread calls CheckDoStatus (which        *
  *       is hooked into Z.Core.OnCheckThreadSynchronize).                     *
  ****************************************************************************** }
unit Z.Status;

{$DEFINE FPC_DELPHI_MODE}
{$I Z.Define.inc}

interface

uses
{$IFDEF MSWINDOWS}
  Windows,
{$ENDIF}
  SysUtils, Classes, SyncObjs,
{$IFDEF FPC}
  Z.FPC.GenericList, fgl,
{$ENDIF FPC}
  Z.Core, Z.PascalStrings, Z.UPascalStrings, Z.UnicodeMixedLib;

type
  {
    * TDoStatus_P – Status callback that captures its enclosing context.
    *               In FPC this is declared as “is nested”; in Delphi it is a
    *               “reference to procedure”.  Use this style when you need to
    *               access local variables of the calling routine from inside
    *               the callback.
    *
    * @param Text_   The status message string (system encoding).
    * @param ID      An integer tag that can be used to classify or filter
    *                the message (e.g. error level, module number).
    *
    * @Example
    *   procedure Outer;
    *   var
    *     LocalVar: Integer;
    *   begin
    *     LocalVar := 42;
    *     AddDoStatusHookP(Self,
    *       procedure(Text_: SystemString; const ID: Integer)
    *       begin
    *         DoStatus(Format('LocalVar=%d, msg=%s', [LocalVar, Text_]));
    *       end
    *     );
    *   end;
  }
{$IFDEF FPC}
  TDoStatus_P = procedure(Text_: SystemString; const ID: Integer) is nested;
{$ELSE FPC}
  TDoStatus_P = reference to procedure(Text_: SystemString; const ID: Integer);
{$ENDIF FPC}
  {
    * TDoStatus_M – Object‑method callback for status notifications.
    * Use this style when you want to handle status messages in a method
    * of a class instance.  The instance (Self) is automatically available.
    *
    * @param Text_   The message text.
    * @param ID      User‑defined integer identifier.
    *
    * @Example
    *   TMyLogger = class
    *     procedure LogStatus(Text_: SystemString; const ID: Integer);
    *   end;
    *   ...
    *   AddDoStatusHookM(MyLogger, MyLogger.LogStatus);
  }
  TDoStatus_M = procedure(Text_: SystemString; const ID: Integer) of object;

  {
    * TDoStatus_C – Plain procedural callback (standalone function or
    *               class static method).
    * Use this when you have a plain procedure that does not need object
    * state or nested context.
    *
    * @param Text_   The status message.
    * @param ID      Identifier tag.
    *
    * @Example
    *   procedure MyGlobalHandler(Text_: SystemString; const ID: Integer);
    *   begin
    *     // process message
    *   end;
    *   ...
    *   AddDoStatusHookC(Self, MyGlobalHandler);
  }
  TDoStatus_C = procedure(Text_: SystemString; const ID: Integer);

  {
    * Registers a method‑based status hook.
    * The hook will be called for every status message that is emitted.
    * Multiple hooks can be registered; they are invoked in the order they
    * were added.
    *
    * @param TokenObj   An arbitrary object reference that identifies this
    *                   hook.  Must be the same token passed to
    *                   DeleteDoStatusHook to remove the hook.
    * @param OnNotify   The method to call when a status message arrives.
    *
    * @Note The TokenObj is not used for invocation; it only serves as a
    *       key for removal.  It can be any object (e.g. the owning class).
    *
    * @Example
    *   AddDoStatusHookM(Self, MyForm.StatusDisplay);
  }
procedure AddDoStatusHook(TokenObj: TCore_Object; OnNotify: TDoStatus_M);
procedure AddDoStatusHookM(TokenObj: TCore_Object; OnNotify: TDoStatus_M); // Alias for AddDoStatusHook

{
  * Registers a plain procedural status hook.
  *
  * @param TokenObj   Token for later removal.
  * @param OnNotify   The procedure to call.
  *
  * @Example
  *   AddDoStatusHookC(Self, ConsoleLogger);
}
procedure AddDoStatusHookC(TokenObj: TCore_Object; OnNotify: TDoStatus_C);

{
  * Registers a nested/reference procedure status hook.
  *
  * @param TokenObj   Token for removal.
  * @param OnNotify   The nested procedure or anonymous method.
  *
  * @Example
  *   AddDoStatusHookP(Self,
  *     procedure(Text_: SystemString; const ID: Integer)
  *     begin
  *       Memo1.Lines.Add(Text_);
  *     end
  *   );
}
procedure AddDoStatusHookP(TokenObj: TCore_Object; OnNotify: TDoStatus_P);

{
  * Removes all status hooks that were registered with the given token.
  *
  * @param TokenObj   The object token used when adding the hook(s).
  *
  * @Example
  *   DeleteDoStatusHook(Self);  // remove all hooks owned by this object
}
procedure DeleteDoStatusHook(TokenObj: TCore_Object);
procedure RemoveDoStatusHook(TokenObj: TCore_Object); // Alias for DeleteDoStatusHook

{
  * Temporarily disables all status output.
  * After calling this, no status messages will be delivered to any hook,
  * and no console output will appear.  The internal queue is still
  * accumulating messages (they are not lost) but they will not be
  * dispatched until EnabledStatus is called.
  *
  * @Note To completely flush the queue while disabled, call
  *       Wait_DoStatus_Queue after re‑enabling.
}
procedure DisableStatus;

{
  * Re‑enables status output that was previously disabled.
  * All queued messages will be delivered immediately (or on the next
  * check) after this call.
}
procedure EnabledStatus;

function Is_EnabledStatus: Boolean; // Returns True if status output is currently enabled.
function Is_DisableStatus: Boolean; // Returns True if status output is currently disabled.
function Get_DoStatus_Queue_Num: NativeInt; // Returns the number of pending status messages in the queue.

{
  * Blocks the calling thread until the status queue becomes empty.
  * Useful when you need to ensure that all previously emitted messages
  * have been delivered before performing a critical action (e.g. shutting
  * down).
  *
  * @Note This method polls the queue and sleeps for 10 ms between checks.
  *       It should not be called from the main thread’s message loop
  *       unless you are certain that the queue will be emptied quickly.
}
procedure Wait_DoStatus_Queue;

{
  * Emits a status message with a given identifier.
  * This is the most basic overload; all other overloads eventually call
  * this one.
  *
  * @param Text_   The message text.
  * @param ID      An integer tag (default 0 if omitted).
  *
  * @Example
  *   DoStatus('Server started', 1);
}
procedure DoStatus__(Text_: SystemString; const ID: Integer);
procedure DoStatus(Text_: SystemString; const ID: Integer); overload;

{
  * Dumps a memory buffer in hexadecimal format, with a specified number
  * of bytes per line.
  *
  * @param v      Pointer to the buffer.
  * @param siz    Size of the buffer in bytes.
  * @param width  Number of bytes to display per line (must be even).
  *
  * @Example
  *   DoStatus(@myBuffer, 32, 16);
}
procedure DoStatus(const v: Pointer; siz, width: NativeInt); overload;

{
  * Dumps a memory buffer with a prefix string prepended to each line.
  *
  * @param prefix  String to add before each hexadecimal line.
  * @param v       Pointer to buffer.
  * @param siz     Buffer size.
  * @param width   Bytes per line.
  *
  * @Example
  *   DoStatus('Data: ', @buf, 64, 16);
}
procedure DoStatus(prefix: SystemString; v: Pointer; siz, width: NativeInt); overload;

{
  * Outputs each string in a TCore_Strings collection as a separate status
  * message.  If the string has an associated object, its class name is
  * appended.
  *
  * @param v   The string list to output.
  *
  * @Example
  *   DoStatus(StringList);
}
procedure DoStatus(const v: TCore_Strings); overload;

procedure DoStatus(const v: Int64); overload; // Outputs an Int64 value as a decimal string.
procedure DoStatus(const v: Integer); overload; // Outputs an Integer value as a decimal string.
procedure DoStatus(const v: Single); overload; // Outputs a Single value as a string.
procedure DoStatus(const v: Double); overload; // Outputs a Double value as a string.
procedure DoStatusPtr(const v: Pointer); overload; // Outputs a pointer address in hexadecimal format (0x...).

{
  * Formats a string using SysUtils.Format and outputs the result.
  *
  * @param v      Format string.
  * @param Args   Arguments for the format placeholders.
  *
  * @Example
  *   DoStatus('Value = %d, Name = %s', [123, 'test']);
}
procedure DoStatus(const v: SystemString; const Args: array of const); overload;

procedure DoStatus(const v: SystemString); overload; // Outputs a plain string message (ID=0).
procedure DoStatus(const v1, v2: SystemString); overload; // Concatenates two strings and outputs.
procedure DoStatus(const v1, v2, v3: SystemString); overload; // Concatenates three strings.

procedure DoStatus(const v: TPascalString); overload; // Outputs a TPascalString message.
procedure DoStatus(const v1, v2: TPascalString); overload;
procedure DoStatus(const v1, v2, v3: TPascalString); overload;

procedure DoStatus(const v: TUPascalString); overload; // Outputs a TUPascalString message.
procedure DoStatus(const v1, v2: TUPascalString); overload;
procedure DoStatus(const v1, v2, v3: TUPascalString); overload;

procedure DoStatus(const v: TMD5); overload; // Outputs an MD5 digest as a hexadecimal string.

{
  * Outputs a buffer as a hexadecimal string (without line breaks).
  *
  * @param p    Pointer to buffer.
  * @param siz  Size in bytes.
}
procedure DoStatus(const p: Pointer; const siz: Integer); overload;

{
  * Processes one pending status message from the queue and delivers it to
  * all hooks.  This is called automatically from the main thread’s
  * synchronisation hook, but you may call it explicitly to force
  * processing.
  *
  * @Note If the queue is empty, this does nothing.
}
procedure CheckDoStatus();

procedure DoStatus(); overload; // Emits an empty line (calls CheckDoStatus).
procedure Post_To_DoStatus_Queue(Th: TCore_Thread; Text_: SystemString; const ID: Integer);

{
  * ConsoleWrite – Write a string to the console
}
procedure ConsoleWrite(const S: string);
procedure ConsoleWriteLn(const S: string);

{
  * Appends text to a per‑thread buffer that accumulates a line without
  * emitting a line break.  When a line break character (#13 or #10) is
  * encountered, the accumulated line is flushed as a normal status
  * message.
  *
  * Use this to build a status line incrementally from multiple pieces.
  *
  * @param v   The text to append (may contain line breaks).
  *
  * @Example
  *   DoStatusNoLn('Progress: ');
  *   for i := 1 to 100 do
  *   begin
  *     // append a dot without newline
  *     if i mod 10 = 0 then
  *       DoStatusNoLn('.' + #13#10)   // flush line every 10 dots
  *     else
  *       DoStatusNoLn('.');
  *   end;
}
procedure DoStatusNoLn(const v: TPascalString); overload;

{
  * Appends a formatted string to the current no‑line buffer.
  *
  * @param v      Format string.
  * @param Args   Format arguments.
}
procedure DoStatusNoLn(const v: SystemString; const Args: array of const); overload;

{
  * Forces the current no‑line buffer to be flushed as a complete status
  * line (even if it does not contain a line break).
  *
  * @Example
  *   DoStatusNoLn('Partial line');
  *   // ... later ...
  *   DoStatusNoLn;   // flush it now
}
procedure DoStatusNoLn; overload;

var
  { The last status message that was actually delivered to any hook.
    Useful for debugging or for retrieving the most recent message. }
  LastDoStatus: SystemString;

  { If True, status messages are also written to the console (via Writeln)
    when the application is a console application.  Default is True. }
  ConsoleOutput: Boolean;

  {
    * The core dispatch routine for all status messages.  By default it
    * points to InternalDoStatus, which queues the message and handles
    * console output.  Advanced users may replace this with a custom
    * procedure to intercept all status output at the lowest level.
    *
    * @Note The replacement must handle all calls; if you want to keep the
    *       existing functionality, call the old hook inside your custom
    *       routine.
  }
  OnDoStatusHook: TDoStatus_C;

  {
    * If True, messages that originate from non‑main threads have the
    * thread ID prepended in brackets, e.g. “[1234] message”.  This helps
    * identify which thread emitted each message.  Default is True.
  }
  StatusThreadID: Boolean;

  {
    * Maximum number of queued messages to process in one call to
    * CheckDoStatus.  This prevents the main thread from being blocked for
    * too long when processing a large burst of messages.  Default is 20.
  }
  One_Step_Status_Limit: Integer;

implementation

uses Z.Cipher, Z.Status.Exception_Helper;

{
  * bufHashToString – Converts a binary buffer into a hexadecimal string.
  *
  * @param hash    Pointer to the buffer.
  * @param Size    Number of bytes.
  * @param output  (out) Receives the hex string (uppercase, no spaces).
}
procedure bufHashToString(hash: Pointer; Size: NativeInt; var output: TPascalString);
const
  HexArr: array [0 .. 15] of SystemChar = ('0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'A', 'B', 'C', 'D', 'E', 'F');
var
  i: Integer;
begin
  output.Len := Size * 2; // Each byte becomes two hex characters.
  for i := 0 to Size - 1 do
    begin
      output.buff[i * 2] := HexArr[(PByte(nativeUInt(hash) + i)^ shr 4) and $0F]; // High nibble.
      output.buff[i * 2 + 1] := HexArr[PByte(nativeUInt(hash) + i)^ and $0F]; // Low nibble.
    end;
end;

{ ******************************************************************************
  * DoStatus (ID overload) – The central entry point for all status messages.  *
  * It calls the global OnDoStatusHook (default InternalDoStatus).             *
  ****************************************************************************** }
procedure DoStatus__(Text_: SystemString; const ID: Integer);
begin
  try
      OnDoStatusHook(Text_, ID);
  except
    // silently ignore any exceptions from hooks
  end;
end;

procedure DoStatus(Text_: SystemString; const ID: Integer);
begin
  DoStatus__(Text_, ID);
end;

{
  * Hex dump with no prefix.  Calls bufHashToString and splits the hex
  * string into lines of `width` bytes each.
  *
  * The resulting hex string is split into groups of two characters per byte,
  * with a space between groups.  Lines are emitted via DoStatus.
}
procedure DoStatus(const v: Pointer; siz, width: NativeInt);
var
  S: TPascalString;
  i: Integer;
  n: SystemString;
begin
  bufHashToString(v, siz, S);
  n := '';
  for i := 1 to S.Len div 2 do
    begin
      if n <> '' then
          n := n + #32 + S[i * 2 - 1] + S[i * 2] // Append byte as two hex chars with a leading space.
      else
          n := S[i * 2 - 1] + S[i * 2]; // First byte without leading space.

      if i mod (width div 2) = 0 then // After `width` bytes, emit the line and reset.
        begin
          DoStatus(n);
          n := '';
        end;
    end;
  if n <> '' then
      DoStatus(n); // Emit any remaining bytes as a partial last line.
end;

{
  * Hex dump with a prefix string prepended to each line.
  * Works identically to the above, but each line is prefixed with `prefix`.
}
procedure DoStatus(prefix: SystemString; v: Pointer; siz, width: NativeInt);
var
  S: TPascalString;
  i: Integer;
  n: SystemString;
begin
  bufHashToString(v, siz, S);
  n := '';
  for i := 1 to S.Len div 2 do
    begin
      if n <> '' then
          n := n + #32 + S[i * 2 - 1] + S[i * 2]
      else
          n := S[i * 2 - 1] + S[i * 2];

      if i mod (width div 2) = 0 then
        begin
          DoStatus(prefix + n);
          n := '';
        end;
    end;
  if n <> '' then
      DoStatus(prefix + n);
end;

{
  * Outputs each string in a TCore_Strings collection.  If an item has an
  * associated object, its class name is appended in angle brackets.
}
procedure DoStatus(const v: TCore_Strings);
var
  i: Integer;
  o: TCore_Object;
begin
  for i := 0 to v.Count - 1 do
    begin
      o := v.Objects[i];
      if o <> nil then
          DoStatus('%s<%s>', [v[i], o.ClassName]) // Show object class if present.
      else
          DoStatus(v[i]);
    end;
end;

{ -----------------------------------------------------------------------------
  Overloads for simple types – convert to string and call DoStatus.
}
procedure DoStatus(const v: Int64);
begin
  DoStatus(IntToStr(v));
end;

procedure DoStatus(const v: Integer);
begin
  DoStatus(IntToStr(v));
end;

procedure DoStatus(const v: Single);
begin
  DoStatus(FloatToStr(v));
end;

procedure DoStatus(const v: Double);
begin
  DoStatus(FloatToStr(v));
end;

procedure DoStatusPtr(const v: Pointer);
begin
  try
      DoStatus(Format('0x%p', [v]));
  except
    // if formatting fails, ignore
  end;
end;

{
  * Formatted output using SysUtils.Format.
  * If formatting fails, an error message is emitted instead.
}
procedure DoStatus(const v: SystemString; const Args: array of const);
begin
  try
      DoStatus(Format(v, Args));
  except
      DoStatus('format text error %s', [v]);
  end;
end;

{ -----------------------------------------------------------------------------
  Plain string overload (ID = 0).
}
procedure DoStatus(const v: SystemString);
begin
  DoStatus__(v, 0);
end;

procedure DoStatus(const v1, v2: SystemString);
begin
  DoStatus__(v1 + v2, 0);
end;

procedure DoStatus(const v1, v2, v3: SystemString);
begin
  DoStatus__(v1 + v2 + v3, 0);
end;

{ -----------------------------------------------------------------------------
  TPascalString, TUPascalString, TMD5, and buffer overloads.
}
procedure DoStatus(const v: TPascalString);
begin
  DoStatus__(v, 0);
end;

procedure DoStatus(const v1, v2: TPascalString);
begin
  DoStatus__(v1 + v2, 0);
end;

procedure DoStatus(const v1, v2, v3: TPascalString);
begin
  DoStatus__(v1 + v2 + v3, 0);
end;

procedure DoStatus(const v: TUPascalString);
begin
  DoStatus__(v, 0);
end;

procedure DoStatus(const v1, v2: TUPascalString);
begin
  DoStatus__(v1 + v2, 0);
end;

procedure DoStatus(const v1, v2, v3: TUPascalString);
begin
  DoStatus__(v1 + v2 + v3, 0);
end;

procedure DoStatus(const v: TMD5);
begin
  DoStatus(umlMD5ToString(v).Text);
end;

procedure DoStatus(const p: Pointer; const siz: Integer);
begin
  DoStatus(TCipher.BuffToString(p, siz));
end;

{ ******************************************************************************
  * Internal data structures for managing hooks and the message queue.         *
  ****************************************************************************** }

{
  * TEvent_Struct__ – A record that holds one registered hook.
  * Only one of the three callback fields (M, C, P) will be non‑nil,
  * depending on the registration type.
}
type
  TEvent_Struct__ = record
    TokenObj: TCore_Object; // token used for removal
    OnStatusM: TDoStatus_M; // method hook
    OnStatusC: TDoStatus_C; // procedural hook
    OnStatusP: TDoStatus_P; // nested/reference hook
  end;

  PEvent_Struct__ = ^TEvent_Struct__;

  {
    * TText_Queue_Data – One queued status message.
  }
  TText_Queue_Data = record
    S: SystemString; // the message text
    Th: TCore_Thread; // thread that emitted the message
    TriggerTime: TTimeTick; // timestamp for lifetime tracking
    ID: Integer; // user‑defined identifier
  end;

  PText_Queue_Data = ^TText_Queue_Data;

  {
    * TNo_Ln_Text – Per‑thread buffer for DoStatusNoLn.
  }
  TNo_Ln_Text = record
    S: TPascalString; // accumulated text
    Th: TCore_Thread; // owning thread
    TriggerTime: TTimeTick; // last update time
  end;

  PNo_Ln_Text = ^TNo_Ln_Text;

  {
    * TEvent_Pool__ – A pool (extending TBigList) that stores hook records.
    * It overrides DoFree to dispose the PEvent_Struct__ correctly.
  }
  TEvent_Pool__ = class(TBigList<PEvent_Struct__>)
  public
    procedure DoFree(var Data: PEvent_Struct__); override;
  end;

  {
    * TText_Queue_Data_Pool__ – Pool for queued messages.
  }
  TText_Queue_Data_Pool__ = class(TBigList<PText_Queue_Data>)
  public
    procedure DoFree(var Data: PText_Queue_Data); override;
  end;

  {
    * TNo_Ln_Text_Pool__ – Pool for no‑line buffers.
  }
  TNo_Ln_Text_Pool__ = class(TBigList<PNo_Ln_Text>)
  public
    procedure DoFree(var Data: PNo_Ln_Text); override;
  end;

  { ******************************************************************************
    * Pool destructor implementations – free the dynamically allocated records.  *
    ****************************************************************************** }

  {
    * Frees a hook record.  The data is disposed and the pointer is set to nil.
  }
procedure TEvent_Pool__.DoFree(var Data: PEvent_Struct__);
begin
  dispose(Data);
  Data := nil;
end;

{
  * Frees a queued message record.  The string is cleared and the record disposed.
}
procedure TText_Queue_Data_Pool__.DoFree(var Data: PText_Queue_Data);
begin
  Data^.S := ''; // Free the string memory.
  dispose(Data);
  Data := nil;
end;

{
  * Frees a no‑line buffer record.  The string is cleared and the record disposed.
}
procedure TNo_Ln_Text_Pool__.DoFree(var Data: PNo_Ln_Text);
begin
  Data^.S := '';
  dispose(Data);
  Data := nil;
end;

{ ******************************************************************************
  * Global state variables – all are protected by Status_Critical__.           *
  ****************************************************************************** }
var
  Status_Active__: Boolean; // whether output is enabled
  Event_Pool__: TEvent_Pool__; // list of registered hooks
  Text_Queue_Data_Pool__: TText_Queue_Data_Pool__; // pending messages
  Status_Critical__: TCritical; // mutual exclusion for queues
  Check_Status_Critical__: TCritical;
  No_Ln_Text_Pool__: TNo_Ln_Text_Pool__; // per‑thread no‑line buffers

  {
    * GetOrCreateStatusNoLnData_ – Returns the no‑line buffer for a given thread.
    * If the buffer does not exist, it is created.  Old buffers (not updated
    * for more than one minute) are automatically recycled to prevent leaks.
    *
    * @param Th_   The thread whose buffer is requested.
    * @Return      Pointer to the buffer record.
  }
function GetOrCreateStatusNoLnData_(Th_: TCore_Thread): PNo_Ln_Text;
var
  R_: PNo_Ln_Text;
  Tick: TTimeTick;
begin
  R_ := nil;
  Tick := GetTimeTick();

  if No_Ln_Text_Pool__.Num > 0 then
    with No_Ln_Text_Pool__.Repeat_ do
      repeat
        if Queue^.Data^.Th = Th_ then
          begin
            R_ := Queue^.Data;
            R_^.TriggerTime := Tick; // Update timestamp to keep it alive.
          end
        else if Tick - Queue^.Data^.TriggerTime > C_Tick_Minute then
          begin
            No_Ln_Text_Pool__.Push_To_Recycle_Pool(Queue); // Remove expired buffers.
          end;
      until not Next;
  No_Ln_Text_Pool__.Free_Recycle_Pool; // Actually free the recycled items.

  if R_ = nil then
    begin
      new(R_); // Allocate new buffer.
      R_^.S := '';
      R_^.Th := Th_;
      R_^.TriggerTime := Tick;
      No_Ln_Text_Pool__.Add(R_);
    end;
  Result := R_;
end;

{
  * Overload for the current thread – calls GetOrCreateStatusNoLnData_(CurrentThread).
}
function GetOrCreateStatusNoLnData(): PNo_Ln_Text;
begin
  Result := GetOrCreateStatusNoLnData_(TCore_Thread.CurrentThread);
end;

{
  * DoStatusNoLn (TPascalString) – Appends text to the current thread’s
  * no‑line buffer.  When a line break (#13 or #10) is encountered, the
  * accumulated line is flushed as a normal status message.
  *
  * The text is scanned character by character.  Consecutive line breaks are
  * skipped after flushing to avoid empty lines.
}
procedure DoStatusNoLn(const v: TPascalString);
var
  L, i: Integer;
  StatusNoLnData: PNo_Ln_Text;
  pSS: PText_Queue_Data;
begin
  Status_Critical__.Acquire; // Lock to protect shared buffer pools.
  StatusNoLnData := GetOrCreateStatusNoLnData();
  try
    L := v.Len;
    i := 1;
    while i <= L do
      begin
        if CharIn(v[i], [#13, #10]) then // Line break detected.
          begin
            if StatusNoLnData^.S.Len > 0 then // Flush accumulated text.
              begin
                new(pSS);
                pSS^.S := StatusNoLnData^.S.Text;
                pSS^.Th := TCore_Thread.CurrentThread;
                pSS^.TriggerTime := GetTimeTick;
                pSS^.ID := 0;
                Text_Queue_Data_Pool__.Add(pSS); // Queue the complete line.
                StatusNoLnData^.S := '';
              end;
            repeat
                inc(i);
            until (i > L) or (not CharIn(v[i], [#13, #10])); // Skip all consecutive line breaks.
          end
        else
          begin
            StatusNoLnData^.S.Append(v[i]); // Append regular character.
            inc(i);
          end;
      end;
  finally
      Status_Critical__.Release;
  end;
end;

{
  * Formatted version of DoStatusNoLn.
}
procedure DoStatusNoLn(const v: SystemString; const Args: array of const);
begin
  try
      DoStatusNoLn(Format(v, Args));
  except
      DoStatusNoLn('format text error %s', [v]);
  end;
end;

{
  * Flush the no‑line buffer without waiting for a line break.
  * This forces any accumulated text to be emitted as a complete status line.
}
procedure DoStatusNoLn;
var
  StatusNoLnData: PNo_Ln_Text;
  S: SystemString;
begin
  Status_Critical__.Acquire;
  StatusNoLnData := GetOrCreateStatusNoLnData();
  S := StatusNoLnData^.S; // Copy current buffer.
  StatusNoLnData^.S := '';
  Status_Critical__.Release;
  if Length(S) > 0 then
      DoStatus(S); // Emit the accumulated text as a normal message.
end;

{
  * Do_Trigger_Event_Output_ – Internal routine that delivers a single
  * message to all registered hooks.  If the message contains line breaks,
  * it is split and each line is delivered separately (with the same ID).
  *
  * @param Text_   The message text (may contain #10).
  * @param ID      The identifier tag.
}
procedure Do_Trigger_Event_Output_(const Text_: U_String; const ID: Integer);
var
  tmp: U_String;
begin
  if Text_.Exists(#10) then
    begin
      tmp := Text_.DeleteChar(#13); // Remove carriage returns.
      Do_Trigger_Event_Output_(umlGetFirstStr___(tmp, #10), ID); // Emit first line.
      tmp := umlDeleteFirstStr___(tmp, #10);
      Do_Trigger_Event_Output_(tmp, ID); // Recursively emit the rest.
      exit;
    end;
  if (Status_Active__) and (Event_Pool__.Num > 0) then
    begin
      LastDoStatus := Text_; // Store the last delivered message.
      with Event_Pool__.Repeat_ do
        repeat
          try
            if Assigned(Queue^.Data^.OnStatusM) then
                Queue^.Data^.OnStatusM(Text_, ID);
            if Assigned(Queue^.Data^.OnStatusC) then
                Queue^.Data^.OnStatusC(Text_, ID);
            if Assigned(Queue^.Data^.OnStatusP) then
                Queue^.Data^.OnStatusP(Text_, ID);
          except
            // ignore exceptions from individual hooks
          end;
        until not Next;
    end;
end;

{
  * CheckDoStatus – Processes up to One_Step_Status_Limit messages from the
  * queue and dispatches them.  Called automatically from the main thread’s
  * synchronisation hook.
  *
  * If the queue is empty, nothing happens.  The limit prevents a single call
  * from taking too long.
}
procedure CheckDoStatus();
var
  i: Integer;
  p: TText_Queue_Data_Pool__.PQueueStruct;
begin
  if Status_Critical__ = nil then
      exit;

  Check_Status_Critical__.Acquire;
  try
    i := 0;
    while (Text_Queue_Data_Pool__.Num > 0) and (i < One_Step_Status_Limit) do
      begin
        Status_Critical__.Acquire;
        p := Text_Queue_Data_Pool__.First;
        Status_Critical__.Release;

        Do_Trigger_Event_Output_(p^.Data^.S, p^.Data^.ID);

        Status_Critical__.Acquire;
        Text_Queue_Data_Pool__.Next;
        Status_Critical__.Release;

        inc(i);
      end;
  finally
      Check_Status_Critical__.Release;
  end;
end;

{
  * DoStatus (no params) – just call CheckDoStatus to process the queue.
  * This is a convenience to flush pending messages.
}
procedure DoStatus();
begin
  CheckDoStatus();
end;

{ ------------------------------------------------------------------------------
  ToUTF8 – Safely convert a system string to UTF-8 encoding.

  In FPC, string may be ANSI or UTF-8 depending on codepage; we inspect its
  codepage. In Delphi (2009+), string is UnicodeString, so we encode directly.
}
function ToUTF8(const S: string): UTF8String;
begin
{$IFDEF FPC}
  if StringCodePage(S) = CP_UTF8 then
      Result := UTF8String(S) // Already UTF-8, just cast
  else
      Result := UTF8Encode(S); // Convert from ANSI to UTF-8
{$ELSE}
  Result := UTF8Encode(S); // Delphi: UnicodeString -> UTF-8
{$ENDIF}
end;

{ ------------------------------------------------------------------------------
  ConsoleWrite – Writes a string to standard output.

  If the output handle is a real console, it uses WriteConsoleW for proper
  Unicode rendering. If the handle is redirected (pipe/file), it uses WriteFile
  to write UTF‑8 bytes, so that the parent process can capture the output via
  a pipe.

  This fixes the problem that WriteConsoleW bypasses stdout redirection.
  ------------------------------------------------------------------------------ }
procedure ConsoleWrite(const S: string);
var
  UTF8Str: UTF8String;
{$IFDEF MSWINDOWS}
  WStr: UnicodeString;
  Written: DWORD;
  StdHandle: THandle;
  ConsoleMode: DWORD;
{$ENDIF}
begin
  if not IsConsole then
      exit;

  UTF8Str := ToUTF8(S);

{$IFDEF MSWINDOWS}
  StdHandle := GetStdHandle(STD_OUTPUT_HANDLE);
  if StdHandle = INVALID_HANDLE_VALUE then
      exit;

  // Check if the handle is a console (GetConsoleMode succeeds for console handles)
  if GetConsoleMode(StdHandle, ConsoleMode) then
    begin
      // Console: use WriteConsoleW for correct Unicode display
      WStr := UTF8Decode(UTF8Str);
      WriteConsoleW(StdHandle, PWideChar(WStr), Length(WStr), Written, nil);
    end
  else
    begin
      // Redirected (pipe/file): write raw UTF‑8 bytes
      WriteFile(StdHandle, Pointer(UTF8Str)^, Length(UTF8Str), Written, nil);
    end;
{$ELSE}
  Write(UTF8Str);
{$ENDIF}
end;

{ ------------------------------------------------------------------------------
  ConsoleWriteLn – Write a string to the console followed by a line break.
  ------------------------------------------------------------------------------ }
procedure ConsoleWriteLn(const S: string);
begin
  ConsoleWrite(S);
  ConsoleWrite(sLineBreak); // Write line break as UTF-8
end;

procedure Post_To_DoStatus_Queue(Th: TCore_Thread; Text_: SystemString; const ID: Integer);
var
  pSS: PText_Queue_Data;
begin
  new(pSS);
  if StatusThreadID then
      pSS^.S := '[' + IntToStr(Cardinal(Th.ThreadID)) + '] ' + umlReplace(Text_, #10, #10 + '[' + IntToStr(Cardinal(Th.ThreadID)) + '] ', False, False)
  else
      pSS^.S := Text_;
  pSS^.Th := Th;
  pSS^.TriggerTime := GetTimeTick();
  pSS^.ID := ID;
  Status_Critical__.Acquire;
  Text_Queue_Data_Pool__.Add(pSS);
  Status_Critical__.Release;
end;

{
  * InternalDoStatus – The default implementation of OnDoStatusHook.
  * It formats the message (optionally prepending thread ID), enqueues it,
  * and, if called from the main thread, immediately processes the queue.
  * It also writes to the console if ConsoleOutput is True.
  *
  * @param Text_   The raw message text.
  * @param ID      The identifier tag.
}
procedure InternalDoStatus(Text_: SystemString; const ID: Integer);
var
  Th: TCore_Thread;
begin
  if not Status_Active__ then
      exit;

  Th := TCore_Thread.CurrentThread;
  Post_To_DoStatus_Queue(Th, Text_, ID);

  if Th = Main_Thread then
      CheckDoStatus(); // If we are on the main thread, process immediately.

  if ConsoleOutput and IsConsole then
    begin
      Status_Critical__.Acquire;
      try
{$IFDEF FPC}
        ConsoleWriteLn(Text_); // fpc safe writeln
{$ELSE FPC}
        WriteLn(Text_);
{$ENDIF FPC}
      finally
          Status_Critical__.Release;
      end;
    end;
end;

{ ******************************************************************************
  * Public registration routines – they allocate a TEvent_Struct__ record,     *
  * fill the appropriate callback field, and add it to the hook pool.          *
  ****************************************************************************** }

procedure AddDoStatusHook(TokenObj: TCore_Object; OnNotify: TDoStatus_M);
begin
  AddDoStatusHookM(TokenObj, OnNotify);
end;

procedure AddDoStatusHookM(TokenObj: TCore_Object; OnNotify: TDoStatus_M);
var
  p: PEvent_Struct__;
begin
  new(p);
  p^.TokenObj := TokenObj;
  p^.OnStatusM := OnNotify;
  p^.OnStatusC := nil;
  p^.OnStatusP := nil;
  Event_Pool__.Add(p);
end;

procedure AddDoStatusHookC(TokenObj: TCore_Object; OnNotify: TDoStatus_C);
var
  p: PEvent_Struct__;
begin
  new(p);
  p^.TokenObj := TokenObj;
  p^.OnStatusM := nil;
  p^.OnStatusC := OnNotify;
  p^.OnStatusP := nil;
  Event_Pool__.Add(p);
end;

procedure AddDoStatusHookP(TokenObj: TCore_Object; OnNotify: TDoStatus_P);
var
  p: PEvent_Struct__;
begin
  new(p);
  p^.TokenObj := TokenObj;
  p^.OnStatusM := nil;
  p^.OnStatusC := nil;
  p^.OnStatusP := OnNotify;
  Event_Pool__.Add(p);
end;

{
  * Removal – scans the hook pool and marks for recycling any entry that
  * matches the given token.  The recycled items are freed later.
}
procedure DeleteDoStatusHook(TokenObj: TCore_Object);
begin
  RemoveDoStatusHook(TokenObj);
end;

procedure RemoveDoStatusHook(TokenObj: TCore_Object);
begin
  Event_Pool__.Free_Recycle_Pool;
  if Event_Pool__.Num > 0 then
    with Event_Pool__.Repeat_ do
      repeat
        if Queue^.Data^.TokenObj = TokenObj then
            Event_Pool__.Push_To_Recycle_Pool(Queue);
      until not Next;
  Event_Pool__.Free_Recycle_Pool;
end;

{ ******************************************************************************
  * Global enable/disable and query functions.                                 *
  ****************************************************************************** }

procedure DisableStatus;
begin
  Status_Active__ := False;
end;

procedure EnabledStatus;
begin
  Status_Active__ := True;
end;

function Is_EnabledStatus: Boolean;
begin
  Result := Status_Active__;
end;

function Is_DisableStatus: Boolean;
begin
  Result := not Status_Active__;
end;

{
  * Get_DoStatus_Queue_Num – Returns the number of pending messages.
}
function Get_DoStatus_Queue_Num: NativeInt;
begin
  Result := Text_Queue_Data_Pool__.Num;
end;

{
  * Wait_DoStatus_Queue – Blocks until the queue is empty.
}
procedure Wait_DoStatus_Queue;
begin
  while Get_DoStatus_Queue_Num > 0 do
      TCompute.Sleep(10);
end;

{ ******************************************************************************
  * Hooking into Z.Core’s synchronisation and exception reporting.             *
  * We override OnCheckThreadSynchronize to call CheckDoStatus, and            *
  * On_Raise_Info to log exceptions via DoStatus.                              *
  ****************************************************************************** }
var
  Hooked_OnCheckThreadSynchronize: TOn_Check_Thread_Synchronize;
  Hooked_OnRaiseInfo: TOn_Raise_Info;

  {
    * DoCheckThreadSynchronize – Replacement for Z.Core's synchronisation hook.
    * It processes pending status messages and then calls the original hook.
  }
procedure DoCheckThreadSynchronize;
begin
  CheckDoStatus(); // Process the queue.
  if Assigned(Hooked_OnCheckThreadSynchronize) then
      Hooked_OnCheckThreadSynchronize();
end;

{
  * RaiseInfo – Replacement for Z.Core's exception hook.
  * Logs the exception message via DoStatus.
}
procedure Do_RaiseInfo___(const n: string);
begin
  DoStatus('%s exception ' + n, [umlDT(umlNow).Text]);
end;

{ ******************************************************************************
  * Initialization – creates the global pools and sets default values.         *
  ****************************************************************************** }
procedure _DoInit;
begin
  Event_Pool__ := TEvent_Pool__.Create;
  Text_Queue_Data_Pool__ := TText_Queue_Data_Pool__.Create;
  Status_Critical__ := TCritical.Create('Status_Critical__');
  Check_Status_Critical__ := TCritical.Create('Check_Status_Critical__');
  No_Ln_Text_Pool__ := TNo_Ln_Text_Pool__.Create;

  Status_Active__ := True;
  LastDoStatus := '';
  ConsoleOutput := True;
  OnDoStatusHook := InternalDoStatus;
  StatusThreadID := True;
  One_Step_Status_Limit := 20;

  Hooked_OnCheckThreadSynchronize := Z.Core.OnCheckThreadSynchronize;
  Z.Core.OnCheckThreadSynchronize := DoCheckThreadSynchronize;

  Hooked_OnRaiseInfo := Z.Core.On_Raise_Info;
  Z.Core.On_Raise_Info := Do_RaiseInfo___;
end;

{ ******************************************************************************
  * Finalization – frees all global objects and restores the original hooks.   *
  ****************************************************************************** }
procedure _DoFree;
begin
  Event_Pool__.Free;
  Text_Queue_Data_Pool__.Free;
  No_Ln_Text_Pool__.Free;
  Status_Critical__.Free;
  Check_Status_Critical__.Free;
  Status_Active__ := True;
  Status_Critical__ := nil;
  Z.Core.OnCheckThreadSynchronize := Hooked_OnCheckThreadSynchronize;
  Z.Core.On_Raise_Info := Hooked_OnRaiseInfo;
end;

initialization

_DoInit;

finalization

_DoFree;

end.

{ ****************************************************************************** }
{ * support > 2G TMemoryStream64, writen by QQ 600585@qq.com                   * }
{ * https://github.com/PassByYou888/CoreCipher                                 * }
{ * https://github.com/PassByYou888/ZServer4D                                  * }
{ * https://github.com/PassByYou888/zExpression                                * }
{ * https://github.com/PassByYou888/zTranslate                                 * }
{ * https://github.com/PassByYou888/zSound                                     * }
{ * https://github.com/PassByYou888/zAnalysis                                  * }
{ * https://github.com/PassByYou888/zGameWare                                  * }
{ * https://github.com/PassByYou888/zRasterization                             * }
{ ****************************************************************************** }

unit MemoryStream64;

{$INCLUDE zDefine.inc}

{
  create by passbyyou
  first 2011-10

  last 2017-11-2 added x64 memory interface
  2017-12-29 added newCompressor
}

interface

uses
  SysUtils, ZLib,
{$IFDEF FPC}
  zstream,
{$ENDIF}
  CoreClasses, PascalStrings;

type
  TMemoryStream64 = class(TCoreClassStream)
  private
    FMemory: Pointer;
    FSize: nativeUInt;
    FPosition: nativeUInt;
    FCapacity: nativeUInt;
    FProtectedMode: Boolean;
  protected
    procedure SetPointer(buffPtr: Pointer; const BuffSize: nativeUInt);
    procedure SetCapacity(NewCapacity: nativeUInt);
    function Realloc(var NewCapacity: nativeUInt): Pointer; virtual;
    property Capacity: nativeUInt read FCapacity write SetCapacity;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Clear;

    procedure SetPointerWithProtectedMode(buffPtr: Pointer; const BuffSize: nativeUInt); {$IFDEF INLINE_ASM} inline; {$ENDIF}
    function PositionAsPtr(const APosition: Int64): Pointer; overload; {$IFDEF INLINE_ASM} inline; {$ENDIF}
    function PositionAsPtr: Pointer; overload; {$IFDEF INLINE_ASM} inline; {$ENDIF}
    //
    procedure LoadFromStream(stream: TCoreClassStream); virtual;
    procedure LoadFromFile(const fileName: SystemString);
    procedure SaveToStream(stream: TCoreClassStream); virtual;
    procedure SaveToFile(const fileName: SystemString);

    procedure SetSize(const NewSize: Int64); overload; override;
    procedure SetSize(NewSize: longint); overload; override;

    function Write64(const buffer; Count: Int64): Int64; virtual;
    function WritePtr(const p: Pointer; Count: Int64): Int64; {$IFDEF INLINE_ASM} inline; {$ENDIF}
    function write(const buffer; Count: longint): longint; overload; override;
{$IFNDEF FPC} function write(const buffer: TBytes; Offset, Count: longint): longint; overload; override; {$ENDIF}
    //
    function Read64(var buffer; Count: Int64): Int64; virtual;
    function ReadPtr(const p: Pointer; Count: Int64): Int64; {$IFDEF INLINE_ASM} inline; {$ENDIF}
    function read(var buffer; Count: longint): longint; overload; override;
{$IFNDEF FPC} function read(buffer: TBytes; Offset, Count: longint): longint; overload; override; {$ENDIF}
    //
    function Seek(const Offset: Int64; origin: TSeekOrigin): Int64; override;
    property Memory: Pointer read FMemory;

    function CopyFrom(const Source: TCoreClassStream; CCount: Int64): Int64; virtual;
  end;

  IMemoryStream64WriteTrigger = interface
    procedure TriggerWrite64(Count: Int64);
  end;

  TMemoryStream64OfWriteTrigger = class(TMemoryStream64)
  private
  public
    Trigger: IMemoryStream64WriteTrigger;
    constructor Create(ATrigger: IMemoryStream64WriteTrigger);
    function Write64(const buffer; Count: Int64): Int64; override;
  end;

  IMemoryStream64ReadTrigger = interface
    procedure TriggerRead64(Count: Int64);
  end;

  TMemoryStream64OfReadTrigger = class(TMemoryStream64)
  private
  public
    Trigger: IMemoryStream64ReadTrigger;
    constructor Create(ATrigger: IMemoryStream64ReadTrigger);
    function Read64(var buffer; Count: Int64): Int64; override;
  end;

  IMemoryStream64ReadWriteTrigger = interface
    procedure TriggerWrite64(Count: Int64);
    procedure TriggerRead64(Count: Int64);
  end;

  TMemoryStream64OfReadWriteTrigger = class(TMemoryStream64)
  private
  public
    Trigger: IMemoryStream64ReadWriteTrigger;
    constructor Create(ATrigger: IMemoryStream64ReadWriteTrigger);
    function Read64(var buffer; Count: Int64): Int64; override;
    function Write64(const buffer; Count: Int64): Int64; override;
  end;

{$IFDEF FPC}

  TDecompressionStream = class(zstream.TDecompressionStream)
  public
  end;

  { TCompressionStream }

  TCompressionStream = class(zstream.TCompressionStream)
  public
    constructor Create(stream: TCoreClassStream); overload;
    constructor Create(level: Tcompressionlevel; stream: TCoreClassStream); overload;
  end;
{$ELSE}

  TDecompressionStream = ZLib.TZDecompressionStream;
  TCompressionStream   = ZLib.TZCompressionStream;
{$ENDIF}
  //
  // zlib
function MaxCompressStream(sour: TCoreClassStream; ComTo: TCoreClassStream): Boolean; {$IFDEF INLINE_ASM} inline; {$ENDIF}
function FastCompressStream(sour: TCoreClassStream; ComTo: TCoreClassStream): Boolean; {$IFDEF INLINE_ASM} inline; {$ENDIF}
function CompressStream(sour: TCoreClassStream; ComTo: TCoreClassStream): Boolean; {$IFDEF INLINE_ASM} inline; {$ENDIF}

function DecompressStream(DataPtr: Pointer; siz: nativeInt; DeTo: TCoreClassStream): Boolean; overload; {$IFDEF INLINE_ASM} inline; {$ENDIF}
function DecompressStream(sour: TCoreClassStream; DeTo: TCoreClassStream): Boolean; overload; {$IFDEF INLINE_ASM} inline; {$ENDIF}
function DecompressStreamToPtr(sour: TCoreClassStream; var DeTo: Pointer): Boolean; {$IFDEF INLINE_ASM} inline; {$ENDIF}


implementation

uses UnicodeMixedLib;

procedure TMemoryStream64.SetPointer(buffPtr: Pointer; const BuffSize: nativeUInt);
begin
  FMemory := buffPtr;
  FSize := BuffSize;
end;

procedure TMemoryStream64.SetCapacity(NewCapacity: nativeUInt);
begin
  if FProtectedMode then
      Exit;
  SetPointer(Realloc(NewCapacity), FSize);
  FCapacity := NewCapacity;
end;

function TMemoryStream64.Realloc(var NewCapacity: nativeUInt): Pointer;
begin
  if FProtectedMode then
      Exit(nil);

  if (NewCapacity > 0) and (NewCapacity <> FSize) then
      NewCapacity := umlDeltaNumber(NewCapacity, 256);
  Result := Memory;
  if NewCapacity <> FCapacity then
    begin
      if NewCapacity = 0 then
        begin
          System.FreeMemory(Memory);
          Result := nil;
        end
      else
        begin
          if Capacity = 0 then
              Result := System.GetMemory(NewCapacity)
          else
              Result := System.ReallocMemory(Result, NewCapacity);
          if Result = nil then
              RaiseInfo('Out of memory while expanding memory stream');
        end;
    end;
end;

constructor TMemoryStream64.Create;
begin
  inherited Create;
  FMemory := nil;
  FSize := 0;
  FPosition := 0;
  FCapacity := 0;
  FProtectedMode := False;
end;

destructor TMemoryStream64.Destroy;
begin
  Clear;
  inherited Destroy;
end;

procedure TMemoryStream64.Clear;
begin
  if FProtectedMode then
      Exit;
  SetCapacity(0);
  FSize := 0;
  FPosition := 0;
end;

procedure TMemoryStream64.SetPointerWithProtectedMode(buffPtr: Pointer; const BuffSize: nativeUInt);
begin
  Clear;
  FMemory := buffPtr;
  FSize := BuffSize;
  FPosition := 0;
  FProtectedMode := True;
end;

function TMemoryStream64.PositionAsPtr(const APosition: Int64): Pointer;
begin
  Result := Pointer(nativeUInt(FMemory) + APosition);
end;

function TMemoryStream64.PositionAsPtr: Pointer;
begin
  Result := Pointer(nativeUInt(FMemory) + FPosition);
end;

procedure TMemoryStream64.LoadFromStream(stream: TCoreClassStream);
const
  ChunkSize = 64 * 1024 * 1024;
var
  p: Pointer;
  J: nativeInt;
  Num: nativeInt;
  Rest: nativeInt;
begin
  if FProtectedMode then
      Exit;

  stream.Position := 0;
  SetSize(stream.Size);
  if stream.Size > 0 then
    begin
      p := FMemory;
      if stream.Size > ChunkSize then
        begin
          { Calculate number of full chunks that will fit into the buffer }
          Num := stream.Size div ChunkSize;
          { Calculate remaining bytes }
          Rest := stream.Size mod ChunkSize;

          { Process full chunks }
          for J := 0 to Num - 1 do
            begin
              stream.ReadBuffer(p^, ChunkSize);
              p := Pointer(nativeUInt(p) + ChunkSize);
            end;

          { Process remaining bytes }
          if Rest > 0 then
            begin
              stream.ReadBuffer(p^, Rest);
              p := Pointer(nativeUInt(p) + Rest);
            end;
        end
      else
          stream.ReadBuffer(p^, stream.Size);
    end;
end;

procedure TMemoryStream64.LoadFromFile(const fileName: SystemString);
var
  stream: TCoreClassStream;
begin
  stream := TCoreClassFileStream.Create(fileName, fmOpenRead or fmShareDenyWrite);
  try
      LoadFromStream(stream);
  finally
      DisposeObject(stream);
  end;
end;

procedure TMemoryStream64.SaveToStream(stream: TCoreClassStream);
const
  ChunkSize = 64 * 1024 * 1024;
var
  p: Pointer;
  J: nativeInt;
  Num: nativeInt;
  Rest: nativeInt;
begin
  if Size > 0 then
    begin
      p := FMemory;
      if Size > ChunkSize then
        begin
          { Calculate number of full chunks that will fit into the buffer }
          Num := Size div ChunkSize;
          { Calculate remaining bytes }
          Rest := Size mod ChunkSize;

          { Process full chunks }
          for J := 0 to Num - 1 do
            begin
              stream.WriteBuffer(p^, ChunkSize);
              p := Pointer(nativeUInt(p) + ChunkSize);
            end;

          { Process remaining bytes }
          if Rest > 0 then
            begin
              stream.WriteBuffer(p^, Rest);
              p := Pointer(nativeUInt(p) + Rest);
            end;
        end
      else
          stream.WriteBuffer(p^, Size);
    end;
end;

procedure TMemoryStream64.SaveToFile(const fileName: SystemString);
var
  stream: TCoreClassStream;
begin
  stream := TCoreClassFileStream.Create(fileName, fmCreate);
  try
      SaveToStream(stream);
  finally
      DisposeObject(stream);
  end;
end;

procedure TMemoryStream64.SetSize(const NewSize: Int64);
var
  OldPosition: Int64;
begin
  if FProtectedMode then
      Exit;

  OldPosition := FPosition;
  SetCapacity(NewSize);
  FSize := NewSize;
  if OldPosition > NewSize then
      Seek(0, TSeekOrigin.soEnd);
end;

procedure TMemoryStream64.SetSize(NewSize: longint);
begin
  SetSize(Int64(NewSize));
end;

function TMemoryStream64.Write64(const buffer; Count: Int64): Int64;
var
  p: Int64;
begin
  if FProtectedMode then
    begin
      Result := 0;
      Exit;
    end;

  if (Count > 0) then
    begin
      p := FPosition;
      p := p + Count;
      if p > 0 then
        begin
          if p > FSize then
            begin
              if p > FCapacity then
                  SetCapacity(p);
              FSize := p;
            end;
          System.Move(buffer, PByte(nativeUInt(FMemory) + FPosition)^, Count);
          FPosition := p;
          Result := Count;
          Exit;
        end;
    end;
  Result := 0;
end;

function TMemoryStream64.WritePtr(const p: Pointer; Count: Int64): Int64;
begin
  Result := Write64(p^, Count);
end;

function TMemoryStream64.write(const buffer; Count: longint): longint;
begin
  Result := Write64(buffer, Count);
end;

{$IFNDEF FPC}


function TMemoryStream64.write(const buffer: TBytes; Offset, Count: longint): longint;
var
  p: Int64;
begin
  if Count > 0 then
    begin
      p := FPosition;
      p := p + Count;
      if p > 0 then
        begin
          if p > FSize then
            begin
              if p > FCapacity then
                  SetCapacity(p);
              FSize := p;
            end;
          System.Move(buffer[Offset], PByte(nativeUInt(FMemory) + FPosition)^, Count);
          FPosition := p;
          Result := Count;
          Exit;
        end;
    end;
  Result := 0;
end;
{$ENDIF}


function TMemoryStream64.Read64(var buffer; Count: Int64): Int64;
begin
  if Count > 0 then
    begin
      Result := FSize;
      Result := Result - FPosition;
      if Result > 0 then
        begin
          if Result > Count then
              Result := Count;
          System.Move(PByte(nativeUInt(FMemory) + FPosition)^, buffer, Result);
          Inc(FPosition, Result);
          Exit;
        end;
    end;
  Result := 0;
end;

function TMemoryStream64.ReadPtr(const p: Pointer; Count: Int64): Int64;
begin
  Result := Read64(p^, Count);
end;

function TMemoryStream64.read(var buffer; Count: longint): longint;
begin
  Result := Read64(buffer, Count);
end;

{$IFNDEF FPC}


function TMemoryStream64.read(buffer: TBytes; Offset, Count: longint): longint;
var
  p: Int64;
begin
  if Count > 0 then
    begin
      p := FSize;
      p := p - FPosition;
      if p > 0 then
        begin
          if p > Count then
              p := Count;

          System.Move(PByte(nativeUInt(FMemory) + FPosition)^, buffer[Offset], p);
          Inc(FPosition, p);
          Result := p;
          Exit;
        end;
    end;
  Result := 0;
end;
{$ENDIF}


function TMemoryStream64.Seek(const Offset: Int64; origin: TSeekOrigin): Int64;
begin
  case origin of
    TSeekOrigin.soBeginning: FPosition := Offset;
    TSeekOrigin.soCurrent: Inc(FPosition, Offset);
    TSeekOrigin.soEnd: FPosition := FSize + Offset;
  end;
  Result := FPosition;
end;

function TMemoryStream64.CopyFrom(const Source: TCoreClassStream; CCount: Int64): Int64;
const
  MaxBufSize = $F000;
var
  BufSize, n: Int64;
  buffer: TBytes;
begin
  if FProtectedMode then
      RaiseInfo('protected mode');

  if Source is TMemoryStream64 then
    begin
      WritePtr(TMemoryStream64(Source).PositionAsPtr, CCount);
      TMemoryStream64(Source).Position := TMemoryStream64(Source).FPosition + CCount;
      Result := CCount;
      Exit;
    end;

  if CCount <= 0 then
    begin
      Source.Position := 0;
      CCount := Source.Size;
    end;

  Result := CCount;
  if CCount > MaxBufSize then
      BufSize := MaxBufSize
  else
      BufSize := CCount;
  SetLength(buffer, BufSize);
  try
    while CCount <> 0 do
      begin
        if CCount > BufSize then
            n := BufSize
        else
            n := CCount;
        Source.read((@buffer[0])^, n);
        WritePtr((@buffer[0]), n);
        Dec(CCount, n);
      end;
  finally
      SetLength(buffer, 0);
  end;
end;

constructor TMemoryStream64OfWriteTrigger.Create(ATrigger: IMemoryStream64WriteTrigger);
begin
  inherited Create;
  Trigger := ATrigger;
end;

function TMemoryStream64OfWriteTrigger.Write64(const buffer; Count: Int64): Int64;
begin
  Result := inherited Write64(buffer, Count);
  if Assigned(Trigger) then
      Trigger.TriggerWrite64(Count);
end;

constructor TMemoryStream64OfReadTrigger.Create(ATrigger: IMemoryStream64ReadTrigger);
begin
  inherited Create;
  Trigger := ATrigger;
end;

function TMemoryStream64OfReadTrigger.Read64(var buffer; Count: Int64): Int64;
begin
  Result := inherited Read64(buffer, Count);
  if Assigned(Trigger) then
      Trigger.TriggerRead64(Count);
end;

constructor TMemoryStream64OfReadWriteTrigger.Create(ATrigger: IMemoryStream64ReadWriteTrigger);
begin
  inherited Create;
  Trigger := ATrigger;
end;

function TMemoryStream64OfReadWriteTrigger.Read64(var buffer; Count: Int64): Int64;
begin
  Result := inherited Read64(buffer, Count);
  if Assigned(Trigger) then
      Trigger.TriggerRead64(Count);
end;

function TMemoryStream64OfReadWriteTrigger.Write64(const buffer; Count: Int64): Int64;
begin
  Result := inherited Write64(buffer, Count);
  if Assigned(Trigger) then
      Trigger.TriggerWrite64(Count);
end;

{$IFDEF FPC}


constructor TCompressionStream.Create(stream: TCoreClassStream);
begin
  inherited Create(clFastest, stream);
end;

constructor TCompressionStream.Create(level: Tcompressionlevel; stream: TCoreClassStream);
begin
  inherited Create(level, stream);
end;
{$ENDIF}


function MaxCompressStream(sour: TCoreClassStream; ComTo: TCoreClassStream): Boolean;
var
  cp: TCompressionStream;
  sizevalue: Int64;
begin
  Result := False;
  try
    sizevalue := sour.Size;
    ComTo.WriteBuffer(sizevalue, 8);
    if sour.Size > 0 then
      begin
        sour.Position := 0;
        cp := TCompressionStream.Create(clMax, ComTo);
        Result := cp.CopyFrom(sour, sizevalue) = sizevalue;
        DisposeObject(cp);
      end;
  except
  end;
end;

function FastCompressStream(sour: TCoreClassStream; ComTo: TCoreClassStream): Boolean;
var
  cp: TCompressionStream;
  sizevalue: Int64;
begin
  Result := False;
  try
    sizevalue := sour.Size;
    ComTo.WriteBuffer(sizevalue, 8);
    if sour.Size > 0 then
      begin
        sour.Position := 0;
        cp := TCompressionStream.Create(clFastest, ComTo);
        Result := cp.CopyFrom(sour, sizevalue) = sizevalue;
        DisposeObject(cp);
      end;
  except
  end;
end;

function CompressStream(sour: TCoreClassStream; ComTo: TCoreClassStream): Boolean;
var
  cp: TCompressionStream;
  sizevalue: Int64;
begin
  Result := False;
  try
    sizevalue := sour.Size;
    ComTo.WriteBuffer(sizevalue, 8);
    if sour.Size > 0 then
      begin
        sour.Position := 0;
        cp := TCompressionStream.Create(clDefault, ComTo);
        Result := cp.CopyFrom(sour, sizevalue) = sizevalue;
        DisposeObject(cp);
      end;
  except
  end;
end;

function DecompressStream(DataPtr: Pointer; siz: nativeInt; DeTo: TCoreClassStream): Boolean;
var
  m64: TMemoryStream64;
begin
  m64 := TMemoryStream64.Create;
  m64.SetPointer(DataPtr, siz);
  Result := DecompressStream(m64, DeTo);
  DisposeObject(m64);
end;

function DecompressStream(sour: TCoreClassStream; DeTo: TCoreClassStream): Boolean;
var
  DC: TDecompressionStream;
  DeSize: Int64;
begin
  Result := False;
  sour.ReadBuffer(DeSize, 8);
  if DeSize > 0 then
    begin
      try
        DC := TDecompressionStream.Create(sour);
        Result := DeTo.CopyFrom(DC, DeSize) = DeSize;
        DisposeObject(DC);
      except
      end;
    end;
end;

function DecompressStreamToPtr(sour: TCoreClassStream; var DeTo: Pointer): Boolean;
var
  DC: TDecompressionStream;
  DeSize: Int64;
begin
  Result := False;
  try
    sour.ReadBuffer(DeSize, 8);
    if DeSize > 0 then
      begin
        DC := TDecompressionStream.Create(sour);
        DeTo := System.GetMemory(DeSize);
        Result := DC.read(DeTo^, DeSize) = DeSize;
        DisposeObject(DC);
      end;
  except
  end;
end;

initialization

finalization

end. 
 

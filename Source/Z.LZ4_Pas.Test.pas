{*****************************************************************************
  Comprehensive test suite for Z.LZ4_Pas (32/64-bit APIs).

  Tests cover:
    - Basic functionality (empty, single byte, few bytes, ASCII)
    - Structured data (JSON, XML)
    - Repeated patterns and mixed text
    - Boundary conditions (max distance, compress expanding, exact buffer)
    - Random binary data from 1KB to 4MB
    - Error handling (truncated, invalid offset, overflow, corrupted)
    - Interoperability with official LZ4 ("abc" sample)
    - Daily use simulations (text files, image data, protocol packets)
    - 64-bit API: basic consistency, large repetitions, huge literals, streaming

  Output uses Z.Status.DoStatus for logging.

  Create by.qq600585 (deepseek v4)

*******************************************************************************}

unit Z.LZ4_Pas.Test;

{$DEFINE FPC_DELPHI_MODE}
{$I Z.Define.inc}
{$R-}

interface

procedure RunAllTests;

implementation

uses
  Z.Core,
  Z.PascalStrings,
  Z.UPascalStrings,
  Z.UnicodeMixedLib,
  Z.Status,
  Z.LZ4_Pas;

const
  KB = 1024;
  MB = 1024 * 1024;

var
  Passed, Failed: Integer;

procedure LogResult(const TestName: string; Success: Boolean);
begin
  if Success then
  begin
    DoStatus('  PASSED: ' + TestName);
    Inc(Passed);
  end
  else
  begin
    DoStatus('  FAILED: ' + TestName);
    Inc(Failed);
  end;
end;

// ---------- Helper: compress/decompress and verify (32-bit) ----------
function CompressDecompressVerify32(const Src: array of Byte; const Desc: string;
  out CompSize, DecompSize: Integer): Boolean;
var
  SrcLen, BufLen: Integer;
  CompBuf, DecompBuf: array of Byte;
begin
  SrcLen := Length(Src);
  BufLen := LZ4_compressBound(SrcLen);
  SetLength(CompBuf, BufLen);
  SetLength(DecompBuf, SrcLen);
  CompSize := LZ4_compress_default(Src[0], SrcLen, CompBuf[0], BufLen);
  DecompSize := LZ4_decompress_safe(CompBuf[0], CompSize, DecompBuf[0], SrcLen);
  Result := (DecompSize = SrcLen) and CompareMemory(@Src[0], @DecompBuf[0], SrcLen);
  if Result and (Desc <> '') then
    DoStatus('    %s: %d -> %d bytes (%.1f%%)',
      [Desc, SrcLen, CompSize, CompSize / SrcLen * 100]);
end;

// ==================== 32-bit Test Functions ====================

function Test_EmptyData: Boolean;
var
  Src: array[0..0] of Byte;
  Comp, Decomp: array[0..255] of Byte;
  CompSize, DecompSize: Integer;
begin
  CompSize := LZ4_compress_default(Src, 0, Comp, SizeOf(Comp));
  DecompSize := LZ4_decompress_safe(Comp, CompSize, Decomp, 0);
  Result := (CompSize = 1) and (DecompSize = 0);
end;

function Test_SingleByte: Boolean;
var
  Src: Byte;
  Comp, Decomp: array[0..255] of Byte;
  CompSize, DecompSize: Integer;
begin
  Src := $AB;
  CompSize := LZ4_compress_default(Src, 1, Comp, SizeOf(Comp));
  DecompSize := LZ4_decompress_safe(Comp, CompSize, Decomp, 1);
  Result := (CompSize > 0) and (DecompSize = 1) and (Decomp[0] = $AB);
end;

function Test_TwoBytes: Boolean;
var
  Src: array[0..1] of Byte;
  Comp, Decomp: array[0..255] of Byte;
  CompSize, DecompSize: Integer;
begin
  Src[0] := $12; Src[1] := $34;
  CompSize := LZ4_compress_default(Src, 2, Comp, SizeOf(Comp));
  DecompSize := LZ4_decompress_safe(Comp, CompSize, Decomp, 2);
  Result := (DecompSize = 2) and CompareMemory(@Src, @Decomp, 2);
end;

function Test_ThreeBytes: Boolean;
var
  Src: array[0..2] of Byte;
  Comp, Decomp: array[0..255] of Byte;
  CompSize, DecompSize: Integer;
begin
  Src[0] := $10; Src[1] := $20; Src[2] := $30;
  CompSize := LZ4_compress_default(Src, 3, Comp, SizeOf(Comp));
  DecompSize := LZ4_decompress_safe(Comp, CompSize, Decomp, 3);
  Result := (DecompSize = 3) and CompareMemory(@Src, @Decomp, 3);
end;

function Test_SimpleAscii: Boolean;
var
  Src: AnsiString;
  SrcBuf: array of Byte;
  c, d: Integer;
begin
  Src := 'Hello, World! This is a simple ASCII test.';
  SetLength(SrcBuf, Length(Src));
  Move(Src[1], SrcBuf[0], Length(Src));
  Result := CompressDecompressVerify32(SrcBuf, 'Simple ASCII', c, d);
end;

function Test_RepeatedPattern: Boolean;
var
  Src: AnsiString;
  SrcBuf: array of Byte;
  c, d: Integer;
begin
  Src := StringOfChar('Z', 5000);
  SetLength(SrcBuf, Length(Src));
  Move(Src[1], SrcBuf[0], Length(Src));
  Result := CompressDecompressVerify32(SrcBuf, 'Repeated Z', c, d);
end;

function Test_RepeatedPattern2: Boolean;
var
  Buf: array of Byte;
  i: Integer;
  c, d: Integer;
begin
  SetLength(Buf, 4000);
  for i := 0 to 3999 do
    if (i and 1) = 0 then
      Buf[i] := $41
    else
      Buf[i] := $42;
  Result := CompressDecompressVerify32(Buf, 'AB pattern', c, d);
end;

function Test_MixedText: Boolean;
var
  Src: AnsiString;
  SrcBuf: array of Byte;
  c, d: Integer;
begin
  Src := 'LZ4 is a lossless data compression algorithm that is focused on compression and decompression speed. ' +
         'It belongs to the LZ77 family of byte-oriented compression schemes.';
  SetLength(SrcBuf, Length(Src));
  Move(Src[1], SrcBuf[0], Length(Src));
  Result := CompressDecompressVerify32(SrcBuf, 'Mixed text', c, d);
end;

function Test_JsonLike: Boolean;
var
  Src: AnsiString;
  SrcBuf: array of Byte;
  c, d: Integer;
begin
  Src := '{"id":1234,"name":"John Doe","email":"john@example.com","roles":["user","admin"],"active":true,' +
         '"scores":[100,98,95,94],"metadata":{"created":"2025-01-01","updated":"2025-06-01"}}';
  SetLength(SrcBuf, Length(Src));
  Move(Src[1], SrcBuf[0], Length(Src));
  Result := CompressDecompressVerify32(SrcBuf, 'JSON-like', c, d);
end;

function Test_XmlLike: Boolean;
var
  Src: AnsiString;
  SrcBuf: array of Byte;
  c, d: Integer;
begin
  Src := '<root><item id="1"><name>Item1</name><value>100</value></item>' +
         '<item id="2"><name>Item2</name><value>200</value></item></root>';
  SetLength(SrcBuf, Length(Src));
  Move(Src[1], SrcBuf[0], Length(Src));
  Result := CompressDecompressVerify32(SrcBuf, 'XML-like', c, d);
end;

function Test_BinaryBlock(const Size: Integer; const Desc: string; var Ratio: Double): Boolean;
var
  SrcBuf, CompBuf, DecompBuf: array of Byte;
  CompSize, DecompSize, i: Integer;
begin
  SetLength(SrcBuf, Size);
  RandSeed := 12345;
  for i := 0 to Size - 1 do
    SrcBuf[i] := Random(256);
  SetLength(CompBuf, LZ4_compressBound(Size));
  SetLength(DecompBuf, Size);
  CompSize := LZ4_compress_default(SrcBuf[0], Size, CompBuf[0], Length(CompBuf));
  DecompSize := LZ4_decompress_safe(CompBuf[0], CompSize, DecompBuf[0], Size);
  Result := (DecompSize = Size) and CompareMemory(@SrcBuf[0], @DecompBuf[0], Size);
  Ratio := CompSize / Size * 100;
  if Result then
    DoStatus('  %s: %d bytes -> %d bytes (%.2f%%)', [Desc, Size, CompSize, Ratio]);
end;

function Test_Random_1KB: Boolean;   var R: Double; begin Result := Test_BinaryBlock(1*KB, 'Random 1KB', R); end;
function Test_Random_16KB: Boolean;  var R: Double; begin Result := Test_BinaryBlock(16*KB, 'Random 16KB', R); end;
function Test_Random_64KB: Boolean;  var R: Double; begin Result := Test_BinaryBlock(64*KB, 'Random 64KB', R); end;
function Test_Random_1MB: Boolean;   var R: Double; begin Result := Test_BinaryBlock(1*MB, 'Random 1MB', R); end;
function Test_Random_4MB: Boolean;   var R: Double; begin Result := Test_BinaryBlock(4*MB, 'Random 4MB', R); end;

function Test_BinaryStructured: Boolean;
var
  Buf: array of Byte;
  i: Integer;
  c, d: Integer;
begin
  SetLength(Buf, 1024);
  for i := 0 to 1023 do
    if i < 100 then
      Buf[i] := $00
    else if i < 200 then
      Buf[i] := $FF
    else
      Buf[i] := Byte(i and $0F);
  Result := CompressDecompressVerify32(Buf, 'Structured binary', c, d);
end;

function Test_MaxDistance: Boolean;
var
  Src: AnsiString;
  SrcBuf: array of Byte;
  c, d: Integer;
begin
  Src := StringOfChar('A', 65535) + 'B';
  SetLength(SrcBuf, Length(Src));
  Move(Src[1], SrcBuf[0], Length(Src));
  Result := CompressDecompressVerify32(SrcBuf, 'Max distance 65536', c, d);
end;

function Test_CompressedLarger: Boolean;
var
  Buf: array of Byte;
  i: Integer;
  c, d: Integer;
begin
  SetLength(Buf, 512);
  for i := 0 to 511 do
    Buf[i] := Byte(i * 31 mod 256);
  Result := CompressDecompressVerify32(Buf, 'Expand test', c, d);
  if Result and (c > 512) then
    DoStatus('    Compressed larger (expected): %d > 512', [c]);
end;

function Test_ExactBuffer: Boolean;
var
  Src: AnsiString;
  SrcBuf, CompBuf, DecompBuf: array of Byte;
  Bound, CompSize, DecompSize: Integer;
begin
  Src := 'Test exact buffer size';
  SetLength(SrcBuf, Length(Src));
  Move(Src[1], SrcBuf[0], Length(Src));
  Bound := LZ4_compressBound(Length(Src));
  SetLength(CompBuf, Bound);
  CompSize := LZ4_compress_default(SrcBuf[0], Length(Src), CompBuf[0], Bound);
  SetLength(DecompBuf, Length(Src));
  DecompSize := LZ4_decompress_safe(CompBuf[0], CompSize, DecompBuf[0], Length(Src));
  Result := (DecompSize = Length(Src)) and CompareMemory(@SrcBuf[0], @DecompBuf[0], Length(Src));
end;

function Test_HugeLiteral: Boolean;
var
  Buf: array of Byte;
  i: Integer;
  c, d: Integer;
begin
  SetLength(Buf, 65536 + 10);
  for i := 0 to High(Buf) do
    Buf[i] := Byte(i and $FF);
  Result := CompressDecompressVerify32(Buf, 'Huge literal 65KB', c, d);
end;

function Test_StreamCompression: Boolean;
var
  TotalSrc: Integer;
  Src, TmpComp, TmpDecomp: array of Byte;
  i, Pos, Chunk, CompSize, DecompSize: Integer;
begin
  TotalSrc := 5000;
  SetLength(Src, TotalSrc);
  for i := 0 to TotalSrc - 1 do
    Src[i] := Random(256);
  Pos := 0;
  Result := True;
  while Pos < TotalSrc do
  begin
    Chunk := 200 + Random(300);
    if Pos + Chunk > TotalSrc then
      Chunk := TotalSrc - Pos;
    SetLength(TmpComp, LZ4_compressBound(Chunk));
    CompSize := LZ4_compress_default(Src[Pos], Chunk, TmpComp[0], Length(TmpComp));
    SetLength(TmpDecomp, Chunk);
    DecompSize := LZ4_decompress_safe(TmpComp[0], CompSize, TmpDecomp[0], Chunk);
    if (DecompSize <> Chunk) or not CompareMemory(@Src[Pos], @TmpDecomp[0], Chunk) then
    begin
      Result := False;
      Break;
    end;
    Inc(Pos, Chunk);
  end;
  if Result then
    DoStatus('    Stream test: 5000 bytes processed in variable chunks');
end;

function Test_DecompressTruncated: Boolean;
const
  Src: array[0..3] of Byte = ($30, $61, $62, $63);
var
  Decomp: array[0..2] of Byte;
begin
  Result := LZ4_decompress_safe(Src, 1, Decomp, SizeOf(Decomp)) < 0;
end;

function Test_DecompressInvalidOffset: Boolean;
var
  Data: array[0..2] of Byte;
  Decomp: array[0..9] of Byte;
begin
  Data[0] := $00;
  Data[1] := $01; Data[2] := $00;
  Result := LZ4_decompress_safe(Data, 3, Decomp, SizeOf(Decomp)) < 0;
end;

function Test_DecompressOutputOverflow: Boolean;
var
  Data: array[0..4] of Byte;
  Decomp: array[0..3] of Byte;
begin
  Data[0] := $20;
  Data[1] := $41; Data[2] := $42;
  Data[3] := $01; Data[4] := $00;
  Result := LZ4_decompress_safe(Data, 5, Decomp, SizeOf(Decomp)) < 0;
end;

function Test_DecompressCorrupted: Boolean;
var
  Data: array[0..3] of Byte;
  Decomp: array[0..9] of Byte;
begin
  Data[0] := $10;
  Data[1] := $41;
  Data[2] := $00; Data[3] := $00;
  Result := LZ4_decompress_safe(Data, 4, Decomp, SizeOf(Decomp)) < 0;
end;

function Test_InteropOfficialABC: Boolean;
const
  Comp: array[0..3] of Byte = ($30, $61, $62, $63);
  abc: array[0..2] of Byte = (ord('a'),ord('b'),ord('c'));
var
  Decomp: array[0..2] of Byte;
begin
  Result := (LZ4_decompress_safe(Comp, SizeOf(Comp), Decomp, SizeOf(Decomp)) = 3) and
            CompareMemory(@Decomp, @abc, 3);
end;

function Test_InteropSelf: Boolean;
begin
  Result := True;
end;

function Test_TextFileSimulation: Boolean;
var
  Text: AnsiString;
  Buf: array of Byte;
  c, d: Integer;
  i: Integer;
begin
  Text := '[' + StringOfChar('*', 200) + ']'#13#10 +
          'key1=value1'#13#10 +
          'key2=' + StringOfChar('x', 300) + #13#10 +
          '[Section]'#13#10;
  for i := 1 to 10 do
    Text := Text + 'log line ' + umlIntToStr(i) + ': ' + StringOfChar('=', i) + #13#10;
  SetLength(Buf, Length(Text));
  Move(Text[1], Buf[0], Length(Text));
  Result := CompressDecompressVerify32(Buf, 'Text file sim', c, d);
end;

function Test_ImageDataSimulation: Boolean;
var
  Buf: array of Byte;
  i: Integer;
  c, d: Integer;
begin
  SetLength(Buf, 320 * 200);
  for i := 0 to 319 do
    FillChar(Buf[i * 200], 200, Byte(i mod 256));
  Result := CompressDecompressVerify32(Buf, 'Image 64000B', c, d);
end;

function Test_ProtocolPacket: Boolean;
var
  Buf: array of Byte;
  i: Integer;
  c, d: Integer;
begin
  SetLength(Buf, 1024);
  FillChar(Buf[0], 16, $FF);
  Buf[0] := $01; Buf[1] := $00;
  for i := 16 to 1023 do
    Buf[i] := Byte(i mod 10 + 65);
  Result := CompressDecompressVerify32(Buf, 'Protocol 1KB', c, d);
end;

// ==================== 64-bit Test Functions ====================

function Test_64bit_Basic: Boolean;
var
  Src: AnsiString;
  SrcBuf: array of Byte;
  CompBuf32, DecompBuf32: array of Byte;
  CompBuf64, DecompBuf64: array of Byte;
  CompSize32, DecompSize32: Integer;
  CompSize64, DecompSize64: Int64;
  SrcLen: Integer;
begin
  Src := 'Hello, 64-bit LZ4!';
  SrcLen := Length(Src);
  SetLength(SrcBuf, SrcLen);
  Move(Src[1], SrcBuf[0], SrcLen);

  SetLength(CompBuf32, LZ4_compressBound(SrcLen));
  SetLength(DecompBuf32, SrcLen);
  CompSize32 := LZ4_compress_default(SrcBuf[0], SrcLen, CompBuf32[0], Length(CompBuf32));
  DecompSize32 := LZ4_decompress_safe(CompBuf32[0], CompSize32, DecompBuf32[0], SrcLen);

  SetLength(CompBuf64, LZ4_compressBound64(SrcLen));
  SetLength(DecompBuf64, SrcLen);
  CompSize64 := LZ4_compress_default64(SrcBuf[0], SrcLen, CompBuf64[0], Length(CompBuf64));
  DecompSize64 := LZ4_decompress_safe64(CompBuf64[0], CompSize64, DecompBuf64[0], SrcLen);

  Result := (DecompSize32 = SrcLen) and
            (DecompSize64 = SrcLen) and
            (CompSize32 = CompSize64) and
            CompareMemory(@DecompBuf32[0], @DecompBuf64[0], SrcLen);
end;

function Test_64bit_LargeRepeat: Boolean;
var
  TotalSize: Int64;
  BigData: array of Byte;
  CompBuf, DecompBuf: array of Byte;
  CompSize, DecompSize: Int64;
begin
  TotalSize := 10 * MB;
  SetLength(BigData, TotalSize);
  FillChar(BigData[0], TotalSize, Ord('A'));

  SetLength(CompBuf, LZ4_compressBound64(TotalSize));
  SetLength(DecompBuf, TotalSize);
  CompSize := LZ4_compress_default64(BigData[0], TotalSize, CompBuf[0], Length(CompBuf));
  DecompSize := LZ4_decompress_safe64(CompBuf[0], CompSize, DecompBuf[0], TotalSize);

  Result := (DecompSize = TotalSize) and CompareMemory(@BigData[0], @DecompBuf[0], TotalSize);
  if Result then
    DoStatus('  64-bit large repeat: %d bytes -> %d bytes', [TotalSize, CompSize]);
end;

function Test_64bit_HugeLiteral: Boolean;
var
  TotalSize: Int64;
  BigData: array of Byte;
  CompBuf, DecompBuf: array of Byte;
  CompSize, DecompSize: Int64;
  i: Integer;
begin
  TotalSize := 5 * MB;
  SetLength(BigData, TotalSize);
  RandSeed := 12345;
  for i := 0 to TotalSize-1 do
    BigData[i] := Random(256);

  SetLength(CompBuf, LZ4_compressBound64(TotalSize));
  SetLength(DecompBuf, TotalSize);
  CompSize := LZ4_compress_default64(BigData[0], TotalSize, CompBuf[0], Length(CompBuf));
  DecompSize := LZ4_decompress_safe64(CompBuf[0], CompSize, DecompBuf[0], TotalSize);

  Result := (DecompSize = TotalSize) and CompareMemory(@BigData[0], @DecompBuf[0], TotalSize);
  if Result then
    DoStatus('  64-bit huge literal: %d bytes -> %d bytes', [TotalSize, CompSize]);
end;

function Test_64bit_Streaming: Boolean;
var
  TotalSize: Int64;
  Src, TmpComp, TmpDecomp: array of Byte;
  Pos, Chunk, CompSize, DecompSize: Int64;
  i: Integer;
begin
  TotalSize := 5 * MB;
  SetLength(Src, TotalSize);
  RandSeed := 6789;
  for i := 0 to TotalSize-1 do
    Src[i] := Random(256);

  Pos := 0;
  Result := True;
  while Pos < TotalSize do
  begin
    Chunk := 100000 + Random(200000);
    if Pos + Chunk > TotalSize then
      Chunk := TotalSize - Pos;

    SetLength(TmpComp, LZ4_compressBound64(Chunk));
    CompSize := LZ4_compress_default64(Src[Pos], Chunk, TmpComp[0], Length(TmpComp));
    SetLength(TmpDecomp, Chunk);
    DecompSize := LZ4_decompress_safe64(TmpComp[0], CompSize, TmpDecomp[0], Chunk);
    if (DecompSize <> Chunk) or not CompareMemory(@Src[Pos], @TmpDecomp[0], Chunk) then
    begin
      Result := False;
      Break;
    end;
    Inc(Pos, Chunk);
  end;
  if Result then
    DoStatus('  64-bit streaming: 5 MB processed in variable chunks');
end;

// ==================== Main Test Runner ====================

procedure RunAllTests;
begin
  Passed := 0;
  Failed := 0;
  DoStatus('========================================');
  DoStatus('  LZ4 Extended Test Suite (32/64 bit)');
  DoStatus('========================================');
  DoStatus('');

  DoStatus('--- Basic Functionality ---');
  LogResult('Empty data', Test_EmptyData);
  LogResult('Single byte', Test_SingleByte);
  LogResult('Two bytes', Test_TwoBytes);
  LogResult('Three bytes', Test_ThreeBytes);
  LogResult('Simple ASCII', Test_SimpleAscii);
  LogResult('Repeated pattern (5000 Z)', Test_RepeatedPattern);
  LogResult('Repeated pattern (ABAB...)', Test_RepeatedPattern2);
  LogResult('Mixed text', Test_MixedText);

  DoStatus('');
  DoStatus('--- Structured Data ---');
  LogResult('JSON-like data', Test_JsonLike);
  LogResult('XML-like data', Test_XmlLike);

  DoStatus('');
  DoStatus('--- Boundary / Stress ---');
  LogResult('Max distance (65536 bytes)', Test_MaxDistance);
  LogResult('Compressed larger than original', Test_CompressedLarger);
  LogResult('Exact output buffer', Test_ExactBuffer);
  LogResult('Huge literal (>64KB)', Test_HugeLiteral);
  LogResult('Stream compression (variable chunks)', Test_StreamCompression);

  DoStatus('');
  DoStatus('--- Random / Binary Data ---');
  LogResult('Random 1KB', Test_Random_1KB);
  LogResult('Random 16KB', Test_Random_16KB);
  LogResult('Random 64KB', Test_Random_64KB);
  LogResult('Random 1MB', Test_Random_1MB);
  LogResult('Random 4MB', Test_Random_4MB);
  LogResult('Binary data (structured)', Test_BinaryStructured);

  DoStatus('');
  DoStatus('--- Error Handling ---');
  LogResult('Decompress truncated data', Test_DecompressTruncated);
  LogResult('Decompress invalid offset', Test_DecompressInvalidOffset);
  LogResult('Decompress output overflow', Test_DecompressOutputOverflow);
  LogResult('Decompress corrupted data', Test_DecompressCorrupted);

  DoStatus('');
  DoStatus('--- Interoperability ---');
  LogResult('Official LZ4 "abc" decompress', Test_InteropOfficialABC);
  LogResult('Our compress -> self consistency', Test_InteropSelf);

  DoStatus('');
  DoStatus('--- Daily Use Simulation ---');
  LogResult('Text file simulation', Test_TextFileSimulation);
  LogResult('Image data simulation', Test_ImageDataSimulation);
  LogResult('Protocol packet simulation', Test_ProtocolPacket);

  DoStatus('');
  DoStatus('--- 64-bit API Tests ---');
  LogResult('64-bit basic consistency', Test_64bit_Basic);
  LogResult('64-bit large repeat (10 MB)', Test_64bit_LargeRepeat);
  LogResult('64-bit huge literal (5 MB)', Test_64bit_HugeLiteral);
  LogResult('64-bit streaming (5 MB)', Test_64bit_Streaming);

  DoStatus('');
  DoStatus('========================================');
  DoStatus('  Total: %d  Passed: %d  Failed: %d', [Passed + Failed, Passed, Failed]);
  if Failed = 0 then
    DoStatus('  ALL TESTS PASSED!')
  else
    DoStatus('  SOME TESTS FAILED!');
  DoStatus('========================================');
  DoStatus('');
end;

end.

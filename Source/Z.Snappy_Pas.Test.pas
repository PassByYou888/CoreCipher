// ---------------------------------------------------------------------------
// test Snappy compression / decompression for pascal (delphi/fpc)
// create by.qq600585
// ---------------------------------------------------------------------------
unit Z.Snappy_Pas.Test;

{$DEFINE FPC_DELPHI_MODE}
{$I Z.Define.inc}
{$R-}

interface

uses SysUtils, Z.Core, Z.PascalStrings, Z.UPascalStrings, Z.Status, Z.Snappy_Pas;

type

  TSnappyTester = class
  private type
    TByteArray = TBytes;
  private
    FTestCount: Integer;
    FPassed: Integer;

    // ---------- data generation helpers ----------
    function StrToBytes(const s: TPascalString): TByteArray;
    function RepeatingBytes(const Pattern: TByteArray; TotalLen: Int64): TByteArray;
    function RandomBytes(Len: Int64): TByteArray;
    function GenerateJsonData(RecordCount: Integer): TByteArray;
    function GenerateLogData(TotalLen: Int64): TByteArray;
    function GenerateXmlData(ElemCount: Integer): TByteArray;
    function GenerateBase64Data(TotalLen: Int64): TByteArray;
    function GenerateSparseData(TotalLen: Int64; Fill: Byte): TByteArray;
    function GenerateBinaryRepeatingPattern(TotalLen: Int64): TByteArray;
    function GenerateFibonacciText(TotalLen: Int64): TByteArray;
    function GenerateIncrementalNumbers(Count: Integer): TByteArray;

    // core test executor
    procedure RunTest(const Name: string; const Data: TByteArray);
  public
    constructor Create;
    procedure RunAllTests;
    class procedure Run;
  end;

implementation

// ============================================================================
// TSnappyTester implementation
// ============================================================================

constructor TSnappyTester.Create;
begin
  inherited Create;
  FTestCount := 0;
  FPassed := 0;
end;

function TSnappyTester.StrToBytes(const s: TPascalString): TByteArray;
begin
  Result := s.ANSI;
end;

function TSnappyTester.RepeatingBytes(const Pattern: TByteArray; TotalLen: Int64): TByteArray;
var
  i: Int64;
  patLen: Int64;
begin
  patLen := Length(Pattern);
  SetLength(Result, TotalLen);
  for i := 0 to TotalLen - 1 do
      Result[i] := Pattern[i mod patLen];
end;

function TSnappyTester.RandomBytes(Len: Int64): TByteArray;
var
  i: Int64;
begin
  SetLength(Result, Len);
  for i := 0 to Len - 1 do
      Result[i] := Random(256);
end;

function TSnappyTester.GenerateJsonData(RecordCount: Integer): TByteArray;
var
  i: Integer;
  s: AnsiString;
begin
  s := '[';
  for i := 0 to RecordCount - 1 do
    begin
      if i > 0 then
          s := s + ',';
      s := s + '{"id":' + IntToStr(i) +
        ',"name":"Item ' + IntToStr(i) +
        '","value":' + IntToStr(Random(1000000)) +
        ',"tags":["tag1","tag2","tag3"]}';
    end;
  s := s + ']';
  Result := StrToBytes(s);
end;

function TSnappyTester.GenerateLogData(TotalLen: Int64): TByteArray;
var
  s: AnsiString;
begin
  s := '';
  while Int64(Length(s)) < TotalLen do
      s := s + Format('[%s] [INFO] Sample log message. Quick brown fox. Error: 0x%x'#13#10,
      [FormatDateTime('yyyy-mm-dd hh:nn:ss.zzz', Now), Random(255)]);
  SetLength(Result, TotalLen);
  if Length(s) > 0 then
      Move(s[1], Result[0], TotalLen);
end;

function TSnappyTester.GenerateXmlData(ElemCount: Integer): TByteArray;
var
  i: Integer;
  s: AnsiString;
begin
  s := '<?xml version="1.0"?><root>';
  for i := 0 to ElemCount - 1 do
      s := s + '<item id="' + IntToStr(i) +
      '"><name>Item' + IntToStr(i) +
      '</name><value>' + IntToStr(Random(100000)) +
      '</value></item>';
  s := s + '</root>';
  Result := StrToBytes(s);
end;

function TSnappyTester.GenerateBase64Data(TotalLen: Int64): TByteArray;
const
  B64Chars: AnsiString = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
var
  i: Int64;
  s: AnsiString;
begin
  s := '';
  while Int64(Length(s)) < TotalLen do
      s := s + B64Chars[Random(64) + 1];
  SetLength(Result, TotalLen);
  if Length(s) > 0 then
      Move(s[1], Result[0], TotalLen);
end;

function TSnappyTester.GenerateSparseData(TotalLen: Int64; Fill: Byte): TByteArray;
var
  i: Int64;
begin
  SetLength(Result, TotalLen);
  for i := 0 to TotalLen - 1 do
    if Random(100) < 5 then
        Result[i] := Random(256)
    else
        Result[i] := Fill;
end;

function TSnappyTester.GenerateBinaryRepeatingPattern(TotalLen: Int64): TByteArray;
var
  i: Int64;
  pat: TByteArray;
begin
  SetLength(pat, 256);
  for i := 0 to 255 do
      pat[i] := i;
  Result := RepeatingBytes(pat, TotalLen);
end;

function TSnappyTester.GenerateFibonacciText(TotalLen: Int64): TByteArray;
var
  s: AnsiString;
  a, b, c: Integer;
begin
  s := '1 1';
  a := 1;
  b := 1;
  while Int64(Length(s)) < TotalLen do
    begin
      c := a + b;
      a := b;
      b := c;
      s := s + ' ' + IntToStr(c);
    end;
  SetLength(Result, TotalLen);
  if Length(s) > 0 then
      Move(s[1], Result[0], TotalLen);
end;

function TSnappyTester.GenerateIncrementalNumbers(Count: Integer): TByteArray;
var
  i: Integer;
  s: AnsiString;
begin
  s := '';
  for i := 1 to Count do
      s := s + IntToStr(i) + ' ';
  Result := StrToBytes(s);
end;

// ---------- single test runner ----------
procedure TSnappyTester.RunTest(const Name: string; const Data: TByteArray);
var
  comp, decomp: TByteArray;
  compSize, decompSize: Int64;
  success: Boolean;
  origLen: Int64;
  startTime, endTime: TDateTime;
  ms: Double;
  ratio: Double;
begin
  Inc(FTestCount);
  origLen := Length(Data);
  DoStatusNoLn(Format('Test %2d: %-40s [len=%-10d] ... ', [FTestCount, Name, origLen]));

  // Compression
  compSize := origLen + (origLen div 6) + 32;
  SetLength(comp, compSize);
  startTime := Now;
  success := SnappyCompress(@Data[0], origLen, @comp[0], compSize);
  endTime := Now;
  if not success then
    begin
      DoStatusNoLn('FAIL (compress)');
      DoStatusNoLn;
      Exit;
    end;
  ms := (endTime - startTime) * 86400000;
  SetLength(comp, compSize);

  // Decompression
  decompSize := origLen;
  SetLength(decomp, decompSize);
  startTime := Now;
  success := SnappyDecompress(@comp[0], compSize, @decomp[0], decompSize);
  endTime := Now;
  if not success then
    begin
      DoStatusNoLn('FAIL (decompress)');
      DoStatusNoLn;
      Exit;
    end;
  ms := ms + (endTime - startTime) * 86400000;

  if decompSize <> origLen then
    begin
      DoStatusNoLn('FAIL (size mismatch)');
      DoStatusNoLn;
      Exit;
    end;

  if (origLen > 0) and (not CompareMem(@Data[0], @decomp[0], origLen)) then
    begin
      DoStatusNoLn('FAIL (data corruption)');
      DoStatusNoLn;
      Exit;
    end;

  ratio := 100.0 * compSize / origLen;
  DoStatusNoLn(Format('OK  comp: %-10d  ratio: %6.1f%%  time: %7.1f ms',
      [compSize, ratio, ms]));
  DoStatusNoLn;
  Inc(FPassed);
end;

// ---------- all tests ----------
procedure TSnappyTester.RunAllTests;
var
  emptyArr: TByteArray;
begin
  // Make sure empty array has zero length
  SetLength(emptyArr, 0);

  DoStatus('===========================================================');
  DoStatus('      Snappy Compression 38-Test Suite (Class based)');
  DoStatus('===========================================================');
  DoStatus;

  // 1-5: Edge cases and tiny data
  RunTest('Empty', emptyArr);
  RunTest('Single zero byte', [0]);
  RunTest('Single 0xFF byte', [255]);
  RunTest('Two bytes different', [1, 2]);
  RunTest('Three bytes', [1, 2, 3]);

  // 6-10: Short texts
  RunTest('Short text (13 bytes)', StrToBytes('Hello, World!'));
  RunTest('Short text (30 bytes)', StrToBytes('The quick brown fox jumps.'));
  RunTest('Medium text (200 bytes)', StrToBytes(
      'Lorem ipsum dolor sit amet, consectetur adipiscing elit. ' +
        'Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. ' +
        'Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris.'));
  RunTest('Chinese text (100 bytes)', StrToBytes(
      '落霞与孤鹜齐飞，秋水共长天一色。渔舟唱晚，响穷彭蠡之滨；雁阵惊寒，声断衡阳之浦。'));
  RunTest('Numbers only (1KB)',
    RepeatingBytes(StrToBytes('0123456789'), 1024));

  // 11-15: Highly compressible (repetitions)
  RunTest('All zeros 16KB', RepeatingBytes([0], 16384));
  RunTest('All 0xFF 32KB', RepeatingBytes([255], 32768));
  RunTest('Two-byte pattern 64KB', RepeatingBytes([0, 255], 65536));
  RunTest('Repeated 8-byte seq 256KB',
    RepeatingBytes([0, 1, 2, 3, 4, 5, 6, 7], 262144));
  RunTest('Long repeat (1MB)',
    RepeatingBytes([$AA, $55, $AA, $55], 1048576));

  RunTest('Random 1KB', RandomBytes(1024));
  RunTest('Random 8KB', RandomBytes(8192));
  RunTest('Random 64KB', RandomBytes(65536));
  RunTest('Random 512KB', RandomBytes(524288));
  RunTest('Random 2MB', RandomBytes(2097152));

  RunTest('HTML snippet', StrToBytes(
      '<html><head><title>Test</title></head><body>' +
        '<h1>Snappy Compression</h1><p>This is a paragraph with repeated words: test test test.</p>' +
        '</body></html>'));
  RunTest('JSON 2000 records', GenerateJsonData(2000));
  RunTest('XML 500 elements', GenerateXmlData(500));
  RunTest('Log data 128KB', GenerateLogData(131072));
  RunTest('Base64 256KB', GenerateBase64Data(262144));

  RunTest('Binary null-filled 16KB', GenerateSparseData(16384, 0));
  RunTest('Binary 0xFF-filled 32KB', GenerateSparseData(32768, 255));
  RunTest('Binary repeating 0..255 128KB', GenerateBinaryRepeatingPattern(131072));
  RunTest('Fibonacci text 64KB', GenerateFibonacciText(65536));

  RunTest('Repeated text 4MB',
    RepeatingBytes(StrToBytes('Hello World! Hello World! '), 4194304));
  RunTest('Mixed random+repeated 4MB', RandomBytes(4194304));
  RunTest('All zeros 8MB', RepeatingBytes([0], 8388608));
  RunTest('Random 8MB', RandomBytes(8388608));

  RunTest('Single char 64KB', RepeatingBytes([Ord('A')], 65536));
  RunTest('UTF8 text 32KB', StrToBytes('日本語テスト日本語テスト日本語テスト'#13#10'Русский текст для проверки сжатия.'));
  RunTest('Data with nulls 1KB', [0, 1, 2, 3, 0, 0, 0, 4, 5, 6, 0, 0, 0, 7, 8, 9, 10, 0, 0, 0, 0, 0, 0, 11, 12, 13, 0, 14, 15]);
  RunTest('Large JSON 5000 records', GenerateJsonData(5000));
  RunTest('Extreme compression (1MB zeros)', RepeatingBytes([0], 1048576));

  DoStatus;
  DoStatus('===========================================================');
  DoStatus(Format('Total: %d  Passed: %d  Failed: %d', [FTestCount, FPassed, FTestCount - FPassed]));
  if FTestCount = FPassed then
      DoStatus('All 38 tests passed - implementation is correct!')
  else
      DoStatus('Some tests failed.');
end;

class procedure TSnappyTester.Run;
begin
  with TSnappyTester.Create do
    begin
      RunAllTests;
      free;
    end;
end;

end.

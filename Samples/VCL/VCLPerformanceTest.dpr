program VCLPerformanceTest;

uses
  Vcl.Forms,
  Unit1 in 'Unit1.pas' {Form1},
  CoreCipher in '..\..\Source\CoreCipher.pas',
  CoreClasses in '..\..\Source\CoreClasses.pas',
  DoStatusIO in '..\..\Source\DoStatusIO.pas',
  ListEngine in '..\..\Source\ListEngine.pas',
  PasMP in '..\..\Source\PasMP.pas',
  UnicodeMixedLib in '..\..\Source\UnicodeMixedLib.pas',
  PascalStrings in '..\..\Source\PascalStrings.pas',
  MemoryStream64 in '..\..\Source\MemoryStream64.pas',
  Fast_MD5 in '..\..\Source\Fast_MD5.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TForm1, Form1);
  Application.Run;
end.

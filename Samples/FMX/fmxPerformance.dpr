program fmxPerformance;

uses
  System.StartUpCopy,
  FMX.Forms,
  Unit1 in 'Unit1.pas' {Form1},
  CoreCipher in '..\..\Source\CoreCipher.pas',
  CoreClasses in '..\..\Source\CoreClasses.pas',
  DoStatusIO in '..\..\Source\DoStatusIO.pas',
  ListEngine in '..\..\Source\ListEngine.pas',
  MemoryStream64 in '..\..\Source\MemoryStream64.pas',
  PascalStrings in '..\..\Source\PascalStrings.pas',
  PasMP in '..\..\Source\PasMP.pas',
  TextDataEngine in '..\..\Source\TextDataEngine.pas',
  UnicodeMixedLib in '..\..\Source\UnicodeMixedLib.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TForm1, Form1);
  Application.Run;
end.

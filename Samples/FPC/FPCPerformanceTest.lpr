program FPCperformanceTest;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}{$IFDEF UseCThreads}
  cthreads,
  {$ENDIF}{$ENDIF}
  Interfaces, // this includes the LCL widgetset
  Forms, Unit1, Z.Cipher, Z.Status, Z.AES, Z.Compress, Z.Core, Z.Delphi.JsonDataObjects, Z.DFE, Z.Expression, Z.Expression.Sequence, Z.FPC.GenericList, Z.FragmentBuffer,
  Z.Geometry.Low, Z.Geometry2D, Z.Geometry3D, Z.HashList.Templet, Z.Instance.Tool, Z.Int128, Z.IOThread, Z.Json, Z.ListEngine, Z.LZ4_Pas, Z.LZ4_Pas.Test, Z.MD5, Z.MemoryStream,
  Z.Notify, Z.Number, Z.OpCode, Z.Parsing, Z.PascalStrings, Z.Snappy_Pas, Z.Snappy_Pas.Test, Z.Status.Exception_Helper, Z.Cadencer, Z.TextDataEngine, Z.UnicodeMixedLib,
  Z.UPascalStrings, Z.UReplace
  { you can add units after this };

{$R *.res}

begin
  RequireDerivedFormResource:=True;
  Application.Initialize;
  Application.CreateForm(TForm1, Form1);
  Application.Run;
end.

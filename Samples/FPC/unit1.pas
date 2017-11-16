unit Unit1;

{$mode objfpc}{$H+}
{$MODESWITCH AdvancedRecords}
{$A+} {Word Align Data}
{$Q-} {Overflow Checking}
{$R-} {Range-Checking}
{$S-} {Stack-Overflow Checking}
{$V-} {Var-String Checking}
{$B-} {Complete Boolean Evaluation}
{$I+} {Input/Output-Checking}
{$P+} {Open Parameters}
{$T-} {Typed @ Operator}
{$W-} {Windows Stack Frame}
{$X+} {Extended Syntax}


interface

uses
  Classes, SysUtils, FileUtil, Forms, Controls, Graphics, Dialogs, StdCtrls,
  CoreCipher, DoStatusIO;

type

  { TForm1 }

  TForm1 = class(TForm)
    Button1: TButton;
    Memo1: TMemo;
    procedure Button1Click(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
  private
    { private declarations }
  public
    { public declarations }
    procedure DoStatusNear(AText: string; const ID: Integer=0);
  end;

var
  Form1: TForm1;

implementation

{$R *.lfm}

{ TForm1 }
procedure TForm1.DoStatusNear(AText: string; const ID: Integer=0);
begin
  Form1.Memo1.Lines.Add(AText);
  Application.ProcessMessages;
end;


procedure TForm1.FormCreate(Sender: TObject);
begin
  AddDoStatusHook(Self, @DoStatusNear);
end;

procedure TForm1.Button1Click(Sender: TObject);
begin
  Button1.Visible:=False;
  TestCoreCipher;
  Button1.Visible:=True;
end;

procedure TForm1.FormDestroy(Sender: TObject);
begin
  DeleteDoStatusHook(Self);
end;

end.


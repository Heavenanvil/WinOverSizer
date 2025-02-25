program WinOverSizer;

uses
  Vcl.Forms,
  Unit1 in '..\Unit1.pas' {Form1};

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.Title := 'WinOverSizer - v1';
  Application.CreateForm(TForm1, Form1);
  Application.Run;
end.

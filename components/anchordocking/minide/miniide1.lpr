program miniide1;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}{$IFDEF UseCThreads}
  cthreads,
  {$ENDIF}{$ENDIF}
  Interfaces, // this includes the LCL widgetset
  Forms, Unit1, Controls, LazUTF8;

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TMainIDE, MainIDE);
  if (Paramcount>0) then
    MainIDE.LoadLayout(ParamStrUTF8(1));
  Application.Run;
end.


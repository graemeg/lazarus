program pochecker;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}{$IFDEF UseCThreads}
  cthreads,
  {$ENDIF}{$ENDIF}
  Interfaces, // this includes the LCL widgetset
  Forms, pocheckermain, pofamilies, resultdlg, pocheckerconsts,
  graphstat, pocheckersettings, pofamilylists;

{$R *.res}

begin
  RequireDerivedFormResource := True;
  Application.Scaled := True;
  Application.Title := '';
  Application.Initialize;
  Application.CreateForm(TPoCheckerForm, PoCheckerForm);
  Application.Run;
end.


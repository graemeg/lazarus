program project1;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}{$IFDEF UseCThreads}
  cthreads,
  {$ENDIF}{$ENDIF}
  Interfaces, // this includes the LCL widgetset
  Classes,
  Forms
  { add your units here }, unit1;

begin
  Application.Title:='';
  Application.Initialize;
  Application.BidiMode := bdRightToLeft;
  Application.CreateForm(TForm1, Form1);
  Application.Run;
end.


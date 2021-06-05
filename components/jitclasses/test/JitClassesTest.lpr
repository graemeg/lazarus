program JitClassesTest;

{$mode objfpc}{$H+}

uses
  Interfaces, Forms, GuiTestRunner, TestJitClass;

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TGuiTestRunner, TestRunner);
  Application.Run;
end.


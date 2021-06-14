unit TestErrorHandler;

{$mode objfpc}{$H+}

interface

uses
  FpDbgDwarf, FpDbgUtil, FpErrorMessages, TestHelperClasses, {$ifdef FORCE_LAZLOGGER_DUMMY} LazLoggerDummy {$else} LazLoggerBase {$endif}, LazUTF8,
  DbgIntfBaseTypes, sysutils, fpcunit, testregistry;

type

  { TTestMemManager }

  { TTestErrorHandler }

  TTestErrorHandler = class(TTestCase)
  published
    procedure TestErrorHandler;
  end;

implementation

{ TTestErrorHandler }

procedure TTestErrorHandler.TestErrorHandler;
var
  e: TFpError;
  e2: TFpError;
begin
  e := CreateError(fpErrSymbolNotFound, ['a']);
  e2 := CreateError(fpErrLocationParserMemRead, e, []);
  ErrorHandler.ErrorAsString(e2);
end;

initialization
  RegisterTest(TTestErrorHandler);

end.


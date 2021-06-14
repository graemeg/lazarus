unit TestDwarfVarious;

{$mode objfpc}{$H+}

interface

uses
  FpDbgDwarf, FpDbgUtil, {$ifdef FORCE_LAZLOGGER_DUMMY} LazLoggerDummy {$else} LazLoggerBase {$endif}, LazUTF8, sysutils, fpcunit, testregistry;

type

  { TestDwarfVarious }

  TTestDwarfVarious = class(TTestCase)
  published
    procedure TestCompareUtf8BothCase;
  end;

implementation

procedure TTestDwarfVarious.TestCompareUtf8BothCase;
var
  s1, s2,s3: String;
begin
  s2 := UTF8UpperCase( '_vptr$TOBJECT');
  s3 := UTF8LowerCase( '_vptr$TOBJECT');

  s1 := '_vptr$TOBJECT';
  AssertTrue( CompareUtf8BothCase(@s2[1],@s3[1],@s1[1]) );
  s1 := '_Vptr$TOBJECT';
  AssertTrue( CompareUtf8BothCase(@s2[1],@s3[1],@s1[1]) );
  s1 := '_vPtR$TOBJECT';
  AssertTrue( CompareUtf8BothCase(@s2[1],@s3[1],@s1[1]) );
  s1 := '_Vvptr$TOBJECT';
  AssertFalse( CompareUtf8BothCase(@s2[1],@s3[1],@s1[1]) );
end;

initialization

  RegisterTest(TTestDwarfVarious);
end.


{
 Test all with:
     ./runtests --format=plain --suite=TTestLazUTF8

 Test specific with:
     ./runtests --format=plain --suite=TestUTF8Trim
     ./runtests --format=plain --suite=TestUTF8Pos
     ./runtests --format=plain --suite=TestFindInvalidUTF8
     ./runtests --format=plain --suite=TestFindUnicodeToUTF8
     ./runtests --format=plain --suite=TestUTF8QuotedStr
}
unit TestLazUTF8;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpcunit, testglobals, LazUTF8, LazLoggerBase;

type

  { TTestLazUTF8 }

  TTestLazUTF8 = class(TTestCase)
  public
  published
    procedure TestUTF8Trim;
    procedure TestUTF8Pos;
    procedure TestFindInvalidUTF8;
    procedure TestFindUnicodeToUTF8;
    procedure TestUTF8QuotedStr;
  end;

implementation

{ TTestLazUTF8 }

procedure TTestLazUTF8.TestUTF8Trim;
begin
  AssertEquals('Empty string','',UTF8Trim(''));
  AssertEquals('Single space string','',UTF8Trim(' '));
  AssertEquals('Single char string','a',UTF8Trim('a'));
  AssertEquals('Space at start','a',UTF8Trim(' a'));
  AssertEquals('Space at end','a',UTF8Trim('a '));
  AssertEquals('Space at start and end','a',UTF8Trim(' a '));
  AssertEquals('Tabs','a',UTF8Trim(#9'a'#9));
  AssertEquals('Line breaks 1','a',UTF8Trim(#10'a'#13#10));
  AssertEquals('Line breaks 2','',UTF8Trim(#10#13#13));
  AssertEquals('Control characters 1','a',UTF8Trim(#0'a'#0));
  AssertEquals('left-to-right','a',UTF8Trim(#$E2#$80#$8E'a'));
  AssertEquals('right-to-left mark','a',UTF8Trim('a'#$E2#$80#$8F));
  AssertEquals('left-to-right, right-to-left mark','a',UTF8Trim(#$E2#$80#$8E'a'#$E2#$80#$8F));
end;

procedure TTestLazUTF8.TestUTF8Pos;
begin
  AssertEquals('Skip first occurence',4,UTF8Pos('ab','abcabc',2));
  AssertEquals('Not found',0,UTF8Pos('abc'#0,'abcabc'));
  AssertEquals('Check #0',2,UTF8Pos('bc'#0,'abc'#0'abc'));
end;

procedure TTestLazUTF8.TestFindInvalidUTF8;

  procedure t(const s: string; Expected: PtrInt; const Title: string);
  var
    Actual: PtrInt;
  begin
    Actual:=FindInvalidUTF8Codepoint(PChar(s),length(s));
    AssertEquals(Title+': '+dbgMemRange(Pointer(s),length(s)),Expected,Actual);
  end;

begin
  t('',-1,'empty');
  t('a',-1,'');
  t('a'#0,-1,'a with #0');
  t(#0'a',-1,'#0 with a');
  t(#128,0,'gap value 128');
  t(#191,0,'gap value 192');
  // 1 byte UTF-8
  t(UnicodeToUTF8(0),-1,'unicode(0)');
  t(UnicodeToUTF8(1),-1,'unicode(1)');
  t(UnicodeToUTF8(65),-1,'unicode(65)');
  t(UnicodeToUTF8($7f),-1,'unicode($7f)');
  // 2 bytes UTF-8
  t(UnicodeToUTF8($80),-1,'unicode($80)');
  t(UnicodeToUTF8($7ff),-1,'unicode($7ff)');
  // 3 bytes UTF-8
  t(UnicodeToUTF8($800),-1,'unicode($800)');
  t(UnicodeToUTF8($ffff),-1,'unicode($ffff)');
  // 4 bytes UTF-8
  t(UnicodeToUTF8($10000),-1,'unicode($10000)');
  t(UnicodeToUTF8($10900),-1,'unicode($10900)');
  t(UnicodeToUTF8($10ffff),-1,'unicode($10ffff)');
  t(#$F4#$8F#$BF#$BF,-1,'unicode($10ffff)');
  t(#$F4#$90#$80#$80,0,'unicode($110000)');
  t(#$c0#0,0,'invalid second byte of 2 byte');
  t(#$e0#0,0,'invalid second byte of 3 byte');
  t(#$e0#$80#0,0,'invalid third byte of 3 byte');
  t(#$f0#0,0,'invalid second byte of 4 byte');
  t(#$f0#$80#0,0,'invalid third byte of 4 byte');
  t(#$f0#$80#$80#0,0,'// invalid fourth byte of 4 byte');
  t(#$c0#$80,0,'invalid: ascii encoded as 2 byte');
  t(#$c0#$8f,0,'invalid: ascii encoded as 2 byte');
  t(#$c1#$80,0,'invalid: ascii encoded as 2 byte');
  t(#$c1#$bf,0,'invalid: ascii encoded as 2 byte');
  t(#$e0#$80#$80,0,'invalid: 0 encoded as 3 byte');
  t(#$e0#$9f#$bf,0,'invalid: $7ff encoded as 3 byte');
  t(#$f0#$80#$80#$80,0,'invalid: 0 encoded as 4 byte');
  t(#$f0#$8f#$bf#$bf,0,'invalid: $ffff encoded as 4 byte');
  t(#$F7#$BF#$BF#$BF,0,'invalid 4 byte out of range');
end;

procedure TTestLazUTF8.TestFindUnicodeToUTF8;

  procedure t(CodePoint: cardinal; Expected: string);
  var
    Actual: String;
  begin
    Actual:=LazUTF8.UnicodeToUTF8(CodePoint);
    AssertEquals('CodePoint='+HexStr(CodePoint,8),
      dbgMemRange(PChar(Expected),length(Expected)),
      dbgMemRange(PChar(Actual),length(Actual)));
  end;

begin
  t($0,#0);
  t($1,#1);
  t($20,' ');
  t($7f,#$7f);
  t($80,#$C2#$80);
  t($7ff,#$DF#$BF);
  t($800,#$E0#$A0#$80);
  t($fff,#$E0#$BF#$BF);
  t($1fff,#$E1#$BF#$BF);
  t($3fff,#$E3#$BF#$BF);
  t($7fff,#$E7#$BF#$BF);
  t($ffff,#$EF#$BF#$BF);
  t($1ffff,#$F0#$9F#$BF#$BF);
  t($3ffff,#$F0#$BF#$BF#$BF);
  t($7ffff,#$F1#$BF#$BF#$BF);
  t($fffff,#$F3#$BF#$BF#$BF);
end;

procedure TTestLazUTF8.TestUTF8QuotedStr;

  procedure t(const S, Quote, Expected: string);
  var
    Actual: String;
  begin
    Actual:=UTF8QuotedStr(S,Quote);
    AssertEquals('S="'+S+'" Quote="'+Quote+'"',Expected,Actual);
  end;

begin
  t('','=','==');
  t('','AB','ABAB');
  t('A','A','AAAA');
  t('bAb','A','AbAAbA');
  t('cABc','AB','ABcABABcAB');
end;

initialization
  AddToLazUtilsTestSuite(TTestLazUTF8);

end.


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
    procedure TestUTF8ToUTF16;
    procedure TestFindInvalidUTF8;
    procedure TestFindUnicodeToUTF8;
    procedure TestUTF8QuotedStr;
    procedure TestUTF8FixBroken;
  end;

implementation

function dbgUnicodeStr(S: UnicodeString): string;
var
  i: Integer;
begin
  Result:='';
  for i:=1 to length(S) do
    Result:=Result+'$'+HexStr(ord(S[i]),4);
end;

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
  AssertEquals('Skip first occurrence',4,UTF8Pos('ab','abcabc',2));
  AssertEquals('Not found',0,UTF8Pos('abc'#0,'abcabc'));
  AssertEquals('Check #0',2,UTF8Pos('bc'#0,'abc'#0'abc'));
end;

procedure TTestLazUTF8.TestUTF8ToUTF16;

  procedure t(theUTF8: string; Expected: UnicodeString);
  var
    Actual: UnicodeString;
  begin
    Actual:=LazUTF8.UTF8ToUTF16(theUTF8);
    //writeln('TTestLazUTF8.TestUTF8ToUTF16 ','UTF8='+dbgMemRange(PChar(theUTF8),length(theUTF8)));
    AssertEquals('UTF8='+dbgMemRange(PChar(theUTF8),length(theUTF8)),
      dbgUnicodeStr(Expected),
      dbgUnicodeStr(Actual));
  end;

begin
  t(#0,#0);
  t(#1,#1);
  t(#$20,' ');
  t(#$7f,#$7f);
  t(#$80,'');
  t(#$C0#0,'?'#0); // invalid 2-byte UTF8
  t(#$C2#$80,#$0080);
  t(#$DF#$BF,#$07FF);
  t(#$E0#$A0#$80,#$0800);
  t(#$E0#$BF#$BF,#$0FFF);
  t(#$E1#$BF#$BF,#$1FFF);
  t(#$E3#$BF#$BF,#$3FFF);
  t(#$E7#$BF#$BF,#$7FFF);
  t(#$ED#$9F#$BF,#$D7FF);
  t(#$ED#$A0#$80,'?'); // U+D800 is not Unicode standard conform, but many en/decoders support it anyway
  t(#$ED#$BF#$BF,'?'); // U+DFFF is not Unicode standard conform, but many en/decoders support it anyway
  t(#$EE#$80#$80,#$E000);
  t(#$EF#$80#$80,#$F000);
  t(#$EF#$BF#$BF,#$FFFF);
  t(#$F0#$9F#$98#$80,#$D83D#$DE00); // U+1F600
  t(#$F0#$9F#$BF#$BF,#$D83F#$DFFF); // U+1FFFF
  t(#$F0#$AF#$BF#$BF,#$D87F#$DFFF); // U+2FFFF
  t(#$F0#$BF#$BF#$BF,#$D8BF#$DFFF); // U+3FFFF
  t(#$F1#$BF#$BF#$BF,#$D9BF#$DFFF); // U+7FFFF
  t(#$F2#$BF#$BF#$BF,#$DABF#$DFFF); // U+8FFFF
  t(#$F3#$BF#$BF#$BF,#$DBBF#$DFFF); // U+FFFFF
  t(#$F4#$8F#$BF#$BF,#$DBFF#$DFFF); // U+10FFFF
  t(#$F7#$BF#$BF#$BF,'?'); // invalid 4 byte out of range
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
  t(#$c2#0,0,'valid 2 byte');
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
  t(#$ED#$A0#$80,0,'3 byte encoding for reserved UTF-16 surrogate halve');
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
  t($1f600,#$F0#$9F#$98#$80);
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

procedure TTestLazUTF8.TestUTF8FixBroken;

  procedure t(const S, Expected: string);
  var
    Actual: String;
  begin
    Actual:=S;
    UTF8FixBroken(Actual);
    AssertEquals('S: '+dbgMemRange(PChar(S),length(S)),
      dbgMemRange(PChar(Expected),length(Expected)),
      dbgMemRange(PChar(Actual),length(Actual)));
  end;

begin
  t(#$0,#$0);
  t(#$1,#$1);
  t(#$7F,#$7F);
  t(#$80,' ');
  t(#$BF,' ');
  t(#$C0#$0,' '#$0);
  t(#$C0#$7F,' '#$7F);
  t(#$C0#$80,'  ');
  t(#$C0#$CF,'  ');
  t(#$C1#$80,'  ');
  t(#$C2#$7F,' '#$7F);
  t(#$C2#$80,#$C2#$80);
  t(#$DF#$80,#$DF#$80);
  t(#$DF#$BF,#$DF#$BF);
  t(#$DF#$C0,'  ');
  t(#$DF#$70,' '#$70);
  t(#$E0#$80,'  ');
  t(#$E0#$80#$80,'   ');
  t(#$E0#$9F#$BF,'   ');
  t(#$E0#$A0#$80,#$E0#$A0#$80);
  t(#$E0#$80#$70,'  '#$70);
  t(#$EF#$BF#$BF,#$EF#$BF#$BF);
  t(#$EF#$BF#$7F,'  '#$7F);
  t(#$EF#$BF#$C0,'   ');
  t(#$EF#$7F#$80,' '#$7F' ');
  t(#$F0#$80#$80#$80,'    ');
  t(#$F0#$8F#$BF#$BF,'    ');
  t(#$F0#$9F#$BF#$BF,#$F0#$9F#$BF#$BF);
  t(#$F0#$9F#$BF#$CF,'    ');
  t(#$F0#$9F#$CF#$BF,'  '#$CF#$BF);
  t(#$F0#$CF#$BF#$BF,' '#$CF#$BF' ');
  t(#$F4#$8F#$BF#$BF,#$F4#$8F#$BF#$BF);
  t(#$F4#$90#$80#$80,'    ');
end;

initialization
  AddToLazUtilsTestSuite(TTestLazUTF8);

end.


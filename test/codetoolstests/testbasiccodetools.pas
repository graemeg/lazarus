{
 Test with:
   ./runtests --format=plain --suite=TTestBasicCodeTools
   ./runtests --format=plain --suite=TestFindLineEndOrCodeInFrontOfPosition
   ./runtests --format=plain --suite=TestHasTxtWord
   ./runtests --format=plain --suite=TestBasicFindCommentEnd
   ./runtests --format=plain --suite=TestBasicFindNextComment
   ./runtests --format=plain --suite=TestCompareTextIgnoringSpace
   ./runtests --format=plain --suite=TestGuessIndentSize
   ./runtests --format=plain --suite=TestReindent
   ./runtests --format=plain --suite=TestSimpleFormat
   ./runtests --format=plain --suite=TestDateToCfgStr
   ./runtests --format=plain --suite=TestFilenameIsMatching
}
unit TestBasicCodetools;

{$mode objfpc}{$H+}

interface

uses
  fpcunit, Classes, SysUtils, testglobals, FileProcs, BasicCodeTools;

type
  { TTestBasicCodeTools }

  TTestBasicCodeTools = class(TTestCase)
  protected
  published
    // BasicCodeTools
    procedure TestFindLineEndOrCodeInFrontOfPosition;
    procedure TestHasTxtWord;
    procedure TestBasicFindCommentEnd;
    procedure TestBasicFindNextComment;
    procedure TestCompareTextIgnoringSpace;
    procedure TestGuessIndentSize;
    procedure TestReIndent;
    procedure TestSimpleFormat;
    // FileProcs
    procedure TestDateToCfgStr;
    procedure TestFilenameIsMatching;
  end;

implementation

{ TTestBasicCodeTools }

procedure TTestBasicCodeTools.TestFindLineEndOrCodeInFrontOfPosition;

  procedure t(Src: string; SkipSemicolonComma: boolean = true;
    StopAtDirectives: boolean = true;
    SkipEmptyLines: boolean = false; NestedComments: boolean = true);
  var
    Position: integer;
    Expected: integer;
    Actual: LongInt;
    OrigSrc: String;
  begin
    OrigSrc:=Src;
    Expected:=Pos('$',Src);
    if Expected<1 then
      raise Exception.Create('TTestBasicCodeTools.TestFindLineEndOrCodeInFrontOfPosition missing # expected position');
    Delete(Src,Expected,1);
    Position:=Pos('|',Src);
    if Position<1 then
      raise Exception.Create('TTestBasicCodeTools.TestFindLineEndOrCodeInFrontOfPosition missing | start position');
    Delete(Src,Position,1);
    Actual:=FindLineEndOrCodeInFrontOfPosition(Src,Position,1,NestedComments,
      StopAtDirectives,SkipSemicolonComma,SkipEmptyLines);
    AssertEquals('['+dbgstr(OrigSrc)+']',Expected,Actual);
  end;

var
  e: String;
begin
  //writeln('TTestBasicCodeTools.TestFindLineEndOrCodeInFrontOfPosition ');
  e:=#13#10; // use windows line endings, they are more complicated
  t(' $'+e+'|a:=1;');
  t('a$'+e+'// comment'+e+' { comment } '+e+'|');
  t('$'+e+' (* *)'+e+' |a:=1');
  t('a:=1;(* comment of first line'+e+' *)$ |b:=1');
  t('a:=1; // comment$'+e+'|b:=1');
  t('a:=1; (* comment'+e+' *) $'+e+'|b:=1');
  t('a:=1; (* comment'+e+' *) { comment'+e+' } $'+e+'|b:=1');
end;

procedure TTestBasicCodeTools.TestHasTxtWord;

  procedure t(aWord,aText: PChar; ExpectedWholeWord: boolean; ExpectedCount: SizeInt);
  var
    WholeWord: boolean;
    Count: SizeInt;
  begin
    HasTxtWord(aWord,aText,WholeWord,Count);
    AssertEquals('Word="'+aWord+'" Text="'+aText+'" WholeWord',ExpectedWholeWord,WholeWord);
    AssertEquals('Word="'+aWord+'" Text="'+aText+'" Count',ExpectedCount,Count);
  end;

begin
  t(nil,nil,false,0);
  t('a','a',true,1);
  t('ab','a',false,0); // ab not in a
  t('a','ab',false,1); // a in ab
  t('a','aba',false,2);
  t('a','a a',true,2);
  t('a','ab a',true,1);
  t('abc','ab abcd',false,1);
  t('ab','abab',false,2);
end;

procedure TTestBasicCodeTools.TestBasicFindCommentEnd;

  procedure TestFindCommentEnd(Src: string;
    NestedComments: boolean; ExpectedEndPos: integer);
  var
    EndPos: Integer;
    p: PChar;
    EndP: PChar;
  begin
    EndPos:=FindCommentEnd(Src,1,NestedComments);
    AssertEquals('FindCommentEnd(string) '+dbgstr(Src),ExpectedEndPos,EndPos);
    p:=PChar(Src);
    EndP:=FindCommentEnd(p,NestedComments);
    EndPos:=EndP-PChar(Src)+1;
    AssertEquals('FindCommentEnd(pchar) '+dbgstr(Src),ExpectedEndPos,EndPos);
  end;

begin
  TestFindCommentEnd(' ',false,1);
  TestFindCommentEnd('{}',false,3);
  TestFindCommentEnd('(**)',false,5);
  TestFindCommentEnd('(*)',false,4);
  TestFindCommentEnd('{{}}',false,4);
  TestFindCommentEnd('{{}}',true,5);
  TestFindCommentEnd('{'#3#3'}',false,5);
  TestFindCommentEnd('{'#3'}'#3'}',false,6);
  TestFindCommentEnd('//',false,3);
end;

procedure TTestBasicCodeTools.TestBasicFindNextComment;

  procedure TestFindNextComment(Src: string; ExpectedPos: integer);
  var
    StartPos: Integer;
  begin
    StartPos:=FindNextComment(Src,1);
    AssertEquals('FindNextComment '+dbgstr(Src),ExpectedPos,StartPos);
  end;

begin
  TestFindNextComment('{',1);
  TestFindNextComment('//',1);
  TestFindNextComment('(*',1);
  TestFindNextComment('(',2);
  TestFindNextComment('/',2);
end;

procedure TTestBasicCodeTools.TestCompareTextIgnoringSpace;

  procedure t(Txt1, Txt2: string; Expected: integer; CaseSensitive: boolean = false);
  var
    r: Integer;
  begin
    r:=CompareTextIgnoringSpace(Txt1,Txt2,CaseSensitive);
    AssertEquals('Txt1="'+dbgstr(Txt1)+'",Txt2="'+dbgstr(Txt2)+'"',Expected,r);
  end;

begin
  t('a','a',0);
  t('a','A',0);
  t('a',' a',0);
  t(' a','a',0);
  t(' a','a ',0);
  t(' a: b','a:b',0);
  t('procedure TCustomSynEdit.LineCountChanged(Sender: TSynEditStrings; AIndex,'#13#10'  ACount: Integer); ',
    'procedure TCustomSynEdit.LineCountChanged(Sender: TSynEditStrings; AIndex, ACount: Integer);',0);
end;

procedure TTestBasicCodeTools.TestGuessIndentSize;

  procedure t(Src: string; ExpectedIndent: integer; DefaultIndent: integer = 2; TabWidth: integer = 2);
  var
    ActualIndent: Integer;
  begin
    ActualIndent:=DefaultIndent;
    GuessIndentSize(Src,ActualIndent,TabWidth);
    if ActualIndent=ExpectedIndent then exit;
    AssertEquals('"'+DbgStr(Src)+'"',ExpectedIndent,ActualIndent);
  end;

begin
  t('',2,2);
  t(' a',1);
  t('  a',2);
  t('   a',3);
  t('  a'#10'b',2);
  t('  a'#10#13'  b',2);
  t('  a'#10'    b'#10'  c',2);
end;

procedure TTestBasicCodeTools.TestReIndent;

  procedure t(Src: string; OldIndent,OldTabWidth, NewIndentStep, NewTabWidth: integer; ExpectedSrc: string);
  var
    ActualSrc: String;
  begin
    ActualSrc:=ReIndent(Src,OldIndent,OldTabWidth, NewIndentStep, NewTabWidth);
    if ExpectedSrc=ActualSrc then exit;
    writeln(dbgsDiff(ExpectedSrc,ActualSrc));
    AssertEquals('"'+DbgStr(Src)+'"',true,false);
  end;

begin
  t('',2,4, 4,4,'');
  t('A',2,4, 4,4,'A');
  t(' A',2,4, 4,4,#9'A');
  t('  A',2,4, 4,4,#9'A');
  t('   A',2,4, 4,4,#9#9'A');
  t('    A',2,4, 4,4,#9#9'A');
  t('     A',2,4, 4,4,#9#9#9'A');
  t('      A',2,4, 4,4,#9#9#9'A');
  t(#9'A',4,4, 2,0,'  A');
  t('A'#10'  B'#10,2,4, 3,0,'A'#10'   B'#10);
end;

procedure TTestBasicCodeTools.TestSimpleFormat;

  procedure t(const Fmt: string; Args: array of const; const Expected: string);
  var
    Actual: String;
  begin
    Actual:=SimpleFormat(Fmt,Args);
    if Expected=Actual then exit;
    writeln(dbgsDiff(Expected,Actual));
    AssertEquals('"'+DbgStr(Fmt)+'"('+dbgs(High(Args)-Low(Args)+1)+')',true,false);
  end;

begin
  t('A',['Foo'],'A,Foo');
  t('A%sB',['Foo'],'AFooB');
  t('A%sB%sC',['Foo'],'AFooB%sC');
  t('A%sB',['Foo','Bar'],'AFooB,Bar');
  t('A%0B',['Foo','Bar'],'AFooB,Bar');
  t('A%1B',['Foo','Bar'],'ABarB,Foo');
  t('A%1%0B',['Foo','Bar'],'ABarFooB');
  t('A%1:s%0:sB',['Foo','Bar'],'ABarFooB');
end;

procedure TTestBasicCodeTools.TestDateToCfgStr;

  procedure t(const Date: TDateTime; const aFormat, Expected: string);
  var
    Actual: String;
    ActualDate: TDateTime;
  begin
    Actual:=DateToCfgStr(Date,aFormat);
    if Actual<>Expected then begin
      writeln(dbgsDiff(Expected,Actual));
      AssertEquals('DateToCfgStr failed: Format="'+aFormat+'"',Expected,Actual);
      exit;
    end;
    if (not CfgStrToDate(Actual,ActualDate,aFormat)) then begin
      AssertEquals('CfgStrToDate failed: Format="'+aFormat+'" Cfg="'+Actual+'"',false,true);
      exit;
    end;
    if ActualDate<>Date then begin
      AssertEquals('CfgStrToDate failed: Format="'+aFormat+'"',DateTimeToStr(ActualDate),DateTimeToStr(Date));
    end;
  end;

begin
  t(EncodeDate(1234,12,17),DateAsCfgStrFormat,'12341217');
  t(EncodeDate(1234,1,2),DateAsCfgStrFormat,'12340102');
  t(ComposeDateTime(EncodeDate(1234,1,2),EncodeTime(3,4,5,6)),DateTimeAsCfgStrFormat,'1234/01/02 03:04:05');
end;

procedure TTestBasicCodeTools.TestFilenameIsMatching;

  procedure t(aMask,aFilename: string; aExactly,Expected: boolean);
  var
    Actual: Boolean;
  begin
    Actual:=FilenameIsMatching(aMask,aFilename,aExactly);
    if Actual=Expected then exit;
    AssertEquals('Mask="'+aMask+'" File="'+aFilename+'" Exactly='+dbgs(aExactly),Expected,Actual);
  end;

begin
  //  /abc           matches /abc, /abc/, /abc/p, /abc/xyz/filename
  //                 but not /abcd
  t('/abc','/abc',true,true);
  t('/abc','/abc',false,true);
  t('/abc','/abc/',true,true);
  t('/abc','/abc/',false,true);
  t('/abc','/abc/p',true,false);
  t('/abc','/abc/p',false,true);
  t('/abc','/abc/xyz/filename',false,true);
  t('/abc','/abc/xyz/filename',true,false);
  t('/abc','/abcd',true,false);
  t('/abc','/abcd',false,false);

  //  /abc/            matches /abc, /abc/, /abc//, but not /abc/.
  t('/abc/','/abc',true,true);
  t('/abc/','/abc',false,true);
  t('/abc/','/abc/',true,true);
  t('/abc/','/abc/',false,true);
  t('/abc/','/abc//',true,true);
  t('/abc/','/abc//',false,true);
  t('/abc/','/abc/.',true,false);
  t('/abc/','/abc/.',false,true);
  t('/abc/','/abc/d',true,false);
  t('/abc/','/abc/d',false,true);

  //  /abc/x?z/www   matches /abc/xyz/www, /abc/xaz/www
  //                 but not /abc/x/z/www
  t('/abc/x?z/www','/abc/xyz/www',true,true);
  t('/abc/x?z/www','/abc/xyz/www',false,true);
  t('/abc/x?z/www','/abc/xaz/www',true,true);
  t('/abc/x?z/www','/abc/x/z/www',true,false);
  t('/abc/x?z/www','/abc/x/z/www',false,false);

  //  /abc/x*z/www   matches /abc/xz/www, /abc/xyz/www, /abc/xAAAz/www
  //                 but not /abc/x/z/www
  t('/abc/x*z/www','/abc/xz/www',true,true);
  t('/abc/x*z/www','/abc/xz/www',false,true);
  t('/abc/x*z/www','/abc/xyz/www',true,true);
  t('/abc/x*z/www','/abc/xyz/www',false,true);
  t('/abc/x*z/www','/abc/xAAAz/www',true,true);
  t('/abc/x*z/www','/abc/xAAAz/www',false,true);
  t('/abc/x*z/www','/abc/x/z/www',true,false);
  t('/abc/x*z/www','/abc/x/z/www',false,false);

  //  /abc/x#*z/www  matches /abc/x*z/www, /abc/x*z/www/ttt
  t('/abc/x#*z/www','/abc/x*z/www',true,true);
  t('/abc/x#*z/www','/abc/x*z/www',false,true);
  t('/abc/x#*z/www','/abc/x*z/www/ttt',true,false);
  t('/abc/x#*z/www','/abc/x*z/www/ttt',false,true);

  //  /a{b,c,d}e     matches /abe, /ace, /ade, but not /aze
  t('/a{b,c,d}e','/abe',true,true);
  t('/a{b,c,d}e','/abe',false,true);
  t('/a{b,c,d}e','/ace',true,true);
  t('/a{b,c,d}e','/ace',false,true);
  t('/a{b,c,d}e','/ade',true,true);
  t('/a{b,c,d}e','/ade',false,true);
  t('/a{b,c,d}e','/aze',true,false);
  t('/a{b,c,d}e','/aze',false,false);

  // {*.pas,*.pp,*.p,*.inc,Makefile.fpc} matches math.pp
  t('{*.pas,*.pp,*.p,*.inc,Makefile.fpc}','math.pp',true,true);

  t('{*.pas}','Generics.Collections.pas',true,true);
  t('{*.pas,*.pp}','Generics.Collections.pas',true,true);
  t('{*.pas,*.pp,*.p}','Generics.Collections.pas',true,true);
  t('{*.pas,*.pp,*.p,*.inc}','Generics.Collections.pas',true,true);
  t('{*.pas,*.pp,*.p,*.inc,Makefile.fpc}','Generics.Collections.pas',true,true);

  // *{.p{as,p,}}   matches a.pas unit1.pp b.p but not b.inc
  t('*{.p{as,p,}}','a.pas',true,true);
  t('*{.p{as,p,}}','unit1.pp',true,true);
  t('*{.p{as,p,}}','b.p',true,true);
  t('*{.p{as,p,}}','b.inc',true,false);

  //  *.{p{as,p,},inc} matches a.pas unit1.pp b.p b.inc but not c.lfm
  t('*.{p{as,p,},inc}','a.pas',true,true);
  t('*.{p{as,p,},inc}','unit1.pp',true,true);
  t('*.{p{as,p,},inc}','b.p',true,true);
  t('*.{p{as,p,},inc}','b.inc',true,true);
  t('*.{p{as,p,},inc}','c.lfm',true,false);
end;

initialization
  AddToCodetoolsTestSuite(TTestBasicCodeTools);

end.


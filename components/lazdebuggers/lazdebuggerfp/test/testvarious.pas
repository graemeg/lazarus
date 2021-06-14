unit TestVarious;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, FpPascalBuilder, {$ifdef FORCE_LAZLOGGER_DUMMY} LazLoggerDummy {$else} LazLoggerBase {$endif}, TestOutputLogger, fpcunit,
  testutils, testregistry;

type

  { TTestVarious }

  TTestVarious = class(TTestCase)
  published
    procedure TestQuoteString;
  end;

implementation

procedure TTestVarious.TestQuoteString;
const
  N: array [0..9] of string = (
    #0, #1, 'a', '1', '''',
    'ä', // correct utf8
    #193, #225#129, #225, #129  // broken
  );
  E: array [0..9] of string = (
    '#$00', '#$01', 'a', '1', '''''',
    'ä',
    '#$C1', '#$E1#$81', '#$E1', '#$81'  // broken
  );

  Q='''';
var
  c: array [1..5] of integer;
  l, i: Integer;
  s1, s2: String;
  InQuote: Boolean;
begin
  AssertEquals(Q+Q,       QuoteText(''));
  AssertEquals(Q+'a'+Q,      QuoteText('a'));
  AssertEquals(Q+Q+Q+Q,     QuoteText(Q));
  AssertEquals('#$09',       QuoteText(#9));

  for l := 1 to 5 do begin
    for i := 1 to l do c[i] := 0;
    while true do begin
      s1 := '';
      s2 := '';
      InQuote := False;
      for i := 1 to l do begin
        s1 := s1 + N[c[i]]; // input
        if (E[c[i]][1] <> '#') xor InQuote then begin
          s2 := s2 + Q;
          InQuote := not InQuote;
        end;
        s2 := s2 + E[c[i]]; // expect
      end;
      if InQuote then
        s2 := s2 + Q;

      AssertEquals(s2, QuoteText(s1));

      // iterate all variations for length 1 - 5
      i := 1;
      while i <= l do begin
        if c[i] < 9 then begin
          inc(c[i]);
          // avoid combining 2 broken into one correct char
          if (c[i] in [6,7,8]) and (i < l) and (c[i+1] = 9) then
            c[i] := 9;
          break;
        end else begin
          c[i] := 0;
          inc(i);
        end;
      end;
      if i > l then
        break;
    end;
  end;

end;



initialization

  RegisterTest(TTestVarious);
end.


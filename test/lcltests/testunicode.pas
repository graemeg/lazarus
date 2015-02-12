unit TestUnicode;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpcunit, testglobals, LazUTF8, lazutf16, LazLogger;

type

  { TTestUnicode }

  TTestUnicode= class(TTestCase)
  published
    procedure TestUTF8ToUTF16;
    procedure TestUTF16ToUTF8;
    procedure TestUTF16ToUnicode;
    procedure TestUnicodeToUTF16;
    procedure TestUTF8CharacterToUnicode;
  end; 
  
const
  Limits: Array [0..9] of Cardinal =
    (0, $7F, $80, $7FF, $800, $D7FF, $E000, $FFFF, $10000, $10FFFF);

implementation

{ TTestUnicode }

procedure TTestUnicode.TestUTF8ToUTF16;
var
  U: Cardinal;
  I1, I2: Integer;
  SUTF8, S1UTF8: UTF8String;
  SUTF16, S1UTF16, R: WideString;
begin
  for U := 0 to $10FFFF do // test each unicode char
  begin
    if (U >= $D800) and (U <= $DFFF) then Continue;
    
    SUTF8 := UnicodeToUTF8(U);
    SUTF16 := UnicodeToUTF16(U);
    R := UTF8ToUTF16(SUTF8);

    AssertEquals('UTF8ToUTF16 of unicode char: ' + IntToHex(U, 6) + ' error! ' + DbgWideStr(SUTF16) + ' ' + DbgWideStr(R),
      SUTF16, R);
  end;
  
  for I1 := 0 to High(Limits) do // test two char string with limit char values
  begin
    S1UTF8 := UnicodeToUTF8(Limits[I1]);
    S1UTF16 := UnicodeToUTF16(Limits[I1]);
    
    for I2 := 0 to High(Limits) do
    begin
      SUTF8 := S1UTF8 + UnicodeToUTF8(Limits[I2]);
      SUTF16 := S1UTF16 + UnicodeToUTF16(Limits[I2]);
      R := UTF8ToUTF16(SUTF8);
      
      AssertEquals('UTF8ToUTF16 of two unicode chars: ' +
        IntToHex(Limits[I1], 6) + IntToHex(Limits[I2], 6) + ' error!',
        SUTF16, R);
    end;
  end;
end;

procedure TTestUnicode.TestUTF16ToUTF8;
var
  U: Cardinal;
  I1, I2: Integer;
  SUTF8, S1UTF8, R: UTF8String;
  SUTF16, S1UTF16: WideString;
begin
  for U := 0 to $10FFFF do
  begin
    if (U >= $D800) and (U <= $DFFF) then Continue;
    
    SUTF8 := UnicodeToUTF8(U);
    SUTF16 := UnicodeToUTF16(U);
    R := UTF16ToUTF8(SUTF16);

    AssertEquals('UTF16ToUTF8 of unicode char: ' + IntToHex(U, 6) + ' error! ' + DbgStr(SUTF16) + ' ' + DbgStr(R),
      SUTF8, R);
  end;
  
  for I1 := 0 to High(Limits) do
  begin
    S1UTF8 := UnicodeToUTF8(Limits[I1]);
    S1UTF16 := UnicodeToUTF16(Limits[I1]);

    for I2 := 0 to High(Limits) do
    begin
      SUTF8 := S1UTF8 + UnicodeToUTF8(Limits[I2]);
      SUTF16 := S1UTF16 + UnicodeToUTF16(Limits[I2]);
      R := UTF16ToUTF8(SUTF16);

      AssertEquals('UTF16ToUTF8 of two unicode chars: ' +
        IntToHex(Limits[I1], 6) + IntToHex(Limits[I2], 6) + ' error!',
        SUTF8, R);
    end;
  end;
end;

procedure TTestUnicode.TestUTF16ToUnicode;
var
  L: Integer;
begin
  AssertEquals(0, UTF16CharacterToUnicode(#0, L));
  AssertEquals($D7FF, UTF16CharacterToUnicode(#$D7FF, L));
  AssertEquals($E000, UTF16CharacterToUnicode(#$E000, L));
  AssertEquals($FFFF, UTF16CharacterToUnicode(#$FFFF, L));
  AssertEquals($10000, UTF16CharacterToUnicode(#$D800#$DC00, L));
  AssertEquals($10001, UTF16CharacterToUnicode(#$D800#$DC01, L));
  AssertEquals($10FFFD, UTF16CharacterToUnicode(#$DBFF#$DFFD, L));
end;

procedure TTestUnicode.TestUnicodeToUTF16;
begin
  AssertEquals(#0, UnicodeToUTF16(0));
  AssertEquals(#$D7FF, UnicodeToUTF16($D7FF));
  AssertEquals(#$E000, UnicodeToUTF16($E000));
  AssertEquals(#$FFFF, UnicodeToUTF16($FFFF));
  AssertEquals(#$D800#$DC00, UnicodeToUTF16($10000));
  AssertEquals(#$D800#$DC01, UnicodeToUTF16($10001));
  AssertEquals(#$DBFF#$DFFD, UnicodeToUTF16($10FFFD));
end;

procedure TTestUnicode.TestUTF8CharacterToUnicode;
var
  i,u: cardinal;
  s: String;
  dum: integer;
begin
  for i:=0 to $10FFFF do
  begin
    s:=UnicodeToUTF8(i);
    u:=UTF8CharacterToUnicode(PChar(s), dum);
    AssertEquals('got (hexidecimal): ' + InttoHex(u,6), i, u);
  end;
end;

initialization

  AddToLCLTestSuite(TTestUnicode);
end.


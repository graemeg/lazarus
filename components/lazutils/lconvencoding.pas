{
 *****************************************************************************
  This file is part of LazUtils.

  See the file COPYING.modifiedLGPL.txt, included in this distribution,
  for details about the license.
 *****************************************************************************

  Note:
    The functions of this unit are thread-safe.
}
unit LConvEncoding;

{$mode objfpc}{$H+}

{$i lazutils_defines.inc}

interface

{ $Define DisableAsianCodePages}
{$IFDEF UTF8_RTL}
  // Windows provides conversion functions.
  // Unix: unit cwstring provides conversion functions which are used by default UTF-8 encoding system.
  {$Define UseSystemCPConv} // use system conversions
{$ENDIF}
{$ifdef UseLCPConv}{$undef UseSystemCPConv}{$endif}

uses
  SysUtils, Classes, dos, LazUTF8, CodepagesCommon
  {$IFnDEF DisableAsianCodePages},CodepagesAsian{$ENDIF}
  {$IFDEF EnableIconvEnc},iconvenc{$ENDIF};

type
  TConvertEncodingErrorMode = (
    ceemSkip,
    ceemException,
    ceemReplace,
    ceemReturnEmpty
    );

var
  //Global variable which controls behaviour of encoding conversion error, in 3 places:
  //a) UTF8 to single byte encoding, b) DBCS (Asian) encoding to UTF8, c) UTF8 to DBCS
  ConvertEncodingErrorMode: TConvertEncodingErrorMode = ceemSkip;

//encoding names
const
  EncodingUTF8 = 'utf8';
  EncodingAnsi = 'ansi';
  EncodingUTF8BOM = 'utf8bom'; // UTF-8 with byte order mark
  EncodingUCS2LE = 'ucs2le'; // UCS 2 byte little endian
  EncodingUCS2BE = 'ucs2be'; // UCS 2 byte big endian

  EncodingCP1250 = 'cp1250';
  EncodingCP1251 = 'cp1251';
  EncodingCP1252 = 'cp1252';
  EncodingCP1253 = 'cp1253';
  EncodingCP1254 = 'cp1254';
  EncodingCP1255 = 'cp1255';
  EncodingCP1256 = 'cp1256';
  EncodingCP1257 = 'cp1257';
  EncodingCP1258 = 'cp1258';

  EncodingCP437 = 'cp437';
  EncodingCP850 = 'cp850';
  EncodingCP852 = 'cp852';
  EncodingCP866 = 'cp866';
  EncodingCP874 = 'cp874';

  EncodingCP932 = 'cp932';
  EncodingCP936 = 'cp936';
  EncodingCP949 = 'cp949';
  EncodingCP950 = 'cp950';

  EncodingCPMac = 'macintosh';
  EncodingCPKOI8R = 'koi8r';
  EncodingCPKOI8U = 'koi8u';
  EncodingCPKOI8RU = 'koi8ru';

  EncodingCPIso1 = 'iso88591';
  EncodingCPIso2 = 'iso88592';
  EncodingCPIso15 = 'iso885915';

//signatures in ansi
const
  UTF8BOM = #$EF#$BB#$BF;
  UTF16BEBOM = #$FE#$FF;
  UTF16LEBOM = #$FF#$FE;
  UTF32BEBOM = #0#0#$FE#$FF;
  UTF32LEBOM = #$FE#$FF#0#0;

function GuessEncoding(const s: string): string;

function ConvertEncodingFromUTF8(const s, ToEncoding: string; out Encoded: boolean
  {$ifdef FPC_HAS_CPSTRING}; SetTargetCodePage: boolean = false{$endif}): string;
function ConvertEncodingToUTF8(const s, FromEncoding: string; out Encoded: boolean): string;
// For UTF8 use the above functions, they save you one parameter
function ConvertEncoding(const s, FromEncoding, ToEncoding: string
  {$ifdef FPC_HAS_CPSTRING}; SetTargetCodePage: boolean = false{$endif}): string;

// This routine should obtain the encoding utilized by ansistring in the RTL
function GetDefaultTextEncoding: string;
// This routine returns the console text encoding, which might be different
// from the normal system encoding in some Windows systems
// see http://mantis.freepascal.org/view.php?id=20552
function GetConsoleTextEncoding: string;
function NormalizeEncoding(const Encoding: string): string;

type
  TConvertEncodingFunction = function(const s: string): string;
  {$ifdef FPC_HAS_CPSTRING}
  TConvertUTF8ToEncodingFunc = function(const s: string; SetTargetCodePage: boolean = false): RawByteString;
  {$else}
  TConvertUTF8ToEncodingFunc = function(const s: string): string;
  {$endif}
  TCharToUTF8Table = CodepagesCommon.TCharToUTF8Table;
  TUnicodeToCharID = function(Unicode: cardinal): integer;
var
  ConvertAnsiToUTF8: TConvertEncodingFunction = nil;
  ConvertUTF8ToAnsi: TConvertUTF8ToEncodingFunc = nil;

function UTF8BOMToUTF8(const s: string): string; // UTF8 with BOM
function ISO_8859_1ToUTF8(const s: string): string; // central europe
function ISO_8859_15ToUTF8(const s: string): string; // Western European languages
function ISO_8859_2ToUTF8(const s: string): string; // eastern europe
function CP1250ToUTF8(const s: string): string; // central europe
function CP1251ToUTF8(const s: string): string; // cyrillic
function CP1252ToUTF8(const s: string): string; // latin 1
function CP1253ToUTF8(const s: string): string; // greek
function CP1254ToUTF8(const s: string): string; // turkish
function CP1255ToUTF8(const s: string): string; // hebrew
function CP1256ToUTF8(const s: string): string; // arabic
function CP1257ToUTF8(const s: string): string; // baltic
function CP1258ToUTF8(const s: string): string; // vietnam
function CP437ToUTF8(const s: string): string;  // DOS central europe
function CP850ToUTF8(const s: string): string;  // DOS western europe
function CP852ToUTF8(const s: string): string;  // DOS central europe
function CP866ToUTF8(const s: string): string;  // DOS and Windows console's cyrillic
function CP874ToUTF8(const s: string): string;  // thai
function KOI8RToUTF8(const s: string): string;  // russian cyrillic
// Deprecated in Lazarus 2.2, 14.7.2021.
function KOI8ToUTF8(const s: string): string; deprecated 'Call KOI8RToUTF8 instead.';
function MacintoshToUTF8(const s: string): string;  // Macintosh, alias Mac OS Roman
function SingleByteToUTF8(const s: string; const Table: TCharToUTF8Table): string;
function UCS2LEToUTF8(const s: string): string; // UCS2-LE 2byte little endian
function UCS2BEToUTF8(const s: string): string; // UCS2-BE 2byte big endian

function UTF8ToUTF8BOM(const s: string): string; // UTF8 with BOM
{$ifdef FPC_HAS_CPSTRING}
function UTF8ToISO_8859_1(const s: string; SetTargetCodePage: boolean = false): RawByteString; // central europe
function UTF8ToISO_8859_2(const s: string; SetTargetCodePage: boolean = false): RawByteString; // eastern europe
function UTF8ToISO_8859_15(const s: string; SetTargetCodePage: boolean = false): RawByteString; // Western European languages
function UTF8ToCP1250(const s: string; SetTargetCodePage: boolean = false): RawByteString; // central europe
function UTF8ToCP1251(const s: string; SetTargetCodePage: boolean = false): RawByteString; // cyrillic
function UTF8ToCP1252(const s: string; SetTargetCodePage: boolean = false): RawByteString; // latin 1
function UTF8ToCP1253(const s: string; SetTargetCodePage: boolean = false): RawByteString; // greek
function UTF8ToCP1254(const s: string; SetTargetCodePage: boolean = false): RawByteString; // turkish
function UTF8ToCP1255(const s: string; SetTargetCodePage: boolean = false): RawByteString; // hebrew
function UTF8ToCP1256(const s: string; SetTargetCodePage: boolean = false): RawByteString; // arabic
function UTF8ToCP1257(const s: string; SetTargetCodePage: boolean = false): RawByteString; // baltic
function UTF8ToCP1258(const s: string; SetTargetCodePage: boolean = false): RawByteString; // vietnam
function UTF8ToCP437(const s: string; SetTargetCodePage: boolean = false): RawByteString;  // DOS central europe
function UTF8ToCP850(const s: string; SetTargetCodePage: boolean = false): RawByteString;  // DOS western europe
function UTF8ToCP852(const s: string; SetTargetCodePage: boolean = false): RawByteString;  // DOS central europe
function UTF8ToCP866(const s: string; SetTargetCodePage: boolean = false): RawByteString;  // DOS and Windows console's cyrillic
function UTF8ToCP874(const s: string; SetTargetCodePage: boolean = false): RawByteString;  // thai
function UTF8ToKOI8R(const s: string; SetTargetCodePage: boolean = false): RawByteString;  // russian cyrillic
function UTF8ToKOI8U(const s: string; SetTargetCodePage: boolean = false): RawByteString;  // ukrainian cyrillic
function UTF8ToKOI8RU(const s: string; SetTargetCodePage: boolean = false): RawByteString;  // belarussian cyrillic
function UTF8ToMacintosh(const s: string; SetTargetCodePage: boolean = false): RawByteString;  // Macintosh, alias Mac OS Roman
{$ELSE}
function UTF8ToISO_8859_1(const s: string): string; // central europe
function UTF8ToISO_8859_15(const s: string): string; // Western European languages
function UTF8ToISO_8859_2(const s: string): string; // eastern europe
function UTF8ToCP1250(const s: string): string; // central europe
function UTF8ToCP1251(const s: string): string; // cyrillic
function UTF8ToCP1252(const s: string): string; // latin 1
function UTF8ToCP1253(const s: string): string; // greek
function UTF8ToCP1254(const s: string): string; // turkish
function UTF8ToCP1255(const s: string): string; // hebrew
function UTF8ToCP1256(const s: string): string; // arabic
function UTF8ToCP1257(const s: string): string; // baltic
function UTF8ToCP1258(const s: string): string; // vietnam
function UTF8ToCP437(const s: string): string;  // DOS central europe
function UTF8ToCP850(const s: string): string;  // DOS western europe
function UTF8ToCP852(const s: string): string;  // DOS central europe
function UTF8ToCP866(const s: string): string;  // DOS and Windows console's cyrillic
function UTF8ToCP874(const s: string): string;  // thai
function UTF8ToKOI8R(const s: string): string;  // russian cyrillic
function UTF8ToKOI8U(const s: string): string;  // ukrainian cyrillic
function UTF8ToKOI8RU(const s: string): string;  // belarussian cyrillic
function UTF8ToMacintosh(const s: string): string;  // Macintosh, alias Mac OS Roman
{$ENDIF}
// custom conversion
function UTF8ToSingleByte(const s: string; const UTF8CharConvFunc: TUnicodeToCharID): string;

function UTF8ToUCS2LE(const s: string): string; // UCS2-LE 2byte little endian without BOM
function UTF8ToUCS2BE(const s: string): string; // UCS2-BE 2byte big endian without BOM

{$IFnDEF DisableAsianCodePages}
// Asian encodings
function CP932ToUTF8(const s: string): string;      // Japanese
function CP936ToUTF8(const s: string): string;      // Chinese
function CP949ToUTF8(const s: string): string;      // Korea
function CP950ToUTF8(const s: string): string;      // Chinese Complex

{$ifdef FPC_HAS_CPSTRING}
function UTF8ToCP932(const s: string; SetTargetCodePage: boolean = false): RawByteString; // Japanese
function UTF8ToCP936(const s: string; SetTargetCodePage: boolean = false): RawByteString; // Chinese, essentially the same as GB 2312 and a predecessor to GB 18030
function UTF8ToCP949(const s: string; SetTargetCodePage: boolean = false): RawByteString; // Korea
function UTF8ToCP950(const s: string; SetTargetCodePage: boolean = false): RawByteString; // Chinese Complex
{$ELSE}
function UTF8ToCP932(const s: string): string;      // Japanese
function UTF8ToCP936(const s: string): string;      // Chinese, essentially the same as GB 2312 and a predecessor to GB 18030
function UTF8ToCP949(const s: string): string;      // Korea
function UTF8ToCP950(const s: string): string;      // Chinese Complex
{$ENDIF}
// Common function used by all UTF8ToXXX functions.
function UTF8ToDBCS(const s: string; const UTF8CharConvFunc: TUnicodeToCharID): string;
{$ENDIF}

procedure GetSupportedEncodings(List: TStrings);

implementation

{$IFDEF Windows}
uses Windows;
{$ENDIF}

var
  EncodingValid: boolean = false;
  DefaultTextEncoding: string = EncodingAnsi;

function SearchTable(CodePageArr: array of word; id: cardinal): word;
var
  idMid: integer;
  idLow, idHigh: integer;
begin
  idLow  := 0;
  idHigh := High(CodePageArr);
  while (idLow <= idHigh) do
  begin
    if idLow = idHigh then
    begin
      if CodePageArr[idLow] = id then
      begin
        Result := idLow;
      end
      else
      begin
        Result := 0;
      end;
      Exit;
    end;
    idMid := (idLow + idHigh) div 2;
    if CodePageArr[idMid] = id then
    begin
      Result := idMid;
      Exit;
    end;
    if CodePageArr[idMid] > id then
      idHigh := idMid - 1;
    if CodePageArr[idMid] < id then
      idLow := idMid + 1;
  end;
  Result := 0;
end;

{$IFnDEF DisableAsianCodePages}
{$include asiancodepagefunctions.inc}
{$ENDIF}

{$IFDEF Windows}
// AConsole - If false, it is the general system encoding,
//            if true, it is the console encoding
function GetWindowsEncoding(AConsole: Boolean = False): string;
var
  cp : UINT;
{$IFDEF WinCE}
// CP_UTF8 is missing in the windows unit of the Windows CE RTL
const
  CP_UTF8 = 65001;
{$ENDIF}
begin
  if AConsole then cp := GetOEMCP
  else cp := GetACP;

  case cp of
    CP_UTF8: Result := EncodingUTF8;
  else
    Result:='cp'+IntToStr(cp);
  end;
end;
{$ELSE}
{$IFNDEF Darwin}
function GetUnixEncoding: string;
var
  Lang: string;
  i: integer;
begin
  Result:=EncodingAnsi;

  lang := GetEnv('LC_ALL');
  if Length(lang) = 0 then
  begin
    lang := GetEnv('LC_MESSAGES');
    if Length(lang) = 0 then
    begin
      lang := GetEnv('LANG');
    end;
  end;
  i:=pos('.',Lang);
  if (i>0) and (i<=length(Lang)) then
    Result:=copy(Lang,i+1,length(Lang)-i);
end;
{$ENDIF}
{$ENDIF}

function GetDefaultTextEncoding: string;
begin
  if EncodingValid then begin
    Result:=DefaultTextEncoding;
    exit;
  end;

  {$IFDEF Windows}
  Result:=GetWindowsEncoding;
  {$ELSE}
  {$IFDEF Darwin}
  Result:=EncodingUTF8;
  {$ELSE}
  Result:=GetUnixEncoding;
  {$ENDIF}
  {$ENDIF}

  Result:=NormalizeEncoding(Result);

  DefaultTextEncoding:=Result;
  EncodingValid:=true;
end;

function GetConsoleTextEncoding: string;
begin
  {$ifdef Windows}
  Result:=GetWindowsEncoding(True);
  Result:=NormalizeEncoding(Result);
  {$else}
  Result := GetDefaultTextEncoding;
  {$endif}
end;

function NormalizeEncoding(const Encoding: string): string;
var
  i: Integer;
begin
  Result:=LowerCase(Encoding);
  for i:=length(Result) downto 1 do
    if Result[i]='-' then System.Delete(Result,i,1);
end;

function UTF8BOMToUTF8(const s: string): string;
begin
  if s='' then exit('');
  if CompareMem(@UTF8BOM[1],@s[1],length(UTF8BOM)) then
    Result:=copy(s,4,length(s))
  else
    Result:=s;
end;

function ISO_8859_1ToUTF8(const s: string): string;
begin
  Result:=SingleByteToUTF8(s,ArrayISO_8859_1ToUTF8);
end;

function ISO_8859_15ToUTF8(const s: string): string;
begin
  Result:=SingleByteToUTF8(s,ArrayISO_8859_15ToUTF8);
end;

function ISO_8859_2ToUTF8(const s: string): string;
begin
  Result:=SingleByteToUTF8(s,ArrayISO_8859_2ToUTF8);
end;

function CP1250ToUTF8(const s: string): string;
begin
  Result:=SingleByteToUTF8(s,ArrayCP1250ToUTF8);
end;

function CP1251ToUTF8(const s: string): string;
begin
  Result:=SingleByteToUTF8(s,ArrayCP1251ToUTF8);
end;

function CP1252ToUTF8(const s: string): string;
begin
  Result:=SingleByteToUTF8(s,ArrayCP1252ToUTF8);
end;

function CP1253ToUTF8(const s: string): string;
begin
  Result:=SingleByteToUTF8(s,ArrayCP1253ToUTF8);
end;

function CP1254ToUTF8(const s: string): string;
begin
  Result:=SingleByteToUTF8(s,ArrayCP1254ToUTF8);
end;

function CP1255ToUTF8(const s: string): string;
begin
  Result:=SingleByteToUTF8(s,ArrayCP1255ToUTF8);
end;

function CP1256ToUTF8(const s: string): string;
begin
  Result:=SingleByteToUTF8(s,ArrayCP1256ToUTF8);
end;

function CP1257ToUTF8(const s: string): string;
begin
  Result:=SingleByteToUTF8(s,ArrayCP1257ToUTF8);
end;

function CP1258ToUTF8(const s: string): string;
begin
  Result:=SingleByteToUTF8(s,ArrayCP1258ToUTF8);
end;

function CP437ToUTF8(const s: string): string;
begin
  Result:=SingleByteToUTF8(s,ArrayCP437ToUTF8);
end;

function CP850ToUTF8(const s: string): string;
begin
  Result:=SingleByteToUTF8(s,ArrayCP850ToUTF8);
end;

function CP852ToUTF8(const s: string): string;
begin
  Result:=SingleByteToUTF8(s,ArrayCP852ToUTF8);
end;

function CP866ToUTF8(const s: string): string;
begin
  Result:=SingleByteToUTF8(s,ArrayCP866ToUTF8);
end;

function CP874ToUTF8(const s: string): string;
begin
  Result:=SingleByteToUTF8(s,ArrayCP874ToUTF8);
end;

function KOI8RToUTF8(const s: string): string;
begin
  Result:=SingleByteToUTF8(s,ArrayKOI8RToUTF8);
end;

function KOI8UToUTF8(const s: string): string;
begin
  Result:=SingleByteToUTF8(s,ArrayKOI8UToUTF8);
end;

function KOI8RUToUTF8(const s: string): string;
begin
  Result:=SingleByteToUTF8(s,ArrayKOI8RUToUTF8);
end;

function KOI8ToUTF8(const s: string): string;
begin
 Result:=KOI8RUToUTF8(s);
end;

function MacintoshToUTF8(const s: string): string;
begin
  Result:=SingleByteToUTF8(s,ArrayMacintoshToUTF8);
end;

function SingleByteToUTF8(const s: string; const Table: TCharToUTF8Table): string;
var
  len: Integer;
  i: Integer;
  Src: PChar;
  Dest: PChar;
  p: PChar;
  c: Char;
begin
  if s='' then exit('');
  len:=length(s);
  SetLength(Result,len*4);// UTF-8 is at most 4 bytes
  Src:=PChar(s);
  Dest:=PChar(Result);
  for i:=1 to len do begin
    c:=Src^;
    inc(Src);
    if ord(c)<128 then begin
      Dest^:=c;
      inc(Dest);
    end else begin
      p:=Table[c];
      if p<>nil then begin
        while p^<>#0 do begin
          Dest^:=p^;
          inc(p);
          inc(Dest);
        end;
      end;
    end;
  end;
  SetLength(Result,{%H-}PtrUInt(Dest)-PtrUInt(Result));
end;

function UCS2LEToUTF8(const s: string): string;
var
  len: Integer;
  Src: PWord;
  Dest: PChar;
  i: Integer;
  c: Word;
begin
  len:=length(s) div 2;
  if len=0 then
    exit('');
  SetLength(Result,len*3);// UTF-8 is at most 3/2 times the size
  Src:=PWord(Pointer(s));
  Dest:=PChar(Result);
  for i:=1 to len do begin
    c:=LEtoN(Src^);
    inc(Src);
    if ord(c)<128 then begin
      Dest^:=chr(c);
      inc(Dest);
    end else begin
      inc(Dest,UnicodeToUTF8SkipErrors(c,Dest));
    end;
  end;
  len:={%H-}PtrUInt(Dest)-PtrUInt(Result);
  if len>length(Result) then
    raise Exception.Create('');
  SetLength(Result,len);
end;

function UCS2BEToUTF8(const s: string): string;
var
  len: Integer;
  Src: PWord;
  Dest: PChar;
  i: Integer;
  c: Word;
begin
  len:=length(s) div 2;
  if len=0 then
    exit('');
  SetLength(Result,len*3);// UTF-8 is at most three times the size
  Src:=PWord(Pointer(s));
  Dest:=PChar(Result);
  for i:=1 to len do begin
    c:=BEtoN(Src^);
    inc(Src);
    if ord(c)<128 then begin
      Dest^:=chr(c);
      inc(Dest);
    end else begin
      inc(Dest,UnicodeToUTF8SkipErrors(c,Dest));
    end;
  end;
  len:={%H-}PtrUInt(Dest)-PtrUInt(Result);
  if len>length(Result) then
    raise Exception.Create('');
  SetLength(Result,len);
end;

function UTF8ToUTF8BOM(const s: string): string;
begin
  Result:=UTF8BOM+s;
end;

{$IfNdef UseSystemCPConv}
function UnicodeToCP1256(Unicode: cardinal): integer;
begin
  case Unicode of
  0..127: Result:=Unicode;
  160: Result:=160;
  162..169: Result:=Unicode;
  171..185: Result:=Unicode;
  187..190: Result:=Unicode;
  215: Result:=215;
  224: Result:=224;
  226: Result:=226;
  231..235: Result:=Unicode;
  238..239: Result:=Unicode;
  244: Result:=244;
  247: Result:=247;
  249: Result:=249;
  251..252: Result:=Unicode;
  338: Result:=140;
  339: Result:=156;
  402: Result:=131;
  710: Result:=136;
  1548: Result:=161;
  1563: Result:=186;
  1567: Result:=191;
  1569..1590: Result:=Unicode-1376;
  1591..1594: Result:=Unicode-1375;
  1600..1603: Result:=Unicode-1380;
  1604: Result:=225;
  1605..1608: Result:=Unicode-1378;
  1609..1610: Result:=Unicode-1373;
  1611..1614: Result:=Unicode-1371;
  1615..1616: Result:=Unicode-1370;
  1617: Result:=248;
  1618: Result:=250;
  1657: Result:=138;
  1662: Result:=129;
  1670: Result:=141;
  1672: Result:=143;
  1681: Result:=154;
  1688: Result:=142;
  1705: Result:=152;
  1711: Result:=144;
  1722: Result:=159;
  1726: Result:=170;
  1729: Result:=192;
  1746: Result:=255;
  8204..8205: Result:=Unicode-8047;
  8206..8207: Result:=Unicode-7953;
  8211..8212: Result:=Unicode-8061;
  8216..8217: Result:=Unicode-8071;
  8218: Result:=130;
  8220..8221: Result:=Unicode-8073;
  8222: Result:=132;
  8224..8225: Result:=Unicode-8090;
  8226: Result:=149;
  8230: Result:=133;
  8240: Result:=137;
  8249: Result:=139;
  8250: Result:=155;
  8364: Result:=128;
  8482: Result:=153;
  else Result:=-1;
  end;
end;

function UnicodeToCP437(Unicode: cardinal): integer;
begin
  case Unicode of
  0..127: Result:=Unicode;
  160: Result:=255;
  161: Result:=173;
  162..163: Result:=Unicode-7;
  165: Result:=157;
  170: Result:=166;
  171: Result:=174;
  172: Result:=170;
  176: Result:=248;
  177: Result:=241;
  178: Result:=253;
  181: Result:=230;
  183: Result:=250;
  186: Result:=167;
  187: Result:=175;
  188: Result:=172;
  189: Result:=171;
  191: Result:=168;
  196..197: Result:=Unicode-54;
  198: Result:=146;
  199: Result:=128;
  201: Result:=144;
  209: Result:=165;
  214: Result:=153;
  220: Result:=154;
  223: Result:=225;
  224: Result:=133;
  225: Result:=160;
  226: Result:=131;
  228: Result:=132;
  229: Result:=134;
  230: Result:=145;
  231: Result:=135;
  232: Result:=138;
  233: Result:=130;
  234..235: Result:=Unicode-98;
  236: Result:=141;
  237: Result:=161;
  238: Result:=140;
  239: Result:=139;
  241: Result:=164;
  242: Result:=149;
  243: Result:=162;
  244: Result:=147;
  246: Result:=148;
  247: Result:=246;
  249: Result:=151;
  250: Result:=163;
  251: Result:=150;
  252: Result:=129;
  255: Result:=152;
  262: Result := 93;
  263: Result := 125;
  268: Result := 94;
  269: Result := 126;
  272: Result := 92;
  273: Result := 124;
  381: Result := 64;
  382: Result := 96;
  352: Result := 91;
  353: Result := 123;
  402: Result:=159;
  915: Result:=226;
  920: Result:=233;
  931: Result:=228;
  934: Result:=232;
  937: Result:=234;
  945: Result:=224;
  948: Result:=235;
  949: Result:=238;
  960: Result:=227;
  963: Result:=229;
  964: Result:=231;
  966: Result:=237;
  8319: Result:=252;
  8359: Result:=158;
  8729: Result:=249;
  8730: Result:=251;
  8734: Result:=236;
  8745: Result:=239;
  8776: Result:=247;
  8801: Result:=240;
  8804: Result:=243;
  8805: Result:=242;
  8976: Result:=169;
  8992..8993: Result:=Unicode-8748;
  9472: Result:=196;
  9474: Result:=179;
  9484: Result:=218;
  9488: Result:=191;
  9492: Result:=192;
  9496: Result:=217;
  9500: Result:=195;
  9508: Result:=180;
  9516: Result:=194;
  9524: Result:=193;
  9532: Result:=197;
  9552: Result:=205;
  9553: Result:=186;
  9554..9555: Result:=Unicode-9341;
  9556: Result:=201;
  9557: Result:=184;
  9558: Result:=183;
  9559: Result:=187;
  9560: Result:=212;
  9561: Result:=211;
  9562: Result:=200;
  9563: Result:=190;
  9564: Result:=189;
  9565: Result:=188;
  9566..9567: Result:=Unicode-9368;
  9568: Result:=204;
  9569..9570: Result:=Unicode-9388;
  9571: Result:=185;
  9572..9573: Result:=Unicode-9363;
  9574: Result:=203;
  9575..9576: Result:=Unicode-9368;
  9577: Result:=202;
  9578: Result:=216;
  9579: Result:=215;
  9580: Result:=206;
  9600: Result:=223;
  9604: Result:=220;
  9608: Result:=219;
  9612: Result:=221;
  9616: Result:=222;
  9617..9619: Result:=Unicode-9441;
  9632: Result:=254;
  else Result:=-1;
  end;
end;

function UnicodeToCP850(Unicode: cardinal): integer;
begin
  case Unicode of
  0..127: Result:=Unicode;
  160: Result:=255;
  161: Result:=173;
  162: Result:=189;
  163: Result:=156;
  164: Result:=207;
  165: Result:=190;
  166: Result:=221;
  167: Result:=245;
  168: Result:=249;
  169: Result:=184;
  170: Result:=166;
  171: Result:=174;
  172: Result:=170;
  173: Result:=240;
  174: Result:=169;
  175: Result:=238;
  176: Result:=248;
  177: Result:=241;
  178: Result:=253;
  179: Result:=252;
  180: Result:=239;
  181: Result:=230;
  182: Result:=244;
  183: Result:=250;
  184: Result:=247;
  185: Result:=251;
  186: Result:=167;
  187: Result:=175;
  188: Result:=172;
  189: Result:=171;
  190: Result:=243;
  191: Result:=168;
  192: Result:=183;
  193..194: Result:=Unicode-12;
  195: Result:=199;
  196..197: Result:=Unicode-54;
  198: Result:=146;
  199: Result:=128;
  200: Result:=212;
  201: Result:=144;
  202..203: Result:=Unicode+8;
  204: Result:=222;
  205..207: Result:=Unicode+9;
  208: Result:=209;
  209: Result:=165;
  210: Result:=227;
  211: Result:=224;
  212: Result:=226;
  213: Result:=229;
  214: Result:=153;
  215: Result:=158;
  216: Result:=157;
  217: Result:=235;
  218..219: Result:=Unicode+15;
  220: Result:=154;
  221: Result:=237;
  222: Result:=232;
  223: Result:=225;
  224: Result:=133;
  225: Result:=160;
  226: Result:=131;
  227: Result:=198;
  228: Result:=132;
  229: Result:=134;
  230: Result:=145;
  231: Result:=135;
  232: Result:=138;
  233: Result:=130;
  234..235: Result:=Unicode-98;
  236: Result:=141;
  237: Result:=161;
  238: Result:=140;
  239: Result:=139;
  240: Result:=208;
  241: Result:=164;
  242: Result:=149;
  243: Result:=162;
  244: Result:=147;
  245: Result:=228;
  246: Result:=148;
  247: Result:=246;
  248: Result:=155;
  249: Result:=151;
  250: Result:=163;
  251: Result:=150;
  252: Result:=129;
  253: Result:=236;
  254: Result:=231;
  255: Result:=152;
  305: Result:=213;
  402: Result:=159;
  8215: Result:=242;
  9472: Result:=196;
  9474: Result:=179;
  9484: Result:=218;
  9488: Result:=191;
  9492: Result:=192;
  9496: Result:=217;
  9500: Result:=195;
  9508: Result:=180;
  9516: Result:=194;
  9524: Result:=193;
  9532: Result:=197;
  9552: Result:=205;
  9553: Result:=186;
  9556: Result:=201;
  9559: Result:=187;
  9562: Result:=200;
  9565: Result:=188;
  9568: Result:=204;
  9571: Result:=185;
  9574: Result:=203;
  9577: Result:=202;
  9580: Result:=206;
  9600: Result:=223;
  9604: Result:=220;
  9608: Result:=219;
  9617..9619: Result:=Unicode-9441;
  9632: Result:=254;
  else Result:=-1;
  end;
end;

// ftp://ftp.unicode.org/Public/MAPPINGS/VENDORS/MICSFT/PC/CP852.TXT
function UnicodeToCP852(Unicode: cardinal): integer;
begin
  case Unicode of
  0..127: Result:=Unicode;
  160: Result:=255;
  164: Result:=207;
  167: Result:=245;
  168: Result:=249;
  171: Result:=174;
  172: Result:=170;
  173: Result:=240;
  176: Result:=248;
  180: Result:=239;
  184: Result:=247;
  187: Result:=175;
  193..194: Result:=Unicode-12;
  196: Result:=142;
  199: Result:=128;
  201: Result:=144;
  203: Result:=211;
  205..206: Result:=Unicode+9;
  211: Result:=224;
  212: Result:=226;
  214: Result:=153;
  215: Result:=158;
  218: Result:=233;
  220: Result:=154;
  221: Result:=237;
  223: Result:=225;
  225: Result:=160;
  226: Result:=131;
  228: Result:=132;
  231: Result:=135;
  233: Result:=130;
  235: Result:=137;
  237: Result:=161;
  238: Result:=140;
  243: Result:=162;
  244: Result:=147;
  246: Result:=148;
  247: Result:=246;
  250: Result:=163;
  252: Result:=129;
  253: Result:=236;
  258..259: Result:=Unicode-60;
  260..261: Result:=Unicode-96;
  262: Result:=143;
  263: Result:=134;
  268: Result:=172;
  269: Result:=159;
  270: Result:=210;
  271: Result:=212;
  272: Result:=209;
  273: Result:=208;
  280..281: Result:=Unicode-112;
  282: Result:=183;
  283: Result:=216;
  313..314: Result:=Unicode-168;
  317..318: Result:=Unicode-168;
  321: Result:=157;
  322: Result:=136;
  323..324: Result:=Unicode-96;
  327: Result:=213;
  328: Result:=229;
  336..337: Result:=Unicode-198;
  340: Result:=232;
  341: Result:=234;
  344..345: Result:=Unicode-92;
  346..347: Result:=Unicode-195;
  350: Result:=184;
  351: Result:=173;
  352..353: Result:=Unicode-122;
  354: Result:=221;
  355: Result:=238;
  356..357: Result:=Unicode-201;
  366: Result:=222;
  367: Result:=133;
  368: Result:=235;
  369: Result:=251;
  377: Result:=141;
  378: Result:=171;
  379..380: Result:=Unicode-190;
  381..382: Result:=Unicode-215;
  711: Result:=243;
  728: Result:=244;
  729: Result:=250;
  731: Result:=242;
  733: Result:=241;
  9472: Result:=196;
  9474: Result:=179;
  9484: Result:=218;
  9488: Result:=191;
  9492: Result:=192;
  9496: Result:=217;
  9500: Result:=195;
  9508: Result:=180;
  9516: Result:=194;
  9524: Result:=193;
  9532: Result:=197;
  9552: Result:=205;
  9553: Result:=186;
  9556: Result:=201;
  9559: Result:=187;
  9562: Result:=200;
  9565: Result:=188;
  9568: Result:=204;
  9571: Result:=185;
  9574: Result:=203;
  9577: Result:=202;
  9580: Result:=206;
  9600: Result:=223;
  9604: Result:=220;
  9608: Result:=219;
  9617..9619: Result:=Unicode-9441;
  9632: Result:=254;
  else Result:=-1;
  end;
end;

function UnicodeToCP866(Unicode: cardinal): integer;
begin
  case Unicode of
  0..127: Result:=Unicode;
  1040..1087 : Result := Unicode-912;
  9617..9619 : Result := Unicode-9441;
  9474 : Result := 179;
  9508 : Result := 180;
  9569 : Result := 181;
  9570 : Result := 182;
  9558 : Result := 183;
  9557 : Result := 184;
  9571 : Result := 185;
  9553 : Result := 186;
  9559 : Result := 187;
  9565 : Result := 188;
  9564 : Result := 189;
  9563 : Result := 190;
  9488 : Result := 191;
  9492 : Result := 192;
  9524 : Result := 193;
  9516 : Result := 194;
  9500 : Result := 195;
  9472 : Result := 196;
  9532 : Result := 197;
  9566 : Result := 198;
  9567 : Result := 199;
  9562 : Result := 200;
  9556 : Result := 201;
  9577 : Result := 202;
  9574 : Result := 203;
  9568 : Result := 204;
  9552 : Result := 205;
  9580 : Result := 206;
  9575 : Result := 207;
  9576 : Result := 208;
  9572 : Result := 209;
  9573 : Result := 210;
  9561 : Result := 211;
  9560 : Result := 212;
  9554 : Result := 213;
  9555 : Result := 214;
  9579 : Result := 215;
  9578 : Result := 216;
  9496 : Result := 217;
  9484 : Result := 218;
  9608 : Result := 219;
  9604 : Result := 220;
  9612 : Result := 221;
  9616 : Result := 222;
  9600 : Result := 223;
  1088..1103 : Result := Unicode-864;
  1025 : Result := 240;
  1105 : Result := 241;
  1028 : Result := 242;
  1108 : Result := 243;
  1031 : Result := 244;
  1111 : Result := 245;
  1038 : Result := 246;
  1118 : Result := 247;
  176  : Result := 248;
  8729 : Result := 249;
  183  : Result := 250;
  8730 : Result := 251;
  8470 : Result := 252;
  164  : Result := 253;
  9632 : Result := 254;
  160  : Result := 255;
  else Result:=-1;
  end;
end;

function UnicodeToISO_8859_1(Unicode: cardinal): integer;
begin
  case Unicode of
  0..255: Result:=Unicode;
  else Result:=-1;
  end;
end;

function UnicodeToISO_8859_15(Unicode: cardinal): integer;
begin
  case Unicode of
  0..255: Result:=Unicode;
  8364: Result:=164;
  352: Result:=166;
  353: Result:=168;
  381: Result:=180;
  382: Result:=184;
  338: Result:=188;
  339: Result:=189;
  376: Result:=190;
  else Result:=-1;
  end;
end;

function UnicodeToISO_8859_2(Unicode: cardinal): integer;
begin
  case Unicode of
  0..127: Result:=Unicode;
  128..160: Result:=Unicode;
  164: Result:=164;
  167..168: Result:=Unicode;
  173: Result:=173;
  176: Result:=176;
  180: Result:=180;
  184: Result:=184;
  193..194: Result:=Unicode;
  196: Result:=196;
  199: Result:=199;
  201: Result:=201;
  203: Result:=203;
  205..206: Result:=Unicode;
  211..212: Result:=Unicode;
  214..215: Result:=Unicode;
  218: Result:=218;
  220..221: Result:=Unicode;
  223: Result:=223;
  225..226: Result:=Unicode;
  228: Result:=228;
  231: Result:=231;
  233: Result:=233;
  235: Result:=235;
  237..238: Result:=Unicode;
  243..244: Result:=Unicode;
  246..247: Result:=Unicode;
  250: Result:=250;
  252..253: Result:=Unicode;
  258: Result:=195;
  259: Result:=227;
  260: Result:=161;
  261: Result:=177;
  262: Result:=198;
  263: Result:=230;
  268: Result:=200;
  269: Result:=232;
  270: Result:=207;
  271: Result:=239;
  272: Result:=208;
  273: Result:=240;
  280: Result:=202;
  281: Result:=234;
  282: Result:=204;
  283: Result:=236;
  313: Result:=197;
  314: Result:=229;
  317: Result:=165;
  318: Result:=181;
  321: Result:=163;
  322: Result:=179;
  323: Result:=209;
  324: Result:=241;
  327: Result:=210;
  328: Result:=242;
  336: Result:=213;
  337: Result:=245;
  340: Result:=192;
  341: Result:=224;
  344: Result:=216;
  345: Result:=248;
  346: Result:=166;
  347: Result:=182;
  350: Result:=170;
  351: Result:=186;
  352: Result:=169;
  353: Result:=185;
  354: Result:=222;
  355: Result:=254;
  356: Result:=171;
  357: Result:=187;
  366: Result:=217;
  367: Result:=249;
  368: Result:=219;
  369: Result:=251;
  377: Result:=172;
  378: Result:=188;
  379: Result:=175;
  380: Result:=191;
  381: Result:=174;
  382: Result:=190;
  711: Result:=183;
  728: Result:=162;
  729: Result:=255;
  731: Result:=178;
  733: Result:=189;
  else Result:=-1;
  end;
end;

function UnicodeToMacintosh(Unicode: cardinal): integer;
begin
  case Unicode of
  0..127: Result:=Unicode;
  160: Result:=202;
  161: Result:=193;
  162..163: Result:=Unicode;
  165: Result:=180;
  167: Result:=164;
  168: Result:=172;
  169: Result:=169;
  170: Result:=187;
  171: Result:=199;
  172: Result:=194;
  174: Result:=168;
  175: Result:=248;
  176: Result:=161;
  177: Result:=177;
  180: Result:=171;
  181: Result:=181;
  182: Result:=166;
  183: Result:=225;
  184: Result:=252;
  186: Result:=188;
  187: Result:=200;
  191: Result:=192;
  192: Result:=203;
  193: Result:=231;
  194: Result:=229;
  195: Result:=204;
  196..197: Result:=Unicode-68;
  198: Result:=174;
  199: Result:=130;
  200: Result:=233;
  201: Result:=131;
  202: Result:=230;
  203: Result:=232;
  204: Result:=237;
  205..207: Result:=Unicode+29;
  209: Result:=132;
  210: Result:=241;
  211..212: Result:=Unicode+27;
  213: Result:=205;
  214: Result:=133;
  216: Result:=175;
  217: Result:=244;
  218..219: Result:=Unicode+24;
  220: Result:=134;
  223: Result:=167;
  224: Result:=136;
  225: Result:=135;
  226: Result:=137;
  227: Result:=139;
  228: Result:=138;
  229: Result:=140;
  230: Result:=190;
  231: Result:=141;
  232: Result:=143;
  233: Result:=142;
  234..235: Result:=Unicode-90;
  236: Result:=147;
  237: Result:=146;
  238..239: Result:=Unicode-90;
  241: Result:=150;
  242: Result:=152;
  243: Result:=151;
  244: Result:=153;
  245: Result:=155;
  246: Result:=154;
  247: Result:=214;
  248: Result:=191;
  249: Result:=157;
  250: Result:=156;
  251..252: Result:=Unicode-93;
  255: Result:=216;
  305: Result:=245;
  338..339: Result:=Unicode-132;
  376: Result:=217;
  402: Result:=196;
  710: Result:=246;
  711: Result:=255;
  728..730: Result:=Unicode-479;
  731: Result:=254;
  732: Result:=247;
  733: Result:=253;
  916: Result:=198;
  937: Result:=189;
  960: Result:=185;
  8211..8212: Result:=Unicode-8003;
  8216..8217: Result:=Unicode-8004;
  8218: Result:=226;
  8220..8221: Result:=Unicode-8010;
  8222: Result:=227;
  8224: Result:=160;
  8225: Result:=224;
  8226: Result:=165;
  8230: Result:=201;
  8240: Result:=228;
  8249..8250: Result:=Unicode-8029;
  8260: Result:=218;
  8364: Result:=219;
  8482: Result:=170;
  8706: Result:=182;
  8719: Result:=184;
  8721: Result:=183;
  8730: Result:=195;
  8734: Result:=176;
  8747: Result:=186;
  8776: Result:=197;
  8800: Result:=173;
  8804..8805: Result:=Unicode-8626;
  9674: Result:=215;
  57374: Result:=240;
  64257..64258: Result:=Unicode-64035;
  else Result:=-1;
  end;
end;
{$endif}

function UnicodeToKOI8R(Unicode: cardinal): integer;
begin
  case Unicode of
  0..127: Result:=Unicode;
  160: Result:=154;
  169: Result:=191;
  176: Result:=156;
  178: Result:=157;
  183: Result:=158;
  247: Result:=159;
  1025: Result:=179;
  1040..1041: Result:=Unicode-815;
  1042: Result:=247;
  1043: Result:=231;
  1044..1045: Result:=Unicode-816;
  1046: Result:=246;
  1047: Result:=250;
  1048..1055: Result:=Unicode-815;
  1056..1059: Result:=Unicode-814;
  1060: Result:=230;
  1061: Result:=232;
  1062: Result:=227;
  1063: Result:=254;
  1064: Result:=251;
  1065: Result:=253;
  1066: Result:=255;
  1067: Result:=249;
  1068: Result:=248;
  1069: Result:=252;
  1070: Result:=224;
  1071: Result:=241;
  1072..1073: Result:=Unicode-879;
  1074: Result:=215;
  1075: Result:=199;
  1076..1077: Result:=Unicode-880;
  1078: Result:=214;
  1079: Result:=218;
  1080..1087: Result:=Unicode-879;
  1088..1091: Result:=Unicode-878;
  1092: Result:=198;
  1093: Result:=200;
  1094: Result:=195;
  1095: Result:=222;
  1096: Result:=219;
  1097: Result:=221;
  1098: Result:=223;
  1099: Result:=217;
  1100: Result:=216;
  1101: Result:=220;
  1102: Result:=192;
  1103: Result:=209;
  1105: Result:=163;
  8729: Result:=149;
  8730: Result:=150;
  8776: Result:=151;
  8804: Result:=152;
  8805: Result:=153;
  8992: Result:=147;
  8993: Result:=155;
  9472: Result:=128;
  9474: Result:=129;
  9484: Result:=130;
  9488: Result:=131;
  9492: Result:=132;
  9496: Result:=133;
  9500: Result:=134;
  9508: Result:=135;
  9516: Result:=136;
  9524: Result:=137;
  9532: Result:=138;
  9552..9554: Result:=Unicode-9392;
  9555..9569: Result:=Unicode-9391;
  9570..9580: Result:=Unicode-9390;
  9600: Result:=139;
  9604: Result:=140;
  9608: Result:=141;
  9612: Result:=142;
  9616..9619: Result:=Unicode-9473;
  9632: Result:=148;
  else Result:=-1;
  end;
end;

function UnicodeToKOI8U(Unicode: cardinal): integer;
begin
  case Unicode of
  1028: Result:=180;
  1030..1031: Result:=Unicode-848;
  1108: Result:=164;
  1110..1111: Result:=Unicode-944;
  1168: Result:=189;
  1169: Result:=173;
  else
    Result:=UnicodeToKOI8R(Unicode);
  end;
end;

function UnicodeToKOI8RU(Unicode: cardinal): integer;
begin
  case Unicode of
  164 : Result:=159;
  171 : Result:=157;
  174 : Result:=156;
  187 : Result:=155;
  1038: Result:=190;
  1118: Result:=174;
  8212: Result:=151;
  8220: Result:=147;
  8221: Result:=150;
  8470: Result:=152;
  8482: Result:=153;
  else
    Result:=UnicodeToKOI8U(Unicode);
  end;
end;

function UnicodeToCP1250(Unicode: cardinal): integer;
begin
  case Unicode of
  0..127,129,131,136,144,152: Result:=Unicode;
  160: Result:=160;
  164: Result:=164;
  166..169: Result:=Unicode;
  171..174: Result:=Unicode;
  176..177: Result:=Unicode;
  180..184: Result:=Unicode;
  187: Result:=187;
  193..194: Result:=Unicode;
  196: Result:=196;
  199: Result:=199;
  201: Result:=201;
  203: Result:=203;
  205..206: Result:=Unicode;
  211..212: Result:=Unicode;
  214..215: Result:=Unicode;
  218: Result:=218;
  220..221: Result:=Unicode;
  223: Result:=223;
  225..226: Result:=Unicode;
  228: Result:=228;
  231: Result:=231;
  233: Result:=233;
  235: Result:=235;
  237..238: Result:=Unicode;
  243..244: Result:=Unicode;
  246..247: Result:=Unicode;
  250: Result:=250;
  252..253: Result:=Unicode;
  258: Result:=195;
  259: Result:=227;
  260: Result:=165;
  261: Result:=185;
  262: Result:=198;
  263: Result:=230;
  268: Result:=200;
  269: Result:=232;
  270: Result:=207;
  271: Result:=239;
  272: Result:=208;
  273: Result:=240;
  280: Result:=202;
  281: Result:=234;
  282: Result:=204;
  283: Result:=236;
  313: Result:=197;
  314: Result:=229;
  317: Result:=188;
  318: Result:=190;
  321: Result:=163;
  322: Result:=179;
  323: Result:=209;
  324: Result:=241;
  327: Result:=210;
  328: Result:=242;
  336: Result:=213;
  337: Result:=245;
  340: Result:=192;
  341: Result:=224;
  344: Result:=216;
  345: Result:=248;
  346: Result:=140;
  347: Result:=156;
  350: Result:=170;
  351: Result:=186;
  352: Result:=138;
  353: Result:=154;
  354: Result:=222;
  355: Result:=254;
  356: Result:=141;
  357: Result:=157;
  366: Result:=217;
  367: Result:=249;
  368: Result:=219;
  369: Result:=251;
  377: Result:=143;
  378: Result:=159;
  379: Result:=175;
  380: Result:=191;
  381: Result:=142;
  382: Result:=158;
  711: Result:=161;
  728: Result:=162;
  729: Result:=255;
  731: Result:=178;
  733: Result:=189;
  8211..8212: Result:=Unicode-8061;
  8216..8217: Result:=Unicode-8071;
  8218: Result:=130;
  8220..8221: Result:=Unicode-8073;
  8222: Result:=132;
  8224..8225: Result:=Unicode-8090;
  8226: Result:=149;
  8230: Result:=133;
  8240: Result:=137;
  8249: Result:=139;
  8250: Result:=155;
  8364: Result:=128;
  8482: Result:=153;
  else Result:=-1;
  end;
end;

function UnicodeToCP1251(Unicode: cardinal): integer;
begin
  case Unicode of
  0..127,152: Result:=Unicode;
  160: Result:=160;
  164: Result:=164;
  166..167: Result:=Unicode;
  169: Result:=169;
  171..174: Result:=Unicode;
  176..177: Result:=Unicode;
  181..183: Result:=Unicode;
  187: Result:=187;
  1025: Result:=168;
  1026..1027: Result:=Unicode-898;
  1028: Result:=170;
  1029: Result:=189;
  1030: Result:=178;
  1031: Result:=175;
  1032: Result:=163;
  1033: Result:=138;
  1034: Result:=140;
  1035: Result:=142;
  1036: Result:=141;
  1038: Result:=161;
  1039: Result:=143;
  1040..1103: Result:=Unicode-848;
  1105: Result:=184;
  1106: Result:=144;
  1107: Result:=131;
  1108: Result:=186;
  1109: Result:=190;
  1110: Result:=179;
  1111: Result:=191;
  1112: Result:=188;
  1113: Result:=154;
  1114: Result:=156;
  1115: Result:=158;
  1116: Result:=157;
  1118: Result:=162;
  1119: Result:=159;
  1168: Result:=165;
  1169: Result:=180;
  8211..8212: Result:=Unicode-8061;
  8216..8217: Result:=Unicode-8071;
  8218: Result:=130;
  8220..8221: Result:=Unicode-8073;
  8222: Result:=132;
  8224..8225: Result:=Unicode-8090;
  8226: Result:=149;
  8230: Result:=133;
  8240: Result:=137;
  8249: Result:=139;
  8250: Result:=155;
  8364: Result:=136;
  8470: Result:=185;
  8482: Result:=153;
  else Result:=-1;
  end;
end;

function UnicodeToCP1252(Unicode: cardinal): integer;
begin
  case Unicode of
  0..127,129,141,143,144,157: Result:=Unicode;
  160..255: Result:=Unicode;
  338: Result:=140;
  339: Result:=156;
  352: Result:=138;
  353: Result:=154;
  376: Result:=159;
  381: Result:=142;
  382: Result:=158;
  402: Result:=131;
  710: Result:=136;
  732: Result:=152;
  8211..8212: Result:=Unicode-8061;
  8216..8217: Result:=Unicode-8071;
  8218: Result:=130;
  8220..8221: Result:=Unicode-8073;
  8222: Result:=132;
  8224..8225: Result:=Unicode-8090;
  8226: Result:=149;
  8230: Result:=133;
  8240: Result:=137;
  8249: Result:=139;
  8250: Result:=155;
  8364: Result:=128;
  8482: Result:=153;
  else Result:=-1;
  end;
end;

function UnicodeToCP1253(Unicode: cardinal): integer;
begin
  case Unicode of
  0..127,129,136,138,140,141,142,143,144,152,154,156,157,158,159,170: Result:=Unicode;
  160: Result:=160;
  163..169: Result:=Unicode;
  171..174: Result:=Unicode;
  176..179: Result:=Unicode;
  181..183: Result:=Unicode;
  187: Result:=187;
  189: Result:=189;
  402: Result:=131;
  900: Result:=180;
  901..902: Result:=Unicode-740;
  904..906: Result:=Unicode-720;
  908: Result:=188;
  910..975: Result:=Unicode-720;
  8211..8212: Result:=Unicode-8061;
  8213: Result:=175;
  8216..8217: Result:=Unicode-8071;
  8218: Result:=130;
  8220..8221: Result:=Unicode-8073;
  8222: Result:=132;
  8224..8225: Result:=Unicode-8090;
  8226: Result:=149;
  8230: Result:=133;
  8240: Result:=137;
  8249: Result:=139;
  8250: Result:=155;
  8364: Result:=128;
  8482: Result:=153;
  else Result:=-1;
  end;
end;

function UnicodeToCP1254(Unicode: cardinal): integer;
begin
  case Unicode of
  0..127,129,141,142,143,144,157,158: Result:=Unicode;
  160..207: Result:=Unicode;
  209..220: Result:=Unicode;
  223..239: Result:=Unicode;
  241..252: Result:=Unicode;
  255: Result:=255;
  286: Result:=208;
  287: Result:=240;
  304: Result:=221;
  305: Result:=253;
  338: Result:=140;
  339: Result:=156;
  350: Result:=222;
  351: Result:=254;
  352: Result:=138;
  353: Result:=154;
  376: Result:=159;
  402: Result:=131;
  710: Result:=136;
  732: Result:=152;
  8211..8212: Result:=Unicode-8061;
  8216..8217: Result:=Unicode-8071;
  8218: Result:=130;
  8220..8221: Result:=Unicode-8073;
  8222: Result:=132;
  8224..8225: Result:=Unicode-8090;
  8226: Result:=149;
  8230: Result:=133;
  8240: Result:=137;
  8249: Result:=139;
  8250: Result:=155;
  8364: Result:=128;
  8482: Result:=153;
  else Result:=-1;
  end;
end;

function UnicodeToCP1255(Unicode: cardinal): integer;
begin
  case Unicode of
  0..127,129,138,140..144,154: Result:=Unicode;
  156..163: Result:=Unicode;
  165..169: Result:=Unicode;
  171..185: Result:=Unicode;
  187..191: Result:=Unicode;
  215: Result:=170;
  247: Result:=186;
  402: Result:=131;
  710: Result:=136;
  732: Result:=152;
  1456..1475: Result:=Unicode-1264;
  1488..1516: Result:=Unicode-1264;
  1517: Result:=255;
  1520..1535: Result:=Unicode-1308;
  8206..8207: Result:=Unicode-7953;
  8211..8212: Result:=Unicode-8061;
  8216..8217: Result:=Unicode-8071;
  8218: Result:=130;
  8220..8221: Result:=Unicode-8073;
  8222: Result:=132;
  8224..8225: Result:=Unicode-8090;
  8226: Result:=149;
  8230: Result:=133;
  8240: Result:=137;
  8249: Result:=139;
  8250: Result:=155;
  8362: Result:=164;
  8364: Result:=128;
  8482: Result:=153;
  else Result:=-1;
  end;
end;

function UnicodeToCP1257(Unicode: cardinal): integer;
begin
  case Unicode of
  0..127: Result:=Unicode;
  129: Result:=129;
  131: Result:=131;
  136: Result:=136;
  138: Result:=138;
  140: Result:=140;
  144: Result:=144;
  152: Result:=152;
  154: Result:=154;
  156: Result:=156;
  159..167: Result:=Unicode;
  168: Result:=141;
  169: Result:=169;
  171..174: Result:=Unicode;
  175: Result:=157;
  176..183: Result:=Unicode;
  184: Result:=143;
  185: Result:=185;
  187..190: Result:=Unicode;
  196..197: Result:=Unicode;
  198: Result:=175;
  201: Result:=201;
  211: Result:=211;
  213..215: Result:=Unicode;
  216: Result:=168;
  220: Result:=220;
  223: Result:=223;
  228..229: Result:=Unicode;
  230: Result:=191;
  233: Result:=233;
  243: Result:=243;
  245..247: Result:=Unicode;
  248: Result:=184;
  252: Result:=252;
  256: Result:=194;
  257: Result:=226;
  260: Result:=192;
  261: Result:=224;
  262: Result:=195;
  263: Result:=227;
  268: Result:=200;
  269: Result:=232;
  274: Result:=199;
  275: Result:=231;
  278: Result:=203;
  279: Result:=235;
  280: Result:=198;
  281: Result:=230;
  290: Result:=204;
  291: Result:=236;
  298: Result:=206;
  299: Result:=238;
  302: Result:=193;
  303: Result:=225;
  310: Result:=205;
  311: Result:=237;
  315: Result:=207;
  316: Result:=239;
  321: Result:=217;
  322: Result:=249;
  323: Result:=209;
  324: Result:=241;
  325: Result:=210;
  326: Result:=242;
  332: Result:=212;
  333: Result:=244;
  342: Result:=170;
  343: Result:=186;
  346: Result:=218;
  347: Result:=250;
  352: Result:=208;
  353: Result:=240;
  362: Result:=219;
  363: Result:=251;
  370: Result:=216;
  371: Result:=248;
  377: Result:=202;
  378: Result:=234;
  379: Result:=221;
  380: Result:=253;
  381: Result:=222;
  382: Result:=254;
  711: Result:=142;
  729: Result:=255;
  731: Result:=158;
  8211..8212: Result:=Unicode-8061;
  8216..8217: Result:=Unicode-8071;
  8218: Result:=130;
  8220..8221: Result:=Unicode-8073;
  8222: Result:=132;
  8224..8225: Result:=Unicode-8090;
  8226: Result:=149;
  8230: Result:=133;
  8240: Result:=137;
  8249: Result:=139;
  8250: Result:=155;
  8364: Result:=128;
  8482: Result:=153;
  else Result:=-1;
  end;
end;

function UnicodeToCP1258(Unicode: cardinal): integer;
begin
  case Unicode of
  0..127: Result:=Unicode;
  129: Result:=129;
  138: Result:=138;
  141..144: Result:=Unicode;
  154: Result:=154;
  157..158: Result:=Unicode;
  160..194: Result:=Unicode;
  196..203: Result:=Unicode;
  205..207: Result:=Unicode;
  209: Result:=209;
  211..212: Result:=Unicode;
  214..220: Result:=Unicode;
  223..226: Result:=Unicode;
  228..235: Result:=Unicode;
  237..239: Result:=Unicode;
  241: Result:=241;
  243..244: Result:=Unicode;
  246..252: Result:=Unicode;
  255: Result:=255;
  258: Result:=195;
  259: Result:=227;
  272: Result:=208;
  273: Result:=240;
  338: Result:=140;
  339: Result:=156;
  376: Result:=159;
  402: Result:=131;
  416: Result:=213;
  417: Result:=245;
  431: Result:=221;
  432: Result:=253;
  710: Result:=136;
  732: Result:=152;
  768: Result:=204;
  769: Result:=236;
  771: Result:=222;
  777: Result:=210;
  803: Result:=242;
  8211..8212: Result:=Unicode-8061;
  8216..8217: Result:=Unicode-8071;
  8218: Result:=130;
  8220..8221: Result:=Unicode-8073;
  8222: Result:=132;
  8224..8225: Result:=Unicode-8090;
  8226: Result:=149;
  8230: Result:=133;
  8240: Result:=137;
  8249: Result:=139;
  8250: Result:=155;
  8363: Result:=254;
  8364: Result:=128;
  8482: Result:=153;
  else Result:=-1;
  end;
end;

function UnicodeToCP874(Unicode: cardinal): integer;
begin
  case Unicode of
  0..127: Result:=Unicode;
  129..132: Result:=Unicode;
  134..144: Result:=Unicode;
  152..160: Result:=Unicode;
  219..222: Result:=Unicode;
  252..255: Result:=Unicode;
  3585..3642: Result:=Unicode-3424;
  3647..3675: Result:=Unicode-3424;
  8211..8212: Result:=Unicode-8061;
  8216..8217: Result:=Unicode-8071;
  8220..8221: Result:=Unicode-8073;
  8226: Result:=149;
  8230: Result:=133;
  8364: Result:=128;
  else Result:=-1;
  end;
end;

//{$if FPC_FULLVERSION >= 20701}
{$IFDEF FPC_HAS_CPSTRING}
procedure InternalUTF8ToCP(const s: string; TargetCodePage: TSystemCodePage;
  SetTargetCodePage: boolean;
  const UTF8CharConvFunc: TUnicodeToCharID;
  out TheResult: RawByteString); inline;
begin
  if not Assigned(UTF8CharConvFunc) then
  begin
    TheResult:=s;
    SetCodePage(TheResult, TargetCodePage, True);
    if not SetTargetCodePage then
      SetCodePage(TheResult, CP_ACP, False);
  end else begin
    TheResult:=UTF8ToSingleByte(s,UTF8CharConvFunc);
    if SetTargetCodePage then
      SetCodePage(TheResult, TargetCodePage, False);
  end;
end;

function UTF8ToISO_8859_1(const s: string; SetTargetCodePage: boolean): RawByteString;
begin
  InternalUTF8ToCP(s,28591,SetTargetCodePage,{$IfDef UseSystemCPConv}nil{$else}@UnicodeToISO_8859_1{$endif},Result);
end;

function UTF8ToISO_8859_2(const s: string; SetTargetCodePage: boolean): RawByteString;
begin
  InternalUTF8ToCP(s,28592,SetTargetCodePage,{$IfDef UseSystemCPConv}nil{$else}@UnicodeToISO_8859_2{$endif},Result);
end;

function UTF8ToISO_8859_15(const s: string; SetTargetCodePage: boolean): RawByteString;
begin
  InternalUTF8ToCP(s,28605,SetTargetCodePage,{$IfDef UseSystemCPConv}nil{$else}@UnicodeToISO_8859_15{$endif},Result);
end;

function UTF8ToCP1250(const s: string; SetTargetCodePage: boolean): RawByteString;
begin
  // system conversion fails for character #129 -> using table
  InternalUTF8ToCP(s,1250,SetTargetCodePage,@UnicodeToCP1250,Result);
end;

function UTF8ToCP1251(const s: string; SetTargetCodePage: boolean): RawByteString;
begin
  // system conversion fails for character #152 -> using table
  InternalUTF8ToCP(s,1251,SetTargetCodePage,@UnicodeToCP1251,Result);
end;

function UTF8ToCP1252(const s: string; SetTargetCodePage: boolean): RawByteString;
begin
  // system conversion fails for character #128 -> using table
  InternalUTF8ToCP(s,1252,SetTargetCodePage,@UnicodeToCP1252,Result);
end;

function UTF8ToCP1253(const s: string; SetTargetCodePage: boolean): RawByteString;
begin
  // system conversion fails for character #129 -> using table
  InternalUTF8ToCP(s,1253,SetTargetCodePage,@UnicodeToCP1253,Result);
end;

function UTF8ToCP1254(const s: string; SetTargetCodePage: boolean): RawByteString;
begin
  // system conversion fails for character #129 -> using table
  InternalUTF8ToCP(s,1254,SetTargetCodePage,@UnicodeToCP1254,Result);
end;

function UTF8ToCP1255(const s: string; SetTargetCodePage: boolean): RawByteString;
begin
  // system conversion fails for character #129 -> using table
  InternalUTF8ToCP(s,1255,SetTargetCodePage,@UnicodeToCP1255,Result);
end;

function UTF8ToCP1256(const s: string; SetTargetCodePage: boolean): RawByteString;
begin
  InternalUTF8ToCP(s,1256,SetTargetCodePage,{$IfDef UseSystemCPConv}nil{$else}@UnicodeToCP1256{$endif},Result);
end;

function UTF8ToCP1257(const s: string; SetTargetCodePage: boolean): RawByteString;
begin
  // system conversion fails for character #129 -> using table
  InternalUTF8ToCP(s,1257,SetTargetCodePage,@UnicodeToCP1257,Result);
end;

function UTF8ToCP1258(const s: string; SetTargetCodePage: boolean): RawByteString;
begin
  // system conversion fails for character #129 -> using table
  InternalUTF8ToCP(s,1258,SetTargetCodePage,@UnicodeToCP1258,Result);
end;

function UTF8ToCP437(const s: string; SetTargetCodePage: boolean): RawByteString;
begin
  InternalUTF8ToCP(s,437,SetTargetCodePage,{$IfDef UseSystemCPConv}nil{$else}@UnicodeToCP437{$endif},Result);
end;

function UTF8ToCP850(const s: string; SetTargetCodePage: boolean): RawByteString;
begin
  InternalUTF8ToCP(s,850,SetTargetCodePage,{$IfDef UseSystemCPConv}nil{$else}@UnicodeToCP850{$endif},Result);
end;

function UTF8ToCP852(const s: string; SetTargetCodePage: boolean): RawByteString;
begin
  InternalUTF8ToCP(s,852,SetTargetCodePage,{$IfDef UseSystemCPConv}nil{$else}@UnicodeToCP852{$endif},Result);
end;

function UTF8ToCP866(const s: string; SetTargetCodePage: boolean): RawByteString;
begin
  InternalUTF8ToCP(s,866,SetTargetCodePage,{$IfDef UseSystemCPConv}nil{$else}@UnicodeToCP866{$endif},Result);
end;

function UTF8ToCP874(const s: string; SetTargetCodePage: boolean): RawByteString;
begin
  // system conversion fails for character #129 -> using table
  InternalUTF8ToCP(s,874,SetTargetCodePage,@UnicodeToCP874,Result);
end;

function UTF8ToKOI8R(const s: string; SetTargetCodePage: boolean): RawByteString;
begin
  InternalUTF8ToCP(s,20866,SetTargetCodePage,{$IfDef UseSystemCPConv}nil{$else}@UnicodeToKOI8R{$endif},Result);
end;

function UTF8ToKOI8U(const s: string; SetTargetCodePage: boolean): RawByteString;
begin
  InternalUTF8ToCP(s,21866,SetTargetCodePage,{$IfDef UseSystemCPConv}nil{$else}@UnicodeToKOI8U{$endif},Result);
end;

function UTF8ToKOI8RU(const s: string; SetTargetCodePage: boolean): RawByteString;
begin
  // KOI8-RU dont have code page
  InternalUTF8ToCP(s,0,SetTargetCodePage,@UnicodeToKOI8RU,Result);
end;

function UTF8ToMacintosh(const s: string; SetTargetCodePage: boolean): RawByteString;
begin
  InternalUTF8ToCP(s,10000,SetTargetCodePage,{$IfDef UseSystemCPConv}nil{$else}@UnicodeToMacintosh{$endif},Result);
end;
{$ELSE}
function UTF8ToISO_8859_1(const s: string): string;
begin
  Result:=UTF8ToSingleByte(s,@UnicodeToISO_8859_1);
end;

function UTF8ToISO_8859_15(const s: string): string;
begin
  Result:=UTF8ToSingleByte(s,@UnicodeToISO_8859_15);
end;

function UTF8ToISO_8859_2(const s: string): string;
begin
  Result:=UTF8ToSingleByte(s,@UnicodeToISO_8859_2);
end;

function UTF8ToCP1250(const s: string): string;
begin
  Result:=UTF8ToSingleByte(s,@UnicodeToCP1250);
end;

function UTF8ToCP1251(const s: string): string;
begin
  Result:=UTF8ToSingleByte(s,@UnicodeToCP1251);
end;

function UTF8ToCP1252(const s: string): string;
begin
  Result:=UTF8ToSingleByte(s,@UnicodeToCP1252);
end;

function UTF8ToCP1253(const s: string): string;
begin
  Result:=UTF8ToSingleByte(s,@UnicodeToCP1253);
end;

function UTF8ToCP1254(const s: string): string;
begin
  Result:=UTF8ToSingleByte(s,@UnicodeToCP1254);
end;

function UTF8ToCP1255(const s: string): string;
begin
  Result:=UTF8ToSingleByte(s,@UnicodeToCP1255);
end;

function UTF8ToCP1256(const s: string): string;
begin
  Result:=UTF8ToSingleByte(s,@UnicodeToCP1256);
end;

function UTF8ToCP1257(const s: string): string;
begin
  Result:=UTF8ToSingleByte(s,@UnicodeToCP1257);
end;

function UTF8ToCP1258(const s: string): string;
begin
  Result:=UTF8ToSingleByte(s,@UnicodeToCP1258);
end;

function UTF8ToCP437(const s: string): string;
begin
  Result:=UTF8ToSingleByte(s,@UnicodeToCP437);
end;

function UTF8ToCP850(const s: string): string;
begin
  Result:=UTF8ToSingleByte(s,@UnicodeToCP850);
end;

function UTF8ToCP852(const s: string): string;
begin
  Result:=UTF8ToSingleByte(s,@UnicodeToCP852);
end;

function UTF8ToCP866(const s: string): string;
begin
  Result:=UTF8ToSingleByte(s,@UnicodeToCP866);
end;

function UTF8ToCP874(const s: string): string;
begin
  Result:=UTF8ToSingleByte(s,@UnicodeToCP874);
end;

function UTF8ToKOI8R(const s: string): string;
begin
  Result:=UTF8ToSingleByte(s,@UnicodeToKOI8R);
end;

function UTF8ToKOI8U(const s: string): string;
begin
  Result:=UTF8ToSingleByte(s,@UnicodeToKOI8U);
end;

function UTF8ToKOI8RU(const s: string): string;
begin
  Result:=UTF8ToSingleByte(s,@UnicodeToKOI8RU);
end;

function UTF8ToMacintosh(const s: string): string;
begin
  Result:=UTF8ToSingleByte(s,@UnicodeToMacintosh);
end;
{$ENDIF}

function UTF8ToSingleByte(const s: string; const UTF8CharConvFunc: TUnicodeToCharID): string;
var
  len, i, CharLen: Integer;
  Src, Dest: PChar;
  c: Char;
  Unicode: LongWord;
begin
  if s='' then exit('');
  len:=length(s);
  SetLength(Result,len);
  Src:=PChar(s);
  Dest:=PChar(Result);
  while len>0 do begin
    c:=Src^;
    if c<#128 then begin
      Dest^:=c;
      inc(Dest);
      inc(Src);
      dec(len);
    end else begin
      Unicode:=UTF8CodepointToUnicode(Src,CharLen);
      inc(Src,CharLen);
      dec(len,CharLen);
      i:=UTF8CharConvFunc(Unicode);
      //writeln('UTF8ToSingleByte Unicode=',Unicode,' CharLen=',CharLen,' c="',copy(s,Src-PChar(s)+1-CharLen,CharLen),'" i=',i);
      if i>=0 then begin
        Dest^:=chr(i);
        inc(Dest);
      end
      else
      case ConvertEncodingErrorMode of
        ceemSkip:
          begin end;
        ceemException:
          raise EConvertError.Create('Cannot convert UTF8 to single byte');
        ceemReplace:
          begin
            Dest^:='?';
            inc(Dest);
          end;
        ceemReturnEmpty:
          Exit('');
      end;
    end;
  end;
  SetLength(Result,Dest-PChar(Result));
end;

function UTF8ToUCS2LE(const s: string): string;
var
  len: Integer;
  Src: PChar;
  Dest: PWord;
  c: Char;
  Unicode: LongWord;
  CharLen: integer;
begin
  if s='' then exit('');
  len:=length(s);
  SetLength(Result,len*2);
  Src:=PChar(s);
  Dest:=PWord(Pointer(Result));
  while len>0 do begin
    c:=Src^;
    if c<#128 then begin
      Dest^:=NtoLE(Word(ord(c)));
      inc(Dest);
      inc(Src);
      dec(len);
    end else begin
      Unicode:=UTF8CodepointToUnicode(Src,CharLen);
      inc(Src,CharLen);
      dec(len,CharLen);
      if Unicode<=$ffff then begin
        Dest^:=NtoLE(Word(Unicode));
        inc(Dest);
      end;
    end;
  end;
  len:={%H-}PtrUInt(Dest)-PtrUInt(Result);
  if len>length(Result) then
    raise Exception.Create('');
  SetLength(Result,len);
end;

function UTF8ToUCS2BE(const s: string): string;
var
  len: Integer;
  Src: PChar;
  Dest: PWord;
  c: Char;
  Unicode: LongWord;
  CharLen: integer;
begin
  if s='' then exit('');
  len:=length(s);
  SetLength(Result,len*2);
  Src:=PChar(s);
  Dest:=PWord(Pointer(Result));
  while len>0 do begin
    c:=Src^;
    if c<#128 then begin
      Dest^:=NtoBE(Word(ord(c)));
      inc(Dest);
      inc(Src);
      dec(len);
    end else begin
      Unicode:=UTF8CodepointToUnicode(Src,CharLen);
      inc(Src,CharLen);
      dec(len,CharLen);
      if Unicode<=$ffff then begin
        Dest^:=NtoBE(Word(Unicode));
        inc(Dest);
      end;
    end;
  end;
  len:={%H-}PtrUInt(Dest)-PtrUInt(Result);
  if len>length(Result) then
    raise Exception.Create('');
  SetLength(Result,len);
end;

procedure GetSupportedEncodings(List: TStrings);
begin
  List.Add('UTF-8');
  List.Add('UTF-8BOM');
  List.Add('Ansi');

  List.Add(EncodingCP1250);
  List.Add(EncodingCP1251);
  List.Add(EncodingCP1252);
  List.Add(EncodingCP1253);
  List.Add(EncodingCP1254);
  List.Add(EncodingCP1255);
  List.Add(EncodingCP1256);
  List.Add(EncodingCP1257);
  List.Add(EncodingCP1258);
  List.Add(EncodingCP437);
  List.Add(EncodingCP850);
  List.Add(EncodingCP852);
  List.Add(EncodingCP866);
  List.Add(EncodingCP874);

  {$IFnDEF DisableAsianCodePages}
  List.Add(EncodingCP932);
  List.Add(EncodingCP936);
  List.Add(EncodingCP949);
  List.Add(EncodingCP950);
  {$ENDIF}

  List.Add('ISO-8859-1');
  List.Add('ISO-8859-2');
  List.Add('ISO-8859-15');

  List.Add('KOI8-R');
  List.Add('KOI8-U');
  List.Add('KOI8-RU');
  List.Add('Macintosh');

  // UCS2 are less common, list them last
  List.Add('UCS-2LE');
  List.Add('UCS-2BE');
end;

function GuessEncoding(const s: string): string;

  function CompareI(p1, p2: PChar; Count: integer): boolean;
  var
    i: Integer;
    Chr1: Byte;
    Chr2: Byte;
  begin
    for i:=1 to Count do begin
      Chr1 := byte(p1^);
      Chr2 := byte(p2^);
      if Chr1<>Chr2 then begin
        if Chr1 in [97..122] then
          dec(Chr1,32);
        if Chr2 in [97..122] then
          dec(Chr2,32);
        if Chr1<>Chr2 then exit(false);
      end;
      inc(p1);
      inc(p2);
    end;
    Result:=true;
  end;

  {$IFDEF VerboseIDEEncoding}
  function PosToStr(p: integer): string;
  var
    y: Integer;
    x: Integer;
    i: Integer;
  begin
    y:=1;
    x:=1;
    i:=1;
    while (i<=length(s)) and (i<p) do begin
      if s[i] in [#10,#13] then begin
        inc(i);
        x:=1;
        inc(y);
        if (i<=length(s)) and (s[i] in [#10,#13]) and (s[i]<>s[i-1]) then
          inc(i);
      end else begin
        inc(i);
        inc(x);
      end;
    end;
    Result:='x='+IntToStr(x)+',y='+IntToStr(y);
  end;
  {$ENDIF}

var
  l: Integer;
  p: PChar;
  EndPos: PChar;
  i: LongInt;
begin
  l:=length(s);
  if l=0 then exit('');
  p:=PChar(s);

  // try UTF-8 BOM (Byte Order Mark)
  if CompareI(p,UTF8BOM,3) then begin
    Result:=EncodingUTF8BOM;
    exit;
  end;

  // try ucs-2le BOM FF FE (ToDo: nowadays this BOM is UTF16LE)
  if (p^=#$FF) and (p[1]=#$FE) then begin
    Result:=EncodingUCS2LE;
    exit;
  end;

  // try ucs-2be BOM FE FF (ToDo: nowadays this BOM is UTF16BE)
  if (p^=#$FE) and (p[1]=#$FF) then begin
    Result:=EncodingUCS2BE;
    exit;
  end;

  // try {%encoding eee}
  if CompareI(p,'{%encoding ',11) then begin
    inc(p,length('{%encoding '));
    while (p^ in [' ',#9]) do inc(p);
    EndPos:=p;
    while not (EndPos^ in ['}',' ',#9,#0]) do inc(EndPos);
    Result:=NormalizeEncoding(copy(s,p-PChar(s)+1,EndPos-p));
    exit;
  end;

  // try UTF-8 (this includes ASCII)
  p:=PChar(s);
  repeat
    if ord(p^)<128 then begin
      // ASCII
      if (p^=#0) and (p-PChar(s)>=l) then begin
        Result:=EncodingUTF8;
        exit;
      end;
      inc(p);
    end else begin
      i:=UTF8CodepointStrictSize(p);
      //DebugLn(['GuessEncoding ',i,' ',DbgStr(s[p])]);
      if i=0 then begin
        {$IFDEF VerboseIDEEncoding}
        DebugLn(['GuessEncoding non UTF-8 found at ',PosToStr(p-PChar(s)+1),' ',dbgstr(copy(s,p-PChar(s)-10,20))]);
        {$ENDIF}
        break;
      end;
      inc(p,i);
    end;
  until false;

  // use system encoding
  Result:=GetDefaultTextEncoding;

  if NormalizeEncoding(Result)=EncodingUTF8 then begin
    // the system encoding is UTF-8, but the text is not UTF-8
    // use ISO-8859-1 instead. This encoding has a full 1:1 mapping to unicode,
    // so no character is lost during conversion back and forth.
    Result:='ISO-8859-1';
  end;
end;


function ConvertEncodingFromUTF8(const s, ToEncoding: string; out Encoded: boolean
  {$ifdef FPC_HAS_CPSTRING}; SetTargetCodePage: boolean = false{$endif}): string;
var
  ATo: string;

  {$ifdef FPC_HAS_CPSTRING}
  procedure CheckKeepCP; inline;
  begin
    if SetTargetCodePage then
      raise Exception.Create('ConvertEncodingFromUTF8: cannot set AnsiString codepage to "'+ATo+'"');
  end;
  {$endif}

begin
  Result:=s;
  Encoded:=true;
  ATo:=NormalizeEncoding(ToEncoding);

  if ATo=EncodingUTF8BOM then begin Result:=UTF8ToUTF8BOM(s); exit; end;
  if ATo=EncodingCPIso1 then begin Result:=UTF8ToISO_8859_1(s{$ifdef FPC_HAS_CPSTRING},SetTargetCodePage{$endif}); exit; end;
  if ATo=EncodingCPIso15 then begin Result:=UTF8ToISO_8859_15(s{$ifdef FPC_HAS_CPSTRING},SetTargetCodePage{$endif}); exit; end;
  if ATo=EncodingCPIso2 then begin Result:=UTF8ToISO_8859_2(s{$ifdef FPC_HAS_CPSTRING},SetTargetCodePage{$endif}); exit; end;
  if ATo=EncodingCP1250 then begin Result:=UTF8ToCP1250(s{$ifdef FPC_HAS_CPSTRING},SetTargetCodePage{$endif}); exit; end;
  if ATo=EncodingCP1251 then begin Result:=UTF8ToCP1251(s{$ifdef FPC_HAS_CPSTRING},SetTargetCodePage{$endif}); exit; end;
  if ATo=EncodingCP1252 then begin Result:=UTF8ToCP1252(s{$ifdef FPC_HAS_CPSTRING},SetTargetCodePage{$endif}); exit; end;
  if ATo=EncodingCP1253 then begin Result:=UTF8ToCP1253(s{$ifdef FPC_HAS_CPSTRING},SetTargetCodePage{$endif}); exit; end;
  if ATo=EncodingCP1254 then begin Result:=UTF8ToCP1254(s{$ifdef FPC_HAS_CPSTRING},SetTargetCodePage{$endif}); exit; end;
  if ATo=EncodingCP1255 then begin Result:=UTF8ToCP1255(s{$ifdef FPC_HAS_CPSTRING},SetTargetCodePage{$endif}); exit; end;
  if ATo=EncodingCP1256 then begin Result:=UTF8ToCP1256(s{$ifdef FPC_HAS_CPSTRING},SetTargetCodePage{$endif}); exit; end;
  if ATo=EncodingCP1257 then begin Result:=UTF8ToCP1257(s{$ifdef FPC_HAS_CPSTRING},SetTargetCodePage{$endif}); exit; end;
  if ATo=EncodingCP1258 then begin Result:=UTF8ToCP1258(s{$ifdef FPC_HAS_CPSTRING},SetTargetCodePage{$endif}); exit; end;
  if ATo=EncodingCP437 then begin Result:=UTF8ToCP437(s{$ifdef FPC_HAS_CPSTRING},SetTargetCodePage{$endif}); exit; end;
  if ATo=EncodingCP850 then begin Result:=UTF8ToCP850(s{$ifdef FPC_HAS_CPSTRING},SetTargetCodePage{$endif}); exit; end;
  if ATo=EncodingCP852 then begin Result:=UTF8ToCP852(s{$ifdef FPC_HAS_CPSTRING},SetTargetCodePage{$endif}); exit; end;
  if ATo=EncodingCP866 then begin Result:=UTF8ToCP866(s{$ifdef FPC_HAS_CPSTRING},SetTargetCodePage{$endif}); exit; end;
  if ATo=EncodingCP874 then begin Result:=UTF8ToCP874(s{$ifdef FPC_HAS_CPSTRING},SetTargetCodePage{$endif}); exit; end;
  {$IFnDEF DisableAsianCodePages}
  if ATo=EncodingCP936 then begin Result:=UTF8ToCP936(s{$ifdef FPC_HAS_CPSTRING},SetTargetCodePage{$endif}); exit; end;
  if ATo=EncodingCP950 then begin Result:=UTF8ToCP950(s{$ifdef FPC_HAS_CPSTRING},SetTargetCodePage{$endif}); exit; end;
  if ATo=EncodingCP949 then begin Result:=UTF8ToCP949(s{$ifdef FPC_HAS_CPSTRING},SetTargetCodePage{$endif}); exit; end;
  if ATo=EncodingCP932 then begin Result:=UTF8ToCP932(s{$ifdef FPC_HAS_CPSTRING},SetTargetCodePage{$endif}); exit; end;
  {$ENDIF}
  if ATo=EncodingCPKOI8R then begin Result:=UTF8ToKOI8R(s{$ifdef FPC_HAS_CPSTRING},SetTargetCodePage{$endif}); exit; end;
  if ATo=EncodingCPKOI8U then begin Result:=UTF8ToKOI8U(s{$ifdef FPC_HAS_CPSTRING},SetTargetCodePage{$endif}); exit; end;
  if ATo=EncodingCPKOI8RU then begin Result:=UTF8ToKOI8RU(s{$ifdef FPC_HAS_CPSTRING},SetTargetCodePage{$endif}); exit; end;
  if ATo=EncodingCPMac then begin Result:=UTF8ToMacintosh(s{$ifdef FPC_HAS_CPSTRING},SetTargetCodePage{$endif}); exit; end;
  if ATo=EncodingUCS2LE then begin {$ifdef FPC_HAS_CPSTRING}CheckKeepCP;{$endif} Result:=UTF8ToUCS2LE(s); exit; end;
  if ATo=EncodingUCS2BE then begin {$ifdef FPC_HAS_CPSTRING}CheckKeepCP;{$endif} Result:=UTF8ToUCS2BE(s); exit; end;

  if (ATo=GetDefaultTextEncoding) and Assigned(ConvertUTF8ToAnsi) then begin
    Result:=ConvertUTF8ToAnsi(s);
    exit;
  end;

  Encoded:= false;
end;

function ConvertEncodingToUTF8(const s, FromEncoding: string; out Encoded: boolean): string;
var
  AFrom: string;
begin
  Result:=s;
  Encoded:=true;
  AFrom:=NormalizeEncoding(FromEncoding);

  if AFrom=EncodingUTF8BOM then begin Result:=UTF8BOMToUTF8(s); exit; end;
  if AFrom=EncodingCPIso1 then begin Result:=ISO_8859_1ToUTF8(s); exit; end;
  if AFrom=EncodingCPIso15 then begin Result:=ISO_8859_15ToUTF8(s); exit; end;
  if AFrom=EncodingCPIso2 then begin Result:=ISO_8859_2ToUTF8(s); exit; end;
  if AFrom=EncodingCP1250 then begin Result:=CP1250ToUTF8(s); exit; end;
  if AFrom=EncodingCP1251 then begin Result:=CP1251ToUTF8(s); exit; end;
  if AFrom=EncodingCP1252 then begin Result:=CP1252ToUTF8(s); exit; end;
  if AFrom=EncodingCP1253 then begin Result:=CP1253ToUTF8(s); exit; end;
  if AFrom=EncodingCP1254 then begin Result:=CP1254ToUTF8(s); exit; end;
  if AFrom=EncodingCP1255 then begin Result:=CP1255ToUTF8(s); exit; end;
  if AFrom=EncodingCP1256 then begin Result:=CP1256ToUTF8(s); exit; end;
  if AFrom=EncodingCP1257 then begin Result:=CP1257ToUTF8(s); exit; end;
  if AFrom=EncodingCP1258 then begin Result:=CP1258ToUTF8(s); exit; end;
  if AFrom=EncodingCP437 then begin Result:=CP437ToUTF8(s); exit; end;
  if AFrom=EncodingCP850 then begin Result:=CP850ToUTF8(s); exit; end;
  if AFrom=EncodingCP852 then begin Result:=CP852ToUTF8(s); exit; end;
  if AFrom=EncodingCP866 then begin Result:=CP866ToUTF8(s); exit; end;
  if AFrom=EncodingCP874 then begin Result:=CP874ToUTF8(s); exit; end;
  {$IFnDEF DisableAsianCodePages}
  if AFrom=EncodingCP936 then begin Result:=CP936ToUTF8(s); exit; end;
  if AFrom=EncodingCP950 then begin Result:=CP950ToUTF8(s); exit; end;
  if AFrom=EncodingCP949 then begin Result:=CP949ToUTF8(s); exit; end;
  if AFrom=EncodingCP932 then begin Result:=CP932ToUTF8(s); exit; end;
  {$ENDIF}
  if AFrom=EncodingCPKOI8R then begin Result:=KOI8RToUTF8(s); exit; end;
  if AFrom=EncodingCPKOI8U then begin Result:=KOI8UToUTF8(s); exit; end;
  if AFrom=EncodingCPKOI8RU then begin Result:=KOI8RUToUTF8(s); exit; end;
  if AFrom=EncodingCPMac then begin Result:=MacintoshToUTF8(s); exit; end;
  if AFrom=EncodingUCS2LE then begin Result:=UCS2LEToUTF8(s); exit; end;
  if AFrom=EncodingUCS2BE then begin Result:=UCS2BEToUTF8(s); exit; end;

  if (AFrom=GetDefaultTextEncoding) and Assigned(ConvertAnsiToUTF8) then begin
    Result:=ConvertAnsiToUTF8(s);
    exit;
  end;

  Encoded:= false;
end;

function ConvertEncoding(const s, FromEncoding, ToEncoding: string
  {$ifdef FPC_HAS_CPSTRING}; SetTargetCodePage: boolean{$endif}): string;
var
  AFrom, ATo, SysEnc : String;
  Encoded : Boolean;
  {$ifdef EnableIconvEnc}
  Dummy: String;
  {$endif}
begin
  AFrom:=NormalizeEncoding(FromEncoding);
  ATo:=NormalizeEncoding(ToEncoding);
  SysEnc:=GetDefaultTextEncoding;
  if AFrom=EncodingAnsi then AFrom:=SysEnc
  else if AFrom='' then AFrom:=EncodingUTF8;
  if ATo=EncodingAnsi then ATo:=SysEnc
  else if ATo='' then ATo:=EncodingUTF8;
  if AFrom=ATo then begin
    Result:=s;
    exit;
  end;
  if s='' then begin
    if ATo=EncodingUTF8BOM then
      Result:=UTF8BOM
    else Result := s;
    exit;
  end;
  //DebugLn(['ConvertEncoding ',AFrom,' ',ATo]);

  if AFrom=EncodingUTF8 then begin
    Result:=ConvertEncodingFromUTF8(s, ATo, Encoded{$ifdef FPC_HAS_CPSTRING}, SetTargetCodePage{$endif});
    if Encoded then exit;
  end
  else
  if ATo=EncodingUTF8 then begin
    Result:=ConvertEncodingToUTF8(s, AFrom, Encoded);
    if Encoded then exit;
  end
  else
  begin
    Result:=ConvertEncodingToUTF8(s, AFrom, Encoded);
    if Encoded then
      Result:=ConvertEncodingFromUTF8(Result, ATo, Encoded{$ifdef FPC_HAS_CPSTRING}, SetTargetCodePage{$endif});
    if Encoded then exit;
  end;

  //cannot encode: return orig str
  Result:=s;

  {$ifdef EnableIconvEnc}
  try
    if not IconvLibFound and not InitIconv(Dummy) then
    begin
      {$IFNDEF DisableChecks}
      DebugLn(['Can not init iconv: ',Dummy]);
      {$ENDIF}
      Exit;
    end;
    if Iconvert(s, Result, AFrom, ATo)<>0 then
    begin
      Result:=s;
      Exit;
    end;
  except
  end;
  {$endif}
end;

end.

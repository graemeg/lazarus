{******************************************************************}
{*   IPUTILS.PAS - Miscellaneous Constants, Types, and Routines   *}
{******************************************************************}

(* ***** BEGIN LICENSE BLOCK *****
 * Version: MPL 1.1
 *
 * The contents of this file are subject to the Mozilla Public License Version
 * 1.1 (the "License"); you may not use this file except in compliance with
 * the License. You may obtain a copy of the License at
 * http://www.mozilla.org/MPL/
 *
 * Software distributed under the License is distributed on an "AS IS" basis,
 * WITHOUT WARRANTY OF ANY KIND, either express or implied. See the License
 * for the specific language governing rights and limitations under the
 * License.
 *
 * The Original Code is TurboPower Internet Professional
 *
 * The Initial Developer of the Original Code is
 * TurboPower Software
 *
 * Portions created by the Initial Developer are Copyright (C) 2000-2002
 * the Initial Developer. All Rights Reserved.
 *
 * Contributor(s):
 *
 * ***** END LICENSE BLOCK ***** *)

{ Global defines potentially affecting this unit }
{$I IPDEFINE.INC}

unit IpUtils;

interface

uses
  SysUtils, Classes, Registry,
  LCLType, LCLIntf, LMessages, Controls, ComCtrls,
  GraphType, LazFileUtils, LazStringUtils;

const
  InternetProfessionalVersion = 1.15;
  sShortVersion = 'v%.2f';

  IpMsgBase = WM_USER + $0E90;

  CM_IPASYNCRESULT      = IpMsgBase + 0;
  CM_IPSOCKMESSAGE      = IpMsgBase + 1;
  CM_IPSOCKETSTATUS     = IpMsgBase + 2;
  CM_IPFREESOCKET       = IpMsgBase + 3;
  CM_IPLINEMESSAGE      = IpMsgBase + 4;
  CM_IPTERMDATA         = IpMsgBase + 5;
  CM_IPTERMRESIZE       = IpMsgBase + 6;
  CM_IPICMPECHO         = IpMsgBase + 7;
  CM_IPHTTPGETREQUEST   = IpMsgBase + 8;
  CM_IPTIMESERVER       = IpMsgBase + 9;
  CM_IPTIMECLIENT       = IpMsgBase + 10;
  CM_IPSNTPCLIENT       = IpMsgBase + 11;
  CM_IPFTPREPLY         = IpMsgBase + 12;
  CM_IPFTPSTATUS        = IpMsgBase + 13;
  CM_IPFTPERROR         = IpMsgBase + 14;
  CM_IPFTPTIMEOUT       = IpMsgBase + 15;
  CM_IPTERMFORCESIZE    = IpMsgBase + 16;
  CM_IPTERMSTUFF        = IpMsgBase + 17;
  CM_IPRASSTATUS        = IpMsgBase + 18;
  CM_IPFINWHOSERVER     = IpMsgBase + 19;
  CM_IPUTILITYSERVER    = IpMsgBase + 20;
  CM_IPSMTPEVENT        = IpMsgBase + 21;
  CM_IPPOP3EVENT        = IpMsgBase + 22;
  CM_IPNNTPEVENT        = IpMsgBase + 23;
  CM_IPHOTINVOKE        = IpMsgBase + 24;

type
  TIpLineTerminator = (ltNone, ltCR, ltLF, ltCRLF, ltOther);

  TIpCRCByteArray = array[0..Pred(High(LongInt))] of Byte;

  TIpCharArray = array[0..Pred(High(LongInt))] of AnsiChar;

  TIpMD5StateArray = array[0..3] of DWORD;
  TIpMD5CountArray = array[0..1] of DWORD;

  TIpMD5ByteBuf = array[0..63] of Byte;
  TIpMD5LongBuf = array[0..15] of DWORD;

  TIpMD5Context = record
    State : TIpMD5StateArray;
    Count : TIpMD5CountArray;
    case Integer of
      0 : (ByteBuf : TIpMD5ByteBuf);
      1 : (LongBuf : TIpMD5LongBuf);
  end;

  TIpMD5Digest = array[0..15] of Byte;

  EIpBaseException = class(Exception);

  EIpAccessException = class(EIpBaseException);
  EIpHtmlException = class(EIpBaseException);

  TIpBaseAccess = class
  private
    baPropCS : TCriticalSection;
  public
    constructor Create; virtual;
    destructor Destroy; override;
    procedure LockProperties;
    procedure UnlockProperties;
  end;

  TIpBasePersistent = class(TPersistent)
  private
    bpPropCS : TCriticalSection;
  public
    constructor Create; virtual;
    destructor Destroy; override;
    procedure LockProperties;
    procedure UnlockProperties;
  end;

  TIpComponentClass = class of TIpBaseComponent;

  TIpBaseComponent = class(TComponent)
  protected
    function GetVersion : string;
    procedure SetVersion(const Value : string);
  public
    class function GetLogString(const S, D1, D2, D3 : DWORD) : string; virtual;
  published
    property Version : string
      read GetVersion write SetVersion stored False;
  end;

  TIpBaseWinControl = class(TWinControl)
  protected
    function GetVersion : string;
    procedure SetVersion(const Value : string);
  published
    property Version : string read GetVersion write SetVersion stored False;
  end;

  { Misc utility routines }
  function InClassA(Addr : LongInt) : Boolean;
  function InClassB(Addr : LongInt) : Boolean;
  function InClassC(Addr : LongInt) : Boolean;
  function InClassD(Addr : LongInt) : Boolean;
  function InMulticast(Addr : LongInt) : Boolean;

  function IpCharCount(const Buffer; BufSize : DWORD; C : AnsiChar) : DWORD;
  function IpCompStruct(const S1, S2; Size : Cardinal) : Integer;
  function IpMaxInt(A, B : Integer) : Integer;
  function IpMinInt(A, B : Integer) : Integer;
  procedure IpSafeFree(var Obj);
  function IpShortVersion : string;

  { CRC routines }
  function InternetSumPrim(var Data; DataSize, CurCrc : DWORD) : DWORD;
  function InternetSumOfStream(Stream : TStream; CurCrc : DWORD) : DWORD;
  function InternetSumOfFile(const FileName : string) : DWORD;
  function MD5SumOfFile(const FileName : string) : string;
  function MD5SumOfStream(Stream : TStream) : string;
  function MD5SumOfStreamDigest(Stream : TStream) : TIpMD5Digest;
  function MD5SumOfString(const S : string) : string;
  function MD5SumOfStringDigest(const S : string) : TIpMD5Digest;

  function SafeYield : LongInt; {-Allow other processes a chance to run}
  function AllTrimSpaces(Strng: string) : string;
  function CharPos(C: AnsiChar; const S : string): Integer;
  function CharPosIdx(C: AnsiChar; const S : string; Idx: Integer): Integer;
  function NthCharPos(C: AnsiChar; const S : string; Nth: Integer): Integer;
  function RCharPos(C: AnsiChar; const S : string): Integer;
  function RCharPosIdx(C: AnsiChar; const S : string; Idx: Integer): Integer;
  function RNthCharPos(C: AnsiChar; const S : string; Nth: Integer): Integer;
  function RPos(const Substr: string; const S: string): Integer;
  function PosIdx(const SubStr, S: string; Idx: Integer): Integer;


{address handling}
type
  CharSet = set of AnsiChar;

{ Structure to hold pieces of a URI (Uniform Resource Identifier) }
{ field names are derived from terminology used in:               }
{ RFC-2396 "Uniform Resource Identifiers (URI): Generic Syntax"   }

  TIpAddrRec = record
    Scheme     : string;
    UserName   : string;
    Password   : string;
    Authority  : string;
    Port       : string;
    Path       : string;
    Fragment   : string;
    Query      : string;
    QueryDelim : AnsiChar;
  end;
  
  procedure Initialize(var AddrRec: TIpAddrRec);
  procedure Finalize(var AddrRec: TIpAddrRec);

  function ExtractEntityName(const NamePath: string): string;
  function ExtractEntityPath(const NamePath: string): string;
  function IpParseURL(const URL : string; var Rslt : TIpAddrRec) : Boolean;
  function BuildURL(const OldURL, NewURL: string): string;
  function PutEscapes(const S : string; EscapeSet : CharSet) : string;
  function RemoveEscapes(const S : string; EscapeSet : CharSet) : string;
  procedure SplitParams(const Parms : string; Dest : TStrings);
  function NetToDOSPath(const PathStr : string) : string;
  function DOSToNetPath(const PathStr : string) : string;
  procedure SplitHttpResponse(const S : string; var V, MsgID, Msg: string);
  procedure FieldFix(Fields : TStrings);
  function AppendSlash(APath : string) : string;
  function RemoveSlash(APath : string) : string;
  function GetParentPath(const Path : string) : string;

{ File/Directory Stuff }
  function GetLocalContent(const TheFileName: string): string;
  function DirExists(Dir : string): Boolean;
  function GetTemporaryFile(const Path : string) : string;
  function GetTemporaryPath: string;
  function AppendBackSlash(APath : string) : string;
  function RemoveBackSlash(APath: string) : string;

{ date stuff }

  { convert Net date (as spec'ed in RFC 2616) to Delphi TDateTime }
  function INetDateStrToDateTime(const DateStr: string): TDateTime;
  { convert Delphi TDateTime to Net date (as spec'ed in RFC 2616) }
  function DateTimeToINetDateTimeStr(DateTime: TDateTime): string;
  { return the current local TimeZone "bias" in minutes from UTC (GMT) }
  function TimeZoneBias : Integer;

  procedure SplitCookieFields(const Data: string; Fields: TStrings);

implementation
{ misc utility routines }

{ Allow other processes a chance to run }
function SafeYield : LongInt;
begin
  SafeYield := 0;
  writeln('ToDo: IpUtils.SafeYield');
(*
  var
    Msg : TMsg;
  if PeekMessage(Msg, 0, 0, 0, PM_REMOVE) then begin
    if Msg.Message = wm_Quit then
      {Re-post quit message so main message loop will terminate}
      PostQuitMessage(Msg.WParam)
    else begin
      TranslateMessage(Msg);
      DispatchMessage(Msg);
    end;
    {Return message so caller can act on message if necessary}
    SafeYield := MAKELONG(Msg.Message, Msg.hwnd);
*)
end;

{ Trim leading and trailing spaces from a string }
function AllTrimSpaces(Strng: string) : string;
var
  StrStart, StrEnd: Cardinal;
begin
  StrEnd := Length(Strng);
  if StrEnd = 0 then begin  { string is empty }
    Result := '';
    Exit;
  end;

  while (StrEnd > 0 ) and (Strng[StrEnd] = ' ') do begin
  { find last non-space character }
    Dec(StrEnd);
  end;

  if StrEnd = 0 then begin  { string was all spaces }
    Result := '';
    Exit;
  end;

  StrStart := 1;
  while (StrStart < StrEnd) and (Strng[StrStart] = ' ') do begin
  { find first non-space character }
    Inc(StrStart);
  end;

  Result := Copy(Strng, StrStart, StrEnd - StrStart + 1);
end;

{ Find leftmost occurrence of character C in string S }
{* If C not found returns 0 }
function CharPos(C: AnsiChar; const S : string): Integer;
var
  i : Integer;
begin
  for i := 1 to length(S) do
    if (S[i] = C) then begin
      Result := i;
      Exit;
    end;
  Result := 0;
end;

{ Find leftmost occurrence of character C in string S past location Idx }
{ * If C not found returns 0 }
function CharPosIdx(C: AnsiChar; const S : string; Idx: Integer): Integer;
var
  Len : Integer;
begin
  Len := Length(S);
  if (Idx > Len) or (Idx < 1) then begin
    Result := 0;
    Exit;
  end;

  Result := Idx;
  while (Result <= Len) and (S[Result] <> C) do
    Inc(Result);
  if Result > Len then
    Result := 0;
end;

{ Find Nth occurrence of character C in string S }
{ * If C not found returns 0 }
function NthCharPos(C: AnsiChar; const S : string; Nth: Integer): Integer;
var
  Len, CharCt : Integer;
begin
  if Nth <= 0 then begin
    Result := 0;
    Exit;
  end;
  Len := Length(S);
  CharCt := 0;
  Result := 1;

  while (Result <= Len) and (CharCt < Nth) do begin
    if S[Result] = C then
      Inc(CharCt);
    if CharCt < Nth then
      Inc(Result);
  end;
  if Result > Len then
    Result := 0;
end;

{ Find rightmost occurrence of character C in string S }
{ * If C not found returns 0 }
function RCharPos(C: AnsiChar; const S : string): Integer;
begin
  Result := Length(S);
  while (Result > 0) and (S[Result] <> C) do
    Dec(Result);
  if (Result < 0) then
    Result := 0;
end;

{ Find rightmost occurrence of character C in string S prior to location Idx }
{ * If C not found returns 0 }
function RCharPosIdx(C: AnsiChar; const S : string; Idx: Integer): Integer;
begin
  Result := Length(S);

  if (Idx > Result) or (Idx < 1) then begin
    Result := 0;
    Exit;
  end;

  Result := Idx;
  while (Result > 0) and (S[Result] <> C) do
    Dec(Result);
  if (Result < 0) then
    Result := 0;
end;

{ Find Nth from the rightmost occurrence of character C in string S }
{ * If C not found returns 0 }
function RNthCharPos(C: AnsiChar; const S : string; Nth: Integer): Integer;
var
  CharCt : Integer;
begin
  if Nth <= 0 then begin
    Result := 0;
    Exit;
  end;

  CharCt := 0;
  Result := Length(S);
  while (Result > 0) and (CharCt < Nth) do begin
    if S[Result] = C then
      Inc(CharCt);
    if CharCt < Nth then
      Dec(Result);
  end;
  if (Result < 0) then
    Result := 0;
end;

{ Complement to RTL Pos() function, finds RIGHTmost }
{ instance of a substring (SubStr) within a string (S) }
{ * If Substr not found returns 0 }
function RPos(const Substr: string; const S: string): Integer;
var
  SL, i : Integer;
begin
  SL := Length(Substr);
  i := Length(S);
  if (Substr = '') or (S = '') or (SL > i) then begin
    Result := 0;
    Exit;
  end;

  while i >= SL do begin
    if S[i] = Substr[SL] then begin
      if Copy(S, i - SL + 1, SL) = Substr then begin
        Result := i - SL + 1;
        Exit;
      end;
    end;
    Dec(i);
  end;
  Result := i;
end;

{ Find location of first occurrence of a substring (SubStr) in a string (S) }
{ past a particular index (Idx) }
{ * Result is relative to the start of the entire original string }
{ * Returns 0 if substring not found }
function PosIdx(const SubStr, S: string; Idx: Integer): Integer;
var
  Temp : string;
begin
  Temp := Copy(S, Idx, Length(S) - Idx - 1);
  Result := Pos(SubStr, Temp);
  if Result > 0 then
    Result := Result + (Idx - 1);
end;

procedure Initialize(var AddrRec: TIpAddrRec);
begin
  AddrRec.QueryDelim:=#0;
end;

procedure Finalize(var AddrRec: TIpAddrRec);
begin
  with AddrRec do begin
    Scheme     :='';
    UserName   :='';
    Password   :='';
    Authority  :='';
    Port       :='';
    Path       :='';
    Fragment   :='';
    Query      :='';
  end;
end;

const
  CrcBufSize = 2048;
  CrcFileMode = fmOpenRead or fmShareDenyWrite;

{ Returns True if a given address is a Class A address }
function InClassA(Addr : LongInt) : Boolean;
begin
  Result := (Addr and $80000000) = 0;
end;

{ Returns True if a given address is a Class B address }
function InClassB(Addr : LongInt) : Boolean;
begin
  Result := (Cardinal(Addr) and $C0000000) = $80000000;
end;

{ Returns True if a given address is a Class C address }
function InClassC(Addr : LongInt) : Boolean;
begin
  Result := (Cardinal(Addr) and $E0000000) = $C0000000;
end;

{ Returns True if a given address is a Class D address }
function InClassD(Addr : LongInt) : Boolean;
begin
  Result := (Cardinal(Addr) and $F0000000) = $E0000000;
end;

{ Returns True if a given address is a multicast address }
function InMulticast(Addr : LongInt) : Boolean;
begin
  Result := InClassD(Addr);
end;

{ Calculates the Internet Checksum of a block }
function InternetSumPrim(var Data; DataSize, CurCrc : DWORD) : DWORD;
var
  I : Integer;
begin
  Result := CurCrc;
  if DataSize = 0 then Exit;
  for I := 0 to (DataSize - 1) do begin
    if Odd(I) then
      Result := Result + (cardinal(TIpCRCByteArray(Data)[I]) shl 8)
    else
      Result := Result + TIpCRCByteArray(Data)[I];
  end;
  Result := (not((Result and $FFFF) + (Result shr 16))) and $FFFF;
end;

{ Calculates the Internet Checksum of a stream }
function InternetSumOfStream(Stream : TStream; CurCrc : DWORD) : DWORD;
var
  BufArray : array[0..(CrcBufSize-1)] of Byte;
  Res      : LongInt;
begin
  {Initialize Crc}
  Result := CurCrc;
  repeat
    Res := Stream.Read(BufArray, CrcBufSize);
    Result := InternetSumPrim(BufArray, Res, Result);
  until (Res <> CrcBufSize);
end;

{ Calculates the Internet Checksum of a file }
function InternetSumOfFile(const FileName : string) : DWORD;
var
  FileSt : TFileStream;
begin
  FileSt := TFileStream.Create(FileName, CrcFileMode);
  try
    Result := InternetSumOfStream(FileSt, 0);
  finally
    FileSt.Free;
  end;
end;

{ Initialize the MD5 context record }
procedure MD5Init(var Context : TIpMD5Context);
begin
  { Zero out context }
  FillChar(Context, SizeOf(TIpMD5Context), #0);

  { Load magic initialization constants }
  Context.State[0] := DWORD($67452301);
  Context.State[1] := DWORD($efcdab89);
  Context.State[2] := DWORD($98badcfe);
  Context.State[3] := DWORD($10325476);
end;

{ MD5 Basic Transformation -- Transforms State based on Buf }
procedure MD5Transform(var State : TIpMD5StateArray; const Buf : TIpMD5LongBuf);
const
  S11 = 7; S12 = 12; S13 = 17; S14 = 22; S21 = 5; S22 = 9; S23 = 14;
  S24 = 20; S31 = 4; S32 = 11; S33 = 16; S34 = 23; S41 = 6; S42 = 10;
  S43 = 15; S44 = 21;
var
  a, b, c, d : DWORD;

  { Round 1 processing }
  procedure FF(var W : DWORD; X, Y, Z : DWORD; S : Byte; Data : DWORD);
  begin
    Inc(W, (Z xor (X and (Y xor Z))) + Data);
    W := (W shl S) or (W shr (32 - S));
    Inc(W, X);
  end;

  { Round 2 processing }
  procedure GG(var W : DWORD; X, Y, Z : DWORD; S : Byte; Data : DWORD);
  begin
    Inc(W, (Y xor (Z and (X xor Y))) + Data);
    W := (W shl S) or (W shr (32 - S));
    Inc(W, X);
  end;

  { Round 3 processing }
  procedure HH(var W : DWORD; X, Y, Z : DWORD; S : Byte; Data : DWORD);
  begin
    Inc(W, (X xor Y xor Z) + Data);
    W := (W shl S) or (W shr (32 - S));
    Inc(W, X);
  end;

  { Round 4 processing }
  procedure II(var W : DWORD; X, Y, Z : DWORD; S : Byte; Data : DWORD);
  begin
    Inc(W, (Y xor (X or not Z)) + Data);
    W := (W shl S) or (W shr (32 - S));
    Inc(W, X);
  end;

begin
  a := State[0];
  b := State[1];
  c := State[2];
  d := State[3];

  { Round 1 }
  FF(a, b, c, d, S11, Buf[ 0] + DWORD($d76aa478)); { 1 }
  FF(d, a, b, c, S12, Buf[ 1] + DWORD($e8c7b756)); { 2 }
  FF(c, d, a, b, S13, Buf[ 2] + DWORD($242070db)); { 3 }
  FF(b, c, d, a, S14, Buf[ 3] + DWORD($c1bdceee)); { 4 }
  FF(a, b, c, d, S11, Buf[ 4] + DWORD($f57c0faf)); { 5 }
  FF(d, a, b, c, S12, Buf[ 5] + DWORD($4787c62a)); { 6 }
  FF(c, d, a, b, S13, Buf[ 6] + DWORD($a8304613)); { 7 }
  FF(b, c, d, a, S14, Buf[ 7] + DWORD($fd469501)); { 8 }
  FF(a, b, c, d, S11, Buf[ 8] + DWORD($698098d8)); { 9 }
  FF(d, a, b, c, S12, Buf[ 9] + DWORD($8b44f7af)); { 10 }
  FF(c, d, a, b, S13, Buf[10] + DWORD($ffff5bb1)); { 11 }
  FF(b, c, d, a, S14, Buf[11] + DWORD($895cd7be)); { 12 }
  FF(a, b, c, d, S11, Buf[12] + DWORD($6b901122)); { 13 }
  FF(d, a, b, c, S12, Buf[13] + DWORD($fd987193)); { 14 }
  FF(c, d, a, b, S13, Buf[14] + DWORD($a679438e)); { 15 }
  FF(b, c, d, a, S14, Buf[15] + DWORD($49b40821)); { 16 }

  { Round 2 }
  GG(a, b, c, d, S21, Buf[ 1] + DWORD($f61e2562)); { 17 }
  GG(d, a, b, c, S22, Buf[ 6] + DWORD($c040b340)); { 18 }
  GG(c, d, a, b, S23, Buf[11] + DWORD($265e5a51)); { 19 }
  GG(b, c, d, a, S24, Buf[ 0] + DWORD($e9b6c7aa)); { 20 }
  GG(a, b, c, d, S21, Buf[ 5] + DWORD($d62f105d)); { 21 }
  GG(d, a, b, c, S22, Buf[10] + DWORD($02441453)); { 22 }
  GG(c, d, a, b, S23, Buf[15] + DWORD($d8a1e681)); { 23 }
  GG(b, c, d, a, S24, Buf[ 4] + DWORD($e7d3fbc8)); { 24 }
  GG(a, b, c, d, S21, Buf[ 9] + DWORD($21e1cde6)); { 25 }
  GG(d, a, b, c, S22, Buf[14] + DWORD($c33707d6)); { 26 }
  GG(c, d, a, b, S23, Buf[ 3] + DWORD($f4d50d87)); { 27 }
  GG(b, c, d, a, S24, Buf[ 8] + DWORD($455a14ed)); { 28 }
  GG(a, b, c, d, S21, Buf[13] + DWORD($a9e3e905)); { 29 }
  GG(d, a, b, c, S22, Buf[ 2] + DWORD($fcefa3f8)); { 30 }
  GG(c, d, a, b, S23, Buf[ 7] + DWORD($676f02d9)); { 31 }
  GG(b, c, d, a, S24, Buf[12] + DWORD($8d2a4c8a)); { 32 }

  { Round 3 }
  HH(a, b, c, d, S31, Buf[ 5] + DWORD($fffa3942)); { 33 }
  HH(d, a, b, c, S32, Buf[ 8] + DWORD($8771f681)); { 34 }
  HH(c, d, a, b, S33, Buf[11] + DWORD($6d9d6122)); { 35 }
  HH(b, c, d, a, S34, Buf[14] + DWORD($fde5380c)); { 36 }
  HH(a, b, c, d, S31, Buf[ 1] + DWORD($a4beea44)); { 37 }
  HH(d, a, b, c, S32, Buf[ 4] + DWORD($4bdecfa9)); { 38 }
  HH(c, d, a, b, S33, Buf[ 7] + DWORD($f6bb4b60)); { 39 }
  HH(b, c, d, a, S34, Buf[10] + DWORD($bebfbc70)); { 40 }
  HH(a, b, c, d, S31, Buf[13] + DWORD($289b7ec6)); { 41 }
  HH(d, a, b, c, S32, Buf[ 0] + DWORD($eaa127fa)); { 42 }
  HH(c, d, a, b, S33, Buf[ 3] + DWORD($d4ef3085)); { 43 }
  HH(b, c, d, a, S34, Buf[ 6] + DWORD($04881d05)); { 44 }
  HH(a, b, c, d, S31, Buf[ 9] + DWORD($d9d4d039)); { 45 }
  HH(d, a, b, c, S32, Buf[12] + DWORD($e6db99e5)); { 46 }
  HH(c, d, a, b, S33, Buf[15] + DWORD($1fa27cf8)); { 47 }
  HH(b, c, d, a, S34, Buf[ 2] + DWORD($c4ac5665)); { 48 }

  { Round 4 }
  II(a, b, c, d, S41, Buf[ 0] + DWORD($f4292244)); { 49 }
  II(d, a, b, c, S42, Buf[ 7] + DWORD($432aff97)); { 50 }
  II(c, d, a, b, S43, Buf[14] + DWORD($ab9423a7)); { 51 }
  II(b, c, d, a, S44, Buf[ 5] + DWORD($fc93a039)); { 52 }
  II(a, b, c, d, S41, Buf[12] + DWORD($655b59c3)); { 53 }
  II(d, a, b, c, S42, Buf[ 3] + DWORD($8f0ccc92)); { 54 }
  II(c, d, a, b, S43, Buf[10] + DWORD($ffeff47d)); { 55 }
  II(b, c, d, a, S44, Buf[ 1] + DWORD($85845dd1)); { 56 }
  II(a, b, c, d, S41, Buf[ 8] + DWORD($6fa87e4f)); { 57 }
  II(d, a, b, c, S42, Buf[15] + DWORD($fe2ce6e0)); { 58 }
  II(c, d, a, b, S43, Buf[ 6] + DWORD($a3014314)); { 59 }
  II(b, c, d, a, S44, Buf[13] + DWORD($4e0811a1)); { 60 }
  II(a, b, c, d, S41, Buf[ 4] + DWORD($f7537e82)); { 61 }
  II(d, a, b, c, S42, Buf[11] + DWORD($bd3af235)); { 62 }
  II(c, d, a, b, S43, Buf[ 2] + DWORD($2ad7d2bb)); { 63 }
  II(b, c, d, a, S44, Buf[ 9] + DWORD($eb86d391)); { 64 }

  Inc(State[0], a);
  Inc(State[1], b);
  Inc(State[2], c);
  Inc(State[3], d);
end;

{ MD5 finalization. Ends an MD5 message-digest operation, }
{ writing the message digest and zeroing the context.     }
procedure MD5Final(var Digest : TIpMD5Digest; var Context : TIpMD5Context);
var
  I : Integer;
  P : Byte;
begin
  I := (Context.Count[0] shr 3) and $3F;
  Context.ByteBuf[I] := $80;
  P := Succ(I);
  I := Pred(64)-I;

  { Pad appropriately }
  if I < 8 then begin
    FillChar(Context.ByteBuf[P], I, #0);
    MD5Transform(Context.State, Context.LongBuf);
    FillChar(Context.ByteBuf, 56, #0);
  end else begin
    FillChar(Context.ByteBuf[P], I-8, #0);
  end;

  { Set count in context }
  Context.LongBuf[14] := Context.Count[0];
  Context.LongBuf[15] := Context.Count[1];

  MD5Transform(Context.State, Context.LongBuf);
  Move(Context.State, Digest, 16);

  { Zero out Context }
  FillChar(Context, SizeOf(TIpMD5Context), #0);
end;

{ Calculates the MD5 Digest of a block -- RFC 1321 }
procedure MD5SumPrim(const Data; DataSize : DWORD; var Context : TIpMD5Context);
var
  I, J : DWORD;
begin
  J := Context.Count[0];
  Inc(Context.Count[0], DWORD(DataSize) shl 3);
  if Context.Count[0] < J then
    Inc(Context.Count[1]);
  Inc(Context.Count[1], DataSize shr 29);

  J := (J shr 3) and $3F;
  if J <> 0 then begin
    I := J;
    J := 64 - J;
    if DataSize < J then begin
      Move(Data, Context.ByteBuf[I], DataSize);
      Exit;
    end;
    Move(Data, Context.ByteBuf[I], J);
    MD5Transform(Context.State, Context.LongBuf);
    Dec(DataSize, J);
  end;

  I := J;
  while DataSize >= 64 do begin
    Move(TByteArray(Data)[I], Context.ByteBuf, 64);
    MD5Transform(Context.State, Context.LongBuf);
    Inc(I, 64);
    Dec(DataSize, 64);
  end;

  Move(TByteArray(Data)[I], Context.ByteBuf, DataSize);
end;

{ Calculates the MD5 Digest of a file }
function MD5SumOfFile(const FileName : string) : string;
var
  FileSt : TFileStream;
begin
  FileSt := TFileStream.Create(FileName, CrcFileMode);
  try
    Result := MD5SumOfStream(FileSt);
  finally
    FileSt.Free;
  end;
end;

{ Return hex string representing MD5 digest }
function HexDigest(Digest : TIpMD5Digest) : string;
const
  HexDigits : array[0..$F] of AnsiChar = '0123456789abcdef';
var
  I : Integer;
begin
  SetLength(Result, 32);

  { Generate output string }
  for I := 0 to 15 do begin
    Result[(I shl 1) + 1] := HexDigits[Digest[I] shr 4];
    Result[(I shl 1) + 2] := HexDigits[Digest[I] and $F];
  end;
end;

{ Calculates the MD5 Digest of a stream }
function MD5SumOfStream(Stream : TStream) : string;
begin
  Result := HexDigest(MD5SumOfStreamDigest(Stream));
end;

{ Calculates the MD5 Digest of a stream }
function MD5SumOfStreamDigest(Stream : TStream) : TIpMD5Digest;
var
  BufArray : array[0..(CrcBufSize-1)] of Byte;
  Context  : TIpMD5Context;
  I, Res   : Integer;
begin
  { Init Digest }
  for I := 0 to 15 do
    Byte(Result[I]) := Succ(I);

  { Init Context }
  MD5Init(Context);
  repeat
    Res := Stream.Read(BufArray, CrcBufSize);
    MD5SumPrim(BufArray, Res, Context);
  until (Res <> CrcBufSize);

  { Finalize }
  MD5Final(Result, Context);
end;

{ Calculates the MD5 Digest of a string }
function MD5SumOfString(const S : string) : string;
var
  Context  : TIpMD5Context;
  Digest   : TIpMD5Digest;
  I : Byte;
begin
  Result := '';

  { Init Digest }
  for I := 0 to 15 do
    Digest[I] := Succ(I);

  { Init Context }
  MD5Init(Context);
  MD5SumPrim(S[1], Length(S), Context);

  { Finalize }
  MD5Final(Digest, Context);

  { Generate output string }
  Result := HexDigest(Digest);
end;

{ Calculates the MD5 Digest of a string }
function MD5SumOfStringDigest(const S : string) : TIpMD5Digest;
var
  Context  : TIpMD5Context;      
  I : Byte;
begin
  { Init Digest }
  for I := 0 to 15 do
    Result[I] := Succ(I);

  { Init Context }
  MD5Init(Context);
  MD5SumPrim(S[1], Length(S), Context);

  { Finalize }
  MD5Final(Result, Context);
end;

{ Compares two fixed size structures }
function IpCompStruct(const S1, S2; Size : Cardinal) : Integer;
{$IFDEF CPUI386}
asm
  push   edi
  push   esi
  mov    esi, eax
  mov    edi, edx
  xor    eax, eax
  or     ecx, ecx
  jz     @@CSDone

  repe   cmpsb
  je     @@CSDone

  inc    eax
  ja     @@CSDone
  or     eax, -1

@@CSDone:
  pop    esi
  pop    edi
end;
{$ELSE}
begin
  Result := CompareMemRange(@S1, @S2, Size);
end;
{$ENDIF}

function IpCharCount(const Buffer; BufSize : DWORD; C : AnsiChar) : DWORD;
  register;
{$IFDEF CPUI386}
asm
  push  ebx
  xor   ebx, ebx
  or    edx, edx
  jz    @@Done
  jmp   @@5

@@Loop:
  cmp   cl, [eax+3]
  jne   @@1
  inc   ebx

@@1:
  cmp   cl, [eax+2]
  jne   @@2
  inc   ebx

@@2:
  cmp   cl, [eax+1]
  jne   @@3
  inc   ebx

@@3:
  cmp   cl, [eax+0]
  jne   @@4
  inc   ebx

@@4:
  add   eax, 4
  sub   edx, 4

@@5:
  cmp   edx, 4
  jge   @@Loop

  cmp   edx, 3
  je    @@1

  cmp   edx, 2
  je    @@2

  cmp   edx, 1
  je    @@3

@@Done:
  mov   eax, ebx
  pop   ebx
end;
{$ELSE}
var
X: Integer;
begin
  Result := 0;
  for X := 0 to Bufsize-1 do begin
    if PChar(@Buffer)[X] = C then Inc(Result);
  end;
end;
{$ENDIF}


function IpMaxInt(A, B : Integer) : Integer;
begin
  if A >= B then
    Result := A
  else
    Result := B;
end;

function IpMinInt(A, B : Integer) : Integer;
begin
  if A <= B then
    Result := A
  else
    Result := B;
end;



{ Thread safe object free }
procedure IpSafeFree(var Obj);
var
  P : TObject;
begin
  P := TObject(Obj);
  { Clear reference }
  TObject(Obj) := nil;
  { Destroy object }
  P.Free;
end;

{ Return short version string }
function IpShortVersion : string;
begin
  Result := Format(sShortVersion, [InternetProfessionalVersion]);
end;

{ TIpBaseAccess }

{ Create instance of TIpBaseAccess }
constructor TIpBaseAccess.Create;
begin
  inherited;
  InitializeCriticalSection(baPropCS);
end;

{ Destroy instance of TIpBaseAccess }
destructor TIpBaseAccess.Destroy;
begin
  DeleteCriticalSection(baPropCS);
  inherited;
end;

{ Enters TIpBaseAccess critical section }
procedure TIpBaseAccess.LockProperties;
begin
  if IsMultiThread then
    EnterCriticalSection(baPropCS);
end;

{ Leaves TIpBaseAccess critical section }
procedure TIpBaseAccess.UnlockProperties;
begin
  if IsMultiThread then
    LeaveCriticalSection(baPropCS);
end;

{ TIpBasePersistent }

{ Create instance of TIpBasePersistent }
constructor TIpBasePersistent.Create;
begin
  inherited;
  InitializeCriticalSection(bpPropCS);
end;

{ Destroy instance of TIpBasePersistent }
destructor TIpBasePersistent.Destroy;
begin
  DeleteCriticalSection(bpPropCS);
  inherited;
end;

{ Enters TIpBasePersistent critical section }
procedure TIpBasePersistent.LockProperties;
begin
  if IsMultiThread then
    EnterCriticalSection(bpPropCS);
end;

{ Leaves TIpBasePersistent critical section }
procedure TIpBasePersistent.UnlockProperties;
begin
  if IsMultiThread then
    LeaveCriticalSection(bpPropCS);
end;

{ TIpBaseComponent }

function TIpBaseComponent.GetVersion: string;
begin
  Result := IpShortVersion;
end;

{ Returns an appropriate string for the given parameters }
class function TIpBaseComponent.GetLogString(const S, D1, D2, D3: DWORD): string;
begin
  if (S=0) or (D1=0) or (D2=0) or (D3=0) then ; // avoid hints
    Result := '!!!! Unhandled log entry'#10#13;
end;

procedure TIpBaseComponent.SetVersion(const Value: string);
begin
  if (Value='') then ; // avoid hints
  { Intentionally empty }
end;

{ TIpBaseWinControl }

function TIpBaseWinControl.GetVersion : string;
begin
  Result := IpShortVersion;
end;

procedure TIpBaseWinControl.SetVersion(const Value : string);
begin
  if (Value='') then ; // avoid hints
  { Intentionally empty }
end;

{ address handling }

{ Apply Internet escaping (%nn) to characters in EscapeSet found in S }
function PutEscapes(const S : string; EscapeSet : CharSet) : string;
var
  Temp, Rep : string;
  i : Integer;
begin
  Temp := S;

  i := 1;
  while i <= Length(Temp) do begin
    if Temp[i] in EscapeSet then begin
      { Internet escapes of the form %nn where }
      { n is the ASCII character number in Hex }
      Rep := '%' + Format('%2x', [Ord(Temp[i])]);
      Delete(Temp, i, 1);
      Insert(Rep, Temp, i);
      Inc(i, 3);
    end
    else
      Inc(i);
  end;
  Result := Temp;
end;

{ Convert Internet escapes to ASCII equivalents }
function RemoveEscapes(const S : string; EscapeSet : CharSet) : string;
var
  Temp, Start, EscStr : string;
  P : Integer;
  C : AnsiChar;
begin
  Temp := S;
  Start := '';

  P := CharPos('%', Temp);

  while P > 0 do begin
    Start := Start + Copy(Temp, 1, P-1);
    EscStr := Copy(Temp, P + 1, 2);
    C := Chr(StrToInt('$' + EscStr));

    if C in EscapeSet then begin
      Start := Start + C;
    end
    else begin
      Start := Start + EscStr;
    end;

    Temp := Copy(Temp, P + 3, Length(Temp) - 3);
    P := CharPos('%', Temp);
  end;

  Result := Start + Temp;
end;

{ Convert Internet file characters to DOS }
{ * maps '|' -> ':' }
{        '/' -> '\' }
function NetToDOSPath(const PathStr : string) : string;
var
  i : Integer;
begin
  Result := PathStr;
  for i := 1 to Length(Result) do begin
    case Result[i] of
      '|': Result[i] := ':';
      '/': Result[i] := DirectorySeparator;
    else
      { leave it alone };
    end;
  end;

  if (CharPos('\', Result) = 1) and (CharPos(':', Result) > 0) then
    Result := Copy(Result, 2, Length(Result) - 1);
end;

function DOSToNetPath(const PathStr : string) : string;
{ Convert DOS file characters to Internet }
{ * maps ':' -> '|' }
{       '\' -> '/'  }
var
  i : Integer;
begin
  Result := PathStr;
  for i := 1 to Length(Result) do begin
    case Result[i] of
      ':': Result[i] := '|';
      DirectorySeparator: Result[i] := '/';
    else
      { leave it alone };
    end;
  end;
end;


function IpParseURL(const URL : string; var Rslt : TIpAddrRec) : Boolean;
{ Splits URL into components }

{ -- rewritten
  - Parsing UserName and Password fields out of Mailto: urls of the form:
      mailto:user:pass@myserver.net
  - Username and Password fields added to TIpAddrRec in support of
    additional IpParseUrl capabilities
  - Handling URL Fragments and Queries on local files
  - Improved recognition of relative paths
  - Improved recognition of "LocalHost" style Authorities
}

{
Algorithm:
1. Leading spaces ignored
2. Start of string:
   - Any starting alphabetic character is accumulated into a "Potential
     Authority" (PA) string
   - If the first character is a digit URL is assumed to be starting with a
     numeric format IP address
   - If the first character is a period ('.') or a slash ('/', '\') the URL is
     considered to be a relative path
4. If a PA has been started:
   - alphanumeric characters are accumulated into the PA
   - if a ':' or '|' are encountered and there is only one character in
     the preceding PA, the PA is assumed to be a drive letter for a local
     file and the rest of the URL is handled accordingly
   - if there is more than one character in the PA when the ':' is encountered,
     and if the PA contains at least one period ('.') it is assumed to be an
     authority, otherwise it is assumed to be a scheme (e.g. HTTP), the ':' is
     assumed to be delimiting between an authority and a port ID and the PA
     string is handled accordingly
   - if a '.' is encountered prior to seeing a '/' then the PA is assumed to be
     an authority.
   - if a '/' is encountered, the PA is assumed to be an authority
   - if a '@' is encountered the present PA is assumed to be a username, and
     PA accumulation is re-started
   - any other non-specified character is assumed to indicate an Authority
5. If a character indicating the end of the PA has been encountered:
   - if numeric characters are seen after a ':' these are assumed to be a port ID
   - if alphabetic characters are seen they are assumed to be part of a password
   - if a slash is encountered the PA is assumed to be a scheme
   - if an '@' or ':' is encountered the PA is assumed to be a UserName.
       On '@' the assumption is the Authority is starting.
       On ':' the assumption is a password is starting.
6. Slashes following a scheme:
   - all forward slashes (if any) following a scheme are ignored
   - if a '.' or '\' is found immediately after the scheme slashes, it's assumed
     to indicate the start of a local relative path
7. Password accumulation:
   - non-'@' characters are considered part of the password
   - if an '@' is encountered it's considered the start of the authority and
     actual authority accumulatino is started
8. Authority Accumulation:
   - characters in the set ['A'..'Z', 'a'..'z', '0'..'9', '.', '-', '_'] are
     accumulated into the authority
   - a ':' is assumed to indicate the end of the authority and the start of a
     Port ID
   - a '/' is assumed to indicate the end of the authority and the start of a
     path
   - a space (' ') is assumed to indicate trailing spaces on the URL
9. Port has started:
   - numeric characters are accumulated into the Port
   - a '/' is assumed to indicate the start of a path
   - a ' ' is assumed to indicate trailing spaces on the url
10. Path has started:
   - characters not in the set ['#', '?', '&'] are accumulated into the Path
   - a '#' is assumed to indicate the start of a Fragment
   - a '?' or '&' is assumed to indicate the start of a Query
11. Fragment has started:
   - characters not in the set ['?', '&', ' '] are accumulated into the Fragment
   - a '?' or '&' is assumed to indicate the start of a Query
   - a ' ' is assumed to indicate trailing spaces on the url
12. Query has started:
   - non space characters are accumulated into the Fragment
   - a ' ' is assumed to indicate trailing spaces on the url
13. Trailing spaces
   - ignored
}

type
  TUrlParseState = (
    psStart, psError, psStartSp, psPotAuth, psEoPotAuth, psSchemeSlashes,
    psLocalPath, psAuthority, psUserName, psPassword, psPort, psPath,
    psFragment, psQuery, psEndSp
  );
const
  UrlStops : set of TUrlParseState = [psPath, psLocalPath, psAuthority, psPort,
    psFragment, psQuery, psEndSp];

var
  P : PChar;
  i : Integer;
  State : TUrlParseState;
  PotAuth, PotPath : string;
  SchemeSeen: Boolean;
  SlashCount: integer;

procedure ProcessChar;
begin
  case State of
    psStart: begin
      case P^ of
        ' ': begin
          State := psStartSp;
        end;

        'A'..'Z', 'a'..'z': begin
          PotAuth := PotAuth + P^;
          State := psPotAuth;
        end;

        '0'..'9': begin
          Rslt.Authority := Rslt.Authority + P^;
          State := psAuthority;
        end;

        '.', '/', '\' : begin
          PotPath := PotPath + P^;
          State := psPath;
        end;

        else
          State := psError;
      end;
    end;

    psStartSp: begin
      case P^ of
        ' ': { ignore };

        'A'..'Z', 'a'..'z', '-', '_': begin
          PotAuth := PotAuth + P^;
          State := psPotAuth;
        end;

        '0'..'9': begin
          Rslt.Authority := Rslt.Authority + P^;
          State := psAuthority;
        end;

        '.', '/', '\' : begin
          PotPath := PotPath + P^;
          State := psPath;
        end;

        else
          State := psError;
      end;
    end;

    psPotAuth: begin
      case P^ of
        'A'..'Z', 'a'..'z', '0'..'9', '.', '-', '_': begin
          PotAuth := PotAuth + P^;
        end;

        ':', '|': begin
          if Length(PotAuth) = 1 then begin
            PotPath := PotAuth + P^;
            PotAuth := '';
            State := psLocalPath;
          end
          else begin

            if Pos('.', PotAuth) > 0 then begin
              Rslt.Authority := PotAuth;
              State := psPort;
            end
            else
            if (Rslt.Scheme = '') then begin
              Rslt.Scheme := PotAuth;
              SchemeSeen := True;
              PotAuth := '';
              State := psSchemeSlashes;
              SlashCount := 0;
            end
            else begin

              State := psEoPotAuth;
            end;
          end;
        end;


        '/', '\': begin
          if SchemeSeen then
            Rslt.Authority := PotAuth
          else begin
            if Pos('.', PotAuth) > 0 then
              Rslt.Authority := PotAuth
            else
              PotPath := PotAuth;
          end;
          PotAuth := '';
          PotPath := PotPath + P^;
          State := psPath;
        end;

        '@': begin
          Rslt.UserName := PotAuth;
          PotAuth := '';
          State := psAuthority;
        end;

        else begin
          Rslt.Authority := PotAuth;
          PotAuth := '';
          State := psAuthority;
        end;

      end;

    end;

    psEoPotAuth: begin
      case P^ of
        '0'..'9': begin
          Rslt.Authority := PotAuth;
          PotAuth := '';
          Rslt.Port := Rslt.Port + P^;
          State := psPort;
        end;

        '/', '\': begin
          Rslt.Scheme := PotAuth;
          SchemeSeen := True;
          PotAuth := '';
          State := psSchemeSlashes;
          SlashCount := 0;
        end;

        'A'..'Z', 'a'..'z': begin
          Rslt.UserName := PotAuth;
          PotAuth := '';
          Rslt.Password := Rslt.Password + P^;
          State := psPassword;
        end;

        '@': begin
          Rslt.UserName := PotAuth;
          PotAuth := '';
          State := psAuthority;
        end;

        ':': begin
          Rslt.UserName := PotAuth;
          PotAuth := '';
          State := psPassword;
        end;

      end;

    end;

    psSchemeSlashes: begin
      inc(SlashCount);
      if (p^ <> '/') or (SlashCount > 2) then
        case P^ of
          '.', '\','/': begin { start of a local path }
            PotPath := PotPath + P^;
            State := psLocalPath;
          end;

          else begin
            if CharPos('@', URL) > 0 then begin
              PotAuth := P^;
              State := psUserName;
            end
            else begin
              PotAuth := P^;
              State := psPotAuth;
            end;
          end;
        end;
    end;


    psLocalPath: begin
      case P^ of
        '#': begin
          if PotPath <> '' then
            Rslt.Path := AllTrimSpaces(PotPath);
          State := psFragment;
        end;

        '?', '&': begin
          if PotPath <> '' then
            Rslt.Path := AllTrimSpaces(PotPath);
          Rslt.QueryDelim := P^;
          State := psQuery;
        end;

        else
          PotPath := PotPath + P^;
      end;
    end;

    psAuthority: begin
      case P^ of
        'A'..'Z', 'a'..'z', '0'..'9', '.', '-', '_' : begin
          Rslt.Authority := Rslt.Authority + P^;
        end;

        ':': begin
          State := psPort;
        end;

        ' ': begin
          State := psEndSp;
        end;

        '/', '\': begin
          PotPath := PotPath + P^;
          State := psPath;
        end;
      end;
    end;

    psUserName: begin
      case P^ of
        '@': begin
          Rslt.UserName := PotAuth;
          PotAuth := '';
          State := psAuthority;
        end;

        ':', '|': begin
          if Length(PotAuth) = 1 then begin
            PotPath := PotAuth + P^;
            PotAuth := '';
            State := psLocalPath;
          end
          else begin
            Rslt.UserName := PotAuth;
            PotAuth := '';
            State := psPassword;
          end;
        end;

        else
          PotAuth := PotAuth + P^;
      end;
    end;

    psPassword: begin
      case P^ of
        '@': begin
          State := psAuthority;
        end;

        else begin
          Rslt.Password := Rslt.Password + P^;
        end;
      end;
    end;

    psPort: begin
      case P^ of
        '0'..'9': begin
          Rslt.Port := Rslt.Port + P^;
        end;

        '/', '\': begin
          PotPath := PotPath + P^;
          State := psPath;
        end;

        ' ': begin
          State := psEndSp;
        end;

        else
          State := psError;
      end;
    end;

    psPath: begin
      case P^ of
        '#': begin
          if PotPath <> '' then begin
            Rslt.Path := AllTrimSpaces(PotPath);
            PotPath := '';
          end;
          State := psFragment;
        end;

        '?', '&' : begin
          if PotPath <> '' then begin
            Rslt.Path := AllTrimSpaces(PotPath);
            PotPath := '';
          end;
          Rslt.QueryDelim := P^;
          State := psQuery;
        end;

        ' ': begin
          State := psEndSp;
        end;

        else
          PotPath := PotPath + P^;
      end;
    end;

{ Extract "Fragment" (in-page reference) portion of URL }

{ - If URL contains an Entity name then Fragment should be delimited by a '#' }
{ - If URL does not contain Entity name then Fragment may immediately follow a }
{  final slash in the URL's "Path" component, but must still be delimited by }
{  a '#' to indicate that it is a Fragment.  In this case the assumption is }
{  that the Fragment refers to the current page }

    psFragment: begin
      case P^ of
        '?', '&': begin
          if PotPath <> '' then begin
            Rslt.Path := AllTrimSpaces(PotPath);
            PotPath := '';
          end;
          Rslt.QueryDelim := P^;
          State := psQuery;
        end;

        else
          Rslt.Fragment := Rslt.Fragment + P^;
      end;
    end;

{ Extract "Query" portion of URL }

{ - If URL contains an Entity name and/or Fragment then Query should }
{  be delimited by a '?' }
{ - If URL does not contain Entity name and/or Fragment then Query may or may }
{  not be delimited by a '?' }
{ - Individual elements/parameters within the query typically appear in }
{  <name>=<value> pairs separated by '&' characters }
{ See also: SplitParams() and FieldFix() routines }

    psQuery: begin
      case P^ of
        ' ': begin
          State := psEndSp;
        end;

        else
          Rslt.Query := Rslt.Query + P^;
      end;
    end;

    psEndSp: begin
      case P^ of
        ' ' : { ignore };

        else
          State := psError;
      end;
    end;

    psError: begin
    end;
  end {case State };
end;


begin
  Rslt.Scheme    := '';
  Rslt.Authority := '';
  Rslt.UserName  := '';
  Rslt.Password  := '';
  Rslt.Port      := '';
  Rslt.Path      := '';
  Rslt.Fragment  := '';
  Rslt.Query     := '';

  P := @URL[1];
  State := psStart;

//  Result := False;
  PotAuth := '';
  PotPath := '';

  SchemeSeen := False;
  for i := 1 to Length(URL) do begin
    ProcessChar;
    if State = psError then
      Break;
    Inc(P);
  end;

  if PotAuth <> '' then
    Rslt.Authority := PotAuth;


  if Rslt.Path = '' then begin
    if PotPath <> '' then
      Rslt.Path := AllTrimSpaces(PotPath)
    else
      Rslt.Path := '/';
  end;

  Result := State in UrlStops;
end;


{ Build absolute URL from a starting URL (Old) and a new URL (New) }

{ * Old may be empty }
{ * New may be a full address or a path relative to Old }
{ * "FILE://" references are converted for Internet (':'=>'|', '\'=>'/') }
{ * Attempts to handle relative paths containing one or more "../" references }
{   intelligently, but does no error checking that there are sufficient higher }
{   levels in Old to account for the number of "../" levels in New }
{ Change for FPC: renamed Old, New to OldURL, NewURL }
function BuildURL(const OldURL, NewURL: string): string;
var
  OldAddrRec : TIpAddrRec;
  NewAddrRec : TIpAddrRec;
  FoundPos : Integer;
  RelPos : Integer;
  ParentPos : Integer;
  Path : string;
  Scheme : string;
  Port : string;
begin
  Result := '';
  Path := '';

  { sanity checks }
  if (OldURL = '') and (NewURL = '') then begin
    Result := '';
    Exit;
  end;

  if (OldURL = '') and (NewURL <> '') then begin
    Result := NewURL;
    Exit;
  end;

  if (OldURL <> '') and (NewURL = '') then begin
    Result := OldURL;
    Exit;
  end;

  { Main processing }
  Result := DOSToNetPath(OldURL);

  Initialize(OldAddrRec);
  Initialize(NewAddrRec);

  IpParseURL(OldURL, OldAddrRec);
  IpParseURL(NewURL, NewAddrRec);

  if OldAddrRec.Scheme = '' then
    Scheme := ''
  else
    Scheme := OldAddrRec.Scheme + '://';

  if OldAddrRec.Port = '' then
    Port := ''
  else
    Port := ':' + OldAddrRec.Port;

  if CompareText(NewAddrRec.Scheme, 'FILE') = 0 then begin
    { New is a local file }
    Result := NewAddrRec.Scheme + '://' + NewAddrRec.Path;
  end else if NewAddrRec.Scheme <> '' then begin
    { New is a full address in its own right }
    Result := NewURL;  { so just return that }
  end else if (NewAddrRec.Scheme = '') and (NewURL[1] = '/') then begin
    { New is probably a direct path off the Root }
    Result := Scheme + OldAddrRec.Authority + Port; { build Root }
    if (NewURL <> '') and (NewURL[1] <> '/') then
      Result := Result + '/';
    Result := Result + NewURL;  { just append }
  end else if (NewAddrRec.Scheme = '') and (NewURL[1] <> '.') then begin
    { New is probably a direct path off the current path }
    if CompareText(OldAddrRec.Scheme, 'FILE') = 0 then begin
      Path := ExtractFilePath(OldAddrRec.Path);
      Result := Scheme + Path;
    end
    else begin
      Path := ExtractEntityPath(DosToNetPath(OldAddrRec.Path));
      if (Path <> '') and (Path[1] = '/') then
        Path := Copy(Path, 2, Length(Path) - 1);
      Result := Scheme;

      if OldAddrRec.Authority <> '' then
        Result := Result + OldAddrRec.Authority + Port + '/';

      if Path <> '' then
        Result := Result + AppendSlash(Path);
    end;

    Result := Result + NewURL;

    Exit;
  end else begin
    { otherwise New should be a relative path of Old }
    Path := AppendSlash(ExtractEntityPath(DOSToNetPath(OldAddrRec.Path)));
    FoundPos := PosIdx('../', NewURL, 1);
    RelPos := FoundPos + 3;
    ParentPos := RCharPosIdx('/', Path, Length(Path));
    while (FoundPos > 0) do begin
      FoundPos := PosIdx('../', NewURL, FoundPos + 3);
      if FoundPos > 0 then
        RelPos := FoundPos + 3;
      ParentPos := RCharPosIdx('/', Path, ParentPos - 1);
    end;

    Path := AppendSlash(Copy(Path, 1, ParentPos));
    Result := Scheme + OldAddrRec.Authority + Path +
      Copy(NewURL, RelPos, Length(NewURL) - RelPos + 1);

    { remove shorthand for current directory if it exists }
    FoundPos := Pos('/./', Result);
    if FoundPos > 0 then
      Delete(Result, FoundPos, 2);
  end;

  Path := OldURL;
  Finalize(OldAddrRec);
  Finalize(NewAddrRec);
end;

{ Split Internet formated (ampersand '&' separated) parameters }
{ from Parms into Dest }
procedure SplitParams(const Parms : string; Dest : TStrings);
var
  P : Integer;
  Temp : string;
begin
  if not Assigned(Dest) then
    Exit;

  Dest.Clear;

  Temp := Parms;

  P := CharPos('&', Temp);
  while P > 0 do begin
    Dest.Add(Copy(Temp, 1, P - 1));
    Temp := Copy(Temp, P + 1, Length(Temp) - P);
    P := CharPos('&', Temp);
  end;
  Dest.Add(Temp);
end;

{ Divide HTTP response header line into individual fields }
{ - HTTP response in the form of: }
{      "HTTP/"<HTTP Version><SP><HTTP Message ID#><SP><HTTP Message String> }
{   for example, if "HTTP/1.1 200 OK" passed in S, procedure returns }
{     "1.1" in V }
{     "200" in MsgID }
{     "OK"  in Msg }
procedure SplitHttpResponse(const S: string; var V, MsgID, Msg: string);
var
  P: Integer;
  Temp: string;
begin
  Temp := S;
  P := CharPos(' ', Temp);
  V := Copy(Temp, 6, P - 6);
  Temp := Copy(Temp, P + 1, Length(Temp) - P);
  P := CharPos(' ', Temp);
  MsgID := Copy(Temp, 1, P - 1);
  Msg := Copy(Temp, P + 1, Length(Temp) - P);
end;

{ Convert HTTP Header into TStrings parseable by Name=Value mechanism      }
{ - Basically just converts HTTP header fields of the form <NAME>: <VALUE> }
{   pairs into <NAME>=<VALUE> pairs.    }
{ - Also parses HTTP header associating }
{     Full header ->       "FullHead="  }
{     HTTP version ->      "Version="   }
{     HTTP Message ID# ->  "MsgID="     }
{     HTTP Message Text -> "Message="   }
procedure FieldFix(Fields : TStrings);
var
  i, P : Integer;
  S, Ver, ID, Msg : string;
begin
  if Fields.Count > 0 then begin
    S := Fields[0];
    Fields.Delete(0);

    SplitHttpResponse(S, Ver, ID, Msg);
    Fields.Insert(0, 'Message=' + Msg);
    Fields.Insert(0, 'MsgID=' + ID);
    Fields.Insert(0, 'Version=' + Ver);
    Fields.Insert(0, 'FullHead=' + S);


    for i := 4 to Pred(Fields.Count) do begin
      P := CharPos(':', Fields[i]);
      if P > 0 then begin
        S := Fields[i];
        Delete(S, P, 1);
        Insert('=', S, P);
        Fields.Delete(i);
        Fields.Insert(i,S);
      end;
    end;
  end;
end;

{ Append slash to Internet path if needed }
function AppendSlash(APath : string) : string;
begin
  Result := APath;
  if (Result <> '') and (Result[Length(APath)] <> '/') then
    Result := Result + '/';
end;

{ Drop trailing slash from Internet path if needed }
function RemoveSlash(APath : string) : string;
begin
  Result := APath;
  if Result[Length(Result)] = '/' then
    Delete(Result, Length(Result), 1);
end;

{ Extract Entity (Filename) portion of Internet Path }
{ Parallel to SysUtils.ExtractFileName for Internet Paths }
function ExtractEntityName(const NamePath : string) : string;
var
  P : Integer;
  Temp : string;
begin
  Result := '';
  P := RCharPos('/', NamePath);
  if P > 0 then begin
    Temp := Copy(NamePath, P + 1, Length(NamePath) - P);

    if CharPos('.', Temp) > 0 then
      Result := Temp
    else
      Result := '';
  end;
end;

{ Extract Path (non-filename) portion of Internet Path }
{ Parallel to SysUtils.ExtractFilePath for Internet Paths }
function ExtractEntityPath(const NamePath: string): string;
var
  P : Integer;
begin
  P := RCharPos('/', NamePath);
  if P = Length(NamePath) then { no file name on Path }
    Result := NamePath
  else
    Result := Copy(NamePath, 1, P);
end;

{ Return next highest level in Internet path }
{ e.g. if Path parameter contains "/default/pub/pics/jpgs" }
{ function would return "/default/pub/pics" }
function GetParentPath(const Path : string) : string;
var
  P : Integer;
begin
  if Path = '/' then begin
    Result := Path;
    Exit;
  end;
  P := Length(Path);
  if Path[P] = '/' then
    Dec(P);
  while Path[P] <> '/' do
    Dec(P);
  Result := Copy(Path, 1, P);
end;

{ date stuff }
const
  EpochYear = 70;  { UNIX Julian time count starts in 1970 }
  EpochLowStr = '19';
  EpochHiStr  = '20';
  CanonicalDate = '"%s", dd "%s" yyyy hh:mm:ss "%s00"';

{
Note: The following strings and string arrays are used for
interpreting/building canonical Internet dates and should
NOT be internationalized!
}

{  DayString : string =
    'SUNDAY   ' +
    'MONDAY   ' +
    'TUESDAY  ' +
    'WEDNESDAY' +
    'THURSDAY ' +
    'FRIDAY   ' +
    'SATURDAY '; }

  MonthString : string =
    'JANUARY  ' +
    'FEBRUARY ' +
    'MARCH    ' +
    'APRIL    ' +
    'MAY      ' +
    'JUNE     ' +
    'JULY     ' +
    'AUGUST   ' +
    'SEPTEMBER' +
    'OCTOBER  ' +
    'NOVEMBER ' +
    'DECEMBER ';

  IpMonthsStrings: array[1..12] of string = (
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec');
  IpDOWStrings: array[1..7] of string = (
    'Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat');

type
  THttpDateType = (hdtUnknown, hdtRFC822, hdtRFC850, hdtANSIC);

{ Returns numeric month index [1..12] from any unique string }
{ abbreviation of English month name, returns 0 if no match }
function MonStrToInt(MonStr : string) : Integer;
var
  P : Integer;
begin
  P := PosI(MonStr, MonthString);
  if P > 0 then
    Result := (P div 9) + 1
  else
    Result := 0;
end;

{ For two digit year string passed in returns }
{ four digit year string based on EpochYear constant. }
{ If converting YrStr to an integer yields > 99 then }
{ YrStr is returned unchanged }
function EpochStr(YrStr: string) : string;
var
  Yr: Word;
begin
  Yr := StrToInt(YrStr);
  if (Yr > 99) then begin { not a 2 digit year }
    Result := YrStr;
    Exit;
  end;

  if (Yr < EpochYear) then begin
    Result :=  EpochHiStr + YrStr;
  end
  else begin
    Result := EpochLowStr + YrStr;
  end;
end;


{
Convert an Internet Date string to a TDateTime

If the string isn't in one of the canonical formats (see below)
the Internet start date of Jan 1, 1970 0:0:0:0 is returned

Canonical Internet header date strings are in one of three standard formats:
  Sun, 06 Nov 1994 08:49:37 GMT   ; RFC 822, updated by RFC 1123
  Sunday, 06-Nov-94 08:49:37 GMT  ; RFC 850, obsoleted by RFC 1036
  Sun Nov  6 08:49:37 1994        ; ANSI C's asctime() format
}

{-- rewritten to handle common variants such as the Day or Month name
to be fully spelled out where they are not in the canonical form, or to have
a 4 digit year in the RFC 850 style
}
function INetDateStrToDateTime(const DateStr: string): TDateTime;
type
  TINetDateState = (idStart, idStartSp, idDow, idDowSp, idDay1, idDay1Sp,
  idMon1, idMon1Sp, idMon2, idMon2Sp, idDay2, idYr1,
  idPreTimeSp, idHrs, idMin, idSec, idPostTimeSp, {idGMT,} idYr2,
  idEndSp, idAM, idPM, idDaySpace1, IdTimeZoneNum, IdTimeZoneAlpha,
  idError);

const
  AcceptStates: set of TINetDateState = [{idGMT,} idYr2, idSec,
                                         idPostTimeSp, idEndSp,
                                         idTimeZoneAlpha,
                                         idTimeZoneNum];
var
  Dow, Day, Mon, Year, Hrs, Min, Sec: string;
  Dy, Mo, Yr: Word;
  Hr, Mn, Sc: SmallInt;
  State: TINetDateState;
  P: PChar;
  i : Integer;
  AMPM : Boolean;
  PM : Boolean;
  TimeZone : string;

procedure ParseDate;
begin
  case State of
    idStart: begin
      case P^ of
        ' ' : State := idStartSp;

        'A'..'Z', 'a'..'z' : begin
          State := idDow;
          Dow := Dow + P^;
        end;

        '0'..'9': begin
          State := idDay1;
          Day := Day + P^;
        end;

        else
          State := idError;
      end;
    end;

    idStartSp: begin  { ignore initial spaces }
      case P^ of
        ' ': { ignore };

        'A'..'Z', 'a'..'z' : begin
          State := idDow;
          Dow := Dow + P^;
        end;
        else
          State := idError;
      end;
    end;

    idDow: begin  { all formats start with a DOW string }
      case P^ of
        'A'..'Z', 'a'..'z' : begin
          Dow := Dow + P^;
        end;

        ',', ' ': begin
          State := idDowSp;
        end;
        else
          State := idError;
      end;
    end;

    idDowSp: begin  { ignore spaces following DOW }
      case P^ of
        ' ': { ignore };

        '0'..'9': begin
          State := idDay1;
          Day := Day + P^;
        end;

        'A'..'Z', 'a'..'z' : begin
          State := idMon1;
          Mon := Mon + P^;
        end;

        else
          State := idError;
      end;
    end;

    idDay1: begin  { RFC 822 and 850 formats start with day digit }
      case P^ of
        ' ': begin
          State := idDay1Sp;
        end;

        '-': begin
          State := idMon2;
        end;

        '0'..'9': begin
          Day := Day + P^;
        end;

        else
          State := idError;
      end;
    end;

    idDay1Sp: begin { ignore spaces following day digit }
      case P^ of
        ' ': { ignore };

        'A'..'Z', 'a'..'z' : begin
          State := idMon2;
          Mon := Mon + P^;
        end;

        else
          State := idError;
      end;
    end;

    idMon1: begin  { ANSI C format starts with month string }
      case P^ of
        ' ': begin
          State := idMon1Sp;
        end;

        'A'..'Z', 'a'..'z' : begin
          Mon := Mon + P^;
        end;

        else
          State := idError;
      end;
    end;

    idMon1Sp: begin { ignore spaces after ANSI C month string }
      case P^ of
        ' ': { ignore };

        '0'..'9': begin
          State := idDay2;
          Day := Day + P^;
        end;

        else
          State := idError;
      end;
    end;

    idMon2: begin  { RFC 822 and 850 month string }
      case P^ of
        ' ' : begin
          State := idMon2Sp;
        end;

        '-' : begin
          State := idYr1;
        end;

        'A'..'Z', 'a'..'z' : begin
          Mon := Mon + P^;
        end;

        else
          State := idError;
      end;
    end;

    idMon2Sp: begin   {ignore spaces after month string }
      case P^ of
        ' ': { ignore };

        '0'..'9': begin
          State := idYr1;
          Year := Year + P^;
        end;

        else
          State := idError;
      end;
    end;

    idDay2: begin   { ANSI C format Day string }
      case P^ of
        '0'..'9': begin
          Day := Day + P^;
        end;

        ',' : begin
          State := idDaySpace1;
        end;

        ' ': begin
          State := idPreTimeSp;
        end;

        else
          State := idError;
      end;
    end;

    idDaySpace1 : begin
      case P^ of
        ' ' : begin
        end;

        '0'..'9' : begin
          Year := Year + P^;
          State := idYr1;
        end;

        else
          State := idError;
      end;
    end;

    idYr1: begin    { RFC 822 and 850 year string }
      case P^ of
        '0'..'9': begin
          Year := Year + P^;
        end;

        ' ': begin
          State := idPreTimeSp;
        end;

        else
          State := idError;
      end;
    end;

    idPreTimeSp: begin  { ignore spaces before start of time string }
      case P^ of
        ' ': { ignore };

        '0'..'9': begin
          State := idHrs;
          Hrs := Hrs + P^;
        end;

        else
          State := idError;
      end;
    end;

    idHrs: begin  { hours string }
      case P^ of
        ':': begin
          State := idMin;
        end;

        '0'..'9': begin
          Hrs := Hrs + P^;
        end;

        else
          State := idError;
      end;
    end;

    idMin: begin { minutes string }
      case P^ of
        ':': begin
          State := idSec;
        end;

        '0'..'9': begin
          Min := Min + P^;
        end;

        ' ' : begin
          State := idPostTimeSp;
          Sec := '00';
        end;

        else
          State := idError;
      end;
    end;

    idSec: begin { seconds string }
      case P^ of
        ' ': begin
          State := idPostTimeSp;
        end;

        '0'..'9': begin
          Sec := Sec + P^;
        end;

        'A', 'a' : begin
          AMPM := True;
          PM := False;
          State := idAM;
        end;

        'P', 'p' : begin
          AMPM := True;
          PM := True;
          State := idPM;
        end;

        else
          State := idError;
      end;
    end;

    idAM : begin { AM string }
      case P^ of
        ' ' : begin
          State := idPostTimeSp
        end;

        'M', 'm' : begin
          State := idPostTimeSp;
        end;

        else
          State := idError;
      end;
    end;

    idPM : begin { PM string }
      case P^ of
        ' ' : begin
          State := idPostTimeSp
        end;

        'M', 'm' : begin
          State := idPostTimeSp;
        end;

        else
          State := idError;
      end;
    end;

    idPostTimeSp: begin   { ignore spaces before after time string }
      case P^ of
        ' ': { ignore };

        '0'..'9': begin
          State := idYr2;
          Year := Year + P^;
        end;

        {'G', 'g': begin                                               }
        {  State := idGMT;                                             }
        {end;                                                          }

        '-' : begin
          TimeZone := TimeZone + P^;
          State := IdTimeZoneNum;
        end;

        '+' : begin
          TimeZone := TimeZone + P^;
          State := IdTimeZoneNum;
        end;

        'A'..'Z', 'a'..'z' : begin
          TimeZone := TimeZone + P^;
          State := IdTimeZoneAlpha;
        end;

        else
          State := idError;
      end;
    end;

    idTimeZoneNum : begin
      case P^ of
        '0'..'9' : begin
          TimeZone := TimeZone + P^;
        end;

        ' ' : begin
          State := idEndSp;
        end;

        else
          State := idError;
      end;
    end;

    idTimeZoneAlpha : begin
      case P^ of
        'A'..'Z', 'a'..'z' : begin
          TimeZone := TimeZone + P^;
        end;

        ' ' : begin
          if CompareText(TimeZone, 'AM') = 0 then begin
            AMPM := True;
            PM := False;
            State := IdTimeZoneAlpha;
            TimeZone := '';
          end else if CompareText(TimeZone, 'PM') = 0 then begin
            AMPM := True;
            PM := True;
            State := IdTimeZoneAlpha;
            TimeZone := '';
          end else
            State := idEndSp;
        end;

        else
          State := idError;
      end;
    end;

    {idGMT: begin }   { RFC 822 and 850 should end with "GMT" }
    {  case P^ of                                                      }
    {    'M', 'T': begin                                               }
    {    end;                                                          }
    {                                                                  }
    {    ' ': begin                                                    }
    {      State := idEndSp;                                           }
    {    end;                                                          }
    {                                                                  }
    {    else                                                          }
    {      State := idError;                                           }
    {  end;                                                            }
    {end;                                                              }

    idYr2: begin    { ANSI C time ends with Year }
      case P^ of
        '0'..'9': begin
          Year := Year + P^;
        end;

        ' ': begin
          State := idEndSp;
        end;

        else
          State := idError;
      end;
    end;

    idEndSp: begin  { ignore trailing spaces }
      case P^ of
        ' ': {ignore};
        else
          State := idError;
      end;
    end;

    idError: begin
    end;
  end;
end;


begin
  Result := EncodeDate(1970, 1, 1);
  if DateStr = '' then Exit;

  { clear parse strings }
  Dow := '';
  Day := '';
  Mon := '';
  Year := '';
  Hrs := '';
  Min := '';
  Sec := '';
  AMPM := False;
  PM := False;
  TimeZone := '';

  { start at first character }
  P := @DateStr[1];

  { iterate characters }
  for i := 1 to Length(DateStr) do begin
    ParseDate;
    if State = idError then
      Exit { error in date format, give up }
    else
      Inc(P);
  end;

  if State = idTimeZoneAlpha then begin
    if CompareText(TimeZone, 'AM') = 0 then begin
      AMPM := True;
      PM := False;
      TimeZone := '';
    end else if CompareText(TimeZone, 'PM') = 0 then begin
      AMPM := True;
      PM := True;
      TimeZone := '';
    end;
  end;

  if State = idMin then begin
    Sec := '00';
    State := idSec;
  end;

  { date string terminated prematurely }
  if not (State in AcceptStates) then Exit;

  { validate day of week and Month name vs. expected }
//  if not ((Pos(UpperCase(Dow), DayString)   mod 9) = 1) then Exit; // !!!
  if not ((PosI(Mon, MonthString) mod 9) = 1) then Exit;

  { correct two digit years }
  Year := EpochStr(Year);

  { convert D-M-Y string representations to integers }
  Dy := StrToIntDef(Day, 0);
  Mo := MonStrToInt(Mon);
  Yr := StrToIntDef(Year, 0);

  { check for errors or out of range }
  if (Dy = 0) or (Mo = 0) or (Yr = 0) then Exit;
  if (Dy > 31) or (Mo > 12) then Exit;

  { convert H-M-S string representations to integers }
  Hr := StrToIntDef(Hrs, -1);
  Mn := StrToIntDef(Min, -1);
  Sc := StrToIntDef(Sec, -1);

  if AMPM then begin
    if (Hr < 12) and (PM) then
      Hr := Hr + 12;
    if (Hr = 12) and (not PM) then
      Hr := 0;
  end;

  { check for errors or out of range }
  if (Hr = -1) or (Mn = -1) or (Sc = -1) then Exit;
  if (Hr > 24) or (Mn > 60) or (Sc > 60) then Exit;

  { tests passed, generate final result }
  Result := ComposeDateTime(EncodeDate(Yr, Mo, Dy),EncodeTime(Hr, Mn, Sc, 0));
end;


{ increment TDateTime by supplied number of minutes }
function IncMins(const Date: TDateTime; NumberOfMins: Integer): TDateTime;
begin
  Result := Date + NumberOfMins / 1440.0;
end;


{ returns the current local TimeZone "bias" in minutes from UTC (GMT) }
function TimeZoneBias : Integer;
begin
  Result:=0;
  writeln('TimeZoneBias ToDo');
end;

(*
const
  TIME_ZONE_ID_UNKNOWN  = 0;
  TIME_ZONE_ID_STANDARD = 1;
  TIME_ZONE_ID_DAYLIGHT = 2;
{$ENDIF}
var
  TZI : TTimeZoneInformation;
begin
  Result := 0;
  case GetTimeZoneInformation(TZI) of
    TIME_ZONE_ID_UNKNOWN :  Result := 0;
    TIME_ZONE_ID_STANDARD : Result := TZI.Bias + TZI.StandardBias;
    TIME_ZONE_ID_DAYLIGHT : Result := TZI.Bias + TZI.DaylightBias;
  end;
end;
*)

{ Format TDateTime to standard HTTP date string }
function DateTimeToINetDateTimeStr(DateTime: TDateTime): string;
var
  Yr, Mo, Dy: Word;
  s: String;
begin
  DecodeDate(DateTime, Yr, Mo, Dy);
  s := Format('%g', [Abs(TimeZoneBias/60)]);
  if Length(s) = 1 then
    s := '0' + s;
  if TimeZoneBias < 0 then s := '-' + s;

  Result := FormatDateTime(CanonicalDate, DateTime);
  Result := Format(Result, [IpDOWStringS[DayOfWeek(DateTime)], IpMonthsStrings[Mo], s]);
end;


{ File/Directory Stuff }

{ Retreive Windows "MIME" type for a particular file extension }
{$ifndef MSWindows}
{define some basic mime types}
const MimeTypeExt : Array[0..4] of String = ('.htm','.html','.txt','.jpg','.png');
      MimeTypes   : Array[0..4] of String = ('text/html','text/html','text/plain','image/jpeg','image/png');
{$endif}

function GetLocalContent(const TheFileName: string): string;
var
  Reg : TRegistry;
  Ext : string;
  {$ifndef MSWindows}
  i : integer;
  {$ENDIF}
begin
  Result := '';
  Ext := ExtractFileExt(TheFileName);
  {$ifndef MSWindows}
  for i := 0 to high(MimeTypeExt) do
    if CompareText(MimeTypeExt[i], Ext) = 0 then
    begin
      result := MimeTypes[i];
      break;
    end;
  {$endif}
  if result = '' then
  begin
    Reg := nil;
    try
      Reg := TRegistry.Create;
      Reg.RootKey := HKEY_CLASSES_ROOT;
      if Reg.OpenKeyReadOnly(Ext) then
        Result := Reg.ReadString('Content Type');
    finally
      Reg.CloseKey;
      Reg.Free;
    end;
  end;
  //DebugLn('IpUtils.GetLocalContent File:'+TheFileName+' Result:'+result);
end;

{ Determine if a directory exists }
function DirExists(Dir : string): Boolean;
begin
  Result:=DirPathExists(Dir);
end;

{ Get temporary filename as string }
function GetTemporaryFile(const Path : string) : string;
begin
  Result:=GetTempFileNameUTF8(Path,'IP_');
end;

{ Get Windows system TEMP path in a string }
function GetTemporaryPath: string;
begin
  writeln('ToDo: IpUtils.GetTemporaryPath');
  Result:='';
end;

{ Append backslash to DOS path if needed }
function AppendBackSlash(APath : string) : string;
begin
  Result := AppendPathDelim(APath);
end;

{ Remove trailing backslash from a DOS path if needed }
function RemoveBackSlash(APath: string) : string;
begin
  Result := ChompPathDelim(APath);
end;

{***********************************************}

{cookie support}

const
  CookieDefaults: array [1..5] of string[8] =
    ('Version=',
     'Path=',
     'Domain=',
     'Max-Age=',
     'Path=');
function FixDefaults(const S: string): string;
var
  i : Integer;
begin
  Result := S;
  for i := 1 to 5 do
    if Pos(CookieDefaults[i], S) = 1 then
      Result := '$' + S;
end;

procedure SplitCookieFields(const Data: string; Fields: TStrings);
{
Split Cookie data fields into items in a TStrings instance, Cookie fields will
be in Name="Value" pairs easily accessed via the associated TStrings properties
routine automatically prepends '$' to default Cookie fields for response header
}
var
  P1, P2 : Integer;
  S, Temp : string;
begin
  Temp := Data + ';';
  P1 := 1;
  P2 := CharPosIdx(';', Temp, P1);
  while P2 > 0 do begin
    S := Trim(Copy(Temp, P1, P2 - P1));
    Fields.Add(FixDefaults(S));
    P1 := P2 + 1;
    P2 := CharPosIdx(';', Temp, P1);
  end;
end;


end.


{*****************************************}
{                                         }
{             FastReport v2.3             }
{            Various routines             }
{                                         }
{  Copyright (c) 1998-99 by Tzyganenko A. }
{                                         }
{*****************************************}

unit LR_Utils;

interface

{$I LR_Vers.inc}

uses
  SysUtils, Classes, strutils, Graphics, Controls,
  LR_DBRel, Forms, StdCtrls, ClipBrd, Menus, db,
  {$IFDEF WIN32}
  Windows,
  {$ENDIF}
  LCLType, LCLIntf, LConvEncoding, LazFileUtils, LazUTF8, LazLogger;

type
  TUTF8Item=packed record
    Index: Integer;
    UTF8Index: Integer;
    Count: byte;
    UTF8Count: byte;
    Space: boolean;
  end;
  TArrUTF8Item=array of TUTF8Item;



procedure frReadMemo(Stream: TStream; l: TStrings);
procedure frReadMemo22(Stream: TStream; l: TStrings);
procedure frWriteMemo(Stream: TStream; l: TStrings);
function frReadString(Stream: TStream): String;
function frReadString22(Stream: TStream): String;
{$IFDEF FREEREP2217READ}
function frReadMemoText2217(Stream: TStream): String;
function frReadString2217(Stream: TStream): String;
{$ENDIF}
procedure frWriteString(Stream: TStream; s: String);
procedure frEnableControls(c: Array of TControl; e: Boolean);
function frControlAtPos(Win: TWinControl; p: TPoint): TControl;
function frGetDataSet(const ComplexName: String): TfrTDataSet;
procedure frGetDataSetAndField(ComplexName: String;
  var DataSet: TfrTDataSet; out Field: TfrTField);
function frGetFontStyle(Style: TFontStyles): Integer;
function frSetFontStyle(Style: Integer): TFontStyles;
procedure frInitFont(aFont : TFont; aColor : TColor; {%H-}aSize : Integer; aStyle : TFontStyles);
function frFindComponent(Owner: TComponent; const Name: String): TComponent;
procedure frGetComponents(Owner: TComponent; ClassRef: TClass;
  List: TStrings; Skip: TComponent);

function frGetWindowsVersion: String;

function frTypeObjectToStr(ot : Byte):string;
function StrTofrTypeObject(St : string) : Byte;


function lrGetUnBrackedStr(const S:string):string; //remove '[' from begion of string and ']' from end
function lrValidFieldReference(s: string):boolean;
function lrDateTimeToStr(ADate:TDateTime):string;
function lrStrToDateTime(AValue: string): TDateTime;
function lrExpandVariables(const S:string):string;
procedure lrNormalizeLocaleFloats(DisableLocale: boolean);
function lrConfigFolderName(ACreatePath: boolean): string;
function lrCanReadName(Stream: TStream): boolean;

procedure CanvasTextRectJustify(const Canvas:TCanvas;
  const ARect: TRect; X1, X2, Y: integer; const Text: string;
  Trimmed: boolean);

// utf8 tools
function UTF8Desc(S:string; var Desc: string): Integer; deprecated;
function UTF8Char(S:string; index:Integer; Desc:string): TUTF8Char; deprecated;
function UTF8Range(S:string; index,count:Integer; Desc:String):string; deprecated;
function UTF8Index(index:integer; desc:string): Integer; deprecated;
function UTF8CharIn(ch:TUTF8Char; const arrstr:array of string): boolean;
function UTF8QuotedStr(s:string; Quote: TUTF8Char; desc:string=''): string; deprecated;
function PosLast(SubChr:char; const Source:string):integer;
function UTF8CountWords(const str:string; out WordCount,SpcCount,SpcSize:Integer): TArrUTF8Item;

implementation

uses LR_Class, LR_Const, LR_Pars, LazUtilsStrConsts, LR_DSet, LR_DBComponent;

var
  PreviousFormatSettings: TFormatSettings;

procedure frInitFont(aFont : TFont; aColor : TColor; aSize : Integer; aStyle : TFontStyles);
begin
  with aFont do
  begin
    aFont.BeginUpdate;
    try
      aFont.Name :='default';
      aFont.Color:=aColor;
      aFont.Size :=0; //aSize;
      aFont.Style:=aStyle;
      aFont.Pitch:=fpDefault; //fpFixed;
      aFont.CharSet:=1;
    finally
      aFont.EndUpdate;
    end;
  end;
end;

function frSetFontStyle(Style: Integer): TFontStyles;
begin
  Result := [];
  if (Style and $1) <> 0 then Result := Result + [fsItalic];
  if (Style and $2) <> 0 then Result := Result + [fsBold];
  if (Style and $4) <> 0 then Result := Result + [fsUnderLine];
end;

function frGetFontStyle(Style: TFontStyles): Integer;
begin
  Result := 0;
  if fsItalic in Style then Result := Result or $1;
  if fsBold in Style then Result := Result or $2;
  if fsUnderline in Style then Result := Result or $4;
end;

procedure RemoveQuotes(var s: String);
begin
  if (Length(s) > 1) and (s[1] = '"') and (s[Length(s)] = '"') then
    s := Copy(s, 2, Length(s) - 2);
end;

procedure frReadMemo(Stream: TStream; l: TStrings);
var
  s: String;
  b: Byte;
  n: Word;
begin
  l.Clear;
  n := 0;
  Stream.Read(n, 2);
  if n > 0 then
    repeat
      Stream.Read(n, 2);
      SetLength(s, n);
      Stream.Read(s[1], n);
      if frVersion<=23 then
        // this string is not UTF-8 encoded, give developer a chance
        // to specify from what encoding should it convert from to UTF8
        // if developer do not specify an encoding function assume CP1250
        if Assigned(ConvertAnsiToUTF8) then
          s := ConvertAnsiToUTF8(s)
        else
          s := CP1250ToUTF8(s);
      l.Add(s);
      b := 0;
      Stream.Read(b, 1);
    until b = 0
  else
    Stream.Read(b, 1);
end;

procedure frWriteMemo(Stream: TStream; l: TStrings);
var
  s: String;
  i: Integer;
  n: Word;
  b: Byte;
begin
  n := l.Count;
  Stream.Write(n, 2);
  for i := 0 to l.Count - 1 do
  begin
    s := l[i];
    n := Length(s);
    Stream.Write(n, 2);
    Stream.Write(s[1], n);
    b := 13;
    if i <> l.Count - 1 then Stream.Write(b, 1);
  end;
  b := 0;
  Stream.Write(b, 1);
end;

function frReadString(Stream: TStream): String;
var
  s: String;
  n: Word;
  b: Byte;
begin
  n := 0;
  Stream.Read(n, 2);
  SetLength(s, n);
  Stream.Read(s[1], n);
  b := 0;
  Stream.Read(b, 1);
  Result := s;
end;

procedure frWriteString(Stream: TStream; s: String);
var
  b: Byte;
  n: Word;
begin
  n := Length(s);
  Stream.Write(n, 2);
  Stream.Write(s[1], n);
  b := 0;
  Stream.Write(b, 1);
end;

procedure frReadMemo22(Stream: TStream; l: TStrings);
var
  s: String;
  i: Integer;
  b: Byte;
begin
  SetLength(s, 4096);
  l.Clear;
  i := 1;
  repeat
    b := 0;
    Stream.Read(b,1);
    if (b = 13) or (b = 0) then
    begin
      SetLength(s, i - 1);
      if not ((b = 0) and (i = 1)) then l.Add(s);
      SetLength(s, 4096);
      i := 1;
    end
    else if b <> 0 then
    begin
      s[i] := Chr(b);
      Inc(i);
      if i > 4096 then
        SetLength(s, Length(s) + 4096);
    end;
  until b = 0;
end;

function frReadString22(Stream: TStream): String;
var
  s: String;
  i: Integer;
  b: Byte;
begin
  SetLength(s, 4096);
  i := 1;
  repeat
    b := 0;
    Stream.Read(b, 1);
    if b = 0 then
      SetLength(s, i - 1)
    else
    begin
      s[i] := Chr(b);
      Inc(i);
      if i > 4096 then
        SetLength(s, Length(s) + 4096);
    end;
  until b = 0;
  Result := s;
end;

{$IFDEF FREEREP2217READ}
function frReadMemoText2217(Stream: TStream): String;
var
  I: Integer;
begin
  Stream.ReadBuffer(I, SizeOf(I));
  SetLength(Result, I);
  Stream.ReadBuffer(PChar(Result)^, I);
end;

function frReadString2217(Stream: TStream): String;
var
  I: Integer;
begin
  Result := frReadMemoText2217(Stream);
  I := Pos(#13, Result);
  if I > 0 then
    Result := Copy(Result, 1, I - 1);
end;
{$ENDIF}

type
  THackWinControl = class(TWinControl)
  end;

procedure frEnableControls(c: Array of TControl; e: Boolean);
const
  Clr1: Array[Boolean] of TColor = (clGrayText,clWindowText);
  Clr2: Array[Boolean] of TColor = (clBtnFace,clWindow);
var
  i: Integer;
begin
  for i := Low(c) to High(c) do
    if c[i] is TLabel then
      with c[i] as TLabel do
      begin
        Font.Color := Clr1[e];
        Enabled := e;
      end
    else if c[i] is TWinControl then
      with THackWinControl(c[i]) do
      begin
        Color := Clr2[e];
        Enabled := e;
      end;
end;

function frControlAtPos(Win: TWinControl; p: TPoint): TControl;
var
  i: Integer;
  c: TControl;
  p1: TPoint;
begin
  Result := nil;
  with Win do
  begin
    for i := ControlCount - 1 downto 0 do
    begin
      c := Controls[i];
      if c.Visible and PtInRect(Classes.Rect(c.Left, c.Top, c.Left + c.Width, c.Top + c.Height), p) then
        if (c is TWinControl) and (csAcceptsControls in c.ControlStyle) and
           (TWinControl(c).ControlCount > 0) then
        begin
          p1 := p;
          Dec(p1.X, c.Left); Dec(p1.Y, c.Top);
          c := frControlAtPos(TWinControl(c), p1);
          if c <> nil then
          begin
            Result := c;
            Exit;
          end;
        end
        else
        begin
          Result := c;
          Exit;
        end;
    end;
  end;
end;

function frGetDataSet(const ComplexName: String): TfrTDataSet;
var
  Component: TComponent;
  F:TfrObject;
  S1, S2:string;
begin
  Result := nil;
  if ComplexName = '' then exit;
  Component := nil;

  if Assigned(CurReport) then
  begin
    if (Pos('.', ComplexName) > 0)  then
    begin
      S1:=Copy(ComplexName, 1, Pos('.', ComplexName)-1);
      S2:=Copy(ComplexName, Pos('.', ComplexName)+1, Length(ComplexName));
      F:=CurReport.FindObject(S1);
      if Assigned(F) and (F is TfrPageDialog) then
        F:=TfrPageDialog(F).FindObject(S2);

      if Assigned(F) and (F is TLRDataSetControl) then
        Component:=TLRDataSetControl(F).DataSet;

    end
    else
    begin
      F:=CurReport.FindObject(ComplexName);
      if Assigned(F) and (F is TLRDataSetControl) then
        Component:=TLRDataSetControl(F).DataSet;
    end;
  end;

  if not Assigned(Component) then
    Component := frFindComponent(CurReport.Owner, ComplexName);

  if Assigned(Component) then
  begin
    if Component is TDataSet then
      Result := TfrTDataSet(Component)
    else if Component is TDataSource then
      Result := TfrTDataSet(TDataSource(Component).DataSet);
  end
  else
    Result := nil;
end;

procedure frGetDataSetAndField(ComplexName: String; var DataSet: TfrTDataSet;
  out Field: TfrTField);
var
  n: Integer;
  Owner, Component: TComponent;
  s1, s2, s3, s4: String;
  frDS, F:TfrObject;
begin
  Field := nil;
  Owner := CurReport.Owner;
  n := Pos('.', ComplexName);
  if n <> 0 then
  begin
    s1 := Copy(ComplexName, 1, n - 1);        // table name
    s2 := Copy(ComplexName, n + 1, 255);      // field name

    if Assigned(CurReport) then
    begin
      // find dataset and field in DS on reports dialogs
      if Pos('.', S2)>0 then
      begin
        S3:=Copy(S2, Pos('.', S2)+1, Length(S2));
        Delete(S2, Pos('.', S2), Length(S2));

        F:=CurReport.FindObject(S1);
        if Assigned(F) and (F is TfrPageDialog) then
          frDS:=TfrPageDialog(F).FindObject(S2)
        else
          frDS:=nil;

        if Assigned(frDS) and (frDS is TLRDataSetControl) then
        begin
          RemoveQuotes(s3);
          DataSet:= TfrTDataSet(TLRDataSetControl(frDS).DataSet);
          Field:=TfrTField(TLRDataSetControl(frDS).DataSet.FindField(S3));
        end;
      end
      else
      begin
        frDS:=CurReport.FindObject(S1);
        if Assigned(frDS) and (frDS is TLRDataSetControl) then
        begin
          RemoveQuotes(s2);
          DataSet:=TfrTDataSet(TLRDataSetControl(frDS).DataSet);
          Field:=TfrTField(TLRDataSetControl(frDS).DataSet.FindField(S2));
        end;
      end;

    end;

    if Assigned(Field) then
      exit;

    s1 := Copy(ComplexName, 1, n - 1);        // table name
    s2 := Copy(ComplexName, n + 1, 255);      // field name
    if Pos('.', s2) <> 0 then                 // module name present
    begin
      s3 := Copy(s2, Pos('.', s2) + 1, 255);
      s2 := Copy(s2, 1, Pos('.', s2) - 1);
      Owner:=FindGlobalComponent(S1);
      if Owner <> nil then
      begin
        n:=Pos('.', S3);                      //test for frame name
        if n>0 then                           //if frame name present
        begin
          S4:=Copy(S3, 1, n-1);
          Delete(S3, 1, n);
          Owner:=Owner.FindComponent(S2);
          Component := frFindComponent(Owner, s4);
          if Assigned(Component) then
            begin
              if Component is TDataSet then
                DataSet := TfrTDataSet(Component)
              else if Component is TDataSource then
                DataSet := TfrTDataSet(TDataSource(Component).DataSet);
            end;
        end
        else
          begin
            Component := frFindComponent(Owner, s2);
            if Assigned(Component) then
              begin
                if Component is TDataSet then
                  DataSet := TfrTDataSet(Component)
                else if Component is TDataSource then
                  DataSet := TfrTDataSet(TDataSource(Component).DataSet);
              end;
          end;
        RemoveQuotes(s3);
        if DataSet <> nil then
          Field := TfrTField(DataSet.FindField(s3));
      end;
    end
    else
    begin
      Component := frFindComponent(Owner, s1);
      if Assigned(Component) then
        begin
          if Component is TDataSet then
            DataSet := TfrTDataSet(Component)
          else if Component is TDataSource then
            DataSet := TfrTDataSet(TDataSource(Component).DataSet);
        end;
      RemoveQuotes(s2);
      if DataSet <> nil then
        Field := TfrTField(DataSet.FindField(s2));
    end;
  end
  else if DataSet <> nil then
  begin
    RemoveQuotes(ComplexName);
    Field := TfrTField(DataSet.FindField(ComplexName));
  end;
end;

function frFindComponent(Owner: TComponent; const Name: String): TComponent;
var
  n, i, j: Integer;
  s1, s2, s3: String;
begin
  Result := nil;
  n := Pos('.', Name);
  try
    if n = 0 then
    begin
      if Assigned(Owner) then
        Result := Owner.FindComponent(Name)
    end
    else
    begin
      s1 := Copy(Name, 1, n - 1);        // module name
      s2 := Copy(Name, n + 1, Length(Name));      // component name

      n := Pos('.', S2); //check for frames
      if n = 0 then
        S3:=''
      else
      begin
        s3 := Copy(S2, 1, n - 1);        // module name
        Delete(S2, 1, n);
      end;

      if Assigned(CurReport) and (S3 = '') then
      begin
        for i:=0 to CurReport.Pages.Count-1 do
          if CurReport.Pages[i] is TfrPageDialog then
          begin
            if CurReport.Pages[i].Name = S1 then
            begin;
              for j:=0 to CurReport.Pages[i].Objects.Count-1 do
              begin
                if TfrObject(CurReport.Pages[i].Objects[j]) is TLRDataSetControl then
                begin
                  if TLRDataSetControl(CurReport.Pages[i].Objects[j]).DataSet.Name = S2 then
                  begin
                    Result:=TLRDataSetControl(CurReport.Pages[i].Objects[j]).DataSet;
                    break;
                  end;
                  if TLRDataSetControl(CurReport.Pages[i].Objects[j]).lrDBDataSet.Name = S2 then
                  begin
                    Result:=TLRDataSetControl(CurReport.Pages[i].Objects[j]).lrDBDataSet;
                    break;
                  end;
                  if TLRDataSetControl(CurReport.Pages[i].Objects[j]).lrDataSource.Name = S2 then
                  begin
                    Result:=TLRDataSetControl(CurReport.Pages[i].Objects[j]).lrDataSource;
                    break;
                  end;
                end;
              end;
              break;
            end
          end;
      end;

      if not Assigned(Result) then
      begin
        Owner := FindGlobalComponent(s1);
        if Owner=nil then begin
          // try screen registered containers
          // which at design time are not in FindGlobalComponentList
          Owner := Screen.FindDataModule(s1);
          if Owner=nil then
            Owner := Screen.FindForm(s1);
        end;
        if Owner <> nil then
        begin
          if s3<>'' then
            Owner:=Owner.FindComponent(s3);
          if Assigned(Owner) then
            Result := Owner.FindComponent(s2);
        end;
      end;
    end;
  except
    on Exception do
      raise EClassNotFound.CreateFmt(sObjectNotFound, [Name]);
  end;
end;

{$HINTS OFF}
procedure frGetComponents(Owner: TComponent; ClassRef: TClass;
  List: TStrings; Skip: TComponent);

  procedure EnumComponents(f: TComponent);
  var
    i: Integer;
    c: TComponent;
  begin
{$IFDEF Delphi5}
    if f is TForm then
      for i := 0 to TForm(f).ControlCount - 1 do
      begin
        c := TForm(f).Controls[i];
        if c is TFrame then
          EnumComponents(c);
      end;
{$ENDIF}
    for i := 0 to f.ComponentCount - 1 do
    begin
      c := f.Components[i];
      if c is TFrame then
        EnumComponents(c)
      else
      if (c <> Skip) and (c is ClassRef) then
        if f = Owner then
          List.Add(c.Name)
        else
        if ((f is TForm) or (f is TDataModule) or (f is TFrame)) then
          List.Add(f.Name + '.' + c.Name)
        else
          List.Add(TControl(f).Owner.Name + '.' + f.Name + '.' + c.Name)
    end;
  end;

var
  i, j: Integer;
  S:string;
begin
  {$IFDEF DebugLR}
  DebugLn('frGetComponents 1');
  {$ENDIF}
  List.Clear;

  //Find DataSet in current report
  if Assigned(CurReport) and (ClassRef = TfrDataSet) then
  begin
    for i:=0 to CurReport.Pages.Count-1 do
      if CurReport.Pages[i] is TfrPageDialog then
      begin
        for j:=0 to CurReport.Pages[i].Objects.Count-1 do
        begin
          if TfrObject(CurReport.Pages[i].Objects[j]) is TLRDataSetControl then
          begin
            S:=CurReport.Pages[i].Name+'.'+TLRDataSetControl(CurReport.Pages[i].Objects[j]).lrDBDataSet.Name;
            List.Add(S);
          end;
        end;
      end;
  end;

  if Assigned(CurReport) and (ClassRef = TDataSet) then
  begin
    for i:=0 to CurReport.Pages.Count-1 do
      if CurReport.Pages[i] is TfrPageDialog then
      begin
        for j:=0 to CurReport.Pages[i].Objects.Count-1 do
        begin
          if TfrObject(CurReport.Pages[i].Objects[j]) is TLRDataSetControl then
          begin
            S:=CurReport.Pages[i].Name+'.'+TLRDataSetControl(CurReport.Pages[i].Objects[j]).DataSet.Name;
            List.Add(S);
          end;
        end;
      end;
  end;

  if Assigned(CurReport) and (ClassRef = TDataSource) then
  begin
    for i:=0 to CurReport.Pages.Count-1 do
      if CurReport.Pages[i] is TfrPageDialog then
      begin
        for j:=0 to CurReport.Pages[i].Objects.Count-1 do
        begin
          if TfrObject(CurReport.Pages[i].Objects[j]) is TLRDataSetControl then
          begin
            S:=CurReport.Pages[i].Name+'.'+TLRDataSetControl(CurReport.Pages[i].Objects[j]).lrDataSource.Name;
            List.Add(S);
          end;
        end;
      end;
  end;
  {$IFDEF DebugLR}
  DebugLn('frGetComponents 2');
  {$ENDIF}

  for i := 0 to Screen.FormCount - 1 do
    EnumComponents(Screen.Forms[i]);

  {$IFDEF DebugLR}
  DebugLn('frGetComponents 3');
  {$ENDIF}
  for i := 0 to Screen.DataModuleCount - 1 do
    EnumComponents(Screen.DataModules[i]);

  with Screen do
  begin
    {$IFDEF DebugLR}
    DebugLn('frGetComponents 4');
    {$ENDIF}
    for i := 0 to CustomFormCount - 1 do
    begin
      with CustomForms[i] do
      begin
        if (UpperCase(ClassName)='TDATAMODULEFORM')  then
          for j := 0 to ComponentCount - 1 do
          begin
            if (Components[j] is TDataModule) then
              EnumComponents(Components[j]);
          end;
      end;
    end;
  end;
end;
{$HINTS ON}  

function frGetWindowsVersion: String;
{$IFDEF WIN32}
var Ver: TOsVersionInfo;
begin
  Ver.dwOSVersionInfoSize := SizeOf(Ver);
  GetVersionEx(Ver);
  with Ver do begin
    case dwPlatformId of
      VER_PLATFORM_WIN32s: Result := '32s';
      VER_PLATFORM_WIN32_WINDOWS:
        begin
          dwBuildNumber := dwBuildNumber and $0000FFFF;
          if (dwMajorVersion > 4) or ((dwMajorVersion = 4) and
            (dwMinorVersion >= 10)) then
            Result := '98' else
            Result := '95';
        end;
      VER_PLATFORM_WIN32_NT: Result := 'NT';
    end;
  end;
end;
{$ELSE}
begin
  Result:='LINUX';
end;
{$ENDIF}

{**
* Return the string value of type object
**}
function frTypeObjectToStr(ot : Byte): string;
begin
  Case ot of
    gtMemo     : result:='gtMemo';
    gtPicture  : result:='gtPicture';
    gtBand     : result:='gtBand';
    gtSubReport: result:='gtSubReport';
    gtLine     : result:='gtLine';
    gtAddIn    : result:='gtAddIn';
    else         result:='undef ('+IntTostr(ot)+')';
  end;
end;

function StrTofrTypeObject(St : string) : Byte;
begin
  Result:=StrToIntDef(St,gtMemo);
  
  if SameText(St,'gtMemo') then
    result:=gtMemo
  else
    if SameText(St,'gtPicture') then
      result:=gtPicture
    else
     if SameText(St,'gtBand') then
       result:=gtBand
      else
       if SameText(St,'gtSubReport') then
          result:=gtSubReport
       else
        if SameText(St,'gtLine') then
          result:=gtLine
        else
         if SameText(St,'gtAddIn') then
           result:=gtAddIn;
end;

function lrGetUnBrackedStr(const S: string): string;
var
  Cnt, i:integer;
begin
  Cnt:=Length(S);
  if (Cnt>2) and (S[1]='[') then
  begin
    for i := Cnt downto 2 do
      if S[i]=']' then
      begin
        Result:=Copy(S, 2, i-2);
        exit;
      end;
  end;
  Result:=S;
end;

function lrValidFieldReference(s: string): boolean;
var
  i,j,k,n: Integer;
begin
  result := false;

  s := lrGetUnbrackedStr(Trim(s));

  if length(s)<3 then
    exit;

  n := 0;
  i := Length(s);
  while i>0 do begin

    // get item
    j := i;
    while (i>0) and (s[i]<>'.') do
      dec(i);

    // validate item
    k := i+1;

    // trim
    while (k<=j) and (s[k] in [' ',#9]) do
      inc(k);
    while (j>=k) and (s[j] in [' ',#9,#10,#13]) do
      dec(j);

    if s[k]='"' then  // quoted field

      result := (n=0) and (j>(k+1)) and (s[j]='"')

    else begin  // identifier

      result := (k<=j) and (s[k] in ['A'..'Z','a'..'z','_']);
      inc(k);
      while result and (k<=j) do begin
        result := result and (s[k] in ['A'..'Z','a'..'z','0'..'9','_']);
        inc(k);
      end;

    end;

    if not result then
      exit;

    inc(n);
    dec(i);
  end;
  result := n>1;
end;

function lrDateTimeToStr(ADate: TDateTime): string;
var
  DF:TFormatSettings;
begin
  DF.DateSeparator:='-';
  DF.TimeSeparator:=':';
  Result:=FormatDateTime( 'YYYY-MM-DD HH:NN:SS', ADate, DF);
end;

function lrStrToDateTime(AValue: string): TDateTime;
var
  DF:TFormatSettings;
begin
  if AValue <> '' then
  begin
    DF.DateSeparator:='-';
    DF.TimeSeparator:=':';
    DF.ShortDateFormat:='YYYY-MM-DD';
    DF.ShortTimeFormat:='HH:NN:SS';
    try
      Result:=StrToDateTime(AValue,   DF);
    except
      Result:=0
    end;
  end
  else
    Result:=0;
end;

function lrExpandVariables(const S: string): string;
var
  i, j, k:integer;
  SP, SV:string;
begin
  Result:='';
  i:=1;
  k:=1;
  while i<=Length(S) do
  begin
    if S[i] = '[' then
    begin
      SP:=GetBrackedVariable(S, i, j);
      SV:='';
      CurReport.InternalOnGetValue(SP, SV);

      Result:=Result + Copy(S, K, I-K) + SV;
      i:=j+1;
      k:=j+1;
    end
    else
      Inc(I);
  end;
  if K<i then
    Result:=Result + Copy(S, K, I-K);
end;

procedure lrNormalizeLocaleFloats(DisableLocale: boolean);
begin
  if DisableLocale then
  begin
    PreviousFormatSettings := DefaultFormatSettings;
    DefaultFormatSettings.DecimalSeparator := '.';
  end else
    DefaultFormatSettings := PreviousFormatSettings;
end;

function lrConfigFolderName(ACreatePath: boolean): string;
begin
  Result:=AppendPathDelim(GetAppConfigDirUTF8(false, ACreatePath))+'LazReport';

  if ACreatePath and not ForceDirectoriesUTF8(Result) then
    raise EInOutError.Create(SysUtils.Format(lrsUnableToCreateConfigDirectoryS,[Result]));
end;

function lrCanReadName(Stream: TStream): boolean;
var
  oldPosition: Int64;
  aName: string;
  n: Integer;
begin
  // normally stream is seek-able so this should work....
  oldPosition := stream.Position;
  result := false;
  try
    try
      n := stream.ReadWord;
      setLength(aName, n);
      stream.Read(aName[1], n);
      if (n>0) and (stream.ReadByte=0) then begin
        // unfortunately, objects names are not validated
        // only check standard names here
        while (n>0) and (aName[n] in ['a'..'z','A'..'Z','0'..'9','_']) do
          dec(n);
        result := (n=0);
      end;
    except
    end;
  finally
    Stream.Position := oldPosition;
  end;
end;

function UTF8Desc(S: string; var Desc: string): Integer;
// create Desc as an array with Desc[i] is the size of the UTF-8 codepoint
var
  i,b: Integer;
begin
  i := 1;
  Result := 0;
  SetLength(Desc, Length(S));
  while i<=Length(s) do begin
    b := UTF8CharacterStrictLength(@S[i]);
    inc(i,b);
    inc(Result);
    if Result<length(Desc) then
      Desc[Result] := Char(b)
    else //abort on invalid UTF8 String
      begin
        s := '';
        Result := 0;
        exit;
      end;
  end;
  Setlength(Desc, Result);
end;

function UTF8Char(S: string; index: Integer; Desc: string): TUTF8Char;
var
  i,j: Integer;
begin
  Result := '';
  if (index<1) or (index>Length(Desc)) then begin
    //Result := #$EF#$BF#$BD  // replacement character
    exit;
  end;

  i:=0; j:=1;
  while i<Length(Desc) do begin
    inc(i);
    if i=index then begin
      Move(S[j],Result[1],ord(Desc[i]));
      Result[0]:=Desc[i];
      break;
    end;
    inc(j, ord(Desc[i]));
  end;

end;

function UTF8Range(S: string; index, count: Integer; Desc: String
  ): string;
var
  c,i: Integer;
begin
  result := '';
  c := 0;
  i := index;
  while (Count>0) and (i<=Length(Desc)) do begin
    c := c + ord(Desc[i]);
    inc(i);
    Dec(Count);
  end;
  i := {%H-}UTF8Index(Index, Desc);
  if i>0 then begin
    SetLength(Result, c);
    Move(S[i],Result[1],c);
  end;
end;

// this assume index is in valid range
function UTF8Index(index: integer; desc: string): Integer;
var
  i,c: integer;
begin
  result := 0;
  c := 0;
  for i:=1 to Length(Desc) do begin
    inc(c);
    if i=index then begin
      result := c;
      break;
    end;
    c := c + ord(Desc[i]) - 1;
  end;
end;

function UTF8CharIn(ch:TUTF8Char; const arrstr: array of string): boolean;
var
  i: Integer;
begin
  result := false;
  for i:=low(arrstr) to high(arrstr) do
    if arrstr[i]=ch then begin
      result := true;
      break;
    end;
end;

// converted from FPC AnsiQuotedStr()
function UTF8QuotedStr(s: string; Quote: TUTF8Char; desc:string=''): string;
var
    i, j, count: integer;
begin
  result := '' + Quote;
  if desc='' then
    count := {%H-}UTF8Desc(s, desc)
  else
    count := length(s);

  i := 0;
  j := 0;
  while i < count do begin
    i := i + 1;
    if {%H-}UTF8Char(s,i,desc) = Quote then begin
      result := result + {%H-}UTF8Range(S, 1 + j, i - j, desc) + Quote;
      j := i;
    end;
  end;

  if i <> j then
    result := result + {%H-}UTF8Range(S, 1 + j, i - j, desc);
  result := result + Quote;
end ;

function PosLast(SubChr: char; const Source: string): integer;
var
  i:integer;
begin
  for i:=Length(Source) downto 1 do
    if Source[i] = SubChr then
    begin
      Result:=i;
      exit;
    end;
  Result:=-1;
end;

function UTF8CountWords(const str:string; out WordCount,SpcCount,SpcSize:Integer): TArrUTF8Item;
var
  b,i,j,len: Integer;
  spc: boolean;
begin
  i := 1;
  len := 0;
  SetLength(result, 0);
  WordCount := 0;
  SpcCount := 0;
  SpcSize := 0;
  while i<=Length(str) do
  begin
    b := UTF8CharacterStrictLength(@Str[i]);
    spc := (b=1) and (str[i]=' ');
    inc(len);
    j := Length(result)-1;
    if (j<0) or (result[j].Space<>Spc) then
    begin
      inc(j);
      SetLength(result, j+1);
      result[j].Count:=0;
      result[j].UTF8Count:=0;
      result[j].Index:=i;
      result[j].UTF8Index:=len;
      if not spc then
        Inc(WordCount)
      else
        Inc(SpcCount);
    end;
    result[j].Space := Spc;
    result[j].UTF8Count := result[j].UTF8Count + 1;
    result[j].Count := result[j].Count + b;
    inc(i,b);
    if Spc then
      Inc(SpcSize);
  end;
end;

procedure CanvasTextRectJustify(const Canvas:TCanvas;
  const ARect: TRect; X1, X2, Y: integer; const Text: string;
  Trimmed: boolean);
var
  WordCount,SpcCount,SpcSize:Integer;
  Arr: TArrUTF8Item;
  PxSpc,RxSpc,Extra: Integer;
  i: Integer;
  Cini,Cend: Integer;
  SpaceWidth, AvailWidth: Integer;
  s:string;
begin

  AvailWidth := (X2-X1);
  // count words
  Arr := UTF8CountWords(Text, WordCount, SpcCount, SpcSize);

  // handle trimmed text
  s := Text;
  if (SpcCount>0) then
  begin
    Cini := 0;
    CEnd := Length(Arr)-1;
    if Trimmed then
    begin
      s := UTF8Trim(Text, [u8tKeepStart]);
      if Arr[CEnd].Space then
      begin
        Dec(CEnd);
        Dec(SpcCount);
      end;
    end;
    AvailWidth := AvailWidth - Canvas.TextWidth(s);
  end;

  // check if long way is needed
  if (SpcCount>0) and (AvailWidth>0) then
  begin

    SpaceWidth := Canvas.TextWidth(' ');
    PxSpc := AvailWidth div SpcCount;
    RxSpc := AvailWidth mod SpcCount;
    if PxSPC=0 then
    begin
      PxSPC := 1;
      RxSpc := 0;
    end;

    for i:=CIni to CEnd do
      if Arr[i].Space then
      begin
        X1 := X1 + Arr[i].Count * SpaceWidth;
        if AvailWidth>0 then
        begin
          Extra := PxSpc;
          if RxSpc>0 then
          begin
            Inc(Extra);
            Dec(RxSpc);
          end;
          X1 := X1 + Extra;
          Dec(AvailWidth, Extra);
        end;
      end
      else
      begin
        s := Copy(Text, Arr[i].Index, Arr[i].Count);
        Canvas.TextRect(ARect, X1, Y, s);
        X1 := X1 + Canvas.TextWidth(s);
      end;

  end else
    Canvas.TextRect(ARect, X1, Y, s);

  SetLength(Arr, 0);
end;

end.

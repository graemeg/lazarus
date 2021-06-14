unit FpPascalBuilder;

{$mode objfpc}{$H+}
{$TYPEDADDRESS on}

interface

uses
  Classes, SysUtils, DbgIntfBaseTypes, DbgIntfDebuggerBase, FpDbgInfo,
  FpdMemoryTools, FpErrorMessages, FpDbgDwarfDataClasses, FpDbgDwarf,
  {$ifdef FORCE_LAZLOGGER_DUMMY} LazLoggerDummy {$else} LazLoggerBase {$endif}, LazUTF8, LazClasses;

type
  TTypeNameFlag = (
    tnfOnlyDeclared    // do not return a substitute with ^ symbol
  );
  TTypeNameFlags = set of TTypeNameFlag;

  TTypeDeclarationFlag = (
    tdfNoFirstLineIndent,
    tdfIncludeVarName,     // like i: Integer
    tdfSkipClassBody,      // shorten class
    tdfSkipRecordBody,      // shorten class

    tdfDynArrayWithPointer, // TODO, temp, act like gdb
    tdfStopAfterPointer
  );
  TTypeDeclarationFlags = set of TTypeDeclarationFlag;

  TFpPrettyPrintValueFlag = (
    ppvCreateDbgType,
    ppvSkipClassBody, ppvSkipRecordBody
  );
  TFpPrettyPrintValueFlags = set of TFpPrettyPrintValueFlag;

  TFpPrettyPrintOption = (
    ppoStackParam
  );
  TFpPrettyPrintOptions = set of TFpPrettyPrintOption;

const
  PV_FORWARD_FLAGS = [ppvSkipClassBody, ppvSkipRecordBody];

type

  PDBGType = ^TDBGType;

  { TFpPascalPrettyPrinter }

  TFpPascalPrettyPrinter = class
  private
    FAddressSize: Integer;
    FContext: TFpDbgLocationContext;
    function InternalPrintValue(out APrintedValue: String;
                                AValue: TFpValue;
                                AnAddressSize: Integer;
                                AFlags: TFpPrettyPrintValueFlags;
                                ANestLevel: Integer; AnIndent: String;
                                ADisplayFormat: TWatchDisplayFormat;
                                ARepeatCount: Integer = -1;
                                ADBGTypeInfo: PDBGType = nil;
                                AOptions: TFpPrettyPrintOptions = []
                               ): Boolean;
  public
    constructor Create(AnAddressSize: Integer);
    function PrintValue(out APrintedValue: String;
                        AValue: TFpValue;
                        ADisplayFormat: TWatchDisplayFormat = wdfDefault;
                        ARepeatCount: Integer = -1;
                        AOptions: TFpPrettyPrintOptions = []
                       ): Boolean;
    function PrintValue(out APrintedValue: String;
                        out ADBGTypeInfo: TDBGType;
                        AValue: TFpValue;
                        ADisplayFormat: TWatchDisplayFormat = wdfDefault;
                        ARepeatCount: Integer = -1
                       ): Boolean;
    property AddressSize: Integer read FAddressSize write FAddressSize;
    property Context: TFpDbgLocationContext read FContext write FContext;
  end;



function GetTypeName(out ATypeName: String; ADbgSymbol: TFpSymbol; AFlags: TTypeNameFlags = []): Boolean;
function GetTypeAsDeclaration(out ATypeDeclaration: String; ADbgSymbol: TFpSymbol;
  AFlags: TTypeDeclarationFlags = []; AnIndent: Integer = 0): Boolean;

function QuoteText(AText: Utf8String): UTf8String;

implementation

function GetTypeName(out ATypeName: String; ADbgSymbol: TFpSymbol;
  AFlags: TTypeNameFlags): Boolean;
var
  s: String;
  sym: TFpSymbol;
begin
  ATypeName := '';
  Result := ADbgSymbol <> nil;
  if not Result then
    exit;
  if (ADbgSymbol.SymbolType = stValue) then begin
    ADbgSymbol := ADbgSymbol.TypeInfo;
    Result := ADbgSymbol <> nil;
    if not Result then
      exit;
  end;

  ATypeName := ADbgSymbol.Name;
  Result := ATypeName <> '';

  if Result then
    exit;

  ATypeName := '';
  sym := ADbgSymbol;
  while (sym.Kind = skPointer) and (sym.TypeInfo <> nil) do begin
    ATypeName := ATypeName + '^';
    sym := sym.TypeInfo;
    s := sym.Name;
    if s <> '' then begin
      ATypeName := ATypeName + s;
      Result := True;
      exit;
    end;
  end;

  Result := True;
  case ADbgSymbol.Kind of
    skInstance:     ATypeName := '{class}';
    skProcedure:    ATypeName := '{procedure}';
    skFunction:     ATypeName := '{function}';
    skProcedureRef: ATypeName := '{procedure}';
    skFunctionRef:  ATypeName := '{function}';
    skPointer:      ATypeName := '{pointer}';
    skInteger:      ATypeName := '{signed int}';
    skCardinal:     ATypeName := '{unsigned int}';
    skBoolean:      ATypeName := '{boolean}';
    skChar:         ATypeName := '{char}';
    skFloat:        ATypeName := '{float}';
    skString:       ATypeName := '{string}';
    skAnsiString:   ATypeName := '{string}';
    skCurrency:     ATypeName := '{currency}';
    skVariant:      ATypeName := '{variant}';
    skWideString:   ATypeName := '{widestring}';
    skEnum:         ATypeName := '{enum}';
    skSet:          ATypeName := '{set}';
    skRecord:       ATypeName := '{record}';
    skObject:       ATypeName := '{object}';
    skClass:        ATypeName := '{class}';
    skInterface:    ATypeName := '{interface}';
    else begin
        ATypeName := '';
        Result := False;
      end;
  end;

end;

function GetTypeAsDeclaration(out ATypeDeclaration: String; ADbgSymbol: TFpSymbol;
  AFlags: TTypeDeclarationFlags; AnIndent: Integer): Boolean;
var
  IndentString: String;

  function GetIndent: String;
  begin
    if (IndentString = '') and (AnIndent > 0) then
      IndentString := StringOfChar(' ', AnIndent);
    Result := IndentString;
  end;

  function NeedBracket(S: String): Boolean;
  var
    i, l: Integer;
  begin
    l := 0;
    i := length(s);
    while (i > 0) do begin
      case s[i] of
        'a'..'z', 'A'..'Z', '0'..'9', '_', '$', '^': ;
         '(': dec(l);
         ')': inc(l);
        else
          if l = 0 then break;
      end;
      dec(i);
    end;
    Result := i > 0;
  end;

  Function MembersAsGdbText(out AText: String; WithVisibilty: Boolean; ANewFlags: TTypeDeclarationFlags = []): Boolean;
  var
    CurVis: TDbgSymbolMemberVisibility;

    procedure AddVisibility(AVis: TDbgSymbolMemberVisibility; AFirst: Boolean);
    begin
      if not (WithVisibilty and ((CurVis <> AVis) or AFirst)) then
        exit;
      CurVis := AVis;
      case AVis of
        svPrivate:   AText := AText + GetIndent + '  private' + LineEnding;
        svProtected: AText := AText + GetIndent + '  protected' + LineEnding;
        svPublic:    AText := AText + GetIndent + '  public' + LineEnding;
      end;
    end;

  var
    c, i: Integer;
    m: TFpSymbol;
    s: String;
    r: Boolean;
  begin
    Result := True;
    AText := '';
    ANewFlags := ANewFlags + AFlags;
    c := ADbgSymbol.NestedSymbolCount;
    i := 0;
    while (i < c) and Result do begin
      m := ADbgSymbol.NestedSymbol[i];
      AddVisibility(m.MemberVisibility, i= 0);
      if tdfStopAfterPointer in ANewFlags then
        r := GetTypeName(s, m)
      else
        r := GetTypeAsDeclaration(s, m, [tdfIncludeVarName, tdfStopAfterPointer] + ANewFlags, AnIndent + 4);
      if r then
        AText := AText + GetIndent + s + ';' + LineEnding
      else
        AText := AText + m.Name + ': <unknown>;' + LineEnding;
      inc(i);
    end;
  end;

  function GetPointerType(out ADeclaration: String): Boolean;
  var
    s: String;
  begin
    s := '';
    while (ADbgSymbol.Kind = skPointer) and (ADbgSymbol.TypeInfo <> nil) do begin
      ADbgSymbol := ADbgSymbol.TypeInfo;
      s := s + '^';
    end;
    if (tdfStopAfterPointer in AFlags) then begin
      Result := GetTypeName(ADeclaration, ADbgSymbol, []);
    end
    else begin
      Result := GetTypeAsDeclaration(ADeclaration, ADbgSymbol, AFlags + [tdfStopAfterPointer]);
      if not Result then
        Result := GetTypeName(ADeclaration, ADbgSymbol, []);
    end;
    if NeedBracket(ADeclaration)
    then ADeclaration := s + '(' + ADeclaration + ')'
    else ADeclaration := s + ADeclaration;
  end;

  function GetBaseType(out ADeclaration: String): Boolean;
  var
    s1, s2: String;
    hb, lb: Int64;
  begin
    if sfSubRange in ADbgSymbol.Flags then begin
      case ADbgSymbol.Kind of
        // TODO: check bound are in size
        skInteger: begin
            Result := ADbgSymbol.GetValueBounds(nil, lb, hb);
            if Result then ADeclaration := Format('%d..%d', [lb, hb]);
          end;
        skCardinal: begin
            Result := ADbgSymbol.GetValueBounds(nil, lb, hb);
            if Result then ADeclaration := Format('%u..%u', [QWord(lb), QWord(hb)]);
          end;
        skChar: begin
            Result := ADbgSymbol.GetValueBounds(nil, lb, hb);
            if (lb >= 32) and (hb <= 126)
            then s1 := '''' + chr(lb) + ''''
            else s1 := '#'+IntToStr(lb);
            if (hb >= 32) and (hb <= 126)
            then s2 := '''' + chr(hb) + ''''
            else s2 := '#'+IntToStr(hb);
            if Result then ADeclaration := Format('%s..%s', [s1, s2]);
          end;
        else
          Result := False; // not sure how to show a subrange of skFloat, skBoolean, :
      end;
    end
    else
      Result := GetTypeName(ADeclaration, ADbgSymbol, []);
  end;

  function GetParameterList(out ADeclaration: String): Boolean;
  var
    i: Integer;
    m: TFpSymbol;
    name, lname: String;
  begin
    ADeclaration := '';
    lname := '';
    for i := 0 to ADbgSymbol.NestedSymbolCount - 1 do begin
      m := ADbgSymbol.NestedSymbol[i];
      if (m <> nil) and (sfParameter in m.Flags) then begin
        GetTypeName(name, m, [tnfOnlyDeclared]);
        if (lname <> '') then begin
          if (lname = name) then
            ADeclaration := ADeclaration + ', '
          else
            ADeclaration := ADeclaration + ': ' + lname + '; ';
        end
        else
        if ADeclaration <> '' then
          ADeclaration := ADeclaration + '; ';
        ADeclaration := ADeclaration + m.Name;
        lname := name;
      end;
    end;
    if (lname <> '') then
      ADeclaration := ADeclaration + ': ' + lname;
    Result := True;
  end;

  function GetFunctionType(out ADeclaration: String): Boolean;
  var
    s, p: String;
  begin
    GetTypeAsDeclaration(s, ADbgSymbol.TypeInfo, AFlags);
    GetParameterList(p);
    ADeclaration := 'function ' + '(' + p + '): ' + s + '';
    if sfVirtual in ADbgSymbol.Flags then ADeclaration := ADeclaration + '; virtual';
    Result := true;
  end;

  function GetProcedureType(out ADeclaration: String): Boolean;
  var
    p: String;
  begin
    GetParameterList(p);
    ADeclaration := 'procedure ' + '(' + p + ')';
    if sfVirtual in ADbgSymbol.Flags then ADeclaration := ADeclaration + '; virtual';
    Result := true;
  end;

  function GetClassType(out ADeclaration: String): Boolean;
  var
    s, s2: String;
  begin
    Result := tdfSkipClassBody in AFlags;
    if Result then begin
      GetTypeName(s, ADbgSymbol);
      ADeclaration := s + ' {=class}';
      exit;
    end;
    Result := MembersAsGdbText(s, True, [tdfSkipClassBody]);
    if not GetTypeName(s2, ADbgSymbol.TypeInfo) then
      s2 := '';
    if Result then
      ADeclaration := Format('class(%s)%s%s%send',
                             [s2, LineEnding, s, GetIndent]);
  end;

  function GetRecordType(out ADeclaration: String): Boolean;
  var
    s: String;
  begin
    if tdfSkipRecordBody in AFlags then begin
      Result := True;
      if GetTypeName(s, ADbgSymbol) then
        ADeclaration := s + ' {=record}'
      else
        ADeclaration := Format('record {...};%s%send', [LineEnding, GetIndent]);
      exit;
    end;
    Result := MembersAsGdbText(s, False);
    if Result then
      ADeclaration := Format('record%s%s%send', [LineEnding, s, GetIndent]);
  end;

  function GetObjectType(out ADeclaration: String): Boolean;
  var
    s: String;
  begin
    if tdfSkipRecordBody in AFlags then begin
      Result := True;
      if GetTypeName(s, ADbgSymbol) then
        ADeclaration := s + ' {=object}'
      else
        ADeclaration := Format('object {...};%s%send', [LineEnding, GetIndent]);
      exit;
    end;
    Result := MembersAsGdbText(s, False);
    if Result then
      ADeclaration := Format('object%s%s%send', [LineEnding, s, GetIndent]);
  end;

  function GetEnumType(out ADeclaration: String): Boolean;
  var
    i, j, val: Integer;
    m: TFpSymbol;
  begin
    // TODO assigned value (a,b:=3,...)
    Result := True;
    ADeclaration := '(';
    j := 0;
    for i := 0 to ADbgSymbol.NestedSymbolCount - 1 do begin
      m := ADbgSymbol.NestedSymbol[i];
      if i > 0 then ADeclaration := ADeclaration + ', ';
      ADeclaration := ADeclaration + m.Name;
      if m.HasOrdinalValue then begin
        val := m.OrdinalValue;
        if j <> val then begin
          ADeclaration := ADeclaration + ' := ' + IntToStr(val);
          j := val;
          continue;
        end;
      end;
      inc(j);
    end;
    ADeclaration := ADeclaration + ')'
  end;

  function GetSetType(out ADeclaration: String): Boolean;
  var
    t: TFpSymbol;
    s: String;
    lb, hb: Int64;
  begin
    // TODO assigned value (a,b:=3,...)
    t := ADbgSymbol.TypeInfo;
    Result := t <> nil;
    if not Result then exit;

    case t.Kind of
      skInteger: begin
          Result := t.GetValueBounds(nil, lb, hb);
          ADeclaration := format('set of %d..%d', [lb, hb]);
        end;
      skCardinal: begin
          Result := t.GetValueBounds(nil, lb, hb);
          ADeclaration := format('set of %u..%u', [QWord(lb), QWord(hb)]);
        end;
      skEnum: begin
          if t.Name <> '' then begin
            Result := True;
            s := t.Name;
          end
          else
            Result := GetTypeAsDeclaration(s, t, AFlags);
          ADeclaration := 'set of ' + s;
        end;
      else
        Result := False;
    end;
  end;

  function GetArrayType(out ADeclaration: String): Boolean;
  var
    t: TFpSymbol;
    s: String;
    i: Integer;
    lb, hb: Int64;
  begin
    // TODO assigned value (a,b:=3,...)
    t := ADbgSymbol.TypeInfo;
    Result := (t <> nil);
    if not Result then exit;

    s := t.Name;
    if s = '' then begin
      if tdfStopAfterPointer in AFlags then
        Result := GetTypeName(s, t)
      else
        Result := GetTypeAsDeclaration(s, t, [tdfNoFirstLineIndent, tdfStopAfterPointer] + AFlags, AnIndent + 4); // no class ?
      if not Result then exit;
    end;


    if sfDynArray in ADbgSymbol.Flags then begin //supprts only one level
      ADeclaration := 'array of ' + s;
      if tdfDynArrayWithPointer in AFlags then
        ADeclaration := '^(' + ADeclaration + ')';
    end
    else begin
      ADeclaration := 'array [';
      for i := 0 to ADbgSymbol.NestedSymbolCount - 1 do begin
        if i > 0 then
          ADeclaration := ADeclaration + ', ';
        t := ADbgSymbol.NestedSymbol[i];
        t.GetValueBounds(nil, lb, hb);
        if t.Kind = skCardinal
        then ADeclaration := ADeclaration + Format('%u..%u', [QWord(lb), QWord(hb)])
        else ADeclaration := ADeclaration + Format('%d..%d', [lb, hb]);
      end;
      ADeclaration := ADeclaration + '] of ' + s;
    end;
  end;

var
  VarName: String;
begin
  Result := ADbgSymbol <> nil;
  if not Result then
    exit;
  VarName := '';
  if (ADbgSymbol.SymbolType = stValue) then begin
    if tdfIncludeVarName in AFlags then
      VarName := ADbgSymbol.Name;
    ADbgSymbol := ADbgSymbol.TypeInfo;
    Result := ADbgSymbol <> nil;
    if not Result then
      exit;
  end;

  case ADbgSymbol.Kind of
    skPointer:   Result := GetPointerType(ATypeDeclaration);
    skInteger, skCardinal, skBoolean, skChar, skFloat:
                 Result := GetBaseType(ATypeDeclaration);
    skFunction, skFunctionRef:  Result := GetFunctionType(ATypeDeclaration);
    skProcedure, skProcedureRef: Result := GetProcedureType(ATypeDeclaration);
    skClass:     Result := GetClassType(ATypeDeclaration);
    skRecord:    Result := GetRecordType(ATypeDeclaration);
    skObject:    Result := GetObjectType(ATypeDeclaration);
    //skInterface: Result := GetInterfaceType(ATypeDeclaration);
    skEnum:      Result := GetEnumType(ATypeDeclaration);
    skset:       Result := GetSetType(ATypeDeclaration);
    skArray:     Result := GetArrayType(ATypeDeclaration);
    skNone:      ATypeDeclaration := '<unknown>';
    else         Result := GetBaseType(ATypeDeclaration);
  end;

  if VarName <> '' then
    ATypeDeclaration := VarName + ': ' + ATypeDeclaration;
  if (AnIndent <> 0) and not(tdfNoFirstLineIndent in AFlags) then
    ATypeDeclaration := GetIndent + ATypeDeclaration;
end;

function QuoteWideText(AText: WideString): WideString;
const
  HEXCHR: array [0..15] of char = ('0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'A', 'B', 'C', 'D', 'E', 'F');
var
  Len: Integer;
  c: WideChar;
  RPos, SPos, SEnd, QPos: PWideChar;
begin
  if AText = '' then
    exit('''''');

  Len := Length(AText);

  SetLength(Result, Len * 4); // This is the maximal length result can get
  RPos := @Result[1];
  SPos := @AText[1];
  SEnd := @AText[Len] + 1;

  repeat
    RPos^ := ''''; inc(RPos);
    QPos := RPos;


    repeat
      c := SPos^;
      case c of
        #0..#31, #127, #$80..#$9F:
          break;
        '''': begin
          RPos^ := c; inc(RPos);
          RPos^ := c; inc(RPos);
          inc(SPos);
        end;
        else begin
          RPos^ := c; inc(RPos);
          inc(SPos);
        end;
      end;

      c := SPos^;
    until False;;

    if RPos = QPos then
      dec(RPos)
    else begin
      RPos^ := ''''; inc(RPos);
    end;

    repeat
      c := SPos^;
      if (c = #0) and (SPos >= SEnd) then begin
        // END OF TEXT
        Assert(RPos-1 <= @Result[Length(Result)], 'RPos-1 <= @Result[Length(Result)]');
        SetLength(Result, RPos - @Result[1]);
        exit;
      end;

      RPos^ := '#'; inc(RPos);
      RPos^ := '$'; inc(RPos);
      RPos^ := HEXCHR[Byte(c) >> 4]; inc(RPos);
      RPos^ := HEXCHR[Byte(c) and 15]; inc(RPos);
      inc(SPos);
      c := SPos^;
    until not(c in [#0..#31, #127, #$80..#$9F]);

  until False;
end;

function QuoteText(AText: Utf8String): UTf8String;
// TODO: process large text in chunks to avoid allocating huge memory
const
  HEXCHR: array [0..15] of char = ('0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'A', 'B', 'C', 'D', 'E', 'F');
var
  Len: Integer;
  c: Char;
  RPos, SPos, SEnd, QPos: PChar;
begin
  if AText = '' then
    exit('''''');

  Len := Length(AText);

  SetLength(Result, Len * 4); // This is the maximal length result can get
  RPos := @Result[1];
  SPos := @AText[1];
  SEnd := @AText[Len] + 1;

  repeat
    RPos^ := ''''; inc(RPos);
    QPos := RPos;


    repeat
      c := SPos^;
      case c of
        '''': begin
          RPos^ := c; inc(RPos);
          RPos^ := c; inc(RPos);
          inc(SPos);
        end;
        #32..Pred(''''), Succ('''')..#126: begin
          RPos^ := c; inc(RPos);
          inc(SPos);
        end;
        #192..#223: begin
          if ((Byte(SPos[1]) and $C0) <> $80)
          then
            break; // invalid utf8 -> escape
          RPos^ := c; inc(RPos);
          RPos^ := SPos[1]; inc(RPos);
          inc(SPos, 2);
        end;
        #224..#239: begin
          if ((Byte(SPos[1]) and $C0) <> $80) or ((Byte(SPos[2]) and $C0) <> $80)
          then
            break; // invalid utf8 -> escape
          RPos^ := c; inc(RPos);
          RPos^ := SPos[1]; inc(RPos);
          RPos^ := SPos[2]; inc(RPos);
          inc(SPos, 3);
        end;
        #240..#247: begin
          if ((Byte(SPos[1]) and $C0) <> $80) or ((Byte(SPos[2]) and $C0) <> $80) or
             ((Byte(SPos[3]) and $C0) <> $80)
          then
            break; // invalid utf8 -> escape
          RPos^ := c; inc(RPos);
          RPos^ := SPos[1]; inc(RPos);
          RPos^ := SPos[2]; inc(RPos);
          RPos^ := SPos[3]; inc(RPos);
          inc(SPos, 4);
        end;
        #0: begin
          if (SPos < SEnd) then
            break; // need escaping

          // END OF TEXT
          RPos^ := ''''; inc(RPos);
          Assert(RPos-1 <= @Result[Length(Result)], 'RPos-1 <= @Result[Length(Result)]');
          SetLength(Result, RPos - @Result[1]);
          exit;
        end;
        else
          break; // need escaping
      end;

      c := SPos^;
    until False;

    if RPos = QPos then
      dec(RPos)
    else begin
      RPos^ := ''''; inc(RPos);
    end;

    repeat
      c := SPos^;
      if (c = #0) and (SPos >= SEnd) then begin
        // END OF TEXT
        Assert(RPos-1 <= @Result[Length(Result)], 'RPos-1 <= @Result[Length(Result)]');
        SetLength(Result, RPos - @Result[1]);
        exit;
      end;

      RPos^ := '#'; inc(RPos);
      RPos^ := '$'; inc(RPos);
      RPos^ := HEXCHR[Byte(c) >> 4]; inc(RPos);
      RPos^ := HEXCHR[Byte(c) and 15]; inc(RPos);
      inc(SPos);
      c := SPos^;
    until not(c in [#0..#31, #127, #$80..#$BF]);

  until False;
end;

{ TFpPascalPrettyPrinter }

function TFpPascalPrettyPrinter.InternalPrintValue(out APrintedValue: String;
  AValue: TFpValue; AnAddressSize: Integer; AFlags: TFpPrettyPrintValueFlags;
  ANestLevel: Integer; AnIndent: String; ADisplayFormat: TWatchDisplayFormat;
  ARepeatCount: Integer; ADBGTypeInfo: PDBGType; AOptions: TFpPrettyPrintOptions): Boolean;


  function ResTypeName: String;
  begin
    if not((AValue.TypeInfo<> nil) and
           GetTypeName(Result, AValue.TypeInfo, []))
    then
      Result := '';
  end;
  function ResTypeName(AVal : TFpValue): String;
  begin
    if not((AVal.TypeInfo<> nil) and
           GetTypeName(Result, AVal.TypeInfo, []))
    then
      Result := '';
  end;

  procedure DoPointer(AnAddress: boolean);
  var
    s: String;
    v: QWord;
  begin
    if ((ADisplayFormat = wdfDefault) and (ANestLevel=0)) or // default for unested: with typename
       (ADisplayFormat = wdfStructure)
    then
      s := ResTypeName
    else
      s := '';

    if AnAddress then
      v := AValue.Address.Address
    else
      v := AValue.AsCardinal;
    if (ppvCreateDbgType in AFlags) then begin
      ADBGTypeInfo^ := TDBGType.Create(skPointer, s);
      ADBGTypeInfo^.Value.AsPointer := Pointer(v);  // TODO: no cut off
    end;

    case ADisplayFormat of
      wdfDecimal, wdfUnsigned: APrintedValue := IntToStr(v);
      wdfHex: APrintedValue := '$'+IntToHex(v, AnAddressSize*2);
      else begin //wdfPointer/Default ;
          if v = 0 then
            APrintedValue := 'nil'
          else
            APrintedValue := '$'+IntToHex(v, AnAddressSize*2);
        end;
    end;


    if ADisplayFormat = wdfPointer then begin
      if s <> '' then
        APrintedValue := s + '(' + APrintedValue + ')';
      exit; // no data
    end;

    (* In Dwarf 2 Strings are Pchar => do not add the typename.
       TODO: In Dwarf 3 this should be true pchar, maybe add typename?
    *)
    if svfString in AValue.FieldFlags then begin
      if v <> 0 then
        APrintedValue := APrintedValue + '^: ' + QuoteText(AValue.AsString);
    end
    else
    if svfWideString in AValue.FieldFlags then begin
      if v <> 0 then
        APrintedValue := APrintedValue + '^: ' + QuoteWideText(AValue.AsWideString)
    end
    else
    if s <> '' then
      APrintedValue := s + '(' + APrintedValue + ')'; // no typeinfo for strings/pchar

    Result := True;
  end;

  procedure DoUnknown;
  begin
    APrintedValue := 'Unknown type';
    if svfAddress in AValue.FieldFlags then
      APrintedValue := APrintedValue + '($'+IntToHex(AValue.Address.Address, AnAddressSize*2) + ')'
    else
    if svfDataAddress in AValue.FieldFlags then
      APrintedValue := APrintedValue + '($'+IntToHex(AValue.DataAddress.Address, AnAddressSize*2) + ')';
    Result := True;
  end;

  procedure DoType;
  begin
    // maybe include tdfIncludeVarName for structure members "TFooClass.SomeField"
    if GetTypeAsDeclaration(APrintedValue, AValue.DbgSymbol) then
      APrintedValue := 'type ' + APrintedValue
    else
      DoUnknown;
    Result := True;
  end;

  procedure DoFunction;
  var
    s: String;
    proc, procref: TFpSymbolDwarf;
    t, sym: TFpSymbol;
    par: TFpValueDwarf;
    v: TFpDbgMemLocation;
    va: TDBGPtr;
  begin
    proc := nil;
    procref := nil;
    v := AValue.DataAddress;
    va := v.Address;
    if (ppvCreateDbgType in AFlags) then begin
      ADBGTypeInfo^ := TDBGType.Create(AValue.Kind, '');
      if AValue.Kind in [skFunctionRef, skProcedureRef] then
        ADBGTypeInfo^.Value.AsPointer := Pointer(va);  // TODO: no cut off
    end;

    // TODO: depending on verbosity: TypeName($0123456)
    if AValue.Kind in [skFunctionRef, skProcedureRef] then begin
      if va = 0 then
        APrintedValue := 'nil'
      else
        APrintedValue := '$'+IntToHex(va, AnAddressSize*2);

      t := AValue.TypeInfo;
      sym := AValue.DbgSymbol;
      if (sym is TFpSymbolDwarfDataProc) then begin
        proc := TFpSymbolDwarf(sym);
      end
      else begin
        proc := TFpSymbolDwarf(TDbgDwarfSymbolBase(t).CompilationUnit.Owner.FindProcSymbol(va));
        procref := proc;
      end;
      if proc <> nil then begin
        s := proc.Name;
        if (proc is TFpSymbolDwarfDataProc) then begin
          par := TFpSymbolDwarfDataProc(proc).GetSelfParameter; // Has no Context set, but we only need TypeInfo.Name
          if (par <> nil) and (par.TypeInfo <> nil) then
            s := par.TypeInfo.Name + '.' + s;
          par.ReleaseReference;
        end;
        APrintedValue := APrintedValue + ' = ' + s; // TODO: offset to startaddress
      end;
      APrintedValue := APrintedValue + ': ';
    end
    else
      t := AValue.DbgSymbol;

    if AFlags * PV_FORWARD_FLAGS <> [] then
      GetTypeName(s, t)
    else
      GetTypeAsDeclaration(s, t);
    APrintedValue := APrintedValue + s;

    if (AValue.Kind in [skFunction, skProcedure]) and IsReadableLoc(v) then begin
      APrintedValue := APrintedValue + ' AT ' + '$'+IntToHex(va, AnAddressSize*2);
    end;

    ReleaseRefAndNil(procref);
    Result := True;
  end;

  procedure DoInt;
  var
    n: Integer;
    ValSize: TFpDbgValueSize;
  begin
    case ADisplayFormat of
      wdfUnsigned: APrintedValue := IntToStr(QWord(AValue.AsInteger));
      wdfHex: begin
          if (svfSize in AValue.FieldFlags) and AValue.GetSize(ValSize) then
            n := SizeToFullBytes(ValSize)* 2
          else begin
            n := 16;
            if QWord(AValue.AsInteger) <= high(Cardinal) then n := 8;
            if QWord(AValue.AsInteger) <= high(Word) then n := 3;
            if QWord(AValue.AsInteger) <= high(Byte) then n := 2;
          end;
          APrintedValue := '$'+IntToHex(QWord(AValue.AsInteger), n);
        end;
      // TODO wdfChar:
      else
          APrintedValue := IntToStr(AValue.AsInteger);
    end;

    if (ppvCreateDbgType in AFlags) then begin
      ADBGTypeInfo^ := TDBGType.Create(skSimple, ResTypeName);
      //ADBGTypeInfo^.Value.As64Bits := QWord(AValue.AsInteger); // TODO: no cut off
    end;
    Result := True;
  end;

  procedure DoCardinal;
  var
    n: Integer;
    ValSize: TFpDbgValueSize;
  begin
    case ADisplayFormat of
      wdfDecimal: APrintedValue := IntToStr(Int64(AValue.AsCardinal));
      wdfHex: begin
          if (svfSize in AValue.FieldFlags) and AValue.GetSize(ValSize) then
            n := SizeToFullBytes(ValSize)* 2
          else begin
            n := 16;
            if AValue.AsCardinal <= high(Cardinal) then n := 8;
            if AValue.AsCardinal <= high(Word) then n := 4;
            if AValue.AsCardinal <= high(Byte) then n := 2;
          end;
          APrintedValue := '$'+IntToHex(AValue.AsCardinal, n);
        end;
      // TODO wdfChar:
      else
          APrintedValue := IntToStr(AValue.AsCardinal);
    end;

    if (ppvCreateDbgType in AFlags) then begin
      ADBGTypeInfo^ := TDBGType.Create(skSimple, ResTypeName);
      //ADBGTypeInfo^.Value.As64Bits := QWord(AValue.AsiCardinal); // TODO: no cut off
    end;
    Result := True;
  end;

  procedure DoBool;
  begin
    if AValue.AsBool then begin
      APrintedValue := 'True';
      if AValue.AsCardinal <> 1 then
        APrintedValue := APrintedValue + '(' + IntToStr(AValue.AsCardinal) + ')';
    end
    else
      APrintedValue := 'False';

    if (ppvCreateDbgType in AFlags) then begin
      ADBGTypeInfo^ := TDBGType.Create(skSimple, ResTypeName);
    end;
    Result := True;
  end;

  procedure DoChar;
  begin
    if svfWideString in AValue.FieldFlags then
      APrintedValue := QuoteWideText(AValue.AsWideString)
    else
      APrintedValue := QuoteText(AValue.AsString);
    if (ppvCreateDbgType in AFlags) then begin
      ADBGTypeInfo^ := TDBGType.Create(skSimple, ResTypeName);
    end;
    Result := True;
  end;

  procedure DoString;
  begin
    APrintedValue := QuoteText(AValue.AsString);
    if (ppvCreateDbgType in AFlags) then begin
      ADBGTypeInfo^ := TDBGType.Create(skString, ResTypeName);
    end;
    Result := True;
  end;

  procedure DoWideString;
  begin
    APrintedValue := QuoteWideText(AValue.AsWideString);
    if (ppvCreateDbgType in AFlags) then begin
      ADBGTypeInfo^ := TDBGType.Create(skWideString, ResTypeName);
    end;
    Result := True;
  end;

  procedure DoFloat;
  begin
    APrintedValue := FloatToStr(AValue.AsFloat);
    if (ppvCreateDbgType in AFlags) then begin
      ADBGTypeInfo^ := TDBGType.Create(skSimple, ResTypeName);
    end;
    Result := True;
  end;

  procedure DoEnum;
  var
    s: String;
  begin
    APrintedValue := AValue.AsString;
    if APrintedValue = '' then begin
      s := ResTypeName;
      APrintedValue := s + '(' + IntToStr(AValue.AsCardinal) + ')';
    end
    else if (ppvCreateDbgType in AFlags) then
      s := ResTypeName;

    if (ppvCreateDbgType in AFlags) then begin
      ADBGTypeInfo^ := TDBGType.Create(skEnum, s);
    end;
    Result := True;
  end;

  procedure DoEnumVal;
  begin
    APrintedValue := AValue.AsString;
    if APrintedValue <> '' then
      APrintedValue := APrintedValue + ':=';
    APrintedValue := APrintedValue+ IntToStr(AValue.AsCardinal);

    if (ppvCreateDbgType in AFlags) then begin
      ADBGTypeInfo^ := TDBGType.Create(skSimple, ResTypeName);
    end;
    Result := True;
  end;

  procedure DoSet;
  var
    s: String;
    i: Integer;
    m: TFpValue;
  begin
    APrintedValue := '';
    for i := 0 to AValue.MemberCount-1 do begin
      m := AValue.Member[i];
      if svfIdentifier in m.FieldFlags then
        s := m.AsString
      else
      if svfOrdinal in m.FieldFlags then // set of byte
        s := IntToStr(m.AsCardinal)
      else
      begin
        m.ReleaseReference;
        continue;
      end;

      if APrintedValue = ''
      then APrintedValue := s
      else APrintedValue := APrintedValue + ', ' + s;
      m.ReleaseReference;
    end;
    APrintedValue := '[' + APrintedValue + ']';

    if (ppvCreateDbgType in AFlags) then begin
      ADBGTypeInfo^ := TDBGType.Create(skSet, ResTypeName);
    end;
    Result := True;
  end;

  procedure DoStructure;
  var
    s, s2, MbName, MbVal: String;
    i: Integer;
    MemberValue: TFpValue;
    fl: TFpPrettyPrintValueFlags;
    f: TDBGField;
    ti: TFpSymbol;
    Cache: TFpDbgMemCacheBase;
  begin
    if (AValue.Kind in [skClass, skInterface]) and (AValue.AsCardinal = 0) then begin
      APrintedValue := 'nil';
      if (ppvCreateDbgType in AFlags) then begin
        ADBGTypeInfo^ := TDBGType.Create(skSimple, ResTypeName);
      end;
      Result := True;
      exit;
    end;

    if not Context.MemManager.CheckDataSize(SizeToFullBytes(AValue.DataSize)) then begin
      APrintedValue := ErrorHandler.ErrorAsString(Context.LastMemError);
      Result := True;
      exit;
    end;

    if Context.MemManager.CacheManager <> nil then
      Cache := Context.MemManager.CacheManager.AddCache(AValue.DataAddress.Address, SizeToFullBytes(AValue.DataSize))
    else
      Cache := nil;
    try

      if (ppvCreateDbgType in AFlags) then begin
        s := ResTypeName;
        case AValue.Kind of
          skRecord: ADBGTypeInfo^ := TDBGType.Create(skRecord, s);
          skObject: ADBGTypeInfo^ := TDBGType.Create(skObject, s);
          skClass:  ADBGTypeInfo^ := TDBGType.Create(skClass, s);
          skInterface:  ADBGTypeInfo^ := TDBGType.Create(skInterface, s);
        end;
      end;

      if ((ADisplayFormat = wdfPointer) or (ppoStackParam in AOptions)) and (AValue.Kind in [skClass, skInterface]) then begin
        if not (ppvCreateDbgType in AFlags) then
          s := ResTypeName;
        APrintedValue := '$'+IntToHex(AValue.AsCardinal, AnAddressSize*2);
        if s <> '' then
          APrintedValue := s + '(' + APrintedValue + ')';
        Result := True;
        if not (ppvCreateDbgType in AFlags) then
          exit;
      end
      else
      if ( (AValue.Kind in [skClass, skObject]) and (ppvSkipClassBody in AFlags) ) or
         ( (AValue.Kind in [skRecord]) and (ppvSkipRecordBody in AFlags) )
      then begin
        APrintedValue := ResTypeName;
        case AValue.Kind of
          skRecord: APrintedValue := '{record:}' + APrintedValue;
          skObject: APrintedValue := '{object:}' + APrintedValue;
          skClass:  APrintedValue := '{class:}' + APrintedValue + '(' + '$'+IntToHex(AValue.AsCardinal, AnAddressSize*2) + ')';
        end;
        Result := True;
        if not (ppvCreateDbgType in AFlags) then
          exit;
      end;

      s2 := LineEnding;
      if AFlags <> [] then s2 := ' ';;
      fl := [ppvSkipClassBody];
      //if ppvSkipClassBody in AFlags then
      //  fl := [ppvSkipClassBody, ppvSkipRecordBody];

      if (ppvCreateDbgType in AFlags) and (AValue.Kind in [skObject, skClass]) then begin
        ti := AValue.TypeInfo;
        if (ti <> nil) and (ti.TypeInfo <> nil) then
          ADBGTypeInfo^.Ancestor := ti.TypeInfo.Name;
      end;

      if not Result then
        APrintedValue := '';
      for i := 0 to AValue.MemberCount-1 do begin
        MemberValue := AValue.Member[i];
        if (MemberValue = nil) or (MemberValue.Kind in [skProcedure, skFunction]) then begin
          MemberValue.ReleaseReference;
          continue;
        end;
        s := '';
        // ppoStackParam: Do not expand nested structures // may need ppoSingleLine?
        InternalPrintValue(MbVal, MemberValue, AnAddressSize, fl, ANestLevel+1, AnIndent, ADisplayFormat, -1, nil, AOptions+[ppoStackParam]);
        if MemberValue.DbgSymbol <> nil then begin
          MbName := MemberValue.DbgSymbol.Name;
          if (ppoStackParam in AOptions) then
            s := MbVal
          else
            s := MbName + ' = ' + MbVal;
        end
        else begin
          MbName := '';
          s := MbVal;
        end;

        if not Result then begin
          if APrintedValue = ''
          then APrintedValue := s
          else APrintedValue := APrintedValue + ';' + LineEnding + s2 + s;
        end;
        if (ppvCreateDbgType in AFlags) then begin
          s := '';
          if MemberValue.ParentTypeInfo <> nil then s := MemberValue.ParentTypeInfo.Name;
          f := TDBGField.Create(MbName, TDBGType.Create(skSimple, ResTypeName(MemberValue)),
                                flPublic, [], s);
          f.DBGType.Value.AsString := MbVal;
          ADBGTypeInfo^.Fields.Add(f);
        end;
        MemberValue.ReleaseReference;
      end;
      if not Result then
        APrintedValue := ResTypeName + ' (' + APrintedValue + ')';
      Result := True;
    finally
      if Cache <> nil then
        Context.MemManager.CacheManager.RemoveCache(Cache)
    end;
  end;

  procedure DoArray;
  var
    s: String;
    i: Integer;
    MemberValue: TFpValue;
    Cnt, FullCnt: Integer;
    d: Int64;
  begin
    APrintedValue := '';

    if (ppvCreateDbgType in AFlags) then begin
      ADBGTypeInfo^ := TDBGType.Create(skArray, ResTypeName);
    //ATypeInfo.Len;
    //ATypeInfo.BoundLow;
    //ATypeInfo.BoundHigh;
    end;

    Cnt := AValue.MemberCount;
    if (Context.MemManager.MemLimits.MaxArrayLen > 0) and (Cnt > Context.MemManager.MemLimits.MaxArrayLen) then
      Cnt := Context.MemManager.MemLimits.MaxArrayLen;

    FullCnt := Cnt;
    if (Cnt = 0) and (svfOrdinal in AValue.FieldFlags) then begin  // dyn array
      APrintedValue := 'nil';
      Result := True;
      exit;
    end;
    if (ANestLevel > 2) then begin
      s := ResTypeName;
      APrintedValue := s+'({'+IntToStr(FullCnt)+' elements})'; // TODO len and addr (dyn array)
      Result := True;
      exit;
    end;
    If ARepeatCount > 0                     then Cnt := ARepeatCount
    else if (ANestLevel > 1) and (Cnt > 3)  then Cnt := 3
    else if (ANestLevel > 0) and (Cnt > 10) then Cnt := 10
    else if (Cnt > 300)                     then Cnt := 300;

    if (AValue.IndexTypeCount = 0) or (not AValue.IndexType[0].GetValueLowBound(AValue, d)) then
      d := 0;
    for i := d to d + Cnt - 1 do begin
      MemberValue := AValue.Member[i];
      if MemberValue <> nil then
        InternalPrintValue(s, MemberValue, AnAddressSize, AFlags * PV_FORWARD_FLAGS, ANestLevel+1, AnIndent, ADisplayFormat, -1, nil, AOptions)
      else
        s := '{error}';
      MemberValue.ReleaseReference;
      if APrintedValue = ''
      then APrintedValue := s
      else APrintedValue := APrintedValue + ', ' + s;
    end;
    if Cnt < FullCnt then
      APrintedValue := APrintedValue + ', {'+IntToStr(FullCnt-Cnt)+' more elements}';
    APrintedValue := '(' + APrintedValue + ')';
    Result := True;
  end;
var
  MemAddr: TFpDbgMemLocation;
  MemSize: Integer;
  MemDest: array of Byte;
  i: Integer;
  ValSize: TFpDbgValueSize;
begin
  if ADBGTypeInfo <> nil then ADBGTypeInfo^ := nil;
  if ANestLevel > 0 then begin
    AnIndent := AnIndent + '  ';
  end;

  if ADisplayFormat = wdfMemDump then begin
    if FContext <> nil then begin
      MemAddr := UnInitializedLoc;
      if svfDataAddress in AValue.FieldFlags then begin
        MemAddr := AValue.DataAddress;
        MemSize := SizeToFullBytes(AValue.DataSize);
      end
      else
      if svfAddress in AValue.FieldFlags then begin
        MemAddr := AValue.Address;
        if not AValue.GetSize(ValSize) then
          ValSize := SizeVal(256);
        MemSize := SizeToFullBytes(ValSize);
      end;
      if MemSize < ARepeatCount then MemSize := ARepeatCount;
      if MemSize <= 0 then MemSize := 256;

      if IsTargetAddr(MemAddr) then begin
        if not Context.MemManager.SetLength(MemDest, MemSize) then begin
          APrintedValue := ErrorHandler.ErrorAsString(Context.MemManager.LastError);
        end
        else
        if FContext.ReadMemory(MemAddr, SizeVal(MemSize), @MemDest[0]) then begin
          APrintedValue := IntToHex(MemAddr.Address, AnAddressSize*2)+ ':' + LineEnding;
          for i := 0 to high(MemDest) do begin
            if (i > 0) and (i mod 16 = 0) then
              APrintedValue := APrintedValue + LineEnding
            else
            if (i > 0) and (i mod 8 = 0) then
              APrintedValue := APrintedValue + '  '
            else
            if (i > 0)  then
              APrintedValue := APrintedValue + ' ';
            APrintedValue := APrintedValue + IntToHex(MemDest[i], 2);
          end;
        end
        else begin
          APrintedValue := 'Cannot read memory at address '+ IntToHex(MemAddr.Address, AnAddressSize*2);
        end;
        exit;
      end;
    end;

    APrintedValue := 'Cannot read memory for expression';
    exit
  end;

  Result := False;
  case AValue.Kind of
    skUnit: ;
    skProcedure,
    skFunction,
    skProcedureRef,
    skFunctionRef:  DoFunction;
    skPointer:   DoPointer(False);
    skInteger:   DoInt;
    skCardinal:  DoCardinal;
    skBoolean:   DoBool;
    skChar:      DoChar;
    skFloat:     DoFloat;
    skString:    DoString;
    skAnsiString: ;
    skCurrency: ;
    skVariant: ;
    skWideString: DoWideString;
    skEnum:      DoEnum;
    skEnumValue: DoEnumVal;
    skSet:       DoSet;
    skRecord:    DoStructure;
    skObject:    DoStructure;
    skClass:     DoStructure;
    skInterface: DoStructure;
    skArray:     DoArray;
    skType:      DoType;
    skNone:      DoUnknown;
  end;

  if (ADBGTypeInfo <> nil) and (ADBGTypeInfo^ <> nil) then
    ADBGTypeInfo^.Value.AsString := APrintedValue;

  if IsError(AValue.LastError) then
    APrintedValue := ErrorHandler.ErrorAsString(AValue.LastError);
end;

constructor TFpPascalPrettyPrinter.Create(AnAddressSize: Integer);
begin
  FAddressSize := AnAddressSize;
end;

function TFpPascalPrettyPrinter.PrintValue(out APrintedValue: String; AValue: TFpValue;
  ADisplayFormat: TWatchDisplayFormat; ARepeatCount: Integer;
  AOptions: TFpPrettyPrintOptions): Boolean;
begin
  Result := InternalPrintValue(APrintedValue, AValue,
                               AddressSize, [], 0, '', ADisplayFormat, ARepeatCount, nil, AOptions);
end;

function TFpPascalPrettyPrinter.PrintValue(out APrintedValue: String; out
  ADBGTypeInfo: TDBGType; AValue: TFpValue; ADisplayFormat: TWatchDisplayFormat;
  ARepeatCount: Integer): Boolean;
begin
  Result := InternalPrintValue(APrintedValue, AValue,
                               AddressSize, [ppvCreateDbgType], 0, '',
                               ADisplayFormat, ARepeatCount, @ADBGTypeInfo);
end;

end.


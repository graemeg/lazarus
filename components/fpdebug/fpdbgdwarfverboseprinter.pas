unit FpDbgDwarfVerbosePrinter;

{$mode objfpc}{$H+}

interface

uses
  Classes, Math, SysUtils, FpDbgDwarf, FpDbgLoader, FpDbgDwarfConst, FpdMemoryTools,
  FpImgReaderBase, FpDbgDwarfDataClasses, {$ifdef FORCE_LAZLOGGER_DUMMY} LazLoggerDummy {$else} LazLoggerBase {$endif}, maps;

type

  { TDwarfAbbrevDecoder }

  TDwarfAbbrevDecoder = class(TObject)
  private
    FCU: TDwarfCompilationUnit;
    function  ReadTargetAddressFromDwarfSection(var AData: Pointer; AIncPointer: Boolean = False): TFpDbgMemLocation;
    function  ReadDwarfSectionOffsetOrLenFromDwarfSection(var AData: Pointer; AIncPointer: Boolean = False): TFpDbgMemLocation;
    procedure InternalDecode(AData: Pointer; AMaxData: Pointer; const AIndent: String = '');
  protected
    procedure DecodeLocation(AData: PByte; ASize: QWord; const AIndent: String = '');
    procedure DecodeLocationList({%H-}AReference: QWord; const {%H-}AIndent: String = '');
    function MakeAddressString(AData: Pointer): string;
  public
    constructor Create(ACompilationUnit: TDwarfCompilationUnit);
    procedure Decode;
  end;

  { TDwarfStatementDecoder }

  TDwarfStatementDecoder = class(TObject)
  private
    FCU: TDwarfCompilationUnit;
    procedure InternalDecode(AData: Pointer; {%H-}AMaxData: Pointer; const {%H-}AIndent: String = '');
  protected
  public
    constructor Create(ACompilationUnit: TDwarfCompilationUnit);
    procedure Decode(AData: Pointer); // Adata := FCU.FLineInfo.Header
  end;

  { TVerboseDwarfCallframeDecoder }

  TVerboseDwarfCallframeDecoder = class(TObject)
  private
    FLoader: TDbgImageLoader;
    procedure InternalDecode(AData: Pointer; ASize, AStart: QWord);
  protected
  public
    constructor Create(ALoader: TDbgImageLoader);
    procedure Decode;
  end;

implementation
var
  FPDBG_DWARF_VERBOSE, FPDBG_DWARF_WARNINGS: PLazLoggerLogGroup;

{ TDwarfAbbrevDecoder }

constructor TDwarfAbbrevDecoder.Create(ACompilationUnit: TDwarfCompilationUnit);
begin
  inherited Create;
  FCU := ACompilationUnit;
end;

procedure TDwarfAbbrevDecoder.Decode;
var
  Iter: TMapIterator;
  Info: TDwarfAddressInfo;
  Scope: TDwarfScopeInfo;
begin
  // force all abbrevs to be loaded
  InternalDecode(FCU.InfoData, FCU.InfoData + FCU.InfoDataLength);

  DebugLn(FPDBG_DWARF_VERBOSE, ['addresses: ']);
  Iter := TMapIterator.Create(FCU.AddressMap);
  while not Iter.EOM do
  begin
    Iter.GetData(Info);
    DbgOut(FPDBG_DWARF_VERBOSE, ['  ']);
    Scope.Init(Info.ScopeList);
    Scope.Index := Info.ScopeIndex;
    Scope := Scope.Parent;
    while Scope.IsValid do
    begin
      DbgOut(FPDBG_DWARF_VERBOSE, ['.']);
      Scope := Scope.Parent;
    end;
    DebugLn(FPDBG_DWARF_VERBOSE, [Info.Name, ': $', IntToHex(Info.StartPC, FCU.AddressSize * 2), '..$', IntToHex(Info.EndPC, FCU.AddressSize * 2)]);
    Iter.Next;
  end;
  Iter.Free;

end;

procedure TDwarfAbbrevDecoder.DecodeLocation(AData: PByte; ASize: QWord; const AIndent: String);
var
  MaxData: PByte;
  v: Int64;
begin
  MaxData := AData + ASize - 1;
  while AData <= MaxData do
  begin
    DbgOut(FPDBG_DWARF_VERBOSE, [AIndent]);
    case AData^ of
      DW_OP_addr: begin
        DbgOut(FPDBG_DWARF_VERBOSE, ['DW_OP_addr ', MakeAddressString(@AData[1])]);
        Inc(AData, 4);
      end;
      DW_OP_deref: begin
        DbgOut(FPDBG_DWARF_VERBOSE, ['DW_OP_deref']);
      end;
      DW_OP_const1u: begin
        DbgOut(FPDBG_DWARF_VERBOSE, ['DW_OP_const1u ', AData[1]]);
        Inc(AData, 1);
      end;
      DW_OP_const1s: begin
        DbgOut(FPDBG_DWARF_VERBOSE, ['DW_OP_const1s ', PShortInt(@AData[1])^]);
        Inc(AData, 1);
      end;
      DW_OP_const2u: begin
        DbgOut(FPDBG_DWARF_VERBOSE, ['DW_OP_const2u ', PWord(@AData[1])^]);
        Inc(AData, 2);
      end;
      DW_OP_const2s: begin
        DbgOut(FPDBG_DWARF_VERBOSE, ['DW_OP_const2s ', PSmallInt(@AData[1])^]);
        Inc(AData, 2);
      end;
      DW_OP_const4u: begin
        DbgOut(FPDBG_DWARF_VERBOSE, ['DW_OP_const4u ', PLongWord(@AData[1])^]);
        Inc(AData, 4);
      end;
      DW_OP_const4s: begin
        DbgOut(FPDBG_DWARF_VERBOSE, ['DW_OP_const4s ', PLongInt(@AData[1])^]);
        Inc(AData, 4);
      end;
      DW_OP_const8u: begin
        DbgOut(FPDBG_DWARF_VERBOSE, ['DW_OP_const8u ', PQWord(@AData[1])^]);
        Inc(AData, 8);
      end;
      DW_OP_const8s: begin
        DbgOut(FPDBG_DWARF_VERBOSE, ['DW_OP_const8s ', PInt64(@AData[1])^]);
        Inc(AData, 8);
      end;
      DW_OP_constu: begin
        Inc(AData);
        DbgOut(FPDBG_DWARF_VERBOSE, ['DW_OP_constu ', ULEB128toOrdinal(AData)]);;
        Dec(AData);
      end;
      DW_OP_consts: begin
        Inc(AData);
        DbgOut(FPDBG_DWARF_VERBOSE, ['DW_OP_consts ', SLEB128toOrdinal(AData)]);;
        Dec(AData);
      end;
      DW_OP_dup: begin
        DbgOut(FPDBG_DWARF_VERBOSE, ['DW_OP_dup']);
      end;
      DW_OP_drop: begin
        DbgOut(FPDBG_DWARF_VERBOSE, ['DW_OP_drop']);
      end;
      DW_OP_over: begin
        DbgOut(FPDBG_DWARF_VERBOSE, ['DW_OP_over']);
      end;
      DW_OP_pick: begin
        DbgOut(FPDBG_DWARF_VERBOSE, ['DW_OP_pick ', AData[1]]);
        Inc(AData, 1);
      end;
      DW_OP_swap: begin
        DbgOut(FPDBG_DWARF_VERBOSE, ['DW_OP_swap']);
      end;
      DW_OP_rot: begin
        DbgOut(FPDBG_DWARF_VERBOSE, ['DW_OP_rot']);
      end;
      DW_OP_xderef: begin
        DbgOut(FPDBG_DWARF_VERBOSE, ['DW_OP_xderef']);
      end;
      DW_OP_abs: begin
        DbgOut(FPDBG_DWARF_VERBOSE, ['DW_OP_abs']);
      end;
      DW_OP_and: begin
        DbgOut(FPDBG_DWARF_VERBOSE, ['DW_OP_and']);
      end;
      DW_OP_div: begin
        DbgOut(FPDBG_DWARF_VERBOSE, ['DW_OP_div']);
      end;
      DW_OP_minus: begin
        DbgOut(FPDBG_DWARF_VERBOSE, ['DW_OP_minus']);
      end;
      DW_OP_mod: begin
        DbgOut(FPDBG_DWARF_VERBOSE, ['DW_OP_mod']);
      end;
      DW_OP_mul: begin
        DbgOut(FPDBG_DWARF_VERBOSE, ['DW_OP_mul']);
      end;
      DW_OP_neg: begin
        DbgOut(FPDBG_DWARF_VERBOSE, ['DW_OP_neg']);
      end;
      DW_OP_not: begin
        DbgOut(FPDBG_DWARF_VERBOSE, ['DW_OP_not']);
      end;
      DW_OP_or: begin
        DbgOut(FPDBG_DWARF_VERBOSE, ['DW_OP_or']);
      end;
      DW_OP_plus: begin
        DbgOut(FPDBG_DWARF_VERBOSE, ['DW_OP_plus']);
      end;
      DW_OP_plus_uconst: begin
        Inc(AData);
        DbgOut(FPDBG_DWARF_VERBOSE, ['DW_OP_plus_uconst ', ULEB128toOrdinal(AData)]);;
        Dec(AData);
      end;
      DW_OP_shl: begin
        DbgOut(FPDBG_DWARF_VERBOSE, ['DW_OP_shl']);
      end;
      DW_OP_shr: begin
        DbgOut(FPDBG_DWARF_VERBOSE, ['DW_OP_shr']);
      end;
      DW_OP_shra: begin
        DbgOut(FPDBG_DWARF_VERBOSE, ['DW_OP_shra']);
      end;
      DW_OP_xor: begin
        DbgOut(FPDBG_DWARF_VERBOSE, ['DW_OP_xor']);
      end;
      DW_OP_skip: begin
        DbgOut(FPDBG_DWARF_VERBOSE, ['DW_OP_skip ', PSmallInt(@AData[1])^]);
        Inc(AData, 2);
      end;
      DW_OP_bra: begin
        DbgOut(FPDBG_DWARF_VERBOSE, ['DW_OP_bra ', PSmallInt(@AData[1])^]);
        Inc(AData, 2);
      end;
      DW_OP_eq: begin
        DbgOut(FPDBG_DWARF_VERBOSE, ['DW_OP_eq']);
      end;
      DW_OP_ge: begin
        DbgOut(FPDBG_DWARF_VERBOSE, ['DW_OP_ge']);
      end;
      DW_OP_gt: begin
        DbgOut(FPDBG_DWARF_VERBOSE, ['DW_OP_gt']);
      end;
      DW_OP_le: begin
        DbgOut(FPDBG_DWARF_VERBOSE, ['DW_OP_le']);
      end;
      DW_OP_lt: begin
        DbgOut(FPDBG_DWARF_VERBOSE, ['DW_OP_lt']);
      end;
      DW_OP_ne: begin
        DbgOut(FPDBG_DWARF_VERBOSE, ['DW_OP_ne']);
      end;
      DW_OP_lit0..DW_OP_lit31: begin
        DbgOut(FPDBG_DWARF_VERBOSE, ['DW_OP_lit', AData^ - DW_OP_lit0]);
      end;
      DW_OP_reg0..DW_OP_reg31: begin
        DbgOut(FPDBG_DWARF_VERBOSE, ['DW_OP_reg', AData^ - DW_OP_reg0]);
      end;
      DW_OP_breg0..DW_OP_breg31: begin
        DbgOut(FPDBG_DWARF_VERBOSE, ['DW_OP_breg', AData^ - DW_OP_breg0]);
        Inc(AData);
        v := SLEB128toOrdinal(AData);
        Dec(AData);
        if v >= 0
        then DbgOut(FPDBG_DWARF_VERBOSE, ['+']);
        DbgOut(FPDBG_DWARF_VERBOSE, [v]);
      end;
      DW_OP_regx: begin
        Inc(AData);
        DbgOut(FPDBG_DWARF_VERBOSE, ['DW_OP_regx ', ULEB128toOrdinal(AData)]);
        Dec(AData);
      end;
      DW_OP_fbreg: begin
        Inc(AData);
        DbgOut(FPDBG_DWARF_VERBOSE, ['DW_OP_fbreg ', SLEB128toOrdinal(AData)]);
        Dec(AData);
      end;
      DW_OP_bregx: begin
        Inc(AData);
        DbgOut(FPDBG_DWARF_VERBOSE, ['DW_OP_bregx ', ULEB128toOrdinal(AData)]);
        v := SLEB128toOrdinal(AData);
        Dec(AData);
        if v >= 0
        then DbgOut(FPDBG_DWARF_VERBOSE, ['+']);
        DbgOut(FPDBG_DWARF_VERBOSE, [v]);
      end;
      DW_OP_piece: begin
        Inc(AData);
        DbgOut(FPDBG_DWARF_VERBOSE, ['DW_OP_piece ', ULEB128toOrdinal(AData)]);
        Dec(AData);
      end;
      DW_OP_deref_size: begin
        DbgOut(FPDBG_DWARF_VERBOSE, ['DW_OP_deref_size ', AData[1]]);
        Inc(AData);
      end;
      DW_OP_xderef_size: begin
        DbgOut(FPDBG_DWARF_VERBOSE, ['DW_OP_xderef_size', AData[1]]);
        Inc(AData);
      end;
      DW_OP_nop: begin
        DbgOut(FPDBG_DWARF_VERBOSE, ['DW_OP_nop']);
      end;
      DW_OP_push_object_address: begin
        DbgOut(FPDBG_DWARF_VERBOSE, ['DW_OP_push_object_address']);
      end;
      DW_OP_call2: begin
        DbgOut(FPDBG_DWARF_VERBOSE, ['DW_OP_call2 ', PWord(@AData[1])^]);
        Inc(AData, 2);
      end;
      DW_OP_call4: begin
        DbgOut(FPDBG_DWARF_VERBOSE, ['DW_OP_call4 ', PLongWord(@AData[1])^]);
        Inc(AData, 4);
      end;
      DW_OP_call_ref: begin
        DbgOut(FPDBG_DWARF_VERBOSE, ['DW_OP_call_ref ', MakeAddressString(@AData[1])]);
        Inc(AData, 4);
      end;
      DW_OP_form_tls_address: begin
        DbgOut(FPDBG_DWARF_VERBOSE, ['DW_OP_form_tls_address']);
      end;
      DW_OP_call_frame_cfa: begin
        DbgOut(FPDBG_DWARF_VERBOSE, ['DW_OP_call_frame_cfa']);
      end;
      DW_OP_bit_piece: begin
        Inc(AData);
        DbgOut(FPDBG_DWARF_VERBOSE, ['DW_OP_bit_piece ', ULEB128toOrdinal(AData), ' ', ULEB128toOrdinal(AData)]);
        Dec(AData);
      end;
      DW_OP_lo_user..DW_OP_hi_user: begin
        DbgOut(FPDBG_DWARF_VERBOSE, ['DW_OP_user=', AData^]);
      end;
    else
      DbgOut(FPDBG_DWARF_VERBOSE, ['Unknown DW_OP_', AData^]);
    end;
    Inc(AData);
    DebugLn(FPDBG_DWARF_VERBOSE, ['']);
  end;
end;

procedure TDwarfAbbrevDecoder.DecodeLocationList(AReference: QWord; const AIndent: String);
begin

end;

function TDwarfAbbrevDecoder.ReadTargetAddressFromDwarfSection(
  var AData: Pointer; AIncPointer: Boolean): TFpDbgMemLocation;
begin
  // do not need mem reader, address is in dwarf. Should be in correct format
  if FCU.AddressSize = 4
  then Result := TargetLoc(PLongWord(AData)^)
  else Result := TargetLoc(PQWord(AData)^);
  if AIncPointer then inc(AData, FCU.AddressSize);
end;

function TDwarfAbbrevDecoder.ReadDwarfSectionOffsetOrLenFromDwarfSection(var AData: Pointer;
  AIncPointer: Boolean): TFpDbgMemLocation;
begin
  // do not need mem reader, address is in dwarf. Should be in correct format
  if FCU.AddressSize = 4 // TODO Dwarf3 depends on FIsDwarf64
  then Result := TargetLoc(PLongWord(AData)^)
  else Result := TargetLoc(PQWord(AData)^);
  if AIncPointer then inc(AData, FCU.AddressSize);
end;

procedure TDwarfAbbrevDecoder.InternalDecode(AData: Pointer; AMaxData: Pointer; const AIndent: String);
  procedure Dump(var p: PByte; count: QWord);
  var
    n: integer;
  begin
    for n := 1 to Min(80, count) do
    begin
      DbgOut(FPDBG_DWARF_VERBOSE, [IntToHex(p^, 2), ' ']);
      Inc(p);
    end;
    if Count > 80
    then begin
      Inc(p, Count - 80);
      DbgOut(FPDBG_DWARF_VERBOSE, ['...']);
    end;
  end;
  procedure DumpStr(var p: PChar);
  begin
    while p^ <> #0 do
    begin
      case p^ of
        #32..#127: DbgOut(FPDBG_DWARF_VERBOSE, [p^]);
      else
        DbgOut(FPDBG_DWARF_VERBOSE, ['<', IntToHex(Ord(p^), 2), '>']);
      end;
      Inc(p);
    end;
    Inc(p);
  end;

var
  Attribute: Cardinal;
  Abbrev, Form: Cardinal;
  Def: TDwarfAbbrev;
  idx: Integer;
  Value: QWord;
  ValueSize: QWord;
  ValuePtr, p: Pointer;
  Indent: String;
  Level: Integer;
  ADefs: PDwarfAbbrevEntry;
begin
  Indent := AIndent;
  Level := 0;
  ADefs := FCU.AbbrevList.EntryPointer[0];
  while (AData <= AMaxData) and (Level >= 0) do
  begin
p := AData;
    Abbrev := ULEB128toOrdinal(AData);
    if Abbrev = 0
    then begin
      Dec(Level);
      SetLength(Indent, Length(Indent) - 2);
      if Level >= 0
      then  DebugLn(FPDBG_DWARF_VERBOSE, [Indent, ' \--']);
      Continue;
    end;
    DbgOut(FPDBG_DWARF_VERBOSE, [Indent, 'abbrev: ', Abbrev]);
    if not FCU.GetDefinition(p, Def)
    then begin
      DebugLn(FPDBG_DWARF_WARNINGS, ['Error: Abbrev not found: ', Abbrev]);
      Exit;
    end;
    DbgOut(FPDBG_DWARF_VERBOSE, [', tag: ', Def.tag, '=', DwarfTagToString(Def.tag)]);
    if (dafHasChildren in Def.flags)
    then begin
      DebugLn(FPDBG_DWARF_VERBOSE, ['']);
      DebugLn(FPDBG_DWARF_VERBOSE, [', has children']);
      Inc(Level);
    end
    else DebugLn(FPDBG_DWARF_VERBOSE, ['']);

    for idx := Def.Index to Def.Index + Def.Count - 1 do
    begin
      Form := ADefs[idx].Form;
      Attribute := ADefs[idx].Attribute;
      DbgOut(FPDBG_DWARF_VERBOSE, [Indent, ' attrib: ', Attribute, '=', DwarfAttributeToString(Attribute)]);
      DbgOut(FPDBG_DWARF_VERBOSE, [', form: ', Form, '=', DwarfAttributeFormToString(Form)]);

      ValueSize := 0;
      ValuePtr := nil;
      Value := 0;
      repeat
        DbgOut(FPDBG_DWARF_VERBOSE, [', value: ']);
        case Form of
          DW_FORM_addr     : begin
            Value := LocToAddrOrNil(ReadTargetAddressFromDwarfSection(AData));
            ValuePtr := {%H-}Pointer(PtrUInt(Value));
            ValueSize := FCU.AddressSize;
            DbgOut(FPDBG_DWARF_VERBOSE, ['$'+IntToHex(Value, FCU.AddressSize * 2)]);
            Inc(AData, FCU.AddressSize);
          end;
          DW_FORM_block    : begin
            ValueSize := ULEB128toOrdinal(AData);
            ValuePtr := AData;
            DbgOut(FPDBG_DWARF_VERBOSE, ['Size=', ValueSize, ', Data=']);
            Dump(AData, ValueSize);
          end;
          DW_FORM_block1   : begin
            ValueSize := PByte(AData)^;
            Inc(AData, 1);
            ValuePtr := AData;
            DbgOut(FPDBG_DWARF_VERBOSE, ['Size=', ValueSize, ', Data=']);
            Dump(AData, ValueSize);
          end;
          DW_FORM_block2   : begin
            ValueSize := PWord(AData)^;
            Inc(AData, 2);
            ValuePtr := AData;
            DbgOut(FPDBG_DWARF_VERBOSE, ['Size=', ValueSize, ', Data=']);
            Dump(AData, ValueSize);
          end;
          DW_FORM_block4   : begin
            ValueSize := PLongWord(AData)^;
            Inc(AData, 4);
            ValuePtr := AData;
            DbgOut(FPDBG_DWARF_VERBOSE, ['Size=', ValueSize, ', Data=']);
            Dump(AData, ValueSize);
          end;
          DW_FORM_data1    : begin
            Value := PByte(AData)^;
            ValueSize := 1;
            DbgOut(FPDBG_DWARF_VERBOSE, ['$'+IntToHex(Value, 2)]);
            Inc(AData, 1);
          end;
          DW_FORM_data2    : begin
            Value := PWord(AData)^;
            ValueSize := 2;
            DbgOut(FPDBG_DWARF_VERBOSE, ['$'+IntToHex(Value, 4)]);
            Inc(AData, 2);
          end;
          DW_FORM_data4    : begin
            Value := PLongWord(AData)^;
            ValueSize := 4;
            DbgOut(FPDBG_DWARF_VERBOSE, ['$'+IntToHex(Value, 8)]);
            Inc(AData, 4);
          end;
          DW_FORM_data8    : begin
            Value := PQWord(AData)^;
            ValueSize := 8;
            DbgOut(FPDBG_DWARF_VERBOSE, ['$'+IntToHex(Value, 16)]);
            Inc(AData, 8);
          end;
          DW_FORM_sdata    : begin
            p := AData;
            Value := ULEB128toOrdinal(AData);
            ValueSize := {%H-}PtrUInt(AData) - {%H-}PtrUInt(p);
            DbgOut(FPDBG_DWARF_VERBOSE, ['$'+IntToHex(Value, ValueSize * 2)]);
          end;
          DW_FORM_udata    : begin
            p := AData;
            Value := ULEB128toOrdinal(AData);
            ValueSize := {%H-}PtrUInt(AData) - {%H-}PtrUInt(p);
            DbgOut(FPDBG_DWARF_VERBOSE, ['$'+IntToHex(Value, ValueSize * 2)]);
          end;
          DW_FORM_flag     : begin
            Value := PByte(AData)^;
            ValueSize := 1;
            DbgOut(FPDBG_DWARF_VERBOSE, ['$'+IntToHex(Value, 2)]);
            Inc(AData, 1);
          end;
          DW_FORM_ref1     : begin
            Value := PByte(AData)^;
            ValueSize := 1;
            DbgOut(FPDBG_DWARF_VERBOSE, ['$'+IntToHex(Value, 2)]);
            Inc(AData, 1);
          end;
          DW_FORM_ref2     : begin
            Value := PWord(AData)^;
            ValueSize := 2;
            DbgOut(FPDBG_DWARF_VERBOSE, ['$'+IntToHex(Value, 4)]);
            Inc(AData, 2);
          end;
          DW_FORM_ref4     : begin
            Value := PLongWord(AData)^;
            ValueSize := 4;
            DbgOut(FPDBG_DWARF_VERBOSE, ['$'+IntToHex(Value, 8)]);
            Inc(AData, 4);
          end;
          DW_FORM_ref8     : begin
            Value := PQWord(AData)^;
            ValueSize := 8;
            DbgOut(FPDBG_DWARF_VERBOSE, ['$'+IntToHex(Value, 16)]);
            Inc(AData, 8);
          end;
          DW_FORM_ref_udata: begin
            p := AData;
            Value := ULEB128toOrdinal(AData);
            ValueSize := {%H-}PtrUInt(AData) - {%H-}PtrUInt(p);
            DbgOut(FPDBG_DWARF_VERBOSE, ['$'+IntToHex(Value, ValueSize * 2)]);
          end;
          DW_FORM_ref_addr : begin
            Value := LocToAddrOrNil(ReadDwarfSectionOffsetOrLenFromDwarfSection(AData));
            ValuePtr := {%H-}Pointer(PtrUInt(Value));
            ValueSize := FCU.AddressSize;
            DbgOut(FPDBG_DWARF_VERBOSE, ['$'+IntToHex(Value, FCU.AddressSize * 2)]);
            Inc(AData, FCU.AddressSize);
          end;
          DW_FORM_string   : begin
            ValuePtr := AData;
            DumpStr(AData);
            ValueSize := {%H-}PtrUInt(AData) - {%H-}PtrUInt(ValuePtr);
          end;
          DW_FORM_strp     : begin
            Value := LocToAddrOrNil(ReadDwarfSectionOffsetOrLenFromDwarfSection(AData));
            ValueSize := FCU.AddressSize;
            DbgOut(FPDBG_DWARF_VERBOSE, ['$'+IntToHex(Value, FCU.AddressSize * 2)]);
            Inc(AData, FCU.AddressSize);
          end;
          DW_FORM_indirect : begin
            Form := ULEB128toOrdinal(AData);
            DbgOut(FPDBG_DWARF_VERBOSE, ['indirect form: ', Form, '=', DwarfAttributeFormToString(Form)]);
            Continue;
          end;
        else
          DebugLn(FPDBG_DWARF_WARNINGS, ['Error: Unknown Form: ', Form]);
          Exit;
        end;
        Break;
      until False;

      case Attribute of
        DW_AT_accessibility: begin
          DebugLn(FPDBG_DWARF_VERBOSE, ['=', DwarfAccessibilityToString(Value)]);
        end;
        DW_AT_data_member_location: begin
          DebugLn(FPDBG_DWARF_VERBOSE, ['-->']);
          DecodeLocation(ValuePtr, ValueSize, Indent + '  ');
        end;
        DW_AT_encoding: begin
          DebugLn(FPDBG_DWARF_VERBOSE, ['=', DwarfBaseTypeEncodingToString(Value)]);
        end;
        DW_AT_language: begin
          DebugLn(FPDBG_DWARF_VERBOSE, ['=', DwarfLanguageToString(Value)]);
        end;
        DW_AT_identifier_case: begin
          DebugLn(FPDBG_DWARF_VERBOSE, ['=', DwarfIdentifierCaseToString(Value)]);
        end;
        DW_AT_location: begin
          if ValuePtr = nil
          then begin
            DebugLn(FPDBG_DWARF_VERBOSE, ['-->']);
            DecodeLocationList(Value, AIndent + '  ');
          end
          else begin
            DebugLn(FPDBG_DWARF_VERBOSE, ['-->']);
            DecodeLocation(ValuePtr, ValueSize, Indent + '  ');
          end;
        end;
        DW_AT_type: begin
          DebugLn(FPDBG_DWARF_VERBOSE, ['-->']);
          try
            p := FCU.DebugFile^.Sections[dsInfo].RawData + Value - FCU.Owner.ImageBase - FCU.DebugFile^.Sections[dsInfo].VirtualAddress;
            InternalDecode(p, p, Indent + '  ');
          except
            on E: Exception do DebugLn(FPDBG_DWARF_WARNINGS, [AIndent, '  ', E.Message]);
          end;
        end;
      else
        DebugLn(FPDBG_DWARF_VERBOSE, ['']);
      end;
    end;

    if (dafHasChildren in Def.flags)
    then begin
      DebugLn(FPDBG_DWARF_VERBOSE, [Indent, ' /--']);
      Indent := Indent + ' |';
    end;
  end;
end;


function TDwarfAbbrevDecoder.MakeAddressString(AData: Pointer): string;
begin
  if FCU.AddressSize = 4
  then Result := '$'+IntToHex(PLongWord(AData)^, 8)
  else Result := '$'+IntToHex(PQWord(AData)^, 16);
end;

{ TDwarfStatementDecoder }

constructor TDwarfStatementDecoder.Create(ACompilationUnit: TDwarfCompilationUnit);
begin
  inherited Create;
  FCU := ACompilationUnit;
end;

procedure TDwarfStatementDecoder.Decode(AData: Pointer);
begin
  if AData = nil
  then begin
    DebugLn(FPDBG_DWARF_WARNINGS, ['No lineinfo']);
    Exit;
  end;
  InternalDecode(AData, FCU.DebugFile^.Sections[dsInfo].RawData + FCU.DebugFile^.Sections[dsInfo].Size);
end;

procedure TDwarfStatementDecoder.InternalDecode(AData: Pointer; AMaxData: Pointer; const AIndent: String);
var
  Info: PDwarfLNPInfoHeader;

  Address: QWord;
  Line: Int64;
  FileNr: Cardinal;
  Column: Cardinal;
  IsStmt: Boolean;
  BasicBlock: Boolean;
  PrologueEnd: Boolean;
  EpilogueBegin: Boolean;
  Isa: QWord;

  procedure AddRow(ALast: Boolean = False);
  begin
    DbgOut(FPDBG_DWARF_VERBOSE, ['> ']);
    DbgOut(FPDBG_DWARF_VERBOSE, ['Address=$', IntToHex(Address, FCU.AddressSize * 2)]);
    DbgOut(FPDBG_DWARF_VERBOSE, [', Line=',Line]);
    DbgOut(FPDBG_DWARF_VERBOSE, [', FileNr=',FileNr]);
    DbgOut(FPDBG_DWARF_VERBOSE, [', Column=',Column]);
    DbgOut(FPDBG_DWARF_VERBOSE, [', IsStmt=',IsStmt]);
    DbgOut(FPDBG_DWARF_VERBOSE, [', BasicBlock=',BasicBlock]);
    DbgOut(FPDBG_DWARF_VERBOSE, [', PrologueEnd=',PrologueEnd]);
    DbgOut(FPDBG_DWARF_VERBOSE, [', EpilogueBegin=',EpilogueBegin]);
    DbgOut(FPDBG_DWARF_VERBOSE, [', Isa=',Isa]);
    DebugLn(FPDBG_DWARF_VERBOSE, ['']);
    if ALast
    then DebugLn(FPDBG_DWARF_VERBOSE, ['> ---------']);
  end;

  procedure DoAdjust(AOpcode: Byte);
  begin
    Dec(AOpcode, Info^.OpcodeBase);
    if Info^.LineRange = 0
    then begin
      Inc(Address, AOpcode * Info^.MinimumInstructionLength);
    end
    else begin
      Inc(Address, (AOpcode div Info^.LineRange) * Info^.MinimumInstructionLength);
      Inc(Line, Info^.LineBase + (AOpcode mod Info^.LineRange));
    end;
  end;

  procedure DoReset;
  begin
    Address := 0;
    Line := 1;
    FileNr := 1;
    Column := 0;
    IsStmt := Info^.DefaultIsStmt <> 0;
    BasicBlock := False;
    PrologueEnd := False;
    EpilogueBegin := False;
    Isa := 0;
  end;


var
  LNP32: PDwarfLNPHeader32 absolute AData;
  LNP64: PDwarfLNPHeader64 absolute AData;
  UnitLength: QWord;
  Version: Word;
  HeaderLength: QWord;
  n: integer;
  ptr: Pointer;
  p: Pointer;
  pb: PByte absolute p;
  pc: PChar absolute p;
  DataEnd: Pointer;
  DataStart: Pointer;
  UValue: QWord;
  SValue: Int64;
begin
  DebugLn(FPDBG_DWARF_VERBOSE, ['FileName: ', FCU.FileName]);

  if LNP64^.Signature = DWARF_HEADER64_SIGNATURE
  then begin
    UnitLength := LNP64^.UnitLength;
    DataEnd := Pointer(@LNP64^.Version) + UnitLength;
    Version := LNP64^.Version;
    HeaderLength := LNP64^.HeaderLength;
    Info := @LNP64^.Info;
  end
  else begin
    UnitLength := LNP32^.UnitLength;
    DataEnd := Pointer(@LNP32^.Version) + UnitLength;
    Version := LNP32^.Version;
    HeaderLength := LNP32^.HeaderLength;
    Info := @LNP32^.Info;
  end;
  DataStart := PByte(Info) + HeaderLength;

  DebugLn(FPDBG_DWARF_VERBOSE, ['UnitLength: ', UnitLength]);
  DebugLn(FPDBG_DWARF_VERBOSE, ['Version: ', Version]);
  DebugLn(FPDBG_DWARF_VERBOSE, ['HeaderLength: ', HeaderLength]);

  DebugLn(FPDBG_DWARF_VERBOSE, ['MinimumInstructionLength: ', Info^.MinimumInstructionLength]);
  DebugLn(FPDBG_DWARF_VERBOSE, ['DefaultIsStmt: ', Info^.DefaultIsStmt]);
  DebugLn(FPDBG_DWARF_VERBOSE, ['LineBase: ', Info^.LineBase]);
  DebugLn(FPDBG_DWARF_VERBOSE, ['LineRange: ', Info^.LineRange]);
  DebugLn(FPDBG_DWARF_VERBOSE, ['OpcodeBase: ', Info^.OpcodeBase]);
  p := @Info^.StandardOpcodeLengths;
  DebugLn(FPDBG_DWARF_VERBOSE, ['StandardOpcodeLengths:']);
  for n := 1 to Info^.OpcodeBase - 1 do
  begin
    DebugLn(FPDBG_DWARF_VERBOSE, ['  [', n, '] ', pb^]);
    Inc(pb);
  end;

  DebugLn(FPDBG_DWARF_VERBOSE, ['IncludeDirectories:']);
  while pc^ <> #0 do
  begin
    DbgOut(FPDBG_DWARF_VERBOSE, ['  ']);
    repeat
      DbgOut(FPDBG_DWARF_VERBOSE, [pc^]);
      Inc(pc);
    until pc^ = #0;
    DebugLn(FPDBG_DWARF_VERBOSE, ['']);
    Inc(pc);
  end;
  Inc(pc);
  DebugLn(FPDBG_DWARF_VERBOSE, ['FileNames:']);
  while pc^ <> #0 do
  begin
    DbgOut(FPDBG_DWARF_VERBOSE, ['  ']);
    repeat
      DbgOut(FPDBG_DWARF_VERBOSE, [pc^]);
      Inc(pc);
    until pc^ = #0;
    Inc(pc);
    DbgOut(FPDBG_DWARF_VERBOSE, [', diridx=', ULEB128toOrdinal(p)]);
    DbgOut(FPDBG_DWARF_VERBOSE, [', last modified=', ULEB128toOrdinal(p)]);
    DbgOut(FPDBG_DWARF_VERBOSE, [', length=', ULEB128toOrdinal(p)]);
    DebugLn(FPDBG_DWARF_VERBOSE, ['']);
  end;

  DebugLn(FPDBG_DWARF_VERBOSE, ['Program:']);

  p := DataStart;
  DoReset;

  while p < DataEnd do
  begin
    DbgOut(FPDBG_DWARF_VERBOSE, ['  ']);
    if (pb^ > 0) and (pb^ < Info^.OpcodeBase)
    then begin
      // Standard opcode
      case pb^ of
        DW_LNS_copy: begin
          Inc(p);
          DebugLn(FPDBG_DWARF_VERBOSE, ['DW_LNS_copy']);
          AddRow;
          BasicBlock := False;
          PrologueEnd := False;
          EpilogueBegin := False;
        end;
        DW_LNS_advance_pc: begin
          Inc(p);
          UValue := ULEB128toOrdinal(p);
          Inc(Address, UValue);
          DebugLn(FPDBG_DWARF_VERBOSE, ['DW_LNS_advance_pc ', UValue]);
        end;
        DW_LNS_advance_line: begin
          Inc(p);
          SValue := SLEB128toOrdinal(p);
          Inc(Line, SValue);
          DebugLn(FPDBG_DWARF_VERBOSE, ['DW_LNS_advance_line ', SValue]);
        end;
        DW_LNS_set_file: begin
          Inc(p);
          UValue := ULEB128toOrdinal(p);
          DebugLn(FPDBG_DWARF_VERBOSE, ['DW_LNS_set_file ', UVAlue]);
          FileNr := UValue;
        end;
        DW_LNS_set_column: begin
          Inc(p);
          UValue := ULEB128toOrdinal(p);
          DebugLn(FPDBG_DWARF_VERBOSE, ['DW_LNS_set_column ', UValue]);
          Column := UValue;
        end;
        DW_LNS_negate_stmt: begin
          Inc(p);
          DebugLn(FPDBG_DWARF_VERBOSE, ['DW_LNS_negate_stmt']);
          IsStmt := not IsStmt;
        end;
        DW_LNS_set_basic_block: begin
          Inc(p);
          DebugLn(FPDBG_DWARF_VERBOSE, ['DW_LNS_set_basic_block']);
          BasicBlock := True;
        end;
        DW_LNS_const_add_pc: begin
          Inc(p);
          DebugLn(FPDBG_DWARF_VERBOSE, ['DW_LNS_const_add_pc']);
          DoAdjust(255);
        end;
        DW_LNS_fixed_advance_pc: begin
          Inc(p);
          Inc(Address, PWord(p)^);
          DebugLn(FPDBG_DWARF_VERBOSE, ['DW_LNS_fixed_advance_pc ', PWord(p)^]);
          Inc(p, 2);
        end;
        DW_LNS_set_prologue_end: begin
          Inc(p);
          DebugLn(FPDBG_DWARF_VERBOSE, ['DW_LNS_set_prologue_end']);
          PrologueEnd := True;
        end;
        DW_LNS_set_epilogue_begin: begin
          Inc(p);
          DebugLn(FPDBG_DWARF_VERBOSE, ['DW_LNS_set_epilogue_begin']);
          EpilogueBegin := True;
        end;
        DW_LNS_set_isa: begin
          Inc(p);
          UValue := ULEB128toOrdinal(p);
          Isa := UValue;
          DebugLn(FPDBG_DWARF_VERBOSE, ['DW_LNS_set_isa ', UValue]);
        end;
      else
        DbgOut(FPDBG_DWARF_VERBOSE, ['unknown opcode: ', pb^]);
        Inc(p, PByte(@Info^.StandardOpcodeLengths)[pb^-1]);
      end;
      Continue;
    end;

    if pb^ = 0
    then begin
      // Extended opcode
      Inc(p);
      UValue := ULEB128toOrdinal(p); // instruction length

      case pb^ of
        DW_LNE_end_sequence: begin
          DebugLn(FPDBG_DWARF_VERBOSE, ['DW_LNE_end_sequence']);
          AddRow(True);
          DoReset;
          //Inc(p, UValue);
          //Break;
        end;
        DW_LNE_set_address: begin
          if LNP64^.Signature = DWARF_HEADER64_SIGNATURE
          then Address := PQWord(pb+1)^
          else Address := PLongWord(pb+1)^;
          DebugLn(FPDBG_DWARF_VERBOSE, ['DW_LNE_set_address $', IntToHex(Address, FCU.AddressSize * 2)]);
        end;
        DW_LNE_define_file: begin
          ptr := p;
          Inc(ptr);
          DbgOut(FPDBG_DWARF_VERBOSE, ['DW_LNE_define_file name=']);
          repeat
            DbgOut(FPDBG_DWARF_VERBOSE, [PChar(ptr)^]);
            Inc(ptr);
          until PChar(ptr)^ = #0;
          Inc(ptr);
          DbgOut(FPDBG_DWARF_VERBOSE, [', diridx=', ULEB128toOrdinal(ptr)]);
          DbgOut(FPDBG_DWARF_VERBOSE, [', last modified=', ULEB128toOrdinal(ptr)]);
          DbgOut(FPDBG_DWARF_VERBOSE, [', length=', ULEB128toOrdinal(ptr)]);
          DebugLn(FPDBG_DWARF_VERBOSE, ['']);
        end;
      else
        DbgOut(FPDBG_DWARF_VERBOSE, ['unknown extended opcode: ', pb^]);
      end;
      Inc(p, UValue);
    end
    else begin
      DebugLn(FPDBG_DWARF_VERBOSE, ['Special opcode: ', pb^]);
      // Special opcode
      DoAdjust(pb^);
      AddRow;
      BasicBlock := False;
      PrologueEnd := False;
      EpilogueBegin := False;
      Inc(p);
    end;
  end;
end;

{ TVerboseDwarfCallframeDecoder }

constructor TVerboseDwarfCallframeDecoder.Create(ALoader: TDbgImageLoader);
begin
  inherited Create;
  FLoader := Aloader;
end;

procedure TVerboseDwarfCallframeDecoder.Decode;
var
  Section: PDbgImageSection;
begin
  Section := FLoader.Section[DWARF_SECTION_NAME[dsFrame]];
  if Section <> nil
  then InternalDecode(Section^.RawData, Section^.Size, Section^.VirtualAddress);
end;

procedure TVerboseDwarfCallframeDecoder.InternalDecode(AData: Pointer; ASize: QWord; AStart: QWord);
var
  Is64bit: boolean;

  procedure DecodeInstructions(p: Pointer; MaxAddr: Pointer);
  var
    pb: PByte absolute p;
    pw: PWord absolute p;
    pc: PCardinal absolute p;
    pq: PQWord absolute p;
    q: QWord;
  begin
    repeat
      DbgOut(FPDBG_DWARF_VERBOSE, [' ']);
      Inc(pb);
      case pb[-1] of
        DW_CFA_nop: begin
          DebugLn(FPDBG_DWARF_VERBOSE, ['DW_CFA_nop']);
        end;
        DW_CFA_set_loc: begin
          // address
          DbgOut(FPDBG_DWARF_VERBOSE, ['DW_CFA_set_loc $']);
          if Is64Bit
          then begin
            DebugLn(FPDBG_DWARF_VERBOSE, [IntToHex(pq^, 16)]);
            Inc(pq);
          end
          else begin
            DebugLn(FPDBG_DWARF_VERBOSE, [IntToHex(pc^, 8)]);
            Inc(pc);
          end;
        end;
        DW_CFA_advance_loc1: begin
          // 1-byte delta
          DebugLn(FPDBG_DWARF_VERBOSE, ['DW_CFA_advance_loc1 ', pb^, ' * caf']);
          Inc(pb);
        end;
        DW_CFA_advance_loc2: begin
          // 2-byte delta
          DebugLn(FPDBG_DWARF_VERBOSE, ['DW_CFA_advance_loc2 ', pw^, ' * caf']);
          Inc(pw);
        end;
        DW_CFA_advance_loc4: begin
          // 4-byte delta
          DebugLn(FPDBG_DWARF_VERBOSE, ['DW_CFA_advance_loc4 ', pc^, ' * caf']);
          Inc(pw);
        end;
        DW_CFA_offset_extended: begin
          // ULEB128 register, ULEB128 offset
          DebugLn(FPDBG_DWARF_VERBOSE, ['DW_CFA_offset_extended R', ULEB128toOrdinal(p), ' + ', ULEB128toOrdinal(p), ' * daf']);
        end;
        DW_CFA_restore_extended: begin
          // ULEB128 register
          DebugLn(FPDBG_DWARF_VERBOSE, ['DW_CFA_restore_extended R', ULEB128toOrdinal(p)]);
        end;
        DW_CFA_undefined: begin
          // ULEB128 register
          DebugLn(FPDBG_DWARF_VERBOSE, ['DW_CFA_undefined R', ULEB128toOrdinal(p)]);
        end;
        DW_CFA_same_value: begin
          // ULEB128 register
          DebugLn(FPDBG_DWARF_VERBOSE, ['DW_CFA_same_value R', ULEB128toOrdinal(p)]);
        end;
        DW_CFA_register: begin
          // ULEB128 register, ULEB128 register
          DebugLn(FPDBG_DWARF_VERBOSE, ['DW_CFA_register R', ULEB128toOrdinal(p), ' R', ULEB128toOrdinal(p)]);
        end;
        DW_CFA_remember_state: begin
          DebugLn(FPDBG_DWARF_VERBOSE, ['DW_CFA_remember_state']);
        end;
        DW_CFA_restore_state: begin
          DebugLn(FPDBG_DWARF_VERBOSE, ['DW_CFA_restore_state']);
        end;
        DW_CFA_def_cfa: begin
          // ULEB128 register, ULEB128 offset
          DebugLn(FPDBG_DWARF_VERBOSE, ['DW_CFA_def_cfa R', ULEB128toOrdinal(p), ' + ', ULEB128toOrdinal(p)]);
        end;
        DW_CFA_def_cfa_register: begin
          // ULEB128 register
          DebugLn(FPDBG_DWARF_VERBOSE, ['DW_CFA_def_cfa_register R', ULEB128toOrdinal(p)]);
        end;
        DW_CFA_def_cfa_offset: begin
          // ULEB128 offset
          DebugLn(FPDBG_DWARF_VERBOSE, ['DW_CFA_def_cfa_offset ', ULEB128toOrdinal(p)]);
        end;
        // --- DWARF3 ---
        DW_CFA_def_cfa_expression: begin
          // BLOCK
          q := ULEB128toOrdinal(p);
          DebugLn(FPDBG_DWARF_VERBOSE, ['DW_CFA_def_cfa_expression, lenght=',q]);
          Inc(p, q);
        end;
        DW_CFA_expression: begin
          // ULEB128 register, BLOCK
          DbgOut(FPDBG_DWARF_VERBOSE, ['DW_CFA_expression R', ULEB128toOrdinal(p), ' lenght=',q]);
          q := ULEB128toOrdinal(p);
          DebugLn(FPDBG_DWARF_VERBOSE, [q]);
          Inc(p, q);
        end;
        DW_CFA_offset_extended_sf: begin
          // ULEB128 register, SLEB128 offset
          DebugLn(FPDBG_DWARF_VERBOSE, ['DW_CFA_offset_extended_sf R', ULEB128toOrdinal(p), ' + ', SLEB128toOrdinal(p), ' * daf']);
        end;
        DW_CFA_def_cfa_sf: begin
          // ULEB128 register, SLEB128 offset
          DebugLn(FPDBG_DWARF_VERBOSE, ['DW_CFA_def_cfa_sf R', ULEB128toOrdinal(p), ' + ', SLEB128toOrdinal(p), ' * daf']);
        end;
        DW_CFA_def_cfa_offset_sf: begin
          // SLEB128 offset
          DebugLn(FPDBG_DWARF_VERBOSE, ['DW_CFA_def_cfa_offset_sf ', SLEB128toOrdinal(p), ' * daf' ]);
        end;
        DW_CFA_val_offset: begin
          // ULEB128         , ULEB128
          DebugLn(FPDBG_DWARF_VERBOSE, ['DW_CFA_val_offset R', ULEB128toOrdinal(p), ' + ', ULEB128toOrdinal(p), ' * daf']);
        end;
        DW_CFA_val_offset_sf: begin
          // ULEB128         , SLEB128
          DebugLn(FPDBG_DWARF_VERBOSE, ['DW_CFA_val_offset_sf R', ULEB128toOrdinal(p), ' + ', SLEB128toOrdinal(p), ' * daf']);
        end;
        DW_CFA_val_expression: begin
          // ULEB128         , BLOCK
          DbgOut(FPDBG_DWARF_VERBOSE, ['DW_CFA_val_expression R', ULEB128toOrdinal(p), ' lenght=',q]);
          q := ULEB128toOrdinal(p);
          DebugLn(FPDBG_DWARF_VERBOSE, [q]);
          Inc(p, q);
        end;
        // ---  ---
        DW_CFA_lo_user..DW_CFA_hi_user: begin
          DebugLn(FPDBG_DWARF_VERBOSE, ['DW_CFA_user=', pb^]);
        end;
        // ---  ---
        DW_CFA_advance_loc..DW_CFA_offset-1: begin
          // delta
          DebugLn(FPDBG_DWARF_VERBOSE, ['DW_CFA_advance_loc ', pb[-1] and $3F, ' * caf']);
        end;
        DW_CFA_offset..DW_CFA_restore-1: begin
          // register  ULEB128 offset
          DebugLn(FPDBG_DWARF_VERBOSE, ['DW_CFA_offset R', pb[-1] and $3F, ' + ', ULEB128toOrdinal(p),' * caf']);
        end;
        DW_CFA_restore..$FF: begin
         // register
          DebugLn(FPDBG_DWARF_VERBOSE, ['DW_CFA_restore R', pb[-1] and $3F]);
        end;
      else
        DebugLn(FPDBG_DWARF_VERBOSE, ['Undefined $', IntToHex(pb[-1], 2)]);
      end;
    until p >= MaxAddr;
  end;

var
  p, next: Pointer;
  pb: PByte absolute p;
  pi: PInteger absolute p;
  pc: PCardinal absolute p;
  pq: PQWord absolute p;

  len: QWord;
  version: Byte;
  IsCie: Boolean;

  s: String;
begin
  p := AData;
  while p < Adata + ASize do
  begin
    DebugLn(FPDBG_DWARF_VERBOSE, ['[', {%H-}PtrUInt(p) - {%H-}PtrUInt(AData), ']']);

    Is64bit := pi^ = -1;
    if Is64bit
    then begin
      Inc(pi);
      len := pq^;
      Inc(pq);
      IsCie := Int64(pq^) = -1;
    end
    else begin
      len := pc^;
      Inc(pc);
      IsCie := pi^ = -1;
    end;
    next := p + len;

    if IsCie
    then DebugLn(FPDBG_DWARF_VERBOSE, ['=== CIE ==='])
    else DebugLn(FPDBG_DWARF_VERBOSE, ['--- FDE ---']);

    DebugLn(FPDBG_DWARF_VERBOSE, ['Length: ', len]);

    if IsCie
    then begin
      Inc(pi);
      version := pb^;
      DebugLn(FPDBG_DWARF_VERBOSE, ['Version: ', version]);
      Inc(pb);
      S := Pchar(p);
      DebugLn(FPDBG_DWARF_VERBOSE, ['Augmentation: ', S]);
      Inc(p, Length(s) + 1);
      DebugLn(FPDBG_DWARF_VERBOSE, ['Code alignment factor (caf): ', ULEB128toOrdinal(p)]);
      DebugLn(FPDBG_DWARF_VERBOSE, ['Data alignment factor (daf): ', SLEB128toOrdinal(p)]);
      DbgOut(FPDBG_DWARF_VERBOSE, ['Return addr: R']);
      if version <= 2
      then begin
        DebugLn(FPDBG_DWARF_VERBOSE, [pb^]);
        Inc(pb);
      end
      else DebugLn(FPDBG_DWARF_VERBOSE, [ULEB128toOrdinal(p)]);
    end
    else begin
      if pc^ > ASize
      then DebugLn(FPDBG_DWARF_VERBOSE, ['CIE: $', IntToHex(pc^, 8), ' (=address ?) -> offset: ', pc^ - AStart - FLoader.ImageBase])
      else DebugLn(FPDBG_DWARF_VERBOSE, ['CIE: ', pc^]);
      Inc(pc);
      DebugLn(FPDBG_DWARF_VERBOSE, ['InitialLocation: $', IntToHex(pc^, 8)]);
      Inc(pc);
      DebugLn(FPDBG_DWARF_VERBOSE, ['Address range: ', pc^]);
      Inc(pc);
    end;
    DebugLn(FPDBG_DWARF_VERBOSE, ['Instructions:']);
    DecodeInstructions(p, next);

    p := next;
  end;
end;

initialization
  FPDBG_DWARF_VERBOSE       := DebugLogger.FindOrRegisterLogGroup('FPDBG_DWARF_VERBOSE' {$IFDEF FPDBG_DWARF_VERBOSE} , True {$ENDIF} );
  FPDBG_DWARF_WARNINGS      := DebugLogger.FindOrRegisterLogGroup('FPDBG_DWARF_WARNINGS' {$IFDEF FPDBG_DWARF_WARNINGS} , True {$ENDIF} );
end.


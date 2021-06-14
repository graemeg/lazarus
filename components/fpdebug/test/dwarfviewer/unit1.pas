unit Unit1;

{$mode objfpc}{$H+}

interface

uses
  FpImgReaderWinPE, Classes, SysUtils, math, FileUtil, LazLogger, LazLoggerProfiling,
  LazSysUtils, FpDbgLoader, FpDbgDwarf, FpDbgDwarfConst, FpPascalParser, FpDbgInfo,
  FpDbgDwarfDataClasses, Forms, Controls, Graphics, Dialogs, StdCtrls, ComCtrls, EditBtn,
  Menus, Clipbrd, maps, types, strutils;

type

  { TForm1 }

  TForm1 = class(TForm)
    btnCopyAll: TButton;
    btnLoad: TButton;
    btnShowUnit: TButton;
    btnCopyOne: TButton;
    btnLines: TButton;
    FileNameEdit1: TFileNameEdit;
    CompUnitListBox: TListBox;
    StatusBar1: TStatusBar;
    TreeView1: TTreeView;
    procedure btnCopyAllClick(Sender: TObject);
    procedure btnCopyOneClick(Sender: TObject);
    procedure btnLoadClick(Sender: TObject);
    procedure btnShowUnitClick(Sender: TObject);
    procedure btnLinesClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormDropFiles(Sender: TObject; const FileNames: array of String);
  private
    { private declarations }
    NameList: TStringList;
    FFileName: String;
    FTestCaseTexts: TStringList;
    FImageLoaderList: TDbgImageLoaderList;
    FDwarfInfo: TFpDwarfInfo;
    FCUCount : Integer;
    FShowingUnit: Boolean;
  public
    { public declarations }
    procedure LoadDwarf;
    procedure UnLoadDwarf;
  end;

var
  Form1: TForm1;

implementation

{$R *.lfm}

type
  TDwarfCompilationUnitHack = class(TDwarfCompilationUnit)
  public
    property FirstScope;
    property AbbrevList;
  end;

{ TForm1 }

procedure TForm1.btnLoadClick(Sender: TObject);
var
  i: Integer;
begin
  if FileNameEdit1.FileName = '' then
    FileNameEdit1.RunDialog;
  FFileName := FileNameEdit1.FileName;
  LoadDwarf;

  if FDwarfInfo = nil then
    exit;

  CompUnitListBox.Clear;
  for i := 0 to FCUCount - 1 do begin
    CompUnitListBox.AddItem(FDwarfInfo.CompilationUnits[i].FileName,
                            FDwarfInfo.CompilationUnits[i] );
  end;
end;

procedure TForm1.btnCopyOneClick(Sender: TObject);
var
  n: TTreeNode;
  i: PtrInt;
begin
  n := TreeView1.Selected;
  if n = nil then exit;
  i := ptrint(n.Data)-1;
  if i < 0 then exit;
debugln(['TForm1.MenuItem1Click ']);
  Clipboard.AsText := FTestCaseTexts[i];
end;

procedure TForm1.btnLinesClick(Sender: TObject);
const
  B: Array [Boolean] of string = ('F', 'T');
var
  i: Integer;
  Node, ParentNode: TTreeNode;
  CU: TDwarfCompilationUnitHack;
  SM: TDwarfLineInfoStateMachine;
begin
  TreeView1.BeginUpdate;
  try
    TreeView1.Items.Clear;
    i := CompUnitListBox.ItemIndex;
    if i < 0 then exit;
    CU := TDwarfCompilationUnitHack(CompUnitListBox.Items.Objects[i]);
    if CU = nil then exit;

    SM := CU.FLineInfo.StateMachine;
    SM.Reset;
    ParentNode := nil;

    while SM.NextLine do
    begin

      Node := TreeView1.Items.AddChild(ParentNode,
        Format('Line: %2d, Col: %2d, Addr: %s,  IsStmt: %s,  Basic: %s, EndSeq: %s, Prol: %s, Epil: %s, ISA: %u,  File: %s // Ended: %s',
        [SM.Line, SM.Column, IntToHex(SM.Address,16), b[SM.IsStmt], b[SM.BasicBlock],
        b[SM.EndSequence], b[SM.PrologueEnd], b[SM.EpilogueBegin], SM.Isa, sm.FileName, b[SM.Ended] ]));

      if ParentNode = nil then ParentNode := Node;
      if SM.EndSequence then begin
        ParentNode := nil;
        if not SM.NextLine then break;
      end;
    end;

  finally
    TreeView1.EndUpdate;
  end;

end;

procedure TForm1.btnCopyAllClick(Sender: TObject);
var
  nm: TStringList;
  vars: String;
  procedure AddChildren(n: TTreeNode; var s: string; idnt: String);
  var
    i: PtrInt;
    s2: String;
  begin
    n := n.GetFirstChild;
    while n <> nil do begin
      i := ptrint(n.Data)-1;
      s2 := 'XXXXXXXXXXX.';
      if i >= 0 then
        s2 := FTestCaseTexts[i];
      nm.Add(copy(s2, 1, max(0, pos('.', s2)-1)));
      if i >= 0 then begin
        vars := vars + nm[nm.Count-1] +', ';
        if s2 <> '' then begin
          s2 := nm[nm.Count-1] + ' := ' + nm[nm.Count-2] + '.GetNewChild;' +LineEnding
                + s2;

          s2 := AnsiReplaceStr(s2, LineEnding, LineEnding+idnt);
          s := s + idnt + s2 + LineEnding;;
        end;
      end;
      AddChildren(n, s, idnt+'  ');
      nm.Delete(nm.Count-1);
      n := n.GetNextSibling;
    end;
  end;
var
  s: String;
  n: TTreeNode;
  i: PtrInt;
  i2: Integer;
begin
  nm := TStringList.Create;
  n := TreeView1.Selected;
  if n = nil then exit;
  i := ptrint(n.Data)-1;
  if i < 0 then exit;
debugln(['TForm1.MenuItem1Click ']);
  s := FTestCaseTexts[i] + LineEnding;
  nm.Add(copy(s, 1, pos('.',s)-1));
  vars := vars + nm[nm.Count-1] +', ';

  AddChildren(n, s, '  ');

  s := 'var '+vars + LineEnding + LineEnding + LineEnding + s;
  for i2 := 0 to NameList.count - 1 do
    s := AnsiReplaceStr(s, NameList.Names[i2], NameList.ValueFromIndex[i2]);

  Clipboard.AsText := s;
  nm.Free;
end;

procedure TForm1.LoadDwarf;
var
  ImageLoader: TDbgImageLoader;
begin
  UnLoadDwarf;
  ImageLoader := TDbgImageLoader.Create(FFileName);
  FImageLoaderList := TDbgImageLoaderList.Create(True);
  ImageLoader.AddToLoaderList(FImageLoaderList);

  FDwarfInfo := TFpDwarfInfo.Create(FImageLoaderList, nil);
  FCUCount := FDwarfInfo.LoadCompilationUnits;
end;


procedure TForm1.btnShowUnitClick(Sender: TObject);
var
  CU: TDwarfCompilationUnitHack;
  BaseScopeAddr: Pointer;

  function ToHex(var p: pbyte; l : integer):String; inline;
  begin
    Result := '';
    while l > 0 do begin
      Result :=  IntToHex(p^,2) + Result;
      inc(p);
      dec(l);
    end;
  end;

  function ToHexCommaList(p: pbyte; l : integer):String;
  begin
    Result := '';
    while l > 0 do begin
      if Result <> ''
      then Result :=  Result + ', ' + '$'+IntToHex(p^,2)
      else Result :=  Result + '$'+IntToHex(p^,2);
      inc(p);
      dec(l);
    end;
  end;

  function DecodeLocation(AData: PByte; ASize: QWord): String;
    function MakeAddressString(AData: Pointer): string;
    begin
      Result := '$'+IntToHex(PLongWord(AData)^, 8)
      //Result := '$'+IntToHex(PQWord(AData)^, 16);
    end;
  var
    MaxData: PByte;
    v: Int64;
  begin
    Result:='';
    MaxData := AData + ASize - 1;
    while AData <= MaxData do
    begin
      if Result <> '' then Result := Result + ', ';
      case AData^ of
        DW_OP_addr: begin
          Result := Result + 'DW_OP_addr, AddrB(' + MakeAddressString(@AData[1]) + ')';
          Inc(AData, 4);
        end;
        DW_OP_deref: begin
          Result := Result + 'DW_OP_deref';
        end;
        DW_OP_const1u: begin
          Result := Result + 'DW_OP_const1u, ' + IntToStr(AData[1]);
          Inc(AData, 1);
        end;
        DW_OP_const1s: begin
          Result := Result + 'DW_OP_const1s, ' + IntToStr(PShortInt(@AData[1])^);
          Inc(AData, 1);
        end;
        DW_OP_const2u: begin
          Result := Result + 'DW_OP_const2u, NumU(' + IntToStr(PWord(@AData[1])^) + ',2)';
          Inc(AData, 2);
        end;
        DW_OP_const2s: begin
          Result := Result + 'DW_OP_const2s, NumS(' + IntToStr(PSmallInt(@AData[1])^) + ',2)';
          Inc(AData, 2);
        end;
        DW_OP_const4u: begin
          Result := Result + 'DW_OP_const4u, NumU(' + IntToStr(PLongWord(@AData[1])^) + ',4)';
          Inc(AData, 4);
        end;
        DW_OP_const4s: begin
          Result := Result + 'DW_OP_const4s, NumS(' + IntToStr(PLongInt(@AData[1])^) + ',4)';
          Inc(AData, 4);
        end;
        DW_OP_const8u: begin
          Result := Result + 'DW_OP_const8u, NumU' + IntToStr(PQWord(@AData[1])^) + ',8)';
          Inc(AData, 8);
        end;
        DW_OP_const8s: begin
          Result := Result + 'DW_OP_const8s, NumS' + IntToStr(PInt64(@AData[1])^) + ',8)';
          Inc(AData, 8);
        end;
        DW_OP_constu: begin
          Inc(AData);
          Result := Result + 'DW_OP_constu, ULEB' + IntToStr(ULEB128toOrdinal(AData)) + ')';
          Dec(AData);
        end;
        DW_OP_consts: begin
          Inc(AData);
          Result := Result + 'DW_OP_consts, SLEB(' + IntToStr(SLEB128toOrdinal(AData)) + ')';
          Dec(AData);
        end;
        DW_OP_dup: begin
          Result := Result + 'DW_OP_dup';
        end;
        DW_OP_drop: begin
          Result := Result + 'DW_OP_drop';
        end;
        DW_OP_over: begin
          Result := Result + 'DW_OP_over';
        end;
        DW_OP_pick: begin
          Result := Result + 'DW_OP_pick, ' + IntToStr(AData[1]);
          Inc(AData, 1);
        end;
        DW_OP_swap: begin
          Result := Result + 'DW_OP_swap';
        end;
        DW_OP_rot: begin
          Result := Result + 'DW_OP_rot';
        end;
        DW_OP_xderef: begin
          Result := Result + 'DW_OP_xderef';
        end;
        DW_OP_abs: begin
          Result := Result + 'DW_OP_abs';
        end;
        DW_OP_and: begin
          Result := Result + 'DW_OP_and';
        end;
        DW_OP_div: begin
          Result := Result + 'DW_OP_div';
        end;
        DW_OP_minus: begin
          Result := Result + 'DW_OP_minus';
        end;
        DW_OP_mod: begin
          Result := Result + 'DW_OP_mod';
        end;
        DW_OP_mul: begin
          Result := Result + 'DW_OP_mul';
        end;
        DW_OP_neg: begin
          Result := Result + 'DW_OP_neg';
        end;
        DW_OP_not: begin
          Result := Result + 'DW_OP_not';
        end;
        DW_OP_or: begin
          Result := Result + 'DW_OP_or';
        end;
        DW_OP_plus: begin
          Result := Result + 'DW_OP_plus';
        end;
        DW_OP_plus_uconst: begin
          Inc(AData);
          Result := Result + 'DW_OP_plus_uconst, ULEB(' + IntToStr(ULEB128toOrdinal(AData))+')';
          Dec(AData);
        end;
        DW_OP_shl: begin
          Result := Result + 'DW_OP_shl';
        end;
        DW_OP_shr: begin
          Result := Result + 'DW_OP_shr';
        end;
        DW_OP_shra: begin
          Result := Result + 'DW_OP_shra';
        end;
        DW_OP_xor: begin
          Result := Result + 'DW_OP_xor';
        end;
        DW_OP_skip: begin
          Result := Result + 'DW_OP_skip, NumS(' + IntToStr(PSmallInt(@AData[1])^) + ',2)';
          Inc(AData, 2);
        end;
        DW_OP_bra: begin
          Result := Result + 'DW_OP_bra, NumS(' + IntToStr(PSmallInt(@AData[1])^) + ',2)';
          Inc(AData, 2);
        end;
        DW_OP_eq: begin
          Result := Result + 'DW_OP_eq';
        end;
        DW_OP_ge: begin
          Result := Result + 'DW_OP_ge';
        end;
        DW_OP_gt: begin
          Result := Result + 'DW_OP_gt';
        end;
        DW_OP_le: begin
          Result := Result + 'DW_OP_le';
        end;
        DW_OP_lt: begin
          Result := Result + 'DW_OP_lt';
        end;
        DW_OP_ne: begin
          Result := Result + 'DW_OP_ne';
        end;
        DW_OP_lit0..DW_OP_lit31: begin
          Result := Result + 'DW_OP_lit' + IntToStr(AData^ - DW_OP_lit0);
        end;
        DW_OP_reg0..DW_OP_reg31: begin
          Result := Result + 'DW_OP_reg' + IntToStr(AData^ - DW_OP_reg0);
        end;
        DW_OP_breg0..DW_OP_breg31: begin
          Result := Result + 'DW_OP_breg' + IntToStr(AData^ - DW_OP_breg0);
          Inc(AData);
          v := SLEB128toOrdinal(AData);
          Dec(AData);
          Result := Result + ', SLEB(';
          Result := Result + IntToStr(v) + ')';
        end;
        DW_OP_regx: begin
          Inc(AData);
          Result := Result + 'DW_OP_regx, ULEB(' + IntToStr(ULEB128toOrdinal(AData)) + ')';
          Dec(AData);
        end;
        DW_OP_fbreg: begin
          Inc(AData);
          Result := Result + 'DW_OP_fbreg, SLEB(' + IntToStr(SLEB128toOrdinal(AData)) + ')';
          Dec(AData);
        end;
        DW_OP_bregx: begin
          Inc(AData);
          Result := Result + 'DW_OP_bregx, ULEB(' + IntToStr(ULEB128toOrdinal(AData)) + ')';
          v := SLEB128toOrdinal(AData);
          Dec(AData);
          Result := Result + ', SLEB(';
          Result := Result + IntToStr(v) + ')';
        end;
        DW_OP_piece: begin
          Inc(AData);
          Result := Result + 'DW_OP_piece, ULEB(' + IntToStr(ULEB128toOrdinal(AData)) + ')';
          Dec(AData);
        end;
        DW_OP_deref_size: begin
          Result := Result + 'DW_OP_deref_size, ' + IntToStr(AData[1]);
          Inc(AData);
        end;
        DW_OP_xderef_size: begin
          Result := Result + 'DW_OP_xderef_size, ' + IntToStr(AData[1]);
          Inc(AData);
        end;
        DW_OP_nop: begin
          Result := Result + 'DW_OP_nop';
        end;
        DW_OP_push_object_address: begin
          Result := Result + 'DW_OP_push_object_address';
        end;
        DW_OP_call2: begin
          Result := Result + 'DW_OP_call2, ' + IntToStr(PWord(@AData[1])^);
          Inc(AData, 2);
        end;
        DW_OP_call4: begin
          Result := Result + 'DW_OP_call4, ' + IntToStr(PLongWord(@AData[1])^);
          Inc(AData, 4);
        end;
        DW_OP_call_ref: begin
          Result := Result + 'DW_OP_call_ref, AddrB(' + MakeAddressString(@AData[1]) + ')';
          Inc(AData, 4);
        end;
        DW_OP_form_tls_address: begin
          Result := Result + 'DW_OP_form_tls_address';
        end;
        DW_OP_call_frame_cfa: begin
          Result := Result + 'DW_OP_call_frame_cfa';
        end;
        DW_OP_bit_piece: begin
          Inc(AData);
          Result := Result + 'DW_OP_bit_piece, ULEB(' + IntToStr(ULEB128toOrdinal(AData)) + '), ULEB(' + IntToStr(ULEB128toOrdinal(AData)) + ')';
          Dec(AData);
        end;
        DW_OP_lo_user..DW_OP_hi_user: begin
          Result := Result + 'DW_OP_user, ' + IntToStr(AData^);
        end;
      else
        Result := Result + 'Unknown DW_OP_' + IntToStr(AData^);
      end;
      Inc(AData);
      //Result := Result +' / ';
    end;
  end;

  function AddAbbrev(AParent: TTreeNode;   s: TDwarfScopeInfo; Def: TDwarfAbbrev;
    var PascalTestCAseCode: String; namePreFix: String = ''): String;
  var
    p: Pointer;
    Form: Cardinal;
    Attribute: Cardinal;
    i: Integer;
    s1, s2, s3, s4, stest: String;
    ValueSize: QWord;
    Value: qword;
    SValue: int64;
    p2: Pointer;
    addednode: TTreeNode;
  begin
    Result := '';
    PascalTestCAseCode := '';
    p := s.Entry;
    ULEB128toOrdinal(p);
    for i := def.index to Def.index + Def.count - 1 do begin
      Form := CU.AbbrevList.EntryPointer[i]^.Form;
      Attribute := CU.AbbrevList.EntryPointer[i]^.Attribute;
      s1 := DwarfAttributeToString(Attribute);
      s2 := DwarfAttributeFormToString(Form);
      p2 := p;

        case Form of
          DW_FORM_addr     : begin
            s3 := ToHex(p, cu.AddressSize {4} {FCU.FAddressSize});
            PascalTestCAseCode := PascalTestCAseCode +
              Format(namePreFix+'AddAddr(%s, %s, $%s);%s', [s1, s2, s3, LineEnding]);
          end;
          DW_FORM_block    : begin
            p2 := p;
            ValueSize := ULEB128toOrdinal(p);
            stest := ToHexCommaList(p,ValueSize);
            p2 := p;
            s3 := IntToStr(ValueSize) + ': ' + ToHex(p, ValueSize);
            if (Attribute = DW_AT_location) or (Attribute = DW_AT_data_location) or (Attribute = DW_AT_data_member_location)  then
              PascalTestCAseCode := PascalTestCAseCode +
                Format(namePreFix+'Add(%s, %s, BytesLenU([%s]));  // %s%s', [s1, s2, DecodeLocation(p2, ValueSize), stest, LineEnding])
            else
              PascalTestCAseCode := PascalTestCAseCode +
                Format(namePreFix+'Add(%s, %s, BytesLenU([%s]));%s', [s1, s2, stest, LineEnding]);
          end;
          DW_FORM_block1   : begin
            ValueSize := PByte(p)^;
            Inc(p, 1);
            p2 := p;
            stest := ToHexCommaList(p,ValueSize);
            s3 := IntToStr(ValueSize) + ': ' + ToHex(p, ValueSize);
            if (Attribute = DW_AT_location) or (Attribute = DW_AT_data_location) or (Attribute = DW_AT_data_member_location)  then
              PascalTestCAseCode := PascalTestCAseCode +
                Format(namePreFix+'Add(%s, %s, BytesLen1([%s])); // %s%s', [s1, s2, DecodeLocation(p2, ValueSize), stest, LineEnding])
            else
              PascalTestCAseCode := PascalTestCAseCode +
                Format(namePreFix+'Add(%s, %s, BytesLen1([%s]));%s', [s1, s2, stest, LineEnding]);
          end;
          DW_FORM_block2   : begin
            ValueSize := PWord(p)^;
            Inc(p, 2);
            p2 := p;
            stest := ToHexCommaList(p,ValueSize);
            s3 := IntToStr(ValueSize) + ': ' + ToHex(p, ValueSize);
            if (Attribute = DW_AT_location) or (Attribute = DW_AT_data_location) or (Attribute = DW_AT_data_member_location)  then
              PascalTestCAseCode := PascalTestCAseCode +
                Format(namePreFix+'Add(%s, %s, BytesLen2([%s])); // %s%s', [s1, s2, DecodeLocation(p2, ValueSize), stest, LineEnding])
            else
              PascalTestCAseCode := PascalTestCAseCode +
                Format(namePreFix+'Add(%s, %s, BytesLen2([%s]));%s', [s1, s2, stest, LineEnding]);
          end;
          DW_FORM_block4   : begin
            ValueSize := PLongWord(p)^;
            Inc(p, 4);
            p2 := p;
            stest := ToHexCommaList(p,ValueSize);
            s3 := IntToStr(ValueSize) + ': ' + ToHex(p, ValueSize);
            if (Attribute = DW_AT_location) or (Attribute = DW_AT_data_location) or (Attribute = DW_AT_data_member_location)  then
              PascalTestCAseCode := PascalTestCAseCode +
                Format(namePreFix+'Add(%s, %s, BytesLen4([%s])); // %s%s', [s1, s2, DecodeLocation(p2, ValueSize), stest, LineEnding])
            else
              PascalTestCAseCode := PascalTestCAseCode +
                Format(namePreFix+'Add(%s, %s, BytesLen4([%s]));%s', [s1, s2, stest, LineEnding]);
          end;
          DW_FORM_data1    : begin
            stest := ToHexCommaList(p,1);
            s3 := ToHex(p, 1);
            PascalTestCAseCode := PascalTestCAseCode +
              Format(namePreFix+'Add(%s, %s, [%s]);%s', [s1, s2, stest, LineEnding]);
          end;
          DW_FORM_data2    : begin
            stest := ToHexCommaList(p,2);
            s3 := ToHex(p, 2);
            PascalTestCAseCode := PascalTestCAseCode +
              Format(namePreFix+'Add(%s, %s, [%s]);%s', [s1, s2, stest, LineEnding]);
          end;
          DW_FORM_data4    : begin
            stest := ToHexCommaList(p,4);
            s3 := ToHex(p, 4);
            PascalTestCAseCode := PascalTestCAseCode +
              Format(namePreFix+'Add(%s, %s, [%s]);%s', [s1, s2, stest, LineEnding]);
          end;
          DW_FORM_data8    : begin
            stest := ToHexCommaList(p,8);
            s3 := ToHex(p, 8);
            PascalTestCAseCode := PascalTestCAseCode +
              Format(namePreFix+'Add(%s, %s, [%s]);%s', [s1, s2, stest, LineEnding]);
          end;
          DW_FORM_sdata    : begin
            SValue := SLEB128toOrdinal(p);
            s3 := IntToStr(SValue);
            PascalTestCAseCode := PascalTestCAseCode +
              Format(namePreFix+'AddSLEB(%s, %s, %d);%s', [s1, s2, SValue, LineEnding]);
          end;
          DW_FORM_udata    : begin
            Value := ULEB128toOrdinal(p);
            s3 := IntToStr(Value);
            PascalTestCAseCode := PascalTestCAseCode +
              Format(namePreFix+'AddULEB(%s, %s, %u);%s', [s1, s2, Value, LineEnding]);
          end;
          DW_FORM_flag     : begin
            stest := ToHexCommaList(p,1);
            s3 := ToHex(p, 1);
            PascalTestCAseCode := PascalTestCAseCode +
              Format(namePreFix+'Add(%s, %s, [%s]);%s', [s1, s2, stest, LineEnding]);
          end;
          DW_FORM_ref1     : begin
            stest := ToHexCommaList(p,1);
            s3 := ToHex(p, 1);
            PascalTestCAseCode := PascalTestCAseCode +
              Format(namePreFix+'AddRef(%s, %s, @Info__%s_); // %s  %s', [s1, s2, IntToStr(PByte(p-1)^), stest, LineEnding]);
              //Format(namePreFix+'AddRef(%s, %s, FOO); // %s  %s', [s1, s2, stest, LineEnding]);
          end;
          DW_FORM_ref2     : begin
            stest := ToHexCommaList(p,3);
            s3 := ToHex(p, 2);
            PascalTestCAseCode := PascalTestCAseCode +
              Format(namePreFix+'AddRef(%s, %s, @Info__%s_); // %s  %s', [s1, s2, IntToStr(PWord(p-2)^), stest, LineEnding]);
              //Format(namePreFix+'AddRef(%s, %s, FOO); // %s %s', [s1, s2, stest, LineEnding]);
          end;
          DW_FORM_ref4     : begin
            stest := ToHexCommaList(p,4);
            s4 := IntToHex(PInteger(p)^ -11, 8);;
            s3 := ToHex(p, 4) + '    // '+ s4;
            PascalTestCAseCode := PascalTestCAseCode +
              Format(namePreFix+'AddRef(%s, %s, @Info__%s_); // %s  %s', [s1, s2, IntToStr(PDWord(p-4)^), stest, LineEnding]);
              //Format(namePreFix+'AddRef(%s, %s, FOO); // %s %s', [s1, s2, stest, LineEnding]);
          end;
          DW_FORM_ref8     : begin
            stest := ToHexCommaList(p,8);
            s3 := ToHex(p, 8);
            PascalTestCAseCode := PascalTestCAseCode +
              Format(namePreFix+'AddRef(%s, %s, @Info__%s_); // %s  %s', [s1, s2, IntToStr(PQWord(p-8)^), stest, LineEnding]);
              //Format(namePreFix+'AddRef(%s, %s, FOO); // %s %s', [s1, s2, stest, LineEnding]);
          end;
          DW_FORM_ref_udata: begin
            Value := ULEB128toOrdinal(p);
            s3 := IntToStr(Value);
            PascalTestCAseCode := PascalTestCAseCode +
              Format(namePreFix+'AddRef(%s, %s, FOO); // %u // ULEB %s', [s1, s2, Value, LineEnding]);
          end;
          DW_FORM_ref_addr : begin
            stest := ToHexCommaList(p,4);
            s3 := ToHex(p, 4 {FCU.FAddressSize});
            PascalTestCAseCode := PascalTestCAseCode +
              Format(namePreFix+'AddRef(%s, %s, FOO); // %s // %s', [s1, s2, stest, LineEnding]);
          end;
          DW_FORM_string   : begin
            s3 := copy(pchar(p),1,1000);
            while pbyte( p)^ <> 0 do begin
              inc(pbyte(p));
            end;
            inc(pbyte(p));
            PascalTestCAseCode := PascalTestCAseCode +
              Format(namePreFix+'Add(%s, %s, ''%s''+#0);%s', [s1, s2, s3, LineEnding]);
          end;
          DW_FORM_strp     : begin
            stest := ToHexCommaList(p,4);
            s3 := ToHex(p, 4 {FCU.FAddressSize});
            PascalTestCAseCode := PascalTestCAseCode +
              Format(namePreFix+'Add(%s, %s, [%s]);%s', [s1, s2, stest, LineEnding]);
          end;
          DW_FORM_indirect : begin
            Value := ULEB128toOrdinal(p);
            s3 := IntToStr(Value);
            //Form := ULEB128toOrdinal(p);
            //Continue;
            PascalTestCAseCode := PascalTestCAseCode +
              Format(namePreFix+'AddULEB(%s, %s, %u);%s', [s1, s2, Value, LineEnding]);
          end;
        else
          s3 := '?????';
          PascalTestCAseCode := PascalTestCAseCode +
            Format(namePreFix+'Add(%s, %s, %s);%s', [s1, s2, '???????????', LineEnding]);
        end;

      if Attribute = DW_AT_name then Result := s3;

      if (Attribute = DW_AT_location) or (Attribute = DW_AT_data_location) or (Attribute = DW_AT_data_member_location)
         or (Attribute = DW_AT_upper_bound) or (Attribute = DW_AT_lower_bound)
      then begin
        stest := DecodeLocation(p2, ValueSize);
        s3 := s3 + ' // ' +stest;
      end;

      addednode := TreeView1.Items.AddChild(AParent, Format('  --  Attr: %20s(%4x) Form: %18s(%4x) >> %s', [s1, Attribute, s2, Form, s3]));

    end;
  end;

  function AddNode(AParent, Asibling: TTreeNode;   s: TDwarfScopeInfo): TTreeNode;
  var
    p: Pointer;
    Abbrev: QWord;
    Node: TTreeNode;
    s2: TDwarfScopeInfo;
    n: TTreeNode;
    i: Integer;
    Def: TDwarfAbbrev;
    entryname: String;
    TestCaseText: String;
    NMLIdx: Integer;
    pre, sName: String;
  begin
     Result := nil;
     p := s.Entry;
     Abbrev := ULEB128toOrdinal(p);
     p := s.Entry;
     CU.GetDefinition(p, Def);
     Node := TreeView1.Items.AddChild(AParent, Format('Abr: %d Tag: %d %s ', [Abbrev, Def.tag, DwarfTagToString(Def.tag)]));

     sName := 'Info__'+IntToStr(s.Entry - BaseScopeAddr + 11)+'_.';
     entryname := AddAbbrev(Node, s, Def, TestCaseText, sName);

     pre := '';
     Case def.tag of
       DW_TAG_base_type, DW_TAG_string_type, DW_TAG_union_type, DW_TAG_ptr_to_member_type,
       DW_TAG_file_type, DW_TAG_thrown_type, DW_TAG_subroutine_type, DW_TAG_packed_type,
       DW_TAG_const_type, DW_TAG_volatile_type, DW_TAG_reference_type,
       DW_TAG_subrange_type, DW_TAG_enumeration_type,
       DW_TAG_enumerator, DW_TAG_set_type, DW_TAG_structure_type, DW_TAG_class_type,
       DW_TAG_array_type: pre:= 'Type';
       DW_TAG_typedef:   pre:= 'TypeDecl';
       DW_TAG_pointer_type: pre:= 'TypePtr';
       DW_TAG_variable, DW_TAG_formal_parameter, DW_TAG_member: pre:= 'Var';
       DW_TAG_subprogram: pre:= 'Prog';
        DW_TAG_compile_unit: pre:= 'Unit';
        else pre:= 'XX';
     end;
     pre := pre + entryname;
     pre := AnsiReplaceStr(pre, '$', '');
     pre := AnsiReplaceStr(pre, '.', '_');
     pre := AnsiReplaceStr(pre, '  ', '_');
     pre := AnsiReplaceStr(pre, ' ', '_');

     NameList.Values['Info__'+IntToStr(s.Entry - BaseScopeAddr + 11)+'_']
       := pre+'_'+IntToStr(FTestCaseTexts.Count);
     i := 0;
     if s.HasChild then i := 1;
     TestCaseText :=
              Format('%sTag := %s;%s',
                     [sName, DwarfTagToString(Def.tag), LineEnding])
              + Format('%sChildren := %d;%s', [sName, i, LineEnding])
              + TestCaseText;
     node.Data := pointer(ptruint(FTestCaseTexts.Add(TestCaseText)+1));

     i := 0;
     if s.HasChild then begin
       n:=nil;
       s2 := s.Child;
       while s2.IsValid do begin
         n := AddNode(Node,n,s2);
         s2.GoNext;
         inc(i);
         if (i and 31) = 0 then begin
           StatusBar1.SimpleText := IntToHex(s2.Index,8) + ' / '+ IntToHex(s2.ScopeListPtr^.HighestKnown,8)+' // '+format('%2.1f',[s2.Index*100/s2.ScopeListPtr^.HighestKnown]);
           Application.ProcessMessages;
           if not FShowingUnit then break;
         end;
       end;
     end;

     Node.Text := Format('At %4x  Abr: %d  Tag: %d %s  ChildCnt: %d   %s', [s.Entry-BaseScopeAddr, Abbrev, Def.tag, DwarfTagToString(Def.tag), i, entryname]);
  end;

var
  i: Integer;
  s: TDwarfScopeInfo;
  Node: TTreeNode;
begin
  FShowingUnit := not FShowingUnit;//////////////////
  if not FShowingUnit then exit;/////////////////
  TreeView1.BeginUpdate;
  try
    TreeView1.Items.Clear;
    i := CompUnitListBox.ItemIndex;
    if i < 0 then exit;
    CU := TDwarfCompilationUnitHack(CompUnitListBox.Items.Objects[i]);
    if CU = nil then exit;
    s := CU.FirstScope;
    BaseScopeAddr := s.Entry;

    Node := nil;
    while s.IsValid do begin
      Node := AddNode(nil,Node,s);
      s.GoNext;
    end;
  finally
    TreeView1.EndUpdate;
    FShowingUnit := False; ////////////////////
  end;
end;


procedure TForm1.FormCreate(Sender: TObject);
begin
  FTestCaseTexts:= TStringList.Create;
  NameList:= TStringList.Create;
end;

procedure TForm1.FormDestroy(Sender: TObject);
begin
  UnLoadDwarf;
  FTestCaseTexts.Free;
end;

procedure TForm1.FormDropFiles(Sender: TObject; const FileNames: array of String
  );
begin
  if Length(FileNames) > 0 then
    FileNameEdit1.Text := FileNames[0];
end;

procedure TForm1.UnLoadDwarf;
begin
  FreeAndNil(FDwarfInfo);
  FreeAndNil(FImageLoaderList);
  FCUCount := 0;
end;

end.


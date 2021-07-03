{ $Id: carbonwsstdctrls.pp 15309 2008-06-04 22:12:59Z vincents $}
{
 *****************************************************************************
 *                              CocoaWSStdCtrls.pp                           *
 *                              ---------------                              *
 *                                                                           *
 *                                                                           *
 *****************************************************************************

 *****************************************************************************
  This file is part of the Lazarus Component Library (LCL)

  See the file COPYING.modifiedLGPL.txt, included in this distribution,
  for details about the license.
 *****************************************************************************
}
unit CocoaWSStdCtrls;

{$mode objfpc}{$H+}
{$modeswitch objectivec1}
{$modeswitch objectivec2}
{$include cocoadefines.inc}

interface

uses
  // Libs
  MacOSAll, CocoaAll, Classes, sysutils,
  // LCL
  Controls, StdCtrls, Graphics, LCLType, LMessages, LCLProc, LCLMessageGlue, Forms,
  // LazUtils
  LazUTF8, TextStrings,
  // Widgetset
  WSStdCtrls, WSLCLClasses, WSControls, WSProc,
  // LCL Cocoa
  CocoaWSCommon, CocoaPrivate, CocoaUtils, CocoaGDIObjects, CocoaButtons,
  CocoaTables, CocoaTextEdits, CocoaScrollers, Cocoa_Extra;

type

  { TCocoaWSScrollBar }

  TCocoaWSScrollBar = class(TWSScrollBar)
  published
    class function CreateHandle(const AWinControl: TWinControl; const AParams: TCreateParams): TLCLIntfHandle; override;
    class procedure SetKind(const AScrollBar: TCustomScrollBar; const AIsHorizontal: Boolean); override;
    class procedure SetParams(const AScrollBar: TCustomScrollBar); override;
  end;

  { TCocoaWSCustomGroupBox }

  TCocoaWSCustomGroupBox = class(TWSCustomGroupBox)
  published
    class function CreateHandle(const AWinControl: TWinControl; const AParams: TCreateParams): TLCLIntfHandle; override;
    class function  GetText(const AWinControl: TWinControl; var AText: String): Boolean; override;
    class procedure SetText(const AWinControl: TWinControl; const AText: String); override;
    class procedure SetFont(const AWinControl: TWinControl; const AFont: TFont); override;
  end;

  { TLCLComboboxCallback }

  TLCLComboboxCallback = class(TLCLCommonCallback, IComboBoxCallback)
  public
    isShowPopup: Boolean;
    procedure ComboBoxWillPopUp;
    procedure ComboBoxWillDismiss;
    procedure ComboBoxSelectionDidChange;
    procedure ComboBoxSelectionIsChanging;

    procedure ComboBoxDrawItem(itemIndex: Integer; ctx: TCocoaContext;
      const r: TRect; isSelected: Boolean);
  end;

  { TCocoaWSCustomComboBox }

  TCocoaWSCustomComboBox = class(TWSCustomComboBox)
  published
    class function  CreateHandle(const AWinControl: TWinControl; const AParams: TCreateParams): TLCLIntfHandle; override;
    class procedure SetBorderStyle(const AWinControl: TWinControl; const ABorderStyle: TBorderStyle); override;

    class function GetDroppedDown(const ACustomComboBox: TCustomComboBox): Boolean; override;
    {class function  GetSelStart(const ACustomComboBox: TCustomComboBox): integer; override;
    class function  GetSelLength(const ACustomComboBox: TCustomComboBox): integer; override;}
    class function  GetItemIndex(const ACustomComboBox: TCustomComboBox): integer; override;
    {class function  GetMaxLength(const ACustomComboBox: TCustomComboBox): integer; override;

    class procedure SetSelStart(const ACustomComboBox: TCustomComboBox; NewStart: integer); override;
    class procedure SetSelLength(const ACustomComboBox: TCustomComboBox; NewLength: integer); override;}
    class procedure SetItemIndex(const ACustomComboBox: TCustomComboBox; NewIndex: integer); override;
    {class procedure SetMaxLength(const ACustomComboBox: TCustomComboBox; NewLength: integer); override;}
    class procedure SetStyle(const ACustomComboBox: TCustomComboBox; NewStyle: TComboBoxStyle); override;
    class procedure SetReadOnly(const ACustomComboBox: TCustomComboBox; NewReadOnly: boolean); override;
    class procedure SetDropDownCount(const ACustomComboBox: TCustomComboBox; NewCount: Integer); override;

    class function  GetItems(const ACustomComboBox: TCustomComboBox): TStrings; override;
    {class procedure Sort(const ACustomComboBox: TCustomComboBox; AList: TStrings; IsSorted: boolean); override;}

    class function GetItemHeight(const ACustomComboBox: TCustomComboBox): Integer; override;
    class procedure SetItemHeight(const ACustomComboBox: TCustomComboBox; const AItemHeight: Integer); override;
    class procedure GetPreferredSize(
       const AWinControl: TWinControl; var PreferredWidth, PreferredHeight: integer;
       WithThemeSpace: Boolean); override;

    class procedure SetText(const AWinControl: TWinControl; const AText: String); override;
    class procedure SetTextHint(const ACustomComboBox: TCustomComboBox; const ATextHint: string); override;
  end;

  { TCocoaWSCustomListBox }

  TCocoaWSCustomListBox = class(TWSCustomListBox)
  published
    class procedure DragStart(const ACustomListBox: TCustomListBox); override;

    class function CreateHandle(const AWinControl: TWinControl; const AParams: TCreateParams): TLCLIntfHandle; override;
    class function GetIndexAtXY(const ACustomListBox: TCustomListBox; X, Y: integer): integer; override;
    class function GetItemIndex(const ACustomListBox: TCustomListBox): integer; override;
    class function GetItemRect(const ACustomListBox: TCustomListBox; Index: integer; var ARect: TRect): boolean; override;
    class function GetSelCount(const ACustomListBox: TCustomListBox): integer; override;
    class function GetSelected(const ACustomListBox: TCustomListBox; const AIndex: integer): boolean; override;
    class function GetStrings(const ACustomListBox: TCustomListBox): TStrings; override;
    class function GetTopIndex(const ACustomListBox: TCustomListBox): integer; override;

    class procedure SelectItem(const ACustomListBox: TCustomListBox; AIndex: integer; ASelected: boolean); override;
    class procedure SetBorderStyle(const AWinControl: TWinControl; const ABorderStyle: TBorderStyle); override;
    //class procedure SetBorder(const ACustomListBox: TCustomListBox); override;
    class procedure SetItemIndex(const ACustomListBox: TCustomListBox; const AIndex: integer); override;
    class procedure SetSelectionMode(const ACustomListBox: TCustomListBox; const AExtendedSelect, AMultiSelect: boolean); override;
    class procedure SetStyle(const ACustomListBox: TCustomListBox); override;
    {class procedure SetSorted(const ACustomListBox: TCustomListBox; AList: TStrings; ASorted: boolean); override;}
    class procedure SetTopIndex(const ACustomListBox: TCustomListBox; const NewTopIndex: integer); override;
  end;

  { TCocoaWSCustomEdit }

  TCocoaWSCustomEdit = class(TWSCustomEdit)
  public
    class function GetTextField(AWinControl: TWinControl): TCocoaTextField;
  published
    class function  CreateHandle(const AWinControl: TWinControl; const AParams: TCreateParams): TLCLIntfHandle; override;

    // WSControl functions
    class procedure SetColor(const AWinControl: TWinControl); override;
    class procedure SetBorderStyle(const AWinControl: TWinControl; const ABorderStyle: TBorderStyle); override;

    // WSEdit functions
    class function  GetSelStart(const ACustomEdit: TCustomEdit): integer; override;
    class function  GetSelLength(const ACustomEdit: TCustomEdit): integer; override;
    class procedure SetAlignment(const ACustomEdit: TCustomEdit; const NewAlignment: TAlignment); override;

    {class procedure SetCharCase(const ACustomEdit: TCustomEdit; NewCase: TEditCharCase); override;
    class procedure SetEchoMode(const ACustomEdit: TCustomEdit; NewMode: TEchoMode); override;}
    class procedure SetMaxLength(const ACustomEdit: TCustomEdit; NewLength: integer); override;
    class procedure SetPasswordChar(const ACustomEdit: TCustomEdit; NewChar: char); override;
    class procedure SetReadOnly(const ACustomEdit: TCustomEdit; NewReadOnly: boolean); override;
    class procedure SetSelStart(const ACustomEdit: TCustomEdit; NewStart: integer); override;
    class procedure SetSelLength(const ACustomEdit: TCustomEdit; NewLength: integer); override;

    class procedure Cut(const ACustomEdit: TCustomEdit); override;
    class procedure Copy(const ACustomEdit: TCustomEdit); override;
    class procedure Paste(const ACustomEdit: TCustomEdit); override;
    class procedure Undo(const ACustomEdit: TCustomEdit); override;

    class procedure SetText(const AWinControl: TWinControl; const AText: String); override;
    class procedure SetTextHint(const ACustomEdit: TCustomEdit; const ATextHint: string); override;
  end;
  
  { TCocoaMemoStrings }

  TCocoaMemoStrings = class(TCustomMemoStrings)
  private
    FTextView: TCocoaTextView;
  public
    class procedure GetLineStart(const s: AnsiString; LineIndex: Integer; var Offset, LinesSkipped: Integer);
  protected
    function GetTextStr: string; override;
    procedure SetTextStr(const Value: string); override;
    function GetCount: Integer; override;
    function Get(Index: Integer): string; override;
  public
    constructor Create(ATextView: TCocoaTextView);
    procedure Clear; override;
    procedure Delete(Index: Integer); override;
    procedure Insert(Index: Integer; const S: string); override;
    procedure LoadFromFile(const FileName: string); override;
    procedure SaveToFile(const FileName: string); override;
  end;

  { TCocoaWSCustomMemo }

  TCocoaWSCustomMemo = class(TWSCustomMemo)
  public
    class function GetTextView(AWinControl: TWinControl): TCocoaTextView;
    class function GetScrollView(AWinControl: TWinControl): TCocoaScrollView;
  published
    class function CreateHandle(const AWinControl: TWinControl; const AParams: TCreateParams): TLCLIntfHandle; override;

    // WSControl functions
    class procedure SetColor(const AWinControl: TWinControl); override;
    class procedure SetSelStart(const ACustomEdit: TCustomEdit; NewStart: integer); override;
    class procedure SetSelLength(const ACustomEdit: TCustomEdit; NewLength: integer); override;
    class procedure SetBorderStyle(const AWinControl: TWinControl; const ABorderStyle: TBorderStyle); override;

    // WSEdit functions
    //class function GetCanUndo(const ACustomEdit: TCustomEdit): Boolean; override;
    class function GetCaretPos(const ACustomEdit: TCustomEdit): TPoint; override;
    class function GetSelStart(const ACustomEdit: TCustomEdit): integer; override;
    class function GetSelLength(const ACustomEdit: TCustomEdit): integer; override;
    class procedure SetAlignment(const ACustomEdit: TCustomEdit; const NewAlignment: TAlignment); override;

    // WSMemo functions
    class function GetStrings(const ACustomMemo: TCustomMemo): TStrings; override;
    class procedure AppendText(const ACustomMemo: TCustomMemo; const AText: string); override;
    class procedure SetScrollbars(const ACustomMemo: TCustomMemo; const NewScrollbars: TScrollStyle); override;
    class procedure SetWantReturns(const ACustomMemo: TCustomMemo; const NewWantReturns: boolean); override;
    class procedure SetWantTabs(const ACustomMemo: TCustomMemo; const NewWantTabs: boolean); override;
    class procedure SetWordWrap(const ACustomMemo: TCustomMemo; const NewWordWrap: boolean); override;
    class procedure SetReadOnly(const ACustomEdit: TCustomEdit; NewReadOnly: boolean); override;

    class function GetTextLen(const AWinControl: TWinControl; var ALength: Integer): Boolean; override;
    class procedure SetText(const AWinControl: TWinControl; const AText: String); override;
    class function GetText(const AWinControl: TWinControl; var AText: String): Boolean; override;
  end;

  { TLCLButtonCallback }

  TLCLButtonCallback = class(TLCLCommonCallback, IButtonCallback)
  public
    procedure ButtonClick; virtual;
    procedure Draw(ControlContext: NSGraphicsContext; const bounds, dirty: NSRect); override;
    procedure GetAllowMixedState(var allowed: Boolean); virtual;
  end;
  TLCLButtonCallBackClass = class of TLCLButtonCallBack;

  { TLCLListBoxCallback }

  TLCLListBoxCallback = class(TLCLCommonCallback, IListViewCallBack)
  protected
    function AllocStrings(ATable: NSTableView): TCocoaStringList; virtual;
  public
    listview : TCocoaTableListView;
    strings  : TCocoaStringList;
    constructor CreateWithView(AOwner: TCocoaTableListView; ATarget: TWinControl);
    destructor Destroy; override;
    function ItemsCount: Integer; virtual;
    function GetItemTextAt(ARow, ACol: Integer; var Text: String): Boolean; virtual;
    function GetItemCheckedAt(ARow, ACol: Integer; var isChecked: Integer): Boolean; virtual;
    function GetItemImageAt(ARow, ACol: Integer; var imgIdx: Integer): Boolean; virtual;
    function GetImageFromIndex(imgIdx: Integer): NSImage; virtual;
    procedure SetItemTextAt(ARow, ACol: Integer; const Text: String); virtual;
    procedure SetItemCheckedAt(ARow, ACol: Integer; isChecked: Integer); virtual;
    procedure tableSelectionChange(ARow: Integer; Added, Removed: NSIndexSet); virtual;
    procedure ColumnClicked(ACol: Integer); virtual;
    procedure DrawRow(rowidx: Integer; ctx: TCocoaContext; const r: TRect; state: TOwnerDrawState); virtual;
    procedure GetRowHeight(rowidx: integer; var h: Integer); virtual;
  end;
  TLCLListBoxCallBackClass = class of TLCLListBoxCallBack;

  { TCocoaWSButton }

  TCocoaWSButton = class(TWSButton)
  published
    class function CreateHandle(const AWinControl: TWinControl; const AParams: TCreateParams): TLCLIntfHandle; override;
    class procedure SetDefault(const AButton: TCustomButton; ADefault: Boolean); override;
    class procedure SetText(const AWinControl: TWinControl; const AText: String); override;
    class function GetText(const AWinControl: TWinControl; var AText: String): Boolean; override;
    class function GetTextLen(const AWinControl: TWinControl; var ALength: Integer): Boolean; override;
    class procedure SetFont(const AWinControl: TWinControl; const AFont: TFont); override;
  end;

  { TLCLCheckBoxCallback }

  TLCLCheckBoxCallback = class(TLCLButtonCallBack)
  public
    procedure ButtonClick; override;
    procedure GetAllowMixedState(var allowed: Boolean); override;
  end;

  { TCocoaWSCustomCheckBox }

  TCocoaWSCustomCheckBox = class(TWSCustomCheckBox)
  published
    class function CreateHandle(const AWinControl: TWinControl; const AParams: TCreateParams): TLCLIntfHandle; override;
    class function RetrieveState(const ACustomCheckBox: TCustomCheckBox): TCheckBoxState; override;
    class procedure SetState(const ACustomCheckBox: TCustomCheckBox; const NewState: TCheckBoxState); override;
    //
    class procedure GetPreferredSize(const AWinControl: TWinControl; var PreferredWidth, PreferredHeight: integer; {%H-}WithThemeSpace: Boolean); override;
    class procedure SetText(const AWinControl: TWinControl; const AText: String); override;
    class function GetText(const AWinControl: TWinControl; var AText: String): Boolean; override;
    class function GetTextLen(const AWinControl: TWinControl; var ALength: Integer): Boolean; override;
  end;

  { TCocoaWSToggleBox }

  TCocoaWSToggleBox = class(TWSToggleBox)
  published
    class function CreateHandle(const AWinControl: TWinControl; const AParams: TCreateParams): TLCLIntfHandle; override;
  end;

  { TLCLRadioButtonCallback }

  TLCLRadioButtonCallback = class(TLCLCheckBoxCallback)
  public
    procedure ButtonClick; override;
  end;

  { TCocoaWSRadioButton }

  TCocoaWSRadioButton = class(TWSRadioButton)
  published
    class function CreateHandle(const AWinControl: TWinControl; const AParams: TCreateParams): TLCLIntfHandle; override;
    class procedure SetState(const ACustomCheckBox: TCustomCheckBox; const NewState: TCheckBoxState); override;
  end;

  { TCocoaWSCustomStaticText }

  TCocoaWSCustomStaticText = class(TWSCustomStaticText)
  private
  protected
  published
    class function  CreateHandle(const AWinControl: TWinControl; const AParams: TCreateParams): TLCLIntfHandle; override;
//    class procedure SetAlignment(const ACustomStaticText: TCustomStaticText; const NewAlignment: TAlignment); override;
  end;

function AllocTextView(ATarget: TWinControl; const AParams: TCreateParams; fieldEditor: Boolean): NSTextView;
function AllocButton(const ATarget: TWinControl; const ACallBackClass: TLCLButtonCallBackClass; const AParams: TCreateParams; btnBezel: NSBezelStyle; btnType: NSButtonType): TCocoaButton;
function AllocTextField(ATarget: TWinControl; const AParams: TCreateParams): TCocoaTextField;
function AllocSecureTextField(ATarget: TWinControl; const AParams: TCreateParams): TCocoaSecureTextField;

function GetListBox(AWinControl: TWinControl): TCocoaTableListView;
procedure ListBoxSetStyle(list: TCocoaTableListView; AStyle: TListBoxStyle);

procedure TextViewSetWordWrap(txt: NSTextView; lScroll: NSScrollView; NewWordWrap: Boolean);
function AlignmentLCLToCocoa(al: TAlignment): NSTextAlignment;
procedure TextViewSetAllignment(txt: NSTextView; align: TAlignment);
procedure TextFieldSetAllignment(txt: NSTextField; align: TAlignment);
procedure TextFieldSetBorderStyle(txt: NSTextField; astyle: TBorderStyle);
procedure RadioButtonSwitchSiblings(checkedRadio: NSButton);
procedure ButtonSetState(btn: NSButton; NewState: TCheckBoxState;
  SkipChangeEvent: Boolean = true);
procedure TextFieldSetTextHint(txt: NSTextField; const str: string);
procedure ObjSetTextHint(obj: NSObject; const str: string);

procedure ScrollViewSetScrollStyles(AScroll: TCocoaScrollView; AStyles: TScrollStyle);

function ComboBoxStyleIsReadOnly(AStyle: TComboBoxStyle): Boolean;
function ComboBoxIsReadOnly(cmb: TCustomComboBox): Boolean;
function ComboBoxIsOwnerDrawn(AStyle: TComboBoxStyle): Boolean;
function ComboBoxIsVariable(AStyle: TComboBoxStyle): Boolean;
procedure ComboBoxSetBorderStyle(box: NSComboBox; astyle: TBorderStyle);

// Sets the control text and then calls controls callback (if any)
// with TextChange (CM_TEXTCHANGED) event.
// Cocoa control do not fire a notification, if text is changed programmatically
// LCL expects a change notification in either way. (by software or by user)
procedure ControlSetTextWithChangeEvent(ctrl: NSControl; const text: string);

implementation

uses
  CocoaInt;

const
  VerticalScrollerVisible: array[TScrollStyle] of boolean = (
 {ssNone          } false,
 {ssHorizontal    } false,
 {ssVertical      } true,
 {ssBoth          } true,
 {ssAutoHorizontal} false,
 {ssAutoVertical  } true,
 {ssAutoBoth      } true
  );

  HorizontalScrollerVisible: array[TScrollStyle] of boolean = (
 {ssNone          } false,
 {ssHorizontal    } true,
 {ssVertical      } false,
 {ssBoth          } true,
 {ssAutoHorizontal} true,
 {ssAutoVertical  } false,
 {ssAutoBoth      } true
  );

  ScrollerAutoHide: array[TScrollStyle] of boolean = (
 {ssNone          } false,
 {ssHorizontal    } false,
 {ssVertical      } false,
 {ssBoth          } false,
 {ssAutoHorizontal} true,
 {ssAutoVertical  } true,
 {ssAutoBoth      } true
  );

function AllocButton(const ATarget: TWinControl; const ACallBackClass: TLCLButtonCallBackClass; const AParams: TCreateParams; btnBezel: NSBezelStyle; btnType: NSButtonType): TCocoaButton;
begin
  Result := TCocoaButton.alloc.lclInitWithCreateParams(AParams);
  if Assigned(Result) then
  begin
    TCocoaButton(Result).callback := ACallBackClass.Create(Result, ATarget);

    Result.setTitle(ControlTitleToNSStr(AParams.Caption));
    if btnBezel <> 0 then
      Result.setBezelStyle(btnBezel);
    Result.setButtonType(btnType);
  end;
end;

function AllocTextView(ATarget: TWinControl; const AParams: TCreateParams; fieldEditor: Boolean): NSTextView;
begin
  Result := TCocoaTextView.alloc.lclInitWithCreateParams(AParams);
  if Assigned(Result) then
  begin
    TCocoaTextView(Result).callback := TLCLCommonCallback.Create(Result, ATarget);
  end;
end;

function AllocTextField(ATarget: TWinControl; const AParams: TCreateParams): TCocoaTextField;
begin
  Result := TCocoaTextField.alloc.lclInitWithCreateParams(AParams);
  if Assigned(Result) then
  begin
    Result.setFont(NSFont.systemFontOfSize(NSFont.systemFontSize));
    Result.callback := TLCLCommonCallback.Create(Result, ATarget);
    SetNSControlValue(Result, AParams.Caption);
  end;
end;

function AllocSecureTextField(ATarget: TWinControl; const AParams: TCreateParams): TCocoaSecureTextField;
begin
  Result := TCocoaSecureTextField.alloc.lclInitWithCreateParams(AParams);
  if Assigned(Result) then
  begin
    Result.setFont(NSFont.systemFontOfSize(NSFont.systemFontSize));
    TCocoaSecureTextField(Result).callback := TLCLCommonCallback.Create(Result, ATarget);
    SetNSText(Result.currentEditor, AParams.Caption);
  end;
end;

procedure TextFieldSetBorderStyle(txt: NSTextField; astyle: TBorderStyle);
begin
  if not Assigned(txt) then Exit;
  {$ifdef BOOLFIX}
  txt.setBezeled_(Ord(astyle <> bsNone));
  {$else}
  txt.setBezeled(astyle <> bsNone);
  {$endif}
end;

procedure RadioButtonSwitchSiblings(checkedRadio: NSButton);
var
  SubView : NSView;
begin
  if not Assigned(checkedRadio) then Exit;
  for SubView in checkedRadio.superView.subviews do
    if (SubView <> checkedRadio) and (SubView.lclGetTarget is TRadioButton) then
    begin
      NSButton(SubView).setState(NSOffState);
    end;
end;

procedure ButtonSetState(btn: NSButton; NewState: TCheckBoxState;
  SkipChangeEvent: Boolean = true);
const
  buttonState: array [TcheckBoxState] of NSInteger =
    (NSOffState, NSOnState, NSMixedState);
var
  cb : IButtonCallback;
begin
  if NewState = cbGrayed then
    {$ifdef BOOLFIX}
    btn.setAllowsMixedState_(Ord(true));
    {$else}
    btn.setAllowsMixedState(true);
    {$endif}
  if SkipChangeEvent and (btn.isKindOfClass(TCocoaButton)) then
  begin
    //todo: This place needs a cleanup!
    //      Assigning state, while having callback removed
    //      TCocoaButton.setState is causing OnChange event, if callback is not nil
    cb := TCocoaButton(btn).callback;
    TCocoaButton(btn).callback := nil;
    btn.setState(buttonState[NewState]);
    TCocoaButton(btn).callback := cb;
  end
  else
    btn.setState(buttonState[NewState]);
end;

procedure ScrollViewSetScrollStyles(AScroll: TCocoaScrollView; AStyles: TScrollStyle);
begin
  AScroll.setHasVerticalScroller(VerticalScrollerVisible[AStyles]);
  AScroll.setHasHorizontalScroller(HorizontalScrollerVisible[AStyles]);
  AScroll.setAutohidesScrollers(ScrollerAutoHide[AStyles]);
end;

procedure TextFieldSetTextHint(txt: NSTextField; const str: string);
var
  ns : NSString;
begin
  if not Assigned(txt) then Exit;
  ns := NSStringUtf8(str);
  txt.setPlaceholderString(ns);
  ns.release;
end;

procedure ObjSetTextHint(obj: NSObject; const str: string);
begin
  if not Assigned(obj) or not obj.isKindOfClass(NSTextField) then Exit;
  TextFieldSetTextHint(NSTextField(obj), str);
end;

function ComboBoxStyleIsReadOnly(AStyle: TComboBoxStyle): Boolean;
begin
  Result := not AStyle.HasEditBox;
end;

function ComboBoxIsReadOnly(cmb: TCustomComboBox): Boolean;
begin
  Result := Assigned(cmb) and (ComboBoxStyleIsReadOnly(cmb.Style));
end;

function ComboBoxIsOwnerDrawn(AStyle: TComboBoxStyle): Boolean;
begin
  Result := AStyle.IsOwnerDrawn;
end;

function ComboBoxIsVariable(AStyle: TComboBoxStyle): Boolean;
begin
  Result := AStyle.IsVariable;
end;

procedure ComboBoxSetBorderStyle(box: NSComboBox; astyle: TBorderStyle);
begin
  {$IFDEF BOOLFIX}
  box.setBezeled_(Ord(astyle <> bsNone));
  {$else}
  box.setBezeled(astyle <> bsNone);
  {$endif}
end;

{ TLCLRadioButtonCallback }

procedure TLCLRadioButtonCallback.ButtonClick;
var
  SubView: NSView;
begin
  if not Owner.lclIsEnabled() then Exit;
  if NSButton(Owner).state = NSOnState then
    RadioButtonSwitchSiblings(NSButton(Owner));
  inherited ButtonClick;
end;

{ TLCLButtonCallback }

procedure TLCLButtonCallback.ButtonClick;
begin
  if not Owner.lclIsEnabled() then Exit;
  SendSimpleMessage(Target, LM_CLICKED);
end;

procedure TLCLButtonCallback.Draw(ControlContext: NSGraphicsContext;
  const bounds, dirty: NSRect);
var
  PS: PPaintStruct;
  nsr:NSRect;
  ctx: TCocoaContext;
begin
  // todo: think more about draw call while previous draw still active
  ctx := TCocoaContext.Create(ControlContext);
  ctx.isControlDC := True;
  try
    nsr:=dirty;
    nsr.origin.y:=bounds.size.height-dirty.origin.y-dirty.size.height;
    New(PS);
    try
      FillChar(PS^, SizeOf(TPaintStruct), 0);
      PS^.hdc := HDC(ctx);
      PS^.rcPaint := NSRectToRect(nsr);
      LCLSendPaintMsg(Target, HDC(ctx), PS);
    finally
      Dispose(PS);
    end;
  finally
    FreeAndNil(ctx);
  end;
end;

procedure TLCLButtonCallback.GetAllowMixedState(var allowed: Boolean);
begin

end;

{ TLCLListBoxCallback }

function TLCLListBoxCallback.AllocStrings(ATable: NSTableView
  ): TCocoaStringList;
begin
  Result := TCocoaStringList.Create(ATable);
end;

constructor TLCLListBoxCallback.CreateWithView(AOwner: TCocoaTableListView;
  ATarget: TWinControl);
begin
  Create(AOwner, ATarget);

  listview := AOwner;
  strings := AllocStrings(AOwner);
end;

destructor TLCLListBoxCallback.Destroy;
begin
  // "strings" are released with FreeStrings call
  inherited Destroy;
end;

function TLCLListBoxCallback.ItemsCount: Integer;
begin
  Result := strings.Count;
end;

function TLCLListBoxCallback.GetItemTextAt(ARow, ACol: Integer; var Text: String): Boolean;
begin
  Result := (ARow>=0) and (ARow < strings.Count);
  if Result then Text := strings[ARow];
end;

function TLCLListBoxCallback.GetItemCheckedAt(ARow, ACol: Integer;
  var isChecked: Integer): Boolean;
begin
  Result := false;
end;

function TLCLListBoxCallback.GetItemImageAt(ARow, ACol: Integer;
  var imgIdx: Integer): Boolean;
begin
  Result := false;
end;

function TLCLListBoxCallback.GetImageFromIndex(imgIdx: Integer): NSImage;
begin
  Result := nil;
end;

procedure TLCLListBoxCallback.SetItemTextAt(ARow, ACol: Integer;
  const Text: String);
begin
  // todo:
end;

procedure TLCLListBoxCallback.SetItemCheckedAt(ARow, ACol: Integer;
  isChecked: Integer);
begin
  // do nothing
end;

procedure TLCLListBoxCallback.tableSelectionChange(ARow: Integer; Added,
  Removed: NSIndexSet);
begin
  // do not notify about selection changes while clearing
  if Assigned(strings) and (strings.isClearing) then Exit;
  SendSimpleMessage(Target, LM_SELCHANGE);
end;

procedure TLCLListBoxCallback.ColumnClicked(ACol: Integer);
begin
  // not needed
end;

procedure TLCLListBoxCallback.DrawRow(rowidx: Integer; ctx: TCocoaContext;
  const r: TRect; state: TOwnerDrawState);
var
  DrawStruct: TDrawListItemStruct;
begin
  if not listview.isOwnerDraw then Exit;
  DrawStruct.ItemState := state;
  DrawStruct.Area := r;
  DrawStruct.DC := HDC(ctx);
  DrawStruct.ItemID :=  rowIdx;
  LCLSendDrawListItemMsg(Target, @DrawStruct);
end;

procedure TLCLListBoxCallback.GetRowHeight(rowidx: integer; var h: Integer);
begin
  if TCustomListBox(Target).Style = lbOwnerDrawVariable then
    TCustomListBox(Target).MeasureItem(rowidx, h);
end;

{ TLCLCheckBoxCallback }

procedure TLCLCheckBoxCallback.ButtonClick;
begin
  inherited;
  if not Owner.lclIsEnabled() then Exit;
  SendSimpleMessage(Target, LM_CHANGED);
  // todo: win32 has something about dbcheckbox handling here. so maybe we need to handle it special too
end;

procedure TLCLCheckBoxCallback.GetAllowMixedState(var allowed: Boolean);
begin
  allowed := TCustomCheckBox(Target).AllowGrayed;
end;

{ TLCLComboboxCallback }

procedure TLCLComboboxCallback.ComboBoxWillPopUp;
begin
  isShowPopup := true;
  LCLSendDropDownMsg(Target);
end;

procedure TLCLComboboxCallback.ComboBoxWillDismiss;
begin
  LCLSendCloseUpMsg(Target);
  isShowPopup := false;
end;

procedure TLCLComboboxCallback.ComboBoxSelectionDidChange;
begin
  SendSimpleMessage(Target, LM_SELCHANGE);
end;

procedure TLCLComboboxCallback.ComboBoxSelectionIsChanging;
begin

end;

procedure TLCLComboboxCallback.ComboBoxDrawItem(itemIndex: Integer;
  ctx: TCocoaContext; const r: TRect; isSelected: Boolean);
var
  itemstruct: TDrawListItemStruct;
begin
  itemstruct.ItemID := UINT(itemIndex);
  itemstruct.Area := r;
  itemstruct.DC := HDC(ctx);
  itemstruct.ItemState := [];
  if isSelected then Include(itemstruct.ItemState, odSelected);
  // we don't distingiush at the moment
  if isSelected then Include(itemstruct.ItemState, odFocused);

  LCLSendDrawListItemMsg(Target, @itemstruct);
end;


{ TCocoaWSButton }

{------------------------------------------------------------------------------
  Method:  TCocoaWSButton.CreateHandle
  Params:  AWinControl - LCL control
           AParams     - Creation parameters
  Returns: Handle to the control in Cocoa interface

  Creates new button control in Cocoa interface with the specified parameters
 ------------------------------------------------------------------------------}
class function TCocoaWSButton.CreateHandle(const AWinControl: TWinControl;
  const AParams: TCreateParams): TLCLIntfHandle;
var
  btn: TCocoaButton;
begin
  btn := AllocButton(AWinControl, TLCLButtonCallback, AParams, NSRoundedBezelStyle, NSMomentaryPushInButton);
  btn.smallHeight := PUSHBTN_SMALL_HEIGHT;
  btn.miniHeight := PUSHBTN_MINI_HEIGHT;
  btn.adjustFontToControlSize:=true;
  Result := TLCLIntfHandle(btn);
end;

{------------------------------------------------------------------------------
  Method:  TCocoaWSButton.SetDefault
  Params:  AButton  - LCL button control
           ADefault

  Sets button default indication in Cocoa interface
 ------------------------------------------------------------------------------}
class procedure TCocoaWSButton.SetDefault(const AButton: TCustomButton; ADefault: Boolean);
var
  cf: NSString;
const
  DefEq: array [Boolean] of String = (#0, #13);
begin
  if not AButton.HandleAllocated then
    Exit;
  cf := NSStringUtf8(DefEq[ADefault]);
  NSButton(AButton.Handle).setKeyEquivalent(cf);
  cf.release;
end;

class procedure TCocoaWSButton.SetText(const AWinControl: TWinControl; const AText: String);
var
  btn : NSButton;
begin
  btn := NSButton(AWinControl.Handle);
  btn.setTitle(ControlTitleToNSStr(AText));
end;

class function TCocoaWSButton.GetText(const AWinControl: TWinControl;
  var AText: String): Boolean;
begin
  // The text is static, so let the LCL fallback to FCaption
  Result := false;
end;

class function TCocoaWSButton.GetTextLen(const AWinControl: TWinControl;
  var ALength: Integer): Boolean;
begin
  // The text is static, so let the LCL fallback to FCaption
  Result := false;
end;

class procedure TCocoaWSButton.SetFont(const AWinControl: TWinControl;
  const AFont: TFont);
begin
  if not (AWinControl.HandleAllocated) then Exit;
  TCocoaWSWinControl.SetFont(AWinControl, AFont);
  TCocoaButton(AWinControl.Handle).adjustFontToControlSize := (AFont.Name = 'default')
    and (AFont.Size = 0);
end;

{ TCocoaWSCustomCheckBox }

{------------------------------------------------------------------------------
  Method:  TCocoaWSCustomCheckBox.CreateHandle
  Params:  AWinControl - LCL control
           AParams     - Creation parameters
  Returns: Handle to the control in Cocoa interface

  Creates new check box in Cocoa interface with the specified parameters
 ------------------------------------------------------------------------------}
class function TCocoaWSCustomCheckBox.CreateHandle(const AWinControl: TWinControl;
  const AParams: TCreateParams): TLCLIntfHandle;
var
  btn: TCocoaButton;
  cb: IButtonCallback;
begin
  btn := AllocButton(AWinControl, TLCLCheckBoxCallBack, AParams, 0, NSSwitchButton);
  // changes in AllowGrayed are never sent to WS!
  // so it should be checked at create time (and at SetNextState?)
  if TCustomCheckBox(AWinControl).AllowGrayed then
    {$ifdef BOOLFIX}
    NSButton(btn).setAllowsMixedState_(Ord(true));
    {$else}
    NSButton(btn).setAllowsMixedState(true);
    {$endif}
    ;
  Result := TLCLIntfHandle(btn);
end;

{------------------------------------------------------------------------------
  Method:  TCocoaWSCustomCheckBox.RetrieveState
  Params:  ACustomCheckBox - LCL custom check box
  Returns: State of check box

  Retrieves the state of check box in Cocoa interface
 ------------------------------------------------------------------------------}
class function TCocoaWSCustomCheckBox.RetrieveState(const ACustomCheckBox: TCustomCheckBox): TCheckBoxState;
var
  state : NSInteger;
begin
  Result := cbUnchecked;
  if not ACustomCheckBox.HandleAllocated then
    Exit;
  state := NSButton(ACustomCheckBox.Handle).state;
  case state of
    NSOnState: Result := cbChecked;
    NSMixedState: Result := cbGrayed;
  end;
end;

{------------------------------------------------------------------------------
  Method:  TCocoaWSCustomCheckBox.SetState
  Params:  ACustomCheckBox - LCL custom check box
           NewState        - New state of check box

  Sets the new state of check box in Cocoa interface
 ------------------------------------------------------------------------------}
class procedure TCocoaWSCustomCheckBox.SetState(
  const ACustomCheckBox: TCustomCheckBox; const NewState: TCheckBoxState);
const
  buttonState: array [TcheckBoxState] of NSInteger = (NSOffState, NSOnState, NSMixedState);
begin
  if not ACustomCheckBox.HandleAllocated then Exit;
  ButtonSetState(NSButton(ACustomCheckBox.Handle), NewState);
end;

class procedure TCocoaWSCustomCheckBox.GetPreferredSize(
  const AWinControl: TWinControl; var PreferredWidth, PreferredHeight: integer;
  WithThemeSpace: Boolean);
var
  lButton: NSButton;
  lOldSize: NSSize;
begin
  if not AWinControl.HandleAllocated then Exit;
  lButton := NSButton(AWinControl.Handle);

  lOldSize := lButton.bounds.size;
  lButton.sizeToFit();
  PreferredWidth := round(lButton.bounds.size.width);
  PreferredHeight := round(lButton.bounds.size.height);
  //lButton.setBoundsSize(lOldSize); This causes problems in SetText
end;

class procedure TCocoaWSCustomCheckBox.SetText(const AWinControl: TWinControl;
  const AText: String);
begin
  TCocoaWSButton.SetText(AWinControl, AText);
end;

class function TCocoaWSCustomCheckBox.GetText(const AWinControl: TWinControl;
  var AText: String): Boolean;
begin
  Result := TCocoaWSButton.GetText(AWinControl, AText);
end;

class function TCocoaWSCustomCheckBox.GetTextLen(
  const AWinControl: TWinControl; var ALength: Integer): Boolean;
begin
  Result := TCocoaWSButton.GetTextLen(AWinControl, ALength);
end;

{ TCocoaWSRadioButton }

class function TCocoaWSRadioButton.CreateHandle(const AWinControl: TWinControl;
  const AParams: TCreateParams): TLCLIntfHandle;
var
  btn: TCocoaButton;
begin
  btn := AllocButton(AWinControl, TLCLRadioButtonCallback, AParams, 0, NSRadioButton);
  Result := TLCLIntfHandle(btn);
end;

class procedure TCocoaWSRadioButton.SetState(
  const ACustomCheckBox: TCustomCheckBox; const NewState: TCheckBoxState);
var
  btn : NSButton;
begin
  if not ACustomCheckBox.HandleAllocated then Exit;
  btn := NSButton(ACustomCheckBox.Handle);
  if NewState = cbChecked then
    RadioButtonSwitchSiblings(btn);
  ButtonSetState(btn, NewState);
end;

{ TCocoaWSCustomStaticText }

class function TCocoaWSCustomStaticText.CreateHandle(const AWinControl: TWinControl;
  const AParams: TCreateParams): TLCLIntfHandle;
var
  field: NSTextField;
begin
  field := NSTextField(AllocTextField(AWinControl, AParams));
  {$ifdef BOOLFIX}
  field.setBezeled_(Ord(False));
  field.setDrawsBackground_(Ord(False));
  field.setEditable_(Ord(False));
  field.setSelectable_(Ord(False));
  {$else}
  field.setBezeled(False);
  field.setDrawsBackground(False);
  field.setEditable(False);
  field.setSelectable(False);
  {$endif}
  Result:=TLCLIntfHandle(field);
end;

{ TCocoaWSCustomEdit }

class function TCocoaWSCustomEdit.GetTextField(AWinControl: TWinControl): TCocoaTextField;
begin
  if not Assigned(AWinControl) or (not AWinControl.HandleAllocated) or (AWinControl.Handle=0) then
  begin
    Exit(nil);
  end;

  if AWinControl is TCustomMemo then
  begin
    //raise Exception.Create('[TCocoaWSCustomEdit.GetTextField] Called for TMemo, but TMemo has no text field');
    Exit(nil);
  end;

  Result := TCocoaTextField(AWinControl.Handle);
end;

class function TCocoaWSCustomEdit.CreateHandle(const AWinControl: TWinControl; const AParams: TCreateParams): TLCLIntfHandle;
var
  field : NSTextField;
  cell  : NSTextFieldCell;
begin
  if TCustomEdit(AWinControl).PasswordChar=#0
    then field:=NSTextField(AllocTextField(AWinControl, AParams))
    else field:=NSTextField(AllocSecureTextField(AWinControl, AParams));
  if (field.respondsToSelector(ObjCSelector('cell'))) and Assigned(field.cell) then
  begin
    cell := NSTextFieldCell(field.cell);
    cell.setWraps(false);
    cell.setScrollable(true);
    cell.setUsesSingleLineMode(true);
  end;
  TextFieldSetAllignment(field, TCustomEdit(AWinControl).Alignment);
  TextFieldSetBorderStyle(field, TCustomEdit(AWinControl).BorderStyle);
  UpdateFocusRing(field, TCustomEdit(AWinControl).BorderStyle);

  Result:=TLCLIntfHandle(field);
end;

class procedure TCocoaWSCustomEdit.SetColor(const AWinControl: TWinControl);
var
  field : TCocoaTextField;
  w     : NSWindow;
  rsp   : NSResponder;
  ed    : TCocoaFieldEditor;
begin
  field := GetTextField(AWinControl);
  if not Assigned(field) then Exit;

  if (AWinControl.Color = clDefault) or (AWinControl.Color = clWindow) or (AWinControl.Color = clBackground)  then
    field.setBackgroundColor( NSColor.textBackgroundColor )
  else
    field.setBackgroundColor( ColorToNSColor(ColorToRGB(AWinControl.Color)));

  w := NSView(AWinControl.Handle).window;
  if not Assigned(w) then Exit;
  rsp := w.firstResponder;
  if (Assigned(rsp)) and (rsp.isKindOfClass(TCocoaFieldEditor)) then
  begin
    ed := TCocoaFieldEditor(rsp);
    if (NSObject(ed.delegate) = NSView(AWinControl.Handle)) then
      ed.lclReviseCursorColor;
  end;
end;

class procedure TCocoaWSCustomEdit.SetBorderStyle(
  const AWinControl: TWinControl; const ABorderStyle: TBorderStyle);
var
  field : TCocoaTextField;
begin
  field := GetTextField(AWinControl);
  if not Assigned(field) then Exit;
  {$ifdef BOOLFIX}
  field.setBordered_( ObjCBool(ABorderStyle <> bsNone) );
  field.setBezeled_( ObjCBool(ABorderStyle <> bsNone) );
  {$else}
  field.setBordered( ABorderStyle <> bsNone );
  field.setBezeled( ABorderStyle <> bsNone );
  {$endif}
  UpdateFocusRing(field, ABorderStyle);
end;

class function TCocoaWSCustomEdit.GetSelStart(const ACustomEdit: TCustomEdit): integer;
var
  field : TCocoaTextField;
  txt   :  NSText;
begin
  Result:=0;
  field := GetTextField(ACustomEdit);
  if not Assigned(field) then Exit;
  txt:=NSText(field.currentEditor);
  if not Assigned(txt) then Exit;

  Result:=txt.selectedRange.location;
end;

class function TCocoaWSCustomEdit.GetSelLength(const ACustomEdit: TCustomEdit): integer;
var
  field : TCocoaTextField;
  txt   :  NSText;
begin
  Result:=0;
  field := GetTextField(ACustomEdit);
  if not Assigned(field) then Exit;
  txt:=NSText(field.currentEditor);
  if not Assigned(txt) then Exit;

  Result:=txt.selectedRange.length;
end;

class procedure TCocoaWSCustomEdit.SetAlignment(const ACustomEdit: TCustomEdit;
  const NewAlignment: TAlignment);
var
  field: TCocoaTextField;
begin
  field := GetTextField(ACustomEdit);
  if not Assigned(field) then Exit;
  TextFieldSetAllignment(field, NewAlignment);
end;

class procedure TCocoaWSCustomEdit.SetMaxLength(const ACustomEdit: TCustomEdit;
  NewLength: integer);
var
  field: NSTextField;
begin
  if not (ACustomEdit.HandleAllocated) then Exit;
  field := NSTextField(ACustomEdit.Handle);
  if not Assigned(field) then Exit;

  if NSObject(field).respondsToSelector( ObjCSelector('lclSetMaxLength:') ) then
    {%H-}NSTextField_LCLExt(field).lclSetMaxLength(NewLength);
end;

class procedure TCocoaWSCustomEdit.SetPasswordChar(const ACustomEdit: TCustomEdit; NewChar: char);
begin
  if (NewChar<>#0) xor TCocoaTextField(ACustomEdit.Handle).isKindOfClass_(NSSecureTextField) then
    RecreateWnd(ACustomEdit);
end;


class procedure TCocoaWSCustomEdit.SetReadOnly(const ACustomEdit: TCustomEdit; NewReadOnly: boolean);
var
  lHandle: TCocoaTextField;
  w : NSWindow;
  t : NSText;
  isFocused: Boolean;
  r : Boolean;
  b : Boolean;
  rsp : NSResponder;
  ed  : TCocoaFieldEditor;
begin
  lHandle := GetTextField(ACustomEdit);
  if not Assigned(lHandle) then Exit;

  ed := nil; //if lHandle is "focused" then ed would be <> nil
  w := lHandle.window;
  if not Assigned(w) then t := nil
  else begin
    rsp := w.firstResponder;
    if (Assigned(rsp)) and (rsp.isKindOfClass(TCocoaFieldEditor)) then
    begin
      ed := TCocoaFieldEditor(rsp);
      if (NSObject(ed.delegate) = lHandle) then
      begin
        ed.retain;
        // the hack is needed to prevent infinite loop
        // on switching editable (ReadOnly) status.
        // without prevention of Editor focusing, AppKit goes into an infinite loop:
        // AppKit`-[_NSKeyboardFocusClipView removeFromSuperview] + 55
        // AppKit`-[NSWindow endEditingFor:] + 429
        // AppKit`-[NSView removeFromSuperview] + 78
        // AppKit`-[_NSKeyboardFocusClipView removeFromSuperview] + 55
        // AppKit`-[NSWindow endEditingFor:] + 429
        // AppKit`-[NSView removeFromSuperview] + 78
        // AppKit`-[_NSKeyboardFocusClipView removeFromSuperview] + 55
        ed.goingReadOnly := true;
      end
      else
        ed := nil; // someone else is focused
    end;
  end;

  {$ifdef BOOLFIX}
  lHandle.setEditable_(ObjCBool(not NewReadOnly));
  lHandle.setSelectable_(1); // allow to select read-only text (LCL compatible)
  {$ELSE}
  lHandle.setEditable( not NewReadOnly);
  lHandle.setSelectable(true); // allow to select read-only text (LCL compatible)
  {$ENDIF}

  if Assigned(ed) then begin
    ed.goingReadOnly := false;
    ed.release;
  end;
end;

class procedure TCocoaWSCustomEdit.SetSelStart(const ACustomEdit: TCustomEdit; NewStart: integer);
var
  lHandle: TCocoaTextField;
  curEditor:  NSText;
  lRange: NSRange;
begin
  lHandle := GetTextField(ACustomEdit);
  if not Assigned(lHandle) then Exit;
  curEditor := NSText(lHandle.currentEditor);
  if not Assigned(curEditor) then Exit;
  lRange := curEditor.selectedRange;
  lRange.location := NewStart;
  curEditor.setSelectedRange(lRange);
end;

class procedure TCocoaWSCustomEdit.SetSelLength(const ACustomEdit: TCustomEdit; NewLength: integer);
var
  lHandle: TCocoaTextField;
  curEditor:  NSText;
  lRange: NSRange;
begin
  lHandle := GetTextField(ACustomEdit);
  if not Assigned(lHandle) then Exit;
  curEditor := NSText(lHandle.currentEditor);
  if not Assigned(curEditor) then Exit;
  lRange := curEditor.selectedRange;
  lRange.length := NewLength;
  curEditor.setSelectedRange(lRange);
end;

class procedure TCocoaWSCustomEdit.Cut(const ACustomEdit: TCustomEdit);
begin
  if not Assigned(ACustomEdit) or not (ACustomEdit.HandleAllocated) then Exit;
  NSApplication(NSApp).sendAction_to_from(objcselector('cut:'), nil, id(ACustomEdit.Handle));
end;

class procedure TCocoaWSCustomEdit.Copy(const ACustomEdit: TCustomEdit);
begin
  if not Assigned(ACustomEdit) or not (ACustomEdit.HandleAllocated) then Exit;
  NSApplication(NSApp).sendAction_to_from(objcselector('copy:'), nil, id(ACustomEdit.Handle));
end;

class procedure TCocoaWSCustomEdit.Paste(const ACustomEdit: TCustomEdit);
begin
  if not Assigned(ACustomEdit) or not (ACustomEdit.HandleAllocated) then Exit;
  NSApplication(NSApp).sendAction_to_from(objcselector('paste:'), nil, id(ACustomEdit.Handle));
end;

class procedure TCocoaWSCustomEdit.Undo(const ACustomEdit: TCustomEdit);
begin
  if not Assigned(ACustomEdit) or not (ACustomEdit.HandleAllocated) then Exit;
  NSApplication(NSApp).sendAction_to_from(objcselector('undo:'), nil, id(ACustomEdit.Handle));
end;

class procedure TCocoaWSCustomEdit.SetText(const AWinControl: TWinControl;
  const AText: String);
var
  txt : string;
  mxl : Integer;
begin
  if (AWinControl.HandleAllocated) then
  begin
    txt := AText;
    mxl := TCustomEdit(AWinControl).MaxLength;
    if (mxl > 0) and (UTF8Length(txt) > mxl) then
      txt := UTF8Copy(txt, 1, mxl);
    ControlSetTextWithChangeEvent(NSControl(AWinControl.Handle), txt);
  end;
end;

class procedure TCocoaWSCustomEdit.SetTextHint(const ACustomEdit: TCustomEdit;
  const ATextHint: string);
begin
  if NSAppKitVersionNumber <= NSAppKitVersionNumber10_10 then Exit;
  if (ACustomEdit.HandleAllocated) then
    ObjSetTextHint(NSObject(ACustomEdit.Handle), ATextHint);
end;

{ TCocoaMemoStrings }

function LineBreaksToUnix(const src: string): string;
begin
  // todo: need more effecient replacement
  Result := StringReplace( StringReplace(
    StringReplace(src, #10#13, #10, [rfReplaceAll])
    , #13#10, #10, [rfReplaceAll])
    , #13, #10, [rfReplaceAll]);
end;

constructor TCocoaMemoStrings.Create(ATextView: TCocoaTextView);
begin
  inherited Create;
  FTextView := ATextView;
end;

function TCocoaMemoStrings.GetTextStr: string;
begin
  Result := NSStringToString(FTextView.string_);
end;

procedure TCocoaMemoStrings.SetTextStr(const Value: string);
begin
  SetNSText(FTextView, LineBreaksToUnix(Value));

  FTextView.textDidChange(nil);
end;

class procedure TCocoaMemoStrings.GetLineStart(const s: AnsiString; LineIndex: Integer; var Offset, LinesSkipped: Integer);
var
  i : Integer;
begin
  i:=1;
  LinesSkipped:=0;
  while (LinesSkipped<>LineIndex) and (i<=length(s)) do begin
    if s[i] in [#10, #13] then begin
      inc(i);
      inc(LinesSkipped);
      if (i<=length(s)) and (s[i] in [#10,#13]) and (s[i-1]<>s[i]) then
        inc(i);
    end else
      inc(i);
  end;
  Offset:=i;
end;

function TCocoaMemoStrings.GetCount:Integer;
var
  s      : NSString;
  i      : LongWord;
  strLen : LongWord;
begin
  s := FTextView.string_;
  // it's a very nice example for Apple's docs
  // https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/TextLayout/Tasks/CountLines.html
  strLen := s.length;
  i := 0;
  Result := 0;
  while (i < strLen) do begin
    i := NSMaxRange(s.lineRangeForRange(NSMakeRange(i, 0)));
    inc(Result);
  end;
end;

function TCocoaMemoStrings.Get(Index:Integer):string;
var
  s     : AnsiString;
  ofs   : Integer;
  eofs  : Integer;
  t     : Integer;
begin
  s:=GetTextStr;
  t:=0;
  ofs:=0;
  GetLineStart(s, Index, ofs, t);
  eofs:=ofs;
  while (eofs<=length(s)) and not (s[eofs] in [#10,#13]) do
    inc(eofs);
  Result:=Copy(s, ofs, eofs-ofs);
end;

procedure TCocoaMemoStrings.Clear;
begin
  SetTextStr('');
end;

procedure TCocoaMemoStrings.Delete(Index:Integer);
var
  s     : AnsiString;
  ofs   : Integer;
  eofs  : Integer;
  t     : Integer;
begin
  s:=GetTextStr;
  GetLineStart(s, Index, ofs, t);
  eofs:=ofs;
  while (eofs<=length(s)) and not (s[eofs] in [#10,#13]) do
    inc(eofs);
  if eofs<=length(s) then begin
    inc(eofs);
    if (eofs<=length(s)) and (s[eofs] in [#10,#13]) and (s[eofs-1]<>s[eofs]) then
      inc(eofs);
  end;
  System.Delete(s, ofs, eofs-ofs);
  SetTextStr(s);
end;

procedure TCocoaMemoStrings.Insert(Index:Integer;const S:string);
var
  rng   : NSRange;
  st,ed : NSUInteger;
  ced   : NSUInteger;
  ns    : NSString;
  idx   : integer;
  ro    : Boolean;
const
  LFSTR = #10;
begin
  ns:=FTextView.string_;
  idx:=0;
  rng:=NSMakeRange(0,0);
  while (idx<Index) and (rng.location<ns.length) do begin
    ns.getLineStart_end_contentsEnd_forRange(nil, @st, @ced, rng);
    inc(idx);
    rng.location:=st;
    rng.length:=0;
  end;

  // using selectedRange in order to be consistent with Windows widgetset
  if rng.location>ns.length then rng.location:=ns.length;
  inc(FTextView.supressTextChangeEvent);

  ro := FTextView.isEditable; // checking for read-only flag;
  if not ro then FTextView.setEditable(true);

  FTextView.setSelectedRange(rng);

  if (rng.location>=ns.length) and (st=ced) and (ns.length>0) then
    FTextView.insertText( NSString.stringWithUTF8String( LFSTR ));

  if S<>'' then
  begin
    FTextView.insertText( NSString.stringWithUTF8String( @S[1] ));
  end;

  dec(FTextView.supressTextChangeEvent);
  FTextView.insertText( NSString.stringWithUTF8String( LFSTR ));

  if not ro then FTextView.setEditable(ro);

  FTextView.undoManager.removeAllActions;
end;

procedure TCocoaMemoStrings.LoadFromFile(const FileName: string);
var
  TheStream: TFileStream;
begin
  TheStream:=TFileStream.Create(FileName,fmOpenRead or fmShareDenyWrite);
  try
    LoadFromStream(TheStream);
  finally
    TheStream.Free;
  end;
end;

procedure TCocoaMemoStrings.SaveToFile(const FileName: string);
var
  TheStream: TFileStream;
begin
  TheStream:=TFileStream.Create(FileName,fmCreate);
  try
    SaveToStream(TheStream);
  finally
    TheStream.Free;
  end;
end;

{ TCocoaWSCustomMemo }

procedure TextViewSetWordWrap(txt: NSTextView; lScroll: NSScrollView; NewWordWrap: Boolean);
var
  layoutSize: NSSize;
begin
  if NewWordWrap then
  begin
    layoutSize := lScroll.contentSize();
    layoutSize := GetNSSize(layoutSize.width, CGFloat_Max);
    txt.textContainer.setContainerSize(layoutSize);
    txt.textContainer.setWidthTracksTextView(True);
    txt.setHorizontallyResizable(false);
    txt.setAutoresizingMask(NSViewWidthSizable);
    layoutSize.height:=txt.frame.size.height;
    txt.setFrameSize(layoutSize);
  end
  else
  begin
    txt.textContainer.setWidthTracksTextView(False);
    layoutSize := GetNSSize(CGFloat_Max, CGFloat_Max);
    txt.textContainer.setContainerSize(layoutSize);
    txt.textContainer.setWidthTracksTextView(False);
    txt.setHorizontallyResizable(true);
    txt.setAutoresizingMask(0);
  end;
  txt.sizeToFit;
end;

function AlignmentLCLToCocoa(al: TAlignment): NSTextAlignment;
begin
  case al of
    taRightJustify:
      Result := NSTextAlignmentRight;
    taCenter:
      Result := NSTextAlignmentCenter;
  else
    Result:= NSTextAlignmentLeft;
  end;
end;

procedure TextViewSetAllignment(txt: NSTextView; align: TAlignment);
begin
  //todo: for bidi modes, there's "NSTextAlignmentNatural"
  txt.setAlignment( AlignmentLCLToCocoa(align) );
end;

procedure TextFieldSetAllignment(txt: NSTextField; align: TAlignment);
begin
  //todo: for bidi modes, there's "NSTextAlignmentNatural"
  txt.setAlignment( AlignmentLCLToCocoa(align) );
end;

class function TCocoaWSCustomMemo.GetTextView(AWinControl: TWinControl): TCocoaTextView;
var
  lScroll: TCocoaScrollView;
begin
  lScroll := GetScrollView(AWinControl);
  if not Assigned(lScroll) then
  begin
    Exit(nil);
  end;

  Result := TCocoaTextView(lScroll.documentView);
end;

class function TCocoaWSCustomMemo.GetScrollView(AWinControl: TWinControl): TCocoaScrollView;
begin
  if not Assigned(AWinControl) or (not AWinControl.HandleAllocated) or (AWinControl.Handle=0) then
  begin
    Exit(nil);
  end;

  Result := TCocoaScrollView(AWinControl.Handle);
end;

class function TCocoaWSCustomMemo.CreateHandle(const AWinControl: TWinControl;
  const AParams: TCreateParams):TLCLIntfHandle;
var
  txt: TCocoaTextView;
  ns: NSString;
  scr: TCocoaScrollView;
  nr:NSRect;
  r:TRect;
  layoutSize: NSSize;
  lcl: TLCLCommonCallback;
begin
  scr := TCocoaScrollView(NSView(TCocoaScrollView.alloc).lclInitWithCreateParams(AParams));

  nr.origin.x:=0;
  nr.origin.y:=0;
  nr.size.height:=0;
  nr.size.width:=AParams.Width;

  txt := TCocoaTextView.alloc.initwithframe(nr);
  txt.setAllowsUndo(true);
  // setting up a default system font (to be consistent with other widgetsets)
  txt.setFont( NSFont.systemFontOfSize( NSFont.systemFontSizeForControlSize(NSRegularControlSize) ));
  txt.setRichText(false);
  txt.setImportsGraphics(false);
  txt.setUsesRuler(false);

  // this is necessary for Ward Wrap disabled, so NSViewText
  // doesn't have a constraint to resize
  // Apple default maxsize is InitialWidth, 10000000
  // (MaxSize is also changed automatically, if NSViewText size is changed)
  txt.setMaxSize(NSMakeSize(10000000, 10000000));
  scr.setDocumentView(txt);

  scr.setHasVerticalScroller(VerticalScrollerVisible[TMemo(AWinControl).ScrollBars]);
  scr.setHasHorizontalScroller(HorizontalScrollerVisible[TMemo(AWinControl).ScrollBars]);
  scr.setAutohidesScrollers(ScrollerAutoHide[TMemo(AWinControl).ScrollBars]);
  scr.setDrawsBackground(false);

  ScrollViewSetBorderStyle(scr, TCustomMemo(AWinControl).BorderStyle);
  UpdateFocusRing(txt, TCustomMemo(AWinControl).BorderStyle);

  nr:=scr.documentVisibleRect;
  txt.setFrame(nr);
  txt.lclSetEnabled(True);

  // ToDo: This should be made selectable in the LCL
  txt.setAutomaticQuoteSubstitutionEnabled(False);
  txt.setAutomaticLinkDetectionEnabled(False);
  // macOS 10.6 version
  if txt.respondsToSelector(objcselector('setAutomaticDataDetectionEnabled:')) then
    txt.setAutomaticDataDetectionEnabled(false);
  if txt.respondsToSelector(objcselector('setAutomaticTextReplacementEnabled:')) then
    txt.setAutomaticTextReplacementEnabled(False);
  if txt.respondsToSelector(ObjCSelector('setAutomaticDashSubstitutionEnabled:')) then
    txt.setAutomaticDashSubstitutionEnabled(False);
  if txt.respondsToSelector(ObjCSelector('setAutomaticSpellingCorrectionEnabled:')) then
    txt.setAutomaticSpellingCorrectionEnabled(False);

  // defaulting to System colors
  // This makes NSTextView to be responsive to theme color change (Mojave 10.14)
  txt.setTextColor(NSColor.textColor);
  txt.setBackgroundColor(NSColor.textBackgroundColor);
  scr.setFocusRingType(NSFocusRingTypeExterior);

  lcl := TLCLCommonCallback.Create(txt, AWinControl);
  lcl.ForceReturnKeyDown := true;
  txt.callback := lcl;
  txt.setDelegate(txt);

  SetNSText(txt, AParams.Caption);

  scr.callback := txt.callback;

  TextViewSetWordWrap(txt, scr, TCustomMemo(AWinControl).WordWrap);
  TextViewSetAllignment(txt, TCustomMemo(AWinControl).Alignment);
  txt.wantReturns := TCustomMemo(AWinControl).WantReturns;
  txt.callback.SetTabSuppress(not TCustomMemo(AWinControl).WantTabs);
  Result := TLCLIntfHandle(scr);
end;

class procedure TCocoaWSCustomMemo.SetColor(const AWinControl: TWinControl);
var
  txt: TCocoaTextView;
begin
  txt := GetTextView(AWinControl);
  if not Assigned(txt) then Exit;

  if (AWinControl.Color = clDefault) or (AWinControl.Color = clWindow) or (AWinControl.Color = clBackground) then
    txt.setBackgroundColor( NSColor.textBackgroundColor )
  else
    txt.setBackgroundColor( ColorToNSColor(ColorToRGB(AWinControl.Color)));
end;

class procedure TCocoaWSCustomMemo.SetSelStart(const ACustomEdit: TCustomEdit;
  NewStart: integer);
var
  lRange: NSRange;
  txt: TCocoaTextView;
begin
  txt := GetTextView(ACustomEdit);
  if not Assigned(txt) then Exit;

  lRange := txt.selectedRange;
  lRange.location := NewStart;
  txt.setSelectedRange(lRange);
  txt.scrollRangeToVisible(lRange);
end;

class procedure TCocoaWSCustomMemo.SetSelLength(const ACustomEdit: TCustomEdit;
  NewLength: integer);
var
  lRange: NSRange;
  txt: TCocoaTextView;
begin
  txt := GetTextView(ACustomEdit);
  if not Assigned(txt) then Exit;

  lRange := txt.selectedRange;
  lRange.length := NewLength;
  txt.setSelectedRange(lRange);
end;

class procedure TCocoaWSCustomMemo.SetBorderStyle(
  const AWinControl: TWinControl; const ABorderStyle: TBorderStyle);
var
  sv: TCocoaScrollView;
begin
  sv := GetScrollView(AWinControl);
  if not Assigned(sv) then Exit;

  ScrollViewSetBorderStyle(sv, ABorderStyle);
  UpdateFocusRing(NSView(sv.documentView), ABorderStyle);
end;

class function TCocoaWSCustomMemo.GetCaretPos(const ACustomEdit: TCustomEdit): TPoint;
var
  txt: TCocoaTextView;
  lValue: NSValue;
  viewString: NSString;
  paraStart: NSUInteger = 0;
  paraEnd: NSUInteger = 0;
  contentsEnd: NSUInteger = 0;
  curLine: Integer = 0;
begin
  Result := Point(0, 0);
  txt := GetTextView(ACustomEdit);
  if not Assigned(txt) then Exit;
  lValue := NSValue(txt.selectedRanges.objectAtIndex(0));
  if lValue = nil then Exit;

  viewString := txt.string_;
  Result.X := lValue.rangeValue.location;

  // There is no simple function to do this in Cocoa :(
  while (paraEnd < viewString.length) do
  begin
    viewString.getLineStart_end_contentsEnd_forRange(@paraStart,
      @paraEnd, @contentsEnd, NSMakeRange(paraEnd, 0));

    if (lValue.rangeValue.location >= paraStart) and
       (lValue.rangeValue.location < paraEnd) then
    begin
      Break;
    end
    else
      Result.X := Result.X - (paraEnd - paraStart);

    Inc(curLine);
  end;
  Result.Y := curLine;

  {This doesn't work :/
  lineRange := viewString.lineRangeForRange(lValue.rangeValue);
  Result.X := lineRange.location;}
end;

class function TCocoaWSCustomMemo.GetSelStart(const ACustomEdit: TCustomEdit): integer;
var
  txt: TCocoaTextView;
begin
  txt := GetTextView(ACustomEdit);
  if not Assigned(txt) then
  begin
    Result:=0;
    Exit;
  end;
  Result := txt.selectedRange.location;
end;

class function TCocoaWSCustomMemo.GetSelLength(const ACustomEdit: TCustomEdit): integer;
var
  txt: TCocoaTextView;
  ns: NSArray;
begin
  txt := GetTextView(ACustomEdit);
  if not Assigned(txt) then
  begin
    Result:=0;
    Exit;
  end;
  Result := txt.selectedRange.length;
end;

class procedure TCocoaWSCustomMemo.SetAlignment(const ACustomEdit: TCustomEdit;
  const NewAlignment: TAlignment);
var
  txt: TCocoaTextView;
begin
  txt := GetTextView(ACustomEdit);
  if Assigned(txt) then
    TextViewSetAllignment(txt, NewAlignment);
end;

class function TCocoaWSCustomMemo.GetStrings(const ACustomMemo: TCustomMemo): TStrings;
var
  txt: TCocoaTextView;
begin
  txt := GetTextView(ACustomMemo);
  if Assigned(txt) then
    Result := TCocoaMemoStrings.Create(txt)
  else
    Result := nil
end;

class procedure TCocoaWSCustomMemo.AppendText(const ACustomMemo: TCustomMemo;
  const AText: string);
begin
  //todo:
end;

class procedure TCocoaWSCustomMemo.SetReadOnly(const ACustomEdit:TCustomEdit;
  NewReadOnly:boolean);
var
  txt: TCocoaTextView;
begin
  txt := GetTextView(ACustomEdit);
  if Assigned(txt) then
    txt.setEditable(not NewReadOnly);
end;

class function TCocoaWSCustomMemo.GetTextLen(const AWinControl: TWinControl;
  var ALength: Integer): Boolean;
var
  txt: TCocoaTextView;
begin
  txt := GetTextView(AWinControl);
  Result := Assigned(txt);
  if Result then
    ALength := txt.string_.lengthOfBytesUsingEncoding(NSUTF8StringEncoding);
end;

class procedure TCocoaWSCustomMemo.SetScrollbars(const ACustomMemo: TCustomMemo; const NewScrollbars: TScrollStyle);
begin
  ScrollViewSetScrollStyles(TCocoaScrollView(ACustomMemo.Handle), NewScrollbars);
end;

class procedure TCocoaWSCustomMemo.SetWantTabs(const ACustomMemo: TCustomMemo;
  const NewWantTabs: boolean);
var
  txt: TCocoaTextView;
begin
  txt := GetTextView(ACustomMemo);
  if (not Assigned(txt)) then Exit;
  txt.callback.SetTabSuppress(not NewWantTabs);
end;


class procedure TCocoaWSCustomMemo.SetWantReturns(const ACustomMemo: TCustomMemo;
  const NewWantReturns: boolean);
var
  txt: TCocoaTextView;
begin
  txt := GetTextView(ACustomMemo);
  if (not Assigned(txt)) then Exit;
  txt.wantReturns := NewWantReturns;
end;

class procedure  TCocoaWSCustomMemo.SetWordWrap(const ACustomMemo: TCustomMemo; const NewWordWrap: boolean);
var
  txt: TCocoaTextView;
  lScroll: TCocoaScrollView;
begin
  txt := GetTextView(ACustomMemo);
  lScroll := GetScrollView(ACustomMemo);
  if (not Assigned(txt)) or (not Assigned(lScroll)) then Exit;

  TextViewSetWordWrap(txt, lScroll, NewWordWrap);
end;

class procedure TCocoaWSCustomMemo.SetText(const AWinControl:TWinControl;const AText:String);
var
  txt: TCocoaTextView;
begin
  txt := GetTextView(AWinControl);
  if not Assigned(txt) then Exit;
  SetNSText(txt, LineBreaksToUnix(AText));
end;

class function TCocoaWSCustomMemo.GetText(const AWinControl: TWinControl; var AText: String): Boolean;
var
  txt: TCocoaTextView;
begin
  txt := GetTextView(AWinControl);
  Result := Assigned(txt);
  if Result then
    AText := NSStringToString(txt.string_);
end;

{ TCocoaWSCustomComboBox }

type
  TCustomComboBoxAccess = class(TCustomComboBox)
  end;

class function TCocoaWSCustomComboBox.CreateHandle(const AWinControl:TWinControl;
  const AParams:TCreateParams):TLCLIntfHandle;
var
  cmb: TCocoaComboBox;
  rocmb: TCocoaReadOnlyComboBox;
begin
  Result:=0;
  if ComboBoxIsReadOnly(TCustomComboBox(AWinControl)) then
  begin
    rocmb := NSView(TCocoaReadOnlyComboBox.alloc).lclInitWithCreateParams(AParams);
    if not Assigned(rocmb) then Exit;
    rocmb.list:=TCocoaReadOnlyComboBoxList.Create(rocmb);
    rocmb.setTarget(rocmb);
    rocmb.setAction(objcselector('comboboxAction:'));
    rocmb.selectItemAtIndex(rocmb.lastSelectedItemIndex);
    rocmb.callback:=TLCLComboboxCallback.Create(rocmb, AWinControl);
    Result:=TLCLIntfHandle(rocmb);
    rocmb.isOwnerDrawn := ComboBoxIsOwnerDrawn(TCustomComboBox(AWinControl).Style);
    rocmb.isOwnerMeasure := ComboBoxIsVariable(TCustomComboBox(AWinControl).Style);
  end
  else
  begin
    cmb := NSView(TCocoaComboBox.alloc).lclInitWithCreateParams(AParams);
    if not Assigned(cmb) then Exit;
    //cmb.setCell(TCocoaComboBoxCell.alloc.initTextCell(NSString.string_));
    cmb.list:=TCocoaEditComboBoxList.Create(cmb);
    cmb.setUsesDataSource(true);
    cmb.setDataSource(cmb);
    cmb.setDelegate(cmb);
    cmb.setStringValue(NSStringUtf8(AParams.Caption));
    cmb.callback:=TLCLComboboxCallback.Create(cmb, AWinControl);
    if (cmb.respondsToSelector(ObjCSelector('cell'))) and Assigned(cmb.cell) then
      NSTextFieldCell(cmb.cell).setUsesSingleLineMode(true);
    // default BorderStyle for TComboBox is bsNone! and it looks ugly!
    // also, Win32 doesn't suppot borderstyle for TComboBox at all.
    // to be tested and considered
    //ComboBoxSetBorderStyle(cmb, TCustomComboBoxAccess(AWinControl).BorderStyle);
    Result:=TLCLIntfHandle(cmb);
  end;
  //todo: 26 pixels is the height of 'normal' combobox. The value is taken from the Interface Builder!
  //      use the correct way to set the size constraints
  AWinControl.Constraints.SetInterfaceConstraints(0,COMBOBOX_MINI_HEIGHT,0,COMBOBOX_REG_HEIGHT);
end;

class procedure TCocoaWSCustomComboBox.SetBorderStyle(
  const AWinControl: TWinControl; const ABorderStyle: TBorderStyle);
var
  ACustomComboBox : TCustomComboBox;
begin
  if not Assigned(AWinControl) or not AWinControl.HandleAllocated then Exit;
  ACustomComboBox:= TCustomComboBox(AWinControl);

  if ComboBoxStyleIsReadOnly(ACustomComboBox.Style) then
    //Result := TCocoaReadOnlyComboBox(ACustomComboBox.Handle).indexOfSelectedItem
  else
  begin
    //todo: consider the use of border style
    //ComboBoxSetBorderStyle(TCocoaComboBox(ACustomComboBox.Handle), ABorderStyle);
  end;

end;

class function TCocoaWSCustomComboBox.GetDroppedDown(
  const ACustomComboBox: TCustomComboBox): Boolean;
var
  cb  : ICommonCallback;
  obj : TObject;
begin
  Result:=false;
  if (not Assigned(ACustomComboBox)) or (not ACustomComboBox.HandleAllocated) then
    Exit;

  cb := NSView(ACustomComboBox.Handle).lclGetCallback;
  if Assigned(cb) then
  begin
    obj := cb.GetCallbackObject;
    if (obj is TLCLComboboxCallback) then
      Result := TLCLComboboxCallback(obj).isShowPopup;
  end;

end;

class function TCocoaWSCustomComboBox.GetItemIndex(const ACustomComboBox:
  TCustomComboBox):integer;
var
  idx : NSInteger;
begin
  if (not Assigned(ACustomComboBox)) or (not ACustomComboBox.HandleAllocated) then
  begin
    Result:=-1;
    Exit;
  end;

  if ComboBoxStyleIsReadOnly(ACustomComboBox.Style) then
    idx := TCocoaReadOnlyComboBox(ACustomComboBox.Handle).indexOfSelectedItem
  else
    idx := TCocoaComboBox(ACustomComboBox.Handle).indexOfSelectedItem;
  if idx = NSNotFound then
    Result := -1
  else
    Result := Integer(idx);
end;

class procedure TCocoaWSCustomComboBox.SetItemIndex(const ACustomComboBox:
  TCustomComboBox;NewIndex:integer);
var
  rocmb: TCocoaReadOnlyComboBox;
begin
  if (not Assigned(ACustomComboBox)) or (not ACustomComboBox.HandleAllocated) then
    Exit;

  if ComboBoxStyleIsReadOnly(ACustomComboBox.Style) then
  begin
    rocmb := TCocoaReadOnlyComboBox(ACustomComboBox.Handle);
    rocmb.lastSelectedItemIndex := NewIndex;
    rocmb.selectItemAtIndex(NewIndex);
  end
  else
    TCocoaComboBox(ACustomComboBox.Handle).selectItemAtIndex(NewIndex);
end;

class procedure TCocoaWSCustomComboBox.SetStyle(
  const ACustomComboBox: TCustomComboBox; NewStyle: TComboBoxStyle);
begin
  if (not Assigned(ACustomComboBox)) or (not ACustomComboBox.HandleAllocated) then
    Exit;
  RecreateWnd(ACustomComboBox);
end;

class procedure TCocoaWSCustomComboBox.SetReadOnly(
  const ACustomComboBox: TCustomComboBox; NewReadOnly: boolean);
var
  box : NSComboBox;
begin
  if (not Assigned(ACustomComboBox)) or (not ACustomComboBox.HandleAllocated) then
    Exit;
  if not (NSObject(ACustomComboBox.Handle).isKindOfClass(NSComboBox)) then Exit;
  box := NSComboBox(ACustomComboBox.Handle);
  box.setEditable(not NewReadOnly);
  {$ifdef BOOLFIX}
  box.setSelectable_(1);
  {$ELSE}
  box.setSelectable(true);
  {$endif}
end;

class procedure TCocoaWSCustomComboBox.SetDropDownCount(const ACustomComboBox:
  TCustomComboBox;NewCount:Integer);
begin
  if (not Assigned(ACustomComboBox)) or (not ACustomComboBox.HandleAllocated) then
    Exit;

  if ComboBoxStyleIsReadOnly(ACustomComboBox.Style) then Exit;
  TCocoaComboBox(ACustomComboBox.Handle).setNumberOfVisibleItems(NewCount);
end;

class function TCocoaWSCustomComboBox.GetItems(const ACustomComboBox: TCustomComboBox): TStrings;
begin
  if (not Assigned(ACustomComboBox)) or (not ACustomComboBox.HandleAllocated) then
  begin
    Result:=nil;
    Exit;
  end;

  if ComboBoxStyleIsReadOnly(ACustomComboBox.Style) then
    Result:=TCocoaReadOnlyComboBox(ACustomComboBox.Handle).list
  else
    Result:=TCocoaComboBox(ACustomComboBox.Handle).list;
end;

class function TCocoaWSCustomComboBox.GetItemHeight(const ACustomComboBox:
  TCustomComboBox):Integer;
begin
  if (not Assigned(ACustomComboBox)) or (not ACustomComboBox.HandleAllocated) then
  begin
    Result:=0;
    Exit;
  end;

  if ComboBoxStyleIsReadOnly(ACustomComboBox.Style) then
    Result := 26 // ToDo
  else
    Result:=Round(TCocoaComboBox(ACustomComboBox.Handle).itemHeight);
end;

class procedure TCocoaWSCustomComboBox.SetItemHeight(const ACustomComboBox:
  TCustomComboBox;const AItemHeight:Integer);
begin
  if (not Assigned(ACustomComboBox)) or (not ACustomComboBox.HandleAllocated) then
    Exit;

  if ComboBoxStyleIsReadOnly(ACustomComboBox.Style) then
    Exit // ToDo
  else
    TCocoaComboBox(ACustomComboBox.Handle).setItemHeight(AItemHeight);
end;

class procedure TCocoaWSCustomComboBox.GetPreferredSize(
  const AWinControl: TWinControl; var PreferredWidth, PreferredHeight: integer;
  WithThemeSpace: Boolean);
begin
  // do not override PreferredWidth and Height
  // see todo at TCocoaWSWinControl.GetPreferredSize
  // once it's resolved, TCocoaWSCustomComboBox.GetPreferredSize could be removed
end;

class procedure TCocoaWSCustomComboBox.SetText(const AWinControl: TWinControl;
  const AText: String);
begin
  if (AWinControl.HandleAllocated) then
    ControlSetTextWithChangeEvent(NSControl(AWinControl.Handle), AText);
end;

class procedure TCocoaWSCustomComboBox.SetTextHint(
  const ACustomComboBox: TCustomComboBox; const ATextHint: string);
begin
  if NSAppKitVersionNumber <= NSAppKitVersionNumber10_10 then
    Exit;
  if (not Assigned(ACustomComboBox)) or (not ACustomComboBox.HandleAllocated) then
    Exit;
  ObjSetTextHint(NSObject(ACustomComboBox.Handle), ATextHint);
end;

{ TCocoaWSToggleBox }

class function TCocoaWSToggleBox.CreateHandle(const AWinControl:TWinControl;
  const AParams:TCreateParams):TLCLIntfHandle;
var
  btn: NSButton;
  cl: NSButtonCell;
begin
  btn := AllocButton(AWinControl, TLCLCheckBoxCallback, AParams, CocoaToggleBezel, CocoaToggleType);
  cl := NSButtonCell(NSButton(btn).cell);
  cl.setShowsStateBy(cl.showsStateBy or NSContentsCellMask);
  Result := TLCLIntfHandle(btn);
end;

{ TCocoaWSScrollBar }

class function TCocoaWSScrollBar.CreateHandle(const AWinControl:TWinControl;
  const AParams:TCreateParams):TLCLIntfHandle;
var
  scr : TCocoaScrollBar;
  prm : TCreateParams;
const
  ScrollBase = 15; // the shorter size of the scroller. There's a NSScroller class method for that
begin
  prm := AParams;
  // forcing the initial size to follow the designated kind of the scroll
  if (TCustomScrollBar(AWinControl).Kind = sbVertical) then begin
    prm.Width:=ScrollBase;
    prm.Height:=ScrollBase*4;
  end else
  begin
    prm.Width:=ScrollBase*4;
    prm.Height:=ScrollBase;
  end;

  scr:=NSView(TCocoaScrollBar.alloc).lclInitWithCreateParams(prm);
  scr.callback:=TLCLCommonCallback.Create(scr, AWinControl);

  // OnChange (scrolling) event handling
  scr.setTarget(scr);
  scr.setAction(objcselector('actionScrolling:'));

  scr.minInt:=TCustomScrollBar(AWinControl).Min;
  scr.maxInt:=TCustomScrollBar(AWinControl).Max;
  scr.pageInt:=TCustomScrollBar(AWinControl).PageSize;
  scr.largeInc:=abs(TCustomScrollBar(AWinControl).LargeChange);
  scr.smallInc:=abs(TCustomScrollBar(AWinControl).SmallChange);
  if scr.largeInc=0 then scr.largeInc:=1;
  if scr.smallInc=0 then scr.smallInc:=1;

  Result:=TLCLIntfHandle(scr);

  scr.lclSetFrame( Bounds(AParams.X, AParams.Y, AParams.Width, AParams.Height));
end;

// vertical/horizontal in Cocoa is set automatically according to
// the geometry of the scrollbar, it cannot be forced to an unusual value
class procedure TCocoaWSScrollBar.SetKind(const AScrollBar: TCustomScrollBar; const AIsHorizontal: Boolean);
begin
  // the scroll type can be changed when creating a scroll.
  // since the size got changed, we have to create the handle
  RecreateWnd(AScrollBar);
end;

class procedure TCocoaWSScrollBar.SetParams(const AScrollBar:TCustomScrollBar);
var
  lScroller: TCocoaScrollBar;
  sz : integer;
begin
  if not Assigned(AScrollBar) then Exit;
  lScroller := TCocoaScrollBar(AScrollBar.Handle);
  if (lScroller = nil) then Exit;
  sz:=AScrollBar.Max - AScrollBar.PageSize;
  if sz > 0 then
  begin
    lScroller.setDoubleValue( AScrollBar.Position / sz );
    lScroller.setKnobProportion( AScrollBar.PageSize / AScrollBar.Max );
  end;
end;

{ TCocoaWSCustomGroupBox }

class function TCocoaWSCustomGroupBox.CreateHandle(const AWinControl: TWinControl;
  const AParams: TCreateParams): TLCLIntfHandle;
var
  box: TCocoaGroupBox;
  cap: NSString;
  lGroupBoxContents: TCocoaCustomControl;
  ns: NSRect;
  //str: string;
begin
  box := NSView(TCocoaGroupBox.alloc).lclInitWithCreateParams(AParams);
  if Assigned(box) then
  begin
    box.callback := TLCLCommonCallback.Create(box, AWinControl);
    TLCLCommonCallback(box.callback.GetCallbackObject).BlockCocoaUpDown := true;
    cap := NSStringUTF8(AParams.Caption);
    box.setTitle(cap);
    cap.release;

    // set a content view in order to be able to customize drawing for labels/color
    ns := GetNSRect(AParams.X, AParams.Y, AParams.Width, AParams.Height);
    lGroupBoxContents := TCocoaCustomControl(TCocoaCustomControl.alloc.initWithFrame(ns));
    lGroupBoxContents.callback := box.callback; //TLCLCustomControlCallback.Create(lGroupBoxContents, AWinControl);
    //str := Format('%X=%X', [PtrUInt(box.callback), PtrUInt(lGroupBoxContents.callback)]);
    lGroupBoxContents.autorelease;
    box.setContentView(lGroupBoxContents);
  end;
  Result := TLCLIntfHandle(box);
end;

class function TCocoaWSCustomGroupBox.GetText(const AWinControl: TWinControl; var AText: String): Boolean;
var
  box: TCocoaGroupBox;
begin
  box := TCocoaGroupBox(AWinControl.Handle);
  Result:=Assigned(box);
  if Result then
    AText := NSStringToString(box.title);
end;

class procedure TCocoaWSCustomGroupBox.SetText(const AWinControl: TWinControl; const AText: String);
var
  box: TCocoaGroupBox;
begin
  box := TCocoaGroupBox(AWinControl.Handle);
  box.setTitle(ControlTitleToNSStr(AText));
end;

class procedure TCocoaWSCustomGroupBox.SetFont(const AWinControl: TWinControl;
  const AFont: TFont);
var
  box: TCocoaGroupBox;
  fn : NSFont;
begin
  if not AWinControl.HandleAllocated then Exit;
  box := TCocoaGroupBox(AWinControl.Handle);
  fn := TCocoaFont(AFont.Reference.Handle).Font;
  if AFont.Size = 0 then
    fn := NSFont.fontWithDescriptor_size(fn.fontDescriptor, NSFont.smallSystemFontSize);
  box.setTitleFont(fn);
end;

{ TCocoaWSCustomListBox }

function GetListBox(AWinControl: TWinControl): TCocoaTableListView;
begin
  if not Assigned(AWinControl) or (AWinControl.Handle=0) then
    Result := nil
  else
    Result := TCocoaTableListView(TCocoaScrollView(AWinControl.Handle).documentView);
end;

function GetListBoxWithCb(AWinControl: TWinControl; out cb: TLCLListBoxCallback): TCocoaTableListView;
begin
  Result := GetListBox(AWinControl);
  if not Assigned(Result) then
    cb := nil
  else
    cb := TLCLListBoxCallback(Result.lclGetCallback.GetCallbackObject)
end;


procedure ListBoxSetStyle(list: TCocoaTableListView; AStyle: TListBoxStyle);
begin
  if not Assigned(list) then Exit;
  list.isOwnerDraw := AStyle in [lbOwnerDrawFixed, lbOwnerDrawVariable];
  list.isDynamicRowHeight := AStyle = lbOwnerDrawVariable;
  //todo: if flag isCustomRowHeight changes in runtime
  //      noteHeightOfRowsWithIndexesChanged, should be sent to listview
end;

class procedure TCocoaWSCustomListBox.DragStart(
  const ACustomListBox: TCustomListBox);
var
  view: TCocoaTableListView;
  cb : TLCLListBoxCallback;
begin
  view := GetListBoxWithCb(ACustomListBox, cb);
  if not Assigned(view) or not Assigned(cb) then Exit;
  cb.BlockCocoaMouseMove:=true;
end;

class function TCocoaWSCustomListBox.CreateHandle(const AWinControl:TWinControl;
  const AParams:TCreateParams):TLCLIntfHandle;
var
  list    : TCocoaTableListView;
  scroll  : TCocoaScrollView;
  lclListBox: TCustomListBox absolute AWinControl;
  cb  : TLCLListBoxCallback;
begin
  list := AllocCocoaTableListView.lclInitWithCreateParams(AParams);
  if not Assigned(list) then
  begin
    Result := 0;
    Exit;
  end;
  cb := TLCLListBoxCallback.CreateWithView(list, AWinControl);
  list.callback := cb;
  list.addTableColumn(NSTableColumn.alloc.init);
  list.setHeaderView(nil);
  list.setDataSource(list);
  list.setDelegate(list);
  list.setAllowsMultipleSelection(lclListBox.MultiSelect);
  list.readOnly := true;
  // LCL ItemHeight for TListBox can only be set during Recreation of Handle
  if TCustomListBox(AWinControl).ItemHeight>0 then
  begin
    // Cocoa default is 16.
    // Note that it might be different of Retina monitors
    list.CustomRowHeight := TCustomListBox(AWinControl).ItemHeight;
    list.setRowHeight(list.CustomRowHeight);
  end;

  ListBoxSetStyle(list, TCustomListBox(AWinControl).Style);

  scroll := EmbedInScrollView(list);
  if not Assigned(scroll) then
  begin
    list.dealloc;
    Result := 0;
    Exit;
  end;
  cb.HandleFrame := scroll;
  scroll.callback := list.callback;
  scroll.setHasVerticalScroller(true);
  scroll.setAutohidesScrollers(true);
  ScrollViewSetBorderStyle(scroll, lclListBox.BorderStyle);
  UpdateFocusRing(list, lclListBox.BorderStyle);

  Result := TLCLIntfHandle(scroll);
end;

class function TCocoaWSCustomListBox.GetIndexAtXY(const ACustomListBox: TCustomListBox; X, Y: integer): integer;
var
  list: TCocoaTableListView;
  lPoint: NSPoint;
begin
  list := GetListBox(ACustomListBox);
  if not Assigned(list) then
  begin
    Result:=-1;
    Exit();
  end;

  Result := LCLCoordToRow(list, x,y);
end;

class function TCocoaWSCustomListBox.GetItemRect(const ACustomListBox: TCustomListBox; Index: integer; var ARect: TRect): boolean;
var
  view: TCocoaTableListView;
  r:NSRect;
begin
  Result := False;

  view := GetListBox(ACustomListBox);
  if not Assigned(view) then Exit(False);
  Result := LCLGetItemRect(view, Index, 0, ARect);
end;

class function TCocoaWSCustomListBox.GetItemIndex(const ACustomListBox: TCustomListBox): integer;
var
  view: TCocoaTableListView;
  indexset: NSIndexSet;
begin
  view:=GetListBox(ACustomListBox);
  if not Assigned(view) then Exit(-1);

  indexset:=view.selectedRowIndexes();
  if indexset.count = 0 then
    Result := -1
  else
    Result := indexset.firstIndex;
end;

class function TCocoaWSCustomListBox.GetSelCount(const ACustomListBox: TCustomListBox): integer;
var
  view: TCocoaTableListView;
  selection: NSIndexSet;
begin
  view := GetListBox(ACustomListBox);
  if not Assigned(view) then Exit(0);
  selection := view.selectedRowIndexes();
  Result := selection.count();
end;


class function TCocoaWSCustomListBox.GetSelected(const ACustomListBox: TCustomListBox; const AIndex: integer): boolean;
var
  view: TCocoaTableListView;
  selection: NSIndexSet;
begin
  view := GetListBox(ACustomListBox);
  if not Assigned(view) then Exit(False);
  if AIndex < 0 then Exit(False);
  selection := view.selectedRowIndexes();
  Result := selection.containsIndex(AIndex);
end;

class function TCocoaWSCustomListBox.GetStrings(const ACustomListBox: TCustomListBox):TStrings;
var
  view: TCocoaTableListView;
  cb : TLCLListBoxCallback;
begin
  view := GetListBoxWithCb(ACustomListBox, cb);
  if not Assigned(view) then Exit(nil);
  Result := cb.strings;
end;

class function TCocoaWSCustomListBox.GetTopIndex(const ACustomListBox: TCustomListBox): integer;
var
  view: TCocoaTableListView;
begin
  view := GetListBox(ACustomListBox);
  if not Assigned(view) then Exit(-1);
  Result := LCLGetTopRow(view);
end;

class procedure TCocoaWSCustomListBox.SelectItem(const ACustomListBox: TCustomListBox; AIndex: integer; ASelected: boolean);
var
  list: TCocoaTableListView;
begin
  list := GetListBox(ACustomListBox);
  if not Assigned(list) then Exit();
  if ASelected then
  begin
    list.selectRowIndexes_byExtendingSelection(NSIndexSet.indexSetWithIndex(AIndex), True)
  end
  else
    list.deselectRow(AIndex);
end;

class procedure TCocoaWSCustomListBox.SetBorderStyle(
  const AWinControl: TWinControl; const ABorderStyle: TBorderStyle);
var
  list: TCocoaTableListView;
begin
  list := GetListBox(AWinControl);
  if not Assigned(list) then Exit;

  ScrollViewSetBorderStyle(list.enclosingScrollView, ABorderStyle);
  UpdateFocusRing(list, ABorderStyle);
end;

class procedure TCocoaWSCustomListBox.SetItemIndex(const ACustomListBox: TCustomListBox; const AIndex: integer);
var
  list: TCocoaTableListView;
begin
  list := GetListBox(ACustomListBox);
  if not Assigned(list) then Exit();

  if (AIndex < 0) then
    list.deselectAll(nil)
  else
  begin
    list.selectRowIndexes_byExtendingSelection(NSIndexSet.indexSetWithIndex(AIndex), false);
    list.scrollRowToVisible(AIndex);
  end;
end;

class procedure TCocoaWSCustomListBox.SetSelectionMode(const ACustomListBox: TCustomListBox; const AExtendedSelect, AMultiSelect: boolean);
var
  list: TCocoaTableListView;
begin
  list := GetListBox(ACustomListBox);
  if not Assigned(list) then Exit();
  list.setAllowsMultipleSelection(AMultiSelect);
end;

class procedure TCocoaWSCustomListBox.SetStyle(const ACustomListBox: TCustomListBox);
var
  view: TCocoaTableListView;
begin
  view := GetListBox(ACustomListBox);
  ListBoxSetStyle(view, TCustomListBox(ACustomListBox).Style);
  view.setNeedsDisplay_(true);
end;

class procedure TCocoaWSCustomListBox.SetTopIndex(const ACustomListBox: TCustomListBox; const NewTopIndex: integer);
var
  view: TCocoaTableListView;
begin
  view := GetListBox(ACustomListBox);
  if not Assigned(view) then Exit();
  view.scrollRowToVisible(NewTopIndex);
end;

procedure ControlSetTextWithChangeEvent(ctrl: NSControl; const text: string);
var
  cb: ICommonCallBack;
begin
  SetNSControlValue(ctrl, text);
  cb := ctrl.lclGetcallback;
  if Assigned(cb) then // cb.SendOnChange;
    cb.SendOnTextChanged;
end;

end.


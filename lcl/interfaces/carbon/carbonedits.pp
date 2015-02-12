{                 --------------------------------------------
                  carbonedits.pp  -  Carbon edit-like controls
                  --------------------------------------------

 *****************************************************************************
  This file is part of the Lazarus Component Library (LCL)

  See the file COPYING.modifiedLGPL.txt, included in this distribution,
  for details about the license.
 *****************************************************************************
}
unit CarbonEdits;

{$mode objfpc}{$H+}

interface

// defines
{$I carbondefines.inc}

uses
 // rtl+ftl
  Classes, SysUtils,
 // carbon bindings
  MacOSAll,
 // LCL
  LMessages, LCLMessageGlue, LCLProc, LCLType, Graphics, Controls, StdCtrls, ExtCtrls,
  Spin, LazUTF8,
 // widgetset
  WSLCLClasses,
 // LCL Carbon
  CarbonDef, CarbonPrivate, CarbonGDIObjects,
  CarbonProc, CarbonDbgConsts, CarbonUtils;
  
type

  { TCarbonControlWithEdit }

  TCarbonControlWithEdit = class(TCarbonControl)
  private
    FMaxLength: Integer;
  protected
    procedure LimitTextLength;
    procedure AdaptCharCase;
    function GetEditPart: ControlPartCode; virtual;
    procedure RegisterEvents; override;
  public
    procedure TextDidChange; virtual;
    procedure AllowMenuProcess(MenuHotKey: AnsiChar; State: TShiftState; var AllowMenu: Boolean); override;
  public
    function GetPreferredSize: TPoint; override;

    function GetSelStart(var ASelStart: Integer): Boolean; virtual;
    function GetSelLength(var ASelLength: Integer): Boolean; virtual;
    function SetSelStart(ASelStart: Integer): Boolean; virtual;
    function SetSelLength(ASelLength: Integer): Boolean; virtual;

    function GetText(var S: String): Boolean; override;
    function SetText(const S: String): Boolean; override;
  public
    property MaxLength: Integer read FMaxLength write FMaxLength;
    procedure SetReadOnly(AReadOnly: Boolean); virtual;
  end;

  { TCarbonComboBox }

  TCarbonComboBox = class(TCarbonControlWithEdit)
  private
    FItemIndex: Integer;
    FReadOnly: Boolean;
    FPopupMenu: MenuRef;
    FTimer: TTimer;
    FLastDroppedDown: Boolean;
    procedure DropDownTimer(Sender: TObject);
    // there is no drop down nor close up event in Carbon, we must check it with timer
  protected
    procedure RegisterEvents; override;
    procedure CreateWidget(const AParams: TCreateParams); override;
    procedure DestroyWidget; override;
    function GetEditPart: ControlPartCode; override;
    function GetPopupButtonMenu: MenuRef;
  public
    class function GetValidEvents: TCarbonControlEvents; override;
    procedure ListItemSelected(AIndex: Integer); virtual;
    procedure ValueChanged; override;
    procedure FocusSet; override;
    procedure TextDidChange; override;
    procedure BoundsChanged; override;
  public
    function GetText(var S: String): Boolean; override;
    function SetBounds(const ARect: TRect): Boolean; override;
    procedure SetReadOnly(AReadOnly: Boolean); override;
    
    function GetItemIndex: Integer;
    function SetItemIndex(AIndex: Integer): Boolean;
    
    procedure Insert(AIndex: Integer; const S: String);
    procedure Remove(AIndex: Integer);
    
    function DropDown(ADropDown: Boolean): Boolean;
    function IsDroppedDown: Boolean;
  end;
  
  { TCarbonCustomEdit }

  TCarbonCustomEdit = class(TCarbonControlWithEdit)
  public
    function GetCanUndo: Boolean; virtual;
    procedure CopyToClip; virtual;
    procedure CutToClip; virtual;
    procedure PasteFromClip; virtual;
    procedure UndoClip; virtual;
    procedure SetPasswordChar(AChar: Char); virtual; abstract;
    function FilterKeyPress({%H-}SysKey: Boolean; const Char: TUTF8Char): Boolean; override;
    function GetCaretPos: TPoint; virtual;
  end;
  
  { TCarbonSpinEdit }

  TCarbonSpinEdit = class(TCarbonCustomEdit)
  private
    FUpDown: ControlRef;
    FValue: Double;
    FMin: Double;
    FMax: Double;
    FIncrement: Double;
    FDecimalPlaces: Integer;
    function UpDownThemeWidth: Integer;
    function FocusRectThemeOutset: Integer;
    function GetEditBounds(const ARect: HIRect): HIRect;
    function GetUpDownBounds(const ARect: HIRect): HIRect;
  protected
    procedure CreateWidget(const AParams: TCreateParams); override;
    procedure DestroyWidget; override;
    function GetFrame(Index: Integer): ControlRef; override;
    function GetFrameBounds(var ARect: TRect): Boolean; override;
  public
    class function GetFrameCount: Integer; override;
    class function GetValidEvents: TCarbonControlEvents; override;
    procedure TextDidChange; override;
    procedure DoAction(AControlPart: ControlPartCode); override;
    function SetBounds(const ARect: TRect): Boolean; override;
    procedure SetPasswordChar({%H-}AChar: Char); override;
    function SetText(const S: String): Boolean; override;
  public
    procedure UpdateControl;
    property Value: Double read FValue;
  end;

  { TCarbonEdit }

  TCarbonEdit = class(TCarbonCustomEdit)
  private
    FIsPassword   : Boolean;

    //   Native Carbon edit's bounds are changing "internal edit" control (not the frame)  //
    // for this reason EditExtra* constants have been introduced.                          //
    // So the bounds of the frame a changed (for LCL compatibility);                       //
    //   Howevr, GetFrameBounds cannot return correct value, if Bounds of the edit         //
    // is smaller than EditExtraLeft + EditExtraRight, or EditExtraTop+EditExtraBottom     //
    // Incorrect returned bounds is causes endless loop in LCL processing.                 //
    // For this reason "TooSmall" flag is introduced to return smaller size of the control //
    FTooSmall     : Boolean;
    FSmallBounds  : TRect;
  protected
    procedure CreateWidget(const AParams: TCreateParams); override;
    function GetFrameBounds(var r: TRect): Boolean; override;    
  public
    procedure BoundsChanged; override;
  public
    function GetText(var S: String): Boolean; override;
    function SetText(const S: String): Boolean; override;
    function GetPreferredSize: TPoint; override;
    procedure SetPasswordChar(AChar: Char); override;
    function SetBounds(const ARect: TRect): Boolean; override;
  end;

  { TCarbonMemo }

  TCarbonMemo = class(TCarbonCustomEdit)
  private
    FScrollView: HIViewRef;
    FScrollBars: TScrollStyle;
    FDrawBorder: Boolean;
    FBorder: HIViewRef;
    procedure SetScrollBars(const AValue: TScrollStyle);
  protected
    function GetFrame({%H-}Index: Integer): ControlRef; override;
    procedure CreateWidget(const AParams: TCreateParams); override;
    procedure DestroyWidget; override;
    procedure GetLineOffset(AIndex: Integer; out AStart, AEnd: TXNOffset);
    function GetCreationOptions: TXNFrameOptions; virtual;
    function GetTXNSelection(var iStart, iEnd: Integer): Boolean;
    function SetTXNSelection(iStart, iEnd: Integer): Boolean;
    procedure RegisterEvents; override;
  public
    procedure Invalidate(Rect: PRect = nil); override;
    procedure BoundsChanged; override;
    procedure AllowMenuProcess({%H-}MenuHotKey: AnsiChar; {%H-}State: TShiftState; var AllowMenu: Boolean); override;
    procedure TextDidChange; override;
    function GetTextObject: TXNObject;
    function FilterKeyPress({%H-}SysKey: Boolean; const {%H-}Char: TUTF8Char): Boolean; override;
    procedure ProcessKeyEvent(const msg: TLMKey); override;
    
    function SetTXNControl(Tag: TXNControlTag; const Data: TXNControlData): Boolean;
  public
    function GetSelStart(var ASelStart: Integer): Boolean; override;
    function GetSelLength(var ASelLength: Integer): Boolean; override;
    function SetSelStart(ASelStart: Integer): Boolean; override;
    function SetSelLength(ASelLength: Integer): Boolean; override;

    procedure SetAlignment(AAlignment: TAlignment);
    procedure SetColor(const AColor: TColor); override;
    procedure SetFont(const AFont: TFont); override;
    procedure SetPasswordChar(AChar: Char); override;
    procedure SetReadOnly(AReadOnly: Boolean); override;
    procedure SetWordWrap(AWordWrap: Boolean); virtual;
    function SetText(const S: String): Boolean; override;
    procedure SetBorderVisible(ABorderVisbile: Boolean); virtual;

    function SetBounds(const ARect: TRect): Boolean; override;
  public
    function GetLineCount: Integer;
    function GetLine(AIndex: Integer): String;
    procedure DeleteLine(AIndex: Integer);
    procedure InsertLine(AIndex: Integer; const S: String);
    function GetCaretPos: TPoint; override;
  public
    property ScrollBars: TScrollStyle read FScrollBars write SetScrollBars;
    property Border: HIViewRef read FBorder;
    property ScrollView: HIViewRef read FScrollView;
  end;

implementation

// Edit's frame bounds cannot be received or set directly by using HIViewGetFrame/HIViewSetFrame
// http://lists.apple.com/archives/carbon-dev/2009/Jul/msg00044.html
// Region can be used, but constants are used instead
                                                      
const
  EditExtraTop     = 3; 
  EditExtraBottom  = 3;
  EditExtraLeft    = 3;
  EditExtraRight   = 3;
  
{ TCarbonControlWithEdit }

{------------------------------------------------------------------------------
  Name: CarbonTextField_DidChange
  Handles text change
 ------------------------------------------------------------------------------}
function CarbonTextField_DidChange(ANextHandler: EventHandlerCallRef;
  AEvent: EventRef;
  AWidget: TCarbonWidget): OSStatus; {$IFDEF darwin}mwpascal;{$ENDIF}
begin
  {$IFDEF VerboseControlEvent}
    DebugLn('CarbonTextField_DidChange: ', DbgSName(AWidget.LCLObject));
  {$ENDIF}

  Result := CallNextEventHandler(ANextHandler, AEvent);

  (AWidget as TCarbonControlWithEdit).TextDidChange;
end;

{------------------------------------------------------------------------------
  Method:  TCarbonControlWithEdit.LimitTextLength

  Limits the text length to maximum length
 ------------------------------------------------------------------------------}
procedure TCarbonControlWithEdit.LimitTextLength;
var
  S: String;
  R: Boolean;
  SelStart: Integer;
begin
  if MaxLength > 0 then
  begin
    if GetText(S{%H-}) then
      if LazUTF8.UTF8Length(S) > MaxLength then
      begin
        R := GetSelStart(SelStart{%H-});
        S := LazUTF8.UTF8Copy(S, 1, MaxLength);
        if SetText(S) then
          if R then SetSelStart(SelStart);
      end;
  end;
end;

{------------------------------------------------------------------------------
  Method:  TCarbonControlWithEdit.AdaptCharCase

  Change text char case
 ------------------------------------------------------------------------------}
procedure TCarbonControlWithEdit.AdaptCharCase;
begin
  // TODO
end;

{------------------------------------------------------------------------------
  Method:  TCarbonControlWithEdit.GetEditPart
  Returns: Control part code of edit control
 ------------------------------------------------------------------------------}
function TCarbonControlWithEdit.GetEditPart: ControlPartCode;
begin
  Result := kControlEntireControl;
end;

{------------------------------------------------------------------------------
  Method:  TCarbonControlWithEdit.RegisterEvents

  Registers event handlers for control with edit
 ------------------------------------------------------------------------------}
procedure TCarbonControlWithEdit.RegisterEvents;
var
  TmpSpec: EventTypeSpec;
begin
  inherited RegisterEvents;
  
  if GetEditPart >= 0 then
  begin
    TmpSpec := MakeEventSpec(kEventClassTextField, kEventTextDidChange);
    InstallControlEventHandler(Widget,
      RegisterEventHandler(@CarbonTextField_DidChange),
      1, @TmpSpec, Pointer(Self), nil);
  end;
end;

procedure TCarbonControlWithEdit.AllowMenuProcess(MenuHotKey: AnsiChar;
  State: TShiftState; var AllowMenu: Boolean);
{ These characters seems to be hardcoded by apple to Edit controls. }
{ It doesn't seem possible to change the hotkeys. Even if there're  }
{ some menu available with the same hotkey, still focused control }
{ has a priority over the menu  }
const
  MacHotChars = ['a','A','c','C','v','V','x','X','z','Z'];
begin
  AllowMenu:=not ( (State = [ssMeta]) and (MenuHotKey in MacHotChars)) ;
end;

{------------------------------------------------------------------------------
  Method:  TCarbonControlWithEdit.TextDidChange

  Text changed event handler
 ------------------------------------------------------------------------------}
procedure TCarbonControlWithEdit.TextDidChange;
var
  Msg: TLMessage;
begin
  // limit the text according to MaxLength
  LimitTextLength;

  // set char case TODO
  AdaptCharCase;

  FillChar(Msg{%H-}, SizeOf(Msg), 0);
  Msg.Msg := CM_TEXTCHANGED;
  DeliverMessage(LCLObject, Msg);
end;

{------------------------------------------------------------------------------
  Method:  TCarbonControlWithEdit.GetPreferredSize
  Returns: The preffered size of control for autosizing or (0, 0)
 ------------------------------------------------------------------------------}
function TCarbonControlWithEdit.GetPreferredSize: TPoint;
begin
  Result := inherited GetPreferredSize;
  Result.X := 0; // do not autosize width of edit like controls
end;

{------------------------------------------------------------------------------
  Method:  TCarbonControlWithEdit.GetSelStart
  Params:  ASelStart - Selection start
  Returns: If the function suceeds

  Gets the selection start from the edit part of control
 ------------------------------------------------------------------------------}
function TCarbonControlWithEdit.GetSelStart(var ASelStart: Integer): Boolean;
var
  SelData: ControlEditTextSelectionRec;
begin
  Result := False;
  ASelStart := 0;
  if GetEditPart < 0 then Exit;
  
  if OSError(
    GetControlData(ControlRef(Widget), GetEditPart, kControlEditTextSelectionTag,
      SizeOf(ControlEditTextSelectionRec), @SelData, nil),
    Self, 'GetSelStart', SGetData) then Exit;

  ASelStart := SelData.SelStart;
  Result := True;
end;

{------------------------------------------------------------------------------
  Method:  TCarbonControlWithEdit.GetSelLength
  Params:  ASelLength - Selection length
  Returns: If the function suceeds

  Gets the selection length from the edit part of control
 ------------------------------------------------------------------------------}
function TCarbonControlWithEdit.GetSelLength(var ASelLength: Integer): Boolean;
var
  SelData: ControlEditTextSelectionRec;
begin
  Result := False;
  ASelLength := 0;
  if GetEditPart < 0 then Exit;
  
  if OSError(
    GetControlData(ControlRef(Widget), GetEditPart, kControlEditTextSelectionTag,
    SizeOf(ControlEditTextSelectionRec), @SelData, nil),
    Self, 'GetSelLength', SGetData) then Exit;

  ASelLength := SelData.SelEnd - SelData.SelStart;
  Result := True;
end;

{------------------------------------------------------------------------------
  Method:  TCarbonControlWithEdit.SetSelStart
  Params:  ASelStart - Selection start
  Returns: If the function suceeds

  Sets the selection start of the edit part of control
 ------------------------------------------------------------------------------}
function TCarbonControlWithEdit.SetSelStart(ASelStart: Integer): Boolean;
var
  SelData: ControlEditTextSelectionRec;
const
  SName = 'SetSelStart';
begin
  Result := False;
  if GetEditPart < 0 then Exit;
  
  if OSError(
    GetControlData(ControlRef(Widget), GetEditPart, kControlEditTextSelectionTag,
      SizeOf(ControlEditTextSelectionRec), @SelData, nil),
    Self, SName, SGetData) then Exit;

  if SelData.SelStart = ASelStart then
  begin
    Result := True;
    Exit;
  end;

  SelData.SelEnd := (SelData.SelEnd - SelData.SelStart) + ASelStart;
  SelData.SelStart := ASelStart;
  
  if OSError(
    SetControlData(ControlRef(Widget), GetEditPart, kControlEditTextSelectionTag,
      SizeOf(ControlEditTextSelectionRec), @SelData),
    Self, SName, SSetData) then Exit;
      
  Result := True;
end;

{------------------------------------------------------------------------------
  Method:  TCarbonControlWithEdit.SetSelLength
  Params:  ASelLength - Selection length
  Returns: If the function suceeds

  Sets the selection length of the edit part of control
 ------------------------------------------------------------------------------}
function TCarbonControlWithEdit.SetSelLength(ASelLength: Integer): Boolean;
var
  SelData: ControlEditTextSelectionRec;
const
  SName = 'SetSelLength';
begin
  Result := False;
  if GetEditPart < 0 then Exit;

  if OSError(
    GetControlData(ControlRef(Widget), GetEditPart, kControlEditTextSelectionTag,
      SizeOf(ControlEditTextSelectionRec), @SelData, nil),
    Self, SName, SGetData) then Exit;

  if SelData.SelEnd = SelData.SelStart + ASelLength then
  begin
    Result := True;
    Exit;
  end;

  SelData.SelEnd := SelData.SelStart + ASelLength;
  
  if OSError(
    SetControlData(ControlRef(Widget), GetEditPart, kControlEditTextSelectionTag,
      SizeOf(ControlEditTextSelectionRec), @SelData),
    Self, SName, SSetData) then Exit;

  Result := True;
end;

{------------------------------------------------------------------------------
  Method:  TCarbonControlWithEdit.GetText
  Params:  S - Text
  Returns: If the function succeeds

  Gets the text of edit control
 ------------------------------------------------------------------------------}
function TCarbonControlWithEdit.GetText(var S: String): Boolean;
var
  CFString: CFStringRef;
begin
  Result := False;
  S := '';
  if GetEditPart < 0 then Exit;
  
  if OSError(
    GetControlData(ControlRef(Widget), GetEditPart, kControlEditTextCFStringTag,
      SizeOf(CFStringRef), @CFString, nil),
    Self, SGetText, SGetData) then Exit;
  try
    S := CFStringToStr(CFString);
    S := StringReplace(S, #13, LineEnding, [rfReplaceAll]);
    Result := True;
  finally
    FreeCFString(CFString);
  end;
end;

{------------------------------------------------------------------------------
  Method:  TCarbonControlWithEdit.SetText
  Params:  S - New text
  Returns: If the function succeeds

  Sets the text of edit control
 ------------------------------------------------------------------------------}
function TCarbonControlWithEdit.SetText(const S: String): Boolean;
var
  CFString: CFStringRef;
  Res     : Boolean;
  utf8  : String;
begin
  Result := False;
  if GetEditPart < 0 then Exit;
  
  CreateCFString(S, CFString);
  Res:=Assigned(CFString);
  if not Res then
  begin
    // the string contains utf8 invalid characters. trying to convert it to utf8 first
    utf8:=AnsiToUtf8(S);
    CreateCFString(utf8, CFString);
    Res:=Assigned(CFString);
    // if CFString cannot be created even for the converted string, clear the content and return False
    if not Res then CreateCFString('', CFString);
  end;

  try
    if OSError(
      SetControlData(ControlRef(Widget), GetEditPart, kControlEditTextCFStringTag,
        SizeOf(CFStringRef), @CFString),
      Self, SSetText, SSetData) then Exit;
      
    Result := Res;
  finally
    FreeCFString(CFString);
  end;
end;

{------------------------------------------------------------------------------
  Method:  TCarbonControlWithEdit.SetReadOnly
  Params:  AReadOnly - Read only behavior

  Sets the read only behavior of edit control
 ------------------------------------------------------------------------------}
procedure TCarbonControlWithEdit.SetReadOnly(AReadOnly: Boolean);
begin
  if GetEditPart < 0 then Exit;
  
  OSError(SetControlData(ControlRef(Widget), GetEditPart,
      kControlEditTextLockedTag, SizeOf(Boolean), @AReadOnly),
    Self, 'SetReadOnly', SSetData);
end;

{ TCarbonComboBox }

{------------------------------------------------------------------------------
  Name: CarbonComboBox_ListItemSelected
  Handles combo box list item change
 ------------------------------------------------------------------------------}
function CarbonComboBox_ListItemSelected(ANextHandler: EventHandlerCallRef;
  AEvent: EventRef;
  AWidget: TCarbonWidget): OSStatus; {$IFDEF darwin}mwpascal;{$ENDIF}
var
  Index: CFIndex;
begin
  {$IFDEF VerboseControlEvent}
    DebugLn('CarbonComboBox_ListItemSelected: ', DbgSName(AWidget.LCLObject));
  {$ENDIF}

  Result := CallNextEventHandler(ANextHandler, AEvent);

  // get selected item index
  if OSError(
    GetEventParameter(AEvent, kEventParamComboBoxListSelectedItemIndex,
      typeCFIndex, nil, SizeOf(CFIndex), nil, @Index),
    'CarbonComboBox_ListItemSelected', SGetEvent,
    'kEventParamComboBoxListSelectedItemIndex') then Index := -1;
  (AWidget as TCarbonComboBox).ListItemSelected(Index);
end;

{------------------------------------------------------------------------------
  Name: CarbonComboBox_MenuOpening
  Handles combo box menu open event
 ------------------------------------------------------------------------------}
function CarbonComboBox_MenuOpening(ANextHandler: EventHandlerCallRef;
  AEvent: EventRef;
  AWidget: TCarbonWidget): OSStatus; {$IFDEF darwin}mwpascal;{$ENDIF}
begin
  {$IFDEF VerboseControlEvent}
    DebugLn('CarbonComboBox_MenuOpening: ', DbgSName(AWidget.LCLObject));
  {$ENDIF}

  Result := CallNextEventHandler(ANextHandler, AEvent);

  LCLSendDropDownMsg(AWidget.LCLObject);
end;

{------------------------------------------------------------------------------
  Name: CarbonComboBox_MenuClosed
  Handles combo box menu closed event
 ------------------------------------------------------------------------------}
function CarbonComboBox_MenuClosed(ANextHandler: EventHandlerCallRef;
  AEvent: EventRef;
  AWidget: TCarbonWidget): OSStatus; {$IFDEF darwin}mwpascal;{$ENDIF}
begin
  {$IFDEF VerboseControlEvent}
    DebugLn('CarbonComboBox_MenuClosed: ', DbgSName(AWidget.LCLObject));
  {$ENDIF}

  Result := CallNextEventHandler(ANextHandler, AEvent);

  LCLSendCloseUpMsg(AWidget.LCLObject);
end;

procedure TCarbonComboBox.DropDownTimer(Sender: TObject);
var
  D: Boolean;
begin
  D := IsDroppedDown;
  if D <> FLastDroppedDown then
  begin
    FLastDroppedDown := D;
    if FLastDroppedDown then
      LCLSendDropDownMsg(LCLObject)
    else
      LCLSendCloseUpMsg(LCLObject);
  end;
end;

{------------------------------------------------------------------------------
  Method:  TCarbonComboBox.RegisterEvents

  Registers event handlers for combo box
 ------------------------------------------------------------------------------}
procedure TCarbonComboBox.RegisterEvents;
var
  TmpSpec: EventTypeSpec;
begin
  inherited RegisterEvents;
  
  TmpSpec := MakeEventSpec(kEventClassHIComboBox, kEventComboBoxListItemSelected);
  InstallControlEventHandler(Widget,
    RegisterEventHandler(@CarbonComboBox_ListItemSelected),
    1, @TmpSpec, Pointer(Self), nil);
end;

{------------------------------------------------------------------------------
  Method:  TCarbonComboBox.CreateWidget
  Params:  AParams - Creation parameters

  Creates Carbon combo box
 ------------------------------------------------------------------------------}
procedure TCarbonComboBox.CreateWidget(const AParams: TCreateParams);
var
  CFString: CFStringRef;
  TmpSpec: EventTypeSpec;
begin
  FReadOnly := (LCLObject as TCustomComboBox).ReadOnly;
  FLastDroppedDown := False;
  
  if FReadOnly then
  begin
    if OSError(
      CreatePopupButtonControl(GetTopParentWindow,
        ParamsToCarbonRect(AParams), nil, -12345, False, 0, popupTitleLeftJust,
        Normal, Widget),
      Self, SCreateWidget, 'CreatePopupButtonControl')then RaiseCreateWidgetError(LCLObject);
      
    OSError(CreateNewMenu(0, kMenuAttrAutoDisable, FPopupMenu),
      Self, SCreateWidget, 'CreateNewMenu');
      
    TmpSpec := MakeEventSpec(kEventClassMenu, kEventMenuOpening);
    InstallMenuEventHandler(FPopupMenu,
      RegisterEventHandler(@CarbonComboBox_MenuOpening),
      1, @TmpSpec, Pointer(Self), nil);
      
    TmpSpec := MakeEventSpec(kEventClassMenu, kEventMenuClosed);
    InstallMenuEventHandler(FPopupMenu,
      RegisterEventHandler(@CarbonComboBox_MenuClosed),
      1, @TmpSpec, Pointer(Self), nil);
        
    OSError(
      SetControlData(ControlRef(Widget), kControlEntireControl,
        kControlPopupButtonOwnedMenuRefTag, SizeOf(MenuRef), @FPopupMenu),
      Self, SCreateWidget, SSetData);

    // count of popup button items is initially zero
    SetMaximum(0);
  end
  else
  begin
    CreateCFString(AParams.Caption, CFString);
    try
      if OSError(HIComboBoxCreate(ParamsToHIRect(AParams), CFString, nil, nil,
          kHIComboBoxAutoSizeListAttribute or kHIComboBoxAutoDisclosureAttribute, Widget),
        Self, SCreateWidget, 'HIComboBoxCreate')then RaiseCreateWidgetError(LCLObject);

    finally
      FreeCFString(CFString);
    end;
    
    FreeAndNil(FTimer);
    FTimer := TTimer.Create(nil);
    FTimer.Interval := 200;
    FTimer.OnTimer := @DropDownTimer;
  end;
  
  FItemIndex := -1;
  FMaxLength := 0;
  
  inherited;
end;

{------------------------------------------------------------------------------
  Method:  TCarbonComboBox.DestroyWidget

  Destroys Carbon combo box
 ------------------------------------------------------------------------------}
procedure TCarbonComboBox.DestroyWidget;
begin
  if FReadOnly then
    DisposeMenu(FPopupMenu)
  else
  begin
    if FTimer.Enabled then DropDownTimer(nil);
    FTimer.Free;
  end;

  inherited DestroyWidget;
end;

{------------------------------------------------------------------------------
  Method:  TCarbonComboBox.GetEditPart
  Returns: Control part code of edit control
 ------------------------------------------------------------------------------}
function TCarbonComboBox.GetEditPart: ControlPartCode;
begin
  if FReadOnly then Result := -1
  else Result := kHIComboBoxEditTextPart;
end;

{------------------------------------------------------------------------------
  Method:  TCarbonComboBox.GetPopupButtonMenu
  Returns: Popup Button menu
 ------------------------------------------------------------------------------}
function TCarbonComboBox.GetPopupButtonMenu: MenuRef;
begin
  Result := FPopupMenu;

end;

{------------------------------------------------------------------------------
  Method:  TCarbonComboBox.GetValidEvents
  Returns: Set of events with installed handlers
 ------------------------------------------------------------------------------}
class function TCarbonComboBox.GetValidEvents: TCarbonControlEvents;
begin
  Result := inherited GetValidEvents + [cceValueChanged];
end;

{------------------------------------------------------------------------------
  Method:  TCarbonComboBox.ListItemSelected
  Params:  AIndex - Index of selected item

  List item selected event handler
 ------------------------------------------------------------------------------}
procedure TCarbonComboBox.ListItemSelected(AIndex: Integer);
begin
  if FItemIndex <> AIndex then
  begin
    FItemIndex := AIndex;
    LCLSendSelectionChangedMsg(LCLObject);
    // Fire OnChange event
    LCLSendChangedMsg(LCLObject);
  end;
end;

{------------------------------------------------------------------------------
  Method:  TCarbonComboBox.ValueChanged

  Value changed event handler
 ------------------------------------------------------------------------------}
procedure TCarbonComboBox.ValueChanged;
begin
  if FReadOnly then ListItemSelected(GetValue - 1);
end;

{------------------------------------------------------------------------------
  Method:  TCarbonComboBox.FocusSet

  Handles set focus
 ------------------------------------------------------------------------------}
procedure TCarbonComboBox.FocusSet;
begin
  inherited;
  // fire OnGetitems
  (LCLObject as TCustomComboBox).IntfGetItems;
end;

{------------------------------------------------------------------------------
  Method:  TCarbonComboBox.TextDidChange

  Text changed event handler
 ------------------------------------------------------------------------------}
procedure TCarbonComboBox.TextDidChange;
begin
  inherited TextDidChange;
  
  // TComboBox needs LM_CHANGED message type
  SendSimpleMessage(LCLObject, LM_CHANGED);
end;

const
  // values are used from Interface Builder
  StdComboBoxNormalSize = 20;
  StdComboBoxSmallSize = 17;
  StdComboBoxTinySize = 0; // 14

  StdPopupButtonNormalSize = 20;
  StdPopupButtonSmallSize = 17;
  StdPopupButtonTinySize = 0; // 16

procedure TCarbonComboBox.BoundsChanged;
begin
  inherited BoundsChanged;
  if FReadOnly then
    SetControlViewStyle(Widget, StdPopupButtonTinySize, StdPopupButtonSmallSize, StdPopupButtonNormalSize)
  else
    SetControlViewStyle(Widget, StdComboBoxTinySize, StdComboBoxSmallSize, StdComboBoxNormalSize);
end;

{------------------------------------------------------------------------------
  Method:  TCarbonComboBox.GetText
  Params:  S - Text
  Returns: If the function succeeds

  Gets the text of combo box
 ------------------------------------------------------------------------------}
function TCarbonComboBox.GetText(var S: String): Boolean;
var
  ComboBox: TCustomComboBox;
begin
  if FReadOnly then
  begin
    ComboBox := LCLObject as TCustomComboBox;
    if (FItemIndex >= 0) and (FItemIndex < ComboBox.Items.Count) then
      S := ComboBox.Items[FItemIndex]
    else
      S := '';
      
    Result := True;
  end
  else
    Result := inherited GetText(S);
end;

{------------------------------------------------------------------------------
  Method:  TCarbonComboBox.SetBounds
  Params:  ARect - Record for control coordinates
  Returns: If function succeeds

  Sets the control bounding rectangle relative to the client origin of its
  parent
 ------------------------------------------------------------------------------}
function TCarbonComboBox.SetBounds(const ARect: TRect): Boolean;
var
  R: TRect;
begin
  R := ARect;
  R.Bottom := R.Top + GetPreferredSize.Y;
  Result := inherited SetBounds(R);
end;

{------------------------------------------------------------------------------
  Method:  TCarbonComboBox.SetReadOnly
  Params:  AReadOnly - Read only behavior

  Sets the read only behavior of combo box
 ------------------------------------------------------------------------------}
procedure TCarbonComboBox.SetReadOnly(AReadOnly: Boolean);
begin
  if AReadOnly <> FReadOnly then RecreateWnd(LCLObject);
end;

{------------------------------------------------------------------------------
  Method:  TCarbonComboBox.GetItemIndex
  Returns: The current item selected index
 ------------------------------------------------------------------------------}
function TCarbonComboBox.GetItemIndex: Integer;
begin
  Result := FItemIndex;
end;

{------------------------------------------------------------------------------
  Method:  TCarbonComboBox.SetItemIndex
  Params:  AIndex - New item index
  
  Changes currently selected item
 ------------------------------------------------------------------------------}
function TCarbonComboBox.SetItemIndex(AIndex: Integer): Boolean;
begin
  Result := False;
  //DebugLn('TCarbonComboBox.SetItemIndex New: ' + DbgS(AIndex) + ' Prev: ' + DbgS(FItemIndex));
  if AIndex <> FItemIndex then
  begin
    if FReadOnly then SetValue(AIndex + 1)
    else
    begin
      if AIndex = -1 then
      begin
        FItemIndex := -1;
        Result := SetText('');
      end
      else
      begin
        FItemIndex := AIndex;
        Result := SetText((LCLObject as TCustomComboBox).Items[AIndex]);
      end;
      end;
  end
  else Result := True;
end;

{------------------------------------------------------------------------------
  Method:  TCarbonComboBox.Insert
  Params:  AIndex - Item index
           S      - Item text

  Inserts item with the specified text at index
 ------------------------------------------------------------------------------}
procedure TCarbonComboBox.Insert(AIndex: Integer; const S: String);
var
  CFString: CFStringRef;
begin
  CreateCFString(S, CFString);
  try
    if FReadOnly then
    begin
      OSError(InsertMenuItemTextWithCFString(GetPopupButtonMenu, CFString, AIndex,
          kMenuItemAttrIgnoreMeta, 0),
        Self, 'Inset', 'InsertMenuItemTextWithCFString');
        
      SetMaximum((LCLObject as TCustomComboBox).Items.Count);
    end
    else
    begin
      OSError(HIComboBoxInsertTextItemAtIndex(HIViewRef(Widget), AIndex, CFString),
        Self, 'Insert', 'HIComboBoxInsertTextItemAtIndex');
     end;
  finally
    FreeCFString(CFString);
  end;
end;

{------------------------------------------------------------------------------
  Method:  TCarbonComboBox.Remove
  Params:  AIndex - Item index

  Removes item with the specified index
 ------------------------------------------------------------------------------}
procedure TCarbonComboBox.Remove(AIndex: Integer);
begin
  if FReadOnly then
  begin
    DeleteMenuItem(GetPopupButtonMenu, AIndex + 1);
    SetMaximum((LCLObject as TCustomComboBox).Items.Count);
  end
  else
  begin
    OSError(HIComboBoxRemoveItemAtIndex(HIViewRef(Widget), AIndex),
      Self, 'Remove', 'HIComboBoxRemoveItemAtIndex');
  end;
end;

{------------------------------------------------------------------------------
  Method:  TCarbonComboBox.DropDown
  Params:  ADropDown - Drop down
  Returns: If the function succeeds

  Shows or hides drop down list
 ------------------------------------------------------------------------------}
function TCarbonComboBox.DropDown(ADropDown: Boolean): Boolean;
begin
  Result := False;
  if FReadOnly then
  begin
    //P := LCLObject.ClientToScreen(Classes.Point(0, 0));
    //PopUpMenuSelect(FPopupMenu, P.Y, P.X, FItemIndex + 1);
    DebugLn('TCarbonComboBox.DropDown for DropDownList TODO');
    Exit;
  end;
  
  if OSError(HIComboBoxSetListVisible(ControlRef(Widget), ADropDown), Self,
    'DropDown', 'HIComboBoxSetListVisible') then Exit;

  Result := True;
end;

function TCarbonComboBox.IsDroppedDown: Boolean;
begin
  Result := HIComboBoxIsListVisible(ControlRef(Widget));
end;

{ TCarbonCustomEdit }

function TCarbonCustomEdit.GetCanUndo: Boolean;
var
  AStr: CFStringRef;
begin
  AStr := nil;
  Result := TXNCanUndoAction(HITextViewGetTXNObject(ControlRef(Widget)), AStr);
end;

procedure TCarbonCustomEdit.CopyToClip;
begin
  TXNCopy(HITextViewGetTXNObject(ControlRef(Widget)));
end;

procedure TCarbonCustomEdit.CutToClip;
begin
  TXNCut(HITextViewGetTXNObject(ControlRef(Widget)));
end;

procedure TCarbonCustomEdit.PasteFromClip;
begin
  TXNPaste(HITextViewGetTXNObject(ControlRef(Widget)));
end;

procedure TCarbonCustomEdit.UndoClip;
begin
  TXNUndo(HITextViewGetTXNObject(ControlRef(Widget)));
end;

{------------------------------------------------------------------------------
  Method:  TCarbonCustomEdit.FilterKeyPress

  Filters key presses from being send to Carbon control
 ------------------------------------------------------------------------------}
function TCarbonCustomEdit.FilterKeyPress(SysKey: Boolean; const Char: TUTF8Char): Boolean;
begin
  Result := (Char = #13);
end;

function TCarbonCustomEdit.GetCaretPos: TPoint;
var
  x  : Integer;
begin
  Result.Y := 0;
  if not GetSelStart(x{%H-}) then x := 0;
  Result.X := x;
end;

{ TCarbonSpinEdit }

{------------------------------------------------------------------------------
  Method:  TCarbonSpinEdit.UpDownThemeWidth
  Returns: UpDown theme width
 ------------------------------------------------------------------------------}
function TCarbonSpinEdit.UpDownThemeWidth: Integer;
begin
  Result := GetCarbonThemeMetric(kThemeMetricLittleArrowsWidth, 13);
end;

{------------------------------------------------------------------------------
  Method:  TCarbonSpinEdit.FocusRectThemeOutset
  Returns: Focus rectangle theme outset
 ------------------------------------------------------------------------------}
function TCarbonSpinEdit.FocusRectThemeOutset: Integer;
begin
  Result := GetCarbonThemeMetric(kThemeMetricFocusRectOutset, 4);
end;

{------------------------------------------------------------------------------
  Method:  TCarbonSpinEdit.GetEditBounds
  Params:  ARect - Bounding rect
  Returns: Bounding rect for edit
 ------------------------------------------------------------------------------}
function TCarbonSpinEdit.GetEditBounds(const ARect: HIRect): HIRect;
var
  H: Single;
begin
  if LCLObject.AutoSize then
  begin // apply edit preffered height if autosize
    H := GetPreferredSize.y;
    if H = 0 then H := ARect.size.height;
  end
  else
    H := ARect.size.height;
    
  Result.origin.x := ARect.origin.x;
  Result.origin.y := ARect.origin.y + (ARect.size.height - H) / 2;
  Result.size.width := ARect.size.width - (UpDownThemeWidth + 2 * FocusRectThemeOutset);
  Result.size.height := H;
end;

{------------------------------------------------------------------------------
  Method:  TCarbonSpinEdit.GetUpDownBounds
  Params:  ARect - Bounding rect
  Returns: Bounding rect for updown
 ------------------------------------------------------------------------------}
function TCarbonSpinEdit.GetUpDownBounds(const ARect: HIRect): HIRect;
begin
  Result.origin.x := ARect.origin.x + ARect.size.width - (UpDownThemeWidth);
  Result.origin.y := ARect.origin.y;
  Result.size.width := UpDownThemeWidth;
  Result.size.height := ARect.size.height;
end;

{------------------------------------------------------------------------------
  Method:  TCarbonSpinEdit.CreateWidget
  Params:  AParams - Creation parameters

  Creates Carbon spin edit
 ------------------------------------------------------------------------------}
procedure TCarbonSpinEdit.CreateWidget(const AParams: TCreateParams);
var
  CFString: CFStringRef;
const
  SingleLine: Boolean = True;
begin
  CreateCFString(AParams.Caption, CFString);
  try
    if OSError(
      CreateEditUniCodeTextControl(GetTopParentWindow, ParamsToCarbonRect(AParams),
        CFString, False, nil, Widget),
      Self, SCreateWidget, 'CreateEditUniCodeTextControl') then RaiseCreateWidgetError(LCLObject);
  finally
    FreeCFString(CFString);
  end;
  
  // set edit single line
  OSError(
    SetControlData(Widget, kControlEntireControl, kControlEditTextSingleLineTag,
      SizeOf(Boolean), @SingleLine),
    Self, SCreateWidget, SSetData);

  // bug: #14634
  // for some reason, OSX 10.5, arrows don't work properly, with
  // value = 1, min = 0, max = 2. Only lower button is visually pressed (painted).
  // changed to: value = 0, min = -5, max = 5
  if OSError(
      CreateLittleArrowsControl(GetTopParentWindow,
        HIRectToCarbonRect(GetUpDownBounds(ParamsToHIRect(AParams))),
        0, -5, 5, 1, FUpDown),
      Self, SCreateWidget, 'CreateLittleArrowsControl') then RaiseCreateWidgetError(LCLObject);
    
  AddControlPart(FUpDown);
    
  inherited;
  
  SetBounds(ParamsToRect(AParams));
  UpdateControl;
end;

{------------------------------------------------------------------------------
  Method:  TCarbonSpinEdit.DestroyWidget

  Destroys Carbon spin edit
 ------------------------------------------------------------------------------}
procedure TCarbonSpinEdit.DestroyWidget;
begin
  DisposeControl(FUpDown);

  inherited;
end;

{------------------------------------------------------------------------------
  Method:  TCarbonSpinEdit.GetFrame
  Params:  Frame index
  Returns: Frame area control
 ------------------------------------------------------------------------------}
function TCarbonSpinEdit.GetFrame(Index: Integer): ControlRef;
begin
  case Index of
  0: Result := ControlRef(Widget);
  1: Result := FUpDown;
  end;
end;

{------------------------------------------------------------------------------
  Method:  TCarbonSpinEdit.GetFrameBounds
  Params:  ARect - Rectangle
  Returns: If function succeeds

  Returns the control bounding rectangle relative to the client origin of its
  parent
 ------------------------------------------------------------------------------}
function TCarbonSpinEdit.GetFrameBounds(var ARect: TRect): Boolean;
begin
  Result := False;

  if inherited GetFrameBounds(ARect) then
  begin
    // add updown width
    ARect.Right := ARect.Right + (UpDownThemeWidth + 2 * FocusRectThemeOutset);
    
    Result := True;
  end;
end;

{------------------------------------------------------------------------------
  Method:  TCarbonSpinEdit.GetFrameCount
  Returns: Count of control frames
 ------------------------------------------------------------------------------}
class function TCarbonSpinEdit.GetFrameCount: Integer;
begin
  Result := 2;
end;

{------------------------------------------------------------------------------
  Method:  TCarbonSpinEdit.GetValidEvents
  Returns: Set of events with installed handlers
 ------------------------------------------------------------------------------}
class function TCarbonSpinEdit.GetValidEvents: TCarbonControlEvents;
begin
  Result := inherited GetValidEvents + [cceDoAction];
end;

{------------------------------------------------------------------------------
  Method:  TCarbonSpinEdit.TextDidChange

  Text changed event handler
 ------------------------------------------------------------------------------}
procedure TCarbonSpinEdit.TextDidChange;
begin
  FValue := (LCLObject as TCustomFloatSpinEdit).StrToValue(
    (LCLObject as TCustomFloatSpinEdit).Text);

  inherited TextDidChange;
end;

{------------------------------------------------------------------------------
  Method:  TCarbonSpinEdit.DoAction
  Params:  AControlPart - Control part to perform the action

  Action event handler
 ------------------------------------------------------------------------------}
procedure TCarbonSpinEdit.DoAction(AControlPart: ControlPartCode);
begin
  case AControlPart of
    kControlUpButtonPart:   FValue := FValue + FIncrement;
    kControlDownButtonPart: FValue := FValue - FIncrement;
  end;
  
  FValue := (LCLObject as TCustomFloatSpinEdit).GetLimitedValue(FValue);
  
  inherited SetText((LCLObject as TCustomFloatSpinEdit).ValueToStr(FValue));
  inherited TextDidChange;
end;

{------------------------------------------------------------------------------
  Method:  TCarbonSpinEdit.SetBounds
  Params:  ARect - Record for control coordinates
  Returns: If function succeeds

  Sets the control bounding rectangle relative to the client origin of its
  parent
 ------------------------------------------------------------------------------}
function TCarbonSpinEdit.SetBounds(const ARect: TRect): Boolean;
begin
  Result := False;

  if OSError(
    HIViewSetFrame(Widget, GetEditBounds(RectToCGRect(ARect))),
    Self, SSetBounds, SViewFrame) then Exit;
    
  if OSError(HIViewSetFrame(FUpDown, GetUpDownBounds(RectToCGRect(ARect))),
    Self, SSetBounds, SViewFrame) then Exit;
    
  Result := True;
end;

{------------------------------------------------------------------------------
  Method:  TCarbonSpinEdit.SetPasswordChar
  Params:  AChar     - New password char

  Sets the new password char of Carbon edit
 ------------------------------------------------------------------------------}
procedure TCarbonSpinEdit.SetPasswordChar(AChar: Char);
begin
  // not supported
end;

{------------------------------------------------------------------------------
  Method:  TCarbonControlWithEdit.SetText
  Params:  S - New text
  Returns: If the function succeeds

  Sets the text of edit control
 ------------------------------------------------------------------------------}
function TCarbonSpinEdit.SetText(const S: String): Boolean;
begin
  FValue := (LCLObject as TCustomFloatSpinEdit).StrToValue(S);
  
  Result := inherited SetText(S);
end;

{------------------------------------------------------------------------------
  Method:  TCarbonSpinEdit.UpdateControl

  Updates the value, min, max and increment of Carbon spin edit
 ------------------------------------------------------------------------------}
procedure TCarbonSpinEdit.UpdateControl;
var
  SpinEdit: TCustomFloatSpinEdit;
begin
  SpinEdit := (LCLObject as TCustomFloatSpinEdit);
  FValue := SpinEdit.Value;
  FMin := SpinEdit.MinValue;
  FMax := SpinEdit.MaxValue;
  FIncrement := SpinEdit.Increment;
  FDecimalPlaces :=  SpinEdit.DecimalPlaces;
    
  // update edit text
  inherited SetText((LCLObject as TCustomFloatSpinEdit).ValueToStr(FValue));
end;

{ TCarbonEdit }

{------------------------------------------------------------------------------
  Method:  TCarbonEdit.CreateWidget
  Params:  AParams - Creation parameters

  Creates Carbon edit
 ------------------------------------------------------------------------------}
procedure TCarbonEdit.CreateWidget(const AParams: TCreateParams);
var
  Edit: TCustomEdit;
  Control: ControlRef;
  CFString: CFStringRef;
  SingleLine: Boolean = True;
begin
  Edit := LCLObject as TCustomEdit;

  CreateCFString(AParams.Caption, CFString);
  try
    if OSError(
      CreateEditUniCodeTextControl(GetTopParentWindow, ParamsToCarbonRect(AParams),
        CFString, (Edit.PasswordChar <> #0), nil, Control{%H-}),
      Self, SCreateWidget, 'CreateEditUniCodeTextControl') then RaiseCreateWidgetError(LCLObject);

    Widget := Control;
    
    inherited;
  finally
    FreeCFString(CFString);
  end;

  // set edit single line
  OSError(
    SetControlData(Control, kControlEntireControl, kControlEditTextSingleLineTag,
      SizeOf(Boolean), @SingleLine),
    Self, SCreateWidget, SSetData);
    
  FIsPassword := Edit.PasswordChar <> #0;
  FMaxLength := Edit.MaxLength;
end;

const
  // values are used from Interface Builder
  StdEditNormalSize = 16;
  StdEditSmallSize = 13;
  StdEditTinySize = 0; // 9

procedure TCarbonEdit.BoundsChanged;
begin
  inherited BoundsChanged;
  SetControlViewStyle(Widget, StdEditTinySize, StdEditSmallSize, StdEditNormalSize);
end;

{------------------------------------------------------------------------------
  Method:  TCarbonEdit.GetText
  Params:  S - Text
  Returns: If the function succeeds

  Gets the text of edit control
 ------------------------------------------------------------------------------}
function TCarbonEdit.GetText(var S: String): Boolean;
var
  CFString: CFStringRef;
begin
  if not FIsPassword then
    Result := inherited GetText(S)
  else
  begin
    Result := False;

    if OSError(
      GetControlData(ControlRef(Widget), GetEditPart,
        kControlEditTextPasswordCFStringTag, SizeOf(CFStringRef), @CFString, nil),
      Self, SGetText, SGetData) then Exit;

    try
      S := CFStringToStr(CFString);
      Result := True;
    finally
      FreeCFString(CFString);
    end;
  end;
end;

{------------------------------------------------------------------------------
  Method:  TCarbonEdit.SetText
  Params:  S - New text
  Returns: If the function succeeds

  Sets the text of edit control
 ------------------------------------------------------------------------------}
function TCarbonEdit.SetText(const S: String): Boolean;
var
  CFString: CFStringRef;
begin
  if not FIsPassword then
    Result := inherited SetText(S)
  else
  begin
    Result := False;
    
    CreateCFString(S, CFString);
    try
      if OSError(
        SetControlData(ControlRef(Widget), GetEditPart,
          kControlEditTextPasswordCFStringTag, SizeOf(CFStringRef), @CFString),
        Self, SSetText, SSetData) then Exit;
        
      Result := True;
    finally
      FreeCFString(CFString);
    end;
  end;
end;

function TCarbonEdit.GetPreferredSize: TPoint;  
begin
  Result:=inherited GetPreferredSize;  
  inc(Result.Y, EditExtraBottom+EditExtraTop);
end;

{------------------------------------------------------------------------------
  Method:  TCarbonEdit.SetPasswordChar
  Params:  AChar     - New password char

  Sets the new password char of Carbon edit
 ------------------------------------------------------------------------------}
procedure TCarbonEdit.SetPasswordChar(AChar: Char);
begin
  if FIsPassword <> (AChar <> #0) then RecreateWnd(LCLObject);
end;

function TCarbonEdit.SetBounds(const ARect: TRect): Boolean; 
var
  r : TRect;
begin
  r := ARect;
  inc(r.Top, EditExtraTop);
  dec(r.Bottom, EditExtraBottom);
  inc(r.Left, EditExtraLeft);
  dec(r.Right, EditExtraRight);

  FTooSmall:=(r.Right<r.Left) or (r.Bottom<r.Top);
  if FTooSmall then FSmallBounds:=ARect;

  Result := inherited SetBounds(r);
end;

function TCarbonEdit.GetFrameBounds(var r: TRect): Boolean; 
begin
  if FTooSmall then
  begin
    r:=FSmallBounds;
    Result:=True;
  end
  else
  begin
    Result := inherited GetFrameBounds(r);
    dec(r.Top, EditExtraTop);
    inc(r.Bottom, EditExtraBottom);
    dec(r.Left, EditExtraLeft);
    inc(r.Right, EditExtraRight);
  end;
end;


{ TCarbonMemo }

{------------------------------------------------------------------------------
  Method:  TCarbonMemo.SetScrollBars
  Params:  AValue - New scroll style

  Sets the memo scrollbars
 ------------------------------------------------------------------------------}
procedure TCarbonMemo.SetScrollBars(const AValue: TScrollStyle);
begin
  ChangeScrollBars(FScrollView, FScrollBars, AValue);
end;

{------------------------------------------------------------------------------
  Method:  TCarbonMemo.GetFrame
  Params:  Frame index
  Returns: Frame area control
 ------------------------------------------------------------------------------}
function TCarbonMemo.GetFrame(Index: Integer): ControlRef;
begin
  Result:=FBorder;
end;


{------------------------------------------------------------------------------
  Method:  TCarbonMemo.CreateWidget
  Params:  AParams - Creation parameters

  Creates Carbon memo
 ------------------------------------------------------------------------------}
procedure TCarbonMemo.CreateWidget(const AParams: TCreateParams);
var
  Control: ControlRef;
  R: HIRect;
begin
  R := ParamsToHIRect(AParams);
  if OSError(HITextViewCreate(@R, 0, GetCreationOptions, Control{%H-}),
    Self, SCreateWidget, 'HITextViewCreate') then RaiseCreateWidgetError(LCLObject);

  Widget := Control;
  
  // force embed in scroll view because HITextView is not scrolling into
  // caret position when not embedded

  FScrollBars := (LCLObject as TCustomMemo).ScrollBars;
  FScrollView := EmbedInScrollView(FScrollBars);

  FBorder:= CreateCustomHIView(ParamsToHIRect(AParams), LCLObject.ControlStyle);
  HIViewAddSubview(FBorder, FScrollView);
  HIViewSetVisible(FScrollView, True);
  OSError(
    SetControlProperty(FBorder, LAZARUS_FOURCC, WIDGETINFO_FOURCC, SizeOf(Self), @Self),
    Self, 'AddControlPart', SSetControlProp);


  inherited;

  FMaxLength := 0;
end;

{------------------------------------------------------------------------------
  Method:  TCarbonMemo.DestroyWidget

  Destroys Carbon memo
 ------------------------------------------------------------------------------}
procedure TCarbonMemo.DestroyWidget;
begin
  inherited DestroyWidget;
  
  DisposeControl(FScrollView);
  DisposeControl(FBorder);
end;

{------------------------------------------------------------------------------
  Method:  TCarbonMemo.GetLineOffset
  Returns: Offset of specified line
 ------------------------------------------------------------------------------}
procedure TCarbonMemo.GetLineOffset(AIndex: Integer; out AStart, AEnd: TXNOffset);
const
  SName = 'GetLineOffset';
var
  O: TXNObject;
  W, H: Fixed;
  P: HIPoint;
  Line, TextStart, TextEnd: TXNOffset;
  LineTop, LineBottom: Single;
begin
  AStart := 0;
  AEnd := 0;
  if AIndex >= GetLineCount then
  begin
    AStart := kTXNEndOffset;
    AEnd := kTXNEndOffset;
    Exit;
  end;
  O := HITextViewGetTXNObject(ControlRef(Widget));
  if TXNDataSize(O) = 0 then Exit;

  if OSError(TXNGetLineMetrics(O, AIndex, W{%H-}, H{%H-}), Self, SName, 'TXNGetLineMetrics') then Exit;
  if OSError(TXNOffsetToHIPoint(O, 0, P{%H-}), Self, SName, 'TXNOffsetToHIPoint') then Exit;
  LineTop := P.y + AIndex * Fix2X(H);
  LineBottom := LineTop + Fix2X(H);

  // find line offset with bisection
  TextStart := 0;
  TextEnd := TXNDataSize(O) div 2;
  repeat
    Line := (TextStart + TextEnd) div 2;
    if OSError(TXNOffsetToHIPoint(O, Line, P), Self, SName, 'TXNOffsetToHIPoint') then Exit;
    if P.y < LineTop then
      TextStart := Line + 1
    else
      TextEnd := Line;
      
    if (P.y >= LineTop) and (P.y < LineBottom) then Break;
  until TextEnd < TextStart;

  LineTop := P.y;

  // find line start offset
  AStart := Line;
  while AStart > 0 do
  begin
    if OSError(TXNOffsetToHIPoint(O, AStart - 1, P), Self, SName, 'TXNOffsetToHIPoint') then Exit;
    if P.y <> LineTop then Break;
    Dec(AStart);
  end;
  
  // find line end offset
  AEnd := Line;
  TextEnd := TXNDataSize(O) div 2;
  while AEnd < TextEnd do
  begin
    if OSError(TXNOffsetToHIPoint(O, AEnd + 1, P), Self, SName, 'TXNOffsetToHIPoint') then Exit;
    if P.y <> LineTop then Break;
    Inc(AEnd);
  end;
end;

function TCarbonMemo.GetCreationOptions: TXNFrameOptions;
begin
  Result := kTXNMonostyledTextMask // disable more font styles
    or kTXNDontDrawSelectionWhenInactiveMask // hide selection, when inactive
    or kOutputTextInUnicodeEncodingMask
end;

{------------------------------------------------------------------------------
  Method:  TCarbonMemo.TextDidChange

  Text changed event handler
 ------------------------------------------------------------------------------}
procedure TCarbonMemo.TextDidChange;
var
  Msg: TLMessage;
begin
  // limit the text according to MaxLength
  LimitTextLength;

  AdaptCharCase;

  FillChar(Msg{%H-}, SizeOf(Msg), 0);
  Msg.Msg := CM_TEXTCHANGED;
  DeliverMessage(LCLObject, Msg);
end;

function TCarbonMemo.GetTextObject: TXNObject;
begin
  if not Assigned(Content) then Result := nil
  else Result := HITextViewGetTXNObject(Content);
end;

{------------------------------------------------------------------------------
  Method:  TCarbonMemo.SetTXNControl
  Params:  Tag  - Tag
           Data - Tag data

  Sets the control data of TXN object in Carbon interface
 ------------------------------------------------------------------------------}
function TCarbonMemo.SetTXNControl(Tag: TXNControlTag;
  const Data: TXNControlData): Boolean;
begin
  Result := False;
  
  if OSError(TXNSetTXNObjectControls(HITextViewGetTXNObject(ControlRef(Widget)),
         False, 1, @Tag, @Data),
      Self, 'SetTXNControl', SSetTXNControls) then Exit;
  
  Result := True;
end;

function TCarbonMemo.GetTXNSelection(var iStart, iEnd: Integer): Boolean;
var
  ist, ien : TXNOffset;
begin
  TXNGetSelection(HITextViewGetTXNObject(ControlRef(Widget)), ist{%H-}, ien{%H-});
  iStart := Integer(ist);
  iEnd  := Integer(ien);
  Result := true;
end;

function TCarbonMemo.SetTXNSelection(iStart, iEnd: Integer): Boolean;
begin
  Result := not OSError( TXNSetSelection( HITextViewGetTXNObject(Widget), iStart, iEnd),
      Self, 'SetSelSTart', 'SetTXNSelection', '');
  if Result then Invalidate(nil);
end;

procedure TCarbonMemo.BoundsChanged;
var
  r : CGRect;
begin
  inherited BoundsChanged;
  HIViewGetFrame(FBorder, r{%H-});
  if FDrawBorder then
  begin
    //todo: use themed metrics for TextFrame, instead of hard-coded values!
    r.origin.x:=1;
    r.origin.y:=1;
    r.size.width:=r.size.width-2;
    r.size.height:=r.size.height-2;
  end
  else
  begin
    r.origin.x:=0;
    r.origin.y:=0;
  end;
  HIViewSetFrame(FScrollView, r);
end;

function CarbonMemoBorder_Resized(ANextHandler: EventHandlerCallRef;
  AEvent: EventRef;
  AWidget: TCarbonWidget): OSStatus; {$IFDEF darwin}mwpascal;{$ENDIF}
begin
  Result:=CallNextEventHandler(ANextHandler, AEvent);
  if Assigned(AWidget) then
    TCarbonMemo(AWidget).BoundsChanged;
end;

function CarbonMemoBorder_Draw(ANextHandler: EventHandlerCallRef;
  AEvent: EventRef;
  AWidget: TCarbonWidget): OSStatus; {$IFDEF darwin}mwpascal;{$ENDIF}
var
  ctx   : CGContextRef;
  cg    : CGRect;
  clips : array [0..1] of CGRect;
  frm   : HIThemeFrameDrawInfo;
const
  ScrollSz = 16;
begin
  Result:=CallNextEventHandler(ANextHandler, AEvent);
  if Assigned(AWidget) then
  begin
    if OSError(
      GetEventParameter(AEvent, kEventParamCGContextRef, typeCGContextRef, nil,
        SizeOf(CGContextRef), nil, @ctx),
      'CarbonMemoBorder_Draw', SGetEvent, 'kEventParamCGContextRef') then Exit;
    if not Assigned(ctx) then Exit;
    HIViewGetBounds(TCarbonMemo(AWidget).FBorder, cg{%H-});
    cg.origin.x:=0.5;
    cg.origin.y:=0.5;
    cg.size.width:=cg.size.width-2;
    cg.size.height:=cg.size.height-1;

    if TCarbonMemo(AWidget).FDrawBorder then
    begin
      if TCarbonMemo(AWidget).ScrollBars in [ssBoth] then begin
        clips[0].origin.x:=0;
        clips[0].origin.y:=0;
        clips[0].size.width:=cg.size.width+2;
        clips[0].size.height:=cg.size.height-ScrollSz+1;
        clips[1].origin.x:=0;
        clips[1].origin.y:=cg.size.height-ScrollSz;
        clips[1].size.width:=cg.size.width-ScrollSz+2;
        clips[1].size.height:=ScrollSz+1;
        CGContextClipToRects(ctx, @clips, 2);
      end;
      FillChar(frm{%H-}, sizeof(frm), 0);
      frm.kind:=kHIThemeFrameTextFieldSquare;
      frm.state:=kThemeStateActive;
      HIThemeDrawFrame( cg, frm, ctx, 0);
    end;
  end;
end;

// The memo border normally just redirects towards the real control
// but if it is readonly it is more convenient to say we are a text label
function CarbonMemoBorder_Accessibility(ANextHandler: EventHandlerCallRef;
  AEvent: EventRef;
  AWidget: TCarbonWidget): OSStatus; {$IFDEF darwin}mwpascal;{$ENDIF}
var
  // Inputs
  lAXRole, lInputStr: CFStringRef;
  lIsReadOnlyMemo: Boolean;
  lInputAXObject, lInputMemoAXObject: AXUIElementRef;
  lInputID64: UInt64;
  lInputAccessibleObject: TLazAccessibleObject;
  lInputPasStr: string;
  lInputMutableArray: CFMutableArrayRef;
  // Outputs
  lOutputStr: CFStringRef;
  lOutputInt: SInt64;
  lOutputNum: CFNumberRef;
  //
  lLazControl: TControl;
  lLazMemo: TCustomMemo = nil;
  {%H-}lLazAXRole: TLazAccessibilityRole;
  EventKind: UInt32;
  // array
begin
  {$IF defined(VerboseControlEvent) or defined(VerboseAccessibilityEvent)}
    DebugLn('CarbonMemoBorder_Accessibility LCLObject=', DbgSName(AWidget.LCLObject));
  {$ENDIF}

  Result := CallNextEventHandler(ANextHandler, AEvent); // Must be called at the event handling start

  lLazControl := TControl((AWidget as TCarbonControl).LCLObject);
  if lLazControl = nil then Exit;
  if lLazControl is TCustomMemo then lLazMemo := lLazControl as TCustomMemo;
  lIsReadOnlyMemo := (lLazMemo <> nil) and lLazMemo.ReadOnly;

  GetEventParameter(AEvent, kEventParamAccessibleObject,
    typeCFTypeRef, nil, SizeOf(AXUIElementRef), nil, @lInputAXObject);

  // Check if this is an event to a child accessible object
  AXUIElementGetIdentifier(lInputAXObject, lInputID64{%H-});
  lInputAccessibleObject := lLazControl.GetAccessibleObject();
  lInputMemoAXObject := {%H-}AXUIElementRef(lInputAccessibleObject.Handle);
  lLazAXRole := lInputAccessibleObject.AccessibleRole;

  EventKind := GetEventKind(AEvent);
  case EventKind of
    kEventAccessibleGetFocusedChild:
    begin
      {$IF defined(VerboseControlEvent) or defined(VerboseAccessibilityEvent)}
        DebugLn('CarbonMemoBorder_Accessibility kEventAccessibleGetFocusedChild '
          + 'lInputAXObject=%x lChildAX=%x', [PtrInt(lInputAXObject), PtrInt(lInputMemoAXObject)]);
      {$ENDIF}

      if lIsReadOnlyMemo then
        SetEventParameter(AEvent, kEventParamAccessibleChild, typeCFTypeRef,
          SizeOf(AXUIElementRef), nil)
      else
        SetEventParameter(AEvent, kEventParamAccessibleChild, typeCFTypeRef,
          SizeOf(AXUIElementRef), @lInputMemoAXObject);
      Result := noErr;
    end;
    kEventAccessibleGetAllAttributeNames:
    begin
      {$IF defined(VerboseControlEvent) or defined(VerboseAccessibilityEvent)}
        DebugLn('CarbonMemoBorder_Accessibility kEventAccessibleGetAllAttributeNames');
      {$ENDIF}

      GetEventParameter(AEvent, kEventParamAccessibleAttributeNames,
        typeCFMutableArrayRef, nil, SizeOf(CFMutableArrayRef), nil, @lInputMutableArray);

      if lIsReadOnlyMemo then
      begin
        lOutputStr := CFSTR('AXFocused');
        CFArrayAppendValue(lInputMutableArray, lOutputStr);
        lOutputStr := CFSTR('AXValue');
        CFArrayAppendValue(lInputMutableArray, lOutputStr);
        lOutputStr := CFSTR('AXStringForRange');
        CFArrayAppendValue(lInputMutableArray, lOutputStr);
        lOutputStr := CFSTR('AXAttributedStringForRange');
        CFArrayAppendValue(lInputMutableArray, lOutputStr);
        lOutputStr := CFSTR('AXBoundsForRange');
        CFArrayAppendValue(lInputMutableArray, lOutputStr);
        lOutputStr := CFSTR('AXRangeForIndex');
        CFArrayAppendValue(lInputMutableArray, lOutputStr);
        lOutputStr := CFSTR('AXRangeForLine');
        CFArrayAppendValue(lInputMutableArray, lOutputStr);
        lOutputStr := CFSTR('AXRangeForPosition');
        CFArrayAppendValue(lInputMutableArray, lOutputStr);
        lOutputStr := CFSTR('AXRTFForRange');
        CFArrayAppendValue(lInputMutableArray, lOutputStr);
        lOutputStr := CFSTR('AXStyleRangeForIndex');
        CFArrayAppendValue(lInputMutableArray, lOutputStr);
      end;
    end; // kEventAccessibleGetAllAttributeNames
    kEventAccessibleGetNamedAttribute:
    begin
      GetEventParameter(AEvent, kEventParamAccessibleAttributeName,
        typeCFStringRef, nil, SizeOf(CFStringRef), nil, @lInputStr);

      lInputPasStr := CFStringToStr(lInputStr);

      {$IF defined(VerboseControlEvent) or defined(VerboseAccessibilityEvent)}
        DebugLn('CarbonMemoBorder_Accessibility kEventAccessibleGetNamedAttribute kEventParamAccessibleAttributeName=' + lInputPasStr);
      {$ENDIF}

      if lIsReadOnlyMemo and (lInputPasStr = 'AXRole') then
      begin
        lAXRole := CFSTR('AXStaticText');
        SetEventParameter(AEvent, kEventParamAccessibleAttributeValue, typeCFStringRef,
          SizeOf(CFStringRef), @lAXRole);

        Result := noErr;
        Exit;
      end
      // Specially only AXRoleDescription is allowed to override non-TCustomControl values
      else if lInputPasStr = 'AXRoleDescription' then
      begin
        //if lInputAccessibleObject.AccessibleDescription = '' then Exit;
        if lIsReadOnlyMemo then
          CreateCFString('read only text area', lOutputStr)
        else
          CreateCFString('memoborder', lOutputStr);
        SetEventParameter(AEvent, kEventParamAccessibleAttributeValue, typeCFStringRef,
          SizeOf(CFStringRef), @lOutputStr);
        FreeCFString(lOutputStr);
        Result := noErr;
        Exit;
      end
      else if lIsReadOnlyMemo and (lInputPasStr = 'AXValue') then
      begin
        CreateCFString(lLazMemo.Lines.Text, lOutputStr);
        SetEventParameter(AEvent, kEventParamAccessibleAttributeValue, typeCFStringRef,
          SizeOf(CFStringRef), @lOutputStr);
        FreeCFString(lOutputStr);
        Result := noErr;
      end
      else if lIsReadOnlyMemo and (lInputPasStr = 'AXNumberOfCharacters') then
      begin
        lOutputInt := LazUTF8.UTF8Length(lLazMemo.Lines.Text);
        lOutputNum := CFNumberCreate(nil, kCFNumberSInt64Type, @lOutputInt);
        SetEventParameter(AEvent, kEventParamAccessibleAttributeValue, typeCFNumberRef,
          SizeOf(lOutputNum), @lOutputNum);
        CFRelease(lOutputNum);
        Result := noErr;
      end
      //
      // Parameterized attributes
      //
      else if lIsReadOnlyMemo and (lInputPasStr = 'AXStringForRange') then
      begin
        CreateCFString(lLazMemo.Lines.Text, lOutputStr);
        SetEventParameter(AEvent, kEventParamAccessibleAttributeParameter, typeCFStringRef,
          SizeOf(CFStringRef), @lOutputStr);
        FreeCFString(lOutputStr);
        Result := noErr;
      end
      else if lIsReadOnlyMemo and ((lInputPasStr = 'AXAttributedStringForRange') or
         (lInputPasStr = 'AXBoundsForRange') or
         (lInputPasStr = 'AXRangeForIndex') or
         (lInputPasStr = 'AXRangeForLine') or
         (lInputPasStr = 'AXRangeForPosition') or
         (lInputPasStr = 'AXRTFForRange') or
         (lInputPasStr = 'AXStyleRangeForIndex')) then
      begin
        SetEventParameter(AEvent, kEventParamAccessibleAttributeParameter, typeCFTypeRef,
          0, nil);
        Result := noErr;
      end
    end; // kEventAccessibleGetNamedAttribute
  end; // case EventKind of
end;

procedure TCarbonMemo.RegisterEvents;
var
  TmpSpec: EventTypeSpec;
  AccessibilitySpec: array [0..3] of EventTypeSpec;
begin
  inherited RegisterEvents;

  if GetEditPart >= 0 then
  begin
    TmpSpec := MakeEventSpec(kEventClassControl, kEventControlBoundsChanged);
    InstallControlEventHandler(FBorder,
      RegisterEventHandler(@CarbonMemoBorder_Resized),
      1, @TmpSpec, Pointer(Self), nil);

    TmpSpec := MakeEventSpec(kEventClassControl, kEventControlDraw);
    InstallControlEventHandler(FBorder,
      RegisterEventHandler(@CarbonMemoBorder_Draw),
      1, @TmpSpec, Pointer(Self), nil);

    // Accessibility
    //AccessibilitySpec[0].eventClass := kEventClassAccessibility;
    //AccessibilitySpec[0].eventKind := kEventAccessibleGetChildAtPoint;
    AccessibilitySpec[0].eventClass := kEventClassAccessibility;
    AccessibilitySpec[0].eventKind := kEventAccessibleGetFocusedChild;
    AccessibilitySpec[1].eventClass := kEventClassAccessibility;
    AccessibilitySpec[1].eventKind := kEventAccessibleGetAllAttributeNames;
    {AccessibilitySpec[3].eventClass := kEventClassAccessibility;
    AccessibilitySpec[3].eventKind := kEventAccessibleGetAllParameterizedAttributeNames;}
    AccessibilitySpec[2].eventClass := kEventClassAccessibility;
    AccessibilitySpec[2].eventKind := kEventAccessibleGetNamedAttribute;
    // kEventAccessibleSetNamedAttribute
    AccessibilitySpec[3].eventClass := kEventClassAccessibility;
    AccessibilitySpec[3].eventKind := kEventAccessibleIsNamedAttributeSettable;
    // kEventAccessibleGetAllActionNames
    // kEventAccessiblePerformNamedAction
    // kEventAccessibleGetNamedActionDescription

    InstallControlEventHandler(FBorder,
      RegisterEventHandler(@CarbonMemoBorder_Accessibility),
      4, @AccessibilitySpec[0], Pointer(Self), nil);
  end;
end;

procedure TCarbonMemo.Invalidate(Rect: PRect);
var
  R: TRect;
begin
  if Rect = nil then
  begin
    GetClientRect(R{%H-});
    Rect := @R;
  end;
  inherited Invalidate(Rect);
end;

procedure TCarbonMemo.AllowMenuProcess(MenuHotKey: AnsiChar; State: TShiftState; var AllowMenu: Boolean);
begin
  AllowMenu:=True;
end;

function TCarbonMemo.GetSelStart(var ASelStart: Integer): Boolean;
var
  iEnd    : Integer;
begin
  Result := GetTXNSelection(ASelStart, iEnd{%H-});
end;

function TCarbonMemo.GetSelLength(var ASelLength: Integer): Boolean;
var
  iStart : integer;
begin
  Result := GetTXNSelection(iStart{%H-}, ASelLength);
  dec(ASelLength, iStart);
end;

function TCarbonMemo.SetSelStart(ASelStart: Integer): Boolean;
var
  iStart : integer;
  iEnd   : integer;
begin
  Result := GetTXNSelection(iStart{%H-}, iEnd{%H-});
  if not Result then
  begin
    iStart := 0;
    iEnd := iStart;
    Result := true;
  end;
  Result := SetTXNSelection(ASelStart, ASelStart+iEnd-iStart);
end;

function TCarbonMemo.SetSelLength(ASelLength: Integer): Boolean;
var
  iStart : integer;
  iEnd   : integer;
begin
  iEnd := 0;
  Result := GetTXNSelection(iStart{%H-},{%H-}iEnd);
  if not Result then
  begin
    iStart := 0;
    Result := true;
  end;
  if ASelLength < 0 then iEnd := kTXNEndOffset
  else iEnd := iStart + ASelLength;
  Result := SetTXNSelection(iStart, iEnd);
end;

{------------------------------------------------------------------------------
  Method:  TCarbonMemo.SetAlignment
  Params:  AAlignment  - New alignment

  Sets the alignment of memo in Carbon interface
 ------------------------------------------------------------------------------}
procedure TCarbonMemo.SetAlignment(AAlignment: TAlignment);
var
  Data: TXNControlData;
begin
  case AAlignment of
    taLeftJustify:  Data.uValue := UInt32(kTXNFlushLeft);
    taRightJustify: Data.uValue := UInt32(kTXNFlushRight);
    taCenter:       Data.uValue := UInt32(kTXNCenter);
  end;
  SetTXNControl(kTXNJustificationTag, Data);
  
  Invalidate;
end;

{------------------------------------------------------------------------------
  Method:  TCarbonMemo.SetColor
  Params:  AColor - New color

  Sets the color of memo
 ------------------------------------------------------------------------------}
procedure TCarbonMemo.SetColor(const AColor: TColor);
var
  CGColor: CGColorRef;
begin
  if AColor = clDefault then
    CGColor := CreateCGColor(LCLObject.GetDefaultColor(dctBrush))
  else
    CGColor := CreateCGColor(AColor);
  try
    OSError(HITextViewSetBackgroundColor(HIViewRef(Widget), CGColor),
      Self, SSetColor, 'HITextViewSetBackgroundColor');
  finally
    CGColorRelease(CGColor);
  end;
end;

{------------------------------------------------------------------------------
  Method:  TCarbonMemo.SetFont
  Params:  AFont - New font

  Sets the font of memo
 ------------------------------------------------------------------------------}
procedure TCarbonMemo.SetFont(const AFont: TFont);
var
  Attrs: Array [0..3] of TXNTypeAttributes;
  FontColor: RGBColor;
  SavedStyle: ATSUStyle;
const
  SName = 'SetFont';
begin
  // font name
  Attrs[0].tag := kATSUFontTag;
  Attrs[0].size := SizeOf(ATSUFontID);
  Attrs[0].data.dataValue := FindCarbonFontID(AFont.Name);

  // font color
  FontColor := ColorToRGBColor(AFont.Color);
  Attrs[1].tag := kTXNQDFontColorAttribute;
  Attrs[1].size := kTXNQDFontColorAttributeSize;
  Attrs[1].data.dataPtr := @FontColor;

  // font size
  Attrs[2].tag := kTXNQDFontSizeAttribute;
  Attrs[2].size := kTXNQDFontSizeAttributeSize;
  Attrs[2].data.dataValue := AFont.Size;

  ATSUCreateAndCopyStyle(TCarbonFont(AFont.Reference.Handle).Style, SavedStyle{%H-});
  try
    // set font color
    if AFont.Color = clDefault then
      TCarbonFont(AFont.Reference.Handle).SetColor(LCLObject.GetDefaultColor(dctFont))
    else
      TCarbonFont(AFont.Reference.Handle).SetColor(AFont.Color);

    // font style
    Attrs[3].tag := kTXNATSUIStyle;
    Attrs[3].size := kTXNATSUIStyleSize;
    Attrs[3].data.dataPtr := Pointer(TCarbonFont(AFont.Reference.Handle).Style);

    // apply
    OSError(
      TXNSetTypeAttributes(HITextViewGetTXNObject(ControlRef(Widget)), 4, @Attrs[0],
        kTXNStartOffset, kTXNEndOffset),
      Self, SName, 'TXNSetTypeAttributes');
  finally
    ATSUCopyAttributes(SavedStyle, TCarbonFont(AFont.Reference.Handle).Style);
    ATSUDisposeStyle(SavedStyle);
  end;

  // invalidate control
  Invalidate;
end;

{------------------------------------------------------------------------------
  Method:  TCarbonMemo.SetPasswordChar
  Params:  AChar     - New password char

  Sets the new password char of Carbon memo
 ------------------------------------------------------------------------------}
procedure TCarbonMemo.SetPasswordChar(AChar: Char);
begin
  OSError(
    TXNEchoMode(HITextViewGetTXNObject(ControlRef(Widget)),
      UniChar(AChar), CreateTextEncoding(kTextEncodingUnicodeDefault,
      kUnicodeNoSubset, kUnicodeUTF8Format), AChar <> #0),
    Self, 'SetPasswordChar', 'TXNEchoMode');

  Invalidate;
end;

{------------------------------------------------------------------------------
  Method:  TCarbonMemo.SetReadOnly
  Params:  AReadOnly - Read only behavior

  Sets the read only behavior of Carbon memo
 ------------------------------------------------------------------------------}
procedure TCarbonMemo.SetReadOnly(AReadOnly: Boolean);
var
  Data: TXNControlData;
begin
  if AReadOnly then
    Data.uValue := UInt32(kTXNReadOnly)
  else
    Data.uValue := UInt32(kTXNReadWrite);
    
  SetTXNControl(kTXNNoUserIOTag, Data);
end;

{------------------------------------------------------------------------------
  Method:  TCarbonMemo.SetWordWrap
  Params:  AWordWrap - New word wrap

  Sets the word wrap of Carbon memo
 ------------------------------------------------------------------------------}
procedure TCarbonMemo.SetWordWrap(AWordWrap: Boolean);
var
  Data: TXNControlData;
begin
  if AWordWrap then
    Data.uValue := UInt32(kTXNAutoWrap)
  else
    Data.uValue := UInt32(kTXNNoAutoWrap);

  SetTXNControl(kTXNWordWrapStateTag, Data);

  Invalidate;
end;

function TCarbonMemo.SetText(const S: String): Boolean;
begin
  Result:=inherited SetText(S);
  Invalidate;
end;

procedure TCarbonMemo.SetBorderVisible(ABorderVisbile:Boolean);
begin
  FDrawBorder:=ABorderVisbile;
  BoundsChanged;
end;

function TCarbonMemo.SetBounds(const ARect:TRect):Boolean;
var
  r : TRect;
begin
  Result:=inherited SetBounds(ARect);
  BoundsChanged;
  GetBounds(r{%H-});
end;

{------------------------------------------------------------------------------
  Method:  TCarbonMemo.GetLineCount
  Returns: Memo line count
 ------------------------------------------------------------------------------}
function TCarbonMemo.GetLineCount: Integer;
var
  C: ItemCount;
  S: Integer;
  O: TXNObject;
begin
  Result := 0;
  O := HITextViewGetTXNObject(ControlRef(Widget));
  if not OSError(TXNGetLineCount(O, C{%H-}),
      Self, 'GetLineCount', 'TXNGetLineCount') then
  begin
    Result := C;
    S := TXNDataSize(O);
    if S = 0 then Dec(Result);
  end;
end;

{------------------------------------------------------------------------------
  Method:  TCarbonMemo.GetLine
  Returns: Memo line text
 ------------------------------------------------------------------------------}
function TCarbonMemo.GetLine(AIndex: Integer): String;
var
  AStart, AEnd: TXNOffset;
  Data: MacOSAll.Handle;
  W: WideString;
begin
  Result := '';

  GetLineOffset(AIndex, AStart, AEnd);
  if OSError(TXNGetData(HITextViewGetTXNObject(ControlRef(Widget)), AStart, AEnd, Data{%H-}), Self, 'GetLine', 'TXNGetData') then Exit;
  
  W := PWideChar(Data^);

  Result := LazUTF8.UTF16ToUTF8(Copy(W, 0, GetHandleSize(Data) div 2));
  // remove CRLF
  if (Result <> '') and (Result[Length(Result)] in [#10, #13]) then
    Delete(Result, Length(Result), 1);
  if (Result <> '') and (Result[Length(Result)] in [#10, #13]) then
    Delete(Result, Length(Result), 1);

  DisposeHandle(Data);
end;

{------------------------------------------------------------------------------
  Method:  TCarbonMemo.DeleteLine
 ------------------------------------------------------------------------------}
procedure TCarbonMemo.DeleteLine(AIndex: Integer);
var
  AStart, AEnd: TXNOffset;
begin
  GetLineOffset(AIndex, AStart, AEnd);
  // remove line end
  if (AIndex = 0) and (GetLineCount > 1) then Inc(AEnd)
  else
    if AIndex > 0 then Dec(AStart);
  
  OSError(TXNSetData(HITextViewGetTXNObject(ControlRef(Widget)), kTXNUnicodeTextData, nil, 0, AStart, AEnd),
    Self, 'DeleteLine', 'TXNSetData');
end;

{------------------------------------------------------------------------------
  Method:  TCarbonMemo.InsertLine
 ------------------------------------------------------------------------------}
procedure TCarbonMemo.InsertLine(AIndex: Integer; const S: String);
var
  AStart, AEnd: TXNOffset;
  W: WideString;
  LineCnt: Integer;
  p: PWideChar;
const
  // Carbon Line ending should be MacOS classic rather than Unix compatible, see #16267
  CarbonEoln = #13;
begin
  if AIndex < 0 then AIndex := 0;
  W := LazUTF8.UTF8ToUTF16(S);

  LineCnt:=GetLineCount;
  if LineCnt = 0 then
    AStart := 0
  else
  if AIndex < LineCnt then
  begin
    GetLineOffset(AIndex, AStart, AEnd);
    W := W + CarbonEoln;
  end
  else
  begin
    GetLineOffset(LineCnt - 1, AStart, AEnd);
    W := CarbonEoln + W;
    AStart := AEnd;
  end;

  p:=nil;
  if W<>'' then
    p:=@W[1];
  //debugln(['TCarbonMemo.InsertLine Index=',AIndex,' LineCnt=',LineCnt,' AStart=',AStart,' len=',length(W)]);
  OSError(TXNSetData(HITextViewGetTXNObject(ControlRef(Widget)),
    kTXNUnicodeTextData, p, Length(W) * 2, AStart, AStart),
    Self, 'InsertLine', 'TXNSetData');
end;

function TCarbonMemo.GetCaretPos: TPoint;
var
  obj     : TXNObject;
  r       : HIRect;
  cnt     : ItemCount;
  i, ly   : Integer;
  yofs    : Integer;
  fw,fh   : Fixed;
  ofs     : TXNOffset;
  ofs2    : TXNOffset;
  crtpnt  : HIPoint;
begin
  Result.X := 0;
  Result.Y := 0;
  obj:=HITextViewGetTXNObject(Widget);
  if not Assigned(obj) then Exit;

  {looking for the Y-pos}
  TXNGetHIRect(obj, kTXNTextRectKey, r{%H-});
  TXNGetSelection(obj, ofs{%H-}, ofs2{%H-});
  TXNOffsetToHIPoint(obj, ofs, crtpnt{%H-});
  yofs := Round(crtpnt.y);

  TXNGetLineCount(obj, cnt{%H-});
  i := 0;
  ly := Round(r.origin.y);
  while (i{%H-}<cnt) and (ly < yofs) do
  begin
    TXNGetLineMetrics(obj, i, fw{%H-}, fh{%H-});
    inc(i);
    inc(ly, Fix2Long(fh));
  end;
  Result.Y := i;

  {looking for the X-pos}
  crtpnt.X := 0;
  TXNHIPointToOffset(obj, crtpnt, ofs2);
  Result.X := ofs-ofs2;
end;

{------------------------------------------------------------------------------
  Method:  TCarbonMemo.FilterKeyPress

  Filters key presses from being send to Carbon control
 ------------------------------------------------------------------------------}
function TCarbonMemo.FilterKeyPress(SysKey: Boolean; const Char: TUTF8Char): Boolean;
begin
  Result := False;
end;

procedure TCarbonMemo.ProcessKeyEvent(const msg: TLMKey);
var
  txn : TXNObject;
begin
  // CarbonEdit does action on every LM_SYSKEYDOWN
  // But text view does copy/paste action only on LM_SYSUPDOWN (because HICommand is generated on KeyUp event)
  // to avoid double processing (on HICommand and KeyUP event), copy/paste operations should be done on KeyDown event...
  // this's actually LCL (win) memo emulation
  if (msg.Msg = CN_SYSKEYDOWN) then begin
    case msg.CharCode of
      VK_C:
        if (msg.KeyData and (MK_Shift or MK_Control) = 0) then begin
          txn := GetTextObject;
          if Assigned(txn) then TXNCopy(txn);
        end;
      VK_V:
        if (msg.KeyData and (MK_Shift or MK_Control) = 0) then begin
          txn := GetTextObject;
          if Assigned(txn) then TXNPaste(txn);
        end;
      VK_X:
        if (msg.KeyData and (MK_Shift or MK_Control) = 0) then begin
          txn := GetTextObject;
          if Assigned(txn) then TXNCut(txn);
        end;
      VK_Z:
        if ((msg.KeyData and MK_Control) = 0) then begin
          txn := GetTextObject;
          if Assigned(txn) then
            if msg.KeyData and MK_Shift > 0 then TXNRedo(txn)
            else TXNUndo(txn);
        end;
    end; {of case}
  end;
end;



end.


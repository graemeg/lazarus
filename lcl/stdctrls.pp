{
 /***************************************************************************
                               stdctrls.pp
                               -----------

                   Initial Revision : Tue Oct 19 CST 1999

 ***************************************************************************/

 *****************************************************************************
  This file is part of the Lazarus Component Library (LCL)

  See the file COPYING.modifiedLGPL.txt, included in this distribution,
  for details about the license.
 *****************************************************************************
}

unit StdCtrls;

{$mode objfpc}{$H+}
{$I lcl_defines.inc}
{$modeswitch typehelpers}

interface


uses
  Classes, SysUtils, types,
  // LCL
  LCLStrConsts, LCLType, LCLProc, LCLIntf, LMessages, LResources, Graphics,
  ActnList, Controls, Forms, Menus, Themes,
  // LazUtils
  TextStrings, ExtendedStrings, LazUTF8, LazMethodList, LazLoggerBase, LazUtilities;

type

  { TCustomEdit Options}

  TEditCharCase = (ecNormal, ecUppercase, ecLowerCase);
  TEchoMode = (emNormal, emNone, emPassword);

  { TScrollBar }

  TScrollStyle = (ssNone, ssHorizontal, ssVertical, ssBoth,
    ssAutoHorizontal, ssAutoVertical, ssAutoBoth);

  TScrollCode = (
    // !!! Beware. The position of these enums must correspond to the SB_xxx
    // values in LCLType  (Delphi compatibility, not our decision)
    // MWE: Don't know if this still is a requirement
    //      afaik have I removed all casts from the LCL
    scLineUp,   // = SB_LINEUP
    scLineDown, // = SB_LINEDOWN
    scPageUp,   // = SB_PAGEUP
    scPageDown, // = SB_PAGEDOWN
    scPosition, // = SB_THUMBPOSITION
    scTrack,    // = SB_THUMBTRACK
    scTop,      // = SB_TOP
    scBottom,   // = SB_BOTTOM
    scEndScroll // = SB_ENDSCROLL
    );

  TScrollEvent = procedure(Sender: TObject; ScrollCode: TScrollCode;
                           var ScrollPos: Integer) of object;

  { TCustomScrollBar }

  TCustomScrollBar = class(TWinControl)
  private
    FKind: TScrollBarKind;
    FPosition: Integer;
    FMin: Integer;
    FMax: Integer;
    FPageSize: Integer;
    FRTLFactor: Integer;
    FSmallChange: TScrollBarInc;
    FLargeChange: TScrollBarInc;
    FOnChange: TNotifyEvent;
    FOnScroll: TScrollEvent;
    procedure DoScroll(var Message: TLMScroll);
    function NotRightToLeft: Boolean;
    procedure SetKind(Value: TScrollBarKind);
    procedure SetMax(Value: Integer);
    procedure SetMin(Value: Integer);
    procedure SetPosition(Value: Integer);
    procedure SetPageSize(Value: Integer);
    procedure CNHScroll(var Message: TLMHScroll); message LM_HSCROLL;
    procedure CNVScroll(var Message: TLMVScroll); message LM_VSCROLL;
    procedure CNCtlColorScrollBar(var Message: TLMessage); message CN_CTLCOLORSCROLLBAR;
    procedure WMEraseBkgnd(var Message: TLMEraseBkgnd); message LM_ERASEBKGND;
  protected
    class procedure WSRegisterClass; override;
    class function GetControlClassDefaultSize: TSize; override;
    procedure CreateParams(var Params: TCreateParams); override;
    procedure CreateWnd; override;
    procedure Change; virtual;
    procedure Scroll(ScrollCode: TScrollCode; var ScrollPos: Integer); virtual;
    procedure CalculatePreferredSize(var PreferredWidth,
      PreferredHeight: integer; WithThemeSpace: Boolean); override;
  public
    constructor Create(AOwner: TComponent); override;
    procedure SetParams(APosition, AMin, AMax, APageSize: Integer);
    procedure SetParams(APosition, AMin, AMax: Integer);
  public
    property Kind: TScrollBarKind read FKind write SetKind default sbHorizontal;
    property LargeChange: TScrollBarInc read FLargeChange write FLargeChange default 1;
    property Max: Integer read FMax write SetMax default 100;
    property Min: Integer read FMin write SetMin default 0;
    property PageSize: Integer read FPageSize write SetPageSize;
    property Position: Integer read FPosition write SetPosition default 0;
    property SmallChange: TScrollBarInc read FSmallChange write FSmallChange default 1;
    property TabStop default true;
    property OnChange: TNotifyEvent read FOnChange write FOnChange;
    property OnScroll: TScrollEvent read FOnScroll write FOnScroll;
  end;


  { TScrollBar }

  TScrollBar = class(TCustomScrollBar)
  published
    property Align;
    property Anchors;
    property BidiMode;
    property BorderSpacing;
    property Constraints;
    property DoubleBuffered;
    property DragCursor;
    property DragKind;
    property DragMode;
    property Enabled;
    property Kind;
    property LargeChange;
    property Max;
    property Min;
    property PageSize;
    property ParentBidiMode;
    property ParentDoubleBuffered;
    property ParentShowHint;
    property PopupMenu;
    property Position;
    property ShowHint;
    property SmallChange;
    property TabOrder;
    property TabStop;
    property Visible;
    property OnChange;
    property OnContextPopup;
    property OnDragDrop;
    property OnDragOver;
    property OnEndDrag;
    property OnEnter;
    property OnExit;
    property OnKeyDown;
    property OnKeyPress;
    property OnKeyUp;
    property OnScroll;
    property OnStartDrag;
    property OnUTF8KeyPress;
  end;


  { TCustomGroupBox }

  TCustomGroupBox = class(TWinControl)
  protected
    class procedure WSRegisterClass; override;
    class function GetControlClassDefaultSize: TSize; override;

    procedure UpdateOpaque;
    procedure CreateParams(var Params: TCreateParams); override;
    procedure SetColor(Value: TColor); override;
    procedure SetParentBackground(const AParentBackground: Boolean); override;
    procedure CMParentColorChanged(var Message: TLMessage); message CM_PARENTCOLORCHANGED;
  public
    constructor Create(AOwner: TComponent); override;

    property ParentBackground default True;
  end;


  { TGroupBox }

  TGroupBox = class(TCustomGroupBox)
  published
    property Align;
    property Anchors;
    property AutoSize;
    property BidiMode;
    property BorderSpacing;
    property Caption;
    property ChildSizing;
    property ClientHeight;
    property ClientWidth;
    property Color;
    property Constraints;
    property DockSite;
    property DoubleBuffered;
    property DragCursor;
    property DragKind;
    property DragMode;
    property Enabled;
    property Font;
    property ParentBackground;
    property ParentBidiMode;
    property ParentColor;
    property ParentDoubleBuffered;
    property ParentFont;
    property ParentShowHint;
    property PopupMenu;
    property ShowHint;
    property TabOrder;
    property TabStop;
    property Visible;
    property OnChangeBounds;
    property OnClick;
    property OnContextPopup;
    property OnDblClick;
    property OnDragDrop;
    property OnDockDrop;
    property OnDockOver;
    property OnDragOver;
    property OnEndDock;
    property OnEndDrag;
    property OnEnter;
    property OnExit;
    property OnGetSiteInfo;
    property OnKeyDown;
    property OnKeyPress;
    property OnKeyUp;
    property OnMouseDown;
    property OnMouseEnter;
    property OnMouseLeave;
    property OnMouseMove;
    property OnMouseUp;
    property OnMouseWheel;
    property OnMouseWheelDown;
    property OnMouseWheelUp;
    property OnResize;
    property OnStartDock;
    property OnStartDrag;
    property OnUnDock;
    property OnUTF8KeyPress;
  end;

  // Used for TCustomComboBox and TCustomEdit.
  TEmulatedTextHintStatus = (thsHidden, thsShowing, thsChanging);

  { TCustomComboBox }
  TComboBoxAutoCompleteTextOption = (
    cbactEnabled,             //Enable Auto-Completion Feature
    cbactEndOfLineComplete,   //Perform Auto-Complete only when cursor is at end of line
    cbactRetainPrefixCase,    //Retains the case of characters user has typed if is cbactEndOfLineComplete
    cbactSearchCaseSensitive, //Search Text with CaseSensitivity
    cbactSearchAscending      //Search Text from top of the list
  );
  TComboBoxAutoCompleteText = set of TComboBoxAutoCompleteTextOption;
const
  DefaultComboBoxAutoCompleteText = [cbactEndOfLineComplete, cbactSearchAscending];

type
  TComboBoxStyle = (
    csDropDown,         // like an TEdit plus a button to drop down the list, default
    csSimple,           // like an TEdit plus a TListBox
    csDropDownList,     // like TLabel plus a button to drop down the list
    csOwnerDrawFixed,   // like csDropDownList, but custom drawn
    csOwnerDrawVariable,// like csDropDownList, but custom drawn and with each item can have another height
    csOwnerDrawEditableFixed,// like csOwnerDrawFixed, but with TEdit
    csOwnerDrawEditableVariable// like csOwnerDrawVariable, but with TEdit
  );

  TComboBoxStyleHelper = type helper for TComboBoxStyle
  public
    function HasEditBox: Boolean;
    function SetEditBox(const AHasEditBox: Boolean): TComboBoxStyle; // return a style with/without editbox according to the current style
    function IsOwnerDrawn: Boolean;
    function IsVariable: Boolean;
  end;

  TOwnerDrawState = LCLType.TOwnerDrawState;

  TDrawItemEvent = procedure(Control: TWinControl; Index: Integer;
                             ARect: TRect; State: TOwnerDrawState) of object;
  TMeasureItemEvent = procedure(Control: TWinControl; Index: Integer;
                                var AHeight: Integer) of object;

  { TCustomComboBox }

  TCustomComboBox = class(TWinControl)
  private
    FArrowKeysTraverseList: Boolean;
    FAutoCompleteText: TComboBoxAutoCompleteText;
    FAutoSelect: Boolean;
    FAutoSelected: Boolean;
    FAutoDropDown: Boolean;
    FCanvas: TCanvas;
    FCharCase: TEditCharCase;
    FDropDownCount: Integer;
    FDroppedDown: boolean;
    FDroppingDown: Boolean;
    FEditingDone: Boolean;
    FEmulatedTextHintStatus: TEmulatedTextHintStatus;
    FItemHeight: integer;
    FItemIndex: integer;
    FItemWidth: integer;
    FItems: TStrings;
    FMaxLength: integer;
    FOnChange: TNotifyEvent;
    FOnCloseUp: TNotifyEvent;
    FOnDrawItem: TDrawItemEvent;
    FOnDropDown: TNotifyEvent;
    FOnGetItems: TNotifyEvent;
    FOnMeasureItem: TMeasureItemEvent;
    FOnSelect: TNotifyEvent;
    FReadOnly: Boolean;
    FReturnArrowState: Boolean; //used to return the state of arrow keys from termporary change
    FSelLength: integer;
    FSelStart: integer;
    FSorted: boolean;
    FStyle: TComboBoxStyle;
    FTextHint: TTranslateString;
    function GetAutoComplete: boolean;
    function GetDroppedDown: Boolean;
    function GetItemWidth: Integer;
    procedure SetAutoComplete(const AValue: boolean);
    procedure SetArrowKeysTraverseList(Value: Boolean);
    procedure SetItemWidth(const AValue: Integer);
    procedure SetCharCase(eccCharCase: TEditCharCase);
    procedure SetReadOnly(const AValue: Boolean);
    procedure SetTextHint(const AValue: TTranslateString);
    procedure ShowEmulatedTextHintIfYouCan;
    procedure ShowEmulatedTextHint;
    procedure HideEmulatedTextHint;
    procedure UpdateSorted;
    procedure LMDrawListItem(var TheMessage: TLMDrawListItem); message LM_DrawListItem;
    procedure LMMeasureItem(var TheMessage: TLMMeasureItem); message LM_MeasureItem;
    procedure LMSelChange(var TheMessage); message LM_SelChange;
    procedure CNCommand(var TheMessage: TLMCommand); message CN_Command;
    procedure WMChar(var Message: TLMChar); message LM_CHAR;
    procedure WMKillFocus(var Message: TLMKillFocus); message LM_KILLFOCUS;
    procedure WMSetFocus(var Message: TLMSetFocus); message LM_SETFOCUS;
  protected
    class procedure WSRegisterClass; override;
    function CanShowEmulatedTextHint: Boolean; virtual;
    procedure CreateParams(var Params: TCreateParams); override;
    procedure InitializeWnd; override;
    procedure DestroyWnd; override;
    procedure DoEnter; override;
    procedure DoExit; override;
    procedure DrawItem(Index: Integer; ARect: TRect;
                       State: TOwnerDrawState); virtual;
    procedure KeyUpAfterInterface(var Key: Word; Shift: TShiftState); override;
    procedure MeasureItem(Index: Integer; var TheHeight: Integer); virtual;
    class function GetControlClassDefaultSize: TSize; override;
    procedure LMChanged(var Msg); message LM_CHANGED;
    procedure CMWantSpecialKey(var Message: TCMWantSpecialKey); message CM_WANTSPECIALKEY;
    procedure Change; virtual;
    procedure Select; virtual;
    procedure DropDown; virtual;
    procedure GetItems; virtual;
    procedure SetItems(const Value: TStrings); virtual;
    procedure CloseUp; virtual;
    procedure AdjustDropDown; virtual;
    procedure DoAutoAdjustLayout(const AMode: TLayoutAdjustmentPolicy;
      const AXProportion, AYProportion: Double); override;

    function GetItemCount: Integer; //override;
    function GetItemHeight: Integer; virtual;
    function GetSelLength: integer; virtual;
    function GetSelStart: integer; virtual;
    function GetSelText: string; virtual;
    function GetItemIndex: integer; virtual;
    function GetMaxLength: integer; virtual;
    procedure SetDropDownCount(const AValue: Integer); virtual;
    procedure SetDroppedDown(const AValue: Boolean); virtual;
    procedure SetItemHeight(const AValue: Integer); virtual;
    procedure SetItemIndex(const Val: integer); virtual;
    procedure SetMaxLength(AValue: integer); virtual;
    procedure SetSelLength(Val: integer); virtual;
    procedure SetSelStart(Val: integer); virtual;
    procedure SetSelText(const Val: string); virtual;
    procedure SetSorted(Val: boolean); virtual;
    procedure SetStyle(Val: TComboBoxStyle); virtual;
    function  RealGetText: TCaption; override;
    procedure RealSetText(const AValue: TCaption); override;
    procedure KeyDown(var Key: Word; Shift: TShiftState); override;
    procedure KeyUp(var Key: Word; Shift: TShiftState); override;
    procedure UTF8KeyPress(var UTF8Key: TUTF8Char); override;
    procedure MouseUp(Button: TMouseButton; Shift:TShiftState; X, Y: Integer); override;
    function SelectItem(const AnItem: String): Boolean;
    procedure ShouldAutoAdjust(var AWidth, AHeight: Boolean); override;

    property ItemHeight: Integer read GetItemHeight write SetItemHeight;
    property ItemWidth: Integer read GetItemWidth write SetItemWidth default 0;
    property MaxLength: integer read GetMaxLength write SetMaxLength default 0;
    property OnChange: TNotifyEvent read FOnChange write FOnChange;
    property OnCloseUp: TNotifyEvent read FOnCloseUp write FOnCloseUp;
    property OnDrawItem: TDrawItemEvent read FOnDrawItem write FOnDrawItem;
    property OnDropDown: TNotifyEvent read FOnDropDown write FOnDropDown;
    property OnGetItems: TNotifyEvent read FOnGetItems write FOnGetItems;
    property OnMeasureItem: TMeasureItemEvent
      read FOnMeasureItem write FOnMeasureItem;
    property OnSelect: TNotifyEvent read FOnSelect write FOnSelect;
    property ParentColor default false;
    property Sorted: boolean read FSorted write SetSorted default False;
  public
    constructor Create(TheOwner: TComponent); override;
    destructor Destroy; override;
    procedure IntfGetItems;
    procedure AddItem(const Item: String; AnObject: TObject); virtual;
    procedure AddHistoryItem(const Item: string; MaxHistoryCount: integer;
                             SetAsText, CaseSensitive: boolean);
    procedure AddHistoryItem(const Item: string; AnObject: TObject;
                   MaxHistoryCount: integer; SetAsText, CaseSensitive: boolean);
    procedure Clear; virtual;
    procedure ClearSelection; //override;
    property CharCase: TEditCharCase read FCharCase write SetCharCase default ecNormal;
    property DroppedDown: Boolean read GetDroppedDown write SetDroppedDown;
    property DroppingDown: Boolean read FDroppingDown write FDroppingDown; deprecated 'Will be removed in 2.2';
    procedure SelectAll;
    property AutoComplete: boolean read GetAutoComplete write SetAutoComplete default False;
    property AutoCompleteText: TComboBoxAutoCompleteText
                           read FAutoCompleteText write FAutoCompleteText
                           default DefaultComboBoxAutoCompleteText;
    property AutoDropDown: Boolean read FAutoDropDown write FAutoDropDown default False;
    property AutoSelect: Boolean read FAutoSelect write FAutoSelect default True;
    property AutoSelected: Boolean read FAutoSelected write FAutoSelected;
    property AutoSize default True; // Overrides default value
    property ArrowKeysTraverseList: Boolean read FArrowKeysTraverseList
                                    write SetArrowKeysTraverseList default True;
    property Canvas: TCanvas read FCanvas;
    property DropDownCount: Integer read FDropDownCount write SetDropDownCount default 8;
    property EmulatedTextHintStatus: TEmulatedTextHintStatus read FEmulatedTextHintStatus;
    property Items: TStrings read FItems write SetItems;
    property ItemIndex: integer read GetItemIndex write SetItemIndex default -1;
    property ReadOnly: Boolean read FReadOnly write SetReadOnly default False;
    property SelLength: integer read GetSelLength write SetSelLength;// UTF-8 length
    property SelStart: integer read GetSelStart write SetSelStart;// UTF-8 position
    property SelText: String read GetSelText write SetSelText;
    property Style: TComboBoxStyle read FStyle write SetStyle default csDropDown;
    property TabStop default true;
    property Text;
    property TextHint: TTranslateString read FTextHint write SetTextHint;
  end;


  { TComboBox }

  TComboBox = class(TCustomComboBox)
  published
    property Align;
    property Anchors;
    property ArrowKeysTraverseList;
    property AutoComplete;
    property AutoCompleteText;
    property AutoDropDown;
    property AutoSelect;
    property AutoSize;// Note: windows has a fixed height in some styles
    property BidiMode;
    property BorderSpacing;
    property BorderStyle;
    property CharCase;
    property Color;
    property Constraints;
    property DoubleBuffered;
    property DragCursor;
    property DragKind;
    property DragMode;
    property DropDownCount;
    property Enabled;
    property Font;
    property ItemHeight;
    property ItemIndex;
    property Items;
    property ItemWidth;
    property MaxLength;
    property OnChange;
    property OnChangeBounds;
    property OnClick;
    property OnCloseUp;
    property OnContextPopup;
    property OnDblClick;
    property OnDragDrop;
    property OnDragOver;
    property OnDrawItem;
    property OnEndDrag;
    property OnDropDown;
    property OnEditingDone;
    property OnEnter;
    property OnExit;
    property OnGetItems;
    property OnKeyDown;
    property OnKeyPress;
    property OnKeyUp;
    property OnMeasureItem;
    property OnMouseDown;
    property OnMouseEnter;
    property OnMouseLeave;
    property OnMouseMove;
    property OnMouseUp;
    property OnMouseWheel;
    property OnMouseWheelDown;
    property OnMouseWheelUp;
    property OnSelect;
    property OnStartDrag;
    property OnUTF8KeyPress;
    property ParentBidiMode;
    property ParentColor;
    property ParentDoubleBuffered;
    property ParentFont;
    property ParentShowHint;
    property PopupMenu;
    property ReadOnly;
    property ShowHint;
    property Sorted;
    property Style;
    property TabOrder;
    property TabStop;
    property Text;
    property TextHint;
    property Visible;
  end;


  { TCustomListBox }

  TListBoxStyle = (lbStandard, lbOwnerDrawFixed, lbOwnerDrawVariable, lbVirtual);
  TSelectionChangeEvent = procedure(Sender: TObject; User: boolean) of object;
  TListBoxOption = (
    lboDrawFocusRect // draw focus rect in case of owner drawing
    );
  TListBoxOptions = set of TListBoxOption;

  { TCustomListBox }

  TCustomListBox = class(TWinControl)
  private const
    DefOptions = [lboDrawFocusRect];
  private
    FCacheValid: Boolean;
    FCanvas: TCanvas;
    FClickOnSelChange: boolean;
    FClickTriggeredBySelectionChange: Boolean;
    FColumns: Integer;
    FExtendedSelect: boolean;
    FIntegralHeight: boolean;
    FItemHeight: Integer;
    FItemIndex: integer;
    FItems: TStrings;
    FLockSelectionChange: integer;
    FMultiSelect: boolean;
    FOnDrawItem: TDrawItemEvent;
    FOnMeasureItem: TMeasureItemEvent;
    FOnSelectionChange: TSelectionChangeEvent;
    FOptions: TListBoxOptions;
    FScrollWidth: Integer;
    FSorted: boolean;
    FStyle: TListBoxStyle;
    FTopIndex: integer;
    function GetCount: Integer;
    function GetScrollWidth: Integer;
    function GetTopIndex: Integer;
    procedure RaiseIndexOutOfBounds(AIndex: integer);
    procedure SetColumns(const AValue: Integer);
    procedure SetScrollWidth(const AValue: Integer);
    procedure SetTopIndex(const AValue: Integer);
    procedure UpdateSelectionMode;
    procedure UpdateSorted;
    procedure LMDrawListItem(var TheMessage: TLMDrawListItem); message LM_DrawListItem;
    procedure LMMeasureItem(var TheMessage: TLMMeasureItem); message LM_MeasureItem;
    procedure LMSelChange(var TheMessage); message LM_SelChange;
    procedure WMLButtonUp(Var Message: TLMLButtonUp); message LM_LBUTTONUP;
    procedure SendItemSelected(Index: integer; IsSelected: boolean);
    procedure ClearSelectedCache;
    procedure SetSelectedCache(Index: Integer; IsSelected: Boolean);
    function GetSelectedCache(Index: Integer): Boolean;
  protected
    class procedure WSRegisterClass; override;
    procedure AssignItemDataToCache(const AIndex: Integer; const AData: Pointer); virtual; // called to store item data while the handle isn't created
    procedure AssignCacheToItemData(const AIndex: Integer; const AData: Pointer); virtual; // called to restore the itemdata after a handle is created
    procedure BeforeDragStart; override;
    procedure BeginAutoDrag; override;
    function CalculateStandardItemHeight: Integer;
    procedure CreateParams(var Params: TCreateParams); override;
    procedure InitializeWnd; override;
    procedure DestroyWnd; override;
    procedure FinalizeWnd; override;
    class function GetControlClassDefaultSize: TSize; override;
    procedure CheckIndex(const AIndex: Integer);
    function GetItemHeight: Integer;
    function GetItemIndex: integer; virtual;
    function GetSelCount: integer;
    function GetSelected(Index: integer): boolean;
    function GetCachedDataSize: Integer; virtual; // returns the amount of data needed per item
    function GetCachedData(const AIndex: Integer): Pointer;
    procedure SetExtendedSelect(Val: boolean); virtual;
    procedure SetItemIndex(AIndex: integer); virtual;
    procedure SetItems(Value: TStrings); virtual;
    procedure SetItemHeight(Value: Integer);
    procedure SetMultiSelect(Val: boolean); virtual;
    procedure SetSelected(Index: integer; Val: boolean);
    procedure SetSorted(Val: boolean); virtual;
    procedure SetStyle(Val: TListBoxStyle); virtual;
    procedure DrawItem(Index: Integer; ARect: TRect; State: TOwnerDrawState); virtual;
    procedure DoAutoAdjustLayout(const AMode: TLayoutAdjustmentPolicy;
      const AXProportion, AYProportion: Double); override;
    procedure DoSelectionChange(User: Boolean); virtual;
    procedure SendItemIndex;
    procedure WMGetDlgCode(var Message: TLMNoParams); message LM_GETDLGCODE;
  public
    constructor Create(TheOwner: TComponent); override;
    destructor Destroy; override;
    procedure AddItem(const Item: String; AnObject: TObject);
    procedure Click; override; // make it public
    procedure Clear; virtual;
    procedure ClearSelection;
    function GetIndexAtXY(X, Y: integer): integer;
    function GetIndexAtY(Y: integer): integer;
    function GetSelectedText: string;
    function ItemAtPos(const Pos: TPoint; Existing: Boolean): Integer;
    function ItemRect(Index: Integer): TRect;
    function ItemVisible(Index: Integer): boolean;
    function ItemFullyVisible(Index: Integer): boolean;
    procedure LockSelectionChange;
    procedure MakeCurrentVisible;
    procedure MeasureItem(Index: Integer; var TheHeight: Integer); virtual;
    procedure SelectAll; virtual;
    procedure SelectRange(ALow, AHigh: integer; ASelected: boolean); virtual;
    procedure DeleteSelected; virtual;
    procedure UnlockSelectionChange;
  public
    property Align;
    property Anchors;
    property BorderStyle default bsSingle;
    property Canvas: TCanvas read FCanvas;
    property ClickOnSelChange: boolean read FClickOnSelChange
               write FClickOnSelChange default true; // true is Delphi behaviour
    property Columns: Integer read FColumns write SetColumns default 0;
    property Constraints;
    property Count: Integer read GetCount; // for Delphi compatability
    property ExtendedSelect: boolean read FExtendedSelect write SetExtendedSelect default true;
    property Font;
    property IntegralHeight: boolean read FIntegralHeight write FIntegralHeight default False; // not implemented
    property ItemHeight: Integer read GetItemHeight write SetItemHeight;
    property ItemIndex: integer read GetItemIndex write SetItemIndex default -1;
    property Items: TStrings read FItems write SetItems;
    property MultiSelect: boolean read FMultiSelect write SetMultiSelect default False;
    property OnChangeBounds;
    property OnClick;
    property OnDblClick;
    property OnDrawItem: TDrawItemEvent read FOnDrawItem write FOnDrawItem;
    property OnEnter;
    property OnExit;
    property OnKeyDown;
    property OnKeyPress;
    property OnKeyUp;
    property OnMeasureItem: TMeasureItemEvent read FOnMeasureItem write FOnMeasureItem;
    property OnMouseDown;
    property OnMouseEnter;
    property OnMouseLeave;
    property OnMouseMove;
    property OnMouseUp;
    property OnMouseWheel;
    property OnMouseWheelDown;
    property OnMouseWheelUp;
    property OnResize;
    property OnSelectionChange: TSelectionChangeEvent read FOnSelectionChange
                                                      write FOnSelectionChange;
    property OnUTF8KeyPress;
    property Options: TListBoxOptions read FOptions write FOptions default DefOptions;
    property ParentColor default False;
    property ParentFont;
    property ParentShowHint;
    property PopupMenu;
    property ScrollWidth: Integer read GetScrollWidth write SetScrollWidth default 0;
    property SelCount: integer read GetSelCount;
    property Selected[Index: integer]: boolean read GetSelected write SetSelected;
    property ShowHint;
    property Sorted: boolean read FSorted write SetSorted default False;
    property Style: TListBoxStyle read FStyle write SetStyle default lbStandard;
    property TabOrder;
    property TabStop default true;
    property TopIndex: Integer read GetTopIndex write SetTopIndex default 0;
    property Visible;
  end;


  { TListBox }

  TListBox = class(TCustomListBox)
  published
    property Align;
    property Anchors;
    property BidiMode;
    property BorderSpacing;
    property BorderStyle;
    property ClickOnSelChange;
    property Color;
    property Columns;
    property Constraints;
    property DoubleBuffered;
    property DragCursor;
    property DragKind;
    property DragMode;
    property ExtendedSelect;
    property Enabled;
    property Font;
    property IntegralHeight;
    property Items;
    property ItemHeight;
    property ItemIndex;
    property MultiSelect;
    property OnChangeBounds;
    property OnClick;
    property OnContextPopup;
    property OnDblClick;
    property OnDragDrop;
    property OnDragOver;
    property OnDrawItem;
    property OnEnter;
    property OnEndDrag;
    property OnExit;
    property OnKeyPress;
    property OnKeyDown;
    property OnKeyUp;
    property OnMeasureItem;
    property OnMouseDown;
    property OnMouseEnter;
    property OnMouseLeave;
    property OnMouseMove;
    property OnMouseUp;
    property OnMouseWheel;
    property OnMouseWheelDown;
    property OnMouseWheelUp;
    property OnMouseWheelHorz;
    property OnMouseWheelLeft;
    property OnMouseWheelRight;
    property OnResize;
    property OnSelectionChange;
    property OnShowHint;
    property OnStartDrag;
    property OnUTF8KeyPress;
    property Options;
    property ParentBidiMode;
    property ParentColor;
    property ParentDoubleBuffered;
    property ParentShowHint;
    property ParentFont;
    property PopupMenu;
    property ScrollWidth;
    property ShowHint;
    property Sorted;
    property Style;
    property TabOrder;
    property TabStop;
    property TopIndex;
    property Visible;
  end;


  { TCustomEdit }

  TCustomEdit = class(TWinControl)
  private
    FAlignment: TAlignment;
    FAutoSelect: Boolean;
    FAutoSelected: Boolean;
    FCharCase: TEditCharCase;
    fCaretPos: TPoint;
    FEchoMode: TEchoMode;
    FEmulatedTextHintStatus: TEmulatedTextHintStatus;
    FHideSelection: Boolean;
    FMaxLength: Integer;
    FModified: Boolean;
    FOnChangeHandler: TMethodList;
    FPasswordChar: Char;
    FReadOnly: Boolean;
    FNumbersOnly: Boolean;
    FOnChange: TNotifyEvent;
    FSelLength: integer;
    FSelStart: integer;
    FTextChangedByRealSetText: Boolean;
    FTextChangedLock: Boolean;
    FTextHint: TTranslateString;
    procedure ShowEmulatedTextHintIfYouCan;
    procedure ShowEmulatedTextHint;
    procedure HideEmulatedTextHint;
    procedure SetAlignment(const AValue: TAlignment);
    function GetCanUndo: Boolean;
    function GetModified: Boolean;
    procedure SetHideSelection(const AValue: Boolean);
    procedure SetMaxLength(Value: Integer);
    procedure SetModified(Value: Boolean);
    procedure SetPasswordChar(const AValue: Char);
  protected
    class procedure WSRegisterClass; override;
    function CanShowEmulatedTextHint: Boolean; virtual;
    procedure CalculatePreferredSize(var PreferredWidth, PreferredHeight: integer;
                                     WithThemeSpace: Boolean); override;
    procedure CreateParams(var Params: TCreateParams); override;
    procedure InitializeWnd; override;
    procedure TextChanged; override;
    procedure FontChanged(Sender: TObject); override;
    procedure Change; virtual;
    procedure DoEnter; override;
    procedure DoExit; override;
    procedure EditingDone; override;
    function GetCaretPos: TPoint; virtual;
    function GetNumbersOnly: Boolean; virtual;
    function GetReadOnly: Boolean; virtual;
    function GetSelLength: integer; virtual;
    function GetSelStart: integer; virtual;
    function GetSelText: string; virtual;
    function GetTextHint: TTranslateString; virtual;
    procedure SetCaretPos(const Value: TPoint); virtual;
    procedure SetCharCase(Value: TEditCharCase); virtual;
    procedure SetEchoMode(Val: TEchoMode); virtual;
    procedure SetNumbersOnly(Value: Boolean); virtual;
    procedure SetReadOnly(Value: Boolean); virtual;
    procedure SetSelLength(Val: integer); virtual;
    procedure SetSelStart(Val: integer); virtual;
    procedure SetSelText(const Val: string); virtual;
    procedure SetTextHint(const AValue: TTranslateString); virtual;
    function ChildClassAllowed(ChildClass: TClass): boolean; override;
    class function GetControlClassDefaultSize: TSize; override;
    procedure MouseUp(Button: TMouseButton; Shift:TShiftState; X, Y: Integer); override;
    function  RealGetText: TCaption; override;
    procedure RealSetText(const AValue: TCaption); override;
    procedure KeyUpAfterInterface(var Key: Word; Shift: TShiftState); override;
    procedure WMChar(var Message: TLMChar); message LM_CHAR;
    procedure CMWantSpecialKey(var Message: TCMWantSpecialKey); message CM_WANTSPECIALKEY;
    procedure WndProc(var Message: TLMessage); override;
    procedure ShouldAutoAdjust(var AWidth, AHeight: Boolean); override;
    procedure WMSetFocus(var Message: TLMSetFocus); message LM_SETFOCUS;
    procedure WMKillFocus(var Message: TLMKillFocus); message LM_KILLFOCUS;

    property AutoSelect: Boolean read FAutoSelect write FAutoSelect default True;
    property AutoSelected: Boolean read FAutoSelected write FAutoSelected;
    property ParentColor default False;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure Clear;
    procedure SelectAll; virtual;
    procedure ClearSelection; virtual;
    procedure CopyToClipboard; virtual;
    procedure CutToClipboard; virtual;
    procedure PasteFromClipboard; virtual;
    procedure Undo; virtual;

    procedure RemoveAllHandlersOfObject(AnObject: TObject); override;
    procedure AddHandlerOnChange(const AnOnChangeEvent: TNotifyEvent;
      AsFirst: Boolean = False);
    procedure RemoveHandlerOnChange(const AnOnChangeEvent: TNotifyEvent);
  public
    property Alignment: TAlignment read FAlignment write SetAlignment default taLeftJustify;
    property AutoSize default True;
    property BorderStyle default bsSingle;
    property CanUndo: Boolean read GetCanUndo;
    property CaretPos: TPoint read GetCaretPos write SetCaretPos;
    property CharCase: TEditCharCase read FCharCase write SetCharCase default ecNormal;
    property EchoMode: TEchoMode read FEchoMode write SetEchoMode default emNormal;
    property EmulatedTextHintStatus: TEmulatedTextHintStatus read FEmulatedTextHintStatus;
    property HideSelection: Boolean read FHideSelection write SetHideSelection default True;
    property MaxLength: Integer read FMaxLength write SetMaxLength default 0;
    property Modified: Boolean read GetModified write SetModified;
    property NumbersOnly: Boolean read GetNumbersOnly write SetNumbersOnly default false;
    property OnChange: TNotifyEvent read FOnChange write FOnChange;
    property PasswordChar: Char read FPasswordChar write SetPasswordChar default #0;
    property PopupMenu;
    property ReadOnly: Boolean read GetReadOnly write SetReadOnly default false;
    property SelLength: integer read GetSelLength write SetSelLength;
    property SelStart: integer read GetSelStart write SetSelStart;
    property SelText: String read GetSelText write SetSelText;
    property TabOrder;
    property TabStop default true;
    property Text;
    property TextHint: TTranslateString read GetTextHint write SetTextHint;
  end;


  { TMemoScrollbar }

  TMemoScrollbar = class(TControlScrollBar)
  protected
    function GetHorzScrollBar: TControlScrollBar; override;
    function GetVertScrollBar: TControlScrollBar; override;
  public
    property Increment;
    property Page;
    property Smooth;
    property Position;
    property Range;
    property Size;
    property Visible;
  end;


  { TCustomMemo }

  TCustomMemo = class(TCustomEdit)
  private
    FHorzScrollBar: TMemoScrollBar;
    FLines: TStrings;
    FScrollBars: TScrollStyle;
    FVertScrollBar: TMemoScrollBar;
    FWantReturns: Boolean;
    FWantTabs: boolean;
    FWordWrap: Boolean;
  protected
    class procedure WSRegisterClass; override;
    procedure CreateParams(var Params: TCreateParams); override;
    procedure InitializeWnd; override;
    procedure FinalizeWnd; override;
    function  RealGetText: TCaption; override;
    procedure RealSetText(const AValue: TCaption); override;
    function GetCachedText(var CachedText: TCaption): boolean; override;
    function GetCaretPos: TPoint; override;
    procedure KeyUpAfterInterface(var Key: Word; Shift: TShiftState); override;
    procedure SetCaretPos(const AValue: TPoint); override;
    procedure SetLines(const AValue: TStrings);
    procedure SetWantReturns(const AValue: Boolean);
    procedure SetWantTabs(const NewWantTabs: boolean);
    procedure SetWordWrap(const AValue: boolean);
    procedure SetScrollBars(const AValue: TScrollStyle);
    procedure Loaded; override;
    procedure CMWantSpecialKey(var Message: TCMWantSpecialKey); message CM_WANTSPECIALKEY;
    procedure WMGetDlgCode(var Message: TLMGetDlgCode); message LM_GETDLGCODE;
    class function GetControlClassDefaultSize: TSize; override;
    procedure UTF8KeyPress(var UTF8Key: TUTF8Char); override;
    function CanShowEmulatedTextHint: Boolean; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure Append(const AValue: String);
    procedure ScrollBy(DeltaX, DeltaY: Integer); override;
  public
    property Lines: TStrings read FLines write SetLines;
    property HorzScrollBar: TMemoScrollBar read FHorzScrollBar write FHorzScrollBar;
    property VertScrollBar: TMemoScrollBar read FVertScrollBar write FVertScrollBar;
    property ScrollBars: TScrollStyle read FScrollBars write SetScrollBars default ssNone;
    property WantReturns: Boolean read FWantReturns write SetWantReturns default true;
    property WantTabs: Boolean read FWantTabs write SetWantTabs default false;
    property WordWrap: Boolean read FWordWrap write SetWordWrap default true;
  end;


  { TEdit }

  TEdit = class(TCustomEdit)
  public
    property AutoSelected;
  published
    property Align;
    property Alignment;
    property Anchors;
    property AutoSize;
    property AutoSelect;
    property BidiMode;
    property BorderSpacing;
    property BorderStyle;
    property CharCase;
    property Color;
    property Constraints;
    property DoubleBuffered;
    property DragCursor;
    property DragKind;
    property DragMode;
    property EchoMode;
    property Enabled;
    property Font;
    property HideSelection;
    property MaxLength;
    property NumbersOnly;
    property ParentBidiMode;
    property OnChange;
    property OnChangeBounds;
    property OnClick;
    property OnContextPopup;
    property OnDblClick;
    property OnDragDrop;
    property OnDragOver;
    property OnEditingDone;
    property OnEndDrag;
    property OnEnter;
    property OnExit;
    property OnKeyDown;
    property OnKeyPress;
    property OnKeyUp;
    property OnMouseDown;
    property OnMouseEnter;
    property OnMouseLeave;
    property OnMouseMove;
    property OnMouseUp;
    property OnMouseWheel;
    property OnMouseWheelDown;
    property OnMouseWheelUp;
    property OnResize;
    property OnStartDrag;
    property OnUTF8KeyPress;
    property ParentColor;
    property ParentDoubleBuffered;
    property ParentFont;
    property ParentShowHint;
    property PasswordChar;
    property PopupMenu;
    property ReadOnly;
    property ShowHint;
    property TabStop;
    property TabOrder;
    property Text;
    property TextHint;
    property Visible;
  end;


  { TMemo }

  TMemo = class(TCustomMemo)
  published
    property Align;
    property Alignment;
    property Anchors;
    property BidiMode;
    property BorderSpacing;
    property BorderStyle;
    property CharCase;
    property Color;
    property Constraints;
    property DoubleBuffered;
    property DragCursor;
    property DragKind;
    property DragMode;
    property Enabled;
    property Font;
    property HideSelection;
    property Lines;
    property MaxLength;
    property OnChange;
    property OnClick;
    property OnContextPopup;
    property OnDblClick;
    property OnDragDrop;
    property OnDragOver;
    property OnEditingDone;
    property OnEndDrag;
    property OnEnter;
    property OnExit;
    property OnKeyDown;
    property OnKeyPress;
    property OnKeyUp;
    property OnMouseDown;
    property OnMouseEnter;
    property OnMouseLeave;
    property OnMouseMove;
    property OnMouseUp;
    property OnMouseWheel;
    property OnMouseWheelDown;
    property OnMouseWheelUp;
    property OnMouseWheelHorz;
    property OnMouseWheelLeft;
    property OnMouseWheelRight;
    property OnResize;
    property OnStartDrag;
    property OnUTF8KeyPress;
    property ParentBidiMode;
    property ParentColor;
    property ParentDoubleBuffered;
    property ParentFont;
    property PopupMenu;
    property ParentShowHint;
    property ReadOnly;
    property ScrollBars;
    property ShowHint;
    property TabOrder;
    property TabStop;
    property Visible;
    property WantReturns;
    property WantTabs;
    property WordWrap;
  end;


  { TCustomStaticText }

  TStaticBorderStyle = (sbsNone, sbsSingle, sbsSunken);

  TCustomStaticText = class(TWinControl)
  private
    FAlignment: TAlignment;
    FFocusControl: TWinControl;
    FShowAccelChar: boolean;
    FStaticBorderStyle: TStaticBorderStyle;
    function GetTransparent: Boolean;
    procedure SetAlignment(Value: TAlignment);
    procedure SetStaticBorderStyle(Value: TStaticBorderStyle);
    procedure SetTransparent(const AValue: Boolean);
    procedure WMActivate(var Message: TLMActivate); message LM_ACTIVATE;
  protected
    class procedure WSRegisterClass; override;
    function GetLabelText: String ; virtual;
    procedure RealSetText(const AValue: TCaption); override;
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
    procedure SetFocusControl(Val: TWinControl); virtual;
    procedure SetShowAccelChar(Val: boolean); virtual;
    function DialogChar(var Message: TLMKey): boolean; override;
    class function GetControlClassDefaultSize: TSize; override;
  public
    constructor Create(AOwner: TComponent); override;
    property Alignment: TAlignment read FAlignment write SetAlignment default taLeftJustify;
    property BorderStyle: TStaticBorderStyle read FStaticBorderStyle write SetStaticBorderStyle default sbsNone;
    property FocusControl: TWinControl read FFocusControl write SetFocusControl;
    property ShowAccelChar: boolean read FShowAccelChar write SetShowAccelChar default true;
    property Transparent: Boolean read GetTransparent write SetTransparent default True;
  end;


  { TStaticText }

  TStaticText = class(TCustomStaticText)
  published
    property Align;
    property Alignment;
    property Anchors;
    property AutoSize;
    property BidiMode;
    property BorderSpacing;
    property BorderStyle;
    property Caption;
    property Color nodefault;
    property Constraints;
    property DoubleBuffered;
    property DragCursor;
    property DragKind;
    property DragMode;
    property Enabled;
    property FocusControl;
    property Font;
    property OnChangeBounds;
    property OnClick;
    property OnContextPopup;
    property OnDblClick;
    property OnDragDrop;
    property OnDragOver;
    property OnEndDrag;
    property OnMouseDown;
    property OnMouseEnter;
    property OnMouseLeave;
    property OnMouseMove;
    property OnMouseUp;
    property OnMouseWheel;
    property OnMouseWheelDown;
    property OnMouseWheelUp;
    property OnMouseWheelHorz;
    property OnMouseWheelLeft;
    property OnMouseWheelRight;
    property OnResize;
    property OnStartDrag;
    property ParentBidiMode;
    property ParentFont;
    property ParentColor;
    property ParentDoubleBuffered;
    property ParentShowHint;
    property PopupMenu;
    property ShowAccelChar;
    property ShowHint;
    property TabOrder;
    property TabStop;
    property Transparent;
    property Visible;
  end;


  { TButtonControl }

  TButtonControl = class(TWinControl)
  private
    FOnChange: TNotifyEvent;
    FClicksDisabled: Boolean;
    function IsCheckedStored: boolean;
    procedure WMDefaultClicked(var Message: TLMessage); message LM_CLICKED;
  protected
    class procedure WSRegisterClass; override;
    function GetActionLinkClass: TControlActionLinkClass; override;
    function GetChecked: Boolean; virtual;
    procedure SetChecked(Value: Boolean); virtual;
    procedure DoOnChange; virtual;
    procedure Click; override;
  protected
    property Checked: Boolean read GetChecked write SetChecked stored IsCheckedStored default False;
    property ClicksDisabled: Boolean read FClicksDisabled write FClicksDisabled;
    property OnChange: TNotifyEvent read FOnChange write FOnChange;
  public
    constructor Create(TheOwner: TComponent); override;
  end;

  { TButtonActionLink - Finish me }

  TButtonActionLink = class(TWinControlActionLink)
  protected
    FClientButton: TButtonControl;
    procedure AssignClient(AClient: TObject); override;
    procedure SetChecked(Value: Boolean); override;
  public
    function IsCheckedLinked: Boolean; override;
  end;

  TButtonActionLinkClass = class of TButtonActionLink;


  { TCustomButton }

  TCustomButton = class(TButtonControl)
  private
    FModalResult: TModalResult;
    FShortCut: TShortcut;
    FShortCutKey2: TShortcut;
    FCancel: Boolean;
    FDefault: Boolean;
    FActive: boolean;
    FRolesUpdateLocked: Boolean;
    procedure SetCancel(NewCancel: boolean);
    procedure SetDefault(Value: Boolean);
    procedure SetModalResult(const AValue: TModalResult);
    procedure CMUIActivate(var Message: TLMessage); message CM_UIACTIVATE;
    procedure WMSetFocus(var Message: TLMSetFocus); message LM_SETFOCUS;
    procedure WMKillFocus(var Message: TLMKillFocus); message LM_KILLFOCUS;
    procedure UpdateFocus(AFocused: Boolean);
  protected
    class procedure WSRegisterClass; override;
    procedure CreateWnd; override;
    procedure CreateParams(var Params: TCreateParams); override;
    procedure ControlKeyDown(var Key: Word; Shift: TShiftState); override;
    procedure ControlKeyUp(var Key: Word; Shift: TShiftState); override;
    function DialogChar(var Message: TLMKey): boolean; override;
    function ChildClassAllowed(ChildClass: TClass): boolean; override;
    class function GetControlClassDefaultSize: TSize; override;
    property ParentColor default false;
    procedure WSSetDefault;
    procedure WSSetText(const AText: String); override;
    procedure TextChanged; override;
    procedure Loaded; override;
    procedure UpdateDefaultCancel;
  public
    constructor Create(TheOwner: TComponent); override;
    procedure Click; override;
    procedure ExecuteDefaultAction; override;
    procedure ExecuteCancelAction; override;
    procedure ActiveDefaultControlChanged(NewControl: TControl); override;
    procedure UpdateRolesForForm; override;
    function UseRightToLeftAlignment: Boolean; override;
  public
    property Active: boolean read FActive stored false;
    property Default: Boolean read FDefault write SetDefault default false;
    property ModalResult: TModalResult read FModalResult write SetModalResult default mrNone;
    property ShortCut: TShortcut read FShortCut;
    property ShortCutKey2: TShortcut read FShortCutKey2;
    property Cancel: Boolean read FCancel write SetCancel default false;
    property Color default {$ifdef UseCLDefault}clDefault{$else}clBtnFace{$endif};
    property TabStop default true;
  end;


  { TButton }

  TButton = class(TCustomButton)
  published
    property Action;
    property Align;
    property Anchors;
    property AutoSize;
    property BidiMode;
    property BorderSpacing;
    property Cancel;
    property Caption;
    property Color;
    property Constraints;
    property Default;
    property DoubleBuffered;
    property DragCursor;
    property DragKind;
    property DragMode;
    property Enabled;
    property Font;
    property ParentBidiMode;
    property ModalResult;
    property OnChangeBounds;
    property OnClick;
    property OnContextPopup;
    property OnDragDrop;
    property OnDragOver;
    property OnEndDrag;
    property OnEnter;
    property OnExit;
    property OnKeyDown;
    property OnKeyPress;
    property OnKeyUp;
    property OnMouseDown;
    property OnMouseEnter;
    property OnMouseLeave;
    property OnMouseMove;
    property OnMouseUp;
    property OnMouseWheel;
    property OnMouseWheelDown;
    property OnMouseWheelUp;
    property OnResize;
    property OnStartDrag;
    property OnUTF8KeyPress;
    property ParentDoubleBuffered;
    property ParentFont;
    property ParentShowHint;
    property PopupMenu;
    property ShowHint;
    property TabOrder;
    property TabStop;
    property Visible;
  end;

  { TCustomCheckBox }

  TCheckBoxState = (cbUnchecked, cbChecked, cbGrayed);

  { TCustomCheckBox }

  TCustomCheckBox = class(TButtonControl)
  private
    FAlignment: TLeftRight;
    FAllowGrayed: Boolean;
    FState: TCheckBoxState;
    FShortCut: TShortcut;
    FShortCutKey2: TShortcut;
    function GetAlignment: TLeftRight;
    procedure SetAlignment(AValue: TLeftRight);
    procedure SetState(Value: TCheckBoxState);
    function GetState: TCheckBoxState;
    procedure DoChange(var Msg); message LM_CHANGED;
  protected
    class procedure WSRegisterClass; override;
    procedure Click; override;
    procedure DoClickOnChange; virtual;
    function RetrieveState: TCheckBoxState;
    procedure InitializeWnd; override;
    procedure Toggle; virtual;
    function DialogChar(var Message: TLMKey): boolean; override;
    function GetChecked: Boolean; override;
    procedure SetChecked(Value: Boolean); override;
    procedure RealSetText(const Value: TCaption); override;
    procedure ApplyChanges; virtual;
    class function GetControlClassDefaultSize: TSize; override;
    procedure Loaded; override;
    procedure WSSetText(const AText: String); override;
    procedure TextChanged; override;
    procedure CreateParams(var Params: TCreateParams); override;
  public
    constructor Create(TheOwner: TComponent); override;
  public
    property Alignment: TLeftRight read GetAlignment write SetAlignment default taRightJustify;
    property AllowGrayed: Boolean read FAllowGrayed write FAllowGrayed default false;
    property State: TCheckBoxState read GetState write SetState default cbUnchecked;
    property ShortCut: TShortcut read FShortCut;
    property ShortCutKey2: TShortcut read FShortCutKey2;
    property OnChange;
  end;

  // Normal checkbox

  { TCheckBox }

  TCheckBox = class(TCustomCheckBox)
  public
    constructor Create(TheOwner: TComponent); override;
  published
    property Action;
    property Align;
    property Alignment;
    property AllowGrayed;
    property Anchors;
    property AutoSize default True;
    property BidiMode;
    property BorderSpacing;
    property Caption;
    property Checked;
    property Color nodefault;
    property Constraints;
    property DoubleBuffered;
    property DragCursor;
    property DragKind;
    property DragMode;
    property Enabled;
    property Font;
    property Hint;
    property OnChange;
    property OnChangeBounds;
    property OnClick;
    property OnContextPopup;
    property OnDragDrop;
    property OnDragOver;
    property OnEditingDone;
    property OnEndDrag;
    property OnEnter;
    property OnExit;
    property OnKeyPress;
    property OnKeyDown;
    property OnKeyUp;
    property OnMouseDown;
    property OnMouseEnter;
    property OnMouseLeave;
    property OnMouseMove;
    property OnMouseUp;
    property OnMouseWheel;
    property OnMouseWheelDown;
    property OnMouseWheelUp;
    property OnResize;
    property OnStartDrag;
    property OnUTF8KeyPress;
    property ParentColor;
    property ParentDoubleBuffered;
    property ParentFont;
    property ParentShowHint;
    property ParentBidiMode;
    property PopupMenu;
    property ShowHint;
    property State;
    property TabOrder;
    property TabStop default True;
    property Visible;
  end;

  { TToggleBox }

  TToggleBox = class(TCustomCheckBox)
  protected
    class procedure WSRegisterClass; override;
    class function GetControlClassDefaultSize: TSize; override;
    procedure CreateParams(var Params: TCreateParams); override;
    property ParentColor default false;
  public
    constructor Create(TheOwner: TComponent); override;
  published
    property AllowGrayed;
    property Align;
    property Anchors;
    property AutoSize;
    property BidiMode;
    property BorderSpacing;
    property Caption;
    property Checked;
    property Color;
    property Constraints;
    property DoubleBuffered;
    property DragCursor;
    property DragKind;
    property DragMode;
    property Enabled;
    property Font;
    property Hint;
    property OnChange;
    property OnClick;
    property OnContextPopup;
    property OnDragDrop;
    property OnDragOver;
    property OnEndDrag;
    property OnEnter;
    property OnExit;
    property OnMouseDown;
    property OnMouseEnter;
    property OnMouseLeave;
    property OnMouseMove;
    property OnMouseUp;
    property OnMouseWheel;
    property OnMouseWheelDown;
    property OnMouseWheelUp;
    property OnResize;
    property OnStartDrag;
    property ParentBidiMode;
    property ParentDoubleBuffered;
    property ParentFont;
    property ParentShowHint;
    property PopupMenu;
    property ShowHint;
    property State;
    property TabOrder;
    property TabStop default True;
    property Visible;
  end;


  { TRadioButton }

  TRadioButton = class(TCustomCheckBox)
  protected
    class procedure WSRegisterClass; override;
    procedure ApplyChanges; override;
    function DialogChar(var Message: TLMKey): boolean; override;
    procedure RealSetText(const Value: TCaption); override;
    procedure DoClickOnChange; override;
    procedure CreateParams(var Params: TCreateParams); override;
  public
    constructor Create(TheOwner: TComponent); override;
  published
    property Align;
    property Alignment;
    property Anchors;
    property AutoSize default True;
    property BidiMode;
    property BorderSpacing;
    property Caption;
    property Checked;
    property Color;
    property Constraints;
    property DoubleBuffered;
    property DragCursor;
    property DragKind;
    property DragMode;
    property Enabled;
    property Font;
    property Hint;
    property OnChange;
    property OnChangeBounds;
    property OnClick;
    property OnContextPopup;
    property OnDragDrop;
    property OnDragOver;
    property OnEndDrag;
    property OnEnter;
    property OnExit;
    property OnKeyDown;
    property OnKeyPress;
    property OnKeyUp;
    property OnMouseDown;
    property OnMouseEnter;
    property OnMouseLeave;
    property OnMouseMove;
    property OnMouseUp;
    property OnMouseWheel;
    property OnMouseWheelDown;
    property OnMouseWheelUp;
    property OnResize;
    property OnStartDrag;
    property ParentBidiMode;
    property ParentColor;
    property ParentDoubleBuffered;
    property ParentFont;
    property ParentShowHint;
    property PopupMenu;
    property ShowHint;
    property TabOrder;
    property TabStop default False;
    property Visible;
  end;


  { TCustomLabel }

  TCustomLabel = class(TGraphicControl)
  private
    FAlignment: TAlignment;
    FFocusControl: TWinControl;
    FOptimalFill: Boolean;
    FShowAccelChar: Boolean;
    FWordWrap: Boolean;
    FLayout: TTextLayout;
    FInternalSetBounds: Boolean;
    procedure SetAlignment(Value: TAlignment);
    procedure SetOptimalFill(const AValue: Boolean);
  protected
    class procedure WSRegisterClass; override;
    function  CanTab: boolean; override;
    procedure DoDrawText(var Rect: TRect; Flags: Longint); virtual;
    function  HasMultiLine : boolean;
    procedure CalculatePreferredSize(
                         var PreferredWidth, PreferredHeight: integer;
                         WithThemeSpace: Boolean); override;
    procedure CalculateSize(MaxWidth: integer;
                            var NeededWidth, NeededHeight: integer);
    procedure DoAutoSize; override;
    function  DialogChar(var Message: TLMKey): boolean; override;
    procedure TextChanged; override;
    procedure DoSetBounds(ALeft, ATop, AWidth, AHeight: integer); override;
    procedure FontChanged(Sender: TObject); override;
    class function GetControlClassDefaultSize: TSize; override;

    procedure WMActivate(var Message: TLMActivate); message LM_ACTIVATE;
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;

    function  GetLabelText: string; virtual;
    function  GetTransparent: boolean;
    procedure SetColor(NewColor: TColor); override;
    procedure SetFocusControl(Value: TWinControl);
    procedure SetLayout(Value: TTextLayout);
    procedure SetShowAccelChar(Value: Boolean);
    procedure SetTransparent(NewTransparent: boolean);
    procedure SetWordWrap(Value: Boolean);
    procedure Loaded; override;
    procedure UpdateSize;

    property Alignment: TAlignment read FAlignment write SetAlignment default taLeftJustify;
    property FocusControl: TWinControl read FFocusControl write SetFocusControl;
    property Layout: TTextLayout read FLayout write SetLayout default tlTop;
    property ShowAccelChar: Boolean read FShowAccelChar write SetShowAccelChar default true;
    property Transparent: boolean read GetTransparent write SetTransparent default true;
    property WordWrap: Boolean read FWordWrap write SetWordWrap default false;
    property OptimalFill: Boolean read FOptimalFill write SetOptimalFill default false;
  public
    constructor Create(TheOwner: TComponent); override;
    function CalcFittingFontHeight(const TheText: string;
      MaxWidth, MaxHeight: Integer;
      out FontHeight, NeededWidth, NeededHeight: Integer): Boolean;
    function ColorIsStored: boolean; override;
    function AdjustFontForOptimalFill: Boolean;
    procedure Paint; override;
    procedure SetBounds(aLeft, aTop, aWidth, aHeight: integer); override;
    property AutoSize default True;
    property Color default clNone;
    property ParentColor default False;
  end;


  { TLabel }

  TLabel = class(TCustomLabel)
  published
    property Align;
    property Alignment;
    property Anchors;
    property AutoSize;
    property BidiMode;
    property BorderSpacing;
    property Caption;
    property Color;
    property Constraints;
    property DragCursor;
    property DragKind;
    property DragMode;
    property Enabled;
    property FocusControl;
    property Font;
    property Layout;
    property ParentBidiMode;
    property ParentColor;
    property ParentFont;
    property ParentShowHint;
    property PopupMenu;
    property ShowAccelChar;
    property ShowHint;
    property Transparent;
    property Visible;
    property WordWrap;
    property OnChangeBounds;
    property OnClick;
    property OnContextPopup;
    property OnDblClick;
    property OnDragDrop;
    property OnDragOver;
    property OnEndDrag;
    property OnMouseDown;
    property OnMouseEnter;
    property OnMouseLeave;
    property OnMouseMove;
    property OnMouseUp;
    property OnMouseWheel;
    property OnMouseWheelDown;
    property OnMouseWheelUp;
    property OnMouseWheelHorz;
    property OnMouseWheelLeft;
    property OnMouseWheelRight;
    property OnResize;
    property OnStartDrag;
    property OptimalFill;
  end;

function CreateEmulatedTextHintFont(AWinControl: TWinControl): TFont;
procedure Register;


implementation

uses
  WSControls, WSStdCtrls, interfacebase; // Widgetset uses circle is allowed


type
  TMemoStrings = class(TStrings)
  private
    FMemo: TCustomMemo;
    FMemoWidgetClass: TWSCustomMemoClass;
  protected
    function Get(Index: Integer): String; override;
    function GetCount: Integer; override;
  public
    constructor Create(AMemo: TCustomMemo);
    procedure Clear; override;
    procedure Delete(index: Integer); override;
    procedure Insert(index: Integer; const S: String); override;

    property MemoWidgetClass: TWSCustomMemoClass read FMemoWidgetClass write FMemoWidgetClass;
  end;

procedure Register;
begin
  RegisterComponents('Standard',[TButton, TLabel,TEdit,TMemo,TToggleBox,TCheckBox,
       TRadioButton,TListBox,TComboBox,TScrollBar,TGroupBox]);
  RegisterComponents('Additional',[TStaticText]);
end;

procedure InternalDrawItem(Control:TControl; Canvas: TCanvas; ARect:TRect; const Text: string);
var
  OldBrushStyle: TBrushStyle;
  OldTextStyle: TTextStyle;
  NewTextStyle: TTextStyle;
begin
  OldBrushStyle := Canvas.Brush.Style;
  Canvas.Brush.Style := bsClear;

  OldTextStyle := Canvas.TextStyle;
  NewTextStyle := OldTextStyle;
  NewTextStyle.Layout := tlCenter;
  NewTextStyle.RightToLeft := Control.UseRightToLeftReading;
  if Control.UseRightToLeftAlignment then
  begin
    NewTextStyle.Alignment := taRightJustify;
    ARect.Right := ARect.Right - 2;
  end
  else
  begin
    NewTextStyle.Alignment := taLeftJustify;
    ARect.Left := ARect.Left + 2;
  end;

  Canvas.TextStyle := NewTextStyle;

  Canvas.TextRect(ARect, ARect.Left, ARect.Top, Text);
  Canvas.Brush.Style := OldBrushStyle;
  Canvas.TextStyle := OldTextStyle;
end;

// Get font for TextHint in some controls / widgetsets.
function CreateEmulatedTextHintFont(AWinControl: TWinControl): TFont;
begin
  Result := TFont.Create;
  try
    Result.Assign(AWinControl.Font);
    Result.Color := clGrayText;
  except
    FreeAndNil(Result);
    raise;
  end;
end;


{$I customgroupbox.inc}
{$I customcombobox.inc}
{$I customlistbox.inc}
{$I custommemo.inc}
{$I customedit.inc}
{$I customlabel.inc}
{$I customcheckbox.inc}

{$I scrollbar.inc}
{$I memoscrollbar.inc}
{$I memostrings.inc}

{$I buttoncontrol.inc}
{$I buttons.inc}

{$I checkbox.inc}
{$I radiobutton.inc}
{$I togglebox.inc}

{$I customstatictext.inc}

end.

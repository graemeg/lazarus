unit CocoaWSComCtrls;

interface

{$mode delphi}
{$modeswitch objectivec1}
{$include cocoadefines.inc}

{.$DEFINE COCOA_DEBUG_TABCONTROL}
{.$DEFINE COCOA_DEBUG_LISTVIEW}

uses
  // RTL, FCL, LCL
  MacOSAll, CocoaAll,
  Classes, LCLType, SysUtils, Contnrs, LCLMessageGlue, LMessages,
  Controls, ComCtrls, Types, StdCtrls, LCLProc, Graphics, ImgList,
  Math,
  // WS
  WSComCtrls,
  // Cocoa WS
  CocoaPrivate, CocoaScrollers, CocoaTabControls, CocoaUtils,
  CocoaWSCommon, CocoaTables, cocoa_extra, CocoaWSStdCtrls, CocoaGDIObjects, CocoaButtons;

type

  { TCocoaWSStatusBar }

  { TStatusBarCallback }

  TStatusBarCallback = class(TLCLCommonCallback, IStatusBarCallback, ICommonCallback)
    function GetBarsCount: Integer;
    function GetBarItem(idx: Integer; var txt: String; var width: Integer; var align: TAlignment): Boolean;
    procedure DrawPanel(idx: Integer; const r: TRect);
  end;

  TCocoaWSStatusBar = class(TWSStatusBar)
  published
    class function  CreateHandle(const AWinControl: TWinControl; const AParams: TCreateParams): TLCLIntfHandle; override;
    class procedure PanelUpdate(const AStatusBar: TStatusBar; PanelIndex: integer); override;
    class procedure SetPanelText(const AStatusBar: TStatusBar; PanelIndex: integer); override;
    class procedure Update(const AStatusBar: TStatusBar); override;
    //
    class procedure GetPreferredSize(const AWinControl: TWinControl; var PreferredWidth, PreferredHeight: integer; WithThemeSpace: Boolean); override;
  end;

  { TCocoaWSTabSheet }

  TCocoaWSTabSheet = class(TWSTabSheet)
  published
  end;

  { TLCLTabControlCallback }

  TLCLTabControlCallback = class(TLCLCommonCallback, ITabControlCallback)
    procedure willSelectTabViewItem(aTabIndex: Integer);
    procedure didSelectTabViewItem(aTabIndex: Integer);
  end;

  { TCocoaWSCustomPage }

  TCocoaWSCustomPage = class(TWSCustomPage)
  public
    class function  GetCocoaTabPageFromHandle(AHandle: HWND): TCocoaTabPage;
  published
    class function  CreateHandle(const AWinControl: TWinControl; const AParams: TCreateParams): TLCLIntfHandle; override;
    class procedure DestroyHandle(const AWinControl: TWinControl); override;
    class procedure UpdateProperties(const ACustomPage: TCustomPage); override;
    class procedure SetProperties(const ACustomPage: TCustomPage; ACocoaControl: NSTabViewItem);
    //
    class procedure SetBounds(const AWinControl: TWinControl; const ALeft, ATop, AWidth, AHeight: Integer); override;
    class procedure SetText(const AWinControl: TWinControl; const AText: String); override;
    class function GetText(const AWinControl: TWinControl; var AText: String): Boolean; override;
  end;

  { TCocoaWSCustomTabControl }

  TCocoaWSCustomTabControl = class(TWSCustomTabControl)
  private
    class function LCLTabPosToNSTabStyle(AShowTabs: Boolean; ABorderWidth: Integer; ATabPos: TTabPosition): NSTabViewType;
  public
    class function  GetCocoaTabControlHandle(ATabControl: TCustomTabControl): TCocoaTabControl;
  published
    class function CreateHandle(const AWinControl: TWinControl; const AParams: TCreateParams): TLCLIntfHandle; override;

    class procedure AddPage(const ATabControl: TCustomTabControl; const AChild: TCustomPage; const AIndex: integer); override;
    class procedure MovePage(const ATabControl: TCustomTabControl; const AChild: TCustomPage; const NewIndex: integer); override;
    class procedure RemovePage(const ATabControl: TCustomTabControl; const AIndex: integer); override;

    //class function GetNotebookMinTabHeight(const AWinControl: TWinControl): integer; override;
    //class function GetNotebookMinTabWidth(const AWinControl: TWinControl): integer; override;
    //class function GetPageRealIndex(const ATabControl: TCustomTabControl; AIndex: Integer): Integer; override;
    class function GetTabIndexAtPos(const ATabControl: TCustomTabControl; const AClientPos: TPoint): integer; override;
    class function GetTabRect(const ATabControl: TCustomTabControl; const AIndex: Integer): TRect; override;
    class procedure SetPageIndex(const ATabControl: TCustomTabControl; const AIndex: integer); override;
    class procedure SetTabPosition(const ATabControl: TCustomTabControl; const ATabPosition: TTabPosition); override;
    class procedure ShowTabs(const ATabControl: TCustomTabControl; AShowTabs: boolean); override;
  end;

  { TCocoaWSPageControl }

  TCocoaWSPageControl = class(TWSPageControl)
  published
  end;

  { TCocoaWSCustomListView }

  TCocoaListView = TCocoaScrollView;

  { TLCLListViewCallback }

  TLCLListViewCallback = class(TLCLCommonCallback, IListViewCallback)
  public
    listView: TCustomListView;
    tempItemsCountDelta : Integer;

    isSetTextFromWS: Integer; // allows to suppress the notifation about text change
                              // when initiated by Cocoa itself.
    checkedIdx : NSMutableIndexSet;
    ownerData  : Boolean;

    constructor Create(AOwner: NSObject; ATarget: TWinControl; AHandleView: NSView); override;
    destructor Destroy; override;
    function ItemsCount: Integer;
    function GetItemTextAt(ARow, ACol: Integer; var Text: String): Boolean;
    function GetItemCheckedAt(ARow, ACol: Integer; var IsChecked: Integer): Boolean;
    function GetItemImageAt(ARow, ACol: Integer; var imgIdx: Integer): Boolean;
    function GetImageFromIndex(imgIdx: Integer): NSImage;
    procedure SetItemTextAt(ARow, ACol: Integer; const Text: String);
    procedure SetItemCheckedAt(ARow, ACol: Integer; IsChecked: Integer);
    procedure tableSelectionChange(NewSel: Integer; Added, Removed: NSIndexSet);
    procedure ColumnClicked(ACol: Integer);
    procedure DrawRow(rowidx: Integer; ctx: TCocoaContext; const r: TRect;
      state: TOwnerDrawState);
    procedure GetRowHeight(rowidx: Integer; var h: Integer);
  end;
  TLCLListViewCallBackClass = class of TLCLListViewCallback;


  TCocoaWSCustomListView = class(TWSCustomListView)
  private
    class function CheckParams(out AScroll: TCocoaListView; out ATableControl: TCocoaTableListView; const ALV: TCustomListView): Boolean;
    class function CheckParamsCb(out AScroll: TCocoaListView; out ATableControl: TCocoaTableListView; out Cb: TLCLListViewCallback; const ALV: TCustomListView): Boolean;
    class function CheckColumnParams(out ATableControl: TCocoaTableListView;
      out ANSColumn: NSTableColumn; const ALV: TCustomListView; const AIndex: Integer; ASecondIndex: Integer = -1): Boolean;
  published
    class function  CreateHandle(const AWinControl: TWinControl; const AParams: TCreateParams): TLCLIntfHandle; override;
    class procedure SetBorderStyle(const AWinControl: TWinControl; const ABorderStyle: TBorderStyle); override;
    // Column
    class procedure ColumnDelete(const ALV: TCustomListView; const AIndex: Integer); override;
    class function  ColumnGetWidth(const ALV: TCustomListView; const AIndex: Integer; const {%H-}AColumn: TListColumn): Integer; override;
    class procedure ColumnInsert(const ALV: TCustomListView; const AIndex: Integer; const AColumn: TListColumn); override;
    class procedure ColumnMove(const ALV: TCustomListView; const AOldIndex, ANewIndex: Integer; const AColumn: TListColumn); override;
    class procedure ColumnSetAlignment(const ALV: TCustomListView; const AIndex: Integer; const {%H-}AColumn: TListColumn; const AAlignment: TAlignment); override;
    class procedure ColumnSetAutoSize(const ALV: TCustomListView; const AIndex: Integer; const {%H-}AColumn: TListColumn; const AAutoSize: Boolean); override;
    class procedure ColumnSetCaption(const ALV: TCustomListView; const AIndex: Integer; const {%H-}AColumn: TListColumn; const ACaption: String); override;
    class procedure ColumnSetImage(const ALV: TCustomListView; const AIndex: Integer; const {%H-}AColumn: TListColumn; const AImageIndex: Integer); override;
    class procedure ColumnSetMaxWidth(const ALV: TCustomListView; const AIndex: Integer; const {%H-}AColumn: TListColumn; const AMaxWidth: Integer); override;
    class procedure ColumnSetMinWidth(const ALV: TCustomListView; const AIndex: Integer; const {%H-}AColumn: TListColumn; const AMinWidth: integer); override;
    class procedure ColumnSetWidth(const ALV: TCustomListView; const AIndex: Integer; const {%H-}AColumn: TListColumn; const AWidth: Integer); override;
    class procedure ColumnSetVisible(const ALV: TCustomListView; const AIndex: Integer; const {%H-}AColumn: TListColumn; const AVisible: Boolean); override;
    class procedure ColumnSetSortIndicator(const ALV: TCustomListView; const AIndex: Integer; const AColumn: TListColumn; const ASortIndicator: TSortIndicator); override;

    // Item
    class procedure ItemDelete(const ALV: TCustomListView; const AIndex: Integer); override;
    class function  ItemDisplayRect(const ALV: TCustomListView; const AIndex, ASubItem: Integer; ACode: TDisplayCode): TRect; override;
    class function  ItemGetChecked(const ALV: TCustomListView; const AIndex: Integer; const {%H-}AItem: TListItem): Boolean; override;
    class function  ItemGetPosition(const ALV: TCustomListView; const AIndex: Integer): TPoint; override;
    class function  ItemGetState(const ALV: TCustomListView; const AIndex: Integer; const {%H-}AItem: TListItem; const AState: TListItemState; out AIsSet: Boolean): Boolean; override; // returns True if supported
    class procedure ItemInsert(const ALV: TCustomListView; const AIndex: Integer; const {%H-}AItem: TListItem); override;
    class procedure ItemSetChecked(const ALV: TCustomListView; const AIndex: Integer; const {%H-}AItem: TListItem; const AChecked: Boolean); override;
    class procedure ItemSetImage(const ALV: TCustomListView; const AIndex: Integer; const {%H-}AItem: TListItem; const {%H-}ASubIndex, {%H-}AImageIndex: Integer); override;
    //carbon//class function ItemSetPosition(const ALV: TCustomListView; const AIndex: Integer; const ANewPosition: TPoint): Boolean; override;*)
    class procedure ItemSetState(const ALV: TCustomListView; const AIndex: Integer; const {%H-}AItem: TListItem; const AState: TListItemState; const AIsSet: Boolean); override;
    class procedure ItemSetText(const ALV: TCustomListView; const AIndex: Integer; const {%H-}AItem: TListItem; const {%H-}ASubIndex: Integer; const {%H-}AText: String); override;
    class procedure ItemShow(const ALV: TCustomListView; const AIndex: Integer; const {%H-}AItem: TListItem; const PartialOK: Boolean); override;

    // LV
    //available in 10.7 only//class procedure BeginUpdate(const ALV: TCustomListView); override;
    //available in 10.7 only//class procedure EndUpdate(const ALV: TCustomListView); override;

    //class function GetBoundingRect(const ALV: TCustomListView): TRect; override;
    //carbon//class function GetDropTarget(const ALV: TCustomListView): Integer; override;
    class function GetFocused(const ALV: TCustomListView): Integer; override;
    //carbon//class function GetHoverTime(const ALV: TCustomListView): Integer; override;
    class function GetItemAt(const ALV: TCustomListView; x,y: integer): Integer; override;
    class function GetSelCount(const ALV: TCustomListView): Integer; override;
    class function GetSelection(const ALV: TCustomListView): Integer; override;
    class function GetTopItem(const ALV: TCustomListView): Integer; override;
    //class function GetViewOrigin(const ALV: TCustomListView): TPoint; override;
    class function GetVisibleRowCount(const ALV: TCustomListView): Integer; override;

    class procedure SelectAll(const ALV: TCustomListView; const AIsSet: Boolean); override;
    //carbon//class procedure SetAllocBy(const ALV: TCustomListView; const AValue: Integer); override;
    class procedure SetDefaultItemHeight(const ALV: TCustomListView; const AValue: Integer); override;
    //carbon//class procedure SetHotTrackStyles(const ALV: TCustomListView; const AValue: TListHotTrackStyles); override;
    //carbon//class procedure SetHoverTime(const ALV: TCustomListView; const AValue: Integer); override;
    class procedure SetImageList(const ALV: TCustomListView; const {%H-}AList: TListViewImageList; const {%H-}AValue: TCustomImageListResolution); override;
    class procedure SetItemsCount(const ALV: TCustomListView; const Avalue: Integer); override;
    class procedure SetOwnerData(const ALV: TCustomListView; const {%H-}AValue: Boolean); override;
    class procedure SetProperty(const ALV: TCustomListView; const AProp: TListViewProperty; const AIsSet: Boolean); override;
    class procedure SetProperties(const ALV: TCustomListView; const AProps: TListViewProperties); override;
    class procedure SetScrollBars(const ALV: TCustomListView; const AValue: TScrollStyle); override;
    class procedure SetSort(const ALV: TCustomListView; const {%H-}AType: TSortType; const {%H-}AColumn: Integer;
      const {%H-}ASortDirection: TSortDirection); override;
    class function RestoreItemCheckedAfterSort(const ALV: TCustomListView): Boolean; override;
    (*class procedure SetViewOrigin(const ALV: TCustomListView; const AValue: TPoint); override;
    class procedure SetViewStyle(const ALV: TCustomListView; const AValue: TViewStyle); override;*)
  end;

  { TCocoaWSProgressBar }

  TCocoaWSProgressBar = class(TWSProgressBar)
  published
    class function  CreateHandle(const AWinControl: TWinControl; const AParams: TCreateParams): TLCLIntfHandle; override;
    class procedure ApplyChanges(const AProgressBar: TCustomProgressBar); override;
    class procedure SetPosition(const AProgressBar: TCustomProgressBar; const NewPosition: integer); override;
    class procedure SetStyle(const AProgressBar: TCustomProgressBar; const NewStyle: TProgressBarStyle); override;
  end;

  { TCocoaWSCustomUpDown }

  TCocoaWSCustomUpDown = class(TWSCustomUpDown)
  published
    class function CreateHandle(const AWinControl: TWinControl; const AParams: TCreateParams): TLCLIntfHandle; override;
    class procedure SetIncrement(const AUpDown: TCustomUpDown; AValue: Double); override;
    class procedure SetMaxPosition(const AUpDown: TCustomUpDown; AValue: Double); override;
    class procedure SetMinPosition(const AUpDown: TCustomUpDown; AValue: Double); override;
    class procedure SetPosition(const AUpDown: TCustomUpDown; AValue: Double); override;
    class procedure SetWrap(const AUpDown: TCustomUpDown; ADoWrap: Boolean); override;
  end;

  { TCarbonWSUpDown }

  TCarbonWSUpDown = class(TWSUpDown)
  published
  end;

  { TCocoaWSToolButton }

  TCocoaWSToolButton = class(TWSToolButton)
  published
  end;

  { TCarbonWSToolBar }

  TCarbonWSToolBar = class(TWSToolBar)
  published
    //class function  CreateHandle(const AWinControl: TWinControl; const AParams: TCreateParams): TLCLIntfHandle; override;
  end;

  { TCocoaWSTrackBar }

  TCocoaWSTrackBar = class(TWSTrackBar)
  published
    class function  CreateHandle(const AWinControl: TWinControl; const AParams: TCreateParams): TLCLIntfHandle; override;
    class procedure ApplyChanges(const ATrackBar: TCustomTrackBar); override;
    class function  GetPosition(const ATrackBar: TCustomTrackBar): integer; override;
    class procedure SetPosition(const ATrackBar: TCustomTrackBar; const {%H-}NewPosition: integer); override;
    class procedure SetOrientation(const ATrackBar: TCustomTrackBar; const AOrientation: TTrackBarOrientation); override;
    class procedure SetTick(const ATrackBar: TCustomTrackBar; const ATick: integer); override;
    class procedure GetPreferredSize(const AWinControl: TWinControl; var PreferredWidth, PreferredHeight: integer; WithThemeSpace: Boolean); override;
  end;

  { TCocoaWSCustomTreeView }

  TCocoaWSCustomTreeView = class(TWSCustomTreeView)
  published
  end;

  { TCocoaWSTreeView }

  TCocoaWSTreeView = class(TWSTreeView)
  published
  end;

implementation

type

  { TUpdownCommonCallback }

  TUpdownCommonCallback = class(TLCLCommonCallback, IStepperCallback)
    procedure BeforeChange(var Allowed: Boolean);
    procedure Change(NewValue: Double; isUpPressed: Boolean; var Allowed: Boolean);
    procedure UpdownClick(isUpPressed: Boolean);
  end;

type
  TAccessUpDown = class(TCustomUpDown);

{ TUpdownCommonCallback }

procedure TUpdownCommonCallback.BeforeChange(var Allowed: Boolean);
begin
  if Assigned( TAccessUpDown(Target).OnChanging ) then
    TAccessUpDown(Target).OnChanging(Target, Allowed);
end;

procedure TUpdownCommonCallback.Change(NewValue: Double; isUpPressed: Boolean;
  var Allowed: Boolean);
const
  UpDownDir : array [Boolean] of TUpDownDirection = (updUp, updDown);
begin
  if Assigned( TAccessUpDown(Target).OnChangingEx ) then
    TAccessUpDown(Target).OnChangingEx(Target, Allowed,
      Round(NewValue), UpDownDir[isUpPressed]);
end;

procedure TUpdownCommonCallback.UpdownClick(isUpPressed: Boolean);
const
  UpDownBtn : array [Boolean] of TUDBtnType = (btPrev, btNext);
begin
  TAccessUpDown(Target).Position := NSStepper(Owner).intValue;
  if Assigned( TAccessUpDown(Target).OnClick ) then
    TAccessUpDown(Target).OnClick( Target, UpDownBtn[isUpPressed]);
end;

{ TCocoaWSCustomUpDown }

class function TCocoaWSCustomUpDown.CreateHandle(
  const AWinControl: TWinControl; const AParams: TCreateParams): TLCLIntfHandle;
var
  lResult: TCocoaStepper;
begin
  lResult := TCocoaStepper.alloc.lclInitWithCreateParams(AParams);
  if Assigned(lResult) then
  begin
    lResult.callback := TUpdownCommonCallback.Create(lResult, AWinControl);
    //small constrol size looks like carbon
    //lResult.setControlSize(NSSmallControlSize);
    lResult.setTarget(lResult);
    lResult.setAction(objcselector('stepperAction:'));

  end;
  Result := TLCLIntfHandle(lResult);
end;

class procedure TCocoaWSCustomUpDown.SetMinPosition(
  const AUpDown: TCustomUpDown; AValue: Double);
begin
  if not Assigned(AUpDown) or not AUpDown.HandleAllocated then Exit;
  TCocoaStepper(AUpDown.Handle).setMinValue(AValue);
end;

class procedure TCocoaWSCustomUpDown.SetMaxPosition(
  const AUpDown: TCustomUpDown; AValue: Double);
begin
  if not Assigned(AUpDown) or not AUpDown.HandleAllocated then Exit;
  TCocoaStepper(AUpDown.Handle).setMaxValue(AValue);
end;

class procedure TCocoaWSCustomUpDown.SetPosition(const AUpDown: TCustomUpDown;
  AValue: Double);
begin
  if not Assigned(AUpDown) or not AUpDown.HandleAllocated then Exit;
  TCocoaStepper(AUpDown.Handle).lastValue := AValue;
  TCocoaStepper(AUpDown.Handle).setDoubleValue(AValue);
end;

class procedure TCocoaWSCustomUpDown.SetIncrement(const AUpDown: TCustomUpDown;
  AValue: Double);
begin
  if not Assigned(AUpDown) or not AUpDown.HandleAllocated then Exit;
  TCocoaStepper(AUpDown.Handle).setIncrement(AValue);
end;

class procedure TCocoaWSCustomUpDown.SetWrap(const AUpDown: TCustomUpDown;
  ADoWrap: Boolean);
begin
  if not Assigned(AUpDown) or not AUpDown.HandleAllocated then Exit;
  TCocoaStepper(AUpDown.Handle).setValueWraps(ADoWrap);
end;

{ TStatusBarCallback }

function TStatusBarCallback.GetBarsCount: Integer;
begin
  if  TStatusBar(Target).SimplePanel
    then Result := 1
    else Result := TStatusBar(Target).Panels.Count;
end;

function TStatusBarCallback.GetBarItem(idx: Integer; var txt: String;
  var width: Integer; var align: TAlignment): Boolean;
var
  sb : TStatusBar;
begin
  sb := TStatusBar(Target);
  if sb.SimplePanel then begin
    Result := idx = 0;
    if not Result then Exit;
    txt := sb.SimpleText;
    width := sb.Width;
    align := taLeftJustify; // todo: RTL?
  end else begin
    Result := (idx >= 0) and (idx < sb.Panels.Count);
    if not Result then Exit;
    if sb.Panels[idx].Style = psOwnerDraw
      then txt := ''
      else txt := sb.Panels[idx].Text;
    width := sb.Panels[idx].Width;
    align := sb.Panels[idx].Alignment;
  end;
end;

procedure TStatusBarCallback.DrawPanel(idx: Integer; const r: TRect);
var
  sb  : TStatusBar;
  msg : TLMDrawItems;
  ctx : TCocoaContext;
  dr  : TDrawItemStruct;
  fr  : TRect;
  sv  : Integer;
begin
  sb := TStatusBar(Target);
  if sb.SimplePanel then Exit;
  if (idx<0) or (idx >= sb.Panels.Count) then Exit;
  if sb.Panels[idx].Style <> psOwnerDraw then Exit;

  ctx := TCocoaContext.Create(NSGraphicsContext.currentContext);
  sv := ctx.SaveDC;
  try
    FillChar(msg, sizeof(msg), 0);
    FillChar(dr, sizeof(dr), 0);
    msg.Ctl := Target.Handle;
    msg.Msg := LM_DRAWITEM;
    msg.DrawItemStruct := @dr;
    dr.itemID := idx;
    dr._hDC := HDC(ctx);
    dr.rcItem := r;
    fr := NSView(Owner).lclFrame;
    ctx.InitDraw(fr.Right-fr.Left, fr.Bottom-fr.Top);
    LCLMessageGlue.DeliverMessage(Target, msg);
  finally
    ctx.RestoreDC(sv);
    ctx.Free;
  end;
end;

{ TLCLTabControlCallback }

procedure TLCLTabControlCallback.willSelectTabViewItem(aTabIndex: Integer);
var
  Msg: TLMNotify;
  Hdr: TNmHdr;
begin
  if aTabIndex<0 then exit;

  FillChar(Msg, SizeOf(Msg), 0);
  Msg.Msg := LM_NOTIFY;
  FillChar(Hdr, SizeOf(Hdr), 0);

  Hdr.hwndFrom := FTarget.Handle;
  Hdr.Code := TCN_SELCHANGING;
  Hdr.idFrom := TTabControl(Target).TabToPageIndex(ATabIndex);
  Msg.NMHdr := @Hdr;
  Msg.Result := 0;
  LCLMessageGlue.DeliverMessage(Target, Msg);
end;

procedure TLCLTabControlCallback.didSelectTabViewItem(aTabIndex: Integer);
var
  Msg: TLMNotify;
  Hdr: TNmHdr;
begin
  if aTabIndex<0 then exit;

  FillChar(Msg, SizeOf(Msg), 0);
  Msg.Msg := LM_NOTIFY;
  FillChar(Hdr, SizeOf(Hdr), 0);

  Hdr.hwndFrom := FTarget.Handle;
  Hdr.Code := TCN_SELCHANGE;
  Hdr.idFrom := TTabControl(Target).TabToPageIndex(ATabIndex);
  Msg.NMHdr := @Hdr;
  Msg.Result := 0;
  LCLMessageGlue.DeliverMessage(Target, Msg);
end;

{ TCocoaWSStatusBar }

class function TCocoaWSStatusBar.CreateHandle(const AWinControl: TWinControl;
  const AParams: TCreateParams): TLCLIntfHandle;
var
  lResult: TCocoaStatusBar;
  cell   : NSButtonCell;
  cb : TStatusBarCallback;
begin
  Result := 0;
  lResult := TCocoaStatusBar.alloc.lclInitWithCreateParams(AParams);
  if not Assigned(lResult) then Exit;
  Result := TLCLIntfHandle(lResult);

  cb := TStatusBarCallback.Create(lResult, AWinControl);
  lResult.callback := cb;
  lResult.barcallback := cb;
  cb.BlockCocoaUpDown := true;
  //lResult.StatusBar := TStatusBar(AWinControl);

  //todo: get rid of Cells and replace them with views!
  cell:=NSButtonCell(NSButtonCell.alloc).initTextCell(nil);
  // NSSmallSquareBezelStyle aka "Gradient button", is the best looking
  // candidate for the status bar panel. Could be changed to any NSCell class
  // since CocoaStatusBar doesn't suspect any specific cell type.
  cell.setBezelStyle(NSSmallSquareBezelStyle);
  cell.setFont( NSFont.systemFontOfSize( NSFont.smallSystemFontSize ));

  cell.setLineBreakMode(NSLineBreakByClipping);
  //cell.setLineBreakMode(NSLineBreakByTruncatingTail);

  lResult.panelCell := cell;
end;

class procedure TCocoaWSStatusBar.PanelUpdate(const AStatusBar: TStatusBar;
  PanelIndex: integer);
begin
  // todo: can make more effecient
  Update(AStatusBar);
end;

class procedure TCocoaWSStatusBar.SetPanelText(const AStatusBar: TStatusBar;
  PanelIndex: integer);
begin
  Update(AStatusBar);
end;

class procedure TCocoaWSStatusBar.Update(const AStatusBar: TStatusBar);
begin
  if not Assigned(AStatusBar) or not (AStatusBar.HandleAllocated) then Exit;
  {$ifdef BOOLFIX}
  TCocoaStatusBar(AStatusBar.Handle).setNeedsDisplay__(Ord(true));
  {$else}
  TCocoaStatusBar(AStatusBar.Handle).setNeedsDisplay_(true);
  {$endif}
end;

class procedure TCocoaWSStatusBar.GetPreferredSize(const AWinControl: TWinControl;
  var PreferredWidth, PreferredHeight: integer; WithThemeSpace: Boolean);
begin
  PreferredWidth := 0;
  PreferredHeight := STATUSBAR_DEFAULT_HEIGHT;
end;

{ TCocoaWSCustomPage }

class function  TCocoaWSCustomPage.GetCocoaTabPageFromHandle(AHandle: HWND): TCocoaTabPage;
var
  lHandle: TCocoaTabPageView;
begin
  lHandle := TCocoaTabPageView(AHandle);
  Result := lHandle.tabPage;
end;

class function TCocoaWSCustomPage.CreateHandle(const AWinControl: TWinControl; const AParams: TCreateParams): TLCLIntfHandle;
var
  lControl: TCocoaTabPage;
  tv: TCocoaTabPageView;
  tabview: TCocoaTabControl;
begin
  {$IFDEF COCOA_DEBUG_TABCONTROL}
  WriteLn('[TCocoaWSCustomPage.CreateHandle]');
  {$ENDIF}
  lControl := TCocoaTabPage.alloc().init();
  Result := TLCLIntfHandle(lControl);
  if Result <> 0 then
  begin
    //lControl.callback := TLCLCommonCallback.Create(lControl, AWinControl);
    SetProperties(TCustomPage(AWinControl), lControl);

    // Set a special view for the page
    // based on http://stackoverflow.com/questions/14892218/adding-a-nstextview-subview-to-nstabviewitem
    tabview := TCocoaTabControl(AWinControl.Parent.Handle);
    tabview.setAllowsTruncatedLabels(false);
    tv := TCocoaTabPageView.alloc.initWithFrame(NSZeroRect);
    tv.setAutoresizingMask(NSViewWidthSizable or NSViewHeightSizable);
    {tv.setHasVerticalScroller(True);
    tv.setHasHorizontalScroller(True);
    tv.setAutohidesScrollers(True);
    tv.setBorderType(NSNoBorder);}
    tv.tabView := tabview;
    tv.tabPage := lControl;
    tv.callback := TLCLCommonCallback.Create(tv, AWinControl);
    TLCLCommonCallback(tv.callback.GetCallbackObject).BlockCocoaUpDown := true;
    lControl.callback := tv.callback;
    lControl.setView(tv);

    Result := TLCLIntfHandle(tv);
  end;
end;

class procedure TCocoaWSCustomPage.DestroyHandle(const AWinControl: TWinControl);
var
  tv: TCocoaTabPageView;
  ndx: NSInteger;
begin
  tv := TCocoaTabPageView(AWinControl.Handle);
  ndx := tv.tabView.exttabIndexOfTabViewItem(tv.tabPage);
  if (ndx >= 0) and (ndx < tv.tabView.fulltabs.count) then
    tv.tabview.exttabRemoveTabViewItem(tv.tabPage);
  TCocoaWSWinControl.DestroyHandle(AWinControl);
end;

class procedure TCocoaWSCustomPage.UpdateProperties(const ACustomPage: TCustomPage);
var
  lTabPage: TCocoaTabPage;
begin
  {$IFDEF COCOA_DEBUG_TABCONTROL}
  WriteLn('[TCocoaWSCustomTabControl.UpdateProperties] ACustomPage='+IntToStr(PtrInt(ACustomPage)));
  {$ENDIF}
  if not Assigned(ACustomPage) or not ACustomPage.HandleAllocated then Exit;
  lTabPage := GetCocoaTabPageFromHandle(ACustomPage.Handle);
  if Assigned(lTabPage) then SetProperties(ACustomPage, lTabPage);
end;

class procedure TCocoaWSCustomPage.SetProperties(
  const ACustomPage: TCustomPage; ACocoaControl: NSTabViewItem);
var
  lHintStr: string;
begin
  // title
  ACocoaControl.setLabel(ControlTitleToNSStr(ACustomPage.Caption));

  // hint
  if ACustomPage.ShowHint then lHintStr := ACustomPage.Hint
  else lHintStr := '';
  ACocoaControl.setToolTip(NSStringUTF8(lHintStr));
end;

class procedure TCocoaWSCustomPage.SetBounds(const AWinControl: TWinControl;
  const ALeft, ATop, AWidth, AHeight: Integer);
begin
  // Pages should be fixed into their PageControl owner,
  // allowing the TCocoaWSWinControl.SetBounds function to operate here
  // was causing bug 28489
end;

class procedure TCocoaWSCustomPage.SetText(const AWinControl: TWinControl;
  const AText: String);
var
  lTitle: String;
  page  : TCocoaTabPage;
begin
  if not Assigned(AWinControl) or not AWinControl.HandleAllocated then Exit;

  page := GetCocoaTabPageFromHandle(AWinControl.Handle);
  if not Assigned(page) then Exit;
  page.setLabel(ControlTitleToNSStr(AText));
end;

class function TCocoaWSCustomPage.GetText(const AWinControl: TWinControl;
  var AText: String): Boolean;
var
  page  : TCocoaTabPage;
begin
  if not Assigned(AWinControl) or not AWinControl.HandleAllocated then
  begin
    Result := false;
    Exit;
  end;

  page := GetCocoaTabPageFromHandle(AWinControl.Handle);
  AText := NSStringToString( page.label_ );
  Result := true;
end;

{ TCocoaWSCustomTabControl }

class function TCocoaWSCustomTabControl.LCLTabPosToNSTabStyle(AShowTabs: Boolean; ABorderWidth: Integer; ATabPos: TTabPosition): NSTabViewType;
begin
  Result := NSTopTabsBezelBorder;
  if AShowTabs then
  begin
    case ATabPos of
    tpTop:    Result := NSTopTabsBezelBorder;
    tpBottom: Result := NSBottomTabsBezelBorder;
    tpLeft:   Result := NSLeftTabsBezelBorder;
    tpRight:  Result := NSRightTabsBezelBorder;
    end;
  end
  else
  begin
    if ABorderWidth = 0 then
      Result := NSNoTabsNoBorder
    else if ABorderWidth = 1 then
      Result := NSNoTabsLineBorder
    else
      Result := NSNoTabsBezelBorder;
  end;
end;

class function TCocoaWSCustomTabControl.GetCocoaTabControlHandle(ATabControl: TCustomTabControl): TCocoaTabControl;
begin
  Result := nil;
  if ATabControl = nil then Exit;
  if not ATabControl.HandleAllocated then Exit;
  Result := TCocoaTabControl(ATabControl.Handle);
end;

class function TCocoaWSCustomTabControl.CreateHandle(const AWinControl: TWinControl; const AParams: TCreateParams): TLCLIntfHandle;
var
  lControl: TCocoaTabControl;
  lTabControl: TCustomTabControl = nil;
  lTabStyle: NSTabViewType = NSTopTabsBezelBorder;
begin
  lTabControl := TCustomTabControl(AWinControl);
  lControl := TCocoaTabControl.alloc.lclInitWithCreateParams(AParams);
  lTabStyle := LCLTabPosToNSTabStyle(lTabControl.ShowTabs, lTabControl.BorderWidth, lTabControl.TabPosition);
  lControl.setTabViewType(lTabStyle);
  lControl.lclEnabled := AWinControl.Enabled;
  Result := TLCLIntfHandle(lControl);
  if Result <> 0 then
  begin
    lControl.callback := TLCLTabControlCallback.Create(lControl, AWinControl);
    lControl.setDelegate(lControl);
  end;
end;

class procedure TCocoaWSCustomTabControl.AddPage(const ATabControl: TCustomTabControl; const AChild: TCustomPage; const AIndex: integer);
var
  lTabControl: TCocoaTabControl;
  lTabPage: TCocoaTabPage;
begin
  {$IFDEF COCOA_DEBUG_TABCONTROL}
  WriteLn('[TCocoaWSCustomTabControl.AddPage] AChild='+IntToStr(PtrInt(AChild)));
  {$ENDIF}
  if not Assigned(ATabControl) or not ATabControl.HandleAllocated then Exit;
  lTabControl := TCocoaTabControl(ATabControl.Handle);
  AChild.HandleNeeded();
  if not Assigned(AChild) or not AChild.HandleAllocated then Exit;
  lTabPage := TCocoaWSCustomPage.GetCocoaTabPageFromHandle(AChild.Handle);

  lTabControl.exttabInsertTabViewItem_atIndex(lTabPage, AIndex);

  {$IFDEF COCOA_DEBUG_TABCONTROL}
  WriteLn('[TCocoaWSCustomTabControl.AddPage] END');
  {$ENDIF}
end;

class procedure TCocoaWSCustomTabControl.MovePage(const ATabControl: TCustomTabControl; const AChild: TCustomPage; const NewIndex: integer);
var
  lTabControl: TCocoaTabControl;
  lTabPage: TCocoaTabPage;
begin
  if not Assigned(ATabControl) or not ATabControl.HandleAllocated then Exit;
  lTabControl := TCocoaTabControl(ATabControl.Handle);
  AChild.HandleNeeded();
  if not Assigned(AChild) or not AChild.HandleAllocated then Exit;
  lTabPage := TCocoaWSCustomPage.GetCocoaTabPageFromHandle(AChild.Handle);

  lTabControl.exttabremoveTabViewItem(lTabPage);
  lTabControl.exttabinsertTabViewItem_atIndex(lTabPage, NewIndex);
end;

class procedure TCocoaWSCustomTabControl.RemovePage(const ATabControl: TCustomTabControl; const AIndex: integer);
var
  lTabControl: TCocoaTabControl;
  lTabPage: NSTabViewItem;
begin
  if not Assigned(ATabControl) or not ATabControl.HandleAllocated then Exit;
  lTabControl := TCocoaTabControl(ATabControl.Handle);

  lTabPage := NSTabViewItem(lTabControl.fulltabs.objectAtIndex(AIndex));
  lTabControl.exttabremoveTabViewItem(lTabPage);
end;

class function TCocoaWSCustomTabControl.GetTabIndexAtPos(const ATabControl: TCustomTabControl; const AClientPos: TPoint): integer;
var
  lTabControl: TCocoaTabControl;
  lTabPage: NSTabViewItem;
  lClientPos: NSPoint;
  pt : TPoint;
begin
  Result := -1;
  if not Assigned(ATabControl) or not ATabControl.HandleAllocated then Exit;
  lTabControl := TCocoaTabControl(ATabControl.Handle);

  pt.x := Round(AClientPos.x + lTabControl.contentRect.origin.x);
  pt.y := Round(AClientPos.y + lTabControl.contentRect.origin.y);

  if lTabControl.isFlipped then
  begin
    lClientPos.x := pt.X;
    lClientPos.y := pt.Y;
  end
  else
    lClientPos := LCLToNSPoint(pt, lTabControl.frame.size.height);

  lTabPage := lTabControl.tabViewItemAtPoint(lClientPos);
  if not Assigned(lTabPage) then
    Exit;
  Result := lTabControl.exttabIndexOfTabViewItem(lTabPage);
end;

class function TCocoaWSCustomTabControl.GetTabRect(
  const ATabControl: TCustomTabControl; const AIndex: Integer): TRect;
var
  lTabControl: TCocoaTabControl;
  lTabPage: NSTabViewItem;
  tb : TCocoaTabPageView;
  i   : integer;
  idx : integer;
  tr  : TRect;
  w   : array of Double;
  mw  : Double;
  ofs : Double; // aprx offset between label and the text (from both sides)
  x   : Double;
  vt  : NSTabViewType;
begin
  Result:=inherited GetTabRect(ATabControl, AIndex);
  if not Assigned(ATabControl) or not ATabControl.HandleAllocated then Exit;
  lTabControl := TCocoaTabControl(ATabControl.Handle);
  // unable to determine the rectangle view

  if (AIndex<0) or (AIndex>=ATabControl.PageCount) then Exit;
  tb := TCocoaTabPageView(ATabControl.Page[AIndex].Handle);
  if not Assigned(tb) then Exit;

  idx := lTabControl.tabViewItems.indexOfObject( tb.tabPage );
  if (idx = Integer(NSNotFound)) then Exit;

  if not GetTabsRect(lTabControl, tr) then Exit;

  SetLength(w, lTabControl.tabViewItems.count);
  if (length(w) = 0) then Exit; // no tabs!

  vt := lTabControl.tabViewType;
  if (vt = NSTopTabsBezelBorder) or (vt = NSBottomTabsBezelBorder) then
  begin
    mw := 0;
    for i := 0 to Integer(lTabControl.tabViewItems.count)-1 do
    begin
      lTabPage := lTabControl.tabViewItemAtIndex(i);
      w[i] := lTabPage.sizeOfLabel(false).width;
      mw := mw + w[i];
    end;
    if (mw = 0) then Exit; // 0 for the total tabs width?

    ofs := (tr.Right - tr.Left - mw) / length(w);

    x := tr.Left;
    for i := 0 to idx-1 do
      x := x+ofs+w[i];

    Result.Left := Round(x);
    Result.Right := Round(Result.Left + w[idx]);
    Result.Top := tr.Top;
    Result.Bottom := tr.Bottom;
  end
  else
  begin
    mw := 0;
    for i := 0 to Integer(lTabControl.tabViewItems.count)-1 do
    begin
      lTabPage := lTabControl.tabViewItemAtIndex(i);
      w[i] := lTabPage.sizeOfLabel(false).height;
      mw := mw + w[i];
    end;
    if (mw = 0) then Exit; // 0 for the total tabs width?

    ofs := (tr.Bottom - tr.Top - mw) / length(w);

    x := tr.Top;
    for i := 0 to idx-1 do
      x := x+ofs+w[i];

    Result.Left := tr.Left;
    Result.Right := tr.Right;
    Result.Top := Round(x);
    Result.Bottom := Round(Result.Top + w[idx]);
  end;
end;

class procedure TCocoaWSCustomTabControl.SetPageIndex(const ATabControl: TCustomTabControl; const AIndex: integer);
var
  i  : NSInteger;
  tb : TCocoaTabPageView;
begin
  {$IFDEF COCOA_DEBUG_TABCONTROL}
  WriteLn('[TCocoaWSCustomTabControl.SetPageIndex]');
  {$ENDIF}
  if not Assigned(ATabControl) or not ATabControl.HandleAllocated then Exit;
  if (AIndex<0) or (AIndex>=ATabControl.PageCount) then Exit;
  tb := TCocoaTabPageView(ATabControl.Page[AIndex].Handle);
  if not Assigned(tb) then Exit;

  i := TCocoaTabControl(ATabControl.Handle).fulltabs.indexOfObject( tb.tabPage );
  if (i = NSNotFound) then Exit;

  TCocoaTabControl(ATabControl.Handle).ignoreChange := True;
  TCocoaTabControl(ATabControl.Handle).extselectTabViewItemAtIndex(NSInteger(i));
  TCocoaTabControl(ATabControl.Handle).ignoreChange := False;
end;

class procedure TCocoaWSCustomTabControl.SetTabPosition(const ATabControl: TCustomTabControl; const ATabPosition: TTabPosition);
var
  lTabControl: TCocoaTabControl = nil;
  lOldTabStyle, lTabStyle: NSTabViewType;
begin
  if not Assigned(ATabControl) or not ATabControl.HandleAllocated then Exit;
  lTabControl := TCocoaTabControl(ATabControl.Handle);

  lOldTabStyle := lTabControl.tabViewType();
  lTabStyle := LCLTabPosToNSTabStyle(ATabControl.ShowTabs, ATabControl.BorderWidth, ATabPosition);
  lTabControl.setTabViewType(lTabStyle);
end;

class procedure TCocoaWSCustomTabControl.ShowTabs(const ATabControl: TCustomTabControl; AShowTabs: boolean);
var
  lTabControl: TCocoaTabControl = nil;
  lOldTabStyle, lTabStyle: NSTabViewType;
var
  pr : TRect;
  ar : TRect;
  fr : NSRect;
  dx, dy : double;
  cb: ICommonCallback;
begin
  if not Assigned(ATabControl) or not ATabControl.HandleAllocated then Exit;
  lTabControl := TCocoaTabControl(ATabControl.Handle);

  lOldTabStyle := lTabControl.tabViewType();
  lTabStyle := LCLTabPosToNSTabStyle(AShowTabs, ATabControl.BorderWidth, ATabControl.TabPosition);
  pr := lTabControl.lclGetFrameToLayoutDelta;
  lTabControl.setTabViewType(lTabStyle);
  ar := lTabControl.lclGetFrameToLayoutDelta;
  // switching ShowTabs actually changes layout to frame
  // this needs to be compenstated
  if (ar.Top<>pr.Top) or (pr.Left<>ar.Top) then
  begin
    fr := lTabControl.frame;
    dx := pr.Left - ar.left;
    dy := pr.Top - ar.Top;
    fr.origin.x := fr.origin.x + dx;
    fr.origin.y := fr.origin.y + dy;
    fr.size.width := fr.size.width - dx - (ar.Right - pr.Right);
    fr.size.height := fr.size.height - dy - (ar.Bottom - pr.Bottom);
    lTabControl.setFrame(fr);
    cb := lTabControl.lclGetCallback;
    if Assigned(cb) then cb.frameDidChange(lTabControl);
  end;
end;

{ TCocoaWSCustomListView }

class function TCocoaWSCustomListView.CheckParams(
  out AScroll: TCocoaListView;
  out ATableControl: TCocoaTableListView; const ALV: TCustomListView): Boolean;
begin
  Result := False;
  AScroll := nil;
  ATableControl := nil;
  if not Assigned(ALV) or not ALV.HandleAllocated then Exit;
  AScroll := TCocoaListView(ALV.Handle);

  // ToDo: Implement for other styles
  if Assigned(AScroll.documentView) and (AScroll.documentView.isKindOfClass(TCocoaTableListView)) then
  begin
    ATableControl := TCocoaTableListView(AScroll.documentView);
    Result := True;
  end;
end;

class function TCocoaWSCustomListView.CheckParamsCb(out AScroll: TCocoaListView; out ATableControl: TCocoaTableListView; out Cb: TLCLListViewCallback; const ALV: TCustomListView): Boolean;
begin
  Result := CheckParams(AScroll, ATableControl, ALV);
  if Result then
    Cb := TLCLListViewCallback(ATableControl.lclGetCallback.GetCallbackObject)
  else
    Cb := nil;
end;

class function TCocoaWSCustomListView.CheckColumnParams(
  out ATableControl: TCocoaTableListView; out ANSColumn: NSTableColumn;
  const ALV: TCustomListView; const AIndex: Integer; ASecondIndex: Integer
  ): Boolean;
var
  lv : TCocoaListView;
begin
  Result := False;
  ANSColumn := nil;
  if not CheckParams(lv, ATableControl, ALV) then Exit;

  if (AIndex < 0) or (AIndex >= ATableControl.tableColumns.count()) then Exit;
  ANSColumn := NSTableColumn(ATableControl.tableColumns.objectAtIndex(AIndex));
  Result := Assigned(ANSColumn);

  if ASecondIndex >= 0 then
  begin
    if (ASecondIndex < 0) or (ASecondIndex >= ATableControl.tableColumns.count()) then Exit;
  end;
end;

class function TCocoaWSCustomListView.CreateHandle(const AWinControl: TWinControl; const AParams: TCreateParams): TLCLIntfHandle;
var
  lCocoaLV: TCocoaListView;
  lTableLV: TCocoaTableListView;
  ns: NSRect;
  lclcb: TLCLListViewCallback;
  sz: NSSize;
begin
  {$IFDEF COCOA_DEBUG_LISTVIEW}
  WriteLn('[TCocoaWSCustomListView.CreateHandle] AWinControl='+IntToStr(PtrInt(AWinControl)));
  {$ENDIF}
  lCocoaLV := TCocoaListView.alloc.lclInitWithCreateParams(AParams);
  Result := TLCLIntfHandle(lCocoaLV);
  if Result <> 0 then
  begin
    ns := GetNSRect(0, 0, AParams.Width, AParams.Height);
    lTableLV := AllocCocoaTableListView.initWithFrame(ns);
    if lTableLV = nil then
    begin
      lCocoaLV.dealloc;
      Result := 0;
      exit;
    end;

    // Unintuitive things about NSTableView which caused a lot of headaches:
    // 1-> The column header appears only if the NSTableView is inside a NSScrollView
    // 2-> To get proper scrolling use NSScrollView.setDocumentView instead of addSubview
    // Source: http://stackoverflow.com/questions/13872642/nstableview-scrolling-does-not-work
    //lCocoaLV.TableListView := lTableLV;
    lCocoaLV.setDocumentView(lTableLV);
    lCocoaLV.setHasVerticalScroller(True);

    lclcb := TLCLListViewCallback.Create(lTableLV, AWinControl, lCocoaLV);
    lclcb.listView := TCustomListView(AWinControl);
    lTableLV.callback := lclcb;
    lTableLV.setDataSource(lTableLV);
    lTableLV.setDelegate(lTableLV);
    lTableLV.setAllowsColumnReordering(False);
    lTableLV.setAllowsColumnSelection(False);
    lCocoaLV.callback := lclcb;

    ScrollViewSetBorderStyle(lCocoaLV, TCustomListView(AWinControl).BorderStyle);
    UpdateFocusRing(lTableLV, TCustomListView(AWinControl).BorderStyle);

    sz := lTableLV.intercellSpacing;
    // Windows compatibility. on Windows there's no extra space between columns
    sz.width := 0;
    lTableLV.setIntercellSpacing(sz);;
    {$IFDEF COCOA_DEBUG_LISTVIEW}
    WriteLn(Format('[TCocoaWSCustomListView.CreateHandle] headerView=%d', [PtrInt(lTableLV.headerView)]));
    {$ENDIF}
  end;
end;

class procedure TCocoaWSCustomListView.SetBorderStyle(
  const AWinControl: TWinControl; const ABorderStyle: TBorderStyle);
begin
  if not Assigned(AWinControl) or not AWinControl.HandleAllocated then Exit;
  ScrollViewSetBorderStyle(NSScrollView(AWinControl.Handle), ABorderStyle);
  UpdateFocusRing(NSView(NSScrollView(AWinControl.Handle).documentView), ABorderStyle);
end;

class procedure TCocoaWSCustomListView.ColumnDelete(const ALV: TCustomListView;
  const AIndex: Integer);
var
  lTableLV: TCocoaTableListView;
  lNSColumn: NSTableColumn;
begin
  {$IFDEF COCOA_DEBUG_LISTVIEW}
  WriteLn(Format('[TCocoaWSCustomListView.ColumnDelete] AIndex=%d', [AIndex]));
  {$ENDIF}
  if not CheckColumnParams(lTableLV, lNSColumn, ALV, AIndex) then Exit;

  if lNSColumn = nil then Exit;
  lTableLV.removeTableColumn(lNSColumn);
  lNSColumn.release;
end;

class function TCocoaWSCustomListView.ColumnGetWidth(
  const ALV: TCustomListView; const AIndex: Integer; const AColumn: TListColumn
  ): Integer;
var
  lTableLV: TCocoaTableListView;
  lColumn: NSTableColumn;
  sc: TCocoaListView;
begin
  {$IFDEF COCOA_DEBUG_LISTVIEW}
  WriteLn(Format('[TCocoaWSCustomListView.ColumnGetWidth] AIndex=%d', [AIndex]));
  {$ENDIF}
  Result:=0;
  if not CheckParams(sc, lTableLV, ALV) then Exit;
  //if not Assigned(ALV) or not ALV.HandleAllocated then Exit;
  //lTableLV := TCocoaTableListView(TCocoaListView(ALV.Handle).documentView);
  if (AIndex < 0) or (AIndex >= lTableLV.tableColumns.count()) then Exit;

  lColumn := lTableLV.tableColumns.objectAtIndex(AIndex);
  Result := Round(lColumn.width());
end;

class procedure TCocoaWSCustomListView.ColumnInsert(const ALV: TCustomListView;
  const AIndex: Integer; const AColumn: TListColumn);
var
  lTableLV: TCocoaTableListView;
  lNSColumn: NSTableColumn;
  lTitle: NSString;
  sc: TCocoaListView;
begin
  {$IFDEF COCOA_DEBUG_LISTVIEW}
  WriteLn(Format('[TCocoaWSCustomListView.ColumnInsert] ALV=%x AIndex=%d', [PtrInt(ALV), AIndex]));
  {$ENDIF}
  ALV.HandleNeeded();
  //if not Assigned(ALV) or not ALV.HandleAllocated then Exit;
  //lTableLV := TCocoaTableListView(TCocoaListView(ALV.Handle).documentView);
  if not CheckParams(sc, lTableLV, ALV) then Exit;
  {$IFDEF COCOA_DEBUG_LISTVIEW}
  WriteLn(Format('[TCocoaWSCustomListView.ColumnInsert]=> tableColumns.count=%d', [lTableLV.tableColumns.count()]));
  {$ENDIF}
  if (AIndex < 0) or (AIndex >= lTableLV.tableColumns.count()+1) then Exit;
  lTitle := NSStringUTF8(AColumn.Caption);
  lNSColumn := NSTableColumn.alloc.initWithIdentifier(lTitle);
  lNSColumn.headerCell.setStringValue(lTitle);
  lNSColumn.setResizingMask(NSTableColumnUserResizingMask);
  lTableLV.addTableColumn(lNSColumn);
  lTitle.release;
end;

class procedure TCocoaWSCustomListView.ColumnMove(const ALV: TCustomListView;
  const AOldIndex, ANewIndex: Integer; const AColumn: TListColumn);
var
  lTableLV: TCocoaTableListView;
  lNSColumn: NSTableColumn;
begin
  if not CheckColumnParams(lTableLV, lNSColumn, ALV, AOldINdex, ANewIndex) then Exit;
  lTableLV.moveColumn_toColumn(AOldIndex, ANewIndex);
end;

class procedure TCocoaWSCustomListView.ColumnSetAlignment(
  const ALV: TCustomListView; const AIndex: Integer;
  const AColumn: TListColumn; const AAlignment: TAlignment);
var
  lTableLV: TCocoaTableListView;
  lNSColumn: NSTableColumn;
const
  txtAlign : array[TAlignment] of NSTextAlignment = (
    NSLeftTextAlignment, NSRightTextAlignment, NSCenterTextAlignment
  );
begin
  if not CheckColumnParams(lTableLV, lNSColumn, ALV, AIndex) then Exit;
  lTableLV.lclSetColumnAlign(lNSColumn, txtAlign[AAlignment]);
  lTableLV.setNeedsDisplayInRect(lTableLV.rectOfColumn(AIndex));
  lTableLV.headerView.setNeedsDisplayInRect( lTableLV.headerView.headerRectOfColumn(AIndex) );
end;

class procedure TCocoaWSCustomListView.ColumnSetAutoSize(
  const ALV: TCustomListView; const AIndex: Integer;
  const AColumn: TListColumn; const AAutoSize: Boolean);
var
  lTableLV: TCocoaTableListView;
  lNSColumn: NSTableColumn;
  lResizeMask: NSUInteger;
begin
  if not CheckColumnParams(lTableLV, lNSColumn, ALV, AIndex) then Exit;

  if AAutoSize then lResizeMask := NSTableColumnAutoresizingMask or NSTableColumnUserResizingMask
  else lResizeMask := NSTableColumnUserResizingMask;
  lNSColumn.setResizingMask(lResizeMask);
end;

class procedure TCocoaWSCustomListView.ColumnSetCaption(
  const ALV: TCustomListView; const AIndex: Integer;
  const AColumn: TListColumn; const ACaption: String);
var
  lTableLV: TCocoaTableListView;
  lNSColumn: NSTableColumn;
  lNSCaption: NSString;
begin
  if not CheckColumnParams(lTableLV, lNSColumn, ALV, AIndex) then Exit;

  lNSCaption := NSStringUtf8(ACaption);
  if lNSColumn.respondsToSelector(ObjCSelector('setTitle:')) then
    lNSColumn.setTitle(lNSCaption)
  else
    lNSColumn.headerCell.setStringValue(lNSCaption);

  {$ifdef BOOLFIX}
  lTableLV.headerView.setNeedsDisplay__(Ord(true)); // forces the newly set Value (even for setTitle!)
  {$else}
  lTableLV.headerView.setNeedsDisplay_(true); // forces the newly set Value (even for setTitle!)
  {$endif}
  lNSCaption.release;
end;

class procedure TCocoaWSCustomListView.ColumnSetImage(
  const ALV: TCustomListView; const AIndex: Integer;
  const AColumn: TListColumn; const AImageIndex: Integer);
begin
  inherited ColumnSetImage(ALV, AIndex, AColumn, AImageIndex);
end;

class procedure TCocoaWSCustomListView.ColumnSetMaxWidth(
  const ALV: TCustomListView; const AIndex: Integer;
  const AColumn: TListColumn; const AMaxWidth: Integer);
var
  lTableLV: TCocoaTableListView;
  lNSColumn: NSTableColumn;
begin
  {$IFDEF COCOA_DEBUG_LISTVIEW}
  WriteLn(Format('[TCocoaWSCustomListView.ColumnSetMaxWidth] AMaxWidth=%d', [AMaxWidth]));
  {$ENDIF}
  if not CheckColumnParams(lTableLV, lNSColumn, ALV, AIndex) then Exit;

  if AMaxWidth <= 0 then lNSColumn.setMaxWidth($FFFFFFFF)
  else lNSColumn.setMaxWidth(AMaxWidth);
end;

class procedure TCocoaWSCustomListView.ColumnSetMinWidth(
  const ALV: TCustomListView; const AIndex: Integer;
  const AColumn: TListColumn; const AMinWidth: integer);
var
  lTableLV: TCocoaTableListView;
  lNSColumn: NSTableColumn;
begin
  {$IFDEF COCOA_DEBUG_LISTVIEW}
  WriteLn(Format('[TCocoaWSCustomListView.ColumnSetMinWidth] AMinWidth=%d', [AMinWidth]));
  {$ENDIF}
  if not CheckColumnParams(lTableLV, lNSColumn, ALV, AIndex) then Exit;

  lNSColumn.setMinWidth(AMinWidth);
end;

class procedure TCocoaWSCustomListView.ColumnSetWidth(
  const ALV: TCustomListView; const AIndex: Integer;
  const AColumn: TListColumn; const AWidth: Integer);
var
  lTableLV: TCocoaTableListView;
  lNSColumn: NSTableColumn;
begin
  {$IFDEF COCOA_DEBUG_LISTVIEW}
  WriteLn(Format('[TCocoaWSCustomListView.ColumnSetWidth] AWidth=%d', [AWidth]));
  {$ENDIF}
  if not CheckColumnParams(lTableLV, lNSColumn, ALV, AIndex) then Exit;

  lNSColumn.setWidth(AWidth);
end;

class procedure TCocoaWSCustomListView.ColumnSetVisible(
  const ALV: TCustomListView; const AIndex: Integer;
  const AColumn: TListColumn; const AVisible: Boolean);
var
  lTableLV: TCocoaTableListView;
  lNSColumn: NSTableColumn;
begin
  if not CheckColumnParams(lTableLV, lNSColumn, ALV, AIndex) then Exit;
  {$ifdef BOOLFIX}
  lNSColumn.setHidden_(Ord(not AVisible));
  {$else}
  lNSColumn.setHidden(not AVisible);
  {$endif}
end;

class procedure TCocoaWSCustomListView.ColumnSetSortIndicator(
  const ALV: TCustomListView; const AIndex: Integer;
  const AColumn: TListColumn; const ASortIndicator: TSortIndicator);
var
  lTableLV: TCocoaTableListView;
  lNSColumn: NSTableColumn;
begin
  if not CheckColumnParams(lTableLV, lNSColumn, ALV, AIndex) then Exit;

  case ASortIndicator of
    siNone:
     lTableLV.setIndicatorImage_inTableColumn(nil, lNSColumn);
    siAscending:
      lTableLV.setIndicatorImage_inTableColumn(
        NSImage.imageNamed(NSSTR('NSAscendingSortIndicator')),
        lNSColumn);
    siDescending:
      lTableLV.setIndicatorImage_inTableColumn(
        NSImage.imageNamed(NSSTR('NSDescendingSortIndicator')),
        lNSColumn);
  end;
end;

class procedure TCocoaWSCustomListView.ItemDelete(const ALV: TCustomListView;
  const AIndex: Integer);
var
  lCocoaLV: TCocoaListView;
  lTableLV: TCocoaTableListView;
  lclcb : TLCLListViewCallback;
begin
  {$IFDEF COCOA_DEBUG_TABCONTROL}
  WriteLn(Format('[TCocoaWSCustomListView.ItemDelete] AIndex=%d', [AIndex]));
  {$ENDIF}
  if not CheckParamsCb(lCocoaLV, lTableLV, lclcb, ALV) then Exit;

  lclcb.tempItemsCountDelta := -1;
  lclcb.checkedIdx.shiftIndexesStartingAtIndex_by(AIndex, -1);

  lTableLV.lclInsDelRow(AIndex, false);

  lclcb.tempItemsCountDelta := 0;
end;

class function TCocoaWSCustomListView.ItemDisplayRect(
  const ALV: TCustomListView; const AIndex, ASubItem: Integer;
  ACode: TDisplayCode): TRect;
var
  lCocoaLV: TCocoaListView;
  lTableLV: TCocoaTableListView;
begin
  Result:=Bounds(0,0,0,0);
  if not CheckParams(lCocoaLV, lTableLV, ALV) then Exit;
  LCLGetItemRect(lTableLV, AIndex, ASubItem, Result);
  case ACode of
    drLabel: Result := lTableLV.lclGetLabelRect(AIndex, ASubItem, Result);
    drIcon:  Result := lTableLV.lclGetIconRect(AIndex, ASubItem, Result);
  end;
end;

class function TCocoaWSCustomListView.ItemGetChecked(
  const ALV: TCustomListView; const AIndex: Integer; const AItem: TListItem
  ): Boolean;
var
  lclcb : TLCLListViewCallback;
  lCocoaLV: TCocoaListView;
  lTableLV: TCocoaTableListView;
begin
  if not CheckParamsCb(lCocoaLV, lTableLV, lclcb, ALV) then begin
    Result := false;
    Exit;
  end;
  Result := lclcb.checkedIdx.containsIndex(AIndex);
end;

class function TCocoaWSCustomListView.ItemGetPosition(
  const ALV: TCustomListView; const AIndex: Integer): TPoint;
var
  lCocoaLV: TCocoaListView;
  lTableLV: TCocoaTableListView;
  lNSRect: NSRect;
begin
  if not CheckParams(lCocoaLV, lTableLV, ALV) then
  begin
    Result:=Point(0,0);
    Exit;
  end;
  lNSRect := lTableLV.rectOfRow(AIndex);
  Result.X := Round(lNSRect.origin.X);
  Result.Y := Round(lCocoaLV.frame.size.height - lNSRect.origin.Y);
end;

class function TCocoaWSCustomListView.ItemGetState(const ALV: TCustomListView;
  const AIndex: Integer; const AItem: TListItem; const AState: TListItemState;
  out AIsSet: Boolean): Boolean;
var
  lCocoaLV: TCocoaListView;
  lTableLV: TCocoaTableListView;
  lclcb: TLCLListViewCallback;
begin
  case AState of
    lisSelected: begin
      Result := false;
      if not CheckParamsCb(lCocoaLV, lTableLV, lclcb, ALV) then Exit;
      Result := (AIndex>=0) and (AIndex <= lTableLV.numberOfRows);
      AIsSet := lTableLV.isRowSelected(AIndex);
    end;
  else
    Result := inherited ItemGetState(ALV, AIndex, AItem, AState, AIsSet);
  end;
end;

class procedure TCocoaWSCustomListView.ItemInsert(const ALV: TCustomListView;
  const AIndex: Integer; const AItem: TListItem);
var
  lCocoaLV: TCocoaListView;
  lTableLV: TCocoaTableListView;
  lclcb: TLCLListViewCallback;
begin
  {$IFDEF COCOA_DEBUG_TABCONTROL}
  WriteLn(Format('[TCocoaWSCustomListView.ItemInsert] AIndex=%d', [AIndex]));
  {$ENDIF}
  if not CheckParamsCb(lCocoaLV, lTableLV, lclcb, ALV) then Exit;

  lclcb.checkedIdx.shiftIndexesStartingAtIndex_by(AIndex, 1);

  lTableLV.lclInsDelRow(AIndex, true);

  lTableLV.sizeToFit();
end;

class procedure TCocoaWSCustomListView.ItemSetChecked(
  const ALV: TCustomListView; const AIndex: Integer; const AItem: TListItem;
  const AChecked: Boolean);
var
  lCocoaLV: TCocoaListView;
  lTableLV: TCocoaTableListView;
  cb : TLCLListViewCallback;
begin
  if not CheckParamsCb(lCocoaLV, lTableLV, cb, ALV) then Exit;
  // todo: make a specific row/column reload data!

  if AChecked and not cb.checkedIdx.containsIndex(AIndex) then
  begin
    cb.checkedIdx.addIndex(AIndex);
    lTableLV.reloadDataForRow_column(AIndex, 0);
  end
  else
  if not AChecked and cb.checkedIdx.containsIndex(AIndex) then
  begin
    cb.checkedIdx.removeIndex(AIndex);
    lTableLV.reloadDataForRow_column(AIndex, 0);
  end;
end;

class procedure TCocoaWSCustomListView.ItemSetImage(const ALV: TCustomListView;
  const AIndex: Integer; const AItem: TListItem; const ASubIndex,
  AImageIndex: Integer);
var
  lCocoaLV: TCocoaListView;
  lTableLV: TCocoaTableListView;
begin
  if not CheckParams(lCocoaLV, lTableLV, ALV) then Exit;
  lTableLV.reloadDataForRow_column(AIndex, ASubIndex);
end;

class procedure TCocoaWSCustomListView.ItemSetState(const ALV: TCustomListView;
  const AIndex: Integer; const AItem: TListItem; const AState: TListItemState;
  const AIsSet: Boolean);
var
  lCocoaLV: TCocoaListView;
  lTableLV: TCocoaTableListView;
  row : Integer;
  isSel : Boolean;
begin
  if not CheckParams(lCocoaLV, lTableLV, ALV) or not Assigned(AItem) then Exit;

  row := AItem.Index;
  if (row < 0) or (row >= lTableLV.numberOfRows) then Exit;

  case AState of
    lisSelected:
    begin
      isSel := lTableLV.selectedRowIndexes.containsIndex(row);
      if AIsSet and not isSel then
        lTableLV.selectRowIndexes_byExtendingSelection(NSIndexSet.indexSetWithIndex(row),false)
      else if not AIsSet and isSel then
        lTableLV.deselectRow(row);
    end;
  else
    inherited ItemSetState(ALV, AIndex, AItem, AState, AIsSet);
  end;
end;

class procedure TCocoaWSCustomListView.ItemSetText(const ALV: TCustomListView;
  const AIndex: Integer; const AItem: TListItem; const ASubIndex: Integer;
  const AText: String);
var
  lCocoaLV: TCocoaListView;
  lTableLV: TCocoaTableListView;
begin
  if not CheckParams(lCocoaLV, lTableLV, ALV) then Exit;
  lTableLV.reloadDataForRow_column(AIndex, ASubIndex);
end;

class procedure TCocoaWSCustomListView.ItemShow(const ALV: TCustomListView;
  const AIndex: Integer; const AItem: TListItem; const PartialOK: Boolean);
begin
  inherited ItemShow(ALV, AIndex, AItem, PartialOK);
end;

class function TCocoaWSCustomListView.GetFocused(const ALV: TCustomListView): Integer;
var
  lCocoaLV: TCocoaListView;
  lTableLV: TCocoaTableListView;
begin
  if not CheckParams(lCocoaLV, lTableLV, ALV) then
  begin
    Result:=-1;
    Exit;
  end;
  Result := lTableLV.selectedRow;
  {$IFDEF COCOA_DEBUG_TABCONTROL}
  WriteLn(Format('[TCocoaWSCustomListView.GetFocused] Result=%d', [Result]));
  {$ENDIF}
end;

class function TCocoaWSCustomListView.GetItemAt(const ALV: TCustomListView; x,
  y: integer): Integer;
var
  lCocoaLV: TCocoaListView;
  lTableLV: TCocoaTableListView;
begin
  if not CheckParams(lCocoaLV, lTableLV, ALV) then
  begin
    Result:=-1;
    Exit;
  end;
  Result := LCLCoordToRow(lTableLV, x,y);
end;

class function TCocoaWSCustomListView.GetSelCount(const ALV: TCustomListView): Integer;
var
  lCocoaLV: TCocoaListView;
  lTableLV: TCocoaTableListView;
begin
  if not CheckParams(lCocoaLV, lTableLV, ALV) then
  begin
    Result:=0;
    Exit;
  end;
  Result := lTableLV.selectedRowIndexes().count();
end;

class function TCocoaWSCustomListView.GetSelection(const ALV: TCustomListView): Integer;
var
  lCocoaLV: TCocoaListView;
  lTableLV: TCocoaTableListView;
begin
  if not CheckParams(lCocoaLV, lTableLV, ALV) then
  begin
    Result:=-1;
    Exit;
  end;
  Result := lTableLV.selectedRow;
  {$IFDEF COCOA_DEBUG_TABCONTROL}
  WriteLn(Format('[TCocoaWSCustomListView.GetSelection] Result=%d', [Result]));
  {$ENDIF}
end;

class function TCocoaWSCustomListView.GetTopItem(const ALV: TCustomListView): Integer;
var
  lCocoaLV: TCocoaListView;
  lTableLV: TCocoaTableListView;
begin
  if not CheckParams(lCocoaLV, lTableLV, ALV) then
  begin
    Result:=-1;
    Exit;
  end;
  Result := LCLGetTopRow(lTableLV);
end;

class function TCocoaWSCustomListView.GetVisibleRowCount(
  const ALV: TCustomListView): Integer;
var
  lCocoaLV: TCocoaListView;
  lTableLV: TCocoaTableListView;
  lVisibleRows: NSRange;
begin
  if not CheckParams(lCocoaLV, lTableLV, ALV) then
  begin
    Result := 0;
    Exit;
  end;
  lVisibleRows := lTableLV.rowsInRect(lTableLV.visibleRect());
  Result := lVisibleRows.length;
end;

class procedure TCocoaWSCustomListView.SelectAll(const ALV: TCustomListView;
  const AIsSet: Boolean);
var
  lCocoaLV: TCocoaListView;
  lTableLV: TCocoaTableListView;
begin
  if not CheckParams(lCocoaLV, lTableLV, ALV) then Exit;
  if AIsSet then
    lTableLV.selectAll(lTableLV)
  else
    lTableLV.deselectAll(lTableLV);
end;

class procedure TCocoaWSCustomListView.SetDefaultItemHeight(
  const ALV: TCustomListView; const AValue: Integer);
var
  lCocoaLV: TCocoaListView;
  lTableLV: TCocoaTableListView;
begin
  if not CheckParams(lCocoaLV, lTableLV, ALV) then Exit;
  if AValue > 0 then
    lTableLV.setRowHeight(AValue);
  // setRowSizeStyle could be used here but is available only in 10.7+
end;

class procedure TCocoaWSCustomListView.SetImageList(const ALV: TCustomListView;
  const AList: TListViewImageList; const AValue: TCustomImageListResolution);
var
  lCocoaLV: TCocoaListView;
  lTableLV: TCocoaTableListView;
begin
  if not CheckParams(lCocoaLV, lTableLV, ALV) then Exit;
  lTableLV.lclSetImagesInCell(Assigned(AValue));
end;

class procedure TCocoaWSCustomListView.SetItemsCount(
  const ALV: TCustomListView; const Avalue: Integer);
var
  lCocoaLV: TCocoaListView;
  lTableLV: TCocoaTableListView;
begin
  if not CheckParams(lCocoaLV, lTableLV, ALV) then Exit;
  lTableLV.noteNumberOfRowsChanged();
end;

class procedure TCocoaWSCustomListView.SetOwnerData(const ALV: TCustomListView;
  const AValue: Boolean);
var
  lCocoaLV : TCocoaListView;
  lTableLV : TCocoaTableListView;
  cb       : TLCLListViewCallback;
begin
  if not CheckParamsCb(lCocoaLV, lTableLV, cb, ALV) then Exit;
  cb.ownerData := AValue;
  if cb.ownerData then cb.checkedIdx.removeAllIndexes; // releasing memory
end;

class procedure TCocoaWSCustomListView.SetProperty(const ALV: TCustomListView;
  const AProp: TListViewProperty; const AIsSet: Boolean);
var
  lCocoaLV: TCocoaListView;
  lTableLV: TCocoaTableListView;
const
  GridStyle : array [boolean] of NSUInteger = (
    NSTableViewGridNone,
    NSTableViewSolidHorizontalGridLineMask or NSTableViewSolidVerticalGridLineMask
  );
begin
  if not CheckParams(lCocoaLV, lTableLV, ALV) then Exit;
  case AProp of
  {lvpAutoArrange,}
  lvpCheckboxes: lTableLV.lclSetFirstColumCheckboxes(AIsSet);
 // lvpColumnClick: lTableLV.setAllowsColumnSelection(AIsSet);
{  lvpFlatScrollBars,
  lvpFullDrag,}
  lvpGridLines: lTableLV.setGridStyleMask(GridStyle[AIsSet]);
  {lvpHideSelection,
  lvpHotTrack,}
  lvpMultiSelect: lTableLV.setAllowsMultipleSelection(AIsSet);
  {lvpOwnerDraw,}
  lvpReadOnly: lTableLv.readOnly := AIsSet;
{  lvpRowSelect,}
  lvpShowColumnHeaders:
    if (AIsSet <> Assigned(lTableLV.headerView)) then
    begin
      if AIsSet then lTableLv.setHeaderView ( NSTableHeaderView.alloc.init )
      else lTableLv.setHeaderView(nil);
    end;
{  lvpShowWorkAreas,
  lvpWrapText,
  lvpToolTips}
  end;
end;

class procedure TCocoaWSCustomListView.SetProperties(
  const ALV: TCustomListView; const AProps: TListViewProperties);
begin
  inherited SetProperties(ALV, AProps);
end;

class procedure TCocoaWSCustomListView.SetScrollBars(
  const ALV: TCustomListView; const AValue: TScrollStyle);
var
  lTableLV: TCocoaTableListView;
  lCocoaLV: TCocoaListView;
begin
  if not CheckParams(lCocoaLV, lTableLV, ALV) then Exit;

  ScrollViewSetScrollStyles(lCocoaLV, AValue);

  {$ifdef BOOLFIX}
  lCocoaLV.setNeedsDisplay__(Ord(true));
  {$else}
  lCocoaLV.setNeedsDisplay_(true);
  {$endif}

  {$ifdef BOOLFIX}
  lCocoaLV.documentView.setNeedsDisplay__(Ord(true));
  {$else}
  lCocoaLV.documentView.setNeedsDisplay_(true);
  {$endif}
end;

class procedure TCocoaWSCustomListView.SetSort(const ALV: TCustomListView;
  const AType: TSortType; const AColumn: Integer;
  const ASortDirection: TSortDirection);
var
  lTableLV: TCocoaTableListView;
  lCocoaLV: TCocoaListView;
  lNSColumn: NSTableColumn;
  Cb: TLCLListViewCallback;
begin
  if not CheckColumnParams(lTableLV, lNSColumn, ALV, AColumn) then Exit;
  if not CheckParamsCb(lCocoaLV, lTableLV, cb, ALV) then Exit;

  cb.checkedIdx.removeAllIndexes;
  lTableLV.reloadData();
  { //todo:
    lNSColumn.setSortDescriptorPrototype(
    NSSortDescriptor.sortDescriptorWithKey_ascending_selector(
      NSSTR('none'),
      ASortDirection=sdAscending,
      objcselector('none:')
    )
  );}
end;

class function TCocoaWSCustomListView.RestoreItemCheckedAfterSort(
  const ALV: TCustomListView): Boolean;
begin
  Result:=true;
end;

{ TCocoaWSProgressBar }

class function TCocoaWSProgressBar.CreateHandle(const AWinControl: TWinControl;
  const AParams: TCreateParams): TLCLIntfHandle;
var
  lResult: TCocoaProgressIndicator;
begin
  lResult := TCocoaProgressIndicator.alloc.lclInitWithCreateParams(AParams);
  if Assigned(lResult) then
  begin
    lResult.callback := TLCLCommonCallback.Create(lResult, AWinControl);
    lResult.startAnimation(nil);
    //small constrol size looks like carbon
    //lResult.setControlSize(NSSmallControlSize);
  end;
  Result := TLCLIntfHandle(lResult);
end;

class procedure TCocoaWSProgressBar.ApplyChanges(
  const AProgressBar: TCustomProgressBar);
var
  ind : NSProgressIndicator;
begin
  if not Assigned(AProgressBar) or not AProgressBar.HandleAllocated then Exit;
  ind:=NSProgressIndicator(AProgressBAr.Handle);
  ind.setMaxValue(AProgressBar.Max);
  ind.setMinValue(AProgressBar.Min);
  ind.setDoubleValue(AProgressBar.Position);
  SetStyle(AProgressBar, AProgressBar.Style);
end;

class procedure TCocoaWSProgressBar.SetPosition(
  const AProgressBar: TCustomProgressBar; const NewPosition: integer);
begin
  if AProgressBar.HandleAllocated then
    NSProgressIndicator(AProgressBar.Handle).setDoubleValue(NewPosition);
end;

class procedure TCocoaWSProgressBar.SetStyle(
  const AProgressBar: TCustomProgressBar; const NewStyle: TProgressBarStyle);
begin
  if AProgressBar.HandleAllocated then
  begin
    NSProgressIndicator(AProgressBar.Handle).setIndeterminate(NewStyle = pbstMarquee);
    NSProgressIndicator(AProgressBar.Handle).startAnimation(nil);
  end;
end;

{ TCocoaTabPage }

(*function TCocoaTabPage.lclGetCallback: ICommonCallback;
begin
  Result:=callback;
end;

procedure TCocoaTabPage.lclClearCallback;
begin
  callback:=nil;
end;

{ TCocoaTabControl }

function TCocoaTabControl.lclGetCallback: ICommonCallback;
begin
  Result:=callback;
end;

procedure TCocoaTabControl.lclClearCallback;
begin
  callback:=nil;
end; *)

{ TLCLListViewCallback }

type
  TProtCustomListView = class(TCustomListView);

constructor TLCLListViewCallback.Create(AOwner: NSObject; ATarget: TWinControl; AHandleView: NSView);
begin
  inherited Create(AOwner, ATarget, AHandleView);
  checkedIdx := NSMutableIndexSet.alloc.init;
end;

destructor TLCLListViewCallback.Destroy;
begin
  if Assigned(checkedIdx) then checkedIdx.release;
  inherited Destroy;
end;

function TLCLListViewCallback.ItemsCount: Integer;
begin
  Result:=listView.Items.Count + tempItemsCountDelta;
end;

function TLCLListViewCallback.GetItemTextAt(ARow, ACol: Integer;
  var Text: String): Boolean;
begin
  Result := (ACol>=0) and (ACol<listView.ColumnCount)
    and (ARow >= 0) and (ARow < listView.Items.Count);
  if not Result then Exit;
  if ACol = 0 then
    Text := listView.Items[ARow].Caption
  else
  begin
    Text := '';
    dec(ACol);
    if (ACol >=0) and (ACol < listView.Items[ARow].SubItems.Count) then
      Text := listView.Items[ARow].SubItems[ACol];
  end;
end;

function TLCLListViewCallback.GetItemCheckedAt(ARow, ACol: Integer;
  var IsChecked: Integer): Boolean;
var
  BoolState : array [Boolean] of Integer = (NSOffState, NSOnState);
begin
  if ownerData and Assigned(listView) and (ARow>=0) and (ARow < listView.Items.Count) then
    IsChecked := BoolState[listView.Items[ARow].Checked]
  else
    IsChecked := BoolState[checkedIdx.containsIndex(ARow)];
  Result := true;
end;

function TLCLListViewCallback.GetItemImageAt(ARow, ACol: Integer;
  var imgIdx: Integer): Boolean;
begin
  Result := (ACol >= 0) and (ACol < listView.ColumnCount)
    and (ARow >= 0) and (ARow < listView.Items.Count);

  if not Result then Exit;

  if ACol = 0 then
    imgIdx := listView.Items[ARow].ImageIndex
  else
  begin
    dec(ACol);
    if (ACol >=0) and (ACol < listView.Items[ARow].SubItems.Count) then
      imgIdx := listView.Items[ARow].SubItemImages[ACol];
  end;
end;

type
  TSmallImagesAccess = class(TCustomListView);

function TLCLListViewCallback.GetImageFromIndex(imgIdx: Integer): NSImage;
var
  bmp : TBitmap;
  lst : TCustomImageList;
  x,y : integer;
  img : NSImage;
  rep : NSBitmapImageRep;
  cb  : TCocoaBitmap;
begin
  lst := TSmallImagesAccess(listView).SmallImages;
  bmp := TBitmap.Create;
  try
    lst.GetBitmap(imgIdx, bmp);

    if bmp.Handle = 0 then begin
      Result := nil;
      Exit;
    end;

    // Bitmap Handle should be nothing but TCocoaBitmap
    cb := TCocoaBitmap(bmp.Handle);

    // There's NSBitmapImageRep in TCocoaBitmap, but it depends on the availability
    // of memory buffer stored with TCocoaBitmap. As soon as TCocoaBitmap is freed
    // pixels are not available. For this reason, we're making a copy of the bitmapdata
    // allowing Cocoa to allocate its own buffer (by passing nil for planes parameter)
    rep := NSBitmapImageRep(NSBitmapImageRep.alloc).initWithBitmapDataPlanes_pixelsWide_pixelsHigh__colorSpaceName_bitmapFormat_bytesPerRow_bitsPerPixel(
      nil, // planes, BitmapDataPlanes
      Round(cb.ImageRep.size.Width), // width, pixelsWide
      Round(cb.ImageRep.size.Height),// height, PixelsHigh
      cb.ImageRep.bitsPerSample,// bitsPerSample, bps
      cb.ImageRep.samplesPerPixel, // samplesPerPixel, spp
      cb.ImageRep.hasAlpha, // hasAlpha
      False, // isPlanar
      cb.ImageRep.colorSpaceName, // colorSpaceName
      cb.ImageRep.bitmapFormat, // bitmapFormat
      cb.ImageRep.bytesPerRow, // bytesPerRow
      cb.ImageRep.BitsPerPixel //bitsPerPixel
    );
    System.Move( cb.ImageRep.bitmapData^, rep.bitmapData^, cb.ImageRep.bytesPerRow * Round(cb.ImageRep.size.height));
    img := NSImage(NSImage.alloc).initWithSize( rep.size );
    img.addRepresentation(rep);
    Result := img;
  finally
    bmp.Free;
  end;
end;

procedure TLCLListViewCallback.SetItemTextAt(ARow, ACol: Integer;
  const Text: String);
begin
  // there's no notifcaiton to be sent to the TCustomListView;
  if (ACol<>0) then Exit;

  inc(isSetTextFromWS);
  try
    if (ACol=0) then
      if (ARow>=0) and (ARow<listView.Items.Count) then
        TProtCustomListView(listView).DoEndEdit(listView.Items[ARow], Text);
  finally
    dec(isSetTextFromWS);
  end;

end;

procedure TLCLListViewCallback.SetItemCheckedAt(ARow, ACol: Integer;
  IsChecked: Integer);
var
  Msg: TLMNotify;
  NMLV: TNMListView;
begin
  if IsChecked = NSOnState
    then checkedIdx.addIndex(ARow)
    else checkedIdx.removeIndex(ARow);

  FillChar(Msg{%H-}, SizeOf(Msg), #0);
  FillChar(NMLV{%H-}, SizeOf(NMLV), #0);

  Msg.Msg := CN_NOTIFY;

  NMLV.hdr.hwndfrom := ListView.Handle;
  NMLV.hdr.code := LVN_ITEMCHANGED;
  NMLV.iItem := ARow;
  NMLV.iSubItem := 0;
  NMLV.uChanged := LVIF_STATE;
  Msg.NMHdr := @NMLV.hdr;

  LCLMessageGlue.DeliverMessage(ListView, Msg);
end;

procedure TLCLListViewCallback.tableSelectionChange(NewSel: Integer; Added, Removed: NSIndexSet);
var
  Msg: TLMNotify;
  NMLV: TNMListView;

  procedure RunIndex(idx: NSIndexSet);
  var
    buf : array [0..256-1] of NSUInteger;
    rng : NSRange;
    cnt : Integer;
    i   : Integer;
    itm : NSUInteger;
  begin
    rng.location := idx.firstIndex;
    repeat
      rng.length := idx.lastIndex - rng.location + 1;
      cnt := idx.getIndexes_maxCount_inIndexRange(@buf[0], length(buf), @rng);
      for i := 0 to cnt - 1 do begin
        NMLV.iItem := buf[i];
        LCLMessageGlue.DeliverMessage(ListView, Msg);
      end;
      if cnt < length(buf) then cnt := 0
      else rng.location := buf[cnt-1]+1;
    until cnt = 0;
  end;

begin
  {$IFDEF COCOA_DEBUG_LISTVIEW}
  WriteLn(Format('[TLCLListViewCallback.SelectionChanged] NewSel=%d', [NewSel]));
  {$ENDIF}

  FillChar(Msg{%H-}, SizeOf(Msg), #0);
  FillChar(NMLV{%H-}, SizeOf(NMLV), #0);

  Msg.Msg := CN_NOTIFY;

  NMLV.hdr.hwndfrom := ListView.Handle;
  NMLV.hdr.code := LVN_ITEMCHANGED;
  NMLV.iSubItem := 0;
  NMLV.uChanged := LVIF_STATE;
  Msg.NMHdr := @NMLV.hdr;

  if Removed.count>0 then
  begin
    NMLV.uNewState := 0;
    NMLV.uOldState := LVIS_SELECTED;
    RunIndex( Removed );
  end;
  if Added.count > 0 then begin
    NMLV.uNewState := LVIS_SELECTED;
    NMLV.uOldState := 0;
    RunIndex( Added );
  end;

  {if NewSel >= 0 then
  begin
    NMLV.iItem := NewSel;
    NMLV.uNewState := LVIS_SELECTED;
  end
  else
  begin
    NMLV.iItem := 0;
    NMLV.uNewState := 0;
    NMLV.uOldState := LVIS_SELECTED;
  end;

  LCLMessageGlue.DeliverMessage(ListView, Msg);}
end;

procedure TLCLListViewCallback.ColumnClicked(ACol: Integer);
var
  Msg: TLMNotify;
  NMLV: TNMListView;
begin
  FillChar(Msg{%H-}, SizeOf(Msg), #0);
  FillChar(NMLV{%H-}, SizeOf(NMLV), #0);

  Msg.Msg := CN_NOTIFY;

  NMLV.hdr.hwndfrom := ListView.Handle;
  NMLV.hdr.code := LVN_COLUMNCLICK;
  NMLV.iSubItem := ACol;
  NMLV.uChanged := 0;
  Msg.NMHdr := @NMLV.hdr;

  LCLMessageGlue.DeliverMessage(ListView, Msg);
end;

procedure TLCLListViewCallback.DrawRow(rowidx: Integer; ctx: TCocoaContext;
  const r: TRect; state: TOwnerDrawState);
begin
  // todo: check for custom draw listviews event
end;

procedure TLCLListViewCallback.GetRowHeight(rowidx: Integer; var h: Integer);
begin

end;

{ TCocoaWSTrackBar }

{------------------------------------------------------------------------------
  Method:  TCocoaWSTrackBar.CreateHandle
  Params:  AWinControl - LCL control
           AParams     - Creation parameters
  Returns: Handle to the control in Carbon interface

  Creates new track bar with the specified parameters
 ------------------------------------------------------------------------------}
class function TCocoaWSTrackBar.CreateHandle(const AWinControl: TWinControl;
  const AParams: TCreateParams): TLCLIntfHandle;
var
  lResult: TCocoaSlider;
begin
  lResult := TCocoaSlider.alloc.lclInitWithCreateParams(AParams);
  if Assigned(lResult) then
  begin
    lResult.callback := TLCLCommonCallback.Create(lResult, AWinControl);
    lResult.setTarget(lResult);
    lResult.setAction(objcselector('sliderAction:'));
  end;
  Result := TLCLIntfHandle(lResult);
end;

{------------------------------------------------------------------------------
  Method:  TCocoaWSTrackBar.ApplyChanges
  Params:  ATrackBar - LCL custom track bar

  Sets the parameters (Min, Max, Position, Ticks) of slider
 ------------------------------------------------------------------------------}
class procedure TCocoaWSTrackBar.ApplyChanges(const ATrackBar: TCustomTrackBar);
var
  lSlider: TCocoaSlider;
  lTickCount, lTrackBarLength: Integer;
begin
  if not Assigned(ATrackBar) or not ATrackBar.HandleAllocated then Exit;
  lSlider := TCocoaSlider(ATrackBar.Handle);
  lSlider.setMaxValue(ATrackBar.Max);
  lSlider.setMinValue(ATrackBar.Min);
  lSlider.setIntValue(ATrackBar.Position);
  lSlider.intval := ATrackBar.Position;
  lSlider.setContinuous(true);
  lSlider.setAltIncrementValue(1); // forcing the slider to switch by 1 by the keyboard

  // Ticks
  if ATrackBar.TickStyle = tsAuto then
  begin
    // this should only apply to Auto
    // and for Manual it should drawn manually
    if ATrackBar.Frequency <> 0 then
      lTickCount := (ATrackBar.Max-ATrackBar.Min) div ATrackBar.Frequency + 1
    else
      lTickCount := (ATrackBar.Max-ATrackBar.Min);

    // Protection from too frequent ticks.
    // 1024 is a number of "too much" ticks, based on a common
    // screen resolution 1024 x 768
    // Protects ticks from "disappearing" when trackbar is resized
    // and is temporary too narrow to fit the trackbar
    if TickCount > 1024 then
    begin
      if ATrackBar.Orientation = trHorizontal then
        lTrackBarLength := ATrackBar.Width
      else
        lTrackBarLength := ATrackBar.Height;

      lTickCount := Min(lTickCount, lTrackBarLength);
    end;
  end else if ATrackBar.TickStyle = tsManual then
  begin
    lTickCount := 2;
  end else
    lTickCount := 0;

  lSlider.lclSetManTickDraw(ATrackBar.TickStyle = tsManual);

  lSlider.setNumberOfTickMarks(lTickCount);

  if ATrackBar.TickMarks = tmTopLeft then
    lSlider.setTickMarkPosition(NSTickMarkAbove)
  else
    lSlider.setTickMarkPosition(NSTickMarkBelow);
  lSlider.setNeedsDisplay_(true);
end;

{------------------------------------------------------------------------------
  Method:  TCocoaWSTrackBar.GetPosition
  Params:  ATrackBar - LCL custom track bar
  Returns: Position of slider
 ------------------------------------------------------------------------------}
class function TCocoaWSTrackBar.GetPosition(const ATrackBar: TCustomTrackBar
  ): integer;
var
  lSlider: TCocoaSlider;
begin
  if not Assigned(ATrackBar) or not ATrackBar.HandleAllocated then
  begin
    Result := 0;
    Exit;
  end;
  lSlider := TCocoaSlider(ATrackBar.Handle);
  Result := lSlider.intValue();
end;

{------------------------------------------------------------------------------
  Method:  TCocoaWSTrackBar.SetPosition
  Params:  ATrackBar - LCL custom track bar
           NewPosition  - New position

  Sets the position of slider
 ------------------------------------------------------------------------------}
class procedure TCocoaWSTrackBar.SetPosition(const ATrackBar: TCustomTrackBar;
  const NewPosition: integer);
var
  lSlider: TCocoaSlider;
begin
  if not Assigned(ATrackBar) or not ATrackBar.HandleAllocated then Exit;
  lSlider := TCocoaSlider(ATrackBar.Handle);
  lSlider.setIntValue(ATrackBar.Position);
end;

// Cocoa auto-detects the orientation based on width/height and there seams
// to be no way to force it
class procedure TCocoaWSTrackBar.SetOrientation(const ATrackBar: TCustomTrackBar;
  const AOrientation: TTrackBarOrientation);
begin
  if not Assigned(ATrackBar) or not ATrackBar.HandleAllocated then Exit;
  if (AOrientation = trHorizontal) and (ATrackBar.Height >= ATrackBar.Width) then
    ATrackBar.Width := ATrackBar.Height + 1
  else if (AOrientation = trVertical) and (ATrackBar.Width >= ATrackBar.Height) then
    ATrackBar.Height := ATrackBar.Width + 1;
end;

class procedure TCocoaWSTrackBar.SetTick(const ATrackBar: TCustomTrackBar; const ATick: integer);
var
  lSlider: TCocoaSlider;
begin
  if not Assigned(ATrackBar) or not ATrackBar.HandleAllocated then Exit;
  lSlider := TCocoaSlider(ATrackBar.Handle);
  lSlider.lclAddManTick(ATick);
end;

class procedure TCocoaWSTrackBar.GetPreferredSize(
  const AWinControl: TWinControl; var PreferredWidth, PreferredHeight: integer;
  WithThemeSpace: Boolean);
var
  lSlider : TCocoaSlider;
  trk     : TCustomTrackBar;
  frm     : NSRect;
begin
  if not Assigned(AWinControl) or not AWinControl.HandleAllocated then Exit;
  trk := TCustomTrackBar(AWinControl);
  lSlider := TCocoaSlider(AWinControl.Handle);
  frm := lSlider.frame;
  try
    if trk.Orientation = trVertical then
      lSlider.setFrame(NSMakeRect(0,0,5,10))
    else
      lSlider.setFrame(NSMakeRect(0,0,10,5));

    TCocoaWSWinControl.GetPreferredSize(AWinControl,PreferredWidth, PreferredHeight, WithThemeSpace);
    if trk.Orientation = trVertical then
      PreferredHeight := 0
    else
      PreferredWidth := 0;
  finally
    lSlider.setFrame(frm);
  end;
end;

end.

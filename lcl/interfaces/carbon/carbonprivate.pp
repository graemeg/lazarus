{                 --------------------------------------------
                  carbonprivate.pp  -  Carbon internal classes
                  --------------------------------------------

 This unit contains the private classhierarchy for the Carbon implemetations
 This hierarchy reflects (more or less) the Carbon widget hierarchy

 *****************************************************************************
  This file is part of the Lazarus Component Library (LCL)

  See the file COPYING.modifiedLGPL.txt, included in this distribution,
  for details about the license.
 *****************************************************************************
}
unit CarbonPrivate;

{$mode objfpc}{$H+}

interface

// defines
{$I carbondefines.inc}

uses
  // rtl+ftl
  Types, Classes, SysUtils,
  // carbon bindings
  MacOSAll,
  {$ifdef CarbonUseCocoaAll}
  CocoaAll,
  {$endif}
  // widgetset
  WSLCLClasses,
 // LCL Carbon
  CarbonDef, CarbonGDIObjects, CarbonMenus,
 // LCL
  LMessages, LCLMessageGlue, LCLProc, LCLType, Graphics, Controls, Forms,
  Dialogs, StdCtrls, Buttons, ComCtrls, ExtCtrls, Menus;
  
type
  TCarbonControlEvent = (cceValueChanged, cceIndicatorMoved, cceDoAction,
    cceDraw, cceHit);
  TCarbonControlEvents = set of TCarbonControlEvent;
  TCarbonWidgetFlag = (cwfNone, cwdTToolBar, cwdTTabControl);

  { TCarbonControl }
  
  TCarbonControl = class(TCarbonWidget)
  private
    FCarbonWidgetFlag: TCarbonWidgetFlag;
  protected
    procedure RegisterEvents; override;
    procedure CreateWidget(const {%H-}AParams: TCreateParams); override;
    procedure DestroyWidget; override;
    procedure AddControlPart(const AControl: ControlRef);
    function GetContent: ControlRef; override;
    function GetControlContentRect(var ARect: TRect): Boolean;
    function GetFrame({%H-}Index: Integer): ControlRef; virtual;
    function GetFrameBounds(var ARect: TRect): Boolean; virtual;
    function GetForceEmbedInScrollView: Boolean; virtual;
    function UpdateContentBounds: Boolean;
    function EmbedInScrollView(const AParams: TCreateParams): HIViewRef;
    function EmbedInScrollView(AScrollBars: TScrollStyle): HIViewRef;
    procedure ChangeScrollBars(AScrollView: HIViewRef; var AScrollBars: TScrollStyle; ANewValue: TScrollStyle);
  public
    class function GetFrameCount: Integer; virtual;
    class function GetValidEvents: TCarbonControlEvents; virtual;
    procedure Hit({%H-}AControlPart: ControlPartCode); virtual;
    procedure Draw; virtual;
    procedure ValueChanged; virtual;
    procedure IndicatorMoved; virtual;
    procedure DoAction({%H-}AControlPart: ControlPartCode); virtual;
  public
    procedure AllowMenuProcess({%H-}MenuHotKey: AnsiChar; {%H-}State: TShiftState; var AllowCommandProcess: Boolean); virtual;
  public
    procedure AddToWidget(AParent: TCarbonWidget); override;
    function GetTopParentWindow: WindowRef; override;
    function GetThemeDrawState: ThemeDrawState;
    function GetWindowRelativePos(winX, winY: Integer): TPoint; override;
    function GetClientRect(var ARect: TRect): Boolean; override;
    function GetPreferredSize: TPoint; override;
    procedure Invalidate(Rect: PRect = nil); override;
    function IsEnabled: Boolean; override;
    function IsVisible: Boolean; override;
    function Enable(AEnable: Boolean): Boolean; override;
    
    function GetBounds(var ARect: TRect): Boolean; override;
    function GetScreenBounds(var ARect: TRect): Boolean; override;
    function SetBounds(const ARect: TRect): Boolean; override;

    procedure SetFocus; override;
    procedure SetColor(const AColor: TColor); override;
    procedure SetFont(const AFont: TFont); override;
    procedure SetZOrder(AOrder: HIViewZOrderOp; ARefWidget: TCarbonWidget); override;
    procedure ShowHide(AVisible: Boolean); override;
    
    function GetText(var {%H-}S: String): Boolean; override;
    function SetText(const S: String): Boolean; override;
    
    function Update: Boolean; override;
    
    function WidgetAtPos(const P: TPoint): ControlRef; override;
  public
    function GetValue: Integer;
    procedure SetValue(AValue: Integer);
    procedure SetMinimum(AValue: Integer);
    procedure SetMaximum(AValue: Integer);
    procedure SetViewSize(AValue: Integer);
  public
    // needed to avoid "Class is" or "ClassType"
    property CarbonWidgetFlag: TCarbonWidgetFlag read FCarbonWidgetFlag write FCarbonWidgetFlag;
  { Frame:
     = widget in controls without special frame control
     - frame area control of control
     - determines bounds of control
     - processes only bounds changed event            }
    property Frames[Index: Integer]: ControlRef read GetFrame;
  end;
  
  { TCarbonCustomControl }

  TCarbonCustomControl = class(TCarbonControl)
  private
    FScrollView: HIViewRef;
    FScrollOrigin: HIPoint;
    FScrollSize: TPoint;
    FScrollMin: TPoint;
    FScrollPageSize: TPoint;
    
    FMulX: Single; // multiply x coords to fit real page size
    FMulY: Single; // multiply y coords to fit real page size
    FTextFractional: Boolean;
  protected
    procedure RegisterEvents; override;
    procedure CreateWidget(const AParams: TCreateParams); override;
    procedure DestroyWidget; override;
    function GetFrame({%H-}Index: Integer): ControlRef; override;
    function GetForceEmbedInScrollView: Boolean; override;
    procedure SendScrollUpdate;
    procedure UpdateLCLClientRect; override;
  public
    class function GetValidEvents: TCarbonControlEvents; override;
    procedure Draw; override;
    procedure GetInfo(out AImageSize, AViewSize, ALineSize: HISize; out AOrigin: HIPoint); virtual;
    procedure ScrollTo(const ANewOrigin: HIPoint); virtual;
    procedure Invalidate(Rect:PRect=nil);override;
  public
    procedure AddToWidget(AParent: TCarbonWidget); override;
    procedure SetColor(const {%H-}AColor: TColor); override;
    procedure SetFont(const {%H-}AFont: TFont); override;
    procedure GetScrollInfo(SBStyle: Integer; var ScrollInfo: TScrollInfo); override;
    function GetScrollbarVisible(SBStyle: Integer): Boolean; override;
    function SetScrollInfo(SBStyle: Integer; const ScrollInfo: TScrollInfo): Integer; override;

    property TextFractional: Boolean read FTextFractional write FTextFractional;
  end;

  { TCarbonToolBar }

  TCarbonToolBar = class(TCarbonCustomControl)
  protected
    procedure CreateWidget(const AParams: TCreateParams); override;
  end;
  
  { TCarbonScrollingWinControl }

  TCarbonScrollingWinControl = class(TCarbonCustomControl)
  protected
    procedure CreateWidget(const AParams: TCreateParams); override;
    function GetForceEmbedInScrollView: Boolean; override;
  public
    function GetWindowRelativePos(winX, winY: Integer): TPoint; override;
    function GetPreferredSize: TPoint; override;
  end;

  { TCarbonWindow }

  TCarbonWindow = class(TCarbonScrollingWinControl)
  private
    FSheetWin: WindowRef;
  protected
    fWindowRef  : WindowRef;
    fHiddenWin  : WindowRef;
    fWinContent : HIViewRef; // actuall content view

    fPrevMenuEnabled  : Boolean; // was menu enabled before showing modal


    procedure RegisterWindowEvents; virtual;
    procedure CreateWindow(const AParams: TCreateParams); virtual;

    procedure RegisterEvents; override;
    procedure CreateWidget(const AParams: TCreateParams); override;

    procedure DestroyWidget; override;
  public
    function GetPreferredSize: TPoint; override;

    procedure BoundsChanged; override;

    procedure AddToWidget(AParent: TCarbonWidget); override;
    function GetWindowRelativePos(winX, winY: Integer): TPoint; override;
    function GetTopParentWindow: WindowRef; override;
    function GetClientRect(var ARect: TRect): Boolean; override;
    procedure Invalidate(Rect: PRect = nil); override;
    function IsEnabled: Boolean; override;
    function IsVisible: Boolean; override;
    function Enable(AEnable: Boolean): boolean; override;

    function GetBounds(var ARect: TRect): Boolean; override;
    function GetScreenBounds(var ARect: TRect): Boolean; override;
    function SetBounds(const ARect: TRect): Boolean; override;

    procedure SetFocus; override;
    procedure SetColor(const AColor: TColor); override;
    procedure SetFont(const AFont: TFont); override;
    procedure SetZOrder(AOrder: HIViewZOrderOp; ARefWidget: TCarbonWidget); override;
    procedure ShowHide(AVisible: Boolean); override;

    function GetText(var {%H-}S: String): Boolean; override;
    function SetText(const S: String): Boolean; override;

    function Update: Boolean; override;
    function WidgetAtPos(const {%H-}P: TPoint): ControlRef; override;
  public
    function Activate: Boolean; virtual;

    procedure CloseModal; virtual;
    procedure ShowModal; virtual;

    function IsIconic: Boolean; virtual;
    function IsZoomed: Boolean; virtual;

    function SetForeground: Boolean; virtual;
    function Show(AShow: Integer): Boolean; virtual;

    procedure SetBorderIcons(ABorderIcons: TBorderIcons); virtual;
    procedure SetFormBorderStyle(AFormBorderStyle: TFormBorderStyle); virtual;
  public
    property Window: WindowRef read FWindowRef;
    property SheetWin: WindowRef  read FSheetWin write FSheetWin; // used to show sheet in modal window
  end;

  { TCarbonHintWindow }

  TCarbonHintWindow = class(TCarbonWindow)
  protected
    procedure CreateWindow(const AParams: TCreateParams); override;
  public
    procedure ShowHide(AVisible: Boolean); override;
  end;

  { TCarbonDesignWindow }

  TCarbonDesignWindow = class(TCarbonWindow)
  private
    FDesignControl: HIViewRef;
    FDesignContext: TCarbonContext;
    procedure BringDesignerToFront;
  protected
    procedure RegisterEvents; override;
    procedure CreateWidget(const AParams: TCreateParams); override;
    procedure DestroyWidget; override;
  public
    procedure ControlAdded; override;
    procedure BoundsChanged; override;

    procedure SetChildZPosition(AChild: TCarbonWidget; const AOldPos, ANewPos: Integer; const AChildren: TFPList); override;

    function GetDesignContext: TCarbonContext;
    procedure ReleaseDesignContext;
  end;
  
  { TCarbonGroupBox }

  TCarbonGroupBox = class(TCarbonControl)
  private
    FUserPane: ControlRef;
    FBoxColor: TColor;
  protected
    procedure RegisterEvents; override;
    procedure CreateWidget(const AParams: TCreateParams); override;
    procedure DestroyWidget; override;
    function GetContent: ControlRef; override;
  public
    function GetPreferredSize: TPoint; override;
    function GetClientRect(var ARect: TRect): Boolean; override;
    function SetBounds(const ARect: TRect): Boolean; override;
    procedure SetColor(const AColor: TColor); override;
  end;
  
  { TCarbonStatusBar }

  TCarbonStatusBar = class(TCarbonControl)
  private
    {$ifdef CarbonOldStatusBar}
    FPanels: TObjectList;
    {$endif}
  protected
    procedure CreateWidget(const AParams: TCreateParams); override;
    procedure DestroyWidget; override;
  public
    class function GetValidEvents: TCarbonControlEvents; override;
    procedure Draw; override;
  public
    function GetPreferredSize: TPoint; override;
    procedure SetColor(const {%H-}AColor: TColor); override;
    procedure SetFont(const {%H-}AFont: TFont); override;
    procedure UpdatePanel({%H-}AIndex: Integer = -1);
  end;

  { TCarbonStaticText }

  TCarbonStaticText = class(TCarbonControl)
  protected
    procedure CreateWidget(const AParams: TCreateParams); override;
  public
    procedure BoundsChanged; override;
  public
    procedure SetAlignment(AAlignment: TAlignment); virtual;
  end;
  
function GetCarbonWidget(AWidget: Pointer): TCarbonWidget;
function GetCarbonWindow(AWidget: WindowRef): TCarbonWindow;
function GetCarbonControl(AWidget: ControlRef): TCarbonControl;

const
  larAXStaticTextRoles = [larClock, larLabel, larListItem, larTreeItem, larResizeGrip];
  larAXListRoles = [larListBox, larTreeView];

implementation

uses LazUTF8, InterfaceBase, CarbonInt, CarbonProc, CarbonDbgConsts, CarbonUtils, CarbonCanvas, CarbonCaret;

var
  // recursive number of draw events called by OSX
  IsDrawEvent  : Integer = 0;
  // invalidated inside OnPaint event
  InvalidPaint : Boolean = false;
  // invalidating
  IsRepaint    : Boolean = false;



{------------------------------------------------------------------------------
  Name:    GetCarbonWidget
  Params:  AWidget - Pointer to control or window widget
  Returns: The Carbon widget

  Retrieves widget for specified Carbon control or window
 ------------------------------------------------------------------------------}
function GetCarbonWidget(AWidget: Pointer): TCarbonWidget;
begin
  if AWidget = nil then
  begin
    Result := nil;
    Exit;
  end;

  if IsValidControlHandle(AWidget) then
    Result := GetCarbonControl(ControlRef(AWidget))
  else
    // there is no (cheap) check for windows so assume a window
    // when it is not a control.
    Result := GetCarbonWindow(WindowRef(AWidget));
end;

{------------------------------------------------------------------------------
  Name:    GetCarbonWindow
  Params:  AWidget - Pointer to window widget
  Returns: The Carbon window

  Retrieves the Carbon window for specified window widget
 ------------------------------------------------------------------------------}
function GetCarbonWindow(AWidget: WindowRef): TCarbonWindow;
begin
  if GetWindowProperty(AWidget, LAZARUS_FOURCC, WIDGETINFO_FOURCC,
    SizeOf(TCarbonWidget), nil, @Result) <> noErr then Result := nil;
end;

{------------------------------------------------------------------------------
  Name:    GetCarbonControl
  Params:  AWidget - Pointer to control widget
  Returns: The Carbon control

  Retrieves the Carbon control for specified control widget
 ------------------------------------------------------------------------------}
function GetCarbonControl(AWidget: ControlRef): TCarbonControl;
begin
  if GetControlProperty(AWidget, LAZARUS_FOURCC, WIDGETINFO_FOURCC,
    SizeOf(TCarbonWidget), nil, @Result) <> noErr then Result := nil;
end;

// Store state of key modifiers so that we can emulate keyup/keydown
// of keys like control, option, command, caps lock, shift
var PrevKeyModifiers: UInt32 = 0;

// Stores mouse up message to be fired on control hit after value is updated
var SavedMouseUpMsg: TLMMouse;

// Stores multi click mouse down message to be fired after handling standard event
var PostponedDownMsg: TLMMouse;
var PostponedDown: Boolean;

// Stores last mouse pos to call mouse move only when it really has changed
var LastMousePos: TPoint;

{$I carbonprivatecommon.inc}
{$I carbonprivatecontrol.inc}
{$I carbonprivatewindow.inc}

{ TCarbonHintWindow }

{------------------------------------------------------------------------------
  Method:  TCarbonHintWindow.CreateWindow
  Params:  AParams - Creation parameters

  Creates Carbon hint window
 ------------------------------------------------------------------------------}
procedure TCarbonHintWindow.CreateWindow(const AParams: TCreateParams);
var
  AWindow: WindowRef;
begin
  if OSError(
    CreateNewWindow(kHelpWindowClass,
      kWindowCompositingAttribute or
      kWindowHideOnSuspendAttribute or kWindowStandardHandlerAttribute,
      ParamsToCarbonRect(AParams), AWindow{%H-}),
    Self, SCreateWidget, 'CreateNewWindow') then RaiseCreateWidgetError(LCLObject);

  fWindowRef := AWindow;

  // creating wrapped views
  if OSError(
    HIViewFindByID(HIViewGetRoot(fWindowRef), kHIViewWindowContentID, fWinContent),
    Self, SCreateWidget, 'HIViewGetRoot') then RaiseCreateWidgetError(LCLObject);

  OSError(
    SetWindowProperty(AWindow, LAZARUS_FOURCC, WIDGETINFO_FOURCC, SizeOf(Self), @Self),
    Self, SCreateWidget, 'SetWindowProperty');
  OSError(
    SetControlProperty(fWinContent, LAZARUS_FOURCC, WIDGETINFO_FOURCC, SizeOf(Self), @Self),
    Self, SCreateWidget, SSetControlProp);
  
  SetColor(LCLObject.Color);
end;

procedure TCarbonHintWindow.ShowHide(AVisible: Boolean);
begin
  if Assigned(fWindowRef) then
    MacOSAll.ShowHide(fWindowRef, AVisible or (csDesigning in LCLobject.ComponentState))
  else
    inherited ShowHide(AVisible);
end;

{ TCarbonDesignWindow }

{------------------------------------------------------------------------------
  Name: CarbonDesign_Draw
  Handles draw event
 ------------------------------------------------------------------------------}
function CarbonDesign_Draw(ANextHandler: EventHandlerCallRef;
  AEvent: EventRef;
  AWidget: TCarbonWidget): OSStatus; {$IFDEF darwin}mwpascal;{$ENDIF}
var
  ADesignWindow: TCarbonDesignWindow;
  AStruct: PPaintStruct;
begin
  {$IFDEF VerbosePaint}
    Debugln('CarbonDesign_Draw ', DbgSName(AWidget.LCLObject));
  {$ENDIF}

  ADesignWindow := (AWidget as TCarbonDesignWindow);

  ADesignWindow.FDesignContext := TCarbonControlContext.Create(ADesignWindow);
  try
    // set canvas context
    if OSError(
      GetEventParameter(AEvent, kEventParamCGContextRef, typeCGContextRef, nil,
        SizeOf(CGContextRef), nil, @(ADesignWindow.FDesignContext.CGContext)),
      'CarbonDesign_Draw', SGetEvent, 'kEventParamCGContextRef') then Exit;

    // let carbon draw/update
    Result := CallNextEventHandler(ANextHandler, AEvent);

    // draw designer stuff
    New(AStruct);
    FillChar(AStruct^, SizeOf(TPaintStruct), 0);
    AStruct^.hdc := HDC(ADesignWindow.FDesignContext);
    try
      {$IFDEF VerbosePaint}
        DebugLn('CarbonDesign_Draw LM_PAINT to ', DbgSName(AWidget.LCLObject));
      {$ENDIF}
      LCLSendPaintMsg(AWidget.LCLObject, HDC(ADesignWindow.FDesignContext), AStruct);
    finally
      Dispose(AStruct);
    end;
  finally
    FreeAndNil(ADesignWindow.FDesignContext);
  end;
  {$IFDEF VerbosePaint}
    Debugln('CarbonDesign_Draw end ', DbgSName(AWidget.LCLObject));
  {$ENDIF}
end;

{------------------------------------------------------------------------------
  Method:  TCarbonDesignWindow.BringDesignerToFront
 ------------------------------------------------------------------------------}
procedure TCarbonDesignWindow.BringDesignerToFront;
begin
  OSError(HIViewSetZOrder(FDesignControl, kHIViewZOrderAbove, nil),
    Self, 'BringDesignerToFront', 'HIViewSetZOrder');
end;

{------------------------------------------------------------------------------
  Method:  TCarbonDesignWindow.RegisterEvents

  Registers event handlers for design window
 ------------------------------------------------------------------------------}
procedure TCarbonDesignWindow.RegisterEvents;
var
  TmpSpec: EventTypeSpec;
begin
  inherited;

  TmpSpec := MakeEventSpec(kEventClassControl, kEventControlDraw);
  InstallControlEventHandler(FDesignControl,
    RegisterEventHandler(@CarbonDesign_Draw),
    1, @TmpSpec, Pointer(Self), nil);

  TmpSpec := MakeEventSpec(kEventClassControl, kEventControlTrack);
  InstallControlEventHandler(FDesignControl,
    RegisterEventHandler(@CarbonCommon_Track),
    1, @TmpSpec, Pointer(Self), nil);

  {$IFDEF VerboseWindowEvent}
    DebugLn('TCarbonDesignWindow.RegisterEvents ', ClassName, ' ',
      LCLObject.Name, ': ', LCLObject.ClassName);
  {$ENDIF}
end;

{------------------------------------------------------------------------------
  Method:  TCarbonDesignWindow.CreateWidget
  Params:  AParams - Creation parameters

  Creates Carbon window for designing
 ------------------------------------------------------------------------------}
procedure TCarbonDesignWindow.CreateWidget(const AParams: TCreateParams);
var
  R: TRect;
begin
  inherited;
  
  // create custom view above all others
  GetClientRect(R{%H-});
  OffsetRect(R, -R.Left, -R.Top);
  FDesignControl := CreateCustomHIView(RectToCGRect(R));
  
  OSError(
    HIViewChangeFeatures(FDesignControl, kHIViewFeatureDoesNotUseSpecialParts,
      kHIViewFeatureGetsFocusOnClick),
    SCreateWidget, 'HIViewChangeFeatures');
    
  OSError(
    SetControlProperty(FDesignControl, LAZARUS_FOURCC, WIDGETINFO_FOURCC, SizeOf(Self), @Self),
    Self, SCreateWidget, SSetControlProp);
    
  OSError(HIViewAddSubview(fWinContent, FDesignControl), Self, SCreateWidget, SViewAddView);
  BringDesignerToFront;
end;

{------------------------------------------------------------------------------
  Method:  TCarbonDesignWindow.DestroyWidget

  Override to do some clean-up
 ------------------------------------------------------------------------------}
procedure TCarbonDesignWindow.DestroyWidget;
begin
  DisposeControl(FDesignControl);
  LCLObject := nil;
  inherited;
end;

{------------------------------------------------------------------------------
  Method:  TCarbonDesignWindow.ControlAdded

  Notifies about control added
 ------------------------------------------------------------------------------}
procedure TCarbonDesignWindow.ControlAdded;
begin
  BringDesignerToFront;
end;

{------------------------------------------------------------------------------
  Method:  TCarbonDesignWindow.BoundsChanged

  Handles bounds change
 ------------------------------------------------------------------------------}
procedure TCarbonDesignWindow.BoundsChanged;
var
  R: TRect;
begin
  inherited;

  GetClientRect(R{%H-});
  OffsetRect(R, -R.Left, -R.Top);
  OSError(HIViewSetFrame(FDesignControl, RectToCGRect(R)),
    Self, SSetBounds, SViewFrame);

  BringDesignerToFront;
end;

{------------------------------------------------------------------------------
  Method:  TCarbonDesignWindow.SetChildZPosition
  Params:  AChild      - Child widget
           AOldPos     - Old z position
           ANewPos     - New z position
           AChildren   - List of all child controls

  Sets the child z position of Carbon widget
 ------------------------------------------------------------------------------}
procedure TCarbonDesignWindow.SetChildZPosition(AChild: TCarbonWidget; const AOldPos,
  ANewPos: Integer; const AChildren: TFPList);
begin
  inherited;
  
  BringDesignerToFront;
end;

{------------------------------------------------------------------------------
  Method:  TCarbonDesignWindow.GetDesignContext
  Returns: Context for drawing designer stuff
 ------------------------------------------------------------------------------}
function TCarbonDesignWindow.GetDesignContext: TCarbonContext;
begin
  if FDesignContext <> nil then Result := FDesignContext
  else Result := DefaultContext;
end;

{------------------------------------------------------------------------------
  Method:  TCarbonDesignWindow.ReleaseDesignContext

  Releases the context for drawing designer stuff
 ------------------------------------------------------------------------------}
procedure TCarbonDesignWindow.ReleaseDesignContext;
begin
  // nothing
end;

{ TCarbonCustomControl }

{------------------------------------------------------------------------------
  Name: CarbonScrollable_GetInfo
  Handles scrollable get info
 ------------------------------------------------------------------------------}
function CarbonScrollable_GetInfo({%H-}ANextHandler: EventHandlerCallRef;
  AEvent: EventRef;
  AWidget: TCarbonWidget): OSStatus; {$IFDEF darwin}mwpascal;{$ENDIF}
var
  ImageHISize, ViewHISize, LineHISize: HISize;
  HIOrigin: HIPoint;
const
  SName = 'CarbonScrollable_GetInfo';
begin
  {$IFDEF VerboseControlEvent}
    DebugLn('CarbonScrollable_GetInfo ', DbgSName(AWidget.LCLObject));
  {$ENDIF}

  (AWidget as TCarbonCustomControl).GetInfo(ImageHISize, ViewHISize, LineHISize, HIOrigin);

  OSError(SetEventParameter(AEvent, kEventParamImageSize, typeHISize,
    SizeOf(HISize), @ImageHISize), SName, SSetEvent, 'kEventParamImageSize');
  OSError(SetEventParameter(AEvent, kEventParamViewSize, typeHISize,
    SizeOf(HISize), @ViewHISize), SName, SSetEvent, 'kEventParamViewSize');
  OSError(SetEventParameter(AEvent, kEventParamLineSize, typeHISize,
    SizeOf(HISize), @LineHISize), SName, SSetEvent, 'kEventParamLineSize');
  OSError(SetEventParameter(AEvent, kEventParamOrigin, typeHIPoint,
    SizeOf(HIPoint), @HIOrigin), SName, SSetEvent, 'kEventParamOrigin');
  
  Result := noErr;
end;

{------------------------------------------------------------------------------
  Name: CarbonScrollable_ScrollTo
  Handles scrollable get info
 ------------------------------------------------------------------------------}
function CarbonScrollable_ScrollTo({%H-}ANextHandler: EventHandlerCallRef;
  AEvent: EventRef;
  AWidget: TCarbonWidget): OSStatus; {$IFDEF darwin}mwpascal;{$ENDIF}
var
  Origin: HIPoint;
begin
  {$IFDEF VerboseControlEvent}
    DebugLn('CarbonScrollable_ScrollTo ', DbgSName(AWidget.LCLObject));
  {$ENDIF}
  
  if OSError(
    GetEventParameter(AEvent, kEventParamOrigin, typeHIPoint, nil,
      SizeOf(HIPoint), nil, @Origin), 'CarbonScrollable_ScrollTo', SGetEvent,
    'kEventParamOrigin') then Exit;
  
  (AWidget as TCarbonCustomControl).ScrollTo(Origin);
  
  Result := noErr;
end;

{------------------------------------------------------------------------------
  Method:  TCarbonCustomControl.RegisterEvents

  Registers event handlers for custom control
 ------------------------------------------------------------------------------}
procedure TCarbonCustomControl.RegisterEvents;
var
  TmpSpec: EventTypeSpec;
begin
  inherited RegisterEvents;
  
  if FScrollView <> Widget then
  begin
    TmpSpec := MakeEventSpec(kEventClassScrollable, kEventScrollableScrollTo);
    InstallControlEventHandler(Widget,
      RegisterEventHandler(@CarbonScrollable_ScrollTo),
      1, @TmpSpec, Pointer(Self), nil);
  end;
end;

{------------------------------------------------------------------------------
  Method:  TCarbonCustomControl.CreateWidget
  Params:  AParams - Creation parameters

  Creates Carbon custom control
 ------------------------------------------------------------------------------}
procedure TCarbonCustomControl.CreateWidget(const AParams: TCreateParams);
var
  TmpSpec: EventTypeSpec;
  AStyle: TControlStyle;
begin
  AStyle := LCLObject.ControlStyle;

  if CarbonWidgetFlag = cwdTToolBar then
    AStyle := AStyle + [csNoFocus];

  Widget := CreateCustomHIView(ParamsToHIRect(AParams), AStyle);
  if Widget = nil then RaiseCreateWidgetError(LCLObject);

  // The event must be installed before embedding ScrollView. related to #19425
  TmpSpec := MakeEventSpec(kEventClassScrollable, kEventScrollableGetInfo);
  InstallControlEventHandler(Widget,
    RegisterEventHandler(@CarbonScrollable_GetInfo),
    1, @TmpSpec, Pointer(Self), nil);

  FScrollView := EmbedInScrollView(AParams);
  FScrollSize := Classes.Point(0, 0);
  FScrollMin := Classes.Point(0, 0);
  FScrollPageSize := Classes.Point(0, 0);
  FScrollOrigin := GetHIPoint(0, 0);
  FMulX := 1;
  FMulY := 1;

  if LCLObject.ClassNameIs('TSynEdit') then
    FTextFractional := False
  else
    FTextFractional := True;
    
  inherited;
end;

{------------------------------------------------------------------------------
  Method:  TCarbonCustomControl.DestroyWidget

  Clean-up
 ------------------------------------------------------------------------------}
procedure TCarbonCustomControl.DestroyWidget;
begin
  if (FScrollView <> Widget) and (FScrollView <> nil) then DisposeControl(FScrollView);
  
  inherited DestroyWidget;
end;

procedure TCarbonCustomControl.AddToWidget(AParent: TCarbonWidget);
begin
  inherited AddToWidget(AParent);
  // Updating ScrollInfo of the control. Sometimes Carbon shows "unused" scrollbars #16613
  SendScrollUpdate;
end;

{------------------------------------------------------------------------------
  Method:  TCarbonCustomControl.GetFrame
  Params:  Frame index
  Returns: Frame area control
 ------------------------------------------------------------------------------}
function TCarbonCustomControl.GetFrame(Index: Integer): ControlRef;
begin
  Result := FScrollView;
end;

function TCarbonCustomControl.GetForceEmbedInScrollView:Boolean;
begin
  Result:=True;
end;

{------------------------------------------------------------------------------
  Method:  TCarbonCustomControl.GetValidEvents
  Returns: Set of events with installed handlers
 ------------------------------------------------------------------------------}
class function TCarbonCustomControl.GetValidEvents: TCarbonControlEvents;
begin
  Result := [cceDraw];
end;

{------------------------------------------------------------------------------
  Method:  TCarbonCustomControl.Draw

  Draw event handler
 ------------------------------------------------------------------------------}
procedure TCarbonCustomControl.Draw;
var
  DC: TCarbonDeviceContext;
  Color: TColor;
begin
  if Context <> nil then
  begin
    DC := (Context as TCarbonDeviceContext);
    
    if DC.CGContext <> nil then
    begin
      if DC.CurrentBrush <> nil then // apply control background color
      begin
        Color := LCLObject.Color;
        if Color = clDefault then
          DC.CurrentBrush.SetColor(LCLObject.GetDefaultColor(dctBrush), False)
        else
        if Color <> clBtnFace then
          DC.CurrentBrush.SetColor(Color, True)
        else
          DC.CurrentBrush.SetColor(Color, False);

        DC.CurrentBrush.Apply(DC, False);
        if (Color <> clBtnFace) and (Color <> clDefault) then
          DC.FillRect(DC.GetClipRect, DC.CurrentBrush);
      end;
    end;
    
    DC.TextFractional := TextFractional;
  end;
end;

{------------------------------------------------------------------------------
  Method:  TCarbonCustomControl.GetInfo
  Params:  AImageSize - Size of entire scrollable area
           AViewSize  - Size of scrollable page
           ALineSize  - Size of scrollable line
           AOrigin    - Scroll position

  Handles scrollable get info event
 ------------------------------------------------------------------------------}
procedure TCarbonCustomControl.GetInfo(out AImageSize, AViewSize, ALineSize: HISize;
  out AOrigin: HIPoint);
var
  C: TRect;
begin
  // modify coordinates to fit real page size
  c := LCLObject.BoundsRect;
  if FScrollPageSize.X = 0 then FMulX := 1
  else
    FMulX := (C.Right - C.Left) / FScrollPageSize.X;
  if FScrollPageSize.Y = 0 then FMulY := 1
  else
    FMulY := (C.Bottom - C.Top) / FScrollPageSize.Y;
  
  AOrigin := GetHIPoint(Round(FScrollOrigin.X * FMulX), Round(FScrollOrigin.Y * FMulY));
  AImageSize := GetHISize(Round(FScrollSize.X * FMulX), Round(FScrollSize.Y * FMulY));

  GetBounds(C);
  AViewSize := GetHISize(C.Right - C.Left, C.Bottom - C.Top);

  if FMulX > 1 then
    ALineSize.width := FMulX
  else
    ALineSize.width := 10;
    
  if FMulY > 1 then
    ALineSize.height := FMulY
  else
    ALineSize.height := 20;
  
  {$IFDEF VerboseScroll}
    DebugLn('TCarbonCustomControl.GetInfo ' + LCLObject.Name + ' Origin: ' +
      DbgS(AOrigin) + ' Image: ' + DbgS(AImageSize) + ' View: ' +
      DbgS(AViewSize) + ' Line: ' + DbgS(ALineSize));
  {$ENDIF}
end;

{------------------------------------------------------------------------------
  Method:  TCarbonCustomControlScrollTo
  Params:  ANewOrigin - New scroll position

  Handles scrollable scroll to event
 ------------------------------------------------------------------------------}
procedure TCarbonCustomControl.ScrollTo(const ANewOrigin: HIPoint);
var
  ScrollMsg: TLMScroll;
  I: Integer;
begin
  {$IFDEF VerboseScroll}
    DebugLn('TCarbonCustomControl.ScrollTo ' + LCLObject.Name + ' Origin: ' +
      DbgS(ANewOrigin));
  {$ENDIF}
  
  if FMulX = 0 then FScrollOrigin.X := 0
  else
    FScrollOrigin.X := Round(ANewOrigin.X / FMulX);
  if FMulY = 0 then FScrollOrigin.Y := 0
  else
    FScrollOrigin.Y := Round(ANewOrigin.Y / FMulY);
  
  // send vertical scroll
  FillChar(ScrollMsg{%H-}, SizeOf(TLMScroll), 0);
  with ScrollMsg do
  begin
    Msg := LM_VSCROLL;
    Pos := Round(FScrollOrigin.Y) + FScrollMin.Y;
    ScrollCode := SB_THUMBPOSITION;
  end;
  DeliverMessage(LCLObject, ScrollMsg);
  
  // send horizontal scroll
  FillChar(ScrollMsg, SizeOf(TLMScroll), 0);
  with ScrollMsg do
  begin
    Msg := LM_HSCROLL;
    Pos := Round(FScrollOrigin.X) + FScrollMin.X;
    ScrollCode := SB_THUMBPOSITION;
  end;
  DeliverMessage(LCLObject, ScrollMsg);
  
  // force update all child views - BUG in OS X
  for I := 0 to LCLObject.ControlCount - 1 do
    if (LCLObject.Controls[I] is TWinControl) and
      (LCLObject.Controls[I] as TWinControl).HandleAllocated and
      TCarbonWidget((LCLObject.Controls[I] as TWinControl).Handle).IsVisible then
    begin
      TCarbonWidget((LCLObject.Controls[I] as TWinControl).Handle).ShowHide(False);
      TCarbonWidget((LCLObject.Controls[I] as TWinControl).Handle).ShowHide(True);
    end;

  // scroll bars can change client rect - update it
  UpdateLCLClientRect;
  
  OSError(
    HiViewSetNeedsDisplay(Widget, True), Self, 'ScrollTo', SViewNeedsDisplay);
end;

procedure TCarbonCustomControl.Invalidate(Rect:PRect);
var
  v : HIViewRef;
  r : HIRect;
  b : HIRect;
begin
  inherited Invalidate(Rect);

  // Forced invalidation of ScrollBars
  if Assigned(FScrollView) and not Assigned(Rect) then
  begin
    v:=HIViewGetFirstSubview(FScrollView);
    while Assigned(v) do
    begin
      HIViewSetNeedsDisplay(v, true);
      v:=HIViewGetNextView(v);
    end;
  end
  else
  begin
    v:=HIViewGetFirstSubview(FScrollView);
    r:=RectToCGRect(Rect^);
    while Assigned(v) do
    begin
      HIViewGetBounds(v, b);
      r.origin.x:=Rect^.Left+b.origin.x;
      r.origin.y:=Rect^.Top+b.origin.y;
      OSError(
        HIViewSetNeedsDisplayInRect(v, r, True), Self,
        SInvalidate, SViewNeedsDisplayRect);
      v:=HIViewGetNextView(v);
    end;
  end;
end;

{------------------------------------------------------------------------------
  Method:  TCarbonCustomControl.SetColor
  Params:  AColor - New color

  Sets the color of control (for edit like controls)
 ------------------------------------------------------------------------------}
procedure TCarbonCustomControl.SetColor(const AColor: TColor);
begin
  // not supported
end;

{------------------------------------------------------------------------------
  Method:  TCarbonCustomControl.SetFont
  Params:  AFont - New font

  Sets the font of control
 ------------------------------------------------------------------------------}
procedure TCarbonCustomControl.SetFont(const AFont: TFont);
begin
  // not supported
end;

{------------------------------------------------------------------------------
  Method:  TCarbonCustomControl.SetScrollInfo
  Params:  SBStyle    - Scrollbar type (SB_VERT, SB_HORZ)
           ScrollInfo - Scrolling info
  Returns: The new scroll bar position

  Sets the scrolling info of the specified scroll bar
 ------------------------------------------------------------------------------}
function TCarbonCustomControl.SetScrollInfo(SBStyle: Integer;
  const ScrollInfo: TScrollInfo): Integer;
begin
  {$IFDEF VerboseScroll}
    DebugLn('TCarbonCustomControl.SetScrollInfo ' + LCLObject.Name +
      ' SBStyle: ' + DbgS(SBStyle) + ' ' + DbgS(ScrollInfo));
  {$ENDIF}

  if (SIF_RANGE and ScrollInfo.fMask) > 0 then
  begin
    if SBStyle = SB_HORZ then
    begin
      FScrollSize.X := (ScrollInfo.nMax - ScrollInfo.nMin + 1);
      FScrollMin.X := ScrollInfo.nMin;
    end;
    if SBStyle = SB_VERT then
    begin
      FScrollSize.Y := (ScrollInfo.nMax - ScrollInfo.nMin + 1);
      FScrollMin.Y := ScrollInfo.nMin;
    end;
  end;
  
  if (SIF_POS and ScrollInfo.fMask) > 0 then
  begin
    if SBStyle = SB_HORZ then
      FScrollOrigin.X := ScrollInfo.nPos - FScrollMin.X;
    if SBStyle = SB_VERT then
      FScrollOrigin.Y := ScrollInfo.nPos - FScrollMin.Y;
  end;
  
  if (SIF_PAGE and ScrollInfo.fMask) > 0 then
  begin
    if SBStyle = SB_HORZ then
      FScrollPageSize.X := ScrollInfo.nPage;
    if SBStyle = SB_VERT then
      FScrollPageSize.Y := ScrollInfo.nPage;
  end;

  if SBStyle = SB_HORZ then
    Result := Round(FScrollOrigin.X);
  if SBStyle = SB_VERT then
    Result := Round(FScrollOrigin.Y);
  
  if (SBStyle in [SB_HORZ, SB_VERT]) and
    ((ScrollInfo.fMask and (SIF_RANGE or SIF_POS or SIF_PAGE)) > 0) then
    SendScrollUpdate;
end;

{------------------------------------------------------------------------------
  Method:  TCarbonCustomControl.GetScrollInfo
  Params:  SBStyle    - Scrollbar type (SB_VERT, SB_HORZ)
           ScrollInfo - Record fo scrolling info
  Returns: If the function suceeds

  Gets the scrolling info of the specified scroll bar
 ------------------------------------------------------------------------------}
procedure TCarbonCustomControl.GetScrollInfo(SBStyle: Integer;
  var ScrollInfo: TScrollInfo);
var
  AImageSize, AViewSize, ALineSize: HISize;
  AOrigin: HIPoint;
  Pt: TPoint;
begin
  {$IFDEF VerboseScroll}
    DebugLn('TCarbonCustomControl.GetScrollInfo ' + LCLObject.Name +
      ' SBStyle: ' + DbgS(SBStyle) + ' ' + DbgS(ScrollInfo));
  {$ENDIF}
  
  if (SIF_RANGE and ScrollInfo.fMask) > 0 then
  begin
    ScrollInfo.nMin := 0;
    
    if SBStyle = SB_HORZ then
      ScrollInfo.nMax := FScrollSize.X - FScrollMin.X - 1;
    if SBStyle = SB_VERT then
      ScrollInfo.nMax := FScrollSize.Y - FScrollMin.Y - 1;
  end;

  if ((SIF_POS and ScrollInfo.fMask) > 0) then
  begin
    if SBStyle = SB_HORZ then
      ScrollInfo.nPos := Trunc(FScrollOrigin.X) + FScrollMin.X;
    if SBStyle = SB_VERT then
      ScrollInfo.nPos := Trunc(FScrollOrigin.Y) + FScrollMin.Y;
  end;

  if (SIF_PAGE and ScrollInfo.fMask) > 0 then
  begin
    if SBStyle = SB_HORZ then
      ScrollInfo.nPage := FScrollPageSize.X;
    if SBStyle = SB_VERT then
      ScrollInfo.nPage := FScrollPageSize.Y;
  end;

  if ((SIF_TRACKPOS and ScrollInfo.fMask) > 0) then
  begin
    GetInfo(AImageSize, AViewSize, ALineSize, AOrigin);
    Pt := HIPointToPoint(AOrigin);
    if SBStyle = SB_HORZ then
      ScrollInfo.nTrackPos := Pt.X
    else
    if SBStyle = SB_VERT then
      ScrollInfo.nTrackPos := Pt.Y;
  end;
  
  {$IFDEF VerboseScroll}
    DebugLn('TCarbonCustomControl.GetScrollInfo Result: ' + DbgS(ScrollInfo));
  {$ENDIF}
end;

function TCarbonCustomControl.GetScrollbarVisible(SBStyle: Integer): Boolean;
begin
  case SBStyle of
    SB_VERT:
      Result := FScrollPageSize.Y < (FScrollSize.Y - FScrollMin.Y);
    SB_HORZ:
      Result := FScrollPageSize.X < (FScrollSize.X - FScrollMin.X);
  else
    Result := False;
  end;
end;

{ TCarbonScrollingWinControl }

{------------------------------------------------------------------------------
  Method:  TCarbonScrollingWinControl.CreateWidget
  Params:  AParams - Creation parameters

  Creates Carbon scrolling window control
 ------------------------------------------------------------------------------}
procedure TCarbonScrollingWinControl.CreateWidget(const AParams: TCreateParams);
var
  Params: TCreateParams;
begin
  Params := AParams;
  // add both scrollbars
  Params.Style := Params.Style or WS_HSCROLL or WS_VSCROLL;
  
  inherited CreateWidget(Params);
end;

{------------------------------------------------------------------------------
  Method:  TCarbonScrollingWinControl.GetForceEmbedInScrollView
  Returns: Whether use scroll view even if no scroll bars are needed
 ------------------------------------------------------------------------------}
function TCarbonScrollingWinControl.GetForceEmbedInScrollView: Boolean;
begin
  Result := True;
end;

function TCarbonScrollingWinControl.GetWindowRelativePos(winX, winY: Integer): TPoint;
var
  sz : HISize;
  org : HIPoint;
begin
  Result:=inherited GetWindowRelativePos(winX, winY);
  GetInfo(sz, sz, sz, org);
  dec(Result.X, Trunc(org.x));
  dec(Result.Y, Trunc(org.y));
end;

function TCarbonScrollingWinControl.GetPreferredSize: TPoint;
begin
  Result.X:=0;
  Result.Y:=0;
end;

{ TCarbonGroupBox }


function CarbonGroupBox_Draw(ANextHandler: EventHandlerCallRef;
  AEvent: EventRef;
  AWidget: TCarbonWidget): OSStatus; {$IFDEF darwin}mwpascal;{$ENDIF}
var
  ABox    : TCarbonGroupBox;
  Context : CGContextRef;
  c : TColorRef;
  b : TRect;
const
  rgbkoef = 1 / 255;
begin
  {$IFDEF VerbosePaint}
    Debugln('CarbonGroupBox_Draw ', DbgSName(AWidget.LCLObject));
  {$ENDIF}

  ABox := (AWidget as TCarbonGroupBox);

  try
    Context := nil;
    if (ABox.FBoxColor <> clBtnFace) and (ABox.FBoxColor <> clDefault) then
    begin
      if OSError(
        GetEventParameter(AEvent, kEventParamCGContextRef, typeCGContextRef, nil,
          SizeOf(CGContextRef), nil, @Context),
        'CarbonGroupBox_Draw', SGetEvent, 'kEventParamCGContextRef') then Exit;
      if Assigned(Context) then
      begin
        c := ColorToRGB(ABox.FBoxColor);
        ABox.GetBounds(b{%H-});
        CGContextSaveGState(Context);
        CGContextSetRGBFillColor(Context, (c and $FF) * rgbkoef, ((c shr 8) and $FF)*rgbkoef,
          ((c shr 16) and $FF)*rgbkoef, 1);
        with b do CGContextFillRect(Context, RectToCGRect(Bounds(0,0, Right-Left, Bottom-Top)));
        CGContextRestoreGState(Context);
      end;
    end;

    // let carbon draw/update
    Result := CallNextEventHandler(ANextHandler, AEvent);

  finally
  end;
  {$IFDEF VerbosePaint}
    Debugln('CarbonGroupBox_Draw end ', DbgSName(AWidget.LCLObject));
  {$ENDIF}
end;


procedure TCarbonGroupBox.RegisterEvents;
var
  TmpSpec: EventTypeSpec;
begin
  inherited;
  TmpSpec := MakeEventSpec(kEventClassControl, kEventControlDraw);
  InstallControlEventHandler(Widget,
    RegisterEventHandler(@CarbonGroupBox_Draw),
    1, @TmpSpec, Pointer(Self), nil);
end;

{------------------------------------------------------------------------------
  Method:  TCarbonGroupBox.CreateWidget
  Params:  AParams - Creation parameters

  Creates Carbon custom group box
 ------------------------------------------------------------------------------}
procedure TCarbonGroupBox.CreateWidget(const AParams: TCreateParams);
var
  Control: ControlRef;
  R: TRect;
begin
  if OSError(
    CreateGroupBoxControl(GetTopParentWindow, ParamsToCarbonRect(AParams),
      nil, not (LCLObject.Parent is TCustomGroupBox), Control{%H-}),
    Self, SCreateWidget, 'CreateGroupBoxControl') then RaiseCreateWidgetError(LCLObject);

  Widget := Control;
  
  if not GetClientRect(R{%H-}) then
  begin
    DebugLn('TCarbonGroupBox.CreateWidget Error - no content region!');
    Exit;
  end;
  
  FUserPane := CreateCustomHIView(RectToCGRect(R));
  if FUserPane = nil then RaiseCreateWidgetError(LCLObject);
    
  OSError(HIViewSetVisible(FUserPane, True), Self, SCreateWidget, SViewVisible);
  
  if OSError(HIViewAddSubview(Control, FUserPane), Self, SCreateWidget,
    SViewAddView) then RaiseCreateWidgetError(LCLObject);
  
  inherited;

  SetText(AParams.Caption);
end;

{------------------------------------------------------------------------------
  Method:  TCarbonGroupBox.DestroyWidget
  
  Clean-up
 ------------------------------------------------------------------------------}
procedure TCarbonGroupBox.DestroyWidget;
begin
  DisposeControl(FUserPane);

  inherited DestroyWidget;
end;

{------------------------------------------------------------------------------
  Method:  TCarbonGroupBox.GetContent
  Returns: Content area control
 ------------------------------------------------------------------------------}
function TCarbonGroupBox.GetContent: ControlRef;
begin
  Result := FUserPane;
end;

function TCarbonGroupBox.GetPreferredSize:TPoint;
const
  DefaultWidth = 8;
  DefaultHeight = 22;
var
  ContentRect: TRect;
  BoundsRect: TRect;
begin
  Result := inherited;
  if GetBounds(BoundsRect{%H-}) and
     ((BoundsRect.Right - BoundsRect.Left) = Result.X) and
     ((BoundsRect.Bottom - BoundsRect.Top) = Result.Y) then
  begin
    // OSX does not know the preferred size and returned us the bounds rect size
    Result.X := DefaultWidth;
    Result.Y := DefaultHeight;
  end
  else
  if GetClientRect(ContentRect{%H-}) then
  begin
    Dec(Result.X, ContentRect.Right - ContentRect.Left);
    Dec(Result.Y, ContentRect.Bottom - ContentRect.Top);
  end;
end;

{------------------------------------------------------------------------------
  Method:  TCarbonGroupBox.GetClientRect
  Params:  ARect - Record for client area coordinates
  Returns: If the function succeeds

  Returns the control client rectangle relative to the control origin
 ------------------------------------------------------------------------------}
function TCarbonGroupBox.GetClientRect(var ARect: TRect): Boolean;
begin
  Result := GetControlContentRect(ARect);
end;

{------------------------------------------------------------------------------
  Method:  TCarbonGroupBox.SetBounds
  Params:  ARect - Record for control coordinates
  Returns: If function succeeds

  Sets the control bounding rectangle relative to the client origin of its
  parent
 ------------------------------------------------------------------------------}
function TCarbonGroupBox.SetBounds(const ARect: TRect): Boolean;
begin
  Result := False;
  if not inherited SetBounds(ARect) then Exit;
  Result := UpdateContentBounds;
end;

{------------------------------------------------------------------------------
  Method:  TCarbonGroupBox.SetColor
  Params:  AColor - color of group box

  Sets groupbox's color
 ------------------------------------------------------------------------------}
procedure TCarbonGroupBox.SetColor(const AColor: TColor);
begin
  FBoxColor := AColor;
  inherited SetColor(AColor);
end;

{ TCarbonStatusBar }

type
  TStatusItemData = record
    Text  : AnsiString;
    Width : Integer;
    Align : TAlignment;
  end;

  TItemDrawEvent = procedure (ItemIndex: Integer; const r: TRect; const ItemData: TStatusItemData) of object;

const
  StatusHeight = 15;

procedure DrawSection(Ctx: CGContextRef; const r: TRect; data: TStatusItemData);
var
  cr    : CGRect;
  cf    : CFStringRef;
  info  : HIThemeButtonDrawInfo;
  txtinfo : HIThemeTextInfo;
const
  txtHorzFlush : array [TAlignment] of Integer =
    (kHIThemeTextHorizontalFlushLeft,kHIThemeTextHorizontalFlushRight,kHIThemeTextHorizontalFlushCenter);
begin
  cr:=RectToCGRect(r);
  FillChar(info{%H-}, sizeof(info), 0);
  info.kind:=kThemeListHeaderButton;
  info.state:=kThemeStateActive;
  HIThemeDrawButton( cr, info, ctx, 0, nil);

  cr.origin.x:=cr.origin.x+2;
  cr.origin.y:=cr.origin.y+1;
  cr.size.width:=cr.size.width-6;
  if data.Text<>'' then
  begin
    CreateCFString(data.Text, cf);
    if Assigned(cf) then
    begin
      FillChar(txtinfo{%H-}, sizeof(txtinfo), 0);
      txtinfo.version:=1;
      //txtinfo.fontID:=kThemeMiniSystemFont;
      txtinfo.horizontalFlushness:=txtHorzFlush[data.align];
      txtinfo.fontID:=kThemeSmallSystemFont;
      txtinfo.state:=kThemeStateActive;
      HIThemeSetTextFill(kThemeTextColorListView, nil, ctx, 0);
      HIThemeDrawTextBox(cf, cr, txtinfo, ctx, 0);
    end;
    CFRelease(cf);
  end;
end;

procedure DrawCarbonStatusBar(Ctx: CGContextRef; const bnd: TRect; Items: array of TStatusItemData; OnItemDraw: TItemDrawEvent);
var
  i   : Integer;
  x   : Integer;
  xn  : Integer;
  r   : TRect;
const
  dummy : TStatusItemData = (Text:''; Width:0; align: taLeftJustify);
  ExtraWidth=2;
begin
  if length(Items)>0 then
  begin
    x:=bnd.Left;
    for i:=0 to length(Items)-2 do
    begin
      xn:=x+Items[i].Width;
      r:=Types.Rect(x, bnd.Top, xn+ExtraWidth, bnd.Bottom);
      DrawSection(Ctx, r, Items[i]);
      dec(r.Right, ExtraWidth);
      if Assigned(OnItemDraw) then OnItemDraw(i, r, Items[i]);
      x:=xn;
    end;

    i:=length(Items)-1;
    r:=Types.Rect(x, bnd.Top, bnd.Right, bnd.Bottom);
    DrawSection(Ctx, r, Items[i]);
    if Assigned(OnItemDraw) then OnItemDraw(i, r, Items[i]);
  end
  else
  begin
    DrawSection(Ctx, bnd, dummy);
    if Assigned(OnItemDraw) then OnItemDraw(-1, bnd, dummy);
  end;
end;

{------------------------------------------------------------------------------
  Method:  TCarbonStatusBar.CreateWidget
  Params:  AParams - Creation parameters

  Creates Carbon status bar
 ------------------------------------------------------------------------------}
procedure TCarbonStatusBar.CreateWidget(const AParams: TCreateParams);
{$ifdef CarbonOldStatusBar}
var
  Control: ControlRef;
{$endif}
begin
  {$ifdef CarbonOldStatusBar}
  if OSError(
    CreatePlacardControl(GetTopParentWindow, ParamsToCarbonRect(AParams), Control),
    Self, SCreateWidget, 'CreatePlacardControl') then RaiseCreateWidgetError(LCLObject);
  Widget := Control;
  {$else}
  Widget := CreateCustomHIView(ParamsToHIRect(AParams), LCLObject.ControlStyle);
  {$endif}

  inherited;

  {$ifdef CarbonOldStatusBar}
  FPanels := TObjectList.Create(True);
  UpdatePanel; // add panels
  {$endif}
end;

{------------------------------------------------------------------------------
  Method:  TCarbonStatusBar.DestroyWidget

  Clean-up
 ------------------------------------------------------------------------------}
procedure TCarbonStatusBar.DestroyWidget;
begin
  {$ifdef CarbonOldStatusBar}
  FPanels.Free;
  {$endif}
  inherited DestroyWidget;
end;

{------------------------------------------------------------------------------
  Method:  TCarbonStatusBar.GetValidEvents
  Returns: Set of events with installed handlers
 ------------------------------------------------------------------------------}
class function TCarbonStatusBar.GetValidEvents: TCarbonControlEvents;
begin
  Result := [cceDraw];
end;

{------------------------------------------------------------------------------
  Method:  TCarbonStatusBar.Draw

  Draw event handler
 ------------------------------------------------------------------------------}
procedure TCarbonStatusBar.Draw;
var
  StatusBar : TStatusBar;
  R         : TRect;
  {$ifndef CarbonOldStatusBar}
  items     : array of TStatusItemData;
  i         : Integer;
  {$endif}
begin
  StatusBar := LCLObject as TStatusBar;
  {$ifdef CarbonOldStatusBar}
  if StatusBar.SimplePanel and (StatusBar.SimpleText <> '') then
  begin
    GetClientRect(R);
    
    (Context as TCarbonDeviceContext).ExtTextOut(R.Top, R.Left, 0, nil,
      PChar(StatusBar.SimpleText), Length(StatusBar.SimpleText), nil);
  end;
  {$else}
  StatusBar := LCLObject as TStatusBar;
  GetClientRect(r{%H-});
  if StatusBar.SimplePanel then
  begin
    SetLength(items, 1);
    items[0].Width:=r.Right-r.Left;
    items[0].Text:=StatusBar.SimpleText;
    items[0].Align:=taLeftJustify; //todo: select proper Justify based on lanuage text-mode (r2l, l2r)!
  end
  else
  begin
    SetLength(items, StatusBar.Panels.Count);
    for i:=0 to length(items)-1 do
    begin
      items[i].Width:=StatusBar.Panels[i].Width;
      items[i].Text:=StatusBar.Panels[i].Text;
      items[i].Align:=StatusBar.Panels[i].Alignment;
    end;
  end;
  DrawCarbonStatusBar( TCarbonContext(Context).CGContext, r, items, nil);
  {$endif}
end;

{------------------------------------------------------------------------------
  Method:  TCarbonStatusBar.GetPreferredSize
  Returns: The preffered size of status bar for autosizing or (0, 0)
 ------------------------------------------------------------------------------}
function TCarbonStatusBar.GetPreferredSize: TPoint;
{$ifdef CarbonOldStatusBar}
const
  CarbonStatusBarHeight = 20; // should statusbar height be evaluated of the default font's height?
{$else}
const
  CarbonStatusBarHeight = StatusHeight; // should statusbar height be evaluated of the default font's height?
{$endif}
begin
  Result := inherited GetPreferredSize;
  
  // stretch status bar to whole window width
  if LCLObject.Parent <> nil then
  begin
    Result.X := LCLObject.Parent.ClientWidth;
    Result.Y := CarbonStatusBarHeight;
  end;
end;

{------------------------------------------------------------------------------
  Method:  TCarbonStatusBar.SetColor
  Params:  AColor - New color

  Sets the color of control (for edit like controls)
 ------------------------------------------------------------------------------}
procedure TCarbonStatusBar.SetColor(const AColor: TColor);
begin
  // not supported
end;

{------------------------------------------------------------------------------
  Method:  TCarbonStatusBar.SetFont
  Params:  AFont - New font

  Sets the font of control
 ------------------------------------------------------------------------------}
procedure TCarbonStatusBar.SetFont(const AFont: TFont);
begin
  // not supported
end;

{------------------------------------------------------------------------------
  Method:  TCarbonStatusBar.UpdatePanel
  Params:  AIndex - Index of panel to update or -1 to update all

  Updates properties of the specified panel(s) of status bar
 ------------------------------------------------------------------------------}
procedure TCarbonStatusBar.UpdatePanel(AIndex: Integer);
{$ifdef CarbonOldStatusBar}
var
  StatusBar: TStatusBar;
  I, X: Integer;
  Panel: TPanel;
{$endif}
begin
{$ifdef CarbonOldStatusBar}
  StatusBar := LCLObject as TStatusBar;

  if StatusBar.SimplePanel then
  begin
    // hide panels
    for I := 0 to FPanels.Count - 1 do (FPanels[I] as TPanel).Hide;
  end
  else
  begin
    X := 0;

    for I := 0 to StatusBar.Panels.Count - 1 do
    begin
      if I >= FPanels.Count then // create new panel
      begin
        Panel := TPanel.Create(nil);
        Panel.Visible := False;
        
        Panel.Height := LCLObject.Height;
        Panel.Parent := LCLObject;
        
        FPanels.Add(Panel);
      end
      else Panel := FPanels[I] as TPanel;
      
      if I >= AIndex then // reposition panel
      begin
        Panel.Left := X;
        
        if (I = AIndex) or (AIndex = -1) then // update panel attrs
        begin
          Panel.Width := StatusBar.Panels[I].Width;
          if I = StatusBar.Panels.Count - 1 then
            Panel.Align:=alClient
          else
            Panel.Align:=alLeft;
          Panel.Caption := StatusBar.Panels[I].Text;
          Panel.Alignment := StatusBar.Panels[I].Alignment;
          Panel.BevelOuter := TPanelBevel(StatusBar.Panels[I].Bevel);
        end;
      end;
      Panel.Show;
      
      Inc(X, Panel.Width);
    end;
    
    // delete unneeded panels
    for I := FPanels.Count - 1 downto StatusBar.Panels.Count do
      FPanels.Delete(I);
  end;
{$endif}
  Invalidate;
end;

{ TCarbonStaticText }

{------------------------------------------------------------------------------
  Method:  TCarbonStaticText.CreateWidget
  Params:  AParams - Creation parameters

  Creates Carbon static text
 ------------------------------------------------------------------------------}
procedure TCarbonStaticText.CreateWidget(const AParams: TCreateParams);
var
  Control: ControlRef;
  MultiLine: Boolean = True;
  FontStyle: ControlFontStyleRec;
begin
  FontStyle.flags := kControlUseJustMask;
  case (LCLObject as TCustomStaticText).Alignment of
  taLeftJustify:  FontStyle.just := teFlushLeft;
  taRightJustify: FontStyle.just := teFlushRight;
  taCenter:       FontStyle.just := teCenter;
  end;

  if OSError(
    CreateStaticTextControl(GetTopParentWindow, ParamsToCarbonRect(AParams),
      nil, @FontStyle, Control{%H-}),
    Self, SCreateWidget, 'CreateStaticTextControl') then RaiseCreateWidgetError(LCLObject);

  Widget := Control;
    
  inherited;

  SetText(AParams.Caption);
  
  // switch on multi-line attribute
  OSError(
    SetControlData(Control, kControlEntireControl,
      kControlStaticTextIsMultilineTag, SizeOf(Boolean), @MultiLine),
    Self, SCreateWidget, SSetData, 'kControlStaticTextIsMultilineTag');
end;

const
  // values are used from Interface Builder
  StdStaticTextNormalSize = 16;
  StdStaticTextSmallSize = 13;
  StdStaticTextTinySize = 0; // 11

procedure TCarbonStaticText.BoundsChanged;
begin
  inherited BoundsChanged;
  SetControlViewStyle(Widget, StdStaticTextTinySize, StdStaticTextSmallSize, StdStaticTextNormalSize);
end;

{------------------------------------------------------------------------------
  Method:  TCarbonStaticText.SetAlignment
  Params:  AAlignment      - New caption alignment

  Sets the new caption alignment of Carbon static text
 ------------------------------------------------------------------------------}
procedure TCarbonStaticText.SetAlignment(AAlignment: TAlignment);
var
  FontStyle: ControlFontStyleRec;
const
  SName = 'SetAlignment';
begin
  // get static text font style and change only justification
  OSError(
    GetControlData(ControlRef(Widget), kControlEntireControl,
      kControlStaticTextStyleTag, SizeOf(FontStyle), @FontStyle, nil),
    Self, SName, SGetData);

  FontStyle.flags := FontStyle.flags or kControlUseJustMask;
  case AAlignment of
  taLeftJustify : FontStyle.just := teFlushLeft;
  taRightJustify: FontStyle.just := teFlushRight;
  taCenter      : FontStyle.just := teCenter;
  end;

  OSError(
    SetControlData(ControlRef(Widget), kControlEntireControl,
      kControlStaticTextStyleTag, SizeOf(FontStyle), @FontStyle),
    Self, SName, SSetData);

  Invalidate;
end;



end.



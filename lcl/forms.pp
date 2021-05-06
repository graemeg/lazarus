{
 /***************************************************************************
                                  forms.pp
                                  --------
                             Component Library Code


                   Initial Revision  : Sun Mar 28 23:15:32 CST 1999
                   Revised : Sat Jul 15 1999

 ***************************************************************************/

 *****************************************************************************
  This file is part of the Lazarus Component Library (LCL)

  See the file COPYING.modifiedLGPL.txt, included in this distribution,
  for details about the license.
 *****************************************************************************
}

unit Forms;

{$mode objfpc}{$H+}{$macro on}
{$I lcl_defines.inc}

interface

{$ifdef Trace}
  {$ASSERTIONS ON}
{$endif}

{$DEFINE HasDefaultValues}

uses
  // RTL + FCL
  Classes, SysUtils, Types, TypInfo, Math, CustApp,
  // LCL
  LCLStrConsts, LCLType, LCLProc, LCLIntf, LCLVersion, LCLClasses, InterfaceBase,
  LResources, Graphics, Menus, LMessages, CustomTimer, ActnList,
  ClipBrd, HelpIntfs, Controls, ImgList, Themes,
  // LazUtils
  LazFileUtils, LazUTF8, Maps, IntegerList, LazMethodList, LazLoggerBase,
  LazUtilities, GraphType, UITypes
  {$ifndef wince},gettext{$endif}// remove ifdefs when gettext is fixed and a new fpc is released
  ;

type
  // forward class declarations
  TIDesigner = class;
  TMonitor = class;
  TScrollingWinControl = class;

  TProcedure = procedure;
  TProcedureOfObject = procedure of object;

  // form position policies:
  TPosition = (
    poDesigned,        // use bounds from the designer (read from stream)
    poDefault,         // LCL decision (normally window manager decides)
    poDefaultPosOnly,  // designed size and LCL position
    poDefaultSizeOnly, // designed position and LCL size
    poScreenCenter,    // center form on screen (depends on DefaultMonitor)
    poDesktopCenter,   // center form on desktop (total of all screens)
    poMainFormCenter,  // center form on main form (depends on DefaultMonitor)
    poOwnerFormCenter, // center form on owner form (depends on DefaultMonitor)
    poWorkAreaCenter   // center form on working area (depends on DefaultMonitor)
    );

  TWindowState = (wsNormal, wsMinimized, wsMaximized, wsFullScreen);
  TCloseAction = (caNone, caHide, caFree, caMinimize);

  { Hint actions }

  TCustomHintAction = class(TCustomAction)
  published
    property Hint;
  end;


  { TControlScrollBar }

  TScrollBarKind = (sbHorizontal, sbVertical);
  TScrollBarInc = 1..32768;
  TScrollBarStyle = (ssRegular, ssFlat, ssHotTrack);
  EScrollBar = class(Exception) end;

  TControlScrollBar = class(TPersistent)
  private
    FAutoRange: Longint; // = Max(0, FRange - ClientSize)
    FIncrement: TScrollBarInc;
    FKind: TScrollBarKind;
    FPage: TScrollBarInc;
    FRange: Integer; // if AutoScroll=true this is the needed size of the child controls
    FSmooth: Boolean;
    FTracking: Boolean;
    FVisible: Boolean;
    FOldScrollInfo: TScrollInfo;
    FOldScrollInfoValid: Boolean;
  protected
    FControl: TWinControl;
    FPosition: Integer;
    function ControlHandle: HWnd; virtual;
    function GetAutoScroll: boolean; virtual;
    function GetIncrement: TScrollBarInc; virtual;
    function GetPage: TScrollBarInc; virtual;
    function GetPosition: Integer; virtual;
    function GetRange: Integer; virtual;
    function GetSize: integer; virtual;
    function GetSmooth: Boolean; virtual;
    function HandleAllocated: boolean; virtual;
    function IsRangeStored: boolean; virtual;
    procedure ControlUpdateScrollBars; virtual;
    procedure InternalSetRange(const AValue: Integer); virtual;
    procedure ScrollHandler(var Message: TLMScroll);
    procedure SetIncrement(const AValue: TScrollBarInc); virtual;
    procedure SetPage(const AValue: TScrollBarInc); virtual;
    procedure SetPosition(const Value: Integer);
    procedure SetRange(const AValue: Integer); virtual;
    procedure SetSmooth(const AValue: Boolean); virtual;
    procedure SetTracking(const AValue: Boolean);
    procedure SetVisible(const AValue: Boolean); virtual;
    procedure UpdateScrollBar; virtual;
    procedure InvalidateScrollInfo;
  {$ifdef VerboseScrollingWinControl}
    function DebugCondition: Boolean;
  {$endif}
    function GetHorzScrollBar: TControlScrollBar; virtual;
    function GetVertScrollBar: TControlScrollBar; virtual;
  protected
    function ScrollBarShouldBeVisible: Boolean; virtual; // should the widget be made visible?
  public
    constructor Create(AControl: TWinControl; AKind: TScrollBarKind);
    procedure Assign(Source: TPersistent); override;
    function IsScrollBarVisible: Boolean; virtual; // returns current widget state
    function ScrollPos: Integer; virtual;
    property Kind: TScrollBarKind read FKind;
    function GetOtherScrollBar: TControlScrollBar;
    property Size: integer read GetSize stored False;
    function ControlSize: integer; // return for vertical scrollbar the control width
    function ClientSize: integer; // return for vertical scrollbar the clientwidth
    function ClientSizeWithBar: integer; // return for vertical scrollbar the clientwidth with the bar, even if Visible=false
    function ClientSizeWithoutBar: integer; // return for vertical scrollbar the clientwidth without the bar, even if Visible=true
  published
    property Increment: TScrollBarInc read GetIncrement write SetIncrement default 8;
    property Page: TScrollBarInc read GetPage write SetPage default 80;
    property Smooth: Boolean read GetSmooth write SetSmooth default False;
    property Position: Integer read GetPosition write SetPosition default 0; // 0..Range-Page
    property Range: Integer read GetRange write SetRange stored IsRangeStored default 0; // >=Page
    property Tracking: Boolean read FTracking write SetTracking default False;
    property Visible: Boolean read FVisible write SetVisible default True;
  end;

  { TScrollingWinControl }

  TScrollingWinControl = class(TCustomControl)
  private
    FHorzScrollBar: TControlScrollBar;
    FVertScrollBar: TControlScrollBar;
    FAutoScroll: Boolean;
    FIsUpdating: Boolean;
    procedure SetHorzScrollBar(Value: TControlScrollBar);
    procedure SetVertScrollBar(Value: TControlScrollBar);
    procedure HideScrollbars;
  protected
    class procedure WSRegisterClass; override;
    procedure AlignControls(AControl: TControl; var ARect: TRect); override;
    function AutoScrollEnabled: Boolean; virtual;
    procedure CalculateAutoRanges; virtual;
    procedure CreateWnd; override;
    function GetClientScrollOffset: TPoint; override;
    function GetLogicalClientRect: TRect; override;// logical size of client area
    procedure DoOnResize; override;
    procedure GetPreferredSizeClientFrame(out aWidth, aHeight: integer); override;
    procedure WMSize(var Message: TLMSize); message LM_Size;
    procedure WMHScroll(var Message : TLMHScroll); message LM_HScroll;
    procedure WMVScroll(var Message : TLMVScroll); message LM_VScroll;
    procedure ComputeScrollbars; virtual;
    procedure SetAutoScroll(Value: Boolean); virtual;
    procedure Loaded; override;
    procedure Resizing(State: TWindowState); virtual;
    property AutoScroll: Boolean read FAutoScroll write SetAutoScroll default False;// auto show/hide scrollbars
    procedure SetAutoSize(Value: Boolean); override;
  public
    constructor Create(TheOwner : TComponent); override;
    destructor Destroy; override;
    function ScreenToClient(const APoint: TPoint): TPoint; override;
    function ClientToScreen(const APoint: TPoint): TPoint; override;
    procedure UpdateScrollbars;
    class function GetControlClassDefaultSize: TSize; override;
    procedure ScrollBy(DeltaX, DeltaY: Integer); override;
    procedure ScrollInView(AControl: TControl);
  published
    property HorzScrollBar: TControlScrollBar read FHorzScrollBar write SetHorzScrollBar;
    property VertScrollBar: TControlScrollBar read FVertScrollBar write SetVertScrollBar;
  end;


  { TScrollBox }

  TScrollBox = class(TScrollingWinControl)
  protected
    class procedure WSRegisterClass; override;
  public
    constructor Create(AOwner: TComponent); override;
  published
    property Align;
    property Anchors;
    property AutoSize;
    property AutoScroll default True;
    property BorderSpacing;
    property BiDiMode;
    property BorderStyle default bsSingle;
    property ChildSizing;
    property ClientHeight;
    property ClientWidth;
    property Constraints;
    property DockSite;
    property DragCursor;
    property DragKind;

    property DragMode;
    property Enabled;
    property Color nodefault;
    property Font;
    property ParentBackground default False;
    property ParentBiDiMode;
    property ParentColor;
    property ParentFont;
    property ParentShowHint;
    property PopupMenu;
    property ShowHint;
    property TabOrder;
    property TabStop;
    property Visible;
    //property OnCanResize;
    property OnClick;
    property OnConstrainedResize;
    property OnDblClick;
    property OnDockDrop;
    property OnDockOver;
    property OnDragDrop;
    property OnDragOver;
    property OnEndDock;
    property OnEndDrag;
    property OnEnter;
    property OnExit;
    property OnGetSiteInfo;
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
    property OnStartDock;
    property OnStartDrag;
    property OnUnDock;
    property OnPaint;
  end;

  TCustomDesignControl = class(TScrollingWinControl)
  private
    FScaled: Boolean;
    FDesignTimePPI: Integer;
    FPixelsPerInch: Integer;

    function DesignTimePPIIsStored: Boolean;
    procedure SetDesignTimePPI(const ADesignTimePPI: Integer);
  protected
    procedure SetScaled(const AScaled: Boolean); virtual;

    procedure DoAutoAdjustLayout(const AMode: TLayoutAdjustmentPolicy;
      const AXProportion, AYProportion: Double); override;
  public
    constructor Create(TheOwner: TComponent); override;

    procedure AutoAdjustLayout(AMode: TLayoutAdjustmentPolicy; const AFromPPI,
      AToPPI, AOldFormWidth, ANewFormWidth: Integer); override;
  public
    property DesignTimePPI: Integer read FDesignTimePPI write SetDesignTimePPI stored DesignTimePPIIsStored;
    property PixelsPerInch: Integer read FPixelsPerInch write FPixelsPerInch stored False;
    property Scaled: Boolean read FScaled write SetScaled default True;
  end;


  { TCustomFrame }

  TCustomFrame = class(TCustomDesignControl)
  private
    procedure AddActionList(ActionList: TCustomActionList);
    procedure RemoveActionList(ActionList: TCustomActionList);
    procedure ReadDesignLeft(Reader: TReader);
    procedure ReadDesignTop(Reader: TReader);
    procedure WriteDesignLeft(Writer: TWriter);
    procedure WriteDesignTop(Writer: TWriter);
  protected
    class procedure WSRegisterClass; override;
    procedure Notification(AComponent: TComponent;
      Operation: TOperation); override;
    procedure SetColor(Value: TColor); override;
    procedure SetParent(AParent: TWinControl); override;
    procedure SetParentBackground(const AParentBackground: Boolean); override;
    procedure CMParentColorChanged(var Message: TLMessage); message CM_PARENTCOLORCHANGED;
    procedure DefineProperties(Filer: TFiler); override;
    procedure CalculatePreferredSize(var PreferredWidth,
           PreferredHeight: integer; WithThemeSpace: Boolean); override;
    procedure UpdateOpaque;
  public
    constructor Create(AOwner: TComponent); override;
    procedure GetChildren(Proc: TGetChildProc; Root: TComponent); override;
    class function GetControlClassDefaultSize: TSize; override;

    property ParentBackground default True;
  end;

  TCustomFrameClass = class of TCustomFrame;


  { TFrame }

  TFrame = class(TCustomFrame)
  private
    FLCLVersion: string;
    function LCLVersionIsStored: boolean;
  public
    constructor Create(TheOwner: TComponent); override;
  published
    property Align;
    property Anchors;
    property AutoScroll;
    property AutoSize;
    property BiDiMode;
    property BorderSpacing;
    property ChildSizing;
    property ClientHeight;
    property ClientWidth;
    property Color nodefault;
    property Constraints;
    property DesignTimePPI;
    property DockSite;
    property DragCursor;
    property DragKind;
    property DragMode;
    property Enabled;
    property Font;
    property LCLVersion: string read FLCLVersion write FLCLVersion stored LCLVersionIsStored;
    property OnClick;
    property OnConstrainedResize;
    property OnContextPopup;
    property OnDblClick;
    property OnDockDrop;
    property OnDockOver;
    property OnDragDrop;
    property OnDragOver;
    property OnEndDock;
    property OnEndDrag;
    property OnEnter;
    property OnExit;
    property OnGetSiteInfo;
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
    property OnStartDock;
    property OnStartDrag;
    property OnUnDock;
    property ParentBackground;
    property ParentBiDiMode;
    property ParentColor;
    property ParentFont;
    property ParentShowHint;
    property PopupMenu;
    property Scaled;
    property ShowHint;
    property TabOrder;
    property TabStop;
    property Visible;
  end;


  { TCustomForm }

  TBorderIcon = ( // Form title bar items
    biSystemMenu, // system menu
    biMinimize,   // minimize button
    biMaximize,   // maximize button
    biHelp        // help button
  );
  TBorderIcons = set of TBorderIcon;

  TDefaultMonitor = ( // monitor to place form
    dmDesktop,        // use full desktop
    dmPrimary,        // use primary monitor
    dmMainForm,       // use monitor of main form
    dmActiveForm      // use monitor of active form
  );

  TFormStateType = (
    fsCreating,          // initializing (form streaming)
    fsVisible,           // form should be shown
    fsShowing,           // form handling WM_SHOWWINDOW message
    fsModal,             // form is modal
    fsCreatedMDIChild,   // todo: not mplemented
    fsBorderStyleChanged,// border style is changed before window handle creation
    fsFormStyleChanged,  // form style is changed before window handle creation
    fsFirstShow,         // form is shown for the first time
    fsDisableAutoSize    // disable autosize
    );
  TFormState = set of TFormStateType;

  TModalResult = UITypes.TModalResult;
  PModalResult = ^UITypes.TModalResult;

  TFormHandlerType = (
    fhtFirstShow,
    fhtClose,
    fhtCreate
    );

  TShowInTaskbar = (
    stDefault,  // use default rules for showing taskbar item
    stAlways,   // always show taskbar item for the form
    stNever     // never show taskbar item for the form
  );

  TPopupMode = (
    pmNone,     // modal: popup to active form or if not available, to main form; non-modal: no window parent
    pmAuto,     // modal & non-modal: popup to active form or if not available, to main form
    pmExplicit  // modal & non-modal: popup to PopupParent or if not available, to main form
  );

  TCloseEvent = procedure(Sender: TObject; var CloseAction: TCloseAction) of object;
  TCloseQueryEvent = procedure(Sender : TObject; var CanClose: Boolean) of object;
  TDropFilesEvent = procedure (Sender: TObject; const FileNames: array of string) of object;
  THelpEvent = function(Command: Word; Data: PtrInt; var CallHelp: Boolean): Boolean of object;
  TShortCutEvent = procedure (var Msg: TLMKey; var Handled: Boolean) of object;
  TModalDialogFinished = procedure (Sender: TObject; AResult: Integer) of object;


  TCustomForm = class(TCustomDesignControl)
  private
    FActive: Boolean;
    FActiveControl: TWinControl;
    FActiveDefaultControl: TControl;
    FAllowDropFiles: Boolean;
    FAlphaBlend: Boolean;
    FAlphaBlendValue: Byte;
    FBorderIcons: TBorderIcons;
    FDefaultControl: TControl;
    FCancelControl: TControl;
    FDefaultMonitor: TDefaultMonitor;
    FDesigner: TIDesigner;
    FFormStyle: TFormStyle;
    FFormUpdateCount: integer;
    FFormHandlers: array[TFormHandlerType] of TMethodList;
    FHelpFile: string;
    FIcon: TIcon;
    FOnShowModalFinished: TModalDialogFinished;
    FPopupMode: TPopupMode;
    FPopupParent: TCustomForm;
    FSmallIconHandle: HICON;
    FBigIconHandle: HICON;
    FKeyPreview: Boolean;
    FMenu: TMainMenu;
    FModalResult: TModalResult;
    FLastActiveControl: TWinControl;
    FLastFocusedControl: TWinControl;
    FOldBorderStyle: TFormBorderStyle;
    FOnActivate: TNotifyEvent;
    FOnClose: TCloseEvent;
    FOnCloseQuery: TCloseQueryEvent;
    FOnCreate: TNotifyEvent;
    FOnDeactivate: TNotifyEvent;
    FOnDestroy: TNotifyEvent;
    FOnDropFiles: TDropFilesEvent;
    FOnHelp: THelpEvent;
    FOnHide: TNotifyEvent;
    FOnShortcut: TShortCutEvent;
    FOnShow: TNotifyEvent;
    FOnWindowStateChange: TNotifyEvent;
    FPosition: TPosition;
    FRestoredLeft: integer;
    FRestoredTop: integer;
    FRestoredWidth: integer;
    FRestoredHeight: integer;
    FShowInTaskbar: TShowInTaskbar;
    FWindowState: TWindowState;
    FDelayedEventCtr: Integer;
    FDelayedOnChangeBounds, FDelayedOnResize: Boolean;
    FIsFirstOnShow, FIsFirstOnActivate: Boolean;
    function GetClientHandle: HWND;
    function GetEffectiveShowInTaskBar: TShowInTaskBar;
    function GetMonitor: TMonitor;
    function IsAutoScrollStored: Boolean;
    function IsForm: Boolean;
    function IsIconStored: Boolean;
    procedure CloseModal;
    procedure FreeIconHandles;
    procedure IconChanged(Sender: TObject);
    procedure DelayedEvent(Data: PtrInt);
    procedure SetActive(AValue: Boolean);
    procedure SetActiveControl(AWinControl: TWinControl);
    procedure SetActiveDefaultControl(AControl: TControl);
    procedure SetAllowDropFiles(const AValue: Boolean);
    procedure SetAlphaBlend(const AValue: Boolean);
    procedure SetAlphaBlendValue(const AValue: Byte);
    procedure SetBorderIcons(NewIcons: TBorderIcons);
    procedure SetFormBorderStyle(NewStyle: TFormBorderStyle);
    procedure SetCancelControl(NewControl: TControl);
    procedure SetDefaultControl(NewControl: TControl);
    procedure SetFormStyle(Value : TFormStyle);
    procedure SetIcon(AValue: TIcon);
    procedure SetMenu(Value: TMainMenu);
    procedure SetModalResult(Value: TModalResult);
    procedure SetPopupMode(const AValue: TPopupMode);
    procedure SetPopupParent(const AValue: TCustomForm);
    procedure SetPosition(Value: TPosition);
    procedure SetShowInTaskbar(Value: TShowInTaskbar);
    procedure SetLastFocusedControl(AControl: TWinControl);
    procedure SetWindowFocus;
    procedure SetWindowState(Value : TWindowState);
    procedure AddHandler(HandlerType: TFormHandlerType;
                         const Handler: TMethod; AsFirst: Boolean = false);
    procedure RemoveHandler(HandlerType: TFormHandlerType;
                            const Handler: TMethod);
    function FindDefaultForActiveControl: TWinControl;
    procedure UpdateMenu;
    procedure UpdateShowInTaskBar;
  protected
    procedure WMActivate(var Message : TLMActivate); message LM_ACTIVATE;
    procedure WMCloseQuery(var message: TLMessage); message LM_CLOSEQUERY;
    procedure WMHelp(var Message: TLMHelp); message LM_HELP;
    procedure WMShowWindow(var message: TLMShowWindow); message LM_SHOWWINDOW;
    procedure WMSize(var message: TLMSize); message LM_Size;
    procedure WMWindowPosChanged(var Message: TLMWindowPosChanged); message LM_WINDOWPOSCHANGED;
    procedure CMBiDiModeChanged(var Message: TLMessage); message CM_BIDIMODECHANGED;
    procedure CMParentBiDiModeChanged(var Message: TLMessage); message CM_PARENTBIDIMODECHANGED;
    procedure CMAppShowBtnGlyphChanged(var Message: TLMessage); message CM_APPSHOWBTNGLYPHCHANGED;
    procedure CMAppShowMenuGlyphChanged(var Message: TLMessage); message CM_APPSHOWMENUGLYPHCHANGED;
    procedure CMIconChanged(var Message: TLMessage); message CM_ICONCHANGED;
    procedure CMRelease(var Message: TLMessage); message CM_RELEASE;
    procedure CMActivate(var Message: TLMessage); message CM_ACTIVATE;
    procedure CMDeactivate(var Message: TLMessage); message CM_DEACTIVATE;
    procedure CMShowingChanged(var Message: TLMessage); message CM_SHOWINGCHANGED;
    procedure WMDPIChanged(var Msg: TLMessage); message LM_DPICHANGED;
  protected
    FActionLists: TList; // keep this TList for Delphi compatibility
    FFormBorderStyle: TFormBorderStyle;
    FFormState: TFormState;
    class procedure WSRegisterClass; override;
    procedure DoShowWindow; virtual;
    procedure Activate; virtual;
    procedure ActiveChanged; virtual;
    procedure AdjustClientRect(var Rect: TRect); override;
    procedure BeginFormUpdate;
    function ColorIsStored: boolean; override;
    procedure CreateParams(var Params: TCreateParams); override;
    procedure CreateWnd; override;
    procedure Deactivate; virtual;
    procedure DoClose(var CloseAction: TCloseAction); virtual;
    procedure DoCreate; virtual;
    procedure DoDestroy; virtual;
    procedure DoHide; virtual;
    procedure DoShow; virtual;
    procedure EndFormUpdate;
    function HandleCreateException: Boolean; virtual;
    function HandleDestroyException: Boolean; virtual;
    function HandleShowHideException: Boolean; virtual;
    procedure InitializeWnd; override;
    procedure Loaded; override;
    procedure ChildHandlesCreated; override;
    procedure Notification(AComponent: TComponent; Operation : TOperation);override;
    procedure PaintWindow(dc : Hdc); override;
    procedure RequestAlign; override;
    procedure Resizing(State: TWindowState); override;
    procedure CalculatePreferredSize(var PreferredWidth,
           PreferredHeight: integer; WithThemeSpace: Boolean); override;
    procedure DoOnResize; override;
    procedure DoOnChangeBounds; override;
    procedure SetZOrder(Topmost: Boolean); override;
    procedure SetParent(NewParent: TWinControl); override;
    procedure MoveToDefaultPosition; virtual;
    procedure UpdateShowing; override;
    procedure SetVisible(Value: boolean); override;
    procedure AllAutoSized; override;
    procedure DoFirstShow; virtual;
    procedure UpdateWindowState;
    procedure VisibleChanging; override;
    procedure VisibleChanged; override;
    procedure WndProc(var TheMessage : TLMessage); override;
    function VisibleIsStored: boolean;
    procedure DoAutoSize; override;
    procedure SetAutoSize(Value: Boolean); override;
    procedure SetAutoScroll(Value: Boolean); override;
    procedure SetScaled(const AScaled: Boolean); override;
    procedure DoAddActionList(List: TCustomActionList);
    procedure DoRemoveActionList(List: TCustomActionList);
    procedure ProcessResource;virtual;
  protected
    // drag and dock
    procedure BeginAutoDrag; override;
    procedure DoDock(NewDockSite: TWinControl; var ARect: TRect); override;
    function GetFloating: Boolean; override;
    function GetDefaultDockCaption: String; override;
  protected
    // actions
    procedure CMActionExecute(var Message: TLMessage); message CM_ACTIONEXECUTE;
    procedure CMActionUpdate(var Message: TLMessage); message CM_ACTIONUPDATE;
    function DoExecuteAction(ExeAction: TBasicAction): boolean;
    function DoUpdateAction(TheAction: TBasicAction): boolean;
    procedure UpdateActions; virtual;
  protected
    {MDI implementation}
    {returns handle of MDIForm client handle (container for mdi children this
    is not Handle of form itself !)}
    property ClientHandle: HWND read GetClientHandle;
  public
    constructor Create(AOwner: TComponent); override;
    constructor CreateNew(AOwner: TComponent; Num: Integer = 0); virtual;
    destructor Destroy; override;
    procedure AfterConstruction; override;
    procedure BeforeDestruction; override;

    class function GetControlClassDefaultSize: TSize; override;

    function BigIconHandle: HICON;
    procedure Close;
    function CloseQuery: boolean; virtual;
    procedure DefocusControl(Control: TWinControl; Removing: Boolean);
    procedure DestroyWnd; override;
    procedure EnsureVisible(AMoveToTop: Boolean = True);
    procedure FocusControl(WinControl: TWinControl);
    function FormIsUpdating: boolean; override;
    function GetFormImage: TBitmap;
    function GetRolesForControl(AControl: TControl): TControlRolesForForm;
    function GetRealPopupParent: TCustomForm;
    procedure Hide;
    procedure IntfDropFiles(const FileNames: array of String);
    procedure IntfHelp(AComponent: TComponent);
    function IsShortcut(var Message: TLMKey): boolean; virtual;
    procedure MakeFullyVisible(AMonitor: TMonitor = nil; UseWorkarea: Boolean = False);
    function AutoSizeDelayedHandle: Boolean; override;
    procedure GetPreferredSize(var PreferredWidth, PreferredHeight: integer;
                               Raw: boolean = false;
                               WithThemeSpace: boolean = true); override;
    procedure Release;
    function CanFocus: Boolean; override;
    procedure SetFocus; override;
    function SetFocusedControl(Control: TWinControl): Boolean ; virtual;
    procedure SetRestoredBounds(ALeft, ATop, AWidth, AHeight: integer; const
                                ADefaultPosition: Boolean = False);
    procedure Show;

    function ShowModal: Integer; virtual;
    procedure ShowOnTop;
    function SmallIconHandle: HICON;
    procedure GetChildren(Proc: TGetChildProc; Root: TComponent); override;
    function WantChildKey(Child : TControl;
                          var Message : TLMessage): Boolean; virtual;

    // handlers
    procedure RemoveAllHandlersOfObject(AnObject: TObject); override;
    procedure AddHandlerFirstShow(OnFirstShowHandler: TNotifyEvent;
                                  AsFirst: Boolean=false);
    procedure RemoveHandlerFirstShow(OnFirstShowHandler: TNotifyEvent);
    procedure AddHandlerClose(OnCloseHandler: TCloseEvent; AsFirst: Boolean=false);
    procedure RemoveHandlerClose(OnCloseHandler: TCloseEvent);
    procedure AddHandlerCreate(OnCreateHandler: TNotifyEvent; AsFirst: Boolean=false);
    procedure RemoveHandlerCreate(OnCreateHandler: TNotifyEvent);
  public
    {MDI implementation}
    function ActiveMDIChild: TCustomForm; virtual;
    function GetMDIChildren(AIndex: Integer): TCustomForm; virtual;
    function MDIChildCount: Integer; virtual;
  public
    procedure AutoScale; // set scaled to True and AutoAdjustLayout to current monitor PPI
  public
    // drag and dock
    procedure Dock(NewDockSite: TWinControl; ARect: TRect); override;
    procedure UpdateDockCaption(Exclude: TControl); override;
  public
    property Active: Boolean read FActive;
    property ActiveControl: TWinControl read FActiveControl write SetActiveControl;
    property ActiveDefaultControl: TControl read FActiveDefaultControl write SetActiveDefaultControl;
    property AllowDropFiles: Boolean read FAllowDropFiles write SetAllowDropFiles default False;
    property AlphaBlend: Boolean read FAlphaBlend write SetAlphaBlend;
    property AlphaBlendValue: Byte read FAlphaBlendValue write SetAlphaBlendValue;
    property AutoScroll stored IsAutoScrollStored;
    property BorderIcons: TBorderIcons read FBorderIcons write SetBorderIcons
      default [biSystemMenu, biMinimize, biMaximize];
    property BorderStyle: TFormBorderStyle
                      read FFormBorderStyle write SetFormBorderStyle default bsSizeable;
    property CancelControl: TControl read FCancelControl write SetCancelControl;
    property Caption stored IsForm;
    property Color default {$ifdef UseCLDefault}clDefault{$else}clBtnFace{$endif};
    property DefaultControl: TControl read FDefaultControl write SetDefaultControl;
    property DefaultMonitor: TDefaultMonitor read FDefaultMonitor
      write FDefaultMonitor default dmActiveForm;
    property Designer: TIDesigner read FDesigner write FDesigner;
    property EffectiveShowInTaskBar: TShowInTaskBar read GetEffectiveShowInTaskBar;
    property FormState: TFormState read FFormState;
    property FormStyle: TFormStyle read FFormStyle write SetFormStyle
                                   default fsNormal;
    property HelpFile: string read FHelpFile write FHelpFile;
    property Icon: TIcon read FIcon write SetIcon stored IsIconStored;
    property KeyPreview: Boolean read FKeyPreview write FKeyPreview default False;
    property MDIChildren[I: Integer]: TCustomForm read GetMDIChildren;
    property Menu : TMainMenu read FMenu write SetMenu;
    property ModalResult : TModalResult read FModalResult write SetModalResult;
    property Monitor: TMonitor read GetMonitor;
    property LastActiveControl: TWinControl read FLastActiveControl;
    property PopupMode: TPopupMode read FPopupMode write SetPopupMode default pmNone;
    property PopupParent: TCustomForm read FPopupParent write SetPopupParent;

    property OnActivate: TNotifyEvent read FOnActivate write FOnActivate;
    property OnClose: TCloseEvent read FOnClose write FOnClose stored IsForm;
    property OnCloseQuery : TCloseQueryEvent
                     read FOnCloseQuery write FOnCloseQuery stored IsForm;
    property OnCreate: TNotifyEvent read FOnCreate write FOnCreate;
    property OnDeactivate: TNotifyEvent read FOnDeactivate write FOnDeactivate;
    property OnDestroy: TNotifyEvent read FOnDestroy write FOnDestroy;
    property OnDropFiles: TDropFilesEvent read FOnDropFiles write FOnDropFiles;
    property OnHelp: THelpEvent read FOnHelp write FOnHelp;
    property OnHide: TNotifyEvent read FOnHide write FOnHide;
    property OnResize stored IsForm;
    property OnShortcut: TShortcutEvent read FOnShortcut write FOnShortcut;
    property OnShow: TNotifyEvent read FOnShow write FOnShow;
    property OnShowModalFinished: TModalDialogFinished read FOnShowModalFinished write FOnShowModalFinished;
    property OnWindowStateChange: TNotifyEvent
                         read FOnWindowStateChange write FOnWindowStateChange;
    property ParentFont default False;
    property Position: TPosition read FPosition write SetPosition default poDesigned;
    property RestoredLeft: integer read FRestoredLeft;
    property RestoredTop: integer read FRestoredTop;
    property RestoredWidth: integer read FRestoredWidth;
    property RestoredHeight: integer read FRestoredHeight;
    property ShowInTaskBar: TShowInTaskbar read FShowInTaskbar write SetShowInTaskBar
                                    default stDefault;
    property Visible stored VisibleIsStored default false;
    property WindowState: TWindowState read FWindowState write SetWindowState
                                       default wsNormal;
  end;

  TCustomFormClass = class of TCustomForm;


  { TForm }

  TForm = class(TCustomForm)
  private
    FLCLVersion: string;
    function LCLVersionIsStored: boolean;
  protected
    class procedure WSRegisterClass; override;
    procedure CreateWnd; override;
    procedure Loaded; override;
  public
    constructor Create(TheOwner: TComponent); override;

    { mdi related routine}
    procedure Cascade;
    { mdi related routine}
    procedure Next;
    { mdi related routine}
    procedure Previous;
    { mdi related routine}
    procedure Tile;
    { mdi related routine}
    procedure ArrangeIcons;
    { mdi related property}
    property ClientHandle;

    property DockManager;
  published
    property Action;
    property ActiveControl;
    property Align;
    property AllowDropFiles;
    property AlphaBlend default False;
    property AlphaBlendValue default 255;
    property Anchors;
    property AutoScroll;
    property AutoSize;
    property BiDiMode;
    property BorderIcons;
    property BorderStyle;
    property BorderWidth;
    property Caption;
    property ChildSizing;
    property ClientHeight;
    property ClientWidth;
    property Color;
    property Constraints;
    property DefaultMonitor;
    property DesignTimePPI;
    property DockSite;
    property DoubleBuffered;
    property DragKind;
    property DragMode;
    property Enabled;
    property Font;
    property FormStyle;
    property HelpFile;
    property Icon;
    property KeyPreview;
    property Menu;
    property OnActivate;
    property OnChangeBounds;
    property OnClick;
    property OnClose;
    property OnCloseQuery;
    property OnConstrainedResize;
    property OnContextPopup;
    property OnCreate;
    property OnDblClick;
    property OnDeactivate;
    property OnDestroy;
    property OnDockDrop;
    property OnDockOver;
    property OnDragDrop;
    property OnDragOver;
    property OnDropFiles;
    property OnEndDock;
    property OnGetSiteInfo;
    property OnHelp;
    property OnHide;
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
    property OnPaint;
    property OnResize;
    property OnShortCut;
    property OnShow;
    property OnShowHint;
    property OnStartDock;
    property OnUnDock;
    property OnUTF8KeyPress;
    property OnWindowStateChange;
    property ParentBiDiMode;
    property ParentDoubleBuffered;
    property ParentFont;
    property PixelsPerInch;
    property PopupMenu;
    property PopupMode;
    property PopupParent;
    property Position;
    property SessionProperties;
    property ShowHint;
    property ShowInTaskBar;
    property UseDockManager;
    property LCLVersion: string read FLCLVersion write FLCLVersion stored LCLVersionIsStored;
    property Scaled;
    property Visible;
    property WindowState;
  end;

  TFormClass = class of TForm;


  { TCustomDockForm }

  TCustomDockForm = class(TCustomForm)
  protected
    procedure DoAddDockClient(Client: TControl; const ARect: TRect); override;
    procedure DoRemoveDockClient(Client: TControl); override;
    procedure GetSiteInfo(Client: TControl; var InfluenceRect: TRect;
                          MousePos: TPoint; var CanDock: Boolean); override;
    procedure Loaded; override;
  public
    constructor Create(TheOwner: TComponent); override;
    property AutoScroll default False;
    property BorderStyle default bsSizeToolWin;
    property FormStyle default fsStayOnTop;
  published
    property PixelsPerInch;
  end;


  { THintWindow }

  THintWindow = class(TCustomForm)
  // For simple text hint without child controls.
  private
    FActivating: Boolean;
    FAlignment: TAlignment;
    FHintRect: TRect;
    FHintData: Pointer;
    FAutoHide: Boolean;
    FAutoHideTimer: TCustomTimer;
    FHideInterval: Integer;
    procedure AdjustBoundsForMonitor(KeepWidth: Boolean = True;
      KeepHeight: Boolean = True);
    function GetDrawTextFlags: Cardinal;
    procedure SetAutoHide(Value : Boolean);
    procedure AutoHideHint(Sender : TObject);
    procedure SetHideInterval(Value : Integer);
    procedure SetHintRectAdjust(AValue: TRect);
  protected
    class procedure WSRegisterClass; override;
    procedure WMNCHitTest(var Message: TLMessage); message LM_NCHITTEST;
    procedure ActivateSub;
    procedure DoShowWindow; override;
    procedure UpdateRegion;
    procedure SetColor(Value: TColor); override;
    function UseBGThemes: Boolean;
    function UseFGThemes: Boolean;
    procedure Paint; override;
  private class var
    FSysHintFont: TFont;
  protected
    class function SysHintFont: TFont;
  public
    class destructor Destroy;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure ActivateHint(const AHint: String);
    procedure ActivateHint(ARect: TRect; const AHint: String); virtual;
    procedure ActivateWithBounds(ARect: TRect; const AHint: String);
    procedure ActivateHintData(ARect: TRect; const AHint: String;
                               AData: pointer); virtual;
    function CalcHintRect(MaxWidth: Integer; const AHint: String;
                          AData: pointer): TRect; virtual;
    function OffsetHintRect(AOffset: TPoint; dy: Integer = 15;
      KeepWidth: Boolean = True; KeepHeight: Boolean = True): Boolean;
    procedure InitializeWnd; override;
    function IsHintMsg(Msg: TMsg): Boolean; virtual;
    procedure ReleaseHandle;
    procedure SetBounds(ALeft, ATop, AWidth, AHeight: integer); override;
    class function GetControlClassDefaultSize: TSize; override;
  public
    property OnMouseDown;  // Public access may be needed.
    property OnMouseUp;
    property OnMouseMove;
    property OnMouseLeave;
    property Alignment: TAlignment read FAlignment write FAlignment;
    property HintRect: TRect read FHintRect write FHintRect;
    property HintRectAdjust: TRect read FHintRect write SetHintRectAdjust;
    property HintData: Pointer read FHintData write FHintData;
    property AutoHide: Boolean read FAutoHide write SetAutoHide;
    property BiDiMode;
    property HideInterval: Integer read FHideInterval write SetHideInterval;
  end;

  THintWindowClass = class of THintWindow;

  { THintWindowRendered }

  THintWindowRendered = class(THintWindow)
  // For rendered hint with a child control added by an external provider.
  private
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure ActivateRendered;
  end;

  { TMonitor }

  TMonitor = class(TObject)
  private
    FHandle: HMONITOR;
    FMonitorNum: Integer;
    function GetInfo(out Info: TMonitorInfo): Boolean; {inline; fpc bug - compilation error with inline}
    function GetLeft: Integer;
    function GetHeight: Integer;
    function GetPixelsPerInch: Integer;
    function GetTop: Integer;
    function GetWidth: Integer;
    function GetBoundsRect: TRect;
    function GetWorkareaRect: TRect;
    function GetPrimary: Boolean;
  public
    property Handle: HMONITOR read FHandle;
    property MonitorNum: Integer read FMonitorNum;
    property Left: Integer read GetLeft;
    property Height: Integer read GetHeight;
    property Top: Integer read GetTop;
    property Width: Integer read GetWidth;
    property BoundsRect: TRect read GetBoundsRect;
    property WorkareaRect: TRect read GetWorkareaRect;
    property Primary: Boolean read GetPrimary;
    property PixelsPerInch: Integer read GetPixelsPerInch;
  end;

  { TMonitorList }

  TMonitorList = class(TList)
  private
    function GetItem(AIndex: Integer): TMonitor;
    procedure SetItem(AIndex: Integer; const AValue: TMonitor);
  protected
    procedure Notify(Ptr: Pointer; Action: TListNotification); override;
  public
    property Items[AIndex: Integer]: TMonitor read GetItem write SetItem; default;
  end;

  { TScreen }

  PCursorRec = ^TCursorRec;
  TCursorRec = record
    Next: PCursorRec;
    Index: Integer;
    Handle: HCURSOR;
  end;

  TScreenFormEvent = procedure(Sender: TObject; Form: TCustomForm) of object;
  TScreenControlEvent = procedure(Sender: TObject;
                                  LastControl: TControl) of object;

  TScreenNotification = (
    snFormAdded,
    snRemoveForm,
    snActiveControlChanged,
    snActiveFormChanged,
    snFormVisibleChanged
    );

  TMonitorDefaultTo = (mdNearest, mdNull, mdPrimary);

  { TScreen }

  TScreen = class(TLCLComponent)
  private
    FActiveControl: TWinControl;
    FActiveCustomForm: TCustomForm;
    FActiveForm: TForm;
    FCursor: TCursor;
    FTempCursors: array of TCursor;
    FCursorMap: TMap;
    FCustomForms: TFPList;
    FCustomFormsZOrdered: TFPList;
    FDefaultCursor: HCURSOR;
    FHintFont: TFont;
    FFocusedForm: TCustomForm;
    FFonts : TStrings;
    FFormList: TFPList;
    FDataModuleList: TFPList;
    FIconFont: TFont;
    FMenuFont: TFont;
    FScreenHandlers: array[TScreenNotification] of TMethodList;
    FLastActiveControl: TWinControl;
    FLastActiveCustomForm: TCustomForm;
    FMonitors: TMonitorList;
    FOnActiveControlChange: TNotifyEvent;
    FOnActiveFormChange: TNotifyEvent;
    FPixelsPerInch : integer;
    FSaveFocusedList: TFPList;
    FSystemFont: TFont;
    procedure DeleteCursor(AIndex: Integer);
    procedure DestroyCursors;
    procedure DestroyMonitors;
    function GetCursors(AIndex: Integer): HCURSOR;
    function GetCustomFormCount: Integer;
    function GetCustomFormZOrderCount: Integer;
    function GetCustomForms(Index: Integer): TCustomForm;
    function GetCustomFormsZOrdered(Index: Integer): TCustomForm;
    function GetDataModuleCount: Integer;
    function GetDataModules(AIndex: Integer): TDataModule;
    function GetDesktopLeft: Integer;
    function GetDesktopTop: Integer;
    function GetDesktopHeight: Integer;
    function GetDesktopWidth: Integer;
    function GetDesktopRect: TRect;
    function GetFonts : TStrings;
    function GetFormCount: Integer;
    function GetForms(IIndex: Integer): TForm;
    function GetHeight : Integer;
    function GetMonitor(Index: Integer): TMonitor;
    function GetMonitorCount: Integer;
    function GetPrimaryMonitor: TMonitor;
    function GetRealCursor: TCursor;
    function GetWidth : Integer;
    procedure AddForm(AForm: TCustomForm);
    procedure RemoveForm(AForm: TCustomForm);
    function SetFocusedForm(AForm: TCustomForm): Boolean;
    procedure SetCursor(const AValue: TCursor);
    procedure SetCursors(AIndex: Integer; const AValue: HCURSOR);
    procedure SetHintFont(const AValue: TFont);
    procedure SetIconFont(const AValue: TFont);
    procedure SetMenuFont(const AValue: TFont);
    procedure SetSystemFont(const AValue: TFont);
    function UpdatedMonitor(AHandle: HMONITOR; ADefault: TMonitorDefaultTo;
      AErrorMsg: string): TMonitor;
    procedure UpdateLastActive;
    procedure RestoreLastActive;
    procedure AddHandler(HandlerType: TScreenNotification;
                         const Handler: TMethod; AsFirst: Boolean);
    procedure RemoveHandler(HandlerType: TScreenNotification;
                            const Handler: TMethod);
    procedure DoAddDataModule(DataModule: TDataModule);
    procedure DoRemoveDataModule(DataModule: TDataModule);
    procedure NotifyScreenFormHandler(HandlerType: TScreenNotification;
                                      Form: TCustomForm);
    function GetWorkAreaHeight: Integer;
    function GetWorkAreaLeft: Integer;
    function GetWorkAreaRect: TRect;
    function GetWorkAreaTop: Integer;
    function GetWorkAreaWidth: Integer;
  protected
    function GetHintFont: TFont; virtual;
    function GetIconFont: TFont; virtual;
    function GetMenuFont: TFont; virtual;
    function GetSystemFont: TFont; virtual;
  public
    constructor Create(AOwner : TComponent); override;
    destructor Destroy; override;
    function CustomFormIndex(AForm: TCustomForm): integer;
    function FormIndex(AForm: TForm): integer;
    function CustomFormZIndex(AForm: TCustomForm): integer;
    procedure MoveFormToFocusFront(ACustomForm: TCustomForm);
    procedure MoveFormToZFront(ACustomForm: TCustomForm);
    function GetCurrentModalForm: TCustomForm;
    function GetCurrentModalFormZIndex: Integer;
    function CustomFormBelongsToActiveGroup(AForm: TCustomForm): Boolean;
    function FindNonDesignerForm(const FormName: string): TCustomForm;
    function FindForm(const FormName: string): TCustomForm;
    function FindNonDesignerDataModule(const DataModuleName: string): TDataModule;
    function FindDataModule(const DataModuleName: string): TDataModule;
    procedure UpdateMonitors;
    procedure UpdateScreen;
    // handler
    procedure RemoveAllHandlersOfObject(AnObject: TObject); override;
    procedure AddHandlerFormAdded(OnFormAdded: TScreenFormEvent;
                                  AsFirst: Boolean=false);
    procedure RemoveHandlerFormAdded(OnFormAdded: TScreenFormEvent);
    procedure AddHandlerRemoveForm(OnRemoveForm: TScreenFormEvent;
                                   AsFirst: Boolean=false);
    procedure RemoveHandlerRemoveForm(OnRemoveForm: TScreenFormEvent);
    procedure AddHandlerActiveControlChanged(
                                    OnActiveControlChanged: TScreenControlEvent;
                                    AsFirst: Boolean=false);
    procedure RemoveHandlerActiveControlChanged(
                                   OnActiveControlChanged: TScreenControlEvent);
    procedure AddHandlerActiveFormChanged(OnActiveFormChanged: TScreenFormEvent;
                                          AsFirst: Boolean=false);
    procedure RemoveHandlerActiveFormChanged(OnActiveFormChanged: TScreenFormEvent);
    procedure AddHandlerFormVisibleChanged(OnFormVisibleChanged: TScreenFormEvent;
                                           AsFirst: Boolean=false);
    procedure RemoveHandlerFormVisibleChanged(OnFormVisibleChanged: TScreenFormEvent);

    function DisableForms(SkipForm: TCustomForm; DisabledList: TList = nil): TList;
    procedure EnableForms(var AFormList: TList);
    function MonitorFromPoint(const Point: TPoint;
      MonitorDefault: TMonitorDefaultTo = mdNearest): TMonitor;
    function MonitorFromRect(const Rect: TRect;
      MonitorDefault: TMonitorDefaultTo = mdNearest): TMonitor;
    function MonitorFromWindow(const Handle: THandle;
      MonitorDefault: TMonitorDefaultTo = mdNearest): TMonitor;

    procedure BeginTempCursor(const aCursor: TCursor);
    procedure EndTempCursor(const aCursor: TCursor);
    procedure BeginWaitCursor;
    procedure EndWaitCursor;
  public
    property ActiveControl: TWinControl read FActiveControl;
    property ActiveCustomForm: TCustomForm read FActiveCustomForm;
    property ActiveForm: TForm read FActiveForm;
    property Cursor: TCursor read FCursor write SetCursor;
    property RealCursor: TCursor read GetRealCursor;
    property Cursors[Index: Integer]: HCURSOR read GetCursors write SetCursors;
    property CustomFormCount: Integer read GetCustomFormCount;
    property CustomForms[Index: Integer]: TCustomForm read GetCustomForms;
    property CustomFormZOrderCount: Integer read GetCustomFormZOrderCount;
    property CustomFormsZOrdered[Index: Integer]: TCustomForm
                               read GetCustomFormsZOrdered; // lower index means on top

    property DesktopLeft: Integer read GetDesktopLeft;
    property DesktopTop: Integer read GetDesktopTop;
    property DesktopHeight: Integer read GetDesktopHeight;
    property DesktopWidth: Integer read GetDesktopWidth;
    property DesktopRect: TRect read GetDesktopRect;

    property FocusedForm: TCustomForm read FFocusedForm;
    property FormCount: Integer read GetFormCount;
    property Forms[Index: Integer]: TForm read GetForms;
    property DataModuleCount: Integer read GetDataModuleCount;
    property DataModules[Index: Integer]: TDataModule read GetDataModules;
    
    property HintFont: TFont read GetHintFont write SetHintFont;
    property IconFont: TFont read GetIconFont write SetIconFont;
    property MenuFont: TFont read GetMenuFont write SetMenuFont;
    property SystemFont: TFont read GetSystemFont write SetSystemFont;
    property Fonts: TStrings read GetFonts;

    property Height: Integer read Getheight;
    property MonitorCount: Integer read GetMonitorCount;
    property Monitors[Index: Integer]: TMonitor read GetMonitor;
    property PixelsPerInch: integer read FPixelsPerInch;
    property PrimaryMonitor: TMonitor read GetPrimaryMonitor;
    property Width: Integer read GetWidth;
    property WorkAreaRect: TRect read GetWorkAreaRect;
    property WorkAreaHeight: Integer read GetWorkAreaHeight;
    property WorkAreaLeft: Integer read GetWorkAreaLeft;
    property WorkAreaTop: Integer read GetWorkAreaTop;
    property WorkAreaWidth: Integer read GetWorkAreaWidth;
    property OnActiveControlChange: TNotifyEvent read FOnActiveControlChange
                                                 write FOnActiveControlChange;
    property OnActiveFormChange: TNotifyEvent read FOnActiveFormChange
                                              write FOnActiveFormChange;
  end;


  { TApplication }

  TQueryEndSessionEvent = procedure (var Cancel: Boolean) of object;
  TExceptionEvent = procedure (Sender: TObject; E: Exception) of object;
  TGetHandleEvent = procedure(var Handle: HWND) of object;
  TIdleEvent = procedure (Sender: TObject; var Done: Boolean) of object;
  TOnUserInputEvent = procedure(Sender: TObject; Msg: Cardinal) of object;
  TDataEvent = procedure (Data: PtrInt) of object;

  // application hint stuff
  TCMHintShow = record
    Msg: Cardinal;
    Reserved: WPARAM;
    HintInfo: PHintInfo;
    Result: LRESULT;
  end;

  TCMHintShowPause = record
    Msg: Cardinal;
    WasActive: Integer;
    Pause: PInteger;
    Result: LRESULT;
  end;

  TAppHintTimerType = (ahttNone, ahttShowHint, ahttHideHint, ahttReshowHint);

  TShowHintEvent = procedure (var HintStr: string; var CanShow: Boolean;
    var HintInfo: THintInfo) of object;

  THintInfoAtMouse = record
    MousePos: TPoint;
    Control: TControl;
    ControlHasHint: boolean;
  end;

  TApplicationFlag = (
    AppWaiting,
    AppIdleEndSent,
    AppNoExceptionMessages,
    AppActive, // application has focus
    AppDestroying,
    AppDoNotCallAsyncQueue,
    AppInitialized // initialization of application was done
    );
  TApplicationFlags = set of TApplicationFlag;

  TApplicationNavigationOption = (
    anoTabToSelectNext,
    anoReturnForDefaultControl,
    anoEscapeForCancelControl,
    anoF1ForHelp,
    anoArrowToSelectNextInParent
    );
  TApplicationNavigationOptions = set of TApplicationNavigationOption;

  TApplicationHandlerType = (
    ahtIdle,
    ahtIdleEnd,
    ahtKeyDownBefore, // before interface and LCL
    ahtKeyDownAfter,  // after interface and LCL
    ahtActivate,
    ahtDeactivate,
    ahtUserInput,
    ahtException,
    ahtEndSession,
    ahtQueryEndSession,
    ahtMinimize,
    ahtModalBegin,
    ahtModalEnd,
    ahtRestore,
    ahtDropFiles,
    ahtHelp,
    ahtHint,
    ahtShowHint,
    ahtGetMainFormHandle
    );

  PAsyncCallQueueItem = ^TAsyncCallQueueItem;
  TAsyncCallQueueItem = record
    Method: TDataEvent;
    Data: PtrInt;
    NextItem, PrevItem: PAsyncCallQueueItem;
  end;
  TAsyncCallQueue = record
    Top, Last: PAsyncCallQueueItem;
  end;
  TAsyncCallQueues = record
    CritSec: TRTLCriticalSection;
    Cur: TAsyncCallQueue; // currently processing
    Next: TAsyncCallQueue; // new calls added to this queue
  end;

  // This identifies the kind of device where the application currently runs on
  // Note that the same application can run in all kinds of devices if it has a
  // user interface flexible enough
  TApplicationType = (
    atDefault,     // The widgetset will attempt to auto-detect the device type
    atDesktop,     // For common desktops and notebooks
    atPDA,         // For smartphones and other devices with touch screen and a small screen
    atKeyPadDevice,// Devices without any pointing device, such as keypad feature phones or kiosk machines
    atTablet,      // Similar to a PDA/Smartphone, but with a large screen
    atTV,          // The device is a television
    atMobileEmulator// For desktop platforms. It will create a main windows of 240x320
                   // and place all forms there to immitate a mobile platform
  );

  TApplicationExceptionDlg = (
    aedOkCancelDialog,  // Exception handler window will be a dialog with Ok/Cancel buttons
    aedOkMessageBox     // Exception handler window will be a simple message box
  );

  TApplicationShowGlyphs = (
    sbgAlways,  // show them always (default)
    sbgNever,   // show them never
    sbgSystem   // show them depending on OS
  );

  TTaskBarBehavior = (
    tbDefault,      // widgetset dependent
    tbMultiButton,  // show buttons for Forms with ShowTaskBar = stDefault
    tbSingleButton  // hide buttons for Forms with ShowTaskBar = stDefault.
                    // Some Linux window managers do not support it. For example Cinnamon.
  );

  TApplicationDoubleBuffered = ( // what Forms.DoubleBuffered with ParentDoubleBuffered=True will gain when created
    adbDefault, // widgetset dependent (LCLWin32: True unless in remote desktop connection; other WSs: False)
    adbFalse,   // False
    adbTrue);   // True

  { TApplication }

  TApplication = class(TCustomApplication)
  private
    FApplicationHandlers: array[TApplicationHandlerType] of TMethodList;
    FApplicationType: TApplicationType;
    FCaptureExceptions: boolean;
    FComponentsToRelease: TFPList;
    FComponentsReleasing: TFPList;
    FComponentsToReleaseSavedByModal: TFPList;
    FComponentsReleasingSavedByModal: TFPList;
    FCreatingForm: TForm;// currently created form (CreateForm), candidate for MainForm
    FDoubleBuffered: TApplicationDoubleBuffered;
    FExceptionDialog: TApplicationExceptionDlg;
    FExtendedKeysSupport: Boolean;
    FFindGlobalComponentEnabled: boolean;
    FFlags: TApplicationFlags;
    FHint: string;
    FHintColor: TColor;
    FHintControl: TControl;
    FHintHidePause: Integer;
    FHintHidePausePerChar: Integer;
    FHintPause: Integer;
    FHintRect: TRect;
    FHintShortCuts: Boolean;
    FHintShortPause: Integer;
    FHintTimer: TCustomTimer;
    FHintTimerType: TAppHintTimerType;
    FHintWindow: THintWindow;
    FIcon: TIcon;
    FBigIconHandle: HICON;
    FLayoutAdjustmentPolicy: TLayoutAdjustmentPolicy;
    FMainFormOnTaskBar: Boolean;
    FModalLevel: Integer;
    FMoveFormFocusToChildren: Boolean;
    FOnCircularException: TExceptionEvent;
    FOnGetMainFormHandle: TGetHandleEvent;
    FOnMessageDialogFinished: TModalDialogFinished;
    FOnModalBegin: TNotifyEvent;
    FOnModalEnd: TNotifyEvent;
    FScaled: Boolean;
    FShowButtonGlyphs: TApplicationShowGlyphs;
    FShowMenuGlyphs: TApplicationShowGlyphs;
    FSmallIconHandle: HICON;
    FIdleLockCount: Integer;
    FLastKeyDownSender: TWinControl;
    FLastKeyDownKeys: TWordList;
    FLastKeyDownShift: TShiftState;
    FMainForm : TForm;
    FMouseControl: TControl;
    FNavigation: TApplicationNavigationOptions;
    FOldExceptProc: TExceptProc;
    FOnActionExecute: TActionEvent;
    FOnActionUpdate: TActionEvent;
    FOnActivate: TNotifyEvent;
    FOnDeactivate: TNotifyEvent;
    FOnDestroy: TNotifyEvent;
    FOnDropFiles: TDropFilesEvent;
    FOnHelp: THelpEvent;
    FOnHint: TNotifyEvent;
    FOnIdle: TIdleEvent;
    FOnIdleEnd: TNotifyEvent;
    FOnEndSession: TNotifyEvent;
    FOnQueryEndSession: TQueryEndSessionEvent;
    FOnMinimize: TNotifyEvent;
    FOnRestore: TNotifyEvent;
    FOnShortcut: TShortcutEvent;
    FOnShowHint: TShowHintEvent;
    FOnUserInput: TOnUserInputEvent;
    FAsyncCall: TAsyncCallQueues;
    FShowHint: Boolean;
    FShowMainForm: Boolean;
    FLastMousePos: TPoint;
    FLastMouseControl: TControl;
    FLastMouseControlValid: Boolean;
    FBidiMode: TBiDiMode;
    FRestoreStayOnTop: TList;
    FTaskBarBehavior: TTaskBarBehavior;
    FUpdateFormatSettings: Boolean;
    FRemoveStayOnTopCounter: Integer;
    FExceptionCounter: Byte;
    procedure DoOnIdleEnd;
    function GetActive: boolean;
    function GetCurrentHelpFile: string;
    function GetExename: String;
    function GetHandle: THandle;
    function GetMainFormHandle: HWND;
    function GetTitle: string;
    procedure FreeIconHandles;
    procedure IconChanged(Sender: TObject);
    procedure SetBidiMode(const AValue: TBiDiMode);
    procedure SetFlags(const AValue: TApplicationFlags);
    procedure SetMainFormOnTaskBar(const AValue: Boolean);
    procedure SetNavigation(const AValue: TApplicationNavigationOptions);
    procedure SetShowButtonGlyphs(const AValue: TApplicationShowGlyphs);
    procedure SetShowMenuGlyphs(const AValue: TApplicationShowGlyphs);
    procedure SetTaskBarBehavior(const AValue: TTaskBarBehavior);
    procedure UpdateMouseControl(NewMouseControl: TControl);
    procedure UpdateMouseHint(CurrentControl: TControl);
    procedure SetCaptureExceptions(const AValue: boolean);
    procedure SetHandle(const AHandle: THandle);
    procedure SetHint(const AValue: string);
    procedure SetHintColor(const AValue: TColor);
    procedure SetIcon(AValue: TIcon);
    procedure SetShowHint(const AValue: Boolean);
    procedure StopHintTimer;
    function  ValidateHelpSystem: Boolean;
    procedure WndProc(var AMessage : TLMessage);
    function DispatchAction(Msg: Longint; Action: TBasicAction): Boolean;
    procedure AddHandler(HandlerType: TApplicationHandlerType;
                         const Handler: TMethod; AsFirst: Boolean);
    procedure RemoveHandler(HandlerType: TApplicationHandlerType;
                            const Handler: TMethod);
    procedure RunLoop;
    procedure Activate(Data: PtrInt);
    procedure Deactivate(Data: PtrInt);
  protected
    function GetConsoleApplication: boolean; override;
    procedure NotifyIdleHandler(var Done: Boolean);
    procedure NotifyIdleEndHandler;
    procedure NotifyActivateHandler;
    procedure NotifyDeactivateHandler;
    procedure NotifyCustomForms(Msg: Word);
    function IsHintMsg(var Msg: TMsg): Boolean;
    function DoOnHelp(Command: Word; Data: PtrInt; var CallHelp: Boolean): Boolean; virtual;
    procedure DoOnMouseMove; virtual;
    procedure ShowHintWindow(const Info: THintInfoAtMouse);
    procedure OnHintTimer(Sender: TObject);
    procedure SetTitle(const AValue: String); override;
    procedure StartHintTimer(Interval: integer; TimerType: TAppHintTimerType);
    procedure UpdateVisible;
    procedure DoIdleActions;
    procedure MenuPopupHandler(Sender: TObject);
    procedure ProcessAsyncCallQueue;
    procedure FreeComponent(Data: PtrInt);
    procedure ReleaseComponents;
    procedure DoBeforeFinalization;
    function GetParams(Index: Integer): string; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure ActivateHint(CursorPos: TPoint; CheckHintControlChange: Boolean = False);
    function GetControlAtMouse: TControl;
    procedure ControlDestroyed(AControl: TControl);
    function BigIconHandle: HIcon;
    function SmallIconHandle: HIcon;
    procedure BringToFront;
    procedure CreateForm(InstanceClass: TComponentClass; out Reference);
    procedure UpdateMainForm(AForm: TForm);
    procedure QueueAsyncCall(const AMethod: TDataEvent; Data: PtrInt);
    procedure RemoveAsyncCalls(const AnObject: TObject);
    procedure ReleaseComponent(AComponent: TComponent);
    function ExecuteAction(ExeAction: TBasicAction): Boolean; override;
    function UpdateAction(TheAction: TBasicAction): Boolean; override;
    procedure HandleException(Sender: TObject); override;
    procedure HandleMessage;
    function HelpCommand(Command: Word; Data: PtrInt): Boolean;
    function HelpContext(Context: THelpContext): Boolean;
    function HelpKeyword(const Keyword: String): Boolean;
    procedure ShowHelpForObject(Sender: TObject);
    procedure RemoveStayOnTop(const ASystemTopAlso: Boolean = False);
    procedure RestoreStayOnTop(const ASystemTopAlso: Boolean = False);
    function IsWaiting: boolean;
    procedure CancelHint;
    procedure HideHint;
    procedure HintMouseMessage(Control : TControl; var AMessage: TLMessage);
    procedure Initialize; override;
    function MessageBox(Text, Caption: PChar; Flags: Longint = MB_OK): Integer;
    procedure Minimize;
    procedure ModalStarted;
    procedure ModalFinished;
    procedure Restore;
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
    procedure ProcessMessages;
    procedure Idle(Wait: Boolean);
    procedure Run;
    procedure ShowException(E: Exception); override;
    procedure Terminate; override;
    procedure DisableIdleHandler;
    procedure EnableIdleHandler;
    procedure NotifyUserInputHandler(Sender: TObject; Msg: Cardinal);
    procedure NotifyKeyDownBeforeHandler(Sender: TObject;
                                         var Key: Word; Shift: TShiftState);
    procedure NotifyKeyDownHandler(Sender: TObject;
                                   var Key: Word; Shift: TShiftState);
    procedure ControlKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure ControlKeyUp(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure AddOnIdleHandler(Handler: TIdleEvent; AsFirst: Boolean=true);
    procedure RemoveOnIdleHandler(Handler: TIdleEvent);
    procedure AddOnIdleEndHandler(Handler: TNotifyEvent; AsFirst: Boolean=true);
    procedure RemoveOnIdleEndHandler(Handler: TNotifyEvent);
    procedure AddOnUserInputHandler(Handler: TOnUserInputEvent;
                                    AsFirst: Boolean=true);
    procedure RemoveOnUserInputHandler(Handler: TOnUserInputEvent);
    procedure AddOnKeyDownBeforeHandler(Handler: TKeyEvent;
                                        AsFirst: Boolean=true);
    procedure RemoveOnKeyDownBeforeHandler(Handler: TKeyEvent);
    procedure AddOnKeyDownHandler(Handler: TKeyEvent; AsFirst: Boolean=true);
    procedure RemoveOnKeyDownHandler(Handler: TKeyEvent);
    procedure AddOnActivateHandler(Handler: TNotifyEvent; AsFirst: Boolean=true);
    procedure RemoveOnActivateHandler(Handler: TNotifyEvent);
    procedure AddOnDeactivateHandler(Handler: TNotifyEvent; AsFirst: Boolean=true);
    procedure RemoveOnDeactivateHandler(Handler: TNotifyEvent);
    procedure AddOnExceptionHandler(Handler: TExceptionEvent; AsFirst: Boolean=true);
    procedure RemoveOnExceptionHandler(Handler: TExceptionEvent);
    procedure AddOnEndSessionHandler(Handler: TNotifyEvent; AsFirst: Boolean=true);
    procedure RemoveOnEndSessionHandler(Handler: TNotifyEvent);
    procedure AddOnQueryEndSessionHandler(Handler: TQueryEndSessionEvent; AsFirst: Boolean=true);
    procedure RemoveOnQueryEndSessionHandler(Handler: TQueryEndSessionEvent);
    procedure AddOnMinimizeHandler(Handler: TNotifyEvent; AsFirst: Boolean=true);
    procedure RemoveOnMinimizeHandler(Handler: TNotifyEvent);
    procedure AddOnModalBeginHandler(Handler: TNotifyEvent; AsFirst: Boolean=true);
    procedure RemoveOnModalBeginHandler(Handler: TNotifyEvent);
    procedure AddOnModalEndHandler(Handler: TNotifyEvent; AsFirst: Boolean=true);
    procedure RemoveOnModalEndHandler(Handler: TNotifyEvent);
    procedure AddOnRestoreHandler(Handler: TNotifyEvent; AsFirst: Boolean=true);
    procedure RemoveOnRestoreHandler(Handler: TNotifyEvent);
    procedure AddOnDropFilesHandler(Handler: TDropFilesEvent; AsFirst: Boolean=true);
    procedure RemoveOnDropFilesHandler(Handler: TDropFilesEvent);
    procedure AddOnHelpHandler(Handler: THelpEvent; AsFirst: Boolean=true);
    procedure RemoveOnHelpHandler(Handler: THelpEvent);
    procedure AddOnHintHandler(Handler: TNotifyEvent; AsFirst: Boolean=true);
    procedure RemoveOnHintHandler(Handler: TNotifyEvent);
    procedure AddOnShowHintHandler(Handler: TShowHintEvent; AsFirst: Boolean=true);
    procedure RemoveOnShowHintHandler(Handler: TShowHintEvent);
    procedure AddOnGetMainFormHandleHandler(Handler: TGetHandleEvent; AsFirst: Boolean = True);
    procedure RemoveOnGetMainFormHandleHandler(Handler: TGetHandleEvent);
    procedure RemoveAllHandlersOfObject(AnObject: TObject); virtual;
    procedure DoBeforeMouseMessage(CurMouseControl: TControl);
    function  IsShortcut(var Message: TLMKey): boolean;
    procedure IntfQueryEndSession(var Cancel: Boolean);
    procedure IntfEndSession;
    procedure IntfAppActivate(const Async: Boolean = False);
    procedure IntfAppDeactivate(const Async: Boolean = False);
    procedure IntfAppMinimize;
    procedure IntfAppRestore;
    procedure IntfDropFiles(const FileNames: Array of String);
    procedure IntfSettingsChange;
    procedure IntfThemeOptionChange(AThemeServices: TThemeServices; AOption: TThemeOption);

    function IsRightToLeft: Boolean;
    function IsRTLLang(ALang: String): Boolean;
    function Direction(ALang: String): TBiDiMode;
  public
    // on key down
    procedure DoArrowKey(AControl: TWinControl; var Key: Word; Shift: TShiftState);
    procedure DoTabKey(AControl: TWinControl; var Key: Word; Shift: TShiftState);
    // on key up
    procedure DoEscapeKey(AControl: TWinControl; var Key: Word; Shift: TShiftState);
    procedure DoReturnKey(AControl: TWinControl; var Key: Word; Shift: TShiftState);

    property Active: boolean read GetActive;
    property ApplicationType : TApplicationType read FApplicationType write FApplicationType;
    property BidiMode: TBiDiMode read FBidiMode write SetBidiMode;
    property CaptureExceptions: boolean read FCaptureExceptions
                                        write SetCaptureExceptions;
    property DoubleBuffered: TApplicationDoubleBuffered read FDoubleBuffered write FDoubleBuffered default adbDefault; platform;
    property ExtendedKeysSupport: Boolean read FExtendedKeysSupport write FExtendedKeysSupport; // See VK_LSHIFT in LCLType for more details
    property ExceptionDialog: TApplicationExceptionDlg read FExceptionDialog write FExceptionDialog;
    property FindGlobalComponentEnabled: boolean read FFindGlobalComponentEnabled
                                               write FFindGlobalComponentEnabled;
    property Flags: TApplicationFlags read FFlags write SetFlags;
    //property HelpSystem : IHelpSystem read FHelpSystem;
    property Handle: THandle read GetHandle write SetHandle; platform;
    property Hint: string read FHint write SetHint;
    property HintColor: TColor read FHintColor write SetHintColor;
    property HintHidePause: Integer read FHintHidePause write FHintHidePause;
    property HintHidePausePerChar: Integer read FHintHidePausePerChar write FHintHidePausePerChar;
    property HintPause: Integer read FHintPause write FHintPause;
    property HintShortCuts: Boolean read FHintShortCuts write FHintShortCuts;
    property HintShortPause: Integer read FHintShortPause write FHintShortPause;
    property Icon: TIcon read FIcon write SetIcon;
    property LayoutAdjustmentPolicy: TLayoutAdjustmentPolicy read FLayoutAdjustmentPolicy write FLayoutAdjustmentPolicy;
    property Navigation: TApplicationNavigationOptions read FNavigation write SetNavigation;
    property MainForm: TForm read FMainForm;
    property MainFormHandle: HWND read GetMainFormHandle;
    property MainFormOnTaskBar: Boolean read FMainFormOnTaskBar write SetMainFormOnTaskBar; platform;
    property ModalLevel: Integer read FModalLevel;
    property MoveFormFocusToChildren: Boolean read FMoveFormFocusToChildren write FMoveFormFocusToChildren default True;
    property MouseControl: TControl read FMouseControl;
    property TaskBarBehavior: TTaskBarBehavior read FTaskBarBehavior write SetTaskBarBehavior;
    property UpdateFormatSettings: Boolean read FUpdateFormatSettings write FUpdateFormatSettings; platform;
    property OnActionExecute: TActionEvent read FOnActionExecute write FOnActionExecute;
    property OnActionUpdate: TActionEvent read FOnActionUpdate write FOnActionUpdate;
    property OnActivate: TNotifyEvent read FOnActivate write FOnActivate;
    property OnDeactivate: TNotifyEvent read FOnDeactivate write FOnDeactivate;
    property OnGetMainFormHandle: TGetHandleEvent read FOnGetMainFormHandle write FOnGetMainFormHandle;
    property OnIdle: TIdleEvent read FOnIdle write FOnIdle;
    property OnIdleEnd: TNotifyEvent read FOnIdleEnd write FOnIdleEnd;
    property OnEndSession: TNotifyEvent read FOnEndSession write FOnEndSession;
    property OnQueryEndSession: TQueryEndSessionEvent read FOnQueryEndSession write FOnQueryEndSession;
    property OnMinimize: TNotifyEvent read FOnMinimize write FOnMinimize;
    property OnMessageDialogFinished: TModalDialogFinished read FOnMessageDialogFinished write FOnMessageDialogFinished;
    property OnModalBegin: TNotifyEvent read FOnModalBegin write FOnModalBegin;
    property OnModalEnd: TNotifyEvent read FOnModalEnd write FOnModalEnd;
    property OnRestore: TNotifyEvent read FOnRestore write FOnRestore;
    property OnDropFiles: TDropFilesEvent read FOnDropFiles write FOnDropFiles;
    property OnHelp: THelpEvent read FOnHelp write FOnHelp;
    property OnHint: TNotifyEvent read FOnHint write FOnHint;
    property OnShortcut: TShortcutEvent read FOnShortcut write FOnShortcut;
    property OnShowHint: TShowHintEvent read FOnShowHint write FOnShowHint;
    property OnUserInput: TOnUserInputEvent read FOnUserInput write FOnUserInput;
    property OnDestroy: TNotifyEvent read FOnDestroy write FOnDestroy;
    property OnCircularException: TExceptionEvent read FOnCircularException write FOnCircularException;
    property ShowButtonGlyphs: TApplicationShowGlyphs read FShowButtonGlyphs write SetShowButtonGlyphs default sbgAlways;
    property ShowMenuGlyphs: TApplicationShowGlyphs read FShowMenuGlyphs write SetShowMenuGlyphs default sbgAlways;
    property ShowHint: Boolean read FShowHint write SetShowHint;
    property ShowMainForm: Boolean read FShowMainForm write FShowMainForm default True;
    property Title: String read GetTitle write SetTitle;
    property Scaled: Boolean read FScaled write FScaled;
  end;

const
  DefaultApplicationBiDiMode: TBiDiMode = bdLeftToRight;

  DefHintColor = clInfoBk;           // default hint window color
  DefHintPause = 500;                // default pause before hint window displays (ms)
  DefHintShortPause = 0;             // default reshow pause
  DefHintHidePause = 5*DefHintPause; // default pause before hint is hidden (ms)
  DefHintHidePausePerChar = 200;     // added to DefHintHidePause (ms)

type
  { TApplicationProperties }

  TApplicationProperties = class(TLCLComponent)
  private
    FCaptureExceptions: boolean;
    FExceptionDialogType: TApplicationExceptionDlg;
    FHelpFile: string;
    FHint: string;
    FHintColor: TColor;
    FHintHidePause: Integer;
    FHintPause: Integer;
    FHintShortCuts: Boolean;
    FHintShortPause: Integer;
    FOnActivate: TNotifyEvent;
    FOnDeactivate: TNotifyEvent;
    FOnDropFiles: TDropFilesEvent;
    FOnGetMainFormHandle: TGetHandleEvent;
    FOnModalBegin: TNotifyEvent;
    FOnModalEnd: TNotifyEvent;
    FShowButtonGlyphs: TApplicationShowGlyphs;
    FShowHint: Boolean;
    FShowMainForm: Boolean;
    FShowMenuGlyphs: TApplicationShowGlyphs;
    FTitle: String;

    FOnException: TExceptionEvent;
    FOnIdle: TIdleEvent;
    FOnIdleEnd: TNotifyEvent;
    FOnHelp: THelpEvent;
    FOnHint: TNotifyEvent;
    FOnShowHint: TShowHintEvent;
    FOnUserInput: TOnUserInputEvent;
    FOnEndSession : TNotifyEvent;
    FOnQueryEndSession : TQueryEndSessionEvent;
    FOnMinimize : TNotifyEvent;
    FOnRestore : TNotifyEvent;
    procedure SetExceptionDialog(AValue: TApplicationExceptionDlg);
  protected
    procedure SetCaptureExceptions(const AValue : boolean);
    procedure SetHelpFile(const AValue : string);
    procedure SetHint(const AValue : string);
    procedure SetHintColor(const AValue : TColor);
    procedure SetHintHidePause(const AValue : Integer);
    procedure SetHintPause(const AValue : Integer);
    procedure SetHintShortCuts(const AValue : Boolean);
    procedure SetHintShortPause(const AValue : Integer);
    procedure SetShowButtonGlyphs(const AValue: TApplicationShowGlyphs);
    procedure SetShowMenuGlyphs(const AValue: TApplicationShowGlyphs);
    procedure SetShowHint(const AValue : Boolean);
    procedure SetShowMainForm(const AValue: Boolean);
    procedure SetTitle(const AValue : String);

    procedure SetOnActivate(AValue: TNotifyEvent);
    procedure SetOnDeactivate(AValue: TNotifyEvent);
    procedure SetOnException(const AValue : TExceptionEvent);
    procedure SetOnGetMainFormHandle(const AValue: TGetHandleEvent);
    procedure SetOnIdle(const AValue : TIdleEvent);
    procedure SetOnIdleEnd(const AValue : TNotifyEvent);
    procedure SetOnEndSession(const AValue : TNotifyEvent);
    procedure SetOnQueryEndSession(const AValue : TQueryEndSessionEvent);
    procedure SetOnMinimize(const AValue : TNotifyEvent);
    procedure SetOnModalBegin(const AValue: TNotifyEvent);
    procedure SetOnModalEnd(const AValue: TNotifyEvent);
    procedure SetOnRestore(const AValue : TNotifyEvent);
    procedure SetOnDropFiles(const AValue: TDropFilesEvent);
    procedure SetOnHelp(const AValue : THelpEvent);
    procedure SetOnHint(const AValue : TNotifyEvent);
    procedure SetOnShowHint(const AValue : TShowHintEvent);
    procedure SetOnUserInput(const AValue : TOnUserInputEvent);
  public
    constructor Create(AOwner: TComponent); Override;
    destructor Destroy; override;
  published
    property CaptureExceptions: boolean read FCaptureExceptions
                                        write SetCaptureExceptions default True;
    property ExceptionDialog: TApplicationExceptionDlg read FExceptionDialogType
                                                       write SetExceptionDialog default aedOkCancelDialog;
    property HelpFile: string read FHelpFile write SetHelpFile;
    property Hint: string read FHint write SetHint;
    property HintColor: TColor read FHintColor write SetHintColor default DefHintColor;
    property HintHidePause: Integer read FHintHidePause write SetHintHidePause default DefHintHidePause;
    property HintPause: Integer read FHintPause write SetHintPause default DefHintPause;
    property HintShortCuts: Boolean read FHintShortCuts write SetHintShortCuts default True;
    property HintShortPause: Integer read FHintShortPause write SetHintShortPause default DefHintShortPause;
    property ShowButtonGlyphs: TApplicationShowGlyphs read FShowButtonGlyphs write SetShowButtonGlyphs default sbgAlways;
    property ShowMenuGlyphs: TApplicationShowGlyphs read FShowMenuGlyphs write SetShowMenuGlyphs default sbgAlways;
    property ShowHint: Boolean read FShowHint write SetShowHint default True;
    property ShowMainForm: Boolean read FShowMainForm write SetShowMainForm default True;
    property Title: String read FTitle write SetTitle;

    property OnActivate: TNotifyEvent read FOnActivate write SetOnActivate;
    property OnDeactivate: TNotifyEvent read FOnDeactivate write SetOnDeactivate;
    property OnException: TExceptionEvent read FOnException write SetOnException;
    property OnGetMainFormHandle: TGetHandleEvent read FOnGetMainFormHandle write SetOnGetMainFormHandle;
    property OnIdle: TIdleEvent read FOnIdle write SetOnIdle;
    property OnIdleEnd: TNotifyEvent read FOnIdleEnd write SetOnIdleEnd;
    property OnEndSession: TNotifyEvent read FOnEndSession write SetOnEndSession;
    property OnQueryEndSession: TQueryEndSessionEvent read FOnQueryEndSession write SetOnQueryEndSession;
    property OnMinimize: TNotifyEvent read FOnMinimize write SetOnMinimize;
    property OnModalBegin: TNotifyEvent read FOnModalBegin write SetOnModalBegin;
    property OnModalEnd: TNotifyEvent read FOnModalEnd write SetOnModalEnd;
    property OnRestore: TNotifyEvent read FOnRestore write SetOnRestore;
    property OnDropFiles: TDropFilesEvent read FOnDropFiles write SetOnDropFiles;
    property OnHelp: THelpEvent read FOnHelp write SetOnHelp;
    property OnHint: TNotifyEvent read FOnHint write SetOnHint;
    property OnShowHint: TShowHintEvent read FOnShowHint write SetOnShowHint;
    property OnUserInput: TOnUserInputEvent read FOnUserInput write SetOnUserInput;
  end;


  { TIDesigner }

  TIDesigner = class(TObject)
  protected
    FLookupRoot: TComponent;
    FDefaultFormBoundsValid: boolean;
  public
    function IsDesignMsg(Sender: TControl; var Message: TLMessage): Boolean;
      virtual; abstract;
    procedure UTF8KeyPress(var UTF8Key: TUTF8Char); virtual; abstract;
    procedure Modified; virtual; abstract;
    procedure Notification(AComponent: TComponent;
      Operation: TOperation); virtual; abstract;
    procedure PaintGrid; virtual; abstract;
    procedure ValidateRename(AComponent: TComponent;
      const CurName, NewName: string); virtual; abstract;
    function GetShiftState: TShiftState; virtual; abstract;
    procedure SelectOnlyThisComponent(AComponent: TComponent); virtual; abstract;
    function UniqueName(const BaseName: string): string; virtual; abstract;
    procedure PrepareFreeDesigner(AFreeComponent: boolean); virtual; abstract;
  public
    property LookupRoot: TComponent read FLookupRoot;
    property DefaultFormBoundsValid: boolean read FDefaultFormBoundsValid
                                             write FDefaultFormBoundsValid;
  end;


  { TFormPropertyStorage - abstract base class }

  TFormPropertyStorage = class(TControlPropertyStorage)
  private
    procedure FormCreate(Sender: TObject);
    procedure FormClose(Sender: TObject; var CloseAction: TCloseAction);
    procedure FormDestroy(Sender : TObject);
  public
    constructor Create(TheOwner: TComponent); override;
    destructor Destroy; override;
  end;

function KeysToShiftState(Keys: PtrUInt): TShiftState;
function KeyDataToShiftState(KeyData: PtrInt): TShiftState;
function KeyboardStateToShiftState: TShiftState;
function ShiftStateToKeys(ShiftState: TShiftState): PtrUInt;

function WindowStateToStr(const State: TWindowState): string;
function StrToWindowState(const Name: string): TWindowState;
function dbgs(const State: TWindowState): string; overload;
function dbgs(const Action: TCloseAction): string; overload;
function dbgs(const Kind: TScrollBarKind): string; overload;

type
  TFocusState = Pointer;

function SaveFocusState: TFocusState;
procedure RestoreFocusState(FocusState: TFocusState);

type
  TGetDesignerFormEvent = function(APersistent: TPersistent): TCustomForm of object;
  TIsFormDesignFunction = function(AForm: TWinControl): boolean;

var
  OnGetDesignerForm: TGetDesignerFormEvent = nil;
  IsFormDesign: TIsFormDesignFunction = nil;

function GetParentForm(Control: TControl; TopForm: Boolean = True): TCustomForm;
function GetDesignerForm(Control: TControl): TCustomForm;
function GetFirstParentForm(Control:TControl): TCustomForm;
function GetTopFormSkipNonDocked(Control: TControl): TCustomForm;
function ValidParentForm(Control: TControl; TopForm: Boolean = True): TCustomForm;
function GetDesignerForm(APersistent: TPersistent): TCustomForm;
function FindRootDesigner(APersistent: TPersistent): TIDesigner;
function GetParentDesignControl(Control: TControl): TCustomDesignControl;
function NeedParentDesignControl(Control: TControl): TCustomDesignControl;

function IsAccel(VK: word; const Str: string): Boolean;
procedure NotifyApplicationUserInput(Target: TControl; Msg: Cardinal);


function GetShortHint(const Hint: string): string;
function GetLongHint(const Hint: string): string;


var
  Application: TApplication = nil;
  Screen: TScreen = nil;
  ExceptionObject: TExceptObject;
  HintWindowClass: THintWindowClass = THintWindow;
  RequireDerivedFormResource: Boolean = False;

type
  TMessageBoxFunction = function(Text, Caption : PChar; Flags : Longint) : Integer;
var
  MessageBoxFunction: TMessageBoxFunction = nil;

const
  DefaultBorderIcons : array[TFormBorderStyle] of TBorderIcons =
    ([],                                        // bsNone
     [biSystemMenu, biMinimize],                // bsSingle
     [biSystemMenu, biMinimize, biMaximize],    // bsSizeable
     [biSystemMenu],                            // bsDialog
     [biSystemMenu, biMinimize],                // bsToolWindow
     [biSystemMenu, biMinimize, biMaximize]);   // bsSizeToolWin

procedure CreateWidgetset(AWidgetsetClass: TWidgetsetClass);
procedure FreeWidgetSet;

procedure Register;


implementation

{$R cursors.res}

{$ifdef WinCE}
  {$define extdecl := cdecl}
{$else}
  {$define extdecl := stdcall}
{$endif}

uses
  WSControls, WSForms; // Widgetset uses circle is allowed

var
  HandlingException: Boolean = False;
  HaltingProgram: Boolean = False;
  LastFocusedControl: TWinControl = nil;

procedure Register;
begin
  RegisterComponents('Standard',[TFrame]);
  RegisterComponents('Additional',[TScrollBox, TApplicationProperties]);
end;

{------------------------------------------------------------------------------
  procedure NotifyApplicationUserInput;

 ------------------------------------------------------------------------------}
procedure NotifyApplicationUserInput(Target: TControl; Msg: Cardinal);
begin
  if Assigned(Application) then
    Application.NotifyUserInputHandler(Target, Msg);
end;


//------------------------------------------------------------------------------
procedure ExceptionOccurred(Sender: TObject; Addr:Pointer; FrameCount: Longint;
  Frames: PPointer);
Begin
  DebugLn('[FORMS.PP] ExceptionOccurred ');
  if HaltingProgram or HandlingException then Halt;
  HandlingException:=true;
  if Sender<>nil then
  begin
    DebugLn('  Sender=',Sender.ClassName);
    if Sender is Exception then
    begin
      DebugLn('  Exception=',Exception(Sender).Message);
      DumpExceptionBackTrace();
    end;
  end else
    DebugLn('  Sender=nil');
  if Application<>nil then
    Application.HandleException(Sender);
  HandlingException:=false;
end;

procedure BeforeFinalization;
// This is our ExitProc handler.
begin
  Application.DoBeforeFinalization;
end;

function SaveFocusState: TFocusState;
begin
  Result := LastFocusedControl;
end;

procedure RestoreFocusState(FocusState: TFocusState);
begin
  LastFocusedControl := TWinControl(FocusState);
end;

//------------------------------------------------------------------------------
function KeysToShiftState(Keys: PtrUInt): TShiftState;
begin
  Result := [];
  if Keys and MK_Shift <> 0 then Include(Result, ssShift);
  if Keys and MK_Control <> 0 then Include(Result, ssCtrl);
  if Keys and MK_LButton <> 0 then Include(Result, ssLeft);
  if Keys and MK_RButton <> 0 then Include(Result, ssRight);
  if Keys and MK_MButton <> 0 then Include(Result, ssMiddle);
  if Keys and MK_XBUTTON1 <> 0 then Include(Result, ssExtra1);
  if Keys and MK_XBUTTON2 <> 0 then Include(Result, ssExtra2);
  if Keys and MK_DOUBLECLICK <> 0 then Include(Result, ssDouble);
  if Keys and MK_TRIPLECLICK <> 0 then Include(Result, ssTriple);
  if Keys and MK_QUADCLICK <> 0 then Include(Result, ssQuad);

  if GetKeyState(VK_MENU) < 0 then Include(Result, ssAlt);
  if (GetKeyState(VK_LWIN) < 0) or (GetKeyState(VK_RWIN) < 0) then Include(Result, ssMeta);
end;

function KeyboardStateToShiftState: TShiftState;
begin
  Result := [];
  if GetKeyState(VK_SHIFT) < 0 then Include(Result, ssShift);
  if GetKeyState(VK_CONTROL) < 0 then Include(Result, ssCtrl);
  if GetKeyState(VK_MENU) < 0 then Include(Result, ssAlt);
  if (GetKeyState(VK_LWIN) < 0) or
     (GetKeyState(VK_RWIN) < 0) then Include(Result, ssMeta);
end;

function KeyDataToShiftState(KeyData: PtrInt): TShiftState;
begin
  Result := MsgKeyDataToShiftState(KeyData);
end;

function ShiftStateToKeys(ShiftState: TShiftState): PtrUInt;
begin
  Result := 0;
  if ssShift  in ShiftState then Result := Result or MK_SHIFT;
  if ssCtrl   in ShiftState then Result := Result or MK_CONTROL;
  if ssLeft   in ShiftState then Result := Result or MK_LBUTTON;
  if ssRight  in ShiftState then Result := Result or MK_RBUTTON;
  if ssMiddle in ShiftState then Result := Result or MK_MBUTTON;
  if ssExtra1 in ShiftState then Result := Result or MK_XBUTTON1;
  if ssExtra2 in ShiftState then Result := Result or MK_XBUTTON2;
  if ssDouble in ShiftState then Result := Result or MK_DOUBLECLICK;
  if ssTriple in ShiftState then Result := Result or MK_TRIPLECLICK;
  if ssQuad   in ShiftState then Result := Result or MK_QUADCLICK;
end;

function WindowStateToStr(const State: TWindowState): string;
begin
  Result:=GetEnumName(TypeInfo(TWindowState),ord(State));
end;

function StrToWindowState(const Name: string): TWindowState;
begin
  Result:=TWindowState(GetEnumValueDef(TypeInfo(TWindowState),Name,
                                       ord(wsNormal)));
end;

function dbgs(const State: TWindowState): string; overload;
begin
  Result:=GetEnumName(TypeInfo(TWindowState),ord(State));
end;

function dbgs(const Action: TCloseAction): string; overload;
begin
  Result:=GetEnumName(TypeInfo(TCloseAction),ord(Action));
end;

function dbgs(const Kind: TScrollBarKind): string;
begin
  if Kind=sbVertical then
    Result:='sbVertical'
  else
    Result:='sbHorizontal';
end;

//------------------------------------------------------------------------------
function GetParentForm(Control: TControl; TopForm: Boolean): TCustomForm;
begin
  //For Delphi compatibility if Control is a TCustomForm with no parent, the function returns the TCustomForm itself
  while (Control <> nil) and (Control.Parent <> nil) do
  begin
    if (not TopForm) and (Control is TCustomForm) then
      Break;
    Control := Control.Parent;
  end;
  if Control is TCustomForm then
    Result := TCustomForm(Control)
  else
    Result := nil;
end;

//------------------------------------------------------------------------------
function GetParentDesignControl(Control: TControl): TCustomDesignControl;
begin
  while (Control <> nil) and (Control.Parent <> nil) do
    Control := Control.Parent;

  if Control is TCustomDesignControl then
    Result := TCustomDesignControl(Control)
  else
    Result := nil;
end;

//------------------------------------------------------------------------------
function NeedParentDesignControl(Control: TControl): TCustomDesignControl;
begin
  Result := GetParentDesignControl(Control);
  if Result=nil then
    raise EInvalidOperation.CreateFmt(rsControlHasNoParentFormOrFrame, [Control.Name]);
end;

//------------------------------------------------------------------------------
function GetDesignerForm(Control: TControl): TCustomForm;
begin
  // find the topmost parent form with designer

  Result := nil;
  while Control<>nil do
  begin
    if (Control is TCustomForm) and (TCustomForm(Control).Designer<>nil) then
      Result := TCustomForm(Control);
    Control := Control.Parent;
  end;
end;

function GetTopFormSkipNonDocked(Control: TControl): TCustomForm;
var
  aForm: TCustomForm;
begin
  Result:=GetParentForm(Control, False);
  if Result=nil then exit;
  if Result.DockSite or Result.UseDockManager then exit;
  repeat
    aForm:=GetParentForm(Result.Parent,false);
    if (aForm=nil) or aForm.DockSite or aForm.UseDockManager then exit;
    Result:=aForm;
  until false;
end;

//------------------------------------------------------------------------------
function ValidParentForm(Control: TControl; TopForm: Boolean): TCustomForm;
begin
  Result := GetParentForm(Control, TopForm);
  if Result = nil then
    raise EInvalidOperation.CreateFmt(sParentRequired, [Control.Name]);
end;


//------------------------------------------------------------------------------
function IsAccel(VK: word; const Str: string): Boolean;
const
  AmpersandChar = '&';
var
  position: integer;
  ACaption, FoundChar: string;
begin
  ACaption := Str;
  Result := false;
  repeat
    position := UTF8Pos(AmpersandChar, ACaption);
    // Not found or found at the end of string. Nothing to underscore.
    if (position <= 0) or (position >= UTF8Length(ACaption)) then break;
    FoundChar := UTF8Copy(ACaption, position+1, 1);
    // two AmpersandChar characters together are not valid hot key
    if FoundChar = AmpersandChar then
      UTF8Delete(ACaption, 1, position+1)
    else
      Exit(UTF8UpperCase(UTF16ToUTF8(WideString(WideChar(VK)))) = UTF8UpperCase(FoundChar));
  until false;
end;

//==============================================================================

function FindRootDesigner(APersistent: TPersistent): TIDesigner;
var
  Form: TCustomForm;
begin
  Result:=nil;
  Form:=GetDesignerForm(APersistent);
  if Form<>nil then
    Result:=Form.Designer;
end;

function GetFirstParentForm(Control: TControl): TCustomForm;
begin
  if (Control = nil) then
    Result:= nil
  else
    Result := GetParentForm(Control, False);
end;

function GetDesignerForm(APersistent: TPersistent): TCustomForm;
begin
  if APersistent = nil then Exit(nil);
  if Assigned(OnGetDesignerForm) then
    Result := OnGetDesignerForm(APersistent)
  else
  begin
    Result := nil;
    repeat
      if (APersistent is TComponent) then begin
        if TComponent(APersistent).Owner=nil then
          exit;
        APersistent:=TComponent(APersistent).Owner
      end else if APersistent is TCollection then begin
        if TCollection(APersistent).Owner=nil then
          exit;
        APersistent:=TCollection(APersistent).Owner
      end else if APersistent is TCollectionItem then begin
        if TCollectionItem(APersistent).Collection=nil then
          exit;
        APersistent:=TCollectionItem(APersistent).Collection
      end else if APersistent is TCustomForm then begin
        Result := TCustomForm(APersistent);
        exit;
      end else
        exit;
    until false;
  end;
end;

function SendApplicationMsg(Msg: Cardinal; WParam: WParam; LParam: LParam): Longint;
var
  AMessage: TLMessage;
begin
  if Application<>nil then begin
    AMessage.Msg := Msg;
    AMessage.WParam := WParam;
    AMessage.LParam := LParam;
    { Can't simply use SendMessage, as the Application does not necessarily have a handle }
    Application.WndProc(AMessage);
    Result := AMessage.Result;
  end else
    Result := 0;
end;

procedure IfOwnerIsFormThenDesignerModified(AComponent: TComponent);
begin
  if (AComponent<>nil) and (AComponent.Owner<>nil)
  and ([csDesigning,csLoading]*AComponent.ComponentState=[csDesigning])
  and (AComponent.Owner is TForm)
  and (TForm(AComponent.Owner).Designer <> nil) then
    TForm(AComponent.Owner).Designer.Modified;
end;

function GetShortHint(const Hint: string): string;
var
  I: Integer;
begin
  I := Pos('|', Hint);
  if I = 0 then
    Result := Hint else
    Result := Copy(Hint, 1, I - 1);
end;

function GetLongHint(const Hint: string): string;
var
  I: Integer;
begin
  I := Pos('|', Hint);
  if I = 0 then
    Result := Hint else
    Result := Copy(Hint, I + 1, Maxint);
end;

procedure CreateWidgetset(AWidgetsetClass: TWidgetsetClass);
begin
  //debugln('CreateWidgetset');
  CallInterfaceInitializationHandlers;
  WidgetSet := AWidgetsetClass.Create;
end;

procedure FreeWidgetSet;
begin
  //debugln('FreeWidgetSet');
  if Screen <> nil then
  begin
    Screen.DestroyCursors;
    Screen.DestroyMonitors;
  end;
  Application.Free;
  Application:=nil;
  CustomApplication:=nil;
  FreeAllClipBoards;
  CallInterfaceFinalizationHandlers;
  WidgetSet.Free;
  WidgetSet:=nil;
end;


//==============================================================================

{$I controlscrollbar.inc}
{$I scrollingwincontrol.inc}
{$I scrollbox.inc}
{$I customdesigncontrol.inc}
{$I customframe.inc}
{$I customform.inc}
{$I customdockform.inc}
{$I monitor.inc}
{$I screen.inc}
{$I application.inc}
{$I applicationproperties.inc}
{$I hintwindow.inc}


//==============================================================================

procedure ImageDrawEvent(AImageList: TPersistent; ACanvas: TPersistent;
                     AX, AY, AIndex: Integer; ADrawEffect: TGraphicsDrawEffect;
                     AImageWidth: Integer; ARefControl: TPersistent);
var
  ImageList: TCustomImageList absolute AImageList;
  Canvas: TCanvas absolute ACanvas;
  RefControl: TControl absolute ARefControl;
begin
  if (RefControl<>nil) and ImageList.Scaled then
    ImageList.DrawForControl(Canvas,AX,AY,AIndex,AImageWidth,RefControl,ADrawEffect)
  else
    ImageList.Draw(Canvas,AX,AY,AIndex,ADrawEffect)
end;

function IsFormDesignFunction(AForm: TWinControl): boolean;
var
  LForm: TCustomForm absolute AForm;
begin
  if (AForm = nil) or not (AForm is TCustomForm) then
    Exit(False);
  Result := (csDesignInstance in LForm.ComponentState)
     or ((csDesigning in LForm.ComponentState) and (LForm.Designer <> nil));
end;

initialization
  LCLProc.OwnerFormDesignerModifiedProc:=@IfOwnerIsFormThenDesignerModified;
  ThemesImageDrawEvent:=@ImageDrawEvent;
  IsFormDesign:=@IsFormDesignFunction;
  Screen:=TScreen.Create(nil);
  Application:=TApplication.Create(nil);
  Assert(CustomApplication=Nil, 'CustomApplication is assigned in Forms initialization.');
  CustomApplication:=Application;

finalization
  //DebugLn('forms.pp - finalization section');
  LCLProc.OwnerFormDesignerModifiedProc:=nil;
  HintWindowClass:=nil;
  FreeThenNil(Application);
  CustomApplication:=nil;
  FreeThenNil(Screen);

end.

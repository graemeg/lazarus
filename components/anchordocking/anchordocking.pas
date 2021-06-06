{ Unit implementing anchor docking.

  Copyright (C) 2018 Mattias Gaertner mattias@freepascal.org

  This library is free software; you can redistribute it and/or modify it
  under the terms of the GNU Library General Public License as published by
  the Free Software Foundation; either version 2 of the License, or (at your
  option) any later version with the following modification:

  As a special exception, the copyright holders of this library give you
  permission to link this library with independent modules to produce an
  executable, regardless of the license terms of these independent modules,and
  to copy and distribute the resulting executable under terms of your choice,
  provided that you also meet, for each linked independent module, the terms
  and conditions of the license of that module. An independent module is a
  module which is not derived from or based on this library. If you modify
  this library, you may extend this exception to your version of the library,
  but you are not obligated to do so. If you do not wish to do so, delete this
  exception statement from your version.

  This program is distributed in the hope that it will be useful, but WITHOUT
  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
  FITNESS FOR A PARTICULAR PURPOSE. See the GNU Library General Public License
  for more details.

  You should have received a copy of the GNU Library General Public License
  along with this library; if not, write to the Free Software Foundation,
  Inc., 51 Franklin Street - Fifth Floor, Boston, MA 02110-1335, USA.

  Features:
    - dnd docking
    - preview rectangle while drag over
    - inside and outside docking
    - header with close button and hints
    - using stock item for close button glyph
    - auto header caption from content
    - hide header caption for floating form
    - auto site for headers to safe space (configurable)
    - bidimode for headers
    - page docking
    - pagecontrols uses TPageControl for native look&feel
    - page control is automatically removed if only one page left
    - scaling on resize (configurable)
    - auto insert splitters between controls (size configurable)
    - keep size when docking
    - header is automatically hidden when docked into page
    - save complete layout
    - restore layout:
       - close unneeded windows,
       - automatic clean up if windows are missing,
       - reusing existing docksites to minimize flickering
    - popup menu
       - close site
       - lock/unlock
       - header auto, left, top, right, bottom
       - undock (needed if no place to undock on screen)
       - merge (for example after moving a dock page into a layout)
       - enlarge side to left, top, right, bottom
       - move page left, right, leftmost, rightmost
       - close page
       - tab position (default, left, top, right, bottom)
       - options
    - dock site: MakeDockSite for forms, that should be able to dock other sites,
       but should not be docked themselves. Their Parent is always nil.
    - design time package for IDE
    - dnd move page index
    - dnd move page to another pagecontrol
    - on close button: save a restore layout
    - option to show/hide dock headers
    - option HeaderStyle to change appearance of grabbers
    - option MultiLine show pages tabs on multiple lines when needed
    - option FloatingWindowsOnTop MainDockForm has FormStyle fsNormal, all other
      not docked windows get FormStyle fsStayOnTop to not hide helper windows

  ToDo:
    - option to save on IDE close (if MainForm is visible on active screen)
    - restore: put MainForm on active screen
    - restore custom dock site splitter without resizing content, only resize docked site
    - undock on hide
    - popup menu
       - shrink side left, top, right, bottom
    - implement a simple way to make forms dockable at designtime without any code
    - on show again (hide form, show form): restore layout
    - close button for pages
    - event for drawing grabbers+headers
    - save/restore other splitters

    Parent bug with links to all other:
    - http://bugs.freepascal.org/view.php?id=18298 default layout sometimes wrong main bar
    Other bugs:
    - http://bugs.freepascal.org/view.php?id=19810 multi monitor
}
unit AnchorDocking;

{$mode objfpc}{$H+}
{$modeswitch advancedrecords}
{$modeswitch typehelpers}

// better use this definitions in project options, as it used in other units too
{ $DEFINE VerboseAnchorDockRestore}
{ $DEFINE VerboseADCustomSite}
{ $DEFINE VerboseAnchorDockPages}
{ $DEFINE VerboseAnchorDocking}

interface

uses
  Math, Classes, SysUtils, types, fgl,
  LCLType, LCLIntf, LCLProc,
  Controls, Forms, ExtCtrls, ComCtrls, Graphics, Themes, Menus, Buttons,
  LazConfigStorage, Laz2_XMLCfg, LazFileCache, LazUTF8,
  AnchorDockStr, AnchorDockStorage, AnchorDockPanel;

{$IFDEF DebugDisableAutoSizing}
const ADAutoSizingReason = 'TAnchorDockMaster Delayed';
{$ENDIF}

const EmptyMouseTimeStartX=low(Integer);
      MouseNoMoveDelta=5;
      MouseNoMoveTime=500;
      HideOverlappingFormByMouseLoseTime=500;
      ButtonBorderSpacingAround=4;
      OppositeAnchorKind2Align: array[TAnchorKind] of TAlign = (
        alBottom, // akTop,
        alRight,  // akLeft,
        alLeft,   // akRight,
        alTop     // akBottom
        );
      OppositeAnchorKind: array[TAnchorKind] of TAnchorKind = (
        akBottom, // akTop,
        akRight,  // akLeft,
        akLeft,   // akRight,
        akTop     // akBottom
        );
      {AnchorKind2Align: array[TAnchorKind] of TAlign = (
        alTop,  // akTop,
        alLeft, // akLeft,
        alRight,// akRight,
        alBottom// akBottom
        );}
      OppositeAnchorKind2TADLHeaderPosition: array[TAnchorKind] of TADLHeaderPosition = (
        adlhpBottom, // akTop,
        adlhpRight,  // akLeft,
        adlhpLeft,   // akRight,
        adlhpTop     // akBottom
        );


type
  TAnchorDockHostSite = class;

  { TAnchorDockCloseButton
    Close button used in TAnchorDockHeader, uses the close button glyph of the
    theme shrinked to a small size. The glyph is shared by all close buttons. }

  TAnchorDockCloseButton = class(TCustomSpeedButton)
  protected
    function GetDrawDetails: TThemedElementDetails; override;
    procedure CalculatePreferredSize(var PreferredWidth,
           PreferredHeight: integer; {%H-}WithThemeSpace: Boolean); override;
  end;

  TAnchorDockMinimizeButton = class(TCustomSpeedButton)
  protected
    function GetDrawDetails: TThemedElementDetails; override;
    procedure CalculatePreferredSize(var PreferredWidth,
           PreferredHeight: integer; {%H-}WithThemeSpace: Boolean); override;
  end;


  { TAnchorDockHeader
    The panel of a TAnchorDockHostSite containing the close button and the
    caption when the form is docked. The header can be shown at any of the four
    sides, shows a hint for long captions, starts dragging and shows the popup
    menu of the dockmaster.
    Hiding and aligning is done by its Parent, which is a TAnchorDockHostSite }

    THeaderStyleName=string;

    TADHeaderStyleDesc=record
      NeedDrawHeaderAfterText,NeedHighlightText:boolean;
      Name:THeaderStyleName;
    end;

    TDrawADHeaderProc= procedure (Canvas: TCanvas; Style: TADHeaderStyleDesc; r: TRect;
    Horizontal: boolean; Focused: boolean);

    TADHeaderStyle=record
      StyleDesc:TADHeaderStyleDesc;
      DrawProc:TDrawADHeaderProc;
    end;

    THeaderStyleName2ADHeaderStylesMap=specialize TFPGMap<THeaderStyleName, TADHeaderStyle>;

  type

  TAnchorDockHeader = class(TCustomPanel)
  private
    FCloseButton: TCustomSpeedButton;
    FMinimizeButton: TCustomSpeedButton;
    FHeaderPosition: TADLHeaderPosition;
    FFocused: Boolean;
    FUseTimer: Boolean;
    FMouseTimeStartX,FMouseTimeStartY:Integer;
    procedure CloseButtonClick(Sender: TObject);
    procedure MinimizeButtonClick(Sender: TObject);
    procedure HeaderPositionItemClick(Sender: TObject);
    procedure UndockButtonClick(Sender: TObject);
    procedure MergeButtonClick(Sender: TObject);
    procedure EnlargeSideClick(Sender: TObject);
    procedure SetHeaderPosition(const AValue: TADLHeaderPosition);
  protected
    procedure Paint; override;
    procedure Draw(HeaderStyle:TADHeaderStyle);
    procedure CalculatePreferredSize(var PreferredWidth,
          PreferredHeight: integer; WithThemeSpace: Boolean); override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X,
             Y: Integer); override;
    procedure MouseMove(Shift: TShiftState; X,Y: Integer); override;
    procedure MouseLeave;  override;
    procedure StartMouseNoMoveTimer;
    procedure StopMouseNoMoveTimer;
    procedure DoMouseNoMoveTimer(Sender: TObject);
    procedure UpdateHeaderControls;
    procedure SetAlign(Value: TAlign); override;
    procedure DoOnShowHint(HintInfo: PHintInfo); override;
    procedure PopupMenuPopup(Sender: TObject); virtual;
  public
    constructor Create(TheOwner: TComponent); override;
    property CloseButton: TCustomSpeedButton read FCloseButton;
    property MinimizeButton: TCustomSpeedButton read FMinimizeButton;
    property HeaderPosition: TADLHeaderPosition read FHeaderPosition write SetHeaderPosition;
    property BevelOuter default bvNone;
  end;
  TAnchorDockHeaderClass = class of TAnchorDockHeader;

  { TAnchorDockSplitter
    A TSplitter used on a TAnchorDockHostSite with SiteType=adhstLayout.
    It can store DockBounds, used by its parent to scale. Scaling works by
    moving the splitters. All other controls are fully anchored to these
    splitters or their parent. }

  TAnchorDockSplitter = class(TCustomSplitter)
  private
    FAsyncUpdateDockBounds: boolean;
    FCustomWidth: Boolean;
    FDockBounds: TRect;
    FDockParentClientSize: TSize;
    FDockRestoreBounds: TRect;
    FPercentPosition: Single;
    procedure SetAsyncUpdateDockBounds(const AValue: boolean);
    procedure UpdatePercentPosition;
  protected
    procedure OnAsyncUpdateDockBounds({%H-}Data: PtrInt);
    procedure SetResizeAnchor(const AValue: TAnchorKind); override;
    procedure SetParent(NewParent: TWinControl); override;
    procedure PopupMenuPopup(Sender: TObject); virtual;
    procedure Paint; override;
  public
    procedure MoveSplitter(Offset: integer); override;
  public
    constructor Create(TheOwner: TComponent); override;
    destructor Destroy; override;
    property DockBounds: TRect read FDockBounds;
    property DockParentClientSize: TSize read FDockParentClientSize;
    procedure UpdateDockBounds;
    property AsyncUpdateDockBounds: boolean read FAsyncUpdateDockBounds write SetAsyncUpdateDockBounds;
    procedure SetBounds(ALeft, ATop, AWidth, AHeight: integer); override; // any normal movement sets the DockBounds
    procedure SetBoundsPercentually;
    procedure SetBoundsKeepDockBounds(ALeft, ATop, AWidth, AHeight: integer); // movement for scaling keeps the DockBounds
    function SideAnchoredControlCount(Side: TAnchorKind): integer;
    function HasAnchoredControls: boolean;
    function GetSpliterBoundsWithUnminimizedDockSites:TRect;
    procedure SaveLayout(LayoutNode: TAnchorDockLayoutTreeNode);
    function HasOnlyOneSibling(Side: TAnchorKind; MinPos, MaxPos: integer): TControl;
    property DockRestoreBounds: TRect read FDockRestoreBounds write FDockRestoreBounds;
    property CustomWidth: Boolean read FCustomWidth write FCustomWidth;
    // Increase visibility of TCustomSplitter events:
    property OnMouseWheel;
    property OnMouseWheelDown;
    property OnMouseWheelUp;
  end;
  TAnchorDockSplitterClass = class of TAnchorDockSplitter;

  TAnchorDockPageControl = class;
  { TAnchorDockPage
    A page of a TAnchorDockPageControl. }

  TAnchorDockPage = class(TCustomPage)
  public
    procedure UpdateDockCaption(Exclude: TControl = nil); override;
    procedure InsertControl(AControl: TControl; Index: integer); override;
    procedure RemoveControl(AControl: TControl); override;
    function GetSite: TAnchorDockHostSite;
  end;
  TAnchorDockPageClass = class of TAnchorDockPage;

  { TAnchorDockPageControl
    Used for page docking.
    The parent is always a TAnchorDockHostSite with SiteType=adhstPages.
    Its children are all TAnchorDockPage.
    It shows the DockMaster popup menu and starts dragging. }

  TAnchorDockPageControl = class(TCustomTabControl)
  private
    function GetDockPages(Index: integer): TAnchorDockPage;
  protected
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X,Y: Integer); override;
    procedure PopupMenuPopup(Sender: TObject); virtual;
    procedure CloseButtonClick(Sender: TObject); virtual;
    procedure MoveLeftButtonClick(Sender: TObject); virtual;
    procedure MoveLeftMostButtonClick(Sender: TObject); virtual;
    procedure MoveRightButtonClick(Sender: TObject); virtual;
    procedure MoveRightMostButtonClick(Sender: TObject); virtual;
    procedure TabPositionClick(Sender: TObject); virtual;
    function GetPageClass: TCustomPageClass;override;
  public
    constructor Create(TheOwner: TComponent); override;
    procedure UpdateDockCaption(Exclude: TControl = nil); override;
    property DockPages[Index: integer]: TAnchorDockPage read GetDockPages;
    procedure RemoveControl(AControl: TControl); override;
    function GetActiveSite: TAnchorDockHostSite;
  end;
  TAnchorDockPageControlClass = class of TAnchorDockPageControl;


  TAnchorDockOverlappingForm = class(TCustomForm)
  public
    AnchorDockHostSite:TAnchorDockHostSite;
    Panel:TPanel;
    constructor CreateNew(AOwner: TComponent; Num: Integer = 0); override;
  end;

  { TAnchorDockHostSite
    This form is the dockhostsite for all controls.
    When docked together they build a tree structure with the docked controls
    as leaf nodes.
    A TAnchorDockHostSite has four modes: TAnchorDockHostSiteType }

  TAnchorDockHostSiteType = (
    adhstNone,  // fresh created, no control docked
    adhstOneControl, // a control and the "Header" (TAnchorDockHeader)
    adhstLayout, // several controls/TAnchorDockHostSite separated by TAnchorDockSplitters
    adhstPages  // the "Pages" (TAnchorDockPageControl) with several pages
    );

  TAnchorDockHostSite = class(TCustomForm)
  private
    FDockRestoreBounds: TRect;
    FHeader: TAnchorDockHeader;
    FHeaderSide: TAnchorKind;
    FPages: TAnchorDockPageControl;
    FSiteType: TAnchorDockHostSiteType;
    FBoundSplitter: TAnchorDockSplitter;
    FUpdateLayout: Integer;
    FMinimizedControl: TControl;
    procedure CheckFormStyle;
    procedure FirstShow(Sender: TObject);
    function GetMinimized: Boolean;
    procedure SetHeaderSide(const AValue: TAnchorKind);
  protected
    procedure DoEnter; override;
    procedure DoExit; override;
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
    function DoDockClientMsg(DragDockObject: TDragDockObject;
                             aPosition: TPoint): boolean; override;
    function ExecuteDock(NewControl, DropOnControl: TControl; DockAlign: TAlign): boolean; virtual;
    function DockFirstControl(NewControl: TControl): boolean; virtual;
    function DockSecondControl(NewControl: TControl; DockAlign: TAlign;
                               Inside: boolean): boolean; virtual;
    function DockAnotherControl(Sibling, NewControl: TControl; DockAlign: TAlign;
                                Inside: boolean): boolean; virtual;
    procedure ChildVisibleChanged(Sender: TObject); virtual;
    procedure CreatePages; virtual;
    procedure FreePages; virtual;
    function DockSecondPage(NewControl: TControl): boolean; virtual;
    function DockAnotherPage(NewControl: TControl; InFrontOf: TControl): boolean; virtual;
    procedure AddCleanControl(AControl: TControl; TheAlign: TAlign = alNone);
    procedure RemoveControlFromLayout(AControl: TControl);
    procedure RemoveMinimizedControl;
    procedure RemoveSpiralSplitter(AControl: TControl);
    procedure ClearChildControlAnchorSides(AControl: TControl);
    procedure Simplify;
    procedure SimplifyPages;
    procedure SimplifyOneControl;
    function GetOneControl: TControl;
    function GetSiteCount: integer;
    function IsOneSiteLayout(out Site: TAnchorDockHostSite): boolean;
    function IsTwoSiteLayout(out Site1, Site2: TAnchorDockHostSite): boolean;
    function GetUniqueSplitterName: string;
    function MakeSite(AControl: TControl): TAnchorDockHostSite;
    procedure MoveAllControls(dx, dy: integer);
    procedure AlignControls(AControl: TControl; var ARect: TRect); override;
    function CheckIfOneControlHidden: boolean;
    procedure DoDock(NewDockSite: TWinControl; var ARect: TRect); override;
    procedure SetParent(NewParent: TWinControl); override;
    function HeaderNeedsShowing: boolean;
    procedure DoClose(var CloseAction: TCloseAction); override;
    function CanUndock: boolean;
    procedure Undock;
    function CanMerge: boolean;
    procedure Merge;
    function EnlargeSide(Side: TAnchorKind;
                         OnlyCheckIfPossible: boolean): boolean;
    function EnlargeSideResizeTwoSplitters(ShrinkSplitterSide,
                         EnlargeSpitterSide: TAnchorKind;
                         OnlyCheckIfPossible: boolean): boolean;
    function EnlargeSideRotateSplitter(Side: TAnchorKind;
                         OnlyCheckIfPossible: boolean): boolean;
    procedure CreateBoundSplitter(Disabled: boolean=false);
    procedure PositionBoundSplitter;
  public
    constructor CreateNew(AOwner: TComponent; Num: Integer = 0); override;
    destructor Destroy; override;
    function CloseQuery: boolean; override;
    function CloseSite: boolean; virtual;
    procedure MinimizeSite; virtual;
    procedure AsyncMinimizeSite({%H-}Data: PtrInt);
    procedure ShowMinimizedControl;
    procedure HideMinimizedControl;
    procedure RemoveControl(AControl: TControl); override;
    procedure InsertControl(AControl: TControl; Index: integer); override;
    procedure GetSiteInfo(Client: TControl; var InfluenceRect: TRect;
                          MousePos: TPoint; var CanDock: Boolean); override;
    function GetPageArea: TRect;
    procedure ChangeBounds(ALeft, ATop, AWidth, AHeight: integer;
                           KeepBase: boolean); override;
    procedure UpdateDockCaption(Exclude: TControl = nil); override;
    procedure UpdateHeaderAlign;
    procedure UpdateHeaderShowing;
    function CanBeMinimized(out Splitter: TAnchorDockSplitter; out SplitterAnchorKind:TAnchorKind):boolean;
    procedure BeginUpdateLayout;
    procedure EndUpdateLayout;
    function UpdatingLayout: boolean;

    // save/restore layout
    procedure SaveLayout(LayoutTree: TAnchorDockLayoutTree;
                         LayoutNode: TAnchorDockLayoutTreeNode);
    property DockRestoreBounds: TRect read FDockRestoreBounds write FDockRestoreBounds;
    function GetDockEdge(const MousePos: TPoint): TAlign; override;

    property HeaderSide: TAnchorKind read FHeaderSide write SetHeaderSide;
    property Header: TAnchorDockHeader read FHeader;
    property Minimized: Boolean read GetMinimized;
    property MinimizedControl: TControl read FMinimizedControl;
    property Pages: TAnchorDockPageControl read FPages;
    property SiteType: TAnchorDockHostSiteType read FSiteType;
    property BoundSplitter: TAnchorDockSplitter read FBoundSplitter;
  end;
  TAnchorDockHostSiteClass = class of TAnchorDockHostSite;

  TADMResizePolicy = (
    admrpNone,
    admrpChild  // resize child
    );

  { TAnchorDockManager
    A TDockManager is the LCL connector to catch various docking events for a
    TControl. Every TAnchorDockHostSite and every custom dock site gets one
    TAnchorDockManager. The LCL frees it automatically when the Site is freed. }

  TAnchorDockManager = class(TDockManager)
  private
    FDockableSites: TAnchors;
    FDockSite: TAnchorDockHostSite;
    FInsideDockingAllowed: boolean;
    FPreferredSiteSizeAsSiteMinimum: boolean;
    FResizePolicy: TADMResizePolicy;
    FStoredConstraints: TRect;
    FSite: TWinControl;
    FSiteClientRect: TRect;
    procedure SetPreferredSiteSizeAsSiteMinimum(const AValue: boolean);
  public
    constructor Create(ADockSite: TWinControl); override;
    procedure GetControlBounds(Control: TControl; out AControlBounds: TRect);
      override;
    procedure InsertControl(Control: TControl; InsertAt: TAlign;
      DropCtl: TControl); override; overload;
    procedure InsertControl(ADockObject: TDragDockObject); override; overload;
    procedure LoadFromStream(Stream: TStream); override;
    procedure PositionDockRect(Client, DropCtl: TControl; DropAlign: TAlign;
      var DockRect: TRect); override; overload;
    procedure RemoveControl(Control: TControl); override;
    procedure ResetBounds(Force: Boolean); override;
    procedure SaveToStream(Stream: TStream); override;
    function GetDockEdge(ADockObject: TDragDockObject): boolean; override;
    procedure RestoreSite(SplitterPos: integer);
    procedure StoreConstraints;
    function GetSitePreferredClientSize: TPoint;
    function IsEnabledControl(Control: TControl):Boolean; override;

    property Site: TWinControl read FSite; // the associated TControl (a TAnchorDockHostSite or a custom dock site)
    property DockSite: TAnchorDockHostSite read FDockSite; // if Site is a TAnchorDockHostSite, this is it
    property DockableSites: TAnchors read FDockableSites write FDockableSites; // at which sides can be docked
    property InsideDockingAllowed: boolean read FInsideDockingAllowed write FInsideDockingAllowed; // if true allow to put a site into the custom dock site
    function GetChildSite: TAnchorDockHostSite; // get first child TAnchorDockHostSite
    property ResizePolicy: TADMResizePolicy read FResizePolicy write FResizePolicy;
    property StoredConstraints: TRect read FStoredConstraints write FStoredConstraints;
    function StoredConstraintsValid: boolean;
    property PreferredSiteSizeAsSiteMinimum: boolean read FPreferredSiteSizeAsSiteMinimum write SetPreferredSiteSizeAsSiteMinimum;
  end;
  TAnchorDockManagerClass = class of TAnchorDockManager;

  { TAnchorDockSettings }

type
  TAnchorDockSettings = class
  private
    FAllowDragging: boolean;
    FChangeStamp: integer;
    FDockOutsideMargin: integer;
    FDockParentMargin: integer;
    FDragTreshold: integer;
    FFloatingWindowsOnTop: boolean;
    FHeaderAlignLeft: integer;
    FHeaderAlignTop: integer;
    FHeaderHint: string;
    FHeaderStyle: THeaderStyleName;
    FHeaderFlatten: boolean;
    FHeaderFilled: boolean;
    FHeaderHighlightFocused: boolean;
    FHideHeaderCaptionFloatingControl: boolean;
    FMultiLinePages: boolean;
    FPageAreaInPercent: integer;
    FScaleOnResize: boolean;
    FShowHeader: boolean;
    FShowHeaderCaption: boolean;
    FSplitterWidth: integer;
    FDockSitesCanBeMinimized: boolean;
    procedure SetAllowDragging(AValue: boolean);
    procedure SetDockOutsideMargin(AValue: integer);
    procedure SetDockParentMargin(AValue: integer);
    procedure SetDragTreshold(AValue: integer);
    procedure SetFloatingWindowsOnTop(AValue: boolean);
    procedure SetHeaderAlignLeft(AValue: integer);
    procedure SetHeaderAlignTop(AValue: integer);
    procedure SetHeaderHint(AValue: string);
    procedure SetHeaderStyle(AValue: THeaderStyleName);
    procedure SetHideHeaderCaptionFloatingControl(AValue: boolean);
    procedure SetMultiLinePages(AValue: boolean);
    procedure SetPageAreaInPercent(AValue: integer);
    procedure SetScaleOnResize(AValue: boolean);
    procedure SetShowHeader(AValue: boolean);
    procedure SetShowHeaderCaption(AValue: boolean);
    procedure SetSplitterWidth(AValue: integer);
    procedure SetHeaderFlatten(AValue: boolean);
    procedure SetHeaderFilled(AValue: boolean);
    procedure SetHeaderHighlightFocused(AValue: boolean);
    procedure SetDockSitesCanBeMinimized(AValue: boolean);
  public
    property DragTreshold: integer read FDragTreshold write SetDragTreshold;
    property DockOutsideMargin: integer read FDockOutsideMargin write SetDockOutsideMargin;
    property DockParentMargin: integer read FDockParentMargin write SetDockParentMargin;
    property PageAreaInPercent: integer read FPageAreaInPercent write SetPageAreaInPercent;
    property HeaderAlignTop: integer read FHeaderAlignTop write SetHeaderAlignTop;
    property HeaderAlignLeft: integer read FHeaderAlignLeft write SetHeaderAlignLeft;
    property HeaderHint: string read FHeaderHint write SetHeaderHint;
    property SplitterWidth: integer read FSplitterWidth write SetSplitterWidth;
    property ScaleOnResize: boolean read FScaleOnResize write SetScaleOnResize;
    property ShowHeader: boolean read FShowHeader write SetShowHeader;
    property ShowHeaderCaption: boolean read FShowHeaderCaption write SetShowHeaderCaption;
    property HideHeaderCaptionFloatingControl: boolean read FHideHeaderCaptionFloatingControl write SetHideHeaderCaptionFloatingControl;
    property AllowDragging: boolean read FAllowDragging write SetAllowDragging;
    property HeaderStyle: THeaderStyleName read FHeaderStyle write SetHeaderStyle;
    property HeaderFlatten: boolean read FHeaderFlatten write SetHeaderFlatten;
    property HeaderFilled: boolean read FHeaderFilled write SetHeaderFilled;
    property HeaderHighlightFocused: boolean read FHeaderHighlightFocused write SetHeaderHighlightFocused;
    property DockSitesCanBeMinimized: boolean read FDockSitesCanBeMinimized write SetDockSitesCanBeMinimized;
    property FloatingWindowsOnTop: boolean read FFloatingWindowsOnTop write SetFloatingWindowsOnTop;
    property MultiLinePages: boolean read FMultiLinePages write SetMultiLinePages;
    procedure IncreaseChangeStamp; inline;
    property ChangeStamp: integer read FChangeStamp;
    procedure LoadFromConfig(Config: TConfigStorage); overload;
    procedure LoadFromConfig(Path: string; Config: TRttiXMLConfig); overload;
    procedure SaveToConfig(Config: TConfigStorage); overload;
    procedure SaveToConfig(Path: string; Config: TRttiXMLConfig); overload;
    function IsEqual(Settings: TAnchorDockSettings): boolean; reintroduce;
    procedure Assign(Source: TAnchorDockSettings);
  end;

  TMapMinimizedControls = specialize TFPGMap <Pointer, Pointer>;

  TAnchorDockMaster = class;

  { TAnchorDockMaster
    The central instance that connects all sites and manages all global
    settings. Its global variable is the DockMaster.
    Applications only need to talk to the DockMaster. }

  TADCreateControlEvent = procedure(Sender: TObject; aName: string;
                var AControl: TControl; DoDisableAutoSizing: boolean) of object;
  TADShowDockMasterOptionsEvent = function(aDockMaster: TAnchorDockMaster): TModalResult;

  { TStyleOfForm }

  TStyleOfForm = record
    Form: TCustomForm;
    FormStyle: TFormStyle;
    class operator = (Item1, Item2: TStyleOfForm): Boolean;
  end;

  { TFormStyles }

  TFormStyles = class(specialize TFPGList<TStyleOfForm>)
  public
    procedure AddForm(const AForm: TCustomForm);
    function IndexOfForm(const AForm: TCustomForm): Integer;
    procedure RemoveForm(const AForm: TCustomForm);
  end;

  TAnchorDockMaster = class(TComponent)
  private
    FAllowDragging: boolean;
    FControls: TFPList; // list of TControl, custom host sites and docked controls, not helper controls (e.g. TAnchorDock*)
    FDockOutsideMargin: integer;
    FDockParentMargin: integer;
    FDragTreshold: integer;
    FFloatingWindowsOnTop: boolean;
    FFormStyles: TFormStyles;
    FHeaderAlignLeft: integer;
    FHeaderAlignTop: integer;
    FHeaderClass: TAnchorDockHeaderClass;
    FHeaderHint: string;
    FHeaderStyle: THeaderStyleName;
    FHeaderFlatten: boolean;
    FHeaderFilled: boolean;
    FHeaderHighlightFocused: boolean;
    FDockSitesCanBeMinimized: boolean;
    FIdleConnected: Boolean;
    FManagerClass: TAnchorDockManagerClass;
    FMainDockForm: TCustomForm;
    FMultiLinePages: boolean;
    FOnCreateControl: TADCreateControlEvent;
    FOnOptionsChanged: TNotifyEvent;
    FOnShowOptions: TADShowDockMasterOptionsEvent;
    FOptionsChangeStamp: int64;
    FPageAreaInPercent: integer;
    FPageClass: TAnchorDockPageClass;
    FPageControlClass: TAnchorDockPageControlClass;
    FQueueSimplify: Boolean;
    FRestoreLayouts: TAnchorDockRestoreLayouts;
    FRestoring: boolean;
    FScaleOnResize: boolean;
    FShowHeader: boolean;
    FShowHeaderCaption: boolean;
    FHideHeaderCaptionFloatingControl: boolean;
    FShowMenuItemShowHeader: boolean;
    FSiteClass: TAnchorDockHostSiteClass;
    FSplitterClass: TAnchorDockSplitterClass;
    FSplitterWidth: integer;
    FMapMinimizedControls: TMapMinimizedControls; // minimized controls and previous parent
    fNeedSimplify: TFPList; // list of TControl
    fNeedFree: TFPList; // list of TControl
    fSimplifying: boolean;
    FAllClosing: Boolean;
    fUpdateCount: integer;
    fDisabledAutosizing: TFPList; // list of TControl
    fTreeNameToDocker: TADNameToControl; // TAnchorDockHostSite, TAnchorDockSplitter or custom docksite
    fPopupMenu: TPopupMenu;
    // Used by RestoreLayout:
    WorkArea, SrcWorkArea: TRect;
    FOverlappingForm:TAnchorDockOverlappingForm;
    CurrentADHeaderStyle:TADHeaderStyle;
    FHeaderStyleName2ADHeaderStyle:THeaderStyleName2ADHeaderStylesMap;

    procedure FormFirstShow(Sender: TObject);
    function GetControls(Index: integer): TControl;
    function GetLocalizedHeaderHint: string;
    function GetMainDockForm: TCustomForm;
    procedure MarkCorrectlyLocatedControl(Tree: TAnchorDockLayoutTree);
    function CloseUnneededAndWronglyLocatedControls(Tree: TAnchorDockLayoutTree): boolean;
    function CreateNeededControls(Tree: TAnchorDockLayoutTree;
                DisableAutoSizing: boolean; ControlNames: TStrings): boolean;
    function GetNodeSite(Node: TAnchorDockLayoutTreeNode): TAnchorDockHostSite;
    procedure MapTreeToControls(Tree: TAnchorDockLayoutTree);
    function RestoreLayout(Tree: TAnchorDockLayoutTree; Scale: boolean): boolean;
    procedure ScreenFormAdded(Sender: TObject; Form: TCustomForm);
    procedure ScreenRemoveForm(Sender: TObject; Form: TCustomForm);
    procedure SetMainDockForm(AValue: TCustomForm);
    procedure SetMinimizedState(Tree: TAnchorDockLayoutTree);
    procedure UpdateHeaders;
    procedure SetNodeMinimizedState(ANode: TAnchorDockLayoutTreeNode);
    procedure EnableAllAutoSizing;
    procedure ClearLayoutProperties(AControl: TControl; NewAlign: TAlign = alClient);
    procedure PopupMenuPopup(Sender: TObject);
    procedure ChangeLockButtonClick(Sender: TObject);
    procedure RefreshFloatingWindowsOnTop;
    function ScaleBoundsRect(ARect: TRect; FromDPI, ToDPI: integer): TRect;
    function ScaleChildX(p: integer): integer;
    function ScaleChildY(p: integer): integer;
    function ScaleTopLvlX(p: integer): integer;
    function ScaleTopLvlY(p: integer): integer;
    procedure SetAllowDragging(AValue: boolean);
    procedure SetDockOutsideMargin(AValue: integer);
    procedure SetDockParentMargin(AValue: integer);
    procedure SetDragTreshold(AValue: integer);
    procedure SetHeaderHint(AValue: string);
    procedure SetHeaderStyle(AValue: THeaderStyleName);
    procedure SetPageAreaInPercent(AValue: integer);
    procedure SetScaleOnResize(AValue: boolean);

    procedure SetHeaderFlatten(AValue: boolean);
    procedure SetHeaderFilled(AValue: boolean);
    procedure SetHeaderHighlightFocused(AValue: boolean);
    procedure SetDockSitesCanBeMinimized(AValue: boolean);
    procedure SetFloatingWindowsOnTop(AValue: boolean);
    procedure SetMultiLinePages(AValue: boolean);

    procedure SetShowMenuItemShowHeader(AValue: boolean);
    procedure SetupSite(Site: TWinControl; ANode: TAnchorDockLayoutTreeNode;
      AParent: TWinControl);
    procedure ShowHeadersButtonClick(Sender: TObject);
    procedure OptionsClick(Sender: TObject);
    procedure SetIdleConnected(const AValue: Boolean);
    procedure SetQueueSimplify(const AValue: Boolean);
    procedure SetRestoring(const AValue: boolean);
    procedure OptionsChanged;
  protected
    function DoCreateControl(aName: string; DisableAutoSizing: boolean): TControl;
    procedure AutoSizeAllHeaders(EnableAutoSizing: boolean);
    procedure DisableControlAutoSizing(AControl: TControl);
    procedure InvalidateHeaders;
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
    procedure SetHeaderAlignLeft(const AValue: integer);
    procedure SetHeaderAlignTop(const AValue: integer);
    procedure SetShowHeader(AValue: boolean);
    procedure SetShowHeaderCaption(const AValue: boolean);
    procedure SetHideHeaderCaptionFloatingControl(const AValue: boolean);
    procedure SetSplitterWidth(const AValue: integer);
    procedure OnIdle(Sender: TObject; var Done: Boolean);
    procedure StartHideOverlappingTimer;
    procedure StopHideOverlappingTimer;
    procedure AsyncSimplify({%H-}Data: PtrInt);
  public
    procedure RegisterHeaderStyle(StyleName: THeaderStyleName; DrawProc:TDrawADHeaderProc; NeedDrawHeaderAfterText,NeedHighlightText: boolean);
    procedure ShowOverlappingForm;
    procedure HideOverlappingForm(Sender: TObject);
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    function FullRestoreLayout(Tree: TAnchorDockLayoutTree; Scale: Boolean): Boolean;
    function ControlCount: integer;
    property Controls[Index: integer]: TControl read GetControls;
    function IndexOfControl(const aName: string): integer;
    function FindControl(const aName: string): TControl;
    function IsMinimizedControl(AControl: TControl; out Site: TAnchorDockHostSite): Boolean;
    function IsSite(AControl: TControl): boolean;
    function IsAnchorSite(AControl: TControl): boolean;
    function IsCustomSite(AControl: TControl): boolean;
    function GetSite(AControl: TControl): TCustomForm;
    function GetAnchorSite(AControl: TControl): TAnchorDockHostSite;
    function GetControl(Site: TControl): TControl;
    function IsFloating(AControl: TControl): Boolean;
    function GetPopupMenu: TPopupMenu;
    function AddPopupMenuItem(AName, ACaption: string;
                    const OnClickEvent: TNotifyEvent; AParent: TMenuItem = nil): TMenuItem; virtual;
    function AddRemovePopupMenuItem(Add: boolean; AName, ACaption: string;
                    const OnClickEvent: TNotifyEvent; AParent: TMenuItem = nil): TMenuItem; virtual;

    // show / make a control dockable
    procedure MakeDockable(AControl: TControl; Show: boolean = true;
                           BringToFront: boolean = false;
                           AddDockHeader: boolean = true);
    procedure MakeDockSite(AForm: TCustomForm; Sites: TAnchors;
                           ResizePolicy: TADMResizePolicy;
                           AllowInside: boolean = false);
    procedure MakeDockPanel(APanel: TAnchorDockPanel;
                            ResizePolicy: TADMResizePolicy);
    procedure MakeVisible(AControl: TControl; SwitchPages: boolean);
    function ShowControl(ControlName: string; BringToFront: boolean = false): TControl;
    procedure CloseAll;

    // save/restore layouts
    procedure SaveLayoutToConfig(Config: TConfigStorage);
    procedure SaveMainLayoutToTree(LayoutTree: TAnchorDockLayoutTree);
    procedure SaveSiteLayoutToTree(AControl: TWinControl;
                                   LayoutTree: TAnchorDockLayoutTree);
    function CreateRestoreLayout(AControl: TControl): TAnchorDockRestoreLayout;
    function ConfigIsEmpty(Config: TConfigStorage): boolean;
    function LoadLayoutFromConfig(Config: TConfigStorage; Scale: Boolean): boolean;
    // layout information for restoring hidden forms
    property RestoreLayouts: TAnchorDockRestoreLayouts read FRestoreLayouts
                                                      write FRestoreLayouts;
    property Restoring: boolean read FRestoring write SetRestoring;
    property IdleConnected: Boolean read FIdleConnected write SetIdleConnected;
    procedure LoadSettingsFromConfig(Config: TConfigStorage);
    procedure SaveSettingsToConfig(Config: TConfigStorage);
    procedure LoadSettings(Settings: TAnchorDockSettings);
    procedure SaveSettings(Settings: TAnchorDockSettings);
    function SettingsAreEqual(Settings: TAnchorDockSettings): boolean;
    procedure ResetSplitters;

    // manual docking
    procedure ManualFloat(AControl: TControl);
    procedure ManualDock(SrcSite: TAnchorDockHostSite; TargetSite: TCustomForm;
                         Align: TAlign; TargetControl: TControl = nil); overload;
    procedure ManualDock(SrcSite: TAnchorDockHostSite; TargetPanel: TAnchorDockPanel;
                         Align: TAlign; TargetControl: TControl = nil); overload;
    function ManualEnlarge(Site: TAnchorDockHostSite; Side: TAnchorKind;
                         OnlyCheckIfPossible: boolean): boolean;

    // simplification/garbage collection
    procedure BeginUpdate;
    procedure EndUpdate;
    function IsReleasing(AControl: TControl): Boolean;
    procedure NeedSimplify(AControl: TControl);
    procedure NeedFree(AControl: TControl);
    procedure SimplifyPendingLayouts;
    function AutoFreedIfControlIsRemoved(AControl, RemovedControl: TControl): boolean;
    function CreateSite(NamePrefix: string = '';
                        DisableAutoSizing: boolean = true): TAnchorDockHostSite;
    function CreateSplitter(NamePrefix: string = ''): TAnchorDockSplitter;
    property QueueSimplify: Boolean read FQueueSimplify write SetQueueSimplify;

    property OnCreateControl: TADCreateControlEvent read FOnCreateControl write FOnCreateControl;

    // options
    property OnShowOptions: TADShowDockMasterOptionsEvent read FOnShowOptions write FOnShowOptions;
    property OnOptionsChanged: TNotifyEvent read FOnOptionsChanged write FOnOptionsChanged;
    property DragTreshold: integer read FDragTreshold write SetDragTreshold default 4;
    property DockOutsideMargin: integer read FDockOutsideMargin write SetDockOutsideMargin default 10; // max distance for outside mouse snapping
    property DockParentMargin: integer read FDockParentMargin write SetDockParentMargin default 10; // max distance for snap to parent
    property FloatingWindowsOnTop: boolean read FFloatingWindowsOnTop write SetFloatingWindowsOnTop default false;
    property PageAreaInPercent: integer read FPageAreaInPercent write SetPageAreaInPercent default 40; // size of inner mouse snapping area for page docking
    property ShowHeader: boolean read FShowHeader write SetShowHeader default true; // set to false to hide all headers
    property ShowMenuItemShowHeader: boolean read FShowMenuItemShowHeader write SetShowMenuItemShowHeader default false;
    property ShowHeaderCaption: boolean read FShowHeaderCaption write SetShowHeaderCaption default true; // set to false to remove the text in the headers
    property HideHeaderCaptionFloatingControl: boolean read FHideHeaderCaptionFloatingControl
                          write SetHideHeaderCaptionFloatingControl default true; // disables ShowHeaderCaption for floating controls
    property HeaderAlignTop: integer read FHeaderAlignTop write SetHeaderAlignTop default 80; // move header to top, when (width/height)*100<=HeaderAlignTop
    property HeaderAlignLeft: integer read FHeaderAlignLeft write SetHeaderAlignLeft default 120; // move header to left, when (width/height)*100>=HeaderAlignLeft
    property HeaderHint: string read FHeaderHint write SetHeaderHint; // if empty it uses resourcestring adrsDragAndDockC
    property HeaderStyle: THeaderStyleName read FHeaderStyle write SetHeaderStyle;
    property HeaderFlatten: boolean read FHeaderFlatten write SetHeaderFlatten default true;
    property HeaderFilled: boolean read FHeaderFilled write SetHeaderFilled default true;
    property HeaderHighlightFocused: boolean read FHeaderHighlightFocused write SetHeaderHighlightFocused default false;
    property DockSitesCanBeMinimized: boolean read FDockSitesCanBeMinimized write SetDockSitesCanBeMinimized default false;

    property SplitterWidth: integer read FSplitterWidth write SetSplitterWidth default 4;
    property ScaleOnResize: boolean read FScaleOnResize write SetScaleOnResize default true; // scale children when resizing a site
    property AllowDragging: boolean read FAllowDragging write SetAllowDragging default true;
    property MultiLinePages: boolean read FMultiLinePages write SetMultiLinePages default false;
    property OptionsChangeStamp: int64 read FOptionsChangeStamp;
    procedure IncreaseOptionsChangeStamp; inline;

    // for descendants
    property SplitterClass: TAnchorDockSplitterClass read FSplitterClass write FSplitterClass;
    property SiteClass: TAnchorDockHostSiteClass read FSiteClass write FSiteClass;
    property ManagerClass: TAnchorDockManagerClass read FManagerClass write FManagerClass;
    property HeaderClass: TAnchorDockHeaderClass read FHeaderClass write FHeaderClass;
    property PageControlClass: TAnchorDockPageControlClass read FPageControlClass write FPageControlClass;
    property PageClass: TAnchorDockPageClass read FPageClass write FPageClass;
    property HeaderStyleName2ADHeaderStyle:THeaderStyleName2ADHeaderStylesMap read FHeaderStyleName2ADHeaderStyle;

    // for floating windows on top
    property MainDockForm: TCustomForm read GetMainDockForm write SetMainDockForm;
  end;

var
  DockMaster: TAnchorDockMaster = nil;
  DockTimer: TTimer = nil;

  PreferredButtonWidth:integer=-1;
  PreferredButtonHeight:integer=-1;


const
  HardcodedButtonSize:integer=13;

function dbgs(SiteType: TAnchorDockHostSiteType): string; overload;


procedure CopyAnchorBounds(Source, Target: TControl);
procedure AnchorAndChangeBounds(AControl: TControl; Side: TAnchorKind;
                                Target: TControl);
function ControlsLeftTopOnScreen(AControl: TControl): TPoint;

type
  TAnchorControlsRect = array[TAnchorKind] of TControl;

function DockedControlIsVisible(Control: TControl): boolean;
function GetDockSplitter(Control: TControl; Side: TAnchorKind;
                         out Splitter: TAnchorDockSplitter): boolean;
function GetDockSplitterOrParent(Control: TControl; Side: TAnchorKind;
                                 out AnchorControl: TControl): boolean;
function CountAnchoredControls(Control: TControl; Side: TAnchorKind): Integer;
function NeighbourCanBeShrinked(EnlargeControl, Neighbour: TControl;
                                Side: TAnchorKind): boolean;
function ControlIsAnchoredIndirectly(StartControl: TControl; Side: TAnchorKind;
                                     DestControl: TControl): boolean;
procedure GetAnchorControlsRect(Control: TControl; out ARect: TAnchorControlsRect);
function GetEnclosingControlRect(ControlList: TFPlist;
                                 out ARect: TAnchorControlsRect): boolean;
function GetEnclosedControls(const ARect: TAnchorControlsRect): TFPList;

implementation

function dbgs(SiteType: TAnchorDockHostSiteType): string; overload;
begin
  case SiteType of
  adhstNone: Result:='None';
  adhstOneControl: Result:='OneControl';
  adhstLayout: Result:='Layout';
  adhstPages: Result:='Pages';
  else Result:='?';
  end;
end;

procedure CopyAnchorBounds(Source, Target: TControl);
var
  a: TAnchorKind;
begin
  Target.DisableAutoSizing{$IFDEF DebugDisableAutoSizing}('CopyAnchorBounds'){$ENDIF};
  try
    Target.BoundsRect:=Source.BoundsRect;
    Target.Anchors:=Source.Anchors;
    Target.Align:=Source.Align;
    for a:=low(TAnchorKind) to high(TAnchorKind) do
      Target.AnchorSide[a].Assign(Source.AnchorSide[a]);
  finally
    Target.EnableAutoSizing{$IFDEF DebugDisableAutoSizing}('CopyAnchorBounds'){$ENDIF};
  end;
end;

procedure AnchorAndChangeBounds(AControl: TControl; Side: TAnchorKind;
  Target: TControl);
begin
  if Target=AControl.Parent then begin
    AControl.AnchorParallel(Side,0,Target);
    case Side of
    akTop: AControl.Top:=0;
    akLeft: AControl.Left:=0;
    akRight: AControl.Width:=AControl.Parent.ClientWidth-AControl.Left;
    akBottom: AControl.Height:=AControl.Parent.ClientHeight-AControl.Top;
    end;
  end else begin
    AControl.AnchorToNeighbour(Side,0,Target);
    case Side of
    akTop: AControl.Top:=Target.Top+Target.Height;
    akLeft: AControl.Left:=Target.Left+Target.Width;
    akRight: AControl.Width:=Target.Left-AControl.Width;
    akBottom: AControl.Height:=Target.Top-AControl.Height;
    end;
  end;
end;

function ControlsLeftTopOnScreen(AControl: TControl): TPoint;
begin
  if AControl.Parent<>nil then begin
    Result:=AControl.Parent.ClientOrigin;
    inc(Result.X,AControl.Left);
    inc(Result.Y,AControl.Top);
  end else begin
    Result:=AControl.Parent.ClientOrigin;
  end;
end;

function DockedControlIsVisible(Control: TControl): boolean;
begin
  while Control<>nil do begin
    if (not Control.IsControlVisible)
    and (not (Control is TAnchorDockPage)) then
      exit(false);
    Control:=Control.Parent;
  end;
  Result:=true;
end;

function GetDockSplitter(Control: TControl; Side: TAnchorKind; out
  Splitter: TAnchorDockSplitter): boolean;
begin
  Result:=false;
  Splitter:=nil;
  if not Assigned(Control) or not (Side in Control.Anchors) then exit;
  Splitter:=TAnchorDockSplitter(Control.AnchorSide[Side].Control);
  if not (Splitter is TAnchorDockSplitter) then begin
    Splitter:=nil;
    exit;
  end;
  if Splitter.Parent<>Control.Parent then exit;
  Result:=true;
end;

function GetDockSplitterOrParent(Control: TControl; Side: TAnchorKind; out
  AnchorControl: TControl): boolean;
begin
  Result:=false;
  AnchorControl:=nil;
  if not (Side in Control.Anchors) then exit;
  AnchorControl:=Control.AnchorSide[Side].Control;
  if (AnchorControl is TAnchorDockSplitter)
  and (AnchorControl.Parent=Control.Parent)
  then
    Result:=true
  else if AnchorControl=Control.Parent then
    Result:=true;
end;

function CountAnchoredControls(Control: TControl; Side: TAnchorKind): Integer;
{ return the number of siblings, that are anchored on Side of Control
  For example: if Side=akLeft it will return the number of controls, which
  right side is anchored to the left of Control }
var
  i: Integer;
  Neighbour: TControl;
begin
  Result:=0;
  for i:=0 to Control.AnchoredControlCount-1 do begin
    Neighbour:=Control.AnchoredControls[i];
    if (OppositeAnchor[Side] in Neighbour.Anchors)
    and (Neighbour.AnchorSide[OppositeAnchor[Side]].Control=Control) then
      inc(Result);
  end;
end;

function CountAndReturnOnlyOneMinimizedAnchoredControls(Control: TControl; Side: TAnchorKind): TAnchorDockHostSite;
var
  i,Counter: Integer;
  Neighbour: TControl;
begin
  Counter:=0;
  for i:=0 to Control.AnchoredControlCount-1 do begin
    Neighbour:=Control.AnchoredControls[i];
    if Neighbour.Visible then
    if Neighbour is TAnchorDockHostSite then
    if (OppositeAnchor[Side] in Neighbour.Anchors)
    and (Neighbour.AnchorSide[OppositeAnchor[Side]].Control=Control) then begin
      inc(Counter);
      result:=TAnchorDockHostSite(Neighbour);
    end;
  end;
  if (Counter=1) and (result is TAnchorDockHostSite) and ((result as TAnchorDockHostSite).Minimized) then
  else
    result:=Nil;
end;

function ReturnAnchoredControlsSize(Control: TControl; Side: TAnchorKind): integer;
var
  i: Integer;
  Neighbour: TControl;
begin
  result:=high(integer);
  for i:=0 to Control.AnchoredControlCount-1 do begin
    Neighbour:=Control.AnchoredControls[i];
    if Neighbour.Visible then
    if Neighbour is TAnchorDockHostSite then
    if (OppositeAnchor[Side] in Neighbour.Anchors)
    and (Neighbour.AnchorSide[OppositeAnchor[Side]].Control=Control) then begin
      case Side of
   akTop,akBottom: if Neighbour.ClientHeight<result then
                     result:=Neighbour.ClientHeight;
   akLeft,akRight: if Neighbour.ClientWidth<result then
                     result:=Neighbour.ClientWidth;
      end;
    end;
  end;
end;

function NeighbourCanBeShrinked(EnlargeControl, Neighbour: TControl;
  Side: TAnchorKind): boolean;
{ returns true if Neighbour can be shrinked on the opposite side of Side
}
const
  MinControlSize = 20;
var
  Splitter: TAnchorDockSplitter;
begin
  Result:=false;
  if not GetDockSplitter(EnlargeControl,OppositeAnchor[Side],Splitter) then
    exit;
  case Side of
  akLeft: // check if left side of Neighbour can be moved
    Result:=Neighbour.Left+Neighbour.Width
        >EnlargeControl.Left+EnlargeControl.Width+Splitter.Width+MinControlSize;
  akRight: // check if right side of Neighbour can be moved
    Result:=Neighbour.Left+MinControlSize+Splitter.Width<EnlargeControl.Left;
  akTop: // check if top side of Neighbour can be moved
    Result:=Neighbour.Top+Neighbour.Height
       >EnlargeControl.Top+EnlargeControl.Height+Splitter.Height+MinControlSize;
  akBottom: // check if bottom side of Neighbour can be moved
    Result:=Neighbour.Top+MinControlSize+Splitter.Height<EnlargeControl.Top;
  end;
end;

function ControlIsAnchoredIndirectly(StartControl: TControl; Side: TAnchorKind;
  DestControl: TControl): boolean;
{ true if there is an Anchor way from StartControl to DestControl over Side.
  For example:

    +-+|+-+
    |A|||B|
    +-+|+-+

  A is akLeft to B.
  B is akRight to A.
  The splitter is akLeft to B.
  The splitter is akRight to A.
  All other are false.
}
var
  Checked: array of Boolean;
  Parent: TWinControl;

  function Check(ControlIndex: integer): boolean;
  var
    AControl: TControl;
    SideControl: TControl;
    i: Integer;
  begin
    if Checked[ControlIndex] then
      exit(false);
    Checked[ControlIndex]:=true;
    AControl:=Parent.Controls[ControlIndex];
    if AControl=DestControl then exit(true);

    if (Side in AControl.Anchors) then begin
      SideControl:=AControl.AnchorSide[Side].Control;
      if (SideControl<>nil) and Check(Parent.GetControlIndex(SideControl)) then
        exit(true);
    end;
    for i:=0 to AControl.AnchoredControlCount-1 do begin
      if Checked[i] then continue;
      SideControl:=AControl.AnchoredControls[i];
      if OppositeAnchor[Side] in SideControl.Anchors then begin
        if (SideControl.AnchorSide[OppositeAnchor[Side]].Control=AControl)
        and Check(i) then
          exit(true);
      end;
    end;
    Result:=false;
  end;

var
  i: Integer;
begin
  if (StartControl=nil) or (DestControl=nil)
  or (StartControl.Parent=nil)
  or (StartControl.Parent<>DestControl.Parent)
  or (StartControl=DestControl) then
    exit(false);
  Parent:=StartControl.Parent;
  SetLength(Checked,Parent.ControlCount);
  for i:=0 to length(Checked)-1 do Checked[i]:=false;
  Result:=Check(Parent.GetControlIndex(StartControl));
end;

procedure GetAnchorControlsRect(Control: TControl; out ARect: TAnchorControlsRect);
var
  a: TAnchorKind;
begin
  for a:=Low(TAnchorKind) to High(TAnchorKind) do
    ARect[a]:=Control.AnchorSide[a].Control;
end;

function GetEnclosingControlRect(ControlList: TFPlist; out
  ARect: TAnchorControlsRect): boolean;
{ ARect will be the minimum TAnchorControlsRect around the controls in the list
  returns true, if there is such a TAnchorControlsRect.

  The controls in ARect will either be the Parent or a TLazDockSplitter
}
var
  Parent: TWinControl;

  function ControlIsValidAnchor(Control: TControl; Side: TAnchorKind): boolean;
  var
    i: Integer;
  begin
    Result:=false;
    if (Control=ARect[Side]) then exit(true);// this allows Parent at the beginning

    if not (Control is TAnchorDockSplitter) then
      exit;// not a splitter
    if (TAnchorDockSplitter(Control).ResizeAnchor in [akLeft,akRight])
      <>(Side in [akLeft,akRight]) then
        exit;// wrong alignment
    if ControlList.IndexOf(Control)>=0 then
      exit;// is an inner control
    if ControlIsAnchoredIndirectly(Control,Side,ARect[Side]) then
      exit; // this anchor would be worse than the current maximum
    for i:=0 to ControlList.Count-1 do begin
      if not ControlIsAnchoredIndirectly(Control,Side,TControl(ControlList[i]))
      then begin
        // this anchor is not above (below, ...) the inner controls
        exit;
      end;
    end;
    Result:=true;
  end;

var
  TopIndex: Integer;
  TopControl: TControl;
  RightIndex: Integer;
  RightControl: TControl;
  BottomIndex: Integer;
  BottomControl: TControl;
  LeftIndex: Integer;
  LeftControl: TControl;
  Candidates: TFPList;
  i: Integer;
  a: TAnchorKind;
begin
  Result:=false;
  if (ControlList=nil) or (ControlList.Count=0) then exit;

  // get Parent
  Parent:=TControl(ControlList[0]).Parent;
  if Parent=nil then exit;
  for i:=0 to ControlList.Count-1 do
    if TControl(ControlList[i]).Parent<>Parent then exit;

  // set the default rect: the Parent
  Result:=true;
  for a:=Low(TAnchorKind) to High(TAnchorKind) do
    ARect[a]:=Parent;

  // find all possible Candidates
  Candidates:=TFPList.Create;
  try
    Candidates.Add(Parent);
    for i:=0 to Parent.ControlCount-1 do
      if Parent.Controls[i] is TAnchorDockSplitter then
        Candidates.Add(Parent.Controls[i]);

    // now check every possible rectangle
    // Note: four loops seems to be dog slow, but the checks
    //       avoid most possibilities early
    for TopIndex:=0 to Candidates.Count-1 do begin
      TopControl:=TControl(Candidates[TopIndex]);
      if not ControlIsValidAnchor(TopControl,akTop) then continue;

      for RightIndex:=0 to Candidates.Count-1 do begin
        RightControl:=TControl(Candidates[RightIndex]);
        if (TopControl.AnchorSide[akRight].Control<>RightControl)
        and (RightControl.AnchorSide[akTop].Control<>TopControl) then
          continue; // not touching / not a corner
        if not ControlIsValidAnchor(RightControl,akRight) then continue;

        for BottomIndex:=0 to Candidates.Count-1 do begin
          BottomControl:=TControl(Candidates[BottomIndex]);
          if (RightControl.AnchorSide[akBottom].Control<>BottomControl)
          and (BottomControl.AnchorSide[akRight].Control<>RightControl) then
            continue; // not touching / not a corner
          if not ControlIsValidAnchor(BottomControl,akBottom) then continue;

          for LeftIndex:=0 to Candidates.Count-1 do begin
            LeftControl:=TControl(Candidates[LeftIndex]);
            if (BottomControl.AnchorSide[akLeft].Control<>LeftControl)
            and (LeftControl.AnchorSide[akBottom].Control<>BottomControl) then
              continue; // not touching / not a corner
            if (TopControl.AnchorSide[akLeft].Control<>LeftControl)
            and (LeftControl.AnchorSide[akTop].Control<>LeftControl) then
              continue; // not touching / not a corner
            if not ControlIsValidAnchor(LeftControl,akLeft) then continue;

            // found a better rectangle
            ARect[akLeft]  :=LeftControl;
            ARect[akRight] :=RightControl;
            ARect[akTop]   :=TopControl;
            ARect[akBottom]:=BottomControl;
          end;
        end;
      end;
    end;
  finally
    Candidates.Free;
  end;
end;

function GetEnclosedControls(const ARect: TAnchorControlsRect): TFPList;
{ return a list of all controls bounded by the anchors in ARect }
var
  Parent: TWinControl;

  procedure Fill(AControl: TControl);
  var
    a: TAnchorKind;
    SideControl: TControl;
    i: Integer;
  begin
    if AControl=nil then exit;
    if AControl=Parent then exit;// do not add Parent
    for a:=Low(TAnchorKind) to High(TAnchorKind) do
      if ARect[a]=AControl then exit;// do not add boundary

    if Result.IndexOf(AControl)>=0 then exit;// already added
    Result.Add(AControl);

    for a:=Low(TAnchorKind) to High(TAnchorKind) do
      Fill(AControl.AnchorSide[a].Control);
    for i:=0 to Parent.ControlCount-1 do begin
      SideControl:=Parent.Controls[i];
      for a:=Low(TAnchorKind) to High(TAnchorKind) do
        if SideControl.AnchorSide[a].Control=AControl then
          Fill(SideControl);
    end;
  end;

var
  i: Integer;
  AControl: TControl;
  LeftTopControl: TControl;
begin
  Result:=TFPList.Create;

  // find the Parent
  if (ARect[akLeft]=ARect[akRight]) and (ARect[akLeft] is TWinControl) then
    Parent:=TWinControl(ARect[akLeft])
  else
    Parent:=ARect[akLeft].Parent;

  // find the left, top most control
  for i:=0 to Parent.ControlCount-1 do begin
    AControl:=Parent.Controls[i];
    if (AControl.AnchorSide[akLeft].Control=ARect[akLeft])
    and (AControl.AnchorSide[akTop].Control=ARect[akTop]) then begin
      LeftTopControl:=AControl;
      break;
    end;
  end;
  if Result.Count=0 then exit;

  // use flood fill to find the rest
  Fill(LeftTopControl);
end;

{ TAnchorDockSettings }

procedure TAnchorDockSettings.SetAllowDragging(AValue: boolean);
begin
  if FAllowDragging=AValue then Exit;
  FAllowDragging:=AValue;
  IncreaseChangeStamp;
end;

procedure TAnchorDockSettings.SetDockOutsideMargin(AValue: integer);
begin
  if FDockOutsideMargin=AValue then Exit;
  FDockOutsideMargin:=AValue;
  IncreaseChangeStamp;
end;

procedure TAnchorDockSettings.SetDockParentMargin(AValue: integer);
begin
  if FDockParentMargin=AValue then Exit;
  FDockParentMargin:=AValue;
  IncreaseChangeStamp;
end;

procedure TAnchorDockSettings.SetDragTreshold(AValue: integer);
begin
  if FDragTreshold=AValue then Exit;
  FDragTreshold:=AValue;
  IncreaseChangeStamp;
end;

procedure TAnchorDockSettings.SetFloatingWindowsOnTop(AValue: boolean);
begin
  if FFloatingWindowsOnTop=AValue then Exit;
  FFloatingWindowsOnTop:=AValue;
  IncreaseChangeStamp;
end;

procedure TAnchorDockSettings.SetHeaderAlignLeft(AValue: integer);
begin
  if FHeaderAlignLeft=AValue then Exit;
  FHeaderAlignLeft:=AValue;
  IncreaseChangeStamp;
end;

procedure TAnchorDockSettings.SetHeaderAlignTop(AValue: integer);
begin
  if FHeaderAlignTop=AValue then Exit;
  FHeaderAlignTop:=AValue;
  IncreaseChangeStamp;
end;

procedure TAnchorDockSettings.SetHeaderHint(AValue: string);
begin
  if FHeaderHint=AValue then Exit;
  FHeaderHint:=AValue;
  IncreaseChangeStamp;
end;

procedure TAnchorDockSettings.SetHeaderStyle(AValue: THeaderStyleName);
begin
  if FHeaderStyle=AValue then Exit;

  // the next two lines can be removed in Lazarus 2.4.0 upwards - there should no old
  // environmentoptions.xml be out there anymore - see https://bugs.freepascal.org/view.php?id=38960
  if AValue='Themed caption' then AValue:='ThemedCaption';
  if AValue='Themed button' then AValue:='ThemedButton';

  FHeaderStyle:=AValue;
  IncreaseChangeStamp;
end;

procedure TAnchorDockSettings.SetHideHeaderCaptionFloatingControl(
  AValue: boolean);
begin
  if FHideHeaderCaptionFloatingControl=AValue then Exit;
  FHideHeaderCaptionFloatingControl:=AValue;
  IncreaseChangeStamp;
end;

procedure TAnchorDockSettings.SetMultiLinePages(AValue: boolean);
begin
  if FMultiLinePages = AValue then Exit;
  FMultiLinePages := AValue;
  IncreaseChangeStamp;
end;

procedure TAnchorDockSettings.SetPageAreaInPercent(AValue: integer);
begin
  if FPageAreaInPercent=AValue then Exit;
  FPageAreaInPercent:=AValue;
  IncreaseChangeStamp;
end;

procedure TAnchorDockSettings.SetScaleOnResize(AValue: boolean);
begin
  if FScaleOnResize=AValue then Exit;
  FScaleOnResize:=AValue;
  IncreaseChangeStamp;
end;

procedure TAnchorDockSettings.SetHeaderFlatten(AValue: boolean);
begin
  if FHeaderFlatten=AValue then Exit;
  FHeaderFlatten:=AValue;
  IncreaseChangeStamp;
end;

procedure TAnchorDockSettings.SetHeaderFilled(AValue: boolean);
begin
  if FHeaderFilled=AValue then Exit;
  FHeaderFilled:=AValue;
  IncreaseChangeStamp;
end;

procedure TAnchorDockSettings.SetHeaderHighlightFocused(AValue: boolean);
begin
  if FHeaderHighlightFocused=AValue then Exit;
  FHeaderHighlightFocused:=AValue;
  IncreaseChangeStamp;
end;

procedure TAnchorDockSettings.SetShowHeader(AValue: boolean);
begin
  if FShowHeader=AValue then Exit;
  FShowHeader:=AValue;
  IncreaseChangeStamp;
end;

procedure TAnchorDockSettings.SetShowHeaderCaption(AValue: boolean);
begin
  if FShowHeaderCaption=AValue then Exit;
  FShowHeaderCaption:=AValue;
  IncreaseChangeStamp;
end;

procedure TAnchorDockSettings.SetSplitterWidth(AValue: integer);
begin
  if FSplitterWidth=AValue then Exit;
  FSplitterWidth:=AValue;
  IncreaseChangeStamp;
end;

procedure TAnchorDockSettings.SetDockSitesCanBeMinimized(AValue: boolean);
begin
  if FDockSitesCanBeMinimized=AValue then Exit;
  FDockSitesCanBeMinimized:=AValue;
  IncreaseChangeStamp;
end;

procedure TAnchorDockSettings.Assign(Source: TAnchorDockSettings);
begin
  FChangeStamp := Source.FChangeStamp;

  FAllowDragging                    := Source.FAllowDragging;
  FDockOutsideMargin                := Source.FDockOutsideMargin;
  FDockParentMargin                 := Source.FDockParentMargin;
  FDockSitesCanBeMinimized          := Source.FDockSitesCanBeMinimized;
  FDragTreshold                     := Source.FDragTreshold;
  FFloatingWindowsOnTop             := Source.FFloatingWindowsOnTop;
  FHeaderAlignLeft                  := Source.FHeaderAlignLeft;
  FHeaderAlignTop                   := Source.FHeaderAlignTop;
  FHeaderFilled                     := Source.FHeaderFilled;
  FHeaderFlatten                    := Source.FHeaderFlatten;
  FHeaderHighlightFocused           := Source.FHeaderHighlightFocused;
  FHeaderHint                       := Source.FHeaderHint;
  FHeaderStyle                      := Source.FHeaderStyle;
  FHideHeaderCaptionFloatingControl := Source.FHideHeaderCaptionFloatingControl;
  FMultiLinePages                   := Source.FMultiLinePages;
  FPageAreaInPercent                := Source.FPageAreaInPercent;
  FScaleOnResize                    := Source.FScaleOnResize;
  FShowHeader                       := Source.FShowHeader;
  FShowHeaderCaption                := Source.FShowHeaderCaption;
  FSplitterWidth                    := Source.FSplitterWidth;
end;

procedure TAnchorDockSettings.IncreaseChangeStamp;
begin
  LUIncreaseChangeStamp(fChangeStamp);
end;

procedure TAnchorDockSettings.LoadFromConfig(Config: TConfigStorage);
begin
  Config.AppendBasePath('Settings/');
  AllowDragging                    := Config.GetValue('AllowDragging',true);
  DockOutsideMargin                := Config.GetValue('DockOutsideMargin',10);
  DockParentMargin                 := Config.GetValue('DockParentMargin',10);
  DockSitesCanBeMinimized          := Config.GetValue('DockSitesCanBeMinimized',False);
  DragTreshold                     := Config.GetValue('DragThreshold',4);
  FloatingWindowsOnTop             := Config.GetValue('FloatingWindowsOnTop',false);
  HeaderAlignLeft                  := Config.GetValue('HeaderAlignLeft',120);
  HeaderAlignTop                   := Config.GetValue('HeaderAlignTop',80);
  HeaderFilled                     := Config.GetValue('HeaderFilled',true);
  HeaderFlatten                    := Config.GetValue('HeaderFlatten',true);
  HeaderHighlightFocused           := Config.GetValue('HeaderHighlightFocused',False);
  HeaderStyle                      := Config.GetValue('HeaderStyle','Frame3D');
  HideHeaderCaptionFloatingControl := Config.GetValue('HideHeaderCaptionFloatingControl',true);
  MultiLinePages                   := Config.GetValue('MultiLinePages',false);
  PageAreaInPercent                := Config.GetValue('PageAreaInPercent',40);
  ScaleOnResize                    := Config.GetValue('ScaleOnResize',true);
  ShowHeader                       := Config.GetValue('ShowHeader',true);
  ShowHeaderCaption                := Config.GetValue('ShowHeaderCaption',true);
  SplitterWidth                    := Config.GetValue('SplitterWidth',4);
  Config.UndoAppendBasePath;
end;

procedure TAnchorDockSettings.SaveToConfig(Path: string; Config: TRttiXMLConfig);
begin
  Config.SetDeleteValue(Path+'AllowDragging',AllowDragging,true);
  Config.SetDeleteValue(Path+'DockOutsideMargin',DockOutsideMargin,10);
  Config.SetDeleteValue(Path+'DockParentMargin',DockParentMargin,10);
  Config.SetDeleteValue(Path+'DockSitesCanBeMinimized',DockSitesCanBeMinimized,False);
  Config.SetDeleteValue(Path+'DragThreshold',DragTreshold,4);
  Config.SetDeleteValue(Path+'FloatingWindowsOnTop',FloatingWindowsOnTop,false);
  Config.SetDeleteValue(Path+'HeaderAlignLeft',HeaderAlignLeft,120);
  Config.SetDeleteValue(Path+'HeaderAlignTop',HeaderAlignTop,80);
  Config.SetDeleteValue(Path+'HeaderFilled',HeaderFilled,true);
  Config.SetDeleteValue(Path+'HeaderFlatten',HeaderFlatten,true);
  Config.SetDeleteValue(Path+'HeaderHighlightFocused',HeaderHighlightFocused,False);
  Config.SetDeleteValue(Path+'HeaderStyle',HeaderStyle,'Frame3D');
  Config.SetDeleteValue(Path+'HideHeaderCaptionFloatingControl',HideHeaderCaptionFloatingControl,true);
  Config.SetDeleteValue(Path+'MultiLinePages',MultiLinePages,false);
  Config.SetDeleteValue(Path+'PageAreaInPercent',PageAreaInPercent,40);
  Config.SetDeleteValue(Path+'ScaleOnResize',ScaleOnResize,true);
  Config.SetDeleteValue(Path+'ShowHeader',ShowHeader,true);
  Config.SetDeleteValue(Path+'ShowHeaderCaption',ShowHeaderCaption,true);
  Config.SetDeleteValue(Path+'SplitterWidth',SplitterWidth,4);
end;

procedure TAnchorDockSettings.SaveToConfig(Config: TConfigStorage);
begin
  Config.AppendBasePath('Settings/');
  Config.SetDeleteValue('AllowDragging',AllowDragging,true);
  Config.SetDeleteValue('DockOutsideMargin',DockOutsideMargin,10);
  Config.SetDeleteValue('DockParentMargin',DockParentMargin,10);
  Config.SetDeleteValue('DockSitesCanBeMinimized',DockSitesCanBeMinimized,False);
  Config.SetDeleteValue('DragThreshold',DragTreshold,4);
  Config.SetDeleteValue('FloatingWindowsOnTop',FloatingWindowsOnTop,false);
  Config.SetDeleteValue('HeaderAlignLeft',HeaderAlignLeft,120);
  Config.SetDeleteValue('HeaderAlignTop',HeaderAlignTop,80);
  Config.SetDeleteValue('HeaderFilled',HeaderFilled,true);
  Config.SetDeleteValue('HeaderFlatten',HeaderFlatten,true);
  Config.SetDeleteValue('HeaderHighlightFocused',HeaderHighlightFocused,False);
  Config.SetDeleteValue('HeaderStyle',HeaderStyle,'Frame3D');
  Config.SetDeleteValue('HideHeaderCaptionFloatingControl',HideHeaderCaptionFloatingControl,true);
  Config.SetDeleteValue('MultiLinePages',MultiLinePages,false);
  Config.SetDeleteValue('PageAreaInPercent',PageAreaInPercent,40);
  Config.SetDeleteValue('ScaleOnResize',ScaleOnResize,true);
  Config.SetDeleteValue('ShowHeader',ShowHeader,true);
  Config.SetDeleteValue('ShowHeaderCaption',ShowHeaderCaption,true);
  Config.SetDeleteValue('SplitterWidth',SplitterWidth,4);
  Config.UndoAppendBasePath;
end;

function TAnchorDockSettings.IsEqual(Settings: TAnchorDockSettings): boolean;
begin
  Result:=(AllowDragging=Settings.AllowDragging)
      and (DockOutsideMargin=Settings.DockOutsideMargin)
      and (DockParentMargin=Settings.DockParentMargin)
      and (DockSitesCanBeMinimized=Settings.DockSitesCanBeMinimized)
      and (DragTreshold=Settings.DragTreshold)
      and (FloatingWindowsOnTop=Settings.FloatingWindowsOnTop)
      and (HeaderAlignLeft=Settings.HeaderAlignLeft)
      and (HeaderAlignTop=Settings.HeaderAlignTop)
      and (HeaderFilled=Settings.HeaderFilled)
      and (HeaderFlatten=Settings.HeaderFlatten)
      and (HeaderHighlightFocused=Settings.HeaderHighlightFocused)
      and (HeaderHint=Settings.HeaderHint)
      and (HeaderStyle=Settings.HeaderStyle)
      and (HideHeaderCaptionFloatingControl=Settings.HideHeaderCaptionFloatingControl)
      and (MultiLinePages=Settings.MultiLinePages)
      and (PageAreaInPercent=Settings.PageAreaInPercent)
      and (ScaleOnResize=Settings.ScaleOnResize)
      and (ShowHeader=Settings.ShowHeader)
      and (ShowHeaderCaption=Settings.ShowHeaderCaption)
      and (SplitterWidth=Settings.SplitterWidth)
      ;
end;

procedure TAnchorDockSettings.LoadFromConfig(Path: string;
  Config: TRttiXMLConfig);
begin
  AllowDragging                    := Config.GetValue(Path+'AllowDragging',true);
  DockOutsideMargin                := Config.GetValue(Path+'DockOutsideMargin',10);
  DockParentMargin                 := Config.GetValue(Path+'DockParentMargin',10);
  DockSitesCanBeMinimized          := Config.GetValue(Path+'DockSitesCanBeMinimized',false);
  DragTreshold                     := Config.GetValue(Path+'DragThreshold',4);
  FloatingWindowsOnTop             := Config.GetValue(Path+'FloatingWindowsOnTop',false);  ;
  HeaderAlignLeft                  := Config.GetValue(Path+'HeaderAlignLeft',120);
  HeaderAlignTop                   := Config.GetValue(Path+'HeaderAlignTop',80);
  HeaderFilled                     := Config.GetValue(Path+'HeaderFilled',true);
  HeaderFlatten                    := Config.GetValue(Path+'HeaderFlatten',true);
  HeaderHighlightFocused           := Config.GetValue(Path+'HeaderHighlightFocused',false);
  HeaderStyle                      := Config.GetValue(Path+'HeaderStyle','Frame3D');
  HideHeaderCaptionFloatingControl := Config.GetValue(Path+'HideHeaderCaptionFloatingControl',true);
  MultiLinePages                   := Config.GetValue(Path+'MultiLinePages',false);
  PageAreaInPercent                := Config.GetValue(Path+'PageAreaInPercent',40);
  ScaleOnResize                    := Config.GetValue(Path+'ScaleOnResize',true);
  ShowHeader                       := Config.GetValue(Path+'ShowHeader',true);
  ShowHeaderCaption                := Config.GetValue(Path+'ShowHeaderCaption',true);
  SplitterWidth                    := Config.GetValue(Path+'SplitterWidth',4);
end;

{ TStyleOfForm }

class operator TStyleOfForm. = (Item1, Item2: TStyleOfForm): Boolean;
begin
  Result := (Item1.Form = Item2.Form) and
            (Item1.FormStyle = Item2.FormStyle);
end;

{ TFormStyles }

procedure TFormStyles.AddForm(const AForm: TCustomForm);
var
  AStyleOfForm: TStyleOfForm;
begin
  if not Assigned(AForm) then Exit;
  if IndexOfForm(AForm) >= 0 then Exit;
  AStyleOfForm.Form := AForm;
  AStyleOfForm.FormStyle := AForm.FormStyle;
  Add(AStyleOfForm);
end;

function TFormStyles.IndexOfForm(const AForm: TCustomForm): Integer;
var
  i: Integer;
begin
  for i := 0 to Count - 1 do
    if Self[i].Form = AForm then Exit(i);
  Result := -1;
end;

procedure TFormStyles.RemoveForm(const AForm: TCustomForm);
var
  AIndex: Integer;
begin
  AIndex := IndexOfForm(AForm);
  if AIndex < 0 then Exit;
  Delete(AIndex);
end;

{ TAnchorDockMaster }

function TAnchorDockMaster.GetControls(Index: integer): TControl;
begin
  Result:=TControl(FControls[Index]);
end;

procedure TAnchorDockMaster.FormFirstShow(Sender: TObject);
var
  AForm: TCustomForm absolute Sender;
  IsMainDockForm: Boolean;
begin
  if not (Sender is TCustomForm) then Exit;
  if AForm.FormStyle in fsAllStayOnTop then Exit;
  if not FloatingWindowsOnTop then Exit;
  IsMainDockForm := (AForm = MainDockForm)
                or (AForm.IsParentOf(MainDockForm))
                or (GetParentForm(AForm) = MainDockForm);
  if IsMainDockForm then
    AForm.FormStyle := fsNormal
  else
    AForm.FormStyle := fsStayOnTop;
end;

function TAnchorDockMaster.GetLocalizedHeaderHint: string;
begin
  if HeaderHint<>'' then
    Result:=HeaderHint
  else
    Result:=adrsDragAndDockC;
end;

function TAnchorDockMaster.GetMainDockForm: TCustomForm;
begin
  if not Assigned(FMainDockForm) then
    FMainDockForm := Application.MainForm;
  // Workaround: if FloatingWindowsOnTop is loaded on MainForm.Create
  // Application.MainForm is not set now, but already in Screen.Forms
  // see https://bugs.freepascal.org/view.php?id=19272
  if not Assigned(FMainDockForm) and (Screen.FormCount > 0) then
    FMainDockForm := Screen.Forms[0];
  Result := FMainDockForm;
end;

procedure TAnchorDockMaster.SetHeaderAlignLeft(const AValue: integer);
begin
  if FHeaderAlignLeft=AValue then exit;
  FHeaderAlignLeft:=AValue;
  FHeaderAlignTop:=Min(FHeaderAlignLeft-1,FHeaderAlignTop);
  OptionsChanged;
end;

procedure TAnchorDockMaster.SetHeaderAlignTop(const AValue: integer);
begin
  if FHeaderAlignTop=AValue then exit;
  FHeaderAlignTop:=AValue;
  FHeaderAlignLeft:=Max(FHeaderAlignTop+1,FHeaderAlignLeft);
  OptionsChanged;
end;

procedure TAnchorDockMaster.MarkCorrectlyLocatedControl(Tree: TAnchorDockLayoutTree);
var
  Counter:integer;

  function GetRealParent(Node:TAnchorDockLayoutTreeNode):TAnchorDockLayoutTreeNode;
  begin
    result := Node;
    while Assigned(result.Parent) do begin
      result := result.Parent;
      fTreeNameToDocker[Node.Name];
      if result.NodeType in [adltnControl,adltnCustomSite] then exit
    end;
  end;

  function GetDockParent(Control: TControl): TControl;
  begin
    Control := Control.Parent;
    while (Control <> nil) and (Control.Parent <> nil) do
    begin
      if not (Control is TAnchorDockHostSite) then
        Break;
      Control := Control.Parent;
    end;
    Result := Control;
  end;

  procedure RealChildrenCount(AWinControl:twincontrol;var realsubcontrolcoun:integer);
  var
    i:integer;
    ACountedControl:tcontrol;
  begin
     for i:=0 to AWinControl.ControlCount-1 do
       begin
         ACountedControl:=AWinControl.Controls[i];
         if not (ACountedControl is TAnchorDockHostSite) then
         if not (ACountedControl is TAnchorDockHeader) then
         if not (ACountedControl is TAnchorDockPageControl) then
         if ACountedControl.IsVisible then
           inc(realsubcontrolcoun);
         if ACountedControl is TAnchorDockHostSite then
         if ACountedControl.IsVisible then
           RealChildrenCount(ACountedControl as TWinControl, realsubcontrolcoun);
       end;
  end;

  function CheckNode(Node: TAnchorDockLayoutTreeNode; var ControlsCount: integer):TADLControlLocation;
  var
    i: Integer;
    AControl,AParent: TControl;
    SubControlsCount,realsubcontrolcoun: integer;
  begin
    if Node.IsSplitter then begin
      inc(ControlsCount);
      exit(adlclCorrect);
    end
    else if Node=Tree.Root then begin
      result:=adlclCorrect;
      AControl:=nil;
      AParent:=nil;
    end
    else begin
      AControl:=FindControl(Node.Name);
      AParent:=FindControl(GetRealParent(Node).Name);
      if Node.NodeType=adltnLayout then result:=adlclCorrect
      else if AControl is TAnchorDockPanel then result:=adlclCorrect
      else if AControl=nil then result:=adlclWrongly
      else if GetDockParent(AControl)<>AParent then result:=adlclWrongly
      else
      begin
      end;
    end;
    if AControl<>nil then
    if not (AControl is TAnchorDockHostSite) then
     inc(ControlsCount);
    if result=adlclWrongly then exit;
    if AControl=nil then AControl:=AParent;
    SubControlsCount:=0;
    for i:=0 to Node.Count-1 do
    begin
      result:=CheckNode(Node[i],SubControlsCount);
      if result=adlclWrongly then exit;
    end;
    realsubcontrolcoun:=0;
    if (AControl is TAnchorDockHostSite) or (AControl is TAnchorDockPanel) then
    begin
       RealChildrenCount(AControl as TWinControl,realsubcontrolcoun);
       if SubControlsCount<>realsubcontrolcoun then Exit(adlclWrongly);
    end;
    ControlsCount:=ControlsCount+SubControlsCount;
    if result=adlclWrongly then exit;
    for i:=0 to Node.Count-1 do
    begin
      Node[i].ControlLocation:=adlclCorrect;
    end;
  end;

begin
  //We need compare dock tree and fact controls placement
  //and mark controls which location is coincides with tree
  //these controls can be not closrd in CloseUnneededAndWronglyLocatedControls
  Counter:=0;
  Tree.Root.ControlLocation:=CheckNode(Tree.Root,Counter);
end;

function TAnchorDockMaster.CloseUnneededAndWronglyLocatedControls(Tree: TAnchorDockLayoutTree
  ): boolean;

  function GetParentAnchorDockPageControl(thisControl: TControl):TAnchorDockPageControl;
  begin
    while thisControl<>nil do
    begin
      if thisControl is TAnchorDockPageControl then
        exit(thisControl as TAnchorDockPageControl);
      thisControl:=thisControl.Parent;
    end;
    result:=nil;
  end;

var
  i: Integer;
  AControl: TControl;
  TreeNodeControl: TAnchorDockLayoutTreeNode;
  ParentAnchorDockPageControl:TAnchorDockPageControl;
begin
  i:=ControlCount-1;
  while i>=0 do begin
    AControl:=Controls[i];
    TreeNodeControl:=Tree.Root.FindChildNode(AControl.Name,true);
    if DockedControlIsVisible(AControl)
    and (Application.MainForm<>AControl)
    and (not(AControl is TAnchorDockPanel))
    and ((Tree.Root.FindChildNode(AControl.Name,true)=nil)
    or (TreeNodeControl.ControlLocation=adlclWrongly)) then begin
      ParentAnchorDockPageControl:=GetParentAnchorDockPageControl(AControl);
      DisableControlAutoSizing(AControl);
      // AControl is currently on a visible site, but not in the Tree
      // => close site
      if AControl.HostDockSite <> nil then
      begin
        {$IFDEF VerboseAnchorDocking}
        debugln(['TAnchorDockMaster.CloseUnneededControls Control=',DbgSName(AControl),' Site=',AControl.HostDockSite.Name]);
        {$ENDIF}
        if AControl.HostDockSite is TAnchorDockHostSite then begin
          if not TAnchorDockHostSite(AControl.HostDockSite).CloseSite then begin
            if FControls.IndexOf(AControl)<0 then
              AControl:=nil;
            {$IFDEF VerboseAnchorDocking}
            debugln(['TAnchorDockMaster.CloseUnneededControls CloseSite failed Control=',DbgSName(AControl)]);
            {$ENDIF}
            exit(false);
          end;
        end;
      end;
      if FControls.IndexOf(AControl)>=0 then begin
        // the control is still there
        if AControl.HostDockSite<>nil then begin
          AControl.HostDockSite.Visible:=false;
          AControl.HostDockSite.Parent:=nil;
        end else begin
          AControl.Visible:=False;
          AControl.Parent:=nil;
        end;
      end;
      if ParentAnchorDockPageControl<>nil then
        if ParentAnchorDockPageControl.Parent<>nil then
          ParentAnchorDockPageControl.Parent.Free;
    end;
    i:=Min(i,ControlCount)-1;
  end;
  Result:=true;
end;

function TAnchorDockMaster.CreateNeededControls(Tree: TAnchorDockLayoutTree;
  DisableAutoSizing: boolean; ControlNames: TStrings): boolean;

  procedure CreateControlsForNode(Node: TAnchorDockLayoutTreeNode);
  var
    i: Integer;
    AControl: TControl;
  begin
    if (Node.NodeType in [adltnControl,adltnCustomSite])
    and (Node.Name<>'') then begin
      AControl:=FindControl(Node.Name);
      if AControl<>nil then begin
        //debugln(['CreateControlsForNode ',Node.Name,' already exists']);
        if DisableAutoSizing then
          DisableControlAutoSizing(AControl);
      end else begin
        //debugln(['CreateControlsForNode ',Node.Name,' needs creation']);
        AControl:=DoCreateControl(Node.Name,true);
        if AControl<>nil then begin
          try
            if DisableAutoSizing and (fDisabledAutosizing.IndexOf(AControl)<0)
            then begin
              fDisabledAutosizing.Add(AControl);
              AControl.FreeNotification(Self);
            end;
            if Node.NodeType=adltnControl then
              MakeDockable(AControl,false)
            else if not IsCustomSite(AControl) then
              raise EAnchorDockLayoutError.Create('not a docksite: '+DbgSName(AControl));
          finally
            if not DisableAutoSizing then
              AControl.EnableAutoSizing{$IFDEF DebugDisableAutoSizing}(ADAutoSizingReason){$ENDIF};
          end;
        end else begin
          debugln(['CreateControlsForNode ',Node.Name,' failed to create']);
        end;
      end;
      if AControl<>nil then
        ControlNames.Add(AControl.Name);
    end;
    for i:=0 to Node.Count-1 do
      CreateControlsForNode(Node[i]);
  end;

begin
  Result:=false;
  CreateControlsForNode(Tree.Root);
  Result:=true;
end;

procedure TAnchorDockMaster.MapTreeToControls(Tree: TAnchorDockLayoutTree);

  procedure MapHostDockSites(Node: TAnchorDockLayoutTreeNode);
  // map in TreeNameToDocker each control name to its HostDockSite or custom dock site
  var
    i: Integer;
    AControl: TControl;
  begin
    if Node.IsSplitter then exit;
    if (Node.NodeType=adltnControl) then begin
      AControl:=FindControl(Node.Name);
      if (AControl<>nil) and (AControl.HostDockSite is TAnchorDockHostSite) then
        fTreeNameToDocker[Node.Name]:=AControl.HostDockSite;
      // ignore kids
      exit;
    end;
    if (Node.NodeType=adltnCustomSite) then begin
      AControl:=FindControl(Node.Name);
      if IsCustomSite(AControl) or (AControl is TAnchorDockPanel) then
        fTreeNameToDocker[Node.Name]:=AControl;
    end;
    for i:=0 to Node.Count-1 do
      MapHostDockSites(Node[i]); // recursive
  end;

  procedure MapTopLevelSites(Node: TAnchorDockLayoutTreeNode);
  // map in TreeNameToDocker each RootWindow node name to a site with a
  // corresponding control
  // For example: if there is control on a complex site (SiteA), and the control
  //    has a node in the Tree, then the root node of the tree node is mapped to
  //    the SiteA. This way the corresponding root forms are kept which reduces
  //    flickering.

    function FindMappedControl(ChildNode: TAnchorDockLayoutTreeNode): TCustomForm;
    var
      i: Integer;
    begin
      if ChildNode.NodeType in [adltnControl,adltnCustomSite] then
        Result:=TCustomForm(fTreeNameToDocker[ChildNode.Name])
      else
        for i:=0 to ChildNode.Count-1 do begin
          Result:=FindMappedControl(ChildNode[i]); // search recursive
          if Result<>nil then exit;
        end;
    end;

  var
    i: Integer;
    RootSite: TCustomForm;
    Site: TCustomForm;
  begin
    if Node.IsSplitter then exit;
    if Node.IsRootWindow then begin
      if Node.Name='' then exit;
      if Node.NodeType=adltnControl then exit;
      // Node is a complex site
      if fTreeNameToDocker[Node.Name]<>nil then exit;
      // and not yet mapped to a site
      Site:=FindMappedControl(Node);
      if Site=nil then exit;
      // and there is sub node mapped to a site (anchor or custom)
      RootSite:=GetParentForm(Site);
      if not (RootSite is TAnchorDockHostSite) then exit;
      // and the mapped site has a root site
      if fTreeNameToDocker.ControlToName(RootSite)<>'' then exit;
      // and the root site is not yet mapped
      // => map the root node to the root site
      fTreeNameToDocker[Node.Name]:=RootSite;
    end else
      for i:=0 to Node.Count-1 do
        MapTopLevelSites(Node[i]); // recursive
  end;

  procedure MapBottomUp(Node: TAnchorDockLayoutTreeNode);
  { map the other nodes to existing sites
    The heuristic works like this:
      if a child node was mapped to a site and the site has a parent site then
      map this node to this parent site.
  }
  var
    i: Integer;
    BestSite: TControl;
  begin
    if Node.IsSplitter then exit;
    BestSite:=fTreeNameToDocker[Node.Name];
    for i:=0 to Node.Count-1 do begin
      MapBottomUp(Node[i]); // recursive
      if BestSite=nil then
        BestSite:=fTreeNameToDocker[Node[i].Name];
    end;
    if (fTreeNameToDocker[Node.Name]=nil) and (BestSite<>nil) then begin
      // search the parent site of a child site
      repeat
        if BestSite is TAnchorDockPanel then begin
          if fTreeNameToDocker.ControlToName(BestSite)='' then
            fTreeNameToDocker[Node.Name]:=BestSite;
          break;
        end;
        BestSite:=BestSite.Parent;
        if BestSite is TAnchorDockHostSite then begin
          if fTreeNameToDocker.ControlToName(BestSite)='' then
            fTreeNameToDocker[Node.Name]:=BestSite;
          break;
        end;
      until (BestSite=nil);
    end;
  end;

  procedure MapSplitters(Node: TAnchorDockLayoutTreeNode);
  { map the splitter nodes to existing splitters
    The heuristic works like this:
      If a node is mapped to a site and the node is at Side anchored to a
        splitter node and the site is anchored at Side to a splitter
      then map the splitter node to the splitter.
  }
  var
    i: Integer;
    Side: TAnchorKind;
    Site: TControl;
    SplitterNode: TAnchorDockLayoutTreeNode;
    Splitter: TControl;
  begin
    if Node.IsSplitter then exit;
    for i:=0 to Node.Count-1 do
      MapSplitters(Node[i]); // recursive

    if Node.Parent=nil then exit;
    // node is a child node
    Site:=fTreeNameToDocker[Node.Name];
    if Site=nil then exit;
    // node is mapped to a site
    // check each side
    for Side:=Low(TAnchorKind) to high(TAnchorKind) do begin
      if Node.Anchors[Side]='' then continue;
      Splitter:=Site.AnchorSide[Side].Control;
      if (not (Splitter is TAnchorDockSplitter))
      or (Splitter.Parent<>Site.Parent) then continue;
      SplitterNode:=Node.Parent.FindChildNode(Node.Anchors[Side],false);
      if (SplitterNode=nil) then continue;
      // this Side of node is anchored to a splitter node
      if fTreeNameToDocker[SplitterNode.Name]<>nil then continue;
      // the SplitterNode is not yet mapped
      if fTreeNameToDocker.ControlToName(Splitter)<>'' then continue;
      // there is an unmapped splitter anchored to the Site
      // => map the splitter to the splitter node
      // Note: Splitter.Name can be different from SplitterNode.Name !
      fTreeNameToDocker[SplitterNode.Name]:=Splitter;
    end;
  end;

begin
  MapHostDockSites(Tree.Root);
  MapTopLevelSites(Tree.Root);
  MapBottomUp(Tree.Root);
  MapSplitters(Tree.Root);
end;

function SrcRectValid(const r: TRect): boolean;
begin
  Result:=(r.Left<r.Right) and (r.Top<r.Bottom);
end;

function TAnchorDockMaster.ScaleTopLvlX(p: integer): integer;
begin
  Result:=p;
  if SrcRectValid(SrcWorkArea) and SrcRectValid(WorkArea) then
    Result:=((p-SrcWorkArea.Left)*(WorkArea.Right-WorkArea.Left))
              div (SrcWorkArea.Right-SrcWorkArea.Left)
            +WorkArea.Left;
end;

function TAnchorDockMaster.ScaleTopLvlY(p: integer): integer;
begin
  Result:=p;
  if SrcRectValid(SrcWorkArea) and SrcRectValid(WorkArea) then
    Result:=((p-SrcWorkArea.Top)*(WorkArea.Bottom-WorkArea.Top))
                 div (SrcWorkArea.Bottom-SrcWorkArea.Top)
            +WorkArea.Top;
end;

function TAnchorDockMaster.ScaleChildX(p: integer): integer;
begin
  Result:=p;
  if SrcRectValid(SrcWorkArea) and SrcRectValid(WorkArea) then
    Result:=p*(WorkArea.Right-WorkArea.Left)
              div (SrcWorkArea.Right-SrcWorkArea.Left);
end;

function TAnchorDockMaster.ScaleChildY(p: integer): integer;
begin
  Result:=p;
  if SrcRectValid(SrcWorkArea) and SrcRectValid(WorkArea) then
    Result:=p*(WorkArea.Bottom-WorkArea.Top)
              div (SrcWorkArea.Bottom-SrcWorkArea.Top);
end;

procedure TAnchorDockMaster.SetupSite(Site: TWinControl;
  ANode: TAnchorDockLayoutTreeNode; AParent: TWinControl);
var
  aManager: TAnchorDockManager;
  NewBounds: TRect;
  aMonitor: TMonitor;
  aHostSite: TAnchorDockHostSite;
  ParentForm: TCustomForm;
begin
  if Site is TCustomForm then begin
    Site.Align:=alNone;
    TCustomForm(Site).PixelsPerInch:=Screen.PixelsPerInch;
    if AParent=nil then
      TCustomForm(Site).WindowState:=ANode.WindowState
    else
      TCustomForm(Site).WindowState:=wsNormal;
  end else begin
    ParentForm:=GetParentForm(Site);
    ParentForm.WindowState:=ANode.WindowState;
    ParentForm.PixelsPerInch:=Screen.PixelsPerInch;
  end;
  if Site is TAnchorDockPanel then
    ParentForm.BoundsRect:=ScaleBoundsRect(ANode.BoundsRect,ANode.PixelsPerInch,Screen.PixelsPerInch)
  else begin
    if AParent=nil then begin
      if (ANode.Monitor>=0) and (ANode.Monitor<Screen.MonitorCount) then
        aMonitor:=Screen.Monitors[ANode.Monitor]
      else begin
        if Site is TCustomForm then
          aMonitor:=TCustomForm(Site).Monitor
        else
          aMonitor:=ParentForm.Monitor;
      end;
      WorkArea:=aMonitor.WorkareaRect;
      {$IFDEF VerboseAnchorDockRestore}
      debugln(['TAnchorDockMaster.RestoreLayout.SetupSite WorkArea=',dbgs(WorkArea)]);
      {$ENDIF}
    end;
  end;
  if IsCustomSite(Site) then begin
    aManager:=TAnchorDockManager(Site.DockManager);
    if ANode.Count>0 then begin
      // this custom dock site gets a child => store and clear constraints
      aManager.StoreConstraints;
    end;
  end;
  Site.Constraints.MaxWidth:=0;
  Site.Constraints.MaxHeight:=0;
  NewBounds:=ScaleBoundsRect(ANode.BoundsRect,ANode.PixelsPerInch,Screen.PixelsPerInch);
  if AParent=nil then begin
    NewBounds:=Rect(ScaleTopLvlX(NewBounds.Left),ScaleTopLvlY(NewBounds.Top),
                    ScaleTopLvlX(NewBounds.Right),ScaleTopLvlY(NewBounds.Bottom));
  end else begin
    if AParent is TAnchorDockPanel then
    begin
      NewBounds:=Rect(0,0,AParent.ClientWidth,AParent.ClientHeight);
      Site.Align:=alClient;
    end
    else
      NewBounds:=Rect(ScaleChildX(NewBounds.Left), ScaleChildY(NewBounds.Top),
                      ScaleChildX(NewBounds.Right),ScaleChildY(NewBounds.Bottom));
  end;
  {$IFDEF VerboseAnchorDockRestore}
  //if Scale then
    debugln(['TAnchorDockMaster.RestoreLayout.SetupSite scale Site=',DbgSName(Site),' Caption="',Site.Caption,'" OldWorkArea=',dbgs(SrcWorkArea),' CurWorkArea=',dbgs(WorkArea),' OldBounds=',dbgs(aNode.BoundsRect),' NewBounds=',dbgs(NewBounds)]);
  {$ENDIF}
  Site.Visible:=true;
  if not (Site is TAnchorDockPanel) then
    begin
      Site.BoundsRect:=NewBounds;
      Site.Parent:=AParent;
    end;
  if IsCustomSite(AParent) then begin
    aManager:=TAnchorDockManager(AParent.DockManager);
    Site.Align:=ANode.Align;
    {$IFDEF VerboseAnchorDockRestore}
    debugln(['TAnchorDockMaster.RestoreLayout.SetupSite custom Site=',DbgSName(Site),' Site.Bounds=',dbgs(Site.BoundsRect),' BoundSplitterPos=',aNode.BoundSplitterPos]);
    {$ENDIF}
    if Application.Scaled then
      aManager.RestoreSite(MulDiv(ANode.BoundSplitterPos,Screen.PixelsPerInch,ANode.PixelsPerInch))
    else
      aManager.RestoreSite(ANode.BoundSplitterPos);
    Site.HostDockSite:=AParent;
  end;
  if Site is TAnchorDockHostSite then begin
    aHostSite:=TAnchorDockHostSite(Site);
    aHostSite.Header.HeaderPosition:=ANode.HeaderPosition;
    aHostSite.DockRestoreBounds:=NewBounds;
    //aHostSite.FMinimized:=ANode.Minimized;
    //we update aHostSite.FMinimized in TAnchorDockMaster.SetMinimizedState
    if (ANode.NodeType<>adltnPages) and (aHostSite.Pages<>nil) then
      aHostSite.FreePages;
  end;
end;

function TAnchorDockMaster.GetNodeSite(Node: TAnchorDockLayoutTreeNode): TAnchorDockHostSite;
var
  Site: TControl;
begin
  Site:=fTreeNameToDocker[Node.Name];
  if Site is TAnchorDockHostSite then
    exit(TAnchorDockHostSite(Site));
  if Site<>nil then
    exit(nil);
  Result:=CreateSite;
  fDisabledAutosizing.Add(Result);
  fTreeNameToDocker[Node.Name]:=Result;
end;

procedure TAnchorDockMaster.SetNodeMinimizedState(ANode: TAnchorDockLayoutTreeNode);
var
  HostSite:TAnchorDockHostSite;
  i:integer;
begin
  HostSite:=GetNodeSite(ANode);
  if Assigned(HostSite) then
    if HostSite.Minimized<>ANode.Minimized then
      Application.QueueAsyncCall(@HostSite.AsyncMinimizeSite,0);
      //HostSite.MinimizeSite;
  for i:=0 to ANode.Count-1 do
    SetNodeMinimizedState(ANode.Nodes[i]);
end;

procedure TAnchorDockMaster.SetMinimizedState(Tree: TAnchorDockLayoutTree);
begin
  SetNodeMinimizedState(Tree.Root);
end;

function TAnchorDockMaster.RestoreLayout(Tree: TAnchorDockLayoutTree;
  Scale: boolean): boolean;

  function Restore(ANode: TAnchorDockLayoutTreeNode; AParent: TWinControl): TControl;
  var
    AControl: TControl;
    Site: TAnchorDockHostSite;
    Splitter: TAnchorDockSplitter;
    i, j: Integer;
    Side: TAnchorKind;
    AnchorControl: TControl;
    ChildNode: TAnchorDockLayoutTreeNode;
    NewBounds: TRect;
    aPageName: String;
    aPage: TCustomPage;
  begin
    Result:=nil;
    if Scale and SrcRectValid(ANode.WorkAreaRect) then
      SrcWorkArea:=ANode.WorkAreaRect;
    {$IFDEF VerboseAnchorDockRestore}
    debugln(['TAnchorDockMaster.RestoreLayout.Restore Node="',aNode.Name,'" ',dbgs(aNode.NodeType),' Bounds=',dbgs(aNode.BoundsRect),' Parent=',DbgSName(aParent),' ']);
    {$ENDIF}
    AControl:=nil;
    if ANode.NodeType in [adltnControl, adltnCustomSite] then
    begin
      AControl:=FindControl(ANode.Name);
      if AControl=nil then begin
        debugln(['TAnchorDockMaster.RestoreLayout.Restore WARNING: can not find control ',ANode.Name,
                 ', NodeType=', ANode.NodeType]);
        exit;
      end;
    end;
    if ANode.NodeType=adltnControl then begin
      // restore control
      // the control was already created  =>  dock it
      DisableControlAutoSizing(AControl);
      if AControl.HostDockSite=nil then
        MakeDockable(AControl,false)
      else
        ClearLayoutProperties(AControl);
      {$IFDEF VerboseAnchorDockRestore}
      debugln(['TAnchorDockMaster.RestoreLayout.Restore Control Node.Name=',aNode.Name,
               ' Control=',DbgSName(AControl),' Site=',DbgSName(AControl.HostDockSite)]);
      {$ENDIF}
      AControl.Visible:=true;
      SetupSite(AControl.HostDockSite,ANode,AParent);
      Result:=AControl.HostDockSite;
    end
    else if ANode.NodeType=adltnCustomSite then begin
      // restore custom dock site
      // the control was already created  =>  position it
      if not (IsCustomSite(AControl) or (AControl is TAnchorDockPanel)) then begin
        debugln(['TAnchorDockMaster.RestoreLayout.Restore WARNING: ',ANode.Name,' is not a custom dock site ',DbgSName(AControl)]);
        exit;
      end;
      DisableControlAutoSizing(AControl);
      SetupSite(TCustomForm(AControl),ANode,nil);
      Result:=AControl;
      // restore docked site
      if ANode.Count>0 then
        Restore(ANode[0],TCustomForm(AControl));
    end
    else if ANode.IsSplitter then begin
      // restore splitter
      Splitter:=TAnchorDockSplitter(fTreeNameToDocker[ANode.Name]);
      if Splitter=nil then begin
        Splitter:=CreateSplitter;
        fTreeNameToDocker[ANode.Name]:=Splitter;
      end;
      {$IFDEF VerboseAnchorDockRestore}
      debugln(['TAnchorDockMaster.RestoreLayout.Restore Splitter Node.Name=',aNode.Name,' ',dbgs(aNode.NodeType),' Splitter=',DbgSName(Splitter)]);
      {$ENDIF}
      Splitter.Parent:=AParent;
      NewBounds:=ScaleBoundsRect(ANode.BoundsRect,ANode.PixelsPerInch,Screen.PixelsPerInch);
      if SrcRectValid(SrcWorkArea) then
        NewBounds:=Rect(ScaleChildX(NewBounds.Left),ScaleChildY(NewBounds.Top),
          ScaleChildX(NewBounds.Right),ScaleChildY(NewBounds.Bottom));
      Splitter.DockRestoreBounds:=NewBounds;
      Splitter.BoundsRect:=NewBounds;
      if ANode.NodeType=adltnSplitterVertical then begin
        Splitter.ResizeAnchor:=akLeft;
        Splitter.AnchorSide[akLeft].Control:=nil;
        Splitter.AnchorSide[akRight].Control:=nil;
      end else begin
        Splitter.ResizeAnchor:=akTop;
        Splitter.AnchorSide[akTop].Control:=nil;
        Splitter.AnchorSide[akBottom].Control:=nil;
      end;
      Result:=Splitter;
      Splitter.AsyncUpdateDockBounds:=true;
    end else if ANode.NodeType=adltnLayout then begin
      // restore layout
      Site:=GetNodeSite(ANode);
      {$IFDEF VerboseAnchorDockRestore}
      debugln(['TAnchorDockMaster.RestoreLayout.Restore Layout Node.Name=',aNode.Name,' ChildCount=',aNode.Count]);
      {$ENDIF}
      Site.BeginUpdateLayout;
      try
        SetupSite(Site,ANode,AParent);
        Site.FSiteType:=adhstLayout;
        Site.Header.Parent:=nil;
        // create children
        for i:=0 to ANode.Count-1 do
          Restore(ANode[i],Site);
        // anchor children
        for i:=0 to ANode.Count-1 do begin
          ChildNode:=ANode[i];
          AControl:=fTreeNameToDocker[ChildNode.Name];
          {$IFDEF VerboseAnchorDockRestore}
          debugln(['  Restore layout child anchors Site=',DbgSName(Site),' ChildNode.Name=',ChildNode.Name,' Control=',DbgSName(AControl)]);
          {$ENDIF}
          if AControl=nil then continue;
          for Side:=Low(TAnchorKind) to high(TAnchorKind) do begin
            if ((ChildNode.NodeType=adltnSplitterHorizontal)
                and (Side in [akTop,akBottom]))
            or ((ChildNode.NodeType=adltnSplitterVertical)
                and (Side in [akLeft,akRight]))
            then continue;
            AnchorControl:=nil;
            if ChildNode.Anchors[Side]<>'' then begin
              AnchorControl:=fTreeNameToDocker[ChildNode.Anchors[Side]];
              if AnchorControl=nil then
                debugln(['WARNING: TAnchorDockMaster.RestoreLayout.Restore: Node=',ChildNode.Name,' Anchor[',dbgs(Side),']=',ChildNode.Anchors[Side],' not found']);
            end;
            if AnchorControl<>nil then
              AControl.AnchorToNeighbour(Side,0,AnchorControl)
            else
              AControl.AnchorParallel(Side,0,Site);
          end;
        end;
        // free unneeded helper controls (e.g. splitters)
        for i:=Site.ControlCount-1 downto 0 do begin
          AControl:=Site.Controls[i];
          if fTreeNameToDocker.ControlToName(AControl)<>'' then continue;
          if AControl is TAnchorDockSplitter then begin
            AControl.Free;
          end;
        end;
      finally
        Site.EndUpdateLayout;
      end;
      Result:=Site;
    end else if ANode.NodeType=adltnPages then begin
      // restore pages
      Site:=GetNodeSite(ANode);
      {$IFDEF VerboseAnchorDockRestore}
      debugln(['TAnchorDockMaster.RestoreLayout.Restore Pages Node.Name=',aNode.Name,' ChildCount=',aNode.Count]);
      {$ENDIF}
      Site.BeginUpdateLayout;
      j:=0;
      try
        SetupSite(Site,ANode,AParent);
        Site.FSiteType:=adhstPages;
        //Site.Header.Parent:=nil;
        if Site.Pages=nil then
          Site.CreatePages;
        Site.Pages.TabPosition:=ANode.TabPosition;
        for i:=0 to ANode.Count-1 do begin
          aPageName:=ANode[i].Name;
          if j>=Site.Pages.PageCount then
            Site.Pages.Pages.Add(aPageName);
          aPage:=Site.Pages.Page[j];
          inc(j);
          AControl:=Restore(ANode[i],aPage);
          if AControl=nil then continue;
          AControl.Align:=alClient;
          for Side:=Low(TAnchorKind) to high(TAnchorKind) do
            AControl.AnchorSide[Side].Control:=nil;
        end;
        Site.Pages.PageIndex:=ANode.PageIndex;
      finally
        while Site.Pages.PageCount>j do
          Site.Pages.Page[Site.Pages.PageCount-1].Free;
        Site.SimplifyPages;
        Site.EndUpdateLayout;
      end;
      Result:=Site;
    end else begin
      // create children
      for i:=0 to ANode.Count-1 do
        Restore(ANode[i],AParent);
    end;
  end;

begin
  Result:=true;
  WorkArea:=Rect(0,0,0,0);
  SrcWorkArea:=WorkArea;
  Restore(Tree.Root,nil);
  Restoring:=true;
end;

procedure TAnchorDockMaster.ScreenFormAdded(Sender: TObject; Form: TCustomForm);
begin
  FFormStyles.AddForm(Form);
  Form.AddHandlerFirstShow(@FormFirstShow);
end;

procedure TAnchorDockMaster.ScreenRemoveForm(Sender: TObject; Form: TCustomForm);
begin
  FFormStyles.RemoveForm(Form);
end;

procedure TAnchorDockMaster.SetMainDockForm(AValue: TCustomForm);
begin
  if FMainDockForm = AValue then Exit;
  FMainDockForm := AValue;
  RefreshFloatingWindowsOnTop;
end;

function TAnchorDockMaster.DoCreateControl(aName: string;
  DisableAutoSizing: boolean): TControl;
begin
  Result:=nil;
  OnCreateControl(Self,aName,Result,DisableAutoSizing);
  if Result=nil then
    debugln(['TAnchorDockMaster.DoCreateControl WARNING: control not found: "',aName,'"']);
  if (Result<>nil) and (Result.Name<>aName) then
    raise Exception.Create('TAnchorDockMaster.DoCreateControl'+Format(
      adrsRequestedButCreated, [aName, Result.Name]));
end;

procedure TAnchorDockMaster.DisableControlAutoSizing(AControl: TControl);
begin
  if fDisabledAutosizing.IndexOf(AControl)>=0 then exit;
  //debugln(['TAnchorDockMaster.DisableControlAutoSizing ',DbgSName(AControl)]);
  fDisabledAutosizing.Add(AControl);
  AControl.FreeNotification(Self);
  AControl.DisableAutoSizing{$IFDEF DebugDisableAutoSizing}(ADAutoSizingReason){$ENDIF};
end;

procedure TAnchorDockMaster.EnableAllAutoSizing;
var
  i: Integer;
  AControl: TControl;
begin
  i:=fDisabledAutosizing.Count-1;
  while (i>=0) do begin
    AControl:=TControl(fDisabledAutosizing[i]);
    //debugln(['TAnchorDockMaster.EnableAllAutoSizing ',DbgSName(AControl)]);
    fDisabledAutosizing.Delete(i);
    AControl.EnableAutoSizing{$IFDEF DebugDisableAutoSizing}(ADAutoSizingReason){$ENDIF};
    i:=Min(i,fDisabledAutosizing.Count)-1;
  end;
end;

procedure TAnchorDockMaster.ClearLayoutProperties(AControl: TControl;
  NewAlign: TAlign);
var
  a: TAnchorKind;
begin
  AControl.AutoSize:=false;
  AControl.Align:=NewAlign;
  AControl.BorderSpacing.Around:=0;
  AControl.BorderSpacing.Left:=0;
  AControl.BorderSpacing.Top:=0;
  AControl.BorderSpacing.Right:=0;
  AControl.BorderSpacing.Bottom:=0;
  AControl.BorderSpacing.InnerBorder:=0;
  for a:=Low(TAnchorKind) to High(TAnchorKind) do
    AControl.AnchorSide[a].Control:=nil;
end;

procedure TAnchorDockMaster.PopupMenuPopup(Sender: TObject);
var
  Popup: TPopupMenu;
  ChangeLockItem: TMenuItem;
  ShowHeadersItem: TMenuItem;
begin
  if not (Sender is TPopupMenu) then exit;
  Popup:=TPopupMenu(Sender);
  Popup.Items.Clear;

  // top popup menu item can be clicked by accident, so use something simple:
  // lock/unlock
  ChangeLockItem:=AddPopupMenuItem('AnchorDockMasterChangeLockMenuItem',
                                   adrsLocked,@ChangeLockButtonClick);
  ChangeLockItem.Checked:=not AllowDragging;
  ChangeLockItem.ShowAlwaysCheckable:=true;

  if Popup.PopupComponent is TAnchorDockHeader then
    TAnchorDockHeader(Popup.PopupComponent).PopupMenuPopup(Sender)
  else if Popup.PopupComponent is TAnchorDockPageControl then
    TAnchorDockPageControl(Popup.PopupComponent).PopupMenuPopup(Sender)
  else if Popup.PopupComponent is TAnchorDockSplitter then
    TAnchorDockSplitter(Popup.PopupComponent).PopupMenuPopup(Sender);

  if ShowMenuItemShowHeader or (not ShowHeader) then begin
    ShowHeadersItem:=AddPopupMenuItem('AnchorDockMasterShowHeaderMenuItem',
                                      adrsShowHeaders, @ShowHeadersButtonClick);
    ShowHeadersItem.Checked:=ShowHeader;
    ShowHeadersItem.ShowAlwaysCheckable:=true;
  end;

  if Assigned(OnShowOptions) then
    AddPopupMenuItem('OptionsMenuItem', adrsDockingOptions, @OptionsClick);
end;

procedure TAnchorDockMaster.ResetSplitters;
var
  I: Integer;
  S: TAnchorDockSplitter;
begin
  for I := 0 to ComponentCount-1 do
    if Components[I] is TAnchorDockSplitter then
    begin
      S := TAnchorDockSplitter(Components[I]);
      S.UpdateDockBounds;
      S.UpdatePercentPosition;
    end;
end;

function TAnchorDockMaster.FullRestoreLayout(Tree: TAnchorDockLayoutTree;
  Scale: Boolean): Boolean;
var
  ControlNames: TStringListUTF8Fast;
begin
  Result:=false;
  ControlNames:=TStringListUTF8Fast.Create;
  fTreeNameToDocker:=TADNameToControl.Create;
  try

    // close all unneeded and wrongly allocated forms/controls (not helper controls like splitters)
    MarkCorrectlyLocatedControl(Tree);
    if not CloseUnneededAndWronglyLocatedControls(Tree) then exit;

    BeginUpdate;
    try
      // create all needed forms/controls (not helper controls like splitters)
      if not CreateNeededControls(Tree,true,ControlNames) then exit;

      // simplify layouts
      ControlNames.Sort;
      {$IFDEF VerboseAnchorDockRestore}
      debugln(['TAnchorDockMaster.FullRestoreLayout controls: ']);
      debugln(ControlNames.Text);
      {$ENDIF}
      // if some forms/controls could not be created the layout needs to be adapted
      Tree.Root.Simplify(ControlNames,false);

      // reuse existing sites to reduce flickering
      MapTreeToControls(Tree);
      {$IFDEF VerboseAnchorDockRestore}
      fTreeNameToDocker.WriteDebugReport('TAnchorDockMaster.FullRestoreLayout Map');
      {$ENDIF}

      // create sites, move controls
      RestoreLayout(Tree,Scale);
      SetMinimizedState(Tree);
    finally
      EndUpdate;
    end;
  finally
    // clean up
    FreeAndNil(fTreeNameToDocker);
    ControlNames.Free;
    // commit (this can raise an exception, when it triggers events)
    EnableAllAutoSizing;
  end;
  ResetSplitters; // reset splitters' DockBounds after EnableAllAutoSizing. fixes issue #18538
  {$IFDEF VerboseAnchorDockRestore}
  DebugWriteChildAnchors(Application.MainForm,true,false);
  {$ENDIF}
  Result:=true;
end;

procedure TAnchorDockMaster.SetHideHeaderCaptionFloatingControl(
  const AValue: boolean);
var
  Site: TAnchorDockHostSite;
  i: Integer;
begin
  if AValue=HideHeaderCaptionFloatingControl then exit;
  fHideHeaderCaptionFloatingControl:=AValue;
  for i:=0 to ComponentCount-1 do begin
    Site:=TAnchorDockHostSite(Components[i]);
    if not (Site is TAnchorDockHostSite) then continue;
    Site.UpdateDockCaption;
  end;
  OptionsChanged;
end;

procedure TAnchorDockMaster.SetSplitterWidth(const AValue: integer);
var
  i: Integer;
  Splitter: TAnchorDockSplitter;
begin
  if (AValue<1) or (AValue=SplitterWidth) then exit;
  FSplitterWidth:=AValue;
  for i:=0 to ComponentCount-1 do begin
    Splitter:=TAnchorDockSplitter(Components[i]);
    if not (Splitter is TAnchorDockSplitter) then continue;
    if not Splitter.CustomWidth then
    begin
      if Splitter.ResizeAnchor in [akLeft,akRight] then
        Splitter.Width:=SplitterWidth
      else
        Splitter.Height:=SplitterWidth;
    end;
  end;
  OptionsChanged;
end;

procedure TAnchorDockMaster.StartHideOverlappingTimer;
begin
  if not DockTimer.Enabled then begin
    DockTimer.Interval:=HideOverlappingFormByMouseLoseTime;
    DockTimer.OnTimer:=@HideOverlappingForm;
    DockTimer.Enabled:=true;
  end;
end;

procedure TAnchorDockMaster.StopHideOverlappingTimer;
begin
  DockTimer.Enabled:=False;
  DockTimer.Interval:=0;
  DockTimer.OnTimer:=nil;
end;

function IsParentControl(aParent, aControl: TControl): boolean;
begin
  while (aControl <> nil) and (aControl.Parent <> nil) do
  begin
    if (aControl=aParent) then
      exit(true);
    aControl := aControl.Parent;
  end;
  result:=aControl=aParent;
end;


procedure TAnchorDockMaster.OnIdle(Sender: TObject; var Done: Boolean);
var
  MousePos: TPoint;
  Bounds:Trect;
begin
  if Done then ;
  Restoring:=false;
  if FOverlappingForm=nil then
    IdleConnected:=false
  else begin
    MousePos:=Point(0, 0);
    GetCursorPos(MousePos);
    Bounds.TopLeft:=FOverlappingForm.ClientToScreen(point(0,0));
    Bounds.BottomRight:=FOverlappingForm.ClientToScreen(point(FOverlappingForm.Width,FOverlappingForm.Height));
    if not IsParentControl(FOverlappingForm, GetCaptureControl) then begin
      if not PtInRect(Bounds,MousePos) then
          StartHideOverlappingTimer
        else
          StopHideOverlappingTimer;
    end;
  end;
end;

procedure TAnchorDockMaster.AsyncSimplify(Data: PtrInt);
begin
  FQueueSimplify:=false;
  SimplifyPendingLayouts;
end;

procedure TAnchorDockMaster.ChangeLockButtonClick(Sender: TObject);
begin
  AllowDragging:=not AllowDragging;
end;

procedure TAnchorDockMaster.RefreshFloatingWindowsOnTop;
var
  i, AIndex: Integer;
  AForm, ParentForm: TCustomForm;
  IsMainDockForm: Boolean;
  AFormStyle: TFormStyle;
begin
  for i := 0 to Screen.FormCount - 1 do
  begin
    AForm := Screen.Forms[i];
    if AForm.FormStyle = fsSplash then continue;
    ParentForm := GetParentForm(AForm);
    if FFloatingWindowsOnTop then
    begin
      IsMainDockForm := (AForm = MainDockForm)
                    or (AForm.IsParentOf(MainDockForm))
                    or (ParentForm = MainDockForm);
      if IsMainDockForm then
        AFormStyle := fsNormal
      else
        AFormStyle := fsStayOnTop;
    end else begin
      AIndex := FFormStyles.IndexOfForm(AForm);
      if AIndex >= 0 then
        AFormStyle := FFormStyles[AIndex].FormStyle
      else
        AFormStyle := fsNormal;
    end;
    if ParentForm is TAnchorDockHostSite then
      ParentForm.FormStyle := AFormStyle
    else
      AForm.FormStyle := AFormStyle;
  end;
end;

function TAnchorDockMaster.ScaleBoundsRect(ARect: TRect; FromDPI, ToDPI: integer): TRect;
begin
  if not Application.Scaled or (FromDPI <= 0) or (ToDPI <= 0) then
    Result := ARect
  else begin
    Result.Left  :=MulDiv(ARect.Left  ,ToDPI,FromDPI);
    Result.Top   :=MulDiv(ARect.Top   ,ToDPI,FromDPI);
    Result.Width :=MulDiv(ARect.Width ,ToDPI,FromDPI);
    Result.Height:=MulDiv(ARect.Height,ToDPI,FromDPI);
  end;
  {$IFDEF VerboseAnchorDockRestore}
  debugln(['TAnchorDockMaster.ScaleBoundsRect FromDPI=',FromDPI,' ToDPI=',ToDPI,' FromRect[',dbgs(ARect),'] ToRect[',dbgs(Result),']']);
  {$ENDIF}
end;

procedure TAnchorDockMaster.SetAllowDragging(AValue: boolean);
begin
  if FAllowDragging=AValue then Exit;
  FAllowDragging:=AValue;
  OptionsChanged;
end;

procedure TAnchorDockMaster.SetDockOutsideMargin(AValue: integer);
begin
  if FDockOutsideMargin=AValue then Exit;
  FDockOutsideMargin:=AValue;
  OptionsChanged;
end;

procedure TAnchorDockMaster.SetDockParentMargin(AValue: integer);
begin
  if FDockParentMargin=AValue then Exit;
  FDockParentMargin:=AValue;
  OptionsChanged;
end;

procedure TAnchorDockMaster.SetDragTreshold(AValue: integer);
begin
  if FDragTreshold=AValue then Exit;
  FDragTreshold:=AValue;
  OptionsChanged;
end;

procedure TAnchorDockMaster.SetHeaderHint(AValue: string);
begin
  if FHeaderHint=AValue then Exit;
  FHeaderHint:=AValue;
  OptionsChanged;
end;

procedure TAnchorDockMaster.SetHeaderStyle(AValue: THeaderStyleName);
begin
  if FHeaderStyle=AValue then Exit;
  FHeaderStyle:=AValue;
  FHeaderStyleName2ADHeaderStyle.TryGetData(uppercase(AValue),CurrentADHeaderStyle);
  OptionsChanged;
  InvalidateHeaders;
end;

procedure TAnchorDockMaster.SetPageAreaInPercent(AValue: integer);
begin
  if FPageAreaInPercent=AValue then Exit;
  FPageAreaInPercent:=AValue;
  OptionsChanged;
end;

procedure TAnchorDockMaster.SetScaleOnResize(AValue: boolean);
begin
  if FScaleOnResize=AValue then Exit;
  FScaleOnResize:=AValue;
  OptionsChanged;
end;

procedure TAnchorDockMaster.SetHeaderFlatten(AValue: boolean);
begin
  if FHeaderFlatten=AValue then Exit;
  FHeaderFlatten:=AValue;
  OptionsChanged;
  InvalidateHeaders;
end;

procedure TAnchorDockMaster.SetHeaderFilled(AValue: boolean);
begin
  if FHeaderFilled=AValue then Exit;
  FHeaderFilled:=AValue;
  OptionsChanged;
  InvalidateHeaders;
end;

procedure TAnchorDockMaster.SetHeaderHighlightFocused(AValue: boolean);
begin
  if FHeaderHighlightFocused=AValue then Exit;
  FHeaderHighlightFocused:=AValue;
  OptionsChanged;
  InvalidateHeaders;
end;

procedure TAnchorDockMaster.SetDockSitesCanBeMinimized(AValue: boolean);
begin
  if FDockSitesCanBeMinimized=AValue then Exit;
  FDockSitesCanBeMinimized:=AValue;
  UpdateHeaders;
  InvalidateHeaders;
  EnableAllAutoSizing;
  OptionsChanged;
end;

procedure TAnchorDockMaster.SetFloatingWindowsOnTop(AValue: boolean);
begin
  if FFloatingWindowsOnTop = AValue then Exit;
  FFloatingWindowsOnTop := AValue;
  RefreshFloatingWindowsOnTop;
  OptionsChanged;
end;

procedure TAnchorDockMaster.SetMultiLinePages(AValue: boolean);
var
  Site: TAnchorDockHostSite;
  i: Integer;
begin
  if FMultiLinePages=AValue then Exit;
  FMultiLinePages:=AValue;
  for i:=0 to ComponentCount-1 do
  begin
    Site:=TAnchorDockHostSite(Components[i]);
    if not (Site is TAnchorDockHostSite) then continue;
    if Assigned(Site.Pages) then
    begin
      DisableControlAutoSizing(Site);
      Site.Pages.MultiLine:=AValue;
    end;
  end;
  EnableAllAutoSizing;
  OptionsChanged;
end;

procedure TAnchorDockMaster.SetShowMenuItemShowHeader(AValue: boolean);
begin
  if FShowMenuItemShowHeader=AValue then Exit;
  FShowMenuItemShowHeader:=AValue;
  OptionsChanged;
end;

procedure TAnchorDockMaster.ShowHeadersButtonClick(Sender: TObject);
begin
  ShowHeader:=not ShowHeader;
end;

procedure TAnchorDockMaster.OptionsClick(Sender: TObject);
begin
  if Assigned(OnShowOptions) then OnShowOptions(Self);
end;

procedure TAnchorDockMaster.SetIdleConnected(const AValue: Boolean);
begin
  if FIdleConnected=AValue then exit;
  FIdleConnected:=AValue;
  if IdleConnected then
    Application.AddOnIdleHandler(@OnIdle,true)
  else
    Application.RemoveOnIdleHandler(@OnIdle);
end;

procedure TAnchorDockMaster.SetQueueSimplify(const AValue: Boolean);
begin
  if FQueueSimplify=AValue then exit;
  FQueueSimplify:=AValue;
  if FQueueSimplify then
    Application.QueueAsyncCall(@AsyncSimplify,0)
  else
    Application.RemoveAsyncCalls(Self);
end;

procedure TAnchorDockMaster.SetRestoring(const AValue: boolean);
var
  AComponent: TComponent;
  i: Integer;
begin
  if FRestoring=AValue then exit;
  FRestoring:=AValue;
  if FRestoring then begin
    IdleConnected:=true;
  end else begin
    for i:=0 to ComponentCount-1 do begin
      AComponent:=Components[i];
      if AComponent is TAnchorDockHostSite then
        TAnchorDockHostSite(AComponent).DockRestoreBounds:=Rect(0,0,0,0)
      else if AComponent is TAnchorDockSplitter then
        TAnchorDockSplitter(AComponent).DockRestoreBounds:=Rect(0,0,0,0)
    end;
  end;
end;

procedure TAnchorDockMaster.OptionsChanged;
begin
  IncreaseOptionsChangeStamp;
  if Assigned(OnOptionsChanged) then
    OnOptionsChanged(Self);
end;

procedure TAnchorDockMaster.SetShowHeader(AValue: boolean);
var
  i: Integer;
  Site: TAnchorDockHostSite;
begin
  if FShowHeader=AValue then exit;
  FShowHeader:=AValue;
  for i:=0 to ComponentCount-1 do begin
    Site:=TAnchorDockHostSite(Components[i]);
    if not (Site is TAnchorDockHostSite) then continue;
    if (Site.Header<>nil) then begin
      DisableControlAutoSizing(Site);
      Site.UpdateHeaderShowing;
      if Site.Minimized then
        if not AValue then
          site.MinimizeSite;
    end;
  end;
  EnableAllAutoSizing;
  OptionsChanged;
end;

procedure TAnchorDockMaster.SetShowHeaderCaption(const AValue: boolean);
var
  i: Integer;
  Site: TAnchorDockHostSite;
begin
  if FShowHeaderCaption=AValue then exit;
  FShowHeaderCaption:=AValue;
  for i:=0 to ComponentCount-1 do begin
    Site:=TAnchorDockHostSite(Components[i]);
    if not (Site is TAnchorDockHostSite) then continue;
    Site.UpdateDockCaption;
  end;
  OptionsChanged;
end;

procedure TAnchorDockMaster.Notification(AComponent: TComponent;
  Operation: TOperation);
var
  AControl: TControl;
begin
  inherited Notification(AComponent, Operation);
  if Operation=opRemove then begin
    if AComponent is TControl then begin
      AControl:=TControl(AComponent);
      FControls.Remove(AControl);
      fNeedSimplify.Remove(AControl);
      fNeedFree.Remove(AControl);
      fDisabledAutosizing.Remove(AControl);
      if fTreeNameToDocker<>nil then
        fTreeNameToDocker.RemoveControl(AControl);
    end;
  end;
end;

procedure TAnchorDockMaster.InvalidateHeaders;
var
  i: Integer;
  Site: TAnchorDockHostSite;
begin
  for i:=0 to ComponentCount-1 do begin
    Site:=TAnchorDockHostSite(Components[i]);
    if not (Site is TAnchorDockHostSite) then continue;
    if (Site.Header<>nil) and (Site.Header.Parent<>nil) then
      Site.Header.Invalidate;
  end;
end;

procedure TAnchorDockMaster.AutoSizeAllHeaders(EnableAutoSizing: boolean);
var
  i: Integer;
  Site: TAnchorDockHostSite;
begin
  for i:=0 to ComponentCount-1 do begin
    Site:=TAnchorDockHostSite(Components[i]);
    if not (Site is TAnchorDockHostSite) then continue;
    if (Site.Header<>nil) and (Site.Header.Parent<>nil) then begin
      Site.Header.InvalidatePreferredSize;
      DisableControlAutoSizing(Site);
    end;
  end;
  if EnableAutoSizing then
    EnableAllAutoSizing;
end;

procedure TAnchorDockMaster.RegisterHeaderStyle(StyleName: THeaderStyleName; DrawProc:TDrawADHeaderProc; NeedDrawHeaderAfterText,NeedHighlightText: boolean);
var
  TempStyle:TADHeaderStyle;
begin
  TempStyle.DrawProc:=DrawProc;
  TempStyle.StyleDesc.NeedDrawHeaderAfterText:=NeedDrawHeaderAfterText;
  TempStyle.StyleDesc.NeedHighlightText:=NeedHighlightText;
  TempStyle.StyleDesc.Name:=StyleName;
  FHeaderStyleName2ADHeaderStyle.AddOrSetData(uppercase(StyleName), TempStyle);
  if FHeaderStyleName2ADHeaderStyle.Count=1 then
  begin
    CurrentADHeaderStyle:=TempStyle;
    HeaderStyle:=StyleName;
  end;
end;

procedure TAnchorDockMaster.ShowOverlappingForm;
begin
  FOverlappingForm.Show;
  IdleConnected:=true;
end;

procedure TAnchorDockMaster.HideOverlappingForm(Sender: TObject);
begin
  StopHideOverlappingTimer;
  FOverlappingForm.Hide;
  FOverlappingForm.AnchorDockHostSite.HideMinimizedControl;
  IdleConnected:=false;
end;

constructor TAnchorDockMaster.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FFormStyles:=TFormStyles.Create;
  FMainDockForm:=nil;
  FControls:=TFPList.Create;
  FAllowDragging:=true;
  FDragTreshold:=4;
  FDockOutsideMargin:=10;
  FDockParentMargin:=10;
  FFloatingWindowsOnTop:=false;
  FPageAreaInPercent:=40;
  FHeaderAlignTop:=80;
  HeaderAlignLeft:=120;
  FHeaderHint:='';
  FMultiLinePages:=false;
  FShowHeader:=true;
  FShowHeaderCaption:=true;
  FHideHeaderCaptionFloatingControl:=true;
  FSplitterWidth:=4;
  FScaleOnResize:=true;
  FMapMinimizedControls:=TMapMinimizedControls.Create;
  fNeedSimplify:=TFPList.Create;
  fNeedFree:=TFPList.Create;
  fDisabledAutosizing:=TFPList.Create;
  FSplitterClass:=TAnchorDockSplitter;
  FSiteClass:=TAnchorDockHostSite;
  FManagerClass:=TAnchorDockManager;
  FHeaderClass:=TAnchorDockHeader;
  FHeaderFlatten:=true;
  FHeaderFilled:=true;
  FPageControlClass:=TAnchorDockPageControl;
  FPageClass:=TAnchorDockPage;
  FRestoreLayouts:=TAnchorDockRestoreLayouts.Create;
  FHeaderHighlightFocused:=false;
  FDockSitesCanBeMinimized:=false;
  FOverlappingForm:=nil;
  FAllClosing:=False;
  FHeaderStyleName2ADHeaderStyle:=THeaderStyleName2ADHeaderStylesMap.create;
  Screen.AddHandlerFormAdded(@ScreenFormAdded);
  Screen.AddHandlerRemoveForm(@ScreenRemoveForm);
end;

destructor TAnchorDockMaster.Destroy;
var
  AControl: TControl;
  i, j: Integer;
begin
  Screen.RemoveHandlerFormAdded(@ScreenFormAdded);
  Screen.RemoveHandlerRemoveForm(@ScreenRemoveForm);
  QueueSimplify:=false;
  FreeAndNil(FRestoreLayouts);
  FreeAndNil(fPopupMenu);
  FreeAndNil(fTreeNameToDocker);
  if FControls.Count>0 then begin
    while ControlCount>0 do begin
      AControl:=Controls[ControlCount-1];
      debugln(['TAnchorDockMaster.Destroy: still in list: ',DbgSName(AControl),' Caption="',AControl.Caption,'"']);
      AControl.Free;
    end;
  end;
  FreeAndNil(fNeedSimplify);
  FreeAndNil(FControls);
  FreeAndNil(fNeedFree);
  FreeAndNil(FMapMinimizedControls);
  FreeAndNil(fDisabledAutosizing);
  {$IFDEF VerboseAnchorDocking}
  for i:=0 to ComponentCount-1 do begin
    debugln(['TAnchorDockMaster.Destroy ',i,'/',ComponentCount,' ',DbgSName(Components[i])]);
  end;
  {$ENDIF}
  for i:=0 to ComponentCount-1 do begin
    for j:=0 to ComponentCount-1 do begin
      if i<>j then
        TControl(Components[i]).RemoveAllHandlersOfObject(TControl(Components[j]));
  end;
  end;
  FreeAndNil(FHeaderStyleName2ADHeaderStyle);
  FreeAndNil(FFormStyles);
  inherited Destroy;
end;

function TAnchorDockMaster.ControlCount: integer;
begin
  Result:=FControls.Count;
end;

function TAnchorDockMaster.IndexOfControl(const aName: string): integer;
begin
  Result:=ControlCount-1;
  while (Result>=0) and (Controls[Result].Name<>aName) do dec(Result);
end;

function TAnchorDockMaster.FindControl(const aName: string): TControl;
var
  i: LongInt;
begin
  i:=IndexOfControl(aName);
  if i>=0 then
    Result:=Controls[i]
  else
    Result:=nil;
end;

function TAnchorDockMaster.IsMinimizedControl(AControl: TControl; out
  Site: TAnchorDockHostSite): Boolean;
var
  AIndex: Integer;
begin
  AIndex:=FMapMinimizedControls.IndexOf(AControl);
  if AIndex<0 then begin
    Result:=False;
    Site:=nil;
  end else begin
    Result:=True;
    Site:=TAnchorDockHostSite(FMapMinimizedControls[AControl]);
  end;
end;

function TAnchorDockMaster.IsSite(AControl: TControl): boolean;
begin
  Result:=(AControl is TAnchorDockHostSite) or IsCustomSite(AControl);
end;

function TAnchorDockMaster.IsAnchorSite(AControl: TControl): boolean;
begin
  Result:=AControl is TAnchorDockHostSite;
end;

function TAnchorDockMaster.IsCustomSite(AControl: TControl): boolean;
begin
  Result:=(AControl is TCustomForm) // also checks for nil
      and (AControl.Parent=nil)
      and (TCustomForm(AControl).DockManager is TAnchorDockManager);
end;

function TAnchorDockMaster.GetSite(AControl: TControl): TCustomForm;
begin
  Result:=nil;
  if AControl=nil then
    exit
  else if IsCustomSite(AControl) then
    Result:=TCustomForm(AControl)
  else if AControl is TAnchorDockHostSite then
    Result:=TAnchorDockHostSite(AControl)
  else if (AControl.HostDockSite is TAnchorDockHostSite) then
    Result:=TAnchorDockHostSite(AControl.HostDockSite);
end;

function TAnchorDockMaster.GetAnchorSite(AControl: TControl): TAnchorDockHostSite;
begin
  Result:=nil;
  if AControl=nil then
    Result:=nil
  else if AControl is TAnchorDockHostSite then
    Result:=TAnchorDockHostSite(AControl)
  else if (AControl.HostDockSite is TAnchorDockHostSite) then
    Result:=TAnchorDockHostSite(AControl.HostDockSite);
end;

function TAnchorDockMaster.GetControl(Site: TControl): TControl;
var
  AnchorSite: TAnchorDockHostSite;
begin
  Result:=nil;
  if IsCustomSite(Site) then
    Result:=Site
  else if Site is TAnchorDockHostSite then begin
    AnchorSite:=TAnchorDockHostSite(Site);
    if AnchorSite.SiteType=adhstOneControl then
      Result:=AnchorSite.GetOneControl;
  end else if (Site<>nil) and (Site.HostDockSite is TAnchorDockHostSite)
  and (TAnchorDockHostSite(Site.HostDockSite).SiteType=adhstOneControl) then
    Result:=Site;
end;

function TAnchorDockMaster.IsFloating(AControl: TControl): Boolean;
begin
  if AControl is TAnchorDockHostSite then begin
    Result:=(TAnchorDockHostSite(AControl).SiteType=adhstOneControl)
            and (AControl.Parent=nil);
  end else if (AControl.HostDockSite is TAnchorDockHostSite) then begin
    Result:=(TAnchorDockHostSite(AControl.HostDockSite).SiteType=adhstOneControl)
        and (AControl.HostDockSite.Parent=nil);
  end else
    Result:=AControl.Parent=nil;
end;

function TAnchorDockMaster.GetPopupMenu: TPopupMenu;
begin
  if fPopupMenu=nil then begin
    fPopupMenu:=TPopupMenu.Create(Self);
    fPopupMenu.OnPopup:=@PopupMenuPopup;
  end;
  Result:=fPopupMenu;
end;

function TAnchorDockMaster.AddPopupMenuItem(AName, ACaption: string;
  const OnClickEvent: TNotifyEvent; AParent: TMenuItem): TMenuItem;
begin
  Result:=TMenuItem(fPopupMenu.FindComponent(AName));
  if Result=nil then begin
    Result:=TMenuItem.Create(fPopupMenu);
    Result.Name:=AName;
    if AParent=nil then
      fPopupMenu.Items.Add(Result)
    else
      AParent.Add(Result);
  end;
  Result.Caption:=ACaption;
  Result.OnClick:=OnClickEvent;
end;

function TAnchorDockMaster.AddRemovePopupMenuItem(Add: boolean; AName,
  ACaption: string; const OnClickEvent: TNotifyEvent; AParent: TMenuItem
  ): TMenuItem;
begin
  if Add then
    Result:=AddPopupMenuItem(AName,ACaption,OnClickEvent,AParent)
  else begin
    Result:=TMenuItem(fPopupMenu.FindComponent(AName));
    if Result<>nil then
      FreeAndNil(Result);
  end;
end;

procedure TAnchorDockMaster.MakeDockable(AControl: TControl; Show: boolean;
  BringToFront: boolean; AddDockHeader: boolean);
var
  Site: TAnchorDockHostSite;
begin
  if AControl.Name='' then
    raise Exception.Create('TAnchorDockMaster.MakeDockable '+
      adrsMissingControlName);
  if (AControl is TCustomForm) and (fsModal in TCustomForm(AControl).FormState)
  then
    raise Exception.Create('TAnchorDockMaster.MakeDockable '+
      adrsModalFormsCanNotBeMadeDockable);
  if IsCustomSite(AControl) then
    raise Exception.Create('TAnchorDockMaster.MakeDockable '+
      adrsControlIsAlreadyADocksite);
  Site:=nil;
  AControl.DisableAutoSizing{$IFDEF DebugDisableAutoSizing}('TAnchorDockMaster.DisableControlAutoSizing'){$ENDIF};
  try
    if AControl is TAnchorDockHostSite then begin
      // already a site
      Site:=TAnchorDockHostSite(AControl);
    end else if AControl.Parent=nil then
      if IsMinimizedControl(AControl, Site) then begin
        Site.AsyncMinimizeSite(0);
      end else begin

        if FControls.IndexOf(AControl)<0 then begin
          FControls.Add(AControl);
          AControl.FreeNotification(Self);
        end;

        // create docksite
        Site:=CreateSite;
        try
          try
            Site.BoundsRect:=AControl.BoundsRect;
            ClearLayoutProperties(AControl);
            // dock
            AControl.ManualDock(Site);
            AControl.Visible:=true;
            if not AddDockHeader then
              Site.Header.Parent:=nil;
          except
            FreeAndNil(Site);
            raise;
          end;
        finally
          if Site<>nil then
            Site.EnableAutoSizing{$IFDEF DebugDisableAutoSizing}(ADAutoSizingReason){$ENDIF};
        end;
    end else if AControl.Parent is TAnchorDockHostSite then begin
      // AControl is already docked => show site
      Site:=TAnchorDockHostSite(AControl.Parent);
      AControl.Visible:=true;
    end else begin
      raise Exception.Create('TAnchorDockMaster.MakeDockable '+Format(
        adrsNotSupportedHasParent, [DbgSName(AControl), DbgSName(AControl)]));
    end;
    site.UpdateHeaderShowing;
    if (Site<>nil) and Show then
      MakeVisible(Site,BringToFront);
  finally
    AControl.EnableAutoSizing{$IFDEF DebugDisableAutoSizing}('TAnchorDockMaster.DisableControlAutoSizing'){$ENDIF};
  end;
  // BringToFront
  if Show and BringToFront and (Site<>nil) then begin
    GetParentForm(Site).BringToFront;
    Site.SetFocus;
  end;
end;

procedure TAnchorDockMaster.MakeDockSite(AForm: TCustomForm; Sites: TAnchors;
  ResizePolicy: TADMResizePolicy; AllowInside: boolean);
var
  AManager: TAnchorDockManager;
begin
  if AForm.Name='' then
    raise Exception.Create('TAnchorDockMaster.MakeDockSite '+
      adrsMissingControlName);
  if AForm.DockManager<>nil then
    raise Exception.Create('TAnchorDockMaster.MakeDockSite DockManager<>nil');
  if AForm.Parent<>nil then
    raise Exception.Create('TAnchorDockMaster.MakeDockSite Parent='+DbgSName(AForm.Parent));
  if fsModal in AForm.FormState then
    raise Exception.Create('TAnchorDockMaster.MakeDockSite '+
      adrsModalFormsCanNotBeMadeDockable);
  if Sites=[] then
    raise Exception.Create('TAnchorDockMaster.MakeDockSite Sites=[]');
  AForm.DisableAutoSizing{$IFDEF DebugDisableAutoSizing}('TAnchorDockMaster.MakeDockSite'){$ENDIF};
  try
    if FControls.IndexOf(AForm)<0 then begin
      FControls.Add(AForm);
      AForm.FreeNotification(Self);
    end;
    AManager:=ManagerClass.Create(AForm);
    AManager.DockableSites:=Sites;
    AManager.InsideDockingAllowed:=AllowInside;
    AManager.ResizePolicy:=ResizePolicy;
    AForm.DockManager:=AManager;
    AForm.UseDockManager:=true;
    AForm.DockSite:=true;
  finally
    AForm.EnableAutoSizing{$IFDEF DebugDisableAutoSizing}('TAnchorDockMaster.MakeDockSite'){$ENDIF};
  end;
end;

procedure TAnchorDockMaster.MakeDockPanel(APanel:TAnchorDockPanel;
                                          ResizePolicy: TADMResizePolicy);
var
  AManager: TAnchorDockManager;
begin
  if APanel.Name='' then
    raise Exception.Create('TAnchorDockMaster.MakeDockPanel '+
      adrsMissingControlName);
  if APanel.DockManager<>nil then
    raise Exception.Create('TAnchorDockMaster.MakeDockPanel DockManager<>nil');
  APanel.DisableAutoSizing{$IFDEF DebugDisableAutoSizing}('TAnchorDockMaster.MakeDockPanel'){$ENDIF};
  try
    if FControls.IndexOf(APanel)<0 then begin
      FControls.Add(APanel);
      APanel.FreeNotification(Self);
    end;
    AManager:=ManagerClass.Create(APanel);
    AManager.DockableSites:=[];
    AManager.InsideDockingAllowed:=true;
    AManager.ResizePolicy:=ResizePolicy;
    APanel.DockManager:=AManager;
    APanel.UseDockManager:=true;
    APanel.DockSite:=true;
  finally
    APanel.EnableAutoSizing{$IFDEF DebugDisableAutoSizing}('TAnchorDockMaster.MakeDockPanel'){$ENDIF};
  end;
end;

procedure TAnchorDockMaster.MakeVisible(AControl: TControl; SwitchPages: boolean);
begin
  while AControl<>nil do begin
    if FMapMinimizedControls.IndexOf(AControl)>=0 then begin
      AControl:=TAnchorDockHostSite(FMapMinimizedControls[AControl]);
      TAnchorDockHostSite(AControl).MinimizeSite;
    end;
    AControl.Visible:=true;
    if SwitchPages and (AControl is TAnchorDockPage) then
      TAnchorDockPageControl(AControl.Parent).PageIndex:=
        TAnchorDockPage(AControl).PageIndex;
    AControl:=AControl.Parent;
  end;
end;

function TAnchorDockMaster.ShowControl(ControlName: string;
  BringToFront: boolean): TControl;
begin
  Result:=DoCreateControl(ControlName,false);
  if Result=nil then exit;
  MakeDockable(Result,true,BringToFront);
end;

procedure TAnchorDockMaster.CloseAll;
var
  i: Integer;
  AForm: TCustomForm;
  AControl: TWinControl;
begin
  FAllClosing:=True;
  // hide all forms
  i:=Screen.CustomFormCount-1;
  while i>=0 do begin
    AForm:=GetParentForm(Screen.CustomForms[i]);
    if Assigned(AForm)then
      AForm.Hide;
    i:=Min(i,Screen.CustomFormCount)-1;
  end;

  // close all forms except the MainForm
  i:=Screen.CustomFormCount-1;
  while i>=0 do begin
    AForm:=Screen.CustomForms[i];
    if (AForm<>Application.MainForm) and not AForm.IsParentOf(Application.MainForm)
    then begin
      AControl:=AForm;
      while (AControl.Parent<>nil)
      and (AControl.Parent<>Application.MainForm) do begin
        AControl:=AControl.Parent;
        if AControl is TCustomForm then AForm:=TCustomForm(AControl);
      end;
      AForm.Close;
    end;
    i:=Min(i,Screen.CustomFormCount)-1;
  end;
  FAllClosing:=False;
end;

procedure TAnchorDockMaster.SaveLayoutToConfig(Config: TConfigStorage);
var
  Tree: TAnchorDockLayoutTree;
begin
  Tree:=TAnchorDockLayoutTree.Create;
  try
    Config.AppendBasePath('MainConfig/');
    SaveMainLayoutToTree(Tree);
    Tree.SaveToConfig(Config);
    Config.UndoAppendBasePath;
    Config.AppendBasePath('Restores/');
    RestoreLayouts.SaveToConfig(Config);
    Config.UndoAppendBasePath;
    {$IFDEF VerboseAnchorDocking}
    WriteDebugLayout('TAnchorDockMaster.SaveLayoutToConfig ',Tree.Root);
    {$ENDIF}
    //DebugWriteChildAnchors(Tree.Root);
  finally
    Tree.Free;
  end;
end;

function GetParentFormOrDockPanel(Control: TControl; TopForm:Boolean=true): TCustomForm;
var
  oldControl: TControl;
begin
  oldControl:=Control;
  while (Control <> nil) and (Control.Parent <> nil) do
  begin
    if (Control is TAnchorDockPanel) then
      Break;
    Control := Control.Parent;
  end;
  if Control is TCustomForm then
    Result := TCustomForm(Control)
  else if Control is TAnchorDockPanel then
    Result := TCustomForm(Control)
  else
    Result := nil;
  if not TopForm then begin
    if Control is TAnchorDockPanel then
      exit;
    Control:=oldControl;
    while (Control <> nil) and (Control.Parent <> nil) do
    begin
      Control := Control.Parent;
      if (Control is TCustomForm) then
        Break;
    end;
    Result := TCustomForm(Control);
  end;
end;

procedure TAnchorDockMaster.SaveMainLayoutToTree(LayoutTree: TAnchorDockLayoutTree);
var
  i: Integer;
  AControl: TControl;
  Site: TAnchorDockHostSite;
  SavedSites: TFPList;
  LayoutNode: TAnchorDockLayoutTreeNode;
  AFormOrDockPanel: TWinControl;
  VisibleControls: TStringListUTF8Fast;

  procedure SaveFormOrDockPanel(theFormOrDockPanel: TWinControl; SaveChildren: boolean; AMinimized:boolean);
  begin
    // custom dock site
    LayoutNode:=LayoutTree.NewNode(LayoutTree.Root);
    LayoutNode.NodeType:=adltnCustomSite;
    LayoutNode.Assign(theFormOrDockPanel,theFormOrDockPanel is TAnchorDockPanel,AMinimized);
    // can have one normal dock site
    if SaveChildren then
    begin
      Site:=TAnchorDockManager(theFormOrDockPanel.DockManager).GetChildSite;
      if Site<>nil then begin
        LayoutNode:=LayoutTree.NewNode(LayoutNode);
        Site.SaveLayout(LayoutTree,LayoutNode);
        {if Site.BoundSplitter<>nil then begin
          LayoutNode:=LayoutTree.NewNode(LayoutNode);
          Site.BoundSplitter.SaveLayout(LayoutNode);
        end;}
      end;
    end;
  end;

begin
  SavedSites:=TFPList.Create;
  VisibleControls:=TStringListUTF8Fast.Create;
  try
    for i:=0 to ControlCount-1 do begin
      AControl:=Controls[i];
      if not DockedControlIsVisible(AControl) then continue;
      VisibleControls.Add(AControl.Name);
      AFormOrDockPanel:=GetParentFormOrDockPanel(AControl);
      if AFormOrDockPanel=nil then continue;
      if SavedSites.IndexOf(AFormOrDockPanel)>=0 then continue;
      SavedSites.Add(AFormOrDockPanel);
      {$IFDEF VerboseAnchorDockRestore}
      debugln(['TAnchorDockMaster.SaveMainLayoutToTree AForm=',DbgSName(AFormOrDockPanel)]);
      DebugWriteChildAnchors(AFormOrDockPanel,true,true);
      {$ENDIF}
      if AFormOrDockPanel is TAnchorDockPanel then begin
        SaveFormOrDockPanel(GetParentFormOrDockPanel(AFormOrDockPanel),true,false);
        //LayoutNode:=LayoutTree.NewNode(LayoutTree.Root);
        //TAnchorDockPanel(AFormOrDockPanel).SaveLayout(LayoutTree,LayoutNode);
      end else if AFormOrDockPanel is TAnchorDockHostSite then begin
        Site:=TAnchorDockHostSite(AFormOrDockPanel);
        LayoutNode:=LayoutTree.NewNode(LayoutTree.Root);
        Site.SaveLayout(LayoutTree,LayoutNode);
      end else if IsCustomSite(AFormOrDockPanel) then begin
        SaveFormOrDockPanel(AFormOrDockPanel,true,false);
      end else
        raise EAnchorDockLayoutError.Create('invalid root control for save: '+DbgSName(AControl));
    end;
    // remove invisible controls
    LayoutTree.Root.Simplify(VisibleControls,false);
  finally
    VisibleControls.Free;
    SavedSites.Free;
  end;
end;

procedure TAnchorDockMaster.SaveSiteLayoutToTree(AControl: TWinControl;
  LayoutTree: TAnchorDockLayoutTree);
var
  LayoutNode: TAnchorDockLayoutTreeNode;
  Site: TAnchorDockHostSite;
begin
  if AControl is TAnchorDockHostSite then begin
    Site:=TAnchorDockHostSite(AControl);
    Site.SaveLayout(LayoutTree,LayoutTree.Root);
  end else if AControl is TAnchorDockPanel then begin
    (AControl as TAnchorDockPanel).SaveLayout(LayoutTree,LayoutTree.Root);
  end else if IsCustomSite(AControl) then begin
    LayoutTree.Root.NodeType:=adltnCustomSite;
    LayoutTree.Root.Assign(AControl,false,false);
    // can have one normal dock site
    Site:=TAnchorDockManager(AControl.DockManager).GetChildSite;
    if Site<>nil then begin
      LayoutNode:=LayoutTree.NewNode(LayoutTree.Root);
      Site.SaveLayout(LayoutTree,LayoutNode);
    end;
  end else
    raise EAnchorDockLayoutError.Create('invalid root control for save: '+DbgSName(AControl));
end;

function TAnchorDockMaster.CreateRestoreLayout(AControl: TControl
  ): TAnchorDockRestoreLayout;
{ Create a restore layout for AControl and its child controls.
  It contains the whole parent structure so that the restore knows where to
  put AControl.
}

  procedure AddControlNames(SubControl: TControl;
    RestoreLayout: TAnchorDockRestoreLayout);
  var
    i: Integer;
  begin
    if (FControls.IndexOf(SubControl)>=0)
    and not RestoreLayout.HasControlName(SubControl.Name) then
      RestoreLayout.ControlNames.Add(SubControl.Name);
    if SubControl is TWinControl then
      for i:=0 to TWinControl(SubControl).ControlCount-1 do
        AddControlNames(TWinControl(SubControl).Controls[i],RestoreLayout);
  end;

var
  AForm: TCustomForm;
begin
  if not IsSite(AControl) then
    raise Exception.Create('TAnchorDockMaster.CreateRestoreLayout: not a site '+DbgSName(AControl));
  AForm:=GetParentFormOrDockPanel(AControl);
  Result:=TAnchorDockRestoreLayout.Create(TAnchorDockLayoutTree.Create);
  if AForm=nil then exit;
  SaveSiteLayoutToTree(AForm,Result.Layout);
  AddControlNames(AControl,Result);
end;

function TAnchorDockMaster.ConfigIsEmpty(Config: TConfigStorage): boolean;
begin
  Result:=Config.GetValue('MainConfig/Nodes/ChildCount',0)=0;
end;

function TAnchorDockMaster.LoadLayoutFromConfig(Config: TConfigStorage;
  Scale: Boolean): boolean;
var
  Tree: TAnchorDockLayoutTree;
  ControlNames: TStringListUTF8Fast;
begin
  Result:=false;
  ControlNames:=TStringListUTF8Fast.Create;
  fTreeNameToDocker:=TADNameToControl.Create;
  Tree:=TAnchorDockLayoutTree.Create;
  try
    // load layout
    Config.AppendBasePath('MainConfig/');
    try
      Tree.LoadFromConfig(Config);
    finally
      Config.UndoAppendBasePath;
    end;
    // load restore layouts for hidden forms
    Config.AppendBasePath('Restores/');
    try
      RestoreLayouts.LoadFromConfig(Config);
    finally
      Config.UndoAppendBasePath;
    end;

    {$IFDEF VerboseAnchorDockRestore}
    WriteDebugLayout('TAnchorDockMaster.LoadLayoutFromConfig ',Tree.Root);
    DebugWriteChildAnchors(Tree.Root);
    {$ENDIF}

    // close all unneeded and wrongly allocated forms/controls (not helper controls like splitters)
    MarkCorrectlyLocatedControl(Tree);
    if not CloseUnneededAndWronglyLocatedControls(Tree) then exit;

    BeginUpdate;
    try
      // create all needed forms/controls (not helper controls like splitters)
      if not CreateNeededControls(Tree,true,ControlNames) then exit;

      // simplify layouts
      ControlNames.Sort;
      {$IFDEF VerboseAnchorDockRestore}
      debugln(['TAnchorDockMaster.LoadLayoutFromConfig controls: ']);
      debugln(ControlNames.Text);
      {$ENDIF}
      // if some forms/controls could not be created the layout needs to be adapted
      Tree.Root.Simplify(ControlNames,false);

      // reuse existing sites to reduce flickering
      MapTreeToControls(Tree);
      {$IFDEF VerboseAnchorDockRestore}
      fTreeNameToDocker.WriteDebugReport('TAnchorDockMaster.LoadLayoutFromConfig Map');
      {$ENDIF}

      // create sites, move controls
      RestoreLayout(Tree,Scale);
      SetMinimizedState(Tree);
    finally
      EndUpdate;
    end;
  finally
    // clean up
    FreeAndNil(fTreeNameToDocker);
    ControlNames.Free;
    Tree.Free;
    // commit (this can raise an exception)
    EnableAllAutoSizing;
  end;
  {$IFDEF VerboseAnchorDockRestore}
  if Assigned(Application.MainForm) then
    DebugWriteChildAnchors(Application.MainForm,true,false)
  else
  if (ControlCount>0) and (Controls[0] is TWinControl) then
    DebugWriteChildAnchors(TWinControl(Controls[0]),true,false);
  {$ENDIF}
  Result:=true;
end;

procedure TAnchorDockMaster.LoadSettingsFromConfig(Config: TConfigStorage);
var
  Settings: TAnchorDockSettings;
begin
  Settings:=TAnchorDockSettings.Create;
  try
    Settings.LoadFromConfig(Config);
    LoadSettings(Settings);
  finally
    Settings.Free;
  end;
end;

procedure TAnchorDockMaster.SaveSettingsToConfig(Config: TConfigStorage);
var
  Settings: TAnchorDockSettings;
begin
  Settings:=TAnchorDockSettings.Create;
  try
    SaveSettings(Settings);
    Settings.SaveToConfig(Config);
  finally
    Settings.Free;
  end;
end;

procedure TAnchorDockMaster.LoadSettings(Settings: TAnchorDockSettings);
begin
  AllowDragging                    := Settings.AllowDragging;
  DockOutsideMargin                := Settings.DockOutsideMargin;
  DockParentMargin                 := Settings.DockParentMargin;
  DockSitesCanBeMinimized          := Settings.DockSitesCanBeMinimized;
  DragTreshold                     := Settings.DragTreshold;
  FloatingWindowsOnTop             := Settings.FloatingWindowsOnTop;
  PageAreaInPercent                := Settings.PageAreaInPercent;
  HeaderAlignLeft                  := Settings.HeaderAlignLeft;
  HeaderAlignTop                   := Settings.HeaderAlignTop;
  HeaderFilled                     := Settings.HeaderFilled;
  HeaderFlatten                    := Settings.HeaderFlatten;
  HeaderHighlightFocused           := Settings.HeaderHighlightFocused;
  HeaderStyle                      := Settings.HeaderStyle;
  HideHeaderCaptionFloatingControl := Settings.HideHeaderCaptionFloatingControl;
  MultiLinePages                   := Settings.MultiLinePages;
  ScaleOnResize                    := Settings.ScaleOnResize;
  ShowHeader                       := Settings.ShowHeader;
  ShowHeaderCaption                := Settings.ShowHeaderCaption;
  SplitterWidth                    := Settings.SplitterWidth;
end;

procedure TAnchorDockMaster.SaveSettings(Settings: TAnchorDockSettings);
begin
  Settings.AllowDragging                    := AllowDragging;
  Settings.DockOutsideMargin                := DockOutsideMargin;
  Settings.DockParentMargin                 := DockParentMargin;
  Settings.DockSitesCanBeMinimized          := DockSitesCanBeMinimized;
  Settings.DragTreshold                     := DragTreshold;
  Settings.FloatingWindowsOnTop             := FloatingWindowsOnTop;
  Settings.PageAreaInPercent                := PageAreaInPercent;
  Settings.HeaderAlignLeft                  := HeaderAlignLeft;
  Settings.HeaderAlignTop                   := HeaderAlignTop;
  Settings.HeaderFilled                     := HeaderFilled;
  Settings.HeaderFlatten                    := HeaderFlatten;
  Settings.HeaderHighlightFocused           := HeaderHighlightFocused;
  Settings.HeaderStyle                      := HeaderStyle;
  Settings.HideHeaderCaptionFloatingControl := HideHeaderCaptionFloatingControl;
  Settings.MultiLinePages                   := MultiLinePages;
  Settings.ScaleOnResize                    := ScaleOnResize;
  Settings.ShowHeader                       := ShowHeader;
  Settings.ShowHeaderCaption                := ShowHeaderCaption;
  Settings.SplitterWidth                    := SplitterWidth;
end;

function TAnchorDockMaster.SettingsAreEqual(Settings: TAnchorDockSettings
  ): boolean;
var
  Cur: TAnchorDockSettings;
begin
  Cur:=TAnchorDockSettings.Create;
  try
    SaveSettings(Cur);
    Result:=Cur.IsEqual(Settings);
  finally
    Cur.Free;
  end;
end;

procedure TAnchorDockMaster.ManualFloat(AControl: TControl);
var
  Site: TAnchorDockHostSite;
begin
  Site:=GetAnchorSite(AControl);
  if Site=nil then exit;
  Site.Undock;
end;

procedure TAnchorDockMaster.ManualDock(SrcSite: TAnchorDockHostSite;
  TargetSite: TCustomForm; Align: TAlign; TargetControl: TControl);
var
  Site: TAnchorDockHostSite;
  aManager: TAnchorDockManager;
  DockObject: TDragDockObject;
begin
  {$IFDEF VerboseAnchorDocking}
  debugln(['TAnchorDockMaster.ManualDock SrcSite=',DbgSName(SrcSite),' TargetSite=',DbgSName(TargetSite),' Align=',dbgs(Align),' TargetControl=',DbgSName(TargetControl)]);
  {$ENDIF}
  if SrcSite=TargetSite then exit;
  if SrcSite.IsParentOf(TargetSite) then
    raise Exception.Create('TAnchorDockMaster.ManualDock SrcSite.IsParentOf(TargetSite)');
  if TargetSite.IsParentOf(SrcSite) then
    raise Exception.Create('TAnchorDockMaster.ManualDock TargetSite.IsParentOf(SrcSite)');

  if IsCustomSite(TargetSite) then begin
    aManager:=TAnchorDockManager(TargetSite.DockManager);
    Site:=aManager.GetChildSite;
    if Site=nil then begin
      // dock as first site into custom dock site
      {$IFDEF VerboseAnchorDocking}
      debugln(['TAnchorDockMaster.ManualDock dock as first site into custom dock site: SrcSite=',DbgSName(SrcSite),' TargetSite=',DbgSName(TargetSite),' Align=',dbgs(Align)]);
      {$ENDIF}
      BeginUpdate;
      try
        DockObject := TDragDockObject.Create(SrcSite);
        try
          DockObject.DropAlign:=Align;
          DockObject.DockRect:=SrcSite.BoundsRect;
          DockObject.Control.Dock(TargetSite, SrcSite.BoundsRect);
          aManager.InsertControl(DockObject);
        finally
          DockObject.Free;
        end;
      finally
        EndUpdate;
      end;
      exit;
    end;
    // else: dock into child site of custom dock site
  end else begin
    // dock to or into TargetSite
    if not (TargetSite is TAnchorDockHostSite) then
      raise Exception.Create('TAnchorDockMaster.ManualDock invalid TargetSite');
    Site:=TAnchorDockHostSite(TargetSite);
  end;
  if AutoFreedIfControlIsRemoved(Site,SrcSite) then
    raise Exception.Create('TAnchorDockMaster.ManualDock TargetSite depends on SrcSite');
  BeginUpdate;
  try
    Site.ExecuteDock(SrcSite,TargetControl,Align);
  finally
    EndUpdate;
  end;
end;

procedure TAnchorDockMaster.ManualDock(SrcSite: TAnchorDockHostSite;
  TargetPanel: TAnchorDockPanel; Align: TAlign; TargetControl: TControl);
var
  Site: TAnchorDockHostSite;
  aManager: TAnchorDockManager;
  DockObject: TDragDockObject;
begin
  {$IFDEF VerboseAnchorDocking}
  debugln(['TAnchorDockMaster.ManualDock SrcSite=',DbgSName(SrcSite),' TargetPanel=',DbgSName(TargetPanel),' Align=',dbgs(Align),' TargetControl=',DbgSName(TargetControl)]);
  {$ENDIF}
  if SrcSite.IsParentOf(TargetPanel) then
    raise Exception.Create('TAnchorDockMaster.ManualDock SrcSite.IsParentOf(TargetSite)');
  if TargetPanel.IsParentOf(SrcSite) then
    raise Exception.Create('TAnchorDockMaster.ManualDock TargetSite.IsParentOf(SrcSite)');


  aManager:=TAnchorDockManager(TargetPanel.DockManager);
  Site:=aManager.GetChildSite;
  if Site=nil then begin
    // dock as first site into AnchorDockPanel
    {$IFDEF VerboseAnchorDocking}
    debugln(['TAnchorDockMaster.ManualDock dock as first site into AnchorDockPanel: SrcSite=',DbgSName(SrcSite),' TargetPanel=',DbgSName(TargetPanel),' Align=',dbgs(Align)]);
    {$ENDIF}
    BeginUpdate;
    try
      DockObject := TDragDockObject.Create(SrcSite);
      try
        DockObject.DropAlign:=alClient;
        DockObject.DockRect:=SrcSite.BoundsRect;
        DockObject.Control.Dock(TargetPanel, SrcSite.BoundsRect);
        aManager.InsertControl(DockObject);
      finally
        DockObject.Free;
      end;
    finally
      EndUpdate;
    end;
    exit;
  end;

  if AutoFreedIfControlIsRemoved(Site,SrcSite) then
    raise Exception.Create('TAnchorDockMaster.ManualDock TargetPanel depends on SrcSite');
  BeginUpdate;
  try
    Site.ExecuteDock(SrcSite,TargetControl,Align);
  finally
    EndUpdate;
  end;
end;

function TAnchorDockMaster.ManualEnlarge(Site: TAnchorDockHostSite;
  Side: TAnchorKind; OnlyCheckIfPossible: boolean): boolean;
begin
  Result:=(Site<>nil) and Site.EnlargeSide(Side,OnlyCheckIfPossible);
end;

procedure TAnchorDockMaster.BeginUpdate;
begin
  inc(fUpdateCount);
end;

procedure TAnchorDockMaster.EndUpdate;
begin
  if fUpdateCount<=0 then
    RaiseGDBException('');
  dec(fUpdateCount);
  if fUpdateCount=0 then begin
    SimplifyPendingLayouts;
    UpdateHeaders;
    InvalidateHeaders;
  end;
end;

function TAnchorDockMaster.IsReleasing(AControl: TControl): Boolean;
begin
  Result := fNeedFree.IndexOf(AControl) >= 0;
end;

procedure TAnchorDockMaster.NeedSimplify(AControl: TControl);
begin
  if Self=nil then exit;
  if csDestroying in ComponentState then exit;
  if csDestroying in AControl.ComponentState then exit;
  if fNeedSimplify=nil then exit;
  if fNeedSimplify.IndexOf(AControl)>=0 then exit;
  if not ((AControl is TAnchorDockHostSite)
          or (AControl is TAnchorDockPage))
  then
    exit;
  if Application.Terminated then exit;
  //debugln(['TAnchorDockMaster.NeedSimplify ',DbgSName(AControl),' Caption="',AControl.Caption,'"']);
  fNeedSimplify.Add(AControl);
  AControl.FreeNotification(Self);
  QueueSimplify:=true;
end;

procedure TAnchorDockMaster.NeedFree(AControl: TControl);
begin
  //debugln(['TAnchorDockMaster.NeedFree ',DbgSName(AControl),' ',csDestroying in AControl.ComponentState]);
  if IsReleasing(AControl) then exit;
  if csDestroying in AControl.ComponentState then exit;
  fNeedFree.Add(AControl);
  AControl.DisableAutoSizing{$IFDEF DebugDisableAutoSizing}(ADAutoSizingReason){$ENDIF};
  AControl.Parent:=nil;
  AControl.Visible:=false;
end;

procedure TAnchorDockMaster.SimplifyPendingLayouts;
var
  AControl: TControl;
  Changed: Boolean;
  i: Integer;
begin
  if fSimplifying or (fUpdateCount>0) then exit;
  fSimplifying:=true;
  try
    // simplify layout (do not free controls in this step, only mark them)
    repeat
      Changed:=false;
      i:=fNeedSimplify.Count-1;
      while i>=0 do begin
        AControl:=TControl(fNeedSimplify[i]);
        if (csDestroying in AControl.ComponentState)
        or IsReleasing(AControl) then begin
          fNeedSimplify.Delete(i);
          Changed:=true;
        end else if (AControl is TAnchorDockHostSite) then begin
          //debugln(['TAnchorDockMaster.SimplifyPendingLayouts ',DbgSName(AControl),' ',dbgs(TAnchorDockHostSite(AControl).SiteType),' UpdatingLayout=',TAnchorDockHostSite(AControl).UpdatingLayout]);
          if not TAnchorDockHostSite(AControl).UpdatingLayout then begin
            fNeedSimplify.Delete(i);
            Changed:=true;
            if TAnchorDockHostSite(AControl).SiteType=adhstNone then
            begin
              //debugln(['TAnchorDockMaster.SimplifyPendingLayouts free empty site: ',dbgs(pointer(AControl)),' Caption="',AControl.Caption,'"']);
              NeedFree(AControl);
            end else begin
              TAnchorDockHostSite(AControl).Simplify;
            end;
          end;
        end else if AControl is TAnchorDockPage then begin
          fNeedSimplify.Delete(i);
          Changed:=true;
          NeedFree(AControl);
        end else
          RaiseGDBException('TAnchorDockMaster.SimplifyPendingLayouts inconsistency');
        i:=Min(fNeedSimplify.Count,i)-1;
      end;
    until not Changed;

    // free unneeded controls
    for i := fNeedFree.Count - 1 downto 0 do
      if not (csDestroying in TControl(fNeedFree[i]).ComponentState) then
        Application.ReleaseComponent(TComponent(fNeedFree[i]));
    fNeedFree.Clear;
  finally
    fSimplifying:=false;
  end;
end;

function TAnchorDockMaster.AutoFreedIfControlIsRemoved(AControl,
  RemovedControl: TControl): boolean;
{ returns true if the simplification algorithm will automatically free
     AControl when RemovedControl is removed
  Some sites are dummy sites that were autocreated. They will be auto freed
  if not needed anymore.
  1. A TAnchorDockPage has a TAnchorDockHostSite as child. If the child is freed
     the page will be freed.
  2. When a TAnchorDockPageControl has only one page left the content is moved
     up and the pagecontrol and page will be freed.
  3. When a adhstLayout site has only one child site left, the content is moved up
     and the child site will be freed.
  4. When the control of a adhstOneControl site is freed the site will be freed.
}
var
  ParentSite: TAnchorDockHostSite;
  Page: TAnchorDockPage;
  PageControl: TAnchorDockPageControl;
  OtherPage: TAnchorDockPage;
  Site, Site1, Site2: TAnchorDockHostSite;
begin
  Result:=false;
  if (RemovedControl=nil) or (AControl=nil) then exit;
  while RemovedControl<>nil do begin
    if RemovedControl=AControl then exit(true);
    if RemovedControl is TAnchorDockPage then begin
      // a page will be removed
      Page:=TAnchorDockPage(RemovedControl);
      if not (Page.Parent is TAnchorDockPageControl) then exit;
      PageControl:=TAnchorDockPageControl(Page.Parent);
      if PageControl.PageCount>2 then exit;
      if PageControl.PageCount=2 then begin
        // this pagecontrol will be replaced by the content of the other page
        if PageControl=AControl then exit(true);
        if PageControl.Page[0]=Page then
          OtherPage:=PageControl.DockPages[1]
        else
          OtherPage:=PageControl.DockPages[0];
        // the other page will be removed (its content will be moved up)
        if OtherPage=AControl then exit(true);
        if (OtherPage.ControlCount>0) then begin
          if (OtherPage.Controls[0] is TAnchorDockHostSite)
          and (OtherPage.Controls[0]=RemovedControl) then
            exit(true); // the site of the other page will be removed (its content moved up)
        end;
        exit;
      end;
      // the last page of the pagecontrol is freed => the pagecontrol will be removed too
    end else if RemovedControl is TAnchorDockPageControl then begin
      // the pagecontrol will be removed
      if not (RemovedControl.Parent is TAnchorDockHostSite) then exit;
      // a pagecontrol is always the only child of a site
      // => the site will be removed too
    end else if RemovedControl is TAnchorDockHostSite then begin
      // a site will be removed
      Site:=TAnchorDockHostSite(RemovedControl);
      if Site.Parent is TAnchorDockPage then begin
        // a page has only one site
        // => the page will be removed too
      end else if Site.Parent is TAnchorDockHostSite then begin
        ParentSite:=TAnchorDockHostSite(Site.Parent);
        if (ParentSite.SiteType=adhstOneControl)
        or ParentSite.IsOneSiteLayout(Site) then begin
          // the control of a OneControl site is removed => the ParentSite is freed too
        end else if ParentSite.SiteType=adhstLayout then begin
          if ParentSite.IsTwoSiteLayout(Site1,Site2) then begin
            // when there are two sites and one of them is removed
            // the content of the other will be moved up and then both sites are
            // removed
            if (Site1=AControl) or (Site2=AControl) then
              exit(true);
          end;
          exit; // removing only site will not free the layout
        end else begin
          raise Exception.Create('TAnchorDockMaster.AutoFreedIfControlIsRemoved ParentSiteType='+dbgs(ParentSite.SiteType)+' ChildSiteType='+dbgs(Site.SiteType));
        end;
      end else
        exit; // other classes will never be auto freed
    end else begin
      // control is not a site => check if control is in a OneControl site
      if not (RemovedControl.Parent is TAnchorDockHostSite) then exit;
      ParentSite:=TAnchorDockHostSite(RemovedControl.Parent);
      if (ParentSite.SiteType<>adhstOneControl) then exit;
      if ParentSite.GetOneControl<>RemovedControl then exit;
      // the control of a OneControl site is removed => the site is freed too
    end;
    RemovedControl:=RemovedControl.Parent;
  end;
end;

function TAnchorDockMaster.CreateSite(NamePrefix: string;
  DisableAutoSizing: boolean): TAnchorDockHostSite;
var
  i: Integer;
  NewName: String;
begin
  Result:=TAnchorDockHostSite(SiteClass.NewInstance);
  {$IFDEF DebugDisableAutoSizing}
  if DisableAutoSizing then
    Result.DisableAutoSizing(ADAutoSizingReason)
  else
    Result.DisableAutoSizing('TAnchorDockMaster.CreateSite');
  {$ELSE}
  Result.DisableAutoSizing;
  {$ENDIF};
  try
    Result.CreateNew(Self,1);
    i:=0;
    repeat
      inc(i);
      NewName:=NamePrefix+AnchorDockSiteName+IntToStr(i);
    until (Screen.FindForm(NewName)=nil) and (FindComponent(NewName)=nil);
    Result.Name:=NewName;
  finally
    if not DisableAutoSizing then
      Result.EnableAutoSizing{$IFDEF DebugDisableAutoSizing}('TAnchorDockMaster.CreateSite'){$ENDIF};
  end;
end;

function TAnchorDockMaster.CreateSplitter(NamePrefix: string): TAnchorDockSplitter;
var
  i: Integer;
  NewName: String;
begin
  Result:=SplitterClass.Create(Self);
  i:=0;
  repeat
    inc(i);
    NewName:=NamePrefix+AnchorDockSplitterName+IntToStr(i);
  until FindComponent(NewName)=nil;
  Result.Name:=NewName;
end;

procedure TAnchorDockMaster.IncreaseOptionsChangeStamp;
begin
  LUIncreaseChangeStamp64(FOptionsChangeStamp);
end;

procedure TAnchorDockMaster.UpdateHeaders;
var
  i: Integer;
  AControl: TControl;
begin
  for i:=0 to ControlCount-1 do begin
    AControl:=Controls[i];
    while Assigned(AControl) do
    begin
      if AControl is TAnchorDockHostSite then
        TAnchorDockHostSite(AControl).UpdateHeaderShowing;
      AControl:=AControl.Parent;
    end;
  end;
end;

{ TAnchorDockHostSite }

procedure TAnchorDockHostSite.SetHeaderSide(const AValue: TAnchorKind);
begin
  if FHeaderSide=AValue then exit;
  FHeaderSide:=AValue;
end;

function TAnchorDockHostSite.GetMinimized: Boolean;
begin
  Result:=Assigned(FMinimizedControl);
end;

procedure TAnchorDockHostSite.CheckFormStyle;
var
  AControl: TControl;
  AForm: TCustomForm absolute AControl;
  IsMainDockForm: Boolean;
begin
  AControl := GetOneControl;
  if not (AControl is TCustomForm) then Exit;
  if AForm.FormStyle in fsAllStayOnTop then
  begin
    FormStyle := AForm.FormStyle;
    Exit;
  end;
  if not DockMaster.FloatingWindowsOnTop then
    Exit;
  IsMainDockForm := (AForm = DockMaster.MainDockForm)
                or (AForm.IsParentOf(DockMaster.MainDockForm))
                or (GetParentForm(AForm) = DockMaster.MainDockForm);
  if IsMainDockForm then Exit;
  FormStyle := fsStayOnTop;
end;

procedure TAnchorDockHostSite.FirstShow(Sender: TObject);
begin
  if Sender <> Self then Exit;
  CheckFormStyle;
end;

procedure TAnchorDockHostSite.ChildVisibleChanged(Sender: TObject);
var
  AControl: TControl;
begin
  if Sender is TControl then begin
    AControl:=TControl(Sender);
    if not (csDestroying in ComponentState) then begin
      if (not AControl.Visible)
      and (not Minimized)
      and (not ((AControl is TAnchorDockHeader)
               or (AControl is TAnchorDockSplitter)
               or (AControl is TAnchorDockHostSite)))
      then begin
        //debugln(['TAnchorDockHostSite.ChildVisibleChanged START ',Caption,' ',dbgs(SiteType),' ',DbgSName(AControl),' UpdatingLayout=',UpdatingLayout]);
        if (SiteType=adhstOneControl) then
          Hide
        else if (SiteType=adhstLayout) then begin
          RemoveControlFromLayout(AControl);
          UpdateDockCaption;
        end;
        //debugln(['TAnchorDockHostSite.ChildVisibleChanged END ',Caption,' ',dbgs(SiteType),' ',DbgSName(AControl)]);
      end;
    end;
  end;
end;

procedure TAnchorDockHostSite.DoEnter;
begin
  inherited;
  if Assigned(FHeader) then
    FHeader.FFocused:=true;
  invalidate;
end;

procedure TAnchorDockHostSite.DoExit;
begin
  inherited;
  if Assigned(FHeader) then
    FHeader.FFocused:=false;
  invalidate;
end;

procedure TAnchorDockHostSite.Notification(AComponent: TComponent;
  Operation: TOperation);
begin
  inherited Notification(AComponent, Operation);
  if Operation=opRemove then begin
    if AComponent=Pages then FPages:=nil;
    if AComponent=Header then FHeader:=nil;
    if AComponent=BoundSplitter then FBoundSplitter:=nil;
  end;
end;

function TAnchorDockHostSite.DoDockClientMsg(DragDockObject: TDragDockObject;
  aPosition: TPoint): boolean;
begin
  if aPosition.X=0 then ;
  Result:=ExecuteDock(DragDockObject.Control,DragDockObject.DropOnControl,
                      DragDockObject.DropAlign);
end;

function TAnchorDockHostSite.ExecuteDock(NewControl, DropOnControl: TControl;
  DockAlign: TAlign): boolean;
begin
  if UpdatingLayout then exit;
  //debugln(['TAnchorDockHostSite.ExecuteDock Self="',Caption,'"  Control=',DbgSName(NewControl),' DropOnControl=',DbgSName(DropOnControl),' Align=',dbgs(DockAlign)]);

  DisableAutoSizing{$IFDEF DebugDisableAutoSizing}('TAnchorDockHostSite.ExecuteDock HostSite'){$ENDIF};
  try
    BeginUpdateLayout;
    try
      DockMaster.SimplifyPendingLayouts;
      NewControl.DisableAutoSizing{$IFDEF DebugDisableAutoSizing}('TAnchorDockHostSite.ExecuteDock NewControl'){$ENDIF};

      if (NewControl.Parent=Self) and (SiteType=adhstLayout) then begin
        // change of layout, one child is docked to the outer side
        RemoveControlFromLayout(NewControl);
      end else if (NewControl.Parent=Parent) and (Parent is TAnchorDockHostSite)
      and (TAnchorDockHostSite(Parent).SiteType=adhstLayout) then begin
        // change of layout, one sibling is moved
        TAnchorDockHostSite(Parent).RemoveControlFromLayout(NewControl);
      end;

      if SiteType=adhstNone then begin
        // make a control dockable by docking it into a TAnchorDockHostSite;
        Result:=DockFirstControl(NewControl);
      end else if DockAlign=alClient then begin
        // page docking
        if SiteType=adhstOneControl then begin
          if Parent is TAnchorDockPage then begin
            // add as sibling page
            Result:=(Parent.Parent.Parent as TAnchorDockHostSite).DockAnotherPage(NewControl,nil);
          end else
            // create pages
            Result:=DockSecondPage(NewControl);
        end else if SiteType=adhstPages then
          // add as sibling page
          Result:=DockAnotherPage(NewControl,DropOnControl);
      end else if DockAlign in [alLeft,alTop,alRight,alBottom] then
      begin
        // anchor docking
        if SiteType=adhstOneControl then begin
          if Parent is TAnchorDockHostSite then begin
            // add site as sibling
            Result:=TAnchorDockHostSite(Parent).DockAnotherControl(Self,NewControl,
                      DockAlign,DropOnControl<>nil);
          end else
            // create layout
            Result:=DockSecondControl(NewControl,DockAlign,DropOnControl<>nil);
        end else if SiteType=adhstLayout then
          // add site as sibling
          Result:=DockAnotherControl(nil,NewControl,DockAlign,DropOnControl<>nil);
      end;

      NewControl.EnableAutoSizing{$IFDEF DebugDisableAutoSizing}('TAnchorDockHostSite.ExecuteDock NewControl'){$ENDIF};
    finally
      EndUpdateLayout;
    end;
  finally
    EnableAutoSizing{$IFDEF DebugDisableAutoSizing}('TAnchorDockHostSite.ExecuteDock HostSite'){$ENDIF};
  end;
end;

function TAnchorDockHostSite.DockFirstControl(NewControl: TControl): boolean;
var
  DestRect: TRect;
begin
  if SiteType<>adhstNone then
    RaiseGDBException('TAnchorDockHostSite.DockFirstControl inconsistency');
  // create adhstOneControl
  DestRect := ClientRect;
  NewControl.Dock(Self, DestRect);
  FSiteType:=adhstOneControl;
  if NewControl is TCustomForm then begin
    Icon.Assign(TCustomForm(NewControl).Icon);
  end;
  Result:=true;
end;

function TAnchorDockHostSite.DockSecondControl(NewControl: TControl;
  DockAlign: TAlign; Inside: boolean): boolean;
{ Convert a adhstOneControl into a adhstLayout by docking NewControl
  at a side (DockAlign).
  If Inside=true this DockSite is not expanded and both controls share the old space.
  If Inside=false this DockSite is expanded.
}
var
  OldSite: TAnchorDockHostSite;
  OldControl: TControl;
begin
  Result:=true;
  {$IFDEF VerboseAnchorDocking}
  debugln(['TAnchorDockHostSite.DockSecondControl Self="',Caption,'" AControl=',DbgSName(NewControl),' Align=',dbgs(DockAlign),' Inside=',Inside]);
  {$ENDIF}
  if SiteType<>adhstOneControl then
    RaiseGDBException('TAnchorDockHostSite.DockSecondControl inconsistency: not adhstOneControl');
  if not (DockAlign in [alLeft,alTop,alRight,alBottom]) then
    RaiseGDBException('TAnchorDockHostSite.DockSecondControl inconsistency: DockAlign='+dbgs(DockAlign));

  FSiteType:=adhstLayout;

  // remove header (keep it for later use)
  Header.Parent:=nil;

  // put the OldControl into a site of its own (OldSite) and dock OldSite
  OldControl:=GetOneControl;
  OldSite:=MakeSite(OldControl);
  AddCleanControl(OldSite);
  OldSite.AnchorClient(0);
  // the LCL will compute the bounds later after EnableAutoSizing
  // but the bounds are needed now => set them manually
  OldSite.BoundsRect:=Rect(0,0,ClientWidth,ClientHeight);

  Result:=DockAnotherControl(OldSite,NewControl,DockAlign,Inside);
  {$IFDEF VerboseAnchorDocking}
  debugln(['TAnchorDockHostSite.DockSecondControl END Self="',Caption,'" AControl=',DbgSName(NewControl),' Align=',dbgs(DockAlign),' Inside=',Inside]);
  {$ENDIF}
end;

function TAnchorDockHostSite.DockAnotherControl(Sibling, NewControl: TControl;
  DockAlign: TAlign; Inside: boolean): boolean;
var
  Splitter: TAnchorDockSplitter;
  a: TAnchorKind;
  NewSite: TAnchorDockHostSite;
  NewBounds: TRect;
  MainAnchor: TAnchorKind;
  i: Integer;
  NewSiblingWidth: Integer;
  NewSiblingHeight: Integer;
  NewSize: LongInt;
  BoundsIncreased: Boolean;
  NewParentBounds: TRect;
begin
  Result:=false;
  if SiteType<>adhstLayout then
    RaiseGDBException('TAnchorDockHostSite.DockAnotherControl inconsistency');
  if not (DockAlign in [alLeft,alTop,alRight,alBottom]) then
    RaiseGDBException('TAnchorDockHostSite.DockAnotherControl inconsistency');

  // add a splitter
  Splitter:=DockMaster.CreateSplitter;
  if DockAlign in [alLeft,alRight] then begin
    Splitter.ResizeAnchor:=akLeft;
    Splitter.Width:=DockMaster.SplitterWidth;
  end else begin
    Splitter.ResizeAnchor:=akTop;
    Splitter.Height:=DockMaster.SplitterWidth;
  end;
  Splitter.Parent:=Self;

  // dock the NewControl
  NewSite:=MakeSite(NewControl);
  AddCleanControl(NewSite);

  BoundsIncreased:=false;
  if (not Inside) then begin
    if (Parent=nil) then begin
      // expand Self
      NewBounds:=BoundsRect;
      case DockAlign of
      alLeft:
        begin
          dec(NewBounds.Left,NewSite.Width+Splitter.Width);
          MoveAllControls(NewSite.Width+Splitter.Width,0);
        end;
      alRight:
        inc(NewBounds.Right,NewSite.Width+Splitter.Width);
      alTop:
        begin
          dec(NewBounds.Top,NewSite.Height+Splitter.Height);
          MoveAllControls(0,NewSite.Height+Splitter.Height);
        end;
      alBottom:
        inc(NewBounds.Bottom,NewSite.Height+Splitter.Height);
      end;
      BoundsRect:=NewBounds;
      BoundsIncreased:=true;
    end else if DockMaster.IsCustomSite(Parent) then begin
      // Parent is a custom docksite
      // => expand Self and Parent
      // expand Parent (the custom docksite)
      NewParentBounds:=Parent.BoundsRect;
      NewBounds:=BoundsRect;
      case DockAlign of
      alLeft:
        begin
          i:=NewSite.Width+Splitter.Width;
          dec(NewParentBounds.Left,i);
          dec(NewBounds.Left,i);
          MoveAllControls(i,0);
        end;
      alRight:
        begin
          i:=NewSite.Width+Splitter.Width;
          inc(NewBounds.Right,i);
          inc(NewParentBounds.Right,i);
        end;
      alTop:
        begin
          i:=NewSite.Height+Splitter.Height;
          dec(NewBounds.Top,i);
          dec(NewParentBounds.Top,i);
          MoveAllControls(0,i);
        end;
      alBottom:
        begin
          i:=NewSite.Height+Splitter.Height;
          inc(NewParentBounds.Bottom,i);
          inc(NewBounds.Bottom,i);
        end;
      end;
      Parent.BoundsRect:=NewParentBounds;
      BoundsRect:=NewBounds;
      BoundsIncreased:=true;
      TAnchorDockManager(Parent.DockManager).FSiteClientRect:=Parent.ClientRect;
    end;
    {$IFDEF VerboseAnchorDocking}
    debugln(['TAnchorDockHostSite.DockAnotherControl AFTER ENLARGE ',Caption]);
    //DebugWriteChildAnchors(Self,true,true);
    {$ENDIF}
  end;

  // anchors
  MainAnchor:=MainAlignAnchor[DockAlign];
  if Inside and (Sibling<>nil) then begin
    { Example: insert right of Sibling
                    #                                  #
        ################          ########################
            -------+#                -------+#+-------+#
            Sibling|#     ----->     Sibling|#|NewSite|#
            -------+#                -------+#+-------+#
        ################          ########################
                    #                                  #
     }
    for a:=low(TAnchorKind) to high(TAnchorKind) do begin
      if a in AnchorAlign[DockAlign] then begin
        NewSite.AnchorSide[a].Assign(Sibling.AnchorSide[a]);
      end else begin
        NewSite.AnchorToNeighbour(a,0,Splitter);
      end;
    end;
    Sibling.AnchorToNeighbour(MainAnchor,0,Splitter);

    if DockAlign in [alLeft,alRight] then begin
      Splitter.AnchorSide[akTop].Assign(Sibling.AnchorSide[akTop]);
      Splitter.AnchorSide[akBottom].Assign(Sibling.AnchorSide[akBottom]);
      // resize and move
      // the NewSite gets at maximum half the space
      // Many bounds are later set by the LCL anchoring. When docking several
      // controls at once the bounds are needed earlier.
      NewSize:=Max(1,Min(NewSite.Width,Sibling.Width div 2));
      NewBounds:=Rect(0,0,NewSize,Sibling.Height);
      NewSiblingWidth:=Max(1,Sibling.Width-NewSize-Splitter.Width);
      if DockAlign=alLeft then begin
        // alLeft: NewControl, Splitter, Sibling
        Splitter.SetBounds(Sibling.Left+NewSize,Sibling.Top,
                           Splitter.Width,Sibling.Height);
        OffsetRect(NewBounds,Sibling.Left,Sibling.Top);
        Sibling.SetBounds(Splitter.Left+Splitter.Width,Sibling.Top,
                          NewSiblingWidth,Sibling.Height);
      end else begin
        // alRight: Sibling, Splitter, NewControl
        Sibling.Width:=NewSiblingWidth;
        Splitter.SetBounds(Sibling.Left+Sibling.Width,Sibling.Top,
                           Splitter.Width,Sibling.Height);
        OffsetRect(NewBounds,Splitter.Left+Splitter.Width,Sibling.Top);
      end;
      NewSite.BoundsRect:=NewBounds;
    end else begin
      Splitter.AnchorSide[akLeft].Assign(Sibling.AnchorSide[akLeft]);
      Splitter.AnchorSide[akRight].Assign(Sibling.AnchorSide[akRight]);
      // resize and move
      // the NewSite gets at maximum half the space
      // Many bounds are later set by the LCL anchoring. When docking several
      // controls at once the bounds are needed earlier.
      NewSize:=Max(1,Min(NewSite.Height,Sibling.Height div 2));
      NewSiblingHeight:=Max(1,Sibling.Height-NewSize-Splitter.Height);
      if DockAlign=alTop then begin
        // alTop: NewControl, Splitter, Sibling
        Splitter.SetBounds(Sibling.Left,Sibling.Top+NewSize,
                           Sibling.Width,Splitter.Height);
        NewSite.SetBounds(Sibling.Left,Sibling.Top,Sibling.Width,NewSize);
        Sibling.SetBounds(Sibling.Left,Splitter.Top+Splitter.Height,
                          Sibling.Width,NewSiblingHeight);
      end else begin
        // alBottom: Sibling, Splitter, NewControl
        Sibling.Height:=NewSiblingHeight;
        Splitter.SetBounds(Sibling.Left,Sibling.Top+Sibling.Height,
                           Sibling.Width,Splitter.Height);
        NewSite.SetBounds(Sibling.Left,Splitter.Top+Splitter.Height,
                          Sibling.Width,NewSize);
      end;
    end;
  end else begin
    { Example: insert right of all siblings
        ##########         #######################
        --------+#         --------+#+----------+#
        SiblingA|#         SiblingA|#|          |#
        --------+#         --------+#|          |#
        ##########  -----> ##########|NewControl|#
        --------+#         --------+#|          |#
        SiblingB|#         SiblingB|#|          |#
        --------+#         --------+#+----------+#
        ##########         #######################
    }
    if DockAlign in [alLeft,alRight] then
      NewSize:=NewSite.Width
    else
      NewSize:=NewSite.Height;
    for i:=0 to ControlCount-1 do begin
      Sibling:=Controls[i];
      if Sibling.AnchorSide[MainAnchor].Control=Self then begin
        // this Sibling is anchored to the docked site
        // anchor it to the splitter
        Sibling.AnchorToNeighbour(MainAnchor,0,Splitter);
        if not BoundsIncreased then begin
          // the NewSite gets at most half the space
          if DockAlign in [alLeft,alRight] then
            NewSize:=Min(NewSize,Sibling.Width div 2)
          else
            NewSize:=Min(NewSize,Sibling.Height div 2);
        end;
      end;
    end;
    NewSize:=Max(1,NewSize);

    // anchor Splitter and NewSite
    a:=ClockwiseAnchor[MainAnchor];
    Splitter.AnchorParallel(a,0,Self);
    Splitter.AnchorParallel(OppositeAnchor[a],0,Self);
    NewSite.AnchorParallel(a,0,Self);
    NewSite.AnchorParallel(OppositeAnchor[a],0,Self);
    NewSite.AnchorParallel(MainAnchor,0,Self);
    NewSite.AnchorToNeighbour(OppositeAnchor[MainAnchor],0,Splitter);

    // Many bounds are later set by the LCL anchoring. When docking several
    // controls at once the bounds are needed earlier.
    if DockAlign in [alLeft,alRight] then begin
      if DockAlign=alLeft then begin
        // alLeft: NewSite, Splitter, other siblings
        Splitter.SetBounds(NewSize,0,Splitter.Width,ClientHeight);
        NewSite.SetBounds(0,0,NewSize,ClientHeight);
      end else begin
        // alRight: other siblings, Splitter, NewSite
        NewSite.SetBounds(ClientWidth-NewSize,0,NewSize,ClientHeight);
        Splitter.SetBounds(NewSite.Left-Splitter.Width,0,Splitter.Width,ClientHeight);
      end;
    end else begin
      if DockAlign=alTop then begin
        // alTop: NewSite, Splitter, other siblings
        Splitter.SetBounds(0,NewSize,ClientWidth,Splitter.Height);
        NewSite.SetBounds(0,0,ClientWidth,NewSize);
      end else begin
        // alBottom: other siblings, Splitter, NewSite
        NewSite.SetBounds(0,ClientHeight-NewSize,ClientWidth,NewSize);
        Splitter.SetBounds(0,NewSite.Top-Splitter.Height,ClientWidth,Splitter.Height);
      end;
    end;
    // shrink siblings
    for i:=0 to ControlCount-1 do begin
      Sibling:=Controls[i];
      if Sibling.AnchorSide[MainAnchor].Control=Splitter then begin
        NewBounds:=Sibling.BoundsRect;
        case DockAlign of
        alLeft: NewBounds.Left:=Splitter.Left+Splitter.Width;
        alRight: NewBounds.Right:=Splitter.Left;
        alTop: NewBounds.Top:=Splitter.Top+Splitter.Height;
        alBottom: NewBounds.Bottom:=Splitter.Top;
        end;
        NewBounds.Right:=Max(NewBounds.Left+1,NewBounds.Right);
        NewBounds.Bottom:=Max(NewBounds.Top+1,NewBounds.Bottom);
        Sibling.BoundsRect:=NewBounds;
      end;
    end;
  end;

  //debugln(['TAnchorDockHostSite.DockAnotherControl ',DbgSName(Self)]);
  //DebugWriteChildAnchors(Self,true,true);
  Result:=true;
end;

procedure TAnchorDockHostSite.CreatePages;
begin
  if FPages<>nil then
    RaiseGDBException('');
  FPages:=DockMaster.PageControlClass.Create(nil); // do not own it, pages can be moved to another site
  FPages.FreeNotification(Self);
  FPages.Parent:=Self;
  FPages.Align:=alClient;
  FPages.MultiLine:=DockMaster.MultiLinePages;
end;

procedure TAnchorDockHostSite.FreePages;
begin
  FreeAndNil(FPages);
end;

function TAnchorDockHostSite.DockSecondPage(NewControl: TControl): boolean;
var
  OldControl: TControl;
  OldSite: TAnchorDockHostSite;
begin
  {$IFDEF VerboseAnchorDockPages}
  debugln(['TAnchorDockHostSite.DockSecondPage Self="',Caption,'" AControl=',DbgSName(NewControl)]);
  {$ENDIF}
  if SiteType<>adhstOneControl then
    RaiseGDBException('TAnchorDockHostSite.DockSecondPage inconsistency');

  FSiteType:=adhstPages;
  CreatePages;

  // remove header (keep it for later use)
  {$IFDEF VerboseAnchorDockPages}
  debugln(['TAnchorDockHostSite.DockSecondPage Self="',Caption,'" removing header ...']);
  {$ENDIF}
  Header.Parent:=nil;

  // put the OldControl into a page of its own
  {$IFDEF VerboseAnchorDockPages}
  debugln(['TAnchorDockHostSite.DockSecondPage Self="',Caption,'" move oldcontrol to site of its own ...']);
  {$ENDIF}
  OldControl:=GetOneControl;
  OldSite:=MakeSite(OldControl);
  OldSite.HostDockSite:=nil;
  {$IFDEF VerboseAnchorDockPages}
  debugln(['TAnchorDockHostSite.DockSecondPage Self="',Caption,'" adding oldcontrol site ...']);
  {$ENDIF}
  FPages.Pages.Add(OldSite.Caption);
  OldSite.Parent:=FPages.Page[0];
  OldSite.Align:=alClient;
  OldSite.Visible:=true;

  Result:=DockAnotherPage(NewControl,nil);
end;

function TAnchorDockHostSite.DockAnotherPage(NewControl: TControl;
  InFrontOf: TControl): boolean;
var
  NewSite: TAnchorDockHostSite;
  NewIndex: LongInt;
begin
  {$IFDEF VerboseAnchorDockPages}
  debugln(['TAnchorDockHostSite.DockAnotherPage Self="',Caption,'" make new control (',DbgSName(NewControl),') dockable ...']);
  {$ENDIF}
  if SiteType<>adhstPages then
    RaiseGDBException('TAnchorDockHostSite.DockAnotherPage inconsistency');

  NewSite:=MakeSite(NewControl);
  //debugln(['TAnchorDockHostSite.DockAnotherPage Self="',Caption,'" adding newcontrol site ...']);
  NewIndex:=FPages.PageCount;
  if (InFrontOf is TAnchorDockPage)
  and (InFrontOf.Parent=Pages) then
    NewIndex:=TAnchorDockPage(InFrontOf).PageIndex;
  Pages.Pages.Insert(NewIndex,NewSite.Caption);
  //debugln(['TAnchorDockHostSite.DockAnotherPage ',DbgSName(FPages.Page[1])]);
  NewSite.Parent:=FPages.Page[NewIndex];
  NewSite.Align:=alClient;
  NewSite.Visible:=true;
  FPages.PageIndex:=NewIndex;

  Result:=true;
end;

procedure TAnchorDockHostSite.AddCleanControl(AControl: TControl;
  TheAlign: TAlign);
var
  a: TAnchorKind;
begin
  AControl.Parent:=Self;
  AControl.Align:=TheAlign;
  AControl.Anchors:=[akLeft,akTop,akRight,akBottom];
  for a:=Low(TAnchorKind) to high(TAnchorKind) do
    AControl.AnchorSide[a].Control:=nil;
  AControl.Visible:=true;
end;

procedure TAnchorDockHostSite.RemoveControlFromLayout(AControl: TControl);

  procedure RemoveControlBoundSplitter(Splitter: TAnchorDockSplitter;
    Side: TAnchorKind);
  var
    i: Integer;
    Sibling: TControl;
    NewBounds: TRect;
  begin
    //debugln(['RemoveControlBoundSplitter START ',DbgSName(Splitter)]);
    { Example: Side=akRight
                          #             #
        #####################     #########
           ---+S+--------+#         ---+#
           ---+S|AControl|#   --->  ---+#
           ---+S+--------+#         ---+#
        #####################     #########
    }
    for i:=Splitter.AnchoredControlCount-1 downto 0 do begin
      Sibling:=Splitter.AnchoredControls[i];
      if Sibling.AnchorSide[Side].Control=Splitter then begin
        // anchor Sibling to next
        Sibling.AnchorSide[Side].Assign(AControl.AnchorSide[Side]);
        // enlarge Sibling
        NewBounds:=Sibling.BoundsRect;
        case Side of
        akTop: NewBounds.Top:=AControl.Top;
        akLeft: NewBounds.Left:=AControl.Left;
        akRight: NewBounds.Right:=AControl.Left+AControl.Width;
        akBottom: NewBounds.Bottom:=AControl.Top+AControl.Height;
        end;
        if (sibling is TAnchorDockHostSite) then
        if (sibling as TAnchorDockHostSite).Minimized then begin
          DockMaster.FMapMinimizedControls.Remove((sibling as TAnchorDockHostSite).FMinimizedControl);
          (sibling as TAnchorDockHostSite).FMinimizedControl.Parent:=(sibling as TAnchorDockHostSite);
          (sibling as TAnchorDockHostSite).FMinimizedControl.Visible:=True;
          (sibling as TAnchorDockHostSite).FMinimizedControl:=nil;
          (sibling as TAnchorDockHostSite).UpdateHeaderAlign;
        end;
        Sibling.BoundsRect:=NewBounds;
      end;
    end;
    //debugln(['RemoveControlBoundSplitter ',DbgSName(Splitter)]);
    Splitter.Free;

    ClearChildControlAnchorSides(AControl);
    //DebugWriteChildAnchors(GetParentForm(Self),true,true);
  end;

  procedure ConvertToOneControlType(OnlySiteLeft: TAnchorDockHostSite);
  var
    a: TAnchorKind;
    NewBounds: TRect;
    p: TPoint;
    i: Integer;
    Sibling: TControl;
    NewParentBounds: TRect;
  begin
    BeginUpdateLayout;
    try
      // remove splitter
      for i:=ControlCount-1 downto 0 do begin
        Sibling:=Controls[i];
        if Sibling is TAnchorDockSplitter then
          Sibling.Free
        else if Sibling is TAnchorDockHostSite then
          for a:=low(TAnchorKind) to high(TAnchorKind) do
            Sibling.AnchorSide[a].Control:=nil;
      end;
      if (Parent=nil) then begin
        // shrink this site
        NewBounds:=OnlySiteLeft.BoundsRect;
        p:=ClientOrigin;
        OffsetRect(NewBounds,p.x,p.y);
        BoundsRect:=NewBounds;
      end else if DockMaster.IsCustomSite(Parent) then begin
        // parent is a custom dock site
        // shrink this site and the parent
        NewParentBounds:=Parent.BoundsRect;
        case Align of
        alTop:
          begin
            inc(NewParentBounds.Top,Height-OnlySiteLeft.Height);
            Width:=Parent.ClientWidth;
            Height:=OnlySiteLeft.Height;
          end;
        alBottom:
          begin
            dec(NewParentBounds.Bottom,Height-OnlySiteLeft.Height);
            Width:=Parent.ClientWidth;
            Height:=OnlySiteLeft.Height;
          end;
        alLeft:
          begin
            inc(NewParentBounds.Left,Width-OnlySiteLeft.Width);
            Width:=OnlySiteLeft.Width;
            Height:=Parent.ClientHeight;
          end;
        alRight:
          begin
            dec(NewParentBounds.Right,Width-OnlySiteLeft.Width);
            Width:=OnlySiteLeft.Width;
            Height:=Parent.ClientHeight;
          end;
        end;
        Parent.BoundsRect:=NewParentBounds;
      end;

      // change type
      FSiteType:=adhstOneControl;
      OnlySiteLeft.Align:=alClient;
      Header.Parent:=Self;
      if OnlySiteLeft.Minimized then begin
        DockMaster.FMapMinimizedControls.Remove(OnlySiteLeft.FMinimizedControl);
        OnlySiteLeft.FMinimizedControl.Parent:=OnlySiteLeft;
        OnlySiteLeft.FMinimizedControl.Visible:=True;
        OnlySiteLeft.FMinimizedControl:=nil;
        UpdateHeaderAlign;
      end;
      UpdateHeaderAlign;

      //debugln(['TAnchorDockHostSite.RemoveControlFromLayout.ConvertToOneControlType AFTER CONVERT "',Caption,'" to onecontrol OnlySiteLeft="',OnlySiteLeft.Caption,'"']);
      //DebugWriteChildAnchors(GetParentForm(Self),true,true);

      DockMaster.NeedSimplify(Self);
    finally
      EndUpdateLayout;
    end;
  end;

var
  Side: TAnchorKind;
  Splitter: TAnchorDockSplitter;
  OnlySiteLeft: TAnchorDockHostSite;
  Sibling: TControl;
  SplitterCount: Integer;
begin
  {$IFDEF VerboseAnchorDocking}
  debugln(['TAnchorDockHostSite.RemoveControlFromLayout Self="',Caption,'" AControl=',DbgSName(AControl),'="',AControl.Caption,'"']);
  {$ENDIF}
  if SiteType<>adhstLayout then
    RaiseGDBException('TAnchorDockHostSite.RemoveControlFromLayout inconsistency');

  if IsOneSiteLayout(OnlySiteLeft) then begin
    ClearChildControlAnchorSides(AControl);
    ConvertToOneControlType(OnlySiteLeft);
    exit;
  end;

  // remove a splitter and fill the gap
  SplitterCount:=0;
  for Side:=Low(TAnchorKind) to high(TAnchorKind) do begin
    Sibling:=AControl.AnchorSide[OppositeAnchor[Side]].Control;
    if Sibling is TAnchorDockSplitter then begin
      inc(SplitterCount);
      Splitter:=TAnchorDockSplitter(Sibling);
      if Splitter.SideAnchoredControlCount(Side)=1 then begin
        // Splitter is only used by AControl at Side
        RemoveControlBoundSplitter(Splitter,Side);
        exit;
      end;
    end;
  end;

  if SplitterCount=4 then begin
    RemoveSpiralSplitter(AControl);
    exit;
  end;

  ClearChildControlAnchorSides(AControl);
end;

procedure TAnchorDockHostSite.RemoveMinimizedControl;
begin
  FMinimizedControl:=nil;
  DockMaster.FMapMinimizedControls.Remove(FMinimizedControl);
end;

procedure TAnchorDockHostSite.RemoveSpiralSplitter(AControl: TControl);
{ Merge two splitters and delete one of them.
  Prefer the pair with shortest distance between.

  For example:
                   3            3
     111111111111113            3
        2+--------+3            3
        2|AControl|3  --->  111111111
        2+--------+3            2
        24444444444444          2
        2                       2
   Everything anchored to 4 is now anchored to 1.
   And right side of 1 is now anchored to where the right side of 4 was anchored.
}
var
  Splitters: array[TAnchorKind] of TAnchorDockSplitter;
  Side: TAnchorKind;
  Keep: TAnchorKind;
  DeleteSplitter: TAnchorDockSplitter;
  i: Integer;
  Sibling: TControl;
  NextSide: TAnchorKind;
  NewBounds: TRect;
begin
  for Side:=low(TAnchorKind) to high(TAnchorKind) do
    Splitters[Side]:=AControl.AnchorSide[Side].Control as TAnchorDockSplitter;
  // Prefer the pair with shortest distance between
  if (Splitters[akRight].Left-Splitters[akLeft].Left)
    <(Splitters[akBottom].Top-Splitters[akTop].Top)
  then
    Keep:=akLeft
  else
    Keep:=akTop;
  DeleteSplitter:=Splitters[OppositeAnchor[Keep]];
  // transfer anchors from the deleting splitter to the kept splitter
  for i:=0 to ControlCount-1 do begin
    Sibling:=Controls[i];
    for Side:=low(TAnchorKind) to high(TAnchorKind) do begin
      if Sibling.AnchorSide[Side].Control=DeleteSplitter then
        Sibling.AnchorSide[Side].Control:=Splitters[Keep];
    end;
  end;
  // longen kept splitter
  NextSide:=ClockwiseAnchor[Keep];
  if Splitters[Keep].AnchorSide[NextSide].Control<>Splitters[NextSide] then
    NextSide:=OppositeAnchor[NextSide];
  Splitters[Keep].AnchorSide[NextSide].Control:=
                                    DeleteSplitter.AnchorSide[NextSide].Control;
  case NextSide of
  akTop: Splitters[Keep].Top:=DeleteSplitter.Top;
  akLeft: Splitters[Keep].Left:=DeleteSplitter.Left;
  akRight: Splitters[Keep].Width:=DeleteSplitter.Left+DeleteSplitter.Width-Splitters[Keep].Left;
  akBottom: Splitters[Keep].Height:=DeleteSplitter.Top+DeleteSplitter.Height-Splitters[Keep].Top;
  end;

  // move splitter to the middle
  if Keep=akLeft then
    Splitters[Keep].Left:=(Splitters[Keep].Left+DeleteSplitter.Left) div 2
  else
    Splitters[Keep].Top:=(Splitters[Keep].Top+DeleteSplitter.Top) div 2;
  // adjust all anchored controls
  for i:=0 to ControlCount-1 do begin
    Sibling:=Controls[i];
    for Side:=low(TAnchorKind) to high(TAnchorKind) do begin
      if Sibling.AnchorSide[Side].Control=Splitters[Keep] then begin
        NewBounds:=Sibling.BoundsRect;
        case Side of
        akTop: NewBounds.Top:=Splitters[Keep].Top+Splitters[Keep].Height;
        akLeft: NewBounds.Left:=Splitters[Keep].Left+Splitters[Keep].Width;
        akRight: NewBounds.Right:=Splitters[Keep].Left;
        akBottom: NewBounds.Bottom:=Splitters[Keep].Top;
        end;
        Sibling.BoundsRect:=NewBounds;
      end;
    end;
  end;

  // delete the splitter
  DeleteSplitter.Free;

  ClearChildControlAnchorSides(AControl);
end;

procedure TAnchorDockHostSite.ClearChildControlAnchorSides(AControl: TControl);
var
  Side: TAnchorKind;
  Sibling: TControl;
begin
  for Side:=Low(TAnchorKind) to high(TAnchorKind) do begin
    Sibling:=AControl.AnchorSide[Side].Control;
    if (Sibling=nil) then continue;
    if (Sibling.Parent=Self) then
      AControl.AnchorSide[Side].Control:=nil;
  end;
end;

procedure TAnchorDockHostSite.Simplify;
var
  AControl: TControl;
begin
  if (Pages<>nil) and (Pages.PageCount=1) then
    SimplifyPages
  else if (SiteType=adhstOneControl) then begin
    AControl:=GetOneControl;
    {$IFDEF VerboseAnchorDocking}
    debugln(['TAnchorDockHostSite.Simplify ',DbgSName(Self),' ',DbgSName(AControl)]);
    {$ENDIF}
    if AControl is TAnchorDockHostSite then
      SimplifyOneControl
    else if ((AControl=nil) or (csDestroying in AControl.ComponentState)) then
      DockMaster.NeedFree(Self);
  end;
end;

procedure TAnchorDockHostSite.SimplifyPages;
var
  Page: TAnchorDockPage;
  Site: TAnchorDockHostSite;
begin
  if Pages=nil then exit;
  if DockMaster.IsReleasing(Pages) then exit;
  if Pages.PageCount=1 then begin
    {$IFDEF VerboseAnchorDockPages}
    debugln(['TAnchorDockHostSite.SimplifyPages "',Caption,'" PageCount=1']);
    {$ENDIF}
    DisableAutoSizing{$IFDEF DebugDisableAutoSizing}('TAnchorDockHostSite.SimplifyPages'){$ENDIF};
    BeginUpdateLayout;
    try
      // move the content of the Page to the place where Pages is
      Page:=Pages.DockPages[0];
      Site:=Page.GetSite;
      Site.Parent:=Self;
      if Site<>nil then
        CopyAnchorBounds(Pages,Site);
      if SiteType=adhstPages then
        FSiteType:=adhstOneControl;
      // free Pages
      DockMaster.NeedFree(Pages);
      if SiteType=adhstOneControl then
        SimplifyOneControl;
    finally
      EndUpdateLayout;
      EnableAutoSizing{$IFDEF DebugDisableAutoSizing}('TAnchorDockHostSite.SimplifyPages'){$ENDIF};
    end;
    //debugln(['TAnchorDockHostSite.SimplifyPages END Self="',Caption,'"']);
    //DebugWriteChildAnchors(GetParentForm(Self),true,true);
  end else if Pages.PageCount=0 then begin
    //debugln(['TAnchorDockHostSite.SimplifyPages "',Caption,'" PageCount=0 Self=',dbgs(Pointer(Self))]);
    FSiteType:=adhstNone;
    FreePages;
    DockMaster.NeedSimplify(Self);
  end;
end;

procedure TAnchorDockHostSite.SimplifyOneControl;
var
  Site: TAnchorDockHostSite;
  i: Integer;
  Child, PlaceHolder: TControl;
  a: TAnchorKind;
begin
  if SiteType<>adhstOneControl then exit;
  if not IsOneSiteLayout(Site) then exit;
  {$IFDEF VerboseAnchorDocking}
  debugln(['TAnchorDockHostSite.SimplifyOneControl Self="',Caption,'" Site="',Site.Caption,'"']);
  {$ENDIF}
  DisableAutoSizing{$IFDEF DebugDisableAutoSizing}('TAnchorDockHostSite.SimplifyOneControl'){$ENDIF};
  BeginUpdateLayout;
  try
    // move the content of Site up and free Site
    // Note: it is not possible to do it the other way round, because moving a
    // form to screen changes the z order and focus
    FSiteType:=Site.SiteType;

    // header
    Header.Align:=Site.Header.Align;
    Header.Caption:=Site.Header.Caption;
    UpdateHeaderShowing;
    Caption:=Site.Caption;

    Site.BeginUpdateLayout;
    // move controls from Site to Self
    // when a site is moved to a other parent, we have to insert a place holder
    // on old site or the splitters will be removed, see issue #34937
    i:=Site.ControlCount-1;
    while i>=0 do begin
      Child:=Site.Controls[i];
      if (Child.Owner<>Site) then begin
        if not (Child is TAnchorDockSplitter) then begin
          PlaceHolder:=TAnchorDockHostSite.CreateNew(Site);
          PlaceHolder.Parent:=Site;
          PlaceHolder.Anchors:=Child.Anchors;
          for a:=Low(TAnchorKind) to High(TAnchorKind) do
            PlaceHolder.AnchorSide[a].Control:=Child.AnchorSide[a].Control;
          PlaceHolder.SetBounds(Child.Left, Child.Top, Child.Width, Child.Height);
          PlaceHolder.Name:='_'+Child.Name;
          PlaceHolder.Visible:=Child.Visible;
        end;
        Child.Parent:=Self;
        if Child=Site.Pages then begin
          FPages:=Site.Pages;
          Site.FPages:=nil;
        end;
        if Child.HostDockSite=Site then
          Child.HostDockSite:=Self;
        for a:=low(TAnchorKind) to high(TAnchorKind) do begin
          if Child.AnchorSide[a].Control=Site then
            Child.AnchorSide[a].Control:=Self;
        end;
      end;
      i:=Min(i,Site.ControlCount)-1;
    end;

    for i:=0 to ControlCount-1 do begin
      Child:=Controls[i];
      PlaceHolder:=TControl(Site.FindComponent('_'+Child.Name));
      if not Assigned(PlaceHolder) then continue;
      for a:=Low(TAnchorKind) to High(TAnchorKind) do
        if PlaceHolder.AnchorSide[a].Control<>Site then
          Child.AnchorSide[a].Control:=PlaceHolder.AnchorSide[a].Control;
    end;
    Site.EndUpdateLayout;

    // delete Site
    Site.FSiteType:=adhstNone;
    DockMaster.NeedFree(Site);
  finally
    EndUpdateLayout;
    EnableAutoSizing{$IFDEF DebugDisableAutoSizing}('TAnchorDockHostSite.SimplifyOneControl'){$ENDIF};
  end;

  //debugln(['TAnchorDockHostSite.SimplifyOneControl END Self="',Caption,'"']);
  //DebugWriteChildAnchors(GetParentForm(Self),true,true);
end;

function TAnchorDockHostSite.GetOneControl: TControl;
var
  i: Integer;
begin
  for i:=0 to ControlCount-1 do begin
    Result:=Controls[i];
    if Result.Owner<>Self then exit;
  end;
  result:=FMinimizedControl;
  //Result:=nil;
end;

function TAnchorDockHostSite.GetSiteCount: integer;
var
  i: Integer;
  Child: TControl;
begin
  Result:=0;
  for i:=0 to ControlCount-1 do begin
    Child:=Controls[i];
    if not (Child is TAnchorDockHostSite) then continue;
    if not Child.IsControlVisible then continue;
    inc(Result);
  end;
end;

function TAnchorDockHostSite.IsOneSiteLayout(out Site: TAnchorDockHostSite
  ): boolean;
var
  i: Integer;
  Child: TControl;
begin
  Site:=nil;
  for i:=0 to ControlCount-1 do begin
    Child:=Controls[i];
    if not (Child is TAnchorDockHostSite) then continue;
    if not Child.IsControlVisible then continue;
    if Site<>nil then exit(false);
    Site:=TAnchorDockHostSite(Child);
  end;
  Result:=Site<>nil;
end;

function TAnchorDockHostSite.IsTwoSiteLayout(out Site1,
  Site2: TAnchorDockHostSite): boolean;
var
  i: Integer;
  Child: TControl;
begin
  Site1:=nil;
  Site2:=nil;
  for i:=0 to ControlCount-1 do begin
    Child:=Controls[i];
    if not (Child is TAnchorDockHostSite) then continue;
    if not Child.IsControlVisible then continue;
    if Site1=nil then
      Site1:=TAnchorDockHostSite(Child)
    else if Site2=nil then
      Site2:=TAnchorDockHostSite(Child)
    else
      exit(false);
  end;
  Result:=Site2<>nil;
end;

function TAnchorDockHostSite.GetUniqueSplitterName: string;
var
  i: Integer;
begin
  i:=0;
  repeat
    inc(i);
    Result:=AnchorDockSplitterName+IntToStr(i);
  until FindComponent(Result)=nil;
end;

function TAnchorDockHostSite.MakeSite(AControl: TControl): TAnchorDockHostSite;
begin
  if AControl is TAnchorDockHostSite then
    Result:=TAnchorDockHostSite(AControl)
  else begin
    Result:=DockMaster.CreateSite;
    try
      AControl.ManualDock(Result,nil,alClient);
    finally
      Result.EnableAutoSizing{$IFDEF DebugDisableAutoSizing}(ADAutoSizingReason){$ENDIF};
    end;
  end;
end;

procedure TAnchorDockHostSite.MoveAllControls(dx, dy: integer);
// move all children, except the sides that are anchored to parent left,top
var
  i: Integer;
  Child: TControl;
  NewBounds: TRect;
begin
  for i:=0 to ControlCount-1 do begin
    Child:=Controls[i];
    NewBounds:=Child.BoundsRect;
    OffsetRect(NewBounds,dx,dy);
    if Child.AnchorSideLeft.Control=Self then
      NewBounds.Left:=0;
    if Child.AnchorSideTop.Control=Self then
      NewBounds.Top:=0;
    Child.BoundsRect:=NewBounds;
  end;
end;

procedure TAnchorDockHostSite.AlignControls(AControl: TControl; var ARect: TRect);
var
  i: Integer;
  Child: TControl;
  Splitter: TAnchorDockSplitter;
begin
  inherited AlignControls(AControl, ARect);
  if csDestroying in ComponentState then exit;

  if DockMaster.ScaleOnResize and (not UpdatingLayout)
  and (not DockMaster.Restoring) then begin
    // scale splitters
    for i:=0 to ControlCount-1 do begin
      Child:=Controls[i];
      if not Child.IsControlVisible then continue;
      if Child is TAnchorDockSplitter then begin
        Splitter:=TAnchorDockSplitter(Child);
        //debugln(['TAnchorDockHostSite.AlignControls ',Caption,' ',DbgSName(Splitter),' OldBounds=',dbgs(Splitter.BoundsRect),' BaseBounds=',dbgs(Splitter.DockBounds),' BaseParentSize=',dbgs(Splitter.DockParentClientSize),' ParentSize=',ClientWidth,'x',ClientHeight]);
        Splitter.SetBoundsPercentually;
        //debugln(['TAnchorDockHostSite.AlignControls ',Caption,' ',DbgSName(Child),' NewBounds=',dbgs(Child.BoundsRect)]);
      end;
    end;
  end;
end;

function TAnchorDockHostSite.CheckIfOneControlHidden: boolean;
var
  Child: TControl;
begin
  Result:=false;
  //debugln(['TAnchorDockHostSite.CheckIfOneControlHidden ',DbgSName(Self),' UpdatingLayout=',UpdatingLayout,' Visible=',Visible,' Parent=',DbgSName(Parent),' csDestroying=',csDestroying in ComponentState,' SiteType=',dbgs(SiteType)]);
  if UpdatingLayout or (not IsControlVisible)
  or (csDestroying in ComponentState)
  or (SiteType<>adhstOneControl)
  then
    exit;
  Child:=GetOneControl;
  if (Child=nil) then exit;
  if Child.IsControlVisible then exit;

  // docked child was hidden/closed
  Result:=true;
  // => undock
  BeginUpdateLayout;
  DisableAutoSizing{$IFDEF DebugDisableAutoSizing}('TAnchorDockHostSite.CheckIfOneControlHidden'){$ENDIF};
  try
    {$IFDEF VerboseAnchorDocking}
    debugln(['TAnchorDockHostSite.CheckIfOneControlHidden ',DbgSName(Self),' UpdatingLayout=',UpdatingLayout,' Visible=',Visible,' Parent=',DbgSName(Parent),' csDestroying=',csDestroying in ComponentState,' SiteType=',dbgs(SiteType),' Child=',DbgSName(Child),' Child.csDestroying=',csDestroying in Child.ComponentState]);
    {$ENDIF}
    Visible:=false;
    Parent:=nil;
  finally
    EnableAutoSizing{$IFDEF DebugDisableAutoSizing}('TAnchorDockHostSite.CheckIfOneControlHidden'){$ENDIF};
  end;
  EndUpdateLayout;
  if (not (Child is TCustomForm)) or (csDestroying in Child.ComponentState) then
    Release;
end;

procedure TAnchorDockHostSite.DoDock(NewDockSite: TWinControl; var ARect: TRect);
begin
  inherited DoDock(NewDockSite, ARect);
  if DockMaster <> nil then
    DockMaster.SimplifyPendingLayouts;
end;

procedure TAnchorDockHostSite.SetParent(NewParent: TWinControl);
var
  OldCaption: string;
  OldParent: TWinControl;
begin
  OldParent:=Parent;
  if NewParent=OldParent then exit;
  inherited SetParent(NewParent);
  OldCaption:=Caption;
  UpdateDockCaption;
  if OldCaption<>Caption then begin
    // UpdateDockCaption has not updated parents => do it now
    if Parent is TAnchorDockHostSite then
      TAnchorDockHostSite(Parent).UpdateDockCaption;
    if Parent is TAnchorDockPage then
      TAnchorDockPage(Parent).UpdateDockCaption;
  end;
  UpdateHeaderShowing;

  if (BoundSplitter<>nil) and (BoundSplitter.Parent<>Parent) then begin
    //debugln(['TAnchorDockHostSite.SetParent freeing splitter: ',DbgSName(BoundSplitter)]);
    FreeAndNil(FBoundSplitter);
  end;
  if Parent=nil then
    BorderStyle:=bsSizeable
  else
    BorderStyle:=bsNone;
end;

function TAnchorDockHostSite.HeaderNeedsShowing: boolean;
begin
  Result:=(SiteType<>adhstLayout)
      and (not (Parent is TAnchorDockPage))
      and Assigned(DockMaster) and DockMaster.ShowHeader;
end;

procedure TAnchorDockHostSite.DoClose(var CloseAction: TCloseAction);
var
  AControl: TControl;
  AForm: TCustomForm absolute AControl;
begin
  if (GetSiteCount=0) and not DockMaster.FAllClosing then
  begin
    AControl:=GetOneControl;
    if (AControl is TCustomForm) then
    begin
      AForm.Close;
      if csDestroying in AForm.ComponentState then
        CloseAction:=caFree
      else if AForm.Visible then
        CloseAction:=caNone;
    end;
  end;
  inherited DoClose(CloseAction);
end;

function TAnchorDockHostSite.CanUndock: boolean;
begin
  Result:=Parent<>nil;
end;

procedure TAnchorDockHostSite.Undock;
var
  p: TPoint;
begin
  if Parent=nil then exit;
  DisableAutoSizing{$IFDEF DebugDisableAutoSizing}('TAnchorDockHostSite.Undock'){$ENDIF};
  try
    p := Point(0,0);
    p := ClientToScreen(p);
    Parent:=nil;
    SetBounds(p.x,p.y,Width,Height);
  finally
    EnableAutoSizing{$IFDEF DebugDisableAutoSizing}('TAnchorDockHostSite.Undock'){$ENDIF};
  end;
end;

function TAnchorDockHostSite.CanMerge: boolean;
begin
  Result:=(SiteType=adhstLayout)
      and (Parent is TAnchorDockHostSite)
      and (TAnchorDockHostSite(Parent).SiteType=adhstLayout);
end;

procedure TAnchorDockHostSite.Merge;
{ Move all child controls to parent and delete this site
}
var
  ParentSite: TAnchorDockHostSite;
  i: Integer;
  Child: TControl;
  Side: TAnchorKind;
begin
  ParentSite:=Parent as TAnchorDockHostSite;
  if (SiteType<>adhstLayout) or (ParentSite.SiteType<>adhstLayout) then
    RaiseGDBException('');
  ParentSite.BeginUpdateLayout;
  DisableAutoSizing{$IFDEF DebugDisableAutoSizing}('TAnchorDockHostSite.Merge'){$ENDIF};
  try
    for i := ControlCount - 1 downto 0 do begin
      Child := Controls[i];
      if Child.Owner <> Self then
      begin
        Child.Parent := ParentSite;
        Child.SetBounds(Child.Left + Left, Child.Top + Top, Child.Width, Child.Height);
        for Side := Low(TAnchorKind) to High(TAnchorKind) do
          if Child.AnchorSide[Side].Control = Self then
            Child.AnchorSide[Side].Assign(AnchorSide[Side]);
      end;
    end;
    Parent:=nil;
    DockMaster.NeedFree(Self);
  finally
    ParentSite.EndUpdateLayout;
    // not needed, because this site is freed: EnableAutoSizing;
  end;
end;

function TAnchorDockHostSite.EnlargeSide(Side: TAnchorKind;
  OnlyCheckIfPossible: boolean): boolean;
{
 Shrink one splitter, enlarge the other splitter.

     |#|         |#         |#|         |#
     |#| Control |#         |#|         |#
   --+#+---------+#   --> --+#| Control |#
   ===============#       ===#|         |#
   --------------+#       --+#|         |#
       A         |#        A|#|         |#
   --------------+#       --+#+---------+#
   ==================     ===================

 Move one neighbor splitter, enlarge Control, resize one splitter, rotate the other splitter.

     |#|         |#|          |#|         |#|
     |#| Control |#|          |#|         |#|
   --+#+---------+#+--  --> --+#| Control |#+--
   ===================      ===#|         |#===
   --------+#+--------      --+#|         |#+--
           |#|   B            |#|         |#|B
           |#+--------        |#|         |#+--
       A   |#=========       A|#|         |#===
           |#+--------        |#|         |#+--
           |#|   C            |#|         |#|C
   --------+#+--------      --+#+---------+#+--
   ===================      ===================
}
begin
  Result:=true;
  if EnlargeSideResizeTwoSplitters(Side,ClockwiseAnchor[Side],
                                   OnlyCheckIfPossible) then exit;
  if EnlargeSideResizeTwoSplitters(Side,OppositeAnchor[ClockwiseAnchor[Side]],
                                   OnlyCheckIfPossible) then exit;
  if EnlargeSideRotateSplitter(Side,OnlyCheckIfPossible) then exit;
  Result:=false;
end;

function TAnchorDockHostSite.EnlargeSideResizeTwoSplitters(ShrinkSplitterSide,
  EnlargeSpitterSide: TAnchorKind; OnlyCheckIfPossible: boolean): boolean;
{ Shrink one neighbor control, enlarge Self. Two splitters are resized.

  For example: ShrinkSplitterSide=akBottom, EnlargeSpitterSide=akLeft

    |#|        |#         |#|        |#
    |#|  Self  |#         |#|        |#
  --+#+--------+#   --> --+#|  Self  |#
  ==============#       ===#|        |#
  -------------+#       --+#|        |#
      A        |#        A|#|        |#
  -------------+#       --+#+--------+#
  =================     ==================



}
var
  ParentSite: TAnchorDockHostSite;
  ShrinkSplitter: TAnchorDockSplitter;
  EnlargeSplitter: TAnchorDockSplitter;
  KeptSide: TAnchorKind;
  KeptAnchorControl: TControl;
  Sibling: TControl;
  ShrinkControl: TControl;
  i: Integer;
begin
  Result:=false;
  if not (Parent is TAnchorDockHostSite) then exit;
  ParentSite:=TAnchorDockHostSite(Parent);
  if not OnlyCheckIfPossible then begin
    ParentSite.BeginUpdateLayout;
    ParentSite.DisableAutoSizing{$IFDEF DebugDisableAutoSizing}('TAnchorDockHostSite.EnlargeSideResizeTwoSplitters'){$ENDIF};
  end;
  try
    // check ShrinkSplitter
    ShrinkSplitter:=TAnchorDockSplitter(AnchorSide[ShrinkSplitterSide].Control);
    if not (ShrinkSplitter is TAnchorDockSplitter) then exit;
    // check if EnlargeSpitterSide is a neighbor ShrinkSplitterSide
    if (EnlargeSpitterSide<>ClockwiseAnchor[ShrinkSplitterSide])
    and (EnlargeSpitterSide<>OppositeAnchor[ClockwiseAnchor[ShrinkSplitterSide]]) then
      exit;
    // check EnlargeSpitter
    EnlargeSplitter:=TAnchorDockSplitter(AnchorSide[EnlargeSpitterSide].Control);
    if not (EnlargeSplitter is TAnchorDockSplitter) then exit;
    // check if KeptSide is anchored to a splitter or parent
    KeptSide:=OppositeAnchor[EnlargeSpitterSide];
    KeptAnchorControl:=AnchorSide[KeptSide].Control;
    if not ((KeptAnchorControl=ParentSite)
            or (KeptAnchorControl is TAnchorDockSplitter)) then exit;
    // check if ShrinkSplitter is anchored/stops at KeptAnchorControl
    if ShrinkSplitter.AnchorSide[KeptSide].Control<>KeptAnchorControl then exit;

    // check if there is a control to shrink
    ShrinkControl:=nil;
    for i:=0 to ShrinkSplitter.AnchoredControlCount-1 do begin
      Sibling:=ShrinkSplitter.AnchoredControls[i];
      if (Sibling.AnchorSide[OppositeAnchor[ShrinkSplitterSide]].Control=ShrinkSplitter)
      and (Sibling.AnchorSide[KeptSide].Control=KeptAnchorControl) then begin
        ShrinkControl:=Sibling;
        break;
      end;
    end;
    if ShrinkControl=nil then exit;

    if OnlyCheckIfPossible then begin
      // check if ShrinkControl is large enough for shrinking
      case EnlargeSpitterSide of
      akTop: if ShrinkControl.Top>=EnlargeSplitter.Top then exit;
      akLeft: if ShrinkControl.Left>=EnlargeSplitter.Left then exit;
      akRight: if ShrinkControl.Left+ShrinkControl.Width
                      <=EnlargeSplitter.Left+EnlargeSplitter.Width then exit;
      akBottom: if ShrinkControl.Top+ShrinkControl.Height
                      <=EnlargeSplitter.Top+EnlargeSplitter.Height then exit;
      end;
    end else begin
      // do it
      // enlarge the EnlargeSplitter and Self
      AnchorAndChangeBounds(EnlargeSplitter,ShrinkSplitterSide,
                          ShrinkControl.AnchorSide[ShrinkSplitterSide].Control);
      AnchorAndChangeBounds(Self,ShrinkSplitterSide,
                          ShrinkControl.AnchorSide[ShrinkSplitterSide].Control);
      // shrink the ShrinkSplitter and ShrinkControl
      AnchorAndChangeBounds(ShrinkSplitter,KeptSide,EnlargeSplitter);
      AnchorAndChangeBounds(ShrinkControl,KeptSide,EnlargeSplitter);
    end;

  finally
    if not OnlyCheckIfPossible then begin
      ParentSite.EnableAutoSizing{$IFDEF DebugDisableAutoSizing}('TAnchorDockHostSite.EnlargeSideResizeTwoSplitters'){$ENDIF};
      ParentSite.EndUpdateLayout;
    end;
  end;
  Result:=true;
end;

function TAnchorDockHostSite.EnlargeSideRotateSplitter(Side: TAnchorKind;
  OnlyCheckIfPossible: boolean): boolean;
{ Shrink splitter at Side, enlarge both neighbor splitters,
  rotate the splitter behind, enlarge Control,
  shrink controls at rotate splitter

     |#|         |#|          |#|         |#|
     |#| Control |#|          |#|         |#|
   --+#+---------+#+--  --> --+#| Control |#+--
   ===================      ===#|         |#===
   --------+#+--------      --+#|         |#+--
           |#|   B            |#|         |#|B
           |#+--------        |#|         |#+--
       A   |#=========       A|#|         |#===
           |#+--------        |#|         |#+--
           |#|   C            |#|         |#|C
   --------+#+--------      --+#+---------+#+--
   ===================      ===================
}
var
  Splitter: TAnchorDockSplitter;
  CWSide: TAnchorKind;
  CWSplitter: TAnchorDockSplitter;
  CCWSide: TAnchorKind;
  i: Integer;
  Sibling: TControl;
  BehindSide: TAnchorKind;
  RotateSplitter: TAnchorDockSplitter;
  CCWSplitter: TAnchorDockSplitter;
begin
  Result:=false;
  // check if there is a splitter at Side
  Splitter:=TAnchorDockSplitter(AnchorSide[Side].Control);
  if not (Splitter is TAnchorDockSplitter) then exit;
  // check if there is a splitter at clockwise Side
  CWSide:=ClockwiseAnchor[Side];
  CWSplitter:=TAnchorDockSplitter(AnchorSide[CWSide].Control);
  if not (CWSplitter is TAnchorDockSplitter) then exit;
  // check if there is a splitter at counter clockwise Side
  CCWSide:=OppositeAnchor[CWSide];
  CCWSplitter:=TAnchorDockSplitter(AnchorSide[CCWSide].Control);
  if not (CCWSplitter is TAnchorDockSplitter) then exit;
  // check if neighbor splitters end at Splitter
  if CWSplitter.AnchorSide[Side].Control<>Splitter then exit;
  if CCWSplitter.AnchorSide[Side].Control<>Splitter then exit;
  // find the rotate splitter behind Splitter
  BehindSide:=OppositeAnchor[Side];
  RotateSplitter:=nil;
  for i:=0 to Splitter.AnchoredControlCount-1 do begin
    Sibling:=Splitter.AnchoredControls[i];
    if Sibling.AnchorSide[BehindSide].Control<>Splitter then continue;
    if not (Sibling is TAnchorDockSplitter) then continue;
    if Side in [akLeft,akRight] then begin
      if Sibling.Top<Top-DockMaster.SplitterWidth then continue;
      if Sibling.Top>Top+Height then continue;
    end else begin
      if Sibling.Left<Left-DockMaster.SplitterWidth then continue;
      if Sibling.Left>Left+Width then continue;
    end;
    if RotateSplitter=nil then
      RotateSplitter:=TAnchorDockSplitter(Sibling)
    else
      // there are multiple splitters behind
      exit;
  end;
  if RotateSplitter=nil then exit;
  // check that all siblings at RotateSplitter are large enough to shrink
  for i:=0 to RotateSplitter.AnchoredControlCount-1 do begin
    Sibling:=RotateSplitter.AnchoredControls[i];
    if Side in [akLeft,akRight] then begin
      if (Sibling.Top>Top-DockMaster.SplitterWidth)
      and (Sibling.Top+Sibling.Height<Top+Height+DockMaster.SplitterWidth) then
        exit;
    end else begin
      if (Sibling.Left>Left-DockMaster.SplitterWidth)
      and (Sibling.Left+Sibling.Width<Left+Width+DockMaster.SplitterWidth) then
        exit;
    end;
  end;
  Result:=true;
  if OnlyCheckIfPossible then exit;

  //debugln(['TAnchorDockHostSite.EnlargeSideRotateSplitter BEFORE Self=',DbgSName(Self),'=',dbgs(BoundsRect),' Side=',dbgs(Side),' CWSide=',dbgs(CWSide),' CWSplitter=',CWSplitter.Name,'=',dbgs(CWSplitter.BoundsRect),' CCWSide=',dbgs(CCWSide),' CCWSplitter=',CCWSplitter.Name,'=',dbgs(CCWSplitter.BoundsRect),' Behind=',dbgs(BehindSide),'=',RotateSplitter.Name,'=',dbgs(RotateSplitter.BoundsRect)]);

  DisableAutoSizing{$IFDEF DebugDisableAutoSizing}('TAnchorDockHostSite.EnlargeSideRotateSplitter'){$ENDIF};
  try
    // enlarge the two neighbor splitters
    AnchorAndChangeBounds(CWSplitter,Side,RotateSplitter.AnchorSide[Side].Control);
    AnchorAndChangeBounds(CCWSplitter,Side,RotateSplitter.AnchorSide[Side].Control);
    // enlarge control
    AnchorAndChangeBounds(Self,Side,RotateSplitter.AnchorSide[Side].Control);
    // shrink the neighbors and anchor them to the enlarge splitters
    for i:=0 to Parent.ControlCount-1 do begin
      Sibling:=Parent.Controls[i];
      if Sibling.AnchorSide[CWSide].Control=RotateSplitter then
        AnchorAndChangeBounds(Sibling,CWSide,CCWSplitter)
      else if Sibling.AnchorSide[CCWSide].Control=RotateSplitter then
        AnchorAndChangeBounds(Sibling,CCWSide,CWSplitter);
    end;
    // rotate the RotateSplitter
    RotateSplitter.AnchorSide[Side].Control:=nil;
    RotateSplitter.AnchorSide[BehindSide].Control:=nil;
    RotateSplitter.ResizeAnchor:=Side;
    AnchorAndChangeBounds(RotateSplitter,CCWSide,Splitter.AnchorSide[CCWSide].Control);
    AnchorAndChangeBounds(RotateSplitter,CWSide,CCWSplitter);
    if Side in [akLeft,akRight] then begin
      RotateSplitter.Left:=Splitter.Left;
      RotateSplitter.Width:=DockMaster.SplitterWidth;
    end else begin
      RotateSplitter.Top:=Splitter.Top;
      RotateSplitter.Height:=DockMaster.SplitterWidth;
    end;
    // shrink Splitter
    AnchorAndChangeBounds(Splitter,CCWSide,CWSplitter);
    // anchor some siblings of Splitter to RotateSplitter
    for i:=0 to Parent.ControlCount-1 do begin
      Sibling:=Parent.Controls[i];
      case Side of
      akLeft: if Sibling.Top<Top then continue;
      akRight: if Sibling.Top>Top then continue;
      akTop: if Sibling.Left>Left then continue;
      akBottom: if Sibling.Left<Left then continue;
      end;
      if Sibling.AnchorSide[BehindSide].Control=Splitter then
        Sibling.AnchorSide[BehindSide].Control:=RotateSplitter
      else if Sibling.AnchorSide[Side].Control=Splitter then
        Sibling.AnchorSide[Side].Control:=RotateSplitter;
    end;
    //debugln(['TAnchorDockHostSite.EnlargeSideRotateSplitter AFTER Self=',DbgSName(Self),'=',dbgs(BoundsRect),' Side=',dbgs(Side),' CWSide=',dbgs(CWSide),' CWSplitter=',CWSplitter.Name,'=',dbgs(CWSplitter.BoundsRect),' CCWSide=',dbgs(CCWSide),' CCWSplitter=',CCWSplitter.Name,'=',dbgs(CCWSplitter.BoundsRect),' Behind=',dbgs(BehindSide),'=',RotateSplitter.Name,'=',dbgs(RotateSplitter.BoundsRect)]);
  finally
    EnableAutoSizing{$IFDEF DebugDisableAutoSizing}('TAnchorDockHostSite.EnlargeSideRotateSplitter'){$ENDIF};
  end;
end;

procedure TAnchorDockHostSite.CreateBoundSplitter(Disabled: boolean);
begin
  if BoundSplitter<>nil then exit;
  FBoundSplitter:=DockMaster.CreateSplitter;
  BoundSplitter.FreeNotification(Self);
  BoundSplitter.Align:=Align;
  BoundSplitter.Parent:=Parent;
  if Disabled then
  begin
    BoundSplitter.Width:=0;
    BoundSplitter.Height:=0;
    BoundSplitter.Visible:=false;
  end;
end;

procedure TAnchorDockHostSite.PositionBoundSplitter;
begin
  case Align of
  alTop: BoundSplitter.SetBounds(0,Height,Parent.ClientWidth,BoundSplitter.Height);
  alBottom: BoundSplitter.SetBounds(0,Parent.ClientHeight-Height-BoundSplitter.Height,
                                Parent.ClientWidth,BoundSplitter.Height);
  alLeft: BoundSplitter.SetBounds(Width,0,BoundSplitter.Width,Parent.ClientHeight);
  alRight: BoundSplitter.SetBounds(Parent.ClientWidth-Width-BoundSplitter.Width,0
                              ,BoundSplitter.Width,Parent.ClientHeight);
  end;
end;

function TAnchorDockHostSite.CloseQuery: boolean;

  function Check(AControl: TWinControl): boolean;
  var
    i: Integer;
    Child: TControl;
  begin
    for i:=0 to AControl.ControlCount-1 do begin
      Child:=AControl.Controls[i];
      if Child is TWinControl then begin
        if Child is TCustomForm then begin
          if not TCustomForm(Child).CloseQuery then exit(false);
        end else begin
          if not Check(TWinControl(Child)) then exit(false);
        end;
      end;
    end;
    Result:=true;
  end;

begin
  Result:=Check(Self);
end;

function CheckOposite(Side:TAnchorKind;AControl: TControl;out Splitter: TAnchorDockSplitter; out SplitterAnchorKind:TAnchorKind):boolean;
begin
  result:=GetDockSplitter(AControl,Side,Splitter);
  if result then begin
    if CountAnchoredControls(Splitter,OppositeAnchor[Side])=1 then begin
      SplitterAnchorKind:=Side;
      exit;
    end;
  end;
  result:=false
end;

function FindNearestSpliter(AControl: TControl;out Splitter: TAnchorDockSplitter;out SplitterAnchorKind:TAnchorKind):boolean;
begin
  result:=CheckOposite(akTop,AControl,Splitter,SplitterAnchorKind);
  if result then exit;
  result:=CheckOposite(akRight,AControl,Splitter,SplitterAnchorKind);
  if result then exit;
  result:=CheckOposite(akBottom,AControl,Splitter,SplitterAnchorKind);
  if result then exit;
  result:=CheckOposite(akLeft,AControl,Splitter,SplitterAnchorKind);
end;

function TAnchorDockHostSite.CanBeMinimized(out Splitter: TAnchorDockSplitter;
                                            out SplitterAnchorKind:TAnchorKind):boolean;
var
  //AControl: TControl;
  OpositeDockHostSite:TAnchorDockHostSite;
  OpositeSplitter: TAnchorDockSplitter;
begin
  result:=false;
  if FindNearestSpliter(self,Splitter,SplitterAnchorKind) then begin
    OpositeDockHostSite:=CountAndReturnOnlyOneMinimizedAnchoredControls(Splitter,SplitterAnchorKind);
    if (Splitter.Enabled and (OpositeDockHostSite=nil)) then begin
      result:=true;
      if CheckOposite(OppositeAnchorKind[SplitterAnchorKind],self,OpositeSplitter,SplitterAnchorKind) then
      if Assigned(OpositeSplitter) then
      if not OpositeSplitter.Enabled then
        result:=false;
    end;
  end;
end;

procedure TAnchorDockHostSite.MinimizeSite;
begin
  //Application.QueueAsyncCall(@AsyncMinimizeSite,0);
  AsyncMinimizeSite(0);
end;

procedure TAnchorDockHostSite.AsyncMinimizeSite(Data: PtrInt);
var
  AControl: TControl;
  Splitter: TAnchorDockSplitter;
  SplitterAnchorKind:TAnchorKind;
  MaxSize:integer;
begin
  {$IFDEF VerboseAnchorDocking}
  debugln(['TAnchorDockHostSite.MinimizeSite ',DbgSName(Self),' SiteType=',dbgs(SiteType)]);
  {$ENDIF}
  if Minimized then
    AControl:=FMinimizedControl
  else
    AControl:=GetOneControl;
  if CanBeMinimized(Splitter,SplitterAnchorKind) or Minimized then begin
    if not Minimized then begin
      FMinimizedControl:=AControl;
      AControl.Visible:=False;
      AControl.Parent:=nil;
      DockMaster.FMapMinimizedControls.Add(AControl,Self);
    end else begin
      MaxSize:=ReturnAnchoredControlsSize(Splitter,SplitterAnchorKind);
      case SplitterAnchorKind of
        akTop:
          if AControl.Height>=MaxSize+Height then
            Splitter.FPercentPosition:=1-(MaxSize+Height)/(Splitter.Parent.ClientHeight*2);
        akBottom:
          if AControl.Height>=MaxSize+Height then
            Splitter.FPercentPosition:=(MaxSize+Height)/(Splitter.Parent.ClientHeight*2);
        akLeft:
          if AControl.Width>=MaxSize+Width then
            Splitter.FPercentPosition:=1-(MaxSize+Width)/(Splitter.Parent.ClientWidth*2);
        akRight:
          if AControl.Width>=MaxSize+Width then
            Splitter.FPercentPosition:=(MaxSize+Width)/(Splitter.Parent.ClientWidth*2);
      end;
      AControl.Parent:=self;
      AControl.Visible:=True;
      FMinimizedControl:=nil;
      DockMaster.FMapMinimizedControls.Remove(AControl);
    end;
    Splitter.Enabled:=AControl.Visible;
    UpdateHeaderAlign;
    dockmaster.UpdateHeaders;
    dockmaster.InvalidateHeaders;
    Splitter.SetBoundsPercentually;
  end;
end;

procedure TAnchorDockHostSite.ShowMinimizedControl;
var
  Splitter: TAnchorDockSplitter;
  SplitterAnchorKind:TAnchorKind;
  SpliterRect,OverlappingFormRect:TRect;
begin
  if FindNearestSpliter(self,Splitter,SplitterAnchorKind) then begin
    SpliterRect:=Splitter.GetSpliterBoundsWithUnminimizedDockSites;
    OverlappingFormRect:=BoundsRect;
    case SplitterAnchorKind of
         akTop:OverlappingFormRect.Top:=SpliterRect.Bottom;
        akLeft:OverlappingFormRect.Left:=SpliterRect.Right;
       akRight:OverlappingFormRect.Right:=SpliterRect.Left;
      akBottom:OverlappingFormRect.Bottom:=SpliterRect.Top;
    end;
    DockMaster.FOverlappingForm:=TAnchorDockOverlappingForm.CreateNew(self);
    DockMaster.FOverlappingForm.BoundsRect:=OverlappingFormRect;
    DockMaster.FOverlappingForm.Parent:=GetParentFormOrDockPanel(self,false);
    DockMaster.FOverlappingForm.AnchorDockHostSite:=self;
    header.Parent:=DockMaster.FOverlappingForm;
    FMinimizedControl.Parent:=DockMaster.FOverlappingForm.Panel;
    FMinimizedControl.Show;
    DockMaster.ShowOverlappingForm;
  end;
end;

procedure TAnchorDockHostSite.HideMinimizedControl;
begin
   FMinimizedControl.Hide;
   header.Parent:=self;
   header.UpdateHeaderControls;
   FMinimizedControl.Parent:=nil;
   FreeAndNil(DockMaster.FOverlappingForm);
end;

function TAnchorDockHostSite.CloseSite: boolean;
var
  AControl: TControl;
  AForm: TCustomForm;
  IsMainForm: Boolean;
  CloseAction: TCloseAction;
  NeedEnableAutoSizing: Boolean;
  i: Integer;
begin
  Result:=CloseQuery;
  if not Result then exit;

  {$IFDEF VerboseAnchorDocking}
  debugln(['TAnchorDockHostSite.CloseSite ',DbgSName(Self),' SiteType=',dbgs(SiteType)]);
  {$ENDIF}
  case SiteType of
  adhstNone:
    begin
      Release;
      exit;
    end;
  adhstOneControl:
    begin
      DisableAutoSizing{$IFDEF DebugDisableAutoSizing}('TAnchorDockHostSite.CloseSite'){$ENDIF};
      NeedEnableAutoSizing:=true;
      try
        AControl:=GetOneControl;
        if AControl is TCustomForm then begin
          AForm:=TCustomForm(AControl);
          IsMainForm := (Application.MainForm = AForm)
                        or (AForm.IsParentOf(Application.MainForm));
          if IsMainForm then
            CloseAction := caFree
          else
            CloseAction := caHide;
          // ToDo: TCustomForm(AControl).DoClose(CloseAction);
          case CloseAction of
          caHide: Hide;
          caMinimize: WindowState := wsMinimized;
          caFree:
            begin
              // if form is MainForm, then terminate the application
              // the owner of the MainForm is the application,
              // so the Application will take care of free-ing the form
              // and Release is not necessary
              if IsMainForm then
                Application.Terminate
              else begin
                NeedEnableAutoSizing:=false;
                Release;
                AForm.Release;
                exit;
              end;
            end;
          end;
        end else begin
          AControl.Visible:=false;
          NeedEnableAutoSizing:=false;
          Release;
          exit;
        end;
        Visible:=false;
        Parent:=nil;
      finally
        if NeedEnableAutoSizing then
          EnableAutoSizing{$IFDEF DebugDisableAutoSizing}('TAnchorDockHostSite.CloseSite'){$ENDIF};
      end;
    end;
  adhstPages:
    begin
      DisableAutoSizing{$IFDEF DebugDisableAutoSizing}('TAnchorDockHostSite.CloseSite'){$ENDIF};
      NeedEnableAutoSizing:=true;
      try
        if Minimized then
        begin
          // close all pages
          for i:=Pages.PageCount-1 downto 0 do begin
            AControl:=Pages.DockPages[Pages.PageCount-1].GetSite;
            if AControl is TAnchorDockHostSite then
              TAnchorDockHostSite(AControl).CloseSite;
            Pages.Pages.Delete(i);
          end;
          Release;
        end else begin
          // just close current page
          AControl:=Pages.DockPages[Pages.PageIndex].GetSite;
          if AControl is TAnchorDockHostSite then
            TAnchorDockHostSite(AControl).CloseSite;
          Pages.Pages.Delete(Pages.PageIndex);
        end;
      finally
        if NeedEnableAutoSizing then
          EnableAutoSizing{$IFDEF DebugDisableAutoSizing}('TAnchorDockHostSite.CloseSite'){$ENDIF};
      end;
    end;
  end;
end;

procedure TAnchorDockHostSite.RemoveControl(AControl: TControl);
begin
  //debugln(['TAnchorDockHostSite.RemoveControl ',DbgSName(Self),'=',Caption,' ',DbgSName(AControl)]);
  DisableAutoSizing{$IFDEF DebugDisableAutoSizing}('TAnchorDockHostSite.RemoveControl'){$ENDIF};
  try
    AControl.RemoveHandlerOnVisibleChanged(@ChildVisibleChanged);
    inherited RemoveControl(AControl);
    if not (csDestroying in ComponentState) then begin
      if (not ((AControl is TAnchorDockHeader)
               or (AControl is TAnchorDockSplitter)))
      then begin
        //debugln(['TAnchorDockHostSite.RemoveControl START ',Caption,' ',dbgs(SiteType),' ',DbgSName(AControl),' UpdatingLayout=',UpdatingLayout]);
        if (SiteType=adhstLayout) then
          RemoveControlFromLayout(AControl)
        else
          DockMaster.NeedSimplify(Self);
        UpdateDockCaption;
        //debugln(['TAnchorDockHostSite.RemoveControl END ',Caption,' ',dbgs(SiteType),' ',DbgSName(AControl)]);
      end;
    end;
  finally
    EnableAutoSizing{$IFDEF DebugDisableAutoSizing}('TAnchorDockHostSite.RemoveControl'){$ENDIF};
  end;
end;

procedure TAnchorDockHostSite.InsertControl(AControl: TControl; Index: integer);
begin
  DisableAutoSizing{$IFDEF DebugDisableAutoSizing}('TAnchorDockHostSite.InsertControl'){$ENDIF};
  try
    inherited InsertControl(AControl, Index);
    if not ((AControl is TAnchorDockSplitter)
            or (AControl is TAnchorDockHeader))
    then
      UpdateDockCaption;
    AControl.AddHandlerOnVisibleChanged(@ChildVisibleChanged);
  finally
    EnableAutoSizing{$IFDEF DebugDisableAutoSizing}('TAnchorDockHostSite.InsertControl'){$ENDIF};
  end;
end;

procedure TAnchorDockHostSite.UpdateDockCaption(Exclude: TControl);
var
  i: Integer;
  Child: TControl;
  NewCaption, OldCaption: String;
begin
  if csDestroying in ComponentState then exit;
  NewCaption:='';
  if Minimized then
  begin
    if Assigned(FMinimizedControl) then
      NewCaption:=FMinimizedControl.Caption;
  end
  else
    for i:=0 to ControlCount-1 do begin
      Child:=Controls[i];
      if Child=Exclude then continue;
      if (Child.HostDockSite=Self) or (Child is TAnchorDockHostSite)
      or (Child is TAnchorDockPageControl) then begin
        if NewCaption<>'' then
          NewCaption:=NewCaption+',';
        NewCaption:=NewCaption+Child.Caption;
      end;
    end;
  OldCaption:=Caption;
  Caption:=NewCaption;
  //debugln(['TAnchorDockHostSite.UpdateDockCaption Caption="',Caption,'" NewCaption="',NewCaption,'" HasParent=',Parent<>nil,' ',DbgSName(Header)]);
  Header.Caption:=Caption;
  if OldCaption<>Caption then begin
    //debugln(['TAnchorDockHostSite.UpdateDockCaption Caption="',Caption,'" NewCaption="',NewCaption,'" HasParent=',Parent<>nil]);
    if Parent is TAnchorDockHostSite then
      TAnchorDockHostSite(Parent).UpdateDockCaption;
    if Parent is TAnchorDockPage then
      TAnchorDockPage(Parent).UpdateDockCaption;
  end;
  // do not show close button for mainform
  Header.CloseButton.Visible:=(not IsParentOf(Application.MainForm));
end;

procedure TAnchorDockHostSite.GetSiteInfo(Client: TControl;
  var InfluenceRect: TRect; MousePos: TPoint; var CanDock: Boolean);
var
  ADockMargin: LongInt;
begin
  GetWindowRect(Handle, InfluenceRect);

  if (Parent=nil) or DockMaster.IsCustomSite(Parent) then begin
    // allow docking outside => enlarge margins
    ADockMargin:=DockMaster.DockOutsideMargin;
    //debugln(['TAnchorDockHostSite.GetSiteInfo ',DbgSName(Self),' allow outside ADockMargin=',ADockMargin,' ',dbgs(InfluenceRect)]);
    InfluenceRect.Left := InfluenceRect.Left-ADockMargin;
    InfluenceRect.Top := InfluenceRect.Top-ADockMargin;
    InfluenceRect.Right := InfluenceRect.Right+ADockMargin;
    InfluenceRect.Bottom := InfluenceRect.Bottom+ADockMargin;
  end else if Parent is TAnchorDockHostSite then begin
    // do not cover parent site => shrink margins
    ADockMargin:=DockMaster.DockParentMargin;
    ADockMargin:=Min(ADockMargin,Min(ClientWidth,ClientHeight) div 10);
    ADockMargin:=Max(0,ADockMargin);
    //debugln(['TAnchorDockHostSite.GetSiteInfo ',DbgSName(Self),' do not cover parent ADockMargin=',ADockMargin,' ',dbgs(InfluenceRect)]);
    InfluenceRect.Left := InfluenceRect.Left+ADockMargin;
    InfluenceRect.Top := InfluenceRect.Top+ADockMargin;
    InfluenceRect.Right := InfluenceRect.Right-ADockMargin;
    InfluenceRect.Bottom := InfluenceRect.Bottom-ADockMargin;
  end;

  CanDock:=(Client is TAnchorDockHostSite)
           and not DockMaster.AutoFreedIfControlIsRemoved(Self,Client)
           and not Minimized;
  //debugln(['TAnchorDockHostSite.GetSiteInfo ',DbgSName(Self),' ',dbgs(BoundsRect),' ',Caption,' CanDock=',CanDock,' PtIn=',PtInRect(InfluenceRect,MousePos)]);

  if Assigned(OnGetSiteInfo) then
    OnGetSiteInfo(Self, Client, InfluenceRect, MousePos, CanDock);
end;

function TAnchorDockHostSite.GetPageArea: TRect;
begin
  Result:=Rect(0,0,Width*DockMaster.PageAreaInPercent div 100,
               Height*DockMaster.PageAreaInPercent div 100);
  OffsetRect(Result,(Width*(100-DockMaster.PageAreaInPercent)) div 200,
                    (Height*(100-DockMaster.PageAreaInPercent)) div 200);
end;

procedure TAnchorDockHostSite.ChangeBounds(ALeft, ATop, AWidth,
  AHeight: integer; KeepBase: boolean);
begin
  inherited ChangeBounds(ALeft, ATop, AWidth, AHeight, KeepBase);
  if Header<>nil then UpdateHeaderAlign;
end;

procedure TAnchorDockHostSite.UpdateHeaderAlign;
var
  NeededHeaderPosition:TADLHeaderPosition;
  Splitter: TAnchorDockSplitter;
  SplitterAnchorKind:TAnchorKind;
begin
  if Header=nil then exit;
  if Minimized then begin
    if FindNearestSpliter(self,Splitter,SplitterAnchorKind) then begin
      NeededHeaderPosition:=OppositeAnchorKind2TADLHeaderPosition[SplitterAnchorKind];
    end else
      NeededHeaderPosition:=Header.HeaderPosition;
  end else
    NeededHeaderPosition:=Header.HeaderPosition;
  case NeededHeaderPosition of
  adlhpAuto:
    if Header.Align in [alLeft,alRight] then begin
      if (ClientHeight>0)
      and ((ClientWidth*100 div ClientHeight)<=DockMaster.HeaderAlignTop) then
        Header.Align:=alTop;
    end else begin
      if (ClientHeight>0)
      and ((ClientWidth*100 div ClientHeight)>=DockMaster.HeaderAlignLeft) then
      begin
        if Application.BidiMode=bdRightToLeft then
          Header.Align:=alRight
        else
          Header.Align:=alLeft;
      end;
    end;
  adlhpLeft: Header.Align:=alLeft;
  adlhpTop: Header.Align:=alTop;
  adlhpRight: Header.Align:=alRight;
  adlhpBottom: Header.Align:=alBottom;
  end;
end;

procedure TAnchorDockHostSite.UpdateHeaderShowing;
var
  Splitter: TAnchorDockSplitter;
  SplitterAnchorKind:TAnchorKind;
begin
  if Header=nil then exit;
  if HeaderNeedsShowing then begin
    Header.Parent:=Self;
    Header.MinimizeButton.Visible:=(DockMaster.DockSitesCanBeMinimized and CanBeMinimized(Splitter,SplitterAnchorKind))or Minimized;
    Header.MinimizeButton.Parent:=Header;
  end
  else
    Header.Parent:=nil;
end;

procedure TAnchorDockHostSite.BeginUpdateLayout;
begin
  inc(FUpdateLayout);
  if FUpdateLayout=1 then DockMaster.BeginUpdate;
end;

procedure TAnchorDockHostSite.EndUpdateLayout;
begin
  if FUpdateLayout=0 then RaiseGDBException('TAnchorDockHostSite.EndUpdateLayout');
  dec(FUpdateLayout);
  if FUpdateLayout=0 then
    DockMaster.EndUpdate;
end;

function TAnchorDockHostSite.UpdatingLayout: boolean;
begin
  Result:=(FUpdateLayout>0) or (csDestroying in ComponentState);
end;

function AcceptAlign(Site:TAnchorDockHostSite; AlignCandidate:TAlign):TAlign;
var
  i:integer;
  Splitter: TAnchorDockSplitter;
  SplitterAnchorKind:TAnchorKind;
  MinimizedSiteAlign:TAlign;
begin
  for i:=0 to Site.ControlCount-1 do
    if Site.Controls[i] is TAnchorDockHostSite then
      if (Site.Controls[i] as TAnchorDockHostSite).Minimized then begin
        if FindNearestSpliter(Site.Controls[i] as TAnchorDockHostSite,Splitter,SplitterAnchorKind) then begin
          MinimizedSiteAlign:=OppositeAnchorKind2Align[SplitterAnchorKind];
          if AlignCandidate=MinimizedSiteAlign then
            exit(alNone);
        end
      end;
  result:=AlignCandidate;
end;

function TAnchorDockHostSite.GetDockEdge(const MousePos: TPoint): TAlign;
begin
  result:=inherited;
  result:=AcceptAlign(self,result);
end;

procedure TAnchorDockHostSite.SaveLayout(
  LayoutTree: TAnchorDockLayoutTree; LayoutNode: TAnchorDockLayoutTreeNode);
var
  i: Integer;
  Site: TAnchorDockHostSite;
  ChildNode: TAnchorDockLayoutTreeNode;
  Child: TControl;
  Splitter: TAnchorDockSplitter;
  OneControl: TControl;
begin
  if SiteType=adhstOneControl then
    OneControl:=GetOneControl
  else
    OneControl:=nil;
  if (SiteType=adhstOneControl) and (OneControl<>nil)
  and (not (OneControl is TAnchorDockHostSite)) then begin
    LayoutNode.NodeType:=adltnControl;
    LayoutNode.Assign(Self,false,Minimized);
    LayoutNode.Name:=OneControl.Name;
    LayoutNode.HeaderPosition:=Header.HeaderPosition;
  end else if (SiteType in [adhstLayout,adhstOneControl]) then begin
    LayoutNode.NodeType:=adltnLayout;
    for i:=0 to ControlCount-1 do begin
      Child:=Controls[i];
      if Child.Owner=Self then continue;
      if (Child is TAnchorDockHostSite) then begin
        Site:=TAnchorDockHostSite(Child);
        ChildNode:=LayoutTree.NewNode(LayoutNode);
        Site.SaveLayout(LayoutTree,ChildNode);
      end else if (Child is TAnchorDockSplitter) then begin
        Splitter:=TAnchorDockSplitter(Child);
        ChildNode:=LayoutTree.NewNode(LayoutNode);
        Splitter.SaveLayout(ChildNode);
      end;
    end;
    LayoutNode.Assign(Self,false,Minimized);
    LayoutNode.HeaderPosition:=Header.HeaderPosition;
  end else if SiteType=adhstPages then begin
    LayoutNode.NodeType:=adltnPages;
    for i:=0 to Pages.PageCount-1 do begin
      Site:=Pages.DockPages[i].GetSite;
      if Site<>nil then begin
        ChildNode:=LayoutTree.NewNode(LayoutNode);
        Site.SaveLayout(LayoutTree,ChildNode);
      end;
    end;
    LayoutNode.Assign(Self,false,Minimized);
    LayoutNode.HeaderPosition:=Header.HeaderPosition;
    LayoutNode.TabPosition:=Pages.TabPosition;
    LayoutNode.PageIndex:=Pages.PageIndex;
  end else
    LayoutNode.NodeType:=adltnNone;
  if BoundSplitter<>nil then begin
    if Align in [alLeft,alRight] then
      LayoutNode.BoundSplitterPos:=BoundSplitter.Left
    else
      LayoutNode.BoundSplitterPos:=BoundSplitter.Top;
  end;
  LayoutNode.PixelsPerInch:=Screen.PixelsPerInch;
end;

constructor TAnchorDockHostSite.CreateNew(AOwner: TComponent; Num: Integer);
begin
  inherited CreateNew(AOwner,Num);
  FMinimizedControl:=Nil;
  Visible:=false;
  FHeaderSide:=akTop;
  FHeader:=DockMaster.HeaderClass.Create(Self);
  FHeader.Align:=alTop;
  FHeader.Parent:=Self;
  FSiteType:=adhstNone;
  UpdateHeaderAlign;
  DragKind:=dkDock;
  DockManager:=DockMaster.ManagerClass.Create(Self);
  UseDockManager:=true;
  DragManager.RegisterDockSite(Self,true);
  AddHandlerFirstShow(@FirstShow);
end;

destructor TAnchorDockHostSite.Destroy;
{$IFDEF VerboseAnchorDocking}
var i: Integer;
{$ENDIF}
begin
  {$IFDEF VerboseAnchorDocking}
  debugln(['TAnchorDockHostSite.Destroy ',DbgSName(Self),' Caption="',Caption,'" Self=',dbgs(Pointer(Self)),' ComponentCount=',ComponentCount,' ControlCount=',ControlCount]);
  for i:=0 to ComponentCount-1 do
    debugln(['TAnchorDockHostSite.Destroy Component ',i,'/',ComponentCount,' ',DbgSName(Components[i])]);
  for i:=0 to ControlCount-1 do
    debugln(['TAnchorDockHostSite.Destroy Control ',i,'/',ControlCount,' ',DbgSName(Controls[i])]);
  {$ENDIF}
  FreePages;
  inherited Destroy;
end;

{ TAnchorDockHeader }

procedure TAnchorDockHeader.PopupMenuPopup(Sender: TObject);
var
  HeaderPosItem: TMenuItem;
  ParentSite: TAnchorDockHostSite;
  Side: TAnchorKind;
  SideCaptions: array[TAnchorKind] of string;
  Item: TMenuItem;
  ContainsMainForm: boolean;
  s: String;
begin
  ParentSite:=TAnchorDockHostSite(Parent);
  SideCaptions[akLeft]:=adrsLeft;
  SideCaptions[akTop]:=adrsTop;
  SideCaptions[akRight]:=adrsRight;
  SideCaptions[akBottom]:=adrsBottom;

  // menu items: undock, merge
  DockMaster.AddRemovePopupMenuItem(ParentSite.CanUndock,'UndockMenuItem',
                                    adrsUndock,@UndockButtonClick);
  DockMaster.AddRemovePopupMenuItem(ParentSite.CanMerge,'MergeMenuItem',
                                    adrsMerge, @MergeButtonClick);

  // menu items: header position
  HeaderPosItem:=DockMaster.AddPopupMenuItem('HeaderPosMenuItem',
                                             adrsHeaderPosition, nil);
  Item:=DockMaster.AddPopupMenuItem('HeaderPosAutoMenuItem', adrsAutomatically,
                   @HeaderPositionItemClick, HeaderPosItem);
  if Item<>nil then begin
    Item.Tag:=ord(adlhpAuto);
    Item.Checked:=HeaderPosition=TADLHeaderPosition(Item.Tag);
  end;
  for Side:=Low(TAnchorKind) to High(TAnchorKind) do begin
    Item:=DockMaster.AddPopupMenuItem('HeaderPos'+DbgS(Side)+'MenuItem',
                     SideCaptions[Side], @HeaderPositionItemClick,
                     HeaderPosItem);
    if Item=nil then continue;
    Item.Tag:=ord(Side)+1;
    Item.Checked:=HeaderPosition=TADLHeaderPosition(Item.Tag);
  end;

  // menu items: enlarge
  for Side:=Low(TAnchorKind) to High(TAnchorKind) do begin
    Item:=DockMaster.AddRemovePopupMenuItem(ParentSite.EnlargeSide(Side,true),
      'Enlarge'+DbgS(Side)+'MenuItem', Format(adrsEnlargeSide, [
        SideCaptions[Side]]),@EnlargeSideClick);
    if Item<>nil then Item.Tag:=ord(Side);
  end;

  // menu item: close or quit
  ContainsMainForm:=ParentSite.IsParentOf(Application.MainForm);
  if ContainsMainForm then
    s:=Format(adrsQuit, [Application.Title])
  else
    s:=adrsClose;
  DockMaster.AddRemovePopupMenuItem(CloseButton.Visible,'CloseMenuItem',s,
                                    @CloseButtonClick);
end;

procedure TAnchorDockHeader.CloseButtonClick(Sender: TObject);
var
  HeaderParent:TAnchorDockHostSite;
begin
  TWinControl(HeaderParent):=Parent;
  if HeaderParent=TWinControl(DockMaster.FOverlappingForm) then begin
    HeaderParent:=DockMaster.FOverlappingForm.AnchorDockHostSite;
    HeaderParent.HideMinimizedControl;
  end;
  if HeaderParent is TAnchorDockHostSite then begin
    DockMaster.RestoreLayouts.Add(DockMaster.CreateRestoreLayout(HeaderParent),true);
    HeaderParent.CloseSite;
  end;
end;

procedure TAnchorDockHeader.MinimizeButtonClick(Sender: TObject);
var
  HeaderParent:TAnchorDockHostSite;
begin
  TWinControl(HeaderParent):=Parent;
  if HeaderParent=TWinControl(DockMaster.FOverlappingForm) then begin
    HeaderParent:=DockMaster.FOverlappingForm.AnchorDockHostSite;
    HeaderParent.HideMinimizedControl;
  end;
  if HeaderParent is TAnchorDockHostSite then begin
    HeaderParent.MinimizeSite;
  end;
end;

procedure TAnchorDockHeader.HeaderPositionItemClick(Sender: TObject);
var
  Item: TMenuItem;
begin
  if not (Sender is TMenuItem) then exit;
  Item:=TMenuItem(Sender);
  HeaderPosition:=TADLHeaderPosition(Item.Tag);
end;

procedure TAnchorDockHeader.UndockButtonClick(Sender: TObject);
begin
  TAnchorDockHostSite(Parent).Undock;
end;

procedure TAnchorDockHeader.MergeButtonClick(Sender: TObject);
begin
  TAnchorDockHostSite(Parent).Merge;
end;

procedure TAnchorDockHeader.EnlargeSideClick(Sender: TObject);
var
  Side: TAnchorKind;
begin
  if not (Sender is TMenuItem) then exit;
  Side:=TAnchorKind(TMenuItem(Sender).Tag);
  TAnchorDockHostSite(Parent).EnlargeSide(Side,false);
end;

procedure TAnchorDockHeader.SetHeaderPosition(const AValue: TADLHeaderPosition);
begin
  if FHeaderPosition=AValue then exit;
  FHeaderPosition:=AValue;
  if Parent is TAnchorDockHostSite then
    TAnchorDockHostSite(Parent).UpdateHeaderAlign;
end;

procedure TAnchorDockHeader.Draw(HeaderStyle:TADHeaderStyle);
var
  r: TRect;
  TxtH: longint;
  TxtW: longint;
  dx,dy: Integer;
  //NeedDrawHeaderAfterText,NeedHighlightText:boolean;
begin
  r:=ClientRect;
  if not HeaderStyle.StyleDesc.NeedDrawHeaderAfterText then begin
      HeaderStyle.DrawProc(Canvas,HeaderStyle.StyleDesc,r,not(Align in [alLeft,alRight]),FFocused);
  end else begin
    Canvas.Brush.Color := clForm;
    if DockMaster.HeaderFilled then
       Canvas.FillRect(r);
    if not DockMaster.HeaderFlatten then
       Canvas.Frame3d(r,1,bvRaised);
  end;
  {case DockMaster.HeaderStyle of
  adhsPoints: Canvas.Brush.Color := clForm;
  else Canvas.Frame3d(r,1,bvRaised);
  end;
  Canvas.FillRect(r);}

  if CloseButton.IsControlVisible and (CloseButton.Parent=Self) then begin
    if Align in [alLeft,alRight] then
      r.Top:=CloseButton.Top+CloseButton.Height+ButtonBorderSpacingAround
    else
      r.Right:=CloseButton.Left-ButtonBorderSpacingAround;
  end;

  if MinimizeButton.IsControlVisible and (MinimizeButton.Parent=Self) then begin
    if Align in [alLeft,alRight] then
      r.Top:=MinimizeButton.Top+MinimizeButton.Height+ButtonBorderSpacingAround
    else
      r.Right:=MinimizeButton.Left-ButtonBorderSpacingAround;
  end;

  // caption
  if Caption<>'' then begin
    if FFocused and DockMaster.HeaderHighlightFocused and HeaderStyle.StyleDesc.NeedHighlightText then
      Canvas.Font.Bold:=true
    else
      Canvas.Font.Bold:=False;
    Canvas.Brush.Color:=clNone;
    Canvas.Brush.Style:=bsClear;
    TxtH:=Canvas.TextHeight('ABCMgq');
    TxtW:=Canvas.TextWidth(Caption);
    if Align in [alLeft,alRight] then begin
      // vertical
      dx:=Max(0,(r.Right-r.Left-TxtH) div 2);
      {$IFDEF LCLWin32}
      dec(dx,2);
      {$ENDIF}
      dy:=Max(0,(r.Bottom-r.Top-TxtW) div 2);
      Canvas.Font.Orientation:=900;
      if TxtW<(r.Bottom-r.Top)then
      begin
        // text fits
        Canvas.TextOut(r.Left+dx-1,r.Bottom-dy,Caption);
        if HeaderStyle.StyleDesc.NeedDrawHeaderAfterText then begin
          HeaderStyle.DrawProc(Canvas,HeaderStyle.StyleDesc,Rect(r.Left,r.Top,r.Right,r.Bottom-dy-TxtW-1),false,FFocused);
          HeaderStyle.DrawProc(Canvas,HeaderStyle.StyleDesc,Rect(r.Left,r.Bottom-dy+1,r.Right,r.Bottom),false,FFocused);
        end;
      end else begin
        // text does not fit
        if HeaderStyle.StyleDesc.NeedDrawHeaderAfterText then
          HeaderStyle.DrawProc(Canvas,HeaderStyle.StyleDesc,r,false,FFocused);
      end;
    end else begin
      // horizontal
      dx:=Max(0,(r.Right-r.Left-TxtW) div 2);
      dy:=Max(0,(r.Bottom-r.Top-TxtH) div 2);
      Canvas.Font.Orientation:=0;
      if TxtW<(r.right-r.Left)then
      begin
        // text fits
        Canvas.TextRect(r,dx+2,dy,Caption);
        if HeaderStyle.StyleDesc.NeedDrawHeaderAfterText then begin
          HeaderStyle.DrawProc(Canvas,HeaderStyle.StyleDesc,Rect(r.Left,r.Top,r.Left+dx-1,r.Bottom),true,FFocused);
          HeaderStyle.DrawProc(Canvas,HeaderStyle.StyleDesc,Rect(r.Left+dx+TxtW+2,r.Top,r.Right,r.Bottom),true,FFocused);
        end;
      end else begin
        // text does not fit
        if HeaderStyle.StyleDesc.NeedDrawHeaderAfterText then
          HeaderStyle.DrawProc(Canvas,HeaderStyle.StyleDesc,r,true,FFocused);
      end;
    end;
  end
  else if HeaderStyle.StyleDesc.NeedDrawHeaderAfterText then
    if Align in [alLeft,alRight] then
      HeaderStyle.DrawProc(Canvas,HeaderStyle.StyleDesc,r,false,FFocused)
    else
      HeaderStyle.DrawProc(Canvas,HeaderStyle.StyleDesc,r,true,FFocused);
end;

procedure TAnchorDockHeader.Paint;
begin
  draw(DockMaster.CurrentADHeaderStyle);
end;

procedure TAnchorDockHeader.CalculatePreferredSize(var PreferredWidth,
  PreferredHeight: integer; WithThemeSpace: Boolean);
const
  TestTxt = 'ABCXYZ123gqj';
var
  DC: HDC;
  R: TRect;
  OldFont: HGDIOBJ;
  Flags: cardinal;
  NeededHeight: Integer;
begin
  inherited CalculatePreferredSize(PreferredWidth,PreferredHeight,WithThemeSpace);
  if Caption<>'' then begin
    DC := GetDC(Parent.Handle);
    try
      R := Rect(0, 0, 10000, 10000);
      OldFont := SelectObject(DC, HGDIOBJ(Font.Reference.Handle));
      Flags := DT_CALCRECT or DT_EXPANDTABS or DT_SINGLELINE or DT_NOPREFIX;

      DrawText(DC, PChar(TestTxt), Length(TestTxt), R, Flags);
      SelectObject(DC, OldFont);
      NeededHeight := R.Bottom - R.Top + BevelWidth*2;
    finally
      ReleaseDC(Parent.Handle, DC);
    end;
    if Align in [alLeft,alRight] then begin
      PreferredWidth:=Max(NeededHeight,PreferredWidth);
    end else begin
      PreferredHeight:=Max(NeededHeight,PreferredHeight);
    end;
  end else begin
    NeededHeight:=CloseButton.Height;
    if Align in [alLeft,alRight] then begin
      PreferredWidth:=Max(NeededHeight,PreferredWidth);
    end else begin
      PreferredHeight:=Max(NeededHeight,PreferredHeight);
  end;
  end;
end;

procedure TAnchorDockHeader.MouseDown(Button: TMouseButton; Shift: TShiftState;
  X, Y: Integer);
var
  SiteMinimized:Boolean;
begin
  inherited MouseDown(Button, Shift, X, Y);
  SiteMinimized:=False;
  FUseTimer:=false;
  StopMouseNoMoveTimer;
  if Parent is TAnchorDockHostSite then
    SiteMinimized:=(Parent as TAnchorDockHostSite).Minimized;
  if SiteMinimized then begin
    DoMouseNoMoveTimer(nil);
  end else
    begin
      if parent<>nil then
        if DockMaster.FOverlappingForm<>nil then
          //if parent=DockMaster.FOverlappingForm.Panel then
            DockMaster.HideOverlappingForm(nil);
      if (Button=mbLeft) and (DockMaster.AllowDragging) and (DockMaster.FOverlappingForm=nil) then
        DragManager.DragStart(Parent,false,DockMaster.DragTreshold);
    end;
end;

procedure  TAnchorDockHeader.MouseMove(Shift: TShiftState; X,Y: Integer);
begin
  inherited MouseMove(Shift, X, Y);
  if parent<>nil then
    if parent is TAnchorDockHostSite then
      if (parent as TAnchorDockHostSite).Minimized then
        if DockMaster.FOverlappingForm=nil then
          if FMouseTimeStartX=EmptyMouseTimeStartX then
            StartMouseNoMoveTimer
          else begin
            if (abs(FMouseTimeStartX-X)>MouseNoMoveDelta) or (abs(FMouseTimeStartY-Y)>MouseNoMoveDelta)then
            StopMouseNoMoveTimer;
          end;
  if (parent is TAnchorDockHostSite) and (DockMaster.FOverlappingForm=nil)then
    FUseTimer:=true;
end;

procedure TAnchorDockHeader.MouseLeave;
begin
  inherited;
  StopMouseNoMoveTimer;
end;

procedure TAnchorDockHeader.StartMouseNoMoveTimer;
begin
  if FUseTimer then begin
    if DockTimer.Enabled then DockTimer.Enabled:=false;
    DockTimer.Interval:=MouseNoMoveTime;
    DockTimer.OnTimer:=@DoMouseNoMoveTimer;
    DockTimer.Enabled:=true;
  end;
end;

procedure TAnchorDockHeader.StopMouseNoMoveTimer;
begin
  FMouseTimeStartX:=EmptyMouseTimeStartX;
  DockTimer.OnTimer:=nil;
  DockTimer.Enabled:=false;
end;

procedure TAnchorDockHeader.DoMouseNoMoveTimer(Sender: TObject);
begin
  StopMouseNoMoveTimer;
  //if FUseTimer then
    if parent<>nil then
      if parent is TAnchorDockHostSite then
        if (parent as TAnchorDockHostSite).Minimized then
          (parent as TAnchorDockHostSite).ShowMinimizedControl;
end;

procedure TAnchorDockHeader.UpdateHeaderControls;
begin
  if Align in [alLeft,alRight] then begin
    if CloseButton<>nil then begin
      //MinimizeButton.Align:=alTop;
      //CloseButton.Align:=alTop;
      CloseButton.AnchorSide[akLeft].Side := asrCenter;
      CloseButton.AnchorSide[akLeft].Control := Self;
      CloseButton.AnchorSide[akTop].Side := asrTop;
      CloseButton.AnchorSide[akTop].Control := Self;
      CloseButton.Anchors := [akTop] + [akLeft];

      MinimizeButton.AnchorSide[akLeft].Side := asrCenter;
      MinimizeButton.AnchorSide[akLeft].Control := Self;
      MinimizeButton.AnchorSide[akTop].Side := asrBottom;
      MinimizeButton.AnchorSide[akTop].Control := CloseButton;
      MinimizeButton.Anchors := [akTop] + [akLeft];
    end;
  end else begin
    if CloseButton<>nil then begin
      //MinimizeButton.Align:=alRight;
      //CloseButton.Align:=alRight;
      CloseButton.AnchorSide[akRight].Side := asrRight;
      CloseButton.AnchorSide[akRight].Control := Self;
      CloseButton.AnchorSide[akTop].Side := asrCenter;
      CloseButton.AnchorSide[akTop].Control := Self;
      CloseButton.Anchors := [akTop] + [akRight];

      MinimizeButton.AnchorSide[akRight].Side := asrLeft;
      MinimizeButton.AnchorSide[akRight].Control := CloseButton;
      MinimizeButton.AnchorSide[akTop].Side := asrCenter;
      MinimizeButton.AnchorSide[akTop].Control := Self;
      MinimizeButton.Anchors := [akTop] + [akRight];
    end;
  end;
  CloseButton.BorderSpacing.Around:=ButtonBorderSpacingAround;
  MinimizeButton.BorderSpacing.Around:=ButtonBorderSpacingAround;
  //debugln(['TAnchorDockHeader.UpdateHeaderControls ',dbgs(Align),' ',dbgs(CloseButton.Align)]);
end;

procedure TAnchorDockHeader.SetAlign(Value: TAlign);
begin
  if Value=Align then exit;
  DisableAutoSizing{$IFDEF DebugDisableAutoSizing}('TAnchorDockHostSite.SetAlign'){$ENDIF};
  try
    inherited SetAlign(Value);
    UpdateHeaderControls;
  finally
    EnableAutoSizing{$IFDEF DebugDisableAutoSizing}('TAnchorDockHostSite.SetAlign'){$ENDIF};
  end;
end;

procedure TAnchorDockHeader.DoOnShowHint(HintInfo: PHintInfo);
var
  s: String;
  p: LongInt;
  c: String;
begin
  s:=DockMaster.GetLocalizedHeaderHint;
  p:=Pos('%s',s);
  if p>0 then begin
    if Parent<>nil then
      c:=Parent.Caption
    else
      c:='';
    s:=Format(s,[c]);
  end;
  //debugln(['TAnchorDockHeader.DoOnShowHint "',s,'" "',DockMaster.HeaderHint,'"']);
  HintInfo^.HintStr:=s;
  inherited DoOnShowHint(HintInfo);
end;

constructor TAnchorDockHeader.Create(TheOwner: TComponent);
begin
  inherited Create(TheOwner);
  FHeaderPosition:=adlhpAuto;
  BevelOuter:=bvNone;
  BorderWidth:=0;
  FCloseButton:=TAnchorDockCloseButton.Create(Self);
  with FCloseButton do begin
    Name:='CloseButton';
    Parent:=Self;
    Flat:=true;
    ShowHint:=true;
    Hint:=adrsClose;
    OnClick:=@CloseButtonClick;
    AutoSize:=true;
  end;
  FMinimizeButton:=TAnchorDockMinimizeButton.Create(Self);
  with FMinimizeButton do begin
    Name:='MinimizeButton';
    Parent:=Self;
    Flat:=true;
    ShowHint:=true;
    Hint:=adrsMinimize;
    OnClick:=@MinimizeButtonClick;
    AutoSize:=true;
  end;
  Align:=alTop;
  AutoSize:=true;
  ShowHint:=true;
  PopupMenu:=DockMaster.GetPopupMenu;
  FFocused:=false;
  FMouseTimeStartX:=EmptyMouseTimeStartX;
  FUseTimer:=true;
end;

{ TAnchorDockCloseButton }

function TAnchorDockCloseButton.GetDrawDetails: TThemedElementDetails;

function WindowPart: TThemedWindow;
  begin
    // no check states available
    Result := twCloseButtonNormal;
    if not IsEnabled then
      Result := {$IFDEF LCLWIN32}twCloseButtonDisabled{$ELSE}twSmallCloseButtonDisabled{$ENDIF}
    else
    if FState in [bsDown, bsExclusive] then
      Result := {$IFDEF LCLWIN32}twCloseButtonPushed{$ELSE}twSmallCloseButtonPushed{$ENDIF}
    else
    if FState = bsHot then
      Result := {$IFDEF LCLWIN32}twCloseButtonHot{$ELSE}twSmallCloseButtonHot{$ENDIF}
    else
      Result := {$IFDEF LCLWIN32}twCloseButtonNormal;{$ELSE}twSmallCloseButtonNormal;{$ENDIF}
  end;

begin
  Result := ThemeServices.GetElementDetails(WindowPart);
end;

procedure SizeCorrector(var current,recomend:integer);
begin
  if recomend<0 then begin
    if current>0 then
      recomend:=current
    else
      current:=HardcodedButtonSize;
  end else begin
      if current>recomend then
        current:=recomend
      else begin
        if current>0 then
         recomend:=current
        else
         current:=recomend;
      end;
  end;
end;

procedure ButtonSizeCorrector(var w,h:integer);
begin
  SizeCorrector(w,PreferredButtonWidth);
  SizeCorrector(h,PreferredButtonHeight);
end;

procedure TAnchorDockCloseButton.CalculatePreferredSize(var PreferredWidth,
  PreferredHeight: integer; WithThemeSpace: Boolean);
begin
  with ThemeServices.GetDetailSize(ThemeServices.GetElementDetails(twSmallCloseButtonNormal)) do
  begin
    PreferredWidth:=cx;
    PreferredHeight:=cy;
    ButtonSizeCorrector(PreferredWidth,PreferredHeight);
    {$IF defined(LCLGtk2) or defined(Carbon)}
    inc(PreferredWidth,2);
    inc(PreferredHeight,2);
    {$ENDIF}
    PreferredWidth:=ScaleDesignToForm(PreferredWidth);
    PreferredHeight:=ScaleDesignToForm(PreferredHeight);
  end;
end;

{ TAnchorDockMinimizeButton }

function TAnchorDockMinimizeButton.GetDrawDetails: TThemedElementDetails;

function WindowPart: TThemedWindow;
  begin
    // no check states available
    Result := twMinButtonNormal;
    if not IsEnabled then
      Result := {$IFDEF LCLGtk2}twMDIRestoreButtonDisabled{$ELSE}twMinButtonDisabled{$ENDIF}
    else
    if FState in [bsDown, bsExclusive] then
      Result := {$IFDEF LCLGtk2}twMDIRestoreButtonPushed{$ELSE}twMinButtonPushed{$ENDIF}
    else
    if FState = bsHot then
      Result := {$IFDEF LCLGtk2}twMDIRestoreButtonHot{$ELSE}twMinButtonHot{$ENDIF}
    else
      Result := {$IFDEF LCLGtk2}twMDIRestoreButtonNormal{$ELSE}twMinButtonNormal{$ENDIF};
  end;

begin
  Result := ThemeServices.GetElementDetails(WindowPart);
end;

procedure TAnchorDockMinimizeButton.CalculatePreferredSize(var PreferredWidth,
  PreferredHeight: integer; WithThemeSpace: Boolean);
begin
  with ThemeServices.GetDetailSize(ThemeServices.GetElementDetails({$IFDEF LCLGtk2}twMDIRestoreButtonNormal{$ELSE}twMinButtonNormal{$ENDIF})) do
  begin
    PreferredWidth:=cx;
    PreferredHeight:=cy;
    ButtonSizeCorrector(PreferredWidth,PreferredHeight);
    {$IF defined(LCLGtk2) or defined(Carbon)}
    inc(PreferredWidth,2);
    inc(PreferredHeight,2);
    {$ENDIF}
    PreferredWidth:=ScaleDesignToForm(PreferredWidth);
    PreferredHeight:=ScaleDesignToForm(PreferredHeight);
  end;
end;

{ TAnchorDockManager }

procedure TAnchorDockManager.SetPreferredSiteSizeAsSiteMinimum(
  const AValue: boolean);
begin
  if FPreferredSiteSizeAsSiteMinimum=AValue then exit;
  FPreferredSiteSizeAsSiteMinimum:=AValue;
  if DockSite=nil then
    Site.AdjustSize;
end;

constructor TAnchorDockManager.Create(ADockSite: TWinControl);
begin
  inherited Create(ADockSite);
  FSite:=ADockSite;
  FDockableSites:=[akLeft,akTop,akBottom,akRight];
  FInsideDockingAllowed:=true;
  FPreferredSiteSizeAsSiteMinimum:=true;
  if (ADockSite is TAnchorDockHostSite) then
    FDockSite:=TAnchorDockHostSite(ADockSite);
end;

procedure TAnchorDockManager.GetControlBounds(Control: TControl; out
  AControlBounds: TRect);
begin
  if Control=nil then ;
  AControlBounds:=Rect(0,0,0,0);
  //debugln(['TAnchorDockManager.GetControlBounds DockSite="',DockSite.Caption,'" Control=',DbgSName(Control)]);
end;

procedure TAnchorDockManager.InsertControl(Control: TControl; InsertAt: TAlign;
  DropCtl: TControl);
begin
  if Control=nil then;
  if InsertAt=alNone then ;
  if DropCtl=nil then ;
end;

procedure TAnchorDockManager.InsertControl(ADockObject: TDragDockObject);
var
  NewSiteBounds: TRect;
  NewChildBounds: TRect;
  Child: TControl;
  ChildSite: TAnchorDockHostSite;
  SplitterWidth: Integer;
begin
  if DockSite<>nil then begin
    // handled by TAnchorDockHostSite
    //debugln(['TAnchorDockManager.InsertControl DockSite="',DockSite.Caption,'" Control=',DbgSName(ADockObject.Control),' InsertAt=',dbgs(ADockObject.DropAlign)])
  end else begin
    {$IFDEF VerboseAnchorDocking}
    debugln(['TAnchorDockManager.InsertControl DockSite=nil Site="',DbgSName(Site),'" Control=',DbgSName(ADockObject.Control),' InsertAt=',dbgs(ADockObject.DropAlign),' Site.Bounds=',dbgs(Site.BoundsRect),' Control.Client=',dbgs(ADockObject.Control.ClientRect),' Parent=',DbgSName(ADockObject.Control.Parent)]);
    {$ENDIF}
    Site.DisableAutoSizing{$IFDEF DebugDisableAutoSizing}('TAnchorDockManager.InsertControl'){$ENDIF};
    try
      // align dragged Control
      Child:=ADockObject.Control;
      Child.Parent:=Site;
      Child.Align:=ADockObject.DropAlign;
      Child.Width:=ADockObject.DockRect.Right-ADockObject.DockRect.Left;
      Child.Height:=ADockObject.DockRect.Bottom-ADockObject.DockRect.Top;

      SplitterWidth:=0;
      ChildSite:=nil;
      if Child is TAnchorDockHostSite then begin
        ChildSite:=TAnchorDockHostSite(Child);
        ChildSite.CreateBoundSplitter(Site is TAnchorDockPanel);
        SplitterWidth:=DockMaster.SplitterWidth;
      end;

      if Site is TAnchorDockPanel then
        ADockObject.DropAlign:=alClient;

      // resize Site
      NewSiteBounds:=Site.BoundsRect;
      case ADockObject.DropAlign of
      alLeft: dec(NewSiteBounds.Left,Child.ClientWidth+SplitterWidth);
      alRight: dec(NewSiteBounds.Right,Child.ClientWidth+SplitterWidth);
      alTop: dec(NewSiteBounds.Top,Child.ClientHeight+SplitterWidth);
      alBottom: inc(NewSiteBounds.Bottom,Child.ClientHeight+SplitterWidth);
      alClient: ;
      end;
      if not StoredConstraintsValid then
        StoreConstraints;
      if ADockObject.DropAlign in [alLeft,alRight] then
        Site.Constraints.MaxWidth:=0
      else if ADockObject.DropAlign in [alTop,alBottom] then
        Site.Constraints.MaxHeight:=0;
      Site.BoundsRect:=NewSiteBounds;
      if ADockObject.DropAlign=alClient then
        Child.Align:=alClient;

      //debugln(['TAnchorDockManager.InsertControl Site.BoundsRect=',dbgs(Site.BoundsRect),' NewSiteBounds=',dbgs(NewSiteBounds),' Child.ClientRect=',dbgs(Child.ClientRect)]);
      FSiteClientRect:=Site.ClientRect;

      // resize child
      NewChildBounds:=Child.BoundsRect;
      case ADockObject.DropAlign of
      alTop: NewChildBounds:=Bounds(0,0,Site.ClientWidth,Child.ClientHeight);
      alBottom: NewChildBounds:=Bounds(0,Site.ClientHeight-Child.ClientHeight,
                                       Site.ClientWidth,Child.ClientHeight);
      alLeft: NewChildBounds:=Bounds(0,0,Child.ClientWidth,Site.ClientHeight);
      alRight: NewChildBounds:=Bounds(Site.ClientWidth-Child.ClientWidth,0,
                                      Child.ClientWidth,Site.ClientHeight);
      alClient: NewChildBounds:=Bounds(0,0,
                                       Site.ClientWidth,Site.ClientHeight);
      end;
      Child.BoundsRect:=NewChildBounds;
      NewChildBounds:=Child.BoundsRect;

      if ChildSite<>nil then
        ChildSite.PositionBoundSplitter;

      // only allow to dock one control
      DragManager.RegisterDockSite(Site,false);
      {$IFDEF VerboseAnchorDocking}
      debugln(['TAnchorDockManager.InsertControl AFTER Site="',DbgSName(Site),'" Control=',DbgSName(ADockObject.Control),' InsertAt=',dbgs(ADockObject.DropAlign),' Site.Bounds=',dbgs(Site.BoundsRect),' Control.ClientRect=',dbgs(ADockObject.Control.ClientRect)]);
      {$ENDIF}
    finally
      Site.EnableAutoSizing{$IFDEF DebugDisableAutoSizing}('TAnchorDockManager.InsertControl'){$ENDIF};
    end;
  end;
end;

procedure TAnchorDockManager.LoadFromStream(Stream: TStream);
begin
  debugln(['TAnchorDockManager.LoadFromStream not implemented Site="',DbgSName(Site),'"']);
  if Stream=nil then ;
end;

procedure TAnchorDockManager.PositionDockRect(Client, DropCtl: TControl;
  DropAlign: TAlign; var DockRect: TRect);
{ Client = dragged source site (a TAnchorDockHostSite)
  DropCtl is target control (the DockSite, DockSite.Pages or one of the pages)
  DropAlign: where on Client DropCtl should be placed
  DockRect: the estimated new bounds of DropCtl
}
var
  Offset: TPoint;
  Inside: Boolean;
begin
  if (DropAlign=alClient) and (DockSite<>nil) and (DockSite.Pages<>nil) then begin
    // dock into pages
    if DropCtl=DockSite.Pages then begin
      // dock as last page
      DockRect:=DockSite.Pages.TabRect(DockSite.Pages.PageCount-1);
      case DockSite.Pages.TabPosition of
      tpTop,tpBottom: DockRect.Left:=(DockRect.Left+DockRect.Right) div 2;
      tpLeft,tpRight: DockRect.Top:=(DockRect.Top+DockRect.Bottom) div 2;
      end;
      Offset:=DockSite.Pages.ClientOrigin;
      OffsetRect(DockRect,Offset.X,Offset.Y);
      exit;
    end else if DropCtl is TAnchorDockPage then begin
      // dock in front of page
      DockRect:=DockSite.Pages.TabRect(TAnchorDockPage(DropCtl).PageIndex);
      case DockSite.Pages.TabPosition of
      tpTop,tpBottom: DockRect.Right:=(DockRect.Left+DockRect.Right) div 2;
      tpLeft,tpRight: DockRect.Bottom:=(DockRect.Top+DockRect.Bottom) div 2;
      end;
      Offset:=DockSite.Pages.ClientOrigin;
      OffsetRect(DockRect,Offset.X,Offset.Y);
      exit;
    end;
  end;

  Inside:=(DropCtl=Site);
  if (not Inside) and (Site.Parent<>nil) then begin
    if (Site.Parent is TAnchorDockHostSite)
    or (not (Site.Parent.DockManager is TAnchorDockManager))
    or (Site.Parent.Parent<>nil) then
      Inside:=true;
  end;

  if Site is TAnchorDockPanel then begin
    DockRect:=Bounds(Site.ClientOrigin.x,Site.ClientOrigin.y,Site.ClientWidth,Site.ClientHeight);
    exit;
  end;

  case DropAlign of
  alLeft:
    if Inside then
      DockRect:=Rect(0,0,Min(Client.Width,Site.ClientWidth div 2),Site.ClientHeight)
    else
      DockRect:=Rect(-Client.Width,0,0,Site.ClientHeight);
  alRight:
    if Inside then begin
      DockRect:=Rect(0,0,Min(Client.Width,Site.Width div 2),Site.ClientHeight);
      OffsetRect(DockRect,Site.ClientWidth-DockRect.Right,0);
    end else
      DockRect:=Bounds(Site.ClientWidth,0,Client.Width,Site.ClientHeight);
  alTop:
    if Inside then
      DockRect:=Rect(0,0,Site.ClientWidth,Min(Client.Height,Site.ClientHeight div 2))
    else
      DockRect:=Rect(0,-Client.Height,Site.ClientWidth,0);
  alBottom:
    if Inside then begin
      DockRect:=Rect(0,0,Site.ClientWidth,Min(Client.Height,Site.ClientHeight div 2));
      OffsetRect(DockRect,0,Site.ClientHeight-DockRect.Bottom);
    end else
      DockRect:=Bounds(0,Site.ClientHeight,Site.ClientWidth,Client.Height);
  alClient:
    begin
      // paged docking => show center
      if DockSite<>nil then
        DockRect:=DockSite.GetPageArea;
    end;
  else
    exit; // use default
  end;
  Offset:=Site.ClientOrigin;
  OffsetRect(DockRect,Offset.X,Offset.Y);
end;

procedure TAnchorDockManager.RemoveControl(Control: TControl);
var
  NewBounds: TRect;
  ChildSite: TAnchorDockHostSite;
  SplitterWidth: Integer;
begin
  if DockSite<>nil then
  begin
    {$IFDEF VerboseAnchorDocking}
    debugln(['TAnchorDockManager.RemoveControl DockSite="',DockSite.Caption,'" Control=',DbgSName(Control)]);
    {$ENDIF}
    if DockSite.Minimized then
      DockSite.RemoveMinimizedControl;
  end
  else begin
    {$IFDEF VerboseAnchorDocking}
    debugln(['TAnchorDockManager.RemoveControl Site="',DbgSName(Site),'" Control=',DbgSName(Control)]);
    {$ENDIF}
    if Control is TAnchorDockHostSite then begin
      SplitterWidth:=0;
      if Control is TAnchorDockHostSite then begin
        ChildSite:=TAnchorDockHostSite(Control);
        if ChildSite.BoundSplitter<>nil then
          SplitterWidth:=DockMaster.SplitterWidth;
      end;

      // shrink Site
      NewBounds:=Site.BoundsRect;
      case Control.Align of
      alTop: inc(NewBounds.Top,Control.Height+SplitterWidth);
      alBottom: dec(NewBounds.Bottom,Control.Height+SplitterWidth);
      alLeft: inc(NewBounds.Left,Control.Width+SplitterWidth);
      alRight: dec(NewBounds.Right,Control.Width+SplitterWidth);
      end;
      if StoredConstraintsValid then begin
        // restore constraints
        with Site.Constraints do begin
          MinWidth:=FStoredConstraints.Left;
          MinHeight:=FStoredConstraints.Top;
          MaxWidth:=FStoredConstraints.Right;
          MaxHeight:=FStoredConstraints.Bottom;
        end;
        FStoredConstraints:=Rect(0,0,0,0);
      end;
      Site.BoundsRect:=NewBounds;
      {$IFDEF VerboseAnchorDocking}
      debugln(['TAnchorDockManager.RemoveControl Site=',DbgSName(Site),' ',dbgs(Site.BoundsRect)]);
      {$ENDIF}

      // Site can dock a control again
      DragManager.RegisterDockSite(Site,true);
    end;
  end;
end;

procedure TAnchorDockManager.ResetBounds(Force: Boolean);
var
  OldSiteClientRect: TRect;
  WidthDiff: Integer;
  HeightDiff: Integer;
  ClientRectChanged: Boolean;

  procedure AlignChilds;
  var
    i: Integer;
    b: TRect;
    AControl: TControl;
    ChildMaxSize: TPoint;
    SiteMinSize: TPoint;
    Child: TAnchorDockHostSite;
  begin
    if ClientRectChanged and DockMaster.Restoring then begin
      // ClientRect changed => restore bounds
      for i:=0 to Site.ControlCount-1 do begin
        AControl:=Site.Controls[i];
        b:=Rect(0,0,0,0);
        if AControl is TAnchorDockHostSite then
          b:=TAnchorDockHostSite(AControl).DockRestoreBounds
        else if AControl is TAnchorDockSplitter then
          b:=TAnchorDockSplitter(AControl).DockRestoreBounds;
        if (b.Right<=b.Left) or (b.Bottom<=b.Top) then
          b:=AControl.BoundsRect;
        {$IFDEF VerboseAnchorDockRestore}
        debugln(['TAnchorDockManager.ResetBounds RESTORE ',DbgSName(AControl),' Cur=',dbgs(AControl.BoundsRect),' Restore=',dbgs(b)]);
        {$ENDIF}
        if AControl is TAnchorDockSplitter then begin
          // fit splitter into clientarea
          if AControl.AnchorSide[akLeft].Control=nil then
            b.Left:=Max(0,Min(b.Left,Site.ClientWidth-10));
          if AControl.AnchorSide[akTop].Control=nil then
            b.Top:=Max(0,Min(b.Top,Site.ClientHeight-10));
          if TAnchorDockSplitter(AControl).ResizeAnchor in [akLeft,akRight] then
          begin
            b.Right:=b.Left+DockMaster.SplitterWidth;
            b.Bottom:=Max(1,Min(b.Bottom,Site.ClientHeight-b.Top));
          end
          else begin
            b.Right:=Max(1,Min(b.Right,Site.ClientWidth-b.Left));
            b.Bottom:=b.Top+DockMaster.SplitterWidth;
          end;
        end;

        AControl.BoundsRect:=b;
        if AControl is TAnchorDockSplitter then
          TAnchorDockSplitter(AControl).UpdateDockBounds;
      end;
      exit;
    end;

    if DockSite<>nil then exit;
    Child:=GetChildSite;
    if Child=nil then exit;

    {$IFDEF VerboseAnchorDockRestore}
    debugln(['TAnchorDockManager.ResetBounds ',DbgSName(Site),' ',dbgs(Child.BaseBounds),' ',WidthDiff,',',HeightDiff]);
    {$ENDIF}
    ChildMaxSize:=Point(Site.ClientWidth-DockMaster.SplitterWidth,
                        Site.ClientHeight-DockMaster.SplitterWidth);
    if PreferredSiteSizeAsSiteMinimum then begin
      SiteMinSize:=GetSitePreferredClientSize;
      if Child.Align in [alLeft,alRight] then begin
        ChildMaxSize.X:=Max(0,(ChildMaxSize.X-SiteMinSize.X));
      end else begin
        ChildMaxSize.Y:=Max(0,(ChildMaxSize.Y-SiteMinSize.Y));
      end;
      {$IF defined(VerboseAnchorDockRestore) or defined(VerboseADCustomSite)}
      debugln(['TAnchorDockManager.ResetBounds ChildMaxSize=',dbgs(ChildMaxSize),' SiteMinSize=',dbgs(SiteMinSize),' Site.Client=',dbgs(Site.ClientRect)]);
      {$ENDIF}
    end;

    case ResizePolicy of
    admrpChild:
      begin
        if Child.Parent is TAnchorDockPanel then
          //
        else begin
          if Child.Align in [alLeft,alRight] then
            Child.Width:=Max(1,Min(ChildMaxSize.X,Child.Width+WidthDiff))
          else begin
            i:=Max(1,Min(ChildMaxSize.Y,Child.Height+HeightDiff));
            {$IFDEF VerboseAnchorDockRestore}
            debugln(['TAnchorDockManager.ResetBounds Child=',DbgSName(Child),' OldHeight=',Child.Height,' NewHeight=',i]);
            {$ENDIF}
            Child.Height:=i;
          end;
        end;
      end;
    end;
  end;

begin
  if Force then ;

  //debugln(['TAnchorDockManager.ResetBounds Site="',Site.Caption,'" Force=',Force,' ',dbgs(Site.ClientRect)]);
  OldSiteClientRect:=FSiteClientRect;
  FSiteClientRect:=Site.ClientRect;
  WidthDiff:=FSiteClientRect.Right-OldSiteClientRect.Right;
  HeightDiff:=FSiteClientRect.Bottom-OldSiteClientRect.Bottom;
  ClientRectChanged:=(WidthDiff<>0) or (HeightDiff<>0);
  if ClientRectChanged or PreferredSiteSizeAsSiteMinimum then
    AlignChilds;
  if ClientRectChanged then
    if DockMaster.FOverlappingForm<>nil then
      DockMaster.HideOverlappingForm(nil);
end;

procedure TAnchorDockManager.SaveToStream(Stream: TStream);
begin
  if Stream=nil then ;
  debugln(['TAnchorDockManager.SaveToStream not implemented Site="',DbgSName(Site),'"']);
end;

function TAnchorDockManager.GetDockEdge(ADockObject: TDragDockObject): boolean;
var
  BestDistance: Integer;

  procedure FindMinDistance(CurAlign: TAlign; CurDistance: integer);
  begin
    if CurDistance<0 then
      CurDistance:=-CurDistance;
    if CurDistance>=BestDistance then exit;
    ADockObject.DropAlign:=CurAlign;
    BestDistance:=CurDistance;
  end;

var
  p: TPoint;
  LastTabRect: TRect;
  TabIndex: longint;
begin
  //debugln(['TAnchorDockManager.GetDockEdge ',DbgSName(Site),' ',DbgSName(DockSite),' DockableSites=',dbgs(DockableSites)]);
  if DockableSites=[] then begin
    ADockObject.DropAlign:=alNone;
    exit(false);
  end;

  p:=Site.ScreenToClient(ADockObject.DragPos);
  //debugln(['TAnchorDockManager.GetDockEdge ',dbgs(p),' ',dbgs(Site.BoundsRect),' ',DbgSName(Site)]);
  if (DockSite<>nil) and (DockSite.Pages<>nil) then begin
    // page docking
    ADockObject.DropAlign:=alClient;
    p:=DockSite.Pages.ScreenToClient(ADockObject.DragPos);
    LastTabRect:=DockSite.Pages.TabRect(DockSite.Pages.PageCount-1);
    if (p.Y>=LastTabRect.Top) and (p.y<LastTabRect.Bottom) then begin
      // specific tab
      if p.X>=LastTabRect.Right then begin
        // insert as last
        ADockObject.DropOnControl:=DockSite.Pages;
      end else begin
        TabIndex:=DockSite.Pages.IndexOfPageAt(p);
        if TabIndex>=0 then begin
          // insert in front of an existing
          ADockObject.DropOnControl:=DockSite.Pages.Page[TabIndex];
        end;
      end;
    end;
  end else if (DockSite<>nil) and PtInRect(DockSite.GetPageArea,p) then begin
    // page docking
    ADockObject.DropAlign:=alClient;
  end else begin

    // check side
    BestDistance:=High(Integer);
    if akLeft in DockableSites then FindMinDistance(alLeft,p.X);
    if akRight in DockableSites then FindMinDistance(alRight,Site.ClientWidth-p.X);
    if akTop in DockableSites then FindMinDistance(alTop,p.Y);
    if akBottom in DockableSites then FindMinDistance(alBottom,Site.ClientHeight-p.Y);

    // check inside
    if InsideDockingAllowed
    and ( ((ADockObject.DropAlign=alLeft) and (p.X>=0))
       or ((ADockObject.DropAlign=alTop) and (p.Y>=0))
       or ((ADockObject.DropAlign=alRight) and (p.X<Site.ClientWidth))
       or ((ADockObject.DropAlign=alBottom) and (p.Y<Site.ClientHeight)) )
    then
      ADockObject.DropOnControl:=Site
    else
      ADockObject.DropOnControl:=nil;
    if Site is TAnchorDockHostSite then begin
      ADockObject.DropAlign:=AcceptAlign(Site as TAnchorDockHostSite,ADockObject.DropAlign);
      if ADockObject.DropAlign=alNone then
        exit(false);
    end;
  end;
  //debugln(['TAnchorDockManager.GetDockEdge ADockObject.DropAlign=',dbgs(ADockObject.DropAlign),' DropOnControl=',DbgSName(ADockObject.DropOnControl)]);
  Result:=true;
end;

procedure TAnchorDockManager.RestoreSite(SplitterPos: integer);
var
  ChildSite: TAnchorDockHostSite;
begin
  FSiteClientRect:=Site.ClientRect;
  if DockSite<>nil then exit;
  ChildSite:=GetChildSite;
  {$IFDEF VerboseAnchorDockRestore}
  debugln(['TAnchorDockManager.RestoreSite START ',DbgSName(Site),' ChildSite=',DbgSName(ChildSite)]);
  {$ENDIF}
  if ChildSite<>nil then begin
    ChildSite.CreateBoundSplitter;
    ChildSite.PositionBoundSplitter;
    if ChildSite.Align in [alLeft,alRight] then
      ChildSite.BoundSplitter.Left:=SplitterPos
    else
      ChildSite.BoundSplitter.Top:=SplitterPos;
    case ChildSite.Align of
    alTop: ChildSite.Height:=ChildSite.BoundSplitter.Top;
    alBottom: ChildSite.Height:=Site.ClientHeight
                  -(ChildSite.BoundSplitter.Top+ChildSite.BoundSplitter.Height);
    alLeft: ChildSite.Width:=ChildSite.BoundSplitter.Left;
    alRight: ChildSite.Width:=Site.ClientWidth
                  -(ChildSite.BoundSplitter.Left+ChildSite.BoundSplitter.Width);
    end;
    // only allow to dock one control
    DragManager.RegisterDockSite(Site,false);
    {$IFDEF VerboseAnchorDockRestore}
    debugln(['TAnchorDockManager.RestoreSite ',DbgSName(Site),' ChildSite=',DbgSName(ChildSite),' Site.Bounds=',dbgs(Site.BoundsRect),' Site.Client=',dbgs(Site.ClientRect),' ChildSite.Bounds=',dbgs(ChildSite.BoundsRect),' Splitter.Bounds=',dbgs(ChildSite.BoundSplitter.BoundsRect)]);
    {$ENDIF}
  end;
end;

procedure TAnchorDockManager.StoreConstraints;
begin
  with Site.Constraints do
    FStoredConstraints:=Rect(MinWidth,MinHeight,MaxWidth,MaxHeight);
end;

function TAnchorDockManager.GetSitePreferredClientSize: TPoint;
{ Compute the preferred inner size of Site without the ChildSite and without
  the splitter
}
var
  ChildSite: TAnchorDockHostSite;
  Splitter: TAnchorDockSplitter;
  SplitterSize: TPoint;
  i: Integer;
  ChildControl: TControl;
  PrefWidth: Integer;
  PrefHeight: Integer;
  SplitterAnchor: TAnchorKind; // side where a child is anchored to the splitter
  ChildPrefWidth: integer;
  ChildPrefHeight: integer;
  ChildBottom: Integer;
  ChildRight: Integer;
begin
  Result:=Point(0,0);
  Site.GetPreferredSize(Result.X,Result.Y);
  // compute the bounds without the Splitter and ChildSite
  ChildSite:=GetChildSite;
  if ChildSite=nil then exit;
  Splitter:=ChildSite.BoundSplitter;
  if Splitter=nil then exit;
  SplitterSize:=Point(0,0);
  Splitter.GetPreferredSize(SplitterSize.X,SplitterSize.Y);
  PrefWidth:=0;
  PrefHeight:=0;
  if ChildSite.Align in [alLeft,alRight] then
    PrefHeight:=Result.Y
  else
    PrefWidth:=Result.X;
  SplitterAnchor:=MainAlignAnchor[ChildSite.Align];
  for i:=0 to Site.ControlCount-1 do begin
    ChildControl:=Site.Controls[i];
    if (ChildControl=Splitter) or (ChildControl=ChildSite) then continue;
    if (ChildControl.AnchorSide[SplitterAnchor].Control=Splitter)
    or ((ChildControl.Align in [alLeft,alTop,alRight,alBottom,alClient])
      and (SplitterAnchor in AnchorAlign[ChildControl.Align]))
    then begin
      // this control could be resized by the splitter
      // => use its position and preferred size for a preferred size of the ChildSite
      ChildPrefWidth:=0;
      ChildPrefHeight:=0;
      ChildControl.GetPreferredSize(ChildPrefWidth,ChildPrefHeight);
      //debugln(['  ChildControl=',DbgSName(ChildControl),' ',ChildPrefWidth,',',ChildPrefHeight]);
      case ChildSite.Align of
      alTop:
        begin
          ChildBottom:=ChildControl.Top+ChildControl.Height;
          PrefHeight:=Max(PrefHeight,Site.ClientHeight-ChildBottom-ChildPrefHeight);
        end;
      alBottom:
        PrefHeight:=Max(PrefHeight,ChildControl.Top+ChildPrefHeight);
      alLeft:
        begin
          ChildRight:=ChildControl.Left+ChildControl.Width;
          PrefWidth:=Max(PrefWidth,Site.ClientWidth-ChildRight-ChildPrefWidth);
        end;
      alRight:
        PrefWidth:=Max(PrefWidth,ChildControl.Left+ChildPrefWidth);
      end;
    end;
  end;
  {$IFDEF VerboseADCustomSite}
  debugln(['TAnchorDockManager.GetSitePreferredClientSize DefaultSitePref=',dbgs(Result),' Splitter.Align=',dbgs(Splitter.Align),' ChildSite.Align=',dbgs(ChildSite.Align),' NewPref=',PrefWidth,',',PrefHeight]);
  {$ENDIF}
  Result.X:=PrefWidth;
  Result.Y:=PrefHeight;
end;

function TAnchorDockManager.GetChildSite: TAnchorDockHostSite;
var
  i: Integer;
begin
  for i:=0 to Site.ControlCount-1 do
    if Site.Controls[i] is TAnchorDockHostSite then begin
      Result:=TAnchorDockHostSite(Site.Controls[i]);
      exit;
    end;
  Result:=nil;
end;

function TAnchorDockManager.StoredConstraintsValid: boolean;
begin
  with FStoredConstraints do
    Result:=(Left<>0) or (Top<>0) or (Right<>0) or (Bottom<>0);
end;

function TAnchorDockManager.IsEnabledControl(Control: TControl):Boolean;
begin
  Result := (DockMaster <> nil) and DockMaster.IsSite(Control);
end;

{ TAnchorDockSplitter }

procedure TAnchorDockSplitter.SetResizeAnchor(const AValue: TAnchorKind);
begin
  inherited SetResizeAnchor(AValue);

  case ResizeAnchor of
  akLeft: Anchors:=AnchorAlign[alLeft];
  akTop: Anchors:=AnchorAlign[alTop];
  akRight: Anchors:=AnchorAlign[alRight];
  akBottom: Anchors:=AnchorAlign[alBottom];
  end;

  UpdatePercentPosition;

  //debugln(['TAnchorDockSplitter.SetResizeAnchor ',DbgSName(Self),' ResizeAnchor=',dbgs(ResizeAnchor),' Align=',dbgs(Align),' Anchors=',dbgs(Anchors)]);
end;

procedure TAnchorDockSplitter.SetParent(NewParent: TWinControl);
begin
  if NewParent=nil then
    AsyncUpdateDockBounds:=false;
  inherited SetParent(NewParent);
end;

procedure TAnchorDockSplitter.PopupMenuPopup(Sender: TObject);
begin

end;

procedure TAnchorDockSplitter.OnAsyncUpdateDockBounds (Data: PtrInt);
begin
  FAsyncUpdateDockBounds:=false;
  FPercentPosition:=-1;
  UpdateDockBounds;
end;

procedure TAnchorDockSplitter.UpdateDockBounds;
begin
  if csDestroying in ComponentState then exit;
  FDockBounds:=BoundsRect;
  if Parent<>nil then begin
    FDockParentClientSize.cx:=Parent.ClientWidth;
    FDockParentClientSize.cy:=Parent.ClientHeight;
  end else begin
    FDockParentClientSize.cx:=0;
    FDockParentClientSize.cy:=0;
  end;
  if FPercentPosition < 0 then
    UpdatePercentPosition;
end;

procedure TAnchorDockSplitter.UpdatePercentPosition;
begin
  case ResizeAnchor of
    akTop, akBottom:
      if FDockParentClientSize.cy > 0 then
        FPercentPosition := Top / FDockParentClientSize.cy
      else
        FPercentPosition := -1;
  else
    if FDockParentClientSize.cx > 0 then
      FPercentPosition := Left / FDockParentClientSize.cx
    else
      FPercentPosition := -1;
  end;
end;

procedure TAnchorDockSplitter.SetAsyncUpdateDockBounds(const AValue: boolean);
begin
  if FAsyncUpdateDockBounds=AValue then Exit;
  FAsyncUpdateDockBounds:=AValue;
  if FAsyncUpdateDockBounds then
    Application.QueueAsyncCall(@OnAsyncUpdateDockBounds,0)
  else
    Application.RemoveAsyncCalls(Self);
end;

procedure TAnchorDockSplitter.SetBounds(ALeft, ATop, AWidth, AHeight: integer);
begin
  DisableAutoSizing{$IFDEF DebugDisableAutoSizing}('TAnchorDockSplitter.SetBounds'){$ENDIF};
  try
    inherited SetBounds(ALeft, ATop, AWidth, AHeight);
    UpdateDockBounds;
  finally
    EnableAutoSizing{$IFDEF DebugDisableAutoSizing}('TAnchorDockSplitter.SetBounds'){$ENDIF};
  end;
end;

procedure TAnchorDockSplitter.SetBoundsKeepDockBounds(ALeft, ATop, AWidth, AHeight: integer);
begin
  inherited SetBounds(ALeft,ATop,AWidth,AHeight);
end;

procedure TAnchorDockSplitter.SetBoundsPercentually;
var
  NewLeft, NewTop: Integer;
  AControl: TControl;
  SplitterAnchorKind:TAnchorKind;
begin
  if Enabled then begin
    if ResizeAnchor in [akLeft,akRight] then
    begin
      if DockParentClientSize.cx > 0 then
      begin
        if (FPercentPosition > 0) or SameValue(FPercentPosition, 0) then
          NewLeft := Round(FPercentPosition*Parent.ClientWidth)
        else
          NewLeft := (DockBounds.Left*Parent.ClientWidth) div DockParentClientSize.cx;
        NewTop := Top;
        SetBoundsKeepDockBounds(NewLeft,NewTop,Width,Height);
      end;
    end else
    begin
      if DockParentClientSize.cy > 0 then
      begin
        NewLeft := Left;
        if (FPercentPosition > 0) or SameValue(FPercentPosition, 0) then
          NewTop := Round(FPercentPosition*Parent.ClientHeight)
        else
          NewTop := (DockBounds.Top*Parent.ClientHeight) div DockParentClientSize.cy;
        SetBoundsKeepDockBounds(NewLeft,NewTop,Width,Height);
      end;
    end;
    if FPercentPosition < 0 then
      UpdatePercentPosition;
  end else begin
    SplitterAnchorKind:=akTop;
    AControl:=CountAndReturnOnlyOneMinimizedAnchoredControls(self,SplitterAnchorKind);
    if AControl=nil then begin
      SplitterAnchorKind:=akRight;
      AControl:=CountAndReturnOnlyOneMinimizedAnchoredControls(self,SplitterAnchorKind);
    end;
    if AControl=nil then begin
      SplitterAnchorKind:=akBottom;
      AControl:=CountAndReturnOnlyOneMinimizedAnchoredControls(self,SplitterAnchorKind);
    end;
    if AControl=nil then begin
      SplitterAnchorKind:=akLeft;
      AControl:=CountAndReturnOnlyOneMinimizedAnchoredControls(self,SplitterAnchorKind);
    end;

    if AControl is TAnchorDockHostSite then begin
      (AControl as TAnchorDockHostSite).UpdateHeaderAlign;
      NewTop := (AControl as TAnchorDockHostSite).Header.Left;
      NewTop := (AControl as TAnchorDockHostSite).Header.Height;
      NewLeft := left;
      NewTop := top;
      (AControl as TAnchorDockHostSite).UpdateHeaderAlign;
      case SplitterAnchorKind of
        akTop: NewTop := AControl.Top+(AControl as TAnchorDockHostSite).Header.Height;
        akBottom: NewTop := AControl.Top+AControl.Height-(AControl as TAnchorDockHostSite).Header.Height-Height;
        akLeft: NewLeft := AControl.Left+(AControl as TAnchorDockHostSite).Header.Width;
        akRight: NewLeft := AControl.Left+AControl.Width-(AControl as TAnchorDockHostSite).Header.Width-Width;
      end;
      SetBoundsKeepDockBounds(NewLeft,NewTop,Width,Height);
    end;
  end;
end;

function TAnchorDockSplitter.SideAnchoredControlCount(Side: TAnchorKind): integer;
var
  Sibling: TControl;
  i: Integer;
begin
  Result:=0;
  for i:=0 to AnchoredControlCount-1 do begin
    Sibling:=AnchoredControls[i];
    if Sibling.AnchorSide[OppositeAnchor[Side]].Control=Self then
      inc(Result);
  end;
end;

function TAnchorDockSplitter.HasAnchoredControls: boolean;
// returns true if this splitter has at least one non splitter control anchored to it
var
  i: Integer;
  Sibling: TControl;
begin
  Result:=false;
  for i:=0 to AnchoredControlCount-1 do begin
    Sibling:=AnchoredControls[i];
    if Sibling is TAnchorDockSplitter then continue;
    exit(true);
  end;
end;

function TAnchorDockSplitter.GetSpliterBoundsWithUnminimizedDockSites:TRect;
var
  NewLeft, NewTop: Integer;
begin
  if ResizeAnchor in [akLeft,akRight] then
  begin
    if DockParentClientSize.cx > 0 then
    begin
      if (FPercentPosition > 0) or SameValue(FPercentPosition, 0) then
        NewLeft := Round(FPercentPosition*Parent.ClientWidth)
      else
        NewLeft := (DockBounds.Left*Parent.ClientWidth) div DockParentClientSize.cx;
      NewTop := Top;
    end;
  end else
  begin
    if DockParentClientSize.cy > 0 then
    begin
      NewLeft := Left;
      if (FPercentPosition > 0) or SameValue(FPercentPosition, 0) then
        NewTop := Round(FPercentPosition*Parent.ClientHeight)
      else
        NewTop := (DockBounds.Top*Parent.ClientHeight) div DockParentClientSize.cy;
    end;
  end;
  result:=Rect(NewLeft,NewTop,NewLeft+Width,NewTop+Height);
end;

procedure TAnchorDockSplitter.SaveLayout(
  LayoutNode: TAnchorDockLayoutTreeNode);
begin
  if ResizeAnchor in [akLeft,akRight] then
    LayoutNode.NodeType:=adltnSplitterVertical
  else
    LayoutNode.NodeType:=adltnSplitterHorizontal;
  LayoutNode.Assign(Self,false,false);
  if not Enabled then
    LayoutNode.BoundsRect:=GetSpliterBoundsWithUnminimizedDockSites;
  LayoutNode.PixelsPerInch:=Screen.PixelsPerInch;
end;

function TAnchorDockSplitter.HasOnlyOneSibling(Side: TAnchorKind; MinPos,
  MaxPos: integer): TControl;
var
  i: Integer;
  AControl: TControl;
begin
  Result:=nil;
  for i:=0 to AnchoredControlCount-1 do begin
    AControl:=AnchoredControls[i];
    if AControl.AnchorSide[OppositeAnchor[Side]].Control<>Self then continue;
    // AControl is anchored at Side to this splitter
    if (Side in [akLeft,akRight]) then begin
      if (AControl.Left>MaxPos) or (AControl.Left+AControl.Width<MinPos) then
        continue;
    end else begin
      if (AControl.Top>MaxPos) or (AControl.Top+AControl.Height<MinPos) then
        continue;
    end;
    // AControl is in range
    if Result=nil then
      Result:=AControl
    else begin
      // there is more than one control
      Result:=nil;
      exit;
    end;
  end;
end;

procedure TAnchorDockSplitter.MoveSplitter(Offset: integer);
begin
  FPercentPosition:=-1;
  inherited MoveSplitter(Offset);
  UpdatePercentPosition;
end;

procedure TAnchorDockSplitter.Paint;
begin
  if Enabled then
    inherited Paint
  else
  begin
    Canvas.Brush.Color := clDefault;
    Canvas.FillRect(ClientRect);
  end;
end;

constructor TAnchorDockSplitter.Create(TheOwner: TComponent);
begin
  inherited Create(TheOwner);
  Align:=alNone;
  ResizeAnchor:=akLeft;
  // make sure the splitter never vanish
  Constraints.MinWidth:=2;
  Constraints.MinHeight:=2;
  PopupMenu:=DockMaster.GetPopupMenu;
  FPercentPosition:=-1;
end;

destructor TAnchorDockSplitter.Destroy;
begin
  AsyncUpdateDockBounds:=false;
  inherited Destroy;
end;

{ TAnchorDockPageControl }

function TAnchorDockPageControl.GetDockPages(Index: integer): TAnchorDockPage;
begin
  Result:=TAnchorDockPage(Page[Index]);
end;

procedure TAnchorDockPageControl.MouseDown(Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
var
  ATabIndex: LongInt;
  APage: TCustomPage;
  Site: TAnchorDockHostSite;
begin
  inherited MouseDown(Button, Shift, X, Y);
  ATabIndex := IndexOfPageAt(X, Y);
  if (Button = mbLeft) and DockMaster.AllowDragging and (ATabIndex >= 0) and (DockMaster.FOverlappingForm=nil) then
  begin
    APage:=Page[ATabIndex];
    if (APage.ControlCount>0) and (APage.Controls[0] is TAnchorDockHostSite) then
    begin
      Site:=TAnchorDockHostSite(APage.Controls[0]);
      DragManager.DragStart(Site,false,DockMaster.DragTreshold);
    end;
  end;
  if (Button = mbRight) then
  begin
    //select on right click
    if ATabIndex>=0 then
      PageIndex:=ATabIndex;
  end;
end;

procedure TAnchorDockPageControl.PopupMenuPopup(Sender: TObject);
var
  ContainsMainForm: Boolean;
  s: String;
  TabPositionSection: TMenuItem;
  Item: TMenuItem;
  tp: TTabPosition;
begin
  // movement
  if PageIndex>0 then
    DockMaster.AddPopupMenuItem('MoveLeftMenuItem', adrsMovePageLeft,
                                              @MoveLeftButtonClick);
  if PageIndex>1 then
    DockMaster.AddPopupMenuItem('MoveLeftMostMenuItem', adrsMovePageLeftmost,
                                              @MoveLeftMostButtonClick);

  if PageIndex<PageCount-1 then
    DockMaster.AddPopupMenuItem('MoveRightMenuItem', adrsMovePageRight,
                                              @MoveRightButtonClick);
  if PageIndex<PageCount-2 then
    DockMaster.AddPopupMenuItem('MoveRightMostMenuItem', adrsMovePageRightmost,
                                              @MoveRightMostButtonClick);

  // tab position
  TabPositionSection:=DockMaster.AddPopupMenuItem('TabPositionMenuItem',
                                                  adrsTabPosition,nil);
  for tp:=Low(TTabPosition) to high(TTabPosition) do begin
    case tp of
    tpTop: s:=adrsTop;
    tpBottom: s:=adrsBottom;
    tpLeft: s:=adrsLeft;
    tpRight: s:=adrsRight;
    end;
    Item:=DockMaster.AddPopupMenuItem('TabPos'+ADLTabPostionNames[tp]+'MenuItem',
                              s,@TabPositionClick,TabPositionSection);
    Item.ShowAlwaysCheckable:=true;
    Item.Checked:=TabPosition=tp;
    Item.Tag:=ord(tp);
  end;

  // close
  ContainsMainForm:=IsParentOf(Application.MainForm);
  if ContainsMainForm then
    s:=Format(adrsQuit, [Application.Title])
  else
    s:=adrsClose;
  DockMaster.AddPopupMenuItem('CloseMenuItem',s,@CloseButtonClick);
end;

procedure TAnchorDockPageControl.CloseButtonClick(Sender: TObject);
var
  Site: TAnchorDockHostSite;
begin
  Site:=GetActiveSite;
  if Site=nil then exit;
  DockMaster.RestoreLayouts.Add(DockMaster.CreateRestoreLayout(Site),true);
  Site.CloseSite;
  DockMaster.SimplifyPendingLayouts;
end;

procedure TAnchorDockPageControl.MoveLeftButtonClick(Sender: TObject);
begin
  if PageIndex>0 then
    Page[PageIndex].PageIndex:=Page[PageIndex].PageIndex-1;
end;

procedure TAnchorDockPageControl.MoveLeftMostButtonClick(Sender: TObject);
begin
  if PageIndex>0 then
    Page[PageIndex].PageIndex:=0;
end;

procedure TAnchorDockPageControl.MoveRightButtonClick(Sender: TObject);
begin
  if PageIndex<PageCount-1 then
    Page[PageIndex].PageIndex:=Page[PageIndex].PageIndex+1;
end;

procedure TAnchorDockPageControl.MoveRightMostButtonClick(Sender: TObject);
begin
  if PageIndex<PageCount-1 then
    Page[PageIndex].PageIndex:=PageCount-1;
end;

procedure TAnchorDockPageControl.TabPositionClick(Sender: TObject);
var
  Item: TMenuItem;
begin
  if not (Sender is TMenuItem) then exit;
  Item:=TMenuItem(Sender);
  TabPosition:=TTabPosition(Item.Tag);
end;

procedure TAnchorDockPageControl.UpdateDockCaption(Exclude: TControl);
begin
  if Exclude=nil then ;
end;

procedure TAnchorDockPageControl.RemoveControl(AControl: TControl);
begin
  inherited RemoveControl(AControl);
  if (not (csDestroying in ComponentState)) then begin
    if (PageCount<=1) and (Parent is TAnchorDockHostSite) then
      DockMaster.NeedSimplify(Parent);
  end;
end;

function TAnchorDockPageControl.GetActiveSite: TAnchorDockHostSite;
var
  CurPage: TCustomPage;
  CurDockPage: TAnchorDockPage;
begin
  Result:=nil;
  CurPage:=ActivePageComponent;
  if not (CurPage is TAnchorDockPage) then exit;
  CurDockPage:=TAnchorDockPage(CurPage);
  Result:=CurDockPage.GetSite;
end;

constructor TAnchorDockPageControl.Create(TheOwner: TComponent);
begin
  inherited Create(TheOwner);
  PopupMenu:=DockMaster.GetPopupMenu;
end;

function TAnchorDockPageControl.GetPageClass: TCustomPageClass;
begin
  Result:=DockMaster.PageClass;
end;

{ TAnchorDockOverlappingForm }

constructor TAnchorDockOverlappingForm.CreateNew(AOwner: TComponent; Num: Integer = 0);
begin
  inherited;
  BorderStyle:=bsNone;
  AnchorDockHostSite:=nil;
  Panel:=TPanel.Create(self);
  Panel.BorderStyle:=bsSingle;
  Panel.Align:=alClient;
  Panel.Parent:=self;
  Panel.Visible:=true;
end;

{ TAnchorDockPage }

procedure TAnchorDockPage.UpdateDockCaption(Exclude: TControl);
var
  i: Integer;
  Child: TControl;
  NewCaption: String;
begin
  NewCaption:='';
  for i:=0 to ControlCount-1 do begin
    Child:=Controls[i];
    if Child=Exclude then continue;
    if not (Child is TAnchorDockHostSite) then continue;
    if NewCaption<>'' then
      NewCaption:=NewCaption+',';
    NewCaption:=NewCaption+Child.Caption;
  end;
  //debugln(['TAnchorDockPage.UpdateDockCaption ',Caption,' ',NewCaption]);
  if Caption=NewCaption then exit;
  Caption:=NewCaption;
  if Parent is TAnchorDockPageControl then
    TAnchorDockPageControl(Parent).UpdateDockCaption;
end;

procedure TAnchorDockPage.InsertControl(AControl: TControl; Index: integer);
begin
  inherited InsertControl(AControl, Index);
  //debugln(['TAnchorDockPage.InsertControl ',DbgSName(AControl)]);
  if AControl is TAnchorDockHostSite then begin
    if TAnchorDockHostSite(AControl).Header<>nil then
      TAnchorDockHostSite(AControl).Header.Parent:=nil;
    UpdateDockCaption;
  end;
end;

procedure TAnchorDockPage.RemoveControl(AControl: TControl);
begin
  inherited RemoveControl(AControl);
  if (GetSite=nil) and (not (csDestroying in ComponentState))
  and (Parent<>nil) and (not (csDestroying in Parent.ComponentState)) then
    DockMaster.NeedSimplify(Self);
end;

function TAnchorDockPage.GetSite: TAnchorDockHostSite;
begin
  Result:=nil;
  if ControlCount=0 then exit;
  if not (Controls[0] is TAnchorDockHostSite) then exit;
  Result:=TAnchorDockHostSite(Controls[0]);
end;

procedure DrawFrame3DHeader(Canvas: TCanvas; {%H-}Style: TADHeaderStyleDesc; r: TRect;
  {%H-}Horizontal: boolean; {%H-}Focused: boolean);
begin
  Canvas.Frame3d(r,2,bvLowered);
  Canvas.Frame3d(r,4,bvRaised);
end;

procedure DrawFrameLine(Canvas: TCanvas; {%H-}Style: TADHeaderStyleDesc; r: TRect;
  Horizontal: boolean; {%H-}Focused: boolean);
var
  Center:integer;
begin
  if Horizontal then
  begin
    Center:=r.Top+(r.Bottom-r.Top) div 2;
    Canvas.Pen.Color:=clltgray;
    Canvas.Line(r.Left+5,Center-1,r.Right-3,Center-1);
    Canvas.Pen.Color:=clgray;
    Canvas.Line(r.Left+5,Center,r.Right-3,Center);
  end else
  begin
    Center:=r.Right+(r.Left-r.Right) div 2;
    Canvas.Pen.Color:=clltgray;
    Canvas.Line(Center-1,r.Top+3,Center-1,r.Bottom-5);
    Canvas.Pen.Color:=clgray;
    Canvas.Line(Center,r.Top+3,Center,r.Bottom-5);
  end;
end;

procedure DrawFrameLines(Canvas: TCanvas; {%H-}Style: TADHeaderStyleDesc; r: TRect;
  Horizontal: boolean; {%H-}Focused: boolean);
var
  lx,ly:integer;
begin
  InflateRect(r,-2,-2);
  if Horizontal then
  begin
    lx:=0;
    ly:=3;
    r.Bottom:=r.top+(r.bottom-r.Top) div 3;
    r.top:=r.bottom-ly;
  end else
  begin
    lx:=3;
    ly:=0;
    r.Right:=r.Left+(r.Right-r.Left) div 3 ;
    r.Left:=r.Right-lx;
  end;
  DrawEdge(Canvas.Handle,r, BDR_RAISEDINNER, BF_RECT );
  OffsetRect(r,lx,ly);
  DrawEdge(Canvas.Handle,r, BDR_RAISEDINNER, BF_RECT );
  OffsetRect(r,lx,ly);
  DrawEdge(Canvas.Handle,r, BDR_RAISEDINNER, BF_RECT );
end;

procedure DrawFramePoints(Canvas: TCanvas; {%H-}Style: TADHeaderStyleDesc; r: TRect;
  Horizontal: boolean; {%H-}Focused: boolean);
var
  lx,ly,d,lt,lb,lm:integer;
begin
  if Horizontal then begin
    lx := r.left+2;
    d := (r.Bottom - r.Top - 5) div 2;
    lt := r.Top + d;
    lb := lt + 4;
    lm := lt + 2;
    while lx < r.Right do
    begin
      Canvas.Pixels[lx, lt] := clBtnShadow;
      Canvas.Pixels[lx, lb] := clBtnShadow;
      Canvas.Pixels[lx+2, lm] := clBtnShadow;
      lx := lx + 4;
    end;
  end else begin
    ly := r.Bottom - 2;
    d := (r.Right - r.Left - 5) div 2;
    lt := r.Left + d;
    lb := lt + 4;
    lm := lt + 2;
    while ly > r.Top do
    begin
      Canvas.Pixels[lt, ly] := clBtnShadow;
      Canvas.Pixels[lb, ly] := clBtnShadow;
      Canvas.Pixels[lm, ly-2] := clBtnShadow;
      ly := ly - 4;
    end;
  end;
end;

procedure DrawFrameThemedCaption(Canvas: TCanvas; {%H-}Style: TADHeaderStyleDesc; r: TRect;
  {%H-}Horizontal: boolean; Focused: boolean);
var
  ted:TThemedElementDetails;
begin
  if Focused then
    ted:=ThemeServices.GetElementDetails(twSmallCaptionActive)
  else
    ted:=ThemeServices.GetElementDetails(twSmallCaptionInactive);
  r.Bottom:=r.Bottom-3;
  ThemeServices.DrawElement(Canvas.Handle,ted, r);
  if Focused then
    ted:=ThemeServices.GetElementDetails(twSmallFrameBottomActive)
  else
    ted:=ThemeServices.GetElementDetails(twSmallFrameBottomInactive);
  r.Top:=r.Bottom;
  r.Bottom:=r.Bottom+3;
  ThemeServices.DrawElement(Canvas.Handle,ted, r);
end;

procedure DrawFrameThemedButton(Canvas: TCanvas; {%H-}Style: TADHeaderStyleDesc; r: TRect;
  {%H-}Horizontal: boolean; Focused: boolean);
var
  ted:TThemedElementDetails;
begin
  if Focused then
    ted:=ThemeServices.GetElementDetails(tbPushButtonHot)
  else
    ted:=ThemeServices.GetElementDetails(tbPushButtonNormal);
  ThemeServices.DrawElement(Canvas.Handle,ted, r);
end;

initialization
  DockMaster:=TAnchorDockMaster.Create(nil);
  DockMaster.RegisterHeaderStyle('Frame3D', @DrawFrame3DHeader, true, true);
  DockMaster.RegisterHeaderStyle('Line', @DrawFrameLine, true, true);
  DockMaster.RegisterHeaderStyle('Lines', @DrawFrameLines, true, true);
  DockMaster.RegisterHeaderStyle('Points', @DrawFramePoints, true, true);
  DockMaster.RegisterHeaderStyle('ThemedCaption', @DrawFrameThemedCaption, false, false);
  DockMaster.RegisterHeaderStyle('ThemedButton', @DrawFrameThemedButton, false, false);
  DockTimer:=TTimer.Create(nil);

finalization
  FreeAndNil(DockMaster);
  FreeAndNil(DockTimer);

end.


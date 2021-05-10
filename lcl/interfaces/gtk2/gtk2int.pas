{
 /***************************************************************************
                       gtk2int.pas  -  GTK2 Interface Object
                       -------------------------------------


 ***************************************************************************/

 *****************************************************************************
  This file is part of the Lazarus Component Library (LCL)

  See the file COPYING.modifiedLGPL.txt, included in this distribution,
  for details about the license.
 *****************************************************************************
 }

unit Gtk2Int;

{$mode objfpc}{$H+}

interface

{$ifdef Trace}
{$ASSERTIONS ON}
{$endif}

{$I gtk2defines.inc}

uses
  // RTL
  {$ifdef Unix}
  BaseUnix, Unix,
  {$endif}
  Types, Classes, SysUtils, Math,
  {$IfNDef GTK2_2}
    {$IfDef HasX}
     XLib, xatom, X, gdk2x,
    {$EndIf}
  {$EndIf}
  gdk2pixbuf, gtk2, gdk2, glib2, Pango,
  // LCL
  LMessages, LCLProc, LCLIntf, LCLType, Dialogs, Controls, Forms, LCLStrConsts,
  Graphics, Menus, Themes, Buttons, StdCtrls, CheckLst, ComCtrls, ExtCtrls,
  LCLPlatformDef, InterfaceBase,
  WSLCLClasses, WSControls,
  Gtk2WinApiWindow, Gtk2Globals, Gtk2Proc, Gtk2Def, Gtk2FontCache, Gtk2Extra, Gtk2MsgQueue,
  // LazUtils
  GraphType, GraphMath, LazFileUtils, LazUTF8, DynHashArray, Maps, IntegerList,
  LazLoggerBase, LazTracer, LazUtilities, LazStringUtils;

type

{$IFDEF HASX}
  { TDummyWidget }

  TDummyWidget = class(TObject) {needed for accurate frame on x11}
  private
    FFrameRect: TRect;
    FFirstPaintEvent: boolean;
    FWidget: PGtkWidget;
  public
    constructor Create; overload;
    destructor Destroy; override;
    function GetWidgetFrame: TRect;
    function ShowDummyWidget(const ALeft, ATop, AWidth, AHeight: integer): boolean;
    procedure SendToBack;
    procedure HideWidget;
    property Widget: PGtkWidget read FWidget write FWidget;
  end;
{$ENDIF}

  { TGtk2WidgetSet }

  TGtk2WidgetSet = class(TWidgetSet)
  private
    {$IFNDEF USE_GTK_MAIN_OLD_ITERATION}
    FMainPoll: PGPollFD;
    {$ENDIF}
    FIsLibraryInstance: Boolean;
    FGtkTerminated: Boolean;
    FMultiThreadingEnabled: boolean;
    FocusTimer: cardinal;
    FLastFocusIn: PGtkWidget;
    FLastFocusOut: PGtkWidget;
    StayOnTopList: TMap;
    FAppActive: Boolean;
    FCachedTitleBarHeight: Integer;
    FCachedBorderSize: Integer;
    function GetAppActive: Boolean;
    function GetTitleBarHeight: Integer;
    procedure SetAppActive(const AValue: Boolean);
  protected
    function CreateThemeServices: TThemeServices; override;
  protected
    FKeyStateList_: TFPList; // Keeps track of which keys are pressed
    FDeviceContexts: TDynHashArray;// hasharray of HDC
    FGDIObjects: TDynHashArray;    // hasharray of PGdiObject
    FMessageQueue: TGtkMessageQueue; // queue of PMsg (must be thread safe!)
    WaitingForMessages: boolean;
    MovedPaintMessageCount: integer;// how many paint messages moved to the end of the queue

    FRCFilename: string;
    FRCFileParsed: boolean;
    FRCFileAge: integer;
    FGTKToolTips: PGtkToolTips;

    FLogHandlerID: guint; // ID returend by set_handler

    FStockNullBrush: HBRUSH;
    FStockBlackBrush: HBRUSH;
    FStockLtGrayBrush: HBRUSH;
    FStockGrayBrush: HBRUSH;
    FStockDkGrayBrush: HBRUSH;
    FStockWhiteBrush: HBRUSH;

    FStockNullPen: HPEN;
    FStockBlackPen: HPEN;
    FStockWhitePen: HPEN;

    FSysColorBrushes: array[0..MAX_SYS_COLORS] of HBrush;

    FWaitHandles: PWaitHandleEventHandler;
    {$ifdef unix}
    FChildSignalHandlers: PChildSignalEventHandler;
    {$else}
    {$IFDEF VerboseGtkToDos}{$warning no declaration of FChildSignalHandlers for this OS}{$ENDIF}
    {$endif}

    FDefaultFontDesc: PPangoFontDescription;
    FDefaultFont: TGtkIntfFont;
    FStockSystemFont: HFONT;
    FExtUTF8OutCache: Pointer;
    FExtUTF8OutCacheSize: integer;
    FGlobalCursor: HCursor;

    FDCManager: TDeviceContextMemManager;
    FDockImage: PGtkWidget;
    FDragImageList: PGtkWidget;
    FDragImageListIcon: PGtkWidget;
    FDragHotStop: TPoint;
  public
    procedure InitStockItems;
    procedure FreeStockItems;
    procedure InitSystemColors;
    procedure InitSystemBrushes;
    procedure FreeSystemBrushes;
    procedure PassCmdLineOptions; override;

    {$ifdef Unix}
    procedure InitSynchronizeSupport;
    procedure ProcessChildSignal;
    procedure PrepareSynchronize({%H-}AObject: TObject);
    {$endif}

    procedure HandlePipeEvent(AData: PtrInt; AFlags: dword);

    // styles
    procedure FreeAllStyles;
    function GetCompStyle(Sender : TObject) : Longint;

    // create and destroy
    function CreateAPIWidget(AWinControl: TWinControl): PGtkWidget;
    function CreateSimpleClientAreaWidget(Sender: TObject;
      NotOnParentsClientArea: boolean): PGtkWidget;
    procedure DestroyEmptySubmenu(Sender: TObject);
    procedure DestroyConnectedWidget(Widget: PGtkWidget;
                                     CheckIfDestroying: boolean);
    // clipboard
    procedure SetClipboardWidget(TargetWidget: PGtkWidget);

    // device contexts
    function IsValidDC(const DC: HDC): Boolean;
    function NewDC: TGtkDeviceContext;
    function FindDCWithGDIObject(GDIObject: PGdiObject): TGtkDeviceContext;
    procedure DisposeDC(aDC: TGtkDeviceContext);
    function CreateDCForWidget(AWidget: PGtkWidget; AWindow: PGdkWindow;
                               AWithChildWindows: Boolean; ADoubleBuffer: PgdkDrawable = nil): HDC;

    // GDIObjects
    function IsValidGDIObject(const AGDIObj: HGDIOBJ): Boolean;
    function IsValidGDIObjectType(const GDIObject: HGDIOBJ;
                                  const GDIType: TGDIType): Boolean;
    function NewGDIObject(const GDIType: TGDIType): PGdiObject;
    procedure DisposeGDIObject(GdiObject: PGdiObject);
    function ReleaseGDIObject(GdiObject: PGdiObject): boolean;
    procedure ReferenceGDIObject(GdiObject: PGdiObject);
    function CreateDefaultBrush: PGdiObject;
    function CreateDefaultFont: PGdiObject;
    function CreateDefaultPen: PGdiObject;
    function CreateDefaultGDIBitmap: PGdiObject;
    procedure UpdateDCTextMetric(DC: TGtkDeviceContext);
    function GetDefaultFontDesc(IncreaseReferenceCount: boolean): PPangoFontDescription;
    function GetDefaultGtkFont(IncreaseReferenceCount: boolean): TGtkIntfFont;
    function GetGtkFont(DC: TGtkDeviceContext): TGtkIntfFont;
    function CreateRegionCopy(SrcRGN: hRGN): hRGN; override;
    function DCClipRegionValid(DC: HDC): boolean; override;
    function CreateEmptyRegion: hRGN; override;

    // images
    procedure LoadPixbufFromLazResource(const ResourceName: string;
      var Pixbuf: PGdkPixbuf);
    function InternalGetDIBits(DC: HDC; Bitmap: HBitmap; StartScan, NumScans: UINT;
      BitSize : Longint; Bits: Pointer; out BitInfo: BitmapInfo; Usage: UINT; DIB : Boolean): Integer;
    function RawImage_DescriptionFromDrawable(out ADesc: TRawImageDescription; ADrawable: PGdkDrawable; ACustomAlpha: Boolean): boolean;
    function RawImage_DescriptionFromPixbuf(out ADesc: TRawImageDescription; APixbuf: PGdkPixbuf): boolean;
    function RawImage_FromDrawable(out ARawImage: TRawImage; ADrawable, AAlpha: PGdkDrawable; ARect: PRect = nil): boolean;
    function RawImage_FromPixbuf(out ARawImage: TRawImage; APixbuf: PGdkPixbuf; ARect: PRect = nil): boolean;
    function RawImage_SetAlpha(var ARawImage: TRawImage; AAlpha: PGdkPixmap; ARect: PRect = nil): boolean;
    function RawImage_AddMask(var ARawImage: TRawImage; AMask: PGdkBitmap; ARect: PRect = nil): boolean;
    function StretchCopyArea(DestDC: HDC; X, Y, Width, Height: Integer;
      SrcDC: HDC; XSrc, YSrc, SrcWidth, SrcHeight: Integer;
      Mask: HBITMAP; XMask, YMask: Integer;
      Rop: Cardinal): Boolean;

    // RC file
    procedure SetRCFilename(const AValue: string);
    procedure CheckRCFilename;
    procedure ParseRCFile;

    // forms and dialogs
    procedure BringFormToFront(Sender: TObject);
    procedure UntransientWindow(GtkWindow: PGtkWindow);
    // misc
    function GetCaption(Sender : TObject) : String;
    procedure WordWrap(DC: HDC; AText: PChar; MaxWidthInPixel: integer;
      out Lines: PPChar; out LineCount: integer);

    procedure ResizeChild(Sender : TObject; {%H-}Left,{%H-}Top,{%H-}Width,{%H-}Height : Integer);
    procedure RemoveCallbacks(Widget: PGtkWidget);

    // for gtk specific components:
    procedure SetWidgetColor(const AWidget: PGtkWidget;
                             const FGColor, BGColor: TColor;
                             const Mask: tGtkStateEnum);
    procedure SetCallbackDirect(const AMsg: LongInt; const AGTKObject: PGTKObject;
                          const ALCLObject: TObject);
    procedure SetCallback(const AMsg: LongInt; const AGTKObject: PGTKObject;
                          const ALCLObject: TObject);
    function  LCLtoGtkMessagePending: boolean;
    procedure SendCachedGtkMessages;
    // show, hide and invalidate
    procedure SetVisible(Sender: TObject; const AVisible: Boolean);

    // Drag ImageLsit
    function DragImageList_BeginDrag(APixmap: PGdkPixmap; AMask: PGdkBitmap; AHotSpot: TPoint): Boolean;
    procedure DragImageList_EndDrag;
    function DragImageList_DragMove(X, Y: Integer): Boolean;
    function DragImageList_SetVisible(NewVisible: Boolean): Boolean;

    procedure UpdateTransientWindows;
    procedure SendCachedLCLMessages; override;

    function CreateTimer(Interval: integer; TimerProc: TWSTimerProc) : THandle; override;
    function DestroyTimer(TimerHandle: THandle) : boolean; override;
    procedure DestroyLCLComponent(Sender: TObject);
    // notebook

    procedure DCSetAntialiasing(CanvasHandle: HDC; AEnabled: Boolean); override;
    function  DCGetPixel(CanvasHandle: HDC; X, Y: integer): TGraphicsColor; override;
    procedure DCSetPixel(CanvasHandle: HDC; X, Y: integer; AColor: TGraphicsColor); override;
    procedure DCRedraw(CanvasHandle: HDC); override;
    {used by 3rd party components eg. opengl implementation}
    procedure FinishCreateHandle(const AWinControl: TWinControl;
      Widget: PGtkWidget; const AParams: TCreateParams);

  private
    {$IFDEF HASX}
    FDesktopWidget: PGtkWidget;
    FWSFrameRect: TRect;
    {$ENDIF}
    procedure Gtk2Create;
    procedure Gtk2Destroy;

  protected
    function GetAppHandle: THandle; override;
  public
    constructor Create; override;
    destructor Destroy; override;

    function LCLPlatform: TLCLPlatform; override;
    function GetLCLCapability(ACapability: TLCLCapability): PtrUInt; override;

    procedure AppInit(var ScreenInfo: TScreenInfo); override;
    procedure AppBringToFront; override;
    procedure AppMinimize; override;
    procedure AppRestore; override;
    function AppRemoveStayOnTopFlags(const ASystemTopAlso: Boolean = False): Boolean; override;
    function AppRestoreStayOnTopFlags(const ASystemTopAlso: Boolean = False): Boolean; override;
    procedure AppProcessMessages; override;
    procedure AppWaitMessage; override;
    procedure AppTerminate; override;
    procedure AppSetTitle(const {%H-}ATitle: string); override;

    procedure _SetCallbackEx(const AMsg: LongInt; const AGTKObject: PGTKObject; const ALCLObject: TObject; Direct: Boolean);
    procedure SetCallbackEx(const AMsg: LongInt; const AGTKObject: PGTKObject; const ALCLObject: TObject; Direct: Boolean);
    procedure SetCommonCallbacks(const AGTKObject: PGTKObject; const ALCLObject: TObject);
    procedure SetLabelCaption(const ALabel: PGtkLabel; const ACaption: String);
    procedure SetSelectionMode(Sender: TObject; Widget: PGtkWidget;
      MultiSelect, {%H-}ExtendedSelect: Boolean);
    function ForceLineBreaks(DC : hDC; Src: PChar; MaxWidthInPixels : Longint;
                             ConvertAmpersandsToUnderScores: Boolean) : PChar;
    procedure SetWidgetFont(const AWidget: PGtkWidget; const AFont: TFont);
    {$I gtk2winapih.inc}
    {$I gtk2lclintfh.inc}
  public
    {$IFDEF HASX}
    function CreateDummyWidgetFrame(const ALeft, ATop, AWidth,
      AHeight: integer): boolean;
    function GetDummyWidgetFrame: TRect;

    function compositeManagerRunning: Boolean;
    function GetDesktopWidget: PGtkWidget;
    //function X11Raise(AHandle: HWND): boolean; currently not used
    function GetWindowManager: String;
    function IsCurrentDesktop(AWindow: PGdkWindow): Boolean;
    function X11GetActiveWindow: HWND;
    function GetAlwaysOnTopX11(AWindow: PGdkWindow): boolean;
    procedure HideAllHints;
    procedure RestoreAllHints;
    {$ENDIF}
    procedure StartFocusTimer;
    property AppActive: Boolean read GetAppActive write SetAppActive;
    property IsLibraryInstance: Boolean read FIsLibraryInstance;
    property GtkIsTerminated: Boolean read FGtkTerminated;
    property LastFocusIn: PGtkWidget read FLastFocusIn write FLastFocusIn;
    property LastFocusOut: PGtkWidget read FLastFocusOut write FLastFocusOut;
    property MultiThreadingEnabled: boolean read FMultiThreadingEnabled;
    property KeyStateList: TFPList read FKeyStateList_;
  end;

  {$I gtk2listslh.inc}

  { TGtkListStoreStringList }

  TGtkListStoreStringList = class(TStrings)
  private
    FChangeStamp: Integer;
    FColumnIndex: Integer;
    FGtkListStore: PGtkListStore;
    FOwner: TWinControl;
    FSorted: Boolean;
    FStates: TGtkListStringsStates;
    FCachedCount: Integer;
    FCachedCapacity: Integer;
    FCachedSize: Integer;
    FCachedItems: PGtkTreeIter;
    FUpdateCount: Integer;
  protected
    function GetCount: Integer; override;
    function Get(Index: Integer): String; override;
    function GetObject(Index: Integer): TObject; override;
    procedure Put(Index: Integer; const S: String); override;
    procedure PutObject(Index: Integer; AnObject: TObject); override;
    procedure SetSorted(Val: Boolean);
    procedure UpdateItemCache;
    procedure GrowCache;
    procedure ShrinkCache;
    procedure IncreaseChangeStamp;
  public
    constructor Create(AListStore: PGtkListStore;
                       ColumnIndex: Integer; AOwner: TWinControl);
    destructor Destroy; override;
    function Add(const S: String): Integer; override;
    procedure Assign(Source: TPersistent); override;
    procedure Clear; override;
    procedure Delete(Index: Integer); override;
    function Find(const S: String; out Index: Integer): Boolean;
    function IndexOf(const S: String): Integer; override;
    procedure Insert(Index: Integer; const S: String); override;
    procedure Move(CurIndex, NewIndex: Integer); override;
    procedure Sort;
    function IsEqual(List: TStrings): Boolean;
    procedure BeginUpdate;
    procedure EndUpdate;
  public
    property Sorted: Boolean read FSorted write SetSorted;
    property Owner: TWinControl read FOwner;
    property ChangeStamp: Integer read FChangeStamp;
  end;

var
  GTK2WidgetSet: TGTK2WidgetSet;


// Gtk2FileDialogUtils

procedure ExtractFilterList(const Filter: string;
  out ListOfFileSelFilterEntry: TFPList; SplitMultiMask: boolean);
procedure FreeListOfFileSelFilterEntry(ListOfFileSelFilterEntry: TFPList);

implementation

uses
  {%H-}Gtk2WSFactory{%H-},
{$ifdef Windows}
  Gtk2Windows,
{$endif}
  Gtk2WSStdCtrls,
  Gtk2WSControls,
  Gtk2WSCheckLst,
  Gtk2WSPrivate,
  Gtk2Themes,
////////////////////////////////////////////////////
  {%H-}Gtk2Debug{%H-};

{$include gtk2widgetset.inc}
{$include gtk2winapi.inc}
{$include gtk2lclintf.inc}


{*************************************************************}
{                      TGtkListStoreStringList methods             }
{*************************************************************}

{------------------------------------------------------------------------------
  Method: TGtkListStoreStringList.Create
  Params:
  Returns:

 ------------------------------------------------------------------------------}
constructor TGtkListStoreStringList.Create(AListStore: PGtkListStore;
  ColumnIndex: Integer; AOwner: TWinControl);
begin
  inherited Create;
  if AListStore = nil 
  then RaiseGDBException('TGtkListStoreStringList.Create Unspecified list store');

  FGtkListStore := AListStore;

  if (ColumnIndex < 0) 
  or (ColumnIndex >= gtk_tree_model_get_n_columns(GTK_TREE_MODEL(fGtkListStore))) 
  then RaiseGDBException('TGtkListStoreStringList.Create Invalid Column Index');
  FColumnIndex := ColumnIndex;

  if AOwner = nil 
  then RaiseGDBException('TGtkListStoreStringList.Create Unspecified owner');
  FOwner := AOwner;
  FStates := [glsItemCacheNeedsUpdate, glsCountNeedsUpdate];
end;

destructor TGtkListStoreStringList.Destroy;
begin
  FGtkListStore := nil;
  // don't destroy the widgets
  ReAllocMem(FCachedItems, 0);
  inherited Destroy;
end;

function TGtkListStoreStringList.Add(const S: String): Integer;
begin
  if FSorted then
    Find(S, Result)
  else
    Result := Count;

  //DebugLn(['TGtkListStoreStringList.Add ',S,' Count=',Result]);
  Insert(Result, S);
end;

{------------------------------------------------------------------------------
  Method: TGtkListStringList.SetSorted
  Params:
  Returns:

 ------------------------------------------------------------------------------}
procedure TGtkListStoreStringList.SetSorted(Val: Boolean);
var
  i: Integer;
begin
  if Val = FSorted then Exit;

  FSorted := Val;
  if not FSorted then Exit;

  for i := 0 to Count - 2 do
  begin
    if DoCompareText(Strings[i], Strings[i + 1]) < 0 then
    begin
      Sort;
      Break;
    end;
  end;
end;

{------------------------------------------------------------------------------
  procedure TGtkListStoreStringList.RemoveAllCallbacks;

 ------------------------------------------------------------------------------}

procedure TGtkListStoreStringList.UpdateItemCache;
var
  i: Integer;
begin
  if not (glsItemCacheNeedsUpdate in FStates) then exit;

  //DebugLn(['TGtkListStoreStringList.UpdateItemCache ']); DumpStack;
  FCachedSize := Count;
  FCachedCapacity := Count;
  ReAllocMem(FCachedItems, SizeOf(TGtkTreeIter) * FCachedCapacity);
  if FGtkListStore <> nil then
    for I := 0 to FCachedSize - 1 do
      gtk_tree_model_iter_nth_child(GTK_TREE_MODEL(FGtkListStore),
        @FCachedItems[i], nil, I);
  Exclude(FStates, glsItemCacheNeedsUpdate);
end;

procedure TGtkListStoreStringList.GrowCache;
begin
  FCachedCapacity := ((FCachedCapacity * 5) div 4) + 10;
  ReAllocMem(FCachedItems, SizeOf(TGtkTreeIter) * FCachedCapacity);
end;

procedure TGtkListStoreStringList.ShrinkCache;
begin
  FCachedCapacity := FCachedSize + 1;
  ReAllocMem(FCachedItems, SizeOf(TGtkTreeIter) * FCachedCapacity);
end;

procedure TGtkListStoreStringList.IncreaseChangeStamp;
begin
  if FChangeStamp < High(FChangeStamp) then
    Inc(FChangeStamp)
  else
    FChangeStamp := Low(FChangeStamp);
end;

procedure TGtkListStoreStringList.PutObject(Index: Integer; AnObject: TObject);
var
  ListItem: TGtkTreeIter;
begin
  if (Index < 0) or (Index >= Count) 
  then begin
    RaiseGDBException('TGtkListStoreStringList.PutObject Out of bounds.');
    Exit;
  end;

  if FGtkListStore = nil then Exit;

  UpdateItemCache;
  ListItem := FCachedItems[Index];
  gtk_list_store_set(FGtkListStore, @ListItem, [FColumnIndex + 1, Pointer(AnObject), -1]);
  IncreaseChangeStamp;
end;

{------------------------------------------------------------------------------
  Method: TGtkListStoreStringList.Sort
  Params:
  Returns:

 ------------------------------------------------------------------------------}
procedure TGtkListStoreStringList.Sort;
var
  sl: TStringList;
  OldSorted: Boolean;
begin
  BeginUpdate;
  // sort internally (sorting in the widget would be slow and unpretty ;)
  sl := TStringList.Create;
  sl.Assign(Self);
  sl.Sort;
  OldSorted := Sorted;
  FSorted := False;
  Assign(sl);
  FSorted := OldSorted;
  sl.Free;
  EndUpdate;
end;

function TGtkListStoreStringList.IsEqual(List: TStrings): Boolean;
var
  i, Cnt: Integer;
begin
  if List = Self then Exit(True);
  if List = nil then Exit(False);

  Cnt := Count;
  if (Cnt <> List.Count) then Exit(False);

  for i := 0 to Cnt - 1 do
  begin
    if Strings[i] <> List[i] then Exit(False);
    if Objects[i] <> List.Objects[i] then Exit(False);
  end;
  
  Result := True;
end;

procedure TGtkListStoreStringList.BeginUpdate;
begin
  Inc(FUpdateCount);
end;

procedure TGtkListStoreStringList.EndUpdate;
begin
  Dec(FUpdateCount);
end;

{------------------------------------------------------------------------------
  Method: TGtkListStoreStringList.Assign
  Params:
  Returns:

 ------------------------------------------------------------------------------}
procedure TGtkListStoreStringList.Assign(Source: TPersistent);
var
  i, Cnt: Integer;
  CmpList: TStrings;
  OldSorted: Boolean;
begin
  if (Source = Self) or (Source = nil) then Exit;

  if ((Source is TGtkListStoreStringList) 
  and (TGtkListStoreStringList(Source).FGtkListStore = FGtkListStore)) then
    RaiseGDBException('TGtkListStoreStringList.Assign: There are 2 lists with the same FGtkListStore');

  BeginUpdate;
  OldSorted := Sorted;
  CmpList := nil;
  try
    if Source is TStrings then
    begin
      // clearing and resetting can change other properties of the widget,
      // => don't change if the content is already the same
      if Sorted then
      begin
        CmpList := TStringList.Create;
        CmpList.Assign(TStrings(Source));
        TStringList(CmpList).Sort;
      end
      else
        CmpList := TStrings(Source);
     
      if IsEqual(CmpList) then Exit;

      Clear;
      FSorted := False;
      Cnt := TStrings(Source).Count;
      for i := 0 to Cnt - 1 do
      begin
        AddObject(CmpList[i], CmpList.Objects[i]);
        //DebugLn(['TGtkListStoreStringList.Assign ',i,' ',CmpList[i],' ',Count]);
      end;
      // ToDo: restore other settings

      // Do not call inherited Assign as it does things we do not want to happen
    end
    else
      inherited Assign(Source);
  finally
    fSorted := OldSorted;
    if CmpList <> Source 
    then CmpList.Free;

    EndUpdate;
  end;
end;

{------------------------------------------------------------------------------
  Method: TGtkListStoreStringList.Get
  Params:
  Returns:

 ------------------------------------------------------------------------------}
function TGtkListStoreStringList.Get(Index: Integer): String;
var
  Item: PChar;
  ListItem: TGtkTreeIter;
begin
  if (Index < 0) or (Index >= Count) 
  then begin
    RaiseGDBException('TGtkListStoreStringList.Get Out of bounds.');
    Exit;
  end;

  UpdateItemCache;
  ListItem := FCachedItems[Index];

  Item := nil;
  gtk_tree_model_get(GTK_TREE_MODEL(FGtkListStore), @ListItem, [FColumnIndex, @Item, -1]);
  if Item = nil then Exit('');

  Result := Item;
  g_free(Item);
end;

function TGtkListStoreStringList.GetObject(Index: Integer): TObject;
var
  ListItem: TGtkTreeIter;
begin
  if (Index < 0) or (Index >= Count)
  then begin
    RaiseGDBException('TGtkListStoreStringList.GetObject Out of bounds.');
    Exit(nil);
  end;
  if FGtkListStore = nil then Exit(nil);

  UpdateItemCache;
  ListItem := FCachedItems[Index];
  gtk_tree_model_get(FGtkListStore, @ListItem, [FColumnIndex + 1, @Result, -1]);
end;

procedure TGtkListStoreStringList.Put(Index: Integer; const S: String);
var
  ListItem: TGtkTreeIter;
begin
  if (Index < 0) or (Index >= Count) 
  then begin
    RaiseGDBException('TGtkListStoreStringList.Put Out of bounds.');
    Exit;
  end;
  if FGtkListStore = nil then Exit;

  UpdateItemCache;
  ListItem := FCachedItems[Index];
  gtk_list_store_set(FGtkListStore, @ListItem, [FColumnIndex, PChar(S), -1]);
  IncreaseChangeStamp;
end;

{------------------------------------------------------------------------------
  Method: TGtkListStoreStringList.GetCount
  Params:
  Returns:

 ------------------------------------------------------------------------------}
function TGtkListStoreStringList.GetCount: Integer;
begin
  if (glsCountNeedsUpdate in FStates) then
  begin
    if FGtkListStore <> nil then
      FCachedCount := gtk_tree_model_iter_n_children(GTK_TREE_MODEL(FGtkListStore), nil)
    else
      FCachedCount := 0;
    Exclude(FStates, glsCountNeedsUpdate);
  end;
  Result := FCachedCount;
end;

{------------------------------------------------------------------------------
  Method: TGtkListStoreStringList.Clear
  Params:
  Returns:

 ------------------------------------------------------------------------------}
procedure TGtkListStoreStringList.Clear;
var
  WidgetInfo: PWidgetInfo;
begin
  //DebugLn(['TGtkListStoreStringList.Clear ']);
  //while Count>0 do Delete(Count-1);

  //Lock the widget to avoid trigger events
  //Note: Assign/Clear is called inside CreateHandle before Handle is set
  if FOwner.HandleAllocated then
  begin
    WidgetInfo := GetWidgetInfo({%H-}Pointer(FOwner.Handle));
    Inc(WidgetInfo^.ChangeLock);

    gtk_list_store_clear(FGtkListStore);

    //resize columns to optimal width. See issue #17837
    //TODO: see if this is needed by TComboBox and others.
    if FOwner is TListBox then
      gtk_tree_view_columns_autosize(PGtkTreeView(WidgetInfo^.CoreWidget));

    Dec(WidgetInfo^.ChangeLock);
    //Update the internal Index cache
    PInteger(WidgetInfo^.UserData)^ := -1;
  end;

  IncreaseChangeStamp;

  ReAllocMem(FCachedItems, 0);
  FCachedCapacity := 0;
  FCachedSize := 0;
  Exclude(FStates, glsItemCacheNeedsUpdate);
  FCachedCount := 0;
  Exclude(FStates, glsCountNeedsUpdate);
end;

{------------------------------------------------------------------------------
  Method: TGtkListStoreStringList.Delete
  Params:
  Returns:

 ------------------------------------------------------------------------------}
procedure TGtkListStoreStringList.Delete(Index: Integer);
var
  ListItem: TGtkTreeIter;
  WidgetInfo: PWidgetInfo;
begin
  if not (glsItemCacheNeedsUpdate in FStates) then
    ListItem := FCachedItems[Index]
  else
    gtk_tree_model_iter_nth_child(FGtkListStore, @ListItem, nil, Index);

  //gtk_list_store_g
  WidgetInfo := GetWidgetInfo({%H-}Pointer(FOwner.Handle));
  //Lock the widget to avoid trigger events
  Inc(WidgetInfo^.ChangeLock);
  gtk_list_store_remove(FGtkListStore, @ListItem);
  Dec(WidgetInfo^.ChangeLock);
  IncreaseChangeStamp;

  if not (glsCountNeedsUpdate in FStates) then
    Dec(FCachedCount);
  if (not (glsItemCacheNeedsUpdate in FStates)) and (Index = Count) then
  begin
    // cache is valid and the last item was deleted -> just remove last item
    Dec(FCachedSize);
    if (FCachedSize < FCachedCapacity div 2) then
      ShrinkCache;
  end
  else
    Include(FStates, glsItemCacheNeedsUpdate);

  if FOwner is TCustomComboBox then
  begin
    TGtk2WSCustomComboBox.SetText(FOwner, '');
    //Update the internal Index cache
    PInteger(WidgetInfo^.UserData)^ := -1;
  end;
end;

function TGtkListStoreStringList.Find(const S: String; out Index: Integer): Boolean;
var
  L, R, I: Integer;
  CompareRes: Integer;
begin
  Result := False;
  // Use binary search.
  L := 0;
  R := Count - 1;
  while (L <= R) do
  begin
    I := L + (R - L) div 2;
    CompareRes := DoCompareText(S, Strings[I]);
    if (CompareRes > 0) then
      L := I + 1
    else
    begin
      R := I - 1;
      if (CompareRes = 0) then
      begin
        Result := True;
        L := I; // forces end of while loop
      end;
    end;
  end;
  Index := L;
end;

function TGtkListStoreStringList.IndexOf(const S: String): Integer;
begin
  Result := -1;
  BeginUpdate;
  if FSorted then
  begin
    //Binary Search
    if not Find(S, Result) then
      Result := -1;
  end else
    Result := inherited IndexOf(S);
  EndUpdate;
end;

{------------------------------------------------------------------------------
  Method: TGtkListStoreStringList.Insert
  Params:
  Returns:

 ------------------------------------------------------------------------------}
procedure TGtkListStoreStringList.Insert(Index: Integer; const S: String);
var
  li: TGtkTreeIter;
  LCLIndex: PInteger;
begin
  if (Index < 0) or (Index > Count)
  then begin
    RaiseGDBException('TGtkListStoreStringList.Insert: Index ' + IntToStr(Index) + ' out of bounds. Count=' + IntToStr(Count));
    Exit;
  end;

  if Owner = nil
  then begin
    RaiseGDBException('TGtkListStoreStringList.Insert Unspecified owner');
    Exit;
  end;

  BeginUpdate;
  try
    // this call is few times faster than gtk_list_store_insert, gtk_list_store_set
    gtk_list_store_insert_with_values(FGtkListStore, @li, Index, FColumnIndex, PChar(S), -1);
    IncreaseChangeStamp;

    //if the item is inserted before the selected item the
    //internal index cache becomes out of sync
    if (FOwner is TCustomComboBox) and FOwner.HandleAllocated then
    begin
      LCLIndex := PInteger(GetWidgetInfo({%H-}Pointer(FOwner.Handle))^.UserData);
      if Index <= LCLIndex^ then
        Inc(LCLIndex^);
    end;

    // ToDo: connect callbacks

    if not (glsCountNeedsUpdate in FStates) then
      Inc(FCachedCount);

    if (not (glsItemCacheNeedsUpdate in FStates)) and (Index = Count - 1) then
    begin
      // cache is valid and item was added as last
      // Add item to cache (instead of updating the whole cache)
      // This accelerates Assign.
      if FCachedSize = FCachedCapacity then GrowCache;
      FCachedItems[FCachedSize] := li;
      Inc(FCachedSize);
    end
    else
      Include(FStates, glsItemCacheNeedsUpdate);
  finally
    EndUpdate;
  end;
end;

procedure TGtkListStoreStringList.Move(CurIndex, NewIndex: Integer);
const
  AState: Array[Boolean] of TCheckBoxState = (cbUnchecked, cbChecked);
var
  AItemChecked: Boolean;
begin
  if FOwner is TCheckListBox then
    AItemChecked := TCheckListBox(FOwner).Checked[CurIndex];
  inherited Move(CurIndex, NewIndex);
  if FOwner is TCheckListBox then
    TGtk2WSCustomCheckListBox.SetState(TCustomCheckListBox(FOwner),
      NewIndex, AState[AItemChecked]);

end;

{$I gtk2listsl.inc}

// Gtk2FileDialogUtils

{------------------------------------------------------------------------------
  Function: ExtractFilterList
  Params: const Filter: string; var FilterIndex: integer;
          var ListOfPFileSelFilterEntry: TStringList
  Returns: -

  Converts a Delphi file filter of the form
  'description1|mask1|description2|mask2|...'
  into a TFPList of PFileSelFilterEntry(s).
  Multi masks:
    - multi masks like '*.pas;*.pp' are converted into multiple entries.
    - if the masks are found in the description they are adjusted
    - if the mask is not included in the description it will be concatenated
    For example:
      'Pascal files (*.pas;*.pp)|*.pas;*.lpr;*.pp;
      is converted to three filter entries:
        'Pascal files (*.pas)' + '*.pas'
        'Pascal files (*.pp)'  + '*.pp'
        'Pascal files (*.lpr)' + '*.lpr'
 ------------------------------------------------------------------------------}
procedure ExtractFilterList(const Filter: string;
  out ListOfFileSelFilterEntry: TFPList;
  SplitMultiMask: boolean);
var
  Masks: TStringList;
  CurFilterIndex: integer;

  procedure ExtractMasks(const MultiMask: string);
  var CurMaskStart, CurMaskEnd: integer;
    s: string;
  begin
    if Masks=nil then
      Masks:=TStringList.Create
    else
      Masks.Clear;
    CurMaskStart:=1;
    while CurMaskStart<=length(MultiMask) do begin
      CurMaskEnd:=CurMaskStart;
      if SplitMultiMask then begin
        while (CurMaskEnd<=length(MultiMask)) and (MultiMask[CurMaskEnd]<>';')
        do
          inc(CurMaskEnd);
      end else begin
        CurMaskEnd:=length(MultiMask)+1;
      end;
      s:=Trim(copy(MultiMask,CurMaskStart,CurMaskEnd-CurMaskStart));
      Masks.Add(s);
      CurMaskStart:=CurMaskEnd+1;
    end;
  end;

  procedure AddEntry(const Desc, Mask: string);
  var NewFilterEntry: TFileSelFilterEntry;
  begin
    NewFilterEntry:=TFileSelFilterEntry.Create(Desc,Mask);
    NewFilterEntry.FilterIndex:=CurFilterIndex;
    ListOfFileSelFilterEntry.Add(NewFilterEntry);
  end;

  // remove all but one masks from description string
  function RemoveOtherMasks(const Desc: string; MaskIndex: integer): string;
  var i, StartPos, EndPos: integer;
  begin
    Result:=Desc;
    for i:=0 to Masks.Count-1 do begin
      if i=MaskIndex then continue;
      StartPos:=Pos(Masks[i],Result);
      EndPos:=StartPos+length(Masks[i]);
      if StartPos<1 then continue;
      while (StartPos>1) and (Result[StartPos-1] in [' ',#9,';']) do
        dec(StartPos);
      while (EndPos<=length(Result)) and (Result[EndPos] in [' ',#9]) do
        inc(EndPos);
      if (StartPos>1) and (Result[StartPos-1]='(')
      and (EndPos<=length(Result)) then begin
        if (Result[EndPos]=')') then begin
          dec(StartPos);
          inc(EndPos);
        end else if Result[EndPos]=';' then begin
          inc(EndPos);
        end;
      end;
      System.Delete(Result,StartPos,EndPos-StartPos);
    end;
  end;

  procedure AddEntries(const Desc: string; MultiMask: string);
  var i: integer;
    CurDesc: string;
  begin
    ExtractMasks(MultiMask);
    for i:=0 to Masks.Count-1 do begin
      CurDesc:=RemoveOtherMasks(Desc,i);
      if (Masks.Count>1) and (Pos(Masks[i],CurDesc)<1) then begin
        if (CurDesc='') or (CurDesc[length(CurDesc)]<>' ') then
          CurDesc:=CurDesc+' ';
        CurDesc:=CurDesc+'('+Masks[i]+')';
      end;
      //debugln('AddEntries ',CurDesc,' ',Masks[i]);
      AddEntry(CurDesc,Masks[i]);
    end;
    inc(CurFilterIndex);
  end;

var
  CurDescStart, CurDescEnd, CurMultiMaskStart, CurMultiMaskEnd: integer;
  CurDesc, CurMultiMask: string;
begin
  ListOfFileSelFilterEntry:=TFPList.Create;
  Masks:=nil;
  CurFilterIndex:=0;
  CurDescStart:=1;
  while CurDescStart<=length(Filter) do begin
    // extract next filter description
    CurDescEnd:=CurDescStart;
    while (CurDescEnd<=length(Filter)) and (Filter[CurDescEnd]<>'|') do
      inc(CurDescEnd);
    CurDesc:=copy(Filter,CurDescStart,CurDescEnd-CurDescStart);
    // extract next filter multi mask
    CurMultiMaskStart:=CurDescEnd+1;
    CurMultiMaskEnd:=CurMultiMaskStart;
    while (CurMultiMaskEnd<=length(Filter)) and (Filter[CurMultiMaskEnd]<>'|') do
      inc(CurMultiMaskEnd);
    CurMultiMask:=copy(Filter,CurMultiMaskStart,CurMultiMaskEnd-CurMultiMaskStart);
    if CurDesc='' then CurDesc:=CurMultiMask;
    // add filter(s)
    if (CurMultiMask<>'') or (CurDesc<>'') then
      AddEntries(CurDesc,CurMultiMask);
    // next filter
    CurDescStart:=CurMultiMaskEnd+1;
  end;
  Masks.Free;
end;

procedure FreeListOfFileSelFilterEntry(ListOfFileSelFilterEntry: TFPList);
var
  i: Integer;
begin
  if ListOfFileSelFilterEntry=nil then exit;
  for i:=0 to ListOfFileSelFilterEntry.Count-1 do
    TObject(ListOfFileSelFilterEntry[i]).Free;
  ListOfFileSelFilterEntry.Free;
end;

procedure InternalInit;
var
  c: TClipboardType;
begin
  gtk_handler_quark := g_quark_from_static_string('gtk-signal-handlers');

  MouseCaptureWidget := nil;

  // clipboard
  ClipboardSelectionData:=TFPList.Create;
  for c:=Low(TClipboardType) to High(TClipboardType) do begin
    ClipboardTypeAtoms[c]:=0;
    ClipboardHandler[c]:=nil;
    //ClipboardIgnoreLossCount[c]:=0;
    ClipboardTargetEntries[c]:=nil;
    ClipboardTargetEntryCnt[c]:=0;
  end;

  // charset encodings
  CharSetEncodingList := TList.Create;
  CreateDefaultCharsetEncodings;

  InitDesignSignalMasks;
end;

procedure InternalFinal;
var i: integer;
  ced: PClipboardEventData;
  c: TClipboardType;
begin
  // clipboard
  for i:=0 to ClipboardSelectionData.Count-1 do begin
    ced:=PClipboardEventData(ClipboardSelectionData[i]);
    FreeMem(ced^.Data.Data);
    Dispose(ced);
  end;
  for c:=Low(TClipboardType) to High(TClipboardType) do
    FreeClipboardTargetEntries(c);
  FreeAndNil(ClipboardSelectionData);

  // charset encodings
  if CharSetEncodingList<>nil then begin
    ClearCharSetEncodings;
    FreeAndNil(CharSetEncodingList);
  end;
end;


initialization
  InternalInit;

finalization
  InternalFinal;

end.


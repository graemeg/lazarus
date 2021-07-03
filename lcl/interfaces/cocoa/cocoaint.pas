{
 /***************************************************************************
                    CocoaInt.pas  -  CocoaInterface Object
                    ----------------------------------------

                 Initial Revision  : Mon August 6th CST 2004


 ***************************************************************************/

 *****************************************************************************
  This file is part of the Lazarus Component Library (LCL)

  See the file COPYING.modifiedLGPL.txt, included in this distribution,
  for details about the license.
 *****************************************************************************
 }

unit CocoaInt;

{$mode objfpc}{$H+}
{$modeswitch objectivec1}
{$modeswitch objectivec2}
{$include cocoadefines.inc}

interface

uses
  // rtl+ftl
  Types, Classes, SysUtils, Math, contnrs,
  // carbon bindings
  MacOSAll,
  // interfacebase
  LCLPlatformDef, InterfaceBase, GraphType,
  // private
  CocoaAll, CocoaPrivate, CocoaUtils, CocoaGDIObjects,
  cocoa_extra, CocoaWSMenus, CocoaWSForms, CocoaWindows, CocoaScrollers,
  CocoaWSClipboard, CocoaTextEdits, CocoaWSCommon,
  // LCL
  LCLStrConsts, LMessages, LCLMessageGlue, LCLProc, LCLIntf, LCLType,
  Controls, Forms, Themes, Menus,
  IntfGraphics, Graphics, CocoaWSFactory;

type

  { TCocoaTimerObject }

  TCocoaTimerObject = objcclass(NSObject)
    func: TWSTimerProc;
    procedure timerEvent; message 'timerEvent';
    class function newWithFunc(afunc: TWSTimerProc): TCocoaTimerObject; message 'newWithFunc:';
  end;

  { TAppDelegate }

  TWinLevelOrder = record
    win : NSWindow;
    lvl : NSInteger;
    ord : NSinteger;
    vis : Boolean;
  end;
  PWinLevelOrder = ^TWinLevelOrder;
  TWinLevelOrderArray = array [Word] of TWinLevelOrder;
  PWinLevelOrderArray = ^TWinLevelOrderArray;

  TAppDelegate = objcclass(NSObject, NSApplicationDelegateProtocol)
  public
    orderArray : PWinLevelOrderArray;
    orderArrayCount : Integer;
    procedure application_openFiles(sender: NSApplication; filenames: NSArray);
    procedure applicationDidHide(notification: NSNotification);
    procedure applicationDidUnhide(notification: NSNotification);
    procedure applicationWillBecomeActive(notification: NSNotification);
    procedure applicationDidBecomeActive(notification: NSNotification);
    procedure applicationDidResignActive(notification: NSNotification);
    procedure applicationDidChangeScreenParameters(notification: NSNotification);
    procedure applicationWillFinishLaunching(notification: NSNotification);
    procedure handleQuitAppEvent_withReplyEvent(event: NSAppleEventDescriptor; replyEvent: NSAppleEventDescriptor); message 'handleQuitAppEvent:withReplyEvent:';
  end;

  { TCocoaApplication }

  TCocoaApplication = objcclass(NSApplication)
    aloop : TApplicationMainLoop;
    isrun : Boolean;
    modals : NSMutableDictionary;
    inputclient : TCocoaInputClient;
    inputctx    : NSTextInputContext;
    {$ifdef COCOAPPRUNNING_OVERRIDEPROPERTY}
    Stopped : Boolean;
    {$endif}

    procedure dealloc; override;
    {$ifdef COCOALOOPOVERRIDE}
    procedure run; override;
    {$endif}
    procedure sendEvent(theEvent: NSEvent); override;
    function nextEventMatchingMask_untilDate_inMode_dequeue(mask: NSUInteger; expiration: NSDate; mode: NSString; deqFlag: LCLObjCBoolean): NSEvent; override;

    function runModalForWindow(theWindow: NSWindow): NSInteger; override;
    procedure lclSyncCheck(arg: id); message 'lclSyncCheck:';
    {$ifdef COCOAPPRUNNING_OVERRIDEPROPERTY}
    function isRunning: {$if FPC_FULLVERSION >= 30200}objc.ObjCBOOL{$else}Boolean{$endif}; override;
    procedure stop(sender: id); override;
    {$endif}
  end;

  { TModalSession }

  TModalSession = class(TObject)
    window : NSWindow;
    sess   : NSModalSession;
    // recording menu state for the modality stack
    // there's no limitation for a modal window to have its own menu
    // if it override the mainMenu, we still need the information
    // to restore the previous state of the mainmenu
    prevMenuEnabled: Boolean;
    cocoaMenu : NSMenu;
    lclMenu   : TMenu;
    constructor Create(awin: NSWindow; asess: NSModalSession;
      APrevMenuEnabled: Boolean;
      amainmenu: NSMenu; ALCL: TMenu);
  end;

  { TCocoaWidgetSet }

  TCocoaWidgetSet = class(TWidgetSet)
  private
    FTerminating: Boolean;
    FNSApp: TCocoaApplication;
    FNSApp_Delegate: TAppDelegate;
    FCurrentCursor: HCursor;
    FCaptureControl: HWND;

  protected
    FStockNullBrush: HBRUSH;
    FStockBlackBrush: HBRUSH;
    FStockLtGrayBrush: HBRUSH;
    FStockGrayBrush: HBRUSH;
    FStockDkGrayBrush: HBRUSH;
    FStockWhiteBrush: HBRUSH;

    FStockNullPen: HPEN;
    FStockBlackPen: HPEN;
    FStockWhitePen: HPEN;
    FStockSystemFont: HFONT;
    FStockFixedFont: HFONT;

    FSysColorBrushes: array[0..MAX_SYS_COLORS] of HBrush;

    // Sandboxing
    SandboxingOn: Boolean;
    fClipboard: TCocoaWSClipboard;

    // Clipboard

    // collecting objects that needs to be released AFTER an event
    // has been processed
    ToCollect: TList;
    function RetainToCollect: Integer;
    procedure ReleaseToCollect(fromIdx: integer);

    procedure SyncClipboard();

    function PromptUser(const DialogCaption, DialogMessage: String;
      DialogType: longint; Buttons: PLongint; ButtonCount, DefaultIndex,
      EscapeResult: Longint): Longint; override;
    function MessageBox(HWnd: HWND; lpText, lpCaption: PChar;
      uType: Cardinal): Integer; override;
    function GetAppHandle: THandle; override;
    function CreateThemeServices: TThemeServices; override;

    procedure SendCheckSynchronizeMessage;
    procedure OnWakeMainThread(Sender: TObject);

    procedure DoSetMainMenu(AMenu: NSMenu; ALCLMenu: TMenu);
  public
    // modal session
    CurModalForm: NSWindow;
    Modals : TList;
    ModalCounter: Integer; // the cheapest way to determine if modal window was called
                           // used in mouse handling (in callbackobject)
                           // Might not be needed, if native Modality used
    MainMenuEnabled: Boolean; // the latest main menu status
    PrevMenu : NSMenu;
    PrevLCLMenu : TMenu;
    CurLCLMenu: TMenu;
    PrevMenuEnabled: Boolean; // previous mainmenu status

    constructor Create; override;
    destructor Destroy; override;

    function LCLPlatform: TLCLPlatform; override;

    procedure AppInit(var ScreenInfo: TScreenInfo); override;
    procedure AppRun(const ALoop: TApplicationMainLoop); override;
    procedure AppRunMessages(onlyOne: Boolean; eventExpDate: NSDate);
    procedure AppWaitMessage; override;
    procedure AppProcessMessages; override;
    procedure AppTerminate; override;
    procedure AppMinimize; override;
    procedure AppRestore; override;
    procedure AppBringToFront; override;
    procedure AppSetIcon(const Small, Big: HICON); override;
    procedure AppSetTitle(const ATitle: string); override;

    function  GetLCLCapability(ACapability: TLCLCapability): PtrUInt; override;

    function CreateTimer(Interval: integer; TimerFunc: TWSTimerProc): THandle; override;
    function DestroyTimer(TimerHandle: THandle): boolean; override;

    procedure InitStockItems;
    procedure FreeStockItems;
    procedure FreeSysColorBrushes;

    procedure SetMainMenu(const AMenu: HMENU; const ALCLMenu: TMenu);
    function StartModal(awin: NSWindow; hasMenu: Boolean): Boolean;
    procedure EndModal(awin: NSWindow);
    function isTopModalWin(awin: NSWindow): Boolean;
    function isModalSession: Boolean;

    {todo:}
    function  DCGetPixel(CanvasHandle: HDC; X, Y: integer): TGraphicsColor; override;
    procedure DCSetPixel(CanvasHandle: HDC; X, Y: integer; AColor: TGraphicsColor); override;
    procedure DCRedraw(CanvasHandle: HDC); override;
    procedure DCSetAntialiasing(CanvasHandle: HDC; AEnabled: Boolean); override;
    procedure SetDesigning(AComponent: TComponent); override;

    function RawImage_DescriptionFromCocoaBitmap(out ADesc: TRawImageDescription; ABitmap: TCocoaBitmap): Boolean;
    function RawImage_FromCocoaBitmap(out ARawImage: TRawImage; ABitmap, AMask: TCocoaBitmap; ARect: PRect = nil): Boolean;
    function RawImage_DescriptionToBitmapType(ADesc: TRawImageDescription; out bmpType: TCocoaBitmapType): Boolean;
    function GetImagePixelData(AImage: CGImageRef; out bitmapByteCount: PtrUInt): Pointer;
    class function Create32BitAlphaBitmap(ABitmap, AMask: TCocoaBitmap): TCocoaBitmap;
    property NSApp: TCocoaApplication read FNSApp;
    property CurrentCursor: HCursor read FCurrentCursor write FCurrentCursor;
    property CaptureControl: HWND read FCaptureControl;
    // the winapi compatibility methods
    {$I cocoawinapih.inc}
    // the extra LCL interface methods
    {$I cocoalclintfh.inc}
    procedure AddToCollect(obj: TObject);
  end;
  
var
  CocoaWidgetSet: TCocoaWidgetSet;
  CocoaBasePPI : Integer = 96; // for compatiblity with LCL 1.8 release. The macOS base is 72ppi
  MainPool : NSAutoreleasePool = nil;

  // if set to true, then WS would not assign icons via TCocoaWSForm SetIcon
  // The icon would have to be changed manually. By default LCL behaviour is used
  CocoaIconUse: Boolean = false;
  CocoaToggleBezel : NSBezelStyle = NSRoundedBezelStyle;
  CocoaToggleType  : NSButtonType = NSPushOnPushOffButton;

  CocoaHideFocusNoBorder : Boolean = true;

  {$ifdef COCOALOOPHIJACK}
  // The flag is set to true once hi-jacked loop is finished (at the end of app)
  // The flag is checked in Menus to avoid "double" Cmd+Q menu
  LoopHiJackEnded : Boolean = false;
  {$endif}

function CocoaScrollBarSetScrollInfo(bar: TCocoaScrollBar; const ScrollInfo: TScrollInfo): Integer;
function CocoaScrollBarGetScrollInfo(bar: TCocoaScrollBar; var ScrollInfo: TScrollInfo): Boolean;
procedure NSScrollerGetScrollInfo(docSz, pageSz: CGFloat; rl: NSSCroller; Var ScrollInfo: TScrollInfo);
procedure NSScrollViewGetScrollInfo(sc: NSScrollView; BarFlag: Integer; Var ScrollInfo: TScrollInfo);
procedure NSScrollerSetScrollInfo(docSz, pageSz: CGFloat; rl: NSSCroller; const ScrollInfo: TScrollInfo);
procedure NSScrollViewSetScrollPos(sc: NSScrollView; BarFlag: Integer; const ScrollInfo: TScrollInfo);

function CocoaPromptUser(const DialogCaption, DialogMessage: String;
    DialogType: longint; Buttons: PLongint; ButtonCount, DefaultIndex,
    EscapeResult: Longint;
    sheetOfWindow: NSWindow = nil; modalSheet: Boolean = false): Longint;

// The function tries to initialize the proper application class.
// The desired application class can be specified in info.plit
// by specifying NSPrincipalClass property.
// If then principal class has been found (in the bundle binaries)
// InitApplication function will try to call its "sharedApplication" method.
// If principle class is not specified, then TCocoaApplication is used.
// You should always specify either TCocoaApplication or
// a class derived from TCocoaApplication, in order for LCL to fucntion properly
function InitApplication: TCocoaApplication;

implementation


// NSCursor doesn't support any wait cursor, so we need to use a non-native one
// Not supporting it at all would result in crashes in Screen.Cursor := crHourGlass;
{$R ../../cursor_hourglass.res}

uses
  dl,dynlibs,
  CocoaCaret,
  CocoaThemes;

function CocoaScrollBarSetScrollInfo(bar: TCocoaScrollBar; const ScrollInfo: TScrollInfo): Integer;
var
  pg  : Integer;
  mn  : Integer;
  mx  : Integer;
  dl  : Integer;
begin
  if not Assigned(bar) then
  begin
    Result := 0;
    Exit;
  end;

  if ScrollInfo.fMask and SIF_PAGE>0 then
  begin
    pg:=ScrollInfo.nPage;
  end
  else pg:=bar.pageInt;

  if ScrollInfo.fMask and SIF_RANGE>0 then
  begin
    mn:=ScrollInfo.nMin;
    mx:=ScrollInfo.nMax;
  end
  else
  begin
    mn:=bar.minInt;
    mx:=bar.maxInt;
  end;

  dl:=mx-mn;
  {$ifdef BOOLFIX}
  bar.setEnabled_(Ord(dl<>0));
  {$else}
  bar.SetEnabled(dl<>0);
  {$endif}

  // if changed page or range, the knob changes
  if ScrollInfo.fMask and (SIF_RANGE or SIF_PAGE)>0 then
  begin
    if dl<>0 then
      bar.setKnobProportion(pg/dl)
    else
      bar.setKnobProportion(1);
    bar.pageInt:=pg;
    bar.minInt:=mn;
    bar.maxInt:=mx;
  end;

  if ScrollInfo.fMask and SIF_POS > 0 then
    bar.lclSetPos( ScrollInfo.nPos );

  Result:=bar.lclPos;
end;

function CocoaScrollBarGetScrollInfo(bar: TCocoaScrollBar; var ScrollInfo: TScrollInfo): Boolean;
var
  l : integer;
begin
  Result:=Assigned(bar);
  if not Result then Exit;

  FillChar(ScrollInfo, sizeof(ScrollInfo), 0);
  ScrollInfo.cbSize:=sizeof(ScrollInfo);
  ScrollInfo.fMask:=SIF_ALL;
  ScrollInfo.nMin:=bar.minInt;
  ScrollInfo.nMax:=bar.maxInt;
  ScrollInfo.nPage:=bar.pageInt;
  ScrollInfo.nPos:=bar.lclPos;
  ScrollInfo.nTrackPos:=ScrollInfo.nPos;
  Result:=true;
end;

procedure NSScrollerGetScrollInfo(docSz, pageSz: CGFloat; rl: NSSCroller; Var ScrollInfo: TScrollInfo);
begin
  ScrollInfo.cbSize:=sizeof(ScrollInfo);
  ScrollInfo.fMask:=SIF_ALL;
  ScrollInfo.nPos:=round(rl.floatValue*(docSz-pageSz));
  ScrollInfo.nTrackPos:=ScrollInfo.nPos;
  ScrollInfo.nMin:=0;
  ScrollInfo.nMax:=round(docSz);
  ScrollInfo.nPage:=round(rl.knobProportion*docSz);
end;

procedure NSScrollViewGetScrollInfo(sc: NSScrollView; BarFlag: Integer; Var ScrollInfo: TScrollInfo);
var
  ns : NSView;
  vr : NSRect;
begin
  ns:=sc.documentView;
  if not Assigned(ns) then begin
    FillChar(ScrollInfo, sizeof(ScrollInfo),0);
    ScrollInfo.cbSize:=sizeof(ScrollInfo);
    Exit;
  end;
  vr:=sc.documentVisibleRect;
  if BarFlag = SB_Vert then
    NSScrollerGetScrollInfo(ns.frame.size.height, vr.size.height, sc.verticalScroller, ScrollInfo)
  else
    NSScrollerGetScrollInfo(ns.frame.size.width, vr.size.width, sc.horizontalScroller, ScrollInfo);
end;

procedure NSScrollerSetScrollInfo(docSz, pageSz: CGFloat; rl: NSSCroller; const ScrollInfo: TScrollInfo);
var
  sz : CGFloat;
begin
  if ScrollInfo.fMask and SIF_POS>0 then begin
    sz:=docSz-pageSz;
    if sz=0 then rl.setFloatValue(0)
    else rl.setFloatValue(ScrollInfo.nPos/sz);
  end;
  if ScrollInfo.fMask and SIF_PAGE>0 then begin
    sz:=docSz-pageSz;
    if sz=0 then rl.setKnobProportion(1)
    else rl.setKnobProportion(1/sz);
  end;
end;

procedure NSScrollViewSetScrollPos(sc: NSScrollView; BarFlag: Integer; const ScrollInfo: TScrollInfo);
var
  ns : NSView;
  vr : NSRect;
begin
  ns:=sc.documentView;
  if not Assigned(ns) then Exit;

  vr:=sc.documentVisibleRect;
  if BarFlag = SB_Vert then
  begin
    //NSScrollerSetScrollInfo(ns.frame.size.height, sc.verticalScroller, ScrollInfo)
    if not sc.documentView.isFlipped then
      vr.origin.y := sc.documentView.frame.size.height - ScrollInfo.nPos - vr.size.Height
    else
      vr.origin.y := ScrollInfo.nPos;
  end
  else
  begin
    //NSScrollerSetScrollInfo(ns.frame.size.width, sc.horizontalScroller, ScrollInfo);
    vr.origin.x:=ScrollInfo.nPos;
  end;
  ns.scrollRectToVisible(vr);
end;

{ TModalSession }

constructor TModalSession.Create(awin: NSWindow; asess: NSModalSession;
  APrevMenuEnabled: Boolean; amainmenu: NSMenu; ALCL: TMenu);
begin
  inherited Create;
  window := awin;
  sess := asess;
  prevMenuEnabled := APrevMenuEnabled;
  cocoaMenu := amainmenu;
  lclMenu   := alcl;
end;

{ TCocoaApplication }

procedure TCocoaApplication.dealloc;
begin
  if Assigned(modals) then modals.release;
  if Assigned(inputclient) then inputclient.release;
  inherited dealloc;
end;

{$ifdef COCOALOOPOVERRIDE}
procedure TCocoaApplication.run;
begin
  {$ifdef COCOAPPRUNNING_SETINTPROPERTY}
  setValue_forKey(NSNumber.numberWithBool(true), NSSTR('_running'));
  {$endif}
  aloop();
end;
{$endif}

procedure ForwardMouseMove(app: NSApplication; theEvent: NSEvent);
var
  w   : NSWindow;
  kw  : NSWindow;
  ev  : NSEvent;
  p   : NSPoint;
  wfr : NSRect;
begin
  kw := app.keyWindow;

  // mouse move was consumed by the focused window
  if Assigned(kw) and NSPointInRect( theEvent.mouseLocation, kw.frame) then
    Exit;

  for w in app.windows do
  begin
    if w = kw then Continue;
    if not w.isVisible then Continue;
    // todo: check for enabled windows? modal windows?

    wfr := w.frame;
    if not NSPointInRect( theEvent.mouseLocation, wfr) then Continue;

    p := theEvent.mouseLocation;
    p.x := p.x - w.frame.origin.x;
    p.y := p.y - w.frame.origin.y;
    ev := NSEvent.mouseEventWithType_location_modifierFlags_timestamp_windowNumber_context_eventNumber_clickCount_pressure(
      theEvent.type_,
      p,
      theEvent.modifierFlags,
      theEvent.timestamp,
      w.windowNumber,
      theEvent.context,
      theEvent.eventNumber,
      theEvent.clickCount,
      theEvent.pressure
    );
    w.sendEvent(ev);
  end;
end;

procedure TCocoaApplication.sendEvent(theEvent: NSEvent);
var
  cb : ICommonCallback;
  wnd: TCocoaWindow;
  allowcocoa : Boolean;
  idx: integer;
  win : NSWindow;
  cbnew : ICommonCallback;
begin
  {$ifdef COCOALOOPNATIVE}
  try
  {$endif}
  idx := CocoaWidgetSet.RetainToCollect;
  win := theEvent.window;
  if not Assigned(win) then win := self.keyWindow;

  if Assigned(win) then
    cb := win.firstResponder.lclGetCallback
  else
    cb := nil;
  try
    if (theEvent.type_ = NSKeyDown) or (theEvent.type_ = NSKeyUp) or
       (theEvent.type_ = NSFlagsChanged) then begin
      if Assigned(cb) then
      begin
        try
          if win.isKindOfClass_(TCocoaWindow) then begin
            wnd := TCocoaWindow(win);
            wnd._keyEvCallback := cb;
          end
          else
            wnd := nil;

          {$ifndef CPUPOWERPC}
          if (theEvent.type_ = NSKeyDown)
            and not (win.firstResponder.conformsToProtocol(objcprotocol(NSTextInputClientProtocol))) then
          begin
            if not Assigned(inputctx) then
            begin
              inputclient := TCocoaInputClient.alloc.init;
              inputctx := NSTextInputContext.alloc.initWithClient(inputclient);
            end;
            inputctx.handleEvent(theEvent);
          end;
          {$endif}

          cb.KeyEvBefore(theEvent, allowcocoa);
          if allowcocoa then
            inherited sendEvent(theEvent);
          cb.KeyEvAfter;
        finally
          if Assigned(wnd) then
            wnd._keyEvCallback := nil;
        end;
        Exit;
      end;
    end;

    inherited sendEvent(theEvent);

    if (theEvent.type_ = NSMouseMoved) then ForwardMouseMove(Self, theEvent);

     // todo: this should be called for "Default" or "Modal" loops
     NSApp.updateWindows;

  finally

    // Focus change notification used to be in makeFirstResponder method
    // However, it caused many issues with infinite loops.
    // Sometimes Cocoa like to switch focus to window (temporary) (i.e. when switching tabs)
    // That's causing a conflict with LCL. LCL tries to switch focus back
    // to the original control. And Cocoa keep switching it back to the Window.
    // (Note, that for Cocoa, window should ALWAYS be focusable)
    // Thus, Focus switching notification was moved to post event handling.
    //
    // can't have this code in TCocoaWindow, because some key events are not forwarded
    // to the window
    cbnew := win.firstResponder.lclGetCallback;
    if not isCallbackForSameObject(cb, cbnew) then
    begin
      if Assigned(cb) then cb.ResignFirstResponder;
      cbnew := win.firstResponder.lclGetCallback;
      if Assigned(cbnew) then cbnew.BecomeFirstResponder;
    end;

    CocoaWidgetSet.ReleaseToCollect(idx);
  end;
  {$ifdef COCOALOOPNATIVE}
    if CocoaWidgetSet.FTerminating then stop(nil);
  except
    if CocoaWidgetSet.FTerminating then stop(nil);
    if Assigned(Application) and Application.CaptureExceptions then
      Application.HandleException(Application)
    else
      raise;
  end;
  {$endif}
end;

function isMouseMoveEvent(tp: NSEventType): Boolean; inline;
begin
  Result := (tp = NSMouseMoved)
    or (tp = NSLeftMouseDragged)
    or (tp = NSRightMouseDragged)
    or (tp = NSOtherMouseDragged);
end;

type
  TCrackerApplication = class(TApplication);

function TCocoaApplication.nextEventMatchingMask_untilDate_inMode_dequeue(
  mask: NSUInteger; expiration: NSDate; mode: NSString; deqFlag: LCLObjCBoolean
  ): NSEvent;
var
  cb : ICommonCallback;
begin
  {$ifdef COCOALOOPHIJACK}
  if not isrun and Assigned(aloop) then begin
    isrun := True;
    Result := nil;
    aloop();
    stop(nil); // this should stop the main loop
    LoopHiJackEnded := true;
    exit;
  end;
  {$endif}

  {$ifdef BOOLFIX}
  Result:=inherited nextEventMatchingMask_untilDate_inMode_dequeue_(
    mask,
    expiration, mode, Ord(deqFlag));
  {$else}
  Result:=inherited nextEventMatchingMask_untilDate_inMode_dequeue(mask,
    expiration, mode, deqFlag);
  {$endif}
  if not Assigned(Result) then
  begin
    {$ifdef COCOALOOPNATIVE}
    if Assigned(Application) then Application.Idle(true);
    {$endif}
    Exit;
  end;

  if ((mode = NSEventTrackingRunLoopMode) or mode.isEqualToString(NSEventTrackingRunLoopMode))
    and Assigned(TrackedControl)
  then
  begin
    if Result.type_ = NSLeftMouseUp then
    begin
      //todo: send callback!
      TrackedControl := nil;
    end
    else
    if isMouseMoveEvent(Result.type_) then
    begin
      cb := TrackedControl.lclGetCallback;
      if Assigned(cb) then begin
        // if the mouse event was handled by LCL - just don't return it back to Cocoa
        // i.e. needed for LCL to handle MouseMove events during DragAndDrop
        // Cocoa should not process the mouseMove at this time!
        if cb.MouseMove(Result) then Result := nil;
      end;
    end;
  end;
end;

function TCocoaApplication.runModalForWindow(theWindow: NSWindow): NSInteger;
begin
  ApplicationWillShowModal;

  Result:=inherited runModalForWindow(theWindow);
end;

procedure TCocoaApplication.lclSyncCheck(arg: id);
begin
  {$ifdef COCOALOOPNATIVE}
  try
    CheckSynchronize;
    if Assigned(Application) then
      TCrackerApplication(Application).ProcessAsyncCallQueue;
  except
    if Assigned(Application) and Application.CaptureExceptions then
      Application.HandleException(Application)
    else
      raise;
  end;
  {$else}
  CheckSynchronize;
  if Assigned(Application) then
    TCrackerApplication(Application).ProcessAsyncCallQueue;
  {$endif}
end;

{$ifdef COCOAPPRUNNING_OVERRIDEPROPERTY}
function TCocoaApplication.isRunning: {$if FPC_FULLVERSION >= 30200}objc.ObjCBOOL{$else}Boolean{$endif};
begin
  Result:=not Stopped;
end;

procedure TCocoaApplication.stop(sender: id);
begin
  Stopped := true;
  inherited stop(sender);
end;
{$endif}

procedure InternalInit;
begin
  // MacOSX 10.6 reports a lot of warnings during initialization process
  // adding the autorelease pool for the whole Cocoa widgetset
  MainPool := NSAutoreleasePool.alloc.init;
end;

procedure InternalFinal;
begin
  if Assigned(MainPool) then
  begin
    MainPool.release;
    MainPool := nil;
  end;
end;

type
  AppClassMethod = objccategory external (NSObject)
    function sharedApplication: NSApplication; message 'sharedApplication';
  end;

function InitApplication: TCocoaApplication;
var
  bun : NSBundle;
begin
  bun := NSBundle.mainBundle;
  if Assigned(bun) and Assigned(bun.principalClass) then
    Result := TCocoaApplication(NSObject(bun.principalClass).sharedApplication)
  else
    Result := TCocoaApplication(TCocoaApplication.sharedApplication);
end;

// the implementation of the utility methods
{$I cocoaobject.inc}
// the implementation of the winapi compatibility methods
{$I cocoawinapi.inc}
// the implementation of the extra LCL interface methods
{$I cocoalclintf.inc}

procedure TCocoaWidgetSet.DoSetMainMenu(AMenu: NSMenu; ALCLMenu: TMenu);
var
  i: Integer;
  lCurItem: TMenuItem;
  lMenuObj: NSObject;
  lNSMenu: NSMenu absolute AMenu;
begin
  if Assigned(PrevMenu) then PrevMenu.release;
  PrevMenu := NSApplication(NSApp).mainMenu;
  PrevMenu.retain;

  PrevLCLMenu := CurLCLMenu;

  if (lNSMenu.isKindOfClass(TCocoaMenu)) then
    TCocoaMenu(lNSMenu).attachAppleMenu();

  NSApp.setMainMenu(lNSMenu);
  CurLCLMenu := ALCLMenu;

  if (ALCLMenu = nil) or not ALCLMenu.HandleAllocated then Exit;

  // Find the Apple menu, if the user provided any by setting the Caption to 
  // Some older docs say we should use setAppleMenu to obtain the Services/Hide/Quit items,
  // but its now private and in 10.10 it doesn't seam to do anything
  // NSApp.setAppleMenu(NSMenu(lMenuObj));
  for i := 0 to ALCLMenu.Items.Count-1 do
  begin
    lCurItem := ALCLMenu.Items.Items[i];
    if not lNSMenu.isKindOfClass_(TCocoaMenu) then Break;
    if not lCurItem.HandleAllocated then Continue;

    lMenuObj := NSObject(lCurItem.Handle);
    if not lMenuObj.isKindOfClass_(TCocoaMenuItem) then Continue;
    if TCocoaMenuItem(lMenuObj).isValidAppleMenu() then
    begin
      TCocoaMenu(lNSMenu).overrideAppleMenu(TCocoaMenuItem(lMenuObj));
      Break;
    end;
  end;
end;

procedure TCocoaWidgetSet.SetMainMenu(const AMenu: HMENU; const ALCLMenu: TMenu);
begin
  if AMenu<>0 then
  begin
    DoSetMainMenu(NSMenu(AMenu), ALCLMenu);

    PrevMenuEnabled := MainMenuEnabled;
    MainMenuEnabled := true;
    ToggleAppMenu(true);
    //if not Assigned(ACustomForm.Menu) then ToggleAppMenu(false);

    // for modal windows work around bug, but doesn't work :(
    {$ifdef COCOA_USE_NATIVE_MODAL}
    {if CurModalForm <> nil then
    for i := 0 to lNSMenu.numberOfItems()-1 do
    begin
      lNSMenu.itemAtIndex(i).setTarget(TCocoaWSCustomForm.GetWindowFromHandle(CurModalForm));
    end;}
    {$endif}
  end;
end;

function TCocoaWidgetSet.StartModal(awin: NSWindow; hasMenu: Boolean): Boolean;
var
  sess : NSModalSession;
  lvl : NSInteger;
begin
  Result := false;
  if not Assigned(awin) then Exit;

  lvl := awin.level;

  sess := NSApplication(NSApp).beginModalSessionForWindow(awin);
  if not Assigned(sess) then Exit;

  // beginModalSession "configures" the modality and potentially is changing window level
  awin.setLevel(lvl);

  if not Assigned(Modals) then Modals := TList.Create;

  // If a modal menu has it's menu, then SetMainMenu has already been called
  // (Show is called for modal windows prior to ShowModal. Show triggers Activate and Active is doing MainMenu)
  if not hasMenu then begin
    Modals.Add( TModalSession.Create(awin, sess, MainMenuEnabled, NSApplication(NSApp).mainMenu, CurLCLMenu));
    MainMenuEnabled := false;
    ToggleAppMenu(false); // modal menu doesn't have a window, disabling it
  end else
    // if modal window has its own menu, then the prior window is rescord in "Prev" fields
    Modals.Add( TModalSession.Create(awin, sess, PrevMenuEnabled, PrevMenu, PrevLCLMenu));

  Result := true;
  inc(ModalCounter);
end;

procedure TCocoaWidgetSet.EndModal(awin: NSWindow);
var
  ms : TModalSession;
begin
  if not Assigned(Modals) or (Modals.Count = 0) then Exit;
  ms := TModalSession(Modals[Modals.Count-1]);
  if (ms.window <> awin) then Exit;
  NSApplication(NSApp).endModalSession(ms.sess);

  // restoring the menu status that was before the modality
  DoSetMainMenu(ms.cocoaMenu, ms.lclMenu);
  PrevMenuEnabled := MainMenuEnabled;
  MainMenuEnabled := ms.prevMenuEnabled;
  ToggleAppMenu(ms.prevMenuEnabled); // modal menu doesn't have a window, disabling it

  ms.Free;
  Modals.Delete(Modals.Count-1);
end;

function TCocoaWidgetSet.isTopModalWin(awin: NSWindow): Boolean;
begin
  if not isModalSession then begin
    Result := false;
    Exit;
  end;
  Result := TModalSession(Modals[Modals.Count-1]).window = awin;
end;

function TCocoaWidgetSet.isModalSession: Boolean;
begin
  Result := Assigned(Modals) and (Modals.Count > 0);
end;

procedure TCocoaWidgetSet.AddToCollect(obj: TObject);
begin
  // let's try to find an object. Do not add a duplicate
  if (ToCollect.IndexOf(Obj)>=0) then Exit;
  ToCollect.Add(obj);
end;

function TCocoaWidgetSet.RetainToCollect: Integer;
begin
  Result := ToCollect.Count;
end;

procedure TCocoaWidgetSet.ReleaseToCollect(fromIdx: integer);
var
  i  : integer;
begin
  for i := fromIdx to ToCollect.Count - 1 do
  begin
    TObject(ToCollect[i]).Free;
    ToCollect[i]:=nil;
  end;
  ToCollect.Pack;
end;

initialization
//  {$I Cocoaimages.lrs}

finalization
  InternalFinal;

end.

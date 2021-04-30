{%MainUnit gtk3int.pas}

// included by gtk3int.pas

{******************************************************************************
  All gtk3 Winapi related stuff goes here.
  This are the overrides of the Gtk3 Interface for the methods defined in the
  lcl/include/winapih.inc


  !! Keep this alphabetical !!
  
  Support routines go to gtk3proc.pp
  
 ******************************************************************************
 Interface
 ******************************************************************************

 *****************************************************************************
  This file is part of the Lazarus Component Library (LCL)

  See the file COPYING.modifiedLGPL.txt, included in this distribution,
  for details about the license.
 *****************************************************************************
}

//##apiwiz##sps##   // Do not remove, no wizard declaration before this line


function Arc(DC: HDC; Left, top, right, bottom, angle1, angle2: Integer): Boolean; override;
function AngleChord(DC: HDC; x1 ,y1, x2, y2, angle1, angle2: Integer): Boolean; override;

function BeginPaint(Handle: hWnd; Var PS : TPaintStruct) : hdc; override;
function BitBlt(DestDC: HDC; X, Y, Width, Height: Integer; SrcDC: HDC; XSrc, YSrc: Integer; Rop: DWORD): Boolean; override;

function CallNextHookEx({%H-}hHk: HHOOK; {%H-}ncode : Integer; {%H-}wParam: WParam; {%H-}lParam : LParam) : Integer; override;
function CallWindowProc({%H-}lpPrevWndFunc : TFarProc; Handle : HWND; Msg : UINT; wParam: WParam; lParam : lParam) : Integer; override;
function ClientToScreen(Handle : HWND; var P : TPoint) : Boolean;override;

// clipboard
function ClipboardFormatToMimeType(FormatID: TClipboardFormat): string; override;
function ClipboardGetData(ClipboardType: TClipboardType;
  FormatID: TClipboardFormat; Stream: TStream): boolean; override;
// ! List will be created. You must free it yourself with FreeMem(List) !
function ClipboardGetFormats(ClipboardType: TClipboardType;
  var Count: integer; var List: PClipboardFormat): boolean; override;
function ClipboardGetOwnerShip(ClipboardType: TClipboardType;
  OnRequestProc: TClipboardRequestEvent;  FormatCount: integer;
  Formats: PClipboardFormat): boolean; override;
function ClipboardRegisterFormat(const AMimeType: string): TClipboardFormat; override;

function CombineRgn(Dest, Src1, Src2 : HRGN; fnCombineMode : Longint) : Longint;  override;
function CreateBitmap(Width, Height: Integer; Planes, BitCount: Longint; BitmapBits: Pointer): HBITMAP; override;
function CreateBrushIndirect(const LogBrush: TLogBrush): HBRUSH; override;
function CreateCaret(Handle : HWND; Bitmap : hBitmap; width, Height : Integer) : Boolean; override;
function CreateCompatibleBitmap(DC: HDC; Width, Height: Integer): HBITMAP; override;
function CreateCompatibleDC({%H-}DC: HDC): HDC; override;
function CreateEllipticRgn(X1, Y1, X2, Y2: Integer): HRGN; override;
function CreateRoundRectRgn(X1, Y1, X2, Y2, nW, nH: Integer): HRGN; override;
function CreateFontIndirect(const LogFont: TLogFont): HFONT; override;
function CreateFontIndirectEx(const LogFont: TLogFont; const LongFontName: string): HFONT; override;
function CreateIconIndirect(IconInfo: PIconInfo): HICON; override;
function CreatePalette(const LogPalette: TLogPalette): HPALETTE; override;
function CreatePenIndirect(const LogPen: TLogPen): HPEN; override;
function CreatePolygonRgn(Points: PPoint; NumPts: Integer; FillMode: integer): HRGN; override;
function CreateRectRgn(X1,Y1,X2,Y2 : Integer): HRGN; override;

procedure DeleteCriticalSection(var CritSection: TCriticalSection); override;
function DeleteDC(hDC: HDC): Boolean; override;
function DeleteObject(GDIObject: HGDIOBJ): Boolean;  override;
function DestroyCaret(Handle : HWND): Boolean; override;
function DestroyCursor(Handle: HCURSOR): Boolean; override;
function DestroyIcon(Handle: HICON): Boolean; override;
function DPtoLP(DC: HDC; var Points; Count: Integer): BOOL; override;
function DrawFrameControl(DC: HDC; const aRect : TRect; uType, uState : Cardinal) : Boolean; override;
function DrawFocusRect(DC: HDC; const aRect: TRect): boolean; override;
function DrawEdge(DC: HDC; var ARect: TRect; Edge: Cardinal; grfFlags: Cardinal): Boolean; override;
function DrawText(DC: HDC; Str: PChar; Count: Integer; var Rect: TRect; Flags: Cardinal): Integer; override;

function Ellipse(DC: HDC; x1,y1,x2,y2: Integer): Boolean; override;
function EnableScrollBar({%H-}Wnd: HWND; {%H-}wSBflags, {%H-}wArrows: Cardinal): Boolean; override;
function EnableWindow(hWnd: HWND; bEnable: Boolean): Boolean; override;
function EndPaint(Handle : hwnd; var PS : TPaintStruct): Integer; override;
procedure EnterCriticalSection(var CritSection: TCriticalSection); override;
function EnumDisplayMonitors({%H-}hdc: HDC; {%H-}lprcClip: PRect; lpfnEnum: MonitorEnumProc; dwData: LPARAM): LongBool; override;
{$IFDEF GTK2OLDENUMFONTFAMILIES}
function EnumFontFamilies(DC: HDC; Family: Pchar; EnumFontFamProc: FontEnumProc; LParam:Lparam):longint; override;
{$ENDIF}
function EnumFontFamiliesEx({%H-}DC: HDC; lpLogFont: PLogFont; Callback: FontEnumExProc; Lparam: LParam; {%H-}Flags: dword): longint; override;
function EqualRgn(Rgn1: HRGN; Rgn2: HRGN): Boolean; override;
function IntersectClipRect(dc: hdc; Left, Top, Right,Bottom: Integer): Integer; override;
function ExcludeClipRect(dc: hdc; Left, Top, Right, Bottom : Integer) : Integer; override;
function ExtCreatePen(dwPenStyle, dwWidth: DWord; const lplb: TLogBrush; dwStyleCount: DWord; lpStyle: PDWord): HPEN; override;
function ExtSelectClipRGN(dc: hdc; rgn : hrgn; Mode : Longint) : Integer;  override;
function ExtTextOut(DC: HDC; X, Y: Integer; Options: Longint; Rect: PRect; Str: PChar; Count: Longint; Dx: PInteger): Boolean;  override;

function FillRect(DC: HDC; const Rect: TRect; Brush: HBRUSH): Boolean; override;
function FillRgn(DC: HDC; RegionHnd: HRGN; hbr: HBRUSH): Bool; override;
function Frame3d(DC: HDC; var ARect: TRect; const FrameWidth : integer; const Style : TBevelCut): Boolean; override;
function FrameRect(DC: HDC; const ARect: TRect; hBr: HBRUSH): Integer; override;

function HideCaret(hWnd: HWND): Boolean; override;

function GetActiveWindow : HWND; override;
function GetBitmapBits(Bitmap: HBITMAP; Count: Longint;  Bits: Pointer): Longint; override;
function GetBkColor(DC: HDC): TColorRef; override;
function GetCapture: HWND; override;
function GetCaretPos(var lpPoint: TPoint): Boolean; override;
function GetCaretRespondToFocus(handle: HWND; var ShowHideOnFocus: boolean): Boolean; override;
function GetCharABCWidths({%H-}DC: HDC; {%H-}p2, {%H-}p3: UINT; const {%H-}ABCStructs): Boolean; override;
function GetClientBounds(handle : HWND; var ARect : TRect) : Boolean; override;
function GetClientRect(handle : HWND; var ARect : TRect) : Boolean; override;
function GetClipBox(DC : hDC; lpRect : PRect) : Longint; override;
function GetClipRGN(DC : hDC; RGN : hRGN) : Longint; override;
function GetCmdLineParamDescForInterface: string; override;
function GetCurrentObject(DC: HDC; uObjectType: UINT): HGDIOBJ; override;
function GetCursorPos(var lpPoint: TPoint): Boolean; override;
function GetDC(hWnd: HWND): HDC;  override;
function GetDCOriginRelativeToWindow(PaintDC: HDC; WindowHandle: HWND; var OriginDiff: TPoint): boolean; override;
function GetDesignerDC(WindowHandle: HWND): HDC; override;
function GetDeviceCaps(DC: HDC; Index: Integer): Integer; override;
function GetDeviceSize(DC: HDC; var p: TPoint): boolean; override;
function GetDIBits(DC: HDC; Bitmap: HBitmap; StartScan, NumScans: UINT; Bits: Pointer; var BitInfo: BitmapInfo; Usage: UINT): Integer; override;
function GetDpiForMonitor(hmonitor: HMONITOR; dpiType: TMonitorDpiType; out dpiX: UINT; out dpiY: UINT): HRESULT;override;
function GetFocus: HWND; override;
function GetFontLanguageInfo(DC: HDC): DWord; override;
function GetForegroundWindow: HWND; override;
function GetKeyState(nVirtKey: Integer): Smallint; override;
function GetMapMode(DC: HDC): Integer; override;
function GetMonitorInfo(Monitor: HMONITOR; lpmi: PMonitorInfo): Boolean; override;
function GetObject(GDIObj: HGDIOBJ; BufSize: Integer; Buf: Pointer): Integer; override;
function GetParent(Handle : HWND): HWND; override;
function GetProp(Handle : hwnd; Str : PChar): Pointer; override;
function GetRgnBox(RGN : HRGN; lpRect : PRect) : Longint; override;
function GetROP2(DC: HDC): Integer; override;
function GetScrollBarSize(Handle: HWND; BarKind: Integer): integer; override;
function GetScrollbarVisible(Handle: HWND; SBStyle: Integer): boolean; override;
function GetScrollInfo(Handle: HWND; SBStyle: Integer; var ScrollInfo: TScrollInfo): Boolean; override;
function GetStockObject(Value: Integer): THandle; override;
function GetSysColor(nIndex: Integer): DWORD; override;
function GetSysColorBrush(nIndex: Integer): HBrush; override;
function GetSystemMetrics(nIndex: Integer): Integer;  override;
function GetTextColor(DC: HDC) : TColorRef; override;
function GetTextExtentPoint(DC: HDC; Str: PChar; Count: Integer; var Size: TSize): Boolean; override;
function GetTextMetrics(DC: HDC; var TM: TTextMetric): Boolean;  override;
function GetViewPortExtEx(DC: HDC; Size: PSize): Integer; override;
function GetViewPortOrgEx(DC: HDC; P: PPoint): Integer; override;
function GetWindowExtEx(DC: HDC; Size: PSize): Integer; override;
function GetWindowLong(Handle : HWND; int: Integer): PtrInt; override;
function GetWindowOrgEx(dc : hdc; P: PPoint): Integer;  override;
function GetWindowRect(Handle : hwnd; var ARect: TRect): Integer; override;
function GetWindowRelativePosition(Handle : hwnd; var Left, Top: integer): boolean; override;
function GetWindowSize(Handle : hwnd; var Width, Height: integer): boolean; override;

procedure InitializeCriticalSection(var CritSection: TCriticalSection); override;
function InvalidateRect(aHandle : HWND; Rect : pRect; bErase : Boolean) : Boolean; override;
function InvalidateRgn(Handle: HWND; Rgn: HRGN; Erase: Boolean): Boolean; override;
function IsIconic(handle: HWND): boolean; override;
function IsWindow(handle: HWND): boolean; override;
function IsWindowEnabled(handle: HWND): boolean; override;
function IsWindowVisible(handle: HWND): boolean; override;
function IsZoomed(handle: HWND): boolean; override;

procedure LeaveCriticalSection(var CritSection: TCriticalSection); override;
function LineTo(DC: HDC; X, Y: Integer): Boolean; override;
function LPtoDP(DC: HDC; var Points; Count: Integer): BOOL; override;

function MessageBox({%H-}hWnd: HWND; lpText, lpCaption: PChar; uType: Cardinal): integer; override;
function MonitorFromPoint(ptScreenCoords: TPoint; dwFlags: DWord): HMONITOR;override;
function MonitorFromWindow(hWnd: HWND; dwFlags: DWord): HMONITOR;override;
function MoveToEx(DC: HDC; X, Y: Integer; OldPoint: PPoint): Boolean; override;

function OffsetRgn(RGN: HRGN; nXOffset, nYOffset: Integer): Integer; override;

function PaintRgn(DC: HDC; RGN: HRGN): Boolean; override;
function PeekMessage(var lpMsg : TMsg; {%H-}Handle : HWND; {%H-}wMsgFilterMin, {%H-}wMsgFilterMax,wRemoveMsg : UINT): Boolean; override;
function PolyBezier(DC: HDC; Points: PPoint; NumPts: Integer; Filled, Continuous: boolean): boolean; override;
function Polygon(DC: HDC; Points: PPoint; NumPts: Integer; Winding: boolean): boolean; override;
function Polyline(DC: HDC; Points: PPoint; NumPts: Integer): boolean; override;
function PostMessage(Handle: HWND; Msg: Cardinal; wParam: WParam; lParam: LParam): Boolean; override;
function PtInRegion(RGN: HRGN; X, Y: Integer): Boolean; override;

function RadialArc(DC: HDC; left, top, right, bottom, sx, sy, ex, ey: Integer): Boolean; override;
function RadialChord(DC: HDC; x1, y1, x2, y2, sx, sy, ex, ey: Integer): Boolean; override;
function RealizePalette(DC: HDC): Cardinal; override;
function Rectangle(DC: HDC; X1, Y1, X2, Y2: Integer): Boolean; override;
function RectInRegion(RGN: HRGN; ARect: TRect): Boolean; override;
function RectVisible(dc : hdc; const ARect: TRect) : Boolean; override;
function RegroupMenuItem(hndMenu: HMENU; GroupIndex: integer): Boolean; override;
function ReleaseCapture : Boolean; override;
function ReleaseDC({%H-}hWnd: HWND; DC: HDC): Integer; override;
function RemoveProp(Handle: hwnd; Str: PChar): THandle; override;
function RestoreDC(DC: HDC; SavedDC: Integer): Boolean; override;
function RoundRect(DC : hDC; X1, Y1, X2, Y2: Integer; RX,RY : Integer): Boolean;  override;

function SaveDC(DC: HDC): Integer; override;
function ScreenToClient(Handle : HWND; var P : TPoint) : Integer; override;
function ScrollWindowEx(hWnd: HWND; dx, dy: Integer; prcScroll, prcClip: PRect; {%H-}hrgnUpdate: HRGN; prcUpdate: PRect; flags: UINT): Boolean; override;
function SelectClipRGN(DC: hDC; RGN: HRGN): Longint; override;
function SelectObject(DC: HDC; GDIObj: HGDIOBJ): HGDIOBJ;  override;
function SelectPalette({%H-}DC: HDC; {%H-}Palette: HPALETTE; {%H-}ForceBackground: Boolean): HPALETTE; override;
function SendMessage(HandleWnd: HWND; Msg: Cardinal; wParam: WParam; lParam: LParam): LResult; override;
function SetActiveWindow(Handle: HWND): HWND; override;
function SetBkColor(DC: HDC; Color: TColorRef): TColorRef; override;
function SetBkMode(DC: HDC; bkMode : Integer) : Integer; override;
function SetCapture(AHandle: HWND): HWND; override;
function SetCaretPos(X, Y: Integer): Boolean; override;
function SetCaretPosEx(Handle: HWnd; X, Y: Integer): Boolean; override;
function SetCaretRespondToFocus(handle: HWND; ShowHideOnFocus: boolean): Boolean; override;
function SetCursor(ACursor: HCURSOR): HCURSOR; override;
function SetCursorPos(X, Y: Integer): Boolean; override;
function SetFocus(hWnd: HWND): HWND; override;
function SetForegroundWindow(hWnd: HWND): boolean; override;
function SetMapMode(DC: HDC; fnMapMode : Integer): Integer; override;
function SetParent(hWndChild: HWND; hWndParent: HWND): HWND; override;
function SetProp(Handle: hwnd; Str : PChar; Data : Pointer) : Boolean; override;
function SetRectRgn(aRGN: HRGN; X1, Y1, X2, Y2 : Integer): Boolean; override;
function SetROP2(DC: HDC; Mode: Integer): Integer; override;
function SetScrollInfo(Handle : HWND; SBStyle : Integer; ScrollInfo: TScrollInfo; bRedraw : Boolean): Integer; override;
function SetSysColors(cElements: Integer; const lpaElements; const lpaRgbValues): Boolean; override;
function SetTextCharacterExtra({%H-}DC : hdc; {%H-}nCharExtra : Integer):Integer; override;
function SetTextColor(DC: HDC; Color: TColorRef): TColorRef; override;
function SetViewPortExtEx(DC: HDC; XExtent, YExtent : Integer; OldSize: PSize): Boolean; override;
function SetViewPortOrgEx(DC: HDC; NewX, NewY: Integer; OldPoint: PPoint): Boolean; override;
function SetWindowExtEx(DC: HDC; XExtent, YExtent: Integer; OldSize: PSize): Boolean; override;
function SetWindowLong(Handle: HWND; Idx: Integer; NewLong: PtrInt): PtrInt; override;
function SetWindowOrgEx(dc : hdc; NewX, NewY : Integer; OldPoint: PPoint) : Boolean; override;
function SetWindowPos(hWnd: HWND; hWndInsertAfter: HWND;
      X, Y, cx, cy: Integer; uFlags: UINT): Boolean;  override;
function SetWindowRgn(hWnd: HWND; hRgn: HRGN; bRedraw: Boolean): longint; override;
function ShowCaret(hWnd: HWND): Boolean; override;
function ShowScrollBar(Handle: HWND; wBar: Integer; bShow: Boolean): Boolean; override;
function ShowWindow(hWnd: HWND; nCmdShow: Integer): Boolean; override;
function StretchBlt(DestDC: HDC; X, Y, Width, Height: Integer; SrcDC: HDC; XSrc, YSrc, SrcWidth, SrcHeight: Integer; ROp: Cardinal): Boolean; override;
function StretchMaskBlt(DestDC: HDC; X, Y, Width, Height: Integer; SrcDC: HDC; XSrc, YSrc, SrcWidth, SrcHeight: Integer; Mask: HBITMAP; XMask, YMask: Integer; Rop: DWORD): Boolean; override;
function SystemParametersInfo(uiAction: DWord; {%H-}uiParam: DWord; pvParam: Pointer; {%H-}fWinIni: DWord): LongBool; override;

function TextOut(DC: HDC; X,Y : Integer; Str : Pchar; Count: Integer) : Boolean; override;

function UpdateWindow(Handle: HWND): Boolean; override;

function WindowFromPoint(APoint: TPoint): HWND; override;

//##apiwiz##eps##   // Do not remove, no wizard declaration after this line

// included by gtk3int.pas

{
 *****************************************************************************
 *                             gtk3objects.pas                               *
 *                             -----------------                             *
 *                                                                           *
 *                                                                           *
 *****************************************************************************

 *****************************************************************************
  This file is part of the Lazarus Component Library (LCL)

  See the file COPYING.modifiedLGPL.txt, included in this distribution,
  for details about the license.
 *****************************************************************************
}
unit gtk3objects;
{$i gtk3defines.inc}
{$mode objfpc}
{$H+}

interface

uses
  Classes, SysUtils, Types, math, FPCanvas,
  // LazUtils
  LazUTF8, IntegerList, LazStringUtils,
  // LCL
  LCLType, LCLProc, Graphics,
  LazGtk3, LazGdk3, LazGObject2, LazGLib2, LazGdkPixbuf2,
  LazPango1, LazPangoCairo1, LazCairo1, gtk3procs;

type
  TGtk3DeviceContext = class;

  { TGtk3Object }

  TGtk3Object = class(TObject)
  private
    FUpdateCount: Integer;
  public
    constructor Create; virtual; overload;
    procedure Release; virtual;
    procedure BeginUpdate; virtual;
    procedure EndUpdate; virtual;
    function InUpdate: Boolean;
  end;

  { TGtk3ContextObject }

  TGtk3ContextObject = class(TGtk3Object)
  private
    FShared: Boolean;
    fContext:TGtk3DeviceContext;
  public
    constructor Create; override;
    function Select(ACtx:TGtk3DeviceContext):TGtk3ContextObject;virtual;
    function Get(szbuf:integer;pbuf:pointer):integer;virtual;abstract;
    property Shared: Boolean read FShared write FShared;
  end;

  { TGtk3Font }

  TGtk3Font = class(TGtk3ContextObject)
  private
    FLayout: PPangoLayout;
    FLogFont: TLogFont;
    FFontName: String;
    FHandle: PPangoFontDescription;
  public
    constructor Create(ACairo: Pcairo_t; AWidget: PGtkWidget = nil);
    constructor Create(ALogFont: TLogFont; const ALongFontName: String);
    function Select(ACtx:TGtk3DeviceContext):TGtk3ContextObject;override;
    function Get(szbuf:integer;pbuf:pointer):integer;override;
    destructor Destroy; override;
    procedure UpdateLogFont;
    property FontName: String read FFontName write FFontName;
    property Handle: PPangoFontDescription read FHandle;
    property Layout: PPangoLayout read FLayout;
    property LogFont: TLogFont read FLogFont;
  end;

  { TGtk3Brush }

  TGtk3Brush = class(TGtk3ContextObject)
  private
    FColor: TColor;
    FStyle: LongWord;
    procedure SetColor(AValue: TColor);
    procedure SetStyle(AStyle:longword);
  public
    brush_pattern:pcairo_pattern_t;
    pat_buf:pdword;
    LogBrush: TLogBrush;
    constructor Create; override;
    function Select(ACtx:TGtk3DeviceContext):TGtk3ContextObject;override;
    function Get(szbuf:integer;pbuf:pointer):integer;override;
    destructor Destroy;override;
    procedure UpdatePattern;
    property Color: TColor read FColor write SetColor;
    property Context: TGtk3DeviceContext read FContext write FContext;
    property Style: LongWord read FStyle write SetStyle;
  end;

  { TGtk3Pen }

  TGtk3Pen = class(TGtk3ContextObject)
  private
    FCosmetic: Boolean;
    FEndCap: TPenEndCap;
    FJoinStyle: TPenJoinStyle;
    FPenMode: TPenMode;
    FStyle: TFPPenStyle;
    FWidth: Integer;
    FColor: TColor;
    FIsExtPen: Boolean;
    procedure SetColor(AValue: TColor);
    procedure setCosmetic(b: Boolean);
    procedure setWidth(p1: Integer);
  public
    LogPen: TLogPen;
    constructor Create; override;
    function Select(ACtx:TGtk3DeviceContext):TGtk3ContextObject;override;
    function Get(szbuf:integer;pbuf:pointer):integer;override;
    property Color: TColor read FColor write SetColor;
    property Context: TGtk3DeviceContext read FContext write FContext;

    property Cosmetic: Boolean read FCosmetic write SetCosmetic;
    property EndCap: TPenEndCap read FEndCap write FEndCap;
    property IsExtPen: Boolean read FIsExtPen write FIsExtPen;
    property JoinStyle: TPenJoinStyle read FJoinStyle write FJoinStyle;
    property Mode: TPenMode read FPenMode write FPenMode;
    property Style: TFPPenStyle read FStyle write FStyle;
    property Width: Integer read FWidth write SetWidth;
  end;

  { TGtk3Region }

  TGtk3Region = class(TGtk3ContextObject)
  private
    FHandle: Pcairo_region_t;
  public
    property Handle: Pcairo_region_t read FHandle write FHandle;
    constructor Create({%H-}CreateHandle: Boolean); virtual; overload;
    constructor Create({%H-}CreateHandle: Boolean; X1,Y1,X2,Y2: Integer); virtual; overload;
    constructor Create(X1,Y1,X2,Y2,nW,nH: Integer); virtual; overload;
    constructor CreateEllipse(X1,Y1,X2,Y2: Integer); virtual; overload;
    function Select(ACtx:TGtk3DeviceContext):TGtk3ContextObject;override;
    function Get(szbuf:integer;pbuf:pointer):integer;override;
    destructor Destroy; override;
    function GetExtents: TRect;
    function ContainsRect(ARect: TRect): Boolean;
    function ContainsPoint(APoint: TPoint): Boolean;
  end;

  { TGtk3Image }

  TGtk3Image = class(TGtk3ContextObject)
  private
    FData: PByte;
    FDataOwner: Boolean;
    FHandle: PGdkPixbuf;
    FFormat : cairo_format_t;
  public
    constructor Create; override;
    constructor Create(vHandle: PGdkPixbuf); overload;
    constructor Create(AData: PByte; width: Integer; height: Integer; format: cairo_format_t; const ADataOwner: Boolean = False); overload;
    constructor Create(AData: PByte; width: Integer; height: Integer; bytesPerLine: Integer; format: cairo_format_t; const ADataOwner: Boolean = False); overload;
    function Select(ACtx:TGtk3DeviceContext):TGtk3ContextObject;override;
    function Get(szbuf:integer;pbuf:pointer):integer;override;
    destructor Destroy; override;
    procedure CopyFrom(AImage: PGdkPixbuf; x, y, w, h: integer);
    function height: Integer;
    function width: Integer;
    function depth: Integer;
    function dotsPerMeterX: Integer;
    function dotsPerMeterY: Integer;
    function bits: PByte;
    function numBytes: LongWord;
    function bytesPerLine: Integer;
    property Format: cairo_format_t read FFormat;
    property Handle: PGdkPixbuf read FHandle;
  end;

  { TGtk3Cursor }

  TGtk3Cursor = class(TGtk3Object)
  private
    fHandle:PGdkCursor;
  public
    constructor Create(ACur:integer);overload;
    constructor Create(pixbuf:PGdkPixbuf;x,y:gint);overload;
    constructor Create(img:TGtk3Image);overload;
    destructor Destroy;override;
    property Handle:PGdkCursor read fHandle;
  end;

  { TGtk3DeviceContext }

  TGtk3DeviceContext = class (TGtk3Object)
  private
    FBrush: TGtk3Brush;
    FFont: TGtk3Font;
    FvImage: TGtk3Image;
    FCanRelease: Boolean;
    FCurrentBrush: TGtk3Brush;
    FCurrentFont: TGtk3Font;
    FCurrentImage: TGtk3Image;
    FCurrentTextColor: TColorRef;
    FCurrentRegion: TGtk3Region;
    FOwnsCairo: Boolean;
    FOwnsSurface: Boolean;
    FPen: TGtk3Pen;
    FvClipRect: TRect;
    FCurrentPen: TGtk3Pen;
    FBkMode: Integer;
    function GetOffset: TPoint;
    procedure setBrush(AValue: TGtk3Brush);
    procedure SetFont(AValue: TGtk3Font);
    procedure SetOffset(AValue: TPoint);
    procedure setPen(AValue: TGtk3Pen);
    procedure SetvImage(AValue: TGtk3Image);
    function SX(const x: double): Double;
    function SY(const y: double): Double;
    function SX2(const x: double): Double;
    function SY2(const y: double): Double;
    procedure ApplyBrush;
    procedure ApplyFont;
    procedure ApplyPen;
    procedure FillAndStroke;
  public
    CairoSurface: Pcairo_surface_t;
    pcr: Pcairo_t;
    Parent: PGtkWidget;
    Window: PGdkWindow;
    ParentPixmap: PGdkPixbuf;
    fncOrigin:TPoint; // non-client area offsets surface origin
    constructor Create(AWidget: PGtkWidget; const APaintEvent: Boolean = False); virtual;
    constructor Create(AWindow: PGdkWindow; const APaintEvent: Boolean); virtual;
    constructor CreateFromCairo(AWidget: PGtkWidget; ACairo: PCairo_t); virtual;
    destructor Destroy; override;
    procedure CreateObjects;
    procedure DeleteObjects;
  public
    procedure drawPixel(x, y: Integer; AColor: TColor);
    function getPixel(x, y: Integer): TColor;
    procedure drawRect(x1, y1, w, h: Integer; const AFill, ABorder: Boolean);
    procedure drawRoundRect(x, y, w, h, rx, ry: Integer);
    procedure drawText(x, y: Integer; AText: PChar; ALen: Integer);
    procedure drawEllipse(x, y, w, h: Integer; AFill, ABorder: Boolean);
    procedure drawSurface(targetRect: PRect; Surface: Pcairo_surface_t; sourceRect: PRect;
      mask: PGdkPixBuf; maskRect: PRect);
    procedure drawImage(targetRect: PRect; image: PGdkPixBuf; sourceRect: PRect;
      mask: PGdkPixBuf; maskRect: PRect);
    procedure drawImage1(targetRect: PRect; image: PGdkPixBuf; sourceRect: PRect;
      mask: PGdkPixBuf; maskRect: PRect);
    procedure drawPixmap(p: PPoint; pm: PGdkPixbuf; sr: PRect);
    procedure drawPolyLine(P: PPoint; NumPts: Integer);
    procedure drawPolygon(P: PPoint; NumPts: Integer; FillRule: Integer; AFill,
      ABorder: Boolean);
    procedure drawPolyBezier(P: PPoint; NumPoints: Integer; Filled, Continuous: boolean);
    procedure EllipseArcPath(CX, CY, RX, RY: Double; Angle1, Angle2: Double; Clockwise, Continuous: Boolean);
    procedure eraseRect(ARect: PRect);
    procedure fillRect(ARect: PRect; ABrush: HBRUSH); overload;
    procedure fillRect(x, y, w, h: Integer; ABrush: HBRUSH); overload;
    procedure fillRect(x, y, w, h: Integer); overload;
    function RoundRect(X1, Y1, X2, Y2: Integer; RX, RY: Integer): Boolean;
    function drawFrameControl(arect:TRect;uType,uState:cardinal):boolean;
    function drawFocusRect(const aRect: TRect): boolean;
    function getBpp: integer;
    function getDepth: integer;
    function getDeviceSize: TPoint;
    function LineTo(X, Y: Integer): Boolean;
    function MoveTo(const X, Y: Integer; OldPoint: PPoint): Boolean;
    function SetClipRegion(ARgn: TGtk3Region): Integer;
    procedure SetSourceColor(AColor: TColor);
    procedure SetImage(AImage: TGtk3Image);
    function ResetClip: Integer;
    procedure TranslateCairoToDevice;
    procedure Translate(APoint: TPoint);
    procedure set_antialiasing(aamode:boolean);
    property BkMode: Integer read FBkMode write FBkMode;
    property CanRelease: Boolean read FCanRelease write FCanRelease;
    property CurrentBrush: TGtk3Brush read FCurrentBrush write FCurrentBrush;
    property CurrentFont: TGtk3Font read FCurrentFont write FCurrentFont;
    property CurrentImage: TGtk3Image read FCurrentImage write FCurrentImage;
    property CurrentPen: TGtk3Pen read FCurrentPen write FCurrentPen;
    property CurrentRegion: TGtk3Region read FCurrentRegion;
    property CurrentTextColor: TColorRef read FCurrentTextColor write FCurrentTextColor;
    property Offset: TPoint read GetOffset write SetOffset;
    property OwnsSurface: Boolean read FOwnsSurface;
    property vBrush: TGtk3Brush read FBrush write setBrush;
    property vClipRect: TRect read FvClipRect write FvClipRect;
    property vFont: TGtk3Font read FFont write SetFont;
    property vImage: TGtk3Image read FvImage write SetvImage;
    property vPen: TGtk3Pen read FPen write setPen;
  end;

function CheckBitmap(const ABitmap: HBITMAP; const AMethodName: String;
  const AParamName: String = ''): Boolean;
procedure Gtk3WordWrap(DC: HDC; AText: PChar;
  MaxWidthInPixel: integer; out Lines: PPChar; out LineCount: integer);

function Gtk3DefaultContext: TGtk3DeviceContext;
function Gtk3ScreenContext: TGtk3DeviceContext;

function ReplaceAmpersandsWithUnderscores(const S: string): string; inline;

implementation

uses gtk3int,controls;

const
  PixelOffset = 0.5; // Cairo API needs 0.5 pixel offset to not make blurry lines

const
  Dash_Dash:        array [0..1] of double = (18, 6);             //____ ____
  Dash_Dot:         array [0..1] of double = (3, 3);              //.........
  Dash_DashDot:     array [0..3] of double = (9, 6, 3, 6);        //__ . __ .
  Dash_DashDotDot:  array [0..5] of double = (9, 3, 3, 3, 3, 3);  //__ . . __

var
  FDefaultContext: TGtk3DeviceContext = nil;
  FScreenContext: TGtk3DeviceContext = nil;

  function create_stipple(stipple_data:pbyte;width,height:integer):pcairo_pattern_t;forward;

  const clr_A = $FF008000;// $3093BA52;
  const clr_B = $FFFFFFFF;// $30FFFFFF;

  const
        (* the stipple patten should look like that
         *	    1 1 1 0  0 0 0 1
         *	    1 1 0 0  0 0 1 1
         *	    1 0 0 0  0 1 1 1
         *	    0 0 0 0  1 1 1 1
         *
         *	    0 0 0 1  1 1 1 0
         *	    0 0 1 1  1 1 0 0
         *	    0 1 1 1  1 0 0 0
         *	    1 1 1 1  0 0 0 0
         *)

       stipple_bdiag: array[0..8 * 8-1] of dword = (
            clr_A, clr_A, clr_A, clr_B, clr_B, clr_B, clr_B, clr_A,
            clr_A, clr_A, clr_B, clr_B, clr_B, clr_B, clr_A, clr_A,
            clr_A, clr_B, clr_B, clr_B, clr_B, clr_A, clr_A, clr_A,
            clr_B, clr_B, clr_B, clr_B, clr_A, clr_A, clr_A, clr_A,
            //-----------------------------------------------------
            clr_B, clr_B, clr_B, clr_A, clr_A, clr_A, clr_A, clr_B,
            clr_B, clr_B, clr_A, clr_A, clr_A, clr_A, clr_B, clr_B,
            clr_B, clr_A, clr_A, clr_A, clr_A, clr_B, clr_B, clr_B,
            clr_A, clr_A, clr_A, clr_A, clr_B, clr_B, clr_B, clr_B);

        stipple_fdiag: array[0..8 * 8-1] of dword = (
            clr_A, clr_A, clr_A, clr_A, clr_B, clr_B, clr_B, clr_B,
            clr_B, clr_A, clr_A, clr_A, clr_A, clr_B, clr_B, clr_B,
            clr_B, clr_B, clr_A, clr_A, clr_A, clr_A, clr_B, clr_B,
            clr_B, clr_B, clr_B, clr_A, clr_A, clr_A, clr_A, clr_B,
            //-----------------------------------------------------
            clr_B, clr_B, clr_B, clr_B, clr_A, clr_A, clr_A, clr_A,
            clr_A, clr_B, clr_B, clr_B, clr_B, clr_A, clr_A, clr_A,
            clr_A, clr_A, clr_B, clr_B, clr_B, clr_B, clr_A, clr_A,
            clr_A, clr_A, clr_A, clr_B, clr_B, clr_B, clr_B, clr_A);



       //bsHorizontal
       stipple_horz: array[0..15] of dword = (
          clr_B, clr_B, clr_B, clr_B,
          clr_B, clr_B, clr_B, clr_B,
          clr_B, clr_B, clr_B, clr_B,
          clr_A, clr_A, clr_A, clr_A
       );

       stipple_vert: array[0..15] of dword = (
          clr_A, clr_B, clr_B, clr_B,
          clr_A, clr_B, clr_B, clr_B,
          clr_A, clr_B, clr_B, clr_B,
          clr_A, clr_B, clr_B, clr_B
       );

      (* , bsVertical, bsFDiagonal,
                   bsBDiagonal, bsCross, bsDiagCross, bsImage, bsPattern);*)


       stipple_cross0: array[0..8] of dword = (
          clr_B, clr_A, clr_B,
          clr_A, clr_A, clr_A,
          clr_B, clr_A, clr_B
       );

       stipple_cross1: array[0..63] of dword = (
          clr_B, clr_B, clr_B, clr_A, clr_A, clr_B, clr_B, clr_B,
          clr_B, clr_B, clr_B, clr_A, clr_A, clr_B, clr_B, clr_B,
          clr_B, clr_B, clr_B, clr_A, clr_A, clr_B, clr_B, clr_B,
          clr_A, clr_A, clr_A, clr_A, clr_A, clr_A, clr_A, clr_A,
          clr_A, clr_A, clr_A, clr_A, clr_A, clr_A, clr_A, clr_A,
          clr_B, clr_B, clr_B, clr_A, clr_A, clr_B, clr_B, clr_B,
          clr_B, clr_B, clr_B, clr_A, clr_A, clr_B, clr_B, clr_B,
          clr_B, clr_B, clr_B, clr_A, clr_A, clr_B, clr_B, clr_B
       );

       stipple_dcross0: array[0..8] of dword = (
          clr_A, clr_B, clr_A,
          clr_B, clr_A, clr_B,
          clr_A, clr_B, clr_A
       );

       stipple_dcross: array[0..63] of dword = (
          clr_A, clr_B, clr_B, clr_B, clr_B, clr_B, clr_B, clr_A,
          clr_A, clr_A, clr_B, clr_B, clr_B, clr_B, clr_A, clr_A,
          clr_B, clr_A, clr_A, clr_B, clr_B, clr_A, clr_A, clr_B,
          clr_B, clr_B, clr_A, clr_A, clr_A, clr_A, clr_B, clr_B,
          //----------------------------------------------------
          clr_B, clr_B, clr_B, clr_A, clr_A, clr_B, clr_B, clr_B,
          clr_B, clr_B, clr_A, clr_A, clr_A, clr_A, clr_B, clr_B,
          clr_B, clr_A, clr_A, clr_B, clr_B, clr_A, clr_A, clr_B,
          clr_A, clr_A, clr_B, clr_B, clr_B, clr_B, clr_A, clr_A
       );

function Gtk3DefaultContext: TGtk3DeviceContext;
begin
  if FDefaultContext = nil then
    FDefaultContext := TGtk3DeviceContext.Create(PGtkWidget(nil), False);
  Result := FDefaultContext;
end;

function Gtk3ScreenContext: TGtk3DeviceContext;
begin
  if FScreenContext = nil then
    FScreenContext := TGtk3DeviceContext.Create(gdk_get_default_root_window, False);
  Result := FScreenContext;
end;

{------------------------------------------------------------------------------
  Name:    CheckBitmap
  Params:  Bitmap      - Handle to a bitmap (TGtk3Image)
           AMethodName - Method name
           AParamName  - Param name
  Returns: If the bitmap is valid
 ------------------------------------------------------------------------------}
function CheckBitmap(const ABitmap: HBITMAP; const AMethodName: String;
  const AParamName: String): Boolean;
begin
  Result := TObject(ABitmap) is TGtk3Image;
  if Result then Exit;

  if Pos('.', AMethodName) = 0 then
    DebugLn('Gtk3WidgetSet ' + AMethodName + ' Error - invalid bitmap ' +
      AParamName + ' = ' + DbgS(ABitmap) + '!')
  else
    DebugLn(AMethodName + ' Error - invalid bitmap ' + AParamName + ' = ' +
      DbgS(ABitmap) + '!');
end;

procedure TColorToRGB(AColor: TColor; out R, G, B: double);
begin
  R := (AColor and $FF) / 255;
  G := ((AColor shr 8) and $FF) / 255;
  B := ((AColor shr 16) and $FF) / 255;
end;

{ TGtk3Cursor }

constructor TGtk3Cursor.Create(ACur:integer);
var gdk_cur:integer;
begin
  case ACur of
  crArrow: gdk_cur:=GDK_ARROW;
  else
    gdk_cur:=GDK_ARROW;
  end;

  Fhandle:=TGdkCursor.new(gdk_cur);
end;

constructor TGtk3Cursor.Create(pixbuf: PGdkPixbuf;x,y:gint);
begin
  fHandle:=TGdkCursor.new_from_pixbuf(TGdkDisplay.get_default(),pixbuf,x,y);
end;

constructor TGtk3Cursor.Create(img: TGtk3Image);
var w,h:gint;
begin
  inherited Create;
  w:=img.width;
  h:=img.height;
  Create(img.Handle,w,h);
end;

destructor TGtk3Cursor.Destroy;
begin
  PGdkCursor(fHandle)^.unref();
  inherited Destroy;
end;

{ TGtk3ContextObject }

constructor TGtk3ContextObject.Create;
begin
  inherited Create;
  FShared := False;
end;

function TGtk3ContextObject.Select(ACtx:TGtk3DeviceContext): TGtk3ContextObject;
begin
  DbgS('Default context object selected, please implement');
  Result:=nil;
end;

{ TGtk3Region }

constructor TGtk3Region.Create(CreateHandle: Boolean);
begin
  inherited Create;
  FHandle := cairo_region_create;
end;

constructor TGtk3Region.Create(CreateHandle: Boolean; X1, Y1, X2, Y2: Integer);
var
  ARect: Tcairo_rectangle_int_t;
begin
  inherited Create;
  FHandle := nil;
  ARect.x := x1;
  ARect.y := y1;
  ARect.width := x2 - x1;
  ARect.height := y2 - y1;
  FHandle := cairo_region_create_rectangle(@ARect);
end;

constructor TGtk3Region.Create(X1,Y1,X2,Y2,nW,nH: Integer);
var
  ASurface: pcairo_surface_t;
  cr:Pcairo_t;
  rr:double;
  w,h:integer;
begin
  inherited Create;
  FHandle := nil;
  w:=x2-x1;
  h:=y2-y1;
  rr:=nW/2;

  ASurface := cairo_image_surface_create(CAIRO_FORMAT_ARGB32, w, h);
  cr:=cairo_create(ASurface);
  try
    cairo_new_path(cr);

    cairo_move_to(cr,x1,y2-rr);
    cairo_line_to(cr,x1,y1+rr);
    cairo_arc(cr,x1 + rr, y1 + rr, rr, pi, 3*pi/2);
    cairo_line_to(cr,x2-rr,y1);
    cairo_arc(cr,x2 - rr, y1 + rr, rr, 3*pi/2, 0);
    cairo_line_to(cr,x2,y2-rr);
    cairo_arc(cr,x2 - rr, y2 - rr, rr, 0, pi/2);
    cairo_line_to(cr,x1-rr,y2);
    cairo_arc(cr,x1 + rr, y2 - rr, rr, pi/2, pi);

    cairo_close_path(cr);
    cairo_set_source_rgba(cr,1,1,1,1);
    cairo_fill_preserve(cr);

    FHandle := gdk_cairo_region_create_from_surface(ASurface);
  finally
    cairo_destroy(cr);
    cairo_surface_destroy(ASurface);
  end;
end;

constructor TGtk3Region.CreateEllipse(X1,Y1,X2,Y2: Integer);
var
  ASurface: pcairo_surface_t;
  cr:Pcairo_t;
  w,h:integer;
  save_matrix:cairo_matrix_t;
begin
  inherited Create;
  FHandle := nil;
  w:=x2-x1;
  h:=y2-y1;

  ASurface := cairo_image_surface_create(CAIRO_FORMAT_ARGB32, w, h);
  cr:=cairo_create(ASurface);
  try
    cairo_save(cr);
    try
      cairo_get_matrix(cr, @save_matrix);
      cairo_translate (cr, x1 + w / 2.0 + PixelOffset, y1 + h / 2.0 + PixelOffset);
      cairo_scale (cr, w / 2.0, h / 2.0);
      cairo_new_path(cr);
      cairo_arc
          (
            (*cr =*) cr,
            (*xc =*) 0,
            (*yc =*) 0,
            (*radius =*) 1,
            (*angle1 =*) 0,
            (*angle2 =*) 2 * Pi
          );
      cairo_close_path(cr);
      cairo_set_source_rgba(cr,1,1,1,1);
      cairo_fill_preserve(cr);
    finally
      cairo_restore(cr);
    end;
    FHandle := gdk_cairo_region_create_from_surface(ASurface);
  finally
    cairo_destroy(cr);
    cairo_surface_destroy(ASurface);
  end;
end;

function TGtk3Region.Select(ACtx: TGtk3DeviceContext): TGtk3ContextObject;
begin
  fContext:=ACtx;
  if not Assigned(fContext) then exit(nil);
  fContext.setClipRegion(Self);
  Result:=Self;
end;

function TGtk3Region.Get(szbuf: integer; pbuf: pointer): integer;
begin
  Result:=0;
end;

destructor TGtk3Region.Destroy;
begin
  if Assigned(FHandle) then
  begin
    cairo_region_destroy(FHandle);
    FHandle := nil;
  end;
  inherited Destroy;
end;

function TGtk3Region.GetExtents: TRect;
var
  ARect: Tcairo_rectangle_int_t;
begin
  Result := Rect(0, 0, 0, 0);
  if Assigned(FHandle) then
  begin
    cairo_region_get_extents(FHandle, @ARect);
    Result.Left := ARect.x;
    Result.Top := ARect.y;
    Result.Right := ARect.width + ARect.x;
    Result.Bottom := ARect.height + ARect.y;
  end;
end;

function TGtk3Region.ContainsRect(ARect: TRect): Boolean;
var
  ACairoRect: Tcairo_rectangle_int_t;
begin
  with ACairoRect do
  begin
    x := ARect.Left;
    y := ARect.Top;
    width := ARect.Right - ARect.Left;
    height := ARect.Bottom - ARect.Top;
  end;
  Result := cairo_region_contains_rectangle(FHandle, @ACairoRect) = CAIRO_REGION_OVERLAP_IN;
end;

function TGtk3Region.ContainsPoint(APoint: TPoint): Boolean;
begin
  Result := cairo_region_contains_point(FHandle, APoint.x, APoint.y);
end;

{ TGtk3Font }

procedure TGtk3Font.UpdateLogFont;
var
  sz:integer;
  members:TPangoFontMask;
  AStyle: TPangoStyle;
  AGravity: TPangoGravity;
begin
  if not Assigned(fHandle) then exit;
  fillchar(fLogFont,sizeof(fLogFont),0);
  members:=fHandle^.get_set_fields;
  if (PANGO_FONT_MASK_FAMILY and members<>0) then
  begin
    fLogFont.lfFaceName:=PChar(fHandle^.get_family);
  end;
  if (PANGO_FONT_MASK_STYLE and members<>0) then
  begin
    AStyle := fHandle^.get_style;
    if AStyle = PANGO_STYLE_ITALIC then
      fLogFont.lfItalic:=1;
  end;
  if (PANGO_FONT_MASK_WEIGHT and members<>0) then
  begin
    fLogFont.lfWeight:=fHandle^.get_weight();
  end;
  if (PANGO_FONT_MASK_GRAVITY and members<>0) then
  begin
    AGravity := fHandle^.get_gravity;
    if AGravity = PANGO_GRAVITY_SOUTH then
      fLogFont.lfOrientation := 0
    else
    if AGravity = PANGO_GRAVITY_EAST then
      fLogFont.lfOrientation := 900
    else
    if AGravity = PANGO_GRAVITY_NORTH then
      fLogFont.lfOrientation := 1800
    else
    if AGravity = PANGO_GRAVITY_WEST then
      fLogFont.lfOrientation := 2700;
  end;
  if (PANGO_FONT_MASK_SIZE and members<>0) then
  begin
    sz:=fHandle^.get_size;
    if fHandle^.get_size_is_absolute then
    begin
      sz:= PANGO_PIXELS(sz);
    end else
    begin
      { in points }
      //sz:=round(96*sz/PANGO_SCALE/72);//round(2.03*sz/PANGO_SCALE);
      sz := MulDiv(PANGO_PIXELS(sz), 96{Screen.PixelsPerInch}, 72 )
    end;

    fLogFont.lfHeight:=sz;//round(sz/PANGO_SCALE);
  end;
end;

constructor TGtk3Font.Create(ACairo: Pcairo_t; AWidget: PGtkWidget);
var
  AContext: PPangoContext;
  AOwnsContext: Boolean;
begin
  inherited Create;
  AOwnsContext := not Gtk3IsWidget(AWidget);
  if not AOwnsContext then
  begin
    AContext := gtk_widget_get_pango_context(AWidget);
    // DebugLn('TGtk3Font.Create AContext created from widget ....context=',dbgHex(PtrUInt(AContext)));
  end else
  begin
    AContext := pango_cairo_create_context(ACairo);
    // DebugLn('TGtk3Font.Create AContext created from pango cairo ....');
  end;
  FHandle := pango_font_description_copy(pango_context_get_font_description(AContext));
  FFontName := pango_font_description_get_family(FHandle);

  FLayout := pango_layout_new(AContext);
  if FHandle^.get_size_is_absolute then
  begin
    FHandle^.set_absolute_size(FHandle^.get_size);
    // writeln('**TGtk3Font.Create size is absolute ',FFontName,' size ',FHandle^.get_size);
  end else
  begin
    FHandle^.set_size(FHandle^.get_size);
    // writeln('*TGtk3Font.Create size is not absolute ',FFontName,' size ',FHandle^.get_size);
  end;

  FLayout^.set_font_description(FHandle);
  // writeln('TGtk3Font.Create1 ',FFontName);
  if AOwnsContext then
    g_object_unref(AContext);
  // writeln('TGtk3Font.Create1 ',FFontName);
end;

constructor TGtk3Font.Create(ALogFont: TLogFont; const ALongFontName: String);
var
  AContext: PPangoContext;
  AttrList: PPangoAttrList;
  Attr: PPangoAttribute;
begin
  FLogFont := ALogFont;
  FFontName := ALogFont.lfFaceName;
  AContext := gdk_pango_context_get;
  if IsFontNameDefault(FFontName) or (FFontName = '') then
  begin
    if Gtk3WidgetSet.DefaultAppFontName <> '' then
      FHandle := pango_font_description_from_string(PgChar(Gtk3WidgetSet.DefaultAppFontName))
    else
      FHandle := pango_font_description_copy(pango_context_get_font_description(AContext));
  end else
    FHandle := pango_font_description_from_string(PgChar(FFontName));
  FFontName := FHandle^.get_family;
  if ALogFont.lfHeight <> 0 then
    FHandle^.set_absolute_size(Abs(ALogFont.lfHeight) * PANGO_SCALE);
  if ALogFont.lfItalic > 0 then
    FHandle^.set_style(PANGO_STYLE_ITALIC);
  FHandle^.set_weight(ALogFont.lfWeight);
  FLayout := pango_layout_new(AContext);
  FLayout^.set_font_description(FHandle);

  if (ALogFont.lfUnderline<>0) or (ALogFont.lfStrikeOut<>0) then
  begin
    AttrList := pango_layout_get_attributes(FLayout);
    if (AttrList = nil) then
      AttrList := pango_attr_list_new();
    if ALogFont.lfUnderline <> 0 then
      Attr := pango_attr_underline_new(PANGO_UNDERLINE_SINGLE)
    else
      Attr := pango_attr_underline_new(PANGO_UNDERLINE_NONE);
    pango_attr_list_change(AttrList, Attr);

    Attr := pango_attr_strikethrough_new(ALogFont.lfStrikeOut<>0);
    pango_attr_list_change(AttrList, Attr);
    pango_layout_set_attributes(FLayout, AttrList);
    pango_attr_list_unref(AttrList);
  end;
  g_object_unref(AContext);
end;

function TGtk3Font.Select(ACtx:TGtk3DeviceContext): TGtk3ContextObject;
begin
  fContext:=ACtx;
  if not Assigned(fContext) then exit(nil);
  Result := fContext.CurrentFont;
  fContext.CurrentFont:= Self;
end;

function TGtk3Font.Get(szbuf: integer; pbuf: pointer): integer;
begin
  Result:=sizeof(Self.LogFont);
  if pbuf=nil then exit;
  Self.UpdateLogFont;
  move(LogFont,pbuf^,min(szbuf,Result));
end;

destructor TGtk3Font.Destroy;
begin
  if Assigned(FLayout) then
  begin
    g_object_unref(FLayout);
    FLayout := nil;
  end;
  if Assigned(FHandle) then
  begin
    pango_font_description_free(FHandle);
    FHandle := nil;
  end;
  inherited Destroy;
end;

{ TGtk3Object }

constructor TGtk3Object.Create;
begin
  FUpdateCount := 0;
end;

procedure TGtk3Object.Release;
begin
  Free;
end;

procedure TGtk3Object.BeginUpdate;
begin
  inc(FUpdateCount);
end;

procedure TGtk3Object.EndUpdate;
begin
  if FUpdateCount > 0 then
    dec(FUpdateCount);
end;

function TGtk3Object.InUpdate: Boolean;
begin
  Result := FUpdateCount > 0;
end;

{ TGtk3Image }

constructor TGtk3Image.Create;
var
  ACairo: Pcairo_t;
  ASurface: Pcairo_surface_t;
  ARect: TGdkRectangle;
begin
  {$IFDEF VerboseGtk3DeviceContext}
    DebugLn('TGtk3Image.Create 1');
  {$ENDIF}
  inherited Create;
  ACairo := gdk_cairo_create(gdk_get_default_root_window);
  gdk_cairo_get_clip_rectangle(ACairo, @ARect);
  ASurface := cairo_image_surface_create(CAIRO_FORMAT_ARGB32, ARect.width, ARect.height);
  try
    FHandle := gdk_pixbuf_get_from_surface(ASurface, 0 ,0, ARect.Width, ARect.Height);
  finally
    cairo_surface_destroy(ASurface);
  end;
  FData := nil;
  FDataOwner := False;
  FFormat := CAIRO_FORMAT_ARGB32;
end;

constructor TGtk3Image.Create(vHandle: PGdkPixbuf);
begin
  {$IFDEF VerboseGtk3DeviceContext}
    DebugLn('TGtk3Image.Create 2 vHandle=',dbgs(vHandle),' channels ',dbgs(vHandle^.get_n_channels),' bps ',dbgs(vHandle^.get_bits_per_sample),' has_alpha=',dbgs(vHandle^.get_has_alpha));
  {$ENDIF}
  inherited Create;
  FHandle := vHandle^.copy;
  FData := nil;
  FDataOwner := False;

  if FHandle^.get_has_alpha then
    FFormat := CAIRO_FORMAT_ARGB32
  else
    FFormat := CAIRO_FORMAT_RGB24;
end;

constructor TGtk3Image.Create(AData: PByte; width: Integer; height: Integer;
  format: cairo_format_t; const ADataOwner: Boolean);
var
  ASurface: Pcairo_surface_t;
  w,h: Integer;
begin
  {$IFDEF VerboseGtk3DeviceContext}
  DebugLn('TGtk3Image.Create 3 AData=',dbgs(AData <> nil),' format=',dbgs(Ord(format)),' w=',dbgs(width),' h=',dbgs(height),' dataowner=',dbgs(ADataOwner));
  {$ENDIF}
  FFormat := format;
  FData := AData;
  FDataOwner := ADataOwner;
  if FData = nil then
  begin
    w := width;
    h := height;
    if w <= 0 then
      w := 16;
    if h <= 0 then
      h := 16;

    ASurface := cairo_image_surface_create(format, w, h);
    try
      FHandle := gdk_pixbuf_get_from_surface(ASurface, 0 ,0, w, h);
    finally
      cairo_surface_destroy(ASurface);
    end;
    gdk_pixbuf_fill(FHandle, 0);
  end else
  begin
    FHandle := TGdkPixbuf.new_from_data(AData, GDK_COLORSPACE_RGB, format=CAIRO_FORMAT_ARGB32, 8, width, height, 0, nil, nil);
  end;
  (*
  if FData = nil then
  begin
    FHandle := QImage_create(width, height, format);
    QImage_fill(FHandle, 0);
  end
  else
  begin
    FHandle := QImage_create(FData, width, height, format);
    if format=QImageFormat_Mono then
      QImage_setNumColors(FHandle, 2);
  end;
  *)

end;

constructor TGtk3Image.Create(AData: PByte; width: Integer; height: Integer;
  bytesPerLine: Integer; format: cairo_format_t; const ADataOwner: Boolean);
var
  ASurface: Pcairo_surface_t;
  w, h: Integer;
begin
  {$ifdef VerboseGtk3DeviceContext}
    DebugLn('TGtk3Image.Create 4 AData=',dbgs(AData <> nil),' format=',dbgs(Ord(format)),' w=',dbgs(width),' h=',dbgs(height),' dataowner=',dbgs(ADataOwner),' bpl=',dbgs(bytesPerLine));
  {$endif}
  inherited Create;
  FFormat := format;
  FData := AData;
  FDataOwner := ADataOwner;

  if FData = nil then
  begin
    w := width;
    h := height;
    if (w <= 0) then
      w := 16;
    if (h <= 0) then
      h := 16;
    ASurface := cairo_image_surface_create(format, w, h);
    try
      FHandle := gdk_pixbuf_get_from_surface(ASurface, 0 ,0, w, h);
    finally
      cairo_surface_destroy(ASurface);
    end;
    gdk_pixbuf_fill(FHandle, 0);
  end else
  begin
    FHandle := TGdkPixbuf.new_from_data(AData, GDK_COLORSPACE_RGB, format=CAIRO_FORMAT_ARGB32, 8, width, height, bytesPerLine, nil, nil);
  end;
end;

function TGtk3Image.Select(ACtx: TGtk3DeviceContext): TGtk3ContextObject;
begin
  fContext:=ACtx;
  if not Assigned(ACtx) then exit(nil);
  Result := fContext.CurrentImage;
  fContext.SetImage(Self);
end;

function TGtk3Image.Get(szbuf: integer; pbuf: pointer): integer;
begin
  Result:=0;
end;

destructor TGtk3Image.Destroy;
begin
  if FHandle <> nil then
  begin
    FHandle^.unref;
    FHandle := nil;
  end;
  if (FDataOwner) and (FData <> nil) then
    FreeMem(FData);

  inherited Destroy;
end;

procedure TGtk3Image.CopyFrom(AImage: PGdkPixbuf; x, y, w, h: integer);
begin
  if FHandle = nil then
  begin
    DebugLn('*TGtk3Image.CopyFrom create subpixbuf ...');
    FHandle := gdk_pixbuf_new_subpixbuf(AImage, x, y, w, h);
    //TODO: must
    // FHandle := gdk_pixbuf_copy(AImage);
  end else
  begin
    DebugLn('*TGtk3Image.CopyFrom AImage ...');
    g_object_unref(FHandle);
    FHandle := gdk_pixbuf_new_subpixbuf(AImage, x, y, w, h);
    // gdk_pixbuf_copy_area(AImage, x, y, w, h, FHandle, 0, 0);
  end;
end;

function TGtk3Image.height: Integer;
begin
  Result := FHandle^.get_height;
end;

function TGtk3Image.width: Integer;
begin
  Result := FHandle^.get_width;
end;

function TGtk3Image.depth: Integer;
var
  AOption: Pgchar;
begin
  Result := 32;
  AOption := FHandle^.get_option('depth');
  if AOption <> nil then
  begin
    TryStrToInt(StrPas(AOption), Result);
  end;
end;

function TGtk3Image.dotsPerMeterX: Integer;
begin
  Result := 0;
end;

function TGtk3Image.dotsPerMeterY: Integer;
begin
  Result := 0;
end;

function TGtk3Image.bits: PByte;
begin
  Result := FHandle^.pixels;
end;

function TGtk3Image.numBytes: LongWord;
begin
  Result := FHandle^.get_byte_length;
end;

function TGtk3Image.bytesPerLine: Integer;
begin
  Result := FHandle^.rowstride;
end;

{ TGtk3Pen }

procedure TGtk3Pen.SetColor(AValue: TColor);
var
  ARed, AGreen, ABlue: Double;
begin
  FColor := AValue;
  ColorToCairoRGB(FColor, ARed, AGreen, ABlue);
  if Assigned(FContext) and Assigned(FContext.pcr) then
    cairo_set_source_rgb(FContext.pcr, ARed, AGreen, ABlue);
end;

constructor TGtk3Pen.Create;
begin
  inherited Create;
  FillChar(LogPen, SizeOf(LogPen), #0);
  FIsExtPen := False;
  FContext := nil;
  FColor := clBlack;
  FCosmetic := True;
  FWidth := 0;
  FStyle := psSolid;
  FEndCap := pecFlat;
  FJoinStyle := pjsRound;
  FPenMode := pmCopy; // default pen mode
end;

function TGtk3Pen.Select(ACtx:TGtk3DeviceContext): TGtk3ContextObject;
begin
  fContext:=ACtx;
  if not Assigned(fContext) then exit(nil);
  Result := FContext.CurrentPen;
  fContext.CurrentPen := Self;
end;

function TGtk3Pen.Get(szbuf: integer; pbuf: pointer): integer;
begin
  Result:=sizeof(LogPen);
  if pbuf=nil then exit;
  move(LogPen,pbuf^,min(result,szbuf));
end;

procedure TGtk3Pen.setCosmetic(b: Boolean);
begin
  FCosmetic := B;
  if Assigned(FContext) and Assigned(FContext.pcr) then
  begin
    if b then
      cairo_set_line_width(FContext.pcr, 0)
    else
      cairo_set_line_width(FContext.pcr, 1);
  end;
end;

procedure TGtk3Pen.setWidth(p1: Integer);
begin
  FWidth := p1;
  if Assigned(FContext) then
    cairo_set_line_width(FContext.pcr, p1);
end;

{ TGtk3Brush }

procedure TGtk3Brush.SetColor(AValue: TColor);
var
  ARed, AGreen, ABlue: Double;
begin
  FColor := AValue;
  ColorToCairoRGB(FColor, ARed, AGreen, ABlue);
  if Assigned(FContext) then
    cairo_set_source_rgb(FContext.pcr, ARed, AGreen, ABlue);
end;

procedure TGtk3Brush.SetStyle(AStyle: longword);
begin
  if AStyle=fStyle then exit;
  fStyle:=AStyle;
  Self.UpdatePattern;
end;

constructor TGtk3Brush.Create;
begin
  inherited Create;
  FColor := clNone;
  FillChar(LogBrush, SizeOf(TLogBrush), #0);
end;

function TGtk3Brush.Select(ACtx:TGtk3DeviceContext): TGtk3ContextObject;
begin
  fContext:=ACtx;
  if not Assigned(fContext) then exit(nil);
  Result := fContext.CurrentBrush;
  Self.UpdatePattern;
  fContext.CurrentBrush := Self;
end;

function TGtk3Brush.Get(szbuf: integer; pbuf: pointer): integer;
begin
  Result:=sizeof(LogBrush);
  if pbuf=nil then exit;
  move(LogBrush,pbuf^,min(Result,szbuf));
end;

destructor TGtk3Brush.Destroy;
begin
  if Assigned(brush_pattern) then
    cairo_pattern_destroy(brush_pattern);
  if Assigned(pat_buf) then
  freeandnil(pat_buf);
  inherited Destroy;
end;

procedure TGtk3Brush.UpdatePattern;
var
  w,h,i,j:integer;
  clr:dword;
  rgb:array[0..3] of byte absolute clr;
  pat_sample,psrc,pdst:pdword;
begin
  if Self.LogBrush.lbStyle<>BS_HATCHED then exit;

  if Assigned(Self.brush_pattern) then
  begin
     cairo_pattern_destroy(brush_pattern);
     freeandnil(pat_buf);
  end;
  case TBrushStyle(Self.LogBrush.lbHatch+ord(bsHorizontal)) of
  bsHorizontal:
    begin
      w:=4; h:=4;
      pat_sample:=@stipple_horz;
    end;
  bsVertical:
    begin
      w:=4; h:=4;
      pat_sample:=@stipple_vert;
    end;
  bsFDiagonal:
    begin
      w:=8; h:=8;
      pat_sample:=@stipple_fdiag;
    end;
  bsBDiagonal:
    begin
      w:=8; h:=8;
      pat_sample:=@stipple_bdiag;
    end;
  bsCross:
    begin
      w:=8; h:=8;
      pat_sample:=@stipple_cross1;
    end;
  bsDiagCross:
    begin
      w:=8; h:=8;
      pat_sample:=@stipple_dcross;
    end;
  else
    exit
  end;
  psrc:=pat_sample;
  getmem(pat_buf,w*h*sizeof(dword));
  pdst:=pat_buf;
  clr:=ColorToRgb(Self.Color);
  for i:=0 to h-1 do
  for j:=0 to w-1 do
  begin
    case psrc^ of
    clr_A: pdst^:=$ff000000 or (rgb[0] shl 16) or (rgb[1] shl 8) or (rgb[2]);
    clr_B: pdst^:=$ffffffff;
    end;
    inc(psrc); inc(pdst);
  end;
  {GTK3 states the buffer must exist, until image that uses the buffer - destroyed}
  brush_pattern:=create_stipple(PByte(pat_buf),w,w);
end;



function create_stipple(stipple_data:pbyte;width,height:integer):pcairo_pattern_t;
var
  surface:pcairo_surface_t;
	pattern:pcairo_pattern_t;
  stride:integer;
begin
	stride := cairo_format_stride_for_width (CAIRO_FORMAT_ARGB32, width);
	surface := cairo_image_surface_create_for_data (stipple_data, CAIRO_FORMAT_ARGB32, width, height,
	                                               stride);
	pattern := cairo_pattern_create_for_surface (surface);
	cairo_surface_destroy (surface);
	cairo_pattern_set_extend (pattern, CAIRO_EXTEND_REPEAT);

	result:= pattern;
end;

{ TGtk3DeviceContext }

function TGtk3DeviceContext.GetOffset: TPoint;
var
  dx,dy: Double;
begin
  cairo_surface_get_device_offset(cairo_get_target(pcr), @dx, @dy);
  Result := Point(Round(dx), Round(dy));
end;

procedure TGtk3DeviceContext.setBrush(AValue: TGtk3Brush);
begin
  if Assigned(FBrush) then
    FBrush.Free;
  FBrush := AValue;
end;

procedure TGtk3DeviceContext.SetFont(AValue: TGtk3Font);
begin
  if Assigned(FFont) then
    FFont.Free;
  FFont := AValue;
end;

procedure TGtk3DeviceContext.SetOffset(AValue: TPoint);
var
  dx, dy: Double;
begin
  dx := AValue.X;
  dy := AValue.Y;
  cairo_surface_set_device_offset(cairo_get_target(pcr), dx, dy);
end;

procedure TGtk3DeviceContext.setPen(AValue: TGtk3Pen);
begin
  if Assigned(FPen) then
    FPen.Free;
  FPen := AValue;
end;

procedure TGtk3DeviceContext.SetvImage(AValue: TGtk3Image);
begin
  if Assigned(FvImage) then
    FvImage.Free;
  FvImage.Free;
end;

function TGtk3DeviceContext.SX(const x: double): Double;
begin
  Result := 1*(x+vClipRect.Left);
end;

function TGtk3DeviceContext.SY(const y: double): Double;
begin
  Result := 1*(y+vClipRect.Top);
end;

function TGtk3DeviceContext.SX2(const x: double): Double;
begin
  Result := x;
end;

function TGtk3DeviceContext.SY2(const y: double): Double;
begin
  Result := y;
end;

procedure TGtk3DeviceContext.ApplyBrush;
begin
  if FBkMode = TRANSPARENT then
  begin
    DebugLn('TGtk3DeviceContext.ApplyBrush setting transparent source');
    //cairo_set_source_surface(Widget, CairoSurface, 0 , 0);
  end else
    SetSourceColor(FCurrentBrush.Color);

  if Self.FCurrentBrush.Style<>0 then
  begin
    if Assigned(Self.FCurrentBrush.brush_pattern) then
    cairo_set_source(pcr,Self.FCurrentBrush.brush_pattern);
  end;
end;

procedure TGtk3DeviceContext.ApplyFont;
var
  AFont: TGtk3Font;
begin
  if Assigned(FCurrentFont) then
    AFont := FCurrentFont
  else
    AFont := FFont;
  if AFont<>nil then ;
  debugln(['TGtk3DeviceContext.ApplyFont ToDo']);
end;

procedure TGtk3DeviceContext.ApplyPen;
  procedure SetDash(d: array of double);
  begin
    cairo_set_dash(pcr, @d, High(d)+1, 0);
  end;
var
  cap: cairo_line_cap_t;
  w: Double;
begin
  SetSourceColor(FCurrentPen.Color);
  case FCurrentPen.Mode of
    pmBlack: begin
      SetSourceColor(clBlack);
      cairo_set_operator(pcr, CAIRO_OPERATOR_OVER);
    end;
    pmWhite: begin
      SetSourceColor(clWhite);
      cairo_set_operator(pcr, CAIRO_OPERATOR_OVER);
    end;
    pmCopy: cairo_set_operator(pcr, CAIRO_OPERATOR_OVER);
    pmXor: cairo_set_operator(pcr, CAIRO_OPERATOR_XOR);
    pmNotXor: cairo_set_operator(pcr, CAIRO_OPERATOR_XOR);
    {pmNop,
    pmNot,
    pmCopy,
    pmNotCopy,
    pmMergePenNot,
    pmMaskPenNot,
    pmMergeNotPen,
    pmMaskNotPen,
    pmMerge,
    pmNotMerge,
    pmMask,
    pmNotMask,}
    else
      cairo_set_operator(pcr, CAIRO_OPERATOR_OVER);
  end;

  if FCurrentPen.Cosmetic then
    cairo_set_line_width(pcr, 1.0)
  else
  begin
    w := FCurrentPen.Width;
    if w <= 1 then
      w := 0.5;
    cairo_set_line_width(pcr, w {* ScaleX}); //line_width is diameter of the pen circle
  end;

  case FCurrentPen.Style of
    psSolid: cairo_set_dash(pcr, nil, 0, 0);
    psDash: SetDash(Dash_Dash);
    psDot: SetDash(Dash_Dot);
    psDashDot: SetDash(Dash_DashDot);
    psDashDotDot: SetDash(Dash_DashDotDot);
  else
    cairo_set_dash(pcr, nil, 0, 0);
  end;

  case FCurrentPen.EndCap of
    pecRound: cap := CAIRO_LINE_CAP_ROUND;
    pecSquare: cap := CAIRO_LINE_CAP_SQUARE;
    pecFlat: cap := CAIRO_LINE_CAP_BUTT;
  end;

  // dashed patterns do not look ok  combined with round or squared caps
  // make it flat until a solution is found
  case FCurrentPen.Style of
    psDash, psDot, psDashDot, psDashDotDot:
      cap := CAIRO_LINE_CAP_BUTT
  end;
  cairo_set_line_cap(pcr, cap);

  case FCurrentPen.JoinStyle of
    pjsRound: cairo_set_line_join(pcr, CAIRO_LINE_JOIN_ROUND);
    pjsBevel: cairo_set_line_join(pcr, CAIRO_LINE_JOIN_BEVEL);
    pjsMiter: cairo_set_line_join(pcr, CAIRO_LINE_JOIN_MITER);
  end;
end;

constructor TGtk3DeviceContext.Create(AWidget: PGtkWidget;
  const APaintEvent: Boolean);
var
  W: gint;
  H: gint;
  ACairo:pcairo_t;
  ARect: TGdkRectangle;
begin
  {$ifdef VerboseGtk3DeviceContext}
    WriteLn('TGtk3DeviceContext.Create (',
     ' WidgetHandle: ', dbghex(PtrInt(AWidget)),
     ' FromPaintEvent:',BoolToStr(APaintEvent),' )');
  {$endif}
  inherited Create;
  FvClipRect := Rect(0, 0, 0, 0);
  Window := nil;
  Parent := nil;
  ParentPixmap := nil;
  CairoSurface := nil;
  // FMetrics := nil;
  // SelFont := nil;
  // SelBrush := nil;
  // SelPen := nil;
  FCanRelease := False;
  FOwnsCairo := True;
  FOwnsSurface := False;
  FCurrentTextColor := clBlack;

  if AWidget = nil then
  begin
   (* AWindow := gdk_get_default_root_window;
    AWindow^.get_geometry(@x, @y, @w, @h);
    w:=1; h:=1;
    // ParentPixmap := gdk_pixbuf_get_from_window(AWindow, x, y, w, h);
    // Widget := gdk_cairo_create(AWindow);
    // gdk_cairo_set_source_pixbuf(Widget, ParentPixmap, 0, 0);
    //CairoSurface := cairo_image_surface_create(CAIRO_FORMAT_RGB24, w, h);
    CairoSurface := cairo_image_surface_create(CAIRO_FORMAT_ARGB32, w, h);
    Widget := cairo_create(CairoSurface);   *)

    ACairo := gdk_cairo_create(gdk_get_default_root_window);
    gdk_cairo_get_clip_rectangle(ACairo, @ARect);
    CairoSurface := cairo_image_surface_create(CAIRO_FORMAT_ARGB32, ARect.width, ARect.height);
    pcr := cairo_create(CairoSurface);

    ParentPixmap := gdk_pixbuf_get_from_surface(CairoSurface, 0, 0, ARect.width, ARect.height);
    FOwnsSurface := True;
  end else
  begin
    Parent := AWidget;
    if not APaintEvent then
    begin
      {avoid paints on null pixmaps !}
      W := gtk_widget_get_allocated_width(AWidget);
      H := gtk_widget_get_allocated_height(AWidget);
      if W <= 0 then W := 1;
      if H <= 0 then H := 1;
      pcr := gdk_cairo_create(gtk_widget_get_window(AWidget));
    end else
    begin
      W := gtk_widget_get_allocated_width(AWidget);
      H := gtk_widget_get_allocated_height(AWidget);
      if W <= 0 then W := 1;
      if H <= 0 then H := 1;
      pcr := gdk_cairo_create(gtk_widget_get_window(AWidget));
    end;
  end;
  if not FOwnsSurface then
    CairoSurface := cairo_get_target(pcr);
  CreateObjects;
  (*
  FRopMode := R2_COPYPEN;
  FOwnPainter := True;
  CreateObjects;
  FPenPos.X := 0;
  FPenPos.Y := 0;
  *)
end;

constructor TGtk3DeviceContext.Create(AWindow: PGdkWindow;
  const APaintEvent: Boolean);
begin
  {$ifdef VerboseGtk3DeviceContext}
    WriteLn('TGtk3DeviceContext.Create (',
     ' WindowHandle: ', dbghex(PtrInt(AWindow)),
     ' FromPaintEvent:',BoolToStr(APaintEvent),' )');
  {$endif}
  inherited Create;
  FvClipRect := Rect(0, 0, 0, 0);
  Parent := nil;
  ParentPixmap := nil;
  CairoSurface := nil;
  Window := AWindow;
  FOwnsSurface := False;
  FCanRelease := False;
  FOwnsCairo := True;
  FCurrentTextColor := clBlack;
  //AWindow^.get_geometry(@x, @y, @w, @h);
  // ParentPixmap := gdk_pixbuf_get_from_window(AWindow, x, y, w, h);
  pcr := gdk_cairo_create(AWindow);
  // gdk_cairo_set_source_pixbuf(Widget, ParentPixmap, 0, 0);
  gdk_cairo_set_source_window(pcr, AWindow, 0, 0);
  CairoSurface := cairo_get_target(pcr);
  CreateObjects;
end;

constructor TGtk3DeviceContext.CreateFromCairo(AWidget: PGtkWidget;
  ACairo: PCairo_t);
var
  AGdkRect: TGdkRectangle;
begin
  {$ifdef VerboseGtk3DeviceContext}
    WriteLn('TGtk3DeviceContext.CreateFromCairo (',
     ' WidgetHandle: ', dbghex(PtrInt(AWidget)),
     ' FromPaintEvent:',BoolToStr(True),' )');
  {$endif}
  inherited Create;
  FOwnsCairo := False;
  Window := nil;
  Parent := AWidget;
  ParentPixmap := nil;
  CairoSurface := nil;
  FOwnsSurface := False;
  FCurrentTextColor := clBlack;
  gdk_cairo_get_clip_rectangle(ACairo, @AGdkRect);
  FvClipRect := RectFromGdkRect(AGdkRect);
  pcr := ACairo;
  CairoSurface := cairo_get_target(pcr);
  CreateObjects;
end;

destructor TGtk3DeviceContext.Destroy;
begin
  {$ifdef VerboseGtk3DeviceContext}
    WriteLn('TGtk3DeviceContext.Destroy ',dbgHex(PtrUInt(Self)));
  {$endif}
  DeleteObjects;
  if FOwnsCairo and (pcr <> nil) then
    cairo_destroy(pcr);
  if (ParentPixmap <> nil) then
    g_object_unref(ParentPixmap);
  if FOwnsSurface and (CairoSurface <> nil) then
    cairo_surface_destroy(CairoSurface);
  Parent := nil;
  pcr := nil;
  ParentPixmap := nil;
  CairoSurface := nil;
  Window := nil;
  inherited Destroy;
end;

procedure TGtk3DeviceContext.CreateObjects;
var
  Matrix:cairo_matrix_t;
begin
  FBkMode := TRANSPARENT;
  FCurrentImage := nil;
  FCurrentRegion := nil;
  FBrush := TGtk3Brush.Create;
  FBrush.Context := Self;
  FBrush.Color := clNone;
  FBrush.Style := BS_SOLID;
  FPen := TGtk3Pen.Create;
  FPen.Context := Self;
  FPen.Color := clBlack;
  FCurrentPen := FPen;
  FCurrentBrush := FBrush;
  FFont := TGtk3Font.Create(pcr, Parent);
  FCurrentFont := FFont;
  FvImage := TGtk3Image.Create(nil, 1, 1, 8, CAIRO_FORMAT_ARGB32);
  FCurrentImage := FvImage;

  cairo_get_matrix(pcr, @Matrix);
  // widget with menu or other non-client exclusions have offset in trasform matrix
  fncOrigin:=Point(round(Matrix.x0),round(Matrix.y0));
end;

procedure TGtk3DeviceContext.DeleteObjects;
begin
  if Assigned(FBrush) then
    FreeAndNil(FBrush);
  if Assigned(FPen) then
    FreeAndNil(FPen);
  if Assigned(FFont) then
    FreeAndNil(FFont);
  if Assigned(FvImage) then
    FreeAndNil(FvImage);
end;

procedure TGtk3DeviceContext.drawPixel(x, y: Integer; AColor: TColor);
// Seems that painting line from (a-1, b-1) to (a,b) gives one pixel
begin
  SetSourceColor(AColor);
  cairo_set_line_width(pcr, 1);
  cairo_move_to(pcr, x - PixelOffset, y - PixelOffset);
  cairo_line_to(pcr, x + PixelOffset, y + PixelOffset);
  cairo_stroke(pcr);
end;

function TGtk3DeviceContext.getPixel(x, y: Integer): TColor;
var
  pixbuf: PGdkPixbuf;
  pixels: pointer;
begin
  Result := 0;
  pixbuf := gdk_pixbuf_get_from_surface(CairoSurface, X, Y, 1, 1);
  if Assigned(pixbuf) then
  begin
    pixels := gdk_pixbuf_get_pixels(pixbuf);
    if Assigned(pixels) then
      Result := PLongInt(pixels)^ and $FFFFFF; // take first 3 bytes at pixels^
  end;
end;

procedure TGtk3DeviceContext.drawRect(x1, y1, w, h: Integer; const AFill, ABorder: Boolean);
begin
  cairo_save(pcr);
  try
    cairo_rectangle(pcr, x1 + PixelOffset, y1 + PixelOffset, w - 1, h - 1);

    if AFill then
    begin
      ApplyBrush;
      cairo_fill_preserve(pcr);
    end;
    if ABorder then
    begin
      ApplyPen;
      cairo_stroke(pcr);
    end;

    cairo_new_path(pcr);
  finally
    cairo_restore(pcr);
  end;
end;

procedure TGtk3DeviceContext.drawRoundRect(x, y, w, h, rx, ry: Integer);
begin
  RoundRect(x, y, w, h, rx, ry);
end;

procedure TGtk3DeviceContext.drawText(x, y: Integer; AText: PChar; ALen: Integer
  );
var
  R, G, B: Double;
  gColor: TGdkColor;
  Attr: PPangoAttribute;
  AttrList: PPangoAttrList;
  UseBack: boolean;
  ornt:integer;
begin
  cairo_save(pcr);
  try
    cairo_move_to(pcr, X, Y);
    ornt := Self.FCurrentFont.FLogFont.lfOrientation;
    if ornt<>0 then
      cairo_rotate(pcr, - pi * (ornt / 10)/180);
    ColorToCairoRGB(ColorToRgb(TColor(CurrentTextColor)), R, G, B);
    cairo_set_source_rgb(pcr, R, G, B);

    FCurrentFont.Layout^.set_text(AText, ALen);

    UseBack := FCurrentBrush.Style <> BS_NULL;
    if UseBack then
    begin
      gColor := TColorToTGDKColor(FCurrentBrush.Color);
      AttrList := pango_attr_list_new;
      Attr := pango_attr_background_new(gColor.red, gColor.green, gColor.blue);
      pango_attr_list_insert(AttrList, Attr);
      FCurrentFont.Layout^.set_attributes(AttrList);
    end;

    pango_cairo_show_layout(pcr, FCurrentFont.Layout);

    if UseBack then
    begin
      FCurrentFont.Layout^.set_attributes(nil);
      pango_attribute_destroy(Attr);
    end;
  finally
    cairo_restore(pcr);
  end;
end;

procedure TGtk3DeviceContext.drawEllipse(x, y, w, h: Integer; AFill, ABorder: Boolean);
var
  save_matrix:cairo_matrix_t;
begin
  cairo_save(pcr);
  try
    cairo_get_matrix(pcr, @save_matrix);
    cairo_translate (pcr, x + w / 2.0 + PixelOffset, y + h / 2.0 + PixelOffset);
    cairo_scale (pcr, w / 2.0, h / 2.0);
    cairo_new_path(pcr);
    cairo_arc
        (
          (*cr =*) pcr,
          (*xc =*) 0,
          (*yc =*) 0,
          (*radius =*) 1,
          (*angle1 =*) 0,
          (*angle2 =*) 2 * Pi
        );
    cairo_close_path(pcr);
    if AFill then
    begin
      ApplyBrush;
      cairo_fill_preserve(pcr);
    end;
  finally
    cairo_restore(pcr);
  end;
  if ABorder then
  begin
    ApplyPen;
    cairo_stroke(pcr);
  end;
  //if ABorder=false, need to clear current path
  cairo_new_path(pcr);
end;

procedure TGtk3DeviceContext.drawSurface(targetRect: PRect;
  Surface: Pcairo_surface_t; sourceRect: PRect; mask: PGdkPixBuf;
  maskRect: PRect);
var
  M: cairo_matrix_t;
begin
  {$IFDEF VerboseGtk3DeviceContext}
  DebugLn('TGtk3DeviceContext.DrawSurface ');
  {$ENDIF}
  cairo_save(pcr);
  try
    with targetRect^ do
      cairo_rectangle(pcr, Left + PixelOffset, Top + PixelOffset, Right - Left, Bottom - Top);
    cairo_set_source_surface(pcr, Surface, 0, 0);
    cairo_matrix_init_identity(@M);
    cairo_matrix_translate(@M, SourceRect^.Left, SourceRect^.Top);
    cairo_matrix_scale(@M,  (sourceRect^.Right-sourceRect^.Left) / (targetRect^.Right-targetRect^.Left),
        (sourceRect^.Bottom-sourceRect^.Top) / (targetRect^.Bottom-targetRect^.Top));
    cairo_matrix_translate(@M, -targetRect^.Left, -targetRect^.Top);
    cairo_pattern_set_matrix(cairo_get_source(pcr), @M);
    cairo_clip(pcr);
    cairo_paint(pcr);
  finally
    cairo_restore(pcr);
  end;
end;

procedure TGtk3DeviceContext.drawImage(targetRect: PRect; image: PGdkPixBuf;
  sourceRect: PRect; mask: PGdkPixBuf; maskRect: PRect);
//var
//  pm: PGdkPixbuf;
//  AData: PByte;
//  ASurface: Pcairo_surface_t;
begin
  {$IFDEF VerboseGtk3DeviceContext}
  DebugLn('TGtk3DeviceContext.DrawImage ');
  {$ENDIF}
  cairo_save(pcr);
  try
    // pm := Image;
    // AData := PByte(gdk_pixbuf_get_pixels(pm));
    // ASurface := cairo_image_surface_create_for_data(AData, CAIRO_FORMAT_ARGB32, gdk_pixbuf_get_width(pm), gdk_pixbuf_get_height(pm), gdk_pixbuf_get_rowstride(pm));
    // cairo_set_source_surface(Widget, ASurface, targetRect^.Left, targetRect^.Top);
    gdk_cairo_set_source_pixbuf(pcr, Image, 0, 0);
    with targetRect^ do
      cairo_rectangle(pcr, Left + PixelOffset, Top + PixelOffset, Right - Left, Bottom - Top);
    cairo_paint(pcr);
  finally
    // cairo_surface_destroy(ASurface);
    cairo_restore(pcr);
  end;
end;

procedure TGtk3DeviceContext.drawImage1(targetRect: PRect; image: PGdkPixBuf;
  sourceRect: PRect; mask: PGdkPixBuf; maskRect: PRect);
var
  M: cairo_matrix_t;
begin
  {$IFDEF VerboseGtk3DeviceContext}
  DebugLn('TGtk3DeviceContext.DrawImage ');
  {$ENDIF}
  cairo_save(pcr);
  try
    gdk_cairo_set_source_pixbuf(pcr, Image, 0, 0);
    with targetRect^ do
      cairo_rectangle(pcr, Left + PixelOffset, Top + PixelOffset, Right - Left, Bottom - Top);

    cairo_set_operator (pcr, CAIRO_OPERATOR_OVER);


    cairo_matrix_init_identity(@M);
    cairo_matrix_translate(@M, SourceRect^.Left, SourceRect^.Top);
    cairo_matrix_scale(@M,  (sourceRect^.Right-sourceRect^.Left) / (targetRect^.Right-targetRect^.Left),
        (sourceRect^.Bottom-sourceRect^.Top) / (targetRect^.Bottom-targetRect^.Top));
    cairo_matrix_translate(@M, -targetRect^.Left, -targetRect^.Top);
    cairo_pattern_set_matrix(cairo_get_source(pcr), @M);
    //cairo_fill (Widget);
    cairo_clip(pcr);
    cairo_paint(pcr);
  finally
    cairo_restore(pcr);
  end;
end;


procedure TGtk3DeviceContext.drawPixmap(p: PPoint; pm: PGdkPixbuf; sr: PRect);
var
  ASurface: Pcairo_surface_t;
  AData: PByte;
begin
  {$IFDEF VerboseGtk3DeviceContext}
  DebugLn('TGtk3DeviceContext.DrawPixmap ');
  {$ENDIF}
  cairo_save(pcr);
  try
    AData := PByte(gdk_pixbuf_get_pixels(pm));
    ASurface := cairo_image_surface_create_for_data(AData, CAIRO_FORMAT_ARGB32, gdk_pixbuf_get_width(pm), gdk_pixbuf_get_height(pm), gdk_pixbuf_get_rowstride(pm));
    cairo_set_source_surface(pcr, ASurface, sr^.Left, sr^.Top);
    cairo_paint(pcr);
  finally
    cairo_surface_destroy(ASurface);
    cairo_restore(pcr);
  end;
end;

procedure TGtk3DeviceContext.drawPolyLine(P: PPoint; NumPts: Integer);
var
  i: Integer;
begin
  cairo_save(pcr);
  try
    ApplyPen;
    cairo_move_to(pcr, P[0].X+PixelOffset, P[0].Y+PixelOffset);
    for i := 1 to NumPts-1 do
      cairo_line_to(pcr, P[i].X+PixelOffset, P[i].Y+PixelOffset);
    cairo_stroke(pcr);
  finally
    cairo_restore(pcr);
  end;

end;

procedure TGtk3DeviceContext.drawPolygon(P: PPoint; NumPts: Integer;
  FillRule: Integer; AFill, ABorder: Boolean);
var
  i: Integer;
begin
  cairo_save(pcr);
  try
    // add offset so the center of the pixel is used
    cairo_move_to(pcr, P[0].X+PixelOffset, P[0].Y+PixelOffset);
    for i := 1 to NumPts-1 do
      cairo_line_to(pcr, P[i].X+PixelOffset, P[i].Y+PixelOffset);
    cairo_close_path(pcr);

    if AFill then
    begin
      ApplyBrush;
      cairo_set_fill_rule(pcr, cairo_fill_rule_t(FillRule));
      cairo_fill_preserve(pcr);
    end;

    if ABorder then
    begin
      ApplyPen;
      cairo_stroke(pcr);
    end;

    cairo_new_path(pcr);
  finally
    cairo_restore(pcr);
  end;
end;

procedure TGtk3DeviceContext.drawPolyBezier(P: PPoint; NumPoints: Integer; Filled, Continuous: boolean);
var
  MaxIndex, i: Integer;
  bFill, bBorder: Boolean;
begin
  // 3 points per curve + a starting point for the first curve
  if (NumPoints < 4) then
    Exit;

  bFill := CurrentBrush.Style <> BS_NULL;
  bBorder := CurrentPen.Style <> psClear;

  // we need 3 points left for continuous and 4 for not continous
  MaxIndex := NumPoints - 3 - Ord(not Continuous);

  cairo_save(pcr);
  try
    i := 0;
    while i <= MaxIndex do
    begin
      if i = 0 then
      begin
        cairo_move_to(pcr, P[i].X+PixelOffset, P[i].Y+PixelOffset); // start point
        Inc(i);
      end
      else
      if not Continuous then
      begin
        cairo_line_to(pcr, P[i].X+PixelOffset, P[i].Y+PixelOffset); // start point
        Inc(i);
      end;

      cairo_curve_to(pcr,
                     P[i].X+PixelOffset, P[i].Y+PixelOffset, // control point 1
                     P[i+1].X+PixelOffset, P[i+1].Y+PixelOffset, // control point 2
                     P[i+2].X+PixelOffset, P[i+2].Y+PixelOffset); // end point and start point of next
      Inc(i, 3);
    end;

    if Filled then
    begin
      cairo_close_path(pcr);
      if bFill then
      begin
        ApplyBrush;
        cairo_fill_preserve(pcr);
      end;
    end;

    if bBorder then
    begin
      ApplyPen;
      cairo_stroke(pcr);
    end
    else
      cairo_new_path(pcr);
  finally
    cairo_restore(pcr);
  end;
end;

procedure TGtk3DeviceContext.eraseRect(ARect: PRect);
begin
  // cairo_surface_
end;

procedure TGtk3DeviceContext.fillRect(ARect: PRect; ABrush: HBRUSH);
begin
  with ARect^ do
    fillRect(Left, Top, Right - Left, Bottom - Top, ABrush);
end;

procedure TGtk3DeviceContext.fillRect(x, y, w, h: Integer; ABrush: HBRUSH);
var
  ATempBrush: TGtk3Brush;
begin
  {$ifdef VerboseGtk3DeviceContext}
  // WriteLn('TGtk3DeviceContext.fillRect ',Format('x %d y %d w %d h %d',[x, y, w, h]));
  {$endif}

  cairo_save(pcr);
  try
    ATempBrush := nil;
    if ABrush <> 0 then
    begin
      ATempBrush := FCurrentBrush;
      fBkMode := OPAQUE;
      CurrentBrush:= TGtk3Brush(ABrush);
    end;

    applyBrush;
    cairo_rectangle(pcr, x + PixelOffset, y + PixelOffset, w - 1, h - 1);
    cairo_fill_preserve(pcr);

    // must paint border, filling is not enough
    SetSourceColor(FCurrentBrush.Color);
    cairo_set_line_width(pcr, 1);
    cairo_stroke(pcr);

    if ABrush <> 0 then
      CurrentBrush:= ATempBrush;
  finally
    cairo_restore(pcr);
  end;
end;

procedure TGtk3DeviceContext.fillRect(x, y, w, h: Integer);
begin
  fillRect(x, y, w, h , 0);
end;

procedure TGtk3DeviceContext.FillAndStroke;
begin
  if Assigned(FCurrentBrush) and (FCurrentBrush.Style <> BS_NULL) then
  begin
    ApplyBrush;
    if Assigned(FCurrentPen) and (FCurrentPen.Style = psClear) then
      cairo_fill(pcr)
    else
      cairo_fill_preserve(pcr);
  end;
  if Assigned(FCurrentPen) and (FCurrentPen.Style <> psClear) then
  begin
    ApplyPen;
    cairo_stroke(pcr);
  end;
end;

procedure TGtk3DeviceContext.EllipseArcPath(CX, CY, RX, RY: Double; Angle1, Angle2: Double; Clockwise, Continuous: Boolean);
begin
  if (RX=0) or (RY=0) then //cairo_scale do not likes zero params
    Exit;
  cairo_save(pcr);
  try
    cairo_translate(pcr, SX(CX), SY(CY));
    cairo_scale(pcr, SX2(RX), SY2(RY));
    if not Continuous then
      cairo_move_to(pcr, cos(Angle1), sin(Angle1)); //Move to arcs starting point
    if Clockwise then
      cairo_arc(pcr, 0, 0, 1, Angle1, Angle2)
    else
      cairo_arc_negative(pcr, 0, 0, 1, Angle1, Angle2);
  finally
    cairo_restore(pcr);
  end;
end;

function TGtk3DeviceContext.RoundRect(X1, Y1, X2, Y2: Integer; RX, RY: Integer): Boolean;
var
  DX, DY: Double;
begin
  Result := False;
  cairo_surface_get_device_offset(cairo_get_target(pcr), @DX, @DY);
  DX := DX+PixelOffset;
  DY := DY+PixelOffset;
  cairo_translate(pcr, DX, DY);
  try
    cairo_move_to(pcr, SX(X1+RX), SY(Y1));
    cairo_line_to(pcr, SX(X2-RX), SY(Y1));
    EllipseArcPath(X2-RX, Y1+RY, RX, RY, -PI/2, 0, True, True);
    cairo_line_to(pcr, SX(X2), SY(Y2-RY));
    EllipseArcPath(X2-RX, Y2-RY, RX, RY, 0, PI/2, True, True);
    cairo_line_to(pcr, SX(X1+RX), SY(Y2));
    EllipseArcPath(X1+RX, Y2-RY, RX, RY, PI/2, PI, True, True);
    cairo_line_to(pcr, SX(X1), SY(Y1+RX));
    EllipseArcPath(X1+RX, Y1+RY, RX, RY, PI, PI*1.5, True, True);
    FillAndStroke;
    Result := True;
  finally
    cairo_translate(pcr, -DX, -DY);
  end;
end;

function TGtk3DeviceContext.drawFrameControl(arect:TRect;uType,uState:cardinal):boolean;
var
  Context: PGtkStyleContext;
  pw:PGtkWidget;
  path:PGtkwIdgetPath;
  w:PgtkWidget;
begin

  Result:=false;

 { if Parent <> nil then
    Context := Parent^.get_style_context
  else
  begin
    Context:=TGtkStyleContext.new();
    Context^.add_class('button');
  end;
  if Context = nil then
  begin
    DebugLn('WARNING: TGtk3WidgetSet.DrawFrameControl on non widget context isn''t implemented.');
    exit;
  end;  }

  w:=nil;

  if uType=DFC_BUTTON then
  begin
    w:=GetStyleWidget(lgsButton);
  end else
  if uType=DFC_MENU then
  begin
    w:=GetStyleWidget(lgsMenu);
  end;

  if not Assigned(w) then exit;

  Context:=w^.get_style_context;
  path:=w^.get_path;
  gtk_style_context_set_path (context, path);
  gtk_style_context_set_state (context,(* gtk_widget_path_iter_get_state (path, -1)*) -1);

  {GTK_STATE_FLAG_NORMAL: TGtkStateFlags = 0;
  GTK_STATE_FLAG_ACTIVE: TGtkStateFlags = 1;
  GTK_STATE_FLAG_PRELIGHT: TGtkStateFlags = 2;
  GTK_STATE_FLAG_SELECTED: TGtkStateFlags = 4;
  GTK_STATE_FLAG_INSENSITIVE: TGtkStateFlags = 8;
  GTK_STATE_FLAG_INCONSISTENT: TGtkStateFlags = 16;
  GTK_STATE_FLAG_FOCUSED: TGtkStateFlags = 32;
  GTK_STATE_FLAG_BACKDROP: TGtkStateFlags = 64;
  GTK_STATE_FLAG_DIR_LTR: TGtkStateFlags = 128;
  GTK_STATE_FLAG_DIR_RTL: TGtkStateFlags = 256;
  }
  gtk_style_context_set_state (context, GTK_STATE_FLAG_FOCUSED or GTK_STATE_FLAG_PRELIGHT);

  pw:=w;
  while Assigned(pw) do
  begin

    Context:=pw^.get_style_context;
    path:=pw^.get_path;
    with aRect do
    begin
      gtk_render_background(Context,pcr, Left, Top, Right - Left, Bottom - Top);
      gtk_render_frame(Context,pcr, Left, Top, Right - Left, Bottom - Top);
    end;
    pw:=pw^.parent;
  end;

  Result := True;
end;

function TGtk3DeviceContext.drawFocusRect(const aRect: TRect): boolean;
var
  Context: PGtkStyleContext;
  //AValue: TGValue;
begin
  Result := False;

  if Parent <> nil then
    Context := Parent^.get_style_context
  else
  begin
    Context:=TGtkStyleContext.new();
    Context^.add_class('button');
    //gtk_style_context_get(Context,GTK_STATE_NORMAL,[]);
 { if gtk_widget_get_default_style^.has_context then
  begin
    // Context := gtk_widget_get_default_style^.has_context
    AValue.g_type := G_TYPE_POINTER;
    AValue.set_pointer(nil);
    g_object_get_property(gtk_widget_get_default_style,'context',@AValue);
    Context := AValue.get_pointer;
    AValue.unset;
  end else
    Context := nil;}
  end;
  if Context = nil then
  begin
    DebugLn('WARNING: TGtk3WidgetSet.DrawFocusRect drawing focus on non widget context isn''t implemented.');
    exit;
  end;
  with aRect do
    gtk_render_focus(Context ,pcr, Left, Top, Right - Left, Bottom - Top);

  Result := True;
end;

function TGtk3DeviceContext.getBpp: integer;
var
  AVisual: PGdkVisual;
begin
  if (Parent <> nil) and (Parent^.get_has_window) then
  begin
    AVisual := gdk_window_get_visual(Parent^.get_window);
    Result := gdk_visual_get_bits_per_rgb(AVisual);
    g_object_unref(AVisual);
  end else
  if (ParentPixmap <> nil) and (Parent = nil) then
  begin
    Result := ParentPixmap^.get_bits_per_sample;
  end else
  begin
    AVisual := gdk_window_get_visual(gdk_get_default_root_window);
    Result := gdk_visual_get_bits_per_rgb(AVisual);
    g_object_unref(AVisual);
  end;
end;

function TGtk3DeviceContext.getDepth: integer;
var
  AVisual: PGdkVisual;
begin
  Result := 0;
  if (Parent <> nil) and Gtk3IsGdkWindow(Parent^.get_window) then
  begin
    AVisual := gdk_window_get_visual(Parent^.get_window);
    if Gtk3IsGdkVisual(AVisual) then
    begin
      Result := gdk_visual_get_depth(AVisual);
      exit;
    end;
  end;
  AVisual := gdk_window_get_visual(gdk_get_default_root_window);
  if Gtk3IsGdkVisual(AVisual) then
  begin
    Result := gdk_visual_get_depth(AVisual);
  end;
end;

function TGtk3DeviceContext.getDeviceSize: TPoint;
begin
  Result := Point(0 , 0);
  if Parent <> nil then
  begin
    Result.y := Parent^.get_allocated_height;
    Result.x := Parent^.get_allocated_width;
  end else
  if ParentPixmap <> nil then
  begin
    Result.y := ParentPixmap^.height;
    Result.x := ParentPixmap^.width;
  end else
  if Gtk3IsGdkWindow(Window) then
  begin
    Result.X := Window^.get_width;
    Result.y := Window^.get_height;
  end;
end;

function TGtk3DeviceContext.LineTo(X, Y: Integer): Boolean;
var
  FX, FY: Double;
  X0, Y0,dx,dy:integer;
begin
  if not Assigned(pcr) then
    exit(False);
  ApplyPen;


  if fCurrentPen.Width<=1 then // optimizations
  begin
    cairo_get_current_point(pcr, @FX, @FY);
    X0:=round(FX);
    Y0:=round(FY);
    dx:=X-X0;
    dy:=Y-Y0;

    if (dx=0) and (dy=0) then exit;

    if (dx=0) then
    begin
      cairo_move_to(pcr,X+PixelOffset,Y0);
      cairo_line_to(pcr,X+PixelOffset,Y);
    end else
    if (dy=0) then
    begin
      cairo_move_to(pcr,X0,Y+PixelOffset);
      cairo_line_to(pcr,X,Y+PixelOffset);
    end else
    if abs(dx)=abs(dy) then
    begin
      // here is required more Cairo magic
      if (dx>0) then
      begin
        cairo_move_to(pcr,FX-PixelOffset,FY-PixelOffset);
        cairo_line_to(pcr,X+2*PixelOffset, Y+2*PixelOffset);
      end else
      begin
        cairo_move_to(pcr,FX+2*PixelOffset,FY);
        cairo_line_to(pcr,X+PixelOffset, Y+PixelOffset);
      end;
    end else
      cairo_line_to(pcr,X+PixelOffset, Y+PixelOffset);

  end else
    cairo_line_to(pcr,X+PixelOffset, Y+PixelOffset);

  cairo_stroke(pcr);
  Result := True;
end;

function TGtk3DeviceContext.MoveTo(const X, Y: Integer; OldPoint: PPoint): Boolean;
var
  dx: Double;
  dy: Double;
begin
  if not Assigned(pcr) then
    exit(False);
  if OldPoint <> nil then
  begin
    cairo_get_current_point(pcr, @dx, @dy);
    OldPoint^.X := Round(dx);
    OldPoint^.Y := Round(dy);
  end;
  cairo_move_to(pcr, X{-PixelOffset}, Y{-PixelOffset});
  Result := True;
end;

function TGtk3DeviceContext.SetClipRegion(ARgn: TGtk3Region): Integer;
begin
  Result := SimpleRegion;
  if Assigned(pcr) then
  begin
    cairo_reset_clip(pcr);
    gdk_cairo_region(pcr, ARgn.FHandle);
    cairo_clip(pcr);
  end;
end;

procedure TGtk3DeviceContext.SetSourceColor(AColor: TColor);
var
  R, G, B: double;
begin
  TColorToRGB(AColor, R, G, B);
  cairo_set_source_rgb(pcr, R, G, B);
end;

procedure TGtk3DeviceContext.SetImage(AImage: TGtk3Image);
var
  APixBuf: PGdkPixbuf;
begin
  FCurrentImage := AImage;
  cairo_destroy(pcr);
  APixBuf := AImage.Handle;
  if not Gtk3IsGdkPixbuf(APixBuf) then
  begin
    DebugLn('ERROR: TGtk3DeviceContext.SetImage image handle isn''t PGdkPixbuf.');
    exit;
  end;
  (*
  DebugLn('TGtk3DeviceContext.SetImage w=',dbgs(APixBuf^.width),' h=',dbgs(APixBuf^.height),
  ' RowStride ',dbgs(APixBuf^.rowstride),' BPS=',dbgs(APixBuf^.get_bits_per_sample),
  ' BLEN ',dbgs(APixbuf^.get_byte_length),' channels ',dbgs(APixBuf^.get_n_channels),
  ' ALPHA ',dbgs(APixbuf^.get_has_alpha));
  *)
  if FOwnsSurface and (CairoSurface <> nil) then
    cairo_surface_destroy(CairoSurface);
  CairoSurface := cairo_image_surface_create_for_data(APixBuf^.pixels,
                                                AImage.Format,
                                                APixBuf^.get_width,
                                                APixBuf^.get_height,
                                                APixBuf^.rowstride);
  pcr := cairo_create(CairoSurface);
  FOwnsSurface := true;
end;

function TGtk3DeviceContext.ResetClip: Integer;
begin
  Result := NullRegion;
  if Assigned(pcr) then
    cairo_reset_clip(pcr);
end;

procedure TGtk3DeviceContext.TranslateCairoToDevice;
var
  Pt: TPoint;
begin
  Pt := Offset;
  Translate(Pt);
end;

procedure TGtk3DeviceContext.Translate(APoint: TPoint);
begin
  cairo_translate(pcr, APoint.X, APoint.Y);
end;

procedure TGtk3DeviceContext.set_antialiasing(aamode: boolean);
const
   caa:array[boolean] of cairo_antialias_t = (CAIRO_ANTIALIAS_NONE,CAIRO_ANTIALIAS_DEFAULT);
begin
  cairo_set_antialias(pcr, caa[aamode]);
end;


//various routines for text , copied from gtk2.

function ReplaceAmpersandsWithUnderscores(const S: string): string; inline;
begin
  Result := StringReplace(S, '_', '__', [rfReplaceAll]);
  Result := StringReplace(Result, '&', '_', [rfReplaceAll]);
end;

{-------------------------------------------------------------------------------
  function GetTextExtentIgnoringAmpersands(TheFont: PGDKFont;
    Str : PChar; StrLength: integer;
    MaxWidth: Longint; lbearing, rbearing, width, ascent, descent : Pgint);

  Gets text extent of a string, ignoring escaped Ampersands.
  That means, ampersands are not counted.
  Negative MaxWidth means no limit.
-------------------------------------------------------------------------------}
procedure GetTextExtentIgnoringAmpersands(TheFont: TGtk3Font;
  Str : PChar; StrLength: integer;
  lbearing, rbearing, width, ascent, descent : Pgint);
var
  NewStr : PChar;
  AMetrics: PPangoFontMetrics;
  {ACharWidth,}ATextWidth,ATextHeight: gint;
begin
  if lbearing<>nil then
    lbearing^:=0;
  if rbearing<>nil then
    rbearing^:=0;
  // check if Str contains an ampersand before removing them all.
  if StrLScan(Str, '&', StrLength) <> nil then
    NewStr := RemoveAmpersands(Str, StrLength)
  else
    NewStr := Str;
  TheFont.Layout^.set_text(NewStr, StrLength);
  // TheFont.Layout^.get_extents(@AInkRect, @ALogicalRect);

  AMetrics := pango_context_get_metrics(TheFont.Layout^.get_context, TheFont.Handle, TheFont.Layout^.get_context^.get_language);
  // if not Gtk3IsPangoFontMetrics(PGObject(AMetrics)) then
  //  exit;
  if AMetrics = nil then
  begin
    Debugln('WARNING: GetTextExtentIgnoringAmpersands AMetrics=nil');
    exit;
  end;

  if ascent <> nil then
    ascent^ := AMetrics^.get_ascent;
  if descent <> nil then
    descent^ := AMetrics^.get_descent;
  if width <> nil then
  begin
    {ACharWidth := AMetrics^.get_approximate_char_width;
    width^ := (utf8length(Str, StrLength) * ACharWidth) div PANGO_SCALE;}
    TheFont.Layout^.get_pixel_size(@ATextWidth, @ATextHeight);
    width^:=ATextWidth;
  end;
  // PANGO_PIXELS(char_width)

  // lBearing^ := 0;
  // rBearing^ := 0;
  // gdk_text_extents(TheFont, NewStr, StrLength,
  //                 lbearing, rBearing, width, ascent, descent);
  if NewStr <> Str then
    StrDispose(NewStr);
  AMetrics^.unref;
end;

{------------------------------------------------------------------------------
  procedure Gtk3WordWrap(DC: HDC; AText: PChar; MaxWidthInPixel: integer;
    var Lines: PPChar; var LineCount: integer); virtual;

  Breaks AText into several lines and creates a list of PChar. The last entry
  will be nil.
  Lines break at new line chars and at spaces if a line is longer than
  MaxWidthInPixel or in a word.
  Lines will be one memory block so that you can free the list and all lines
  with FreeMem(Lines).
------------------------------------------------------------------------------}
procedure Gtk3WordWrap(DC: HDC; AText: PChar;
  MaxWidthInPixel: integer; out Lines: PPChar; out LineCount: integer);
var
  UseFont: TGtk3Font;

  function GetLineWidthInPixel(LineStart, LineLen: integer): integer;
  var
    width: LongInt;
  begin
    GetTextExtentIgnoringAmpersands(UseFont, @AText[LineStart], LineLen,
                                    nil, nil, @width, nil, nil);
    Result := Width;
  end;

  function FindLineEnd(LineStart: integer): integer;
  var
    CharLen,
    LineStop,
    LineWidth, WordWidth, WordEnd, CharWidth: integer;
  begin
    // first search line break or text break
    Result:=LineStart;
    while not (AText[Result] in [#0,#10,#13]) do inc(Result);
    if Result<=LineStart+1 then exit;
    lineStop:=Result;

    // get current line width in pixel
    LineWidth:=GetLineWidthInPixel(LineStart,Result-LineStart);
    if LineWidth>MaxWidthInPixel then
    begin
      // line too long
      // -> add words till line size reached
      LineWidth:=0;
      WordEnd:=LineStart;
      WordWidth:=0;
      repeat
        Result:=WordEnd;
        inc(LineWidth,WordWidth);
        // find word start
        while AText[WordEnd] in [' ',#9] do inc(WordEnd);
        // find word end
        while not (AText[WordEnd] in [#0,' ',#9,#10,#13]) do inc(WordEnd);
        // calculate word width
        WordWidth:=GetLineWidthInPixel(Result,WordEnd-Result);
      until LineWidth+WordWidth>MaxWidthInPixel;
      if LineWidth=0 then
      begin
        // the first word is longer than the maximum width
        // -> add chars till line size reached
        Result:=LineStart;
        LineWidth:=0;
        repeat
          charLen:=UTF8CodepointSize(@AText[result]);
          CharWidth:=GetLineWidthInPixel(Result,charLen);
          inc(LineWidth,CharWidth);
          if LineWidth>MaxWidthInPixel then break;
          if result>=lineStop then break;
          inc(Result,charLen);
        until false;
        // at least one char
        if Result=LineStart then begin
          charLen:=UTF8CodepointSize(@AText[result]);
          inc(Result,charLen);
        end;
      end;
    end;
  end;

  function IsEmptyText: boolean;
  begin
    if (AText=nil) or (AText[0]=#0) then
    begin
      // no text
      GetMem(Lines,SizeOf(PChar));
      Lines[0]:=nil;
      LineCount:=0;
      Result:=true;
    end else
      Result:=false;
  end;

  procedure InitFont;
  begin
    UseFont := TGtk3DeviceContext(DC).CurrentFont;
  end;

var
  LinesList: TIntegerList;
  LineStart, LineEnd, LineLen: integer;
  ArraySize, TotalSize: integer;
  i: integer;
  CurLineEntry: PPChar;
  CurLineStart: PChar;
begin
  if IsEmptyText then
  begin
    Lines:=nil;
    LineCount:=0;
    exit;
  end;
  InitFont;
  LinesList:=TIntegerList.Create;
  LineStart:=0;

  // find all line starts and line ends
  repeat
    LinesList.Add(LineStart);
    // find line end
    LineEnd:=FindLineEnd(LineStart);
    LinesList.Add(LineEnd);
    // find next line start
    LineStart:=LineEnd;
    if AText[LineStart] in [#10,#13] then
    begin
      // skip new line chars
      inc(LineStart);
      if (AText[LineStart] in [#10,#13])
      and (AText[LineStart]<>AText[LineStart-1]) then
        inc(LineStart);
    end else
    if AText[LineStart] in [' ',#9] then
    begin
      // skip space
      while AText[LineStart] in [' ',#9] do
        inc(LineStart);
    end;
  until AText[LineStart]=#0;

  // create mem block for 'Lines': array of PChar + all lines
  LineCount:=LinesList.Count shr 1;
  ArraySize:=(LineCount+1)*SizeOf(PChar);
  TotalSize:=ArraySize;
  i:=0;
  while i<LinesList.Count do
  begin
    // add  LineEnd - LineStart + 1 for the #0
    LineLen:=LinesList[i+1]-LinesList[i]+1;
    inc(TotalSize,LineLen);
    inc(i,2);
  end;
  GetMem(Lines,TotalSize);
  FillChar(Lines^,TotalSize,0);

  // create Lines
  CurLineEntry:=Lines;
  CurLineStart:=PChar(CurLineEntry)+ArraySize;
  i:=0;
  while i<LinesList.Count do
  begin
    // set the pointer to the start of the current line
    CurLineEntry[i shr 1]:=CurLineStart;
    // copy the line
    LineStart:=LinesList[i];
    LineEnd:=LinesList[i+1];
    LineLen:=LineEnd-LineStart;
    if LineLen>0 then
      Move(AText[LineStart],CurLineStart^,LineLen);
    inc(CurLineStart,LineLen);
    // add #0 as line end
    CurLineStart^:=#0;
    inc(CurLineStart);
    // next line
    inc(i,2);
  end;
  if {%H-}PtrUInt(CurLineStart)-{%H-}PtrUInt(Lines)<>TotalSize then
    RaiseGDBException('Gtk3WordWrap Consistency Error:'
      +' Lines+TotalSize<>CurLineStart');
  CurLineEntry[i shr 1]:=nil;

  LinesList.Free;
end;

end.

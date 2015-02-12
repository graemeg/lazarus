{                 ------------------------------------------
                  carbongdiobjects.pp  -  Carbon GDI objects
                  ------------------------------------------

 *****************************************************************************
  This file is part of the Lazarus Component Library (LCL)

  See the file COPYING.modifiedLGPL.txt, included in this distribution,
  for details about the license.
 *****************************************************************************
}
unit CarbonGDIObjects;

{$mode objfpc}{$H+}
{.$define DumpRegion}
interface

// defines
{$I carbondefines.inc}

uses
 // rtl+fcl
  Types, Classes, SysUtils, Math,
 // carbon bindings
  MacOSAll,
 // LCL
  LCLProc, LCLType, GraphType, Graphics, Controls, Forms,
 // LCL Carbon
 {$ifdef DebugBitmaps}
  CarbonDebug,
 {$endif}
  CarbonDef;

type
  TCarbonBitmap = class;

  { TCarbonGDIObject }

  TCarbonGDIObject = class
  private
    FSelCount: Integer;
    FGlobal: Boolean;
  public
    constructor Create(AGlobal: Boolean);
    
    procedure Select;
    procedure Unselect;
    
    property Global: Boolean read FGlobal;
    property SelCount: Integer read FSelCount;
  end;
  
  { TCarbonRegion }

  TCarbonRegion = class(TCarbonGDIObject)
  private
    FShape: HIShapeRef;
  public
    constructor Create;
    constructor Create(const X1, Y1, X2, Y2: Integer);
    constructor Create(Points: PPoint; NumPts: Integer; FillMode: Integer);
    constructor CreateEllipse(X1, Y1, X2, Y2: Integer);
    destructor Destroy; override;
    
    procedure Apply(ADC: TCarbonContext);
    function GetBounds: TRect;
    function GetType: Integer;
    function ContainsPoint(const P: TPoint): Boolean;
    procedure SetShape(AShape: HIShapeRef);
    function CombineWith(ARegion: TCarbonRegion; CombineMode: Integer): Integer;
    procedure Offset(dx, dy: Integer);
    function GetShapeCopy: HIShapeRef;
    procedure MakeMutable;
  public
    property Shape: HIShapeRef read FShape write SetShape;
  end;
  
  TCarbonFont = class;
  
  { TCarbonTextLayout }

  TCarbonTextLayout = class
  private
    FTextBefore: ATSUTextMeasurement;
    FTextAfter: ATSUTextMeasurement;
    FAscent: ATSUTextMeasurement;
    FDescent: ATSUTextMeasurement;
    FLineRotation: Fixed;
  public
    procedure Apply(ADC: TCarbonContext); virtual; abstract;
    function Draw(X, Y: Integer; DX: PInteger; DXCount: Integer): Boolean; virtual; abstract;
    procedure Release; virtual;

    function GetHeight: Integer;
    function GetWidth: Integer;
    function GetDrawBounds(X, Y: Integer): CGRect;

    property TextBefore: ATSUTextMeasurement read FTextBefore;
    property TextAfter: ATSUTextMeasurement read FTextAfter;
    property Ascent: ATSUTextMeasurement read FAscent;
    property Descent: ATSUTextMeasurement read FDescent;
  end;
  
  { TCarbonTextLayoutBuffer }

  TCarbonTextLayoutBuffer = class(TCarbonTextLayout)
  private
    FLayout: ATSUTextLayout;
    FWidget: HIViewRef;
    FTextBuffer: WideString;
    FDC: TCarbonContext;
    FDXCount: Integer;
    FDX: PInteger;
    Idx: Integer;
  protected
    procedure DoJustify(iLineRef: ATSULineRef; var Handled: Boolean);
  public
    constructor Create(const Text: String; Font: TCarbonFont; TextFractional: Boolean);
    procedure Apply(ADC: TCarbonContext); override;
    function Draw(X, Y: Integer; DX: PInteger; DXCount: Integer): Boolean; override;
    procedure Release; override;

    property Layout: ATSUTextLayout read FLayout;
    property TextBuffer: WideString read FTextBuffer;
  end;
  
  { TCarbonTextLayoutArray }

  TCarbonTextLayoutArray = class(TCarbonTextLayout)
  private
    FText: String;
    FFont: TCarbonFont;
  public
    constructor Create(const Text: String; Font: TCarbonFont);
    procedure Apply(ADC: TCarbonContext); override;
    function Draw(X, Y: Integer; DX: PInteger; DXCount: Integer): Boolean; override;
  end;

  { TCarbonFont }

  TCarbonFont = class(TCarbonGDIObject)
  private
    FStyle: ATSUStyle;
    FLineRotation: Fixed;
    FCachedLayouts: Array of TCarbonTextLayoutBuffer;
  public
    constructor Create(AGlobal: Boolean); // default system font
    constructor Create(ALogFont: TLogFont; const AFaceName: String);
    function CreateStyle(ALogFont: TLogFont; const AFaceName: String): ATSUStyle;
    procedure QueryStyle(ALogFont: PLogFont);
    destructor Destroy; override;
    procedure SetColor(AColor: TColor);
    
    function CreateTextLayout(const Text: String; TextFractional: Boolean): TCarbonTextLayout;
  public
    property LineRotation: Fixed read FLineRotation;
    property Style: ATSUStyle read FStyle;
  end;

  { TCarbonColorObject }

  TCarbonColorObject = class(TCarbonGDIObject)
  private
    FR, FG, FB: Byte;
    FA: Boolean; // alpha: True - solid, False - clear
    function GetColorRef: TColorRef;
  public
    constructor Create(const AColor: TColor; ASolid, AGlobal: Boolean);
    procedure SetColor(const AColor: TColor; ASolid: Boolean);
    procedure GetRGBA(AROP2: Integer; out AR, AG, AB, AA: Single);
    function CreateCGColor: CGColorRef;
    
    property Red: Byte read FR write FR;
    property Green: Byte read FG write FG;
    property Blue: Byte read FB write FB;
    property Solid: Boolean read FA write FA;
    property ColorRef: TColorRef read GetColorRef;
  end;

  { TCarbonBrush }

  TCarbonBrush = class(TCarbonColorObject)
  private
    FCGPattern: CGPatternRef;
    FColored: Boolean;
    FBitmap: TCarbonBitmap;
  protected
    procedure SetHatchStyle(AHatch: PtrInt);
    procedure SetBitmap(ABitmap: TCarbonBitmap);
  public
    constructor Create(AGlobal: Boolean); // create default brush
    constructor Create(ALogBrush: TLogBrush);
    destructor Destroy; override;
    procedure Apply(ADC: TCarbonContext; UseROP2: Boolean = True);
  end;

const
  // Paul Ishenin:
  // pen shapes are compared with windows shapes and now a bit to bit equal
  CarbonDashStyle: Array [0..1] of Single = (3, 1);
  CarbonDotStyle: Array [0..1] of Single = (1, 1);
  CarbonDashDotStyle: Array [0..3] of Single = (3, 1, 1, 1);
  CarbonDashDotDotStyle: Array [0..5] of Single = (3, 1, 1, 1, 1, 1);

type
  TCarbonDashes = array of Float32;

  { TCarbonPen }

  TCarbonPen = class(TCarbonColorObject)
  private
    FWidth: Integer;
    FStyle: LongWord;
    FIsExtPen: Boolean;
    FIsGeometric: Boolean;
    FEndCap: CGLineCap;
    FJoinStyle: CGLineJoin;
   public
    Dashes: TCarbonDashes;
    constructor Create(AGlobal: Boolean); // create default pen
    constructor Create(ALogPen: TLogPen);
    constructor Create(dwPenStyle, dwWidth: DWord; const lplb: TLogBrush; dwStyleCount: DWord; lpStyle: PDWord);
    procedure Apply(ADC: TCarbonContext; UseROP2: Boolean = True);
    
    property Width: Integer read FWidth;
    property Style: LongWord read FStyle;
    property IsExtPen: Boolean read FIsExtPen;
    property IsGeometric: Boolean read FIsGeometric;
    property JoinStyle: CGLineJoin read FJoinStyle;
    property CapStyle: CGLineCap read FEndCap;
  end;

  { TCarbonBitmap }
  
  TCarbonBitmapAlignment = (
    cbaByte,  // each line starts at byte boundary.
    cbaWord,  // each line starts at word (16bit) boundary
    cbaDWord, // each line starts at double word (32bit) boundary
    cbaQWord, // each line starts at quad word (64bit) boundary
    cbaDQWord // each line starts at double quad word (128bit) boundary
  );
  
  TCarbonBitmapType = (
    cbtMono,  // mask or mono bitmap
    cbtGray,  // grayscale bitmap
    cbtRGB,   // color bitmap 8-8-8 R-G-B
    cbtARGB,  // color bitmap with alpha channel first 8-8-8-8 A-R-G-B
    cbtRGBA,  // color bitmap with alpha channel last 8-8-8-8 R-G-B-A
    cbtBGR,   // color bitmap 8-8-8 B-G-R (windows compatible)
    cbtBGRA   // color bitmap with alpha channel 8-8-8-8 B-G-R-A (windows compatible)
  );
const
  cbtMask = cbtMono;
    

type
  TCarbonBitmap = class(TCarbonGDIObject)
  private
    FData: Pointer;
    FAlignment: TCarbonBitmapAlignment;
    FFreeData: Boolean;
    FDataSize: Integer;
    FBytesPerRow: Integer;
    FDepth: Byte;
    FBitsPerPixel: Byte;
    FWidth: Integer;
    FHeight: Integer;
    FType: TCarbonBitmapType;
    FCGImage: CGImageRef;
    function GetBitsPerComponent: Integer;
    function GetColorSpace: CGColorSpaceRef;
    function GetInfo: CGBitmapInfo;
    procedure SetCGImage(const AValue: CGImageRef);
  public
    constructor Create(AWidth, AHeight, ADepth, ABitsPerPixel: Integer;
      AAlignment: TCarbonBitmapAlignment; AType: TCarbonBitmapType;
      AData: Pointer; ACopyData: Boolean = True);
    constructor Create(ABitmap: TCarbonBitmap);
    destructor Destroy; override;
    procedure SetInfo(AWidth, AHeight, ADepth, ABitsPerPixel: Integer;
      AAlignment: TCarbonBitmapAlignment; AType: TCarbonBitmapType);
    procedure UpdateImage;
    procedure UpdateInfo;
    function CreateSubImage(const ARect: TRect): CGImageRef;
    function CreateMaskImage(const ARect: TRect): CGImageRef;
    function CreateMaskedImage(AMask: TCarbonBitmap): CGImageRef;
    function CreateMaskedImage(AMask: TCarbonBitmap; const ARect: TRect): CGImageRef;
    procedure AddMask(AMask: TCarbonBitmap);
  public
    property BitsPerComponent: Integer read GetBitsPerComponent;
    property BitmapType: TCarbonBitmapType read FType;
    property BytesPerRow: Integer read FBytesPerRow;
    property CGImage: CGImageRef read FCGImage write SetCGImage;
    property ColorSpace: CGColorSpaceRef read GetColorSpace;
    property Data: Pointer read FData;
    property DataSize: Integer read FDataSize;
    property Depth: Byte read FDepth;
    property Info: CGBitmapInfo read GetInfo;
    property Width: Integer read FWidth;
    property Height: Integer read FHeight;
  end;

const
  kThemeUndefCursor = ThemeCursor(-1); // undefined mac theme cursor
  
  CursorToThemeCursor: array[crLow..crHigh] of ThemeCursor =
    ({crSizeSE      } kThemeResizeRightCursor, {!!}
     {crSizeS       } kThemeResizeDownCursor,
     {crSizeSW      } kThemeResizeLeftCursor, {!!}
     {crSizeE       } kThemeResizeRightCursor,
     {crSizeW       } kThemeResizeLeftCursor,
     {crSizeNE      } kThemeResizeRightCursor, {!!}
     {crSizeN       } kThemeResizeUpCursor,
     {crSizeNW      } kThemeResizeLeftCursor, {!!}
     {crSizeAll     } kThemeUndefCursor,           // will be loaded from resource
     {crHandPoint   } kThemePointingHandCursor,
     {crHelp        } kThemeUndefCursor,           // will be loaded from resource
     {crAppStart    } kThemeSpinningCursor,
     {crNo          } kThemeUndefCursor,
     {crSQLWait     } kThemeUndefCursor,           // will be loaded from resource
     {crMultiDrag   } kThemeUndefCursor,           // will be loaded from resource
     {crVSplit      } kThemeResizeUpDownCursor,
     {crHSplit      } kThemeResizeLeftRightCursor,
     {crNoDrop      } kThemeNotAllowedCursor, 
     {crDrag        } kThemeCopyArrowCursor,
     {crHourGlass   } kThemeSpinningCursor,
     {crUpArrow     } kThemeUndefCursor,           // will be loaded from resource
     {crSizeWE      } kThemeResizeLeftRightCursor,
     {crSizeNWSE    } kThemeResizeLeftRightCursor, {!!}
     {crSizeNS      } kThemeResizeUpDownCursor, {!!}
     {crSizeNESW    } kThemeResizeLeftRightCursor, {!!}
     {undefined     } kThemeArrowCursor, {!!}
     {crIBeam       } kThemeIBeamCursor,
     {crCross       } kThemeCrossCursor,
     {crArrow       } kThemeArrowCursor,
     {crNone        } kThemeUndefCursor,
     {crDefault     } kThemeArrowCursor);

type
  TCarbonCursorType =
  (
    cctUnknown,    // undefined
    cctQDHardware, // QuickDraw hardware cursor
    cctQDColor,    // QuickDraw Color cursor
    cctTheme,      // theme cursor
    cctAnimated,   // animated theme cursor
    cctWait        // special wait cursor
  );
  { TCarbonCursor }
  
  TCarbonCursor = class(TCarbonGDIObject)
  private
    FCursorType: TCarbonCursorType;
    FDefault: Boolean;
    FThemeCursor: ThemeCursor;
    // animation
    FAnimationStep: Integer;
    FTaskID: MPTaskID;
    // color cursors
    FQDColorCursorHandle: CCrsrHandle;
    FQDHardwareCursorName: String;
    FPixmapHandle: PixmapHandle;
    procedure CreateThread;
    procedure DestroyThread;
  protected
    procedure CreateHardwareCursor(ABitmap: TCarbonBitmap; AHotSpot: Point);
    procedure CreateColorCursor(ABitmap: TCarbonBitmap; AHotSpot: Point);
  public
    constructor Create;
    constructor CreateFromInfo(AInfo: PIconInfo);
    constructor CreateThemed(AThemeCursor: ThemeCursor; ADefault: Boolean = False);
    destructor Destroy; override;

    procedure Install;
    procedure UnInstall;
    function StepAnimation: Boolean;
    class function HardwareCursorsSupported: Boolean;
  public
    property CursorType: TCarbonCursorType read FCursorType;
    property Default: Boolean read FDefault;
  end;
  
function CheckGDIObject(const GDIObject: HGDIOBJ; const AMethodName: String; AParamName: String = ''): Boolean;
function CheckBitmap(const Bitmap: HBITMAP; const AMethodName: String; AParamName: String = ''): Boolean;
function CheckCursor(const Cursor: HCURSOR; const AMethodName: String; AParamName: String = ''): Boolean;

function FloodFillBitmap(const Bitmap: TCarbonBitmap; X,Y: Integer; {%H-}ABorderColor, FillColor: TColor; {%H-}isBorderColor: Boolean): Boolean;

var
  StockSystemFont: TCarbonFont;
  StockNullBrush: TCarbonBrush;
  WhiteBrush: TCarbonBrush;
  BlackPen: TCarbonPen;
  
  DefaultFont: TCarbonFont;
  DefaultBrush: TCarbonBrush;
  DefaultPen: TCarbonPen;

  DefaultBitmap: TCarbonBitmap; // 1 x 1 bitmap for default context
  
implementation

uses
  LazUTF8, CarbonInt, CarbonProc, CarbonCanvas, CarbonDbgConsts;

const
  BITMAPINFOMAP: array[TCarbonBitmapType] of CGBitmapInfo = (
    {cbtMask} kCGImageAlphaNone,
    {cbtGray} kCGImageAlphaNone,
    {cbtRGB}  kCGImageAlphaNoneSkipFirst,
    {cbtARGB} kCGImageAlphaFirst,
    {cbtRGBA} kCGImageAlphaLast,
    {cbtBGR}  kCGImageAlphaNoneSkipFirst or kCGBitmapByteOrder32Little,
    {cbtBGRA} kCGImageAlphaFirst or kCGBitmapByteOrder32Little
  );

type

  { TScanObject }

  TScanObject = class
    Shape: HIShapeRef;
    fX, fY, fW, fH: Integer;
    Data: Pointer;
    Context: CGContextRef;
    constructor create(aShape: HIShapeRef; aX, aY, aW, aH: Integer);
    destructor destroy; override;
    procedure AddPart(X1, X2, Y: Integer);
    function Setup: boolean;
    procedure Scan;
    procedure ScanConvex;
  end;


constructor TScanObject.create(aShape: HIShapeRef; aX, aY, aW, aH: Integer);
begin
  inherited Create;
  Shape := aShape;
  fX := aX;
  fY := aY;
  fW := aW;
  fH := aH;
end;


destructor TScanObject.destroy;
begin
  if Context<>nil then
    CGContextRelease(Context);
  if Data<>nil then
    System.Freemem(Data);
  inherited Destroy;
end;

function TScanObject.Setup: boolean;
begin
  System.GetMem(Data, fW * fH);
  System.FillChar(Data^, fW * fH, 0);
  try
    Context := CGBitmapContextCreate(Data, fW, fH, 8, fW, GrayColorSpace, kCGImageAlphaNone);
    CGContextSetShouldAntialias(Context, 0); // disable anti-aliasing
    CGContextSetGrayFillColor(Context, 1.0, 1.0); // draw white polygon
    CGContextTranslateCTM(Context, -fx, -fy); // Translate origin so we draw at 0,0
    result := true;
  except
    result := false;
  end;
end;

procedure TScanObject.AddPart(X1, X2, Y: Integer);
var
  R: HIShapeRef;
begin
  //DebugLn('AddPart:' + DbgS(X1) + ' - ' + DbgS(X2) + ', ' + DbgS(Y));
  R := HIShapeCreateWithRect(GetCGRect(X1, Y, X2, Y + 1));
  OSError(HIShapeUnion(Shape, R, Shape), Self, 'AddPart', 'HIShapeUnion');
  CFRelease(R);
end;

procedure TScanObject.Scan;
var
  PData: PByte;
  X, Y, SX: Integer;
  LC, C: Byte;
  {$ifdef DumpRegion}
  Line: string;
  {$endif}
begin
  // scan shape
  {$ifdef DumpRegion}
  DebugLn;
  DebugLn('SCAN: X=%d Y=%d W=%d H=%d',[fX,fY,fW,fH]);
  SetLength(Line, fW);
  {$endif}

  PData := Data;
  for Y := 0 to Pred(fH) do
  begin
    LC := 0; // edge is black
    Sx := -1;
    for X := 0 to Pred(fW) do
    begin
      C := PData^;
      {$ifdef DumpRegion}
      Line[X + 1] := Chr(Ord('0') + C div 255);
      {$endif}

      if (C = $FF) and (LC = 0) then
        SX := X; // start of painted row part
      if (SX>=0) and (LC = $FF) and ((C = 0) or (x=Pred(fw))) then
        // end of painted row part (SX, X)
        AddPart(fx + SX, fx + X,  fy + Pred(fH) - Y);

      LC := C;
      Inc(PData);
    end;
    {$ifdef DumpRegion}
    DebugLn('%.3d: %s',[Pred(fH) - Y,Line]);
    {$endif}
  end;
end;

procedure TScanObject.ScanConvex;
var
  PData, P: PByte;
  X, Xe, Y, SX,EX: Integer;
  {$ifdef DumpRegion}
  Line: string;
  {$endif}
  found, noted: boolean;
begin
  // scan shape
  {$ifdef DumpRegion}
  DebugLn;
  DebugLn('SCANCONVEX: X=%d Y=%d W=%d H=%d',[fX,fY,fW,fH]);
  SetLength(Line, fW);
  {$endif}

  noted := false;
  PData := Data;
  for Y := 0 to Pred(fH) do
  begin
    P := PData;
    {$ifdef DumpRegion}
    for X:=0 to Pred(fW) do Line[X+1] := Chr(Ord('0') + P[X] div 255);
    {$endif}
    SX := -1; EX := -1;
    for X := 0 to Pred(fW) do
    begin
      Xe := Pred(fW)-X;
      if (SX=-1) and (P[X]=$FF) then SX := X;
      if (EX=-1) and (P[Xe]=$FF) then EX := Xe;
      found := (EX>=0) and (SX>=0);
      if found or (Xe<=X) then
        break;
    end;
    // just in case ....
    if not found then
    begin
      if (Sx>=0) then begin Ex := Pred(fW); found := true; end;
      if (Ex>=0) then begin Sx := 0; found := true; end;
      if not noted and found then begin
        noted := true;
        DebugLn('NOTE: ScanObj: broken convex!');
      end;
    end;

    inc(PData, fW);
    if found then
      AddPart(fX + SX, fX + Ex + 1,  fY + Pred(fH) - Y);
    {$ifdef DumpRegion}
    DebugLn('%.3d: %s did=%s',[Pred(fH) - Y,Line,dbgs(found)]);
    {$endif}
  end;
end;


{------------------------------------------------------------------------------
  Name:    CheckGDIObject
  Params:  GDIObject   - Handle to a GDI Object (TCarbonFont, ...)
           AMethodName - Method name
           AParamName  - Param name
  Returns: If the GDIObject is valid

  Remark: All handles for GDI objects must be pascal objects so we can
 distinguish between them
 ------------------------------------------------------------------------------}
function CheckGDIObject(const GDIObject: HGDIOBJ; const AMethodName: String;
  AParamName: String): Boolean;
begin
  if TObject(GDIObject) is TCarbonGDIObject then Result := True
  else
  begin
    Result := False;
    
    if Pos('.', AMethodName) = 0 then
      DebugLn(SCarbonWSPrefix + AMethodName + ' Error - invalid GDIObject ' +
        AParamName + ' = ' + DbgS(GDIObject) + '!')
    else
      DebugLn(AMethodName + ' Error - invalid GDIObject ' + AParamName + ' = ' +
        DbgS(GDIObject) + '!');
  end;
end;

{------------------------------------------------------------------------------
  Name:    CheckBitmap
  Params:  Bitmap      - Handle to a bitmap (TCarbonBitmap)
           AMethodName - Method name
           AParamName  - Param name
  Returns: If the bitmap is valid
 ------------------------------------------------------------------------------}
function CheckBitmap(const Bitmap: HBITMAP; const AMethodName: String;
  AParamName: String): Boolean;
begin
  if TObject(Bitmap) is TCarbonBitmap then Result := True
  else
  begin
    Result := False;
    
    if Pos('.', AMethodName) = 0 then
      DebugLn(SCarbonWSPrefix + AMethodName + ' Error - invalid bitmap ' +
        AParamName + ' = ' + DbgS(Bitmap) + '!')
    else
      DebugLn(AMethodName + ' Error - invalid bitmap ' + AParamName + ' = ' +
        DbgS(Bitmap) + '!');
  end;
end;

{------------------------------------------------------------------------------
  Name:    CheckCursor
  Params:  Cursor      - Handle to a cursor (TCarbonCursor)
           AMethodName - Method name
           AParamName  - Param name
  Returns: If the cursor is valid
 ------------------------------------------------------------------------------}
function CheckCursor(const Cursor: HCURSOR; const AMethodName: String;
  AParamName: String): Boolean;
begin
  if TObject(Cursor) is TCarbonCursor then Result := True
  else
  begin
    Result := False;

    if Pos('.', AMethodName) = 0 then
      DebugLn(SCarbonWSPrefix + AMethodName + ' Error - invalid cursor ' +
        AParamName + ' = ' + DbgS(Cursor) + '!')
    else
      DebugLn(AMethodName + ' Error - invalid cursor ' + AParamName + ' = ' +
        DbgS(Cursor) + '!');
  end;
end;

type
  THardwareCursorsAvailability =
  (
    hcaUndef,
    hcaAvailable,
    hcaUnavailable
  );

const
// missed error codes
  kQDNoColorHWCursorSupport = -3951;
  {%H-}kQDCursorAlreadyRegistered = -3952;
  {%H-}kQDCursorNotRegistered = -3953;
  {%H-}kQDCorruptPICTDataErr = -3954;
  
  kThemeCursorAnimationDelay = 70;
  LazarusCursorInfix = '_lazarus_';

var
  MHardwareCursorsSupported: THardwareCursorsAvailability = hcaUndef;

{------------------------------------------------------------------------------
  Name: AnimationCursorHandler
  Handles cursor animation steps
 ------------------------------------------------------------------------------}
function AnimationCursorHandler(parameter: UnivPtr): OSStatus;
  {$IFDEF darwin}mwpascal;{$ENDIF}
begin
  Result := noErr;
  while True do
  begin
    if TCarbonCursor(parameter).StepAnimation then
      Sleep(kThemeCursorAnimationDelay) else
      break;
  end;
end;

{ TCarbonGDIObject }

{------------------------------------------------------------------------------
  Method:  TCarbonGDIObject.Create
  Params:  AGlobal - Global

  Creates custom GDI object
 ------------------------------------------------------------------------------}
constructor TCarbonGDIObject.Create(AGlobal: Boolean);
begin
  FSelCount := 0;
  FGlobal := AGlobal;
end;

{------------------------------------------------------------------------------
  Method:  TCarbonGDIObject.Select

  Selects custom GDI object
 ------------------------------------------------------------------------------}
procedure TCarbonGDIObject.Select;
begin
  if FGlobal then Exit;
  Inc(FSelCount);
end;

{------------------------------------------------------------------------------
  Method:  TCarbonGDIObject.Unselect

  Unselects custom GDI object
 ------------------------------------------------------------------------------}
procedure TCarbonGDIObject.Unselect;
begin
  if FGlobal then Exit;
  if FSelCount > 0 then
    Dec(FSelCount)
  else
  begin
    DebugLn('TCarbonGDIObject.Unselect Error - ', DbgSName(Self), ' SelCount = ',
      DbgS(FSelCount), '!');
  end;
end;

{ TCarbonRegion }

{------------------------------------------------------------------------------
  Method:  TCarbonRegion.Create

  Creates a new empty Carbon region
 ------------------------------------------------------------------------------}
constructor TCarbonRegion.Create;
begin
  inherited Create(False);
  
  FShape := HIShapeCreateEmpty;
end;

{------------------------------------------------------------------------------
  Method:  TCarbonRegion.Create
  Params:  X1, Y1, X2, Y2 - Region bounding rectangle

  Creates a new rectangular Carbon region
 ------------------------------------------------------------------------------}
constructor TCarbonRegion.Create(const X1, Y1, X2, Y2: Integer);
begin
  inherited Create(False);
  
  FShape := HIShapeCreateWithRect(GetCGRectSorted(X1, Y1, X2, Y2));
end;

{------------------------------------------------------------------------------
  Method:  TCarbonRegion.Create
  Params:  Points   - Pointer to array of polygon points
           NumPts   - Number of points passed
           FillMode - Filling mode

  Creates a new polygonal Carbon region from the specified points
 ------------------------------------------------------------------------------}
constructor TCarbonRegion.Create(Points: PPoint; NumPts: Integer;
  FillMode: Integer);
var
  Bounds: TRect;
  ScanObj: TScanObject;
  P: PPoint;
  I, W, H: Integer;

  function GetPolygonBounds: TRect;
  var
    I: Integer;
  begin
    P := Points;
    Result := Classes.Rect(P^.X, P^.Y, P^.X, P^.Y);
    for I := 1 to NumPts - 1 do
    begin
      Inc(P);
      if P^.X < Result.Left then Result.Left := P^.X;
      if P^.X > Result.Right then Result.Right := P^.X;
      if P^.Y < Result.Top then Result.Top := P^.Y;
      if P^.Y > Result.Bottom then Result.Bottom := P^.Y;
    end;
  end;

begin
  inherited Create(False);
  
(*
  The passed polygon is drawed into grayscale context, the region is constructed
  per rows from rectangles of drawed polygon parts.
  *)
  
  FShape := HIShapeCreateMutable;
  
  if (NumPts <= 2) or (Points = nil) then Exit;
  Bounds := GetPolygonBounds;
  // DebugLn('TCarbonRegion.Create Bounds:' + DbgS(Bounds));
  W := Bounds.Right - Bounds.Left + 2;
  H := Bounds.Bottom - Bounds.Top + 2;
  
  if (W <= 0) or (H <= 0) then Exit;

  ScanObj := TScanObject.create(FShape, Bounds.Left, Bounds.Top, W, H);
  try
    if ScanObj.Setup then begin
      // draw object to scan
      P := Points;
      CGContextBeginPath(ScanObj.Context);
      CGContextMoveToPoint(ScanObj.Context, P^.X, P^.Y);
      for I := 1 to NumPts - 1 do
      begin
        Inc(P);
        CGContextAddLineToPoint(ScanObj.Context, P^.X, P^.Y);
      end;
      CGContextClosePath(ScanObj.Context);
      if FillMode = ALTERNATE then
        CGContextEOFillPath(ScanObj.Context)
      else
        CGContextFillPath(ScanObj.Context);

      // scan object in current path
      ScanObj.Scan;
    end;
  finally
    ScanObj.free;
  end;
end;

constructor TCarbonRegion.CreateEllipse(X1, Y1, X2, Y2: Integer);
var
  R: CGRect;
  ScanObj: TScanObject;
  i: Integer;
begin
  FShape := HIShapeCreateMutable;

  if X2<X1 then begin i:=X1; X1:=X2; X2:=i; end;
  if Y2<Y1 then begin i:=Y1; Y1:=Y2; Y2:=i; end;

  R := getCGRect(X1, Y1, X2, Y2);
  R.origin.x := R.origin.x + 0.5;
  R.origin.y := R.origin.y + 0.5;
  R.size.width := R.size.width - 1;
  R.size.height := R.size.height - 1;

  with R do
  ScanObj := TScanObject.create(FShape, X1, Y1, X2-X1+1, Y2-Y1+1);
  try
    with ScanObj do
    if Setup then begin
      CGContextSetGrayStrokeColor(Context, 1.0, 1.0); // draw white stroke
      CGContextSetGrayFillColor(Context, 0.0, 0.0); // draw black fill
      CGContextBeginPath(Context);
      CGContextAddEllipseInRect(Context, R);
      CGContextDrawPath(Context, kCGPathFillStroke);
      // scan object in current path
      ScanConvex;
    end;
  finally
    ScanObj.free;
  end;

end;

{------------------------------------------------------------------------------
  Method:  TCarbonRegion.Destroy

  Destroys Carbon region
 ------------------------------------------------------------------------------}
destructor TCarbonRegion.Destroy;
begin
  CFRelease(FShape);

  inherited Destroy;
end;

{------------------------------------------------------------------------------
  Method:  TCarbonRegion.Apply
  Params:  ADC - Context to apply to

  Applies region to the specified context
  Note: Clipping region is only reducing
 ------------------------------------------------------------------------------}
procedure TCarbonRegion.Apply(ADC: TCarbonContext);
var
  DeviceShape: HIShapeRef;
begin
  if ADC = nil then Exit;
  if ADC.CGContext = nil then Exit;
  DeviceShape := HIShapeCreateMutableCopy(Shape);
  try
    with ADC.GetLogicalOffset do
      HIShapeOffset(DeviceShape, -X, -Y);
    if HIShapeIsEmpty(DeviceShape) or OSError(HIShapeReplacePathInCGContext(DeviceShape, ADC.CGContext),
      Self, 'Apply', 'HIShapeReplacePathInCGContext') then Exit;
    CGContextClip(ADC.CGContext);
  finally
    CFRelease(DeviceShape);
  end;
end;

{------------------------------------------------------------------------------
  Method:  TCarbonRegion.GetBounds
  Returns: The bounding box of Carbon region
 ------------------------------------------------------------------------------}
function TCarbonRegion.GetBounds: TRect;
var
  R: HIRect;
begin
  if HIShapeGetBounds(FShape, R{%H-}) = nil then
  begin
    DebugLn('TCarbonRegion.GetBounds Error!');
    Exit;
  end;
  
  Result := CGRectToRect(R);
end;

{------------------------------------------------------------------------------
  Method:  TCarbonRegion.GetType
  Returns: The type of Carbon region
 ------------------------------------------------------------------------------}
function TCarbonRegion.GetType: Integer;
begin
  Result := ERROR;
  if HIShapeIsEmpty(FShape) then
    Result := NULLREGION
  else
  if HIShapeIsRectangular(FShape) then
    Result := SIMPLEREGION
  else
    Result := COMPLEXREGION;
end;

{------------------------------------------------------------------------------
  Method:  TCarbonRegion.ContainsPoint
  Params:  P - Point
  Returns: If the specified point lies in Carbon region
 ------------------------------------------------------------------------------}
function TCarbonRegion.ContainsPoint(const P: TPoint): Boolean;
begin
  Result := HIShapeContainsPoint(FShape, PointToHIPoint(P));
end;

procedure TCarbonRegion.SetShape(AShape: HIShapeRef);
begin
  if Assigned(FShape) then CFRelease(FShape);
  FShape := AShape;
end;

function TCarbonRegion.CombineWith(ARegion: TCarbonRegion; CombineMode: Integer): Integer;
var
  sh1, sh2: HIShapeRef;
const
  MinCoord=-35000;
  MaxSize=65000;
begin
  if not Assigned(ARegion) then
    Result := LCLType.Error
  else
  begin
    if (CombineMode in [RGN_AND, RGN_OR, RGN_XOR]) and HIShapeIsEmpty(FShape) then
      CombineMode := RGN_COPY;
      
    case CombineMode of
      RGN_AND:
        begin
          Shape := HIShapeCreateIntersection(FShape, ARegion.Shape);
          Result := GetType;
        end;
      RGN_XOR:
      begin
        sh1 := HIShapeCreateUnion(FShape, ARegion.Shape);
        sh2 := HIShapeCreateIntersection(FShape, ARegion.Shape);
        Shape := HIShapeCreateDifference(sh1, sh2);
        CFRelease(sh1);
        CFRelease(sh2);
        Result := GetType;
      end;
      RGN_OR:
        begin
          Shape := HIShapeCreateUnion(FShape, ARegion.Shape);
          Result := GetType;
        end;
      RGN_DIFF:
      begin
        if HIShapeIsEmpty(FShape) then
          {HIShapeCreateDifference doesn't work properly if original shape is empty}
          {to simulate "emptieness" very big shape is created }
          Shape := HIShapeCreateWithRect(GetCGRect(MinCoord, MinCoord, MaxSize, MaxSize)); // create clip nothing.

        Shape := HIShapeCreateDifference(FShape, ARegion.Shape);
        Result := GetType;
      end;
      RGN_COPY:
        begin
          Shape := HIShapeCreateCopy(ARegion.Shape);
          Result := GetType;
        end
    else
      Result := LCLType.Error;
    end;
  end;
end;

procedure TCarbonRegion.Offset(dx, dy: Integer);
begin
  MakeMutable;
  HIShapeOffset(FShape, dx, dy);
end;

function TCarbonRegion.GetShapeCopy: HIShapeRef;
begin
  Result := HIShapeCreateCopy(Shape);
end;

procedure TCarbonRegion.MakeMutable;
begin
  Shape := HIShapeCreateMutableCopy(Shape);
end;

{ TCarbonTextLayout }

procedure TCarbonTextLayout.Release;
begin
  Free;
end;

function TCarbonTextLayout.GetHeight: Integer;
begin
  Result := RoundFixed(Descent + Ascent);
end;

function TCarbonTextLayout.GetWidth: Integer;
begin
  Result := RoundFixed(TextAfter - TextBefore);
end;

function TCarbonTextLayout.GetDrawBounds(X, Y: Integer): CGRect;
begin
  Result := GetCGRectSorted(X - RoundFixed(FTextBefore),
    -Y, X + RoundFixed(FTextAfter), -Y - RoundFixed(FAscent + FDescent));
end;


{------------------------------------------------------------------------------
  Method:  TCarbonTextLayoutBuffer.Create
  Params:  Text           - UTF-8 text
           Font           - Text font
           TextFractional

  Creates new Carbon text layout with buffer
 ------------------------------------------------------------------------------}
constructor TCarbonTextLayoutBuffer.Create(const Text: String; Font: TCarbonFont; TextFractional: Boolean);
var
  TextStyle: ATSUStyle;
  TextLength: LongWord;
  Tag: ATSUAttributeTag;
  DataSize: ByteCount;
  Options: ATSLineLayoutOptions;
  PValue: ATSUAttributeValuePtr;
begin
  // keep copy of text
  FTextBuffer := LazUTF8.UTF8ToUTF16(Text);
  if FTextBuffer='' then
    FTextBuffer:=#0#0;
  TextStyle := Font.Style;

  // create text layout
  TextLength := kATSUToTextEnd;
  if OSError(ATSUCreateTextLayoutWithTextPtr(ConstUniCharArrayPtr(@FTextBuffer[1]),
      kATSUFromTextBeginning, kATSUToTextEnd, Length(FTextBuffer), 1, @TextLength,
      @TextStyle, FLayout), Self, SCreate, 'ATSUCreateTextLayoutWithTextPtr') then Exit;
      
  // set layout line orientation
  Tag := kATSULineRotationTag;
  DataSize := SizeOf(Fixed);

  FLineRotation := Font.LineRotation;
  PValue := @(FLineRotation);
  if OSError(ATSUSetLayoutControls(FLayout, 1, @Tag, @DataSize, @PValue),
    Self, SCreate, 'ATSUSetLayoutControls', 'LineRotation') then Exit;
    
  if not TextFractional then
  begin
    // disable fractional positions of glyphs in layout
    Tag := kATSULineLayoutOptionsTag;
    DataSize := SizeOf(ATSLineLayoutOptions);

    Options := kATSLineFractDisable or kATSLineDisableAutoAdjustDisplayPos or
      kATSLineDisableAllLayoutOperations or kATSLineUseDeviceMetrics;
    PValue := @Options;
    if OSError(ATSUSetLayoutControls(FLayout, 1, @Tag, @DataSize, @PValue),
      Self, SCreate, 'ATSUSetLayoutControls', 'LineLayoutOptions') then Exit;
  end;
  
  FDC := nil;
  FWidget := nil;

  // allow font substitution for exotic glyphs
  OSError(ATSUSetTransientFontMatching(FLayout, True), Self, SCreate,
    'ATSUSetTransientFontMatching');
end;

{------------------------------------------------------------------------------
  Method:  TCarbonTextLayoutBuffer.Apply
  Params:  ADC     - Context to apply to

  Applies text layout to the specified context
 ------------------------------------------------------------------------------}
procedure TCarbonTextLayoutBuffer.Apply(ADC: TCarbonContext);
var
  Tag: ATSUAttributeTag;
  DataSize: ByteCount;
  PValue: ATSUAttributeValuePtr;
begin
  // check if must reset layout to new context
  if FDC = ADC then
  begin
    if (ADC is TCarbonControlContext) then
    begin
      if FWidget = (ADC as TCarbonControlContext).Owner.Content then Exit;
    end
    else
      if FWidget = nil then Exit;
  end;

  FDC := ADC;
  if ADC is TCarbonControlContext then
    FWidget := (ADC as TCarbonControlContext).Owner.Content
  else
    FWidget := nil;

  // set layout context
  Tag := kATSUCGContextTag;
  DataSize := SizeOf(CGContextRef);

  PValue := @(ADC.CGContext);
  if OSError(ATSUSetLayoutControls(FLayout, 1, @Tag, @DataSize, @PValue),
    Self, 'Apply', 'ATSUSetLayoutControls', 'CGContext') then Exit;
    
  // get text ascent
  if OSError(
    ATSUGetUnjustifiedBounds(FLayout, kATSUFromTextBeginning, kATSUToTextEnd,
      FTextBefore, FTextAfter, FAscent, FDescent),
    Self, 'Apply', SGetUnjustifiedBounds) then Exit;
end;


function ATSUCallback({%H-}iCurrentOperation: ATSULayoutOperationSelector; iLineRef: ATSULineRef; iRefCon: UInt32; {%H-}iOperationCallbackParameterPtr: UnivPtr;
  var oCallbackStatus: ATSULayoutOperationCallbackStatus ): OSStatus; {$ifdef DARWIN}mwpascal;{$endif}
var
  Buffer  : TCarbonTextLayoutBuffer;
  Handled : Boolean;
begin
  Result := noErr;
  Buffer := TCarbonTextLayoutBuffer(iRefCon);
  oCallbackStatus:=kATSULayoutOperationCallbackStatusHandled;

  if Assigned(Buffer) then begin
    Handled:=false;
    Buffer.DoJustify(iLineRef, Handled);
  end;
end;

procedure TCarbonTextLayoutBuffer.DoJustify(iLineRef: ATSULineRef; var Handled: Boolean);
type
	ATSLayoutRecord1 = packed record
		glyphID: ATSGlyphRef;
		flags: ATSGlyphInfoFlags;
		originalOffset: ByteCount;
		realPos: Fixed;
	end;

type
  TATSLayoutRecordArray = array [Word] of ATSLayoutRecord1;
  PATSLayoutRecordArray = ^TATSLayoutRecordArray;
var
  i, ofs  : Integer;
  Layouts   : PATSLayoutRecordArray;
  LayCount  : ItemCount;
begin
  if not Assigned(FDX) or (FDXCount=0) then Exit;
  Laycount:=0;
  ATSUDirectGetLayoutDataArrayPtrFromLineRef( iLineRef,
    kATSUDirectDataLayoutRecordATSLayoutRecordVersion1, true, @Layouts, Laycount);
  if Assigned(Layouts) and (Laycount>0) then
  begin
    ofs:=0;
    for i:=0 to Min(FDXCount, LayCount)-1 do
    begin
      Layouts^[i].realPos:=Long2Fix(ofs);
      inc(ofs, FDX[i]);
    end;
  end;
  ATSUDirectReleaseLayoutDataArrayPtr(iLineRef, kATSUDirectDataLayoutRecordATSLayoutRecordCurrent, @Layouts );
  Handled:=True;
end;

function TCarbonTextLayoutBuffer.Draw(X, Y: Integer; Dx: PInteger; DXCount: Integer): Boolean;
var
  MX, MY: ATSUTextMeasurement;
  A: Single;
  theTag    : ATSUAttributeTag;
  theSize   : ByteCount;
  theValue  : ATSUAttributeValuePtr;
  OverSpec  : ATSULayoutOperationOverrideSpecifier;
begin
  Result := False;
  
  if FLineRotation <> 0 then
  begin
    A := FLineRotation * (PI / ($10000 * 180));
    MX := Round(Ascent * Sin(A));
    MY := Round(Ascent - Ascent * Cos(A));
  end
  else
  begin
    MX := 0;
    MY := 0;
  end;

  if Assigned(Dx) then begin
    FDX := Dx;
    FDxCount := DXCount;
    idx:=0;
    OverSpec.operationSelector := kATSULayoutOperationPostLayoutAdjustment;
    OverSpec.overrideUPP := NewATSUDirectLayoutOperationOverrideUPP(@ATSUCallback);
    theTag := kATSULayoutOperationOverrideTag;
    theSize := sizeof (ATSULayoutOperationOverrideSpecifier);
    theValue := @OverSpec;
    ATSUSetTextLayoutRefCon(FLayout, UInt32(Self));
    ATSUSetLayoutControls (FLayout, 1, @theTag, @theSize, @theValue);
  end else begin
    FDX:=nil;
    FDXCount:=0;
  end;

  if OSError(ATSUDrawText(FLayout, kATSUFromTextBeginning, kATSUToTextEnd,
      X shl 16 - FTextBefore + MX, -(Y shl 16) - FAscent + MY),
    Self, 'Draw', 'ATSUDrawText') then Exit;

  if Assigned(Dx) then begin
    DisposeATSUDirectLayoutOperationOverrideUPP(OverSpec.overrideUPP);
    OverSpec.overrideUPP := nil;
    ATSUSetLayoutControls (FLayout, 1, @theTag, @theSize, @theValue);
    fDX := nil;
  end;
    
  Result := True;
end;

{------------------------------------------------------------------------------
  Method:  TCarbonTextLayoutBuffer.Release

  Releases text layout
 ------------------------------------------------------------------------------}
procedure TCarbonTextLayoutBuffer.Release;
begin
  if FLayout <> nil then
    OSError(ATSUDisposeTextLayout(FLayout), Self, 'Release', 'ATSUDisposeTextLayout');

  inherited;
end;

{ TCarbonTextLayoutArray }

{------------------------------------------------------------------------------
  Method:  TCarbonTextLayoutArray.Create
  Params:  Text           - UTF-8 text
           Font           - Text font

  Creates new Carbon text layout array
 ------------------------------------------------------------------------------}
constructor TCarbonTextLayoutArray.Create(const Text: String; Font: TCarbonFont);
begin
  FText := Text;
  FFont := Font;
end;

{------------------------------------------------------------------------------
  Method:  TCarbonTextLayoutArray.Apply
  Params:  ADC     - Context to apply to

  Applies text layout to the specified context
 ------------------------------------------------------------------------------}
procedure TCarbonTextLayoutArray.Apply(ADC: TCarbonContext);
var
  I: Integer;
begin
  FAscent := 0;
  FDescent := 0;
  FTextBefore := 0;
  FTextAfter := 0;
  
  for I := 1 to Length(FText) do
  begin
    FFont.FCachedLayouts[Ord(FText[I])].Apply(ADC);
    
    if I = 1 then
    begin
      FAscent := FFont.FCachedLayouts[Ord(FText[1])].FAscent;
      FDescent := FFont.FCachedLayouts[Ord(FText[1])].FDescent;
      FTextBefore := FFont.FCachedLayouts[Ord(FText[1])].FTextBefore;
      FTextAfter := FTextBefore;
    end;
    FTextAfter := FTextAfter + Long2Fix(FFont.FCachedLayouts[Ord(FText[I])].GetWidth);
  end;
end;

function TCarbonTextLayoutArray.Draw(X, Y: Integer; Dx: PInteger; DXCount: Integer): Boolean;
var
  I   : Integer;
  ix  : Integer;
begin
  Result := False;
  ix := 0;
  for I := 1 to Length(FText) do
  begin
    Result := FFont.FCachedLayouts[Ord(FText[I])].Draw(X, Y, nil, 0);
    if Assigned(dx) and (ix < DXCount) then
    begin
      Inc(X, Dx[ix]);
      inc(ix);
    end
    else
      Inc(X, FFont.FCachedLayouts[Ord(FText[I])].GetWidth);
  end;

  Result := True;
end;

{ TCarbonFont }

{------------------------------------------------------------------------------
  Method:  TCarbonFont.Create
  Params:  AGlobal

  Creates default Carbon font
 ------------------------------------------------------------------------------}
constructor TCarbonFont.Create(AGlobal: Boolean);
begin
  inherited Create(AGlobal);

  FStyle := DefaultTextStyle;
  FLineRotation := 0;
end;

{------------------------------------------------------------------------------
  Method:  TCarbonFont.Create
  Params:  ALogFont  - Font characteristics
           AFaceName - Name of the font

  Creates Carbon font with the specified name and characteristics
 ------------------------------------------------------------------------------}
constructor TCarbonFont.Create(ALogFont: TLogFont; const AFaceName: String);
begin
  inherited Create(False);
  
  FStyle := CreateStyle(ALogFont, AFaceName);
  
  // applied when creating text layout
  FLineRotation := (ALogFont.lfEscapement shl 16) div 10;
end;

{------------------------------------------------------------------------------
  Method:  TCarbonFont.CreateStyle
  Params:  ALogFont  - Font characteristics
           AFaceName - Name of the font
  Returns: ATSUStyle for the specified font name and characteristics
 ------------------------------------------------------------------------------}
function TCarbonFont.CreateStyle(ALogFont: TLogFont; const AFaceName: String): ATSUStyle;
var
  Attr: ATSUAttributeTag;
  M: ATSUTextMeasurement;
  O: ATSStyleRenderingOptions;
  B: Boolean;
  S: ByteCount;
  A: ATSUAttributeValuePtr;
  ID: ATSUFontID;
  H: Integer;
const
  SSetAttrs = 'ATSUSetAttributes';
  SName = 'CreateStyle';
  ATSStyleRenderingOption: Array [NONANTIALIASED_QUALITY..ANTIALIASED_QUALITY] of
    ATSStyleRenderingOptions = (kATSStyleNoAntiAliasing, kATSStyleApplyAntiAliasing);
begin
  inherited Create(False);

  Result:=nil;
  OSError(ATSUCreateStyle(Result), Self, SName, SCreateStyle);

  ID := FindCarbonFontID(AFaceName);

  if ID <> 0 then
  begin
    Attr := kATSUFontTag;
    A := @ID;
    S := SizeOf(ID);
    OSError(ATSUSetAttributes(Result, 1, @Attr, @S, @A), Self, SName,
      SSetAttrs, 'kATSUFontTag');
  end;

  if ALogFont.lfHeight = 0
    then H := CarbonDefaultFontSize
    else H := ALogFont.lfHeight;

  Attr := kATSUSizeTag;
  M := Abs(H) shl 16;
  A := @M;
  S := SizeOf(M);
  OSError(ATSUSetAttributes(Result, 1, @Attr, @S, @A), Self, SName,
    SSetAttrs, 'kATSUSizeTag');

  if ALogFont.lfWeight > FW_NORMAL then
  begin
    Attr := kATSUQDBoldfaceTag;
    B := True;
    A := @B;
    S := SizeOf(B);
    OSError(ATSUSetAttributes(Result, 1, @Attr, @S, @A), Self, SName,
      SSetAttrs, 'kATSUQDBoldfaceTag');
  end;

  if ALogFont.lfItalic > 0 then
  begin
    Attr := kATSUQDItalicTag;
    B := True;
    A := @B;
    S := SizeOf(B);
    OSError(ATSUSetAttributes(Result, 1, @Attr, @S, @A), Self, SName, SSetAttrs,
      'kATSUQDItalicTag');
  end;

  if ALogFont.lfUnderline > 0 then
  begin
    Attr := kATSUQDUnderlineTag;
    B := True;
    A := @B;
    S := SizeOf(B);
    OSError(ATSUSetAttributes(Result, 1, @Attr, @S, @A), Self, SName,
      SSetAttrs, 'kATSUQDUnderlineTag');
  end;

  if ALogFont.lfStrikeOut > 0 then
  begin
    Attr := kATSUStyleStrikeThroughTag;
    B := True;
    A := @B;
    S := SizeOf(B);
    OSError(ATSUSetAttributes(Result, 1, @Attr, @S, @A), Self, SName,
      SSetAttrs, 'kATSUStyleStrikeThroughTag');
  end;

  if (ALogFont.lfQuality >= NONANTIALIASED_QUALITY) and
    (ALogFont.lfQuality <= ANTIALIASED_QUALITY) then
  begin
    Attr := kATSUStyleRenderingOptionsTag;
    O := ATSStyleRenderingOption[ALogFont.lfQuality];
    A := @O;
    S := SizeOf(O);
    OSError(ATSUSetAttributes(Result, 1, @Attr, @S, @A), Self, SName,
      SSetAttrs, 'kATSUStyleRenderingOptionsTag');
  end;
end;

{------------------------------------------------------------------------------
  Method:  TCarbonFont.QueryStyle
  Params:  ALogFont  - Font characteristics
 ------------------------------------------------------------------------------}
procedure TCarbonFont.QueryStyle(ALogFont: PLogFont);
var
  Attr: ATSUAttributeTag;
  M: ATSUTextMeasurement;
  O: ATSStyleRenderingOptions;
  B: Boolean;
  S: ByteCount;
  A: ATSUAttributeValuePtr;
  ID: ATSUFontID;
  Ascent, Leading, Descent: Integer;
const
  SGetAttr = 'ATSUGetAttribute';
  SName = 'QueryStyle';

begin

  Attr := kATSUFontTag;
  A := @ID;
  S := SizeOf(ID);
  OSError(ATSUGetAttribute(Style, Attr, S, A, nil), Self, SName,
      SGetAttr, 'kATSUFontTag', kATSUNotSetErr);

  ALogFont^.lfFaceName := CarbonFontIDTOFontName(ID);

  
  A := @M;
  S := SizeOf(M);
  OSError(ATSUGetAttribute(Style, kATSUAscentTag, S, A, nil), Self, SName,
      SGetAttr, 'kATSUAscentTag', kATSUNotSetErr);
  Ascent := (M shr 16);

  OSError(ATSUGetAttribute(Style, kATSULeadingTag, S, A, nil), Self, SName,
      SGetAttr, 'kATSULeadingTag', kATSUNotSetErr);
  Leading := (M shr 16);

  OSError(ATSUGetAttribute(Style, kATSUDescentTag, S, A, nil), Self, SName,
      SGetAttr, 'kATSUDescentTag', kATSUNotSetErr);
  Descent := (M shr 16);

  ALogFont^.lfHeight := Ascent + Leading + Descent;

  
  Attr := kATSUQDBoldfaceTag;
  A := @B;
  S := SizeOf(B);
  OSError(ATSUGetAttribute(Style, Attr, S, A, nil), Self, SName,
      SGetAttr, 'kATSUQDBoldfaceTag', kATSUNotSetErr);

  if B then ALogFont^.lfWeight := FW_BOLD else ALogFont^.lfWeight := FW_NORMAL;


  Attr := kATSUQDItalicTag;
  A := @B;
  S := SizeOf(B);
  OSError(ATSUGetAttribute(Style, Attr, S, A, nil), Self, SName, SGetAttr,
      'kATSUQDItalicTag', kATSUNotSetErr);

  if B then ALogFont^.lfItalic := 1 else ALogFont^.lfItalic := 0;


  Attr := kATSUQDUnderlineTag;
  A := @B;
  S := SizeOf(B);
  OSError(ATSUGetAttribute(Style, Attr, S, A, nil), Self, SName,
      SGetAttr, 'kATSUQDUnderlineTag', kATSUNotSetErr);

  if B then ALogFont^.lfUnderline := 1 else ALogFont^.lfUnderLine := 0;


  Attr := kATSUStyleStrikeThroughTag;
  A := @B;
  S := SizeOf(B);
  OSError(ATSUGetAttribute(Style, Attr, S, A, nil), Self, SName,
      SGetAttr, 'kATSUStyleStrikeThroughTag', kATSUNotSetErr);

  if B then ALogFont^.lfStrikeOut := 1 else ALogFont^.lfStrikeOut := 0;


  Attr := kATSUStyleRenderingOptionsTag;
  A := @O;
  S := SizeOf(O);
  OSError(ATSUGetAttribute(Style, Attr, S, A, nil), Self, SName,
      SGetAttr, 'kATSUStyleRenderingOptionsTag', kATSUNotSetErr);

  case O of
	kATSStyleApplyAntiAliasing:	ALogFont^.lfQuality := ANTIALIASED_QUALITY;
	kATSStyleNoAntiAliasing:	ALogFont^.lfQuality := NONANTIALIASED_QUALITY;
  else
	ALogFont^.lfQuality := DEFAULT_QUALITY;
  end;
end;

{------------------------------------------------------------------------------
  Method:  TCarbonFont.Destroy

  Frees Carbon font
 ------------------------------------------------------------------------------}
destructor TCarbonFont.Destroy;
var
  I: Integer;
begin
  if FStyle <> DefaultTextStyle then
    OSError(ATSUDisposeStyle(FStyle), Self, SDestroy, SDisposeStyle);
  for I := 0 to High(FCachedLayouts) do
    if FCachedLayouts[I] <> nil then FCachedLayouts[I].Release;

  inherited;
end;

{------------------------------------------------------------------------------
  Method:  TCarbonFont.SetColor
  Params:  AColor  - Font color

  Chnage font style color
 ------------------------------------------------------------------------------}
procedure TCarbonFont.SetColor(AColor: TColor);
var
  Attr: ATSUAttributeTag;
  S: ByteCount;
  A: ATSUAttributeValuePtr;
  C: RGBColor;
begin
  C := ColorToRGBColor(AColor);

  Attr := kATSUColorTag;
  A := @C;
  S := SizeOf(C);
  OSError(ATSUSetAttributes(Style, 1, @Attr, @S, @A), Self, SSetColor,
    'ATSUSetAttributes');
end;

function TCarbonFont.CreateTextLayout(const Text: String;
  TextFractional: Boolean): TCarbonTextLayout;
  
  function IsTextASCII: Boolean;
  var
    I: Integer;
    C: Byte;
  begin
    Result := False;

    for I := 1 to Length(Text) do
    begin
      C := Ord(Text[I]);
      if (C > 127) or (C = 10) or (C = 13) then Exit;
    end;
    
    Result := True;
  end;
var
  I, J, L: Integer;
  C: Byte;
begin
  if (FLineRotation <> 0) or TextFractional or not IsTextASCII then
    Result := TCarbonTextLayoutBuffer.Create(Text, Self, TextFractional)
  else
  begin
    for I := 1 to Length(Text) do
    begin
      C := Ord(Text[I]);
      if C > High(FCachedLayouts) then
      begin
        L := Length(FCachedLayouts);
        SetLength(FCachedLayouts, C + 1);
        for J := L to C do FCachedLayouts[J] := nil;
      end;
      
      if FCachedLayouts[C] = nil then
        FCachedLayouts[C] := TCarbonTextLayoutBuffer.Create(Text[I], Self, TextFractional);
    end;
    
    Result := TCarbontextLayoutArray.Create(Text, Self);
  end;
end;

{ TCarbonColorObject }

function TCarbonColorObject.GetColorRef: TColorRef;
begin
  Result := TColorRef(RGBToColor(FR, FG, FB));
end;

{------------------------------------------------------------------------------
  Method:  TCarbonColorObject.Create
  Params:  AColor  - Color
           ASolid  - Opacity
           AGlobal - Global
          
  Creates Carbon color object
 ------------------------------------------------------------------------------}
constructor TCarbonColorObject.Create(const AColor: TColor; ASolid, AGlobal: Boolean);
begin
  inherited Create(AGlobal);
  
  SetColor(AColor, ASolid);
end;

{------------------------------------------------------------------------------
  Method:  TCarbonColorObject.SetColor
  Params:  AColor - Color
           ASolid - Opacity

  Sets the color and opacity
 ------------------------------------------------------------------------------}
procedure TCarbonColorObject.SetColor(const AColor: TColor; ASolid: Boolean);
begin
  RedGreenBlue(ColorToRGB(AColor), FR, FG, FB);
  FA := ASolid;
end;

{------------------------------------------------------------------------------
  Method:  TCarbonColorObject.GetRGBA
  Params:  AROP2 - Binary raster operation
           AR, AG, AB, AA - Red, green, blue, alpha component of color

  Gets the individual color components according to the binary raster operation
 ------------------------------------------------------------------------------}
procedure TCarbonColorObject.GetRGBA(AROP2: Integer; out AR, AG, AB, AA: Single);
begin
  case AROP2 of
    R2_BLACK:
    begin
      AR := 0;
      AG := 0;
      AB := 0;
      AA := Byte(FA);
    end;
    R2_WHITE:
    begin
      AR := 1;
      AG := 1;
      AB := 1;
      AA := Byte(FA);
    end;
    R2_NOP:
    begin
      AR := 1;
      AG := 1;
      AB := 1;
      AA := 0;
    end;
    R2_NOT:
    begin
      AR := 1;
      AG := 1;
      AB := 1;
      AA := Byte(FA);
    end;
    R2_NOTCOPYPEN:
    begin
      AR := (255 - FR) / 255;
      AG := (255 - FG) / 255;
      AB := (255 - FB) / 255;
      AA := Byte(FA);
    end;
  else // copy
    begin
      AR := FR / 255;
      AG := FG / 255;
      AB := FB / 255;
      AA := Byte(FA);
    end;
  end;
end;

{------------------------------------------------------------------------------
  Method:  TCarbonColorObject.CreateCGColor
  Returns: CGColor
 ------------------------------------------------------------------------------}
function TCarbonColorObject.CreateCGColor: CGColorRef;
var
  F: Array [0..3] of Single;
begin
  F[0] := FR / 255;
  F[1] := FG / 255;
  F[2] := FB / 255;
  F[3] := Byte(FA);
  
  Result := CGColorCreate(RGBColorSpace, @F[0]);
end;

{ TCarbonBrush }

procedure DrawBitmapPattern(info: UnivPtr; c: CGContextRef); MWPascal;
var
  ABrush: TCarbonBrush absolute info;
  AImage: CGImageRef;
begin
  AImage := ABrush.FBitmap.CGImage;
  CGContextDrawImage(c, GetCGRect(0, 0, CGImageGetWidth(AImage), CGImageGetHeight(AImage)),
    AImage);
end;

procedure TCarbonBrush.SetHatchStyle(AHatch: PtrInt);
const
  HATCH_DATA: array[HS_HORIZONTAL..HS_DIAGCROSS] of array[0..7] of Byte =
 (
 { HS_HORIZONTAL } ($FF, $FF, $FF, $00, $FF, $FF, $FF, $FF),
 { HS_VERTICAL   } ($F7, $F7, $F7, $F7, $F7, $F7, $F7, $F7),
 { HS_FDIAGONAL  } ($7F, $BF, $DF, $EF, $F7, $FB, $FD, $FE),
 { HS_BDIAGONAL  } ($FE, $FD, $FB, $F7, $EF, $DF, $BF, $7F),
 { HS_CROSS      } ($F7, $F7, $F7, $00, $F7, $F7, $F7, $F7),
 { HS_DIAGCROSS  } ($7E, $BD, $DB, $E7, $E7, $DB, $BD, $7E)
  );
var
  ACallBacks: CGPatternCallbacks;
begin
  if AHatch in [HS_HORIZONTAL..HS_DIAGCROSS] then
  begin
    FillChar(ACallBacks{%H-}, SizeOf(ACallBacks), 0);
    ACallBacks.drawPattern := @DrawBitmapPattern;
    FBitmap := TCarbonBitmap.Create(8, 8, 1, 1, cbaByte, cbtMask, @HATCH_DATA[AHatch]);
    FColored := False;
    FCGPattern := CGPatternCreate(Self, GetCGRect(0, 0, 8, 8),
      CGAffineTransformIdentity, 8, 8, kCGPatternTilingConstantSpacing,
      Ord(FColored), ACallBacks);
  end;
end;

procedure TCarbonBrush.SetBitmap(ABitmap: TCarbonBitmap);
var
  AWidth, AHeight: Integer;
  ACallBacks: CGPatternCallbacks;
begin
  AWidth := ABitmap.Width;
  AHeight := ABitmap.Height;
  FillChar(ACallBacks{%H-}, SizeOf(ACallBacks), 0);
  ACallBacks.drawPattern := @DrawBitmapPattern;
  FBitmap := TCarbonBitmap.Create(ABitmap);
  FColored := True;
  FCGPattern := CGPatternCreate(Self, GetCGRect(0, 0, AWidth, AHeight),
    CGAffineTransformIdentity, AWidth, AHeight, kCGPatternTilingConstantSpacing,
    Ord(FColored), ACallBacks);
end;

{------------------------------------------------------------------------------
  Method:  TCarbonBrush.Create
  Params:  AGlobal

  Creates default Carbon brush
 ------------------------------------------------------------------------------}
constructor TCarbonBrush.Create(AGlobal: Boolean);
begin
  inherited Create(clWhite, True, AGlobal);
  FCGPattern := nil;
  FBitmap := nil;
end;

{------------------------------------------------------------------------------
  Method:  TCarbonBrush.Create
  Params:  ALogBrush - Brush characteristics

  Creates Carbon brush with the specified characteristics
 ------------------------------------------------------------------------------}
constructor TCarbonBrush.Create(ALogBrush: TLogBrush);
begin
  FCGPattern := nil;
  FBitmap := nil;
  case ALogBrush.lbStyle of
    BS_SOLID:
        inherited Create(ColorToRGB(TColor(ALogBrush.lbColor)), True, False);
    BS_HATCHED:        // Hatched brush.
      begin
        inherited Create(ColorToRGB(TColor(ALogBrush.lbColor)), True, False);
        SetHatchStyle(ALogBrush.lbHatch);
      end;
    BS_DIBPATTERN,
    BS_DIBPATTERN8X8,
    BS_DIBPATTERNPT,
    BS_PATTERN,
    BS_PATTERN8X8:
      begin
        inherited Create(ColorToRGB(TColor(ALogBrush.lbColor)), False, False);
        SetBitmap(TCarbonBitmap(ALogBrush.lbHatch));
      end
    else
      inherited Create(ColorToRGB(TColor(ALogBrush.lbColor)), False, False);
  end;
end;

destructor TCarbonBrush.Destroy;
begin
  if FCGPattern <> nil then
    CGPatternRelease(FCGPattern);
  FBitmap.Free;
  inherited Destroy;
end;

{------------------------------------------------------------------------------
  Method:  TCarbonBrush.Apply
  Params:  ADC     - Context to apply to
           UseROP2 - Consider binary raster operation?

  Applies brush to the specified context
 ------------------------------------------------------------------------------}
procedure TCarbonBrush.Apply(ADC: TCarbonContext; UseROP2: Boolean);
var
  RGBA: array[0..3] of Single;
  AROP2: Integer;
  APatternSpace: CGColorSpaceRef;
  BaseSpace : CGColorSpaceRef;
begin
  if ADC = nil then Exit;
  if ADC.CGContext = nil then Exit;

  if UseROP2 then 
    AROP2 := (ADC as TCarbonDeviceContext).ROP2
  else 
    AROP2 := R2_COPYPEN;

  GetRGBA(AROP2, RGBA[0], RGBA[1], RGBA[2], RGBA[3]);

  if AROP2 <> R2_NOT then
    CGContextSetBlendMode(ADC.CGContext, kCGBlendModeNormal)
  else
    CGContextSetBlendMode(ADC.CGContext, kCGBlendModeDifference);

  if FCGPattern <> nil then
  begin
    if not FColored then
      BaseSpace:=CGColorSpaceCreateDeviceRGB
    else
    begin
      BaseSpace:=nil;
      RGBA[0] := 1.0;
    end;
    APatternSpace := CGColorSpaceCreatePattern(BaseSpace);
    CGContextSetFillColorSpace(ADC.CGContext, APatternSpace);
    CGColorSpaceRelease(APatternSpace);
    if Assigned(BaseSpace) then CGColorSpaceRelease(BaseSpace);
    CGContextSetFillPattern(ADC.CGcontext, FCGPattern, @RGBA[0]);
  end
  else
    CGContextSetRGBFillColor(ADC.CGContext, RGBA[0], RGBA[1], RGBA[2], RGBA[3]);
end;

{ TCarbonPen }

{------------------------------------------------------------------------------
  Method:  TCarbonPen.Create
  Params:  AGlobal

  Creates default Carbon pen
 ------------------------------------------------------------------------------}
constructor TCarbonPen.Create(AGlobal: Boolean);
begin
  inherited Create(clBlack, True, AGlobal);
  FStyle := PS_SOLID;
  FWidth := 1;
  FIsExtPen := False;
  Dashes := nil;
end;

{------------------------------------------------------------------------------
  Method:  TCarbonPen.Create
  Params:  ALogPen - Pen characteristics

  Creates Carbon pen with the specified characteristics
 ------------------------------------------------------------------------------}
constructor TCarbonPen.Create(ALogPen: TLogPen);
begin
  case ALogPen.lopnStyle of
    PS_SOLID..PS_DASHDOTDOT,
    PS_INSIDEFRAME:
      begin
        inherited Create(ColorToRGB(TColor(ALogPen.lopnColor)), True, False);
        FWidth := Max(1, ALogPen.lopnWidth.x);
      end;
    else
    begin
      inherited Create(ColorToRGB(TColor(ALogPen.lopnColor)), False, False);
      FWidth := 1;
    end;
  end;

  FStyle := ALogPen.lopnStyle;
end;

constructor TCarbonPen.Create(dwPenStyle, dwWidth: DWord; const lplb: TLogBrush; dwStyleCount: DWord; lpStyle: PDWord);
var
  i: integer;
begin
  case dwPenStyle and PS_STYLE_MASK of
    PS_SOLID..PS_DASHDOTDOT,
    PS_USERSTYLE:
      begin
        inherited Create(ColorToRGB(TColor(lplb.lbColor)), True, False);
      end;
    else
    begin
      inherited Create(ColorToRGB(TColor(lplb.lbColor)), False, False);
    end;
  end;

  FIsExtPen := True;
  FIsGeometric := (dwPenStyle and PS_TYPE_MASK) = PS_GEOMETRIC;

  if IsGeometric then
  begin
    case dwPenStyle and PS_JOIN_MASK of
      PS_JOIN_ROUND: FJoinStyle := kCGLineJoinRound;
      PS_JOIN_BEVEL: FJoinStyle := kCGLineJoinBevel;
      PS_JOIN_MITER: FJoinStyle := kCGLineJoinMiter;
    end;

    case dwPenStyle and PS_ENDCAP_MASK of
      PS_ENDCAP_ROUND: FEndCap := kCGLineCapRound;
      PS_ENDCAP_SQUARE: FEndCap := kCGLineCapSquare;
      PS_ENDCAP_FLAT: FEndCap := kCGLineCapButt;
    end;
    FWidth := Max(1, dwWidth);
  end
  else
    FWidth := 1;

  if (dwPenStyle and PS_STYLE_MASK) = PS_USERSTYLE then
  begin
    SetLength(Dashes, dwStyleCount);
    for i := 0 to dwStyleCount - 1 do
      Dashes[i] := lpStyle[i];
  end;

  FStyle := dwPenStyle and PS_STYLE_MASK;
end;

{------------------------------------------------------------------------------
  Method:  TCarbonPen.Apply
  Params:  ADC     - Context to apply to
           UseROP2 - Consider binary raster operation?

  Applies pen to the specified context
 ------------------------------------------------------------------------------}
procedure TCarbonPen.Apply(ADC: TCarbonContext; UseROP2: Boolean);

  function GetDashes(Source: TCarbonDashes): TCarbonDashes;
  var
    i: Integer;
  begin
    Result := Source;
    for i := Low(Result) to High(Result) do
      Result[i] := Result[i] * FWidth;
  end;

var
  AR, AG, AB, AA: Single;
  AROP2: Integer;
  ADashes: TCarbonDashes;
begin
  if ADC = nil then Exit;
  if ADC.CGContext = nil then Exit;

  if UseROP2 then AROP2 := (ADC as TCarbonDeviceContext).ROP2
  else AROP2 := R2_COPYPEN;

  GetRGBA(AROP2, AR, AG, AB, AA);

  if AROP2 <> R2_NOT then
    CGContextSetBlendMode(ADC.CGContext, kCGBlendModeNormal)
  else
    CGContextSetBlendMode(ADC.CGContext, kCGBlendModeDifference);

  CGContextSetRGBStrokeColor(ADC.CGContext, AR, AG, AB, AA);
  CGContextSetLineWidth(ADC.CGContext, FWidth);

  if IsExtPen then
  begin
    if IsGeometric then
    begin
      CGContextSetLineCap(ADC.CGContext, FEndCap);
      CGContextSetLineJoin(ADC.CGContext, FJoinStyle);
    end;
  end;

  case FStyle of
    PS_DASH:
      begin
        ADashes := GetDashes(CarbonDashStyle);
        CGContextSetLineDash(ADC.CGContext, 0, @ADashes[0], Length(ADashes));
      end;
    PS_DOT:
      begin
        ADashes := GetDashes(CarbonDotStyle);
        CGContextSetLineDash(ADC.CGContext, 0, @ADashes[0], Length(ADashes));
      end;
    PS_DASHDOT:
      begin
        ADashes := GetDashes(CarbonDashDotStyle);
        CGContextSetLineDash(ADC.CGContext, 0, @ADashes[0], Length(ADashes));
      end;
    PS_DASHDOTDOT:
      begin
        ADashes := GetDashes(CarbonDashDotDotStyle);
        CGContextSetLineDash(ADC.CGContext, 0, @ADashes[0], Length(ADashes));
      end;
    PS_USERSTYLE:
      if Length(Dashes) = 0 then
        CGContextSetLineDash(ADC.CGContext, 0, nil, Length(Dashes))
      else
      CGContextSetLineDash(ADC.CGContext, 0, @Dashes[0], Length(Dashes));
  else
    CGContextSetLineDash(ADC.CGContext, 0, nil, 0);
  end;
end;

{ TCarbonBitmap }

{------------------------------------------------------------------------------
  Method:  TCarbonBitmap.GetBitsPerComponent
  Returns: Bitmap bits per component
 ------------------------------------------------------------------------------}
function TCarbonBitmap.GetBitsPerComponent: Integer;
begin
  case FType of
    cbtMask,
    cbtGray: Result := FDepth;
    cbtRGB,
    cbtBGR:  Result := FDepth div 3;
    cbtARGB,
    cbtRGBA,
    cbtBGRA: Result := FDepth shr 2;
  else
    Result := 0;
  end;
end;

{------------------------------------------------------------------------------
  Method:  TCarbonBitmap.GetColorSpace
  Returns: The colorspace for this type of bitmap
 ------------------------------------------------------------------------------}
function TCarbonBitmap.GetColorSpace: CGColorSpaceRef;
begin
  if FType in [cbtMask, cbtGray]
  then Result := GrayColorSpace
  else Result := RGBColorSpace
end;

{------------------------------------------------------------------------------
  Method:  TCarbonBitmap.GetInfo
  Returns: The CGBitmapInfo for this type of bitmap
 ------------------------------------------------------------------------------}
function TCarbonBitmap.GetInfo: CGBitmapInfo;
begin
  Result := BITMAPINFOMAP[FType];
end;

procedure TCarbonBitmap.SetCGImage(const AValue: CGImageRef);
begin
  if FCGImage = AValue then
    Exit;
    
  if FCGImage <> nil then
    CGImageRelease(FCGImage);

  FCGImage := AValue;

  UpdateInfo;
end;

{------------------------------------------------------------------------------
  Method:  TCarbonBitmap.Create
  Params:  AWidth        - Bitmap width
           AHeight       - Bitmap height
           ADepth        - Significant bits per pixel
           ABitsPerPixel - The number of allocated bits per pixel (can be larger than depth)
           AAlignment    - Alignment of the data for each row
           ABytesPerRow  - The number of bytes between rows
           ACopyData     - Copy supplied bitmap data (OPTIONAL)
  
  Creates Carbon bitmap with the specified characteristics
 ------------------------------------------------------------------------------}
constructor TCarbonBitmap.Create(AWidth, AHeight, ADepth, ABitsPerPixel: Integer;
  AAlignment: TCarbonBitmapAlignment; AType: TCarbonBitmapType; AData: Pointer;
  ACopyData: Boolean);
begin
  inherited Create(False);

  FCGImage := nil;

  SetInfo(AWidth, AHeight, ADepth, ABitsPerPixel, AAlignment, AType);
  
  if (AData = nil) or ACopyData then
  begin
    System.GetMem(FData, FDataSize);
    FFreeData := True;
    if AData <> nil then
      System.Move(AData^, FData^, FDataSize) // copy data
    else
      FillDWord(FData^, FDataSize shr 2, 0); // clear bitmap
  end
  else
  begin
    FData := AData;
    FFreeData := False;
  end;

//DebugLn(Format('TCarbonBitmap.Create %d x %d Data: %d RowSize: %d Size: %d',
//  [AWidth, AHeight, Integer(AData), DataRowSize, FDataSize]));

  UpdateImage;
  
  //DbgDumpImage(FCGImage, 'TCarbonBitmap.Create');
end;

{------------------------------------------------------------------------------
  Method:  TCarbonBitmap.Create
  Params:  ABitmap - Source bitmap

  Creates Carbon bitmap as a copy of specified bitmap
 ------------------------------------------------------------------------------}
constructor TCarbonBitmap.Create(ABitmap: TCarbonBitmap);
begin
  Create(ABitmap.Width, ABitmap.Height, ABitmap.Depth, ABitmap.FBitsPerPixel,
    ABitmap.FAlignment, ABitmap.FType, ABitmap.Data);
end;

{------------------------------------------------------------------------------
  Method:  TCarbonBitmap.Destroy

  Frees Carbon bitmap
 ------------------------------------------------------------------------------}
destructor TCarbonBitmap.Destroy;
begin
  CGImageRelease(FCGImage);
  if FFreeData then System.FreeMem(FData);

  inherited Destroy;
end;

procedure TCarbonBitmap.SetInfo(AWidth, AHeight, ADepth,
  ABitsPerPixel: Integer; AAlignment: TCarbonBitmapAlignment;
  AType: TCarbonBitmapType);
const
  ALIGNBITS: array[TCarbonBitmapAlignment] of Integer = (0, 1, 3, 7, $F);
var
  M: Integer;
begin
  if AWidth < 1 then AWidth := 1;
  if AHeight < 1 then AHeight := 1;
  FWidth := AWidth;
  FHeight := AHeight;
  FDepth := ADepth;
  FBitsPerPixel := ABitsPerPixel;
  FType := AType;
  FAlignment := AAlignment;

  //todo: FDepth should not be Zero. Need to find out what's causing it.
  if (FType in [cbtMono, cbtGray]) and (FDepth=0) then
    FDepth:=FBitsPerPixel;

  FBytesPerRow := ((AWidth * ABitsPerPixel) + 7) shr 3;
  M := FBytesPerRow and ALIGNBITS[AAlignment];
  if M <> 0 then Inc(FBytesPerRow, ALIGNBITS[AAlignment] + 1 - M);

  FDataSize := FBytesPerRow * FHeight;
end;

{------------------------------------------------------------------------------
  Method:  TCarbonBitmap.UpdateImage

  Updates Carbon bitmap
 ------------------------------------------------------------------------------}
procedure TCarbonBitmap.UpdateImage;
var
  CGDataProvider: CGDataProviderRef;
begin
  // we have a data and description and we need to build CGImage
  
  if FData = nil then Exit;
  if FCGImage <> nil then CGImageRelease(FCGImage);

  CGDataProvider := CGDataProviderCreateWithData(nil, FData, FDataSize, nil);
  try
    if FType = cbtMask
    then FCGImage := CGImageMaskCreate(FWidth, FHeight, GetBitsPerComponent,
           FBitsPerPixel, FBytesPerRow, CGDataProvider, nil, 0)
    else FCGImage := CGImageCreate(FWidth, FHeight, GetBitsPerComponent,
           FBitsPerPixel, FBytesPerRow, GetColorSpace, BITMAPINFOMAP[FType],
           CGDataProvider, nil, 0, kCGRenderingIntentDefault);
  finally
    CGDataProviderRelease(CGDataProvider);
  end;
end;

procedure TCarbonBitmap.UpdateInfo;
const
  ALIGNMAP: array[TRawImageLineEnd] of TCarbonBitmapAlignment = (cbaByte, cbaByte, cbaWord, cbaDWord, cbaQWord, cbaDQWord);
var
  ADesc: TRawImageDescription;
  AType: TCarbonBitmapType;
  ADataSize: PtrUInt;
begin
  // we have a CGImage and we need to update all info related to that image
  
  if FFreeData then System.FreeMem(FData);
  FData := nil;
  FFreeData := True;
  
  if not CarbonWidgetSet.RawImage_DescriptionFromCarbonBitmap(ADesc, Self) then
    Exit;

  if not CarbonWidgetSet.RawImage_DescriptionToBitmapType(ADesc, AType) then
    Exit;

  SetInfo(ADesc.Width, ADesc.Height, ADesc.Depth, ADesc.BitsPerPixel,
    ALIGNMAP[ADesc.LineEnd], AType);

  FData := CarbonWidgetSet.GetImagePixelData(FCGImage, ADataSize);
  FDataSize := FDataSize;
end;

{------------------------------------------------------------------------------
  Method:  TCarbonBitmap.CreateSubImage
  Returns: New image ref to portion of image data according to the rect
 ------------------------------------------------------------------------------}
function TCarbonBitmap.CreateSubImage(const ARect: TRect): CGImageRef;
begin
  if CGImage = nil then Result := nil
  else Result := CGImageCreateWithImageInRect(CGImage, RectToCGRect(ARect));
end;

{------------------------------------------------------------------------------
  Method:  TCarbonBitmap.CreateMaskImage
  Returns: New mask image ref to portion of image data according to the rect
 ------------------------------------------------------------------------------}
function TCarbonBitmap.CreateMaskImage(const ARect: TRect): CGImageRef;
var
  CGDataProvider: CGDataProviderRef;
  Mask: CGImageRef;
begin
  CGDataProvider := CGDataProviderCreateWithData(nil, FData, FDataSize, nil);
  try
    Mask := CGImageMaskCreate(FWidth, FHeight, FBitsPerPixel,
      FBitsPerPixel, FBytesPerRow, CGDataProvider, nil, 0);
    Result := CGImageCreateWithImageInRect(Mask, RectToCGRect(ARect));
  finally
    CGDataProviderRelease(CGDataProvider);
    CGImageRelease(Mask);
  end;
end;

{------------------------------------------------------------------------------
  Method:  TCarbonBitmap.CreateMaskedImage
  Returns: New image ref to masked image data
 ------------------------------------------------------------------------------}
function TCarbonBitmap.CreateMaskedImage(AMask: TCarbonBitmap): CGImageRef;
begin
  Result := CreateMaskedImage(AMask, Classes.Rect(0, 0, Width, Height));
end;

{------------------------------------------------------------------------------
  Method:  TCarbonBitmap.CreateMaskedImage
  Returns: New image ref to portion of masked image data according to the rect
 ------------------------------------------------------------------------------}
function TCarbonBitmap.CreateMaskedImage(AMask: TCarbonBitmap;
  const ARect: TRect): CGImageRef;
var
  CGSubImage: CGImageRef;
  CGSubMaskImage: CGImageRef;
begin
  Result := nil;
  if CGImage = nil then Exit;
  if (AMask <> nil) and (AMask.CGImage <> nil) then
  begin
    CGSubImage := CreateSubImage(ARect);
    CGSubMaskImage := AMask.CreateMaskImage(ARect);
    try
      Result := CGImageCreateWithMask(CGSubImage, CGSubMaskImage);
    finally
      CGImageRelease(CGSubMaskImage);
      CGImageRelease(CGSubImage);
    end;
  end
  else
    Result := CreateSubImage(ARect);
end;

procedure TCarbonBitmap.AddMask(AMask: TCarbonBitmap);
begin
  if AMask = nil then
    Exit;

  CGImage := CreateMaskedImage(AMask);
end;

{ TCarbonCursor }

{------------------------------------------------------------------------------
  Method:  TCarbonCursor.Create

  Creates Carbon cursor
 ------------------------------------------------------------------------------}
constructor TCarbonCursor.Create;
begin
  inherited Create(False);

  FCursorType := cctUnknown;
  FThemeCursor := 0;
  FAnimationStep := 0;
  FQDHardwareCursorName := '';
  FPixmapHandle := nil;
end;

{------------------------------------------------------------------------------
  Method:  TCarbonCursor.CreateThread

  Creates cursor animation thread
 ------------------------------------------------------------------------------}
procedure TCarbonCursor.CreateThread;
begin
  FTaskID := nil;
  OSError(MPCreateTask(@AnimationCursorHandler, Self, 0, nil, nil, nil, 0, @FTaskID),
    Self, 'CreateThread', 'MPCreateTask');
end;

{------------------------------------------------------------------------------
  Method:  TCarbonCursor.DestroyThread

  Destroys cursor animation thread
 ------------------------------------------------------------------------------}
procedure TCarbonCursor.DestroyThread;
begin
  OSError(MPTerminateTask(FTaskID, noErr), Self, 'DestroyThread', 'MPTerminateTask');
  FTaskID := nil;
end;

{------------------------------------------------------------------------------
  Method:  TCarbonCursor.CreateHardwareCursor
  Params:  ABitmap  - Cursor image
           AHotSpot - Hot spot position

  Creates new hardware cursor
 ------------------------------------------------------------------------------}
procedure TCarbonCursor.CreateHardwareCursor(ABitmap: TCarbonBitmap; AHotSpot: Point);
var
  B: Rect;
begin
  FCursorType := cctQDHardware;

  B.top := 0;
  B.left := 0;
  B.bottom := ABitmap.Height;
  B.right := ABitmap.Width;

  FPixmapHandle := PixMapHandle(NewHandleClear(SizeOf(PixMap)));
  // tell that this is pixmap (bit 15 := 1)
  FPixmapHandle^^.rowBytes := SInt16(ABitmap.BytesPerRow or $8000);
  FPixmapHandle^^.bounds := B;
  FPixmapHandle^^.pmVersion := 0;
  FPixmapHandle^^.packType := 0;
  FPixmapHandle^^.packSize := 0;
  FPixmapHandle^^.hRes := $00480000; // 72 dpi
  FPixmapHandle^^.vRes := $00480000; // 72 dpi
  FPixmapHandle^^.pixelType := RGBDirect;
  FPixmapHandle^^.cmpSize := ABitmap.BitsPerComponent;
  FPixmapHandle^^.cmpCount := ABitmap.Depth div FPixmapHandle^^.cmpSize;  // $AARRGGBB
  FPixmapHandle^^.pixelSize := ABitmap.FBitsPerPixel; // depth
  FPixmapHandle^^.pmTable := nil;
  FPixmapHandle^^.baseAddr := Ptr(ABitmap.Data);

  FQDHardwareCursorName := Application.Title + LazarusCursorInfix + IntToStr(Integer(Self));
  OSError(
    QDRegisterNamedPixMapCursor(FPixmapHandle, nil, AHotSpot, PChar(FQDHardwareCursorName)),
    Self, 'CreateHardwareCursor', 'QDRegisterNamedPixMapCursor');
end;

{------------------------------------------------------------------------------
  Method:  TCarbonCursor.CreateColorCursor
  Params:  ABitmap  - Cursor image
           AHotSpot - Hot spot position

  Creates new color cursor
 ------------------------------------------------------------------------------}
procedure TCarbonCursor.CreateColorCursor(ABitmap: TCarbonBitmap; AHotSpot: Point);
var
  Bounds: Rect;
  i, j, rowBytes: integer;
  SrcRowPtr, SrcPtr, DstRowPtr: PByte;
  RowMask, RowData, Bit: UInt16;
begin
  FCursorType := cctQDColor;
  Bounds.top := 0;
  Bounds.left := 0;
  Bounds.bottom := 16;
  Bounds.right := 16;

  FPixmapHandle := PixMapHandle(NewHandleClear(SizeOf(PixMap)));
  FPixmapHandle^^.baseAddr := nil;
  FPixmapHandle^^.bounds := Bounds;
  FPixmapHandle^^.pmVersion := 0;
  FPixmapHandle^^.packType := 0;
  FPixmapHandle^^.packSize := 0;
  FPixmapHandle^^.hRes := $00480000; // 72 dpi
  FPixmapHandle^^.vRes := $00480000; // 72 dpi
  FPixmapHandle^^.pixelType := RGBDirect;
  FPixmapHandle^^.cmpSize := ABitmap.BitsPerComponent;
  FPixmapHandle^^.cmpCount := ABitmap.Depth div FPixmapHandle^^.cmpSize;  // $AARRGGBB
  FPixmapHandle^^.pixelSize := ABitmap.FBitsPerPixel; // depth
  rowBytes := FPixmapHandle^^.Bounds.right * (FPixmapHandle^^.pixelSize shr 3);
  // tell that this is pixmap (bit 15 := 1)
  FPixmapHandle^^.rowBytes := SInt16(rowBytes or $8000);
  FPixmapHandle^^.pmTable := nil;

  // create cursor handle
  FQDColorCursorHandle := CCrsrHandle(NewHandleClear(SizeOf(CCrsr)));
  FQDColorCursorHandle^^.crsrType := SInt16($8001); // color cursor ($8000 - bw)
  FQDColorCursorHandle^^.crsrMap := FPixmapHandle;
  FQDColorCursorHandle^^.crsrXData := nil;
  FQDColorCursorHandle^^.crsrXValid := 0;
  FQDColorCursorHandle^^.crsrXHandle := nil;
  FQDColorCursorHandle^^.crsrHotspot.h := Min(15, AHotSpot.h);
  FQDColorCursorHandle^^.crsrHotspot.v := Min(15, AHotSpot.v);
  FQDColorCursorHandle^^.crsrXTable := 0;
  FQDColorCursorHandle^^.crsrID := GetCTSeed;

  // handle for data with size = rowBytes * height
  FQDColorCursorHandle^^.crsrData := NewHandleClear(rowBytes * FPixmapHandle^^.bounds.bottom);

  // fill cursor bitmap and mask
  SrcRowPtr := ABitmap.Data;
  DstRowPtr := PByte(FQDColorCursorHandle^^.crsrData^);
  for i := 0 to 15 do
  begin
    RowMask := 0;
    RowData := 0;
    Bit := $8000;
    SrcPtr := SrcRowPtr;
    System.Move(SrcPtr^, DstRowPtr^, 16 * 4);
    for j := 0 to 15 do
    begin
      // check alpha
      if SrcPtr[0] and $FF = 0 then
        RowData := RowData or Bit
      else
        RowMask := RowMask or Bit;

      Bit := Bit shr 1;
      Inc(SrcPtr, 4);
    end;
 {$IFDEF ENDIAN_BIG}
    FQDColorCursorHandle^^.crsrMask[i] := SInt16(RowMask);
    FQDColorCursorHandle^^.crsr1Data[i] := SInt16(RowData);
 {$ELSE}
    FQDColorCursorHandle^^.crsrMask[i] := SInt16(CFSwapInt16(RowMask));
    FQDColorCursorHandle^^.crsr1Data[i] := SInt16(CFSwapInt16(RowData));
 {$ENDIF}
    Inc(SrcRowPtr, ABitmap.BytesPerRow);
    Inc(DstRowPtr, rowBytes);
  end;
end;

{------------------------------------------------------------------------------
  Method:  TCarbonCursor.CreateFromInfo
  Params:  AInfo - Cusrsor info

  Creates new cursor from the specified info
 ------------------------------------------------------------------------------}
constructor TCarbonCursor.CreateFromInfo(AInfo: PIconInfo);
var
  AHotspot: Point;
  AMaskedBitmap: TCarbonBitmap;
begin
  Create;

  if (AInfo^.hbmColor = 0) or not (TObject(AInfo^.hbmColor) is TCarbonBitmap) then
    Exit;

  AHotspot.h := AInfo^.xHotspot;
  AHotspot.v := AInfo^.yHotspot;
  
  AMaskedBitmap := TCarbonBitmap(AInfo^.hbmColor);
  if (AInfo^.hbmMask <> 0) then
  begin
    AMaskedBitmap := TCarbonBitmap.Create(AMaskedBitmap);
    AMaskedBitmap.AddMask(TCarbonBitmap(AInfo^.hbmMask));
  end;
  
  if HardwareCursorsSupported then
    CreateHardwareCursor(AMaskedBitmap, AHotSpot)
  else
    CreateColorCursor(AMaskedBitmap, AHotSpot);

   if (AInfo^.hbmMask <> 0) then
     AMaskedBitmap.Free;
end;

{------------------------------------------------------------------------------
  Method:  TCarbonCursor.CreateThemed
  Params:  AThemeCursor - Theme cursor kind

  Creates new theme cursor
 ------------------------------------------------------------------------------}
constructor TCarbonCursor.CreateThemed(AThemeCursor: ThemeCursor;
  ADefault: Boolean);
const
  kThemeCursorTypeMap: array[kThemeArrowCursor..22] of TCarbonCursorType =
  (
    cctTheme,    // kThemeArrowCursor
    cctTheme,    // kThemeCopyArrowCursor
    cctTheme,    // kThemeAliasArrowCursor
    cctTheme,    // kThemeContextualMenuArrowCursor
    cctTheme,    // kThemeIBeamCursor
    cctTheme,    // kThemeCrossCursor
    cctTheme,    // kThemePlusCursor
    cctAnimated, // kThemeWatchCursor
    cctTheme,    // kThemeClosedHandCursor
    cctTheme,    // kThemeOpenHandCursor
    cctTheme,    // kThemePointingHandCursor
    cctAnimated, // kThemeCountingUpHandCursor
    cctAnimated, // kThemeCountingDownHandCursor
    cctAnimated, // kThemeCountingUpAndDownHandCursor
    cctWait,     // kThemeSpinningCursor (!!! obsolte and thats why we should use wait instead)
    cctTheme,    // kThemeResizeLeftCursor
    cctTheme,    // kThemeResizeRightCursor
    cctTheme,    // kThemeResizeLeftRightCursor
    cctTheme,    // kThemeNotAllowedCursor
    cctTheme,    // kThemeResizeUpCursor
    cctTheme,    // kThemeResizeDownCursor
    cctTheme,    // kThemeResizeUpDownCursor
    cctTheme     // kThemePoofCursor
  );
begin
  Create;
  FDefault := ADefault;
  FThemeCursor := AThemeCursor;
  if (AThemeCursor {%H-}>= Low(kThemeCursorTypeMap)) and
     (AThemeCursor <= High(kThemeCursorTypeMap)) then
    FCursorType := kThemeCursorTypeMap[FThemeCursor] else
    FCursorType := cctTheme;
end;

{------------------------------------------------------------------------------
  Method:  TCarbonCursor.Destroy

  Frees Carbon cursor
 ------------------------------------------------------------------------------}
destructor TCarbonCursor.Destroy;
begin
  UnInstall;
  
  case CursorType of
    cctQDHardware:
      if FQDHardwareCursorName <> '' then
      begin
        OSError(QDUnregisterNamedPixmapCursor(PChar(FQDHardwareCursorName)),
          Self, SDestroy, 'QDUnregisterNamedPixmapCursor');
        
        FPixmapHandle^^.baseAddr := nil;
        DisposePixMap(FPixmapHandle);
      end;
    cctQDColor:
      DisposeCCursor(FQDColorCursorHandle);  // suppose pixmap will be disposed too
  end;
  
  inherited Destroy;
end;

{------------------------------------------------------------------------------
  Method:  TCarbonCursor.Install

  Installs Carbon cursor
 ------------------------------------------------------------------------------}
procedure TCarbonCursor.Install;
const
  SName = 'Install';
begin
  {$IFDEF VerboseCursor}
    DebugLn('TCarbonCursor.Install type: ', DbgS(Ord(CursorType)));
  {$ENDIF}
  
  case CursorType of
    cctQDHardware:
      if FQDHardwareCursorName <> '' then
        OSError(QDSetNamedPixmapCursor(PChar(FQDHardwareCursorName)),
          Self, SName, 'QDSetNamedPixmapCursor');
    cctQDColor:
      SetCCursor(FQDColorCursorHandle);
    cctTheme:
      OSError(SetThemeCursor(FThemeCursor),
        Self, SName, 'SetThemeCursor');
    cctAnimated:
      begin
        FAnimationStep := 0;
        CreateThread;
      end;
    cctWait:
      QDDisplayWaitCursor(True);
    else
      DebugLn('[TCarbonCursor.Apply] !!! Unknown cursor type');
  end;
end;

{------------------------------------------------------------------------------
  Method:  TCarbonCursor.UnInstall

  Uninstalls Carbon cursor
 ------------------------------------------------------------------------------}
procedure TCarbonCursor.UnInstall;
begin
  case CursorType of
    cctWait: QDDisplayWaitCursor(False);
    cctAnimated: DestroyThread;
  end;
end;

{------------------------------------------------------------------------------
  Method:  TCarbonCursor.StepAnimation
  Returns: If the function succeeds

  Steps Carbon cursor animation
 ------------------------------------------------------------------------------}
function TCarbonCursor.StepAnimation: Boolean;
begin
  Result := SetAnimatedThemeCursor(FThemeCursor, FAnimationStep) <> themeBadCursorIndexErr;
  if Result then
  begin
    inc(FAnimationStep);
  end else
  begin
    FCursorType := cctTheme;
    SetThemeCursor(FThemeCursor);
  end;
end;

{------------------------------------------------------------------------------
  Method:  TCarbonCursor.HardwareCursorsSupported
  Returns: If hardware cursors are supported
 ------------------------------------------------------------------------------}
class function TCarbonCursor.HardwareCursorsSupported: Boolean;
var
  P: Point;
  ATestCursorName: String;
  ATempPixmap: PixmapHandle;
begin
  if MHardwareCursorsSupported = hcaUndef then
  begin
    ATestCursorName := Application.Title + LazarusCursorInfix + 'test';
    P.v := 0;
    P.h := 0;
    
    ATempPixmap := PixMapHandle(NewHandleClear(SizeOf(PixMap)));
    if QDRegisterNamedPixMapCursor(ATempPixmap, nil, P, PChar(ATestCursorName)) = kQDNoColorHWCursorSupport then
      MHardwareCursorsSupported := hcaUnavailable else
      MHardwareCursorsSupported := hcaAvailable;
    QDUnregisterNamedPixmapCursor(PChar(ATestCursorName));
    DisposePixMap(ATempPixmap);
  end;
  Result := MHardwareCursorsSupported = hcaAvailable;
end;

function GetScanLine(Bitmap: TCarbonBitmap; Line: Integer): PByteArray;
begin
  if (Line>=Bitmap.Height) or (Line<0) then Result:=nil
  else Result:=PByteArray(@PByteArray(Bitmap.Data)^[ Bitmap.BytesPerRow*Line ]);
end;

type
  TColorPos = record
    ri  : Byte;
    gi  : Byte;
    bi  : Byte;
    ai  : Byte;
  end;

procedure GetRGBA24(Bitmap: TCarbonBitmap; X,Y: Integer; out r,g,b,a: Byte; const pos: TColorPos);
var
  line  : PByteArray;
begin
  line:=GetScanLine(Bitmap, Y);
  if not Assigned(line) then begin
    r:=0;g:=0;b:=0;a:=$FF;
    Exit;
  end;
  r:=line^[x*3+pos.ri];
  g:=line^[x*3+pos.gi];
  b:=line^[x*3+pos.bi];
  a:=255;
end;

procedure SetRGBA24(Bitmap: TCarbonBitmap; X,Y: Integer; r,g,b,{%H-}a: Byte; const pos: TColorPos);
var
  line  : PByteArray;
begin
  line:=GetScanLine(Bitmap, Y);
  if not Assigned(line) then Exit;
  line^[x*3+pos.ri]:=r;
  line^[x*3+pos.gi]:=g;
  line^[x*3+pos.bi]:=b;
end;

procedure GetRGBA32(Bitmap: TCarbonBitmap; X,Y: Integer; out r,g,b,a: Byte; const pos: TColorPos);
var
  line  : PByteArray;
begin
  line:=GetScanLine(Bitmap, Y);
  if not Assigned(line) then begin
    r:=0;g:=0;b:=0;a:=$FF;
    Exit;
  end;
  r:=line^[x*4+pos.ri];
  g:=line^[x*4+pos.gi];
  b:=line^[x*4+pos.bi];
  a:=line^[x*4+pos.ai];
end;

procedure SetRGBA32(Bitmap: TCarbonBitmap; X,Y: Integer; r,g,b,a: Byte; const pos: TColorPos);
var
  line  : PByteArray;
begin
  line:=GetScanLine(Bitmap, Y);
  if not Assigned(line) then Exit;
  line^[x*4+pos.ri]:=r;
  line^[x*4+pos.gi]:=g;
  line^[x*4+pos.bi]:=b;
  line^[x*4+pos.ai]:=a;
end;

//todo: add support for non 24-32 bit images
//todo: faster and better code!
//todo: support for iBorderColor (currently ignored both ABorderColor and isBorderColor settings)
function FloodFillBitmap(const Bitmap: TCarbonBitmap; X,Y: Integer; ABorderColor, FillColor: TColor; isBorderColor: Boolean): Boolean;
var
  sr, sg, sb, sa  : Byte;
  tr, tg, tb, ta  : Byte;
  r,g,b,a : Byte;
  data  : array of TPoint;
  cnt   : Integer;
  i,j   : Integer;
  k     : Integer;
  clpos : TColorPos;
  FillColorRef: TColorRef;
const
  LEPos : TColorPos = (ri:1;gi:2;bi:3;ai:0);
const
  dx : array [0..3] of Integer = (-1,1,0,0);
  dy : array [0..3] of Integer = (0,0,-1,1);
var
  GetRGBA: procedure (Bitmap: TCarbonBitmap; X,Y: Integer; out r,g,b,a: Byte; const pos: TColorPos);
  SetRGBA: procedure (Bitmap: TCarbonBitmap; X,Y: Integer; r,g,b,a: Byte; const pos: TColorPos);
begin
  FillColorRef:=ColorToRGB(FillColor);
  r:=FillColorRef and $FF;
  g:=(FillColorRef shr 8) and $FF;
  b:=(FillColorRef shr 16) and $FF;
  a:=$FF;
  GetRGBA:=nil;
  SetRGBA:=nil;
  clpos:=LEPos; //todo: Little endian, big endian or bitmap specific
  if Bitmap.BitsPerComponent=8 then
  begin
    if Bitmap.FBitsPerPixel=32 then
    begin
      GetRGBA:=@GetRGBA32;
      SetRGBA:=@SetRGBA32;
    end else
    begin
      GetRGBA:=@GetRGBA24;
      SetRGBA:=@SetRGBA24;
    end;
  end;
  Result:=Assigned(GetRGBA);
  if not Result then Exit;

  try
    GetRGBA(Bitmap, x,y, sr, sg, sb, sa, clpos);
    if (sr=r) and (sg=g) and (sb=b) then Exit;
    SetLength(data, Bitmap.Width*Bitmap.Height);
    cnt:=1;
    data[0].x:=x;
    data[0].y:=y;
    SetRGBA(Bitmap, x,y, r, g, b, a, clPos);

    while cnt>0 do
    begin
      x:=data[0].x;
      y:=data[0].y;
      for k:=0 to 3 do
      begin
        i:=x+dx[k];
        j:=y+dy[k];
        if (i<0) or (j<0) or (i>=Bitmap.Width) or (j>=Bitmap.Height) then Continue;
        GetRGBA(Bitmap, i,j, tr, tg, tb, ta, clPos);
        if (tr=sr) and (tg=sg) and (tb=sb) then
        begin
          SetRGBA(Bitmap, i,j, r, g, b, a, clPos);
          data[cnt].X:=i;
          data[cnt].Y:=j;
          inc(cnt);
        end;
      end;
      dec(cnt);
      data[0]:=data[cnt];
    end;
  finally
    Bitmap.UpdateImage;
  end;
end;

var
  LogBrush: TLogBrush;

initialization

  InitCursor;

  StockSystemFont := TCarbonFont.Create(True);

  LogBrush.lbStyle := BS_NULL;
  LogBrush.lbColor := 0;
  StockNullBrush := TCarbonBrush.Create(LogBrush);

  WhiteBrush := TCarbonBrush.Create(True);
  BlackPen := TCarbonPen.Create(True);
  
  DefaultFont := TCarbonFont.Create(True);

  DefaultBrush := TCarbonBrush.Create(True);
  DefaultPen := TCarbonPen.Create(True);
  
  DefaultContext := TCarbonBitmapContext.Create;
  DefaultBitmap := TCarbonBitmap.Create(1, 1, 32, 32, cbaDQWord, cbtARGB, nil);
  DefaultContext.Bitmap := DefaultBitmap;
  
  ScreenContext := TCarbonScreenContext.Create;
  ScreenContext.CGContext := DefaultContext.CGContext; // workaround

finalization
  DefaultContext.Free;
  ScreenContext.Free;
  
  DefaultBrush.Free;
  DefaultPen.Free;
  
  DefaultFont.Free;
  
  BlackPen.Free;
  WhiteBrush.Free;

  StockNullBrush.Free;
  StockSystemFont.Free;
  
  DefaultBitmap.Free;

end.

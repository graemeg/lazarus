{%MainUnit qtint.pp}
{ $Id$ }
{******************************************************************************
  All QT Winapi implementations.
  This are the implementations of the overrides of the QT Interface for the
  methods defined in the
  lcl/include/winapi.inc


  !! Keep alphabetical !!


 ******************************************************************************
 Implementation
 ******************************************************************************

 *****************************************************************************
  This file is part of the Lazarus Component Library (LCL)

  See the file COPYING.modifiedLGPL.txt, included in this distribution,
  for details about the license.
 *****************************************************************************
}

//##apiwiz##sps##   // Do not remove, no wizard declaration before this line

{------------------------------------------------------------------------------
  Function: Arc
  Params: DC: HDC; Left,Top,Right,Bottom,angle1,angle2 : Integer
  Returns: Boolean
 ------------------------------------------------------------------------------}
function TQtWidgetSet.Arc(DC: HDC; Left,Top,Right,Bottom,angle1,angle2 : Integer): Boolean;
var
  R: TRect;
begin
  {$ifdef VerboseQtWinAPI}
    WriteLn('[WinAPI Arc] DC: ', dbghex(DC));
  {$endif}
  Result := IsValidDC(DC);

  if Result then
  begin
    R := Rect(Left, Top, Right, Bottom);
    QPainter_drawArc(TQtDeviceContext(DC).Widget, @R, Angle1, Angle2);
  end;
end;

{------------------------------------------------------------------------------
  Function: AngleChord
  Params: DC: HDC; x1, y1, x2, y2, angle1, angle2: Integer
  Returns: Boolean
 ------------------------------------------------------------------------------}
function TQtWidgetSet.AngleChord(DC: HDC; x1, y1, x2, y2, angle1, angle2: Integer): Boolean;
begin
  {$ifdef VerboseQtWinAPI}
    WriteLn('[WinAPI AngleChord] DC: ', dbghex(DC));
  {$endif}
  Result := IsValidDC(DC);
  if Result then
    QPainter_drawChord(TQtDeviceContext(DC).Widget, x1, y1, x2 - x1, y2 - y1, Angle1, Angle2);
end;

{------------------------------------------------------------------------------
  Function: BeginPaint
  Params:
  Returns:

  This function is Called:
  - Once on every OnPaint event
 ------------------------------------------------------------------------------}
function TQtWidgetSet.BeginPaint(Handle: hWnd; Var PS: TPaintStruct): hdc;
var
  Widget: TQtWidget;
  DC: TQtDeviceContext;
begin
  {$ifdef VerboseQtWinAPI}
    WriteLn('Trace:> [WinAPI BeginPaint] Handle=', dbghex(Handle));
  {$endif}
  Widget := TQtWidget(Handle);
  if Widget <> nil then
    DC := TQtDeviceContext.Create(Widget.PaintData.PaintWidget, True)
  else
    DC := TQtDeviceContext.Create(nil, True);

  PS.hdc := HDC(DC);

  if Handle<>0 then
  begin
    // if current handle has paintdata information,
    // setup hdc with it
    //DC.DebugClipRect('BeginPaint: Before');
    if (QtVersionMajor = 4) and (QtVersionMinor > 6) then
      QPainter_setLayoutDirection(DC.Widget, QtLayoutDirectionAuto);
    if Widget.PaintData.ClipRegion <> nil then
    begin
      //Write('>>> Setting Paint ClipRegion: ');
      //DebugRegion('PaintData.ClipRegion: ', Widget.PaintData.ClipRegion);
      DC.setClipRegion(Widget.PaintData.ClipRegion);
      DC.setClipping(True);
    end;
    if Widget.PaintData.ClipRect <> nil then
    begin
      New(DC.vClipRect);
      DC.vClipRect^ := Widget.PaintData.ClipRect^;
    end;
  end;

  Result := PS.hdc;

  {$ifdef VerboseQtWinAPI}
    WriteLn('Trace:< [WinAPI BeginPaint] Result=', dbghex(Result));
  {$endif}
end;

function TQtWidgetSet.BitBlt(DestDC: HDC; X, Y, Width, Height: Integer; SrcDC: HDC; XSrc, YSrc: Integer; Rop: DWORD): Boolean;
begin
  {$ifdef VerboseQtWinAPI}
    WriteLn('Trace:> [TQtWidgetSet.BitBlt]');
  {$endif}

  Result := StretchBlt(DestDC, X, Y, Width, Height, SrcDC, XSrc, YSrc, Width,
                       Height, ROP);

  {$ifdef VerboseQtWinAPI}
    WriteLn('Trace:< [TQtWidgetSet.BitBlt]');
  {$endif}
end;

function TQtWidgetSet.CallNextHookEx(hHk: HHOOK; ncode : Integer; wParam: WParam; lParam : LParam) : Integer;
begin
  {$ifdef VerboseQtWinAPI_MISSING_IMPLEMENTATION}
  	WriteLn('***** [WinAPI TQtWidgetSet.CallNextHookEx] missing implementation ');
  {$endif}
  Result := 0;
end;

function TQtWidgetSet.CallWindowProc(lpPrevWndFunc : TFarProc; Handle : HWND; Msg : UINT; wParam: WParam; lParam : lParam) : Integer;
begin
  {$ifdef VerboseQtWinAPI_MISSING_IMPLEMENTATION}
  	WriteLn('***** [WinAPI TQtWidgetSet.CallWindowProc] missing implementation ');
  {$endif}
  Result := -1;
end;

{------------------------------------------------------------------------------
  Method:  ClientToScreen
  Params:  Handle    -
  Returns:
 ------------------------------------------------------------------------------}
function TQtWidgetSet.ClientToScreen(Handle: HWND; var P: TPoint) : Boolean;
begin
  Result := IsValidHandle(Handle);
  if Result then
    P := TQtWidget(Handle).MapToGlobal(P, True);
end;


function TQtWidgetSet.ClipboardFormatToMimeType(FormatID: TClipboardFormat): string;
begin
  Result := Clipboard.FormatToMimeType(FormatID);
end;

function TQtWidgetSet.ClipboardGetData(ClipboardType: TClipboardType;
  FormatID: TClipboardFormat; Stream: TStream): boolean;
begin
  Result := Clipboard.Getdata(ClipboardType, FormatID, Stream);
end;

function TQtWidgetSet.ClipboardGetFormats(ClipboardType: TClipboardType;
  var Count: integer; var List: PClipboardFormat): boolean;
begin
  Result := Clipboard.GetFormats(ClipboardType, Count, List);
end;

function TQtWidgetSet.ClipboardGetOwnerShip(ClipboardType: TClipboardType;
  OnRequestProc: TClipboardRequestEvent;  FormatCount: integer;
  Formats: PClipboardFormat): boolean;
begin
  Result := Clipboard.GetOwnerShip(ClipboardType, OnRequestProc, FormatCount, Formats);
end;

function TQtWidgetSet.ClipboardRegisterFormat(const AMimeType: string): TClipboardFormat;
begin
  Result := Clipboard.RegisterFormat(AMimeType);
end;


{------------------------------------------------------------------------------
  Function: CombineRgn
  Params:  Dest, Src1, Src2, fnCombineMode
  Returns: longint

  Combine the 2 Source Regions into the Destination Region using the specified
  Combine Mode. The Destination must already be initialized. The Return value
  is the Destination's Region type, or ERROR.

  The Combine Mode can be one of the following:
      RGN_AND  : Gets a region of all points which are in both source regions

      RGN_COPY : Gets an exact copy of the first source region

      RGN_DIFF : Gets a region of all points which are in the first source
                 region but not in the second.(Source1 - Source2)

      RGN_OR   : Gets a region of all points which are in either the first
                 source region or in the second.(Source1 + Source2)

      RGN_XOR  : Gets all points which are in either the first Source Region
                 or in the second, but not in both.

  The result can be one of the following constants
      Error
      NullRegion
      SimpleRegion
      ComplexRegion

 ------------------------------------------------------------------------------}
function TQtWidgetSet.CombineRgn(Dest, Src1, Src2: HRGN; fnCombineMode: Longint): Longint;
var
  RDest,RSrc1,RSrc2: QRegionH;
begin
  result:=ERROR;

  if not IsValidGDIObject(Dest) or not IsValidGDIObject(Src1) then
    exit
  else
  begin
    RDest := TQtRegion(Dest).FHandle;
    RSrc1 := TQtRegion(Src1).FHandle;
  end;

  if (fnCombineMode<>RGN_COPY) and not IsValidGDIObject(Src2) then
    exit
  else
    RSrc2 := TQtRegion(Src2).FHandle;

  case fnCombineMode of
    RGN_AND:
      QRegion_intersected(RSrc1, RDest, RSrc2);
    RGN_COPY:
      begin
        // union of Src1 with a null region
        RSrc2 := QRegion_create;
        QRegion_united(RSrc1, RDest, RSrc2);
        QRegion_destroy(RSrc2);
      end;
    RGN_DIFF:
      QRegion_subtracted(RSrc1, RDest, RSrc2);
    RGN_OR:
      QRegion_united(RSrc1, RDest, RSrc2);
    RGN_XOR:
      QRegion_xored(RSrc1, RDest, RSrc2);
  end;

  if QRegion_isEmpty(RDest) then
    Result := NULLREGION
  else
  begin
    if TQtRegion(Dest).IsPolyRegion or (TQtRegion(Dest).numRects > 0) then
      Result := COMPLEXREGION
    else
      Result := SIMPLEREGION;
  end;
end;

{------------------------------------------------------------------------------
  Method:  TQtWidgetSet.CreateCompatibleBitmap
  Params: HDC, Width & Height
  Returns: HBITMAP

 ------------------------------------------------------------------------------}
function TQtWidgetSet.CreateCompatibleBitmap(DC: HDC; Width, Height: Integer): HBITMAP;
var
  QtDC: TQtDeviceContext;
  Format: QImageFormat = QImageFormat_ARGB32;
  ADevice: QPaintDeviceH = nil;
  ADesktop: QDesktopWidgetH = nil;
begin
  {$ifdef VerboseQtWinAPI}
    WriteLn('Trace:> [WinAPI CreateCompatibleBitmap]',
     ' DC:', dbghex(DC),
     ' Width:', dbgs(Width),
     ' Height:', dbgs(Height));
  {$endif}
  Result := 0;
  if IsValidDC(DC) then
  begin
    QtDC := TQtDeviceContext(DC);
    case QtDC.getDepth of
      1: Format := QImageFormat_Mono;
      15, 16: Format := QImageFormat_RGB16;
      24: Format := QImageFormat_RGB32;
      32: Format := QImageFormat_ARGB32;
    end;
  end else
  begin
    ADesktop := QApplication_desktop();
    if ADesktop <> nil then
      ADevice := QWidget_to_QPaintDevice(ADesktop);
    if ADevice <> nil then
    begin
      case QPaintDevice_depth(ADevice) of
        1: Format := QImageFormat_Mono;
        15, 16: Format := QImageFormat_RGB16;
        24: Format := QImageFormat_RGB32;
        32: Format := QImageFormat_ARGB32;
      end;
    end;
  end;
  Result := HBitmap(TQtImage.Create(nil, Width, Height, Format));
  {$ifdef VerboseQtWinAPI}
    WriteLn('Trace:< [WinAPI CreateCompatibleBitmap] Bitmap:', dbghex(Result));
  {$endif}
end;

{------------------------------------------------------------------------------
  Method:  TQtWidgetSet.CreateBitmap
  Params:
  Returns:

  This functions is for TBitmap support.
  Specifically it´s utilized on when a handle for a bitmap is needed
 ------------------------------------------------------------------------------}
function TQtWidgetSet.CreateBitmap(Width, Height: Integer;
  Planes, BitCount: Longint; BitmapBits: Pointer): HBITMAP;
var
  Format: QImageFormat;
  NewBits: PByte;
  NewBitsSize: PtrUInt;
  ARowStride, RSS: Integer;
begin
  {$ifdef VerboseQtWinAPI}
    WriteLn('Trace:> [WinAPI CreateBitmap]',
     ' Width:', dbgs(Width),
     ' Height:', dbgs(Height),
     ' Planes:', dbgs(Planes),
     ' BitCount:', dbgs(BitCount),
     ' BitmapBits: ', dbgs(BitmapBits));
  {$endif}

  // for win32 data is aligned to WORD
  // for qt we must realign data to DWORD

  case BitCount of
    1: Format := QImageFormat_Mono;
    15, 16: Format := QImageFormat_RGB16;
    24: Format := QImageFormat_RGB32;
    32: Format := QImageFormat_ARGB32;
  else
    Format := QImageFormat_ARGB32;
  end;

  RSS := GetBytesPerLine(Width, BitCount, rileWordBoundary);
  if BitmapBits <> nil then
  begin
    ARowStride := GetBytesPerLine(Width, BitCount, rileDWordBoundary);
    if not CopyImageData(Width, Height, RSS, BitCount, BitmapBits, Rect(0, 0, Width, Height),
      riloBottomToTop, riloBottomToTop, rileDWordBoundary, NewBits, NewBitsSize) then
    begin
      // this was never tested
      ARowStride := RSS;
      NewBits := AllocMem(RSS * Height);
      Move(BitmapBits^, NewBits^, RSS * Height);
    end;
    Result := HBitmap(TQtImage.Create(NewBits, Width, Height, ARowStride, Format, True));
  end
  else
    Result := HBitmap(TQtImage.Create(nil, Width, Height, Format));

  {$ifdef VerboseQtWinAPI}
    WriteLn('Trace:< [WinAPI CreateBitmap] Bitmap:', dbghex(Result));
  {$endif}
end;


{------------------------------------------------------------------------------
  Function:  CreateBrushIndirect
  Params:  none
  Returns: Nothing
 ------------------------------------------------------------------------------}
function TQtWidgetSet.CreateBrushIndirect(const LogBrush: TLogBrush): HBRUSH;
var
  QtBrush: TQtBrush;
  Color: TQColor;
begin
  {$ifdef VerboseQtWinAPI}
    WriteLn(Format('Trace:> [WinAPI CreateBrushIndirect]  Style: %d, Color: %8x (%s)',
      [LogBrush.lbStyle, LogBrush.lbColor, ColorToString(LogBrush.lbColor)]));
  {$endif}

  Result := 0;

  QtBrush := TQtBrush.Create(True);

  try
    case LogBrush.lbStyle of
      BS_NULL: QtBrush.Style := QtNoBrush; // Same as BS_HOLLOW.
      BS_SOLID: QtBrush.Style := QtSolidPattern;

      BS_HATCHED: // Hatched brushes.
      begin
        case LogBrush.lbHatch of
          HS_BDIAGONAL: QtBrush.Style := QtBDiagPattern;
          HS_CROSS: QtBrush.Style := QtCrossPattern;
          HS_DIAGCROSS: QtBrush.Style := QtDiagCrossPattern;
          HS_FDIAGONAL: QtBrush.Style := QtFDiagPattern;
          HS_HORIZONTAL: QtBrush.Style := QtHorPattern;
          HS_VERTICAL: QtBrush.Style := QtVerPattern;
        else
          QtBrush.Style := QtSolidPattern;
        end;
      end;

      BS_DIBPATTERN,     // A pattern brush defined by a device-independent
             // bitmap (DIB) specification. If lbStyle is BS_DIBPATTERN, the
             // lbHatch member contains a handle to a packed DIB.Windows 95:
             // Creating brushes from bitmaps or DIBs larger than 8x8 pixels
             // is not supported. If a larger bitmap is given, only a portion
             // of the bitmap is used.
      BS_DIBPATTERN8X8,  // Same as BS_DIBPATTERN.
      BS_DIBPATTERNPT,   // A pattern brush defined by a device-independent
             // bitmap (DIB) specification. If lbStyle is BS_DIBPATTERNPT, the
             // lbHatch member contains a pointer to a packed DIB.
      BS_PATTERN,        // Pattern brush defined by a memory bitmap.
      BS_PATTERN8X8:     // Same as BS_PATTERN.
      begin
        QtBrush.setTextureImage(TQtImage(LogBrush.lbHatch).Handle);
        QtBrush.Style := QtTexturePattern;
      end;
    else
      DebugLn(Format('Unsupported Style %d',[LogBrush.lbStyle]));
    end;

    {
      Other non-utilized Qt brushes:
        QtDense1Pattern,
        QtDense2Pattern,
        QtDense3Pattern,
        QtDense4Pattern,
        QtDense5Pattern,
        QtDense6Pattern,
        QtDense7Pattern,
        QtLinearGradientPattern,
        QtRadialGradientPattern,
        QtConicalGradientPattern
    }

    // set brush color
    Color := QBrush_Color(QtBrush.FHandle)^;
    ColorRefToTQColor(ColorToRGB(TColor(logBrush.lbColor)), Color);
    QtBrush.setColor(@Color);
    Result := HBRUSH(QtBrush);
  except
    Result := 0;
    DebugLn('TQtWidgetSet.CreateBrushIndirect: Failed');
  end;

  {$ifdef VerboseQtWinAPI}
    WriteLn('Trace:< [WinAPI CreateBrushIndirect] Result: ', dbghex(Result));
  {$endif}
end;

{------------------------------------------------------------------------------
  Function:  CreateBrushWithRadialGradient
  Params:  none
  Returns: Nothing
 ------------------------------------------------------------------------------}
function TQtWidgetSet.CreateBrushWithRadialGradient(const LogBrush: TLogRadialGradient): HBRUSH;
var
  QtBrush: TQtBrush;
begin
  Result := 0;

  QtBrush := TQtBrush.CreateWithRadialGradient(LogBrush);
  Result := HBRUSH(QtBrush);
  if Result = 0 then
    DebugLn('TQtWidgetSet.CreateBrushWithRadialGradient: Failed');
end;

function TQtWidgetSet.CreateCaret(Handle: HWND; Bitmap: hBitmap; Width, Height: Integer): Boolean;
begin
  Result := (Handle <> 0) and
    QtCaret.CreateCaret(TQtWidget(Handle), Bitmap, Width, Height);
end;

{------------------------------------------------------------------------------
  Function: CreateCompatibleDC
  Params:  DC - handle to memory device context
  Returns: handle to a memory device context

  Creates a memory device context (DC) compatible with the specified device.
 ------------------------------------------------------------------------------}
function TQtWidgetSet.CreateCompatibleDC(DC: HDC): HDC;
begin
  {$ifdef VerboseQtWinAPI}
    WriteLn('[WinAPI CreateCompatibleDC] DC: ', dbghex(DC));
  {$endif}
  Result := HDC(TQtDeviceContext.Create(nil, True));
end;

{------------------------------------------------------------------------------
  Function: CreateEllipticRgn
  Params:  p1 - X position of the top-left corner
           p2 - Y position of the top-left corner
           p3 - X position of the bottom-right corner
           p4 - Y position of the bottom-right corner
  Returns: HRGN
 ------------------------------------------------------------------------------}
function TQtWidgetSet.CreateEllipticRgn(p1, p2, p3, p4: Integer): HRGN;
var
  QtRegion: TQtRegion;
begin
  {$ifdef VerboseQtWinAPI}
    WriteLn('[WinAPI CreateEllipticRgn] ');
  {$endif}
  QtRegion := TQtRegion.Create(True, p1, p2, p3, p4, QRegionEllipse);
  Result := HRGN(QtRegion);
end;

{------------------------------------------------------------------------------
  Function: CreateFontIndirect
  Params:  const LogFont: TLogFont
  Returns: HFONT

  Creates a font GDIObject.
 ------------------------------------------------------------------------------}
function TQtWidgetSet.CreateFontIndirect(const LogFont: TLogFont): HFONT;
begin
  Result := CreateFontIndirectEx(LogFont, '');
end;

{------------------------------------------------------------------------------
  Function: CreateFontIndirectEx
  Params:  const LogFont: TLogFont
  Returns: HFONT

  Creates a font GDIObject.
 ------------------------------------------------------------------------------}
function TQtWidgetSet.CreateFontIndirectEx(const LogFont: TLogFont; const LongFontName: string): HFONT;
var
  QtFont: TQtFont;
  FamilyName: string;
const
  QStyleStategy: array [DEFAULT_QUALITY..CLEARTYPE_NATURAL_QUALITY] of QFontStyleStrategy = (
 { DEFAULT_QUALITY           } QFontPreferDefault,
 { DRAFT_QUALITY             } QFontPreferMatch,
 { PROOF_QUALITY             } QFontPreferQuality,
 { NONANTIALIASED_QUALITY    } QFontNoAntialias,
 { ANTIALIASED_QUALITY       } QFontPreferAntialias,
 { CLEARTYPE_QUALITY         } QFontPreferAntialias,
 { CLEARTYPE_NATURAL_QUALITY } QFontPreferAntialias
  );
begin
  {$ifdef VerboseQtWinAPI}
    WriteLn('[WinAPI CreateFontIndirectEx] FontName: ' + LongFontName);
  {$endif}

  Result := 0;

  QtFont := TQtFont.Create(True);
  try
    // -1 has different meaning - it means that font height was set using setPointSize
    if LogFont.lfHeight <> -1 then
      QtFont.setPixelSize(Abs(LogFont.lfHeight));

    // Some values at available on Qt documentation at a table
    // Others are guesses. The best would be to test different values for those
    // See: http://doc.trolltech.com/4.1/qfont.html#Weight-enum
    case LogFont.lfWeight of
      FW_THIN       : QtFont.setWeight(10);
      FW_EXTRALIGHT : QtFont.setWeight(15);
      FW_LIGHT      : QtFont.setWeight(25);
      FW_NORMAL     : QtFont.setWeight(50);
      FW_MEDIUM     : QtFont.setWeight(55);
      FW_SEMIBOLD   : QtFont.setWeight(63);
      FW_BOLD       : QtFont.setWeight(75);
      FW_EXTRABOLD  : QtFont.setWeight(80);
      FW_HEAVY      : QtFont.setWeight(87);
    end;

    QtFont.Angle := LogFont.lfEscapement;

    //LogFont.lfOrientation;

    QtFont.setItalic(LogFont.lfItalic = High(Byte));
    QtFont.setUnderline(LogFont.lfUnderline = High(Byte));
    QtFont.setStrikeOut(LogFont.lfStrikeOut = High(Byte));

    FamilyName := StrPas(LogFont.lfFaceName);

    if not IsFontNameDefault(FamilyName) then
      QtFont.setFamily(FamilyName)
    else
      QtFont.setFamily(GetDefaultAppFontName{%H-});

    if LogFont.lfQuality <= High(QStyleStategy) then
      QtFont.setStyleStrategy(QStyleStategy[LogFont.lfQuality]);
    Result := HFONT(QtFont);
  except
    Result := 0;
    DebugLn('TQtWidgetSet.CreateFontIndirectEx: Failed');
  end;
end;

function TQtWidgetSet.CreateIconIndirect(IconInfo: PIconInfo): HICON;
var
  AIcon: TQtIcon;
  APixmap, ATemp: QPixmapH;
  AMask: QBitmapH;
  {$IFDEF DARWIN}
  AImgFmt: QImageFormat;
  {$ENDIF}
begin
  Result := 0;
  if IsValidGDIObject(IconInfo^.hbmColor) then
  begin
    APixmap := QPixmap_create();
    QPixmap_fromImage(APixmap, TQtImage(IconInfo^.hbmColor).Handle);
    {$IFDEF DARWIN}
    AImgFmt := TQtImage(IconInfo^.hbmColor).getFormat;
    if (AImgFmt in [QImageFormat_Mono, QImageFormat_MonoLSB,
      QImageFormat_Indexed8, QImageFormat_RGB32]) then
    {$ENDIF}
    if IconInfo^.hbmMask <> 0 then
    begin
      ATemp := QPixmap_create();
      QPixmap_fromImage(ATemp, TQtImage(IconInfo^.hbmMask).Handle);
      AMask := QBitmap_create(ATemp);
      QPixmap_setMask(APixmap, AMask);
      QPixmap_destroy(ATemp);
      QBitmap_destroy(AMask);
    end;
    if IconInfo^.fIcon then
    begin
      AIcon := TQtIcon.Create;
      AIcon.addPixmap(APixmap);
      Result := HICON(AIcon);
    end else
      Result := HCURSOR(TQtCursor.Create(APixmap, IconInfo^.xHotspot, IconInfo^.yHotspot));
    QPixmap_destroy(APixmap);
  end;
end;

{------------------------------------------------------------------------------
  Function:  CreatePatternBrush
  Params:  HBITMAP
  Returns: HBRUSH
 ------------------------------------------------------------------------------}

function TQtWidgetSet.CreatePatternBrush(ABitmap: HBITMAP): HBRUSH;
var
  Image: QImageH;
  QtBrush: TQtBrush;
begin
  {$ifdef VerboseQtWinAPI}
    WriteLn('[WinAPI CreatePatternBrush]',' Bitmap=', dbghex(ABitmap));
  {$endif}
  Result := 0;
  if ABitmap = 0 then
    exit;
  QtBrush := TQtBrush.Create(True);
  Image := QImage_create(TQtImage(ABitmap).Handle);
  try
    QtBrush.setTextureImage(Image);
  finally
    QImage_destroy(Image);
  end;

  Result := HBRUSH(QtBrush);
end;

{------------------------------------------------------------------------------
  Function:  CreatePenIndirect
  Params:  none
  Returns: HPEN
 ------------------------------------------------------------------------------}

function TQtWidgetSet.CreatePenIndirect(const LogPen: TLogPen): HPEN;
var
  QtPen: TQtPen;
  color: TQColor;
begin
  Result := 0;
  QtPen := TQtPen.Create(True);
  with LogPen do
  begin
    case lopnStyle and PS_STYLE_MASK of
      PS_SOLID: QtPen.setStyle(QtSolidLine);
      PS_DASH: QtPen.setStyle(QtDashLine);
      PS_DOT: QtPen.setStyle(QtDotLine);
      PS_DASHDOT: QtPen.setStyle(QtDashDotLine);
      PS_DASHDOTDOT: QtPen.setStyle(QtDashDotDotLine);
      PS_NULL: QtPen.setStyle(QtNoPen);
    else
      QtPen.setStyle(QtSolidLine);
    end;

    if lopnWidth.X <= 0 then
      QtPen.setCosmetic(True)
    else
    begin
      QtPen.setCosmetic(False);
      QtPen.setWidth(lopnWidth.X);
    end;

    QPen_Color(QtPen.FHandle, @Color);
    ColorRefToTQColor(ColorToRGB(TColor(lopnColor)), Color);
    QPen_setColor(QtPen.FHandle, @Color);
  end;

  Result := HPEN(QtPen);
end;

{------------------------------------------------------------------------------
  Function: CreatePolygonRgn
  Params:  none
  Returns: HRGN

 ------------------------------------------------------------------------------}
function TQtWidgetSet.CreatePolygonRgn(Points: PPoint; NumPts: Integer; FillMode: integer): HRGN;
var
  QtRegion: TQtRegion;
  QtPoints: PQtPoint;
  i: Integer;
  Poly: QPolygonH;
begin
  {$ifdef VerboseQtWinAPI}
    WriteLn('Trace: [WinAPI CreatePolygonRgn] ');
  {$endif}
  GetMem(QtPoints, NumPts * SizeOf(TQtPoint));
  for i := 0 to NumPts - 1 do
    QtPoints[i] := QtPoint(Points[i].x, Points[i].y);
  Poly := QPolygon_create(NumPts, PInteger(QtPoints));
  FreeMem(QtPoints);
  try
    {fillmode can be ALTERNATE or WINDING as msdn says}
    if FillMode = ALTERNATE then
      QtRegion := TQtRegion.Create(True, Poly, QtOddEvenFill)
    else
      QtRegion := TQtRegion.Create(True, Poly, QtWindingFill);
    Result := HRGN(QtRegion);
  finally
    QPolygon_destroy(Poly);
  end;
end;

{------------------------------------------------------------------------------
  Function: CreateRectRgn
  Params:  none
  Returns: HRGN


 ------------------------------------------------------------------------------}
function TQtWidgetSet.CreateRectRgn(X1,Y1,X2,Y2 : Integer): HRGN;
var
  QtRegion: TQtRegion;
begin
  QtRegion := TQtRegion.Create(True, X1, Y1, X2, Y2);
  Result := HRGN(QtRegion);
  {$ifdef VerboseQtWinAPI}
    WriteLn('Trace: [WinAPI CreateRectRgn] Result: ', dbghex(Result),
     ' QRegionH: ', dbghex(PtrInt(QtRegion.Widget)));
  {$endif}
end;

{------------------------------------------------------------------------------
  Procedure: DeleteCriticalSection
  Params:  var CritSection: TCriticalSection
  Returns: Nothing
 ------------------------------------------------------------------------------}
procedure TQtWidgetSet.DeleteCriticalSection(var CritSection: TCriticalSection);
var
  ACritSec: System.PRTLCriticalSection;
begin
  ACritSec:=System.PRTLCriticalSection(CritSection);
  System.DoneCriticalsection(ACritSec^);
  Dispose(ACritSec);
  CritSection:=0;
end;

{------------------------------------------------------------------------------
  Function: DeleteDC
  Params:  none
  Returns: Nothing

 ------------------------------------------------------------------------------}
function TQtWidgetSet.DeleteDC(hDC: HDC): Boolean;
begin
  {$ifdef VerboseQtWinAPI}
    WriteLn('[WinAPI DeleteDC] Handle: ', dbghex(hDC));
  {$endif}

  Result := False;
  if not IsValidDC(hDC) then exit;

  TQtDeviceContext(hDC).Free;
end;

{------------------------------------------------------------------------------
  Function: DeleteObject
  Params:  none
  Returns: Nothing

 ------------------------------------------------------------------------------}
function TQtWidgetSet.DeleteObject(GDIObject: HGDIOBJ): Boolean;
var
  aObject: TObject;
  APaintEngine: QPaintEngineH;
  APainter: QPainterH;
  {$ifdef VerboseQtWinAPI}
    ObjType: string;
  {$endif}
begin
  {$ifdef VerboseQtWinAPI}
    WriteLn('Trace:> [WinAPI DeleteObject] GDIObject: ', dbghex(GDIObject));
    ObjType := 'Unidentifyed';
  {$endif}

  Result := False;

  if GDIObject = 0 then
    Exit(True);

  if not IsValidGDIObject(GDIObject) then
    Exit;

  aObject := TObject(GDIObject);

  if (aObject is TQtResource) and TQtResource(aObject).FShared then
    Exit(True);

  {------------------------------------------------------------------------------
    Font
   ------------------------------------------------------------------------------}
  if aObject is TQtFont then
  begin
    {$ifdef VerboseQtWinAPI}
      ObjType := 'Font';
    {$endif}
  end
  {------------------------------------------------------------------------------
    Brush
   ------------------------------------------------------------------------------}
  else if aObject is TQtBrush then
  begin
    {$ifdef VerboseQtWinAPI}
      ObjType := 'Brush';
    {$endif}
  end
  {------------------------------------------------------------------------------
    Image
   ------------------------------------------------------------------------------}
  else if aObject is TQtImage then
  begin
    {$ifdef VerboseQtWinAPI}
      ObjType := 'Image';
    {$endif}

    // we must stop paintdevice before destroying

    APaintEngine := QImage_paintEngine(TQtImage(AObject).Handle);

    if (APaintEngine <> nil) and QPaintEngine_isActive(APaintEngine) then
    begin
      APainter := QPaintEngine_painter(APaintEngine);
      if APainter <> nil then
        QPainter_end(APainter);
    end;
  end
  {------------------------------------------------------------------------------
    Region
   ------------------------------------------------------------------------------}
  else if aObject is TQtRegion then
  begin
    {$ifdef VerboseQtWinAPI}
      ObjType := 'Region';
    {$endif}
  end

  {------------------------------------------------------------------------------
    Pen
   ------------------------------------------------------------------------------}
  else if aObject is TQtPen then
  begin
    {$ifdef VerboseQtWinAPI}
      ObjType := 'Pen';
    {$endif}
  end;

  if AObject is TQtResource then
    if TQtResource(AObject).Owner <> nil then
    begin
      // this is an owned (default) resource, let owner free it
      DebugLn('WARNING: TQtWidgetSet.DeleteObject() trying to free a default resource ',dbgsName(AObject),' owner=',dbgsName(TQtResource(AObject).Owner));
      AObject := nil;
    end;

  if AObject <> nil then
  begin
    //WriteLn('Delete object: ', PtrUInt(AObject));
    FreeThenNil(AObject);
  end;

  Result := True;

  {$ifdef VerboseQtWinAPI}
    WriteLn('Trace:< [WinAPI DeleteObject] Result=', dbgs(Result), ' ObjectType=', ObjType);
  {$endif}
end;

function TQtWidgetSet.DestroyCaret(Handle: HWND): Boolean;
begin
  Result := (Handle <> 0) and QtCaret.DestroyCaret;
end;

{------------------------------------------------------------------------------
  Method:  DestroyIcon
  Params:  Handle
  Returns: Result of destroying
 ------------------------------------------------------------------------------}

function TQtWidgetSet.DestroyIcon(Handle: HICON): Boolean;
begin
  Result := (Handle <> 0) and
            (
              (TObject(Handle) is TQtIcon) or
              (TObject(Handle) is TQtCursor)
            );
  if Result then
    TObject(Handle).Free;
end;

{------------------------------------------------------------------------------
  Method:  DPtoLP
  Params:  DC: HDC; var Points; Count: Integer
  Returns: Boolean
 ------------------------------------------------------------------------------}
function TQtWidgetSet.DPtoLP(DC: HDC; var Points; Count: Integer): BOOL;
var
  P: PPoint;
  QtPoint: TQtPoint;
  Matrix: QTransformH;
  MatrixInv: QTransformH;
  QtDC: TQtDeviceContext;
  Inverted: Boolean;
begin
  {$ifdef VerboseQtWinAPI}
    WriteLn('[WinAPI DPtoLP] ');
  {$endif}

  Result := False;

  if not IsValidDC(DC) then
    Exit;

  QtDC := TQtDeviceContext(DC);

  Matrix := QTransform_create;
  MatrixInv := QTransform_create;
  QPainter_combinedTransform(QtDC.Widget, Matrix);
  P := @Points;
  try
    while Count > 0 do
    begin
      Dec(Count);
      Inverted := QTransform_isInvertible(Matrix);
      QTransform_inverted(Matrix, MatrixInv, @Inverted);
      QtPoint.X := P^.X;
      QtPoint.Y := P^.Y;
      QTransform_map(MatrixInv, PQtPoint(@QtPoint), PQtPoint(@QtPoint));
      P^.X := QtPoint.X;
      P^.Y := QtPoint.Y;
      Inc(P);
    end;

    Result := True;
  finally
    QTransform_destroy(MatrixInv);
    QTransform_destroy(Matrix);
  end;
end;

{------------------------------------------------------------------------------
  Method:  DrawEdge
  Params: DC: HDC; var Rect: TRect; edge: Cardinal; grfFlags: Cardinal
  Returns: Boolean
 ------------------------------------------------------------------------------}
function TQtWidgetSet.DrawEdge(DC: HDC; var Rect: TRect; edge: Cardinal; grfFlags: Cardinal): Boolean;
var
  Brush: HBRUSH;
  ColorDark, ColorLight: TColorRef;
  ClientRect: TRect;
  QtDC: TQtDeviceContext;

  procedure InternalDrawEdge(Outer: Boolean; const R: TRect);
  var
    X1, Y1, X2, Y2: Integer;
    ColorLeftTop, ColorRightBottom: TColor;
    EdgeQtColor: TQColor;
    APen, OldPen: TQtPen;
  begin
    X1 := R.Left;
    Y1 := R.Top;
    X2 := R.Right;
    Y2 := R.Bottom;

    ColorLeftTop := clNone;
    ColorRightBottom := clNone;

    if Outer then
    begin
      if Edge and BDR_RAISEDOUTER <> 0 then
      begin
        ColorLeftTop := ColorLight;
        ColorRightBottom := ColorDark;
      end
      else if Edge and BDR_SUNKENOUTER <> 0 then
      begin
        ColorLeftTop := ColorDark;
        ColorRightBottom := ColorLight;
      end;
    end
    else
    begin
      if Edge and BDR_RAISEDINNER <> 0 then
      begin
        ColorLeftTop := ColorLight;
        ColorRightBottom := ColorDark;
      end
      else if Edge and BDR_SUNKENINNER <> 0 then
      begin
        ColorLeftTop := ColorDark;
        ColorRightBottom := ColorLight;
      end;
    end;

    if grfFlags and BF_DIAGONAL = 0 then
    begin

      APen := TQtPen.Create(True);
      ColorRefToTQColor(TColorRef(ColorLeftTop), EdgeQtColor{%H-});
      APen.setColor(EdgeQtColor);
      OldPen := QtDC.setPen(APen);

      if grfFlags and BF_LEFT <> 0 then
        QtDC.DrawLine(X1, Y1, X1, Y2);
      if grfFlags and BF_TOP <> 0 then
        QtDC.DrawLine(X1, Y1, X2, Y1);

      QtDC.setPen(OldPen);
      APen.Free;
      APen := TQtPen.Create(True);

      ColorRefToTQColor(TColorRef(ColorRightBottom), EdgeQtColor);
      APen.setColor(EdgeQtColor);
      OldPen := QtDC.SetPen(APen);

      if grfFlags and BF_RIGHT <> 0 then
        QtDC.DrawLine(X2, Y1, X2, Y2);
      if grfFlags and BF_BOTTOM <> 0 then
        QtDC.DrawLine(X1, Y2, X2, Y2);
      QtDC.SetPen(OldPen);
      APen.Free;
    end
    else
    begin

      APen := TQtPen.Create(True);
      ColorRefToTQColor(TColorRef(ColorLeftTop), EdgeQtColor);
      APen.setColor(EdgeQtColor);
      OldPen := QtDC.setPen(APen);

      if (grfFlags and BF_DIAGONAL_ENDTOPLEFT = BF_DIAGONAL_ENDTOPLEFT) or
         (grfFlags and BF_DIAGONAL_ENDBOTTOMRIGHT = BF_DIAGONAL_ENDBOTTOMRIGHT) then
        QtDC.DrawLine(X1, Y1, X2, Y2)
      else
        QtDC.DrawLine(X1, Y2, X2, Y1);
      QtDC.setPen(OldPen);
      APen.Free;
    end;
  end;

begin
  {$ifdef VerboseQtWinAPI}
    WriteLn('[WinAPI DrawEdge] ');
  {$endif}

  Result := False;
  if not IsValidDC(DC) or IsRectEmpty(Rect) then exit;

  QtDC := TQtDeviceContext(DC);

  ClientRect := Rect;
  Dec(ClientRect.Right, 1);
  Dec(ClientRect.Bottom, 1);
  QtDC.save;
  try
    ColorDark := ColorToRGB(clBtnShadow);
    ColorLight := ColorToRGB(clBtnHighlight);
    if grfFlags and BF_FLAT <> 0 then
      ColorLight := clSilver;
    if grfFlags and BF_MONO <> 0 then
    begin
      ColorDark := TColorRef(clBlack);
      ColorLight := TColorRef(clWhite);
    end;
    try
      if Edge and (BDR_SUNKENOUTER or BDR_RAISEDOUTER) <> 0 then
        InternalDrawEdge(True, ClientRect);
      InflateRect(ClientRect, -1, -1);
      if grfFlags and BF_MONO = 0 then
      begin
        ColorLight := ColorToRGB(clBtnHighlight);
        ColorDark := ColorToRGB(clBtnShadow);
      end;
      if Edge and (BDR_SUNKENINNER or BDR_RAISEDINNER) <> 0 then
      begin
        InternalDrawEdge(False, ClientRect);
        InflateRect(ClientRect, -1, -1);
      end;
    finally
    end;

    inc(ClientRect.Right);
    inc(ClientRect.Bottom);

    if grfFlags and BF_MIDDLE <> 0 then
    begin
      Brush := CreateSolidBrush(TColorRef(clBtnFace));
      try
        FillRect(DC, ClientRect, Brush);
      finally
        DeleteObject(Brush);
      end;
    end;

    if grfFlags and BF_ADJUST <> 0 then
      Rect := ClientRect;

    Result := True;
  finally
    QtDC.Restore;
  end;

end;

{------------------------------------------------------------------------------
  Method: DrawFocusRect
  Params: DC: HDC; const Rect: TRect
  Returns: Boolean
 ------------------------------------------------------------------------------}
function TQtWidgetSet.DrawFocusRect(DC: HDC; const Rect: TRect): boolean;
var
  StyleOption: QStyleOptionFocusRectH;
  QtDC: TQtDeviceContext;
begin
  {$ifdef VerboseQtWinAPI}
    WriteLn('[TQtWidgetSet.DrawFocusRect] Handle: ', dbghex(DC));
  {$endif}
  Result := False;

  if not IsValidDC(DC) then exit;

  QtDC := TQtDeviceContext(DC);
  StyleOption := QStyleOptionFocusRect_create;
  QtDC.save;
  try
    QStyleOption_setRect(StyleOption, @Rect);
    if not QtDC.getClipping then
      QtDC.setClipRect(Rect);
    QStyle_drawPrimitive(QApplication_style, QStylePE_FrameFocusRect, StyleOption, QtDC.Widget, QtDC.Parent);
    Result := True;
  finally
    QStyleOptionFocusRect_destroy(StyleOption);
    QtDC.restore;
  end;
end;

function TQtWidgetSet.DrawFrameControl(DC: HDC; const Rect: TRect; uType,
  uState: Cardinal): Boolean;
var
  QtDC: TQtDeviceContext;
  Painter: QPainterH;
  Widget: QWidgetH;

  function uStatetoQStyleState: QStyleState;
  begin
    Result := QStyleState_None;
    if (uState and DFCS_INACTIVE = 0) then
      Result := Result or QStyleState_Enabled;

    if (uState and DFCS_PUSHED <> 0) then
      Result := Result or QStyleState_MouseOver or QStyleState_Sunken
    else
      Result := Result or QStyleState_Raised;

    if (uState and DFCS_CHECKED <> 0) then
      Result := Result or QStyleState_On
    else
      Result := Result or QStyleState_Off;

    if ((uState and DFCS_HOT <> 0) or (uState and DFCS_PUSHED <> 0)) then
      Result := Result or QStyleState_MouseOver or QStyleState_Active;

    if (uType <> DFC_BUTTON) and
      ((uState and DFCS_FLAT <> 0) and not (uState and DFCS_PUSHED <> 0)) then
      Result := Result and not QStyleState_Raised;

    // DFCS_TRANSPARENT = 2048;
    //DFCS_ADJUSTRECT = 8192;
    //DFCS_FLAT = 16384;
    //DFCS_MONO = 32768;
  end;

  procedure DrawButton;
  var
    Opt: QStyleOptionButtonH;
    Element: QStyleControlElement;
    State: QStyleState;
    Features: QStyleOptionButtonButtonFeatures;
  begin
    State := uStatetoQStyleState;
    if uState and DFCS_FLAT <> 0 then
      Features := QStyleOptionButtonFlat
    else
      Features := QStyleOptionButtonNone;
    if (uState and $1F) in [DFCS_BUTTONCHECK, DFCS_BUTTON3STATE] then
      Element := QStyleCE_CheckBox
    else
    if (DFCS_BUTTONRADIO and uState) <> 0 then
      Element := QStyleCE_RadioButton
    else
    if (DFCS_BUTTONPUSH and uState) <> 0 then
      Element := QStyleCE_PushButton
    else
    if (DFCS_BUTTONRADIOIMAGE and uState) <> 0 then
      Element := QStyleCE_RadioButton
      //TODO: what to implement here ?
    else
    if (DFCS_BUTTONRADIOMASK and uState) <> 0 then
      Element := QStyleCE_RadioButton
      //TODO: what to implement here ?
    ;

    Opt := QStyleOptionButton_create();
    QStyleOptionButton_setFeatures(Opt, Features);
    QStyleOption_setRect(Opt, @Rect);
    QStyleOption_setState(Opt, State);
    QStyle_drawControl(QApplication_style(), Element, Opt, Painter, Widget);
    QStyleOptionButton_destroy(Opt);
  end;

  procedure DrawScrollBarArrows;
  var
    Opt: QStyleOptionH;
    Element: QStylePrimitiveElement;
    State: QStyleState;
  begin
    //TODO: DFCS_SCROLLCOMBOBOX and DFCS_SCROLLSIZEGRIP
    State := uStatetoQStyleState;
    Element := QStylePE_CustomBase;
    if (uState and $1F) in [DFCS_SCROLLUP] then
      Element := QStylePE_IndicatorArrowUp
    else
    if (uState and $1F) in [DFCS_SCROLLDOWN] then
      Element := QStylePE_IndicatorArrowDown
    else
    if (uState and $1F) in [DFCS_SCROLLLEFT] then
      Element := QStylePE_IndicatorArrowLeft
    else
    if (uState and $1F) in [DFCS_SCROLLRIGHT] then
      Element := QStylePE_IndicatorArrowRight;

    if Element = QStylePE_CustomBase then
      exit;
    Opt := QStyleOption_create(QStyleOptionVersion, QStyleOptionSO_Default);
    QStyleOption_setRect(Opt, @Rect);
    QStyleOption_setState(Opt, State);
    QStyle_drawPrimitive(QApplication_style(), Element, Opt, Painter, Widget);
    QStyleOption_destroy(Opt);
  end;

begin
  Result := False;
  if not IsValidDC(DC) then
    exit;
  QtDC := TQtDeviceContext(DC);
  Painter := QtDC.Widget;
  Widget := QtDC.Parent;
  case uType of
    DFC_BUTTON: DrawButton;
    DFC_CAPTION: ; // title bar captions
    DFC_MENU: ; // menu
    DFC_SCROLL: DrawScrollBarArrows;
  end;
end;

{------------------------------------------------------------------------------
  Method:  DrawText
  Params:  DC, Str, Count, Rect, Flags
  Returns: If the string was drawn, or CalcRect run

  if DT_CALCRECT is one of the Flags passed to this function, then:

  * DrawText should not draw the text, but determine the size that would be required to write it.
  * If there are multiple lines of text, this function will keep Rect.Width fixed and
    expand Rect.Height to fit the text.
  * If there is one line of text, Rect is reduced or expanded to fit it.
  * The result will the height of the text.
 ------------------------------------------------------------------------------}
function TQtWidgetSet.DrawText(DC: HDC; Str: PChar; Count: Integer;
  var ARect: TRect; Flags: Cardinal): Integer;
var
  WStr: WideString;
  R: TRect;
  QtDC: TQtDeviceContext;
  F: Integer;
  Pt: TPoint;
  ClipRect: TRect;
  B: Boolean;
  S: String;
  i: Integer;

  procedure CalculateOffsetWithAngle(const AFontAngle: Integer;
    var TextLeft,TextTop: Integer);
  var
    OffsX, OffsY: integer;
    Angle: Integer;
    Size: TSize;
  begin
    OffsX := R.Right - R.Left;
    OffsY := R.Bottom - R.Top;
    Size.cX := OffsX;
    Size.cy := OffsY;
    Angle := AFontAngle div 10;
    if Angle < 0 then
      Angle := 360 + Angle;

    if Angle <= 90 then
    begin
      OffsX := 0;
      OffsY := Trunc(Size.cx * sin(Angle * Pi / 180));
    end else
    if Angle <= 180 then
    begin
      OffsX := Trunc(Size.cx * -cos(Angle * Pi / 180));
      OffsY := Trunc(Size.cx * sin(Angle * Pi / 180) +
         Size.cy * cos((180 - Angle) * Pi / 180));
    end else
    if Angle <= 270 then
    begin
      OffsX := Trunc(Size.cx * -cos(Angle * Pi / 180) +
        Size.cy * sin((Angle - 180) * Pi / 180));
      OffsY := Trunc(Size.cy * sin((270 - Angle) * Pi / 180));
    end else
    if Angle <= 360 then
    begin
      OffsX := Trunc(Size.cy * sin((360 - Angle) * Pi / 180));
      OffsY := 0;
    end;
    TextTop := OffsY;
    TextLeft := OffsX;
  end;

begin
  {$ifdef VerboseQtWinAPI}
    WriteLn('[WinAPI DrawText] DC: ', dbghex(DC), ' Str: ', string(Str),
     ' CalcRect: ', dbgs((Flags and DT_CALCRECT) = DT_CALCRECT),' ARect ',dbgs(ARect));
  {$endif}

  Result := 0;

  if not IsValidDC(DC) then
    Exit;

  QtDC :=TQtDeviceContext(DC);

  if Count >= 0 then
    WStr := {%H-}Copy(Str, 1, Count)
  else
    WStr := Str;

  ClipRect := Rect(0, 0, 0, 0);
  B := QtDC.getClipping;
  if (Flags and DT_NOCLIP = DT_NOCLIP) and
    (Flags and DT_WORDBREAK = DT_WORDBREAK) and
    {if DT_CALCRECT is inlcuded we should avoid wrong calculation}
    (Flags and DT_CALCRECT = 0) then
  begin
    if B then
      ClipRect := QtDC.getClipRegion.getBoundingRect;
    //this is just to get same behaviour as gtk2 and win32
    //IMO, we should change ARect.Left and/or ARect.Top if smaller than
    //clip rect (map to clipRect). Then multiline text is drawn ok.
    //look at issue http://bugs.freepascal.org/view.php?id=17678 . zeljko.
    if not B or (B and ((ARect.Left < ClipRect.Left) or (ARect.Top < ClipRect.Top))) then
    begin
      {$note remove ifdef if I'm wrong about DT_WORDBREAK OBSERVATION}
      {$IFDEF QT_DRAWTEXT_MAP_TO_CLIPRECT}
      if ARect.Left < ClipRect.Left then
        ARect.Left := ClipRect.Left;
      if ARect.Top < ClipRect.Top then
        ARect.Top := ClipRect.Top;
      {$ELSE}
      Flags := Flags and not DT_WORDBREAK;
      {$ENDIF}
    end;
  end;

  F := DTFlagsToQtFlags(Flags);

  QtDC.Metrics.BoundingRect(@R, @ARect, F, @WStr);

  //TODO: result should be different when DT_VCENTER or DT_BOTTOM is set
  Result := R.Bottom - R.Top;

  if (Flags and DT_CALCRECT) = DT_CALCRECT then
  begin
    if (Flags and DT_WORDBREAK = DT_WORDBREAK) and
    ((R.Bottom - R.Top) > (ARect.Bottom - ARect.Top)) then
      // MSDN says do not touch rect width when we have DT_WORDBREAK flag
      // and new text is multiline (if R height > ARect height).See #17329.
    else
      ARect.Right := ARect.Left + R.Right - R.Left;
    ARect.Bottom := ARect.Top + R.Bottom - R.Top;
    {$ifdef VerboseQtWinAPI}
      WriteLn('[WinAPI DrawText] Rect=', dbgs(ARect));
    {$endif}
    Exit;
  end;

  // if our Font.Orientation <> 0 we must recalculate X,Y offset
  // also it works only with DT_TOP DT_LEFT. Qt can handle multiline
  // text in this case too.
  Pt := Point(0, 0);
  if (QtDC.Font.Angle <> 0) then
  begin
    if IsRectEmpty(ClipRect) and QtDC.getClipping then
      ClipRect := QtDC.getClipRegion.getBoundingRect;
    if EqualRect(ClipRect, ARect) then
    begin
      Pt := Point(ARect.Left, ARect.Top);
      CalculateOffsetWithAngle(QtDC.font.Angle, Pt.X, Pt.Y);
    end;
  end;

  // we cannot fit into rectangle, so use DT_SINGLELINE.See #17329.
  // http://msdn.microsoft.com/en-us/library/dd162498%28v=VS.85%29.aspx
  if B and
    (Flags and DT_NOCLIP = DT_NOCLIP) and
    (Flags and DT_WORDBREAK = DT_WORDBREAK) and
    (Flags and DT_SINGLELINE = DT_SINGLELINE) and
    ((R.Bottom - R.Top) >= (ARect.Bottom - ARect.Top)) then
  begin
    Flags := Flags and not DT_WORDBREAK;
    F := DTFlagsToQtFlags(Flags);
  end;

  {Workaround for qt-4.7 QPainter bug.It's fixed in qt-4.7.4. DO NOT REMOVE}
  { Bug triggers when we try to paint multiline text which contains 1
   space. eg "Save project\nCtrl+S". In this case QPainter draws
   Save
   project (in two lines, so Ctrl+S is invisible. See issue #18631.
   But does not trigger with qt-4.6.XX and maybe with 4.7.0.
   Opened nokia issue: http://bugreports.qt.nokia.com/browse/QTBUG-17020
   UPDATE: it's fixed in qt-4.7.4 git and qt-4.8}
  if (QtVersionMajor = 4) and (QtVersionMinor = 7) and (QtVersionMicro < 4) and
   (Flags and DT_WORDBREAK = DT_WORDBREAK) and
   ((Flags and DT_VCENTER = DT_VCENTER) or (Flags and DT_CENTER = DT_CENTER))
    and not (Flags and DT_NOCLIP = DT_NOCLIP) and
    not (Flags and DT_MODIFYSTRING = DT_MODIFYSTRING) and
    not (Flags and DT_END_ELLIPSIS = DT_END_ELLIPSIS) then
  begin
    S := StrPas(Str);
    if length(S) > 0 then
    begin
      i := Pos(' ', S);
      if (AnsiPos(LineEnding, S) > i) and
        (S[length(S)] <> LineEnding) then
      begin
        Flags := Flags and not DT_WORDBREAK;
        F := DTFlagsToQtFlags(Flags);
      end;
    end;
  end;

  if (Flags and DT_MODIFYSTRING = DT_MODIFYSTRING) and
  (Flags and DT_END_ELLIPSIS = DT_END_ELLIPSIS) and
  (Flags and DT_WORDBREAK = 0) then
  begin
    // windows are removing trailing spaces in this case
    // and we are doing same thing too.
    WStr := TrimLeft(WStr);
    with ARect do
      WStr := QtDC.Metrics.elidedText(WStr, QtElideRight, Right - Left, 0);
  end;

  QtDC.DrawText(ARect.Left + Pt.X, ARect.Top + Pt.Y, ARect.Right-ARect.Left, ARect.Bottom-ARect.Top, F, @WStr);
end;

{------------------------------------------------------------------------------
  Method:   Ellipse
  Params:   X1, Y1, X2, Y2
  Returns:  Nothing

  Use Ellipse to draw a filled circle or ellipse.
 ------------------------------------------------------------------------------}
function TQtWidgetSet.Ellipse(DC: HDC; x1, y1, x2, y2: Integer): Boolean;
var
  R: TRect;
begin
  if not IsValidDC(DC) then Exit(False);
  R := NormalizeRect(Rect(X1, Y1, X2, Y2));
  if IsRectEmpty(R) then Exit(True);
  TQtDeviceContext(DC).drawEllipse(R.Left, R.Top, R.Right - R.Left, R.Bottom - R.Top);
  Result := True;
end;

function TQtWidgetSet.EnableScrollBar(Wnd: HWND; wSBflags, wArrows: Cardinal): Boolean;
begin
  {maybe we can put creating of scrollbar here instead of SetScrollInfo() }
  Result := False;
  {$ifdef VerboseQtWinAPI_MISSING_IMPLEMENTATION}
    WriteLn('***** [WinAPI TQtWidgetSet.EnableScrollbar] missing implementation ');
  {$endif}
end;

function TQtWidgetSet.EnableWindow(hWnd: HWND; bEnable: Boolean): Boolean;
begin
  {$ifdef VerboseQtWinAPI}
    WriteLn('[WinAPI EnableWindow] ');
  {$endif}
  Result := False;
  if HWND <> 0 then
  begin
    Result := not TQtWidget(hwnd).getEnabled;
    TQtWidget(hWnd).setEnabled(bEnable);
  end;
end;

{------------------------------------------------------------------------------
  Function: EndPaint
  Params:
  Returns:

 ------------------------------------------------------------------------------}
function TQtWidgetSet.EndPaint(Handle: hwnd; var PS: TPaintStruct): Integer;
begin
  {$ifdef VerboseQtWinAPI}
    WriteLn('[WinAPI EndPaint] Handle: ', dbghex(Handle),
     ' PS.HDC: ', dbghex(PS.HDC));
  {$endif}

  Result := 1;

  if IsValidDC(PS.HDC) and (TObject(PS.HDC) is TQtDeviceContext) then
  begin
    {$ifdef VerboseQtWinAPI}
      WriteLn('Freeing resources');
    {$endif}
    TQtDeviceContext(PS.HDC).Free;
  end;
end;

{------------------------------------------------------------------------------
  Procedure: EnterCriticalSection
  Params:  var CritSection: TCriticalSection
  Returns: Nothing
 ------------------------------------------------------------------------------}
procedure TQtWidgetSet.EnterCriticalSection(var CritSection: TCriticalSection);
var
  ACritSec: System.PRTLCriticalSection;
begin
  ACritSec:=System.PRTLCriticalSection(CritSection);
  System.EnterCriticalsection(ACritSec^);
end;

function TQtWidgetSet.EnumDisplayMonitors(hdc: HDC; lprcClip: PRect;
  lpfnEnum: MonitorEnumProc; dwData: LPARAM): LongBool;
var
  i: integer;
  Desktop: QDesktopWidgetH;
begin
  Desktop := QApplication_desktop();
  Result := True;
  for i := 0 to QDesktopWidget_numScreens(Desktop) - 1 do
  begin
    Result := Result and lpfnEnum(i + 1, 0, nil, dwData);
    if not Result then break;
  end;
end;


function CharsetToQtCharSet(const ALCLCharset: Byte): QFontDatabaseWritingSystem;
begin
  Result := QFontDatabaseAny;
  case ALCLCharset of
    SYMBOL_CHARSET: Result := QFontDatabaseSymbol;
    FCS_ISO_8859_1 .. FCS_ISO_8859_4,
    FCS_ISO_8859_9,FCS_ISO_8859_10,
    FCS_ISO_8859_15,
    EASTEUROPE_CHARSET: Result := QFontDatabaseLatin;
    FCS_ISO_8859_5,
    RUSSIAN_CHARSET: Result := QFontDatabaseCyrillic;
    FCS_ISO_8859_6,
    ARABIC_CHARSET: Result := QFontDatabaseArabic;
    FCS_ISO_8859_7,
    GREEK_CHARSET: Result := QFontDatabaseGreek;
    FCS_ISO_8859_8,
    HEBREW_CHARSET: Result := QFontDatabaseHebrew;
    SHIFTJIS_CHARSET: Result := QFontDatabaseJapanese;
    HANGEUL_CHARSET: Result := QFontDatabaseKorean;
    GB2312_CHARSET: Result := QFontDatabaseSimplifiedChinese;
    CHINESEBIG5_CHARSET: Result := QFontDatabaseTraditionalChinese;
    THAI_CHARSET: Result := QFontDatabaseThai;
  end;
end;

function QtCharsetToCharset(AWritingSystem: QFontDatabaseWritingSystem;
  AList: TFPList): Byte;
begin
  Result := DEFAULT_CHARSET;
  case AWritingSystem of
    QFontDatabaseAny:
    begin
      Result := FCS_ISO_10646_1;
      AList.Add(TObject(PtrUInt(Result)));
    end;
    QFontDatabaseSymbol:
    begin
      Result := SYMBOL_CHARSET;
      AList.Add(TObject(PtrUInt(Result)));
    end;
    QFontDatabaseThai:
    begin
      Result := THAI_CHARSET;
      AList.Add(TObject(PtrUInt(Result)));
    end;
    QFontDatabaseTraditionalChinese:
    begin
      Result := CHINESEBIG5_CHARSET;
      AList.Add(TObject(PtrUInt(Result)));
    end;
    QFontDatabaseSimplifiedChinese:
    begin
      Result := GB2312_CHARSET;
      AList.Add(TObject(PtrUInt(Result)));
    end;
    QFontDatabaseKorean:
    begin
      Result := HANGEUL_CHARSET;
      AList.Add(TObject(PtrUInt(Result)));
    end;
    QFontDatabaseJapanese:
    begin
      Result := SHIFTJIS_CHARSET;
      AList.Add(TObject(PtrUInt(Result)));
    end;
    QFontDatabaseHebrew:
    begin
      Result := HEBREW_CHARSET;
      AList.Add(TObject(PtrUInt(Result)));
      AList.Add(TObject(PtrUInt(FCS_ISO_8859_8)));
    end;
    QFontDatabaseGreek:
    begin
      Result := GREEK_CHARSET;
      AList.Add(TObject(PtrUInt(Result)));
      AList.Add(TObject(PtrUInt(FCS_ISO_8859_7)));
    end;
    QFontDatabaseArabic:
    begin
      Result := ARABIC_CHARSET;
      AList.Add(TObject(PtrUInt(Result)));
    end;
    QFontDatabaseCyrillic:
    begin
      Result := RUSSIAN_CHARSET;
      AList.Add(TObject(PtrUInt(Result)));
      AList.Add(TObject(PtrUInt(FCS_ISO_8859_5)));
    end;
    QFontDatabaseLatin:
    begin
      Result := FCS_ISO_10646_1;
      AList.Add(TObject(PtrUInt(Result)));
      AList.Add(TObject(PtrUInt(ANSI_CHARSET)));
      AList.Add(TObject(PtrUInt(FCS_ISO_8859_1)));
      AList.Add(TObject(PtrUInt(FCS_ISO_8859_2)));
      AList.Add(TObject(PtrUInt(FCS_ISO_8859_3)));
      AList.Add(TObject(PtrUInt(FCS_ISO_8859_4)));
      AList.Add(TObject(PtrUInt(FCS_ISO_8859_9)));
      AList.Add(TObject(PtrUInt(FCS_ISO_8859_10)));
      AList.Add(TObject(PtrUInt(FCS_ISO_8859_15)));
      AList.Add(TObject(PtrUInt(EASTEUROPE_CHARSET)));
    end;
  end;
end;

{------------------------------------------------------------------------------
  Function: EnumFontFamiliesEx
  Params:
    hdc
        [in] Handle to the device context.
    lpLogfont
        [in] Pointer to a LOGFONT structure that contains information about the
        fonts to enumerate. The function examines the following members.

        Member 	Description
        lfCharset 	If set to DEFAULT_CHARSET, the function enumerates all fonts
                    in all character sets. If set to a valid character set value,
                    the function enumerates only fonts in the specified character
                    set.
        lfFaceName 	If set to an empty string, the function enumerates one font
                    in each available typeface name. If set to a valid typeface
                    name, the function enumerates all fonts with the
                    specified name.

        lfPitchAndFamily 	Must be set to zero for all language versions of
                          the operating system.

    lpEnumFontFamExProc
        [in] Pointer to the application definedcallback function. For more
             information, see the EnumFontFamExProc function.
    lParam
        [in] Specifies an applicationdefined value. The function passes this value
             to the callback function along with font information.
    dwFlags
        This parameter is not used and must be zero.

  Returns:

  The return value is the last value returned by the callback function.
  This value depends on which font families are available for the
  specified device.

 ------------------------------------------------------------------------------}
function TQtWidgetSet.EnumFontFamiliesEx(DC: HDC; lpLogFont: PLogFont; Callback: FontEnumExProc; Lparam: LParam; Flags: dword): longint;
var
  EnumLogFont: TEnumLogFontEx;
  Metric: TNewTextMetricEx;
  FontList: TStringList;
  FontType: Integer;
  FontDB: QFontDatabaseH;
  i: Integer;
  y: Integer;
  AStyle: String;
  StylesCount: Integer;
  StylesList: QStringListH;
  ScriptList: QStringListH;
  CharsetList: TFPList;

  function QtGetFontFamiliesDefault(var List:TStringList;
    const AWritingSystem: QFontDatabaseWritingSystem = QFontDatabaseAny):integer;
  var
    StrLst: QStringlistH;
    WStr: WideString;
    j: integer;
  begin
    Result := -1;
    StrLst := QStringList_create;
    try
      QFontDatabase_families(FontDB, StrLst, AWritingSystem);
      Result := QStringList_size(StrLst);
      for j := 0 to Result - 1 do
      begin
        QStringList_at(StrLst, @WStr, j);
        List.Add(WStr{%H-});
      end;
    finally
      QStringList_destroy(StrLst);
    end;
  end;

  function QtGetFontFamilies(var List: TStringList;
    const APitch: Byte;
    const AFamilyName: String;
    const AWritingSystem: QFontDatabaseWritingSystem = QFontDatabaseAny): Integer;
  var
    StrLst: QStringlistH;
    NewList: QStringListH;
    WStr: WideString;
    j: integer;
  begin
    Result := -1;
    StrLst := QStringList_create();
    NewList := QStringList_create();

    try
      QFontDatabase_families(FontDB, StrLst, AWritingSystem);
      for j := 0 to QStringList_size(StrLst) - 1 do
      begin
        QStringList_at(StrLst, @WStr, j);
        if APitch <> DEFAULT_PITCH then
        begin
          case APitch of
            FIXED_PITCH, MONO_FONT:
            begin
              if QFontDatabase_isFixedPitch(FontDB, @WStr) then
                QStringList_append(NewList, @WStr);
            end;
            VARIABLE_PITCH:
            begin
              if QFontDatabase_isScalable(FontDB, @WStr) then
                QStringList_append(NewList, @WStr);
            end;
          end;
        end else
          QStringList_append(NewList, @WStr);
      end;

      if AFamilyName <> '' then
      begin
        for j := QStringList_size(NewList) - 1 downto 0 do
        begin
          QStringList_at(NewList, @WStr, j);
          if UTF16ToUTF8(WStr) <> AFamilyName then
            QStringList_removeAt(NewList, j);
        end;
      end;
      for j := 0 to QStringList_size(NewList) - 1 do
      begin
        QStringList_at(NewList, @WStr, j);
        List.Add(WStr{%H-});
      end;
      Result := List.Count;
    finally
      QStringList_destroy(StrLst);
      QStringList_destroy(NewList);
    end;
  end;

  function GetStyleAt(AIndex: Integer): String;
  var
    WStr: WideString;
  begin
    Result := '';
    if (AIndex >= 0) and (AIndex < QStringList_size(StylesList)) then
    begin
      QStringList_at(StylesList, @WStr, AIndex);
      Result := {%H-}WStr;
    end;
  end;

  function GetWritingSystems(AFontName: String; AList: QStringListH;
    ACharsetList: TFPList): Boolean;
  var
    WStr: WideString;
    Arr: TPtrIntArray;
    j: Integer;
  begin
    Result := False;
    QStringList_clear(AList);
    if Assigned(CharSetList) then
      CharSetList.Clear;
    WStr := {%H-}AFontName;
    QFontDatabase_writingSystems(FontDB, @Arr, @WStr);
    Result := length(Arr) > 0;
    for j := 0 to High(Arr) do
    begin
      if Assigned(ACharsetList) then
        QtCharsetToCharset(QFontDatabaseWritingSystem(Arr[j]), ACharsetList);
      QFontDatabase_writingSystemName(@WStr, QFontDatabaseWritingSystem(Arr[j]));
      QStringList_append(AList, @WStr);
    end;
  end;

  function FillLogFontA(AFontName: String; var ALogFontA: TLogFontA;
    var AMetric: TNewTextMetricEx; var AFontType: Integer;
    out AStyle: String): Integer;
  var
    Font: QFontH;
    WStr: WideString;
  begin
    WStr := {%H-}AFontName;
    Font := QFont_create(@WStr);
    ALogFontA.lfItalic := Byte(QFont_italic(Font));
    ALogFontA.lfWeight := QFont_weight(Font);
    ALogFontA.lfHeight := QFont_pointSize(Font);
    ALogFontA.lfUnderline := Byte(QFont_underline(Font));
    ALogFontA.lfStrikeOut := Byte(QFont_strikeOut(Font));

    if QFont_styleStrategy(Font) = QFontPreferBitmap then
      AFontType := AFontType  or RASTER_FONTTYPE;
    if QFont_styleStrategy(Font) = QFontPreferDevice then
      AFontType := AFontType  or DEVICE_FONTTYPE;

    if not (QFont_styleStrategy(Font) = QFontPreferDefault) then
      AFontType := AFontType and not TRUETYPE_FONTTYPE;

    QStringList_clear(StylesList);
    QFontDatabase_styles(FontDB, StylesList, @WStr);
    AStyle := '';
    Result := QStringList_size(StylesList);

    if Result > 0 then
      AStyle := GetStyleAt(0);
    // fill script and charset list
    GetWritingSystems(AFontName, ScriptList, CharsetList);

    QFont_destroy(Font);
  end;

begin
  {$ifdef VerboseQtWinAPI}
  WriteLn('[WinAPI EnumFontFamiliesEx] Charset=',lpLogFont^.lfCharSet,
  ' face ',lpLogFont^.lfFaceName,' pitchAndFamily=',lpLogFont^.lfPitchAndFamily);
  {$endif}
  Result := 0;
  Metric.ntmentm.ntmAvgWidth := 0; // just to shutup compiler
  FontDB := QFontDatabase_create();
  try
    if (lpLogFont^.lfCharSet = DEFAULT_CHARSET) and
       (lpLogFont^.lfFaceName= '') and
       (lpLogFont^.lfPitchAndFamily = 0) then
    begin
      FontType := 0;
      FontList := TStringList.create;
      try
        if QtGetFontFamiliesDefault(FontList) > 0 then
        begin
          for i := 0 to FontList.Count - 1 do
          begin
            EnumLogFont.elfLogFont.lfFaceName := FontList[i];
            Result := Callback(EnumLogFont, Metric, FontType, LParam);
          end;
        end;
      finally
        FontList.free;
      end;
    end else
    begin
      Result := 0;
      FontType := TRUETYPE_FONTTYPE;
      FontList := TStringList.create;
      StylesList := QStringList_create();
      ScriptList := QStringList_create();
      CharsetList := TFPList.Create;
      try
        if QtGetFontFamilies(FontList, lpLogFont^.lfPitchAndFamily,
          lpLogFont^.lfFaceName, CharsetToQtCharSet(lpLogFont^.lfCharSet)) > 0 then
        begin
          StylesList := QStringList_create();
          for i := 0 to FontList.Count - 1 do
          begin
            EnumLogFont.elfLogFont.lfFaceName := FontList[i];
            EnumLogFont.elfLogFont.lfPitchAndFamily := lpLogFont^.lfPitchAndFamily;
            EnumLogFont.elfFullName := FontList[i];

            StylesCount := FillLogFontA(FontList[i], EnumLogFont.elfLogFont, Metric, FontType,
              AStyle);
            EnumLogFont.elfStyle := AStyle;
            if CharSetList.Count > 0 then
              EnumLogFont.elfLogFont.lfCharSet := {%H-}PtrUInt(CharsetList.Items[0]);
            Result := Callback(EnumLogFont, Metric, FontType, LParam);
            for y := 1 to StylesCount - 1 do
            begin
              AStyle := GetStyleAt(y);
              EnumLogFont.elfStyle := AStyle;
              Result := Callback(EnumLogFont, Metric, FontType, LParam);
            end;
            for y := 1 to CharsetList.Count - 1 do
            begin
              EnumLogFont.elfLogFont.lfCharSet := {%H-}PtrUInt(CharsetList.Items[y]);
              Result := Callback(EnumLogFont, Metric, FontType, LParam);
            end;
          end;
        end;
      finally
        FontList.free;
        QStringList_destroy(StylesList);
        CharSetList.Free;
      end;
    end;
  finally
    QFontDatabase_destroy(FontDB);
  end;
end;


{------------------------------------------------------------------------------
  Function: ExcludeClipRect
  Params:  none
  Returns: Nothing

 ------------------------------------------------------------------------------}
function TQtWidgetSet.ExcludeClipRect(dc: hdc; Left, Top, Right, Bottom : Integer) : Integer;
var
  Region: QRegionH;
  ClipRegion: QRegionH;
  ExRegion: QRegionH;
  QtDC: TQtDeviceContext;
  R: TRect;
begin
  {$ifdef VerboseQtWinAPI}
    WriteLn('[WinAPI ExcludeClipRect]');
  {$endif}

  Result := ERROR;
  if not IsValidDC(DC) then Exit;

  QtDC := TQtDeviceContext(DC);

  {ExcludeClipRect on X11 paint engine is pretty slow with complex regions
   eg. setting clipRegion with hundreds of rects (usually created by
   calling ExcludeClipRect for many children on widget) dramatically kills
   performance of our application.
   To get rid of it we are using trick from webkit. If numRects is over
   25 then create an new rect region with boundsRect of NewRegion.
   see issue http://bugs.freepascal.org/view.php?id=19698.
   If you want accurate ExcludeClipRect use graphicssystem Raster or
   see comment in TQtWidgetSet.ExtSelectClipRgn}
  ExRegion := QRegion_create(Left, Top, Right - Left, Bottom - Top, QRegionRectangle);
  Region := QRegion_create;
  ClipRegion := QRegion_create;
  try
    QPainter_clipRegion(QtDC.Widget, ClipRegion);
    QRegion_subtracted(ClipRegion, Region, ExRegion);

    // only for X11 paintEngine.
    if (QPaintEngine_type(QtDC.PaintEngine) = QPaintEngineX11) and
      not QRegion_isEmpty(Region) and
      (QRegion_numRects(Region) > 25) then
    begin
      QRegion_boundingRect(Region, @R);
      QRegion_setRects(Region, @R, 1);
    end;

    QtDC.setClipRegion(Region);
    QtDC.setClipping(True);
    if QRegion_isEmpty(Region) then
      Result := NULLREGION
    else
    if QRegion_numRects(Region) = 1 then
      Result := SIMPLEREGION
    else
      Result := COMPLEXREGION;

  finally
    QRegion_destroy(ClipRegion);
    QRegion_destroy(Region);
    QRegion_destroy(ExRegion);
  end;
end;

function TQtWidgetSet.ExtCreatePen(dwPenStyle, dwWidth: DWord;
  const lplb: TLogBrush; dwStyleCount: DWord; lpStyle: PDWord): HPEN;
var
  QtPen: TQtPen;
  color: TQColor;
begin
  Result := 0;
  QtPen := TQtPen.Create(True);
  QtPen.IsExtPen := True;

  case dwPenStyle and PS_STYLE_MASK of
    PS_SOLID: QtPen.setStyle(QtSolidLine);
    PS_DASH: QtPen.setStyle(QtDashLine);
    PS_DOT: QtPen.setStyle(QtDotLine);
    PS_DASHDOT: QtPen.setStyle(QtDashDotLine);
    PS_DASHDOTDOT: QtPen.setStyle(QtDashDotDotLine);
    PS_USERSTYLE: QtPen.setStyle(QtCustomDashLine);
    PS_NULL: QtPen.setStyle(QtNoPen);
  end;

  QtPen.setCosmetic((dwPenStyle and PS_TYPE_MASK) = PS_COSMETIC);
  if (dwPenStyle and PS_TYPE_MASK) = PS_GEOMETRIC then
  begin
    QtPen.setWidth(dwWidth);
    case dwPenStyle and PS_JOIN_MASK of
      PS_JOIN_ROUND: QtPen.setJoinStyle(QtRoundJoin);
      PS_JOIN_BEVEL: QtPen.setJoinStyle(QtBevelJoin);
      PS_JOIN_MITER: QtPen.setJoinStyle(QtMiterJoin);
    end;

    case dwPenStyle and PS_ENDCAP_MASK of
      PS_ENDCAP_ROUND: QtPen.setCapStyle(QtRoundCap);
      PS_ENDCAP_SQUARE: QtPen.setCapStyle(QtSquareCap);
      PS_ENDCAP_FLAT: QtPen.setCapStyle(QtFlatCap);
    end;
  end;

  if (dwPenStyle and PS_STYLE_MASK) = PS_USERSTYLE then
    QtPen.setDashPattern(lpStyle, dwStyleCount);

  QPen_Color(QtPen.FHandle, @Color);
  ColorRefToTQColor(ColorToRGB(TColor(lplb.lbColor)), Color);
  QPen_setColor(QtPen.FHandle, @Color);

  Result := HPEN(QtPen);
end;

function TQtWidgetSet.ExtSelectClipRGN(dc: hdc; rgn : hrgn; Mode : Longint) : Integer;
var
  Clip: HRGN = 0;
  Tmp : hRGN;
  DCOrigin: TPoint;
  QtWidget: TQtWidget = nil;
  QtDC: TQtDeviceContext;
  QtRgn: TQtRegion;
  R: TRect;
begin
  {$ifdef VerboseQtWinAPI}
    WriteLn('[WinAPI TQtWidgetSet.ExtSelectClipRGN]');
  {$endif}
  if not IsValidDC(DC) then
  begin
    Result := ERROR;
    exit;
  end else
    Result := SIMPLEREGION;

  QtDC := TQtDeviceContext(DC);

  if Assigned(QtDC.Parent) then
    QtWidget := QtObjectFromWidgetH(QtDC.Parent);

  if Assigned(QtWidget) or
    (not Assigned(QtWidget) and Assigned(QtDC.vImage)) then
  begin
    // there is no clipping region in the DC
    case Mode of
      RGN_COPY: Result := SelectClipRGN(DC, RGN);
      RGN_OR,
      RGN_XOR,
      RGN_AND:
        begin
          // as MSDN says only RGN_COPY allows NULL RGN param.
          if not IsValidGDIObject(RGN) then
          begin
            Result := ERROR;
            exit;
          end;
          // get existing clip
          QtRgn := QtDC.getClipRegion;

          if (QtRgn = nil) or (QtRgn.GetRegionType = NULLREGION) then
          begin
            Result := SelectClipRGN(DC, RGN);
            exit;
          end;

          // get transformation
          GetWindowOrgEx(DC, @DCOrigin);
          R := QtRgn.getBoundingRect;
          Clip := CreateRectRGN(0, 0, R.Right - R.Left, R.Bottom - R.Top);
          TQtRegion(Clip).translate(DCOrigin.X, DCOrigin.Y);

          // create target clip
          Tmp := CreateEmptyRegion;
          // combine
          Result := CombineRGN(Tmp, Clip, RGN, Mode);
          // commit
          SelectClipRGN(DC, Tmp);
          // clean up
          DeleteObject(Clip);
          DeleteObject(Tmp);
        end;
      RGN_DIFF:
      begin
        // when substracting we must have active clipregion
        // with all of its rects.
        QtRgn := QtDC.getClipRegion;
        if (QtRgn = nil) or (QtRgn.GetRegionType = NULLREGION) then
        begin
          Result := SelectClipRGN(DC, RGN);
          exit;
        end;

        Tmp := CreateEmptyRegion;
        Result := CombineRGN(Tmp, HRGN(QtRgn), RGN, MODE);

        // X11 paintEngine comment only !
        // we'll NOT reset num of rects here (performance problem) like we do
        // in ExcludeClipRect, because this function must be correct,
        // if someone want accurate ExcludeClipRect with X11 then
        // use code from intfbasewinapi.inc TWidgetSet.ExcludeClipRect()
        // which calls this function and then combineRgn.
        SelectClipRGN(DC, Tmp);
        DeleteObject(Tmp);
      end;
    end;
  end
  else
    Result := inherited ExtSelectClipRGN(DC, RGN, Mode);
end;

{------------------------------------------------------------------------------
  Function: ExtTextOut
  Params:  none
  Returns: Nothing


 ------------------------------------------------------------------------------}
function TQtWidgetSet.ExtTextOut(DC: HDC; X, Y: Integer; Options: Longint;
  Rect: PRect; Str: PChar; Count: Longint; Dx: PInteger): Boolean;
var
  WStr: WideString;
  QtDC: TQtDeviceContext absolute DC;
  R, R1: TRect;
  Pt: TPoint;
  ALayout: QtLayoutDirection;
  B: Boolean;

  procedure DoDrawCharByChar(const AClipped: Boolean);
  var
    CurX, CharLen: Integer;
    CurCount: LongInt;
    CurDx: PInteger;
    CurStr: PChar;
    W: WideString;
  begin
    CurDx := Dx;
    CurStr := Str;
    CurCount := Count;
    CurX := X;
    while CurCount > 0 do
    begin
      CharLen := UTF8CodepointSize(CurStr);
      W := {%H-}Copy(CurStr, 1, CharLen);
      if AClipped then
        QtDC.drawText(CurX, Y, Rect^.Right - Rect^.Left, Rect^.Bottom - Rect^.Top,
                      QtTextDontClip, @W)
      else
        QtDC.drawText(CurX, Y, @W);
      inc(CurX, CurDx^);
      inc(CurDx);
      inc(CurStr, CharLen);
      dec(CurCount, CharLen);
    end;
  end;

begin
  {$ifdef VerboseQtWinAPI}
    WriteLn('[WinAPI ExtTextOut]');
  {$endif}

  Result := False;

  if not IsValidDC(DC) then Exit;

  B := False;
  if ((Options and (ETO_OPAQUE + ETO_CLIPPED)) <> 0) and (Rect = nil) then
  begin
    if Count >= 0 then
      WStr := {%H-}Copy(Str, 1, Count)
    else
      WStr := Str;

    R := QtDC.getClipRegion.getBoundingRect;
    QtDC.font.Metrics.boundingRect(@R1, @R, 0, @WStr);
    B := True;
    Rect := @R1;
  end;

  if ((Options and ETO_OPAQUE) <> 0) and (Rect <> nil) then
  begin
    // Qt-4.8 bug
    if (QtVersionMajor = 4) and (QtVersionMinor = 8) and (QtVersionMicro < 3) and
      QPaintEngine_testDirty(QtDC.PaintEngine, QPaintEngineDirtyBrushOrigin) then
    begin
      // couldn't find way to fix it.
    end;
    if B then
      QtDC.fillRect(X, Y, Rect^.Right - Rect^.Left, Rect^.Bottom - Rect^.Top)
    else
      QtDC.fillRect(Rect^.Left, Rect^.Top, Rect^.Right - Rect^.Left, Rect^.Bottom - Rect^.Top);
  end else
  if ((Options and ETO_OPAQUE) = 0) and (Rect <> nil) and (QtDC.getBKMode = OPAQUE) then
  begin
    // Qt-4.8 bug
    {$warning workaround for Qt-4.8.XX bug (test with 4.8.3 release) !}
    if (QtVersionMajor = 4) and (QtVersionMinor = 8) and (QtVersionMicro < 3) and
      QPaintEngine_testDirty(QtDC.PaintEngine, QPaintEngineDirtyBrushOrigin) then
    begin
      R := Rect^;
      QtDC.font.Metrics.boundingRect(@R1, @R, QtTextSingleLine, @WStr);
      if Options and ETO_CLIPPED = 0 then
        Pt := Point(Rect^.Left - X, Rect^.Top - Y)
      else
        Pt := Point(0, 0);
      QtDC.fillRect(Rect^.Left - Pt.X, Rect^.Top - Pt.Y + 1, Rect^.Right - Rect^.Left + Pt.X,
        R1.Bottom - R1.Top + Pt.Y, QtDC.BackgroundBrush.FHandle);
    end;
  end;

  if Str <> nil then
  begin
    ALayout := QPainter_layoutDirection(QtDC.Widget);
    if Options and ETO_RTLREADING <> 0 then
      QPainter_setLayoutDirection(QtDC.Widget, QtRightToLeft);
    if Count >= 0 then
      WStr := {%H-}Copy(Str, 1, Count)
    else
      WStr := Str;

    if (Options and ETO_CLIPPED <> 0) then
    begin
      QtDC.save;
      try
        QtDC.setClipRect(Rect^);
        if Dx <> nil then
          DoDrawCharByChar(True)
        else
          QtDC.drawText(X, Y, Rect^.Right - Rect^.Left, Rect^.Bottom - Rect^.Top,
            QtTextDontClip, @WStr);
      finally
        QtDC.Restore;
      end;
    end else
    begin
      if Dx <> nil then
        DoDrawCharByChar(False)
      else
        QtDC.drawText(X, Y, @WStr);
    end;
    if Options and ETO_RTLREADING <> 0 then
      QPainter_setLayoutDirection(QtDC.Widget, ALayout);
  end;

  Result := True;
end;

{------------------------------------------------------------------------------
  Function: FillRect
  Params:  none
  Returns: Nothing


 ------------------------------------------------------------------------------}
function TQtWidgetSet.FillRect(DC: HDC; const Rect: TRect; Brush: HBRUSH): Boolean;
begin
  Result := False;

  {$ifdef VerboseQtWinAPI}
    DebugLn('[WinAPI FillRect Rect=', dbgs(Rect),' Brush=', dbghex(Brush));
  {$endif}

  if not IsValidDC(DC) then
    exit;
  if not IsValidGdiObject(Brush) then
    exit;

  TQtDeviceContext(DC).fillRect(@Rect, TQtBrush(Brush).FHandle);
  Result := True;
end;

{------------------------------------------------------------------------------
  Function: FillRgn
  Params:  DC: HDC; RegionHnd: HRGN; hbr: HBRUSH
  Returns: Boolean

 ------------------------------------------------------------------------------}
function TQtWidgetSet.FillRgn(DC: HDC; RegionHnd: HRGN; hbr: HBRUSH): Bool;
var
  OldRgn: TQtRegion;
  R: TRect;
  hasClipping: Boolean;
  QtDC: TQtDeviceContext;
  APath: QPainterPathH;
  APolyFH: QPolygonFH;
begin
  {$ifdef VerboseQtWinAPI}
    DebugLn('[WinAPI FillRgn Rgn=', dbgs(RegionHnd),' Brush=', dbghex(hbr));
  {$endif}

  Result := False;

  if not IsValidDC(DC) then exit;

  QtDC := TQtDeviceContext(DC);

  HasClipping := QtDC.getClipping;
  QtDC.save;

  if HasClipping then
    OldRgn := TQtRegion.Create(True)
  else
    OldRgn := nil;
  try
    if HasClipping then
      QPainter_clipRegion(QtDC.Widget, OldRgn.FHandle);

    if SelectClipRgn(DC, RegionHnd) <> ERROR then
    begin
      if TQtRegion(RegionHnd).IsPolyRegion then
      begin
        APath := QPainterPath_create();
        APolyFH := QPolygonF_create(TQtRegion(RegionHnd).Polygon);
        try
          QPainterPath_addPolygon(APath, APolyFH);
          QPainter_fillPath(QtDC.Widget, APath, TQtBrush(hbr).FHandle);
        finally
          QPainterPath_destroy(APath);
          QPolygonF_destroy(APolyFH);
        end;
      end else
      begin
        R := TQtRegion(RegionHnd).getBoundingRect;
        QtDC.fillRect(@R, TQtBrush(hbr).FHandle);
      end;
      if HasClipping then
        SelectClipRgn(DC, HRGN(OldRgn));
      Result := True;
    end;
  finally
    if HasClipping then
      OldRgn.Free;
    QtDC.restore;
  end;
end;

{------------------------------------------------------------------------------
  Function: Frame3D
  Params:  none
  Returns: Nothing

  Draws a 3d border in Qt native style.
 ------------------------------------------------------------------------------}
function TQtWidgetSet.Frame3d(DC: HDC; var ARect: TRect;
  const FrameWidth: integer; const Style: TBevelCut): Boolean;
var
  QtDC: TQtDeviceContext;
  AWidget: HWND;
  ATransparent: Boolean;
begin
  {$ifdef VerboseQtWinAPI}
    DebugLn('[TQtWidgetSet.Frame3d Rect=', dbgs(ARect));
  {$endif}

  Result := False;

  if not IsValidDC(DC) then exit;

  QtDC := TQtDeviceContext(DC);

  // issue #26491, draw opaque TCustomPanel if csOpaque is setted up in control style
  // otherwise use brush and painter backgroundmode settings.
  ATransparent := True;
  if (QtDC.Parent <> nil) and QObject_isWidgetType(QtDC.Parent) then
  begin
    AWidget := HwndFromWidgetH(QtDC.Parent);
    if (AWidget <> 0) and Assigned(TQtWidget(AWidget).LCLObject) then
    begin
      ATransparent := not (csOpaque in TQtWidget(AWidget).LCLObject.ControlStyle);
      // issue #26607
      if ATransparent and (TQtWidget(AWidget).LCLObject is TCustomPanel) and
        (TQtWidget(AWidget).LCLObject.Color <> clDefault) and
        not TCustomPanel(TQtWidget(AWidget).LCLObject).ParentColor then
          ATransparent := False;
    end;
  end;

  case Style of
    bvNone: ;
    bvLowered: QtDC.qDrawWinPanel(ARect.Left, ARect.Top,
      ARect.Right - ARect.Left, ARect.Bottom - ARect.Top, ATransparent, nil, True, FrameWidth);
    bvRaised: QtDC.qDrawWinPanel(ARect.Left, ARect.Top,
      ARect.Right - ARect.Left, ARect.Bottom - ARect.Top, ATransparent, nil, False, FrameWidth);
    bvSpace: QtDC.qDrawPlainRect(ARect.Left, ARect.Top,
      ARect.Right - ARect.Left, ARect.Bottom - ARect.Top, nil, FrameWidth);
  end;

  InflateRect(ARect, -FrameWidth, -FrameWidth);
  Result := True;
end;

{------------------------------------------------------------------------------
  Function: FrameRect
  Params:  none
  Returns: Nothing
 ------------------------------------------------------------------------------}
function TQtWidgetSet.FrameRect(DC: HDC; const ARect: TRect;
  hBr: HBRUSH): Integer;
var
  AColor: PQColor;
begin
  Result := 0;

  if not IsValidDC(DC) then Exit;

  if IsValidGDIObject(hBr) then
    AColor := TQtBrush(HBR).getColor
  else
    AColor := nil;

  TQtDeviceContext(DC).qDrawPLainRect(ARect.Left, ARect.Top,
    ARect.Right - ARect.Left, ARect.Bottom - ARect.Top, AColor);
  Result := 1;
end;

function TQtWidgetSet.GetActiveWindow: HWND;
var
  Widget: QWidgetH;
  W: TQtWidget;
  SubW: TQtWidget;
  Area: QMdiAreaH;
begin
  Result := 0;
  Widget := QApplication_activeWindow;
  {return modal if activeWindow is nil issue #33409}
  if Widget = nil then
    Widget := QApplication_activeModalWidget;
  if Widget = nil then
    Widget := QApplication_activePopupWidget;
  if Assigned(Widget) then
  begin
    W := QtObjectFromWidgetH(Widget);
    if Assigned(W) and IsValidHandle(HWND(W)) then
    begin
      if (TQtWidget(W) is TQtMainWindow) and (TQtMainWindow(W).MDIAreaHandle <> nil) then
      begin
        Area := QMdiAreaH(TQtMainWindow(W).MDIAreaHandle.Widget);
        SubW := QtObjectFromWidgetH(QMdiArea_activeSubWindow(Area));
        if SubW <> nil then
          Result := HWND(SubW)
        else
          Result := HWND(W);
      end else
        Result := HWND(W);
    end;
  end;
end;


{------------------------------------------------------------------------------
  Method:  TQtWidgetSet.GetBitmapBits
  Params:  none
  Returns:

 ------------------------------------------------------------------------------}
function TQtWidgetSet.GetBitmapBits(Bitmap: HBITMAP; Count: Longint;  Bits: Pointer): Longint;
var
  Image: QImageH;
begin
  {$ifdef VerboseQtWinAPI}
    WriteLn('[WinAPI GetBitmapBits]',' Bitmap=', dbghex(Bitmap),' Count=',Count);
  {$endif}

  Result := 0;

  if (Bitmap = 0) or (Count <= 0) then
    Exit;

  Image := QImage_create(TQtImage(Bitmap).Handle);
  try
    Result := (QImage_width(Image) * QImage_height(Image) * QImage_depth(Image) + 7) div 8;
    if Count < Result then
      Result := Count;
    if Result > 0 then
      Move(QImage_bits(Image)^, Bits^, Result);
  finally
    QImage_destroy(Image);
  end;
end;

function TQtWidgetSet.GetBkColor(DC: HDC): TColorRef;
var
  QtDC: TQtDeviceContext;
begin
  Result := CLR_INVALID;
  if not IsValidDC(DC) then Exit;
  QtDC := TQtDeviceContext(DC);
  Result := QtDC.GetBkColor;
end;

function TQtWidgetSet.GetCapture: HWND;
var
  w: QWidgetH;
  Widget: TQtWidget;
  {$IFDEF MSWINDOWS}
  AWin: HWND;
  {$ENDIF}
begin
  {$IFDEF MSWINDOWS}
  AWin := Windows.GetCapture;
  if AWin <> 0 then
    w := QWidget_find(AWin)
  else
    w := nil;

  if (w = nil) and (QApplication_mouseButtons() > 0) then
    w := QApplication_focusWidget()
  else
    if (w <> QWidget_mouseGrabber) and (QWidget_mouseGrabber <> nil) then
      w := QWidget_mouseGrabber;

  {$ELSE}
  w := QWidget_mouseGrabber();
  {$ENDIF}

  if w <> nil then
  begin
    // Capture widget can be child of complex control. In any case we should return TQtWidget as result.
    // So we will look for parent while not found apropriate LCL handle.
    Widget := GetFirstQtObjectFromWidgetH(w);
    {$IFDEF MSWINDOWS}
    if Widget <> nil then
    begin
      if Widget is TQtCustomControl then
        Widget := TQtCustomControl(Widget).Viewport;
    end;
    {$ENDIF}
    Result := HWND(Widget);
  end
  else
    Result := 0;
  {$ifdef VerboseQtWinAPI}
  WriteLn('[WinAPI GetCapture] Capture = ', Result);
  {$endif}
end;

function TQtWidgetSet.GetCaretPos(var lpPoint: TPoint): Boolean;
begin
  Result := QtCaret.GetCaretPos(lpPoint);
end;

function TQtWidgetSet.GetCaretRespondToFocus(handle: HWND; var ShowHideOnFocus: boolean): Boolean;
begin
  ShowHideOnFocus := QtCaret.GetQtCaretRespondToFocus;
  Result := True;
end;

{------------------------------------------------------------------------------
  Function: GetClientBounds
  Params: handle:
          Result:
  Returns: true on success

  Returns the client bounds of a control. The client bounds is the rectangle of
  the inner area of a control, where the child controls are visible. The
  coordinates are relative to the control's left and top.
 ------------------------------------------------------------------------------}
function TQtWidgetSet.GetClientBounds(handle : HWND; var ARect : TRect) : Boolean;
begin
  {$ifdef VerboseQtWinAPI}
    WriteLn('[WinAPI GetClientBounds]');
  {$endif}
  if Handle = 0 then
    Exit(False);
  ARect := TQtWidget(handle).getClientBounds;
  Result := True;
end;

{------------------------------------------------------------------------------
  Function: GetClientRect
  Params: handle:
          Result:
  Returns: true on success

  Returns the client bounds of a control. The client bounds is the rectangle of
  the inner area of a control, where the child controls are visible. The
  coordinates are relative to the control's left and top.
 ------------------------------------------------------------------------------}
function TQtWidgetSet.GetClientRect(handle : HWND; var ARect : TRect) : Boolean;
begin
  {$ifdef VerboseQtWinAPI}
    WriteLn('[WinAPI GetClientRect]');
  {$endif}
  if Handle = 0 then
    Exit(False);
  GetClientBounds(Handle, ARect);
  OffsetRect(ARect, -ARect.Left, -ARect.Top);

  Result := True;
end;

{------------------------------------------------------------------------------
  Function: GetClipBox
  Params: dc, lprect
  Returns: Integer

  Returns the smallest rectangle which includes the entire current
  Clipping Region, or if no Clipping Region is set, the current
  dimensions of the Drawable.

  The result can be one of the following constants
      Error
      NullRegion
      SimpleRegion
      ComplexRegion
 ------------------------------------------------------------------------------}
function TQtWidgetSet.GetClipBox(DC: hDC; lpRect: PRect): Longint;
var
  ARegion: QRegionH;
  Pt: TPoint;
begin
  Result := NULLREGION;
  if lpRect <> nil then
    lpRect^ := Rect(0,0,0,0);

  if not IsValidDC(DC) then
    Result := ERROR;

  if Result <> ERROR then
  with TQtDeviceContext(DC) do
  begin
    {$ifdef VerboseQtWinAPI}
      Writeln('TQtWidgetSet.GetClipBox FastClip=',
       ((vClipRect <> nil) and not vClipRectDirty) );
    {$endif}

    // the most correct way to get a clipbox if through
    // region.boundingrect, but it's slower.

    // TODO: remove "and false" below when vClipRectDirty is implemented
    //       it should be "true" when user set a custom clip rect
    //       and "false" on beginpaint
    if (vClipRect<>nil) and not vClipRectDirty and false then
      lpRect^ := vClipRect^
    else
    if getClipping then
    begin
      ARegion := QRegion_Create;
      try
        QPainter_clipRegion(Widget, ARegion);
        GetWindowOrgEx(DC, @Pt);
        if (Pt.X <> 0) or (Pt.Y <> 0) then
          SetWindowOrgEx(DC, Pt.X, Pt.Y, @Pt);
        QRegion_boundingRect(ARegion, lpRect);
      finally
        QRegion_destroy(ARegion);
      end;
      Result := SIMPLEREGION;
    end
    else
      if vImage <> nil then
      begin
        lpRect^ := Rect(0, 0, vImage.width, vImage.height);
        Result := SIMPLEREGION;
      end;
    {$ifdef VerboseQtWinAPI}
    WriteLn('TQtWidgetSet.GetClipBox Rect=', dbgs(lprect^));
    {$endif}
  end;
end;

{------------------------------------------------------------------------------
  Function: GetClipRGN
  Params: dc, rgn
  Returns: Integer

  Returns a copy of the current Clipping Region.

  The result can be one of the following constants
     0 = no clipping set
     1 = ok
    -1 = error
 ------------------------------------------------------------------------------}
function TQtWidgetSet.GetClipRGN(DC : hDC; RGN : hRGN): Longint;
begin
  {$ifdef VerboseQtWinAPI}
    Writeln('Trace: [WinAPI GetClipRgn]',
     ' DC: ', dbghex(DC),
     ' RGN: ', dbghex(Rgn));
    if RGN<>0 then
      WriteLn(' QRegionH=', PtrInt(TQtRegion(Rgn).Widget))
    else
      WriteLn(' Rgn=0');
  {$endif}
  // it assumes that clipregion object has been created some other place
  Result := -1;
  if not IsValidDC(DC) then
    exit;
  if Rgn = 0 then
    exit;
  if not TQtDeviceContext(DC).getClipping then
    Result := 0
  else
  begin
    // if our TQtRegion contains widget then
    // first destroy it because QPainter creates
    // new reference.
    if TQtRegion(Rgn).FHandle <> nil then
    begin
      QRegion_destroy(TQtRegion(Rgn).FHandle);
      TQtRegion(Rgn).FHandle := QRegion_create;
    end;
    QPainter_clipRegion(TQtDeviceContext(DC).Widget, TQtRegion(Rgn).FHandle);
    Result := 1;
  end;
end;

function TQtWidgetSet.GetCmdLineParamDescForInterface: string;
  function b(const s: string): string;
  begin
    Result:=BreakString(s,75,22)+LineEnding+LineEnding;
  end;
begin
  Result:=
     b(rsqtOptionNoGrab)
    +b(rsqtOptionDoGrab)
    +b(rsqtOptionSync)
    +b(rsqtOptionStyle)
    +b(rsqtOptionStyleSheet)
    +b(rsqtOptionGraphicsStyle)
    +b(rsqtOptionSession)
    +b(rsqtOptionWidgetCount)
    +b(rsqtOptionReverse)
    {$IFDEF HASX11}
    +b(rsqtOptionX11Display)
    +b(rsqtOptionX11Geometry)
    +b(rsqtOptionX11Font)
    +b(rsqtOptionX11BgColor)
    +b(rsqtOptionX11FgColor)
    +b(rsqtOptionX11BtnColor)
    +b(rsqtOptionX11Name)
    +b(rsqtOptionX11Title)
    +b(rsqtOptionX11Visual)
    +b(rsqtOptionX11NCols)
    +b(rsqtOptionX11CMap)
    +b(rsqtOptionX11IM)
    +b(rsqtOptionX11InputStyle)
    +b(rsqtOptionDisableAccurateFrame)
    {$ENDIF}
    ;
end;

{------------------------------------------------------------------------------
  Method: GetCurrentObject
  Params:
    DC - A handle to the DC
    uObjectType - The object type to be queried
  Returns: If the function succeeds, the return value is a handle to the specified object.
    If the function fails, the return value is NULL.
 ------------------------------------------------------------------------------}

function TQtWidgetSet.GetCurrentObject(DC: HDC; uObjectType: UINT): HGDIOBJ;
var
  QtDC: TQtDeviceContext absolute DC;
begin
  Result := 0;
  if not QtWidgetSet.IsValidDC(DC) then
    Exit;
  case uObjectType of
    OBJ_BITMAP: Result := HGDIOBJ(QtDC.vImage);
    OBJ_BRUSH: Result := HGDIOBJ(QtDC.vBrush);
    OBJ_FONT: Result := HGDIOBJ(QtDC.vFont);
    OBJ_PEN: Result := HGDIOBJ(QtDC.vPen);
  end;
end;

{------------------------------------------------------------------------------
  Function: GetCursorPos
  Params:  lpPoint: The cursorposition
  Returns: True if succesful

 ------------------------------------------------------------------------------}
function TQtWidgetSet.GetCursorPos(var lpPoint: TPoint ): Boolean;
var
  vPoint: TQtPoint;
begin
  QCursor_pos(@vPoint);

  lpPoint.x := vPoint.x;
  lpPoint.y := vPoint.y;

  Result := True;
end;

{------------------------------------------------------------------------------
  Function: GetDC
  Params:  hWnd is any widget.
  Returns: Nothing

  This function is Called:
  - Once on app startup with hWnd = 0
  - Twice for every TLabel on the TCustomLabel.CalcSize function
 ------------------------------------------------------------------------------}
function TQtWidgetSet.GetDC(hWnd: HWND): HDC;
var
  Widget: TQtWidget;
begin
  {$ifdef VerboseQtWinAPI}
    WriteLn('Trace:> [WinAPI GetDC] hWnd: ', dbghex(hWnd));
  {$endif}

  if QtWidgetSet.IsValidHandle(hWnd) then
  begin
    Widget := TQtWidget(hWnd);
    Result := Widget.Context;
    if Result = 0 then
    begin
      {issue #28106}
      Result := HDC(TQtDeviceContext.Create(Widget.Widget, False));
      {can be destroyed via ReleaseDC()}
      TQtDeviceContext(Result).UserDC := True;
    end;
  end else
    Result := HDC(QtScreenContext);

  {$ifdef VerboseQtWinAPI}
    WriteLn('Trace:< [WinAPI GetDC] Result: ', dbghex(Result));
  {$endif}
end;

function TQtWidgetSet.GetDCOriginRelativeToWindow(PaintDC: HDC;
  WindowHandle: HWND; var OriginDiff: TPoint): boolean;
var
  QtDC: TQtDeviceContext absolute PaintDC;
  Matrix: QTransformH;
  P: TPoint;
begin
  {$ifdef VerboseQtWinAPI}
    WriteLn('[WinAPI GetDCOriginRelativeToWindow] PaintDC ' + dbghex(PaintDC));
  {$endif}
  Result := IsValidDC(PaintDC);
  if not Result then
    exit;
  Matrix := QPainter_transform(QtDC.Widget);
  OriginDiff := Point(0, 0);
  P := Point(0, 0);
  if WindowHandle <> 0 then
    P := TQtWidget(WindowHandle).getClientOffset;
  if Matrix <> nil then
  begin
    OriginDiff.X := Round(QTransform_Dx(Matrix)) - P.X;
    OriginDiff.Y := Round(QTransform_Dy(Matrix)) - P.Y;
  end;
end;

{------------------------------------------------------------------------------
  Function: GetDeviceCaps
  Params: DC: HDC; Index: Integer
  Returns: Integer

 ------------------------------------------------------------------------------}
function TQtWidgetSet.GetDeviceCaps(DC: HDC; Index: Integer): Integer;
var
  QtDC: TQtDeviceContext;
  PaintDevice: QPaintDeviceH;
  PaintEngine: QPaintEngineH;
begin
  {$ifdef VerboseQtWinAPI}
    WriteLn('[WinAPI GetDeviceCaps] DC ' + dbghex(DC));
  {$endif}

  Result := 0;
  if DC = 0 then
    DC := HDC(QtScreenContext);

  if not IsValidDC(DC) then exit;

  QtDC := TQtDeviceContext(DC);

  PaintEngine := QtDC.PaintEngine;
  if PaintEngine = nil then
    exit;
  PaintDevice := QPaintEngine_paintDevice(PaintEngine);

  case Index of
    HORZSIZE:
      Result := QPaintDevice_widthMM(PaintDevice);
    VERTSIZE:
      Result := QPaintDevice_heightMM(PaintDevice);
    HORZRES:
      Result := QPaintDevice_width(PaintDevice);
    BITSPIXEL:
      Result := QPaintDevice_depth(PaintDevice);
    PLANES:
      Result := 1;
    SIZEPALETTE:
      Result := QPaintDevice_numColors(PaintDevice);
    LOGPIXELSX:
      Result := QPaintDevice_logicalDpiX(PaintDevice);
    LOGPIXELSY:
      Result := QPaintDevice_logicalDpiY(PaintDevice);
    VERTRES:
      Result := QPaintDevice_height(PaintDevice);
    NUMRESERVED:
      Result := 0;
    else
      Result := 0;
  end;
end;

function TQtWidgetSet.GetDIBits(DC: HDC; Bitmap: HBitmap; StartScan, NumScans: UINT; Bits: Pointer; var BitInfo: BitmapInfo; Usage: UINT): Integer;
begin
  Result := 0;
  {$ifdef VerboseQtWinAPI_MISSING_IMPLEMENTATION}
    WriteLn('***** [WinAPI TQtWidgetSet.GetDIBits] missing implementation ');
  {$endif}
end;

{------------------------------------------------------------------------------
  Function: GetDoubleClickTime
  Params: none
  Returns:

 ------------------------------------------------------------------------------}
function TQtWidgetSet.GetDoubleClickTime: UINT;
begin
  Result := QApplication_doubleClickInterval;
end;

{------------------------------------------------------------------------------
  Function: GetFocus
  Params:  None
  Returns: Nothing

 ------------------------------------------------------------------------------}
function TQtWidgetSet.GetFocus: HWND;
var
  W: QWidgetH;
 {$ifdef VerboseFocus}
 Obj: TQtWidget;
 {$endif}
begin
  Result := 0;
  W := QApplication_FocusWidget();
  if W <> nil then
  begin
    Result := HwndFromWidgetH(W);
    if IsValidHandle(Result) then
    begin
      if TQtWidget(Result).getOwner <> nil then
        Result := HWND(TQtWidget(Result).getOwner);
    end;
    {$ifdef VerboseFocus}
    Obj := TQtWidget(Result);
    WriteLn('TQtWidgetSet.GetFocus: WidgetH=',dbghex(ptruint(W)), ' QtWidget=', dbgsname(Obj));
    if Obj<>nil then
      WriteLn(' LclObject=', dbgsname(Obj.LCLObject))
    else
      WriteLn;
    {$endif}
  end;
end;

function TQtWidgetSet.GetKeyState(nVirtKey: Integer): Smallint;
const
  StateDown    = SmallInt($FF80);
  {StateToggled = SmallInt($0001);}
begin
  Result := 0;

  {$IFDEF MSWINDOWS}
  if (nVirtKey = VK_CONTROL) or (nVirtKey = VK_MENU) or
    (nVirtKey = VK_LCONTROL) or (nVirtKey = VK_LMENU) then
  begin
    if (GetWinKeyState(VK_RMENU) < 0) and
      (GetWinKeyState(VK_LCONTROL) < 0) then
      exit;
  end;
  {$ENDIF}

  case nVirtKey of
    VK_LSHIFT:   nVirtKey := VK_SHIFT;
    VK_LCONTROL: nVirtKey := VK_CONTROL;
    VK_LMENU:    nVirtKey := VK_MENU;
  end;

  // where to track toggle state?
  case nVirtKey of
    VK_LBUTTON:
      if (QApplication_mouseButtons and QtLeftButton) > 0 then
        Result := Result or StateDown;
    VK_RBUTTON:
      if (QApplication_mouseButtons and QtRightButton) > 0 then
        Result := Result or StateDown;
    VK_MBUTTON:
      if (QApplication_mouseButtons and QtMidButton) > 0 then
        Result := Result or StateDown;
    VK_XBUTTON1:
      if (QApplication_mouseButtons and QtXButton1) > 0 then
        Result := Result or StateDown;
    VK_XBUTTON2:
      if (QApplication_mouseButtons and QtXButton2) > 0 then
        Result := Result or StateDown;
    VK_MENU:
      if (QApplication_keyboardModifiers and QtAltModifier) > 0 then
        Result := Result or StateDown;
    VK_SHIFT:
      if (QApplication_keyboardModifiers and QtShiftModifier) > 0 then
        Result := Result or StateDown;
    VK_CONTROL:
      if (QApplication_keyboardModifiers and QtControlModifier) > 0 then
        Result := Result or StateDown;
    VK_LWIN, VK_RWIN:
      if (QApplication_keyboardModifiers and QtMetaModifier) > 0 then
        Result := Result or StateDown;
    VK_LCL_CAPSLOCK, VK_NUMLOCK:
    begin
      {$IFDEF MSWINDOWS}
      Result := GetWinKeyState(nVirtKey);
      {$ELSE}
      {$IFDEF HASX11}
      if GetKeyLockState(nVirtKey) then
        Result := StateDown;
      {$ENDIF}
      {$ENDIF}
    end;
   {$ifdef VerboseQtWinAPI}
    else
      DebugLn('TQtWidgetSet.GetKeyState TODO ', DbgSVKCode(Word(nVirtkey)));
   {$endif}
  end;
end;

function TQtWidgetSet.GetMapMode(DC: HDC): Integer;
begin
  if IsValidDC(DC) then
    Result := TQtDeviceContext(DC).vMapMode
  else
    Result := 0;
end;

function TQtWidgetSet.GetMonitorInfo(Monitor: HMONITOR; lpmi: PMonitorInfo): Boolean;
var
  Desktop: QDesktopWidgetH;
begin
  Result := (lpmi <> nil) and (lpmi^.cbSize >= SizeOf(TMonitorInfo)) or (Monitor = 0);
  if not Result then Exit;
  Desktop := QApplication_desktop();
  Dec(Monitor);
  // Note: Monitor is PtrUInt and is always >= 0.
  Result := Monitor < PtrUInt(QDesktopWidget_numScreens(Desktop));
  if not Result then Exit;
  QDesktopWidget_screenGeometry(Desktop, @lpmi^.rcMonitor, Monitor);
  QDesktopWidget_availableGeometry(Desktop, @lpmi^.rcWork, Monitor);
  if PtrUInt(QDesktopWidget_primaryScreen(Desktop)) = Monitor then
    lpmi^.dwFlags := MONITORINFOF_PRIMARY
  else
    lpmi^.dwFlags := 0;
end;

{------------------------------------------------------------------------------
  Method:  TQtWidgetSet.GetDeviceSize
  Params:  none
  Returns: True if successful

  Return the size of a device
 ------------------------------------------------------------------------------}
function TQtWidgetSet.GetDeviceSize(DC: HDC; var P: TPoint): Boolean;
begin
  {$ifdef VerboseQtWinAPI}
    WriteLn('[WinAPI GetDeviceSize]');
  {$endif}

  Result := False;

  P.X := 0;
  P.Y := 0;

  if not IsValidDC(DC) then Exit;

  if (TObject(DC) is TQtDeviceContext) then
    P := TQtDeviceContext(DC).getDeviceSize;

  Result := True;
end;

{------------------------------------------------------------------------------
  Method:  TQtWidgetSet.GetObject
  Params:  none
  Returns: The size written to the buffer

  Necessary for TBitmap support
 ------------------------------------------------------------------------------}
function TQtWidgetSet.GetObject(GDIObj: HGDIOBJ; BufSize: Integer; Buf: Pointer): Integer;
const
  QtPenStyleToWinStyleMap: array[QtPenStyle] of UINT =
  (
 { QtNoPen          } PS_NULL,
 { QtSolidLine      } PS_SOLID,
 { QtDashLine       } PS_DASH,
 { QtDotLine        } PS_DOT,
 { QtDashDotLine    } PS_DASHDOT,
 { QtDashDotDotLine } PS_DASHDOTDOT,
 { QtCustomDashLine } PS_USERSTYLE
  );
var
  aObject: TObject;
  AFont: TQtFont absolute aObject;
  APen: TQtPen absolute aObject;
  ABrush: TQtBrush absolute aObject;
  BitmapSection : TDIBSECTION;
  ALogFont: PLogFont absolute Buf;
  ALogPen: PLogPen absolute Buf;
  AExtLogPen: PExtLogPen absolute Buf;
  ALogBrush: PLogBrush absolute Buf;
  Dashes: TQRealArray;
  i: integer;
  PaintDevice: QPaintDeviceH;
  {$ifdef VerboseQtWinAPI}
    ObjType: string;
  {$endif}
begin
  {$ifdef VerboseQtWinAPI}
    WriteLn('Trace:> [WinAPI GetObject] GDIObj: ' + dbghex(GDIObj));
    ObjType := '';
  {$endif}

  Result := 0;

  if not IsValidGDIObject(GDIObj) then
  begin
    {$ifdef VerboseQtWinAPI}
      WriteLn('Trace:< [WinAPI GetObject] Invalid GDI Object');
    {$endif}

    Exit;
  end;

  aObject := TObject(GDIObj);

  {------------------------------------------------------------------------------
    Font
   ------------------------------------------------------------------------------}
  if aObject is TQtFont then
  begin
    if Buf = nil then
      Result := SizeOf(TLogFont)
    else
    if BufSize >= SizeOf(TLogFont) then
    begin
      Result := SizeOf(TLogFont);

      FillChar(ALogFont^, SizeOf(ALogFont^), 0);
      if AFont.getPixelSize = -1 then
      begin
        PaintDevice := QWidget_to_QPaintDevice(QApplication_desktop);
        if PaintDevice <> nil then
          ALogFont^.lfHeight := MulDiv(AFont.getPointSize, QPaintDevice_logicalDpiX(PaintDevice), 72)
        else
          ALogFont^.lfHeight := AFont.getPointSize;
      end else
        ALogFont^.lfHeight := AFont.getPixelSize;
      ALogFont^.lfEscapement := AFont.Angle;
      case AFont.getWeight of
        10: ALogFont^.lfWeight := FW_THIN;
        15: ALogFont^.lfWeight := FW_EXTRALIGHT;
        25: ALogFont^.lfWeight := FW_LIGHT;
        50: ALogFont^.lfWeight := FW_NORMAL;
        55: ALogFont^.lfWeight := FW_MEDIUM;
        63: ALogFont^.lfWeight := FW_SEMIBOLD;
        75: ALogFont^.lfWeight := FW_BOLD;
        80: ALogFont^.lfWeight := FW_EXTRABOLD;
        87: ALogFont^.lfWeight := FW_HEAVY;
      end;

      ALogFont^.lfItalic := Ord(AFont.getItalic) * High(Byte);
      ALogFont^.lfUnderline := Ord(AFont.getUnderline) * High(Byte);
      ALogFont^.lfStrikeOut := Ord(AFont.getStrikeOut) * High(Byte);
      ALogFont^.lfCharSet := DEFAULT_CHARSET;
      case AFont.getStyleStategy of
        QFontPreferMatch: ALogFont^.lfQuality := DRAFT_QUALITY;
        QFontPreferQuality: ALogFont^.lfQuality := PROOF_QUALITY;
        QFontNoAntialias: ALogFont^.lfQuality := NONANTIALIASED_QUALITY;
        QFontPreferAntialias: ALogFont^.lfQuality := ANTIALIASED_QUALITY;
      else
        ALogFont^.lfQuality := DEFAULT_QUALITY;
      end;
      ALogFont^.lfFaceName := AFont.getFamily;
    end;
  end
  {------------------------------------------------------------------------------
    Pen
   ------------------------------------------------------------------------------}
  else
  if aObject is TQtPen then
  begin
    if not APen.IsExtPen then
    begin
      if Buf = nil then
        Result := SizeOf(TLogPen)
      else
      if BufSize >= SizeOf(TLogPen) then
      begin
        Result := SizeOf(TLogPen);
        TQColorToColorRef(APen.getColor, ALogPen^.lopnColor);
        if APen.getCosmetic then
          ALogPen^.lopnWidth := Point(1, 0)
        else
          ALogPen^.lopnWidth := Point(APen.getWidth, 0);
        ALogPen^.lopnStyle := QtPenStyleToWinStyleMap[APen.getStyle];
      end;
    end
    else
    begin
      i := SizeOf(TExtLogPen);
      if APen.getStyle = QtCustomDashLine then
      begin
        Dashes := APen.getDashPattern;
        inc(i, (Length(Dashes) - 1) * SizeOf(DWord));
      end
      else
        Dashes := nil;
      if Buf = nil then
        Result := i
      else
      if BufSize >= i then
      begin
        Result := i;
        AExtLogPen^.elpPenStyle := QtPenStyleToWinStyleMap[APen.getStyle];

        if not APen.getCosmetic then
        begin
          AExtLogPen^.elpPenStyle := AExtLogPen^.elpPenStyle or PS_GEOMETRIC;

          case APen.getJoinStyle of
            QtMiterJoin: AExtLogPen^.elpPenStyle := AExtLogPen^.elpPenStyle or PS_JOIN_MITER;
            QtBevelJoin: AExtLogPen^.elpPenStyle := AExtLogPen^.elpPenStyle or PS_JOIN_BEVEL;
            QtRoundJoin: AExtLogPen^.elpPenStyle := AExtLogPen^.elpPenStyle or PS_JOIN_ROUND;
          end;

          case APen.getCapStyle of
            QtFlatCap: AExtLogPen^.elpPenStyle := AExtLogPen^.elpPenStyle or PS_ENDCAP_FLAT;
            QtSquareCap: AExtLogPen^.elpPenStyle := AExtLogPen^.elpPenStyle or PS_ENDCAP_SQUARE;
            QtRoundCap: AExtLogPen^.elpPenStyle := AExtLogPen^.elpPenStyle or PS_ENDCAP_ROUND;
          end;

          AExtLogPen^.elpWidth := APen.getWidth;
        end
        else
          AExtLogPen^.elpWidth := 1;

        AExtLogPen^.elpBrushStyle := BS_SOLID;
        TQColorToColorRef(APen.getColor, AExtLogPen^.elpColor);
        AExtLogPen^.elpHatch := 0;

        AExtLogPen^.elpNumEntries := Length(Dashes);
        if AExtLogPen^.elpNumEntries > 0 then
        begin
          for i := 0 to AExtLogPen^.elpNumEntries - 1 do
            PDword(@AExtLogPen^.elpStyleEntry)[i] := Trunc(Dashes[i]);
        end
        else
          AExtLogPen^.elpStyleEntry[0] := 0;
      end;
    end;
  end
  {------------------------------------------------------------------------------
    Region
   ------------------------------------------------------------------------------}
  else
  if aObject is TQtRegion then
  begin
    {TODO: implement Region}
    {$ifdef VerboseQtWinAPI}
      ObjType := 'Region';
    {$endif}
  end else
  {------------------------------------------------------------------------------
    Brush
   ------------------------------------------------------------------------------}
  if aObject is TQtBrush then
  begin
    if Buf = nil then
      Result := SizeOf(TLogBrush)
    else
    if BufSize >= SizeOf(TLogBrush) then
    begin
      Result := SizeOf(TLogBrush);
      TQColorToColorRef(ABrush.getColor^, ALogBrush^.lbColor);
      ABrush.GetLbStyle(ALogBrush^.lbStyle, ALogBrush^.lbHatch);
    end;
  end
  {------------------------------------------------------------------------------
    Image
   ------------------------------------------------------------------------------}
  else
  if aObject is TQtImage then
  begin
    {$ifdef VerboseQtWinAPI}
      ObjType := 'Image';
    {$endif}

    if Buf = nil then
      Result := SizeOf(TDIBSECTION)
    else
    begin
      BitmapSection.dsOffset := 0;
      FillChar(BitmapSection, SizeOf(TDIBSECTION), 0);

      with TQtImage(aObject) do
      begin
        {dsBM - BITMAP}
        BitmapSection.dsBm.bmType := $4D42;
        BitmapSection.dsBm.bmWidth := width;
        BitmapSection.dsBm.bmHeight := height;
        BitmapSection.dsBm.bmWidthBytes := bytesPerLine;
        BitmapSection.dsBm.bmPlanes := 1;//Does Bitmap Format support more?
        BitmapSection.dsBm.bmBitsPixel := depth;
        BitmapSection.dsBm.bmBits := bits;

        {dsBmih - BITMAPINFOHEADER}
        BitmapSection.dsBmih.biSize := 40;
        BitmapSection.dsBmih.biWidth := BitmapSection.dsBm.bmWidth;
        BitmapSection.dsBmih.biHeight := BitmapSection.dsBm.bmHeight;
        BitmapSection.dsBmih.biPlanes := BitmapSection.dsBm.bmPlanes;
        BitmapSection.dsBmih.biBitCount := BitmapSection.dsBm.bmBitsPixel;

        BitmapSection.dsBmih.biCompression := 0;

        BitmapSection.dsBmih.biSizeImage := numBytes;
        BitmapSection.dsBmih.biXPelsPerMeter := dotsPerMeterX;
        BitmapSection.dsBmih.biYPelsPerMeter := dotsPerMeterY;

        BitmapSection.dsBmih.biClrUsed := 0;
        BitmapSection.dsBmih.biClrImportant := 0;
      end;

      if BufSize >= SizeOf(BitmapSection) then
      begin
        PDIBSECTION(Buf)^ := BitmapSection;
        Result := SizeOf(TDIBSECTION);
      end
      else if BufSize > 0 then
      begin
        Move(BitmapSection, Buf^, BufSize);
        Result := BufSize;
      end;
    end;
  end;

  {$ifdef VerboseQtWinAPI}
    WriteLn('Trace:< [WinAPI GetObject] Result=', dbgs(Result), ' ObjectType=', ObjType);
  {$endif}
end;

function TQtWidgetSet.GetParent(Handle : HWND): HWND;
var
  QtWidget: TQtWidget;
begin
  {$ifdef VerboseQtWinAPI}
  writeln('Trace:> [WinAPI GetParent] Handle: ' + dbghex(Handle));
  {$endif}
  Result := 0;
  if Handle = 0 then
    exit;

  QtWidget := TQtWidget(Handle);

  Result := HwndFromWidgetH(QtWidget.GetParent);

  {$ifdef VerboseQtWinAPI}
  writeln('Trace:< [WinAPI GetParent] : ' + dbghex(Result));
  {$endif}
end;

function TQtWidgetSet.GetProp(Handle: hwnd; Str: PChar): Pointer;
begin
  if Handle<>0 then
    result := TQtWidget(Handle).Props[str]
  else
    result := nil;
end;

function TQtWidgetSet.GetRgnBox(RGN : HRGN; lpRect : PRect) : Longint;
var
  R: TRect;
begin
  {$ifdef VerboseQtWinAPI}
  writeln('Trace:> [WinAPI GetRgnBox] Handle: ' + dbghex(RGN));
  {$endif}
  Result := SIMPLEREGION;
  if lpRect <> nil then
    lpRect^ := Rect(0,0,0,0);
  if not IsValidGDIObject(RGN) then
    Result := ERROR
  else
  begin
    Result := TQtRegion(RGN).GetRegionType;
    if not (Result in [ERROR, NULLREGION]) and (lpRect <> nil) then
    begin
      R := TQtRegion(RGN).getBoundingRect;
      with lpRect^ do
      begin
        Left   := R.Left;
        Top    := R.Top;
        Right  := R.Left + R.Right;
        Bottom := R.Top + R.Bottom;
      end;
    end;
  end;
end;

function TQtWidgetSet.GetROP2(DC: HDC): Integer;
var
  QtDC: TQtDeviceContext absolute DC;
begin
  {$ifdef VerboseQtWinAPI}
  writeln('> TQtWidgetSet.GetROP2() DC ',dbghex(DC));
  {$endif}
  Result := R2_COPYPEN;
  if not IsValidDC(DC) then
    exit;
  Result := QtDC.Rop2;
  {$ifdef VerboseQtWinAPI}
  writeln('< TQtWidgetSet.GetROP2() DC ',dbghex(DC),' Result ',Result);
  {$endif}
end;

function TQtWidgetSet.GetScrollBarSize(Handle: HWND; BarKind: Integer): integer;
var
  w: TQtWidget;
  ScrollBar: TQtScrollBar;
  ASize: TSize;
begin
	{$ifdef VerboseQtWinAPI}
  writeln('Trace:> [WinAPI GetScrollBarSize] Handle: ' + dbghex(Handle),' BarKind: ',BarKind);
  {$endif}
  Result := 0;
  if Handle = 0 then exit;

  w := TQtWidget(Handle);

  {$IFDEF QTSCROLLABLEFORMS}
  if (w is TQtMainWindow) and Assigned(TQtMainWindow(w).ScrollArea) then
    w := TQtMainWindow(w).ScrollArea;
  {$ENDIF}
  if w is TQtAbstractScrollArea then
  begin
    if BarKind in [SB_VERT, SM_CXVSCROLL, SM_CYVSCROLL] then
      ScrollBar := TQtAbstractScrollArea(w).verticalScrollBar
    else
      ScrollBar := TQtAbstractScrollArea(w).horizontalScrollBar;
  end else
  if w is TQtScrollBar then
    ScrollBar := TQtScrollBar(w)
  else
    ScrollBar := nil;
  if ScrollBar <> nil then
  begin
    if ScrollBar.getOrientation = QtVertical then
    begin
      if not ScrollBar.testAttribute(QtWA_Mapped) then
      begin
        ScrollBar.sizeHint(@ASize);
        Result := ASize.cx;
      end else
        Result := ScrollBar.getWidth;
    end else
    begin
      if not ScrollBar.testAttribute(QtWA_Mapped) then
      begin
        ScrollBar.sizeHint(@ASize);
        Result := ASize.cy;
      end else
        Result := ScrollBar.getHeight;
    end;
  end;
end;

function TQtWidgetSet.GetScrollbarVisible(Handle: HWND; SBStyle: Integer): boolean;
var
  w: TQtWidget;
  ScrollBar: TQtScrollBar;
begin
	{$ifdef VerboseQtWinAPI}
  writeln('Trace:> [WinAPI GetScrollBarVisible] Handle: ' + dbghex(Handle),' SBStyle: ',SBStyle);
  {$endif}
  Result := False;
  if Handle = 0 then exit;

  w := TQtWidget(Handle);

  {TODO: find out what to do with TCustomForm descendants }
  {$IFDEF QTSCROLLABLEFORMS}
  if (w is TQtMainWindow) and Assigned(TQtMainWindow(w).ScrollArea) then
    w := TQtMainWindow(w).ScrollArea;
  {$ENDIF}

  if w is TQtAbstractScrollArea then
  begin
    if SBStyle = SB_VERT then
      ScrollBar := TQtAbstractScrollArea(w).verticalScrollBar
    else
      ScrollBar := TQtAbstractScrollArea(w).horizontalScrollBar;
  end else
  if w is TQtScrollBar then
    ScrollBar := TQtScrollBar(w)
  else
    ScrollBar := nil;

  if ScrollBar <> nil then
    Result := ScrollBar.getVisible;
end;

{------------------------------------------------------------------------------
  Function: GetScrollInfo
  Params: BarFlag
           SB_CTL Retrieves the parameters for a scroll bar control. The hwnd
           parameter must be the handle to the scroll bar control.
           SB_HORZ Retrieves the parameters for the window's standard horizontal
           scroll bar.
           SB_VERT Retrieves the parameters for the window's standard vertical
           scroll bar.

          ScrollInfo returns TScrollInfo structure.

  Returns: boolean

 ------------------------------------------------------------------------------}
function TQtWidgetSet.GetScrollInfo(Handle: HWND; BarFlag: Integer;
  Var ScrollInfo: TScrollInfo): Boolean;
var
  QtScrollBar: TQtScrollBar;
begin
  Result := False;

  if Handle = 0 then exit;

  if (csDestroying in TQtWidget(Handle).LCLObject.ComponentState) or
   (csFreeNotification in TQtWidget(Handle).LCLObject.ComponentState) then
    exit;

  QtScrollBar := nil;

  if not TQtWidget(Handle).LCLObject.InheritsFrom(TCustomScrollBar) then
  begin
    {$IFDEF QTSCROLLABLEFORMS}
    if (TQtWidget(Handle) is TQtMainWindow) and Assigned(TQtMainWindow(Handle).ScrollArea) then
    begin
      case BarFlag of
        SB_HORZ: QtScrollBar := TQtMainWindow(Handle).ScrollArea.horizontalScrollBar;
        SB_VERT: QtScrollBar := TQtMainWindow(Handle).ScrollArea.verticalScrollBar;
      end;
    end else
    {$ENDIF}
    if (TQtWidget(Handle) is TQtAbstractScrollArea) then
    begin
      case BarFlag of
        SB_HORZ: QtScrollBar := TQtAbstractScrollArea(Handle).horizontalScrollBar;
        SB_VERT: QtScrollBar := TQtAbstractScrollArea(Handle).verticalScrollBar;
      end;
    end else
      Result := False;
  end
  else
    QtScrollBar := TQtScrollBar(TScrollBar(TQtWidget(Handle).LCLObject).Handle);

  if Assigned(QtScrollBar) then
  begin
    // POS
    if (ScrollInfo.fMask and SIF_POS) <> 0 then
    begin
      // if QtScrollBar.ChildOfComplexWidget = ccwAbstractScrollArea then
      if QtScrollBar.SliderPressed then
        ScrollInfo.nPos := QtScrollBar.getSliderPosition
      else
        ScrollInfo.nPos := QtScrollBar.getValue;
    end;

    // RANGE
    if (ScrollInfo.fMask and SIF_RANGE) <> 0 then
    begin
      ScrollInfo.nMin:= QtScrollBar.getMin;
      ScrollInfo.nMax:= QtScrollBar.getMax + QtScrollBar.getPageStep;
    end;
    // PAGE
    if (ScrollInfo.fMask and SIF_PAGE) <> 0 then
      ScrollInfo.nPage := QtScrollBar.getPageStep;

    // TRACKPOS
    if (ScrollInfo.fMask and SIF_TRACKPOS) <> 0 then
      ScrollInfo.nTrackPos := QtScrollBar.getSliderPosition;

    Result := True;
  end;
end;

function TQtWidgetSet.GetStockObject(Value: Integer): THandle;
begin
  {$ifdef VerboseQtWinAPI}
    WriteLn('Trace:> [WinAPI GetStockObject] Value: ', Value);
  {$endif}

  Result := 0;

  case Value of
    BLACK_BRUSH:         // Black brush.
      Result := FStockBlackBrush;
    DKGRAY_BRUSH:        // Dark gray brush.
      Result := FStockDKGrayBrush;
    GRAY_BRUSH:          // Gray brush.
      Result := FStockGrayBrush;
    LTGRAY_BRUSH:        // Light gray brush.
      Result := FStockLtGrayBrush;
    NULL_BRUSH:          // Null brush (equivalent to HOLLOW_BRUSH).
      Result := FStockNullBrush;
    WHITE_BRUSH:         // White brush.
      Result := FStockWhiteBrush;

    BLACK_PEN:           // Black pen.
      Result := FStockBlackPen;
    NULL_PEN:            // Null pen.
      Result := FStockNullPen;
    WHITE_PEN:           // White pen.
      Result := FStockWhitePen;

    {System font. By default, Windows uses the system font to draw menus,
     dialog box controls, and text. In Windows versions 3.0 and later,
     the system font is a proportionally spaced font; earlier versions of
     Windows used a monospace system font.}
    DEFAULT_GUI_FONT, SYSTEM_FONT:
      begin

        If FStockSystemFont <> 0 then
        begin
          DeleteObject(FStockSystemFont);
          FStockSystemFont := 0;
        end;

        If FStockSystemFont = 0 then
          FStockSystemFont := CreateDefaultFont;
        Result := FStockSystemFont;
      end;

  {$ifdef VerboseQtWinAPI}
    else
    WriteLn('[WinAPI GetStockObject] UNHANDLED Value: ', Value);
  {$endif}
  end;
  {$ifdef VerboseQtWinAPI}
    WriteLn('Trace:< [WinAPI GetStockObject] Value: ', Value);
  {$endif}
end;

{------------------------------------------------------------------------------
  Function: TQtWidgetSet.GetSysColor
  Params:   index to the syscolors array
  Returns:  RGB value

 ------------------------------------------------------------------------------}
function TQtWidgetSet.GetSysColor(nIndex: Integer): DWORD;

  function GetColor(Group: QPaletteColorGroup; Role: QPaletteColorRole; ClassName: PAnsiChar = nil): TColor;
  var
    Handle: QPaletteH;
    QColor: PQColor;
    QC: QColorH;
  begin
    Handle := QPalette_create;
    if ClassName = nil then
      QApplication_palette(Handle)
    else
      QApplication_palette(Handle, ClassName);

    QColor := QPalette_color(Handle, Group, Role);
    QC := QColor_create(QColor);
    try
      Result := (QColor_red(QC) and $00FF) or ((QColor_green(QC) and $00FF) shl 8) or ((QColor_blue(QC) and $00FF) shl 16);
    finally
      QColor_destroy(QC);
    end;

    QPalette_destroy(Handle);
  end;

begin
  if (nIndex < 0) or (nIndex > MAX_SYS_COLORS) then
  begin
    {$ifdef VerboseQtWinAPI}
      WriteLn('Trace:Unknown lcl system color: [TQtWidgetSet.GetSysColor]');
    {$endif}
    Result := 0;
    Exit;
  end;

  if FCachedColors[nIndex] = nil then
  begin
    case nIndex of
      COLOR_SCROLLBAR               : Result:=GetColor(QPaletteActive,   QPaletteButton);
      COLOR_BACKGROUND              : Result:=GetColor(QPaletteActive,   QPaletteWindow);
      COLOR_WINDOW                  : Result:=GetColor(QPaletteInActive, QPaletteBase);
      COLOR_WINDOWFRAME             : Result:=GetColor(QPaletteActive,   QPaletteShadow);
      COLOR_WINDOWTEXT              : Result:=GetColor(QPaletteActive,   QPaletteWindowText);
      COLOR_ACTIVEBORDER            : Result:=GetColor(QPaletteActive,   QPaletteWindow);
      COLOR_INACTIVEBORDER          : Result:=GetColor(QPaletteInactive, QPaletteWindow);
      COLOR_APPWORKSPACE            : Result:=GetColor(QPaletteActive,   QPaletteWindow);
      COLOR_HIGHLIGHT               : Result:=GetColor(QPaletteActive,   QPaletteHighlight);
      COLOR_HIGHLIGHTTEXT           : Result:=GetColor(QPaletteActive,   QPaletteHighlightedText);
      COLOR_BTNFACE                 : Result:=GetColor(QPaletteActive,   QPaletteButton);
      COLOR_BTNSHADOW               : Result:=GetColor(QPaletteActive,   QPaletteDark);
      COLOR_GRAYTEXT                : Result:=GetColor(QPaletteDisabled,   QPaletteText);
      COLOR_BTNTEXT                 : Result:=GetColor(QPaletteActive,   QPaletteButtonText);
      COLOR_BTNHIGHLIGHT            : Result:=GetColor(QPaletteActive,   QPaletteLight);
      COLOR_3DDKSHADOW              : Result:=GetColor(QPaletteActive,   QPaletteShadow);
      COLOR_3DLIGHT                 : Result:=GetColor(QPaletteActive,   QPaletteMidlight);
      COLOR_INFOTEXT                : Result:=GetColor(QPaletteInActive, QPaletteToolTipText);
      COLOR_INFOBK                  : Result:=GetColor(QPaletteInActive, QPaletteToolTipBase);
      COLOR_HOTLIGHT                : Result:=GetColor(QPaletteActive,   QPaletteLight);

      // qt does not provide any methods to retrieve titlebar colors
    {$IFNDEF MSWINDOWS}
      COLOR_ACTIVECAPTION           : Result:=GetColor(QPaletteActive,   QPaletteHighlight);
      COLOR_INACTIVECAPTION         : Result:=GetColor(QPaletteInActive, QPaletteHighlight);
      COLOR_CAPTIONTEXT             : Result:=GetColor(QPaletteActive,   QPaletteHighlightedText);
      COLOR_INACTIVECAPTIONTEXT     : Result:=GetColor(QPaletteInactive, QPaletteHighlightedText);
      COLOR_GRADIENTACTIVECAPTION   : Result:=GetColor(QPaletteActive,   QPaletteBase);
      COLOR_GRADIENTINACTIVECAPTION : Result:=GetColor(QPaletteInactive, QPaletteBase);
    {$ELSE}
      COLOR_ACTIVECAPTION           : Result:=Windows.GetSysColor(COLOR_ACTIVECAPTION);
      COLOR_INACTIVECAPTION         : Result:=Windows.GetSysColor(COLOR_INACTIVECAPTION);
      COLOR_CAPTIONTEXT             : Result:=Windows.GetSysColor(COLOR_CAPTIONTEXT);
      COLOR_INACTIVECAPTIONTEXT     : Result:=Windows.GetSysColor(COLOR_INACTIVECAPTIONTEXT);
      COLOR_GRADIENTACTIVECAPTION   : Result:=Windows.GetSysColor(COLOR_GRADIENTACTIVECAPTION);
      COLOR_GRADIENTINACTIVECAPTION : Result:=Windows.GetSysColor(COLOR_GRADIENTINACTIVECAPTION);
    {$ENDIF}
      COLOR_MENU                    : Result:=GetColor(QPaletteActive,   QPaletteButton, 'QMenu');
      COLOR_MENUTEXT                : Result:=GetColor(QPaletteActive,   QPaletteButtonText, 'QMenu');
      COLOR_MENUHILIGHT             : Result:=GetColor(QPaletteDisabled, QPaletteHighlight, 'QMenu');
      COLOR_MENUBAR                 : Result:=GetColor(QPaletteActive,   QPaletteButton, 'QMenu');
      COLOR_FORM                    : Result:=GetColor(QPaletteActive,   QPaletteWindow);
    else
      Result:=0;
    end;
    FCachedColors[nIndex] := getMem(SizeOf(LongWord));
    FCachedColors[nIndex]^ := Result;
  end
  else
    Result := FCachedColors[nIndex]^;
end;

function TQtWidgetSet.GetSysColorBrush(nIndex: Integer): HBrush;

  function GetBrush(Group: QPaletteColorGroup; Role: QPaletteColorRole; ClassName: PAnsiChar = nil): HBrush;
  var
    Handle: QPaletteH;
  begin
    Handle := QPalette_create;
    if ClassName = nil then
      QApplication_palette(Handle)
    else
      QApplication_palette(Handle, ClassName);
    if FSysColorBrushes[nIndex] = 0 then
      Result := HBrush(TQtBrush.Create(False))
    else
      Result := FSysColorBrushes[nIndex];
    TQtBrush(Result).FHandle := QBrush_create(QPalette_brush(Handle, Group, Role));
    TQtBrush(Result).FShared := True;

    QPalette_destroy(Handle);
  end;

  function GetSolidBrush(AColor: TColor): HBrush;
  var
    Color: TQColor;
  begin
    if FSysColorBrushes[nIndex] = 0 then
      Result := HBrush(TQtBrush.Create(True))
    else
      Result := FSysColorBrushes[nIndex];
    Color := QBrush_Color(TQtBrush(Result).FHandle)^;
    ColorRefToTQColor(ColorToRGB(AColor), Color);
    QBrush_setColor(TQtBrush(Result).FHandle, @Color);
    TQtBrush(Result).FShared := True;
  end;

begin
  if (nIndex < 0) or (nIndex > MAX_SYS_COLORS) then
  begin
    Result := 0;
    Exit;
  end;

  if (FSysColorBrushes[nIndex] = 0) or
    (
    (FSysColorBrushes[nIndex] <> 0) and
    (TQtBrush(FSysColorBrushes[nIndex]).FHandle = nil)
    ) then
  begin
    case nIndex of
      COLOR_SCROLLBAR               : Result:=GetBrush(QPaletteActive,   QPaletteButton);
      COLOR_BACKGROUND              : Result:=GetBrush(QPaletteActive,   QPaletteWindow);
      COLOR_WINDOW                  : Result:=GetBrush(QPaletteInActive, QPaletteBase);
      COLOR_WINDOWFRAME             : Result:=GetBrush(QPaletteActive,   QPaletteShadow);
      COLOR_WINDOWTEXT              : Result:=GetBrush(QPaletteActive,   QPaletteWindowText);
      COLOR_ACTIVEBORDER            : Result:=GetBrush(QPaletteActive,   QPaletteWindow);
      COLOR_INACTIVEBORDER          : Result:=GetBrush(QPaletteInactive, QPaletteWindow);
      COLOR_APPWORKSPACE            : Result:=GetBrush(QPaletteActive,   QPaletteWindow);
      COLOR_HIGHLIGHT               : Result:=GetBrush(QPaletteActive,   QPaletteHighlight);
      COLOR_HIGHLIGHTTEXT           : Result:=GetBrush(QPaletteActive,   QPaletteHighlightedText);
      COLOR_BTNFACE                 : Result:=GetBrush(QPaletteActive,   QPaletteButton);
      COLOR_BTNSHADOW               : Result:=GetBrush(QPaletteActive,   QPaletteDark);
      COLOR_GRAYTEXT                : Result:=GetBrush(QPaletteActive,   QPaletteText);
      COLOR_BTNTEXT                 : Result:=GetBrush(QPaletteActive,   QPaletteButtonText);
      COLOR_BTNHIGHLIGHT            : Result:=GetBrush(QPaletteActive,   QPaletteLight);
      COLOR_3DDKSHADOW              : Result:=GetBrush(QPaletteActive,   QPaletteShadow);
      COLOR_3DLIGHT                 : Result:=GetBrush(QPaletteActive,   QPaletteMidlight);
      COLOR_INFOTEXT                : Result:=GetBrush(QPaletteInActive, QPaletteToolTipText);
      COLOR_INFOBK                  : Result:=GetBrush(QPaletteInActive, QPaletteToolTipBase);
      COLOR_HOTLIGHT                : Result:=GetBrush(QPaletteActive,   QPaletteLight);

      // qt does not provide any methods to retrieve titlebar colors
    {$IFNDEF MSWINDOWS}
      COLOR_ACTIVECAPTION           : Result:=GetBrush(QPaletteActive,   QPaletteHighlight);
      COLOR_INACTIVECAPTION         : Result:=GetBrush(QPaletteInActive, QPaletteHighlight);
      COLOR_CAPTIONTEXT             : Result:=GetBrush(QPaletteActive,   QPaletteHighlightedText);
      COLOR_INACTIVECAPTIONTEXT     : Result:=GetBrush(QPaletteInactive, QPaletteHighlightedText);
      COLOR_GRADIENTACTIVECAPTION   : Result:=GetBrush(QPaletteActive,   QPaletteBase);
      COLOR_GRADIENTINACTIVECAPTION : Result:=GetBrush(QPaletteInactive, QPaletteBase);
    {$ELSE}
      COLOR_ACTIVECAPTION           : Result:=GetSolidBrush(Windows.GetSysColor(COLOR_ACTIVECAPTION));
      COLOR_INACTIVECAPTION         : Result:=GetSolidBrush(Windows.GetSysColor(COLOR_INACTIVECAPTION));
      COLOR_CAPTIONTEXT             : Result:=GetSolidBrush(Windows.GetSysColor(COLOR_CAPTIONTEXT));
      COLOR_INACTIVECAPTIONTEXT     : Result:=GetSolidBrush(Windows.GetSysColor(COLOR_INACTIVECAPTIONTEXT));
      COLOR_GRADIENTACTIVECAPTION   : Result:=GetSolidBrush(Windows.GetSysColor(COLOR_GRADIENTACTIVECAPTION));
      COLOR_GRADIENTINACTIVECAPTION : Result:=GetSolidBrush(Windows.GetSysColor(COLOR_GRADIENTINACTIVECAPTION));
    {$ENDIF}
      COLOR_MENU                    : Result:=GetBrush(QPaletteActive,   QPaletteButton, 'QMenu');
      COLOR_MENUTEXT                : Result:=GetBrush(QPaletteActive,   QPaletteButtonText, 'QMenu');
      COLOR_MENUHILIGHT             : Result:=GetBrush(QPaletteDisabled, QPaletteHighlight, 'QMenu');
      COLOR_MENUBAR                 : Result:=GetBrush(QPaletteActive,   QPaletteButton, 'QMenu');
      COLOR_FORM                    : Result:=GetBrush(QPaletteActive,   QPaletteWindow);
    else
      Result:=0;
    end;
    FSysColorBrushes[nIndex] := Result;
  end
  else
    Result := FSysColorBrushes[nIndex];
end;

{------------------------------------------------------------------------------
  Function: GetSystemMetrics
  Params:
  Returns: Nothing


 ------------------------------------------------------------------------------}
function TQtWidgetSet.GetSystemMetrics(nIndex: Integer): Integer;
var
  R: TRect;
begin
  {$ifdef VerboseQtWinAPI}
    WriteLn(Format('Trace:> [TQtWidgetSet.GetSystemMetrics] %d', [nIndex]));
  {$endif}
  Result := 0;
  case nIndex of
    SM_ARRANGE:
      begin
        {$ifdef VerboseQtWinAPI}
          WriteLn('Trace:TODO: [TQtWidgetSet.GetSystemMetrics] --> SM_ARRANGE          ');
        {$endif}
      end;
    SM_CLEANBOOT:
      begin
        {$ifdef VerboseQtWinAPI}
          WriteLn('Trace:TODO: [TQtWidgetSet.GetSystemMetrics] --> SM_CLEANBOOT          ');
        {$endif}
      end;
    SM_CMONITORS:
      Result := QDesktopWidget_numScreens(QApplication_desktop());
    SM_CMOUSEBUTTONS:
      begin
        //DebugLn('Trace:TODO: [TQtWidgetSet.GetSystemMetrics] --> SM_CMOUSEBUTTONS    ');
      end;
    SM_CXBORDER, SM_CYBORDER:
      begin
        //The height of a window border, in pixels
        Result := GetPixelMetric(QStylePM_DefaultFrameWidth, nil, nil);
      end;
    SM_CXCURSOR:
      begin
        Result := 32; // recomended in docs
      end;
    SM_CYCURSOR:
      begin
        Result := 32; // recomended in docs
      end;
    SM_CXDOUBLECLK:
      begin
        //DebugLn('Trace:TODO: [TQtWidgetSet.GetSystemMetrics] --> SM_CXDOUBLECLK      ');
      end;
    SM_CYDOUBLECLK:
      begin
        //DebugLn('Trace:TODO: [TQtWidgetSet.GetSystemMetrics] --> SM_CYDOUBLECLK      ');
      end;
    SM_CXDRAG,
    SM_CYDRAG: QApplication_startDragDistance();
    SM_CXEDGE:
      begin
        Result := 2;
      end;
    SM_CYEDGE:
      begin
        Result := 2;
      end;
    SM_CXFIXEDFRAME:
      begin
        //DebugLn('Trace:TODO: [TQtWidgetSet.GetSystemMetrics] --> SM_CXFIXEDFRAME     ');
      end;
    SM_CYFIXEDFRAME:
      begin
        //DebugLn('Trace:TODO: [TQtWidgetSet.GetSystemMetrics] --> SM_CYFIXEDFRAME     ');
      end;
    SM_CXHTHUMB,
    SM_CYVTHUMB:
      begin
        Result := GetPixelMetric(QStylePM_ScrollBarSliderMin, nil, nil);
      end;
    SM_CXICON,
    SM_CYICON:
      begin
        Result := 32;
      end;
    SM_CXICONSPACING:
      begin
        //DebugLn('Trace:TODO: [TQtWidgetSet.GetSystemMetrics] --> SM_CXICONSPACING    ');
      end;
    SM_CYICONSPACING:
      begin
        //DebugLn('Trace:TODO: [TQtWidgetSet.GetSystemMetrics] --> SM_CYICONSPACING    ');
      end;
    SM_CXMAXIMIZED:
      begin
        QDesktopWidget_availableGeometry(QApplication_desktop(), @R,
          QDesktopWidget_primaryScreen(QApplication_desktop()));
        Result := R.Right - R.Left;
      end;
    SM_CYMAXIMIZED:
      begin
        QDesktopWidget_availableGeometry(QApplication_desktop(), @R,
          QDesktopWidget_primaryScreen(QApplication_desktop()));
        Result := R.Bottom - R.Top;
      end;
    SM_CXMAXTRACK:
      begin
        //DebugLn('Trace:TODO: [TQtWidgetSet.GetSystemMetrics] --> SM_CXMAXTRACK       ');
      end;
    SM_CYMAXTRACK:
      begin
        //DebugLn('Trace:TODO: [TQtWidgetSet.GetSystemMetrics] --> SM_CYMAXTRACK       ');
      end;
    SM_CXMENUCHECK:
      begin
        Result := GetPixelMetric(QStylePM_IndicatorWidth, nil, nil);
      end;
    SM_CYMENUCHECK:
      begin
        Result := GetPixelMetric(QStylePM_IndicatorHeight, nil, nil);
      end;
    SM_CXMENUSIZE,
    SM_CYMENUSIZE:
      begin
        Result := GetPixelMetric(QStylePM_TitleBarHeight, nil, nil) -
          (GetPixelMetric(QStylePM_DefaultFrameWidth, nil, nil) * 2);
      end;
    SM_CXMIN,
    SM_CYMIN: Result := 0;
    SM_CXMINIMIZED:
      begin
        //DebugLn('Trace:TODO: [TQtWidgetSet.GetSystemMetrics] --> SM_CXMINIMIZED      ');
      end;
    SM_CYMINIMIZED:
      begin
        //DebugLn('Trace:TODO: [TQtWidgetSet.GetSystemMetrics] --> SM_CYMINIMIZED      ');
      end;
    SM_CXMINSPACING:
      begin
        //DebugLn('Trace:TODO: [TQtWidgetSet.GetSystemMetrics] --> SM_CXMINSPACING     ');
      end;
    SM_CYMINSPACING:
      begin
        //DebugLn('Trace:TODO: [TQtWidgetSet.GetSystemMetrics] --> SM_CYMINSPACING     ');
      end;
    SM_CXMINTRACK:
      begin
        //DebugLn('Trace:TODO: [TQtWidgetSet.GetSystemMetrics] --> SM_CXMINTRACK       ');
      end;
    SM_CYMINTRACK:
      begin
        //DebugLn('Trace:TODO: [TQtWidgetSet.GetSystemMetrics] --> SM_CYMINTRACK       ');
      end;
    SM_CXFULLSCREEN,
    SM_CXSCREEN:
      begin
        QDesktopWidget_screenGeometry(QApplication_desktop(), @R, QDesktopWidget_primaryScreen(QApplication_desktop()));
        Result := R.Right - R.Left;
      end;
    SM_CYFULLSCREEN,
    SM_CYSCREEN:
      begin
        QDesktopWidget_screenGeometry(QApplication_desktop(), @R, QDesktopWidget_primaryScreen(QApplication_desktop()));
        Result := R.Bottom - R.Top;
      end;
    SM_CXSIZE:
      begin
        //DebugLn('Trace:TODO: [TQtWidgetSet.GetSystemMetrics] --> SM_CXSIZE           ');
      end;
    SM_CYSIZE:
      begin
        //DebugLn('Trace:TODO: [TQtWidgetSet.GetSystemMetrics] --> SM_CYSIZE           ');
      end;
    SM_CXSIZEFRAME,
    SM_CYSIZEFRAME:
      begin
        Result := GetPixelMetric(QStylePM_MDIFrameWidth, nil, nil);
      end;
    SM_CXSMICON,
    SM_CYSMICON:
      begin
        Result := GetPixelMetric(QStylePM_SmallIconSize, nil, nil);
      end;
    SM_CXSMSIZE:
      begin
        //DebugLn('Trace:TODO: [TQtWidgetSet.GetSystemMetrics] --> SM_CXSMSIZE         ');
      end;
    SM_CYSMSIZE:
      begin
        //DebugLn('Trace:TODO: [TQtWidgetSet.GetSystemMetrics] --> SM_CYSMSIZE         ');
      end;
    SM_XVIRTUALSCREEN:
      begin
        Result := QWidget_x(QApplication_desktop);
      end;
    SM_YVIRTUALSCREEN:
      begin
        Result := QWidget_y(QApplication_desktop);
      end;
    SM_CXVIRTUALSCREEN:
      begin
        Result := QWidget_width(QApplication_desktop);
      end;
    SM_CYVIRTUALSCREEN:
      begin
        Result := QWidget_height(QApplication_desktop);
      end;
    SM_CXVSCROLL,
    SM_CYVSCROLL,
    SM_CXHSCROLL,
    SM_CYHSCROLL:
      begin
        Result := GetPixelMetric(QStylePM_ScrollBarExtent, nil, nil);
      end;
    SM_CYCAPTION:
      begin
        Result := GetPixelMetric(QStylePM_TitleBarHeight, nil, nil);
      end;
    SM_CYKANJIWINDOW:
      begin
        //DebugLn('Trace:TODO: [TQtWidgetSet.GetSystemMetrics] --> SM_CYKANJIWINDOW    ');
      end;
    SM_CYMENU:
      begin
        Result := GetMenuHeight;
      end;
    SM_CYSMCAPTION:
      begin
        //DebugLn('Trace:TODO: [TQtWidgetSet.GetSystemMetrics] --> SM_CYSMCAPTION      ');
      end;
    SM_DBCSENABLED:
      begin
        //DebugLn('Trace:TODO: [TQtWidgetSet.GetSystemMetrics] --> SM_DBCSENABLED      ');
      end;
    SM_DEBUG:
      begin
        //DebugLn('Trace:TODO: [TQtWidgetSet.GetSystemMetrics] --> SM_DEBUG            ');
      end;
    SM_MENUDROPALIGNMENT:
      begin
        //DebugLn('Trace:TODO: [TQtWidgetSet.GetSystemMetrics] --> SM_MENUDROPALIGNMENT');
      end;
    SM_MIDEASTENABLED:
      begin
        //DebugLn('Trace:TODO: [TQtWidgetSet.GetSystemMetrics] --> SM_MIDEASTENABLED   ');
      end;
    SM_MOUSEPRESENT:
      begin
        //DebugLn('Trace:TODO: [TQtWidgetSet.GetSystemMetrics] --> SM_MOUSEPRESENT     ');
      end;
    SM_MOUSEWHEELPRESENT:
      begin
        //DebugLn('Trace:TODO: [TQtWidgetSet.GetSystemMetrics] --> SM_MOUSEWHEELPRESENT');
      end;
    SM_NETWORK:
      begin
        //DebugLn('Trace:TODO: [TQtWidgetSet.GetSystemMetrics] --> SM_NETWORK          ');
      end;
    SM_PENWINDOWS:
      begin
        //DebugLn('Trace:TODO: [TQtWidgetSet.GetSystemMetrics] --> SM_PENWINDOWS       ');
      end;
    SM_SECURE:
      begin
        //DebugLn('Trace:TODO: [TQtWidgetSet.GetSystemMetrics] --> SM_SECURE           ');
      end;
    SM_SHOWSOUNDS:
      begin
        //DebugLn('Trace:TODO: [TQtWidgetSet.GetSystemMetrics] --> SM_SHOWSOUNDS       ');
      end;
    SM_SLOWMACHINE:
      begin
        //DebugLn('Trace:TODO: [TQtWidgetSet.GetSystemMetrics] --> SM_SLOWMACHINE      ');
      end;
    SM_SWAPBUTTON:
      begin
        //DebugLn('Trace:TODO: [TQtWidgetSet.GetSystemMetrics] --> SM_SWAPBUTTON       ');
      end;
    SM_SWSCROLLBARSPACING:
      begin
        Result := 0;
        if (QStyle_styleHint(QApplication_style(),
          QStyleSH_ScrollView_FrameOnlyAroundContents) <> 0) then
        Result := QStyle_pixelMetric(QApplication_style(),
          QStylePM_ScrollView_ScrollBarSpacing, nil, nil);
      end;
    SM_LCLMAXIMIZEDWIDTH:
      begin
        Result := GetSystemMetrics(SM_CXMAXIMIZED);
      end;
    SM_LCLMAXIMIZEDHEIGHT:
      begin
        Result := GetSystemMetrics(SM_CYMAXIMIZED) - 1 -
          (GetSystemMetrics(SM_CYCAPTION) - (GetSystemMetrics(SM_CYSIZEFRAME) * 2));
      end;
    SM_LCLHasFormAlphaBlend:
      Result := 1;
  end;
end;

{------------------------------------------------------------------------------
  Function: GetTextColor
  Params:  DC     - A device context
  Returns: TColorRef

  Gets the Font Color currently assigned to the Device Context
 ------------------------------------------------------------------------------}
function TQtWidgetSet.GetTextColor(DC: HDC) : TColorRef;
var
  Color: TQColor;
  QtDC: TQtDeviceContext;
begin
  {$ifdef VerboseQtWinAPI}
    WriteLn('[WinAPI GetTextColor]');
  {$endif}

  Result := 0;

  if IsValidDC(DC) then
  begin
    QtDC := TQtDeviceContext(DC);
    ColorRefToTQColor(TColorRef(QtDC.vTextColor), Color{%H-});
    TQColorToColorRef(Color, Result);
  end;
end;

{------------------------------------------------------------------------------
  Function: GetTextExtentExPoint
  Params: http://msdn.microsoft.com/en-us/library/dd144935%28VS.85%29.aspx
  Returns: True on success
 ------------------------------------------------------------------------------}
function TQtWidgetSet.GetTextExtentExPoint(DC: HDC; Str: PChar; Count,
  MaxWidth: Integer; MaxCount, PartialWidths: PInteger; var Size: TSize
  ): Boolean;
var
  i: Integer;
  w: Integer;
  AStr: WideString;
  Accu: Integer;
begin
  Result := False;
  if not IsValidDC(DC) then Exit;
  with TQtDeviceContext(DC) do
  begin
    if Str = nil then
      AStr := ''
    else
      AStr := Str;
    Size.cx := 0;
    Size.cY := Font.Metrics.Height;
    if (AStr = '') then
    begin
      if MaxCount <> nil then
        MaxCount^ := 0;
      if PartialWidths <> nil then
      begin
        for i := 0 to Count - 1 do
          PartialWidths[i] := 0;
      end;
      exit(True);
    end;
    if PartialWidths = nil then
    begin
      if MaxCount <> nil then
      begin
        Size.cx := Font.Metrics.width(@AStr);
        Accu := 0;
        if MaxWidth <= 0 then
          MaxCount^ := 0
        else
          for i := 0 to Count - 1 do
          begin
            W := QFontMetrics_charWidth(Font.Metrics.FHandle, @AStr, i);
            Accu := Accu + W;
            if Accu <= MaxWidth then
              MaxCount^ := i + 1
            else
              break;
          end;
      end;
    end else
    begin
      if MaxCount <> nil then
        MaxCount^ := 0;
      for i := 0 to Count - 1 do
      begin
        w := QFontMetrics_charWidth(Font.Metrics.FHandle, @AStr, i);
        Inc(Size.cx, w);
        if MaxCount <> nil then
        begin
          if Size.cx <= MaxWidth then
          begin
            inc(MaxCount^);
            PartialWidths[i] := Size.cx;
          end else
          begin
            Dec(Size.cx, w);
            break;
          end;
        end else
          PartialWidths[i] := Size.cx;
      end;
    end;
  end;
  Result := True;
end;

{------------------------------------------------------------------------------
  Function: GetTextExtentPoint
  Params:  none
  Returns: Nothing
 ------------------------------------------------------------------------------}
function TQtWidgetSet.GetTextExtentPoint(DC: HDC; Str: PChar; Count: Integer; var Size: TSize): Boolean;
var
  WStr: WideString;
  QtDC: TQtDeviceContext absolute DC;
begin
  {$ifdef VerboseQtWinAPI}
    WriteLn('[WinAPI GetTextExtentPoint]');
  {$endif}

  Result := IsValidDC(DC);

  if not Result then
    exit;

  Size.cx := 0;
  Size.cy := 0;
  if (Count <= 0) or (Str = nil) or (StrPas(Str) = '') then
    exit;
  WStr := Str;
  Size.cx := QtDC.Metrics.width(@WStr, Count);
  Size.cy := QtDC.Metrics.height;

  Result := True;
end;

{------------------------------------------------------------------------------
  Function: GetTextMetrics
  Params:  DC     - A device context with a font selected
           TM     - The structure to receive the font information
  Returns: If successfull
 ------------------------------------------------------------------------------}
function TQtWidgetSet.GetTextMetrics(DC: HDC; var TM: TTextMetric): Boolean;
var
  QtFontMetrics: TQtFontMetrics;
  FontFamily: WideString;
  QtDC: TQtDeviceContext absolute DC;
  FontWeight: Integer;
begin
  {$ifdef VerboseQtWinAPI}
    WriteLn('[WinAPI GetTextMetrics]');
  {$endif}

  Result := IsValidDC(DC);

  if Result then
  begin
    QtFontMetrics := QtDC.Metrics;
    TM.tmHeight := QtFontMetrics.height;
    TM.tmAscent := QtFontMetrics.ascent;
    TM.tmDescent := QtFontMetrics.descent;
    TM.tmInternalLeading := 0;
    TM.tmExternalLeading := QtFontMetrics.leading;
    {this is due qt bug in fontmetrics::averageCharWidth() under Mac
     http://trolltech.com/developer/task-tracker/index_html?method=entry&id=169440 }
    {$IFDEF DARWIN}
    if (QtVersionMajor = 4) and (QtVersionMinor >= 6) then
      TM.tmAveCharWidth := QtFontMetrics.averageCharWidth
    else
      TM.tmAveCharWidth := QtFontMetrics.charWidth('x',0);
    {$ELSE}
    TM.tmAveCharWidth := QtFontMetrics.averageCharWidth;
    {$ENDIF}

    TM.tmMaxCharWidth := QtFontMetrics.maxWidth;
    FontWeight := QtDC.font.getWeight;
    case FontWeight of
      25: TM.tmWeight := FW_LIGHT;
      50: TM.tmWeight := FW_NORMAL;
      63: TM.tmWeight := FW_SEMIBOLD;
      75: TM.tmWeight := FW_BOLD;
      87: TM.tmWeight := FW_HEAVY;
      else
        TM.tmWeight := Round(FontWeight * 9.5);
    end;
    TM.tmOverhang := 0;
    TM.tmDigitizedAspectX := 0;
    TM.tmDigitizedAspectY := 0;
    TM.tmFirstChar := 'a';
    TM.tmLastChar := 'z';
    TM.tmDefaultChar := 'x';
    TM.tmBreakChar := '?';
    TM.tmItalic := Ord(QtDC.Font.getItalic);
    TM.tmUnderlined := Ord(QtDC.Font.getUnderline);
    TM.tmStruckOut := Ord(QtDC.Font.getStrikeOut);

    QtDC.font.family(@FontFamily);

    { Defaults to a TrueType font.
      Note that the meaning of the FIXED_PITCH constant is the opposite of
      the name implies, according to MSDN docs. Just a small inconsistency
      on Windows API that we have to mimic. }
    if QtDC.font.fixedPitch then
      TM.tmPitchAndFamily := TRUETYPE_FONTTYPE
    else
      TM.tmPitchAndFamily := FIXED_PITCH or TRUETYPE_FONTTYPE;

    TM.tmCharSet := DEFAULT_CHARSET;
  end;
end;

function TQtWidgetSet.GetViewPortExtEx(DC: HDC; Size: PSize): Integer;
var
  R: TRect;
begin
  if IsValidDC(DC) and (Size <> nil) then
  begin
    QPainter_ViewPort(TQtDeviceContext(DC).Widget, @R);
    Size^.cx := R.Right - R.Left;
    Size^.cy := R.Bottom - R.Top;
    Result := Integer(True);
  end else
    Result := Integer(False);
end;

function TQtWidgetSet.GetViewPortOrgEx(DC: HDC; P: PPoint): Integer;
var
  R: TRect;
begin
  if IsValidDC(DC) and (P <> nil) then
  begin
    QPainter_ViewPort(TQtDeviceContext(DC).Widget, @R);
    P^ := R.TopLeft;
    Result := Integer(True);
  end else
    Result := Integer(False);
end;

function TQtWidgetSet.GetWindowExtEx(DC: HDC; Size: PSize): Integer;
var
  R: TRect;
begin
  if IsValidDC(DC) and (Size <> nil) then
  begin
    QPainter_Window(TQtDeviceContext(DC).Widget, @R);
    Size^.cx := R.Right - R.Left;
    Size^.cy := R.Bottom - R.Top;
    Result := Integer(True);
  end else
    Result := Integer(False);
end;

function TQtWidgetSet.GetWindowLong(Handle : hwnd; int: Integer): PtrInt;
begin
  Result := 0;
  {$ifdef VerboseQtWinAPI_MISSING_IMPLEMENTATION}
    WriteLn('***** [WinAPI TQtWidgetSet.GetWindowLong] missing implementation ');
  {$endif}
end;

{------------------------------------------------------------------------------
  Method:  GetWindowOrgEx
  Params:  DC    -
  Returns:
 ------------------------------------------------------------------------------}
function TQtWidgetSet.GetWindowOrgEx(dc: hdc; P: PPoint): Integer;
var
  Matrix: QTransformH;
begin
  {$ifdef VerboseQtWinAPI}
    WriteLn('Trace: > [WinAPI GetWindowOrgEx]');
  {$endif}
  Result := 0;
  if not IsValidDC(DC) and (P<>nil) then
  begin
    {$ifdef VerboseQtWinAPI}
      WriteLn('Trace: < [WinAPI GetWindowOrgEx] No valid DC or P is nil');
    {$endif}
    exit;
  end;

  Matrix := QPainter_transform(TQtDeviceContext(DC).Widget);
  if Matrix <> nil then
  begin
    P^.X := -Trunc(QTransform_Dx(Matrix));
    P^.Y := -Trunc(QTransform_Dy(Matrix));
    Result := 1;
  end;
  {$ifdef VerboseQtWinAPI}
    WriteLn('Trace: < [WinAPI GetWindowOrgEx] Result=', dbgs(p^));
  {$endif}
end;


{------------------------------------------------------------------------------
  Method:  GetWindowRect
  Params:  Handle - handle of window
           Rect   - record for window coordinates
  Returns: if the function succeeds, the return value is nonzero; if the
           function fails, the return value is zero

  Retrieves the dimensions of the bounding rectangle of the specified window.
 ------------------------------------------------------------------------------}
function TQtWidgetSet.GetWindowRect(Handle: hwnd; var ARect: TRect): Integer;
var
  APos: TQtPoint;
  R, AFrame: TRect;
  AForm: TCustomForm;
begin
  {$ifdef VerboseQtWinAPI}
    WriteLn('[WinAPI GetWindowRect]');
  {$endif}

  Result := 0;
  if not IsValidHandle(Handle) then
    exit;

  if (TQtWidget(Handle) is TQtMainWindow) and Assigned(TQtWidget(Handle).LCLObject) and
    (TQtWidget(Handle).LCLObject.Parent = nil) and
    not TQtMainWindow(Handle).FirstPaintEvent
    {$IFDEF HASX11}and (QtWidgetSet.GetDummyWidgetFrame <> Rect(0, 0, 0, 0)){$ENDIF} then
  begin
    AForm := TCustomForm(TQtWidget(Handle).LCLObject);
    if not (AForm.FormStyle in [fsMDIChild, fsSplash]) and (AForm.BorderStyle <> bsNone) and
      not IsFormDesign(AForm) then
    begin
      {$IFDEF HASX11}
      R := AForm.BoundsRect;
      AFrame := QtWidgetSet.GetDummyWidgetFrame;
      // apply frame size to lcl form.
      R.Right += AFrame.Left + AFrame.Right;
      R.Bottom += AFrame.Top + AFrame.Bottom;
      ARect := R; //this is now real size under x11 even on unmapped window :)
      exit(-1);
      {$ELSE}
      QWidget_winID(TQtWidget(Handle).Widget);
      {$ENDIF}
    end;
  end;

  APos := QtPoint(0,0);
  QWidget_mapToGlobal(TQtWidget(Handle).Widget, @APos, @APos);

  R := TQtWidget(Handle).getFrameGeometry;
  ARect := Bounds(APos.X,APos.Y,R.Right-R.Left,R.Bottom-R.Top);
  Result := -1;
end;

{------------------------------------------------------------------------------
  Function: GetWindowRelativePosition
  Params:  Handle : HWND;
  Returns: true on success

  returns the current widget Left, Top, relative to the client origin of its
  parent. Top level form returns 0,0 when we use accurate frames.
 ------------------------------------------------------------------------------}
function TQtWidgetSet.GetWindowRelativePosition(Handle: hwnd; var Left,
  Top: Integer): boolean;
var
  R: TRect;
begin
  {$ifdef VerboseQtWinAPI}
    WriteLn('[WinAPI GetWindowRelativePosition]');
  {$endif}
  if Handle = 0 then
    Exit(False);
  R := TQtWidget(Handle).getFrameGeometry;
  Left := R.Left;
  Top := R.Top;
  Result := True;
end;

{------------------------------------------------------------------------------
  Function: GetWindowSize
  Params:  Handle : hwnd;
  Returns: true on success

  Returns the current widget Width and Height
 ------------------------------------------------------------------------------}
function TQtWidgetSet.GetWindowSize(Handle: hwnd; var Width, Height: Integer
  ): boolean;
var
  ASize: TSize;
begin
  {$ifdef VerboseQtWinAPI}
    WriteLn('[WinAPI GetWindowSize]');
  {$endif}
  if Handle = 0 then
    Exit(False);

  ASize := TQtWidget(Handle).getSize;
  Height := ASize.cy;
  Width := ASize.cx;

  Result := True;

  // Here we should convert top level lcl window coordinaties to qt coord
  // Due to borders and etc
  // ?
end;

{------------------------------------------------------------------------------
  Function: GradientFill
  Params: DC - DeviceContext to perform on
          Vertices - array of Points W/Color & Alpha
          NumVertices - Number of Vertices
          Meshes - array of Triangle or Rectangle Meshes,
                   each mesh representing one Gradient Fill
          NumMeshes - Number of Meshes
          Mode - Gradient Type, either Triangle,
                 Vertical Rect, Horizontal Rect

  Returns: true on success

  Performs multiple Gradient Fills, either a Three way Triangle Gradient,
  or a two way Rectangle Gradient, each Vertex point also supports optional
  Alpha/Transparency for more advanced Gradients.
 ------------------------------------------------------------------------------}
function TQtWidgetSet.GradientFill(DC: HDC; Vertices: PTriVertex;
  NumVertices: Longint; Meshes: Pointer; NumMeshes: Longint; Mode: Longint
  ): Boolean;

  function DoFillTriangle: Boolean; inline;
  begin
    Result := (Mode and GRADIENT_FILL_TRIANGLE) = GRADIENT_FILL_TRIANGLE;
  end;

  function DoFillVRect: Boolean; inline;
  begin
    Result := (Mode and GRADIENT_FILL_RECT_V) = GRADIENT_FILL_RECT_V;
  end;

  function VertexToColor(AVertex: tagTRIVERTEX): TQColor;
  var
    TheAlpha: Byte;
  begin
    TheAlpha := AVertex.Alpha shr 8;
    if TheAlpha = 0 then
      TheAlpha := 255;
    with AVertex do
      QColor_fromRgb(@Result, Red shr 8, Green shr 8, Blue shr 8, TheAlpha);
  end;

  function FillTriMesh(Mesh: tagGradientTriangle) : Boolean;
  var
    V1, V2, V3: tagTRIVERTEX;
    C1, C2, C3: TQColor;
    Grad: QConicalGradientH;
    Brush: QBrushH;
    Triangle: QPolygonH;
    R: TRect;
    Painter: QPainterH;
    Rgn: QRegionH;
  begin
    with Mesh do
    begin
      Result :=
        (Vertex1 < Cardinal(NumVertices)) and
        (Vertex2 < Cardinal(NumVertices)) and
        (Vertex3 < Cardinal(NumVertices));

      if (Vertex1 = Vertex2) or
        (Vertex1 = Vertex3) or
        (Vertex2 = Vertex3) or not Result then
        Exit;

      V1 := Vertices[Vertex1];
      V2 := Vertices[Vertex2];
      V3 := Vertices[Vertex3];

      Painter := TQtDeviceContext(DC).Widget;
      QPainter_save(Painter);
      Triangle := QPolygon_create(3);
      QPolygon_setPoint(Triangle, 0, V1.X, V1.Y);
      QPolygon_setPoint(Triangle, 1, V2.X, V2.Y);
      QPolygon_setPoint(Triangle, 2, V3.X, V3.Y);
      QPolygon_boundingRect(Triangle, @R);

      Dec(R.Bottom);
      Dec(R.Right);

      Rgn := QRegion_create(@R);

      // make our poly clip region , so gradient center is at real center
      QPainter_setClipRegion(Painter, Rgn, QtIntersectClip);

      Grad := QConicalGradient_create(R.Right div 2, R.Bottom div 2, 90);
      C1 := VertexToColor(V1);
      C2 := VertexToColor(V2);
      C3 := VertexToColor(V3);

      QGradient_setColorAt(Grad, 0.0, @C1); // open
      QGradient_setColorAt(Grad, 0.33, @C2); // left corner
      QGradient_setColorAt(Grad, 0.66, @C3); // right corner
      QGradient_setColorAt(Grad, 1.0, @C1); // close


      Brush := QBrush_create(Grad);
      QPainter_setPen(Painter, QtNoPen);
      QPainter_setBrush(Painter, Brush);

      // move center point down, so we remove reflections of C2 and C3
      // TODO: C1 reflection is still visible
      QPainter_setBrushOrigin(Painter, 0, R.Bottom div 5);
      QPainter_drawPolygon(Painter, Triangle);

      //TODO: now me must make it look "softer" because reflection look of
      // first color is ugly.

      QBrush_destroy(Brush);
      QPolygon_destroy(Triangle);
      QGradient_destroy(Grad);
      QRegion_destroy(Rgn);
      QPainter_restore(Painter);

    end;
  end;

  function FillRectMesh(Mesh: tagGradientRect) : boolean;
  var
    TL,BR: tagTRIVERTEX;
    StartColor, EndColor, SwapColor: TQColor;
    Swap: Longint;
    SwapColors: Boolean;
    Grad: QGradientH;
    Brush: QBrushH;
  begin
    with Mesh do
    begin
      Result :=
        (UpperLeft < Cardinal(NumVertices)) and
        (LowerRight < Cardinal(NumVertices));
      if (LowerRight = UpperLeft) or not Result then
        Exit;

      TL := Vertices[UpperLeft];
      BR := Vertices[LowerRight];
      SwapColors := (BR.Y < TL.Y) and (BR.X < TL.X);
      if BR.X < TL.X then
      begin
        Swap := BR.X;
        BR.X := TL.X;
        TL.X := Swap;
      end;
      if BR.Y < TL.Y then
      begin
        Swap := BR.Y;
        BR.Y := TL.Y;
        TL.Y := Swap;
      end;
      StartColor := VertexToColor(TL);
      EndColor := VertexToColor(BR);
      if SwapColors then
      begin
        SwapColor := StartColor;
        StartColor := EndColor;
        EndColor := SwapColor;
      end;
      if DoFillVRect then
        Grad := QLinearGradient_create(TL.X, TL.Y, TL.X, BR.Y)
      else
        Grad := QLinearGradient_create(TL.X, TL.Y, BR.X, TL.Y);
      QGradient_setColorAt(Grad, 0, @StartColor);
      QGradient_setColorAt(Grad, 1, @EndColor);
      Brush := QBrush_create(Grad);
      TQtDeviceContext(DC).fillRect(TL.X, TL.Y, BR.X - TL.X, BR.Y - TL.Y, Brush);
      QGradient_destroy(Grad);
      QBrush_destroy(Brush);
    end;
  end;

const
  MeshSize: Array[Boolean] of Integer = (
    SizeOf(tagGradientRect), SizeOf(tagGradientTriangle));
var
  i : Integer;
begin
  {$ifdef VerboseQtWinAPI}
    WriteLn('***** [WinAPI TQtWidgetSet.GradientFill] ');
  {$endif}

  //Currently Alpha blending is ignored... Ideas anyone?
  Result := (Meshes <> nil) and (NumMeshes >= 1) and (NumVertices >= 2)
            and (Vertices <> nil);
  if Result and DoFillTriangle then
    Result := NumVertices >= 3;
  if Result then
  begin
    Result := False;

    //Sanity Checks For Vertices Size vs. Count
    if MemSize(Vertices) < PtrUInt(SizeOf(tagTRIVERTEX)*NumVertices) then
      exit;

    //Sanity Checks For Meshes Size vs. Count
    if MemSize(Meshes) < PtrUInt(MeshSize[DoFillTriangle]*NumMeshes) then
      exit;

    for I := 0 to NumMeshes - 1 do
    begin
      if DoFillTriangle then
      begin
        if not FillTriMesh(PGradientTriangle(Meshes)[I]) then
          exit;
      end
      else
      begin
        if not FillRectMesh(PGradientRect(Meshes)[I]) then
          exit;
      end;
    end;
    Result := True;
  end;
end;

function TQtWidgetSet.HideCaret(hWnd: HWND): Boolean;
begin
  Result := (hWnd <> 0) and QtCaret.HideCaret(TQtWidget(hWnd));
end;

{------------------------------------------------------------------------------
  Procedure: InitializeCriticalSection
  Params: var CritSection: TCriticalSection
  Returns:
 ------------------------------------------------------------------------------}
procedure TQtWidgetSet.InitializeCriticalSection(var CritSection: TCriticalSection);
var
  ACritSec: System.PRTLCriticalSection;
begin
  New(ACritSec);
  System.InitCriticalSection(ACritSec^);
  CritSection:=TCriticalSection(ACritSec);
end;

function TQtWidgetSet.InitStockFont(AFont: TObject; AStockFont: TStockFont
  ): Boolean;
var
  Font: TFont absolute AFont;
  AMenu: QMenuH;
  QtFont: QFontH;
  AName: WideString;
begin
  Result := False;
  if AStockFont = sfMenu then
  begin
    AName := 'MenuTitle';
    AMenu := QMenu_create(@AName, nil);
    try
      QtFont := QWidget_font(AMenu);
      QFont_family(QtFont, @AName);
      Font.Name := AName{%H-};
      {$ifdef darwin}
      // issue #34625
      if QFont_pointSize(QtFont) > 0 then
        Font.Height := -Round(QFont_pointSizeF(QtFont))
      else
        Font.Height := QFont_pixelSize(QtFont);
      {$else}
      if QFont_pointSize(QtFont) > 0 then
        Font.Size := QFont_pointSize(QtFont)
      else
        Font.Height := QFont_pixelSize(QtFont);
      {$endif}
      if QFont_bold(QtFont) then
        Font.Style := Font.Style + [fsBold];
      if QFont_italic(QtFont) then
        Font.Style := Font.Style + [fsItalic];
      if QFont_underline(QtFont) then
        Font.Style := Font.Style + [fsUnderline];
      if QFont_strikeOut(QtFont) then
        Font.Style := Font.Style + [fsStrikeOut];
      Font.Color := clMenuText;
      Result := True;
    finally
      QWidget_destroy(AMenu);
    end;
  end else
  begin
    QtFont := QFont_create;
    try
      if AStockFont = sfHint then
        QToolTip_font(QtFont)
      else
        QApplication_font(QtFont);
      QFont_family(QtFont, @AName);
      Font.Name := AName{%H-};
      {$ifdef darwin}
      // issue #34625
      if QFont_pointSize(QtFont) > 0 then
        Font.Height := -Round(QFont_pointSizeF(QtFont))
      else
        Font.Height := QFont_pixelSize(QtFont);
      {$else}
      if QFont_pointSize(QtFont) > 0 then
        Font.Size := QFont_pointSize(QtFont)
      else
        Font.Height := QFont_pixelSize(QtFont);
      {$endif}
      if QFont_bold(QtFont) then
        Font.Style := Font.Style + [fsBold];
      if QFont_italic(QtFont) then
        Font.Style := Font.Style + [fsItalic];
      if QFont_underline(QtFont) then
        Font.Style := Font.Style + [fsUnderline];
      if QFont_strikeOut(QtFont) then
        Font.Style := Font.Style + [fsStrikeOut];

      {comment font.color for check if hintfont works correct}
      if AStockFont = sfHint then
        Font.Color := clInfoText;

      Result := True;
    finally
      QFont_destroy(QtFont);
    end;
  end;
end;

function TQtWidgetSet.IntersectClipRect(dc: hdc; Left, Top, Right, Bottom: Integer): Integer;
var
  QtDC: TQtDeviceContext absolute dc;
  IntersectRgn, Rgn: QRegionH;
begin
  {$ifdef VerboseQtWinAPI}
    WriteLn('[WinAPI TQtWidgetSet.IntersectClipRect] L ',Left,' T ',Top,' R ',Right,' B ',Bottom);
  {$endif}
  Result := ERROR;
  if not IsValidDC(DC) then exit;

  IntersectRgn := QRegion_create(Left, Top, Right - Left, Bottom - Top);
  try
    if QtDC.getClipping then
    begin
      Rgn := QRegion_create;
      try
        QPainter_clipRegion(QtDC.Widget, Rgn);
        if QRegion_isEmpty(Rgn) then
          QtDC.setClipRegion(IntersectRgn)
        else
          QtDC.setClipRegion(IntersectRgn, QtIntersectClip);
        QtDC.setClipping(True);
        // recreate Rgn
        QRegion_destroy(Rgn);
        Rgn := QRegion_create;
        QPainter_clipRegion(QtDC.Widget, Rgn);
        Result := QtDC.GetRegionType(Rgn);
      finally
        QRegion_destroy(Rgn);
      end;
    end else
    begin
      QtDC.setClipRegion(InterSectRgn);
      QtDC.setClipping(True);
      Result := QtDC.GetRegionType(InterSectRgn);
    end;
  finally
    QRegion_destroy(IntersectRgn);
  end;
end;

function TQtWidgetSet.IsIconic(Handle: HWND): boolean;
begin
  Result := False;
  if IsValidHandle(Handle) then
    Result := TQtWidget(Handle).isMinimized;
end;

function TQtWidgetSet.IsWindow(handle: HWND): boolean;
begin
  Result := IsValidHandle(Handle);
end;

function TQtWidgetSet.IsWindowEnabled(Handle: HWND): boolean;
begin
  Result := False;
  if IsValidHandle(Handle) then
    Result := TQtWidget(Handle).getEnabled and TQtWidget(Handle).getVisible;
end;

function TQtWidgetSet.IsWindowVisible(Handle: HWND): boolean;
begin
  Result := False;
  if IsValidHandle(Handle) then
    Result := TQtWidget(Handle).getVisible;
end;

function TQtWidgetSet.IsZoomed(Handle: HWND): boolean;
begin
  Result := False;
  if IsValidHandle(Handle) then
    Result := TQtWidget(Handle).isMaximized;
end;

{------------------------------------------------------------------------------
  Function: InvalidateRect
  Params: aHandle:
          Rect:
          bErase:
  Returns:

 ------------------------------------------------------------------------------}
function TQtWidgetSet.InvalidateRect(aHandle: HWND; Rect: pRect; bErase: Boolean): Boolean;
var
  Pt: TPoint;
begin
  {$ifdef VerboseQtWinAPI}
    WriteLn('[WinAPI InvalidateRect]');
  {$endif}
  if AHandle = 0 then
    exit(False);
  if Rect <> nil then
  begin
    with TQtWidget(aHandle).getClientOffset do
      OffsetRect(Rect^, x, y);

    {$IFDEF QTSCROLLABLEFORMS}
    if (TQtWidget(AHandle) is TQtMainWindow) and Assigned(TQtMainWindow(AHandle).ScrollArea) then
    begin
      Pt := TQtMainWindow(AHandle).ScrollArea.ScrolledOffset;
      OffsetRect(Rect^, -Pt.X, -Pt.Y);
    end else
    {$ENDIF}
    if TQtWidget(AHandle).ChildOfComplexWidget = ccwScrollingWinControl then
    begin
      Pt := TQtCustomControl(AHandle).viewport.ScrolledOffset;
      OffsetRect(Rect^, -Pt.X, -Pt.Y);
    end;

    // no need to handle bErase. Qt automatically erase rect on paint event according to docs
    TQtWidget(aHandle).Update(Rect);
  end else
    TQtWidget(aHandle).Update;

  Result := True;
end;

{------------------------------------------------------------------------------
  Function: InvalidateRgn
  Params: aHandle:
          Rect:
          bErase:
  Returns: True if invalidate is successfull.
  Invalidates region of widget.
 ------------------------------------------------------------------------------}
function TQtWidgetSet.InvalidateRgn(aHandle: HWND; Rgn: HRGN; Erase: Boolean): Boolean;
begin
  {$ifdef VerboseQtWinAPI}
    WriteLn('[WinAPI InvalidateRgn]');
  {$endif}
  if aHandle = 0 then
    exit(False);
  if IsValidGDIObject(Rgn) and (TQtRegion(Rgn).FHandle <> nil) then
    TQtWidget(aHandle).UpdateRegion(TQtRegion(Rgn).FHandle)
  else
    TQtWidget(aHandle).Update;
  Result := True;
end;

{------------------------------------------------------------------------------
  Procedure: LeaveCriticalSection
  Params:  var CritSection: TCriticalSection
  Returns: Nothing
 ------------------------------------------------------------------------------}
procedure TQtWidgetSet.LeaveCriticalSection(var CritSection: TCriticalSection);
var
  ACritSec: System.PRTLCriticalSection;
begin
  ACritSec:=System.PRTLCriticalSection(CritSection);
  System.LeaveCriticalsection(ACritSec^);
end;

{------------------------------------------------------------------------------
  Function: LineTo
  Params:  none
  Returns: Nothing


 ------------------------------------------------------------------------------}
function TQtWidgetSet.LineTo(DC: HDC; X, Y: Integer): Boolean;
var
  PenPos, LastPos: TPoint;
begin
  {$ifdef VerboseQtWinAPI}
    WriteLn('[WinAPI LineTo]');
  {$endif}

  Result := False;

  if not IsValidDC(DC) then Exit;

  TQtDeviceContext(DC).getPenPos(@PenPos);
  LastPos := Point(X, Y);
  if TQtDeviceContext(DC).pen.getCosmetic then
    LastPos := TQtDeviceContext(DC).GetLineLastPixelPos(PenPos, LastPos);
  TQtDeviceContext(DC).drawLine(PenPos.X, PenPos.Y, LastPos.X, LastPos.Y);
  MoveToEx(DC, X, Y, nil);

  Result := True;
end;

function TQtWidgetSet.LPtoDP(DC: HDC; var Points; Count: Integer): BOOL;
var
  P: PPoint;
  QtPoint: TQtPoint;
  Matrix: QTransformH;
  QtDC: TQtDeviceContext;
begin
  Result := False;

  if not IsValidDC(DC) then
    Exit;

  QtDC := TQtDeviceContext(DC);

  Matrix := QPainter_transform(QtDC.Widget);
  P := @Points;
  while Count > 0 do
  begin
    Dec(Count);
    QtPoint.X := P^.X;
    QtPoint.Y := P^.Y;
    QTransform_map(Matrix, PQtPoint(@QtPoint), PQtPoint(@QtPoint));
    P^.X := QtPoint.X;
    P^.Y := QtPoint.Y;
    Inc(P);
  end;

  Result := True;
end;

function TQtWidgetSet.MessageBox(hWnd: HWND; lpText, lpCaption: PChar; uType: Cardinal): integer;
const
  ButtonToQtButton: array[1..4] of QMessageBoxStandardButton = (
   QMessageBoxOk, QMessageBoxYes, QMessageBoxNo, QMessageBoxCancel);


  function IconToMessageType(AType: cardinal): QMessageBoxIcon;
  begin
    case AType of
      1: Result := QMessageBoxCritical; // MB_ICONERROR = $00000010;
      2: Result := QMessageBoxQuestion; // MB_ICONQUESTION = $00000020;
      3: Result := QMessageBoxWarning; // MB_ICONWARNING = $00000030;
      4: Result := QMessageBoxInformation; // MB_ICONINFORMATION = $00000040;
      else Result := QMessageBoxNoIcon;
    end;
  end;

  function ButtonToQtButtons(AType: cardinal): QMessageBoxStandardButtons;
  begin
    Result := QMessageBoxNoButton;
    case AType of
      0: Result := QMessageBoxOk;
      1: Result := QMessageBoxOk or QMessageBoxCancel;
      2: Result := QMessageBoxAbort or QMessageBoxRetry or QMessageBoxIgnore;
      3: Result := QMessageBoxYes or QMessageBoxNo or QMessageBoxCancel;
      4: Result := QMessageBoxYes or QMessageBoxNo;
      5: Result := QMessageBoxRetry or QMessageBoxCancel;
      6: Result := QMessageBoxCancel or QMessageBoxRetry or QMessageBoxApply; // not supported by lcl
      else
      begin
        DebugLn(Format('WARNING: TQtWidgetSet.MessageBox() invalid message box type %d',[AType]));
      end;
    end;
  end;

  function ButtonToQtDefButton(AType: cardinal; ADefButton: cardinal): QMessageBoxStandardButton;
  begin
    Result := QMessageBoxNoButton;
    case AType of
      0: Result := QMessageBoxOk;
      1:
      begin
        if ADefButton = 2 then
          Result := QMessageBoxCancel
        else
          Result := QMessageBoxOk;
      end;
      2:
      begin
        if ADefButton = 3 then
          Result := QMessageBoxIgnore
        else
        if ADefButton = 2 then
          Result := QMessageBoxRetry
        else
          Result := QMessageBoxAbort;
      end;
      3:
      begin
        if ADefButton = 3 then
          Result := QMessageBoxCancel
        else
        if ADefButton = 2 then
          Result := QMessageBoxNo
        else
          Result := QMessageBoxYes;
      end;
      4:
      begin
        if ADefButton = 2 then
          Result := QMessageBoxNo
        else
          Result := QMessageBoxYes;
      end;
      5:
      begin
        if ADefButton = 2 then
          Result := QMessageBoxCancel
        else
          Result := QMessageBoxRetry;
      end;
      6:
      begin
        if ADefButton = 3 then
          Result := QMessageBoxCancel
        else
        if ADefButton = 2 then
          Result := QMessageBoxRetry
        else
          Result := QMessageBoxApply;
      end;
      else
        DebugLn(Format('WARNING: TQtWidgetSet.MessageBox() invalid message box type %d',[AType]));
    end;
  end;

  function QtButtonToResult(AResult: integer): integer;
  begin
    Result := 0;
    case AResult of
      QMessageBoxOk, QMessageBoxApply: Result := ID_OK;
      QMessageBoxCancel: Result := ID_CANCEL;
      QMessageBoxAbort: Result := ID_ABORT;
      QMessageBoxRetry: Result := ID_RETRY;
      QMessageBoxIgnore: Result := ID_IGNORE;
      QMessageBoxYes: Result := ID_YES;
      QMessageBoxNo: Result := ID_NO;
      QMessageBoxClose: Result := ID_CLOSE;
      QMessageBoxHelp: Result := ID_HELP;
    end;
  end;
var
  Str: WideString;
  TitleStr: WideString;
  //OkStr: WideString;
  AParent: QWidgetH;
  DialogType, DefButton, DefIcon : Cardinal;
begin
  Result := 0;
  Str := lpText;
  TitleStr := lpCaption;
  //TODO: TRANSLATIONS for buttons text, use TQtMessageBox
  if HWND <> 0 then
    AParent := TQtWidget(Hwnd).Widget
  else
    AParent := nil;
  DefButton:= ((uType and $00000300) shr 8) + 1;
  DialogType:= (uType and $0000000F);
  DefIcon := (uType and $000000FF) shr 4;


  case IconToMessageType(DefIcon) of
    QMessageBoxInformation: Result := QMessageBox_information(AParent, @TitleStr, @Str, ButtonToQtButtons(DialogType), ButtonToQtDefButton(DialogType, DefButton));
    QMessageBoxQuestion: Result := QMessageBox_question(AParent, @TitleStr, @Str, ButtonToQtButtons(DialogType), ButtonToQtDefButton(DialogType, DefButton));
    QMessageBoxCritical: Result := QMessageBox_critical(AParent, @TitleStr, @Str, ButtonToQtButtons(DialogType), ButtonToQtDefButton(DialogType, DefButton));
    QMessageBoxWarning: Result := QMessageBox_warning(AParent, @TitleStr, @Str, ButtonToQtButtons(DialogType), ButtonToQtDefButton(DialogType, DefButton));
    else
    begin
      DebugLn('WARNING: TQtWidgetSet.MessageBox() unspecified dialog type.');
      Result := QMessageBox_information(AParent, @Str, @TitleStr, ButtonToQtButtons(DialogType), ButtonToQtButton[DefButton]);
    end;
  end;
  Result := QtButtonToResult(Result);
end;

function TQtWidgetSet.MonitorFromPoint(ptScreenCoords: TPoint; dwFlags: DWord
  ): HMONITOR;
var
  AQtPoint: TQtPoint;
  Monitor: Integer;
begin
  Result := MONITOR_UNIMPL;
  AQtPoint := QtPoint(ptScreenCoords.x, ptScreenCoords.y);
  Monitor := QDesktopWidget_screenNumber(QApplication_desktop(), PQtPoint(@AQtPoint));
  if (Monitor >= 0) then
    Result := HMONITOR(Monitor + 1);
end;

function TQtWidgetSet.MonitorFromRect(lprcScreenCoords: PRect; dwFlags: DWord
  ): HMONITOR;
var
  AQtPoint: TQtPoint;
  Monitor: Integer;
begin
  Result := MONITOR_UNIMPL;
  Monitor := -1;
  if lprcScreenCoords <> nil then
  begin
    AQtPoint := QtPoint(lprcScreenCoords^.Left, lprcScreenCoords^.Top);
    Monitor := QDesktopWidget_screenNumber(QApplication_desktop(), PQtPoint(@AQtPoint));
  end;
  if (Monitor >= 0) then
    Result := HMONITOR(Monitor + 1);
end;

function TQtWidgetSet.MonitorFromWindow(hWnd: HWND; dwFlags: DWord): HMONITOR;
var
  Monitor: Integer;
begin
  Result := MONITOR_UNIMPL;
  Monitor := -1;
  if (hwnd > 0) and IsValidHandle(hWnd) then
    Monitor := QDesktopWidget_screenNumber(QApplication_desktop(), TQtWidget(hWnd).Widget);
  if (Monitor >= 0) then
    Result := HMONITOR(Monitor + 1);
end;

{------------------------------------------------------------------------------
  Function: MoveToEx
  Params:  none
  Returns: Nothing


 ------------------------------------------------------------------------------}
function TQtWidgetSet.MoveToEx(DC: HDC; X, Y: Integer; OldPoint: PPoint): Boolean;
begin
  {$ifdef VerboseQtWinAPI}
    WriteLn('[WinAPI MoveToEx]',
     ' DC:', dbghex(DC),
     ' X:', dbgs(X),
     ' Y:', dbgs(Y));
  {$endif}

  Result := False;

  if not IsValidDC(DC) then Exit;

  if (OldPoint <> nil) then TQtDeviceContext(DC).getPenPos(OldPoint);

  TQtDeviceContext(DC).setPenPos(X, Y);

  Result := True;
end;

function TQtWidgetSet.OffsetRgn(RGN: HRGN; nXOffset, nYOffset: Integer): Integer;
var
  QtRgn: QRegionH;
begin
  Result := ERROR;

  if not IsValidGDIObject(RGN) then
    Exit
  else
    QtRgn := TQtRegion(RGN).FHandle;

  QRegion_translate(QtRgn, nXOffset, nYOffset);

  if QRegion_isEmpty(QtRgn) then
    Result := NULLREGION
  else
  begin
    if TQtRegion(RGN).IsPolyRegion or (TQtRegion(RGN).numRects > 0) then
      Result := COMPLEXREGION
    else
      Result := SIMPLEREGION;
  end;
end;

function TQtWidgetSet.PaintRgn(DC: HDC; RGN: HRGN): Boolean;
var
  APath: QPainterPathH;
begin
  Result := False;
  if not IsValidDC(DC) or not IsValidGDIObject(RGN) then
    exit;
  if TQtRegion(RGN).FHandle = nil then
    exit;
  APath := QPainterPath_create;
  QPainterPath_addRegion(APath, TQtRegion(RGN).FHandle);
  QPainterPath_closeSubpath(APath);
  QPainter_fillPath(TQtDeviceContext(DC).Widget, APath, QPainter_brush(TQtDeviceContext(DC).Widget));
  QPainterPath_destroy(APath);
  Result := True;
end;

function TQtWidgetSet.PeekMessage(var lpMsg : TMsg; Handle : HWND; wMsgFilterMin, wMsgFilterMax,wRemoveMsg : UINT): Boolean;
begin
  Result := False;
  {$ifdef VerboseQtWinAPI_MISSING_IMPLEMENTATION}
    WriteLn('***** [WinAPI TQtWidgetSet.PeekMessage] missing implementation ');
  {$endif}
end;

{------------------------------------------------------------------------------
  Function: PolyBezier
  Params:  DC: HDC; Points: PPoint; NumPts: Integer; Filled: Boolean;
           Continuous: Boolean
  Returns: Nothing
 ------------------------------------------------------------------------------}
function TQtWidgetSet.PolyBezier(DC: HDC; Points: PPoint; NumPts: Integer;
  Filled, Continuous: boolean): boolean;
begin
  {$ifdef VerboseQtWinAPI}
    WriteLn('[WinAPI PolyBezier] DC: ', dbghex(DC));
  {$endif}
  Result := inherited PolyBezier(DC, Points, NumPts, Filled, Continuous);
end;

{------------------------------------------------------------------------------
  Function: Polygon
  Params:  DC: HDC; Points: PPoint; NumPts: Integer; Winding: Boolean
  Returns: Nothing
 ------------------------------------------------------------------------------}
function TQtWidgetSet.Polygon(DC: HDC; Points: PPoint; NumPts: Integer;
  Winding: boolean): boolean;
var
  QtPoints: PQtPoint;
  i: integer;
begin
  {$ifdef VerboseQtWinAPI}
    WriteLn('[WinAPI Polygon] DC: ', dbghex(DC));
  {$endif}
  Result := IsValidDC(DC);
  if Result then
  begin
    GetMem(QtPoints, NumPts * SizeOf(TQtPoint));
    for i := 0 to NumPts - 1 do
      QtPoints[i] := QtPoint(Points[i].x, Points[i].y);
    if Winding then
      QPainter_drawPolygon(TQtDeviceContext(DC).Widget, QtPoints, NumPts, QtWindingFill)
    else
      QPainter_drawPolygon(TQtDeviceContext(DC).Widget, QtPoints, NumPts, QtOddEvenFill);
    FreeMem(QtPoints);
  end;
end;

{------------------------------------------------------------------------------
  Function: Polyline
  Params:  DC: HDC; Points: PPoint; NumPts: Integer
  Returns: Nothing
 ------------------------------------------------------------------------------}
function TQtWidgetSet.Polyline(DC: HDC; Points: PPoint; NumPts: Integer): boolean;
begin
  {$ifdef VerboseQtWinAPI}
    WriteLn('[WinAPI Polyline] DC: ', dbghex(DC));
  {$endif}
  Result := IsValidDC(DC) and (NumPts > 0);
  if Result then
    TQtDeviceContext(DC).DrawPolyLine(Points, NumPts);
end;

function TQtWidgetSet.PostMessage(Handle: HWND; Msg: Cardinal; wParam: WParam; lParam: LParam): Boolean;
var
  Widget: TQtWidget absolute Handle;
  Event: QLCLMessageEventH;
begin
  Result := False;
  if Handle <> 0 then
  begin
    Event := QLCLMessageEvent_create(QEventLCLMessage, Msg, wParam, lParam, 0);
    QCoreApplication_postEvent(Widget.Widget, Event, 1 {high priority});
    Result := True;
  end;
end;

function TQtWidgetSet.PtInRegion(RGN: HRGN; X, Y: Integer): Boolean;
begin
  Result := False;

  if not IsValidGDIObject(RGN) then
    exit;
  if not (TObject(RGN) is TQtRegion) then
    Result := False
  else
    Result := TQtRegion(RGN).containsPoint(X, Y);
end;

{------------------------------------------------------------------------------
  Function: Rectangle
  Params:  DC: HDC; X1, Y1, X2, Y2: Integer
  Returns: Nothing

  The Rectangle function draws a rectangle. The rectangle is outlined by using
  the current pen and filled by using the current brush.
 ------------------------------------------------------------------------------}
function TQtWidgetSet.Rectangle(DC: HDC; X1, Y1, X2, Y2: Integer): Boolean;
var
  R: TRect;
  B: Boolean;
begin
  {$ifdef VerboseQtWinAPI}
    WriteLn('[WinAPI Rectangle] DC: ', dbghex(DC));
  {$endif}

  if not IsValidDC(DC) then Exit(False);

  R := NormalizeRect(Rect(X1, Y1, X2, Y2));
  if IsRectEmpty(R) then Exit(True);
  // issue http://bugs.freepascal.org/view.php?id=25227
  B := (QtVersionMajor = 4) and (QtVersionMinor = 8) and
    (QPaintEngine_type(TQtDeviceContext(DC).PaintEngine) = QPaintEngineRaster) and
    QPen_isCosmetic(QPainter_pen(TQtDeviceContext(DC).Widget));

  TQtDeviceContext(DC).drawRect(R.Left, R.Top, R.Right - R.Left - 1, R.Bottom - R.Top - 1, B);
  Result := True;
end;

function TQtWidgetSet.RectVisible(dc : hdc; const ARect: TRect) : Boolean;
var
  QtDC: TQtDeviceContext;
begin
  {$ifdef VerboseQtWinAPI}
  writeln('[WinAPI RectVisible] ');
  {$endif}
  Result := False;
  if not IsValidDC(DC) then Exit;
  QtDC := TQtDeviceContext(DC);
  // as MSDN says only clipping region can play here
  if QtDC.getClipping then
    Result := QtDC.getClipRegion.containsRect(ARect);
end;

{------------------------------------------------------------------------------
  Function: RedrawWindow
  Params: Wnd:
          lprcUpdate:
          hrgnUpdate:
          flags:
  Returns:

 ------------------------------------------------------------------------------}
function TQtWidgetSet.RedrawWindow(Wnd: HWND; lprcUpdate: PRECT; hrgnUpdate: HRGN; flags: UINT): Boolean;
var
  QtWidget: TQtWidget;
  Region: TQtRegion;
begin
  if not IsValidHandle(Wnd) then
    Exit(False);

  QtWidget := TQtWidget(Wnd);
  if IsValidGDIObject(hrgnUpdate) then
    Region := TQtRegion(hrgnUpdate)
  else
    Region := nil;
  if (lprcUpdate = nil) and (hrgnUpdate = 0) then
  begin
    QtWidget.Update(nil);
    Exit(True);
  end;

  if Region = nil then
    Result := InvalidateRect(Wnd, lprcUpdate, False)
  else
    QtWidget.UpdateRegion(Region.FHandle);

  Result := True;
end;

function TQtWidgetSet.ReleaseCapture: Boolean;
var
  w: TQtWidget;
begin
  w := TQtWidget(GetCapture);
  Result := w <> nil;
  if Result then
  begin
    {$IFDEF MSWINDOWS}
    if (w is TQtMainWindow) then
      w.releaseMouse()
    else
      windows.ReleaseCapture;
    {$ELSE}
    w.releaseMouse();
    {$ENDIF}
  end;
  {$ifdef VerboseQtWinAPI}
  WriteLn('[WinAPI ReleaseCapture] Capture = ', THandle(w));
  {$endif}
end;

{------------------------------------------------------------------------------
  Function: ReleaseDC
  Params:     hWnd:       Handle to the window whose DC is to be released.
              hDC:        Handle to the DC to be released.
  Returns:
 ------------------------------------------------------------------------------}
function TQtWidgetSet.ReleaseDC(hWnd: HWND; DC: HDC): Integer;
begin
  {$ifdef VerboseQtWinAPI}
    WriteLn('[WinAPI ReleaseDC]',
     ' hWnd: ', dbghex(hWnd),
     ' DC: ', dbghex(DC));
  {$endif}

  Result := 0;

  if IsValidDC(DC) then
  begin
    if TQtDeviceContext(DC).UserDC then
      TQtDeviceContext(DC).Free;
    Exit;
  end;

  Result := 1;
end;


{------------------------------------------------------------------------------
  Function: RestoreDC: Restore a previously saved DC state
  Params:
    DC: Handle to a DeviceContext
    SavedDC: Index of saved state that needs to be restored
  Returns: True if state was successfuly restored.
-------------------------------------------------------------------------------}
function TQtWidgetSet.RestoreDC(DC: HDC; SavedDC: Integer): Boolean;
var
  DCData: PQtDCData;
begin
  {$ifdef VerboseQTWinAPI}
  WriteLn('Trace:> [WinAPI RestoreDC] DC=', dbghex(DC),' SavedDC=',SavedDC);
  {$Endif}
  // if SavedDC is positive, it represents the wished saved dc instance
  // if SavedDC is negative, it's a relative number from last pushed state
  Result := False;
  if SavedDCList=nil then
  begin
    {$ifdef VerboseQTWinAPI}
    WriteLn('Trace:< [WinAPI RestoreDC] there is no List yet, result=', result);
    {$Endif}
    exit;
  end;

  if SavedDC < 0 then
    SavedDC := SavedDC + SavedDCList.Count;

  // check index
  Result := (SavedDC > 0) and (SavedDC < SavedDCList.Count);
  if Result then
  begin
    Result := true;
    while SavedDC > 0 do
    begin
      DCData := PQtDcData(SavedDCList[SavedDC]);
      SavedDCList.Delete(SavedDC);
      Result := TQtDeviceContext(DC).RestoreDCData(DCData);
      Dec(SavedDC);
    end;
  end;
  {$ifdef VerboseQTWinAPI}
  WriteLn('Trace:< [WinAPI RestoreDC]');
  {$Endif}
end;

function TQtWidgetSet.RoundRect(DC: hDC; X1, Y1, X2, Y2: Integer; RX,RY : Integer): Boolean;
begin
  Result := False;
  if not IsValidDC(DC) then
  begin
    {$ifdef VerboseQTWinAPI}
    WriteLn('Trace:< [WinAPI RoundRect] DC Invalid, result=', result);
    {$Endif}
    Exit;
  end;
  Result := inherited RoundRect(DC, X1, Y1, X2, Y2, RX, RY);
end;
{------------------------------------------------------------------------------
  Function: SaveDC: save DC state information to a stack
  Params:  DC
  Returns: The index assigned to the or 0 if DC is not valid
-------------------------------------------------------------------------------}
function TQtWidgetSet.SaveDC(DC: HDC): Integer;
var
  DCData: PQtDCData;
begin
  {$ifdef VerboseQTWinAPI}
  WriteLn('Trace:> [WinAPI SaveDC] DC=', dbghex(DC));
  {$Endif}

  result:=0;

  if not IsValidDC(DC) then
  begin
    {$ifdef VerboseQTWinAPI}
    WriteLn('Trace:< [WinAPI SaveDC] DC Invalid, result=', result);
    {$Endif}
    exit;
  end;

  if SavedDCList=nil then
  begin
    SavedDCList := TFPList.Create;
    SavedDCList.Add(nil); // start at index 1, 0 is an invalid saved state
  end;

  DCData := TQtDeviceContext(DC).CreateDCData;
  Result := 1;
  SavedDCList.Insert(Result, DCData);

  {$ifdef VerboseQTWinAPI}
  WriteLn('Trace:< [WinAPI SaveDC] result=', Result);
  {$Endif}
end;

{------------------------------------------------------------------------------
  Function: ScreenToClient
  Params:  Handle: HWND; var P: TPoint
  Returns:
-------------------------------------------------------------------------------}
function TQtWidgetSet.ScreenToClient(Handle : HWND; var P : TPoint) : Integer;
begin
  Result := 0;
  if IsValidHandle(Handle) then
  begin
    P := TQtWidget(Handle).MapFromGlobal(P);
    Result := 1;
  end;
end;

{------------------------------------------------------------------------------
  Method:  ScrollWindowEx
  Params:  HWnd       - handle of window to scroll
           DX         - horizontal amount to scroll
           DY         - vertical amount to scroll
           PRcScroll  - pointer to scroll rectangle
           PRcClip    - pointer to clip rectangle
           HRgnUpdate - handle of update region
           PRcUpdate  - pointer to update rectangle
           Flags      - scrolling flags

  Returns: True if succesfull

  The ScrollWindowEx function scrolls the content of the specified window's
  client area
 ------------------------------------------------------------------------------}
function TQtWidgetSet.ScrollWindowEx(HWnd: HWND; DX, DY: Integer; PRcScroll,
  PRcClip: PRect; HRgnUpdate: HRGN; PRcUpdate: PRect; Flags: UINT): Boolean;
var
  R: TRect;
  W: TQtWidget;
begin
  Result := False;
  if (HWND = 0) then exit;

  W := TQtWidget(HWND);
  if ((Flags and SW_SCROLLCHILDREN) <> 0) then
  begin
    if Assigned(W.LCLObject) then {mantis #34589}
      W.WidgetState := W.WidgetState + [qtwsForceSendMove];

    W.scroll(dx, dy, nil);

    if Assigned(W.LCLObject) then {mantis #34589}
      W.WidgetState := W.WidgetState - [qtwsForceSendMove];
  end else
  if (PrcScroll = nil) then
  begin
    R := W.getClientBounds;
    W.scroll(dx, dy, @R);
  end
  else
    W.scroll(dx, dy, PRcScroll);

  if ((Flags and SW_INVALIDATE) <> 0) then
  begin
    if IsValidGDIObject(HRgnUpdate) then
    begin
      R := TQtRegion(HRgnUpdate).getBoundingRect;
      PRcUpdate := @R;
      W.Update(@R);
    end else
    if PRcClip <> nil then
    begin
      PRcUpdate := PRcClip;
      W.Update(PrcClip);
    end;
  end;

  Result := True;
end;

{------------------------------------------------------------------------------
  Function: SelectClipRGN
  Params:  DC, RGN
  Returns: longint

  Sets the DeviceContext's ClipRegion. The Return value
  is the new clip regions type, or ERROR.

  The result can be one of the following constants
      Error
      NullRegion
      SimpleRegion
      ComplexRegion

 ------------------------------------------------------------------------------}
function TQtWidgetSet.SelectClipRGN(DC: hDC; RGN: HRGN): Longint;
var
  QtDC: TQtDeviceContext;
  EmptyRegion: QRegionH;
  P: TPoint;
begin
  Result := ERROR;
  if IsValidDC(DC) then
  begin
    QtDC := TQtDeviceContext(DC);
    if IsValidGDIObject(RGN) then
    begin
      Result := TQtRegion(Rgn).GetRegionType;
      // RGN is in Device coordinates. Qt expects logical coordinates
      // so we need to convert RGN coords.
      GetWindowOrgEx(DC, @P);
      TQtRegion(Rgn).translate(P.X, P.Y);
      QtDC.setClipRegion(TQtRegion(Rgn).FHandle);
    end else
    begin
      EmptyRegion := QRegion_create;
      try
        QtDC.setClipRegion(EmptyRegion, QtNoClip);
      finally
        QRegion_destroy(EmptyRegion);
      end;
      Result := NULLREGION;
    end;
  end;
end;

{------------------------------------------------------------------------------
  Function: SelectObject
  Params:  none
  Returns: The GDI object of the same type previously associated with the DC

  Changes one of the GDI objects (Font, Brush, etc) of a Device Context;
 ------------------------------------------------------------------------------}
function TQtWidgetSet.SelectObject(DC: HDC; GDIObj: HGDIOBJ): HGDIOBJ;
var
  aObject: TObject;
  {$ifdef VerboseQtWinAPI}
    ObjType: string;
  {$endif}
begin
  {$ifdef VerboseQtWinAPI}
    WriteLn('Trace:> [WinAPI SelectObject]',
    ' DC=', dbghex(DC),
    ' GDIObj=', dbghex(GDIObj));
  {$endif}

  Result := 0;

  if not IsValidDC(DC) then
  begin
    {$ifdef VerboseQtWinAPI}
      WriteLn('Trace:< [WinAPI SelectObject] Invalid DC');
    {$endif}

    Exit;
  end;

  if not IsValidGDIObject(GDIObj) then
  begin
    {$ifdef VerboseQtWinAPI}
      WriteLn('Trace:< [WinAPI SelectObject] Invalid GDI Object');
    {$endif}

    Exit;
  end;

  aObject := TObject(GDIObj);

  if aObject is TQtFont then
  begin
    {$ifdef VerboseQtWinAPI}
      ObjType := 'Font';
    {$endif}

    Result := HGDIOBJ(TQtDeviceContext(DC).font);

    TQtDeviceContext(DC).setFont(TQtFont(aObject));
  end
  else if aObject is TQtPen then
  begin
    {$ifdef VerboseQtWinAPI}
      ObjType := 'Pen'      ;
    {$endif}
    result := HGDIOBJ(TQtDeviceContext(DC).pen);

    TQtDeviceContext(DC).setPen(TQtPen(aObject));
  end
  else if aObject is TQtBrush then
  begin
    {$ifdef VerboseQtWinAPI}
      ObjType := 'Brush';
    {$endif}

    Result := HGDIOBJ(TQtDeviceContext(DC).brush);

    TQtDeviceContext(DC).setBrush(TQtBrush(aObject));
  end
  else if aObject is TQtImage then
  begin
    {$ifdef VerboseQtWinAPI}
      ObjType := 'Image';
    {$endif}

    Result := HGDIOBJ(TQtDeviceContext(DC).vImage);

    // TODO: is this also saved in qpainter_save?
    TQtDeviceContext(DC).setImage(TQtImage(aObject));
  end else
  if AObject is TQtRegion then
  begin
    Result := HGDIOBJ(TQtDeviceContext(DC).getClipRegion);
    SelectClipRGN(DC, HRGN(GDIObj));
  end;

  {$ifdef VerboseQtWinAPI}
    WriteLn('Trace:< [WinAPI SelectObject] Result=', dbghex(Result), ' ObjectType=', ObjType);
  {$endif}
end;

function TQtWidgetSet.SendMessage(HandleWnd: HWND; Msg: Cardinal;
  WParam: WParam; LParam: LParam): LResult;
var
  Widget: TQtWidget absolute HandleWnd;
  Event: QLCLMessageEventH;
begin
  Result := 0;
  if (HandleWnd <> 0) and (Widget.Widget <> nil) then
  begin
    Event := QLCLMessageEvent_create(QEventLCLMessage, Msg, wParam, lParam, 0);
    try
      QCoreApplication_sendEvent(Widget.Widget, Event);
      Result := QLCLMessageEvent_getMsgResult(Event);
    finally
      QLCLMessageEvent_destroy(Event);
    end;
  end;
end;

function TQtWidgetSet.SetActiveWindow(Handle: HWND): HWND;
begin
  Result := GetActiveWindow;

  if Handle <> 0 then
    TQtWidget(Handle).Activate
  else
    Result := 0; // error
end;

{------------------------------------------------------------------------------
  Function: SetBKColor
  Params: X:
          Y:
  Returns:

 ------------------------------------------------------------------------------}
function TQtWidgetSet.SetBKColor(DC: HDC; Color: TColorRef): TColorRef;
begin
  {$ifdef VerboseQtWinAPI}
    WriteLn('Trace:> [WinAPI SetBkColor]',
     ' DC: ', dbghex(DC),
     ' Color: ', dbgs(Color));
  {$endif}

  Result := 0;

  if not IsValidDC(DC) then
  begin
    {$ifdef VerboseQtWinAPI}
      WriteLn('Trace:< [WinAPI SetBkColor] Invalid DC');
    {$endif}

    Exit;
  end;

  Result := TQtDeviceContext(DC).SetBkColor(TColorRef(Color));
end;

{------------------------------------------------------------------------------
  Method:  SetBkMode
  Params:  DC    -
  Returns:
 ------------------------------------------------------------------------------}
function TQtWidgetSet.SetBkMode(DC: HDC; bkMode: Integer): Integer;
begin
  {$ifdef VerboseQtWinAPI}
    WriteLn('Trace:> [WinAPI SetBkMode] DC=', dbghex(DC), ' BkMode=', dbgs(bkMode));
  {$endif}

  Result := 0;

  if not IsValidDC(DC) then
  begin
    {$ifdef VerboseQtWinAPI}
      WriteLn('Trace:< [WinAPI SetBkMode] Invalid DC');
    {$endif}

    Exit;
  end;

  Result := TQtDeviceContext(DC).SetBkMode(bkMode);
end;

function TQtWidgetSet.SetCapture(AHandle: HWND): HWND;
var
  Message: TLMessage;
begin
  Result := GetCapture;
  if Result <> AHandle then
  begin
    if Result <> 0 then
      ReleaseCapture;
    if IsValidHandle(AHandle) then
    begin
      {$IFDEF MSWINDOWS}
      if TQtWidget(AHandle) is TQtCustomControl then
      begin
        Windows.SetCapture(QWidget_winID(TQtCustomControl(AHandle).Viewport.Widget))
      end else
        Windows.SetCapture(QWidget_winID(TQtWidget(AHandle).Widget));
      {$ELSE}
      TQtWidget(AHandle).grabMouse();
      {$ENDIF}
    end;
    {$ifdef VerboseQtWinAPI}
      WriteLn('[WinAPI SetCapture] Capture = ', Result, ' New capture = ', AHandle);
    {$endif}
    if (Result <> 0) and IsValidHandle(AHandle) then
    begin
      Message.Msg := 0;
      FillChar(Message, SizeOf(Message), 0);
      Message.msg := LM_CAPTURECHANGED;
      Message.wParam := 0;
      Message.lParam := PtrInt(Result);
      LCLMessageGlue.DeliverMessage(TQtWidget(AHandle).LCLObject, Message);
    end;
  end;
end;

function TQtWidgetSet.SetCaretPos(X, Y: Integer): Boolean;
begin
  Result := QtCaret.SetCaretPos(X, Y);
end;

function TQtWidgetSet.SetCaretPosEx(Handle: HWnd; X, Y: Integer): Boolean;
begin
  Result := QtCaret.SetCaretPos(X, Y);
end;

function TQtWidgetSet.SetCaretRespondToFocus(handle: HWND;
  ShowHideOnFocus: boolean): Boolean;
begin
  Result := True;
  QtCaret.SetQtCaretRespondToFocus(ShowHideOnFocus);
end;

{------------------------------------------------------------------------------
  Function: SetCursor
  Params: ACursor - HCursor (TQtCursor)
  Returns:
       previous global cursor
 ------------------------------------------------------------------------------}
function TQtWidgetSet.SetCursor(ACursor: HCURSOR): HCURSOR;
begin
  Result := HCURSOR(OverrideCursor);

  if Result = ACursor then
    Exit;

  if Screen.Cursors[crDefault] = ACursor then
    OverrideCursor := nil
  else
    OverrideCursor := TQtCursor(ACursor);
end;

{------------------------------------------------------------------------------
  Function: SetCursorPos
  Params: X:
          Y:
  Returns:

 ------------------------------------------------------------------------------}
function TQtWidgetSet.SetCursorPos(X, Y: Integer): Boolean;
begin
  {$ifdef VerboseQtWinAPI}
    WriteLn('[WinAPI SetCursorPos]');
  {$endif}

  QCursor_setPos(X, Y);

  Result := True;
end;

{------------------------------------------------------------------------------
  Function: SetFocus
  Params: hWnd   - Window handle to be focused
  Returns:

 ------------------------------------------------------------------------------}
function TQtWidgetSet.SetFocus(hWnd: HWND): HWND;
var
  W: TQtWidget;
begin
  Result := 0;
  if hwnd<>0 then
  begin
    {$ifdef VerboseFocus}
    WriteLn('*********  TQtWidgetSet.SetFocus INIT focusing ', TQtWidget(hwnd).lclobject.name);
    {$endif}
    Result := GetFocus;
    W := TQtWidget(HWND).getWindow;
    if (W <> nil) and W.getVisible and not W.IsActiveWindow and
      not TQtMainWindow(W).Blocked then
        W.Activate;
    TQtWidget(hWnd).setFocus;
    {$ifdef VerboseFocus}
    DebugLn('********* TQtWidgetSet.SetFocus END was %x now is %x %s %d',[result,hwnd,dbgsName(TQtWidget(hWnd).LCLObject), GetTickCount]);
    {$endif}
  end;
end;

function TQtWidgetSet.GetForegroundWindow: HWND;
begin
  {$IFDEF HASX11}
  {$note this should return current system active window, not
    application one, if our app isn''t active.
    This is per MSDN and pretty win32 specific}
  if WindowManagerName = 'metacity' then
    Result := HwndFromWidgetH(X11GetActivewindow)
  else
    Result := GetActiveWindow;
  {$ELSE}
  Result := GetActiveWindow;
  {$ENDIF}
end;

function TQtWidgetSet.SetForegroundWindow(HWnd: HWND): boolean;
begin
  Result := False;
  if HWND <> 0 then
  begin
    Result := TQtWidget(HWND).IsActiveWindow;
    TQtWidget(HWnd).Activate;
  end;
end;

function TQtWidgetSet.SetMenu(AWindowHandle: HWND; AMenuHandle: HMENU): Boolean;
var
  AWidget, AMenuWidget: TQtWidget;
  QtMainWindow: TQtMainWindow absolute AWidget;
  QtMenuBar: TQtMenuBar absolute AMenuWidget;
  R, R1: TRect;
begin
  AWidget := TQtWidget(AWindowHandle);
  Result := AWidget is TQtMainWindow;
  if Result then
  begin
    AMenuWidget := TQtWidget(AMenuHandle);
    if AMenuWidget is TQtMenuBar then
    begin
      R := AWidget.LCLObject.ClientRect;
      R1 := QtMainWindow.MenuBar.getGeometry;
      R1.Right := R.Right;
      QtMenuBar.setGeometry(R1);
      QtMainWindow.setMenuBar(QMenuBarH(QtMenuBar.Widget));
    end
    else
      QtMainWindow.setMenuBar(QMenuBarH(QtMainWindow.MenuBar.Widget));
  end;
end;

function TQtWidgetSet.SetParent(hWndChild: HWND; hWndParent: HWND): HWND;
var
  OldVisible: Boolean;
  Flags: QtWindowFlags;
  W: TQtWidget;
begin
  {$ifdef VerboseQtWinAPI}
  writeln('[WinApi SetParent] child: ',dbgHex(PtrUInt(hwndChild)),
    ' parent: ',dbgHex(PtrUInt(hWndParent)));
  {$endif}
  Result := 0;
  if not IsValidHandle(hwndChild) then
    exit;
  Result := GetParent(hWndChild);
  if (Result = hwndParent) then
    exit;
  W := TQtWidget(hWndChild);
  OldVisible := W.getVisible;
  Flags := W.windowFlags;
  if IsValidHandle(hWndParent) then
    W.setParent(TQtWidget(hWndParent).GetContainerWidget)
  else
  begin
    W.setParent(nil);
    W.setWindowFlags(Flags);
  end;
  W.setVisible(OldVisible);
end;

function TQtWidgetSet.SetMapMode(DC: HDC; fnMapMode : Integer): Integer;
var
  AWindowExt: TPoint;
  R: TRect;
begin
  if IsValidDC(DC) then
  begin
    if fnMapMode <> TQtDeviceContext(DC).vMapMode then
    begin
      AWindowExt := Point(0, 0);
      case fnMapMode of
        MM_ANISOTROPIC:; // user's choice
        MM_ISOTROPIC:; // adjusted after each SetViewPortExtEx call (see MSDN for details)
        MM_HIENGLISH: AWindowExt := Point(1000, -1000);
        MM_HIMETRIC: AWindowExt := Point(2540, -2540);
        MM_LOENGLISH: AWindowExt := Point(100, -100);
        MM_LOMETRIC: AWindowExt := Point(254, -254);
        MM_TWIPS: AWindowExt := Point(1440, -1440);
      else
        fnMapMode := MM_TEXT;
      end;
      TQtDeviceContext(DC).vMapMode := fnMapMode;
      QPainter_setViewTransformEnabled(TQtDeviceContext(DC).Widget, fnMapMode <> MM_TEXT);
      if not (fnMapMode in [MM_TEXT, MM_ANISOTROPIC, MM_ISOTROPIC]) then
      begin
        QPainter_Window(TQtDeviceContext(DC).Widget, @R);
        R.BottomRight := AWindowExt;
        QPainter_setWindow(TQtDeviceContext(DC).Widget, @R);
        QPainter_ViewPort(TQtDeviceContext(DC).Widget, @R);
        R.Right := QtWidgetSet.GetDeviceCaps(DC, LOGPIXELSX);
        R.Bottom := QtWidgetSet.GetDeviceCaps(DC, LOGPIXELSX);
        QPainter_setViewPort(TQtDeviceContext(DC).Widget, @R);
      end;
    end;
    Result := Integer(True);
  end else
    Result := Integer(False);
end;

function TQtWidgetSet.SetViewPortExtEx(DC: HDC; XExtent, YExtent : Integer; OldSize: PSize): Boolean;
var
  R, RW: TRect;
  Ratio: Single;
begin
  Result := False;
  if IsValidDC(DC) then
  begin
    QPainter_ViewPort(TQtDeviceContext(DC).Widget, @R);
    if OldSize <> nil then
    begin
      OldSize^.cx := R.Right - R.Left;
      OldSize^.cy := R.Bottom - R.Top;
    end;
    if (XExtent <> R.Right) or (YExtent <> R.Bottom) then
    begin
      case TQtDeviceContext(DC).vMapMode of
        MM_ANISOTROPIC, MM_ISOTROPIC:
        begin
          if TQtDeviceContext(DC).vMapMode = MM_ISOTROPIC then
          begin
            // TK: Is here also an adjustment on Windows if DPIX and DPIY are different?
            QPainter_Window(TQtDeviceContext(DC).Widget, @RW);
            Ratio := RW.Right / RW.Bottom; // no check, programmer cannot put nonsense
            if YExtent * Ratio > XExtent then
              YExtent := RoundToInt(XExtent / Ratio)
            else if YExtent * Ratio < XExtent then
              XExtent := RoundToInt(YExtent * Ratio)
          end;
          QPainter_setViewPort(TQtDeviceContext(DC).Widget, R.Left, R.Top, XExtent, YExtent);
          Result := True;
        end;
      end;
    end;
  end;
end;

function TQtWidgetSet.SetViewPortOrgEx(DC: HDC; NewX, NewY: Integer; OldPoint: PPoint): Boolean;
var
  R: TRect;
begin
  Result := False;
  if IsValidDC(DC) then
  begin
    QPainter_ViewPort(TQtDeviceContext(DC).Widget, @R);
    if OldPoint <> nil then
      OldPoint^ := R.TopLeft;
    if (TQtDeviceContext(DC).vMapMode <> MM_TEXT) and (NewX <> R.Left) or (NewY <> R.Top) then
    begin
      QPainter_setViewPort(TQtDeviceContext(DC).Widget, NewX, NewY, R.Right - R.Left, R.Bottom - R.Top);
      Result := True;
    end;
  end;
end;

function TQtWidgetSet.SetWindowExtEx(DC: HDC; XExtent, YExtent: Integer; OldSize: PSize): Boolean;
var
  R: TRect;
begin
  Result := False;
  if IsValidDC(DC) then
  begin
    QPainter_Window(TQtDeviceContext(DC).Widget, @R);
    if OldSize <> nil then
    begin
      OldSize^.cx := R.Right - R.Left;
      OldSize^.cy := R.Bottom - R.Top;
    end;
    if (XExtent <> R.Right) or (YExtent <> R.Bottom) then
    begin
      case TQtDeviceContext(DC).vMapMode of
        MM_ANISOTROPIC, MM_ISOTROPIC:
        begin
          QPainter_setWindow(TQtDeviceContext(DC).Widget, R.Left, R.Top, XExtent, YExtent);
          Result := True;
        end;
      end;
    end;
  end;
end;

{------------------------------------------------------------------------------
  Method:  SetWindowOrgEx
  Params:  DC    - handle of device context
           NewX  - new x-coordinate of window origin
           NewY  - new y-coordinate of window origin
           Point - record receiving original origin
  Returns: Whether the call was successful

  Sets the window origin of the device context by using the specified coordinates.
 ------------------------------------------------------------------------------}
function TQtWidgetSet.SetWindowOrgEx(DC : HDC; NewX, NewY : Integer; OldPoint: PPoint) : Boolean;
var
  P: TPoint;
begin
  {$ifdef VerboseQtWinAPI}
    WriteLn('[WinAPI SetWindowOrgEx] DC: ', dbghex(DC), ' NewX: ', dbgs(NewX), ' NewY: ', dbgs(NewY));
  {$endif}

  Result := False;

  if IsValidDC(DC) then
  begin
    GetWindowOrgEx(DC, @P);
    // restore 0, 0
    if (P.X <> 0) or (P.Y <> 0) then
      TQtDeviceContext(DC).translate(P.X, P.Y);
    if OldPoint <> nil then
      OldPoint^ := P;
    TQtDeviceContext(DC).translate(-NewX, -NewY);
    Result := True;
  end;
end;

{------------------------------------------------------------------------------
  Method:  SetWindowPos
  Params: HWnd            - handle of window
          HWndInsertAfter - placement-order handle
          X               - horizontal position
          Y               - vertical position
          CX              - width
          CY              - height
          UFlags          - window-positioning flags
  Returns: If the function succeeds

  Changes the size, position, and Z order of a child, pop-up, or top-level
  window.
 ------------------------------------------------------------------------------}
function TQtWidgetSet.SetWindowPos(hWnd: HWND; hWndInsertAfter: HWND; X, Y, cx,
  cy: Integer; uFlags: UINT): Boolean;
var
  DisableUpdates: boolean;
begin
  {$ifdef VerboseQtWinAPI}
    WriteLn('[WinAPI SetWindowPos] Handle: ', dbghex(hWnd),
      ' hWndInsertAfter: ',dbghex(hWnd));
  {$endif}
  Result := hWnd <> 0;
  if not Result then
    exit;

  DisableUpdates := (SWP_NOREDRAW and uFlags) <> 0;
  if DisableUpdates then
    TQtWidget(Hwnd).setUpdatesEnabled(False);
  try
    if (SWP_NOMOVE and uFlags) = 0 then
      TQtWidget(Hwnd).move(X, Y);

    if (SWP_NOSIZE and uFlags) = 0 then
      TQtWidget(Hwnd).resize(CX, CY);

    if (SWP_SHOWWINDOW and uFlags) <> 0 then
      TQtWidget(Hwnd).Show;

    if (SWP_HIDEWINDOW and uFlags) <> 0 then
      TQtWidget(Hwnd).Hide;

    if (SWP_NOZORDER and uFlags) = 0 then
    begin
      case hWndInsertAfter of
        HWND_TOP:
          begin
            TQtWidget(hWnd).raiseWidget;
            if (SWP_NOACTIVATE and uFlags) = 0 then
              TQtWidget(hWnd).Activate;
          end;
        HWND_BOTTOM: TQtWidget(hWnd).lowerWidget;
        {TODO: HWND_TOPMOST ,HWND_NOTOPMOST}
      end;
    end;
  finally
    if DisableUpdates then
      TQtWidget(Hwnd).setUpdatesEnabled(True);
  end;
end;

{------------------------------------------------------------------------------
  Method:  SetWindowRgn
  Params:  hWnd    - handle of the widget
           hRgn    - handle of the region
           bRedraw - ?
  Returns: 0 if the call failed, any other value if it was successful

  Makes the region specifyed in hRgn be the only part of the window which is
  visible.
 ------------------------------------------------------------------------------}
function TQtWidgetSet.SetWindowRgn(hWnd: HWND;
 hRgn: HRGN; bRedraw: Boolean):longint;
var
  w: TQtWidget;
  r: TQtRegion;
begin
  Result := 0;

  {$ifdef VerboseQtWinAPI}
    WriteLn('[WinAPI SetWindowRgn] Handle: ', dbghex(hWnd));
  {$endif}

  // Basic checks
  if (hWnd = 0) or (hRgn = 0) then Exit;

  w := TQtWidget(hWnd);
  r := TQtRegion(hRgn);

  // Now set the mask in the widget
  w.setMask(r.FHandle);

  Result := 1;
end;

function TQtWidgetSet.ShowCaret(hWnd: HWND): Boolean;
begin
  Result := (hWnd <> 0) and (QtCaret.ShowCaret(TQtWidget(hWnd)));
end;

{------------------------------------------------------------------------------
  Method:  SetProp
  Params:  Handle -
  Returns:
 ------------------------------------------------------------------------------}
function TQtWidgetSet.SetProp(Handle: hwnd; Str: PChar; Data: Pointer): Boolean;
begin
  if Handle<>0 then
  begin
    TQtWidget(Handle).Props[str] := Data;
    Result := (TQtWidget(Handle).Props[str]=Data);
    {$ifdef VerboseQtWinApi}
    DebugLn('[WinAPI SetProp win=%s str=%s data=%x',[dbgsname(TQtWidget(Handle)), str, ptrint(data)]);
    {$endif}
  end else
    Result := False;
end;

{------------------------------------------------------------------------------
  Function: SetROP2
  Params:  HDC, Raster OP mode
  Returns: Old Raster OP mode

  Please note that the bitwise raster operation modes, denoted with a
  RasterOp prefix, are only natively supported in the X11 and
  raster paint engines.
  This means that the only way to utilize these modes on the Mac is
  via a QImage.
  The RasterOp denoted blend modes are not supported for pens and brushes
  with alpha components. Also, turning on the QPainter::Antialiasing render
  hint will effectively disable the RasterOp modes.
 ------------------------------------------------------------------------------}
function TQtWidgetSet.SetROP2(DC: HDC; Mode: Integer): Integer;
var
  QtDC: TQtDeviceContext absolute DC;
begin
  {$ifdef VerboseQtWinAPI}
  writeln('TQtWidgetSet.SetROP2() DC ',dbghex(DC),' Mode ',Mode);
  {$endif}
  Result := R2_COPYPEN;
  if not IsValidDC(DC) then
    exit;
  Result := QtDC.Rop2;
  QtDC.Rop2 := Mode;
end;

{------------------------------------------------------------------------------
  Function: SetScrollInfo
  Params:  none
  Returns: The new position value

 ------------------------------------------------------------------------------}
function TQtWidgetSet.SetScrollInfo(Handle : HWND; SBStyle : Integer;
  ScrollInfo: TScrollInfo; bRedraw : Boolean): Integer;
var
  Control: TWinControl;
  ScrollBar: TQtScrollBar;

  function UpdateScrollInfo: Integer;
  var
    iReCountMax: Integer;
    i: Integer;
    WheelLines: Integer;
  begin
    Scrollbar.BeginUpdate;

    Result := 0;

    if (ScrollInfo.FMask and SIF_RANGE) <> 0 then
    begin
      ScrollBar.setMinimum(ScrollInfo.nMin);

      // we must recount ScrollBar.Max since invalid value raises AV
      iRecountMax := ScrollInfo.nMax - Integer(ScrollInfo.nPage);
      if iRecountMax < ScrollInfo.nMin then
        iRecountMax := ScrollInfo.nMin;

      ScrollBar.setMaximum(iRecountMax);
    end;

    if (ScrollInfo.FMask and SIF_PAGE) <> 0 then
    begin
      // segfaults if we don't check Enabled property
      if ScrollBar.getEnabled then
      begin
        ScrollBar.setPageStep(Integer(ScrollInfo.nPage));
        WheelLines := QApplication_wheelScrollLines();
        with Scrollbar do
        begin
          i := Max(1, floor((GetPageStep / WheelLines) / 6));
          setSingleStep(i);
        end;
      end;
    end;

    if (ScrollInfo.FMask and SIF_UPDATEPOLICY) <> 0 then
      ScrollBar.setTracking(ScrollInfo.nTrackPos <> SB_POLICY_DISCONTINUOUS);

    if (ScrollInfo.FMask and SIF_POS) <> 0 then
    begin
      if not (ScrollBar.getTracking and ScrollBar.getSliderDown) then
      begin
        if (ScrollInfo.nPos < ScrollBar.getMin) then
          ScrollInfo.nPos := ScrollBar.getMin
        else
        if (ScrollInfo.nPos > ScrollBar.getMax) then
          ScrollInfo.nPos := ScrollBar.getMax;

        {related issues for setting pos are #16255, #19687 and #22187.
         Do not use ScrollBar.setValue here.}
        if (ScrollBar.getSliderPosition <> ScrollInfo.nPos) then
          ScrollBar.setSliderPosition(ScrollInfo.nPos);
        // setValue(ScrollInfo.nPos);
      end;
    end;

    if (ScrollInfo.FMask and SIF_TRACKPOS) <> 0 then
    begin
      ScrollBar.TrackPos := ScrollInfo.nTrackPos;
      // from MSDN: the SetScrollInfo function ignores this member
      // ScrollBar.setSliderPosition(ScrollInfo.nTrackPos);
    end;

    Result := ScrollBar.getSliderPosition;

    ScrollBar.EndUpdate;
  end;

begin
  // bRedraw is useles with qt

  Result := 0;

  if (Handle = 0) then exit;

  ScrollBar := nil;
  case SBStyle of
    SB_BOTH:
    begin
      {TODO: SB_BOTH fixme }
      //writeln('TODO: ############## SB_BOTH CALLED HERE .... #################');
    end; {SB_BOTH}

    SB_CTL:
    begin
      {HWND is always TScrollBar, but seem that Create ScrollBar should be called here }
      if (csReading in TQtWidget(Handle).LCLObject.ComponentState) or
      (csDestroying in TQtWidget(Handle).LCLObject.ComponentState) then exit;

      ScrollBar := TQtScrollBar(Handle);

      if not Assigned(ScrollBar) then exit;
    end; {SB_CTL}

    SB_HORZ:
    begin
      if (csReading in TQtWidget(Handle).LCLObject.ComponentState) or
         (csDestroying in TQtWidget(Handle).LCLObject.ComponentState) then
        exit;

      {$IFDEF QTSCROLLABLEFORMS}
      if (TQtWidget(Handle) is TQtMainWindow) then
      begin
        if Assigned(TQtMainWindow(Handle).ScrollArea) then
          Scrollbar := TQtMainWindow(Handle).ScrollArea.horizontalScrollBar
        else
          Scrollbar := nil;
      end else
      {$ENDIF}
      if TQtWidget(Handle) is TQtAbstractScrollArea then
      begin
        ScrollBar := TQtAbstractScrollArea(Handle).horizontalScrollBar;
      end else
      begin
        {do not localize !}
        Control := TWinControl(TQtWidget(Handle).LCLObject.FindChildControl(TQtWidget(Handle).LCLObject.Name+'_HSCROLLBAR'));
        if (Control <> nil) and (Control.HandleAllocated) then
          ScrollBar := TQtScrollBar(Control.Handle)
      end;
    end; {SB_HORZ}

    SB_VERT:
    begin
      if (csReading in TQtWidget(Handle).LCLObject.ComponentState) or
        (csDestroying in TQtWidget(Handle).LCLObject.ComponentState) then
        exit;

      {$IFDEF QTSCROLLABLEFORMS}
      if (TQtWidget(Handle) is TQtMainWindow) then
      begin
        if Assigned(TQtMainWindow(Handle).ScrollArea) then
          Scrollbar := TQtMainWindow(Handle).ScrollArea.verticalScrollBar
        else
          Scrollbar := nil;
      end else
      {$ENDIF}
      if TQtWidget(Handle) is TQtAbstractScrollArea then
      begin
        ScrollBar := TQtAbstractScrollArea(Handle).verticalScrollBar;
      end else
      begin
        {do not localize !}
        Control := TWinControl(TQtWidget(Handle).LCLObject.FindChildControl(TQtWidget(Handle).LCLObject.Name+'_VSCROLLBAR'));
        if (Control <> nil) and (Control.HandleAllocated) then
          ScrollBar := TQtScrollBar(Control.Handle)
      end;
    end; {SB_VERT}

  end;

  if Assigned(ScrollBar) then
    Result := UpdateScrollInfo;
end;

{------------------------------------------------------------------------------
  Method:  SetTextColor
  Params:  Handle -
  Returns:
 ------------------------------------------------------------------------------}
function TQtWidgetSet.SetTextColor(DC: HDC; Color: TColorRef): TColorRef;
begin
  {$ifdef VerboseQtWinAPI}
    WriteLn('[WinAPI SetTextColor] DC: ', dbghex(DC));
  {$endif}
  Result := CLR_INVALID;
  if not IsValidDC(DC) then begin
    {$ifdef VerboseQtWinAPI}
    WriteLn('[WinAPI SetTextColor] Invalid DC');
    {$endif}
    exit;
  end;
  Result := TQtDeviceContext(DC).vTextColor;
  TQtDeviceContext(DC).vTextColor := ColorToRGB(TColor(Color)); // be sure we get TColorRef
end;

{------------------------------------------------------------------------------
  function ShowScrollBar(Handle: HWND; wBar: Integer; bShow: Boolean): Boolean;
  Params  Handle: HWND; wBar: Integer; bShow: Boolean
  Result
------------------------------------------------------------------------------}
function TQtWidgetSet.ShowScrollBar(Handle: HWND; wBar: Integer; bShow: Boolean): Boolean;
var
  w: TQtWidget;
  ScrollArea: TQtAbstractScrollArea;
begin
  {$ifdef VerboseQtWinAPI}
    WriteLn('[WinAPI ShowScrollBar] Handle: ', dbghex(Handle),' wBar: ',wBar);
  {$endif}

  Result := (Handle <> 0);

  if not Result then exit;

  w := TQtWidget(Handle);

  {$IFDEF QTSCROLLABLEFORMS}
  if (w is TQtMainWindow) and Assigned(TQtMainWindow(w).ScrollArea) then
    w := TQtMainWindow(Handle).ScrollArea;
  {$ENDIF}
  if w is TQtAbstractScrollArea then
  begin
    ScrollArea := TQtAbstractScrollArea(w);
    case wBar of
      SB_BOTH:
      begin
        if bShow then
          ScrollArea.setScrollStyle(ssBoth)
        else
          ScrollArea.setScrollStyle(ssNone);
      end;

      SB_HORZ:
      begin
        if bShow then
          ScrollArea.setScrollStyle(ssHorizontal)
        else
          ScrollArea.ScrollBarPolicy[False] := QtScrollBarAlwaysOff;
      end;

      SB_VERT:
      begin
        if bShow then
          ScrollArea.setScrollStyle(ssVertical)
        else
          ScrollArea.ScrollBarPolicy[True] := QtScrollBarAlwaysOff;
      end;

      SB_CTL:
      begin
        if bShow then
          ScrollArea.Show
        else
          ScrollArea.Hide;
      end;
    end;

  end else
    Result := False;
end;

{------------------------------------------------------------------------------
  function ShowWindow(hWnd: HWND; nCmdShow: Integer): Boolean;

  nCmdShow:
    SW_SHOWNORMAL, SW_MINIMIZE, SW_SHOWMAXIMIZED
------------------------------------------------------------------------------}
function TQtWidgetSet.ShowWindow(hWnd: HWND; nCmdShow: Integer): Boolean;
var
  Widget: TQtWidget;
begin
  {$ifdef VerboseQtWinAPI}
  WriteLn('[WinAPI ShowWindow] hwnd ',dbgHex(PtrUInt(hWnd)),' nCmdShow ',nCmdShow);
  {$endif}

  Result := False;

  Widget := TQtWidget(hWnd);

  if Widget <> nil then
  begin
    case nCmdShow of
      SW_SHOW: Widget.setVisible(True);
      SW_SHOWNORMAL: Widget.ShowNormal;
      SW_MINIMIZE: Widget.setWindowState(QtWindowMinimized);
      SW_SHOWMINIMIZED: Widget.ShowMinimized;
      SW_SHOWMAXIMIZED: Widget.ShowMaximized;
      SW_SHOWFULLSCREEN: Widget.ShowFullScreen;
      SW_HIDE: Widget.setVisible(False);
    end;
    {$IFDEF HASX11}
    if (nCmdShow <> SW_HIDE) and (Widget is TQtMainWindow)
      and not TQtMainWindow(Widget).IsMdiChild
      and not TQtMainWindow(Widget).IsMainForm
      and not TQtMainWindow(Widget).ShowOnTaskBar then
        SetSkipX11Taskbar(Widget.Widget, True);
    {$ENDIF}
    if (Byte(nCmdShow) in [SW_SHOW, SW_SHOWNORMAL, SW_SHOWMAXIMIZED, SW_SHOWFULLSCREEN]) and
      (Widget is TQtMainWindow) then
        TQtMainWindow(Widget).Activate;
    Result := True;
  end;
end;

{------------------------------------------------------------------------------
  Function: StretchBlt
  Params:  DestDC:                The destination devicecontext
           X, Y:                  The left/top corner of the destination rectangle
           Width, Height:         The size of the destination rectangle
           SrcDC:                 The source devicecontext
           XSrc, YSrc:            The left/top corner of the source rectangle
           SrcWidth, SrcHeight:   The size of the source rectangle
           ROp:                   The raster operation to be performed
  Returns: True if succesful

  The StretchBlt function copies a bitmap from a source rectangle into a
  destination rectangle using the specified raster operation. If needed it
  resizes the bitmap to fit the dimensions of the destination rectangle.
  Sizing is done according to the stretching mode currently set in the
  destination device context.
  If SrcDC contains a mask the pixmap will be copied with this transparency.
 ------------------------------------------------------------------------------}
function TQtWidgetSet.StretchBlt(DestDC: HDC; X, Y, Width, Height: Integer;
  SrcDC: HDC; XSrc, YSrc, SrcWidth, SrcHeight: Integer; ROp: Cardinal): Boolean;
begin
  Result := StretchMaskBlt(DestDC,X,Y,Width,Height,
                          SrcDC,XSrc,YSrc,SrcWidth,SrcHeight,
                          0,0,0,
                          ROp);
end;

{------------------------------------------------------------------------------
  Function: StretchMaskBlt
  Params:  DestDC:                The destination devicecontext
           X, Y:                  The left/top corner of the destination rectangle
           Width, Height:         The size of the destination rectangle
           SrcDC:                 The source devicecontext
           XSrc, YSrc:            The left/top corner of the source rectangle
           SrcWidth, SrcHeight:   The size of the source rectangle
           Mask:                  The handle of a monochrome bitmap
           XMask, YMask:          The left/top corner of the mask rectangle
           ROp:                   The raster operation to be performed
  Returns: True if succesful

  The StretchMaskBlt function copies a bitmap from a source rectangle into a
  destination rectangle using the specified mask and raster operation. If needed
  it resizes the bitmap to fit the dimensions of the destination rectangle.
  Sizing is done according to the stretching mode currently set in the
  destination device context.
 ------------------------------------------------------------------------------}
function TQtWidgetSet.StretchMaskBlt(DestDC: HDC; X, Y, Width, Height: Integer;
  SrcDC: HDC; XSrc, YSrc, SrcWidth, SrcHeight: Integer; Mask: HBITMAP;
  XMask, YMask: Integer; Rop: DWORD): Boolean;
var
  SrcQDC: TQtDeviceContext absolute SrcDC;
  DstQDC: TQtDeviceContext absolute DestDC;
  SrcRect, DstRect, MaskRect: TRect;
  Image, TmpImage, QMask, TmpMask: QImageH;
  TmpPixmap: QPixmapH;
  SrcMatrix: QTransformH;
  dx, dy: integer;
  OldRop: Integer;
  OldBkColor: TColorRef;
  RestoreClip: Boolean;
  AClipRect: TRect;
  AWidgetID: LongWord;

  function NeedScaling(const ADstRect, ASrcRect: TRect): boolean;
  var
    R: TRect;
    TgtW, TgtH,
    ClpW, ClpH: integer;
  begin
    if not DstQDC.getClipping then
      exit((Width <> SrcWidth) or (Height <> SrcHeight));

    R := DstQDC.getClipRegion.getBoundingRect;

    TgtW := ADstRect.Right - ADstRect.Left;
    TgtH := ADstRect.Bottom - ADstRect.Top;
    ClpW := R.Right - R.Left;
    ClpH := R.Bottom - R.Top;

    Result := PtInRect(R, Point(R.Left + 1, R.Top + 1)) and
      (((ClpW <= TgtW) and (ClpH <= TgtH)) or ((TgtW < SrcWidth) and (TgtH < SrcHeight)));
  end;

  procedure RenderPixmap(APixmap: QPixmapH; AMaskImg: QImageH; const AHighQuality: boolean);
  var
    ATempPixmap: QPixmapH;
    ABitmap: QBitmapH;
    AMaskPix, AScaledPix: QPixmapH;
    ARenderHints: QPainterRenderHints;
    ARenderHint: Boolean;
  begin
    ATempPixmap := QPixmap_create();

    ARenderHints := QPainter_renderHints(DstQDC.Widget);
    ARenderHint := (AHighQuality and not EqualRect(DstRect, SrcRect)) and
      ((ARenderHints and QPainterAntialiasing <> 0) or (ARenderHints and QPainterSmoothPixmapTransform <> 0) or
       (ARenderHints and QPainterHighQualityAntialiasing <> 0));

    if ARenderHint and (ARenderHints and QPainterSmoothPixmapTransform <> 0) then
      ARenderHint := False; // do not touch render hints

    if NeedScaling(DstRect, SrcRect) then
      QPixmap_scaled(APixmap, ATempPixmap, Width, Height)
    else
      QPixmap_copy(APixmap, ATempPixmap, 0, 0, QPixmap_width(APixmap), QPixmap_height(APixmap));


    if AMaskImg <> nil then
    begin
      // apply mask to pixmap
      AScaledPix := QPixmap_create();
      AMaskPix := QPixmap_create();
      QPixmap_fromImage(AMaskPix, AMaskImg);
      try
        if IsRectEmpty(MaskRect) or (MaskRect.Size <> DstRect.Size) then
        begin
          if (QPixmap_width(ATempPixmap) < (DstRect.Right - DstRect.Left)) or
            (QPixmap_Height(ATempPixmap) < (DstRect.Bottom - DstRect.Top)) then
            QPixmap_scaled(AMaskPix, AScaledPix, QPixmap_width(ATempPixmap), QPixmap_height(ATempPixmap))
          else
            QPixmap_scaled(AMaskPix, AScaledPix, Width, Height);
        end else
        begin
          QPixmap_copy(AMaskPix, AScaledPix, MaskRect.Left, MaskRect.Top,
            MaskRect.Right - MaskRect.Left, MaskRect.Bottom - MaskRect.Top);
        end;

        ABitmap := QBitmap_Create(AScaledPix);

        QPixmap_setMask(ATempPixmap, ABitmap);
        QBitmap_Destroy(ABitmap);
        QPixmap_destroy(AScaledPix);
      finally
        QPixmap_destroy(AMaskPix);
      end;
    end;

    if ARenderHint then
      QPainter_setRenderHint(DstQDC.Widget, QPainterSmoothPixmapTransform, True);

    QPainter_drawPixmap(DstQDC.Widget, X, Y, Width, Height, ATempPixmap);

    if ARenderHint then
      QPainter_setRenderHint(DstQDC.Widget, QPainterSmoothPixmapTransform, not ARenderHint);

    QPixmap_destroy(ATempPixmap);
  end;

begin
  {$ifdef VerboseQtWinAPI}
    WriteLn('[WinAPI StretchMaskBlt]',
     ' DestDC:', dbghex(DestDC),
     ' SrcDC:', dbghex(SrcDC),
     ' Image:', dbghex(PtrInt(Image)),
     ' X:', dbgs(X), ' Y:', dbgs(Y),
     ' W:', dbgs(Width), ' H:', dbgs(Height),
     ' XSrc:', dbgs(XSrc), ' YSrc:', dbgs(YSrc),
     ' WSrc:', dbgs(SrcWidth), ' HSrc:', dbgs(SrcHeight),' Rop: ',dbgs(Rop));
  {$endif}

  Result := False;

  SrcMatrix := QPainter_transform(SrcQDC.Widget);

  QTransform_map(SrcMatrix, XSrc, YSrc, @XSrc, @YSrc);
  // our map can have some transformations
  if XSrc < 0 then // we cannot draw from negative coord, so we will draw from zero with shift
  begin
    dx := -XSrc;
    XSrc := 0;
  end
  else
    dx := 0;

  if YSrc < 0 then
  begin
    dy := -YSrc;
    YSrc := 0;
  end
  else
    dy := 0;

  if dx <> 0 then // apply shifts
  begin
    inc(X, dx);        // shift destination
    dec(Width, dx);    // substract width
    dec(SrcWidth, dx); // and do not forget about SrcWidth or we will get unneeded stretching
  end;

  if dy <> 0 then
  begin
    inc(Y, dy);
    dec(Height, dy);
    dec(SrcHeight, dy);
  end;

  DstRect := Bounds(X, Y, Width, Height);
  SrcRect := Bounds(XSrc, YSrc, SrcWidth, SrcHeight);
  MaskRect := Bounds(XMask, YMask, SrcWidth, SrcHeight);

  if Mask <> 0 then
    QMask := TQtImage(Mask).Handle
  else
    QMask := nil;

  if ((Rop = SRCCOPY) and (SrcQDC.vImage <> nil) and (SrcQDC.vImage.Handle <> nil))
    and not ((DstRect.Right < DstRect.Left) or (DstRect.Bottom < DstRect.Top)) then
  begin
    //issue #32137
    TmpImage := QImage_Create();
    QImage_copy(SrcQDC.vImage.Handle, TmpImage, XSrc, YSrc, SrcWidth, SrcHeight);

    // #11713, #25590
    if (QImage_format(TmpImage) = QImageFormat_RGB32) then
    begin
      Image := QImage_create();
      QImage_convertToFormat(TmpImage, Image, QImageFormat_ARGB32);
      QImage_destroy(TmpImage);
      TmpImage := QImage_create(Image);
      QImage_destroy(Image);
    end;

    TmpPixmap := QPixmap_create();
    QPixmap_fromImage(TmpPixmap, TmpImage);

    RenderPixmap(TmpPixmap, QMask,
      QImage_format(SrcQDC.vImage.Handle) = QImageFormat_ARGB32);
    QImage_destroy(TmpImage);
    QPixmap_destroy(TmpPixmap);
    exit(True);
  end else
  if SrcQDC.vImage = nil then
  begin
    if SrcQDC.Parent <> nil then
    begin
      AWidgetID := QWidget_winId(SrcQDC.Parent);

      if (Rop = SRCCOPY) and not ((DstRect.Right < DstRect.Left) or (DstRect.Bottom < DstRect.Top)) then
      begin
        TmpPixmap := QPixmap_create();
        QPixmap_grabWindow(TmpPixmap, AWidgetID, XSrc,  YSrc, SrcWidth, SrcHeight);
        RenderPixmap(TmpPixmap, QMask, QPixmap_hasAlphaChannel(TmpPixmap));
        QPixmap_destroy(TmpPixmap);
        exit(True);
      end else
      begin
        with SrcQDC.getDeviceSize do
          TmpPixmap := QPixmap_create(x, y);
        QPixmap_grabWindow(TmpPixmap, AWidgetID, 0, 0);
        Image := QImage_create();
        QPixmap_toImage(TmpPixmap, Image);
        QPixmap_destroy(TmpPixmap);
      end;
    end
    else
      Exit;
  end
  else
    Image := SrcQDC.vImage.Handle;

  if (DstRect.Right < DstRect.Left) or (DstRect.Bottom < DstRect.Top) then
  begin
    // Right < Left mean horizontal flip, Bottom < Top - vertical
    TmpImage := QImage_create();
    QImage_mirrored(Image, TmpImage, DstRect.Right < DstRect.Left, DstRect.Bottom < DstRect.Top);
    if QMask <> nil then
    begin
      TmpMask := QImage_create();
      QImage_mirrored(QMask, TmpMask, DstRect.Right < DstRect.Left, DstRect.Bottom < DstRect.Top);
    end
    else
      TmpMask := QMask;
    DstRect := NormalizeRect(DstRect);
    MaskRect := NormalizeRect(MaskRect);

    OldRop := DstQDC.Rop2;
    if Rop <> SRCCOPY then
      DstQDC.Rop2 := Integer(Rop);
    try
      DstQDC.drawImage(@DstRect, TmpImage, @SrcRect, TmpMask, @MaskRect);
    finally
      if Rop <> SRCCOPY then
        DstQDC.Rop2 := OldRop;
    end;

    QImage_destroy(TmpImage);
    if TmpMask <> nil then
      QImage_destroy(TmpMask);
  end else
  begin
    if (Rop = PATCOPY) then
    begin
      OldRop := DstQDC.Rop2;
      DstQDC.Rop2 := SRCCOPY;
      try
        DstQDC.setBrush(DstQDC.BackgroundBrush);
        with DstRect do
          DstQDC.fillRect(Left, Top, Right - Left, Bottom - Top);
      finally
        DstQDC.Rop2 := OldRop;
      end;
    end else
    if (Rop = BLACKNESS) or (Rop = WHITENESS) then
    begin
      OldRop := DstQDC.Rop2;
      DstQDC.Rop2 := SRCCOPY;
      try
        if (Rop = BLACKNESS) then
          OldBkColor := DstQDC.SetBkColor(clBlack)
        else
          OldBkColor := DstQDC.SetBkColor(clWhite);
        with DstRect do
          DstQDC.fillRect(Left, Top, Right - Left, Bottom - Top);
      finally
        DstQDC.SetBkColor(OldBkColor);
        DstQDC.Rop2 := OldRop;
      end;
    end else
    begin
      OldRop := DstQDC.Rop2;
      if Rop <> SRCCOPY then
        DstQDC.Rop2 := Integer(Rop);
      try
        RestoreClip := False;
        if ((SrcRect.Left < DstRect.Left) or (SrcRect.Top < DstRect.Top)) and
          DstQDC.getClipping and DstQDC.getClipRegion.containsRect(SrcRect) then
        begin
          AClipRect := DstQDC.getClipRegion.getBoundingRect;
          OffsetRect(AClipRect, -AClipRect.Left, -AClipRect.Top);

          if (DstRect.Right - DstRect.Left <= AClipRect.Right) and
            (DstRect.Bottom - DstRect.Top <= AClipRect.Bottom) and
            DstQDC.getClipRegion.containsPoint(DstRect.Left, DstRect.Top) then
          begin
            if (QPaintEngine_type(DstQDC.PaintEngine) = QPaintEngineRaster) then
            begin
              // issue #26744 - only affects raster engine.
              RestoreClip := ((DstRect.Left > 0) or (DstRect.Top > 0)) and
                (DstRect.Right - DstRect.Left - AClipRect.Right - AClipRect.Left = 0) and
                (DstRect.Bottom - DstRect.Top - AClipRect.Bottom - AClipRect.Top = 0);
            end else
              // issue #26342, unset clipping only when transform is dirty with non raster engine.
              RestoreClip := QPaintEngine_testDirty(DstQDC.PaintEngine, QPaintEngineDirtyTransform);
            if RestoreClip then
              DstQDC.setClipping(False);
          end;
        end;
        DstQDC.drawImage(@DstRect, Image, @SrcRect, QMask, @MaskRect);
        if RestoreClip then
          DstQDC.setClipping(True);
      finally
        if Rop <> SRCCOPY then
          DstQDC.Rop2 := OldRop;
      end;
    end;
  end;

  if SrcQDC.vImage = nil then
    QImage_destroy(Image);

  Result := True;
end;

{------------------------------------------------------------------------------
  Function: SystemParametersInfo
  Params: uiAction: System-wide parameter to be retrieved or set
          uiParam: Depends on the system parameter being queried or set
          pvParam: Depends on the system parameter being queried or set
          fWinIni:
  Returns: True if the function succeeds
  retrieves or sets the value of one of the system-wide parameters
 ------------------------------------------------------------------------------}
function TQtWidgetSet.SystemParametersInfo(uiAction: DWord; uiParam: DWord; pvParam: Pointer; fWinIni: DWord): LongBool;
var
  ADesktop: QDesktopWidgetH;
  AScreen: Integer;
  R: TRect;
begin
  case uiAction of
    SPI_GETWHEELSCROLLLINES: PDword(pvPAram)^ := QApplication_wheelScrollLines;
    SPI_GETWORKAREA:
    begin
      ADesktop := QApplication_desktop();
      AScreen := QDesktopWidget_primaryScreen(ADesktop);
      QDesktopWidget_availableGeometry(ADesktop, @R, AScreen);
      TRect(pvParam^) := R;
      Result:=True;
    end;
  else
    Result := False;
  end
end;

{------------------------------------------------------------------------------
  Function: TextOut
  Params: DC:
          X:
          Y:
          Str:
          Count:
  Returns:

 ------------------------------------------------------------------------------}
function TQtWidgetSet.TextOut(DC: HDC; X, Y: Integer; Str: Pchar; Count: Integer
  ): Boolean;
var
  WStr: WideString;
begin
  {$ifdef VerboseQtWinAPI}
    WriteLn('[WinAPI TextOut]');
  {$endif}

  Result := False;

  if not IsValidDC(DC) then Exit;

  if Count >= 0 then
    WStr := {%H-}Copy(Str, 1, Count)
  else
    WStr := Str;

  TQtDeviceContext(DC).drawText(X, Y, @WStr);

  Result := True;
end;

{------------------------------------------------------------------------------
  Method:  UpdateWindow
  Params:  Handle
  Returns:
 ------------------------------------------------------------------------------}
function TQtWidgetSet.UpdateWindow(Handle: HWND): Boolean;
begin
 {$ifdef VerboseQtWinAPI}
   WriteLn('[WinAPI UpdateWindow]');
 {$endif}
  Result := False;
  if Handle <> 0 then
  begin
    TQtWidget(Handle).Update;
    Result := True;
  end;
end;

{------------------------------------------------------------------------------
  Method:  WindowFromPoint
  Params:  TPoint
  Returns: The return value is a handle to the window that contains the param
  point.
  If no window exists at the given point, the return value is 0.
  If the point is over a static text control,
  the return value is a handle to the window under the static text control.
 ------------------------------------------------------------------------------}
function TQtWidgetSet.WindowFromPoint(APoint: TPoint): HWND;
var
  Widget: QWidgetH;
begin
  // we use cachedresults instead of calling very expensive widgetAt
  if (FLastWFPResult <> 0) then
  begin
    if not IsValidWidgetAtCachePointer then
      FLastWFPResult := 0
    else
    if (APoint.X = FLastWFPMousePos.X) and (APoint.Y = FLastWFPMousePos.Y) and
      TQtWidget(FLastWFPResult).getVisible and
      TQtWidget(FLastWFPResult).getEnabled then
    begin
      // return from cache
      exit(FLastWFPResult);
    end;
  end;

  Result := 0;
  Widget := QApplication_widgetAt(APoint.x, APoint.y);

  if (Widget = nil) then
  begin
    if (APoint.X = FLastWFPMousePos.X) and (APoint.Y = FLastWFPMousePos.Y) then
    begin
      FLastWFPMousePos := Point(MaxInt, MaxInt);
      FLastWFPResult := 0;
    end;
    exit;
  end;

  // according to MSDN disabled widget shouldn't be in result
  // but win32 returns first enabled and visible parent !
  if not QWidget_isEnabled(Widget) or not QWidget_isVisible(Widget) then
  begin
    while Widget <> nil do
    begin
      Widget := QWidget_parentWidget(Widget);
      if (Widget <> nil) and QWidget_IsVisible(Widget) and
        QWidget_isEnabled(Widget) then
          break;
    end;
    if Widget = nil then
      exit;
  end;

  Result := HwndFromWidgetH(Widget);

  // return from cache if we are same TQtWidget, just update point
  if IsValidWidgetAtCachePointer and (Result = FLastWFPResult) then
  begin
    FLastWFPMousePos := APoint;
    exit(FLastWFPResult);
  end;

  // maybe we are viewport of native QAbstractScrollArea (eg. QTextEdit).
  if (Result = 0) then
  begin
    if QWidget_parentWidget(Widget) <> nil then
    begin
      while (Widget <> nil) do
      begin
        Widget := QWidget_parentWidget(Widget);
        if Widget <> nil then
          Result := HwndFromWidgetH(Widget);
        if Result <> 0 then
          break;
      end;
    end;
  end;

  if (Result <> 0) and
    not (TQtWidget(Result) is TQtMainWindow) then
  begin
    if TQtWidget(Result).getOwner <> nil then
      Result := HWND(TQtWidget(Result).getOwner);
  end else
  begin
    Widget := QApplication_topLevelAt(APoint.x, APoint.y);
    if (Widget <> nil) and QWidget_isEnabled(Widget) then
      Result := HwndFromWidgetH(Widget)
    else
      Result := 0;
  end;

  // add to cache
  FLastWFPResult := Result;
  FLastWFPMousePos := APoint;
end;

//##apiwiz##eps##   // Do not remove, no wizard declaration after this line

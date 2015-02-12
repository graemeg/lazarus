{%MainUnit carbonint.pas}

{******************************************************************************
  All Carbon Winapi implementations.
  This are the implementations of the overrides of the Carbon Interface for the
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

//##apiwiz##sps##   // Do not remove

function TCarbonWidgetSet.Arc(DC: HDC; Left, Top, Right, Bottom, angle1,
  angle2: Integer): Boolean;
begin
  Result:=inherited Arc(DC, Left, Top, Right, Bottom, angle1, angle2);
end;

function TCarbonWidgetSet.AngleChord(DC: HDC; x1, y1, x2, y2, angle1,
  angle2: Integer): Boolean;
begin
  Result:=inherited AngleChord(DC, x1, y1, x2, y2, angle1, angle2);
end;

function TCarbonWidgetSet.BeginPaint(Handle: hWnd; var PS: TPaintStruct): hdc;
begin
  Result:=inherited BeginPaint(Handle, PS);
  PS.hdc:=Result;
end;

{------------------------------------------------------------------------------
  Method:  BitBlt
  Params:  DestDC        - Destination device context
           X, Y          - Left/top corner of the destination rectangle
           Width, Height - Size of the destination rectangle
           SrcDC         - Source device context
           XSrc, YSrc    - Left/top corner of the source rectangle
           Rop           - Raster operation to be performed
  Returns: If the function succeeds

  Copies a bitmap from a source context into a destination context using the
  specified raster operation
 ------------------------------------------------------------------------------}
function TCarbonWidgetSet.BitBlt(DestDC: HDC; X, Y, Width, Height: Integer;
  SrcDC: HDC; XSrc, YSrc: Integer; Rop: DWORD): Boolean;
begin
  Result := StretchMaskBlt(DestDC, X, Y, Width, Height, SrcDC, XSrc, YSrc,
    Width, Height, 0, 0, 0, Rop);
end;

function TCarbonWidgetSet.CallNextHookEx(hHk: HHOOK; ncode: Integer;
  wParam: WParam; lParam: LParam): Integer;
begin
  Result:=inherited CallNextHookEx(hHk, ncode, wParam, lParam);
end;

function TCarbonWidgetSet.CallWindowProc(lpPrevWndFunc: TFarProc; Handle: HWND;
  Msg: UINT; wParam: WParam; lParam: lParam): Integer;
begin
  Result:=inherited CallWindowProc(lpPrevWndFunc, Handle, Msg, wParam, lParam);
end;

{------------------------------------------------------------------------------
  Method:  ClientToScreen
  Params:  Handle - Handle of window
           P      - Record for coordinates
  Returns: If the function succeeds

  Converts the specified client coordinates to the screen coordinates
 ------------------------------------------------------------------------------}
function TCarbonWidgetSet.ClientToScreen(Handle: HWND; var P: TPoint): Boolean;
var
  R: TRect;
  Pt: TPoint;
begin
  Result := False;
  
  {$IFDEF VerboseWinAPI}
    DebugLn('TCarbonWidgetSet.ClientToScreen P: ' + DbgS(P));
  {$ENDIF}
  
  if not CheckWidget(Handle, 'ClientToScreen') then Exit;
  Result := TCarbonWidget(Handle).GetScreenBounds(R{%H-});
  
  if Result then
  begin
    Inc(P.X, R.Left);
    Inc(P.Y, R.Top);
    
    Result := TCarbonWidget(Handle).GetClientRect(R);
    
    if Result then
    begin
      Inc(P.X, R.Left);
      Inc(P.Y, R.Top);
      Pt := TCarbonWidget(Handle).ScrollOffset;
      Dec(P.X, Pt.X);
      Dec(P.Y, Pt.Y);
    end;

  end;
  
  {$IFDEF VerboseWinAPI}
    DebugLn('TCarbonWidgetSet.ClientToScreen Result: ' + DbgS(Result) + ' P: ' + DbgS(P));
  {$ENDIF}
end;

{------------------------------------------------------------------------------
  Method:  ClipboardFormatToMimeType
  Params:  FormatID - A registered format identifier (0 is invalid)
  Returns: The corresponding mime type as string
 ------------------------------------------------------------------------------}
function TCarbonWidgetSet.ClipboardFormatToMimeType(FormatID: TClipboardFormat): string;
begin
  {$IFDEF VerboseWinAPI}
    DebugLn('TCarbonWidgetSet.ClipboardFormatToMimeType FormatID: ' + DbgS(FormatID));
  {$ENDIF}
  
  Result := Clipboard.FormatToMimeType(FormatID);
end;

{------------------------------------------------------------------------------
  Method:  ClipboardGetData
  Params:  ClipboardType - Clipboard type
           FormatID      - A registered format identifier (0 is invalid)
           Stream        - If format is available, it will be appended to this
                           stream
  Returns: If the function succeeds
 ------------------------------------------------------------------------------}
function TCarbonWidgetSet.ClipboardGetData(ClipboardType: TClipboardType;
  FormatID: TClipboardFormat; Stream: TStream): boolean;
begin
  {$IFDEF VerboseWinAPI}
    DebugLn('TCarbonWidgetSet.ClipboardGetData ClipboardType' +
      ClipboardTypeName[ClipboardType] + ' FormatID: ' + DbgS(FormatID));
  {$ENDIF}
  
  Result := Clipboard.GetData(ClipboardType, FormatID, Stream);
end;

{------------------------------------------------------------------------------
  Method:  ClipboardGetFormats
  Params:  ClipboardType - The type of clipboard operation
           Count         - The number of clipboard formats
           List          - Pointer to an array of supported formats
                           (you must free it yourself)
  Returns: If the function succeeds
 ------------------------------------------------------------------------------}
function TCarbonWidgetSet.ClipboardGetFormats(ClipboardType: TClipboardType;
  var Count: integer; var List: PClipboardFormat): Boolean;
begin
  {$IFDEF VerboseWinAPI}
    DebugLn('TCarbonWidgetSet.ClipboardGetFormats ClipboardType' +
      ClipboardTypeName[ClipboardType]);
  {$ENDIF}
  
  Result := Clipboard.GetFormats(ClipboardType, Count, List);
end;

{------------------------------------------------------------------------------
  Method:  ClipboardGetOwnerShip
  Params:  ClipboardType - Type of clipboard
           OnRequestProc - TClipboardRequestEvent is defined in LCLType.pp
                           If OnRequestProc is nil the onwership will end.
           FormatCount   - Number of formats
           Formats       - Array of TClipboardFormat. The supported formats the
                           owner provides.

  Returns: If the function succeeds

  Sets the supported formats and requests ownership for the clipboard.
  The OnRequestProc is used to get the data from the LCL and to put it on the
  clipboard.
  If someone else requests the ownership, the OnRequestProc will be executed
  with the invalid FormatID 0 to notify the old owner of the lost of ownership.
 ------------------------------------------------------------------------------}
function TCarbonWidgetSet.ClipboardGetOwnerShip(ClipboardType: TClipboardType;
  OnRequestProc: TClipboardRequestEvent; FormatCount: integer;
  Formats: PClipboardFormat): boolean;
begin
  {$IFDEF VerboseWinAPI}
    DebugLn('TCarbonWidgetSet.ClipboardGetOwnerShip ClipboardType' +
      ClipboardTypeName[ClipboardType] + ' FormatCount: ' + DbgS(FormatCount));
  {$ENDIF}
  
  Result := Clipboard.GetOwnerShip(ClipboardType, OnRequestProc, FormatCount,
    Formats);
end;

{------------------------------------------------------------------------------
  Method:  ClipboardRegisterFormat
  Params:  AMimeType - A string (usually a MIME type) identifying a new format
                       type to register
  Returns: The registered Format identifier (TClipboardFormat)
 ------------------------------------------------------------------------------}
function TCarbonWidgetSet.ClipboardRegisterFormat(const AMimeType: string): TClipboardFormat;
begin
  Result := Clipboard.RegisterFormat(AMimeType);
end;

function TCarbonWidgetSet.CombineRgn(Dest, Src1, Src2: HRGN;
  fnCombineMode: Longint): Longint;
var
  RealDest: TCarbonRegion;
begin
  Result := LCLType.Error;
  if (Dest = 0) or (Src1 = 0) or (fnCombineMode<RGN_AND) or (fnCombineMode>RGN_COPY) then Exit;
  if (fnCombineMode <> RGN_COPY) and (Src2 = 0) then Exit;

  if Dest=Src2 then
  begin
    RealDest := TCarbonRegion.Create;
    try
      result := RealDest.CombineWith(TCarbonRegion(Src1), RGN_COPY);
      if fnCombineMode<>RGN_COPY then
        result := RealDest.CombineWith(TCarbonRegion(Src2), fnCombineMode);
      TCarbonRegion(Dest).CombineWith(RealDest, RGN_COPY);
    finally
      RealDest.free;
    end;
  end else
  begin
    if Src1<>Dest then
      TCarbonRegion(Dest).CombineWith(TCarbonRegion(Src1), RGN_COPY);
    if fnCombineMode <> RGN_COPY then
      Result := TCarbonRegion(Dest).CombineWith(TCarbonRegion(Src2), fnCombineMode)
    else
      Result := TCarbonRegion(Dest).GetType;
  end;
end;

{------------------------------------------------------------------------------
  Method:  CreateBitmap
  Params:  Width      - Bitmap width, in pixels
           Height     - Bitmap height, in pixels
           Planes     - Number of color planes
           BitCount   - Number of bits required to identify a color (TODO)
           BitmapBits - Pointer to array containing color data (TODO)
  Returns: A handle to a bitmap

  Creates a bitmap with the specified width, height and color format
 ------------------------------------------------------------------------------}
function TCarbonWidgetSet.CreateBitmap(Width, Height: Integer; Planes,
  BitCount: Longint; BitmapBits: Pointer): HBITMAP;
var
  bmpType: TCarbonBitmapType;
begin
  {$IFDEF VerboseWinAPI}
    DebugLn('TCarbonWidgetSet.CreateBitmap');
  {$ENDIF}
  
  // WORKAROUND: force context supported depths
  if BitmapBits = nil then
  begin
    if BitCount = 24 then BitCount := 32;
    // if BitCount = 1 then BitCount := 8;
  end;
  
  case BitCount of
    1:  bmpType := cbtMono;
    8:  bmpType := cbtGray;
    32: bmpType := cbtARGB;
  else
    bmpType := cbtRGB;
  end;
  
  // winapi Bitmaps are on a word boundary
  Result := HBITMAP(TCarbonBitmap.Create(Width, Height, BitCount, BitCount, cbaWord, bmpType, BitmapBits));
end;


{------------------------------------------------------------------------------
  Method:   CreateBrushIndirect
  Params:   LogBrush - Record with brush characteristics
  Returns:  Handle to a logical brush

  Creates new logical brush that has the specified style, color, and pattern
  TODO: patterns
 ------------------------------------------------------------------------------}
function TCarbonWidgetSet.CreateBrushIndirect(const LogBrush: TLogBrush): HBRUSH;
begin
  {$IFDEF VerboseWinAPI}
    DebugLn('TCarbonWidgetSet.CreateBrushIndirect');
  {$ENDIF}
  
  Result := HBRUSH(TCarbonBrush.Create(LogBrush));
end;

{------------------------------------------------------------------------------
  Method:  CreateCaret
  Params:  Handle - handle to owner window
           Bitmap - handle to bitmap for caret shape
           Width  - caret width
           Height - caret height
  Returns: If the function succeeded

  Creates a new shape for the system caret and assigns ownership of the caret
  to the specified window
 ------------------------------------------------------------------------------}
function TCarbonWidgetSet.CreateCaret(Handle: HWND; Bitmap: hBitmap; Width, Height: Integer): Boolean;
begin
  Result := True;
  {$IFDEF VerboseWinAPI}
    DebugLn('TCarbonWidgetSet.CreateCaret Handle: ' + DbgS(Handle) + ' Bitmap: ' + DbgS(Bitmap),
      ' W: ' + DbgS(Width), ' H: ' + DbgS(Height));
  {$ENDIF}
  if not CheckWidget(Handle, 'CreateCaret') then Exit;
  if Bitmap > 1 then
    if not CheckBitmap(Bitmap, 'CreateCaret') then Exit;
  
  Result := CarbonCaret.CreateCaret(TCarbonWidget(Handle), Bitmap, Width, Height);
end;

{------------------------------------------------------------------------------
  Method:  CreateCompatibleBitmap
  Params:  DC     - Handle to memory device context
           Width  - Bitmap width
           Height - Bitmap height

  Returns: Handle to a bitamp

  Creates a bitamp compatible with the specified device
 ------------------------------------------------------------------------------}
function TCarbonWidgetSet.CreateCompatibleBitmap(DC: HDC; Width, Height: Integer
  ): HBITMAP;
begin
  {$IFDEF VerboseWinAPI}
    DebugLn('TCarbonWidgetSet.CreateCompatibleBitmap');
  {$ENDIF}
  
  // TODO: consider DC depth
  Result := HBITMAP(TCarbonBitmap.Create(Width, Height, 32, 32, cbaDQWord, cbtARGB, nil));
end;

{------------------------------------------------------------------------------
  Method:  CreateCompatibleDC
  Params:  DC - Handle to memory device context
  Returns: Handle to a memory device context

  Creates a memory device context (DC) compatible with the specified device
 ------------------------------------------------------------------------------}
function TCarbonWidgetSet.CreateCompatibleDC(DC: HDC): HDC;
begin
  {$IFDEF VerboseWinAPI}
    DebugLn('TCarbonWidgetSet.CreateCompatibleDC');
  {$ENDIF}
  
  // TODO: consider DC depth
  Result := HDC(TCarbonBitmapContext.Create);
end;

{------------------------------------------------------------------------------
  Method:  CreateFontIndirect
  Params:  LogFont - Font characteristics
  Returns: Handle to the font

  Creates new font with specified characteristics
 ------------------------------------------------------------------------------}
function TCarbonWidgetSet.CreateFontIndirect(const LogFont: TLogFont): HFONT;
begin
  {$IFDEF VerboseWinAPI}
    DebugLn('TCarbonWidgetSet.CreateFontIndirect');
  {$ENDIF}
  
  Result := HFONT(TCarbonFont.Create(LogFont, LogFont.lfFaceName));
end;

{------------------------------------------------------------------------------
  Method:  CreateFontIndirectEx
  Params:  LogFont      - Font characteristics
           LongFontName - Font name
  Returns: Handle to the font

  Creates new font with specified characteristics and name
 ------------------------------------------------------------------------------}
function TCarbonWidgetSet.CreateFontIndirectEx(const LogFont: TLogFont;
  const LongFontName: string): HFONT;
begin
  {$IFDEF VerboseWinAPI}
    DebugLn('TCarbonWidgetSet.CreateFontIndirectEx');
  {$ENDIF}
  
  Result := HFONT(TCarbonFont.Create(LogFont, LongFontName));
end;

function Create32BitAlphaBitmap(ABitmap, AMask: TCarbonBitmap): TCarbonBitmap;
var
  ARawImage: TRawImage;
  Desc: TRawImageDescription absolute ARawimage.Description;

  ImgHandle, ImgMaskHandle: HBitmap;
  ImagePtr: PRawImage;
  DevImage: TRawImage;
  DevDesc: TRawImageDescription;
  SrcImage, DstImage: TLazIntfImage;
  W, H: Integer;
begin
  Result := nil;

  if not RawImage_FromBitmap(ARawImage, HBITMAP(ABitmap), HBITMAP(AMask)) then
    Exit;

  ImgMaskHandle := 0;

  W := Desc.Width;
  if W < 1 then W := 1;
  H := Desc.Height;
  if H < 1 then H := 1;

  {$Note: check if DevDesc is the right parameter for QueryDescription}
  FillByte(DevDesc{%H-},SizeOf(DevDesc),0);
  QueryDescription(DevDesc, [riqfRGB, riqfAlpha], W, H);

  if DevDesc.IsEqual(Desc)
  then begin
    // image is compatible, so use it
    DstImage := nil;
    ImagePtr := @ARawImage;
  end
  else begin
    // create compatible copy
    SrcImage := TLazIntfImage.Create(ARawImage, False);
    DstImage := TLazIntfImage.Create(0,0,[]);
    DstImage.DataDescription := DevDesc;
    DstImage.CopyPixels(SrcImage);
    SrcImage.Free;
    DstImage.GetRawImage(DevImage);
    ImagePtr := @DevImage;
  end;

  try
    if not RawImage_CreateBitmaps(ImagePtr^, ImgHandle, ImgMaskHandle, True) then Exit;

    Result := TCarbonBitmap(ImgHandle);
  finally
    ARawImage.FreeData;
    DstImage.Free;
  end;
end;

{------------------------------------------------------------------------------
  Method:  CreateIconIndirect
  Params:  IconInfo - Icon/Cursor info as in win32
  Returns: Handle to a icon/cursor

  Creates an icon / cursor from bitmap and mask
 ------------------------------------------------------------------------------}
function TCarbonWidgetSet.CreateIconIndirect(IconInfo: PIconInfo): HICON;
var
  ABitmap: TCarbonBitmap;
begin
  {$IFDEF VerboseWinAPI}
    DebugLn('TCarbonWidgetSet.CreateIconIndirect');
  {$ENDIF}

  Result := 0;
  if IconInfo^.hbmColor = 0 then
    Exit;

  ABitmap := Create32BitAlphaBitmap(TCarbonBitmap(IconInfo^.hbmColor), TCarbonBitmap(IconInfo^.hbmMask));

  if IconInfo^.fIcon then
  begin
    Result := HICON(ABitmap)
  end
  else
  begin
    IconInfo^.hbmColor := HBITMAP(ABitmap);
    IconInfo^.hbmMask := 0;
    Result := HICON(TCarbonCursor.CreateFromInfo(IconInfo));
  end;
end;

function TCarbonWidgetSet.CreatePalette(const LogPalette: TLogPalette
  ): HPALETTE;
begin
  Result:=inherited CreatePalette(LogPalette);
end;

{------------------------------------------------------------------------------
  Method:  CreatePenIndirect
  Params:  LogPen - Record with pen characteristics
  Returns: Handle to a logical cosmetic pen

  Creates new logical cosmetic pen that has the specified style, width and color
 ------------------------------------------------------------------------------}
function TCarbonWidgetSet.CreatePenIndirect(const LogPen: TLogPen): HPEN;
begin
  {$IFDEF VerboseWinAPI}
    DebugLn('TCarbonWidgetSet.CreatePenIndirect');
  {$ENDIF}
  
  Result := HPEN(TCarbonPen.Create(LogPen));
end;

{------------------------------------------------------------------------------
  Method:  CreatePolygonRgn
  Params:  Points   - Pointer to array of polygon points
           NumPts   - Number of points passed
           FillMode - Filling mode
  Returns: The new polygonal region

  Creates a new polygonal region from the specified points
 ------------------------------------------------------------------------------}
function TCarbonWidgetSet.CreatePolygonRgn(Points: PPoint; NumPts: Integer;
  FillMode: integer): HRGN;
begin
  {$IFDEF VerboseWinAPI}
    DebugLn('TCarbonWidgetSet.CreatePolygonRgn NumPts: ' + DbgS(NumPts) +
      ' FillMode: ' + DbgS(FillMode));
  {$ENDIF}
  
  Result := HRGN(TCarbonRegion.Create(Points, NumPts, FillMode));
end;

{------------------------------------------------------------------------------
  Method:  CreateRectRgn
  Params:  X1, Y1, X2, Y2 - Region bounding rectangle
  Returns: The new rectangular region

  Creates a new rectangular region
 ------------------------------------------------------------------------------}
function TCarbonWidgetSet.CreateRectRgn(X1, Y1, X2, Y2: Integer): HRGN;
begin
  {$IFDEF VerboseWinAPI}
    DebugLn('TCarbonWidgetSet.CreateRectRgn R: ' + DbgS(Classes.Rect(X1, Y1, X2, Y2)));
  {$ENDIF}
  
  Result := HRGN(TCarbonRegion.Create(X1, Y1, X2, Y2));
end;

{------------------------------------------------------------------------------
  Method:  CreateEllipticRgn
  Params:  X1, Y1, X2, Y2 - Region bounding rectangle
  Returns: The new elliptic region

  Creates a new elliptic region. This region correspond to the extent drawn
  by the Ellipse funcion using default context's stroke properties, aliasing=off
 ------------------------------------------------------------------------------}
function TCarbonWidgetSet.CreateEllipticRgn(X1, Y1, X2, Y2: Integer): HRGN;
begin
  Result:=HRGN(TCarbonRegion.CreateEllipse(X1, Y1, X2, Y2));
end;

{------------------------------------------------------------------------------
  Method:  DeleteCriticalSection
  Params:  CritSection - Critical section to be deleted

  Deletes the specified critical section
 ------------------------------------------------------------------------------}
procedure TCarbonWidgetSet.DeleteCriticalSection(
  var CritSection: TCriticalSection);
var
  ACritSec: System.PRTLCriticalSection;
begin
  {$IFDEF VerboseWinAPI}
    DebugLn('TCarbonWidgetSet.DeleteCriticalSection Section: ' + DbgS(CritSection));
  {$ENDIF}
  
  ACritSec := {%H-}System.PRTLCriticalSection(CritSection);

  System.DoneCriticalsection(ACritSec^);
  Dispose(ACritSec);
  
  CritSection := 0;
end;

{------------------------------------------------------------------------------
  Method:  DeleteDC
  Params:  HDC - Handle to device context
  Returns: If the function succeeds

  Deletes the specified device context (DC)
 ------------------------------------------------------------------------------}
function TCarbonWidgetSet.DeleteDC(hDC: HDC): Boolean;
begin
  Result := False;

  {$IFDEF VerboseWinAPI}
    DebugLn('TCarbonWidgetSet.DeleteDC DC: ' + DbgS(hDC));
  {$ENDIF}
  
  if not CheckDC(hDC, 'DeleteDC') then Exit;
  
  TCarbonDeviceContext(hDC).Free;
  Result := True;
end;

{------------------------------------------------------------------------------
  Method:  DeleteObject
  Params:  GDIObject - Handle to graphic object
  Returns: If the function succeeds

  Deletes the specified graphic object, freeing all system resources associated
  with the object
 ------------------------------------------------------------------------------}
function TCarbonWidgetSet.DeleteObject(GDIObject: HGDIOBJ): Boolean;
var
  CarbonGDIObject: TCarbonGDIObject;
begin
  Result := False;

  {$IFDEF VerboseWinAPI}
    DebugLn('TCarbonWidgetSet.DeleteObject GDIObject: ' + DbgS(GDIObject));
  {$ENDIF}
  
  if not CheckGDIObject(GDIObject, 'DeleteObject') then Exit;
  CarbonGDIObject := TCarbonGDIObject(GDIObject);
  
  if CarbonGDIObject.Global then
  begin
    DebugLn('TCarbonWidgetSet.DeleteObject Error - GDIObject: ' +
      DbgSName(CarbonGDIObject) + ' is global!');
    Exit;
  end;
  
  if CarbonGDIObject.SelCount = 0 then CarbonGDIObject.Free
  else
  begin
    DebugLn('TCarbonWidgetSet.DeleteObject Error - GDIObject: ' +
      DbgSName(CarbonGDIObject) + ' is still selected!');
    Exit;
  end;
  
  Result := True;
end;

{------------------------------------------------------------------------------
  Method:  DestroyCaret
  Params:  Handle - handle to the window with a caret (IGNORED)
  Returns: If the function succeeds

  Destroys the caret but doesn't free the bitmap.
 ------------------------------------------------------------------------------}
function TCarbonWidgetSet.DestroyCaret(Handle: HWND): Boolean;
begin
  Result := False;

  {$IFDEF VerboseWinAPI}
    DebugLn('TCarbonWidgetSet.DestroyCaret Handle: ' + DbgS(Handle));
  {$ENDIF}
  
  Result := CarbonCaret.DestroyCaret;
end;

{------------------------------------------------------------------------------
  Method:  DestroyIcon
  Params:  Handle - Handle to icon/cursor
  Returns: If the function succeeds

  Destroy previously created icon/cursor
 ------------------------------------------------------------------------------}
function TCarbonWidgetSet.DestroyIcon(Handle: HICON): Boolean;
begin
  Result := False;

  {$IFDEF VerboseWinAPI}
    DebugLn('TCarbonWidgetSet.DestroyIcon Handle: ' + DbgS(Handle));
  {$ENDIF}
  
  if (TObject(Handle) is TCarbonBitmap) or
     (TObject(Handle) is TCarbonCursor) then 
    TObject(Handle).Free;
end;

function TCarbonWidgetSet.DPtoLP(DC: HDC; var Points; Count: Integer): BOOL;
var
  P: PPoint;
begin
  Result := False;
  if not CheckDC(DC, 'LPtoDP') then Exit;
  P := @Points;
  with TCarbonDeviceContext(DC).GetLogicalOffset do
    while Count > 0 do
    begin
      Dec(Count);
      dec(P^.X, X);
      dec(P^.Y, Y);
      inc(P);
    end;
  Result := True;
end;

{------------------------------------------------------------------------------
  Method:  DrawFocusRect
  Params:  DC   - Handle to device context
           Rect - Bounding rectangle
  Returns: If the function succeeds

  Draws a focus rectangle
 ------------------------------------------------------------------------------}
function TCarbonWidgetSet.DrawFocusRect(DC: HDC; const Rect: TRect): boolean;
begin
  Result := False;

  {$IFDEF VerboseWinAPI}
    DebugLn('TCarbonWidgetSet.DrawFocusRect DC: ' + DbgS(DC) + ' Rect: ' + DbgS(Rect));
  {$ENDIF}

  if not CheckDC(DC, 'DrawFocusRect') then Exit;

  TCarbonDeviceContext(DC).DrawFocusRect(Rect);

  Result := True;
end;

{------------------------------------------------------------------------------
  Method:  Ellipse
  Params:
           DC - Handle to device context
           X1 - X-coord. of bounding rectangle's upper-left corner
           Y1 - Y-coord. of bounding rectangle's upper-left corner
           X2 - X-coord. of bounding rectangle's lower-right corner
           Y2 - Y-coord. of bounding rectangle's lower-right corner
  Returns: If the function succeeds

  Draws a ellipse. The ellipse is outlined by using the current pen and filled
  by using the current brush.
 ------------------------------------------------------------------------------}
function TCarbonWidgetSet.Ellipse(DC: HDC; x1, y1, x2, y2: Integer): Boolean;
begin
  Result := False;

  {$IFDEF VerboseWinAPI}
    DebugLn('TCarbonWidgetSet.Ellipse DC: ' + DbgS(DC) + ' R: ' + DbgS(Classes.Rect(X1, Y1, X2, Y2)));
  {$ENDIF}
  
  if not CheckDC(DC, 'Ellipse') then Exit;

  TCarbonDeviceContext(DC).Ellipse(X1, Y1, X2, Y2);

  Result := True;
end;

function TCarbonWidgetSet.EnableScrollBar(Wnd: HWND; wSBflags, wArrows: Cardinal
  ): Boolean;
begin
  Result:=inherited EnableScrollBar(Wnd, wSBflags, wArrows);
end;

{------------------------------------------------------------------------------
  Method:  EnableWindow
  Params:  hWnd    - Handle to window
           bEnable - Whether to enable the window
  Returns: If the window was previously disabled

  Enables or disables mouse and keyboard input to the specified window or
  control
 ------------------------------------------------------------------------------}
function TCarbonWidgetSet.EnableWindow(hWnd: HWND; bEnable: Boolean): Boolean;
begin
  Result := False;

  {$IFDEF VerboseWinAPI}
    DebugLn('TCarbonWidgetSet.EnableWindow Handle: ' + DbgS(hWnd) + 'Enable: ' + DbgS(bEnable));
  {$ENDIF}
  
  if not CheckWidget(HWnd, 'EnableWindow') then Exit;
  Result := TCarbonWidget(HWnd).Enable(bEnable);
end;

function TCarbonWidgetSet.EndPaint(Handle: hwnd; var PS: TPaintStruct
  ): Integer;
begin
  Result:=inherited EndPaint(Handle, PS);
end;

{------------------------------------------------------------------------------
  Method:  EnterCriticalSection
  Params:  CritSection - Critical section to be entered

  Enters the specified critical section
 ------------------------------------------------------------------------------}
procedure TCarbonWidgetSet.EnterCriticalSection(
  var CritSection: TCriticalSection);
var
  ACritSec: System.PRTLCriticalSection;
begin
  {$IFDEF VerboseWinAPI}
    DebugLn('TCarbonWidgetSet.EnterCriticalSection Section: ' + DbgS(CritSection));
  {$ENDIF}
  
  ACritSec:={%H-}System.PRTLCriticalSection(CritSection);
  System.EnterCriticalsection(ACritSec^);
end;

function TCarbonWidgetSet.EnumDisplayMonitors(hdc: HDC; lprcClip: PRect;
  lpfnEnum: MonitorEnumProc; dwData: LPARAM): LongBool;
var
  Count: CGDisplayCount;
  activeDspys: array[0..1024] of CGDirectDisplayID;
  i: integer;
begin
  if OSError(CGGetActiveDisplayList(1024, activeDspys, Count{%H-}),
    'TCarbonWidgetSet.EnumDisplayMonitors', 'CGGetActiveDisplayList') then Exit(False);
  Result := True;
  for i := 0 to Count - 1 do
  begin
    Result := Result and lpfnEnum(HMONITOR(activeDspys[i]), 0, nil, dwData);
    if not Result then break;
  end;
end;

function TCarbonWidgetSet.EnumFontFamilies(DC: HDC; Family: Pchar;
  EnumFontFamProc: FontEnumProc; LParam: Lparam): Longint;
begin
  Result:=inherited EnumFontFamilies(DC, Family, EnumFontFamProc, LParam);
end;

{------------------------------------------------------------------------------
  Method:  EnumFontFamiliesEx
  Params:  DC        - Handle to the device context (ignored)
           lpLogFont - Font characteristics to match
           Callback  - Callback function
           LParam    - Parameter to pass to the callback function.
           flags     - Not used
  Returns: The last value returned by callback function

  Enumerates all the font families in the system that match specified
  characteristics
  TODO: specific face or specific char set enumeration
 ------------------------------------------------------------------------------}
function TCarbonWidgetSet.EnumFontFamiliesEx(DC: HDC; lpLogFont: PLogFont;
  Callback: FontEnumExProc; LParam: Lparam; flags: dword): Longint;
var
  FamilyCount: LongWord;
  FamilyListPtr, PFamily: ^ATSUFontID;
  FontName: String;
  EnumLogFont: TEnumLogFontEx;
  Metric: TNewTextMetricEx;
  FontType, I: Integer;
const
  SName = 'TCarbonWidgetSet.EnumFontFamiliesEx';
begin
  Result := 0;

  {$IFDEF VerboseWinAPI}
    DebugLn('TCarbonWidgetSet.EnumFontFamiliesEx');
  {$ENDIF}
  
  if (lpLogFont = nil) or not Assigned(Callback) then Exit;
  
  // enumarate ATSUI font families:
  
  if (lpLogFont^.lfCharSet = DEFAULT_CHARSET) and (lpLogFont^.lfFaceName = '') then
  begin
    // all system fonts
    if OSError(ATSUFontCount(FamilyCount{%H-}), SName, 'ATSUFontCount') then Exit;
    
    GetMem(FamilyListPtr, SizeOf(ATSUFontID) * FamilyCount);
    try
      if OSError(ATSUGetFontIDs(FamilyListPtr, FamilyCount, nil), SName, 'ATSUGetFontIDs') then Exit;

      {$IFDEF VerboseWinAPI}
        DebugLn(SName + ' Found: ' + DbgS(FamilyCount));
      {$ENDIF}

      PFamily := FamilyListPtr;
      for I := 0 to Pred(FamilyCount) do
      begin
        FontName := CarbonFontIDToFontName(PFamily^);
        if FontName <> '' then // execute callback
        begin
          FillChar(EnumLogFont{%H-}, SizeOf(EnumLogFont), #0);
          FillChar(Metric{%H-}, SizeOf(Metric), #0);
          FontType := 0;
          EnumLogFont.elfLogFont.lfFaceName := FontName;
          // TODO: get all attributes
          
          Result := Callback(EnumLogFont, Metric, FontType, LParam);
        end;
        Inc(PFamily);
      end;
    finally
      System.FreeMem(FamilyListPtr);
    end;
  end
  else
  begin
    DebugLn(SName + ' with specific face or char set is not implemented!');
  end;
end;

{------------------------------------------------------------------------------
  Method:  ExcludeClipRect
  Params:  DC - Handle to device context
           Left, Top, Right, Bottom - Rectangle coordinates
  Returns: See bellow

  Subtracts all intersecting points of the passed bounding rectangle from the
  current clipping region of the device context. The result can be one of the
  following constants: ERROR, NULLREGION, SIMPLEREGION, COMPLEXREGION.
 ------------------------------------------------------------------------------}
function TCarbonWidgetSet.ExcludeClipRect(DC: HDC; Left, Top, Right,
  Bottom: Integer): Integer;
begin
  //todo: remove, as unused
  Result := inherited ExcludeClipRect(DC, Left, Top, Right, Bottom);
end;

function TCarbonWidgetSet.ExtCreatePen(dwPenStyle, dwWidth: DWord;
  const lplb: TLogBrush; dwStyleCount: DWord; lpStyle: PDWord): HPEN;
begin
  Result := HPEN(TCarbonPen.Create(dwPenStyle, dwWidth, lplb, dwStyleCount, lpStyle));
end;

{------------------------------------------------------------------------------
  Method:  ExtTextOut
  Params:  DC      - Handle to device context
           X       - X-coordinate of reference point
           Y       - Y-coordinate of reference point
           Options - Text-output options
           Rect    - Optional clipping and/or opaquing rectangle (TODO)
           Str     - Character string to be drawn
           Count   - Number of characters in string
           Dx      - Pointer to array of intercharacter spacing values (IGNORED)
  Returns: If the string was drawn

  Draws a character string by using the currently selected font
 ------------------------------------------------------------------------------}
function TCarbonWidgetSet.ExtTextOut(DC: HDC; X, Y: Integer; Options: Longint;
  Rect: PRect; Str: PChar; Count: Longint; Dx: PInteger): Boolean;
var
  SavedDC: Integer;
begin
  Result := False;

  {$IFDEF VerboseWinAPI}
    DebugLn('TCarbonWidgetSet.ExtTextOut DC: ' + DbgS(DC) + ' ' + DbgS(X) +
      ', ' + DbgS(Y) + ' Str: ' + Str + ' Count: ' + DbgS(Count));
  {$ENDIF}
  
  if not CheckDC(DC, 'ExtTextOut') then Exit;

  if ((Options and ETO_CLIPPED) > 0) and Assigned(Rect) then
  begin
    SavedDC := SaveDC(DC);
    with Rect^ do
      IntersectClipRect(DC, Left, Top, Right, Bottom);
  end;

  Result :=
    TCarbonDeviceContext(DC).ExtTextOut(X, Y, Options, Rect, Str, Count, Dx);
  
  if ((Options and ETO_CLIPPED) > 0) and Assigned(Rect) then
    RestoreDC(DC, SavedDC);
  {$IFDEF VerboseWinAPI}
    DebugLn('TCarbonWidgetSet.ExtTextOut Result: ' + DbgS(Result));
  {$ENDIF}
end;

function TCarbonWidgetSet.ExtSelectClipRGN(dc: hdc; rgn: hrgn; Mode: Longint): Integer;
const
  SName = 'TCarbonWidgetSet.ExtSelectClipRGN';
begin
  {$IFDEF VerboseWinAPI}
    DebugLn('TCarbonWidgetSet.ExtSelectClipRGN DC: ' + DbgS(DC) + ' RGN: ' +
      DbgS(RGN));
  {$ENDIF}
  Result := LCLType.Error;
  if (DC = 0) then Exit;
  if not CheckDC(DC, SName) then Exit;
  Result := TCarbonDeviceContext(DC).SetClipRegion(TCarbonRegion(RGN), Mode);
end;

{------------------------------------------------------------------------------
  Method:  FillRect
  Params:  DC    - Handle to device context
           Rect  - Record with rectangle coordinates
           Brush - Handle to brush
  Returns: If the function succeeds

  Fills the rectangle by using the specified brush
  It includes the left and top borders, but excludes the right and
  bottom borders of the rectangle!
 ------------------------------------------------------------------------------}
function TCarbonWidgetSet.FillRect(DC: HDC; const Rect: TRect; Brush: HBRUSH
  ): Boolean;
begin
  Result := False;

  {$IFDEF VerboseWinAPI}
    DebugLn('TCarbonWidgetSet.FillRect DC: ' + DbgS(DC) + ' R: ' + DbgS(Rect) +
      ' Brush: ' + DbgS(Brush));
  {$ENDIF}
  
  if not CheckDC(DC, 'FillRect') then Exit;
  if not (TObject(Brush) is TCarbonBrush) then
  begin
    DebugLn('TCarbonWidgetSet.FillRect Error - invalid Brush!');
    Exit;
  end;

  TCarbonDeviceContext(DC).FillRect(Rect, TCarbonBrush(Brush));

  Result := True;
end;


{------------------------------------------------------------------------------
  Method:  FloodFill
  Params:  DC        - Handle to device context
           X,Y       - Filling start point
           Color     - A border color or filling color
           FillStyle - filling style
           Brush     - a content to fill with
  Returns: > 0 if the function succeeds

  Fills the aread starting at 0,0 with the specified brush
 ------------------------------------------------------------------------------}
function TCarbonWidgetSet.FloodFill(DC: HDC; X, Y: Integer;
                   Color: TGraphicsColor;
                   FillStyle: TGraphicsFillStyle;
                   Brush: HBRUSH): Boolean;
begin
  Result := False;

  {$IFDEF VerboseWinAPI}
    DebugLn('TCarbonWidgetSet.FloodFill DC: ' + DbgS(DC)  + ' Brush: ' + DbgS(Brush));
  {$ENDIF}

  if not CheckDC(DC, 'FillRect') then Exit;
  if not (TObject(Brush) is TCarbonBrush) then
  begin
    DebugLn('TCarbonWidgetSet.FloodFill Error - invalid Brush!');
    Exit;
  end;

  try
    Result:=TCarbonDeviceContext(DC) is TCarbonBitmapContext;
    if not Result then Exit;
    with TCarbonBrush(Brush) do
    begin
      Result:=FloodFillBitmap( TCarbonBitmapContext(DC).Bitmap,
        X, Y, 0, RGBToColor(Red,Green,Blue), True);
    end;
  except
    Result:=False;
  end;

end;

{------------------------------------------------------------------------------
  Method:  Frame3D
  Params:  DC         - Handle to device context
           ARect      - Bounding box of frame
           FrameWidth - Frame width
           Style      - Frame style
  Returns: If the function succeeds

  Draws a 3D border in Carbon native style
 ------------------------------------------------------------------------------}
function TCarbonWidgetSet.Frame3D(DC: HDC; var ARect: TRect;
  const FrameWidth: integer; const Style: TBevelCut): Boolean;
begin
  Result := False;

  {$IFDEF VerboseWinAPI}
    DebugLn('TCarbonWidgetSet.Frame3D DC: ' + DbgS(DC) + ' R: ' + DbgS(ARect) +
      ' Width: ' + DbgS(FrameWidth) + ' Style: ' + DbgS(Integer(Style)));
  {$ENDIF}
  
  if not CheckDC(DC, 'Frame3D') then Exit;
  
  if FrameWidth <= 0 then Exit;

  TCarbonDeviceContext(DC).Frame3D(ARect, FrameWidth, Style);
  
  Result := True;
end;

{------------------------------------------------------------------------------
  Method:  FrameRect
  Params:  DC    - Handle to device context
           ARect - Bounding box of frame
           hBr   - Border brush (ignored)
  Returns: > 0 if the function succeeds

  Draws a border with the specified brush color in Carbon native style
  The width of the border of this rectangle is always 1
 ------------------------------------------------------------------------------}
function TCarbonWidgetSet.FrameRect(DC: HDC; const ARect: TRect;
  hBr: HBRUSH): Integer;
var
  NewPen, OldPen: TCarbonPen;
  CarbonDC: TCarbonDeviceContext absolute DC;
begin
  Result := 0;
  
  {$IFDEF VerboseWinAPI}
    DebugLn('TCarbonWidgetSet.FrameRect DC: ' + DbgS(DC) + ' R: ' + DbgS(ARect) +
      ' Brush: ' + DbgS(hBr));
  {$ENDIF}
  
  if not CheckDC(DC, 'FrameRect') then Exit;
  if not CheckGDIObject(hBr, 'FrameRect') then Exit;

  // Create a new Pen with default values and the color of the brush
  NewPen := TCarbonPen.Create(False);
  try
    NewPen.SetColor(TCarbonBrush(hBr).ColorRef, True);

    OldPen := CarbonDC.CurrentPen;
    CarbonDC.CurrentPen := NewPen;

    MoveToEx(DC, ARect.Left, ARect.Top, nil);
    LineTo(DC, ARect.Right - 1, ARect.Top);
    MoveToEx(DC, ARect.Left, ARect.Bottom - 1, nil);
    LineTo(Dc, ARect.Right - 1, ARect.Bottom - 1);
    MoveToEx(DC, ARect.Right - 1, ARect.Top, nil);
    LineTo(DC, ARect.Right - 1, ARect.Bottom - 1);
    MoveToEx(DC, ARect.Left, ARect.Top, nil);
    LineTo(DC, ARect.Left, ARect.Bottom - 1);

    Result := -1;

    CarbonDC.CurrentPen := OldPen;
  finally
    NewPen.Free;
  end;
end;

{------------------------------------------------------------------------------
  Method:  GetActiveWindow
  Params:  None
  Returns: The handle to the active window

  Retrieves the window handle to the active window
 ------------------------------------------------------------------------------}
function TCarbonWidgetSet.GetActiveWindow: HWND;
var
  Window: WindowRef;
begin
  Result := 0;
  
  Window := GetWindowList;
  while (Window <> nil) and not IsWindowActive(Window) do
    Window := GetNextWindow(Window);

  Result := HWND(GetCarbonWindow(Window));
  
  {$IFDEF VerboseWinAPI}
    DebugLn('TCarbonWidgetSet.GetActiveWindow Result: ' + DbgS(Result));
  {$ENDIF}
end;

function TCarbonWidgetSet.GetBitmapBits(Bitmap: HBITMAP; Count: Longint;
  Bits: Pointer): Longint;
begin
  Result:=inherited GetBitmapBits(Bitmap, Count, Bits);
end;

function TCarbonWidgetSet.GetBkColor(DC: HDC): TColorRef;
begin
  {$IFDEF VerboseWinAPI}
    DebugLn('TCarbonWidgetSet.GetBkColor DC: ' + DbgS(DC));
  {$ENDIF}

  Result := CLR_INVALID;

  if not CheckDC(DC, 'GetBkColor') then Exit;
  Result := TCarbonDeviceContext(DC).BkColor;
end;

{------------------------------------------------------------------------------
  Method:  GetCapture
  Returns: The handle of the capture window

  Retrieves the handle of the window (if any) that has captured the mouse
 ------------------------------------------------------------------------------}
function TCarbonWidgetSet.GetCapture: HWND;
begin
  Result := FCaptureWidget;
end;

{------------------------------------------------------------------------------
  Method:  GetCaretPos
  Params:  LPPoint - record to receive coordinates
  Returns: If the function succeeds

  Gets the caret's position, in client coordinates.
 ------------------------------------------------------------------------------}
function TCarbonWidgetSet.GetCaretPos(var lpPoint: TPoint): Boolean;
begin
  Result := CarbonCaret.GetCaretPos(lpPoint);
  
  {$IFDEF VerboseWinAPI}
    DebugLn('TCarbonWidgetSet.GetCaretPos Point: ' + DbgS(lpPoint), ' Result: ' + DbgS(Result));
  {$ENDIF}
end;

function TCarbonWidgetSet.GetCaretRespondToFocus(handle: HWND;
  var ShowHideOnFocus: boolean): Boolean;
begin
  Result:=inherited GetCaretRespondToFocus(handle, ShowHideOnFocus);
end;

function TCarbonWidgetSet.GetCharABCWidths(DC: HDC; p2, p3: UINT;
  const ABCStructs): Boolean;
begin
  Result:=inherited GetCharABCWidths(DC, p2, p3, ABCStructs);
end;

{------------------------------------------------------------------------------
  Method:  GetClientBounds
  Params:  Handle - Handle of window
           Rect   - Record for client coordinates
  Returns: If the function succeeds

  Retrieves the local coordinates of a window's client area
 ------------------------------------------------------------------------------}
function TCarbonWidgetSet.GetClientBounds(Handle: HWND; var ARect: TRect): Boolean;
begin
  Result := False;
  
  {$IFDEF VerboseWinAPI}
    DebugLn('TCarbonWidgetSet.GetClientBounds Handle: ' + DbgS(Handle));
  {$ENDIF}
  
  if not CheckWidget(Handle, 'GetClientBounds') then Exit;
  Result := TCarbonWidget(Handle).GetClientRect(ARect);
  
  {$IFDEF VerboseWinAPI}
    DebugLn('TCarbonWidgetSet.GetClientBounds Result: ' + DbgS(Result));
  {$ENDIF}
end;

{------------------------------------------------------------------------------
  Method:  GetClientRect
  Params:  Handle - Handle of window
           Rect   - Record for client coordinates
  Returns: If the function succeeds

  Retrieves the dimension of a window's client area.
  Left and Top are always 0, 0.
 ------------------------------------------------------------------------------}
function TCarbonWidgetSet.GetClientRect(Handle: HWND; var ARect: TRect): Boolean;
begin
  Result := False;
  
  {$IFDEF VerboseWinAPI}
    DebugLn('TCarbonWidgetSet.GetClientRect Handle: ' + DbgS(Handle));
  {$ENDIF}
  
  if not CheckWidget(Handle, 'GetClientRect') then Exit;
  
  Result := TCarbonWidget(Handle).GetClientRect(ARect);
  if Result then OffsetRect(ARect, -ARect.Left, -ARect.Top);
  
  {$IFDEF VerboseWinAPI}
    DebugLn('TCarbonWidgetSet.GetClientRect Result: ' + DbgS(Result));
  {$ENDIF}
end;

{------------------------------------------------------------------------------
  Method:  GetClipBox
  Params:  DC   - Handle to device context
           Rect - Record for client coordinates of clipping box
  Returns: See bellow

  Retrieves the smallest rectangle which includes the entire current clipping
  region. The result can be one of the following constants: ERROR, NULLREGION,
  SIMPLEREGION, COMPLEXREGION.
 ------------------------------------------------------------------------------}
function TCarbonWidgetSet.GetClipBox(DC: hDC; lpRect: PRect): Longint;
begin
  Result := ERROR;
  
  {$IFDEF VerboseWinAPI}
    DebugLn('TCarbonWidgetSet.GetClipBox DC: ' + DbgS(DC));
  {$ENDIF}
  
  if not CheckDC(DC, 'GetClipBox') then Exit;
  
  if lpRect <> nil then
    lpRect^ := TCarbonDeviceContext(DC).GetClipRect;

  Result := COMPLEXREGION;
  
  {$IFDEF VerboseWinAPI}
    if lpRect <> nil then
      DebugLn('TCarbonWidgetSet.GetClipBox Rect: ' + DbgS(lpRect^));
  {$ENDIF}
end;

function TCarbonWidgetSet.GetClipRGN(DC: hDC; RGN: hRGN): Longint;
begin
  {$IFDEF VerboseWinAPI}
    DebugLn('TCarbonWidgetSet.GetClipRGN DC: ' + DbgS(DC));
  {$ENDIF}
  Result := LCLType.Error;
  if RGN = 0 then Exit;
  if not CheckDC(DC, 'GetClipRGN') then Exit;
  Result := TCarbonDeviceContext(DC).CopyClipRegion(TCarbonRegion(RGN));
end;

function TCarbonWidgetSet.GetCmdLineParamDescForInterface: string;
begin
  Result:=inherited GetCmdLineParamDescForInterface;
end;

{------------------------------------------------------------------------------
  Method: GetCurrentObject
  Params:
    DC - A handle to the DC
    uObjectType - The object type to be queried
  Returns: If the function succeeds, the return value is a handle to the specified object.
    If the function fails, the return value is NULL.
 ------------------------------------------------------------------------------}

function TCarbonWidgetSet.GetCurrentObject(DC: HDC; uObjectType: UINT): HGDIOBJ;
var
  CarbonDC: TCarbonDeviceContext absolute DC;
begin
  Result := 0;
  if not CheckDC(DC, 'GetCurrentObject') then
    Exit;
  case uObjectType of
    OBJ_BITMAP:
      begin
         if CarbonDC is TCarbonBitmapContext then
           Result := HGDIOBJ(TCarbonBitmapContext(CarbonDC).Bitmap);
      end;
    OBJ_BRUSH: Result := HGDIOBJ(CarbonDC.CurrentBrush);
    OBJ_FONT: Result := HGDIOBJ(CarbonDC.CurrentFont);
    OBJ_PEN: Result := HGDIOBJ(CarbonDC.CurrentPen);
  end;
end;

{------------------------------------------------------------------------------
  Method:  GetCursorPos
  Params:  lpPoint - Record for coordinates
  Returns: If the function succeeds

  Retrieves the global screen coordinates of the mouse cursor
 ------------------------------------------------------------------------------}
function TCarbonWidgetSet.GetCursorPos(var lpPoint: TPoint): Boolean;
var
  Pt: MacOSAll.Point;
begin
  Result := False;
  
  GetGlobalMouse(Pt{%H-});
  
  lpPoint.X := Pt.h;
  lpPoint.Y := Pt.v;
  
  Result := True;
  
  {$IFDEF VerboseWinAPI}
    DebugLn('TCarbonWidgetSet.GetCursorPos Point: ' + DbgS(lpPoint));
  {$ENDIF}
end;

{------------------------------------------------------------------------------
  Method:  GetDC
  Params:  HWnd - Handle of window
  Returns: Value identifying the device context for the given window's client
           area

  Retrieves a handle of a display device context (DC) for the client area of
  the specified window
  TODO: implement screen context
 ------------------------------------------------------------------------------}
function TCarbonWidgetSet.GetDC(HWnd: HWND): HDC;
var
  DC: TCarbonControlContext;
begin
  Result := 0;

  {$IFDEF VerboseWinAPI}
    DebugLn('TCarbonWidgetSet.GetDC HWnd: ' + DbgS(HWnd));
  {$ENDIF}

  if HWnd = 0 then Result := HDC(ScreenContext)
  else
  begin
    if not CheckWidget(HWnd, 'GetDC') then Exit;
    
    // use dummy context if we are outside paint event
    if TCarbonWidget(HWnd).Context <> nil then Result := HDC(TCarbonWidget(HWnd).Context)
    else
    begin
      DC := TCarbonControlContext.Create(TCarbonWidget(HWnd));
      DC.CGContext := DefaultContext.CGContext;
      DC.Reset;
      Result := HDC(DC);
    end;
  end;
  
  {$IFDEF VerboseWinAPI}
    DebugLn('TCarbonWidgetSet.GetDC Result: ' + DbgS(Result));
  {$ENDIF}
end;

function TCarbonWidgetSet.GetDCOriginRelativeToWindow(PaintDC: HDC;
  WindowHandle: HWND; var OriginDiff: TPoint): boolean;
var
  DC      : TCarbonDeviceContext;
  affine  : CGAffineTransform;
  r : TRect;
begin
  {$IFDEF VerboseWinAPI}
    DebugLn(Format('TCarbonWidgetSet.GetDCOriginRelativeToWindow WindowHandle: %x PaintDC: %x',
     [WindowHandle, PaintDC]));
  {$ENDIF}

  Result := CheckDC(PaintDC, 'GetDCOriginRelativeToWindow');
  if Result then
  begin
    DC := TCarbonDeviceContext(PaintDC);
    affine := CGContextGetCTM(DC.CGContext);
    TCarbonWidget(WindowHandle).GetBounds(r{%H-});
    OriginDiff.x := Round(affine.tx);
    OriginDiff.y := Round((r.Bottom - r.Top) - affine.ty);
    Result := true;
  end;
end;

{------------------------------------------------------------------------------
  Method: GetDeviceCaps
  Params: DC    - Display device context
          Index - Index of needed capability

  Returns device specific information
 ------------------------------------------------------------------------------}
function TCarbonWidgetSet.GetDeviceCaps(DC: HDC; Index: Integer): Integer;
begin
  Result := 0;

  {$IFDEF VerboseWinAPI}
    DebugLn('TCarbonWidgetSet.GetDeviceCaps DC: ' + DbgS(DC) + ' Index: ' + DbgS(Index));
  {$ENDIF}
  
  if not CheckDC(DC, 'GetDeviceCaps') then Exit;

  case Index of
  LOGPIXELSX,
  LOGPIXELSY:
    // logical is allways 72 dpi, although physical can differ
    Result := 72; // TODO: test scaling and magnification
  BITSPIXEL:  Result := CGDisplayBitsPerPixel(CGMainDisplayID);
  else
    DebugLn('TCarbonWidgetSet.GetDeviceCaps TODO Index: ' + DbgS(Index));
  end;
  
  {$IFDEF VerboseWinAPI}
    DebugLn('TCarbonWidgetSet.GetDeviceCaps Result: ' + DbgS(Result));
  {$ENDIF}
end;

{------------------------------------------------------------------------------
  Method:  GetDeviceSize
  Params:  DC - Handle to device context
           P  - Record point for result
  Returns: If the function succeeds

  Retrieves the size of the specified device context
 ------------------------------------------------------------------------------}
function TCarbonWidgetSet.GetDeviceSize(DC: HDC; var p: TPoint): boolean;
begin
  Result := False;

  {$IFDEF VerboseWinAPI}
    DebugLn('TCarbonWidgetSet.GetDeviceSize DC: ' + DbgS(DC));
  {$ENDIF}
  
  if not CheckDC(DC, 'GetDeviceSize') then Exit;
  
  P := TCarbonDeviceContext(DC).Size;
  Result := True;
  
  {$IFDEF VerboseWinAPI}
    DebugLn('TCarbonWidgetSet.GetDeviceSize Size: ' + DbgS(P));
  {$ENDIF}
end;

function TCarbonWidgetSet.GetDIBits(DC: HDC; Bitmap: HBitmap; StartScan,
  NumScans: UINT; Bits: Pointer; var BitInfo: BitmapInfo; Usage: UINT
  ): Integer;
begin
  Result:=inherited GetDIBits(DC, Bitmap, StartScan, NumScans, Bits, BitInfo,
    Usage);
end;

{------------------------------------------------------------------------------
  Method:  GetFocus
  Params:  None
  Returns: The handle of the window with focus

  Retrieves the handle of the window that has the focus.
 ------------------------------------------------------------------------------}
function TCarbonWidgetSet.GetFocus: HWND;
var
  Control: ControlRef;
  Window: WindowRef;
begin
  Result := 0;

  {$IFDEF VerboseWinAPI}
    DebugLn('TCarbonWidgetSet.GetFocus');
  {$ENDIF}
  
  if FFocusedWidget = 0 then
  begin
    Window := WindowRef(GetUserFocusWindow);
    if Window = nil then Exit;

    Control := nil;
    OSError(GetKeyboardFocus(Window, Control), Self, 'GetFocus', SGetKeyboardFocus);

    if Control <> nil then
      Result := HWND(GetCarbonControl(Control))
    else Result := HWND(GetCarbonWindow(Window));
  end
  else
    Result := FFocusedWidget;
  
  {$IFDEF VerboseWinAPI}
    DebugLn('TCarbonWidgetSet.GetFocus Result: ' + DbgS(Result));
  {$ENDIF}
end;

function TCarbonWidgetSet.GetFontLanguageInfo(DC: HDC): DWord;
begin
  Result:=inherited GetFontLanguageInfo(DC);
end;

function TCarbonWidgetSet.GetMonitorInfo(hMonitor: HMONITOR; lpmi: PMonitorInfo): Boolean;
var
  DisplayID: CGDirectDisplayID absolute hMonitor;
  DeviceHandle: GDHandle;
  displayRect: CGRect;
  availRect: Rect;
begin
  Result := (lpmi <> nil) and (lpmi^.cbSize >= SizeOf(TMonitorInfo));
  if not Result then Exit;
  displayRect := CGDisplayBounds(DisplayID);
  lpmi^.rcMonitor := CGRectToRect(displayRect);
  lpmi^.rcWork := lpmi^.rcMonitor;
  if DisplayID = CGMainDisplayID then
  begin
    lpmi^.dwFlags := MONITORINFOF_PRIMARY;
    if OSError(DMGetGDeviceByDisplayID(DisplayIDType(DisplayID), DeviceHandle{%H-}, True),
      'TCarbonWidgetSet.GetMonitorInfo', 'DMGetGDeviceByDisplayID') then Exit;
    if OSError(GetAvailableWindowPositioningBounds(DeviceHandle, availRect{%H-}),
      'TCarbonWidgetSet.GetMonitorInfo', 'GetAvailableWindowPositioningBounds') then Exit;
    with availRect do
      lpmi^.rcWork := Types.Rect(left, top, right, bottom);
  end
  else
    lpmi^.dwFlags := 0;
end;

{------------------------------------------------------------------------------
  Method:  GetKeyState
  Params:  nVirtKey - The requested key
  Returns: If the function succeeds, the return value specifies the status of
           the given virtual key. If the high-order bit is 1, the key is down;
           otherwise, it is up. If the low-order bit is 1, the key is toggled.

  Retrieves the status of the specified virtual key
 ------------------------------------------------------------------------------}
function TCarbonWidgetSet.GetKeyState(nVirtKey: Integer): Smallint;
const
  StateDown    = SmallInt($FF80);
  //StateToggled = SmallInt($0001);
begin
  Result := 0;

  // DebugLn('TCarbonWidgetSet.GetKeyState ' + DbgSVKCode(nVirtKey));

  case nVirtKey of
  VK_MENU:
    if (GetCurrentEventKeyModifiers and optionKey) > 0 then
      // the ssAlt/VK_MENU is mapped to optionKey under MacOS
      Result := StateDown;
  VK_SHIFT:
    if (GetCurrentEventKeyModifiers and shiftKey) > 0 then
      Result := StateDown;
  VK_CONTROL:
    if (GetCurrentEventKeyModifiers and controlKey) > 0 then
      // the ssCtrl/VK_CONTROL is mapped to controlKey under MacOS
      Result := StateDown;
  VK_LWIN, VK_RWIN:
    // distinguish left and right
    if (GetCurrentEventKeyModifiers and cmdKey) > 0 then
      // the ssMeta/VK_LWIN is mapped to cmdKey under MacOS
      Result := StateDown;
  VK_LBUTTON:
    if (GetCurrentEventButtonState and $01) > 0 then Result := StateDown;
  VK_RBUTTON:
    if (GetCurrentEventButtonState and $02) > 0 then Result := StateDown;
  VK_MBUTTON:
    if (GetCurrentEventButtonState and $04) > 0 then Result := StateDown;
  VK_XBUTTON1:
    if (GetCurrentEventButtonState and $08) > 0 then Result := StateDown;
  VK_XBUTTON2:
    if (GetCurrentEventButtonState and $10) > 0 then Result := StateDown;
  else
    DebugLn('TCarbonWidgetSet.GetKeyState TODO ', DbgSVKCode(Word(nVirtkey)));
  end;
  
  // DebugLn('TCarbonWidgetSet.GetKeyState Result: ' + DbgS(Result));
end;

{------------------------------------------------------------------------------
  Method:  TCarbonWidgetSet.GetObject
  Params:  GDIObj  - GDI object
           BufSize - Size of specified buffer
           Buf     - Pointer to the buffer
  Returns: The size written to the buffer

  Retrieves the GDI object information
 ------------------------------------------------------------------------------}
function TCarbonWidgetSet.GetObject(GDIObj: HGDIOBJ; BufSize: Integer;
  Buf: Pointer): Integer;
var
  AObject: TCarbonGDIObject;
  DIB: TDIBSection;
  Width, Height, RequiredSize, i: Integer;

  APen: TCarbonPen absolute AObject;
  ALogPen: PLogPen absolute Buf;
  AExtLogPen: PExtLogPen absolute Buf;
  AFont: TCarbonFont absolute AObject;
  ALogFont: PLogFont absolute Buf;
begin
  Result := 0;

  {$IFDEF VerboseWinAPI}
    DebugLn('TCarbonWidgetSet.GetObject GDIObj: ' + DbgS(GDIObj));
  {$ENDIF}
  
  if not CheckGDIObject(GDIObj, 'GetObject') then Exit;
  
  AObject := TCarbonGDIObject(GDIObj);
  if AObject is TCarbonBitmap then
  begin
    if Buf = nil then
    begin
      Result := SizeOf(TDIBSection);
      Exit;
    end;
     
    Width := TCarbonBitmap(AObject).Width;
    Height := TCarbonBitmap(AObject).Height;

    FillChar(DIB{%H-}, SizeOf(TDIBSection), 0);

    {dsBM - BITMAP}
    DIB.dsBm.bmType := $4D42;
    DIB.dsBm.bmWidth := Width;
    DIB.dsBm.bmHeight := Height;
    DIB.dsBm.bmWidthBytes := 0;
    DIB.dsBm.bmPlanes := 1;
    DIB.dsBm.bmBitsPixel := 32;
    DIB.dsBm.bmBits := nil;

    {dsBmih - BITMAPINFOHEADER}
    DIB.dsBmih.biSize := 40;
    DIB.dsBmih.biWidth := Width;
    DIB.dsBmih.biHeight := Height;
    DIB.dsBmih.biPlanes := DIB.dsBm.bmPlanes;
    DIB.dsBmih.biCompression := 0;
    DIB.dsBmih.biSizeImage := 0;
    DIB.dsBmih.biXPelsPerMeter := 0;
    DIB.dsBmih.biYPelsPerMeter := 0;
    DIB.dsBmih.biClrUsed   := 0;
    DIB.dsBmih.biClrImportant := 0;
    DIB.dsBmih.biBitCount := 32;

    if BufSize >= SizeOf(TDIBSection) then
    begin
      PDIBSection(Buf)^ := DIB;
      Result := SizeOf(TDIBSection);
    end
    else
      if BufSize > 0 then
      begin
        System.Move(DIB, Buf^, BufSize);
        Result := BufSize;
      end;
  end
  else
  if AObject is TCarbonPen then
  begin
    if APen.IsExtPen then
    begin
      RequiredSize := SizeOf(TExtLogPen);
      if Length(APen.Dashes) > 1 then
        inc(RequiredSize, (Length(APen.Dashes) - 1) * SizeOf(DWord));
      if Buf = nil then
        Result := RequiredSize
      else
      if BufSize >= RequiredSize then
      begin
        Result := RequiredSize;
        AExtLogPen^.elpPenStyle := APen.Style;
        if APen.IsGeometric then
        begin
          case APen.JoinStyle of
            kCGLineJoinRound:
              AExtLogPen^.elpPenStyle := AExtLogPen^.elpPenStyle or PS_JOIN_ROUND;
            kCGLineJoinBevel:
              AExtLogPen^.elpPenStyle := AExtLogPen^.elpPenStyle or PS_JOIN_BEVEL;
            kCGLineJoinMiter:
              AExtLogPen^.elpPenStyle := AExtLogPen^.elpPenStyle or PS_JOIN_MITER;
          end;

          case APen.CapStyle of
            kCGLineCapRound:
              AExtLogPen^.elpPenStyle := AExtLogPen^.elpPenStyle or PS_ENDCAP_ROUND;
            kCGLineCapSquare:
              AExtLogPen^.elpPenStyle := AExtLogPen^.elpPenStyle or PS_ENDCAP_SQUARE;
            kCGLineCapButt:
              AExtLogPen^.elpPenStyle := AExtLogPen^.elpPenStyle or PS_ENDCAP_FLAT;
          end;
          AExtLogPen^.elpWidth := APen.Width;
        end
        else
          AExtLogPen^.elpWidth := 1;

        AExtLogPen^.elpBrushStyle := BS_SOLID;
        AExtLogPen^.elpColor := APen.ColorRef;
        AExtLogPen^.elpHatch := 0;

        AExtLogPen^.elpNumEntries := Length(APen.Dashes);
        if AExtLogPen^.elpNumEntries > 0 then
        begin
          for i := 0 to AExtLogPen^.elpNumEntries - 1 do
            PDword(@AExtLogPen^.elpStyleEntry)[i] := Trunc(APen.Dashes[i]);
        end
        else
          AExtLogPen^.elpStyleEntry[0] := 0;
      end;
    end
    else
    begin
      if Buf = nil then
        Result := SizeOf(TLogPen)
      else
      if BufSize >= SizeOf(TLogPen) then
      begin
        Result := SizeOf(TLogPen);
        ALogPen^.lopnStyle := APen.Style;
        ALogPen^.lopnWidth := Types.Point(APen.Width, 0);
        ALogPen^.lopnColor := APen.ColorRef;
      end;
    end;
  end
  else
  {------------------------------------------------------------------------------
    Font
   ------------------------------------------------------------------------------}
  if aObject is TCarbonFont then
  begin
    if Buf = nil then
      Result := SizeOf(TLogFont)
    else
    if BufSize >= SizeOf(TLogFont) then
    begin
      Result := SizeOf(TLogFont);

      FillChar(ALogFont^, SizeOf(ALogFont^), 0);
	  AFont.QueryStyle(ALogFont);
	end;
  end
  else
    DebugLn('TCarbonWidgetSet.GetObject Font, Brush TODO');
end;

{------------------------------------------------------------------------------
  Method:  GetParent
  Params:  Handle - Handle of child window
  Returns: The handle of the parent window

  Retrieves the handle of the specified child window's parent window.
 ------------------------------------------------------------------------------}
function TCarbonWidgetSet.GetParent(Handle: HWND): HWND;
begin
  Result := 0;

  {$IFDEF VerboseWinAPI}
    DebugLn('TCarbonWidgetSet.GetParent Handle: ' + DbgS(Handle));
  {$ENDIF}
  
  if not CheckWidget(Handle, 'GetParent') then Exit;
  
  if TCarbonWidget(Handle) is TCarbonControl then
  begin
    {$IFDEF VerboseWinAPI}
      DebugLn('TCarbonWidgetSet.GetParent Widget: ' + DbgS(TCarbonControl(Handle).Widget));
    {$ENDIF}
    Result := HWnd(GetCarbonWidget(HIViewGetSuperview(TCarbonControl(Handle).Widget)));
    if Result = 0 then // no parent control => then parent is a window?
      Result := HWnd(GetCarbonWidget(HIViewGetWindow(TCarbonControl(Handle).Widget)));
  end;
  // Carbon windows has no parent
  
  {$IFDEF VerboseWinAPI}
    DebugLn('TCarbonWidgetSet.GetParent Result: ' + DbgS(Result));
  {$ENDIF}
end;

{------------------------------------------------------------------------------
  Method:  GetProp
  Params:  Handle - Handle of window
           Str    - Property name
  Returns: The property data or nil if the property is not listed

  Retrieves a pointer to data from the property list of the specified window or
  nil if the property is not listed
 ------------------------------------------------------------------------------}
function TCarbonWidgetSet.GetProp(Handle: hwnd; Str: PChar): Pointer;
begin
  Result := nil;

  {$IFDEF VerboseWinAPI}
    DebugLn('TCarbonWidgetSet.GetProp Handle: ' + DbgS(Handle) + ' Str: ' + Str);
  {$ENDIF}
  
  if not CheckWidget(Handle, 'GetProp') then Exit;

  Result := TCarbonWidget(Handle).Properties[Str];
  
  {$IFDEF VerboseWinAPI}
    DebugLn('TCarbonWidgetSet.GetProp Result: ' + DbgS(Result));
  {$ENDIF}
end;

{------------------------------------------------------------------------------
  Method:  GetRgnBox
  Params:  RGN    - Handle to region
           lpRect - Pointer to rectangle
  Returns: See bellow

  Retrieves the specified region bounding rectangle. The result can be one of
  the following constants: ERROR, NULLREGION, SIMPLEREGION, COMPLEXREGION.
 ------------------------------------------------------------------------------}
function TCarbonWidgetSet.GetRgnBox(RGN: HRGN; lpRect: PRect): Longint;
begin
  Result := ERROR;
  if lpRect <> nil then lpRect^ := Classes.Rect(0, 0, 0, 0);
  
  {$IFDEF VerboseWinAPI}
    DebugLn('TCarbonWidgetSet.GetRgnBox RGN: ' + DbgS(RGN));
  {$ENDIF}
  
  if not (TObject(RGN) is TCarbonRegion) then
  begin
    DebugLn('TCarbonWidgetSet.GetRgnBox Error - invalid region ', DbgS(RGN), '!');
    Exit;
  end;
  
  if lpRect <> nil then
  begin
    lpRect^ := TCarbonRegion(RGN).GetBounds;
    Result := TCarbonRegion(RGN).GetType;
  end;
end;

function TCarbonWidgetSet.GetScrollBarSize(Handle: HWND; BarKind: Integer
  ): integer;
begin
  Result:=inherited GetScrollBarSize(Handle, BarKind);
end;

function TCarbonWidgetSet.GetScrollbarVisible(Handle: HWND; SBStyle: Integer
  ): boolean;
begin
  Result := False;

  {$IFDEF VerboseWinAPI}
    DebugLn('TCarbonWidgetSet.GetScrollbarVisible Handle: ' + DbgS(Handle) +
      ' SBStyle: ' + DbgS(SBStyle));
  {$ENDIF}

  if not CheckWidget(Handle, 'GetScrollbarVisible') then Exit;

  TCarbonWidget(Handle).GetScrollbarVisible(SBStyle);

  Result := True;
end;

{------------------------------------------------------------------------------
  Method:  GetScrollInfo
  Params:  Handle     - Handle of window
           SBStyle    - Scroll bar flag
           ScrollInfo - Record fo scrolling info
  Returns: If the function succeeds

  Gets the parameters of a scroll bar
 ------------------------------------------------------------------------------}
function TCarbonWidgetSet.GetScrollInfo(Handle: HWND; SBStyle: Integer;
  var ScrollInfo: TScrollInfo): Boolean;
begin
  Result := False;

  {$IFDEF VerboseWinAPI}
    DebugLn('TCarbonWidgetSet.GetScrollInfo Handle: ' + DbgS(Handle) +
      ' SBStyle: ' + DbgS(SBStyle));
  {$ENDIF}

  if not CheckWidget(Handle, 'GetScrollInfo') then Exit;

  TCarbonWidget(Handle).GetScrollInfo(SBStyle, ScrollInfo);
  
  Result := True;
end;

{------------------------------------------------------------------------------
  Method:  GetStockObject
  Params:  Value - Type of stock object
  Returns: A value identifying the logical object requested

  Retrieves a handle to one of the predefined stock objects
 ------------------------------------------------------------------------------}
function TCarbonWidgetSet.GetStockObject(Value: Integer): THandle;
begin
  Result := 0;

  {$IFDEF VerboseWinAPI}
    DebugLn('TCarbonWidgetSet.GetStockObject Value: ' + DbgS(Value));
  {$ENDIF}

  case Value of
    NULL_BRUSH: // null brush (equivalent to HOLLOW_BRUSH).
      Result := HBRUSH(StockNullBrush);
    DEFAULT_GUI_FONT, SYSTEM_FONT:
      Result := HFONT(StockSystemFont);
  else
    DebugLn('TCarbonWidgetSet.GetStockObject TODO ', DbgS(Value));
  end;
end;

{------------------------------------------------------------------------------
  Method:  GetSysColor
  Params:  NIndex - Display element whose color is to be retrieved
  Returns: RGB color value

  Retrieves the current color of the specified display element
  TODO: all system colors
 ------------------------------------------------------------------------------}
function TCarbonWidgetSet.GetSysColor(NIndex: Integer): DWORD;
var
  C: MacOSAll.RGBColor;
  Depth: SInt16;
  R: OSStatus;
begin
  Result := 0;

  {$IFDEF VerboseWinAPI}
    DebugLn('TCarbonWidgetSet.GetSysColor NIndex: ' + DbgS(NIndex));
  {$ENDIF}
  
  R := not noErr;
  
  Depth := CGDisplayBitsPerPixel(CGMainDisplayID);
  case NIndex of
  COLOR_MENU:
    R := GetThemeBrushAsColor(kThemeBrushMenuBackground, Depth, True, C{%H-});
  COLOR_MENUTEXT:
    R := GetThemeTextColor(kThemeTextColorMenuItemActive, Depth, True, C);
  COLOR_WINDOWFRAME, COLOR_ACTIVEBORDER, COLOR_INACTIVEBORDER,
  COLOR_INFOTEXT, COLOR_WINDOWTEXT:
    R := GetThemeTextColor(kThemeTextColorMenuItemActive, Depth, True, C);
  COLOR_CAPTIONTEXT:
    R := GetThemeTextColor(kThemeTextColorDocumentWindowTitleActive, Depth, True, C);
  COLOR_APPWORKSPACE:
    R := GetThemeBrushAsColor(kThemeBrushUtilityWindowBackgroundActive, Depth, True, C);
  COLOR_HIGHLIGHT:
    R := GetThemeBrushAsColor(kThemeBrushPrimaryHighlightColor, Depth, True, C);
  COLOR_HIGHLIGHTTEXT:
    R := GetThemeTextColor(kThemeTextColorPushButtonPressed, Depth, True, C);
  COLOR_SCROLLBAR, COLOR_BTNFACE:
    R := GetThemeBrushAsColor(kThemeBrushButtonFaceActive, Depth, True, C);
  COLOR_BTNSHADOW:
    R := GetThemeBrushAsColor(kThemeBrushButtonActiveDarkShadow, Depth, True, C);
  COLOR_GRAYTEXT:
    R := GetThemeTextColor(kThemeTextColorBevelButtonInactive , Depth, True, C);
  COLOR_BTNTEXT:
    R := GetThemeTextColor(kThemeTextColorPushButtonActive, Depth, True, C);
  COLOR_INACTIVECAPTIONTEXT:
    R := GetThemeTextColor(kThemeTextColorDocumentWindowTitleInactive, Depth, True, C);
  COLOR_BTNHIGHLIGHT:
    R := GetThemeBrushAsColor(kThemeBrushButtonFacePressed, Depth, True, C);
  COLOR_3DDKSHADOW:
    R := GetThemeBrushAsColor(kThemeBrushButtonActiveDarkShadow, Depth, True, C);
  COLOR_3DLIGHT:
    R := GetThemeBrushAsColor(kThemeBrushButtonActiveLightShadow, Depth, True, C);
  //COLOR_HOTLIGHT:
  COLOR_INFOBK:
    begin
      C := ColorToRGBColor(RGB(249, 252, 201));
      R := noErr;
    end;
  COLOR_BACKGROUND,
  COLOR_WINDOW, COLOR_FORM:
    R := GetThemeBrushAsColor(kThemeBrushDocumentWindowBackground, Depth, True, C);
  COLOR_ACTIVECAPTION,
  COLOR_GRADIENTACTIVECAPTION:
    R := GetThemeBrushAsColor(kThemeBrushAlternatePrimaryHighlightColor, Depth, True, C);
  COLOR_INACTIVECAPTION,
  COLOR_GRADIENTINACTIVECAPTION:
    R := GetThemeBrushAsColor(kThemeBrushSecondaryHighlightColor, Depth, True, C);
  COLOR_MENUBAR:
    R := GetThemeBrushAsColor(kThemeBrushMenuBackground, Depth, True, C);
  COLOR_MENUHILIGHT:
    R := GetThemeBrushAsColor(kThemeBrushMenuBackgroundSelected, Depth, True, C);
  else
    DebugLn('TCarbonWidgetSet.GetSysColor TODO ', DbgS(NIndex));
  end;
  
  if OSError(R, Self, 'GetSysColor', 'NIndex = ' + DbgS(NIndex)) then Exit;

  Result := RGBColorToColor(C);
    
  {$IFDEF VerboseWinAPI}
    DebugLn('TCarbonWidgetSet.GetSysColor Result: ' + DbgS(Result));
  {$ENDIF}
end;

{------------------------------------------------------------------------------
  Method:  GetSystemMetrics
  Params:  NIndex - System metric to retrieve
  Returns: The requested system metric value

  Retrieves various system metrics.
 ------------------------------------------------------------------------------}
function TCarbonWidgetSet.GetSystemMetrics(NIndex: Integer): Integer;
begin
  Result := 0;

  {$IFDEF VerboseWinAPI}
    DebugLn('TCarbonWidgetSet.GetSystemMetrics NIndex: ' + DbgS(NIndex));
  {$ENDIF}

  case NIndex of
    SM_CXHSCROLL,
    SM_CYHSCROLL,
    SM_CXVSCROLL,
    SM_CYVSCROLL:
      Result := GetCarbonThemeMetric(kThemeMetricScrollBarWidth);
    SM_CXSCREEN,
    SM_CXVIRTUALSCREEN: Result := CGDisplayPixelsWide(CGMainDisplayID);
    SM_CYSCREEN,
    SM_CYVIRTUALSCREEN: Result := CGDisplayPixelsHigh(CGMainDisplayID);
    SM_XVIRTUALSCREEN: Result := Round(CGDisplayBounds(CGMainDisplayID).origin.x);
    SM_YVIRTUALSCREEN: Result := Round(CGDisplayBounds(CGMainDisplayID).origin.y);

    SM_CXSMICON,
    SM_CYSMICON:
      Result := 16;
    SM_CXICON,
    SM_CYICON:
      Result := 128;
    SM_CXCURSOR,
    SM_CYCURSOR:
      begin
        if TCarbonCursor.HardwareCursorsSupported then
          Result := 64 else
          Result := 16;
      end;
    SM_CXHTHUMB:
      Result := GetCarbonThemeMetric(kThemeMetricScrollBarMinThumbWidth);
    SM_CYVTHUMB:
      Result := GetCarbonThemeMetric(kThemeMetricScrollBarMinThumbHeight);
    SM_SWSCROLLBARSPACING:
      Result:=0;
    SM_CYCAPTION:
      begin
        Result := GetCarbonThemeMetric(kThemeMetricTitleBarControlsHeight);
        Result := Result + (Result div 2) + 1;
      end;
    SM_CYMENU: Result := 0;
  else
    DebugLn('TCarbonWidgetSet.GetSystemMetrics TODO ', DbgS(NIndex));;
  end;
  
  {$IFDEF VerboseWinAPI}
    DebugLn('TCarbonWidgetSet.GetSystemMetrics Result: ' + DbgS(Result));
  {$ENDIF}
end;

function TCarbonWidgetSet.GetTextColor(DC: HDC): TColorRef;
begin
  Result := clNone;

  {$IFDEF VerboseWinAPI}
    DebugLn('TCarbonWidgetSet.GetTextColor DC: ' + DbgS(DC));
  {$ENDIF}

  if not CheckDC(DC, 'GetTextColor') then Exit;

  Result := TCarbonDeviceContext(DC).TextColor;

  {$IFDEF VerboseWinAPI}
    DebugLn('TCarbonWidgetSet.GetTextColor Result: ' + DbgS(Result));
  {$ENDIF}
end;

{------------------------------------------------------------------------------
  Method:  GetTextExtentPoint
  Params:  DC    - Handle of device context
           Str   - Text string
           Count - Number of characters in string
           Size  - The record for the dimensions of the string
  Returns: If the function succeeds

  Computes the width and height of the specified string of text
 ------------------------------------------------------------------------------}
function TCarbonWidgetSet.GetTextExtentPoint(DC: HDC; Str: PChar;
  Count: Integer; var Size: TSize): Boolean;
begin
  Result := False;

  {$IFDEF VerboseWinAPI}
    DebugLn('TCarbonWidgetSet.GetTextExtentPoint DC: ' + DbgS(DC) + ' Str: ' + Str);
  {$ENDIF}
  
  if not CheckDC(DC, 'GetTextExtentPoint') then Exit;

  Result := TCarbonDeviceContext(DC).GetTextExtentPoint(Str, Count, Size);
  
  {$IFDEF VerboseWinAPI}
    DebugLn('TCarbonWidgetSet.GetTextExtentPoint Size: ' + DbgS(Size));
  {$ENDIF}
end;

{------------------------------------------------------------------------------
  Method:  GetTextMetrics
  Params:  DC - Handle of device context
           TM - The Record for the text metrics
  Returns: If the function succeeds

  Fills the specified buffer with the metrics for the currently selected font
  TODO: get exact max. and av. char width, pitch and charset
 ------------------------------------------------------------------------------}
function TCarbonWidgetSet.GetTextMetrics(DC: HDC; var TM: TTextMetric): Boolean;
begin
  Result := False;

  {$IFDEF VerboseWinAPI}
    DebugLn('TCarbonWidgetSet.GetTextMetrics DC: ' + DbgS(DC));
  {$ENDIF}
  
  if not CheckDC(DC, 'GetTextMetrics') then Exit;

  Result := TCarbonDeviceContext(DC).GetTextMetrics(TM);
  
  {$IFDEF VerboseWinAPI}
    DebugLn('TCarbonWidgetSet.GetTextMetrics Result: ' + DbgS(Result) +
      ' TextMetric: ' + DbgS(TM));
  {$ENDIF}
end;

function TCarbonWidgetSet.GetWindowLong(Handle: hwnd; int: Integer): PtrInt;
begin
  Result:=inherited GetWindowLong(Handle, int);
end;

{------------------------------------------------------------------------------
  Method:  GetWindowOrgEx
  Params:  DC - Handle of device context
           P   - Record for context origin
  Returns: if the function succeeds, the return value is nonzero; if the
           function fails, the return value is zero

  Retrieves the origin of the specified context
 ------------------------------------------------------------------------------}
function TCarbonWidgetSet.GetWindowOrgEx(dc: hdc; P: PPoint): Integer;
begin
  Result := 0;
  
  {$IFDEF VerboseWinAPI}
    DebugLn('TCarbonWidgetSet.GetWindowOrgEx DC: ' + DbgS(DC));
  {$ENDIF}
  
  if not CheckDC(DC, 'GetWindowOrgEx') then Exit;

  Result:=1;
  if Assigned(P) then P^:=TCarbonDeviceContext(DC).WindowOfs;
  {$IFDEF VerboseWinAPI}
    DebugLn('TCarbonWidgetSet.GetWindowOrgEx ' + DbgS(P^.X) + ', ' + DbgS(P^.Y));
  {$ENDIF}
end;

function TCarbonWidgetSet.GetViewPortOrgEx(DC: HDC; P: PPoint): Integer;
begin
  Result := 0;

  {$IFDEF VerboseWinAPI}
    DebugLn('TCarbonWidgetSet.GetViewPortOrgEx DC: ' + DbgS(DC));
  {$ENDIF}

  if not CheckDC(DC, 'GetViewPortOrgEx') then Exit;

  Result:=1;
  if Assigned(P) then P^:=TCarbonDeviceContext(DC).ViewPortOfs;
  {$IFDEF VerboseWinAPI}
    DebugLn('TCarbonWidgetSet.GetWindowOrgEx ' + DbgS(P^.X) + ', ' + DbgS(P^.Y));
  {$ENDIF}
end;

{------------------------------------------------------------------------------
  Method:  GetWindowRect
  Params:  Handle - Handle of window
           Rect   - Record for window coordinates
  Returns: if the function succeeds, the return value is nonzero; if the
           function fails, the return value is zero

  Retrieves the screen bounding rectangle of the specified window
 ------------------------------------------------------------------------------}
function TCarbonWidgetSet.GetWindowRect(Handle: hwnd; var ARect: TRect): Integer;
begin
  Result := 0;

  {$IFDEF VerboseWinAPI}
    DebugLn('TCarbonWidgetSet.GetWindowRect Handle: ' + DbgS(Handle));
  {$ENDIF}
  
  if not CheckWidget(Handle, 'GetWindowRect') then Exit;
  Result := Integer(TCarbonWidget(Handle).GetScreenBounds(ARect));
  
  {$IFDEF VerboseWinAPI}
    DebugLn('TCarbonWidgetSet.GetWindowRect R: ' + DbgS(ARect));
  {$ENDIF}
end;

{------------------------------------------------------------------------------
  Method:  GetWindowRelativePosition
  Params:  Handle - Handle of window
  Returns: If function succeeds

  Returns the window left and top relative to the client origin of its
  parent
 ------------------------------------------------------------------------------}
function TCarbonWidgetSet.GetWindowRelativePosition(Handle: hwnd; var Left,
  Top: integer): boolean;
var
  ARect: TRect;
begin
  Result := False;

  {$IFDEF VerboseWinAPI}
    DebugLn('TCarbonWidgetSet.GetWindowRelativePosition Handle: ' + DbgS(Handle));
  {$ENDIF}
  
  if not CheckWidget(Handle, 'GetWindowRelativePosition') then Exit;
  Result := TCarbonWidget(Handle).GetBounds(ARect{%H-});
  
  if not Result then Exit;
  Left := ARect.Left;
  Top := ARect.Top;
  
  {$IFDEF VerboseWinAPI}
    DebugLn('TCarbonWidgetSet.GetWindowRelativePosition Left: ' + DbgS(Left) +
      ' Top: ' + DbgS(Top));
  {$ENDIF}
end;

{------------------------------------------------------------------------------
  Function: GetWindowSize
  Params:   Handle - Handle of window
            Width
            Height
  Returns:  If function succeeds

  Returns the width and height of the specified window
 ------------------------------------------------------------------------------}
function TCarbonWidgetSet.GetWindowSize(Handle: hwnd; var Width, Height: integer
  ): boolean;
var
  ARect: TRect;
begin
  Result := False;

  {$IFDEF VerboseWinAPI}
    DebugLn('TCarbonWidgetSet.GetWindowSize Handle: ' + DbgS(Handle));
  {$ENDIF}
  
  if not CheckWidget(Handle, 'GetWindowSize') then Exit;
  Result := TCarbonWidget(Handle).GetBounds(ARect{%H-});
    
  if not Result then Exit;
  Width := ARect.Right - ARect.Left;
  Height := ARect.Bottom - ARect.Top;
  
  {$IFDEF VerboseWinAPI}
    DebugLn('TCarbonWidgetSet.GetWindowSize Width: ' + DbgS(Width) + ' Height:'
      + DbgS(Height));
  {$ENDIF}
end;

type
  TColorComponents = array[0..3] of CGFloat;

  PLinearGradientInfo = ^TLinearGradientInfo;
  TLinearGradientInfo = record
    colors: array[0..1] of TColorComponents;
  end;

function VertexToColor(AVertex: tagTRIVERTEX): TColorComponents;
var
  TheAlpha: Byte;
begin
  TheAlpha := AVertex.Alpha shr 8;
  if TheAlpha = 0 then
    TheAlpha := 255;
  with AVertex do
  begin
    Result[0] := (Red shr 8) / 255;
    Result[1] := (Green shr 8) / 255;
    Result[2] := (Blue shr 8 )/ 255;
    Result[3] := TheAlpha / 255;
  end;
end;

function LinearGradientCreateInfo(TL, BR: tagTRIVERTEX): UnivPtr;
var
  Swap: Longint;
  SwapColors: Boolean;
  Info: PLinearGradientInfo;
  Tmp: TColorComponents;
begin
  GetMem(Info, SizeOf(TLinearGradientInfo));
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
  Info^.colors[0] := VertexToColor(TL);
  Info^.colors[1] := VertexToColor(BR);
  if SwapColors then
  begin
    Tmp := Info^.colors[0];
    Info^.colors[0] := Info^.colors[1];
    Info^.colors[1] := Tmp;
  end;
  Result:=Info;
end;

procedure LinearGradientReleaseInfo(info: UnivPtr); mwpascal;
begin
  FreeMem(info);
end;

procedure LinearGradientEvaluate(info: UnivPtr; inputValue: CGFloatPtr; outputValue: CGFloatPtr); mwpascal;
var
  GradientInfo: PLinearGradientInfo absolute info;
  Position: CGFloat;
  I: Integer;
begin
  if not Assigned(GradientInfo) then
    Exit;
  Position := inputValue^;
  if Position = 0 then
    System.Move(GradientInfo^.colors[0], outputValue^, SizeOf(TColorComponents))
  else
    for I := 0 to 3 do
      outputValue[I] := GradientInfo^.colors[0][I] + Position * (GradientInfo^.colors[1][I] - GradientInfo^.colors[0][I]);
end;

function TCarbonWidgetSet.GradientFill(DC: HDC; Vertices: PTriVertex;
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

  function FillRectMesh(Mesh: tagGradientRect) : boolean;
  var
    TL, BR: tagTRIVERTEX;
    Shading: CGShadingRef;
    ShadingFunction: CGFunctionRef;
    ShadingCallbacks: CGFunctionCallbacks;
    Context: CGContextRef;
    domain: array[0..1] of CGFloat;
    range: array[0..7] of CGFloat;
    info: UnivPtr;
  begin
    with Mesh do
    begin
      Result :=
        (UpperLeft < Cardinal(NumVertices)) {and (UpperLeft >= 0)} and
        (LowerRight < Cardinal(NumVertices)) {and (LowerRight >= 0)};
      if (LowerRight = UpperLeft) or not Result then
        Exit;

      TL := Vertices[UpperLeft];
      BR := Vertices[LowerRight];
      info := LinearGradientCreateInfo(TL, BR);
      Context := TCarbonDeviceContext(DC).CGContext;
      CGContextSaveGState(Context);
      // to draw a gradient in a rectangle we need to first clip it by that
      // rectangle and only then draw the gradient
      CGContextAddRect(Context, CGRectMake(TL.X, TL.Y, BR.X - TL.X, BR.Y - TL.Y));
      CGContextClip(Context);

      ShadingCallbacks.version := 0;
      ShadingCallbacks.evaluate := @LinearGradientEvaluate;
      ShadingCallbacks.releaseInfo := @LinearGradientReleaseInfo;
      domain[0] := 0;
      domain[1] := 1;
      range[0] := 0;
      range[1] := 1;
      range[2] := 0;
      range[3] := 1;
      range[4] := 0;
      range[5] := 1;
      range[6] := 0;
      range[7] := 1;
      ShadingFunction := CGFunctionCreate(Info, 1, @domain[0], 4, @range[0], ShadingCallbacks);
      if DoFillVRect then
        Shading := CGShadingCreateAxial(RGBColorSpace, CGPointMake(TL.X, TL.Y), CGPointMake(TL.X, BR.Y), ShadingFunction, 0, 0)
      else
        Shading := CGShadingCreateAxial(RGBColorSpace, CGPointMake(TL.X, TL.Y), CGPointMake(BR.X, TL.Y), ShadingFunction, 0, 0);

      CGContextDrawShading(Context, Shading);
      CGShadingRelease(Shading);
      CGContextRestoreGState(Context);
    end;
  end;

var
  i: Integer;
begin
  if not CheckDC(DC, 'GradientFill') then Exit(False);
  Result := (Meshes <> nil) and (NumMeshes >= 1) and (NumVertices >= 2)
          and (Vertices <> nil);
  if Result and DoFillTriangle then
  begin
    Result := inherited;
    Exit;
  end;

  if Result then
  begin
    Result := False;

    //Sanity Checks For Vertices Size vs. Count
    if MemSize(Vertices) < PtrUInt(SizeOf(tagTRIVERTEX)*NumVertices) then
      exit;

    for I := 0 to NumMeshes - 1 do
    begin
      if not FillRectMesh(PGradientRect(Meshes)[I]) then
        exit;
    end;
    Result := True;
  end;
end;

{------------------------------------------------------------------------------
  Method:  HideCaret
  Params:  HWnd - handle to the window with the caret
  Returns: Whether the window owns the caret

  Removes the caret from the screen.
 ------------------------------------------------------------------------------}
function TCarbonWidgetSet.HideCaret(hWnd: HWND): Boolean;
begin
  Result := False;
  {$IFDEF VerboseWinAPI}
    DebugLn('TCarbonWidgetSet.HideCaret Handle: ' + DbgS(hWnd));
  {$ENDIF}
  if not CheckWidget(hWnd, 'HideCaret') then Exit;

  Result := CarbonCaret.HideCaret(TCarbonWidget(hWnd));
end;

{------------------------------------------------------------------------------
  Method:  InitializeCriticalSection
  Params:  CritSection - Record for initialized critical section

  Creates a new critical section
 ------------------------------------------------------------------------------}
procedure TCarbonWidgetSet.InitializeCriticalSection(
  var CritSection: TCriticalSection);
var
  ACritSec: System.PRTLCriticalSection;
begin
  New(ACritSec);
  
  System.InitCriticalSection(ACritSec^);
  CritSection := {%H-}TCriticalSection(ACritSec);
  
  {$IFDEF VerboseWinAPI}
    DebugLn('TCarbonWidgetSet.InitializeCriticalSection Section: ' + DbgS(CritSection));
  {$ENDIF}
end;

{------------------------------------------------------------------------------
  Method:  IntersectClipRect
  Params:  DC - Handle to device context
           Left, Top, Right, Bottom - Rectangle coordinates
  Returns: See bellow

  Changes the current clipping region of the device context to intersection with
  the specified rectangle. The result can be one of the following constants:
  ERROR, NULLREGION, SIMPLEREGION, COMPLEXREGION.
 ------------------------------------------------------------------------------}
function TCarbonWidgetSet.IntersectClipRect(DC: HDC; Left, Top, Right,
  Bottom: Integer): Integer;
begin
  //todo: remove, as not used  
  Result := inherited IntersectClipRect(DC, Left, Top, Right, Bottom);
end;

{------------------------------------------------------------------------------
  Method:  InvalidateRect
  Params:  AHandle - Handle of window
           Rect    - Pointer to rectangle coordinates
           BErase  - Specifies whether the background is to be erased
  Returns: If the function succeeds

  Adds a rectangle to the specified window's update region
 ------------------------------------------------------------------------------}
function TCarbonWidgetSet.InvalidateRect(AHandle: HWND; Rect: pRect;
  bErase: Boolean): Boolean;
var
  Pt: TPoint;
begin
  Result := False;

  {$IFDEF VerboseWinAPI}
    DebugLn('TCarbonWidgetSet.InvalidateRect Handle: ' + DbgS(AHandle));
  {$ENDIF}
  
  if not CheckWidget(AHandle, 'InvalidateRect') then Exit;

  if Rect <> nil then
  begin
    Pt := TCarbonWidget(AHandle).ScrollOffset;
    OffsetRect(Rect^, -Pt.X, -Pt.Y);
  end;
  TCarbonWidget(AHandle).Invalidate(Rect);
  Result := True;
end;

{------------------------------------------------------------------------------
  Method:  InvalidateRgn
  Params:  Handle - handle of window with changed update region
           Rgn    - handle to region to invalidate
           Erase  - specifies whether the background is to be erased
  Returns: if the function succeeds

  Adds a region to the specified window's update region.
 ------------------------------------------------------------------------------}
function TCarbonWidgetSet.InvalidateRgn(Handle: HWND; Rgn: HRGN; Erase: Boolean): Boolean;
begin
  Result := False;

  {$IFDEF VerboseWinAPI}
    DebugLn('TCarbonWidgetSet.InvalidateRgn Handle: ' + DbgS(Handle));
  {$ENDIF}
  
  if not CheckWidget(Handle, 'InvalidateRgn') then Exit;
  if (Rgn <> 0) and not (TObject(Rgn) is TCarbonRegion) then
  begin
    DebugLn('TCarbonWidgetSet.InvalidateRgn Error - invalid region: ', DbgS(Rgn), '!');
    Exit;
  end;

  if Rgn = 0 then
    TCarbonWidget(Handle).Invalidate(nil)
  else
    TCarbonWidget(Handle).InvalidateRgn(TCarbonRegion(Rgn).Shape);
  Result := True;
end;

function TCarbonWidgetSet.IsIconic(Handle: HWND): boolean;
begin
  if not CheckWidget(Handle, 'IsIconic') then Exit(False);
  Result := (TCarbonWidget(Handle) is TCarbonWindow) and TCarbonWindow(Handle).IsIconic;
end;


{------------------------------------------------------------------------------
  Method:  IsWindow
  Params:  Handle - Handle of window
  Returns: True if handle is carbonwidget, False otherwise
 ------------------------------------------------------------------------------}
function TCarbonWidgetSet.IsWindow(handle: HWND): boolean;
var
  obj : TObject;
begin
  //todo: better code?!
  obj:=TObject(Handle);
  try
    Result:=Assigned(obj) and (obj is TCarbonWidget);
  except
    Result:=False;
  end;
end;

{------------------------------------------------------------------------------
  Method:  IsWindowEnabled
  Params:  Handle - Handle of window
  Returns: True if window is enabled, false otherwise
 ------------------------------------------------------------------------------}
function TCarbonWidgetSet.IsWindowEnabled(Handle: HWND): boolean;
begin
  Result := False;

  {$IFDEF VerboseWinAPI}
    DebugLn('TCarbonWidgetSet.IsWindowEnabled Handle: ' + DbgS(Handle));
  {$ENDIF}
  
  if not CheckWidget(Handle, 'IsWindowEnabled') then Exit;
  Result := TCarbonWidget(Handle).IsEnabled;
  
  {$IFDEF VerboseWinAPI}
    DebugLn('TCarbonWidgetSet.IsWindowEnabled Result: ' + DbgS(Result));
  {$ENDIF}
end;

{------------------------------------------------------------------------------
  Method:  IsWindowVisible
  Params:  Handle - Handle of window
  Returns: True if window is visible, false otherwise
 ------------------------------------------------------------------------------}
function TCarbonWidgetSet.IsWindowVisible(Handle: HWND): boolean;
begin
  Result := False;

  {$IFDEF VerboseWinAPI}
    DebugLn('TCarbonWidgetSet.IsWindowVisible Handle: ' + DbgS(Handle));
  {$ENDIF}
  
  if not CheckWidget(Handle, 'IsWindowVisible') then Exit;
  Result := TCarbonWidget(Handle).IsVisible;
  
   {$IFDEF VerboseWinAPI}
    DebugLn('TCarbonWidgetSet.IsWindowVisible Result: ' + DbgS(Result));
  {$ENDIF}
end;

function TCarbonWidgetSet.IsZoomed(Handle: HWND): boolean;
begin
  if not CheckWidget(Handle, 'IsZoomed') then Exit(False);
  Result := (TCarbonWidget(Handle) is TCarbonWindow) and TCarbonWindow(Handle).IsZoomed;
end;

{------------------------------------------------------------------------------
  Method:  LeaveCriticalSection
  Params:  CritSection - Critical section to be left

  Leaves the specified critical section
 ------------------------------------------------------------------------------}
procedure TCarbonWidgetSet.LeaveCriticalSection(
  var CritSection: TCriticalSection);
var
  ACritSec: System.PRTLCriticalSection;
begin
  {$IFDEF VerboseWinAPI}
    DebugLn('TCarbonWidgetSet.LeaveCriticalSection Section: ' + DbgS(CritSection));
  {$ENDIF}
  
  ACritSec := {%H-}System.PRTLCriticalSection(CritSection);
  System.LeaveCriticalsection(ACritSec^);
end;

{------------------------------------------------------------------------------
  Method:  LineTo
  Params:  DC - Handle to device context
           X  - X-coordinate of line's ending point
           Y  - Y-coordinate of line's ending point
  Returns: If the function succeeds

  Draws a line from the current position up to the specified point and updates
  the current position
 ------------------------------------------------------------------------------}
function TCarbonWidgetSet.LineTo(DC: HDC; X, Y: Integer): Boolean;
begin
  Result := False;

  {$IFDEF VerboseWinAPI}
    DebugLn('TCarbonWidgetSet.LineTo DC: ' + DbgS(DC) + ' ' + DbgS(X) + ', ' +
      DbgS(Y));
  {$ENDIF}
  
  if not CheckDC(DC, 'LineTo') then Exit;

  TCarbonDeviceContext(DC).LineTo(X, Y);

  Result := True;
end;

function TCarbonWidgetSet.LPtoDP(DC: HDC; var Points; Count: Integer): BOOL;
var
  P: PPoint;
begin
  Result := False;
  if not CheckDC(DC, 'LPtoDP') then Exit;
  P := @Points;
  with TCarbonDeviceContext(DC).GetLogicalOffset do
    while Count > 0 do
    begin
      Dec(Count);
      inc(P^.X, X);
      inc(P^.Y, Y);
      inc(P);
    end;
  Result := True;
end;

function TCarbonWidgetSet.MessageBox(hWnd: HWND; lpText, lpCaption: PChar;
  uType: Cardinal): integer;
begin
  Result:=inherited MessageBox(hWnd, lpText, lpCaption, uType);
end;

{------------------------------------------------------------------------------
  Method:  MoveToEx
  Params:  DC       - Handle to device context
           X        - X-coordinate of new current position
           Y        - Y-coordinate of new current position
           OldPoint - Pointer to old current position
  Returns: If the function succeeds.

  Updates the current position to the specified point
 ------------------------------------------------------------------------------}
function TCarbonWidgetSet.MoveToEx(DC: HDC; X, Y: Integer; OldPoint: PPoint): Boolean;
var
  ADC: TCarbonDeviceContext;
  TempPenPos: TPoint;
begin
  Result := False;

  {$IFDEF VerboseWinAPI}
    DebugLn('TCarbonWidgetSet.MoveToEx DC: ' + DbgS(DC) + ' ' + DbgS(X) + ', ' +
      DbgS(Y));
  {$ENDIF}
  
  if not CheckDC(DC, 'MoveToEx') then Exit;

  ADC := TCarbonDeviceContext(DC);

  if OldPoint <> nil then OldPoint^ := ADC.PenPos;

  { We need a temporary variable or this wont compile with 2.3.x }
  TempPenPos.X := X;
  TempPenPos.Y := Y;
  ADC.PenPos := TempPenPos;
  
  Result := True;
end;

{------------------------------------------------------------------------------
  Method:  MoveWindowOrgEx
  Params:  DC - Handle to device context
           DX - Horizontal shift
           DY - Vertical shift
  Returns: If the function succeeds

  Moves origin of the device context by the specified shift
 ------------------------------------------------------------------------------}
function TCarbonWidgetSet.MoveWindowOrgEx(DC: HDC; dX, dY: Integer): Boolean;
begin
  Result := inherited MoveWindowOrgEx(DC, dX, dY);
end;

function TCarbonWidgetSet.OffsetRgn(RGN: HRGN; nXOffset, nYOffset: Integer): Integer;
begin
  if not (TObject(RGN) is TCarbonRegion) then
    Exit(ERROR);
  TCarbonRegion(RGN).Offset(nXOffset, nYOffset);
  Result := TCarbonRegion(RGN).GetType;
end;

function TCarbonWidgetSet.PeekMessage(var lpMsg: TMsg; Handle: HWND;
  wMsgFilterMin, wMsgFilterMax, wRemoveMsg: UINT): Boolean;
begin
  Result:=inherited PeekMessage(lpMsg, Handle, wMsgFilterMin, wMsgFilterMax,
    wRemoveMsg);
end;

{------------------------------------------------------------------------------
  Method:  PolyBezier
  Params:  DC        - Handle to device context
           Points    - Points defining the cubic Bézier curve
           NumPts    - Number of points passed
           Filled    - Fill the drawed shape
           Continous - Connect Bézier curves
  Returns: If the function succeeds

  Draws a cubic Bézier curves. The first curve is drawn from the first point to
  the fourth point with the second and third points being the control points.
 ------------------------------------------------------------------------------}
function TCarbonWidgetSet.PolyBezier(DC: HDC; Points: PPoint; NumPts: Integer;
  Filled, Continuous: boolean): boolean;
begin
  Result := False;

  {$IFDEF VerboseWinAPI}
    DebugLn('TCarbonWidgetSet.PolyBezier DC: ' + DbgS(DC) + ' NumPts: ' +
      DbgS(NumPts) + ' Filled: ' + DbgS(Filled) + ' Continuous: ' +
      DbgS(Continuous));
  {$ENDIF}
  
  if not CheckDC(DC, 'PolyBezier') then Exit;
  if Points = nil then Exit;
  if NumPts < 4 then Exit;

  TCarbonDeviceContext(DC).PolyBezier(Points, NumPts, Filled, Continuous);

  Result := True;
end;

{------------------------------------------------------------------------------
  Method:  Polygon
  Params:  DC      - Handle to device context
           Points  - Pointer to polygon's vertices
           NumPts  - Number of polygon's vertices
           Winding - Use winding fill rule
  Returns: If the function succeeds

  Draws a closed, many-sided shape on the canvas, using the pen and brush.
  If Winding is set, Polygon fills the shape using the Winding fill algorithm.
  Otherwise, Polygon uses the even-odd (alternative) fill algorithm. The first
  point is always connected to the last point.
 ------------------------------------------------------------------------------}
function TCarbonWidgetSet.Polygon(DC: HDC; Points: PPoint; NumPts: Integer;
  Winding: boolean): boolean;
begin
  Result := False;

  {$IFDEF VerboseWinAPI}
    DebugLn('TCarbonWidgetSet.Polygon DC: ' + DbgS(DC) + ' NumPts: ' +
      DbgS(NumPts) + ' Winding: ' + DbgS(Winding));
  {$ENDIF}
  
  if not CheckDC(DC, 'Polygon') then Exit;
  if Points = nil then Exit;
  if NumPts < 2 then Exit;

  TCarbonDeviceContext(DC).Polygon(Points, NumPts, Winding);
    
  Result := True;
end;

{------------------------------------------------------------------------------
  Method:  Polyline
  Params:  DC     - Handle to device context
           Points - Pointer to array containing points
           NumPts - Number of points in the array
  Returns: If the function succeeds

  Draws a series of line segments by connecting the points in the specified
  array
 ------------------------------------------------------------------------------}
function TCarbonWidgetSet.Polyline(DC: HDC; Points: PPoint; NumPts: Integer): boolean;
begin
  Result := False;

  {$IFDEF VerboseWinAPI}
    DebugLn('TCarbonWidgetSet.Polyline DC: ' + DbgS(DC) + ' NumPts: ' + DbgS(NumPts));
  {$ENDIF}
  
  if not CheckDC(DC, 'Polyline') then Exit;
  if Points = nil then Exit;

  TCarbonDeviceContext(DC).Polyline(Points, NumPts);

  Result := True;
end;

function TCarbonWidgetSet.PostMessage(Handle: HWND; Msg: Cardinal;
  wParam: WParam; lParam: LParam): Boolean;
var
  UserEvent: EventRef;
  EventTarget: EventTargetRef;
begin
  Result := False;
  if not CheckWidget(Handle, 'PostMessage') then Exit;

  UserEvent := nil;
  try
    UserEvent := PrepareUserEvent(Handle, Msg, wParam, lParam, EventTarget);
    if UserEvent = nil then
      Exit;

    SetEventParameter(UserEvent, kEventParamPostTarget, typeEventTargetRef,
      SizeOf(EventTarget), @EventTarget);
      
    if PostEventToQueue(FMainEventQueue, UserEvent, kEventPriorityStandard) <> noErr then
      Exit;
  finally
    if UserEvent <> nil then 
      ReleaseEvent(UserEvent);
  end;
  Result := True;
end;

{------------------------------------------------------------------------------
  Method:  PtInRegion
  Params:  RNG  - Handle to region
           X, Y - Point
  Returns: If the specified point lies in the region
 ------------------------------------------------------------------------------}
function TCarbonWidgetSet.PtInRegion(RGN: HRGN; X, Y: Integer): Boolean;
begin
  Result := False;

  {$IFDEF VerboseWinAPI}
    DebugLn('TCarbonWidgetSet.PtInRegion RGN: ' + DbgS(RGN), ' X: ', DbgS(X),
      ' Y: ', DbgS(Y));
  {$ENDIF}

  if not (TObject(RGN) is TCarbonRegion) then
  begin
    DebugLn('TCarbonWidgetSet.PtInRegion Error - invalid region ', DbgS(RGN), '!');
    Exit;
  end;

  Result := TCarbonRegion(RGN).ContainsPoint(Classes.Point(X, Y));
  
  {$IFDEF VerboseWinAPI}
    DebugLn('TCarbonWidgetSet.PtInRegion Result: ' + DbgS(Result));
  {$ENDIF}
end;

function TCarbonWidgetSet.RadialArc(DC: HDC; left, top, right, bottom, sx, sy, ex,
  ey: Integer): Boolean;
begin
  Result:=inherited RadialArc(DC, left, top, right, bottom, sx, sy, ex, ey);
end;

function TCarbonWidgetSet.RadialChord(DC: HDC; x1, y1, x2, y2, sx, sy, ex,
  ey: Integer): Boolean;
begin
  Result:=inherited RadialChord(DC, x1, y1, x2, y2, sx, sy, ex, ey);
end;

function TCarbonWidgetSet.RealizePalette(DC: HDC): Cardinal;
begin
  Result:=inherited RealizePalette(DC);
end;

{------------------------------------------------------------------------------
  Method:  Rectangle
  Params:  DC - Handle to device context
           X1 - X-coordinate of bounding rectangle's upper-left corner
           Y1 - Y-coordinate of bounding rectangle's upper-left corner
           X2 - X-coordinate of bounding rectangle's lower-right corner
           Y2 - Y-coordinate of bounding rectangle's lower-right corner
  Returns: If the function succeeds

  Draws a rectangle. The rectangle is outlined by using the current pen and
  filled by using the current brush.
 ------------------------------------------------------------------------------}
function TCarbonWidgetSet.Rectangle(DC: HDC; X1, Y1, X2, Y2: Integer): Boolean;
begin
  Result := False;
  
  {$IFDEF VerboseWinAPI}
    DebugLn('TCarbonWidgetSet.Rectangle DC: ' + DbgS(DC) + ' R: ' +
      DbgS(Classes.Rect(X1, Y1, X2, Y2)));
  {$ENDIF}
  
  if not CheckDC(DC, 'Rectangle') then Exit;

  TCarbonDeviceContext(DC).Rectangle(X1, Y1, X2, Y2);

  Result := True;
end;

{------------------------------------------------------------------------------
  Method:  RectVisible
  Params:  DC    - Handle to device context
           ARect - Rectangle to test
  Returns: If the rectangle is not completely clipped away
 ------------------------------------------------------------------------------}
function TCarbonWidgetSet.RectVisible(DC: HDC; const ARect: TRect): Boolean;
var
  ClipBox: CGRect;
  R: TRect;
begin
  Result := False;

  {$IFDEF VerboseWinAPI}
    DebugLn('TCarbonWidgetSet.RectVisible DC: ' + DbgS(DC) + ' R: ' + DbgS(ARect));
  {$ENDIF}
  
  if not CheckDC(DC, 'RectVisible') then Exit;
  if (ARect.Right <= ARect.Left) or (ARect.Bottom <= ARect.Top) then Exit;
  
  // In Quartz 2D there is no direct access to clipping path of CGContext,
  // therefore we can only test bounding box of the clipping path.
  
  ClipBox := CGContextGetClipBoundingBox(TCarbonContext(DC).CGContext);
  Result := IntersectRect(R{%H-}, ARect, CGRectToRect(ClipBox));
  
  {$IFDEF VerboseWinAPI}
    DebugLn('TCarbonWidgetSet.RectVisible Result: ' + DbgS(Result) + ' Clip: ' + DbgS(CGRectToRect(ClipBox)));
  {$ENDIF}
end;

function TCarbonWidgetSet.RegroupMenuItem(hndMenu: HMENU; GroupIndex: integer
  ): Boolean;
begin
  Result:=inherited RegroupMenuItem(hndMenu, GroupIndex);
end;

{------------------------------------------------------------------------------
  Method:  ReleaseCapture
  Returns: If the function succeeds

  Releases the mouse capture from a window and restores normal mouse input
  processing
  TODO: not only release capture indicator
 ------------------------------------------------------------------------------}
function TCarbonWidgetSet.ReleaseCapture: Boolean;
begin
  Result := False;

  {$IFDEF VerboseWinAPI}
    DebugLn('TCarbonWidgetSet.ReleaseCapture');
  {$ENDIF}
  
  SetCaptureWidget(0);
  
  Result := True;
end;

{------------------------------------------------------------------------------
  Method:  ReleaseDC
  Params:  HWnd - Handle of window
           DC   - Handle of device context
  Returns: 1 if the device context was released or 0 if it wasn't

  Releases a device context (DC), freeing it for use by other applications
 ------------------------------------------------------------------------------}
function TCarbonWidgetSet.ReleaseDC(HWnd: HWND; DC: HDC): Integer;
var
  Context: TCarbonDeviceContext;
begin
  Result := 0;

  {$IFDEF VerboseWinAPI}
    DebugLn('TCarbonWidgetSet.ReleaseDC HWnd: ' + DbgS(HWnd) + ' DC: ' + DbgS(DC));
  {$ENDIF}
  
  if not CheckDC(DC, 'ReleaseDC') then Exit;
  Context := TCarbonDeviceContext(DC);
  if (Context <> DefaultContext) and (Context is TCarbonControlContext) and
    (Context.CGContext = DefaultContext.CGContext) then Context.Free;

  Result := 1;
end;

{------------------------------------------------------------------------------
  Method:  RemoveProp
  Params:  Handle - Handle of window
           Str    - Property name
  Returns: Property data or nil if the property is not listed

  Removes the an existing entry from the property list of the
  specified window
 ------------------------------------------------------------------------------}
function TCarbonWidgetSet.RemoveProp(Handle: hwnd; Str: PChar): THandle;
begin
  Result := 0;

  {$IFDEF VerboseWinAPI}
    DebugLn('TCarbonWidgetSet.RemoveProp Handle: ' + DbgS(Handle) + ' Str: ' +
      DbgS(Str));
  {$ENDIF}
  
  if not CheckWidget(Handle, 'RemoveProp') then Exit;

  Result := {%H-}THandle(TCarbonWidget(Handle).Properties[Str]);
  TCarbonWidget(Handle).Properties[Str] := nil;
end;

{------------------------------------------------------------------------------
  Method:  RestoreDC
  Params:  DC      - Handle to device context
           SavedDC - Index of saved DC
  Returns: If the function succeeds

  Resores state of the device context to the state with the specified index
 ------------------------------------------------------------------------------}
function TCarbonWidgetSet.RestoreDC(DC: HDC; SavedDC: Integer): Boolean;
begin
  Result := False;

  {$IFDEF VerboseWinAPI}
    DebugLn('TCarbonWidgetSet.RestoreDC DC: ' + DbgS(DC) + ' SavedDC: ' +
      DbgS(SavedDC));
  {$ENDIF}
  
  if not CheckDC(DC, 'RestoreDC') then Exit;

  Result := TCarbonDeviceContext(DC).RestoreDC(SavedDC);
  
  {$IFDEF VerboseWinAPI}
    DebugLn('TCarbonWidgetSet.RestoreDC Result: ' + DbgS(Result));
  {$ENDIF}
end;

function TCarbonWidgetSet.RoundRect(DC: hDC; X1, Y1, X2, Y2: Integer; RX,
  RY: Integer): Boolean;
begin
  Result:=inherited RoundRect(DC, X1, Y1, X2, Y2, RX, RY);
end;

{------------------------------------------------------------------------------
  Method:  SaveDC
  Params:  DC - Handle to device context
  Returns: Saved DC index or 0 if failed

  Saves current state of the device context and returns its index
 ------------------------------------------------------------------------------}
function TCarbonWidgetSet.SaveDC(DC: HDC): Integer;
begin
  Result := 0;

  {$IFDEF VerboseWinAPI}
    DebugLn('TCarbonWidgetSet.SaveDC DC: ' + DbgS(DC));
  {$ENDIF}
  
  if not CheckDC(DC, 'SaveDC') then Exit;
  
  Result := TCarbonDeviceContext(DC).SaveDC;
  
  {$IFDEF VerboseWinAPI}
    DebugLn('TCarbonWidgetSet.SaveDC Result: ' + DbgS(Result));
  {$ENDIF}
end;

function TCarbonWidgetSet.ScreenToClient(Handle: HWND; var P: TPoint): Integer;
var
  R: TRect;
  Pt: TPoint;
begin
  // Result:=inherited ScreenToClient(Handle, P);
  Result := 0;
  {$IFDEF VerboseWinAPI}
    DebugLn('TCarbonWidgetSet.ScreenToClient P: ' + DbgS(P));
  {$ENDIF}

  if not CheckWidget(Handle, 'ScreenToClient') then Exit;
  if not TCarbonWidget(Handle).GetScreenBounds(R{%H-}) then exit;
  // DebugLn('TCarbonWidgetSet.ScreenToClient Control screen bounds: ',dbgs(R));
  Dec(P.X, R.Left);
  Dec(P.Y, R.Top);

  if not TCarbonWidget(Handle).GetClientRect(R) then exit;

  Dec(P.X, R.Left);
  Dec(P.Y, R.Top);
  Pt := TCarbonWidget(Handle).ScrollOffset;
  Inc(P.X, Pt.X);
  Inc(P.Y, Pt.Y);
end;

{$IFDEF NewScrollWindowEx}
function TCarbonWidgetSet.ScrollWindowEx(hWnd: HWND; dx, dy: Integer;
  prcScroll, prcClip: PRect; hrgnUpdate: HRGN; prcUpdate: PRect; flags: UINT
  ): Boolean;
const
  SName = 'ScrollWindowEx';
var
  ACtl: TCarbonControl;
  RFullSource: TRect;
  R, R1: CGRect;
  RR: TRect;
begin
  (* - On Windows prcScroll is used a source-rectangle. The Result can (and will)
       be placed outside that area. It may be limited by prcClip.
     - Carbon uses the rect given to HIViewScrollRect as source and Clip.
       So to get the same effect as on Windows prcScroll may need to be extended
     - SW_INVALIDATE: Carbon always invalidates. So nothing to do if the flag is set.
       Todo: If it is not set, and if it was known that the area was not already
       invalidated before, then maybe it can be re-validadet?
  *)
  {$IFDEF VerboseWinAPI}
  DebugLn('TCarbonWidgetSet.ScrollWindowEx() HWnd=',dbgs(hWnd),' prcScroll ',dbgs(prcScroll <> nil),
    ' prcClip ',dbgs(prcClip <> nil));
  {$ENDIF}
  Result := False;
  if (dy = 0) and (dx = 0) then exit;
  if (hWnd = 0) then exit;

  ACtl := TCarbonControl(hWnd);
  OSError(HIViewGetBounds(ACtl.Content, R1),
    Self, SName, 'HIViewGetBounds');

  RFullSource := CGRectToRect(R1);
  {$ifdef VerboseScrollWindowEx}
  DebugLn(['ScrollWindowEx A RFullSource=', dbgs(RFullSource),' dy=',dy, ' scroll=',dbgs(prcScroll^), ' clip=',dbgs(prcClip^)]);
  {$ENDIF}

  if PrcScroll <> nil then
  begin
    RFullSource.Left   := Max(RFullSource.Left,   PrcScroll^.Left);
    RFullSource.Top    := Max(RFullSource.Top,    PrcScroll^.Top);
    RFullSource.Right  := Min(RFullSource.Right,  PrcScroll^.Right);
    RFullSource.Bottom := Min(RFullSource.Bottom, PrcScroll^.Bottom);

    // extend
    if dx < 0 then
      RFullSource.Left := RFullSource.Left + dx;
    if dx > 0 then
      RFullSource.Right := RFullSource.Right + dx;
    if dy < 0 then
      RFullSource.Top := RFullSource.Top + dy;
    if dy > 0 then
      RFullSource.Bottom := RFullSource.Bottom + dy;
    {$ifdef VerboseScrollWindowEx}
    DebugLn(['ScrollWindowEx prcScroll RFullSource=', dbgs(RFullSource)]);
    {$ENDIF}
  end;

  if prcClip <> nil then
  begin
    // only limit the site towards which is scrolled
    // the other side is required for invalidation
    if dx < 0 then
      RFullSource.Left := Max(RFullSource.Left, prcClip^.Left - dx);
    if dx > 0 then
      RFullSource.Right := Min(RFullSource.Right, prcClip^.Right - dx);
    if dy < 0 then
      RFullSource.Top := Max(RFullSource.Top, prcClip^.Top - dy);
    if dy > 0 then
      RFullSource.Bottom := Min(RFullSource.Bottom, prcClip^.Bottom - dy);
    {$ifdef VerboseScrollWindowEx}
    DebugLn(['ScrollWindowEx prcClip RFullSource=', dbgs(RFullSource)]);
    {$ENDIF}
  end;

  if prcUpdate <> nil then
  begin
    prcUpdate^ := RFullSource;
    if dx < 0 then
      prcUpdate^.Left := Max(RFullSource.Left, RFullSource.Right + dx);
    if dx > 0 then
      prcUpdate^.Right := Min(RFullSource.Right, RFullSource.Left + dx);
    if dy < 0 then
      prcUpdate^.Top := Max(RFullSource.Top, RFullSource.Bottom + dy);
    if dy > 0 then
      prcUpdate^.Bottom := Min(RFullSource.Bottom, RFullSource.Top + dy);
    {$ifdef VerboseScrollWindowEx}
    DebugLn(['ScrollWindowEx prcUpdate RFullSource=', dbgs(prcUpdate^)]);
    {$ENDIF}
  end;

  R := RectToCGRect(RFullSource);
  OSError(HIViewScrollRect(ACtl.Content, HiRectPtr(@R), CGFloat(dx), CGFloat(dy)),
    ACtl, SName, 'HIViewScrollRect');

  if (flags and SW_SCROLLCHILDREN <> 0) then
  begin
    // complete view scrolls
    with ACtl.ScrollOffset do
    begin
      X := X + DX;
      Y := Y + DY;
    end;
  end;

  Result := true;
end;
{$ELSE}
function TCarbonWidgetSet.ScrollWindowEx(hWnd: HWND; dx, dy: Integer;
  prcScroll, prcClip: PRect; hrgnUpdate: HRGN; prcUpdate: PRect; flags: UINT
  ): Boolean;
const
  SName = 'ScrollWindowEx';
var
  ACtl: TCarbonControl;
  R, R1: CGRect;
  {%H-}RR: TRect;
begin
  {$IFDEF VerboseWinAPI}
  DebugLn('TCarbonWidgetSet.ScrollWindowEx() HWnd=',dbgs(hWnd),' prcScroll ',prcScroll <> nil,
    ' prcClip ',prcClip <> nil,' flags ',flags);
  {$ENDIF}
  if (hWnd <> 0) then
  begin
    ACtl := TCarbonControl(hWnd);
    if (flags and SW_SCROLLCHILDREN <> 0) then
    begin
      // complete view scrolls
      // MFR: R is not initialized
      OSError(HIViewScrollRect(ACtl.Content, HiRectPtr(@R), CGFloat(dx), CGFloat(dy)),
        ACtl, SName, 'HIViewScrollRect');
      with ACtl.ScrollOffset do
      begin
        X := X + DX;
        Y := Y + DY;
      end;
      Result := True;
    end else
    if (Flags = 0) then
    begin
      if (prcScroll <> nil) then
      begin
        R := RectToCGRect(prcScroll^);
        // TODO: create CGRect
        OSError(HIViewGetBounds(ACtl.Content, R1{%H-}),
          Self, SName, 'HIViewGetBounds');
        RR := CGRectToRect(R1);
        {$NOTE: check why RR is not used}
        OSError(HIViewScrollRect(ACtl.Content, HiRectPtr(@R), CGFloat(dx), CGFloat(dy)),
          ACtl, SName, 'HIViewScrollRect');
        Result := True;
      end;
    end;

    if flags and SW_INVALIDATE <> 0 then
    begin
      if prcClip <> nil then
      begin
        prcUpdate := prcClip;
        Result := InvalidateRect(hwnd, prcClip, flags and SW_ERASE <> 0)
      end else
      begin
        prcUpdate := prcScroll;
        Result := InvalidateRect(hwnd, prcScroll, flags and SW_ERASE <> 0);
      end;
    end;
  end else
    Result:=inherited ScrollWindowEx(hWnd, dx, dy, prcScroll, prcClip,
      hrgnUpdate, prcUpdate, flags);
end;
{$ENDIF}

function TCarbonWidgetSet.SelectClipRGN(DC: hDC; RGN: HRGN): Longint;
begin
  {$IFDEF VerboseWinAPI}
    DebugLn('TCarbonWidgetSet.SelectClipRGN DC: ' + DbgS(DC) + ' RGN: ' +
      DbgS(RGN));
  {$ENDIF}

  Result := ExtSelectClipRGN(DC, RGN, RGN_COPY)
end;

{------------------------------------------------------------------------------
  Method:  SelectObject
  Params:  DC     - Handle of the device context
           GDIObj - Handle of the object
  Returns: The handle of the object being replaced or 0 if error occurs

  Selects an object into the specified device context
 ------------------------------------------------------------------------------}
function TCarbonWidgetSet.SelectObject(DC: HDC; GDIObj: HGDIOBJ): HGDIOBJ;
var
  AObject: TObject;
  ADC: TCarbonDeviceContext;
const
  SName = 'TCarbonWidgetSet.SelectObject';
begin
  Result := 0;

  {$IFDEF VerboseWinAPI}
    DebugLn('TCarbonWidgetSet.SelectObject DC: ' + DbgS(DC) + ' GDIObj: ' +
      DbgS(GDIObj));
  {$ENDIF}
  
  if not CheckDC(DC, SName) then Exit;
  if not CheckGDIObject(GDIObj, SName) then Exit;
  
  ADC := TCarbonDeviceContext(DC);
  AObject := TObject(GDIObj);
  
  if AObject is TCarbonBrush then // select brush
  begin
    Result := HBRUSH(ADC.CurrentBrush);
    ADC.CurrentBrush := TCarbonBrush(GDIObj);
  end
  else
  if AObject is TCarbonPen then // select pen
  begin
    Result := HPEN(ADC.CurrentPen);
    ADC.CurrentPen := TCarbonPen(GDIObj);
  end
  else
  if AObject is TCarbonFont then // select font
  begin
    Result := HFONT(ADC.CurrentFont);
    ADC.CurrentFont := TCarbonFont(GDIObj);
  end
  else
  if AObject is TCarbonRegion then // select region
  begin
    Result := HBRUSH(ADC.CurrentRegion);
    ADC.CurrentRegion := TCarbonRegion(GDIObj);
  end
  else
  if AObject is TCarbonBitmap then // select bitmap
  begin
    if not (ADC is TCarbonBitmapContext) then
    begin
      DebugLn(SName + ' Error - The specified device context is not bitmap context!');
      Exit;
    end;
    
    Result := HBITMAP(TCarbonBitmapContext(ADC).Bitmap);
    TCarbonBitmapContext(ADC).Bitmap := TCarbonBitmap(GDIObj);
  end;
  
  {$IFDEF VerboseWinAPI}
    DebugLn('TCarbonWidgetSet.SelectObject Result: ' + DbgS(Result));
  {$ENDIF}
end;

function TCarbonWidgetSet.SelectPalette(DC: HDC; Palette: HPALETTE;
  ForceBackground: Boolean): HPALETTE;
begin
  Result:=inherited SelectPalette(DC, Palette, ForceBackground);
end;

{------------------------------------------------------------------------------
  Method:  SendMessage
  Params:  HandleWnd - Handle of destination window
           Msg       - Message to send
           WParam    - First message parameter
           LParam    - Second message parameter
  Returns: The result of the message processing

  Sends the specified message to the specified window
 ------------------------------------------------------------------------------}
function TCarbonWidgetSet.SendMessage(HandleWnd: HWND; Msg: Cardinal;
  wParam: WParam; lParam: LParam): LResult;
var
  UserEvent: EventRef;
  EventTarget: EventTargetRef;
  AMessage: TLMessage;
begin
  Result := 0;
  if not CheckWidget(HandleWnd, 'SendMessage') then Exit;

  UserEvent := nil;
  try
    UserEvent := PrepareUserEvent(HandleWnd, Msg, wParam, lParam, EventTarget);
    if UserEvent = nil then
      Exit;

    SendEventToEventTarget(UserEvent, EventTarget);
    if GetEventParameter(UserEvent, MakeFourCC('wmsg'), MakeFourCC('wmsg'), nil,
       SizeOf(TLMessage), nil, @AMessage) = noErr then
      Result := AMessage.Result;
  finally
    if UserEvent <> nil then
      ReleaseEvent(UserEvent);
  end;
end;

{------------------------------------------------------------------------------
  Method:  SetActiveWindow
  Params:  Handle - Window to activate
  Returns: Previous active window

  Sets focus to the specified window.
 ------------------------------------------------------------------------------}
function TCarbonWidgetSet.SetActiveWindow(Handle: HWND): HWND;
begin
  Result := 0;

  {$IFDEF VerboseWinAPI}
    DebugLn('TCarbonWidgetSet.SetActiveWindow Handle: ' + DbgS(Handle));
  {$ENDIF}
  
  if not CheckWidget(Handle, 'SetActiveWindow', TCarbonWindow) then Exit;
  
  Result := GetActiveWindow;
  if not TCarbonWindow(Handle).Activate then Result := 0;
end;

{------------------------------------------------------------------------------
  Method:  SetBkColor
  Params:  DC    - Handle to device context
           Color - Background color value
  Returns: The previous background color if succeeds, otherwise CLR_INVALID

  Sets the current background color to the specified color value
 ------------------------------------------------------------------------------}
function TCarbonWidgetSet.SetBkColor(DC: HDC; Color: TColorRef): TColorRef;
begin
  Result := CLR_INVALID;

  {$IFDEF VerboseWinAPI}
    DebugLn('TCarbonWidgetSet.SetBkColor DC: ' + DbgS(DC) + ' Color: ' + DbgS(Color));
  {$ENDIF}
  
  if not CheckDC(DC, 'SetBkColor') then Exit;

  Result := TColorRef(TCarbonDeviceContext(DC).BkColor);
  TCarbonDeviceContext(DC).BkColor := TColor(Color);
end;

{------------------------------------------------------------------------------
  Method:  SetBkMode
  Params:  DC     - Handle to device context
           BkMode - Flag specifying background mode
  Returns: The previous background mode if suceeds, otherwise 0

  Sets the background mix mode of the specified device context
 ------------------------------------------------------------------------------}
function TCarbonWidgetSet.SetBkMode(DC: HDC; BkMode: Integer): Integer;
begin
  Result := 0;

  {$IFDEF VerboseWinAPI}
    DebugLn('TCarbonWidgetSet.SetBkMode DC: ' + DbgS(DC) + ' BkMode: ' + DbgS(BkMode));
  {$ENDIF}
  
  if not CheckDC(DC, 'SetBkMode') then Exit;

  Result := TCarbonDeviceContext(DC).BkMode;
  TCarbonDeviceContext(DC).BkMode := BkMode;
end;

function TCarbonWidgetSet.SetCapture(AHandle: HWND): HWND;
begin
  Result:=CarbonWidgetSet.CaptureWidgetSet;
  CarbonWidgetSet.SetCaptureWidget(AHandle);
end;

{------------------------------------------------------------------------------
  Method:  SetCaretPos
  Params:  X, Y - Caret pos
  Returns: If the function succeeds

  Moves the caret to the specified coordinates.
 ------------------------------------------------------------------------------}
function TCarbonWidgetSet.SetCaretPos(X, Y: Integer): Boolean;
begin
  {$IFDEF VerboseWinAPI}
    DebugLn('TCarbonWidgetSet.SetCaretPos X: ' + DbgS(X) + ' Y: ' + DbgS(Y));
  {$ENDIF}
  
  Result := CarbonCaret.SetCaretPos(X, Y);
end;

{------------------------------------------------------------------------------
  Method:  SetCaretPosEx
  Params:  Handle - handle of window
           X      - Horizontal caret coordinate
           Y      - Vertical caret coordinate
  Returns: If the function succeeds

  Moves the caret to the specified coordinates in the specified window.
 ------------------------------------------------------------------------------}
function TCarbonWidgetSet.SetCaretPosEx(Handle: HWnd; X, Y: Integer): Boolean;
begin
  {$IFDEF VerboseWinAPI}
    DebugLn('TCarbonWidgetSet.SetCaretPosEx X: ' + DbgS(X) + ' Y: ' + DbgS(Y));
  {$ENDIF}
  
  Result := CarbonCaret.SetCaretPos(X, Y);
end;

function TCarbonWidgetSet.SetCaretRespondToFocus(handle: HWND;
  ShowHideOnFocus: boolean): Boolean;
begin
  Result:=inherited SetCaretRespondToFocus(handle, ShowHideOnFocus);
end;

function TCarbonWidgetSet.SetComboMinDropDownSize(Handle: HWND; MinItemsWidth, MinItemsHeight, MinItemCount: integer): boolean;
begin
  Result:=inherited SetComboMinDropDownSize(Handle, MinItemsWidth,
    MinItemsHeight, MinItemCount);
end;


{------------------------------------------------------------------------------
  Method:  SetCursor
  Params:  ACursor - Handle of cursor to set
  Returns: Previous cursor

  Sets the cursor to application
 ------------------------------------------------------------------------------}
function TCarbonWidgetSet.SetCursor(ACursor: HCURSOR): HCURSOR;
begin
  {$IFDEF VerboseWinAPI}
    DebugLn('TCarbonWidgetSet.SetCursor ACursor: ' + DbgS(ACursor));
  {$ENDIF}
  
  Result := FCurrentCursor;
  if not CheckCursor(ACursor, 'SetCursor') then Exit;
  if FCurrentCursor = ACursor then Exit;

  // If we setted cursor before, them we should uninstall it.
  // This needs for animated cursors (because of threading) and wait cursor
  if (FCurrentCursor <> 0) then
    TCarbonCursor(FCurrentCursor).UnInstall;

  // install new cursor
  TCarbonCursor(ACursor).Install;
  FCurrentCursor := ACursor;
end;

{------------------------------------------------------------------------------
  Method:  SetCursorPos
  Params:  X - global screen horizontal coordinate
           Y - global screen vertical coordinate
  Returns: If the function succeeds.

  Sets the position of the cursor on the screen.
  NOTE: does not generate events!
 ------------------------------------------------------------------------------}
function TCarbonWidgetSet.SetCursorPos(X, Y: Integer): Boolean;
var
	CursorPos: CGPoint;
begin
  Result := False;
    
  {$IFDEF VerboseWinAPI}
    DebugLn('TCarbonWidgetSet.SetCursorPos X: ' + DbgS(X) + ' Y: ' + DbgS(Y));
  {$ENDIF}

  CursorPos.X := X;
	CursorPos.Y := Y;
  if OSError(CGWarpMouseCursorPosition(CursorPos), Self, 'SetCursorPos',
    'CGWarpMouseCursorPosition') then Exit;
  Result := True;
end;

{------------------------------------------------------------------------------
  Method:  SetFocus
  Params:  HWnd - Handle of new focus window
  Returns: Previous focused window

  Sets the keyboard focus to the specified window
 ------------------------------------------------------------------------------}
function TCarbonWidgetSet.SetFocus(HWnd: HWND): HWND;
begin
  {$IFDEF VerboseWinAPI}
    DebugLn('TCarbonWidgetSet.SetFocus HWnd: ' + DbgS(HWnd));
  {$ENDIF}
  
  Result := GetFocus;
  if HWnd = 0 then Exit;
  if HWnd = Result then Exit; // if window is already focused exit
  if not CheckWidget(HWnd, SSetFocus) then Exit;
  
  TCarbonWidget(HWnd).SetFocus;
end;

{------------------------------------------------------------------------------
  Method:  SetForegroundWindow
  Params:  HWnd - Handle of window
  Returns: If the function suceeds

  Brings the specified window to the top
 ------------------------------------------------------------------------------}
function TCarbonWidgetSet.SetForegroundWindow(HWnd: HWND): boolean;
begin
  Result := False;

  {$IFDEF VerboseWinAPI}
    DebugLn('TCarbonWidgetSet.SetForegroundWindow HWnd: ' + DbgS(HWnd));
  {$ENDIF}

  if not CheckWidget(HWnd, 'SetForegroundWindow', TCarbonWindow) then Exit;
  
  Result := TCarbonWindow(HWnd).SetForeground;
end;

{------------------------------------------------------------------------------
  Method:  TCarbonWidgetSet.SetMenu
  Params:  AMenuObject - Menu

  Attaches the menu of window to menu bar
 ------------------------------------------------------------------------------}
function TCarbonWidgetSet.SetMenu(AWindowHandle: HWND; AMenuHandle: HMENU): Boolean;
begin
  Result := False;
  {$IFDEF VerboseWinAPI}
    DebugLn(Format('TCarbonWidgetSet.SetMenu AWindowHAndle: %x AMenuHandle: %x',
     [AWindowHandle, AMenuHandle]));
  {$ENDIF}

  if not CheckWidget(AWindowHandle, 'SetMenu') then Exit;
  if not CheckMenu(AMenuHandle, 'SetMenu') then Exit;


  SetRootMenu(AMenuHandle);
  Result := True;
end;

{------------------------------------------------------------------------------
  Method:  TCarbonWidgetSet.SetParent
  Params:  hWndChild - a window we want to attach, hWndParent - a window to
           which we want to attach

  Attaches the child window to a new parent
 ------------------------------------------------------------------------------}
function TCarbonWidgetSet.SetParent(hWndChild: HWND; hWndParent: HWND): HWND;
var
  ChildWidget: TCarbonWidget absolute hWndChild;
begin
  if not CheckWidget(hWndChild, 'SetParent') then Exit;

  if ChildWidget is TCarbonControl then
    Result := HWnd(GetCarbonWidget(HIViewGetSuperview(TCarbonControl(ChildWidget).Widget)))
  else
    Result := 0;

  ChildWidget.AddToWidget(TCarbonWidget(hWndParent));
end;


{------------------------------------------------------------------------------
  Method:  SetProp
  Params:  Handle - Handle of window
           Str    - Property name
           Data   - Property data
  Returns: If the function suceeds

  Adds a new entry or changes an existing entry in the property list of the
  specified window
 ------------------------------------------------------------------------------}
function TCarbonWidgetSet.SetProp(Handle: hwnd; Str: PChar; Data: Pointer): Boolean;
begin
  Result := False;

  {$IFDEF VerboseWinAPI}
    DebugLn('TCarbonWidgetSet.SetProp Handle: ' + DbgS(Handle) + ' Str: ' + Str +
      ' Data: ' + DbgS(Data));
  {$ENDIF}
  
  if not CheckWidget(Handle, 'SetProp') then Exit;
  
  TCarbonWidget(Handle).Properties[Str] := Data;
  Result := True;
end;

{------------------------------------------------------------------------------
  Method:  SetROP2
  Params:  DC		- Handle to device context
           Mode	- Foreground mixing mode
  Returns: The previous mode if succeeds, otherwise 0
  
  Sets the specified foreground mixing mode to the device context
  TODO: implement all modes
 ------------------------------------------------------------------------------}
function TCarbonWidgetSet.SetROP2(DC: HDC; Mode: Integer): Integer;
begin
  Result := 0;

  {$IFDEF VerboseWinAPI}
    DebugLn('TCarbonWidgetSet.SetROP2 DC: ' + DbgS(DC) + ' Mode: ' + DbgS(Mode));
  {$ENDIF}
  
  if not CheckDC(DC, 'SetROP2') then Exit;

  Result := TCarbonDeviceContext(DC).ROP2;
  TCarbonDeviceContext(DC).ROP2 := Mode;
end;

{------------------------------------------------------------------------------
  Method:  SetScrollInfo
  Params:  Handle     - Handle of window
           SBStyle    - Scroll bar flag
           ScrollInfo - Scrolling info
           bRedraw    - Redraw the scroll bar?
  Returns: The new position value

  Sets the parameters of a scroll bar
 ------------------------------------------------------------------------------}
function TCarbonWidgetSet.SetScrollInfo(Handle: HWND; SBStyle: Integer;
  ScrollInfo: TScrollInfo; bRedraw: Boolean): Integer;
var
  CarbonControl: TCarbonControl;
begin
  Result := 0;

  {$IFDEF VerboseWinAPI}
    DebugLn('TCarbonWidgetSet.SetScrollInfo Handle: ' + DbgS(Handle) +
      ' SBStyle: ' + DbgS(SBStyle));
  {$ENDIF}
  
  if SBStyle = SB_CTL then
  begin
    if not CheckWidget(Handle, 'SetScrollInfo', TCarbonControl) then Exit;

    CarbonControl := TCarbonControl(Handle);
    
    if (SIF_RANGE and ScrollInfo.fMask) > 0 then
    begin
      CarbonControl.SetMinimum(ScrollInfo.nMin);
      CarbonControl.SetMaximum(ScrollInfo.nMax);
    end;
    if (SIF_POS and ScrollInfo.fMask) > 0 then
      CarbonControl.SetValue(ScrollInfo.nPos);
    if (SIF_PAGE and ScrollInfo.fMask) > 0 then
      CarbonControl.SetViewSize(ScrollInfo.nPage);

    Result := CarbonControl.GetValue;
  end
  else
  begin
    if not CheckWidget(Handle, 'SetScrollInfo') then Exit;

    Result := TCarbonWidget(Handle).SetScrollInfo(SBStyle, ScrollInfo);
  end;
end;

function TCarbonWidgetSet.SetSysColors(cElements: Integer; const lpaElements;
  const lpaRgbValues): Boolean;
begin
  Result:=inherited SetSysColors(cElements, lpaElements, lpaRgbValues);
end;

function TCarbonWidgetSet.SetTextCharacterExtra(_hdc: hdc; nCharExtra: Integer
  ): Integer;
begin
  Result:=inherited SetTextCharacterExtra(_hdc, nCharExtra);
end;

{------------------------------------------------------------------------------
  Method:  SetTextColor
  Params:  DC    - Handle to device context.
           Color - Specifies the color of the text
  Returns: The previous color if succeeds, CLR_INVALID otherwise

  Sets the text color for the specified device context to the specified color
 ------------------------------------------------------------------------------}
function TCarbonWidgetSet.SetTextColor(DC: HDC; Color: TColorRef): TColorRef;
begin
  Result := CLR_INVALID;

  {$IFDEF VerboseWinAPI}
    DebugLn('TCarbonWidgetSet.SetTextColor DC: ' + DbgS(DC) + ' Color: ' + DbgS(Color));
  {$ENDIF}
  
  if not CheckDC(DC, 'SetTextColor') then Exit;
  
  Result := TColorRef(TCarbonDeviceContext(DC).TextColor);
  TCarbonDeviceContext(DC).TextColor := TColor(Color);
end;

function TCarbonWidgetSet.SetViewPortOrgEx(DC: HDC; NewX, NewY: Integer;
  OldPoint: PPoint): Boolean;
begin
  Result := False;
  if not CheckDC(DC, 'SetViewPortOrgEx') then Exit;

  if Assigned(OldPoint) then
    OldPoint^ := TCarbonDeviceContext(DC).ViewPortOfs;
  TCarbonDeviceContext(DC).ViewPortOfs := Types.Point(NewX, NewY);
  Result := True;
end;

function TCarbonWidgetSet.SetWindowLong(Handle: HWND; Idx: Integer;
  NewLong: PtrInt): PtrInt;
begin
  Result:=inherited SetWindowLong(Handle, Idx, NewLong);
end;

{------------------------------------------------------------------------------
  Method:  SetWindowOrgEx
  Params:  DC    - Handle to device context.
           NewX, NewY - New context origin
  Returns: If the function succeeds

  Sets the origin of the specified device context
 ------------------------------------------------------------------------------}
function TCarbonWidgetSet.SetWindowOrgEx(DC: HDC; NewX, NewY: Integer;
  OldPoint: PPoint): Boolean;
begin
  Result  := False;
  if not CheckDC(DC, 'SetWindowOrgEx') then Exit;

  if Assigned(OldPoint) then
    OldPoint^ := TCarbonDeviceContext(DC).WindowOfs;
  TCarbonDeviceContext(DC).WindowOfs := Types.Point(NewX, NewY);
  Result := True;
end;

function TCarbonWidgetSet.SetWindowPos(hWnd: HWND; hWndInsertAfter: HWND; X, Y,
  cx, cy: Integer; uFlags: UINT): Boolean;
begin
  Result:=inherited SetWindowPos(hWnd, hWndInsertAfter, X, Y, cx, cy, uFlags);
end;

{------------------------------------------------------------------------------
  Method:  ShowCaret
  Params:  HWnd - Handle of window with caret
  Returns: if the function succeeds

  Makes the caret visible on the screen at the caret's current position.
 ------------------------------------------------------------------------------}
function TCarbonWidgetSet.ShowCaret(hWnd: HWND): Boolean;
begin
  Result := False;
  {$IFDEF VerboseWinAPI}
    DebugLn('TCarbonWidgetSet.ShowCaret Handle: ' + DbgS(hWnd));
  {$ENDIF}
  if not CheckWidget(hWnd, 'ShowCaret') then Exit;

  Result := CarbonCaret.ShowCaret(TCarbonWidget(hWnd));
end;

function TCarbonWidgetSet.ShowScrollBar(Handle: HWND; wBar: Integer;
  bShow: Boolean): Boolean;
//var
//  CarbonControl: TCarbonControl;
begin
  Result:=false;

  //CarbonControl := TCarbonControl(Handle);

  // ToDo:

  Result:=inherited ShowScrollBar(Handle, wBar, bShow);
end;

{------------------------------------------------------------------------------
  Method:  ShowWindow
  Params:  hWnd     - Handle of window
           nCmdShow - (SW_SHOWNORMAL, SW_MINIMIZE, SW_SHOWMAXIMIZED)
  Returns: If the function succeeds
  
  Shows the window normal, minimized or maximized
------------------------------------------------------------------------------}
function TCarbonWidgetSet.ShowWindow(hWnd: HWND; nCmdShow: Integer): Boolean;
var
  ACtl: TCarbonControl;
begin
  Result := False;

  {$IFDEF VerboseWinAPI}
    DebugLn('TCarbonWidgetSet.ShowWindow hWnd: ' + DbgS(hWnd) + ' nCmdShow: ' +
      DbgS(nCmdShow));
  {$ENDIF}

  if HWND = 0 then
    exit;
  ACtl := TCarbonControl(HWND);
  if not (ACtl is TCarbonWindow) then
  begin
    if nCmdShow in [SW_SHOW, SW_HIDE] then
    begin
      ACtl.ShowHide(nCmdShow = SW_SHOW);
      Result := True;
    end;
  end else
  begin
    if not CheckWidget(HWnd, 'ShowWindow', TCarbonWindow) then Exit;

    Result := TCarbonWindow(HWnd).Show(nCmdShow);
  end;
end;

{------------------------------------------------------------------------------
  Method:  StretchBlt
  Params:  DestDC              - Destination device context
           X, Y                - Left/top corner of the destination rectangle
           Width, Height       - Size of the destination rectangle
           SrcDC               - Source device context
           XSrc, YSrc          - Left/top corner of the source rectangle
           SrcWidth, SrcHeight - Size of the source rectangle
           Rop                 - Raster operation to be performed
  Returns: If the function succeeds

  Copies a bitmap from a source rectangle into a destination rectangle using the
  specified raster operation. If needed it resizes the bitmap to fit the
  dimensions of the destination rectangle. Sizing is done according to the
  stretching mode currently set in the destination device context.
 ------------------------------------------------------------------------------}
function TCarbonWidgetSet.StretchBlt(DestDC: HDC; X, Y, Width, Height: Integer;
  SrcDC: HDC; XSrc, YSrc, SrcWidth, SrcHeight: Integer; ROp: Cardinal): Boolean;
begin
  Result := StretchMaskBlt(DestDC, X, Y, Width, Height, SrcDC, XSrc, YSrc,
    SrcWidth, SrcHeight, 0, 0, 0, Rop);
end;

{------------------------------------------------------------------------------
  Method:  StretchMaskBlt
  Params:  DestDC              - Handle to destination device context
           X, Y                - Left/top corner of the destination rectangle
           Width, Height       - Size of the destination rectangle
           SrcDC               - Handle to source device context
           XSrc, YSrc          - Left/top corner of the source rectangle
           SrcWidth, SrcHeight - Size of the source rectangle
           Mask                - Handle of a monochrome bitmap (IGNORED)
           XMask, YMask        - Left/top corner of the mask rectangle
           Rop                 - Raster operation to be performed (TODO)
  Returns: If the function succeeds

  Copies a bitmap from a source rectangle into a destination rectangle using
  the specified mask and raster operations. If needed it resizes the bitmap to
  fit the dimensions of the destination rectangle. Sizing is done according to
  the stretching mode currently set in the destination device context.
  TODO: copy from any canvas
        ROP
        stretch mode
        SrcX, SrcY, SrcWidth, SrcHeight
 ------------------------------------------------------------------------------}
function TCarbonWidgetSet.StretchMaskBlt(DestDC: HDC; X, Y, Width,
  Height: Integer; SrcDC: HDC; XSrc, YSrc, SrcWidth, SrcHeight: Integer;
  Mask: HBITMAP; XMask, YMask: Integer; Rop: DWORD): Boolean;
const
  SName = 'TCarbonWidgetSet.StretchMaskBlt';
begin
  Result := False;
  {$IFDEF VerboseWinAPI}
    DebugLn('TCarbonWidgetSet.StretchMaskBlt DestDC: ' + DbgS(DestDC) + ' SrcDC: ',
      DbgS(SrcDC) + ' X: ' +  DbgS(X) + ' Y: ' + DbgS(Y),
     ' W: ' + DbgS(Width) + ' H: ', DbgS(Height),
     ' XSrc: ' + DbgS(XSrc) + ' YSrc: ' + DbgS(YSrc),
     ' SrcW: ' + DbgS(SrcWidth), ' SrcH: ' + DbgS(SrcHeight) + ' Rop: ' + DbgS(Rop));
  {$ENDIF}
  
  if not CheckDC(DestDC, SName, 'Dest') then Exit;
  if not CheckDC(SrcDC, SName, 'Src') then Exit;
  if not (TCarbonDeviceContext(SrcDC) is TCarbonBitmapContext) then
  begin
    DebugLn(SName + ' Error - invalid source device context ', TCarbonDeviceContext(SrcDC).ClassName,
      ', expected TCarbonBitmapContext!');
    Exit;
  end;
  
  Result := TCarbonDeviceContext(DestDC).StretchDraw(X, Y, Width, Height,
    TCarbonBitmapContext(SrcDC), XSrc, YSrc, SrcWidth, SrcHeight,
    TCarbonBitmap(Mask), XMask, YMask, Rop);
end;

function TCarbonWidgetSet.SystemParametersInfo(uiAction: DWord; uiParam: DWord;
  pvParam: Pointer; fWinIni: DWord): LongBool;
begin
  Result:=True;
  Case uiAction of
    SPI_GETWORKAREA: begin
      TRect(pvParam^):=Bounds(GetSystemMetrics(SM_XVIRTUALSCREEN),
                              GetSystemMetrics(SM_YVIRTUALSCREEN),
                              GetSystemMetrics(SM_CXVIRTUALSCREEN),
                              GetSystemMetrics(SM_CYVIRTUALSCREEN));
    end;
    SPI_GETWHEELSCROLLLINES: PDword(pvPAram)^ := 3;
    else
      Result := False;
  end;
end;

{------------------------------------------------------------------------------
  Method:  TextOut
  Params:  DC    - Handle of the device context
           X     - X-coordinate of starting position
           Y     - Y-coordinate of starting position
           Str   - String
           Count - Number of characters in string
  Returns: If the function succeeds

  Draws a character string at the specified location, using the currently
  selected font
 ------------------------------------------------------------------------------}
function TCarbonWidgetSet.TextOut(DC: HDC; X, Y: Integer; Str: Pchar;
  Count: Integer): Boolean;
begin
  Result := ExtTextOut(DC, X, Y, 0, nil, Str, Count, nil);
end;

{------------------------------------------------------------------------------
  Method:  UpdateWindow
  Params:  Handle - Handle to window
  Returns: If the function succeeds

  Updates the dirty areas of the specified window
 ------------------------------------------------------------------------------}
function TCarbonWidgetSet.UpdateWindow(Handle: HWND): Boolean;
begin
  Result := False;

  {$IFDEF VerboseWinAPI}
    DebugLn('TCarbonWidgetSet.UpdateWindow Handle: ' + DbgS(Handle));
  {$ENDIF}
  
  if not CheckWidget(Handle, 'UpdateWindow') then Exit;
  
  TCarbonWidget(Handle).Update;
end;

{------------------------------------------------------------------------------
  Method:  WindowFromPoint
  Params:  Point - Screen point
  Returns: Carbon control or window under the specified screen point
 ------------------------------------------------------------------------------}
function TCarbonWidgetSet.WindowFromPoint(Point: TPoint): HWND;
var
  Window: WindowRef;
  Control: ControlRef;
  WindowPart: WindowPartCode;
  P: MacOSAll.Point;
  R: MacOSAll.Rect;
begin
  Result := 0;

  {$IFDEF VerboseWinAPI}
    DebugLn('TCarbonWidgetSet.WindowFromPoint Point: ' + DbgS(Point));
  {$ENDIF}

  P.h := Point.X;
  P.v := Point.Y;
  if FindWindowOfClass(P, kAllWindowClasses, Window{%H-}, @WindowPart) <> noErr then Exit;
  if Window = nil then Exit;
  if WindowPart <> inContent then Exit;
  
  if OSError(GetWindowBounds(Window, kWindowContentRgn, R{%H-}), Self,
    'WindowFromPoint', SGetWindowBounds) then Exit;
    
  Dec(P.h, R.left);
  Dec(P.v, R.top);
  
  Control := FindControlUnderMouse(P, Window, nil);
  if Control = nil then
    Result := HWND(GetCarbonWidget(Window))
  else
    Result := HWND(GetCarbonWidget(Control));
    
  {$IFDEF VerboseWinAPI}
    DebugLn('TCarbonWidgetSet.WindowFromPoint Result: ' + DbgS(Result));
  {$ENDIF}
end;

procedure TCarbonWidgetSet.SetFocusedWidget(const AWidget: HWND);
begin
  FFocusedWidget := AWidget;
end;

function TCarbonWidgetSet.GetFocusedWidget: HWND;
begin
  Result := FFocusedWidget;
end;

//##apiwiz##eps##   // Do not remove, no wizard declaration after this line







{%MainUnit cocoaint.pas}
{ $Id: cocoawinapi.inc 15525 2008-06-23 06:39:58Z paul $ }
{******************************************************************************
  All Cocoa Winapi implementations.
  This are the implementations of the overrides of the Cocoa Interface for the
  methods defined in the
  lcl/include/winapi.inc

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

function CocoaCombineMode(ACombineMode: Integer): TCocoaCombine;
begin
  case ACombineMode of
    RGN_AND:  Result:=cc_And;
    RGN_OR:   Result:=cc_Or;
    RGN_XOR:  Result:=cc_Xor;
    RGN_DIFF: Result:=cc_Diff;
  else
    Result:=cc_Copy;
  end;
end;

const
  CocoaRegionTypeToWin32Map: array[TCocoaRegionType] of Integer = (
 { crt_Error     } ERROR,
 { crt_Empty     } NULLREGION,
 { crt_Rectangle } SIMPLEREGION,
 { crt_Complex   } COMPLEXREGION
  );

function TCocoaWidgetSet.Arc(DC: HDC; Left, Top, Right, Bottom, angle1,
  angle2: Integer): Boolean;
begin
  Result:=inherited Arc(DC, Left, Top, Right, Bottom, angle1, angle2);
end;

function TCocoaWidgetSet.AngleChord(DC: HDC; x1, y1, x2, y2, angle1,
  angle2: Integer): Boolean;
begin
  Result:=inherited AngleChord(DC, x1, y1, x2, y2, angle1, angle2);
end;

function TCocoaWidgetSet.BeginPaint(Handle: hWnd; var PS: TPaintStruct): hdc;
begin
  Result := inherited BeginPaint(Handle, PS);
  PS.hdc := Result;
end;

function TCocoaWidgetSet.BitBlt(DestDC: HDC; X, Y, Width, Height: Integer;
  SrcDC: HDC; XSrc, YSrc: Integer; Rop: DWORD): Boolean;
var
  SrcCtx, DestCtx: TCocoaContext;
  Bmp: TCocoaBitmap;
begin
  SrcCtx := CheckDC(SrcDC);
  DestCtx := CheckDC(DestDC);

  Result := Assigned(SrcCtx) and Assigned(DestCtx);

  if not Result then
    Exit;

  if not (SrcCtx is TCocoaBitmapContext) then
  begin
    DebugLn('StretchMaskBlt Error - invalid source device context ', SrcCtx.ClassName,
      ', expected TCocoaBitmapContext!');
    Exit(False);
  end;

  Bmp := TCocoaBitmapContext(SrcCtx).Bitmap;

  if not Assigned(Bmp) then
    Exit(False);

  // Width and Height should not be greater than bitmap width
  Width := Min(Width, Bmp.Width);
  Height := Min(Height, Bmp.Height);

  Result := DestCtx.StretchDraw(X, Y, Width, Height,
    TCocoaBitmapContext(SrcCtx), XSrc, YSrc, Width, Height,
    nil, 0, 0, Rop);
end;

function TCocoaWidgetSet.ClientToScreen(Handle: HWND; var P: TPoint): Boolean;
var
  r : NSRect;
  cl : NSView;
  clr : TRect;
begin
  Result := Handle <> 0;

  if Result then
  begin
    // must use lclContentView! - it's client view
    cl := NSObject(Handle).lclContentView;
    if HWND(cl) = Handle then
    begin
      // if Handle is lclContentView, then we should check clientRect
      // (i.e. TabControl doesn't have lclContentView, yet its clientRect is adjusted)
      clr := NSObject(Handle).lclClientFrame;
      P.X := P.X + clr.Left;
      P.Y := P.Y + clr.Top;
    end;
    cl.lclLocalToScreen(P.X, P.Y);
  end;
end;

procedure TCocoaWidgetSet.CallDefaultWndHandler(Sender: TObject; var Message);
var
  hnd : NSObject;
  vw  : NSView;
  tb : Boolean;
  ar : Boolean;
  ks : Boolean;
  rt : Boolean;
const
  WantTab   : array [boolean] of integer = (0, DLGC_WANTTAB);
  WantArrow : array [boolean] of integer = (0, DLGC_WANTARROWS);
  WantKeys  : array [boolean] of integer = (0, DLGC_WANTALLKEYS);
begin
  case TLMessage(Message).Msg of
    LM_GETDLGCODE: begin
      hnd := nil;
      if (Sender is TWinControl) then hnd := NSObject(TWinControl(Sender).Handle);
      if not Assigned(hnd) then Exit;
      vw := hnd.lclContentView();
      if Assigned(vw) then
      begin
        tb := false;
        ar := false;
        ks := false;
        rt := false;
        vw.lclExpectedKeys(tb, ar, rt, ks);
        ks := ks or rt; // Return is handled by LCL as part of ALLKey
        TLMessage(Message).Result := TLMessage(Message).Result or WantTab[tb] or WantArrow[ar] or WantKeys[ks];
      end;

    end;
  else
    TLMessage(Message).Result := 0;
  end;
end;

{------------------------------------------------------------------------------
  Method:  ClipboardFormatToMimeType
  Params:  FormatID - A registered format identifier (0 is invalid)
  Returns: The corresponding mime type as string
 ------------------------------------------------------------------------------}
function TCocoaWidgetSet.ClipboardFormatToMimeType(FormatID: TClipboardFormat): string;
begin
  {$IFDEF VerboseClipboard}
    DebugLn('TCocoaWidgetSet.ClipboardFormatToMimeType FormatID: ' + DbgS(FormatID));
  {$ENDIF}
  Result := fClipboard.FormatToMimeType(FormatID);
end;

{------------------------------------------------------------------------------
  Method:  ClipboardGetData
  Params:  ClipboardType - Clipboard type
           FormatID      - A registered format identifier (0 is invalid)
           Stream        - If format is available, it will be appended to this
                           stream
  Returns: If the function succeeds
 ------------------------------------------------------------------------------}
function TCocoaWidgetSet.ClipboardGetData(ClipboardType: TClipboardType;
  FormatID: TClipboardFormat; Stream: TStream): boolean;
begin
  {$IFDEF VerboseClipboard}
    DebugLn('TCocoaWidgetSet.ClipboardGetData ClipboardType=' +
      ClipboardTypeName[ClipboardType] + ' FormatID: ' + DbgS(FormatID));
  {$ENDIF}
  Result := fClipboard.GetData(ClipboardType, FormatID, Stream);
end;

{------------------------------------------------------------------------------
  Method:  ClipboardGetFormats
  Params:  ClipboardType - The type of clipboard operation
           Count         - The number of clipboard formats
           List          - Pointer to an array of supported formats
                           (you must free it yourself)
  Returns: If the function succeeds
 ------------------------------------------------------------------------------}

function TCocoaWidgetSet.ClipboardGetFormats(ClipboardType: TClipboardType;
  var Count: integer; var List: PClipboardFormat): boolean;
var
  fmt: TDynClipboardFormatArray;
begin
  {$IFDEF VerboseClipboard}
    DebugLn('TCocoaWidgetSet.ClipboardGetFormats ClipboardType' +
      ClipboardTypeName[ClipboardType]);
  {$ENDIF}
  fmt := nil;
  Result := fClipboard.GetFormats(ClipboardType, Count, fmt);
  if Count > 0 then begin
    GetMem(List, Count * sizeof(TClipboardFormat));
    System.Move(fmt[0], List^, Count * sizeof(TClipboardFormat));
  end else
    List := nil;
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
function TCocoaWidgetSet.ClipboardGetOwnerShip(ClipboardType: TClipboardType;
  OnRequestProc: TClipboardRequestEvent; FormatCount: integer;
  Formats: PClipboardFormat): boolean;
begin
  {$IFDEF VerboseClipboard}
    DebugLn('TCocoaWidgetSet.ClipboardGetOwnerShip ClipboardType=' +
      ClipboardTypeName[ClipboardType] + ' FormatCount: ' + DbgS(FormatCount));
  {$ENDIF}
  Result := fClipboard.GetOwnership(ClipboardType, OnRequestProc, FormatCount, Formats);
end;

{------------------------------------------------------------------------------
  Method:  ClipboardRegisterFormat
  Params:  AMimeType - A string (usually a MIME type) identifying a new format
                       type to register
  Returns: The registered Format identifier (TClipboardFormat)
 ------------------------------------------------------------------------------}
function TCocoaWidgetSet.ClipboardRegisterFormat(const AMimeType: string): TClipboardFormat;
begin
  Result := fClipboard.RegisterFormat(AMimeType);
  {$IFDEF VerboseClipboard}
    DebugLn('TCocoaWidgetSet.ClipboardRegisterFormat AMimeType=' + AMimeType
      + ' Result='+DbgS(Result));
  {$ENDIF}
end;

function TCocoaWidgetSet.ClipboardFormatNeedsNullByte(
  const AFormat: TPredefinedClipboardFormat): Boolean;
begin
  Result := False
end;

function TCocoaWidgetSet.CombineRgn(Dest, Src1, Src2: HRGN; fnCombineMode: Longint): Longint;
begin
  Result := LCLType.Error;
  if (Dest = 0) or (Src1 = 0) or (fnCombineMode<RGN_AND) or (fnCombineMode>RGN_COPY) then Exit;
  if (fnCombineMode <> RGN_COPY) and (Src2 = 0) then Exit;

  Result := CocoaRegionTypeToWin32Map[TCocoaRegion(Dest).CombineWith(TCocoaRegion(Src1), cc_Copy)];

  if fnCombineMode <> RGN_COPY then
    Result := CocoaRegionTypeToWin32Map[TCocoaRegion(Dest).CombineWith(TCocoaRegion(Src2), CocoaCombineMode(fnCombineMode))];
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
function TCocoaWidgetSet.CreateBitmap(Width, Height: Integer;
  Planes, BitCount: Longint; BitmapBits: Pointer): HBITMAP;
var
  bmpType: TCocoaBitmapType;
begin
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
  Result := HBITMAP(TCocoaBitmap.Create(Width, Height, BitCount, BitCount, cbaWord, bmpType, BitmapBits));
end;

function TCocoaWidgetSet.CreateBrushIndirect(const LogBrush: TLogBrush): HBRUSH;
begin
  Result := HBrush(TCocoaBrush.Create(LogBrush));
end;

function TCocoaWidgetSet.CreateCaret(Handle: HWND; Bitmap: hBitmap; Width,
  Height: Integer): Boolean;
begin
  Result := (Handle <> 0);
  if Result then
    Result := CocoaCaret.CreateCaret(NSView(Handle).lclContentView, Bitmap, Width, Height)
end;

function TCocoaWidgetSet.CreateCompatibleBitmap(DC: HDC; Width, Height: Integer): HBITMAP;
begin
  Result := HBITMAP(TCocoaBitmap.Create(Width, Height, 32, 32, cbaDQWord, cbtARGB, nil));
end;

{------------------------------------------------------------------------------
  Method:  CreateCompatibleDC
  Params:  DC - Handle to memory device context
  Returns: Handle to a memory device context

  Creates a memory device context (DC) compatible with the specified device
 ------------------------------------------------------------------------------}
function TCocoaWidgetSet.CreateCompatibleDC(DC: HDC): HDC;
begin
  Result := HDC(TCocoaBitmapContext.Create);
end;

//todo:
//function TCocoaWidgetSet.CreateEllipticRgn(p1, p2, p3, p4: Integer): HRGN;
//begin
//end;

function TCocoaWidgetSet.CreateFontIndirect(const LogFont: TLogFont): HFONT;
begin
  Result := HFont(TCocoaFont.Create(LogFont, LogFont.lfFaceName));
end;

function TCocoaWidgetSet.CreateFontIndirectEx(const LogFont: TLogFont;
  const LongFontName: string): HFONT;
begin
  Result := HFont(TCocoaFont.Create(LogFont, LongFontName));
end;

class function TCocoaWidgetSet.Create32BitAlphaBitmap(ABitmap, AMask: TCocoaBitmap): TCocoaBitmap;
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

  if not LCLIntf.RawImage_FromBitmap(ARawImage, HBITMAP(ABitmap), HBITMAP(AMask)) then
    Exit;

  ImgMaskHandle := 0;

  W := Desc.Width;
  if W < 1 then W := 1;
  H := Desc.Height;
  if H < 1 then H := 1;

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
    if not LCLIntf.RawImage_CreateBitmaps(ImagePtr^, ImgHandle, ImgMaskHandle, True) then Exit;

    Result := TCocoaBitmap(ImgHandle);
  finally
    ARawImage.FreeData;
    DstImage.Free;
  end;
end;

function TCocoaWidgetSet.CreateIconIndirect(IconInfo: PIconInfo): HICON;
var
  ABitmap: TCocoaBitmap;
begin
  Result := 0;
  if IconInfo^.hbmColor = 0 then Exit;

  ABitmap := Create32BitAlphaBitmap(TCocoaBitmap(IconInfo^.hbmColor), TCocoaBitmap(IconInfo^.hbmMask));

  if IconInfo^.fIcon then
    Result := HICON(ABitmap)
  else
    Result := HICON(TCocoaCursor.CreateFromBitmap(ABitmap, GetNSPoint(IconInfo^.xHotSpot, IconInfo^.yHotSpot)));
end;

function TCocoaWidgetSet.CreatePenIndirect(const LogPen: TLogPen): HPEN;
begin
  Result := HPen(TCocoaPen.Create(LogPen));
end;

{------------------------------------------------------------------------------
  Method:  CreatePolygonRgn
  Params:  Points   - Pointer to array of polygon points
           NumPts   - Number of points passed
           FillMode - Filling mode
  Returns: The new polygonal region

  Creates a new polygonal region from the specified points
 ------------------------------------------------------------------------------}
function TCocoaWidgetSet.CreatePolygonRgn(Points: PPoint; NumPts: Integer;
  FillMode: integer): HRGN;
begin
  {$IFDEF VerboseWinAPI}
    DebugLn('TCocoaWidgetSet.CreatePolygonRgn NumPts: ' + DbgS(NumPts) +
      ' FillMode: ' + DbgS(FillMode));
  {$ENDIF}

  Result := HRGN(TCocoaRegion.Create(Points, NumPts, FillMode=ALTERNATE));
end;

function TCocoaWidgetSet.CreateRectRgn(X1, Y1, X2, Y2: Integer): HRGN;
begin
  {$IFDEF VerboseWinAPI}
    DebugLn('TCocoaWidgetSet.CreateRectRgn R: ' + DbgS(Classes.Rect(X1, Y1, X2, Y2)));
  {$ENDIF}

  Result := HRGN(TCocoaRegion.Create(X1, Y1, X2, Y2));
end;

function TCocoaWidgetSet.DeleteObject(GDIObject: HGDIOBJ): Boolean;
const
  SName = 'TCocoaWidgetSet.DeleteObject';
var
  gdi: TCocoaGDIObject;
begin
  Result := False;
  if GDIObject = 0 then
    Exit(True);

  gdi := CheckGDIOBJ(GdiObject);

  if not Assigned(gdi) then
  begin
    DebugLn(SName, ' Error - GDIObject: ' +  DbgSName(gdi) + ' is unknown!');
    Exit;
  end;

  if gdi.Global then
  begin
    // global brushes can be cached, so just exit here since we will free the resource later on
    //DebugLn(SName, ' Error - GDIObject: ' +  DbgSName(gdi) + ' is global!');
    Exit;
  end;

  if gdi.RefCount <> 1 then
  begin
    DebugLn(SName, 'Error - GDIObject: ' + DbgSName(gdi) + ' is still selected!');
    Exit;
  end;

  gdi.Destroy;
  Result := True;
end;

function TCocoaWidgetSet.DestroyCaret(Handle: HWND): Boolean;
begin
  Result := CocoaCaret.DestroyCaret( NSView(Handle).lclContentView );
end;

function TCocoaWidgetSet.DestroyIcon(Handle: HICON): Boolean;
var
  Ico: TObject;
begin
  Result := Handle <> 0;
  if not Result then
    Exit;
  Ico := TObject(Handle);
  Result := (Ico is TCocoaBitmap) or (Ico is TCocoaCursor);
  if Result then
    Ico.Destroy;
end;

function TCocoaWidgetSet.DPtoLP(DC: HDC; var Points; Count: Integer): BOOL;
var
  ctx: TCocoaContext;
  P: PPoint;
begin
  Result := False;
  ctx := CheckDC(DC);
  if not Assigned(ctx) then Exit;
  P := @Points;
  with ctx.GetLogicalOffset do
    while Count > 0 do
    begin
      Dec(Count);
      dec(P^.X, X);
      dec(P^.Y, Y);
      inc(P);
    end;
  Result := True;
end;

function TCocoaWidgetSet.DrawFocusRect(DC: HDC; const Rect: TRect): boolean;
var
  ctx: TCocoaContext;
  p: Integer;
  pn: TCocoaPen;
  opn: TCocoaPen;
  r: TRect;
begin

  ctx := CheckDC(DC);
  Result := Assigned(ctx);
  if Result then
  begin
    //ctx.DrawFocusRect(Rect);

    // drawing in Windows compatible XOR style

    p:=ctx.ROP2;
    opn:=ctx.Pen;
    pn:=TCocoaPen.Create(clDkGray, psSolid, true, 2, pmCopy, pecFlat, pjsRound, false );
    try
      ctx.Pen:=pn;
      ctx.ROP2:=R2_NOTXORPEN;
      ctx.Pen.Apply(ctx, true);
      r:=Rect;
      dec(r.Right);
      dec(r.Bottom);
      ctx.Frame(r);
    finally
      ctx.ROP2:=p;
      ctx.Pen:=opn;
      pn.Free;
    end;
  end;
end;

procedure DrawEdgeRect(dst: TCocoaContext; const r: TRect; flags: Cardinal;
  LTColor, BRColor: TColor);
begin
  dst.Pen.SetColor(LTColor, true);
  dst.Pen.Apply(dst);
  if flags and BF_LEFT > 0 then
  begin
    dst.MoveTo(r.Left, r.Bottom);
    dst.LineTo(r.Left, r.Top);
  end;
  if flags and BF_TOP > 0 then
  begin
    dst.MoveTo(r.Left, r.Top);
    dst.LineTo(r.Right, r.Top);
  end;

  dst.Pen.SetColor(BRColor, true);
  dst.Pen.Apply(dst);
  if flags and BF_RIGHT > 0 then
  begin
    dst.MoveTo(r.Right, r.Top);
    dst.LineTo(r.Right, r.Bottom);
  end;
  if flags and BF_BOTTOM > 0 then
  begin
    dst.MoveTo(r.Right, r.Bottom);
    // there's a missing pixel. Seems like it's accumulating an offset
    dst.LineTo(r.Left-1, r.Bottom);
  end;
end;

function TCocoaWidgetSet.DrawEdge(DC: HDC; var Rect: TRect; edge: Cardinal;
  grfFlags: Cardinal): Boolean;
var
  ctx: TCocoaContext;
  r: TRect;
  keepPen   : TCocoaPen;
  edgePen   : TCocoaPen;
  keepBrush : TCocoaBrush;
  edgeBrush : TCocoaBrush;
const
  OutLT = cl3DLight;    // the next to hilight
  OutBR = cl3DDkShadow; // the darkest (almost black)
  InnLT = cl3DHiLight;  // the lightest (almost white)
  InnBR = cl3DShadow;   // darker than light, lighter than dark shadow
begin
  ctx := CheckDC(DC);
  Result := Assigned(ctx);
  if not Result then Exit;

  keepPen := ctx.Pen;
  keepBrush := ctx.Brush;
  try
    edgePen := TCocoaPen.Create($FFFFFF, psSolid, false, 1, pmCopy, pecRound, pjsRound);
    edgeBrush := TCocoaBrush.Create(NSColor.whiteColor, false);
    edgeBrush.Solid := false;
    ctx.Pen := edgePen;
    ctx.Brush := edgeBrush;

    r := Rect;
    if (edge and BDR_OUTER > 0) then
    begin
      if edge and BDR_RAISEDOUTER > 0 then
        DrawEdgeRect(ctx, r, grfFlags, OutLT, OutBR)
      else
        DrawEdgeRect(ctx, r, grfFlags, InnBR, InnLT);
      InflateRect(r, -1, -1);
    end;

    if (edge and BDR_INNER > 0) then
    begin
      if edge and BDR_RAISEDINNER > 0 then
        DrawEdgeRect(ctx, r, grfFlags, InnLT, InnBR)
      else
        DrawEdgeRect(ctx, r, grfFlags, OutBR, OutLT);
    end;

  finally
    ctx.Pen := keepPen;
    ctx.Brush := keepBrush;
    edgeBrush.Free;
    edgePen.Free;
  end;

  Result := true;
end;

function TCocoaWidgetSet.Ellipse(DC: HDC; x1, y1, x2, y2: Integer): Boolean;
var
  ctx: TCocoaContext;
begin
  ctx := CheckDC(DC);
  Result := Assigned(ctx);
  if Result then
    ctx.Ellipse(x1, y1, x2, y2);
end;

function TCocoaWidgetSet.EnableWindow(hWnd: HWND; bEnable: Boolean): Boolean;
var
  obj : NSObject;
begin
  Result := hWnd <> 0;
  if Result then
  begin
    obj := NSObject(hWnd);

    // The following check is actually a hack. LCL enables all windows disabled
    // during ShowModal form. No matter if the windows are on the stack of the modality or not.
    // Since Cocoa doesn't do much of the "modal" control over the windows
    // (runWindowModal isn't used... maybe it should be?)
    // It's possible that windows "disabled" by a another model window would be
    // re-enabled. This check verifies that only a window on the top of the modal stack
    // will be brought back active... what about other windows?
    if bEnable and isModalSession and (obj.isKindOfClass(TCocoaWindowContent)) then begin
      if not (TCocoaWindowContent(obj).isembedded)
        and not isTopModalWin(TCocoaWindowContent(obj).window) then Exit;
    end;
    obj.lclSetEnabled(bEnable);

    if (CaptureControl <> 0)
      and (not bEnable)
      and (obj.isKindOfClass(NSView))
      and NSViewIsLCLEnabled(NSView(obj)) then
      ReleaseCapture
  end;
end;

function TCocoaWidgetSet.EndPaint(Handle: hwnd; var PS: TPaintStruct): Integer;
begin
  Result:=inherited EndPaint(Handle, PS);
end;

function TCocoaWidgetSet.EnumFontFamiliesEx(DC: HDC; lpLogFont: PLogFont;
  Callback: FontEnumExProc; Lparam: LParam; Flags: dword): longint;
var
  fname: NSString;
  ELogFont: TEnumLogFontEx;
  Metric: TNewTextMetricEx;
  FontName: AnsiString;
begin
  Result := 0;
  if not Assigned(Callback) then Exit;
  for fname in NSFontManager.sharedFontManager.availableFontFamilies do
  begin
    try
      FontName := NSStringToString(fname);
      FillChar(ELogFont, SizeOf(ELogFont), #0);
      FillChar(Metric, SizeOf(Metric), #0);
      ELogFont.elfLogFont.lfFaceName := FontName;
      ELogFont.elfFullName := FontName;
      //todo: read the data from all fonts of the fontfamily
      Result := CallBack(ELogFont, Metric, TRUETYPE_FONTTYPE, lparam);
      if Result = 0 then Break;
    except
      Break;
    end;
  end;
end;

// According to the documentation of NSScreen.screen It's recommended
// not to cache NSScreen objects stored in the array. As those might change.
// However, according to the same documentation, the objects can change
// only with a notificatio sent out. BUT while using a macincloud (remote desktop)
// services, it was identified that NSScreen object CAN change without any notification.
// So, instead of passing NSScreen as HMonitor, only INDEX+1 in NSScreen.screen
// is used.
function IndexToHMonitor(i: NSUInteger): HMonitor;
begin
  if i = NSIntegerMax then Result := 0
  else Result := i + 1;
end;

function HMonitorToIndex(h: HMonitor): NSUInteger;
begin
  if h = 0 then Result := NSIntegerMax
  else Result := NSUInteger(h)-1;
end;

function TCocoaWidgetSet.EnumDisplayMonitors(hdc: HDC; lprcClip: PRect;
  lpfnEnum: MonitorEnumProc; dwData: LPARAM): LongBool;
var
  i: NSUInteger;
  cnt: NSUInteger;
begin
  Result := True;
  cnt := NSScreen.screens.count;
  if cnt = 0 then
  begin
    Result := false;
    Exit;
  end;
  for i := 0 to NSScreen.screens.count - 1 do
  begin
    Result := Result and lpfnEnum(IndexToHMonitor(i), 0, nil, dwData);
    if not Result then break;
  end;
end;

function TCocoaWidgetSet.ExcludeClipRect(dc: hdc;
  Left, Top, Right, Bottom : Integer) : Integer;
var
  RRGN : HRGN;
  R : TRect;
begin
  // there seems to be a bug in TWidgetset ExcludeClipRect.
  // as it doesn't use LPtoDP() (as IntersectClipRect does).
  // Fixing the problem here.
  R := Types.Rect(Left, Top, Right, Bottom);
  LPtoDP(DC, R, 2);

  If DCClipRegionValid(DC) then begin
    //DebugLn('TWidgetSet.ExcludeClipRect A DC=',DbgS(DC),' Rect=',Left,',',Top,',',Right,',',Bottom);
    // create the rectangle region, that should be excluded
    RRGN := CreateRectRgn(R.Left,R.Top,R.Right,R.Bottom);
    Result := ExtSelectClipRGN(DC, RRGN, RGN_DIFF);
    //DebugLn('TWidgetSet.ExcludeClipRect B Result=',Result);
    DeleteObject(RRGN);
  end else
    Result:=ERROR;
end;


function TCocoaWidgetSet.ExtSelectClipRGN(dc: hdc; rgn: hrgn; Mode: Longint): Integer;
var
  ctx: TCocoaContext;
begin
  ctx := CheckDC(DC);
  if Assigned(ctx) then
    Result := CocoaRegionTypeToWin32Map[ctx.SetClipRegion(TCocoaRegion(rgn), CocoaCombineMode(Mode))]
  else
    Result := ERROR;
end;

function TCocoaWidgetSet.ExtCreatePen(dwPenStyle, dwWidth: DWord;
  const lplb: TLogBrush; dwStyleCount: DWord; lpStyle: PDWord): HPEN;
begin
  Result := HPEN(TCocoaPen.Create(dwPenStyle, dwWidth, lplb, dwStyleCount, lpStyle));
end;

function TCocoaWidgetSet.ExtTextOut(DC: HDC; X, Y: Integer; Options: Longint;
  Rect: PRect; Str: PChar; Count: Longint; Dx: PInteger): Boolean;
var
  ctx: TCocoaContext;
begin
  ctx := CheckDC(DC);
  Result := Assigned(ctx);
  if Assigned(ctx) then
    ctx.TextOut(X, Y, Options, Rect, Str, Count, Dx);
end;

function TCocoaWidgetSet.FillRect(DC: HDC; const Rect: TRect; Brush: HBRUSH): Boolean;
var
  ctx: TCocoaContext;
  br: TCocoaGDIObject;
begin
  ctx := CheckDC(DC);
  br := CheckGDIOBJ(Brush);
  Result := Assigned(ctx) and (not Assigned(br) or (br is TCocoaBrush));
  if not Result then Exit;

  ctx.Rectangle(Rect.Left, Rect.Top, Rect.Right, Rect.Bottom, True, TCocoaBrush(br));
end;

function TCocoaWidgetSet.FillRgn(DC: HDC; RegionHnd: HRGN; hbr: HBRUSH): Bool;
var
  OldRgn: TCocoaRegion;
  R: TRect;
  Clipped: Boolean;
  ctx: TCocoaContext;
  br: TCocoaGDIObject;
  I: Integer;
begin
  ctx := CheckDC(DC);
  br := CheckGDIOBJ(hbr);
  Result := Assigned(ctx) and (not Assigned(br) or (br is TCocoaBrush));
  if not Result then Exit;

  Clipped := ctx.Clipped;
  I := ctx.SaveDC;
  if Clipped then
    OldRgn := TCocoaRegion.CreateDefault;
  try
    if Clipped then
      ctx.CopyClipRegion(OldRgn);
    if SelectClipRgn(DC, RegionHnd) <> ERROR then
    begin
      R := TCocoaRegion(RegionHnd).GetBounds;
      with R do
        ctx.Rectangle(Left, Top, Right, Bottom, True, TCocoaBrush(br));
      if Clipped then
        SelectClipRgn(DC, HRGN(OldRgn));
      Result := True;
    end;
  finally
    if Clipped then
      OldRgn.Free;
    ctx.RestoreDC(I);
  end;
end;

function TCocoaWidgetSet.Frame3d(DC: HDC; var ARect: TRect;
  const FrameWidth: integer; const Style: TBevelCut): Boolean;
var
  ctx: TCocoaContext;
begin
  ctx := CheckDC(DC);
  Result := Assigned(ctx) and (FrameWidth > 0);
  if Result then
    ctx.Frame3d(ARect, FrameWidth, Style);
end;

function TCocoaWidgetSet.FrameRect(DC: HDC; const ARect: TRect; hBr: HBRUSH): Integer;
var
  ctx: TCocoaContext;
begin
  ctx := CheckDC(DC);
  if Assigned(ctx) then
  begin
    ctx.FrameRect(ARect, TCocoaBrush(hBr));
    Result := -1;
  end
  else
    Result := 0;
end;

function TCocoaWidgetSet.GetActiveWindow: HWND;
var
  wn : NSWindow;
begin
  // return the currect application active window
  wn := NSApp.keyWindow;
  if not Assigned(wn) then Result := 0
  else Result := HWND(wn.contentView);
end;

function TCocoaWidgetSet.GetBkColor(DC: HDC): TColorRef;
var
  ctx: TCocoaContext;
begin
  ctx := CheckDC(DC);
  if Assigned(ctx) then
    Result := ctx.BkColor
  else
    Result := CLR_INVALID;
end;

function TCocoaWidgetSet.GetCapture: HWND;
begin
  Result:=FCaptureControl;
end;

function TCocoaWidgetSet.GetCaretPos(var lpPoint: TPoint): Boolean;
begin
  Result := CocoaCaret.GetCaretPos(lpPoint);
end;

function TCocoaWidgetSet.GetCaretRespondToFocus(handle: HWND;
  var ShowHideOnFocus: boolean): Boolean;
begin
  Result := inherited GetCaretRespondToFocus(handle, ShowHideOnFocus);
end;

{------------------------------------------------------------------------------
  function ShowWindow(hWnd: HWND; nCmdShow: Integer): Boolean;

  nCmdShow:
    SW_SHOWNORMAL, SW_MINIMIZE, SW_SHOWMAXIMIZED
------------------------------------------------------------------------------}
function TCocoaWidgetSet.ShowWindow(hWnd: HWND; nCmdShow: Integer): Boolean;
var
  win: NSWindow;
  lCocoaWin: TCocoaWindow = nil;
  lWinContent: TCocoaWindowContent = nil;
  disableFS : Boolean;
const
  NSFullScreenWindowMask = 1 shl 14;

begin
  Result:=true;
  {$ifdef VerboseCocoaWinAPI}
    DebugLn('TCocoaWidgetSet.ShowWindow');
  {$endif}

  // for regular controls (non-window or embedded window, acting as a control)
  if (not NSObject(hWnd).isKindOfClass(TCocoaWindowContent)) or (TCocoaWindowContent(hWnd).isembedded) then
  begin
    NSObject(hWnd).lclSetVisible(nCmdSHow <> SW_HIDE);
    Exit;
  end;

  // for windows
  lWinContent := TCocoaWindowContent(hWnd);

  //todo: should it be lclOwnWindow?
  if Assigned(lWinContent.fswin) then
    win := lWinContent.fswin
  else
    win := NSWindow(lWinContent.window);

  disableFS := false;
  if win.isKindOfClass(TCocoaWindow) then
  begin
    lCocoaWin := TCocoaWindow(win);
    disableFS := Assigned(lCocoaWin) and (lCocoaWin.lclIsFullScreen) and (nCmdShow <> SW_SHOWFULLSCREEN);
  end;

  if disableFS and Assigned(lCocoaWin) then
    lCocoaWin.lclSwitchFullScreen(false);

  case nCmdShow of
    SW_SHOW, SW_SHOWNORMAL:
      win.orderFront(nil);
    SW_HIDE:
      win.orderOut(nil);
    SW_MINIMIZE:
      win.miniaturize(nil);
    SW_MAXIMIZE:
      win.zoom(nil);
    SW_SHOWFULLSCREEN:
      if Assigned(lCocoaWin) then
        lCocoaWin.lclSwitchFullScreen(true);
  end;
end;

function TCocoaWidgetSet.StretchBlt(DestDC: HDC; X, Y, Width, Height: Integer;
  SrcDC: HDC; XSrc, YSrc, SrcWidth, SrcHeight: Integer; ROp: Cardinal
  ): Boolean;
begin
  Result := StretchMaskBlt(DestDC, X, Y, Width, Height, SrcDC, XSrc, YSrc,
    SrcWidth, SrcHeight, 0, 0, 0, Rop);
end;

function TCocoaWidgetSet.StretchMaskBlt(DestDC: HDC; X, Y, Width,
  Height: Integer; SrcDC: HDC; XSrc, YSrc, SrcWidth, SrcHeight: Integer;
  Mask: HBITMAP; XMask, YMask: Integer; Rop: DWORD): Boolean;
var
  SrcCtx, DestCtx: TCocoaContext;
begin
  DestCtx := CheckDC(DestDC);
  SrcCtx := CheckDC(SrcDC);

  Result := Assigned(DestCtx) and Assigned(SrcCtx);

  if not Result then
    Exit;

  if not (SrcCtx is TCocoaBitmapContext) then
  begin
    DebugLn('StretchMaskBlt Error - invalid source device context ', SrcCtx.ClassName,
      ', expected TCocoaBitmapContext!');
    Exit;
  end;

  Result := DestCtx.StretchDraw(X, Y, Width, Height,
    TCocoaBitmapContext(SrcCtx), XSrc, YSrc, SrcWidth, SrcHeight,
    TCocoaBitmap(Mask), XMask, YMask, Rop);
end;

function TCocoaWidgetSet.SystemParametersInfo(uiAction: DWord; uiParam: DWord;
  pvParam: Pointer; fWinIni: DWord): LongBool;
begin
  Result := True;
  case uiAction of
    SPI_GETWHEELSCROLLLINES: PDword(pvPAram)^ := 3;
    SPI_GETWORKAREA:
    begin
      NSToLCLRect(NSScreen(NSScreen.screens.objectAtIndex(0)).visibleFrame
        , NSScreenZeroHeight
        , TRect(pvParam^));
    end;
  else
    Result := False;
  end
end;

{------------------------------------------------------------------------------
  Method:  GetWindowRect
  Params:  Handle - Handle of window
           Rect   - Record for window coordinates
  Returns: if the function succeeds, the return value is nonzero; if the
           function fails, the return value is zero

  Retrieves the screen bounding rectangle of the specified window
 ------------------------------------------------------------------------------}
function TCocoaWidgetSet.GetWindowRect(Handle: hwnd; var ARect: TRect): Integer;
var
  dx, dy: Integer;
begin
  if Handle <> 0 then
  begin
    ARect := NSObject(Handle).lclFrame;
    if not NSObject(Handle).isKindOfClass_(NSWindow) then
    begin
      dx := 0;
      dy := 0;
      NSObject(Handle).lclLocalToScreen(dx, dy);
      MoveRect(ARect, dx, dy);
    end;
    Result := 1;
  end else
    Result := 0;
end;

function TCocoaWidgetSet.IsWindowEnabled(Handle: HWND): boolean;
begin
  if Handle<>0
    then Result:=NSObject(Handle).lclIsEnabled
    else Result:=False;
end;

function TCocoaWidgetSet.IsWindowVisible(Handle: HWND): boolean;
begin
  if Handle<>0
    then Result:=NSObject(Handle).lclIsVisible
    else Result:=False;
end;

function TCocoaWidgetSet.GetClientBounds(handle : HWND; var ARect : TRect) : Boolean;
begin
  Result := Handle <> 0;
  if Result then
    ARect := NSObject(handle).lclClientFrame;
end;

function TCocoaWidgetSet.GetClientRect(handle : HWND; var ARect : TRect) : Boolean;
begin
  Result := Handle <> 0;
  if Result then
  begin
    ARect := NSObject(handle).lclClientFrame;
    OffsetRect(ARect, -ARect.Left, -ARect.Top);
  end;
end;

function TCocoaWidgetSet.GetClipBox(DC: hDC; lpRect: PRect): Longint;
var
  ctx: TCocoaContext;
begin
  ctx := CheckDC(DC);
  if Assigned(ctx) and Assigned(lpRect) then
  begin
    lpRect^ := ctx.GetClipRect;
    Result := COMPLEXREGION;
  end
  else
    Result := ERROR;
end;

function TCocoaWidgetSet.GetClipRGN(DC: hDC; RGN: hRGN): Longint;
var
  ctx: TCocoaContext;
begin
  ctx := CheckDC(DC);
  if Assigned(ctx) and (RGN <> 0) then
    Result := CocoaRegionTypeToWin32Map[ctx.CopyClipRegion(TCocoaRegion(RGN))]
  else
    Result := ERROR;
end;

function TCocoaWidgetSet.GetCursorPos(var lpPoint: TPoint ): Boolean;
begin
  with NSEvent.mouseLocation do
  begin
    lpPoint.x := Round(x);
    // cocoa returns cursor with inverted y coordinate
    lpPoint.y := Round(NSScreenZeroHeight-y);
  end;
  //debugln('GetCursorPos='+DbgS(lpPoint));
  Result := True;
end;

function TCocoaWidgetSet.GetMonitorInfo(hMonitor: HMONITOR; lpmi: PMonitorInfo): Boolean;
var
  Scr0Height:  CGFloat;
  ScreenID: NSScreen;
  idx : NSUInteger;
begin
  Result := (lpmi <> nil) and (lpmi^.cbSize >= SizeOf(TMonitorInfo));
  if not Result then Exit;
  idx := HMonitorToIndex(hMonitor);
  Result := (idx < NSScreen.screens.count);
  if not Result then Exit;

  Scr0Height := NSScreenZeroHeight;
  ScreenID := NSScreen(NSScreen.screens.objectAtIndex(idx));
  NSToLCLRect(ScreenID.frame, Scr0Height, lpmi^.rcMonitor);
  NSToLCLRect(ScreenID.visibleFrame, Scr0Height, lpmi^.rcWork);
  // according to the documentation the primary (0,0 coord screen)
  // is always and index 0
  if idx = 0 then
    lpmi^.dwFlags := MONITORINFOF_PRIMARY
  else
    lpmi^.dwFlags := 0;
end;

function TCocoaWidgetSet.GetObject(GDIObj: HGDIOBJ; BufSize: Integer; Buf: Pointer): Integer;
var
  AObject: TCocoaGDIObject;
  DIB: TDIBSection;
  Width, Height, RequiredSize, i: Integer;
  Traits: NSFontTraitMask;

  APen: TCocoaPen absolute AObject;
  ALogPen: PLogPen absolute Buf;
  AExtLogPen: PExtLogPen absolute Buf;
  AFont: TCocoaFont absolute AObject;
  ALogFont: PLogFont absolute Buf;
begin
  Result := 0;

  AObject := CheckGDIObj(GDIObj);

  if AObject is TCocoaBitmap then
  begin
    if Buf = nil then
    begin
      Result := SizeOf(TDIBSection);
      Exit;
    end;

    Width := TCocoaBitmap(AObject).Width;
    Height := TCocoaBitmap(AObject).Height;

    FillChar(DIB, SizeOf(TDIBSection), 0);

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
  if AObject is TCocoaPen then
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
  end;
  if AObject is TCocoaFont then
  begin
    if Buf = nil then
      Result := SizeOf(TLogFont)
    else
    if BufSize >= SizeOf(TLogFont) then
    begin
      Result := SizeOf(TLogFont);
      FillChar(ALogFont^, SizeOf(ALogFont^), 0);
      ALogFont^.lfFaceName := AFont.Name;
      ALogFont^.lfHeight := -AFont.Size; // Cocoa supports only full height (with leading) that corresponds with a negative value in WinAPI
      Traits := NSFontManager.sharedFontManager.traitsOfFont(AFont.Font);
      if (Traits and NSFontBoldTrait) <> 0 then
        ALogFont^.lfWeight := FW_BOLD
      else
        ALogFont^.lfWeight := FW_NORMAL;
      if (Traits and NSFontItalicTrait) <> 0 then
        ALogFont^.lfItalic := 1
      else
        ALogFont^.lfItalic := 0;
    end;
  end;
end;

function TCocoaWidgetSet.GetParent(Handle : HWND): HWND;
begin
  if Handle<>0 then
    Result:=HWND(NSObject(Handle).lclParent)
  else
    Result:=0;
end;

function TCocoaWidgetSet.GetWindowRelativePosition(Handle: hwnd; var Left, Top: Integer): boolean;
begin
  Result := Handle <> 0;
  if Result then
    NSObject(handle).lclRelativePos(Left, Top);
end;

function TCocoaWidgetSet.GetWindowSize(Handle: hwnd; var Width, Height: Integer): boolean;
var
  r: TRect;
  lView: NSView;
begin
  Result := Handle <> 0;
  if not Result then Exit;

  r := NSObject(Handle).lclFrame;
  Width := R.Right - R.Left;
  Height := R.Bottom - R.Top;
end;

function TCocoaWidgetSet.InitStockFont(AFont: TObject; AStockFont: TStockFont): Boolean;
var
  Font: TFont absolute AFont;
  CTFont: CTFontRef;
  CTFontName: CFStringRef;
  CTFontSize: CGFloat;
  CTFontType: CTFontUIFontType;
begin
  Result := False;

  case AStockFont of
    sfSystem:  // stock system font
      CTFontType := kCTFontSystemFontType;
    sfHint:    // stock hint font
      CTFontType := kCTFontToolTipFontType;
    sfIcon:    // stock icon font
      CTFontType := kCTFontViewsFontType;
    sfMenu:     // stock menu font
      CTFontType := kCTFontMenuItemFontType;
  end;

  CTFont :=  CTFontCreateUIFontForLanguage(CTFontType, 0, nil);
  try
    CTFontName := CTFontCopyFamilyName(CTFont);
    try
      Font.Name := CFStringToStr(CTFontName);
      finally
      CFRelease(CTFontName);
      end;
    CTFontSize := CTFontGetSize(CTFont);
    Font.Height := -Round(CTFontSize);
    finally
    CFRelease(CTFont);
    end;
  Result := True;
end;

function TCocoaWidgetSet.HideCaret(Handle: HWND): Boolean;
var
  lView: NSView;
begin
  if (Handle = 0)
    then lView := nil
    else lView := NSView(Handle).lclContentView;

  Result := CocoaCaret.HideCaret(lView);
end;

function TCocoaWidgetSet.InvalidateRect(aHandle: HWND; Rect: pRect; bErase: Boolean): Boolean;
begin
  Result := aHandle <> 0;
  if Result then
  begin
    if Assigned(Rect) then
      NSObject(aHandle).lclInvalidateRect(Rect^)
    else
      NSObject(aHandle).lclInvalidate;
  end;
end;

function TCocoaWidgetSet.UpdateWindow(Handle: HWND): Boolean;
begin
  Result := Handle <> 0;
  if Result then
    NSObject(Handle).lclUpdate;
end;

function TCocoaWidgetSet.GetProp(Handle: hwnd; Str: PChar): Pointer;
var
  PropStorage: TStringList;
  I: Integer;
begin
  if Handle <> 0 then
  begin
    PropStorage := NSObject(Handle).lclGetPropStorage;
    if Assigned(PropStorage) then
    begin
      I := PropStorage.IndexOf(Str);
      if I <> -1 then
        Result := PropStorage.Objects[I]
      else
        Result := nil;
    end
    else
      Result := nil;
  end else
    Result := nil;
end;

function TCocoaWidgetSet.IsWindow(handle: HWND): boolean;
var
  cbi : ICommonCallback;
  obj : TObject;
begin
  if handle <> 0 then
  begin
    cbi := NSObject(handle).lclGetCallback;
    Result := Assigned(cbi);
    if not Result then Exit;

    obj := cbi.GetCallbackObject;
    Result :=  (obj is TLCLCommonCallback)
      and (HWND(TLCLCommonCallback(obj).HandleFrame)=handle);
  end
  else
    Result := False;
end;

function ViewFromPoint(view: NSView;Point: TPoint): HWND;
var rect: TRect;
    p:TPoint;
    cb: ICommonCallback;
    cbo: TObject;
  hv  : NSView;
begin
  Result:=0;
  if not assigned(view) then
     exit;
  cb := view.lclGetCallback;
  if Assigned(cb) then
  begin
    cbo := cb.GetCallbackObject;
    if not (cbo is TLCLCommonCallback) then Exit;
    p:=Point;
    // The hit test is done by the out-side frame (Handle)
    hv := TLCLCommonCallback(cbo).HandleFrame;
    hv.lclScreenToLocal(p.X,p.Y);
    rect:=hv.lclClientFrame;
    if PtInRect(rect, p) then
      //if hv.lclClassName;
      Result := HWND(hv)
  end
end;

function RecurseSubviews(view: NSView;Point: TPoint):HWND;
var  sv:integer;
begin
  // first check views subview if there is a embedded view
  Result:=0;
  if not Assigned(view) or (view.isHidden) or (not view.lclIsEnabled) then Exit;
  sv:=0;
  while (Result=0) and (sv<view.subviews.count) do
    begin
    Result:=RecurseSubviews(view.subviews.objectAtIndex(sv),Point);
    inc(sv)
    end;
  if Result=0 then
     Result:=ViewFromPoint(view,Point);
end;

function TCocoaWidgetSet.WindowFromPoint(Point: TPoint): HWND;
var 
  winrect: TRect;
  windows: NSArray;
  win: integer;
  window, windowbelowpoint: NSWindow;
  p:NSPoint;
  winnr:NSInteger;
begin
  Result := 0;
  if not assigned(NSApp) then
    Exit;

  windows := NSApp.windows;
  for win := 0 to windows.count - 1 do
  begin
    window:=windows.objectAtIndex(win);
    p.x:=Point.X;
    p.y:=NSScreenZeroHeight-Point.Y;
    winnr:=NSWindow.windowNumberAtPoint_belowWindowWithWindowNumber(p,0);
    windowbelowpoint:=NSWindow(NSApp.windowWithWindowNumber(winnr));
    if windowbelowpoint=window then
    begin
      Result:=RecurseSubviews(window.contentView, Point);
      if Result<>0 then
      begin
        exit;
      end;
    end;
  end;
end;


function TCocoaWidgetSet.GetRgnBox(RGN: HRGN; lpRect: PRect): Longint;
begin
  Result := ERROR;
  if Assigned(lpRect) then
    lpRect^ := Types.Rect(0, 0, 0, 0);

  if not (TObject(RGN) is TCocoaRegion) then
    Exit;

  if Assigned(lpRect) then
  begin
    lpRect^ := TCocoaRegion(RGN).GetBounds;
    Result := CocoaRegionTypeToWin32Map[TCocoaRegion(RGN).GetType];
  end;
end;

function TCocoaWidgetSet.GetROP2(DC: HDC): Integer;
var
  ctx: TCocoaContext;
begin
  ctx := CheckDC(DC);
  if Assigned(ctx) then
    Result := ctx.ROP2
  else
    Result := 0;
end;

function TCocoaWidgetSet.SetProp(Handle: hwnd; Str: PChar; Data: Pointer): Boolean;
var
  PropStorage: TStringList;
begin
  Result := Handle <> 0;
  if Result then
  begin
    PropStorage := NSObject(Handle).lclGetPropStorage;
    Result := Assigned(PropStorage);
    if Result then
      PropStorage.AddObject(Str, TObject(Data));
  end;
end;

function TCocoaWidgetSet.SetROP2(DC: HDC; Mode: Integer): Integer;
var
  ctx: TCocoaContext;
begin
  ctx := CheckDC(DC);
  if Assigned(ctx) then
  begin
    Result := ctx.ROP2;
    ctx.ROP2 := Mode;
  end
  else
    Result := 0;
end;

{----------------------------- WINDOWS SCROLLING ------------------------------}

function TCocoaWidgetSet.GetScrollBarSize(Handle: HWND; BarKind: Integer): integer;
var
  sc  : NSScrollView;
  obj : NSObject;
begin
  obj := NSObject(Handle);
  Result := 0;
  if not Assigned(obj) then Exit;

  if obj.isKindOfClass(NSScrollView) then
  begin
    if (BarKind = SB_Vert) and Assigned(NSScrollView(obj).verticalScroller) then
      Result:=round(NSScrollView(obj).verticalScroller.frame.size.width)
    else if (BarKind = SB_Horz) and Assigned(NSScrollView(obj).horizontalScroller) then
      Result:=round(NSScrollView(obj).verticalScroller.frame.size.height)
    else
      Result := Round(NSScroller.scrollerWidth);
  end
  else
    Result := Round(NSScroller.scrollerWidth);
end;

function TCocoaWidgetSet.GetScrollbarVisible(Handle: HWND; SBStyle: Integer): boolean;
var
  obj : NSObject;
  sc  : NSScrollView;
  mn  : TCocoaManualScrollView;
begin
  obj := NSObject(Handle);
  Result := Assigned(obj);
  if not Result then Exit;

  if obj.isKindOfClass(TCocoaManualScrollHost) then
    obj := TCocoaManualScrollHost(obj).documentView;

  if obj.isKindOfClass(NSScrollView) then
  begin
    sc := NSScrollView(obj);
    case SBStyle of
      SB_Vert: Result := sc.hasVerticalScroller;
      SB_Horz: Result := sc.hasHorizontalScroller;
    else
      Result := sc.hasHorizontalScroller and sc.hasVerticalScroller;
    end;
  end
  else if obj.isKindOfClass(TCocoaManualScrollView) then
  begin
    mn := TCocoaManualScrollView(obj);
    case SBStyle of
      SB_Vert: Result := mn.hasVerticalScroller;
      SB_Horz: Result := mn.hasHorizontalScroller;
    else
      Result := mn.hasHorizontalScroller and mn.hasVerticalScroller;
    end;
  end
  else
    Result := False;
end;

function TCocoaWidgetSet.GetScrollInfo(Handle: HWND; BarFlag: Integer;
  var ScrollInfo: TScrollInfo): Boolean;
var
  sc : NSScrollView;
  obj : NSObject;
begin
  obj := NSObject(Handle);
  Result := Assigned(obj);
  if not Result then Exit;

  if obj.isKindOfClass(TCocoaManualScrollHost) then
    obj := TCocoaManualScrollHost(obj).documentView;

  if obj.isKindOfClass(TCocoaScrollBar) then
    Result := CocoaScrollBarGetScrollInfo(TCocoaScrollBar(obj), ScrollInfo)
  else
  if obj.isKindOfClass(TCocoaManualScrollView) then
  begin
    if BarFlag = SB_Vert then
      Result := CocoaScrollBarGetScrollInfo( TCocoaScrollBar(TCocoaManualScrollView(obj).verticalScroller), ScrollInfo)
    else
      Result := CocoaScrollBarGetScrollInfo( TCocoaScrollBar(TCocoaManualScrollView(obj).horizontalScroller), ScrollInfo);
  end else if obj.isKindOfClass(NSScrollView) then
    NSScrollViewGetScrollInfo(NSScrollView(obj), BarFlag, ScrollInfo)
  else
    Result := False;
end;

function TCocoaWidgetSet.GetStockObject(Value: Integer): THandle;
begin
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

    DEFAULT_GUI_FONT, SYSTEM_FONT:
      Result := FStockSystemFont;
    SYSTEM_FIXED_FONT:
      Result := FStockFixedFont;
  end;
end;

function TCocoaWidgetSet.GetSysColor(nIndex: Integer): DWORD;
var
  Color: NSColor;
  SysBrush: HBrush;
begin
  // 1. get the system brush - it has a NSColor reference
  SysBrush := GetSysColorBrush(nIndex);
  if SysBrush = 0 then
  begin
    Result := 0;
    Exit;
  end;

  Color := TCocoaBrush(SysBrush).Color;

  if Assigned(Color) then
    Result := NSColorToColorRef(Color)
  else
    Result := 0;
end;

function TCocoaWidgetSet.GetSysColorBrush(nIndex: Integer): HBRUSH;
var
  sys : NSColor;
begin
  if (nIndex < 0) or (nIndex > MAX_SYS_COLORS) then
  begin
    Result := 0;
    Exit;
  end;
  if (FSysColorBrushes[nIndex] = 0) then
    FSysColorBrushes[nIndex] := HBrush(TCocoaBrush.Create(SysColorToNSColor(nIndex), True))
  else
  begin
    // system wide can change the color on the fly
    TCocoaBrush(FSysColorBrushes[nIndex]).Color := SysColorToNSColor(nIndex)
  end;

  Result := FSysColorBrushes[nIndex];
end;

function TCocoaWidgetSet.SetScrollInfo(Handle : HWND; SBStyle : Integer; ScrollInfo: TScrollInfo; bRedraw : Boolean): Integer;
var
  si  : TScrollInfo;
  obj : NSObject;
  sc  : TCocoaScrollView;
  bar : TCocoaScrollBar;
  f   : NSSize;
  sz  : NSSize;
  flg : NSUInteger;
  hosted: Boolean;
begin
  obj := NSObject(Handle);
  Result := 0;
  if not Assigned(obj) then Exit;

  if obj.isKindOfClass(TCocoaManualScrollHost) then
  begin
    hosted := true;
    obj := TCocoaManualScrollHost(obj).documentView;
  end else
    hosted := false;

  if obj.isKindOfClass(TCocoaScrollView) then
  begin
    sc:=TCocoaScrollView(obj);
    if sc.isCustomRange and (ScrollInfo.fMask and SIF_RANGE>0) then begin
      f:=sc.frame.size;
      sz:=NSView(sc.documentView).frame.size; // type casting is here for the compiler. for i386 it messes up types
      flg:=sc.documentView.autoresizingMask;

      if SBStyle=SB_Horz then begin
        if ScrollInfo.nMax>f.width then begin
          sz.width := ScrollInfo.nMax;
          flg:=flg and not NSViewWidthSizable;
        end else begin
          sz.width := f.width;
          flg:=flg or NSViewWidthSizable;
        end;
      end else if SBStyle=SB_Vert then begin
        if ScrollInfo.nMax>f.height then begin
          sz.height := ScrollInfo.nMax;
          flg:=flg and not NSViewHeightSizable;
        end else begin
          sz.height := f.height;
          flg:=flg or NSViewHeightSizable;
        end;
      end;
      sc.documentView.setAutoresizingMask(flg);
      sc.documentView.setFrameSize( sz );
    end;

    if ScrollInfo.fMask and SIF_ALL > 0 then
      NSScrollViewSetScrollPos(NSScrollView(obj), SBStyle, ScrollInfo);
    FillChar(si, sizeof(si), 0);
    si.cbSize:=sizeof(si);
    NSScrollViewGetScrollInfo(NSScrollView(obj), SBStyle, si);
    Result:=si.nPos;
  end else if obj.isKindOfClass(TCocoaManualScrollView) then
  begin
    bar:=nil;
    if SBStyle=SB_Vert then
      bar:= TCocoaScrollBar(TCocoaManualScrollView(obj).allocVerticalScroller(false))
    else if SBStyle=SB_Horz then
      bar:= TCocoaScrollBar(TCocoaManualScrollView(obj).allocHorizontalScroller(false));

    if Assigned(bar) then
    begin
      Result := CocoaScrollBarSetScrollInfo(bar, ScrollInfo);
      //debugln('TCocoaWidgetSet.SetScrollInfo page=',bar.pageInt,' min=',bar.minInt,' max=',bar.maxInt,' ',bar.lclPos);
      ShowScrollBar(Handle, SBStyle, bar.pageInt < bar.maxInt-bar.minInt);
    end
    else
      Result := 0;

    if hosted then
      NSView(obj).lclInvalidate;

  end else if obj.isKindOfClass(TCocoaScrollBar) then
  begin
    Result := CocoaScrollBarSetScrollInfo(TCocoaScrollBar(obj), ScrollInfo);
  end
  else
    Result := 0;
end;

function TCocoaWidgetSet.ShowScrollBar(Handle: HWND; wBar: Integer; bShow: Boolean): Boolean;
var
  obj : NSObject;
  sc  : TCocoaScrollView;
  mn  : TCocoaManualScrollView;
begin
  obj := NSObject(Handle);
  Result := Assigned(obj);
  if not Result then Exit;

  if obj.isKindOfClass(TCocoaManualScrollHost) then
    obj := TCocoaManualScrollHost(obj).documentView;

  if obj.isKindOfClass(TCocoaScrollView)
  then begin
    Result := true;
    sc := TCocoaScrollView(obj);
    if wBar in [SB_Vert, SB_Both] then
      sc.setHasVerticalScroller(bShow);

    if wBar in [SB_Horz, SB_Both] then
      sc.setHasHorizontalScroller(bShow);
  end
  else if obj.isKindOfClass(TCocoaManualScrollView)
  then begin
    mn := TCocoaManualScrollView(obj);

    if wBar in [SB_Vert, SB_Both] then
      mn.setHasVerticalScroller(bShow);

    if wBar in [SB_Horz, SB_Both] then
      mn.setHasHorizontalScroller(bShow);

    Result := true;
  end else
    Result := false;
end;

{----------------------------------- DRAWING ----------------------------------}


type
  TPointArray = array [word] of TPoint;
  PPointArray = ^TPointArray;

function TCocoaWidgetSet.LineTo(DC: HDC; X, Y: Integer): Boolean;
var
  ctx: TCocoaContext;
begin
  ctx := CheckDC(DC);
  Result := Assigned(ctx);
  if Result then
    ctx.LineTo(X, Y);
end;

function TCocoaWidgetSet.LPtoDP(DC: HDC; var Points; Count: Integer): BOOL;
var
  ctx: TCocoaContext;
  P: PPoint;
begin
  Result := False;
  ctx := CheckDC(DC);
  if not Assigned(ctx) then Exit;
  P := @Points;
  with ctx.GetLogicalOffset do
    while Count > 0 do
    begin
      Dec(Count);
      inc(P^.X, X);
      inc(P^.Y, Y);
      inc(P);
    end;
  Result := True;
end;

function TCocoaWidgetSet.OffsetRgn(RGN: HRGN; nXOffset, nYOffset: Integer): Integer;
begin
  if not (TObject(RGN) is TCocoaRegion) then
    Exit(ERROR);
  TCocoaRegion(RGN).Offset(nXOffset, nYOffset);
  Result := CocoaRegionTypeToWin32Map[TCocoaRegion(RGN).GetType];
end;

function TCocoaWidgetSet.MoveToEx(DC: HDC; X, Y: Integer; OldPoint: PPoint): Boolean;
var
  ctx: TCocoaContext;
begin
  ctx := CheckDC(DC);
  Result := Assigned(ctx);
  if Result then
  begin
    if Assigned(OldPoint) then
      OldPoint^ := ctx.PenPos;
    ctx.MoveTo(X, Y);
  end;
end;

{$push}
{$rangechecks off}
function TCocoaWidgetSet.Polygon(DC: HDC; Points: PPoint; NumPts: Integer; Winding: boolean): boolean;
var
  ctx: TCocoaContext;
begin
  ctx := CheckDC(DC);
  Result := Assigned(ctx) and Assigned(Points) and (NumPts >= 2);
  if Result then
    ctx.Polygon(PPointArray(Points)^, NumPts, Winding);
end;

function TCocoaWidgetSet.Polyline(DC: HDC; Points: PPoint; NumPts: Integer): boolean;
var
  ctx: TCocoaContext;
begin
  ctx := CheckDC(DC);
  Result := Assigned(ctx) and Assigned(Points) and (NumPts > 0);
  if Result then
    ctx.Polyline(PPointArray(Points)^, NumPts);
end;
{$pop}

type
  TLCLEventMessage = objcclass(NSObject)
    handle: HWND;
    msg: Cardinal;
    wp: WParam;
    lp: LParam;
    res: LResult;
    releaseAfterRun: Boolean;
    procedure lclRunEvent(sender: id); message 'lclRunEvent:';
  end;

procedure TLCLEventMessage.lclRunEvent(sender: id);
begin
  res := NSObject(handle).lclDeliverMessage(msg, wp, lp);
  if releaseAfterRun then self.release;
end;

function AllocLCLEventMessage(ahandle: HWND; amsg: Cardinal; awp: WParam; alp: LParam; forSend: Boolean): TLCLEventMessage;
begin
  Result := TLCLEventMessage.alloc.init;
  Result.handle := ahandle;
  Result.msg := amsg;
  Result.wp := awp;
  Result.lp := alp;
  Result.releaseAfterRun := not forSend;
end;


function TCocoaWidgetSet.PostMessage(Handle: HWND; Msg: Cardinal;
  wParam: WParam; lParam: LParam): Boolean;
var
  m: TLCLEventMessage;
begin
  Result := Handle <> 0;
  if Result then
  begin
    m:=AllocLCLEventMessage(Handle, Msg, wParam, lParam, false);
    m.performSelectorOnMainThread_withObject_waitUntilDone(
      ObjCSelector('lclRunEvent:'), nil, false
    );
  end;
end;

function TCocoaWidgetSet.Rectangle(DC: HDC; X1, Y1, X2, Y2: Integer): Boolean;
var
  ctx: TCocoaContext;
begin
  ctx := CheckDC(DC);
  Result := Assigned(ctx);
  if Result then
  begin
    // rectangle must be filled using current brush
    ctx.Rectangle(X1, Y1, X2, Y2, True, ctx.Brush);
    // and outlined by current pen
    ctx.Rectangle(X1, Y1, X2, Y2, False, nil);
  end;
end;

{------------------------------- SYNC OBJECTS ---------------------------------}

procedure TCocoaWidgetSet.InitializeCriticalSection(var CritSection: TCriticalSection);
begin
  CritSection:=TCriticalSection(NSRecursiveLock.alloc);
end;

procedure TCocoaWidgetSet.DeleteCriticalSection(var CritSection: TCriticalSection);
begin
  if CritSection=0 then Exit;
  NSRecursiveLock(CritSection).release;
  CritSection:=0;
end;

function TCocoaWidgetSet.DeleteDC(hDC: HDC): Boolean;
begin
  Result := hDC <> 0;
  if Result then
    TCocoaContext(hDC).Free;
end;

procedure TCocoaWidgetSet.EnterCriticalSection(var CritSection: TCriticalSection);
begin
  if CritSection=0 then Exit;
  NSRecursiveLock(CritSection).lock;
end;

procedure TCocoaWidgetSet.LeaveCriticalSection(var CritSection: TCriticalSection);
begin
  if CritSection=0 then Exit;
  NSRecursiveLock(CritSection).unlock;
end;

{------------------------------- DEVICE CONTEXT -------------------------------}

function TCocoaWidgetSet.GetDC(hWnd: HWND): HDC;
var
  ctx: TCocoaContext = nil;
  lCallback: ICommonCallback;
begin
  if hWnd = 0 then
    Result := HDC(ScreenContext)
  else
  begin
    lCallback := NSObject(hWnd).lclGetCallback;
    if lCallback <> nil then
      ctx := lCallback.GetContext;

    if ctx = nil then
    begin
      ctx := TCocoaContext.Create(DefaultContext.ctx);
      ctx.InitDraw(DefaultContext.size.cx, DefaultContext.size.cy);
    end;
    Result := HDC(ctx);
  end;

  {$IFDEF VerboseWinAPI}
    DebugLn('[TCocoaWidgetSet.GetDC] hWnd: %x Result: %x', [hWnd, Result]);
  {$ENDIF}
end;

function TCocoaWidgetSet.GetDCOriginRelativeToWindow(PaintDC: HDC;
  WindowHandle: HWND; var OriginDiff: TPoint): boolean;
begin
  Result:=PaintDC<>0;
  if Result then
    OriginDiff:=TCocoaContext(PaintDC).WindowOfs;
end;

function TCocoaWidgetSet.GetDeviceCaps(DC: HDC; Index: Integer): Integer;
var
  ctx: TCocoaContext;
begin
  ctx := CheckDC(DC);
  if not Assigned(ctx) then
    Exit(0);

  // todo: change implementation for printers
  case Index of
    HORZSIZE:
      Result := Round(NSScreen.mainScreen.frame.size.width / 72 * 25.4);
    VERTSIZE:
      Result := Round(NSScreen.mainScreen.frame.size.height / 72 * 25.4);
    HORZRES:
      Result := Round(NSScreen.mainScreen.frame.size.width);
    BITSPIXEL:
      // this is based on the main screen only. Should verify what actual DC is passed.
      // for VIEWS the typical BPP would be 32.
      case NSScreen.mainScreen.depth of
        NSWindowDepthTwentyfourBitRGB: //24-bit would be reported as 32
          Result := 32;
        NSWindowDepthSixtyfourBitRGB:
          Result := 64;
        NSWindowDepthOnehundredtwentyeightBitRGB:
          Result := 128;
      else
        Result := 32;
      end;

    PLANES:
      Result := 1;
    SIZEPALETTE:
      Result := 0;
    LOGPIXELSX:
      Result := 72;
    LOGPIXELSY:
      Result := 72;
    VERTRES:
      Result := Round(NSScreen.mainScreen.frame.size.height);
    NUMRESERVED:
      Result := 0;
  else
    DebugLn('TCocoaWidgetSet.GetDeviceCaps TODO Index: ' + DbgS(Index));
    Result := 0;
  end;
end;

function TCocoaWidgetSet.GetDeviceSize(DC: HDC; var P: TPoint): Boolean;
var
  ctx: TCocoaContext;
begin
  ctx := CheckDC(DC);
  Result := Assigned(ctx);
  if Result then
    with ctx.Size do
    begin
      P.X := cx;
      P.Y := cy;
    end;
end;

function TCocoaWidgetSet.GetFocus: HWND;
var
  Obj : NSObject;
  win : NSWindow;
  rsp : NSResponder;
  view : NSView;
  dl   : NSObject;
  cb   : ICommonCallback;
  cbobj : TObject;
begin
  Result := 0;
  win := NSApp.keyWindow;
  if not Assigned(win) then Exit;
  // assuming that that the content view of Window
  // is the focused handle and return it, by default
  Result := HWND(win.contentView);

  rsp := win.firstResponder;
  if not Assigned(rsp) then Exit;

  // todo: The HANDLE is allocated in "WS" side, thus we should be using
  //       "callback" object to determine, what actual NSView is the handle

  if rsp.isKindOfClass(TCocoaFieldEditor) then
  begin
    // field editor is a "popup" editor over many controls
    // the editor itself is never returned as any kind of HANDLE.
    // The handle is the box, that's editing
    dl := NSObject(TCocoaFieldEditor(rsp).delegate);
    if Assigned(dl) and (dl.isKindOfClass(NSView)) and Assigned(dl.lclGetCallback) then
      Result := HWND(dl);
  end
  else
  begin
    cb := rsp.lclGetCallback;
    if Assigned(cb) then
      cbobj := cb.GetCallbackObject
    else
      cbobj := nil;

    if (cbobj is TLCLCommonCallback) then
      Result := HWND(TLCLCommonCallback(cbobj).HandleFrame)
    else
      Result := 0;
  end;
end;

function TCocoaWidgetSet.GetForegroundWindow: HWND;
//var
//  App: NSRunningApplication;
begin
  // return the currect active window in the system
{ this is not possible because we can't access another application NSApplication
  for App in NSWorkSpace.sharedWorkspace.runningApplications do
    if App.isActive then
    begin
      Result := HWND(App.keyWindow);
      Exit;
    end;
}
  if NSApp.isActive then
    Result := HWND(NSApp.keyWindow)
  else
    Result := 0;
end;

function TCocoaWidgetSet.GetKeyState(nVirtKey: Integer): Smallint;
const
  StateDown    = SmallInt($FF80);
  StateToggled = SmallInt($0001);
  DownMap: array[Boolean] of SmallInt = (0, StateDown);
  ToggleMap: array[Boolean] of SmallInt = (0, StateToggled);
var
  Modifiers: NSUInteger;
begin
  // NSApp.currentEvent.modifierFlags doesn't work before events start coming,
  // see bug 29272 and http://lists.apple.com/archives/cocoa-dev/2010/Feb/msg00105.html
  Modifiers := NSEvent.modifierFlags_();
  case nVirtKey of
    VK_MENU,
    VK_LMENU:
      // the ssAlt/VK_MENU is mapped to optionKey under MacOS
      Result := DownMap[(Modifiers and NSAlternateKeyMask) <> 0];
    VK_SHIFT,
    VK_LSHIFT:
      Result := DownMap[(Modifiers and NSShiftKeyMask) <> 0];
    VK_CONTROL,
    VK_LCONTROL:
      Result := DownMap[(Modifiers and NSControlKeyMask) <> 0];
    VK_LWIN, VK_RWIN:
      Result := DownMap[(Modifiers and NSCommandKeyMask) <> 0];
    VK_CAPITAL:
      Result := ToggleMap[(Modifiers and NSAlphaShiftKeyMask) <> 0];
    VK_LBUTTON:
      Result := DownMap[(NSEvent.pressedMouseButtons() and $1) <> 0];
    VK_RBUTTON:
      Result := DownMap[(NSEvent.pressedMouseButtons() and $2) <> 0];
    VK_MBUTTON:
      Result := DownMap[(NSEvent.pressedMouseButtons() and $3) <> 0];
    VK_XBUTTON1:
      Result := DownMap[(NSEvent.pressedMouseButtons() and $4) <> 0];
    VK_XBUTTON2:
      Result := DownMap[(NSEvent.pressedMouseButtons() and $5) <> 0];
    else
      Result := 0;
  end;
end;

function TCocoaWidgetSet.SelectObject(ADC: HDC; GDIObj: HGDIOBJ): HGDIOBJ;
var
  dc: TCocoaContext;
  gdi: TCocoaGDIObject;
const
  SName = 'TCocoaWidgetSet.SelectObject';
begin
  {$IFDEF VerboseWinAPI}
    DebugLn(Format('TCocoaWidgetSet.SelectObject DC: %x GDIObj: %x', [ADC, GDIObj]));
  {$ENDIF}
  Result := 0;

  dc:=CheckDC(ADC);
  gdi:=CheckGDIOBJ(GDIObj);
  if not Assigned(dc) then Exit;
  if not Assigned(gdi) then Exit;

  if gdi is TCocoaBrush then
  begin // select brush
    Result := HBRUSH(dc.Brush);
    dc.Brush := TCocoaBrush(gdi);
  end else if gdi is TCocoaPen then
  begin // select pen
    Result := HPEN(dc.Pen);
    dc.Pen := TCocoaPen(gdi);
  end else if gdi is TCocoaFont then
  begin // select font
    Result := HFONT(dc.Font);
    dc.Font := TCocoaFont(gdi);
  end else if gdi is TCocoaRegion then
  begin // select region
    Result := HRGN(dc.Region);
    dc.Region := TCocoaRegion(gdi);
  end else if gdi is TCocoaBitmap then
  begin // select bitmap
    if not (dc is TCocoaBitmapContext) then
    begin
      DebugLn(SName + ' Error - The specified device context is not bitmap context!');
      Exit;
    end;
    Result := HBITMAP(TCocoaBitmapContext(dc).Bitmap);
    TCocoaBitmapContext(dc).Bitmap := TCocoaBitmap(gdi);
  end
  else
  begin
    DebugLn(SName + ' Error - Unknown Object Type ' + DbgSName(gdi));
    Exit;
  end;

  {$IFDEF VerboseWinAPI}
    DebugLn(Format('TCocoaWidgetSet.SelectObject Result: %x', [Result]));
  {$ENDIF}
end;

function TCocoaWidgetSet.SendMessage(Handle: HWND; Msg: Cardinal;
  WParam: WParam; LParam: LParam): LResult;
var
  m: TLCLEventMessage;
begin
  if Handle <> 0 then
  begin
    m:=AllocLCLEventMessage(Handle, Msg, wParam, lParam, true);
    m.performSelectorOnMainThread_withObject_waitUntilDone(
      ObjCSelector('lclRunEvent:'), nil, true
    );
    Result := m.res;
    m.release;
  end else
    Result := 0;
end;

function TCocoaWidgetSet.SetActiveWindow(Handle: HWND): HWND;
var
  Obj: NSObject;
begin
  Obj := NSObject(Handle);
  Result := 0; // should return 0, if function fails
  if Assigned(Obj) and NSApp.isActive then
  begin
    Result := HWND(NSApp.keyWindow.contentView);
    if (Handle <> 0) then
      NSView(Handle).window.makeKeyWindow;
  end;
end;

function TCocoaWidgetSet.SetBKColor(DC: HDC; Color: TColorRef): TColorRef;
var
  ctx: TCocoaContext;
begin
  ctx := CheckDC(DC);
  if Assigned(ctx) then
  begin
    Result := ctx.BkColor;
    ctx.BkColor := TColor(Color);
  end
  else
    Result := CLR_INVALID;
end;

function TCocoaWidgetSet.SetBkMode(DC: HDC; bkMode: Integer): Integer;
var
  ctx: TCocoaContext;
begin
  ctx := CheckDC(DC);
  if Assigned(ctx) then
  begin
    Result := ctx.BkMode;
    ctx.BkMode := bkMode;
  end
  else
    Result := 0;
end;

function TCocoaWidgetSet.SetCapture(AHandle: HWND): HWND;
begin
  Result := FCaptureControl;
  FCaptureControl := AHandle;
end;

function TCocoaWidgetSet.SetCaretPos(X, Y: Integer): Boolean;
begin
  Result := CocoaCaret.SetCaretPos(X, Y);
end;

function TCocoaWidgetSet.SetCaretPosEx(Handle: HWnd; X, Y: Integer): Boolean;
begin
  Result := CocoaCaret.SetCaretPos(X, Y);
end;

function TCocoaWidgetSet.SetCaretRespondToFocus(handle: HWND;
  ShowHideOnFocus: boolean): Boolean;
begin
  Result:=inherited SetCaretRespondToFocus(handle, ShowHideOnFocus);
end;

function TCocoaWidgetSet.RectVisible(dc: hdc; const ARect: TRect): Boolean;
var
  ClipBox: CGRect;
  ctx : TCocoaContext;
  R: TRect;
begin
  ctx := CheckDC(DC);
  Result := Assigned(ctx) and (ARect.Right > ARect.Left) and (ARect.Bottom > ARect.Top);

  if not Result then Exit;

  // In Quartz 2D there is no direct access to clipping path of CGContext,
  // therefore we can only test bounding box of the clipping path.

  ClipBox := CGContextGetClipBoundingBox(ctx.CGContext);
  Result := IntersectRect(R, ARect, CGRectToRect(ClipBox));
end;

function TCocoaWidgetSet.ReleaseCapture : Boolean;
begin
  FCaptureControl:=0;
  Result := True;
end;

function TCocoaWidgetSet.ReleaseDC(hWnd: HWND; DC: HDC): Integer;
var
  ctx: TCocoaContext;
begin
  Result := 0;
  ctx := CheckDC(DC);
  if not Assigned(ctx) then
    Exit;
  if (ctx <> DefaultContext) and (ctx<>ScreenContext) and (not ctx.isControlDC) then
    ctx.Free;
  Result := 1;
end;

function TCocoaWidgetSet.GetWindowOrgEx(dc: hdc; P: PPoint): Integer;
var
  ctx: TCocoaContext;
begin
  ctx := CheckDC(dc);
  if not Assigned(ctx) then
    Exit(0);
  if Assigned(P) then
    P^ := ctx.WindowOfs;
  Result:=1;
end;

function TCocoaWidgetSet.SetCursor(ACursor: HCURSOR): HCURSOR;
begin
  if ACursor = 0 then Result := 0 else
  Result := HCURSOR(TCocoaCursor(ACursor).Install);
end;

function TCocoaWidgetSet.SetCursorPos(X, Y: Integer): Boolean;
var
  CursorPos: CGPoint;
begin
  Result := False;

  CursorPos.X := X;
  CursorPos.Y := Y;
  if CGWarpMouseCursorPosition(CursorPos) <> noErr then Exit;
  Result := True;
end;

function NeedsFocusNotifcation(event: NSEvent; win: NSWindow): Boolean;
begin
  Result := (Assigned(win))
      and (not Assigned(event) or (event.window <> win));
end;

function TCocoaWidgetSet.SetFocus(Handle: HWND): HWND;
var
  Obj: NSObject;
  lView: NSView;
  cb: ICommonCallback;
begin
  if Handle <> 0 then
  begin
    Result := GetFocus;
    if Result = Handle then
      Exit;
    Obj := NSObject(Handle);
    if Obj.isKindOfClass(NSWindow) then
    begin
      NSWindow(Obj).makeKeyWindow;
      NSWindow(Obj).makeFirstResponder(nil);
    end
    else
    begin
      lView := obj.lclContentView;
      if lView <> nil then
      begin
        if lView.window <> nil then
        begin
          lView.window.makeKeyWindow;
          if lView.window.makeFirstResponder(lView.lclContentView) then
          begin
            // initial focus set (right before the event loop starts)
            if NeedsFocusNotifcation(NSApp.currentEvent, lView.window) then
            begin
              cb := lView.lclGetCallback;
              if Assigned(cb) then cb.BecomeFirstResponder;
            end;
          end;
        end else
          Result := 0; // the view is on window, cannot set focus. Fail
      end else
        Result := 0;
    end;
  end
  else
    Result := 0;
end;

function TCocoaWidgetSet.SetForegroundWindow(HWnd: HWND): boolean;
var
  Obj: NSObject;
  lWin: NSWindow;
begin
  Result := HWnd <> 0;
  if Result then
  begin
    {$ifdef BOOLFIX}
    NSApp.activateIgnoringOtherApps_(Ord(True));
    {$else}
    NSApp.activateIgnoringOtherApps(True);
    {$endif}
    Obj := NSObject(HWnd);
    lWin := NSWindow(GetNSObjectWindow(Obj));
    if lWin <> nil then
      lWin.makeKeyAndOrderFront(NSApp)
    else
      Result := False;
  end;
end;

function TCocoaWidgetSet.SetMenu(AWindowHandle: HWND; AMenuHandle: HMENU): Boolean;
var
  lWin: NSWindow;
  frm : TCustomForm;
begin
  Result := False;

  lWin := NSWindow(GetNSObjectWindow(NSObject(AWindowHandle)));

  frm := HWNDToForm(AWindowHandle);
  if Assigned(frm) and (csDesigning in frm.ComponentState) then begin
    Result := true;
    Exit;
  end;
  if not Assigned(frm) then Exit;

  if (lWin <> nil) and lWin.isKindOfClass(TCocoaWindow) and
     //todo: why is Menu handle checked here?
     (frm.Menu.Handle = AMenuHandle)
  then
  begin
    if lWin.isKeyWindow or lWin.isMainWindow then
      SetMainMenu(AMenuHandle, frm.Menu);
    Result := True;
  end;
end;

{------------------------------- FONT AND TEXT --------------------------------}

function TCocoaWidgetSet.SetTextColor(DC: HDC; Color: TColorRef): TColorRef;
var
  ctx: TCocoaContext;
begin
  ctx := CheckDC(DC);
  if Assigned(ctx) then
  begin
    Result := TColorRef(ctx.TextColor);
    ctx.TextColor := TColor(Color);
  end
  else
    Result := CLR_INVALID;
end;

function TCocoaWidgetSet.SetViewPortOrgEx(DC: HDC; NewX, NewY: Integer;
  OldPoint: PPoint): Boolean;
var
  ctx: TCocoaContext;
begin
  Result := False;
  ctx := CheckDC(DC);
  if not Assigned(ctx) then Exit;

  if Assigned(OldPoint) then
    OldPoint^ := ctx.ViewportOfs;
  ctx.ViewportOfs := Types.Point(NewX, NewY);
  Result := True;
end;

function TCocoaWidgetSet.SetWindowOrgEx(DC: HDC; NewX, NewY: Integer;
  OldPoint: PPoint): Boolean;
var
  ctx: TCocoaContext;
begin
  Result := False;
  ctx := CheckDC(DC);
  if not Assigned(ctx) then Exit;

  if Assigned(OldPoint) then
    OldPoint^ := ctx.WindowOfs;
  ctx.WindowOfs := Types.Point(NewX, NewY);
  Result := True;
end;

function TCocoaWidgetSet.ShowCaret(Handle: HWND): Boolean;
var
  lView: NSView;
begin
  //writeln('WinAPI. show caret ',PtrUInt(Handle));
  if (Handle = 0) then lView := nil
  else lView := NSView(Handle).lclContentView;

  Result := CocoaCaret.ShowCaret(lView)
end;

{------------------------------------------------------------------------------
  Method:  GetSystemMetrics
  Params:  NIndex - System metric to retrieve
  Returns: The requested system metric value

  Retrieves various system metrics.
 ------------------------------------------------------------------------------}
function TCocoaWidgetSet.GetSystemMetrics(nIndex: Integer): Integer;
begin
  Result := 0;

  {$IFDEF VerboseWinAPI}
    DebugLn('TCocoaWidgetSet.GetSystemMetrics NIndex: ' + DbgS(NIndex));
  {$ENDIF}

  case NIndex of
    SM_CXHSCROLL,
    SM_CYHSCROLL,
    SM_CXVSCROLL,
    SM_CYVSCROLL:
      Result := Round(NSScroller.scrollerWidthForControlSize(NSRegularControlSize));
    SM_CXSCREEN,
    SM_CXVIRTUALSCREEN,
    SM_CXFULLSCREEN: Result := Round(NSScreen.mainScreen.frame.size.width);
    SM_CYSCREEN,
    SM_CYVIRTUALSCREEN,
    SM_CYFULLSCREEN: Result := Round(NSScreen.mainScreen.frame.size.height);
    SM_XVIRTUALSCREEN: Result := Round(NSScreen.mainScreen.frame.origin.x);
    SM_YVIRTUALSCREEN: Result := Round(NSScreen.mainScreen.frame.origin.y);
    SM_CXSMICON,
    SM_CYSMICON:
      Result := 16;
    SM_CXICON,
    SM_CYICON:
      Result := 128;
    SM_CXCURSOR,
    SM_CYCURSOR:
      begin
{        if TCarbonCursor.HardwareCursorsSupported then
          Result := 64 else}
          Result := 16;
      end;
    SM_CXDRAG,SM_CYDRAG: Result := 5;
    SM_CXHTHUMB, SM_CYVTHUMB:
      Result := Round(NSScroller.scrollerWidthForControlSize(NSRegularControlSize));
    SM_SWSCROLLBARSPACING:
      Result := 0;
    SM_LCLHasFormAlphaBlend:
      Result := 1;
  else
    DebugLn('TCocoaWidgetSet.GetSystemMetrics TODO ', DbgS(NIndex));;
  end;

  {$IFDEF VerboseWinAPI}
    DebugLn('TCocoaWidgetSet.GetSystemMetrics Result: ' + DbgS(Result));
  {$ENDIF}
end;

function TCocoaWidgetSet.GetTextColor(DC: HDC) : TColorRef;
var
  ctx: TCocoaContext;
begin
  ctx := CheckDC(DC);
  if Assigned(ctx) then
    Result := ColorToRGB(ctx.TextColor)
  else
    Result := CLR_INVALID;
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
function TCocoaWidgetSet.GetTextExtentPoint(DC: HDC; Str: PChar; Count: Integer; var Size: TSize): Boolean;
var
  ctx : TCocoaContext;
begin
  {$IFDEF VerboseWinAPI}
    DebugLn('[TCocoaWidgetSet.GetTextExtentPoint] DC: %x Str: %s Count: %d', [DC, Str, Count]);
  {$ENDIF}
  ctx:=CheckDC(DC);
  Result:=Assigned(ctx);
  if not Assigned(ctx) then Exit(False);
  Result := ctx.GetTextExtentPoint(Str, Count, Size);
  {$IFDEF VerboseWinAPI}
    DebugLn('[TCocoaWidgetSet.GetTextExtentPoint] Size: %d,%d', [Size.cx, Size.cy]);
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
function TCocoaWidgetSet.GetTextMetrics(DC: HDC; var TM: TTextMetric): Boolean;
var
  ctx: TCocoaContext;
begin
  ctx := CheckDC(DC);
  Result := Assigned(ctx) and ctx.GetTextMetrics(TM);
end;

function TCocoaWidgetSet.GetViewPortOrgEx(DC: HDC; P: PPoint): Integer;
var
  ctx: TCocoaContext;
begin
  ctx := CheckDC(dc);
  if not Assigned(ctx) then
    Exit(0);
  if Assigned(P) then
    P^ := ctx.ViewportOfs;
  Result:=1;
end;

function TCocoaWidgetSet.TextOut(DC: HDC; X,Y: Integer; Str: Pchar; Count: Integer) : Boolean;
begin
  Result := ExtTextOut(DC, X, Y, 0, nil, Str, Count, nil);
end;

function TCocoaWidgetSet.SaveDC(DC: HDC): Integer;
var
  ctx: TCocoaContext;
begin
  ctx := CheckDC(DC);
  if Assigned(ctx) then
    Result := ctx.SaveDC
  else
    Result:=0;
end;

function TCocoaWidgetSet.ScreenToClient(Handle: HWND; var P: TPoint): Integer;
begin
  Result := Ord(Handle <> 0);

  if Result = 1 then
    NSObject(Handle).lclScreenToLocal(P.X, P.Y);
end;

function TCocoaWidgetSet.ScrollWindowEx(hWnd: HWND; dx, dy: Integer; prcScroll, prcClip: PRect; hrgnUpdate: HRGN; prcUpdate: PRect; flags: UINT): Boolean;
var
  obj: NSOBject;
  v : NSView;
begin
  obj:=NSObject(hWnd);
  Result:=Assigned(obj) and (obj.isKindOfClass(NSView));
  if not Result then Exit;

  v:=NSView(obj).lclContentView;
  // todo: parse the passed parameters.
  //       the content of the window could be already prepared
  //       thus not entire control should be invalided
  {$ifdef BOOLFIX}
  v.setNeedsDisplay__(Ord(true));
  {$else}
  v.setNeedsDisplay_(true);
  {$endif}
end;

function TCocoaWidgetSet.SelectClipRGN(DC: hDC; RGN: HRGN): Longint;
begin
  Result := ExtSelectClipRgn(DC, RGN, RGN_COPY);
end;

function TCocoaWidgetSet.SetSysColors(cElements: Integer; const lpaElements; const lpaRgbValues): Boolean;
var
  n: Integer;
  Element: LongInt;
  Color: NSColor;
begin
  Result := False;
  if cElements > MAX_SYS_COLORS then Exit;

  for n := 0 to cElements - 1 do
  begin
    Element := PInteger(@lpaElements)[n];
    if (Element > MAX_SYS_COLORS) or (Element < 0) then 
      Exit;
    Color := ColorToNSColor(PDWord(@lpaRgbValues)[n]);
    if (FSysColorBrushes[Element] <> 0) then
      TCocoaBrush(FSysColorBrushes[Element]).Color := Color
    else
      FSysColorBrushes[Element] := HBrush(TCocoaBrush.Create(Color, True));
  end;

  Result := True;
end;

function TCocoaWidgetSet.RestoreDC(DC: HDC; SavedDC: Integer): Boolean;
var
  ctx: TCocoaContext;
begin
  ctx := CheckDC(DC);
  if Assigned(ctx) then
    Result := ctx.RestoreDC(SavedDC)
  else
    Result := False;
end;

function TCocoaWidgetSet.RoundRect(DC: HDC; X1, Y1, X2, Y2: Integer; RX,
  RY: Integer): Boolean;
begin
  Result:=inherited RoundRect(DC, X1, Y1, X2, Y2, RX, RY);
end;

//##apiwiz##eps##   // Do not remove, no wizard declaration after this line

{%MainUnit gtk3int.pas}

function TGtk3WidgetSet.Arc(DC: HDC; Left, top, right, bottom, angle1,
  angle2: Integer): Boolean;
begin
  {$IFDEF GTK3DEBUGNOTIMPLEMENTED}
  DebugLn('WARNING: TGtk3WidgetSet.Arc not implemented ...');
  {$ENDIF}
  Result:=inherited Arc(DC, Left, top, right, bottom, angle1, angle2);
end;

function TGtk3WidgetSet.AngleChord(DC: HDC; x1, y1, x2, y2, angle1,
  angle2: Integer): Boolean;
begin
  {$IFDEF GTK3DEBUGNOTIMPLEMENTED}
  DebugLn('WARNING: TGtk3WidgetSet.AngleChord not implemented ...');
  {$ENDIF}
  Result:=inherited AngleChord(DC, x1, y1, x2, y2, angle1, angle2);
end;

function TGtk3WidgetSet.BeginPaint(Handle: hWnd; var PS: TPaintStruct): hdc;
var
  Widget: TGtk3Widget;
  GtkWidget: PGtkWidget;
  DC: TGtk3DeviceContext;
begin
  Widget := TGtk3Widget(Handle);
  if Widget <> nil then
  begin
    GtkWidget := Widget.GetContainerWidget;
    if Widget.CairoContext <> nil then
      DC := TGtk3DeviceContext.CreateFromCairo(GtkWidget, Widget.CairoContext)
    else
      DC := TGtk3DeviceContext.Create(GtkWidget, True);
  end
  else
    DC := TGtk3DeviceContext.Create(PGtkWidget(nil), True);

  PS.hdc := HDC(DC);

  if Handle<>0 then
  begin
    DC.vClipRect := Widget.PaintData.ClipRect^;
    (*
    // if current handle has paintdata information,
    // setup hdc with it
    //DC.DebugClipRect('BeginPaint: Before');
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
    *)
  end;

  Result := PS.hdc;
end;

function TGtk3WidgetSet.BitBlt(DestDC: HDC; X, Y, Width, Height: Integer;
  SrcDC: HDC; XSrc, YSrc: Integer; Rop: DWORD): Boolean;
begin
  {$ifdef VerboseGtk3DeviceContext}
    WriteLn('Trace:> [TGtk3WidgetSet.BitBlt]');
  {$endif}
  Result := StretchBlt(DestDC, X, Y, Width, Height, SrcDC, XSrc, YSrc, Width,
                       Height, ROP);

  {$ifdef VerboseGtk3DeviceContext}
    WriteLn('Trace:< [TGtk3WidgetSet.BitBlt]');
  {$endif}
end;

function TGtk3WidgetSet.CallNextHookEx(hHk: HHOOK; ncode: Integer;
  wParam: WParam; lParam: LParam): Integer;
begin
  {$IFDEF GTK3DEBUGNOTIMPLEMENTED}
  DebugLn('WARNING: TGtk3WidgetSet.CallNextHookEx not implemented ...');
  {$ENDIF}
  Result:=inherited CallNextHookEx(hHk, ncode, wParam, lParam);
end;

function TGtk3WidgetSet.CallWindowProc(lpPrevWndFunc: TFarProc; Handle: HWND;
  Msg: UINT; wParam: WParam; lParam: lParam): Integer;
begin
  {$IFDEF GTK3DEBUGNOTIMPLEMENTED}
  DebugLn('WARNING: TGtk3WidgetSet.CallWindowProc not implemented ...');
  {$ENDIF}
  Result:=inherited CallWindowProc(lpPrevWndFunc, Handle, Msg, wParam, lParam);
end;

function TGtk3WidgetSet.ClientToScreen(Handle: HWND; var P: TPoint): Boolean;
begin
  {$ifdef VerboseGtk3WinApi}
    DebugLn('Trace:> [TGtk3WidgetSet.ClientToScreen] ',dbgs(P));
  {$endif}
  // Result:=inherited ClientToScreen(Handle, P);
  Result := False;
  P := Point(0, 0);
  if IsValidHandle(Handle) then
    Result := TGtk3Widget(Handle).ClientToScreen(P);
  {$ifdef VerboseGtk3WinApi}
    DebugLn('Trace:< [TGtk3WidgetSet.ClientToScreen] ',dbgs(P),' result=',dbgs(Result));
  {$endif}
end;

function TGtk3WidgetSet.ClipboardFormatToMimeType(FormatID: TClipboardFormat
  ): string;
begin
  {$IFDEF GTK3DEBUGNOTIMPLEMENTED}
  DebugLn('WARNING: TGtk3WidgetSet.ClipboardFormatToMimeType not implemented ...');
  {$ENDIF}
  Result:=inherited ClipboardFormatToMimeType(FormatID);
end;

const
  sPrimary = 'PRIMARY';
  sClipboard = 'CLIPBOARD';

function TGtk3WidgetSet.ClipboardGetData(ClipboardType: TClipboardType;
  FormatID: TClipboardFormat; Stream: TStream): boolean;
var
  pclp:PGtkClipboard;
  pc:pgchar;
  pcname:PgdkAtom;
begin
  case ClipboardType of
  ctPrimarySelection: pcname:=TGdkAtom.intern(sPrimary,false);
  ctSecondarySelection: pcname:=nil;
  ctClipboard: pcname:=TGdkAtom.intern(sClipboard,false);
  end;
  if not Assigned(pcname) then exit;
  pclp:=TGtkClipboard.get(pcname);
  if not Assigned(pclp) then exit(false);
  // text handling
  //pclp^.request_text(@ClipboardTextReceivedFunc,Stream);
  pc:=pclp^.wait_for_text;
  Stream.Write(pc^,strlen(pc));
  Result:=true;
end;

function TGtk3WidgetSet.ClipboardGetFormats(ClipboardType: TClipboardType;
  var Count: integer; var List: PClipboardFormat): boolean;
begin
  {$IFDEF GTK3DEBUGNOTIMPLEMENTED}
  DebugLn('WARNING: TGtk3WidgetSet.ClipboardGetFormats not implemented ...');
  {$ENDIF}
  Result:=inherited ClipboardGetFormats(ClipboardType, Count, List);
end;

function TGtk3WidgetSet.ClipboardGetOwnerShip(ClipboardType: TClipboardType;
  OnRequestProc: TClipboardRequestEvent; FormatCount: integer;
  Formats: PClipboardFormat): boolean;
var
  pclp:PGtkClipboard;
  pcname:PgdkAtom;
begin
  case ClipboardType of
  ctPrimarySelection: pcname:=TGdkAtom.intern(sPrimary,false);
  ctSecondarySelection: pcname:=nil;
  ctClipboard: pcname:=TGdkAtom.intern(sClipboard,false);
  end;
  if not Assigned(pcname) then exit;
  pclp:=TGtkClipboard.get(pcname);
  if not Assigned(pclp) then exit(false);
{  // text handling
  //pclp^.request_text(@ClipboardTextReceivedFunc,Stream);
  pc:=pclp^.wait_for_text;
  Stream.Write(pc^,strlen(pc)); }
  Result:=true;
end;

function TGtk3WidgetSet.ClipboardRegisterFormat(const AMimeType: string): TClipboardFormat;
begin
  if Assigned(Application) then
    Result := {%H-}TClipboardFormat(TGdkAtom.intern(PChar(AMimeType), False))
  else
    RaiseGDBException(
      'ERROR: TGtk3WidgetSet.ClipboardRegisterFormat gdk not initialized');
end;

function TGtk3WidgetSet.CombineRgn(Dest, Src1, Src2: HRGN;
  fnCombineMode: Longint): Longint;
var
  RDest,RSrc1,RSrc2: Pcairo_region_t;
  AStatus: cairo_status_t;
  ACairoRect: Tcairo_rectangle_int_t;
begin
  {$IFDEF GTK3DEBUGNOTIMPLEMENTED}
  // DebugLn('WARNING: TGtk3WidgetSet.CombineRgn not implemented ...');
  {$ENDIF}
  Result := ERROR;
  if not IsValidGDIObject(Dest) or not IsValidGDIObject(Src1) then
    exit;
  RDest := TGtk3Region(Dest).Handle;
  RSrc1 := TGtk3Region(Src1).Handle;
  if (fnCombineMode<>RGN_COPY) and not IsValidGDIObject(Src2) then
    exit
  else
    RSrc2 := TGtk3Region(Src2).Handle;
  AStatus := CAIRO_STATUS_READ_ERROR;
  case fnCombineMode of
    RGN_AND:
    begin
      AStatus := cairo_region_intersect(RSrc1, RSrc2);
      // cairo cannot intersect empty region
      if cairo_region_is_empty(RDest) then
      begin
        cairo_region_destroy(TGtk3Region(Dest).Handle);
        cairo_region_get_extents(RSrc1, @ACairoRect);
        TGtk3Region(Dest).Handle := cairo_region_create_rectangle(@ACairoRect);
        RDest := TGtk3Region(Dest).Handle;
        //cairo_region_translate(RDest, -ACairoRect.x, -ACairoRect.y);
      end else
        AStatus := cairo_region_intersect(RDest, RSrc1);
    end;
    RGN_COPY:
    begin
      AStatus := cairo_region_intersect(RDest, RSrc1);
      // writeln('CombineRgn RGN_COPY ',AStatus);
    end;
    RGN_DIFF:
    begin
      AStatus := cairo_region_subtract(RSrc1, RSrc2);
      if cairo_region_is_empty(RDest) then
      begin
        cairo_region_destroy(TGtk3Region(Dest).Handle);
        cairo_region_get_extents(RSrc1, @ACairoRect);
        TGtk3Region(Dest).Handle := cairo_region_create_rectangle(@ACairoRect);
        RDest := TGtk3Region(Dest).Handle;
        cairo_region_translate(RDest, -ACairoRect.x, -ACairoRect.y);
      end else
        AStatus := cairo_region_subtract(RDest, RSrc1);
    end;
    RGN_OR:
    begin
      AStatus := cairo_region_union(RSrc1, RSrc2);
      AStatus := cairo_region_union(RDest, RSrc1);
    end;
    RGN_XOR:
    begin
      AStatus := cairo_region_xor(RSrc1, RSrc2);
      AStatus := cairo_region_xor(RDest, RSrc1);
    end;
  end;
  if (AStatus <> CAIRO_STATUS_SUCCESS) or cairo_region_is_empty(RDest) then
    Result := NullRegion
  else
  begin
    if cairo_region_num_rectangles(RDest) > 1 then
      Result := ComplexRegion
    else
      Result := SimpleRegion;
  end;
end;

function TGtk3WidgetSet.CreateBitmap(Width, Height: Integer; Planes,
  BitCount: Longint; BitmapBits: Pointer): HBITMAP;
var
  Format: cairo_format_t;
  NewBits: PByte;
  NewBitsSize: PtrUInt;
  ARowStride, RSS: Integer;
begin
  {$IFDEF VerboseGtk3WinAPI}
    DebugLn('Trace:> [Gtk3WinAPI CreateBitmap]',
     ' Width:', dbgs(Width),
     ' Height:', dbgs(Height),
     ' Planes:', dbgs(Planes),
     ' BitCount:', dbgs(BitCount),
     ' BitmapBits: ', dbgs(BitmapBits));
  {$ENDIF}
  case BitCount of
    1: Format := CAIRO_FORMAT_A1;
    8: Format := CAIRO_FORMAT_A8;
    24: Format := CAIRO_FORMAT_RGB24;
    else
      Format := CAIRO_FORMAT_ARGB32;
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
    Result := HBitmap(TGtk3Image.Create(NewBits, Width, Height, ARowStride, Format, True));
  end
  else
    Result := HBitmap(TGtk3Image.Create(nil, Width, Height, Format));

  {$IFDEF VerboseGtk3WinAPI}
  DebugLn('Trace:< [Gtk3WinAPI CreateBitmap] Bitmap:', dbghex(Result));
  {$ENDIF}
end;

function TGtk3WidgetSet.CreateBrushIndirect(const LogBrush: TLogBrush): HBRUSH;
var
  ABrush: TGtk3Brush;
begin
  Result := 0;
  // DebugLn('TGtk3WidgetSet.CreateBrushIndirect color=',dbgs(logBrush.lbColor),' style=',dbgs(logBrush.lbStyle));
  ABrush := TGtk3Brush.Create;
  try
    // todo: hatch
    ABrush.Style := LogBrush.lbStyle;
    ABrush.Color := ColorToRGB(TColor(logBrush.lbColor));
    ABrush.LogBrush := LogBrush;
    // ABrush.LogBrush.lbColor := ABrush.Color;
    Result := HBRUSH(ABrush);
  except
    Result := 0;
    DebugLn('TGtk3WidgetSet.CreateBrushIndirect: Failed');
  end;

  {$IFDEF VerboseGtk3DeviceContext}
  DebugLn('Trace:< [Gtk3WinAPI CreateBrushIndirect] Result: ', dbghex(Result));
  {$ENDIF}
end;

function TGtk3WidgetSet.CreateCaret(Handle: HWND; Bitmap: hBitmap; width,
  Height: Integer): Boolean;
begin
  {$IFDEF GTK3DEBUGNOTIMPLEMENTED}
  DebugLn('WARNING: TGtk3WidgetSet.CreateCaret not implemented ...');
  {$ENDIF}
  Result := inherited CreateCaret(Handle, Bitmap, width, Height);
end;

function TGtk3WidgetSet.CreateCompatibleBitmap(DC: HDC; Width, Height: Integer
  ): HBITMAP;
var
  Gtk3DC: TGtk3DeviceContext;
  Format: cairo_format_t = CAIRO_FORMAT_ARGB32;
  ADepth: Integer;
  AVisual: PGdkVisual;
  ABpp: gint;
  ARowStride: PtrUInt;
begin
  {$IFDEF VerboseGtk3WinAPI}
  DebugLn('Trace:> [WinAPI CreateCompatibleBitmap]',
     ' DC:', dbghex(DC),
     ' Width:', dbgs(Width),
     ' Height:', dbgs(Height));
  {$ENDIF}
  Result := 0;
  if IsValidDC(DC) then
  begin
    Gtk3DC := TGtk3DeviceContext(DC);
    ADepth := Gtk3DC.getDepth;
    ABpp := Gtk3DC.getBpp;
  end else
  begin
    AVisual := gdk_window_get_visual(gdk_get_default_root_window);
    ADepth := gdk_visual_get_depth(AVisual);
    ABpp := AVisual^.get_bits_per_rgb;
    g_object_unref(AVisual);
  end;
  case ADepth of
    1: Format := CAIRO_FORMAT_A1;
    2: Format := CAIRO_FORMAT_A8;
    24: Format := CAIRO_FORMAT_RGB24;
    else
      Format := CAIRO_FORMAT_ARGB32;
  end;
  ARowStride := GetBytesPerLine(Width, ABpp, rileDWordBoundary);
  Result := HBitmap(TGtk3Image.Create(nil, Width, Height, ARowStride, Format));
  {$IFDEF VerboseGtk3WinAPI}
  DebugLn('Trace:< [Gtk3WinAPI CreateCompatibleBitmap] Bitmap:', dbghex(Result));
  {$ENDIF}
end;

function TGtk3WidgetSet.CreateCompatibleDC(DC: HDC): HDC;
begin
  Result := HDC(TGtk3DeviceContext.Create(PGtkWidget(nil), False));
end;

function TGtk3WidgetSet.CreateEllipticRgn(X1, Y1, X2, Y2: Integer): HRGN;
begin
  Result:=HRGN(TGtk3Region.CreateEllipse(X1,Y1,X2,Y2));
end;

function TGtk3WidgetSet.CreateRoundRectRgn(X1, Y1, X2, Y2, nW, nH: Integer): HRGN;
begin
  Result:=HRGN(TGtk3Region.Create(X1,Y1,X2,Y2,nW,nH));
end;


function TGtk3WidgetSet.CreateFontIndirect(const LogFont: TLogFont): HFONT;
begin
  Result := CreateFontIndirectEx(LogFont, '');
end;

function TGtk3WidgetSet.CreateFontIndirectEx(const LogFont: TLogFont;
  const LongFontName: string): HFONT;
begin
  Result := HFONT(TGtk3Font.Create(LogFont, LongFontName));
end;

function TGtk3WidgetSet.CreateIconIndirect(IconInfo: PIconInfo): HICON;
begin
  Result := 0;
  if IsValidGDIObject(IconInfo^.hbmColor) then
  begin
    if IconInfo^.fIcon then
    begin
      Result := HICON(TGtk3Image.Create(TGtk3Image(IconInfo^.hbmColor).Handle));
    end else
    begin
      Result := HCURSOR({%H-}PtrUInt(gdk_cursor_new_from_pixbuf(gdk_display_get_default,
        TGtk3Image(IconInfo^.hbmColor).Handle, IconInfo^.xHotSpot, IconInfo^.yHotSpot)));
      // create cursor from pixbuf
     { W := gdk_pixbuf_get_width(TGtk3Image(IconInfo^.hbmColor).Handle);
      H := gdk_pixbuf_get_height(TGtk3Image(IconInfo^.hbmColor).Handle);
      DebugLn('TGtk3WidgetSet.CreateIconIndirect W=',dbgs(W),' H=',dbgs(H));
      PixBuf := gdk_pixbuf_new_subpixbuf(TGtk3Image(IconInfo^.hbmColor).Handle, 0, 0, W, H);
      Result := HCURSOR({%H-}PtrUInt(gdk_cursor_new_from_pixbuf(gdk_display_get_default,
        pixbuf, IconInfo^.xHotSpot, IconInfo^.yHotSpot)));
      if pixbuf <> nil then
        g_object_unref(PixBuf); }
    end;
  end;
end;

function TGtk3WidgetSet.CreatePalette(const LogPalette: TLogPalette): HPALETTE;
begin
  {$IFDEF GTK3DEBUGNOTIMPLEMENTED}
  DebugLn('WARNING: TGtk3WidgetSet.CreatePalette not implemented ...');
  {$ENDIF}
  Result := 0;
end;

function TGtk3WidgetSet.CreatePenIndirect(const LogPen: TLogPen): HPEN;
var
  APen: TGtk3Pen;
begin
  Result := 0;
  APen := TGtk3Pen.Create;
  with LogPen do
  begin
    case lopnStyle and PS_STYLE_MASK of
      PS_SOLID: APen.Style := psSolid;
      PS_DASH: APen.Style := psDash;
      PS_DOT: APen.Style := psDot;
      PS_DASHDOT: APen.Style := psDashDot;
      PS_DASHDOTDOT: APen.Style := psDashDotDot;
      PS_NULL: APen.Style := psClear;
    else
      APen.Style := psSolid;
    end;
    APen.Color := TColor(lopnColor);
    APen.Cosmetic := lopnWidth.X <= 0 ;
    if not APen.Cosmetic then
      APen.Width := lopnWidth.X;
  end;
  APen.LogPen := LogPen;

  Result := HPEN(APen);
end;

function TGtk3WidgetSet.CreatePolygonRgn(Points: PPoint; NumPts: Integer;
  FillMode: integer): HRGN;
begin
  {$IFDEF GTK3DEBUGNOTIMPLEMENTED}
  DebugLn('WARNING: TGtk3WidgetSet.CreatePolygonRgn not implemented ...');
  {$ENDIF}
  Result:=inherited CreatePolygonRgn(Points, NumPts, FillMode);
end;

function TGtk3WidgetSet.CreateRectRgn(X1, Y1, X2, Y2: Integer): HRGN;
begin
  Result := HRGN(TGtk3Region.Create(True, X1, Y1, X2, Y2));
end;

procedure TGtk3WidgetSet.DeleteCriticalSection(var CritSection: TCriticalSection
  );
var
  ACritSec: System.PRTLCriticalSection;
begin
  ACritSec:=System.PRTLCriticalSection(CritSection);
  System.DoneCriticalsection(ACritSec^);
  Dispose(ACritSec);
  CritSection:=0;
end;

function TGtk3WidgetSet.DeleteDC(hDC: HDC): Boolean;
begin
  {$ifdef VerboseGtk3DeviceContext}
  DebugLn('TGtk3WidgetSet.DeleteDC Handle: ', dbghex(hDC));
  {$endif}

  if not IsValidDC(hDC) then
    exit(False);

  TGtk3DeviceContext(hDC).Free;
  Result := True;
end;

function TGtk3WidgetSet.DeleteObject(GDIObject: HGDIOBJ): Boolean;
begin
  Result := False;

  if GDIObject = 0 then
    Exit(True);

  if not IsValidGDIObject(GDIObject) then
    Exit;
  {$ifdef VerboseGtk3DeviceContext}
  DebugLn('TGtk3WidgetSet.DeleteObject GDIObject: ', dbghex(GdiObject),' name ',dbgsName(TObject(GdiObject)));
  {$endif}
  if TObject(GDIObject) is TGtk3ContextObject then
  begin
    if TGtk3ContextObject(GDIOBJECT).Shared then
      // DebugLn('ERROR: TGtk3WidgetSet.DeleteObject trial to delete shared object ',dbgsName(TGtk3ContextObject(GdiObject)))
    else
      TGtk3ContextObject(GDIObject).Free;
  end else
    TObject(GDIObject).Free;
end;

function TGtk3WidgetSet.DestroyCaret(Handle: HWND): Boolean;
begin
  {$IFDEF GTK3DEBUGNOTIMPLEMENTED}
  DebugLn('WARNING: TGtk3WidgetSet.DestroyCaret not implemented ...');
  {$ENDIF}
  Result:=inherited DestroyCaret(Handle);
end;

function TGtk3WidgetSet.DestroyCursor(Handle: HCURSOR): Boolean;
begin
  Result := Handle <> 0;
  if Result then
    g_object_unref(PGdkCursor(Handle));
   // gdk_cursor_destroy({%H-}PGdkCursor(Handle));
end;

function TGtk3WidgetSet.DestroyIcon(Handle: HICON): Boolean;
begin
  Result := False;
  if IsValidGDIObject(Handle) then
  begin
    TGtk3Image(Handle).Free;
    Result := True;
  end;
end;

function TGtk3WidgetSet.DPtoLP(DC: HDC; var Points; Count: Integer): BOOL;
begin
  {$IFDEF GTK3DEBUGNOTIMPLEMENTED}
  DebugLn('WARNING: TGtk3WidgetSet.DPToLP not implemented ...');
  {$ENDIF}
  Result:=inherited DPtoLP(DC, Points, Count);
end;

function TGtk3WidgetSet.DrawFrameControl(DC: HDC; const aRect: TRect; uType,
  uState: Cardinal): Boolean;
begin
  Result:=false;
  if IsValidDC(DC) then
    Result:=TGtk3DeviceContext(DC).drawFrameControl(aRect,uType,uState);
end;

function TGtk3WidgetSet.DrawFocusRect(DC: HDC; const aRect: TRect): boolean;
begin
  Result := False;
  if IsValidDC(DC) then
    Result:=TGtk3DeviceContext(DC).drawFocusRect(aRect);
end;

function TGtk3WidgetSet.DrawEdge(DC: HDC; var ARect: TRect; Edge: Cardinal;
  grfFlags: Cardinal): Boolean;
begin
  {$IFDEF GTK3DEBUGNOTIMPLEMENTED}
  DebugLn('WARNING: TGtk3WidgetSet.DrawEdge not implemented ...');
  {$ENDIF}
  Result := False; // inherited DrawEdge(DC, ARect, Edge, grfFlags);
end;

function TGtk3WidgetSet.DrawText(DC: HDC; Str: PChar; Count: Integer;
  var Rect: TRect; Flags: Cardinal): Integer;
const
  TabString = '        ';
var
  pIndex: Longint;
  AStr: String;

  TM: TTextmetric;
  theRect: TRect;
  Lines: PPChar;
  I, NumLines: Longint;
  TempDC: HDC;
  TempPen: HPEN;
  TempBrush: HBRUSH;
  l: LongInt;
  Pt: TPoint;
  SavedRect: TRect; // if font orientation <> 0
  LineHeight: Integer;
  Size: TSize;

  function LeftOffset: Longint;
  begin
    if (Flags and DT_RIGHT) = DT_RIGHT then
      Result := DT_RIGHT
    else
      if (Flags and DT_CENTER) = DT_CENTER then
        Result := DT_CENTER
    else
      Result := DT_LEFT;
  end;

  function TopOffset: Longint;
  begin
    if (Flags and DT_BOTTOM) = DT_BOTTOM then
      Result := DT_BOTTOM
    else
      if (Flags and DT_VCENTER) = DT_VCENTER then
        Result := DT_VCENTER
    else
      Result := DT_TOP;
  end;

  function CalcRect: Boolean;
  begin
    Result := (Flags and DT_CALCRECT) = DT_CALCRECT;
  end;

  function TextExtentPoint(Str: PChar; Count: Integer; var Sz: TSize): Boolean;
  var
    NewStr: String;
  begin
    if (Flags and DT_EXPANDTABS) <> 0 then
    begin
      NewStr := StringReplace(Str, #9, TabString, [rfReplaceAll]);
      Result := GetTextExtentPoint(DC, PChar(NewStr), Length(NewStr), Sz);
    end
    else
      Result := GetTextExtentPoint(Dc, Str, Count, Sz);
  end;

  procedure DoCalcRect;
  var
    AP: TSize;
    J, MaxWidth,
    LineWidth, LineHeight: Integer;
  begin
    theRect := Rect;

    MaxWidth := theRect.Right - theRect.Left;
    //DefHeight := theRect.Bottom - theRect.Top;

    (*
    if Flags and DT_CENTER  <> 0then
      Alignment := DT_CENTER
    else
    if Flags and DT_RIGHT <> 0 then
      Alignment := DT_RIGHT
    else
      Alignment := DT_LEFT;

    TGtk3DeviceContext(DC).CurrentFont.Layout^.set_alignment(Alignment);
    if Flags and DT_WORDBREAK <> 0  then
      TGtk3DeviceContext(DC).CurrentFont.Layout^.set_wrap(PANGO_WRAP_WORD);

    // ADevOffset := TGtk3DeviceContext(DC).Offset;
    // TGtk3DeviceContext(DC).CurrentFont.Layout^.set_width(Rect.Right - Rect.Left);
    // TGtk3DeviceContext(DC).CurrentFont.Layout^.set_height(Rect.Bottom - Rect.Top);

    TGtk3DeviceContext(DC).CurrentFont.Layout^.set_text(Str, Count);


    // TGtk3DeviceContext(DC).CurrentFont.Layout^.get_iter^.get_line_extents(@PR1, @PR2);
    // DebugLn('DoCalcRect LINE EXTENTS Rect=',dbgs(Rect),' PR1 ',dbgs(RectFromGdkRect(TGdkRectangle(PR1))),' PR2 ',dbgs(RectFromGdkRect(TGdkRectangle(PR2))));
    TGtk3DeviceContext(DC).CurrentFont.Layout^.get_extents(@PR1, @PR2);
    // get_extents(@PR1, @PR2);

    DebugLn('DoCalcRect Rect=',dbgs(Rect),' PR1 ',dbgs(RectFromPangoRect(PR1)),' PR2 ',dbgs(RectFromPangoRect(PR2)),' ALIGNMENT ',dbgs(Alignment));

    // DebugLn('DoCalcRect Rect=',dbgs(Rect),' PR1 ',Format('x %d y %d width %d height %d'
    *)

    if (Flags and DT_SINGLELINE) > 0 then
    begin
      // ignore word and line breaks
      TextExtentPoint(PChar(AStr), length(AStr), AP{%H-});
      theRect.Bottom := theRect.Top + TM.tmHeight;
      if (Flags and DT_CALCRECT)<>0 then
      begin
        theRect.Right := theRect.Left +  AP.cX;
        theRect.Bottom := theRect.Top + AP.cY;
      end
      else
      begin
        theRect.Right := theRect.Left + Min(MaxWidth, AP.cX);
        if (Flags and DT_VCENTER) > 0 then
        begin
          OffsetRect(theRect, 0, ((Rect.Bottom - Rect.Top) - (theRect.Bottom - theRect.Top)) div 2);
        end
        else
        if (Flags and DT_BOTTOM) > 0 then
        begin
          OffsetRect(theRect, 0, (Rect.Bottom - Rect.Top) - (theRect.Bottom - theRect.Top));
        end;
      end;
    end
    else
    begin
      // consider line breaks
      if (Flags and DT_WORDBREAK) = 0 then
      begin
        // do not break at word boundaries
        TextExtentPoint(PChar(AStr), length(AStr), AP);
        MaxWidth := AP.cX;
        //DefHeight := AP.cY;
      end;

      Gtk3WordWrap(DC, PChar(AStr), MaxWidth, Lines, NumLines);
      // writeln('WORD WRAP RESULTED IN ',NumLines,' lines for ',AStr,' MAX=',MaxWidth);
      if (Flags and DT_CALCRECT)<>0 then
      begin
        LineWidth := 0;
        LineHeight := 0;
        if (Lines <> nil) then
        begin
          for J := 0 to NumLines - 1 do
          begin
            TextExtentPoint(Lines[J], StrLen(Lines[J]), AP);
            LineWidth := Max(LineWidth, AP.cX);
            Inc(LineHeight, AP.cY);
          end;
        end;
        LineWidth := Min(MaxWidth, LineWidth);
      end else
      begin
        LineWidth := MaxWidth;
        LineHeight := NumLines*TM.tmHeight;
      end;

      theRect.Right := theRect.Left + LineWidth;
      theRect.Bottom := theRect.Top + LineHeight;
      if NumLines>1 then
        Inc(theRect.Bottom, (NumLines-1)*TM.tmDescent);// space between lines

      // debugln('TGtk3WidgetSet.DrawText A ',dbgs(theRect),' TM.tmHeight=',dbgs(TM.tmHeight),' LineWidth=',dbgs(LineWidth),' NumLines=',dbgs(NumLines));
    end;

    if not CalcRect then
      case LeftOffset of
        DT_CENTER:
          OffsetRect(theRect, (Rect.Right - theRect.Right) div 2, 0);
        DT_RIGHT:
          OffsetRect(theRect, Rect.Right - theRect.Right, 0);
      end;
  end;

  // if our Font.Orientation <> 0 we must recalculate X,Y offset
  // also it works only with DT_TOP DT_LEFT. Gtk2 can handle multiline
  // text in this case too.
  procedure CalculateOffsetWithAngle(const AFontAngle: Integer;
    var TextLeft,TextTop: Integer);
  var
    OffsX, OffsY: integer;
    Angle: Double;
    Size: TSize;
    R: TRect;
  begin
    R := SavedRect;
    OffsX := R.Right - R.Left;
    OffsY := R.Bottom - R.Top;
    Size.cx := OffsX;
    Size.cy := OffsY;
    Angle := AFontAngle / 10;
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

  function NeedOffsetCalc: Boolean;
  begin

    Result := (TGtk3DeviceContext(DC).CurrentFont.LogFont.lfOrientation <> 0) and
        (Flags and DT_SINGLELINE <> 0) and
        (Flags and DT_VCENTER = 0) and (Flags and DT_CENTER = 0) and
        (Flags and DT_RIGHT = 0) and (Flags and  DT_BOTTOM = 0) and
        (Flags and DT_CALCRECT = 0) and not IsRectEmpty(SavedRect);
  end;


  procedure DrawLineRaw(theLine: PChar; LineLength, TopPos: Longint);
  var
    Points: array[0..1] of TSize;
    LeftPos: Longint;
  begin
    if LeftOffset <> DT_LEFT then
      GetTextExtentPoint(DC, theLine, LineLength, {%H-}Points[0]);

    if TempBrush = HBRUSH(-1) then
      TempBrush := SelectObject(DC, GetStockObject(NULL_BRUSH));
    case LeftOffset of
      DT_LEFT:
        LeftPos := theRect.Left;
      DT_CENTER:
        LeftPos := theRect.Left + (theRect.Right - theRect.Left) div 2
                 - Points[0].cX div 2;
      DT_RIGHT:
        LeftPos := theRect.Right - Points[0].cX;
    end;

    Pt := Point(0, 0);
    // Draw line of Text
    if NeedOffsetCalc then
    begin
      Pt.X := SavedRect.Left;
      Pt.Y := SavedRect.Top;
      CalculateOffsetWithAngle(TGtk3DeviceContext(DC).CurrentFont.LogFont.lfOrientation, Pt.X, Pt.Y);
    end;
    TextUtf8Out(DC, LeftPos + Pt.X, TopPos + Pt.Y, theLine, lineLength);
  end;

  procedure DrawLine(theLine: PChar; LineLength, TopPos: Longint);
  var
    Points: array[0..1] of TSize;
    LogP: TLogPen;
    LeftPos: Longint;
  begin
    if TempBrush = HBRUSH(-1) then
      TempBrush := SelectObject(DC, GetStockObject(NULL_BRUSH));

    FillByte({%H-}Points[0],SizeOf(Points[0])*2,0);
    if LeftOffset <> DT_Left then
      GetTextExtentPoint(DC, theLine, LineLength, Points[0]);

    case LeftOffset of
      DT_LEFT:
        LeftPos := theRect.Left;
      DT_CENTER:
        LeftPos := theRect.Left + (theRect.Right - theRect.Left) div 2
                 - Points[0].cX div 2;
      DT_RIGHT:
        LeftPos := theRect.Right - Points[0].cX;
    end;

    Pt := Point(0, 0);
    if NeedOffsetCalc then
    begin
      Pt.X := SavedRect.Left;
      Pt.Y := SavedRect.Top;
      CalculateOffsetWithAngle(TGtk3DeviceContext(DC).CurrentFont.LogFont.lfOrientation, Pt.X, Pt.Y);
    end;
    // Draw line of Text
    TextUtf8Out(DC, LeftPos + Pt.X, TopPos + Pt.Y, theLine, LineLength);

    // Draw Prefix
    if (pIndex > 0) and (pIndex<=LineLength) then
    begin
      // Create & select pen of font color
      if TempPen = HPEN(-1) then
      begin
        LogP.lopnStyle := PS_SOLID;
        LogP.lopnWidth.X := 1;
        LogP.lopnColor := GetTextColor(DC);
        TempPen := SelectObject(DC, CreatePenIndirect(LogP));
      end;

      {Get prefix line position}
      GetTextExtentPoint(DC, theLine, pIndex - 1, Points[0]);
      Points[0].cX := LeftPos + Points[0].cX;
      Points[0].cY := TopPos + tm.tmHeight - TM.tmDescent + 1;

      GetTextExtentPoint(DC, @aStr[pIndex], UTF8CodepointSize(@aStr[pIndex]), Points[1]);
      Points[1].cX := Points[0].cX + Points[1].cX;
      Points[1].cY := Points[0].cY;

      {Draw prefix line}
      Polyline(DC, PPoint(@Points[0]), 2);
    end;
  end;
begin
  Result := 0;
  if (Str=nil) or (Str[0]=#0) or not IsValidDC(DC) then
  begin
    // DebugLn('TGtk3DeviceContext.DrawText params error Str Valid ? ',dbgs(Str<>nil),' DC Valid ? ',dbgs(IsValidDC(DC)),' Str#0 ',dbgs(Str[0] = #0));
    exit;
  end;

  if (Count < -1) or (IsRectEmpty(Rect) and
    ((Flags and DT_CALCRECT = 0) and (Flags and DT_NOCLIP = 0))) then Exit;

  // Don't try to use StrLen(Str) in cases count >= 0
  // In those cases str is NOT required to have a null terminator !
  if Count = -1 then
    Count := StrLen(Str);

  Lines := nil;
  NumLines := 0;
  TempDC := HDC(-1);
  TempPen := HPEN(-1);
  TempBrush := HBRUSH(-1);
  // DebugLn('TGtk3DeviceContext.DrawText ',Str,' count=',dbgs(Count),' DT_CALCRECT ',dbgs(Flags and DT_CALCRECT <> 0),' ARect=',dbgs(Rect));
  try
    if (Flags and (DT_SINGLELINE or DT_CALCRECT or DT_NOPREFIX or DT_NOCLIP or DT_EXPANDTABS)) =
       (DT_SINGLELINE or DT_NOPREFIX or DT_NOCLIP) then
    begin
      System.Move(Rect, TheRect, SizeOf(TRect));
      SavedRect := Rect;
      DrawLineRaw(Str, Count, Rect.Top);
      Result := Rect.Bottom - Rect.Top;
      Exit;
    end;

    SetLength(AStr{%H-},Count);
    if Count>0 then
      System.Move(Str^,AStr[1],Count);

    if (Flags and DT_EXPANDTABS) <> 0 then
      AStr := StringReplace(AStr, #9, TabString, [rfReplaceAll]);

    if (Flags and DT_NOPREFIX) <> DT_NOPREFIX then
      pIndex := DeleteAmpersands(AStr)
    else
      pIndex := -1;

    GetTextMetrics(DC, TM{%H-});
    DoCalcRect;
    Result := theRect.Bottom - theRect.Top;
    if (Flags and DT_CALCRECT) = DT_CALCRECT then
    begin
      // DebugLn('TGtk3WidgetSet.DrawText DT_CALCRECT Rect ',dbgs(Rect),' TheRect ',dbgs(theRect),' Result ',dbgs(Result));
      System.Move(TheRect, Rect, SizeOf(TRect));
      exit;
    end;

    TempDC := SaveDC(DC);

    if (Flags and DT_NOCLIP) <> DT_NOCLIP then
    begin
      if theRect.Right > Rect.Right then
        theRect.Right := Rect.Right;
      if theRect.Bottom > Rect.Bottom then
        theRect.Bottom := Rect.Bottom;
      // DebugLn('******* CALLING NOT IMPLEMENTED INTERSECTCLIP RECT ');
      IntersectClipRect(DC, theRect.Left, theRect.Top,
        theRect.Right, theRect.Bottom);
    end;

    if (Flags and DT_SINGLELINE) = DT_SINGLELINE
    then begin
      // DebugLn(['TGtk2WidgetSet.DrawText Draw single line']);
      SavedRect := TheRect;
      DrawLine(PChar(AStr), length(AStr), theRect.Top);
      Exit; //we're ready
    end;

    // multiple lines
    if Lines = nil then Exit;  // nothing to do
    if NumLines = 0 then Exit; //


    //DebugLn(['TGtk2WidgetSet.DrawText Draw multiline']);
    SavedRect := Classes.Rect(0, 0, 0, 0); // no font orientation change if multilined text
    for i := 0 to NumLines - 1 do
    begin
      if theRect.Top > theRect.Bottom then Break;

      if  ((Flags and DT_EDITCONTROL) = DT_EDITCONTROL)
      and (tm.tmHeight > (theRect.Bottom - theRect.Top))
      then Break;

      if Lines[i] <> nil then
      begin
        l:=StrLen(Lines[i]);
        DrawLine(Lines[i], l, theRect.Top);
        dec(pIndex,l+length(LineEnding));
        Size:=default(TSize);
        GetTextExtentPoint(DC, Lines[i], l, Size);
        LineHeight := Size.cY;
      end
      else
        LineHeight := TM.tmHeight;
      Inc(theRect.Top, LineHeight + TM.tmDescent); // space between lines
    end;

  finally
    Reallocmem(Lines, 0);
    if TempBrush <> HBRUSH(-1) then
      SelectObject(DC, TempBrush);// DeleteObject not needed here, because it was a default Brush
    if TempPen <> HPEN(-1) then
      DeleteObject(SelectObject(DC, TempPen));
    if TempDC <> HDC(-1) then
      RestoreDC(DC, TempDC);
  end;
end;

function TGtk3WidgetSet.Ellipse(DC: HDC; x1, y1, x2, y2: Integer): Boolean;
var
  bFill, bBorder: Boolean;
begin
  bFill := TGtk3DeviceContext(DC).CurrentBrush.Style <> BS_NULL;
  bBorder := TGtk3DeviceContext(DC).CurrentPen.Style <> psClear;
  TGtk3DeviceContext(DC).drawEllipse(x1, y1, x2 - x1 - 1, y2 - y1 - 1, bFill, bBorder);
  Result := True;
end;

function TGtk3WidgetSet.EnableScrollBar(Wnd: HWND; wSBflags, wArrows: Cardinal
  ): Boolean;
begin
  {$IFDEF GTK3DEBUGNOTIMPLEMENTED}
  DebugLn('WARNING: TGtk3WidgetSet.EnableScrollBar not implemented ...');
  {$ENDIF}
  Result := inherited EnableScrollBar(Wnd, wSBflags, wArrows);
end;

function TGtk3WidgetSet.EnableWindow(hWnd: HWND; bEnable: Boolean): Boolean;
begin
  Result := False;
  if hWnd <> 0 then
  begin
    Result := TGtk3Widget(HWND).Enabled;
    TGtk3Widget(HWND).Enabled := bEnable;
  end;
end;

function TGtk3WidgetSet.EndPaint(Handle: hwnd; var PS: TPaintStruct): Integer;
begin
  Result := 0;
  if IsValidDC(PS.HDC) then
  begin
    TGtk3DeviceContext(PS.HDC).Free;
    PS.HDC := 0;
    Result := 1;
  end;
end;

procedure TGtk3WidgetSet.EnterCriticalSection(var CritSection: TCriticalSection
  );
var
  ACritSec: System.PRTLCriticalSection;
begin
  ACritSec:=System.PRTLCriticalSection(CritSection);
  System.EnterCriticalsection(ACritSec^);
end;

function TGtk3WidgetSet.EnumDisplayMonitors(hdc: HDC; lprcClip: PRect;
  lpfnEnum: MonitorEnumProc; dwData: LPARAM): LongBool;
var
  i: integer;
begin
  Result := True;
  for i := 0 to gdk_screen_get_n_monitors(gdk_screen_get_default) - 1 do
  begin
    Result := Result and lpfnEnum(i + 1, 0, nil, dwData);
    if not Result then break;
  end;
end;

function TGtk3WidgetSet.EnumFontFamiliesEx(DC: HDC; lpLogFont: PLogFont;
  Callback: FontEnumExProc; Lparam: LParam; Flags: dword): longint;
type
  TPangoFontFaces = packed record
    FamilyName: String;
    Faces: Array of String;
  end;
  PPangoFontFaces = Array of TPangoFontFaces;

var
  i: Integer;
  FontType: Integer;
  EnumLogFont: TEnumLogFontEx;
  Metric: TNewTextMetricEx;
  FontList: TStringList;
  Faces: PPangoFontFaces;

  AStyle: String;
  StylesCount: Integer;
  StylesList: TStringList;
  y: Integer;
  CharsetList: TByteList;
  CS: Byte;

  function Gtk3GetFontFamiliesDefault(var AList: TStringList): Integer;
  var
    i, j: Integer;
    AFamilies: PPPangoFontFamily;
    AFaces: PPPangoFontFace;
    ANumFaces: Integer;
  begin
    AList.Clear;
    SetLength(Faces, 0);
    Result := -1;
    AFamilies := nil;

    pango_context_list_families(gdk_pango_context_get, @AFamilies, @Result);
    SetLength(Faces, Result);
    for i := 0 to Result - 1 do
    begin
      j := AList.Add(StrPas(pango_font_family_get_name(AFamilies[i])));
      AList.Objects[j] := TObject(PtrUInt(pango_font_family_is_monospace(AFamilies[i])));
      Faces[i].FamilyName := AList[j];
      AFaces := nil;
      pango_font_family_list_faces(AFamilies[i], @AFaces, @ANumFaces);
      SetLength(Faces[i].Faces, ANumFaces);
      for j := 0 to ANumFaces - 1 do
        Faces[i].Faces[j] := StrPas(pango_font_face_get_face_name(AFaces[j]));
      g_free(AFaces);
    end;
    g_free(AFamilies);
  end;

  function Gtk3GetFontFamilies(var List: TStringList;
    const APitch: Byte;
    const AFamilyName: String;
    const {%H-}AWritingSystem: Byte): Integer;
  var
    StrLst: TStringList;
    NewList: TStringList;
    S: String;
    j: integer;
  begin
    Result := -1;
    StrLst := TStringList.Create;
    NewList := TStringList.Create;

    try
      Gtk3GetFontFamiliesDefault(StrLst);
      for j := 0 to StrLst.Count - 1 do
      begin
        S := StrLst[j];
        if APitch <> DEFAULT_PITCH then
        begin
          case APitch of
            FIXED_PITCH, MONO_FONT:
            begin
              if StrLst.Objects[j] <> nil then
                NewList.Add(S);
            end;
            VARIABLE_PITCH:
            begin
              if StrLst.Objects[j] = nil then
                NewList.Add(S);
            end;
          end;
        end else
          NewList.Add(S);
      end;

      if AFamilyName <> '' then
      begin
        for j := NewList.Count - 1 downto 0 do
        begin
          S := NewList[j];;
          if S <> AFamilyName then
            NewList.Delete(J);
        end;
      end;
      for j := 0 to NewList.Count - 1 do
      begin
        S := NewList[j];
        List.Add(S);
      end;
      Result := List.Count;
    finally
      StrLst.Free;
      NewList.Free;
    end;
  end;

  function GetStyleAt(AIndex: Integer): String;
  var
    S: String;
  begin
    Result := '';
    if (AIndex >= 0) and (AIndex < StylesList.Count) then
    begin
      S := StylesList[AIndex];
      Result := S;
    end;
  end;

  function FillLogFontA(const AIndex: Integer; var ALogFontA: TLogFontA;
    var {%H-}AMetric: TNewTextMetricEx; var {%H-}AFontType: Integer;
    out AStyle: String): Integer;
  var
    Font: PPangoFontDescription;
    FontStyle: TPangoStyle;
    FontWeight: TPangoWeight;
    S: String;
    i: Integer;
  begin
    S := FontList[AIndex];
    Font := pango_font_description_from_string(PChar(S));

    FontStyle := pango_font_description_get_style(Font);
    FontWeight := pango_font_description_get_weight(Font);

    ALogFontA.lfItalic := Byte(FontStyle = PANGO_STYLE_ITALIC);

    // keep newer pango compat to LCL
    if FontWeight = 380 {PANGO_WEIGHT_BOOK as of pango 1.24} then
      FontWeight := PANGO_WEIGHT_NORMAL
    else
    if FontWeight = 1000 {PANGO_WEIGHT_ULTRAHEAVY as of pango 1.24} then
      FontWeight := PANGO_WEIGHT_HEAVY;

    ALogFontA.lfWeight := FontWeight;

    ALogFontA.lfHeight := pango_font_description_get_size(Font);
    if not pango_font_description_get_size_is_absolute(Font) then
      ALogFontA.lfHeight := PANGO_PIXELS(ALogFontA.lfHeight);

    // pango does not have underline and strikeout params for font
    // ALogFontA.lfUnderline := ;
    // ALogFontA.lfStrikeOut := ;

    StylesList.Clear;
    for i := High(Faces[AIndex].Faces) downto 0 do
      StylesList.Add(Faces[AIndex].Faces[i]);

    AStyle := '';
    Result := StylesList.Count;

    if StylesList.Count > 0  then
      AStyle := GetStyleAt(0);

    // current pango support in fpc is really poor, we cannot
    // get PangoScript since it's in pango >= 1.4
    // FillCharsetListForFont()
  end;

begin
  Result := 0;
  {$ifdef VerboseEnumFonts}
  WriteLn('[TGtk3WidgetSet.EnumFontFamiliesEx] Charset=',lpLogFont^.lfCharSet,
  ' face ',lpLogFont^.lfFaceName,' pitchAndFamily=',lpLogFont^.lfPitchAndFamily);
  {$endif}
  Result := 0;
  Metric.ntmentm.ntmAvgWidth := 0; // just to shutup compiler
  if (lpLogFont^.lfCharSet = DEFAULT_CHARSET) and
     (lpLogFont^.lfFaceName= '') and
     (lpLogFont^.lfPitchAndFamily = 0) then
  begin
    FontType := 0;
    FontList := TStringList.create;
    try
      if Gtk3GetFontFamiliesDefault(FontList) > 0 then
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
    FontList := TStringList.Create;
    StylesList := TStringList.Create;
    CharsetList := TByteList.Create;
    for i := 0 to CharsetEncodingList.Count - 1 do
    begin
      CS := TCharSetEncodingRec(CharsetEncodingList.Items[i]^).CharSet;
      if CharsetList.IndexOf(CS) = -1 then
        CharsetList.Add(CS);
    end;
    try
      if Gtk3GetFontFamilies(FontList, lpLogFont^.lfPitchAndFamily,
        lpLogFont^.lfFaceName, lpLogFont^.lfCharSet) > 0 then
      begin
        for i := 0 to FontList.Count - 1 do
        begin
          EnumLogFont.elfLogFont.lfFaceName := FontList[i];
          EnumLogFont.elfLogFont.lfPitchAndFamily := lpLogFont^.lfPitchAndFamily;
          EnumLogFont.elfFullName := FontList[i];

          StylesCount := FillLogFontA(i, EnumLogFont.elfLogFont, Metric, FontType, AStyle);
          EnumLogFont.elfStyle := AStyle;

          if CharSetList.Count > 0 then
            EnumLogFont.elfLogFont.lfCharSet := CharsetList.Items[0];

          Result := Callback(EnumLogFont, Metric, FontType, LParam);
          for y := 1 to StylesCount - 1 do
          begin
            AStyle := GetStyleAt(y);
            EnumLogFont.elfStyle := AStyle;
            Result := Callback(EnumLogFont, Metric, FontType, LParam);
          end;
          for y := 1 to CharSetList.Count - 1 do
          begin
            EnumLogFont.elfLogFont.lfCharSet := CharsetList.Items[y];
            Result := Callback(EnumLogFont, Metric, FontType, LParam);
          end;
        end;
      end;
    finally
      CharSetList.Free;
      StylesList.Free;
      FontList.Free;
    end;
  end;
end;

function TGtk3WidgetSet.EqualRgn(Rgn1: HRGN; Rgn2: HRGN): Boolean;
begin
  Result := Rgn1 = Rgn2;
  if Result then
    exit;
  if not IsValidGDIObject(Rgn1) or not IsValidGDIObject(Rgn2) then
    exit;
  Result := cairo_region_equal(TGtk3Region(Rgn1).Handle,TGtk3Region(Rgn2).Handle);
end;

function TGtk3WidgetSet.IntersectClipRect(dc: hdc; Left, Top, Right,Bottom: Integer): Integer;
var
  rgn,clip:HRGN;
begin
  {$IFDEF GTK3DEBUGNOTIMPLEMENTED}
  DebugLn('WARNING: TGtk3WidgetSet.ExcludeClipRect not implemented ...');
  {$ENDIF}
  rgn:=Self.CreateRectRgn(Left,Top,Right,Bottom);
  //Self.SelectClipRGN(dc,rgn);
  clip:=Self.CreateEmptyRegion;
  Self.GetClipRGN(dc,clip);
  Self.CombineRgn(clip,rgn,clip,RGN_AND);
  Self.SelectClipRGN(dc,clip);
  DeleteObject(clip);
  DeleteObject(rgn);
  // fail Self.ExtSelectClipRGN(dc,rgn,RGN_AND);
 { ncorg:=Tgtk3DeviceContext(dc).fncOrigin;
  GetWindowOrgEx(DC, @DCOrigin);
  Result:=inherited IntersectClipRect(dc, Left, Top, Right, Bottom);}
  Result:=0;
end;


function TGtk3WidgetSet.ExcludeClipRect(dc: hdc; Left, Top, Right,
  Bottom: Integer): Integer;
begin
  {$IFDEF GTK3DEBUGNOTIMPLEMENTED}
  DebugLn('WARNING: TGtk3WidgetSet.ExcludeClipRect not implemented ...');
  {$ENDIF}
  Result:=inherited ExcludeClipRect(dc, Left, Top, Right, Bottom);
end;

function TGtk3WidgetSet.ExtCreatePen(dwPenStyle, dwWidth: DWord;
  const lplb: TLogBrush; dwStyleCount: DWord; lpStyle: PDWord): HPEN;
var
  APen: TGtk3Pen;
begin
  {$IFDEF GTK3DEBUGNOTIMPLEMENTED}
  // DebugLn('WARNING: TGtk3WidgetSet.ExtCreatePen not implemented ...');
  {$ENDIF}
  APen := TGtk3Pen.Create;
  APen.IsExtPen := True;
  case dwPenStyle and PS_STYLE_MASK of
    PS_SOLID: APen.Style := psSolid;
    PS_DASH: APen.Style := psDash;
    PS_DOT: APen.Style := psDot;
    PS_DASHDOT: APen.Style := psDashDot;
    PS_DASHDOTDOT: APen.Style := psDashDotDot;
    PS_NULL: APen.Style := psClear;
  else
    APen.Style := psSolid;
  end;

  APen.Cosmetic := (dwPenStyle and PS_TYPE_MASK) = PS_COSMETIC;

  if (dwPenStyle and PS_TYPE_MASK) = PS_GEOMETRIC then
  begin
    APen.Width := dwWidth;
    case dwPenStyle and PS_JOIN_MASK of
      PS_JOIN_ROUND: APen.JoinStyle := pjsRound;
      PS_JOIN_BEVEL: APen.JoinStyle := pjsBevel;
      PS_JOIN_MITER: APen.JoinStyle := pjsMiter;
    end;
    case dwPenStyle and PS_ENDCAP_MASK of
      PS_ENDCAP_ROUND: APen.EndCap := pecRound;
      PS_ENDCAP_SQUARE: APen.EndCap := pecSquare;
      PS_ENDCAP_FLAT: APen.EndCap := pecFlat;
    end;
  end;

  if (dwPenStyle and PS_STYLE_MASK) = PS_USERSTYLE then
  begin
    //TODO: APen.setDashPattern
  end;

  APen.Color := TColor(lplb.lbColor);  // ColorToRGB() ?
  APen.LogPen.lopnColor := lplb.lbColor;
  APen.LogPen.lopnStyle := (dwPenStyle and PS_STYLE_MASK) or (dwPenStyle and PS_JOIN_MASK) or (dwPenStyle and PS_ENDCAP_MASK);
  APen.LogPen.lopnWidth.X := dwWidth;
  APen.LogPen.lopnWidth.Y := dwWidth;

  Result := HPen(APen);
end;

function TGtk3WidgetSet.ExtSelectClipRGN(dc: hdc; rgn: hrgn; Mode: Longint): Integer;
var
  GtkDC: TGtk3DeviceContext absolute DC;
  ARect: TGdkRectangle;
  DCOrigin: TPoint;
  R: Classes.TRect;
  Clip: HRGN;
  Tmp: HRGN;
begin
  {$IFDEF GTK3DEBUGNOTIMPLEMENTED}
  // DebugLn('WARNING: TGtk3WidgetSet.ExtSelectClipRGN not implemented ...');
  {$ENDIF}
  if not IsValidDC(DC) then
  begin
    Result := ERROR;
    exit;
  end else
    Result := SIMPLEREGION;
  // DebugLn('WARNING: TGtk3WidgetSet.ExtSelectClipRGN not implemented ...Mode=',dbgs(Mode));
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
          gdk_cairo_get_clip_rectangle(GtkDC.pcr, @ARect);
          R := RectFromGdkRect(ARect);
          if IsRectEmpty(R) then
          begin
            // no clip, just select RGN
            Result := SelectClipRGN(DC, RGN);
            exit;
          end;

          // get transformation
          GetWindowOrgEx(DC, @DCOrigin);
          // writeln('ExtSelectClipRgn DCOrigin=',dbgs(DCOrigin),' R=',dbgs(R));
          // OffsetRect(R, -DCOrigin.X, -DCOrigin.Y);
          // writeln('ExtSelectClipRgn after DCOrigin=',dbgs(DCOrigin),' R=',dbgs(R));
          Clip := CreateRectRGN(0, 0, R.Right - R.Left, R.Bottom - R.Top);

          cairo_region_translate(TGtk3Region(Clip).Handle, -DCOrigin.X, -DCOrigin.Y);

          // create target clip
          Tmp := CreateEmptyRegion;
          // CreateEmptyRegion;
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
        //DebugLn('WARNING: TGtk3DeviceContext.ExtSelectClipRgn RGN_DIFF not implemented .');
        //exit;
        // when substracting we must have active clipregion
        // with all of its rects.
        gdk_cairo_get_clip_rectangle(GtkDC.pcr, @ARect);
        R := RectFromGdkRect(ARect);
        if IsRectEmpty(R) then
        begin
          // no clip, just select RGN
          Result := SelectClipRGN(DC, RGN);
          exit;
        end;

        Clip := CreateRectRGN(R.Left, R.Top, R.Right, R.Bottom);

        Tmp := CreateEmptyRegion;
        Result := CombineRGN(Tmp, HRGN(Clip), RGN, MODE);

        // X11 paintEngine comment only !
        // we'll NOT reset num of rects here (performance problem) like we do
        // in ExcludeClipRect, because this function must be correct,
        // if someone want accurate ExcludeClipRect with X11 then
        // use code from intfbasewinapi.inc TWidgetSet.ExcludeClipRect()
        // which calls this function and then combineRgn.
        SelectClipRGN(DC, Tmp);
        DeleteObject(Clip);
        DeleteObject(Tmp);
      end;
  end;
end;

function TGtk3WidgetSet.ExtTextOut(DC: HDC; X, Y: Integer; Options: Longint;
  Rect: PRect; Str: PChar; Count: Longint; Dx: PInteger): Boolean;
begin
  Result := False;
  // {$IFDEF VerboseGtk3DeviceContext}
  {$IFDEF GTK3DEBUGNOTIMPLEMENTED}
  DebugLn('TGtk3WidgetSet.ExtTextOut x=',dbgs(x),' y=',dbgs(y),' Text ',dbgs(Str),' count ',dbgs(Count));
  {$ENDIF}
  // inherited ExtTextOut(DC, X, Y, Options, Rect, Str, Count, Dx);
  if IsValidDC(DC) then
  begin
    Result := True;
    TGtk3DeviceContext(DC).drawText(X, Y, Str, Count);
  end;
end;

function TGtk3WidgetSet.FillRect(DC: HDC; const Rect: TRect; Brush: HBRUSH
  ): Boolean;
begin
  Result := False;
  if IsValidDC(DC) then
  begin
    with Rect do
      TGtk3DeviceContext(DC).fillRect(Left, Top, Right - Left, Bottom - Top, Brush);
    Result := True;
  end;
end;

function TGtk3WidgetSet.FillRgn(DC: HDC; RegionHnd: HRGN; hbr: HBRUSH): Bool;
var
  R: TRect;
begin
  Result := False;
  if IsValidDC(DC) and IsValidGDIObject(RegionHnd) then
  begin
    R := TGtk3Region(RegionHnd).GetExtents;
    TGtk3DeviceContext(DC).fillRect(R.Left, R.Top, R.Right - R.Left, R.Bottom - R.Top);
    Result := True;
  end;
end;

function TGtk3WidgetSet.Frame3d(DC: HDC; var ARect: TRect;
  const FrameWidth: integer; const Style: TBevelCut): Boolean;
const
  PixelOffset = 0.5;
  NColorLight = clWindow;
  NColorDark = clBtnShadow;
var
  Color1, Color2: TGdkRGBA;
  cr: Pcairo_t;
  i: Integer;
begin
  Result := False;
  if not IsValidDC(DC) then
    Exit;
  Result := True;
  if FrameWidth <= 0 then
    Exit;

  case Style of
    bvNone:
      Exit;
    bvSpace:
      begin
        InflateRect(ARect, -FrameWidth, -FrameWidth);
        Exit;
      end;
    bvRaised:
      begin
        Color1 := TColorToTGdkRGBA(ColorToRGB(NColorLight));
        Color2 := TColorToTGdkRGBA(ColorToRGB(NColorDark));
      end;
    bvLowered:
      begin
        Color1 := TColorToTGdkRGBA(ColorToRGB(NColorDark));
        Color2 := TColorToTGdkRGBA(ColorToRGB(NColorLight));
      end;
  end;

  cr := TGtk3DeviceContext(DC).pcr;
  cairo_save(cr);
  try
    cairo_set_line_width(cr, 1);
    cairo_set_line_cap(cr, cairo_line_cap_t.CAIRO_LINE_CAP_ROUND);
    cairo_set_line_join(cr, cairo_line_join_t.CAIRO_LINE_JOIN_ROUND);

    for i := 1 to FrameWidth do
    begin
      cairo_set_source_rgb(cr, Color1.red, Color1.green, Color1.blue);
      cairo_move_to(cr, ARect.Left+PixelOffset, ARect.Top+PixelOffset);
      cairo_line_to(cr, ARect.Right+PixelOffset-1, ARect.Top+PixelOffset);
      cairo_move_to(cr, ARect.Left+PixelOffset, ARect.Top+PixelOffset);
      cairo_line_to(cr, ARect.Left+PixelOffset, ARect.Bottom+PixelOffset-1);
      cairo_stroke(cr);

      cairo_set_source_rgb(cr, Color2.red, Color2.green, Color2.blue);
      cairo_move_to(cr, ARect.Left+PixelOffset, ARect.Bottom+PixelOffset-1);
      cairo_line_to(cr, ARect.Right+PixelOffset-1, ARect.Bottom+PixelOffset-1);
      cairo_move_to(cr, ARect.Right+PixelOffset-1, ARect.Top+PixelOffset);
      cairo_line_to(cr, ARect.Right+PixelOffset-1, ARect.Bottom+PixelOffset-1);
      cairo_stroke(cr);

      InflateRect(ARect, -1, -1);
    end;
  finally
    cairo_restore(cr);
  end;
end;

function TGtk3WidgetSet.FrameRect(DC: HDC; const ARect: TRect; hBr: HBRUSH): Integer;
const
  PixelOffset = 0.5;
var
  cr: Pcairo_t;
begin
  {$IFDEF GTK3DEBUGNOTIMPLEMENTED}
  DebugLn('TGtk3WidgetSet.FrameRect ARect=',dbgs(ARect));
  {$ENDIF}
  Result := 0;
  if not IsValidDC(DC) then
    exit;
  cr := TGtk3DeviceContext(DC).pcr;
  cairo_rectangle(cr, ARect.Left+PixelOffset, ARect.Top+PixelOffset, ARect.Right-ARect.Left-1, ARect.Bottom-ARect.Top-1);
  if IsValidGDIObject(hBr) then
    TGtk3DeviceContext(DC).SetSourceColor(TGtk3Brush(HBR).Color);
  cairo_set_line_width(cr, 1);
  cairo_stroke(cr); //Don't touch
end;

function TGtk3WidgetSet.HideCaret(hWnd: HWND): Boolean;
begin
  {$IFDEF GTK3DEBUGNOTIMPLEMENTED}
  DebugLn('WARNING: TGtk3WidgetSet.HideCaret not implemented ...');
  {$ENDIF}
  Result:=inherited HideCaret(hWnd);
end;

function TGtk3WidgetSet.GetActiveWindow: HWND;
var
  AWindow: PGdkWindow;
  AData: gpointer;
  AWidget: PGtkWidget;
  i: Integer;
begin
  Result := 0;
  AWindow := gdk_screen_get_active_window(gdk_screen_get_default);
  if AWindow <> nil then
  begin
    gdk_window_get_user_data(AWindow,@AWidget);
    if AWidget <> nil then
    begin
      AData := g_object_get_data(AWidget, 'lclwidget');
      // DebugLn('TGtk3WidgetSet.GetActiveWindow found window from data ...',dbgsName(TGtk3Widget(AData).LCLObject));
      exit({%H-}HWND(AData));
    end;
    for i := 0 to Screen.FormCount - 1 do
    begin
      if Screen.Forms[i].HandleAllocated then
      begin
        if PGtkWindow(TGtk3Window(Screen.Forms[i].Handle).Widget)^.get_window = AWindow then
        begin
          AWidget := PGtkWindow(TGtk3Window(Screen.Forms[i].Handle).Widget)^.get_focus;
          Result := HWND(Screen.Forms[i].Handle);
        end;
      end;
    end;
  end;
end;

function TGtk3WidgetSet.GetBitmapBits(Bitmap: HBITMAP; Count: Longint;
  Bits: Pointer): Longint;
begin
  Result:=inherited GetBitmapBits(Bitmap, Count, Bits);
end;

function TGtk3WidgetSet.GetBkColor(DC: HDC): TColorRef;
begin
  Result := 0;
  if IsValidDC(DC) then
    Result := TGtk3DeviceContext(DC).CurrentBrush.Color;
end;

function TGtk3WidgetSet.GetCapture: HWND;
begin
  Result := HwndFromGtkWidget(gtk_grab_get_current);
  {$IFDEF VerboseGtk3WinApi}
  DebugLn('TGtk3WidgetSet.GetCapture ',dbgHex(Result));
  {$ENDIF}
end;

function TGtk3WidgetSet.GetCaretPos(var lpPoint: TPoint): Boolean;
begin
  {$IFDEF GTK3DEBUGNOTIMPLEMENTED}
  DebugLn('WARNING: TGtk3WidgetSet.GetCaretPos not implemented ...');
  {$ENDIF}
  Result:=inherited GetCaretPos(lpPoint);
end;

function TGtk3WidgetSet.GetCaretRespondToFocus(handle: HWND;
  var ShowHideOnFocus: boolean): Boolean;
begin
  {$IFDEF GTK3DEBUGNOTIMPLEMENTED}
  DebugLn('WARNING: TGtk3WidgetSet.GetCaretPosRespondToFocus not implemented ...');
  {$ENDIF}
  Result:=inherited GetCaretRespondToFocus(handle, ShowHideOnFocus);
end;

function TGtk3WidgetSet.GetCharABCWidths(DC: HDC; p2, p3: UINT; const ABCStructs
  ): Boolean;
begin
  {$IFDEF GTK3DEBUGNOTIMPLEMENTED}
  DebugLn('WARNING: TGtk3WidgetSet.GetCharABCWidths not implemented ...');
  {$ENDIF}
  Result:=inherited GetCharABCWidths(DC, p2, p3, ABCStructs);
end;

function TGtk3WidgetSet.GetClientBounds(handle: HWND; var ARect: TRect
  ): Boolean;
begin
  {$IF DEFINED(VerboseGtk3WinAPI) OR DEFINED(GTK3DEBUGSIZE)}
  DebugLn('[Gtk3WinAPI GetClientBounds]');
  {$ENDIF}
  if Handle = 0 then
    Exit(False);
  ARect := TGtk3Widget(handle).getClientBounds;
  Result := True;
end;

function TGtk3WidgetSet.GetClientRect(handle: HWND; var ARect: TRect): Boolean;
begin
  {$IF DEFINED(VerboseGtk3WinAPI) OR DEFINED(GTK3DEBUGSIZE)}
  DebugLn('[Gtk3WinAPI GetClientRect]');
  {$ENDIF}
  if Handle = 0 then
    Exit(False);
  ARect := TGtk3Widget(handle).getClientRect;
  Result := True;
end;

function TGtk3WidgetSet.GetClipBox(DC: hDC; lpRect: PRect): Longint;
var
  GtkDC: TGtk3DeviceContext absolute DC;
  cr: Pcairo_t;
  //Pt: TPoint;
  ARect: TGdkRectangle;
begin
  //{$IFDEF GTK3DEBUGNOTIMPLEMENTED}
  //DebugLn('WARNING: TGtk3WidgetSet.GetClipBox not implemented ...');
  //{$ENDIF}
  Result := NULLREGION;
  if lpRect <> nil then
    lpRect^ := Rect(0,0,0,0);

  if not IsValidDC(DC) then
    Result := ERROR;

  if Result <> ERROR then
  begin
    cr := GtkDC.pcr;
    if gdk_cairo_get_clip_rectangle(cr, @ARect) then
    begin
      lpRect^ := RectFromGdkRect(ARect);
      Result := SimpleRegion;
    end;
  end;
end;

function TGtk3WidgetSet.GetClipRGN(DC: hDC; RGN: hRGN): Longint;
var
  ARect: TGdkRectangle;
begin
  {$IFDEF GTK3DEBUGNOTIMPLEMENTED}
  // DebugLn('WARNING: TGtk3WidgetSet.GetClipRgn not implemented ...');
  {$ENDIF}
  Result := -1;
  if not IsValidDC(DC) or (RGN = 0) then
    exit;
  gdk_cairo_get_clip_rectangle(TGtk3DeviceContext(DC).pcr, @ARect);
  // DebugLn('GetClipRgn ',dbgs(TGtk3Region(RGN).GetExtents),' clipRect ',dbgs(RectFromGdkRect(ARect)));
  if IsRectEmpty(RectFromGdkRect(ARect)) then
    exit(0)
  else
  begin
    cairo_region_destroy(TGtk3Region(RGN).Handle);
    TGtk3Region(RGN).Handle := cairo_region_create_rectangle(@ARect);
    Result := 1;
  end;
end;

function TGtk3WidgetSet.GetCmdLineParamDescForInterface: string;
begin
  {$IFDEF GTK3DEBUGNOTIMPLEMENTED}
  DebugLn('WARNING: TGtk3WidgetSet.GetCmdLineParamDescForInterface not implemented ...');
  {$ENDIF}
  Result:=inherited GetCmdLineParamDescForInterface;
end;

function TGtk3WidgetSet.GetCurrentObject(DC: HDC; uObjectType: UINT): HGDIOBJ;
var
  GtkDC: TGtk3DeviceContext absolute DC;
begin
  {$IFDEF GTK3DEBUGNOTIMPLEMENTED}
  // DebugLn('WARNING: TGtk3WidgetSet.GetCurrentObject not implemented ...');
  {$ENDIF}
  // Result:=inherited GetCurrentObject(DC, uObjectType);
  Result := 0;
  if not IsValidDC(DC) then
    Exit;
  case uObjectType of
    OBJ_BITMAP: Result := HGDIOBJ(GtkDC.CurrentImage);
    OBJ_BRUSH: Result := HGDIOBJ(GtkDC.CurrentBrush);
    OBJ_FONT: Result := HGDIOBJ(GtkDC.CurrentFont);
    OBJ_PEN: Result := HGDIOBJ(GtkDC.CurrentPen);
    OBJ_REGION: Result := HGDIOBJ(GtkDC.CurrentRegion);
  end;
end;

function TGtk3WidgetSet.GetCursorPos(var lpPoint: TPoint): Boolean;
var
  ADeviceManager: PGdkDeviceManager;
  APointer: PGdkDevice;
  AScreen: PGdkScreen;
begin
  ADeviceManager := gdk_display_get_device_manager(gdk_display_get_default);
  APointer := gdk_device_manager_get_client_pointer(ADeviceManager);
  AScreen := gdk_screen_get_default;
  gdk_device_get_position(APointer, @AScreen, @lpPoint.X, @lpPoint.Y);
  Result := True;
end;

function TGtk3WidgetSet.GetDC(hWnd: HWND): HDC;
var
  Widget: TGtk3Widget;
begin
  if Gtk3WidgetSet.IsValidHandle(hWnd) then
  begin
    Widget := TGtk3Widget(hWnd);
    Result := Widget.Context;
    if Result = 0 then
      Result := HDC(Gtk3DefaultContext);
  end else
    Result := HDC(Gtk3ScreenContext);
end;

function TGtk3WidgetSet.GetDCOriginRelativeToWindow(PaintDC: HDC;
  WindowHandle: HWND; var OriginDiff: TPoint): boolean;
begin
  {$IFDEF GTK3DEBUGNOTIMPLEMENTED}
  DebugLn('WARNING: TGtk3WidgetSet.GetDCOriginRelativeToWindow not implemented ...');
  {$ENDIF}
  Result:=inherited GetDCOriginRelativeToWindow(PaintDC, WindowHandle,
    OriginDiff);
end;

function TGtk3WidgetSet.GetDesignerDC(WindowHandle: HWND): HDC;
begin
  {$IFDEF GTK3DEBUGNOTIMPLEMENTED}
  DebugLn('WARNING: TGtk3WidgetSet.GetDesignerDC not implemented ...');
  {$ENDIF}
  Result:=inherited GetDesignerDC(WindowHandle);
end;

function TGtk3WidgetSet.GetDeviceCaps(DC: HDC; Index: Integer): Integer;
begin
  {$IFDEF GTK3DEBUGNOTIMPLEMENTED}
  if (Index <> BITSPIXEL) and (Index <> LOGPIXELSX) and (Index <> LOGPIXELSY) then
    DebugLn('WARNING: TGtk3WidgetSet.GetDeviceCaps not implemented ...Index=',dbgs(Index),' DC=',dbgs(DC));
  {$ENDIF}
  Result := 0; // inherited GetDeviceCaps(DC, Index);
  case Index of

    HORZRES : { Horizontal width in pixels }
    begin
      if IsValidDC(DC) then
      begin
        Result := TGtk3DeviceContext(DC).getDeviceSize.X;
      end else
        Result := GetSystemMetrics(SM_CXSCREEN);
    end;

    VERTRES : { Vertical height in pixels }
    begin
      if IsValidDC(DC) then
      begin
        Result := TGtk3DeviceContext(DC).getDeviceSize.Y;
      end else
        Result := GetSystemMetrics(SM_CYSCREEN);
    end;

    HORZSIZE : { Horizontal size in millimeters }
      Result := LazUtilities.RoundToInt((GetDeviceCaps(DC, HORZRES) * 100) /
                    (GetDeviceCaps(DC, LOGPIXELSX) * 25.4));

    VERTSIZE : { Vertical size in millimeters }
      Result := LazUtilities.RoundToInt((GetDeviceCaps(DC, VERTRES) * 100) /
                    (GetDeviceCaps(DC, LOGPIXELSY) * 25.4));

    BITSPIXEL:
    begin
      if IsValidDC(DC) then
        Result := TGtk3DeviceContext(DC).getDepth
      else
        Result := gdk_window_get_visual(gdk_get_default_root_window)^.get_depth;
    end;
    PLANES: Result := 1;
    SIZEPALETTE: Result := gdk_window_get_visual(gdk_get_default_root_window)^.get_colormap_size;
    LOGPIXELSX : { Logical pixels per inch in X }
    begin
      Result := LazUtilities.RoundToInt(gdk_screen_width / (gdk_screen_width_mm / 25.4));
    end;

    LOGPIXELSY : { Logical pixels per inch in Y }
    begin
      Result := LazUtilities.RoundToInt(gdk_screen_height / (gdk_screen_height_mm / 25.4));
    end;
  end;

end;

function TGtk3WidgetSet.GetDeviceSize(DC: HDC; var p: TPoint): boolean;
var
  ARect: TGdkRectangle;
begin
  Result := False;
  if not IsValidDC(DC) then
    exit;
  if TGtk3DeviceContext(DC).Parent <> nil then
  begin
    if Gtk3IsGdkWindow(TGtk3DeviceContext(DC).Parent^.window) then
    begin
      p.X := gdk_window_get_width(TGtk3DeviceContext(DC).Parent^.window);
      p.Y := gdk_window_get_height(TGtk3DeviceContext(DC).Parent^.window);
      Result := True;
    end;
  end else
  if (TGtk3DeviceContext(DC).ParentPixmap <> nil) and
    Gtk3IsGdkPixbuf(TGtk3DeviceContext(DC).ParentPixmap) then
  begin
    p.X := TGtk3DeviceContext(DC).ParentPixmap^.get_width;
    p.Y := TGtk3DeviceContext(DC).ParentPixmap^.get_height;
    Result := True;
  end else
  if TGtk3DeviceContext(DC).pcr <> nil then
  begin
    gdk_cairo_get_clip_rectangle(TGtk3DeviceContext(DC).pcr, @ARect);
    p.X := ARect.Width;
    p.Y := ARect.Height;
    Result := True;
  end;
end;

function TGtk3WidgetSet.GetDIBits(DC: HDC; Bitmap: HBitmap; StartScan,
  NumScans: UINT; Bits: Pointer; var BitInfo: BitmapInfo; Usage: UINT): Integer;
begin
  Result:=inherited GetDIBits(DC, Bitmap, StartScan, NumScans, Bits, BitInfo,
    Usage);
end;

function TGtk3WidgetSet.GetDpiForMonitor(hmonitor: HMONITOR;
  dpiType: TMonitorDpiType; out dpiX: UINT; out dpiY: UINT): HRESULT;
var
  w,w_mm,h,h_mm:gint;
  rr:double;
  pscr:PGdkScreen;
begin
  (*  MONITOR_DPI_TYPE = (
    MDT_EFFECTIVE_DPI = 0,
    MDT_ANGULAR_DPI = 1,
    MDT_RAW_DPI = 2,
    MDT_DEFAULT = MDT_EFFECTIVE_DPI);
  TMonitorDpiType = MONITOR_DPI_TYPE;
  *)
  pscr:=TGdkScreen.get_default;
  w:=pscr^.get_width;
  w_mm:=pscr^.get_width_mm;
  h:=pscr^.get_height;
  h_mm:=pscr^.get_height_mm;

  dpiX:=round(25.4*w/w_mm);
  dpiY:=round(25.4*h/h_mm);

  rr:=TGdkScreen.get_default^.get_resolution();

  Result:=0;
  //Result:=inherited GetDpiForMonitor(hmonitor, dpiType, dpiX, dpiY);
end;

function TGtk3WidgetSet.GetFocus: HWND;
var
  i: Integer;
  AWidget: PGtkWidget;
  AList: PGList;
  AHandle: TGtk3Window;
  AWindow: PGtkWindow;
  AActiveWindow: HWND;
begin
  AWidget := nil;

  AActiveWindow := GetActiveWindow;
  if AActiveWindow <> 0 then
  begin
    AWidget := PGtkWindow(TGtk3Widget(AActiveWindow).Widget)^.get_focus;
  end else
  begin
    // worst case scenario is to search for widget or when application
    // isn't active anymore
    AList := gtk_window_list_toplevels;
    for i := 0 to g_list_length(AList) - 1 do
    begin
      if Gtk3IsGtkWindow(PGObject(g_list_nth(AList, i)^.data)) then
      begin
        // gtk3 this is really ugly, it returns .is_active for non active
        // windows, while docs says that is_active is window with kbd focus
        AWindow := PGtkWindow(g_list_nth(AList, i)^.data);
        AHandle := TGtk3Window(HwndFromGtkWidget(AWindow));
        if Assigned(AHandle) and (Screen.FocusedForm = AHandle.LCLObject) and
           (AWindow^.is_active) then
        begin
          AWidget := PGtkWindow(g_list_nth(AList, i)^.data)^.get_focus;
          if AWidget <> nil then
            break;
        end;
      end;
    end;
    g_list_free(AList);
  end;

  Result := HwndFromGtkWidget(AWidget);
  {$IFDEF GTK3DEBUGFOCUS}
  DebugLn('TGtk3WidgetSet.GetFocus current focus ',dbgHex(Result));
  if IsValidHandle(Result) then
    DebugLn('TGtk3WidgetSet.GetFocus current focus ',dbgsName(TGtk3Widget(Result).LCLObject));
  {$ENDIF}
end;

function TGtk3WidgetSet.GetFontLanguageInfo(DC: HDC): DWord;
begin
  Result:=inherited GetFontLanguageInfo(DC);
end;

function TGtk3WidgetSet.GetForegroundWindow: HWND;
var
  i: Integer;
  AWidget: PGtkWindow;
  AWindow: PGtkWindow;
  AList: PGList;
begin
  Result := 0;
  AWidget := nil;
  AWindow := nil;
  AList := gtk_window_list_toplevels;
  for i := 0 to g_list_length(AList) - 1 do
  begin
    if Gtk3IsGtkWindow(PGObject(g_list_nth(AList, i)^.data)) then
    begin
      AWidget := g_list_nth(AList, i)^.data;
      if AWidget^.get_visible and AWidget^.is_toplevel and AWidget^.is_active then
      begin
        AWindow := AWidget;
        break;
      end;
    end;
  end;
  g_list_free(AList);
  Result := HwndFromGtkWidget(AWindow);
end;

function TGtk3WidgetSet.GetKeyState(nVirtKey: Integer): Smallint;
const
  StateDown    = SmallInt($FF80);
var
  AKeyMap: PGdkKeymap;
  AModifiers: guint;
begin
  Result := 0;

  Result := 0;

  case nVirtKey of
    VK_LSHIFT:   nVirtKey := VK_SHIFT;
    VK_LCONTROL: nVirtKey := VK_CONTROL;
    VK_LMENU:    nVirtKey := VK_MENU;
  end;

  (*
  // GdkModifierType
  GDK_SHIFT_MASK: TGdkModifierType = 1;
  GDK_LOCK_MASK: TGdkModifierType = 2;
  GDK_CONTROL_MASK: TGdkModifierType = 4;
  GDK_MOD1_MASK: TGdkModifierType = 8;
  GDK_MOD2_MASK: TGdkModifierType = 16;
  GDK_MOD3_MASK: TGdkModifierType = 32;
  GDK_MOD4_MASK: TGdkModifierType = 64;
  GDK_MOD5_MASK: TGdkModifierType = 128;
  GDK_BUTTON1_MASK: TGdkModifierType = 256;
  GDK_BUTTON2_MASK: TGdkModifierType = 512;
  GDK_BUTTON3_MASK: TGdkModifierType = 1024;
  GDK_BUTTON4_MASK: TGdkModifierType = 2048;
  GDK_BUTTON5_MASK: TGdkModifierType = 4096;
  GDK_MODIFIER_RESERVED_13_MASK: TGdkModifierType = 8192;
  GDK_MODIFIER_RESERVED_14_MASK: TGdkModifierType = 16384;
  GDK_MODIFIER_RESERVED_15_MASK: TGdkModifierType = 32768;
  GDK_MODIFIER_RESERVED_16_MASK: TGdkModifierType = 65536;
  GDK_MODIFIER_RESERVED_17_MASK: TGdkModifierType = 131072;
  GDK_MODIFIER_RESERVED_18_MASK: TGdkModifierType = 262144;
  GDK_MODIFIER_RESERVED_19_MASK: TGdkModifierType = 524288;
  GDK_MODIFIER_RESERVED_20_MASK: TGdkModifierType = 1048576;
  GDK_MODIFIER_RESERVED_21_MASK: TGdkModifierType = 2097152;
  GDK_MODIFIER_RESERVED_22_MASK: TGdkModifierType = 4194304;
  GDK_MODIFIER_RESERVED_23_MASK: TGdkModifierType = 8388608;
  GDK_MODIFIER_RESERVED_24_MASK: TGdkModifierType = 16777216;
  GDK_MODIFIER_RESERVED_25_MASK: TGdkModifierType = 33554432;
  GDK_SUPER_MASK: TGdkModifierType = 67108864;
  GDK_HYPER_MASK: TGdkModifierType = 134217728;
  GDK_META_MASK: TGdkModifierType = 268435456;
  GDK_MODIFIER_RESERVED_29_MASK: TGdkModifierType = 536870912;
  GDK_RELEASE_MASK: TGdkModifierType = 1073741824;
  GDK_MODIFIER_MASK: TGdkModifierType = 1543512063;
  *)
  // AModifierMask := gdk_keymap_get_modifier_mask(AKeyMap, 0);

  AKeyMap := gdk_keymap_get_default;
  AModifiers := gdk_keymap_get_modifier_state(AKeyMap);
  case nVirtKey of
    VK_LBUTTON:
      if AModifiers and GDK_BUTTON1_MASK <> 0 then
        Result := Result or StateDown;
    VK_RBUTTON:
      if AModifiers and GDK_BUTTON2_MASK <> 0 then
        Result := Result or StateDown;
    VK_MBUTTON:
      if AModifiers and GDK_BUTTON3_MASK <> 0 then
        Result := Result or StateDown;
    VK_XBUTTON1:
      if AModifiers and GDK_BUTTON4_MASK <> 0 then
        Result := Result or StateDown;
    VK_XBUTTON2:
      if AModifiers and GDK_BUTTON5_MASK <> 0 then
        Result := Result or StateDown;
    VK_MENU:
      if AModifiers and GDK_MOD1_MASK <> 0 then
        Result := Result or StateDown;
    VK_SHIFT:
      if AModifiers and GDK_SHIFT_MASK <> 0 then
        Result := Result or StateDown;
    VK_CONTROL:
      if AModifiers and GDK_CONTROL_MASK <> 0 then
        Result := Result or StateDown;
    VK_LWIN, VK_RWIN:
      if AModifiers and GDK_META_MASK <> 0 then
        Result := Result or StateDown;
   {$ifdef VerboseGtk3WinAPI}
    else
      DebugLn('TGtk3WidgetSet.GetKeyState TODO ', DbgSVKCode(Word(nVirtkey)));
   {$endif}
  end;
end;

function TGtk3WidgetSet.GetMapMode(DC: HDC): Integer;
begin
  {$IFDEF GTK3DEBUGNOTIMPLEMENTED}
  DebugLn('WARNING: TGtk3WidgetSet.GetMapMode not implemented ...');
  {$ENDIF}
  Result:=inherited GetMapMode(DC);
end;

function TGtk3WidgetSet.GetMonitorInfo(Monitor: HMONITOR; lpmi: PMonitorInfo
  ): Boolean;
var
  MonitorRect, MonitorWorkArea: TGdkRectangle;
begin
  Result := (lpmi <> nil) and (lpmi^.cbSize >= SizeOf(TMonitorInfo)) or (Monitor = 0);
  if not Result then Exit;
  Dec(Monitor);
  gdk_screen_get_monitor_geometry(gdk_screen_get_default, Monitor, @MonitorRect);

  with MonitorRect do
    lpmi^.rcMonitor := Bounds(x, y, width, height);
  // there is no way to determine workarea in gtk
  gdk_screen_get_monitor_workarea(gdk_screen_get_default, Monitor, @MonitorWorkArea);
  with MonitorWorkArea do
    lpmi^.rcWork := Bounds(x, y, width, height);
  lpmi^.rcWork := lpmi^.rcMonitor;
  if Monitor = gdk_screen_get_primary_monitor(gdk_screen_get_default) then
    lpmi^.dwFlags := MONITORINFOF_PRIMARY
  else
    lpmi^.dwFlags := 0;
end;

function TGtk3WidgetSet.GetObject(GDIObj: HGDIOBJ; BufSize: Integer;
  Buf: Pointer): Integer;
begin
  Result := 0;
  if not IsValidGDIObject(GDIObj) then
  begin
    {$ifdef VerboseGtk3WinAPI}
      WriteLn('Trace:< TGtk3WidgetSet.GetObject Invalid GDI Object');
    {$endif}
    Exit;
  end;
  Result:=TGtk3ContextObject(GDIObj).Get(bufsize, buf);
end;

function TGtk3WidgetSet.GetParent(Handle: HWND): HWND;
begin
  if Handle <> 0 then
    Result := HWND(TGtk3Widget(Handle).getParent)
  else
    Result := 0;
end;

function TGtk3WidgetSet.GetProp(Handle: hwnd; Str: PChar): Pointer;
begin
  Result := nil;
  if not IsValidHandle(Handle) then
    exit;
  Result := g_object_get_data(TGtk3Widget(Handle).Widget, PgChar(Str));
end;

function TGtk3WidgetSet.GetRgnBox(RGN: HRGN; lpRect: PRect): Longint;
begin
  Result := SIMPLEREGION;
  if IsValidGDIObject(RGN) then
  begin
    lpRect^ := TGtk3Region(RGN).GetExtents;
  end;
end;

function TGtk3WidgetSet.GetROP2(DC: HDC): Integer;
begin
  {$IFDEF GTK3DEBUGNOTIMPLEMENTED}
  DebugLn('WARNING: TGtk3WidgetSet.GetROP2 not implemented ...');
  {$ENDIF}
  Result := inherited GetROP2(DC);
end;

function TGtk3WidgetSet.GetScrollBarSize(Handle: HWND; BarKind: Integer
  ): integer;
var
  BarWidget: PGtkWidget;
  Scrolled: PGtkScrolledWindow;
begin
  Result := 0;
  if not IsValidHandle(Handle) then
    exit;
  BarWidget := nil;
  if wtScrollbar in TGtk3Widget(Handle).WidgetType then
    BarWidget := TGtk3Widget(Handle).Widget
  else
  if wtScrollingWin in TGtk3Widget(Handle).WidgetType then
  begin
    Scrolled := TGtk3ScrollableWin(Handle).GetScrolledWindow;
    if Scrolled <> nil then
    begin
      if BarKind = SM_CYVSCROLL then
        BarWidget := Scrolled^.get_vscrollbar
      else
        BarWidget := Scrolled^.get_hscrollbar;
    end;
  end;
  if BarWidget <> nil then
  begin
    if BarKind = SM_CYVSCROLL then
      Result := BarWidget^.get_allocated_width
    else
      Result := BarWidget^.get_allocated_height;
  end;
end;

function TGtk3WidgetSet.GetScrollbarVisible(Handle: HWND; SBStyle: Integer
  ): boolean;
var
  AWidget: TGtk3Widget;
begin
  Result := False;
  if not IsValidHandle(Handle) then
    exit;
  AWidget := TGtk3Widget(Handle);

  if wtScrollBar in AWidget.WidgetType then
    Result := AWidget.Visible
  else
  begin
    if wtScrollingWin in AWidget.WidgetType then
    begin
      if SBStyle = SB_Horz then
        Result := TGtk3ScrollableWin(Handle).getHorizontalScrollbar^.get_visible
      else
      if SBStyle = SB_Vert then
        Result := TGtk3ScrollableWin(Handle).getVerticalScrollbar^.get_visible
    end;
  end;
end;

function TGtk3WidgetSet.GetScrollInfo(Handle: HWND; SBStyle: Integer;
  var ScrollInfo: TScrollInfo): Boolean;
var
  Adjustment: PGtkAdjustment;
  AWidget: TGtk3Widget;
  AScrollWin: PGtkScrolledWindow;
begin
  Result := False;
  if not IsValidHandle(Handle) then
    exit;
  AWidget := TGtk3Widget(Handle);
  Adjustment := nil;
  AScrollWin := nil;
  if wtScrollBar in AWidget.WidgetType then
    Adjustment := PGtkScrollBar(AWidget.Widget)^.adjustment
  else
  if wtScrollingWin in AWidget.WidgetType then
    AScrollWin := TGtk3ScrollableWin(Handle).GetScrolledWindow;

  case SBStyle of
    SB_Horz:
    begin
      if not Assigned(Adjustment) and Assigned(AScrollWin) then
        Adjustment := AScrollWin^.get_hadjustment;
    end;
    SB_Vert:
    begin
      if not Assigned(Adjustment) and Assigned(AScrollWin) then
        Adjustment := AScrollWin^.get_vadjustment;
    end;
    SB_CTL:
    begin

    end;
    SB_BOTH:
    begin

    end;
  end;

  if Adjustment = nil then
  begin
    DebugLn('TGtk3WidgetSet.GetScrollInfo error: cannot get PGtkAdjustment from ',dbgsName(AWidget.LCLObject));
    exit;
  end;

  // POS
  if (ScrollInfo.fMask and SIF_POS) <> 0 then
    ScrollInfo.nPos := Round(Adjustment^.Value);

  // RANGE
  if (ScrollInfo.fMask and SIF_RANGE) <> 0 then
  begin
    ScrollInfo.nMin:= Round(Adjustment^.Lower);
    ScrollInfo.nMax:= Round(Adjustment^.Upper);
  end;
  // PAGE
  if (ScrollInfo.fMask and SIF_PAGE) <> 0 then
  begin
    ScrollInfo.nPage := Round(Adjustment^.Page_Size);
  end;
  // TRACKPOS
  if (ScrollInfo.fMask and SIF_TRACKPOS) <> 0 then
  begin
    ScrollInfo.nTrackPos := Round(Adjustment^.Value);
  end;

  Result := True;
end;

function TGtk3WidgetSet.GetStockObject(Value: Integer): THandle;
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
  end;
end;

function TGtk3WidgetSet.GetSysColor(nIndex: Integer): DWORD;
begin
  {$IFDEF GTK3DEBUGNOTIMPLEMENTED}
  writeln('TGtk3WidgetSet.GetSysColor WARNING: SOME SYSCOLORS ARE STILL HARDCODED nIndex=',nIndex);
  {$ENDIF}
  if (nIndex = COLOR_WINDOW) or (nIndex = COLOR_WINDOWTEXT) or
    (nIndex = COLOR_HIGHLIGHT) or (nIndex = COLOR_HIGHLIGHTTEXT) then
      GetStyleWidget(lgsMemo)
  else
  if (nIndex = COLOR_MENU) or (nIndex = COLOR_MENUHILIGHT) or
    (nIndex = COLOR_MENUTEXT) then
  begin
    GetStyleWidget(lgsMenu);
    GetStyleWidget(lgsMenuitem);
  end else
  if (nIndex = COLOR_MENUBAR) then
    GetStyleWidget(lgsMenuBar)
  else
  if (nIndex = COLOR_SCROLLBAR) then
    GetStyleWidget(lgsVerticalScrollbar)
  else
  if (nIndex = COLOR_BTNFACE) or (nIndex = COLOR_BTNTEXT) or
    (nIndex = COLOR_BTNSHADOW) or (nIndex = COLOR_BTNHIGHLIGHT) then
    GetStyleWidget(lgsButton)
  else
  if (nIndex = COLOR_BACKGROUND) or (nIndex = COLOR_FORM) then
    GetStyleWidget(lgsWindow);
  Result := SysColorMap[nIndex];
end;

function TGtk3WidgetSet.GetSysColorBrush(nIndex: Integer): HBrush;
begin
  if (nIndex < 0) or (nIndex > MAX_SYS_COLORS) then
  begin
    Result := 0;
    DebugLn(Format('ERROR: [TGtk3WidgetSet.GetSysColorBrush] Bad Value: %d. Valid Range between 0 and %d', [nIndex, MAX_SYS_COLORS]));
  end else
  begin
    Result := FSysColorBrushes[nIndex];
    if Result = HBRUSH(-1) then
    begin
      InitSysColorBrushes;
      Result := FSysColorBrushes[nIndex];
      if Result = HBRUSH(-1) then
        DebugLn('WARNING: GetSysColorBrush SysColorBrushes arent''t initialized properly....');
    end;
  end;
end;

function TGtk3WidgetSet.GetSystemMetrics(nIndex: Integer): Integer;
var
  auw: guint;
  auh: guint;
  ascreen: PGdkScreen;
  ARect: TGdkRectangle;
begin
  Result := 0;
  case nIndex of
    SM_CXCURSOR,
    SM_CYCURSOR:
      begin
        // Width and height of a cursor, in pixels. For win32 system cannot create cursors of other sizes.
        // For gtk this should be maximal cursor sizes
        gdk_display_get_maximal_cursor_size(gdk_display_get_default, @auw, @auh);
        if nIndex = SM_CXCURSOR then
          Result := auw // return width
        else
          Result := auh; // return height
      end;
    SM_CXDRAG:
      begin
        Result := 2;
      end;
    SM_CYDRAG:
      begin
        Result := 2;
      end;
    SM_CXEDGE:
      begin
        Result := 2;
      end;
    SM_CYEDGE:
      begin
        Result := 2;
      end;

    SM_CXICON,
    SM_CYICON:
      // big icon size
      // gtk recommends sizes 16,32,48. optional: 64 and 128
      Result := 128;

    SM_CXMAXIMIZED:
      begin
        ascreen := gdk_screen_get_default();
        gdk_screen_get_monitor_workarea(ascreen, 0, @ARect);
        Result := ARect.width;
      end;
    SM_CYMAXIMIZED:
      begin
        ascreen := gdk_screen_get_default();
        gdk_screen_get_monitor_workarea(ascreen, 0, @ARect);
        Result := ARect.height;
      end;

    SM_CXFULLSCREEN,
    SM_CXSCREEN:
      begin
        ascreen := gdk_screen_get_default();
        gdk_screen_get_monitor_geometry(ascreen, 0, @ARect);
        Result := ARect.width;
      end;
    SM_CXVIRTUALSCREEN:
      begin
        Result := gdk_Screen_Width;
      end;
    SM_CYFULLSCREEN,
    SM_CYSCREEN:
      begin
        ascreen := gdk_screen_get_default();
        gdk_screen_get_monitor_geometry(ascreen, 0, @ARect);
        Result := ARect.height;
      end;
    SM_CYVIRTUALSCREEN:
      begin
        result := gdk_Screen_Height;
      end;
    SM_LCLHasFormAlphaBlend:
      Result := 1;
  end;
end;

function TGtk3WidgetSet.GetTextColor(DC: HDC): TColorRef;
begin
  Result := CLR_INVALID;
  if IsValidDC(DC) then
    Result := TColorRef(TGtk3DeviceContext(DC).CurrentTextColor);
end;

function TGtk3WidgetSet.GetTextExtentPoint(DC: HDC; Str: PChar; Count: Integer;
  var Size: TSize): Boolean;
begin
  Result := False;
  if not IsValidDC(DC) then
    exit;
  if (Count <= 0) or (Str = nil) or (StrPas(Str) = '') then
  begin
    FillChar(Size, SizeOf(Size), 0);
    Exit;
  end;
  TGtk3DeviceContext(DC).CurrentFont.Layout^.set_text(Str, Count);
  TGtk3DeviceContext(DC).CurrentFont.Layout^.get_pixel_size(@Size.Cx, @Size.CY);
  // DebugLn('TGtk3WidgetSet.GetTextExtentPoint pixel size is ',dbgs(Size),
  //  ' avgcharwidth ',dbgs(ACharWidth div PANGO_SCALE),' avgdigitwidth ',dbgs(ADigitWidth div PANGO_SCALE));
  Result := True;
end;

function TGtk3WidgetSet.GetTextMetrics(DC: HDC; var TM: TTextMetric): Boolean;
const
  TestString: array[boolean] of string = (
    // single byte char font
    '{ABCDEFGHIJKLMNOPQRSTUVWXYZXYZabcdefghijklmnopqrstuvwxyz|_}',
    // double byte char font
    #0'{'#0'A'#0'B'#0'C'#0'D'#0'E'#0'F'#0'G'#0'H'#0'I'#0'J'#0'K'#0'L'#0'M'#0'N'
    +#0'O'#0'P'#0'Q'#0'R'#0'S'#0'T'#0'U'#0'V'#0'W'#0'X'#0'Y'#0'Z'#0'X'#0'Y'#0'Z'
    +#0'a'#0'b'#0'c'#0'd'#0'e'#0'f'#0'g'#0'h'#0'i'#0'j'#0'k'#0'l'#0'm'#0'n'#0'o'
    +#0'p'#0'q'#0'r'#0's'#0't'#0'u'#0'v'#0'w'#0'x'#0'y'#0'z'#0'|'#0'_'#0'}'
    );
var
  AFont: TGtk3Font;
  APangoMetrics: PPangoFontMetrics;
  aRect: TPangoRectangle;
  APangoWeight: TPangoWeight;
begin
  Result := False;
  if IsValidDC(DC) then
  begin
    //TODO add metrics to cache of font, so if we have valid metrics just return.
    //or create metrics when font is created (like qt uses)
    AFont := TGtk3DeviceContext(DC).CurrentFont;

    APangoMetrics := pango_context_get_metrics(AFont.Layout^.get_context,
      AFont.Handle, AFont.Layout^.get_context^.get_language);
    if APangoMetrics = nil then
    begin
      DebugLn(['TGtk3WidgetSet.UpdateDCTextMetric WARNING: no pango metrics']);
      exit;
    end;
    FillChar(TM, SizeOf(TM), #0);

    TM.tmAveCharWidth := Max(1,
               PANGO_PIXELS(pango_font_metrics_get_approximate_char_width(APangoMetrics))
               );
    TM.tmAscent := PANGO_PIXELS(APangoMetrics^.get_ascent);
    TM.tmDescent := PANGO_PIXELS(APangoMetrics^.get_descent);

    TM.tmHeight := TM.tmAscent + TM.tmDescent;

    pango_layout_set_text(AFont.Layout, PChar(TestString[True]),
                          length(PChar(TestString[True])));
    pango_layout_get_extents(AFont.Layout, nil, @aRect);

    // lBearing := 0; // PANGO_LBEARING(aRect) div PANGO_SCALE;
    // rBearing := 0; // PANGO_RBEARING(aRect) div PANGO_SCALE;

    pango_layout_set_text(AFont.Layout, 'M', 1);
    pango_layout_get_pixel_size(AFont.Layout, @aRect.width, @aRect.height);
    TM.tmMaxCharWidth := Max(1,aRect.width);
    pango_layout_set_text(AFont.Layout, 'W', 1);
    pango_layout_get_pixel_size(AFont.Layout, @aRect.width, @aRect.height);
    TM.tmMaxCharWidth := Max(TM.tmMaxCharWidth,aRect.width);

    APangoWeight := AFont.Handle^.get_weight;

    if APangoWeight < PANGO_WEIGHT_THIN then
      APangoWeight := PANGO_WEIGHT_THIN;
    if APangoWeight > PANGO_WEIGHT_HEAVY then
      APangoWeight := PANGO_WEIGHT_HEAVY;

    TM.tmWeight := APangoWeight;

    TM.tmFirstChar := 'a';
    TM.tmLastChar := 'z';
    TM.tmDefaultChar := 'x';
    TM.tmBreakChar := '?';

    TM.tmItalic := Ord(AFont.Handle^.get_style = PANGO_STYLE_ITALIC);
    //  APangoMetrics^.get_underline_position;
    // TM.tmUnderlined :=
    // TM.tmStruckOut :=
    pango_font_metrics_unref(APangoMetrics);
    Result := True;
  end;
end;

function TGtk3WidgetSet.GetViewPortExtEx(DC: HDC; Size: PSize): Integer;
begin
  {$IFDEF GTK3DEBUGNOTIMPLEMENTED}
  DebugLn('WARNING: TGtk3WidgetSet.GetViewportExtEx not implemented ...');
  {$ENDIF}
  Result:=inherited GetViewPortExtEx(DC, Size);
end;

function TGtk3WidgetSet.GetViewPortOrgEx(DC: HDC; P: PPoint): Integer;
begin
  {$IFDEF GTK3DEBUGNOTIMPLEMENTED}
  DebugLn('WARNING: TGtk3WidgetSet.GetViewportOrgEx not implemented ...');
  {$ENDIF}
  Result:=inherited GetViewPortOrgEx(DC, P);
end;

function TGtk3WidgetSet.GetWindowExtEx(DC: HDC; Size: PSize): Integer;
begin
  {$IFDEF GTK3DEBUGNOTIMPLEMENTED}
  DebugLn('WARNING: TGtk3WidgetSet.GetWindowExtEx not implemented ...');
  {$ENDIF}
  Result:=inherited GetWindowExtEx(DC, Size);
end;

function TGtk3WidgetSet.GetWindowLong(Handle: HWND; int: Integer): PtrInt;
begin
  {$IFDEF GTK3DEBUGNOTIMPLEMENTED}
  DebugLn('WARNING: TGtk3WidgetSet.GetWindowLong not implemented ...');
  {$ENDIF}
  Result:=inherited GetWindowLong(Handle, int);
end;

function TGtk3WidgetSet.GetWindowOrgEx(dc: hdc; P: PPoint): Integer;
var
  Matrix: cairo_matrix_t;
  dx: Double;
  dy: Double;
begin
  {$IFDEF GTK3DEBUGNOTIMPLEMENTED}
  // DebugLn('WARNING: TGtk3WidgetSet.GetWindowOrgEx not implemented ...');
  {$ENDIF}
  Result := 0;
  if not IsValidDC(DC) and (P <> nil) then
  begin
    {$ifdef VerboseGtk3WinAPI}
      WriteLn('Trace: < [WinAPI GetWindowOrgEx] No valid DC or P is nil');
    {$endif}
    exit;
  end;
  cairo_get_matrix(TGtk3DeviceContext(DC).pcr, @Matrix);
  dx := 0;
  dy := 0;
  cairo_matrix_transform_point(@Matrix, @dx, @dy);
  // DebugLn('GetWindowOrgEx POINT ',Format('dx %d dy %d',[-Trunc(Dx), -Trunc(Dy)]));
  if P <> nil then
  begin
    P^.X := -Trunc(DX)+TGtk3DeviceContext(DC).fncOrigin.X;
    P^.Y := -Trunc(DY)+TGtk3DeviceContext(DC).fncOrigin.Y;
  end;
  Result := 1;
end;

function TGtk3WidgetSet.GetWindowRect(Handle: hwnd; var ARect: TRect): Integer;
var
  AWindow: PGdkWindow;
  x, y: gint;
  //w, h: gint;
  GRect: TGdkRectangle;
  Allocation: TGtkAllocation;
begin
  Result := 0;
  if Handle <> 0 then
  begin
    AWindow := TGtk3Widget(Handle).GetWindow;
    if AWindow <> nil then
    begin
      AWindow^.get_origin(@x, @y);
      //w := AWindow^.get_width;
      //h := AWindow^.get_height;
      AWindow^.get_frame_extents(@GRect);
      // R := RectFromGdkRect(GRect);
      ARect := Bounds(0, 0, GRect.width, GRect.Height);
      Result := 1;
    end else
    begin
      TGtk3Widget(Handle).Widget^.get_allocation(@Allocation);
      ARect := Bounds(Allocation.x, Allocation.y, Allocation.width, Allocation.height);
    end;
  end;
end;

function TGtk3WidgetSet.GetWindowRelativePosition(Handle: hwnd; var Left,
  Top: integer): boolean;
var
  AWidget: TGtk3Widget;
  APos: TPoint;
begin
  Left:=0;
  Top:=0;
  if Handle = 0 then
    exit(False);
  AWidget := TGtk3Widget(Handle);
  Result := AWidget.GetPosition(APos);
  Left:=APos.X;
  Top:=APos.Y;
end;

function TGtk3WidgetSet.GetWindowSize(Handle: hwnd; var Width, Height: integer
  ): boolean;
var
  aWidget: PGtkWidget;
begin
  Result := False;
  if Handle <> 0 then
  begin
    aWidget:= TGtk3Widget(Handle).Widget;
    if aWidget<>nil then
    begin
      Width := aWidget^.get_allocated_width;
      Height := aWidget^.get_allocated_Height;
      Result := True;
    end;
  end;
end;

procedure TGtk3WidgetSet.InitializeCriticalSection(
  var CritSection: TCriticalSection);
var
  ACritSec: System.PRTLCriticalSection;
begin
  New(ACritSec);
  System.InitCriticalSection(ACritSec^);
  CritSection:=TCriticalSection(ACritSec);
end;

function TGtk3WidgetSet.InvalidateRect(aHandle: HWND; Rect: pRect;
  bErase: Boolean): Boolean;
begin
  Result := False;
  if AHandle <> 0 then
  begin
    TGtk3Widget(AHandle).Update(Rect);
    Result := True;
  end;
end;

function TGtk3WidgetSet.InvalidateRgn(Handle: HWND; Rgn: HRGN; Erase: Boolean): Boolean;
//var
//  R: TRect;
begin
  Result := False; // inherited InvalidateRgn(Handle, Rgn, Erase);
  if IsValidHandle(Handle) then
  begin
    if IsValidGDIObject(RGN) then
    begin
      gtk_widget_queue_draw_region(TGtk3Widget(Handle).GetContainerWidget,
       TGtk3Region(RGN).Handle)
    end else
      TGtk3Widget(Handle).Update(nil);
    //TODO: TGtk3Region must be implemented as Pcairo_region_t
    // GetRgnBox(Rgn, @R);
    // InvalidateRect(Handle, @R, True);
    Result := True;
    // gtk_widget_queue_draw_region();
  end;
end;

function TGtk3WidgetSet.IsIconic(handle: HWND): boolean;
begin
  Result := (handle <> 0) and TGtk3Widget(Handle).IsIconic;
end;

function TGtk3WidgetSet.IsWindow(handle: HWND): boolean;
begin
  Result := (handle <> 0) and
    Gtk3IsWidget(TGtk3Widget(Handle).Widget);
end;

function TGtk3WidgetSet.IsWindowEnabled(handle: HWND): boolean;
begin
  Result := (handle <> 0) and TGtk3Widget(Handle).Enabled and
    TGtk3Widget(Handle).Visible;
end;

function TGtk3WidgetSet.IsWindowVisible(handle: HWND): boolean;
begin
  Result := (handle <> 0) and TGtk3Widget(Handle).Visible;
end;

function TGtk3WidgetSet.IsZoomed(handle: HWND): boolean;
begin
  {$IFDEF GTK3DEBUGNOTIMPLEMENTED}
  DebugLn('WARNING: TGtk3WidgetSet.IsZoomed not implemented ...');
  {$ENDIF}
  Result:=inherited IsZoomed(handle);
end;

procedure TGtk3WidgetSet.LeaveCriticalSection(var CritSection: TCriticalSection
  );
var
  ACritSec: System.PRTLCriticalSection;
begin
  ACritSec:=System.PRTLCriticalSection(CritSection);
  System.LeaveCriticalsection(ACritSec^);
end;

function TGtk3WidgetSet.LineTo(DC: HDC; X, Y: Integer): Boolean;
begin
  if not IsValidDC(DC) then
    exit(False);
  Result := TGtk3DeviceContext(DC).LineTo(X, Y);
end;

function TGtk3WidgetSet.LPtoDP(DC: HDC; var Points; Count: Integer): BOOL;
var
  //Matrix: cairo_matrix_t;
  cr: PCairo_t;
  P: PPoint;
  dx, dy: Double;
  //Pt: TPoint;
begin
  {$IFDEF GTK3DEBUGNOTIMPLEMENTED}
  // DebugLn('WARNING: TGtk3WidgetSet.LPtoDP not implemented ...');
  {$ENDIF}
  Result := False;
  // inherited LPtoDP(DC, Points, Count);
  if not IsValidDC(DC) then
    exit;
  cr := TGtk3DeviceContext(DC).pcr;

  P := @Points;
  while Count > 0 do
  begin
    Dec(Count);
    DX := P^.X;
    DY := P^.Y;
    // DebugLn('LPTODP INPUT ',Format('dx %2.2n dy %2.2n',[dx, dy]));
    //cairo_matrix_translate(@Matrix, Dx, Dy);
    //cairo_matrix_transform_point(@Matrix, @Dx, @Dy);
    cairo_user_to_device(cr,@dx,@dy);
    // DebugLn('LPTODP Output ',Format('dx %2.2n dy %2.2n',[dx, dy]));
    P^.X := Round(DX)-TGtk3DeviceContext(DC).fncOrigin.x;
    P^.Y := Round(DY)-TGtk3DeviceContext(DC).fncOrigin.y;
    Inc(P);
  end;
  Result:=true;
end;

function TGtk3WidgetSet.MessageBox(hWnd: HWND; lpText, lpCaption: PChar;
  uType: Cardinal): integer;
var
  fact:TGtk3DialogFactory;
begin
  fact:=TGtk3DialogFactory.CreateMsgBox(hWnd,lpText,lpCaption,uType);
  try
    fact.run;
    Result:=fact.lcl_result;
  finally
    fact.Free;
  end;
end;

function TGtk3WidgetSet.MonitorFromPoint(ptScreenCoords: TPoint; dwFlags: DWord
  ): HMONITOR;
var
  pscr:PGdkScreen;
  nmon:gint;
begin
  pscr:=TGdkScreen.get_default;
  nmon:=pscr^.get_monitor_at_point(ptScreenCoords.X,ptScreenCoords.Y);
  Result:=HMONITOR(nmon+1);
end;

function TGtk3WidgetSet.MonitorFromWindow(hWnd: HWND; dwFlags: DWord): HMONITOR;
var
  pscr:PGdkScreen;
  nmon:gint;
begin
  pscr:=TGdkScreen.get_default;
  nmon:=pscr^.get_monitor_at_window(TGtk3Widget(hWnd).GetWindow);
  Result:=HMONITOR(nmon+1);
end;

function TGtk3WidgetSet.MoveToEx(DC: HDC; X, Y: Integer; OldPoint: PPoint
  ): Boolean;
begin
  if not IsValidDC(DC) then
    exit(False);
  Result := TGtk3DeviceContext(DC).MoveTo(X, Y, OldPoint);
end;

function TGtk3WidgetSet.OffsetRgn(RGN: HRGN; nXOffset, nYOffset: Integer
  ): Integer;
begin
  {$IFDEF GTK3DEBUGNOTIMPLEMENTED}
  DebugLn('WARNING: TGtk3WidgetSet.OffsetRgn not implemented ...');
  {$ENDIF}
  Result:=inherited OffsetRgn(RGN, nXOffset, nYOffset);
end;

function TGtk3WidgetSet.PaintRgn(DC: HDC; RGN: HRGN): Boolean;
begin
  {$IFDEF GTK3DEBUGNOTIMPLEMENTED}
  DebugLn('WARNING: TGtk3WidgetSet.PaintRgn not implemented ...');
  {$ENDIF}
  Result:=inherited PaintRgn(DC, RGN);
end;

function TGtk3WidgetSet.PeekMessage(var lpMsg: TMsg; Handle: HWND;
  wMsgFilterMin, wMsgFilterMax, wRemoveMsg: UINT): Boolean;
begin
  {$IFDEF GTK3DEBUGNOTIMPLEMENTED}
  DebugLn('WARNING: TGtk3WidgetSet.PeekMessage not implemented ...');
  {$ENDIF}
  Result:=inherited PeekMessage(lpMsg, Handle, wMsgFilterMin, wMsgFilterMax,
    wRemoveMsg);
end;

function TGtk3WidgetSet.PolyBezier(DC: HDC; Points: PPoint; NumPts: Integer;
  Filled, Continuous: boolean): boolean;
begin
  if not IsValidDC(DC) then
    exit(False);
  TGtk3DeviceContext(DC).drawPolyBezier(Points, NumPts, Filled, Continuous);
  Result:=True;
end;

function TGtk3WidgetSet.Polygon(DC: HDC; Points: PPoint; NumPts: Integer;
  Winding: boolean): boolean;
var
  NFillRule: integer;
  bFill, bBorder: boolean;
begin
  if not IsValidDC(DC) then
    exit(False);
  if Winding then
    NFillRule := Ord(CAIRO_FILL_RULE_WINDING)
  else
    NFillRule := Ord(CAIRO_FILL_RULE_EVEN_ODD);
  bFill := TGtk3DeviceContext(DC).CurrentBrush.Style <> BS_NULL;
  bBorder := TGtk3DeviceContext(DC).CurrentPen.Style <> psClear;
  TGtk3DeviceContext(DC).drawPolygon(Points, NumPts, NFillRule, bFill, bBorder);
  Result:= True;
end;

function TGtk3WidgetSet.Polyline(DC: HDC; Points: PPoint; NumPts: Integer): boolean;
begin
  if not IsValidDC(DC) then
    exit(False);
  if TGtk3DeviceContext(DC).CurrentPen.Style = psClear then Exit;
  TGtk3DeviceContext(DC).drawPolyLine(Points, NumPts);
  Result:=True;
end;


type
  PCustomGtk3Message = ^TCustomGtk3Message;
  TCustomGtk3Message = record
    Handle: HWND;
    Msg: Cardinal;
    AwParam: WParam;
    AlParam: LParam;
    Result: LRESULT;
  end;

function Gtk3ProcessPostMessage(user_data: gpointer): gboolean; cdecl;
var
  AMsg: TCustomGtk3Message;
  AMessage: TLMessage;
begin
  Result := False;
  if user_data <> nil then
  begin
    AMsg := TCustomGtk3Message(user_data^);
    if AMsg.Handle <> 0 then
    begin
      FillChar(AMessage{%H-}, SizeOf(AMessage), #0);
      AMessage.Msg := AMsg.Msg;
      AMessage.WParam := AMsg.AwParam;
      AMessage.LParam := AMsg.AlParam;
      TGtk3Widget(AMsg.Handle).DeliverMessage(AMessage);
    end;
    g_idle_remove_by_data(user_data);
    Freemem(user_data);
    user_data := nil;
    Result := True;
  end;
end;

function TGtk3WidgetSet.PostMessage(Handle: HWND; Msg: Cardinal;
  wParam: WParam; lParam: LParam): Boolean;
var
  AEvent: PCustomGtk3Message;
begin
  Result := False;
  if Handle <> 0 then
  begin
    AEvent := GetMem(SizeOf(TCustomGtk3Message));
    AEvent^.Handle := Handle;
    AEvent^.Msg := Msg;
    AEvent^.AwParam := wParam;
    AEvent^.AlParam := lParam;
    AEvent^.Result := 0;
    g_idle_add(@Gtk3ProcessPostMessage, AEvent);
    if GetCurrentThreadId <> MainThreadID then
    begin
      // writeln('TGtk3WidgetSet.PostMessage from different thread !');
      g_main_context_wakeup(g_main_context_default);
    end;
    Result := True;
  end;
end;

function TGtk3WidgetSet.PtInRegion(RGN: HRGN; X, Y: Integer): Boolean;
begin
  Result := False;
  if IsValidGDIObject(RGN) then
    Result := TGtk3Region(RGN).ContainsPoint(Point(X, Y));
end;

function TGtk3WidgetSet.RadialArc(DC: HDC; left, top, right, bottom, sx, sy,
  ex, ey: Integer): Boolean;
begin
  {$IFDEF GTK3DEBUGNOTIMPLEMENTED}
  DebugLn('WARNING: TGtk3WidgetSet.RadialArc not implemented ...');
  {$ENDIF}
  Result:=inherited RadialArc(DC, left, top, right, bottom, sx, sy, ex, ey);
end;

function TGtk3WidgetSet.RadialChord(DC: HDC; x1, y1, x2, y2, sx, sy, ex,
  ey: Integer): Boolean;
begin
  {$IFDEF GTK3DEBUGNOTIMPLEMENTED}
  DebugLn('WARNING: TGtk3WidgetSet.RadialChord not implemented ...');
  {$ENDIF}
  Result:=inherited RadialChord(DC, x1, y1, x2, y2, sx, sy, ex, ey);
end;

function TGtk3WidgetSet.RealizePalette(DC: HDC): Cardinal;
begin
  {$IFDEF GTK3DEBUGNOTIMPLEMENTED}
  DebugLn('WARNING: TGtk3WidgetSet.RealizePalette not implemented ...');
  {$ENDIF}
  Result := inherited RealizePalette(DC);
end;

function TGtk3WidgetSet.Rectangle(DC: HDC; X1, Y1, X2, Y2: Integer): Boolean;
var
  R: TRect;
  bFill, bBorder: Boolean;
begin
  if not IsValidDC(DC) then
    exit(False);
  R := NormalizeRect(Rect(X1, Y1, X2, Y2));
  if IsRectEmpty(R) then Exit(True);
  bFill := TGtk3DeviceContext(DC).CurrentBrush.Style <> BS_NULL;
  bBorder := TGtk3DeviceContext(DC).CurrentPen.Style <> psClear;
  TGtk3DeviceContext(DC).drawRect(R.Left, R.Top, R.Right - R.Left, R.Bottom - R.Top, bFill, bBorder);
  Result := True;
end;

function TGtk3WidgetSet.RectInRegion(RGN: HRGN; ARect: TRect): Boolean;
begin
  Result := False;
  if IsValidGDIObject(RGN) then
    Result := TGtk3Region(Rgn).ContainsRect(ARect);
end;

function TGtk3WidgetSet.RectVisible(dc: hdc; const ARect: TRect): Boolean;
var
  ACairoRegion: Pcairo_region_t;
  ACairoRect: Tcairo_rectangle_int_t;
begin
  {$IFDEF GTK3DEBUGNOTIMPLEMENTED}
  // DebugLn('WARNING: TGtk3WidgetSet.RectVisible not implemented ...');
  {$ENDIF}
  Result := False;
  if not IsValidDC(DC) then
    exit;
  if (TGtk3DeviceContext(DC).Parent <> nil) and
    Gtk3IsGdkWindow(TGtk3DeviceContext(DC).Parent^.window) then
  begin
    if not gdk_window_is_visible(TGtk3DeviceContext(DC).Parent^.window) then
      exit;
    ACairoRegion := gdk_window_get_visible_region(TGtk3DeviceContext(DC).Parent^.window);
  end else
    ACairoRegion := gdk_window_get_visible_region(gdk_get_default_root_window);
  ACairoRect.x := ARect.Left;
  ACairoRect.y := ARect.Top;
  ACairoRect.width := ARect.Right - ARect.Left;
  ACairoRect.height := ARect.Bottom - ARect.Top;
  Result := cairo_region_contains_rectangle(ACairoRegion, @ACairoRect) <> CAIRO_REGION_OVERLAP_OUT;
end;

function TGtk3WidgetSet.RegroupMenuItem(hndMenu: HMENU; GroupIndex: integer
  ): Boolean;
begin
  Result := False;
  {$IFDEF GTK3DEBUGNOTIMPLEMENTED}
  DebugLn('WARNING: TGtk3WidgetSet.RegroupMenuItem not implemented ...');
  {$ENDIF}
  // inherited RegroupMenuItem(hndMenu, GroupIndex);
end;

function TGtk3WidgetSet.ReleaseCapture: Boolean;
var
  AWidget: TGtk3Widget;
begin
  {$IFDEF VerboseGtk3WinApi}
  DebugLn('TGtk3WidgetSet.ReleaseCapture');
  {$ENDIF}
  AWidget := TGtk3Widget(GetCapture);
  Result := AWidget <> nil;
  if Result then
  begin
    if AWidget.Widget = nil then exit;
    if AWidget.GetContainerWidget^.has_grab then
      gtk_grab_remove(AWidget.GetContainerWidget)
    else
    if AWidget.Widget^.has_grab then
      gtk_grab_remove(AWidget.Widget);
  end;
end;

function TGtk3WidgetSet.ReleaseDC(hWnd: HWND; DC: HDC): Integer;
begin
  Result := 0;
  if IsValidDC(DC) then
  begin
    if TGtk3DeviceContext(DC).CanRelease then
      TGtk3DeviceContext(DC).Free;
    Result := 1;
  end;
end;

function TGtk3WidgetSet.RemoveProp(Handle: hwnd; Str: PChar): THandle;
begin
  Result := 0;
  if Handle = 0 then
    exit;
  if Gtk3IsObject(TGtk3Widget(Handle).Widget) then
    g_object_set_data(TGtk3Widget(Handle).Widget, Str, nil);
  if TGtk3Widget(Handle).GetContainerWidget <> TGtk3Widget(Handle).Widget then
  begin
    if Gtk3IsObject(TGtk3Widget(Handle).GetContainerWidget) then
      g_object_set_data(TGtk3Widget(Handle).GetContainerWidget, Str, nil);
  end;
  Result := 1;
end;

function TGtk3WidgetSet.RestoreDC(DC: HDC; SavedDC: Integer): Boolean;
begin
  {$IFDEF GTK3DEBUGNOTIMPLEMENTED}
  // DebugLn('WARNING: TGtk3WidgetSet.RestoreDC not implemented ...');
  {$ENDIF}
  Result := False;
  if not IsValidDC(DC) then
    exit;
  cairo_restore(TGtk3DeviceContext(DC).pcr);
  Result := True;
end;

function TGtk3WidgetSet.RoundRect(DC: hDC; X1, Y1, X2, Y2: Integer; RX,
  RY: Integer): Boolean;
begin
  Result := False;
  if not IsValidDC(DC) then
    exit;
  Result := TGtk3DeviceContext(DC).RoundRect(X1, Y1, X2, Y2, RX, RY);
end;

function TGtk3WidgetSet.SaveDC(DC: HDC): Integer;
begin
  {$IFDEF GTK3DEBUGNOTIMPLEMENTED}
  // DebugLn('WARNING: TGtk3WidgetSet.SaveDC not implemented ...');
  {$ENDIF}
  Result := 0;
  if not IsValidDC(DC) then
    exit;
  cairo_save(TGtk3DeviceContext(DC).pcr);
  Result := 1;
end;

function TGtk3WidgetSet.ScreenToClient(Handle: HWND; var P: TPoint): Integer;
begin
  Result := 0;
  {$ifdef VerboseGtk3WinApi}
  DebugLn('Trace:> [TGtk3WidgetSet.ScreenToClient] ',dbgs(P));
  {$endif}
  if not IsValidHandle(Handle) then
    exit;

  Result := TGtk3Widget(Handle).ScreenToClient(P);
end;

function TGtk3WidgetSet.ScrollWindowEx(hWnd: HWND; dx, dy: Integer; prcScroll,
  prcClip: PRect; hrgnUpdate: HRGN; prcUpdate: PRect; flags: UINT): Boolean;
begin
  {$IFDEF GTK3DEBUGNOTIMPLEMENTED}
  DebugLn('WARNING: TGtk3WidgetSet.ScrollWindowEx not implemented ...');
  {$ENDIF}
  Result:=inherited ScrollWindowEx(hWnd, dx, dy, prcScroll, prcClip,
    hrgnUpdate, prcUpdate, flags);
end;

function TGtk3WidgetSet.SelectClipRGN(DC: hDC; RGN: HRGN): Longint;
begin
  Result := 0;
  if IsValidDC(DC) then
  begin
    if IsValidGDIObject(RGN) then
      Result := TGtk3DeviceContext(DC).setClipRegion(TGtk3Region(RGN))
    else
      Result := TGtk3DeviceContext(DC).ResetClip;
  end;
end;

function TGtk3WidgetSet.SelectObject(DC: HDC; GDIObj: HGDIOBJ): HGDIOBJ;
begin
  Result := 0;
  if not IsValidDC(DC) then
    exit;
  if IsValidGDIObject(GDIObj) then
  begin
    Result:=HGDIOBJ(TGtk3ContextObject(GDIOBJ).Select(TGtk3DeviceContext(DC)));
  end;
end;

function TGtk3WidgetSet.SelectPalette(DC: HDC; Palette: HPALETTE;
  ForceBackground: Boolean): HPALETTE;
begin
  {$IFDEF GTK3DEBUGNOTIMPLEMENTED}
  DebugLn('WARNING: TGtk3WidgetSet.SelectPalette not implemented ...');
  {$ENDIF}
  Result := inherited SelectPalette(DC, Palette, ForceBackground);
end;

function TGtk3WidgetSet.SendMessage(HandleWnd: HWND; Msg: Cardinal;
  wParam: WParam; lParam: LParam): LResult;
begin
  {$IFDEF GTK3DEBUGNOTIMPLEMENTED}
  DebugLn('WARNING: TGtk3WidgetSet.SendMessage not implemented ...');
  {$ENDIF}
  Result := inherited SendMessage(HandleWnd, Msg, wParam, lParam);
end;

function TGtk3WidgetSet.SetActiveWindow(Handle: HWND): HWND;
begin
  Result := GetActiveWindow;
  if Handle <> 0 then
  begin
    if wtWindow in TGtk3Widget(Handle).WidgetType then
      PGtkWindow(TGtk3Window(Handle).Widget)^.present;
  end;
end;

function TGtk3WidgetSet.SetBkColor(DC: HDC; Color: TColorRef): TColorRef;
begin
  {$IFDEF GTK3DEBUGNOTIMPLEMENTED}
  // DebugLn('WARNING: TGtk3WidgetSet.SetBkColor not implemented ...');
  {$ENDIF}
  Result := clNone;
  if not IsValidDC(DC) then
    exit;
  Result := TGtk3DeviceContext(DC).CurrentBrush.Color;
  TGtk3DeviceContext(DC).CurrentBrush.Color := TColor(ColorToRGB(TColor(Color)));
end;

function TGtk3WidgetSet.SetBkMode(DC: HDC; bkMode: Integer): Integer;
begin
  {.$IFDEF GTK3DEBUGNOTIMPLEMENTED}
  // DebugLn('WARNING: TGtk3WidgetSet.SetBkMode not implemented ...', dbgs(BkMode));
  {.$ENDIF}
  Result := 0;
  if not IsValidDC(DC) then
    exit;
  Result := TGtk3DeviceContext(DC).BkMode;
  TGtk3DeviceContext(DC).BkMode := bkMode;
  // if cairo_pattern_get_type(cairo_get_source(TGtk3DeviceContext(DC).Widget)) = CAIRO_PATTERN_TYPE_SURFACE then
  //  Result := TRANSPARENT;
  // we must use TGtk3Brush.Handle = Pcairo_pattern_t
  // cairo_pattern_get_type(nil).CAIRO_PATTERN_TYPE_SOLID;
  // cairo_get_source();
end;

function TGtk3WidgetSet.SetCapture(AHandle: HWND): HWND;
var
  Message: TLMessage;
begin
  {$IFDEF VerboseGtk3WinApi}
  DebugLn('TGtk3WidgetSet.SetCapture');
  {$ENDIF}
  Result := GetCapture;
  if Result <> AHandle then
  begin
    if Result <> 0 then
      ReleaseCapture;
    if IsValidHandle(AHandle) then
    begin
      TGtk3Widget(AHandle).SetCapture;
      //if (Result <> 0) then
      begin
        Message.Msg := 0;
        FillChar(Message, SizeOf(Message), 0);
        Message.msg := LM_CAPTURECHANGED;
        Message.wParam := 0;
        Message.lParam := PtrInt(Result);
        LCLMessageGlue.DeliverMessage(TGtk3Widget(AHandle).LCLObject, Message);
      end;
    end;
  end;
end;

function TGtk3WidgetSet.SetCaretPos(X, Y: Integer): Boolean;
begin
  {$IFDEF GTK3DEBUGNOTIMPLEMENTED}
  DebugLn('WARNING: TGtk3WidgetSet.SetCaretPos not implemented ...');
  {$ENDIF}
  Result:=inherited SetCaretPos(X, Y);
end;

function TGtk3WidgetSet.SetCaretPosEx(Handle: HWnd; X, Y: Integer): Boolean;
begin
  {$IFDEF GTK3DEBUGNOTIMPLEMENTED}
  DebugLn('WARNING: TGtk3WidgetSet.SetCaretPosEx not implemented ...');
  {$ENDIF}
  Result:=inherited SetCaretPosEx(Handle, X, Y);
end;

function TGtk3WidgetSet.SetCaretRespondToFocus(handle: HWND;
  ShowHideOnFocus: boolean): Boolean;
begin
  {$IFDEF GTK3DEBUGNOTIMPLEMENTED}
  DebugLn('WARNING: TGtk3WidgetSet.SetCaretRespondToFocus not implemented ...');
  {$ENDIF}
  Result:=inherited SetCaretRespondToFocus(handle, ShowHideOnFocus);
end;

function TGtk3WidgetSet.SetCursor(ACursor: HCURSOR): HCURSOR;
begin
  {$IFDEF GTK3DEBUGNOTIMPLEMENTED}
  // DebugLn('WARNING: TGtk3WidgetSet.SetCursor not implemented ...');
  {$ENDIF}
  Result := FGlobalCursor;
  if ACursor = FGlobalCursor then Exit;
  if ACursor = Screen.Cursors[crDefault]
  then SetGlobalCursor(0)
  else SetGlobalCursor(ACursor);
  FGlobalCursor := ACursor;
end;

function TGtk3WidgetSet.SetCursorPos(X, Y: Integer): Boolean;
var
  ADeviceManager: PGdkDeviceManager;
  APointer: PGdkDevice;
begin
  ADeviceManager := gdk_display_get_device_manager(gdk_display_get_default);
  APointer := gdk_device_manager_get_client_pointer(ADeviceManager);
  // howto get what screen we are querying on ?
  // gdk_display_get_screen(gdk_display_get_default, 0);
  gdk_device_warp(APointer, gdk_screen_get_default, X, Y);
  Result := True;
end;

function TGtk3WidgetSet.SetFocus(hWnd: HWND): HWND;
begin
  Result := GetFocus;
  if hWnd <> 0 then
  begin
    {$IFDEF GTK3DEBUGFOCUS}
    if Result <> 0 then
      DebugLn('TGtk3WidgetSet.SetFocus: ',dbgsName(TGtk3Widget(HWND).LCLObject),' oldFocus ',dbgsName(TGtk3Widget(Result).LCLObject))
    else
      DebugLn('TGtk3WidgetSet.SetFocus: ',dbgsName(TGtk3Widget(HWND).LCLObject),' oldFocus 0');
    {$ENDIF}
    TGtk3Widget(HWND).setFocus;
  end;
end;

function TGtk3WidgetSet.SetForegroundWindow(hWnd: HWND): boolean;
var
  AWindow: TGtk3Window;
begin
  {$IFDEF GTK3DEBUGNOTIMPLEMENTED}
  // DebugLn('WARNING: TGtk3WidgetSet.SetForegroundWindow not implemented ...');
  {$ENDIF}
  if not IsValidHandle(HWnd) then
    exit(False);
  Result := wtWindow in TGtk3Widget(HWND).WidgetType;
  if Result then
  begin
    AWindow := TGtk3Window(HWND);
    if not AWindow.Visible then
      exit(False);
    // DebugLn('TGtk3WidgetSet.SetForegroundWindow ',dbgsName(AWindow.LCLObject));
    AWindow.Activate;
    Result := True;
  end;
end;

function TGtk3WidgetSet.SetMapMode(DC: HDC; fnMapMode: Integer): Integer;
begin
  {$IFDEF GTK3DEBUGNOTIMPLEMENTED}
  DebugLn('WARNING: TGtk3WidgetSet.SetMapMode not implemented ...');
  {$ENDIF}
  Result:=inherited SetMapMode(DC, fnMapMode);
end;

function TGtk3WidgetSet.SetParent(hWndChild: HWND; hWndParent: HWND): HWND;
begin
  Result := HWND(TGtk3Widget(hWndChild).getParent);
  TGtk3Widget(hWndChild).SetParent(TGtk3Widget(hWndParent),0,0)
end;

function TGtk3WidgetSet.SetProp(Handle: hwnd; Str: PChar; Data: Pointer
  ): Boolean;
begin
  if Handle = 0 then
    exit(False);
  if Gtk3IsObject(TGtk3Widget(Handle).Widget) then
    g_object_set_data(TGtk3Widget(Handle).Widget, Str, Data);
  if TGtk3Widget(Handle).GetContainerWidget <> TGtk3Widget(Handle).Widget then
  begin
    if Gtk3IsObject(TGtk3Widget(Handle).GetContainerWidget) then
      g_object_set_data(TGtk3Widget(Handle).GetContainerWidget, Str, Data);
  end;
  Result := True;
end;

function TGtk3WidgetSet.SetRectRgn(aRGN: HRGN; X1, Y1, X2, Y2: Integer
  ): Boolean;
begin
  {$IFDEF GTK3DEBUGNOTIMPLEMENTED}
  DebugLn('WARNING: TGtk3WidgetSet.SetRectRgn not implemented ...');
  {$ENDIF}
  Result:=inherited SetRectRgn(aRGN, X1, Y1, X2, Y2);
end;

function TGtk3WidgetSet.SetROP2(DC: HDC; Mode: Integer): Integer;
begin
  {$IFDEF GTK3DEBUGNOTIMPLEMENTED}
  DebugLn('WARNING: TGtk3WidgetSet.SetROP2 not implemented ...');
  {$ENDIF}
  Result:=inherited SetROP2(DC, Mode);
end;

function TGtk3WidgetSet.SetScrollInfo(Handle: HWND; SBStyle: Integer;
  ScrollInfo: TScrollInfo; bRedraw: Boolean): Integer;

  (*

  procedure SetRangeUpdatePolicy(Range: PGtkRange);
  var
    UpdPolicy: TGTKUpdateType;
  begin
    case ScrollInfo.nTrackPos of
      SB_POLICY_DISCONTINUOUS: UpdPolicy := GTK_UPDATE_DISCONTINUOUS;
      SB_POLICY_DELAYED:  UpdPolicy := GTK_UPDATE_DELAYED;
      else
        UpdPolicy := GTK_UPDATE_CONTINUOUS;
    end;
    !!! update policy for gtkRange does not exist anymore in gtk3
    so we must mimic that by using events. !!!
    gtk_range_set_update_policy(Range, UpdPolicy);
  end;
  procedure SetScrolledWindowUpdatePolicy(ScrolledWindow:PGTKScrolledWindow);
  var
    Range: PGtkRange;
  begin
    case SBStyle of
      SB_VERT: Range := PGtkRange(ScrolledWindow^.vscrollbar);
      SB_HORZ: Range := PGtkRange(ScrolledWindow^.hscrollbar);
      else exit;
    end;
    SetRangeUpdatePolicy(Range);
  end;
  *)

const
  POLICY: array[BOOLEAN] of TGTKPolicyType = (2, 0); // GTK_POLICY_NEVER, GTK_POLICY_ALWAYS);

var
  Adjustment: PGtkAdjustment;
  AWidget: TGtk3Widget;
  ARange: PGtkRange;
  AScrollWin: PGtkScrolledWindow;
  IsScrollbarVis: Boolean;
begin
  Result := 0;
  if not IsValidHandle(Handle) then
    exit;

  AWidget := TGtk3Widget(Handle);

  Adjustment := nil;
  ARange := nil;
  AScrollWin := nil;

  if wtScrollBar in AWidget.WidgetType then
  begin
    ARange := PGtkRange(AWidget.Widget);
    Adjustment := ARange^.adjustment;
  end else
  if wtScrollingWin in AWidget.WidgetType then
  begin
    AScrollWin := TGtk3ScrollableWin(Handle).GetScrolledWindow;
    if AScrollWin = nil then
      exit;
    if not Gtk3IsScrolledWindow(AScrollWin) then
    begin
      DebugLn('ERROR: TGtk3WidgetSet.SetScrollInfo: Wrong class extracted for scrollwin ',dbgsName(TGtk3Widget(Handle).LCLObject));
      AScrollWin := nil;
    end;
  end;

  case SBStyle of
    SB_Horz:
    begin
      if not Assigned(Adjustment) and Assigned(AScrollWin) then
        Adjustment := AScrollWin^.get_hadjustment;
    end;
    SB_Vert:
    begin
      if not Assigned(Adjustment) and Assigned(AScrollWin) then
        Adjustment := AScrollWin^.get_vadjustment;
    end;
    SB_CTL:
    begin
      DebugLn('TGtk3WidgetSet.SetScrollInfo SB_CTL error: not implemented ',
        dbgsName(AWidget.LCLObject));
    end;
    SB_BOTH:
    begin
      DebugLn('TGtk3WidgetSet.SetScrollInfo SB_BOTH error: not implemented  ',
        dbgsName(AWidget.LCLObject));
    end;
  end;

  if Adjustment = nil then
  begin
    DebugLn('TGtk3WidgetSet.SetScrollInfo error: cannot get PGtkAdjustment from ',
      dbgsName(AWidget.LCLObject));
    exit;
  end;

  if (ScrollInfo.fMask and SIF_RANGE) <> 0 then
  begin
    Adjustment^.lower := ScrollInfo.nMin;
    Adjustment^.upper := ScrollInfo.nMax;
  end;
  if (ScrollInfo.fMask and SIF_PAGE) <> 0 then
  begin
    // 0 <= nPage <= nMax-nMin+1
    Adjustment^.page_size := ScrollInfo.nPage;
    Adjustment^.page_size := Min(Max(Adjustment^.page_size,0),
                                 Adjustment^.upper-Adjustment^.lower+1);
    Adjustment^.page_increment := (Adjustment^.page_size/6)+1;
  end;
  if (ScrollInfo.fMask and SIF_POS) <> 0 then
  begin
    // nMin <= nPos <= nMax - Max(nPage-1,0)
    Adjustment^.value := ScrollInfo.nPos;
    Adjustment^.value := Max(Adjustment^.value,Adjustment^.lower);
    Adjustment^.value := Min(Adjustment^.value,
                              Adjustment^.upper-Max(Adjustment^.page_size-1,0));
  end;

  // check if scrollbar should be hidden
  IsScrollbarVis := True;
  if ((ScrollInfo.fMask and (SIF_RANGE or SIF_PAGE)) <> 0) and
     ((SBStyle=SB_HORZ) or (SBStyle=SB_VERT)) then
  begin
    if (Adjustment^.lower >= (Adjustment^.upper-Max(adjustment^.page_size-1,0)))
    then begin
      if (ScrollInfo.fMask and SIF_DISABLENOSCROLL) = 0 then
        IsScrollbarVis := False
      else
        ;// scrollbar should look disabled (no thumbbar and grayed appearance)
         // maybe not possible in gtk
    end;
  end;
  if bRedraw then
  begin
    if (AScrollWin <> nil) then
    begin
      // DebugLn('Setting scrollstyle of ',dbgsName(AWidget.LCLObject));
      if SBStyle = SB_HORZ then
        TGtk3ScrollableWin(AWidget).HScrollBarPolicy := POLICY[IsScrollbarVis]
      else
      if SBStyle = SB_VERT then
        TGtk3ScrollableWin(AWidget).VScrollBarPolicy := POLICY[IsScrollbarVis];
    end else
      AWidget.Update(nil);

    Adjustment^.changed;

  end;
  Result := Round(Adjustment^.value);
end;

function TGtk3WidgetSet.SetSysColors(cElements: Integer; const lpaElements;
  const lpaRgbValues): Boolean;
begin
  Result:=inherited SetSysColors(cElements, lpaElements, lpaRgbValues);
end;

function TGtk3WidgetSet.SetTextCharacterExtra(DC: hdc; nCharExtra: Integer
  ): Integer;
begin
  Result:=inherited SetTextCharacterExtra(DC, nCharExtra);
end;

function TGtk3WidgetSet.SetTextColor(DC: HDC; Color: TColorRef): TColorRef;
begin
  {$IFDEF GTK3DEBUGNOTIMPLEMENTED}
  // DebugLn('WARNING: TGtk3WidgetSet.SetTextColor not implemented ...');
  {$ENDIF}
  Result := CLR_INVALID;
  if IsValidDC(DC) then
  begin
    Result := TGtk3DeviceContext(DC).CurrentTextColor;
    TGtk3DeviceContext(DC).CurrentTextColor := Color;
  end;
end;

function TGtk3WidgetSet.SetViewPortExtEx(DC: HDC; XExtent, YExtent: Integer;
  OldSize: PSize): Boolean;
begin
  {$IFDEF GTK3DEBUGNOTIMPLEMENTED}
  DebugLn('WARNING: TGtk3WidgetSet.SetViewPortExtEx not implemented ...');
  {$ENDIF}
  Result:=inherited SetViewPortExtEx(DC, XExtent, YExtent, OldSize);
end;

function TGtk3WidgetSet.SetViewPortOrgEx(DC: HDC; NewX, NewY: Integer;
  OldPoint: PPoint): Boolean;
begin
  {$IFDEF GTK3DEBUGNOTIMPLEMENTED}
  DebugLn('WARNING: TGtk3WidgetSet.SetViewPortOrgEx not implemented ...');
  {$ENDIF}
  Result:=inherited SetViewPortOrgEx(DC, NewX, NewY, OldPoint);
end;

function TGtk3WidgetSet.SetWindowExtEx(DC: HDC; XExtent, YExtent: Integer;
  OldSize: PSize): Boolean;
begin
  {$IFDEF GTK3DEBUGNOTIMPLEMENTED}
  DebugLn('WARNING: TGtk3WidgetSet.SetWindowExtEx not implemented ...');
  {$ENDIF}
  Result:=inherited SetWindowExtEx(DC, XExtent, YExtent, OldSize);
end;

function TGtk3WidgetSet.SetWindowLong(Handle: HWND; Idx: Integer;
  NewLong: PtrInt): PtrInt;
begin
  {$IFDEF GTK3DEBUGNOTIMPLEMENTED}
  DebugLn('WARNING: TGtk3WidgetSet.SetWindowLong not implemented ...');
  {$ENDIF}
  Result:=inherited SetWindowLong(Handle, Idx, NewLong);
end;

function TGtk3WidgetSet.SetWindowOrgEx(dc: hdc; NewX, NewY: Integer;
  OldPoint: PPoint): Boolean;
var
  Matrix: cairo_matrix_t;
  //dx, dy: Double;
begin
  Result := False; // inherited SetWindowOrgEx(dc, NewX, NewY, OldPoint);
  if IsValidDC(DC) then
  begin
    GetWindowOrgEx(dc, OldPoint);
    cairo_get_matrix(TGtk3DeviceContext(DC).pcr, @Matrix);
    //dx := 0;
    //dy := 0;
    // cairo_matrix_init_translate(Matrix, -NewX, -NewY);
    cairo_matrix_translate(@Matrix,
    	-NewX - TGtk3DeviceContext(DC).fncOrigin.x,
        -NewY - TGtk3DeviceContext(DC).fncOrigin.Y);
    cairo_transform(TGtk3DeviceContext(DC).pcr, @Matrix);
    // cairo_set_matrix(TGtk3DeviceContext(DC).Widget, Matrix);
    // DebugLn('TGtk3WidgetSet.SetWindowOrgEx NewX=',dbgs(NewX),' NewY=',dbgs(NewY));
    Result := True;

  end;
end;

function TGtk3WidgetSet.SetWindowPos(hWnd: HWND; hWndInsertAfter: HWND; X, Y,
  cx, cy: Integer; uFlags: UINT): Boolean;
begin
  Result := False;
  {$IFDEF GTK3DEBUGNOTIMPLEMENTED}
  DebugLn('WARNING: TGtk3WidgetSet.SetWindowPos not implemented Handle=',dbgHex(hWnd),' X=',dbgs(X),' Y=',dbgs(Y));
  {$ENDIF}
end;

function TGtk3WidgetSet.SetWindowRgn(hWnd: HWND; hRgn: HRGN; bRedraw: Boolean
  ): longint;
var
  PCR: Pcairo_region_t;
begin
  if hRgn = 0 then
    PCR := nil
  else
    PCR := TGtk3Region(hRgn).Handle;
  gtk_widget_shape_combine_region(TGtk3Widget(hWnd).Widget, PCR);
  if bRedraw then
    TGtk3Widget(hWnd).Widget^.realize;
  Result:=1;
end;

function TGtk3WidgetSet.ShowCaret(hWnd: HWND): Boolean;
begin
  {$IFDEF GTK3DEBUGNOTIMPLEMENTED}
  DebugLn('WARNING: TGtk3WidgetSet.ShowCaret not implemented ...');
  {$ENDIF}
  Result:=inherited ShowCaret(hWnd);
end;

function TGtk3WidgetSet.ShowScrollBar(Handle: HWND; wBar: Integer;
  bShow: Boolean): Boolean;
var
  AWidget: TGtk3Widget;
  // AScrolledWin: PGtkScrolledWindow;
  NewPolicy: TGtkPolicyType;
begin
  Result := IsValidHandle(Handle);
  if not Result then
    exit;
  AWidget := TGtk3Widget(Handle);
  if wtScrollBar in AWidget.WidgetType then
  begin
    AWidget.Visible := bShow;
  end else
  (*
  if wtWindow in AWidget.WidgetType then
  begin
    DebugLn('WARNING: TGtk3WidgetSet.ShowScrollBar cannot get scrollbar from ',dbgsName(AWidget.LCLObject),
    ' bShow ',dbgs(bShow));
  end else
  *)
  if wtScrollingWin in AWidget.WidgetType then
  begin
    // AScrolledWin :=
    if TGtk3ScrollableWin(Handle).GetScrolledWindow = nil then
      exit;
    if wBar in [SB_BOTH, SB_HORZ] then
    begin
      if bShow then
        NewPolicy := GTK_POLICY_ALWAYS
      else
        NewPolicy := GTK_POLICY_NEVER;

      // bug in gtk3
      if (wtWindow in AWidget.WidgetType) and (NewPolicy = GTK_POLICY_NEVER) then
        NewPolicy := GTK_POLICY_AUTOMATIC;

      TGtk3ScrollableWin(AWidget).HScrollBarPolicy := NewPolicy;
    end;
    if wBar in [SB_BOTH, SB_VERT] then
    begin
      if bShow then
        NewPolicy := GTK_POLICY_ALWAYS
      else
        NewPolicy := GTK_POLICY_NEVER;

      // bug in gtk3
      if (wtWindow in AWidget.WidgetType) and (NewPolicy = GTK_POLICY_NEVER) then
        NewPolicy := GTK_POLICY_AUTOMATIC;

      TGtk3ScrollableWin(AWidget).VScrollBarPolicy := NewPolicy;
    end;
  end else
    DebugLn('WARNING: TGtk3WidgetSet.ShowScrollBar cannot get scrollbar from ',dbgsName(AWidget.LCLObject));
end;

function TGtk3WidgetSet.ShowWindow(hWnd: HWND; nCmdShow: Integer): Boolean;
begin
  {$IFDEF GTK3DEBUGNOTIMPLEMENTED}
  DebugLn('WARNING: TGtk3WidgetSet.ShowWindow not implemented ...');
  {$ENDIF}
  Result := IsValidHandle(Hwnd);
  if not result then exit;
  if TObject(hWnd) is TGtk3Window then
    Result:=TGtk3Window(hWnd).ShowState(nCmdShow)
  else
  begin
    TGtk3Widget(hWnd).Show;
    Result:=true;
  end;
end;

function TGtk3WidgetSet.StretchBlt(DestDC: HDC; X, Y, Width, Height: Integer;
  SrcDC: HDC; XSrc, YSrc, SrcWidth, SrcHeight: Integer; ROp: Cardinal): Boolean;
begin
  Result := StretchMaskBlt(DestDC,X,Y,Width,Height,
                          SrcDC,XSrc,YSrc,SrcWidth,SrcHeight,
                          0,0,0,
                          ROp);
end;

function TGtk3WidgetSet.StretchMaskBlt(DestDC: HDC; X, Y, Width,
  Height: Integer; SrcDC: HDC; XSrc, YSrc, SrcWidth, SrcHeight: Integer;
  Mask: HBITMAP; XMask, YMask: Integer; Rop: DWORD): Boolean;

var
  DestContext: TGtk3DeviceContext absolute DestDC;
  SrcContext: TGtk3DeviceContext absolute SrcDC;
  ATargetRect, ASrcRect: TRect;
begin
  Result := False;
  {$IFDEF GTK3DEBUGNOTIMPLEMENTED}
  DebugLn('WARNING: TGtk3WidgetSet.StretchMaskBlt not implemented ...');
  {$ENDIF}
  ATargetRect := Rect(X, Y, Width + X, Height + Y);
  ASrcRect := Rect(XSrc, YSrc, SrcWidth + XSrc, SrcHeight + YSrc);

  if (DestContext.OwnsSurface) and (SrcContext.OwnsSurface)  or (mask<>0) then
    DestContext.drawImage1(@ATargetRect, PgdkPixbuf(SrcContext.CurrentImage.Handle) , @ASrcRect, nil, nil)
  else
    DestContext.drawSurface(@ATargetRect,SrcContext.CairoSurface , @ASrcRect, nil, nil);

  Result := True;
end;

function TGtk3WidgetSet.SystemParametersInfo(uiAction: DWord; uiParam: DWord;
  pvParam: Pointer; fWinIni: DWord): LongBool;
var
  wa:TGdkRectangle;
  pdisp:PGdkDisplay;
  pmon:PgdkMonitor;
  pr:PRect;
begin
  Result:=True;
  Case uiAction of
    SPI_GETWHEELSCROLLLINES: PDword(pvParam)^ := 3;
    SPI_GETWORKAREA: begin
      pdisp:=TGdkDisplay.get_default;
      pmon:=pdisp^.get_primary_monitor();
      pmon^.get_workarea(@wa);
      pr:=PRect(pvParam);
      pr^.Left:=wa.x;
      pr^.Top:=wa.y;
      pr^.Width:=wa.width;
      pr^.Height:=wa.height;
    end;
  else
    Result:=False;
  end;
end;

function TGtk3WidgetSet.TextOut(DC: HDC; X, Y: Integer; Str: PChar; Count: Integer): Boolean;
begin
  {$IFDEF VerboseGtk3DeviceContext}
  DebugLn('TGtk3WidgetSet.TextOut X=',dbgs(x),' Y=',dbgs(y),' Text=',dbgs(Str),' Count=',dbgs(Count));
  {$ENDIF}
  Result := False;
  if Count <= 0 then
    Exit;
  if IsValidDC(DC) then
  begin
    Result := True;
    TGtk3DeviceContext(DC).drawText(X, Y, Str, Count);
  end;
end;

function TGtk3WidgetSet.UpdateWindow(Handle: HWND): Boolean;
begin
  {$ifdef VerboseGtk3WinAPI}
  DebugLn('[Gtk3WinAPI UpdateWindow]');
  {$endif}
  Result := False;
  if IsValidHandle(Handle) then
  begin
    TGtk3Widget(Handle).Update(nil);
    if TGtk3Widget(Handle).GetContainerWidget^.get_has_window then
    begin
      if Gtk3IsGdkWindow(TGtk3Widget(Handle).GetContainerWidget^.window) then
        TGtk3Widget(Handle).GetContainerWidget^.window^.process_updates(True);
    end else
    if TGtk3Widget(Handle).Widget^.get_has_window then
    begin
      if Gtk3IsGdkWindow(TGtk3Widget(Handle).Widget^.window) then
        TGtk3Widget(Handle).Widget^.window^.process_updates(True);
    end;
    Result := True;
  end;
end;

function TGtk3WidgetSet.WindowFromPoint(APoint: TPoint): HWND;
var
  ev: TGdkEvent;
  ADeviceManager: PGdkDeviceManager;
  APointer: PGdkDevice;
  AWindow: PGdkWindow;
  AWidget: PGtkWidget;
  x: gint;
  y: gint;
begin
  //TODO: create caching mechanism. window_at_position is pretty expensive call.
  Result := 0;
  ADeviceManager := gdk_display_get_device_manager(gdk_display_get_default);
  APointer := gdk_device_manager_get_client_pointer(ADeviceManager);
  APointer^.get_position(nil, @x ,@y);
  AWindow := gdk_device_get_window_at_position(APointer, @APoint.X, @APoint.Y);
  if AWindow <> nil then
  begin
    FillChar(ev{%H-}, SizeOf(ev), 0);
    ev.any.window := AWindow;
    AWidget := gtk_get_event_widget(@ev);
    Result := HwndFromGtkWidget(AWidget);
    (*
    if Result <> 0 then
    begin
      DebugLn('TGtk3WidgetSet.WindowFromPoint ',dbgsName(TGtk3Widget(Result).LCLObject));
    end else
      DebugLn('Cannot find window under point ',dbgs(APoint));
    *)
  end;
end;

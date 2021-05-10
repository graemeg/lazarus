{%MainUnit gtk3int.pas}

{******************************************************************************
                 All GTK3 interface communication implementations.

 *****************************************************************************
  This file is part of the Lazarus Component Library (LCL)

  See the file COPYING.modifiedLGPL.txt, included in this distribution,
  for details about the license.
 *****************************************************************************
}


//##apiwiz##sps##   // Do not remove

function TGtk3WidgetSet.CreateRubberBand(const ARect: TRect; const ABrush: HBrush): HWND;
var
  Widget: PGtkWidget absolute Result;
  dx, dy: integer;
begin
  dx := ARect.Right - ARect.Left;
  dy := ARect.Bottom - ARect.Top;
  if dx < 0 then
    dx := 0;
  if dy < 0 then
    dy := 0;

  // rubber band is just a window without a title
  Result := {%H-}HWND(gtk_window_new(GTK_WINDOW_TOPLEVEL));
  gtk_window_set_default_size({%H-}PGtkWindow(Result), dx, dy);

  gtk_widget_realize(Widget);

  gdk_window_set_decorations(Widget^.window, 0);
  gdk_window_set_functions(Widget^.window, GDK_FUNC_RESIZE or GDK_FUNC_CLOSE);
  gtk_widget_set_opacity(Widget, 0.25);

  gtk_widget_show(Widget);
end;

procedure TGtk3WidgetSet.DestroyRubberBand(ARubberBand: HWND);
begin
  gtk_widget_destroy({%H-}PGtkWidget(ARubberBand));
end;

procedure TGtk3WidgetSet.DrawDefaultDockImage(AOldRect, ANewRect: TRect;
  AOperation: TDockImageOperation);
//const
//  LineWidth = 2;
var
  dx, dy: integer;
  (*
  Mask: PGdkBitmap;
  gc: PGdkGC;
  AColor: TGdkColor;
  Colormap: PGdkColormap;
  Screen: PGdkScreen;
  *)
begin
  dx := ANewRect.Right - ANewRect.Left;
  dy := ANewRect.Bottom - ANewRect.Top;
  if dx < 0 then
    dx := 0;
  if dy < 0 then
    dy := 0;
  (*
  if FDockImage = nil then
  begin
    // dock image is just a window without title
    FDockImage := gtk_window_new(GTK_WINDOW_POPUP);
    gtk_window_set_default_size(PGtkWindow(FDockImage),
      dx, dy);
    gtk_widget_realize(FDockImage);
    gdk_window_set_decorations(FDockImage^.window, 0);
    gdk_window_set_functions(FDockImage^.window, GDK_FUNC_RESIZE or GDK_FUNC_CLOSE);
    SetWidgetColor(FDockImage, clNone, clGradientActiveCaption, [GTK_STATE_NORMAL]);
    // attemp to make window semi-transparent
    Screen := gtk_widget_get_screen(FDockImage);
    Colormap := gdk_screen_get_rgba_colormap(Screen);
    if (Colormap <> nil) and gdk_screen_is_composited(Screen) then
      gtk_widget_set_colormap(FDockImage, Colormap);
  end;

  gdk_window_move_resize(FDockImage^.window, ANewRect.Left, ANewRect.Top,
    dx, dy);
  if (dx > 0) and (dy > 0) then
  begin
    // create a hole inside window
    Mask := gdk_pixmap_new(nil, dx, dy, 1);
    gc := gdk_gc_new(Mask);
    AColor.pixel := 1;
    gdk_gc_set_foreground(gc, @AColor);
    gdk_draw_rectangle(Mask, gc, 1, 0, 0, dx, dy);
    AColor.pixel := 0;
    gdk_gc_set_foreground(gc, @AColor);
    gdk_draw_rectangle(Mask, gc, 1, LineWidth, LineWidth,
      dx - LineWidth * 2, dy - LineWidth * 2);
    gdk_gc_unref(gc);
    gtk_widget_shape_combine_mask(FDockImage, Mask, 0, 0);
    gdk_pixmap_unref(Mask);
  end;
  case AOperation of
    disShow: gtk_widget_show(FDockImage);
    disHide: gtk_widget_hide(FDockImage);
  end;
  *)
end;

procedure TGtk3WidgetSet.DrawGrid(DC: HDC; const R: TRect; DX, DY: Integer);
var
  X, Y: Integer;
  W, H: Integer;
  SavedDC: Integer;
begin
  SavedDC := SaveDC(DC);
  try
    W := (R.Right - R.Left - 1) div DX;
    H := (R.Bottom - R.Top - 1) div DY;

    // remove rows from clip rect
    for Y := 0 to H do
    begin
      ExcludeClipRect(DC, R.Left, R.Top + Y * DY + 1, R.Right + 1, R.Top + (Y + 1) * DY);
    end;

    // draw vertical lines cross excluded rows -> only grid cross points painted
    for X := 0 to W do
    begin
      if MoveToEx(DC, R.Left + X * DX, R.Top, nil) then
        LineTo(DC, R.Left + X * DX, R.Bottom + 1);
    end;
  finally
    RestoreDC(DC, SavedDC);
  end;
end;


{------------------------------------------------------------------------------
  function TGtk3WidgetSet.ExtUTF8Out(DC: HDC; X, Y: Integer; Options: Longint;
    Rect: PRect; Str: PChar; Count: Longint; Dx: PInteger): Boolean;

  As ExtTextOut except that Str is treated as UTF8
 ------------------------------------------------------------------------------}
function TGtk3WidgetSet.ExtUTF8Out(DC: HDC; X, Y: Integer; Options: Longint;
  Rect: PRect; Str: PChar; Count: Longint; Dx: PInteger): Boolean;
begin
  // all fonts are UTF-8 under gtk2 => no mapping needed
  Result:=ExtTextOut(DC,X,Y,Options,Rect,Str,Count,Dx);
end;

function TGtk3WidgetSet.TextUTF8Out(DC: HDC; X, Y: Integer; Str: PChar; Count: Longint): Boolean;
begin
  // all fonts are UTF-8 under gtk3 => no mapping needed
  Result := TextOut(DC, X, Y, Str, Count);
end;

{------------------------------------------------------------------------------
  function TGtk3WidgetSet.FontIsMonoSpace(Font: HFont): boolean;

  True if font characters have all the same width.
 ------------------------------------------------------------------------------}
function TGtk3WidgetSet.FontIsMonoSpace(Font: HFont): boolean;
begin
  Result := False;
  // IsValidGDIObject(Font)
  //        and FontIsMonoSpaceFont({%H-}PGdiObject(Font)^.GDIFontObject);
end;

{------------------------------------------------------------------------------
  Function: GetAcceleratorString
  Params: AVKey:
          AShiftState:
  Returns:

 ------------------------------------------------------------------------------}
function TGtk3WidgetSet.GetAcceleratorString(const AVKey: Byte;
  const AShiftState: TShiftState): String;
begin
  Result:=inherited GetAcceleratorString(AVKey,AShiftState);
end;



{------------------------------------------------------------------------------
  Function: RawImage_CreateBitmap
  Params: ARawImage:
          ABitmap:
          AMask:
          ASkipMask: When set, no mask is created
  Returns:

 ------------------------------------------------------------------------------}
function TGtk3WidgetSet.RawImage_CreateBitmaps(const ARawImage: TRawImage; out
  ABitmap, AMask: HBitmap; ASkipMask: boolean): boolean;
var
  Desc: TRawImageDescription absolute ARawImage.Description;
  NewData: PByte;
  ImageFormat: cairo_format_t;
  ARowStride: PtrUInt;
  x,y:integer;
  src,dst,SrcRowPtr,DstRowPtr:pbyte;
  ridx,gidx,bidx,aidx:byte;
begin
  Result := False;
  ABitmap := 0;
  AMask := 0;

  if ARawImage.DataSize > 0 then
  begin
    case Desc.LineEnd of
    rileQWordBoundary:
      begin
        ARowStride := Desc.Width;
        if Desc.Width and 1 <> 0 then Inc(ARowStride);
        ARowStride := ARowStride shl 2;
      end;
    rileDQWordBoundary:
      begin
        ARowStride := Desc.Width shr 1;
        if Desc.Width and 3 <> 0 then Inc(ARowStride);
        ARowStride := ARowStride shl 3;
      end;
    else
      ARowStride := Desc.Width shl 2;
    end;

    // check if the pixels are in order, pixbuf expects them in R-G-B-A
    Desc.GetRGBIndices(Ridx, Gidx, Bidx, AIdx);

    GetMem(NewData, ArawImage.DataSize);

    //if (Ridx <> 0) or (Gidx <> 1) or (Bidx <> 2) or (AIdx <> 3) then
    if desc.Depth=32 then
    begin
      // put components in right order

      DstRowPtr := NewData;
      SrcRowPtr := ArawImage.Data;
      y := Desc.Height;
      while y > 0 do
      begin
        Src := SrcRowPtr;
        Dst := DstRowPtr;
        x := Desc.Width;
        while x > 0 do
        begin
          Dst[0] := Src[Ridx];
          Dst[1] := Src[Gidx];
          Dst[2] := Src[Bidx];
          Dst[3] := Src[Aidx] ;

          Inc(Src, 4);
          Inc(Dst, 4);
          Dec(x);
        end;
        Inc(SrcRowPtr, ARowstride);
        Inc(DstRowPtr, ARowstride);
        Dec(y);
      end;
    end;

  end
  else
    NewData := nil;

  // this is only a rough implementation, there is no check against bitsperpixel
  case Desc.Depth of
    1: ImageFormat := CAIRO_FORMAT_A1;
    8: ImageFormat := CAIRO_FORMAT_A8;
    else
       ImageFormat := CAIRO_FORMAT_ARGB32;
  end;
  ARowStride := GetBytesPerLine(Desc.Width, Desc.BitsPerPixel, rileDWordBoundary);
  ABitmap := HBitmap(TGtk3Image.Create(NewData, Desc.Width, Desc.Height, ARowStride, ImageFormat,
                     {not ASkipMask}true));  // Using ASkipMask for DataOwner param prevents a crash later.
  Result := ABitmap <> 0;

 { if ASkipMask then
  FreeMem(NewData); }

  if ASkipMask then Exit;

  if (ARawImage.Mask <> nil) and (ARawImage.MaskSize > 0) then
  begin
    NewData := GetMem(ARawImage.MaskSize*8);
    FillChar(NewData^,  ARawImage.MaskSize*8,$00);
    //Move(ARawImage.Mask^, NewData^, ARawImage.MaskSize*8);
  end
  else
    NewData := nil;


  ARowStride := GetBytesPerLine(Desc.Width, {Desc.BitsPerPixel}8, rilebyteBoundary);
  AMask := HBitmap(TGtk3Image.Create(NewData, Desc.Width, Desc.Height, ARowStride, CAIRO_FORMAT_A8, True));

end;

{------------------------------------------------------------------------------
  Function: RawImage_DescriptionFromBitmap
  Params: Bitmap: HBITMAP;
          Desc: PRawImageDescription
  Returns: boolean;

 ------------------------------------------------------------------------------}
function TGtk3WidgetSet.RawImage_DescriptionFromBitmap(ABitmap: HBITMAP; out ADesc: TRawImageDescription): boolean;
// var
//  GDIObject: PGDIObject absolute ABitmap;
const
  CairoImageFormatToDepth: array[cairo_format_t] of integer =
  (
    // {CAIRO_FORMAT_RGB30}15,
    // {CAIRO_FORMAT_RGB16_565}16,

    {CAIRO_FORMAT_ARGB32} 32,
    {CAIRO_FORMAT_RGB24}  24,
    {CAIRO_FORMAT_A8}      8,
    {CAIRO_FORMAT_A1}      1
  );

var
  Image: TGtk3Image absolute ABitmap;

begin
  Result := False;
  Result := CheckBitmap(ABitmap, 'RawImage_DescriptionFromBitmap');
  if not Result then Exit;

  //FillStandardDescription(ADesc);
  ADesc.Init;
  ADesc.Width := Image.Width;
  ADesc.Height := Image.Height;

  ADesc.BitOrder := riboReversedBits;
  ADesc.ByteOrder := riboLSBFirst;
  ADesc.LineOrder := riloTopToBottom;
  ADesc.LineEnd := rileDWordBoundary;

  ADesc.Depth := CairoImageFormatToDepth[Image.Format];
  ADesc.BitsPerPixel := ADesc.Depth;
  if ADesc.BitsPerPixel = 24 then
    ADesc.BitsPerPixel := 32;

  ADesc.Format := ricfRGBA;
  case ADesc.Depth of
    1, 8:
      begin
        ADesc.Format := ricfGray;

        ADesc.RedPrec := ADesc.BitsPerPixel;
      end;
    16:
      begin
        ADesc.Depth := 15;

        ADesc.RedPrec := 5;
        ADesc.GreenPrec := 5;
        ADesc.BluePrec := 5;

        ADesc.RedShift := 10;
        ADesc.GreenShift := 5;
        ADesc.BlueShift := 0;
      end;
    24:
      begin
        ADesc.RedPrec := 8;
        ADesc.GreenPrec := 8;
        ADesc.BluePrec := 8;

        ADesc.RedShift := 16;
        ADesc.GreenShift := 8;
        ADesc.BlueShift := 0;
      end;
    32:
      begin
        ADesc.AlphaPrec := 8;
        ADesc.RedPrec := 8;
        ADesc.GreenPrec := 8;
        ADesc.BluePrec := 8;

        ADesc.AlphaShift := 24;
        ADesc.RedShift := 0;
        ADesc.GreenShift := 8;
        ADesc.BlueShift := 16;
      end;
  end;
  (*
  if not IsValidGDIObject(ABitmap)
  then begin
    DebugLn('WARNING: [TGtk3WidgetSet.GetBitmapRawImageDescription] invalid Bitmap!');
    exit;
  end;

  case GDIObject^.GDIBitmapType of
    gbBitmap:
      Result := RawImage_DescriptionFromDrawable(ADesc,
        GdiObject^.GDIBitmapObject, False);
    gbPixmap:
      Result := RawImage_DescriptionFromDrawable(ADesc,
        GdiObject^.GDIPixmapObject.Image, GdiObject^.GDIPixmapObject.Mask <> nil);
    gbPixbuf:
      Result := RawImage_DescriptionFromPixbuf(ADesc, GdiObject^.GDIPixbufObject);
  else
    DebugLn('WARNING: [TGtk3WidgetSet.RawImage_DescriptionFromBitmap] Unknown GDIBitmapType');
    Exit;
  end;
  *)
end;

{------------------------------------------------------------------------------
  function RawImage_DescriptionFromDevice
  Params: DC: HDC;
          Desc: PRawImageDescription
  Returns: boolean;

  Retrieves the information about the structure of the supported image data.
 ------------------------------------------------------------------------------}
function TGtk3WidgetSet.RawImage_DescriptionFromDevice(ADC: HDC; out
  ADesc: TRawImageDescription): Boolean;
begin
  Result := true;

  FillStandardDescription(ADesc{%H-});
  (*
  if IsValidDC(ADC)
  then begin
    Drawable := DevCon.Drawable;
    if DevCon.CurrentBitmap <> nil
    then begin
      case DevCon.CurrentBitmap^.GDIBitmapType of
        gbBitmap: Drawable := DevCon.CurrentBitmap^.GDIBitmapObject;
        gbPixmap: begin
          Drawable := DevCon.CurrentBitmap^.GDIPixmapObject.Image;
          UseAlpha := DevCon.CurrentBitmap^.GDIPixmapObject.Mask <> nil;
        end;
        gbPixbuf: begin
          Result := RawImage_DescriptionFromPixbuf(ADesc, DevCon.CurrentBitmap^.GDIPixbufObject);
          Exit;
        end;
      end;
    end;
  end
  else
    Drawable := nil;
  
  Result := RawImage_DescriptionFromDrawable(ADesc, Drawable, UseAlpha);
  *)
end;

function RawImage_DescriptionFromPixbuf(out ADesc: TRawImageDescription; APixbuf: PGdkPixbuf): boolean;
var
  Width, Height, Depth: integer;
  HasAlpha: Boolean;
begin
  Width := 0;
  Height := 0;

  if APixbuf = nil then
  begin
    HasAlpha := False;
    Depth := 24;
  end else
  begin
    Width := gdk_pixbuf_get_width(APixbuf);
    Height := gdk_pixbuf_get_height(APixbuf);
    Depth := gdk_pixbuf_get_bits_per_sample(APixbuf) * gdk_pixbuf_get_n_channels(APixbuf);
    HasAlpha := gdk_pixbuf_get_has_alpha(APixbuf);
  end;

  ADesc.Init;
  ADesc.Width := cardinal(Width);
  ADesc.Height := cardinal(Height);
  ADesc.BitOrder := riboBitsInOrder;

  if HasAlpha then
  begin
    // always give pixbuf description for alpha images
    ADesc.Format:=ricfRGBA;
    ADesc.Depth := 32;
    ADesc.BitsPerPixel := 32;
    ADesc.LineEnd := rileDWordBoundary;
    ADesc.ByteOrder := riboLSBFirst;

    ADesc.RedPrec := 8;
    ADesc.RedShift := 0;
    ADesc.GreenPrec := 8;
    ADesc.GreenShift := 8;
    ADesc.BluePrec := 8;
    ADesc.BlueShift := 16;
    ADesc.AlphaPrec := 8;
    ADesc.AlphaShift := 24;

    ADesc.MaskBitsPerPixel := 0;
    ADesc.MaskShift := 0;
    ADesc.MaskLineEnd := rileByteBoundary;
    ADesc.MaskBitOrder := riboBitsInOrder;
  end else
  begin
    ADesc.Depth := Depth;
    ADesc.BitsPerPixel := 32;
    ADesc.LineEnd := rileDWordBoundary;
    ADesc.ByteOrder := riboLSBFirst;
    ADesc.MaskBitsPerPixel := 0;
    ADesc.MaskShift := 0;
    ADesc.MaskLineEnd := rileByteBoundary;
    ADesc.MaskBitOrder := riboBitsInOrder;

    ADesc.RedPrec := 8;
    ADesc.RedShift := 0;
    ADesc.GreenPrec := 8;
    ADesc.GreenShift := 8;
    ADesc.BluePrec := 8;
    ADesc.BlueShift := 16;
    ADesc.AlphaPrec := 0;
    ADesc.AlphaShift := 24;
  end;

  Result := True;
end;


function RawImage_DescriptionFromDrawable(out
  ADesc: TRawImageDescription; ADrawable: PGdkPixbuf; ACustomAlpha: Boolean
  ): boolean;
var
  Visual: PGdkVisual;
  Image: PGdkPixbuf;
  Width, Height: integer;
  IsBitmap: Boolean;
  AMask: guint32;
  AShift: gint;
  APrecision: gint;
begin
  Visual := nil;
  Width := 0;
  Height := 0;

  if ADrawable = nil then
  begin
    Visual := gdk_visual_get_system^.get_best;
    if Visual = nil then
      Visual := gdk_visual_get_system;
    IsBitmap := False;
  end else
  begin
    (*
    gdk_drawable_get_size(ADrawable, @Width, @Height);
    Depth := gdk_drawable_get_depth(ADrawable);
    Visual := gdk_window_get_visual(ADrawable);
    // pixmaps and bitmaps do not have a visual, but for pixmaps we need one
    if Visual = nil
    then Visual := gdk_visual_get_best_with_depth(Depth);
    IsBitmap := Depth = 1;
    *)
  end;

  if (Visual = nil) and not IsBitmap then // bitmaps don't have a visual
  begin
    DebugLn('TGtk3WidgetSet.RawImage_DescriptionFromDrawable: visual failed');
    Exit(False);
  end;

  ADesc.Init;
  ADesc.Width := cardinal(Width);
  ADesc.Height := cardinal(Height);
  ADesc.BitOrder := riboBitsInOrder;

  if ACustomAlpha then
  begin
    // always give pixbuf description for alpha images
    ADesc.Format:=ricfRGBA;
    ADesc.Depth := 32;
    ADesc.BitsPerPixel := 32;
    ADesc.LineEnd := rileDWordBoundary;
    ADesc.ByteOrder := riboLSBFirst;

    ADesc.RedPrec := 8;
    ADesc.RedShift := 0;
    ADesc.GreenPrec := 8;
    ADesc.GreenShift := 8;
    ADesc.BluePrec := 8;
    ADesc.BlueShift := 16;
    ADesc.AlphaPrec := 8;
    ADesc.AlphaShift := 24;

    ADesc.MaskBitsPerPixel := 1;
    ADesc.MaskShift := 0;
    ADesc.MaskLineEnd := rileByteBoundary;
    ADesc.MaskBitOrder := riboBitsInOrder;

    Exit(True);
  end;

  // Format
  if IsBitmap then
  begin
    ADesc.Format := ricfGray;
  end else
  begin
    case Visual^.get_visual_type of
      0 {GDK_VISUAL_STATIC_GRAY}:  ADesc.Format:=ricfGray;
      1 {GDK_VISUAL_GRAYSCALE}:    ADesc.Format:=ricfGray;
      2 {GDK_VISUAL_STATIC_COLOR}: ADesc.Format:=ricfGray; // this is not really gray, but an index in a color map, but colormaps are not supported yet, so use gray
      3 {GDK_VISUAL_PSEUDO_COLOR}: ADesc.Format:=ricfGray;
      4 {GDK_VISUAL_TRUE_COLOR}:   ADesc.Format:=ricfRGBA;
      5 {GDK_VISUAL_DIRECT_COLOR}: ADesc.Format:=ricfRGBA;
    else
      DebugLn('TGtk3WidgetSet.GetWindowRawImageDescription unknown Visual type ',
              dbgs(Integer(Visual^.get_visual_type)));
      Exit(False);
    end;
  end;

  // Palette
  if not IsBitmap and
    (Visual^.get_visual_type in [GDK_VISUAL_GRAYSCALE,
       GDK_VISUAL_STATIC_COLOR,GDK_VISUAL_PSEUDO_COLOR]) then
  begin
    // has palette
    // ToDo
    ADesc.PaletteColorCount:=0;
  end;

  // Depth
  if IsBitmap then
    ADesc.Depth := 1
  else
    ADesc.Depth := Visual^.get_depth;

  if IsBitmap or (Visual^.get_byte_order = GDK_MSB_FIRST) then
    ADesc.ByteOrder := riboMSBFirst
  else
    ADesc.ByteOrder := riboLSBFirst;

  ADesc.LineOrder := riloTopToBottom;

  case ADesc.Depth of
    0..8:   ADesc.BitsPerPixel := ADesc.Depth;
    9..16:  ADesc.BitsPerPixel := 16;
    17..32: ADesc.BitsPerPixel := 32;
  else
    ADesc.BitsPerPixel := 64;
  end;

  if IsBitmap then
  begin
    ADesc.LineEnd  := rileByteBoundary;
    ADesc.RedPrec  := 1;
    ADesc.RedShift := 0;
  end else
  begin
    // Try retrieving the lineend
    Image := gdk_pixbuf_new(GDK_COLORSPACE_RGB, False, Visual^.get_bits_per_rgb, 1, 1);
    // gdk_image_new(GDK_IMAGE_NORMAL, Visual, 1, 1);
    if Image = nil then
    begin
      DebugLn('TGtk3WidgetSet.GetWindowRawImageDescription testimage creation failed ');
      Exit(False);
    end;
    try
      // the minimum alignment we can detect is bpp
      // that is no problem since a line consists of n x bytesperpixel bytes
      case Image^.get_bits_per_sample of
        1: ADesc.LineEnd := rileByteBoundary;
        2: ADesc.LineEnd := rileWordBoundary;
        4: ADesc.LineEnd := rileDWordBoundary;
        8: ADesc.LineEnd := rileQWordBoundary;
      else
        DebugLn('TGtk3WidgetSet.GetWindowRawImageDescription Unknown line end: %d', [Image^.get_bits_per_sample]);
        Exit(False);
      end;
    finally
      g_object_unref(Image);
      // gdk_image_destroy(Image);
      Image := nil;
    end;

    Visual^.get_red_pixel_details(@AMask, @AShift, @APrecision);
    ADesc.RedPrec := APrecision;
    ADesc.RedShift := AShift;
    Visual^.get_green_pixel_details(@AMask, @AShift, @APrecision);
    ADesc.GreenPrec := APrecision;
    ADesc.GreenShift := AShift;
    Visual^.get_blue_pixel_details(@AMask, @AShift, @APrecision);
    ADesc.BluePrec := APrecision;
    ADesc.BlueShift := AShift;

    ADesc.MaskBitsPerPixel := 1;
    ADesc.MaskShift := 0;
    ADesc.MaskLineEnd := rileByteBoundary;
    ADesc.MaskBitOrder := riboBitsInOrder;
  end;

  {$IFDEF VerboseRawImage}
  DebugLn('TGtk3WidgetSet.GetWindowRawImageDescription A ',ADesc.AsString);
  {$ENDIF}

  Result := True;
end;

{------------------------------------------------------------------------------
  Function: RawImage_QueryDescription
  Params: AFlags:
          ADesc:
  Returns:

 ------------------------------------------------------------------------------}
function TGtk3WidgetSet.RawImage_QueryDescription(AFlags: TRawImageQueryFlags; var ADesc: TRawImageDescription): Boolean;
begin
  Result := inherited RawImage_QueryDescription(AFlags, ADesc);
  if ADesc.BitsPerPixel > 8 then
    ADesc.BitsPerPixel := 32
  else
  if ADesc.BitsPerPixel > 1 then
    ADesc.BitsPerPixel := 8;
  if (riqfMask in AFlags) then
    RawImage_DescriptionFromDrawable(ADesc, nil, riqfAlpha in AFlags);
end;

{------------------------------------------------------------------------------
  function TGtk3WidgetSet.GetRawImageFromBitmap(SrcBitmap, SrcMaskBitmap: HBITMAP;
    const SrcRect: TRect; var NewRawImage: TRawImage): boolean; override;
 ------------------------------------------------------------------------------}
function TGtk3WidgetSet.RawImage_FromBitmap(out ARawImage: TRawImage; ABitmap, AMask: HBITMAP; ARect: PRect): Boolean;
var
  Desc: TRawImageDescription absolute ARawImage.Description;
  Image: TGtk3Image absolute ABitmap;
  Mask: TGtk3Image absolute AMask;

  WorkImage, WorkMask: TGtk3Image;
  R: TRect;
  Width, Height: Integer;
  //InvertPixels: Boolean;
  //Px: Cardinal;
begin
  Result := false;

  if not CheckBitmap(ABitmap, 'RawImage_FromBitmap') then Exit;
  if (AMask <> 0) and not CheckBitmap(AMask, 'RawImage_FromBitmap (mask)') then Exit;

  ARawImage.Init;
  RawImage_DescriptionFromBitmap(ABitmap, Desc);

  if ARect = nil
  then begin
    Width := Image.Width;
    Height := Image.Height;
    R := Rect(0, 0, Width, Height)
  end
  else begin
    R := ARect^;
    Width := R.Right - R.Left;
    Height := R.Bottom - R.Top;
  end;

  WorkMask:=nil;

  if (Width = Image.Width) and (Height = Image.Height) then
  begin
    WorkImage := Image;
    WorkMask := Mask;
  end
  else begin
    WorkImage := TGtk3Image.Create;
    WorkImage.CopyFrom(Image.Handle, R.Left, R.Top, Width, Height);
    if Mask <> nil then
    begin
      WorkMask := TGtk3Image.Create;
      WorkMask.CopyFrom(Mask.Handle, R.Left, R.Top, Width, Height);
    end
    else
      WorkMask := nil;
  end;

  Desc.Width := WorkImage.width;
  Desc.Height := WorkImage.height;

  // copy data
  ARawImage.DataSize := WorkImage.numBytes;
  ReAllocMem(ARawImage.Data, ARawImage.DataSize);

  if ARawImage.DataSize > 0 then
    Move(WorkImage.bits^, ARawImage.Data^, ARawImage.DataSize);

  if WorkMask <> nil then
  begin
    Desc.MaskLineEnd := rileDWordBoundary;
    Desc.MaskBitOrder := riboReversedBits;
    Desc.MaskBitsPerPixel := 1;
    ARawImage.MaskSize := WorkMask.numBytes;
    ReAllocMem(ARawImage.Mask, ARawImage.MaskSize);
    if ARawImage.MaskSize > 0 then
    begin
      (*
      InvertPixels := False;
      if WorkImage <> nil then
      begin
        Px := QImage_pixel(WorkImage.Handle, 0, 0);
        InvertPixels :=
          not QImage_hasAlphaChannel(WorkMask.Handle) and
          not QImage_hasAlphaChannel(WorkImage.Handle) and
          // invert only if WorkImage is RGB32 fmt and allGray
          (WorkImage.getFormat = QImageFormat_RGB32) and
          QImage_allGray(WorkImage.Handle) and
          ((Px = 0) or (Px = $FF))
      end;
      if InvertPixels then
        WorkMask.invertPixels(QImageInvertRGB);
        *)
      if (WorkMask.bits<>nil) and (ARawImage.Mask<>nil) then
      Move(WorkMask.bits^, ARawImage.Mask^, ARawImage.MaskSize);
      // if InvertPixels then
      //  WorkMask.invertPixels(QImageInvertRGB);
    end;
  end;

  if WorkImage <> Image then
    WorkImage.Free;
  if WorkMask <> Mask then
    WorkMask.Free;

  Result := True;

  (*
  {$IFDEF VerboseRawImage}
  DebugLn('TGtk3WidgetSet.GetRawImageFromBitmap A');
  {$ENDIF}
  ARawImage.Init;

  if not IsValidGDIObject(ABitmap)
  then begin
    DebugLn('WARNING: [TGtk3WidgetSet.RawImage_FromBitmap] invalid Bitmap!');
    exit;
  end;
  if (AMask <> 0) and not IsValidGDIObject(AMask)
  then begin
    DebugLn('WARNING: [TGtk3WidgetSet.RawImage_FromBitmap] invalid Mask');
    exit;
  end;

  try
    // get rawimage for Bitmap
    case GdiBitmap^.GDIBitmapType of
      gbBitmap: begin
        Drawable := GdiBitmap^.GDIBitmapObject;
        Bitmap := nil;
      end;
      gbPixmap: begin
        Drawable := GdiBitmap^.GDIPixmapObject.Image;
        Bitmap := GdiBitmap^.GDIPixmapObject.Mask;
      end;
      gbPixbuf: begin
        Result := RawImage_FromPixbuf(ARawImage, GdiBitmap^.GDIPixbufObject, ARect);
        Exit;
      end;
    else
      DebugLn('WARNING: [TGtk3WidgetSet.RawImage_FromBitmap] Unknown GDIBitmapType');
      Exit;
    end;
    {$IFDEF VerboseRawImage}
    DebugLn('TGtk3WidgetSet.RawImage_FromBitmap A GdkPixmap=',DbgS(Drawable),' SrcMaskBitmap=',DbgS(Bitmap));
    {$ENDIF}

    //DbgDumpPixmap(Drawable, 'RawImage_FromBitmap - drawable');
    //DbgDumpBitmap(Bitmap, 'RawImage_FromBitmap - alpha');

    Result := RawImage_FromDrawable(ARawImage, Drawable, Bitmap, ARect);
    if Result and (AMask <> 0)
    then begin
      if GdiMask^.GDIBitmapType <> gbBitmap
      then begin
        DebugLn('WARNING: [TGtk3WidgetSet.RawImage_FromBitmap] Unsupported GDIBitmapType for mask');
        Exit;
      end;
      
      Bitmap := GdiMask^.GDIBitmapObject;
      RawImage_AddMask(ARawImage, Bitmap, ARect);
      //DbgDumpBitmap(Bitmap, 'RawImage_FromBitmap - mask');
    end
    else
      ARawImage.Description.MaskBitsPerPixel := 0;

    if not Result
    then DebugLn('WARNING: [TGtk3WidgetSet.RawImage_FromBitmap] unable to GetRawImageFromGdkWindow Image');

  except
    ARawImage.FreeData;
  end;
  *)
end;

{------------------------------------------------------------------------------
  function TGtk3WidgetSet.GetRawImageFromDevice(SrcDC: HDC; const SrcRect: TRect;
    var NewRawImage: TRawImage): boolean;

 ------------------------------------------------------------------------------}
function TGtk3WidgetSet.RawImage_FromDevice(out ARawImage: TRawImage; ADC: HDC;
  const ARect: TRect): Boolean;
var
  Desc: TRawImageDescription absolute ARawImage.Description;
  DCSize: TSize;
  Pixmap: PGdkPixbuf;
  Context: TGtk3DeviceContext;
  //DCOrigin: TPoint;
  //R: TRect;
  //Drawable: Pcairo_t;
  //AWindow: PGdkWindow;

  procedure RawImage_FromImage(AImage: PGdkPixbuf);
  var
    pixels: Pguint8;
  begin
    ARawImage.DataSize := AImage^.get_byte_length;
    ARawImage.Data := GetMem(ARawImage.DataSize);
    Pixels := AImage^.get_pixels;
    Move(pixels^, ARawImage.Data^, ARawImage.DataSize);
    ARawImage.Mask := nil;
  end;

begin
  Result := True;

  if not IsValidDC(ADC) then
  begin
    DebugLn('WARNING: TGtk3WidgetSet.GetRawImageFromDevice invalid SrcDC');
    Exit(False);
  end;

  ARawImage.Init;
  FillStandardDescription(ARawImage.Description);

  Context := TGtk3DeviceContext(ADC);

  with DCSize, Context.getDeviceSize do
  begin
    cx := x;
    cy := y;
  end;

  if Context.Parent <> nil then
  begin
    Pixmap := gdk_pixbuf_get_from_window(Context.Parent^.window, 0, 0, DCSize.cx, DCSize.cy);
    if Pixmap <> nil then
    begin
      try
        DebugLn('Context.Parent RawImage_FromImage');
        RawImage_FromImage(Pixmap);
        // if you have dual monitors then getDeviceSize return
        // more width than screen width, but grabWindow will only grab one
        // screen, so its width will be less
        // Solution: we can either pass prefered size to grabWindow or
        // correct Description size after. I see the first solution as more correct.
      finally
        g_object_unref(Pixmap);
      end;
    end else
      Result := False;
  end else
  begin
    if Context.ParentPixmap <> nil then
    begin
      Pixmap := gdk_pixbuf_copy(Context.ParentPixmap);
      if Pixmap <> nil then
      begin
        RawImage_FromImage(Pixmap);
        g_object_unref(Pixmap);
      end;
    end else
    if Context.Window <> nil then
    begin
      Pixmap := gdk_pixbuf_get_from_window(Context.Window, 0, 0, DCSize.cx, DCSize.cy);
      if Pixmap <> nil then
      begin
        try
          DebugLn('Context.Window RawImage_FromImage');
          RawImage_FromImage(Pixmap);
          // if you have dual monitors then getDeviceSize return
          // more width than screen width, but grabWindow will only grab one
          // screen, so its width will be less
          // Solution: we can either pass prefered size to grabWindow or
          // correct Description size after. I see the first solution as more correct.
        finally
          g_object_unref(Pixmap);
        end;
      end else
        Result := False;
    end else
      Result := False;
  end;

  // In this case we use the size of the context
  Desc.Width := DCSize.cx;
  Desc.Height := DCSize.cy;

  {$ifdef VerboseGtk3WinApi}
    WriteLn('Trace:< [WinAPI GetRawImageFromDevice]');
  {$endif}

  (*
  DCOrigin := DevCtx.Offset;
  {$IFDEF VerboseRawImage}
  DebugLn('TGtk3WidgetSet.GetRawImageFromDevice A DCOrigin=',dbgs(DCOrigin.X),',',dbgs(DCOrigin.Y),' SrcRect=',dbgs(ARect.Left),',',dbgs(ARect.Top),',',dbgs(ARect.Right),',',dbgs(ARect.Bottom));
  {$ENDIF}
  R := ARect;
  LPtoDP(ADC, R, 2);
  OffSetRect(R, DCOrigin.x, DCOrigin.y);

  Drawable := DevCtx.Widget;
  if Drawable = nil then
  begin
    // get screen shot
    // Drawable := gdk_cairo_set_source_window();
    AWindow := gdk_screen_get_root_window(gdk_screen_get_default);
    Drawable := gdk_cairo_create(AWindow);
    // Result := RawImage_FromDrawable(ARawImage, Drawable, nil, @R);

    cairo_destroy(Drawable);
  end else
  begin
    // Result :=
    // RawImage_FromDrawable(ARawImage, Drawable, nil, @R);
  end;
  *)

end;

{------------------------------------------------------------------------------
  Function: GetControlConstraints
  Params: Constraints: TObject
  Returns: true on success

  Updates the constraints object (e.g. TSizeConstraints) with interface specific
  bounds.
 ------------------------------------------------------------------------------}
(*
function TGtk3WidgetSet.GetControlConstraints(Constraints: TObject): boolean;
var
  SizeConstraints: TSizeConstraints absolute Constraints;
  Widget: PGtkWidget;
  MinWidth: Integer;
  MinHeight: Integer;
  MaxWidth: Integer;
  MaxHeight: Integer;
begin
  Result := True;

  if Constraints is TSizeConstraints then
  begin
    MinWidth := 1;
    MinHeight := 1;
    MaxWidth := 0;
    MaxHeight := 0;

    if (SizeConstraints.Control=nil) then exit;

    if SizeConstraints.Control is TScrollBar then begin
      // TScrollBar
      if TScrollBar(SizeConstraints.Control).Kind=sbHorizontal then begin
        Widget:=GetStyleWidget(lgsHorizontalScrollbar);
        MinHeight:=Widget^.requisition.Height;
        MaxHeight:=MinHeight;
      end else begin
        Widget:=GetStyleWidget(lgsVerticalScrollbar);
        MinWidth:=Widget^.requisition.Width;
        MaxWidth:=MinWidth;
      end;
      //DebugLn('TGtk3WidgetSet.GetControlConstraints A '+dbgs(MinWidth)+','+dbgs(MinHeight),' ',dbgs(TScrollBar(SizeConstraints.Control).Kind=sbHorizontal),' ',TScrollBar(SizeConstraints.Control).Name);
    end
    else if SizeConstraints.Control is TCustomSplitter then begin
      // TCustomSplitter
      if TCustomSplitter(SizeConstraints.Control).ResizeAnchor in [akTop,akBottom] then
      begin
        Widget:=GetStyleWidget(lgsHorizontalPaned);
        MinHeight:=Widget^.requisition.Height;
        MaxHeight:=MinHeight;
      end else begin
        Widget:=GetStyleWidget(lgsVerticalPaned);
        MinWidth:=Widget^.requisition.Width;
        MaxWidth:=MinWidth;
      end;
    end
    else if SizeConstraints.Control is TCustomMemo then begin
      // TCustomMemo
      Widget:=GetStyleWidget(lgsHorizontalScrollbar);
      MinHeight:=Widget^.requisition.Height+20;
      Widget:=GetStyleWidget(lgsVerticalScrollbar);
      MinWidth:=Widget^.requisition.Width+20;
    end
    else if SizeConstraints.Control is TCustomTrackBar then begin
      // TCustomTrackBar
      if TCustomTrackBar(SizeConstraints.Control).Orientation=trHorizontal then
      begin
        Widget:=GetStyleWidget(lgsHScale);
        MinHeight:=Widget^.requisition.height;
      end else begin
        Widget:=GetStyleWidget(lgsVScale);
        MinWidth:=Widget^.requisition.width;
      end;
      //DebugLn(['TGtk3WidgetSet.GetControlConstraints ',DbgSName(SizeConstraints.Control),' ',MinWidth,',',MinHeight]);
    end;

    SizeConstraints.SetInterfaceConstraints(MinWidth,MinHeight,
                                            MaxWidth,MaxHeight);
  end;
end;
*)

{------------------------------------------------------------------------------
  function TGtk3WidgetSet.GetLCLOwnerObject(Handle: HWnd): TObject;

 ------------------------------------------------------------------------------}
function TGtk3WidgetSet.GetLCLOwnerObject(Handle: HWnd): TObject;
begin
  if Handle<>0 then
    Result := TGtk3Widget(Handle).LCLObject
  else
    Result := nil;
end;

function TGtk3WidgetSet.AskUser(const DialogCaption, DialogMessage: string; DialogType:
   LongInt; Buttons: TDialogButtons; HelpCtx: Longint): LongInt;
var
  fact:TGtk3DialogFactory;
begin
  fact:=TGtk3DialogFactory.CreateAsk(DialogCaption,DialogMessage,DialogType,Buttons,HelpCtx);
  try
    fact.run;
    Result := fact.lcl_result;
  finally
    fact.Free;
  end;
end;

function TGtk3WidgetSet.PromptUser(const DialogCaption: string;
  const DialogMessage: string; DialogType: LongInt; Buttons: PLongInt;
  ButtonCount: LongInt; DefaultIndex: LongInt; EscapeResult: LongInt): LongInt;
var
  fact:TGtk3DialogFactory;
begin
  fact:=TGtk3DialogFactory.CreatePrompt(DialogCaption,DialogMessage,
     DialogType,Buttons,ButtonCount,DefaultIndex,EscapeResult);
  try
    fact.run;
    Result:=fact.btn_result;
  finally
    fact.Free;
  end;

end;


function TGtk3WidgetSet.SetComboMinDropDownSize(Handle: HWND; MinItemsWidth,
  MinItemsHeight, MinItemCount: integer): boolean;
var
  p: PGtkWidget;
  Menu: PGtkWidget;
  Height, Width: GInt;
begin
  Result:=True;
  p := TGtk3Widget(Handle).Widget;
  if (p <> nil) and
    g_type_check_instance_is_a(PGTypeInstance(p), gtk_combo_box_get_type) then
  begin
    //TODO: add TGtk3ComboBox.SetComboDropDownSize
    Menu := PGtkWidget(g_object_get_data(p, 'Menu'));
    if Menu<>nil then
    begin
      width := MinItemsWidth;
      height := MinItemsHeight * MinItemCount;
      gtk_widget_set_size_request(Menu, Width, Height);
    end;
  end;
end;


//##apiwiz##eps##   // Do not remove, no wizard declaration after this line


function waithandle_iocallback({%H-}source: PGIOChannel; condition: TGIOCondition;
  data: gpointer): gboolean; cdecl;
// var
//  lEventHandler: PWaitHandleEventHandler absolute data;
begin
  //debugln('waithandle_iocallback lEventHandler=',HexStr(Cardinal(lEventHandler),8));
  // lEventHandler^.OnEvent(lEventHandler^.UserData, condition);
  Result := true;
end;

function TGtk3WidgetSet.AddEventHandler(AHandle: THandle; AFlags: dword;
  AEventHandler: TWaitHandleEvent; AData: PtrInt): PEventHandler;
//var
  //giochannel: pgiochannel;
  //lEventHandler: PWaitHandleEventHandler;
begin
  Result := nil;
  if AEventHandler = nil then exit;
  (*
  New(lEventHandler);
  giochannel := g_io_channel_unix_new(AHandle);
  lEventHandler^.Handle := AHandle;
  lEventHandler^.UserData := AData;
  lEventHandler^.GIOChannel := giochannel;
  lEventHandler^.OnEvent := AEventHandler;
  lEventHandler^.GSourceID := g_io_add_watch(giochannel,
    AFlags, @waithandle_iocallback, lEventHandler);
  //debugln('TGtk3WidgetSet.AddEventHandler lEventHandler=',HexStr(Cardinal(lEventHandler),8),' AHandle=',dbgs(lEventHandler^.Handle));
  lEventHandler^.PrevHandler := nil;
  lEventHandler^.NextHandler := FWaitHandles;
  if FWaitHandles <> nil then
    FWaitHandles^.PrevHandler := lEventHandler;
  FWaitHandles := lEventHandler;
  Result := lEventHandler;
  *)
end;


procedure TGtk3WidgetSet.RemoveEventHandler(var AHandler: PEventHandler);
// var
//  lEventHandler: PWaitHandleEventHandler absolute AHandler;
begin
  (*
  if AHandler = nil then exit;
  g_source_remove(lEventHandler^.GSourceID);
  { channel will be freed with ref count drops to 0 }
  g_io_channel_unref(lEventHandler^.GIOChannel);
  if lEventHandler^.PrevHandler = nil then
    FWaitHandles := lEventHandler^.NextHandler
  else
    lEventHandler^.PrevHandler^.NextHandler := lEventHandler^.NextHandler;
  if lEventHandler^.NextHandler <> nil then
    lEventHandler^.NextHandler^.PrevHandler := lEventHandler^.PrevHandler;
  //debugln('TGtk3WidgetSet.RemoveEventHandler lEventHandler=',HexStr(Cardinal(lEventHandler),8),' AHandle=',dbgs(lEventHandler^.Handle));
  Dispose(lEventHandler);
  *)
  AHandler := nil;
end;

procedure TGtk3WidgetSet.SetEventHandlerFlags(AHandler: PEventHandler; NewFlags: dword);
// var
//  lEventHandler: PWaitHandleEventHandler absolute AHandler;
begin
  if AHandler = nil then exit;
  // g_source_remove(lEventHandler^.GSourceID);
  // lEventHandler^.GSourceID := g_io_add_watch(lEventHandler^.GIOChannel,
  //  NewFlags, @waithandle_iocallback, lEventHandler);
  //debugln('TGtk3WidgetSet.SetEventHandlerFlags lEventHandler=',HexStr(Cardinal(lEventHandler),8),' AHandle=',dbgs(lEventHandler^.Handle));
end;

procedure TGtk3WidgetSet.SetRubberBandRect(const ARubberBand: HWND; const ARect: TRect);
begin
  with ARect do
    gdk_window_move_resize({%H-}PGtkWidget(ARubberBand)^.window, Left,
      Top, Right - Left, Bottom - Top);
end;

type
  PPipeEventInfo = ^TPipeEventInfo;
  TPipeEventInfo = record
    Handler: PEventHandler;
    UserData: PtrInt;
    OnEvent: TPipeEvent;
  end;

function TGtk3WidgetSet.AddPipeEventHandler(AHandle: THandle;
  AEventHandler: TPipeEvent; AData: PtrInt): PPipeEventHandler;
var
  lPipeEventInfo: PPipeEventInfo;
begin
  if AEventHandler = nil then exit;
  New(lPipeEventInfo);
  lPipeEventInfo^.UserData := AData;
  lPipeEventInfo^.OnEvent := AEventHandler;
  // lPipeEventInfo^.Handler := AddEventHandler(AHandle, G_IO_IN or G_IO_HUP or G_IO_OUT,
  //  @HandlePipeEvent, {%H-}PtrUInt(lPipeEventInfo));
  Result := lPipeEventInfo;
end;

(*
procedure TGtk3WidgetSet.HandlePipeEvent(AData: PtrInt; AFlags: dword);
var
  lPipeEventInfo: PPipeEventInfo absolute AData;
  lReasons: TPipeReasons;
begin
  lReasons := [];
  if AFlags and G_IO_IN = G_IO_IN then
    Include(lReasons, prDataAvailable);
  if AFlags and G_IO_OUT = G_IO_OUT then
    Include(lReasons, prCanWrite);
  if AFlags and G_IO_HUP = G_IO_HUP then
    Include(lReasons, prBroken);

  lPipeEventInfo^.OnEvent(lPipeEventInfo^.UserData, lReasons);
end;

procedure TGtk3WidgetSet.RemovePipeEventHandler(var AHandler: PPipeEventHandler);
var
  lPipeEventInfo: PPipeEventInfo absolute AHandler;
begin
  if AHandler = nil then exit;
  RemoveEventHandler(lPipeEventInfo^.Handler);
  Dispose(lPipeEventInfo);
  AHandler := nil;
end;
*)

{$ifdef UNIX}
function TGtk3WidgetSet.AddProcessEventHandler(AHandle: THandle;
  AEventHandler: TChildExitEvent; AData: PtrInt): PProcessEventHandler;
// var
//  lHandler: PChildSignalEventHandler;
begin
  Result := nil;
  if AEventHandler = nil then exit(nil);
  (*
  New(lHandler);
  lHandler^.PID := TPid(AHandle);
  lHandler^.UserData := AData;
  lHandler^.OnEvent := AEventHandler;
  lHandler^.PrevHandler := nil;
  lHandler^.NextHandler := FChildSignalHandlers;
  if FChildSignalHandlers <> nil then
    FChildSignalHandlers^.PrevHandler := lHandler;
  FChildSignalHandlers := lHandler;
  Result := lHandler;
  *)
end;

procedure TGtk3WidgetSet.RemoveProcessEventHandler(var AHandler: PProcessEventHandler);
// var
//  lHandler: PChildSignalEventHandler absolute AHandler;
begin
  if AHandler = nil then exit;
  (*
  if lHandler^.PrevHandler = nil then
    FChildSignalHandlers := lHandler^.NextHandler
  else
    lHandler^.PrevHandler^.NextHandler := lHandler^.NextHandler;
  if lHandler^.NextHandler <> nil then
    lHandler^.NextHandler^.PrevHandler := lHandler^.PrevHandler;
  Dispose(lHandler);
  AHandler := nil;
  *)
end;
{$else}
{$IFDEF VerboseGtkToDos}{$warning TGtk3WidgetSet.RemoveProcessEventHandler and TGtk3WidgetSet.AddProcessEventHandler not implemented on this OS}{$ENDIF}
//PChildSignalEventHandler is only defined on unix
function TGtk3WidgetSet.AddProcessEventHandler(AHandle: THandle;
  AEventHandler: TChildExitEvent; AData: PtrInt): PProcessEventHandler;
begin
  Result := nil;
end;

procedure TGtk3WidgetSet.RemoveProcessEventHandler(var AHandler: PProcessEventHandler);
begin
end;
{$endif}


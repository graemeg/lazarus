{%MainUnit gtk2int.pas}
{ $Id$ }
{******************************************************************************
                 All GTK2 interface communication implementations.
                   Initial Revision  : Sat Jan 17 19:00:00 2004


  !! Keep alphabetical !!

  Support routines go to gtk2proc.pp

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

function TGtk2WidgetSet.CreateRubberBand(const ARect: TRect; const ABrush: HBrush): HWND;
var
  Widget: PGtkWidget absolute Result;
  dx, dy: integer;
  Pixmap: PGdkPixmap;
  gc: PGdkGC;
  AColor: TGdkColor;
begin
  dx := ARect.Right - ARect.Left;
  dy := ARect.Bottom - ARect.Top;
  if dx < 0 then
    dx := 0;
  if dy < 0 then
    dy := 0;

  // rubber band is just a window without a title
  Result := {%H-}HWND(gtk_window_new(GTK_WINDOW_POPUP));
  gtk_window_set_default_size({%H-}PGtkWindow(Result), dx, dy);
  gtk_widget_set_uposition(Widget, ARect.Left, ARect.Top);
  gtk_widget_set_app_paintable(Widget, True);
  gtk_widget_realize(Widget);
  gdk_window_set_decorations(Widget^.window, 0);
  gdk_window_set_functions(Widget^.window, GDK_FUNC_RESIZE or GDK_FUNC_CLOSE);
  gtk_window_set_opacity({%H-}PGtkWindow(Result), 0.25);
  if ABrush = 0 then
    SetWidgetColor(Widget, clNone, clGradientActiveCaption, [GTK_STATE_NORMAL])
  else
  if {%H-}PGDIObject(ABrush)^.GDIBrushFill = GDK_SOLID then
    SetWidgetColor(Widget, clNone, {%H-}PGDIObject(ABrush)^.GDIBrushColor.ColorRef, [GTK_STATE_NORMAL])
  else
  begin
    Pixmap := gdk_pixmap_new(Widget^.window, dx, dy, -1);
    gc := gdk_gc_new(Pixmap);
    AColor := AllocGDKColor(clWhite);
    gdk_gc_set_foreground(gc, @AColor);
    gdk_gc_set_fill(gc, {%H-}PGDIObject(ABrush)^.GDIBrushFill);
    case {%H-}PGDIObject(ABrush)^.GDIBrushFill of
      GDK_TILED: gdk_gc_set_tile(gc, {%H-}PGDIObject(ABrush)^.GDIBrushPixMap);
      GDK_STIPPLED: gdk_gc_set_stipple(gc, {%H-}PGDIObject(ABrush)^.GDIBrushPixMap);
    end;
    gdk_draw_rectangle(Pixmap, gc, -1, 0, 0, dx, dy);
    gdk_gc_unref(gc);
    gdk_window_set_back_pixmap(Widget^.window, Pixmap, False);
    g_object_unref(Pixmap);
  end;

  gtk_widget_show(Widget);
end;

procedure TGtk2WidgetSet.DestroyRubberBand(ARubberBand: HWND);
begin
  gtk_widget_destroy({%H-}PGtkWidget(ARubberBand));
end;

procedure TGtk2WidgetSet.DrawDefaultDockImage(AOldRect, ANewRect: TRect;
  AOperation: TDockImageOperation);
const
  LineWidth = 2;
var
  Mask: PGdkBitmap;
  gc: PGdkGC;
  dx, dy: integer;
  AColor: TGdkColor;
{$ifdef GTK_2_10}
  Colormap: PGdkColormap;
  Screen: PGdkScreen;
{$endif}
begin
  dx := ANewRect.Right - ANewRect.Left;
  dy := ANewRect.Bottom - ANewRect.Top;
  if dx < 0 then
    dx := 0;
  if dy < 0 then
    dy := 0;
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
    {$ifdef GTK_2_10}
    // attemp to make window semi-transparent
    Screen := gtk_widget_get_screen(FDockImage);
    Colormap := gdk_screen_get_rgba_colormap(Screen);
    if (Colormap <> nil) and gdk_screen_is_composited(Screen) then
      gtk_widget_set_colormap(FDockImage, Colormap);
    {$endif}
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
end;

procedure TGtk2WidgetSet.DrawGrid(DC: HDC; const R: TRect; DX, DY: Integer);
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
  function TGtk2WidgetSet.ExtUTF8Out(DC: HDC; X, Y: Integer; Options: Longint;
    Rect: PRect; Str: PChar; Count: Longint; Dx: PInteger): Boolean;

  As ExtTextOut except that Str is treated as UTF8
 ------------------------------------------------------------------------------}
function TGtk2WidgetSet.ExtUTF8Out(DC: HDC; X, Y: Integer; Options: Longint;
  Rect: PRect; Str: PChar; Count: Longint; Dx: PInteger): Boolean;
begin
  // all fonts are UTF-8 under gtk2 => no mapping needed
  Result:=ExtTextOut(DC,X,Y,Options,Rect,Str,Count,Dx);
end;

function TGtk2WidgetSet.TextUTF8Out(DC: HDC; X, Y: Integer; Str: PChar; Count: Longint): Boolean;
begin
  // all fonts are UTF-8 under gtk2 => no mapping needed
  Result := TextOut(DC, X, Y, Str, Count);
end;

{------------------------------------------------------------------------------
  function TGtk2WidgetSet.FontIsMonoSpace(Font: HFont): boolean;

  True if font characters have all the same width.
 ------------------------------------------------------------------------------}
function TGtk2WidgetSet.FontIsMonoSpace(Font: HFont): boolean;
begin
  Result:=IsValidGDIObject(Font)
          and FontIsMonoSpaceFont({%H-}PGdiObject(Font)^.GDIFontObject);
end;

{------------------------------------------------------------------------------
  Function: GetAcceleratorString
  Params: AVKey:
          AShiftState:
  Returns:

 ------------------------------------------------------------------------------}
function TGtk2WidgetSet.GetAcceleratorString(const AVKey: Byte;
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
function TGtk2WidgetSet.RawImage_CreateBitmaps(const ARawImage: TRawImage; out
  ABitmap, AMask: HBitmap; ASkipMask: boolean): boolean;
var
  GdiObject: PGDIObject absolute ABitmap;
  GdiMaskObject: PGDIObject absolute AMask;
  Desc: TRawImageDescription absolute ARawImage.Description;
  ImgData: Pointer absolute ARawImage.Data;
  ImgMask: Pointer absolute ARawImage.Mask;
  ImgWidth: Cardinal absolute ARawImage.Description.Width;
  ImgHeight: Cardinal absolute ARawImage.Description.Height;
  ImgDepth: Byte absolute ARawImage.Description.Depth;
  ImgDataSize: PtrUInt absolute ARawImage.DataSize;
  Drawable: PGdkDrawable;
  Pixbuf, TmpPixBuf: PGdkPixbuf;
  GC: PGdkGC;
  Visual: PGdkVisual;
  GdkImage: PGdkImage;
  RowStride: Cardinal;
  Ridx, Gidx, Bidx, Aidx: Byte;
  Data: Pointer;
  Src, Dst, SrcRowPtr, DstRowPtr: PByte;
  x, y: Cardinal;
  CreateWithAlpha: boolean;
  ADivResult, ARemainder: DWord;
begin
  Result := False;
  ABitmap := 0;
  AMask := 0;

  if ImgWidth = 0 then Exit;
  if ImgHeight = 0 then Exit;

  CreateWithAlpha := True;
  try
    {$IFDEF VerboseRawImage}
    DebugLn('TGtk2WidgetSet.CreateBitmapFromRawImage A ',
      ' ASkipMask='+dbgs(ASkipMask),
      ' Depth='+dbgs(Desc.Depth),
      ' Width='+dbgs(Desc.Width),
      ' Height='+dbgs(Desc.Height),
      ' Data='+DbgS(ARawImage.Data),
      ' DataSize='+dbgs(ARawImage.DataSize)+
      ' Mask='+DbgS(ARawImage.Mask)+
      ' MaskSize='+dbgs(ARawImage.MaskSize)+
      ' Palette='+DbgS(ARawImage.Palette)+
      ' PaletteSize='+dbgs(ARawImage.PaletteSize)+
      ' BitsPerPixel='+dbgs(Desc.BitsPerPixel)+
      '');
    {$ENDIF}

    // ToDo: check description

    GdiObject := NewGDIObject(gdiBitmap);
    GdiObject^.GDIBitmapType := gbPixmap;
    GdiObject^.Depth := ImgDepth;

    // create Pixmap from data
    if ImgDepth = 1 then
    begin
      // create a GdkBitmap
      if ImgData <> nil then
      begin
        Drawable := gdk_bitmap_create_from_data(nil, ImgData, ImgWidth, ImgHeight);
        //gtk2 crashes if we create mask on gdkbitmap.issue #21673
        ASkipMask := True;
      end else
        Drawable := gdk_pixmap_new(nil, ImgWidth, ImgHeight, 1);

      GdiObject^.GDIBitmapObject := Drawable;
      GdiObject^.GDIBitmapType := gbBitmap;
    end else
    begin
      if (ImgData <> nil) and (ImgDepth = 32)
      then begin
        case Desc.LineEnd of
          rileQWordBoundary: begin
            RowStride := ImgWidth;
            if ImgWidth and 1 <> 0 then Inc(RowStride);
            RowStride := RowStride shl 2;
          end;
          rileDQWordBoundary: begin
            RowStride := ImgWidth shr 1;
            if ImgWidth and 3 <> 0 then Inc(RowStride);
            RowStride := RowStride shl 3;
          end;
        else
          RowStride := ImgWidth shl 2;
        end;

        // check if the pixels are in order, pixbuf expects them in R-G-B-A
        Desc.GetRGBIndices(Ridx, Gidx, Bidx, AIdx);

        if (Ridx <> 0) or (Gidx <> 1) or (Bidx <> 2) or (AIdx <> 3) then
        begin
          // put components in right order
          GetMem(Data, ImgDataSize);
          DstRowPtr := Data;
          SrcRowPtr := ImgData;
          y := ImgHeight;
          while y > 0 do
          begin
            Src := SrcRowPtr;
            Dst := DstRowPtr;
            x := ImgWidth;
            while x > 0 do
            begin
              Dst[0] := Src[Ridx];
              Dst[1] := Src[Gidx];
              Dst[2] := Src[Bidx];
              Dst[3] := Src[Aidx];

              Inc(Src, 4);
              Inc(Dst, 4);
              Dec(x);
            end;
            Inc(SrcRowPtr, Rowstride);
            Inc(DstRowPtr, Rowstride);
            Dec(y);
          end;
        end
        else begin
          // components are in place

          // gtkPixbuf doesn't like invalid dataSize/MaskSize < 32. issue #8553.
          if (ARawImage.MaskSize > 0) and (ImgDepth = 32) then
          begin
            // seem that gdkPixbuf does not like many of our masks
            ADivResult := 0;
            ARemainder := 0;
            DivMod(ARawImage.DataSize, ARawImage.MaskSize, ADivResult, ARemainder);
            CreateWithAlpha := ARemainder = 0;
            {$IFDEF VerboseRawImage}
            if not CreateWithAlpha then
              DebugLn('TGtk2WidgetSet.CreateBitmapFromRawImage B WARNING: This image have invalid DataSize / MaskSize.');
            {$ENDIF}
          end;
          Data := ImgData;
        end;

        TmpPixBuf := gdk_pixbuf_new_from_data(Data, GDK_COLORSPACE_RGB, CreateWithAlpha,
          8, ImgWidth, ImgHeight, RowStride, nil, nil);

        // we need to copy our pixbuf into a new one to allow data deallocation
        Pixbuf := gdk_pixbuf_copy(TmpPixBuf);
        gdk_pixbuf_unref(TmpPixBuf);
        GdiObject^.GDIBitmapType := gbPixbuf;
        GdiObject^.GDIPixbufObject := Pixbuf;
        if Data <> ImgData
        then FreeMem(Data);
        GdiObject^.visual := gdk_visual_get_system();
        gdk_visual_ref(GdiObject^.visual);
        //DbgDumpPixbuf(Pixbuf, 'CreateBitmaps (32)');
      end
      else begin
        // check if the depth is supported
        Visual := gdk_visual_get_best_with_depth(Min(ImgDepth, 24));
        // try some alternative (I'm not sure if we should fail here instead)
        // if we don't have a visual we cannot draw anyway
        //if Visual = nil
        //then Visual := gdk_visual_get_best;
        if Visual = nil
        then Exit; // this depth is not supported

        Drawable := gdk_pixmap_new(nil, ImgWidth, ImgHeight, Visual^.depth);

        // create a GdkPixmap
        if ImgData <> nil
        then begin
          { The gdk_pixmap_create_from_data creates only a two-color pixmap so we can not use it }

          GdkImage := gdk_image_new(GDK_IMAGE_FASTEST, Visual, ImgWidth, ImgHeight);

          {$ifdef VerboseRawImage}
          //DebugLn('TGtk2WidgetSet.CreateBitmapFromRawImage GdkImage: ',
          //  ' BytesPerLine=',dbgs(GdkImage^.bpl),
          //  ' BitsPerPixel=',dbgs(GetPGdkImageBitsPerPixel(GdkImage)),
          //  ' ByteOrder=',dbgs(ord(GdkImage^.byte_order)),
          //  '');
          {$endif}

          if ARawImage.Description.BitsPerPixel <> GetGdkImageBitsPerPixel(GdkImage)
          then begin
            DebugLn('TGtk2WidgetSet.CreateBitmapFromRawImage GdkImage: ',
              ' BytesPerLine=',dbgs(GdkImage^.bpl),
              ' BitsPerPixel=',dbgs(GetGdkImageBitsPerPixel(GdkImage)),
              ' ByteOrder=',dbgs(ord(GdkImage^.byte_order)),
              ' Visual^.depth=',dbgs(Visual^.depth),
              ' ImgDepth=',dbgs(ImgDepth),
              ' ARawImage.Description.BitsPerPixel=',dbgs(ARawImage.Description.BitsPerPixel),
              '');
            RaiseGDBException('TGtk2WidgetSet.CreateBitmapFromRawImage Incompatible BitsPerPixel');
          end;
          if ImgDataSize <> GdkImage^.bpl * ImgHeight
          then begin
            RaiseGDBException('TGtk2WidgetSet.CreateBitmapFromRawImage Incompatible DataSize');
          end;

          System.Move(ImgData^, GdkImage^.mem^, ImgDataSize);
          if ImgDepth = 1
          then CheckGdkImageBitOrder(GdkImage, GdkImage^.mem, ImgDataSize);
          GC := gdk_gc_new(Drawable);
          gdk_draw_image(Drawable, GC, GdkImage, 0, 0, 0, 0, ImgWidth, ImgHeight);
          gdk_gc_unref(GC);
          gdk_image_destroy(GdkImage);

          //DbgDumpPixmap(Drawable, 'CreateBitmaps');
        end;

        GdiObject^.GDIPixmapObject.Image := Drawable;
        GdiObject^.Visual := gdk_window_get_visual(Drawable);
        gdk_visual_ref(GdiObject^.Visual);
      end;
    end;
    
    if ASkipMask
    then begin
      Result := True;
      Exit;
    end;

    // create mask

    {$IFDEF VerboseRawImage}
    DebugLn('TGtk2WidgetSet.CreateBitmapFromRawImage creating mask .. ');
    {$ENDIF}

    if ARawImage.IsMasked(False)
    then Drawable := gdk_bitmap_create_from_data(nil, ImgMask, ImgWidth, ImgHeight)
    else begin
      Drawable := gdk_pixmap_new(nil, ImgWidth, ImgHeight, 1);
      // clear drawable, the contents of a new pixmap are indefined
      GC := gdk_gc_new(Drawable);
      gdk_draw_rectangle(Drawable, GC, 1, 0, 0, ImgWidth, ImgHeight);
      gdk_gc_unref(GC);
    end;

    GdiMaskObject := NewGDIObject(gdiBitmap);
    GdiMaskObject^.Depth := 1;
    GdiMaskObject^.GDIBitmapType := gbBitmap;
    GdiMaskObject^.GDIBitmapObject := Drawable;

    //DbgDumpBitmap(Drawable, 'CreateBitmaps - Mask');

    Result := True;
  except
    DeleteObject(ABitmap);
    ABitmap := 0;
    DeleteObject(AMask);
    AMask := 0;
  end;
end;

{------------------------------------------------------------------------------
  Function: RawImage_DescriptionFromBitmap
  Params: Bitmap: HBITMAP;
          Desc: PRawImageDescription
  Returns: boolean;

 ------------------------------------------------------------------------------}
function TGtk2WidgetSet.RawImage_DescriptionFromBitmap(ABitmap: HBITMAP; out ADesc: TRawImageDescription): boolean;
var
  GDIObject: PGDIObject absolute ABitmap;
begin
  Result := False;
  if not IsValidGDIObject(ABitmap)
  then begin
    DebugLn('WARNING: [TGtk2WidgetSet.GetBitmapRawImageDescription] invalid Bitmap!');
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
    DebugLn('WARNING: [TGtk2WidgetSet.RawImage_DescriptionFromBitmap] Unknown GDIBitmapType');
    Exit;
  end;
end;

{------------------------------------------------------------------------------
  function RawImage_DescriptionFromDevice
  Params: DC: HDC;
          Desc: PRawImageDescription
  Returns: boolean;

  Retrieves the information about the structure of the supported image data.
 ------------------------------------------------------------------------------}
function TGtk2WidgetSet.RawImage_DescriptionFromDevice(ADC: HDC; out
  ADesc: TRawImageDescription): Boolean;
var
  DevCon: TGtkDeviceContext absolute ADC;

  Drawable: PGdkDrawable;
  UseAlpha: Boolean;
begin
  UseAlpha := False;
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
end;

{------------------------------------------------------------------------------
  Function: RawImage_QueryDescription
  Params: AFlags:
          ADesc:
  Returns:

 ------------------------------------------------------------------------------}
function TGtk2WidgetSet.RawImage_QueryDescription(AFlags: TRawImageQueryFlags; var ADesc: TRawImageDescription): Boolean;
var
  Desc: TRawImageDescription;
begin
  Desc.Init;
  Result := RawImage_DescriptionFromDrawable(Desc, nil, riqfAlpha in AFlags);
  if not Result then Exit;

  if not (riqfUpdate in AFlags) then
    ADesc.Init;

  // if there's mask gtk2 assumes it's rgba (not XBM format).issue #12362
  if (riqfUpdate in AFlags) and (riqfMono in AFlags) and (riqfMask in AFlags) then
      AFlags := AFlags - [riqfMono] + [riqfRgb];

  if riqfMono in AFlags then
  begin
    ADesc.Format := ricfGray;
    ADesc.Depth := 1;
    ADesc.BitOrder := Desc.MaskBitOrder;
    ADesc.ByteOrder := riboLSBFirst;
    ADesc.LineOrder := Desc.LineOrder;
    ADesc.LineEnd := Desc.MaskLineEnd;
    ADesc.BitsPerPixel := Desc.MaskBitsPerPixel;
    ADesc.RedPrec := 1;
    ADesc.RedShift := Desc.MaskShift;
    // in theory only redshift is used, but if someone reads it as color thsi works too.
    ADesc.GreenPrec := 1;
    ADesc.GreenShift := Desc.MaskShift;
    ADesc.BluePrec := 1;
    ADesc.BlueShift := Desc.MaskShift;
  end
  else if riqfGrey in AFlags
  then begin
    ADesc.Format := ricfGray;
    ADesc.Depth := 8;
    ADesc.BitOrder := Desc.BitOrder;
    ADesc.ByteOrder := Desc.ByteOrder;
    ADesc.LineOrder := Desc.LineOrder;
    ADesc.LineEnd := Desc.LineEnd;
    ADesc.BitsPerPixel := 8;
    ADesc.RedPrec := 8;
    ADesc.RedShift := 0;
  end
  else
  if riqfRGB in AFlags then
  begin
    ADesc.Format := ricfRGBA;
    ADesc.Depth := Desc.Depth;
    ADesc.BitOrder := Desc.BitOrder;
    ADesc.ByteOrder := Desc.ByteOrder;
    ADesc.LineOrder := Desc.LineOrder;
    ADesc.LineEnd := Desc.LineEnd;
    ADesc.BitsPerPixel := Desc.BitsPerPixel;
    ADesc.RedPrec := Desc.RedPrec;
    ADesc.RedShift := Desc.RedShift;
    ADesc.GreenPrec := Desc.GreenPrec;
    ADesc.GreenShift := Desc.GreenShift;
    ADesc.BluePrec := Desc.BluePrec;
    ADesc.BlueShift := Desc.BlueShift;
  end;

  if riqfAlpha in AFlags then
  begin
    ADesc.AlphaPrec := Desc.AlphaPrec;
    ADesc.AlphaShift := Desc.AlphaShift;
  end;

  if riqfMask in AFlags then
  begin
    ADesc.MaskBitsPerPixel := Desc.MaskBitsPerPixel;
    ADesc.MaskShift := Desc.MaskShift;
    ADesc.MaskLineEnd := Desc.MaskLineEnd;
    ADesc.MaskBitOrder := Desc.MaskBitOrder;
  end;

(*
  //TODO
  if riqfPalette in AFlags
  then begin
    ADesc.PaletteColorCount := Desc.PaletteColorCount;
    ADesc.PaletteBitsPerIndex := Desc.PaletteBitsPerIndex;
    ADesc.PaletteShift := Desc.PaletteShift;
    ADesc.PaletteLineEnd := Desc.PaletteLineEnd;
    ADesc.PaletteBitOrder := Desc.PaletteBitOrder;
    ADesc.PaletteByteOrder := Desc.PaletteByteOrder;
  end;
*)
end;

{------------------------------------------------------------------------------
  function TGtk2WidgetSet.GetRawImageFromBitmap(SrcBitmap, SrcMaskBitmap: HBITMAP;
    const SrcRect: TRect; var NewRawImage: TRawImage): boolean; override;
 ------------------------------------------------------------------------------}
function TGtk2WidgetSet.RawImage_FromBitmap(out ARawImage: TRawImage; ABitmap, AMask: HBITMAP; ARect: PRect): Boolean;
var
  GdiBitmap: PGDIObject absolute ABitmap;
  GdiMask: PGDIObject absolute AMask;
  Drawable: PGdkDrawable;
  Bitmap: PGdkBitmap;
begin
  Result := false;
  {$IFDEF VerboseRawImage}
  DebugLn('TGtk2WidgetSet.GetRawImageFromBitmap A');
  {$ENDIF}
  ARawImage.Init;

  if not IsValidGDIObject(ABitmap)
  then begin
    DebugLn('WARNING: [TGtk2WidgetSet.RawImage_FromBitmap] invalid Bitmap!');
    exit;
  end;
  if (AMask <> 0) and not IsValidGDIObject(AMask)
  then begin
    DebugLn('WARNING: [TGtk2WidgetSet.RawImage_FromBitmap] invalid Mask');
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
      DebugLn('WARNING: [TGtk2WidgetSet.RawImage_FromBitmap] Unknown GDIBitmapType');
      Exit;
    end;
    {$IFDEF VerboseRawImage}
    DebugLn('TGtk2WidgetSet.RawImage_FromBitmap A GdkPixmap=',DbgS(Drawable),' SrcMaskBitmap=',DbgS(Bitmap));
    {$ENDIF}

    //DbgDumpPixmap(Drawable, 'RawImage_FromBitmap - drawable');
    //DbgDumpBitmap(Bitmap, 'RawImage_FromBitmap - alpha');

    Result := RawImage_FromDrawable(ARawImage, Drawable, Bitmap, ARect);
    if Result and (AMask <> 0)
    then begin
      if GdiMask^.GDIBitmapType <> gbBitmap
      then begin
        DebugLn('WARNING: [TGtk2WidgetSet.RawImage_FromBitmap] Unsupported GDIBitmapType for mask');
        Exit;
      end;
      
      Bitmap := GdiMask^.GDIBitmapObject;
      RawImage_AddMask(ARawImage, Bitmap, ARect);
      //DbgDumpBitmap(Bitmap, 'RawImage_FromBitmap - mask');
    end
    else
      ARawImage.Description.MaskBitsPerPixel := 0;

    if not Result
    then DebugLn('WARNING: [TGtk2WidgetSet.RawImage_FromBitmap] unable to GetRawImageFromGdkWindow Image');

  except
    ARawImage.FreeData;
  end;
end;

{------------------------------------------------------------------------------
  function TGtk2WidgetSet.GetRawImageFromDevice(SrcDC: HDC; const SrcRect: TRect;
    var NewRawImage: TRawImage): boolean;

 ------------------------------------------------------------------------------}
function TGtk2WidgetSet.RawImage_FromDevice(out ARawImage: TRawImage; ADC: HDC;
  const ARect: TRect): Boolean;
var
  DevCtx: TGtkDeviceContext absolute ADC;
  DCOrigin: TPoint;
  R: TRect;
  Drawable: PGdkDrawable;
begin
  Result := False;
  if not IsValidDC(ADC)
  then begin
    DebugLn('WARNING: TGtk2WidgetSet.GetRawImageFromDevice invalid SrcDC');
    Exit(False);
  end;

  DCOrigin := DevCtx.Offset;
  {$IFDEF VerboseRawImage}
  DebugLn('TGtk2WidgetSet.GetRawImageFromDevice A DCOrigin=',dbgs(DCOrigin.X),',',dbgs(DCOrigin.Y),' SrcRect=',dbgs(ARect.Left),',',dbgs(ARect.Top),',',dbgs(ARect.Right),',',dbgs(ARect.Bottom));
  {$ENDIF}
  R := ARect;
  LPtoDP(ADC, R, 2);
  OffSetRect(R, DCOrigin.x, DCOrigin.y);

  Drawable := DevCtx.Drawable;
  if Drawable = nil then
    // get screen shot
    Drawable := gdk_screen_get_root_window(gdk_screen_get_default);
  Result := RawImage_FromDrawable(ARawImage, Drawable, nil, @R);
end;

{------------------------------------------------------------------------------
  Function: GetControlConstraints
  Params: Constraints: TObject
  Returns: true on success

  Updates the constraints object (e.g. TSizeConstraints) with interface specific
  bounds.
 ------------------------------------------------------------------------------}
function TGtk2WidgetSet.GetControlConstraints(Constraints: TObject): boolean;
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
      //DebugLn('TGtk2WidgetSet.GetControlConstraints A '+dbgs(MinWidth)+','+dbgs(MinHeight),' ',dbgs(TScrollBar(SizeConstraints.Control).Kind=sbHorizontal),' ',TScrollBar(SizeConstraints.Control).Name);
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
        gtk_scale_set_draw_value(PGtkScale(Widget),
                                 TCustomTrackBar(SizeConstraints.Control).TickStyle <> tsNone);
        gtk_widget_size_request(Widget, @Widget^.Requisition);
        MinHeight:=Widget^.requisition.height;
      end else begin
        Widget:=GetStyleWidget(lgsVScale);
        gtk_scale_set_draw_value(PGtkScale(Widget),
                                 TCustomTrackBar(SizeConstraints.Control).TickStyle <> tsNone);
        gtk_widget_size_request(Widget, @Widget^.Requisition);
        MinWidth:=Widget^.requisition.width;
      end;
      //DebugLn(['TGtk2WidgetSet.GetControlConstraints ',DbgSName(SizeConstraints.Control),' ',MinWidth,',',MinHeight]);
    end;

    SizeConstraints.SetInterfaceConstraints(MinWidth,MinHeight,
                                            MaxWidth,MaxHeight);
  end;
end;

{------------------------------------------------------------------------------
  function TGtk2WidgetSet.GetLCLOwnerObject(Handle: HWnd): TObject;

 ------------------------------------------------------------------------------}
function TGtk2WidgetSet.GetLCLOwnerObject(Handle: HWnd): TObject;
begin
  if Handle<>0 then
    Result:=GetNearestLCLObject({%H-}PGtkWidget(Handle))
  else
    Result:=nil;
end;

function PromptUserBoxClosed(Widget : PGtkWidget; {%H-}Event : PGdkEvent;
  data: gPointer) : GBoolean; cdecl;
var
  ModalResult : PtrUInt;
begin
  { We were requested by window manager to close so return EscapeResult}
  if PInteger(data)^ = 0 then
  begin
    ModalResult:= {%H-}PtrUInt(g_object_get_data(PGObject(Widget), 'modal_result'));
    { Don't allow to close if we don't have a default return value }
    Result:= (ModalResult = 0);
    if not Result then PInteger(data)^:= ModalResult
    else DebugLn('Do not close !!!');
  end else Result:= false;
end;

function PromptUserButtonClicked(Widget : PGtkWidget; data: gPointer) : GBoolean; cdecl;
begin
  PInteger(data)^ := {%H-}PtrUInt(g_object_get_data(PGObject(Widget), 'modal_result'));
  Result := False;
end;


function gtk_message_dialog_get_message_area(Dialog:PGtkMessageDialog):PGtkWidget; cdecl; external gtklib;

procedure set_message_text(Dialog:PGtkMessageDialog;const msg: string;const is_pango_markup:boolean=false);
var
  ma:PGtkWidget;
  mainList:PgList;
begin
  if is_pango_markup then
    gtk_message_dialog_set_markup(Dialog, PGChar(msg))
  else
  begin
    ma:=gtk_message_dialog_get_message_area(Dialog);
    MainList := gtk_container_get_children(PGtkContainer(ma));
    if Assigned(MainList) then
    begin
      gtk_label_set_label(PGtkLabel(MainList^.data),PGChar(msg));
      g_list_free(MainList);
    end;

  end;
end;


function TGtk2WidgetSet.AskUser(const DialogCaption, DialogMessage: string; DialogType:
  LongInt; Buttons: TDialogButtons; HelpCtx: Longint): LongInt;

const
  ButtonResults : array[mrNone..mrYesToAll] of Longint = (
    -1, idButtonOK, idButtonCancel, idButtonAbort, idButtonRetry,
    idButtonIgnore, idButtonYes, idButtonNo, idButtonAll, idButtonNoToAll,
    idButtonYesToAll);

var
  Dialog: PGtkWidget;

  function ResponseID(const AnID: Integer): Integer;
  begin
    case AnID of
      idButtonOK       : Result := GTK_RESPONSE_OK;
      idButtonCancel   : Result := GTK_RESPONSE_CANCEL;
      idButtonHelp     : Result := GTK_RESPONSE_HELP;
      idButtonYes      : Result := GTK_RESPONSE_YES;
      idButtonNo       : Result := GTK_RESPONSE_NO;
      idButtonClose    : Result := GTK_RESPONSE_CLOSE;
      idButtonAbort    : Result := GTK_RESPONSE_REJECT;
      idButtonRetry    : Result := GTK_RESPONSE_LCL_RETRY;
      idButtonIgnore   : Result := GTK_RESPONSE_LCL_IGNORE;
      idButtonAll      : Result := GTK_RESPONSE_LCL_ALL;
      idButtonNoToAll  : Result := GTK_RESPONSE_LCL_NOTOALL;
      idButtonYesToAll : Result := GTK_RESPONSE_LCL_YESTOALL;
    else
      Result:=AnID;
    end;
  end;

  procedure CreateButton(const ALabel : String; const AResponse: Integer;
      const AImageHint: Integer = -1);
  var
    NewButton: PGtkWidget;
    BitmapHandle, MaskHandle: HBitmap;
    GDIObject: PGDIObject;
    Pixbuf: PGdkPixbuf;
    Mask: PGdkBitmap;
    Img: PGtkWidget;
  begin
    NewButton := gtk_dialog_add_button(PGtkDialog(Dialog),
      PgChar(Ampersands2Underscore(ALabel)), AResponse);
    gtk_button_set_use_underline(PGtkButton(NewButton), True);
    if AImageHint >= 0 then
    begin
      if ThemeServices.GetStockImage(AImageHint, BitmapHandle, MaskHandle) then
      begin
        GDIObject := {%H-}PGDIObject(BitmapHandle);
        Mask := nil;
        Pixbuf := nil;
        if GDIObject^.GDIBitmapType = gbPixbuf then
          Pixbuf := GDIObject^.GDIPixbufObject
        else
          Mask := CreateGdkMaskBitmap(BitmapHandle, MaskHandle);

        Img := gtk_image_new;

        if Pixbuf <> nil then
          gtk_image_set_from_pixbuf(PGtkImage(Img), Pixbuf)
        else
          gtk_image_set_from_pixmap(PGtkImage(Img), GDIObject^.GDIPixmapObject.Image, Mask);
        gtk_button_set_image(PGtkButton(NewButton), Img);
        if Mask <> nil then
          g_object_unref(Mask);
        DeleteObject(BitmapHandle);
        DeleteObject(MaskHandle);
      end;
    end;
  end;

var
  Btn: PGtkButton;
  BtnId: Longint;
  GtkDialogType: TGtkMessageType;
  BtnIdx: Integer;
  DefaultID, CancelID: Integer;
  X: Integer;
  MainList,ChildList: PGList;
  Title: String;
  ActiveWindow: HWND;
  BtnResult: LongInt;
  DlgBtn: TDialogButton;
  ADialogResult: Integer;
  Btns: TGtkButtonsType;
begin
  Result := mrNone;
  ReleaseCapture;

  if (Length(DialogMessage)>1000) then
  begin
    Result:=inherited;
    exit;
  end;

  ADialogResult := mrCancel;
  case DialogType of
    idDialogWarning: GtkDialogType := GTK_MESSAGE_WARNING;
    idDialogError: GtkDialogType := GTK_MESSAGE_ERROR;
    idDialogInfo : GtkDialogType := GTK_MESSAGE_INFO;
    idDialogConfirm : GtkDialogType := GTK_MESSAGE_QUESTION;
  else
    GtkDialogType := GTK_MESSAGE_INFO;
  end;

  Btns := GTK_BUTTONS_NONE;
  DefaultId := 0;
  CancelId := -1;
  for X := 0 to Buttons.Count - 1 do
  begin
    DlgBtn:=Buttons[X];
    if (Buttons.DefaultButton=DlgBtn)
    or ((Buttons.DefaultButton=nil) and DlgBtn.Default) then
      DefaultID := X;
    if (Buttons.CancelButton=DlgBtn)
    or ((Buttons.CancelButton=nil) and DlgBtn.Cancel)
    then begin
      CancelID := X;
      ADialogResult := DlgBtn.ModalResult;
    end;
  end;


  Dialog := gtk_message_dialog_new({$IFDEF HASX}PGtkWindow(GetDesktopWidget){$ELSE}nil{$ENDIF},
    GTK_DIALOG_MODAL, GtkDialogType, Btns,
     nil);

  set_message_text(PGtkMessageDialog(Dialog), PGChar(DialogMessage));

  g_signal_connect(PGtkObject(Dialog), 'delete-event',
    TGtkSignalFunc(@PromptUserBoxClosed),
    @ADialogResult);

  if Btns = GTK_BUTTONS_NONE then
  begin
    // gtk2 have reverted buttons eg. No, Yes
    for BtnIdx := Buttons.Count - 1 downto 0 do
    begin
      with Buttons[BtnIdx] do
        if (ModalResult >= Low(ButtonResults)) and (ModalResult <= High(ButtonResults)) then
        begin
          BtnID := ButtonResults[ModalResult];
          case BtnID of
            idButtonOK       : CreateButton(Caption, GTK_RESPONSE_OK, BtnID);
            idButtonCancel   : CreateButton(Caption, GTK_RESPONSE_CANCEL, BtnID);
            idButtonHelp     : CreateButton(Caption, GTK_RESPONSE_HELP, BtnID);
            idButtonYes      : CreateButton(Caption, GTK_RESPONSE_YES, BtnID);
            idButtonNo       : CreateButton(Caption, GTK_RESPONSE_NO, BtnID);
            idButtonClose    : CreateButton(Caption, GTK_RESPONSE_CLOSE, BtnID);
            idButtonAbort    : CreateButton(Caption, GTK_RESPONSE_REJECT, BtnID);
            idButtonRetry    : CreateButton(Caption, GTK_RESPONSE_LCL_RETRY, BtnID);
            idButtonIgnore   : CreateButton(Caption, GTK_RESPONSE_LCL_IGNORE, BtnID);
            idButtonAll      : CreateButton(Caption, GTK_RESPONSE_LCL_ALL, BtnID);
            idButtonNoToAll  : CreateButton(Caption, GTK_RESPONSE_LCL_NOTOALL, BtnID);
            idButtonYesToAll : CreateButton(Caption, GTK_RESPONSE_LCL_YESTOALL, BtnID);
          end;
        end else
          CreateButton(Caption, GTK_RESPONSE_NONE, BtnID); // user defined buttons
    end;
  end;

  MainList := gtk_container_children(PGtkContainer(PGtkDialog(Dialog)^.action_area));
  ChildList := MainList;
  BtnIdx := 0;
  while ChildList <> nil do
  begin
    if (ChildList^.Data <> nil) then
    begin
      if GTK_IS_BUTTON(ChildList^.Data) then
      begin
        Btn := PGtkButton(ChildList^.Data);
        DlgBtn := Buttons[BtnIdx];

        BtnID := -1;
        BtnResult:=DlgBtn.ModalResult;
        if (BtnResult>=Low(ButtonResults)) and (BtnResult<=High(ButtonResults)) then
          BtnID := ButtonResults[DlgBtn.ModalResult]
        else
          BtnID := DlgBtn.ModalResult;

        if (BtnIdx=CancelID) then
          g_object_set_data(PGObject(Dialog), 'modal_result', {%H-}Pointer(PtrInt(DlgBtn.ModalResult)));

        X := DlgBtn.ModalResult;
        g_object_set_data(PGObject(Btn), 'modal_result',
          {%H-}Pointer(PtrInt(X)));

        g_signal_connect(PGtkObject(Btn), 'clicked',
          TGtkSignalFunc(@PromptUserButtonClicked), @ADialogResult);

        if DefaultID = BtnIdx then
        begin
          gtk_dialog_set_default_response(PGtkDialog(Dialog),  BtnID);
          gtk_widget_grab_focus(PgtkWidget(Btn));
          X := DlgBtn.ModalResult;
          if CancelID<0 then
            g_object_set_data(PGObject(Dialog), 'modal_result',
              {%H-}Pointer(PtrInt(X)));
        end;

        inc(BtnIdx);
      end;
    end;
    ChildList := g_list_next(ChildList);
  end;
  if MainList <> nil then
    g_list_free(MainList);

  if DialogCaption <> '' then
    gtk_window_set_title(PGtkWindow(Dialog), PGChar(DialogCaption))
  else
  begin
    Title := '';
    case DialogType of
      idDialogWarning: Title := rsMtWarning;
      idDialogError: Title := rsMtError;
      idDialogInfo : Title := rsMtInformation;
      idDialogConfirm : Title := rsMtConfirmation;
    end;
    gtk_window_set_title(PGtkWindow(Dialog), PGChar(Title));
  end;

  if (gtk_major_version = 2) and (gtk_minor_version <= 12) then
  begin
    ActiveWindow := GetActiveWindow;
    if ActiveWindow <> 0 then
      gtk_window_set_transient_for(PGtkWindow(Dialog), {%H-}PGtkWindow(ActiveWindow));
  end;
  gtk_dialog_run(PGtkDialog(Dialog));
  gtk_widget_destroy(Dialog);
  Result := ADialogResult;
end;

function TGtk2WidgetSet.PromptUser(const DialogCaption: string;
  const DialogMessage: string; DialogType: LongInt; Buttons: PLongInt;
  ButtonCount: LongInt; DefaultIndex: LongInt; EscapeResult: LongInt): LongInt;
var
  Btn: PGtkButton;
  Dialog: PGtkWidget;
  ADialogResult: Integer;
  GtkDialogType: TGtkMessageType;
  Btns: TGtkButtonsType;
  BtnIdx: Integer;
  DefaultID: Integer;
  X: Integer;
  MainList,ChildList: PGList;
  Title: String;
  ActiveWindow: HWND;
  QuotedMessage: Pgchar;

  procedure CreateButton(const ALabel : String; const AResponse: Integer);
  var
    NewButton: PGtkButton;
  begin
    NewButton := PGtkButton(gtk_dialog_add_button(PGtkDialog(Dialog),
      PgChar(Ampersands2Underscore(ALabel)), AResponse));
    gtk_button_set_use_underline(NewButton, True);
  end;

  function tr(UseWidgetStr: boolean; const TranslatedStr, WidgetStr: String): string;
  begin
    if UseWidgetStr then
      Result:=WidgetStr
    else
      Result:=TranslatedStr;
  end;

  function ResponseID(const AnID: Integer): Integer;
  begin
    case AnID of
      idButtonOK       : Result := GTK_RESPONSE_OK;
      idButtonCancel   : Result := GTK_RESPONSE_CANCEL;
      idButtonHelp     : Result := GTK_RESPONSE_HELP;
      idButtonYes      : Result := GTK_RESPONSE_YES;
      idButtonNo       : Result := GTK_RESPONSE_NO;
      idButtonClose    : Result := GTK_RESPONSE_CLOSE;
      idButtonAbort    : Result := GTK_RESPONSE_REJECT;
      idButtonRetry    : Result := GTK_RESPONSE_LCL_RETRY;
      idButtonIgnore   : Result := GTK_RESPONSE_LCL_IGNORE;
      idButtonAll      : Result := GTK_RESPONSE_LCL_ALL;
      idButtonNoToAll  : Result := GTK_RESPONSE_LCL_NOTOALL;
      idButtonYesToAll : Result := GTK_RESPONSE_LCL_YESTOALL;
    end;
  end;

begin
  Result := -1;
  ReleaseCapture;
  ADialogResult := EscapeResult;
  case DialogType of
    idDialogWarning: GtkDialogType := GTK_MESSAGE_WARNING;
    idDialogError: GtkDialogType := GTK_MESSAGE_ERROR;
    idDialogInfo : GtkDialogType := GTK_MESSAGE_INFO;
    idDialogConfirm : GtkDialogType := GTK_MESSAGE_QUESTION;
  else
    GtkDialogType := GTK_MESSAGE_INFO;
  end;

  Btns := GTK_BUTTONS_NONE;
  DefaultId := 0;
  for X := 0 to ButtonCount - 1 do
  begin
    if X = DefaultIndex then
      DefaultID := Buttons[X];
  end;

  Dialog := gtk_message_dialog_new({$IFDEF HASX}PGtkWindow(GetDesktopWidget){$ELSE}nil{$ENDIF},
    GTK_DIALOG_MODAL, GtkDialogType, Btns,
    nil);

  // Can't pass message string to gtk_message_dialog_new, as % chars are interpreted
  // gtk_message_dialog_set_markup interpets HTML, so we need to quote that
  QuotedMessage := g_markup_escape_text(PGChar(DialogMessage), Length(DialogMessage));
  gtk_message_dialog_set_markup(PGtkMessageDialog(Dialog), QuotedMessage);
  g_free(QuotedMessage);
  g_signal_connect(PGtkObject(Dialog), 'delete-event',
    TGtkSignalFunc(@PromptUserBoxClosed),
    @ADialogResult);

  if Btns = GTK_BUTTONS_NONE then
  begin
    // gtk2 have reverted buttons eg. No, Yes
    for BtnIdx := ButtonCount-1 downto 0 do
    begin
      case Buttons[BtnIdx] of
        idButtonOK       : CreateButton(tr(rsmbOK='&OK',rsmbOK, 'gtk-ok'), GTK_RESPONSE_OK);
        idButtonCancel   : CreateButton(tr(rsmbCancel='Cancel',rsmbCancel,'gtk-cancel'), GTK_RESPONSE_CANCEL);
        idButtonHelp     : CreateButton(tr(rsmbHelp='&Help',rsmbHelp,'gtk-help'), GTK_RESPONSE_HELP);
        idButtonYes      : CreateButton(tr(rsmbYes='&Yes',rsmbYes,'gtk-yes'), GTK_RESPONSE_YES);
        idButtonNo       : CreateButton(tr(rsmbNo='&No',rsmbNo,'gtk-no'), GTK_RESPONSE_NO);
        idButtonClose    : CreateButton(tr(rsmbClose='&Close',rsmbClose,'gtk-close'), GTK_RESPONSE_CLOSE);
        idButtonAbort    : CreateButton(rsMBAbort, GTK_RESPONSE_REJECT);
        idButtonRetry    : CreateButton(rsMBRetry, GTK_RESPONSE_LCL_RETRY);
        idButtonIgnore   : CreateButton(rsMBIgnore, GTK_RESPONSE_LCL_IGNORE);
        idButtonAll      : CreateButton(rsMbAll, GTK_RESPONSE_LCL_ALL);
        idButtonNoToAll  : CreateButton(rsMBNoToAll, GTK_RESPONSE_LCL_NOTOALL);
        idButtonYesToAll : CreateButton(rsMBYesToAll, GTK_RESPONSE_LCL_YESTOALL);
      end;
    end;
  end;

  MainList := gtk_container_children(PGtkContainer(PGtkDialog(Dialog)^.action_area));
  ChildList := MainList;
  BtnIdx := 0;

  while ChildList <> nil do
  begin
    if (ChildList^.Data <> nil) then
    begin
      if GTK_IS_BUTTON(ChildList^.Data) then
      begin
        Btn := PGtkButton(ChildList^.Data);

        if Buttons[BtnIdx] = idButtonCancel then
          g_object_set_data(PGObject(Dialog), 'modal_result', Pointer(idButtonCancel));

        X := Buttons[BtnIdx];
        g_object_set_data(PGObject(Btn), 'modal_result',
          {%H-}Pointer(PtrInt(X)));

        g_signal_connect(PGtkObject(Btn), 'clicked',
          TGtkSignalFunc(@PromptUserButtonClicked), @ADialogResult);

        if DefaultID = Buttons[BtnIdx] then
        begin
          gtk_dialog_set_default_response(PGtkDialog(Dialog), ResponseID(Buttons[BtnIdx]));
          X := Buttons[BtnIdx];
          g_object_set_data(PGObject(Dialog), 'modal_result',
            {%H-}Pointer(PtrInt(X)));
        end;

        inc(BtnIdx);
      end;
    end;
    ChildList := g_list_next(ChildList);
  end;
  if MainList <> nil then
    g_list_free(MainList);

  if DialogCaption <> '' then
    gtk_window_set_title(PGtkWindow(Dialog), PGChar(DialogCaption))
  else
  begin
    Title := '';
    case DialogType of
      idDialogWarning: Title := rsMtWarning;
      idDialogError: Title := rsMtError;
      idDialogInfo : Title := rsMtInformation;
      idDialogConfirm : Title := rsMtConfirmation;
    end;
    gtk_window_set_title(PGtkWindow(Dialog), PGChar(Title));
  end;

  ActiveWindow := GetActiveWindow;
  if ActiveWindow <> 0 then
    gtk_window_set_transient_for(PGtkWindow(Dialog), {%H-}PGtkWindow(ActiveWindow));
  // the following line keeps the old behaviour making the dialog appear
  // at screen center instead of at ActiveWindow center
  gtk_window_set_position(PGtkWindow(Dialog), GTK_WIN_POS_CENTER);

  gtk_dialog_run(PGtkDialog(Dialog));
  gtk_widget_destroy(Dialog);
  Result := ADialogResult;
end;

function TGtk2WidgetSet.SetComboMinDropDownSize(Handle: HWND; MinItemsWidth,
  MinItemsHeight, MinItemCount: integer): boolean;
var
  p: PGtkWidget;
  Menu: PGtkWidget;
  Requisition: TGtkRequisition;
begin
  Result:=True;
  p := GetWidgetInfo({%H-}Pointer(Handle))^.CoreWidget;
  
  Menu := PGtkWidget(g_object_get_data(G_OBJECT(p), 'Menu'));
  if Menu<>nil then begin
    Requisition.width := MinItemsWidth;
    Requisition.height := MinItemsHeight * MinItemCount;
    gtk_widget_size_request(Menu, @Requisition);
  end;
end;


//##apiwiz##eps##   // Do not remove, no wizard declaration after this line


function waithandle_iocallback({%H-}source: PGIOChannel; condition: TGIOCondition;
  data: gpointer): gboolean; cdecl;
var
  lEventHandler: PWaitHandleEventHandler absolute data;
begin
  //debugln('waithandle_iocallback lEventHandler=',HexStr(Cardinal(lEventHandler),8));
  lEventHandler^.OnEvent(lEventHandler^.UserData, condition);
  Result := true;
end;

function TGtk2WidgetSet.AddEventHandler(AHandle: THandle; AFlags: dword;
  AEventHandler: TWaitHandleEvent; AData: PtrInt): PEventHandler;
var
  giochannel: pgiochannel;
  lEventHandler: PWaitHandleEventHandler;
begin
  if AEventHandler = nil then exit;
  New(lEventHandler);
  giochannel := g_io_channel_unix_new(AHandle);
  lEventHandler^.Handle := AHandle;
  lEventHandler^.UserData := AData;
  lEventHandler^.GIOChannel := giochannel;
  lEventHandler^.OnEvent := AEventHandler;
  lEventHandler^.GSourceID := g_io_add_watch(giochannel,
    AFlags, @waithandle_iocallback, lEventHandler);
  //debugln('TGtk2WidgetSet.AddEventHandler lEventHandler=',HexStr(Cardinal(lEventHandler),8),' AHandle=',dbgs(lEventHandler^.Handle));
  lEventHandler^.PrevHandler := nil;
  lEventHandler^.NextHandler := FWaitHandles;
  if FWaitHandles <> nil then
    FWaitHandles^.PrevHandler := lEventHandler;
  FWaitHandles := lEventHandler;
  Result := lEventHandler;
end;


procedure TGtk2WidgetSet.RemoveEventHandler(var AHandler: PEventHandler);
var
  lEventHandler: PWaitHandleEventHandler absolute AHandler;
begin
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
  //debugln('TGtk2WidgetSet.RemoveEventHandler lEventHandler=',HexStr(Cardinal(lEventHandler),8),' AHandle=',dbgs(lEventHandler^.Handle));
  Dispose(lEventHandler);
  AHandler := nil;
end;

procedure TGtk2WidgetSet.SetEventHandlerFlags(AHandler: PEventHandler; NewFlags: dword);
var
  lEventHandler: PWaitHandleEventHandler absolute AHandler;
begin
  if AHandler = nil then exit;
  g_source_remove(lEventHandler^.GSourceID);
  lEventHandler^.GSourceID := g_io_add_watch(lEventHandler^.GIOChannel,
    NewFlags, @waithandle_iocallback, lEventHandler);
  //debugln('TGtk2WidgetSet.SetEventHandlerFlags lEventHandler=',HexStr(Cardinal(lEventHandler),8),' AHandle=',dbgs(lEventHandler^.Handle));
end;

procedure TGtk2WidgetSet.SetRubberBandRect(const ARubberBand: HWND; const ARect: TRect);
begin
  if ARubberBand = 0 then
    exit;
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

function TGtk2WidgetSet.AddPipeEventHandler(AHandle: THandle;
  AEventHandler: TPipeEvent; AData: PtrInt): PPipeEventHandler;
var
  lPipeEventInfo: PPipeEventInfo;
begin
  if AEventHandler = nil then exit;
  New(lPipeEventInfo);
  lPipeEventInfo^.UserData := AData;
  lPipeEventInfo^.OnEvent := AEventHandler;
  lPipeEventInfo^.Handler := AddEventHandler(AHandle, G_IO_IN or G_IO_HUP or G_IO_OUT,
    @HandlePipeEvent, {%H-}PtrUInt(lPipeEventInfo));
  Result := lPipeEventInfo;
end;

procedure TGtk2WidgetSet.HandlePipeEvent(AData: PtrInt; AFlags: dword);
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

procedure TGtk2WidgetSet.RemovePipeEventHandler(var AHandler: PPipeEventHandler);
var
  lPipeEventInfo: PPipeEventInfo absolute AHandler;
begin
  if AHandler = nil then exit;
  RemoveEventHandler(lPipeEventInfo^.Handler);
  Dispose(lPipeEventInfo);
  AHandler := nil;
end;

{$ifdef UNIX}
function TGtk2WidgetSet.AddProcessEventHandler(AHandle: THandle;
  AEventHandler: TChildExitEvent; AData: PtrInt): PProcessEventHandler;
var
  lHandler: PChildSignalEventHandler;
begin
  if AEventHandler = nil then exit(nil);
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
end;

procedure TGtk2WidgetSet.RemoveProcessEventHandler(var AHandler: PProcessEventHandler);
var
  lHandler: PChildSignalEventHandler absolute AHandler;
begin
  if AHandler = nil then exit;
  if lHandler^.PrevHandler = nil then
    FChildSignalHandlers := lHandler^.NextHandler
  else
    lHandler^.PrevHandler^.NextHandler := lHandler^.NextHandler;
  if lHandler^.NextHandler <> nil then
    lHandler^.NextHandler^.PrevHandler := lHandler^.PrevHandler;
  Dispose(lHandler);
  AHandler := nil;
end;
{$else}
{$IFDEF VerboseGtkToDos}{$warning TGtk2WidgetSet.RemoveProcessEventHandler and TGtk2WidgetSet.AddProcessEventHandler not implemented on this OS}{$ENDIF}
//PChildSignalEventHandler is only defined on unix
function TGtk2WidgetSet.AddProcessEventHandler(AHandle: THandle;
  AEventHandler: TChildExitEvent; AData: PtrInt): PProcessEventHandler;
begin
  Result := nil;
end;

procedure TGtk2WidgetSet.RemoveProcessEventHandler(var AHandler: PProcessEventHandler);
begin
end;
{$endif}


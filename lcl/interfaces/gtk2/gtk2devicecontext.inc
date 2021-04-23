{%MainUnit gtk2def.pp}

{******************************************************************************
                                   TGtk2DeviceContext
 ******************************************************************************

 *****************************************************************************
  This file is part of the Lazarus Component Library (LCL)

  See the file COPYING.modifiedLGPL.txt, included in this distribution,
  for details about the license.
 *****************************************************************************
}

{$IFOPT C-}
// Uncomment for local trace
//  {$C+}
//  {$DEFINE ASSERT_IS_ON}
{$ENDIF}

{ TDeviceContext }

procedure TGtkDeviceContext.SetClipRegion(const AValue: PGdiObject);
begin
  ChangeGDIObject(fClipRegion, AValue);
end;

function TGtkDeviceContext.GetGDIObjects(ID: TGDIType): PGdiObject;
begin
  case ID of
    gdiBitmap: Result:=CurrentBitmap;
    gdiFont: Result:=CurrentFont;
    gdiBrush: Result:=CurrentBrush;
    gdiPen: Result:=CurrentPen;
    gdiPalette: Result:=CurrentPalette;
    gdiRegion: Result:=ClipRegion;
  end;
end;

function TGtkDeviceContext.GetClipRectangle: TGdkRectangle;
var
  X,Y: gint;
begin
  if FClipRegion = nil then
  begin
    if (PaintRectangle.Left<>0) or (PaintRectangle.Top<>0) or
      (PaintRectangle.Right<>0) or (PaintRectangle.Bottom<>0) then
      Result := GdkRectFromRect(PaintRectangle)
    else
    begin
      gdk_window_get_size(Drawable, @X, @Y);
      Result := GdkRectFromRect(Rect(0,0, X, Y));
    end;
  end else
    gdk_region_get_clipbox(FClipRegion^.GDIRegionObject, @Result);
end;

function TGtkDeviceContext.GetOffset: TPoint;
var
  Fixed: Pointer;
  AChild: PGtkWidget;
  AColumn: PGtkTreeViewColumn;
  Area: TGdkRectangle;
  h: gint;
  w: gint;
  yoffs: gint;
  xoffs: gint;
begin
  Result := Point(0, 0);
  if Assigned(FWidget) then
  begin
    Fixed := GetFixedWidget(FWidget);
    if GTK_WIDGET_NO_WINDOW(FWidget) and
       GTK_WIDGET_NO_WINDOW(Fixed) and
       not GtkWidgetIsA(FWidget, GTKAPIWidget_GetType) then
    begin
      Inc(Result.X, FWidget^.Allocation.x);
      Inc(Result.y, FWidget^.Allocation.y);
    end;
    if (GTK_IS_SCROLLED_WINDOW(FWidget) and GTK_IS_BIN(FWidget)) or (GTK_IS_TREE_VIEW(FWidget)) then
    begin
      if GTK_IS_TREE_VIEW(FWidget) then
        AChild := FWidget
      else
        AChild := gtk_bin_get_child(PGtkBin(FWidget));
      if GTK_IS_TREE_VIEW(AChild) and gtk_tree_view_get_headers_visible(PGtkTreeView(AChild)) then
      begin
        AColumn := gtk_tree_view_get_column(PGtkTreeView(AChild), 0);
        gtk_tree_view_column_cell_get_size(AColumn, @Area, @xoffs, @yoffs, @w, @h);
        // borders are 2px
        dec(Result.y, h - 2);
      end;
    end;
  end;
end;

function TGtkDeviceContext.GetOwnedGDIObjects(ID: TGDIType): PGdiObject;
begin
  Result:=fOwnedGDIObjects[ID];
end;

procedure TGtkDeviceContext.SetCurrentBitmap(const AValue: PGdiObject);
begin
  ChangeGDIObject(FCurrentBitmap,AValue);
end;

procedure TGtkDeviceContext.SetCurrentBrush(const AValue: PGdiObject);
begin
  ChangeGDIObject(FCurrentBrush,AValue);
  if FSelectedColors = dcscBrush then
    FSelectedColors := dcscCustom;
end;

procedure TGtkDeviceContext.SetCurrentFont(const AValue: PGdiObject);
begin
  ChangeGDIObject(FCurrentFont,AValue);
  if FHasTransf then
    TransfUpdateFont;
end;

procedure TGtkDeviceContext.SetCurrentPalette(const AValue: PGdiObject);
begin
  ChangeGDIObject(FCurrentPalette,AValue);
end;

procedure TGtkDeviceContext.SetCurrentPen(const AValue: PGdiObject);
begin
  ChangeGDIObject(FCurrentPen,AValue);
  if FSelectedColors = dcscPen then
    FSelectedColors := dcscCustom;
  if FHasTransf then
    TransfUpdatePen;
end;

procedure TGtkDeviceContext.ChangeGDIObject(var GDIObject: PGdiObject;
  const NewValue: PGdiObject);
begin
  if GdiObject = NewValue then exit;
  if GdiObject <> nil then
  begin
    dec(GdiObject^.DCCount);
    if GdiObject^.DCCount < 0 then
      RaiseGDBException('');
    ReleaseGDIObject(GDIObject);
  end;

  GdiObject := NewValue;

  if GdiObject <> nil then
  begin
    inc(GdiObject^.DCCount);
    ReferenceGDIObject(GDIObject);
  end;
end;

procedure TGtkDeviceContext.SetGDIObjects(ID: TGDIType; const AValue: PGdiObject);
begin
  case ID of
    gdiBitmap:  ChangeGDIObject(fCurrentBitmap,AValue);
    gdiFont:    ChangeGDIObject(fCurrentFont,AValue);
    gdiBrush:   ChangeGDIObject(fCurrentBrush,AValue);
    gdiPen:     ChangeGDIObject(fCurrentPen,AValue);
    gdiPalette: ChangeGDIObject(fCurrentPalette,AValue);
    gdiRegion:  ChangeGDIObject(fClipRegion,AValue);
  end;
end;

procedure TGtkDeviceContext.SetMapMode(AValue: Integer);
begin
  if AValue <> FMapMode then
  begin
    case AValue of
      MM_ANISOTROPIC:; // user's choice
      MM_ISOTROPIC:; // adjusted after each SetViewPortExtEx call (see MSDN for details)
      MM_HIENGLISH: FWindowExt := Point(1000, -1000);
      MM_HIMETRIC: FWindowExt := Point(2540, -2540);
      MM_LOENGLISH: FWindowExt := Point(100, -100);
      MM_LOMETRIC: FWindowExt := Point(254, -254);
      MM_TWIPS: FWindowExt := Point(1440, -1440);
    else
      AValue := MM_TEXT;
      FWindowExt := Point(1, 1);
      FViewPortExt := Point(1, 1);
    end;
    FMapMode := AValue;
    // to do: combine with affine transformations here when they get implemented
    FHasTransf :=
      (FMapMode <> MM_TEXT) or
      (FViewPortOrg.x <> 0) or
      (FViewPortOrg.y <> 0) or
      (FWindowOrg.x <> 0) or
      (FWindowOrg.y <> 0);
    if not (FMapMode in [MM_TEXT, MM_ANISOTROPIC, MM_ISOTROPIC]) then
    begin
      FViewPortExt.X := Gtk2WidgetSet.GetDeviceCaps(HDC(Self), LOGPIXELSX);
      FViewPortExt.Y := Gtk2WidgetSet.GetDeviceCaps(HDC(Self), LOGPIXELSY);
    end;
    TransfUpdateFont;
    TransfUpdatePen;
  end;
end;

procedure TGtkDeviceContext.SetOwnedGDIObjects(ID: TGDIType;
  const AValue: PGdiObject);
begin
//MWE: this is not right. all objects except bitmaps can be selected in more than one DC

  if fOwnedGDIObjects[ID]=AValue then exit;
  if fOwnedGDIObjects[ID]<>nil then
    fOwnedGDIObjects[ID]^.Owner:=nil;
  fOwnedGDIObjects[ID]:=AValue;
  if fOwnedGDIObjects[ID]<>nil then
    fOwnedGDIObjects[ID]^.Owner:=Self;
end;

procedure TGtkDeviceContext.SetROP2(AROP: Integer);
var
  Func: TGdkFunction;
begin
  case AROP of
    R2_COPYPEN:     Func := GDK_COPY;
    R2_NOT:         Func := GDK_INVERT;
    R2_XORPEN:      Func := GDK_XOR;
    R2_BLACK:       Func := GDK_CLEAR;
    R2_MASKPEN:     Func := GDK_AND;
    R2_MASKPENNOT:  Func := GDK_AND_REVERSE;
    R2_MASKNOTPEN:  Func := GDK_AND_INVERT;
    R2_NOP:         Func := GDK_NOOP;
    R2_MERGEPEN:    Func := GDK_OR;
    R2_NOTXORPEN:   Func := GDK_EQUIV;
    R2_MERGEPENNOT: Func := GDK_OR_REVERSE;
    R2_NOTCOPYPEN:  Func := GDK_COPY_INVERT;
    R2_NOTMASKPEN:  Func := GDK_NAND;
    //R2_NOTMERGEPEN: Func := GDK_NOR;
    R2_WHITE:       Func := GDK_SET;
  else
    Func := GDK_COPY;
  end;

  gdk_gc_set_function(GC, Func);
  gdk_gc_get_values(GC, @FGCValues);
end;

procedure TGtkDeviceContext.SetViewPortExt(const AValue: TPoint);
var
  Ratio: Single;
begin
  if (AValue.x <> FViewPortExt.x) or (AValue.y <> FViewPortExt.y) and
    (FMapMode in [MM_ISOTROPIC, MM_ANISOTROPIC]) then
  begin
    if FMapMode = MM_ISOTROPIC then
    begin
      // TK: Is here also an adjustment on Windows if DPIX and DPIY are different?
      Ratio := FWindowExt.x / FWindowExt.y; // no check, programmer cannot put nonsense
      if AValue.y * Ratio > AValue.x then
        FViewPortExt := Point(AValue.x, RoundToInt(AValue.x / Ratio))
      else if AValue.y * Ratio < AValue.x then
        FViewPortExt := Point(RoundToInt(AValue.y * Ratio), AValue.y)
      else
        FViewPortExt := AValue;
    end else
      FViewPortExt := AValue;
    TransfUpdateFont;
    TransfUpdatePen;
  end;
end;

procedure TGtkDeviceContext.SetViewPortOrg(const AValue: TPoint);
begin
  if (FViewPortOrg.x <> AValue.x) or
     (FViewPortOrg.y <> AValue.y) then
  begin
    FViewPortOrg := AValue;
    FHasTransf := True;
  end;
end;

procedure TGtkDeviceContext.SetWindowExt(const AValue: TPoint);
begin
  if (AValue.x <> FWindowExt.x) or (AValue.y <> FWindowExt.y) and
    (FMapMode in [MM_ISOTROPIC, MM_ANISOTROPIC]) then
  begin
    FWindowExt := AValue;
    if FMapMode = MM_ANISOTROPIC then
    begin
      TransfUpdateFont;
      TransfUpdatePen;
    end;
  end;
end;

procedure TGtkDeviceContext.SetWindowOrg(AValue: TPoint);
begin
  if (FWindowOrg.x <> AValue.x) or
     (FWindowOrg.y <> AValue.y) then
  begin
    FWindowOrg := AValue;
    FHasTransf := True;
  end;
end;

procedure TGtkDeviceContext.SetSelectedColors(AValue: TDevContextSelectedColorsType);
begin
  if FSelectedColors = AValue then Exit;
  FSelectedColors := AValue;

  case FSelectedColors of
    dcscPen: SelectPenProps;
    dcscBrush: SelectBrushProps;
    dcscFont: SelectTextProps;
  end;
end;

procedure TGtkDeviceContext.SetTextMetricsValid(AValid: Boolean);
begin
  if AValid then
    Include(FFlags, dcfTextMetricsValid)
  else
    Exclude(FFlags, dcfTextMetricsValid);
end;

procedure TGtkDeviceContext.RemovePixbuf;
begin
  if Assigned(FPixbuf) then
  begin
    gdk_pixbuf_unref(FPixbuf);
    FPixbuf := nil;
  end;
end;

procedure TGtkDeviceContext.InvTransfPoint(var X1, Y1: Integer);
begin
  X1 := MulDiv(X1 + FWindowOrg.x - FViewPortOrg.x, FWindowExt.x, FViewPortExt.x);
  Y1 := MulDiv(Y1 + FWindowOrg.y - FViewPortOrg.y, FWindowExt.y, FViewPortExt.y);
  // to do: put affine inverse transformation here (for all Inv.. methods)
end;

function TGtkDeviceContext.InvTransfPointIndirect(const P: TPoint): TPoint;
begin
  Result.X := MulDiv(P.X + FWindowOrg.x - FViewPortOrg.x, FWindowExt.x, FViewPortExt.x);
  Result.Y := MulDiv(P.Y + FWindowOrg.y - FViewPortOrg.y, FWindowExt.y, FViewPortExt.y);
end;

procedure TGtkDeviceContext.InvTransfRect(var X1, Y1, X2, Y2: Integer);
begin
  X1 := MulDiv(X1 + FWindowOrg.x - FViewPortOrg.x, FWindowExt.x, FViewPortExt.x);
  Y1 := MulDiv(Y1 + FWindowOrg.y - FViewPortOrg.y, FWindowExt.y, FViewPortExt.y);
  X2 := MulDiv(X2 + FWindowOrg.x - FViewPortOrg.x, FWindowExt.x, FViewPortExt.x);
  Y2 := MulDiv(Y2 + FWindowOrg.y - FViewPortOrg.y, FWindowExt.y, FViewPortExt.y);
end;

function TGtkDeviceContext.InvTransfRectIndirect(const R: TRect): TRect;
begin
  Result.Left := MulDiv(R.Left + FWindowOrg.x - FViewPortOrg.x, FWindowExt.x, FViewPortExt.x);
  Result.Top := MulDiv(R.Top + FWindowOrg.y - FViewPortOrg.y, FWindowExt.y, FViewPortExt.y);
  Result.Right := MulDiv(R.Right + FWindowOrg.x - FViewPortOrg.x, FWindowExt.x, FViewPortExt.x);
  Result.Bottom := MulDiv(R.Bottom + FWindowOrg.y - FViewPortOrg.y, FWindowExt.y, FViewPortExt.y);
end;

procedure TGtkDeviceContext.InvTransfExtent(var ExtX, ExtY: Integer);
begin
  ExtX := MulDiv(ExtX, FWindowExt.x, FViewPortExt.x);
  ExtY := MulDiv(ExtY, FWindowExt.y, FViewPortExt.y);
end;

function TGtkDeviceContext.InvTransfExtentIndirect(const Extent: TPoint): TPoint;
begin
  Result.X := MulDiv(Extent.X, FWindowExt.x, FViewPortExt.x);
  Result.Y := MulDiv(Extent.Y, FWindowExt.y, FViewPortExt.y);
end;

procedure TGtkDeviceContext.TransfAngles(var Angle1, Angle2: Integer);
begin
  if FWindowExt.x * FViewPortExt.x < 0 then
  begin
    // flip angles along 90-270 degree axis
    Angle1 := 2880 - Angle1;
    Angle2 := 2880 - Angle2;
  end;
  if FWindowExt.y * FViewPortExt.y < 0 then
  begin
    // flip angles along 0-180 degree axis
    Angle1 := 5760 - Angle1;
    Angle2 := 5760 - Angle2;
  end;
end;

procedure TGtkDeviceContext.TransfNormalize(var Lower, Higher: Integer);
var
  Tmp: Integer;
begin
  if Lower > Higher then
  begin
    Tmp := Lower;
    Lower := Higher;
    Higher := Tmp;
  end;
end;

procedure TGtkDeviceContext.TransfPoint(var X1, Y1: Integer);
begin
  // to do: put affine transformation here (for all Transf.. methods)
  X1 := MulDiv(X1, FViewPortExt.x, FWindowExt.x) + FViewPortOrg.x - FWindowOrg.x;
  Y1 := MulDiv(Y1, FViewPortExt.y, FWindowExt.y) + FViewPortOrg.y - FWindowOrg.y;
end;

function TGtkDeviceContext.TransfPointIndirect(const P: TPoint): TPoint;
begin
  Result.x := MulDiv(P.x, FViewPortExt.x, FWindowExt.x) + FViewPortOrg.x - FWindowOrg.x;
  Result.Y := MulDiv(P.y, FViewPortExt.y, FWindowExt.y) + FViewPortOrg.y - FWindowOrg.y;
end;

procedure TGtkDeviceContext.TransfRect(var X1, Y1, X2, Y2: Integer);
begin
  X1 := MulDiv(X1, FViewPortExt.x, FWindowExt.x) + FViewPortOrg.x - FWindowOrg.x;
  Y1 := MulDiv(Y1, FViewPortExt.y, FWindowExt.y) + FViewPortOrg.y - FWindowOrg.y;
  X2 := MulDiv(X2, FViewPortExt.x, FWindowExt.x) + FViewPortOrg.x - FWindowOrg.x;
  Y2 := MulDiv(Y2, FViewPortExt.y, FWindowExt.y) + FViewPortOrg.y - FWindowOrg.y;
end;

function TGtkDeviceContext.TransfRectIndirect(const R: TRect): TRect;
begin
  Result.Left := MulDiv(R.Left, FViewPortExt.x, FWindowExt.x) + FViewPortOrg.x - FWindowOrg.x;
  Result.Top := MulDiv(R.Top, FViewPortExt.y, FWindowExt.y) + FViewPortOrg.y - FWindowOrg.y;
  Result.Right := MulDiv(R.Right, FViewPortExt.x, FWindowExt.x) + FViewPortOrg.x - FWindowOrg.x;
  Result.Bottom := MulDiv(R.Bottom, FViewPortExt.y, FWindowExt.y) + FViewPortOrg.y - FWindowOrg.y;
end;

procedure TGtkDeviceContext.TransfExtent(var ExtX, ExtY: Integer);
begin
  ExtX := MulDiv(ExtX, FViewPortExt.x, FWindowExt.x);
  ExtY := MulDiv(ExtY, FViewPortExt.y, FWindowExt.y);
end;

function TGtkDeviceContext.TransfExtentIndirect(const Extent: TPoint): TPoint;
begin
  Result.X := MulDiv(Extent.X, FViewPortExt.x, FWindowExt.x);
  Result.Y := MulDiv(Extent.Y, FViewPortExt.y, FWindowExt.y);
end;

procedure TGtkDeviceContext.TransfUpdateFont;
var
  AWidth, AHeight: Integer;
  TmpObj: PGdiObject;
begin
  if (FCurrentFont <> nil) and (FCurrentFont^.GDIFontObject <> nil) and (FCurrentFont^.LogFont.lfFaceName[0] <> #0) then
  begin
    if FCurrentFont^.UntransfFontHeight = 0 then
      FCurrentFont^.UntransfFontHeight := FCurrentFont^.LogFont.lfHeight;
    AWidth := 0; AHeight := FCurrentFont^.UntransfFontHeight;
    TransfExtent(AWidth, AHeight);
    if FCurrentFont^.UntransfFontHeight > 0 then
      AHeight := Abs(AHeight)
    else
      AHeight := -Abs(AHeight);
    if AHeight = 0 then
      if FCurrentFont^.LogFont.lfHeight > 0 then
        AHeight := 1
      else
      if FCurrentFont^.LogFont.lfHeight < 0 then
        AHeight := -1
      else
        AHeight := 0;
    if FCurrentFont^.LogFont.lfHeight <> AHeight then
    begin
      FontCache.Unreference(FCurrentFont^.GDIFontObject);
      FCurrentFont^.LogFont.lfHeight := AHeight;
      TmpObj := {%H-}PGdiObject(PtrUInt(GTK2WidgetSet.CreateFontIndirect(FCurrentFont^.LogFont)));
      FCurrentFont^.GDIFontObject := TmpObj^.GDIFontObject;
      TmpObj^.GDIFontObject := nil;
      TmpObj^.RefCount := 0;
      GTK2WidgetSet.DisposeGDIObject(TmpObj);
    end;
  end;
end;

procedure TGtkDeviceContext.TransfUpdatePen;
var
  AWidth, AHeight: Integer;
begin
  if FCurrentPen <> nil then
  begin
    if FCurrentPen^.UnTransfPenWidth = 0 then
      FCurrentPen^.UnTransfPenWidth := FCurrentPen^.GDIPenWidth;
    AWidth := FCurrentPen^.UnTransfPenWidth;
    AHeight := FCurrentPen^.UnTransfPenWidth;
    TransfExtent(AWidth, AHeight);
    AWidth := Abs(AWidth);
    AHeight := Abs(AHeight);
    if AWidth > AHeight then AWidth := AHeight;
    if AWidth <= 0 then AWidth := 1;
    if FCurrentPen^.GDIPenWidth <> DWord(AWidth) then
    begin
      FCurrentPen^.GDIPenWidth := AWidth;
      Exclude(FFlags, dcfPenSelected);
      SelectPenProps;
    end;
  end;
end;

procedure TGtkDeviceContext.SetWidget(AWidget: PGtkWidget; AWindow: PGdkWindow;
                                      AWithChildWindows: Boolean; ADoubleBuffer: PGdkDrawable);

  procedure RaiseWidgetWithoutClientArea;
  begin
    RaiseGDBException('TGtkDeviceContext.SetWidget: widget ' + DbgS(AWidget) + ' has no client area');
  end;

  procedure RaiseWidgetAlreadySet;
  begin
    RaiseGDBException('TGtkDeviceContext.SetWidget: widget already set');
  end;

  procedure RaiseUnableToRealize;
  begin
    RaiseGDBException('TGtkDeviceContext.SetWidget: Unable to realize GdkWindow');
  end;

var
  ClientWidget: PGtkWidget;
  W, TopLvlW: PGtkWidget;
begin
  if FWidget <> nil then
    RaiseWidgetAlreadySet;

  FWithChildWindows := AWithChildWindows;
  FWidget := AWidget;
  FPixbuf := nil;

  if (AWidget = nil) then
  begin
    // screen: ToDo: multiple desktops
    FDrawable := gdk_screen_get_root_window(gdk_screen_get_default);
  end else
  begin
    if ADoubleBuffer <> nil then
    begin
      Include(FFlags, dcfDoubleBuffer);
      FOriginalDrawable := AWindow;
      FDrawable := ADoubleBuffer;
    end else
    begin
      // create a new devicecontext for this window
      Exclude(FFlags, dcfDoubleBuffer);

      if AWindow = nil then
      begin
        ClientWidget := GetFixedWidget(AWidget);
        if ClientWidget = nil then RaiseWidgetWithoutClientArea;

        AWindow := GetControlWindow(ClientWidget);
        if AWindow = nil then
        begin
          W := gtk_widget_get_parent(AWidget);
          TopLvlW := gtk_widget_get_toplevel(AWidget);
          if (W <> nil) and GTK_IS_WINDOW(TopLvlW) then
          begin
            //debugln(['TGtkDeviceContext.SetWidget gtk-class=',GetWidgetClassName(W),' lcl-obj=',DbgSName(GetLCLObject(W))]);
            //we are forcing window creation but not for GtkNotebook
            //see issue #18754 and #20126
            //Zeljko:This part should be NOT BE REMOVED since TToolbar, TFrame
            //TGroupBox etc...depend on this. eg.TToolbar will lock
            //mouse without realizing clientWidget.Also if THintWindow is
            //visible it crashes sometimes. SO JUST NOTEBOOK !
            if not GTK_IS_NOTEBOOK(W) then
              gtk_widget_realize(ClientWidget);
          end;

          AWindow := GetControlWindow(ClientWidget);
          // Don't raise an exception. Not all operations needs drawable. For example font metrics:
          // http://bugs.freepascal.org/view.php?id=14035
          //if AWindow = nil then RaiseUnableToRealize;
        end;
      end else
      begin
        ClientWidget := AWidget;
      end;

      FDrawable := AWindow;
      // GC is created on demand
      if (FDrawable = nil) and not GTK_WIDGET_MAPPED(AWidget) then
        FDrawable := gdk_screen_get_root_window(gdk_screen_get_default);
    end;
  end;

  gdk_color_black(gdk_colormap_get_system, @CurrentTextColor.Color);
  BuildColorRefFromGDKColor(CurrentTextColor);
  gdk_color_white(gdk_colormap_get_system, @CurrentBackColor.Color);
  BuildColorRefFromGDKColor(CurrentBackColor);
  // font, brush, pen are created on demand
end;

procedure TGtkDeviceContext.Clear;
var
  g: TGDIType;

  procedure WarnOwnedGDIObject;
  begin
    DebugLn(['TDeviceContext.Clear ',dbghex(PtrInt(Self)),' OwnedGDIObjects[',ord(g),']<>nil']);
  end;

begin
  if Assigned(FPixbuf) then gdk_pixbuf_unref(FPixbuf);
  FWidget := nil;
  FDrawable := nil;
  FPixbuf := nil;
  FGC := nil;
  FillChar(FGCValues, SizeOf(FGCValues), 0);

  FViewPortExt := Point(1, 1);
  FViewPortOrg := Point(0, 0);
  FWindowExt := Point(1, 1);
  FWindowOrg := Point(0, 0);
  FMapMode := MM_TEXT;
  if FHasTransf then
  begin
    FHasTransf := False;
    TransfUpdateFont;
    TransfUpdatePen;
  end;

  PenPos := Point(0, 0);

  CurrentBitmap:=nil;
  CurrentFont:=nil;
  CurrentPen:=nil;
  CurrentBrush:=nil;
  CurrentPalette:=nil;
  ClipRegion:=nil;
  FillChar(CurrentTextColor,SizeOf(CurrentTextColor),0);
  FillChar(CurrentBackColor,SizeOf(CurrentBackColor),0);
  FillChar(PaintRectangle, SizeOf(PaintRectangle), 0);

  SelectedColors:=dcscCustom;
  SavedContext:=nil;
  FFlags := [];

  for g:=Low(TGDIType) to high(TGDIType) do
    if OwnedGDIObjects[g]<>nil then
      WarnOwnedGDIObject;
end;

{------------------------------------------------------------------------------
  Function: CopyData - used by RestoreDC and SaveDC
  Params:  DestinationDC:  a dc to copy data to
           ClearSource: set true to make a move operation
           MoveGDIOwnerShip: set true to pass the ownership of the GDI objects
                             to Destination
  Returns: True if succesful

  Creates a copy DC from the given DC
 ------------------------------------------------------------------------------}
function TGtkDeviceContext.CopyDataFrom(ASource: TGtkDeviceContext; AClearSource, AMoveGDIOwnerShip, ARestore: Boolean): Boolean;
  procedure RaiseRestoreDifferentWidget;
  begin
    RaiseGDBException('TGtkDeviceContext.CopyDataFrom: restore widget differs');
  end;

  procedure RaiseWidgetAlreadySet;
  begin
    RaiseGDBException('TGtkDeviceContext.CopyDataFrom: widget already set');
  end;

var
  g: TGDIType;
  CurGDIObject: PGDIObject;
begin
  Result := Assigned(Self) and Assigned(ASource);
  if not Result then Exit;

  if ARestore then
  begin
    if FWidget <> ASource.FWidget then
      RaiseRestoreDifferentWidget;
  end else
  begin
    if Assigned(FWidget) then
      RaiseWidgetAlreadySet;
    FWidget := ASource.FWidget;
  end;

  FWithChildWindows := ASource.FWithChildWindows;
  FDrawable := ASource.FDrawable;
  FPixbuf := ASource.Pixbuf;
  FOriginalDrawable := ASource.FOriginalDrawable;

  if Assigned(FGC) then
  begin
    // free old GC
    gdk_gc_unref(FGC);
    FGC := nil;
    Exclude(FFlags, dcfPenSelected);
  end;

  if Assigned(ASource.FGC) and Assigned(FDrawable) then
  begin
    gdk_gc_get_values(ASource.FGC, @FGCValues);
    FGC := gdk_gc_new_with_values(FDrawable, @FGCValues,
      GDK_GC_FOREGROUND or GDK_GC_BACKGROUND or GDK_GC_SUBWINDOW);
    Exclude(FFlags, dcfPenSelected);
  end;

  if dcfTextMetricsValid in ASource.Flags then
  begin
    Include(FFlags, dcfTextMetricsValid);
    DCTextMetric := ASource.DCTextMetric;
  end
  else
    Exclude(FFlags, dcfTextMetricsValid);

  for g := Low(TGDIType) to High(TGDIType) do
  begin
    GDIObjects[g] := ASource.GDIObjects[g];
    if AClearSource then
      ASource.GDIObjects[g] := nil;

    if AMoveGDIOwnerShip then
    begin
      if Assigned(OwnedGDIObjects[g]) then
        DeleteObject(HGDIOBJ({%H-}PtrUInt(OwnedGDIObjects[g])));

      CurGDIObject := ASource.OwnedGDIObjects[g];

      if Assigned(CurGDIObject) then
      begin
        ASource.OwnedGDIObjects[g] := nil;
        OwnedGDIObjects[g] := CurGDIObject;
      end;
    end;
  end;
  CopyGDIColor(ASource.CurrentTextColor, CurrentTextColor);
  CopyGDIColor(ASource.CurrentBackColor, CurrentBackColor);

  SelectedColors := dcscCustom;
  PenPos := ASource.PenPos;

  if FHasTransf then
  begin
    FHasTransf := False;
    FMapMode := MM_TEXT;
    FViewPortExt := Point(1, 1);
    FViewPortOrg := Point(0, 0);
    FWindowExt := Point(1, 1);
    FWindowOrg := Point(0, 0);
    TransfUpdateFont;
    TransfUpdatePen;
  end;

  FHasTransf := ASource.HasTransf;
  if FHasTransf then
  begin
    FMapMode := ASource.MapMode;
    FViewPortExt := ASource.ViewPortExt;
    FViewPortOrg := ASource.ViewPortOrg;
    FWindowExt := ASource.WindowExt;
    FWindowOrg := ASource.WindowOrg;
    TransfUpdateFont;
    TransfUpdatePen;
  end;

  SavedContext := nil;
end;

function TGtkDeviceContext.FillRect(ARect: TRect; ABrush: HBrush; SkipRop: Boolean): Boolean;
var
  Width, Height: Integer;
  OldCurrentBrush: PGdiObject;
  DCOrigin: TPoint;
  BrushChanged: Boolean;
  ClipArea: TGdkRectangle;
begin
  BrushChanged := False;
  if not IsNullBrush then
  begin
    if FHasTransf then
    begin
      ARect := TransfRectIndirect(ARect);
      TransfNormalize(ARect.Left, ARect.Right);
      TransfNormalize(ARect.Top, ARect.Bottom);
    end;

    Width := ARect.Right - ARect.Left;
    Height := ARect.Bottom - ARect.Top;

    // Temporary hold the old brush to replace it with the given brush
    OldCurrentBrush := GetBrush;
    if not CompareGDIBrushes({%H-}PGdiObject(ABrush), OldCurrentBrush) then
    begin
      BrushChanged := True;
      CurrentBrush := {%H-}PGdiObject(ABrush);
      SelectedColors := dcscCustom;
    end;

    SelectBrushProps;
    if SkipRop then
      gdk_gc_set_function(GC, GDK_COPY);

    DCOrigin := Offset;
    ClipArea := ClipRect;
    RemovePixbuf;
    if (CurrentBrush^.GDIBrushFill = GDK_SOLID) and
       (IsBackgroundColor(TColor(CurrentBrush^.GDIBrushColor.ColorRef))) then
      StyleFillRectangle(Drawable, GC,
                         CurrentBrush^.GDIBrushColor.ColorRef,
                         ARect.Left + DCOrigin.X, ARect.Top + DCOrigin.Y,
                         Width, Height, @ClipArea)
    else
      gdk_draw_rectangle(Drawable, GC, 1,
                         ARect.Left + DCOrigin.X, ARect.Top + DCOrigin.Y,
                         Width, Height);

    if SkipRop then
      gdk_gc_set_function(GC, GetFunction);

    // Restore current brush
    if BrushChanged then
    begin
      SelectedColors := dcscCustom;
      CurrentBrush := OldCurrentBrush;
    end;
  end;

  Result := True;
end;

procedure TGtkDeviceContext.CreateBrush;
begin
  if FCurrentBrush <> nil then Exit;
  CurrentBrush := Gtk2Widgetset.CreateDefaultBrush;
  OwnedGDIObjects[gdiBrush] := FCurrentBrush;
end;

procedure TGtkDeviceContext.CreateFont;
var
  NewFont: PGDIObject;
  ClientWidget: PGtkWidget;
begin
  if FCurrentFont <> nil then exit;

  // create font
  if FWidget <> nil then
  begin
    ClientWidget := GetFixedWidget(FWidget);

    NewFont := Gtk2Widgetset.NewGDIObject(gdiFont);
    NewFont^.UntransfFontHeight := 0;
    CurrentFont := NewFont;
    FCurrentFont^.GDIFontObject := gtk_widget_create_pango_layout(ClientWidget, nil);

    {$ifdef fontconsistencychecks}
    if FontCache.FindGTKFont(FCurrentFont^.GDIFontObject) <> nil then
      RaiseGDBException('inconsistency: font already in cache, maybe freed, but not removed from cache');
    {$endif}

    FontCache.AddWithoutName(FCurrentFont^.GDIFontObject);

    // the gtk internal reference count was increased by
    // gtk_widget_create_pango_layout and by FontCache.AddWithoutName
    // reduce it to one, because only this DC is using them at this point
    UnreferenceGtkIntfFont(FCurrentFont^.GDIFontObject);

    {$ifdef fontconsistencychecks}
    // MWE: are we paranoid or so ? (if you can't trust the cache, don't use it or stop coding)
    // MG: some people are coding without knowing about the cache
    if FontCache.FindGTKFont(FCurrentFont^.GDIFontObject) = nil then
      RaiseGDBException('inconsistency: font added to cache, but can not be found');
    {$endif}
  end
  else
    CurrentFont := Gtk2Widgetset.CreateDefaultFont;
  OwnedGDIObjects[gdiFont] := FCurrentFont;
end;

function TGtkDeviceContext.CreateGC: PGdkGC;
begin
  // create GC

  if (Drawable <> nil) and (Drawable^.parent_instance.ref_count>0) then
  begin
    if FWithChildWindows then
    begin
      FillChar(FGCValues, SizeOf(FGCValues), 0);
      FGCValues.subwindow_mode := GDK_INCLUDE_INFERIORS;
      Result := gdk_gc_new_with_values(Drawable, @FGCValues, GDK_GC_FUNCTION or GDK_GC_SUBWINDOW);
    end else
    begin
      Result := gdk_gc_new(Drawable);
    end;
  end else
  begin
    // create default GC
    Result := gdk_gc_new(gdk_screen_get_root_window(gdk_screen_get_default));
  end;
  if Result = nil then Exit;

  gdk_gc_set_function(Result, GDK_COPY);
  gdk_gc_get_values(Result, @FGCValues);
end;

procedure TGtkDeviceContext.CreateBitmap;
begin
  if FCurrentBitmap <> nil then Exit;
  CurrentBitmap := GTK2Widgetset.CreateDefaultGDIBitmap;
  OwnedGDIObjects[gdiBitmap] := FCurrentBitmap;
end;

procedure TGtkDeviceContext.CreateGDIObject(AGDIType: TGDIType);
begin
  case AGDIType of
    gdiFont: CreateFont;
    gdiBrush: CreateBrush;
    gdiPen: CreatePen;
    gdiBitmap: CreateBitmap;
  else
    RaiseGDBException('TGtkDeviceContext.CreateGDIObject');
  end;
end;

procedure TGtkDeviceContext.CreatePen;
begin
  if FCurrentPen <> nil then exit;
  CurrentPen := Gtk2WidgetSet.CreateDefaultPen;
  OwnedGDIObjects[gdiPen] := FCurrentPen;
end;


function TGtkDeviceContext.GetGC: pgdkGC;
begin
  if FGC = nil then
    FGC := CreateGC;
  Result := FGC;
end;

function TGtkDeviceContext.GetFont: PGdiObject;
begin
  if FCurrentFont = nil then
    CreateFont;

  Result := FCurrentFont;
end;

function TGtkDeviceContext.GetBrush: PGdiObject;
begin
  if FCurrentBrush = nil then
    CreateBrush;

  Result := FCurrentBrush;
end;

function TGtkDeviceContext.GetPen: PGdiObject;
begin
  if FCurrentPen = nil then
    CreatePen;

  Result := FCurrentPen;
end;

function TGtkDeviceContext.GetROP2: Integer;
begin
  case GetFunction of
    GDK_COPY:         result := R2_COPYPEN;
    GDK_INVERT:       result := R2_NOT;
    GDK_XOR:          result := R2_XORPEN;
    GDK_CLEAR:        result := R2_BLACK;
    GDK_AND:          result := R2_MASKPEN;
    GDK_AND_REVERSE:  result := R2_MASKPENNOT;
    GDK_AND_INVERT:   result := R2_MASKNOTPEN;
    GDK_NOOP:         result := R2_NOP;
    GDK_OR:           result := R2_MERGEPEN;
    GDK_EQUIV:        result := R2_NOTXORPEN;
    GDK_OR_REVERSE:   result := R2_MERGEPENNOT;
    GDK_COPY_INVERT:  result := R2_NOTCOPYPEN;
    GDK_NAND:         result := R2_NOTMASKPEN;
    //GDK_NOR:          result := R2_NOTMERGEPEN;
    GDK_SET:          result := R2_WHITE;
  else
    result := R2_COPYPEN;
  end;
end;

function TGtkDeviceContext.HasGC: Boolean;
begin
  Result := FGC <> nil;
end;

function TGtkDeviceContext.IsNullBrush: boolean;
begin
  Result := (FCurrentBrush <> nil) and (FCurrentBrush^.IsNullBrush);
end;


function TGtkDeviceContext.IsNullPen: boolean;
begin
  Result := (FCurrentPen <> nil) and (FCurrentPen^.IsNullPen);
end;

procedure TGtkDeviceContext.ResetGCClipping;
begin
  if FGC = nil then Exit;

  {$IFDEF DebugGDK}BeginGDKErrorTrap;{$endif}
  gdk_gc_set_clip_mask(FGC, nil);
  gdk_gc_set_clip_origin (FGC, 0,0);
  {$IFDEF DebugGDK}EndGDKErrorTrap;{$endif}

  SelectRegion;
end;

function TGtkDeviceContext.SelectBitmap(AGdiObject: PGdiObject): PGdiObject;
var
  NewPixbuf: PGdkPixbuf;
  NewDrawable: PGdkPixmap;
  Mask: PGdkBitmap;
begin
  // always create, because a valid GDIObject is needed to restore
  Result := GetBitmap;
  if CurrentBitmap = AGDIObject then Exit;

  NewPixbuf := nil;
  CurrentBitmap := AGDIObject;
  with FCurrentBitmap^ do
    case GDIBitmapType of
      gbPixmap: NewDrawable := GDIPixmapObject.Image;
      gbBitmap: NewDrawable := GDIBitmapObject;
      gbPixbuf:
        begin
          NewDrawable := nil;
          Mask := nil;
          NewPixbuf := GDIPixbufObject;
          gdk_pixbuf_render_pixmap_and_mask(GDIPixbufObject, NewDrawable, Mask, $80);
          GDIBitmapType := gbPixmap;
          GDIPixmapObject.Image := NewDrawable;
          GDIPixmapObject.Mask := Mask;
          if Visual <> nil then
            gdk_visual_unref(Visual);
          Visual := gdk_window_get_visual(NewDrawable);
          gdk_visual_ref(Visual);
        end;
    else
      DebugLn('[TGtkDeviceContext.SelectBitmap] - Unknown bitmaptype, DC=0x%p', [Pointer(Self)]);
      Exit;
    end;

  // no drawable: this is normal, when restoring the default bitmap (FreeDC)
  if NewDrawable = nil then Exit;

  if FGC <> nil then
    gdk_gc_unref(FGC);
  FDrawable := NewDrawable;
  FPixbuf := NewPixbuf;
  FGC := gdk_gc_new(FDrawable);
  gdk_gc_set_function(FGC, GDK_COPY);
  SelectedColors := dcscCustom;
end;

{------------------------------------------------------------------------------
  Procedure: TGtkDeviceContext.SelectBrushProps
  Params:
  Returns: Nothing

  Sets the forecolor and fill according to the brush
 ------------------------------------------------------------------------------}
procedure TGtkDeviceContext.SelectBrushProps;
begin
  if IsNullBrush then Exit;

  // Force brush
  GetBrush;

  EnsureGCColor(HDC(Self), dccCurrentBackColor, True, True);//BKColor
  EnsureGCColor(HDC(Self), dccGDIBrushColor, CurrentBrush^.GDIBrushFill = GDK_Solid, False);//Brush Color

  if CurrentBrush^.GDIBrushFill = GDK_Solid then Exit;
  if CurrentBrush^.GDIBrushPixmap = nil then Exit;

  if CurrentBrush^.GDIBrushFill = GDK_STIPPLED then
  begin
    //invert background / foreground colors to match Windows.FillRect behavior
    //with a 1bit bitmap pattern brush (bit set -> back color, bit unset -> text color)
    EnsureGCColor(HDC(Self), dccCurrentTextColor, False, True);
    EnsureGCColor(HDC(Self), dccCurrentBackColor, True, True);
    gdk_gc_set_stipple(GC, CurrentBrush^.GDIBrushPixmap);
    //use GDK_OPAQUE_STIPPLED to draw both background and foreground color
    gdk_gc_set_fill(GC, GDK_OPAQUE_STIPPLED);
  end
  else
  begin
    gdk_gc_set_tile(GC, CurrentBrush^.GDIBrushPixmap);
    gdk_gc_set_fill(GC, GDK_TILED);
  end;

  gdk_gc_get_values(GC, @FGCValues);
end;

function TGtkDeviceContext.SelectObject(AGdiObject: PGdiObject): PGdiObject;
begin
  case AGdiObject^.GDIType of
    gdiBitmap: Result := SelectBitmap(AGdiObject);
    gdiPen:    Result := SelectPen(AGdiObject);
  else
    // we only handle bitmaps here atm
    Result := {%H-}PGdiObject(GTK2WidgetSet.SelectObject(HDC(Self), {%H-}HGDIOBJ(AGdiObject)));
  end;
end;

function TGtkDeviceContext.SelectPen(AGdiObject: PGdiObject): PGdiObject;
begin
  Result := GetPen;// always create, because a valid GDIObject is needed to restore
  if CurrentPen = AGDIObject then Exit;

  CurrentPen := AGDIObject;
  Exclude(FFlags, dcfPenSelected);
  if FGC <> nil then
    SelectPenProps;
  SelectedColors := dcscCustom;
end;

constructor TGtkDeviceContext.Create;
begin
  Clear;
  BkMode := OPAQUE;
end;

destructor TGtkDeviceContext.Destroy;
begin
  if Assigned(FPixbuf) then gdk_pixbuf_unref(FPixbuf);
  inherited Destroy;
end;

{------------------------------------------------------------------------------
  Procedure: TGtkDeviceContext.SelectPenProps
  Params:  DC: a (LCL)devicecontext
  Returns: Nothing

  Sets the forecolor and fill according to the pen
 ------------------------------------------------------------------------------}
procedure TGtkDeviceContext.SelectPenProps;
var
  PenStyle: DWord;
  LineStyle: TGdkLineStyle;
  JoinStyle: TGdkJoinStyle;
  CapStyle: TGdkCapStyle;
  IsGeometric, IsExtPen: Boolean;
  PenWidth: gint;

  procedure SetDashes(ADashes: array of gint8);
  var
    Multiplier: gint;
    i: integer;
  begin
    Multiplier := PenWidth;
    if Multiplier = 0 then
      Multiplier := 1;

    // this works very well for geometric pens
    for i := Low(ADashes) to High(ADashes) do
      ADashes[i] := ADashes[i] * Multiplier;

    laz_gdk_gc_set_dashes(GC, 4096, @ADashes[0], Length(ADashes))
  end;

begin
//  if IsNullPen then Exit;

  EnsureGCColor(HDC(Self), dccCurrentBackColor, True, True); // BKColor
  EnsureGCColor(HDC(Self), dccGDIPenColor, False, False);    // Pen Color

  if dcfPenSelected in FFlags then Exit;
  Exclude(FFlags, dcfPenInvalid);
  if GC = nil then Exit;

  // force pen
  GetPen;

  PenStyle := CurrentPen^.GDIPenStyle and PS_STYLE_MASK;
  IsExtPen := CurrentPen^.IsExtPen;
  PenWidth := CurrentPen^.GDIPenWidth;

  if IsExtPen then
    IsGeometric := (CurrentPen^.GDIPenStyle and PS_TYPE_MASK) = PS_GEOMETRIC
  else
    IsGeometric := PenWidth > 1;

  if not IsGeometric then
    PenWidth := 0;

  CurrentPen^.IsNullPen := PenStyle = PS_NULL;

  if IsExtPen and IsGeometric then
  begin
    case CurrentPen^.GDIPenStyle and PS_JOIN_MASK of
      PS_JOIN_ROUND: JoinStyle := GDK_JOIN_ROUND;
      PS_JOIN_BEVEL: JoinStyle := GDK_JOIN_BEVEL;
      PS_JOIN_MITER: JoinStyle := GDK_JOIN_MITER;
    end;

    case CurrentPen^.GDIPenStyle and PS_ENDCAP_MASK of
      PS_ENDCAP_ROUND: CapStyle := GDK_CAP_ROUND;
      PS_ENDCAP_SQUARE: CapStyle := GDK_CAP_PROJECTING;
      PS_ENDCAP_FLAT: CapStyle := GDK_CAP_NOT_LAST;
    end;
  end
  else
  begin
    JoinStyle := GDK_JOIN_ROUND;
    if IsGeometric then
      CapStyle := GDK_CAP_ROUND
    else
      CapStyle := GDK_CAP_NOT_LAST;
  end;

  if (PenStyle = PS_USERSTYLE) and (not IsExtPen or (CurrentPen^.GDIPenDashesCount = 0)) then
    PenStyle := PS_SOLID;

  if (PenStyle = PS_SOLID) or (PenStyle = PS_INSIDEFRAME) then
    LineStyle := GDK_LINE_SOLID
  else
    LineStyle := GDK_LINE_ON_OFF_DASH;

  {$IFDEF DebugGDK}BeginGDKErrorTrap;{$ENDIF}
  gdk_gc_set_line_attributes(GC, PenWidth, LineStyle, CapStyle, JoinStyle);
  {$IFDEF DebugGDK}EndGDKErrorTrap;{$ENDIF}

  // Paul Ishenin: I compared patterns with windows
  case PenStyle of
    PS_DASH:       SetDashes([4,2]);
    PS_DOT:        SetDashes([1,2]);
    PS_DASHDOT:    SetDashes([4,2,1,2]);
    PS_DASHDOTDOT: SetDashes([4,2,1,2,1,2]);
    PS_USERSTYLE:  laz_gdk_gc_set_dashes(GC, 0, CurrentPen^.GDIPenDashes, CurrentPen^.GDIPenDashesCount);
  end;
  {$IFDEF DebugGDK}EndGDKErrorTrap;{$ENDIF}
  gdk_gc_get_values(GC, @FGCValues);
  Include(FFlags, dcfPenSelected);
end;

{------------------------------------------------------------------------------
  procedure SelectRegion

  Applies the current clipping region of the DC (DeviceContext) to the
  gc (GDK Graphic context - pgdkGC)
 ------------------------------------------------------------------------------}
procedure TGtkDeviceContext.SelectRegion;
var
  RGNType : Longint;
begin
  {$IFDEF DebugGDK}BeginGDKErrorTrap;{$ENDIF}

  // force GC
  GetGC;

  // Clear
  gdk_gc_set_clip_region(FGC,  nil);
  gdk_gc_set_clip_rectangle(FGC,  nil);

  if ClipRegion <> nil then
  begin
    RGNType := RegionType(ClipRegion^.GDIRegionObject);
    if RGNType <> ERROR then
      gdk_gc_set_clip_region(FGC,  ClipRegion^.GDIRegionObject);
  end;

  {$IFDEF DebugGDK}EndGDKErrorTrap;{$ENDIF}
end;

{------------------------------------------------------------------------------
  Procedure: TGtkDeviceContext.SelectTextProps
  Params:
  Returns: Nothing

  Sets the forecolor and fill according to the Textcolor
 ------------------------------------------------------------------------------}
procedure TGtkDeviceContext.SelectTextProps;
begin
  EnsureGCColor(HDC(Self), dccCurrentBackColor, True, True);//BKColor
  EnsureGCColor(HDC(Self), dccCurrentTextColor, False, False);//Font Color
end;

function TGtkDeviceContext.GetBitmap: PGdiObject;
begin
  if FCurrentBitmap = nil then
    CreateBitmap;

  Result := FCurrentBitmap;
end;

function TGtkDeviceContext.GetFunction: TGdkFunction;
begin
  Result := GCValues._function;
end;


procedure SetLayoutText(ALayout: PPangoLayout; AText: PChar; ALength: PtrInt);
var
  OldStr: PChar;
begin
  OldStr := pango_layout_get_text(ALayout);
  if (strlen(OldStr)<>ALength) or (strlcomp(AText, OldStr, ALength) <> 0) then
    pango_layout_set_text(ALayout, AText, ALength);
end;

procedure TGtkDeviceContext.DrawTextWithColors(AText: PChar; ALength: LongInt;
  X, Y: Integer; FGColor, BGColor: PGdkColor);
var
  WidgetCont: PPangoContext;
  NewMatrix: TPangoMatrix;
  OldMatrix: PPangoMatrix;
  renderer: PGdkPangoRenderer;
  Direction : TPangoDirection;
  AFont: PGdiObject;
  
  procedure SetColors(AFGColor, ABGColor: PGdkColor); inline;
  begin
    gdk_pango_renderer_set_override_color(renderer, PANGO_RENDER_PART_FOREGROUND, AFGColor);
    gdk_pango_renderer_set_override_color(renderer, PANGO_RENDER_PART_UNDERLINE, AFGColor);
    gdk_pango_renderer_set_override_color(renderer, PANGO_RENDER_PART_STRIKETHROUGH, AFGColor);
    gdk_pango_renderer_set_override_color(renderer, PANGO_RENDER_PART_BACKGROUND, ABGColor);
  end;
  
begin
  AFont := GetFont;
  SetLayoutText(AFont^.GDIFontObject, AText, ALength);

  WidgetCont := pango_layout_get_context(AFont^.GDIFontObject);
  Direction := pango_find_base_dir(AText, ALength);
  pango_context_set_base_dir(WidgetCont, Direction);

  if AFont^.LogFont.lfEscapement <> 0 then
  begin
    if Widget <> nil then
      renderer := gdk_pango_renderer_get_default(gtk_widget_get_screen(Widget))
    else
      renderer := gdk_pango_renderer_get_default(gdk_screen_get_default);
    RemovePixbuf;
    gdk_pango_renderer_set_drawable(renderer, drawable);
    gdk_pango_renderer_set_gc(renderer, GC);
    SetColors(FGColor, BGColor);

    OldMatrix := pango_context_get_matrix(WidgetCont);
    NewMatrix.xx := 1.0;
    NewMatrix.xy := 0.0;
    NewMatrix.yx := 0.0;
    NewMatrix.yy := 1.0;
    NewMatrix.x0 := 0.0;
    NewMatrix.y0 := 0.0;
    pango_matrix_translate(@NewMatrix, X, Y);
    pango_matrix_rotate(@NewMatrix, AFont^.LogFont.lfEscapement / 10);

    pango_context_set_matrix(WidgetCont, @NewMatrix);
    pango_layout_context_changed(AFont^.GDIFontObject);
    pango_renderer_draw_layout(PPangoRenderer(renderer), AFont^.GDIFontObject, X, Y);

    //now reset
    pango_context_set_matrix(WidgetCont, OldMatrix);
    pango_layout_context_changed(AFont^.GDIFontObject);
    
    SetColors(nil, nil);
    gdk_pango_renderer_set_drawable(renderer, nil);
    gdk_pango_renderer_set_gc(renderer, nil);
  end
  else
    gdk_draw_layout_with_colors(drawable, GC, X, Y, AFont^.GDIFontObject, FGColor, BGColor);
end;


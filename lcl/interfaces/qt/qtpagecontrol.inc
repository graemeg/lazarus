{%MainUnit qtwscomctrls.pp}
{
 *****************************************************************************
  This file is part of the Lazarus Component Library (LCL)

  See the file COPYING.modifiedLGPL.txt, included in this distribution,
  for details about the license.
 *****************************************************************************
}

const
  QTabWidgetTabPositionMap: array[TTabPosition] of QTabWidgetTabPosition =
  (
{ tpTop    } QTabWidgetNorth,
{ tpBottom } QTabWidgetSouth,
{ tpLeft   } QTabWidgetWest,
{ tpRight  } QTabWidgetEast
  );


{ TQtWSCustomPage }

{------------------------------------------------------------------------------
  Method: TQtWSCustomPage.CreateHandle
  Params:  None
  Returns: Nothing

  Allocates memory and resources for the control and shows it
 ------------------------------------------------------------------------------}
class function TQtWSCustomPage.CreateHandle(const AWinControl: TWinControl;
  const AParams: TCreateParams): TLCLIntfHandle;
var
  QtPage: TQtPage;
begin
  {$ifdef VerboseQt}
    WriteLn('Trace:> [TQtWSCustomPage.CreateHandle]');
  {$endif}

  QtPage := TQtPage.Create(AWinControl, AParams);
  QtPage.AttachEvents;

  // Returns the Handle
  Result := TLCLIntfHandle(QtPage);

  {$ifdef VerboseQt}
    WriteLn('Trace:< [TQtWSCustomPage.CreateHandle] Result: ', IntToStr(Result));
  {$endif}
end;

class procedure TQtWSCustomPage.DestroyHandle(const AWinControl: TWinControl);
var
  B: Boolean;
begin
  B := (AWinControl.Parent is TPageControl) and
    AWinControl.Parent.HandleAllocated;
  if B then
    TQtWidget(AWinControl.Parent.Handle).BeginUpdate;
  TQtWidget(AWinControl.Handle).Release;
  if B then
    TQtWidget(AWinControl.Parent.Handle).EndUpdate;
end;

class procedure TQtWSCustomPage.UpdateTabFontColor(APage: TCustomPage; AFont: TFont);
var
  AParent: TQtWidget;
  ATabWidget: TQtTabWidget;
  AColor: TQColor;
begin
  if not Assigned(APage.Parent) or not APage.Parent.HandleAllocated then
    exit;
  AParent := TQtWidget(APage.Parent.Handle);
  if not (AParent is TQtTabWidget) then
      exit;
  ATabWidget := TQtTabWidget(AParent);

  AColor.Alpha := 0;
  FillChar(AColor, SizeOf(AColor), #0);
  if AFont.Color = clDefault then
    AColor := ATabWidget.Palette.DefaultTextColor
  else
    ColorRefToTQColor(ColorToRGB(AFont.Color), AColor);
  with ATabWidget.TabBar do
    SetTabFontColor(APage.PageIndex, AColor);
end;

class procedure TQtWSCustomPage.SetFont(const AWinControl: TWinControl;
  const AFont: TFont);
begin
  if not WSCheckHandleAllocated(AWinControl, 'SetFont') then
    Exit;
  inherited SetFont(AWinControl, AFont);
  UpdateTabFontColor(TCustomPage(AWinControl), AFont);
end;

class procedure TQtWSCustomPage.UpdateProperties(const ACustomPage: TCustomPage);
var
  ImageList: TCustomImageList;
  ImageIndex: Integer;
  Bmp: TBitmap;
  Icon: QIconH;
  B: Boolean;
  Size: TSize;
  Res: TScaledImageListResolution;
begin
  ImageList := TCustomTabControl(ACustomPage.Parent).Images;

  B := False;

  if Assigned(ImageList) then
  begin
    Res := ImageList.ResolutionForPPI[
      TCustomTabControl(ACustomPage.Parent).ImagesWidth,
      TCustomTabControl(ACustomPage.Parent).Font.PixelsPerInch,
      TCustomTabControl(ACustomPage.Parent).GetCanvasScaleFactor];
    ImageIndex := TCustomTabControl(ACustomPage.Parent).GetImageIndex(ACustomPage.PageIndex);
    if (ImageIndex >= 0) and (ImageIndex < Res.Count) then
    begin
      Bmp := TBitmap.Create;
      try
        Res.GetBitmap(ACustomPage.ImageIndex, Bmp);
        if (TQtPage(ACustomPage.Handle).ChildOfComplexWidget = ccwTabWidget) and
          (TQtPage(ACustomPage.Handle).getTabWidget <> nil) then
        begin
          Size.cx := Res.Width;
          Size.cy := Res.Height;
          QTabWidget_setIconSize(TQtPage(ACustomPage.Handle).getTabWidget, @Size);
        end;
        TQtPage(ACustomPage.Handle).setIcon(TQtImage(Bmp.Handle).AsIcon);
        B := True;
      finally
        Bmp.Free;
      end;
    end;
  end;

  // no ImageList or invalid index.
  if not B then
  begin
    Icon := TQtPage(ACustomPage.Handle).getIcon;
    if (Icon <> nil) and not QIcon_isNull(Icon) then
    begin
      Icon := QIcon_create;
      TQtPage(ACustomPage.Handle).setIcon(Icon);
      QIcon_destroy(Icon);
    end;
  end;

  UpdateTabFontColor(ACustomPage, ACustomPage.Font);
end;

{ TQtWSCustomNotebook }

{------------------------------------------------------------------------------
  Method: TQtWSCustomTabControl.CreateHandle
  Params:  None
  Returns: Nothing

  Allocates memory and resources for the control and shows it
 ------------------------------------------------------------------------------}
class function TQtWSCustomTabControl.CreateHandle(const AWinControl: TWinControl; const AParams: TCreateParams): TLCLIntfHandle;
var
  QtTabWidget: TQtTabWidget;
  QtTTabCtl: TQtWidget;
begin
  {$ifdef VerboseQt}
    WriteLn('TQtWSCustomTabControl.CreateHandle');
  {$endif}
  if AWinControl is TTabControl then
  begin
    QtTTabCtl := TQtWidget.Create(AWinControl, AParams);
    QtTTabCtl.ChildOfComplexWidget := ccwTTabControl;
    QtTTabCtl.AttachEvents;
    Result := TLCLIntfHandle(QtTTabCtl);
  end else
  begin
    QtTabWidget := TQtTabWidget.Create(AWinControl, AParams);
    QtTabWidget.setTabPosition(QTabWidgetTabPositionMap[TCustomTabControl(AWinControl).TabPosition]);
    QtTabWidget.setTabsClosable(nboShowCloseButtons in TCustomTabControl(AWinControl).Options);
    {$IFDEF DARWIN}
    QTabWidget_setElideMode(QTabWidgetH(QtTabWidget.Widget), QtElideNone);
    {$ENDIF}
    QtTabWidget.AttachEvents;
    Result := TLCLIntfHandle(QtTabWidget);
  end;
end;

class function TQtWSCustomTabControl.GetDefaultClientRect(
  const AWinControl: TWinControl; const aLeft, aTop, aWidth, aHeight: integer;
  var aClientRect: TRect): boolean;
var
  dx, dy: integer;
  ATabWidget: TQtTabWidget;
  ASize: TSize;
  HSpace: Integer;
  Overlap: Integer;
  VSpace: Integer;
  BaseHeight: Integer;
  TabOverLap: Integer;
  ShiftVertical: Integer;
begin
  Result := False;
  if AWinControl.HandleAllocated then
  begin
    if TQtWidget(AWinControl.Handle).ChildOfComplexWidget <> ccwTTabControl then
    begin
      ATabWidget := TQtTabWidget(AWinControl.Handle);
      if ATabWidget.testAttribute(QtWA_PendingResizeEvent) or not ATabWidget.testAttribute(QtWA_Mapped) then
      begin
        // we must recalculate aclientrect since we have pending resize event
        // and clientrect won't be accurate.issue #21805
        Result := True;
        dx := GetPixelMetric(QStylePM_DefaultFrameWidth, nil, ATabWidget.Widget);
        // HSpace := GetPixelMetric(QStylePM_TabBarTabHSpace, nil, nil);
        VSpace := GetPixelMetric(QStylePM_TabBarTabVSpace, nil, ATabWidget.Widget);
        Overlap := GetPixelMetric(QStylePM_TabBarBaseOverlap, nil, ATabWidget.Widget);
        TabOverLap := GetPixelMetric(QStylePM_TabBarTabOverlap, nil, ATabWidget.Widget);
        BaseHeight := GetPixelMetric(QStylePM_TabBarBaseHeight, nil, ATabWidget.Widget);
        ShiftVertical := GetPixelMetric(QStylePM_TabBarTabShiftVertical, nil, ATabWidget.Widget);

        // trigger sizing, do not remove
        ATabWidget.TabBar.sizeHint(@ASize);

        if ATabWidget.getTabPosition in [QTabWidgetNorth, QTabWidgetSouth] then
        begin
          if TCustomTabControl(AWinControl).ShowTabs then
            dy := ATabWidget.TabBar.getHeight
          else
            dy := 0;

          if (BaseHeight < ShiftVertical) then
          begin
            if (Overlap = 0) then
            begin
              BaseHeight := BaseHeight + TabOverLap;
              dx := dx + (TabOverlap * 2);
            end else
            begin
              BaseHeight := BaseHeight * 2;
              dx := dx + BaseHeight;
            end;
          end;

          if (Overlap > VSpace) then
            BaseHeight := BaseHeight * 2;

          if (VSpace > TabOverLap) then
            dx := dx + Overlap;

          aClientRect := Rect(0, 0,
               Max(0, aWidth - (BaseHeight * 2)),
               Max(0, aHeight - dx  - dy));
        end else
        begin
          if TCustomTabControl(AWinControl).ShowTabs then
            dy := ATabWidget.TabBar.getWidth
          else
            dy := 0;

          VSpace := 0;
          HSpace := 0;

          if BaseHeight < ShiftVertical then
            VSpace := TabOverLap - BaseHeight;
          if (Overlap < dx) then
          begin
            VSpace := OverLap;
            if OverLap = 0 then
            begin
              VSpace := TabOverLap * 2;
              HSpace := BaseHeight;
            end;
          end;

          aClientRect := Rect(0,0,
               Max(0, aWidth - dx  - dy - VSpace),
               Max(0, aHeight - (dx + Overlap + VSpace + HSpace)));
        end;
      end;
    end;
  end else
  begin
    dx := GetPixelMetric(QStylePM_TabBarBaseHeight, nil, nil);
    aClientRect := Rect(0,0, Max(0, aWidth - (dx * 2)), Max(0, aHeight - (dx * 2)));
    Result := True;
  end;
end;

class procedure TQtWSCustomTabControl.AddPage(const ATabControl: TCustomTabControl;
  const AChild: TCustomPage; const AIndex: integer);
var
  QtTabWidget: TQtTabWidget;
begin
  {$ifdef VerboseQt}
    WriteLn('TQtWSCustomTabControl.AddPage');
  {$endif}
  QtTabWidget := TQtTabWidget(ATabControl.Handle);
  QtTabWidget.setUpdatesEnabled(False);
  QtTabWidget.BeginUpdate;
  try
    QtTabWidget.insertTab(AIndex, TQtPage(AChild.Handle).Widget, AChild.Caption{%H-});
  finally
    QtTabWidget.EndUpdate;
    QtTabWidget.setUpdatesEnabled(True);
  end;
  TQtPage(AChild.Handle).ChildOfComplexWidget := ccwTabWidget;
  TQtWsCustomPage.UpdateProperties(AChild);
end;

class procedure TQtWSCustomTabControl.MovePage(const ATabControl: TCustomTabControl;
  const AChild: TCustomPage; const NewIndex: integer);
var
  TabWidget: TQtTabWidget;
  Index: Integer;
begin
  AChild.HandleNeeded; {create handle if it does not exist yet}
  TabWidget := TQtTabWidget(ATabControl.Handle);
  Index := AChild.PageIndex;
  if Index < 0 then
    Index := ATabControl.IndexOf(AChild);

  TabWidget.BeginUpdate;
  TabWidget.setUpdatesEnabled(false);
  QTabBar_moveTab(QTabBarH(TabWidget.TabBar.Widget), Index, NewIndex);
  // DebugLn('TQtWSCustomTabControl.MovePage from Index=',dbgs(Index),' to ',dbgs(NewIndex),' finished.');
  TabWidget.setUpdatesEnabled(true);
  TabWidget.EndUpdate;
end;

class procedure TQtWSCustomTabControl.RemovePage(const ATabControl: TCustomTabControl;
  const AIndex: integer);
var
  TabWidget: TQtTabWidget;
begin
  {$ifdef VerboseQt}
    WriteLn('TQtWSCustomTabControl.RemovePage');
  {$endif}
  TabWidget := TQtTabWidget(ATabControl.Handle);
  TabWidget.setUpdatesEnabled(false);
  TabWidget.BeginUpdate;
  try
    TabWidget.removeTab(AIndex);
  finally
    TabWidget.EndUpdate;
    TabWidget.setUpdatesEnabled(true);
  end;
end;

class function TQtWSCustomTabControl.GetNotebookMinTabHeight(
  const AWinControl: TWinControl): integer;
var
  dy: integer;
  ATabWidget: TQtTabWidget;
begin
  if AWinControl.HandleAllocated and
     (TQtWidget(AWinControl.Handle).ChildOfComplexWidget <> ccwTTabControl)
  then begin
    ATabWidget := TQtTabWidget(AWinControl.Handle);
    Result := 0;
    dy := 0;
    ATabWidget.TabBar.preferredSize(dy, Result, False);
    if Result > 0 then
      exit;
  end;
  Result:=inherited GetNotebookMinTabHeight(AWinControl);
end;

class function TQtWSCustomTabControl.GetNotebookMinTabWidth(
  const AWinControl: TWinControl): integer;
var
  dy: integer;
  ATabWidget: TQtTabWidget;
begin
  if AWinControl.HandleAllocated and
     (TQtWidget(AWinControl.Handle).ChildOfComplexWidget <> ccwTTabControl)
  then begin
    ATabWidget := TQtTabWidget(AWinControl.Handle);
    Result := 0;
    dy := 0;
    ATabWidget.TabBar.preferredSize(Result, dy, False);
    if Result > 0 then
      exit;
  end;
  Result:=inherited GetNotebookMinTabWidth(AWinControl);
end;

class function TQtWSCustomTabControl.GetCapabilities: TCTabControlCapabilities;
begin
  Result := [nbcShowCloseButtons, nbcTabsSizeable];
end;

class function TQtWSCustomTabControl.GetDesignInteractive(
  const AWinControl: TWinControl; AClientPos: TPoint): Boolean;
var
  TabWidget: TQtTabWidget;
  TabBar: TQtTabBar;
  TabIndex: Integer;
  p: TQtPoint;
begin
  Result := False;
  if not WSCheckHandleAllocated(AWinControl, 'GetDesignInteractive') then
    Exit;
  if TQtWidget(AWinControl.Handle).ChildOfComplexWidget = ccwTTabControl then
    exit;
  TabWidget := TQtTabWidget(AWinControl.Handle);
  TabBar := TabWidget.TabBar;
  p := QtPoint(AClientPos.x, AClientPos.y);
  TabIndex := QTabBar_tabAt(QTabBarH(TabBar.Widget), @p);
  Result := (TabIndex >= 0) and (TabWidget.getCurrentIndex <> TabIndex);
end;

class function TQtWSCustomTabControl.GetTabIndexAtPos(
  const ATabControl: TCustomTabControl; const AClientPos: TPoint): integer;
var
  TabWidget: TQtTabWidget;
  NewPos: TPoint;
  R: TRect;
  TabOffset: TPoint;
begin
  TabWidget := TQtTabWidget(ATabControl.Handle);
  NewPos := AClientPos;
  TabOffset := TabWidget.TabBar.TabBarOffset;
  Dec(NewPos.X, TabOffset.X);
  Dec(NewPos.Y, TabOffset.Y);
  R := TabWidget.TabBar.getGeometry;
  case ATabControl.TabPosition of
    tpTop: if NewPos.Y < 0 then NewPos.Y := R.Bottom + NewPos.Y;
    tpLeft: if NewPos.X < 0 then NewPos.X := R.Left + NewPos.X;
    tpRight: NewPos.X := R.Right - NewPos.X;
    tpBottom: NewPos.Y := R.Bottom - NewPos.Y;
  end;
  // issue #28591, return -1 if we are left of first tab with mouse
  if (ATabControl.BiDiMode = bdRightToLeft) and (QApplication_mouseButtons = QtLeftButton) then
  begin
    if not QWidget_underMouse(TabWidget.TabBar.Widget) then
      exit(-1);
  end;
  Result := TabWidget.tabAt(NewPos);
end;

class function TQtWSCustomTabControl.GetTabRect(const ATabControl: TCustomTabControl;
  const AIndex: Integer): TRect;
var
  TabWidget: TQtTabWidget;
  Offs: TRect;
begin
  Result := Rect(-1, -1, -1, -1);
  if not WSCheckHandleAllocated(ATabControl, 'GetTabRect') then
    Exit;
  TabWidget := TQtTabWidget(ATabControl.Handle);
  Offs := TabWidget.getGeometry;
  Result := TabWidget.TabBar.GetTabRect(AIndex);
  case ATabControl.TabPosition of
    tpTop: OffsetRect(Result, 0, -Result.Bottom);
    tpLeft: OffsetRect(Result, -Result.Right, 0);
    tpRight: OffsetRect(Result, Offs.Width - Result.Right, 0);
    tpBottom: OffsetRect(Result, 0, Offs.Height - Result.Bottom);
  end;
end;

class procedure TQtWSCustomTabControl.SetPageIndex(
  const ATabControl: TCustomTabControl; const AIndex: integer);
var
  TabWidget: TQtTabWidget;
begin
  if ATabControl is TTabControl then
    exit;

  if not WSCheckHandleAllocated(ATabControl, 'SetPageIndex') then
    Exit;
  TabWidget := TQtTabWidget(ATabControl.Handle);

  if (AIndex < 0) or (AIndex > ATabControl.PageCount - 1) then
    exit;

  TabWidget.BeginUpdate;
  if ATabControl.Page[AIndex].HandleAllocated then
    TabWidget.setCurrentWidget(TQtWidget(ATabControl.Page[AIndex].Handle), False);
  TabWidget.EndUpdate;
end;

class procedure TQtWSCustomTabControl.SetTabCaption(
  const ATabControl: TCustomTabControl; const AChild: TCustomPage;
  const AText: string);
var
  Index: Integer;
begin
  Index := AChild.PageIndex;
  if Index < 0 then
    Index := ATabControl.IndexOf(AChild);
  TQtTabWidget(ATabControl.Handle).setTabText(Index, AText{%H-});
end;

class procedure TQtWSCustomTabControl.SetTabPosition(
  const ATabControl: TCustomTabControl; const ATabPosition: TTabPosition);
begin
  TQtTabWidget(ATabControl.Handle).SetTabPosition(QTabWidgetTabPositionMap[ATabPosition]);
end;

class procedure TQtWSCustomTabControl.SetTabSize(
  const ATabControl: TCustomTabControl; const ATabWidth, ATabHeight: integer);
const
  FmtS = 'QTabBar::tab { height: %dpx; width: %dpx; }';
var
  ASize, ANewSize: TSize;
  WS: WideString;
begin
  if not WSCheckHandleAllocated(ATabControl, 'SetTabSize') then
    Exit;
  ASize.cx := -1;
  ASize.cy := -1;
  ANewSize := ASize;
  if ATabWidth > 0 then
    ANewSize.cx := ATabWidth;
  if ATabHeight > 0 then
    ANewSize.cy := ATabHeight;
  if (ATabWidth = 0) and (ATabHeight = 0) then
    WS := ''
  else
  begin
    if ATabControl.TabPosition in [tpLeft, tpRight] then
      WS := {%H-}Format(FmtS, [ANewSize.cx, ANewSize.cy])
    else
      WS := {%H-}Format(FmtS, [ANewSize.cy, ANewSize.cx]);
  end;
  QWidget_setStyleSheet(TQtTabWidget(ATabControl.Handle).Widget, @WS);
end;

class procedure TQtWSCustomTabControl.ShowTabs(const ATabControl: TCustomTabControl;
  AShowTabs: boolean);
var
  TabWidget: TQtTabWidget;
begin
  if not WSCheckHandleAllocated(ATabControl, 'ShowTabs') then
    Exit;
  if TQtWidget(ATabControl.Handle).ChildOfComplexWidget <> ccwTTabControl then
  begin
    TabWidget := TQtTabWidget(ATabControl.Handle);
    if TabWidget.TabBar <> nil then
      TabWidget.ShowTabs := AShowTabs;
  end;
end;

class procedure TQtWSCustomTabControl.UpdateProperties(const ATabControl: TCustomTabControl);
begin
  if not WSCheckHandleAllocated(ATabControl, 'UpdateProperties') then
    Exit;
  if TQtWidget(ATabControl.Handle).ChildOfComplexWidget <> ccwTTabControl then
  begin
    TQtTabWidget(ATabControl.Handle).setTabsClosable(nboShowCloseButtons in ATabControl.Options);
    TQtTabWidget(ATabControl.Handle).SwitchTabsByKeyboard := nboKeyboardTabSwitch in ATabControl.Options;
  end;
end;


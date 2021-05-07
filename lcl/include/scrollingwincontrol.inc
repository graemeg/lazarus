{%MainUnit ../forms.pp}

{
 *****************************************************************************
  This file is part of the Lazarus Component Library (LCL)

  See the file COPYING.modifiedLGPL.txt, included in this distribution,
  for details about the license.
 *****************************************************************************
}

procedure TScrollingWinControl.SetAutoScroll(Value: Boolean);
var
  LOldBounds: TRect;
begin
  if FAutoScroll = Value then Exit;
  FAutoScroll := Value;
  LOldBounds := BoundsRect;
  if Value then
    UpdateScrollBars
  else
    HideScrollbars;
  if LOldBounds <> BoundsRect then
    BoundsRect := LOldBounds;
end;

procedure TScrollingWinControl.CreateWnd;
begin
  DisableAutoSizing{$IFDEF DebugDisableAutoSizing}('TScrollingWinControl.CreateWnd'){$ENDIF};
  try
    inherited CreateWnd;
    UpdateScrollBars;
  finally
    EnableAutoSizing{$IFDEF DebugDisableAutoSizing}('TScrollingWinControl.CreateWnd'){$ENDIF};
  end;
end;

function TScrollingWinControl.GetClientScrollOffset: TPoint;
begin
  if (HorzScrollBar <> nil) and (VertScrollBar <> nil) then
  begin
    Result.X := HorzScrollBar.Position;
    Result.Y := VertScrollBar.Position;
  end else
  begin
    Result.X := 0;
    Result.Y := 0;
  end;
end;

function TScrollingWinControl.GetLogicalClientRect: TRect;
begin
  Result := ClientRect;
  {if (FHorzScrollBar.Range>Result.Right)
  or (FVertScrollBar.Range>Result.Bottom) then
    DebugLn(['TScrollingWinControl.GetLogicalClientRect Client=',ClientWidth,'x',ClientHeight,' Ranges=',FHorzScrollBar.Range,'x',FVertScrollBar.Range]);}
  if Assigned(FHorzScrollBar) and FHorzScrollBar.Visible
  and (FHorzScrollBar.Range > Result.Right) then
    Result.Right := FHorzScrollBar.Range;
  if Assigned(FVertScrollBar) and FVertScrollBar.Visible
  and (FVertScrollBar.Range > Result.Bottom) then
    Result.Bottom := FVertScrollBar.Range;
end;

procedure TScrollingWinControl.DoOnResize;
begin
  inherited DoOnResize;

  if AutoScroll then
  begin
    if (HorzScrollBar = nil) or (VertScrollBar = nil) then Exit;
    if HorzScrollBar.Visible or VertScrollBar.Visible then
      UpdateScrollBars;
  end;
  //debugln(['TScrollingWinControl.DoOnResize ',DbgSName(Self),' ',dbgs(BoundsRect),' ',dbgs(ClientRect),' ',dbgs(GetLogicalClientRect)]);
end;

procedure TScrollingWinControl.GetPreferredSizeClientFrame(out aWidth,
  aHeight: integer);
// return frame width independent of scrollbars (i.e. as if scrollbars not shown)
begin
  if AutoScroll and (VertScrollBar<>nil) then
    aWidth:=Width-VertScrollBar.ClientSizeWithoutBar
  else
    aWidth:=Width-ClientWidth;
  if AutoScroll and (HorzScrollBar<>nil) then
    aHeight:=Height-HorzScrollBar.ClientSizeWithoutBar
  else
    aHeight:=Height-ClientHeight;
end;

procedure TScrollingWinControl.AlignControls(AControl: TControl; var ARect: TRect);
begin
  if AutoScroll then
  begin
    if (HorzScrollBar = nil) or (VertScrollBar = nil) then Exit;
    inherited AlignControls(AControl, ARect);

    UpdateScrollBars;
  end
  else
    inherited AlignControls(AControl, ARect);
end;

function TScrollingWinControl.AutoScrollEnabled: Boolean;
begin
  Result := not (AutoSize or (DockSite and UseDockManager));
end;

procedure TScrollingWinControl.CalculateAutoRanges;
var
  NeededClientW: Integer;
  NeededClientH: Integer;
  FrameWidth: integer;
  FrameHeight: integer;
begin
  NeededClientW:=0;
  NeededClientH:=0;
  GetPreferredSize(NeededClientW,NeededClientH,true,false);
  GetPreferredSizeClientFrame(FrameWidth,FrameHeight);
  if NeededClientW>0 then
    NeededClientW-=FrameWidth;
  if NeededClientH>0 then
    NeededClientH-=FrameHeight;

  if HorzScrollBar.Visible then
    HorzScrollBar.InternalSetRange(NeededClientW)
  else
    HorzScrollBar.InternalSetRange(0);

  if VertScrollBar.Visible then
    VertScrollBar.InternalSetRange(NeededClientH)
  else
    VertScrollBar.InternalSetRange(0);
end;

class function TScrollingWinControl.GetControlClassDefaultSize: TSize;
begin
  Result.CX := 150;
  Result.CY := 150;
end;

procedure TScrollingWinControl.SetHorzScrollBar(Value: TControlScrollBar);
begin
  FHorzScrollbar.Assign(Value);
end;

procedure TScrollingWinControl.SetVertScrollBar(Value: TControlScrollBar);
begin
  FVertScrollbar.Assign(Value);
end;

procedure TScrollingWinControl.HideScrollbars;
begin
  if Assigned(FHorzScrollBar) and FHorzScrollBar.HandleAllocated then
  begin
    ShowScrollBar(FHorzScrollBar.ControlHandle, SB_Horz, False);
    FHorzScrollBar.Range := 0;
    FHorzScrollBar.Page := 80;
    FHorzScrollBar.Position := 0;
  end;
  if Assigned(FVertScrollBar) and FVertScrollBar.HandleAllocated then
  begin
    ShowScrollBar(FVertScrollBar.ControlHandle, SB_Vert, False);
    FVertScrollBar.Range := 0;
    FVertScrollBar.Page := 80;
    FVertScrollBar.Position := 0;
  end;
end;

procedure TScrollingWinControl.WMSize(var Message: TLMSize);
var
  NewState: TWindowState;
begin
  inherited;
  if (Message.SizeType and SIZE_SourceIsInterface) <> 0 then
  begin
    NewState := wsNormal;
    case (Message.SizeType xor SIZE_SourceIsInterface) of
      SIZE_MINIMIZED:
        NewState := wsMinimized;
      SIZE_MAXIMIZED:
        NewState := wsMaximized;
      SIZE_FULLSCREEN:
        NewState := wsFullScreen;
    end;
    Resizing(NewState);
  end;
end;

procedure TScrollingWinControl.Resizing(State: TWindowState);
begin
  //
end;

procedure TScrollingWinControl.ComputeScrollbars;
  procedure UpdateBar(aBar: TControlScrollBar; aClientSize: integer);
  begin
    // page (must be smaller than Range but at least 1)
    aBar.FPage := Max(1,Min(Min(aBar.Range,aClientSize), High(HorzScrollbar.FPage)));
    aBar.FAutoRange := Max(0, aBar.Range - aClientSize);
    {$IFDEF VerboseScrollingWinControl}
    debugln(['TScrollingWinControl.ComputeScrollbars ',DbgSName(Self),' ',dbgs(aBar.Kind),' Page=',aBar.Page,' Range=',aBar.Range,' ClientSize=',aClientSize]);
    {$ENDIF}
  end;
  
var
  ClientW: Integer;
  ClientH: Integer;
begin
  CalculateAutoRanges;

  ClientW:=VertScrollBar.ClientSizeWithoutBar;
  ClientH:=HorzScrollBar.ClientSizeWithoutBar;
  {$IFDEF VerboseScrollingWinControl}
  debugln(['TScrollingWinControl.ComputeScrollbars ',DbgSName(Self),' Bounds=',dbgs(BoundsRect),' ClientRect=',dbgs(ClientRect),' ClientRectNoScrollBars=',ClientW,'x',ClientH]);
  {$ENDIF}

  if VertScrollBar.Range > ClientH then
  begin
    // vertical does not fit -> vertical scrollbar will be shown
    ClientW:=VertScrollBar.ClientSizeWithBar;
  end;
  if HorzScrollBar.Range > ClientW then
  begin
    // horizontal does not fit -> horizontal scrollbar will be shown
    ClientH:=HorzScrollBar.ClientSizeWithBar;
    if VertScrollBar.Range > ClientH then
    begin
      // vertical does not fit, because of the other scrollbar
      // -> vertical scrollbar will be shown too
      ClientW:=VertScrollBar.ClientSizeWithBar;
    end;
  end;

  UpdateBar(HorzScrollBar,ClientW);
  UpdateBar(VertScrollBar,ClientH);
end;

procedure TScrollingWinControl.UpdateScrollbars;
begin
  if ([csLoading, csDestroying] * ComponentState <> []) then Exit;
  if not HandleAllocated then Exit;
  if (HorzScrollBar = nil) or (VertScrollBar = nil) then Exit;

  if FIsUpdating then Exit;

  FIsUpdating := True;
  try
    if AutoScroll then
      ComputeScrollbars; // page, autorange, IsScrollBarVisible
    FVertScrollbar.UpdateScrollbar;
    FHorzScrollbar.UpdateScrollbar;
  finally
    FIsUpdating := False;
  end;
end;

class procedure TScrollingWinControl.WSRegisterClass;
const
  Registered : boolean = False;
begin
  if Registered then
    Exit;
  inherited WSRegisterClass;
  RegisterScrollingWinControl;
  Registered := True;
end;

procedure TScrollingWinControl.ScrollBy(DeltaX, DeltaY: Integer);
begin
  ScrollBy_WS(DeltaX, DeltaY);
end;

procedure TScrollingWinControl.ScrollInView(AControl: TControl);
var
  LRect: TRect;
  LPoint: TPoint;
  LHorzVisible, LVertVisible: Boolean;
begin
  if (AControl = nil) or not IsParentOf(AControl) then Exit;
  LHorzVisible := HorzScrollBar.IsScrollBarVisible;
  LVertVisible := VertScrollBar.IsScrollBarVisible;
  if not LHorzVisible and not LVertVisible then Exit;
  LRect := Rect(0, 0, AControl.Width, AControl.Height);
  LPoint := AControl.ClientToParent(Point(0, 0), Self);
  OffsetRect(LRect, LPoint.x, LPoint.y);
  if LHorzVisible then
    if LRect.Left < 0 then
      HorzScrollBar.Position := HorzScrollBar.Position + LRect.Left
    else if LRect.Right > ClientWidth then
    begin
      if LRect.Right - LRect.Left > ClientWidth then
        LRect.Right := LRect.Left + ClientWidth;
      HorzScrollBar.Position := HorzScrollBar.Position + LRect.Right - ClientWidth;
    end;
  if LVertVisible then
    if LRect.Top < 0 then
      VertScrollBar.Position := VertScrollBar.Position + LRect.Top
    else if LRect.Bottom > ClientHeight then
    begin
      if LRect.Bottom - LRect.Top > ClientHeight then
        LRect.Bottom := LRect.Top + ClientHeight;
      VertScrollBar.Position := VertScrollBar.Position + LRect.Bottom - ClientHeight;
    end;
end;

procedure TScrollingWinControl.Loaded;
begin
  inherited Loaded;
  UpdateScrollbars;
end;

procedure TScrollingWinControl.SetAutoSize(Value: Boolean);
begin
  if AutoSize=Value then exit;
  if Value then
    ControlStyle:=ControlStyle-[csAutoSizeKeepChildLeft,csAutoSizeKeepChildTop]
  else
    ControlStyle:=ControlStyle+[csAutoSizeKeepChildLeft,csAutoSizeKeepChildTop];
  inherited SetAutoSize(Value);
end;

procedure TScrollingWinControl.WMVScroll(var Message : TLMVScroll);
begin
  VertScrollbar.ScrollHandler(Message);
end;

procedure TScrollingWinControl.WMHScroll(var Message : TLMHScroll);
begin
  //DebugLn(['TScrollingWinControl.WMHScroll ',dbgsName(Self)]);
  HorzScrollbar.ScrollHandler(Message);
end;

constructor TScrollingWinControl.Create(TheOwner : TComponent);
begin
  Inherited Create(TheOwner);

  FAutoScroll := False;
  FVertScrollbar := TControlScrollBar.Create(Self, sbVertical);
  FHorzScrollbar := TControlScrollBar.Create(Self, sbHorizontal);

  ControlStyle := [csAcceptsControls, csClickEvents, csDoubleClicks,
                   csAutoSizeKeepChildLeft, csAutoSizeKeepChildTop];

  with GetControlClassDefaultSize do
    SetInitialBounds(0, 0, CX, CY);
end;

destructor TScrollingWinControl.Destroy;
begin
  FreeThenNil(FHorzScrollBar);
  FreeThenNil(FVertScrollBar);
  inherited Destroy;
end;

function TScrollingWinControl.ScreenToClient(const APoint: TPoint): TPoint;
var
  P: TPoint;
begin
  P := GetClientScrollOffset;
  Result := inherited;
  Result.x := Result.x - P.x;
  Result.y := Result.y - P.y;
end;

function TScrollingWinControl.ClientToScreen(const APoint: TPoint): TPoint;
var
  P: TPoint;
begin
  P := GetClientScrollOffset;
  Result := inherited;
  Result.x := Result.x + P.x;
  Result.y := Result.y + P.y;
end;

// included by forms.pp

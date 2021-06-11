{%MainUnit ../comctrls.pp}

{
 *****************************************************************************
  This file is part of the Lazarus Component Library (LCL)

  See the file COPYING.modifiedLGPL.txt, included in this distribution,
  for details about the license.
 *****************************************************************************
}

{------------------------------------------------------------------------------
  TCustomPage Constructor
 ------------------------------------------------------------------------------}
constructor TCustomPage.Create(TheOwner: TComponent);
begin
  inherited Create(TheOwner);

  FImageIndex := -1;
  FCompStyle := csPage;
  FTabVisible := True;
  ControlStyle := ControlStyle + [csAcceptsControls, csDesignFixedBounds, csNoDesignVisible, csNoFocus];

  // height and width depends on parent, align to client rect
  Align := alClient;
  Caption := '';
  Visible := False;
end;

{------------------------------------------------------------------------------
  method TCustomPage SetImageIndex
  Params: const AValue: integer
  Result: none

  Set the image index of the image shown in the tabs.
 ------------------------------------------------------------------------------}
procedure TCustomPage.SetImageIndex(const AValue: TImageIndex);
begin
  if FImageIndex = AValue then Exit;
  FImageIndex := AValue;
  if not HandleAllocated or (csLoading in ComponentState) then Exit;
  TWSCustomPageClass(WidgetSetClass).UpdateProperties(Self);
end;

function TCustomPage.GetTabVisible: Boolean;
begin
  Result := FTabVisible;
end;

procedure TCustomPage.SetTabVisible(const AValue: Boolean);
begin
  if AValue = FTabVisible then Exit;
  FTabVisible := AValue;
 
  if csDesigning in ComponentState then
    Exit;

  if Assigned(Parent) and Parent.HandleAllocated then
  begin
    if FTabVisible then
    begin
      // check if there was no visible tab
      if TCustomTabControl(Parent).PageIndex = -1 then
        TCustomTabControl(Parent).PageIndex:=PageIndex;
    end
    else
      // Check if the page is active and set a new pageindex
      TCustomTabControl(Parent).PageRemoved(PageIndex);
    TCustomTabControl(Parent).AddRemovePageHandle(Self);
    TCustomTabControl(Parent).DoSendPageIndex;
  end;
end;

class procedure TCustomPage.WSRegisterClass;
begin
  inherited WSRegisterClass;
  RegisterCustomPage;
end;

{------------------------------------------------------------------------------
  TCustomPage WMPaint
  Params: a TLMPaint message
 ------------------------------------------------------------------------------}
procedure TCustomPage.WMPaint(var Msg: TLMPaint);
var
    Notebook: TCustomTabControl;
begin
  if Parent is TCustomTabControl then
  begin
    NoteBook := TCustomTabControl(Parent);
    if (NoteBook.PageIndex >= 0) and (NoteBook.Page[NoteBook.PageIndex] = Self) then
      inherited WMPaint(Msg);
  end
  else
    inherited WMPaint(Msg);
end;

{------------------------------------------------------------------------------
  procedure TCustomPage.SetParent(AParent: TWinControl);

  Set parent wincontrol.
 ------------------------------------------------------------------------------}
procedure TCustomPage.SetParent(AParent: TWinControl);
var
  OldParent: TWinControl;
  ParentNotebook: TCustomTabControl;
  i: integer;
begin
  if (AParent = Parent) or (pfInserting in FFlags) then Exit;
  CheckNewParent(AParent);
  OldParent := Parent;
  if (OldParent <> AParent) and (OldParent is TCustomTabControl) and
    (not (pfRemoving in FFlags)) then
  begin
    // remove from old pagelist
    ParentNotebook := TCustomTabControl(OldParent);
    i := PageIndex;
    if i >= 0 then
      ParentNotebook.RemovePage(i);
  end;

  inherited SetParent(AParent);

  if (OldParent <> AParent) and (Parent is TCustomTabControl) then
  begin
    // add to new pagelist
    ParentNotebook := TCustomTabControl(Parent);
    i := ParentNotebook.IndexOf(Self);
    if i < 0 then
      ParentNotebook.InsertPage(Self, ParentNotebook.PageCount);
  end;
end;

{------------------------------------------------------------------------------
  procedure TCustomPage.CMHitTest(var Message: TLMNCHITTEST);
 ------------------------------------------------------------------------------}
procedure TCustomPage.CMHitTest(var Message: TLMNCHITTEST);
begin
  if (Parent is TCustomTabControl) and
     (TCustomTabControl(Parent).ActivePageComponent <> Self) then
    Message.Result := 0 // no hit
  else
    inherited CMHitTest(Message);
  {DebugLn('TCustomPage.CMHitTest A ',Name,' ',(Parent<>nil),' ',
    (Parent is TCustomTabControl),' ',
    (TCustomTabControl(Parent).ActivePageComponent<>Self),
    ' Message.Result=',Message.Result);}
end;

procedure TCustomPage.CMVisibleChanged(var Message: TLMessage);
begin
  inherited CMVisibleChanged(Message);
  if Visible then
    DoShow
  else
    DoHide;
end;

{------------------------------------------------------------------------------
  function TCustomPage.PageIndex: integer;

  Returns the index of the page in the notebook.
 ------------------------------------------------------------------------------}
function TCustomPage.GetPageIndex: integer;
begin
  if Parent is TCustomTabControl then
    Result := TCustomTabControl(Parent).IndexOf(Self)
  else
    Result := -1;
end;

procedure TCustomPage.SetPageIndex(AValue: Integer);
begin
  if Parent is TCustomTabControl then
    TCustomTabControl(Parent).MoveTab(Self,AValue);
  //DebugLn('TCustomPage.SetPageIndex Old=',dbgs(PageIndex),' New=',dbgs(AValue));
end;

function TCustomPage.DialogChar(var Message: TLMKey): boolean;
begin
  Result := False;
  if (not (csDesigning in ComponentState)) and IsAccel(Message.CharCode, Caption) and TabVisible then
  begin
    Result := True;
    if Parent is TCustomTabControl then
      TCustomTabControl(Parent).PageIndex := PageIndex;
  end
  else
    Result := inherited DialogChar(Message);
end;

procedure TCustomPage.DoHide;
begin
  if Assigned(FOnHide) then
    FOnHide(Self);
end;

procedure TCustomPage.DoShow;
begin
  if Assigned(FOnShow) then
    FOnShow(Self);
end;

procedure TCustomPage.DestroyHandle;
begin
  inherited DestroyHandle;
  Exclude(FFlags,pfAdded);
end;

procedure TCustomPage.RealSetText(const AValue: TCaption);
begin
  if (Parent <> nil) and Parent.HandleAllocated and (not (csLoading in ComponentState)) then
  begin
    WSSetText(AValue);
    InvalidatePreferredSize;
    inherited RealSetText(AValue);
    AdjustSize;
  end
  else inherited RealSetText(AValue);
end;

function TCustomPage.IsControlVisible: Boolean;
begin
  // when autosizing, need this to return True so that the sizes of non-active
  // pages will be considered in parent's GetPreferredSize()
  if AutoSizingAll then
    Exit(True);
  Result := inherited IsControlVisible;
  if Result and (Parent is TCustomTabControl) then
    Result := PageIndex = TCustomTabControl(Parent).PageIndex;
end;

function TCustomPage.HandleObjectShouldBeVisible: boolean;
begin
  Result := inherited HandleObjectShouldBeVisible;
  if Result and (Parent is TCustomTabControl) then
    Result := PageIndex = TCustomTabControl(Parent).PageIndex;
end;

function TCustomPage.VisibleIndex: integer;
// returns the visible index, as if TabVisible=true
var
  notebook: TCustomTabControl;
  i: Integer;
begin
(* Removed PageList dependency.
  Added missing result value.
*)
  if Parent is TCustomTabControl then
  begin
    Result := 0;
    //List := TCustomTabControl(Parent).PageList;
    notebook := TCustomTabControl(Parent);
    i := 0;
    repeat
      if i = notebook.PageCount then exit(-1);
      if notebook.Page[i] = Self then exit;
      if (csDesigning in ComponentState) or notebook.Page[i].TabVisible
      then inc(Result);
      inc(i);
    until False;
  end;
// else
  Result := -1;
end;

procedure TCustomPage.CheckNewParent(AParent: TWinControl);
begin
  if (AParent<>nil) and (not (AParent is TCustomTabControl)) then
    raise EInvalidOperation.CreateFmt(rsASCannotHaveAsParent, [ClassName,
      AParent.ClassName]);
  inherited CheckNewParent(AParent);
end;

{------------------------------------------------------------------------------
  function TCustomPage.CanTab: boolean;
 ------------------------------------------------------------------------------}
function TCustomPage.CanTab: boolean;
begin
  Result := False;
end;

// included by comctrls.pp

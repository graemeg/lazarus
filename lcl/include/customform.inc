{%MainUnit ../forms.pp}

{******************************************************************************
                               TCustomForm
 ******************************************************************************

 *****************************************************************************
  This file is part of the Lazarus Component Library (LCL)

  See the file COPYING.modifiedLGPL.txt, included in this distribution,
  for details about the license.
 *****************************************************************************
}

{ $DEFINE CHECK_POSITION}

const
  BorderStylesAllowAutoScroll = [bsSizeable, bsSizeToolWin];
  ShowCommands: array[TWindowState] of Integer =
    (SW_SHOWNORMAL, SW_MINIMIZE, SW_SHOWMAXIMIZED, SW_SHOWFULLSCREEN);

{ TCustomForm }

{------------------------------------------------------------------------------
  procedure TCustomForm.CloseModal;
 ------------------------------------------------------------------------------}
procedure TCustomForm.CloseModal;
var
  CloseAction: TCloseAction;
begin
  try
    CloseAction := caNone;
    if CloseQuery then
    begin
      CloseAction := caHide;
      DoClose(CloseAction);
    end;
    case CloseAction of
      caNone: ModalResult := 0;
      caFree: Release;
    end;
    { do not call widgetset CloseModal here, but in ShowModal to
      guarantee execution of it }
  except
    ModalResult := 0;
    Application.HandleException(Self);
  end;
end;

procedure TCustomForm.FreeIconHandles;
begin
  if FSmallIconHandle <> 0 then
  begin
    DestroyIcon(FSmallIconHandle);
    FSmallIconHandle := 0;
  end;

  if FBigIconHandle <> 0 then
  begin
    DestroyIcon(FBigIconHandle);
    FBigIconHandle := 0;
  end;
end;

{------------------------------------------------------------------------------
  Method: TCustomForm.AfterConstruction
  Params:  None
  Returns: Nothing

  Gets called after the construction of the object
 ------------------------------------------------------------------------------}
procedure TCustomForm.AfterConstruction;
var
  MonPPI: Integer;
begin
  SetRestoredBounds(Left, Top, Width, Height, True);
  DoCreate;
  EndFormUpdate; // the BeginFormUpdate is in CreateNew
  inherited AfterConstruction;

  MonPPI := Monitor.PixelsPerInch;
  if Application.Scaled and Scaled and (MonPPI > 0) and (MonPPI <> PixelsPerInch)
  and not (csDesigning in ComponentState) then
    AutoAdjustLayout(lapAutoAdjustForDPI, PixelsPerInch, MonPPI,
                     Width, MulDiv(Width, MonPPI, PixelsPerInch));
end;

{------------------------------------------------------------------------------
  Method: TCustomForm.BeforeDestruction
  Params:  None
  Returns: Nothing

  Gets called before the destruction of the object
 ------------------------------------------------------------------------------}
procedure TCustomForm.BeforeDestruction;
begin
  // set csDestroying
  inherited BeforeDestruction;
  //debugln(['TCustomForm.BeforeDestruction ',DbgSName(Self),' ',csDestroying in ComponentState]);
  // EndWrite will happen in the destructor
  GlobalNameSpace.BeginWrite;
  Screen.FSaveFocusedList.Remove(Self);
  RemoveFixupReferences(Self, '');
  if (FormStyle <> fsMDIChild) or (csDesigning in ComponentState) then
    Hide
  else
  if Assigned(Menu) and Assigned(Application.MainForm) and Assigned(Application.MainForm.Menu) then
    Application.MainForm.Menu.Unmerge(Menu);
  DoDestroy;
  // don't call the inherited method because it calls Destroying which is already called
end;

{------------------------------------------------------------------------------
  Method: TCustomForm.Destroy
  Params:  None
  Returns: Nothing

  Destructor for the class.
 ------------------------------------------------------------------------------}
destructor TCustomForm.Destroy;
var
  HandlerType: TFormHandlerType;
begin
  //DebugLn('[TCustomForm.Destroy] A ',Name,':',ClassName);
  if not (csDestroying in ComponentState) then
    GlobalNameSpace.BeginWrite;
  try
    Application.RemoveAsyncCalls(Self); // because of Application.QueueAsyncCall(@Moved, 0); in WMMove
    DisableAutoSizing{$IFDEF DebugDisableAutoSizing}('TCustomForm.Destroy'){$ENDIF};
    FreeThenNil(FIcon);
    FreeIconHandles;
    Screen.RemoveForm(Self);
    FreeThenNil(FActionLists);
    for HandlerType:=Low(FFormHandlers) to High(FFormHandlers) do
      FreeThenNil(FFormHandlers[HandlerType]);
    //DebugLn('[TCustomForm.Destroy] B ',Name,':',ClassName);
    inherited Destroy;
    //DebugLn('[TCustomForm.Destroy] END ',Name,':',ClassName);
  finally
    // BeginWrite has happen either in the BeforeDestrucion or here
    GlobalNameSpace.EndWrite;
  end;
end;

{------------------------------------------------------------------------------
  Method: TCustomForm.FocusControl
  Params:  None
  Returns: Nothing

  Focus the control. If needed, bring form to front and focus it.
  If Form is not visible or disabled raise an exception.
 ------------------------------------------------------------------------------}
procedure TCustomForm.FocusControl(WinControl: TWinControl);
var
  WasActive: Boolean;
begin
  WasActive := FActive;
  SetActiveControl(WinControl);
  if (not WasActive) then
    SetFocus; // if not CanFocus then this will raise an exception
end;

{------------------------------------------------------------------------------
  Method: TCustomForm.Notification
 ------------------------------------------------------------------------------}
procedure TCustomForm.Notification(AComponent: TComponent;
  Operation: TOperation);
begin
  inherited Notification(AComponent,Operation);

  case Operation of
    opInsert:
      begin
        if AComponent is TCustomActionList then
        begin
          DoAddActionList(TCustomActionList(AComponent));
        end
        else
        if not (csLoading in ComponentState) and (Menu = nil) and
          (AComponent.Owner=Self) and (AComponent is TMainMenu) then
          Menu := TMainMenu(AComponent);
      end;
    opRemove:
      begin
        // first clean up references
        if FActiveControl = AComponent then
        begin
          {$IFDEF VerboseFocus}
          debugln('TCustomForm.Notification opRemove FActiveControl=',DbgSName(AComponent));
          {$ENDIF}
          FActiveControl := nil;
        end;
        if AComponent = FActiveDefaultControl then
          FActiveDefaultControl := nil;
        if AComponent = FDefaultControl then
          FDefaultControl := nil;
        if AComponent = FCancelControl then
          FCancelControl := nil;
        if AComponent = FLastFocusedControl then
          FLastFocusedControl := nil;
        // then do stuff which can trigger things
        if Assigned(FActionLists) and (AComponent is TCustomActionList) then
          DoRemoveActionList(TCustomActionList(AComponent))
        else
        if AComponent = Menu then
          Menu := nil
        else
        if AComponent = PopupParent then
          PopupParent := nil;
      end;
  end;
  if FDesigner <> nil then
    FDesigner.Notification(AComponent, Operation);
end;

{------------------------------------------------------------------------------
  Method: TCustomForm.IconChanged
 ------------------------------------------------------------------------------}
procedure TCustomForm.IconChanged(Sender: TObject);
begin
  if HandleAllocated then
  begin
    FreeIconHandles;
    if BorderStyle <> bsDialog then
      TWSCustomFormClass(WidgetSetClass).SetIcon(Self, SmallIconHandle, BigIconHandle)
    else
      TWSCustomFormClass(WidgetSetClass).SetIcon(Self, 0, 0);
  end;
end;

procedure TCustomForm.SetCancelControl(NewControl: TControl);
var
  OldCancelControl: TControl;
begin
  if NewControl <> FCancelControl then
  begin
    OldCancelControl := FCancelControl;
    FCancelControl := NewControl;
    // notify old control
    if Assigned(OldCancelControl) then
      OldCancelControl.UpdateRolesForForm;
    // notify new control
    if Assigned(FCancelControl) then 
    begin
      FreeNotification(FCancelControl);
      FCancelControl.UpdateRolesForForm;
    end;
  end;
end;

procedure TCustomForm.SetDefaultControl(NewControl: TControl);
var
  OldDefaultControl: TControl;
begin
  if NewControl <> FDefaultControl then
  begin
    OldDefaultControl := FDefaultControl;
    FDefaultControl := NewControl;
    // notify old control
    if Assigned(OldDefaultControl) then
      OldDefaultControl.UpdateRolesForForm;
    // notify new control
    if Assigned(FDefaultControl) then
    begin
      FDefaultControl.FreeNotification(Self);
      FDefaultControl.UpdateRolesForForm;
    end;
    // maybe active default control changed
    if not Assigned(FActiveDefaultControl) then
    begin
      if Assigned(OldDefaultControl) then
        OldDefaultControl.ActiveDefaultControlChanged(nil);
      if Assigned(FDefaultControl) then
        FDefaultControl.ActiveDefaultControlChanged(nil);
    end;
  end;
end;

{------------------------------------------------------------------------------
  Method: TCustomForm.SetIcon
  Params: the new icon
 ------------------------------------------------------------------------------}
procedure TCustomForm.SetIcon(AValue: TIcon);
begin
  FIcon.Assign(AValue);
end;

procedure TCustomForm.SetPopupMode(const AValue: TPopupMode);
begin
  if FPopupMode <> AValue then
  begin
    FPopupMode := AValue;
    if (FPopupMode in [pmAuto, pmNone]) and (PopupParent <> nil) then
      PopupParent := nil
    else
    if not (csDesigning in ComponentState) and HandleAllocated then
      TWSCustomFormClass(WidgetSetClass).SetRealPopupParent(Self, GetRealPopupParent);
  end;
end;

procedure TCustomForm.SetPopupParent(const AValue: TCustomForm);
begin
  if FPopupParent <> AValue then
  begin
    if FPopupParent <> nil then
      FPopupParent.RemoveFreeNotification(Self);
    FPopupParent := AValue;
    if FPopupParent <> nil then
    begin
      FPopupParent.FreeNotification(Self);
      FPopupMode := pmExplicit;
    end;
    if not (csDesigning in ComponentState) and HandleAllocated then
      TWSCustomFormClass(WidgetSetClass).SetRealPopupParent(Self, GetRealPopupParent);
  end;
end;

{------------------------------------------------------------------------------
  Method: TCustomForm.BigIconHandle
  Returns: HICON
 ------------------------------------------------------------------------------}
function TCustomForm.BigIconHandle: HICON;
var
  OldChange: TNotifyEvent;
  OldCurrent: Integer;
begin
  if Assigned(FIcon) and not FIcon.Empty then
  begin
    if FBigIconHandle = 0 then
    begin
      OldChange := FIcon.OnChange;
      OldCurrent := FIcon.Current;
      FIcon.OnChange := nil;
      FIcon.Current := Icon.GetBestIndexForSize(Size(GetSystemMetrics(SM_CXICON), GetSystemMetrics(SM_CYICON)));
      FBigIconHandle := FIcon.ReleaseHandle;
      FIcon.Current := OldCurrent;
      FIcon.OnChange := OldChange;
    end;
    Result := FBigIconHandle;
  end
  else
    Result := Application.BigIconHandle;
end;

{------------------------------------------------------------------------------
  Method: TCustomForm.SmallIconHandle
  Returns: HICON
 ------------------------------------------------------------------------------}
function TCustomForm.SmallIconHandle: HICON;
var
  OldChange: TNotifyEvent;
  OldCurrent: Integer;
begin
  if Assigned(FIcon) and not FIcon.Empty then
  begin
    if FSmallIconHandle = 0 then
    begin
      OldChange := FIcon.OnChange;
      OldCurrent := FIcon.Current;
      FIcon.OnChange := nil;
      FIcon.Current := Icon.GetBestIndexForSize(Size(GetSystemMetrics(SM_CXSMICON), GetSystemMetrics(SM_CYSMICON)));
      FSmallIconHandle := FIcon.ReleaseHandle;
      FIcon.Current := OldCurrent;
      FIcon.OnChange := OldChange;
    end;
    Result := FSmallIconHandle;
  end
  else
    Result := Application.SmallIconHandle;
end;

{------------------------------------------------------------------------------
  Method: TCustomForm.SetFocus
 ------------------------------------------------------------------------------}
procedure TCustomForm.SetFocus;

  procedure RaiseCannotFocus;
  var
    s: String;
  begin
    s:='[TCustomForm.SetFocus] '+Name+':'+ClassName+' '+rsCanNotFocus;
    {$IFDEF VerboseFocus}
    RaiseGDBException(s);
    {$ELSE}
    raise EInvalidOperation.Create(s);
    {$ENDIF}
  end;

begin
  {$IFDEF VerboseFocus}
  DebugLn('TCustomForm.SetFocus ',Name,':',ClassName,' ActiveControl=',DbgSName(ActiveControl));
  {$ENDIF}
  if not FActive then
  begin
    if not (IsControlVisible and Enabled) then
      RaiseCannotFocus;
    SetWindowFocus;
  end;
end;

{------------------------------------------------------------------------------
       TCustomForm SetVisible
------------------------------------------------------------------------------}
procedure TCustomForm.SetVisible(Value : boolean);
begin
  if (Value=(fsVisible in FFormState)) and (Visible=Value) then exit;
  //DebugLn(['[TCustomForm.SetVisible] START ',Name,':',ClassName,' Old=',Visible,' New=',Value,' ',(fsCreating in FFormState)]);
  if Value then
    Include(FFormState, fsVisible)
  else
    Exclude(FFormState, fsVisible);
  //DebugLn(['TCustomForm.SetVisible ',Name,':',ClassName,' fsCreating=',fsCreating in FFormState]);
  if (fsCreating in FFormState) {or FormUpdating} then
    // will be done when finished loading
  else
  begin
    inherited SetVisible(Value);
    Application.UpdateVisible;
  end;
  //DebugLn(['[TCustomForm.SetVisible] END ',Name,':',ClassName,' ',Value,' ',(fsCreating in FFormState),' ',Visible]);
end;

procedure TCustomForm.AllAutoSized;
begin
  inherited AllAutoSized;
  { If the the form is about to show, calculate its metrics }
  if (not Showing) and Visible and ([csDestroying, csDesigning] * ComponentState = []) then
    MoveToDefaultPosition;
end;

procedure TCustomForm.AutoScale;
var
  MonPPI: Integer;
begin
  if not Scaled then
  begin
    Scaled := True; // will execute AutoScale
    Exit;
  end;
  MonPPI := Monitor.PixelsPerInch;
  if Application.Scaled and (MonPPI > 0) and (MonPPI <> PixelsPerInch) then
    AutoAdjustLayout(lapAutoAdjustForDPI, PixelsPerInch, MonPPI,
                     MulDiv(Width, MonPPI, PixelsPerInch),
                     MulDiv(Height, MonPPI, PixelsPerInch));
end;

{------------------------------------------------------------------------------
  procedure TCustomForm.SetWindowFocus;
 ------------------------------------------------------------------------------}
procedure TCustomForm.SetWindowFocus;
var
  NewFocusControl: TWinControl;
begin
  if [csLoading,csDestroying]*ComponentState<>[] then exit;
  if Assigned(FActiveControl) and not Assigned(FDesigner) then
    NewFocusControl := ActiveControl
  else
    NewFocusControl := Self;
  {$IFDEF VerboseFocus}
  DebugLn('TCustomForm.SetWindowFocus ',Name,':',Classname ,
    ' NewFocusControl=',NewFocusControl.Name,':',NewFocusControl.ClassName,
    ' HndAlloc=',dbgs(NewFocusControl.HandleAllocated));
  {$ENDIF}
  if not NewFocusControl.HandleAllocated or
     not NewFocusControl.CanFocus then
    exit;
  //DebugLn(['TCustomForm.SetWindowFocus ',DbgSName(Self),' NewFocusControl',DbgSName(NewFocusControl)]);
  LCLIntf.SetFocus(NewFocusControl.Handle);
  if GetFocus = NewFocusControl.Handle then
    NewFocusControl.Perform(CM_UIACTIVATE, 0, 0);
end;

{------------------------------------------------------------------------------
  Method: TCustomForm.WMShowWindow
  Params:   Msg: The showwindow message
  Returns:  nothing

  ShowWindow event handler.
 ------------------------------------------------------------------------------}
procedure TCustomForm.WMShowWindow(var message: TLMShowWindow);
begin
  {$IFDEF VerboseFocus}
  Debugln(['TCustomForm.WMShowWindow A ',DbgSName(Self),' fsShowing=',fsShowing in FFormState,' Msg.Show=',Message.Show,' FActiveControl=',DbgSName(FActiveControl)]);
  {$ENDIF}
  if (fsShowing in FFormState) then exit;
  Include(FFormState, fsShowing);
  try
    // only fire event if reason is not some other window hide/showing etc.
    if Message.Status = 0 then
    begin
      if Message.Show then
        DoShowWindow;
    end;
  finally
    Exclude(FFormState, fsShowing);
  end;
end;

{------------------------------------------------------------------------------
  Method: TCustomForm.WMActivate
  Params:   Msg: When the form is Activated
  Returns:  nothing

  Activate event handler.
 ------------------------------------------------------------------------------}
procedure TCustomForm.WMActivate(var Message: TLMActivate);
begin
  {$IFDEF VerboseFocus}
  DebugLn('TCustomForm.WMActivate A ',DbgSName(Self),' Msg.Active=',dbgs(Message.Active));
  {$ENDIF}
  if (Parent = nil) and (ParentWindow = 0) and
     (FormStyle <> fsMDIForm) or (csDesigning in ComponentState) then
    SetActive(Message.Active <> WA_INACTIVE);
  if Message.Active = WA_INACTIVE then
  begin
    if Assigned(Application) then
      Application.Deactivate(0);
  end
  else
  begin
    if Assigned(Application) then
      Application.Activate(0);
    // The button reappears in some situations (e.g. when the window gets the
    //"urgency" flag) so we hide it again here.
    // This is the most important place to invoke UpdateShowInTaskBar, since
    //invoking it anywhere else seeems basically useless/frequently reversed.
    if (ShowInTaskBar = stNever) or
       ( (ShowInTaskBar = stDefault) and
         Assigned(Application) and (Application.TaskBarBehavior = tbSingleButton)
       ) then
      UpdateShowInTaskBar;
  end;
end;

procedure TCustomForm.WMHelp(var Message: TLMHelp);
var
  Child: TWinControl;
  Context: THelpContext;
begin
  if (csDesigning in ComponentState) or not Assigned(Message.HelpInfo) then
    Exit;

{
  WriteLn('context type = ', Message.HelpInfo^.iContextType);
  WriteLn('control id   = ', Message.HelpInfo^.iCtrlId);
  WriteLn('item handle  = ', Message.HelpInfo^.hItemHandle);
  WriteLn('context id   = ', Message.HelpInfo^.dwContextId);
  WriteLn('MousePos     = ', dbgs(Message.HelpInfo^.MousePos));
}

  case Message.HelpInfo^.iContextType of
    HELPINFO_WINDOW:
      begin
        Child := FindControl(Message.HelpInfo^.hItemHandle);
        if Assigned(Child) then
          Child.ShowHelp;
      end;
    HELPINFO_MENUITEM:
      begin
        if Assigned(Menu) then
        begin
          Context := Menu.GetHelpContext(Message.HelpInfo^.iCtrlId, True);
          if Context = 0 then
            Context := Menu.GetHelpContext(Message.HelpInfo^.hItemHandle, False);
          if Context <> 0 then
            Application.HelpContext(Context);
        end;
      end;
  end;
end;

procedure TCustomForm.CMShowingChanged(var Message: TLMessage);
begin
  try
    if Showing then
      DoShow
    else
      DoHide;
  except
    if not HandleShowHideException then
      raise;
  end;
  inherited CMShowingChanged(Message);
end;

procedure TCustomForm.DoShowWindow;
begin
  if (ActiveControl = nil) and (not (csDesigning in ComponentState)) and (Parent = nil) then
  begin
    // automatically choose a control to focus
    {$IFDEF VerboseFocus}
    DebugLn('TCustomForm.DoShowWindow ',DbgSName(Self),' Set ActiveControl := ',DbgSName(FindDefaultForActiveControl));
    {$ENDIF}
    ActiveControl := FindDefaultForActiveControl;
  end;
end;

{------------------------------------------------------------------------------
  Method: TCustomForm.Activate
  Params: none
  Returns:  nothing

  Activation form methode event handler.
 ------------------------------------------------------------------------------}
procedure TCustomForm.Activate;
begin
  if FIsFirstOnActivate and (WindowState in [wsMaximized, wsFullScreen]) then
    Exit;
  FIsFirstOnActivate := False;
  if Assigned(FOnActivate) then FOnActivate(Self);
end;

{------------------------------------------------------------------------------
  procedure TCustomForm.ActiveChanged;
 ------------------------------------------------------------------------------}
procedure TCustomForm.ActiveChanged;
begin

end;

procedure TCustomForm.AdjustClientRect(var Rect: TRect);
begin
  InflateRect(Rect, -BorderWidth, -BorderWidth);
end;

{------------------------------------------------------------------------------
  Method: TCustomForm.Deactivate
  Params: none
  Returns: nothing

  Form deactivation (losing focus within application)  event handler.
 ------------------------------------------------------------------------------}
procedure TCustomForm.Deactivate;
begin
  if Assigned(FOnDeactivate) then FOnDeactivate(Self);
end;

{------------------------------------------------------------------------------
  Method: TCustomForm.WMSize
  Params:   Msg: The Size message
  Returns:  nothing

  Resize event handler.
 ------------------------------------------------------------------------------}
procedure TCustomForm.WMSize(var message: TLMSize);
var
  NewState: TWindowState;
begin
  {$IFDEF CHECK_POSITION}
  DebugLn(['[TCustomForm.WMSize] ',DbgSName(Self),' Message.SizeType=',Message.SizeType,' Message.Width=',Message.Width,' Message.Height=',Message.Height,' AutoSizeDelayed=',AutoSizeDelayed]);
  {$ENDIF}

  if (Parent = nil) and ((Message.SizeType and SIZE_SourceIsInterface) > 0) then
  begin
    // this is a top level form (constraints depend on window manager)
    // and the widgetset set a size
    if (Message.Width <> Width) or (Message.Height <> Height) then
    begin
      // the window manager sets another size => disable autosize to prevent endless loop
      Include(FFormState, fsDisableAutoSize);
    end;
  end;

  inherited WMSize(Message);
end;

procedure TCustomForm.DoOnResize;
begin
  if not (csDestroying in ComponentState) then
  begin
    FDelayedOnResize := True;
    Inc(FDelayedEventCtr);
    Application.QueueAsyncCall(@DelayedEvent, 0);
  end;
end;

procedure TCustomForm.DoOnChangeBounds;
begin
  if not (csDestroying in ComponentState) then
  begin
    FDelayedOnChangeBounds := True;
    Inc(FDelayedEventCtr);
    Application.QueueAsyncCall(@DelayedEvent, 0);
  end;
end;

procedure TCustomForm.DelayedEvent(Data: PtrInt);
begin
  { discard duplicate calls, accept last call only }
  Dec(FDelayedEventCtr);
  if FDelayedEventCtr > 0 then
    Exit;
  { update restored bounds }
  if WindowState = wsNormal then
  begin
    if FDelayedOnChangeBounds then
    begin
      FRestoredLeft := Left;
      FRestoredTop := Top;
    end;
    if FDelayedOnResize then
    begin
      FRestoredWidth := Width;
      FRestoredHeight := Height;
    end;
  end;
  { call onShow() or onActivate() for the first time,
    after first OnResize() and OnChangeBounds() }
  if FDelayedOnResize and FDelayedOnChangeBounds then
  begin
    if FIsFirstOnShow then
    begin
      FIsFirstOnShow := False;
      DoShow;
    end;
    if FIsFirstOnActivate then
    begin
      FIsFirstOnActivate := False;
      if FActive then
        Activate;
    end;
  end;
  { delayed onResize() }
  if FDelayedOnResize then
    inherited DoOnResize;
  { delayed onChangeBounds() }
  if FDelayedOnResize or FDelayedOnChangeBounds then
    inherited DoOnChangeBounds;
  FDelayedOnChangeBounds := False;
  FDelayedOnResize := False;
end;

procedure TCustomForm.WMWindowPosChanged(var Message: TLMWindowPosChanged);
begin
  if (Parent = nil) and Assigned(Message.WindowPos) and ((Message.WindowPos^.flags and SWP_SourceIsInterface)>0) then
  begin
    // this is a top level form (constraints depend on window manager)
    // and the widgetset set a size
    if (Message.WindowPos^.cx <> Width) or (Message.WindowPos^.cy <> Height) then
    begin
      // the window manager sets another size => disable autosize to prevent endless loop
      Include(FFormState,fsDisableAutoSize);
    end;
  end;

  inherited WMWindowPosChanged(Message);
end;

procedure TCustomForm.CMBiDiModeChanged(var Message: TLMessage);
var
  i: Integer;
  lMessage: TLMessage;
begin
  inherited CMBiDiModeChanged(Message);
  // send CM_PARENTBIDIMODECHANGED to all components owned by the form
  // this is needed for menus
  lMessage.msg := CM_PARENTBIDIMODECHANGED;
  lMessage.wParam := 0;
  lMessage.lParam := 0;
  lMessage.Result := 0;
  DisableAlign;
  try
    AdjustSize;
    for i := 0 to ComponentCount - 1 do
    begin
      // all TControl descendants have this notification in TWinControl.CMBidiModeChanged
      if Components[i] is TControl then
        Continue;
      Components[i].Dispatch(lMessage);
    end;
  finally
    EnableAlign;
  end;
end;

procedure TCustomForm.CMParentBiDiModeChanged(var Message: TLMessage);
begin
  if csLoading in ComponentState then
    Exit;

  if ParentBidiMode then
  begin
    if Parent <> nil then
      BidiMode := Parent.BidiMode
    else
      BidiMode := Application.BidiMode;
    ParentBidiMode := True;
  end;
end;

procedure TCustomForm.CMAppShowBtnGlyphChanged(var Message: TLMessage);
begin
  NotifyControls(Message.msg);
end;

procedure TCustomForm.CMAppShowMenuGlyphChanged(var Message: TLMessage);
var
  i: integer;
begin
  for i := 0 to ComponentCount - 1 do
    Components[i].Dispatch(Message);
end;

procedure TCustomForm.CMIconChanged(var Message: TLMessage);
begin
  IconChanged(Self);
end;

procedure TCustomForm.CMRelease(var Message: TLMessage);
begin
  Free;
end;

procedure TCustomForm.CMActivate(var Message: TLMessage);
begin
  if not(csDesigning in ComponentState) and (FormStyle=fsMDIChild) and Assigned(Menu)
  and Assigned(Application.MainForm) and (Application.MainForm.FormStyle=fsMDIForm) and Assigned(Application.MainForm.Menu)
  then
    Application.MainForm.Menu.Merge(Menu);
  Activate;
end;

procedure TCustomForm.CMDeactivate(var Message: TLMessage);
begin
  Deactivate;
  if not(csDesigning in ComponentState) and (FormStyle=fsMDIChild) and Assigned(Menu)
  and Assigned(Application.MainForm) and (Application.MainForm.FormStyle=fsMDIForm) and Assigned(Application.MainForm.Menu)
  then
    Application.MainForm.Menu.Unmerge(Menu);
end;

procedure TCustomForm.AddHandler(HandlerType: TFormHandlerType;
  const Handler: TMethod; AsFirst: Boolean);
begin
  if Handler.Code=nil then RaiseGDBException('TCustomForm.AddHandler');
  if FFormHandlers[HandlerType]=nil then
    FFormHandlers[HandlerType]:=TMethodList.Create;
  FFormHandlers[HandlerType].Add(Handler,not AsFirst);
end;

procedure TCustomForm.RemoveHandler(HandlerType: TFormHandlerType;
  const Handler: TMethod);
begin
  FFormHandlers[HandlerType].Remove(Handler);
end;

function TCustomForm.FindDefaultForActiveControl: TWinControl;
begin
  Result:=FindNextControl(nil, True, True, False)
end;

procedure TCustomForm.UpdateMenu;
begin
  if HandleAllocated and (FMenu <> nil) then
  begin
    // don't show a main menu for the dialog forms (delphi compatible)
    if (BorderStyle <> bsDialog) or (csDesigning in ComponentState) then
      FMenu.HandleNeeded
    else
      FMenu.DestroyHandle;
    FMenu.WindowHandle := Handle;
  end;
end;

function TCustomForm.GetEffectiveShowInTaskBar: TShowInTaskBar;
begin
  Result := ShowInTaskBar;
  if (Result = stDefault) or (csDesigning in ComponentState) then
    case Application.TaskBarBehavior of
      tbSingleButton: Result := stNever;
      tbMultiButton: Result := stAlways;
      tbDefault: Result := stDefault;
    end;
end;

procedure TCustomForm.UpdateShowInTaskBar;
begin
  if (Assigned(Application) and (Application.MainForm = Self)) or
     (not HandleAllocated) or Assigned(Parent) or
     (FormStyle = fsMDIChild) or not Showing then Exit;
  TWSCustomFormClass(WidgetSetClass).SetShowInTaskbar(Self, GetEffectiveShowInTaskBar);
end;

class procedure TCustomForm.WSRegisterClass;
begin
  inherited WSRegisterClass;
  RegisterCustomForm;
end;

{------------------------------------------------------------------------------
  Method: TCustomForm.DefocusControl
  Params:   Control: the control which is to be defocused
            Removing: is it to be defocused because it is being removed
            (destructed or changed parent).
  Returns:  nothing

  Updates ActiveControl if it is to be defocused
 ------------------------------------------------------------------------------}
procedure TCustomForm.DefocusControl(Control: TWinControl; Removing: Boolean);
begin
  if Control.ContainsControl(ActiveControl) then
  begin
    {$IFDEF VerboseFocus}
    debugln('TCustomForm.DefocusControl Control=',DbgSName(Control),' FActiveControl=',DbgSName(FActiveControl));
    {$ENDIF}
    ActiveControl := nil;
  end;
end;

{------------------------------------------------------------------------------
  Method: TCustomForm.DoCreate
  Params:   none
  Returns:  nothing

  Calls user handler
 ------------------------------------------------------------------------------}
procedure TCustomForm.DoCreate;
begin
  try
    LockRealizeBounds;
    if Assigned(FOnCreate) then FOnCreate(Self);
    FFormHandlers[fhtCreate].CallNotifyEvents(Self);
    UnlockRealizeBounds;
  except
    if not HandleCreateException then
      raise
  end;
end;

{------------------------------------------------------------------------------
  Method: TCustomForm.DoClose
  Params:   none
  Returns:  nothing

  Calls user handler
 ------------------------------------------------------------------------------}
procedure TCustomForm.DoClose(var CloseAction: TCloseAction);
var
  i: LongInt;
begin
  if Assigned(FOnClose) then FOnClose(Self, CloseAction);
  i:=FFormHandlers[fhtClose].Count;
  while FFormHandlers[fhtClose].NextDownIndex(i) do
    TCloseEvent(FFormHandlers[fhtClose][i])(Self,CloseAction);
  //DebugLn('TCustomForm.DoClose ',DbgSName(Self),' ',dbgs(ord(CloseAction)));
end;

{------------------------------------------------------------------------------
  Method: TCustomForm.DoDestroy
  Params:   none
  Returns:  nothing

  Calls user handler
 ------------------------------------------------------------------------------}
procedure TCustomForm.DoDestroy;
begin
  try
    if Assigned(FOnDestroy) then FOnDestroy(Self);
  except
    if not HandleDestroyException then
      raise;
  end;
end;

{------------------------------------------------------------------------------
  procedure TCustomForm.SetActive(AValue: Boolean);
 ------------------------------------------------------------------------------}
procedure TCustomForm.SetActive(AValue: Boolean);
begin
  FActive := AValue;
  if FActive then
  begin
    if (ActiveControl = nil) and (not (csDesigning in ComponentState))
      and Application.MoveFormFocusToChildren then
      ActiveControl := FindDefaultForActiveControl;
    SetWindowFocus;
  end;
end;

{------------------------------------------------------------------------------
  Method: TCustomForm.DoHide
  Params:   none
  Returns:  nothing

  Calls user handler
 ------------------------------------------------------------------------------}
procedure TCustomForm.DoHide;
begin
  if Assigned(FOnHide) then FOnHide(Self);
end;

{------------------------------------------------------------------------------
  Method: TCustomForm.DoShow
  Params:   none
  Returns:  nothing

  Calls user handler
 ------------------------------------------------------------------------------}
procedure TCustomForm.DoShow;
begin
  if FIsFirstOnShow and (WindowState in [wsMaximized, wsFullScreen]) then
    Exit;
  FIsFirstOnShow := False;
  if Assigned(FOnShow) then FOnShow(Self);
end;

{------------------------------------------------------------------------------
  procedure TCustomForm.EndFormUpdate;
 ------------------------------------------------------------------------------}
procedure TCustomForm.EndFormUpdate;
begin
  dec(FFormUpdateCount);
  if FFormUpdateCount = 0 then
  begin
    FormEndUpdated;
    Visible := (fsVisible in FFormState);
    EnableAutoSizing{$IFDEF DebugDisableAutoSizing}('TCustomForm.BeginFormUpdate'){$ENDIF};
  end;
end;

procedure TCustomForm.EnsureVisible(AMoveToTop: Boolean = True);
begin
  MakeFullyVisible(nil, True);
  if AMoveToTop then
    ShowOnTop
  else
    Visible := True;
end;

{------------------------------------------------------------------------------
  function TCustomForm.FormIsUpdating: boolean;
 ------------------------------------------------------------------------------}
function TCustomForm.FormIsUpdating: boolean;
begin
  Result:=FFormUpdateCount>0;
end;

{------------------------------------------------------------------------------
  Method: TCustomForm.GetChildren
  Params:   Proc - see fcl/inc/writer.inc
            Root
  Returns:  nothing

  Adds component to children list which have no parent.
    (TWinControl only lists components with parents)
 ------------------------------------------------------------------------------}
procedure TCustomForm.GetChildren(Proc: TGetChildProc; Root: TComponent);
var
  I: Integer;
  OwnedComponent: TComponent;
begin
  inherited GetChildren(Proc, Root);
  if Root = Self then
    for I := 0 to ComponentCount - 1 do begin
      OwnedComponent := Components[I];
      if OwnedComponent.HasParent = False
        then Proc(OwnedComponent);
    end;
end;

function TCustomForm.HandleCreateException: Boolean;
begin
  Result := Application.CaptureExceptions;
  if Result then
    Application.HandleException(Self);
end;

function TCustomForm.HandleDestroyException: Boolean;
begin
  Result := Application.CaptureExceptions;
  if Result then
    Application.HandleException(Self);
end;

function TCustomForm.HandleShowHideException: Boolean;
begin
  Result := Application.CaptureExceptions;
  if Result then
    Application.HandleException(Self);
end;

procedure TCustomForm.InitializeWnd;
begin
  if not (csDesigning in ComponentState) then
  begin
    // set alpha value
    TWSCustomFormClass(WidgetSetClass).SetAlphaBlend(Self, AlphaBlend, AlphaBlendValue);
    // set allow drop files
    TWSCustomFormClass(WidgetSetClass).SetAllowDropFiles(Self, FAllowDropFiles);
  end;
  inherited InitializeWnd;
end;

{------------------------------------------------------------------------------
  Method: TCustomForm.PaintWindow
  Params:   none
  Returns:  nothing

  Calls user handler
 ------------------------------------------------------------------------------}
procedure TCustomForm.PaintWindow(dc: Hdc);
begin
  // Canvas.Lock;
  try
    Canvas.Handle := DC;
    //DebugLn('[TCustomForm.PaintWindow] ',ClassName,' DC=',DbgS(DC,8),'  ',DbgS(FCanvas.Handle,8));
    try
      Paint;
      if FDesigner <> nil then FDesigner.PaintGrid;
    finally
      Canvas.Handle := 0;
    end;
  finally
    // Canvas.Unlock;
  end;
end;


{------------------------------------------------------------------------------
  Method: TCustomForm.RequestAlign
  Params:   none
  Returns:  nothing

  Calls user handler
 ------------------------------------------------------------------------------}
procedure TCustomForm.RequestAlign;
Begin
  if Parent = nil then begin
    //Screen.AlignForm(Self);
  end
  else
  inherited RequestAlign;
end;

procedure TCustomForm.Resizing(State: TWindowState);
var
  OldState: TWindowState;
begin
  if Showing and not (csDesigning in ComponentState) then
  begin
    OldState := FWindowState;
    FWindowState := State;
    if OldState <> State then
    begin
      if (State = wsMinimized) and (Application.MainForm = Self) and
         (WidgetSet.GetLCLCapability(lcNeedMininimizeAppWithMainForm) <> LCL_CAPABILITY_NO) then
        Application.Minimize;
      if (OldState = wsMinimized) and (Application.MainForm = Self) and
         (WidgetSet.GetLCLCapability(lcNeedMininimizeAppWithMainForm) <> LCL_CAPABILITY_NO) then
        Application.Restore;
      if Assigned(OnWindowStateChange) then
        OnWindowStateChange(Self);
    end;
  end;
end;

procedure TCustomForm.CalculatePreferredSize(var PreferredWidth,
  PreferredHeight: integer; WithThemeSpace: Boolean);
var
  WorkArea: TRect;
begin
  inherited CalculatePreferredSize(PreferredWidth, PreferredHeight,
    WithThemeSpace);
  if (Parent = nil) and (Anchors * [akRight, akBottom] <> []) then
  begin
    // do size bigger than the monitor workarea
    WorkArea := Monitor.WorkareaRect;
    if akRight in Anchors then
      PreferredWidth := min(PreferredWidth, WorkArea.Right - WorkArea.Left);
    if akBottom in Anchors then
      PreferredHeight := min(PreferredHeight, WorkArea.Bottom - WorkArea.Top);
  end;
end;

{------------------------------------------------------------------------------
  procedure TCustomForm.SetZOrder(Topmost: Boolean);
------------------------------------------------------------------------------}
procedure TCustomForm.SetZOrder(Topmost: Boolean);
begin
  if Parent = nil then
  begin
    if TopMost and HandleAllocated then
    begin
      if (Screen.GetCurrentModalForm <> nil) and (Screen.GetCurrentModalForm <> Self) then
        Exit;
      //TODO: call TWSCustomFormClass(Widgetset).SetZORder.
      Screen.MoveFormToZFront(Self);
      SetForegroundWindow(Handle);
    end;
  end
  else
    inherited SetZOrder(Topmost);
end;

procedure TCustomForm.SetParent(NewParent: TWinControl);
var
  ParentForm: TCustomForm;
begin
  if Parent = NewParent then exit;
  DisableAutoSizing{$IFDEF DebugDisableAutoSizing}('TCustomForm.SetParent'){$ENDIF};
  try
    if HandleAllocated then DestroyHandle;
    inherited SetParent(NewParent);
    if (Parent = nil) and Visible then
      HandleNeeded;

    if Parent <> nil then
    begin
      ParentForm := GetParentForm(Self);
      if Application.Scaled and (ParentForm<>nil) and ParentForm.Scaled
      and (ParentForm.PixelsPerInch<>PixelsPerInch) then
        AutoAdjustLayout(lapAutoAdjustForDPI, PixelsPerInch, ParentForm.PixelsPerInch, 0, 0);
    end;
  finally
    EnableAutoSizing{$IFDEF DebugDisableAutoSizing}('TCustomForm.SetParent'){$ENDIF};
  end;
end;

procedure TCustomForm.MoveToDefaultPosition;
var
  RealWidth, RealHeight: Integer;

  procedure MoveToDefaultMonitor(var X, Y: Integer);
  var
    Source, Target: TMonitor;
    ABounds: TRect;
  begin
    // delphi compatibility: if no main form then DefaultMonitor has no effect
    if Application.MainForm = nil then Exit;
    // find the monitor of the center of the form (the boundaries might be on another monitor)
    Source := Screen.MonitorFromRect(Rect(X,Y,X+RealWidth,Y+RealHeight));
    case DefaultMonitor of
      dmDesktop:
        Target := Source; // no need to move
      dmPrimary:
        Target := Screen.PrimaryMonitor;
      dmMainForm:
        Target := Application.MainForm.Monitor;
      dmActiveForm:
        if Screen.ActiveCustomForm <> nil then
          Target := Screen.ActiveCustomForm.Monitor
        else
          Target := Source;
    end;
    if Source = Target then Exit; // no move

    if Position in [poMainFormCenter, poOwnerFormCenter] then
    begin
      ABounds := Target.BoundsRect;
      // shift X and Y from Source to Target monitor
      X := (X - Source.Left) + ABounds.Left;
      Y := (Y - Source.Top) + ABounds.Top;

      // check that we are still in the desired monitor
      if X + RealWidth > ABounds.Right then
        X := ABounds.Right - RealWidth;
      if X < ABounds.Left then
        X := ABounds.Left;

      if Y + RealHeight > ABounds.Bottom then
        Y := ABounds.Bottom - RealHeight;
      if Y < ABounds.Top then
        Y := ABounds.Top;
    end
    else // poWorkAreaCenter, poScreenCenter
    begin
      if Position = poWorkAreaCenter then
        ABounds := Target.WorkareaRect
      else
        ABounds := Target.BoundsRect;
      X := (ABounds.Left + ABounds.Right - RealWidth) div 2;
      Y := (ABounds.Top + ABounds.Bottom - RealHeight) div 2;
    end;
  end;

var
  X, Y: integer;
  p: TPosition;
  AForm: TCustomForm;
  RealRect, AFormRealRect: TRect;
  AFormRealWidth, AFormRealHeight: Integer;
begin
  if (Parent <> nil) or (ParentWindow <> 0) then exit;

  if not (WindowState in [wsNormal,wsMinimized]) then exit;

  // first make sure X and Y are assigned
  X := Left;
  Y := Top;
  if HandleAllocated and (GetWindowRect(Handle, RealRect) <> 0) then
  begin // success
    RealWidth := RealRect.Right-RealRect.Left;
    RealHeight := RealRect.Bottom-RealRect.Top;
  end else
  begin // error
    RealWidth := Width;
    RealHeight := Height;
  end;

  p := Position;
  if (Position = poMainFormCenter) and (Application.Mainform=nil) then
    p := poScreenCenter;
  case P of
    poDesktopCenter:
      begin
        X := Screen.DesktopLeft + (Screen.DesktopWidth - RealWidth) div 2;
        Y := Screen.DesktopTop +(Screen.DesktopHeight - RealHeight) div 2;
      end;
    poScreenCenter:
      begin
        X := (Screen.Width - RealWidth) div 2;
        Y := (Screen.Height - RealHeight) div 2;
      end;
    poWorkAreaCenter:
      begin
        X := Screen.WorkAreaLeft + (Screen.WorkAreaWidth - RealWidth) div 2;
        Y := Screen.WorkAreaTop + (Screen.WorkAreaHeight - RealHeight) div 2;
      end;
    poMainFormCenter,
    poOwnerFormCenter:
      begin
        if (P = poOwnerFormCenter) and (Owner is TCustomForm) then
          AForm := TCustomForm(Owner)
        else
          AForm := Application.MainForm;
        if (Self <> AForm) and Assigned(AForm) then
        begin
          if FormStyle = fsMDIChild then
          begin
            X := (AForm.ClientWidth - RealWidth) div 2;
            Y := (AForm.ClientHeight - RealHeight) div 2;
          end else
          begin
            if AForm.HandleAllocated and (GetWindowRect(AForm.Handle, AFormRealRect) <> 0) then
            begin // success
              AFormRealWidth := AFormRealRect.Right-AFormRealRect.Left;
              AFormRealHeight := AFormRealRect.Bottom-AFormRealRect.Top;
            end else
            begin // error
              AFormRealWidth := AForm.Width;
              AFormRealHeight := AForm.Height;
            end;
            X := ((AFormRealWidth - RealWidth) div 2) + AForm.Left;
            Y := ((AFormRealHeight - RealHeight) div 2) + AForm.Top;
          end;
        end;
      end;
  end;
  // get current widgetset position
  if (p in [poDefault, poDefaultPosOnly]) and HandleAllocated then
    GetWindowRelativePosition(Handle,X,Y);
  if (Position in [poScreenCenter, poMainFormCenter, poOwnerFormCenter, poWorkAreaCenter]) then
    MoveToDefaultMonitor(X, Y);
  SetBounds(X, Y, Width, Height);
end;

{------------------------------------------------------------------------------
  procedure TCustomForm.VisibleChanging;
------------------------------------------------------------------------------}
procedure TCustomForm.VisibleChanging;
begin
  //if (FormStyle = fsMDIChild) and Visible then
  //  raise EInvalidOperation.Create(SMDIChildNotVisible);
  inherited VisibleChanging;
end;

procedure TCustomForm.VisibleChanged;
begin
  inherited VisibleChanged;
  if (Screen<>nil) then
    Screen.NotifyScreenFormHandler(snFormVisibleChanged,Self);
end;

{------------------------------------------------------------------------------
       TCustomForm WndProc
------------------------------------------------------------------------------}
procedure TCustomForm.WndProc(var TheMessage : TLMessage);
var
  NewActiveControl: TWinControl;
  NewFocus: HWND;
  MenuItem: TMenuItem;
begin
  //debugln(['TCustomForm.WndProc ',dbgsname(Self)]);
  with TheMessage do
  case Msg of
    LM_SETFOCUS:
      if not (csDesigning in ComponentState) then
      begin
        //DebugLn(['TCustomForm.WndProc ',DbgSName(Self),'Msg = LM_SETFOCUS FActiveControl=',DbgSName(FActiveControl)]);
        NewActiveControl := nil;
        NewFocus := 0;

        if (ActiveControl = nil) and not (csDesigning in ComponentState) then
        begin
          // automatically choose a control to focus
          {$IFDEF VerboseFocus}
          DebugLn('TCustomForm.WndProc ',DbgSName(Self),' Set ActiveControl := ',DbgSName(FindDefaultForActiveControl));
          {$ENDIF}
          NewActiveControl := FindDefaultForActiveControl;
        end
        else
          NewActiveControl := ActiveControl;

        if FormStyle = fsMDIFORM then
        begin
          Exit;
        end
        else
        begin
          if (NewActiveControl <> nil) and (NewActiveControl <> Self) and
             NewActiveControl.IsVisible and NewActiveControl.Enabled and
             ([csLoading,csDestroying]*NewActiveControl.ComponentState=[]) and
             not NewActiveControl.ParentDestroyingHandle then
          begin
            // get or create handle of FActiveControl
            NewFocus := NewActiveControl.Handle;
            //debugln('TCustomForm.WndProc A ',DbgSName(Self),' FActiveControl=',DbgSName(FActiveControl),' FocusHandle=',dbgs(FocusHandle));
          end;
        end;

        TheMessage.Result := 0;
        if NewFocus <> 0 then
        begin
          // redirect focus to child
          {$IFDEF VerboseFocus}
          DebugLn('[TCustomForm.WndProc] ',Name,':',ClassName,' FActiveControl=',DbgSName(FActiveControl));
          {$ENDIF}
          LCLIntf.SetFocus(NewFocus);
          Exit;
        end;
      end;
    CM_EXIT:
      begin
        if HostDockSite <> nil then DeActivate;
      end;
    CM_ENTER:
      begin
        if HostDockSite <> nil then Activate;
      end;
    LM_WINDOWPOSCHANGING:
      if (not (csDesigning in ComponentState)) and (fsFirstShow in FFormState) then
      begin
        if (Position in [poDefault, poDefaultPosOnly]) and (WindowState <> wsMaximized) then
          with PWindowPos(TheMessage.lParam)^ do
            flags := flags or SWP_NOMOVE;

        if (Position in [poDefault, poDefaultSizeOnly]) and (BorderStyle in [bsSizeable, bsSizeToolWin]) then
          with PWindowPos(TheMessage.lParam)^ do
            flags := flags or SWP_NOSIZE;
      end;
    LM_DRAWITEM:
      with PDrawItemStruct(TheMessage.LParam)^ do
      begin
        if (CtlType = ODT_MENU) and Assigned(Menu) then
        begin
          MenuItem := Menu.FindItem(itemID, fkCommand);
          if Assigned(MenuItem) then
            Exit;
        end;
      end;
    end;
  inherited WndProc(TheMessage);
end;

function TCustomForm.VisibleIsStored: boolean;
begin
  Result := Visible;
end;

function TCustomForm.ColorIsStored: boolean;
begin
  Result := (Color <> {$ifdef UseCLDefault}clDefault{$else}clBtnFace{$endif});
end;

procedure TCustomForm.GetPreferredSize(var PreferredWidth,
  PreferredHeight: integer; Raw: boolean; WithThemeSpace: boolean);
begin
  if (fsDisableAutoSize in FFormState) and not Raw then begin
    PreferredWidth:=Width;
    PreferredHeight:=Height;
  end else begin
    inherited GetPreferredSize(PreferredWidth, PreferredHeight, Raw,
      WithThemeSpace);
  end;
end;

function TCustomForm.GetRealPopupParent: TCustomForm;
begin
  Result := nil;
  if (fsModal in FormState) or // always set WndParent of modal windows
     (PopupMode in [pmAuto, pmExplicit]) // set WndParent of non-modal windows only for pmAuto, pmExplicit
  then
  begin
    if (PopupMode = pmAuto)
    or ((PopupMode = pmNone) and (fsModal in FormState)) then
    begin
      Result := Screen.ActiveForm;
      if (Result<>nil) and (Result.FormStyle = fsSplash) then // ignore fsSplash
        Result := nil;
    end else
    if (PopupMode = pmExplicit) then
      Result := PopupParent;

    if (Result = nil) or not Result.HandleAllocated then
      Result := Application.MainForm;
  end;
  if (Result <> nil) and not Result.HandleAllocated then
    Result := nil;
  if (Result = Self) then
    Result := nil;
end;

procedure TCustomForm.DoAutoSize;
begin
  //DebugLn(['TCustomForm.DoAutoSize ',DbgSName(Self),' ',WindowState=wsNormal,' ',fsDisableAutoSize in FFormState,' ',dbgs(BoundsRect),' ',dbgs(ClientRect)]);
  inherited DoAutoSize;
end;

procedure TCustomForm.SetAutoSize(Value: Boolean);
begin
  if Value = AutoSize then Exit;
  if Value then
  begin
    Exclude(FFormState, fsDisableAutoSize);
    if Position=poDefaultPosOnly then
      FPosition:=poDefault;
  end;
  inherited SetAutoSize(Value);
end;

procedure TCustomForm.SetAutoScroll(Value: Boolean);
begin
  inherited SetAutoScroll(Value and (BorderStyle in BorderStylesAllowAutoScroll));
end;

procedure TCustomForm.DoAddActionList(List: TCustomActionList);
begin
  if FActionLists=nil then
    FActionLists:=TList.Create;
  if FActionLists.IndexOf(List)<0 then begin
    FActionLists.Add(List);
    List.FreeNotification(Self);
  end;
end;

procedure TCustomForm.DoRemoveActionList(List: TCustomActionList);
begin
  if FActionLists<>nil then
    FActionLists.Remove(List);
end;

procedure TCustomForm.BeginAutoDrag;
begin
  // allow form dragging only if it is docked into a site without DockManager
  if (HostDockSite <> nil) and not HostDockSite.UseDockManager then
    BeginDrag(False);
end;

class function TCustomForm.GetControlClassDefaultSize: TSize;
begin
  Result.CX := 320;
  Result.CY := 240;
end;

procedure TCustomForm.DoDock(NewDockSite: TWinControl; var ARect: TRect);
//Save or restore the borderstyle
begin
  if (NewDockSite <> HostDockSite) and ((NewDockSite = nil) or (HostDockSite=nil)) then
  begin
    if NewDockSite = nil then begin
      //Restore the form borderstyle
      BorderStyle := FOldBorderStyle;
      // Note: changing the Align property must be done by the dock manager, not by default
    end else begin
      //Save the borderstyle & set new bordertype
      FOldBorderStyle := BorderStyle;
      BorderStyle := bsNone;
      // Note: changing the Align property must be done by the dock manager, not by default
    end;
  end;
  inherited DoDock(NewDockSite, ARect);
end;

function TCustomForm.GetFloating: Boolean;
begin
  Result := ((HostDockSite = nil) and (Parent=nil)
            and (FloatingDockSiteClass = ClassType))
         or (inherited GetFloating);
end;

function TCustomForm.GetDefaultDockCaption: String;
begin
  Result := Caption;
end;

procedure TCustomForm.CMActionExecute(var Message: TLMessage);
begin
  if DoExecuteAction(TBasicAction(Message.LParam)) then
    Message.Result := 1;
end;

procedure TCustomForm.CMActionUpdate(var Message: TLMessage);
begin
  if DoUpdateAction(TBasicAction(Message.LParam)) then
    Message.Result := 1;
end;

function TCustomForm.DoExecuteAction(ExeAction: TBasicAction): boolean;
  function DoExecuteActionInChildControls(ParentControl: TWinControl;
    AnAction: TBasicAction) : boolean;
  var
    i: integer;
    ChildComponent: TComponent;
  begin
    Result := True;
    for i := 0 to ParentControl.ComponentCount - 1 do
    begin
      ChildComponent := ParentControl.Components[i];
      if not (ChildComponent is TControl) or TControl(ChildComponent).Visible then
      begin
        if ChildComponent.ExecuteAction(AnAction) then Exit;
        if (ChildComponent is TWinControl) and
           DoExecuteActionInChildControls(TWinControl(ChildComponent), AnAction) then Exit;
      end;
    end;
    Result := False;
  end;
  
begin
  // don't execute action while designing or when form is not visible
  if (csDesigning in ComponentState) or not Visible then
    Exit(False);

  // assume it gets handled somewhere
  Result := True;
  if Assigned(ActiveControl) and ActiveControl.ExecuteAction(ExeAction) then Exit;
    
  if ExecuteAction(ExeAction) then Exit;
    
  if DoExecuteActionInChildControls(Self, ExeAction) then Exit;

  // not handled anywhere, return false
  Result := False;
end;

function TCustomForm.DoUpdateAction(TheAction: TBasicAction): boolean;

  function ProcessUpdate(Component: TComponent): Boolean;
  begin
    Result := (Component <> nil) and
      Component.UpdateAction(TheAction);
  end;

  function ComponentAllowed(Component: TComponent): Boolean;
  begin
    result := not (Component is TControl) or TControl(Component).Visible;
  end;

  function TraverseClients(Container: TWinControl): Boolean;
  var
    I: Integer;
    Component: TComponent;
  begin
    if Container.Showing then
      for I := 0 to Container.ComponentCount - 1 do
      begin
        Component := Container.Components[I];
        if ComponentAllowed(Component) and ProcessUpdate(Component)
        or (Component is TWinControl) and TraverseClients(TWinControl(Component))
        then begin
          Result := True;
          exit;
        end;
      end;
    Result := False;
  end;

begin
  Result := False;
  if (csDesigning in ComponentState) or not Showing then Exit;
  // Find a target for given Command (Message.LParam).
  if ProcessUpdate(ActiveControl) or
     ProcessUpdate(Self) or
     TraverseClients(Self) then
    Result := True;
end;

procedure TCustomForm.UpdateActions;

  procedure RecursiveInitiate(Container: TWinControl);
  var
    i: Integer;
    CurControl: TControl;
  begin
    if not Container.Showing or (csDesigning in Container.ComponentState) then exit;
    //DebugLn(['RecursiveInitiate ',DbgSName(Container)]);
    for i := 0 to Container.ControlCount - 1 do begin
      CurControl := Container.Controls[i];
      if (csActionClient in CurControl.ControlStyle)
      and CurControl.Visible then
        CurControl.InitiateAction;
      if CurControl is TWinControl then
        RecursiveInitiate(TWinControl(CurControl));
    end;
  end;

var
  I: Integer;
begin
  if (csDesigning in ComponentState) or (not Showing) then exit;
  {$IFDEF DebugDisableAutoSizing}WriteAutoSizeReasons(true);{$ENDIF}
  // update this form
  InitiateAction;
  // update main menu's top-most items
  if Menu <> nil then
    for I := 0 to Menu.Items.Count - 1 do
      with Menu.Items[I] do begin
        //DebugLn(['TCustomForm.UpdateActions ',Name,' Visible=',Visible]);
        if Visible then InitiateAction;
      end;
  // update all controls
  RecursiveInitiate(Self);
end;

{------------------------------------------------------------------------------
       TCustomForm SetMenu
------------------------------------------------------------------------------}
procedure TCustomForm.SetMenu(Value: TMainMenu);
var
  I: Integer;
begin
  if FMenu = Value then Exit;

  // check duplicate menus
  if Value <> nil then
    for I := 0 to Screen.FormCount - 1 do
      if (Screen.Forms[I].Menu = Value) and (Screen.Forms[I] <> Self) then
        raise EInvalidOperation.CreateFmt(sDuplicateMenus, [Value.Name]);

  if (FMenu <> nil) and not (csDestroying in FMenu.ComponentState) then
  begin
    FMenu.DestroyHandle;
    FMenu.Parent := nil;
  end;

  if (csDestroying in ComponentState) or
     ((Value <> nil) and (csDestroying in Value.ComponentState)) then
    Value := nil;

  FMenu := Value;
  if FMenu <> nil then 
  begin
    FMenu.FreeNotification(Self);
    FMenu.Parent := Self;
    UpdateMenu;
  end;
end;

procedure TCustomForm.SetModalResult(Value: TModalResult);
begin
  if HandleAllocated and (Value <> FModalResult) then
    TWSCustomFormClass(WidgetSetClass).SetModalResult(Self, Value);
  FModalResult := Value;
end;

{------------------------------------------------------------------------------
       TCustomForm SetBorderIcons
------------------------------------------------------------------------------}
procedure TCustomForm.SetBorderIcons(NewIcons: TBorderIcons);
begin
  if FBorderIcons = NewIcons then exit;
  FBorderIcons := NewIcons;
  if HandleAllocated then
    TWSCustomFormClass(WidgetSetClass).SetBorderIcons(Self, NewIcons);
end;

{------------------------------------------------------------------------------
       TCustomForm SetFormBorderStyle
------------------------------------------------------------------------------}
procedure TCustomForm.SetFormBorderStyle(NewStyle: TFormBorderStyle);
var
  AdaptBorderIcons: boolean;
begin
  if FFormBorderStyle = NewStyle then exit;

  // AutoScroll is only available for bsSizeable, bsSizeToolWin windows
  if not (NewStyle in BorderStylesAllowAutoScroll) then
    AutoScroll := False;

  AdaptBorderIcons := not (csLoading in ComponentState) and
                      (BorderIcons = DefaultBorderIcons[FFormBorderStyle]);
  FFormBorderStyle := NewStyle;
  
  if not (csDesigning in ComponentState) then
  begin
    // if Form had default border icons before change, it should keep the default
    if AdaptBorderIcons then
      BorderIcons := DefaultBorderIcons[FFormBorderStyle];

    Include(FFormState, fsBorderStyleChanged);
    // ToDo: implement it.
    // We can not use inherited SetBorderStyle(NewStyle),
    // because TBorderStyle <> TFormBorderStyle;
    if HandleAllocated then
    begin
      TWSCustomFormClass(WidgetSetClass).SetFormBorderStyle(Self, NewStyle);
      Perform(CM_ICONCHANGED, 0, 0);
      UpdateMenu;
    end;
  end;
end;

{------------------------------------------------------------------------------
       TCustomForm UpdateWindowState
------------------------------------------------------------------------------}
procedure TCustomForm.UpdateWindowState;
Begin

  //TODO: Finish UpdateWindowState
  //DebugLn('Trace:TODO: [TCustomForm.UpdateWindowState]');
end;

{------------------------------------------------------------------------------
       TCustomForm SetWindowState
------------------------------------------------------------------------------}
procedure TCustomForm.SetWindowState(Value : TWindowState);
begin
  if FWindowState <> Value then
  begin
    FWindowState := Value;
    //DebugLn(['TCustomForm.SetWindowState ',DbgSName(Self),' ',ord(FWindowState),' csDesigning=',csDesigning in ComponentState,' Showing=',Showing]);
    if (not (csDesigning in ComponentState)) and Showing then
      ShowWindow(Handle, ShowCommands[Value]);
  end;
end;

procedure TCustomForm.SetRestoredBounds(ALeft, ATop, AWidth, AHeight: integer;
  const ADefaultPosition: Boolean);
var
  prevWindowState: TWindowState;
begin
  // temporarily go to normal window state to store restored bounds
  if (FRestoredLeft=ALeft) and (FRestoredTop=ATop)
  and (FRestoredWidth=AWidth) and (FRestoredHeight=AHeight) then exit;
  prevWindowState := WindowState;
  WindowState := wsNormal;
  SetBounds(ALeft, ATop, AWidth, AHeight);
  // override
  if ADefaultPosition then
    MoveToDefaultPosition;
  WindowState := prevWindowState;
  FRestoredLeft := Left;
  FRestoredTop := Top;
  FRestoredWidth := Width;
  FRestoredHeight := Height;
end;

procedure TCustomForm.SetScaled(const AScaled: Boolean);
var
  OldScaled: Boolean;
begin
  if Scaled=AScaled then
    Exit;

  OldScaled := Scaled;
  inherited SetScaled(AScaled);
  if not OldScaled and Scaled
  and (ComponentState * [csDesigning, csLoading] = []) then // not in designtime and not when loading
    AutoScale;
end;

{------------------------------------------------------------------------------
       TCustomForm SetActiveControl
------------------------------------------------------------------------------}
procedure TCustomForm.SetActiveControl(AWinControl: TWinControl);
begin
  if FActiveControl = AWinControl then exit;
  if Assigned(AWinControl) and IsVisible then
  begin
    // this form can focus => do some sanity checks and raise an exception to
    // to help programmers to understand why a control is not focused
    if (AWinControl = Self) or
       (GetParentForm(AWinControl) <> Self) or
       not ((csLoading in ComponentState) or AWinControl.CanFocus) then
    begin
      DebugLn(['TCustomForm.SetActiveControl ',DbgSName(Self),' AWinControl=',DbgSName(AWinControl),' GetParentForm(AWinControl)=',
              DbgSName(GetParentForm(AWinControl)),'=Self=',GetParentForm(AWinControl) = Self,
              ' csLoading=',csLoading in ComponentState,
              ' AWinControl.CanFocus=',AWinControl.CanFocus,
              ' IsControlVisible=',AWinControl.IsControlVisible,
              ' Enabled=',AWinControl.Enabled]);
      while AWinControl<>nil do begin
        debugln(['  ',DbgSName(AWinControl),' IsControlVisible=',AWinControl.IsControlVisible,' Enabled=',AWinControl.Enabled,' CanFocus=',AWinControl.CanFocus]);
        AWinControl:=AWinControl.Parent;
      end;
      {$IFDEF VerboseFocus}
      RaiseGDBException(SCannotFocus);
      {$ELSE}
      raise EInvalidOperation.Create(SCannotFocus);
      {$ENDIF}
    end;
  end;

  {$IFDEF VerboseFocus}
  Debugln(['TCustomForm.SetActiveControl ',DbgSName(Self),' FActive=',DbgS(FActive),' OldActiveControl=',DbgSName(FActiveControl),' NewActiveControl=',DbgSName(AWinControl)]);
  {$ENDIF}
  FActiveControl := AWinControl;
  if (FActiveControl<>nil) and not (FActiveControl is TCustomForm) then
    FLastActiveControl := FActiveControl;
  if Assigned(FActiveControl) then FreeNotification(FActiveControl);
  if ([csLoading, csDestroying] * ComponentState = []) then
  begin
    if FActive then
      SetWindowFocus;
    ActiveChanged;
  end;
end;

procedure TCustomForm.SetActiveDefaultControl(AControl: TControl);
var
  lPrevControl: TControl;
begin
  if AControl = FActiveDefaultControl then exit;
  lPrevControl := FActiveDefaultControl;
  FActiveDefaultControl := AControl;

  if Assigned(FActiveDefaultControl) then
    FActiveDefaultControl.FreeNotification(Self);

  // notify previous active default control that he has lost "default-ness"
  if Assigned(lPrevControl) then
    lPrevControl.ActiveDefaultControlChanged(AControl);
  // notify default control that it may become/lost active default again
  if Assigned(FDefaultControl) and (FDefaultControl <> lPrevControl) then
    FDefaultControl.ActiveDefaultControlChanged(AControl);
end;

procedure TCustomForm.SetAllowDropFiles(const AValue: Boolean);
begin
  if AValue = FAllowDropFiles then Exit;
  FAllowDropFiles := AValue;
  
  if HandleAllocated and not (csDesigning in ComponentState) then
    TWSCustomFormClass(WidgetSetClass).SetAllowDropFiles(Self, AValue);
end;

procedure TCustomForm.SetAlphaBlend(const AValue: Boolean);
begin
  if FAlphaBlend = AValue then
    Exit;
  FAlphaBlend := AValue;
  if not (csDesigning in ComponentState) and HandleAllocated then
    TWSCustomFormClass(WidgetSetClass).SetAlphaBlend(Self, AlphaBlend, AlphaBlendValue);
end;

procedure TCustomForm.SetAlphaBlendValue(const AValue: Byte);
begin
  if FAlphaBlendValue = AValue then
    Exit;
  FAlphaBlendValue := AValue;
  if not (csDesigning in ComponentState) and HandleAllocated then
    TWSCustomFormClass(WidgetSetClass).SetAlphaBlend(Self, AlphaBlend, AlphaBlendValue);
end;

{------------------------------------------------------------------------------
       TCustomForm SetFormStyle
------------------------------------------------------------------------------}
procedure TCustomForm.SetFormStyle(Value : TFormStyle);
var
  OldFormStyle: TFormStyle;
Begin
  if FFormStyle = Value then
    exit;
  OldFormStyle := FFormStyle;
  FFormStyle := Value;
  Include(FFormState, fsFormStyleChanged);

  if FFormStyle = fsSplash then
    BorderStyle := bsNone
  else
  if OldFormStyle = fsSplash then
    BorderStyle := bsSizeable;
  if HandleAllocated then
    TWSCustomFormClass(WidgetSetClass).SetFormStyle(Self, Value, OldFormStyle);
end;

{------------------------------------------------------------------------------
       TCustomForm SetPosition
------------------------------------------------------------------------------}
procedure TCustomForm.SetPosition(Value: TPosition);
begin
  if Value <> FPosition then
  begin
    FPosition := Value;
    if Value = poDefaultPosOnly then AutoSize := False;
    UpdateControlState;

    // we must update form TPosition if it's changed during runtime.
    if [csLoading, csDestroying, csDesigning] * ComponentState <> [] then Exit;

    if HandleAllocated and Showing and
       not (fsShowing in FFormState) and
       not (fsFirstShow in FFormState) then
      MoveToDefaultPosition;
  end;
end;

procedure TCustomForm.SetShowInTaskbar(Value: TShowInTaskbar);
begin
  if Value = FShowInTaskbar then exit;
  FShowInTaskbar := Value;
  UpdateShowInTaskBar;
end;

procedure TCustomForm.SetLastFocusedControl(AControl: TWinControl);
begin
  if FLastFocusedControl = AControl then exit;
  FLastFocusedControl := AControl;
  if Assigned(FLastFocusedControl) then
    FLastFocusedControl.FreeNotification(Self);
end;

{------------------------------------------------------------------------------
       TCustomForm Constructor
------------------------------------------------------------------------------}
constructor TCustomForm.Create(AOwner: TComponent);
begin
  FDelayedEventCtr := 0;
  FDelayedOnChangeBounds := False;
  FDelayedOnResize := False;
  FIsFirstOnShow := True;
  FIsFirstOnActivate := True;
  GlobalNameSpace.BeginWrite;
  try
    CreateNew(AOwner, 1); // this calls BeginFormUpdate, which is ended in AfterConstruction
    if (ClassType <> TForm) and not (csDesigning in ComponentState) then
    begin
      Include(FFormState, fsCreating);
      try
        ProcessResource;
      finally
        Exclude(FFormState, fsCreating);
      end;
    end;
  finally
    GlobalNameSpace.EndWrite;
  end;
end;

procedure TCustomForm.ProcessResource;
begin
  if not InitResourceComponent(Self, TForm) then
    if RequireDerivedFormResource then
      raise EResNotFound.CreateFmt(
        rsFormResourceSNotFoundForResourcelessFormsCreateNew, [ClassName])
    else
      DebugLn(Format(rsFormResourceSNotFoundForResourcelessFormsCreateNew, [ClassName]));
end;

{------------------------------------------------------------------------------
  constructor TCustomForm.CreateNew(AOwner: TComponent; Num : Integer);
------------------------------------------------------------------------------}
constructor TCustomForm.CreateNew(AOwner: TComponent; Num: Integer = 0);
begin
  Include(FFormState,fsFirstShow);
  //DebugLn('[TCustomForm.CreateNew] Class=',Classname);
  BeginFormUpdate;
  FLastFocusedControl := Self;
  FBorderIcons := [biSystemMenu, biMinimize, biMaximize];
  FDefaultMonitor := dmActiveForm;
  FPopupMode := pmNone;
  FShowInTaskbar := stDefault;
  FAlphaBlend := False;
  FAlphaBlendValue := 255;
  case Application.DoubleBuffered of
    adbDefault: FDoubleBuffered := TWSCustomFormClass(WidgetSetClass).GetDefaultDoubleBuffered;
    adbTrue: FDoubleBuffered := True;
    adbFalse: FDoubleBuffered := False;
  end;
  // set border style before handle is allocated
  if not (fsBorderStyleChanged in FFormState) then
    FFormBorderStyle:= bsSizeable;
  // set form style before handle is allocated
  if not (fsFormStyleChanged in FFormState) then
    FFormStyle:= fsNormal;

  inherited Create(AOwner);
  Visible := False;
  fCompStyle:= csForm;

  FMenu := nil;

  ControlStyle := ControlStyle + [csAcceptsControls, csCaptureMouse,
                                  csClickEvents, csSetCaption, csDoubleClicks];
  with GetControlClassDefaultSize do
    SetInitialBounds(0, 0, CX, CY);
  ParentColor := False;
  ParentFont := False;
  FWindowState := wsNormal;
  FIcon := TIcon.Create;
  FIcon.OnChange := @IconChanged;
  FKeyPreview :=  False;
  Color := {$ifdef UseCLDefault}clDefault{$else}clBtnFace{$endif};
  FloatingDockSiteClass := TWinControlClass(ClassType);
  Screen.AddForm(Self);
  FAllowDropFiles := False;

  if ParentBiDiMode then
    BiDiMode := Application.BidiMode;

  // Accessibility
  AccessibleDescription := 'A window';
  AccessibleRole := larWindow;

  // the EndFormUpdate is done in AfterConstruction
end;

{------------------------------------------------------------------------------
  TCustomForm CreateParams
------------------------------------------------------------------------------}
procedure TCustomForm.CreateParams(var Params : TCreateParams);
var
  APopupParent: TCustomForm;
begin
  inherited CreateParams(Params);
  with Params do
  begin
    if (Parent = nil) and (ParentWindow = 0) then
    begin
      // define Parent according to PopupMode and PopupParent
      if not (csDesigning in ComponentState) then
      begin
        if (Application.MainForm <> Self) then
        begin
          APopupParent := GetRealPopupParent;
          if APopupParent <> nil then
            WndParent := APopupParent.Handle;
        end;
        if (WndParent = 0) and
           (((Self = Application.MainForm) and Application.MainFormOnTaskBar) or (GetEffectiveShowInTaskBar = stAlways)) then
          ExStyle := ExStyle or WS_EX_APPWINDOW;
      end;
      Style := Style and not Cardinal(WS_GROUP or WS_TABSTOP or WS_CHILD);
    end;
  end;
end;


{------------------------------------------------------------------------------
       TCustomForm Method Close
------------------------------------------------------------------------------}
procedure TCustomForm.Close;
var
  CloseAction: TCloseAction;
  IsMainForm: Boolean;
begin
  if fsModal in FFormState then
    ModalResult := mrCancel
  else
  begin
    if CloseQuery then
    begin
      // IsMainForm flag set if we are closing MainForm or its parent
      IsMainForm := (Application.MainForm = Self) or (Self.IsParentOf(Application.MainForm));
      // Prepare default close action
      if FormStyle = fsMDIChild then
      begin
        CloseAction := caNone;
        // TODO: mdi logic
      end
      else
      begin
        if IsMainForm then
          CloseAction := caFree
        else
          CloseAction := caHide;
      end;
      // call event handler and let user modify CloseAction
      DoClose(CloseAction);
      // execute action according to close action
      case CloseAction of
        caHide: Hide;
        caMinimize: WindowState := wsMinimized;
        caFree:
          begin
            // if form is MainForm, then terminate the application
            // the owner of the MainForm is the application,
            // so the Application will take care of free-ing the form
            // and Release is not necessary
            if IsMainForm then
              Application.Terminate
            else
              Release;
          end;
      end;
    end;
  end;
end;

{------------------------------------------------------------------------------
  procedure TCustomForm.Release;
------------------------------------------------------------------------------}
procedure TCustomForm.Release;
begin
  if Application <> nil then
    Application.ReleaseComponent(Self)
  else
    Free;
end;

function TCustomForm.CanFocus: Boolean;
begin
  if Parent = nil then
    Result := IsControlVisible and Enabled
  else
    Result := inherited CanFocus;
end;

{------------------------------------------------------------------------------
       TCustomForm Method CloseQuery
------------------------------------------------------------------------------}
function TCustomForm.CloseQuery: boolean;

  function Check(AControl: TWinControl): boolean;
  var
    i: Integer;
    Child: TControl;
  begin
    for i:=0 to AControl.ControlCount-1 do begin
      Child:=AControl.Controls[i];
      if Child is TWinControl then begin
        if Child is TCustomForm then begin
          if not TCustomForm(Child).CloseQuery then exit(false);
        end else begin
          if not Check(TWinControl(Child)) then exit(false);
        end;
      end;
    end;
    Result:=true;
  end;

var
  I: Integer;
begin
  if FormStyle = fsMDIForm then
  begin
    // Query children forms whether we can close
    if not Check(Self) then exit(False);
    for I := 0 to MDIChildCount - 1 do
      if not MDIChildren[I].CloseQuery then Exit(False);
  end;
  Result := True;
  if Assigned(FOnCloseQuery) then
    FOnCloseQuery(Self, Result);
end;

{------------------------------------------------------------------------------
       TCustomForm Method WMCloseQuery
------------------------------------------------------------------------------}
procedure TCustomForm.WMCloseQuery(var message: TLMessage);
begin
  Close;
  // Always return 0, because we destroy the window ourselves
  Message.Result:= 0;
end;

procedure TCustomForm.WMDPIChanged(var Msg: TLMessage);
var
  NewDpi, I, L: integer;
begin
  if Parent=nil then
  begin
    NewDpi := hi(Cardinal(Msg.wParam));
    if Application.Scaled and Scaled and (NewDpi<>PixelsPerInch) then
    begin
      { Problem (Windows): if the form is shown the first time on a secondary monitor
        with a different DPI settings, the WM_DPICHANGED message is sent within
        UpdateBounds when BoundsLockCount>0 which means the bounds are not scaled.
        We force to update the bounds. See issue 32162.
        (A better solution is welcome.)
      }
      I := -1;
      while BoundsLockCount>0 do
      begin
        EndUpdateBounds;
        Inc(I);
      end;
      try
        AutoAdjustLayout(lapAutoAdjustForDPI, PixelsPerInch, NewDpi,
          Width, MulDiv(Width, NewDpi, PixelsPerInch));
      finally
        for L := 0 to I do
          BeginUpdateBounds;
      end;
    end;
  end;
end;

{------------------------------------------------------------------------------
       TCustomForm Method Hide
------------------------------------------------------------------------------}
procedure TCustomForm.Hide;
begin
  Visible := False;
end;

{------------------------------------------------------------------------------
  procedure TCustomForm.Show;
------------------------------------------------------------------------------}
procedure TCustomForm.Show;
var
  MonPPI: Integer;
begin
  MonPPI := Monitor.PixelsPerInch;
  if Application.Scaled and Scaled and (MonPPI > 0) and (MonPPI <> PixelsPerInch) then
    AutoAdjustLayout(lapAutoAdjustForDPI, PixelsPerInch, MonPPI,
                     Width, MulDiv(Width, MonPPI, PixelsPerInch));

  Visible := True;
  { wxMaximized secondary forms are not being shown maximized }
  if (not (csDesigning in ComponentState)) and Showing then
    ShowWindow(Handle, ShowCommands[WindowState]);
  BringToFront;
end;

{------------------------------------------------------------------------------
  procedure TCustomForm.ShowOnTop;
------------------------------------------------------------------------------}
procedure TCustomForm.ShowOnTop;
begin
  if WindowState = wsMinimized then
    WindowState := wsNormal;
  Visible := True;
  BringToFront;
  //DebugLn(['TCustomForm.ShowOnTop ',Name,':',ClassName,' ',Visible,' ',HandleAllocated,' ',csDesigning in ComponentState]);
end;

{------------------------------------------------------------------------------
  TCustomForm AutoSizeDelayedHandle

  Returns true if AutoSize should be skipped / delayed because of its handle.
------------------------------------------------------------------------------}
function TCustomForm.AutoSizeDelayedHandle: Boolean;
begin
  if (Parent<>nil) or (ParentWindow<>0) then
    // this form is inlined / embedded it works like a normal TWinControl
    Result:=inherited AutoSizeDelayedHandle
  else
    // this form is on a screen => no delay
    Result:=false;
end;

{------------------------------------------------------------------------------}
{  Method: TCustomForm.IsAutoScrollStored                                      }
{  Returns: if form AutoScroll should be stored in the stream                  }
{------------------------------------------------------------------------------}
function TCustomForm.IsAutoScrollStored: Boolean;
begin
  // store autoscroll only if BorderStyle allows this
  Result := IsForm and (BorderStyle in BorderStylesAllowAutoScroll);
end;

{------------------------------------------------------------------------------}
{  Method: TCustomForm.IsForm                                                  }
{  Returns: if form properties should be stored in the stream                  }
{------------------------------------------------------------------------------}
function TCustomForm.IsForm: Boolean;
begin
  Result := True;
end;

{------------------------------------------------------------------------------}
{  Method: TCustomForm.IsIconStored                                            }
{  Returns: if form icon should be stored in the stream                        }
{------------------------------------------------------------------------------}
function TCustomForm.IsIconStored: Boolean;
begin
  Result := IsForm and (Icon <> nil);
end;

function TCustomForm.GetMonitor: TMonitor;
var
  ParentForm: TCustomForm;
begin
  if Assigned(Parent) then
  begin
    ParentForm := GetParentForm(Self);
    if Assigned(ParentForm) then
      Result := ParentForm.Monitor
    else
      Result := nil;
  end else
  begin
    if HandleAllocated then begin
      // ensure widgetset has latest coordinates // invisible forms are not updated by DoSendBoundsToInterface
      if (not HandleObjectShouldBeVisible) then
        TWSWinControlClass(WidgetSetClass).SetBounds(Self, Left, Top, Width, Height);
      Result := Screen.MonitorFromWindow(Handle, mdNearest);
    end
    else
      Result := Screen.MonitorFromPoint(point(Left,Top));
  end;
end;

{------------------------------------------------------------------------------
  TCustomForm Method SetFocusedControl

  Switch focus.
------------------------------------------------------------------------------}
function TCustomForm.SetFocusedControl(Control: TWinControl): Boolean;

  function SendEnterExitLoop: Boolean;

    function NextChildControl(CurParent, Target: TWinControl): TWinControl; inline;
    begin
      while (Target <> nil) and (Target.Parent <> CurParent) do
        Target := Target.Parent;
      Result := Target;
    end;

  var
    LastState: TFocusState;
    Tmp: TWinControl;
  begin
    // send cm_exit, cm_enter messages
    // cm_exit must be sent to all controls from lastfocusedcontrol to the first parent which contains control
    // cm_enter must be sent from the control we stoped up to control
    // if during this loop something happens with focus (another control or form has aquired it) we need to stop it

    if (FLastFocusedControl<>nil) and (not ContainsControl(FLastFocusedControl)) then
      FLastFocusedControl:=nil; // e.g. FLastFocusedControl was removed from this form
    if FLastFocusedControl=nil then
      FLastFocusedControl:=Self;

    {$IFDEF VerboseFocus}
    debugln(['Sending CM_EXIT,CM_ENTER Form=',Self,' from FLastFocusedControl=',FLastFocusedControl,' to ',Control,' ...']);
    {$ENDIF}
    while not FLastFocusedControl.ContainsControl(Control) do
    begin
      LastState := SaveFocusState;
      if FLastFocusedControl = nil then Exit(False);
      // calling of CM_EXIT can cause other focus changes - so FLastFocusedControl can change after the call
      // therefore we need to change it before the call
      Tmp := FLastFocusedControl;
      if Assigned(Tmp.Parent) and
        ((csDestroying in Tmp.Parent.ComponentState) or
        (csDestroyingHandle in Tmp.Parent.ControlState)) then
        Exit(False);
      SetLastFocusedControl(Tmp.Parent);
      Tmp.Perform(CM_EXIT, 0, 0);
      if SaveFocusState <> LastState then
      begin
        {$IFDEF VerboseFocus}
        debugln(['SendEnterExitLoop Form=',Self,' Control=',Control,' sending CM_EXIT to ',Tmp,' changed focus => FAILED']);
        {$ENDIF}
        Exit(False);
      end;
      if FLastFocusedControl=nil then begin
        {$IFDEF VerboseFocus}
        debugln(['SendEnterExitLoop Form=',Self,' Control=',Control,' sending CM_EXIT to ',Tmp,' FAILED because path missing from last to control']);
        {$ENDIF}
        exit(false);
      end;
    end;

    while FLastFocusedControl <> Control do
    begin
      SetLastFocusedControl(NextChildControl(FLastFocusedControl, Control));
      if FLastFocusedControl = nil then Exit(False);
      LastState := SaveFocusState;
      FLastFocusedControl.Perform(CM_ENTER, 0, 0);
      if SaveFocusState <> LastState then
      begin
        {$IFDEF VerboseFocus}
        debugln(['SendEnterExitLoop Form=',Self,' Control=',Control,' sending CM_ENTER to ',Tmp,' changed focus => FAILED']);
        {$ENDIF}
        Exit(False);
      end;
    end;
    Result := True;
  end;

var
  ParentForm: TCustomForm;
begin
  LastFocusedControl := Control;
  Result := False;
  if (Control <> nil) and (csDestroying in Control.ComponentState) then Exit;
  if (csDestroying in ComponentState) or (csDestroyingHandle in ControlState) then
    exit;

  if (Parent <> nil) then
  begin
    // delegate to topmost form
    ParentForm := GetParentForm(Self);
    if ParentForm <> nil then
      Result := ParentForm.SetFocusedControl(Control);
    Exit;
  end;

  // update FActiveControl
  if ([csLoading, csDesigning] * ComponentState = []) then
  begin
    if Control <> Self then
    begin
      if FActiveControl<>Control then
      begin
        {$IFDEF VerboseFocus}
        debugln(['TCustomForm.SetFocusedControl ',DbgSName(Self),' OldActiveControl=',DbgSName(FActiveControl),' New=',DbgSName(Control)]);
        {$ENDIF}
        FActiveControl := Control;
        if (FActiveControl<>nil) and not (FActiveControl is TCustomForm) then
          FLastActiveControl := FActiveControl;
        if Assigned(FActiveControl) then
          FreeNotification(FActiveControl);
      end;
    end
    else
    begin
      {$IFDEF VerboseFocus}
      if Assigned(FActiveControl) then
        debugln(['TCustomForm.SetFocusedControl ',DbgSName(Self),' OldActiveControl=',DbgSName(FActiveControl),' New=',DbgSName(Control)]);
      {$ENDIF}
      FActiveControl := nil;
    end;
  end;

  // update Screen object
  Screen.FActiveControl := Control;
  if Control <> nil then
  begin
    Screen.FActiveCustomForm := Self;
    Screen.MoveFormToFocusFront(Self);
    if Self is TForm then
      Screen.FActiveForm := TForm(Self)
    else
      Screen.FActiveForm := nil;
  end;
  Screen.UpdateLastActive;

  {$IFDEF VerboseFocus}
  DbgOut('TCustomForm.SetFocusedControl Self=',DbgSName(Self));
  if Control<>nil then
    DbgOut([' Control=',Control,' Control.HandleAllocated=',Control.HandleAllocated,' csFocusing=',(csFocusing in Control.ControlState)]);
  DebugLn();
  {$ENDIF}

  if (Control <> nil) and (not (csFocusing in Control.ControlState)) then
  begin
    Control.ControlState := Control.ControlState + [csFocusing];
    try
      if not Screen.SetFocusedForm(Self) then
      begin
        {$IFDEF VerboseFocus}
        debugln(['TCustomForm.SetFocusedControl Form=',DbgSName(Self),' Control=',DbgSName(Control),' Screen.SetFocusedForm FAILED']);
        {$ENDIF}
        Exit;
      end;
      Result := SendEnterExitLoop;
    finally
      Control.ControlState := Control.ControlState - [csFocusing];
    end;
  end;
end;

{------------------------------------------------------------------------------
       TCustomForm Method WantChildKey
------------------------------------------------------------------------------}
function TCustomForm.WantChildKey(Child : TControl; var Message : TLMessage):Boolean;
begin
  Result := False;
end;

function TCustomForm.IsShortcut(var Message: TLMKey): boolean;
var
  I: integer;
begin
  Result := false;
  if Assigned(FOnShortcut) then
  begin
    FOnShortcut(Message, Result);
    if Result then exit;
  end;
  if Assigned(FMenu) then
  begin
    Result := FMenu.IsShortCut(Message);
    if Result then exit;
  end;
  if Assigned(FActionLists) then
  begin
    for I := 0 to FActionLists.Count - 1 do
    begin
      Result := TCustomActionList(FActionLists.Items[I]).IsShortCut(Message);
      if Result then exit;
    end;
  end;
end;

procedure TCustomForm.MakeFullyVisible(AMonitor: TMonitor; UseWorkarea: Boolean = False);
var
  newLeft, newTop, WindowWidth, WindowHeight: Integer;
  ABounds: TRect;
  Mon: TMonitor;
begin
  newLeft := Left;
  newTop := Top;

  // window rect is not the same as bounds rect. window rect contains titlebar
  if GetWindowRect(Handle, ABounds) = 0 then
    ABounds := BoundsRect;
  with ABounds do
  begin
    WindowWidth := Right - Left;
    WindowHeight := Bottom - Top;
  end;

  // reduce calls to GetMonitor
  if AMonitor <> nil then
    Mon := AMonitor
  else
    Mon := Monitor;

  if Mon <> nil then
    if UseWorkArea then
      ABounds := Mon.WorkareaRect
    else
      ABounds := Mon.BoundsRect
  else
    ABounds := Bounds(0, 0, Screen.Width, Screen.Height);

  if newLeft + WindowWidth > ABounds.Right then
    newLeft := ABounds.Right - WindowWidth;
  if newLeft < ABounds.Left then
    newLeft := ABounds.Left;
  if newTop + WindowHeight > ABounds.Bottom then
    newTop := ABounds.Bottom - WindowHeight;
  if newTop < ABounds.Top then
    newTop := ABounds.Top;
  SetBounds(newLeft, newTop, Width, Height);
end;

{------------------------------------------------------------------------------
  Method:  TCustomForm.IntfDropFiles
  Params:  FileNames - Dropped files

  Invokes OnDropFilesEvent of the form.
  This function is called by the interface.
 ------------------------------------------------------------------------------}
procedure TCustomForm.IntfDropFiles(const FileNames: array of String);
begin
  //debugln(['TCustomForm.IntfDropFiles ',DbgSName(Self)]);
  if Assigned(FOnDropFiles) then FOnDropFiles(Self, FileNames);
end;

{------------------------------------------------------------------------------
  procedure TCustomForm.IntfHelp(AComponent: TComponent);

  Show help for control or menu item.
  This function is called by the interface.
------------------------------------------------------------------------------}
procedure TCustomForm.IntfHelp(AComponent: TComponent);
begin
  if csDesigning in ComponentState then exit;
  
  if AComponent is TControl then begin
    TControl(AComponent).ShowHelp;
  end else begin
    DebugLn('TCustomForm.IntfHelp TODO help for ',DbgSName(AComponent));
  end;
end;

function TCustomForm.GetFormImage: TBitmap;
var
  ARect: TRect;
begin
  Result := TBitmap.Create;
  try
    Result.SetSize(ClientWidth, ClientHeight);
    LCLIntf.GetWindowRect(Handle, ARect);
    with GetClientOrigin do
      PaintTo(Result.Canvas, ARect.Left - X, ARect.Top - Y);
  except
    Result.Free;
    raise;
  end;
end;

procedure TCustomForm.CreateWnd;
// Creates the interface object.
begin
  //DebugLn('TCustomForm.CreateWnd START ',ClassName);
  FFormState := FFormState - [fsBorderStyleChanged, fsFormStyleChanged];
  inherited CreateWnd;

  //DebugLn('Trace:[TCustomForm.CreateWnd] FMenu.HandleNeeded');
  UpdateMenu;

  // update icon
  Perform(CM_ICONCHANGED, 0, 0);
  //DebugLn('TCustomForm.CreateWnd END ',ClassName);
end;

procedure TCustomForm.DestroyWnd;
begin
  if Assigned(FMenu) then
    FMenu.DestroyHandle;
  inherited DestroyWnd;
end;

procedure TCustomForm.Loaded;
var
  Control: TWinControl;
begin
  {$IF defined(CHECK_POSITION) or defined(VerboseFormUpdateShowing) or defined(VerboseShowing)}
  debugln(['[TCustomForm.Loaded] START ',DbgSName(Self),' Pos=',Left,',',Top,' Visible=',Visible,' Showing=',Showing]);
  {$ENDIF}
  DisableAlign;
  try
    if Application.Scaled and Scaled then
      FixDesignFontsPPIWithChildren(FDesignTimePPI);
    inherited Loaded;
  finally
    EnableAlign;
  end;
  if (ActiveControl <> nil) and (Parent = nil) then
  begin
    // check if loaded ActiveControl can be focused
    // and if yes, call SetActiveControl to invoke handlers
    Control := ActiveControl;
    {$IFDEF VerboseFocus}
    if FActiveControl<>nil then
      Debugln('TCustomForm.Loaded Self=',DbgSName(Self),' FActiveControl=',DbgSName(FActiveControl));
    {$ENDIF}
    FActiveControl := nil;
    if Control.CanFocus then SetActiveControl(Control);
  end;
  //DebugLn('TCustomForm.Loaded ',Name,':',ClassName,' ',FormUpdating,' ',fsCreating in FFormState,' ',Visible,' ',fsVisible in FormState);
  if fsVisible in FormState then
    Visible := True;
end;

procedure TCustomForm.ChildHandlesCreated;
// Called after all children handles are created.
begin
  inherited ChildHandlesCreated;
  if Parent=nil then
    ParentFormHandleInitialized;
end;

procedure TCustomForm.BeginFormUpdate;
begin
  inc(FFormUpdateCount);
  if FFormUpdateCount=1 then
    DisableAutoSizing{$IFDEF DebugDisableAutoSizing}('TCustomForm.BeginFormUpdate'){$ENDIF};
end;

procedure TCustomForm.UpdateShowing;
// Here the initial form left and top are determined.
begin
  if csLoading in ComponentState then exit;
  {$IF defined(CHECK_POSITION) or defined(VerboseFormUpdateShowing) or defined(VerboseShowing)}
  DebugLn(['[TCustomForm.UpdateShowing] START ',DbgSName(Self),' Pos=',Left,',',Top,' Visible=',Visible,' Showing=',Showing]);
  {$ENDIF}
  // If the form is about to show, calculate its metrics
  if Visible and (not (csDestroying in ComponentState)) then
  begin
    if not (csDesigning in ComponentState) then
      MoveToDefaultPosition;
    if (fsFirstShow in FFormState) then
    begin
      Exclude(FFormState, fsFirstShow);
      DoFirstShow;
    end;
  end;
  {$IF defined(CHECK_POSITION) or defined(VerboseFormUpdateShowing) or defined(VerboseShowing)}
  DebugLn(['[TCustomForm.UpdateShowing] calling inherited  ',dbgsname(Self),' Pos=',Left,',',Top]);
  {$ENDIF}
  inherited UpdateShowing;
  {$IF defined(CHECK_POSITION) or defined(VerboseFormUpdateShowing) or defined(VerboseShowing)}
  DebugLn(['[TCustomForm.UpdateShowing] activating  ',dbgsname(Self),' Pos=',Left,',',Top]);
  {$ENDIF}
  // activate focus if visible
  if Showing and (not (csDestroying in ComponentState)) then
  begin
    if (not Assigned(ActiveControl)) and (not (csDesigning in ComponentState)) and (Parent=nil) then
    begin
      // automatically choose a control to focus
      {$IFDEF VerboseFocus}
      DebugLn('TCustomForm.CreateWnd ',DbgSName(Self),' Set ActiveControl := ',DbgSName(FindDefaultForActiveControl));
      {$ENDIF}
      ActiveControl := FindDefaultForActiveControl;
    end;
    if (Parent=nil) and Assigned(ActiveControl) and
       ActiveControl.HandleAllocated and ActiveControl.CanFocus and
       ([csLoading, csDestroying, csDesigning] * ComponentState = []) then
    begin
      {$IFDEF VerboseFocus}
      DebugLn('TCustomForm.CreateWnd A ',DbgSName(Self),' FActiveControl=',DbgSName(FActiveControl));
      {$ENDIF}
      LCLIntf.SetFocus(ActiveControl.Handle);
    end;
    UpdateShowInTaskBar;
  end;
end;

procedure TCustomForm.DoFirstShow;
begin
  FFormHandlers[fhtFirstShow].CallNotifyEvents(Self);
end;

{------------------------------------------------------------------------------
  Method:  TCustomForm.GetClientHandle
  Params:  None
  Returns: Nothing

  Returns handle of fsMdiForm container for mdi children.
  This is not same as Handle of form.
  Result is valid only if form FormStyle = fsMDIForm or FormStyle = fsMDIChild.
  In case when FormStyle = fsMDIChild it'll return handle of it's container
  (fsMDIForm).
 ------------------------------------------------------------------------------}
function TCustomForm.GetClientHandle: HWND;
begin
  Result := 0;
  if not (FormStyle in [fsMDIForm, fsMDIChild]) then
    exit;
  if HandleAllocated and not (csDesigning in ComponentState) then
    Result := TWSCustomFormClass(WidgetSetClass).GetClientHandle(Self);
end;

{------------------------------------------------------------------------------
  Method:  TCustomForm.ActiveMDIChild
  Params:  None
  Returns: Nothing

  Returns currently active MDI child form of self.
  Valid result is returned only when Self FormStyle = fsMDIForm or fsMDIChild,
  otherwise Result is nil.
 ------------------------------------------------------------------------------}
function TCustomForm.ActiveMDIChild: TCustomForm;
begin
  Result := nil;
  if not (FormStyle in [fsMDIForm, fsMDIChild]) then
    exit;
  if HandleAllocated and not (csDesigning in ComponentState) then
    Result := TWSCustomFormClass(WidgetSetClass).ActiveMDIChild(Self);
end;

{------------------------------------------------------------------------------
  Method:  TCustomForm.MDIChildCount
  Params:  None
  Returns: Nothing

  Returns count of MDIChild forms.
  Result is returned only when Self FormStyle = fsMDIForm or fsMDIChild (can
  be 0 ... number of mdichild forms).
  If Result is -1 then caller isn't mdi or handle is not allocated.
 ------------------------------------------------------------------------------}
function TCustomForm.MDIChildCount: Integer;
begin
  Result := -1;
  if not (FormStyle in [fsMDIForm, fsMDIChild]) then
    exit;
  if HandleAllocated and not (csDesigning in ComponentState) then
    Result := TWSCustomFormClass(WidgetSetClass).MDIChildCount(Self);
end;

{------------------------------------------------------------------------------
  Method:  TCustomForm.MDIChildCount
  Params:  AIndex: Integer;
  Returns: TCustomForm with FormStyle = fsMDIChild

  Returns MDI child (fsMDIChild) of parent mdi form (fsMDIForm) at index
  AIndex in list of mdi children.
  Result can be nil if caller isn't an mdi type or handle isn't allocated.
 ------------------------------------------------------------------------------}
function TCustomForm.GetMDIChildren(AIndex: Integer): TCustomForm;
begin
  Result := nil;
  if not (FormStyle in [fsMDIForm, fsMDIChild]) then
    exit;
  if HandleAllocated and not (csDesigning in ComponentState) then
    Result := TWSCustomFormClass(WidgetSetClass).GetMDIChildren(Self, AIndex);
end;


{------------------------------------------------------------------------------
  TCustomForm ShowModal
------------------------------------------------------------------------------}
function TCustomForm.ShowModal: Integer;

  function HasVisibleForms: Boolean;
  var
    i: integer;
    AForm: TCustomForm;
  begin
    Result := False;
    for i := 0 to Screen.CustomFormZOrderCount - 1 do
    begin
      AForm := Screen.CustomFormsZOrdered[i];
      if (AForm <> Self) and not (AForm.FormStyle = fsMDIChild) and
        (AForm.Parent = nil) and AForm.Visible and AForm.HandleAllocated then
      begin
        Result := True;
        break;
      end;
    end;
  end;

  procedure RaiseShowModalImpossible;
  var
    s: String;
  begin
    DebugLn('TCustomForm.ShowModal Visible=',dbgs(Visible),' Enabled=',dbgs(Enabled),
      ' fsModal=',dbgs(fsModal in FFormState),' MDIChild=',dbgs(FormStyle = fsMDIChild));
    s:='TCustomForm.ShowModal for '+DbgSName(Self)+' impossible, because';
    if Visible then
      s:=s+' already visible (hint for designer forms: set Visible property to false)';
    if not Enabled then
      s:=s+' not enabled';
    if fsModal in FFormState then
      s:=s+' already modal';
    if FormStyle = fsMDIChild then
      s:=s+' FormStyle=fsMDIChild';
    raise EInvalidOperation.Create(s);
  end;

  procedure RestoreFocusedForm;
  begin
    // needs to be called only in ShowModal
    Perform(CM_DEACTIVATE, 0, 0);
    if Screen.FSaveFocusedList.Count > 0 then
    begin
      Screen.FFocusedForm := TCustomForm(Screen.FSaveFocusedList.First);
      Screen.FSaveFocusedList.Remove(Screen.FFocusedForm);
    end
    else
      Screen.FFocusedForm := nil;
  end;

var
  DisabledList: TList;
  SavedFocusState: TFocusState;
  ActiveWindow: HWnd;
begin
  if Self = nil then
    raise EInvalidOperation.Create('TCustomForm.ShowModal Self = nil');
  if Application.Terminated then
    ModalResult := 0;
  // cancel drags
  DragManager.DragStop(false);
  // close popupmenus
  if ActivePopupMenu <> nil then
    ActivePopupMenu.Close;
  if Visible or (not Enabled) or (fsModal in FFormState) or (FormStyle = fsMDIChild) then
    RaiseShowModalImpossible;
  // Kill capture when opening another dialog
  if GetCapture <> 0 then
    SendMessage(GetCapture, LM_CANCELMODE, 0, 0);
  ReleaseCapture;

  Application.ModalStarted;
  try
    Include(FFormState, fsModal);
    if (PopupMode = pmNone) and HandleAllocated then
      RecreateWnd(Self); // need to refresh handle for pmNone because ParentWindow changes if (fsModal in FFormState) - see GetRealPopupParent
    ActiveWindow := GetActiveWindow;
    SavedFocusState := SaveFocusState;
    Screen.FSaveFocusedList.Insert(0, Screen.FFocusedForm);
    Screen.FFocusedForm := Self;
    Screen.MoveFormToFocusFront(Self);
    Screen.BeginTempCursor(crDefault);
    ModalResult := 0;

    try
      if WidgetSet.GetLCLCapability(lcModalWindow) = LCL_CAPABILITY_NO then
        DisabledList := Screen.DisableForms(Self)
      else
        DisabledList := nil;
      Show;
      try
        // activate must happen after show
        Perform(CM_ACTIVATE, 0, 0);
        TWSCustomFormClass(WidgetSetClass).ShowModal(Self);
        repeat
          { Delphi calls Application.HandleMessage
            But HandleMessage processes all pending events and then calls idle,
            which will wait for new messages. Under Win32 there is always a next
            message, so it works there. The LCL is OS independent, and so it uses
            a better way: }
          try
            WidgetSet.AppProcessMessages; // process all events
          except
            if Application.CaptureExceptions then
              Application.HandleException(Self)
            else
              raise;
          end;
          if Application.Terminated then
            ModalResult := mrCancel;
          if ModalResult <> 0 then
          begin
            CloseModal;
            if ModalResult<>0 then break;
          end;

          Application.Idle(true);
        until False;

        Result := ModalResult;
        if HandleAllocated and (GetActiveWindow <> Handle) then
          ActiveWindow := 0;
      finally
        { guarantee execution of widgetset CloseModal }
        TWSCustomFormClass(WidgetSetClass).CloseModal(Self);
        // set our modalresult to mrCancel before hiding.
        if ModalResult = 0 then
          ModalResult := mrCancel;
        // We should always re-enabled the forms before issuing Hide()
        // Because otherwise we will for a short amount of time have
        // all forms disabled, and some systems, like WinCE, will interprete this
        // as a problem in the application and hide it.
        // See bug 22718
        Screen.EnableForms(DisabledList);
        Hide;
        RestoreFocusedForm;
      end;
    finally
      RestoreFocusState(SavedFocusState);
      Screen.EndTempCursor(crDefault);
      if LCLIntf.IsWindow(ActiveWindow) then
        SetActiveWindow(ActiveWindow);
      Exclude(FFormState, fsModal);
      if ((PopupMode = pmNone) and HandleAllocated) and not (csDestroying in ComponentState) then
        RecreateWnd(Self); // need to refresh handle for pmNone because ParentWindow changes if (fsModal in FFormState) - see GetRealPopupParent
    end;
  finally
    Application.ModalFinished;
  end;
end;

function TCustomForm.GetRolesForControl(AControl: TControl
  ): TControlRolesForForm;
begin
  Result:=[];
  if DefaultControl=AControl then Include(Result,crffDefault);
  if CancelControl=AControl then Include(Result,crffCancel);
end;

procedure TCustomForm.RemoveAllHandlersOfObject(AnObject: TObject);
var
  HandlerType: TFormHandlerType;
begin
  inherited RemoveAllHandlersOfObject(AnObject);
  for HandlerType:=Low(TFormHandlerType) to High(TFormHandlerType) do
    FFormHandlers[HandlerType].RemoveAllMethodsOfObject(AnObject);
end;

procedure TCustomForm.AddHandlerFirstShow(OnFirstShowHandler: TNotifyEvent;
  AsFirst: Boolean);
begin
  AddHandler(fhtFirstShow,TMethod(OnFirstShowHandler),AsFirst);
end;

procedure TCustomForm.RemoveHandlerFirstShow(OnFirstShowHandler: TNotifyEvent);
begin
  RemoveHandler(fhtFirstShow,TMethod(OnFirstShowHandler));
end;

procedure TCustomForm.AddHandlerClose(OnCloseHandler: TCloseEvent;
  AsFirst: Boolean);
begin
  AddHandler(fhtClose,TMethod(OnCloseHandler),AsFirst);
end;

procedure TCustomForm.RemoveHandlerClose(OnCloseHandler: TCloseEvent);
begin
  RemoveHandler(fhtClose,TMethod(OnCloseHandler));
end;

procedure TCustomForm.AddHandlerCreate(OnCreateHandler: TNotifyEvent;
  AsFirst: Boolean);
begin
  AddHandler(fhtCreate,TMethod(OnCreateHandler),AsFirst);
end;

procedure TCustomForm.RemoveHandlerCreate(OnCreateHandler: TNotifyEvent);
begin
  RemoveHandler(fhtCreate,TMethod(OnCreateHandler));
end;

procedure TCustomForm.Dock(NewDockSite: TWinControl; ARect: TRect);
begin
  inherited Dock(NewDockSite, ARect);
end;

procedure TCustomForm.UpdateDockCaption(Exclude: TControl);
const
  MaxCaption = 20;
var
  NewCaption: String;
  i: Integer;
  AControl: TControl;
  CtrlCaption: String;
begin
  { Show the combined captions of all clients.
    Exclude client to be undocked.
    Don't change the Caption to an empty string. }
  NewCaption := '';
  for i := 0 to DockClientCount - 1 do
  begin
    AControl := DockClients[i];
    // check if control is shown
    if (AControl = Exclude) or (not AControl.IsControlVisible) then
      continue;
    // get caption
    CtrlCaption:=GetDockCaption(AControl);
    if CtrlCaption='' then continue;
    // do not put garbage in the title
    UTF8FixBroken(CtrlCaption);
    if not (AControl is TCustomForm) then
    begin
      // non controls like tmemo can have very long captions => cut them
      if UTF8Length(CtrlCaption)>MaxCaption then
        CtrlCaption:=UTF8Copy(CtrlCaption,1,MaxCaption)+'...';
    end;
    if NewCaption<>'' then NewCaption := NewCaption+', ';
    NewCaption:=NewCaption+CtrlCaption;
  end;
  // don't change the Caption to an empty string
  if NewCaption <> '' then
    Caption := NewCaption;
end;

//==============================================================================

{ TForm }

function TForm.LCLVersionIsStored: boolean;
begin
  Result:=Parent=nil;
end;

class procedure TForm.WSRegisterClass;
begin
  inherited WSRegisterClass;
  RegisterPropertyToSkip(TForm, 'OldCreateOrder', 'VCL compatibility property', '');
  RegisterPropertyToSkip(TForm, 'TextHeight', 'VCL compatibility property', '');
  RegisterPropertyToSkip(TForm, 'Scaled', 'VCL compatibility property', '');
  RegisterPropertyToSkip(TForm, 'TransparentColorValue', 'VCL compatibility property', '');
end;

procedure TForm.CreateWnd;
begin
  if (Application<>nil) then
    Application.UpdateMainForm(TForm(Self));
  inherited CreateWnd;
end;

procedure TForm.Loaded;
begin
  inherited Loaded;
  FLCLVersion:=lcl_version;
end;

constructor TForm.Create(TheOwner: TComponent);
begin
  FLCLVersion:=lcl_version;
  inherited Create(TheOwner);
end;

{------------------------------------------------------------------------------
  Method: TForm.Cascade
  Params:  None
  Returns: Nothing

  Arranges MDI child forms so they overlap.
  Use Cascade to arrange MDI child forms so they overlap.
  Cascade works only if the form is an MDI parent form (FormStyle=fsMDIForm).
 ------------------------------------------------------------------------------}
procedure TForm.Cascade;
begin
  if (FormStyle <> fsMDIForm) then
    exit;
  if HandleAllocated and not (csDesigning in ComponentState) then
    TWSCustomFormClass(WidgetSetClass).Cascade(Self);
end;

{------------------------------------------------------------------------------
  Method: TForm.Next
  Params:  None
  Returns: Nothing

  Activates the next child MDI form (fsMDIChild) in the form sequence.
  Use Next to change the active child form of an MDI parent.
  If calling of Next comes to the end of count it restarts and activates
  first dsMDIChild in sequence.
  The Next method applies only to forms with FormStyle = fsMDIForm.
 ------------------------------------------------------------------------------}
procedure TForm.Next;
begin
  if (FormStyle <> fsMDIForm) then
    exit;
  if HandleAllocated and not (csDesigning in ComponentState) then
    TWSCustomFormClass(WidgetSetClass).Next(Self);
end;

{------------------------------------------------------------------------------
  Method: TForm.Previous
  Params:  None
  Returns: Nothing
  Activates the previous MDI child form in the form sequence.
  Behaviour is vice-versa of TForm.Next.
  The Previous method can be called only for forms with FormStyle = fsMDIForm
 ------------------------------------------------------------------------------}
procedure TForm.Previous;
begin
  if (FormStyle <> fsMDIForm) then
    exit;
  if HandleAllocated and not (csDesigning in ComponentState) then
    TWSCustomFormClass(WidgetSetClass).Previous(Self);
end;

{------------------------------------------------------------------------------
  Method: TForm.Tile
  Params:  None
  Returns: Nothing

  Arranges MDI child forms so that they are all the same size.
  Use Tile to arrange MDI child forms so that they are all the same size.
  Tiled forms completely fill up the client area of the parent form.
  How the forms arrange themselves depends upon the values of
  their TileMode properties, and it depends on widgetset.
  Tile works only if the form FormStyle = fsMDIForm.
 ------------------------------------------------------------------------------}
procedure TForm.Tile;
begin
  if (FormStyle <> fsMDIForm) then
    exit;
  if HandleAllocated and not (csDesigning in ComponentState) then
    TWSCustomFormClass(WidgetSetClass).Tile(Self);
end;

{------------------------------------------------------------------------------
  Method: TForm.ArrangeIcons
  Params:  None
  Returns: Nothing

  Arranges the minimized MDI icons in an MDI form.
  ArrangeIcons works only if the form FormStyle = fsMDIForm.
 ------------------------------------------------------------------------------}
procedure TForm.ArrangeIcons;
begin
  if (FormStyle <> fsMDIForm) then
    Exit;
  if HandleAllocated and not (csDesigning in ComponentState) then
    TWSCustomFormClass(WidgetSetClass).ArrangeIcons(Self);
end;

//==============================================================================

{ TFormPropertyStorage }

procedure TFormPropertyStorage.FormCreate(Sender: TObject);
begin
  Restore;
end;

procedure TFormPropertyStorage.FormClose(Sender: TObject; var CloseAction: TCloseAction);
begin
  If CloseAction = caFree Then Begin
    Save;
    TCustomForm(Owner).RemoveHandlerOnBeforeDestruction(@FormDestroy);
  end;
end;

procedure TFormPropertyStorage.FormDestroy(Sender: TObject);
begin
  Save;
end;

constructor TFormPropertyStorage.Create(TheOwner: TComponent);
begin
  inherited Create(TheOwner);
  if Owner is TCustomForm then
  begin
    TCustomForm(Owner).AddHandlerCreate(@FormCreate, True);
    TCustomForm(Owner).AddHandlerClose(@FormClose, True);
    TCustomForm(Owner).AddHandlerOnBeforeDestruction(@FormDestroy, True);
  end;
end;

destructor TFormPropertyStorage.Destroy;
begin
  if Owner is TControl then
    TControl(Owner).RemoveAllHandlersOfObject(Self);
  inherited Destroy;
end;

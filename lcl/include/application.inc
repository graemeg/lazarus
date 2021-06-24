{%MainUnit ../forms.pp}
{******************************************************************************
                                   TApplication
 ******************************************************************************

 *****************************************************************************
  This file is part of the Lazarus Component Library (LCL)

  See the file COPYING.modifiedLGPL.txt, included in this distribution,
  for details about the license.
 *****************************************************************************
}

{ $define DebugHintWindow}

function FindApplicationComponent(const ComponentName: string): TComponent;
// Note: this function is used by TReader to auto rename forms to unique names.
begin
  if Application.FindGlobalComponentEnabled then
  begin
    // ignore designer forms (the IDE registers its own functions to handle them)
    Result:=Application.FindComponent(ComponentName);
    if Result=nil then
      Result:=Screen.FindNonDesignerForm(ComponentName);
    if Result=nil then
      Result:=Screen.FindNonDesignerDataModule(ComponentName);
  end
  else
    Result:=nil;
  //debugln('FindApplicationComponent ComponentName="',ComponentName,'" Result=',DbgSName(Result));
end;

function GetControlShortHint(Control: TControl): String;
begin
  Result := '';
  while (Control <> nil) and (Result = '') do
  begin
    Result := GetShortHint(Control.Hint);
    Control := Control.Parent;
  end;
end;

function GetHintControl(Control: TControl): TControl;
begin
  Result := Control;
  while (Result <> nil) and (not Result.ShowHint) do
    Result := Result.Parent;
  if (Result <> nil)and
     ([csDesigning, csDestroying, csLoading] * Result.ComponentState <> []) then
    Result := nil;
end;

function GetHintInfoAt(CursorPos: TPoint): THintInfoAtMouse;
begin
  Result.MousePos := CursorPos;
  Result.Control := GetHintControl(FindControlAtPosition(Result.MousePos, True));
  Result.ControlHasHint := Assigned(Result.Control) and Assigned(Application) and
    Application.ShowHint and (GetCapture = 0) and
   ((GetKeyState(VK_LBUTTON) and $80) = 0) and
   ((GetKeyState(VK_MBUTTON) and $80) = 0) and
   ((GetKeyState(VK_RBUTTON) and $80) = 0);
  if Result.ControlHasHint then
  begin
    // if there is a modal form, then don't show hints for other forms
    if Assigned(Screen.FFocusedForm) and
       (fsModal in Screen.FFocusedForm.FormState) and
       (GetParentForm(Result.Control) <> GetParentForm(Screen.FFocusedForm)) then
      Result.ControlHasHint := False;
  end;
end;

// Callback function for SysUtils.OnGetApplicationName;
function GetApplicationName: string;
begin
  if Assigned(Application) then
    Result := Application.Title
  else
    Result := '';
end;

constructor TApplication.Create(AOwner: TComponent);
begin
  LCLProc.SendApplicationMessageFunction:=@SendApplicationMsg;

  FExceptionDialog := aedOkCancelDialog;
  FShowButtonGlyphs := sbgAlways;
  FShowMenuGlyphs := sbgAlways;
  FMainForm := nil;
  FModalLevel := 0;
  FMouseControl := nil;
  FHintColor := DefHintColor;
  FHintPause := DefHintPause;
  FHintShortCuts := True;
  FHintShortPause := DefHintShortPause;
  FHintHidePause := DefHintHidePause;
  FHintHidePausePerChar := DefHintHidePausePerChar;
  FMoveFormFocusToChildren := True;
  FShowHint := true;
  FShowMainForm := true;
  FRestoreStayOnTop := nil;
  FOnIdle := nil;
  FIcon := TIcon.Create;
  FIcon.OnChange := @IconChanged;
  FLastKeyDownKeys := TWordList.Create;
  FNavigation := [anoTabToSelectNext,anoReturnForDefaultControl,
                  anoEscapeForCancelControl,anoF1ForHelp,anoArrowToSelectNextInParent];
  FUpdateFormatSettings := True;
  ApplicationActionComponent:=Self;
  OnMenuPopupHandler:=@MenuPopupHandler;
  System.InitCriticalSection(FAsyncCall.CritSec);

  FFindGlobalComponentEnabled:=true;
  RegisterFindGlobalComponentProc(@FindApplicationComponent);

  FBidiMode := DefaultApplicationBiDiMode;

  FMainFormOnTaskBar := False;

  inherited Create(AOwner);
  CaptureExceptions:=true;

  AddExitProc(@BeforeFinalization);
  
  OnGetApplicationName := @GetApplicationName;
end;

destructor TApplication.Destroy;
var
  HandlerType: TApplicationHandlerType;
begin
  if Self=nil then
    RaiseGDBException('TApplication.Destroy Self=nil');
  Include(FFlags,AppDestroying);

  if Assigned(FOnDestroy) then FOnDestroy(Self);

  ProcessAsyncCallQueue;

  if OnMenuPopupHandler=@MenuPopupHandler then
    OnMenuPopupHandler:=nil;

  // shutting down
  CancelHint;
  ShowHint := False;

  // destroying
  ApplicationActionComponent:=nil;
  FreeThenNil(FIcon);
  FreeIconHandles;
  FreeThenNil(FLastKeyDownKeys);
  FreeThenNil(FRestoreStayOnTop);

  for HandlerType:=Low(TApplicationHandlerType) to High(TApplicationHandlerType) do
    FreeThenNil(FApplicationHandlers[HandlerType]);

  UnregisterFindGlobalComponentProc(@FindApplicationComponent);

  inherited Destroy;

  Include(FFlags,AppDoNotCallAsyncQueue);
  ProcessAsyncCallQueue;
  System.DoneCriticalSection(FAsyncCall.CritSec);

  // restore exception handling
  CaptureExceptions:=false;
  LCLProc.SendApplicationMessageFunction:=nil;
  OnGetApplicationName := nil;

  if Application=Self then begin
    Assert(CustomApplication=Application, 'TApplication.Destroy: CustomApplication is wrong.');
    Application:=nil;
    CustomApplication:=nil;
  end;
end;

procedure TApplication.ActivateHint(CursorPos: TPoint; CheckHintControlChange: Boolean);
var
  Info: THintInfoAtMouse;
  HintControlChanged: Boolean;
begin
  Info := GetHintInfoAt(CursorPos);

  {$ifdef DebugHintWindow}
    DebugLn('TApplication.DoOnMouseMove Info.ControlHasHint=',dbgs(Info.ControlHasHint),' Type=',dbgs(ord(FHintTimerType)),' FHintControl=',DbgSName(FHintControl),' Info.Control=',DbgSName(Info.Control));
  {$endif}
  HintControlChanged := not CheckHintControlChange or (FHintControl <> Info.Control);
  if Info.ControlHasHint then
  begin
    if HintControlChanged then
    begin
      StopHintTimer;
      HideHint;
      FHintControl := Info.Control;
      FHintRect := FHintControl.BoundsRect;
    end;
    case FHintTimerType of
      ahttNone, ahttHideHint:
        //react only if the hint control changed or if the mouse leave the previously set hint rect
        if HintControlChanged or (not PtInRect(FHintRect, FHintControl.ScreenToClient(Info.MousePos))) then
        begin
          //if a hint is visible immediately query the app to show a new hint...
          if FHintTimerType = ahttHideHint then
            ShowHintWindow(Info);
          //...if there's no hint window visible at this point then schedule a new query
          if (FHintTimerType = ahttNone) or (FHintWindow = nil) or not FHintWindow.Visible then
            StartHintTimer(HintPause, ahttShowHint);
        end;
      ahttShowHint, ahttReshowHint:
        StartHintTimer(HintPause, ahttShowHint);
    end;
  end
  else
    CancelHint;
end;

procedure TApplication.BringToFront;
begin
  WidgetSet.AppBringToFront;
end;

function TApplication.MessageBox(Text, Caption: PChar; Flags: Longint) : Integer;
begin
  if Assigned(MessageBoxFunction) then
    Result:=MessageBoxFunction(Text,Caption,Flags)
  else begin
    DebugLn('WARNING: TApplication.MessageBox: no MessageBoxFunction');
    DebugLn('  Caption="',Caption,'"');
    DebugLn('  Text="',Text,'"');
    DebugLn('  Flags=',DbgS(Flags));
    Result:=0;
  end;
end;

function TApplication.GetExename: String;
Begin
  Result := ParamStrUTF8(0);
end;

function TApplication.GetHandle: THandle;
begin
  Result := WidgetSet.AppHandle;
end;

function TApplication.GetMainFormHandle: HWND;
var
  i: Integer;
begin
  Result := 0;
  if Assigned(OnGetMainFormHandle) then
    OnGetMainFormHandle(Result);
  i := FApplicationHandlers[ahtGetMainFormHandle].Count;
  while (Result = 0) and FApplicationHandlers[ahtGetMainFormHandle].NextDownIndex(i) do
    TGetHandleEvent(FApplicationHandlers[ahtGetMainFormHandle][i])(Result);
  if (Result = 0) and Assigned(MainForm) then
    Result := MainForm.Handle;
end;

{------------------------------------------------------------------------------
       TApplication Notification  "Performs Application Level Operations"
------------------------------------------------------------------------------}
procedure TApplication.Notification(AComponent : TComponent;
  Operation : TOperation);
var
  l: TFPList;
begin
  if Operation = opRemove then begin
    FLastMouseControlValid:=false;
    if AComponent=FMouseControl then
      FMouseControl:=nil;
    if AComponent=FCreatingForm then
      FCreatingForm:=nil;
    if AComponent=FHintWindow then
      FHintWindow:=nil;
    if AComponent=FHintTimer then
      FHintTimer:=nil;
    if FComponentsToRelease<>nil then
      FComponentsToRelease.Remove(AComponent);
    if FComponentsToReleaseSavedByModal<>nil then
      for Pointer(l) in FComponentsToReleaseSavedByModal do
        if l <> nil then
          l.Remove(AComponent);
    if FComponentsReleasing<>nil then
      FComponentsReleasing.Remove(AComponent);
    if FComponentsReleasingSavedByModal<>nil then
      for Pointer(l) in FComponentsReleasingSavedByModal do
        if l <> nil then
          l.Remove(AComponent);
    if AComponent = MainForm then begin
      FMainForm:= nil;
      Terminate;
    end;
  end;
  inherited Notification(AComponent,Operation);
end;

{------------------------------------------------------------------------------
  Method: TApplication.ControlDestroyed
  Params: None
  Returns:  Nothing
 ------------------------------------------------------------------------------}
procedure TApplication.ControlDestroyed(AControl: TControl);
begin
  FLastMouseControlValid:=false;
  if AControl=FMouseControl then FMouseControl:=nil;
  if AControl = MainForm then FMainForm:= nil;
  if AControl = FCreatingForm then FCreatingForm:= nil;
  if Screen.FActiveControl = AControl then Screen.FActiveControl := nil;
  if Screen.FActiveCustomForm = AControl then
  begin
    Screen.FActiveCustomForm := nil;
    Screen.FActiveForm := nil;
  end;
  if Screen.FFocusedForm = AControl then Screen.FFocusedForm := nil;
  if FHintControl = AControl then FHintControl:=nil;
  Screen.UpdateLastActive;
end;

{------------------------------------------------------------------------------
  Method: TApplication.Minimize
  Params: None
  Returns: Nothing

  Minimizes the application.
 ------------------------------------------------------------------------------}
procedure TApplication.Minimize;
begin
  WidgetSet.AppMinimize;
end;

procedure TApplication.ModalStarted;
begin
  inc(FModalLevel);
  if FComponentsToReleaseSavedByModal = nil then
    FComponentsToReleaseSavedByModal := TFPList.Create;
  FComponentsToReleaseSavedByModal.Add(FComponentsToRelease);
  FComponentsToRelease := nil;
  (* If a component calls ShowModal while being destroyed by ReleaseComponents then FComponentsReleasing may be <> nil *)
  if FComponentsReleasingSavedByModal = nil then
    FComponentsReleasingSavedByModal := TFPList.Create;
  FComponentsReleasingSavedByModal.Add(FComponentsReleasing);
  FComponentsReleasing := nil;
  if (FModalLevel = 1) then
  begin
    if Assigned(FOnModalBegin) then
      FOnModalBegin(Self);
    FApplicationHandlers[ahtModalBegin].CallNotifyEvents(Self);
  end;
  RemoveStayOnTop(True);
end;

procedure TApplication.ModalFinished;
var
  l: TFPList;
  c: Pointer;
begin
  dec(FModalLevel);
  RestoreStayOnTop(True);
  if (FModalLevel = 0) then
  begin
    if Assigned(FOnModalEnd) then
      FOnModalEnd(Self);
    FApplicationHandlers[ahtModalEnd].CallNotifyEvents(Self);
  end;
  // Cannot leave modal, while in ReleaseComponents
  assert(FComponentsReleasing = nil, 'TApplication.ModalFinished: FComponentsReleasing = nil');
  assert(FComponentsToReleaseSavedByModal.Count > 0, 'TApplication.ModalFinished: FComponentsToReleaseSavedByModal.Count > 0');
  if FComponentsToReleaseSavedByModal.Count > 0 then begin
    l := TFPList(FComponentsToReleaseSavedByModal[FComponentsToReleaseSavedByModal.Count - 1]);
    FComponentsToReleaseSavedByModal.Delete(FComponentsToReleaseSavedByModal.Count - 1);
    if l <> nil then begin
      if FComponentsToRelease <> nil then begin
        for c in FComponentsToRelease do
          l.Add(c);
        FComponentsToRelease.Free;
      end;
      FComponentsToRelease := l;
    end;
    if FComponentsToRelease <> nil then
      QueueAsyncCall(@FreeComponent, 0);

    l := TFPList(FComponentsReleasingSavedByModal[FComponentsReleasingSavedByModal.Count - 1]);
    FComponentsReleasingSavedByModal.Delete(FComponentsReleasingSavedByModal.Count - 1);
    if l <> nil then begin
      if FComponentsReleasing <> nil then begin
        for c in FComponentsReleasing do
          l.Add(c);
        FComponentsReleasing.Free;
      end;
      FComponentsReleasing := l;
    end;
  end;
  if (FModalLevel = 0) then
  begin
    assert(FComponentsToReleaseSavedByModal.Count = 0, 'TApplication.ModalFinished: FComponentsToReleaseSavedByModal.Count = 0');
    FreeAndNil(FComponentsToReleaseSavedByModal);
    FreeAndNil(FComponentsReleasingSavedByModal);
  end;
end;

{------------------------------------------------------------------------------
  Method: TApplication.Restore
  Params: None
  Returns: Nothing

  Restore minimized application.
 ------------------------------------------------------------------------------}
procedure TApplication.Restore;
begin
  WidgetSet.AppRestore;
end;

{------------------------------------------------------------------------------
  TApplication ProcesssMessages  "Enter the messageloop and process until empty"
------------------------------------------------------------------------------}
procedure TApplication.ProcessMessages;
begin
  if Self=nil then begin
    // when the programmer did a mistake, avoid getting strange errors
    raise Exception.Create('Application=nil');
  end;
  WidgetSet.AppProcessMessages;
  ProcessAsyncCallQueue;
end;

{------------------------------------------------------------------------------
  Method: TApplication.Idle
  Params: Wait: wait till something happens
  Returns:  Nothing

  Invoked when the application enters the idle state
 ------------------------------------------------------------------------------}
procedure TApplication.Idle(Wait: Boolean);
var
  Done: Boolean;
begin
  ReleaseComponents;
  ProcessAsyncCallQueue;

  Done := True;
  if (FIdleLockCount=0) then begin
    if Assigned(FOnIdle) then FOnIdle(Self, Done);
    if Done then
      NotifyIdleHandler(Done);
  end;
  if Done
  then begin
    // wait till something happens
    if (FIdleLockCount=0) then
      DoIdleActions;
    Include(FFlags,AppWaiting);
    Exclude(FFlags,AppIdleEndSent);
    if Wait then
      WidgetSet.AppWaitMessage;
    if (FIdleLockCount=0) then
      DoOnIdleEnd;
    Exclude(FFlags,AppWaiting);
  end;
end;

procedure TApplication.HintMouseMessage(Control : TControl;
  var AMessage : TLMessage);
begin
  // ToDo
end;

{------------------------------------------------------------------------------
       TApplication Initialize
       Makes a call to the component engine to provide any initialization that
       needs to occur.
------------------------------------------------------------------------------}
procedure TApplication.Initialize;
var
  Res: TFPResourceHandle;
begin
  inherited Initialize;
  // interface object and screen
  if (WidgetSet=nil) or (WidgetSet.ClassType = TWidgetSet)
  then begin
    DebugLn('ERROR: ',rsNoWidgetSet);
    raise Exception.Create(rsNoWidgetSet);
  end;
  WidgetSet.AppInit(ScreenInfo);
  ScreenInfo.Initialized := True;
  Screen.UpdateScreen;
  // set that we are initialized => all exceptions will be handled by our HandleException
  include(FFlags, AppInitialized);

  // application icon
  if LazarusResources.Find('MAINICON') <> nil then
    Icon.LoadFromLazarusResource('MAINICON')
  else
  begin
    Res := FindResource(HInstance, PChar('MAINICON'), PChar(RT_GROUP_ICON));
    if Res <> 0 then
      Icon.LoadFromResourceHandle(Hinstance, Res);
  end;
end;

{------------------------------------------------------------------------------
  Method: TApplication.UpdateMouseHint
  Params: None
  Returns:  Nothing

  Handles mouse Idle
 ------------------------------------------------------------------------------}
procedure TApplication.UpdateMouseHint(CurrentControl: TControl);
var
  HintControl: TControl;
begin
  HintControl := GetHintControl(CurrentControl);
  if HintControl = nil then
    Hint := ''
  else
    Hint := GetLongHint(HintControl.Hint);
end;

procedure TApplication.SetCaptureExceptions(const AValue: boolean);
begin
  if FCaptureExceptions=AValue then exit;
  FCaptureExceptions:=AValue;
  if FCaptureExceptions then begin
    // capture exceptions
    // store old exceptproc
    if FOldExceptProc=nil then
      FOldExceptProc:=ExceptProc;
    ExceptProc:=@ExceptionOccurred;
  end else begin
    // do not capture exceptions
    if ExceptProc=@ExceptionOccurred then begin
      // restore old exceptproc
      ExceptProc:=FOldExceptProc;
      FOldExceptProc:=nil;
    end;
  end;
end;

function TApplication.HelpCommand(Command: Word; Data: PtrInt): Boolean;
var
  CallHelp: Boolean;
begin
  CallHelp := True;

  Result := DoOnHelp(Command, Data, CallHelp);

  if Result then
    Exit;

  if CallHelp then
  begin
    // TODO: call help
  end;
end;

function TApplication.GetControlAtMouse: TControl;
var
  P: TPoint;
begin
  GetCursorPos(P);
  //debugln(['TApplication.GetControlAtMouse p=',dbgs(p),' FLastMousePos=',dbgs(FLastMousePos)]);
  if FLastMouseControlValid and (P.X = FLastMousePos.x) and (P.Y = FLastMousePos.Y) then
    Result := FLastMouseControl
  else
    Result := FindControlAtPosition(P, False);
  
  if Assigned(Result) and (csDesigning in Result.ComponentState) then
    Result := nil;
  if Assigned(Result) then
  begin
    FLastMouseControlValid := True;
    FLastMousePos := p;
    FLastMouseControl := Result;
  end;
end;

procedure TApplication.SetBidiMode(const AValue: TBiDiMode) ;
begin
  if AValue <> FBidiMode then
  begin
    FBidiMode := AValue;
    NotifyCustomForms(CM_PARENTBIDIMODECHANGED);
  end;
end;

procedure TApplication.SetFlags(const AValue: TApplicationFlags);
begin
  { Only allow AppNoExceptionMessages to be changed }
  FFlags := Flags - [AppNoExceptionMessages] + AValue*[AppNoExceptionMessages];
end;

procedure TApplication.SetHandle(const AHandle: THandle);
begin
  WidgetSet.AppHandle := AHandle;
end;

procedure TApplication.SetMainFormOnTaskBar(const AValue: Boolean);
begin
  if FMainFormOnTaskBar = AValue then exit;
  FMainFormOnTaskBar := AValue;
  WidgetSet.AppSetMainFormOnTaskBar(FMainFormOnTaskBar);
end;

procedure TApplication.SetNavigation(const AValue: TApplicationNavigationOptions);
begin
  if FNavigation=AValue then exit;
  FNavigation:=AValue;
end;

procedure TApplication.SetShowButtonGlyphs(const AValue: TApplicationShowGlyphs);
begin
  if FShowButtonGlyphs = AValue then
    Exit;
  FShowButtonGlyphs := AValue;
  NotifyCustomForms(CM_APPSHOWBTNGLYPHCHANGED);
end;

procedure TApplication.SetShowMenuGlyphs(const AValue: TApplicationShowGlyphs);
begin
  if FShowMenuGlyphs = AValue then
    Exit;
  FShowMenuGlyphs := AValue;
  NotifyCustomForms(CM_APPSHOWMENUGLYPHCHANGED);
end;

procedure TApplication.SetTaskBarBehavior(const AValue: TTaskBarBehavior);
var
  i: Integer;
  FormToUpdate: TCustomForm;
begin
  if FTaskBarBehavior=AValue then exit;
  FTaskBarBehavior:=AValue;
  for i := 0 to Screen.CustomFormCount-1 do
  begin
    FormToUpdate := Screen.CustomForms[i];
    if FormToUpdate.ShowInTaskBar = stDefault then
      FormToUpdate.UpdateShowInTaskBar;
  end;
end;

procedure TApplication.UpdateMouseControl(NewMouseControl: TControl);
begin
  //debugln(['TApplication.UpdateMouseControl Old=',DbgSName(FMouseControl),' New=',DbgSName(NewMouseControl)]);
  if FMouseControl = NewMouseControl then
    Exit;
  if (FMouseControl <> nil) then
  begin
    //DebugLn' MOUSELEAVE=',FMouseControl.Name,':',FMouseControl.ClassName);
    FMouseControl.Perform(CM_MOUSELEAVE, 0, 0);
  end;
  FMouseControl := NewMouseControl;

  Application.UpdateMouseHint(FMouseControl);

  if (FMouseControl <> nil) then
  begin
    //DebugLn' MOUSEENTER=',FMouseControl.Name,':',FMouseControl.ClassName);
    FMouseControl.Perform(CM_MOUSEENTER, 0, 0);
  end;
end;

{------------------------------------------------------------------------------
  Method: TApplication.SetIcon
  Params: the new icon
 ------------------------------------------------------------------------------}
procedure TApplication.SetIcon(AValue: TIcon);
begin
  FIcon.Assign(AValue);
end;

procedure TApplication.SetShowHint(const AValue: Boolean);
begin
  if FShowHint = AValue then
    exit;
  FShowHint := AValue;
  if FShowHint then
  begin
    //
  end else
  begin
    FreeThenNil(FHintWindow);
  end;
end;

procedure TApplication.SetTitle(const AValue: String);
begin
  inherited SetTitle(AValue);
  WidgetSet.AppSetTitle(GetTitle);
end;

procedure TApplication.StopHintTimer;
begin
  if FHintTimer <> nil then
    FHintTimer.Enabled := False;
end;

function TApplication.ValidateHelpSystem: Boolean;
begin
  Result := HelpManager <> nil;
end;

{------------------------------------------------------------------------------
  procedure TApplication.NotifyIdleHandler(var Done: Boolean);
  
  Done = true will wait for the next message
  Done = false will repeat calling the OnIdle handlers
 ------------------------------------------------------------------------------}
procedure TApplication.NotifyIdleHandler(var Done: Boolean);
var
  i: LongInt;
begin
  i:=FApplicationHandlers[ahtIdle].Count;
  while FApplicationHandlers[ahtIdle].NextDownIndex(i) do begin
    TIdleEvent(FApplicationHandlers[ahtIdle][i])(Self,Done);
    if not Done then exit;
  end;
end;

procedure TApplication.NotifyIdleEndHandler;
begin
  FApplicationHandlers[ahtIdleEnd].CallNotifyEvents(Self);
end;

procedure TApplication.NotifyActivateHandler;
begin
  if Assigned(OnActivate) then OnActivate(Self);
  FApplicationHandlers[ahtActivate].CallNotifyEvents(Self);
end;

procedure TApplication.NotifyDeactivateHandler;
begin
  if Assigned(OnDeactivate) then OnDeactivate(Self);
  FApplicationHandlers[ahtDeactivate].CallNotifyEvents(Self);
end;

procedure TApplication.NotifyCustomForms(Msg: Word);
var
  i: integer;
begin
  for i := 0 to Screen.CustomFormCount - 1 do
    Screen.CustomForms[i].Perform(Msg, 0, 0);
end;

function TApplication.IsHintMsg(var Msg: TMsg): Boolean;
begin
  Result := False;
end;

function TApplication.DoOnHelp(Command: Word; Data: PtrInt; var CallHelp: Boolean): Boolean;
var
  ActiveForm: TCustomForm;
  i: LongInt;
begin
  ActiveForm := Screen.ActiveCustomForm;

  if Assigned(ActiveForm) and Assigned(ActiveForm.FOnHelp) then
    Result := ActiveForm.FOnHelp(Command, Data, CallHelp)
  else
  begin
    if Assigned(FOnHelp) then
      Result := FOnHelp(Command, Data, CallHelp)
    else
      Result := False;
    i := FApplicationHandlers[ahtHelp].Count;
    while not Result and FApplicationHandlers[ahtHelp].NextDownIndex(i) do
      Result := THelpEvent(FApplicationHandlers[ahtHelp][i])(Command, Data, CallHelp);
  end;
end;

procedure TApplication.DoOnMouseMove;
var
  CursorPos: TPoint;
begin
  if GetCursorPos(CursorPos) then
    ActivateHint(CursorPos, True);
end;

procedure TApplication.ShowHintWindow(const Info: THintInfoAtMouse);

  function GetCursorHeightMargin: integer;
  begin
    Result:=25; // To-Do: better height margin (DPI or cursor aware).
  end;

var
  ClientOrigin, ParentOrigin: TPoint;
  HintInfo: THintInfo;
  CanShow: Boolean;
  HintWinRect: TRect;
  CurHeight, WidthAdjust: Integer;
  i: LongInt;
begin
  if not FShowHint or (FHintControl=nil) then
    Exit;

  {$ifdef DebugHintWindow}
    debugln('TApplication.ShowHintWindow A OldHint="',Hint,'" NewHint="',GetShortHint(Info.Control.Hint),'"');
  {$endif}
  
  CurHeight:=GetCursorHeightMargin;
  HintInfo.HintControl := FHintControl;
  HintInfo.HintPos := Info.MousePos;

  // to reduce flicker
  HintInfo.HintPos.X:=HintInfo.HintPos.X and (not $F);
  HintInfo.HintPos.Y:=HintInfo.HintPos.Y and (not $F);

  Inc(HintInfo.HintPos.Y, CurHeight);
  HintInfo.HintMaxWidth := Screen.Width;
  HintInfo.HintColor := FHintColor;
  HintInfo.CursorRect := FHintControl.BoundsRect;
  ClientOrigin := FHintControl.ClientOrigin;
  ParentOrigin.X := 0;
  ParentOrigin.Y := 0;
  if FHintControl.Parent <> nil then
    ParentOrigin := FHintControl.Parent.ClientOrigin;
  OffsetRect(HintInfo.CursorRect, ParentOrigin.X - ClientOrigin.X,
    ParentOrigin.Y - ClientOrigin.Y);
  HintInfo.CursorPos := FHintControl.ScreenToClient(Info.MousePos);
  HintInfo.HintStr := GetControlShortHint(Info.Control);
  HintInfo.ReshowTimeout := 0;
  HintInfo.HideTimeout := FHintHidePause
                          +FHintHidePausePerChar*length(HintInfo.HintStr);
  HintInfo.HintWindowClass := HintWindowClass;
  HintInfo.HintData := nil;
  CanShow := FHintControl.Perform(CM_HINTSHOW, 0, LParam(PtrUInt(@HintInfo))) = 0;
  if (HintInfo.HintWindowClass=nil)
  or (not HintInfo.HintWindowClass.InheritsFrom(THintWindow)) then
    HintInfo.HintWindowClass := HintWindowClass;

  if CanShow then begin
    if Assigned(FOnShowHint) then
      FOnShowHint(HintInfo.HintStr, CanShow, HintInfo);
    i:=FApplicationHandlers[ahtShowHint].Count;
    while FApplicationHandlers[ahtShowHint].NextDownIndex(i) do
      TShowHintEvent(FApplicationHandlers[ahtShowHint][i])(HintInfo.HintStr, CanShow, HintInfo);
  end;
  if CanShow and (FHintControl <> nil) and (HintInfo.HintStr <> '') then
  begin
    // create hint window
    if (FHintWindow<>nil) and (FHintWindow.ClassType<>HintInfo.HintWindowClass)
    then
      FreeThenNil(FHintWindow);
    if FHintWindow=nil then
    begin
      FHintWindow:=THintWindowClass(HintInfo.HintWindowClass).Create(Self);
      with FHintWindow do
      begin
        Visible := False;
        Caption := '';
        AutoHide := False;
      end;
    end;

    // make the hint have the same BiDiMode as the activating control
    FHintWindow.BiDiMode := FHintControl.BiDiMode;
    // calculate the width of the hint based on HintStr and MaxWidth
    FHintWindow.Left := HintInfo.HintPos.X;
    FHintWindow.Top := HintInfo.HintPos.Y;
    with HintInfo do
      HintWinRect := FHintWindow.CalcHintRect(HintMaxWidth, HintStr, HintData);
    //Position HintWindow depending on LTR/RTL
    if FHintWindow.UseRightToLeftAlignment then
      WidthAdjust := HintWinRect.Right - HintWinRect.Left
    else
      WidthAdjust := 0;
    OffsetRect(HintWinRect, HintInfo.HintPos.X - WidthAdjust, HintInfo.HintPos.Y);
    //DebugLn(['TApplication.ShowHintWindow HintStr="',HintInfo.HintStr,'" HintWinRect=',dbgs(HintWinRect)]);

    FHintWindow.Color := HintInfo.HintColor;
    //DebugLn(['TApplication.ShowHintWindow FHintWindow.Color=',dbgs(FHintWindow.Color),' HintInfo.HintColor=',dbgs(HintInfo.HintColor)]);

    FHintWindow.ActivateHint(HintWinRect, HintInfo.HintStr);
    FHintRect := HintInfo.CursorRect;
    // start hide timer
    if HintInfo.ReshowTimeout>0 then
      StartHintTimer(HintInfo.ReshowTimeout,ahttReshowHint)
    else
      StartHintTimer(HintInfo.HideTimeout,ahttHideHint);
  end
  else
    HideHint;

  {$ifdef DebugHintWindow}
    DebugLn(['TApplication.ShowHintWindow Info.ControlHasHint=',
      Info.ControlHasHint, ' Type=', ord(FHintTimerType)]);
  {$endif}
end;

procedure TApplication.StartHintTimer(Interval: integer;
  TimerType: TAppHintTimerType);
begin
  {$ifdef DebugHintWindow}
    debugln('TApplication.StartHintTimer ',dbgs(Interval));
  {$endif}
  StopHintTimer;
  FHintTimerType := TimerType;
  if Interval > 0 then
  begin
    if FHintTimer = nil then
      FHintTimer := TCustomTimer.Create(Self);
    FHintTimer.Interval := Interval;
    FHintTimer.OnTimer := @OnHintTimer;
    FHintTimer.Enabled := True;
  end
  else
    OnHintTimer(Self);
end;

procedure TApplication.OnHintTimer(Sender: TObject);
var
  Info: THintInfoAtMouse;
  CursorPos: TPoint;
begin
  {$ifdef DebugHintWindow}
    DebugLn('TApplication.OnHintTimer Type=', IntToStr(ord(FHintTimerType)));
  {$endif}
  StopHintTimer;
  case FHintTimerType of
    ahttShowHint,ahttReshowHint:
      begin
        if not GetCursorPos(CursorPos) then
          HideHint
        else
        begin
          Info := GetHintInfoAt(CursorPos);
          if Info.ControlHasHint then
            ShowHintWindow(Info)
          else
            HideHint;
        end;
      end;
    ahttHideHint:
      begin
        HideHint;
        FHintTimerType := ahttNone;
      end
    else
      HideHint;
  end;
end;

procedure TApplication.UpdateVisible;

  function AppUseSingleButton: Boolean;
  begin
    Result := (TaskBarBehavior = tbSingleButton)
      or ((TaskBarBehavior = tbDefault)
      and (WidgetSet.GetLCLCapability(lcNeedMininimizeAppWithMainForm) = LCL_CAPABILITY_YES));
  end;

  function UseAppTaskbarItem(AForm: TCustomForm): Boolean; inline;
  begin
    Result := (AForm = MainForm) or (AForm.ShowInTaskBar = stNever)
      or ((AForm.ShowInTaskBar = stDefault) and AppUseSingleButton);
  end;

  function HasVisibleForms: Boolean;
  var
    i: integer;
    AForm: TCustomForm;
  begin
    Result := False;
    // How to count correctly? Do we need to count TCustomForms exclude THintWindow
    // or just count TForm descendants?
    for i := 0 to Screen.FormCount - 1 do
    begin
      AForm := Screen.Forms[i];
      if (AForm.Parent = nil)
      and AForm.Showing  // check showing (not Visible)
      and (not (csDestroyingHandle in AForm.ControlState))
      and UseAppTaskbarItem(AForm) then
      begin
        Result := True;
        break;
      end;
    end;
  end;

begin
  // If there are visible forms which share application taskbar item then
  // application task bar item must be visible, too. Otherwise hide it.
  WidgetSet.AppSetVisible(HasVisibleForms);
end;

procedure TApplication.DoIdleActions;
var
  i: Integer;
  CurForm: TCustomForm;
begin
  i := 0;
  while i < Screen.CustomFormCount do begin { While loop to allow number of forms to change during loop }
    CurForm:=Screen.CustomForms[i];
    if CurForm.HandleAllocated and CurForm.Visible and CurForm.Enabled then
      CurForm.UpdateActions;
    Inc(i);
  end;
  // hide splashscreen(s)
  i := Screen.CustomFormCount-1;
  while i >=0 do begin { While loop to allow number of forms to change during loop }
    CurForm:=Screen.CustomForms[i];
    if CurForm.FormStyle=fsSplash then
      CurForm.Hide;
    i:=Min(i,Screen.CustomFormCount)-1;
  end;
end;

procedure TApplication.MenuPopupHandler(Sender: TObject);
begin
  HideHint;
end;

{------------------------------------------------------------------------------
  Method: TApplication.ProcessAsyncCallQueue

  Call all methods queued to be called (QueueAsyncCall)
 ------------------------------------------------------------------------------}
procedure TApplication.ProcessAsyncCallQueue;
var
  lItem: PAsyncCallQueueItem;
  Event: TDataEvent;
  Data: PtrInt;
begin
  with FAsyncCall do begin
    // move the items of NextQueue to CurQueue, keep the order
    System.EnterCriticalsection(CritSec);
    try
      if Next.Top<>nil then
      begin
        if Cur.Last<>nil then
        begin
          assert(Cur.Top <> nil, 'TApplication.ProcessAsyncCallQueue: Last entry found, while Top not assigned');
          Cur.Last^.NextItem:=Next.Top;
          Next.Top^.PrevItem:=Cur.Last;
        end else begin
          assert(Cur.Top = nil, 'TApplication.ProcessAsyncCallQueue: Last entry found, while Top not assigned');
          Cur.Top:=Next.Top;
        end;
        Cur.Last:=Next.Last;
        Next.Top:=nil;
        Next.Last:=nil;
      end;
    finally
      System.LeaveCriticalsection(CritSec);
    end;

    // process items from top to last in 'Cur' queue
    // this can create new items, which are added to the 'Next' queue
    // or it can call ProcessAsyncCallQueue, for example via calling
    // Application.ProcesssMessages
    // Using a second queue avoids an endless loop, when an event adds a new event.
    repeat
      // remove top item from queue
      System.EnterCriticalSection(CritSec);
      try
        if Cur.Top=nil then exit;
        lItem:=Cur.Top;
        Cur.Top := lItem^.NextItem;
        if Cur.Top = nil then
          Cur.Last := nil
        else
          Cur.Top^.PrevItem := nil;
        // free item
        Event:=lItem^.Method;
        Data:=lItem^.Data;
        Dispose(lItem);
      finally
        System.LeaveCriticalSection(CritSec);
      end;
      // call event
      Event(Data);
    until false;
  end;
end;

procedure TApplication.DoBeforeFinalization;
var
  i: Integer;
begin
  if Self=nil then exit;
  for i := ComponentCount - 1 downto 0 do 
  begin
    // DebugLn('TApplication.DoBeforeFinalization ',DbgSName(Components[i]));
    if i < ComponentCount then 
      Components[i].Free;
  end;
end;

function TApplication.GetParams(Index: Integer): string;
begin
  Result:=ParamStrUTF8(Index);
end;

procedure TApplication.IconChanged(Sender: TObject);
var
  i: integer;
  CurForm: TCustomForm;
begin
  FreeIconHandles;
  Widgetset.AppSetIcon(SmallIconHandle, BigIconHandle);

  i := Screen.CustomFormCount-1;
  while i >=0 do begin { While loop to allow number of forms to change during loop }
    CurForm:=Screen.CustomForms[i];
    CurForm.Perform(CM_ICONCHANGED, 0, 0);
    i:=Min(i,Screen.CustomFormCount)-1;
  end;
end;

{------------------------------------------------------------------------------
  Method: TApplication.SmallIconHandle
  Returns: handle of application icon
 ------------------------------------------------------------------------------}
function TApplication.SmallIconHandle: HIcon;
begin
  if not Icon.Empty then
  begin
    if FSmallIconHandle = 0 then
    begin
      Icon.OnChange := nil;
      Icon.Current := Icon.GetBestIndexForSize(Size(GetSystemMetrics(SM_CXSMICON), GetSystemMetrics(SM_CYSMICON)));
      FSmallIconHandle := Icon.ReleaseHandle;
      Icon.OnChange := @IconChanged;
    end;
    Result := FSmallIconHandle;
  end
  else
    Result := 0;
end;

{------------------------------------------------------------------------------
  Method: TApplication.BigIconHandle
  Returns: handle of application icon
 ------------------------------------------------------------------------------}
function TApplication.BigIconHandle: HIcon;
begin
  if not Icon.Empty then
  begin
    if FBigIconHandle = 0 then
    begin
      Icon.OnChange := nil;
      Icon.Current := Icon.GetBestIndexForSize(Size(GetSystemMetrics(SM_CXICON), GetSystemMetrics(SM_CYICON)));
      FBigIconHandle := Icon.ReleaseHandle;
      Icon.OnChange := @IconChanged;
    end;
    Result := FBigIconHandle;
  end
  else
    Result := 0;
end;

{------------------------------------------------------------------------------
  Method: TApplication.GetTitle
  Returns: title of application
 ------------------------------------------------------------------------------}
function TApplication.GetTitle: string;
begin
  Result := inherited Title;
  if Result = '' then
    Result := ExtractFileNameOnly(GetExeName);
end;

procedure TApplication.FreeIconHandles;
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
  Method: TApplication.HandleException
  Params: Sender
  Returns:  Nothing
 ------------------------------------------------------------------------------}
procedure TApplication.HandleException(Sender: TObject);
  procedure ShowInvalidException(ExObject: TObject; ExAddr: Pointer);
  // use shortstring. On exception, the heap may be corrupt.
  var
    Buf: ShortString;
  begin
    if Assigned(SysUtils.OnShowException) then
    begin
      SetLength(Buf,ExceptionErrorMessage(ExObject,ExAddr,@Buf[1],255));
      SysUtils.OnShowException(Buf);
    end;
  end;

var
  i: LongInt;
  Skip: Boolean;
begin
  if Self = nil then
    Exit;
  if FExceptionCounter>1 then
  begin
    // multiple exception circle, just exit
    Exit;
  end;
  if FExceptionCounter=1 then
  begin
    // there was an exception during showing the exception -> break the circle
    Inc(FExceptionCounter);
    if ExceptObject is Exception then
    begin
      if Assigned(OnCircularException) then
        OnCircularException(Sender, Exception(ExceptObject));
    end else
      ShowInvalidException(ExceptObject, ExceptAddr);

    HaltingProgram:=true;
    Halt;
  end;
  Inc(FExceptionCounter);
  
  if StopOnException then
    inherited Terminate;

  Skip := ExceptObject is EAbort;

  // release capture and hide all forms with stay on top, so that
  // a message can be shown
  if GetCapture <> 0 then SendMessage(GetCapture, LM_CANCELMODE, 0, 0);
  if not Skip then
    RemoveStayOnTop(True);
  // handle the exception
  if ExceptObject is Exception then
  begin
    if not Skip then
    begin
      i := FApplicationHandlers[ahtException].Count;
      if Assigned(OnException) or (i > 0) then
      begin
        if Assigned(OnException) then
          OnException(Sender, Exception(ExceptObject));
        while FApplicationHandlers[ahtException].NextDownIndex(i) do
          TExceptionEvent(FApplicationHandlers[ahtException][i])(Sender, Exception(ExceptObject));
      end
      else
        ShowException(Exception(ExceptObject));
    end;
  end
  else
    ShowInvalidException(ExceptObject, ExceptAddr);
  if not Skip then
    RestoreStayOnTop(True);
  Dec(FExceptionCounter);
end;

{------------------------------------------------------------------------------
  Method: TApplication.HandleMessage
  Params: None
  Returns:  Nothing

  Handles all messages first then the Idle
 ------------------------------------------------------------------------------}
procedure TApplication.HandleMessage;
begin
  WidgetSet.AppProcessMessages; // process all events
  if not Terminated then Idle(true);
end;

function TApplication.HelpContext(Context: THelpContext): Boolean;
var
  CallHelp: Boolean;
begin
  CallHelp := True;
  Result := DoOnHelp(HELP_CONTEXT, Context, CallHelp);
  if not CallHelp then
    Exit;
  if ValidateHelpSystem then
    Result := ShowHelpOrErrorForContext('', Context) = shrSuccess
  else
    Result := False;
end;

function TApplication.HelpKeyword(const Keyword: String): Boolean;
var
  CallHelp: Boolean;
begin
  CallHelp := True;
  Result := DoOnHelp(HELP_COMMAND, PtrInt(PChar(Keyword)), CallHelp);
  if not CallHelp then
    Exit;
  if ValidateHelpSystem then
    Result := ShowHelpOrErrorForKeyword('', Keyword) = shrSuccess
  else
    Result := False;
end;

procedure TApplication.ShowHelpForObject(Sender: TObject);
begin
  if Sender is TControl then
    TControl(Sender).ShowHelp;
end;

procedure TApplication.RemoveStayOnTop(const ASystemTopAlso: Boolean = False);
var
  i: Integer;
  AForm: TCustomForm;
begin
  if WidgetSet.AppRemoveStayOnTopFlags(ASystemTopAlso) then
    Exit;
  if Screen = nil then
    Exit;
  Inc(FRemoveStayOnTopCounter);
  for i := 0 to Screen.CustomFormCount - 1 do
  begin
    AForm := Screen.CustomForms[i];
    if (AForm.Parent <> nil) or not AForm.Visible then
      Continue;
    if (AForm.FormStyle in fsAllNonSystemStayOnTop) then
    begin
      AForm.FormStyle := fsNormal;
      if FRestoreStayOnTop = nil then
        FRestoreStayOnTop := TList.Create;
      if FRestoreStayOnTop.IndexOf(AForm) = -1 then
        FRestoreStayOnTop.Add(AForm);
    end;
  end;
end;

procedure TApplication.RestoreStayOnTop(const ASystemTopAlso: Boolean = False);
var
  i: integer;
begin
  if WidgetSet.AppRestoreStayOnTopFlags(ASystemTopAlso) then
    Exit;
  Dec(FRemoveStayOnTopCounter);
  if (FRestoreStayOnTop <> nil) and (FRemoveStayOnTopCounter = 0) then
    for i := FRestoreStayOnTop.Count - 1 downto 0 do
    begin
      TCustomForm(FRestoreStayOnTop[i]).FormStyle := fsStayOnTop;
      FRestoreStayOnTop.Delete(i);
    end;
end;

function TApplication.IsWaiting: boolean;
begin
  Result:=AppWaiting in FFlags;
end;

procedure TApplication.CancelHint;
begin
  StopHintTimer;
  HideHint;
  FHintControl := nil;
  FHintTimerType := ahttNone;
end;

procedure TApplication.HideHint;
begin
  if FHintWindow <> nil then
    FHintWindow.Visible := False;
  FHintControl := nil;
  FHintRect := Rect(0,0,0,0);
end;

{------------------------------------------------------------------------------
  TApplication Run
  MainForm is loaded and control is passed to event processor.
------------------------------------------------------------------------------}
procedure TApplication.Run;
begin
  if (FMainForm <> nil) and FShowMainForm then FMainForm.Show;
  WidgetSet.AppRun(@RunLoop);
end;

{------------------------------------------------------------------------------
  TApplication RunLoop
  control is passed to event processor.
------------------------------------------------------------------------------}
procedure TApplication.RunLoop;
begin
  repeat
    if CaptureExceptions then
      try // run with try..except
        HandleMessage;
      except
        HandleException(Self);
      end
    else
      HandleMessage; // run without try..except
  until Terminated;
end;

procedure TApplication.Activate(Data: PtrInt);
begin
  if AppActive in FFlags then exit;
  Include(FFlags, AppActive);
  NotifyActivateHandler;
end;

procedure TApplication.Deactivate(Data: PtrInt);
  procedure HideHintWindows;
  var
    I: Integer;
    Form: TCustomForm;
  begin
    for I := Screen.CustomFormCount-1 downto 0 do
    begin
      Form := Screen.CustomForms[I];
      if Form.Visible and (Form is THintWindow) then
        Form.Hide;
    end;
  end;
begin
  if (AppDestroying in FFlags) or (not (AppActive in FFlags)) then Exit;

  // widgetset has passed deactivate or no control
  // of this application has got the focus.
  // Force=True means that IntfAppDeactivate called us
  if Data = 1 then //TODO: or not Assigned(FindControl(GetFocus)) then
  begin
    Exclude(FFlags, AppActive);
    NotifyDeactivateHandler;
    HideHintWindows;
  end;
end;

procedure TApplication.WndProc(var AMessage : TLMessage);
begin
  case AMessage.Msg of
    CM_ACTIONEXECUTE, CM_ACTIONUPDATE: AMessage.Result := LResult(DispatchAction(AMessage.Msg, TBasicAction(AMessage.LParam)));
  else
    Dispatch(AMessage);
  end;
end;

function TApplication.DispatchAction(Msg: Longint; Action: TBasicAction): Boolean;
var
  Form: TCustomForm;
begin
  Form := Screen.ActiveForm;
  Result := ((Form <> nil) and (Form.Perform(Msg, 0, PtrInt(Action)) = 1)) or
            ((MainForm <> Form) and (MainForm <> nil) and (MainForm.Perform(Msg, 0, PtrInt(Action)) = 1));
  // Disable action if no "user" handler is available
  if (not Result) and (Action is TCustomAction) and
     TCustomAction(Action).Enabled and TCustomAction(Action).DisableIfNoHandler then
    TCustomAction(Action).Enabled := Assigned(Action.OnExecute);
end;

procedure TApplication.AddHandler(HandlerType: TApplicationHandlerType;
  const Handler: TMethod; AsFirst: Boolean);
begin
  if Handler.Code=nil then RaiseGDBException('TApplication.AddHandler');
  if FApplicationHandlers[HandlerType]=nil then
    FApplicationHandlers[HandlerType]:=TMethodList.Create;
  FApplicationHandlers[HandlerType].Add(Handler,not AsFirst);
end;

procedure TApplication.RemoveHandler(HandlerType: TApplicationHandlerType;
  const Handler: TMethod);
begin
  FApplicationHandlers[HandlerType].Remove(Handler);
end;

function TApplication.GetConsoleApplication: boolean;
begin
  Result:=false;
end;

procedure TApplication.SetHint(const AValue: string);
begin
  if FHint = AValue then
    Exit;
  FHint := AValue;
  if Assigned(FOnHint) or (FApplicationHandlers[ahtHint].Count > 0) then
  begin
    if Assigned(FOnHint) then
      FOnHint(Self);
    FApplicationHandlers[ahtHint].CallNotifyEvents(Self);
  end else
  begin
    // Send THintAction
    with TCustomHintAction.Create(Self) do
    begin
      Hint := FHint;
      try
        Execute;
      finally
        Free;
      end;
    end;
  end;
end;

procedure TApplication.SetHintColor(const AValue: TColor);
begin
  if FHintColor = AValue then
    exit;
  FHintColor := AValue;
  if FHintWindow <> nil then
    FHintWindow.Color := FHintColor;
end;

procedure TApplication.DoOnIdleEnd;
begin
  if (AppIdleEndSent in FFlags) then exit;
  if Assigned(OnIdleEnd) then OnIdleEnd(Self);
  NotifyIdleEndHandler;
  Include(FFlags,AppIdleEndSent);
end;

function TApplication.GetActive: boolean;
begin
  Result := AppActive in Flags;
end;

function TApplication.GetCurrentHelpFile: string;
var
  ActiveForm: TCustomForm;
begin
  ActiveForm := Screen.ActiveCustomForm;
  if Assigned(ActiveForm) and (ActiveForm.FHelpFile <> '') then
    Result := ActiveForm.HelpFile
  else
    Result := HelpFile;
end;

procedure TApplication.ShowException(E: Exception);
var
  Msg: string;
  MsgResult: Integer;
begin
  if AppNoExceptionMessages in FFlags then exit;
  Msg := E.Message;
  if FindInvalidUTF8Codepoint(PChar(Msg), Length(Msg)) > 0 then
    Msg := AnsiToUtf8(Msg);
  if (Msg <> '') and (Msg[length(Msg)] <> '.') then Msg := Msg + '.';
  if (not Terminated) and (Self <> nil) and (AppInitialized in FFlags) then
  begin
    DisableIdleHandler;
    try
      if ExceptionDialog=aedOkMessageBox then
      begin
        MsgResult:=PromptUser(GetTitle, msg,
          idDialogError, [idButtonOk], 0, idButtonCancel);
      end else
        MsgResult:=PromptUser(GetTitle,
          Format(rsPressOkToIgnoreAndRiskDataCorruptionPressAbortToK,
                 [Msg, LineEnding+LineEnding, LineEnding]),
          idDialogError, [idButtonOk, idButtonAbort], 0, idButtonCancel);
    finally
      EnableIdleHandler;
    end;
    if MsgResult=idButtonAbort then
    begin
      Include(FFlags, AppNoExceptionMessages);
      HaltingProgram := True;
      Halt;
    end;
  end else
    inherited ShowException(E);
end;

{------------------------------------------------------------------------------
       TApplication Terminate
       Class is terminated and the component engine is shutdown
------------------------------------------------------------------------------}
procedure TApplication.Terminate;
begin
  inherited Terminate;
  WidgetSet.AppTerminate;
end;

procedure TApplication.DisableIdleHandler;
begin
  inc(FIdleLockCount);
end;

procedure TApplication.EnableIdleHandler;
begin
  if FIdleLockCount<=0 then
    RaiseGDBException('TApplication.EnableIdleHandler');
  dec(FIdleLockCount);
end;

procedure TApplication.NotifyUserInputHandler(Sender: TObject; Msg: Cardinal);
var
  i: integer;
begin
  FLastMouseControlValid := False;
  case Msg of
    LM_MOUSEMOVE:
      DoOnMouseMove;
    else
      CancelHint;
  end;

  if not Assigned(Sender) then
    Sender := Self;

  if Assigned(FOnUserInput) then
    FOnUserInput(Sender, Msg);

  i := FApplicationHandlers[ahtUserInput].Count;
  while FApplicationHandlers[ahtUserInput].NextDownIndex(i) do
    TOnUserInputEvent(FApplicationHandlers[ahtUserInput][i])(Sender, Msg);
end;

procedure TApplication.NotifyKeyDownBeforeHandler(Sender: TObject;
  var Key: Word; Shift: TShiftState);
var
  i: Integer;
begin
  i:=FApplicationHandlers[ahtKeyDownBefore].Count;
  while FApplicationHandlers[ahtKeyDownBefore].NextDownIndex(i) do
    TKeyEvent(FApplicationHandlers[ahtKeyDownBefore][i])(Sender,Key,Shift);
end;

procedure TApplication.NotifyKeyDownHandler(Sender: TObject;
  var Key: Word; Shift: TShiftState);
var
  i: Integer;
begin
  i := FApplicationHandlers[ahtKeyDownAfter].Count;
  while FApplicationHandlers[ahtKeyDownAfter].NextDownIndex(i) do
    TKeyEvent(FApplicationHandlers[ahtKeyDownAfter][i])(Sender, Key, Shift);
  if WidgetSet.IsHelpKey(Key, Shift) and
     (Widgetset.GetLCLCapability(lcLMHelpSupport) = LCL_CAPABILITY_NO) then
    ShowHelpForObject(Sender);
end;

procedure TApplication.ControlKeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
var
  AControl: TWinControl;
begin
  if Sender is TWinControl then
  begin
    AControl := TWinControl(Sender);
    //debugln('TApplication.ControlKeyDown A ',DbgSName(AControl));
    if FLastKeyDownSender <> AControl then
      FLastKeyDownKeys.Clear;
    FLastKeyDownSender := AControl;

    // handle navigation key
    DoTabKey(AControl, Key, Shift);
    DoArrowKey(AControl, Key, Shift);
  end
  else
  begin
    if FLastKeyDownSender <> nil then
      FLastKeyDownKeys.Clear;
    FLastKeyDownSender := nil;
  end;
  //DebugLn(['TApplication.ControlKeyDown Sender=',DbgSName(Sender),' Key=',Key,' Shift=',dbgs(Shift)]);
  FLastKeyDownShift := Shift;
  if FLastKeyDownShift <> Shift then
    FLastKeyDownKeys.Clear;
  FLastKeyDownKeys.Add(Key);
end;

procedure TApplication.ControlKeyUp(Sender: TObject; var Key: Word;
  Shift: TShiftState);
var
  AControl: TWinControl;
  AIndex: Integer;
  AKey: Word;
begin
  if Key = VK_UNKNOWN then exit;

  AKey := Key;

  try
    if Sender is TWinControl then
    begin
      AControl := TWinControl(Sender);
      //debugln('TApplication.ControlKeyUp A ',DbgSName(AControl),' Key=',dbgs(Key),' Shift=',dbgs(Shift));

      AIndex := FLastKeyDownKeys.IndexOf(Key);
      if (AIndex = -1) and (FLastKeyDownKeys.Count > 0) then
        FLastKeyDownKeys.Clear;

      if FLastKeyDownKeys.Count = 0 then
      begin
        // key was already handled in key down
        //debugln('TApplication.ControlKeyUp key was handled in key down');
        Exit;
      end;

      if (Shift <> FLastKeyDownShift) or (AControl <> FLastKeyDownSender) then
      begin
        FLastKeyDownKeys.Clear;
        //debugln('TApplication.ControlKeyUp key was handled in key down or in key up');
        Exit;
      end;

      // handle special navigation keys
      DoReturnKey(AControl, Key, Shift);
      DoEscapeKey(AControl, Key, Shift);
    end;
  finally
    AIndex := FLastKeyDownKeys.IndexOf(AKey);
    if AIndex <> -1 then
      FLastKeyDownKeys.Delete(AIndex);
  end;
end;

procedure TApplication.AddOnIdleHandler(Handler: TIdleEvent;
  AsFirst: Boolean);
begin
  AddHandler(ahtIdle,TMethod(Handler),AsFirst);
end;

procedure TApplication.RemoveOnIdleHandler(Handler: TIdleEvent);
begin
  RemoveHandler(ahtIdle,TMethod(Handler));
end;

procedure TApplication.AddOnIdleEndHandler(Handler: TNotifyEvent;
  AsFirst: Boolean);
begin
  AddHandler(ahtIdleEnd,TMethod(Handler),AsFirst);
end;

procedure TApplication.RemoveOnIdleEndHandler(Handler: TNotifyEvent);
begin
  RemoveHandler(ahtIdleEnd,TMethod(Handler));
end;

procedure TApplication.AddOnUserInputHandler(Handler: TOnUserInputEvent;
  AsFirst: Boolean);
begin
  AddHandler(ahtUserInput,TMethod(Handler),AsFirst);
end;

procedure TApplication.RemoveOnUserInputHandler(Handler: TOnUserInputEvent);
begin
  RemoveHandler(ahtUserInput,TMethod(Handler));
end;

procedure TApplication.AddOnKeyDownBeforeHandler(Handler: TKeyEvent;
  AsFirst: Boolean);
begin
  AddHandler(ahtKeyDownBefore,TMethod(Handler),AsFirst);
end;

procedure TApplication.RemoveOnKeyDownBeforeHandler(Handler: TKeyEvent);
begin
  RemoveHandler(ahtKeyDownBefore,TMethod(Handler));
end;

procedure TApplication.AddOnKeyDownHandler(Handler: TKeyEvent; AsFirst: Boolean);
begin
  AddHandler(ahtKeyDownAfter,TMethod(Handler),AsFirst);
end;

procedure TApplication.RemoveOnKeyDownHandler(Handler: TKeyEvent);
begin
  RemoveHandler(ahtKeyDownAfter,TMethod(Handler));
end;

procedure TApplication.AddOnActivateHandler(Handler: TNotifyEvent;
  AsFirst: Boolean);
begin
  AddHandler(ahtActivate,TMethod(Handler),AsFirst);
end;

procedure TApplication.RemoveOnActivateHandler(Handler: TNotifyEvent);
begin
  RemoveHandler(ahtActivate,TMethod(Handler));
end;

procedure TApplication.AddOnDeactivateHandler(Handler: TNotifyEvent;
  AsFirst: Boolean);
begin
  AddHandler(ahtDeactivate,TMethod(Handler),AsFirst);
end;

procedure TApplication.RemoveOnDeactivateHandler(Handler: TNotifyEvent);
begin
  RemoveHandler(ahtDeactivate,TMethod(Handler));
end;

procedure TApplication.AddOnExceptionHandler(Handler: TExceptionEvent;
  AsFirst: Boolean);
begin
  AddHandler(ahtException,TMethod(Handler),AsFirst);
end;

procedure TApplication.RemoveOnExceptionHandler(Handler: TExceptionEvent);
begin
  RemoveHandler(ahtException,TMethod(Handler));
end;

procedure TApplication.AddOnEndSessionHandler(Handler: TNotifyEvent;
  AsFirst: Boolean);
begin
  AddHandler(ahtEndSession,TMethod(Handler),AsFirst);
end;

procedure TApplication.RemoveOnEndSessionHandler(Handler: TNotifyEvent);
begin
  RemoveHandler(ahtEndSession,TMethod(Handler));
end;

procedure TApplication.AddOnQueryEndSessionHandler(
  Handler: TQueryEndSessionEvent; AsFirst: Boolean);
begin
  AddHandler(ahtQueryEndSession,TMethod(Handler),AsFirst);
end;

procedure TApplication.RemoveOnQueryEndSessionHandler(
  Handler: TQueryEndSessionEvent);
begin
  RemoveHandler(ahtQueryEndSession,TMethod(Handler));
end;

procedure TApplication.AddOnMinimizeHandler(Handler: TNotifyEvent;
  AsFirst: Boolean);
begin
  AddHandler(ahtMinimize,TMethod(Handler),AsFirst);
end;

procedure TApplication.RemoveOnMinimizeHandler(Handler: TNotifyEvent);
begin
  RemoveHandler(ahtMinimize,TMethod(Handler));
end;

procedure TApplication.AddOnModalBeginHandler(Handler: TNotifyEvent;
  AsFirst: Boolean);
begin
  AddHandler(ahtModalBegin,TMethod(Handler),AsFirst);
end;

procedure TApplication.RemoveOnModalBeginHandler(Handler: TNotifyEvent);
begin
  RemoveHandler(ahtModalBegin,TMethod(Handler));
end;

procedure TApplication.AddOnModalEndHandler(Handler: TNotifyEvent;
  AsFirst: Boolean);
begin
  AddHandler(ahtModalEnd,TMethod(Handler),AsFirst);
end;

procedure TApplication.RemoveOnModalEndHandler(Handler: TNotifyEvent);
begin
  RemoveHandler(ahtModalEnd,TMethod(Handler));
end;

procedure TApplication.AddOnRestoreHandler(Handler: TNotifyEvent;
  AsFirst: Boolean);
begin
  AddHandler(ahtRestore,TMethod(Handler),AsFirst);
end;

procedure TApplication.RemoveOnRestoreHandler(Handler: TNotifyEvent);
begin
  RemoveHandler(ahtRestore,TMethod(Handler));
end;

procedure TApplication.AddOnDropFilesHandler(Handler: TDropFilesEvent;
  AsFirst: Boolean);
begin
  AddHandler(ahtDropFiles,TMethod(Handler),AsFirst);
end;

procedure TApplication.RemoveOnDropFilesHandler(Handler: TDropFilesEvent);
begin
  RemoveHandler(ahtDropFiles,TMethod(Handler));
end;

procedure TApplication.AddOnHelpHandler(Handler: THelpEvent; AsFirst: Boolean);
begin
  AddHandler(ahtHelp,TMethod(Handler),AsFirst);
end;

procedure TApplication.RemoveOnHelpHandler(Handler: THelpEvent);
begin
  RemoveHandler(ahtHelp,TMethod(Handler));
end;

procedure TApplication.AddOnHintHandler(Handler: TNotifyEvent; AsFirst: Boolean);
begin
  AddHandler(ahtHint,TMethod(Handler),AsFirst);
end;

procedure TApplication.RemoveOnHintHandler(Handler: TNotifyEvent);
begin
  RemoveHandler(ahtHint,TMethod(Handler));
end;

procedure TApplication.AddOnShowHintHandler(Handler: TShowHintEvent;
  AsFirst: Boolean);
begin
  AddHandler(ahtShowHint,TMethod(Handler),AsFirst);
end;

procedure TApplication.RemoveOnShowHintHandler(Handler: TShowHintEvent);
begin
  RemoveHandler(ahtShowHint,TMethod(Handler));
end;

procedure TApplication.AddOnGetMainFormHandleHandler(Handler: TGetHandleEvent;
  AsFirst: Boolean);
begin
  AddHandler(ahtGetMainFormHandle,TMethod(Handler),AsFirst);
end;

procedure TApplication.RemoveOnGetMainFormHandleHandler(Handler: TGetHandleEvent);
begin
  RemoveHandler(ahtGetMainFormHandle,TMethod(Handler));
end;

procedure TApplication.RemoveAllHandlersOfObject(AnObject: TObject);
var
  HandlerType: TApplicationHandlerType;
begin
  for HandlerType:=Low(TApplicationHandlerType) to High(TApplicationHandlerType) do
    FApplicationHandlers[HandlerType].RemoveAllMethodsOfObject(AnObject);
end;

procedure TApplication.IntfEndSession;
begin
  if Assigned(FOnEndSession) then FOnEndSession(Self);
  FApplicationHandlers[ahtEndSession].CallNotifyEvents(Self);
end;

procedure TApplication.IntfAppActivate(const Async: Boolean = False);
begin
  if Async then
    QueueAsyncCall(@Activate, 1)
  else
    Activate(1);
end;

procedure TApplication.IntfAppDeactivate(const Async: Boolean = False);
begin
  if Async then
    QueueAsyncCall(@Deactivate, 1)
  else
    Deactivate(1);
end;

procedure TApplication.IntfQueryEndSession(var Cancel: Boolean);
var
  i: LongInt;
begin
  if Assigned(FOnQueryEndSession) then FOnQueryEndSession(Cancel);
  i:=FApplicationHandlers[ahtQueryEndSession].Count;
  while FApplicationHandlers[ahtQueryEndSession].NextDownIndex(i) do
    TQueryEndSessionEvent(FApplicationHandlers[ahtQueryEndSession][i])(Cancel);
end;

procedure TApplication.IntfAppMinimize;
begin
  if Assigned(FOnMinimize) then FOnMinimize(Self);
  FApplicationHandlers[ahtMinimize].CallNotifyEvents(Self);
end;

procedure TApplication.IntfAppRestore;
begin
  Screen.RestoreLastActive;
  if Assigned(FOnRestore) then FOnRestore(Self);
  FApplicationHandlers[ahtRestore].CallNotifyEvents(Self);
end;

{------------------------------------------------------------------------------
  Method:  TApplication.IntfDropFiles
  Params:  FileNames - Dropped files

  Invokes OnDropFilesEvent of the application.
  This function is called by the interface.
 ------------------------------------------------------------------------------}
procedure TApplication.IntfDropFiles(const FileNames: array of String);
var
  i: LongInt;
begin
  if Assigned(FOnDropFiles) then FOnDropFiles(Self, FileNames);
  i:=FApplicationHandlers[ahtDropFiles].Count;
  while FApplicationHandlers[ahtDropFiles].NextDownIndex(i) do
    TDropFilesEvent(FApplicationHandlers[ahtDropFiles][i])(Self,Filenames);
end;

procedure TApplication.IntfSettingsChange;
begin
  if FUpdateFormatSettings then
  begin
  {$ifdef windows}
    {$ifdef DisableUTF8RTL}
      GetFormatSettings;
    {$else}
      GetFormatSettingsUTF8;
    {$endif}
  {$endif};
  end;
end;

procedure TApplication.IntfThemeOptionChange(AThemeServices: TThemeServices;
  AOption: TThemeOption);
begin
  case AOption of
    toShowButtonImages:
      if ShowButtonGlyphs = sbgSystem then
        NotifyCustomForms(CM_APPSHOWBTNGLYPHCHANGED);
    toShowMenuImages:
      if ShowMenuGlyphs = sbgSystem then
        NotifyCustomForms(CM_APPSHOWMENUGLYPHCHANGED);
  end;
end;

function TApplication.IsRightToLeft: Boolean;
begin
  Result := (BiDiMode <> bdLeftToRight);
end;

procedure TApplication.DoArrowKey(AControl: TWinControl; var Key: Word;
  Shift: TShiftState);
begin
  if (Key in [VK_LEFT, VK_RIGHT, VK_UP, VK_DOWN]) and (Shift = []) and
     (AControl.Perform(CM_WANTSPECIALKEY, Key, 0) = 0) and
     (AControl.Perform(LM_GETDLGCODE, Key, 0) and DLGC_WANTARROWS = 0) and
     (anoArrowToSelectNextInParent in Navigation) and AControl.Focused and
     Assigned(AControl.Parent)  then
  begin
    // traverse controls inside parent
    AControl.Parent.SelectNext(AControl, Key in [VK_RIGHT, VK_DOWN], False);
    Key := VK_UNKNOWN;
  end;
end;

procedure TApplication.DoBeforeMouseMessage(CurMouseControl: TControl);
begin
  //debugln(['TApplication.DoBeforeMouseMessage ',DbgSName(CurMouseControl)]);
  UpdateMouseControl(CurMouseControl);
end;

function TApplication.IsShortcut(var Message: TLMKey): boolean;
var
  ModalForm: TCustomForm;
begin
  Result := false;
  if Assigned(FOnShortcut) then
  begin
    FOnShortcut(Message, Result);
    if Result then
      Exit;
  end;

  // next: if there is a modal form, let it handle the short cut
  ModalForm := Screen.GetCurrentModalForm;
  if Assigned(ModalForm) and IsWindowEnabled(ModalForm.Handle) then
    Result := ModalForm.IsShortcut(Message)
  else
  begin
    // no modal form - let the current focused form handle the shortcut
    if Assigned(Screen.ActiveCustomForm) and IsWindowEnabled(Screen.ActiveCustomForm.Handle) then
    begin
      Result := Screen.ActiveCustomForm.IsShortcut(Message);
      if Result then Exit;
    end;

    // let the main form handle the shortcut
    if Assigned(MainForm) and (Screen.ActiveCustomForm <> MainForm) and IsWindowEnabled(MainForm.Handle) then
    begin
      Result := FMainForm.IsShortcut(Message);
      if Result then Exit;
    end;
  end;
end;

procedure TApplication.DoEscapeKey(AControl: TWinControl; var Key: Word;
  Shift: TShiftState);
var
  Form: TCustomForm;
  lCancelControl: TControl;
begin
  if (Shift = []) and (Key = VK_ESCAPE) and
     (AControl.Perform(CM_WANTSPECIALKEY, Key, 0) = 0) and
     (AControl.Perform(LM_GETDLGCODE, Key, 0) and DLGC_WANTALLKEYS = 0) and
     (anoEscapeForCancelControl in Navigation) then
  begin
    Form := GetParentForm(AControl);
    if Assigned(Form) then
    begin
      lCancelControl := Form.CancelControl;
      if Assigned(lCancelControl)
        and lCancelControl.Enabled and lCancelControl.Visible then
      begin
        //debugln('TApplication.ControlKeyUp VK_ESCAPE ', Acontrol.Name);
        try
          lCancelControl.ExecuteCancelAction;
        finally
          Key := VK_UNKNOWN;
        end;
      end;
    end;
  end;
end;

procedure TApplication.DoReturnKey(AControl: TWinControl; var Key: Word;
  Shift: TShiftState);
var
  Form: TCustomForm;
  lDefaultControl: TControl;
begin
  if (Shift = []) and (Key = VK_RETURN) and
     (AControl.Perform(CM_WANTSPECIALKEY, Key, 0) = 0) and
     (AControl.Perform(LM_GETDLGCODE, Key, 0) and DLGC_WANTALLKEYS = 0) and
     (anoReturnForDefaultControl in Navigation) then
  begin
    //DebugLn(['TApplication.DoReturnKey ',DbgSName(AControl)]);
    Form := GetParentForm(AControl);
    if Assigned(Form) then
    begin
      lDefaultControl := Form.ActiveDefaultControl;
      if lDefaultControl = nil then
        lDefaultControl := Form.DefaultControl;
      if Assigned(lDefaultControl)
        and ((lDefaultControl.Parent = nil) or (lDefaultControl.Parent.CanFocus))
        and lDefaultControl.Enabled and lDefaultControl.Visible then
      begin
        //debugln('TApplication.DoReturnKey VK_RETURN ', Acontrol.Name);
        //Setting Key to VK_UKNOWN prevents the calling of KeyUpAfterInterface,
        //which tiggers EditingDone when Key = VK_RETURN, so we call it here
        try
          AControl.EditingDone;
          lDefaultControl.ExecuteDefaultAction;
        finally
          Key := VK_UNKNOWN;
        end;
      end;
    end;
  end;
end;

procedure TApplication.DoTabKey(AControl: TWinControl; var Key: Word;
  Shift: TShiftState);
begin
  if (Key = VK_TAB) and ((Shift - [ssShift]) = []) and
     (AControl.Perform(CM_WANTSPECIALKEY, Key, 0) = 0) and
     (AControl.Perform(LM_GETDLGCODE, Key, 0) and DLGC_WANTTAB = 0) and
     (anoTabToSelectNext in Navigation) and AControl.Focused then
  begin
    // traverse tabstop controls inside form
    AControl.PerformTab(not (ssShift in Shift));
    Key := VK_UNKNOWN;
  end;
end;

{------------------------------------------------------------------------------
  TApplication CreateForm

  Note: The name is confusing and only kept for Delphi compatibility. It can
  create any kind of components.

  Create a Component instance and sets the pointer to the component variable
  and loads the component. If it is a form it will be added to the applications
  forms list
------------------------------------------------------------------------------}
procedure TApplication.CreateForm(InstanceClass: TComponentClass;
  out Reference);
var
  Instance: TComponent;
  ok: boolean;
  AForm: TForm;
begin
  // Allocate the instance, without calling the constructor
  Instance := TComponent(InstanceClass.NewInstance);
  // set the Reference before the constructor is called, so that
  // events and constructors can refer to it
  TComponent(Reference) := Instance;

  ok:=false;
  try
    if (FCreatingForm=nil) and (Instance is TForm) then
      FCreatingForm:=TForm(Instance);
    Instance.Create(Self);
    ok:=true;
  finally
    if not ok then begin
      TComponent(Reference) := nil;
      if FCreatingForm=Instance then
        FCreatingForm:=nil;
    end;
  end;

  if (Instance is TForm) then
  begin
    AForm := TForm(Instance);
    UpdateMainForm(AForm);
    if FMainForm = AForm then
      AForm.HandleNeeded;
    if AForm.FormStyle = fsSplash then
    begin
      // show the splash form and handle the paint message
      AForm.Show;
      AForm.Invalidate;
      ProcessMessages;
    end;
  end;
  {$IFDEF AfterConstructionDataModuleNotWorking}
  if (Instance is TDataModule) then
  begin
    TDataModule(instance).AfterConstruction;
  end;
  {$ENDIF}
end;

procedure TApplication.UpdateMainForm(AForm: TForm);
begin
  if (FMainForm = nil)
  and (FCreatingForm=AForm)
  and (not (AppDestroying in FFlags))
  and not (AForm.FormStyle in [fsMDIChild, fsSplash])
  then
    FMainForm := AForm;
end;

procedure TApplication.QueueAsyncCall(const AMethod: TDataEvent; Data: PtrInt);
var
  lItem: PAsyncCallQueueItem;
begin
  if AppDoNotCallAsyncQueue in FFlags then
    raise Exception.Create('TApplication.QueueAsyncCall already shut down');
  New(lItem);
  lItem^.Method := AMethod;
  lItem^.Data := Data;
  lItem^.NextItem := nil;
  System.EnterCriticalsection(FAsyncCall.CritSec);
  try
    with FAsyncCall.Next do begin
      lItem^.PrevItem := Last;
      if Last<>nil then begin
        assert(Top <> nil, 'TApplication.QueueAsyncCall: Top entry missing (but last is assigned)');
        Last^.NextItem := lItem
      end else begin
        assert(Last = nil, 'TApplication.QueueAsyncCall: Last entry found, while Top not assigned');
        Top := lItem;
      end;
      Last := lItem;
    end;
  finally
    System.LeaveCriticalsection(FAsyncCall.CritSec);
  end;

  if Assigned(WakeMainThread) then
    WakeMainThread(nil);
end;

procedure TApplication.RemoveAsyncCalls(const AnObject: TObject);

  procedure DoRemoveAsyncCalls(var AQueue: TAsyncCallQueue);
  var
    lItem, lItem2: PAsyncCallQueueItem;
  begin
    lItem := AQueue.Last;
    while lItem <> nil do begin
      if TMethod(lItem^.Method).Data = Pointer(AnObject) then begin
        if lItem^.NextItem <> nil then
          lItem^.NextItem^.PrevItem := lItem^.PrevItem;
        if lItem^.PrevItem <> nil then
          lItem^.PrevItem^.NextItem := lItem^.NextItem;

        if lItem = AQueue.Last then
          AQueue.Last := lItem^.PrevItem;
        if lItem = AQueue.Top then
          AQueue.Top := lItem^.NextItem;

        lItem2 := lItem;
        lItem := lItem^.PrevItem;
        Dispose(lItem2);
      end
      else
        lItem := lItem^.PrevItem;
    end;
  end;

begin
  if AppDoNotCallAsyncQueue in FFlags then
    raise Exception.Create('TApplication.QueueAsyncCall already shut down');

  System.EnterCriticalsection(FAsyncCall.CritSec);
  try
    DoRemoveAsyncCalls(FAsyncCall.Cur);
    DoRemoveAsyncCalls(FAsyncCall.Next);
  finally
    System.LeaveCriticalSection(FAsyncCall.CritSec);
  end;
end;

procedure TApplication.FreeComponent(Data: PtrInt);
begin
  if Data<>0 then
    DebugLn(['HINT: TApplication.FreeComponent Data<>0 ignored']);
  ReleaseComponents;
end;

procedure TApplication.ReleaseComponents;
var
  Component: TComponent;
begin
  if FComponentsReleasing<>nil then exit; // currently releasing
  if (FComponentsToRelease<>nil) then begin
    if FComponentsToRelease.Count=0 then begin
      FreeAndNil(FComponentsToRelease);
      exit;
    end;
    // free components
    // Notes:
    //   - check TLCLComponent.LCLRefCount=0
    //   - during freeing new components can be added to the FComponentsToRelease
    //   - components can be removed from FComponentsToRelease and FComponentsReleasing
    FComponentsReleasing:=FComponentsToRelease;
    FComponentsToRelease:=nil;
    try
      while (FComponentsReleasing<>nil) and (FComponentsReleasing.Count>0) do
      begin
        Component:=TComponent(FComponentsReleasing[0]);
        FComponentsReleasing.Delete(0);
        if (Component is TLCLComponent)
        and (TLCLComponent(Component).LCLRefCount>0) then begin
          // add again to FComponentsToRelease
          ReleaseComponent(Component);
        end else begin
          // this might free some more components from FComponentsReleasing
          Component.Free;
        end;
      end;
    finally
      // add remaining to FComponentsToRelease
      while (FComponentsReleasing<>nil) and (FComponentsReleasing.Count>0) do
      begin
        Component:=TComponent(FComponentsReleasing[0]);
        FComponentsReleasing.Delete(0);
        ReleaseComponent(Component);
      end;
      FreeAndNil(FComponentsReleasing);
    end;
  end;
end;

procedure TApplication.ReleaseComponent(AComponent: TComponent);
var
  IsFirstItem: Boolean;
begin
  if csDestroying in AComponent.ComponentState then exit;
  //DebugLn(['TApplication.ReleaseComponent ',DbgSName(AComponent)]);
  if AppDestroying in FFlags then begin
    // free immediately
    AComponent.Free;
  end else begin
    // free later
    // => add to the FComponentsToRelease
    IsFirstItem:=FComponentsToRelease=nil;
    if IsFirstItem then
      FComponentsToRelease:=TFPList.Create
    else if FComponentsToRelease.IndexOf(AComponent)>=0 then
      exit;
    FComponentsToRelease.Add(AComponent);
    AComponent.FreeNotification(Self);
    if IsFirstItem then
      QueueAsyncCall(@FreeComponent, 0);
  end;
end;

function TApplication.ExecuteAction(ExeAction: TBasicAction): Boolean;
begin
  Result := False;
  if Assigned(FOnActionExecute) then FOnActionExecute(ExeAction, Result);
end;

function TApplication.UpdateAction(TheAction: TBasicAction): Boolean;
begin
  Result := False;
  if Assigned(FOnActionUpdate) then FOnActionUpdate(TheAction, Result);
end;

function TApplication.IsRTLLang(ALang: String): Boolean;
var
 lng : String;
 p   : word;

  function sep_pos : word; inline;
  begin
    Result := Pos('-', lng);
    if Result = 0 then
      Result := Pos('_', lng);
  end;

begin
  lng    := LowerCase(ALang);
  p      := sep_pos;
  if p > 0 then 
    lng := copy(lng, 1, p-1);

  Result := (lng = 'ar') or // Arabic
            (lng = 'he') or // Hebrew
            (lng = 'yi') or // Yiddish

            // The languages bellow usually use arabic as the language name
            (lng = 'dv') or
            (lng = 'ps') or
            (lng = 'az') or
            (lng = 'fa') or
            (lng = 'ks') or
            (lng = 'ku') or
            (lng = 'pa') or
            (lng = 'sd') or
            (lng = 'tk') or
            (lng = 'ug') or
            (lng = 'ur') { or

              Not sure about the following languages ... 
              They do not have 2 letters ISO standard are they in use ?
            (lng = 'jpr') or
            (lng = 'syr') or
            (lng = 'nqo') or
            (lng = 'jrb')
            }
            ;
end;

function TApplication.Direction(ALang: String): TBiDiMode;
const
  BidiModeMap: array[Boolean] of TBiDiMode = (bdLeftToRight, bdRightToLeft);
begin
  Result := BidiModeMap[IsRTLLang(ALang)];
end;


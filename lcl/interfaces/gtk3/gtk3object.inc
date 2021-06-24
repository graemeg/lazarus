{%MainUnit gtk3int.pas}

{ TGtk3WidgetSet }

var
  Gtk3MPF: TGPollFunc;

function Gtk3PollFunction(ufds:PGPollFD; nfsd:guint; timeout:gint):gint; cdecl;
begin
  Result := nfsd;
  if TimeOut = -1 then
    Gtk3WidgetSet.FMainPoll := ufds
  else
    Gtk3WidgetSet.FMainPoll := nil;
  if Gtk3MPF <> nil then
  begin
    // writeln('Gtk3PollFunction timeout ',TimeOut,' nfsd ',nfsd,' ufds.revents ',ufds^.revents);
    Gtk3MPF(ufds, nfsd, timeout);
  end;
end;

{hook into gtk3 main event loop, used for testing purposes only atm.}
procedure Gtk3MainEventLoop(AEvent: PGdkEvent; {%H-}AData: gPointer); cdecl;
var
  AList: PGList;
  APt: TPoint;
  AWindow: HWND;
  AComboBox: TGtk3ComboBox;
  AWidget: gpointer;
  AContext: Pcairo_t;
  x: Double;
  y: Double;
  x2: Double;
  y2: Double;
  ARegion: Pcairo_region_t;
begin
  {$IFDEF GTK3DEBUGCORE}
  DebugLn('** TGtk3WidgetSet.Gtk3MainEventLoop **');
  {$ENDIF}

  // even this does not work correct
  (*
  if (AEvent^.type_ = GDK_CONFIGURE) then
  begin
    AWidget := g_object_get_data(AEvent^.configure.window,'lclwidget');
    if AWidget <> nil then
    begin
      if wtWindow in TGtk3Widget(AWidget).WidgetType then
      begin
        TGtk3Window(AWidget).Gtk3ActivateWindow(AEvent);
        DebugLn('** WindowState event ',dbgsName(TGtk3Widget(AWidget).LCLObject),' windowState=',dbgs(TGtk3Window(AWidget).GetWindowState));
      end else
        DebugLn('** WindowState event not wtWindow ',dbgsName(TGtk3Widget(AWidget).LCLObject));
    end else
      DebugLn('** WindowState event UNKNOWN WINDOW !!!');
  end;
  *)

  (*
  if (AEvent^.type_ = GDK_EXPOSE) then
  begin
    AWidget := g_object_get_data(AEvent^.expose.window,'lclwidget');
    if (AWidget <> nil) then
    begin
      ARegion := gdk_window_get_clip_region(AEvent^.expose.window);
      cairo_region_get_extents(ARegion, @ARect);
      DebugLn('Gtk3MainEventLoop*** EXPOSED ',dbgsName(TGtk3Widget(AWidget).LCLObject),
        ' ownswindow ',dbgs(TGtk3Widget(AWidget).GetContainerWidget^.get_has_window),
        ' window ',dbgHex(PtrUInt(AEvent^.expose.window)),
        ' extents ',Format('x %d y %d x2 %d y2 %d',[ARect.x, ARect.y, ARect.width, ARect.height]));

      { do not use this otherwise painting is corrupted !!!! testing purposes only
      AContext := gdk_cairo_create(AEvent^.expose.window);
      cairo_clip_extents(AContext, @x, @y, @x2, @y2);
      DebugLn('Gtk3MainEventLoop*** EXPOSED ',dbgsName(TGtk3Widget(AWidget).LCLObject),
      ' window ',dbgHex(PtrUInt(AEvent^.expose.window)),
      ' extents ',Format('x %2.2n y %2.2n x2 %2.2n y2 %2.2n',[x, y, x2, y2]));
      cairo_surface_flush(cairo_get_target(AContext));
      cairo_surface_mark_dirty(cairo_get_target(AContext));
      cairo_destroy(AContext);
      }
    end;
  end;
  *)

  gtk_main_do_event(AEvent);
end;

procedure TGtk3WidgetSet.Gtk3Create;
var
  AGtkThread: PGThread;
  AId: String;
begin
  g_type_init;
  gtk_init(@argc, @argv);
  AGtkThread := g_thread_self();
  if not IsLibrary then
  begin
  AId := 'org.lcl.thread_' + dbgHex({%H-}PtrUInt(AGtkThread));
  FGtk3Application := TGtkApplication.new(PgChar(AId), G_APPLICATION_NON_UNIQUE);
  // FGtk3Application^.set_application_id(PgChar(AId));
  FGtk3Application^.register(nil, nil);
  end;
  GTK3WidgetSet := Self;
end;

procedure TGtk3WidgetSet.Gtk3Destroy;
begin
  Gtk3MPF := nil;
  GTK3WidgetSet := nil;
  WakeMainThread := nil;

  if Assigned(FAppIcon) then
    FAppIcon^.unref;
  FAppIcon := nil;
end;

procedure TGtk3WidgetSet.SetDefaultAppFontName;
var
  AValue: TGValue;
begin
  FillByte(AValue{%H-}, SizeOf(AValue), 0);
  AValue.init(G_TYPE_STRING);
  g_object_get_property(gtk_settings_get_default, 'gtk-font-name', @AValue);
  FDefaultAppFontName := AValue.get_string;
  AValue.unset;
end;

procedure TGtk3WidgetSet.InitSysColorBrushes;
var
  i: integer;
  LogBrush: TLogBrush;
begin
  LogBrush.lbHatch := 0;
  FillChar(LogBrush, SizeOf(TLogBrush), 0);
  for i := Low(FSysColorBrushes) to High(FSysColorBrushes) do
  begin
    LogBrush.lbColor := GetSysColor(i);
    FSysColorBrushes[i] := CreateBrushIndirect(LogBrush);
    TGtk3Brush(FSysColorBrushes[i]).Shared := True;
  end;
end;

procedure TGtk3WidgetSet.FreeSysColorBrushes;

  procedure DeleteAndNilObject(var h: HGDIOBJ);
  begin
    if h <> 0 then
      TGtk3Brush(h).Shared := False;
    DeleteObject(h);
    h := 0;
  end;

var
  i: Integer;
begin
  for i := Low(FSysColorBrushes) to High(FSysColorBrushes) do
    if FSysColorBrushes[i] <> HBRUSH(-1) then
      DeleteAndNilObject(FSysColorBrushes[i]);
end;

{$IFNDEF UNIX}
procedure TGtk3WidgetSet.DoWakeMainThread(Sender: TObject);
begin
  g_main_context_wakeup(g_main_context_default);
  CheckSynchronize;
end;
{$ENDIF}

function TGtk3WidgetSet.CreateDCForWidget(AWidget: PGtkWidget;
  AWindow: PGdkWindow; cr: Pcairo_t): HDC;
begin
  if AWindow <> nil then
  begin
    Result := HDC(TGtk3DeviceContext.Create(AWindow, False))
  end else
  begin
    if cr <> nil then
      Result := HDC(TGtk3DeviceContext.CreateFromCairo(AWidget, Cr))
    else
      Result := HDC(TGtk3DeviceContext.Create(AWidget, False));
  end;
  TGtk3DeviceContext(Result).CanRelease := True;
end;

procedure TGtk3WidgetSet.AddWindow(AWindow: PGtkWindow);
begin
  if Assigned(FGtk3Application) then
    FGtk3Application^.add_window(AWindow);
end;

{$IFDEF UNIX}
var
  threadsync_pipein, threadsync_pipeout: cint;
  threadsync_giochannel: pgiochannel;
  childsig_pending: boolean;

  procedure ChildEventHandler({%H-}sig: longint; {%H-}siginfo: psiginfo;
    {%H-}sigcontext: psigcontext); cdecl;
  begin
    childsig_pending := true;
    WakeMainThread(nil);
  end;

  procedure InstallSignalHandler;
  var
    child_action: sigactionrec;
  begin
    child_action.sa_handler := @ChildEventHandler;
    fpsigemptyset(child_action.sa_mask);
    child_action.sa_flags := 0;
    fpsigaction(SIGCHLD, @child_action, nil);
  end;

  function threadsync_iocallback({%H-}source: PGIOChannel; {%H-}condition: TGIOCondition;
    data: gpointer): gboolean; cdecl;
  var
    thrashspace: array[1..1024] of byte;
  begin
    // read the sent bytes
    fpread(threadsync_pipein, {%H-}thrashspace[1], 1);

    Result := true;
    // one of children signaled ?
    if childsig_pending then
    begin
      childsig_pending := false;
      TGtk3WidgetSet(data).ProcessChildSignal;
    end;
    // execute the to-be synchronized method
    if IsMultiThread then
      CheckSynchronize;
  end;

procedure TGtk3WidgetSet.InitSynchronizeSupport;
begin
  WakeMainThread := @PrepareSynchronize;
  assignpipe(threadsync_pipein, threadsync_pipeout);
  threadsync_giochannel := g_io_channel_unix_new(threadsync_pipein);
  g_io_add_watch(threadsync_giochannel, G_IO_IN, @threadsync_iocallback, Self);
end;

procedure TGtk3WidgetSet.ProcessChildSignal;
var
  pid: tpid;
  reason: TChildExitReason;
  status: integer;
  info: dword;
  handler: PChildSignalEventHandler;
begin
  repeat
    status:=0;
    pid := fpwaitpid(-1, status, WNOHANG);
    if pid <= 0 then break;
    if wifexited(status) then
    begin
      reason := cerExit;
      info := wexitstatus(status);
    end else
    if wifsignaled(status) then
    begin
      reason := cerSignal;
      info := wtermsig(status);
    end else
      continue;

    handler := FChildSignalHandlers;
    while handler <> nil do
    begin
      if handler^.pid = pid then
      begin
        handler^.OnEvent(handler^.UserData, reason, info);
        break;
      end;
      handler := handler^.NextHandler;
    end;
  until false;
end;

procedure TGtk3WidgetSet.PrepareSynchronize(AObject: TObject);
var
  thrash: char;
begin
  // wake up GUI thread by sending a byte through the threadsync pipe
  thrash:='l';
  fpwrite(threadsync_pipeout, thrash, 1);
end;
{$ENDIF}

constructor TGtk3WidgetSet.Create;
var
  AValue: TGValue;
  i: Integer;
begin
  SetExceptionMask([exInvalidOp, exDenormalized, exZeroDivide, exOverflow, exUnderflow, exPrecision]);
  inherited Create;
  FCSSTheme := TStringList.Create;
  FThemeName := '';
  FTimerData := TFPList.Create;
  {$IFDEF GTK3DEBUGCORE}
  DebugLn('** TGtk3WidgetSet.Create **');
  {$ENDIF}
  Gtk3Create;
  FMainPoll := nil;
  Gtk3MPF := g_main_context_get_poll_func(g_main_context_default);
  g_main_context_set_poll_func(g_main_context_default, @Gtk3PollFunction);

  {install our event handler, so we can see all events before its delivery to GdkWindows}
  gdk_event_handler_set(@Gtk3MainEventLoop, Self, nil);

  {$IFDEF UNIX}
  InitSynchronizeSupport;
  // InstallSignalHandler;
  {$ELSE}
  WakeMainThread := @DoWakeMainThread;
  {$ENDIF}
  CharSetEncodingList := TList.Create;
  CreateDefaultCharsetEncodings;
  FillByte(AValue{%H-}, SizeOf(AValue), 0);
  AValue.init(G_TYPE_BOOLEAN);
  AValue.set_boolean(True);
  g_object_set_property(gtk_settings_get_default,'gtk-button-images',@AValue);
  AValue.unset;

  FGlobalCursor := 0;
  FAppIcon := nil;
  FStockNullBrush := 0;
  FStockBlackBrush := 0;
  FStockLtGrayBrush := 0;
  FStockGrayBrush := 0;
  FStockDkGrayBrush := 0;
  FStockWhiteBrush := 0;

  FStockNullPen := 0;
  FStockBlackPen := 0;
  FStockWhitePen := 0;
  FStockSystemFont := 0;
  FStockDefaultDC := 0;

  Styles := TStringList.Create;

  InitStockItems;
  // initialize default app font name
  SetDefaultAppFontName;
  // InitSysColorBrushes;
  for i := Low(FSysColorBrushes) to High(FSysColorBrushes) do
    FSysColorBrushes[i] := HBRUSH(-1);

  // g_object_set_property(gtk_settings_get_default,'gtk-enable-mnemonics',@AValue);
  // g_object_set_property(gtk_settings_get_default,'gtk-auto-mnemonics',@AValue);


  cssProvider := gtk_css_provider_new();
  gtk_css_provider_load_from_path(cssProvider, 'theme.css', nil);
  gtk_style_context_add_provider_for_screen(gdk_screen_get_default(),
                               PGtkStyleProvider(cssProvider),
                               GTK_STYLE_PROVIDER_PRIORITY_USER);

end;

destructor TGtk3WidgetSet.Destroy;
begin
  {$IFDEF GTK3DEBUGCORE}
  DebugLn('** TGtk3WidgetSet.Destroy **');
  {$ENDIF}
  if Assigned(cssProvider) then
    cssProvider^.unref;
  ReleaseAllStyles;
  Styles.Free;
  Styles := nil;
  FreeStockItems;
  Gtk3Destroy;
  FTimerData.Free;
  Gtk3DefaultContext.Free;
  Gtk3ScreenContext.Free;
  if Assigned(CharSetEncodingList) then
  begin
    ClearCharsetEncodings;
    FreeAndNil(CharSetEncodingList);
  end;
  FreeSysColorBrushes;
  FCSSTheme.Free;
  inherited Destroy;
end;

function TGtk3WidgetSet.LCLPlatform: TLCLPlatform;
begin
  Result := lpGtk3;
end;

procedure TGtk3WidgetSet.AppInit(var ScreenInfo: TScreenInfo);
//var
//  AId: String;
var
  ScreenDC: HDC;
begin
  {$IFDEF GTK3DEBUGCORE}
  DebugLn('TGtk3WidgetSet.AppInit');
  {$ENDIF}
  ScreenDC := GetDC(0);
  try
    ScreenInfo.PixelsPerInchX := GetDeviceCaps(ScreenDC, LOGPIXELSX);
    ScreenInfo.PixelsPerInchY := GetDeviceCaps(ScreenDC, LOGPIXELSY);
    ScreenInfo.ColorDepth := GetDeviceCaps(ScreenDC, BITSPIXEL);
  finally
    ReleaseDC(0, ScreenDC);
  end;
end;

procedure TGtk3WidgetSet.LoadCSSTheme;
var
  ACSSProvider: PGtkCssProvider;
  ASettings: PGtkSettings;
  AValue: TGValue;
begin
  ASettings := gtk_settings_get_default;
  FillByte(AValue{%H-}, SizeOf(AValue), 0);
  AValue.init(G_TYPE_STRING);
  ASettings^.get_property('gtk-theme-name', @AValue);
  FThemeName := AValue.get_string;
  AValue.unset;
  ACSSProvider := gtk_css_provider_get_named(PGChar(FThemeName), '');
  if not Assigned(ACSSProvider) then
    exit;
  {$note from here we must parse css and get eg tooltip background-color and color etc.}
  FCSSTheme.Text := gtk_css_provider_to_string(ACSSProvider);
end;

procedure TGtk3WidgetSet.ClearCSSTheme;
begin
  FCSSTheme.Clear;
end;

function TGtk3WidgetSet.GetCSSTheme(AList: TStrings): boolean;
begin
  Result := FCSSTheme.Count > 0;
  if not Result then
    LoadCSSTheme;
  AList.Assign(FCSSTheme);
end;

function TGtk3WidgetSet.GetThemeName: string;
begin
  if FThemeName = '' then
    LoadCSSTheme;
  Result := FThemeName;
end;

procedure TGtk3WidgetSet.AppRun(const ALoop: TApplicationMainLoop);
begin
  {$IFDEF GTK3DEBUGCORE}
  DebugLn('TGtk3WidgetSet.AppRun');
  {$ENDIF}
  if Assigned(ALoop) then
    ALoop;
end;

procedure TGtk3WidgetSet.AppWaitMessage;
begin
  {$IFDEF GTK3DEBUGCORE}
  DebugLn('TGtk3WidgetSet.AppWaitMessage');
  {$ENDIF}
  gtk_main_iteration;
end;

procedure TGtk3WidgetSet.AppProcessMessages;
begin
  {$IFDEF GTK3DEBUGCORE}
  DebugLn('TGtk3WidgetSet.AppProcessMessages');
  {$ENDIF}
  while gtk_events_pending do
    gtk_main_iteration_do(False);
end;

procedure TGtk3WidgetSet.AppTerminate;
var
  AList: PGList;
begin
  {$IFDEF GTK3DEBUGCORE}
  DebugLn('TGtk3WidgetSet.AppTerminate ',dbgs(gtk_main_level));
  {$ENDIF}
  // g_main_context_release(g_main_context_default);
  if Assigned(FGtk3Application) then
  begin
    FGtk3Application^.quit;
    AList := FGtk3Application^.get_windows;
    if Assigned(AList) then
    begin
      {$IFDEF GTK3DEBUGCORE}
      DebugLn('TGtk3WidgetSet.Gtk3Destroy app Windows list ',dbgs(g_list_length(AList)));
      {$ENDIF}
      g_list_free(AList);
    end else
    begin
      {$IFDEF GTK3DEBUGCORE}
      DebugLn('TGtk3WidgetSet.Gtk3Destroy app Windows list is null ');
      {$ENDIF}
    end;
    FGtk3Application^.release;
    FGtk3Application^.unref;
    FGtk3Application := nil;
  end;
  if gtk_main_level > 0 then
    gtk_main_quit;
end;

procedure TGtk3WidgetSet.AppMinimize;
begin
  DebugLn('TGtk3WidgetSet.AppMinimize missing');
end;

procedure TGtk3WidgetSet.AppRestore;
begin
  DebugLn('TGtk3WidgetSet.AppRestore missing');
end;

procedure TGtk3WidgetSet.AppBringToFront;
begin
  DebugLn('TGtk3WidgetSet.AppBringToFront missing');
end;

procedure TGtk3WidgetSet.AppSetIcon(const Small, Big: HICON);
var
  DoDestroyIcon: Boolean;
  AIcon: PGdkPixbuf;
begin
  // DebugLn('TGtk3WidgetSet.AppSetIcon Small=',dbgHex(Small),' Big=',dbgHex(Big));
  DoDestroyIcon := Big = 0;
  if DoDestroyIcon then
  begin
    if Assigned(FAppIcon) then
      FAppIcon^.unref;
    FAppIcon := nil;
  end else
  begin
    AIcon := TGtk3Image(Big).Handle;
    FAppIcon := PGdkPixbuf(AIcon)^.copy;
  end;
end;

procedure TGtk3WidgetSet.AppSetTitle(const ATitle: string);
begin
  if Assigned(Application.MainForm) and (Application.MainForm.HandleAllocated) then
  begin
    TGtk3Window(Application.MainForm.Handle).Title := ATitle;
  end;
end;

function TGtk3WidgetSet.AppRemoveStayOnTopFlags(const ASystemTopAlso: Boolean
  ): Boolean;
begin
  Result := inherited AppRemoveStayOnTopFlags(ASystemTopAlso);
end;

function TGtk3WidgetSet.AppRestoreStayOnTopFlags(const ASystemTopAlso: Boolean
  ): Boolean;
begin
  Result := inherited AppRestoreStayOnTopFlags(ASystemTopAlso);
end;

function TGtk3WidgetSet.CreateStandardCursor(ACursor: SmallInt): HCURSOR;
var
  CursorValue: Integer;
begin
  Result := 0;
  if ACursor < crLow then Exit;
  if ACursor > crHigh then Exit;
  case TCursor(ACursor) of
    crDefault:  CursorValue := GDK_LEFT_PTR;
    crArrow:    CursorValue := GDK_Arrow;
    crCross:    CursorValue := GDK_Cross;
    crIBeam:    CursorValue := GDK_XTerm;
    crSizeNESW: CursorValue := GDK_BOTTOM_LEFT_CORNER;
    crSizeNS:   CursorValue := GDK_SB_V_DOUBLE_ARROW;
    crSizeNWSE: CursorValue := GDK_TOP_LEFT_CORNER;
    crSizeWE:   CursorValue := GDK_SB_H_DOUBLE_ARROW;
    crSizeNW:   CursorValue := GDK_TOP_LEFT_CORNER;
    crSizeN:    CursorValue := GDK_TOP_SIDE;
    crSizeNE:   CursorValue := GDK_TOP_RIGHT_CORNER;
    crSizeW:    CursorValue := GDK_LEFT_SIDE;
    crSizeE:    CursorValue := GDK_RIGHT_SIDE;
    crSizeSW:   CursorValue := GDK_BOTTOM_LEFT_CORNER;
    crSizeS:    CursorValue := GDK_BOTTOM_SIDE;
    crSizeSE:   CursorValue := GDK_BOTTOM_RIGHT_CORNER;
    crUpArrow:  CursorValue := GDK_LEFT_PTR;
    crHourGlass:CursorValue := GDK_WATCH;
    crHSplit:   CursorValue := GDK_SB_H_DOUBLE_ARROW;
    crVSplit:   CursorValue := GDK_SB_V_DOUBLE_ARROW;
    crAppStart: CursorValue := GDK_LEFT_PTR;
    crHelp:     CursorValue := GDK_QUESTION_ARROW;
    crHandPoint:CursorValue := GDK_Hand2;
    crSizeAll:  CursorValue := GDK_FLEUR;
  else
    CursorValue := -1;
  end;
  if CursorValue <> -1 then
    Result := HCURSOR({%H-}PtrUInt(gdk_cursor_new(CursorValue)));
end;

function TGtk3WidgetSet.DCGetPixel(CanvasHandle: HDC; X, Y: integer): TGraphicsColor;
begin
  if IsValidDC(CanvasHandle) then
    Result := TGtk3DeviceContext(CanvasHandle).getPixel(X, Y)
  else
    Result := 0;
end;

procedure TGtk3WidgetSet.DCSetPixel(CanvasHandle: HDC; X, Y: Integer; AColor: TGraphicsColor);
begin
  if IsValidDC(CanvasHandle) then
    TGtk3DeviceContext(CanvasHandle).drawPixel(X, Y, AColor);
end;

procedure TGtk3WidgetSet.DCRedraw(CanvasHandle: HDC);
begin
  {$IFDEF GTK3DEBUGNOTIMPLEMENTED}
  DebugLn('WARNING: TGtk3WidgetSet.DCRedraw not implemented ...');
  {$ENDIF}
end;

procedure TGtk3WidgetSet.DCSetAntialiasing(CanvasHandle: HDC; AEnabled: Boolean
  );
begin
  // inherited DCSetAntialiasing(CanvasHandle, AEnabled);
  if IsValidDC(CanvasHandle) then
  begin
    TGtk3DeviceContext(CanvasHandle).set_antialiasing(AEnabled);
  end;
end;

procedure TGtk3WidgetSet.SetDesigning(AComponent: TComponent);
begin
  // inherited SetDesigning(AComponent);
end;

function gtk3TimerProc(Data: gPointer): gBoolean; cdecl;
var
  TimerInfo: PGtkITimerinfo;
begin
  Result := False;

  TimerInfo := PGtkITimerinfo(Data);

  if (FTimerData = nil) or (FTimerData.IndexOf(Data)<0) then
  begin
    Result := False // timer was killed
  end else
  begin
    if TimerInfo^.TimerFunc <> nil then
    begin
      TimerInfo^.TimerFunc;
      Result := True; // timer will go on
    end else
    begin
      Result := False; // stop timer
    end;
  end;

  if Result and (FTimerData.IndexOf(Data)<0) then
  begin
    // timer was killed
    // -> stop timer
    Result := False;
  end;
end;

procedure gtk3TimerDestroyed(Data: gPointer); cdecl;
var
  TimerInfo: PGtkITimerinfo;
begin
  if (FTimerData <> nil) and Assigned(Data) and
    (FTimerData.IndexOf(Data) >= 0) then
  begin
    TimerInfo := PGtkITimerinfo(Data);
    FTimerData.Remove(Data);
    Dispose(TimerInfo);
  end;
end;

function TGtk3WidgetSet.CreateTimer(Interval: integer; TimerFunc: TWSTimerProc
  ): THandle;
var
  TimerInfo: PGtkITimerinfo;
begin
  if ((Interval < 1) or (not Assigned(TimerFunc)))
  then
    Result := 0
  else begin
    New(TimerInfo);
    FillByte(TimerInfo^,SizeOf(TGtkITimerinfo),0);
    TimerInfo^.TimerFunc := TimerFunc;
    {$IFDEF VerboseTimer}
    DebugLn(['TGtk3WidgetSet.CreateTimer Interval=',dbgs(Interval)]);
    {$ENDIF}
    //Result:= g_timeout_add_full(0 {G_PRIORITY_DEFAULT}, Interval, @gtk3TimerProc, TimerInfo, @gtk3TimerDestroyed);
    Result:=g_timeout_add(Interval, @gtk3TimerProc, TimerInfo);
    if Result = 0 then
      Dispose(TimerInfo)
    else begin
      TimerInfo^.TimerFunc := TimerFunc;
      TimerInfo^.TimerHandle:=Result;
      FTimerData.Add(TimerInfo);
    end;
  end;
end;

function TGtk3WidgetSet.DestroyTimer(TimerHandle: THandle): boolean;
var
  n: integer;
  TimerInfo: PGtkITimerinfo;
begin
  Result := False;
  n := FTimerData.Count;
  while (n > 0) do
  begin
    dec (n);
    TimerInfo := PGtkITimerinfo(FTimerData.Items[n]);
    if (TimerInfo^.TimerHandle = guint(TimerHandle)) then
    begin
      // in gtk3 timeout is automatically removed
      // g_timeout_remove(TimerInfo^.TimerHandle);
      g_source_remove(TimerInfo^.TimerHandle);
      TimerInfo^.TimerHandle := 0;
      FTimerData.Delete(n);
      Dispose(TimerInfo);
    end;
  end;
  Result := True;
end;

function TGtk3WidgetSet.IsValidDC(const DC: HDC): Boolean;
begin
  Result := DC <> 0;
end;

function TGtk3WidgetSet.IsValidGDIObject(const AGdiObject: HGDIOBJ): Boolean;
begin
  Result := (AGdiObject <> 0) and (TObject(AGdiObject) is TGtk3ContextObject);
end;

function TGtk3WidgetSet.IsValidHandle(const AHandle: HWND): Boolean;
begin
  Result := AHandle <> 0;
end;

procedure TGtk3WidgetSet.InitStockItems;
var
  LogBrush: TLogBrush;
  logPen : TLogPen;
begin
  FillChar(LogBrush{%H-},SizeOf(TLogBrush),0);
  LogBrush.lbStyle := BS_NULL;
  FStockNullBrush := CreateBrushIndirect(LogBrush);
  TGtk3Brush(FStockNullBrush).Shared := True;

  LogBrush.lbStyle := BS_SOLID;
  LogBrush.lbColor := $000000;
  FStockBlackBrush := CreateBrushIndirect(LogBrush);
  TGtk3Brush(FStockBlackBrush).Shared := True;

  LogBrush.lbColor := $C0C0C0;
  FStockLtGrayBrush := CreateBrushIndirect(LogBrush);
  TGtk3Brush(FStockLtGrayBrush).Shared := True;

  LogBrush.lbColor := $808080;
  FStockGrayBrush := CreateBrushIndirect(LogBrush);
  TGtk3Brush(FStockGrayBrush).Shared := True;

  LogBrush.lbColor := $404040;
  FStockDkGrayBrush := CreateBrushIndirect(LogBrush);
  TGtk3Brush(FStockDkGrayBrush).Shared := True;

  LogBrush.lbColor := $FFFFFF;
  FStockWhiteBrush := CreateBrushIndirect(LogBrush);
  TGtk3Brush(FStockWhiteBrush).Shared := True;

  LogPen.lopnStyle := PS_NULL;
  LogPen.lopnWidth := Point(0, 0); // create cosmetic pens
  LogPen.lopnColor := $FFFFFF;
  FStockNullPen := CreatePenIndirect(LogPen);
  TGtk3Pen(FStockNullPen).Shared := True;

  LogPen.lopnStyle := PS_SOLID;
  FStockWhitePen := CreatePenIndirect(LogPen);
  TGtk3Pen(FStockWhitePen).Shared := True;

  LogPen.lopnColor := $000000;
  FStockBlackPen := CreatePenIndirect(LogPen);
  TGtk3Pen(FStockBlackPen).Shared := True;

  FStockSystemFont := 0; // styles aren't initialized yet

  FStockDefaultDC := 0; // app must be initialized
end;

procedure TGtk3WidgetSet.FreeStockItems;
  procedure DeleteAndNilObject(var h: HGDIOBJ);
  begin
    if h <> 0 then
      TGtk3ContextObject(h).Shared := False;
    DeleteObject(h);
    h := 0;
  end;
begin
  DeleteAndNilObject(FStockNullBrush);
  DeleteAndNilObject(FStockBlackBrush);
  DeleteAndNilObject(FStockLtGrayBrush);
  DeleteAndNilObject(FStockGrayBrush);
  DeleteAndNilObject(FStockDkGrayBrush);
  DeleteAndNilObject(FStockWhiteBrush);

  DeleteAndNilObject(FStockNullPen);
  DeleteAndNilObject(FStockBlackPen);
  DeleteAndNilObject(FStockWhitePen);

  DeleteAndNilObject(FStockSystemFont);
end;

function TGtk3WidgetSet.CreateDefaultFont: HFONT;
var
  AFont: TGtk3Font;
  cr: Pcairo_t;
begin
  Result := 0;
  cr := gdk_cairo_create(gdk_get_default_root_window);
  AFont := TGtk3Font.Create(cr, nil);
  cairo_destroy(cr);
  Result := HFONT(AFont);
end;


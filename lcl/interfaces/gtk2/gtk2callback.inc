{%MainUnit gtk2proc.pp}
{
 *****************************************************************************
  This file is part of the Lazarus Component Library (LCL)

  See the file COPYING.modifiedLGPL.txt, included in this distribution,
  for details about the license.
 *****************************************************************************
}

function DoDeliverPaintMessage(const Target: TObject; var PaintMsg: TLMPaint): PtrInt;
var
  WidgetInfo: PWidgetInfo;
  IsCustomControl: Boolean;
begin
  {
    erase backgound of custom controls
    use only for real custom controls that are GTKAPIWidget
  }
  IsCustomControl := TObject(Target) is TCustomControl;
  if IsCustomControl then begin
    Include(TWinControlAccess(Target).FWinControlFlags, wcfEraseBackground);
    TWinControl(Target).Perform(LM_ERASEBKGND, PtrInt(PaintMsg.DC), 0);
    Exclude(TWinControlAccess(Target).FWinControlFlags, wcfEraseBackground);
  end;

  Result := DeliverMessage(Target, PaintMsg);

  if IsCustomControl then begin
    WidgetInfo := GetWidgetInfo({%H-}PGtkWidget(TCustomControl(Target).Handle));
    if WidgetInfo <> nil then
      WidgetInfo^.UpdateRect := Rect(0,0,0,0);
  end;
end;

function DeliverPaintMessage(const Target: Pointer; var TheMessage): GBoolean;
var
  PaintMsg: TLMPaint;
begin
  if TLMessage(TheMessage).Msg = LM_GTKPAINT then
    PaintMsg := GtkPaintMessageToPaintMessage(TLMGtkPaint(TheMessage), True)
  else
    PaintMsg := TLMPaint(TheMessage);

  Result := DoDeliverPaintMessage(TObject(Target), PaintMsg) = 0;
  
  FinalizePaintMessage(PLMessage(@PaintMsg));
end;

{-------------------------------------------------------------------------------
  function DeliverPostMessage(const Target: Pointer; var TheMessage): GBoolean;

  'TheMessage' is in TLMessage format. Don't confuse this with tagMsg.
--------------------------------------------------------------------------------}
function DeliverPostMessage(const Target: Pointer; var TheMessage): GBoolean;
begin
  if TObject(Target) is TWinControl then
  begin
    // convert TLMessage into a tagMsg and push on the message queue
    Result := PostMessage(TWinControl(Target).Handle,
                          TLMessage(TheMessage).Msg,
                          TLMessage(TheMessage).WParam,
                          TLMessage(TheMessage).LParam
                          );
  end
  else
  begin
    if TLMessage(TheMessage).Msg <> LM_GTKPAINT then
      Result := DeliverMessage(Target, TheMessage) = 0
    else
      Result := DeliverPaintMessage(Target, TheMessage);
  end;
end;

function DeliverGtkPaintMessage(Target: Pointer; Widget: PGtkWidget;
  Area: PGDKRectangle; RepaintAll, IsAfterGtk: boolean): GBoolean;
var
  Msg: TLMGtkPaint;
  AInfo: PWidgetInfo;
begin
  //DebugLn(['DeliverGtkPaintMessage ',DbgSName(TObject(Target)),' Widget=',GetWidgetDebugReport(Widget),' RepaintAll=',RepaintAll,' AfterGtk=',IsAfterGtk,' Area=',dbgs(Area)]);
  // default is, that a control receives the paint message after gtk (including the child paints)
  // In case of TCustomControl, there is no gtk painting only the
  // child paintings. Let the TCustomControl paint the background.
  // ToDo: Eventually there must be a 'before paint message'.

  if (TObject(Target) is TCustomForm) then
  begin
    AInfo := GetWidgetInfo(Widget);
    AInfo^.FirstPaint := True;
  end;

  if IsAfterGtk then
  begin
    if TObject(Target) is TCustomControl then exit(false);
  end else
  begin
    if not (TObject(Target) is TCustomControl) then exit(false);
  end;

  if (not RepaintAll) and ((Area^.Width<1) or (Area^.Height<1)) then exit(false);

  Msg.Msg := LM_GTKPAINT;
  Msg.Data := TLMGtkPaintData.Create;
  Msg.Data.Widget := Widget;
  Msg.Data.State := GtkPaint_LCLWidget;
  Msg.Data.Rect := Bounds(Area^.x, Area^.y, Area^.Width, Area^.Height);
  Msg.Data.RepaintAll := RepaintAll;

  // the gtk2 has a working double buffering and expose event area
  Result := DeliverPaintMessage(Target, Msg);
end;

procedure EventTrace(const TheMessage : string; data : pointer);
begin
//  if Data = nil then
    //DebugLn(Format('Trace:Event [%s] fired',[Themessage]))
//  else
    //DebugLn(Format('Trace:Event [%s] fired for %s',
    //  [TheMessage, TObject(data).Classname]));
end;

{*************************************************************}
{            callback routines                                }
{*************************************************************}

{-------------------------------------------------------------------------------
  function gtkNoteBookCloseBtnClicked
  Params: Widget: PGtkWidget; Data: Pointer
  Result: GBoolean

  gtkNoteBookCloseBtnClicked is called by the gtk, whenever a close button in
  the tab of a notebook page is clicked.
-------------------------------------------------------------------------------}
function gtkNoteBookCloseBtnClicked({%H-}Widget: PGtkWidget;
  Data: Pointer): GBoolean; cdecl;
var APage: TCustomPage;
begin
  Result:=true; // handled = true
  if ComponentIsDestroyingHandle(TWinControl(Data)) then exit;
  APage:=TCustomPage(Data);
  TCustomTabControl(APage.Parent).DoCloseTabClicked(APage);
end;

function FilterFuc({%H-}xevent: PGdkXEvent; {%H-}event: PGdkEvent; {%H-}data: gpointer): TGdkFilterReturn; cdecl;
{$ifdef windows}
var
  AForm: TCustomForm absolute data;
{$endif}
begin
  Result := GDK_FILTER_CONTINUE;
  {$ifdef windows}
  if (PMSG(xevent)^.message = WM_NCLBUTTONDOWN) and
     (PMSG(xevent)^.wParam = HTCAPTION) and
     not (csDesigning in AForm.ComponentState) and
     (TWinControlAccess(TWinControl(AForm)).DragKind = dkDock) and
     (TWinControlAccess(TWinControl(AForm)).DragMode = dmAutomatic) then
  begin
    AForm.BeginDrag(True);
    Result := GDK_FILTER_REMOVE;
  end;
  {$endif}
end;

{-------------------------------------------------------------------------------
  function GTKRealizeCB
  Params: Widget: PGtkWidget; Data: Pointer
  Result: GBoolean

  GTKRealizeCB is called by the gtk, whenever a widget is realized (ie mapped),
  but before the widget itself gets the realize signal.
  That means that the gdk window on the xserver has been created.
-------------------------------------------------------------------------------}
function gtkRealizeCB(Widget: PGtkWidget; Data: Pointer): GBoolean; cdecl;
var
  decor,Func : Longint;
  TheWindow: PGdkWindow;
  TheForm: TCustomForm;
begin
  Result := CallBackDefaultReturn;

  {$IFDEF EventTrace}
  EventTrace('realize', nil);
  {$ENDIF}

  if (Data<>nil) then begin
    if TObject(Data) is TCustomForm then begin
      TheForm:=TCustomForm(Data);
      if TheForm.Parent=nil then begin
        TheWindow:=gtk_widget_get_toplevel(Widget)^.window;

        //apart from none and sizeable, this will
        //only work if WM supports motif flags
        //properly, which very few actually do.

        Decor := GetWindowDecorations(TheForm);
        Func := GetWindowFunction(TheForm);

        gdk_window_set_decorations(TheWindow, decor);
        gdk_window_set_functions(TheWindow, func);
        {$ifdef windows} // for drag/dock
        gdk_window_add_filter(TheWindow, @FilterFuc, TheForm)
        {$endif}
      end;
    end;

    if (csDesigning in TComponent(Data).ComponentState) then begin
      //DebugLn(['gtkRealizeCB ',dbgsName(TComponent(Data)),' ',GetWidgetDebugReport(Widget)]);
    end else begin
      RealizeAccelerator(TComponent(Data),Widget);
    end;
  end;
end;

{-------------------------------------------------------------------------------
  function GTKRealizeAfterCB
  Params: Widget: PGtkWidget; Data: Pointer
  Result: GBoolean

  GTKRealizeAfterCB is called by the gtk, whenever a widget is realized
  (ie mapped), and after the widget itself got the realize signal.
  That means that the gdk window on the xserver has been created and the widget
  initialized the gdkwindow. This function is used for the second part of
  the initialization of a widget.

-------------------------------------------------------------------------------}
function gtkRealizeAfterCB(Widget: PGtkWidget; Data: Pointer): GBoolean; cdecl;
var
  MainWidget, ClientWidget: PGtkWidget;
  WinWidgetInfo: PWidgetInfo;
  GdkWidget, GdkClient: PGDKWindow;
  NewEventMask: TGdkEventMask;
  LCLObject: TObject;
  TheWinControl: TWinControl;
begin
  Result:=CallBackDefaultReturn;
  if Data=nil then ;
  {$IFDEF EventTrace}
  EventTrace('realizeafter', nil);
  {$ENDIF}
  MainWidget:=GetMainWidget(Widget);
  Assert(Assigned(MainWidget), 'gtkRealizeAfterCB: MainWidget not assigned.');
  WinWidgetInfo:=g_object_get_data(PGObject(MainWidget), 'widgetinfo');
  Assert(Assigned(WinWidgetInfo), 'gtkRealizeAfterCB: WinWidgetInfo not assigned.');
  LCLObject:=GetLCLObject(MainWidget);
  if LCLObject=nil then exit;
  if (LCLObject is TWinControl) then
    TheWinControl:=TWinControl(LCLObject)
  else
    TheWinControl:=nil;

  // set extra signal masks after the widget window is created
  // define extra events we're interrested in
  //if TheWinControl<>nil then DbgOut(' ',TheWinControl.Name,':',TheWinControl.ClassName,' ',DbgS(TheWinControl.Handle));
  //DebugLn(' Widget=',DbgS(Widget),' Fixed=',DbgS(GetFixedWidget(Widget)),' Main=',DbgS(GetMainWidget(Widget)));
  if (TheWinControl<>nil) then begin
    //DebugLn(['gtkRealizeAfterCB ',GetWidgetDebugReport(Widget)]);
    {$IFDEF DebugGDK}BeginGDKErrorTrap;{$ENDIF}

    GdkWidget:=GetControlWindow(Widget);
    NewEventMask:=gdk_window_get_events(GdkWidget) or WinWidgetInfo^.EventMask;
    gtk_widget_add_events(Widget,NewEventMask);
    gdk_window_set_events(GdkWidget,NewEventMask);

    ClientWidget:=GetFixedWidget(Widget);
    GdkClient:=GetControlWindow(ClientWidget);
    if (ClientWidget<>nil) and (GdkClient<>nil) and (GdkClient<>GdkWidget) then
    begin
      //DebugLn(['gtkRealizeAfterCB ClientWindow<>Window']);
      NewEventMask:=gdk_window_get_events(GdkClient) or WinWidgetInfo^.EventMask;
      gtk_widget_add_events(ClientWidget,WinWidgetInfo^.EventMask);
      gdk_window_set_events(GdkClient,NewEventMask);
    end;
    //DebugLn('BBB1 ',DbgS(NewEventMask),8),' ',DbgS(Cardinal(gdk_window_get_events(Widget^.Window)));
    {$IFDEF DebugGDK}EndGDKErrorTrap;{$ENDIF}
  end;

  if TheWinControl<>nil then
  begin
    TheWinControl.CNPreferredSizeChanged;
    TGtkPrivateWidgetClass(TheWinControl.WidgetSetClass.WSPrivate).UpdateCursor(WinWidgetInfo);
    ConnectInternalWidgetsSignals(MainWidget,TheWinControl);

    if (TheWinControl is TCustomPage)
      and not ((TheWinControl.Parent <> nil) and (TheWinControl.Parent is TTabControl))
    then
      UpdateNotebookPageTab(nil,TheWinControl);

    if TheWinControl is TCustomForm then
      SetFormShowInTaskbar(TCustomForm(TheWinControl),
                           TCustomForm(TheWinControl).ShowInTaskbar);
  end;
end;

function gtkshowCB( {%H-}widget: PGtkWidget; data: gPointer) : GBoolean; cdecl;
var
  Mess : TLMShowWindow;
begin
  Result := True;

  {$IFDEF EventTrace}
  EventTrace('show', data);
  {$ENDIF}
  FillChar(Mess{%H-},SizeOf(Mess),0);
  Mess.Msg := LM_SHOWWINDOW;
  Mess.Show := True;

  Result := DeliverMessage(Data, Mess) = 0;
end;

function gtkHideCB( {%H-}widget: PGtkWidget; data: gPointer) : GBoolean; cdecl;
var
  Mess : TLMShowWindow;
begin
  Result := True;

  {$IFDEF EventTrace}
  EventTrace('hide', data);
  {$ENDIF}
  FillChar(Mess{%H-},SizeOf(Mess),0);
  Mess.Msg := LM_SHOWWINDOW;
  Mess.Show := False;
  Result := DeliverMessage(Data, Mess) = 0;
end;

function gtkactivateCB(widget: PGtkWidget; data: gPointer) : GBoolean; cdecl;
var
  Mess: TLMActivate;
begin
  Result:= True;
  {$IFDEF EventTrace}
  EventTrace('activate', data);
  {$ENDIF}
  
  ResetDefaultIMContext;
  
  if LockOnChange(PgtkObject(Widget),0) > 0 then Exit;

  FillChar(Mess{%H-}, SizeOf(Mess), #0);
  {$IFDEF VerboseIDEDisplayState}
  debugln(['gtkactivateCB ',DbgSName(TObject(Data))]);
  {$ENDIF}
  Mess.Msg := LM_ACTIVATE;
  Mess.Active := WA_ACTIVE;
  Mess.Minimized := False;
  if GtkWidgetIsA(Widget, gtk_window_get_type) then
    Mess.ActiveWindow := HWnd({%H-}PtrUInt(PGTKWindow(Widget)^.focus_widget))
  else
    Mess.ActiveWindow := 0;
  Mess.Result := 0;
  //DebugLn('gtkactivateCB ',DbgSName(TObject(Data)));
  DeliverMessage(Data, Mess);

  Result := CallBackDefaultReturn;
end;

function GTKCheckMenuToggeledCB(AMenuItem: PGTKCheckMenuItem; AData: gPointer): GBoolean; cdecl;
// AData --> LCLMenuItem
var
  LCLMenuItem: TMenuItem;
begin
  Result := CallBackDefaultReturn;
  {$IFDEF EventTrace}
  EventTrace('toggled', AData);
  {$ENDIF}

  LCLMenuItem := TMenuItem(AData);
  // some sanity checks
  if LCLMenuItem = nil then Exit;
  if not LCLMenuItem.IsCheckItem then Exit; // ???

  // the gtk always toggles the check flag
  // -> restore 'checked' flag if needed
  if gtk_check_menu_item_get_active(AMenuItem) = LCLMenuItem.Checked then Exit;
  if LCLMenuItem.AutoCheck then Exit;

  // restore it
  LockOnChange(PgtkObject(AMenuItem), +1);
  gtk_check_menu_item_set_active(AMenuItem, LCLMenuItem.Checked);
  LockOnChange(PgtkObject(AMenuItem), -1);
end;

function gtkchangedCB( widget: PGtkWidget; data: gPointer) : GBoolean; cdecl;
var
  Mess : TLMessage;
begin
  Result := CallBackDefaultReturn;

  if ComponentIsDestroyingHandle(TWinControl(Data))
  or (LockOnChange(PgtkObject(Widget),0)>0) then exit;
  
  {$IFDEF EventTrace}
  EventTrace('changed', data);
  {$ENDIF}
  FillChar(Mess{%H-}, SizeOf(Mess), 0);
  Mess.Msg := LM_CHANGED;
  DeliverMessage(Data, Mess);
end;

function GtkEntryDelayCursorPos(AGtkWidget: Pointer): GBoolean; cdecl;
var
  Info: PWidgetInfo;
begin
  Result := AGtkWidget <> nil;
  if Result then
  begin
    g_idle_remove_by_data(AGtkWidget);
    Info := GetWidgetInfo(AGtkWidget);
    if Info <> nil then
      gtkchanged_editbox(PGtkWidget(AGtkWidget),
        Info^.LCLObject);
  end;
end;

function postpone_changed_signal(Widget: PGtkWidget): GBoolean; cdecl;
begin
  Result := gtk_false;
  g_object_set_data(PGObject(Widget), 'lcl-postpone-changed-signal', nil);
  gtkchanged_editbox(Widget, GetWidgetInfo(Widget)^.LCLObject);
end;

procedure gtkchanged_editbox_delete_text(Widget: PGtkWidget; AStartPos,
  AEndPos: gint; data: gPointer); cdecl;
var
  id: gPointer;
begin
  // delete key pressed, but nothing is deleted (eg. cursor at the end or empty text)
  if AStartPos = AEndPos then
  begin
    g_signal_stop_emission_by_name(Widget, 'delete-text');
    Exit;
  end;

  id := g_object_get_data(PGObject(Widget), 'lcl-postpone-changed-signal');
  if id = nil then
  begin
    {%H-}PtrUInt(id) := g_idle_add(TGtkFunction(@postpone_changed_signal), Widget);
    g_object_set_data(PGObject(Widget), 'lcl-postpone-changed-signal', id);
  end;
end;

procedure gtkchanged_editbox_insert_text(Widget: PGtkWidget; ANewText: PgChar;
  ANewTextLength: gint; APosition: pgint; data: gPointer); cdecl;
var
  id: gPointer;
  EntryText: PgChar;
  LCLObject: TObject;
begin
  EntryText := gtk_entry_get_text(PGtkEntry(Widget));
  LCLObject := TObject(data);
  if (widget <> nil) and (LCLObject is TCustomEdit) then
    { NumbersOnly: stop signal if inserted text is not a number }
    if TCustomEdit(LCLObject).NumbersOnly and not IsNumber(ANewText) then
    begin
      gtk_entry_set_text(PGtkEntry(widget), EntryText);
      g_signal_stop_emission_by_name(Widget, 'insert-text');
    end;

  id := g_object_get_data(PGObject(Widget), 'lcl-postpone-changed-signal');
  if id <> nil then
  begin
    g_source_remove({%H-}PtrUInt(id));
    g_object_set_data(PGObject(Widget), 'lcl-postpone-changed-signal', nil);
  end;
  if LockOnChange(PgtkObject(Widget), 0) > 0 then
    g_object_set_data(PGObject(Widget), 'lcl-lock-changed-signal', gPointer(-1))
  else
    g_object_set_data(PGObject(Widget), 'lcl-lock-changed-signal', nil);
end;

function gtkchanged_editbox( widget: PGtkWidget; data: gPointer) : GBoolean; cdecl;
var
  Mess : TLMessage;
  GStart, GEnd: gint;
  EntryText: PgChar;
begin
  //debugln('gtkchanged_editbox');
  Result := CallBackDefaultReturn;

  if g_object_get_data(PGObject(Widget), 'lcl-lock-changed-signal') <> nil then
  begin
    g_object_set_data(PGObject(Widget), 'lcl-lock-changed-signal', nil);
    Exit;
  end;
  if g_object_get_data(PGObject(Widget), 'lcl-postpone-changed-signal') <> nil then
    Exit;
  if LockOnChange(PgtkObject(Widget),0)>0 then exit;
  {$IFDEF EventTrace}
  EventTrace('changed_editbox', data);
  {$ENDIF}
  if GTK_IS_ENTRY(Widget) then
  begin
    {cheat GtkEditable to update cursor pos in gtkEntry. issue #7243}
    gtk_editable_get_selection_bounds(PGtkEditable(Widget), @GStart, @GEnd);
    EntryText := gtk_entry_get_text(PGtkEntry(Widget));
    if (GStart = GEnd) and
      (UTF8Length(EntryText) >= PGtkEntry(Widget)^.text_length) then
    begin
      if g_object_get_data(PGObject(Widget),'lcl-gtkentry-pasted-data') <> nil then
      begin
        g_object_set_data(PGObject(Widget),'lcl-gtkentry-pasted-data',nil);
        gtk_editable_set_position(PGtkEditable(Widget), GStart);
      end else
      begin
        g_object_set_data(PGObject(Widget),'lcl-gtkentry-pasted-data',Widget);
        g_idle_add(@GtkEntryDelayCursorPos, Widget);
        exit;
      end;
    end;
  end;

  FillByte(Mess{%H-},SizeOf(Mess),0);
  Mess.Msg := CM_TEXTCHANGED;
  //debugln('gtkchanged_editbox B: DeliverMessage(CM_TextChanged)');
  DeliverMessage(Data, Mess);
end;

function gtkchanged_editbox_delete(widget: PGtkWidget;
  AType: TGtkDeleteType; APos: gint; data: gPointer): GBoolean; cdecl;
begin
  Result := CallBackDefaultReturn;
end;

function gtkpaste_editbox(Widget: PGtkWidget; data: gPointer): GBoolean; cdecl;
var
  FClipText: string;
  FClip: gtk2.PGtkClipboard;
  LCLObject: TObject;
begin
  Result := CallBackDefaultReturn;

  LCLObject := TObject(data);
  if (widget <> nil) and (LCLObject is TCustomEdit) then
    { NumbersOnly }
    if TCustomEdit(LCLObject).NumbersOnly then
    begin
      { get clipboard text and stop signal if pasted text is not a number }
      FClipText := '';
      FClip := gtk_clipboard_get(GDK_SELECTION_CLIPBOARD);
      if (FClip <> nil) and gtk_clipboard_wait_is_text_available(FClip) then
        FClipText := gtk_clipboard_wait_for_text(FClip);
      if Assigned(FClip) and not IsNumber(FClipText) then
        g_signal_stop_emission_by_name(Widget, 'paste-clipboard');
    end;
end;

function gtkdaychanged(Widget: PGtkWidget; data: gPointer) : GBoolean; cdecl;
var
  MSG: TLMessage;
begin
  Result := CallBackDefaultReturn;

  if LockOnChange(PgtkObject(Widget),0)>0 then exit;
  EventTrace('day changed', data);
  MSG.Msg := LM_DAYCHANGED;
  DeliverPostMessage(Data, MSG);

  Result := CallBackDefaultReturn;
end;

function gtktoggledCB( widget: PGtkWidget; data: gPointer): GBoolean; cdecl;
var
  Mess : TLMessage;

  procedure ChangeCheckbox(AGrayed,AChecked: boolean);
  begin
    LockOnChange(PgtkObject(Widget),1);
    gtk_toggle_button_set_Inconsistent(PGtkToggleButton(Widget), AGrayed);
    gtk_toggle_button_set_active(PGtkToggleButton(Widget), AChecked);
    LockOnChange(PgtkObject(Widget),-1);
  end;

begin
  //DebugLn('gtktoggledCB ',DbgSName(TObject(Data)));
  Result := CallBackDefaultReturn;
  {$IFDEF EventTrace}
  EventTrace('toggled', data);
  {$ENDIF}
  if LockOnChange(PgtkObject(Widget),0) > 0 then Exit;

  if GtkWidgetIsA(Widget,gtk_toggle_button_get_type) then begin

    if TObject(Data) is TCustomCheckbox then begin
      if gtk_toggle_button_get_inconsistent(PGtkToggleButton(Widget)) then
        ChangeCheckbox(false, true)
      else
      if TCustomCheckbox(Data).AllowGrayed and
         gtk_toggle_button_get_active(PGtkToggleButton(Widget)) then
        ChangeCheckbox(true, false);
    end;

  end;

  Mess.Msg := LM_CHANGED;
  Mess.Result := 0;
  DeliverMessage(Data, Mess);
  //DebugLn('gtktoggledCB END ',DbgSName(TObject(Data)));
end;

function gtkExposeEvent(Widget: PGtkWidget; Event : PGDKEventExpose;
  Data: gPointer): GBoolean; cdecl;
var
  DesignOnlySignal: boolean;
begin
  Result := CallBackDefaultReturn;
  {$IFDEF EventTrace}
  EventTrace('ExposeAfter', data);
  {$ENDIF}
  //DebugLn(['gtkExposeEvent ',GetWidgetDebugReport(Widget),' Event^.Count=',Event^.Count]);
  if (Event^.Count > 0) then exit;

  if not (csDesigning in TComponent(Data).ComponentState) then begin
    DesignOnlySignal:=GetDesignOnlySignalFlag(Widget,dstExposeAfter);
    if DesignOnlySignal then exit;
  end else begin
    {$IFDEF VerboseDesignerDraw}
    DebugLn('gtkExpose',
      ' Widget=',DbgS(Widget),'=',GetWidgetClassName(Widget),
      ' ',TComponent(Data).Name,
      ' ',dbgs(Event^.area.x),',',dbgs(Event^.area.y),',',dbgs(Event^.area.width),',',dbgs(Event^.area.height),
      '');
    {$ENDIF}
  end;

  //DebugLn(['gtkExposeEvent ',GetWidgetDebugReport(Widget),' ',dbgGRect(@Event^.Area)]);

  DeliverGtkPaintMessage(Data, Widget, @Event^.Area, False, False);
end;

function gtkExposeEventAfter(Widget: PGtkWidget; Event : PGDKEventExpose;
  Data: gPointer): GBoolean; cdecl;
var
  DesignOnlySignal: boolean;
  //children: PGList;
begin
  Result := CallBackDefaultReturn;
  {$IFDEF EventTrace}
  EventTrace('ExposeAfter', data);
  {$ENDIF}
  //DebugLn(['gtkExposeEventAfter ',GetWidgetDebugReport(Widget),' Event^.Count=',Event^.Count]);
  if (Event^.Count > 0) then exit;

  if not (csDesigning in TComponent(Data).ComponentState) then begin
    DesignOnlySignal:=GetDesignOnlySignalFlag(Widget,dstExposeAfter);
    if DesignOnlySignal then exit;
  end else begin
    {$IFDEF VerboseDesignerDraw}
    DebugLn('gtkExposeAfter',
      ' Widget=',DbgS(Widget),'=',GetWidgetClassName(Widget),
      ' ',TComponent(Data).Name,
      ' ',dbgs(Event^.area.x),',',dbgs(Event^.area.y),',',dbgs(Event^.area.width),',',dbgs(Event^.area.height),
      '');
    {$ENDIF}
  end;

  //DebugLn(['gtkExposeEventAfter ',GetWidgetDebugReport(Widget),' ',dbgGRect(@Event^.Area)]);

  DeliverGtkPaintMessage(Data,Widget,@Event^.Area,false,true);
end;

procedure ClearTopLevelsFocus(Win: PGtkWidget);
var
  List, orgList: PGList;
  Window: PGtkWindow;
  event: PGdkEvent;
  TopLevelWin: PGdkWindow;
begin

  if not GTK_IS_WINDOW(win) then
    exit;

  List := gdk_window_get_toplevels;
  orgList:=List;
  while List <> nil do
  begin
    TopLevelWin := PGdkWindow(List^.Data);
    if (TopLevelWin<>nil) and (TopLevelWin<>Win^.Window) then
    begin
      gdk_window_get_user_data(TopLevelWin, Pgpointer(@Window));
      if GTK_IS_WINDOW(Window)
         and GTK_WIDGET_VISIBLE(Window)
         and gtk_window_has_TopLevel_Focus(Window) then
      begin
        // fake focus-out event
        {$IFDEF VerboseFocus}
        DebugLn('NOTE: Window with stalled focus found!, faking focus-out event');
        {$ENDIF}
        event := gdk_event_new(GDK_FOCUS_CHANGE);
        event^.focus_change.window := TopLevelWin;
        event^.focus_change._type := GDK_FOCUS_CHANGE;
        event^.focus_change._in:=0;
        gtk_main_do_event(event);
      end;
    end;
    list := g_list_next(list);
  end;
  if Assigned(orgList) then
    g_list_free(orgList);
end;

function gtkfrmactivateAfter({%H-}widget: PGtkWidget; {%H-}Event : PgdkEventFocus;
  data: gPointer) : GBoolean; cdecl;
var
  Mess: TLMActivate;
  Info: PWidgetInfo;
{$IFDEF VerboseFocus}
  LCLObject: TObject;
  CurFocusWidget: PGtkWidget;
{$ENDIF}
begin
  {$IFDEF EventTrace}
  EventTrace('activate after', data);
  {$ENDIF}

  ResetDefaultIMContext;

  FillChar(Mess{%H-},SizeOf(Mess),#0);
  {$IFDEF VerboseFocus}
  LCLObject:=TObject(data);
  DebugLnEnter(['gtkfrmActivateAfter INIT Widget=',DbgS(Widget),' Event^.theIn=',Event^._in,
    ' LCLObject=',dbgsname(LCLObject)]);
  CurFocusWidget:=PGtkWidget(GetFocus);
  if CurFocusWidget<>nil then begin
    LCLObject:=GetNearestLCLObject(CurFocusWidget);
    DebugLn(' GetFocus=',DbgS(CurFocusWidget),' ParentLCLObject=',dbgsName(LCLObject));
  end;
  {$ENDIF}

  Info := GetWidgetInfo(Widget);
  try
    if (Info <> nil) then
      Include(Info^.Flags, wwiActivating);
    {$IFDEF VerboseIDEDisplayState}
    debugln(['gtkfrmactivateAfter ',DbgSName(TObject(Data))]);
    {$ENDIF}
    Mess.Msg := LM_ACTIVATE;
    Mess.Active := WA_ACTIVE;
    Mess.Minimized := False;
    if GtkWidgetIsA(Widget, gtk_window_get_type) then
      Mess.ActiveWindow := HWnd({%H-}PtrUInt(PGTKWindow(Widget)^.focus_widget))
    else
      Mess.ActiveWindow := 0;
    Mess.Result := 0;
    DeliverMessage(Data, Mess); // send message directly (not Post)
  finally
    if Info <> nil then
      Exclude(Info^.Flags, wwiActivating);
  end;

  Result := CallBackDefaultReturn;
  {$IFDEF VerboseFocus}
  DebugLnExit('gtkfrmActivateAfter DONE');
  {$ENDIF}
end;

function gtkfrmdeactivateAfter( {%H-}widget: PGtkWidget; {%H-}Event : PgdkEventFocus;
  data: gPointer) : GBoolean; cdecl;
var
  Mess: TLMActivate;
  Info: PWidgetInfo;
{$IFDEF VerboseFocus}
  LCLObject: TControl;
{$ENDIF}
begin
  {$IFDEF EventTrace}
  EventTrace('deactivate after', data);
  {$ENDIF}
  {$IFDEF VerboseFocus}
  LCLObject := TControl(GetLCLObject(Widget));
  DebugLnEnter(['gtkfrmDeactivate INIT Widget=',DbgS(Widget),' ',Event^._in,
        ' GetFocus=',DbgS(Widget),' LCLObject=', dbgsName(LCLObject)]);
  {$ENDIF}
  ResetDefaultIMContext;

  Info := GetWidgetInfo(Widget);
  try
    if (Info<>nil) then
      Include(Info^.Flags, wwiDeactivating);
    FillChar(Mess{%H-}, SizeOf(Mess), #0);
    {$IFDEF VerboseIDEDisplayState}
    debugln(['gtkfrmdeactivateAfter ',DbgSName(TObject(Data))]);
    {$ENDIF}
    Mess.Msg := LM_ACTIVATE;
    Mess.Active := WA_INACTIVE;
    Mess.Minimized := False;
    Mess.ActiveWindow := 0;
    Mess.Result := 0;
    DeliverMessage(Data, Mess);
  finally
    if Info<>nil then
      Exclude(Info^.Flags, wwiDeactivating);
  end;

  Result := CallBackDefaultReturn;
  {$IFDEF VerboseFocus}
  DebugLnExit('gtkfrmDeactivate DONE');
  {$ENDIF}
end;

function GTKKeyPress(Widget: PGtkWidget; Event: PGdkEventKey; Data: gPointer) : GBoolean; cdecl;
begin
  Result := HandleGtkKeyUpDown(Widget,Event,Data,true,True,'key-press-event');
end;

function GTKKeyPressAfter(Widget: PGtkWidget; Event: pgdkeventkey; Data: gPointer): GBoolean; cdecl;
begin
  Result := HandleGtkKeyUpDown(Widget,Event,Data,false,True,'key-press-event');
end;

function GTKKeyRelease(Widget: PGtkWidget; Event: PGdkEventKey; Data: gPointer) : GBoolean; cdecl;
begin
  Result := HandleGtkKeyUpDown(Widget,Event,Data,true,False,'key-release-event');
end;

function GTKKeyReleaseAfter(Widget: PGtkWidget; Event: pgdkeventkey; Data: gPointer): GBoolean; cdecl;
begin
  Result := HandleGtkKeyUpDown(Widget,Event,Data,false,False,'key-release-event');
end;


var
  NeedShiftUpdateAfterFocus: Boolean;

procedure UpdateShiftState(const KeyStateList: TFPList; const ShiftState: TShiftState);

  procedure UpdateList(const AVKeyCode: Integer; const APressed: Boolean);
  begin
    if AVKeyCode = 0 then Exit;
    if APressed
    then begin
      if KeyStateList.IndexOf({%H-}Pointer(PtrUInt(AVKeyCode))) < 0
      then KeyStateList.Add({%H-}Pointer(PtrUInt(AVKeyCode)));
    end
    else begin
      KeyStateList.Remove({%H-}Pointer(PtrUInt(AVKeyCode)));
    end;
  end;

const
  STATE_MAP: array[0..3] of TShiftStateEnum = (
    ssShift,
    ssCtrl,
    ssAlt,
    ssSuper
  );
  VK_MAP: array[0..3] of array[0..2] of Byte = (
    // (Main key, alt key 1, alt key 2) to check
    (VK_SHIFT, VK_LSHIFT, VK_RSHIFT),
    (VK_CONTROL, VK_LCONTROL, VK_RCONTROL),
    (VK_MENU, VK_LMENU, VK_RMENU),
    (VK_LWIN, VK_RWIN, 0)
  );

var
  n: Integer;
  InState: Boolean;
begin
  for n := 0 to High(STATE_MAP) do
  begin
    InState := STATE_MAP[n] in ShiftState;
    UpdateList(VK_MAP[n][0], InState);
    UpdateList(VK_MAP[n][1], InState);
    UpdateList(VK_MAP[n][2], InState);
  end;
end;

function GTKFocusCB(widget: PGtkWidget; {%H-}event: PGdkEventFocus; data: gPointer): GBoolean; cdecl;
var
  Mess : TLMessage;
  LCLObject: TObject;
  AForm: TCustomForm;
{$IFDEF VerboseFocus}
  CurFocusWidget: PGtkWidget;
{$ENDIF}
  Mask: TGdkModifierType;
  AInfo: PWidgetInfo;
begin
  {$IFDEF EventTrace}
  EventTrace('focus', data);
  {$ENDIF}
  //DebugLn('GTKFocusCB ',DbgSName(TObject(Data)),' ',GetWidgetDebugReport(Widget));

  LCLObject:=TObject(data);

  if (widget<>nil) and GTK_IS_WINDOW(widget) and (LCLObject is TCustomForm) then
  begin
    // it's a top level window about to be focused, if we are being focused
    // because of ALT+TABing to this form, the origin form might be left with
    // invalid focus information (ALT+TAB doesn't trigger focus-out event on those)
    ClearTopLevelsFocus(Widget);
  end;

  NeedShiftUpdateAfterFocus := False;
  gdk_window_get_pointer(nil, nil, nil, @Mask);
  UpdateShiftState(GTK2WidgetSet.KeyStateList, GTKEventStateToShiftState(Word(Mask)));

  {$IFDEF VerboseFocus}
  DebugLnEnter(['GTKFocusCB INIT Widget=',DbgS(Widget),' Event^.theIn=',Event^._in,
    ' LCLObject=',dbgsName(LCLObject)]);
  CurFocusWidget:=PGtkWidget(GetFocus);
  if CurFocusWidget<>nil then begin
    LCLObject:=GetNearestLCLObject(CurFocusWidget); // NOTE: overrides argument data !!!
    DebugLn('GetFocus=',DbgS(CurFocusWidget), ' ParentLCLFocus=',DbgsName(LCLObject));
    {$IFDEF VerboseSizeMsg}
    DebugLn(['GTKWindowStateEventCB ',DbgSName(TheForm),
      ' GTK=',GtkWidth,'x',GtkHeight,
      ' LCL=',TheForm.Width,'x',TheForm.Height,
      ' SizeType=',SizeMsg.SizeType-Size_SourceIsInterface,'+Size_SourceIsInterface'
      ]);
    {$ENDIF}
    LCLObject := TObject(Data); // restore original LCLObject
  end;
  {$ENDIF}

  if LCLObject is TCustomForm then begin
    // a form became active
    // it does not mean: the control focus is switch to the form
    AForm:=TCustomForm(LCLObject);
    //debugln(['GTKFocusCBAfter ',DbgSName(AForm),' ',DbgSName(AForm.ActiveControl)]);
    // the PGtkWindow(Data)^.focus_widget shows the last focus call for this
    // window. If there is a sub window (e.g. docking), then the focus_widget
    // of the parent window was not updated, so it can not be used.
    // The gtk will use, if we let it, which will not follow the LCL focus logic.
    // Follow the LCL logic:
    if AForm.ActiveControl<>nil then begin
      Data:=AForm.ActiveControl;
      //debugln(['GTKFocusCBAfter ',DbgSName(LCLObject),' send=',event^.send_event,' window=',dbgs(event^.window),' in=',event^._in,' type=',event^._type,' Data=',dbgsname(TObject(Data))]);
    end;
  end;

  // we do not show selection (gtk behaviour) when widget is unfocused,
  // so revert back CursorPos.issues #18164,#21897,#23182
  if GtkWidgetIsA(Widget, gtk_type_entry) then
  begin
    AInfo := GetWidgetInfo(Widget);
    if AInfo <> nil then
    begin
      if (AInfo^.LCLObject is TCustomEdit)
      and ((AInfo^.CursorPos > 0) or (AInfo^.SelLength > 0)) then
      begin
        // gtk_entry_set_position(PGtkEntry(Widget), AInfo^.CursorPos);
        // gtk_editable_select_region(PGtkEditable(Widget), AInfo^.CursorPos, AInfo^.CursorPos);
        // do not trigger signals, only update pos for lcl
        PGtkEntry(Widget)^.current_pos := AInfo^.CursorPos;
        PGtkEntry(Widget)^.selection_bound := AInfo^.CursorPos + AInfo^.SelLength;
      end;
    end;
  end;

  ResetDefaultIMContext;

  //TODO: fill in old focus
  FillChar(Mess{%H-}, SizeOf(Mess), 0);
  Mess.msg := LM_SETFOCUS;
  DeliverMessage(Data,  Mess);

  Result := CallBackDefaultReturn;
  {$IFDEF VerboseFocus}
  DebugLnExit('GTKFocusCB DONE');
  {$ENDIF}
end;

function GTKKillFocusCB({%H-}widget: PGtkWidget; {%H-}event:PGdkEventFocus;
  data: gPointer) : GBoolean; cdecl;
{$IFDEF VerboseFocus}
var
  LCLObject: TObject;
  CurFocusWidget: PGtkWidget;
{$ENDIF}
begin
  {$IFDEF EventTrace}
  EventTrace('killfocusCB', data);
  {$ENDIF}
  //DebugLn('GTKKillFocusCB ',DbgSName(TObject(Data)),' ',GetWidgetDebugReport(Widget));
  {$IFDEF VerboseFocus}
  NeedShiftUpdateAfternFocus := True;   // <- JRA: this doesn't look like simply log !!!
  LCLObject:=TObject(data);
  DebugLn(['GTKillFocusCB Widget=',DbgS(Widget),' Event^.theIn=',Event^._in,
    ' LCLObject=',dbgsName(LCLobject)]);
  CurFocusWidget:=PGtkWidget(GetFocus);
  if CurFocusWidget<>nil then begin
    LCLObject:=GetNearestLCLObject(CurFocusWidget);
    DebugLn('GTKillFocusCB GetFocus=',dbgs(CurFocusWidget),' ParentLCLObject=',dbgsName(LCLObject));
  end;
  {$ENDIF}
  Result:=CallBackDefaultReturn;
end;

function GtkEntryDelayClearCursorPos(AGtkWidget: Pointer): GBoolean; cdecl;
var
  Info: PWidgetInfo;
  p: Pgchar;
  AStart,AEnd: gint;
begin
  Result := (AGtkWidget <> nil) and (GTK_IS_WIDGET(AGtkWidget));
  if Result then
  begin
    g_idle_remove_by_data(AGtkWidget);
    Info := GetWidgetInfo(AGtkWidget);
    if Info <> nil then
    begin
      gtk_editable_get_selection_bounds(PGtkEditable(AGtkWidget),@AStart, @AEnd);
      p := gtk_editable_get_chars(PGtkEditable(AGtkWidget), AStart, AEnd);
      if (AStart <> AEnd) then
        gtk_clipboard_set_text(gtk_clipboard_get(GDK_SELECTION_PRIMARY), p, -1);
      gtk_editable_select_region(PGtkEditable(AGtkWidget), 0, 0);
      g_free(p);
    end;
  end;
end;

function GTKKillFocusCBAfter({%H-}widget: PGtkWidget; {%H-}event:PGdkEventFocus;
  data: gPointer) : GBoolean; cdecl;
var
  Mess : TLMessage;
  Info: PWidgetInfo;
  AStart,AEnd: gint;
  AForm: TCustomForm;
{$IFDEF VerboseFocus}
  LCLObject: TObject;
  CurFocusWidget: PGtkWidget;
{$ENDIF}
begin
  {$IFDEF EventTrace}
  EventTrace('killfocusCBAfter', data);
  {$ENDIF}
  //DebugLn('GTKKillFocusCBAfter ',DbgSName(TObject(Data)),' ',GetWidgetDebugReport(Widget));
  {$IFDEF VerboseFocus}
  NeedShiftUpdateAfternFocus := True;   // <- JRA: this doesn't look like simply log !!!
  LCLObject:=TObject(data);
  DebugLnEnter(['GTKillFocusCBAfter INIT Widget=',DbgS(Widget),' Event^.theIn=',Event^._in,
    ' LCLObject=',dbgsName(LCLObject)]);
  CurFocusWidget:=PGtkWidget(GetFocus);
  if CurFocusWidget<>nil then begin
    LCLObject:=GetNearestLCLObject(CurFocusWidget);
    DebugLn('GetFocus=',DbgS(CurFocusWidget),' ParentLCLFocus=', dbgsName(LCLObject));
  end;
  {$ENDIF}

  ResetDefaultIMContext;

  // do not send LM_KILLFOCUS message if widget is destroying itself
  if Assigned(Data) and
    not ((csDestroying in TComponent(Data).ComponentState) or
         (csDestroyingHandle in TControl(Data).ControlState)) then
  begin
    FillChar(Mess{%H-},SizeOf(Mess),0);
    Mess.msg := LM_KILLFOCUS;
    // do not release the capture widget here

    //TODO: fill in new focus
    //DebugLn(Format('Trace:TODO: [gtkkillfocusCB] %s  finish', [TObject(Data).ClassName]));
  
    DeliverMessage(Data,  Mess);
  end;

  // do not show selection when widget is unfocused
  // issues #18164,#21897,#23182
  if GtkWidgetIsA(Widget, gtk_type_entry) and Assigned(Data) then
  begin
    if (csDestroying in TComponent(Data).ComponentState) or
      (csDestroyingHandle in TControl(Data).ControlState) then
    begin
      // DebugLn('NOTICE: Control is destroying itself, do not add new idle timer for ',dbgsName(TControl(Data)));
      exit;
    end;
    AForm := GetParentForm(TControl(Data));
    if Assigned(AForm) and ((csDestroying in AForm.ComponentState) or
      (csDestroyingHandle in AForm.ControlState) or
      ((fsModal in AForm.FormState) and (AForm.ModalResult <> mrNone)) ) then
    begin
      // DebugLn('NOTICE: Parent form is destroying, do not add new idle timer for ',dbgsName(TControl(Data)));
      exit;
    end;

    g_idle_add(@GtkEntryDelayClearCursorPos, Widget);
    //save now CursorPos and SelStart in WidgetInfo
    if (Widget <> nil) then
    begin
      Info := GetWidgetInfo(Widget);
      if Info <> nil then
      begin
        if (Info^.LCLObject is TCustomEdit) then
        begin
          gtk_editable_get_selection_bounds(PGtkEditable(Widget),@AStart, @AEnd);
          Info^.CursorPos := Min(AStart, AEnd);
          Info^.SelLength := Abs(AEnd - AStart);
        end;
      end;
    end;
  end;

  Result:=true;
  {$IFDEF VerboseFocus}
  DebugLnExit('GTKillFocusCBAfter DONE');
  {$ENDIF}
end;

function GTKWindowStateEventCB(widget: PGtkWidget;
  state: PGdkEventWindowState; data: gpointer): gboolean; cdecl;
var
  TheForm: TCustomForm;
  SizeMsg: TLMSize;
  GtkWidth: LongInt;
  GtkHeight: LongInt;
  {$IFDEF HasX}
  NetAtom: TGdkAtom;
  AtomType: TGdkAtom;
  AIndex, ADesktop: pguint;
  AFormat: gint;
  ALength: gint;
  {$ENDIF}
begin
  Result := CallBackDefaultReturn;

  // if iconified in changed then OnIconify...

  if GTK_WIDGET_REALIZED(Widget) then
  begin
    if (GDK_WINDOW_STATE_WITHDRAWN and state^.changed_mask <> 0)
    or (GDK_WINDOW_STATE_WITHDRAWN and state^.new_window_state <> 0) then
    begin
      // visibility changed - this is another message block
      Exit;
    end;
    if TObject(Data) is TCustomForm then
    begin
      TheForm := TCustomForm(Data);
      //DebugLn(['GTKWindowStateEventCB ',DbgSName(TheForm),' new_window_state=',state^.new_window_state,' changed_mask=',state^.changed_mask]);
      if TheForm.Parent = nil then begin
        // toplevel window
        // send a WMSize Message (see TCustomForm.WMSize)
        // ToDo: this might be too early to use the Widget^.Allocation
        //    Either send this message later or find a better way to determine the size (including the client area)
        GtkWidth:=Widget^.Allocation.Width;
        if GtkWidth<0 then GtkWidth:=0;
        GtkHeight:=Widget^.Allocation.Height;
        if GtkHeight<0 then GtkHeight:=0;
        //debugln('GTKWindowStateEventCB ',DbgSName(TObject(Data)),' ',dbgs(state^.new_window_state),' ',WidgetFlagsToString(Widget));
        if ((GDK_WINDOW_STATE_ICONIFIED and state^.new_window_state)>0) then
        begin
          {$IFDEF HasX}
          NetAtom := gdk_atom_intern('_NET_WM_DESKTOP', True);
          if NetAtom > 0 then begin
            if gdk_property_get(Widget^.window, NetAtom, XA_CARDINAL,
              0, 4, 0, @AtomType, @AFormat, @ALength, @AIndex)
            then begin
              NetAtom := gdk_atom_intern('_NET_CURRENT_DESKTOP', True);
              if gdk_property_get(gdk_get_default_root_window, NetAtom, XA_CARDINAL,0, 4, 0, @AtomType, @AFormat, @ALength, @ADesktop)
              then if ADesktop^ <> AIndex^ then begin
                // form is not on active desktop => ignore
                g_free(ADesktop);
                g_free(AIndex);
                exit;
              end
              else begin
                g_free(ADesktop);
                g_free(AIndex);
              end;
            end;
          end;
          {$ENDIF}
          SizeMsg.SizeType := SIZE_MINIMIZED;
        end
        else if (GDK_WINDOW_STATE_MAXIMIZED and state^.new_window_state)>0 then
        begin
          // it can be both maximized + iconified and just loose iconified state
          if (state^.changed_mask and (GDK_WINDOW_STATE_MAXIMIZED or GDK_WINDOW_STATE_ICONIFIED)) = 0 then Exit;
          SizeMsg.SizeType := SIZE_MAXIMIZED;
        end
        else
          SizeMsg.SizeType := SIZE_RESTORED;

        // don't bother the LCL if nothing changed
        case SizeMsg.SizeType of
          SIZE_RESTORED: if TheForm.WindowState=wsNormal then exit;
          SIZE_MINIMIZED: if TheForm.WindowState=wsMinimized then exit;
          SIZE_MAXIMIZED: if TheForm.WindowState=wsMaximized then exit;
          SIZE_FULLSCREEN: if TheForm.WindowState=wsFullScreen then exit;
        end;

        with SizeMsg do
        begin
          Result := 0;
          Msg := LM_SIZE;
          SizeType := SizeType+Size_SourceIsInterface;
          Width := SmallInt(GtkWidth);
          Height := SmallInt(GtkHeight);
        end;
        {$IFDEF VerboseSizeMsg}
        DebugLn(['GTKWindowStateEventCB ',DbgSName(TheForm),
          ' GTK=',GtkWidth,'x',GtkHeight,
          ' LCL=',TheForm.Width,'x',TheForm.Height,
          ' SizeType=',SizeMsg.SizeType-Size_SourceIsInterface,'+Size_SourceIsInterface'
          ]);
        {$ENDIF}
        DeliverMessage(TheForm, SizeMsg);
        if (gtk_major_version = 2) and (gtk_minor_version <= 8) and
          (TheForm.WindowState = wsMaximized) then
            gtk_widget_queue_draw({%H-}PGtkWidget(TheForm.Handle));

        if (TheForm = Application.MainForm)
        and (GDK_WINDOW_STATE_ICONIFIED and state^.changed_mask <> 0) then
        begin
          if GDK_WINDOW_STATE_ICONIFIED and state^.new_window_state <> 0 then
            Application.IntfAppMinimize
          else
            Application.IntfAppRestore;
        end;
      end;
    end;
  end;
end;


function gtkdestroyCB(widget: PGtkWidget; data: gPointer) : GBoolean; cdecl;
var
  Mess: TLMessage;
  Info: PWidgetInfo;
begin
  Result := CallBackDefaultReturn;
  //DebugLn(['gtkdestroyCB ',GetWidgetDebugReport(Widget)]);
  
  Info:=GetWidgetInfo(Widget);
  if Info = nil then // this widget is already destroyed
    Exit;

  if (Data = nil) or (Info^.LCLObject <> TObject(Data)) then // this LCLObject does not use this widget anymore
    Exit;

  if (TObject(Data) is TWinControl) then
  begin
    if (not TWinControl(Data).HandleAllocated) then
    begin
      FreeWidgetInfo(Widget);
      Exit;
    end else
    if ({%H-}PGtkWidget(TWinControl(Data).Handle) <> Widget) then // the TWinControl does not use this widget anymore.
      Exit;
  end;

  {$IFDEF EventTrace}
  EventTrace('destroyCB', data);
  {$ENDIF}
  //DebugLn('gtkdestroyCB Data="',DbgSName(TObject(Data)),'" LCLObject="',DbgSName(Info^.LCLObject),'" ',GetWidgetDebugReport(Widget));
  FillChar(Mess{%H-}, SizeOf(Mess), 0);
  Mess.msg := LM_DESTROY;
  DeliverMessage(Data, Mess);

  // NOTE: if the destroy message is posted
  // we should post an info destroy message as well

  FreeWidgetInfo(Widget);
end;

procedure DestroyWindowFromPointCB(Widget: PGtkWidget; data: gPointer); cdecl;
begin
  if {%H-}PGtkWidget(LastWFPResult) <> Widget then Exit;
  LastWFPResult := 0;
  LastWFPMousePos := Point(High(Integer), High(Integer));
end;

function gtkdeleteCB( {%H-}widget : PGtkWidget; {%H-}event : PGdkEvent;
  data : gPointer) : GBoolean; cdecl;
var Mess : TLMessage;
begin
  FillChar(Mess{%H-},SizeOf(Mess),0);
  Mess.Msg:= LM_CLOSEQUERY;
  { Message results : True - do nothing, False - destroy or hide window }
  Result:= DeliverMessage(Data, Mess) = 0;
end;

function gtkresizeCB( {%H-}widget: PGtkWidget; data: gPointer) : GBoolean; cdecl;
//var
//   Mess : TLMessage;
begin
  Result := CallBackDefaultReturn;
  {$IFDEF EventTrace}
  EventTrace('resize', data);
  {$ENDIF}
//   Mess.msg := LM_RESIZE;
//   TControl(data).WindowProc(TLMessage(Mess));
  //DebugLn('Trace:TODO: [gtkresizeCB] fix (or remove) to new LM_SIZE');
//TObject(data).Dispatch(Mess);
end;

function gtkMonthChanged({%H-}Widget: PGtkWidget; data: gPointer) : GBoolean; cdecl;
var
  Mess: TLMessage;
begin
  Result := CallBackDefaultReturn;
  {$IFDEF EventTrace}
  EventTrace('month changed', data);
  {$ENDIF}
  FillChar(Mess{%H-},SizeOf(Mess),0);
  Mess.Msg := LM_MONTHCHANGED;
  DeliverPostMessage(Data, Mess);

  Result := CallBackDefaultReturn;
end;

{-------------------------------------------------------------------------------
  procedure DeliverMouseMoveMessage(Widget:PGTKWidget; Event: PGDKEventMotion;
    AWinControl: TWinControl);

  Translate a gdk mouse motion event into a LCL mouse move message and send it.

  Mouse coordinate mapping:

  Why mapping:
  An lcl control can consists of several gtk widgets, and any message to them is
  send to the lcl control. The gtk sends the coordinates relative to the
  emitting gdkwindow (not relative to the gtkwidget). And the area of a lcl
  control can belong to several gdkwindows. Therefore the mouse coordinates must
  be mapped.

  What the lcl expects:
  For Delphi compatibility the mouse coordinates must be relative to the client
  area of the control.
  That means for example if the mouse is over the top-left pixel of the client
  widget (mostly a gtkfixed widget), then 0,0 is send.
  If the mouse is on the top-left pixel of the container widget then the
  coordinates can be negative, if there is frame around the client area.
-------------------------------------------------------------------------------}
procedure DeliverMouseMoveMessage(Widget: PGTKWidget; Event: PGDKEventMotion;
  AWinControl: TWinControl);
var
  Msg: TLMMouseMove;
  ShiftState: TShiftState;
  MappedXY: TPoint;
begin
  CheckTransparentWindow({%H-}TLCLIntfHandle(widget), AWinControl);
  if (widget=nil) or (AWinControl=nil) then
    Exit;

  MappedXY := TranslateGdkPointToClientArea(Event^.Window,
                               Point(TruncToInt(Event^.X), TruncToInt(Event^.Y)),
                               {%H-}PGtkWidget(AWinControl.Handle));
  MappedXY := SubtractScoll({%H-}PGtkWidget(AWinControl.Handle), MappedXY);

  ShiftState := GTKEventStateToShiftState(Event^.State);
  with Msg do
  begin
    Msg := LM_MouseMove;

    XPos := MappedXY.X;
    YPos := MappedXY.Y;

    Keys := ShiftStateToKeys(ShiftState);

    Result := 0;
  end;

  // send the message directly to the LCL
  // (Posting the message via queue
  //  has the risk of getting out of sync with the gtk)
  NotifyApplicationUserInput(AWinControl, Msg.Msg);
  //DebugLn(['DeliverMouseMoveMessage ',dbgsName(AWinControl)]);
  DeliverMessage(AWinControl, Msg);

  // if dragmanager is started later then inform g_object issue #19914
  if GTK_IS_NOTEBOOK({%H-}PGtkWidget(AWinControl.Handle)) and
    DragManager.IsDragging and
    (g_object_get_data({%H-}PGObject(AWinControl.Handle),'lclnotebookdragging') = nil)
    then
      g_object_set_data({%H-}PGObject(AWinControl.Handle),
        'lclnotebookdragging', gpointer(PtrInt(1)));
end;

procedure FixListViewRubberBand(AWidget: PGtkWidget);
var
  Info: PWidgetInfo;
  IconView: PGtkIconView;
  Priv: _PGtkIconViewPrivate;
begin
  Info := GetWidgetInfo(AWidget);
  IconView := PGtkIconView(Info^.CoreWidget);
  Priv := IconView^.priv;

  if Priv^.doing_rubberband then
  begin
    Priv^.doing_rubberband := False;
    gtk_widget_queue_draw(AWidget);
  end;
end;

{-------------------------------------------------------------------------------
  function ControlGetsMouseMoveBefore(AControl: TControl): boolean;

  Returns true, if mouse move event should be sent before the widget itself
  reacts.
-------------------------------------------------------------------------------}
function ControlGetsMouseMoveBefore({%H-}AControl: TControl;
  const ABefore: Boolean; Event: PGDKEventMotion): boolean;
var
  ShiftState: TShiftState;
  Widget: PGtkWidget;
  MainView: PGtkWidget;
begin
  Result := True;
  // currently there are no controls, that need after events.
  if not ABefore then exit;

  // gtk2 column resizing ... issue #21354
  if (Event <> nil) and not (csDesigning in AControl.ComponentState) and
    (AControl is TListView) and
    (TListView(AControl).ViewStyle = vsReport) and
    (TListView(AControl).ShowColumnHeaders) then
  begin
    ShiftState := GTKEventStateToShiftState(Event^.State);
    if ssLeft in ShiftState then
    begin
      Widget := {%H-}PGtkWidget(TWinControl(AControl).Handle);
      if GTK_IS_SCROLLED_WINDOW(Widget) then
      begin
        MainView := gtk_bin_get_child(PGtkBin(Widget));
        if GTK_IS_TREE_VIEW(MainView) then
        begin
          // here we are
          if gtk_tree_view_get_bin_window(PGtkTreeView(MainView)) <> Event^.window then
            Result := False;
          //TODO: queue column resize when x < 0
          // gtk_tree_view_column_queue_resize(tree_column: PGtkTreeViewColumn)
        end;
      end;
    end;
  end else
  if (Event <> nil) and not (csDesigning in AControl.ComponentState) and
    (AControl is TWinControl) and
    (TWinControl(AControl).FCompStyle = csListView) and
    (TListView(AControl).ViewStyle in [vsIcon, vsSmallIcon]) and
    TListView(AControl).MultiSelect then
  begin
    ShiftState := GTKEventStateToShiftState(Event^.State);
    // issue #22991 - this fixes rubberbanding
    if [ssShift, ssAlt, ssCtrl, ssLeft, ssRight, ssMiddle, ssDouble] * ShiftState = [] then
      FixListViewRubberBand({%H-}PGtkWidget(TWinControl(AControl).Handle));
  end;
end;

procedure GTKGetDevicePointer(win: PGdkWindow; dev: PGdkDevice;
  x, y: pgdouble; mask: PGdkModifierType);
var
  axes: pgdouble;
  i: Integer;
begin
  axes := g_new(SizeOf(gdouble), dev^.num_axes);
  gdk_device_get_state(dev, win, axes, mask);

  for i := 0 to dev^.num_axes - 1 do
    if (x^ <> 0) and (dev^.axes[i].use = GDK_AXIS_X) then
      x^ := axes[i]
    else if (y^ <> 0) and (dev^.axes[i].use = GDK_AXIS_Y) then
      y^ := axes[i];

  g_free(axes);
end;


{-------------------------------------------------------------------------------
  GTKMotionNotify
  Params: widget: PGTKWidget; event: PGDKEventMotion; data: gPointer
  Returns: GBoolean

  Called whenever the mouse is moved over a widget.
  The gtk event is translated into a lcl MouseMove message.

-------------------------------------------------------------------------------}
function gtkMotionNotify(Widget:PGTKWidget; Event: PGDKEventMotion;
  Data: gPointer): GBoolean; cdecl;
const
  LastModifierKeys: TShiftState = [];
var
  DesignOnlySignal: boolean;
  ShiftState: TShiftState;
  ACtl: TWinControl;
begin
  Result := CallBackDefaultReturn;

  if (Event^.is_hint <> 0) and (Event^._type = GDK_MOTION_NOTIFY) then
    GTKGetDevicePointer(Event^.window, Event^.device,
      @Event^.x, @Event^.y, @Event^.state);

  {$IFDEF VerboseMouseBugfix}
  DesignOnlySignal:=GetDesignOnlySignalFlag(Widget,dstMouseMotion);
  DebugLn('[GTKMotionNotify] ',
    DbgSName(TControl(Data)),
    ' Widget=',DbgS(Widget),
    ' DSO=',dbgs(DesignOnlySignal),
    ' Event^.X=',dbgs(TruncToInt(Event^.X)),' Event^.Y=',dbgs(TruncToInt(Event^.Y))
    );
  {$ENDIF}

  ShiftState := GTKEventStateToShiftState(Event^.State);

  if (ShiftState*[ssShift, ssCtrl, ssAlt, ssSuper] <> LastModifierKeys) or NeedShiftUpdateAfterFocus
  then begin
    NeedShiftUpdateAfterFocus := False;
    LastModifierKeys := ShiftState*[ssShift, ssCtrl, ssAlt, ssSuper];
    //DebugLn(['Adjust KeyStateList in MouseMove',Integer(LastModifierKeys)]);
    UpdateShiftState(GTK2WidgetSet.KeyStateList, LastModifierKeys);
  end;

  {$IFDEF VerboseMouseCapture}
  if (MouseCaptureWidget = Widget) and ([ssLeft,ssRight,ssMiddle]*ShiftState=[]) then
    DebugLn(['gtkMotionNotify gtk capture without mouse down: ',GetWidgetDebugReport(Widget)]);
  {$ENDIF}

  if not (csDesigning in TComponent(Data).ComponentState) then
  begin
    DesignOnlySignal := GetDesignOnlySignalFlag(Widget, dstMouseMotion);
    if DesignOnlySignal then exit;
    if not ControlGetsMouseMoveBefore(TControl(Data), True, Event) then exit;
  end else
  begin
    // stop the signal, so that the widget does not auto react
    g_signal_stop_emission_by_name(PGTKObject(Widget), 'motion-notify-event');
    Result := CallBackDefaultReturn; // why not True if we want to stop it?
  end;

  ACtl := TWinControl(Data);
  if not (csDesigning in ACtl.ComponentState) and
     not (csCaptureMouse in ACtl.ControlStyle) and
    ([ssLeft,ssRight,ssMiddle]*ShiftState <> []) and
    not (ACtl is TCustomForm) and not (ACtl is TScrollBar)
    and not DragManager.IsDragging then
  begin
    if (Event^.x < 0) or (Event^.y < 0) or
      (Event^.x > ACtl.Width) or (Event^.y > ACtl.Height) then
      Exit(True);
  end;
  DeliverMouseMoveMessage(Widget,Event, ACtl);
  if ACtl.FCompStyle = csWinControl then
    Result := True; // stop signal
end;

{-------------------------------------------------------------------------------
  GTKMotionNotifyAfter
  Params: widget: PGTKWidget; event: PGDKEventMotion; data: gPointer
  Returns: GBoolean

  Called whenever the mouse is moved over a widget as last handler.
-------------------------------------------------------------------------------}
function GTKMotionNotifyAfter(widget:PGTKWidget; event: PGDKEventMotion;
  data: gPointer): GBoolean; cdecl;
begin
  Result := true; // stop event propagation

  if (Event^.is_hint <> 0) and (Event^._type = GDK_MOTION_NOTIFY) then
    GTKGetDevicePointer(Event^.window, Event^.device,
      @Event^.x, @Event^.y, @Event^.state);

  {$IFDEF VerboseMouseBugfix}
  DebugLn('[GTKMotionNotifyAfter] ',
    DbgSName(TControl(Data)));
  {$ENDIF}

  // stop the signal, so that it is not sent to the parent widgets
  g_signal_stop_emission_by_name(PGTKObject(Widget),'motion-notify-event');

  if (csDesigning in TComponent(Data).ComponentState) then exit;
  if ControlGetsMouseMoveBefore(TControl(Data), True, Event) then exit;

  DeliverMouseMoveMessage(Widget,Event, TWinControl(Data));
end;


// restore old column sizing after dblclick. issue #18381
function ReturnColumnSizing(AGtkWidget: Pointer): gboolean; cdecl;
var
  AIndex: PtrInt;
  ASizing: TGtkTreeViewColumnSizing;
  Column: PGtkTreeViewColumn;
  ColWidth: gint;
begin
  Result := AGtkWidget <> nil;
  if Result then
  begin
    if g_object_get_data(PGObject(AGtkWidget),'lcl-column-resized-dblclick') <> nil then
    begin
      AIndex := {%H-}PtrInt(g_object_get_data(PGObject(AGtkWidget),'lcl-column-resized-dblclick') - 1);
      ASizing := TGtkTreeViewColumnSizing({%H-}PtrUInt(g_object_get_data(PGObject(AGtkWidget),'lcl-column-resized-dblclick-oldsizing')) - 1);
      g_object_set_data(PGObject(AGtkWidget),'lcl-column-resized-dblclick', nil);
      g_object_set_data(PGObject(AGtkWidget),'lcl-column-resized-dblclick-oldsizing', nil);
      if (AIndex >= 0) then
      begin
        Column := gtk_tree_view_get_column(PGtkTreeView(AGtkWidget), AIndex);
        ColWidth := gtk_tree_view_column_get_width(Column);
        gtk_tree_view_column_set_sizing(Column, ASizing);
        gtk_tree_view_column_set_fixed_width(Column, ColWidth);
      end;
    end;
    g_idle_remove_by_data(AGtkWidget);
  end;
end;

{resizes column to like autosize does when dblclicked separator. issue #18381}
function ResizeColumnOnDblClick({%H-}ACtl: TWinControl; ScrolledWin: PGtkWidget;
  TreeView: PGtkTreeView; const AMouseCoord: TPoint): Boolean;
var
  Adjustment: PGtkAdjustment;
  List: PGList;
  Column: PGtkTreeViewColumn;
  i, Accu: PtrInt;
  xoffset: Integer;
  Pt: TPoint;
  CurSizing: TGtkTreeViewColumnSizing;
  ColIndex: Integer;
  ColWidth: Integer;
begin
  Result := True;
  Pt := AMouseCoord;
  Accu := 0;
  ColIndex := -1;
  // think about horizontal scrollbar position too !
  Adjustment := gtk_scrolled_window_get_hadjustment(PGtkScrolledWindow(ScrolledWin));
  if Adjustment <> nil then
    xoffset := Round(gtk_adjustment_get_value(Adjustment))
  else
    xoffset := 0;

  List := gtk_tree_view_get_columns(TreeView);
  try
    for i := 0 to g_list_length(List) - 1 do
    begin
      Column := g_list_nth_data(List, i);
      if Column = nil then
        continue;
      if gtk_tree_view_column_get_visible(Column) then
      begin
        ColWidth := gtk_tree_view_column_get_width(Column);
        if (Accu + ColWidth + 3 >= Pt.X + xoffset) then
        begin
          // DebugLn('NOTICE: GtkTreeView column resizing on dblclick ',i);
          CurSizing := gtk_tree_view_column_get_sizing(Column);
          if gtk_tree_view_column_get_resizable(Column) and
            (CurSizing <> GTK_TREE_VIEW_COLUMN_AUTOSIZE) then
          begin
            gtk_tree_view_column_set_sizing(Column, GTK_TREE_VIEW_COLUMN_AUTOSIZE);
            gtk_tree_view_column_set_resizable(Column, True);

            ColIndex := i;
            // we are adding i + 1 since if i = 0 then ptr is null !
            g_object_set_data(PGObject(TreeView),'lcl-column-resized-dblclick', {%H-}GPointer(ColIndex + 1));
            Accu := Ord(CurSizing);
            // we are adding Accu + 1 since if Accu = 0 then ptr is null !
            g_object_set_data(PGObject(TreeView),'lcl-column-resized-dblclick-oldsizing', {%H-}GPointer(Accu + 1));
            Accu := g_idle_add(@ReturnColumnSizing, TreeView);
            break;
          end;
          break;
        end;
        Accu := Accu + ColWidth + 3 {section separator offset};
      end;
    end;
    Result := not (ColIndex >= 0);
  finally
    g_list_free(List);
  end;
end;

{-------------------------------------------------------------------------------
  function ControlGetsMouseDownBefore(AControl: TControl): boolean;

  Returns true, if mouse down event should be sent before the widget istelf
  reacts.
-------------------------------------------------------------------------------}
function ControlGetsMouseDownBefore(AControl: TControl;
  {%H-}AWidget: PGtkWidget; Event : PGdkEventButton): boolean;
var
  Widget: PGtkWidget;
  MainView: PGtkWidget;
  Pt: TPoint;
begin
  Result := True;
  if AControl = nil then exit;

  if not (csDesigning in AControl.ComponentState) and
    (Event^.button = 1) and
    (gdk_event_get_type(Event) = GDK_2BUTTON_PRESS) and
    (AControl is TWinControl) and
    (TWinControl(AControl).FCompStyle = csListView) and
    (TListView(AControl).ViewStyle = vsReport) and
    (TListView(AControl).ShowColumnHeaders) then
  begin
    Widget := {%H-}PGtkWidget(TWinControl(AControl).Handle);
    if GTK_IS_SCROLLED_WINDOW(Widget) then
    begin
      MainView := gtk_bin_get_child(PGtkBin(Widget));
      if GTK_IS_TREE_VIEW(MainView) then
      begin
        if gtk_tree_view_get_bin_window(PGtkTreeView(MainView)) <> Event^.window then
        begin
          Pt.X := Round(Event^.x_root);
          Pt.Y := Round(Event^.y_root);
          ScreenToClient(TWinControl(AControl).Handle, Pt);
          Result := ResizeColumnOnDblClick(TWinControl(AControl), Widget,
            PGtkTreeView(MainView), Pt);
        end;
      end;
    end;
  end else
  if not (csDesigning in AControl.ComponentState) and
    (Event^.button = 1) and
    (gdk_event_get_type(Event) = GDK_BUTTON_PRESS) and
    (AControl is TWinControl) and
    (TWinControl(AControl).FCompStyle = csListView) and
    (TListView(AControl).ViewStyle in [vsIcon, vsSmallIcon]) and
    TListView(AControl).MultiSelect then
  begin
    // issue #22991 - this fixes crash after click on listview when modal form
    // is closed
    FixListViewRubberBand({%H-}PGtkWidget(TWinControl(AControl).Handle));
  end;
end;


{-------------------------------------------------------------------------------
We must stop delivery of events from scrollbars of GtkScrollable, otherwise
if we make an double click on scollbar button, and after that click into
our control client area we need 2 click to make it focused.
gtk_signal_connect_after() is used, otherwise our scrollbar won't react on
such event.
-------------------------------------------------------------------------------}
function gtk2ScrollBarMouseBtnPress(widget: PGtkWidget; event: pgdkEventButton;
  data: gPointer): GBoolean; cdecl;
begin
  Result := True;
end;

{-------------------------------------------------------------------------------
We must stop delivery of events from scrollbars of GtkScrollable, otherwise
if we make an double click on scollbar button, and after that click into
our control client area we need 2 click to make it focused.
gtk_signal_connect_after() is used, otherwise our scrollbar won't react on
such event.
-------------------------------------------------------------------------------}
function gtk2ScrollBarMouseBtnRelease(widget: PGtkWidget; event: pgdkEventButton;
  data: gPointer): GBoolean; cdecl;
begin
  Result := True;
end;

{-------------------------------------------------------------------------------
  gtkMouseBtnPress
  Params: widget: PGTKWidget; event: PGDKEventMotion; data: gPointer
  Returns: GBoolean

  Called whenever the mouse is over a widget and a mouse button is pressed.
-------------------------------------------------------------------------------}
function gtkMouseBtnPress(widget: PGtkWidget; event: pgdkEventButton; data: gPointer): GBoolean; cdecl;

  procedure CheckListSelection;
  var
    List: PGlist;
    ListWidget: PGtkList;
    R: TRect;
    Info: PWinWidgetInfo;
  begin
    // When in browse mode and a listbox is focused and nothing is selected,
    // the first item is focused.
    // Clicking with the mouse on this item won't select it.
    Info := GetWidgetInfo(Widget);
    if Info = nil then Exit;
    if Info^.CoreWidget = nil then Exit;
    if not GtkWidgetIsA(Info^.CoreWidget, gtk_list_get_type) then
      Exit;
    ListWidget := PGtkList(Info^.CoreWidget);
    // Check mode
    if selection_mode(ListWidget^) <> GTK_SELECTION_BROWSE then Exit;

    // Check selection
    List := ListWidget^.selection;
    if (List <> nil) and (List^.data <> nil) then Exit;

    // Check if there are children
    List := ListWidget^.children;
    if List = nil then Exit;
    if List^.Data = nil then Exit;

    // we need only to check the first
    with PGtkWidget(List^.Data)^.allocation do
      R := Bounds(X, Y, Width, Height);
    if not PtInRect(R, Point(Trunc(event^.X), Trunc(event^.Y))) then Exit;
    // Select it
    gtk_list_item_select(PGtkListItem(List^.Data));
  end;

  procedure FixTabControlFocusBehaviour;
  var
    Info: PWidgetInfo;
  begin
    {gtk_notebook have weird behaviour when clicked.
     if there's active control on page it'll loose it's
     focus and trigger OnExit (tab is taking focus).
     issue #20493}
    Info := GetWidgetInfo(Widget);
    if not gtk_widget_is_focus(Widget) then
      Include(Info^.Flags, wwiTabWidgetFocusCheck);
  end;

var
  DesignOnlySignal: boolean;
  Msg: TLMContextMenu;
  x, y: gint;
  W: PGtkWidget;
  Info: PWidgetInfo;
  Old: TObject;
  Path: PGtkTreePath;
  Column: PGtkTreeViewColumn;
  {$IFDEF VerboseMouseBugfix}
  AWinControl: TWinControl;
  {$ENDIF}
begin
  Result := CallBackDefaultReturn;

  {$IFDEF VerboseMouseBugfix}
  AWinControl := TWinControl(Data);
  DebugLn('');
  DesignOnlySignal:=GetDesignOnlySignalFlag(Widget,dstMousePress);
  DebugLn('[gtkMouseBtnPress] ',
    DbgSName(AWinControl),
    ' Widget=',DbgS(Widget),
    ' ControlWidget=',DbgS(AWinControl.Handle),
    ' DSO='+dbgs(DesignOnlySignal),
    ' '+dbgs(TruncToInt(Event^.X)),',',dbgs(TruncToInt(Event^.Y)),
    ' Type='+dbgs(gdk_event_get_type(Event)));
  {$ENDIF}

  {$IFDEF EventTrace}
  EventTrace('Mouse button Press', data);
  {$ENDIF}

  ResetDefaultIMContext;

  //debugln('[gtkMouseBtnPress] calling DeliverMouseDownMessage Result=',dbgs(Result));
  {$IFDEF Gtk2CallMouseDownBeforeContext}
  if DeliverMouseDownMessage(Widget, Event, TWinControl(Data))<>0 then
  begin
    // Debugln(['[gtkMouseBtnPress] DeliverMouseDownMessage handled, stopping event']);
    g_signal_stop_emission_by_name(PGTKObject(Widget), 'button-press-event');
    exit(false);
  end;
  {$ENDIF}

  if not (csDesigning in TComponent(Data).ComponentState) then
  begin
    // fix gtklist selection first
    CheckListSelection;

    DesignOnlySignal := GetDesignOnlySignalFlag(Widget, dstMousePress);
    if DesignOnlySignal then exit;
    if not ControlGetsMouseDownBefore(TControl(Data), Widget, Event) then Exit;

    if Event^.button = 1 then
    begin
      //CaptureMouseForWidget(CaptureWidget,mctGTKIntf);
      if (TControl(Data) is TCustomTabControl) and
        not (csDesigning in TControl(Data).ComponentState) then
          FixTabControlFocusBehaviour;
    end
    else
    // if LCL process LM_CONTEXTMENU then stop the event propagation
    if (Event^.button = 3) then
    begin
      W := Widget;
      gdk_display_get_pointer(gtk_widget_get_display(Widget), nil, @x, @y, nil);
      Old := nil;
      while W <> nil do
      begin
        Info := GetWidgetInfo(W);
        if (Info <> nil) and (Info^.LCLObject <> Old) then
        begin
          Old := Info^.LCLObject;
          FillChar(Msg{%H-}, SizeOf(Msg), #0);
          Msg.Msg := LM_CONTEXTMENU;
          Msg.hWnd := {%H-}HWND(W);
          Msg.XPos := x;
          Msg.YPos := y;

          Result := DeliverMessage(Old, Msg) <> 0;
          if Result then break;
        end;
        // check if widget has a standard popup menu
        if (W = widget) and Assigned(GTK_WIDGET_GET_CLASS(W)^.popup_menu) then
          break;
        W := gtk_widget_get_parent(W);
      end;

      {emit selection change when right mouse button pressed
       otherwise LCL is not updated since ChangeLock = 1 in case
       of pressing right mouse button and 'changed' signal never reach lcl.
       Issues #16972, #17888. }
      if Result and GTK_IS_TREE_VIEW(Widget) and (event^.button = 3) then
      begin
        Column := gtk_tree_view_get_column(GTK_TREE_VIEW(Widget), 0);
        Path:=nil;
        if gtk_tree_view_get_path_at_pos(GTK_TREE_VIEW(Widget), Round(Event^.x), Round(Event^.y),
          Path, Column, @x, @y) then
        begin
          gtk_tree_view_set_cursor(GTK_TREE_VIEW(Widget), Path, Column, False);
          gtk_widget_queue_draw(Widget);
        end;
        g_signal_stop_emission_by_name(PGTKObject(Widget), 'button-press-event');
      end;

    end;
  end else begin
    if (event^.Button=1) and
       (TControl(Data) is TCustomTabControl) then
    begin
      // clicks on the tab control should be handled by the gtk (switching page)
    end
    else
    begin
      // stop the signal, so that the widget does not auto react
      //DebugLn(['gtkMouseBtnPress stop signal']);
      g_signal_stop_emission_by_name(PGTKObject(Widget), 'button-press-event');
    end;
  end;
  {$IFDEF Gtk2CallMouseDownBeforeContext}
  {$ELSE}
  //debugln('[gtkMouseBtnPress] calling DeliverMouseDownMessage Result=',dbgs(Result));
  DeliverMouseDownMessage(Widget, Event, TWinControl(Data));
  {$ENDIF}
  //debugln(['gtkMouseBtnPress END Control=',DbgSName(TObject(Data))]);
end;


{-------------------------------------------------------------------------------
  procedure DeliverMouseDownMessage(widget: PGtkWidget; event : pgdkEventButton;
    AWinControl: TWinControl);

  Translate a gdk mouse press event into a LCL mouse down message and send it.
-------------------------------------------------------------------------------}
function DeliverMouseDownMessage(widget: PGtkWidget; event : pgdkEventButton;
  AWinControl: TWinControl): PtrInt;
const
  LastModifierKeys: TShiftState = [];
  WHEEL_DELTA : array[Boolean] of Integer = (-120, 120);
var
  MessI : TLMMouse;
  MessE : TLMMouseEvent;
  ShiftState: TShiftState;
  MappedXY: TPoint;
  EventXY: TPoint;
  AClip: gtk2.PGtkClipboard;
  AClipText: String;

{off $DEFINE VerboseMouseBugfix}

  function CheckMouseButtonDown(MouseButton, BtnKey: longint): boolean;
  begin
    Result := False;

    case gdk_event_get_type(Event) of
      gdk_2button_press, gdk_3button_press:
      // the gtk itself has detected a double/triple click
      begin
        // they were already detected and sent to the LCL
        // -> skip this message
        exit;
      end;
    end;

    if (LastMouse.Down) then
      if (gdk_event_get_type(Event) in [GDK_BUTTON_PRESS, gdk_2button_press, gdk_3button_press]) then
      begin
        // After a LastMouse.Down has to follow a LastMouse.Up. Issue #32199
        if LastMouse.WinControl <> AWinControl then
          Exit;
      end
      else
      begin
        {$IFDEF VerboseMouseBugfix}
        DebugLn('DeliverMouseDownMessage: NO CLICK: LastMouse.Down=',dbgs(LastMouse.Down),
                ' Event^.theType=',dbgs(gdk_event_get_type(Event)));
        {$ENDIF}
        Exit;
      end;

    if (LastMouse.Down) and (gdk_event_get_type(Event) = GDK_BUTTON_PRESS) and
      (csDesigning in AWinControl.ComponentState) then
        exit;

    MessI.Msg := CheckMouseButtonDownUp({%H-}TLCLIntfHandle(widget), AWinControl,
                                        LastMouse, EventXY, MouseButton, True);
    MessI.Keys := MessI.Keys or BtnKey;
    if BtnKey in [MK_XBUTTON1, MK_XBUTTON2] then
      MessI.Keys :=  MessI.Keys or BtnKey shl 11;
    case LastMouse.ClickCount of
      2: MessI.Keys := MessI.Keys or MK_DOUBLECLICK;
      3: MessI.Keys := MessI.Keys or MK_TRIPLECLICK;
      4: MessI.Keys := MessI.Keys or MK_QUADCLICK;
    end;

    {$IFDEF VerboseMouseBugfix}
    DebugLn('  ClickCount=',dbgs(LastMouse.ClickCount));
    {$ENDIF}

    //DebugLn('DeliverMouseDownMessage ',DbgSName(AWinControl),' Mapped=',dbgs(MappedXY.X),',',dbgs(MappedXY.Y),' Event=',dbgs(EventXY.X),',',dbgs(EventXY.Y),' ',dbgs(LastMouse.ClickCount));
    Result := True;
  end;

begin
  Result := 0;

  if GTK_IS_TREE_VIEW(widget)
  and (gtk_tree_view_get_bin_window(PGtkTreeView(widget)) <> Event^.window) then
    Exit;

  CheckTransparentWindow({%H-}TLCLIntfHandle(widget), AWinControl);
  if (widget=nil) or (AWinControl=nil) then
    Exit;

  EventXY := Point(TruncToInt(Event^.X), TruncToInt(Event^.Y));
  ShiftState := GTKEventStateToShiftState(Event^.State);

  if ShiftState*[ssShift, ssCtrl, ssAlt, ssSuper] <> LastModifierKeys
  then begin
    LastModifierKeys := ShiftState*[ssShift, ssCtrl, ssAlt, ssSuper];
    //DebugLn(['Adjust KeyStateList in MouseBtnDown',Integer(LastModifierKeys)]);
    UpdateShiftState(GTK2WidgetSet.KeyStateList, LastModifierKeys);
  end;

  MappedXY := TranslateGdkPointToClientArea(Event^.Window, EventXY,
                                            {%H-}PGtkWidget(AWinControl.Handle));
  MappedXY := SubtractScoll({%H-}PGtkWidget(AWinControl.Handle), MappedXY);
  //DebugLn('DeliverMouseDownMessage ',DbgSName(AWinControl),' Mapped=',dbgs(MappedXY.X),',',dbgs(MappedXY.Y),' Event=',dbgs(EventXY.X),',',dbgs(EventXY.Y));

  if event^.Button in [4, 5] then
  begin
    // this is a mouse wheel event
    MessE.Msg := LM_MOUSEWHEEL;
    MessE.WheelDelta := WHEEL_DELTA[event^.Button = 4];
    MessE.X := MappedXY.X;
    MessE.Y := MappedXY.Y;
    MessE.State := ShiftState;
    MessE.UserData := AWinControl;
    MessE.Button := 0;

    // send the message directly to the LCL
    NotifyApplicationUserInput(AWinControl, MessE.Msg);
    Result:=DeliverMessage(AWinControl, MessE);
  end
  else
  if event^.Button in [6, 7] then
  begin
    // this is a mouse wheel horizontal-scroll event
    MessE.Msg := LM_MOUSEHWHEEL;
    MessE.WheelDelta := WHEEL_DELTA[event^.Button = 7];
    MessE.X := MappedXY.X;
    MessE.Y := MappedXY.Y;
    MessE.State := ShiftState;
    MessE.UserData := AWinControl;
    MessE.Button := 0;

    // send the message directly to the LCL
    NotifyApplicationUserInput(AWinControl, MessE.Msg);
    Result:=DeliverMessage(AWinControl, MessE);
  end
  else
  begin
    // a normal mouse button is pressed
    MessI.Keys := 0;
    case event^.Button of
      1: if not CheckMouseButtonDown(1, MK_LBUTTON) then Exit;
      2: if not CheckMouseButtonDown(3, MK_MBUTTON) then Exit;
      3: if not CheckMouseButtonDown(2, MK_RBUTTON) then Exit;
      8: if not CheckMouseButtonDown(4, MK_XBUTTON1) then Exit;
      9: if not CheckMouseButtonDown(5, MK_XBUTTON2) then Exit;
      else
        begin
          MessI.Msg := LM_NULL;
          exit;
        end;
    end; // case

    MessI.XPos := MappedXY.X;
    MessI.YPos := MappedXY.Y;

    MessI.Keys := MessI.Keys or ShiftStateToKeys(ShiftState);

    MessI.Result:=0;

    {Gtk2 should always send LM_SETFOCUS first, as qt and win32 does. issues #24308, #31900}
    if ((MessI.Msg = LM_LBUTTONDOWN) or (MessI.Msg = LM_RBUTTONDOWN) or
      (MessI.Msg = LM_MBUTTONDOWN) or (MessI.Msg = LM_LBUTTONDBLCLK) or
      (MessI.Msg = LM_XBUTTONDOWN)) and
      not AWinControl.Focused and AWinControl.CanFocus and
      not (csDesigning in AWinControl.ComponentState) then
    begin
      if (AWinControl is TCustomEdit) then
      begin
        AClipText := '';
        AClip := gtk_clipboard_get(GDK_SELECTION_PRIMARY);
        if gtk_clipboard_get_owner(AClip) = AClip then
          AClip := nil;
        if (AClip <> nil) and gtk_clipboard_wait_is_text_available(AClip) then
          AClipText := gtk_clipboard_wait_for_text(AClip);
        LCLIntf.SetFocus(AWinControl.Handle);
        if Assigned(AClip) then
          gtk_clipboard_set_text(AClip, PgChar(AClipText), length(AClipText));
      end else
      begin
        if (AWinControl is TCustomTabControl)
        or (AWinControl is TCustomPanel) then
          // do not grab focus. issue #32237, #32515
        else
          LCLIntf.SetFocus(AWinControl.Handle);
      end;
    end;

    // send the message directly to the LCL
    NotifyApplicationUserInput(AWinControl, MessI.Msg);
    Result := DeliverMessage(AWinControl, MessI);

    // issue #19914
    if (Result = 0) and (Event^.button = 1) and
      GTK_IS_NOTEBOOK({%H-}PGtkWidget(AWinControl.Handle)) and
      DragManager.IsDragging then
    begin
      g_object_set_data({%H-}PGObject(AWinControl.Handle),
        'lclnotebookdragging', gpointer(PtrInt(1)));
    end;
  end;
end;

{-------------------------------------------------------------------------------
  gtkMouseBtnPressAfter
  Params: widget: PGTKWidget; event: PGDKEventMotion; data: gPointer
  Returns: GBoolean

  Called whenever the mouse is over a widget and a mouse button is pressed.
  This is the last handler.
-------------------------------------------------------------------------------}
function gtkMouseBtnPressAfter(widget: PGtkWidget; event : pgdkEventButton;
  data: gPointer) : GBoolean; cdecl;
begin
  Result := True;

  {$IFDEF VerboseMouseBugfix}
  debugln('[gtkMouseBtnPressAfter] ',
    DbgSName(TObject(Data)),
    ' Widget=',DbgS(Widget), ' ', GetWidgetClassName(Widget),
    ' ',dbgs(TruncToInt(Event^.X)),',',dbgs(TruncToInt(Event^.Y)));
  {$ENDIF}

  ResetDefaultIMContext;

  // stop the signal, so that it is not sent to the parent widgets
  g_signal_stop_emission_by_name(PGTKObject(Widget), 'button-press-event');

  if (csDesigning in TComponent(Data).ComponentState) then exit;
  if ControlGetsMouseDownBefore(TControl(Data),Widget, Event) then exit;

  //debugln('[gtkMouseBtnPressAfter] calling DeliverMouseDownMessage');
  DeliverMouseDownMessage(Widget, Event, TWinControl(Data));
end;

{-------------------------------------------------------------------------------
  function ControlGetsMouseUpBefore(AControl: TControl): boolean;

  Returns true, if mouse up event should be sent before the widget istelf
  reacts.
-------------------------------------------------------------------------------}
function ControlGetsMouseUpBefore({%H-}AControl: TControl): boolean;
begin
  {$NOTE ControlGetsMouseUpBefore always return true. See if still necessary}
  Result:=true;
end;

{-------------------------------------------------------------------------------
  procedure DeliverMouseUpMessage(widget: PGtkWidget; event : pgdkEventButton;
    AWinControl: TWinControl);

  Translate a gdk mouse release event into a LCL mouse up message and send it.

  returns true, if message was handled by LCL
-------------------------------------------------------------------------------}
function DeliverMouseUpMessage(widget: PGtkWidget; event: pgdkEventButton;
  AWinControl: TWinControl): boolean;
var
  MessI : TLMMouse;
  ShiftState: TShiftState;
  MappedXY: TPoint;
  EventXY: TPoint;

  function CheckMouseButtonUp(MouseButton: longint; BtnShiftState: TShiftStateEnum): boolean;
  begin
    MessI.Msg := CheckMouseButtonDownUp({%H-}TLCLIntfHandle(widget),
                           AWinControl, LastMouse, EventXY, MouseButton, False);
    Include(ShiftState, BtnShiftState);
    Result := True;
 end;

begin
  Result := False;
  CheckTransparentWindow({%H-}TLCLIntfHandle(widget), AWinControl);
  if (widget=nil) or (AWinControl=nil) then
    Exit;
  EventXY := Point(TruncToInt(Event^.X), TruncToInt(Event^.Y));
  MappedXY := TranslateGdkPointToClientArea(Event^.Window,
                               EventXY,
                               {%H-}PGtkWidget(AWinControl.Handle));
  MappedXY := SubtractScoll({%H-}PGtkWidget(AWinControl.Handle), MappedXY);
  //DebugLn(['DeliverMouseUpMessage ',GetWidgetDebugReport(Widget),' ',dbgsName(AWinControl),' ',dbgs(MappedXY)]);

  ShiftState := GTKEventStateToShiftState(Event^.State);

  case event^.Button of
    1: if not CheckMouseButtonUp(1, ssLeft) then Exit;
    2: if not CheckMouseButtonUp(3, ssMiddle) then Exit;
    3: if not CheckMouseButtonUp(2, ssRight) then Exit;
    8: if not CheckMouseButtonUp(4, ssExtra1) then Exit;
    9: if not CheckMouseButtonUp(5, ssExtra2) then Exit;
  else
    begin
      MessI.Msg := LM_NULL;
      Exit;
    end;
  end; // case

  MessI.XPos := MappedXY.X;
  MessI.YPos := MappedXY.Y;

  // do not send button in shiftstate on mouse up.issue #20916
  case event^.Button of
    1: ShiftState := ShiftState - [ssLeft];
    2: ShiftState := ShiftState - [ssMiddle];
    3: ShiftState := ShiftState - [ssRight];
  end;
  MessI.Keys := ShiftStateToKeys(ShiftState);
  case LastMouse.ClickCount of
    2: MessI.Keys := MessI.Keys or MK_DOUBLECLICK;
    3: MessI.Keys := MessI.Keys or MK_TRIPLECLICK;
    4: MessI.Keys := MessI.Keys or MK_QUADCLICK;
  end;

  if MessI.Msg <> LM_NULL then
  begin
    // send the message directly to the LCL
    // (Posting the message via queue
    //  has the risk of getting out of sync with the gtk)
    if event^.button in [8,9] then
      MessI.Keys := MessI.Keys or ((event^.button - 7) shl 16);
    MessI.Result := 0;
    NotifyApplicationUserInput(AWinControl, MessI.Msg);
    DeliverMessage(AWinControl, MessI);
    if not AWinControl.HandleAllocated then
      Result := True
    else if MessI.Result <> 0 then
    begin
      // issue #19914
      if GTK_IS_NOTEBOOK(Widget) then
      begin
        if g_object_get_data({%H-}PGObject(AWinControl.Handle),'lclnotebookdragging') <> nil then
        begin
          g_object_steal_data({%H-}PGObject(AWinControl.Handle),'lclnotebookdragging');
          exit;
        end;
      end;
      // handled by the LCL
      //DebugLn(['DeliverMouseUpMessage msg was handled by the LCL, Stopping signal ...']);
      g_signal_stop_emission_by_name(PGTKObject(Widget), 'button-release-event');
      Result := True;
    end;
  end;
end;

{-------------------------------------------------------------------------------
  gtkMouseBtnRelease
  Params: widget: PGTKWidget; event: PGDKEventMotion; data: gPointer
  Returns: GBoolean

  Called whenever the mouse is over a widget and a mouse button is released.
-------------------------------------------------------------------------------}
function gtkMouseBtnRelease(widget: PGtkWidget; event : pgdkEventButton;
  data: gPointer) : GBoolean; cdecl;
var
  DesignOnlySignal: boolean;
  AForm: TCustomForm;
begin
  Result := CallBackDefaultReturn;
  {$IFDEF VerboseMouseBugfix}
  DesignOnlySignal:=GetDesignOnlySignalFlag(Widget,dstMouseRelease);
  DebugLn(['[gtkMouseBtnRelease] A ',DbgSName(TObject(Data)),' ',
    ' Widget=',DbgS(Widget),
    ' Event.time=',event^.time,
    ' DSO=',DesignOnlySignal,
    ' ',TruncToInt(Event^.X),',',TruncToInt(Event^.Y),' Btn=',event^.Button]);
  {$ENDIF}

  //DebugLn('EEE1 MouseRelease Widget=',DbgS(Widget),
  //' EventMask=',DbgS(gdk_window_get_events(Widget^.Window)),
  //' GDK_BUTTON_RELEASE_MASK=',DbgS(GDK_BUTTON_RELEASE_MASK));

  ResetDefaultIMContext;

  if not (csDesigning in TComponent(Data).ComponentState) then
  begin
    DesignOnlySignal := GetDesignOnlySignalFlag(Widget, dstMouseRelease);

    if (TControl(Data) is TCustomListView) and
      (TListView(Data).ViewStyle in [vsIcon, vsSmallIcon]) and
      TListView(Data).MultiSelect then
    begin
      // fixed crash.See issue #22778
      FixListViewRubberBand(Widget);
    end;

    if DesignOnlySignal or (not ControlGetsMouseUpBefore(TControl(Data))) then
    begin
      ReleaseMouseCapture;
      Exit;
    end;
  end else
  begin
    // stop the signal, so that the widget does not auto react
    if not (TControl(Data) is TCustomTabControl) then
    begin
      g_signal_stop_emission_by_name(PGTKObject(Widget), 'button-release-event');
      Result := not CallBackDefaultReturn;
    end;
  end;
  if DeliverMouseUpMessage(Widget, Event, TWinControl(Data)) then
  begin
    ReleaseMouseCapture;
    if not DragManager.IsDragging then
      Result := not CallBackDefaultReturn
    else
    begin
      // workaround for gtk2 bug where "clicked" isn't triggered
      // because of Result=TRUE and we started modal form from OnDropDown event.
      // see issue http://bugs.freepascal.org/view.php?id=14318 for details.
      if GTK_IS_BUTTON(Widget) then
      begin
        AForm := GetParentForm(TWinControl(Data));
        if (AForm <> nil) and (fsModal in AForm.FormState) then
          gtk_button_clicked(PGtkButton(Widget));
      end;
    end;
  end else
    ReleaseMouseCapture;
end;

{-------------------------------------------------------------------------------
  gtkMouseBtnReleaseAfter
  Params: widget: PGTKWidget; event: PGDKEventMotion; data: gPointer
  Returns: GBoolean

  Called whenever the mouse is over a widget and a mouse button is released.
  This is the last handler.
-------------------------------------------------------------------------------}
function gtkMouseBtnReleaseAfter(widget: PGtkWidget; event : pgdkEventButton;
  data: gPointer) : GBoolean; cdecl;
begin
  Result := True;

  {$IFDEF VerboseMouseBugfix}
  DebugLn('[gtkMouseBtnReleaseAfter] ',DbgSName(TObject(Data)),' ',
    ' Widget=',DbgS(Widget),
    ' ',dbgs(TruncToInt(Event^.X)),',',dbgs(TruncToInt(Event^.Y)),' Btn=',dbgs(event^.Button));
  {$ENDIF}

  // stop the signal, so that it is not sent to the parent widgets
  {$NOTE See if is necessary to stop emission. Return true is enough to avoid propagation}
  g_signal_stop_emission_by_name(PGTKObject(Widget),'button-release-event');

  ResetDefaultIMContext;

  if (csDesigning in TComponent(Data).ComponentState) then exit;
  if ControlGetsMouseUpBefore(TControl(Data)) then exit;

  DeliverMouseUpMessage(Widget,Event,TWinControl(Data));
end;

function gtkMouseWheelCB(widget: PGtkWidget; event: PGdkEventScroll;
  data: gPointer): GBoolean; cdecl;
var
  AWinControl: TWinControl;
  EventXY: TPoint;
  ShiftState: TShiftState;
  MappedXY: TPoint;
  MessE : TLMMouseEvent;
begin
  Result := False;

  AWinControl:=TWinControl(Data);
  CheckTransparentWindow({%H-}TLCLIntfHandle(widget), AWinControl);
  if (widget=nil) or (AWinControl=nil) then
    Exit;
  EventXY:=Point(TruncToInt(Event^.X),TruncToInt(Event^.Y));
  ShiftState := GTKEventStateToShiftState(Event^.State);
  MappedXY:=TranslateGdkPointToClientArea(Event^.Window,EventXY,
                                          {%H-}PGtkWidget(AWinControl.Handle));
  MappedXY := SubtractScoll({%H-}PGtkWidget(AWinControl.Handle), MappedXY);
  //DebugLn('gtkMouseWheelCB ',DbgSName(AWinControl),' Mapped=',dbgs(MappedXY.X),',',dbgs(MappedXY.Y),' Event=',dbgs(EventXY.X),',',dbgs(EventXY.Y));

  // this is a mouse wheel event
  FillChar(MessE{%H-},SizeOf(MessE),0);
  case event^.direction of
    GDK_SCROLL_UP: begin MessE.Msg := LM_MOUSEWHEEL; MessE.WheelDelta := 120; end;
    GDK_SCROLL_DOWN: begin MessE.Msg := LM_MOUSEWHEEL; MessE.WheelDelta := -120; end;
    GDK_SCROLL_LEFT: begin MessE.Msg := LM_MOUSEHWHEEL; MessE.WheelDelta := -120; end;
    GDK_SCROLL_RIGHT: begin MessE.Msg := LM_MOUSEHWHEEL; MessE.WheelDelta := 120; end;
  else
    exit;
  end;
  MessE.X := MappedXY.X;
  MessE.Y := MappedXY.Y;
  MessE.State := ShiftState;
  MessE.UserData := AWinControl;
  MessE.Button := 0;

  // send the message directly to the LCL
  NotifyApplicationUserInput(AWinControl, MessE.Msg);
  if DeliverMessage(AWinControl, MessE) <> 0 then
    Result := True; // message handled by LCL, stop processing
end;


function gtkclickedCB(widget: PGtkWidget; data: gPointer) : GBoolean; cdecl;
var
  Mess: TLMessage;
begin
  Result := CallBackDefaultReturn;
  //DebugLn('[gtkclickedCB] ',TObject(Data).ClassName);
  EventTrace('clicked', data);
  if (LockOnChange(PgtkObject(Widget),0)>0) then exit;
  Mess.Msg := LM_CLICKED;
  DeliverMessage(Data, Mess);
end;

function gtkEnterCB(widget: PGtkWidget; data: gPointer) : GBoolean; cdecl;
var
  Mess : TLMessage;
begin
  Result := CallBackDefaultReturn;

  {$IFDEF EventTrace}
  EventTrace('enter', data);
  {$ENDIF}

  if csDesigning in TControl(Data).ComponentState then begin
    // stop the signal, so that the widget does not auto react
    g_signal_stop_emission_by_name(PGTKObject(Widget),'enter');
  end;

  Mess.msg := LM_MOUSEENTER;
  DeliverMessage(Data, Mess);
end;

function gtkLeaveCB(widget: PGtkWidget; data: gPointer) : GBoolean; cdecl;
var
  Mess : TLMessage;
begin
  Result := CallBackDefaultReturn;

  {$IFDEF EventTrace}
  EventTrace('leave', data);
  {$ENDIF}

  if csDesigning in TControl(Data).ComponentState then begin
    // stop the signal, so that the widget does not auto react
    g_signal_stop_emission_by_name(PGTKObject(Widget),'leave');
  end;

  Mess.msg := LM_MOUSELEAVE;
  DeliverMessage(Data, Mess);
end;

function gtksize_allocateCB(widget: PGtkWidget; size: pGtkAllocation;
  data: gPointer) : GBoolean; cdecl;
{$IFDEF VerboseSizeMsg}
var
  w, h: Gint;
{$ENDIF}

begin
  Result := CallBackDefaultReturn;

  EventTrace('size-allocate', data);

  //with Size^ do DebugLn(Format('Trace:[gtksize_allocateCB] %s --> X: %d, Y: %d, Width: %d, Height: %d', [TObject(data).ClassName, X, Y, Width, Height]));

  if not (TObject(Data) is TControl) then begin
    // owner is not TControl -> ignore
    DebugLn('WARNING: gtksize_allocateCB: Data is not TControl. Data=',
            DbgS(Data),' ',GetWidgetClassName(Widget));
    if Data<>nil then
      DebugLn('  Data=',TObject(Data).ClassName);
    RaiseGDBException('');
    exit;
  end;

  {$IFDEF VerboseSizeMsg}
  w:=0; h:=0;
  if Widget^.window<>nil then
    gdk_window_get_size(Widget^.window,@w,@h);
  DebugLn(['gtksize_allocateCB: ',
    DbgSName(TControl(Data)),
    ' widget=',GetWidgetDebugReport(Widget),
    ' fixwidget=',DbgS(GetFixedWidget(Widget)),
    ' NewSize=',Size^.Width,',',Size^.Height,
    ' GtkPos=',Widget^.allocation.x,',',Widget^.allocation.y,
               ',',Widget^.allocation.width,'x',Widget^.allocation.height,
    ' LCLPos=',TControl(Data).Left,',',TControl(Data).Top,
               ',',TControl(Data).Width,'x',TControl(Data).Height,
    ' gdkwindow=',w,'x',h]);
  {$ENDIF}
  {$IFDEF VerboseFormPositioning}
  if TControl(Data) is TCustomForm then
    DebugLn('VFP gtksize_allocateCB: ',TControl(Data).ClassName,' ',dbgs(Size^.X),',',dbgs(Size^.Y));
  {$ENDIF}
  SendSizeNotificationToLCL(Widget);
end;

function gtksize_allocate_client({%H-}widget: PGtkWidget; {%H-}size: pGtkAllocation;
  data: gPointer): GBoolean; cdecl;
var
  MainWidget: PGtkWidget;
  ClientWidget: PGtkWidget;
begin
  Result := CallBackDefaultReturn;

  if (TObject(Data) is TWinControl) then
  begin
    {$IFDEF VerboseSizeMsg}
    DebugLn('gtksize_allocate_client: ',
      TControl(Data).Name,':',TControl(Data).ClassName,
      ' widget=',DbgS(Widget),
      ' NewSize=',dbgs(Size^.Width),',',dbgs(Size^.Height),
      ' Allocation='+dbgs(widget^.Allocation.Width)+'x'+dbgs(Widget^.Allocation.Height),
      ' Requisiton='+dbgs(widget^.Requisition.Width)+'x'+dbgs(Widget^.Requisition.Height)
      );
    {$ENDIF}
    if not TWinControl(Data).HandleAllocated then begin
      exit;
    end;
    MainWidget:={%H-}PGtkWidget(TWinControl(Data).Handle);
    ClientWidget:=GetFixedWidget(MainWidget);
    if GTK_WIDGET_REALIZED(ClientWidget) then begin
      // the gtk resizes bottom to top, that means the
      // inner widget (client area) is resized before the outer widget
      // is resized. Because the LCL reads both sizes, keep this message back.
      SaveClientSizeNotification(ClientWidget);
    end;
  end else begin
    // owner is not TWinControl -> ignore
    DebugLn('WARNING: gtksize_allocate_client: Data is not TWinControl. Data=',
            DbgS(Data));
    exit;
  end;
end;

function gtkconfigureevent( widget: PGtkWidget; event : PgdkEventConfigure;
  data: gPointer) : GBoolean; cdecl;
var
  Allocation : TGtkAllocation;
begin

  { This signal is emitted for top level controls only, i.e. only controls
    that are not children. Thus, we register this event only for forms.
    This event is fired when the form is sized, moved or changes Z order.
  }

  FillChar(Allocation{%H-},SizeOf(TGtkAllocation),0);
  with Allocation do begin
    X:= Event^.X;
    Y:= Event^.Y;
    Width:= Event^.Width;
    Height:= Event^.Height;
  end;
  Result:= gtksize_allocateCB( Widget, @Allocation, Data);
end;

function gtkInsertText(widget: PGtkWidget; char : pChar;
  NewTextLength : Integer; Position : pgint; data: gPointer) : GBoolean; cdecl;
var
  Memo: TCustomMemo;
  CurrLength, CutLength: integer;
begin
  Result := CallBackDefaultReturn;

  { GTK does not provide its own max. length for memos
    we have to do our own. }

  if TObject(Data) is TCustomMemo then begin
    if (NewTextLength = 1) and (char^ = #13) and (LineEnding = #10) then
      char^ := #10;
    Memo:= TCustomMemo(Data);
    if Memo.MaxLength <= 0 then Exit;

    CurrLength:= gtk_text_get_length(PGtkText(widget));
    if CurrLength + NewTextLength <= Memo.MaxLength then Exit;

    CutLength:= CurrLength + NewTextLength - Memo.MaxLength;

    if NewTextLength - CutLength > 0 then
      gtk_editable_insert_text(PGtkEditable(widget), char,
                               NewTextLength - CutLength, Position);

    g_signal_stop_emission_by_name(PGtkObject(widget), 'insert_text');
  end;
  if TObject(Data) is TCustomEdit then
    if (NewTextLength = 1) and (char^ = #13) then
      g_signal_stop_emission_by_name(PGtkObject(widget), 'insert_text');
end;

function gtkSetEditable( {%H-}widget: PGtkWidget; data: gPointer) : GBoolean; cdecl;
var
  Mess : TLMessage;
begin
  EventTrace('Set Editable', data);
  Mess.msg := LM_SETEDITABLE;
  Result:= DeliverMessage(Data, Mess) = 0;
end;

function gtkMoveWord( {%H-}widget: PGtkWidget; data: gPointer) : GBoolean; cdecl;
var
   Mess : TLMessage;
begin
  EventTrace('Move Word', data);
  Mess.msg := LM_MOVEWORD;
  Result:= DeliverMessage(Data, Mess) = 0;
end;

function gtkMovePage( {%H-}widget: PGtkWidget; data: gPointer) : GBoolean; cdecl;
var
  Mess : TLMessage;
begin
  EventTrace('Move Page', data);
  Mess.msg := LM_MOVEPAGE;
  Result:= DeliverMessage(Data, Mess) = 0;
end;

function gtkMoveToRow( {%H-}widget: PGtkWidget; data: gPointer) : GBoolean; cdecl;
var
  Mess : TLMessage;
begin
  EventTrace('Move To Row!!', data);
  Mess.msg := LM_MOVETOROW;
  Result:= DeliverMessage(Data, Mess) = 0;
end;

function gtkMoveToColumn( {%H-}widget: PGtkWidget; data: gPointer) : GBoolean; cdecl;
var
  Mess : TLMessage;
begin
  EventTrace('MoveToColumn', data);
  Mess.msg := LM_MOVETOCOLUMN;
  Result:= DeliverMessage(Data, Mess) = 0;
end;

function gtkKillChar( {%H-}widget: PGtkWidget; data: gPointer) : GBoolean; cdecl;
var
  Mess : TLMessage;
begin
  EventTrace('Kill Char', data);
  Mess.msg := LM_KILLCHAR;
  Result:= DeliverMessage(Data, Mess) = 0;
end;

function gtkKillWord( {%H-}widget: PGtkWidget; data: gPointer) : GBoolean; cdecl;
var
  Mess : TLMessage;
begin
  EventTrace('Kill Word', data);
  Mess.msg := LM_KILLWORD;
  Result:= DeliverMessage(Data, Mess) = 0;
end;

function gtkKillLine( {%H-}widget: PGtkWidget; data: gPointer) : GBoolean; cdecl;
var
  Mess : TLMessage;
begin
  EventTrace('Kill Line', data);
  Mess.msg := LM_KILLLINE;
  Result:= DeliverMessage(Data, Mess) = 0;
end;

function gtkCutToClip( widget: PGtkWidget; data: gPointer) : GBoolean; cdecl;
var
  Mess : TLMessage;
begin
  EventTrace('Cut to clip', data);
  Mess.msg := LM_CUT;
  Result:= DeliverMessage(Data, Mess) = 0;
end;

function gtkCopyToClip( {%H-}widget: PGtkWidget; data: gPointer) : GBoolean; cdecl;
var
  Mess : TLMessage;
begin
  EventTrace('Copy to Clip', data);
  Mess.msg := LM_COPY;
  Result:= DeliverMessage(Data, Mess) = 0;
end;

function gtkPasteFromClip( widget: PGtkWidget; data: gPointer) : GBoolean; cdecl;
var
  Mess : TLMessage;
begin
  EventTrace('Paste from clip', data);
  Mess.msg := LM_PASTE;
  Result:= DeliverMessage(Data, Mess) = 0;
end;

function gtkValueChanged({%H-}widget: PGtkWidget; data: gPointer) : GBoolean; cdecl;
var
  Mess : TLMessage;
begin
  Result := CallBackDefaultReturn;
  EventTrace('Value changed', data);
  Mess.msg := LM_CHANGED;
  DeliverMessage(Data, Mess);
end;

{------------------------------------------------------------------------------
  Method: gtkTimerCB
  Params:  Data - pointer TGtkITimerInfo structure
  Returns: 1    - 1 tells gtk to restart the timer
           0    - 0 will stop the gtk timer

  Callback for gtk timer.

  WARNING: There seems to be a bug in gtk-1.2.x which breaks
           gtk_timeout_remove so we have to dispose data here & return 0
           (s.a. KillTimer).
 ------------------------------------------------------------------------------}
function gtkTimerCB(Data: gPointer): gBoolean; cdecl;
var
  TimerInfo: PGtkITimerinfo;
begin
  EventTrace ('TimerCB', nil);
  Result := GdkFalse;  // assume: timer will stop

  TimerInfo:=PGtkITimerinfo(Data);

  if (FTimerData=nil) or (FTimerData.IndexOf(Data)<0) then begin
    {$IFDEF VerboseTimer}
    DebugLn('gtkTimerCB Timer was killed: TimerInfo=',DbgS(TimerInfo));
    {$ENDIF}
    // timer was killed
    Result:=GdkFalse; // stop timer
  end else begin
    {$IFDEF VerboseTimer}
    DebugLn('gtkTimerCB Timer Event: TimerInfo=',DbgS(TimerInfo));
    {$ENDIF}
    if TimerInfo^.TimerFunc <> nil
    then begin
      // Call users timer function
      //DebugLn(['gtkTimerCB ']);
      TimerInfo^.TimerFunc;
      Result:=GdkTrue; // timer will go on
    end
    else begin
      Result := GdkFalse; // stop timer
    end;
  end;

  if (Result<>GdkFalse) and (FTimerData.IndexOf(Data)<0) then begin
    // timer was killed
    // -> stop timer
    Result:=GdkFalse;
  end;

  if Result=GdkFalse then begin
    {$IFDEF VerboseTimer}
    DebugLn('gtkTimerCB Timer was STOPPED: TimerInfo=',DbgS(TimerInfo));
    {$ENDIF}
    // timer will be stopped
    // -> free timer data, if not already done
    if (FTimerData<>nil) and (FTimerData.IndexOf(Data)>=0) then begin
      FTimerData.Remove(Data);
      Dispose (TimerInfo);     // free memory with timer data
    end;
  end;
end;

function gtkFocusInNotifyCB (widget : PGtkWidget; {%H-}event : PGdkEvent;
  data : gpointer) : GBoolean; cdecl;
var
  MessI : TLMEnter;
begin
  Result := CallBackDefaultReturn;
  //DebugLn('[gtkFocusInNotifyCB] ',TControl(data).Name,':',TObject(data).ClassName);
  {$IFDEF EventTrace}
  EventTrace ('FocusInNotify (alias Enter)', data);
  {$ENDIF}

  if csDesigning in TControl(Data).ComponentState then begin
    // stop the signal, so that the widget does not auto react
    g_signal_stop_emission_by_name(PGTKObject(Widget),'focus-in-event');
  end;

  MessI.msg := LM_Enter;
  DeliverMessage(Data, MessI);
end;

function gtkFocusOutNotifyCB (widget : PGtkWidget; {%H-}event : PGdkEvent;
  data : gpointer) : GBoolean; cdecl;
var
  MessI : TLMExit;
begin
  Result := CallBackDefaultReturn;
  //DebugLn('[gtkFocusOutNotifyCB] ',TControl(data).Name,':',TObject(data).ClassName);
  {$IFDEF EventTrace}
  EventTrace ('FocusOutNotify (alias Exit)', data);
  {$ENDIF}

  if csDesigning in TControl(Data).ComponentState then begin
    // stop the signal, so that the widget does not auto react
    g_signal_stop_emission_by_name(PGTKObject(Widget),'focus-out-event');
  end;

  MessI.msg := LM_Exit;
  DeliverMessage(Data, MessI);
end;

function get_gtk_scroll_type(range: PGTKRange): TGtkScrollType;
type
  TUnOpaqueTimer=record
    timeout_id: guint;
    ScrollType: TGTkScrollType;
  end;
  PUnOpaqueTimer=^TUnopaqueTimer;
begin
  if (gtk_major_version=2) and (gtk_minor_version<6) and
     (Range^.Timer<>nil) then
    { gtk2 pre gtk2.6 ONLY, tested gtk2.0.
      Later versions (gtk2.6+) have a change-value signal that includes scrolltype anyways }

    Result := PUnOpaqueTimer(Range^.Timer)^.ScrollType
  else
    Result := GTK_SCROLL_NONE;
end;

{$IFDEF VerboseGtkScrollbars}
procedure DebugScrollStyle(Scroll: LongInt);
begin
  DbgOut('TYPE=');
  case Scroll of
    GTK_SCROLL_NONE: DbgOut('GTK_SCROLL_NONE ');
    GTK_SCROLL_STEP_BACKWARD: DbgOut('GTK_SCROLL_STEP_BACKWARD ');
    GTK_SCROLL_STEP_FORWARD: DbgOut('GTK_SCROLL_STEP_FORWARD ');
    GTK_SCROLL_PAGE_BACKWARD: DbgOut('GTK_SCROLL_PAGE_BACKWARD ');
    GTK_SCROLL_PAGE_FORWARD: DbgOut('GTK_SCROLL_PAGE_FORWARD ');
    GTK_SCROLL_JUMP: DbgOut('GTK_SCROLL_JUMP ');
    GTK_SCROLL_STEP_UP: DbgOut('GTK_SCROLL_STEP_UP');
    GTK_SCROLL_STEP_DOWN: DbgOut('GTK_SCROLL_STEP_DOWN');
    GTK_SCROLL_PAGE_UP: DbgOut('GTK_SCROLL_PAGE_UP');
    GTK_SCROLL_PAGE_DOWN: DbgOut('GTK_SCROLL_PAGE_DOWN');
    GTK_SCROLL_STEP_LEFT: DbgOut('GTK_SCROLL_STEP_LEFT');
    GTK_SCROLL_STEP_RIGHT: DbgOut('GTK_SCROLL_STEP_RIGHT');
    GTK_SCROLL_PAGE_LEFT: DbgOut('GTK_SCROLL_PAGE_LEFT');
    GTK_SCROLL_PAGE_RIGHT: DbgOut('GTK_SCROLL_PAGE_RIGHT');
    GTK_SCROLL_START: DbgOut('GTK_SCROLL_START');
    GTK_SCROLL_END: DbgOut('GTK_SCROLL_END');
    else
      DbgOut(IntToStr(Scroll), '->?');
  end;
end;
{$ENDIF VerboseGtkScrollbars}

function ScrollTypeToSbCode(IsVertSB: boolean; ScrollType: TGtkScrollType;
                            UpdatePolicy: TGtkUpdateType): Integer;
begin
  case ScrollType of
    GTK_SCROLL_STEP_BACKWARD:
      if IsVertSB then
        Result := SB_LINEUP
      else
        Result := SB_LINELEFT;
    GTK_SCROLL_STEP_FORWARD:
      if IsVertSB then
        Result := SB_LINEDOWN
      else
        Result := SB_LINERIGHT;
    GTK_SCROLL_PAGE_BACKWARD:
      if IsVertSB then
        Result := SB_PAGEUP
      else
        Result := SB_PAGELEFT;
    GTK_SCROLL_PAGE_FORWARD:
      if IsVertSB then
        Result := SB_PAGEDOWN
      else
        Result := SB_PAGERIGHT;
    GTK_SCROLL_STEP_UP:
      Result := SB_LINEUP;
    GTK_SCROLL_STEP_DOWN:
      Result := SB_LINEDOWN;
    GTK_SCROLL_PAGE_UP:
      Result := SB_PAGEUP;
    GTK_SCROLL_PAGE_DOWN:
      Result := SB_PAGEDOWN;
    GTK_SCROLL_STEP_LEFT:
      Result := SB_LINELEFT;
    GTK_SCROLL_STEP_RIGHT:
      Result := SB_LINERIGHT;
    GTK_SCROLL_PAGE_LEFT:
      Result := SB_PAGELEFT;
    GTK_SCROLL_PAGE_RIGHT:
      Result := SB_PAGERIGHT;
    GTK_SCROLL_START:
      if IsVertSB then
        Result := SB_TOP
      else
        Result := SB_LEFT;
    GTK_SCROLL_END:
      if IsVertSB then
        Result := SB_BOTTOM
      else
        Result := SB_RIGHT;
    else
      begin
        {$IFDEF VerboseGtkScrollbars}
        debugln('ScrollTypeToSbCode: Scroll_type=', IntToStr(ScrollType));
        {$Endif}
        if UpdatePolicy=GTK_UPDATE_CONTINUOUS then
          Result := SB_THUMBTRACK
        else
          Result := SB_THUMBPOSITION;
      end;
  end;
end;

function GTKHScrollCB(Adjustment: PGTKAdjustment; data: GPointer): GBoolean; cdecl;
var
  Msg: TLMHScroll;
  Scroll: PGtkRange;
  ScrollType: TGtkScrollType;
begin
  Result := CallBackDefaultReturn;
  //DebugLn(Format('Trace:[GTKHScrollCB] Value: %d', [RoundToInt(Adjustment^.Value)]));
  Scroll := PgtkRange(g_object_get_data(PGObject(Adjustment), odnScrollBar));
  if Scroll<>nil then begin
    Msg.Msg := LM_HSCROLL;
    with Msg do begin
      Pos := Round(Adjustment^.Value);
      if Pos < High(SmallPos)
      then SmallPos := Pos
      else SmallPos := High(SmallPos);
      ScrollBar := HWND({%H-}PtrUInt(Scroll));
      ScrollType := get_gtk_scroll_type(Scroll);
      ScrollCode := ScrollTypeToSbCode(False, ScrollType,
                                       gtk_range_get_update_policy(Scroll));
    end;
    DeliverMessage(Data, Msg);
  end;
end;

function GTKVScrollCB(Adjustment: PGTKAdjustment; data: GPointer): GBoolean; cdecl;
var
  Msg: TLMVScroll;
  Scroll: PGtkRange;
  ScrollType: TGtkScrollType;
begin
  //TODO: implement SB_THUMBPOSITION message after track is finished

  Result := CallBackDefaultReturn;
  {$IFDEF SYNSCROLLDEBUG}
  DebugLn(Format('Trace:[GTKVScrollCB] Value: %d', [RoundToInt(Adjustment^.Value)]));
  {$ENDIF}
  Scroll := PgtkRange(g_object_get_data(PGObject(Adjustment), odnScrollBar));
  if Scroll<>nil then begin
    Msg.Msg := LM_VSCROLL;
    with Msg do begin
      Pos := Round(Adjustment^.Value);
      if Pos < High(SmallPos)
      then SmallPos := Pos
      else SmallPos := High(SmallPos);
      //DebugLn('GTKVScrollCB A Adjustment^.Value=',dbgs(Adjustment^.Value),' SmallPos=',dbgs(SmallPos));
      ScrollBar := HWND({%H-}PtrUInt(Scroll));
      ScrollType := get_gtk_scroll_type(Scroll);
      // GTK1 has a bug with wheel mouse. It sometimes gives the wrong direction.
      ScrollCode := ScrollTypeToSbCode(True, ScrollType,
                                       gtk_range_get_update_policy(Scroll));
      //DebugLn('GTKVScrollCB B Adjustment^.Value=',dbgs(Adjustment^.Value),' ScrollCode=',dbgs(ScrollCode),' ScrollType=',dbgs(ScrollType));
    end;
    DeliverMessage(Data, Msg);
  end;
end;

function Gtk2RangeScrollCB(ARange: PGtkRange; AScrollType: TGtkScrollType;
                  AValue: gdouble; AWidgetInfo: PWidgetInfo): gboolean; cdecl;
var
  Msg: TLMVScroll;
  MaxValue: gdouble;
  Widget: PGTKWidget;
begin
  Result := CallBackDefaultReturn;

  Widget:=PGTKWidget(ARange);
  {$IFDEF SYNSCROLLDEBUG}
  DebugLn(Format('Trace:[Gtk2RangeScrollCB] Value: %d', [RoundToInt(AValue)]));
  {$ENDIF}
  if G_OBJECT_TYPE(ARange) = gtk_hscrollbar_get_type then
    Msg.Msg := LM_HSCROLL
  else
    Msg.Msg := LM_VSCROLL;

  if ARange^.adjustment^.page_size > 0 then
    MaxValue := ARange^.adjustment^.upper - ARange^.adjustment^.page_size
  else
    MaxValue := ARange^.adjustment^.upper;

  if (AValue > MaxValue) then
    AValue := MaxValue
  else if (AValue < ARange^.adjustment^.lower) then
    AValue := ARange^.adjustment^.lower;

  with Msg do
  begin
    Pos := Round(AValue);
    if Pos < High(SmallPos) then
      SmallPos := Pos
    else
      SmallPos := High(SmallPos);

    ScrollBar := HWND({%H-}PtrUInt(ARange));
    ScrollCode := GtkScrollTypeToScrollCode(AScrollType);
  end;
  DeliverMessage(AWidgetInfo^.LCLObject, Msg);

  if Msg.Scrollcode=SB_THUMBTRACK then
  begin
    if Widget^.state = 0 then
    begin
      Msg.ScrollCode := SB_THUMBPOSITION;
      DeliverMessage(AWidgetInfo^.LCLObject, Msg);
      Msg.ScrollCode:=SB_ENDSCROLL;
      DeliverMessage(AWidgetInfo^.LCLObject, Msg);
    end;
  end
  else Widget^.state := 1;

  if (AWidgetInfo^.LCLObject is TScrollingWinControl) and
  ((Msg.ScrollCode=SB_LINEUP) or (Msg.ScrollCode=SB_LINEDOWN)) then
  Result:=True;
end;

procedure Gtk2RangeValueChanged(ARange: PGTKRange; data: GPointer); cdecl;
var
  Msg: TLMVScroll;
  MaxValue: gdouble;
  Widget: PGTKWidget;
  AValue: gDouble;
begin
  // used only by TScrollingWinControl ! #issue #25479
  Widget := PGTKWidget(ARange);
  if G_OBJECT_TYPE(ARange) = gtk_hscrollbar_get_type then
    Msg.Msg := LM_HSCROLL
  else
    Msg.Msg := LM_VSCROLL;

  AValue := gtk_range_get_value(ARange);

  if ARange^.adjustment^.page_size > 0 then
    MaxValue := ARange^.adjustment^.upper - ARange^.adjustment^.page_size
  else
    MaxValue := ARange^.adjustment^.upper;

  if (AValue > MaxValue) then
    AValue := MaxValue
  else if (AValue < ARange^.adjustment^.lower) then
    AValue := ARange^.adjustment^.lower;

  with Msg do
  begin
    Pos := Round(AValue);
    if Pos < High(SmallPos) then
      SmallPos := Pos
    else
      SmallPos := High(SmallPos);

    ScrollBar := HWND({%H-}PtrUInt(ARange));
    ScrollCode := SB_THUMBTRACK;
  end;

  // do not send messages to LCL if we are already synced.
  if (Msg.Msg = LM_VSCROLL) and
    (TScrollingWinControl(PWidgetInfo(Data)^.LCLObject).VertScrollBar.Position = Msg.Pos) then
    exit
  else
  if (Msg.Msg = LM_HSCROLL) and
    (TScrollingWinControl(PWidgetInfo(Data)^.LCLObject).HorzScrollBar.Position = Msg.Pos) then
    exit;

  DeliverMessage(PWidgetInfo(Data)^.LCLObject, Msg);

  if Msg.Scrollcode=SB_THUMBTRACK then
  begin
    if Widget^.state = 0 then
    begin
      Msg.ScrollCode := SB_THUMBPOSITION;
      DeliverMessage(PWidgetInfo(Data)^.LCLObject, Msg);
      Msg.ScrollCode:=SB_ENDSCROLL;
      DeliverMessage(PWidgetInfo(Data)^.LCLObject, Msg);
    end;
  end
  else Widget^.state := 1;
end;

function Gtk2RangeScrollPressCB(Widget: PGtkWidget;
  Event: PGdkEventButton; Data: gPointer): gboolean; cdecl;
begin
  Widget^.state := 2;
  Result := CallBackDefaultReturn;;
end;

function Gtk2RangeScrollReleaseCB(Widget: PGtkWidget;
  Event: PGdkEventButton; Data: gPointer): gboolean; cdecl;
var
  Avalue: gdouble;
  WidgetInfo: PWidgetInfo;
begin
  AValue:=PGtkRange(Widget)^.adjustment^.value;
  WidgetInfo:=GetWidgetInfo(Widget);
  if not Assigned(WidgetInfo) then
    WidgetInfo:=GetWidgetInfo(Widget^.parent);
  if Assigned(WidgetInfo) and (Widget^.state = 1) then
    Gtk2RangeScrollCB(PGtkRange(Widget), 0, AValue, WidgetInfo);
  Widget^.state := 0;
  Result := CallBackDefaultReturn;
end;

function Gtk2RangeUbuntuScrollCB(Adjustment: PGTKAdjustment; data: GPointer): GBoolean; cdecl;
var
  Msg: TLMVScroll;
  AWidgetInfo: PWidgetInfo;
  Scroll: PGtkRange;
  ScrollType: TGtkScrollType;
  LastPos: PtrInt;
begin
  Result := CallBackDefaultReturn;
  AWidgetInfo:=PWidgetInfo(Data);

  //debugln(['Gtk2RangeUbuntuScrollCB ',DbgSName(AWidgetInfo^.LCLObject)]);
  Scroll := PgtkRange(g_object_get_data(PGObject(Adjustment), odnScrollBar));
  if Scroll<>nil then begin
    FillByte(Msg{%H-},SizeOf(Msg),0);
    if Scroll^.orientation=GTK_ORIENTATION_VERTICAL then
      Msg.Msg := LM_VSCROLL
    else
      Msg.Msg := LM_HSCROLL;
    with Msg do begin
      Pos := Round(Adjustment^.Value);
      if Pos < High(SmallPos)
      then SmallPos := Pos
      else SmallPos := High(SmallPos);

      LastPos:={%H-}PtrInt(g_object_get_data(PGObject(Adjustment), odnScrollBarLastPos));
      if LastPos=Pos then begin
        //debugln(['Gtk2RangeUbuntuScrollCB duplicate message => skip']);
        exit;
      end;
      g_object_set_data(PGObject(Adjustment), odnScrollBarLastPos, {%H-}gpointer(Pos));

      //DebugLn('Gtk2RangeUbuntuScrollCB A Adjustment^.Value=',dbgs(Adjustment^.Value),' SmallPos=',dbgs(SmallPos));
      ScrollBar := HWND({%H-}PtrUInt(Scroll));
      ScrollType := get_gtk_scroll_type(Scroll);
      ScrollCode := ScrollTypeToSbCode(True, ScrollType,
                                       gtk_range_get_update_policy(Scroll));
      //DebugLn('Gtk2RangeUbuntuScrollCB B Adjustment^.Value=',dbgs(Adjustment^.Value),' ScrollCode=',dbgs(ScrollCode),' ScrollType=',dbgs(ScrollType));
    end;
    DeliverMessage(AWidgetInfo^.LCLObject, Msg);
    Result:=true;
  end;
end;

function Gtk2ScrolledWindowScrollCB(AScrollWindow: PGtkScrolledWindow; AEvent: PGdkEventScroll; AWidgetInfo: PWidgetInfo): gboolean; cdecl;
var
  Msg: TLMVScroll;
  AValue: Double;
  Range: PGtkRange;
begin
  {$IFDEF SYNSCROLLDEBUG}
  debugln(['Gtk2ScrolledWindowScrollCB ']);
  {$ENDIF}
  case AEvent^.direction of
    GDK_SCROLL_UP,
    GDK_SCROLL_DOWN: Msg.Msg := LM_VSCROLL;
    GDK_SCROLL_LEFT,
    GDK_SCROLL_RIGHT: Msg.Msg := LM_HSCROLL;
  end;

  case Msg.Msg of
    LM_VSCROLL: Range := GTK_RANGE(AScrollWindow^.vscrollbar);
    LM_HSCROLL: Range := GTK_RANGE(AScrollWindow^.hscrollbar);
  end;

  AValue :=  power(Range^.adjustment^.page_size, 2 / 3);

  if (AEvent^.direction = GDK_SCROLL_UP) or
     (AEvent^.direction = GDK_SCROLL_LEFT)
  then
    AValue := -AValue;

  AValue := gtk_range_get_value(Range) + AValue;

  AValue := Max(AValue, Range^.adjustment^.lower);
  AValue := Min(AValue, Range^.adjustment^.upper - Range^.adjustment^.page_size);

  with Msg do
  begin
    Pos := Round(AValue);
    if Pos < High(SmallPos) then
      SmallPos := Pos
    else
      SmallPos := High(SmallPos);

    ScrollBar := HWND({%H-}PtrUInt(Range));
    ScrollCode := SB_THUMBPOSITION;
  end;
  Result := DeliverMessage(AWidgetInfo^.LCLObject, Msg) <> 0;
end;

{------------------------------------------------------------------------------
  Function: GTKKeySnooper
  Params:  Widget: The widget for which this event is fired
           Event:  The keyevent data
           FuncData: the user parameter passed when the snooper was installed
  Returns: True if other snoopers shouldn't handled

  Keeps track of which keys are pressed. The keycode is casted to a pointer and
  if it exists in the KeyStateList, it is pressed.
 ------------------------------------------------------------------------------}
function GTKKeySnooper(Widget: PGtkWidget; Event: PGdkEventKey;
  FuncData: gPointer): gInt; cdecl;
var
  KeyStateList: TFPList absolute FuncData;

  procedure UpdateToggleList(const AVKeyCode: Integer);
  begin
    // Check for a toggle
    // If the remove was successfull, the key was on
    // else it was off so we should set the toggle flag
    if KeyStateList.Remove({%H-}Pointer(PtrUInt(AVKeyCode or KEYMAP_TOGGLE))) < 0
    then KeyStateList.Add({%H-}Pointer(PtrUInt(AVKeyCode or KEYMAP_TOGGLE)));
  end;

  procedure UpdateList(const AVKeyCode: Integer; const APressed: Boolean);
  begin
    if AVKeyCode = 0 then Exit;
    if APressed
    then begin
      if KeyStateList.IndexOf({%H-}Pointer(PtrUInt(AVKeyCode))) < 0
      then KeyStateList.Add({%H-}Pointer(PtrUInt(AVKeyCode)));
    end
    else begin
      KeyStateList.Remove({%H-}Pointer(PtrUInt(AVKeyCode)));
    end;
  end;

const
  STATE_MAP: array[0..3] of TShiftStateEnum = (
    ssShift,
    ssCtrl,
    ssAlt,
    ssSuper
  );
  VK_MAP: array[0..3] of array[0..2] of Byte = (
    // (Main key, alt key 1, alt key 2) to check
    (VK_SHIFT, VK_LSHIFT, VK_RSHIFT),
    (VK_CONTROL, VK_LCONTROL, VK_RCONTROL),
    (VK_MENU, VK_LMENU, VK_RMENU),
    (VK_LWIN, VK_RWIN, 0)
  );
var
  KeyCode: Word;
  KCInfo: TKeyCodeInfo;
  VKey: Byte;
  Pressed, InState: Boolean;

  n: Integer;
  ShiftState: TShiftState;

begin
  Result := 0;

  // TODO: Remove when KeyStateList is obsolete

  case gdk_event_get_type(Event) of
    GDK_KEY_PRESS: Pressed := True;
    GDK_KEY_RELEASE: Pressed := False;
  else
    // not interested
    Exit;
  end;

  KeyCode := Event^.hardware_keycode;
  //DebugLn('GTKKeySnooper: KeyCode=%u -> %s', [KeyCode, Event^._String ]);
  
  if KeyCode > High(MKeyCodeInfo)
  then begin
    if Pressed
    then DebugLn('[WARNING] Key pressed with keycode (%u) larger than expected: K=0x%x S="%s"', [
      KeyCode,
      Event^.KeyVal,
      Event^._String
    ]);
    Exit;
  end;
  
  KCInfo := MKeyCodeInfo[KeyCode];
  if KCInfo.VKey1 = 0
  then begin
    if Pressed
    then DebugLn('[WARNING] Key pressed without VKey: K=0x%x S="%s"', [
      Event^.KeyVal,
      Event^._String
    ]);
    Exit;
  end;

  if KeyStateList = nil then exit;
  
  ShiftState := GTKEventStateToShiftState(Event^.State);
  
  if (KCInfo.Flags and KCINFO_FLAG_SHIFT_XOR_NUM <> 0)
  and ((ssShift in ShiftState) xor (ssNum in ShiftState))
  then VKey := KCInfo.VKey2
  else VKey := KCInfo.VKey1;

  UpdateList(VKey, Pressed);
  if Pressed then
    UpdateToggleList(VKey);

  // Add special left and right codes
  case Event^.KeyVal of
    GDK_Key_Shift_L:   UpdateList(VK_LSHIFT,   Pressed);
    GDK_Key_Shift_R:   UpdateList(VK_RSHIFT,   Pressed);
    GDK_Key_Control_L: UpdateList(VK_LCONTROL, Pressed);
    GDK_Key_Control_R: UpdateList(VK_RCONTROL, Pressed);
    GDK_Key_Alt_L:     UpdateList(VK_LMENU,    Pressed);
    GDK_Key_Alt_R:     UpdateList(VK_RMENU,    Pressed);
  end;

  // Recheck the list against the modifiers
  for n := 0 to High(STATE_MAP) do
  begin
    // Skip our current key, since the state is updated after the event
    if VKey = VK_MAP[n][0] then Continue;
    if VKey = VK_MAP[n][1] then Continue;
    if VKey = VK_MAP[n][2] then Continue;

    InState := STATE_MAP[n] in ShiftState;
    UpdateList(VK_MAP[n][0], InState);
    UpdateList(VK_MAP[n][1], InState);
    UpdateList(VK_MAP[n][2], InState);
  end;

  // if the VKey has multiple VK_codes then SHIFT distinguishes between them
  // In that case SHIFT is not pressed
  // On the next event the shift flag will be restored based on modifiers
  if Pressed and ((KCInfo.Flags and KCINFO_FLAG_SHIFT_XOR_NUM) <> 0)
  then begin
    UpdateList(VK_SHIFT,  False);
    UpdateList(VK_LSHIFT, False);
    UpdateList(VK_RSHIFT, False);
  end;
end;

function gtkYearChanged({%H-}Widget: PGtkWidget; data: gPointer) : GBoolean; cdecl;
var
  MSG: TLMessage;
begin
  Result := CallBackDefaultReturn;

  EventTrace('year changed', data);
  MSG.Msg := LM_YEARCHANGED;
  DeliverPostMessage(Data, MSG);
end;

procedure GtkDragDataReceived(widget:PGtkWidget; context:PGdkDragContext;
  x:gint; y:gint; selection_data:PGtkSelectionData; info:guint; time:guint; Data: gPointer);cdecl;
var
  S: TStringList;
  I: Integer;
  FileName, DecodedFileName: String;
  Files: Array of String;
  Form: TControl;
  Result: Boolean;
  U: TURI;
begin
  //DebugLn('GtkDragDataReceived ' + PChar(selection_data^.data));
  Result := False;
  
  if selection_data^.data <> nil then // data is list of uri
  try
    SetLength(Files{%H-}, 0);
    S := TStringList.Create;
    try
      S.Text := PChar(selection_data^.data);

      for I := 0 to S.Count - 1 do
      begin
        FileName := S[I];

        if FileName = '' then Continue;
        // uri = protocol://hostname/file name
        U := ParseURI(FileName);
        if (SameText(U.Host, 'localhost') or (U.Host = '')) and SameText(U.Protocol, 'file')
          and URIToFileName(FileName, DecodedFileName) then // convert uri of local files to file name
        begin
          FileName := DecodedFileName;
        end;
        // otherwise: protocol and hostname are preserved!

        if FileName = '' then Continue;
        SetLength(Files, Length(Files) + 1);
        Files[High(Files)] := FileName;
        //DebugLn('GtkDragDataReceived ' + DbgS(I) + ': ' + PChar(FileName));
      end;
    finally
      S.Free;
    end;
    
    if Length(Files) > 0 then
    begin
      Form := nil;
      if (TObject(Data) is TWinControl) then
        Form := TWinControl(Data).IntfGetDropFilesTarget;
        
      if Form is TCustomForm then
        TCustomForm(Form).IntfDropFiles(Files)
      else
        if (Application <> nil) and (Application.MainForm <> nil) then
          Application.MainForm.IntfDropFiles(Files);

      if Application <> nil then
        Application.IntfDropFiles(Files);
        
      Result := True;
    end;
  except
    Application.HandleException(nil);
  end;
  
  gtk_drag_finish(Context, Result, false, time);
end;

{------------------------------------------------------------------------------
  ClipboardSelectionReceivedHandler

  This handler is called whenever a clipboard owner sends data. Because the LCL
  caches all requests, this is typically data from another application.
  Copy the received selection data record and buffer to
  internal record and buffer (ClipboardSelectionData)
 ------------------------------------------------------------------------------}
procedure ClipboardSelectionReceivedHandler({%H-}TargetWidget: PGtkWidget;
  SelectionData: PGtkSelectionData; TimeID: guint32; {%H-}Data: Pointer); cdecl;
var TempBuf: Pointer;
  c: PClipboardEventData;
  i: integer;
begin
  // at any time there can be several requests
  // find the request with the correct TimeID
  i:=ClipboardSelectionData.Count-1;
  while (i>=0) do begin
    c:=PClipboardEventData(ClipboardSelectionData[i]);
    if c^.TimeID=TimeID then break;
    dec(i);
  end;
  {$IFDEF DEBUG_CLIPBOARD}
  DebugLn('[ClipboardSelectionReceivedHandler] A TimeID=',dbgs(TimeID),' RequestIndex=',dbgs(i),
    ' selection=',dbgs(SelectionData^.selection)+'='+GdkAtomToStr(SelectionData^.selection),
    ' target=',dbgs(SelectionData^.Target)+'='+GdkAtomToStr(SelectionData^.Target),
    ' theType=',dbgs(SelectionData^._type)+'='+GdkAtomToStr(SelectionData^._type),
    ' format=',dbgs(SelectionData^.format),
    ' len=',dbgs(SelectionData^.length)
    );
  {$ENDIF}
  if i<0 then exit;
  // free old data
  if (c^.Data.Data<>nil) then FreeMem(c^.Data.Data);
  // copy the information
  c^.Data:=SelectionData^;
  // copy the raw data to an internal buffer (the gtk buffer will be destroyed
  // right after this event)
  {$IFDEF DEBUG_CLIPBOARD}
  DebugLn('[ClipboardSelectionReceivedHandler] B DataLen=',dbgs(c^.Data.Length));
  {$ENDIF}
  if (c^.Data.Data<>nil)
  and (c^.Data.Length>0) then begin
    GetMem(TempBuf,c^.Data.Length);
    Move(c^.Data.Data^,TempBuf^,c^.Data.Length);
    c^.Data.Data:=TempBuf;
    {$IFDEF DEBUG_CLIPBOARD}
    DebugLn('[ClipboardSelectionReceivedHandler] C FirstCharacter=',dbgs(ord(PChar(c^.Data.Data)[0])));
    {$ENDIF}
  end else begin
    {if (SelectionData^.Target <> GDK_TARGET_STRING)
    and (SelectionData^.length<0) then begin
      if gtk_selection_convert (TargetWidget, SelectionData^.selection,
        GDK_TARGET_STRING, TimeID)<>GdkFalse
      then begin
        DebugLn('[ClipboardSelectionReceivedHandler] D TimeID=',dbgs(TimeID),' RequestIndex=',dbgs(i),
          ' selection=',dbgs(SelectionData^.selection)+'='+GdkAtomToStr(SelectionData^.selection),
          ' target=',dbgs(SelectionData^.Target)+'='+GdkAtomToStr(SelectionData^.Target),
          ' theType=',dbgs(SelectionData^.theType)+'='+GdkAtomToStr(SelectionData^.theType),
          ' format=',dbgs(SelectionData^.format),
          ' len=',dbgs(SelectionData^.length)
          );
      end;
    end;}
    c^.Data.Data:=nil;
  end;
end;

// Helper procedures for ClipboardSelectionRequestHandler :

procedure Transform2CompoundText(SelectionData: PGtkSelectionData; MemStream: TMemoryStream);
var
  Buffer: Pointer;
  BufLength: integer;
  P: PChar;
begin
  BufLength:=integer(MemStream.Size);
  P:=StrAlloc(BufLength);
  MemStream.Read(P^,BufLength);
  Buffer:=nil;
  BufLength:=0;
  gdk_string_to_compound_text(P,
    @SelectionData^._Type,
    @SelectionData^.Format,ppguchar(@Buffer),@BufLength);
  StrDispose(P);
  gtk_selection_data_set(SelectionData,SelectionData^.Target,
    SelectionData^.Format,Buffer,BufLength);
  gdk_free_compound_text(Buffer);
end;

procedure SetData(SelectionData: PGtkSelectionData; MemStream: TMemoryStream);
var
  Buffer: Pointer;
  BufLength: integer;
begin
  BufLength:=integer(MemStream.Size);
  GetMem(Buffer,BufLength);
  Assert(Assigned(Buffer) and (BufLength>0), 'SetData: GTK2 clipboard Buffer=Nil or empty.');
  MemStream.Read(Buffer^,BufLength);
  gtk_selection_data_set(SelectionData,SelectionData^.Target,8,Buffer,BufLength);
  FreeMem(Buffer);
end;

{------------------------------------------------------------------------------
  ClipboardSelectionRequestHandler

  This signal is emitted if someone requests the clipboard data.
  Since the lcl clipboard caches all requests this will typically be another
  application.
 ------------------------------------------------------------------------------}
procedure ClipboardSelectionRequestHandler({%H-}TargetWidget: PGtkWidget;
  SelectionData: PGtkSelectionData; {%H-}Info: cardinal; {%H-}TimeID: cardinal;
  {%H-}Data: Pointer); cdecl;
var
  ClipboardType: TClipboardType;
  FormatID: cardinal;
  MemStream: TMemoryStream;
begin
  {$IFDEF DEBUG_CLIPBOARD}
  DebugLn('*** [ClipboardSelectionRequestHandler] START');
  {$ENDIF}
  if SelectionData^.Target=0 then exit;
  for ClipboardType:=Low(TClipboardType) to High(TClipboardType) do
  begin
    if SelectionData^.Selection<>ClipboardTypeAtoms[ClipboardType] then
      Continue;
    if ClipboardHandler[ClipboardType]=nil then
      break;
    // handler found for this type of clipboard
    // now create a stream and find a supported format
    {$IFDEF DEBUG_CLIPBOARD}
    DebugLn('[ClipboardSelectionRequestHandler] "',ClipboardTypeName[ClipboardType],'" Format=',GdkAtomToStr(SelectionData^.Target),' ID=',dbgs(SelectionData^.Target));
    {$ENDIF}
    MemStream:=TMemoryStream.Create;
    try
      // the gtk-interface provides automatically some formats, that the lcl
      // does not know. Wrapping them to lcl formats ...
      FormatID:=SelectionData^.Target;
      if ((FormatID=gdk_atom_intern('UTF8_STRING',GdkTrue))
        and (ClipboardExtraGtkFormats[ClipboardType][gfUTF8_STRING]))
      or ((FormatID=gdk_atom_intern('COMPOUND_TEXT',GdkTrue))
        and (ClipboardExtraGtkFormats[ClipboardType][gfCOMPOUND_TEXT]))
      or ((FormatID=gdk_atom_intern('STRING',GdkTrue))
        and (ClipboardExtraGtkFormats[ClipboardType][gfSTRING]))
      or ((FormatID=gdk_atom_intern('TEXT',GdkTrue))
        and (ClipboardExtraGtkFormats[ClipboardType][gfTEXT]))
      then
        FormatID:=gdk_atom_intern('text/plain',GdkTrue);

      {$IFDEF DEBUG_CLIPBOARD}
      DebugLn('[ClipboardSelectionRequestHandler] FormatID=',dbgs(FormatID),'=',GdkAtomToStr(FormatID),' ',dbgs(ClipboardExtraGtkFormats[ClipboardType][gfCOMPOUND_TEXT]));
      {$ENDIF}
      // get the requested data by calling a handler for this clipboard type
      //  and build data for gtk
      ClipboardHandler[ClipboardType](FormatID,MemStream);
      if MemStream.Size=0 then
        break;
      MemStream.Position:=0;
      if (FormatID=gdk_atom_intern('text/plain',GdkTrue))
      and (SelectionData^.Target=gdk_atom_intern('COMPOUND_TEXT',GdkTrue)) then
        // if the format was wrapped, transform text/plain back to COMPOUND_TEXT
        Transform2CompoundText(SelectionData, MemStream)
      else
        SetData(SelectionData, MemStream);
    finally
      MemStream.Free;
    end;
    break;
  end; // for
end;

{------------------------------------------------------------------------------
  ClipboardSelectionLostOwnershipHandler

  This signal is emitted if another application gets the clipboard ownership.
 ------------------------------------------------------------------------------}
function ClipboardSelectionLostOwnershipHandler({%H-}TargetWidget: PGtkWidget;
  EventSelection: PGdkEventSelection;  {%H-}Data: Pointer): cardinal; cdecl;
var ClipboardType: TClipboardType;
begin
  //DebugLn('*** [ClipboardSelectionLostOwnershipHandler] ',DbgS(targetwidget));
  for ClipboardType:=Low(TClipboardType) to High(TClipboardType) do
    if EventSelection^.Selection=ClipboardTypeAtoms[ClipboardType] then begin
      {$IFDEF DEBUG_CLIPBOARD}
      DebugLn('*** [ClipboardSelectionLostOwnershipHandler] ',ClipboardTypeName[ClipboardType]);
      {$ENDIF}
      if (ClipboardWidget<>nil)
      and (gdk_selection_owner_get(ClipboardTypeAtoms[ClipboardType])
        <> GetControlWindow(ClipboardWidget))
      and Assigned(ClipboardHandler[ClipboardType]) then begin
        // handler found for this type of clipboard
        {$IFDEF DEBUG_CLIPBOARD}
        DebugLn('[ClipboardSelectionLostOwnershipHandler] ',ClipboardTypeName[ClipboardType]);
        {$ENDIF}
        ClipboardHandler[ClipboardType](0,nil);
        ClipboardHandler[ClipboardType]:=nil;
      end;
      break;
    end;
  Result:=1;
end;

{-------------------------------------------------------------------------------
  procedure GTKStyleChanged(Widget: PGtkWidget; previous_style : PGTKStyle;
    Data: Pointer); cdecl;

  Handler for style changes. For example the user changes the theme.
  But also called on every widget realize, so it should not release all styles
  everytime.
-------------------------------------------------------------------------------}
{$IFDEF EventTrace}
procedure GTKStyleChanged({%H-}Widget: PGtkWidget; {%H-}previous_style : PGTKStyle;
  {%H-}Data: Pointer); cdecl;
begin
  EventTrace('style-set', nil);
  //ReleaseAllStyles;
end;

procedure GTKStyleChangedAfter({%H-}Widget: PGtkWidget; {%H-}previous_style : PGTKStyle;
  {%H-}Data: Pointer); cdecl;
begin
  EventTrace('style-set', nil);

  { Note:
    This event is called for many widgets but not for all.
    It is called on creation and called when the theme changes.
    The resizing should occur when all styles were updated by the gtk.
    The gtk itself uses size messages via queue.
    Maybe the solution is to use g_idle_add for the top level form and resize.
  }
  //debugln('style-set after ',DbgSName(TWinControl(Data)));
  //LCLObject.InvalidateClientRectCache(False);
end;
{$ENDIF}


function gtkListBoxSelectionChangedAfter(widget: PGtkWidget; data: gPointer
  ): GBoolean; cdecl;
var
  Mess: TLMessage;
  GtkList: PGtkList;
begin
  Result := CallBackDefaultReturn;
  {$IFDEF EventTrace}
  EventTrace('gtkListSelectionChangedAfter', data);
  {$ENDIF}
  GtkList:=PGtkList(widget);
  if (GtkList^.selection = nil) or (LockOnChange(PGtkObject(widget),0) > 0) then
    Exit;
  FillChar(Mess{%H-},SizeOf(Mess),0);
  Mess.msg := LM_SelChange;
  if gtkListGetSelectionMode(GtkList)=GTK_SELECTION_SINGLE then
    gtk_list_set_selection_mode(GtkList,GTK_SELECTION_BROWSE);
  DeliverMessage(Data, Mess);
end;

//DRAG CALLBACK FUNCTIONS

function edit_drag_data_received({%H-}widget : pgtkWidget;
  Context : pGdkDragContext;
  {%H-}X, {%H-}Y : Integer;
  SelData : pGtkSelectionData;
  {%H-}info : Integer;
  time : Integer;
  data : pointer) : GBoolean; cdecl;
Var
  Texts : String;
Begin
  Result:=false;
  //DebugLn('Trace:***********Drag Data Received*******************');
  if Seldata^.Length > 0 then
  Begin
    Texts := StrPas(PChar(SelData^.data));
    //DebugLn('Trace:' + Texts);
    //DebugLn('Trace:0');
    TCustomEdit(Data).Caption := Texts;
    //DebugLn('Trace:1');
  end;
  gtk_drag_finish(Context,false,false,time);
end;

function edit_source_drag_data_get({%H-}widget : pgtkWidget;
  {%H-}Context : pGdkDragContext;
  Selection_data : pGtkSelectionData;
  info : Integer;
  {%H-}time : Integer;
  data : pointer) : GBoolean; cdecl;
var
  strTemp : PChar;
  Texts : String;
Begin
  Result:=false;
  if (info = TARGET_ROOTWIN) then begin
    //DebugLn('Trace:I WAS DROPPED ON THE ROOTWIN')
  end
  else Begin
    //DebugLn('Trace:*********Setting Data************');
    Texts := TCustomEdit(data).Text;
    //DebugLn('Trace:0');
    strTemp := StrAlloc(length(Texts) + 1);
    try
      StrPCopy(strTemp, Texts);
      //DebugLn('Trace:1');
      gtk_selection_data_set(selection_data,selection_data^.target,
                    8,
                    PGUChar(StrTemp),
                    length(Texts)+1);
      //DebugLn('Trace:2');
    finally
      strDispose(strTemp);
    end;
    //DebugLn('Trace:3');
  end;
end;


function Edit_source_drag_data_delete ({%H-}Widget: pGtkWidget;
  {%H-}Context: pGdkDragContext; {%H-}Data: gpointer): gBoolean ; cdecl;
begin
  //DebugLn('Trace:***************');
  //DebugLn('Trace:DELETE THE DATA');
  Result:=false;
end;

// combobox callbacks
function gtkComboBoxShowAfter({%H-}widget: PGtkWidget; data: gPointer): GBoolean; cdecl;
var
  Mess : TLMCommand;
  AComboBox: TCustomComboBox absolute data;
begin
  Result := True;
  EventTrace('ComboBoxShowAfter', data);

  AComboBox.IntfGetItems;

  FillChar(Mess{%H-},SizeOf(Mess),0);
  Mess.Msg := CN_Command;
  Mess.NotifyCode := CBN_DROPDOWN;

  Result := DeliverMessage(Data, Mess) = 0;
end;

function gtkComboBoxHideAfter({%H-}widget: PGtkWidget; data: gPointer): GBoolean; cdecl;
var
  Mess : TLMCommand;
begin
  Result := True;
  EventTrace('ComboBoxHideAfter', data);
  FillChar(Mess{%H-},SizeOf(Mess),0);
  Mess.Msg := CN_Command;
  Mess.NotifyCode := CBN_CLOSEUP;

  Result := DeliverMessage(Data, Mess) = 0;
end;

// notebook callbacks
procedure DrawNotebookPageIcon(Page: TCustomPage; Widget: PGtkWidget);
var
  NoteBook: TCustomTabControl;
  NoteBookWidget: PGtkWidget;
  PageWidget: PGtkWidget;
  TabWidget: PGtkWidget;
  ImageIndex: Integer;
begin
  NoteBook := Page.Parent as TCustomTabControl;
  ImageIndex := NoteBook.GetImageIndex(Page.PageIndex);
  if (NoteBook.Images = nil) or (ImageIndex < 0)
  or (Page.ImageIndex >= NoteBook.Images.Count)
  or (not NoteBook.HandleAllocated)
  or (not Page.HandleAllocated)
  then exit;
  NoteBookWidget := {%H-}PGtkWidget(NoteBook.Handle);
  PageWidget := {%H-}PGtkWidget(Page.Handle);

  // get the tab container and the tab icon widget
  TabWidget := gtk_notebook_get_tab_label(PGtkNoteBook(NotebookWidget),
                                        PageWidget);
  if TabWidget = nil then exit;
  {$IFDEF VerboseGtkToDos}{$note reimplement}{$ENDIF}
  DrawImageListIconOnWidget(NoteBook.Images.ResolutionForPPI[NoteBook.ImagesWidth, NoteBook.Font.PixelsPerInch, NoteBook.GetCanvasScaleFactor],
    ImageIndex, Widget);
end;

function PageIconWidgetExposeAfter(Widget: PGtkWidget; Event: PGDKEventExpose;
  Data: gPointer): GBoolean; cdecl;
var
  ThePage: TCustomPage absolute Data;
begin
  Result := false;
  //DebugLn('PageIconWidgetExposeAfter ',DbgS(Widget));
  EventTrace('PageIconWidgetExposeAfter', Data);
  if (Event^.Count > 0) then exit;
  DrawNotebookPageIcon(ThePage, Widget);
end;



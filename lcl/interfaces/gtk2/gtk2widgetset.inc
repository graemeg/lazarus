{%MainUnit gtk2int.pas}
{******************************************************************************
                                   TGtk2WidgetSet
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

{$IFNDEF USE_GTK_MAIN_OLD_ITERATION}
var
  Gtk2MPF: TGPollFunc;

function Gtk2PollFunction(ufds:PGPollFD; nfsd:guint; timeout:gint):gint;cdecl;
begin
  Result := nfsd;
  if TimeOut = -1 then
    Gtk2WidgetSet.FMainPoll := ufds
  else
    Gtk2WidgetSet.FMainPoll := nil;
  if Gtk2MPF <> nil then
  begin
    if (glib_major_version = 2) and (glib_minor_version < 24) and
      (Gtk2WidgetSet.FMainPoll <> nil) then
    begin
      while (Gtk2WidgetSet.FMainPoll <> nil) and
        (Gtk2WidgetSet.FMainPoll^.revents = 0) do
      begin
        if (Gtk2MPF(ufds, nfsd, 1) = 1) or
        (Gtk2WidgetSet.FMessageQueue.Count > 0) then
          break;
      end;
    end else
      Gtk2MPF(ufds, nfsd, timeout);
  end;
end;
{$ENDIF}

// To do: eat 2 key stroke after re-focus.
function GTK2FocusCB( widget: PGtkWidget; event:PGdkEventFocus;
  data: gPointer) : GBoolean; cdecl;
var
  Status : gBoolean;
begin
  Status := GTKFocusCB(Widget, Event, Data);

  if GtkWidgetIsA(Widget,GTK_APIWIDGETCLIENT_TYPE) then
  begin
    Result := Status;
    {$IFDEF WITH_GTK2_IM}
    gtk_im_context_set_client_window(im_context,GetControlWindow(widget));
    gtk_im_context_focus_in(im_context);
    im_context_widget:=widget;
    {$ENDIF}
  end
  else
    Result := False;
end;

function gtk2HideCB( widget: PGtkWidget; data: gPointer) : GBoolean; cdecl;
var
   Status : GBoolean;
begin
  Status := gtkHideCB(Widget, Data);

  if GtkWidgetIsA(Widget,GTK_APIWIDGETCLIENT_TYPE) then
    Result := Status
  else
    Result := False;
end;

function GTK2KillFocusCB(widget: PGtkWidget; event:PGdkEventFocus;
  data: gPointer) : GBoolean; cdecl;
var
  Status : gBoolean;
begin
  Status := GTKKillFocusCB(Widget, Event, Data);

  if GtkWidgetIsA(Widget,GTK_APIWIDGETCLIENT_TYPE) then
  begin
    Result := Status;
    {$IFDEF WITH_GTK2_IM}
    gtk_im_context_focus_out(im_context);
    gtk_im_context_set_client_window(im_context,nil);
    im_context_widget:=nil;
    ResetDefaultIMContext;
    {$ENDIF}
  end
  else
    Result := False;
end;

function GTK2KillFocusCBAfter(widget: PGtkWidget; event:PGdkEventFocus;
  data: gPointer) : GBoolean; cdecl;
var
  Status : gBoolean;
begin
  Status := GTKKillFocusCBAfter(Widget, Event, Data);

  if GtkWidgetIsA(Widget,GTK_APIWIDGETCLIENT_TYPE) then
    Result := Status
  else
    Result := False;
end;

function gtk2PopupMenuCB(Widget: PGtkWidget; data: gPointer): gboolean; cdecl;
var
  Msg: TLMContextMenu;
begin
  FillChar(Msg{%H-}, SizeOf(Msg), #0);

  Msg.Msg := LM_CONTEXTMENU;
  Msg.hWnd := {%H-}HWND(Widget); // todo: true keystate

  // keyboard popup menu must have -1, -1 coords
  Msg.XPos := -1;
  Msg.YPos := -1;

  Result := DeliverMessage(TComponent(data), Msg) <> 0;
end;

function gtk2showCB( widget: PGtkWidget; data: gPointer) : GBoolean; cdecl;
var
   Status : GBoolean;
begin
  Status := gtkshowCB(Widget, Data);

  if GtkWidgetIsA(Widget,GTK_APIWIDGETCLIENT_TYPE) then
    Result := Status
  else
    Result := False;
end;

function gtk2ShowHelpCB(widget: PGtkWidget; arg1: TGtkWidgetHelpType; {%H-}data: gpointer): gboolean; cdecl;
var
  Info: THelpInfo;
begin
  if arg1 = GTK_WIDGET_HELP_WHATS_THIS then
  begin
    Info.cbSize := SizeOf(Info);
    Info.iContextType := HELPINFO_WINDOW;
    Info.iCtrlId := 0;
    Info.hItemHandle := {%H-}THandle(widget);
    Info.dwContextId := 0;
    gdk_display_get_pointer(gdk_display_get_default(), nil, @Info.MousePos.X, @Info.MousePos.Y, nil);
    Application.HelpCommand(0, {%H-}PtrInt(@Info));
  end;
  Result := True;
end;

function gtk2GrabNotify({%H-}widget: PGtkWidget; grabbed: GBoolean; {%H-}data: GPointer): GBoolean; cdecl;
// called for all widgets on every gtk_grab_add and gtk_grab_remove
// grabbed = true if called by gtk_grab_remove
// grabbed = false if called by gtk_grab_add
var
  CurCaptureWidget: PGtkWidget;
begin
  {$IFDEF VerboseMouseCapture}
  //debugln(['gtk2GrabNotify ',GetWidgetDebugReport(widget),' grabbed=',grabbed,' MouseCaptureWidget=',dbgs(MouseCaptureWidget)]);
  {$ENDIF}
  Result := CallBackDefaultReturn;
  if Grabbed then
  begin
    // grab release
    CurCaptureWidget := gtk_grab_get_current;
    if (MouseCaptureWidget<>nil)
    and ((CurCaptureWidget=nil) or (CurCaptureWidget = MouseCaptureWidget)) then
    begin
      {$IFDEF VerboseMouseCapture}
      debugln(['gtk2GrabNotify ungrab ',GetWidgetDebugReport(widget),' grabbed=',grabbed,' MouseCaptureWidget=',dbgs(MouseCaptureWidget)]);
      {$ENDIF}
      //Result := True;
      ReleaseCaptureWidget(MouseCaptureWidget);
    end;
  end;
end;


procedure gtk_clb_toggle({%H-}cellrenderertoggle : PGtkCellRendererToggle; arg1 : PGChar;
                         WinControl: TWinControl); cdecl;
var
  aWidget : PGTKWidget;
  aTreeModel : PGtkTreeModel;
  aTreeIter : TGtkTreeIter;
  value : pgValue;
begin
  aWidget := GetOrCreateWidgetInfo({%H-}Pointer(WinControl.Handle))^.CoreWidget;
  aTreeModel := gtk_tree_view_get_model (GTK_TREE_VIEW(aWidget));
  if (gtk_tree_model_get_iter_from_string (aTreeModel, @aTreeIter, arg1)) then begin
    aTreeIter.stamp := GTK_LIST_STORE (aTreeModel)^.stamp; //strange hack
    value := g_new0(SizeOf(TgValue), 1);
    gtk_tree_model_get_value(aTreeModel, @aTreeIter, 0, value);

    g_value_set_boolean(value, not g_value_get_boolean(value));

    gtk_list_store_set_value (GTK_LIST_STORE (aTreeModel), @aTreeIter, 0, value);
    g_value_unset(value);
    g_free(value);
  end;
end;

procedure gtk_clb_toggle_row_activated(treeview : PGtkTreeView; arg1 : PGtkTreePath;
                                  {%H-}arg2 : PGtkTreeViewColumn; {%H-}data : gpointer); cdecl;
var
  aTreeModel : PGtkTreeModel;
  aTreeIter : TGtkTreeIter;
  value : PGValue;
begin
  aTreeModel := gtk_tree_view_get_model (treeview);
  if (gtk_tree_model_get_iter (aTreeModel, @aTreeIter, arg1)) then begin
    aTreeIter.stamp := GTK_LIST_STORE (aTreeModel)^.stamp; //strange hack
    value := g_new0(SizeOf(TgValue), 1);
    gtk_tree_model_get_value(aTreeModel, @aTreeIter, 0, value);

    g_value_set_boolean(value, not g_value_get_boolean(value));

    gtk_list_store_set_value (GTK_LIST_STORE (aTreeModel), @aTreeIter, 0, value);
    g_value_unset(value);
    g_free(value);
  end;
end;

procedure gtk_commit_cb ({%H-}context: PGtkIMContext; const Str: Pgchar;
  {%H-}Data: Pointer); cdecl;
{$IFDEF WITH_GTK2_IM}
var
  control:TWinControl;
  i:Integer;
{$ENDIF}
begin
  {$IFDEF WITH_GTK2_IM}
  //DebugLn(['gtk_commit_cb ',dbgstr(Str),'="',Str,'"']);
  { fix double normal character input }
  if not im_context_use then
    im_context_string:=Str // key at non-composition
    else
      im_context_string_commit:=Str; // key at composition
  { commit composition string, not key }
  if (im_context_widget<>nil) then
      begin
        im_context_skipdelete:=True;
        Control:=TWinControl(GetNearestLCLObject(im_context_widget));
        SendMessage(control.Handle,LM_IM_COMPOSITION,GTK_IM_FLAG_COMMIT,LPARAM(pchar(im_context_string_commit)));
        im_context_string_commit:='';
      end;
  {$ELSE}
  im_context_string:=Str;
  {$ENDIF}
end;

{$IFDEF WITH_GTK2_IM}
procedure gtk_preedit_start_cb({%H-}context: PGtkIMContext; {%H-}Data: Pointer); cdecl;
var
  control:TWinControl;
  Flag:WPARAM;
begin
  if (im_context_widget<>nil) and
     (GetNearestLCLObject(im_context_widget) is TCustomControl) then
  begin
    im_context_use:=True;
    im_context_skipDelete:=True;
    control:=TWinControl(GetNearestLCLObject(im_context_widget));
    SendMessage(control.Handle,LM_IM_COMPOSITION,GTK_IM_FLAG_START,LPARAM(context));
  end;
end;

procedure gtk_preedit_end_cb({%H-}context: PGtkIMContext; {%H-}Data: Pointer); cdecl;
var
  control:TWinControl;
  Flag:WPARAM;
begin
  if (im_context_widget<>nil) and
     (GetNearestLCLObject(im_context_widget) is TCustomControl) then
  begin
    control:=TWinControl(GetNearestLCLObject(im_context_widget));
    SendMessage(control.Handle,LM_IM_COMPOSITION,GTK_IM_FLAG_END,LPARAM(context));
  end;
end;

procedure gtk_preedit_changed_cb({%H-}context:PGtkIMContext; {%H-}Data:Pointer); cdecl;
var
  control:TWinControl;
  Flag:WPARAM;
  str:Pgchar;
  pangoattr:PPangoAttrList;
  curpos:gint;
begin
  if (im_context_widget<>nil) then
  begin
    im_context_use:=True;
    gtk_im_context_get_preedit_string(context,@str,pangoattr,@curpos);
    im_context_string_preedit:=str;
    g_free(str);
    pango_attr_list_unref(pangoattr);
    control:=TWinControl(GetNearestLCLObject(im_context_widget));
    Flag:=GTK_IM_FLAG_PREEDIT;
    if (not im_context_skipDelete) then begin
      Flag:=Flag or GTK_IM_FLAG_REPLACE;
    end else
      im_context_skipDelete:=False;
    SendMessage(control.Handle,LM_IM_COMPOSITION,Flag,LPARAM(pchar(im_context_string_preedit)));
  end;
end;

function gtk_retrieve_surrounding_cb({%H-}context: PGtkIMContext; {%H-}Data: Pointer):gboolean; cdecl;
var
  control:TWinControl;
  Flag:WPARAM;
begin
  Result:=False;
  //im_context_use:=True;
end;
{$ENDIF}


{------------------------------------------------------------------------------
  Function: TGtk2WidgetSet._SetCallbackEx

  // originally TGtkWidgetSet.SetCallbackEx

  Params: AMsg - message for which to set a callback
          AGTKObject - object to which callback will be send
          ALCLObject - for compatebility reasons provided, will be used when
                       AGTKObject = nil
          Direct - true: connect the signal to the AGTKObject
                   false: choose smart what gtkobject to use
  Returns:  nothing

  Applies a Message to the sender
 ------------------------------------------------------------------------------}
//TODO: remove ALCLObject when creation splitup is finished
procedure TGtk2WidgetSet._SetCallbackEx(const AMsg: LongInt;
  const AGTKObject: PGTKObject; const ALCLObject: TObject; Direct: Boolean);

  procedure ConnectSenderSignal(const AnObject:PGTKObject; const ASignal: PChar;
    const ACallBackProc: Pointer);
  begin
    ConnectSignal(AnObject,ASignal,ACallBackProc,ALCLObject);
  end;

  procedure ConnectSenderSignalAfter(const AnObject:PGTKObject;
    const ASignal: PChar; const ACallBackProc: Pointer);
  begin
    ConnectSignalAfter(AnObject,ASignal,ACallBackProc,ALCLObject);
  end;

  procedure ConnectSenderSignal(const AnObject:PGTKObject; const ASignal: PChar;
    const ACallBackProc: Pointer; const AReqSignalMask: TGdkEventMask);
  begin
    ConnectSignal(AnObject,ASignal,ACallBackProc,ALCLObject, AReqSignalMask);
  end;

  procedure ConnectSenderSignalAfter(const AnObject:PGTKObject;
    const ASignal: PChar; const ACallBackProc: Pointer;
    const AReqSignalMask: TGdkEventMask);
  begin
    ConnectSignalAfter(AnObject,ASignal,ACallBackProc,ALCLObject,
                       AReqSignalMask);
  end;

  procedure ConnectFocusEvents(const AnObject: PGTKObject);
  begin
    ConnectSenderSignal(AnObject, 'focus-in-event', @gtkFocusCB);
    ConnectSenderSignal(AnObject, 'focus-out-event', @gtkKillFocusCB);
    ConnectSenderSignalAfter(AnObject, 'focus-out-event', @gtkKillFocusCBAfter);
  end;

  procedure ConnectKeyPressReleaseEvents(const AnObject: PGTKObject);
  begin
    //debugln('ConnectKeyPressReleaseEvents A ALCLObject=',DbgSName(ALCLObject));
    ConnectSenderSignal(AnObject,
      'key-press-event', @GTKKeyPress, GDK_KEY_PRESS_MASK);
    ConnectSenderSignalAfter(AnObject,
      'key-press-event', @GTKKeyPressAfter, GDK_KEY_PRESS_MASK);
    ConnectSenderSignal(AnObject,
      'key-release-event', @GTKKeyRelease, GDK_KEY_RELEASE_MASK);
    ConnectSenderSignalAfter(AnObject,
      'key-release-event', @GTKKeyReleaseAfter, GDK_KEY_RELEASE_MASK);
  end;

  function GetAdjustment(const gObject: PGTKObject; vertical: boolean):PGtkObject;
  var
    Scroll: PGtkObject;
  begin
    if Vertical then begin
      if ALCLObject is TScrollBar then
        result := PGtkObject(PgtkhScrollBar(gObject)^.Scrollbar.Range.Adjustment)
      else if (ALCLObject is TScrollBox)
           or (ALCLObject is TCustomForm)
           or (ALCLObject is TCustomFrame)
      then begin
        Scroll := g_object_get_data(PGObject(gObject), odnScrollArea);
        Result := PGtkObject(gtk_scrolled_window_get_vadjustment(
          PGTKScrolledWindow(Scroll)));
      end
      else if GtkWidgetIsA(PGtkWidget(gObject),gtk_scrolled_window_get_type) then
      begin
        Result := PGtkObject(gtk_scrolled_window_get_vadjustment(
          PGTKScrolledWindow(gObject)))
      end else
        DebugLn(['TGtkWidgetSet.SetCallbackEx.GetAdjustment WARNING: invalid widget: ',GetWidgetDebugReport(PGtkWidget(gObject))]);

    end else begin
      if ALCLObject is TScrollBar then
        Result := PgtkObject(PgtkhScrollBar(gObject)^.Scrollbar.Range.Adjustment)
      else if (ALCLObject is TScrollBox)
           or (ALCLObject is TCustomForm)
           or (ALCLObject is TCustomFrame)
      then begin
        Scroll := g_object_get_data(PGObject(gObject), odnScrollArea);
        Result := PgtkObject(gtk_scrolled_window_get_hadjustment(
          PGTKScrolledWindow(Scroll)));
      end
      else if GtkWidgetIsA(PGtkWidget(gObject),gtk_scrolled_window_get_type) then
      begin
        //DebugLn(['GetAdjustment ',GetWidgetDebugReport(PGtkWidget(gObject))]);
        Result := PgtkObject(gtk_scrolled_window_get_hadjustment(
          PGTKScrolledWindow(gObject)));
      end else
        DebugLn(['TGtkWidgetSet.SetCallbackEx.GetAdjustment WARNING: invalid widget: ',GetWidgetDebugReport(PGtkWidget(gObject))]);
    end;
  end;

var
  gObject, gFixed, gCore, Adjustment: PGTKObject;
  gTemp: PGTKObject;
  Info: PWidgetInfo;
  gMain: PGtkObject;
  gMouse: PGtkObject;
begin
  //debugln('TGtkWidgetSet.SetCallback A ALCLObject=',DbgSName(ALCLObject),' AMsg=',dbgs(AMsg));
  if Direct then
  begin
    gMain := AGTKObject;
    gCore := AGTKObject;
    gFixed := AGTKObject;
    gMouse := AGTKObject;
    gObject := AGTKObject;
  end
  else
  begin
    // gObject
    if AGTKObject = nil then
      gObject := ObjectToGTKObject(ALCLObject)
    else
      gObject := AGTKObject;
    if gObject = nil then Exit;

    Info:=GetWidgetInfo(gObject);

    // gFixed is the widget with the client area (e.g. TGroupBox, TCustomForm have this)
    gFixed := PGTKObject(GetFixedWidget(gObject));
    if gFixed = nil then
      gFixed := gObject;

    // gCore is the working widget (e.g. TListBox has a scrolling widget (=main widget) and a tree widget (=core widget))
    gCore:=PGtkObject(Info^.CoreWidget);
    gMain:=GetMainWidget(gObject);
    if (gMain<>gObject) then
      DebugLn(['TGtkWidgetSet.SetCallback WARNING: gObject<>MainWidget ',DbgSName(ALCLObject)]);

    if (gFixed <> gMain) then
      gMouse := gFixed
    else
      gMouse := gCore;

    if gMouse=nil then
      DebugLn(['TGtkWidgetSet.SetCallback WARNING: gMouseWidget=nil ',DbgSName(ALCLObject)]);

    if GTK_IS_FIXED(gMouse) and GTK_WIDGET_NO_WINDOW(gMouse) then
    begin
      gTemp := PGtkObject(gtk_widget_get_parent(PGtkWidget(gMouse)));
      //DebugLn(gtk_type_name(g_object_type(gMouse)) + ' => ' + gtk_type_name(g_object_type(gTemp)));
      if GTK_IS_EVENT_BOX(gTemp) then
        gMouse := gTemp;
    end;
  end;
  //DebugLn(['TGtkWidgetSet.SetCallbackSmart MouseWidget=',GetWidgetDebugReport(PGtkWidget(gMouse))]);

  case AMsg of
    LM_SHOWWINDOW :
    begin
      ConnectSenderSignal(gObject, 'show', @gtkshowCB);
      ConnectSenderSignal(gObject, 'hide', @gtkhideCB);
    end;

    LM_DESTROY :
    begin
      //DebugLn(['TGtkWidgetSet.SetCallback ',DbgSName(ALCLObject)]);
      ConnectSenderSignal(gObject, 'destroy', @gtkdestroyCB);
    end;

    LM_CLOSEQUERY :
    begin
      ConnectSenderSignal(gObject, 'delete-event', @gtkdeleteCB);
    end;

    LM_ACTIVATE :
    begin
      if (ALCLObject is TCustomForm) and (TCustomForm(ALCLObject).Parent=nil)
      then begin
        ConnectSenderSignal(gObject, 'focus-in-event', @gtkfrmactivateAfter);
        ConnectSenderSignal(gObject, 'focus-out-event', @gtkfrmdeactivateAfter);
      end else if ALCLObject is TCustomMemo then
        ConnectSenderSignal(gCore, 'activate', @gtkactivateCB)
      else
        ConnectSenderSignal(gObject, 'activate', @gtkactivateCB);
    end;

    LM_ACTIVATEITEM :
    begin
      ConnectSenderSignal(gObject, 'activate-item', @gtkactivateCB);
    end;

    LM_CHANGED :
    begin
       if ALCLObject is TCustomTrackBar then
       begin
         ConnectSenderSignal(gtk_Object(
                   gtk_range_get_adjustment(GTK_RANGE(gObject))) ,
                      'value_changed', @gtkvaluechanged);
       end
       else
       if ALCLObject is TCustomMemo then
         ConnectSenderSignal(gCore, 'changed', @gtkchanged_editbox)
       else if ALCLObject is TCustomCheckbox then
       begin
         ConnectSenderSignal(gObject, 'toggled', @gtktoggledCB)
       end else
       begin
         if GTK_IS_ENTRY(gObject) then
         begin
           ConnectSenderSignal(gObject,'delete-text', @gtkchanged_editbox_delete_text);
           ConnectSenderSignal(gObject,'insert-text', @gtkchanged_editbox_insert_text);
           ConnectSenderSignal(gObject,'delete-from-cursor', @gtkchanged_editbox_delete);
           ConnectSenderSignal(gObject,'paste-clipboard', @gtkpaste_editbox);
         end;
         ConnectSenderSignal(gObject, 'changed', @gtkchanged_editbox);
       end;
    end;

    LM_CLICKED:
    begin
      ConnectSenderSignal(gObject, 'clicked', @gtkclickedCB);
    end;

    LM_CONFIGUREEVENT :
    begin
      ConnectSenderSignal(gObject, 'configure-event', @gtkconfigureevent);
    end;

    LM_DAYCHANGED :  //calendar
    Begin
      ConnectSenderSignal(gCore, 'day-selected', @gtkdaychanged);
      ConnectSenderSignal(gCore, 'day-selected-double-click', @gtkdaychanged);
    end;

    LM_PAINT :
    begin
      //DebugLn(['TGtkWidgetSet.SetCallback ',DbgSName(ALCLObject),' ',GetWidgetDebugReport(PGtkWIdget(gfixed))]);
      ConnectSenderSignal(gFixed,'expose-event', @GTKExposeEvent);
      ConnectSenderSignalAfter(gFixed,'expose-event', @GTKExposeEventAfter);
      {$IFDEF EventTrace}
      ConnectSenderSignal(gFixed,'style-set', @GTKStyleChanged);
      ConnectSenderSignalAfter(gFixed,'style-set', @GTKStyleChangedAfter);
      {$ENDIF}
    end;


    LM_MONTHCHANGED:  //calendar
    Begin
      ConnectSenderSignal(gCore, 'month-changed', @gtkmonthchanged);
      ConnectSenderSignal(gCore, 'prev-month', @gtkmonthchanged);
      ConnectSenderSignal(gCore, 'next-month', @gtkmonthchanged);
    end;

    LM_MOUSEMOVE:
    begin
      ConnectSenderSignal(gMouse, 'motion-notify-event', @GTKMotionNotify,
                    GDK_POINTER_MOTION_HINT_MASK or GDK_POINTER_MOTION_MASK);
      ConnectSenderSignalAfter(gMouse, 'motion-notify-event',
                    @GTKMotionNotifyAfter,
                    GDK_POINTER_MOTION_HINT_MASK or GDK_POINTER_MOTION_MASK);
    end;

    LM_LBUTTONDOWN,
    LM_RBUTTONDOWN,
    LM_MBUTTONDOWN,
    LM_MOUSEWHEEL,
    LM_MOUSEHWHEEL:
    begin
      ConnectSenderSignal(gMouse, 'button-press-event', @gtkMouseBtnPress,
                          GDK_BUTTON_PRESS_MASK);
      ConnectSenderSignalAfter(gMouse, 'button-press-event',
                               @gtkMouseBtnPressAfter, GDK_BUTTON_PRESS_MASK);
      ConnectSenderSignal(gMouse, 'scroll-event', @gtkMouseWheelCB,
                          GDK_BUTTON_PRESS_MASK);
    end;

    LM_LBUTTONUP,
    LM_RBUTTONUP,
    LM_MBUTTONUP:
    begin
      ConnectSenderSignal(gMouse, 'button-release-event', @gtkMouseBtnRelease,
                    GDK_BUTTON_RELEASE_MASK);
      ConnectSenderSignalAfter(gMouse, 'button-release-event',
                         @gtkMouseBtnReleaseAfter,GDK_BUTTON_RELEASE_MASK);
    end;

    LM_ENTER :
    begin
      if ALCLObject is TCustomButton then
        ConnectSenderSignal(gObject, 'enter', @gtkenterCB)
      else
        ConnectSenderSignal(gObject, 'focus-in-event', @gtkFocusInNotifyCB); //TODO: check this focus in is mapped to focus
    end;

    LM_EXIT :
    begin
      if ALCLObject is TCustomButton then
        ConnectSenderSignal(gObject, 'leave', @gtkleaveCB)
      else
        ConnectSenderSignal(gObject, 'focus-out-event', @gtkFocusOutNotifyCB);
    end;

    LM_LEAVE :
    begin
      ConnectSenderSignal(gObject, 'leave', @gtkleaveCB);
    end;

    LM_WINDOWPOSCHANGED: //LM_SIZEALLOCATE, LM_RESIZE :
    begin
      ConnectSenderSignal(gObject, 'size-allocate', @gtksize_allocateCB);
      if gObject<>gFixed then
      begin
        ConnectSenderSignal(gFixed, 'size-allocate', @gtksize_allocate_client);
      end;
    end;

    LM_CHECKRESIZE :
    begin
      ConnectSenderSignal(gObject, 'check-resize', @gtkresizeCB);
    end;

    LM_SETEDITABLE :
    begin
      ConnectSenderSignal(gObject, 'set-editable', @gtkseteditable);
    end;

    LM_MOVEWORD :
    begin
      ConnectSenderSignal(gObject, 'move-word', @gtkmoveword);
    end;

    LM_MOVEPAGE :
    begin
      ConnectSenderSignal(gObject, 'move-page', @gtkmovepage);
    end;

    LM_MOVETOROW :
    begin
      ConnectSenderSignal(gObject, 'move-to-row', @gtkmovetorow);
    end;

    LM_MOVETOCOLUMN :
    begin
      ConnectSenderSignal(gObject, 'move-to-column', @gtkmovetocolumn);
    end;

    LM_MOUSEENTER:
    begin
      if gCore<>nil then
        ConnectSenderSignal(gCore, 'enter', @gtkEnterCB)
    end;

    LM_MOUSELEAVE:
    begin
      if gCore<>nil then
        ConnectSenderSignal(gCore, 'leave', @gtkLeaveCB)
    end;

    LM_KILLCHAR :
    begin
      ConnectSenderSignal(gObject, 'kill-char', @gtkkillchar);
    end;

    LM_KILLWORD :
    begin
      ConnectSenderSignal(gObject, 'kill-word', @gtkkillword);
    end;

    LM_KILLLINE :
    begin
      ConnectSenderSignal(gObject, 'kill-line', @gtkkillline);
    end;

    LM_CUT:
    begin
      if (ALCLObject is TCustomMemo) then
        ConnectSenderSignal(gCore, 'cut-clipboard', @gtkcuttoclip)
      else
        ConnectSenderSignal(gObject, 'cut-clipboard', @gtkcuttoclip);
    end;

    LM_COPY:
    begin
      if (ALCLObject is TCustomMemo) then
        ConnectSenderSignal(gCore, 'copy-clipboard', @gtkcopytoclip)
      else
        ConnectSenderSignal(gObject, 'copy-clipboard', @gtkcopytoclip);
    end;

    LM_PASTE:
    begin
      if (ALCLObject is TCustomMemo) then
        ConnectSenderSignal(gCore, 'paste-clipboard', @gtkpastefromclip)
      else
        ConnectSenderSignal(gObject, 'paste-clipboard', @gtkpastefromclip);
    end;

    LM_HSCROLL:
    begin
      Adjustment := GetAdjustment(gObject, False);
      if Adjustment <> nil then
        ConnectSenderSignal(Adjustment, 'value-changed', @GTKHScrollCB);
    end;

    LM_VSCROLL:
    begin
      Adjustment := GetAdjustment(gObject, True);
      if Adjustment <> nil then
        ConnectSenderSignal(Adjustment, 'value-changed', @GTKVScrollCB);
    end;

    LM_YEARCHANGED :  //calendar
    Begin
      ConnectSenderSignal(gCore, 'prev-year', @gtkyearchanged);
      ConnectSenderSignal(gCore, 'next-year', @gtkyearchanged);
    end;

    // Listview & Header control
    LM_COMMAND:
    begin
      if ALCLObject is TCustomComboBox then begin
        ConnectSenderSignalAfter(PgtkObject(PgtkCombo(gObject)^.popwin),
          'show', @gtkComboBoxShowAfter);
        ConnectSenderSignalAfter(PgtkObject(PgtkCombo(gObject)^.popwin),
          'hide', @gtkComboBoxHideAfter);
      end;
    end;

    LM_SelChange:
    begin
      if ALCLObject is TCustomListBox then
        ConnectSenderSignalAfter(PgtkObject(gCore),
          'selection_changed', @gtkListBoxSelectionChangedAfter);
    end;

    LM_DROPFILES:
      ConnectSenderSignal(gCore, 'drag_data_received', @GtkDragDataReceived);

(*
    LM_WINDOWPOSCHANGED:
    begin
      ConnectSenderSignal(gObject, 'size-allocate', @gtkSizeAllocateCB);
//      ConnectSenderSignal(gObject, 'move_resize', @gtkmoveresize);
    end;
*)
  else
    //DebugLn(Format('Trace:ERROR:  Signal %d not found!', [AMsg]));
  end;
end;

{------------------------------------------------------------------------------
  Function: TGtk2WidgetSet.SetCallbackEx
  Params: Msg - message for which to set a callback
          sender - object to which callback will be send
  Returns:  nothing

  Applies a Message to the sender
 ------------------------------------------------------------------------------}
procedure TGtk2WidgetSet.SetCallbackEx(const AMsg: LongInt;
  const AGTKObject: PGTKObject; const ALCLObject: TObject; Direct: Boolean);

  procedure ConnectSenderSignal(const AnObject:PGTKObject; const ASignal: PChar;
    const ACallBackProc: Pointer);
  begin
    ConnectSignal(AnObject, ASignal, ACallBackProc, ALCLObject);
  end;

  procedure ConnectSenderSignalAfter(const AnObject:PGTKObject;
    const ASignal: PChar; const ACallBackProc: Pointer);
  begin
    ConnectSignalAfter(AnObject, ASignal, ACallBackProc, ALCLObject);
  end;

  procedure ConnectSenderSignal(const AnObject:PGTKObject; const ASignal: PChar;
    const ACallBackProc: Pointer; const ReqSignalMask: TGdkEventMask);
  begin
    ConnectSignal(AnObject, ASignal, ACallBackProc, ALCLObject,
                  ReqSignalMask);
  end;

  procedure ConnectSenderSignalAfter(const AnObject:PGTKObject;
    const ASignal: PChar; const ACallBackProc: Pointer;
    const ReqSignalMask: TGdkEventMask);
  begin
    ConnectSignalAfter(AnObject, ASignal, ACallBackProc, ALCLObject,
                       ReqSignalMask);
  end;

  procedure ConnectFocusEvents(const AnObject: PGTKObject);
  begin
    //DebugLn(['ConnectFocusEvents ',GetWidgetDebugReport(PGtkWidget(AnObject))]);
    ConnectSenderSignal(AnObject, 'focus-in-event', @gtk2FocusCB);
    ConnectSenderSignal(AnObject, 'focus-out-event', @gtk2KillFocusCB);
    ConnectSenderSignalAfter(AnObject, 'focus-out-event', @gtk2KillFocusCBAfter);
  end;

  procedure ConnectKeyPressReleaseEvents(const AnObject: PGTKObject);
  begin
    //debugln('gtk2object ConnectKeyPressReleaseEvents A ALCLObject=',DbgSName(ALCLObject));
    ConnectSenderSignal(AnObject,
      'key-press-event', @GTKKeyPress, GDK_KEY_PRESS_MASK);
    ConnectSenderSignalAfter(AnObject,
      'key-press-event', @GTKKeyPressAfter, GDK_KEY_PRESS_MASK);
    ConnectSenderSignal(AnObject,
      'key-release-event', @GTKKeyRelease, GDK_KEY_RELEASE_MASK);
    ConnectSenderSignalAfter(AnObject,
      'key-release-event', @GTKKeyReleaseAfter, GDK_KEY_RELEASE_MASK);
  end;

var
  gObject, gFixed, gCore: PGTKObject;
begin
  //debugln('gtk2object.inc TGtk2WidgetSet.SetCallback A ALCLObject=',DbgSName(ALCLObject),' AMsg=',dbgs(AMsg));
  if Direct then
  begin
    gObject := AGTKObject;
    gFixed := AGTKObject;
    gCore := AGTKObject;
  end
  else
  begin
    // gObject
    if AGTKObject = nil then gObject := ObjectToGTKObject(ALCLObject)
    else gObject := AGTKObject;

    if gObject = nil then Exit;

    // gFixed is the widget with the client area (e.g. TGroupBox, TForm have this)
    gFixed := PGTKObject(GetFixedWidget(gObject));
    if gFixed = nil then gFixed := gObject;

    // gCore is the main widget (e.g. TListView has this)
    gCore:= PGtkObject(GetWidgetInfo(gObject)^.CoreWidget);
  end;

  case AMsg of
    LM_FOCUS :
    begin
      ConnectFocusEvents(gCore);
    end;

    LM_GRABFOCUS:
    begin
      ConnectSenderSignal(gObject, 'grab_focus', @gtkActivateCB);
    end;

    LM_CHAR,
    LM_KEYDOWN,
    LM_KEYUP,
    LM_SYSCHAR,
    LM_SYSKEYDOWN,
    LM_SYSKEYUP:
    begin
      if ((ALCLObject is TCustomComboBox) and gtk_is_combo_box_entry(gObject))
      or (ALCLObject is TCustomForm) then
        ConnectKeyPressReleaseEvents(gObject);

      ConnectKeyPressReleaseEvents(gCore);
    end;

    LM_SHOWWINDOW :
    begin
      ConnectSenderSignal(gObject, 'show', @gtk2showCB);
      ConnectSenderSignal(gObject, 'hide', @gtk2hideCB);
    end;

    LM_CONTEXTMENU:
      ConnectSenderSignal(gObject, 'popup-menu', @gtk2PopupMenuCB); // TCustomControl needs gObject, not gCore nor gFixed

  else
    _SetCallbackEx(AMsg, AGTKObject, ALCLObject, Direct);
  end;
end;

procedure TGtk2WidgetSet.SetCommonCallbacks(const AGTKObject: PGTKObject;
  const ALCLObject: TObject);
var
  Widget: PGtkWidget;
begin
  if GTK_IS_SCROLLED_WINDOW(AGtkObject) then
  begin
    Widget := PGtkWidget(AGTKObject);
    g_signal_connect_after(GTK_SCROLLED_WINDOW(Widget)^.vscrollbar, 'button-press-event',
      TGCallback(@gtk2ScrollBarMouseBtnPress), ALCLObject);
    g_signal_connect_after(GTK_SCROLLED_WINDOW(Widget)^.vscrollbar, 'button-release-event',
      TGCallback(@gtk2ScrollBarMouseBtnRelease), ALCLObject);

    g_signal_connect_after(GTK_SCROLLED_WINDOW(Widget)^.hscrollbar, 'button-press-event',
      TGCallback(@gtk2ScrollBarMouseBtnPress), ALCLObject);
    g_signal_connect_after(GTK_SCROLLED_WINDOW(Widget)^.hscrollbar, 'button-release-event',
      TGCallback(@gtk2ScrollBarMouseBtnRelease), ALCLObject);
  end;

  SetCallback(LM_SHOWWINDOW, AGTKObject, ALCLObject);
  SetCallback(LM_DESTROY, AGTKObject, ALCLObject);
  SetCallback(LM_FOCUS, AGTKObject, ALCLObject);
  SetCallback(LM_WINDOWPOSCHANGED, AGTKObject, ALCLObject);
  SetCallback(LM_PAINT, AGTKObject, ALCLObject);
  SetCallback(LM_KEYDOWN, AGTKObject, ALCLObject);
  SetCallback(LM_KEYUP, AGTKObject, ALCLObject);
  SetCallback(LM_CHAR, AGTKObject, ALCLObject);
  SetCallback(LM_MOUSEMOVE, AGTKObject, ALCLObject);
  SetCallback(LM_LBUTTONDOWN, AGTKObject, ALCLObject);
  SetCallback(LM_LBUTTONUP, AGTKObject, ALCLObject);
  SetCallback(LM_RBUTTONDOWN, AGTKObject, ALCLObject);
  SetCallback(LM_RBUTTONUP, AGTKObject, ALCLObject);
  SetCallback(LM_MBUTTONDOWN, AGTKObject, ALCLObject);
  SetCallback(LM_MBUTTONUP, AGTKObject, ALCLObject);
  SetCallback(LM_MOUSEWHEEL, AGTKObject, ALCLObject);
  SetCallback(LM_MOUSEHWHEEL, AGTKObject, ALCLObject);
  SetCallback(LM_DROPFILES, AGTKObject, ALCLObject);
  SetCallback(LM_CONTEXTMENU, AGtkObject, ALCLObject);

  // set gtk2 only callbacks
  ConnectSignal(AGTKObject, 'show-help', @gtk2ShowHelpCB, ALCLObject);
  ConnectSignal(AGTKObject,'grab-notify',@gtk2GrabNotify, ALCLObject);
end;

procedure TGtk2WidgetSet.SetLabelCaption(const ALabel: PGtkLabel;
  const ACaption: String);
var
  s: String;
  i: Integer;
begin
  s := '';
  i := 1;
  while i <=  Length(ACaption) do
  begin
    case ACaption[i] of
      '_': s := s + '__';
      '&':
        if (i < Length(ACaption)) and (ACaption[i + 1] = '&') then
        begin
          s := s + '&';
          inc(i);
        end
        else
          s := s + '_';
    else
      s := s + ACaption[i];
    end;
    inc(i);
  end;
  gtk_label_set_text_with_mnemonic(ALabel, PChar(s));
end;

{------------------------------------------------------------------------------
  procedure TGtk2WidgetSet.SetSelectionMode(Sender: TObject; Widget: PGtkWidget;
    MultiSelect, ExtendedSelect: boolean);
------------------------------------------------------------------------------}
procedure TGtk2WidgetSet.SetSelectionMode(Sender: TObject; Widget: PGtkWidget;
  MultiSelect, ExtendedSelect: Boolean);
var
  AControl: TWinControl;
  SelectionMode: TGtkSelectionMode;
  Selection : PGtkTreeSelection;
begin
  AControl:=TWinControl(Sender);
  if (AControl is TWinControl) and
    (AControl.fCompStyle in [csListBox, csCheckListBox]) then
  begin
    if MultiSelect then
      SelectionMode:= GTK_SELECTION_MULTIPLE
    else
      SelectionMode:= GTK_SELECTION_SINGLE;
      
    Selection := gtk_tree_view_get_selection(GTK_TREE_VIEW(
       GetOrCreateWidgetInfo(Widget)^.CoreWidget));
    gtk_tree_selection_set_mode(Selection, SelectionMode);
  end;
end;

procedure TGtk2WidgetSet.SetWidgetFont(const AWidget: PGtkWidget;
  const AFont: TFont);
var
  FontDesc: PPangoFontDescription;
  UseFont: PPangoLayout;
begin
  if GtkWidgetIsA(AWidget,GTKAPIWidget_GetType) then begin
    // the GTKAPIWidget is self drawn, so no use to change the widget style.
    exit;
  end;

  UseFont := {%H-}PGdiObject(AFont.Reference.Handle)^.GDIFontObject;
  FontDesc := pango_layout_get_font_description(UseFont);
  gtk_widget_modify_font(AWidget, FontDesc);
end;

function TGtk2WidgetSet.CreateThemeServices: TThemeServices;
begin
  Result := TGtk2ThemeServices.Create;
end;

constructor TGtk2WidgetSet.Create;
{$IFDEF HASX}
const
  WMNoTransient: array[0..1] of String = (
    'kwin',
    'awesome'
  );

  function IsNoTransientWM: Boolean;
  var
    wmname: String;
    i: Integer;
  begin
    wmname := GetWindowManager;
    //DebugLn('Window Manager identifier: ', wmname);
    Result := False;
    for i := Low(WMNoTransient) to High(WMNoTransient) do
      if wmname = WMNoTransient[i] then
        Exit(True);
  end;

{$ENDIF}
begin
  inherited Create;
  FCachedTitleBarHeight := -1;
  FCachedBorderSize := 4;
  Gtk2Create;
  {$IFNDEF USE_GTK_MAIN_OLD_ITERATION}
  FMainPoll := nil;
  if not FIsLibraryInstance then
  begin
    FWSFrameRect := Rect(0, 0, 0, 0);
    Gtk2MPF := g_main_context_get_poll_func(g_main_context_default);
    g_main_context_set_poll_func(g_main_context_default, @Gtk2PollFunction);
  end else
    Gtk2MPF := nil;
  {$ENDIF}
  StayOnTopList := nil;
  im_context:=gtk_im_multicontext_new;
  g_signal_connect (G_OBJECT (im_context), 'commit',
    G_CALLBACK (@gtk_commit_cb), nil);
  {$IFDEF WITH_GTK2_IM}
  // Input method
  g_signal_connect (G_OBJECT (im_context), 'preedit-start',
    G_CALLBACK (@gtk_preedit_start_cb), nil);
  g_signal_connect (G_OBJECT (im_context), 'preedit-end',
    G_CALLBACK (@gtk_preedit_end_cb), nil);
  g_signal_connect (G_OBJECT (im_context), 'preedit-changed',
    G_CALLBACK (@gtk_preedit_changed_cb), nil);
  g_signal_connect (G_OBJECT (im_context), 'retrieve_surrounding',
    G_CALLBACK (@gtk_retrieve_surrounding_cb), nil);
  {$ENDIF}
  {$IFDEF HASX}
  if IsNoTransientWM then
  begin
    //some window managers do their own transient settings
    UseTransientForModalWindows := False;
    FDesktopWidget := gtk_window_new(GTK_WINDOW_TOPLEVEL);
    gtk_widget_set_parent_window(FDesktopWidget, gdk_get_default_root_window);
    gtk_widget_set_uposition(FDesktopWidget, 0, 0);
    gtk_widget_set_usize(FDesktopWidget, 1, 1);
    //we must show it, so X11 maps this widget
    gtk_widget_show(FDesktopWidget);
    //hide it imediatelly, so it is really invisible widget
    gtk_widget_hide(FDesktopWidget);
  end else
    FDesktopWidget := nil;
  {$ENDIF}
end;

destructor TGtk2WidgetSet.Destroy;
begin
  g_object_unref(im_context);
  im_context:=nil;
  im_context_widget:=nil;
  FreeAndNil(StayOnTopList);
  Gtk2Destroy;
  {$IFDEF HASX}
  if FDesktopWidget <> nil then
  begin
    gtk_widget_destroy(FDesktopWidget);
    FDesktopWidget := nil;
  end;
  {$ENDIF}

  inherited Destroy;
end;

function TGtk2WidgetSet.LCLPlatform: TLCLPlatform;
begin
  Result:= lpGtk2;
end;

function TGtk2WidgetSet.GetLCLCapability(ACapability: TLCLCapability): PtrUInt;
begin
  case ACapability of
    // Transparency partly works but code completion window would go behind SynEdit -> NO
    lcTransparentWindow: Result := LCL_CAPABILITY_NO;
  else
    Result := inherited GetLCLCapability(ACapability);
  end;
end;

function gdk_screen_get_resolution(screen:PGdkScreen):gdouble; cdecl; external gdklib;

{------------------------------------------------------------------------------
  Method: TGtk2WidgetSet.AppInit
  Params:  None
  Returns: Nothing

  *Note: Initialize GTK engine
  (is called by TApplication.Initialize which is typically after all
   finalization sections)
 ------------------------------------------------------------------------------}
procedure TGtk2WidgetSet.AppInit(var ScreenInfo: TScreenInfo);
begin
  {$if defined(cpui386) or defined(cpux86_64)}
  // needed otherwise some gtk theme engines crash with division by zero
  {$IFNDEF DisableGtkDivZeroFix}
    SetExceptionMask(GetExceptionMask + [exOverflow,exZeroDivide,exInvalidOp]);
  {$ENDIF}
  {$ifend}

  InitKeyboardTables;
  { Compute pixels per inch variable }
  ScreenInfo.PixelsPerInchX :=
    RoundToInt(gdk_screen_get_resolution(gdk_screen_get_default));
  ScreenInfo.PixelsPerInchY :=
    ScreenInfo.PixelsPerInchX;
  if ScreenInfo.PixelsPerInchX <= 0 then
  begin
    ScreenInfo.PixelsPerInchX :=
      RoundToInt(gdk_screen_width / (GetScreenWidthMM / 25.4));
    ScreenInfo.PixelsPerInchY :=
      RoundToInt(gdk_screen_height / (GetScreenHeightMM / 25.4));
  end;
  ScreenInfo.ColorDepth := gdk_visual_get_system^.depth;
end;

procedure TGtk2WidgetSet.AppBringToFront;
begin
  if Assigned(Application.MainForm) and Application.MainForm.HandleAllocated then
  begin
    gdk_window_raise({%H-}PGtkWidget(Application.MainForm.Handle)^.window);
    gdk_window_focus({%H-}PGtkWidget(Application.MainForm.Handle)^.window,
                                gtk_get_current_event_time);
  end;
end;

procedure TGtk2WidgetSet.AppMinimize;
var
  i: Integer;
  AForm: TCustomForm;
  WInfo: PWidgetInfo;
begin
  if Screen=nil then exit;
  {$IFDEF HASX}
  HideAllHints;
  {$ENDIF}
  for i:= 0 to Screen.CustomFormZOrderCount-1 do
  begin
    AForm := Screen.CustomFormsZOrdered[i];
    if (AForm.Parent=nil) and AForm.HandleAllocated and
      GTK_WIDGET_VISIBLE({%H-}PGtkWidget(AForm.Handle)) and
      not (AForm.FormStyle in [fsMDIChild, fsSplash]) and
      not (AForm.BorderStyle in [bsNone]) then
      begin
        WInfo := GetWidgetInfo({%H-}PGtkWidget(AForm.Handle));
        // prevent recursion in gtk2wsforms GDK_WINDOW_STATE event
        if WInfo^.FormWindowState.new_window_state <> GDK_WINDOW_STATE_ICONIFIED then
          gtk_window_iconify({%H-}PGtkWindow(AForm.Handle));
      end;
  end;
end;

procedure TGtk2WidgetSet.AppRestore;
var
  i: Integer;
  AForm: TCustomForm;
begin
  if Screen=nil then exit;
  for i:= Screen.CustomFormZOrderCount-1 downto 0 do
  begin
    AForm:=Screen.CustomFormsZOrdered[i];
    if (AForm.Parent=nil) and AForm.HandleAllocated and
      GTK_WIDGET_VISIBLE({%H-}PGtkWidget(AForm.Handle)) and
      not (AForm.FormStyle in [fsMDIChild, fsSplash]) and
      not (AForm.BorderStyle in [bsNone]) then
        gtk_window_deiconify({%H-}PGtkWindow(AForm.Handle));
  end;
  {$IFDEF HASX}
  RestoreAllHints;
  {$ENDIF}
end;

function TGtk2WidgetSet.GetAppHandle: THandle;
begin
  {$ifdef windows}
  Result := GetWin32AppHandle;
  {$else}
  Result := inherited GetAppHandle;
  {$endif}
end;

type
  TGtk2TempFormStyleSet = Set of TFormStyle;
const
  TGtk2TopForms: Array[Boolean] of TGtk2TempFormStyleSet = (fsAllNonSystemStayOnTop,
    fsAllStayOnTop);


procedure gdk_window_restack(w, s: PGdkWindow; above: gboolean); cdecl; external gdklib;
function gdk_screen_get_active_window(screen: PGdkScreen):PGdkWindow; cdecl; external gdklib;

function TGtk2WidgetSet.AppRemoveStayOnTopFlags(const ASystemTopAlso: Boolean
  ): Boolean;
var
  i: Integer;
  AForm: TCustomForm;
  W: PGtkWidget;
  Flags: TGdkWindowState;
  B: Boolean;
  act: PGdkWindow;
  nact: PGdkWindow;
begin
  Result := True;
  if StayOnTopList = nil then
    StayOnTopList := TMap.Create(TMapIdType(ituPtrSize), SizeOf(TGtkWidget));

  // todo: all screens should be evaluated
  // depending on the screen of a window
  act:=gdk_screen_get_active_window(gdk_screen_get_default);
  // act is typically returned for X11. other systems might
  // not implement it.
  nact:=act;

  for i := 0 to Screen.CustomFormZOrderCount - 1 do
  begin
    AForm := Screen.CustomFormsZOrdered[i];
    if AForm.HandleAllocated then
    begin
      W := {%H-}PGtkWidget(AForm.Handle);
      // do not raise assertion in case of invalid PGdkWindow
      B := GDK_IS_WINDOW(W^.Window);
      if B then
        Flags := gdk_window_get_state(W^.Window);
      if B and (AForm.Parent = nil) and
        not (csDesigning in AForm.ComponentState) and
        (AForm.FormStyle in TGtk2TopForms[ASystemTopAlso]) and
         GTK_WIDGET_VISIBLE(W) and
         not gtk_window_get_modal(PGtkWindow(W)) and
         (Flags and GDK_WINDOW_STATE_ICONIFIED = 0) then
      begin
        gdk_window_set_keep_above(W^.Window, False);
        if Assigned(nact) then
        begin
          gdk_window_restack(W^.Window, act, False);
          nact:=W^.Window;
        end
        else begin
          gdk_window_lower(W^.Window); // send to the bottom
          gdk_window_raise(W^.Window); // restore back
        end;
        if not StayOnTopList.HasId(W) then
          StayOnTopList.Add(W, W);
      end;
    end;
  end;
  if Assigned(act) then g_object_unref(act);
end;

function TGtk2WidgetSet.AppRestoreStayOnTopFlags(const ASystemTopAlso: Boolean
  ): Boolean;
var
  i: Integer;
  AForm: TCustomForm;
  W: PGtkWidget;
  Flags: TGdkWindowState;
  B: Boolean;
begin
  Result := True;
  if StayOnTopList = nil then
    exit;
  for i := Screen.CustomFormZOrderCount - 1 downto 0 do
  begin
    AForm := Screen.CustomFormsZOrdered[i];
    if AForm.HandleAllocated then
    begin
      W := {%H-}PGtkWidget(AForm.Handle);
      // do not raise assertion in case of invalid PGdkWindow
      B := GDK_IS_WINDOW(W^.Window);
      if B then
        Flags := gdk_window_get_state(W^.Window);
      if B and (AForm.Parent = nil) and
        not (csDesigning in AForm.ComponentState) and
        (AForm.FormStyle in TGtk2TopForms[ASystemTopAlso]) and
         GTK_WIDGET_VISIBLE(W) and
         not gtk_window_get_modal(PGtkWindow(W)) and
         (Flags and GDK_WINDOW_STATE_ICONIFIED = 0) then
      begin
        if StayOnTopList.HasId(W) then
          gdk_window_set_keep_above(W^.Window, True);
      end;
    end;
  end;
  FreeAndNil(StayOnTopList);
end;


{off $define GtkFixedWithWindow}
{------------------------------------------------------------------------------
  Procedure: GLogFunc

  Replaces the default glib loghandler. All errors, warnings etc, are logged
  through this function.
  Here are Fatals, Criticals and Errors translated to Exceptions
  Comment Ex to skip exception, comment Level to skip logging
 ------------------------------------------------------------------------------}
procedure GLogFunc(ALogDomain: Pgchar; ALogLevel: TGLogLevelFlags;
  AMessage: Pgchar; AData: gpointer);cdecl;
var
  Flag, Level, Domain: String;
  Ex: ExceptClass;
begin
(*
    G_LOG_FLAG_RECURSION = 1 shl 0;
    G_LOG_FLAG_FATAL = 1 shl 1;
    G_LOG_LEVEL_ERROR = 1 shl 2;
    G_LOG_LEVEL_CRITICAL = 1 shl 3;
    G_LOG_LEVEL_WARNING = 1 shl 4;
    G_LOG_LEVEL_MESSAGE = 1 shl 5;
    G_LOG_LEVEL_INFO = 1 shl 6;
    G_LOG_LEVEL_DEBUG = 1 shl 7;
    G_LOG_LEVEL_MASK = (1 shl 8) - 2;
*)
  if (AData=nil) then ;

  Ex := nil;
  Level := '';
  Flag := '';

  if ALogDomain = nil
  then Domain := ''
  else Domain := ALogDomain + ': ';

  if ALogLevel and G_LOG_FLAG_RECURSION <> 0
  then Flag := '[RECURSION] ';

  if ALogLevel and G_LOG_FLAG_FATAL <> 0
  then Flag := Flag + '[FATAL] ';

  if ALogLevel and G_LOG_LEVEL_ERROR <> 0
  then begin
    Level := 'ERROR';
    Ex := EInterfaceError;
  end
  else
  if ALogLevel and G_LOG_LEVEL_CRITICAL <> 0
  then begin
    Level := 'CRITICAL';
    Ex := EInterfaceCritical;
  end
{ Commented out for issue #31138. The whole system freezed because of GTK2 exception:
"Invalid borders specified for theme pixmap: .../line-h.png. Borders don't fit within the image."
ToDo: Fix the issue properly.
  else
  if ALogLevel and G_LOG_LEVEL_WARNING <> 0
  then begin
    Level := 'WARNING';
    Ex := EInterfaceWarning;
  end
}
  else
  if ALogLevel and G_LOG_LEVEL_INFO <> 0
  then begin
    Level := 'INFO';
  end
  else
  if ALogLevel and G_LOG_LEVEL_DEBUG <> 0
  then begin
    Level := 'DEBUG';
  end
  else begin
    Level := 'USER';
  end;

  if Ex = nil
  then begin
    if Level <> ''
    then DebugLn('[', Level, '] ', Flag, Domain, AMessage);
  end
  else begin
    if ALogLevel and G_LOG_FLAG_FATAL <> 0
    then begin
      // always create exception
      //
      // see callstack for more info
      raise Ex.Create(Flag + Domain + AMessage);
    end
    else begin
      // create a debugger trappable exception
      // but for now let the app continue and log a line
      // in future when all warnings etc. are gone they might raise
      // a real exception
      //
      // see callstack for more info
      try
        raise Ex.Create(Flag + Domain + AMessage);
      except
        on Exception do begin
          // just write a line
          DebugLn('[', Level, '] ', Flag, Domain, AMessage);
        end;
      end;
    end;
  end;

end;

{$ifdef Unix}

// TThread.Synchronize support
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

{$endif}

{------------------------------------------------------------------------------
  Method: TGtk2WidgetSet.Create
  Params:  None
  Returns: Nothing

  Constructor for the class.
 ------------------------------------------------------------------------------}
procedure TGtk2WidgetSet.Gtk2Create;
{$IFDEF EnabledGtkThreading}
{$IFNDEF Win32}
var
  TM: TThreadManager;
  GtkThread: PGThread;
{$ENDIF}
{$ENDIF}
begin
  //if ClassType = TGtkWidgetSet
  //then raise EInvalidOperation.Create('Cannot create the base gtkwidgetset, use gtk1 or gtk2 instead');

  FAppActive := False;
  FLastFocusIn := nil;
  FLastFocusOut := nil;

  LastWFPMousePos := Point(MaxInt, MaxInt);

  FIsLibraryInstance := False;
  FGtkTerminated := False;

  {$IFDEF EnabledGtkThreading}
    {$IFNDEF Win32}
      GtkThread := g_thread_self();
      if GtkThread <> nil then
      begin
        if GtkThread^.data = nil then
          GtkThread^.data := @Self
        else
          FIsLibraryInstance := True;
      end;
      if GetThreadManager(TM{%H-}) and Assigned(TM.InitManager) and g_thread_supported then
      begin
        g_thread_init(nil);
        {$IFDEF USE_GTK_MAIN_OLD_ITERATION}
        gdk_threads_init;
        gdk_threads_enter;
        {$ENDIF}
        fMultiThreadingEnabled := True;
      end;
    {$ELSE}
      g_thread_init(nil);
    {$ENDIF}
  {$ENDIF}

  // DCs, GDIObjects
  FDeviceContexts := TDynHashArray.Create(-1);
  FDeviceContexts.Options:=FDeviceContexts.Options+[dhaoCacheContains];
  FGDIObjects := TDynHashArray.Create(-1);
  FGDIObjects.Options:=FGDIObjects.Options+[dhaoCacheContains];
  Gtk2Def.ReleaseGDIObject:=@ReleaseGDIObject;
  Gtk2Def.ReferenceGDIObject:=@ReferenceGDIObject;

  FDefaultFontDesc:= nil;
  // messages
  FMessageQueue := TGtkMessageQueue.Create;
  WaitingForMessages := false;
  FWidgetsWithResizeRequest := TDynHashArray.Create(-1);
  FWidgetsWithResizeRequest.Options:=
    FWidgetsWithResizeRequest.Options+[dhaoCacheContains];
  FWidgetsResized := TDynHashArray.Create(-1);
  FWidgetsResized.Options:=FWidgetsResized.Options+[dhaoCacheContains];
  FFixWidgetsResized := TDynHashArray.Create(-1);

  FTimerData  := TFPList.Create;
  {$IFDEF Use_KeyStateList}
  FKeyStateList_ := TFPList.Create;
  {$ENDIF}

  DestroyConnectedWidgetCB:=@DestroyConnectedWidget;

  FRCFilename := ChangeFileExt(ParamStrUTF8(0),'.gtkrc');
  FRCFileParsed := false;

  // initialize app level gtk engine
  gtk_set_locale ();

  // call init and pass cmd line args
  PassCmdLineOptions;

  // set glib log handler
  FLogHandlerID := g_log_set_handler(nil, -1, @GLogFunc, Self);

  // read gtk rc file
  ParseRCFile;

  // Initialize Stringlist for holding styles
  Styles := TStringlist.Create;

  {$IFDEF Use_KeyStateList}
  gtk_key_snooper_install(@GTKKeySnooper, FKeyStateList_);
  {$ELSE}
  gtk_key_snooper_install(@GTKKeySnooper, nil);
  {$ENDIF}

  // Init tooltips
  FGTKToolTips := gtk_tooltips_new;
  //gtk_object_ref(PGTKObject(FGTKToolTips));
  gtk_toolTips_Enable(FGTKToolTips);

  // Init stock objects;
  InitStockItems;
  InitSystemColors;
  InitSystemBrushes;

  // clipboard
  ClipboardTypeAtoms[ctPrimarySelection]:=GDK_SELECTION_PRIMARY;
  ClipboardTypeAtoms[ctSecondarySelection]:=GDK_SELECTION_SECONDARY;
  ClipboardTypeAtoms[ctClipboard]:=gdk_atom_intern('CLIPBOARD',GdkFalse);

{$ifdef Unix}
  InitSynchronizeSupport;
{$ifdef UseAsyncProcess}
  DebugLn(['TGtk2WidgetSet.Create Installing signal handler for TAsyncProcess']);
  InstallSignalHandler;
{$endif}
{$endif}

  GTK2WidgetSet := Self;
end;

{------------------------------------------------------------------------------
  Method: TGtk2WidgetSet.PassCmdLineOptions
  Params:  None
  Returns: Nothing

  Passes command line options to the gtk engine
 ------------------------------------------------------------------------------}
procedure TGtk2WidgetSet.PassCmdLineOptions;

  function SearchOption(const Option: string; Remove: boolean): boolean;
  var
    i: Integer;
    ArgCount: LongInt;
  begin
    Result:=false;
    if Option='' then exit;
    i:=0;
    ArgCount:=argc;
    while i<ArgCount do begin
      if AnsiStrComp(PChar(Option),argv[i])=0 then begin
        // option exists
        Result:=true;
        if Remove then begin
          // remove option from parameters, so that no other parameter parsed
          // can see it.
          dec(ArgCount);
          while i<ArgCount do begin
            argv[i]:=argv[i+1];
            inc(i);
          end;
          argv[i]:=nil;
        end;
        exit;
      end;
      inc(i);
    end;
  end;

begin
  gtk_init(@argc,@argv);
  UseTransientForModalWindows := not SearchOption('--lcl-no-transient',true);
end;

{------------------------------------------------------------------------------
  procedure TGtk2WidgetSet.FreeAllStyles;
 ------------------------------------------------------------------------------}
procedure TGtk2WidgetSet.FreeAllStyles;
begin
  If Assigned(Styles) then begin
    ReleaseAllStyles;
    FreeAndNil(Styles);
  end;
end;

{$ifdef TraceGdiCalls}
procedure DumpBackTrace(BackTrace: TCallBacksArray);
var
  i: Integer;
begin
  for i:=0 to MaxCallBacks do
    Debugln(GetLineInfo(BackTrace[i], false));
end;

procedure FillStackAddrs(bp: pointer; BackTraces: PCallBacksArray);
var
  prevbp: pointer;
  caller_frame,
  caller_addr : Pointer;
  i: Integer;
begin
  Prevbp := bp-1;
  i:=0;
  while (bp>prevbp)do begin
    caller_addr := get_caller_addr(bp);
    caller_frame := get_caller_frame(bp);
    BackTraces^[i] := Caller_Addr;
    inc(i);
   if (caller_addr=nil) or
      (caller_frame=nil) or
      (i>MaxCallBacks) then
     break;
   prevbp:=bp;
   bp:=caller_frame;
  end;
end;
{$endif}
{------------------------------------------------------------------------------
  Method: TGtk2WidgetSet._Destroy
  Params:  None
  Returns: Nothing

  Gtk2 original Destructor for the class.
 ------------------------------------------------------------------------------}
procedure TGtk2WidgetSet.Gtk2Destroy;
const
  ProcName = '[TGtk2WidgetSet.Destroy]';
var
  n: Integer;
  pTimerInfo  : PGtkITimerinfo;
  GDITypeCount: array[TGDIType] of Integer;
  GDIType: TGDIType;
  HashItem: PDynHashArrayItem;
  QueueItem  : TGtkMessageQueueItem;
  NextQueueItem : TGtkMessageQueueItem;
begin
  if FDockImage <> nil then
    gtk_widget_destroy(FDockImage);

  ReAllocMem(FExtUTF8OutCache,0);
  FExtUTF8OutCacheSize:=0;

  FreeAllStyles;
  FreeStockItems;
  FreeSystemBrushes;

  if FGTKToolTips<>nil then begin
    gtk_object_sink(PGTKObject(FGTKToolTips));
    FGTKToolTips := nil;
  end;

  // tidy up the paint messages
  FMessageQueue.Lock;
  try
    QueueItem:=FMessageQueue.FirstMessageItem;
    while (QueueItem<>nil) do begin
      NextQueueItem := TGtkMessageQueueItem(QueueItem.Next);
      if QueueItem.IsPaintMessage then
        fMessageQueue.RemoveMessage(QueueItem,FPMF_All,true);
      QueueItem := NextQueueItem;
    end;

    // warn about unremoved paint messages
    if fMessageQueue.HasPaintMessages then begin
      DebugLn(ProcName, Format(rsWarningUnremovedPaintMessages,
        [IntToStr(fMessageQueue.NumberOfPaintMessages)]));
    end;
  finally
    FMessageQueue.UnLock;
  end;

  // warn about unreleased DC
  if (FDeviceContexts.Count > 0)
  then begin
    DebugLn(ProcName, Format(rsWarningUnreleasedDCsDump,
      [FDeviceContexts.Count]));

    n:=0;
    DbgOut(ProcName,'  DCs:  ');
    HashItem:=FDeviceContexts.FirstHashItem;
    while (n<7) and (HashItem<>nil) do
    begin
      DbgOut(' ',DbgS(HashItem^.Item));
      HashItem:=HashItem^.Next;
      inc(n);
    end;
    DebugLn();
  end;

  // warn about unreleased gdi objects
  if (FGDIObjects.Count > 0)
  then begin
    DebugLn(ProcName,Format(rsWarningUnreleasedGDIObjectsDump,
       [FGDIObjects.Count]));
    for GDIType := Low(TGDIType) to High(TGDIType) do
      GDITypeCount[GDIType] := 0;

    n:=0;
    {$ifndef TraceGdiCalls}
    DbgOut(ProcName,'   GDIOs:');
    {$endif}
    HashItem := FGDIObjects.FirstHashItem;
    while (HashItem <> nil) do
    begin
      {$ifndef TraceGdiCalls}
      if n < 7
      then
        DbgOut(' ',DbgS(HashItem^.Item));
      {$endif}

      Inc(GDITypeCount[PGdiObject(HashItem^.Item)^.GDIType]);
      HashItem := HashItem^.Next;
      Inc(n);
    end;
    {$ifndef TraceGdiCalls}
    DebugLn();
    {$endif}

    for GDIType := Low(GDIType) to High(GDIType) do
      if GDITypeCount[GDIType] > 0 then
        DebugLn(ProcName,Format('   %s: %d', [dbgs(GDIType), GDITypeCount[GDIType]]));

    // tidy up messages
    if FMessageQueue.Count > 0   then begin
      DebugLn(ProcName, Format(rsWarningUnreleasedMessagesInQueue,[FMessageQueue.Count]));
      while FMessageQueue.First<>nil do
        fMessageQueue.RemoveMessage(fMessageQueue.FirstMessageItem,FPMF_All,true);
    end;
  end;

  // warn about unreleased timers
  n := FTimerData.Count;
  if (n > 0) then
  begin
    DebugLn(ProcName,Format(rsWarningUnreleasedTimerInfos,[n]));
    while (n > 0) do
    begin
      dec (n);
      pTimerInfo := PGtkITimerinfo (FTimerData.Items[n]);
      Dispose (pTimerInfo);
      FTimerData.Delete (n);
    end;
  end;

  {$ifdef TraceGdiCalls}
  if FDeviceContexts.Count>0 then begin
    //DebugLn('BackTrace for unreleased device contexts follows:');
    n:=0;
    HashItem:=FDeviceContexts.FirstHashItem;
    while (HashItem<>nil) and (n<MaxTraces) do
    begin
      DebugLn('DC: ', Dbgs(HashItem^.Item));
      DumpBackTrace(TGtkDeviceContext(HashItem^.Item).StackAddrs);
      DebugLn();
      HashItem:=HashItem^.Next;
    end;
    if (n>=MaxTraces) then begin
      DebugLn('... Truncated dump DeviceContext leakage dump.');
      DebugLn();
    end;
  end;

  if (FGDIObjects.Count > 0)
  then begin
    //DebugLn('BackTrace for unreleased gdi objects follows:');
    for GDIType := Low(TGDIType) to High(TGDIType) do begin
      if GDITypeCount[GDIType]<>0 then begin
        n:=0;
        HashItem := FGDIObjects.FirstHashItem;
        while (HashItem <> nil) and (n<MaxTraces) do begin
          DebugLn(dbgs(gdiType),': ', dbgs(HashItem^.Item));
          DumpBackTrace(PgdiObject(HashItem^.Item)^.StackAddrs);
          DebugLn();
          HashItem := HashItem^.Next;
          inc(n);
        end;
        if (n>=MaxTraces) then begin
          DebugLn('... Truncated ',dbgs(GDIType),' leakage dump.');
          DebugLn();
        end;
      end;
    end;
  end;
  {$endif}

  FreeAndNil(FWidgetsWithResizeRequest);
  FreeAndNil(FWidgetsResized);
  FreeAndNil(FFixWidgetsResized);
  FreeAndNil(FMessageQueue);
  FreeAndNil(FDeviceContexts);
  FreeAndNil(FGDIObjects);
  {$IFDEF Use_KeyStateList}
  FreeAndNil(FKeyStateList_);
  {$ENDIF}
  FreeAndNil(FTimerData);

  GtkDefDone;
  FreeAndNil(FDCManager);

  // finally remove our loghandler
  g_log_remove_handler(nil, FLogHandlerID);

  GTK2WidgetSet := nil;
  WakeMainThread := nil;

  {$IFDEF EnabledGtkThreading}
  if MultiThreadingEnabled then
  begin
    {$IFNDEF Win32}
      {$IFDEF USE_GTK_MAIN_OLD_ITERATION}
      gdk_threads_leave;
      {$ENDIF}
    {$ENDIF}
    fMultiThreadingEnabled := False;
  end;
  {$ENDIF}

end;

{$ifdef Unix}

{$IFDEF HASX}
function TGtk2WidgetSet.CreateDummyWidgetFrame(const ALeft, ATop, AWidth,
  AHeight: integer): boolean;
var
  ADummy: TDummyWidget;
begin
  Result := False;
  ADummy := TDummyWidget.Create;
  ADummy.ShowDummyWidget(ALeft, ATop, AWidth, AHeight);
  FWSFrameRect := ADummy.GetWidgetFrame;
  ADummy.Free;
  Result := not IsRectEmpty(FWSFrameRect);
end;

function TGtk2WidgetSet.GetDummyWidgetFrame: TRect;
begin
  Result := FWSFrameRect;
end;
{$ENDIF}

procedure TGtk2WidgetSet.PrepareSynchronize(AObject: TObject);
{ This method is the WakeMainThread of the unit classes.
  It is called in TThread.Synchronize to wake up the main thread = LCL GUI thread.
  see: TGtk2WidgetSet.InitSynchronizeSupport
}
var
  thrash: char;
begin
  // ToDo: TGtk2WidgetSet.PrepareSynchronize what is AObject?

  // wake up GUI thread by sending a byte through the threadsync pipe
  thrash:='l';
  fpwrite(threadsync_pipeout, thrash, 1);
end;

procedure TGtk2WidgetSet.ProcessChildSignal;
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
    TGtk2WidgetSet(data).ProcessChildSignal;
  end;
  // execute the to-be synchronized method
  if IsMultiThread then
    CheckSynchronize;
end;

procedure TGtk2WidgetSet.InitSynchronizeSupport;
{ When a thread calls its Synchronize, it calls
  WakeMainThread (defined in the unit classes).
  Set
}
begin
  { TThread.Synchronize ``glue'' }
  WakeMainThread := @PrepareSynchronize;
  assignpipe(threadsync_pipein, threadsync_pipeout);
  threadsync_giochannel := g_io_channel_unix_new(threadsync_pipein);
  g_io_add_watch(threadsync_giochannel, G_IO_IN, @threadsync_iocallback, Self);
end;

{$else}

{$message warn TThread.Synchronize will not work on Gtk/Win32 }

procedure InitSynchronizeSupport;
begin
end;

{$endif}

{------------------------------------------------------------------------------
  procedure TGtk2WidgetSet.UpdateTransientWindows;
 ------------------------------------------------------------------------------}
procedure TGtk2WidgetSet.UpdateTransientWindows;

type
  PTransientWindow = ^TTransientWindow;
  TTransientWindow = record
    GtkWindow: PGtkWindow;
    Component: TComponent;
    IsModal: boolean;
    SortIndex: integer;
    TransientParent: PGtkWindow;
  end;

var
  AllWindows: TFPList;
  List,orgList: PGList;
  Window: PGTKWindow;
  ATransientWindow: PTransientWindow;
  LCLObject: TObject;
  LCLComponent: TComponent;
  i: Integer;
  FirstModal: Integer;
  j: Integer;
  ATransientWindow1: PTransientWindow;
  ATransientWindow2: PTransientWindow;
  ParentTransientWindow: PTransientWindow;
  OldTransientParent: PGtkWindow;
begin
  if (not UseTransientForModalWindows) then exit;
  if UpdatingTransientWindows then begin
    DebugLn('TGtk2WidgetSet.UpdateTransientWindows already updating');
    exit;
  end;
  UpdatingTransientWindows:=true;
  try
    {$IFDEF VerboseTransient}
    DebugLn('TGtk2WidgetSet.UpdateTransientWindows');
    {$ENDIF}
    AllWindows:=nil;

    // find all currently visible gtkwindows
    List := gdk_window_get_toplevels;
    orgList := List;
    while List <> nil do
    begin
      if (List^.Data <> nil)
      then begin
        gdk_window_get_user_data(PGDKWindow(List^.Data), Pgpointer(@Window));
        if GtkWidgetIsA(PGtkWidget(Window), GTK_TYPE_WINDOW)
        and gtk_widget_visible(PGtkWidget(Window))
        then begin
          // visible window found -> add to list
          New(ATransientWindow);
          FillChar(ATransientWindow^,SizeOf(TTransientWindow),0);
          ATransientWindow^.GtkWindow:=Window;
          LCLObject:=GetLCLObject(Window);
          if LCLObject is TComponent then begin
            LCLComponent:=TComponent(LCLObject);
            ATransientWindow^.Component:=LCLComponent;
          end;
          if (ModalWindows<>nil) then
            ATransientWindow^.SortIndex:=ModalWindows.IndexOf(Window)
          else
            ATransientWindow^.SortIndex:=-1;
          ATransientWindow^.IsModal:=(ATransientWindow^.SortIndex>=0)
                                   and (GTK_WIDGET_VISIBLE(PGtkWidget(Window)));
          if not ATransientWindow^.IsModal then begin
            if (LCLObject is TCustomForm)
            and (TCustomForm(LCLObject).Parent=nil) then
              ATransientWindow^.SortIndex:=
                Screen.CustomFormZIndex(TCustomForm(LCLObject));
          end;

          if ATransientWindow^.SortIndex<0 then begin
            // this window has no form. Move it to the back.
            ATransientWindow^.SortIndex:=Screen.CustomFormCount;
          end;

          //DebugLn(['TGtk2WidgetSet.UpdateTransientWindows LCLObject=',DbgSName(LCLObject),' ATransientWindow^.SortIndex=',ATransientWindow^.SortIndex]);
          if AllWindows=nil then AllWindows:=TFPList.Create;
          AllWindows.Add(ATransientWindow);
        end;
      end;
      list := g_list_next(list);
    end;
    if Assigned(orgList) then
    begin
      g_list_free(orgList);
      list:=nil; orgList:=nil;
    end;

    if AllWindows=nil then exit;

    //for i:=0 to SCreen.CustomFormZOrderCount-1 do
    //  DebugLn(['TGtk2WidgetSet.UpdateTransientWindows i=',i,'/',SCreen.CustomFormZOrderCount,' ',DbgSName(SCreen.CustomFormsZOrdered[i])]);

    // sort
    // move all modal windows to the end of the window list
    i:=AllWindows.Count-1;
    FirstModal:=AllWindows.Count;
    while i>=0 do begin
      ATransientWindow:=PTransientWindow(AllWindows[i]);
      if ATransientWindow^.IsModal
      and (i<FirstModal) then begin
        dec(FirstModal);
        if i<FirstModal then
          AllWindows.Exchange(i,FirstModal);
      end;
      dec(i);
    end;

    if FirstModal=AllWindows.Count then begin
      // there is no modal window
      // -> break all transient window relation ships
      for i:=AllWindows.Count-1 downto 0 do begin
        ATransientWindow:=PTransientWindow(AllWindows[i]);
        {$IFDEF VerboseTransient}
        debugln(['TGtk2WidgetSet.UpdateTransientWindows  Untransient ',i,
          ' ',dbgsname(ATransientWindow^.Component)]);
        {$ENDIF}
        gtk_window_set_transient_for(ATransientWindow^.GtkWindow,nil);
      end;
    end else begin
      // there are modal windows
      // -> sort windows in z order and setup transient relationships

      //DebugLn(['TGtk2WidgetSet.UpdateTransientWindows ModalWindows=',AllWindows.Count-FirstModal,' NonModalWindows=',FirstModal]);

      // sort modal windows (bubble sort)
      for i:=FirstModal to AllWindows.Count-2 do begin
        for j:=i+1 to AllWindows.Count-1 do begin
          ATransientWindow1:=PTransientWindow(AllWindows[i]);
          ATransientWindow2:=PTransientWindow(AllWindows[j]);
          if ATransientWindow1^.SortIndex>ATransientWindow2^.SortIndex then
            AllWindows.Exchange(i,j);
        end;
      end;

      // sort non modal windows for z order
      // ToDo: How do we get the z order?
      // For now, just use the inverse order in the Screen object
      // that means: the lower in the Screen object, the later in the transient list
      for i:=0 to FirstModal-2 do begin
        for j:=i+1 to FirstModal-1 do begin
          ATransientWindow1:=PTransientWindow(AllWindows[i]);
          ATransientWindow2:=PTransientWindow(AllWindows[j]);
          if ATransientWindow1^.SortIndex<ATransientWindow2^.SortIndex then
            AllWindows.Exchange(i,j);
        end;
      end;

      // set all transient relationships for LCL windows
      ParentTransientWindow:=nil;
      for i:=0 to AllWindows.Count-1 do begin
        ATransientWindow:=PTransientWindow(AllWindows[i]);
        if (ATransientWindow^.Component<>nil)
        and GTK_WIDGET_VISIBLE(PgtkWidget(ATransientWindow^.GtkWindow)) then
        begin
          if ParentTransientWindow<>nil then begin
            {$IFDEF VerboseTransient}
            DebugLn(['Define TRANSIENT ',
            ' Parent=',
              dbgsname(ParentTransientWindow^.Component),
              ' Index=',ParentTransientWindow^.SortIndex,
              ' Wnd=',DbgS(ParentTransientWindow^.GtkWindow),
            ' Child=',dbgsname(ATransientWindow^.Component),
              ' Index=',ATransientWindow^.SortIndex,
              ' Wnd=',DbgS(ATransientWindow^.GtkWindow),
              '']);
            {$ENDIF}
            ATransientWindow^.TransientParent:=ParentTransientWindow^.GtkWindow;
          end;
          ParentTransientWindow:=ATransientWindow;
        end;
      end;

      // Each transient relationship can reorder the visible forms
      // To reduce flickering and creation of temporary circles
      // do the setup in two separate steps:

      // break unneeded transient relationships
      for i:=AllWindows.Count-1 downto 0 do begin
        ATransientWindow:=PTransientWindow(AllWindows[i]);
        OldTransientParent:=ATransientWindow^.GtkWindow^.transient_parent;
        if (OldTransientParent<>ATransientWindow^.TransientParent) then begin
          {$IFDEF VerboseTransient}
          DebugLn(['Break old TRANSIENT i=',i,'/',AllWindows.Count,
          ' OldTransientParent=',DbgS(OldTransientParent),
          ' Child=',dbgsname(ATransientWindow^.Component),
            ' Index=',ATransientWindow^.SortIndex,
            ' Wnd=',DbgS(ATransientWindow^.GtkWindow),
            '']);
          {$ENDIF}
          gtk_window_set_transient_for(ATransientWindow^.GtkWindow,nil);
        end;
      end;

      // setup transient relationships
      for i:=0 to AllWindows.Count-1 do begin
        ATransientWindow:=PTransientWindow(AllWindows[i]);
        if ATransientWindow^.TransientParent=nil then continue;
        {$IFDEF VerboseTransient}
        DebugLn(['Set TRANSIENT i=',i,'/',AllWindows.Count,
        ' Child=',dbgsname(ATransientWindow^.Component),
          ' Index=',ATransientWindow^.SortIndex,
          ' Wnd=',DbgS(ATransientWindow^.GtkWindow),
          ' Parent=',DbgS(ATransientWindow^.TransientParent),
          '']);
        {$ENDIF}
        gtk_window_set_transient_for(ATransientWindow^.GtkWindow,
                                     ATransientWindow^.TransientParent);
      end;
    end;

    // clean up
    for i:=0 to AllWindows.Count-1 do begin
      ATransientWindow:=PTransientWindow(AllWindows[i]);
      Dispose(ATransientWindow);
    end;
    AllWindows.Free;
  finally
    UpdatingTransientWindows:=false;
  end;
end;

{------------------------------------------------------------------------------
  procedure TGtk2WidgetSet.UntransientWindow(GtkWindow: PGtkWindow);
 ------------------------------------------------------------------------------}
procedure TGtk2WidgetSet.UntransientWindow(GtkWindow: PGtkWindow);
{$IFDEF VerboseTransient}
var
  LCLObject: TObject;
{$ENDIF}
begin
  {$IFDEF VerboseTransient}
  DbgOut('TGtk2WidgetSet.UntransientWindow ',DbgS(GtkWindow));
  LCLObject:=GetLCLObject(PGtkWidget(GtkWindow));
  if LCLObject<>nil then
    DbgOut(' LCLObject=',LCLObject.ClassName)
  else
    DbgOut(' LCLObject=nil');
  DebugLn('');
  {$ENDIF}
  // hide window, so that UpdateTransientWindows untransients it
  if GTK_WIDGET_VISIBLE(PgtkWidget(GtkWindow)) then
    gtk_widget_hide(PgtkWidget(GtkWindow));
  UpdateTransientWindows;
  // remove it from the modal window list
  if ModalWindows<>nil then begin
    ModalWindows.Remove(GtkWindow);
    if ModalWindows.Count=0 then FreeAndNil(ModalWindows);
  end;
end;

{------------------------------------------------------------------------------
  Method: TGtk2WidgetSet.SendCachedLCLMessages
  Params:  None
  Returns: Nothing

  Some LCL messages are not sent directly to the gtk. Send them now.
 ------------------------------------------------------------------------------}
procedure TGtk2WidgetSet.SendCachedLCLMessages;

  procedure SendCachedLCLResizeRequests;
  var
    Widget: PGtkWidget;
    LCLControl: TWinControl;
    IsTopLevelWidget: boolean;
    TopologicalList: TFPList; // list of PGtkWidget;
    i: integer;

    procedure RaiseWidgetWithoutControl;
    begin
      RaiseGDBException('ERROR: TGtk2WidgetSet.SendCachedLCLMessages Widget '
        +DbgS(Widget)+' without LCL control');
    end;

  begin
    if FWidgetsWithResizeRequest.Count=0 then exit;
    {$IFDEF VerboseSizeMsg}
    DebugLn('GGG1 SendCachedLCLResizeRequests SizeMsgCount=',dbgs(FWidgetsWithResizeRequest.Count));
    {$ENDIF}

    TopologicalList:=CreateTopologicalSortedWidgets(FWidgetsWithResizeRequest);
    for i:=0 to TopologicalList.Count-1 do begin
      Widget:=TopologicalList[i];

      // resize widget
      LCLControl:=TWinControl(GetLCLObject(Widget));
      if (LCLControl=nil) or (not (LCLControl is TControl)) then begin
        RaiseWidgetWithoutControl;
      end;
      {$IFDEF VerboseSizeMsg}
      if CompareText(LCLControl.ClassName,'TScrollBar')=0 then
      DebugLn('SendCachedLCLMessages ',LCLControl.Name,':',LCLControl.ClassName,
        ' ',dbgs(LCLControl.Left)+','+dbgs(LCLControl.Top)+','+dbgs(LCLControl.Width)+'x'+dbgs(LCLControl.Height));
      {$ENDIF}

      IsTopLevelWidget:= (LCLControl is TCustomForm)
                         and (LCLControl.Parent = nil);

      if not IsTopLevelWidget then begin
        SetWidgetSizeAndPosition(LCLControl);
      end
      else begin
        // resize form
        {$IFDEF VerboseFormPositioning}
        DebugLn('VFP SendCachedLCLMessages1 ', dbgs(GetControlWindow(Widget)<>nil));
        if (LCLControl is TCustomForm) then
          DebugLn('VFP SendCachedLCLMessages2 ',LCLControl.ClassName,' ',
            dbgs(LCLControl.Left),',',dbgs(LCLControl.Top),',',dbgs(LCLControl.Width),',',dbgs(LCLControl.Height));
        {$ENDIF}
        SetWindowSizeAndPosition(PgtkWindow(Widget),TWinControl(LCLControl));
      end;

    end;
    TopologicalList.Free;
    FWidgetsWithResizeRequest.Clear;
  end;

begin
  SendCachedLCLResizeRequests;
end;

{------------------------------------------------------------------------------
  Method: TGtk2WidgetSet.LCLtoGtkMessagePending
  Params:  None
  Returns: boolean

  Returns true if any messages from the lcl to the gtk is in cache and needs
  delivery.
 ------------------------------------------------------------------------------}
function TGtk2WidgetSet.LCLtoGtkMessagePending: boolean;
begin
  Result:=(FWidgetsWithResizeRequest.Count>0);
end;

{------------------------------------------------------------------------------
  Method: TGtk2WidgetSet.SendCachedGtkMessages
  Params:  None
  Returns: Nothing

  Some Gtk messages are not sent directly to the LCL. Send them now.
 ------------------------------------------------------------------------------}
procedure TGtk2WidgetSet.SendCachedGtkMessages;
begin
  SendCachedGtkResizeNotifications;
end;

{
 Changes some colors of the widget style

 IMPORTANT:
 SystemColors like clBtnFace depend on the theme and widget class, so they
 must be read from the theme. But many gtk themes do not provide all colors
 and instead only provide bitmaps.
 Since we don't have good fallbacks yet, and many controls use SystemColors
 for Delphi compatibility: ignore SystemColors from the following list:

 Gtk 2:

 clNone (should be ignored anyway),
 clBtnFace,

 Gtk 1:

 clNone,
 Any system color
}
procedure TGtk2WidgetSet.SetWidgetColor(const AWidget: PGtkWidget;
  const FGColor, BGColor: TColor; const Mask: tGtkStateEnum);
var
  i: integer;
  xfg, xbg: TGdkColor;
  ChangeFGColor: Boolean;
  ChangeBGColor: Boolean;
  NewColor: PGdkColor;
begin
  ChangeFGColor := (FGColor <> clNone);
  ChangeBGColor := (BGColor <> clNone);

  if (not ChangeFGColor) and (not ChangeBGColor) then Exit;

  // the GTKAPIWidget is self drawn, so no use to change the widget style.
  if GtkWidgetIsA(AWidget, GTKAPIWidget_GetType) then Exit;

  {$IFDEF DisableWidgetColor}
  exit;
  {$ENDIF}

  //DebugLn('TGtk2WidgetSet.SetWidgetColor ',GetWidgetDebugReport(AWidget),' ',hexstr(FGColor,8),'  ',hexstr(BGColor,8));
  //RaiseGDBException('');
  if ChangeFGColor then
  begin
    if (FGColor = clDefault) then
      NewColor := nil
    else
    begin
      xfg := AllocGDKColor(ColorToRGB(FGColor));
      NewColor := @xfg;
    end;
    for i := GTK_STATE_NORMAL to GTK_STATE_INSENSITIVE do
    begin
      if i in mask then
      begin
        if GTK_STYLE_TEXT in mask then
          gtk_widget_modify_text(AWidget, i, NewColor)
        else
          gtk_widget_modify_fg(AWidget, i, NewColor);
      end;
    end;
  end;

  if ChangeBGColor then
  begin
    // setting bg color to nil will cancel previous calls to gtk_widget_modify_bg()
    // cannot use nil on a GtkLayout (issue #16183)
    if not GTK_IS_LAYOUT(AWidget) and
      ((BGColor = clDefault) or (BGColor = clBtnFace)) then
      NewColor := nil
    else
    begin
      xbg := AllocGDKColor(ColorToRGB(BGColor));
      NewColor := @xbg;
    end;
    for i := GTK_STATE_NORMAL to GTK_STATE_INSENSITIVE do
    begin
      if i in mask then
      begin
        if GTK_STYLE_BASE in mask then
          gtk_widget_modify_base(AWidget, i, NewColor)
        else
          gtk_widget_modify_bg(AWidget, i, NewColor);
      end;
    end;
  end;
end;

{------------------------------------------------------------------------------
  Method: TGtk2WidgetSet.AppProcessMessages
  Params:  None
  Returns: Nothing

  Handle all pending messages of the GTK engine and of this interface
 ------------------------------------------------------------------------------}
procedure TGtk2WidgetSet.AppProcessMessages;

  function PendingGtkMessagesExists: boolean;
  begin
    {$IFDEF USE_GTK_MAIN_OLD_ITERATION}
    Result:=(gtk_events_pending<>0) or LCLtoGtkMessagePending;
    {$ELSE}
    Result := g_main_context_pending(g_main_context_default) or
      LCLtoGtkMessagePending;
    {$ENDIF}
  end;

var
  vlItem : TGtkMessageQueueItem;
  vlMsg  : PMSg;
  i: Integer;
begin
  vlMsg:=nil; //issue #27662
  repeat
    // send cached LCL messages to the gtk
    //DebugLn(['TGtk2WidgetSet.AppProcessMessages SendCachedLCLMessages']);
    SendCachedLCLMessages;

    // let gtk handle up to 100 messages and call our callbacks
    i:=100;

    if not FGtkTerminated then
    begin
      {$IFDEF USE_GTK_MAIN_OLD_ITERATION}
      while (gtk_events_pending<>0) and (i>0) do
      begin
        if FGtkTerminated then
          break;
        gtk_main_iteration_do(False);
        dec(i);
      end;
      {$ELSE}
      while g_main_context_pending(g_main_context_default) and (i>0) do
      begin
        if FGtkTerminated then
          break;
        if not g_main_context_iteration(g_main_context_default, False) then
          break;
        dec(i);
      end;
      {$ENDIF}
    end;

    //DebugLn(['TGtk2WidgetSet.AppProcessMessages SendCachedGtkMessages']);
    // send cached gtk messages to the lcl
    SendCachedGtkMessages;

    // then handle our own messages
    while not Application.Terminated do begin
      fMessageQueue.Lock;
      try
        // fetch first message
        vlItem := fMessageQueue.FirstMessageItem;
        if vlItem = nil then break;

        // remove message from queue
        if vlItem.IsPaintMessage then begin
          //DebugLn(['TGtk2WidgetSet.AppProcessMessages Paint: ',DbgSName(GetLCLObject(Pointer(vlItem.Msg^.hwnd)))]);
          // paint messages are the most expensive messages in the LCL,
          // therefore they are sent after all other
          if MovedPaintMessageCount<10 then begin
            inc(MovedPaintMessageCount);
            if fMessageQueue.HasNonPaintMessages then begin
              // there are non paint messages -> move paint message to the end
              fMessageQueue.MoveToLast(FMessageQueue.First);
              continue;
            end else begin
              // there are only paint messages left in the queue
              // -> check other queues
              if PendingGtkMessagesExists then break;
            end;
          end else begin
            // handle this paint message now
            MovedPaintMessageCount:=0;
          end;
        end;

        //DebugLn(['TGtk2WidgetSet.AppProcessMessages SendMessage: ',DbgSName(GetLCLObject(Pointer(vlItem.Msg^.hwnd)))]);
        vlMsg:=fMessageQueue.PopFirstMessage;
      finally
        fMessageQueue.UnLock;
      end;

      //debugln(['TGtk2WidgetSet.AppProcessMessages ',vlMsg^.Message,' ',LM_CHAR,' ',dbgsname(GetLCLObject(Pointer(vlMsg^.hwnd)))]);
      // Send message
      if vlMsg <> nil then
      begin
        try
          with vlMsg^ do SendMessage(hWND, Message, WParam, LParam);
        finally
          Dispose(vlMsg);
        end;
      end;
    end;

    // proceed until all messages are handled
  until (not PendingGtkMessagesExists) or Application.Terminated;
  if (vlMsg = nil) and IsMultiThread then //no message was handled -> CheckSynchronize. issue #27662
    CheckSynchronize;
end;

{------------------------------------------------------------------------------
  Method: TGtk2WidgetSet.AppWaitMessage
  Params:  None
  Returns: Nothing

  Passes execution control to the GTK engine till something happens
 ------------------------------------------------------------------------------}
procedure TGtk2WidgetSet.AppWaitMessage;
begin
  WaitingForMessages:=true;
  if not FGtkTerminated then
  begin
    {$IFDEF USE_GTK_MAIN_OLD_ITERATION}
    gtk_main_iteration_do(True);
    {$ELSE}
    g_main_context_iteration(g_main_context_default, True);
    {$ENDIF}
  end;
  WaitingForMessages:=false;
end;

procedure TGtk2WidgetSet.FreeStockItems;

  procedure DeleteAndNilObject(var h: HGDIOBJ);
  begin
    if h <> 0 then
    begin
      {%H-}PGdiObject(h)^.Shared := False;
      {%H-}PGdiObject(h)^.RefCount := 1;
    end;
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

procedure TGtk2WidgetSet.InitSystemColors;
begin
  // we need to request style and inside UpdateSysColorMap will be indirectly called
  GetStyle(lgsButton);
  GetStyle(lgsWindow);
  GetStyle(lgsMenuBar);
  GetStyle(lgsMenuitem);
  GetStyle(lgsVerticalScrollbar);
  GetStyle(lgsTooltip);
end;

procedure TGtk2WidgetSet.InitSystemBrushes;
var
  i: integer;
  LogBrush: TLogBrush;
begin
  FillChar(LogBrush{%H-}, SizeOf(TLogBrush), 0);
  for i := Low(FSysColorBrushes) to High(FSysColorBrushes) do
  begin
    LogBrush.lbColor := GetSysColor(i);
    FSysColorBrushes[i] := CreateBrushIndirect(LogBrush);
    {%H-}PGDIObject(FSysColorBrushes[i])^.Shared := True;
  end;
end;

procedure TGtk2WidgetSet.FreeSystemBrushes;

  procedure DeleteAndNilObject(var h: HGDIOBJ);
  begin
    if h <> 0 then
    begin
      {%H-}PGdiObject(h)^.Shared := False;
      {%H-}PGdiObject(h)^.RefCount := 1;
    end;
    DeleteObject(h);
    h := 0;
  end;

var
  i: integer;
begin
  for i := Low(FSysColorBrushes) to High(FSysColorBrushes) do
    DeleteAndNilObject(FSysColorBrushes[i]);
end;

{------------------------------------------------------------------------------
  Method: TGtk2WidgetSet.AppTerminate
  Params:  None
  Returns: Nothing

  *Note: Tells GTK Engine to halt and destroy
 ------------------------------------------------------------------------------}
procedure TGtk2WidgetSet.AppTerminate;
begin
  if FIsLibraryInstance then
    FGtkTerminated := True;
    // writeln('TGtk2WidgetSet.AppTerminate called from library ...');
    // g_main_context_wakeup(g_main_context_default);
  // MG: using gtk_main_quit is not a clean way to close
  //gtk_main_quit;
end;

function TGtk2WidgetSet.GetAppActive: Boolean;
begin
  Result := FAppActive;
end;

function TGtk2WidgetSet.GetTitleBarHeight: Integer;
var
  I: Integer;
  AForm: TCustomForm;
  AWindow: PGdkWindow;
  ARect: TGdkRectangle;
  AW, AH: GInt;
begin
  Result := 30;
  if FCachedTitleBarHeight > 0 then
    Result := FCachedTitleBarHeight
  else
  if Assigned(Application) and not Application.Terminated and
    Assigned(Application.MainForm) then
  begin
    for i := 0 to Screen.CustomFormZOrderCount - 1 do
    begin
      AForm := Screen.CustomFormsZOrdered[i];
      if (AForm.HandleAllocated) and (AForm.Visible) and (AForm.Parent = nil) and
        (AForm.BorderStyle <> bsNone) then
      begin
        AWindow := {%H-}PGtkWidget(AForm.Handle)^.window;
        if GDK_IS_WINDOW(AWindow) then
        begin
          gdk_window_get_frame_extents(AWindow, @ARect);
          gdk_window_get_size(AWindow, @AW, @AH);
          FCachedTitleBarHeight := ARect.Height - AH - 1;
          FCachedBorderSize := (ARect.Width - AW) div 2;
          Result := ARect.Height - AH - 1;
          break;
        end;
      end;
    end;
  end;
end;

procedure TGtk2WidgetSet.SetAppActive(const AValue: Boolean);
begin
  if AValue <> FAppActive then
  begin
    FAppActive := AValue;
    if FAppActive then
    begin
      Application.IntfAppActivate;
      AppRestoreStayOnTopFlags(False);
    end else
    begin
      Application.IntfAppDeactivate;
      AppRemoveStayOnTopFlags(False);
    end;
  end;
end;

function gtkAppFocusTimer({%H-}Data: gPointer):gBoolean; cdecl;
// needed by app activate/deactivate
begin
  Result := CallBackDefaultReturn;
  if TGtk2WidgetSet(WidgetSet).LastFocusIn = nil then
    TGtk2WidgetSet(WidgetSet).AppActive := False;
  gtk_timeout_remove(TGtk2WidgetSet(WidgetSet).FocusTimer);
  TGtk2WidgetSet(WidgetSet).FocusTimer := 0;
end;

procedure TGtk2WidgetSet.StartFocusTimer;
begin
  FLastFocusIn := nil;
  if FocusTimer <> 0 then
    gtk_timeout_remove(TGtk2WidgetSet(WidgetSet).FocusTimer);
  FocusTimer := gtk_timeout_add(50, TGtkFunction(@gtkAppFocusTimer), nil);
end;

procedure TGtk2WidgetSet.InitStockItems;
var
  LogBrush: TLogBrush;
  logPen : TLogPen;
begin
  FillChar(LogBrush{%H-}, SizeOf(TLogBrush), 0);
  LogBrush.lbStyle := BS_NULL;
  FStockNullBrush := CreateBrushIndirect(LogBrush);
  {%H-}PGDIObject(FStockNullBrush)^.Shared := True;
  LogBrush.lbStyle := BS_SOLID;
  LogBrush.lbColor := $000000;
  FStockBlackBrush := CreateBrushIndirect(LogBrush);
  {%H-}PGDIObject(FStockBlackBrush)^.Shared := True;
  LogBrush.lbColor := $C0C0C0;
  FStockLtGrayBrush := CreateBrushIndirect(LogBrush);
  {%H-}PGDIObject(FStockLtGrayBrush)^.Shared := True;
  LogBrush.lbColor := $808080;
  FStockGrayBrush := CreateBrushIndirect(LogBrush);
  {%H-}PGDIObject(FStockGrayBrush)^.Shared := True;
  LogBrush.lbColor := $404040;
  FStockDkGrayBrush := CreateBrushIndirect(LogBrush);
  {%H-}PGDIObject(FStockDkGrayBrush)^.Shared := True;
  LogBrush.lbColor := $FFFFFF;
  FStockWhiteBrush := CreateBrushIndirect(LogBrush);
  {%H-}PGDIObject(FStockWhiteBrush)^.Shared := True;

  LogPen.lopnStyle := PS_NULL;
  LogPen.lopnWidth.X := 1;
  LogPen.lopnColor := $FFFFFF;
  FStockNullPen := CreatePenIndirect(LogPen);
  {%H-}PGDIObject(FStockNullPen)^.Shared := True;
  LogPen.lopnStyle := PS_SOLID;
  FStockWhitePen := CreatePenIndirect(LogPen);
  {%H-}PGDIObject(FStockWhitePen)^.Shared := True;
  LogPen.lopnColor := $000000;
  FStockBlackPen := CreatePenIndirect(LogPen);
  {%H-}PGDIObject(FStockBlackPen)^.Shared := True;

  FStockSystemFont := 0;//Styles aren't initialized yet
end;

{------------------------------------------------------------------------------
  procedure TGtk2WidgetSet.AppSetTitle(const ATitle: string);
-------------------------------------------------------------------------------}
procedure TGtk2WidgetSet.AppSetTitle(const ATitle: string);
begin
  // ToDo: TGtk2WidgetSet.AppSetTitle: has a gtk2 application such a thing?
end;

{------------------------------------------------------------------------------
  Function: CreateTimer
  Params: Interval:
          TimerFunc: Callback
  Returns: a GTK-timer id (use this ID to destroy timer)

  This function will create a GTK timer object and associate a callback to it.

  Design: A callback to the TTimer class is implemented.
 ------------------------------------------------------------------------------}
function TGtk2WidgetSet.CreateTimer(Interval: integer;
  TimerProc: TWSTimerProc) : THandle;
var
  TimerInfo: PGtkITimerinfo;
begin
  if ((Interval < 1) or (not Assigned(TimerProc)))
  then
    Result := 0
  else begin
    New(TimerInfo);
    FillByte(TimerInfo^,SizeOf(TGtkITimerinfo),0);
    TimerInfo^.TimerFunc := TimerProc;
    {$IFDEF VerboseTimer}
    DebugLn(['TGtk2WidgetSet.CreateTimer Interval=',dbgs(Interval)]);
    {$ENDIF}
    Result:= gtk_timeout_add(Interval, @gtkTimerCB, TimerInfo);
    if Result = 0 then
      Dispose(TimerInfo)
    else begin
      TimerInfo^.TimerFunc := TimerProc;
      TimerInfo^.TimerHandle:=Result;
      FTimerData.Add(TimerInfo);
    end;
  end;
end;

{------------------------------------------------------------------------------
  Function: DestroyTimer
  Params: TimerHandle
  Returns:

  WARNING: There seems to be a bug in gtk-1.2.x which breaks gtk_timeout_remove
           thus we can't dispose PGtkITimerinfo here (s.a. gtkTimerCB).
 ------------------------------------------------------------------------------}
function TGtk2WidgetSet.DestroyTimer(TimerHandle: THandle) : boolean;
var
  n : integer;
  TimerInfo : PGtkITimerinfo;
begin
  //DebugLn('Trace:removing timer!!!');
  n := FTimerData.Count;
  while (n > 0) do begin
    dec (n);
    TimerInfo := PGtkITimerinfo(FTimerData.Items[n]);
    if (TimerInfo^.TimerHandle=guint(TimerHandle)) then
    begin
      {$IFDEF VerboseTimer}
      DebugLn(['TGtk2WidgetSet.DestroyTimer TimerInfo=',DbgS(TimerInfo),' TimerHandle=',TimerInfo^.TimerHandle]);
      {$ENDIF}
      gtk_timeout_remove(TimerInfo^.TimerHandle);
      FTimerData.Delete(n);
      Dispose(TimerInfo);
    end;
  end;
  Result:=true;
end;

{------------------------------------------------------------------------------
  function TGtk2WidgetSet.InternalGetDIBits(DC: HDC; Bitmap: HBitmap;
    StartScan, NumScans: UINT;
    BitSize : Longint; Bits: Pointer;
    var BitInfo: BitmapInfo; Usage: UINT; DIB : Boolean): Integer;
 ------------------------------------------------------------------------------}
function TGtk2WidgetSet.InternalGetDIBits(DC: HDC; Bitmap: HBitmap;
  StartScan, NumScans: UINT; BitSize : Longint; Bits: Pointer;
  out BitInfo: BitmapInfo; Usage: UINT; DIB : Boolean): Integer;
const
  PadLine : array[0..12] of Byte = (0,0,0,0,0,0,0,0,0,0,1,0,0);
  TempBuffer : array[0..2] of Byte = (0,0,0);

var
  GdiObject: PGDIObject absolute Bitmap;

  Source: PGDKPixbuf;
  rowstride, PixelPos: Longint;
  Pixels: PByte;
  FDIB: TDIBSection;
  X, Y: Longint;
  PadSize, Pos, BytesPerPixel: Longint;
  Buf16Bit: word;

  procedure DataSourceInitialize(Bitmap : PGDIObject; Width : Longint);
  begin
    Source := nil;

    case Bitmap^.GDIBitmapType of
      gbBitmap:
        if Bitmap^.GDIBitmapObject <> nil
        then begin
          {$ifdef VerboseGdkPixbuf} debugln('DataSourceInitialize A1');{$endif}

          Source := CreatePixbufFromDrawable(Bitmap^.GDIBitmapObject, Bitmap^.Colormap, False, 0,StartScan,0,0,Width,StartScan + NumScans);
          rowstride := gdk_pixbuf_get_rowstride(Source);
          Pixels := PByte(gdk_pixbuf_get_pixels(Source));

          {$ifdef VerboseGdkPixbuf} debugln('DataSourceInitialize A2');{$endif}
        end;
      gbPixmap:
        if Bitmap^.GDIPixmapObject.Image <> nil
        then begin
          {$ifdef VerboseGdkPixbuf} debugln('DataSourceInitialize B1');{$endif}

          Source := CreatePixbufFromDrawable(Bitmap^.GDIPixmapObject.Image, Bitmap^.Colormap, False, 0, StartScan, 0, 0, Width, StartScan + NumScans);
          {$IFDEF VerboseGtkToDos}{$note TODO: Apply alpha based on mask when 32bit mode is added}{$ENDIF}

          rowstride := gdk_pixbuf_get_rowstride(Source);
          Pixels := PByte(gdk_pixbuf_get_pixels(Source));

          {$ifdef VerboseGdkPixbuf} debugln('DataSourceInitialize B2');{$endif}
        end;
      gbPixbuf:
        if Bitmap^.GDIPixbufObject <> nil
        then begin
          rowstride := gdk_pixbuf_get_rowstride(Bitmap^.GDIPixbufObject);
          Pixels := PByte(gdk_pixbuf_get_pixels(Bitmap^.GDIPixbufObject));
        end;
    end;
  end;

  function DataSourceGetGDIRGB(Bitmap : PGDIObject; X, Y : Longint) : TGDIRGB;
  begin
    if Bitmap <> nil then ; //Keep compiler happy..

    PixelPos := rowstride*Y + X*3;

    with Result do
    begin
      Red   := Pixels[PixelPos + 0];
      Green := Pixels[PixelPos + 1];
      Blue  := Pixels[PixelPos + 2];
    end;
  end;

  procedure DataSourceFinalize;
  begin
    if Source <> nil
    then gdk_pixbuf_unref(Source);
  end;

  procedure WriteData(Value : PByte; Size : Longint);
  begin
    System.Move(Value^, PByte(Bits)[Pos], Size);
    Inc(Pos, Size);
  end;

  procedure WriteData(Value : Word);
  begin
    PByte(Bits)[Pos] := Lo(Value);
    inc(Pos);
    PByte(Bits)[Pos] := Hi(Value);
    inc(Pos);
  end;

begin
  //DebugLn('trace:[TGtk2WidgetSet.InternalGetDIBits]');

  Result := 0;
  FillByte(BitInfo{%H-},SizeOf(BitInfo),0);

  if (DC=0) or (Usage=0) then ;
  if not IsValidGDIObject(Bitmap)
  then begin
    DebugLn('WARNING: [TGtk2WidgetSet.InternalGetDIBits] invalid Bitmap!');
    Exit;
  end;

  if GdiObject^.GDIType <> gdiBitmap
  then begin
    DebugLn('WARNING: [TGtk2WidgetSet.InternalGetDIBits] not a Bitmap!');
    Exit;
  end;


  FillChar(FDIB{%H-}, SizeOf(FDIB), 0);
  GetObject(Bitmap, SizeOf(FDIB), @FDIB);

  with GdiObject^, BitInfo.bmiHeader do
  begin
    if not DIB
    then begin
      NumScans := biHeight;
      StartScan := 0;
    end;
    BytesPerPixel := biBitCount div 8;

    if BitSize <= 0 then
      BitSize := longint(SizeOf(Byte))
                 *(longint(biSizeImage) div biHeight)
                 *longint(NumScans + StartScan);
    if MemSize(Bits) < PtrInt(BitSize)
    then begin
      DebugLn('WARNING: [TGtk2WidgetSet.InternalGetDIBits] not enough memory allocated for Bits!');
      exit;
    end;

    // ToDo: other bitcounts
    if (biBitCount<>24) and (biBitCount<>16)
    then begin
      DebugLn('WARNING: [TGtk2WidgetSet.InternalGetDIBits] unsupported biBitCount=',dbgs(biBitCount));
      exit;
    end;

    if NumScans = 0 then Exit;

    Pos := 0;
    PadSize := (Longint(biSizeImage) div biHeight) - biWidth * BytesPerPixel;

    {$ifdef DebugGDK} BeginGDKErrorTrap; try{$ENDIF}
    DataSourceInitialize(GdiObject, biWidth);

    if DIB
    then Y := NumScans - 1
    else Y := 0;

    case biBitCount of
      24: repeat
        for X := 0 to biwidth - 1 do
        begin
          with DataSourceGetGDIRGB({%H-}PGDIObject(Bitmap), X, Y) do
          begin
            TempBuffer[0] := Blue;
            TempBuffer[1] := Green;
            TempBuffer[2] := Red;
          end;
          WriteData(TempBuffer, BytesPerPixel);
        end;
        WriteData(PadLine, PadSize);

        if DIB
        then dec(y)
        else inc(y);
      until (Y < 0) or (y >= longint(NumScans));

      16: repeat
        for X := 0 to biwidth - 1 do
        begin
          with DataSourceGetGDIRGB({%H-}PGDIObject(Bitmap), X, Y) do
          begin
            Buf16Bit := (Blue  shr 3) shl 11
                      + (Green shr 2) shl 5
                      + (Red   shr 3);
          end;
          WriteData(Buf16Bit);
        end;
        WriteData(PadLine, PadSize);

        if DIB
        then dec(y)
        else inc(y);
      until (Y < 0) or (y >= longint(NumScans));
    end;
  end;

  DataSourceFinalize;


  {$ifdef DebugGDK}finally EndGDKErrorTrap; end;{$endif}
end;

function TGtk2WidgetSet.RawImage_DescriptionFromDrawable(out
  ADesc: TRawImageDescription; ADrawable: PGdkDrawable; ACustomAlpha: Boolean
  ): boolean;
var
  Visual: PGdkVisual;
  Image: PGdkImage;
  Width, Height, Depth: integer;
  IsBitmap: Boolean;
begin
  Visual := nil;
  Width := 0;
  Height := 0;

  if ADrawable = nil
  then begin
    Visual := gdk_visual_get_system;
    IsBitmap := False;
  end
  else begin
    gdk_drawable_get_size(ADrawable, @Width, @Height);
    Depth := gdk_drawable_get_depth(ADrawable);
    Visual := gdk_window_get_visual(ADrawable);
    // pixmaps and bitmaps do not have a visual, but for pixmaps we need one
    if Visual = nil
    then Visual := gdk_visual_get_best_with_depth(Depth);
    IsBitmap := Depth = 1;
  end;

  if (Visual = nil) and not IsBitmap // bitmaps don't have a visual
  then begin
    DebugLn('TGtk2WidgetSet.RawImage_DescriptionFromDrawable: visual failed');
    Exit(False);
  end;

  ADesc.Init;
  ADesc.Width := cardinal(Width);
  ADesc.Height := cardinal(Height);
  ADesc.BitOrder := riboBitsInOrder;

  if ACustomAlpha
  then begin
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
  if IsBitmap
  then begin
    ADesc.Format := ricfGray;
  end
  else begin
    case Visual^.thetype of
      GDK_VISUAL_STATIC_GRAY:  ADesc.Format:=ricfGray;
      GDK_VISUAL_GRAYSCALE:    ADesc.Format:=ricfGray;
      GDK_VISUAL_STATIC_COLOR: ADesc.Format:=ricfGray; // this is not really gray, but an index in a color map, but colormaps are not supported yet, so use gray
      GDK_VISUAL_PSEUDO_COLOR: ADesc.Format:=ricfGray;
      GDK_VISUAL_TRUE_COLOR:   ADesc.Format:=ricfRGBA;
      GDK_VISUAL_DIRECT_COLOR: ADesc.Format:=ricfRGBA;
    else
      DebugLn('TGtk2WidgetSet.GetWindowRawImageDescription unknown Visual type ',
              dbgs(Integer(Visual^.thetype)));
      Exit(False);
    end;
  end;

  // Palette
  if not IsBitmap
  and (Visual^.thetype in [GDK_VISUAL_GRAYSCALE,
                           GDK_VISUAL_STATIC_COLOR,GDK_VISUAL_PSEUDO_COLOR])
  then begin
    // has palette
    // ToDo
    ADesc.PaletteColorCount:=0;
  end;

  // Depth
  if IsBitmap
  then ADesc.Depth := 1
  else ADesc.Depth := Visual^.Depth;

  if IsBitmap or (Visual^.byte_order = GDK_MSB_FIRST)
  then ADesc.ByteOrder := riboMSBFirst
  else ADesc.ByteOrder := riboLSBFirst;

  ADesc.LineOrder := riloTopToBottom;

  case ADesc.Depth of
    0..8:   ADesc.BitsPerPixel := ADesc.Depth;
    9..16:  ADesc.BitsPerPixel := 16;
    17..32: ADesc.BitsPerPixel := 32;
  else
    ADesc.BitsPerPixel := 64;
  end;

  if IsBitmap
  then begin
    ADesc.LineEnd  := rileByteBoundary;
    ADesc.RedPrec  := 1;
    ADesc.RedShift := 0;
  end
  else begin
    // Try retrieving the lineend
    Image := gdk_image_new(GDK_IMAGE_NORMAL, Visual, 1, 1);
    if Image = nil
    then begin
      DebugLn('TGtk2WidgetSet.GetWindowRawImageDescription testimage creation failed ');
      Exit(False);
    end;
    try
      // the minimum alignment we can detect is bpp
      // that is no problem since a line consists of n x bytesperpixel bytes
      case Image^.bpl of
        1: ADesc.LineEnd := rileByteBoundary;
        2: ADesc.LineEnd := rileWordBoundary;
        4: ADesc.LineEnd := rileDWordBoundary;
        8: ADesc.LineEnd := rileQWordBoundary;
      else
        DebugLn('TGtk2WidgetSet.GetWindowRawImageDescription Unknown line end: %d', [Image^.bpl]);
        Exit(False);
      end;
    finally
      gdk_image_destroy(Image);
      Image := nil;
    end;

    ADesc.RedPrec := Visual^.red_prec;
    ADesc.RedShift := Visual^.red_shift;
    ADesc.GreenPrec := Visual^.green_prec;
    ADesc.GreenShift := Visual^.green_shift;
    ADesc.BluePrec := Visual^.blue_prec;
    ADesc.BlueShift := Visual^.blue_shift;

    ADesc.MaskBitsPerPixel := 1;
    ADesc.MaskShift := 0;
    ADesc.MaskLineEnd := rileByteBoundary;
    ADesc.MaskBitOrder := riboBitsInOrder;
  end;

  {$IFDEF VerboseRawImage}
  DebugLn('TGtk2WidgetSet.GetWindowRawImageDescription A ',ADesc.AsString);
  {$ENDIF}

  Result := True;
end;

function TGtk2WidgetSet.RawImage_DescriptionFromPixbuf(out ADesc: TRawImageDescription; APixbuf: PGdkPixbuf): boolean;
var
  Width, Height, Depth: integer;
  HasAlpha: Boolean;
begin
  Width := 0;
  Height := 0;

  if APixbuf = nil
  then begin
    HasAlpha := False;
    Depth := 24;
  end
  else begin
    Width := gdk_pixbuf_get_width(APixbuf);
    Height := gdk_pixbuf_get_height(APixbuf);
    Depth := gdk_pixbuf_get_bits_per_sample(APixbuf) * gdk_pixbuf_get_n_channels(APixbuf);
    HasAlpha := gdk_pixbuf_get_has_alpha(APixbuf);
  end;

  ADesc.Init;
  ADesc.Width := cardinal(Width);
  ADesc.Height := cardinal(Height);
  ADesc.BitOrder := riboBitsInOrder;

  if HasAlpha
  then begin
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
  end
  else
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

function TGtk2WidgetSet.RawImage_FromDrawable(out ARawImage: TRawImage; ADrawable, AAlpha: PGdkDrawable; ARect: PRect): boolean;
var
  ADesc: TRawImageDescription absolute ARawImage.Description;

  function GetFromPixbuf(const ARect: TRect): Boolean;
  var
    Pixbuf: PGdkPixbuf;
    pixels: pguchar;
  begin
    // create pixbuf with alpha channel first
    Pixbuf := CreatePixbufFromDrawable(ADrawable, nil, True, ARect.Left, ARect.Top, 0, 0, ADesc.Width, ADesc.Height);
    try
      pixels := gdk_pixbuf_get_pixels(Pixbuf);

      ARawImage.DataSize := PtrUInt(gdk_pixbuf_get_rowstride(Pixbuf)) * PtrUInt(ADesc.Height);
      ReAllocMem(ARawImage.Data, ARawImage.DataSize);
      if ARawImage.DataSize > 0 then
        System.Move(pixels^, ARawImage.Data^, ARawImage.DataSize);

      //DbgDumpPixmap(ADrawable, 'RawImage_FromDrawable - image');
      //DbgDumpBitmap(AAlpha, 'RawImage_FromDrawable - alpha');
      //DbgDumpPixbuf(Pixbuf, 'RawImage_FromDrawable - pixbuf');
    finally
      gdk_pixbuf_unref(Pixbuf);
    end;

    Result := RawImage_SetAlpha(ARawImage, AAlpha, @ARect);
  end;

  function GetFromImage(const ARect: TRect): Boolean;
  var
    Image: PGdkImage;
  begin
    Image := gdk_image_get(ADrawable, ARect.Left, ARect.Top, ADesc.Width, ADesc.Height);
    if Image = nil
    then begin
      DebugLn('WARNING: TGtk2WidgetSet.RawImage_FromDrawable: gdk_image_get failed');
      exit(False);
    end;

    try
      {$ifdef RawimageConsistencyCheks}
      // consistency checks
      if ADesc.Depth <> Image^.Depth then
        RaiseGDBException('ARawImage.Description.Depth<>Image^.Depth '+IntToStr(ADesc.Depth)+'<>'+IntToStr(Image^.Depth));
      if ADesc.BitsPerPixel <> Image^.bits_per_pixel then
        RaiseGDBException('NewRawImage.Description.BitsPerPixel<>AnImage^.bpp');
      {$endif}

      ARawImage.DataSize := PtrUInt(Image^.bpl) * PtrUInt(Image^.Height);
      {$IFDEF VerboseRawImage}
      DebugLn('TGtk2WidgetSet.RawImage_FromDrawable: G Width=',dbgs(Image^.Width),' Height=',dbgs(Image^.Height),
        ' BitsPerPixel=',dbgs(ADesc.BitsPerPixel),' bpl=',dbgs(Image^.bpl));
      {$ENDIF}

      // copy data
      ADesc.Width := Image^.Width;
      ADesc.Height := Image^.Height;
      ReAllocMem(ARawImage.Data, ARawImage.DataSize);
      if ARawImage.DataSize > 0
      then begin
        System.Move(Image^.Mem^, ARawImage.Data^, ARawImage.DataSize);
        if Image^.Depth = 1
        then CheckGdkImageBitOrder(Image, ARawImage.Data, ARawImage.DataSize);
      end;

      {$IFDEF VerboseRawImage}
      DebugLn('TGtk2WidgetSet.RawImage_FromDrawable: H ',
        ' Width=',dbgs(ADesc.Width),
        ' Height=',dbgs(ADesc.Height),
        ' Depth=',dbgs(ADesc.Depth),
        ' DataSize=',dbgs(ARawImage.DataSize));
      {$ENDIF}
    finally
      gdk_image_destroy(Image);
    end;

    Result := True;
  end;

var
  R, R1: TRect;
  UseAlpha: Boolean;
begin
  Result := False;
  if ADrawable = nil then
    RaiseGDBException('TGtk2WidgetSet.RawImage_FromDrawable');

  ARawImage.Init;

  UseAlpha := AAlpha <> nil;

  // get raw image description
  if not RawImage_DescriptionFromDrawable(ADesc, ADrawable, UseAlpha)
  then begin
    DebugLn('WARNING: TGtk2WidgetSet.RawImage_FromDrawable: RawImage_DescriptionFromDrawable failed ');
    Exit;
  end;

  R := Rect(0, 0, ADesc.Width, ADesc.Height);
  if ARect <> nil
  then begin
    // get intersection
    IntersectRect(R1{%H-}, ARect^, R);
    R := R1;
    ADesc.Width := R.Right - R.Left;
    ADesc.Height := R.Bottom - R.Top;
  end;

  {$IFDEF VerboseRawImage}
  DebugLn('TGtk2WidgetSet.RawImage_FromDrawable get image ',
    dbgs(R.Left),',',dbgs(R.Top),',',dbgs(R.Right),',',dbgs(R.Bottom),
    ' GDKWindow=',DbgS(ADrawable));
  {$ENDIF}
  if (ADesc.Width <= 0) or (ADesc.Height <= 0)
  then begin
    //DebugLn('WARNING: TGtk2WidgetSet.GetRawImageFromGdkWindow Intersection empty');
    exit;
  end;

  if UseAlpha
  then Result := GetFromPixbuf(R)
  else Result := GetFromImage(R);
end;

function TGtk2WidgetSet.RawImage_FromPixbuf(out ARawImage: TRawImage;
  APixbuf: PGdkPixbuf; ARect: PRect): boolean;
var
  ADesc: TRawImageDescription absolute ARawImage.Description;
  Pixbuf: PGdkPixbuf;
  pixels: pguchar;
  Dest: PByte;
  R, R1: TRect;
  i: Integer;
  SourceStride, DestStride: PtrUInt;
begin
  Result := False;
  if APixbuf = nil then
    RaiseGDBException('TGtk2WidgetSet.RawImage_FromPixbuf');

  //DbgDumpPixbuf(APixbuf);

  ARawImage.Init;

  // get raw image description
  if not RawImage_DescriptionFromPixbuf(ADesc, APixbuf)
  then begin
    DebugLn('WARNING: TGtk2WidgetSet.RawImage_FromPixbuf: RawImage_DescriptionFromPixbuf failed ');
    Exit;
  end;

  R := Rect(0, 0, ADesc.Width, ADesc.Height);
  if ARect <> nil
  then begin
    // get intersection
    IntersectRect(R1{%H-}, ARect^, R);
    R := R1;
    ADesc.Width := R.Right - R.Left;
    ADesc.Height := R.Bottom - R.Top;
  end;

  if (ADesc.Width <= 0) or (ADesc.Height <= 0)
  then begin
    exit;
  end;

  Pixbuf := gdk_pixbuf_new_subpixbuf(APixbuf, R.Left, R.Top, ADesc.Width, ADesc.Height);
  try
    pixels := gdk_pixbuf_get_pixels(Pixbuf);
    SourceStride := PtrUInt(gdk_pixbuf_get_rowstride(Pixbuf));
    DestStride := ADesc.BytesPerLine;
    ARawImage.DataSize :=  DestStride * PtrUInt(ADesc.Height);
    ReAllocMem(ARawImage.Data, ARawImage.DataSize);
    if ARawImage.DataSize > 0 then
      if SourceStride = DestStride then
        System.Move(pixels^, ARawImage.Data^, ARawImage.DataSize)
      else begin
        { Extra padding bytes - need to copy by line }
        Dest := ARawImage.Data;
        for i := 0 to ADesc.Height-1 do begin
          System.Move(pixels^, Dest^, ADesc.BytesPerLine);
          Inc(pixels, SourceStride);
          Inc(Dest, DestStride);
        end;
      end;
  finally
    gdk_pixbuf_unref(Pixbuf);
  end;

  Result := True;
end;

function TGtk2WidgetSet.RawImage_SetAlpha(var ARawImage: TRawImage; AAlpha: PGdkPixmap; ARect: PRect): boolean;
// ARect must have the same dimension as the rawimage
var
  ADesc: TRawImageDescription absolute ARawImage.Description;

  procedure SetAlpha_32_1(AImage: PGdkImage; AWidth, AHeight: Cardinal);
  var
    SrcPtr, DstPtr, SrcLinePtr, DstLinePtr: PByte;
    DstPtr32: PDWord absolute DstPtr;
    SrcBytesPerLine: Integer;
    DstBytesPerLine: Integer;
    SrcBit, SrcStartBit, ShiftInc: ShortInt;
    DstMask: DWord;
    DstSet: DWord;
    X, Y: Cardinal;
    {$ifdef hasx}
    XImage: PXimage;
    {$endif}
  begin
    SrcLinePtr := AImage^.mem;
    SrcBytesPerLine := AImage^.bpl;
    DstLinePtr := ARawImage.Data;
    DstBytesPerLine := ARawImage.Description.BytesPerLine;

    if ADesc.ByteOrder = DefaultByteOrder
    then DstSet := (not ($FFFFFFFF shl ADesc.AlphaPrec)) shl ADesc.AlphaShift
    else DstSet := (not ($FFFFFFFF shr ADesc.AlphaPrec)) shr ADesc.AlphaShift;
    DstMask  := not DstSet;

    // bit order for X11 can be normal or reversed order, win32 and direct_fb
    // is constant in reversed order
    SrcStartBit := 7;
    ShiftInc := -1;
    //todo: TEST
    {$ifdef HasX}
    XImage := gdk_x11_image_get_ximage(AImage);
    if XImage^.bitmap_bit_order = LSBFirst
    then begin
      SrcStartBit := 0;
      ShiftInc := 1;
    end;
    {$endif}

    for Y := 0 to AHeight - 1 do
    begin
      SrcBit := SrcStartBit;
      SrcPtr := SrcLinePtr;
      DstPtr := DstLinePtr;
      for x := 0 to AWidth - 1 do
      begin
        if SrcPtr^ and (1 shl SrcBit) = 0
        then DstPtr32^ := DstPtr32^ and DstMask
        else DstPtr32^ := (DstPtr32^ and DstMask) or DstSet;
        Inc(DstPtr32);
        SrcBit := SrcBit + ShiftInc;
        if SrcBit and $F8 <> 0
        then begin
          SrcBit := SrcBit and 7;
          Inc(SrcPtr);
        end;
      end;
      Inc(SrcLinePtr, SrcBytesPerLine);
      Inc(DstLinePtr, DstBytesPerLine);
    end;
  end;

  procedure SetAlpha_32_8(AImage: PGdkImage; AWidth, AHeight: Cardinal);
  var
    SrcPtr, DstPtr, SrcLinePtr, DstLinePtr: PByte;
    DstPtr32: PDWord absolute DstPtr;
    SrcBytesPerLine: Integer;
    DstBytesPerLine: Integer;
    DstMask: DWord;
    DstShift: Byte;
    X, Y: Cardinal;
  begin
    SrcLinePtr := AImage^.mem;
    SrcBytesPerLine := AImage^.bpl;
    DstLinePtr := ARawImage.Data;
    DstBytesPerLine := ARawImage.Description.BytesPerLine;

    DstMask := not (((1 shl ADesc.AlphaPrec) - 1) shl ADesc.AlphaShift);
    DstShift := ADesc.AlphaShift;

    for Y := 0 to AHeight - 1 do
    begin
      SrcPtr := SrcLinePtr;
      DstPtr := DstLinePtr;
      for x := 0 to AWidth - 1 do
      begin
        DstPtr32^ := (DstPtr32^ and DstMask) or (Cardinal(SrcPtr^) shl DstShift);
        Inc(DstPtr32);
        Inc(SrcPtr);
      end;
      Inc(SrcLinePtr, SrcBytesPerLine);
      Inc(DstLinePtr, DstBytesPerLine);
    end;
  end;

var
  Width, Height, H, W, D: cardinal;
  Image: PGdkImage;
  R: TRect;
begin
  Result := False;

  if ARawImage.Data = nil
  then begin
    {$ifdef RawimageConsistencyChecks}
    RaiseGDBException('TGtk2WidgetSet.RawImage_SetAlpha RawImage.Data = nil');
    {$else}
    DebugLn('WARNING: TGtk2WidgetSet.RawImage_SetAlpha RawImage.Data = nil');
    {$endif}
    Exit;
  end;

  if ADesc.AlphaPrec = 0
  then begin
    {$ifdef RawimageConsistencyChecks}
    RaiseGDBException('TGtk2WidgetSet.RawImage_SetAlpha RawImage.Description.AlphaPrec = 0');
    {$else}
    DebugLn('WARNING: TGtk2WidgetSet.RawImage_SetAlpha No alpha channel defined');
    {$endif}
    Exit;
  end;

  if AAlpha = nil
  then begin
    DebugLn('WARNING: TGtk2WidgetSet.RawImage_SetAlpha Alpha = nil');
    Exit;
  end;

  gdk_drawable_get_size(AAlpha, @W, @H);
  D := gdk_drawable_get_depth(AAlpha);
  if (D <> 1) and (D <> 8)
  then begin
    DebugLn('WARNING: TGtk2WidgetSet.RawImage_SetAlpha: Only a Depth of 1 or 8 is supported. (depth=%d)', [D]);
    Exit;
  end;

  if ARect = nil
  then R := Rect(0, 0, ADesc.Width, ADesc.Height)
  else R := ARect^;

  if (longint(W) < R.Right) or (longint(H) < R.Bottom)
  then begin
    DebugLn('WARNING: TGtk2WidgetSet.RawImage_SetAlpha: Rect(%d,%d %d,%d) outside alpha pixmap(0,0 %d,%d)', [R.Left, R.Top, R.Right, R.Bottom, W, H]);
    Exit;
  end;

  Width := R.Right - R.Left;
  Height := R.Bottom - R.Top;

  if Width <> ADesc.Width
  then begin
    {$ifdef RawimageConsistencyChecks}
    RaiseGDBException('TGtk2WidgetSet.RawImage_SetAlpha: Width <> RawImage.Description.Width');
    {$else}
    DebugLn('WARNING: TGtk2WidgetSet.RawImage_SetAlpha: Width(=%d) <> RawImage.Description.Width(=%d)', [Width, ADesc.Width]);
    {$endif}
    Exit;
  end;

  if Height <> ADesc.Height
  then begin
    {$ifdef RawimageConsistencyChecks}
    RaiseGDBException('TGtk2WidgetSet.RawImage_SetAlpha: Height <> RawImage.Description.Height');
    {$else}
    DebugLn('WARNING: TGtk2WidgetSet.RawImage_SetAlpha: Height(=%d) <> RawImage.Description.Height(=%d)', [Height, ADesc.Height]);
    {$endif}
    Exit;
  end;

  // get gdk_image from gdkbitmap
  Image := gdk_image_get(AAlpha, R.Left, R.Top, Width, Height);
  if Image = nil
  then begin
    DebugLn('WARNING: TGtk2WidgetSet.RawImage_SetAlpha: gdk_image_get failed');
    Exit;
  end;

  try
    case ADesc.BitsPerPixel of
      32: begin
        if D = 1
        then SetAlpha_32_1(Image, Width, Height)
        else SetAlpha_32_8(Image, Width, Height);
      end;
    else
      DebugLn('WARNING: TGtk2WidgetSet.RawImage_SetAlpha: RawImage.Description.BitsPerPixel=%d not supported', [ADesc.BitsPerPixel]);
      Exit;
    end;

  finally
    gdk_image_destroy(Image);
  end;

  Result:=true;
end;

function TGtk2WidgetSet.RawImage_AddMask(var ARawImage: TRawImage; AMask: PGdkBitmap; ARect: PRect): boolean;
// ARect must have the same dimension as the rawimage

var
  ADesc: TRawImageDescription absolute ARawImage.Description;
  Left, Top, Width, Height, H: longint;
  Image: PGdkImage;
  BytesPerLine: Integer;
  SrcPtr, DstPtr: PByte;
begin
  Result := False;

  if ARawImage.Mask <> nil
  then begin
    {$ifdef RawimageConsistencyChecks}
    RaiseGDBException('TGtk2WidgetSet.RawImage_AddMask RawImage.Mask <> nil');
    {$else}
    DebugLn('WARNING: TGtk2WidgetSet.RawImage_AddMask RawImage.Mask <> nil');
    {$endif}
    Exit;
  end;

  if AMask = nil
  then begin
    DebugLn('WARNING: TGtk2WidgetSet.RawImage_AddMask AMask = nil');
    Exit;
  end;

  if ARect = nil
  then begin
    Left := 0;
    Top := 0;
    Width := ADesc.Width;
    Height := ADesc.Height;
  end
  else begin
    Left := ARect^.Left;
    Top := ARect^.Top;
    Width := Min(ADesc.Width,  ARect^.Right - ARect^.Left);
    Height := Min(ADesc.Height, ARect^.Bottom - ARect^.Top);
  end;

  if cardinal(Width) <> ADesc.Width
  then begin
    {$ifdef RawimageConsistencyChecks}
    RaiseGDBException('TGtk2WidgetSet.RawImage_AddMask: Width <> RawImage.Description.Width');
    {$else}
    DebugLn('WARNING: TGtk2WidgetSet.RawImage_AddMask: Width(=%d) <> RawImage.Description.Width(=%d)', [Width, ADesc.Width]);
    {$endif}
    Exit;
  end;

  if cardinal(Height) <> ADesc.Height
  then begin
    {$ifdef RawimageConsistencyChecks}
    RaiseGDBException('TGtk2WidgetSet.RawImage_AddMask: Height <> RawImage.Description.Height');
    {$else}
    DebugLn('WARNING: TGtk2WidgetSet.RawImage_AddMask: Height(=%d) <> RawImage.Description.Height(=%d)', [Height, ADesc.Height]);
    {$endif}
    Exit;
  end;

  // get gdk_image from gdkbitmap
  Image := gdk_image_get(AMask, Left, Top, Width, Height);
  if Image = nil
  then begin
    DebugLn('WARNING: TGtk2WidgetSet.RawImage_AddMask: gdk_image_get failed');
    Exit;
  end;

  try
    {$IFDEF VerboseRawImage}
    DebugLn('TGtk2WidgetSet.RawImage_AddMask: A BytesPerLine=',dbgs(Image^.bpl),
      ' theType=',dbgs(ord(Image^._type)),
      ' depth=',dbgs(Image^.depth),' AnImage^.bpp=',dbgs(Image^.bpp));
    DebugLn('RawImage=', ARawImage.Description.AsString);
    {$ENDIF}

    // See also GetWindowRawImageDescription
    ADesc.MaskBitsPerPixel := GetGdkImageBitsPerPixel(Image);
    ADesc.MaskLineEnd := rileByteBoundary;// gdk_bitmap_create_from_data expects rileByteBoundary
    BytesPerLine := GetBytesPerLine(ADesc.Width, ADesc.MaskBitsPerPixel, ADesc.MaskLineEnd);
    ARawImage.MaskSize := PtrUInt(BytesPerLine) * PtrUInt(Height);

    ReAllocMem(ARawImage.Mask, ARawImage.MaskSize);
    if ARawImage.MaskSize > 0
    then begin
      // copy data
      if BytesPerLine = Image^.bpl
      then begin
        // we can copy all in one go
        System.Move(Image^.Mem^, ARawImage.Mask^, ARawImage.MaskSize);
      end
      else begin
        // copy line by line
        SrcPtr := Image^.Mem;
        DstPtr := ARawImage.Mask;
        H := Height;
        while H > 0 do
        begin
          System.Move(SrcPtr^, DstPtr^, BytesPerLine);
          Inc(SrcPtr, Image^.bpl);
          Inc(DstPtr, BytesPerLine);
          Dec(H);
        end;
      end;
      CheckGdkImageBitOrder(Image, ARawImage.Mask, ARawImage.MaskSize);
    end;


    {$IFDEF VerboseRawImage}
    {DebugLn('TGtk2WidgetSet.GetRawImageMaskFromGdkBitmap H ',
      ' Width=',dbgs(ARawImage.Description.Width),
      ' Height=',dbgs(ARawImage.Description.Height),
      ' AlphaBitsPerPixel=',dbgs(ARawImage.Description.AlphaBitsPerPixel),
      ' MaskSize=',dbgs(ARawImage.MaskSize));}
    {$ENDIF}
  finally
    gdk_image_destroy(Image);
  end;

  Result:=true;
end;

{------------------------------------------------------------------------------
  Function: TGtk2WidgetSet.StretchCopyArea
  Params:  DestDC:                The destination devicecontext
           X, Y:                  The left/top corner of the destination rectangle
           Width, Height:         The size of the destination rectangle
           SrcDC:                 The source devicecontext
           XSrc, YSrc:            The left/top corner of the source rectangle
           SrcWidth, SrcHeight:   The size of the source rectangle
           Mask:                  An optional mask
           XMask, YMask:          Only used if Mask<>nil
           Rop:                   The raster operation to be performed
  Returns: True if succesful

  The StretchBlt function copies a bitmap from a source rectangle into a
  destination rectangle using the specified raster operation. If needed, it
  resizes the bitmap to fit the dimensions of the destination rectangle.
  Sizing is done according to the stretching mode currently set in the
  destination device context.
  If SrcDC contains a mask the pixmap will be copied with this transparency.

  ToDo:
    Mirroring
    Extended NonDrawable support (Image, Bitmap, etc)
    Scale mask
 ------------------------------------------------------------------------------}
function TGtk2WidgetSet.StretchCopyArea(DestDC: HDC; X, Y, Width, Height: Integer;
  SrcDC: HDC; XSrc, YSrc, SrcWidth, SrcHeight: Integer;
  Mask: HBITMAP; XMask, YMask: Integer;
  Rop: Cardinal): Boolean;
var
  SrcDevContext: TGtkDeviceContext absolute SrcDC;
  DstDevContext: TGtkDeviceContext absolute DestDC;
  TempPixmap: PGdkPixmap;
  TempMaskBitmap: PGdkBitmap;
  SizeChange, ROpIsSpecial: Boolean;
  FlipHorz, FlipVert: Boolean;

  function ScaleAndROP(DestGC: PGDKGC;
    Src: PGDKDrawable; SrcPixmap: PGdkDrawable; SrcMaskBitmap: PGdkBitmap): Boolean;
  var
    Depth: Integer;
    ScaleMethod: TGdkInterpType;
    ShrinkWidth, ShrinkHeight: Boolean;
    GC: PGDKGC;
  begin
    {$IFDEF VerboseStretchCopyArea}

    DebugLn('ScaleAndROP START DestGC=',DbgS(DestGC),
      ' SrcPixmap=',DbgS(SrcPixmap),
      ' SrcMaskPixmap=',DbgS(SrcMaskBitmap));
    {$ENDIF}
    Result := False;

    if DestGC = nil
    then begin
      DebugLn('WARNING: [TGtk2WidgetSet.StretchCopyArea] Uninitialized DestGC');
      exit;
    end;

    // create a temporary graphic context for the scale and raster operations
    // copy the destination GC values into the temporary GC
    GC := gdk_gc_new(DstDevContext.Drawable);
    gdk_gc_copy(GC, DestGC);

    // clear any previous clipping in the temporary GC
    gdk_gc_set_clip_region(GC, nil);
    gdk_gc_set_clip_rectangle(GC, nil);

    if SizeChange
    then begin
      {$IFDEF VerboseStretchCopyArea}
      Depth:=gdk_visual_get_system^.Depth;
      DebugLn('ScaleAndROP Scaling buffer: '+dbgs(Width),' x '+dbgs(Height),' x '+dbgs(Depth));
      {$ENDIF}

      // calculate ScaleMethod
      {$IFDEF VerboseGtkToDos}{$note use SetStretchBltMode(dc, mode) here}{$ENDIF}
      //GDKPixbuf Scaling is not done in the same way as Windows
      //but by rights ScaleMethod should really be chosen based
      //on the destination device's internal flag
      {GDK_INTERP_NEAREST,GDK_INTERP_TILES,
      GDK_INTERP_BILINEAR,GDK_INTERP_HYPER);}

      ShrinkWidth := Width < SrcWidth;
      ShrinkHeight := Height < SrcHeight;
      if ShrinkWidth and ShrinkHeight
      then ScaleMethod := GDK_INTERP_TILES
      else
        if ShrinkWidth or ShrinkHeight
        then ScaleMethod := GDK_INTERP_BILINEAR//GDK_INTERP_HYPER
        else begin
          if DstDevContext.Antialiasing then ScaleMethod := GDK_INTERP_BILINEAR
            else ScaleMethod := GDK_INTERP_NEAREST;
        end;

      // Scale the src part to a temporary pixmap with the size of the
      // destination rectangle

      Result := ScalePixmapAndMask(GC, ScaleMethod,
                            SrcPixmap, XSrc, YSrc, SrcWidth, SrcHeight,
                            nil, SrcMaskBitmap,
                            Width, Height, FlipHorz, FlipVert, TempPixmap, TempMaskBitmap);
      if not Result
      then DebugLn('WARNING: ScaleAndROP ScalePixmap for pixmap failed');
    end
    else begin
      if ROpIsSpecial
      then begin
        // no scaling, but special ROp

        Depth:=gdk_visual_get_system^.Depth;
        {$IFDEF VerboseStretchCopyArea}
        DebugLn('ScaleAndROP Creating rop buffer: '+dbgs(Width),' x '+dbgs(Height),' x '+dbgs(Depth));
        {$ENDIF}
        TempPixmap := gdk_pixmap_new(nil,SrcWidth,SrcHeight,Depth);
        gdk_window_copy_area(TempPixmap, GC, 0, 0,
           Src, XSrc, YSrc, SrcWidth, SrcHeight);
      end;
      Result := True;
    end;

    // set raster operation in the destination GC
    if Result
    then SetGCRasterOperation(DestGC, ROP);

    gdk_gc_unref(GC);
  end;

  procedure ROPFillBuffer(DC : hDC);
  var
    OldCurrentBrush: PGdiObject;
    Brush : hBrush;
  begin
    if TempPixmap = nil then exit;

    if not ((ROp=WHITENESS) or (ROp=BLACKNESS) or (ROp=DSTINVERT)) then Exit;

    {$IFDEF VerboseStretchCopyArea}
    DebugLn('ROPFillBuffer ROp='+dbgs(ROp));
    {$ENDIF}
    with TGtkDeviceContext(DC) do
    begin
      // Temporarily hold the old brush to
      // replace it with the given brush
      OldCurrentBrush := CurrentBrush;
      if ROP = WHITENESS
      then
        Brush := GetStockObject(WHITE_BRUSH)
      else
        Brush := GetStockObject(BLACK_BRUSH);
      CurrentBrush := {%H-}PGdiObject(Brush);
      SelectedColors := dcscBrush;

      if not IsNullBrush
      then begin
        gdk_draw_rectangle(TempPixmap, GC, 1, 0, 0, Width, Height);
      end;
      // Restore current brush
      CurrentBrush := OldCurrentBrush;
    end;
  end;

  function SrcDevBitmapToDrawable: Boolean;
  var
    SrcDrawable: PGdkDrawable;
    MskBitmap: PGdkBitmap;
    ClipMask: PGdkBitmap;
    SrcGDIBitmap: PGdiObject;
    B: Boolean;
    TmpPixbuf, TmpPixbuf2: PGdkPixbuf;
  begin
    Result:=true;

    // special case for copying from bitmaps with alpha channel
    if (ROP=SRCCOPY) and Assigned(SrcDevContext.Pixbuf) then
    begin
      if SizeChange then
      begin
        // there isn't a "stretch draw" function for pixbufs so we need to make
        // a temporary scaled copy if we have a different size
        if (Width <> SrcWidth) or (Height <> SrcHeight) then begin
          TmpPixbuf:=gdk_pixbuf_scale_simple(SrcDevContext.Pixbuf, Width, Height, GDK_INTERP_HYPER);
          if not Assigned(TmpPixbuf) then
          begin
            DebugLn('SrcDevBitmapToDrawable: failed to create temporary pixbuf for scaled draw');
            exit;
          end;
        end else begin
          // same size but we have flips, just increase the refcount of the
          // original pixbuf
          TmpPixbuf:=SrcDevContext.Pixbuf;
          gdk_pixbuf_ref(TmpPixbuf);
        end;
        // flip the pixmap, if necessary
        if FlipHorz then begin
          TmpPixbuf2:=gdk_pixbuf_flip(TmpPixbuf, True);
          gdk_pixbuf_unref(TmpPixbuf);
          TmpPixbuf:=TmpPixbuf2;
        end;
        if FlipVert then begin
          TmpPixbuf2:=gdk_pixbuf_flip(TmpPixbuf, False);
          gdk_pixbuf_unref(TmpPixbuf);
          TmpPixbuf:=TmpPixbuf2;
        end;
        // draw and release the final pixbuf
        gdk_draw_pixbuf(DstDevContext.Drawable, DstDevContext.GC, TmpPixbuf, XSrc, YSrc, X, Y, Width, Height, GDK_RGB_DITHER_MAX, 0, 0);
        gdk_pixbuf_unref(TmpPixbuf);
      end else
      begin
        gdk_draw_pixbuf(DstDevContext.Drawable, DstDevContext.GC, SrcDevContext.Pixbuf, XSrc, YSrc, X, Y, Width, Height, GDK_RGB_DITHER_MAX, 0, 0);
      end;
      Exit;
    end;

    {$IFDEF VerboseStretchCopyArea}
    DebugLn('SrcDevBitmapToDrawable Start');
    {$ENDIF}
    B := False;
    SrcGDIBitmap := SrcDevContext.CurrentBitmap;
    if SrcGDIBitmap = nil then
    begin
      SrcDrawable := SrcDevContext.Drawable;
      MskBitmap := nil;
      if SrcDrawable = nil then
      begin
        DebugLn('SrcDevBitmapToDrawable NOTE: SrcDevContext.CurrentBitmap=nil, SrcDevContext.Drawable = nil');
        exit;
      end;
    end else
    begin
      SrcDrawable := SrcGDIBitmap^.GDIPixmapObject.Image;
      MskBitmap := CreateGdkMaskBitmap(HBITMAP({%H-}PtrUInt(SrcGDIBitmap)), Mask);
    end;

    {$IFDEF VerboseStretchCopyArea}
    DebugLn('SrcDevBitmapToDrawable SrcPixmap=[',GetWindowDebugReport(SrcDrawable),']',
      ' MaskPixmap=[',GetWindowDebugReport(MskBitmap),']');
    {$ENDIF}

    if (MskBitmap = nil) and (not SizeChange) and (ROP=SRCCOPY) then
    begin
      // simply copy the area
      {$IFDEF VerboseStretchCopyArea}
      DebugLn('SrcDevBitmapToDrawable Simple copy');
      {$ENDIF}
      gdk_gc_set_function(DstDevContext.GC, GDK_COPY);
      gdk_window_copy_area(DstDevContext.Drawable, DstDevContext.GC, X, Y,
        SrcDrawable, XSrc, YSrc, Width, Height);
      gdk_gc_set_function(DstDevContext.GC, DstDevContext.GetFunction);
      Exit;
    end;


    // perform raster operation and scaling into Scale and fGC
    DstDevContext.SelectedColors := dcscCustom;
    if not ScaleAndROP(DstDevContext.GC, SrcDevContext.Drawable, SrcDrawable, MskBitmap) then
    begin
      if MskBitmap <> nil then
        gdk_bitmap_unref(MskBitmap);
      DebugLn('WARNING: SrcDevBitmapToDrawable: ScaleAndROP failed');
      Exit;
    end;

    {$IFDEF VerboseStretchCopyArea}
    DebugLn('SrcDevBitmapToDrawable TempPixmap=',DbgS(TempPixmap),' TempMaskPixmap=',DbgS(TempMaskBitmap));
    {$ENDIF}
    if TempPixmap <> nil then
    begin
      SrcDrawable := TempPixmap;
      XSrc := 0;
      YSrc := 0;
      SrcWidth := Width;
      SrcHeight := Height;
    end;
    if TempMaskBitmap <> nil then
    begin
      if MskBitmap <> nil then
      begin
        gdk_bitmap_unref(MskBitmap);
        B := True;
      end;
      MskBitmap := TempMaskBitmap;
      XMask := 0;
      YMask := 0;
    end;

    case ROP of
      WHITENESS, BLACKNESS :
        ROPFillBuffer(DestDC);
    end;

    {$IFDEF VerboseStretchCopyArea}
    DebugLn('SrcDevBitmapToDrawable ',
      ' SrcDrawable=',DbgS(SrcDrawable),
      ' XSrc='+dbgs(XSrc),' YSrc='+dbgs(YSrc),' SrcWidth='+dbgs(SrcWidth),' SrcHeight='+dbgs(SrcHeight),
      ' MaskPixmap=',DbgS(MskBitmap),
      ' XMask='+dbgs(XMask),' YMask='+dbgs(YMask),
      '');
    {$ENDIF}

    // set clipping mask for transparency
    MergeClipping(DstDevContext, DstDevContext.GC, X, Y, Width, Height,
                  MskBitmap, XMask, YMask, ClipMask);

    // draw image
    {$IFDEF DebugGDK}BeginGDKErrorTrap;{$ENDIF}
    gdk_window_copy_area(DstDevContext.Drawable, DstDevContext.GC, X, Y,
      SrcDrawable, XSrc, YSrc, SrcWidth, SrcHeight);
    {$IFDEF DebugGDK}EndGDKErrorTrap;{$ENDIF}

    // unset clipping mask for transparency
    DstDevContext.ResetGCClipping;
    if ClipMask <> nil then
      gdk_bitmap_unref(ClipMask);

    if not B and (MskBitmap <> nil) then
      gdk_bitmap_unref(MskBitmap);

    // restore raster operation to SRCCOPY
    gdk_gc_set_function(DstDevContext.GC, GDK_Copy);

    Result:=True;
  end;

  function DrawableToDrawable: Boolean;
  begin
    {$IFDEF VerboseStretchCopyArea}
    DebugLn('DrawableToDrawable Start');
    {$ENDIF}
    Result:=SrcDevBitmapToDrawable;
  end;

  function PixmapToDrawable: Boolean;
  begin
    {$IFDEF VerboseStretchCopyArea}
    DebugLn('PixmapToDrawable Start');
    {$ENDIF}
    Result:=SrcDevBitmapToDrawable;
  end;

  function PixmapToBitmap: Boolean;
  begin
    DebugLn('WARNING: [TGtk2WidgetSet.StretchCopyArea] PixmapToBitmap unimplemented!');
    Result:=false;
  end;

  function BitmapToPixmap: Boolean;
  begin
    DebugLn('WARNING: [TGtk2WidgetSet.StretchCopyArea] BitmapToPixmap unimplemented!');
    Result:=false;
  end;

  function Unsupported: Boolean;
  begin
    DebugLn('WARNING: [TGtk2WidgetSet.StretchCopyArea] Destination and/or Source unsupported!!');
    Result:=false;
  end;

  //----------
  function NoDrawableToNoDrawable: Boolean;
  begin
    Result := Unsupported;
    if SrcDevContext.CurrentBitmap = nil then Exit;
    if DstDevContext.CurrentBitmap = nil then Exit;

    case SrcDevContext.CurrentBitmap^.GDIBitmapType of
      gbBitmap:
        case DstDevContext.CurrentBitmap^.GDIBitmapType of
          gbBitmap: Result:=DrawableToDrawable;
          gbPixmap: Result:=BitmapToPixmap;
        end;
      gbPixmap:
        case DstDevContext.CurrentBitmap^.GDIBitmapType of
          gbBitmap: Result:=PixmapToBitmap;
          gbPixmap: Result:=DrawableToDrawable;
        end;
    end;
  end;

  function NoDrawableToDrawable: Boolean;
  begin
    Result := Unsupported;
    if SrcDevContext.CurrentBitmap = nil then Exit;

    case SrcDevContext.CurrentBitmap^.GDIBitmapType of
      gbBitmap: Result:=PixmapToDrawable;
      gbPixmap: Result:=PixmapToDrawable;
    end;
  end;

  function DrawableToNoDrawable: Boolean;
  begin
    Result := Unsupported;
    if DstDevContext.CurrentBitmap = nil then Exit;

    case DstDevContext.CurrentBitmap^.GDIBitmapType of
      gbBitmap: Result:=Unsupported;
      gbPixmap: Result:=Unsupported;
    end;
  end;

  procedure RaiseSrcDrawableNil;
  begin
    DebugLn(['RaiseSrcDrawableNil ',GetWidgetDebugReport(SrcDevContext.Widget)]);
    RaiseGDBException(Format('TGtk2WidgetSet.StretchCopyArea SrcDC=%p Drawable=nil', [Pointer(SrcDevContext)]));
  end;

  procedure RaiseDestDrawableNil;
  begin
    RaiseGDBException(Format('TGtk2WidgetSet.StretchCopyArea DestDC=%p Drawable=nil', [Pointer(DstDevContext)]));
  end;

var
  NewSrcWidth: Integer;
  NewSrcHeight: Integer;
  NewWidth: Integer;
  NewHeight: Integer;
  SrcDCOrigin: TPoint;
  DstDCOrigin: TPoint;
  SrcWholeWidth, SrcWholeHeight: integer;
  DstWholeWidth, DstWholeHeight, AOldRop: integer;
begin
  Result := IsValidDC(DestDC) and IsValidDC(SrcDC);
  {$IFDEF VerboseStretchCopyArea}
  DebugLn('StretchCopyArea Start '+dbgs(Result));
  {$ENDIF}
  if not Result then Exit;

  if SrcDevContext.HasTransf then
  begin
    // TK: later with shear and rotation error here?
    SrcDevContext.TransfPoint(XSrc, YSrc);
    SrcDevContext.TransfExtent(SrcWidth, SrcHeight);
  end;
  SrcDCOrigin := SrcDevContext.Offset;
  Inc(XSrc, SrcDCOrigin.X);
  Inc(YSrc, SrcDCOrigin.Y);

  if DstDevContext.HasTransf then
  begin
    // TK: later with shear and rotation error here?
    DstDevContext.TransfPoint(X, Y);
    DstDevContext.TransfExtent(Width, Height);
  end;
  DstDCOrigin := DstDevContext.Offset;
  Inc(X, DstDCOrigin.X);
  Inc(Y, DstDCOrigin.Y);

  FlipHorz := Width < 0;
  if FlipHorz then
  begin
    Width := -Width;
    X := X - Width;
  end;

  FlipVert := Height < 0;
  if FlipVert then
  begin
    Height := -Height;
    Y := Y - Height;
  end;

  if (Width = 0) or (Height = 0) then exit;
  if (SrcWidth = 0) or (SrcHeight = 0) then exit;

  SizeChange := (Width <> SrcWidth) or (Height <> SrcHeight) or FlipVert or FlipHorz;
  ROpIsSpecial := (Rop <> SRCCOPY);

  if SrcDevContext.Drawable = nil then RaiseSrcDrawableNil;
  gdk_window_get_size(PGdkWindow(SrcDevContext.Drawable), @SrcWholeWidth, @SrcWholeHeight);


  if DstDevContext.Drawable = nil then RaiseDestDrawableNil;
  gdk_window_get_size(PGdkWindow(DstDevContext.Drawable), @DstWholeWidth, @DstWholeHeight);

  {$IFDEF VerboseStretchCopyArea}
  DebugLn('TGtk2WidgetSet.StretchCopyArea BEFORE CLIPPING X='+dbgs(X),' Y='+dbgs(Y),' Width='+dbgs(Width),' Height='+dbgs(Height),
    ' XSrc='+dbgs(XSrc)+' YSrc='+dbgs(YSrc)+' SrcWidth='+dbgs(SrcWidth)+' SrcHeight='+dbgs(SrcHeight),
    ' SrcDrawable=',DbgS(TGtkDeviceContext(SrcDC).Drawable),
    ' SrcOrigin='+dbgs(SrcDCOrigin),
    ' DestDrawable='+DbgS(TGtkDeviceContext(DestDC).Drawable),
    ' DestOrigin='+dbgs(DstDCOrigin),
    ' Mask='+DbgS(Mask)+' XMask='+dbgs(XMask)+' YMask='+dbgs(YMask),
    ' SizeChange='+dbgs(SizeChange)+' ROpIsSpecial='+dbgs(ROpIsSpecial),
    ' DestWhole='+dbgs(DstWholeWidth)+','+dbgs(DstWholeHeight),
    ' SrcWhole='+dbgs(SrcWholeWidth)+','+dbgs(SrcWholeHeight),
    '');
  {$ENDIF}
  {$IFDEF VerboseGtkToDos}{$note use intersectrect here}{$ENDIF}
  if X >= DstWholeWidth then Exit;
  if Y >= DstWholeHeight then exit;
  if X + Width <= 0 then exit;
  if Y + Height <=0 then exit;
  if XSrc >= SrcWholeWidth then Exit;
  if YSrc >= SrcWholeHeight then exit;
  if XSrc + SrcWidth <= 0 then exit;
  if YSrc + SrcHeight <=0 then exit;

  // gdk does not allow copying areas, party laying out of bounds
  // -> clip

  // clip src to the left
  if (XSrc<0) then begin
    NewSrcWidth:=SrcWidth+XSrc;
    NewWidth:=((Width*NewSrcWidth) div SrcWidth);
    {$IFDEF VerboseStretchCopyArea}
    DebugLn('StretchCopyArea Cliping Src to left NewSrcWidth='+dbgs(NewSrcWidth),' NewWidth='+dbgs(NewWidth));
    {$ENDIF}
    if NewWidth = 0 then exit;
    inc(X, Width-NewWidth);
    if X >= DstWholeWidth then exit;
    XSrc:=0;
    SrcWidth := NewSrcWidth;
  end;

  // clip src to the top
  if (YSrc<0) then begin
    NewSrcHeight:=SrcHeight+YSrc;
    NewHeight:=((Height*NewSrcHeight) div SrcHeight);
    {$IFDEF VerboseStretchCopyArea}
    DebugLn('StretchCopyArea Cliping Src to top NewSrcHeight='+dbgs(NewSrcHeight),' NewHeight='+dbgs(NewHeight));
    {$ENDIF}
    if NewHeight = 0 then exit;
    inc(Y, Height - NewHeight);
    if Y >= DstWholeHeight then exit;
    YSrc:=0;
    SrcHeight := NewSrcHeight;
  end;

  // clip src to the right
  if (XSrc+SrcWidth>SrcWholeWidth) then begin
    NewSrcWidth:=SrcWholeWidth-XSrc;
    Width:=((Width*NewSrcWidth) div SrcWidth);
    {$IFDEF VerboseStretchCopyArea}
    DebugLn('StretchCopyArea Cliping Src to right NewSrcWidth='+dbgs(NewSrcWidth),' NewWidth='+dbgs(Width));
    {$ENDIF}
    if (Width=0) then exit;
    if (X+Width<=0) then exit;
    SrcWidth:=NewSrcWidth;
  end;

  // clip src to the bottom
  if (YSrc+SrcHeight>SrcWholeHeight) then begin
    NewSrcHeight:=SrcWholeHeight-YSrc;
    Height:=((Height*NewSrcHeight) div SrcHeight);
    {$IFDEF VerboseStretchCopyArea}
    DebugLn('StretchCopyArea Cliping Src to bottom NewSrcHeight='+dbgs(NewSrcHeight),' NewHeight='+dbgs(Height));
    {$ENDIF}
    if (Height=0) then exit;
    if (Y+Height<=0) then exit;
    SrcHeight:=NewSrcHeight;
  end;

  if Mask = 0
  then begin
    XMask := XSrc;
    YMask := YSrc;
  end;

  // mark temporary scaling/rop buffers as uninitialized
  TempPixmap := nil;
  TempMaskBitmap := nil;

  {$IFDEF VerboseStretchCopyArea}
  write('TGtk2WidgetSet.StretchCopyArea AFTER CLIPPING X='+dbgs(X)+' Y='+dbgs(Y)+' Width='+dbgs(Width)+' Height='+dbgs(Height),
    ' XSrc='+dbgs(XSrc),' YSrc='+dbgs(YSrc)+' SrcWidth='+dbgs(SrcWidth)+' SrcHeight='+dbgs(SrcHeight),
    ' SrcDrawable='+DbgS(SrcDevContext.Drawable),
    ' DestDrawable='+DbgS(DstDevContext.Drawable),
    ' Mask='+DbgS(Mask)+' XMask='+dbgs(XMask)+' YMask='+dbgs(YMask),
    ' SizeChange='+dbgs(SizeChange)+' ROpIsSpecial='+dbgs(ROpIsSpecial));
  write(' ROp=');
  case ROp of
    SRCCOPY     : DebugLn('SRCCOPY');
    SRCPAINT    : DebugLn('SRCPAINT');
    SRCAND      : DebugLn('SRCAND');
    SRCINVERT   : DebugLn('SRCINVERT');
    SRCERASE    : DebugLn('SRCERASE');
    NOTSRCCOPY  : DebugLn('NOTSRCCOPY');
    NOTSRCERASE : DebugLn('NOTSRCERASE');
    MERGECOPY   : DebugLn('MERGECOPY');
    MERGEPAINT  : DebugLn('MERGEPAINT');
    PATCOPY     : DebugLn('PATCOPY');
    PATPAINT    : DebugLn('PATPAINT');
    PATINVERT   : DebugLn('PATINVERT');
    DSTINVERT   : DebugLn('DSTINVERT');
    BLACKNESS   : DebugLn('BLACKNESS');
    WHITENESS   : DebugLn('WHITENESS');
  else
    DebugLn('???');
  end;
  {$ENDIF}

  {$IFDEF VerboseGtkToDos}{$note tode remove, earlier checks require drawable <> nil}{$ENDIF}
  AOldRop := SetROP2(DestDC, Rop);
  if SrcDevContext.Drawable = nil
  then begin
    if DstDevContext.Drawable = nil
    then
      Result := NoDrawableToNoDrawable
    else
      Result := NoDrawableToDrawable;
  end
  else begin
    if DstDevContext.Drawable = nil
    then
      Result := DrawableToNoDrawable
    else
      Result := DrawableToDrawable;
  end;
  SetROP2(DestDC, AOldRop);

  if TempPixmap <> nil
  then gdk_pixmap_unref(TempPixmap);
  if TempMaskBitmap <> nil
  then gdk_pixmap_unref(TempMaskBitmap);
end;

{$IFDEF HASX}
function TGtk2WidgetSet.GetDesktopWidget: PGtkWidget;
begin
  Result := FDesktopWidget;
end;

{function TGtk2WidgetSet.X11Raise(AHandle: HWND): boolean;
var
   Display: PDisplay;
   RootWin: TWindow;
   ScreenNum: Integer;
   XClient: TXClientMessageEvent;
   WMAtom: TAtom;
   screen: PGdkScreen;
begin
  Result:=false;
  screen:=gdk_screen_get_default;
  Display := gdk_x11_get_default_xdisplay;

  if Display = nil then
    exit;
  ScreenNum := gdk_screen_get_number(screen);
  RootWin := gdk_x11_get_default_root_xwindow;

  XClient._type := ClientMessage;
  XClient.window := AHandle;
  WMAtom := XInternAtom(Display,'_NET_ACTIVE_WINDOW', False);
  XClient.message_type := WMATom;
  XClient.format := 32;
  XClient.data.l[0] := 1;
  XClient.data.l[1] := 0;
  XClient.data.l[2] := 0;
  Result:=XSendEvent (Display, RootWin, False,
	      SubstructureRedirectMask or SubstructureNotifyMask,
	      @XClient)<>0;
end;}

function TGtk2WidgetSet.IsCurrentDesktop(AWindow: PGdkWindow): Boolean;
var
  Display: PDisplay;
  ScreenNum: Integer;
  RootWin: TWindow;
  WMAtom: TAtom;

  typeReturned: TAtom;
  formatReturned: Integer;
  nitemsReturned: PtrInt;
  unused: PtrInt;
  WidgetIndex, DesktopIndex: Pointer;
  WidgetWin: TWindow;
begin
  Result := True;
  if AWindow = nil then
    exit;
  Display := gdk_x11_get_default_xdisplay;
  if Display = nil then
    exit;
  ScreenNum := gdk_x11_get_default_screen;
  RootWin := XRootWindow(Display, ScreenNum);
  WMAtom := XInternAtom(Display,'_NET_WM_DESKTOP', True);
  WidgetWin := gdk_x11_drawable_get_xid(PGdkDrawable(AWindow));

  if (WMAtom > 0) and (WidgetWin <> 0) then
  begin
    WidgetIndex := nil;
    DesktopIndex := nil;
    // first get our desktop num (virtual desktop !)
    if XGetWindowProperty(Display, WidgetWin, WMAtom, 0, 4, False, XA_CARDINAL,
       @typeReturned, @formatReturned, @nitemsReturned,
       @unused, @WidgetIndex) = Success then
    begin
      if (typeReturned = XA_CARDINAL) and (formatReturned = 32) and
        (WidgetIndex <> nil) then
      begin
        // now get current active desktop index
        WMAtom := XInternAtom(Display,'_NET_CURRENT_DESKTOP', True);
        if XGetWindowProperty(Display, RootWin, WMAtom, 0, 4, False,
          XA_CARDINAL, @typeReturned, @formatReturned, @nitemsReturned,
          @unused, @DesktopIndex) = Success then
        begin
          if (typeReturned = XA_CARDINAL) and (formatReturned = 32) and
            (DesktopIndex <> nil) then
            Result := PtrUint(WidgetIndex^) = PtrUint(DesktopIndex^);
        end;
      end;

      if WidgetIndex <> nil then
        XFree(WidgetIndex);
      if DesktopIndex <> nil then
        XFree(DesktopIndex);
      WidgetIndex := nil;
      DesktopIndex := nil;
    end;
  end;
end;

function TGtk2WidgetSet.GetWindowManager: String;
{used to get window manager name, so we can handle different wm's behaviour
 eg. kde vs. gnome}
var
  Display: PDisplay;
  RootWin: TWindow;
  WMAtom: TAtom;
  WMWindow: TWindow;

  typeReturned: TAtom;
  formatReturned: Integer;
  nitemsReturned: PtrInt;
  unused: PtrInt;
  data: Pointer;
  // Screen: PGdkScreen;
begin
  Result := '';

  Display := gdk_x11_get_default_xdisplay;

  if Display = nil then
    exit;
  // Screen := gdk_screen_get_default;
  RootWin := gdk_x11_get_default_root_xwindow;

  WMAtom := XInternAtom(Display,'_NET_WM_DESKTOP', True);

  if WMAtom > 0 then
  begin
    WMAtom := XInternAtom(Display,'_NET_SUPPORTING_WM_CHECK', False);
    if WMAtom > 0 then
    begin
      data := nil;
      WMWindow := 0;
      if XGetWindowProperty(Display, RootWin, WMAtom, 0, 1024, False, XA_WINDOW,
        @typeReturned, @formatReturned, @nitemsReturned,
        @unused, @data) = Success then
        begin
          if (typeReturned = XA_WINDOW) and (formatReturned = 32) and
            (Data <> nil) then
          begin
            // this is our window manager window
            WMWindow := TWindow(Data^);
            XFree(Data);
            Data := nil;
          end;
          if WMWindow = 0 then
            exit;
          WMAtom := XInternAtom(Display,'UTF8_STRING', False);
          if XGetWindowProperty(Display, WMWindow,
            XInternAtom(Display,'_NET_WM_NAME', False), 0, 1024, False,
            WMAtom, @typeReturned, @formatReturned, @nitemsReturned,
            @unused, @data) = Success then
          begin
            if (typeReturned = WMAtom) and (formatReturned = 8) then
              Result := LowerCase(StrPas(Data));
            if Data <> nil then
              XFree(Data);
            Data := nil;
          end;
       end;
    end;
  end;
end;

function TGtk2WidgetSet.X11GetActiveWindow: HWND;
var
  Display: PDisplay;
  RootWin, ResultWindow: TWindow;
  WMAtom: TAtom;
  ActualTypeReturn: TAtom;
  ActualFormatReturn: LongInt;
  NItemsReturn, BytesAfterReturn: Cardinal;
  Ptr: PByte;
  Valid: Boolean;
begin
  Result := 0;

  Display := gdk_x11_get_default_xdisplay;

  if Display = nil then Exit;

  RootWin := gdk_x11_get_default_root_xwindow;
  WMAtom := XInternAtom(Display,'_NET_ACTIVE_WINDOW', False);
  Valid:=XGetWindowProperty(Display, RootWin, WMAtom, 0, 1, False,
                                 AnyPropertyType, @ActualTypeReturn,
                                 @ActualFormatReturn, @NItemsReturn,
                                 @BytesAfterReturn, @Ptr)=0;
  if Valid then
  try
    if (ActualTypeReturn = None) or (ActualFormatReturn <> 32) or not Assigned(Ptr) then
      Valid := False;
    if Valid then ResultWindow := PWindow(Ptr)^;
  finally
    if Assigned(Ptr) then XFree(Ptr);
  end;

  if Valid then Result := {%H-}HWND(gdk_window_foreign_new(ResultWindow));
end;

function TGtk2WidgetSet.GetAlwaysOnTopX11(AWindow: PGdkWindow): boolean;
var
  Display: PDisplay;
  X11Window: TWindow;
  WMAtom: TAtom;
  typeReturned: TAtom;
  formatReturned: Integer;
  nitemsReturned: PtrInt;
  unused: PtrInt;
  data: Pointer;
begin
  Result := False;
  Display := gdk_x11_get_default_xdisplay;
  if Display = nil then
    exit;
  X11Window := gdk_x11_drawable_get_xid(PGdkDrawable(AWindow));
  if X11Window = 0 then
    exit;
  WMAtom := XInternAtom(Display,'_NET_WM_STATE', False);
  if WMAtom > 0 then
  begin
    data := nil;
    if XGetWindowProperty(Display, X11Window, WMAtom, 0, 1024, False, XA_ATOM,
      @typeReturned, @formatReturned, @nitemsReturned,
      @unused, @data) = Success then
    begin
      if (typeReturned = XA_ATOM) and (formatReturned = 32) and
        (Data <> nil) then
      begin
        while nitemsReturned > 0 do
        begin
          // make happy ancient x11 or old kde ?
          if XInternAtom(Display,'_NET_WM_STATE_STAYS_ON_TOP', False) = TAtom(Data^) then
            Result := True
          else
          if XInternAtom(Display,'_NET_WM_STATE_ABOVE', False) = TAtom(Data^) then
            Result := True;
          dec(nItemsReturned);
          if Result or (nItemsReturned = 0) then
            break;
          inc(Data);
        end;
        if nitemsReturned > 0 then
          XFree(Data);
        Data := nil;
      end;
    end;
  end;
end;

procedure TGtk2WidgetSet.HideAllHints;
var
  TopList, List: PGList;
  Window: PGTKWindow;
begin
  TopList := gdk_window_get_toplevels;
  List := TopList;
  while List <> nil do
  begin
    if (List^.Data <> nil) then
    begin
      gdk_window_get_user_data(PGDKWindow(List^.Data), Pgpointer(@Window));
      if GDK_IS_WINDOW(PGDKWindow(List^.Data)) then
      begin
        if gtk_is_window(Window) then
        begin
          if g_object_get_data(PGObject(Window),'lclhintwindow') <> nil then
          begin
            if gdk_window_is_visible(PGDKWindow(List^.Data)) then
            begin
              g_object_set_data(PGObject(Window),'lclneedrestorevisible',Pointer(1));
              gdk_window_hide(PGDKWindow(List^.Data));
            end;
          end;
        end;
      end;
    end;
    list := g_list_next(list);
  end;
  if TopList <> nil then
    g_list_free(TopList);
end;

procedure TGtk2WidgetSet.RestoreAllHints;
var
  TopList, List: PGList;
  Window: PGTKWindow;
begin
  TopList := gdk_window_get_toplevels;
  List := TopList;
  while List <> nil do
  begin
    if (List^.Data <> nil) then
    begin
      gdk_window_get_user_data(PGDKWindow(List^.Data), Pgpointer(@Window));
      if GDK_IS_WINDOW(PGDKWindow(List^.Data)) then
      begin
        if gtk_is_window(Window) then
        begin
          if g_object_get_data(PGObject(Window),'lclhintwindow') <> nil then
          begin
            if g_object_get_data(PGObject(Window),'lclneedrestorevisible') <> nil then
            begin
              g_object_set_data(PGObject(Window),'lclneedrestorevisible', nil);
              gdk_window_show(PGDKWindow(List^.Data));
            end;
          end;
        end;
      end;
    end;
    list := g_list_next(list);
  end;
  if TopList <> nil then
    g_list_free(TopList);
end;

function TGtk2WidgetSet.compositeManagerRunning: Boolean;
var
  XDisplay: PDisplay;
  WMAtom: TAtom;
begin
  Result := False;
  // who's running such old composition manager ?
  if (gtk_major_version = 2) and (gtk_minor_version < 10) then
    exit;
  XDisplay := gdk_display;
  WMAtom := XInternAtom(XDisplay,'_NET_WM_CM_S0', False);
  if WMAtom > 0 then
    Result := XGetSelectionOwner(XDisplay, WMAtom) <> 0;
end;

{$ENDIF}
{------------------------------------------------------------------------------
  procedure TGtk2WidgetSet.BringFormToFront(Sender: TObject);
------------------------------------------------------------------------------}
procedure TGtk2WidgetSet.BringFormToFront(Sender: TObject);
var
  AWindow: PGdkWindow;
  Widget: PGtkWidget;
begin
  Widget := {%H-}PgtkWidget(TCustomForm(Sender).Handle);
  AWindow:=GetControlWindow(Widget);
  if AWindow<>nil then begin
    gdk_window_raise(AWindow);
  end;
end;

{------------------------------------------------------------------------------
  Method: TGtk2WidgetSet.ResizeChild

  Params:  sender - the object which invoked this function
           Left,Top,Width,Height - new dimensions for the control
  Returns: Nothing

  *Note: Resize a child widget on the parents fixed widget
 ------------------------------------------------------------------------------}
procedure TGtk2WidgetSet.ResizeChild(Sender : TObject;
  Left, Top, Width, Height : Integer);
var
  LCLControl: TWinControl;
begin
  //DebugLn('[TGtk2WidgetSet.ResizeChild] START ',TControl(Sender).Name,':',Sender.Classname,' Left=',Left,' Top=',Top,' Width=',Width,' Height=',Height);
  //DebugLn((Format('trace:  [TGtk2WidgetSet.ResizeChild] %s --> Resize', [Sender.ClassNAme])));

  if Sender is TWinControl then begin
    LCLControl:=TWinControl(Sender);
    if LCLControl.HandleAllocated then begin
      ResizeHandle(LCLControl);
      //if (Sender is TCustomForm) then
      //if CompareText(Sender.ClassName,'TScrollBar')=0 then
      //  DebugLn(' FFF ResizeChild ',Sender.ClassName,' ',Left,',',Top,',',Width,',',Height);
    end;
  end;
  //DebugLn('[TGtk2WidgetSet.ResizeChild] END ',Sender.Classname,' Left=',Left,' Top=',Top,' Width=',Width,' Height=',Height);
end;

procedure TGtk2WidgetSet.SetCallbackDirect(const AMsg: LongInt;
  const AGTKObject: PGTKObject; const ALCLObject: TObject);
begin
  SetCallbackEx(AMsg,AGTKObject,ALCLObject,true);
end;

procedure TGtk2WidgetSet.SetCallback(const AMsg: LongInt;
  const AGTKObject: PGTKObject; const ALCLObject: TObject);
begin
  SetCallbackEx(AMsg,AGTKObject,ALCLObject,false);
end;

{------------------------------------------------------------------------------
  Function: TGtk2WidgetSet.RemoveCallBacks
  Params:   Widget
  Returns:  nothing

  Removes Call Back Signals from the Widget
 ------------------------------------------------------------------------------}
procedure TGtk2WidgetSet.RemoveCallbacks(Widget: PGtkWidget);
var
  Info: PWinWidgetInfo;
begin
  if Widget = nil then Exit;
  Info := GetWidgetInfo(Widget);
  if Info <> nil then
    g_signal_handlers_disconnect_matched(Widget, G_SIGNAL_MATCH_DATA, 0, 0, nil, nil, Info);
end;

{-------------------------------------------------------------------------------
  TGtk2WidgetSet.DestroyLCLComponent
  Params: Sender: TObject

  Destroy the widget and all associated data
-------------------------------------------------------------------------------}
procedure TGtk2WidgetSet.DestroyLCLComponent(Sender : TObject);
var
  handle: hwnd; // handle of sender
  Widget: PGtkWidget;
  GtkWindow: PGtkWidget;
begin
  Handle := HWnd({%H-}PtrUInt(ObjectToGtkObject(Sender)));
  if Handle=0 then exit;
  Widget:={%H-}PGtkWidget(Handle);
  if WidgetIsDestroyingHandle(Widget) then exit;
  SetWidgetIsDestroyingHandle(Widget);

  //DebugLn('TGtk2WidgetSet.DestroyLCLComponent A ',GetWidgetClassName(Widget));

  // if one of its widgets has the focus then unfocus
  GtkWindow:=gtk_widget_get_toplevel(Widget);
  if GtkWidgetIsA(GtkWindow,GTK_TYPE_WINDOW)
  and (GetNearestLCLObject(PGtkWindow(GtkWindow)^.Focus_Widget)=Sender)
  then
    gtk_window_set_focus(PGtkWindow(GtkWindow),nil);

  if Sender is TCommonDialog then
    DestroyCommonDialogAddOns(TCommonDialog(Sender));

  if GTK_IS_ENTRY(Widget) then
    g_idle_remove_by_data(Widget);

  // destroy widget and properties
  DestroyConnectedWidget(Widget,false);

  // clean up unneeded containers
  if Sender is TMenuItem then
    DestroyEmptySubmenu(TMenuItem(Sender));

  // mouse click messages
  if LastMouse.WinControl=Sender then
    LastMouse.Button := 0;
end;

procedure TGtk2WidgetSet.FinishCreateHandle(const AWinControl: TWinControl;
  Widget: PGtkWidget; const AParams: TCreateParams);
var
  WidgetInfo: PWidgetInfo;
  Allocation: TGTKAllocation;
begin
  WidgetInfo := GetOrCreateWidgetInfo(Widget); // Widget info already created in CreateAPIWidget
  WidgetInfo^.LCLObject := AWinControl;
  WidgetInfo^.Style := AParams.Style;
  WidgetInfo^.ExStyle := AParams.ExStyle;
  WidgetInfo^.WndProc := {%H-}PtrUInt(AParams.WindowClass.lpfnWndProc);

  // set allocation
  Allocation.X := AParams.X;
  Allocation.Y := AParams.Y;
  Allocation.Width := AParams.Width;
  Allocation.Height := AParams.Height;
  gtk_widget_size_allocate(Widget, @Allocation);

  Set_RC_Name(AWinControl, Widget);
  TGtk2WSWinControl.SetCallbacks(PGtkObject(Widget), AWinControl);
end;

procedure TGtk2WidgetSet.DestroyConnectedWidget(Widget: PGtkWidget;
  CheckIfDestroying: boolean);
var
  FixWidget: PGtkWidget;
  QueueItem : TGtkMessageQueueItem;
  NextItem  : TGtkMessageQueueItem;
  MsgPtr: PMsg;
begin
  if CheckIfDestroying then begin
    if WidgetIsDestroyingHandle(Widget) then exit;
    SetWidgetIsDestroyingHandle(Widget);
  end;

  FixWidget:=GetFixedWidget(Widget);

  //DebugLn('TGtk2WidgetSet.DestroyLCLComponent B  Widget=',GetWidgetDebugReport(Widget));
  ClearAccelKey(Widget);

  // untransient
  if GtkWidgetIsA(Widget,GTK_TYPE_WINDOW) then
    UntransientWindow(PGtkWindow(Widget));

  // callbacks
  RemoveCallbacks(Widget);

  // update mouse capturing
  if (MouseCaptureWidget=Widget) or (MouseCaptureWidget=FixWidget) then
    MouseCaptureWidget:=nil;

  // update clipboard widget
  if (ClipboardWidget=Widget) or (ClipboardWidget=FixWidget) then
  begin
    // clipboard widget destroyed
    if (Application<>nil) and (Application.MainForm<>nil)
    and (Application.MainForm.HandleAllocated)
    and ({%H-}PGtkWidget(Application.MainForm.Handle)<>Widget) then
      // there is still the main form left -> use it for clipboard
      SetClipboardWidget({%H-}PGtkWidget(Application.MainForm.Handle))
    else
      // program closed -> close clipboard
      SetClipboardWidget(nil);
  end;

  // update caret
  if GtkWidgetIsA(Widget,GTKAPIWidget_GetType) then
    DestroyCaret(HDC({%H-}PtrUInt(Widget)));

  // remove pending size messages
  UnsetResizeRequest(Widget);
  FWidgetsResized.Remove(Widget);
  if FixWidget<>Widget then
    FFixWidgetsResized.Remove(FixWidget);

  // destroy the widget
  //DebugLn(['TGtk2WidgetSet.DestroyConnectedWidget ',GetWidgetDebugReport(Widget)]);
  DestroyWidget(Widget);

  // remove all remaining messages to this widget
  fMessageQueue.Lock;
  try
    QueueItem:=FMessageQueue.FirstMessageItem;
    while (QueueItem<>nil) do begin
      MsgPtr := QueueItem.Msg;
      NextItem := TGtkMessagequeueItem(QueueItem.Next);
      if ({%H-}PGtkWidget(MsgPtr^.hWnd)=Widget) then
        fMessageQueue.RemoveMessage(QueueItem,FPMF_All,true);
      QueueItem := NextItem;
    end;
  finally
    fMessageQueue.UnLock;
  end;
end;

function TGtk2WidgetSet.GetCompStyle(Sender : TObject) : Longint;
begin
  Result := csNone;
  if (Sender is TControl) then
    Result := TControl(Sender).FCompStyle
  else
    if (Sender is TMenuItem) then
      Result := TMenuItem(Sender).FCompStyle
  else
    if (Sender is TMenu) or (Sender is TPopupMenu)
    then
      Result := TMenu(Sender).FCompStyle
  else
    if (Sender is TCommonDialog)
    then
      result := TCommonDialog(Sender).FCompStyle;
end;

function TGtk2WidgetSet.GetCaption(Sender : TObject) : String;
begin
  Result := Sender.ClassName;
  if (Sender is TControl) then
    Result := TControl(Sender).Caption
  else
    if (Sender is TMenuItem) then
      Result := TMenuItem(Sender).Caption;

  if Result = '' then
    Result := rsBlank;
end;

function TGtk2WidgetSet.CreateAPIWidget(AWinControl: TWinControl): PGtkWidget;
// currently only used for csFixed
var
  Adjustment: PGTKAdjustment;
  WinWidgetInfo: PWinWidgetInfo;
begin
  Result := GTKAPIWidget_New;
  WinWidgetInfo := GetOrCreateWidgetInfo(Result);
  WinWidgetInfo^.CoreWidget := PGTKAPIWidget(Result)^.Client;
  WinWidgetInfo^.LCLObject := AWinControl;

  gtk_scrolled_window_set_policy(PGTKScrolledWindow(Result),
    GTK_POLICY_NEVER, GTK_POLICY_NEVER);

  Adjustment := gtk_scrolled_window_get_vadjustment(PGTKScrolledWindow(Result));
  if Adjustment <> nil
  then with Adjustment^ do
  begin
    g_object_set_data(PGObject(Adjustment), odnScrollBar,
                      PGTKScrolledWindow(Result)^.VScrollBar);
    Step_Increment := 1;
  end;

  Adjustment := gtk_scrolled_window_get_hadjustment(PGTKScrolledWindow(Result));
  if Adjustment <> nil
  then with Adjustment^ do
  begin
    g_object_set_data(PGObject(Adjustment), odnScrollBar,
                      PGTKScrolledWindow(Result)^.HScrollBar);
    Step_Increment := 1;
  end;

  if AWinControl is TCustomControl then
    GTKAPIWidget_SetShadowType(PGTKAPIWidget(Result),
      BorderStyleShadowMap[TCustomControl(AWinControl).BorderStyle]);
end;

{------------------------------------------------------------------------------
  function TGtk2WidgetSet.CreateSimpleClientAreaWidget(Sender: TObject;
    NotOnParentsClientArea: boolean): PGtkWidget;

  Create a fixed widget in a horizontal box
 ------------------------------------------------------------------------------}
function TGtk2WidgetSet.CreateSimpleClientAreaWidget(Sender: TObject;
  NotOnParentsClientArea: boolean): PGtkWidget;
var
  TempWidget: PGtkWidget;
  WinWidgetInfo: PWinWidgetInfo;
begin
  {$ifdef GtkFixedWithWindow}
  // Fixed + GdkWindow
  Result := gtk_hbox_new(false, 0);
  TempWidget := CreateFixedClientWidget;
  {$else}
  // Fixed w/o GdkWindow
  Result := gtk_event_box_new;
  { MG: Normally the event box should be made invisible as suggested
    here: http://library.gnome.org/devel/gtk/stable/GtkEventBox.html#gtk-event-box-set-visible-window
    But is has a sideeffect:
    Sometimes the mouse events for gtk widgets without window don't get any
    mouse events any longer.
    For example: Add a PageControl (Page3, Page4) into a PageControl (Page1,Page2).
    Start program. Click on Page2, which hides the inner PageControl. Then
    click to return to Page1. Now the inner PageControl does no longer
    receive mouse events and so you can not switch between Page3 and Page4.}
  // MG: disabled: gtk_event_box_set_visible_window(PGtkEventBox(Result), False);
  TempWidget := CreateFixedClientWidget(False);
  {$endif}

  gtk_container_add(GTK_CONTAINER(Result), TempWidget);
  gtk_widget_show(TempWidget);
  if NotOnParentsClientArea then
  begin
    WinWidgetInfo:=GetOrCreateWidgetInfo(Result);
    Include(WinWidgetInfo^.Flags, wwiNotOnParentsClientArea);
  end;
  SetFixedWidget(Result, TempWidget);
  SetMainWidget(Result, TempWidget);

  // MG: should fix the invisible event box, but does not:
  // gtk_widget_add_events (PGtkWidget(Result), GDK_BUTTON_PRESS_MASK);

  gtk_widget_show(Result);
end;

function TGtk2WidgetSet.CreateStandardCursor(ACursor: SmallInt): hCursor;
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
    Result := hCursor({%H-}PtrUInt(gdk_cursor_new(CursorValue)));
end;

{------------------------------------------------------------------------------
  procedure TGtk2WidgetSet.DestroyEmptySubmenu(Sender: TObject);

  Used by DestroyLCLComponent to destroy empty submenus, when destroying the
  last menu item.
------------------------------------------------------------------------------}
procedure TGtk2WidgetSet.DestroyEmptySubmenu(Sender: TObject);
var
  LCLMenuItem: TMenuItem;
  ParentLCLMenuItem: TMenuItem;
  ParentMenuWidget: PGtkWidget;
  ParentSubMenuWidget: PGtkWidget;
  SubMenuWidget: PGtkMenu;
begin
  if not (Sender is TMenuItem) then
    RaiseGDBException('TGtk2WidgetSet.DestroyEmptySubmenu');
  // destroying a TMenuItem
  LCLMenuItem:=TMenuItem(Sender);
  // check if in a sub menu
  if (LCLMenuItem.Parent=nil) then exit;
  if not (LCLMenuItem.Parent is TMenuItem) then exit;
  ParentLCLMenuItem:=TMenuItem(LCLMenuItem.Parent);
  if not ParentLCLMenuItem.HandleAllocated then exit;
  ParentMenuWidget:={%H-}PGtkWidget(ParentLCLMenuItem.Handle);
  if not GtkWidgetIsA(ParentMenuWidget,GTK_TYPE_MENU_ITEM) then exit;
  ParentSubMenuWidget:=PGTKMenuItem(ParentMenuWidget)^.submenu;
  if not GtkWidgetIsA(ParentSubMenuWidget,GTK_TYPE_MENU) then exit;
  SubMenuWidget:=PGTKMenu(ParentSubMenuWidget);
  if SubMenuWidget^.menu_shell.children=nil then begin
    gtk_widget_destroy(PgtkWidget(SubMenuWidget));
    g_object_set_data(PGObject(ParentMenuWidget),'ContainerMenu',nil);
  end;
end;

{------------------------------------------------------------------------------
       TGtkWidgetSet ShowHide
       *Note: Show or hide a widget
------------------------------------------------------------------------------}
{$IFDEF VerboseGtkToDos}{$note TODO: move to wsclass }{$ENDIF}
procedure TGtk2WidgetSet.SetVisible(Sender: TObject; const AVisible: Boolean);

  procedure RaiseWrongClass;
  begin
    RaiseGDBException('TGtk2WidgetSet.ShowHide Sender.ClassName='+Sender.ClassName);
  end;

var
  SenderWidget: PGTKWidget;
  LCLControl: TWinControl;
  Decor, Func : Longint;
  AWindow: PGdkWindow;
  ACustomForm: TCustomForm;
  CurWindowState: TWindowState;
  WidgetInfo: PWidgetInfo;
begin
  if not (Sender is TWinControl) then
    RaiseWrongClass;
  if (Sender is TCustomForm) then
    ACustomForm := TCustomForm(Sender)
  else
    ACustomForm := nil;

  LCLControl:=TWinControl(Sender);
  if not LCLControl.HandleAllocated then exit;
  SenderWidget:={%H-}PgtkWidget(LCLControl.Handle);
  //if (Sender is TForm) and (Sender.ClassName='TForm1') then
  //  DebugLn('[TGtk2WidgetSet.ShowHide] START ',TControl(Sender).Name,':',Sender.ClassName,
  //    ' Visible=',TControl(Sender).Visible,' GtkVisible=',gtk_widget_visible(SenderWidget),
  //    ' GtkRealized=',gtk_widget_realized(SenderWidget),
  //    ' GtkMapped=',gtk_widget_mapped(SenderWidget),
  //    ' Should=',AVisible                           );
  if AVisible then
  begin
    if (ACustomForm<>nil) and (ACustomForm.Parent=nil) then begin
      // update shared accelerators
      ShareWindowAccelGroups(SenderWidget);
    end;

    // before making the widget visible, set the position and size
    // this is not possible for windows - for windows position will be set
    // after widget become visible
    if FWidgetsWithResizeRequest.Contains(SenderWidget) then
    begin
      if (ACustomForm<>nil) and (ACustomForm.Parent=nil) then
      begin
        // top level control (a form without parent)
        {$IFDEF VerboseFormPositioning}
        DebugLn('VFP [TGtk2WidgetSet.ShowHide] A set bounds ',
          LCLControl.Name,':',LCLControl.ClassName,
          ' Window=',dbgs(GetControlWindow(SenderWidget)<>nil),
          ' ',dbgs(LCLControl.Left),',',dbgs(LCLControl.Top),
          ',',dbgs(LCLControl.Width),',',dbgs(LCLControl.Height));
        {$ENDIF}
        SetWindowSizeAndPosition(PgtkWindow(SenderWidget),LCLControl);
      end
      else
      if (LCLControl.Parent<>nil) then
      begin
        // resize widget
        {$IFDEF VerboseSizeMsg}
        DebugLn(['TGtk2WidgetSet.ShowHide ',DbgSName(LCLControl)]);
        {$ENDIF}
        SetWidgetSizeAndPosition(LCLControl);
      end;
    {$ifndef windows}
      UnsetResizeRequest(SenderWidget);
    {$endif}
    end;

    if (ACustomForm<>nil) and (ACustomForm.Parent=nil) then
    begin
      If (ACustomForm.BorderStyle <> bsSizeable) or
        ((ACustomForm.FormStyle in fsAllStayOnTop)
         and (not (csDesigning in ACustomForm.ComponentState)))
      then begin
        Decor := GetWindowDecorations(ACustomForm);
        Func := GetWindowFunction(ACustomForm);
        gtk_widget_realize(SenderWidget);
        AWindow:=GetControlWindow(SenderWidget);
        gdk_window_set_decorations(AWindow, decor);
        gdk_window_set_functions(AWindow, func);
      end;
      ShareWindowAccelGroups(SenderWidget);

      // capturing is always gtkwindow dependent. On showing a new window
      // the gtk will put a new widget on the grab stack.
      // -> release our capture
      if not ACustomForm.ClassNameIs('TDockImageWindow') then
        ReleaseMouseCapture;
    end;

    if gtk_widget_visible(SenderWidget) then
      exit;

    gtk_widget_show(SenderWidget);

    if (ACustomForm <> nil) and
       (ACustomForm.Parent = nil) and
       (ACustomForm.ParentWindow = 0) then
    begin
      CurWindowState:=ACustomForm.WindowState;
      if csDesigning in ACustomForm.ComponentState then
        CurWindowState:=wsNormal;
      case CurWindowState of
        wsNormal:
        begin
          WidgetInfo := GetWidgetInfo(SenderWidget);
          with WidgetInfo^.FormWindowState do
          begin
            if new_window_state and GDK_WINDOW_STATE_ICONIFIED <> 0 then
              gtk_window_deiconify(PGtkWindow(SenderWidget));
            if (new_window_state and GDK_WINDOW_STATE_MAXIMIZED <> 0) or
              (new_window_state and GDK_WINDOW_STATE_FULLSCREEN <> 0) then
                gtk_window_unmaximize(PGtkWindow(SenderWidget));
          end;
        end;
        wsMaximized: gtk_window_maximize(PGtkWindow(SenderWidget));
        wsMinimized: gtk_window_iconify(PGtkWindow(SenderWidget));
      end;
    end;
  end
  else begin
    // hide
    if (ACustomForm<>nil) then
      UnshareWindowAccelGroups(SenderWidget);

    if not gtk_widget_visible(SenderWidget) then
      exit;

    // save previous position
    if ACustomForm <> nil then
    begin
      if (ACustomForm is TForm) and
        not (ACustomForm.FormStyle in [fsMDIChild, fsSplash])
        and (ACustomForm.BorderStyle <> bsNone) then
        SetResizeRequest(SenderWidget);
    end;

    gtk_widget_hide(SenderWidget);

    if GtkWidgetIsA(SenderWidget,GTK_TYPE_WINDOW) then begin
      {$IFDEF VerboseTransient}
      DebugLn('TGtk2WidgetSet.ShowHide HIDE ',Sender.ClassName);
      {$ENDIF}
      UntransientWindow(PGtkWindow(SenderWidget));
    end;
  end;

  if GtkWidgetIsA(SenderWidget,GTK_TYPE_WINDOW) then begin
    // make sure when hiding a window, that at least the main window
    // is selectable via the window manager
    if (Application<>nil) and (Application.MainForm<>nil)
    and (Application.MainForm.HandleAllocated) then begin
      SetFormShowInTaskbar(Application.MainForm,stAlways);
    end;
  end;

  //if Sender is TCustomForm then
  //  DebugLn('[TGtk2WidgetSet.ShowHide] END ',Sender.ClassName,' Window=',FormWidget^.Window<>nil);
end;

function TGtk2WidgetSet.DragImageList_BeginDrag(APixmap: PGdkPixmap; AMask: PGdkBitmap; AHotSpot: TPoint): Boolean;
var
  w, h: gint;
begin
  if FDragImageList = nil then
  begin
    FDragImageList := gtk_window_new(GTK_WINDOW_POPUP);
    gdk_drawable_get_size(APixmap, @w, @h);
    gtk_window_set_default_size(PGtkWindow(FDragImageList), w, h);
    gtk_widget_realize(FDragImageList);
    gdk_window_set_decorations(FDragImageList^.window, 0);
    gdk_window_set_functions(FDragImageList^.window, GDK_FUNC_RESIZE or GDK_FUNC_CLOSE);
    FDragImageListIcon := gtk_pixmap_new(APixmap, AMask);
    gtk_container_add(PGtkContainer(FDragImageList), FDragImageListIcon);
    gtk_widget_show(FDragImageListIcon);
    // make window transparent outside mask
    gdk_window_shape_combine_mask(FDragImageList^.window, AMask, 0, 0);
    FDragHotStop := AHotSpot;
  end;
  Result := FDragImageList <> nil;
end;

procedure TGtk2WidgetSet.DragImageList_EndDrag;
begin
  if FDragImageList <> nil then
  begin
    if FDragImageListIcon <> nil then
      gtk_widget_destroy(FDragImageListIcon);
    gtk_widget_destroy(FDragImageList);
    FDragImageList := nil;
  end;
end;

function TGtk2WidgetSet.DragImageList_DragMove(X, Y: Integer): Boolean;
begin
  Result := FDragImageList <> nil;
  if Result then
  begin
    if gdk_window_is_visible(FDragImageList^.Window) then
      gdk_window_raise(FDragImageList^.Window);
    gdk_window_move(FDragImageList^.Window, X - FDragHotStop.X, Y - FDragHotStop.Y);
  end;
end;

function TGtk2WidgetSet.DragImageList_SetVisible(NewVisible: Boolean): Boolean;
begin
  Result := FDragImageList <> nil;
  if Result then
    if NewVisible then
      gtk_widget_show(FDragImageList)
    else
      gtk_widget_hide(FDragImageList);
end;

{-------------------------------------------------------------------------------
  method TGtkWidgetSet LoadPixbufFromLazResource
  Params: const ResourceName: string;
          var Pixbuf: PGdkPixbuf
  Result: none

  Loads a pixbuf from a lazarus resource. The resource must be a XPM file.
-------------------------------------------------------------------------------}
procedure TGtk2WidgetSet.LoadPixbufFromLazResource(const ResourceName: string;
  var Pixbuf: PGdkPixbuf);
var
  ImgData: PPChar;
begin
  Pixbuf:=nil;
  try
    ImgData:=LazResourceXPMToPPChar(ResourceName);
  except
    on e: Exception do
      DebugLn('WARNING: TGtk2WidgetSet.LoadXPMFromLazResource: '+e.Message);
  end;
  {$IFDEF DebugGDK}BeginGDKErrorTrap;{$ENDIF}
  {$IFDEF VerboseGdkPixbuf}
  debugln('LoadPixbufFromLazResource A1');
  {$ENDIF}
  pixbuf:=gdk_pixbuf_new_from_xpm_data(ImgData);
  {$IFDEF VerboseGdkPixbuf}
  debugln('LoadPixbufFromLazResource A2');
  {$ENDIF}
  {$IFDEF DebugGDK}EndGDKErrorTrap;{$ENDIF}
  FreeMem(ImgData);
end;

{------------------------------------------------------------------------------
  Method: TGtk2WidgetSet.SetPixel
  Params:  Sender : the lcl object which called this func via SendMessage
           Data   : pointer to a TLMSetGetPixel record
  Returns: nothing

  Set the color of the specified pixel on the window?screen?object?
 ------------------------------------------------------------------------------}
procedure TGtk2WidgetSet.DCSetPixel(CanvasHandle: HDC; X, Y: integer; AColor: TGraphicsColor);
var
  DC     : TGtkDeviceContext absolute CanvasHandle;
  DCOrigin: TPoint;
  GDKColor: TGDKColor;
begin
  if (DC = nil) or (DC.Drawable = nil) then exit;

  DCOrigin := DC.TransfPointIndirect(DC.Offset);
  inc(X, DCOrigin.X);
  inc(Y, DCOrigin.Y);

  DC.SelectedColors := dcscCustom;
  GDKColor := AllocGDKColor(ColorToRGB(AColor));
  gdk_gc_set_foreground(DC.GC, @GDKColor);
  {$IFDEF DebugGDK}BeginGDKErrorTrap;{$ENDIF}
  gdk_draw_point(DC.Drawable, DC.GC, X, Y);
  {$IFDEF DebugGDK}EndGDKErrorTrap;{$ENDIF}
end;

procedure TGtk2WidgetSet.DCRedraw(CanvasHandle: HDC);
var
  fWindow :pGdkWindow;
  widget : PgtkWIdget;
  PixMap : pgdkPixMap;
  Child: PGtkWidget;
begin
  //DebugLn('Trace:In AutoRedraw in GTKObject');

  Child := {%H-}PgtkWidget(CanvasHandle);
  Widget := GetFixedWidget(Child);
  pixmap := g_object_get_data(pgobject(Child),'Pixmap');
  if PixMap = nil then Exit;
  fWindow := GetControlWindow(widget);

  if fWindow<>nil then begin
    {$IFDEF DebugGDK}BeginGDKErrorTrap;{$ENDIF}
    gdk_draw_pixmap(fwindow,
      gtk_widget_get_style(widget)^.fg_gc[GTK_WIDGET_STATE (widget)],
      pixmap,
      0,0,
      0,0,
      pgtkwidget(widget)^.allocation.width,
      pgtkwidget(widget)^.allocation.height);
    {$IFDEF DebugGDK}EndGDKErrorTrap;{$ENDIF}
  end;
end;

{------------------------------------------------------------------------------
  Method: TGtk2WidgetSet.GetPixel
  Params:  Sender : the lcl object which called this func via SenMessage
           Data   : pointer to a TLMSetGetPixel record
  Returns: nothing

  Get the color of the specified pixel on the window?screen?object?
 ------------------------------------------------------------------------------}
function  TGtk2WidgetSet.DCGetPixel(CanvasHandle: HDC; X, Y: integer): TGraphicsColor;
var
  DC    : TGtkDeviceContext absolute CanvasHandle;
  Image  : pGDKImage;
  GDKColor: TGDKColor;
  Colormap : PGDKColormap;
  DCOrigin: TPoint;
  MaxX, MaxY: integer;
  Pixel: LongWord;
begin
  Result := clNone;
  if (DC = nil) or (DC.Drawable = nil) then Exit;

  DCOrigin := DC.TransfPointIndirect(DC.Offset);
  inc(X, DCOrigin.X);
  inc(Y, DCOrigin.Y);

  gdk_drawable_get_size(DC.Drawable, @MaxX, @MaxY);
  if (X<0) or (Y<0) or (X>=MaxX) or (Y>=MaxY) then exit;

  Image := gdk_drawable_get_image(DC.Drawable,X,Y,1,1);
  if Image = nil then exit;

  colormap := gdk_image_get_colormap(image);
  if colormap = nil then
    colormap := gdk_drawable_get_colormap(DC.Drawable);

  if colormap = nil then
    colormap := gdk_colormap_get_system;

  Pixel:=gdk_image_get_pixel(Image,0,0);
  FillChar(GDKColor{%H-}, SizeOf(GDKColor),0);
  // does not work with TBitmap.Canvas
  gdk_colormap_query_color(colormap, Pixel, @GDKColor);

  gdk_image_unref(Image);

  Result := TGDKColorToTColor(GDKColor);
end;

{ TODO: move this ``LM_GETVALUE'' spinedit code someplace useful

  csSpinEdit :
    Begin
      Single(Data^):=gtk_spin_button_get_value_As_Float(PgtkSpinButton(Handle));
    end;
}

{------------------------------------------------------------------------------
  Function: IsValidDC
  Params:  DC: a (LCL) devicecontext
  Returns: True if valid

  Checks if the given DC is valid.
 ------------------------------------------------------------------------------}
function TGtk2WidgetSet.IsValidDC(const DC: HDC): Boolean;
begin
  Result := FDeviceContexts.Contains({%H-}Pointer(DC));
end;

{------------------------------------------------------------------------------
  Function: IsValidGDIObject
  Params:  GDIObject: a (LCL) gdiObject
  Returns: True if valid

  Checks if the given GDIObject is valid (e.g. known to the gtk interface).
  This is a quick consistency check to avoid working with dangling pointers.
 ------------------------------------------------------------------------------}
function TGtk2WidgetSet.IsValidGDIObject(const AGDIObj: HGDIOBJ): Boolean;
var
  GdiObject: PGdiObject absolute AGDIObj;
begin
  Result := (AGDIObj <> 0) and FGDIObjects.Contains(GDIObject);
end;

{------------------------------------------------------------------------------
  Function: IsValidGDIObjectType
  Params:  GDIObject: a (LCL) gdiObject
           GDIType: the requested type
  Returns: True if valid

  Checks if the given GDIObject is valid and the GDItype is the requested type
 ------------------------------------------------------------------------------}
function TGtk2WidgetSet.IsValidGDIObjectType(
  const GDIObject: HGDIOBJ; const GDIType: TGDIType): Boolean;
begin
  Result := IsValidGDIObject(GDIObject)
            and ({%H-}PGdiObject(GDIObject)^.GDIType = GDIType);
end;


procedure TGtk2WidgetSet.DCSetAntialiasing(CanvasHandle: HDC; AEnabled: Boolean
  );
var
  DC: TGtkDeviceContext;
begin
  if IsValidDC(CanvasHandle) then
  begin
    //if CanvasHandle = 1 then
      //DC := Gtk2DefaultContext
    //else
      DC := TGtkDeviceContext(CanvasHandle);
    DC.Antialiasing := AEnabled;
  end;
end;


{------------------------------------------------------------------------------
  Function: NewDC
  Params:  none
  Returns: a gtkwinapi DeviceContext

  Creates a raw DC and adds it to FDeviceContexts.

  Used internally by: CreateCompatibleDC, CreateDCForWidget and SaveDC
 ------------------------------------------------------------------------------}
function TGtk2WidgetSet.NewDC: TGtkDeviceContext;
begin
  //DebugLn(Format('Trace:> [TGtk2WidgetSet.NewDC]', []));

  if FDCManager = nil
  then begin
    FDCManager := TDeviceContextMemManager.Create(TGtkDeviceContext);
    FDCManager.MinimumFreeCount := 1000;
  end;
  Result := FDCManager.NewDeviceContext;
  {$IFDEF DebugLCLComponents}
  DebugDeviceContexts.MarkCreated(Result,'TGtk2WidgetSet.NewDC');
  {$ENDIF}

  FDeviceContexts.Add(Result);

  {$ifdef TraceGdiCalls}
  FillStackAddrs(get_caller_frame(get_frame), @Result.StackAddrs);
  {$endif}
  //DebugLn(['[TGtk2WidgetSet.NewDC] ',DbgS(Result),'  ',FDeviceContexts.Count]);
  //DebugLn(Format('Trace:< [TGtk2WidgetSet.NewDC] FDeviceContexts[%d] --> 0x%p', [n, Result]));
end;

function TGtk2WidgetSet.FindDCWithGDIObject(GDIObject: PGdiObject
  ): TGtkDeviceContext;
var
  HashItem: PDynHashArrayItem;
  DC: TGtkDeviceContext;
  g: TGDIType;
  Cnt: Integer;
begin
  Result:=nil;
  if GdiObject=nil then exit;
  HashItem:=FDeviceContexts.FirstHashItem;
  Cnt:=0;
  while HashItem<>nil do begin
    DC:=TGtkDeviceContext(HashItem^.Item);
    for g:=Low(TGDIType) to High(TGDIType) do
      if DC.GDIObjects[g]=GdiObject then exit(DC);
    inc(Cnt);
    HashItem:=HashItem^.Next;
  end;
  if Cnt<>FDeviceContexts.Count then
    RaiseGDBException('');
end;

{------------------------------------------------------------------------------
  procedure TGtk2WidgetSet.DisposeDC(DC: PDeviceContext);

  Disposes a DC
 ------------------------------------------------------------------------------}
procedure TGtk2WidgetSet.DisposeDC(aDC: TGtkDeviceContext);
begin
  if not FDeviceContexts.Contains(aDC) then Exit;

  FDeviceContexts.Remove(aDC);

  {$IFDEF DebugLCLComponents}
  DebugDeviceContexts.MarkDestroyed(ADC);
  {$ENDIF}
  FDCManager.DisposeDeviceContext(ADC);
end;

{------------------------------------------------------------------------------
  function TGtk2WidgetSet.CreateDCForWidget(TheWidget: PGtkWidget;
    TheWindow: PGdkWindow; WithChildWindows: boolean): HDC;

  Creates an initial DC
 ------------------------------------------------------------------------------}
function TGtk2WidgetSet.CreateDCForWidget(AWidget: PGtkWidget;
  AWindow: PGdkWindow; AWithChildWindows: Boolean; ADoubleBuffer: PgdkDrawable
  ): HDC;
var
  DC: TGtkDeviceContext absolute Result;
begin
  DC := NewDC;
  DC.SetWidget(AWidget, AWindow, AWithChildWindows, ADoubleBuffer);
end;

{------------------------------------------------------------------------------
  Function: NewGDIObject
  Params:  none
  Returns: a gtkwinapi DeviceContext

  Creates an initial GDIObject of GDIType.
 ------------------------------------------------------------------------------}
function TGtk2WidgetSet.NewGDIObject(const GDIType: TGDIType): PGdiObject;
begin
  //DebugLn(Format('Trace:> [TGtk2WidgetSet.NewGDIObject]', []));
  Result:=Gtk2Def.InternalNewPGDIObject;
  {$ifdef TraceGdiCalls}
  FillStackAddrs(get_caller_frame(get_frame), @Result^.StackAddrs);
  {$endif}
  Result^.GDIType := GDIType;
  Result^.Shared := False;
  inc(Result^.RefCount);
  FGDIObjects.Add(Result);
  //DebugLn('[TGtk2WidgetSet.NewGDIObject] ',DbgS(Result),'  ',FGDIObjects.Count);
  //DebugLn(Format('Trace:< [TGtk2WidgetSet.NewGDIObject] FGDIObjects --> 0x%p', [Result]));
end;

{------------------------------------------------------------------------------
  Function: NewGDIObject
  Params:  GdiObject: PGdiObject
  Returns: none

  Dispose a GdiObject
 ------------------------------------------------------------------------------}
procedure TGtk2WidgetSet.DisposeGDIObject(GdiObject: PGdiObject);
begin
  if FGDIObjects.Contains(GDIObject) then
  begin
    FGDIObjects.Remove(GDIObject);
    Gtk2Def.InternalDisposePGDIObject(GDIObject);
  end
  else
    RaiseGDBException('');
end;

function TGtk2WidgetSet.ReleaseGDIObject(GdiObject: PGdiObject): boolean;

  procedure RaiseGDIObjectIsStillUsed;
  var
    CurGDIObject: PGDIObject;
    DC: TGtkDeviceContext;
  begin
    {$ifdef TraceGdiCalls}
    DebugLn();
    DebugLn('TGtk2WidgetSet.ReleaseGDIObject: TraceCall for still used object: ');
    DumpBackTrace(PgdiObject(GdiObject)^.StackAddrs);
    DebugLn();
    DebugLn('Exception will follow:');
    DebugLn();
    {$endif}
    // do not raise an exception, because this is a common bug in many programs
    // just give a warning
    CurGDIObject:=PGdiObject(GdiObject);
    debugln('TGtk2WidgetSet.ReleaseGDIObject GdiObject='+dbgs(CurGDIObject)
       +' '+dbgs(CurGDIObject^.GDIType)
       +' is still used. DCCount='+dbgs(CurGDIObject^.DCCount));
    DC:=FindDCWithGDIObject(CurGDIObject);
    if DC<>nil then begin
      DebugLn(['DC: ',dbgs(Pointer(DC)),' ',
        GetWidgetDebugReport(DC.Widget)]);
    end else begin
      DebugLn(['No DC found with this GDIObject => either the DCCount is wrong or the DC is not in the DC list']);
    end;
    //DumpStack;
    //RaiseGDBException('');
  end;

  procedure RaiseInvalidGDIOwner;
  var
    o: PGDIObject;
  begin
    {$ifdef TraceGdiCalls}
    DebugLn();
    DebugLn('TGtk2WidgetSet.ReleaseGDIObject: TraceCall for invalid object: ');
    DumpBackTrace(PgdiObject(GdiObject)^.StackAddrs);
    DebugLn();
    DebugLn('Exception will follow:');
    DebugLn();
    {$endif}
    o:=PGdiObject(GdiObject);
    RaiseGDBException('TGtk2WidgetSet.ReleaseGDIObject invalid owner of'
      +' GdiObject='+dbgs(o)
      +' Owner='+dbgs(o^.Owner)
      +' Owner.OwnedGDIObjects='+dbgs(o^.Owner.OwnedGDIObjects[o^.GDIType]));
  end;

begin
  if GDIObject = nil then
  begin
    Result := True;
    exit;
  end;
  {$IFDEF DebugLCLComponents}
  if DebugGdiObjects.IsDestroyed(GDIObject) then
  begin
    DebugLn(['TGtk2WidgetSet.ReleaseGDIObject object already deleted ',GDIObject]);
    debugln(DebugGdiObjects.GetInfo(GDIObject,true));
    Halt;
  end;
  {$ENDIF}

  with PGdiObject(GDIObject)^ do
  begin
    dec(RefCount);
    if (RefCount > 0) or Shared then
    begin
      Result := True;
      exit;
    end;
    if DCCount > 0 then
    begin
      RaiseGDIObjectIsStillUsed;
      exit(False);
    end;

    if Owner <> nil then
    begin
      if Owner.OwnedGDIObjects[GDIType] <> PGdiObject(GDIObject) then
        RaiseInvalidGDIOwner;
      Owner.OwnedGDIObjects[GDIType] := nil;
    end;

    case GDIType of
      gdiFont:
        begin
          if GDIFontObject <> nil then
          begin
            //DebugLn(['TGtk2WidgetSet.DeleteObject GDIObject=',dbgs(Pointer(PtrInt(GDIObject))),' GDIFontObject=',dbgs(GDIFontObject)]);
            FontCache.Unreference(GDIFontObject);
          end;
        end;
      gdiBrush:
        begin
          {$IFDEF DebugGDKTraps}
          BeginGDKErrorTrap;
          {$ENDIF}
          {$IFDEF DebugGDIBrush}
          debugln('TGtk2WidgetSet.DeleteObject gdiBrush: ',DbgS(GdiObject));
          //if Cardinal(GdiObject)=$404826F4 then RaiseGDBException('');
          {$ENDIF}
          if (GDIBrushPixmap <> nil) then
            gdk_pixmap_unref(GDIBrushPixmap);
          {$IFDEF DebugGDKTraps}
          EndGDKErrorTrap;
          {$ENDIF}

          FreeGDIColor(@GDIBrushColor);
        end;
      gdiBitmap:
        begin
          {$IFDEF DebugGDKTraps}
          BeginGDKErrorTrap;
          {$ENDIF}
          case GDIBitmapType of
            gbBitmap:
              begin
                if GDIBitmapObject <> nil then
                  gdk_bitmap_unref(GDIBitmapObject);
              end;
            gbPixmap:
              begin
                if GDIPixmapObject.Image <> nil then
                  gdk_pixmap_unref(GDIPixmapObject.Image);
                if GDIPixmapObject.Mask <> nil then
                  gdk_bitmap_unref(GDIPixmapObject.Mask);
              end;
              gbPixbuf:
                begin
                  if GDIPixbufObject <> nil then
                    gdk_pixbuf_unref(GDIPixbufObject);
                end;
          end;

          if (Visual <> nil) and (not SystemVisual) then
            gdk_visual_unref(Visual);
          if Colormap <> nil then
            gdk_colormap_unref(Colormap);
          {$IFDEF DebugGDKTraps}
          EndGDKErrorTrap;
          {$ENDIF}
        end;
      gdiPen:
        begin
          FreeGDIColor(@GDIPenColor);
          FreeMem(GDIPenDashes);
        end;
      gdiRegion:
        begin
          if (GDIRegionObject <> nil) then
            gdk_region_destroy(GDIRegionObject);
        end;
      gdiPalette:
        begin
          {$IFDEF DebugGDKTraps}
          BeginGDKErrorTrap;
          {$ENDIF}
          If PaletteVisual <> nil then
            gdk_visual_unref(PaletteVisual);
          If PaletteColormap <> nil then
            gdk_colormap_unref(PaletteColormap);
          {$IFDEF DebugGDKTraps}
          EndGDKErrorTrap;
          {$ENDIF}

          FreeAndNil(RGBTable);
          FreeAndNil(IndexTable);
        end;
      else begin
        Result:= false;
        DebugLn('[TGtk2WidgetSet.DeleteObject] TODO : Unimplemented GDI type');
        //DebugLn('Trace:TODO : Unimplemented GDI object in delete object');
      end;
    end;
  end;

  { Dispose of the GDI object }
  //DebugLn('[TGtk2WidgetSet.DeleteObject] ',Result,'  ',DbgS(GDIObject,8),'  ',FGDIObjects.Count);
  DisposeGDIObject(PGDIObject(GDIObject));
end;

procedure TGtk2WidgetSet.ReferenceGDIObject(GdiObject: PGdiObject);
begin
  inc(GdiObject^.RefCount);
end;

{------------------------------------------------------------------------------
  Function: CreateDefaultBrush
  Params:  none
  Returns: a Brush GDIObject

  Creates an default brush, used for initial values
 ------------------------------------------------------------------------------}
function TGtk2WidgetSet.CreateDefaultBrush: PGdiObject;
begin
//debugln('  TGtk2WidgetSet.CreateDefaultBrush ->');
  Result := NewGDIObject(gdiBrush);
  {$IFDEF DebugGDIBrush}
  debugln('TGtk2WidgetSet.CreateDefaultBrush Created: ',DbgS(Result));
  {$ENDIF}
  Result^.GDIBrushFill := GDK_SOLID;
  Result^.GDIBrushColor.ColorRef := 0;
  Result^.GDIBrushColor.Colormap := gdk_colormap_get_system;
  gdk_color_white(Result^.GDIBrushColor.Colormap, @Result^.GDIBrushColor.Color);
  BuildColorRefFromGDKColor(Result^.GDIBrushColor);
end;

{------------------------------------------------------------------------------
  Function: CreateDefaultFont
  Params:  none
  Returns: a Font GDIObject

  Creates an default font, used for initial values
 ------------------------------------------------------------------------------}
function TGtk2WidgetSet.CreateDefaultFont: PGdiObject;
var
  CachedFont: TGtkFontCacheDescriptor;
begin
  Result := NewGDIObject(gdiFont);
  Result^.UntransfFontHeight := 0;
  Result^.GDIFontObject:=GetDefaultGtkFont(false);
  CachedFont:=FontCache.FindADescriptor(Result^.GDIFontObject);
  if CachedFont<>nil then
    FontCache.Reference(Result^.GDIFontObject)
  else
    FontCache.Add(Result^.GDIFontObject,DefaultLogFont,'');
end;

{------------------------------------------------------------------------------
  Function: CreateDefaultPen
  Params:  none
  Returns: a Pen GDIObject

  Creates an default pen, used for initial values
 ------------------------------------------------------------------------------}
function TGtk2WidgetSet.CreateDefaultPen: PGdiObject;
begin
  //write('  TGtk2WidgetSet.CreateDefaultPen ->');
  Result := NewGDIObject(gdiPen);
  Result^.UnTransfPenWidth := 0;
  Result^.GDIPenStyle := PS_SOLID;
  Result^.GDIPenColor.ColorRef := 0;
  Result^.GDIPenColor.Colormap := gdk_colormap_get_system;
  gdk_color_black(Result^.GDIPenColor.Colormap, @Result^.GDIPenColor.Color);
  BuildColorRefFromGDKColor(Result^.GDIPenColor);
end;

function TGtk2WidgetSet.CreateDefaultGDIBitmap: PGdiObject;
begin
  Result := NewGDIObject(gdiBitmap);
end;

{------------------------------------------------------------------------------
  procedure TGtk2WidgetSet.UpdateDCTextMetric(DC: TGtkDeviceContext);

  Sets the gtk resource file and parses it.
 ------------------------------------------------------------------------------}
procedure TGtk2WidgetSet.UpdateDCTextMetric(DC: TGtkDeviceContext);
const
  TestString: array[boolean] of string = (
    // single byte char font
    '{ABCDEFGHIJKLMNOPQRSTUVWXYZXYZabcdefghijklmnopqrstuvwxyz|_}',
    // double byte char font
    #0'{'#0'A'#0'B'#0'C'#0'D'#0'E'#0'F'#0'G'#0'H'#0'I'#0'J'#0'K'#0'L'#0'M'#0'N'
    +#0'O'#0'P'#0'Q'#0'R'#0'S'#0'T'#0'U'#0'V'#0'W'#0'X'#0'Y'#0'Z'#0'X'#0'Y'#0'Z'
    +#0'a'#0'b'#0'c'#0'd'#0'e'#0'f'#0'g'#0'h'#0'i'#0'j'#0'k'#0'l'#0'm'#0'n'#0'o'
    +#0'p'#0'q'#0'r'#0's'#0't'#0'u'#0'v'#0'w'#0'x'#0'y'#0'z'#0'|'#0'_'#0'}'
    );
var
  UseFont : TGtkIntfFont;
  CachedFont: TGtkFontCacheItem;
  IsDefault: Boolean;
  AWidget: PGtkWidget;
  APangoContext: PPangoContext;
  APangoLanguage: PPangoLanguage;
  Desc: TGtkFontCacheDescriptor;
  APangoFontDescription: PPangoFontDescription;
  APangoMetrics: PPangoFontMetrics;
  aRect: TPangoRectangle;
begin
  with TGtkDeviceContext(DC) do begin
    if dcfTextMetricsValid in Flags then begin
      // cache valid
      exit;
    end;
    UseFont:=GetGtkFont(TGtkDeviceContext(DC));
    FillChar(DCTextMetric, SizeOf(DCTextMetric), 0);
    CachedFont:=FontCache.FindGTKFont(UseFont);
    IsDefault:=UseFont = GetDefaultGtkFont(false);
    if (CachedFont=nil) and (not IsDefault) then begin
      DebugLn(['TGtk2WidgetSet.UpdateDCTextMetric no CachedFont UseFont=',dbgs(UseFont)]);
      DumpStack;
    end;
    //DebugLn(['TGtk2WidgetSet.UpdateDCTextMetric IsDefault=',UseFont = GetDefaultGtkFont(false)]);

    if (CachedFont<>nil) and (CachedFont.MetricsValid) then begin
      DCTextMetric.lBearing:=CachedFont.lBearing;
      DCTextMetric.rBearing:=CachedFont.rBearing;
      DCTextMetric.IsDoubleByteChar:=CachedFont.IsDoubleByteChar;
      DCTextMetric.IsMonoSpace:=CachedFont.IsMonoSpace;
      DCTextMetric.TextMetric:=CachedFont.TextMetric;
    end
    else with DCTextMetric do begin
      IsDoubleByteChar:=FontIsDoubleByteCharsFont(UseFont);
      IsMonoSpace:=FontIsMonoSpaceFont(UseFont);

      // get pango context (= association to a widget)
      AWidget:=Widget;
      if AWidget=nil then
        AWidget:=GetStyleWidget(lgsLabel);
      APangoContext := gtk_widget_get_pango_context(AWidget);
      if APangoContext=nil then
        DebugLn(['TGtk2WidgetSet.UpdateDCTextMetric WARNING: no pango context']);
      // get pango language (e.g. de_DE)
      APangoLanguage := pango_context_get_language(APangoContext);
      if APangoLanguage=nil then
        DebugLn(['TGtk2WidgetSet.UpdateDCTextMetric WARNING: no pango language']);
      // get pango font description (e.g. 'sans 12')
      APangoFontDescription := nil;
      if (not IsDefault) and (CachedFont<>nil) then begin
        Desc:=FontCache.FindADescriptor(UseFont);
        if Desc<>nil then
          APangoFontDescription := Desc.PangoFontDescription;
        //DebugLn(['TGtk2WidgetSet.UpdateDCTextMetric CachedFont Desc.PangoFontDescription=',GetPangoDescriptionReport(APangoFontDescription),' Desc.LongFontName=',Desc.LongFontName]);
      end;
      if APangoFontDescription=nil then
        APangoFontDescription:=pango_context_get_font_description(APangoContext);
      if APangoFontDescription=nil then
        APangoFontDescription:=GetDefaultFontDesc(false);
      if APangoFontDescription=nil then
        DebugLn(['TGtk2WidgetSet.UpdateDCTextMetric WARNING: no pango font description']);
      //DebugLn(['TGtk2WidgetSet.UpdateDCTextMetric APangoFontDescription=',GetPangoDescriptionReport(APangoFontDescription)]);
      // get pango metrics (e.g. ascent, descent)
      APangoMetrics := pango_context_get_metrics(APangoContext,
                                       APangoFontDescription, APangoLanguage);
      if APangoMetrics=nil then
        DebugLn(['TGtk2WidgetSet.UpdateDCTextMetric WARNING: no pango metrics']);

      TextMetric.tmAveCharWidth := Max(1,
                 pango_font_metrics_get_approximate_char_width(APangoMetrics)
                 div PANGO_SCALE);

      TextMetric.tmAscent := PANGO_PIXELS(pango_font_metrics_get_ascent(APangoMetrics));
      TextMetric.tmDescent := PANGO_PIXELS(pango_font_metrics_get_descent(APangoMetrics));
      TextMetric.tmHeight := TextMetric.tmAscent+TextMetric.tmDescent;

      pango_layout_set_text(UseFont, PChar(TestString[IsDoubleByteChar]),
                            length(PChar(TestString[IsDoubleByteChar])));
      pango_layout_get_extents(UseFont, nil, @aRect);

      lBearing := PANGO_LBEARING(aRect) div PANGO_SCALE;
      rBearing := PANGO_RBEARING(aRect) div PANGO_SCALE;

      pango_layout_set_text(UseFont, 'M', 1);
      pango_layout_get_pixel_size(UseFont, @aRect.width, @aRect.height);
      TextMetric.tmMaxCharWidth := Max(1,aRect.width);
      pango_layout_set_text(UseFont, 'W', 1);
      pango_layout_get_pixel_size(UseFont, @aRect.width, @aRect.height);
      TextMetric.tmMaxCharWidth := Max(TextMetric.tmMaxCharWidth,aRect.width);

      pango_font_metrics_unref(APangoMetrics);

      (*debugln('TGtk2WidgetSet.UpdateDCTextMetric A IsDoubleByteChar=',dbgs(IsDoubleByteChar),
        ' lbearing=',dbgs(lBearing),' rbearing=',dbgs(rBearing),
        ' tmAscent='+dbgs(TextMetric.tmAscent),
        ' tmDescent='+dbgs(TextMetric.tmdescent),
        ' tmHeight='+dbgs(TextMetric.tmHeight),
        ' tmMaxCharWidth='+dbgs(TextMetric.tmMaxCharWidth),
        ' tmAveCharWidth='+dbgs(TextMetric.tmAveCharWidth));*)
      if (CachedFont<>nil) then begin
        CachedFont.lBearing:=lBearing;
        CachedFont.rBearing:=rBearing;
        CachedFont.IsDoubleByteChar:=IsDoubleByteChar;
        CachedFont.IsMonoSpace:=IsMonoSpace;
        CachedFont.TextMetric:=TextMetric;
        CachedFont.MetricsValid:=true;
      end;
    end;
    Flags := Flags + [dcfTextMetricsValid];
  end;
end;

{------------------------------------------------------------------------------
  function TGtk2WidgetSet.GetDefaultFontDesc(IncreaseReferenceCount: boolean
    ): PPangoFontDescription;
 ------------------------------------------------------------------------------}
function TGtk2WidgetSet.GetDefaultFontDesc(IncreaseReferenceCount: boolean
  ): PPangoFontDescription;
begin
  if FDefaultFontDesc = nil then begin
    FDefaultFontDesc:=LoadDefaultFontDesc;
    if FDefaultFontDesc = nil then
      raise EOutOfResources.Create(rsUnableToLoadDefaultFont);
  end;
  Result:=FDefaultFontDesc;
  if IncreaseReferenceCount then
    Result := pango_font_description_copy(Result);
end;

{------------------------------------------------------------------------------
  function TGtk2WidgetSet.GetDefaultGtkFont(IncreaseReferenceCount: boolean
    ): TGtkIntfFont;
 ------------------------------------------------------------------------------}
function TGtk2WidgetSet.GetDefaultGtkFont(IncreaseReferenceCount: boolean
  ): TGtkIntfFont;
begin
  if FDefaultFont = nil then begin
    FDefaultFont:=LoadDefaultFont;
    if FDefaultFont = nil then
      raise EOutOfResources.Create(rsUnableToLoadDefaultFont);
    ReferenceGtkIntfFont(FDefaultFont); // mark as used globally
  end;
  Result:=FDefaultFont;
  if IncreaseReferenceCount then
    ReferenceGtkIntfFont(Result); // mark again
end;

function TGtk2WidgetSet.GetGtkFont(DC: TGtkDeviceContext): TGtkIntfFont;
begin
  // create font if needed
  Result:=DC.GetFont^.GDIFontObject;
end;

function TGtk2WidgetSet.CreateRegionCopy(SrcRGN: hRGN): hRGN;
var
  GDIObject: PGDIObject;
begin
  GDIObject := NewGDIObject(gdiRegion);
  GDIObject^.GDIRegionObject:=gdk_region_copy({%H-}PGdiObject(SrcRGN)^.GDIRegionObject);
  Result := hRgn({%H-}PtrUInt(GDIObject));
end;

function TGtk2WidgetSet.DCClipRegionValid(DC: HDC): boolean;
var
  CurClipRegion: hRGN;
begin
  Result:=false;
  if not IsValidDC(DC) then exit;
  CurClipRegion:=HRGN({%H-}PtrUInt(TGtkDeviceContext(DC).ClipRegion));
  if (CurClipRegion<>0) and (not IsValidGDIObject(CurClipRegion)) then exit;
  Result:=true;
end;

function TGtk2WidgetSet.CreateEmptyRegion: hRGN;
var
  GObject: PGdiObject;
begin
  GObject := NewGDIObject(gdiRegion);
  GObject^.GDIRegionObject := gdk_region_new;
  Result := HRGN({%H-}PtrUInt(GObject));
  //DebugLn('TGtk2WidgetSet.CreateEmptyRgn A RGN=',DbgS(Result));
end;

{------------------------------------------------------------------------------
  Function: SetRCFilename
  Params:  const AValue: string
  Returns: none

  Sets the gtk resource file and parses it.
 ------------------------------------------------------------------------------}
procedure TGtk2WidgetSet.SetRCFilename(const AValue: string);
begin
  if (FRCFilename=AValue) then exit;
  FRCFilename:=AValue;
  FRCFileParsed:=false;
  ParseRCFile;
end;

{------------------------------------------------------------------------------
  procedure TGtk2WidgetSet.CheckRCFilename;

  Sets the gtk resource file and parses it.
 ------------------------------------------------------------------------------}
procedure TGtk2WidgetSet.CheckRCFilename;
begin
  if FRCFileParsed and (FRCFilename<>'') and FileExistsUTF8(FRCFilename)
  and (FileAgeUTF8(FRCFilename)<>FRCFileAge) then
    FRCFileParsed:=false;
end;

{------------------------------------------------------------------------------
  Function: ParseRCFile
  Params:  const AValue: string
  Returns: none

  Sets the gtk resource file and parses it.
 ------------------------------------------------------------------------------}
procedure TGtk2WidgetSet.ParseRCFile;
begin
  if (not FRCFileParsed)
  and (FRCFilename<>'') and FileExistsUTF8(FRCFilename) then
  begin
    gtk_rc_parse(PChar(FRCFilename));
    FRCFileParsed:=true;
    FRCFileAge:=FileAgeUTF8(FRCFilename);
  end;
end;

{------------------------------------------------------------------------------
  Function: SetClipboardWidget
  Params: TargetWidget: PGtkWidget - This widget will be connected to all
                  clipboard signals which are all handled by the TGtkWidgetSet
                  itself.
  Returns: none

  All supported targets are added to the new widget. This way, no one,
  especially not the lcl, will notice the change. ;)
 ------------------------------------------------------------------------------}
procedure TGtk2WidgetSet.SetClipboardWidget(TargetWidget: PGtkWidget);
{$IFDEF DEBUG_CLIPBOARD}
type
  TGtkTargetSelectionList = record
    Selection: Cardinal;
    List: PGtkTargetList;
  end;
  PGtkTargetSelectionList = ^TGtkTargetSelectionList;
{$ENDIF}
const
  gtk_selection_handler_key: PChar = 'gtk-selection-handlers';

  {$IFDEF DEBUG_CLIPBOARD}
  function gtk_selection_target_list_get(Widget: PGtkWidget;
    ClipboardType: TClipboardType): PGtkTargetList;
  var
    SelectionLists, CurSelList: PGList;
    TargetSelList: PGtkTargetSelectionList;
  begin
    SelectionLists := g_object_get_data (PGObject(Widget),
                                          gtk_selection_handler_key);
    CurSelList := SelectionLists;
    while (CurSelList<>nil) do begin
      TargetSelList := CurSelList^.Data;
      if (TargetSelList^.Selection = ClipboardTypeAtoms[ClipboardType]) then
      begin
        Result:=TargetSelList^.List;
        exit;
      end;
      CurSelList := CurSelList^.Next;
    end;
    Result:=nil;
  end;

  procedure WriteTargetLists(Widget: PGtkWidget);
  var c: TClipboardType;
    TargetList: PGtkTargetList;
    TmpList: PGList;
    Pair: PGtkTargetPair;
  begin
    DebugLn('  WriteTargetLists WWW START');
    for c:=Low(TClipboardType) to High(TClipboardType) do begin
      TargetList:=gtk_selection_target_list_get(Widget,c);
      DebugLn('  WriteTargetLists WWW ',ClipboardTypeName[c],' ',dbgs(TargetList<>nil));
      if TargetList<>nil then begin
        TmpList:=TargetList^.List;
        while TmpList<>nil do begin
          Pair:=PGtkTargetPair(TmpList^.Data);
          DebugLn('    WriteTargetLists BBB ',dbgs(Pair^.Target),' ',GdkAtomToStr(Pair^.Target));
          TmpList:=TmpList^.Next;
        end;
      end;
    end;
    DebugLn('  WriteTargetLists WWW END');
  end;
  {$ENDIF}

  procedure ClearTargetLists(Widget: PGtkWidget);
  // MG: Reading in gtk internals is dirty, but there seems to be no other way
  //     to clear the old target lists
  var
    SelectionLists: PGList;
    CurClipboard: TClipboardType;
  begin
    {$IFDEF DEBUG_CLIPBOARD}
    DebugLn('  ClearTargetLists WWW START');
    {$ENDIF}
    // clear 3 selections
    for CurClipboard := Low(TClipboardType) to High(CurClipboard) do
      gtk_selection_clear_targets(Widget, ClipboardTypeAtoms[CurClipboard]);

    SelectionLists := g_object_get_data(PGObject(Widget),
      gtk_selection_handler_key);
    if SelectionLists <> nil then
      g_list_free(SelectionLists);
    g_object_set_data (PGObject(Widget), gtk_selection_handler_key, GtkNil);
    {$IFDEF DEBUG_CLIPBOARD}
    DebugLn('  ClearTargetLists WWW END');
    {$ENDIF}
  end;

var c: TClipboardType;
begin
  if ClipboardWidget=TargetWidget then exit;
  {$IFDEF DEBUG_CLIPBOARD}
  DebugLn('[TGtk2WidgetSet.SetClipboardWidget] ',dbgs(ClipboardWidget<>nil),' -> ',dbgs(TargetWidget<>nil),' ',GetWidgetDebugReport(TargetWidget));
  {$ENDIF}
  if ClipboardWidget<>nil then begin
    {$IFDEF DEBUG_CLIPBOARD}
    WriteTargetLists(ClipboardWidget);
    {$ENDIF}
    ClearTargetLists(ClipboardWidget);
    {$IFDEF DEBUG_CLIPBOARD}
    WriteTargetLists(ClipboardWidget);
    {$ENDIF}
  end;

  ClipboardWidget:=TargetWidget;
  if ClipboardWidget<>nil then begin
    // connect widget to all clipboard signals
    g_signal_connect(PGtkObject(ClipboardWidget),'selection_received',
      TGTKSignalFunc(@ClipboardSelectionReceivedHandler),GtkNil);
    g_signal_connect(PGtkObject(ClipboardWidget),'selection_get',
      TGTKSignalFunc(@ClipboardSelectionRequestHandler),GtkNil);
    g_signal_connect(PGtkObject(ClipboardWidget),'selection_clear_event',
      TGTKSignalFunc(@ClipboardSelectionLostOwnershipHandler),GtkNil);
    // add all supported targets for all clipboard types
    for c:=Low(TClipboardType) to High(TClipboardType) do begin
      if (ClipboardTargetEntries[c]<>nil) then begin
        //DebugLn('TGtk2WidgetSet.SetClipboardWidget ',GdkAtomToStr(ClipboardTypeAtoms[c]),' Entries=',dbgs(ClipboardTargetEntryCnt[c]));
        gtk_selection_add_targets(ClipboardWidget,ClipboardTypeAtoms[c],
                  ClipboardTargetEntries[c],ClipboardTargetEntryCnt[c]);
      end;
    end;
    {$IFDEF DEBUG_CLIPBOARD}
    WriteTargetLists(ClipboardWidget);
    {$ENDIF}
  end;
end;

{------------------------------------------------------------------------------
  procedure TGtk2WidgetSet.WordWrap(AText: PChar; MaxWidthInPixel: integer;
    var Lines: PPChar; var LineCount: integer); virtual;

  Breaks AText into several lines and creates a list of PChar. The last entry
  will be nil.
  Lines break at new line chars and at spaces if a line is longer than
  MaxWidthInPixel or in a word.
  Lines will be one memory block so that you can free the list and all lines
  with FreeMem(Lines).
------------------------------------------------------------------------------}
procedure TGtk2WidgetSet.WordWrap(DC: HDC; AText: PChar;
  MaxWidthInPixel: integer; out Lines: PPChar; out LineCount: integer);
var
  UseFont: TGtkIntfFont;

  function GetLineWidthInPixel(LineStart, LineLen: integer): integer;
  var
    width: LongInt;
  begin
    GetTextExtentIgnoringAmpersands(UseFont, @AText[LineStart], LineLen,
                                    nil, nil, @width, nil, nil);
    Result:=Width;
  end;

  function FindLineEnd(LineStart: integer): integer;
  var
    CharLen,
    LineStop,
    LineWidth, WordWidth, WordEnd, CharWidth: integer;
  begin
    // first search line break or text break
    Result:=LineStart;
    while not (AText[Result] in [#0,#10,#13]) do inc(Result);
    if Result<=LineStart+1 then exit;
    lineStop:=Result;

    // get current line width in pixel
    LineWidth:=GetLineWidthInPixel(LineStart,Result-LineStart);
    if LineWidth>MaxWidthInPixel then begin
      // line too long
      // -> add words till line size reached
      LineWidth:=0;
      WordEnd:=LineStart;
      WordWidth:=0;
      repeat
        Result:=WordEnd;
        inc(LineWidth,WordWidth);
        // find word start
        while AText[WordEnd] in [' ',#9] do inc(WordEnd);
        // find word end
        while not (AText[WordEnd] in [#0,' ',#9,#10,#13]) do inc(WordEnd);
        // calculate word width
        WordWidth:=GetLineWidthInPixel(Result,WordEnd-Result);
      until LineWidth+WordWidth>MaxWidthInPixel;
      if LineWidth=0 then begin
        // the first word is longer than the maximum width
        // -> add chars till line size reached
        Result:=LineStart;
        LineWidth:=0;
        repeat
          charLen:=UTF8CodepointSize(@AText[result]);
          CharWidth:=GetLineWidthInPixel(Result,charLen);
          inc(LineWidth,CharWidth);
          if LineWidth>MaxWidthInPixel then break;
          if result>=lineStop then break;
          inc(Result,charLen);
        until false;
        // at least one char
        if Result=LineStart then begin
          charLen:=UTF8CodepointSize(@AText[result]);
          inc(Result,charLen);
        end;
      end;
    end;
  end;

  function IsEmptyText: boolean;
  begin
    if (AText=nil) or (AText[0]=#0) then begin
      // no text
      GetMem(Lines,SizeOf(PChar));
      Lines[0]:=nil;
      LineCount:=0;
      Result:=true;
    end else
      Result:=false;
  end;

  procedure InitFont;
  begin
    UseFont:=GetGtkFont(TGtkDeviceContext(DC));
  end;

var
  LinesList: TIntegerList;
  LineStart, LineEnd, LineLen: integer;
  ArraySize, TotalSize: integer;
  i: integer;
  CurLineEntry: PPChar;
  CurLineStart: PChar;
begin
  if IsEmptyText then begin
    Lines:=nil;
    LineCount:=0;
    exit;
  end;
  InitFont;
  LinesList:=TIntegerList.Create;
  LineStart:=0;

  // find all line starts and line ends
  repeat
    LinesList.Add(LineStart);
    // find line end
    LineEnd:=FindLineEnd(LineStart);
    LinesList.Add(LineEnd);
    // find next line start
    LineStart:=LineEnd;
    if AText[LineStart] in [#10,#13] then begin
      // skip new line chars
      inc(LineStart);
      if (AText[LineStart] in [#10,#13])
      and (AText[LineStart]<>AText[LineStart-1]) then
        inc(LineStart);
    end else if AText[LineStart] in [' ',#9] then begin
      // skip space
      while AText[LineStart] in [' ',#9] do
        inc(LineStart);
    end;
  until AText[LineStart]=#0;

  // create mem block for 'Lines': array of PChar + all lines
  LineCount:=LinesList.Count shr 1;
  ArraySize:=(LineCount+1)*SizeOf(PChar);
  TotalSize:=ArraySize;
  i:=0;
  while i<LinesList.Count do begin
    // add  LineEnd - LineStart + 1 for the #0
    LineLen:=LinesList[i+1]-LinesList[i]+1;
    inc(TotalSize,LineLen);
    inc(i,2);
  end;
  GetMem(Lines,TotalSize);
  FillChar(Lines^,TotalSize,0);

  // create Lines
  CurLineEntry:=Lines;
  CurLineStart:=PChar(CurLineEntry)+ArraySize;
  i:=0;
  while i<LinesList.Count do begin
    // set the pointer to the start of the current line
    CurLineEntry[i shr 1]:=CurLineStart;
    // copy the line
    LineStart:=LinesList[i];
    LineEnd:=LinesList[i+1];
    LineLen:=LineEnd-LineStart;
    if LineLen>0 then
      Move(AText[LineStart],CurLineStart^,LineLen);
    inc(CurLineStart,LineLen);
    // add #0 as line end
    CurLineStart^:=#0;
    inc(CurLineStart);
    // next line
    inc(i,2);
  end;
  if {%H-}PtrUInt(CurLineStart)-{%H-}PtrUInt(Lines)<>TotalSize then
    RaiseGDBException('TGtk2WidgetSet.WordWrap Consistency Error:'
      +' Lines+TotalSize<>CurLineStart');
  CurLineEntry[i shr 1]:=nil;

  LinesList.Free;
end;

function TGtk2WidgetSet.ForceLineBreaks(DC: hDC; Src: PChar;
  MaxWidthInPixels: Longint;
  ConvertAmpersandsToUnderScores: Boolean) : PChar;
var
  Lines : PPChar;
  I, NumLines : Longint;
  TmpStr : PGString;
  Line : PgChar;
begin
  TmpStr := nil;
  WordWrap(DC, Src, MaxWidthInPixels, Lines, NumLines);
  For I := 0 to NumLines - 1 do begin
    If TmpStr <> nil then
      g_string_append_c(TmpStr, #10);

    If ConvertAmpersandsToUnderScores then begin
      Line := Ampersands2Underscore(Lines[I]);
      If Line <> nil then begin
        If TmpStr <> nil then begin
          g_string_append(TmpStr, Line);
        end
        else
          TmpStr := g_string_new(Line);
        StrDispose(Line);
      end;
    end
    else begin
      If Lines[I] <> nil then
        If TmpStr <> nil then
          g_string_append(TmpStr, Lines[I])
        else
          TmpStr := g_string_new(Lines[I]);
    end;
  end;
  ReallocMem(Lines, 0);
  If TmpStr <> nil then
  begin
    Result := StrNew(TmpStr^.str);
    g_string_free(TmpStr, True);
  end
  else
    Result:=nil;
end;

{$IFDEF HASX}
{.$DEFINE DEBUGGTK2FRAMESIZE}

function Gtk2DummyWidgetEvent({%H-}AWidget: PGtkWidget; AEvent: PGdkEvent; AData: GPointer): gboolean; cdecl;
begin
  Result := CallBackDefaultReturn;
  if (AEvent^._type = GDK_EXPOSE) then
    TDummyWidget(AData).FFirstPaintEvent := True;
end;

constructor TDummyWidget.Create;
begin
  inherited Create;
  FFrameRect := Rect(0, 0, 0, 0);
  Widget := gtk_window_new(GTK_WINDOW_TOPLEVEL);
  gtk_window_set_decorated(PGtkWindow(Widget), True);
  gtk_window_set_accept_focus(PGtkWindow(Widget), False);
  gtk_window_set_focus_on_map(PGtkWindow(Widget), False);
  gtk_window_set_keep_below(PGtkWindow(Widget), True);
  gtk_window_set_skip_taskbar_hint(PGtkWindow(Widget), True);
  gtk_widget_set_parent_window(Widget, gdk_get_default_root_window);
  if Assigned(gtk_window_set_opacity) and Gtk2WidgetSet.compositeManagerRunning then
    gtk_window_set_opacity(PGtkWindow(Widget), 0.5);

  g_signal_connect(PGtkObject(Widget), 'event',
    gtk_signal_func(@Gtk2DummyWidgetEvent), Self);
end;

function TDummyWidget.ShowDummyWidget(const ALeft, ATop, AWidth,
  AHeight: integer): boolean;
var
  R: TRect;
  {$IFDEF DEBUGGTK2FRAMESIZE}
  ATicks: QWord;
  {$ENDIF}
  ALoop: integer;
  AMaxLoops: integer;
  aRequisition: TGtkRequisition;
  AAllocation: TGtkAllocation;
begin
  Result := Assigned(Widget);
  if Result then
  begin
    if Gtk2WidgetSet.compositeManagerRunning then
      AMaxLoops := 200000
    else
      AMaxLoops := 20000;
    {$IFDEF DEBUGGTK2FRAMESIZE}
    writeln('ShowDummyWidget(start) WindowManager="',Gtk2WidgetSet.GetWindowManager,'" Compositing enabled="',Gtk2WidgetSet.compositeManagerRunning,'" IsWayland="UNKNOWN" MaxLoops=',AMaxLoops);
    ATicks := GetTickCount64;
    {$ENDIF}
    if (ALeft <= 0) or (ATop <= 0) or (AWidth <= 0) or (AHeight <= 0) then
    begin
      gdk_screen_get_monitor_geometry(gdk_screen_get_default, 0, @R);
      aRequisition.width := 75;
      aRequisition.height := 32;
      AAllocation.x := R.CenterPoint.x;
      AAllocation.y := R.CenterPoint.y;
      AAllocation.width := aRequisition.Width;
      AAllocation.height := aRequisition.height;
      gtk_widget_size_allocate(Widget,@AAllocation);
    end else
    begin
      aRequisition.width := AWidth - 1;
      aRequisition.height := AHeight - 1;
      AAllocation.x := ALeft + 1;
      AAllocation.y := ATop + 1;
      AAllocation.width := aRequisition.Width;
      AAllocation.height := aRequisition.height;
      gtk_widget_size_allocate(Widget,@AAllocation);
    end;
    gtk_widget_show(Widget);
    gtk_widget_map(Widget);
    gtk_window_move(PGtkWindow(Widget), AAllocation.x, AAllocation.y);
    gtk_window_resize(PGtkWindow(Widget), AAllocation.width, AAllocation.height);

    {We are waiting until dummy window is laid out on screen by window manager
     ALoop variable is needed to avoid infinite loop.
     Usually we get result in about 20-30msec on modern X11 without compositing,
     but 30-100 msec on wm with compositing enabled.
     Older X11 or slower machine might need more loops to get result,
     but it won't be over 200 msec in any case.}

    ALoop := 0; // avoid infinite loop
    while not GDK_IS_WINDOW(Widget^.window) do
    begin
      inc(ALoop);

      while g_main_context_pending(g_main_context_default) do
      begin
        if not g_main_context_iteration(g_main_context_default, False) then
          break;
      end;

      if ALoop > AMaxLoops then
        break;
    end;

    {$IFDEF DEBUGGTK2FRAMESIZE}
    writeln('ShowDummyWidget: 1st LOOP=',ALoop);
    {$ENDIF}

    ALoop := 0; // avoid infinite loop
    while not FFirstPaintEvent do
    begin
      inc(ALoop);

      while g_main_context_pending(g_main_context_default) do
      begin
        if not g_main_context_iteration(g_main_context_default, False) then
          break;
      end;

      if ALoop > AMaxLoops then
        break;
    end;

    {$IFDEF DEBUGGTK2FRAMESIZE}
    writeln('ShowDummyWidget: 2st LOOP=',ALoop);
    {$ENDIF}
    R := Rect(0 ,0, 0, 0);
    ALoop := 0; // avoid infinite loop
    // now wait until R.Top > 0
    while (R.Top <= 0) do //
    begin
      inc(ALoop);
      R := GetWidgetFrame;

      while g_main_context_pending(g_main_context_default) do
      begin
        if not g_main_context_iteration(g_main_context_default, False) then
          break;
      end;

      if ALoop > AMaxLoops then
        break;
    end;
    {$IFDEF DEBUGGTK2FRAMESIZE}
    writeln('ShowDummyWidget: 3nd LOOP=',ALoop,' LAST R=',dbgs(R));
    writeln('ShowDummyWidget: *finished* FRAME=',dbgs(GetWidgetFrame),' in ',GetTickCount64 - ATicks,' msec ');
    {$ENDIF}
  end;
end;

destructor TDummyWidget.Destroy;
begin
  if Assigned(Widget) then
  begin
    HideWidget;
    gtk_widget_destroy(Widget);
    Widget := nil;
  end;
  inherited Destroy;
end;

function TDummyWidget.GetWidgetFrame: TRect;
var
  AFrame, AGeometry: TRect;
  DeskX, DeskY, PosX, PosY, AWidth, AHeight: gint;
  GRect: TGdkRectangle;
begin
  Result := FFrameRect;
  if not Assigned(Widget) then
    exit;
  if not GDK_IS_WINDOW(Widget^.window) then
    exit;
  if not gdk_window_is_visible(Widget^.window) then
    exit;

  gdk_window_get_frame_extents(Widget^.window, @GRect);
  gdk_window_get_deskrelative_origin(Widget^.window, @DeskX, @DeskY);

  AFrame := RectFromGdkRect(GRect);
  gtk_window_get_position(PGtkWindow(Widget), @PosX, @PosY);
  gtk_window_get_size(PGtkWindow(Widget), @AWidth, @AHeight);

  AGeometry := Bounds(PosX, PosY, AWidth, AHeight);
  FFrameRect := Rect(DeskX - PosX, DeskY - PosY, (AFrame.Right - AGeometry.Right) - (DeskX - PosX), (AFrame.Bottom - AGeometry.Bottom) - (DeskY - PosY)); // hardcoded just to proove GetWindowRect

  if FFrameRect.Top < 0 then
    FFrameRect.Top := 0;

  Result := FFrameRect;
end;

procedure TDummyWidget.SendToBack;
begin
  if Assigned(Widget) then
    gtk_window_set_keep_above(PGtkWindow(Widget), True);
end;

procedure TDummyWidget.HideWidget;
begin
  if Assigned(Widget) then
    gtk_widget_hide(Widget);
end;
{$ENDIF}

{$IFDEF ASSERT_IS_ON}
  {$UNDEF ASSERT_IS_ON}
  {$C-}
{$ENDIF}

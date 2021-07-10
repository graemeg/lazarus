{%MainUnit gtk2wsextctrls.pp}
{
 gtk2trayicon.inc

 *****************************************************************************
  This file is part of the Lazarus Component Library (LCL)

  See the file COPYING.modifiedLGPL.txt, included in this distribution,
  for details about the license.
 *****************************************************************************

 Authors: Felipe Monteiro de Carvalho and Andrew Haines

 Special thanks for: Danny Milosavljevic and the Lazarus Team

 Gtk2 specific code.
}

{ TGtk2WSCustomTrayIcon }

type
  { TGtk2TrayIconHandle }

  TGtk2TrayIconHandle = class
  private
    plug: PGtkWidget;
    DrawingArea: PGtkWidget;
    Tips: PGtkTooltips;
    fEmbedded: Boolean;
    fTrayIcon: TCustomTrayIcon;
{$ifdef UseStatusIcon}
    FStatusIcon: PGtkStatusIcon;
{$endif}
{$ifdef HasGdk2X}
    fDisplay: PDisplay;
    fWindow: TWindow;
    fScreen: PScreen;
    fScreenID: longint;
    fTrayParent: TWindow;
    function SendMessage(window: TWindow; msg: Integer; data1, data2, data3: Integer): Boolean;
    procedure SetEmbedded;
{$endif HasGdk2X}
  public
    constructor Create(const wsTrayIcon: TCustomTrayIcon);
    destructor Destroy; override;
    procedure Show;
    function GetPosition: TPoint;
    procedure Update(NewPixBuf: PGdkPixbuf; const NewHint: String);
  end;

const
  SYSTEM_TRAY_REQUEST_DOCK   = 0;
  //SYSTEM_TRAY_BEGIN_MESSAGE  = 1;
  //SYSTEM_TRAY_CANCEL_MESSAGE = 2;

{$ifdef HasGdk2X}
var
  XError: Integer;
{*******************************************************************
*  TempX11ErrorHandler ()
*
*  DESCRIPTION:    Temp ErrorHandler
*
*  PARAMETERS:     ?
*
*  RETURNS:        ?
*
*******************************************************************}
function TempX11ErrorHandler({%H-}Display:PDisplay; ErrorEv:PXErrorEvent):longint;cdecl;
begin
  XError := ErrorEv^.error_code;
  WriteLn('Error: ' + IntToStr(XError));
  Result:=0;
end;

{*******************************************************************
*  TGtk2TrayIconHandle.Send_Message ()
*
*  DESCRIPTION:    Sends a message to the X client
*
*  PARAMETERS:     None
*
*  RETURNS:        Nothing
*
*******************************************************************}
function TGtk2TrayIconHandle.SendMessage(window: TWindow; msg: Integer; data1, data2, data3: Integer): Boolean;
var
  Ev: TXEvent;
begin
  FillChar(Ev{%H-}, SizeOf(TXEvent), 0);

  ev.xclient._type := ClientMessage;
  ev.xclient.window := window;
  ev.xclient.message_type := XInternAtom (fDisplay, '_NET_SYSTEM_TRAY_OPCODE', False);
  ev.xclient.format := 32;
  ev.xclient.data.l[0] := CurrentTime;
  ev.xclient.data.l[1] := msg;
  ev.xclient.data.l[2] := data1;
  ev.xclient.data.l[3] := data2;
  ev.xclient.data.l[4] := data3;

  XError := 0;
  XSendEvent(fDisplay, fTrayParent, False, NoEventMask, @ev);
  XSync(fDisplay, False);
  Result := XError = 0;
  XError := 0;
end;

{*******************************************************************
*  TGtk2TrayIconHandle.SetEmbedded ()
*
*  DESCRIPTION:    Docks the GtkPlug into the system tray
*
*  PARAMETERS:     None
*
*  RETURNS:        Nothing
*
*******************************************************************}
procedure TGtk2TrayIconHandle.SetEmbedded;
var
  old_error: TXErrorHandler;
  buf: array [0..32] of char;
  selection_atom : TAtom;
begin
  if fEmbedded then
    Exit;
  old_error := XSetErrorHandler(@TempX11ErrorHandler);

  xsync(fdisplay,true);
  buf :=  PChar('_NET_SYSTEM_TRAY_S' + IntToStr(fScreenID));
  selection_atom := XInternAtom(fDisplay, buf, false);
  XGrabServer(fDisplay);

  fTrayParent := XGetSelectionOwner(fDisplay, selection_atom);
  if fTrayParent <> None then
  begin
    XSelectInput(fDisplay, fTrayParent, StructureNotifyMask);
  end;

  XUngrabServer(fDisplay);
  XFlush(fDisplay);
  if fTrayParent <> None then
    fEmbedded := SendMessage(fTrayParent, SYSTEM_TRAY_REQUEST_DOCK, fWindow, 0, 0);

  XSetErrorHandler(old_error);
end;
{$endif HasGdk2X}

{*******************************************************************
*  realize_cb ()
*
*  DESCRIPTION:    Callback function for the realize signal
*                  Sets the systray icon after the widget is realized
*
*  PARAMETERS:     None
*
*  RETURNS:        Nothing
*
*******************************************************************}
procedure realize_cb({%H-}widget: PGtkWidget; user_data: gpointer); cdecl;
var
  wsTrayIcon: TCustomTrayIcon absolute user_data;
begin
  with TGtk2TrayIconHandle(wsTrayIcon.Handle) do
  begin
    {$ifdef HasGdk2X}
    fDisplay := GDK_WINDOW_XDISPLAY(plug^.window);
    fWindow := GDK_WINDOW_XWINDOW(plug^.window);

{  Does not work

    gdk_screen := gtk_widget_get_screen(plug);
    fScreen := GDK_SCREEN_XSCREEN(gdk_screen); // get the real screen}

    fScreen := XDefaultScreenOfDisplay(fDisplay);
    fScreenID := XScreenNumberOfScreen(fScreen); // and it's number
    SetEmbedded;
    {$endif}
  end;
end;

{*******************************************************************
*  button_release_cb ()
*
*  DESCRIPTION:    Callback function for Mouse Click
*
*  PARAMETERS:     None
*
*  RETURNS:        Nothing
*
*******************************************************************}
function button_release_cb({%H-}widget: PGtkWidget; event: PGdkEventButton;
 user_data: gpointer): gboolean; cdecl;
var
  vwsTrayIcon: TCustomTrayIcon absolute user_data;
begin
  Result := False;
  
  case event^.button of
    1:
    begin
      if Assigned(vwsTrayIcon.OnClick) then vwsTrayIcon.OnClick(vwsTrayIcon);
      if Assigned(vwsTrayIcon.OnMouseUp) then
       vwsTrayIcon.OnMouseUp(vwsTrayIcon, mbLeft, [], Round(event^.X), Round(event^.Y));
    end;
    
    2: if Assigned(vwsTrayIcon.OnMouseUp) then
        vwsTrayIcon.OnMouseUp(vwsTrayIcon, mbMiddle, [], Round(event^.X), Round(event^.Y));

    3:
    begin
      if Assigned(vwsTrayIcon.OnMouseUp) then
       vwsTrayIcon.OnMouseUp(vwsTrayIcon, mbRight, [], Round(event^.X), Round(event^.Y));
      if Assigned(vwsTrayIcon.PopUpMenu) then
       vwsTrayIcon.PopUpMenu.PopUp(Mouse.CursorPos.X, Mouse.CursorPos.Y);
     end;
  end;
end;

{*******************************************************************
*  button_press_cb ()
*
*  DESCRIPTION:    Callback function for Mouse Click
*
*  PARAMETERS:     None
*
*  RETURNS:        Nothing
*
*******************************************************************}
function button_press_cb({%H-}widget: PGtkWidget; event: PGdkEventButton;
 user_data: gpointer): gboolean; cdecl;
var
  vwsTrayIcon: TCustomTrayIcon absolute user_data;
begin
  Result := False;

  if (event^._type = GDK_2BUTTON_PRESS) and Assigned(vwsTrayIcon.OnDblClick) then
   vwsTrayIcon.OnDblClick(vwsTrayIcon)
  else
  begin
    case event^.button of
      1: if Assigned(vwsTrayIcon.OnMouseDown) then
          vwsTrayIcon.OnMouseDown(vwsTrayIcon, mbLeft, [], Round(event^.X), Round(event^.Y));

      2: if Assigned(vwsTrayIcon.OnMouseDown) then
          vwsTrayIcon.OnMouseDown(vwsTrayIcon, mbMiddle, [], Round(event^.X), Round(event^.Y));

      3: if Assigned(vwsTrayIcon.OnMouseDown) then
          vwsTrayIcon.OnMouseDown(vwsTrayIcon, mbRight, [], Round(event^.X), Round(event^.Y));
    end;
  end;
end;

{*******************************************************************
*  popup_cb ()
*
*  DESCRIPTION:    Callback function for the popup menu
*
*  PARAMETERS:     None
*
*  RETURNS:        Nothing
*
*******************************************************************}
function popup_cb({%H-}widget: PGtkWidget; user_data: gpointer): Boolean; cdecl;
var
  vwsTrayIcon: TCustomTrayIcon absolute user_data;
begin
  Result := True;

  if Assigned(vwsTrayIcon.PopUpMenu) then
    vwsTrayIcon.PopUpMenu.PopUp(Mouse.CursorPos.X, Mouse.CursorPos.Y);
end;

{*******************************************************************
*  motion_cb ()
*
*  DESCRIPTION:    Callback function for the OnMouseMove event
*
*  PARAMETERS:     None
*
*  RETURNS:        Nothing
*
*******************************************************************}
function motion_cb({%H-}widget: PGtkWidget; event: PGdkEventMotion; user_data: gpointer): Boolean; cdecl;
var
  vwsTrayIcon: TCustomTrayIcon absolute user_data;
begin
  Result := False;

  if Assigned(vwsTrayIcon.OnMouseMove) then
   vwsTrayIcon.OnMouseMove(vwsTrayIcon, [], Round(event^.X), Round(event^.Y));
end;

{$ifdef UseStatusIcon}
procedure activate_cb_statusicon({%H-}status_icon: PGtkStatusIcon; user_data: gpointer); cdecl;
var
  vwsTrayIcon: TCustomTrayIcon absolute user_data;
begin
  if Assigned(vwsTrayIcon.OnMouseDown) then
    with Mouse.CursorPos do
      vwsTrayIcon.OnMouseDown(vwsTrayIcon, mbLeft, [], X, Y);
end;

procedure popup_cb_statusicon({%H-}status_icon: PGtkStatusIcon; {%H-}button: guint;
                {%H-}activate_time: guint; user_data: gpointer); cdecl;
var
  vwsTrayIcon: TCustomTrayIcon absolute user_data;
begin
  if Assigned(vwsTrayIcon.PopUpMenu) then
    vwsTrayIcon.PopUpMenu.PopUp(Mouse.CursorPos.X, Mouse.CursorPos.Y);
end;

function button_press_cb_statusicon({%H-}status_icon: PGtkStatusIcon;
  event: PGdkEvent; user_data: gpointer): gboolean; cdecl;
var
  vwsTrayIcon: TCustomTrayIcon absolute user_data;
begin
  Result := False;

  if (PGdkEventButton(event)^._type = GDK_2BUTTON_PRESS) and Assigned(vwsTrayIcon.OnDblClick) then
   vwsTrayIcon.OnDblClick(vwsTrayIcon)
  else
  begin
    case PGdkEventButton(event)^.button of
      1: if Assigned(vwsTrayIcon.OnMouseDown) then
          vwsTrayIcon.OnMouseDown(vwsTrayIcon, mbLeft, [], Round(PGdkEventButton(event)^.X), Round(PGdkEventButton(event)^.Y));

      2: if Assigned(vwsTrayIcon.OnMouseDown) then
          vwsTrayIcon.OnMouseDown(vwsTrayIcon, mbMiddle, [], Round(PGdkEventButton(event)^.X), Round(PGdkEventButton(event)^.Y));

      3: if Assigned(vwsTrayIcon.OnMouseDown) then
          vwsTrayIcon.OnMouseDown(vwsTrayIcon, mbRight, [], Round(PGdkEventButton(event)^.X), Round(PGdkEventButton(event)^.Y));
    end;
  end;
end;

function button_release_cb_statusicon({%H-}status_icon: PGtkStatusIcon;
  event: PGdkEvent; user_data: gpointer): gboolean; cdecl;
var
  vwsTrayIcon: TCustomTrayIcon absolute user_data;
begin
  Result := False;
  case PGdkEventButton(event)^.button of
    1:
    begin
      if Assigned(vwsTrayIcon.OnClick) then vwsTrayIcon.OnClick(vwsTrayIcon);
      if Assigned(vwsTrayIcon.OnMouseUp) then
       vwsTrayIcon.OnMouseUp(vwsTrayIcon, mbLeft, [], Round(PGdkEventButton(event)^.X), Round(PGdkEventButton(event)^.Y));
    end;
    
    2: if Assigned(vwsTrayIcon.OnMouseUp) then
        vwsTrayIcon.OnMouseUp(vwsTrayIcon, mbMiddle, [], Round(PGdkEventButton(event)^.X), Round(PGdkEventButton(event)^.Y));

    3:
    begin
      if Assigned(vwsTrayIcon.OnMouseUp) then
       vwsTrayIcon.OnMouseUp(vwsTrayIcon, mbRight, [], Round(PGdkEventButton(event)^.X), Round(PGdkEventButton(event)^.Y));
      if Assigned(vwsTrayIcon.PopUpMenu) then
       vwsTrayIcon.PopUpMenu.PopUp(Mouse.CursorPos.X, Mouse.CursorPos.Y);
     end;
  end;
end;

function query_tooltip_cb_statusicon({%H-}status_icon: PGtkStatusIcon;
  x: guint; y: guint; {%H-}keyboard_mode: gboolean; {%H-}tooltip: gpointer{PGtkTooltip}; user_data: gpointer): gboolean; cdecl;
var
  vwsTrayIcon: TCustomTrayIcon absolute user_data;
begin
  Result := FALSE;

  if Assigned(vwsTrayIcon.OnMouseMove) then
   vwsTrayIcon.OnMouseMove(vwsTrayIcon, [], x, y);
end;
{$endif}

constructor TGtk2TrayIconHandle.Create(const wsTrayIcon: TCustomTrayIcon);
begin
  fTrayIcon := wsTrayIcon;

{$ifdef UseStatusIcon}
  FStatusIcon := nil;
  if Available_GtkStatusIcon_2_10 then
  begin
    FStatusIcon := gtk_status_icon_new();
    gtk_status_icon_set_from_pixbuf(FStatusIcon, {%H-}PGdkPixbuf(FTrayIcon.Icon.Handle));
    {$IF FPC_FULLVERSION>30300}
    gtk_status_icon_set_tooltip_text(FStatusIcon, PChar(FTrayIcon.Hint));
    {$ELSE}
    gtk_status_icon_set_tooltip(FStatusIcon, PChar(FTrayIcon.Hint));
    {$ENDIF}
    g_object_set(PGObject(FStatusIcon), 'has-tooltip', gTRUE, nil);
    fEmbedded := gtk_status_icon_is_embedded(FStatusIcon);

    g_signal_connect(FStatusIcon, 'activate', TGCallback(@activate_cb_statusicon), fTrayIcon);
    g_signal_connect(FStatusIcon, 'popup-menu', TGCallback(@popup_cb_statusicon), fTrayIcon);
    g_signal_connect(FStatusIcon, 'button-press-event', TGCallback(@button_press_cb_statusicon), fTrayIcon);
    g_signal_connect(FStatusIcon, 'button-release-event', TGCallback(@button_release_cb_statusicon), fTrayIcon);
    g_signal_connect(FStatusIcon, 'query-tooltip', TGCallback(@query_tooltip_cb_statusicon), fTrayIcon);
  end
  else
{$endif}
  begin
    //  Creates the GtkPlug
    plug := gtk_plug_new(0);
    Tips := gtk_tooltips_new;
    g_object_ref(Tips);
    gtk_object_sink(GTK_OBJECT(Tips));
    gtk_tooltips_set_tip(GTK_TOOLTIPS(Tips), plug, PChar(wsTrayIcon.Hint), '');

    //  Connects the signals
    gtk_widget_add_events(plug, GDK_ALL_EVENTS_MASK);
    g_signal_connect(plug, 'realize', TGCallback(@realize_cb), wsTrayIcon);
    g_signal_connect(plug, 'popup-menu', TGCallback(@popup_cb), wsTrayIcon);
    g_signal_connect(plug, 'motion-notify-event', TGCallback(@motion_cb), wsTrayIcon);
    g_signal_connect(plug, 'button-press-event', TGCallback(@button_press_cb), wsTrayIcon);
    g_signal_connect(plug, 'button-release-event', TGCallback(@button_release_cb), wsTrayIcon);

    //  Draws the icon
    with wsTrayIcon do
    begin
      DrawingArea := gtk_image_new_from_pixbuf({%H-}PGdkPixbuf(Icon.Handle));
      gtk_container_add(GTK_CONTAINER(plug), DrawingArea);
      gtk_widget_show(DrawingArea);
    end;
  end;
end;

destructor TGtk2TrayIconHandle.Destroy;
begin
{$ifdef UseStatusIcon}
  if FStatusIcon <> nil then
  begin
    gtk_status_icon_set_visible(FStatusIcon, False);
    g_object_unref(FStatusIcon);
    FStatusIcon := nil;
  end
  else
{$endif}
  begin
    gtk_widget_destroy(plug);
    plug := nil;

    g_object_unref(Tips);
    Tips := nil;
  end;
end;

procedure TGtk2TrayIconHandle.Show;
begin
{$ifdef UseStatusIcon}
  if FStatusIcon <> nil then
    gtk_status_icon_set_visible(FStatusIcon, True)
  else
{$endif}
    gtk_widget_show(plug);
end;

function TGtk2TrayIconHandle.GetPosition: TPoint;
var
{$ifdef UseStatusIcon}
  AScreen: PGdkScreen;
  AArea: TGdkRectangle;
  AOrientation: TGtkOrientation;
{$endif}
  WindowHandle: PGDKWindow;
begin
{$ifdef UseStatusIcon}
  if FStatusIcon <> nil then
  begin
    gtk_status_icon_get_geometry(FStatusIcon, @AScreen, @AArea, @AOrientation);
    Result.x := AArea.x;
    Result.y := AArea.y;
  end
  else
{$endif}
  begin
    if Assigned(plug) then
    begin
      WindowHandle := plug^.window;
      if Assigned(WindowHandle) then
        gdk_window_get_origin(WindowHandle, @Result.X, @Result.Y);
    end;
  end;
end;

procedure TGtk2TrayIconHandle.Update(NewPixBuf: PGdkPixbuf; const NewHint: String);
begin
{$ifdef UseStatusIcon}
  if FStatusIcon <> nil then
  begin
    gtk_status_icon_set_from_pixbuf(FStatusIcon, NewPixBuf);
    {$IF FPC_FULLVERSION>30300}
    gtk_status_icon_set_tooltip_text(FStatusIcon, PChar(NewHint));
    {$ELSE}
    gtk_status_icon_set_tooltip(FStatusIcon, PChar(NewHint));
    {$ENDIF}
    g_object_set(PGObject(FStatusIcon), 'has-tooltip', gTRUE, nil);
  end
  else
{$endif}
  begin
    // Updates the tooltips
    if Assigned(Tips) then
      gtk_tooltips_set_tip(GTK_TOOLTIPS(Tips), plug, PChar(NewHint), '');
    // Updates the icon
    if Assigned(DrawingArea) then
      gtk_image_set_from_pixbuf(GTK_IMAGE(DrawingArea), NewPixbuf);
  end;
end;

{*******************************************************************
*  TGtk2WSCustomTrayIcon.Hide ()
*
*  DESCRIPTION:    Hides the main tray icon of the program
*
*  PARAMETERS:     None
*
*  RETURNS:        True if sucessfull, otherwise False
*
*******************************************************************}
class function TGtk2WSCustomTrayIcon.Hide(const ATrayIcon: TCustomTrayIcon): Boolean;
begin
  Result := False;

  { Free and nil the handle }
  TGtk2TrayIconHandle(ATrayIcon.Handle).Free;
  ATrayIcon.Handle := 0;

  Result := True;
end;

{*******************************************************************
*  TGtk2WSCustomTrayIcon.Show ()
*
*  DESCRIPTION:    Shows the main tray icon of the program
*
*  PARAMETERS:     None
*
*  RETURNS:        True if sucessfull, otherwise False
*
*******************************************************************}
class function TGtk2WSCustomTrayIcon.Show(const ATrayIcon: TCustomTrayIcon): Boolean;
var
  TrayIconHandle: TGtk2TrayIconHandle;
begin
  Result := False;

  TrayIconHandle := TGtk2TrayIconHandle.Create(ATrayIcon);
  ATrayIcon.Handle := HWND(TrayIconHandle);
  {*******************************************************************
  *  Now shows the GtkPlug
  *******************************************************************}
  TrayIconHandle.Show;
  {$ifdef UseStatusIcon}
  Result := True;
  {$else}
  if TrayIconHandle.fEmbedded then
    Result := True
  else
    Hide(ATrayIcon);
  {$endif}
end;

{*******************************************************************
*  TGtk2WSCustomTrayIcon.InternalUpdate ()
*
*  DESCRIPTION:    Makes modifications to the Icon while running
*                  i.e. without hiding it and showing again
*
*  PARAMETERS:     None
*
*  RETURNS:        Nothing
*
*******************************************************************}
class procedure TGtk2WSCustomTrayIcon.InternalUpdate(const ATrayIcon: TCustomTrayIcon);
begin
  if ATrayIcon.Handle <> 0 then
    TGtk2TrayIconHandle(ATrayIcon.Handle).Update({%H-}PGdkPixbuf(ATrayIcon.Icon.Handle), ATrayIcon.Hint);
end;

{*******************************************************************
*  TGtk2WSCustomTrayIcon.GetPosition ()
*
*  DESCRIPTION:    Returns the position of the tray icon on the display.
*                  This function is utilized to show message boxes near
*                  the icon
*
*  PARAMETERS:     None
*
*  RETURNS:        Nothing
*
*******************************************************************}
class function TGtk2WSCustomTrayIcon.GetPosition(const ATrayIcon: TCustomTrayIcon): TPoint;
begin
  Result := Point(0, 0);
  if ATrayIcon.Handle <> 0 then
    Result := TGtk2TrayIconHandle(ATrayIcon.Handle).GetPosition;
end;


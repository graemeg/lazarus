{
 *****************************************************************************
 *                              Gtk2WSForms.pp                               * 
 *                              --------------                               * 
 *                                                                           *
 *                                                                           *
 *****************************************************************************

 *****************************************************************************
  This file is part of the Lazarus Component Library (LCL)

  See the file COPYING.modifiedLGPL.txt, included in this distribution,
  for details about the license.
 *****************************************************************************
}
unit Gtk2WSForms;

{$mode objfpc}{$H+}
{$I gtk2defines.inc}
interface

uses
  // RTL
  Gtk2, Glib2, Gdk2, Gdk2Pixbuf,
  {$IFDEF HASX}
  Gdk2x, X, XLib,
  {$ENDIF}
  Math, types, Classes,
  // LCL
  LCLType, Controls, LMessages, InterfaceBase, Graphics, Forms,
  Gtk2Int, Gtk2Proc, Gtk2Def, Gtk2Extra, Gtk2Globals, Gtk2WSControls,
  WSForms, WSProc,
  // LazUtils
  LazLoggerBase;

type

  { TGtk2WSScrollingWinControl }

  TGtk2WSScrollingWinControl = class(TWSScrollingWinControl)
  protected
    class procedure SetCallbacks(const AWidget: PGtkWidget; const AWidgetInfo: PWidgetInfo); virtual;
  published
    class function CreateHandle(const AWinControl: TWinControl; const AParams: TCreateParams): TLCLIntfHandle; override;
    class procedure SetColor(const AWinControl: TWinControl); override;
  end;

  { TGtk2WSScrollBox }

  TGtk2WSScrollBox = class(TWSScrollBox)
  published
  end;

  { TGtk2WSCustomFrame }

  TGtk2WSCustomFrame = class(TWSCustomFrame)
  published
  end;

  { TGtk2WSFrame }

  TGtk2WSFrame = class(TWSFrame)
  published
  end;

  { TGtk2WSCustomForm }

  TGtk2WSCustomForm = class(TWSCustomForm)
  protected
    class procedure SetCallbacks(const AWidget: PGtkWidget; const AWidgetInfo: PWidgetInfo); virtual;
  published
    class function CanFocus(const AWinControl: TWinControl): Boolean; override;
    class function CreateHandle(const AWinControl: TWinControl; const AParams: TCreateParams): TLCLIntfHandle; override;
    class procedure ScrollBy(const AWinControl: TWinControl; DeltaX, DeltaY: integer); override;
    class procedure SetIcon(const AForm: TCustomForm; const Small, Big: HICON); override;
    class procedure SetAlphaBlend(const ACustomForm: TCustomForm;
       const AlphaBlend: Boolean; const Alpha: Byte); override;
    class procedure SetFormBorderStyle(const AForm: TCustomForm;
                             const AFormBorderStyle: TFormBorderStyle); override;
    class procedure SetFormStyle(const AForm: TCustomform; const AFormStyle,
                       {%H-}AOldFormStyle: TFormStyle); override;
    class procedure SetAllowDropFiles(const AForm: TCustomForm; AValue: Boolean); override;
    class procedure SetShowInTaskbar(const AForm: TCustomForm; const AValue: TShowInTaskbar); override;
    class procedure ShowHide(const AWinControl: TWinControl); override;
    class procedure ShowModal(const {%H-}AForm: TCustomForm); override;
    class procedure SetBorderIcons(const AForm: TCustomForm;
                                   const ABorderIcons: TBorderIcons); override;
    class procedure SetColor(const AWinControl: TWinControl); override;
    class procedure SetRealPopupParent(const ACustomForm: TCustomForm;
       const APopupParent: TCustomForm); override;
  end;

  { TGtk2WSForm }

  TGtk2WSForm = class(TWSForm)
  published
  end;

  { TGtk2WSHintWindow }

  TGtk2WSHintWindow = class(TWSHintWindow)
  protected
    class procedure SetCallbacks(const AWidget: PGtkWidget; const AWidgetInfo: PWidgetInfo); virtual;
  published
    class function  CreateHandle(const AWinControl: TWinControl; const AParams: TCreateParams): TLCLIntfHandle; override;
    class procedure ShowHide(const AWinControl: TWinControl); override;
  end;

  { TGtk2WSScreen }

  TGtk2WSScreen = class(TWSScreen)
  published
  end;

  { TGtk2WSApplicationProperties }

  TGtk2WSApplicationProperties = class(TWSApplicationProperties)
  published
  end;

implementation

{ TGtk2WSCustomForm }

function gtk2WSDelayedWindowStateChange(Data: Pointer): gboolean; cdecl;
var
  AnForm: TCustomForm absolute data;
  AEvent: TGdkEventWindowState;
begin
  Result := False;
  AEvent := GetWidgetInfo({%H-}PGtkWidget(AnForm.Handle))^.FormWindowState;
  GTKWindowStateEventCB({%H-}PGtkWidget(AnForm.Handle), @AEvent, Data);
  // remove idle handler, because in fast switching hide/show there could
  // be dozen of added idle handlers, only one should be here.
  // also reset our internal flag on send_event.
  GetWidgetInfo({%H-}PGtkWidget(AnForm.Handle))^.FormWindowState.send_event := 0;
  g_idle_remove_by_data(Data);
end;

function Gtk2FormEvent(widget: PGtkWidget; event: PGdkEvent; data: GPointer): gboolean; cdecl;
var
  ACtl: TWinControl;
  Mess : TLMessage;
  WInfo: PWidgetInfo;
  X,Y: integer;
  {$IFDEF HASX}
  XDisplay: PDisplay;
  Window: TWindow;
  RevertStatus: Integer;
  winX, winY, winW, winH: gint;
  {$ENDIF}

begin
  Result := CallBackDefaultReturn;
  case event^._type of
    GDK_CONFIGURE:
      begin
        {fixes multiple resize events. See comments on
        http://bugs.freepascal.org/view.php?id=17015}
        ACtl := TWinControl(Data);
        GetWidgetRelativePosition({%H-}PGtkWidget(ACtl.Handle), X, Y);
        Result := (event^.configure.send_event = 1) and
          not ((X <> ACtl.Left) or (Y <> ACtl.Top));

        {$IFDEF HASX}
        // fix for buggy compiz.
        // see http://bugs.freepascal.org/view.php?id=17523
        if Gtk2WidgetSet.compositeManagerRunning then
        begin
          // issue #25473, compositing manager eg. Mutter (Mint 16) makes
          // complete mess with lcl<->gtk2<->x11 when our form is designed.
          if (csDesigning in ACtl.ComponentState) and
          // issue #26349.This patch is related only to Mint window manager !
            (Copy(Gtk2WidgetSet.GetWindowManager,1,6) = 'mutter') then
          begin
            gdk_window_get_geometry(event^.configure.window, @winX, @winY, @winW, @winH, nil);
            if (winW <> event^.configure.width) or (winH <> event^.configure.height) then
            begin
              // goto hell
              {$IF DEFINED(VerboseSizeMsg) OR DEFINED(VerboseGetClientRect)}
              DebugLn('Warning: GDK_CONFIGURE: Designed form is misconfigured because of bad compositing manager (see issue #25473).');
              DebugLn('Warning: GDK_CONFIGURE: Fixing problem by setting current LCL values ',dbgs(ACtl.BoundsRect));
              {$ENDIF}
              Result := True;
              gdk_window_move_resize(event^.configure.window, ACtl.Left, ACtl.Top, ACtl.Width, ACtl.Height);
              exit;
            end;
          end;
          if (X <> ACtl.Left) or (Y <> ACtl.Top) then
            Result := gtkconfigureevent(widget, PGdkEventConfigure(event),
              Data)
          else
            Result := False;
        end;
        {$ENDIF}
      end;
    GDK_WINDOW_STATE:
      begin

        if (GDK_WINDOW_STATE_WITHDRAWN and event^.window_state.changed_mask) = 1 then
          exit;

        {$IFDEF HASX}
        WInfo := GetWidgetInfo(Widget);
        if (event^.window_state.new_window_state = GDK_WINDOW_STATE_ICONIFIED) then
        begin
          if not Gtk2WidgetSet.IsCurrentDesktop(event^.window_state.window) then
          begin
            WInfo := GetWidgetInfo(Widget);
            if (WInfo <> nil) and (WInfo^.LCLObject = Application.MainForm) then
            begin
              g_object_set_data(PGObject(Widget), 'lclhintrestore', Pointer(1));
              GTK2WidgetSet.HideAllHints;
              WInfo^.FormWindowState := Event^.window_state;
              exit;
            end;
          end;
        end;
        if (event^.window_state.new_window_state <> GDK_WINDOW_STATE_ICONIFIED) and
          (WInfo <> nil) and (WInfo^.LCLObject = Application.MainForm) and
          (event^.window_state.changed_mask = GDK_WINDOW_STATE_ICONIFIED) and
          (WInfo^.FormWindowState.new_window_state = GDK_WINDOW_STATE_ICONIFIED) and
          (g_object_get_data(PGObject(Widget), 'lclhintrestore') <> nil) then
        begin
          g_object_set_data(PGObject(Widget), 'lclhintrestore', nil);
          Gtk2WidgetSet.RestoreAllHints;
          WInfo^.FormWindowState := Event^.window_state;
          exit;
        end;
        {$ELSE}
        WInfo := GetWidgetInfo(Widget);
        {$ENDIF}
        if (WInfo <> nil) then
        begin
          if (WInfo^.FormWindowState.new_window_state <> event^.window_state.new_window_state)
           and (WInfo^.FormWindowState.send_event <> 2) then
          begin
            WInfo^.FormWindowState := Event^.window_state;
            // needed to lock recursions, normally send_event can be 0 or 1
            // we add 2 to know if recursion occurred.
            WInfo^.FormWindowState.send_event := 2;
            g_idle_add(@gtk2WSDelayedWindowStateChange, Data);
          end else
          begin
            // our send_event flag is 2, mean recursion occurred
            // so we have to normalize things first.
            while WInfo^.FormWindowState.send_event = 2 do
            begin
             Application.Idle(True);
             Application.ProcessMessages;
            end;
            WInfo^.FormWindowState.send_event := 0;
            Result := GTKWindowStateEventCB(Widget, @event^.window_state, Data);
          end;
        end;
      end;
    GDK_ENTER_NOTIFY:
      begin
        FillChar(Mess{%H-}, SizeOf(Mess), #0);
        Mess.msg := LM_MOUSEENTER;
        DeliverMessage(Data, Mess);
      end;
    GDK_LEAVE_NOTIFY:
      begin
        FillChar(Mess, SizeOf(Mess), #0);
        Mess.msg := LM_MOUSELEAVE;
        DeliverMessage(Data, Mess);
      end;
    GDK_FOCUS_CHANGE:
      begin
        ACtl := TWinControl(Data);
        if PGdkEventFocus(event)^._in = 0 then
        begin
          {$IFDEF HASX}
          XDisplay := gdk_display;
          XGetInputFocus(XDisplay, @Window, @RevertStatus);
          // Window - 1 is our frame  !
          if (RevertStatus = RevertToParent) and
            (GDK_WINDOW_XID(Widget^.Window) = Window - 1) then
            exit(True);
          {$ENDIF}
          with Gtk2WidgetSet do
          begin
            LastFocusOut := {%H-}PGtkWidget(ACtl.Handle);
            if LastFocusOut = LastFocusIn then
              StartFocusTimer;
          end;
        end else
        begin
          with Gtk2WidgetSet do
          begin
            LastFocusIn := {%H-}PGtkWidget(ACtl.Handle);
            if not AppActive then
              AppActive := True;
          end;
        end;
        if GTK_IS_WINDOW(Widget) and
          (g_object_get_data({%H-}PGObject(ACtl.Handle),'lcl_nonmodal_over_modal') <> nil) then
        begin
          if PGdkEventFocus(event)^._in = 0 then
            gtk_window_set_modal({%H-}PGtkWindow(ACtl.Handle), False)
          else
            gtk_window_set_modal({%H-}PGtkWindow(ACtl.Handle), True);
        end;
      end;
  end;
end;

class procedure TGtk2WSCustomForm.SetCallbacks(const AWidget: PGtkWidget;
  const AWidgetInfo: PWidgetInfo);
begin
  TGtk2WSWinControl.SetCallbacks(PGtkObject(AWidget), TComponent(AWidgetInfo^.LCLObject));
  if (TWinControl(AWidgetInfo^.LCLObject).Parent = nil) and (TWinControl(AWidgetInfo^.LCLObject).ParentWindow = 0) then
    with TGTK2WidgetSet(Widgetset) do
    begin
      {$IFDEF HASX}
      // fix for buggy compiz.
      // see http://bugs.freepascal.org/view.php?id=17523
      if not compositeManagerRunning then
      {$ENDIF}
         SetCallback(LM_CONFIGUREEVENT, PGtkObject(AWidget), AWidgetInfo^.LCLObject);
      SetCallback(LM_CLOSEQUERY, PGtkObject(AWidget), AWidgetInfo^.LCLObject);
      SetCallBack(LM_ACTIVATE, PGtkObject(AWidget), AWidgetInfo^.LCLObject);
      if (gtk_major_version = 2) and (gtk_minor_version <= 8) then
      begin
        SetCallback(LM_HSCROLL, PGtkObject(AWidget), AWidgetInfo^.LCLObject);
        SetCallback(LM_VSCROLL, PGtkObject(AWidget), AWidgetInfo^.LCLObject);
      end;
    end;

  g_signal_connect(PGtkObject(AWidgetInfo^.CoreWidget), 'event',
    gtk_signal_func(@Gtk2FormEvent), AWidgetInfo^.LCLObject);
end;

class function TGtk2WSCustomForm.CanFocus(const AWinControl: TWinControl
  ): Boolean;
var
  Widget: PGtkWidget;
begin
  if AWinControl.HandleAllocated then
  begin
    Widget := {%H-}PGtkWidget(AWinControl.Handle);
    Result := GTK_WIDGET_VISIBLE(Widget) and GTK_WIDGET_SENSITIVE(Widget);
  end else
    Result := False;
end;

class function TGtk2WSCustomForm.CreateHandle(const AWinControl: TWinControl;
  const AParams: TCreateParams): TLCLIntfHandle;
var
  WidgetInfo: PWidgetInfo;
  p: pointer;          // ptr to the newly created GtkWidget
  Box: Pointer;
  ABorderStyle: TFormBorderStyle;
  WindowType: TGtkWindowType;
  ACustomForm: TCustomForm;
  AResizable: gint;
  Allocation: TGtkAllocation;
begin
  // Start of old CreateForm method
  ACustomForm := TCustomForm(AWinControl);

  if (AParams.Style and WS_CHILD) = 0 then
  begin
    if csDesigning in ACustomForm.ComponentState then
      ABorderStyle := bsSizeable
    else
      ABorderStyle := ACustomForm.BorderStyle;
  end
  else
    ABorderStyle := bsNone;

  // Maps the border style
  WindowType := FormStyleMap[ABorderStyle];
  if (csDesigning in ACustomForm.ComponentState) then
    WindowType := GTK_WINDOW_TOPLEVEL;

  if (AParams.Style and WS_CHILD) = 0 then
  begin
    // create a floating form
    P := gtk_window_new(WindowType);

    // This is done with the expectation to avoid the button blinking for forms
    //that hide it, but currently it doesn't seem to make a difference.
    gtk_window_set_skip_taskbar_hint(P, True);

    if (ABorderStyle = bsNone) and (ACustomForm.FormStyle in fsAllStayOnTop) then
      gtk_window_set_decorated(PGtkWindow(P), False);

    // Sets the window as resizable or not
    // Depends on the WM supporting this
    if (csDesigning in ACustomForm.ComponentState) then
      AResizable := 1
    else
      AResizable := FormResizableMap[ABorderStyle];

    // gtk_window_set_policy is deprecated in Gtk2
    gtk_window_set_resizable(GTK_WINDOW(P), gboolean(AResizable));

    // Sets the title
    gtk_window_set_title(PGtkWindow(P), AParams.Caption);

    if (AParams.WndParent <> 0) then
      gtk_window_set_transient_for(PGtkWindow(P), {%H-}PGtkWindow(AParams.WndParent))
    else
    if not (csDesigning in ACustomForm.ComponentState) and
      (ACustomForm.FormStyle in fsAllStayOnTop) then
      gtk_window_set_keep_above(PGtkWindow(P), gboolean(True));

    // the clipboard needs a widget
    if (ClipboardWidget = nil) then
      Gtk2WidgetSet.SetClipboardWidget(P);
  end
  else
  begin
    // create a form as child control
    P := gtk_hbox_new(false, 0);
  end;

{$IFDEF HASX}
  if (AWinControl = Application.MainForm) and
    not Application.HasOption('disableaccurateframe') then
      Gtk2WidgetSet.CreateDummyWidgetFrame(-1, -1, -1, -1);
{$ENDIF}

  WidgetInfo := CreateWidgetInfo(P, AWinControl, AParams);
  WidgetInfo^.FormBorderStyle := Ord(ABorderStyle);

  FillChar(WidgetInfo^.FormWindowState, SizeOf(WidgetInfo^.FormWindowState), #0);
  WidgetInfo^.FormWindowState.new_window_state := GDK_WINDOW_STATE_WITHDRAWN;

  Box := CreateFormContents(ACustomForm, P, WidgetInfo);
  gtk_container_add(PGtkContainer(P), Box);

  //so we can double buffer ourselves, eg, the Form Designer
  if csDesigning in AWinControl.ComponentState then
    gtk_widget_set_double_buffered(Box, False);

  gtk_widget_show(Box);

  // main menu
  if (ACustomForm.Menu <> nil) and (ACustomForm.Menu.HandleAllocated) then
    gtk_box_pack_start(Box, {%H-}PGtkWidget(ACustomForm.Menu.Handle), False, False,0);

  // End of the old CreateForm method

  {$IFNDEF NoStyle}
  if (AParams.Style and WS_CHILD) = 0 then
    gtk_widget_set_app_paintable(P, True);
  {$ENDIF}

  if not (csDesigning in AWinControl.ComponentState) then
    WidgetInfo^.UserData := Pointer(1);

  Allocation.X := AParams.X;
  Allocation.Y := AParams.Y;
  Allocation.Width := AParams.Width;
  Allocation.Height := AParams.Height;
  gtk_widget_size_allocate(P, @Allocation);

  {$IFDEF DebugLCLComponents}
  DebugGtkWidgets.MarkCreated(P, dbgsName(AWinControl));
  {$ENDIF}
  Result := TLCLIntfHandle({%H-}PtrUInt(P));
  Set_RC_Name(AWinControl, P);
  SetCallbacks(P, WidgetInfo);
end;

function Gtk2WSDelayRedraw(Data: Pointer): GBoolean; cdecl;
begin
  Result := False;
  gtk_widget_queue_draw(PWidgetInfo(Data)^.ClientWidget);
  g_idle_remove_by_data(Data);
end;

class procedure TGtk2WSCustomForm.ScrollBy(const AWinControl: TWinControl; DeltaX, DeltaY: integer);
var
  Layout: PGtkLayout;
  WidgetInfo: PWidgetInfo;
  Adjustment: PGtkAdjustment;
  h, v: Double;
  NewPos: Double;
begin
  if not AWinControl.HandleAllocated then exit;
  WidgetInfo := GetWidgetInfo({%H-}PGtkWidget(AWinControl.Handle));
  Layout := PGtkLayout(WidgetInfo^.ClientWidget);
  Adjustment := gtk_layout_get_hadjustment(Layout);
  if Adjustment <> nil then
  begin
    h := gtk_adjustment_get_value(Adjustment);
    NewPos := Adjustment^.upper - Adjustment^.page_size;
    if h - DeltaX <= NewPos then
      NewPos := h - DeltaX;
    if gtk_adjustment_get_value(Adjustment) <> NewPos then
    begin
      gtk_adjustment_set_value(Adjustment, NewPos);
      //if our adjustment reached end, scrollbar button is disabled
      //so gtk blocks paints for some reason, so we must postpone an update
      if NewPos >= Adjustment^.upper - Adjustment^.page_size then
        g_idle_add(@Gtk2WSDelayRedraw, WidgetInfo);
    end;
  end;
  Adjustment := gtk_layout_get_vadjustment(Layout);
  if Adjustment <> nil then
  begin
    v := gtk_adjustment_get_value(Adjustment);
    NewPos := Adjustment^.upper - Adjustment^.page_size;
    if v - DeltaY <= NewPos then
      NewPos := v - DeltaY;
    if gtk_adjustment_get_value(Adjustment) <> NewPos then
    begin
      gtk_adjustment_set_value(Adjustment, NewPos);
      //if our adjustment reached end, scrollbar button is disabled
      //so gtk blocks paints for some reason, so we must postpone an update
      if NewPos >= Adjustment^.upper - Adjustment^.page_size then
        g_idle_add(@Gtk2WSDelayRedraw, WidgetInfo);
    end;
  end;
end;

class procedure TGtk2WSCustomForm.SetIcon(const AForm: TCustomForm;
  const Small, Big: HICON);

  procedure SetSmallBigIcon;
  var
    List: PGList;
  begin
    List := nil;
    if Small <> 0 then
      List := g_list_append(List, {%H-}PGdkPixbuf(Small));
    if Big <> 0 then
      List := g_list_append(List, {%H-}PGdkPixbuf(Big));
    gtk_window_set_icon_list({%H-}PGtkWindow(AForm.Handle), List);
    if List <> nil
    then  g_list_free(List);
  end;

  {$IFDEF Gtk2SetIconAll}
  procedure SetAllIcons;
  var
    List: PGList;
    Icon: TIcon;
    CurSize: Integer;
    i: Integer;
    LastIndex: Integer;
    OldChange: TNotifyEvent;
    OldCurrent: Integer;
    IconHnd: HICON;
  begin
    List := nil;
    //debugln(['TGtk2WSCustomForm.SetIcon Form=',DbgSName(AForm)]);
    Icon:=AForm.Icon;
    if (Icon=nil) or Icon.Empty then
      Icon:=Application.Icon;
    if Assigned(Icon) and not Icon.Empty then
    begin
      CurSize:=16;
      OldChange:=Icon.OnChange;
      OldCurrent:=Icon.Current;
      Icon.OnChange := nil;
      LastIndex:=-1;
      while CurSize<=256 do begin
        i:=Icon.GetBestIndexForSize(Size(CurSize,CurSize));
        if (i>=0) and (LastIndex<>i) then begin
          Icon.Current := i;
          IconHnd:=Icon.ReleaseHandle;
          if IconHnd <> 0 then
            List := g_list_append(List, {%H-}PGdkPixbuf(IconHnd));
          //debugln(['TGtk2WSCustomForm.SetIcon adding ',CurSize]);
          LastIndex:=i;
        end;
        CurSize:=CurSize*2;
      end;
      Icon.Current:=OldCurrent;
      Icon.OnChange:=OldChange;
    end;
    gtk_window_set_icon_list({%H-}PGtkWindow(AForm.Handle), List);
    if List <> nil
    then  g_list_free(List);
  end;
  {$ENDIF}

  {$IFDEF Gtk2SetIconFile}
  procedure SetIconFromFile;
  var
    Filename: String;
  begin
    Filename:='test128x128.png';
    debugln(['SetIconFromFile filename=',Filename]);
    gtk_window_set_icon_from_file({%H-}PGtkWindow(AForm.Handle),PGChar(Filename),null);
    debugln(['SetIconFromFile prg name="',g_get_prgname,'"']);
  end;
  {$ENDIF}

begin
  if not WSCheckHandleAllocated(AForm, 'SetIcon')
  then Exit;

  if (AForm.Parent <> nil) or (AForm.ParentWindow <> 0) then Exit;

  {$IFDEF Gtk2SetIconAll}
  SetAllIcons;
  {$ELSE}
    {$IFDEF Gtk2SetIconFile}
    SetIconFromFile;
    {$ELSE}
    SetSmallBigIcon;
    {$ENDIF}
  {$ENDIF}
end;

class procedure TGtk2WSCustomForm.SetAlphaBlend(const ACustomForm: TCustomForm;
  const AlphaBlend: Boolean; const Alpha: Byte);
begin
  if not WSCheckHandleAllocated(ACustomForm, 'SetAlphaBlend') then
    Exit;
  if Assigned(gtk_window_set_opacity) and GTK_IS_WINDOW({%H-}PGtkWidget(ACustomForm.Handle)) then
    if AlphaBlend then
      gtk_window_set_opacity({%H-}PGtkWindow(ACustomForm.Handle), Alpha / 255)
    else
      gtk_window_set_opacity({%H-}PGtkWindow(ACustomForm.Handle), 1);
end;

class procedure TGtk2WSCustomForm.SetFormBorderStyle(const AForm: TCustomForm;
  const AFormBorderStyle: TFormBorderStyle);
var
  Widget: PGtkWidget;
  WidgetInfo: PWidgetInfo;
  // WindowType: TGtkWindowType;
  Resizable: gint;
begin
  if not WSCheckHandleAllocated(AForm, 'SetFormBorderStyle') then
    exit;
  if (csDesigning in AForm.ComponentState) then
    exit;

  Widget := {%H-}PGtkWidget(AForm.Handle);
  WidgetInfo := GetWidgetInfo(Widget);

  if (WidgetInfo^.FormBorderStyle <> Ord(AFormBorderStyle)) then
  begin
    if (AForm.Parent<>nil) then
    begin
      // a nested form
      // at the moment the gtk interface does not support any border for this
    end else if (AFormBorderStyle <> bsNone) then
    begin
      // the borderstyle can be only set on creation
      RecreateWnd(AForm);
    end else
    begin
      // TODO: set window hint WindowType := FormStyleMap[AFormBorderStyle];
      Resizable := FormResizableMap[AFormBorderStyle];
      if (AFormBorderStyle = bsNone) then
        gtk_window_set_decorated(PGtkWindow(Widget), False);
      gtk_window_set_resizable(GTK_WINDOW(Widget), gboolean(Resizable));
      WidgetInfo^.FormBorderStyle := Ord(AFormBorderStyle);
    end;
  end;
end;

class procedure TGtk2WSCustomForm.SetFormStyle(const AForm: TCustomform;
  const AFormStyle, AOldFormStyle: TFormStyle);
begin
  if not WSCheckHandleAllocated(AForm, 'SetFormStyle') then
    exit;
  if (csDesigning in AForm.ComponentState) then
    exit;
  if GTK_IS_WINDOW({%H-}PGtkWindow(AForm.Handle)) then
    gtk_window_set_keep_above({%H-}PGtkWindow(AForm.Handle),
      GBoolean(AFormStyle in fsAllStayOnTop));
end;

class procedure TGtk2WSCustomForm.SetAllowDropFiles(const AForm: TCustomForm;
  AValue: Boolean);
begin
  if AValue then
    gtk_drag_dest_set({%H-}PGtkWidget(AForm.Handle), GTK_DEST_DEFAULT_ALL,
      @FileDragTarget, 1, GDK_ACTION_COPY or GDK_ACTION_MOVE)
  else
    gtk_drag_dest_unset({%H-}PGtkWidget(AForm.Handle));
end;

class procedure TGtk2WSCustomForm.SetShowInTaskbar(const AForm: TCustomForm;
  const AValue: TShowInTaskbar);
begin
  if not WSCheckHandleAllocated(AForm, 'SetShowInTaskbar')
  then Exit;

  SetFormShowInTaskbar(AForm,AValue);
end;

class procedure TGtk2WSCustomForm.ShowHide(const AWinControl: TWinControl);
var
  {$IFDEF HASX}
  TempGdkWindow: PGdkWindow;
  {$ENDIF}
  AForm, APopupParent: TCustomForm;
  GtkWindow: PGtkWindow;
  Geometry: TGdkGeometry;

  function ShowNonModalOverModal: Boolean;
  var
    AForm: TCustomForm;
    AWindow: PGtkWindow;
  begin
    Result := False;
    AForm := TCustomForm(AWinControl);
    if AWinControl.HandleObjectShouldBeVisible and
      not (csDesigning in AForm.ComponentState) and
      not (fsModal in AForm.FormState) and
      (AForm.Parent = nil) and
      (AForm.FormStyle <> fsMDIChild) and
      (ModalWindows <> nil) and (ModalWindows.Count > 0) and
      not (AForm.FormStyle in fsAllStayOnTop) and
      (AForm.BorderStyle in [bsDialog, bsSingle, bsSizeable]) and
      (AForm.PopupParent = nil) and (AForm.PopupMode = pmNone) then
    begin
      AWindow := {%H-}PGtkWindow(AForm.Handle);
      gtk_window_set_modal(AWindow, True);
      // lcl_nonmodal_over_modal is needed to track nonmodal form
      // created and shown when we have active modal forms
      g_object_set_data(PGObject(AWindow),'lcl_nonmodal_over_modal', AForm);
      Result := True;
    end;
  end;
begin
  AForm := TCustomForm(AWinControl);
  if not (csDesigning in AForm.ComponentState) then
  begin
    if AForm.HandleObjectShouldBeVisible and
      GTK_IS_WINDOW({%H-}PGtkWindow(AForm.Handle)) then
      begin
        gtk_window_set_keep_above({%H-}PGtkWindow(AForm.Handle),
          GBoolean(AForm.FormStyle in fsAllStayOnTop))
      end
    else
    if (AForm.FormStyle in fsAllStayOnTop) and
      not (csDestroying in AWinControl.ComponentState) then
        gtk_window_set_keep_above({%H-}PGtkWindow(AForm.Handle), GBoolean(False));
  end;

  GtkWindow := {%H-}PGtkWindow(AForm.Handle);

  if (fsModal in AForm.FormState) and AForm.HandleObjectShouldBeVisible then
  begin
    gtk_window_set_default_size(GtkWindow, Max(1,AForm.Width), Max(1,AForm.Height));
    gtk_widget_set_uposition(PGtkWidget(GtkWindow), AForm.Left, AForm.Top);
    gtk_window_set_type_hint({%H-}PGtkWindow(AForm.Handle),
       GtkWindowTypeHints[AForm.BorderStyle]);
    GtkWindowShowModal(AForm, GtkWindow);
  end else
  begin
    if ShowNonModalOverModal then begin
      // issue #21459
    end
    else if not GTK_IS_WINDOW(GtkWindow) then begin
      //
    end
    else if (AForm.FormStyle <> fsMDIChild) and AForm.HandleObjectShouldBeVisible
      and (ModalWindows <> nil) and (ModalWindows.Count > 0)
      and (AForm.PopupParent = nil) and (AForm.BorderStyle = bsNone)
    then begin
      // showing a non modal form with bsNone above a modal form
      gtk_window_set_transient_for(GtkWindow, nil);
      gtk_window_set_modal(GtkWindow, True);
    end else begin
      // hiding/showing normal form
      // clear former mods, e.g. when a modal form becomes a normal form, see bug 23876
      {$IFDEF HASX}
      gtk_window_set_modal(GtkWindow, False);
      gtk_window_set_transient_for(GtkWindow, nil); //untransient
      {$ELSE}
      gtk_window_set_transient_for(GtkWindow, nil); //untransient
      gtk_window_set_modal(GtkWindow, False);
      {$ENDIF}
    end;

    {$IFDEF HASX}
    // issue #26018
    if AWinControl.HandleObjectShouldBeVisible and
      not (csDesigning in AForm.ComponentState) and
      not (AForm.FormStyle in fsAllStayOnTop) and
      not (fsModal in AForm.FormState) and
      (AForm.PopupMode = pmAuto) and
      (AForm.BorderStyle = bsNone) and
      (AForm.PopupParent = nil) then
    begin
      TempGdkWindow := {%H-}PGdkWindow(Gtk2WidgetSet.GetForegroundWindow);
      if (TempGdkWindow <> nil) and (GdkWindowObject_modal_hint(GDK_WINDOW_OBJECT(TempGdkWindow)^) = 0) then
      begin
        if ((gdk_window_get_state(TempGdkWindow) and GDK_WINDOW_STATE_ABOVE) = GDK_WINDOW_STATE_ABOVE) or
          GTK2WidgetSet.GetAlwaysOnTopX11(TempGdkWindow) then
            gtk_window_set_keep_above(GtkWindow, True);
      end;
    end;

    if AWinControl.HandleObjectShouldBeVisible and
      not (csDesigning in AForm.ComponentState) and
      not (AForm.FormStyle in fsAllStayOnTop) and
      not (fsModal in AForm.FormState) then
    begin
      APopupParent := AForm.GetRealPopupParent;
      if (APopupParent <> nil) then
        SetRealPopupParent(AForm, APopupParent);
    end;
    {$ENDIF}

    Gtk2WidgetSet.SetVisible(AWinControl, AForm.HandleObjectShouldBeVisible);
  end;

  if not (csDesigning in AForm.ComponentState) and
    AForm.HandleObjectShouldBeVisible and
    (AForm.BorderStyle in [bsDialog, bsSingle]) then
  begin
    // we must set fixed size, gtk_window_set_resizable does not work
    // as expected for some reason.issue #20741
    with Geometry do
    begin
      min_width := AForm.Width;
      max_width := AForm.Width;
      min_height := AForm.Height;
      max_height := AForm.Height;

      base_width := AForm.Width;
      base_height := AForm.Height;
      width_inc := 1;
      height_inc := 1;
      min_aspect := 0;
      max_aspect := 1;
      win_gravity := gtk_window_get_gravity(GtkWindow);
    end;
    //debugln('TGtk2WSWinControl.ConstraintsChange A ',GetWidgetDebugReport(Widget),' max=',dbgs(Geometry.max_width),'x',dbgs(Geometry.max_height));
    gtk_window_set_geometry_hints(GtkWindow, nil, @Geometry,
      GDK_HINT_POS or GDK_HINT_MIN_SIZE or GDK_HINT_MAX_SIZE);
  end;

  if not (csDesigning in AForm.ComponentState) and
    AForm.HandleObjectShouldBeVisible and (AForm.WindowState = wsFullScreen) then
      gtk_window_fullscreen(GtkWindow);


  InvalidateLastWFPResult(AWinControl, AWinControl.BoundsRect);
end;

class procedure TGtk2WSCustomForm.ShowModal(const AForm: TCustomForm);
begin
  // modal is started in ShowHide
end;

class procedure TGtk2WSCustomForm.SetBorderIcons(const AForm: TCustomForm;
  const ABorderIcons: TBorderIcons);
begin
  if not WSCheckHandleAllocated(AForm, 'SetBorderIcons')
  then Exit;

  inherited SetBorderIcons(AForm, ABorderIcons);
end;

class procedure TGtk2WSCustomForm.SetColor(const AWinControl: TWinControl);
var
  AScrolled: PGtkWidget;
  AColor: TColor;
begin
  TGtk2WSWinControl.SetColor(AWinControl);

  // Forms: GtkWindow->GtkVBox->gtkScrolledWindow->GtkLayout
  // we need to set the color of the GtkLayout so that the whole viewport
  // will be filled (issue #16183)
  AScrolled := g_object_get_data({%H-}PGObject(AWinControl.Handle), odnScrollArea);
  if GTK_IS_SCROLLED_WINDOW(AScrolled) and
    GTK_IS_LAYOUT({%H-}PGtkBin(AScrolled)^.child) then
  begin
    AColor := AWinControl.Color;
    if AColor = clDefault then
      AColor := GetDefaultColor(AWinControl, dctBrush);
    Gtk2WidgetSet.SetWidgetColor({%H-}PGtkBin(AScrolled)^.child,
                                 clNone, AColor,
                                 [GTK_STATE_NORMAL, GTK_STATE_ACTIVE,
                                  GTK_STATE_PRELIGHT, GTK_STATE_SELECTED]);
  end;
end;

class procedure TGtk2WSCustomForm.SetRealPopupParent(
  const ACustomForm: TCustomForm; const APopupParent: TCustomForm);
begin
  if not WSCheckHandleAllocated(ACustomForm, 'SetRealPopupParent') then Exit;

  if APopupParent <> nil then
    gtk_window_set_transient_for({%H-}PGtkWindow(ACustomForm.Handle), {%H-}PGtkWindow(APopupParent.Handle))
  else
    gtk_window_set_transient_for({%H-}PGtkWindow(ACustomForm.Handle), nil);
end;


{ TGtk2WSScrollingWinControl }

class procedure TGtk2WSScrollingWinControl.SetCallbacks(
  const AWidget: PGtkWidget; const AWidgetInfo: PWidgetInfo);
var
  UseScrollCallback: Boolean;
begin
  TGtk2WSWinControl.SetCallbacks(PGtkObject(AWidget), TComponent(AWidgetInfo^.LCLObject));
  with TGTK2WidgetSet(Widgetset) do
  begin
    UseScrollCallBack := (gtk_major_version = 2) and (gtk_minor_version <= 8);
    if UseScrollCallBack then
    begin
      SetCallback(LM_HSCROLL, PGtkObject(AWidget), AWidgetInfo^.LCLObject);
      SetCallback(LM_VSCROLL, PGtkObject(AWidget), AWidgetInfo^.LCLObject);
    end;
  end;
end;

class function TGtk2WSScrollingWinControl.CreateHandle(
  const AWinControl: TWinControl; const AParams: TCreateParams): TLCLIntfHandle;
var
  Scrolled: PGtkScrolledWindow;
  Layout: PGtkWidget;
  WidgetInfo: PWidgetInfo;
  Adjustment: PGtkAdjustment;
begin
  // create a gtk_scrolled_window for the scrollbars
  Scrolled := PGtkScrolledWindow(gtk_scrolled_window_new(nil, nil));
  gtk_scrolled_window_set_shadow_type(Scrolled,
    BorderStyleShadowMap[TScrollingWinControl(AWinControl).BorderStyle]);

  GTK_WIDGET_UNSET_FLAGS(Scrolled^.hscrollbar, GTK_CAN_FOCUS);
  GTK_WIDGET_UNSET_FLAGS(Scrolled^.vscrollbar, GTK_CAN_FOCUS);
  gtk_scrolled_window_set_policy(Scrolled, GTK_POLICY_NEVER, GTK_POLICY_NEVER);
  g_object_set_data(PGObject(Scrolled), odnScrollArea, Scrolled);

  {$IFDEF DebugLCLComponents}
  DebugGtkWidgets.MarkCreated(Scrolled, dbgsName(AWinControl));
  {$ENDIF}

  WidgetInfo := CreateWidgetInfo(Scrolled, AWinControl, AParams);

  Adjustment := gtk_scrolled_window_get_vadjustment(Scrolled);
  if Adjustment <> nil then
    g_object_set_data(PGObject(Adjustment), odnScrollBar, Scrolled^.vscrollbar);

  Adjustment := gtk_scrolled_window_get_hadjustment(Scrolled);
  if Adjustment <> nil then
    g_object_set_data(PGObject(Adjustment), odnScrollBar, Scrolled^.hscrollbar);

  // create a gtk_layout for the client area, so children can be added at
  // free x,y positions and the scrollbars automatically scrolls the children

  Layout := gtk_layout_new(nil, nil);
  gtk_container_add(PGTKContainer(Scrolled), Layout);
  gtk_widget_show(Layout);
  SetFixedWidget(Scrolled, Layout);
  SetMainWidget(Scrolled, Layout);

  Result := TLCLIntfHandle({%H-}PtrUInt(Scrolled));

  Set_RC_Name(AWinControl, PGtkWidget(Scrolled));
  SetCallBacks(PGtkWidget(Scrolled), WidgetInfo);
  if (gtk_major_version >= 2) and (gtk_minor_version > 8) then
  begin
    g_signal_connect(Scrolled^.hscrollbar, 'change-value',
                     TGCallback(@Gtk2RangeScrollCB), WidgetInfo);
    g_signal_connect(Scrolled^.vscrollbar, 'change-value',
                     TGCallback(@Gtk2RangeScrollCB), WidgetInfo);

    g_signal_connect(Scrolled^.hscrollbar, 'value-changed',
      TGCallback(@Gtk2RangeValueChanged), WidgetInfo);
    g_signal_connect(Scrolled^.vscrollbar, 'value-changed',
      TGCallback(@Gtk2RangeValueChanged), WidgetInfo);

    g_signal_connect(Scrolled^.hscrollbar, 'button-press-event',
                     TGCallback(@Gtk2RangeScrollPressCB), WidgetInfo);
    g_signal_connect(Scrolled^.hscrollbar, 'button-release-event',
                     TGCallback(@Gtk2RangeScrollReleaseCB), WidgetInfo);
    g_signal_connect(Scrolled^.vscrollbar, 'button-press-event',
                     TGCallback(@Gtk2RangeScrollPressCB), WidgetInfo);
    g_signal_connect(Scrolled^.vscrollbar, 'button-release-event',
                     TGCallback(@Gtk2RangeScrollReleaseCB), WidgetInfo);
    if (AWinControl is TScrollBox) then
      g_signal_connect(Scrolled, 'scroll-event',
                       TGCallback(@Gtk2ScrolledWindowScrollCB), WidgetInfo);
  end;
end;

class procedure TGtk2WSScrollingWinControl.SetColor(const AWinControl: TWinControl);
var
  AColor: TColor;
begin
  if not WSCheckHandleAllocated(AWinControl, 'SetColor')
  then Exit;

  // ScrollingWinControl: GtkScrolledWindow->GtkLayout
  // we need to set the color of the GtkLayout so that the whole viewport
  // will be filled (issue #16183)
  AColor := AWinControl.Color;
  if AColor = clDefault then
    AColor := GetDefaultColor(AWinControl, dctBrush);
  Gtk2WidgetSet.SetWidgetColor({%H-}PGtkBin(AWinControl.Handle)^.child,
                               clNone, AColor,
                               [GTK_STATE_NORMAL, GTK_STATE_ACTIVE,
                                GTK_STATE_PRELIGHT, GTK_STATE_SELECTED]);
end;

{ TGtk2WSHintWindow }

class procedure TGtk2WSHintWindow.SetCallbacks(const AWidget: PGtkWidget;
  const AWidgetInfo: PWidgetInfo);
begin
  TGtk2WSWinControl.SetCallbacks(PGtkObject(AWidget), TComponent(AWidgetInfo^.LCLObject));
  if (TControl(AWidgetInfo^.LCLObject).Parent = nil) then
    with TGTK2WidgetSet(Widgetset) do
    begin
      {$note test with smaller minor versions and check where LM_CONFIGUREEVENT is needed.}
      {$IFDEF HASX}
      // fix for buggy compiz.
      // see http://bugs.freepascal.org/view.php?id=17523
      if not compositeManagerRunning then
      {$ENDIF}
        SetCallback(LM_CONFIGUREEVENT, PGtkObject(AWidget), AWidgetInfo^.LCLObject);
    end;
end;

class function TGtk2WSHintWindow.CreateHandle(const AWinControl: TWinControl;
  const AParams: TCreateParams): TLCLIntfHandle;
var
  TempWidget : PGTKWidget;       // pointer to gtk-widget (local use when neccessary)
  p          : pointer;          // ptr to the newly created GtkWidget
  ACustomForm: TCustomForm;
  AWindow: PGdkWindow;
  WidgetInfo: PWidgetInfo;
begin
  ACustomForm := TCustomForm(AWinControl);

  p := gtk_window_new(GTK_WINDOW_POPUP);
  WidgetInfo := CreateWidgetInfo(p, AWinControl, AParams);
  gtk_window_set_policy(GTK_WINDOW(p), 0, 0, 0);
  gtk_window_set_focus_on_map(P, False);

  // issue #24363
  g_object_set_data(P,'lclhintwindow',AWinControl);

  // Create the form client area
  TempWidget := CreateFixedClientWidget;
  gtk_container_add(p, TempWidget);
  GTK_WIDGET_UNSET_FLAGS(TempWidget, GTK_CAN_FOCUS);
  gtk_widget_show(TempWidget);
  SetFixedWidget(p, TempWidget);
  SetMainWidget(p, TempWidget);

  ACustomForm.FormStyle := fsStayOnTop;
  ACustomForm.BorderStyle := bsNone;
  gtk_widget_realize(p);
  AWindow := GetControlWindow(P);
  {$IFDEF DebugGDK}BeginGDKErrorTrap;{$ENDIF}

  gdk_window_set_decorations(AWindow, GetWindowDecorations(ACustomForm));

  gdk_window_set_functions(AWindow, GetWindowFunction(ACustomForm));

  {$IFDEF DebugGDK}EndGDKErrorTrap;{$ENDIF}
  gtk_widget_show_all(TempWidget);// Important: do not show the window yet, only make its content visible

  {$IFNDEF NoStyle}
  if (ACustomForm.Parent = nil) then
    gtk_widget_set_app_paintable(P, True);
  {$ENDIF}

  {$IFDEF DebugLCLComponents}
  DebugGtkWidgets.MarkCreated(P,dbgsName(AWinControl));
  {$ENDIF}
  Result := TLCLIntfHandle({%H-}PtrUInt(P));
  Set_RC_Name(AWinControl, P);
  SetCallbacks(P, WidgetInfo);
end;

class procedure TGtk2WSHintWindow.ShowHide(const AWinControl: TWinControl);
var
  bVisible: boolean;
begin
  if not WSCheckHandleAllocated(AWinControl, 'SetColor') then
    exit;

  bVisible := AWinControl.HandleObjectShouldBeVisible;
  if bVisible then
    gtk_window_set_type_hint({%H-}PGtkWindow(AWinControl.Handle), GDK_WINDOW_TYPE_HINT_TOOLTIP);
  Gtk2WidgetSet.SetVisible(AWinControl, bVisible);
  InvalidateLastWFPResult(AWinControl, AWinControl.BoundsRect);
end;

end.

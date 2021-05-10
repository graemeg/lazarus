{
 *****************************************************************************
 *                              Gtk3WSMenus.pp                               *
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
unit Gtk3WSMenus;

{$i gtk3defines.inc}
{$mode objfpc}{$H+}

interface

uses
  Classes, Types, LCLProc, LCLType,
  LazGObject2, LazGlib2, LazGdk3, LazGtk3, gtk3procs,
  WSLCLClasses, WSMenus,
  LMessages, Graphics, Menus, Forms, LCLIntf;

type

  { TGtk3WSMenuItem }

  TGtk3WSMenuItem = class(TWSMenuItem)
  published
    class procedure AttachMenu(const AMenuItem: TMenuItem); override;
    class function CreateHandle(const AMenuItem: TMenuItem): HMENU; override;
    class procedure DestroyHandle(const AMenuItem: TMenuItem); override;
    class procedure SetCaption(const AMenuItem: TMenuItem; const ACaption: string); override;
    class procedure SetShortCut(const AMenuItem: TMenuItem; const ShortCutK1, ShortCutK2: TShortCut); override;
    class procedure SetVisible(const AMenuItem: TMenuItem; const Visible: boolean); override;
    class function SetCheck(const AMenuItem: TMenuItem; const Checked: boolean): boolean; override;
    class function SetEnable(const AMenuItem: TMenuItem; const Enabled: boolean): boolean; override;
    class function SetRadioItem(const AMenuItem: TMenuItem; const {%H-}RadioItem: boolean): boolean; override;
    class function SetRightJustify(const AMenuItem: TMenuItem; const Justified: boolean): boolean; override;
    class procedure UpdateMenuIcon(const AMenuItem: TMenuItem; const HasIcon: Boolean; const {%H-}AIcon: TBitmap); override;
  end;

  { TGtk3WSMenu }

  TGtk3WSMenu = class(TWSMenu)
  published
    class function CreateHandle(const AMenu: TMenu): HMENU; override;
    class procedure SetBiDiMode(const AMenu: TMenu; UseRightToLeftAlign, {%H-}UseRightToLeftReading : Boolean); override;
  end;

  { TGtk3WSMainMenu }

  TGtk3WSMainMenu = class(TWSMainMenu)
  published
  end;

  { TGtk3WSPopupMenu }

  TGtk3WSPopupMenu = class(TWSPopupMenu)
  protected
  published
    class function CreateHandle(const AMenu: TMenu): HMENU; override;
    class procedure Popup(const APopupMenu: TPopupMenu; const X, Y: integer); override;
  end;


implementation
uses gtk3widgets;
{. $I gtk2defines.inc}

var
  MenuWidget: PGtkWidget = nil;

function Gtk3MenuItemButtonPress(widget: PGtkWidget; event: PGdkEventButton;
 {%H-} user_data: gpointer): gboolean; cdecl;
var
  Parent: PGtkWidget;
  // WidgetInfo: PWidgetInfo;
begin
  Result := False;
  (*
  if (event^._type = GDK_BUTTON_PRESS) then
  begin
    Parent := gtk_widget_get_parent(Widget);
    if (Parent <> nil) and GTK_IS_MENU_BAR(Parent) then
    begin
      if (gtk_menu_item_get_submenu(PGtkMenuItem(Widget)) = nil) then
      begin
        WidgetInfo := GetWidgetInfo(Widget);
        if Assigned(TMenuItem(WidgetInfo^.LCLObject).OnClick) then
        begin
          gtk_menu_item_activate(PGtkMenuItem(Widget));
          // must be true because of issue #22616
          Result := True;
        end;
      end;
    end;
  end;
  *)
end;

function Gtk3MenuItemActivate(widget: PGtkMenuItem; data: gPointer) : GBoolean; cdecl;
var
  Mess: TLMActivate;
  LCLMenuItem: TMenuItem;
begin
  Result:= True;
  (*
  ResetDefaultIMContext;

  if LockOnChange(PgtkObject(Widget),0) > 0 then Exit;

  LCLMenuItem := TMenuItem(Data);

  // the gtk fires activate for radio buttons when unchecking them
  // the LCL expects only uncheck
  if LCLMenuItem.RadioItem
  and GtkWidgetIsA(PGtkWidget(Widget), GTK_TYPE_CHECK_MENU_ITEM)
  and (not gtk_check_menu_item_get_active(PGTKCheckMenuItem(Widget))) then Exit;

  FillChar(Mess{%H-}, SizeOf(Mess), #0);
  Mess.Msg := LM_ACTIVATE;
  Mess.Active := WA_ACTIVE;
  Mess.Minimized := False;
  Mess.ActiveWindow := 0;
  Mess.Result := 0;
  DeliverMessage(Data, Mess);

  Result := CallBackDefaultReturn;
  *)
end;

function Gtk3MenuItemToggled(AMenuItem: PGTKCheckMenuItem;
                             AData: gPointer): GBoolean; cdecl;
var
  LCLMenuItem: TMenuItem;
  Mess: TLMessage;
  b: Boolean;
  w: PGtkWidget;
  // WidgetInfo: PWidgetInfo;
begin
  Result := False; //CallBackDefaultReturn;
  (*
  if LockOnChange(PgtkObject(AMenuItem),0) > 0 then Exit;

  LCLMenuItem := TMenuItem(AData);

  if (csDesigning in LCLMenuItem.ComponentState) then
    exit;

  w := gtk_get_event_widget(gtk_get_current_event);

  if not GTK_IS_RADIO_MENU_ITEM(w) then
    exit;

  b := gtk_check_menu_item_get_active(AMenuItem);

  if not LCLMenuItem.Checked then
    g_signal_stop_emission_by_name(AMenuItem, 'toggled')
  else
    g_signal_stop_emission_by_name(AMenuItem, 'activate');

  if b <> LCLMenuItem.Checked then
    gtk_check_menu_item_set_active(AMenuItem, LCLMenuItem.Checked);

  {we must trigger OnClick() somehow, since we stopped signals}
  if b and (w <> nil) and (w <> PGtkWidget(AMenuItem)) then
  begin
    WidgetInfo := GetWidgetInfo(w);
    FillChar(Mess{%H-},SizeOf(Mess),#0);
    Mess.Msg := LM_ACTIVATE;
    WidgetInfo^.LCLObject.Dispatch(Mess);
  end;
  *)
end;

function Gtk3MenuItemSelect({%H-}item: PGtkMenuItem; AMenuItem: gPointer): GBoolean; cdecl;
begin
  TMenuItem(AMenuItem).IntfDoSelect;
  Result := False;
end;

procedure Gtk3MenuItemToggleSizeRequest(AMenuItem: PGtkMenuItem; requisition: Pgint; LCLItem: TMenuItem); cdecl;
var
  spacing: guint;
  IconWidth: Integer;
begin
  (*
  if LCLItem.HasIcon then
  begin
    IconWidth := LCLItem.GetIconSize.X;
    if IconWidth > 0 then
    begin
      gtk_widget_style_get(PGtkWidget(AMenuItem), 'toggle-spacing', [@spacing, nil]);
      requisition^ := IconWidth + spacing;
    end
    else
      requisition^ := 0;
  end
  else
    GTK_MENU_ITEM_GET_CLASS(AMenuItem)^.toggle_size_request(AMenuItem, requisition);
   *)
end;

procedure Gtk3MenuItemSizeRequest(AMenuItem: PGtkMenuItem; requisition: PGtkRequisition; LCLItem: TMenuItem); cdecl;
var
  IconHeight: Integer;
begin
  (*
  GTK_WIDGET_GET_CLASS(AMenuItem)^.size_request(PGtkWidget(AMenuItem), requisition);
  IconHeight := LCLItem.GetIconSize.Y;
  if requisition^.height < IconHeight then
    requisition^.height := IconHeight;
  *)
end;

function Gtk3MenuItemDeselect({%H-}item: Pointer; {%H-}AMenuItem: TMenuItem): GBoolean; cdecl;
begin
  Application.Hint := '';
  Result := False;
end;

{ TGtk3WSMenuItem }
(*
class procedure TGtk3WSMenuItem.SetCallbacks(const AGtkWidget: PGtkWidget;
  const AWidgetInfo: PWidgetInfo);
begin
  // connect activate signal (i.e. clicked)
  {button-press-event is needed by root menu items which have not
  submenu, but OnClick() is assigned - fix for #15986 }
  g_signal_connect_after(PGTKObject(AGtkWidget), 'button-press-event',
    TGTKSignalFunc(@Gtk2MenuItemButtonPress), AWidgetInfo^.LCLObject);
  g_signal_connect(PGTKObject(AGtkWidget), 'activate',
                   TGTKSignalFunc(@Gtk2MenuItemActivate), AWidgetInfo^.LCLObject);
  g_signal_connect(PGTKObject(AGtkWidget), 'select',
    TGTKSignalFunc(@Gtk2MenuItemSelect), AWidgetInfo^.LCLObject);
  g_signal_connect(PGTKObject(AGtkWidget), 'deselect',
    TGTKSignalFunc(@Gtk2MenuItemDeselect), AWidgetInfo^.LCLObject);
  g_signal_connect(PGTKObject(AGtkWidget), 'toggle-size-request',
    TGTKSignalFunc(@Gtk2MenuItemToggleSizeRequest), AWidgetInfo^.LCLObject);
  g_signal_connect(PGTKObject(AGtkWidget), 'size-request',
    TGTKSignalFunc(@Gtk2MenuItemSizeRequest), AWidgetInfo^.LCLObject);
end;
*)

class procedure TGtk3WSMenuItem.AttachMenu(const AMenuItem: TMenuItem);
// var
//  MenuItem, ParentMenuWidget, ContainerMenu: PGtkWidget;
var
  MenuItem: TGtk3MenuItem;
  ParentMenuWidget, ContainerMenu: PGtkWidget;
  NewMenu: TGtk3Menu;
  AForm: TCustomForm;
begin
  if not AMenuItem.HandleAllocated then
  begin
    DebugLn('WARNING: TGtk3WSMenuItem.AttachMenu handle not allocated ',AMenuItem.Caption);
    exit;
  end;

  MenuItem := TGtk3MenuItem(AMenuItem.Handle);

  {$IFDEF GTK3DEBUGMENUS}
  DebugLn('*LCL* AMenuItem.Menu ',dbgsName(AMenuItem.Menu),' Parent ',dbgsName(AMenuItem.Parent),
    ' PtPt ',dbgsName(AMenuItem.Parent.Parent),
    ' PtMenu ',dbgsName(AMenuItem.GetParentMenu));

  DebugLn('Item: IsMenuBar ',dbgs(Gtk3IsMenuBar(MenuItem.Widget)),' IsMenu ',dbgs(Gtk3IsMenu(MenuItem.Widget)),
    ' IsMenuItem ',dbgs(Gtk3IsWidget(MenuItem.Widget)));
  {$ENDIF}

  if not(Assigned(AMenuItem.Parent)) and (AMenuItem.GetParentMenu is TPopupMenu) then
    ParentMenuWidget := TGtk3Menu(AMenuItem.GetParentMenu.Handle).Widget
  else
    ParentMenuWidget := MenuItem.Widget^.get_parent;
  {$IFDEF GTK3DEBUGMENUS}
  DebugLn('Parent: IsMenuBar ',dbgs(Gtk3IsMenuBar(ParentMenuWidget)),' IsMenu ',dbgs(Gtk3IsMenu(ParentMenuWidget)),
  ' IsMenuItem ',dbgs(Gtk3IsWidget(ParentMenuWidget)));
  {$ENDIF}

  if not Gtk3IsWidget(ParentMenuWidget) then
  begin
    ParentMenuWidget := TGtk3Widget(AMenuItem.Parent.Handle).Widget;
  end;

  if ((not AMenuItem.Parent.HasParent) and (AMenuItem.GetParentMenu is TMainMenu)) then
  begin
    AForm := TCustomForm(AMenuItem.GetParentMenu.Owner);
    PGtkMenuBar(TGtk3Window(AForm.Handle).GetMenuBar)^.append(TGtk3MenuItem(AMenuItem.Handle).Widget);
  end else
  (*
  if (AMenuItem.GetParentMenu is TPopupMenu) then
  begin
    DebugLn('Attaching item to PopupMenu ...');
    PGtkMenu(TGtk3Menu(AMenuItem.GetParentMenu.Handle).Widget)^.append(TGtk3MenuItem(AMenuItem.Handle).Widget);
  end else
  *)
  begin
    if Gtk3IsMenu(ParentMenuWidget) then
      ContainerMenu := ParentMenuWidget
    else
    begin
      {$IFDEF GTK3DEBUGMENUS}
      DebugLn('ParentMenuWidget ',dbgs(Gtk3IsWidget(ParentMenuWidget)));
      {$ENDIF}
      if not Gtk3IsWidget(ParentMenuWidget) then
        ParentMenuWidget := MenuItem.Widget;
      if g_object_get_data(ParentMenuWidget, 'ContainerMenu') <> nil then
        ContainerMenu := PGtkWidget(g_object_get_data(ParentMenuWidget,
                                  'ContainerMenu'))
      else
        ContainerMenu := nil;
    end;

    if ContainerMenu = nil then
    begin
      if (AMenuItem.GetParentMenu is TPopupMenu) and (AMenuItem.Parent.Parent=nil) then
      begin
        ContainerMenu := TGtk3Widget(AMenuItem.GetParentMenu.Handle).Widget;
        g_object_set_data(PGObject(ContainerMenu), 'ContainerMenu',
          ContainerMenu);
      end else
      begin
        {$IFDEF GTK3DEBUGMENUS}
        DebugLn('Creating newMenuItem ...');
        {$ENDIF}
        ContainerMenu := TGtkMenu.new;
        g_object_set_data(ParentMenuWidget, 'ContainerMenu',
                            ContainerMenu);
        PGTKMenuItem(ParentMenuWidget)^.set_submenu(ContainerMenu);
      end;
    end;
    PGtkMenu(ContainerMenu)^.insert(MenuItem.Widget, AMenuItem.MenuVisibleIndex);
  end;
end;

class function TGtk3WSMenuItem.CreateHandle(const AMenuItem: TMenuItem): HMENU;
(*
var
  Widget: PGtkWidget;
  WidgetInfo: PWidgetInfo;
  *)
var
  AMenu: TGtk3Menu;
begin
  if ((not AMenuItem.Parent.HasParent) and (AMenuItem.GetParentMenu is TMainMenu)) then
  begin
    {$IFDEF GTK3DEBUGMENUS}
    DebugLn('******** CREATING TGtk3Menu ********** FORM ',dbgsName(AMenuItem.GetParentMenu.Owner));
    {$ENDIF}
    Result := HMENU(TGtk3MenuItem.Create(AMenuItem));
    // PGtkMenu(AMenu.Widget)^.insert(TGtk3MenuItem(Result).Widget, 0);
  end
  else
    Result := HMENU(TGtk3MenuItem.Create(AMenuItem));

  if AMenuItem.Visible then
    TGtk3MenuItem(Result).show;

  // create the menuitem widget (normal, check or radio)
  (*
  if AMenuItem.Caption = cLineCaption then // create separator
    Widget := gtk_menu_item_new
  else
  if AMenuItem.RadioItem and not AMenuItem.HasIcon then
    Widget := gtk_radio_menu_item_new(nil)
  else
  if AMenuItem.IsCheckItem or AMenuItem.HasIcon then
    Widget := gtk_check_menu_item_new
  else
    Widget := gtk_menu_item_new;

  WidgetInfo := CreateWidgetInfo(Widget);
  WidgetInfo^.LCLObject := AMenuItem;

  if GtkWidgetIsA(Widget, GTK_TYPE_CHECK_MENU_ITEM) then
  begin
    // check or radio
    // set 'ShowAlwaysCheckable'
    gtk_check_menu_item_set_show_toggle(PGtkCheckMenuItem(Widget),
      AMenuItem.ShowAlwaysCheckable);
    // set 'Checked'
    gtk_check_menu_item_set_active(PGtkCheckMenuItem(Widget),
      AMenuItem.Checked);

    g_signal_connect(PGTKObject(Widget), 'toggled',
      TGTKSignalFunc(@Gtk2MenuItemToggled), Pointer(AMenuItem));
  end;

  // set attributes (enabled and rightjustify)
  gtk_widget_set_sensitive(Widget,
                     AMenuItem.Enabled and (AMenuItem.Caption <> cLineCaption));
  if AMenuItem.RightJustify then
    gtk_menu_item_right_justify(PGtkMenuItem(Widget));

  // create the hbox containing the label and the icon
  UpdateInnerMenuItem(AMenuItem, Widget);

  SetCallbacks(Widget, WidgetInfo);

  gtk_widget_show(Widget);
  {$IFDEF DebugLCLComponents}
  DebugGtkWidgets.MarkCreated(Widget, dbgsName(AMenuItem));
  {$ENDIF}
  Result := HMENU({%H-}PtrUInt(Widget));
  *)
end;

class procedure TGtk3WSMenuItem.DestroyHandle(const AMenuItem: TMenuItem);
begin
  { TODO: cleanup }
  TGtk3MenuItem(AMenuItem.Handle).Free;
  // TGtk2WidgetSet(WidgetSet).DestroyLCLComponent(AMenuItem);
end;

class procedure TGtk3WSMenuItem.SetCaption(const AMenuItem: TMenuItem;
  const ACaption: string);
// var
//  MenuItemWidget: TGtk3MenuItem;
begin
  if not WSCheckMenuItem(AMenuItem, 'SetCaption') then
    Exit;
  {$IFDEF GTK3DEBUGMENUS}
  DebugLn('TGtk3WSMenuItem.SetCaption ',ACaption);
  {$ENDIF}
  TGtk3MenuItem(AMenuItem.Handle).Caption := ACaption;
  // MenuItemWidget := TGtk3MenuItem(AMenuItem.Handle);
  // gtk_menu_item_set_label(PGtkMenuItem(MenuItemWidget.Widget), PgChar(AMenuItem.Caption));
  // UpdateInnerMenuItem(AMenuItem,MenuItemWidget);
  // gtk_widget_set_sensitive({%H-}PGtkWidget(AMenuItem.Handle),
  // AMenuItem.Enabled and (ACaption <> cLineCaption));
end;

class procedure TGtk3WSMenuItem.SetShortCut(const AMenuItem: TMenuItem;
  const ShortCutK1, ShortCutK2: TShortCut);
//var
  //MenuWidget: PGtkMenuItem;
  //accel_path: String;
  //CurKey: Word;
  //CurShift: TShiftState;
begin
  if not WSCheckMenuItem(AMenuItem, 'SetShortCut') then  Exit;

  //Gtk3: Use Gtk2 implementation for this ... cannot find anything
  // usefull for this in Gtk3 .... seem that old implementation could work
  // Temporary: At least it writes the names of the shortcuts
  //  UpdateInnerMenuItem(AMenuItem, {%H-}PGTKWidget(AMenuItem.Handle), ShortCutK1, ShortCutK2);
  // PGtkMenuItem(nil)^.add_accelerator();
{  // Gets the inner widgets. They should already be created by now
  MenuWidget := PGtkMenuItem(AMenuItem.Handle);
  if (MenuWidget=nil) then Exit;
  // Converts the shortcut to a gtk friendly format and sets it
  ShortCutToKey(NewShortCut, CurKey, CurShift);
  accel_path := 'LCLApp/Menu/' + GetAcceleratorString(CurKey, CurShift);
  gtk_accel_map_add_entry(accel_path, CurKey, ShiftToGdkModifierType);
  gtk_menu_item_set_accel_path(); }
end;

class procedure TGtk3WSMenuItem.SetVisible(const AMenuItem: TMenuItem;
  const Visible: boolean);
var
  MenuItemWidget: TGtk3Widget;
begin
  if not WSCheckMenuItem(AMenuItem, 'SetVisible') then
    Exit;
  MenuItemWidget := TGtk3Widget(AMenuItem.Handle);
  if MenuItemWidget.Visible = Visible then
    Exit;
  MenuItemWidget.Visible := Visible;
end;

class function TGtk3WSMenuItem.SetCheck(const AMenuItem: TMenuItem;
  const Checked: boolean): boolean;
var
  IsRadio: Boolean;
  Group: PGSList;
  Item: TGtk3MenuItem;
begin
  Result:=false;
  if not WSCheckMenuItem(AMenuItem, 'SetCheck') then
    Exit;
  if AMenuItem.HandleAllocated then
  begin
     Item := TGtk3MenuItem(AMenuItem.Handle);
     Item.SetCheck(Checked);
  end else
  begin
    AMenuItem.RecreateHandle;
    Result := True;
  end;
  (*
  Item := {%H-}Pointer(AMenuItem.Handle);
  IsRadio := gtk_is_radio_menu_item(Item);
  if IsRadio or gtk_is_check_menu_item(Item)
  then begin
    if IsRadio
    then begin
      Group := gtk_radio_menu_item_group(Item);
      LockRadioGroupOnChange(Group, +1);
    end
    else LockOnChange(Item, +1);
    gtk_check_menu_item_set_active(Item, Checked);
    if IsRadio
    then LockRadioGroupOnChange(Group, -1)
    else LockOnChange(Item, -1);
    Result := True;
  end
  else begin
    AMenuItem.RecreateHandle;
    Result := True;
  end;
  *)
end;

class function TGtk3WSMenuItem.SetEnable(const AMenuItem: TMenuItem;
  const Enabled: boolean): boolean;
begin
  Result := False;
  if not WSCheckMenuItem(AMenuItem, 'SetEnable') then
    Exit;
  TGtk3Widget(AMenuItem.Handle).Enabled := Enabled and (AMenuItem.Caption <> cLineCaption);
  // gtk_widget_set_sensitive({%H-}PGtkWidget(AMenuItem.Handle),
  //  Enabled and (AMenuItem.Caption <> cLineCaption));
  Result := True;
end;

class function TGtk3WSMenuItem.SetRadioItem(const AMenuItem: TMenuItem;
  const RadioItem: boolean): boolean;
begin
  AMenuItem.RecreateHandle;
  Result := True;
end;

class function TGtk3WSMenuItem.SetRightJustify(const AMenuItem: TMenuItem;
  const Justified: boolean): boolean;
var
  MenuItemWidget: PGtkMenuItem;
begin
  Result := False;
  if not WSCheckMenuItem(AMenuItem, 'SetRightJustify') then
    Exit;
  // this property does not exist in Gtk3 anymore (deprecated in 3.2).
  // MenuItemWidget := {%H-}PGtkMenuItem(AMenuItem.Handle);
  // gtk_menu_item_set_right_justified(MenuItemWidget, Justified);
  // gtk_widget_queue_resize(GTK_WIDGET(MenuItemWidget));
  Result := True;
end;

class procedure TGtk3WSMenuItem.UpdateMenuIcon(const AMenuItem: TMenuItem;
  const HasIcon: Boolean; const AIcon: TBitmap);
begin
  if not WSCheckMenuItem(AMenuItem, 'UpdateMenuIcon') then
    Exit;
  if HasIcon then
    AMenuItem.RecreateHandle;
end;

{ TGtk3WSMenu }

class function TGtk3WSMenu.CreateHandle(const AMenu: TMenu): HMENU;
(*
var
  Widget: PGtkWidget;
  WidgetInfo: PWidgetInfo;
  Box: Pointer;
  ParentForm: TCustomForm;
const
  MenuDirection : array[Boolean] of Longint = (
    GTK_PACK_DIRECTION_LTR,
    GTK_PACK_DIRECTION_RTL);
  *)
var
  AParams: TCreateParams;
begin
  (*
  Widget := gtk_menu_bar_new();
  // get the VBox, the form has one child, a VBox
  ParentForm := TCustomForm(AMenu.Parent);
  if (ParentForm=nil) or (not (ParentForm is TCustomForm)) then
    RaiseGDBException('MainMenu without form');
  if ParentForm.Menu <> AMenu then
    RaiseGDBException('Form already has a MainMenu');
  if ParentForm.HandleAllocated then
  begin
    Box := {%H-}PGTKBin(ParentForm.Handle)^.Child;
    gtk_box_pack_start(Box, Widget, False, False, 0);
  end;

  gtk_menu_bar_set_pack_direction(PGtkMenuBar(Widget), MenuDirection[AMenu.UseRightToLeftAlignment]);
  gtk_widget_show(Widget);

  {$IFDEF DebugLCLComponents}
  DebugGtkWidgets.MarkCreated(Widget, dbgsName(AMenu));
  {$ENDIF}
  Result := THandle({%H-}PtrUInt(Widget));
  WidgetInfo := CreateWidgetInfo(Widget);
  WidgetInfo^.LCLObject := AMenu;
  // no callbacks for main menu
  *)
  if (AMenu is TMainMenu) and (AMenu.Owner is TCustomForm) then
  begin
    {$IFDEF GTK3DEBUGMENUS}
    Debugln('** TGtk3WSMenu.CreateHandle AMenu ',dbgsName(AMenu),' USING MENUBAR OF FORM !');
    {$ENDIF}
    Result := HMENU(TGtk3MenuBar.Create(AMenu, TGtk3Window(TCustomForm(AMenu.Owner).Handle).GetMenuBar));
  end else
  begin
    {$IFDEF GTK3DEBUGMENUS}
    DebugLn('*#*#*#*#* TGtk3WSMenu.CreateHandle AMenu ',dbgsName(AMenu));
    {$ENDIF}
    Result := HMENU(TGtk3MenuBar.Create(AMenu, nil));
  end;
end;

class procedure TGtk3WSMenu.SetBiDiMode(const AMenu : TMenu;
  UseRightToLeftAlign, UseRightToLeftReading : Boolean);
(*
const
  WidgetDirection : array[boolean] of longint = (GTK_TEXT_DIR_LTR, GTK_TEXT_DIR_RTL);
{$ifdef GTK_2_8}
const
  MenuDirection : array[Boolean] of Longint = (
    GTK_PACK_DIRECTION_LTR,
    GTK_PACK_DIRECTION_RTL);
{$endif}
  procedure Switch(AMenuItem: TMenuItem; Flip: Boolean);
  var
    i: Integer;
  begin
    if Flip then
    begin
      if AMenuItem.HandleAllocated then begin
        gtk_widget_set_direction({%H-}PGtkWidget(AMenuItem.Handle), WidgetDirection[UseRightToLeftAlign]);
        UpdateInnerMenuItem(AMenuItem, {%H-}PGtkWidget(AMenuItem.Handle));
      end;
    end;
    for i := 0 to AMenuItem.Count -1 do
      Switch(AMenuItem[i], True);
  end;
  *)
begin
  (*
  {$ifdef GTK_2_8}
    gtk_menu_bar_set_pack_direction({%H-}PGtkMenuBar(AMenu.Handle), MenuDirection[UseRightToLeftAlign]);
    gtk_menu_bar_set_child_pack_direction({%H-}PGtkMenuBar(AMenu.Handle), MenuDirection[UseRightToLeftAlign]);
  {$endif}
  //gtk_widget_set_direction(PGtkWidget(AMenu.Handle), WidgetDirection[UseRightToLeftAlign]);
  Switch(AMenu.Items, False);
  *)
end;

{ TGtk3WSPopupMenu }

procedure GtkWS_Popup(menu: PGtkMenu; X, Y: pgint; {%H-}push_in: pgboolean;
  AData: gPointer); cdecl;
var
  Requisition: TGtkRequisition;
  Alignment: TPopupAlignment;
  ScreenHeight: gint;
begin
  X^ := TGtk3Menu(TPopupMenu(AData).Handle).PopupPoint.X;
  Y^ := TGtk3Menu(TPopupMenu(AData).Handle).PopupPoint.Y;
  (*
  X^ := PPoint(WidgetInfo^.UserData)^.X;
  Y^ := PPoint(WidgetInfo^.UserData)^.Y;

  if WidgetInfo^.LCLObject is TPopupMenu then
  begin
    // make menu to fit the screen vertically
    gtk_widget_size_request(PGtkWidget(menu), @Requisition);
    ScreenHeight := gdk_screen_height();
    if Y^ + Requisition.height > ScreenHeight then
    begin
      Y^ := ScreenHeight - Requisition.height;
      if Y^ < 0 then Y^ := 0;
    end;

    // get actual alignment
    Alignment := TPopupMenu(WidgetInfo^.LCLObject).Alignment;
    if TPopupMenu(WidgetInfo^.LCLObject).UseRightToLeftAlignment then
    begin
      if Alignment = paLeft then
        Alignment := paRight
      else
      if Alignment = paRight then
        Alignment := paLeft;
    end;

    case Alignment of
      paCenter: X^ := X^ - Requisition.width div 2;
      paRight: X^ := X^ - Requisition.width;
    end;
  end;
  *)
end;

function gtkWSPopupDelayedClose(Data: Pointer): gboolean; cdecl;
var
  PopupMenu: TMenu absolute Data;
begin
  Result := False;
  if PopupMenu is TPopupMenu then
    TPopupMenu(PopupMenu).Close;
end;

procedure gtkWSPopupMenuDeactivate(widget: PGtkWidget; data: gPointer); cdecl;
begin
  if widget = MenuWidget then
    MenuWidget := nil;
  if data <> nil then
    g_idle_add(@gtkWSPopupDelayedClose, TGtk3Menu(data).MenuObject);
end;

class function TGtk3WSPopupMenu.CreateHandle(const AMenu: TMenu): HMENU;
(*
var
  Widget: PGtkWidget;
  WidgetInfo: PWidgetInfo;
  *)
begin
  (*
  Widget := gtk_menu_new;
  Result := HMENU({%H-}PtrUInt(Widget));
  {$IFDEF DebugLCLComponents}
  DebugGtkWidgets.MarkCreated(Widget, dbgsName(Sender));
  {$ENDIF}
  WidgetInfo := CreateWidgetInfo(Widget);
  WidgetInfo^.LCLObject := AMenu;
  SetCallbacks(Widget, WidgetInfo);
  *)
  {$IFDEF GTK3DEBUGMENUS}
  DebugLn('****** TGtk3WSPopupMenu.CreateHandle ******');
  {$ENDIF}
  Result := HMENU(TGtk3Menu.Create(AMenu, nil));
  g_signal_connect_data(TGtk3Menu(Result).Widget,'deactivate',
    TGCallback(@gtkWSPopupMenuDeactivate), TGtk3Menu(Result), nil, 0);

end;

class procedure TGtk3WSPopupMenu.Popup(const APopupMenu: TPopupMenu; const X,
  Y: integer);
var
  AProc: Pointer;
  // WidgetInfo: PWidgetInfo;
begin
  // ReleaseMouseCapture;
  TGtk3Menu(APopupMenu.Handle).PopupPoint := Point(X, Y);
  AProc := @GtkWS_Popup;

  {$IFDEF GTK3DEBUGMENUS}
  DebugLn('TGtk3WSPopupMenu.Popup X=',dbgs(X),' Y=',dbgs(Y));
  {$ENDIF}
  // gtk_menu_popdown(PGtkMenu(TGtk3Widget(APopupMenu.Handle).Widget));
  // PGtkMenu(TGtk3Widget(APopupMenu.Handle).Widget)^.show_all;
  PGtkMenu(TGtk3Menu(APopupMenu.Handle).Widget)^.popup(nil, nil,
    TGtkMenuPositionFunc(AProc), APopupMenu, 0, gtk_get_current_event_time);

  // TGtk3Widget(APopupMenu.Handle).Show;
  (*
  MenuWidget := {%H-}PGtkWidget(APopupMenu.Handle);
  WidgetInfo := GetWidgetInfo(MenuWidget);
  WidgetInfo^.UserData := @APoint;
  WidgetInfo^.DataOwner := False;
  // MenuWidget can be either GtkMenu or GtkMenuItem submenu
  if GTK_IS_MENU_ITEM(MenuWidget) then
    MenuWidget := gtk_menu_item_get_submenu(PGtkMenuItem(MenuWidget));
  gtk_menu_popup(PGtkMenu(MenuWidget), nil, nil, TGtkMenuPositionFunc(AProc),
                 WidgetInfo, 0, gtk_get_current_event_time());
  repeat
    try
      WidgetSet.AppProcessMessages; // process all events
    except
      if Application.CaptureExceptions then
        Application.HandleException(APopupMenu)
      else
        raise;
    end;
    if Application.Terminated or not Assigned(MenuWidget) then
      break;
    Application.Idle(true);
  until False;
  *)
end;

end.

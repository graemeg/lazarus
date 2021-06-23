{
 *****************************************************************************
 *                             Gtk3CellRenderer.pas                          *
 *                             --------------------                          *
 *                                                                           *
 *                                                                           *
 *****************************************************************************

 *****************************************************************************
  This file is part of the Lazarus Component Library (LCL)

  See the file COPYING.modifiedLGPL.txt, included in this distribution,
  for details about the license.
 *****************************************************************************

  An extended gtk_cell_renderer, to provide hooks for the LCL.
  For example for custom drawing.
 
}
unit Gtk3CellRenderer;

{$mode objfpc}{$H+}
{$i gtk3defines.inc}

interface

uses
  Classes, SysUtils, LCLType, LCLProc, Controls, StdCtrls, ComCtrls, LMessages,
  LazGObject2, LazGtk3, LazGdk3, LazGLib2, Gtk3Procs, LazCairo1;
  
type
  PLCLIntfCellRenderer = ^TLCLIntfCellRenderer;
  TLCLIntfCellRenderer = record
    // ! the TextRenderer must be the first attribute of this record !
    TextRenderer: TGtkCellRendererText;
    Index: integer;
    ColumnIndex: Integer; // for TListView
  end;

  PLCLIntfCellRendererClass = ^TLCLIntfCellRendererClass;
  TLCLIntfCellRendererClass = object
    // ParentClass: TGInitiallyUnowned;
    ParentClass: TGtkCellRendererTextClass;
    DefaultGetRequestMode: function(cell: PGtkCellRenderer): TGtkSizeRequestMode; cdecl;
    DefaultGetPreferredWidth: procedure (cell: PGtkCellRenderer; widget: PGtkWidget; minimum_size: Pgint; natural_size: Pgint); cdecl;
    DefaultGetPreferredHeightForWidth: procedure(cell: PGtkCellRenderer; widget: PGtkWidget; width: gint; minimum_height: Pgint; natural_height: Pgint); cdecl;
    DefaultGetPreferredHeight: procedure (cell: PGtkCellRenderer; widget: PGtkWidget; minimum_size: Pgint; natural_size: Pgint); cdecl;
    DefaultGetPreferredWidthForHeight: procedure(cell: PGtkCellRenderer; widget: PGtkWidget; height: gint; minimum_width: Pgint; natural_width: Pgint); cdecl;
    DefaultGetAlignedArea: procedure(cell: PGtkCellRenderer; widget: PGtkWidget; flags: TGtkCellRendererState; cell_area: PGdkRectangle; aligned_area: PGdkRectangle); cdecl;

    DefaultGtkGetSize: procedure(cell: PGtkCellRenderer;
                                 widget: PGtkWidget;
                                 cell_area: PGdkRectangle;
                                 x_offset: pgint;
                                 y_offset: pgint;
                                 width: pgint;
                                 height: pgint); cdecl;

    DefaultGtkRender: procedure(cell: PGtkCellRenderer;
              cr: Pcairo_t;
              widget: PGtkWidget;
              background_area: PGdkRectangle;
              cell_area: PGdkRectangle;
              flags: TGtkCellRendererState); cdecl;

    activate: function (cell: PGtkCellRenderer; event: PGdkEvent; widget: PGtkWidget;
      path: PgChar; bg_area: PGdkRectangle; cell_area: PGdkRectangle;
      flags: TGtkCellRendererState): GBoolean; cdecl;

    start_editing: function(cell: PGtkCellRenderer; event: PGdkEvent; widget: PGtkWidget;
      path: PgChar; bg_area: PGdkRectangle; cell_area: PGdkRectangle; flags: TGtkCellRendererState): PGtkCellEditable; cdecl;
    editing_canceled: procedure(cell: PGtkCellRenderer); cdecl;
    editing_started: procedure(cell: PGtkCellRenderer; editable: PGtkCellEditable; path: pgChar); cdecl;
    priv: PGtkCellRendererClassPrivate;
    _gtk_reserved2: procedure(); cdecl;
    _gtk_reserved3: procedure(); cdecl;
    _gtk_reserved4: procedure(); cdecl;
  end;

function LCLIntfCellRenderer_GetType: TGType;
function LCLIntfCellRenderer_New: PGtkCellRenderer;
procedure LCLIntfCellRenderer_CellDataFunc(cell_layout:PGtkCellLayout;
                                           cell: PGtkCellRenderer;
                                           tree_model: PGtkTreeModel;
                                           iter: PGtkTreeIter;
                                           data: gpointer); cdecl;
procedure LCLIntfRenderer_ColumnCellDataFunc(tree_column: PGtkTreeViewColumn;
                                           cell: PGtkCellRenderer;
                                           tree_model: PGtkTreeModel;
                                           iter: PGtkTreeIter;
                                           data: gpointer); cdecl;
procedure LCLIntfRenderer_GtkCellLayoutDataFunc(cell_layout: PGtkCellLayout; cell: PGtkCellRenderer; tree_model: PGtkTreeModel; iter: PGtkTreeIter; data: gpointer); cdecl;

implementation
uses gtk3widgets, gtk3int;

type
  TCustomListViewAccess = class(TCustomListView);

function GetControl(Widget: PGtkWidget): TWinControl;
var
  AHWND: HWND;
begin
  Result := nil;
  repeat
    AHWND := HwndFromGtkWidget(Widget);
    if AHWND <> 0 then break;
    Widget := Widget^.get_parent;
    if Widget = Nil then break;
  until False;
  if AHWND <> 0 then begin
    Result := TGtk3Widget(AHWND).LCLObject;
    Assert(Result is TWinControl, 'GetControl: LCLObject for Gtk3Widget is not TWinControl.');
  end;
end;

function GetItemIndex(cell: PLCLIntfCellRenderer; {%H-}widget: PGtkWidget): Integer;
begin
  Result := cell^.Index;
end;

function LCLIntfCellRenderer_GetRequestMode(cell: PGtkCellRenderer): TGtkSizeRequestMode; cdecl;
var
  CellClass: PLCLIntfCellRendererClass;
begin
  {$IFDEF GTK3DEBUGCELLRENDERER}
  DebugLn('*** LCLIntfCellRenderer_GetRequestMode ***');
  {$ENDIF}
  CellClass := PLCLIntfCellRendererClass(cell^.g_type_instance.g_class);
  // CellClass := PLCLIntfCellRendererClass(gtk_object_get_class(cell));
  Result := CellClass^.DefaultGetRequestMode(cell);
end;

procedure LCLIntfCellRenderer_GetAlignedArea(cell: PGtkCellRenderer; widget: PGtkWidget;
  flags: TGtkCellRendererState; cell_area: PGdkRectangle; aligned_area: PGdkRectangle); cdecl;
var
  CellClass: PLCLIntfCellRendererClass;
  AWinControl: TWinControl;
  ItemIndex: Integer;
  Msg: TLMMeasureItem;
  MeasureItemStruct: TMeasureItemStruct;
  //Requisition, NaturalSize: TGtkRequisition;
  //AMinHeight, ANaturalHeight: gint;
  //Value: TGValue;
  R1, R2: TGdkRectangle;
begin
  {$IFDEF GTK3DEBUGCELLRENDERER}
  // DebugLn('*** LCLIntfCellRenderer_GetAlignedArea ***');
  {$ENDIF}
  CellClass := PLCLIntfCellRendererClass(cell^.g_type_instance.g_class);
  CellClass^.DefaultGetAlignedArea(cell, widget, flags, cell_area, aligned_area);
  // this does not work too....
  exit;

  R1 := cell_area^;
  R2 := aligned_area^;
  CellClass^.DefaultGetAlignedArea(cell, widget, flags, @R1, @R2);
  cell_area^ := R1;
  aligned_area^ := R2;
  // DebugLn('Cell_Area ',dbgs(RectFromGdkRect(cell_area^)),' Aligned_Area ',dbgs(RectFromGdkRect(aligned_area^)));
  // cell^.get_preferred_size(Widget, @AMinSize, @ANatSize);

  AWinControl := GetControl(widget);
  if AWinControl = Nil then exit;
  if [csDestroying,csLoading]*AWinControl.ComponentState<>[] then exit;

  if AWinControl is TCustomListbox then
    if TCustomListbox(AWinControl).Style < lbOwnerDrawFixed then
      exit;
  if AWinControl is TCustomCombobox then
    if not TCustomCombobox(AWinControl).Style.IsVariable then
      exit;

  ItemIndex := GetItemIndex(PLCLIntfCellRenderer(cell), Widget);

  if ItemIndex < 0 then
    ItemIndex := 0;

  MeasureItemStruct.itemID := UINT(ItemIndex);
  MeasureItemStruct.itemWidth := UINT(aligned_area^.width);
  MeasureItemStruct.itemHeight := UINT(aligned_area^.height);
  Msg.Msg := LM_MEASUREITEM;
  Msg.MeasureItemStruct := @MeasureItemStruct;
  TGtk3Widget(AWinControl.Handle).DeliverMessage(Msg);
  {here we cheat cell renderer to paint eg. height 1 }
  aligned_area^.height := gint(MeasureItemStruct.itemHeight);
  cell_area^.height := gint(MeasureItemStruct.itemHeight);
  DebugLn('**** Cell_Area ',dbgs(RectFromGdkRect(cell_area^)),' Aligned_Area ',dbgs(RectFromGdkRect(aligned_area^)));

end;

// get_preferred_width: procedure(cell: PGtkCellRenderer; widget: PGtkWidget; minimum_size: Pgint; natural_size: Pgint); cdecl;
procedure LCLIntfCellRenderer_GetPreferredWidth(cell: PGtkCellRenderer; widget: PGtkWidget; minimum_size: Pgint; natural_size: Pgint); cdecl;
var
  CellClass: PLCLIntfCellRendererClass;
begin
  {$IFDEF GTK3DEBUGCELLRENDERER}
  DebugLn('*** LCLIntfCellRenderer_GetPreferredWidth ***');
  {$ENDIF}
  CellClass := PLCLIntfCellRendererClass(cell^.g_type_instance.g_class);
  CellClass^.DefaultGetPreferredWidth(cell, widget, minimum_size, natural_size);
  {$IFDEF GTK3DEBUGCELLRENDERER}
  // DebugLn('*** LCLIntfCellRenderer_GetPreferredWidth MIN=',dbgs(minimum_size^),' naturalw=',dbgs(natural_size^));
  {$ENDIF}
end;

procedure LCLIntfCellRenderer_GetPreferredHeight(cell: PGtkCellRenderer; widget: PGtkWidget; minimum_size: Pgint; natural_size: Pgint); cdecl;
var
  CellClass: PLCLIntfCellRendererClass;
begin
  // it's never called ?!?
  {$IFDEF GTK3DEBUGCELLRENDERER}
  DebugLn('*** LCLIntfCellRenderer_GetPreferredHeight ***');
  {$ENDIF}
  CellClass := PLCLIntfCellRendererClass(cell^.g_type_instance.g_class);
  CellClass^.DefaultGetPreferredHeight(cell, widget, minimum_size, natural_size);

end;

procedure LCLIntfCellRenderer_GetPreferredWidthForHeight(cell: PGtkCellRenderer; widget: PGtkWidget;
  height: gint; minimum_width: Pgint; natural_width: Pgint); cdecl;
var
  CellClass: PLCLIntfCellRendererClass;
begin
  {$IFDEF GTK3DEBUGCELLRENDERER}
  DebugLn('*** LCLIntfCellRenderer_GetPreferredWidthForHeight ***');
  {$ENDIF}
  CellClass := PLCLIntfCellRendererClass(cell^.g_type_instance.g_class);
  CellClass^.DefaultGetPreferredWidthForHeight(cell, widget, height, minimum_width, natural_width);
end;

procedure LCLIntfCellRenderer_GetPreferredHeightForWidth(cell: PGtkCellRenderer; widget: PGtkWidget;
  width: gint; minimum_height: Pgint; natural_height: Pgint); cdecl;
var
  CellClass: PLCLIntfCellRendererClass;
  AWinControl: TWinControl;
  ItemIndex: Integer;
  Msg: TLMMeasureItem;
  MeasureItemStruct: TMeasureItemStruct;
  //Requisition, NaturalSize: TGtkRequisition;
  AMinHeight{, ANaturalHeight}: gint;
begin
  {$IFDEF GTK3DEBUGCELLRENDERER}
  DebugLn('*** LCLIntfCellRenderer_GetPreferredHeightForWidth *** width=',dbgs(Width));
  // ,' min ',dbgs(minimum_height^),' natural ',dbgs(natural_height^));
  {$ENDIF}
  CellClass := PLCLIntfCellRendererClass(cell^.g_type_instance.g_class);
  if (minimum_height = nil) or (natural_height = nil) then
  begin
    // CellClass^.DefaultGetPreferredHeightForWidth(cell, widget, width, @AMinHeight, @ANaturalHeight);
    // exit;
  end;

  CellClass^.DefaultGetPreferredHeightForWidth(cell, widget, width, minimum_height, natural_height);

  if minimum_height <> nil then
    AMinHeight := minimum_height^
  else
    AMinHeight := 0;
{  if natural_height <> nil then
    ANaturalHeight := natural_height^
  else
    ANaturalHeight := 0;
}
  // writeln('1.minimumheight ',AMinHeight,' naturalheight ',ANaturalHeight,' min ',dbgs(minimum_height <> nil),' nat ',dbgs(natural_height <> nil));

  AWinControl := GetControl(widget);
  if AWinControl = Nil then exit;
  if [csDestroying,csLoading]*AWinControl.ComponentState<>[] then exit;

  if AWinControl is TCustomListbox then
    if TCustomListbox(AWinControl).Style < lbOwnerDrawFixed then
      exit;
  if AWinControl is TCustomCombobox then
    if not TCustomCombobox(AWinControl).Style.IsVariable then
      exit;

  ItemIndex := GetItemIndex(PLCLIntfCellRenderer(cell), Widget);

  if ItemIndex < 0 then
    ItemIndex := 0;

  MeasureItemStruct.itemID := UINT(ItemIndex);
  MeasureItemStruct.itemWidth := UINT(width);
  MeasureItemStruct.itemHeight := UINT(AMinHeight);
  Msg.Msg := LM_MEASUREITEM;
  Msg.MeasureItemStruct := @MeasureItemStruct;
  TGtk3Widget(AWinControl.Handle).DeliverMessage(Msg);
  if minimum_height <> nil then
    minimum_height^ := gint(MeasureItemStruct.itemHeight);
  if natural_height <> nil then
    natural_height^ := gint(MeasureItemStruct.itemHeight);

  // writeln('Final cell height ',MeasureItemStruct.itemHeight);
end;

procedure LCLIntfCellRenderer_GetSize(cell: PGtkCellRenderer; widget: PGtkWidget;
  cell_area: PGdkRectangle; x_offset: Pgint;
  y_offset: Pgint; width: Pgint; height: Pgint); cdecl;

var
  CellClass: PLCLIntfCellRendererClass;
  AWinControl: TWinControl;
  ItemIndex: Integer;
  Msg: TLMMeasureItem;
  MeasureItemStruct: TMeasureItemStruct;
begin
  // THIS DOES NOT WORK IN Gtk3 ANYMORE.
  {$IFDEF GTK3DEBUGCELLRENDERER}
  DebugLn('******* LCLIntfCellRenderer_GetSize ********');
  {$ENDIF}
  CellClass := PLCLIntfCellRendererClass(cell^.g_type_instance.g_class);
  // CellClass := PLCLIntfCellRendererClass(gtk_object_get_class(cell));
  CellClass^.DefaultGtkGetSize(cell, Widget, cell_area, x_offset, y_offset,
                               width, height);
  //DebugLn(['LCLIntfCellRenderer_GetSize ',GetWidgetDebugReport(Widget)]);
  AWinControl := GetControl(widget);
  if AWinControl = Nil then exit;
  if [csDestroying,csLoading]*AWinControl.ComponentState<>[] then exit;

  if AWinControl is TCustomListbox then
    if TCustomListbox(AWinControl).Style < lbOwnerDrawFixed then
      exit;
  if AWinControl is TCustomCombobox then
    if not TCustomCombobox(AWinControl).Style.IsVariable then
      exit;

  ItemIndex := GetItemIndex(PLCLIntfCellRenderer(cell), Widget);

  if ItemIndex < 0 then
    ItemIndex := 0;

  MeasureItemStruct.itemID := UINT(ItemIndex);
  MeasureItemStruct.itemWidth := UINT(width^);
  MeasureItemStruct.itemHeight := UINT(height^);
  Msg.Msg := LM_MEASUREITEM;
  Msg.MeasureItemStruct := @MeasureItemStruct;
  TGtk3Widget(AWinControl.Handle).DeliverMessage(Msg);
  width^ := gint(MeasureItemStruct.itemWidth);
  height^ := gint(MeasureItemStruct.itemHeight);
end;

function GtkCellRendererStateToListViewDrawState(CellState: TGtkCellRendererState): TCustomDrawState;
begin
  Result := [];
  if CellState and GTK_CELL_RENDERER_SELECTED > 0 then Result := Result + [cdsSelected];
  if CellState and GTK_CELL_RENDERER_PRELIT > 0 then Result := Result + [cdsHot];
  if CellState and GTK_CELL_RENDERER_INSENSITIVE > 0 then Result := Result + [cdsDisabled, cdsGrayed];
  if CellState and GTK_CELL_RENDERER_FOCUSED > 0 then Result := Result + [cdsFocused];
end;

procedure LCLIntfCellRenderer_Render(cell: PGtkCellRenderer; cr: Pcairo_t;
  Widget: PGtkWidget; background_area: PGdkRectangle; cell_area: PGdkRectangle;
  flags: TGtkCellRendererState); cdecl;
var
  CellClass: PLCLIntfCellRendererClass;
  AWinControl: TWinControl;
  ItemIndex: Integer;
  ColumnIndex: Integer;
  AreaRect: TRect;
  State: TOwnerDrawState;
  Msg: TLMDrawListItem;
  DCWidget: PGtkWidget;
  LVTarget: TCustomDrawTarget;
  LVStage: TCustomDrawStage;
  LVState: TCustomDrawState;
  LVSubItem: Integer;
  TmpDC1,
  TmpDC2: HDC;
  SkipDefaultPaint: Boolean;
begin
  // DebugLn('*** LCLIntfCellRenderer_Render widget=',dbgHex(PtrUInt(Widget)), ' HWND=',dbgs(HwndFromGtkWidget(Widget)));
  {DebugLn(['LCLIntfCellRenderer_Render cell=',dbgs(cell),
    ' ',GetWidgetDebugReport(Widget),' ',
    ' background_area=',dbgGRect(background_area),
    ' cell_area=',dbgGRect(cell_area),
    ' expose_area=',dbgGRect(expose_area)]);}

  ColumnIndex := PLCLIntfCellRenderer(cell)^.ColumnIndex;

  AWinControl := GetControl(widget);

  if (ColumnIndex = -1) and (AWinControl <> nil) and
    (AWinControl.FCompStyle = csListView) then
      ColumnIndex := 0;
  (* debugging
  if Assigned(AWinControl) then
  begin
    DebugLn('*** LCLIntfCellRenderer_Render ',dbgsName(AWinControl),' ColIndex ',dbgs(ColumnIndex));
    if Widget = TGtk3Widget(AWinControl.Handle).Widget then
      DebugLn(' MAIN WIDGET ...')
    else
    if Widget = TGtk3Widget(AWinControl.Handle).GetContainerWidget then
    begin
      DebugLn(' CONTAINER WIDGET ... OK ');
      if wtListBox in TGtk3Widget(AWinControl.Handle).WidgetType then
        ColumnIndex := -1;
      if TGtk3Widget(AWinControl.Handle).Context <> 0 then
        DebugLn(' CONTAINER WIDGET ... HAVE CONTEXT !!!!! ');
    end
    else
    begin
      DebugLn(' FATAL ERROR DONT KNOW WHAT WIDGET IS THIS !');
      if Widget^.parent = TGtk3Widget(AWinControl.Handle).Widget then
        DebugLn(' BUT PARENT IS MAIN WIDGET !')
      else
      if Widget^.parent = TGtk3Widget(AWinControl.Handle).GetContainerWidget then
      begin
        DebugLn(' BUT PARENT IS CONTAINER WIDGET ! CellView=',dbgs(Gtk3IsCellView(Widget)),' w=',dbgHex(PtrUInt(Widget)));
        if Gtk3IsCellView(Widget) then
        begin
          DebugLn(' *** check=', dbgHex(PtrUInt(g_object_get_data(Widget, 'lclwidget'))));
        end;
      end;
    end;
  end;
  *)

  if ColumnIndex > -1 then // listview
  begin
    // DebugLn('Paint 1 ', dbgsName(AWinControl));
    AreaRect := Bounds(background_area^.x, background_area^.y,
                     background_area^.Width, background_area^.Height);


    ItemIndex := GetItemIndex(PLCLIntfCellRenderer(cell), Widget);

    if ItemIndex < 0 then
      ItemIndex := 0;

    if ColumnIndex > 0 then
      LVTarget := dtSubItem
    else
      LVTarget := dtItem;
    if AWinControl.FCompStyle = csListView then
      LVSubItem := ColumnIndex
    else
      LVSubItem := ColumnIndex - 1;
    LVStage := cdPrePaint;
    LVState := GtkCellRendererStateToListViewDrawState(flags);
    DCWidget := Widget;
    TmpDC1 := Gtk3WidgetSet.CreateDCForWidget(DCWidget, nil, cr);
    TmpDC2 := TCustomListViewAccess(AWinControl).Canvas.Handle;
    TCustomListViewAccess(AWinControl).Canvas.Handle := TmpDC1;
    // paint
    SkipDefaultPaint := cdrSkipDefault in TCustomListViewAccess(AWinControl).IntfCustomDraw(LVTarget, LVStage, ItemIndex, LVSubItem, LVState, @AreaRect);

    if SkipDefaultPaint then
    begin
      Gtk3WidgetSet.ReleaseDC(TCustomListViewAccess(AWinControl).Handle,TmpDC1);
      TCustomListViewAccess(AWinControl).Canvas.Handle := TmpDC2;
      Exit;
    end;
  end;

  // draw default
  // CellClass := PLCLIntfCellRendererClass(gtk_object_get_class(cell));
  CellClass := PLCLIntfCellRendererClass(cell^.g_type_instance.g_class);

  // do not call DefaultGtkRender when we are custom drawn listbox.issue #23093
  if (ColumnIndex < 0) and Assigned(AWinControl) then
  begin
    if ([csDestroying,csLoading,csDesigning]*AWinControl.ComponentState<>[]) then
      AWinControl := nil;
    if AWinControl is TCustomListbox then
      if TCustomListbox(AWinControl).Style = lbStandard then
        AWinControl := nil;
    if AWinControl is TCustomCombobox then
      AWinControl := nil;
  end;
  // do default draw only if we are not customdrawn.
  if (ColumnIndex > -1) or ((ColumnIndex < 0) and (AWinControl = nil)) then
  begin
    CellClass^.DefaultGtkRender(cell, cr, Widget, background_area, cell_area, flags);
  end;
  
  if ColumnIndex < 0 then  // is a listbox or combobox
  begin
    // send LM_DrawListItem message
    AWinControl := GetControl(widget);
    // DebugLn('Paint 2 ** ', dbgsName(AWinControl));
    if AWinControl = Nil then exit;
    if [csDestroying,csLoading]*AWinControl.ComponentState<>[] then exit;
  
    // check if the LCL object wants item paint messages
    if AWinControl is TCustomListbox then
      if TCustomListbox(AWinControl).Style = lbStandard then
        exit;
    if AWinControl is TCustomCombobox then
      if not TCustomCombobox(AWinControl).Style.IsOwnerDrawn then
        exit;

    ItemIndex := GetItemIndex(PLCLIntfCellRenderer(cell), Widget);

    if ItemIndex < 0 then
      ItemIndex := 0;

    AreaRect := Bounds(background_area^.x, background_area^.y,
                       background_area^.Width, background_area^.Height);

    // collect state flags
    State:=[odBackgroundPainted];
    if (flags and GTK_CELL_RENDERER_SELECTED)>0 then
      Include(State, odSelected);
    if not Widget^.is_sensitive then
      Include(State, odInactive);
    if Widget^.has_default then
      Include(State, odDefault);
    if (flags and GTK_CELL_RENDERER_FOCUSED) <> 0 then
      Include(State, odFocused);
    
    if AWinControl is TCustomCombobox then
    begin
      if TCustomComboBox(AWinControl).DroppedDown and ((flags and GTK_CELL_RENDERER_PRELIT)>0) then
        Include(State,odSelected);
    end;
  end else // is a listview
  begin
    LVStage := cdPostPaint;
    // paint
    TCustomListViewAccess(AWinControl).IntfCustomDraw(LVTarget, LVStage, ItemIndex, LVSubItem, LVState, @AreaRect);

    TCustomListViewAccess(AWinControl).Canvas.Handle := TmpDC2;
    Gtk3WidgetSet.ReleaseDC(TCustomListViewAccess(AWinControl).Handle,TmpDC1);
    Exit;
  end;

  // ListBox and ComboBox
  // create message and deliverFillChar(Msg,SizeOf(Msg),0);
  // DebugLn('Paint 4 listbox or combobox  ** ', dbgsName(AWinControl));
  Msg.Msg:=LM_DrawListItem;
  New(Msg.DrawListItemStruct);
  try
    FillChar(Msg.DrawListItemStruct^,SizeOf(TDrawListItemStruct),0);
    with Msg.DrawListItemStruct^ do
    begin
      ItemID := UINT(ItemIndex);
      Area := AreaRect;
      (*
      DebugLn('LCLIntfCellRenderer_Render Widget is: TGtk3Widget.Widget ? ',dbgs(Widget = TGtk3Widget(AWinControl.Handle).Widget),
       ' ContainerWidget ? ',dbgs(Widget = TGtk3Widget(AWinControl.Handle).GetContainerWidget),
        ' CAIRO ?!? ',dbgHex(PtrUInt(cr)),' AreaR ',dbgs(Area),' AreaH ',dbgs(Area.Bottom - Area.Top));
      *)
      DCWidget := Widget;
      if (DCWidget^.parent<>nil) and
        Gtk3IsMenuItem(DCWidget^.parent) then
      begin
        // the Widget is a sub widget of a menu item
        // -> allow the LCL to paint over the whole menu item
        DCWidget := DCWidget^.parent;
        Area := Rect(0,0,DCWidget^.get_allocated_width,DCWidget^.get_allocated_height);
      end;
      DC := GTK3WidgetSet.CreateDCForWidget(DCWidget, nil, cr);
      ItemState:=State;
    end;
    TGtk3Widget(AWinControl.Handle).DeliverMessage(Msg);
    GTK3WidgetSet.ReleaseDC(AWinControl.Handle,Msg.DrawListItemStruct^.DC);
  finally
    Dispose(Msg.DrawListItemStruct);
  end;

  //DebugLn(['LCLIntfCellRenderer_Render END ',DbgSName(LCLObject)]);
end;

procedure LCLIntfCellRenderer_ClassInit(aClass: gpointer; {%H-}class_data: gpointer); cdecl;
//aClass: PLCLIntfCellRendererClass
var
  LCLClass: PLCLIntfCellRendererClass;
  RendererClass: PGtkCellRendererClass;
begin
  //DebugLn(['LCLIntfCellRenderer_ClassInit ']);
  LCLClass := PLCLIntfCellRendererClass(aClass);
  // check ok
  // PLCLIntfCellRendererClass(g_type_check_class_cast(aClass, LCLIntfCellRenderer_GetType));
  // PLCLIntfCellRendererClass(aClass);
  RendererClass := PGtkCellRendererClass(aClass);
  // check ok
  // RendererClass := PGtkCellRendererClass(g_type_check_class_cast(aClass, gtk_cell_renderer_text_get_type));

  // GTK_CELL_RENDERER_CLASS(aClass);
  LCLClass^.DefaultGetAlignedArea := RendererClass^.get_aligned_area;
  LCLClass^.DefaultGtkGetSize := RendererClass^.get_size;
  LCLClass^.DefaultGtkRender := RendererClass^.render;
  LCLClass^.DefaultGetRequestMode := RendererClass^.get_request_mode;
  LCLClass^.DefaultGetPreferredWidth := RendererClass^.get_preferred_width;
  LCLClass^.DefaultGetPreferredHeight := RendererClass^.get_preferred_height;
  LCLClass^.DefaultGetPreferredHeightForWidth := RendererClass^.get_preferred_height_for_width;
  LCLClass^.DefaultGetPreferredWidthForHeight := RendererClass^.get_preferred_width_for_height;

  RendererClass^.get_request_mode := @LCLIntfCellRenderer_GetRequestMode;
  RendererClass^.get_preferred_width := @LCLIntfCellRenderer_GetPreferredWidth;
  RendererClass^.get_preferred_height := @LCLIntfCellRenderer_GetPreferredHeight;
  RendererClass^.get_preferred_height_for_width := @LCLIntfCellRenderer_GetPreferredHeightForWidth;
  RendererClass^.get_preferred_width_for_height := @LCLIntfCellRenderer_GetPreferredWidthForHeight;
  // this is deprecated so mark in null since GtkCellRenderer checks if get_size is assigned and
  // then it uses old api.
  RendererClass^.get_size := nil; // @LCLIntfCellRenderer_GetSize;
  RendererClass^.get_aligned_area := @LCLIntfCellRenderer_GetAlignedArea;
  RendererClass^.render := @LCLIntfCellRenderer_Render;
end;

procedure LCLIntfCellRenderer_ClassFinalize({%H-}g_class: gpointer; {%H-}class_data: gpointer); cdecl;
begin
  // DebugLn('LCLIntfCellRenderer_ClassFinalize: finalization');
end;

procedure LCLIntfCellRenderer_Init({%H-}Instance:PGTypeInstance;
  {%H-}theClass: Pointer); cdecl;
// Instance: PLCLIntfCellRenderer;
// theClass: PLCLIntfCellRendererClass
begin
  //DebugLn(['LCLIntfCellRenderer_Init ']);
end;

function LCLIntfCellRenderer_GetType: TGType;
const
  CR_NAME = 'LCLIntfCellRenderer';
  crType: TGType = 0;
  crInfo: TGTypeInfo = (
    class_size: SizeOf(TLCLIntfCellRenderer) + 1024;
    base_init: nil; // TGBaseInitFunc;
    base_finalize: nil; // TGBaseFinalizeFunc;
    class_init: @LCLIntfCellRenderer_ClassInit;
    class_finalize: nil; // @LCLIntfCellRenderer_ClassFinalize; // nil; // TGClassFinalizeFunc;
    class_data: nil;
    instance_size: SizeOf(TLCLIntfCellRenderer) + 1024;
    n_preallocs: SizeOf(TLCLIntfCellRenderer) + 1024;
    instance_init: nil; // TGInstanceInitFunc;
    value_table: nil;
  );
begin
  if (crType = 0) then
  begin
    crType := g_type_from_name(CR_NAME);
    if crType = 0 then
      crType := g_type_register_static(gtk_cell_renderer_text_get_type,'LCLIntfCellRenderer',@crInfo, 0);
  end;
  Result := crType;
end;

function LCLIntfCellRenderer_New: PGtkCellRenderer;
begin
  // PGtkCellRenderer(g_type_class_ref(LCLIntfCellRenderer_GetType));
  Result := g_object_new(LCLIntfCellRenderer_GetType, nil,[]);
end;

procedure LCLIntfCellRenderer_CellDataFunc(cell_layout:PGtkCellLayout;
  cell: PGtkCellRenderer; tree_model: PGtkTreeModel; iter: PGtkTreeIter;
  data: gpointer); cdecl;
var
  LCLCellRenderer: PLCLIntfCellRenderer absolute cell;
  APath: PGtkTreePath;
  S: String;
  // Str: PgChar;
  ListColumn: TListColumn;
  ListItem: TListItem;
  Value: TGValue;
begin
  if not Gtk3IsObject(cell) then
    exit;

  ListItem := nil;
  APath := gtk_tree_model_get_path(tree_model,iter);
  LCLCellRenderer^.Index := gtk_tree_path_get_indices(APath)^;
  LCLCellRenderer^.ColumnIndex := -1;
  gtk_tree_path_free(APath);

  // DebugLn('LCLCellRenderer^.Index=',dbgs(LCLCellRenderer^.Index));

  // WidgetInfo := PWidgetInfo(data);
  // DebugLn(['LCLIntfCellRenderer_CellDataFunc stamp=',iter^.stamp,' tree_model=',dbgs(tree_model),' cell=',dbgs(cell),' WidgetInfo=',WidgetInfo <> nil,' Time=',TimeToStr(Now)]);

  if (wtComboBox in TGtk3Widget(Data).WidgetType) and
    not (TCustomComboBox(TGtk3Widget(Data).LCLObject).Style.HasEditBox) and
    not (TCustomComboBox(TGtk3Widget(Data).LCLObject).DroppedDown) then
  begin
    Value.clear;
    Value.init(G_TYPE_UINT);
    Value.set_uint(0);
    g_object_get_property(PgObject(cell),'ypad',@Value);
    g_object_set_property(PGObject(cell), 'ypad', @Value);
    Value.unset;
  end else
  if wtListView in TGtk3Widget(Data).WidgetType then
  begin
    // DebugLn(['LCLIntfCellRenderer_CellDataFunc stamp=',iter^.stamp,' tree_model=',dbgs(tree_model),' cell=',dbgs(cell),' WidgetInfo=',WidgetInfo <> nil,' Time=',TimeToStr(Now)]);
    //Value.g_type := G_TYPE_STRING;

    gtk_tree_model_get(tree_model, iter, [0, @ListItem, -1]);
    if (ListItem = nil) and TCustomListView(TGtk3Widget(Data).LCLObject).OwnerData then
      ListItem := TCustomListView(TGtk3Widget(Data).LCLObject).Items[LCLCellRenderer^.Index];

    if ListItem = nil then
      Exit;

    ListColumn := TListColumn(g_object_get_data(PGObject(cell_layout), 'TListColumn'));

    if ListColumn = nil then
      LCLCellRenderer^.ColumnIndex := -1
    else
      LCLCellRenderer^.ColumnIndex := ListColumn.Index;

    S := '';
    if LCLCellRenderer^.ColumnIndex <= 0 then
      S := ListItem.Caption
    else
      if ListColumn.Index-1 <= ListItem.SubItems.Count-1 then
        S := ListItem.SubItems.Strings[LCLCellRenderer^.ColumnIndex-1];

    Value.clear;
    Value.init(G_TYPE_STRING);
    Value.set_string(PgChar(S));
    cell^.set_property('text', @Value);
    Value.unset;
  end else
  if (wtListBox in TGtk3Widget(Data).WidgetType) then
  begin
    if TGtk3ListBox(Data).ListBoxStyle < lbOwnerDrawFixed then
    begin
      value.clear;
      value.init(G_TYPE_STRING);
      value.set_string(nil);
      cell^.get_property('text', @Value);
      value.unset;
      // DebugLn('PropertyType=',dbgs(Value.g_type),' IsString=',dbgs(Value.g_type = G_TYPE_STRING),' getString=',Value.get_string);

      S := TCustomListBox(TGtk3Widget(Data).LCLObject).Items.Strings[LCLCellRenderer^.Index];
      // DebugLn('LCLCellRenderer^.Index=',dbgs(LCLCellRenderer^.Index),' text=',Str);
      //Value.data[0].v_pointer := PgChar(S);
      value.clear;
      value.init(G_TYPE_STRING);
      Value.set_string(PgChar(S));
      // set text only if we are not ownerdrawn !
      cell^.set_property('text', @Value);
      Value.unset;
      // DebugLn('IsFixedCellSize ',dbgs(PGtkTreeView(TGtk3Widget(Data).GetContainerWidget)^.get_fixed_height_mode));
    end else
    begin
      //
    end;
  end;

  //DebugLn(['LCLIntfCellRenderer_CellDataFunc ItemIndex=',LCLCellRenderer^.Index]);
end;

procedure LCLIntfRenderer_ColumnCellDataFunc(tree_column: PGtkTreeViewColumn;
  cell: PGtkCellRenderer; tree_model: PGtkTreeModel; iter: PGtkTreeIter;
  data: gpointer); cdecl;
begin
  {$IFDEF GTK3DEBUGCELLRENDERER}
  DebugLn('******* LCLIntfRenderer_ColumnCellDataFunc ********');
  {$ENDIF}
  LCLIntfCellRenderer_CellDataFunc(PGtkCellLayout(tree_column), cell, tree_model, iter, data);
end;

procedure LCLIntfRenderer_GtkCellLayoutDataFunc(cell_layout: PGtkCellLayout;
  cell: PGtkCellRenderer; tree_model: PGtkTreeModel; iter: PGtkTreeIter;
  data: gpointer); cdecl;
begin
  DebugLn('******* LCLIntfRenderer_GtkCellLayoutDataFunc ********');
end;

end.

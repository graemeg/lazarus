{
 *****************************************************************************
 *                               gtk3procs.pas                               *
 *                               -------------                               *
 *                                                                           *
 *                                                                           *
 *****************************************************************************

 *****************************************************************************
  This file is part of the Lazarus Component Library (LCL)

  See the file COPYING.modifiedLGPL.txt, included in this distribution,
  for details about the license.
 *****************************************************************************
}
unit gtk3procs;
{$i gtk3defines.inc}
{$mode objfpc}{$H+}

interface

uses
  {$IFDEF UNIX}
  BaseUnix, Unix,
  {$ENDIF}
  Classes, SysUtils, Controls, StdCtrls, Graphics,
  LazGtk3, LazGdk3, LazGLib2, LazGObject2, LazGdkPixbuf2, LazPango1,
  LCLType, InterfaceBase;

type
  GType = TGType;
{$IFDEF UNIX}
  PPChildSignalEventHandler = ^PChildSignalEventHandler;
  PChildSignalEventHandler = ^TChildSignalEventHandler;
  TChildSignalEventHandler = record
    PID: TPid;
    UserData: PtrInt;
    OnEvent: TChildExitEvent;
    PrevHandler: PChildSignalEventHandler;
    NextHandler: PChildSignalEventHandler;
  end;
{$ENDIF}

  // styles -------------------------------------------------------------------

  TLazGtkStyle = (
    lgsGTK_Default, // without anything
    lgsDefault,     // with rc file
    lgsButton,
    lgsLabel,
    lgsWindow,
    lgsCheckbox,
    lgsRadiobutton,
    lgsMenu,
    lgsMenuBar,
    lgsMenuitem,
    lgsList,
    lgsVerticalScrollbar,
    lgsHorizontalScrollbar,
    lgsTooltip,
    lgsVerticalPaned,
    lgsHorizontalPaned,
    lgsNotebook,
    lgsStatusBar,
    lgsHScale,
    lgsVScale,
    lgsGroupBox,
    lgsTreeView,      // for gtk3
    lgsToolBar,       // toolbar
    lgsToolButton,    // button placed on toolbar
    lgsCalendar,      // button placed on toolbar
    lgsScrolledWindow,
    lgsMemo, // memo
    lgsFrame,
    // user defined
    lgsUserDefined
    );


  PStyleObject = ^TStyleObject;
  TStyleObject = record
    Style: PGTKStyle;
    Owner: PGtkWidget;  // The widget that we hold a reference to.
    Widget: PGTKWidget; // This is the style widget.
    FrameBordersValid: boolean;
    FrameBorders: TRect;
  end;

const
  SysColorMap: array [0..MAX_SYS_COLORS] of DWORD = (
    $C0C0C0,     {COLOR_SCROLLBAR}
    $808000,     {COLOR_BACKGROUND}
    $800000,     {COLOR_ACTIVECAPTION}
    $808080,     {COLOR_INACTIVECAPTION}
    $C0C0C0,     {COLOR_MENU}
    $FFFFFF,     {COLOR_WINDOW}
    $000000,     {COLOR_WINDOWFRAME}
    $000000,     {COLOR_MENUTEXT}
    $000000,     {COLOR_WINDOWTEXT}
    $FFFFFF,     {COLOR_CAPTIONTEXT}
    $C0C0C0,     {COLOR_ACTIVEBORDER}
    $C0C0C0,     {COLOR_INACTIVEBORDER}
    $808080,     {COLOR_APPWORKSPACE}
    $800000,     {COLOR_HIGHLIGHT}
    $FFFFFF,     {COLOR_HIGHLIGHTTEXT}
    $D0D0D0,     {COLOR_BTNFACE}
    $808080,     {COLOR_BTNSHADOW}
    $808080,     {COLOR_GRAYTEXT}
    $000000,     {COLOR_BTNTEXT}
    $C0C0C0,     {COLOR_INACTIVECAPTIONTEXT}
    $F0F0F0,     {COLOR_BTNHIGHLIGHT}
    $000000,     {COLOR_3DDKSHADOW}
    $C0C0C0,     {COLOR_3DLIGHT}
    $000000,     {COLOR_INFOTEXT}
    $AEF3F3,     {COLOR_INFOBK}
    $000000,     {unassigned}
    $000000,     {COLOR_HOTLIGHT}
    $800000,     {COLOR_GRADIENTACTIVECAPTION}
    $808080,     {COLOR_GRADIENTINACTIVECAPTION}
    $800000,     {COLOR_MENUHILIGHT}
    $D0D0D0,     {COLOR_MENUBAR}
    $D0D0D0      {COLOR_FORM}
  ); {end _SysColors}

  LazGtkStyleNames: array[TLazGtkStyle] of string = (
    'gtk_default',
    'default',
    'button',
    'label',
    'window',
    'checkbox',
    'radiobutton',
    'menu',
    'menubar',
    'menuitem',
    'list',
    'vertical scrollbar',
    'horizontal scrollbar',
    'tooltip',
    'vertical paned',
    'horizontal paned',
    'notebook',
    'statusbar',
    'hscale',
    'vscale',
    'groupbox',
    'treeview',
    'toolbar',
    'toolbutton',
    'calendar',
    'scrolled window',
    'memo',
    'frame',
    ''
    );

  NO_PROPAGATION_TO_PARENT = 127;
  GTK3_LEFT_BUTTON = 1;
  GTK3_MIDDLE_BUTTON = 2;
  GTK3_RIGHT_BUTTON = 3;

  G_TYPE_FUNDAMENTAL_SHIFT = 2;
  G_TYPE_FUNDAMENTAL_MAX = 255 shl G_TYPE_FUNDAMENTAL_SHIFT;

{ Constant fundamental types,
  introduced by g_type_init(). }
  G_TYPE_INVALID = GType(0 shl G_TYPE_FUNDAMENTAL_SHIFT);
  G_TYPE_NONE = GType(1 shl G_TYPE_FUNDAMENTAL_SHIFT);
  G_TYPE_INTERFACE = GType(2 shl G_TYPE_FUNDAMENTAL_SHIFT);
  G_TYPE_CHAR = GType(3 shl G_TYPE_FUNDAMENTAL_SHIFT);
  G_TYPE_UCHAR = GType(4 shl G_TYPE_FUNDAMENTAL_SHIFT);
  G_TYPE_BOOLEAN = GType(5 shl G_TYPE_FUNDAMENTAL_SHIFT);
  G_TYPE_INT = GType(6 shl G_TYPE_FUNDAMENTAL_SHIFT);
  G_TYPE_UINT = GType(7 shl G_TYPE_FUNDAMENTAL_SHIFT);
  G_TYPE_LONG = GType(8 shl G_TYPE_FUNDAMENTAL_SHIFT);
  G_TYPE_ULONG = GType(9 shl G_TYPE_FUNDAMENTAL_SHIFT);
  G_TYPE_INT64 = GType(10 shl G_TYPE_FUNDAMENTAL_SHIFT);
  G_TYPE_UINT64 = GType(11 shl G_TYPE_FUNDAMENTAL_SHIFT);
  G_TYPE_ENUM = GType(12 shl G_TYPE_FUNDAMENTAL_SHIFT);
  G_TYPE_FLAGS = GType(13 shl G_TYPE_FUNDAMENTAL_SHIFT);
  G_TYPE_FLOAT = GType(14 shl G_TYPE_FUNDAMENTAL_SHIFT);
  G_TYPE_DOUBLE = GType(15 shl G_TYPE_FUNDAMENTAL_SHIFT);
  G_TYPE_STRING = GType(16 shl G_TYPE_FUNDAMENTAL_SHIFT);
  G_TYPE_POINTER = GType(17 shl G_TYPE_FUNDAMENTAL_SHIFT);
  G_TYPE_BOXED = GType(18 shl G_TYPE_FUNDAMENTAL_SHIFT);
  G_TYPE_PARAM = GType(19 shl G_TYPE_FUNDAMENTAL_SHIFT);
  G_TYPE_OBJECT = GType(20 shl G_TYPE_FUNDAMENTAL_SHIFT);


  GtkListItemGtkListTag = 'GtkList';
  GtkListItemLCLListTag = 'LCLList';

  AGtkJustification: array[TAlignment] of TGTKJustification =
  (
    0, {GTK_JUSTIFY_LEFT  taLeftJustify}
    1, {GTK_JUSTIFY_RIGHT taRightJustify}
    2 {GTK_JUSTIFY_CENTER taCenter}
  );

  AGtkJustificationF: array[TAlignment] of gfloat =
  (
    0.0, {GTK_JUSTIFY_LEFT  taLeftJustify}
    1.0, {GTK_JUSTIFY_RIGHT taRightJustify}
    0.5 {GTK_JUSTIFY_CENTER taCenter}
  );

  BorderStyleShadowMap: array[TBorderStyle] of TGtkShadowType =
  (
   0, {GTK_SHADOW_NONE, bsNone   }
   3 {GTK_SHADOW_ETCHED_IN bsSingle }
  );

  StaticBorderShadowMap: array[TStaticBorderStyle] of TGtkShadowType =
  (
    0, {GTK_SHADOW_NONE, sbsNone   }
    3, {GTK_SHADOW_ETCHED_IN sbsSingle }
    1  {GTK_SHADOW_IN sbsSunken}
  );

  MenuDirection : array[Boolean] of Longint = (
    0, {GTK_PACK_DIRECTION_LTR}
    1 {GTK_PACK_DIRECTION_RTL}
    );



  odnScrollArea = 'scroll_area'; // the gtk_scrolled_window of a widget
                                 // used by TCustomForm and TScrollbox
  odnScrollBar = 'ScrollBar'; // Gives the scrollbar the tgtkrange is belonging to
                              // Used by TScrollbar, TScrollbox and TWinApiWidget
  odnScrollBarLastPos = 'ScrollBarLastPos';

  // checklistbox states
  gtk3CLBState = 0; // byte
  gtk3CLBText = 1; // PGChar
  gtk3CLBDisabled = 3; // gboolean




function Gtk3IsObject(AWidget: PGObject): GBoolean;
function Gtk3IsButton(AWidget: PGObject): GBoolean;

function Gtk3IsCellView(AWidget: PGObject): GBoolean;
function Gtk3IsComboBox(AWidget: PGObject): GBoolean;
function Gtk3IsContainer(AWidget: PGObject): GBoolean;
function Gtk3IsEditable(AWidget: PGObject): GBoolean;
function Gtk3IsEntry(AWidget: PGObject): GBoolean;
function Gtk3IsTextView(AWidget: PGObject): GBoolean;

function Gtk3IsBox(AWidget: PGObject): GBoolean;
function Gtk3IsEventBox(AWidget: PGObject): GBoolean;
function Gtk3IsFixed(AWidget: PGObject): GBoolean;
function Gtk3IsLayout(AWidget: PGObject): GBoolean;

function Gtk3IsMenu(AWidget: PGObject): GBoolean;
function Gtk3IsMenuBar(AWidget: PGObject): GBoolean;
function Gtk3IsMenuItem(AWidget: PGObject): GBoolean;

function Gtk3IsNoteBook(AWidget: PGObject): GBoolean;
function Gtk3IsRadioMenuItem(AWidget: PGObject): GBoolean;

function Gtk3IsHScrollbar(AWidget: PGObject): GBoolean;
function Gtk3IsVScrollbar(AWidget: PGObject): GBoolean;

function Gtk3IsScrolledWindow(AWidget: PGObject): GBoolean;
function Gtk3IsSpinButton(AWidget: PGObject): GBoolean;
function Gtk3IsViewPort(AWidget: PGObject): GBoolean;
function Gtk3IsWidget(AWidget: PGObject): GBoolean;
function Gtk3IsGtkWindow(AWidget: PGObject): GBoolean;
function Gtk3IsGdkWindow(AWidget: PGObject): GBoolean;
function Gtk3IsGdkPixbuf(AWidget: PGObject): GBoolean;
function Gtk3IsGdkVisual(AVisual: PGObject): GBoolean;

function Gtk3IsPangoContext(APangoContext: PGObject): GBoolean;
function Gtk3IsPangoFontMetrics(APangoFontMetrics: PGObject): GBoolean;

function Gtk3TranslateScrollStyle(const SS: TScrollStyle): TPoint;
function Gtk3ScrollTypeToScrollCode(ScrollType: TGtkScrollType): LongWord;

function TGDKColorToTColor(const value : TGDKColor) : TColor;
function TColorToTGDKColor(const value : TColor) : TGDKColor;
function TGdkRGBAToTColor(const value : TGdkRGBA) : TColor;
function TColortoTGdkRGBA(const value : TColor; IgnoreAlpha: Boolean = True) : TGdkRGBA;
function ColorToCairoRGB(AColor: TColor; out ARed, AGreen, ABlue: Double): Boolean;
function RectFromGtkAllocation(AGtkAllocation: TGtkAllocation): TRect;
function RectFromGdkRect(AGdkRect: TGdkRectangle): TRect;
function RectFromPangoRect(APangoRect: TPangoRectangle): TRect;
function GdkRectFromRect(R: TRect): TGdkRectangle;
function GtkAllocationFromRect(R: TRect): TGtkAllocation;

function GdkKeyToLCLKey(AValue: Word): Word;
function GdkModifierStateToLCL(AState: TGdkModifierType; const AIsKeyEvent: Boolean): PtrInt;
function GdkModifierStateToShiftState(AState: TGdkModifierType): TShiftState;

procedure SetWindowCursor(AWindow: PGdkWindow; ACursor: HCursor;
  ARecursive: Boolean; ASetDefault: Boolean);
procedure SetGlobalCursor(Cursor: HCURSOR);

type
  Charsetstr = string[15];
  PCharSetEncodingRec=^TCharSetEncodingRec;
  TCharSetEncodingRec=record
    CharSet: byte;              // winapi charset value
    CharSetReg:CharSetStr;      // Charset Registry Pattern
    CharSetCod:CharSetStr;      // Charset Encoding Pattern
    EnumMap: boolean;           // this mapping is meanful when enumerating fonts?
    CharsetRegPart: boolean;    // is CharsetReg a partial pattern?
    CharsetCodPart: boolean;    // is CharsetCod a partial pattern?
  end;

var
  CharSetEncodingList: TList;
  StandardStyles: array[TLazGtkStyle] of PStyleObject;
  Styles: TStrings;



  procedure AddCharsetEncoding(CharSet: Byte; CharSetReg, CharSetCod: CharSetStr;
    ToEnum:boolean=true; CrPart:boolean=false; CcPart:boolean=false);
  procedure ClearCharsetEncodings;
  procedure CreateDefaultCharsetEncodings;

function GetStyleWidget(aStyle: TLazGtkStyle): PGtkWidget;
procedure ReleaseAllStyles;

implementation
uses LCLProc;

function TGdkRGBAToTColor(const value: TGdkRGBA): TColor;
begin
  Result := Trunc(value.red * $FF)
         or (Trunc(value.green * $FF) shl  8)
         or (Trunc(value.blue * $FF) shl  16)
         or (Trunc(value.alpha * $FF) shl  24);
end;

function TColortoTGdkRGBA(const value: TColor; IgnoreAlpha: Boolean = True): TGdkRGBA;
begin
  Result.red := (value and $FF) / 255;
  Result.green := ((value shr 8) and $FF) / 255;
  Result.blue := ((value shr 16) and $FF) / 255;
  if not IgnoreAlpha then
    Result.alpha := ((value shr 24) and $FF) / 255
  else
    Result.alpha:=1;
end;

function ColorToCairoRGB(AColor: TColor; out ARed, AGreen, ABlue: Double): Boolean;
begin
  Result := True;
  ARed := (AColor and $FF) / 255;
  AGreen := ((AColor shr 8) and $FF) / 255;
  ABlue := ((AColor shr 16) and $FF) / 255;
end;

function RectFromGtkAllocation(AGtkAllocation: TGtkAllocation): TRect;
begin
  with AGtkAllocation do
  begin
    Result.Left := x;
    Result.Top := y;
    Result.Right := Width + x;
    Result.Bottom := Height + y;
  end;
end;

function RectFromGdkRect(AGdkRect: TGdkRectangle): TRect;
begin
  with AGdkRect do
  begin
    Result.Left := x;
    Result.Top := y;
    Result.Right := Width + x;
    Result.Bottom := Height + y;
  end;
end;

function RectFromPangoRect(APangoRect: TPangoRectangle): TRect;
begin
  with APangoRect do
  begin
    Result.Left := PANGO_PIXELS(x);
    Result.Top := PANGO_PIXELS(y);
    Result.Right := PANGO_PIXELS(Width+x);
    Result.Bottom := PANGO_PIXELS(Height+y);
  end;
end;

function GdkRectFromRect(R: TRect): TGdkRectangle;
begin
  with Result do
  begin
    x := R.Left;
    y := R.Top;
    width := R.Right-R.Left;
    height := R.Bottom-R.Top;
  end;
end;

function GtkAllocationFromRect(R: TRect): TGtkAllocation;
begin
  with Result do
  begin
    x := R.Left;
    y := R.Top;
    width := R.Right-R.Left;
    height := R.Bottom-R.Top;
  end;
end;

function Gtk3IsObject(AWidget: PGObject): GBoolean;
begin
  Result := (AWidget <> nil) and g_type_check_instance_is_a(PGTypeInstance(AWidget), g_object_get_type);
end;

function Gtk3IsButton(AWidget: PGObject): GBoolean;
begin
  Result := (AWidget <> nil) and g_type_check_instance_is_a(PGTypeInstance(AWidget), gtk_button_get_type);
end;

function Gtk3IsCellView(AWidget: PGObject): GBoolean;
begin
  Result := (AWidget <> nil) and  g_type_check_instance_is_a(PGTypeInstance(AWidget), gtk_cell_view_get_type);
end;

function Gtk3IsComboBox(AWidget: PGObject): GBoolean;
begin
  Result := (AWidget <> nil) and  g_type_check_instance_is_a(PGTypeInstance(AWidget), gtk_combo_box_get_type);
end;

function Gtk3IsEntry(AWidget: PGObject): GBoolean;
begin
  Result := (AWidget <> nil) and  g_type_check_instance_is_a(PGTypeInstance(AWidget), gtk_entry_get_type);
end;

function Gtk3IsContainer(AWidget: PGObject): GBoolean;
begin
  Result := (AWidget <> nil) and  g_type_check_instance_is_a(PGTypeInstance(AWidget), gtk_container_get_type);
end;

function Gtk3IsEditable(AWidget: PGObject): GBoolean;
begin
  Result := (AWidget <> nil) and  g_type_check_instance_is_a(PGTypeInstance(AWidget), gtk_editable_get_type);
end;

function Gtk3IsTextView(AWidget: PGObject): GBoolean;
begin
  Result := (AWidget <> nil) and  g_type_check_instance_is_a(PGTypeInstance(AWidget), gtk_text_view_get_type);
end;

function Gtk3IsBox(AWidget: PGObject): GBoolean;
begin
  Result := (AWidget <> nil) and  g_type_check_instance_is_a(PGTypeInstance(AWidget), gtk_box_get_type);
end;

function Gtk3IsEventBox(AWidget: PGObject): GBoolean;
begin
  Result := (AWidget <> nil) and  g_type_check_instance_is_a(PGTypeInstance(AWidget), gtk_event_box_get_type);
end;

function Gtk3IsFixed(AWidget: PGObject): GBoolean;
begin
  Result := (AWidget <> nil) and  g_type_check_instance_is_a(PGTypeInstance(AWidget), gtk_fixed_get_type);
end;

function Gtk3IsLayout(AWidget: PGObject): GBoolean;
begin
  Result := (AWidget <> nil) and  g_type_check_instance_is_a(PGTypeInstance(AWidget), gtk_layout_get_type);
end;

function Gtk3IsNoteBook(AWidget: PGObject): GBoolean;
begin
  Result := (AWidget <> nil) and  g_type_check_instance_is_a(PGTypeInstance(AWidget), gtk_notebook_get_type);
end;

function Gtk3IsMenu(AWidget: PGObject): GBoolean;
begin
  Result := (AWidget <> nil) and  g_type_check_instance_is_a(PGTypeInstance(AWidget), gtk_menu_get_type);
end;

function Gtk3IsMenuBar(AWidget: PGObject): GBoolean;
begin
  Result := (AWidget <> nil) and  g_type_check_instance_is_a(PGTypeInstance(AWidget), gtk_menu_bar_get_type);
end;

function Gtk3IsMenuItem(AWidget: PGObject): GBoolean;
begin
  Result := (AWidget <> nil) and  g_type_check_instance_is_a(PGTypeInstance(AWidget), gtk_menu_item_get_type);
end;

function Gtk3IsRadioMenuItem(AWidget: PGObject): GBoolean;
begin
  Result := (AWidget <> nil) and  g_type_check_instance_is_a(PGTypeInstance(AWidget), gtk_radio_menu_item_get_type);
end;

function Gtk3IsHScrollbar(AWidget: PGObject): GBoolean;
begin
  Result := (AWidget <> nil) and  g_type_check_instance_is_a(PGTypeInstance(AWidget), gtk_hscrollbar_get_type);
end;

function Gtk3IsVScrollbar(AWidget: PGObject): GBoolean;
begin
  Result := (AWidget <> nil) and  g_type_check_instance_is_a(PGTypeInstance(AWidget), gtk_vscrollbar_get_type);
end;

function Gtk3IsScrolledWindow(AWidget: PGObject): GBoolean;
begin
  Result := (AWidget <> nil) and  g_type_check_instance_is_a(PGTypeInstance(AWidget), gtk_scrolled_window_get_type);
end;

function Gtk3IsSpinButton(AWidget: PGObject): GBoolean;
begin
  Result := (AWidget <> nil) and  g_type_check_instance_is_a(PGTypeInstance(AWidget), gtk_spin_button_get_type);
end;

function Gtk3IsViewPort(AWidget: PGObject): GBoolean;
begin
  Result := (AWidget <> nil) and  g_type_check_instance_is_a(PGTypeInstance(AWidget), gtk_viewport_get_type);
end;

function Gtk3IsWidget(AWidget: PGObject): GBoolean;
begin
  Result := (AWidget <> nil) and  g_type_check_instance_is_a(PGTypeInstance(AWidget), gtk_widget_get_type);
end;

function Gtk3IsGtkWindow(AWidget: PGObject): GBoolean;
begin
  Result := (AWidget <> nil) and  g_type_check_instance_is_a(PGTypeInstance(AWidget), gtk_window_get_type);
end;

function Gtk3IsGdkWindow(AWidget: PGObject): GBoolean;
begin
  Result := (AWidget <> nil) and  g_type_check_instance_is_a(PGTypeInstance(AWidget), gdk_window_get_type);
end;

function Gtk3IsGdkPixbuf(AWidget: PGObject): GBoolean;
begin
  Result := (AWidget <> nil) and  g_type_check_instance_is_a(PGTypeInstance(AWidget), gdk_pixbuf_get_type);
end;

function Gtk3IsGdkVisual(AVisual: PGObject): GBoolean;
begin
  Result := (AVisual <> nil) and  g_type_check_instance_is_a(PGTypeInstance(AVisual), gdk_visual_get_type);
end;

function Gtk3IsPangoContext(APangoContext: PGObject): GBoolean;
begin
  Result := (APangoContext <> nil) and  g_type_check_instance_is_a(PGTypeInstance(APangoContext), pango_context_get_type);
end;

function Gtk3IsPangoFontMetrics(APangoFontMetrics: PGObject): GBoolean;
begin
  Result := (APangoFontMetrics <> nil);//  and  g_type_check_instance_is_a(PGTypeInstance(APangoFontMetrics), pango_font_metrics_get_type);
end;

function Gtk3TranslateScrollStyle(const SS: TScrollStyle): TPoint;
begin
  case SS of
    ssAutoBoth: Result:=Point(GTK_POLICY_AUTOMATIC, GTK_POLICY_AUTOMATIC);
    ssAutoHorizontal: Result:=Point(GTK_POLICY_AUTOMATIC, GTK_POLICY_NEVER);
    ssAutoVertical: Result:=Point(GTK_POLICY_NEVER, GTK_POLICY_AUTOMATIC);
    ssBoth: Result:=Point(GTK_POLICY_ALWAYS, GTK_POLICY_ALWAYS);
    ssHorizontal: Result:=Point(GTK_POLICY_ALWAYS, GTK_POLICY_NEVER);
    ssNone: Result:=Point(GTK_POLICY_NEVER, GTK_POLICY_NEVER);
    ssVertical: Result:=Point(GTK_POLICY_NEVER, GTK_POLICY_ALWAYS);
  end;
end;

function Gtk3ScrollTypeToScrollCode(ScrollType: TGtkScrollType): LongWord;
begin
  (*
  GTK_SCROLL_NONE: TGtkScrollType = 0;
  GTK_SCROLL_JUMP: TGtkScrollType = 1;
  GTK_SCROLL_STEP_BACKWARD: TGtkScrollType = 2;
  GTK_SCROLL_STEP_FORWARD: TGtkScrollType = 3;
  GTK_SCROLL_PAGE_BACKWARD: TGtkScrollType = 4;
  GTK_SCROLL_PAGE_FORWARD: TGtkScrollType = 5;
  GTK_SCROLL_STEP_UP: TGtkScrollType = 6;
  GTK_SCROLL_STEP_DOWN: TGtkScrollType = 7;
  GTK_SCROLL_PAGE_UP: TGtkScrollType = 8;
  GTK_SCROLL_PAGE_DOWN: TGtkScrollType = 9;
  GTK_SCROLL_STEP_LEFT: TGtkScrollType = 10;
  GTK_SCROLL_STEP_RIGHT: TGtkScrollType = 11;
  GTK_SCROLL_PAGE_LEFT: TGtkScrollType = 12;
  GTK_SCROLL_PAGE_RIGHT: TGtkScrollType = 13;
  GTK_SCROLL_START: TGtkScrollType = 14;
  GTK_SCROLL_END: TGtkScrollType = 15;
  *)
  case ScrollType of
    0{GTK_SCROLL_NONE}          : Result := SB_ENDSCROLL;
    1{GTK_SCROLL_JUMP}          : Result := SB_THUMBTRACK;
    2{GTK_SCROLL_STEP_BACKWARD} : Result := SB_LINELEFT;
    3{GTK_SCROLL_STEP_FORWARD}  : Result := SB_LINERIGHT;
    4{GTK_SCROLL_PAGE_BACKWARD} : Result := SB_PAGELEFT;
    5{GTK_SCROLL_PAGE_FORWARD}  : Result := SB_PAGERIGHT;
    6{GTK_SCROLL_STEP_UP}       : Result := SB_LINEUP;
    7{GTK_SCROLL_STEP_DOWN}     : Result := SB_LINEDOWN;
    8{GTK_SCROLL_PAGE_UP}       : Result := SB_PAGEUP;
    9{GTK_SCROLL_PAGE_DOWN}     : Result := SB_PAGEDOWN;
    10{GTK_SCROLL_STEP_LEFT}     : Result := SB_LINELEFT;
    11{GTK_SCROLL_STEP_RIGHT}    : Result := SB_LINERIGHT;
    12{GTK_SCROLL_PAGE_LEFT}     : Result := SB_PAGELEFT;
    13{GTK_SCROLL_PAGE_RIGHT}    : Result := SB_PAGERIGHT;
    14{GTK_SCROLL_START}         : Result := SB_TOP;
    15{GTK_SCROLL_END}           : Result := SB_BOTTOM;
  end;
end;

function TGDKColorToTColor(const value : TGDKColor) : TColor;
begin
  Result := ((Value.Blue shr 8) shl 16) + ((Value.Green shr 8) shl 8)
           + (Value.Red shr 8);
end;

function TColorToTGDKColor(const value : TColor) : TGDKColor;
begin
  if Value<0 then
  begin
    Result.blue := $FF;
    Result.red := $FF;
    Result.green := $FF;
    Result.pixel := 0;
    exit;
  end;
  with Result do
  begin
    pixel := 0;
    red   := (value and $ff) * 257;
    green := ((value shr 8) and $ff) * 257;
    blue  := ((value shr 16) and $ff) * 257;
  end;
end;

function GdkKeyToLCLKey(AValue: Word): Word;
begin
  if AValue <= $FF then
    exit(AValue);
  Result := VK_UNKNOWN;
  case AValue of
    GDK_KEY_Return, GDK_KEY_KP_Enter, GDK_KEY_3270_Enter: Result := VK_RETURN;
    GDK_KEY_Escape: Result := VK_ESCAPE;
    GDK_KEY_Insert: Result := VK_INSERT;
    GDK_KEY_Delete: Result := VK_DELETE;
    GDK_KEY_BackSpace: Result := VK_BACK;
    GDK_KEY_Home: Result := VK_HOME;
    GDK_KEY_End: Result := VK_END;
    GDK_KEY_Page_Up: Result := VK_PRIOR;
    GDK_KEY_Page_Down: Result := VK_NEXT;
    GDK_KEY_Left, GDK_KEY_KP_LEFT: Result := VK_LEFT;
    GDK_KEY_Up, GDK_KEY_KP_UP: Result := VK_UP;
    GDK_KEY_Right, GDK_KEY_KP_Right: Result := VK_RIGHT;
    GDK_KEY_Down, GDK_KEY_KP_Down: Result := VK_DOWN;
    GDK_KEY_Menu: Result := VK_APPS;
    GDK_KEY_Tab, GDK_KEY_3270_BackTab, GDK_KEY_ISO_Left_Tab: Result := VK_TAB;
    GDK_KEY_Shift_L, GDK_KEY_Shift_R: Result := VK_SHIFT;
    GDK_KEY_Control_L, GDK_KEY_Control_R: Result := VK_CONTROL;
    GDK_KEY_F1 .. GDK_KEY_F30:
      Result:= VK_F1 + (AValue - GDK_KEY_F1);
  end;
end;

function GdkModifierStateToLCL(AState: TGdkModifierType; const AIsKeyEvent: Boolean): PtrInt;
begin
  Result := 0;
  if AState and GDK_BUTTON1_MASK <> 0 then
    Result := Result or MK_LBUTTON;

  if AState and GDK_BUTTON2_MASK <> 0 then
    Result := Result or MK_MBUTTON;

  if AState and GDK_BUTTON3_MASK <> 0 then
    Result := Result or MK_RBUTTON;

  if AState and GDK_BUTTON4_MASK <> 0 then
    Result := Result or MK_XBUTTON1;

  if AState and GDK_BUTTON5_MASK <> 0 then
    Result := Result or MK_XBUTTON2;

  if AState and GDK_SHIFT_MASK <> 0 then
    Result := Result or MK_SHIFT;

  if AState and GDK_CONTROL_MASK <> 0 then
    Result := Result or MK_CONTROL;
end;

function GdkModifierStateToShiftState(AState: TGdkModifierType): TShiftState;
begin
  Result := [];
  if AState and GDK_BUTTON1_MASK <> 0 then
    Include(Result, ssLeft);

  if AState and GDK_BUTTON2_MASK <> 0 then
    Include(Result, ssRight);

  if AState and GDK_BUTTON3_MASK <> 0 then
    Include(Result, ssMiddle);

  if AState and GDK_BUTTON4_MASK <> 0 then
    Include(Result, ssExtra1);

  if AState and GDK_BUTTON5_MASK <> 0 then
    Include(Result, ssExtra2);

  if AState and GDK_SHIFT_MASK <> 0 then
    Include(Result, ssShift);

  if AState and GDK_CONTROL_MASK <> 0 then
    Include(Result, ssCtrl);

  if AState and GDK_META_MASK <> 0 then
    Include(Result, ssAlt);
end;

procedure AddCharsetEncoding(CharSet: Byte; CharSetReg, CharSetCod: CharSetStr;
  ToEnum:boolean=true; CrPart:boolean=false; CcPart:boolean=false);
var
  Rec: PCharsetEncodingRec;
begin
   New(Rec);
   Rec^.Charset := CharSet;
   Rec^.CharsetReg := CharSetReg;
   Rec^.CharsetCod := CharSetCod;
   Rec^.EnumMap := ToEnum;
   Rec^.CharsetRegPart := CrPart;
   Rec^.CharsetCodPart := CcPart;
   CharSetEncodingList.Add(Rec);
end;

procedure ClearCharsetEncodings;
var
  Rec: PCharsetEncodingRec;
  i: Integer;
begin
  for i:=0 to CharsetEncodingList.Count-1 do
  begin
    Rec := CharsetEncodingList[i];
    if Rec<>nil then
      Dispose(Rec);
  end;
  CharsetEncodingList.Clear;
end;

procedure CreateDefaultCharsetEncodings;
begin
  ClearCharsetEncodings;

  AddCharsetEncoding(ANSI_CHARSET,        'iso8859',  '1',    false);
  AddCharsetEncoding(ANSI_CHARSET,        'iso8859',  '3',    false);
  AddCharsetEncoding(ANSI_CHARSET,        'iso8859',  '15',   false);
  AddCharsetEncoding(ANSI_CHARSET,        'ansi',     '0');
  AddCharsetEncoding(ANSI_CHARSET,        '*',        'cp1252');
  AddCharsetEncoding(ANSI_CHARSET,        'iso8859',  '*');
  AddCharsetEncoding(DEFAULT_CHARSET,     '*',        '*');
  AddCharsetEncoding(SYMBOL_CHARSET,      '*',        'fontspecific');
  AddCharsetEncoding(MAC_CHARSET,         '*',        'cpxxxx'); // todo
  AddCharsetEncoding(SHIFTJIS_CHARSET,    'jis',      '0',    true, true);
  AddCharsetEncoding(SHIFTJIS_CHARSET,    '*',        'cp932');
  AddCharsetEncoding(HANGEUL_CHARSET,     '*',        'cp949');
  AddCharsetEncoding(JOHAB_CHARSET,       '*',        'cp1361');
  AddCharsetEncoding(GB2312_CHARSET,      'gb2312',   '0',    true, true);
  AddCharsetEncoding(CHINESEBIG5_CHARSET, 'big5',     '0',    true, true);
  AddCharsetEncoding(CHINESEBIG5_CHARSET, '*',        'cp950');
  AddCharsetEncoding(GREEK_CHARSET,       'iso8859',  '7');
  AddCharsetEncoding(GREEK_CHARSET,       '*',        'cp1253');
  AddCharsetEncoding(TURKISH_CHARSET,     'iso8859',  '9');
  AddCharsetEncoding(TURKISH_CHARSET,     '*',        'cp1254');
  AddCharsetEncoding(VIETNAMESE_CHARSET,  '*',        'cp1258');
  AddCharsetEncoding(HEBREW_CHARSET,      'iso8859',  '8');
  AddCharsetEncoding(HEBREW_CHARSET,      '*',        'cp1255');
  AddCharsetEncoding(ARABIC_CHARSET,      'iso8859',  '6');
  AddCharsetEncoding(ARABIC_CHARSET,      '*',        'cp1256');
  AddCharsetEncoding(BALTIC_CHARSET,      'iso8859',  '13');
  AddCharsetEncoding(BALTIC_CHARSET,      'iso8859',  '4');  // northern europe
  AddCharsetEncoding(BALTIC_CHARSET,      'iso8859',  '14'); // CELTIC_CHARSET
  AddCharsetEncoding(BALTIC_CHARSET,      '*',        'cp1257');
  AddCharsetEncoding(RUSSIAN_CHARSET,     'iso8859',  '5');
  AddCharsetEncoding(RUSSIAN_CHARSET,     'koi8',     '*');
  AddCharsetEncoding(RUSSIAN_CHARSET,     '*',        'cp1251');
  AddCharsetEncoding(THAI_CHARSET,        'iso8859',  '11');
  AddCharsetEncoding(THAI_CHARSET,        'tis620',   '*',  true, true);
  AddCharsetEncoding(THAI_CHARSET,        '*',        'cp874');
  AddCharsetEncoding(EASTEUROPE_CHARSET,  'iso8859',  '2');
  AddCharsetEncoding(EASTEUROPE_CHARSET,  '*',        'cp1250');
  AddCharsetEncoding(OEM_CHARSET,         'ascii',    '0');
  AddCharsetEncoding(OEM_CHARSET,         'iso646',   '*',  true, true);
  AddCharsetEncoding(FCS_ISO_10646_1,     'iso10646', '1');
  AddCharsetEncoding(FCS_ISO_8859_1,      'iso8859',  '1');
  AddCharsetEncoding(FCS_ISO_8859_2,      'iso8859',  '2');
  AddCharsetEncoding(FCS_ISO_8859_3,      'iso8859',  '3');
  AddCharsetEncoding(FCS_ISO_8859_4,      'iso8859',  '4');
  AddCharsetEncoding(FCS_ISO_8859_5,      'iso8859',  '5');
  AddCharsetEncoding(FCS_ISO_8859_6,      'iso8859',  '6');
  AddCharsetEncoding(FCS_ISO_8859_7,      'iso8859',  '7');
  AddCharsetEncoding(FCS_ISO_8859_8,      'iso8859',  '8');
  AddCharsetEncoding(FCS_ISO_8859_9,      'iso8859',  '9');
  AddCharsetEncoding(FCS_ISO_8859_10,     'iso8859',  '10');
  AddCharsetEncoding(FCS_ISO_8859_15,     'iso8859',  '15');
end;

function IndexOfStyleWithName(const WName : String): integer;
begin
  if Styles<>nil then
  begin
    for Result := 0 to Styles.Count-1 do
      if CompareText(WName, Styles[Result]) = 0 then
        exit;
  end;
  Result:=-1;
end;

function NewStyleObject: PStyleObject;
begin
  New(Result);
  FillChar(Result^, SizeOf(TStyleObject), 0);
end;

{.-$DEFINE VerboseUpdateSysColorMap}
procedure UpdateSysColorMap(Widget: PGtkWidget; Lgs: TLazGtkStyle);
{$IFDEF VerboseUpdateSysColorMap}
  function GdkColorAsString(c: TgdkColor): string;
  begin
    Result:='LCL='+DbgS(TGDKColorToTColor(c))
             +' Pixel='+DbgS(c.Pixel)
             +' Red='+DbgS(c.Red)
             +' Green='+DbgS(c.Green)
             +' Blue='+DbgS(c.Blue)
             ;
  end;
{$ENDIF}
var
  MainStyle: PGtkStyle;
begin
  if Widget = nil then exit;
  if not (Lgs in [lgsButton, lgsWindow, lgsMenuBar, lgsMenuitem,
    lgsVerticalScrollbar, lgsHorizontalScrollbar, lgsTooltip, lgsMemo, lgsFrame]) then exit;

  {$IFDEF NoStyle}
  exit;
  {$ENDIF}
  //debugln('UpdateSysColorMap ',GetWidgetDebugReport(Widget));
  // gtk_widget_set_rc_style(Widget);
  MainStyle := Widget^.get_style;
  if MainStyle = nil then exit;
  with MainStyle^ do
  begin
    {$IFDEF VerboseUpdateSysColorMap}
    if rc_style<>nil then
    begin
      with rc_style^ do
      begin
        DebugLn('rc_style:');
        DebugLn(' FG GTK_STATE_NORMAL ',GdkColorAsString(fg[GTK_STATE_NORMAL]));
        DebugLn(' FG GTK_STATE_ACTIVE ',GdkColorAsString(fg[GTK_STATE_ACTIVE]));
        DebugLn(' FG GTK_STATE_PRELIGHT ',GdkColorAsString(fg[GTK_STATE_PRELIGHT]));
        DebugLn(' FG GTK_STATE_SELECTED ',GdkColorAsString(fg[GTK_STATE_SELECTED]));
        DebugLn(' FG GTK_STATE_INSENSITIVE ',GdkColorAsString(fg[GTK_STATE_INSENSITIVE]));
        DebugLn('');
        DebugLn(' BG GTK_STATE_NORMAL ',GdkColorAsString(bg[GTK_STATE_NORMAL]));
        DebugLn(' BG GTK_STATE_ACTIVE ',GdkColorAsString(bg[GTK_STATE_ACTIVE]));
        DebugLn(' BG GTK_STATE_PRELIGHT ',GdkColorAsString(bg[GTK_STATE_PRELIGHT]));
        DebugLn(' BG GTK_STATE_SELECTED ',GdkColorAsString(bg[GTK_STATE_SELECTED]));
        DebugLn(' BG GTK_STATE_INSENSITIVE ',GdkColorAsString(bg[GTK_STATE_INSENSITIVE]));
        DebugLn('');
        DebugLn(' TEXT GTK_STATE_NORMAL ',GdkColorAsString(text[GTK_STATE_NORMAL]));
        DebugLn(' TEXT GTK_STATE_ACTIVE ',GdkColorAsString(text[GTK_STATE_ACTIVE]));
        DebugLn(' TEXT GTK_STATE_PRELIGHT ',GdkColorAsString(text[GTK_STATE_PRELIGHT]));
        DebugLn(' TEXT GTK_STATE_SELECTED ',GdkColorAsString(text[GTK_STATE_SELECTED]));
        DebugLn(' TEXT GTK_STATE_INSENSITIVE ',GdkColorAsString(text[GTK_STATE_INSENSITIVE]));
        DebugLn('');
      end;
    end;

    DebugLn('MainStyle:');
    DebugLn(' FG GTK_STATE_NORMAL ',GdkColorAsString(fg[GTK_STATE_NORMAL]));
    DebugLn(' FG GTK_STATE_ACTIVE ',GdkColorAsString(fg[GTK_STATE_ACTIVE]));
    DebugLn(' FG GTK_STATE_PRELIGHT ',GdkColorAsString(fg[GTK_STATE_PRELIGHT]));
    DebugLn(' FG GTK_STATE_SELECTED ',GdkColorAsString(fg[GTK_STATE_SELECTED]));
    DebugLn(' FG GTK_STATE_INSENSITIVE ',GdkColorAsString(fg[GTK_STATE_INSENSITIVE]));
    DebugLn('');
    DebugLn(' BG GTK_STATE_NORMAL ',GdkColorAsString(bg[GTK_STATE_NORMAL]));
    DebugLn(' BG GTK_STATE_ACTIVE ',GdkColorAsString(bg[GTK_STATE_ACTIVE]));
    DebugLn(' BG GTK_STATE_PRELIGHT ',GdkColorAsString(bg[GTK_STATE_PRELIGHT]));
    DebugLn(' BG GTK_STATE_SELECTED ',GdkColorAsString(bg[GTK_STATE_SELECTED]));
    DebugLn(' BG GTK_STATE_INSENSITIVE ',GdkColorAsString(bg[GTK_STATE_INSENSITIVE]));
    DebugLn('');
    DebugLn(' TEXT GTK_STATE_NORMAL ',GdkColorAsString(text[GTK_STATE_NORMAL]));
    DebugLn(' TEXT GTK_STATE_ACTIVE ',GdkColorAsString(text[GTK_STATE_ACTIVE]));
    DebugLn(' TEXT GTK_STATE_PRELIGHT ',GdkColorAsString(text[GTK_STATE_PRELIGHT]));
    DebugLn(' TEXT GTK_STATE_SELECTED ',GdkColorAsString(text[GTK_STATE_SELECTED]));
    DebugLn(' TEXT GTK_STATE_INSENSITIVE ',GdkColorAsString(text[GTK_STATE_INSENSITIVE]));
    DebugLn('');
    DebugLn(' LIGHT GTK_STATE_NORMAL ',GdkColorAsString(light[GTK_STATE_NORMAL]));
    DebugLn(' LIGHT GTK_STATE_ACTIVE ',GdkColorAsString(light[GTK_STATE_ACTIVE]));
    DebugLn(' LIGHT GTK_STATE_PRELIGHT ',GdkColorAsString(light[GTK_STATE_PRELIGHT]));
    DebugLn(' LIGHT GTK_STATE_SELECTED ',GdkColorAsString(light[GTK_STATE_SELECTED]));
    DebugLn(' LIGHT GTK_STATE_INSENSITIVE ',GdkColorAsString(light[GTK_STATE_INSENSITIVE]));
    DebugLn('');
    DebugLn(' DARK GTK_STATE_NORMAL ',GdkColorAsString(dark[GTK_STATE_NORMAL]));
    DebugLn(' DARK GTK_STATE_ACTIVE ',GdkColorAsString(dark[GTK_STATE_ACTIVE]));
    DebugLn(' DARK GTK_STATE_PRELIGHT ',GdkColorAsString(dark[GTK_STATE_PRELIGHT]));
    DebugLn(' DARK GTK_STATE_SELECTED ',GdkColorAsString(dark[GTK_STATE_SELECTED]));
    DebugLn(' DARK GTK_STATE_INSENSITIVE ',GdkColorAsString(dark[GTK_STATE_INSENSITIVE]));
    DebugLn('');
    DebugLn(' MID GTK_STATE_NORMAL ',GdkColorAsString(mid[GTK_STATE_NORMAL]));
    DebugLn(' MID GTK_STATE_ACTIVE ',GdkColorAsString(mid[GTK_STATE_ACTIVE]));
    DebugLn(' MID GTK_STATE_PRELIGHT ',GdkColorAsString(mid[GTK_STATE_PRELIGHT]));
    DebugLn(' MID GTK_STATE_SELECTED ',GdkColorAsString(mid[GTK_STATE_SELECTED]));
    DebugLn(' MID GTK_STATE_INSENSITIVE ',GdkColorAsString(mid[GTK_STATE_INSENSITIVE]));
    DebugLn('');
    DebugLn(' BASE GTK_STATE_NORMAL ',GdkColorAsString(base[GTK_STATE_NORMAL]));
    DebugLn(' BASE GTK_STATE_ACTIVE ',GdkColorAsString(base[GTK_STATE_ACTIVE]));
    DebugLn(' BASE GTK_STATE_PRELIGHT ',GdkColorAsString(base[GTK_STATE_PRELIGHT]));
    DebugLn(' BASE GTK_STATE_SELECTED ',GdkColorAsString(base[GTK_STATE_SELECTED]));
    DebugLn(' BASE GTK_STATE_INSENSITIVE ',GdkColorAsString(base[GTK_STATE_INSENSITIVE]));
    DebugLn('');
    DebugLn(' BLACK ',GdkColorAsString(black));
    DebugLn(' WHITE ',GdkColorAsString(white));
    {$ENDIF}

    {$IFNDEF DisableGtkSysColors}
    // this map is taken from this research:
    // http://www.endolith.com/wordpress/2008/08/03/wine-colors/
    case Lgs of
      lgsButton:
        begin
          SysColorMap[COLOR_ACTIVEBORDER] := TGDKColorToTColor(bg[GTK_STATE_INSENSITIVE]);
          SysColorMap[COLOR_INACTIVEBORDER] := TGDKColorToTColor(bg[GTK_STATE_INSENSITIVE]);
          SysColorMap[COLOR_WINDOWFRAME] := TGDKColorToTColor(mid[GTK_STATE_SELECTED]);

          SysColorMap[COLOR_BTNFACE] := TGDKColorToTColor(bg[GTK_STATE_INSENSITIVE]);
          SysColorMap[COLOR_BTNSHADOW] := TGDKColorToTColor(dark[GTK_STATE_INSENSITIVE]);
          SysColorMap[COLOR_BTNTEXT] := TGDKColorToTColor(fg[GTK_STATE_NORMAL]);
          SysColorMap[COLOR_BTNHIGHLIGHT] := TGDKColorToTColor(light[GTK_STATE_INSENSITIVE]);
          SysColorMap[COLOR_3DDKSHADOW] := TGDKColorToTColor(black);
          SysColorMap[COLOR_3DLIGHT] := TGDKColorToTColor(bg[GTK_STATE_INSENSITIVE]);
        end;
      lgsMemo:
        begin
          SysColorMap[COLOR_HIGHLIGHT] := TGDKColorToTColor(base[GTK_STATE_SELECTED]);
          SysColorMap[COLOR_HIGHLIGHTTEXT] := TGDKColorToTColor(fg[GTK_STATE_SELECTED]);
          SysColorMap[COLOR_WINDOW] := TGDKColorToTColor(base[GTK_STATE_NORMAL]);
          SysColorMap[COLOR_WINDOWTEXT] := TGDKColorToTColor(text[GTK_STATE_NORMAL]);
        end;
      lgsFrame:
        begin
          SysColorMap[COLOR_BACKGROUND] := TGDKColorToTColor(bg[GTK_STATE_NORMAL]);
        end;
      lgsWindow:
        begin
          // colors which can be only retrieved from the window manager (metacity)
          SysColorMap[COLOR_ACTIVECAPTION] := TGDKColorToTColor(dark[GTK_STATE_SELECTED]);
          SysColorMap[COLOR_INACTIVECAPTION] := TGDKColorToTColor(dark[GTK_STATE_NORMAL]);
          SysColorMap[COLOR_GRADIENTACTIVECAPTION] := TGDKColorToTColor(light[GTK_STATE_SELECTED]);
          SysColorMap[COLOR_GRADIENTINACTIVECAPTION] := TGDKColorToTColor(base[GTK_STATE_NORMAL]);
          SysColorMap[COLOR_CAPTIONTEXT] := TGDKColorToTColor(white);
          SysColorMap[COLOR_INACTIVECAPTIONTEXT] := TGDKColorToTColor(white);
          // others
          SysColorMap[COLOR_APPWORKSPACE] := TGDKColorToTColor(base[GTK_STATE_NORMAL]);
          SysColorMap[COLOR_GRAYTEXT] := TGDKColorToTColor(fg[GTK_STATE_INSENSITIVE]);
          (*
          SysColorMap[COLOR_HIGHLIGHT] := TGDKColorToTColor(base[GTK_STATE_SELECTED]);
          SysColorMap[COLOR_HIGHLIGHTTEXT] := TGDKColorToTColor(fg[GTK_STATE_SELECTED]);
          SysColorMap[COLOR_WINDOW] := TGDKColorToTColor(base[GTK_STATE_NORMAL]);
          SysColorMap[COLOR_WINDOWTEXT] := TGDKColorToTColor(text[GTK_STATE_NORMAL]);
          *)
          SysColorMap[COLOR_HOTLIGHT] := TGDKColorToTColor(light[GTK_STATE_NORMAL]);
          // SysColorMap[COLOR_BACKGROUND] := TGDKColorToTColor(bg[GTK_STATE_PRELIGHT]);
          SysColorMap[COLOR_FORM] := TGDKColorToTColor(bg[GTK_STATE_NORMAL]);
        end;
      lgsMenuBar:
        begin
          SysColorMap[COLOR_MENUBAR] := TGDKColorToTColor(bg[GTK_STATE_NORMAL]);
        end;
      lgsMenuitem:
        begin
          SysColorMap[COLOR_MENU] := TGDKColorToTColor(light[GTK_STATE_ACTIVE]);
          SysColorMap[COLOR_MENUTEXT] := TGDKColorToTColor(fg[GTK_STATE_NORMAL]);
          SysColorMap[COLOR_MENUHILIGHT] := TGDKColorToTColor(bg[GTK_STATE_PRELIGHT]);
        end;
      lgsVerticalScrollbar,
      lgsHorizontalScrollbar:
        begin
          SysColorMap[COLOR_SCROLLBAR] := TGDKColorToTColor(bg[GTK_STATE_ACTIVE]);
        end;
      lgsTooltip:
        begin
          SysColorMap[COLOR_INFOTEXT] := TGDKColorToTColor(fg[GTK_STATE_NORMAL]);
          SysColorMap[COLOR_INFOBK] := TGDKColorToTColor(bg[GTK_STATE_NORMAL]);
        end;
    end;
    {$ENDIF}
  end;
end;

function GetStyleWithName(const WName: String): PGtkWidget;
var
  StyleObject : PStyleObject;
  AIndex: Integer;
  lgs: TLazGtkStyle;
  WidgetName: String;
begin
  Result := nil;
  if (WName='') then exit;
  AIndex := IndexOfStyleWithName(WName);
  if AIndex >= 0 then
  begin
    StyleObject := PStyleObject(Styles.Objects[AIndex]);
    Result := StyleObject^.Widget;
  end else
  begin
    StyleObject := NewStyleObject;
    lgs := lgsUserDefined;
    DebugLn('GetStyleWithName creating style widget ',WName);
    WidgetName := 'LazStyle' + WName;
    if CompareText(WName, LazGtkStyleNames[lgsButton]) = 0 then
    begin
      StyleObject^.Widget := TGtkButton.new;
      lgs := lgsButton;
    end else
    if CompareText(WName, LazGtkStyleNames[lgsNotebook]) = 0 then
    begin
      StyleObject^.Widget := TGtkNoteBook.new;
      lgs := lgsNotebook;
    end else
    if CompareText(WName, LazGtkStyleNames[lgsWindow]) = 0 then
    begin
      StyleObject^.Widget := TGtkWindow.new(GTK_WINDOW_TOPLEVEL);
      lgs := lgsWindow;
    end else
    if CompareText(WName, LazGtkStyleNames[lgsTreeView]) = 0 then
    begin
      StyleObject^.Widget := TGtkTreeView.new;
      lgs := lgsTreeView;
    end else
    if CompareText(WName, LazGtkStyleNames[lgsMemo]) = 0 then
    begin
      StyleObject^.Widget := TGtkTextView.new;
      lgs := lgsMemo;
    end else
    if CompareText(WName, LazGtkStyleNames[lgsFrame]) = 0 then
    begin
      StyleObject^.Widget := TGtkFixed.new;
      lgs := lgsFrame;
    end else
    if CompareText(WName, LazGtkStyleNames[lgsVerticalScrollbar]) = 0 then
    begin
      StyleObject^.Widget := TGtkScrollbar.new(GTK_ORIENTATION_VERTICAL, nil);
      lgs := lgsVerticalScrollbar;
    end else
    if CompareText(WName, LazGtkStyleNames[lgsHorizontalScrollbar]) = 0 then
    begin
      StyleObject^.Widget := TGtkScrollbar.new(GTK_ORIENTATION_HORIZONTAL, nil);
      lgs := lgsHorizontalScrollbar;
    end else
    if CompareText(WName, LazGtkStyleNames[lgsMenuBar]) = 0 then
    begin
      StyleObject^.Widget := TGtkMenuBar.new;
      lgs := lgsMenuBar;
    end else
    if CompareText(WName, LazGtkStyleNames[lgsMenu]) = 0 then
    begin
      StyleObject^.Widget := TGtkMenu.new;
      lgs := lgsMenu;
    end else
    if CompareText(WName, LazGtkStyleNames[lgsMenuitem]) = 0 then
    begin
      StyleObject^.Widget := TGtkMenuItem.new;
      lgs := lgsMenuItem;
    end else
    begin
    end;
    if Gtk3IsWidget(StyleObject^.Widget) then
    begin
      StyleObject^.Widget^.set_name(PgChar(WidgetName));
      StyleObject^.Widget^.show_all;
      StyleObject^.Widget^.ensure_style;
      Styles.AddObject(WName, TObject(StyleObject));
      if lgs <> lgsUserDefined then
        StandardStyles[lgs] := StyleObject;
      StyleObject^.Widget^.hide;

      //TODO: copy stuff from gtk2proc
      UpdateSysColorMap(StyleObject^.Widget, lgs);
      Result := StyleObject^.Widget;
    end else
    begin
      // DebugLn('BUG: GetStyleWithName() created style is not GtkWidget ',WName);
    end;
  end;
end;

function GetStyleWidgetWithName(const WName : String) : PGtkWidget;
var
  l : Longint;
begin
  Result := nil;
  // init style
  GetStyleWithName(WName);
  // return widget
  l := IndexOfStyleWithName(WName);
  if l>=0 then
    Result := PStyleObject(Styles.Objects[l])^.Widget;
end;

function GetStyleWidget(aStyle: TLazGtkStyle) : PGtkWidget;
begin
  if aStyle in [lgsUserDefined] then
    raise Exception.Create('Gtk3: user styles are defined by name');

  if StandardStyles[aStyle]<>nil then
    // already created
    Result := StandardStyles[aStyle]^.Widget
  else
    // create it
    Result := GetStyleWidgetWithName(LazGtkStyleNames[aStyle]);
end;

procedure FreeStyleObject(var StyleObject : PStyleObject);
// internal function to dispose a styleobject
// it does *not* remove it from the style lists
begin
  if StyleObject <> nil then
  begin
    if StyleObject^.Owner <> nil then
    begin
      // GTK owns the reference to top level widgets created by application,
      // so they cannot be destroyed by unreferencing.
      if gtk_widget_is_toplevel(StyleObject^.Owner) then
        gtk_widget_destroy(StyleObject^.Owner)
      else
        g_object_unref(StyleObject^.Owner);
    end;
    if StyleObject^.Style <> nil then
      if StyleObject^.Style^.attach_count > 0 then
        g_object_unref(StyleObject^.Style);
    Dispose(StyleObject);
    StyleObject := nil;
  end;
end;

procedure ReleaseAllStyles;
var
  StyleObject: PStyleObject;
  lgs: TLazGtkStyle;
  i: Integer;
begin
  if Styles = nil then
    exit;
  for i:=Styles.Count-1 downto 0 do
  begin
    StyleObject := PStyleObject(Styles.Objects[i]);
    FreeStyleObject(StyleObject);
  end;
  Styles.Clear;
  for lgs:=Low(TLazGtkStyle) to High(TLazGtkStyle) do
    StandardStyles[lgs]:=nil;
end;

{------------------------------------------------------------------------------
  procedure: SetWindowCursor
  Params:  AWindow : PGDkWindow, ACursor: PGdkCursor, ASetDefault: Boolean
  Returns: Nothing

  Sets the cursor for a window.
  Tries to avoid messing with the cursors of implicitly created
  child windows (e.g. headers in TListView) with the following logic:
  - If Cursor <> nil, saves the old cursor (if not already done or ASetDefault = true)
    before setting the new one.
  - If Cursor = nil, restores the old cursor (if not already done).
  ------------------------------------------------------------------------------}
procedure SetWindowCursor(AWindow: PGdkWindow; Cursor: PGdkCursor; ASetDefault: Boolean);
var
  OldCursor: PGdkCursor;
  Data: gpointer;
begin
  if ASetDefault then //and ((Cursor <> nil) or ( <> nil)) then
  begin
    // Override any old default cursor
    g_object_steal_data(PGObject(AWindow), 'havesavedcursor'); // OK?
    g_object_steal_data(PGObject(AWindow), 'savedcursor');
    gdk_window_set_cursor(AWindow, Cursor);
    Exit;
  end;
  if Cursor <> nil then
  begin
    OldCursor := gdk_window_get_cursor(AWindow);
    if ASetDefault or (g_object_get_data(PGObject(AWindow), 'havesavedcursor') = nil) then
    begin
      g_object_set_data(PGObject(AWindow), 'havesavedcursor', gpointer(1));
      g_object_set_data(PGObject(AWindow), 'savedcursor', gpointer(OldCursor));
    end;
    gdk_pointer_grab(AWindow, False, 0, AWindow, Cursor, 1);
    try
      gdk_window_set_cursor(AWindow, Cursor);
    finally
      gdk_pointer_ungrab(0);
    end;
  end else
  begin
    if g_object_steal_data(PGObject(AWindow), 'havesavedcursor') <> nil then
    begin
      Cursor := g_object_steal_data(PGObject(AWindow), 'savedcursor');
      gdk_window_set_cursor(AWindow, Cursor);
    end;
  end;
end;

{------------------------------------------------------------------------------
  procedure: SetWindowCursor
  Params:  AWindow : PGDkWindow, ACursor: HCursor, ARecursive: Boolean
  Returns: Nothing

  Sets the cursor for a window (or recursively for window with children)
 ------------------------------------------------------------------------------}
procedure SetWindowCursor(AWindow: PGdkWindow; ACursor: HCursor;
  ARecursive: Boolean; ASetDefault: Boolean);
var
  Cursor: PGdkCursor;

  procedure SetCursorRecursive(AWindow: PGdkWindow);
  var
    ChildWindows, ListEntry: PGList;
  begin
    SetWindowCursor(AWindow, Cursor, ASetDefault);

    ChildWindows := gdk_window_get_children(AWindow);

    ListEntry := ChildWindows;
    while ListEntry <> nil do
    begin
      SetCursorRecursive(PGdkWindow(ListEntry^.Data));
      ListEntry := ListEntry^.Next;
    end;
    g_list_free(ChildWindows);
  end;
begin
  Cursor := {%H-}PGdkCursor(ACursor);
  if ARecursive then
    SetCursorRecursive(AWindow)
  else
    SetWindowCursor(AWindow, Cursor, ASetDefault);
end;

{------------------------------------------------------------------------------
  procedure: SetGlobalCursor
  Params:  ACursor: HCursor
  Returns: Nothing

  Sets the cursor for all toplevel windows. Also sets the cursor for all child
  windows recursively provided gdk_get_window_cursor is available.
 ------------------------------------------------------------------------------}
procedure SetGlobalCursor(Cursor: HCURSOR);
var
  TopList: PGList;
  i: Integer;
begin
  TopList := gdk_screen_get_toplevel_windows(gdk_screen_get_default);
  if TopList = nil then
    exit;
  for i := 0 to g_list_length(TopList) - 1 do
  begin
    if (TopList^.Data <> nil) then
      SetWindowCursor(PGDKWindow(TopList^.Data), Cursor,
        True, False);
  end;
  g_list_free(TopList);
end;

end.

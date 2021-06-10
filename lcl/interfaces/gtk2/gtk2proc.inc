{%MainUnit gtk2proc.pp}

{******************************************************************************
                        Misc Support Functs  
 ******************************************************************************
   used by:
     GTKObject
     GTKWinAPI
     GTKCallback
 ******************************************************************************
 *****************************************************************************
  This file is part of the Lazarus Component Library (LCL)

  See the file COPYING.modifiedLGPL.txt, included in this distribution,
  for details about the license.
 *****************************************************************************
}

{off $DEFINE VerboseAccelerator}
{off $DEFINE VerboseUpdateSysColorMap}

{$IFOPT C-}
// Uncomment for local trace
  //{$C+}
  //{$DEFINE ASSERT_IS_ON}
{$ENDIF}

function gtk_widget_get_xthickness(Style : PGTKStyle) : gint;
begin  
  If (Style <> nil) then begin
    result := Style^.xthickness
  end else
    result := 0;
end;

function gtk_widget_get_ythickness(Style : PGTKStyle) : gint;
begin  
  If (Style <> nil) then begin
    result := Style^.ythickness
  end else
    result := 0;
end;

function gtk_widget_get_xthickness(Widget : PGTKWidget) : gint; overload;
begin
  result := gtk_widget_get_xthickness(gtk_widget_get_style(Widget));
end;

function gtk_widget_get_ythickness(Widget : PGTKWidget) : gint; overload;
begin
  result := gtk_widget_get_ythickness(gtk_widget_get_style(Widget));
end;

function GetGtkContainerBorderWidth(Widget: PGtkContainer): gint;
begin
  Result:=(Widget^.flag0 and bm_TGtkContainer_border_width)
          shr bp_TGtkContainer_border_width;
end;

procedure gdk_event_key_get_string(Event : PGDKEventKey; var theString: Pointer);
begin
  theString := Pointer(Event^._String);
end;

procedure gdk_event_key_set_string(Event: PGDKEventKey; const NewString: PChar);
var
  OldString: PChar;
begin
  OldString := Pointer(Event^._String);
  // MG: should we set Event^.length := 0; or is this used for mem allocation?
  if (OldString <> nil) then
  begin
    if (NewString <> nil) then
      OldString[0] := NewString[0]
    else
      OldString[0] := #0;
  end;
end;

function gdk_event_get_type(Event : Pointer) : TGdkEventType;
begin
  result := PGdkEvent(Event)^._type;
end;

function KeyEventWasHandledByLCL(Event: PGdkEventKey; BeforeEvent: boolean
  ): TLCLHandledKeyEvent;
var
  i: Integer;
  EventList: TFPList;
begin
  Result:=nil;
  if BeforeEvent then
    EventList:=LCLHandledKeyEvents
  else
    EventList:=LCLHandledKeyAfterEvents;
  if EventList=nil then exit;
  for i:=0 to EventList.Count-1 do begin
    Result:=TLCLHandledKeyEvent(EventList[i]);
    if Result.IsEqual(Event) then
      exit;
  end;
  Result:=nil;
end;

function RememberKeyEventWasHandledByLCL(Event: PGdkEventKey;
  BeforeEvent: boolean):TLCLHandledKeyEvent;
var
  EventList: TFPList;
begin
  Result:= KeyEventWasHandledByLCL(Event,BeforeEvent);
  if Result<>nil then exit;
  if BeforeEvent then begin
    if LCLHandledKeyEvents=nil then
      LCLHandledKeyEvents:=TFPList.Create;
    EventList:=LCLHandledKeyEvents;
  end else begin
    if LCLHandledKeyAfterEvents=nil then
      LCLHandledKeyAfterEvents:=TFPList.Create;
    EventList:=LCLHandledKeyAfterEvents;
  end;
  Result:=TLCLHandledKeyEvent.Create(Event);
  EventList.Add(Result);
  while EventList.Count>10 do begin
    TLCLHandledKeyEvent(EventList[0]).Release;
    EventList.Delete(0);
  end;
end;

function gtk_class_get_type(aclass : Pointer) : TGtkType;
begin
  If (aclass <> nil) then
    result := PGtkTypeClass(aclass)^.g_Type
  else
    result := 0;
end;

function gtk_object_get_class(anobject : Pointer) : Pointer;
begin
  If (anobject <> nil) then
    result := PGtkTypeObject(anobject)^.g_Class
  else
    result := nil;
end;

function gtk_window_get_modal(window:PGtkWindow):gboolean;
begin
  if assigned(Window) then
    result := GTK2.gtk_window_get_modal(window)
  else
    result := False;
end;

function gdk_region_union_with_rect(region:PGdkRegion; rect:PGdkRectangle) : PGdkRegion;
begin
  result := gdk_region_copy(region);
  GDK2.gdk_region_union_with_rect(result, rect);
end;

function gdk_region_intersect(source1:PGdkRegion; source2:PGdkRegion) : PGdkRegion;
begin
  result := gdk_region_copy(source1);
  GDK2.gdk_region_intersect(result, source2);
end;

function gdk_region_union(source1:PGdkRegion; source2:PGdkRegion) : PGdkRegion;
begin
  result := gdk_region_copy(source1);
  GDK2.gdk_region_union(result, source2);
end;

function gdk_region_subtract(source1:PGdkRegion; source2:PGdkRegion) : PGdkRegion;
begin
  result := gdk_region_copy(source1);
  GDK2.gdk_region_subtract(result, source2);
end;

function gdk_region_xor(source1:PGdkRegion; source2:PGdkRegion) : PGdkRegion;
begin
  result := gdk_region_copy(source1);
  GDK2.gdk_region_xor(result, source2);
end;

Procedure gdk_text_extents(TheFont: TGtkIntfFont;
  Str: PChar; StrLength: integer;
  lbearing, rbearing, width, ascent, descent: Pgint);
var
  Layout : PPangoLayout;
  Extents : TPangoRectangle;
begin
  //DebugLn(['gdk_text_extents Str="',Str,'" StrLength=',StrLength,' lbearing=',lbearing<>nil,' rbearing=',rbearing<>Nil,' width=',width<>nil,' ascent=',ascent<>nil,' descent=',descent<>Nil,' ',TheFont<>Nil]);
  Layout:=TheFont;
  pango_layout_set_single_paragraph_mode(Layout, TRUE);
  pango_layout_set_width(Layout, -1);
  pango_layout_set_text(Layout, Str, StrLength);
  if Assigned(width) then
    pango_layout_get_pixel_size(Layout, width, nil);
  if Assigned(lbearing) or Assigned(rbearing)
  or Assigned(ascent) or Assigned(descent) then begin
    pango_layout_get_extents(Layout, nil, @Extents);

    if Assigned(lbearing) then
      lbearing^ := PANGO_LBEARING(extents) div PANGO_SCALE;

    if Assigned(rbearing) then
      rBearing^ := PANGO_RBEARING(extents) div PANGO_SCALE;

    if Assigned(ascent) then
      ascent^ := PANGO_ASCENT(extents) div PANGO_SCALE;

    if Assigned(descent) then
      descent^ := PANGO_DESCENT(extents) div PANGO_SCALE;
  end;
end;


procedure BeginGDKErrorTrap;
begin
  Inc(GdkTrapCalls);
  if GdkTrapIsSet then
    exit;

  gdk_error_trap_push; //try to prevent GDK Bad Drawable/X Windows Errors
                         // from killing us...

  {$IfDef GDK_ERROR_TRAP_FLUSH}
  gdk_flush; //only for debugging purposes DO NOT enable by default.
               // slows things down intolerably for actual use, if we ever
               // have a real need for it, it should be called from that
               // specific function, since this gets called constantly during
               // drawing.
  {$EndIf}
  
  GdkTrapIsSet:=true;
end;

procedure EndGDKErrorTrap;
var
  Xerror : gint;
begin
  Dec(GdkTrapCalls);
  if (not GdkTrapIsSet) then
    RaiseGDBException('EndGDKErrorTrap without BeginGDKErrorTrap');
  if (GdkTrapCalls > 0) then
    exit;
    
  Xerror := gdk_error_trap_pop;

  GdkTrapIsSet:=false;

  {$IFDEF VerboseGtkToDos}{$note TODO: enable standard error_log handling}{$ENDIF}
  {$IfDef REPORT_GDK_ERRORS}
  If (Xerror<>0) then
    RaiseGDBException('A GDK/X Error occurred, this is normally fatal. The error code was: ' + IntToStr(Xerror));
  {$EndIf}
end;

function dbgGRect(const ARect: PGDKRectangle): string;
begin
  if ARect=nil then begin
    Result:='nil';
  end else begin
    Result:='x='+dbgs(ARect^.x)+',y='+dbgs(ARect^.y)
           +',w='+dbgs(ARect^.width)+',h='+dbgs(ARect^.height);
  end;
end;


{------------------------------------------------------------------------------
  Allocates a new PChar
 ------------------------------------------------------------------------------
function CreatePChar(const s: string): PChar;
begin
  Result:=StrAlloc(length(s) + 1);
  StrPCopy(Result, s);
end;
}
function FindChar(c: char; p:PChar; Max: integer): integer;
begin
  Result:=0;
  while Result<Max do begin
    if p[Result]=c then exit;
    inc(Result);
  end;
  Result:=-1;
end;

{------------------------------------------------------------------------------
  Find line end
 ------------------------------------------------------------------------------}
function FindLineLen(p: PChar; Max: integer): integer;
begin
  Result:=0;
  while Result<Max do begin
    if p[Result] in [#10,#13] then exit;
    inc(Result);
  end;
  Result:=-1;
end;

function RectFromGdkRect(const AGdkRect: TGdkRectangle): TRect;
begin
  with AGdkRect do
  begin
    Result.Left := x;
    Result.Top := y;
    Result.Right := Width + x;
    Result.Bottom := Height + y;
  end;
end;

function GdkRectFromRect(const R: TRect): TGdkRectangle;
begin
  with Result do
  begin
    x := R.Left;
    y := R.Top;
    width := R.Right-R.Left;
    height := R.Bottom-R.Top;
  end;
end;

function AlignToGtkAlign(Align: TAlignment): gfloat;
begin
  case Align of
    taLeftJustify : AlignToGtkAlign := 0.0;
    taCenter      : AlignToGtkAlign := 0.5;
    taRightJustify: AlignToGtkAlign := 1.0;
  end;
end;

function GtkScrollTypeToScrollCode(ScrollType: TGtkScrollType): LongWord;
begin
  case ScrollType of
      GTK_SCROLL_NONE          : Result := SB_ENDSCROLL;
      GTK_SCROLL_JUMP          : Result := SB_THUMBTRACK;
      GTK_SCROLL_STEP_BACKWARD : Result := SB_LINELEFT;
      GTK_SCROLL_STEP_FORWARD  : Result := SB_LINERIGHT;
      GTK_SCROLL_PAGE_BACKWARD : Result := SB_PAGELEFT;
      GTK_SCROLL_PAGE_FORWARD  : Result := SB_PAGERIGHT;
      GTK_SCROLL_STEP_UP       : Result := SB_LINEUP;
      GTK_SCROLL_STEP_DOWN     : Result := SB_LINEDOWN;
      GTK_SCROLL_PAGE_UP       : Result := SB_PAGEUP;
      GTK_SCROLL_PAGE_DOWN     : Result := SB_PAGEDOWN;
      GTK_SCROLL_STEP_LEFT     : Result := SB_LINELEFT;
      GTK_SCROLL_STEP_RIGHT    : Result := SB_LINERIGHT;
      GTK_SCROLL_PAGE_LEFT     : Result := SB_PAGELEFT;
      GTK_SCROLL_PAGE_RIGHT    : Result := SB_PAGERIGHT;
      GTK_SCROLL_START         : Result := SB_TOP;
      GTK_SCROLL_END           : Result := SB_BOTTOM;
    end;
end;

function Gtk2TranslateScrollStyle(const SS: TScrollStyle): TPoint;
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

{------------------------------------------------------------------------------
  function GtkWidgetIsA(Widget: PGtkWidget; AType: TGtkType): boolean;

  The GTK_IS_XXX macro functions in the fpc gtk1.x bindings are not correct.
  They just test the highest level.
  This function checks as the real C macros.
 ------------------------------------------------------------------------------}
function GtkWidgetIsA(Widget: PGtkWidget; AType: TGtkType): boolean;
begin
  Result:=(Widget<>nil)
    and (gtk_object_get_class(Widget)<>nil)
    and gtk_type_is_a(gtk_class_get_type(gtk_object_get_class(Widget)), AType);
end;

{------------------------------------------------------------------------------
  function GetWidgetClassName(Widget: PGtkWidget): string;

  Returns the gtk class name of Widget.
 ------------------------------------------------------------------------------}
function GetWidgetClassName(Widget: PGtkWidget): string;
var
  AType: TGtkType;
  ClassPGChar: Pgchar;
  ClassLen: Integer;
begin
  Result:='';
  if Widget=nil then begin
    Result:='nil';
    exit;
  end;
  if (gtk_object_get_class(Widget)=nil) then begin
    Result:='<Widget without class>';
    exit;
  end;
  AType:=gtk_class_get_type(gtk_object_get_class(Widget));
  ClassPGChar:=gtk_type_name(AType);
  if ClassPGChar=nil then begin
    Result:='<Widget without classname>';
    exit;
  end;
  ClassLen:=strlen(ClassPGChar);
  SetLength(Result,ClassLen);
  if ClassLen>0 then
    Move(ClassPGChar[0],Result[1],ClassLen);
end;

function GetWidgetDebugReport(Widget: PGtkWidget): string;
var
  LCLObject: TObject;
  AWinControl: TWinControl;
  MainWidget: PGtkWidget;
  WinWidgetInfo: PWinWidgetInfo;
  FixedWidget: PGTKWidget;
begin
  if Widget = nil
  then begin
    Result := 'nil';
    exit;
  end;
  Result := Format('%p=%s %s', [Pointer(Widget), GetWidgetClassName(Widget), WidgetFlagsToString(Widget)]);
  LCLObject:=GetNearestLCLObject(Widget);
  Result := Result + Format(' LCLObject=%p', [Pointer(LCLObject)]);
  if LCLObject=nil then exit;
  if LCLObject is TControl then
    Result:=Result+'='+TControl(LCLObject).Name+':'+LCLObject.ClassName
  else
    Result:=Result+'='+LCLObject.ClassName;
  if LCLObject is TWinControl then begin
    AWinControl:=TWinControl(LCLObject);
    if AWinControl.HandleAllocated then begin
      MainWidget:={%H-}PGTKWidget(AWinControl.Handle);
      if MainWidget=Widget
      then Result:=Result+'<Is MainWidget>'
      else Result:=Result+Format('<MainWidget=%p=%s>', [Pointer(MainWidget), GetWidgetClassName(MainWidget)]);
      FixedWidget:=GetFixedWidget(MainWidget);
      if FixedWidget=Widget then
        Result:=Result+'<Is FixedWidget>';
      WinWidgetInfo:=GetWidgetInfo(MainWidget);
      if WinWidgetInfo<>nil then begin
        if WinWidgetInfo^.CoreWidget = Widget then
          Result:=Result+'<Is CoreWidget>';
      end;
    end
    else begin
      Result:=Result+'<NOT HandleAllocated>'
    end;
  end;
end;

function GetWindowDebugReport(AWindow: PGDKWindow): string;
var
  p: gpointer;
  Widget: PGtkWidget;
  WindowType: TGdkWindowType;
  Width: Integer;
  Height: Integer;
  TypeAsStr: String;
begin
  Result := DbgS(AWindow);
  if AWindow = nil then Exit;
  
  // window type
  WindowType := gdk_window_get_type(AWindow);
  case WindowType of
    GDK_WINDOW_ROOT: TypeAsStr := 'Root';
    GDK_WINDOW_TOPLEVEL: TypeAsStr := 'TopLvl';
    GDK_WINDOW_CHILD: TypeAsStr := 'Child';
    GDK_WINDOW_DIALOG: TypeAsStr := 'Dialog';
    GDK_WINDOW_TEMP: TypeAsStr := 'Temp';
    GDK_WINDOW_FOREIGN: TypeAsStr := 'Foreign';
  else
    TypeAsStr := 'Unknown';
  end;
  Result:=Result + ' Type=' + TypeAsStr;
  
  DebugLn(Result);
  // user data
  if WindowType in [GDK_WINDOW_ROOT,GDK_WINDOW_TOPLEVEL,GDK_WINDOW_CHILD, GDK_WINDOW_DIALOG] then
  begin
    p := nil;
    gdk_window_get_user_data(AWindow, @p);
    if GtkWidgetIsA(PGTKWidget(p), gtk_widget_get_type) then
    begin
      Widget := PGTKWidget(p);
      Result := Result + '<Widget[' + GetWidgetDebugReport(Widget) + ']>';
    end
    else
      Result := Result + '<UserData=' + DbgS(p) + ']>';
  end;

  // size
  gdk_window_get_size(AWindow, @Width, @Height);
  Result := Result + ' Size=' + IntToStr(Width) + 'x' + IntToStr(Height);

end;

function GetStyleDebugReport(AStyle: PGTKStyle): string;
begin
  Result:='[';
  if AStyle=nil then
    Result:=Result+'nil'
  else begin
    Result:=Result+'FG[N]:='+GdkColorToStr(@AStyle^.fg[GTK_STATE_NORMAL])+' ';
    Result:=Result+'BG[N]:='+GdkColorToStr(@AStyle^.bg[GTK_STATE_NORMAL])+' ';
    Result:=Result+'Base[N]:='+GdkColorToStr(@AStyle^.base[GTK_STATE_NORMAL])+' ';
    Result:=Result+'BG_Pixmap[N]:='+DbgS(AStyle^.bg_pixmap[GTK_STATE_NORMAL])+' ';
    Result:=Result+'rc_style='+GetRCStyleDebugReport(AStyle^.rc_style);
  end;
  Result:=Result+']';
end;

function GetRCStyleDebugReport(AStyle: PGtkRcStyle): string;
begin
  Result:='[';
  if AStyle=nil then
    Result:=Result+'nil'
  else begin
    Result:=Result+'name="'+AStyle^.name+'" ';
    Result:=Result+'font_desc=['+GetPangoDescriptionReport(AStyle^.font_desc)+'] ';
    Result:=Result+'bg_pixmap_name[N]="'+AStyle^.bg_pixmap_name[GTK_STATE_NORMAL]+'" ';
  end;
  Result:=Result+']';
end;

function GetPangoDescriptionReport(Desc: PPangoFontDescription): string;
begin
  if Desc=nil then begin
    Result:='nil';
  end else begin
    Result:='family='+pango_font_description_get_family(Desc);
    Result:=Result+' size='+IntToStr(pango_font_description_get_size(Desc));
    Result:=Result+' weight='+IntToStr(pango_font_description_get_weight(Desc));
    Result:=Result+' variant='+IntToStr(pango_font_description_get_variant(Desc));
    Result:=Result+' style='+IntToStr(pango_font_description_get_style(Desc));
    Result:=Result+' stretch='+IntToStr(pango_font_description_get_stretch(Desc));
  end;
end;

function WidgetFlagsToString(Widget: PGtkWidget): string;
begin
  Result:='[';
  if Widget=nil then
    Result:=Result+'nil'
  else begin
    if GTK_WIDGET_REALIZED(Widget) then
      Result:=Result+'R';
    if GTK_WIDGET_MAPPED(Widget) then
      Result:=Result+'M';
    if GTK_WIDGET_VISIBLE(Widget) then
      Result:=Result+'V';
    if GTK_WIDGET_DRAWABLE(Widget) then
      Result:=Result+'D';
    if GTK_WIDGET_CAN_FOCUS(Widget) then
      Result:=Result+'F';
    if GTK_WIDGET_RC_STYLE(Widget) then
      Result:=Result+'St';
    if GTK_WIDGET_PARENT_SENSITIVE(Widget) then
      Result:=Result+'Pr';
    if GTK_WIDGET_NO_WINDOW(Widget) then
      Result:=Result+'Nw';
    if GTK_WIDGET_COMPOSITE_CHILD(Widget) then
      Result:=Result+'Cc';
    if GTK_WIDGET_APP_PAINTABLE(Widget) then
      Result:=Result+'Ap';
    if GTK_WIDGET_DOUBLE_BUFFERED(Widget) then
      Result:=Result+'Db';
  end;
  Result:=Result+']';
end;

function GdkColorToStr(Color: PGDKColor): string;
begin
  if Color=nil then
    Result:='nil'
  else
    Result:='R'+HexStr(Color^.Red,4)+'G'+HexStr(Color^.Green,4)
           +'B'+HexStr(Color^.Blue,4);
end;

function GetWidgetStyleReport(Widget: PGtkWidget): string;
var
  AStyle: PGtkStyle;
  ARCStyle: PGtkRcStyle;
begin
  Result:='';
  if Widget=nil then exit;
  AStyle:=gtk_widget_get_style(Widget);
  if AStyle=nil then begin
    Result:='nil';
    exit;
  end;
  Result:=Result+'attach_count='+dbgs(AStyle^.attach_count);
  ARCStyle:=AStyle^.rc_style;
  if ARCStyle=nil then begin
    Result:=Result+' rc_style=nil';
  end else begin
    Result:=Result+' rc_style=[';
    Result:=Result+GetPangoDescriptionReport(AStyle^.font_desc);
    Result:=Result+']';
  end;
end;

{------------------------------------------------------------------------------
  function WidgetIsDestroyingHandle(Widget: PGtkWidget): boolean;

  Tests if Destruction Mark is set.
 ------------------------------------------------------------------------------}
function WidgetIsDestroyingHandle(Widget: PGtkWidget): boolean;
begin
  Result:=g_object_get_data(PGObject(Widget),'LCLDestroyingHandle')<>nil;
end;

{------------------------------------------------------------------------------
  procedure SetWidgetIsDestroyingHandle(Widget: PGtkWidget);

  Marks widget for destruction.
 ------------------------------------------------------------------------------}
procedure SetWidgetIsDestroyingHandle(Widget: PGtkWidget);
begin
  g_object_set_data(PGObject(Widget),'LCLDestroyingHandle',Widget);
end;

{------------------------------------------------------------------------------
  function ComponentIsDestroyingHandle(AWinControl: TWinControl): boolean;

  Tests if Destruction Mark is set.
 ------------------------------------------------------------------------------}
function ComponentIsDestroyingHandle(AWinControl: TWinControl): boolean;
begin
  Result:=
    (AWinControl is TWinControl) and (AWinControl.HandleAllocated)
    and WidgetIsDestroyingHandle({%H-}PGtkWidget(AWinControl.Handle));
end;

{------------------------------------------------------------------------------
  function LockOnChange(GtkObject: PGtkObject; LockOffset: integer): integer;

  Adds LockOffset to the OnChangeLock and returns the result.
 ------------------------------------------------------------------------------}
function LockOnChange(GtkObject: PGtkObject; LockOffset: integer): integer; 
var
  Info: PWidgetInfo;
begin
  Info := GetWidgetInfo(GtkObject);
  if Info = nil then Exit(0);
  Inc(Info^.ChangeLock, LockOffset);
  Result := Info^.ChangeLock;
end;

{------------------------------------------------------------------------------
  Reset cached LastWFPResult used by WindowFromPoint.LastWFPResult should be
  invalidated when some control at LastWFPMousePos is hidden, shown, enabled,
  disabled, moved.
 ------------------------------------------------------------------------------}
procedure InvalidateLastWFPResult(AControl: TWinControl; const ABounds: TRect);
begin
  if PtInRect(ABounds, LastWFPMousePos) and
    GTK_IS_OBJECT({%H-}Pointer(LastWFPResult)) then
  begin
    if (AControl <> nil) and (AControl.Handle = LastWFPResult) and
      AControl.Enabled and AControl.Visible then
        exit;
    g_signal_handlers_disconnect_by_func({%H-}GPointer(LastWFPResult),
      TGTKSignalFunc(@DestroyWindowFromPointCB), nil);
    LastWFPResult := 0;
    LastWFPMousePos := Point(High(Integer), High(Integer));
  end;
end;

procedure SetFormShowInTaskbar(AForm: TCustomForm; const AValue: TShowInTaskbar);
var
  Enable: boolean;
  Widget: PGtkWidget;
begin
  if (AForm.Parent <> nil) or
     (AForm.ParentWindow <> 0) or
     not (AForm.HandleAllocated) then Exit;

  Widget := {%H-}PGtkWidget(AForm.Handle);
  // if widget not yet realized then exit
  if Widget^.Window = nil then
    Exit;

  Enable := AValue <> stNever;
  {if (AValue = stDefault)
  and (Application<>nil) and (Application.MainForm <> nil)
  and (Application.MainForm <> AForm) then
    Enable := false;}

  //debugln('SetGtkWindowShowInTaskbar ',DbgSName(AForm),' ',dbgs(Enable));
  // The button reappears in some (still unknown) situations, but has the
  //'skip-taskbar-hint' property still set to True, so invoking the function
  //doesn't have an effect. Resetting the property makes it work.

  if (not Enable) and gtk_window_get_skip_taskbar_hint(PGtkWindow(Widget)) then
    gtk_window_set_skip_taskbar_hint(PGtkWindow(Widget), False);

  SetGtkWindowShowInTaskbar(PGtkWindow(Widget), Enable);
end;

procedure SetGtkWindowShowInTaskbar(AGtkWindow: PGtkWindow; Value: boolean);
begin
  //DebugLn(['SetGtkWindowShowInTaskbar ',GetWidgetDebugReport(PGtkWidget(AGtkWindow)),' ',Value]);
  gtk_window_set_skip_taskbar_hint(AGtkWindow, not Value);
end;

procedure SetWindowFullScreen(AForm: TCustomForm; const AValue: Boolean);
begin
  If AValue then
    GTK_Window_FullScreen({%H-}PGTKWindow(AForm.Handle))
  else
    GTK_Window_UnFullScreen({%H-}PGTKWindow(AForm.Handle));
end;

procedure GrabKeyBoardToForm(AForm: TCustomForm);
begin
  {$IFDEF HasX}
  XGrabKeyboard(gdk_display, FormToX11Window(AForm), true, GrabModeASync,
                GrabModeASync, CurrentTime);
  {$ENDIF}
end;

procedure ReleaseKeyBoardFromForm(AForm: TCustomForm);
begin
  {$IFDEF HasX}
  XUngrabKeyboard(gdk_display, CurrentTime);
  {$ENDIF}
end;

procedure GrabMouseToForm(AForm: TCustomForm);
{$IFDEF HasX}
var
  eventMask: LongInt;
begin
  eventMask := ButtonPressMask or ButtonReleaseMask
               or PointerMotionMask or PointerMotionHintMask;

  XGrabPointer(gdk_display, FormToX11Window(AForm), true,
               eventMask, GrabModeASync, GrabModeAsync,  FormToX11Window(AForm),
               None, CurrentTime);
end;
{$ELSE}
begin
end;
{$ENDIF}

procedure ReleaseMouseFromForm(AForm: TCustomForm);
begin
  {$IFDEF HasX}
  XUngrabPointer(gdk_display, CurrentTime);
  {$ENDIF}
end;

procedure GtkWindowShowModal(AForm: TCustomForm; GtkWindow: PGtkWindow);
begin
  if (GtkWindow=nil) then exit;
  UnsetResizeRequest(PgtkWidget(GtkWindow));

  if ModalWindows=nil then ModalWindows:=TFPList.Create;
  ModalWindows.Add(GtkWindow);
  {$IFDEF HASX}
  if Gtk2WidgetSet.GetDesktopWidget <> nil then
    gtk_window_set_transient_for(GtkWindow, PGtkWindow(Gtk2WidgetSet.GetDesktopWidget));
  {$ENDIF}
  {$IFNDEF gtk_no_set_modal}
  gtk_window_set_modal(GtkWindow, true);
  {$ENDIF}

  gtk_window_present(GtkWindow);

  if (AForm <> nil) and (AForm.ShowInTaskBar <> stAlways) and
    (gtk_window_get_type_hint(GtkWindow) <> GDK_WINDOW_TYPE_HINT_DIALOG) then
    gtk_window_set_skip_taskbar_hint(GtkWindow, True);

  {$IFDEF VerboseTransient}
  DebugLn('TGtkWidgetSet.GtkWindowShowModal ',DbgSName(AForm));
  {$ENDIF}
  GTK2WidgetSet.UpdateTransientWindows;
end;

{$IFDEF HasX}
function FormToX11Window(const AForm: TCustomForm): X.TWindow;
var
  Widget: PGtkWidget;
begin
  Result:=0;
  if (AForm=nil) or (not AForm.HandleAllocated) then exit;
  Widget:={%H-}PGtkWidget(AForm.Handle);
  if Widget^.window = nil then exit;
  Result := gdk_window_xwindow(Widget^.window);
end;
{$ENDIF}

procedure SetLabelAlignment(LabelWidget: PGtkLabel; const NewAlignment: TAlignment);
const
  cLabelAlignX : array[TAlignment] of gfloat = (0.0, 1.0, 0.5);
  cLabelAlignY : array[TTextLayout] of gfloat = (0.0, 0.5, 1.0);
  cLabelAlign : array[TAlignment] of TGtkJustification =
    (GTK_JUSTIFY_LEFT, GTK_JUSTIFY_RIGHT, GTK_JUSTIFY_CENTER);
begin
  gtk_label_set_justify(LabelWidget, cLabelAlign[NewAlignment]);
  gtk_misc_set_alignment(GTK_MISC(LabelWidget), cLabelAlignX[NewAlignment],
                        cLabelAlignY[tlTop]);
end;

{------------------------------------------------------------------------------
  function GtkPaintMessageToPaintMessage(var GtkPaintMsg: TLMGtkPaint;
    FreeGtkPaintMsg: boolean): TLMPaint;

  Converts a LM_GTKPAINT message to a LM_PAINT message
 ------------------------------------------------------------------------------}
function GtkPaintMessageToPaintMessage(var GtkPaintMsg: TLMGtkPaint;
  FreeGtkPaintMsg: boolean): TLMPaint;
var
  PS : PPaintStruct;
  Widget: PGtkWidget;
begin
  FillByte(Result{%H-},SizeOf(Result),0);
  Result.Msg := LM_PAINT;
  New(PS);
  FillChar(PS^, SizeOf(TPaintStruct), 0);
  Widget := GtkPaintMsg.Data.Widget;
  If GtkPaintMsg.Data.RepaintAll then
    PS^.rcPaint := Rect(0, 0, Widget^.Allocation.Width, Widget^.Allocation.Height)
  else
    PS^.rcPaint := GtkPaintMsg.Data.Rect;

  Result.DC := BeginPaint(THandle({%H-}PtrUInt(Widget)), PS^);
  Result.PaintStruct := PS;
  Result.Result := 0;
  if FreeGtkPaintMsg then
    FreeThenNil(GtkPaintMsg.Data);
end;

procedure FinalizePaintMessage(Msg: PLMessage);
var
  PS: PPaintStruct;
  DC: TGtkDeviceContext;
begin
  if (Msg^.Msg = LM_PAINT) then
  begin
    if Msg^.LParam <> 0 then
    begin
      PS := {%H-}PPaintStruct(Msg^.LParam);
      if Msg^.WParam <> 0 then
        DC := TGtkDeviceContext(Msg^.WParam)
      else
        DC := TGtkDeviceContext(PS^.hdc);
      EndPaint(THandle({%H-}PtrUInt(DC.Widget)), PS^);
      Dispose(PS);
      Msg^.LParam:=0;
      Msg^.WParam:=0;
    end
    else
    if Msg^.WParam<>0 then
    begin
      ReleaseDC(0, Msg^.WParam);
      Msg^.WParam := 0;
    end;
  end else
  if Msg^.Msg = LM_GTKPAINT then
    FreeThenNil(TLMGtkPaintData(Msg^.WParam));
end;

procedure FinalizePaintTagMsg(Msg: PMsg);
var
  PS: PPaintStruct;
  DC: TGtkDeviceContext;
begin
  if (Msg^.Message = LM_PAINT) then
  begin
    if Msg^.LParam <> 0 then
    begin
      PS := {%H-}PPaintStruct(Msg^.LParam);
      if Msg^.WParam<>0 then
        DC := TGtkDeviceContext(Msg^.WParam)
      else
        DC := TGtkDeviceContext(PS^.hdc);
      EndPaint(THandle({%H-}PtrUInt(DC.Widget)), PS^);
      Dispose(PS);
      Msg^.LParam:=0;
      Msg^.WParam:=0;
    end else
    if Msg^.WParam<>0 then
    begin
      ReleaseDC(0, Msg^.WParam);
      Msg^.WParam:=0;
    end;
  end else
  if Msg^.Message = LM_GTKPAINT then
    FreeThenNil(TObject(Msg^.WParam));
end;

procedure SetGCRasterOperation(TheGC: PGDKGC; Rop: Cardinal);
begin
  case ROP of
    SRCCOPY : gdk_gc_set_function(TheGC, GDK_COPY);
    SRCPAINT : gdk_gc_set_function(TheGC, GDK_OR);
    SRCAND : gdk_gc_set_function(TheGC, GDK_AND);
    SRCINVERT : gdk_gc_set_function(TheGC, GDK_XOR);
    SRCERASE : gdk_gc_set_function(TheGC, GDK_AND_REVERSE);
    NOTSRCCOPY : gdk_gc_set_function(TheGC, GDK_COPY_INVERT);
    NOTSRCERASE : gdk_gc_set_function(TheGC, GDK_NOR);
    MERGEPAINT : gdk_gc_set_function(TheGC, GDK_OR_INVERT);
    DSTINVERT : gdk_gc_set_function(TheGC, GDK_INVERT);
    BLACKNESS : gdk_gc_set_function(TheGC, GDK_CLEAR);
    WHITENESS : gdk_gc_set_function(TheGC, GDK_SET);
    else
    begin
      gdk_gc_set_function(TheGC, GDK_COPY);
      DebugLn('WARNING: [SetRasterOperation] Got unknown/unsupported CopyMode!!');
    end;
  end;
end;

procedure MergeClipping(DestinationDC: TGtkDeviceContext; DestinationGC: PGDKGC;
  X,Y,Width,Height: integer; ClipMergeMask: PGdkBitmap;
  ClipMergeMaskX, ClipMergeMaskY: integer;
  out NewClipMask: PGdkBitmap);
// merge ClipMergeMask into the destination clipping mask at the
// destination rectangle
var
  temp_gc : PGDKGC;
  temp_color : TGDKColor;
  RGNType : Longint;
  OffsetXY: TPoint;
  //ClipMergeMaskWidth, ClipMergeMaskHeight: integer;
begin
  {$IFDEF VerboseStretchCopyArea}
  DebugLn('MergeClipping START DestinationDC=',DbgS(DestinationDC),
    ' DestinationGC=',DbgS(DestinationGC),
    ' X='+dbgs(X),' Y='+dbgs(Y),' Width='+dbgs(Width),' Height='+dbgs(Height),
    ' ClipMergeMask=',DbgS(ClipMergeMask),
    ' ClipMergeMaskX=',dbgs(ClipMergeMaskX),' ClipMergeMaskY=',dbgs(ClipMergeMaskY));
  {$ENDIF}

  // activate clipping region of destination
  DestinationDC.SelectRegion;
  NewClipMask := nil;
  if (ClipMergeMask = nil) then exit;

  BeginGDKErrorTrap;
  // create temporary mask with the size of the destination rectangle
  NewClipMask := PGdkBitmap(gdk_pixmap_new(nil, width, height, 1));
  // create temporary GC for combination mask
  temp_gc := gdk_gc_new(NewClipMask);
  gdk_gc_set_clip_region(temp_gc, nil); // no default clipping
  gdk_gc_set_clip_rectangle(temp_gc, nil);

  // clear mask
  temp_color.pixel := 0;
  gdk_gc_set_foreground(temp_gc, @temp_color);
  gdk_draw_rectangle(NewClipMask, temp_gc, 1, 0, 0, width+1, height+1);

  // copy the destination clipping mask into the temporary mask
  with DestinationDC do begin
    If (ClipRegion <> nil) then begin
      RGNType := RegionType(ClipRegion^.GDIRegionObject);
      If (RGNType <> ERROR) and (RGNType <> NULLREGION) then begin
        // destination has a clipping mask
        {$IFDEF VerboseStretchCopyArea}
        DebugLn('MergeClipping Destination has clipping mask -> apply to temp GC');
        {$ENDIF}
        // -> copy the destination clipping mask to the temporary mask
        //    The X,Y coordinate in the destination relates to
        //    0,0 in the temporary mask.
        //    The clip region of dest is always at 0,0 in dest
        OffsetXY:=Point(-X,-Y);
        // 1. Move the region
        gdk_region_offset(ClipRegion^.GDIRegionObject,OffsetXY.X,OffsetXY.Y);
        // 2. Apply region to temporary mask
        gdk_gc_set_clip_region(temp_gc, ClipRegion^.GDIRegionObject);
        // 3. Undo moving the region
        gdk_region_offset(ClipRegion^.GDIRegionObject,-OffsetXY.X,-OffsetXY.Y);
      end;
    end;
  end;
  
  // merge the source clipping mask into the temporary mask
  //gdk_window_get_size(ClipMergeMask,@ClipMergeMaskWidth,@ClipMergeMaskHeight);
  //DebugLn('MergeClipping A MergeMask Size=',ClipMergeMaskWidth,',',ClipMergeMaskHeight);
  gdk_draw_pixmap(NewClipMask, temp_gc,
                  ClipMergeMask, ClipMergeMaskX, ClipMergeMaskY, 0, 0, -1, -1);

  // free the temporary GC
  gdk_gc_destroy(temp_gc);

  // apply the new mask to the destination GC
  // The new mask has only the size of the destination rectangle, not of
  // the whole destination. Apply it to destination and move it to the right
  // position.
  gdk_gc_set_clip_mask(DestinationGC, NewClipMask);
  gdk_gc_set_clip_origin(DestinationGC, x, y);
  EndGDKErrorTrap;
end;

function CreatePixbufFromImageAndMask(ASrc: PGdkDrawable; ASrcX, ASrcY, ASrcWidth,
  ASrcHeight: integer; ASrcColorMap: PGdkColormap; ASrcMask: PGdkBitmap): PGdkPixbuf;

  procedure Warn(const AText: String);
  begin
    DebugLn('[WARNING] ScalePixmapAndMask: ' + AText);
  end;

  procedure ApplyMask(APixels, AMask: pguchar);
  type
    TPixbufPixel = record
      R,G,B,A: Byte;
    end;
  var
    RGBA: ^TPixbufPixel absolute APixels;
    Mask: ^TPixbufPixel absolute AMask;
    n: Integer;
  begin
    for n := 0 to (ASrcHeight * ASrcWidth) - 1 do
    begin
      if (Mask^.B = 0) and (Mask^.G = 0) and (Mask^.R = 0)
      then RGBA^.A := 0;
      inc(RGBA);
      inc(Mask);
    end;
  end;
  
var
  Msk: PGdkPixbuf;
  FullSrcWidth, FullSrcHeight: integer;
begin
  Result := nil;
  if ASrc = nil then Exit;

  gdk_window_get_size(PGDKWindow(ASrc), @FullSrcWidth, @FullSrcHeight);
  if ASrcX + ASrcWidth > FullSrcWidth
  then begin
    Warn('ASrcX+ASrcWidth>FullSrcWidth');
  end;
  if ASrcY + ASrcHeight > FullSrcHeight
  then begin
    Warn('ASrcY+ASrcHeight>FullSrcHeight');
  end;

  // Creating PixBuf from pixmap
  Result := CreatePixbufFromDrawable(ASrc, ASrcColorMap, ASrcMask <> nil, ASrcX, ASrcY, 0, 0, ASrcWidth, ASrcHeight);
  if Result = nil
  then begin
    Warn('Result=nil');
    Exit;
  end;
  //DbgDumpPixbuf(Result, 'Pixbuf from Source');

  // Apply mask if present
  if ASrcMask <> nil
  then begin
    if gdk_pixbuf_get_rowstride(Result) <> ASrcWidth shl 2
    then begin
      Warn('rowstride <> 4*width');
      gdk_pixbuf_unref(Result);
      Result := nil;
      Exit;
    end;

    Msk := CreatePixbufFromDrawable(ASrcMask, nil, True, ASrcX, ASrcY, 0, 0, ASrcWidth, ASrcHeight);
    ApplyMask(gdk_pixbuf_get_pixels(Result), gdk_pixbuf_get_pixels(Msk));
    gdk_pixbuf_unref(Msk);
  end;
end;

function ScalePixmapAndMask(AScaleGC: PGDKGC; AScaleMethod: TGdkInterpType;
  ASrc: PGdkPixmap; ASrcX, ASrcY, ASrcWidth, ASrcHeight: integer;
  ASrcColorMap: PGdkColormap; ASrcMask: PGdkBitmap;
  ADstWidth, ADstHeight: Integer; FlipHorz, FlipVert: Boolean;
  out ADst, ADstMask: PGdkPixmap) : Boolean;

  procedure Warn(const AText: String);
  begin
    DebugLn('[WARNING] ScalePixmapAndMask: ' + AText);
  end;
  
var
  ScaleSrc, ScaleDst: PGdkPixbuf;
begin
  Result := False;
  ADst:=nil;
  ADstMask:=nil;

  // Creating PixBuf from pixmap
  ScaleSrc := CreatePixbufFromImageAndMask(ASrc, ASrcX, ASrcY, ASrcWidth, ASrcHeight,
    ASrcColorMap, ASrcMask);

  // Scaling PixBuf
  ScaleDst := gdk_pixbuf_scale_simple(ScaleSrc, ADstWidth, ADstHeight, AScaleMethod);
  gdk_pixbuf_unref(ScaleSrc);
  if ScaleDst = nil
  then begin
    Warn('ScaleDst=nil');
    exit;
  end;

  // flip if needed
  if FlipHorz then
  begin
    ScaleSrc := ScaleDst;
    ScaleDst := gdk_pixbuf_flip(ScaleSrc, True);
    gdk_pixbuf_unref(ScaleSrc);
    if ScaleDst = nil
    then begin
      Warn('ScaleDst=nil');
      exit;
    end;
  end;

  if FlipVert then
  begin
    ScaleSrc := ScaleDst;
    ScaleDst := gdk_pixbuf_flip(ScaleSrc, False);
    gdk_pixbuf_unref(ScaleSrc);
    if ScaleDst = nil
    then begin
      Warn('ScaleDst=nil');
      exit;
    end;
  end;

//  BeginGDKErrorTrap;

  // Creating pixmap from scaled pixbuf
  gdk_pixbuf_render_pixmap_and_mask(ScaleDst, ADst, ADstMask, $80);

//  EndGDKErrorTrap;
  gdk_pixbuf_unref(ScaleDst);
  Result := True;
end;

{$IFDEF VerboseGtkToDos}{$note remove when gtk native imagelist will be ready}{$ENDIF}
procedure DrawImageListIconOnWidget(ImgList: TScaledImageListResolution;
  Index: integer; AEffect: TGraphicsDrawEffect; Checked: boolean; DestWidget: PGTKWidget;
  CenterHorizontally, CenterVertically: boolean;
  DestLeft, DestTop: integer);
// draw icon of imagelist centered on gdkwindow
var
  Bitmap: TBitmap;
  ImageWidth: Integer;
  ImageHeight: Integer;
  WindowWidth, WindowHeight: integer;
  DestDC: HDC;
  Offset: TPoint;
  FixedWidget: PGtkWidget;
  r:TRect;
begin
  if (Index<0) or (Index>=ImgList.Count) then exit;
  if (DestWidget=nil) then exit;
  ImageWidth:=ImgList.Width;
  ImageHeight:=ImgList.Height;
  Bitmap := TBitmap.Create;
  ImgList.GetBitmap(Index, Bitmap, AEffect);
  if (ImageWidth<1) or (ImageHeight<1) then exit;

  WindowWidth := DestWidget^.allocation.width;
  WindowHeight := DestWidget^.allocation.height;

  Offset := Point(0, 0);

  // if our widget is placed on non-window fixed then we should substract its allocation here
  // since in GetDC we will get this difference in offset
  FixedWidget := GetFixedWidget(DestWidget);
  if (FixedWidget <> nil) and GTK_WIDGET_NO_WINDOW(FixedWidget) then
    Offset := Point(FixedWidget^.allocation.x, FixedWidget^.allocation.y);

  if CenterHorizontally then
    DestLeft := DestWidget^.allocation.x - Offset.x + ((WindowWidth-ImageWidth) div 2);
  if CenterVertically then
    DestTop := DestWidget^.allocation.y - Offset.y +  ((WindowHeight-ImageHeight) div 2);
  DestDC := GetDC(HDC({%H-}PtrUInt(DestWidget)));

  if Checked then
  begin
    r:=Rect(DestLeft-2, DestTop-2, ImageWidth+6, ImageHeight+6);
    DrawEdge(DestDC,r,EDGE_SUNKEN,BF_ADJUST or BF_FLAT or BF_RECT or BF_SOFT);
  end;

  //DebugLn('DrawImageListIconOnWidget B DestXY=',DestLeft,',',DestTop,
  //  ' DestWindowSize=',WindowWidth,',',WindowWidth,
  //  ' SrcRect=',ImageRect.Left,',',ImageRect.Top,',',ImageWidth,'x',ImageHeight);
  StretchBlt(DestDC, DestLeft, DestTop, ImageWidth, ImageHeight,
    Bitmap.Canvas.Handle, 0, 0, ImageWidth, ImageHeight,
    SRCCOPY);
  ReleaseDC(HDC({%H-}PtrUInt(DestWidget)),DestDC);
  Bitmap.Free;
end;

procedure DrawImageListIconOnWidget(ImgList: TScaledImageListResolution;
  Index: integer; DestWidget: PGTKWidget);
begin
  DrawImageListIconOnWidget(ImgList, Index, gdeNormal, false, DestWidget, true, true, 0, 0);
end;

function GetGdkImageBitsPerPixel(Image: PGdkImage): cardinal;
begin
  Result:=Image^.bpp;
  if Result<Image^.Depth then
    Result:=Result*8;
end;

{------------------------------------------------------------------------------
  Function: CreateGtkBitmapMask
  Params:  AImageMask: Then internal gtkBitmap for imagemask
           AMask: External gtkbitmap
  Returns: A GdkBitmap

  This function returns a bitmap based on the internal alpha bitmap and the
  maskhandle passed.
  If both internal mask and the given mask is valid, then a new bitmap is created
  else either internal mask or given mask (with increased reference)
 ------------------------------------------------------------------------------}
function CreateGdkMaskBitmap(AImageMask, AMask: PGdkBitmap): PGdkBitmap;
var
  W, H: Integer;
  GC: PGdkGc;
begin
  Result := nil;
  if (AImageMask = nil) and (AMask = nil) then Exit;

  if AMask = nil
  then begin
    Result := AImageMask;
    gdk_pixmap_ref(Result);
    Exit;
  end;

  if AImageMask = nil
  then begin
    Result := AMask;
    gdk_pixmap_ref(Result);
    Exit;
  end;

  // if we are here we need a combination (=AND) of both masks
  gdk_window_get_size(AImageMask, @W, @H);
  Result := gdk_pixmap_new(nil, W, H, 1);
  GC := gdk_gc_new(Result);
  // copy image mask
  gdk_draw_pixmap(Result, GC, AImageMask, 0, 0, 0, 0, -1, -1);
  // and with mask
  gdk_gc_set_function(GC, GDK_AND);
  gdk_draw_pixmap(Result, GC, AMask, 0, 0, 0, 0, -1, -1);
  gdk_gc_unref(GC);
end;

{------------------------------------------------------------------------------
  Function: CreateGdkMaskBitmap
  Params:  AImage: Handle to the (LCL) bitmap image
           AMask: Handle to the (LCL) bitmap mask
  Returns: A GdkBitmap

  This function returns a bitmap based on the internal alpha bitmap of the
  image handle and the maskhandle passed.
  If only internal mask is valid, then that one is returned (with increased reference)
  Otherwise a new bitmap is created.
 ------------------------------------------------------------------------------}
function CreateGdkMaskBitmap(AImage, AMask: HBITMAP): PGdkBitmap;
var
  GdiImage: PGdiObject absolute AImage;
  GdiMask: PGdiObject absolute AMask;
  W, H: Integer;
  GC: PGdkGc;
begin
  Result := nil;
  if (AImage = 0) and (AMask = 0) then Exit;

  if GdiMask = nil
  then begin
    if GdiImage^.GDIBitmapType = gbPixmap
    then Result := GdiImage^.GDIPixmapObject.Mask;
    if Result <> nil
    then gdk_pixmap_ref(Result);
//    DbgDumpBitmap(Result, 'CreateGdkMaskBitmap - Internal mask');
    Exit;
  end;
  
  if GdiMask^.GDIBitmapType <> gbBitmap
  then begin
    DebugLN('[WARNING] CreateGtkBitmapMask: GDIBitmapType <> dbBitmap');
    Exit;
  end;

  if (GdiImage = nil)
  or (GdiImage^.GDIBitmapType <> gbPixmap)
  or (GdiImage^.GDIPixmapObject.Mask = nil)
  then begin
    gdk_window_get_size(GdiMask^.GDIBitmapObject, @W, @H);
    Result := gdk_pixmap_new(nil, W, H, 1);
    GC := gdk_gc_new(Result);
    gdk_gc_set_function(GC, GDK_COPY_INVERT);
    gdk_draw_pixmap(Result, GC, GdiMask^.GDIBitmapObject, 0, 0, 0, 0, -1, -1);
    gdk_gc_unref(GC);

    //DbgDumpBitmap(Result, 'CreateGdkMaskBitmap - Mask');
    Exit;
  end;
  
  // if we are here we need a combination (=AND) of both masks
  gdk_window_get_size(GdiImage^.GDIPixmapObject.Mask, @W, @H);
  Result := gdk_pixmap_new(nil, W, H, 1);
  GC := gdk_gc_new(Result);
  // copy image mask
  gdk_draw_pixmap(Result, GC, GdiImage^.GDIPixmapObject.Mask, 0, 0, 0, 0, -1, -1);
  // and with mask
  gdk_gc_set_function(GC, GDK_AND_INVERT);
  gdk_draw_pixmap(Result, GC, GdiMask^.GDIBitmapObject, 0, 0, 0, 0, -1, -1);
  gdk_gc_unref(GC);

//  DbgDumpBitmap(Result, 'CreateGdkMaskBitmap - Combi');
end;

function ExtractGdkBitmap(Bitmap: PGdkBitmap; const SrcRect: TRect): PGdkBitmap;
var
  MaxRect: TRect;
  SourceRect: TRect;
  SrcWidth: Integer;
  SrcHeight: Integer;
  GC: PGdkGC;
begin
  Result:=nil;
  if Bitmap=nil then exit;
  MaxRect:=Rect(0,0,0,0);
  gdk_window_get_size(Bitmap,@MaxRect.Right,@MaxRect.Bottom);
  IntersectRect(SourceRect{%H-},SrcRect,MaxRect);
  SrcWidth:=SourceRect.Right-SourceRect.Left;
  SrcHeight:=SourceRect.Bottom-SourceRect.Top;
  DebugLn('ExtractGdkBitmap SourceRect=',dbgs(SourceRect));
  if (SrcWidth<1) or (SrcHeight<1) then exit;
  Result:= gdk_pixmap_new(nil, SrcWidth, SrcHeight, 1);
  GC := GDK_GC_New(Result);
  gdk_window_copy_area(Result,GC,0,0,Bitmap,
                       SourceRect.Left,SourceRect.Top,SrcWidth,SrcHeight);
  GDK_GC_Unref(GC);
end;

procedure CheckGdkImageBitOrder(AImage: PGdkImage; AData: PByte; ADataCount: Integer);
var
  b, count: Byte;
  c: Cardinal;
  
{$ifdef hasx}
  XImage: XLib.PXimage;
{$endif}
begin
{$ifdef hasx}
  if AImage = nil then Exit;

  XImage := gdk_x11_image_get_ximage(AImage);
  if XImage^.bitmap_bit_order = LSBFirst then Exit;
{$endif}

  // on windows or bigendian servers the bits need to be swapped
  
  // align dataptr first
  count := {%H-}PtrUint(AData) and 3;
  if count > ADataCount then count := ADataCount;
  Dec(ADataCount, Count);
  
  while (Count > 0) do
  begin
    // reduce dereferences
    b      := AData^;
    b      := ((b shr 4) and $0F) or ((b shl 4) and $F0);
    b      := ((b shr 2) and $33) or ((b shl 2) and $CC);
    AData^ := ((b shr 1) and $55) or ((b shl 1) and $AA);

    Dec(Count);
    Inc(AData);
  end;
  
  // get remainder
  Count := ADataCount and 3;
  
  // now swap bits with 4 in a row
  ADataCount := ADataCount shr 2;
  while (ADataCount > 0) do
  begin
    // reduce dereferences
    c                 := PCardinal(AData)^;
    c                 := ((c shr 4) and $0F0F0F0F) or ((c shl 4) and $F0F0F0F0);
    c                 := ((c shr 2) and $33333333) or ((c shl 2) and $CCCCCCCC);
    PCardinal(AData)^ := ((c shr 1) and $55555555) or ((c shl 1) and $AAAAAAAA);

    Dec(ADataCount);
    Inc(AData, 4);
  end;

  // process remainder
  while (Count > 0) do
  begin
    // reduce dereferences
    b      := AData^;
    b      := ((b shr 4) and $0F) or ((b shl 4) and $F0);
    b      := ((b shr 2) and $33) or ((b shl 2) and $CC);
    AData^ := ((b shr 1) and $55) or ((b shl 1) and $AA);

    Dec(Count);
    Inc(AData);
  end;

end;


{------------------------------------------------------------------------------
  Function: AllocGDKColor
  Params:  AColor: A RGB color (TColor)
  Returns: an Allocated GDKColor

  Allocated a GDKColor from a winapi color
 ------------------------------------------------------------------------------}
function AllocGDKColor(const AColor: TColorRef): TGDKColor;
begin
  with Result do
  begin
    Red :=   ((AColor shl 8) and $00FF00) or ((AColor       ) and $0000FF);
    Green := ((AColor      ) and $00FF00) or ((AColor shr 8 ) and $0000FF);
    Blue :=  ((AColor shr 8) and $00FF00) or ((AColor shr 16) and $0000FF);
  end;
  {$IFDEF DebugGDK}
  BeginGDKErrorTrap;
  {$ENDIF}
  gdk_colormap_alloc_color(gdk_colormap_get_system, @Result, False, True);
  {$IFDEF DebugGDK}
  EndGDKErrorTrap;
  {$ENDIF}
end;


function RegionType(RGN: PGDKRegion) : Longint;
var
  aRect : TGDKRectangle;
  SimpleRGN: PGdkRegion;
begin
  {$IFDEF DebugGDK}
  BeginGDKErrorTrap;
  {$ENDIF}
  If RGN = nil then
    Result := ERROR
  else if gdk_region_empty(RGN) then
    Result := NULLREGION
  else begin
    gdk_region_get_clipbox(RGN,@aRect);
    SimpleRGN := gdk_region_rectangle(@aRect);
    if gdk_region_equal(SimpleRGN, RGN) then
      Result := SIMPLEREGION
    else
      Result := COMPLEXREGION;
    gdk_region_destroy(SimpleRGN);
  end;
  {$IFDEF DebugGDK}
  EndGDKErrorTrap;
  {$ENDIF}
end;


function GDKRegionAsString(RGN: PGDKRegion): string;
var
  aRect: TGDKRectangle;
begin
  Result:=DbgS(RGN);
  BeginGDKErrorTrap;
  gdk_region_get_clipbox(RGN,@aRect);
  EndGDKErrorTrap;
  Result:=Result+'(x='+IntToStr(Integer(aRect.x))+',y='+IntToStr(Integer(aRect.y))+',w='
                    +IntToStr(aRect.Width)+',h='+IntToStr(aRect.Height)+' '
                    +'Type='+IntToStr(RegionType(RGN))+')';
end;

function CreateRectGDKRegion(const ARect: TRect): PGDKRegion;
var
  GDkRect: TGDKRectangle;
begin
  GDkRect.x:=ARect.Left;
  GDkRect.y:=ARect.Top;
  GDkRect.Width:=ARect.Right-ARect.Left;
  GDkRect.Height:=ARect.Bottom-ARect.Top;
  {$IFDEF DebugGDK}
  BeginGDKErrorTrap;
  {$ENDIF}
  Result:=gdk_region_rectangle(@GDKRect);
  {$IFDEF DebugGDK}
  EndGDKErrorTrap;
  {$ENDIF}
end;

Procedure FreeGDIColor(GDIColor: PGDIColor);
begin
  if (cfColorAllocated in GDIColor^.ColorFlags) then begin
    if (GDIColor^.Colormap <> nil) then begin
      BeginGDKErrorTrap;
      gdk_colormap_free_colors(GDIColor^.Colormap,@(GDIColor^.Color), 1);
      EndGDKErrorTrap;
    end;
    //GDIColor.Color.Pixel := -1;
    Exclude(GDIColor^.ColorFlags,cfColorAllocated);
  end;
end;

procedure SetGDIColorRef(var GDIColor: TGDIColor; NewColorRef: TColorRef);
begin
  if GDIColor.ColorRef = NewColorRef then Exit;
  FreeGDIColor(@GDIColor);
  GDIColor.ColorRef := NewColorRef;
end;

procedure AllocGDIColor(DC: hDC; GDIColor: PGDIColor);
var
  RGBColor : DWord;
begin
  if not (cfColorAllocated in GDIColor^.ColorFlags) then
  begin
    RGBColor := ColorToRGB(TColor(GDIColor^.ColorRef));

    with GDIColor^.Color do
    begin
      Red := gushort(GetRValue(RGBColor)) shl 8;
      Green := gushort(GetGValue(RGBColor)) shl 8;
      Blue := gushort(GetBValue(RGBColor)) shl 8;
      Pixel := 0;
    end;

    {with TGtkDeviceContext(DC) do
      If CurrentPalette <> nil then
        GDIColor.Colormap := CurrentPalette^.PaletteColormap
      else}
        GDIColor^.Colormap := GDK_Colormap_get_system;

    gdk_colormap_alloc_color(GDIColor^.Colormap, @(GDIColor^.Color),True,True);

    Include(GDIColor^.ColorFlags,cfColorAllocated);
  end;
end;

procedure BuildColorRefFromGDKColor(var GDIColor: TGDIColor);
begin
  GDIColor.ColorRef:=TGDKColorToTColor(GDIColor.Color);
  Include(GDIColor.ColorFlags,cfColorAllocated);
end;

procedure EnsureGCColor(DC: hDC; ColorType: TDevContextsColorType;
  IsSolidBrush, AsBackground: Boolean);
var
  GC: PGDKGC;
  GDIColor: PGDIColor;

  procedure WarnAllocFailed(const foreground : TGdkColor);
  begin
    DebugLn('NOTE: EnsureGCColor.EnsureAsGCValues gdk_colormap_alloc_color failed ',
      ' Foreground=',
      DbgS(Foreground.red),',',
      DbgS(Foreground.green),',',
      DbgS(Foreground.blue),
      ' GDIColor^.ColorRef=',DbgS(GDIColor^.ColorRef)
      );
  end;

  procedure EnsureAsGCValues;
  var
    AllocFG : Boolean;
    SysGCValues: TGdkGCValues;
  begin
    FreeGDIColor(GDIColor);
    SysGCValues:=GetSysGCValues(GDIColor^.ColorRef,
                                TGtkDeviceContext(DC).Widget);
    {$IFDEF DebugGDK}BeginGDKErrorTrap;{$ENDIF}
    with SysGCValues do
    begin
      AllocFG := Foreground.Pixel = 0;
      if AllocFG then
        if not gdk_colormap_alloc_color(GDK_Colormap_get_system, @Foreground,
                                        True, True) then
          WarnAllocFailed(Foreground);
      gdk_gc_set_fill(GC, fill);
      if AsBackground then
        gdk_gc_set_background(GC, @foreground)
      else
        gdk_gc_set_foreground(GC, @foreground);
      case Fill of
        GDK_TILED :
          if Tile <> nil then
          begin
            gdk_gc_set_ts_origin(GC, ts_x_origin, ts_y_origin);
            gdk_gc_set_tile(GC, Tile);
          end;
        GDK_STIPPLED,
        GDK_OPAQUE_STIPPLED:
          if stipple <> nil then
          begin
            gdk_gc_set_background(GC, @background);
            gdk_gc_set_ts_origin(GC, ts_x_origin, ts_y_origin);
            gdk_gc_set_stipple(GC, stipple);
          end;
      end;
      if AllocFG then
        gdk_colormap_free_colors(GDK_Colormap_get_system, @Foreground,1);
    end;
    {$IFDEF DebugGDK}EndGDKErrorTrap;{$ENDIF}
  end;

  procedure EnsureAsColor;
  begin
    AllocGDIColor(DC, GDIColor);
    //DebugLn('EnsureAsColor ',DbgS(GDIColor^.ColorRef),' AsBackground=',AsBackground);
    {$IFDEF DebugGDK}BeginGDKErrorTrap;{$ENDIF}
    if AsBackground then
      gdk_gc_set_background(GC, @(GDIColor^.Color))
    else
    begin
      gdk_gc_set_fill(GC, GDK_SOLID);
      gdk_gc_set_foreground(GC, @(GDIColor^.Color));
    end;
    {$IFDEF DebugGDK}EndGDKErrorTrap;{$ENDIF}
  end;

begin
  GC:=TGtkDeviceContext(DC).GC;
  GDIColor:=nil;
  with TGtkDeviceContext(DC) do
  begin
    case ColorType of
      dccCurrentBackColor: GDIColor:=@CurrentBackColor;
      dccCurrentTextColor: GDIColor:=@CurrentTextColor;
      dccGDIBrushColor   : GDIColor:=@(GetBrush^.GDIBrushColor);
      dccGDIPenColor     : GDIColor:=@(GetPen^.GDIPenColor);
    end;
  end;
  if GDIColor=nil then exit;
  
  // FPC bug workaround:
  // clScrollbar = $80000000 can't be used in case statements
  if TColor(GDIColor^.ColorRef)=clScrollbar then
  begin
    //often have a BK Pixmap
    if IsSolidBrush then
      EnsureAsGCValues
    else
      EnsureAsColor;//GC's with Pixmaps can't work w/Hatch's (yet)
    exit;
  end;

  case TColor(GDIColor^.ColorRef) of
    //clScrollbar: see above
    clInfoBk,
    clMenu,
    clHighlight,
    clBtnFace,
    clWindow,
    clForm:
      //often have a BK Pixmap
      if IsSolidBrush then
        EnsureAsGCValues
      else
        EnsureAsColor;//GC's with Pixmaps can't work w/Hatch's (yet)

    clHighlightText,
    clBtnShadow,
    clBtnHighlight,
    clBtnText,
    clInfoText,
    clWindowText,
    clMenuText,
    clGrayText:
      //should never have a BK Pixmap
      EnsureAsGCValues;
    else
      EnsureAsColor;
  end;
end;

procedure CopyGDIColor(var SourceGDIColor, DestGDIColor: TGDIColor);
begin
  SetGDIColorRef(DestGDIColor,SourceGDIColor.ColorRef);
end;

function IsBackgroundColor(Color: TColor): boolean;
begin
  Result := (Color = clForm) or
            (Color = clInfoBk) or
            (Color = clBackground);
end;

function CompareGDIColor(const Color1, Color2: TGDIColor): boolean;
begin
  Result:=Color1.ColorRef=Color2.ColorRef;
end;

function CompareGDIFill(const Fill1, Fill2: TGdkFill): boolean;
begin
  Result:=Fill1=Fill2;
end;

function CompareGDIBrushes(Brush1, Brush2: PGdiObject): boolean;
begin
  Result:=Brush1^.IsNullBrush=Brush2^.IsNullBrush;
  if Result then begin
    Result:=CompareGDIColor(Brush1^.GDIBrushColor,Brush2^.GDIBrushColor);
    if Result then begin
      Result:=CompareGDIFill(Brush1^.GDIBrushFill,Brush2^.GDIBrushFill);
      if Result then begin
        Result:=Brush1^.GDIBrushPixMap=Brush2^.GDIBrushPixMap;
      end;
    end;
  end;
end;

//-----------------------------------------------------------------------------

{ Palette Index<->RGB Hash Functions }

type
  TIndexRGB = record
    Index: longint;
    RGB: longint;
  end;
  PIndexRGB = ^TIndexRGB;

function GetIndexAsKey(p: pointer): pointer;
begin
  Result:={%H-}Pointer(PIndexRGB(p)^.Index + 1);
end;

function GetRGBAsKey(p: pointer): pointer;
begin
  Result:={%H-}Pointer(PIndexRGB(p)^.RGB + 1);
end;

function PaletteIndexToIndexRGB(Pal : PGDIObject; I : longint): PIndexRGB;
var
  HashItem: PDynHashArrayItem;
begin
  Result := nil;
  HashItem:=Pal^.IndexTable.FindHashItemWithKey({%H-}Pointer(I + 1));
  if HashItem<>nil then
    Result:=PIndexRGB(HashItem^.Item);
end;

function PaletteRGBToIndexRGB(Pal : PGDIObject; RGB : longint): PIndexRGB;
var
  HashItem: PDynHashArrayItem;
begin
  Result := nil;
  HashItem:=Pal^.RGBTable.FindHashItemWithKey({%H-}Pointer(RGB + 1));
  if HashItem<>nil then
    Result:=PIndexRGB(HashItem^.Item);
end;

{ Palette Index<->RGB lookup Functions }

function PaletteIndexExists(Pal : PGDIObject; I : longint): Boolean;
begin
  Result := Pal^.IndexTable.ContainsKey({%H-}Pointer(I + 1));
end;

function PaletteRGBExists(Pal : PGDIObject; RGB : longint): Boolean;
begin
  Result := Pal^.RGBTable.ContainsKey({%H-}Pointer(RGB + 1));
end;

function PaletteAddIndex(Pal : PGDIObject; I, RGB : Longint): Boolean;
var
  IndexRGB: PIndexRGB;
begin
  New(IndexRGB);
  IndexRGB^.Index:=I;
  IndexRGB^.RGB:=RGB;
  Pal^.IndexTable.Add(IndexRGB);
  Result := PaletteIndexExists(Pal, I);
  If Not Result then
    Dispose(IndexRGB)
  else begin
    Pal^.RGBTable.Add(IndexRGB);
    Result := PaletteRGBExists(Pal, RGB);
    If not Result then begin
      Pal^.IndexTable.Remove(IndexRGB);
      Dispose(IndexRGB);
    end;
  end;
end;

function PaletteDeleteIndex(Pal : PGDIObject; I : Longint): Boolean;
var
  RGBIndex : PIndexRGB;
begin
  RGBIndex := PaletteIndextoIndexRGB(Pal,I);
  Result := RGBIndex = nil;
  If not Result then begin
    Pal^.IndexTable.Remove(RGBIndex);
    If PaletteRGBExists(Pal, RGBIndex^.RGB) then
      Pal^.RGBTable.Remove(RGBIndex);
    Dispose(RGBIndex);
  end;
end;

function PaletteIndexToRGB(Pal : PGDIObject; I : longint): longint;
var
  RGBIndex : PIndexRGB;
begin
  RGBIndex := PaletteIndextoIndexRGB(Pal,I);
  if RGBIndex = nil then
    Result := -1//InvalidRGB
  else
    Result := RGBIndex^.RGB;
end;

function PaletteRGBToIndex(Pal : PGDIObject; RGB : longint): longint;
var
  RGBIndex : PIndexRGB;
begin
  RGBIndex := PaletteRGBtoIndexRGB(Pal,RGB);
  if RGBIndex = nil then
    Result:=-1//InvalidIndex
  else
    Result := RGBIndex^.Index;
end;

procedure InitializePalette(const Pal: PGDIObject; const Entries: PPaletteEntry; const RGBCount: Longint);
var
  I: Integer;
  RGBValue: Longint;
begin
  for I := 0 to RGBCount - 1 do
  begin
    if PaletteIndexExists(Pal, I) then
      PaletteDeleteIndex(Pal, I);
    with Entries[I] do
      RGBValue := RGB(peRed, peGreen, peBlue) {or (peFlags shl 32)??};
    if not PaletteRGBExists(Pal, RGBValue) then
      PaletteAddIndex(Pal, I, RGBValue);
  end;
end;

function HandleGTKKeyUpDown(AWidget: PGtkWidget; AEvent: PGdkEventKey;
  AData: gPointer; ABeforeEvent, AHandleDown: Boolean;
  const AEventName: PGChar) : GBoolean;
// returns CallBackDefaultReturn if event can continue in gtk's message system
{off $DEFINE VerboseKeyboard}
const
  KEYUP_MAP: array[Boolean {syskey}, Boolean {before}] of Cardinal = (
    (LM_KEYUP, CN_KEYUP),
    (LM_SYSKEYUP, CN_SYSKEYUP)
  );

  KEYDOWN_MAP: array[Boolean {syskey}, Boolean {before}] of Cardinal = (
    (LM_KEYDOWN, CN_KEYDOWN),
    (LM_SYSKEYDOWN, CN_SYSKEYDOWN)
  );
  
  CHAR_MAP: array[Boolean {syskey}, Boolean {before}] of Cardinal = (
    (LM_CHAR, CN_CHAR),
    (LM_SYSCHAR, CN_SYSCHAR)
  );
var
  Msg: TLMKey;
  EventStopped: Boolean;
  EventString: PChar; // GTK1 and GTK2 workaround
                      // (and easy access to bytes)
  KeyCode: Word;
  KCInfo: TKeyCodeInfo;
  VKey: Byte;
  ShiftState: TShiftState;

  Character, OldCharacter: TUTF8Char;
  WS: WideString;
  SysKey: Boolean;

  CommonKeyData: Integer;
  Flags: Integer;
  FocusedWidget: PGtkWidget;
  LCLObject: TObject;
  FocusedWinControl: TWinControl;
  EventHandledByLCL: TLCLHandledKeyEvent;
  TargetWidget: PGtkWidget;
  TargetObj: gPointer;
  KeyPressesChar: char;
  PassUTF8AsKeyPress: Boolean;

  procedure ClearKey;
  begin
    //MWE: still need to skip on win32 ?
    {MWE:.$IfNDef Win32}
    if EventString <> nil
    then begin
      gdk_event_key_set_string(AEvent, #0);
      AEvent^.length := 0;
    end;
    {MWE:.$EndIf}
    AEvent^.KeyVal := 0;
    if EventHandledByLCL <> nil then
      EventHandledByLCL.keyval := 0;
  end;

  procedure StopKeyEvent;
  begin
    {$IFDEF VerboseKeyboard}
    DebugLn('StopKeyEvent AEventName="',AEventName,'" ABeforeEvent=',dbgs(ABeforeEvent));
    {$ENDIF}
    if not EventStopped
    then begin
      g_signal_stop_emission_by_name(PGtkObject(AWidget), AEventName);
      EventStopped := True;
    end;
    ClearKey;
    ResetDefaultIMContext;
  end;

  function DeliverKeyMessage(const Target: Pointer; var AMessage): boolean;
  begin
    Result:=DeliverMessage(Target,AMessage)=0;
    if not Result then StopKeyEvent;
  end;

  function GetSpecialChar: Char;
  begin
    if (AEvent^.keyval > $FF00) and (AEvent^.keyval < $FF20) and
       (AEvent^.keyval <> GDK_KEY_TAB) then
      Result := Chr(AEvent^.keyval xor $FF00)
    else
      if (AEvent^.keyval > $60) and (AEvent^.keyval < $7B) then
        Result := Chr(AEvent^.keyval - $60) //^A .. ^Z
    else
      Result := #0;
  end;

  function CanSendChar: Boolean;
  begin
    Result := False;
    if AEvent^.Length > 1 then Exit;

    // to be delphi compatible we should not send a space here
    if AEvent^.KeyVal = GDK_KEY_KP_SPACE then Exit;

    // Check if CTRL is pressed
    if ssCtrl in ShiftState
    then begin
      // Check if we pressed ^@
      if  (AEvent^.Length = 0)
      and (AEvent^.KeyVal = GDK_KEY_AT)
      then begin
        Result := True;
        Exit;
      end;
      // check if we send the ^Char subset
      if (AEvent^.Length = 1) and (EventString <> nil)
      then begin
        Result := (EventString^ > #0) and (EventString^ < ' ');
      end;
      Exit;
    end;
{$IFDEF WITH_GTK2_IM}
    Result := ((not im_context_use) and (AEvent^.Length > 0)) or (GetSpecialChar <> #0);
{$ELSE}
    Result := (AEvent^.Length > 0) or (GetSpecialChar <> #0);
{$ENDIF}
  end;
  
  function KeyAlreadyHandledByGtk: boolean;
  begin
    Result := false;
    if AWidget = nil then exit;
    
    if GtkWidgetIsA(AWidget, gtk_entry_get_type)
    then begin
      // the gtk_entry handles the following keys
      case Aevent^.keyval of
        GDK_Key_Return,
        GDK_Key_Escape,
        GDK_Key_Tab: Exit;
      end;
      
      Result := AEvent^.length > 0;
      if Result then Exit;
      
      case AEvent^.keyval of
        GDK_Key_BackSpace,
        GDK_Key_Clear,
        GDK_Key_Insert,
        GDK_Key_Delete,
        GDK_Key_Home,
        GDK_Key_End,
        GDK_Key_Left,
        GDK_Key_Right,
        $20..$FF: Result := True;
      end;
      exit;
    end;
    
    if GtkWidgetIsA(AWidget, gtk_text_get_type)
    then begin
      // the gtk_text handles the following keys
      case AEvent^.keyval of
        GDK_Key_Escape: Exit;
      end;

      Result := AEvent^.length > 0;
      if Result then Exit;
      
      case AEvent^.keyval of
        GDK_Key_Return,
        GDK_Key_Tab,
        GDK_Key_BackSpace,
        GDK_Key_Clear,
        GDK_Key_Insert,
        GDK_Key_Delete,
        GDK_Key_Home,
        GDK_Key_End,
        GDK_Key_Left,
        GDK_Key_Right,
        GDK_Key_Up,
        GDK_Key_Down,
        $20..$FF: Result := True;
      end;
      exit;
    end;
  end;

  procedure CharToKeyVal(C: Char; out KeyVal: guint; out Length: gint);
  begin
    Length := 1;

    if C in [#$01..#$1B] then
    begin
      KeyVal := $FF00 or Ord(C);
      if KeyVal = GDK_KEY_BackSpace then
        Length := 0;
    end
    else
      KeyVal := Ord(C);
  end;
  
  function KeyActivatedAccelerator: boolean;
  
    function CheckMenuChilds(AMenuItem: TMenuItem): boolean;
    var
      i: Integer;
      Item: TMenuItem;
    begin
      Result:=false;
      if (AMenuItem=nil) or (not AMenuItem.HandleAllocated) then exit;
      for i:=0 to AMenuItem.Count-1 do begin
        Item:=AMenuItem[i];
        if not Item.HandleAllocated then continue;
        if not GTK_WIDGET_SENSITIVE({%H-}PGTKWidget(Item.Handle)) then continue;
        if IsAccel(Msg.CharCode,Item.Caption) then Result:=true;
      end;
    end;
  
  var
    AComponent: TComponent;
    AControl: TControl;
    AForm: TCustomForm;
  begin
    Result:=false;
    //debugln('KeyActivatedAccelerator A');
    if not SysKey then exit;
    // it is a system key -> try menus
    if (Msg.CharCode in [VK_A..VK_Z]) then begin
      if (TObject(TargetObj) is TComponent) then begin
        AComponent:=TComponent(TargetObj);
        //DebugLn(['KeyActivatedAccelerator ',dbgsName(AComponent)]);
        if AComponent is TControl then begin
          AControl:=TControl(AComponent);
          repeat
            AForm:=GetFirstParentForm(AControl);
            if AForm<>nil then begin
              if AForm.Menu<>nil then begin
                Result:=CheckMenuChilds(AForm.Menu.Items);
                if Result then exit;
              end;
            end;
            AControl:=AForm.Parent;
          until AControl=nil;
          
          // check main menu of MainForm
          if (Application.MainForm<>nil) then begin
            AControl:=TControl(AComponent);
            AForm:=GetParentForm(AControl);
            if (AForm<>nil)
            and (not (fsModal in AForm.FormState))
            and (not Application.MainForm.IsParentOf(AControl))
            and (Application.MainForm.Menu<>nil) then begin
              Result:=CheckMenuChilds(Application.MainForm.Menu.Items);
              if Result then exit;
            end;
          end;
        end;
      end;
    end;
  end;

  procedure EmulateEatenKeys;
  begin
    // some widgets eats keys, but do not do anything useful for the LCL
    // emulate the keys
    if not ABeforeEvent then Exit;
    if EventStopped then Exit;

    //DebugLn(['EmulateEatenKeys TargetWidget=',dbghex(PtrInt(TargetWidget))]);
    //DebugLn(['EmulateEatenKeys ',GetWidgetDebugReport(TargetWidget),' gdk_event_get_type(AEvent)=',gdk_event_get_type(AEvent),' GDK_KEY_PRESS=',GDK_KEY_PRESS,' VKey=',VKey]);

    // the gtk2 gtkentry handles the return key and emits an activate signal
    // The LCL does not use that and needs the return key event
    // => emulate it

    // spin button needs VK_RETURN to send OnEditingDone. issue #21224
    // Fix for spin button not triggering TApplication.ControlKeyUp() when
    //   VK_RETURN or VK_ESCAPE is pressed
    if GtkWidgetIsA(TargetWidget, gtk_type_spin_button) and
      (gdk_event_get_type(AEvent) = GDK_KEY_RELEASE) and
      ((VKey = VK_RETURN) or (VKey = VK_ESCAPE)) then
    begin
      // emulate keyup and keydown
      FillChar(Msg, SizeOf(Msg), 0);
      Msg.CharCode := VKey;
      if SysKey then
        Msg.msg := LM_SYSKEYDOWN
      else
        Msg.msg := LM_KEYDOWN;
      Msg.KeyData := CommonKeyData or (Flags shl 16) or $0001;
      // send the (Sys)KeyDown message directly to the LCL
      NotifyApplicationUserInput(TControl(TargetObj), Msg.Msg);
      DeliverKeyMessage(TargetObj, Msg);

      if SysKey then
        Msg.msg := LM_SYSKEYUP
      else
        Msg.msg := LM_KEYUP;
      // send the (Sys)KeyUp message directly to the LCL
      NotifyApplicationUserInput(TControl(TargetObj), Msg.Msg);
      DeliverKeyMessage(TargetObj, Msg);
    end else

    // emulate VK_RETURN on GtkButton. issue #21483
    if GtkWidgetIsA(TargetWidget, gtk_type_button) then
    begin
      if (gdk_event_get_type(AEvent) = GDK_KEY_RELEASE) and
        (VKey = VK_RETURN) then
      begin
        FillChar(Msg, SizeOf(Msg), 0);
        Msg.CharCode := VKey;
        if SysKey then
          Msg.msg := LM_SYSKEYUP
        else
          Msg.msg := LM_KEYUP;
        Msg.KeyData := CommonKeyData or (Flags shl 16) or $0001 {TODO:  repeatcount};
        // do not send next LM_CLICKED. issue #21483
        g_object_set_data(PGObject(TargetWidget),'lcl-button-stop-clicked', TargetWidget);
        NotifyApplicationUserInput(TControl(TargetObj), Msg.Msg);
        DeliverKeyMessage(TargetObj, Msg);
      end;

    end else

    if (
        GtkWidgetIsA(TargetWidget, gtk_type_entry) or
        GtkWidgetIsA(TargetWidget, gtk_type_text_view) or
        GtkWidgetIsA(TargetWidget, gtk_type_tree_view)
       )
       and
      (gdk_event_get_type(AEvent) = GDK_KEY_PRESS) and
      ((VKey = VK_RETURN) or (VKey = VK_TAB)) then
    begin
      // DebugLn(['EmulateKeysEatenByGtk ']);
      FillChar(Msg, SizeOf(Msg), 0);
      Msg.CharCode := VKey;
      if SysKey then
        Msg.msg := LM_SYSKEYDOWN
      else
        Msg.msg := LM_KEYDOWN;
      Msg.KeyData := CommonKeyData or (Flags shl 16) or $0001 {TODO:  repeatcount};

      // send the (Sys)KeyDown message directly to the LCL
      NotifyApplicationUserInput(TControl(TargetObj), Msg.Msg);
      DeliverKeyMessage(TargetObj, Msg);
    end;
  end;

  function BlackListIMModule: boolean;
  const
    cBlackList = 'scim-bridge';
    //to fix issue with duplicated chars:
    //cBlackList = 'scim-bridge,scim,xim';
  var
    sVar: string;
  begin
    {$IFDEF UNIX}
    sVar := g_getenv('GTK_IM_MODULE');
    Result := Pos(','+sVar+',', ','+cBlackList+',')>0;
    {$ELSE}
    Result := False;
    {$ENDIF}
  end;

  procedure CheckDeadKey;
  begin
    if ABeforeEvent then
    begin
      if im_context_widget<>TargetWidget then
      begin
        //DebugLn(['CheckDeadKey init im_context ',GetWidgetDebugReport(TargetWidget)]);
        ResetDefaultIMContext;
        im_context_widget:=TargetWidget;
        gtk_im_context_set_client_window(im_context,GetControlWindow(TargetWidget));
        //DebugLn(['CheckDeadKey im_context initialized']);
      end;
      // Note: gtk_im_context_filter_keypress understands keypress and keyrelease

      {do not pass double chars if we use scim-bridge or other blacklisted im_module.
       issues #15185, #23140}
      if not BlackListIMModule then
        gtk_im_context_filter_keypress (im_context, AEvent);

      //DebugLn(['CheckDeadKey DeadKey=',DeadKey,' str="',im_context_string,'"']);
    end;
  end;
  
begin
  Result := CallBackDefaultReturn;

  EventStopped := False;
  EventHandledByLCL := KeyEventWasHandledByLCL(AEvent, ABeforeEvent);

  {$IFDEF VerboseKeyboard}
  DebugLn(['[HandleGTKKeyUpDown] START ',DbgSName(TControl(AData)),
    ' _Type=',(AEvent^._Type),
    ' state=',(AEvent^.state),
    ' keyval=',(AEvent^.keyval),'=$',hexstr(AEvent^.keyval,4),
    ' hardware_keycode=',(AEvent^.hardware_keycode),
    ' length=',(AEvent^.length),
    ' _string="',dbgMemRange(PByte(AEvent^._string),AEvent^.length),'"',
    ' group=',(AEvent^.group),
    ' Widget=',GetWidgetClassName(AWidget),
    ' Before=',ABeforeEvent,' Down=',AHandleDown,' HandledByLCL=',HandledByLCL<>nil]);
  {$ENDIF}

  // handle every key event only once
  {$IFnDEF WITHOUT_GTK_DOUBLEKEYPRESS_CHECK}
  if EventHandledByLCL<>nil then exit;
  {$ENDIF}

  while (not GtkWidgetIsA(AWidget, gtk_window_get_type)) and (AWidget^.parent <> nil) do
    AWidget := AWidget^.parent;

  TargetWidget := AWidget;
  TargetObj := AData;
  FocusedWinControl := nil;
  FocusedWidget := nil;
  LCLObject := nil;

  // The gtk sends keys first to the gtkwindow and then to the focused control.
  // The LCL expects only once to the focused control.
  // And some gtk widgets (combo) eats keys, so that the LCL has no chance to
  // handle it. Therefore keys to the form are immediately redirected to the
  // focused control without changing the normal gtk event path.
  if GtkWidgetIsA(AWidget, gtk_window_get_type)
  then begin
    FocusedWidget := PGtkWindow(AWidget)^.focus_widget;
    if FocusedWidget <> nil
    then begin
      LCLObject := GetNearestLCLObject(FocusedWidget);
      if LCLObject is TWinControl
      then begin
        FocusedWinControl := TWinControl(LCLObject);
        if FocusedWidget <> AWidget
        then begin
          {$IFDEF VerboseKeyboard}
          DebugLn('[HandleGTKKeyUpDown] REDIRECTING ',
            ' FocusedWidget=',GetWidgetClassName(FocusedWidget),
            ' Control=',FocusedWinControl.Name,':',FocusedWinControl.ClassName);
          {$ENDIF}
          // redirect key to lcl control
          TargetWidget := FocusedWidget;
          TargetObj := FocusedWinControl;
        end;
      end;
    end;
  end;

  // remember this event
  EventHandledByLCL := RememberKeyEventWasHandledByLCL(AEvent, ABeforeEvent);
  EventHandledByLCL.AddRef;
  try
    if TargetWidget = nil then Exit;

    //DebugLn(['HandleGTKKeyUpDown TargetWidget=',GetWidgetDebugReport(TargetWidget)]);

    //DebugLn(['HandleGTKKeyUpDown TargetWidget=',GetWidgetDebugReport(TargetWidget),' ',DbgStr(EventString),' state=',AEvent^.state,' keyval=',AEvent^.keyval]);
    FillChar(Msg, SizeOf(Msg), 0);

    gdk_event_key_get_string(AEvent, EventString{%H-});
    {$IFDEF VerboseKeyboard}
    DebugLn(['HandleGTKKeyUpDown EVENTSTRING "',DbgStr(EventString),'" TargetWidget=',GetWidgetDebugReport(TargetWidget),' state=',AEvent^.state,' keyval=',AEvent^.keyval]);
    {$ENDIF}

    {$IfDef Gtk2LatinAccents}
    gtk_im_context_filter_keypress (im_context, AEvent);
    {$Else}
    CheckDeadKey;
    {$EndIf}

    Flags := 0;
    SysKey := False;
    ShiftState := GTKEventStateToShiftState(AEvent^.state);
    KeyCode := AEvent^.hardware_keycode;

    if (KeyCode = 0)
    or (KeyCode > High(MKeyCodeInfo))
    or (MKeyCodeInfo[KeyCode].VKey1 = 0)
    then begin
      // no VKey defined, maybe composed char ?
      CommonKeyData := 0;
    end
    else begin
      KCInfo := MKeyCodeInfo[KeyCode];

      {$IFDEF VerboseKeyboard}
      debugln(['HandleGTKKeyUpDown AEvent^.hardware_keycode=',AEvent^.hardware_keycode,',keyval=',AEvent^.keyval,',group=',AEvent^.group,' KeyCode=',KeyCode,' ',dbgs(ShiftState),' KCInfo.VKey1=',KCInfo.VKey1,',VKey2=',KCInfo.VKey2]);
      {$ENDIF}
      if (KCInfo.Flags and KCINFO_FLAG_SHIFT_XOR_NUM <> 0)
      and ((ssShift in ShiftState) xor (ssNum in ShiftState))
      then VKey := KCInfo.VKey2
      else VKey := KCInfo.VKey1;

      if (KCInfo.Flags and KCINFO_FLAG_EXT) <> 0
      then Flags := KF_EXTENDED;


      // ssAlt + a key pressed is always a syskey
      // ssAltGr + a key is only a syskey when the key pressed has no levelshift or when ssShift is pressed too
      if ssAltGr in ShiftState then
        SysKey := ssAlt in ShiftState
      else
        SysKey := [ssAlt,ssCtrl]*ShiftState=[ssAlt]; // Alt+Ctrl = AltGr, on Windows and on Linux via VNC, see bug 30544
      if not SysKey then
      begin
        // Check ssAltGr
        if (KCInfo.Flags and KCINFO_FLAG_ALTGR) = 0 then
          // VKey has no levelshift char so AltGr is syskey
          SysKey := ssAltGr in ShiftState
        else
        begin
          // VKey has levelshift char so AltGr + Shift is syskey.
          SysKey := (ShiftState * [ssShift, ssAltGr] = [ssShift, ssAltGr]);

          // This is not true for TCustomControl, issues 22703,25874.
          if LCLObject is TCustomControl then
            SysKey := False;
        end;
      end;

      if SysKey or (ssAlt in ShiftState) then
        Flags := Flags or KF_ALTDOWN;

      CommonKeyData := KeyCode shl 16; // Not really scancode, but will do

      if AHandleDown then
      begin
        {$IFDEF VerboseKeyboard}
        DebugLn(['[HandleGTKKeyUpDown] GDK_KEY_PRESS VKey=',dbgs(VKey),' SysKey=',dbgs(SysKey),' ShiftState=',dbgs(ShiftState),' KCInfo=Key1=',KCInfo.VKey1,',Key2=',KCInfo.VKey2,',Flags=',hexstr(KCInfo.Flags,2)]);
        {$ENDIF}

        Msg.CharCode := VKey;
        Msg.Msg := KEYDOWN_MAP[SysKey, ABeforeEvent];

        // todo  repeat
        // Flags := Flags or KF_REPEAT;

        Msg.KeyData := CommonKeyData or (Flags shl 16) or $0001 {TODO:  repeatcount};

        if not KeyAlreadyHandledByGtk
        then begin
          // send the (Sys)KeyDown message directly to the LCL
          NotifyApplicationUserInput(TControl(TargetObj), Msg.Msg);
          if DeliverKeyMessage(TargetObj, Msg)
          and (Msg.CharCode <> Vkey) then
            StopKeyEvent;
        end;

        if (not EventStopped) and ABeforeEvent
        then begin
          if KeyActivatedAccelerator then exit;
        end;
      end
      else begin
        {$IFDEF VerboseKeyboard}
        DebugLn('[HandleGTKKeyUpDown] GDK_KEY_RELEASE VKey=',dbgs(VKey));
        {$ENDIF}

        Msg.CharCode := VKey;
        Msg.Msg := KEYUP_MAP[SysKey, ABeforeEvent];
        Flags := Flags or KF_UP or KF_REPEAT;
        Msg.KeyData := CommonKeyData or (Flags shl 16) or $0001 {always};

        // send the message directly to the LCL
        Msg.Result:=0;
        NotifyApplicationUserInput(TControl(TargetObj), Msg.Msg);

        if DeliverKeyMessage(TargetObj, Msg)
        and (Msg.CharCode <> VKey)
        then begin
          // key was handled by LCL
          StopKeyEvent;
        end;
      end;
    end;

    // send keypresses
    // im_context_string checking be used for process when non-composition state
    // without checking, non-composite keys(number backspace enter, and etc) doesn't input.
    // (check with press number keys or backspace without candidate window in cjk input state)
{$IFDEF WITH_GTK2_IM}
    if not EventStopped and (AHandleDown or (im_context_string<>'')) then
{$ELSE}
    if not EventStopped and AHandleDown then
{$ENDIF}
    begin
      // send the UTF8 keypress
      PassUTF8AsKeyPress := False;
      if ABeforeEvent then
      begin
        // try to get the UTF8 representation of the key
        if im_context_string <> '' then
        begin
          Character := UTF8Copy(im_context_string,1,1);
          im_context_string:='';// clear, to avoid sending again
        end
        else
        begin
          KeyPressesChar := GetSpecialChar;
          if KeyPressesChar <> #0 then
            Character := KeyPressesChar
          else
            Character := '';
        end;

        {$IFDEF VerboseKeyboard}
        debugln('[HandleGTKKeyUpDown] GDK_KEY_PRESS UTF8="',DbgStr(Character),'"',
        ' EventStopped ',dbgs(EventStopped),' CanSendChar ',dbgs(CanSendChar));
        {$ENDIF}

        // we must pass KeyPress if UTF8KeyPress returned false result. issue #21489
        if Character <> '' then
        begin
          LCLObject := GetNearestLCLObject(TargetWidget);
          if LCLObject is TWinControl then
          begin
            OldCharacter := Character;
            // send the key after navigation keys were handled
            Result := TWinControl(LCLObject).IntfUTF8KeyPress(Character, 1, SysKey);
            if Result or (Character = '') then
              // dont' stop key event here, just clear it since we need a keyUp event
              ClearKey
            else
            if (Character <> OldCharacter) then
            begin
              WS := UTF8ToUTF16(Character);
              if Length(WS) > 0 then
              begin
                AEvent^.keyval := gdk_unicode_to_keyval(Word(WS[1]));
                if (AEvent^.keyval and $1000000) = $1000000 then
                begin
                  CharToKeyVal(Char(Word(WS[1]) and $FF), AEvent^.keyval, AEvent^.length);
                  if AEvent^.length = 1 then
                  begin
                    EventString^ := Char(Word(WS[1]) and $FF);
                    EventString[1] := #0;
                  end
                  else
                    EventString^ := #0;
                  gdk_event_key_set_string(AEvent, EventString);
                end
                else
                  AEvent^.length := 1;
                exit;
              end
              else
              begin
                ClearKey;
                Result := True;
              end;
            end;
          end;
          PassUTF8AsKeyPress := not Result;
        end;
      end;

      //  send a normal KeyPress Event for Delphi compatibility
      if (CanSendChar or PassUTF8AsKeyPress) then
      begin
        {$IFDEF EventTrace}
        EventTrace('char', data);
        {$ENDIF}

        KeyPressesChar := #0;
        if AEvent^.Length = 1 then
        begin
          // ASCII key was pressed
          KeyPressesChar := EventString^;
        end else
        begin
          KeyPressesChar := GetSpecialChar;
          //NonAscii key was pressed, and UTF8KeyPress didn't handle it.issue #21489
          if PassUTF8AsKeyPress and (KeyPressesChar = #0) then
            KeyPressesChar := Char($3F);
        end;

        if KeyPressesChar <> #0 then
        begin
          FillChar(Msg, SizeOf(Msg), 0);

          Msg.KeyData := CommonKeyData or (Flags shl 16) or $0001;
          Msg.Msg := CHAR_MAP[SysKey, ABeforeEvent];

          // send the (Sys)Char message directly (not queued) to the LCL
          Msg.Result:=0;
          Msg.CharCode := Ord(KeyPressesChar);
          if DeliverKeyMessage(TargetObj, Msg) and
            (Ord(KeyPressesChar) <> Msg.CharCode) then
          begin
            // key was changed by lcl
            if (Msg.CharCode=0) or (Msg.CharCode>=128) then
            begin
              // key set to invalid => just clear the key
              ClearKey;
            end else
            begin
              // try to change the key
              CharToKeyVal(chr(Msg.CharCode), AEvent^.KeyVal, AEvent^.length);
              if AEvent^.length = 1 then
              begin
                EventString^ := Character[1];
                EventString[1] := #0;
              end else
                EventString^ := #0;
              gdk_event_key_set_string(AEvent, EventString);
            end;
          end;
        end;
      end;
    end;

    EmulateEatenKeys;
  finally
    EventHandledByLCL.Release
  end;

  Result:=EventStopped;
end;

const
  //AlexeyT:
  //table got from usual Russian keyboard with 8 win-keys on the top

  ru_map: array[GDK_KEY_Cyrillic_yu .. GDK_KEY_Cyrillic_CAPITAL_HARDSIGN] of byte =
    (
    0, ////Ord('.'), //GDK_KEY_Cyrillic_yu = $6c0;
    VK_F, //GDK_KEY_Cyrillic_a = $6c1;
    0, ////Ord(','), //GDK_KEY_Cyrillic_be = $6c2;
    VK_W, //GDK_KEY_Cyrillic_tse = $6c3;
    VK_L, //GDK_KEY_Cyrillic_de = $6c4;
    VK_T, //GDK_KEY_Cyrillic_ie = $6c5;
    VK_A, //GDK_KEY_Cyrillic_ef = $6c6;
    VK_U, //GDK_KEY_Cyrillic_ghe = $6c7;
    0, ////Ord('['), //GDK_KEY_Cyrillic_ha = $6c8;
    VK_B, //GDK_KEY_Cyrillic_i = $6c9;
    VK_Q, //GDK_KEY_Cyrillic_shorti = $6ca;
    VK_R, //GDK_KEY_Cyrillic_ka = $6cb;
    VK_K, //GDK_KEY_Cyrillic_el = $6cc;
    VK_V, //GDK_KEY_Cyrillic_em = $6cd;
    VK_Y, //GDK_KEY_Cyrillic_en = $6ce;
    VK_J, //GDK_KEY_Cyrillic_o = $6cf;
    VK_G, //GDK_KEY_Cyrillic_pe = $6d0;
    VK_Z, //GDK_KEY_Cyrillic_ya = $6d1;
    VK_H, //GDK_KEY_Cyrillic_er = $6d2;
    VK_C, //GDK_KEY_Cyrillic_es = $6d3;
    VK_N, //GDK_KEY_Cyrillic_te = $6d4;
    VK_E, //GDK_KEY_Cyrillic_u = $6d5;
    0, ////Ord(';'), //GDK_KEY_Cyrillic_zhe = $6d6;
    VK_D, //GDK_KEY_Cyrillic_ve = $6d7;
    VK_M, //GDK_KEY_Cyrillic_softsign = $6d8;
    VK_S, //GDK_KEY_Cyrillic_yeru = $6d9;
    VK_P, //GDK_KEY_Cyrillic_ze = $6da;
    VK_I, //GDK_KEY_Cyrillic_sha = $6db;
    0, ////Ord(''''), //GDK_KEY_Cyrillic_e = $6dc;
    VK_O, //GDK_KEY_Cyrillic_shcha = $6dd;
    VK_X, //GDK_KEY_Cyrillic_che = $6de;
    0, ////Ord(']'), //GDK_KEY_Cyrillic_hardsign = $6df;
    0, ////Ord('.'), //GDK_KEY_Cyrillic_CAPITAL_YU = $6e0;
    VK_F, //GDK_KEY_Cyrillic_CAPITAL_A = $6e1;
    0, ////Ord(','), //GDK_KEY_Cyrillic_CAPITAL_BE = $6e2;
    VK_W, //GDK_KEY_Cyrillic_CAPITAL_TSE = $6e3;
    VK_L, //GDK_KEY_Cyrillic_CAPITAL_DE = $6e4;
    VK_T, //GDK_KEY_Cyrillic_CAPITAL_IE = $6e5;
    VK_A, //GDK_KEY_Cyrillic_CAPITAL_EF = $6e6;
    VK_U, //GDK_KEY_Cyrillic_CAPITAL_GHE = $6e7;
    0, ////Ord('['), //GDK_KEY_Cyrillic_CAPITAL_HA = $6e8;
    VK_B, //GDK_KEY_Cyrillic_CAPITAL_I = $6e9;
    VK_Q, //GDK_KEY_Cyrillic_CAPITAL_SHORTI = $6ea;
    VK_R, //GDK_KEY_Cyrillic_CAPITAL_KA = $6eb;
    VK_K, //GDK_KEY_Cyrillic_CAPITAL_EL = $6ec;
    VK_V, //GDK_KEY_Cyrillic_CAPITAL_EM = $6ed;
    VK_Y, //GDK_KEY_Cyrillic_CAPITAL_EN = $6ee;
    VK_J, //GDK_KEY_Cyrillic_CAPITAL_O = $6ef;
    VK_G, //GDK_KEY_Cyrillic_CAPITAL_PE = $6f0;
    VK_Z, //GDK_KEY_Cyrillic_CAPITAL_YA = $6f1;
    VK_H, //GDK_KEY_Cyrillic_CAPITAL_ER = $6f2;
    VK_C, //GDK_KEY_Cyrillic_CAPITAL_ES = $6f3;
    VK_N, //GDK_KEY_Cyrillic_CAPITAL_TE = $6f4;
    VK_E, //GDK_KEY_Cyrillic_CAPITAL_U = $6f5;
    0, ////Ord(';'), //GDK_KEY_Cyrillic_CAPITAL_ZHE = $6f6;
    VK_D, //GDK_KEY_Cyrillic_CAPITAL_VE = $6f7;
    VK_M, //GDK_KEY_Cyrillic_CAPITAL_SOFTSIGN = $6f8;
    VK_S, //GDK_KEY_Cyrillic_CAPITAL_YERU = $6f9;
    VK_P, //GDK_KEY_Cyrillic_CAPITAL_ZE = $6fa;
    VK_I, //GDK_KEY_Cyrillic_CAPITAL_SHA = $6fb;
    0, ////Ord(''''), //GDK_KEY_Cyrillic_CAPITAL_E = $6fc;
    VK_O, //GDK_KEY_Cyrillic_CAPITAL_SHCHA = $6fd;
    VK_X, //GDK_KEY_Cyrillic_CAPITAL_CHE = $6fe;
    0 ////Ord(']') //GDK_KEY_Cyrillic_CAPITAL_HARDSIGN = $6ff;
    );

function gdkKeyMapChanged(aKeymap: PGdkKeymap; Data: gPointer) : GBoolean; cdecl;
begin
  Result:=CallBackDefaultReturn;
  if aKeymap=nil then ;
  if Data=nil then ;
  {$IFDEF VerboseKeyboard}
  debugln(['gdkKeyMapChanged']);
  {$ENDIF}
  InitKeyboardTables;
end;

{------------------------------------------------------------------------------
  Procedure: InitKeyboardTables
  Params:    none
  Returns:   none

  Initializes the CharToVK and CKeyToVK tables
 ------------------------------------------------------------------------------}
procedure InitKeyboardTables;

  procedure FindVKeyInfo(const AKeySym: Cardinal; var AVKey: Byte;
    out AExtended, AHasMultiVK, ASecondKey: Boolean);
  var
    ByteKey: Byte;
  begin
    AExtended := False;
    AHasMultiVK := False;
    AVKey := VK_UNDEFINED;
    ASecondKey := False;

    case AKeySym of
      32..255: begin
        ByteKey:=Byte(AKeySym);
        case Chr(ByteKey) of // Normal ASCII chars
          //only unshifted values are checked
          //'A'..'Z',
          '0'..'9',
          ' ':      AVKey := ByteKey;
          'a'..'z': AVKey := ByteKey - Ord('a') + Ord('A');
          '+': AVKey := VK_OEM_PLUS;
          ',': AVKey := VK_OEM_COMMA;
          '-': AVKey := VK_OEM_MINUS;
          '.': AVKey := VK_OEM_PERIOD;

          // try the US keycodes first
          ';': AVKey := VK_OEM_1;
          '/': AVKey := VK_OEM_2;
          '`': AVKey := VK_OEM_3;
          '[': AVKey := VK_OEM_4;
          '\': AVKey := VK_OEM_5;
          ']': AVKey := VK_OEM_6;
          '''': AVKey := VK_OEM_7;
        end;
      end;

      GDK_KEY_Tab,
      GDK_KEY_ISO_Left_Tab: AVKey := VK_TAB;
      GDK_KEY_RETURN:       AVKey := VK_RETURN;
  //    GDK_KEY_LINEFEED;     AVKey := $0A;

      // Cursor block / keypad
      GDK_KEY_INSERT:
      begin
        AExtended := True;
        AVKey := VK_INSERT;
      end;
      GDK_KEY_DELETE:
      begin
        AExtended := True;
        AVKey := VK_DELETE;
      end;
      GDK_KEY_HOME:
      begin
        AExtended := True;
        AVKey := VK_HOME;
      end;
      GDK_KEY_LEFT:
      begin
        AExtended := True;
        AVKey := VK_LEFT;
      end;
      GDK_KEY_UP:
      begin
        AExtended := True;
        AVKey := VK_UP;
      end;
      GDK_KEY_RIGHT:
      begin
        AExtended := True;
        AVKey := VK_RIGHT;
      end;
      GDK_KEY_DOWN:
      begin
        AExtended := True;
        AVKey := VK_DOWN;
      end;
      GDK_KEY_PAGE_UP:
      begin
        AExtended := True;
        AVKey := VK_PRIOR;
      end;
      GDK_KEY_PAGE_DOWN:
      begin
        AExtended := True;
        AVKey := VK_NEXT;
      end;
      GDK_KEY_END:
      begin
        AExtended := True;
        AVKey := VK_END;
      end;

      // Keypad
      GDK_KEY_KP_ENTER:
      begin
        AExtended := True;
        AVKey := VK_Return;
      end;
      GDK_KEY_KP_Space, GDK_KEY_KP_Begin:
      begin
        AVKey := VK_CLEAR;
        AHasMultiVK := True;
      end;
      GDK_KEY_KP_INSERT:
      begin
        // Keypad key is not extended
        AVKey := VK_INSERT;
        AHasMultiVK := True;
      end;
      GDK_KEY_KP_HOME:
      begin
        // Keypad key is not extended
        AVKey := VK_HOME;
        AHasMultiVK := True;
      end;
      GDK_KEY_KP_LEFT:
      begin
        // Keypad key is not extended
        AVKey := VK_LEFT;
        AHasMultiVK := True;
      end;
      GDK_KEY_KP_UP:
      begin
        // Keypad key is not extended
        AVKey := VK_UP;
        AHasMultiVK := True;
      end;
      GDK_KEY_KP_RIGHT:
      begin
        // Keypad key is not extended
        AVKey := VK_RIGHT;
        AHasMultiVK := True;
      end;
      GDK_KEY_KP_DOWN:
      begin
        // Keypad key is not extended
        AVKey := VK_DOWN;
        AHasMultiVK := True;
      end;
      GDK_KEY_KP_PAGE_UP:
      begin
        // Keypad key is not extended
        AVKey := VK_PRIOR;
        AHasMultiVK := True;
      end;
      GDK_KEY_KP_PAGE_DOWN:
      begin
        // Keypad key is not extended
        AVKey := VK_NEXT;
        AHasMultiVK := True;
      end;
      GDK_KEY_KP_END:
      begin
        // Keypad key is not extended
        AVKey := VK_END;
        AHasMultiVK := True;
      end;
      GDK_KEY_Num_Lock:
      begin
        AExtended := True;
        AVKey := VK_NUMLOCK;
      end;
      GDK_KEY_KP_F1..GDK_KEY_KP_F4:
      begin
        // not on "normal" keyboard so defined extended to differentiate between normal Fn
        AExtended := True;
        AVKey := VK_F1 + AKeySym - GDK_KEY_KP_F1;
      end;
      GDK_KEY_KP_TAB:
      begin
        // not on "normal" keyboard so defined extended to differentiate between normal TAB
        AExtended := True;
        AVKey := VK_TAB;
      end;
      GDK_KEY_KP_Multiply:
      begin
        AVKey := VK_MULTIPLY;
      end;
      GDK_KEY_KP_Add:
      begin
        AVKey := VK_ADD;
      end;
      GDK_KEY_KP_Separator:
      begin
        // Keypad key is not extended
        AVKey := VK_SEPARATOR;
        AHasMultiVK := True;
      end;
      GDK_KEY_KP_Subtract:
      begin
        AVKey := VK_SUBTRACT;
      end;
      GDK_KEY_KP_Decimal:
      begin
        // Keypad key is not extended
        AVKey := VK_DECIMAL;
        AHasMultiVK := True;
      end;
      GDK_KEY_KP_Delete:
      begin
        // Keypad key is not extended
        AVKey := VK_DELETE;
        AHasMultiVK := True;
      end;
      GDK_KEY_KP_Divide:
      begin
        AExtended := True;
        AVKey := VK_DIVIDE;
      end;
      GDK_KEY_KP_0..GDK_KEY_KP_9:
      begin
        // Keypad key is not extended, it is identified by VK
        AVKey := VK_NUMPAD0 + AKeySym - GDK_KEY_KP_0;
        AHasMultiVK := True;
      end;

      GDK_KEY_BackSpace:    AVKey := VK_BACK;
      GDK_KEY_Clear:        AVKey := VK_CLEAR;
      GDK_KEY_Pause:        AVKey := VK_PAUSE;
      GDK_KEY_Scroll_Lock:  AVKey := VK_SCROLL;
      GDK_KEY_Sys_Req:      AVKey := VK_SNAPSHOT;
      GDK_KEY_Escape:       AVKey := VK_ESCAPE;

      GDK_KEY_Kanji:        AVKey := VK_KANJI;

      GDK_Key_Select:       AVKey := VK_SELECT;
      GDK_Key_Print:        AVKey := VK_PRINT;
      GDK_Key_Execute:      AVKey := VK_EXECUTE;
      GDK_Key_Cancel:       AVKey := VK_CANCEL;
      GDK_Key_Help:         AVKey := VK_HELP;
      GDK_Key_Break:        AVKey := VK_CANCEL;
      GDK_Key_Mode_switch,
      GDK_KEY_ISO_Level3_Shift,
      GDK_KEY_ISO_Level5_Shift:  AVKey := VK_MODECHANGE;
      GDK_Key_Caps_Lock:    AVKey := VK_CAPITAL;
      GDK_Key_Shift_L:      AVKey := VK_SHIFT;
      GDK_Key_Shift_R:
      begin
        AVKey := VK_SHIFT;
        ASecondKey := True;
      end;
      GDK_Key_Control_L:    AVKey := VK_CONTROL;
      GDK_Key_Control_R:
      begin
        AVKey := VK_CONTROL;
        ASecondKey := True;
      end;
  //      GDK_Key_Meta_L:       AVKey := VK_MENU;  //shifted alt, so it is found by alt
  //      GDK_Key_Meta_R:       AVKey := VK_MENU;
      GDK_Key_Alt_L:        AVKey := VK_MENU;
      GDK_Key_Alt_R:
      begin
        AVKey := VK_MENU;
        ASecondKey := True;
      end;
      GDK_Key_Super_L:      AVKey := VK_LWIN;
      GDK_Key_Super_R: begin
        AVKey := VK_RWIN;
        ASecondKey := True;
      end;
      GDK_Key_Menu:         AVKey := VK_APPS;

      // function keys
      GDK_KEY_F1..GDK_KEY_F24:  AVKey := VK_F1 + AKeySym - GDK_Key_F1;

      // Extra keys on a "internet" keyboard
      GDKX_KEY_Sleep:
      begin
        AExtended := True;
        AVKey := VK_SLEEP;
      end;
      GDKX_KEY_AudioLowerVolume:
      begin
        AExtended := True;
        AVKey := VK_VOLUME_DOWN;
      end;
      GDKX_KEY_AudioMute:
      begin
        AExtended := True;
        AVKey := VK_VOLUME_MUTE;
      end;
      GDKX_KEY_AudioRaiseVolume:
      begin
        AExtended := True;
        AVKey := VK_VOLUME_UP;
      end;
      GDKX_KEY_AudioPlay:
      begin
        AExtended := True;
        AVKey := VK_MEDIA_PLAY_PAUSE;
      end;
      GDKX_KEY_AudioStop:
      begin
        AExtended := True;
        AVKey := VK_MEDIA_STOP;
      end;
      GDKX_KEY_AudioPrev:
      begin
        AExtended := True;
        AVKey := VK_MEDIA_PREV_TRACK;
      end;
      GDKX_KEY_AudioNext:
      begin
        AExtended := True;
        AVKey := VK_MEDIA_NEXT_TRACK;
      end;
      GDKX_KEY_Mail:
      begin
        AExtended := True;
        AVKey := VK_LAUNCH_MAIL;
      end;
      GDKX_KEY_HomePage:
      begin
        AExtended := True;
        AVKey := VK_BROWSER_HOME;
      end;
      GDKX_KEY_Back:
      begin
        AExtended := True;
        AVKey := VK_BROWSER_BACK;
      end;
      GDKX_KEY_Forward:
      begin
        AExtended := True;
        AVKey := VK_BROWSER_FORWARD;
      end;
      GDKX_KEY_Stop:
      begin
        AExtended := True;
        AVKey := VK_BROWSER_STOP;
      end;
      GDKX_KEY_Refresh:
      begin
        AExtended := True;
        AVKey := VK_BROWSER_REFRESH;
      end;
      GDKX_KEY_WWW:
      begin
        AExtended := True;
        AVKey := VK_BROWSER_HOME;
      end;
      GDKX_KEY_Favorites:
      begin
        AExtended := True;
        AVKey := VK_BROWSER_FAVORITES;
      end;
      GDKX_KEY_AudioMedia:
      begin
        AExtended := True;
        AVKey := VK_LAUNCH_MEDIA_SELECT;
      end;
      GDKX_KEY_MyComputer:
      begin
        AExtended := True;
        AVKey := VK_LAUNCH_APP1;
      end;
      GDKX_KEY_Calculator:
      begin
        AExtended := True;
        AVKey := VK_LAUNCH_APP2;
      end;

      // For faster cases, group by families
      $400..$4FF: begin
        // Katakana
      end;

      $500..$5FF: begin
        // Arabic
        case AKeySym of
          GDK_KEY_arabic_hamza:                  AVKey := VK_X;
          GDK_KEY_arabic_hamzaonwaw:             AVKey := VK_C;
          GDK_KEY_arabic_hamzaonyeh:             AVKey := VK_Z;
          GDK_KEY_arabic_alef:                   AVKey := VK_H;
          GDK_KEY_arabic_beh:                    AVKey := VK_F;
          GDK_KEY_arabic_tehmarbuta:             AVKey := VK_M;
          GDK_KEY_arabic_teh:                    AVKey := VK_J;
          GDK_KEY_arabic_theh:                   AVKey := VK_E;
          GDK_KEY_arabic_jeem:                   AVKey := VK_OEM_4;
          GDK_KEY_arabic_hah:                    AVKey := VK_P;
          GDK_KEY_arabic_khah:                   AVKey := VK_O;
          GDK_KEY_arabic_dal:                    AVKey := VK_OEM_6;
          GDK_KEY_arabic_thal:                   AVKey := VK_OEM_3;
          GDK_KEY_arabic_ra:                     AVKey := VK_V;
          GDK_KEY_arabic_zain:                   AVKey := VK_OEM_PERIOD;
          GDK_KEY_arabic_seen:                   AVKey := VK_S;
          GDK_KEY_arabic_sheen:                  AVKey := VK_A;
          GDK_KEY_arabic_sad:                    AVKey := VK_W;
          GDK_KEY_arabic_dad:                    AVKey := VK_Q;
          GDK_KEY_arabic_tah:                    AVKey := VK_OEM_7;
          GDK_KEY_arabic_zah:                    AVKey := VK_OEM_2;
          GDK_KEY_arabic_ain:                    AVKey := VK_U;
          GDK_KEY_arabic_ghain:                  AVKey := VK_Y;
          GDK_KEY_arabic_feh:                    AVKey := VK_T;
          GDK_KEY_arabic_qaf:                    AVKey := VK_R;
          GDK_KEY_arabic_kaf:                    AVKey := VK_OEM_1;
          GDK_KEY_arabic_lam:                    AVKey := VK_G;
          GDK_KEY_arabic_meem:                   AVKey := VK_L;
          GDK_KEY_arabic_noon:                   AVKey := VK_K;
          GDK_KEY_arabic_heh:                    AVKey := VK_I;
          GDK_KEY_arabic_waw:                    AVKey := VK_OEM_COMMA;
          GDK_KEY_arabic_alefmaksura:            AVKey := VK_N;
          GDK_KEY_arabic_yeh:                    AVKey := VK_D;
        end;
      end;

      $600..$6FF: begin
        // Cyrillic

        // MWE:
        // These VK codes are not compatible with all cyrillic KBlayouts
        // Example:
        // VK_A on a russian layout generates a cyrillic_EF
        // VK_A on a serbian layout generates a cyrillic_A
        //
        // Maybe in future we can take the KBLayout into account
        //
        // AlexeyT:
        // Now Ru keys on RU keyb layout work ok (array ru_map),
        // cannot test Serbian/Ukrainian/Byelorussian etc
        case AKeySym of
          Low(ru_map)..High(ru_map):  AVKey := ru_map[AKeySym];
        end;
      end;

      $700..$7FF: begin
        // Greek
        case AKeySym of
          // Capital is not needed, the lower will match
          GDK_KEY_greek_alpha:           AVKey := VK_A;
          GDK_KEY_greek_beta:            AVKey := VK_B;
          GDK_KEY_greek_gamma:           AVKey := VK_G;
          GDK_KEY_greek_delta:           AVKey := VK_D;
          GDK_KEY_greek_epsilon:         AVKey := VK_E;
          GDK_KEY_greek_zeta:            AVKey := VK_Z;
          GDK_KEY_greek_eta:             AVKey := VK_H;
          GDK_KEY_greek_theta:           AVKey := VK_U;
          GDK_KEY_greek_iota:            AVKey := VK_I;
          GDK_KEY_greek_kappa:           AVKey := VK_K;
          GDK_KEY_greek_lamda:           AVKey := VK_L;
          GDK_KEY_greek_mu:              AVKey := VK_M;
          GDK_KEY_greek_nu:              AVKey := VK_N;
          GDK_KEY_greek_xi:              AVKey := VK_J;
          GDK_KEY_greek_omicron:         AVKey := VK_O;
          GDK_KEY_greek_pi:              AVKey := VK_P;
          GDK_KEY_greek_rho:             AVKey := VK_R;
          GDK_KEY_greek_sigma:           AVKey := VK_S;
          GDK_KEY_greek_finalsmallsigma: AVKey := VK_W;
          GDK_KEY_greek_tau:             AVKey := VK_T;
          GDK_KEY_greek_upsilon:         AVKey := VK_Y;
          GDK_KEY_greek_phi:             AVKey := VK_F;
          GDK_KEY_greek_chi:             AVKey := VK_X;
          GDK_KEY_greek_psi:             AVKey := VK_C;
          GDK_KEY_greek_omega:           AVKey := VK_V;
        end;
      end;

      $C00..$CFF: begin
        // Hebrew
        // Shifted keys will produce A..Z so the VK codes will be assigned there
      end;

      $D00..$DFF: begin
        // Thai
        // To many differences to assign VK codes through lookup
        // Thai Kedmanee and Thai Pattachote are complete different layouts
      end;

      $E00..$EFF: begin
        // Korean
      end;
    end;
  end;

  function IgnoreShifted(const AUnshiftKeySym: Cardinal): Boolean;
  begin
    case AUnshiftKeySym of
      GDK_KEY_END,
      GDK_KEY_HOME,
      GDK_KEY_LEFT,
      GDK_KEY_RIGHT,
      GDK_KEY_UP,
      GDK_KEY_DOWN,
      GDK_KEY_PAGE_UP,
      GDK_KEY_PAGE_DOWN: Result := True;
    else
      Result := False;
    end;
  end;

  procedure NextFreeVK(var AFreeVK: Byte);
  begin
    case AFreeVK of
      $96: AFreeVK := $E1;
      $E1: AFreeVK := $E3;
      $E4: AFreeVK := $E6;
      $E6: AFreeVK := $E9;
      $F5: begin
        {$ifndef HideKeyTableWarnings}
        DebugLn('[WARNING] Out of OEM specific VK codes, changing to unassigned');
        {$endif}
        AFreeVK := $88;
      end;
      $8F: AFreeVK := $97;
      $9F: AFreeVK := $D8;
      $DA: AFreeVK := $E5;
      $E5: AFreeVK := $E8;
      $E8: begin
        {$ifndef HideKeyTableWarnings}
        DebugLn('[WARNING] Out of unassigned VK codes, assigning $FF');
        {$endif}
        AFreeVK := $FF;
      end;
      $FF: AFreeVK := $FF; // stay there
    else
      Inc(AFreeVK);
    end;
  end;
  

const
  KEYFLAGS: array[0..3] of Byte = (
    $00,
    KCINFO_FLAG_SHIFT,
    KCINFO_FLAG_ALTGR,
    KCINFO_FLAG_ALTGR or KCINFO_FLAG_SHIFT
  );
  EXTFLAG: array[Boolean] of Byte = (
    $00,
    KCINFO_FLAG_EXT
  );
  MULTIFLAG: array[Boolean] of Byte = (
    $00,
    KCINFO_FLAG_SHIFT_XOR_NUM
  );

{$ifdef HasX}
{
 Starting gdk 2.10 Alt, meta, hyper are reported by a own mask. Since we support
 older versions, we need to create the modifiermap ourselves for X and we cannot
 use them
}
type
  TModMap = array[Byte] of Cardinal;

  procedure SetupModifiers(ADisplay: Pointer; var AModMap: TModMap);
  const
    MODIFIERS: array[0..7] of Cardinal = (
      GDK_SHIFT_MASK,
      GDK_LOCK_MASK,
      GDK_CONTROL_MASK,
      GDK_MOD1_MASK,
      GDK_MOD2_MASK,
      GDK_MOD3_MASK,
      GDK_MOD4_MASK,
      GDK_MOD5_MASK
    );
  var
    Map: PXModifierKeymap;
    KeyCode: PKeyCode;
    Modifier, n: Integer;
  begin
    FillByte(AModMap, SizeOf(AModMap), 0);
  
    Map := XGetModifierMapping(ADisplay);
    KeyCode := Map^.modifiermap;
    
    for Modifier := Low(MODIFIERS) to High(MODIFIERS) do
    begin
      for n := 1 to Map^.max_keypermod do
      begin
        if KeyCode^ <> 0
        then begin
          AModMap[KeyCode^] := MODIFIERS[Modifier];
          {$ifdef VerboseModifiermap}
          DebugLn('Mapped keycode=%u to modifier=$%2.2x', [KeyCode^, MODIFIERS[Modifier]]);
          {$endif}
        end;
        Inc(KeyCode);
      end;
    end;
    
    XFreeModifiermap(Map);
  end;
  
  procedure UpdateModifierMap(const AModMap: TModMap; AKeyCode: Byte; AKeySym: Cardinal);
  var
  {$if defined(VerboseModifiermap) or defined(VerboseKeyboard)}
    s: string;
  {$endif}
    ShiftState: TShiftStateEnum;
  begin
    if AModMap[AKeyCode] = 0 then Exit;

    case AKeySym of
      GDK_KEY_Caps_Lock,
      GDK_KEY_Shift_Lock: ShiftState := ssCaps;
      GDK_KEY_Num_Lock: ShiftState := ssNum;
      GDK_KEY_Scroll_Lock: ShiftState := ssScroll;
      GDK_Key_Shift_L,
      GDK_Key_Shift_R: ShiftState := ssShift;
      GDK_KEY_Control_L,
      GDK_KEY_Control_R: ShiftState := ssCtrl;
      {$ifndef UseOwnShiftState}
      // UseOwnShiftState will track these, so we don't have to put them in the modmap
      GDK_KEY_Meta_L,
      GDK_KEY_Meta_R: ShiftState := ssMeta;
      GDK_KEY_Alt_L,
      GDK_KEY_Alt_R: ShiftState := ssAlt;
      GDK_KEY_Super_L,
      GDK_KEY_Super_R: ShiftState := ssSuper;
      GDK_KEY_Hyper_L,
      GDK_KEY_Hyper_R: ShiftState := ssHyper;
      GDK_KEY_ISO_Level3_Shift{,
      GDK_KEY_Mode_switch}: ShiftState := ssAltGr;
      {$endif}
    else
      Exit;
    end;
    
    MModifiers[ShiftState].Mask := AModMap[AKeyCode];
    MModifiers[ShiftState].UseValue := False;
    
    {$if defined(VerboseModifiermap) or defined(VerboseKeyboard)}
    WriteStr(s, ShiftState);
    DebugLn('UpdateModifierMap Mapped keycode=%u, keysym=$%x, modifier=$%2.2x to shiftstate %s',
            [AKeyCode, AKeySym, AModMap[AKeyCode], s]);
    {$endif}

  end;

  {$ifdef UseOwnShiftState}
  procedure UpdateKeyStateMap(var AIndex: integer; AKeyCode: Byte; AKeySym: Cardinal);
  var
    Enum: TShiftStateEnum;
    {$IFDEF VerboseKeyboard}
    s: string;
    {$ENDIF}
  begin
    // gdk emulates some keys by creating extra key signals without the
    // current modifier state. Thus the LCL has to query the current state
    // of the following modifiers (e.g. bug 30544).
    case AKeySym of
      GDK_KEY_Control_L,
      GDK_KEY_Control_R: Enum := ssCtrl; // see bug 30544, Alt+Ctrl
      GDK_KEY_Alt_L, GDK_KEY_Alt_R:     Enum := ssAlt;
      GDK_KEY_Meta_L, GDK_KEY_Meta_R:   Enum := ssMeta;
      GDK_KEY_Super_L, GDK_KEY_Super_R: Enum := ssSuper;
      GDK_KEY_Hyper_L, GDK_KEY_Hyper_R: Enum := ssHyper;
      GDK_KEY_Mode_switch,
      GDK_KEY_ISO_Level3_Shift,
      GDK_KEY_ISO_Level3_Latch,
      GDK_KEY_ISO_Level3_Lock,
      GDK_KEY_ISO_Level5_Shift,
      GDK_KEY_ISO_Level5_Latch,
      GDK_KEY_ISO_Level5_Lock:         Enum := ssAltGr;
    else
      Exit;
    end;

    if High(MKeyStateMap) < AIndex
    then SetLength(MKeyStateMap, AIndex + 16);

    MKeyStateMap[AIndex].Index := AKeyCode shr 3;
    MKeyStateMap[AIndex].Mask := 1 shl (AKeyCode and 7);
    MKeyStateMap[AIndex].Enum := Enum;
    {$IFDEF VerboseKeyboard}
    writestr(s,Enum);
    debugln(['UpdateKeyStateMap AKeySym=$',HexStr(AKeySym,4),'=',AKeySym,' ShiftState=',s,' Index=',MKeyStateMap[AIndex].Index,' Mask=',HexStr(MKeyStateMap[AIndex].Mask,4)]);
    {$ENDIF}
    Inc(AIndex)
  end;
  {$endif UseOwnShiftState}

{$endif HasX}

const
  // first OEM specific VK
  VK_FIRST_OEM = $92;
var
  KeySyms: array of guint;
  KeyVals: Pguint = nil;
  KeymapKeys: PGdkKeymapKey = nil;
  UniChar: gunichar;

  KeySymCount: Integer;
  KeySymChars: array[0..16] of Char;
  KeySymCharLen: Integer;
  NewKeyMap: PGdkKeymap;

{$ifdef HasX}
  XDisplay: PDisplay;
  ModMap: TModMap;
{$endif}
{$ifdef UseOwnShiftState}
  KeyStateMapIndex: Integer;
{$endif}

  KeyCode: Byte;
  m: Integer;
  LoKey, HiKey: Integer;

  VKey, FreeVK: Byte;
  HasMultiVK, DummyBool, Extended, SecondKey, HasKey, ComputeVK: Boolean;
begin
{$ifdef HasX}
  XDisplay := gdk_display;
  if XDisplay = nil then Exit;
  FillByte(MKeyStateMap, SizeOF(MKeyStateMap), 0);
  SetupModifiers(XDisplay, ModMap{%H-});
{$endif}

  NewKeyMap:=gdk_keymap_get_for_display(gdk_display_get_default);
  if NewKeyMap<>GdkKeymap then begin
    if GdkKeymap<>nil then
      DisconnectGdkKeymapChangedSignal;
    GdkKeymap:=NewKeyMap;
    if GdkKeymap<>nil then
      GdkKeyMapChangedID:=g_signal_connect_after(GdkKeymap, 'keys-changed',
                                        TGTKSignalFunc(@gdkKeyMapChanged), nil);
  end;

  FillChar(MKeyCodeInfo, SizeOf(MKeyCodeInfo), $FF);
  FillChar(MVKeyInfo, SizeOf(MVKeyInfo), 0);

  LoKey := 0;
  HiKey := 255;

{$ifdef UseOwnShiftState}
  KeyStateMapIndex := 0;
{$endif}
  FreeVK := VK_FIRST_OEM;
  for KeyCode := LoKey to HiKey do
  begin
    // get all values for this keycode for all groups and level
    if not gdk_keymap_get_entries_for_keycode(GdkKeymap, KeyCode, KeymapKeys, KeyVals, @KeySymCount) then
      Continue;
    SetLength(KeySyms{%H-}, KeySymCount);
    Move(KeyVals^, KeySyms[0], SizeOf(KeySyms[0]) * KeySymCount);
    g_free(KeymapKeys); // unused but we cannot pass a nil as param
    g_free(KeyVals);
    HasKey := KeySyms[0] <> 0;
    //DebugLn(['InitKeyboardTables ',KeyCode,' ',HasKey,' ',KeySyms[0]]);

  {$ifdef HasX}
    // Check if this keycode is a modifier
    // and if yes add it to modifiers map
    // loop through all keysyms till one found.
    // Some maps have a modifier with an undefined first keysym. It is checked for
    // modifiers, but not for vkeys
    for m := 0 to KeySymCount - 1 do
    begin
      if KeySyms[m] = 0 then Continue;
      UpdateModifierMap(ModMap, KeyCode, KeySyms[m]);
      {$ifdef UseOwnShiftState}
      UpdateKeyStateMap(KeyStateMapIndex, KeyCode, KeySyms[m]);
      {$endif}
      Break;
    end;
  {$endif}

    // Continue if there is no keysym found
    if not HasKey then Continue;

    // Start looking for a VKcode
    VKey := VK_UNDEFINED;
    for m := 0 to KeySymCount - 1 do
    begin
      if KeySyms[m] = 0 then Continue;
      FindVKeyInfo(KeySyms[m], VKey, Extended{%H-}, HasMultiVK,{%H-} SecondKey);
    {$ifdef Windows}
      // on windows, the keycode is perdef the VK,
      // we only enter this loop to set the correct flags
      VKey := KeyCode;
      Break;
    {$else}
      if HasMultiVK then Break; // has VK per def
      if VKey = VK_UNDEFINED then Continue;
      if MVKeyInfo[VKey].KeyCode[SecondKey or Extended] = 0 then Break; // found unused VK

      // already in use
      VKey := VK_UNDEFINED;
    {$endif}
    end;

    ComputeVK := VKey = VK_UNDEFINED;
    if ComputeVK and not HasMultiVK
    then begin
      VKey := FreeVK;
      NextFreeVK(FreeVK);
    end;

    if VKey = VK_UNDEFINED
    then begin
      MKeyCodeInfo[KeyCode].Flags := $FF;
    end
    else begin
      MKeyCodeInfo[KeyCode].Flags := EXTFLAG[Extended] or MULTIFLAG[HasMultiVK];
      MVKeyInfo[VKey].KeyCode[SecondKey] := KeyCode;
    end;
    MKeyCodeInfo[KeyCode].VKey1 := VKey;

    for m := 0 to Min(High(MVKeyInfo[0].KeyChar), KeySymCount - 1) do
    begin
      if KeySyms[m] = 0 then Continue;
      if (m >= 2) and (KeySyms[m] = KeySyms[m - 2]) then Continue;

      if HasMultiVK
      then begin
        if m >= 2 then Break; // Only process shift

        // The keypadkeys have 2 VK_keycodes :(
        // In that case we have to FindKeyInfo for every keysym
        if m = 1
        then begin
          FindVKeyInfo(KeySyms[m], VKey, Extended, DummyBool, DummyBool{%H-});
          MKeyCodeInfo[KeyCode].VKey2 := VKey;
        end;
      end;
      if VKey = VK_UNDEFINED then Continue;

      MKeyCodeInfo[KeyCode].Flags := MKeyCodeInfo[KeyCode].Flags or KEYFLAGS[m];

      FillByte(KeySymChars{%H-}, SizeOf(KeySymChars), 0);

      UniChar := gdk_keyval_to_unicode(KeySyms[m]);
      if UniChar = 0 then Continue;
      KeySymCharLen := g_unichar_to_utf8(UniChar, @KeySymChars[0]);

      if (KeySymCharLen > SizeOf(TVKeyUTF8Char))
      then DebugLn('[WARNING] InitKeyboardTables - Keysymstring for keycode=%u longer than %u bytes: %s', [KeyCode, SizeOf(TVKeyUTF8Char), KeySymChars]);
      Move(KeySymChars[0], MVKeyInfo[VKey].KeyChar[m], SizeOf(TVKeyUTF8Char));
    end;
  end;
{$ifdef UseOwnShiftState}
  SetLength(MKeyStateMap, KeyStateMapIndex);
{$endif}
end;

{------------------------------------------------------------------------------
  Procedure: DoneKeyboardTables
  Params:    none
  Returns:   none

  Frees the dynamic keyboard tables
 ------------------------------------------------------------------------------}
procedure DoneKeyboardTables;
var
  i: Integer;
begin
  DisconnectGdkKeymapChangedSignal;
  if LCLHandledKeyEvents<>nil then begin
    for i:=0 to LCLHandledKeyEvents.Count-1 do
      TLCLHandledKeyEvent(LCLHandledKeyEvents[i]).Release;
    LCLHandledKeyEvents.Free;
    LCLHandledKeyEvents:=nil;
  end;
  if LCLHandledKeyAfterEvents<>nil then begin
    for i:=0 to LCLHandledKeyAfterEvents.Count-1 do
      TLCLHandledKeyEvent(LCLHandledKeyAfterEvents[i]).Release;
    LCLHandledKeyAfterEvents.Free;
    LCLHandledKeyAfterEvents:=nil;
  end;
end;

procedure DisconnectGdkKeymapChangedSignal;
begin
  if GdkKeymap=nil then exit;
  g_signal_handler_disconnect(GdkKeymap, GdkKeyMapChangedID);
  GdkKeyMapChangedID:=0;
end;

{------------------------------------------------------------------------------
  Function:  GetVKeyInfo
  Params:    AVKey: A virtual key to get the info for
  Returns:   A Info record

  This function is more a safety to make sure MVkeyInfo isn't accessed out of
  it's bounds
 ------------------------------------------------------------------------------}
function GetVKeyInfo(const AVKey: Byte): TVKeyInfo;
begin
  Result := MVKeyInfo[AVKey];
end;

{------------------------------------------------------------------------------
  Procedure: GTKEventState2ShiftState
  Params:    KeyState: The gtk keystate
  Returns:   the TShiftState for the given KeyState

  GTKEventStateToShiftState converts a GTK event state to a LCL/Delphi TShiftState
 ------------------------------------------------------------------------------}
function GTKEventStateToShiftState(KeyState: LongWord): TShiftState;
  {$ifdef HasX}
  function GetState: TShiftState;
  var
    Keys: chararr32;
    n: Integer;
  begin
    Result := [];
    keys:='';
    XQueryKeyMap(gdk_display, Keys);
    for n := Low(MKeyStateMap) to High(MKeyStateMap) do
    begin
      if Ord(Keys[MKeyStateMap[n].Index]) and MKeyStateMap[n].Mask = 0 then Continue;
      Include(Result, MKeyStateMap[n].Enum);
    end;
  end;
  {$else}
  {$ifdef windows}
  function GetState: TShiftState;
  begin
    Result := [];
    if GetKeyState(VK_MENU) < 0 then Include(Result, ssAlt);
    if (GetKeyState(VK_LWIN) < 0) or (GetKeyState(VK_RWIN) < 0) then Include(Result, ssMeta);
  end;
  {$else}
  function GetState: TShiftState;
  begin
    Result := [];
  end;
  {$endif}
  {$endif}

var
  State: TShiftStateEnum;
begin
  {$ifdef UseOwnShiftState}
  Result := GetState;
  {$else}
  Result := [];
  {$endif}
  {$IFDEF VerboseKeyboard}
  if (KeyState<>0) or (Result-[ssLeft,ssRight]<>[]) then
    debugln(['GTKEventStateToShiftState KeyState=',HexStr(KeyState,8),' X-State=',dbgs(Result)]);
  {$ENDIF}
  for State := Low(State) to High(State) do
  begin
    if MModifiers[State].Mask = 0 then Continue;
    if MModifiers[State].UseValue
    then begin
      if KeyState and MModifiers[State].Mask = MModifiers[State].Value
      then Include(Result, State);
    end
    else begin
      if KeyState and MModifiers[State].Mask <> 0
      then Include(Result, State);
    end;
  end;
  {$IFDEF VerboseKeyboard}
  if (KeyState<>0) or (Result-[ssLeft,ssRight]<>[]) then
    debugln(['GTKEventStateToShiftState KeyState=',HexStr(KeyState,8),' Result=',dbgs(Result)]);
  {$ENDIF}
end;

{------------------------------------------------------------------------------
  Procedure: StoreCommonDialogSetup
  Params:    ADialog: TCommonDialog
  Returns:   none

  Stores the size of a TCommonDialog.
 ------------------------------------------------------------------------------}
procedure StoreCommonDialogSetup(ADialog: TCommonDialog);
var DlgWindow: PGtkWidget;
begin
  if (ADialog=nil) or (ADialog.Handle=0) then exit;
  DlgWindow:={%H-}PGtkWidget(ADialog.Handle);
  if DlgWindow^.Allocation.Width>0 then
    ADialog.Width:=DlgWindow^.Allocation.Width;
  if DlgWindow^.Allocation.Height>0 then
    ADialog.Height:=DlgWindow^.Allocation.Height;
end;

{------------------------------------------------------------------------------
  Procedure: DestroyCommonDialogAddOns
  Params:    ADialog: TCommonDialog
  Returns:   none

  Free the memory of additional data of a TCommonDialog
 ------------------------------------------------------------------------------}
procedure DestroyCommonDialogAddOns(ADialog: TCommonDialog);
var
  DlgWindow: PGtkWidget;
  HistoryList: TFPList; // list of TFileSelHistoryListEntry
  AHistoryEntry: PFileSelHistoryEntry;
  i: integer;
  FileSelWidget: PGtkFileSelection;
  LCLHistoryMenu: PGTKWidget;
begin
  if (ADialog=nil) or (not ADialog.HandleAllocated) then exit;
  DlgWindow:={%H-}PGtkWidget(ADialog.Handle);
  {$IFDEF VerboseTransient}
  DebugLn('DestroyCommonDialogAddOns ',DbgSName(ADialog));
  {$ENDIF}
  {$IFDEF HASX}
  gtk_window_set_modal(PGtkWindow(DlgWindow),false);
  {$ENDIF}
  gtk_window_set_transient_for(PGtkWindow(DlgWindow),nil);
  if ADialog is TOpenDialog then begin
    FileSelWidget:=GTK_FILE_CHOOSER(DlgWindow);
    LCLHistoryMenu:=PGTKWidget(g_object_get_data(PGObject(FileSelWidget),
                                       'LCLHistoryMenu'));
    if LCLHistoryMenu<>nil then FreeWidgetInfo(LCLHistoryMenu);

    // free history
    HistoryList:=TFPList(g_object_get_data(PGObject(DlgWindow),
                                             'LCLHistoryList'));
    if HistoryList<>nil then begin
      for i:=0 to HistoryList.Count-1 do begin
        AHistoryEntry:=PFileSelHistoryEntry(HistoryList[i]);
        StrDispose(AHistoryEntry^.Filename);
        AHistoryEntry^.Filename:=nil;
        Dispose(AHistoryEntry);
      end;
      HistoryList.Free;
      g_object_set_data(PGObject(DlgWindow),'LCLHistoryList',nil);
    end;

    // free preview handle
    if ADialog is TPreviewFileDialog then begin
      if TPreviewFileDialog(ADialog).PreviewFileControl<>nil then
        TPreviewFileDialog(ADialog).PreviewFileControl.Handle:=0;
    end;
  end;
end;

{------------------------------------------------------------------------------
  Procedure: PopulateFileAndDirectoryLists
  Params:    FileSelection: PGtkFileSelection;
              Mask: string (File mask, such as *.txt)
  Returns:   none

  Populate the directory and file lists according to the given mask
 ------------------------------------------------------------------------------}
procedure PopulateFileAndDirectoryLists(FileSelection: PGtkFileSelection;
  const Mask: string);
var
  Dirs, Files: PGtkCList;
  Text: array [0..1] of Pgchar;
  Info: TSearchRec;
  DirName: PChar;
  Dir: string;
  StrList: TStringListUTF8Fast;
  CurFileMask: String;
  
  procedure Add(List: PGtkCList; const s: string);
  begin
    Text[0] := PChar(s);
    gtk_clist_append(List, Text);
  end;
  
  procedure AddList(List: PGtkCList);
  var
    i: integer;
  begin
    StrList.Sorted := True;
    //DebugLn(['AddList ',StrList.Text]);
    for i:=0 to StrList.Count-1 do
      Add(List, StrList[i]);
    StrList.Sorted := False;
  end;
  
begin
  StrList := TStringListUTF8Fast.Create;
  dirs := PGtkCList(FileSelection^.dir_list);
  files := PGtkCList(FileSelection^.file_list);
  DirName := gtk_file_selection_get_filename(FileSelection);
  if DirName <> nil then begin
    SetString(Dir, DirName, strlen(DirName));
    SetLength(Dir, LastDelimiter(PathDelim,Dir));
    Dir:=SysToUTF8(Dir);
  end else
    Dir := '';
  //DebugLn(['PopulateFileAndDirectoryLists ',Dir]);
  Text[1] := nil;
  gtk_clist_freeze(Dirs);
  gtk_clist_clear(Dirs);
  gtk_clist_freeze(Files);
  gtk_clist_clear(Files);
  { Add all directories }
  Strlist.Add('..'+PathDelim);
  if FindFirstUTF8(AppendPathDelim(Dir)+GetAllFilesMask, faAnyFile and faDirectory,
    Info) = 0
  then begin
    repeat
      if ((Info.Attr and faDirectory) = faDirectory) and (Info.Name <> '.')
      and (Info.Name <> '..') and (Info.Name<>'') then
        StrList.Add(AppendPathDelim(Info.Name));
    until FindNextUTF8(Info) <> 0;
  end;
  FindCloseUTF8(Info);
  AddList(Dirs);
  // add required files
  StrList.Clear;
  CurFileMask:=Mask;
  if CurFileMask='' then CurFileMask:=GetAllFilesMask;
  if FindFirstUTF8(AppendPathDelim(Dir)+GetAllFilesMask, faAnyFile, Info) = 0 then
  begin
    repeat
      if ((Info.Attr and faDirectory) <> faDirectory) then begin
        //debugln('PopulateFileAndDirectoryLists CurFileMask="',CurFileMask,'" Info.Name="',Info.Name,'" ',dbgs(MatchesMaskList(Info.Name,CurFileMask)));
        if (CurFileMask='') or (MatchesMaskList(Info.Name,CurFileMask)) then
        begin
          Strlist.Add(Info.Name);
        end;
      end;
    until FindNextUTF8(Info) <> 0;
  end;
  FindCloseUTF8(Info);
  AddList(Files);
  StrList.Free;
  gtk_clist_thaw(Dirs);
  gtk_clist_thaw(Files);
end;

{------------------------------------------------------------------------------
  Procedure: DeliverMessage
  Params:    Message: the message to process
  Returns:   True if handled

  Generic function which calls the WindowProc if defined, otherwise the
  dispatcher
 ------------------------------------------------------------------------------}
function DeliverMessage(const Target: Pointer; var AMessage): PtrInt;
begin
  if (TLMessage(AMessage).Msg = LM_PAINT) or
     (TLMessage(AMessage).Msg = LM_GTKPAINT) then
    CurrentSentPaintMessageTarget := TObject(Target);

  Result := LCLMessageGlue.DeliverMessage(TObject(Target), AMessage);

  CurrentSentPaintMessageTarget := nil;
end;

{------------------------------------------------------------------------------
  Function: ObjectToGTKObject
  Params: AnObject: A LCL Object
  Returns:  The GTKObject of the given object

  Returns the GTKObject of the given object, nil if no object available
 ------------------------------------------------------------------------------}
function ObjectToGTKObject(const AnObject: TObject): PGtkObject;
var
  handle : HWND;
begin
  Handle := 0;
  if not assigned(AnObject) then
  begin
    assert (false, 'TRACE:  [ObjectToGtkObject] Object not assigned');
  end
  else if (AnObject is TWinControl) then
  begin
    if TWinControl(AnObject).HandleAllocated then
      handle := TWinControl(AnObject).Handle;
  end
  else if (AnObject is TMenuItem) then
  begin 
    if TMenuItem(AnObject).HandleAllocated then
      handle := TMenuItem(AnObject).Handle;
  end
  else if (AnObject is TMenu) then
  begin 
    if TMenu(AnObject).HandleAllocated then
      handle := TMenu(AnObject).Items.Handle;
  end
  else if (AnObject is TCommonDialog) then
  begin
    {if TCommonDialog(AObject).HandleAllocated then }
    handle := TCommonDialog(AnObject).Handle;
  end
  else begin
    //DebugLn(Format('Trace:  [ObjectToGtkObject] Message received with unhandled class-type <%s>', [AnObject.ClassName]));
  end;
  Result := {%H-}PGTKObject(handle);
  if handle = 0 then
    Assert (false, 'Trace:  [ObjectToGtkObject]****** Warning: handle = 0 *******');
end;


(***********************************************************************
  Widget member functions
************************************************************************)

// ----------------------------------------------------------------------
// the main widget is the widget passed as handle to the winAPI
// main data is stored in the fixed form to get a reference to its parent
// ----------------------------------------------------------------------
function GetMainWidget(const Widget: Pointer): Pointer;
begin
  if Widget = nil
  then raise EInterfaceException.Create('GetMainWidget Widget=nil');
  
  Result := g_object_get_data(Widget, 'Main');
  if Result = nil then Result := Widget; // the widget is the main widget itself.
end;

procedure SetMainWidget(const ParentWidget, ChildWidget: Pointer);
begin
  if ParentWidget = nil
  then raise EInterfaceException.Create('SetMainWidget ParentWidget=nil');
  if ChildWidget = nil
  then raise EInterfaceException.Create('SetMainWidget ChildWidget=nil');
  if ParentWidget = ChildWidget
  then raise EInterfaceException.Create('SetMainWidget ParentWidget=ChildWidget');
  if PGtkWidget(ParentWidget)^.parent=ChildWidget
  then raise EInterfaceException.Create('SetMainWidget Parent^.Parent=ChildWidget');

  g_object_set_data(ChildWidget, 'Main', ParentWidget)
end;

{ ------------------------------------------------------------------------------
 Get the fixed widget of a widget.
 Every LCL control with a clientarea, has at least a main widget for the control
 and a fixed widget for the client area. If the Fixed widget is not set, use
 try to get it trough WinWidgetInfo
------------------------------------------------------------------------------ }
//TODO: remove when WinWidgetInfo implementation is complete
function GetFixedWidget(const Widget: Pointer): Pointer;
var
  WidgetInfo: PWinWidgetInfo;
begin
  if Widget = nil
  then raise EInterfaceException.Create('GetFixedWidget Widget=nil');

  WidgetInfo := GetWidgetInfo(Widget);
  if WidgetInfo <> nil
  then Result := WidgetInfo^.ClientWidget
  else Result := nil;
  if Result <> nil then Exit;
  
  Result := g_object_get_data(Widget, 'Fixed');
  // A last resort
  if Result = nil then Result := Widget;
end;

{ ------------------------------------------------------------------------------
 Set the fixed widget of a widget.
 Every LCL control with a clientarea, has at least a main widget for the control
 and a fixed widget for the client area.
------------------------------------------------------------------------------ }
procedure SetFixedWidget(const ParentWidget, FixedWidget: Pointer);
var
  WidgetInfo: PWinWidgetInfo;
begin
  if ParentWidget = nil
  then raise EInterfaceException.Create('SetFixedWidget ParentWidget=nil');
  
  WidgetInfo := GetWidgetInfo(ParentWidget);
  Assert(Assigned(WidgetInfo), 'SetFixedWidget: WidgetInfo = Nil.');
  WidgetInfo^.ClientWidget := FixedWidget;
  //TODO: remove old compatebility
  g_object_set_data(ParentWidget, 'Fixed', FixedWidget)
end;

{-------------------------------------------------------------------------------
  Set the LCLobject which created this widget.

-------------------------------------------------------------------------------}
procedure SetLCLObject(const Widget: Pointer; const AnObject: TObject);
var
  WidgetInfo: PWinWidgetInfo;
begin
  if Widget = nil
  then raise EInterfaceException.Create('SetLCLObject Widget=nil');
  if AnObject = nil
  then raise EInterfaceException.Create('SetLCLObject AnObject=nil');

  WidgetInfo := GetOrCreateWidgetInfo(Widget);
  WidgetInfo^.LCLObject := AnObject;
end;

function GetLCLObject(const Widget: Pointer): TObject;
var
  WidgetInfo: PWinWidgetInfo;
begin
  if Widget = nil
  then raise EInterfaceException.Create('GetLCLObject Widget=nil');

  WidgetInfo := GetWidgetInfo(Widget);
  if WidgetInfo <> nil
  then Result := WidgetInfo^.LCLObject
  else Result := nil;
end;

{-------------------------------------------------------------------------------
  function GetNearestLCLObject(Widget: PGtkWidget): TObject;
  
  Retrieves the LCLObject belonging to the widget. If the widget is created as
  child of a main widget, the parent is queried.
  
  This function probably obsoletes Get/SetMainWidget
-------------------------------------------------------------------------------}
//TODO: check if Get/SetMainWidget is still required
function GetNearestLCLObject(Widget: PGtkWidget): TObject;
begin
  while (Widget<>nil) do begin
    Result:=GetLCLObject(Widget);
    if Result<>nil then exit;
    Widget:=Widget^.Parent;
  end;
  Result:=nil;
end;

function CreateFixedClientWidget(WithWindow: Boolean = True): PGTKWidget;
begin
  Result := gtk_fixed_new();
  if WithWindow then
    gtk_fixed_set_has_window(PGtkFixed(Result), true);
end;

{------------------------------------------------------------------------------
  procedure FixedMoveControl(Parent, Child : PGTKWidget; Left, Top : Longint);
  
  Move a childwidget on a client area (fixed or layout widget).
------------------------------------------------------------------------------}
procedure FixedMoveControl(Parent, Child : PGTKWidget; Left, Top : Longint);
begin
  If GTKWidgetIsA(Parent, GTK_Layout_Get_Type) then begin
    // parent is layout
    gtk_Layout_move(PGtkLayout(Parent), Child, Left, Top)
  end else If GTKWidgetIsA(Parent, GTK_Fixed_Get_Type) then begin
    // parent is fixed
    gtk_fixed_move(PGtkFixed(Parent), Child, gint16(Left), gint16(Top));
  end else begin
    // parent is invalid
    DebugLn('[FixedMoveControl] WARNING: Invalid Fixed Widget');
  end;
end;

{------------------------------------------------------------------------------
  procedure FixedPutControl(Parent, Child : PGTKWIdget; Left, Top : Longint);

  Add a childwidget onto a client area (fixed or layout widget).
------------------------------------------------------------------------------}
procedure FixedPutControl(Parent, Child: PGTKWidget; Left, Top: Longint);

  procedure RaiseInvalidFixedWidget;
  begin
    // this is in a separate procedure for optimisation
    DebugLn('[FixedPutControl] WARNING: Invalid Fixed Widget.',
      ' Parent=',DbgS(Parent),
      ' Child=',DbgS(Child)
      );
  end;

begin
  if GtkWidgetIsA(Parent, gtk_fixed_get_type) then
    gtk_fixed_put(PGtkFixed(Parent), Child, gint16(Left), gint16(Top))
  else
  if GtkWidgetIsA(Parent, gtk_layout_get_type) then
    gtk_layout_put(PGtkLayout(Parent), Child, Left, Top)
  else
    RaiseInvalidFixedWidget;
end;

function GetWinControlWidget(Child: PGtkWidget): PGtkWidget;
// return the first widget, which is associated with a TWinControl handle
var
  LCLParent: TObject;
begin
  Result:=nil;
  LCLParent:=GetNearestLCLObject(Child);
  if (LCLParent is TWinControl) then
    Result:={%H-}PGtkWidget(TWinControlAccess(LCLParent).WindowHandle);
end;

function GetWinControlFixedWidget(Child: PGtkWidget): PGtkWidget;
begin
  Result:=GetWinControlWidget(Child);
  if Result=nil then exit;
  Result:=GetFixedWidget(Result);
end;

function FindFixedChildListItem(ParentFixed: PGtkFixed; Child: PGtkWidget): PGList;
begin
  Result:=ParentFixed^.children;
  while (Result<>nil) do begin
    if (Result^.Data<>nil) and (PGtkFixedChild(Result^.Data)^.Widget=Child) then
      exit;
    Result:=Result^.Next;
  end;
end;

function FindFixedLastChildListItem(ParentFixed: PGtkFixed): PGList;
begin
  Result:=g_list_last(ParentFixed^.children);
end;

function GetFixedChildListWidget(Item: PGList): PGtkWidget;
begin
  Result:=PGtkFixedChild(Item^.Data)^.Widget;
end;

{------------------------------------------------------------------------------
  procedure MoveGListLinkBehind(First, Item, After: PGList);

  Move the list item 'Item' behind the list item 'After'.
  If After=nil then insert as first item.
------------------------------------------------------------------------------}
procedure MoveGListLinkBehind(First, Item, After: PGList);
var
  Data: Pointer;
  NewPos: Integer;
begin
  if (Item=After) or (Item^.Next=After) then exit;
  if (g_list_position(First,Item)<0) then
    RaiseGDBException('MoveGListLinkBehind Item not found');
  if (After<>nil) and (g_list_position(First,After)<0) then
    RaiseGDBException('MoveGListLinkBehind After not found');
  Data:=Item^.Data;
  g_list_remove_link(First,Item);
  if After<>nil then begin
    NewPos:=g_list_position(First,After)+1;
  end else begin
    NewPos:=0;
  end;
  g_list_insert(First,Data,NewPos);
end;

procedure MoveGListLink(First: PGList; FromIndex, ToIndex: integer);
var
  Item: PGList;
  InsertAfter: PGList;
  i: Integer;
begin
  if (FromIndex=ToIndex) then exit;
  Item:=First;
  i:=0;
  while (i<FromIndex) do begin
    Item:=Item^.next;
    inc(i);
  end;
  // unbind
  if Item^.next<>nil then Item^.next^.prev:=Item^.prev;
  if Item^.prev<>nil then Item^.prev^.next:=Item^.next;
  Item^.next:=nil;
  Item^.prev:=nil;
  // insert
  if ToIndex=0 then begin
    Item^.next:=First;
    First^.prev:=Item;
  end else begin
    i:=0;
    InsertAfter:=First;
    while (i<ToIndex-1) do begin
      if InsertAfter^.next=nil then break;
      InsertAfter:=InsertAfter^.next;
      inc(i);
    end;
    Item^.prev:=InsertAfter;
    Item^.next:=InsertAfter^.next;
    InsertAfter^.next:=Item;
    if Item^.next<>nil then Item^.next^.prev:=Item;
  end;
end;

{------------------------------------------------------------------------------
  function GetControlWindow(Widget: Pointer) : PGDKWindow;

  Get the gdkwindow of a widget.
------------------------------------------------------------------------------}
function GetControlWindow(Widget: Pointer) : PGDKWindow;
begin
  if Widget <> nil then 
  begin
    If GTKWidgetIsA(PGTKWidget(Widget), GTK_Layout_Get_Type) then
      Result := PGtkLayout(Widget)^.bin_window
    else
      Result := PGTKWidget(Widget)^.Window;
    if (Result=nil) and (GTK_WIDGET_NO_WINDOW(Widget)) then
      Result:=gtk_widget_get_parent_window(Widget);
  end else
    RaiseGDBException('GetControlWindow Widget=nil');
end;


{------------------------------------------------------------------------------
  function CreateWidgetInfo(const AWidget: Pointer): PWidgetInfo;

 Creates a WidgetInfo structure for the given widget
 Info needed by the API of a HWND (=Widget)

 This structure obsoletes all other object data, like
   "core-child", "fixed", "class"
 ------------------------------------------------------------------------------}
function CreateWidgetInfo(const AWidget: Pointer): PWidgetInfo;
begin
  if AWidget = nil then
    Exit(nil);
  New(Result);
  FillChar(Result^, SizeOf(Result^), 0);
  g_object_set_data(AWidget, 'widgetinfo', Result);
end;

function CreateWidgetInfo(const AWidget: Pointer; const AObject: TObject;
  const AParams: TCreateParams): PWidgetInfo;
begin
  Result := CreateWidgetInfo(AWidget);
  if Result = nil then Exit;
  
  Result^.LCLObject := AObject;
  Result^.FirstPaint := False;
  // in most cases the created widget is the core widget so default to it
  Result^.CoreWidget := AWidget;
  Result^.Style := AParams.Style;
  Result^.ExStyle := AParams.ExStyle;
  Result^.WndProc := {%H-}PtrUInt(AParams.WindowClass.lpfnWndProc);
end;

function GetWidgetInfo(const AWidget: Pointer): PWidgetInfo;
var
  MainWidget: PGtkObject;
begin
  if AWidget = nil then Exit(nil);
  MainWidget := GetMainWidget(AWidget);
  Result := g_object_get_data(PGObject(MainWidget), 'widgetinfo');
end;

function GetOrCreateWidgetInfo(const AWidget: Pointer): PWidgetInfo;
var
  MainWidget: PGtkObject;
begin
  if AWidget = nil then Exit(nil);
  MainWidget := GetMainWidget(AWidget);
  Result := g_object_get_data(PGObject(MainWidget), 'widgetinfo');
  if Assigned(Result) then Exit;
  Result := CreateWidgetInfo(MainWidget);
  //DebugLn('GetOrCreateWidgetInfo: MainWidget info was created causing a memory leak.');
  // use the main widget as default
  Result^.CoreWidget := PGtkWidget(MainWidget);
end;

procedure FreeWidgetInfo(AWidget: Pointer);
var
  Info: PWidgetInfo;
begin
  if AWidget = nil then Exit;
  //DebugLn(['FreeWidgetInfo ',GetWidgetDebugReport(AWidget)]);
  Info := g_object_get_data(AWidget, 'widgetinfo');
  if Info = nil then Exit;

  if Info^.DoubleBuffer <> nil then
    gdk_pixmap_unref(Info^.DoubleBuffer);

  if (Info^.UserData <> nil) and (Info^.DataOwner) then begin
    FreeMem(Info^.UserData);
    //Info^.UserData := nil; // see below the whole memory is cleared by Fillchar
  end;
  g_object_set_data(AWidget,'widgetinfo',nil);

  // Set WidgetInfo memory to nil. This will expose bugs that use widgetinfo after
  // it has been freed and is still referenced by something!
  FillChar(Info^, SizeOf(TWidgetInfo), 0);

  Dispose(Info);
  //DebugLn(['FreeWidgetInfo END']);
end;

{-------------------------------------------------------------------------------
  procedure DestroyWidget(Widget: PGtkWidget);

  - sends LM_DESTROY
  - frees the WidgetInfo
  - destroys the widget in the gtk
  
  IMPORTANT:
    The above order must be kept, to avoid callbacks working with dangling
    pointers.
    
  Some widgets have a LM_DESTROY set, so if the gtk or some other code
  destroys those widget, the above is done in gtkdestroyCB.
-------------------------------------------------------------------------------}
procedure DestroyWidget(Widget: PGtkWidget);
var
  Info: PWidgetInfo;
  AWinControl: TWinControl;
  Mess: TLMessage;
begin
  //DebugLn(['DestroyWidget A ',GetWidgetDebugReport(Widget)]);
  {$IFDEF DebugLCLComponents}
  if DebugGtkWidgets.FindInfo(Widget)=nil then
    DebugLn(['DestroyWidget ',GetWidgetDebugReport(Widget)]);
  {$ENDIF}
  Info:=GetWidgetInfo(Widget);
  if Info<>nil then begin
    if (Info^.LCLObject is TWinControl) then begin
      AWinControl:=TWinControl(Info^.LCLObject);
      if AWinControl.HandleAllocated
      and ({%H-}PGtkWidget(AWinControl.Handle)=Widget) then begin
        // send the LM_DESTROY message before destroying the widget
        FillChar(Mess{%H-},SizeOf(Mess),0);
        Mess.msg := LM_DESTROY;
        DeliverMessage(Info^.LCLObject, Mess);
      end;
    end;
    FreeWidgetInfo(Widget);
  end;
  {$IFDEF DebugLCLComponents}
  DebugGtkWidgets.MarkDestroyed(Widget);
  {$ENDIF}
  gtk_widget_destroy(Widget);
  //DebugLn(['DestroyWidget B']);
end;

function IsTTabControl(AWidget: PGtkWidget): Boolean;
var
  WidgetInfo: PWidgetInfo;
begin
  if AWidget = nil then
    exit(False);
  WidgetInfo := GetWidgetInfo(AWidget);
  if (WidgetInfo = nil) or (WidgetInfo^.CoreWidget = nil) then
    exit(False);
  Result := g_object_get_data(PGObject(WidgetInfo^.CoreWidget),'lcl_ttabcontrol') <> nil;
end;

{------------------------------------------------------------------------------
  UpdateNoteBookClientWidget
  Params: ANoteBook: TObject

  This procedure updates the 'Fixed' object data.
  * obsolete *
------------------------------------------------------------------------------}
procedure UpdateNoteBookClientWidget(ANoteBook: TObject);
var
  ClientWidget: PGtkWidget;
  NoteBookWidget: PGtkNotebook;
begin
  if not TCustomTabControl(ANoteBook).HandleAllocated then exit;
  NoteBookWidget := {%H-}PGtkNotebook(TCustomTabControl(ANoteBook).Handle);
  ClientWidget := nil;
  SetFixedWidget(NoteBookWidget, ClientWidget);
end;

{-------------------------------------------------------------------------------
  function GetGtkNoteBookPageCount(ANoteBookWidget: PGtkNoteBook): integer;

  Returns the number of pages in a PGtkNotebook
-------------------------------------------------------------------------------}
function GetGtkNoteBookPageCount(ANoteBookWidget: PGtkNoteBook): integer;
var
  AListItem: PGList;
begin
  Result:=0;
  if ANoteBookWidget=nil then exit;
  AListItem:=ANoteBookWidget^.children;
  while AListItem<>nil do begin
    inc(Result);
    AListItem:=AListItem^.Next;
  end;
end;

{-------------------------------------------------------------------------------
  method UpdateNotebookPageTab
  Params: ANoteBook: TCustomTabControl; APage: TCustomPage
  Result: none

  Updates the tab of a page of a notebook. This contains the image to the left
  side, the label, the close button, the menu image and the menu label.
-------------------------------------------------------------------------------}
procedure UpdateNotebookPageTab(ANoteBook, APage: TObject);
var
  TheNoteBook: TCustomTabControl;
  ThePage: TCustomPage;

  NoteBookWidget: PGtkWidget;  // the notebook
  PageWidget: PGtkWidget;      // the page (content widget)
  TabWidget: PGtkWidget;       // the tab (hbox containing a pixmap, a label
                               //          and a close button)
  TabImageWidget: PGtkWidget;  // the icon widget in the tab (a fixed widget)
  TabLabelWidget: PGtkWidget;  // the label in the tab
  TabCloseBtnWidget: PGtkWidget;// the close button in the tab
  TabCloseBtnImageWidget: PGtkWidget; // the pixmap in the close button
  MenuWidget: PGtkWidget;      // the popup menu (hbox containing a pixmap and
                               // a label)
  MenuImageWidget: PGtkWidget; // the icon widget in the popup menu item (a fixed widget)
  MenuLabelWidget: PGtkWidget; // the label in the popup menu item

  procedure UpdateTabImage;
  var
    HasIcon: Boolean;
    IconSize: Types.TSize;
    ImageIndex: Integer;
  begin
    HasIcon:=false;
    IconSize:=Size(0,0);
    ImageIndex := TheNoteBook.GetImageIndex(ThePage.PageIndex);
    if (TheNoteBook.Images<>nil)
    and (ImageIndex >= 0)
    and (ImageIndex < TheNoteBook.Images.Count) then
    begin
      // page has valid image
      IconSize := TheNoteBook.Images.SizeForPPI[TheNoteBook.ImagesWidth, TheNoteBook.Font.PixelsPerInch];
      HasIcon := (IconSize.cx>0) and (IconSize.cy>0);
    end;

    if HasIcon then
    begin
      // page has an image
      if TabImageWidget <> nil then
      begin
        // there is already an icon widget for the image in the tab
        // -> resize the icon widget
        gtk_widget_set_usize(TabImageWidget,IconSize.cx,IconSize.cy);
      end else
      begin
        // there is no pixmap for the image in the tab
        // -> insert one ot the left side of the label
        TabImageWidget := gtk_label_new(#0);
        g_signal_connect(PgtkObject(TabImageWidget), 'expose_event',
                           TGTKSignalFunc(@PageIconWidgetExposeAfter), ThePage);
        g_object_set_data(PGObject(TabWidget), 'TabImage', TabImageWidget);
        gtk_widget_set_usize(TabImageWidget, IconSize.cx, IconSize.cy);
        gtk_widget_show(TabImageWidget);
        gtk_box_pack_start_defaults(PGtkBox(TabWidget), TabImageWidget);
        gtk_box_reorder_child(PGtkBox(TabWidget), TabImageWidget, 0);
      end;
      if MenuImageWidget<>nil then
      begin
        // there is already an icon widget for the image in the menu
        // -> resize the icon widget
        gtk_widget_set_usize(MenuImageWidget, IconSize.cx, IconSize.cy);
      end else
      begin
        // there is no icon widget for the image in the menu
        // -> insert one at the left side of the label
        MenuImageWidget:=gtk_label_new(#0);
        g_signal_connect_after(PgtkObject(MenuImageWidget), 'expose_event',
                          TGTKSignalFunc(@PageIconWidgetExposeAfter), ThePage);
        gtk_widget_set_usize(MenuImageWidget,IconSize.cx,IconSize.cy);
        g_object_set_data(PGObject(MenuWidget),'TabImage',MenuImageWidget);
        gtk_widget_show(MenuImageWidget);
        gtk_box_pack_start_defaults(PGtkBox(MenuWidget),MenuImageWidget);
        gtk_box_reorder_child(PGtkBox(MenuWidget),MenuImageWidget,0);
      end;
    end else
    begin
      // page does not have an image
      if TabImageWidget<>nil then
      begin
        // there is a pixmap for an old image in the tab
        // -> remove the icon widget
        DestroyWidget(TabImageWidget);
        g_object_set_data(PGObject(TabWidget), 'TabImage', nil);
        TabImageWidget:=nil;
      end;
      if MenuImageWidget<>nil then
      begin
        // there is a pixmap for an old image in the menu
        // -> remove the icon widget
        DestroyWidget(MenuImageWidget);
        g_object_set_data(PGObject(MenuWidget), 'TabImage', nil);
        MenuImageWidget:=nil;
      end;
    end;
  end;

  procedure UpdateTabLabel;
  var
    ACaption: String;
  begin
    ACaption := ThePage.Caption;
    GTK2WidgetSet.SetLabelCaption(PGtkLabel(TabLabelWidget), ACaption);

    if MenuLabelWidget <> nil then
      GTK2WidgetSet.SetLabelCaption(PGtkLabel(MenuLabelWidget), ACaption);
  end;

  procedure UpdateTabCloseBtn;
  var
    style: PGtkRcStyle;
  begin
    //debugln('UpdateTabCloseBtn ',dbgs(nboShowCloseButtons in TheNotebook.Options),' ',dbgs(Img<>nil));
    if (nboShowCloseButtons in TheNotebook.Options) then
    begin
      // close buttons enabled
      if TabCloseBtnWidget = nil then
      begin
        // there is no close button yet
        // -> add one to the right side of the label in the tab
        TabCloseBtnWidget := gtk_button_new;
        gtk_button_set_relief(PGtkButton(TabCloseBtnWidget), GTK_RELIEF_NONE);
        gtk_button_set_focus_on_click(PGtkButton(TabCloseBtnWidget), False);
        style := gtk_widget_get_modifier_style(TabCloseBtnWidget);
        style^.xthickness := 0;
        style^.ythickness := 0;
        gtk_widget_modify_style(TabCloseBtnWidget, style);

        g_object_set_data(PGObject(TabWidget), 'TabCloseBtn',
                            TabCloseBtnWidget);
        // put a pixmap into the button
        TabCloseBtnImageWidget:=gtk_image_new_from_stock(GTK_STOCK_CLOSE, GTK_ICON_SIZE_MENU);
        g_object_set_data(PGObject(TabCloseBtnWidget),'TabCloseBtnImage',
                            TabCloseBtnImageWidget);
        gtk_widget_show(TabCloseBtnImageWidget);
        gtk_container_add(PGtkContainer(TabCloseBtnWidget),
                          TabCloseBtnImageWidget);
        gtk_widget_show(TabCloseBtnWidget);
        g_signal_connect(PGtkObject(TabCloseBtnWidget), 'clicked',
          TGTKSignalFunc(@gtkNoteBookCloseBtnClicked), APage);
        gtk_box_pack_start(PGtkBox(TabWidget), TabCloseBtnWidget, False, False, 0);
      end;
    end else begin
      // close buttons disabled
      if TabCloseBtnWidget<>nil then begin
        // there is a close button
        // -> remove it
        g_object_set_data(PGObject(TabWidget), 'TabCloseBtn',
                            nil);
        DestroyWidget(TabCloseBtnWidget);
        TabCloseBtnWidget:=nil;
      end;
    end;
  end;

begin
  ThePage := TCustomPage(APage);
  TheNoteBook := TCustomTabControl(ANoteBook);
  if (APage=nil) or (not ThePage.HandleAllocated) then exit;
  if TheNoteBook=nil then begin
    TheNoteBook:=TCustomTabControl(ThePage.Parent);
    if TheNoteBook=nil then exit;
  end;
  NoteBookWidget:={%H-}PGtkWidget(TWinControl(TheNoteBook).Handle);
  PageWidget:={%H-}PGtkWidget(TWinControl(ThePage).Handle);

  // get the tab container and the tab components: pixmap, label and closebtn
  TabWidget:=gtk_notebook_get_tab_label(PGtkNoteBook(NotebookWidget),
                                        PageWidget);
  if TabWidget<>nil then begin
    TabImageWidget:=g_object_get_data(PGObject(TabWidget), 'TabImage');
    TabLabelWidget:=g_object_get_data(PGObject(TabWidget), 'TabLabel');
    TabCloseBtnWidget:=g_object_get_data(PGObject(TabWidget),'TabCloseBtn');
  end else begin
    TabImageWidget:=nil;
    TabLabelWidget:=nil;
    TabCloseBtnWidget:=nil;
  end;

  // get the menu container and its components: pixmap and label
  MenuWidget:=gtk_notebook_get_menu_label(PGtkNoteBook(NotebookWidget),
                                          PageWidget);
  if MenuWidget<>nil then begin
    MenuImageWidget:=g_object_get_data(PGObject(MenuWidget), 'TabImage');
    MenuLabelWidget:=g_object_get_data(PGObject(MenuWidget), 'TabMenuLabel');
  end else begin
    MenuImageWidget:=nil;
    MenuLabelWidget:=nil;
  end;

  UpdateTabImage;
  UpdateTabLabel;
  UpdateTabCloseBtn;
end;

procedure UpdateNotebookTabFont(APage: TWinControl; AFont: TFont);
var
  NoteBookWidget: PGtkWidget;
  PageWidget: PGtkWidget;
  TabWidget: PGtkWidget;
  TabLabelWidget: PGtkWidget;
begin

  NoteBookWidget:={%H-}PGtkWidget((APage.Parent).Handle);
  PageWidget:={%H-}PGtkWidget(APage.Handle);
  TabWidget:=gtk_notebook_get_tab_label(PGtkNoteBook(NotebookWidget),
                                        PageWidget);
  if TabWidget<>nil then
    TabLabelWidget:=g_object_get_data(PGObject(TabWidget), 'TabLabel')
  else
    TabLabelWidget:=nil;

  // set new font to page
  Gtk2WidgetSet.SetWidgetFont(PageWidget, AFont);
  Gtk2WidgetSet.SetWidgetColor(PageWidget, AFont.Color, clNone,
                            [GTK_STATE_NORMAL,GTK_STATE_ACTIVE,
                             GTK_STATE_PRELIGHT,GTK_STATE_SELECTED,
                             GTK_STYLE_TEXT]);

  // set new font to tab

  if TabLabelWidget = nil then
    exit;

  Gtk2WidgetSet.SetWidgetFont(TabLabelWidget, AFont);
  Gtk2WidgetSet.SetWidgetColor(TabLabelWidget, AFont.Color, clNone,
    [GTK_STATE_NORMAL,GTK_STATE_ACTIVE,
    GTK_STATE_PRELIGHT,GTK_STATE_SELECTED]);
end;


{-------------------------------------------------------------------------------
  GetWidgetScreenPos

  Returns the absolute left top position of a widget on the screen.
-------------------------------------------------------------------------------}
function GetWidgetOrigin(TheWidget: PGtkWidget): TPoint;
var
  TheWindow: PGdkWindow;
  {$IFDEF RaiseExceptionOnNilPointers}
  LCLObject: TObject;
  {$ENDIF}
begin
  TheWindow:=GetControlWindow(TheWidget);
  if TheWindow<>nil then begin
    BeginGDKErrorTrap;
    gdk_window_get_origin(TheWindow,@Result.X,@Result.Y);
    EndGDKErrorTrap;
  end else begin
    {$IFDEF RaiseExceptionOnNilPointers}
    LCLobject:=GetLCLObject(TheWidget);
    DbgOut('GetWidgetOrigin ');
    if LCLObject=nil then
      DbgOut(' LCLObject=nil')
    else if LCLObject is TControl then
      DbgOut(' LCLObject=',TControl(LCLObject).Name,':',TControl(LCLObject).ClassName)
    else
      DbgOut(' LCLObject=',TControl(LCLObject).ClassName);
    DebugLn('');
    RaiseGDBException('GetWidgetOrigin Window=nil');
    {$ENDIF}
    Result.X:=0;
    Result.Y:=0;
  end;

  {gtk2 < 2.10 sometimes raises assertion here. That's because of gtk2 bug and
   cannot be fixed by us.
   http://gitorious.org/gsettings-gtk/gtk/blobs/gsettings-gtk/ChangeLog.pre-2-10
   look for gtk_widget_get_parent_window() in changes.}

  // check if the gdkwindow is the clientwindow of the parent
  if gtk_widget_get_parent_window(TheWidget)=TheWindow then begin
    // the widget is using its parent window
    // -> adjust the coordinates
    inc(Result.X,TheWidget^.Allocation.X);
    inc(Result.Y,TheWidget^.Allocation.Y);
  end;
end;

{-------------------------------------------------------------------------------
  GetWidgetClientScreenPos

  Returns the absolute left top position of a widget's client area
  on the screen.
-------------------------------------------------------------------------------}
function GetWidgetClientOrigin(TheWidget: PGtkWidget): TPoint;

  procedure GetNoteBookClientOrigin(NBWidget: PGtkNotebook);
  var
    PageIndex: LongInt;
    PageWidget: PGtkWidget;
    ClientWidget: PGTKWidget;
    FrameBorders: TRect;
  begin
    // get current page
    PageIndex:=gtk_notebook_get_current_page(NBWidget);
    if PageIndex>=0 then
      PageWidget:=gtk_notebook_get_nth_page(NBWidget,PageIndex)
    else
      PageWidget:=nil;
      
    // get client widget of page
    if (PageWidget<>nil) then
      ClientWidget:=GetFixedWidget(PageWidget)
    else
      ClientWidget:=nil;
      
    // Be careful while using ClientWidget here, it may be nil
    if (ClientWidget<>nil) and (ClientWidget^.window<>nil) then
    begin
      // get the position of the current page
      gdk_window_get_origin(ClientWidget^.window,@Result.X,@Result.Y);
      if GTK_WIDGET_NO_WINDOW(ClientWidget)
      then begin
        Inc(Result.X, ClientWidget^.Allocation.X);
        Inc(Result.Y, ClientWidget^.Allocation.Y);
      end;
    end
    else
    begin
      // use defaults
      Result:=GetWidgetOrigin(TheWidget);
      FrameBorders:=GetStyleNotebookFrameBorders;
      GetWidgetClientOrigin.x:=Result.x+FrameBorders.Left;
      GetWidgetClientOrigin.y:=Result.y+FrameBorders.Top;
    end;
  end;

var
  ClientWidget: PGtkWidget;
  ClientWindow: PGdkWindow;
begin
  ClientWidget := GetFixedWidget(TheWidget);
  if ClientWidget <> TheWidget then
  begin
    ClientWindow := GetControlWindow(ClientWidget);
    if ClientWindow <> nil then
    begin
      {$IFDEF DebugGDK}
      BeginGDKErrorTrap;
      {$ENDIF}
      gdk_window_get_origin(ClientWindow, @Result.X, @Result.Y);
      if GTK_WIDGET_NO_WINDOW(ClientWidget) then
      begin
        Inc(Result.X, ClientWidget^.Allocation.X);
        Inc(Result.Y, ClientWidget^.Allocation.Y);
      end;
      {$IFDEF DebugGDK}
      EndGDKErrorTrap;
      {$ENDIF}
      exit;
    end;
  end
  else
  if GtkWidgetIsA(TheWidget,GTK_TYPE_NOTEBOOK) then
  begin
    GetNoteBookClientOrigin(PGtkNoteBook(TheWidget));
    Exit;
  end;
  Result := GetWidgetOrigin(TheWidget);
end;

function GetWidgetClientRect(TheWidget: PGtkWidget): TRect;
var
  Widget, ClientWidget: PGtkWidget;
  AChild: PGtkWidget;

  procedure GetNoteBookClientRect(NBWidget: PGtkNotebook);
  var
    PageIndex: LongInt;
    PageWidget: PGtkWidget;
    FrameBorders: TRect;
    aWidth: LongInt;
    aHeight: LongInt;
  begin
    // get current page
    PageIndex:=gtk_notebook_get_current_page(NBWidget);
    if PageIndex>=0 then
      PageWidget:=gtk_notebook_get_nth_page(NBWidget,PageIndex)
    else
      PageWidget:=nil;
    if (PageWidget<>nil) and GTK_WIDGET_RC_STYLE(PageWidget)
    and ((PageWidget^.Allocation.Width>1) or (PageWidget^.Allocation.Height>1))
    then begin
      // get the size of the current page
      Result.Right:=PageWidget^.Allocation.Width;
      Result.Bottom:=PageWidget^.Allocation.Height;
      //DebugLn(['GetNoteBookClientRect using pagewidget: ',GetWidgetDebugReport(Widget),' ARect=',dbgs(aRect)]);
    end else begin
      // use defaults
      FrameBorders:=GetStyleNotebookFrameBorders;
      aWidth:=Widget^.allocation.width;
      aHeight:=Widget^.allocation.height;
      Result:=Rect(0,0,
         Max(0,AWidth-FrameBorders.Left-FrameBorders.Right),
         Max(0,aHeight-FrameBorders.Top-FrameBorders.Bottom));
      //DebugLn(['GetNoteBookClientRect using defaults: ',GetWidgetDebugReport(Widget),' ARect=',dbgs(aRect),' Frame=',dbgs(FrameBorders)]);
    end;
  end;
begin
  Result := Rect(0, 0, 0, 0);
  Widget := TheWidget;
  ClientWidget := GetFixedWidget(Widget);
  if (ClientWidget <> nil) then
    Widget := ClientWidget;
  if (Widget <> nil) then
  begin
    Result.Right:=Widget^.Allocation.Width;
    Result.Bottom:=Widget^.Allocation.Height;
    if GtkWidgetIsA(Widget,gtk_notebook_get_type) then
      GetNoteBookClientRect(PGtkNoteBook(Widget))
    else
    if GTK_IS_SCROLLED_WINDOW(Widget) and GTK_IS_BIN(Widget) then
    begin
      AChild := gtk_bin_get_child(PGtkBin(Widget));
      if (AChild <> nil) and GTK_IS_TREE_VIEW(AChild) then
      begin
        Result.Right := AChild^.allocation.width;
        Result.Bottom := AChild^.allocation.height;
      end;
    end;
  end;
  {$IfDef VerboseGetClientRect}
  if ClientWidget<>nil then begin
    DebugLn('GetClientRect  Widget=',GetWidgetDebugReport(PgtkWidget(Handle)),
       ' Client=',DbgS(ClientWidget),WidgetFlagsToString(ClientWidget),
       ' WindowSize=',dbgs(Result.Right),',',dbgs(Result.Bottom),
       ' Allocation=',dbgs(ClientWidget^.Allocation.Width),',',dbgs(ClientWidget^.Allocation.Height)
       );
  end else begin
    DebugLn('GetClientRect  Widget=',GetWidgetDebugReport(PgtkWidget(Handle)),
       ' Client=',DbgS(ClientWidget),WidgetFlagsToString(ClientWidget),
       ' WindowSize=',dbgs(Result.Right),',',dbgs(Result.Bottom),
       ' Allocation=',dbgs(Widget^.Allocation.Width),',',dbgs(Widget^.Allocation.Height)
       );
  end;
  if GetLCLObject(Widget) is TCustomPage then begin
    DebugLn(['TGtk2WidgetSet.GetClientRect Rect=',dbgs(Result),' ',GetWidgetDebugReport(Widget)]);
  end;
  {$EndIf}
end;

{-------------------------------------------------------------------------------
  TranslateGdkPointToClientArea

  Translates SourcePos relative to SourceWindow to a coordinate relative to the
  client area of the LCL WinControl.
-------------------------------------------------------------------------------}
function TranslateGdkPointToClientArea(SourceWindow: PGdkWindow;
  SourcePos: TPoint; DestinationWidget: PGtkWidget): TPoint;
var
  SrcWindowOrigin: TPoint;
  ClientAreaWindowOrigin: TPoint;
  Src2ClientAreaVector: TPoint;
begin
  if SourceWindow = nil then
  begin
    {$IFDEF RaiseExceptionOnNilPointers}
    RaiseGDBException('TranslateGdkPointToClientArea Window=nil');
    {$ENDIF}
    DebugLn('WARNING: TranslateGdkPointToClientArea SourceWindow=nil');
  end;
  gdk_window_get_origin(SourceWindow, @SrcWindowOrigin.X, @SrcWindowOrigin.Y);

  ClientAreaWindowOrigin := GetWidgetClientOrigin(DestinationWidget);
  Src2ClientAreaVector.X := ClientAreaWindowOrigin.X - SrcWindowOrigin.X;
  Src2ClientAreaVector.Y := ClientAreaWindowOrigin.Y - SrcWindowOrigin.Y;
  Result.X := SourcePos.X - Src2ClientAreaVector.X;
  Result.Y := SourcePos.Y - Src2ClientAreaVector.Y;
end;

function SubtractScoll(AWidget: PGtkWidget; APosition: TPoint): TPoint;
begin
  Result := APosition;
  AWidget := g_object_get_data(PGObject(AWidget), odnScrollArea);
  if GTK_IS_SCROLLED_WINDOW(AWidget) then
  begin
    with gtk_scrolled_window_get_hadjustment(PGtkScrolledWindow(AWidget))^ do
      dec(Result.x, Trunc(value - lower));
    with gtk_scrolled_window_get_vadjustment(PGtkScrolledWindow(AWidget))^ do
      dec(Result.y, Trunc(value - lower));
  end;
end;

procedure IncreaseMouseCaptureIndex;
begin
  if MouseCaptureIndex<$ffffffff then
    inc(MouseCaptureIndex)
  else
    MouseCaptureIndex:=0;
end;

function GetDefaultMouseCaptureWidget(Widget: PGtkWidget): PGtkWidget;
var
  WidgetInfo: PWinWidgetInfo;
  LCLObject: TObject;
  CanCapture: Boolean;
  Parent: TWinControl;
  {$IFDEF VerboseMouseCapture}
  CurrentGrab: PGtkWidget;
  GrabInfo: PWinWidgetInfo;
  {$ENDIF}
begin
  Result:=nil;
  if Widget=nil then exit;
  if GtkWidgetIsA(Widget,GTKAPIWidget_Type) then
  begin
    WidgetInfo:=GetWidgetInfo(Widget);
    if WidgetInfo<>nil then
      Result:=WidgetInfo^.CoreWidget;
    exit;
  end;
  LCLObject:=GetNearestLCLObject(Widget);

  if LCLObject=nil then exit;

  CanCapture := TWinControl(LCLObject).HandleAllocated and
    not (csDesigning in TWinControl(LCLObject).ComponentState);

  if CanCapture then
  begin
    if GTK_IS_NOTEBOOK({%H-}PGtkWidget(TWinControl(LCLObject).Handle)) then
      exit;
    Parent := TWinControl(LCLObject).Parent;
    if Assigned(Parent) and GTK_IS_NOTEBOOK({%H-}PGtkWidget(Parent.Handle)) then
      exit;
    WidgetInfo:=GetWidgetInfo({%H-}PGtkWidget(TWinControl(LCLObject).Handle));
    if WidgetInfo <> nil then
    begin
      {$IFDEF VerboseMouseCapture}
      CurrentGrab := gtk_grab_get_current;
      debugln(['GetDefaultMouseCaptureWidget: ',TWinControl(LCLObject).ClassName,
        ' core ',dbghex({%H-}PtrUInt(WidgetInfo^.CoreWidget)),
        ' client ',dbghex({%H-}PtrUInt(WidgetInfo^.ClientWidget)),
        ' currentgrab ', dbghex({%H-}PtrUInt(CurrentGrab))]);
      if CurrentGrab <> nil then
      begin
        GrabInfo := GetWidgetInfo(CurrentGrab);
        if GrabInfo <> nil then
          debugln('GetDefaultMouseCaptureWidget: CURRENT GRAB ',GrabInfo^.LCLObject.ClassName);
      end;
      {$ENDIF}
      if WidgetInfo^.ClientWidget <> nil then
      begin
        if TWinControl(LCLObject) is TCustomForm then
          Result := WidgetInfo^.ClientWidget
        else
          Result := WidgetInfo^.CoreWidget;
      end else
      if GTK_IS_SCROLLED_WINDOW(Widget) and (GTK_IS_BIN(Widget)) then
      begin
        {$IFDEF VerboseMouseCapture}
        debugln('GetDefaultMouseCaptureWidget: **',TWinControl(LCLObject).ClassName,' grabbing viewport ...');
        {$ENDIF}
        Result := gtk_bin_get_child(PGtkBin(Widget));
      end;
    end;
  end;
end;

{------------------------------------------------------------------------------
  procedure ReleaseMouseCapture;

  If the current mouse capture was captured by the LCL or the gtk intf, release
  the capture. Don't release mouse captures of the gtk, because captures must
  be balanced and this is already done by the gtk.
 ------------------------------------------------------------------------------}
procedure ReleaseMouseCapture;
var
  OldMouseCaptureWidget: PGtkWidget;
  Info: PWidgetInfo;
begin
  OldMouseCaptureWidget := gtk_grab_get_current;
  if (OldMouseCaptureWidget=nil) and (MouseCaptureWidget=nil) then exit;
  {$IFDEF VerboseMouseCapture}
  DebugLn('ReleaseMouseCapture gtk_grab=[',GetWidgetDebugReport(OldMouseCaptureWidget),'] MouseCaptureWidget=[',GetWidgetDebugReport(MouseCaptureWidget),']');
  {$ENDIF}
  Info := GetWidgetInfo(OldMouseCaptureWidget);
  if (Info <> nil) and (Info^.CoreWidget <> nil) then
  begin
    if GtkWidgetIsA(Info^.CoreWidget, gtk_list_get_type) then
    begin
      // Paul Ishenin:
      // listbox grabs pointer and other control for itself, when we click on listbox item
      // also it changes its state to drag_selection
      // this is not expected in LCL and as result cause bugs, such as 7892
      // so we need end drag selection manually
      OldMouseCaptureWidget := Info^.CoreWidget;
      gtk_list_end_drag_selection(PGtkList(OldMouseCaptureWidget));
      exit;
    end;
  end;
  if MouseCaptureWidget<>nil then begin
    {$IfDef VerboseMouseCapture}
    DebugLn('TGtk2WidgetSet.ReleaseMouseCapture gtk_grab_remove=[',GetWidgetDebugReport(OldMouseCaptureWidget),']');
    {$EndIf}
    OldMouseCaptureWidget:=MouseCaptureWidget;
    MouseCaptureWidget:=nil;
    gtk_grab_remove(OldMouseCaptureWidget);
  end;
  // tell the LCL
  SetCaptureControl(nil);
end;

procedure ReleaseCaptureWidget(Widget : PGtkWidget);
begin
  if (Widget=nil)
  or ((MouseCaptureWidget<>Widget) and (MouseCaptureWidget<>Widget^.parent))
  then
    exit;
  {$IFDEF VerboseMouseCapture}
  DebugLn('ReleaseCaptureWidget ',GetWidgetDebugReport(Widget));
  {$ENDIF}
  ReleaseMouseCapture;
end;

function GetGtkWindowGroup(Widget: PGtkWidget): PGtkWindowGroup;
var
  toplevel: PGtkWidget;
begin
  Result := nil;
  if gtk_window_get_group = nil then
    exit;
  if Widget<>nil then
    toplevel:=gtk_widget_get_toplevel(Widget)
  else
    toplevel:=nil;

  if GTK_IS_WINDOW (toplevel) then
    Result:=gtk_window_get_group(GTK_WINDOW(toplevel))
  else
    Result:=gtk_window_get_group(nil);
end;

{-------------------------------------------------------------------------------
  procedure: SignalConnect
  Params:  AWidget: PGTKWidget
           ASignal: PChar
           AProc:   Pointer
           AInfo:   PWidgetInfo
  Returns: Nothing

  Connects a gtk signal handler.
  This is a wrapper to get around gtk casting
-------------------------------------------------------------------------------}
procedure SignalConnect(const AWidget: PGTKWidget; const ASignal: PChar;
  const AProc: Pointer; const AInfo: PWidgetInfo);
begin
  g_signal_connect(PGtkObject(AWidget), ASignal, TGTKSignalFunc(AProc), AInfo);
end;

{-------------------------------------------------------------------------------
  procedure: SignalConnectAfter
  Params:  AWidget: PGTKWidget
           ASignal: PChar
           AProc:   Pointer
           AInfo:   PGtkWSWidgetInfo
  Returns: Nothing

  Connects a gtk signal after handler. 
  This is a wrapper to get around gtk casting
-------------------------------------------------------------------------------}
procedure SignalConnectAfter(const AWidget:PGTKWidget; const ASignal: PChar;
  const AProc: Pointer; const AInfo: PWidgetInfo);
begin
  g_signal_connect_after(PGTKObject(AWidget), ASignal, TGTKSignalFunc(AProc), AInfo);
end;

{-------------------------------------------------------------------------------
  procedure ConnectSignal(const AnObject:PGTKObject; const ASignal: PChar;
    const ACallBackProc: Pointer; const ReqSignalMask: TGdkEventMask;
    Flags: TConnectSignalFlags);
    
  Connects a gtk signal handler.
-------------------------------------------------------------------------------}
procedure InitDesignSignalMasks;
var
  SignalType: TDesignSignalType;
begin
  DesignSignalMasks[dstUnknown]:=0;
  for SignalType:=Low(TDesignSignalType) to High(TDesignSignalType) do
    DesignSignalMasks[SignalType]:=1 shl ord(SignalType);
end;

function DesignSignalNameToType(Name: PChar; After: boolean): TDesignSignalType;
begin
  for Result:=Low(TDesignSignalType) to High(TDesignSignalType) do
    if SamePChar(DesignSignalNames[Result],Name)
    and (DesignSignalAfter[Result]=After) then exit;
  Result:=dstUnknown;
end;

function GetDesignSignalMask(Widget: PGtkWidget): TDesignSignalMask;
begin
  Result:=TDesignSignalMask({%H-}PtrUInt(g_object_get_data(PGObject(Widget),
                                                'LCLDesignMask')));
end;

procedure SetDesignSignalMask(Widget: PGtkWidget; NewMask: TDesignSignalMask);
begin
  g_object_set_data(PGObject(Widget),'LCLDesignMask',{%H-}Pointer(PtrInt(NewMask)));
end;

function GetDesignOnlySignalFlag(Widget: PGtkWidget;
  DesignSignalType: TDesignSignalType): boolean;
begin
  Result:=(GetDesignSignalMask(Widget)
          and DesignSignalMasks[DesignSignalType])<>0;
end;

function SignalConnected(const AnObject:PGTKObject; const {%H-}ASignal: PChar;
  const ACallBackProc: Pointer; const ALCLObject: TObject;
  const {%H-}ASFlags: TConnectSignalFlags): boolean;
begin
  Result:=g_signal_handler_find(AnObject,
    G_SIGNAL_MATCH_FUNC or G_SIGNAL_MATCH_DATA,
    0,0,nil,ACallBackProc,ALCLObject)<>0;
end;

procedure ConnectSignal(const AnObject:PGTKObject; const ASignal: PChar;
  const ACallBackProc: Pointer; const ALCLObject: TObject;
  const AReqSignalMask: TGdkEventMask; const ASFlags: TConnectSignalFlags);
var
  WinWidgetInfo: PWinWidgetInfo;
  MainWidget: PGtkWidget;
  OldDesignMask, NewDesignMask: TDesignSignalMask;
  DesignSignalType: TDesignSignalType;
  RealizeConnected: Boolean;
  HasRealizeSignal: Boolean;
begin
  if ACallBackProc = nil then
    RaiseGDBException('ConnectSignal');

  // first loop through the handlers to:
  // - check if a handler already exists
  // - Find the realize handler to change data
  DesignSignalType:=DesignSignalNameToType(ASignal,csfAfter in ASFlags);
  if SignalConnected(AnObject,ASignal,ACallBackProc,ALCLObject,ASFlags) then
  begin
    // signal is already connected
    // update the DesignSignalMask
    if (DesignSignalType <> dstUnknown)
    and (not (csfDesignOnly in ASFlags))
    then begin
      OldDesignMask := GetDesignSignalMask(PGtkWidget(AnObject));
      NewDesignMask :=OldDesignMask and not DesignSignalMasks[DesignSignalType];
      if OldDesignMask <> NewDesignMask
      then SetDesignSignalMask(PGtkWidget(AnObject),NewDesignMask);
    end;
    Exit;
  end;
  
  // if we are here, then no handler was defined yet
  // -> register handler
  //if (Msg=LM_LBUTTONUP) then DebugLn('CONNECT ',ReqSignalMask,' Widget=',DbgS(AnObject));
  //debugln('ConnectSignal ',DbgSName(ALCLObject),' ',ASignal,' After=',dbgs(csfAfter in ASFlags));
  if csfAfter in ASFlags then
    g_signal_connect_after(AnObject, ASignal,
                           TGTKSignalFunc(ACallBackProc), ALCLObject)
  else
    g_signal_connect      (AnObject, ASignal,
                           TGTKSignalFunc(ACallBackProc), ALCLObject);

  // update signal mask which will be set in the realize handler
  if (csfUpdateSignalMask in ASFlags) and (AReqSignalMask <> 0)
  then begin
    MainWidget := GetMainWidget(PGtkWidget(AnObject));
    WinWidgetInfo := g_object_get_data(PGObject(MainWidget), 'widgetinfo');
    Assert(Assigned(MainWidget) and Assigned(WinWidgetInfo), 'ConnectSignal: Widget or WidgetInfo = Nil.');
    WinWidgetInfo^.EventMask := WinWidgetInfo^.EventMask or AReqSignalMask;
  end;
  
  // -> register realize handler
  if (csfConnectRealize in ASFlags) then begin
    HasRealizeSignal:=g_signal_lookup('realize', GTK_OBJECT_TYPE(AnObject))>0;
    if HasRealizeSignal then begin
      RealizeConnected:=SignalConnected(AnObject,'realize',@GTKRealizeCB,
                                        ALCLObject,[]);
      if not RealizeConnected then begin
        g_signal_connect(AnObject, 'realize',
          TGTKSignalFunc(@GTKRealizeCB), ALCLObject);
        g_signal_connect_after(AnObject, 'realize',
          TGTKSignalFunc(@GTKRealizeAfterCB), ALCLObject);
      end;
    end;
  end;

  // update the DesignSignalMask
  if (DesignSignalType <> dstUnknown)
  then begin
    OldDesignMask:=GetDesignSignalMask(PGtkWidget(AnObject));
    if csfDesignOnly in ASFlags then
      NewDesignMask:=OldDesignMask or DesignSignalMasks[DesignSignalType]
    else
      NewDesignMask:=OldDesignMask and not DesignSignalMasks[DesignSignalType];
    if OldDesignMask<>NewDesignMask then
      SetDesignSignalMask(PGtkWidget(AnObject),NewDesignMask);
  end;
end;

procedure ConnectSignal(const AnObject:PGTKObject; const ASignal: PChar;
  const ACallBackProc: Pointer; const ALCLObject: TObject;
  const AReqSignalMask: TGdkEventMask);
begin
  ConnectSignal(AnObject,ASignal,ACallBackProc, ALCLObject, AReqSignalMask,
                [csfConnectRealize,csfUpdateSignalMask]);
end;

procedure ConnectSignalAfter(const AnObject:PGTKObject; const ASignal: PChar;
  const ACallBackProc: Pointer; const ALCLObject: TObject;
  const AReqSignalMask: TGdkEventMask);
begin
  ConnectSignal(AnObject,ASignal,ACallBackProc, ALCLObject, AReqSignalMask,
                [csfConnectRealize,csfUpdateSignalMask,csfAfter]);
end;

procedure ConnectSignal(const AnObject:PGTKObject; const ASignal: PChar;
  const ACallBackProc: Pointer; const ALCLObject: TObject);
begin
  ConnectSignal(AnObject,ASignal,ACallBackProc, ALCLObject, 0);
end;

procedure ConnectSignalAfter(const AnObject:PGTKObject; const ASignal: PChar;
  const ACallBackProc: Pointer; const ALCLObject: TObject);
begin
  ConnectSignalAfter(AnObject,ASignal,ACallBackProc, ALCLObject, 0);
end;

{------------------------------------------------------------------------------
  procedure: ConnectInternalWidgetsSignals
  Params:  AWidget: PGtkWidget; AWinControl: TWinControl
  Returns: Nothing

  Connects hidden child widgets signals.
  Many gtk widgets create internally child widgets (e.g. scrollbars). In
  Design mode these widgets should not auto react themselves, but instead send
  messages to the lcl. Therefore these widgets are connected also to our
  signal handlers.
  This procedure is called by the realize-after handler of all LCL widgets
  and each time the design mode of a LCL control changes.
 ------------------------------------------------------------------------------}
procedure ConnectInternalWidgetsSignals(AWidget: PGtkWidget;
  AWinControl: TWinControl);

  procedure ConnectSignals(TheWidget: PGtkWidget); forward;

  procedure ConnectChilds(TheWidget: PGtkWidget);
  var
    ScrolledWindow: PGtkScrolledWindow;
    BinWidget: PGtkBin;
    ChildEntry2: PGList;
    ChildWidget: PGtkWidget;
  begin
    //if AWinControl is TListView then DebugLn('ConnectChilds A ',DbgS(TheWidget));
    if GtkWidgetIsA(TheWidget,GTK_TYPE_CONTAINER) then begin
      //if AWinControl is TListView then DebugLn('ConnectChilds B ');
      // this is a container widget -> connect all children
      ChildEntry2:=gtk_container_get_children(PGtkContainer(TheWidget));
      while ChildEntry2<>nil do begin
        ChildWidget:=PGtkWidget(ChildEntry2^.Data);
        if ChildWidget<>TheWidget then
          ConnectSignals(ChildWidget);
        ChildEntry2:=ChildEntry2^.Next;
      end;
    end;
    if GtkWidgetIsA(TheWidget,GTK_TYPE_BIN) then begin
      //if AWinControl is TListView then DebugLn('ConnectChilds C ');
      BinWidget:=PGtkBin(TheWidget);
      ConnectSignals(BinWidget^.child);
    end;
    if GtkWidgetIsA(TheWidget,GTK_TYPE_SCROLLED_WINDOW) then begin
      //if AWinControl is TListView then DebugLn('ConnectChilds D ');
      ScrolledWindow:=PGtkScrolledWindow(TheWidget);
      ConnectSignals(ScrolledWindow^.hscrollbar);
      ConnectSignals(ScrolledWindow^.vscrollbar);
    end;
    if GtkWidgetIsA(TheWidget,GTK_TYPE_COMBO) then begin
      //if AWinControl is TListView then DebugLn('ConnectChilds E ');
      ConnectSignals(PGtkCombo(TheWidget)^.entry);
      ConnectSignals(PGtkCombo(TheWidget)^.button);
    end;
  end;

  procedure ConnectSignals(TheWidget: PGtkWidget);
  var
    LCLObject: TObject;
    DesignSignalType: TDesignSignalType;
    DesignFlags: TConnectSignalFlags;
  begin
    //if AWinControl is TListView then DebugLn('ConnectSignals A ',DbgS(TheWidget));
    if TheWidget=nil then exit;
    // check if TheWidget belongs to another LCL object
    LCLObject:=GetLCLObject(TheWidget);
    if (LCLObject<>nil) and (LCLObject<>AWinControl) then begin
      exit;
    end;

    //if AWinControl is TListView then DebugLn('ConnectSignals B ',DbgS(TheWidget));
    // connect signals needed for design mode:
    for DesignSignalType:=Low(TDesignSignalType) to High(TDesignSignalType) do
    begin
      if DesignSignalType=dstUnknown then continue;
      if (not DesignSignalBefore[DesignSignalType])
      and (not DesignSignalAfter[DesignSignalType]) then
        continue;

      DesignFlags:=[csfDesignOnly];
      if DesignSignalAfter[DesignSignalType] then
        Include(DesignFlags,csfAfter);
      ConnectSignal(PGtkObject(TheWidget),DesignSignalNames[DesignSignalType],
                    DesignSignalFuncs[DesignSignalType],AWinControl,0,
                    DesignFlags);
    end;

    // connect recursively ...
    ConnectChilds(TheWidget);
  end;
  
begin
  if (AWinControl=nil) or (AWidget=nil)
  or (not (csDesigning in AWinControl.ComponentState)) then exit;
  ConnectSignals(AWidget);
end;

// ----------------------------------------------------------------------
// The Accelgroup and AccelKey is needed by menus
// ----------------------------------------------------------------------
function GetAccelGroup(const Widget: PGtkWidget;
  CreateIfNotExists: boolean): PGTKAccelGroup;
begin
  Result := PGTKAccelGroup(g_object_get_data(PGObject(Widget),'AccelGroup'));
  if (Result=nil) and CreateIfNotExists then begin
    {$IFDEF VerboseAccelerator}
    DebugLn('GetAccelGroup CREATING  Widget=',DbgS(Widget),' CreateIfNotExists=',dbgs(CreateIfNotExists));
    {$ENDIF}
    Result:=gtk_accel_group_new;
    SetAccelGroup(Widget,Result);
    if GtkWidgetIsA(Widget,GTK_TYPE_WINDOW) then
      ShareWindowAccelGroups(Widget);
  end;
end;

procedure SetAccelGroup(const Widget: PGtkWidget;
  const AnAccelGroup: PGTKAccelGroup);
begin
  if (Widget = nil) then exit;
  g_object_set_data(PGObject(Widget), 'AccelGroup', AnAccelGroup);
  if AnAccelGroup<>nil then begin
    // attach group to widget
    {$IFDEF VerboseAccelerator}
    DebugLn(['SetAccelGroup AnAccelGroup=',DbgS(AnAccelGroup),' IsMenu=',GtkWidgetIsA(Widget,GTK_TYPE_MENU)]);
    {$ENDIF}
    if GtkWidgetIsA(Widget,GTK_TYPE_MENU) then
      gtk_menu_set_accel_group(PGtkMenu(Widget), AnAccelGroup)
    else begin
      Assert(GtkWidgetIsA(Widget,GTK_TYPE_WINDOW));
      gtk_window_add_accel_group(GTK_WINDOW(widget), AnAccelGroup);
    end;
  end;
end;

procedure FreeAccelGroup(const Widget: PGtkWidget);
var
  AccelGroup: PGTKAccelGroup;
begin
  AccelGroup:=GetAccelGroup(Widget,false);
  if AccelGroup<>nil then begin
    {$IFDEF VerboseAccelerator}
    DebugLn('FreeAccelGroup  AccelGroup=',DbgS(AccelGroup));
    {$ENDIF}
    gtk_accel_group_unref(AccelGroup);
    SetAccelGroup(Widget,nil);
  end;
end;

procedure ShareWindowAccelGroups(AWindow: PGtkWidget);

  procedure AttachUnique(TheWindow: PGtkWidget; TheAccelGroup: PGTKAccelGroup);
  begin
    if (TheWindow=nil) or (TheAccelGroup=nil)
      or (TheAccelGroup^.acceleratables=nil)
      or (g_slist_find(TheAccelGroup^.acceleratables, TheWindow)=nil)
    then
      exit;
    gtk_window_add_accel_group(GTK_WINDOW(TheWindow), TheAccelGroup);
  end;

var
  TheForm, CurForm: TCustomForm;
  i: integer;
  TheAccelGroup, CurAccelGroup: PGTKAccelGroup;
  CurWindow: PGtkWidget;
begin
  TheForm:=TCustomForm(GetLCLObject(AWindow));

  // check if visible TCustomForm (not frame)
  if (TheForm=nil) or (not (TheForm is TCustomForm))
  or (not TheForm.Visible) or (TheForm.Parent<>nil)
  or (csDesigning in TheForm.ComponentState)
  then
    exit;
  
  // check if modal form
  if fsModal in TheForm.FormState then begin
    // a modal form does not share accelerators
    exit;
  end;

  // check if there is an accelerator group
  TheAccelGroup:=GetAccelGroup(AWindow,false);

  // this is a normal form
  // -> share accelerators with all other visible normal forms
  for i:=0 to Screen.FormCount-1 do begin
    CurForm:=Screen.Forms[i];
    if (CurForm=TheForm)
    or (not CurForm.HandleAllocated)
    or (not CurForm.Visible)
    or (fsModal in CurForm.FormState)
    or (CurForm.Parent<>nil)
    or (csDesigning in CurForm.ComponentState)
    then continue;
    
    CurWindow:={%H-}PGtkWidget(CurForm.Handle);
    CurAccelGroup:=GetAccelGroup(CurWindow,false);
    {$IFDEF VerboseAccelerator}
    DebugLn('ShareWindowAccelGroups ',TheForm.Name,':',TheForm.ClassName,
            ' <-> ',CurForm.Name,':',CurForm.ClassName);
    {$ENDIF}

    // cross connect
    AttachUnique(CurWindow,TheAccelGroup);
    AttachUnique(AWindow,CurAccelGroup);
  end;
end;

procedure UnshareWindowAccelGroups(AWindow: PGtkWidget);

  procedure Detach(TheWindow: PGtkWidget; TheAccelGroup: PGTKAccelGroup);
  begin
    if (TheWindow=nil) or (TheAccelGroup=nil)
      or (TheAccelGroup^.acceleratables=nil)
      or (g_slist_find(TheAccelGroup^.acceleratables, TheWindow)=nil)
    then
      exit;
    gtk_window_remove_accel_group(GTK_WINDOW(TheWindow), TheAccelGroup);
  end;

var
  TheForm, CurForm: TCustomForm;
  i: integer;
  TheAccelGroup, CurAccelGroup: PGTKAccelGroup;
  CurWindow: PGtkWidget;
begin
  TheForm:=TCustomForm(GetLCLObject(AWindow));

  // check if TCustomForm
  if (TheForm=nil) or (not (TheForm is TCustomForm))
  then exit;

  TheAccelGroup:=GetAccelGroup(AWindow,false);

  // -> unshare accelerators with all other forms
  for i:=0 to Screen.FormCount-1 do begin
    CurForm:=Screen.Forms[i];
    if (CurForm=TheForm)
    or (not CurForm.HandleAllocated)
    then continue;

    CurWindow:={%H-}PGtkWidget(CurForm.Handle);
    CurAccelGroup:=GetAccelGroup(CurWindow,false);
    {$IFDEF VerboseAccelerator}
    DebugLn('UnshareWindowAccelGroups ',TheForm.Name,':',TheForm.ClassName,
            ' <-> ',CurForm.Name,':',CurForm.ClassName);
    {$ENDIF}

    // unlink
    Detach(CurWindow,TheAccelGroup);
    Detach(AWindow,CurAccelGroup);
  end;
end;

function GetAccelGroupForComponent(Component: TComponent;
  CreateIfNotExists: boolean): PGTKAccelGroup;
var
  Control: TControl;
  MenuItem: TMenuItem;
  Form: TCustomForm;
  Menu: TMenu;
begin
  Result:=nil;
  if Component=nil then exit;
  
  if Component is TMenuItem then begin
    MenuItem:=TMenuItem(Component);
    Menu:=MenuItem.GetParentMenu;
    if (Menu=nil) or (Menu.Parent=nil) then exit;
    {$IFDEF VerboseAccelerator}
    DebugLn('GetAccelGroupForComponent A ',Component.Name,':',Component.ClassName);
    {$ENDIF}
    Result:=GetAccelGroupForComponent(Menu.Parent,CreateIfNotExists);
  end else if Component is TControl then begin
    Control:=TControl(Component);
    while Control.Parent<>nil do Control:=Control.Parent;
    if Control is TCustomForm then begin
      Form:=TCustomForm(Control);
      if Form.HandleAllocated then begin
        Result:=GetAccelGroup({%H-}PGtkWidget(Form.Handle),CreateIfNotExists);
        {$IFDEF VerboseAccelerator}
        DebugLn('GetAccelGroupForComponent C ',Component.Name,':',Component.ClassName);
        {$ENDIF}
      end;
    end;
  end;
  {$IFDEF VerboseAccelerator}
  DebugLn('GetAccelGroupForComponent END ',Component.Name,':',Component.ClassName,' Result=',DbgS(Result));
  {$ENDIF}
end;

function GetAccelKey(Widget: PGtkWidget): PAcceleratorKey;
begin
  Result := PAcceleratorKey(g_object_get_data(PGObject(Widget),'AccelKey'));
end;

function SetAccelKey(const Widget: PGtkWidget;
  Key: guint; Mods: TGdkModifierType; const Signal: string): PAcceleratorKey;
begin
  if (Widget = nil) then exit(nil);
  Result:=GetAccelKey(Widget);
  if Result=nil then begin
    if Key>0 then begin
      New(Result);
      FillChar(Result^,SizeOf(Result),0);
    end;
  end else begin
    if Key=0 then begin
      Dispose(Result);
      Result:=nil;
    end;
  end;
  if (Result<>nil) then begin
    Result^.Key:=Key;
    Result^.Mods:=Mods;
    Result^.Signal:=Signal;
    Result^.Realized:=false;
  end;
  {$IFDEF VerboseAccelerator}
  DebugLn('SetAccelKey Widget=',DbgS(Widget),
    ' Key=',dbgs(Key),' Mods=',DbgS(Mods),
    ' Signal="',Signal,'" Result=',DbgS(Result));
  {$ENDIF}
  g_object_set_data(PGObject(Widget), 'AccelKey', Result);
end;

procedure ClearAccelKey(Widget: PGtkWidget);
begin
  SetAccelKey(Widget,0,0,'');
end;

procedure RealizeAccelerator(Component: TComponent; Widget : PGtkWidget);
var
  AccelKey: PAcceleratorKey;
  AccelGroup: PGTKAccelGroup;
begin
  if (Component=nil) or (Widget=nil) then
    RaiseGDBException('RealizeAccelerate: invalid input');

  // Set the accelerator
  AccelKey:=GetAccelKey(Widget);
  if (AccelKey=nil) or (AccelKey^.Realized) then exit;
  
  if AccelKey^.Key>0 then begin
    AccelGroup:=GetAccelGroupForComponent(Component,true);
    if AccelGroup<>nil then begin
      {$IFDEF VerboseAccelerator}
      DebugLn('RealizeAccelerator Add Accelerator ',
        Component.Name,':',Component.ClassName,
        ' Widget=',DbgS(Widget),
        ' Signal=',AccelKey^.Signal,
        ' Key=',dbgs(AccelKey^.Key),' Mods=',dbgs(AccelKey^.Mods),
        '');
      {$ENDIF}
      gtk_widget_add_accelerator(Widget, PChar(AccelKey^.Signal),
        AccelGroup, AccelKey^.Key, AccelKey^.Mods, GTK_ACCEL_VISIBLE);
      AccelKey^.Realized:=true;
    end else begin
      AccelKey^.Realized:=false;
    end;
  end else begin
    AccelKey^.Realized:=true;
  end;
end;

procedure UnrealizeAccelerator(Widget : PGtkWidget);
var
  AccelKey: PAcceleratorKey;
begin
  if (Widget=nil) then
    RaiseGDBException('UnrealizeAccelerate: invalid input');
    
  AccelKey:=GetAccelKey(Widget);
  if (AccelKey=nil) or (not AccelKey^.Realized) then exit;

  if AccelKey^.Signal<>'' then begin
    {$IFDEF VerboseAccelerator}
    DebugLn('UnrealizeAccelerator  ',
      ' Widget=',DbgS(Widget),
      ' Signal=',AccelKey^.Signal,
      ' Key=',dbgs(AccelKey^.Key),' Mods=',dbgs(AccelKey^.Mods),
      '');
    {$ENDIF}
     DebugLn('ToDo: gtkproc.inc UnrealizeAccelerator');
  end;
  AccelKey^.Realized:=false;
end;

procedure RegroupAccelerator(Widget: PGtkWidget);
begin
  UnrealizeAccelerator(Widget);
  RealizeAccelerator(TComponent(GetLCLObject(Widget)),Widget);
end;

procedure Accelerate(Component: TComponent; const Widget : PGtkWidget;
  const Key: guint; Mods: TGdkModifierType; const Signal : string);
var
  OldAccelKey: PAcceleratorKey;
begin
  if (Component=nil) or (Widget=nil) or (Signal='') then
    RaiseGDBException('Accelerate: invalid input');
  {$IFDEF VerboseAccelerator}
  DebugLn('Accelerate ',DbgSName(Component),' Key=',dbgs(Key),' Mods=',DbgS(Mods),' Signal=',Signal);
  {$ENDIF}
  
  // delete old accelerator key
  OldAccelKey:=GetAccelKey(Widget);
  if (OldAccelKey <> nil) then begin
    if (OldAccelKey^.Key=Key) and (OldAccelKey^.Mods=Mods)
    and (OldAccelKey^.Signal=Signal)
    then begin
      // no change
      exit;
    end;
      
    UnrealizeAccelerator(Widget);
  end;

  // Set the accelerator
  SetAccelKey(Widget,Key,Mods,Signal);
  if (Key>0) and (not (csDesigning in Component.ComponentState))
  then
    RealizeAccelerator(Component,Widget);
end;

procedure Accelerate(Component: TComponent; const Widget : PGtkWidget;
  const NewShortCut: TShortCut; const Signal : string);
var
  GDKModifier: TGdkModifierType;
  GDKKey: guint;
  NewKey: word;
  NewModifier: TShiftState;
  Shift: TShiftStateEnum; 
begin
  { Map the shift states }
  GDKModifier := 0;
  ShortCutToKey(NewShortCut, NewKey, NewModifier);
  for Shift := Low(Shift) to High(Shift) do
  begin
    if Shift in NewModifier 
    then GDKModifier := GDKModifier or MModifiers[Shift].Mask;
  end;

  // Send the unmodified keysym ?
  if (ssShift in NewModifier)
  and ((NewKey < VK_F1) or (NewKey > VK_F24))
  then GDKKey := GetVKeyInfo(NewKey).KeySym[1]
  else GDKKey := GetVKeyInfo(NewKey).KeySym[0];

  Accelerate(Component,Widget,GDKKey,GDKModifier,Signal);
end;

{-------------------------------------------------------------------------------
  method TGtkWidgetSet LoadPixbufFromLazResource
  Params: const ResourceName: string;
          var Pixbuf: PGdkPixbuf
  Result: none

  Loads a pixbuf from a lazarus resource. The resource must be a XPM file.
-------------------------------------------------------------------------------}
procedure LoadPixbufFromLazResource(const ResourceName: string;
  var Pixbuf: PGdkPixbuf);
var
  ImgData: PPChar;
begin
  Pixbuf:=nil;
  try
    ImgData:=LazResourceXPMToPPChar(ResourceName);
  except
    on e: Exception do
      DebugLn('WARNING: TGtkWidgetSet.LoadXPMFromLazResource: '+e.Message);
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

{-------------------------------------------------------------------------------
  method CreatePixbufFromDrawable
  Params: ASource: The source drawable
          AColorMap: The colormap to use, when nil a matching colormap is passed
          AIncludeAplha: If set, the resulting pixmap has an alpha channel
          ASrcX, ASrcY: Offset within the source
          ADstX, ADstY: Offset within destination
          AWidth, AHeight: Size of the new image
  Result: New Pixbuf with refcount = 1

  Replaces the gdk_pixbuf_get_from_drawable function which is buggy on big endian
  X servers when an alpha channel is requested.
-------------------------------------------------------------------------------}
function CreatePixbufFromDrawable(ASource: PGdkDrawable; AColorMap:PGdkColormap; AIncludeAplha: Boolean; ASrcX, ASrcY, ADstX, ADstY, AWidth, AHeight: longint): PGdkPixbuf;
{$ifndef HasX}
const
  CanRequestAlpha: Boolean = True;
var
{$else}
var
  CanRequestAlpha: Boolean;
{$endif}
  PixBuf: PGdkPixBuf;
{$ifdef Windows}
  Image: PGdkImage;
{$endif}
begin
  {$ifdef HasX}
  CanRequestAlpha := BitmapBitOrder(gdk_display) = LSBFirst;
  {$endif}
  
  // If Source is GdkBitmap then gdk_pixbuf_get_from_drawable will get
  // pixbuf with 2 colors: transparent and white, but we need only Black and White.
  // If we all alpha at the end then problem is gone.
  CanRequestAlpha := CanRequestAlpha and (gdk_drawable_get_depth(ASource) > 1);
  
  if CanRequestAlpha and AIncludeAplha
  then Pixbuf := gdk_pixbuf_new(GDK_COLORSPACE_RGB, True, 8, AWidth, AHeight)
  else Pixbuf := nil;
  
  // gtk1 requires always a colormap and fails when none passed
  // gtk2 fails when the colormap depth is different than the drawable depth.
  //      It wil use the correct system map when none passed.
  //      Bitmaps (depth = 1) don't need a colormap

  if  (AColorMap = nil)
  and (gdk_drawable_get_depth(ASource) > 1)
  and (gdk_drawable_get_colormap(ASource) = nil)
  then AColorMap := gdk_colormap_get_system;

  {$ifdef Windows}
  if gdk_drawable_get_depth(ASource) = 1 then
  begin
    // Fix gdk error in converter. For 1 bit Byte order is not significant
    Image := gdk_drawable_get_image(ASource, ASrcX, ASrcY, AWidth, AHeight);
    Image^.byte_order := GDK_MSB_FIRST;
    Result := gdk_pixbuf_get_from_image(Pixbuf, Image, nil, ASrcX, ASrcY, ADstX, ADstY, AWidth, AHeight);
    gdk_image_unref(Image);
  end
  else
  {$endif}
  Result := gdk_pixbuf_get_from_drawable(Pixbuf, ASource, AColorMap, ASrcX, ASrcY, ADstX, ADstY, AWidth, AHeight);
  //DbgDumpPixbuf(Result, '');

  if CanRequestAlpha then Exit; // we're done
  if not AIncludeAplha then Exit;

  pixbuf := gdk_pixbuf_add_alpha(Result, false, guchar(0),guchar(0),guchar(0));
  gdk_pixbuf_unref(Result);
  Result := pixbuf;
end;

{-------------------------------------------------------------------------------
  method LoadXPMFromLazResource
  Params: const ResourceName: string;
          Window: PGdkWindow;
          var PixmapImg, PixmapMask: PGdkPixmap
  Result: none

  Loads a pixmap from a lazarus resource. The resource must be a XPM file.
-------------------------------------------------------------------------------}
procedure LoadXPMFromLazResource(const ResourceName: string;
  Window: PGdkWindow; var PixmapImg, PixmapMask: PGdkPixmap);
var
  ImgData: PPGChar;
begin
  PixmapImg:=nil;
  PixmapMask:=nil;
  try
    ImgData:=PPGChar(LazResourceXPMToPPChar(ResourceName));
  except
    on e: Exception do
      DebugLn('WARNING: TGtkWidgetSet.LoadXPMFromLazResource: '+e.Message);
  end;
  {$IFDEF DebugGDK}BeginGDKErrorTrap;{$ENDIF}
  PixmapImg:=gdk_pixmap_create_from_xpm_d(Window,PixmapMask,nil,ImgData);
  {$IFDEF DebugGDK}EndGDKErrorTrap;{$ENDIF}
  FreeMem(ImgData);
end;

{------------------------------------------------------------------------------
  function MENU_ITEM_CLASS(widget: PGtkWidget): PGtkMenuItemClass;

  Returns the gtk klass of a menuitem widget.
 ------------------------------------------------------------------------------}
function MENU_ITEM_CLASS(widget: PGtkWidget): PGtkMenuItemClass;
begin
  Result:=GTK_MENU_ITEM_CLASS(gtk_object_get_class(widget));
end;

{------------------------------------------------------------------------------
  function CHECK_MENU_ITEM_CLASS(widget: PGtkWidget): PGtkCheckMenuItemClass;

  Returns the gtk klass of a checkmenuitem widget.
 ------------------------------------------------------------------------------}
function CHECK_MENU_ITEM_CLASS(widget: PGtkWidget): PGtkCheckMenuItemClass;
begin
  Result:=GTK_CHECK_MENU_ITEM_CLASS(gtk_object_get_class(widget));
end;

{------------------------------------------------------------------------------
  procedure LockRadioGroupOnChange(RadioGroup: PGSList; const ADelta: Integer);

  Calls LockOnChange for all groupmembers
 ------------------------------------------------------------------------------}
procedure LockRadioGroupOnChange(RadioGroup: PGSList; const ADelta: Integer);
begin
  while RadioGroup <> nil do
  begin
    if RadioGroup^.Data <> nil
    then LockOnChange(PgtkObject(RadioGroup^.Data), ADelta);
    RadioGroup := RadioGroup^.Next;
  end;
end;

{------------------------------------------------------------------------------
  procedure UpdateRadioGroupChecks(RadioGroup: PGSList);

  Set 'checked' for all menuitems in the group
 ------------------------------------------------------------------------------}
procedure UpdateRadioGroupChecks(RadioGroup: PGSList);
var
  CurListItem: PGSList;
  MenuItem: PGtkCheckMenuItem;
  LCLMenuItem: TMenuItem;
begin
  // Check if it is a single entry
  if (RadioGroup = nil) or (RadioGroup^.Next = nil)
  then Exit;
  
  // Lock whole group for update
  LockRadioGroupOnChange(RadioGroup, +1);
  CurListItem := RadioGroup;
  try
    // set active radiomenuitem
    while CurListItem <> nil do
    begin
      MenuItem := PGtkCheckMenuItem(CurListItem^.Data);
      if MenuItem<>nil
      then begin
        LCLMenuItem := TMenuItem(GetLCLObject(MenuItem));
        if  (LCLMenuItem <> nil)
        and (gtk_check_menu_item_get_active(MenuItem) <> LCLMenuItem.Checked)
        then gtk_check_menu_item_set_active(MenuItem, LCLMenuItem.Checked);
      end;
      CurListItem := CurListItem^.Next;
    end;
  finally
    // Unlock whole group for update
    LockRadioGroupOnChange(RadioGroup, -1);
  end;
end;

{------------------------------------------------------------------------------
  procedure DrawMenuItemIcon(MenuItem: PGtkCheckMenuItem;
    area: PGdkRectangle); cdecl;

  Handler for drawing the icon of a menuitem.
 ------------------------------------------------------------------------------}
procedure DrawMenuItemIcon(MenuItem: PGtkCheckMenuItem;
  Area: PGdkRectangle); cdecl;
var
  Widget: PGtkWidget;
  Container: PgtkContainer;
  ALeft, ATop, BorderWidth: gint;
  LCLMenuItem: TMenuItem;
  AWindow: PGdkWindow;
  IconWidth, IconHeight: integer;
  IconSize: TPoint;
  HorizPadding, ToggleSpacing: Integer;

  AEffect: TGraphicsDrawEffect;
  AImageList: TCustomImageList;
  FreeImageList: Boolean;
  AImageIndex: Integer;
  ItemBmp: TBitmap;
  DC: HDC;
begin
  if (MenuItem=nil) then
    exit;
  if not (GTK_WIDGET_DRAWABLE (PGtkWidget(MenuItem))) then
    exit;

  // get icon
  LCLMenuItem:=TMenuItem(GetLCLObject(MenuItem));
  if LCLMenuItem=nil then begin // needed for gtk2 dialog
    if GtkWidgetIsA(PGtkWidget(MenuItem), gtk_check_menu_item_get_type) then
      OldCheckMenuItemDrawProc(MenuItem, Area);
    Exit;
  end;
  if not LCLMenuItem.HasIcon then
  begin
    // call default draw function
    OldCheckMenuItemDrawProc(MenuItem,Area);
    exit;
  end;
  // calculate left and top
  Widget := PGtkWidget(MenuItem);
  AWindow:=GetControlWindow(Widget);
  if AWindow = nil then
    exit;

  DC := Widgetset.GetDC(HWND({%H-}PtrUInt(Widget)));
  IconSize:=LCLMenuItem.GetIconSize(DC);
  WidgetSet.ReleaseDC(HWND({%H-}PtrUInt(Widget)), DC);
  IconWidth:=IconSize.X;
  IconHeight:=IconSize.Y;

  Container := GTK_CONTAINER (MenuItem);
  BorderWidth := Container^.flag0 and bm_TGtkContainer_border_width;

  gtk_widget_style_get(PGtkWidget(MenuItem),
                       'horizontal-padding', @HorizPadding,
                       'toggle-spacing', @ToggleSpacing,
                       nil);

  ALeft := BorderWidth +
           gtk_widget_get_xthickness(gtk_widget_get_style(Widget)) +
           HorizPadding +
           ((PGtkMenuItem(MenuItem)^.toggle_size-ToggleSpacing-IconWidth) div 2);

  if gtk_widget_get_direction(Widget) = GTK_TEXT_DIR_RTL then
    ALeft := Widget^.Allocation.width - IconWidth - ALeft; //not sure it is the correct Width

  ATop := (Widget^.Allocation.Height - IconHeight) div 2;

  // draw icon
  AImageList := LCLMenuItem.GetImageList;
  if (AImageList = nil) or (LCLMenuItem.ImageIndex < 0) then
  begin
    AImageList := TImageList.Create(nil);
    // prevent multiple calls to GetBitmap;
    ItemBmp := LCLMenuItem.Bitmap;
    AImageList.Width := ItemBmp.Width; // maybe height to prevent too wide bitmaps?
    AImageList.Height := ItemBmp.Height;
    if not ItemBmp.Transparent then
      AImageIndex := AImageList.AddMasked(ItemBmp, ItemBmp.Canvas.Pixels[0, AImageList.Height-1])
    else
      AImageIndex := AImageList.Add(ItemBmp, nil);
    FreeImageList := True;
  end
  else
  begin
    FreeImageList := False;
    AImageIndex := LCLMenuItem.ImageIndex;
  end;

  if not LCLMenuItem.Enabled then
    AEffect := gdeDisabled
  else
    AEffect := gdeNormal;

  if AImageIndex < AImageList.Count then
    {$IFDEF VerboseGtkToDos}{$note reimplement}{$ENDIF}
    DrawImageListIconOnWidget(AImageList.ResolutionForPPI[IconWidth, 96, 1], AImageIndex, AEffect,
        LCLMenuItem.Checked, Widget, false, false, ALeft, ATop);

  if FreeImageList then
    AImageList.Free;
end;

{------------------------------------------------------------------------------
  procedure MenuSizeRequest(widget:PGtkWidget;
    requisition:PGtkRequisition); cdecl;

  SizeAllocate Handler for check menuitem widgets.
 ------------------------------------------------------------------------------}
procedure MenuSizeRequest(widget:PGtkWidget; requisition:PGtkRequisition); cdecl;
var
  CurToggleSize, MaxToggleSize: integer;
  MenuShell: PGtkMenuShell;
  ListItem: PGList;
  MenuItem: PGtkMenuItem;
  CheckMenuItem: PGtkMenuItem;
  LCLMenuItem: TMenuItem;
  IconSize: TPoint;
  DC: HDC;
begin
  MaxToggleSize:=0;
  MenuShell:=GTK_MENU_SHELL(widget);
  ListItem:=MenuShell^.Children;
  CheckMenuItem:=nil;
  while ListItem<>nil do begin
    MenuItem:=PGtkMenuItem(ListItem^.Data);
    if GTK_IS_CHECK_MENU_ITEM(PGtkWidget(MenuItem)) then begin
      CheckMenuItem:=MenuItem;
      CurToggleSize:=OldCheckMenuItemToggleSize;
      LCLMenuItem:=TMenuItem(GetLCLObject(MenuItem));
      if LCLMenuItem<>nil then begin
        DC := Widgetset.GetDC(HWND({%H-}PtrUInt(widget)));
        IconSize:=LCLMenuItem.GetIconSize(DC);
        WidgetSet.ReleaseDC(HWND({%H-}PtrUInt(Widget)), DC);
        {if IconSize.Width>100 then
          debugln('MenuSizeRequest LCLMenuItem=',LCLMenuItem.Name,' ',LCLMenuItem.Caption,
            ' ');}
        if CurToggleSize<IconSize.X then
          CurToggleSize:=IconSize.X;
      end;
      if MaxToggleSize<CurToggleSize then
        MaxToggleSize:=CurToggleSize;
    end;
    ListItem:=ListItem^.Next;
  end;
  //DebugLn('MenuSizeRequest A MaxToggleSize=',MaxToggleSize);
  // Gtk2ToDo
  if CheckMenuItem<>nil then begin
    GTK_MENU_ITEM(CheckMenuItem)^.toggle_size := 0;
    gtk_menu_item_toggle_size_allocate(GTK_MENU_ITEM(CheckMenuItem),MaxToggleSize);
    GTK_MENU_ITEM(CheckMenuItem)^.toggle_size := MaxToggleSize;
  end;
  //DebugLn('MenuSizeRequest B ',GetWidgetDebugReport(widget),' ',requisition^.width,',',requisition^.height);
  OldMenuSizeRequestProc(Widget,requisition);
  //DebugLn('MenuSizeRequest C ',GetWidgetDebugReport(widget),' ',requisition^.width,',',requisition^.height);
end;

procedure UpdateInnerMenuItem(LCLMenuItem: TMenuItem; MenuItemWidget: PGtkWidget);
begin
  UpdateInnerMenuItem(LCLMenuItem, MenuItemWidget, LCLMenuItem.ShortCut, LCLMenuItem.ShortCutKey2);
end;

{------------------------------------------------------------------------------
  Update the inner widgets of a menuitem widget.
 ------------------------------------------------------------------------------}
procedure UpdateInnerMenuItem(LCLMenuItem: TMenuItem; MenuItemWidget: PGtkWidget;
  NewShortCut, ShortCutKey2: TShortCut);
const
  WidgetDirection : array[boolean] of longint = (GTK_TEXT_DIR_LTR, GTK_TEXT_DIR_RTL);

  function UseRTL: Boolean;
  begin
    Result := LCLMenuItem.GetIsRightToLeft;
  end;
var
  HBoxWidget: PGtkWidget;

  procedure SetMenuItemLabelText(LCLMenuItem: TMenuItem;
    MenuItemWidget: PGtkWidget);
  var
    LabelWidget: PGtkLabel;
  begin
    if (MenuItemWidget = nil) or (LCLMenuItem = nil) then
      Exit;
    LabelWidget := g_object_get_data(PGObject(MenuItemWidget), 'LCLLabel');
    Gtk2Widgetset.SetLabelCaption(LabelWidget, LCLMenuItem.Caption);
    gtk_widget_set_direction(PGtkWidget(LabelWidget), WidgetDirection[UseRTL]);
  end;
  
  procedure UpdateShortCutLabel;
  var
    LabelWidget: PGtkLabel;
    NeedShortCut: Boolean;
    Key, Key2: Word;
    Shift, Shift2: TShiftState;
    s: String;
  begin
    ShortCutToKey(NewShortCut, Key, Shift);
    ShortCutToKey(ShortCutKey2, Key2, Shift2);

    // Check if shortcut is needed. No shortcut captions for items in menubar
    NeedShortCut := (Key <> 0) and
       not ( (LCLMenuItem.Parent <> nil) and LCLMenuItem.Parent.HandleAllocated and
       GtkWidgetIsA({%H-}PGtkWidget(LCLMenuItem.Parent.Handle), GTK_TYPE_MENU_BAR) );

    LabelWidget := PGtkLabel(g_object_get_data(PGObject(MenuItemWidget),'LCLShortCutLabel'));
    if NeedShortCut then
    begin
      s := GetAcceleratorString(Key, Shift);
      if Key2 <> 0 then
        s := s + ', ' + GetAcceleratorString(Key2, Shift2);
      //  ShortCutToText(NewShortCut);
      if LabelWidget = nil then
      begin
        // create a label for the ShortCut
        LabelWidget := PGtkLabel(gtk_label_new(PChar(Pointer(s))));
        g_object_set_data(PGObject(MenuItemWidget), 'LCLShortCutLabel', LabelWidget);
        gtk_container_add(GTK_CONTAINER(HBoxWidget), PGtkWidget(LabelWidget));
        gtk_widget_show(PGtkWidget(LabelWidget));
      end
      else
      begin
        gtk_label_set_text(LabelWidget, PChar(Pointer(s)));
      end;
      gtk_widget_set_direction(PGtkWidget(LabelWidget), GTK_TEXT_DIR_LTR); //Shortcut always LTR
      if UseRTL then
        gtk_misc_set_alignment(GTK_MISC(LabelWidget), 0.0, 0.5)
      else
        gtk_misc_set_alignment(GTK_MISC (LabelWidget), 1.0, 0.5);
    end
    else if LabelWidget <> nil then begin
      gtk_widget_destroy(PGtkWidget(LabelWidget));
      g_object_set_data(PGObject(MenuItemWidget), 'LCLShortCutLabel', nil);
    end;
  end;

  procedure CreateIcon;
  var
    MinHeightWidget: PGtkWidget;
  begin
    // the icon will be painted instead of the toggle
    // of a normal gtkcheckmenuitem
    if LCLMenuItem.HasIcon then
    begin
      GTK_MENU_ITEM(MenuItemWidget)^.flag0:=
        PGtkMenuItem(MenuItemWidget)^.flag0 or
          bm_TGtkCheckMenuItem_always_show_toggle;

      // set our own draw handler
      if OldCheckMenuItemDrawProc = nil then
        OldCheckMenuItemDrawProc := CHECK_MENU_ITEM_CLASS(MenuItemWidget)^.draw_indicator;
      CHECK_MENU_ITEM_CLASS(MenuItemWidget)^.draw_indicator := @DrawMenuItemIcon;

      MinHeightWidget := MenuItemWidget;
    end
    else
      MinHeightWidget := nil;
    g_object_set_data(PGObject(MenuItemWidget),
                        'LCLMinHeight', MinHeightWidget);
  end;

  procedure CreateLabel;
  var
    LabelWidget: PGtkLabel;
  begin
    // create a label for the Caption
    LabelWidget := PGtkLabel(gtk_label_new(''));
    gtk_misc_set_alignment(GTK_MISC (LabelWidget), 0.0, 0.5);
    g_object_set_data(PGObject(MenuItemWidget), 'LCLLabel', LabelWidget);
    gtk_container_add(GTK_CONTAINER(HBoxWidget), PGtkWidget(LabelWidget));
    SetMenuItemLabelText(LCLMenuItem, MenuItemWidget);
    //gtk_accel_label_set_accel_widget(GTK_ACCEL_LABEL(LabelWidget), MenuItemWidget);
    gtk_widget_show(PGtkWidget(LabelWidget));
  end;
  
begin
  HBoxWidget := g_object_get_data(PGObject(MenuItemWidget), 'LCLHBox');
  if HBoxWidget = nil then
  begin
    // create inner widgets
    if LCLMenuItem.Caption = cLineCaption then 
    begin
      // a separator is an empty gtkmenuitem
      exit;
    end;
    HBoxWidget := gtk_hbox_new(false, 20);
    gtk_widget_set_direction(PGtkWidget(HBoxWidget), WidgetDirection[UseRTL]);
    g_object_set_data(PGObject(MenuItemWidget), 'LCLHBox', HBoxWidget);
    CreateIcon;
    CreateLabel;
    UpdateShortCutLabel;
    gtk_container_add(GTK_CONTAINER(MenuItemWidget), HBoxWidget);
    gtk_widget_show(HBoxWidget);
  end else
  begin
    // there are already inner widgets
    if LCLMenuItem.Caption = cLineCaption then 
    begin
      // a separator is an empty gtkmenuitem -> delete the inner widgets
      DestroyWidget(HBoxWidget);
      g_object_set_data(PGObject(MenuItemWidget), 'LCLHBox', nil);
    end else
    begin
      // just update the content
      gtk_widget_set_direction(PGtkWidget(HBoxWidget), WidgetDirection[UseRTL]);
      SetMenuItemLabelText(LCLMenuItem, MenuItemWidget);
      UpdateShortCutLabel;
    end;
  end;
end;

function CreateStatusBarPanel(StatusBar: TObject; Index: integer): PGtkWidget;
begin
  Result := gtk_statusbar_new;
  gtk_widget_show(Result);
  // other properties are set in UpdateStatusBarPanels
end;

procedure UpdateStatusBarPanels(StatusBar: TObject; StatusBarWidget: PGtkWidget);
var
  AStatusBar: TStatusBar;
  HBox: PGtkWidget;
  CurPanelCount: integer;
  NewPanelCount: Integer;
  CurStatusPanelWidget: PGtkWidget;
  ListItem: PGList;
  i: Integer;
  ExpandItem: boolean;
  ShowSizeGrip: Boolean;
begin
  AStatusBar := StatusBar as TStatusBar;
  HBox := PGtkWidget(StatusBarWidget);
  if (not GtkWidgetIsA(StatusBarWidget, GTK_HBOX_GET_TYPE)) then
    RaiseGDBException('');

  // create needed panels
  CurPanelCount := integer(g_list_length(PGtkBox(HBox)^.children));
  if AStatusBar.SimplePanel or (AStatusBar.Panels.Count < 1) then
    NewPanelCount := 1
  else
    NewPanelCount := AStatusBar.Panels.Count;

  while CurPanelCount < NewPanelCount do
  begin
    CurStatusPanelWidget := CreateStatusBarPanel(StatusBar, CurPanelCount);
    ExpandItem := (CurPanelCount = NewPanelCount - 1);
    gtk_box_pack_start(PGtkBox(HBox), CurStatusPanelWidget,
                       ExpandItem, ExpandItem, 0);
    inc(CurPanelCount);
  end;

  // remove unneeded panels
  while CurPanelCount > NewPanelCount do
  begin
    CurStatusPanelWidget := PGtkBoxChild(
              g_list_nth_data(PGtkBox(HBox)^.children, CurPanelCount - 1))^.Widget;
    g_object_set_data(PGObject(CurStatusPanelWidget),'lcl_statusbar_id', nil);
    DestroyConnectedWidgetCB(CurStatusPanelWidget, True);
    dec(CurPanelCount);
  end;

  // check new panel count
  CurPanelCount := integer(g_list_length(PGtkBox(HBox)^.children));
  //DebugLn('TGtkWidgetSet.UpdateStatusBarPanels B ',Dbgs(StatusBar),' NewPanelCount=',dbgs(NewPanelCount),' CurPanelCount=',dbgs(CurPanelCount));
  if CurPanelCount <> NewPanelCount then
    RaiseGDBException('');

  // set panel properties
  ShowSizeGrip := AStatusBar.SizeGrip and AStatusBar.SizeGripEnabled;
  ListItem := PGTKBox(HBox)^.children;
  i := 0;
  while ListItem <> nil do
  begin
    CurStatusPanelWidget := PGtkBoxChild(PGTKWidget(ListItem^.data))^.widget;
    ExpandItem := (ListItem^.next = nil);
    gtk_box_set_child_packing(PGtkBox(HBox), CurStatusPanelWidget,
      ExpandItem, ExpandItem, 0, GTK_PACK_START);
    UpdateStatusBarPanel(StatusBar, i, CurStatusPanelWidget);
    inc(i);
    ListItem := ListItem^.next;
    gtk_statusbar_set_has_resize_grip(PGtkStatusBar(CurStatusPanelWidget),
      (ListItem = nil) and ShowSizeGrip);
  end;
end;

function gtk2PaintStatusBarWidget(Widget: PGtkWidget; Event : PGDKEventExpose;
  Data: gPointer): GBoolean; cdecl;
var
  Msg: TLMDrawItems;
  PS : TPaintStruct;
  ItemStruct: PDrawItemStruct;
  ItemID: Integer;
begin
  Result := CallBackDefaultReturn;
  if (Event^.Count > 0) then exit;

  if (csDesigning in TComponent(Data).ComponentState) then
    exit;

  if TStatusBar(Data).SimplePanel then
    exit;

  ItemId := PtrInt(g_object_get_data(PGObject(Widget), 'lcl_statusbar_id')^);

  if not ((ItemId >= 0) and (ItemId < TStatusBar(Data).Panels.Count)) then
    exit;

  if TStatusBar(Data).Panels[ItemId].Style <> psOwnerDraw then
    exit;

  FillChar(Msg{%H-}, SizeOf(Msg), #0);
  FillChar(PS{%H-}, SizeOf(PS), #0);
  FillChar(ItemStruct{%H-}, SizeOf(ItemStruct), #0);
  New(ItemStruct);
  // we must fill up complete area otherwise gtk2 will do
  // strange paints when item is not fully exposed.
  ItemStruct^.rcItem := Rect(Widget^.allocation.x,
    Widget^.allocation.y,
    Widget^.allocation.width + Widget^.allocation.x,
    Widget^.allocation.height + Widget^.allocation.y);

  OffsetRect(ItemStruct^.rcItem, -ItemStruct^.rcItem.Left, -ItemStruct^.rcItem.Top);

  // take frame borders into account
  with ItemStruct^.rcItem do
  begin
    Left := Left + Widget^.style^.xthickness;
    Top := Top + Widget^.style^.ythickness;
    Right := Right - Widget^.style^.xthickness;
    Bottom := Bottom - Widget^.style^.ythickness;
  end;

  ItemStruct^.itemID := ItemID;
  PS.rcPaint := ItemStruct^.rcItem;
  ItemStruct^._hDC := BeginPaint(THandle({%H-}PtrUInt(Widget)), PS);
  Msg.Ctl := TStatusBar(Data).Handle;
  Msg.DrawItemStruct := ItemStruct;
  Msg.Msg := LM_DRAWITEM;
  try
    DeliverMessage(TStatusBar(Data), Msg);
    Result := not CallBackDefaultReturn;
  finally
    PS.hdc := ItemStruct^._hDC;
    EndPaint(THandle({%H-}PtrUInt(TGtkDeviceContext(PS.hdc).Widget)), PS);
    Dispose(ItemStruct);
  end;
end;

procedure UpdateStatusBarPanel(StatusBar: TObject; Index: integer;
  StatusPanelWidget: PGtkWidget);
var
  AStatusBar: TStatusBar;
  CurPanel: TStatusPanel;
  FrameWidget: PGtkWidget;
  LabelWidget: PGtkLabel;
  PanelText: String;
  ContextID: LongWord;
  NewShadowType: TGtkShadowType;
  NewJustification: TGtkJustification;
  xalign, yalign: gfloat;
  MessageId: guint;
begin
  //DebugLn('UpdateStatusBarPanel ',DbgS(StatusBar),' Index=',dbgs(Index));
  AStatusBar := StatusBar as TStatusBar;

  CurPanel := nil;
  if (not AStatusBar.SimplePanel) and (AStatusBar.Panels.Count > Index) then
    CurPanel := AStatusBar.Panels[Index];
  //DebugLn('Panel ',Index,' ',GetWidgetClassName(StatusPanelWidget),
  //  ' frame=',GetWidgetClassName(PGTKStatusBar(StatusPanelWidget)^.frame),
  //  ' thelabel=',GetWidgetClassName(PGTKStatusBar(StatusPanelWidget)^.thelabel),
  // '');
  FrameWidget := PGTKStatusBar(StatusPanelWidget)^.frame;
  LabelWidget := PGtkLabel(PGTKStatusBar(StatusPanelWidget)^._label);

  // Text
  if AStatusBar.SimplePanel then
    PanelText := AStatusBar.SimpleText
  else
  if CurPanel <> nil then
    PanelText := CurPanel.Text
  else
    PanelText := '';

  if (CurPanel <> nil) and (CurPanel.Style = psOwnerDraw) then
    PanelText := '';

  ContextID := gtk_statusbar_get_context_id(PGTKStatusBar(StatusPanelWidget),
                                            'state');
  //DebugLn('  PanelText="',PanelText,'"');
  if PanelText <> '' then
    MessageId := gtk_statusbar_push(PGTKStatusBar(StatusPanelWidget), ContextID, PGChar(PanelText))
  else
    MessageId := gtk_statusbar_push(PGTKStatusBar(StatusPanelWidget), ContextID, '');
  if MessageId > 1 then
    gtk_statusbar_remove(PGTKStatusBar(StatusPanelWidget), ContextID, MessageId - 1);

  if CurPanel <> nil then
  begin
    //DebugLn('  Alignment="',ord(CurPanel.Alignment),'"');
    // Alignment
    NewJustification := aGtkJustification[CurPanel.Alignment];
    if GTK_IS_LABEL(LabelWidget) then
    begin
      if GTK_IS_MISC(LabelWidget) then
      begin
        {gtk_label_set_justify() has no effect on labels containing
         only a single line !}
        gtk_misc_get_alignment(GTK_MISC(LabelWidget), @xalign, @yalign);
        xalign := AlignToGtkAlign(CurPanel.Alignment);
        gtk_misc_set_alignment(GTK_MISC(LabelWidget), xalign, yalign);
      end else
        gtk_label_set_justify(LabelWidget, NewJustification);
    end;

    // Bevel

    // Paul: this call will not modify frame on gtk2. GtkStatusBar resets frame
    // shadow on every size request. I have tried to modify rcStyle and tried to
    // hook property change event. Both ways are 1) not valid 2) does not give me
    // any result.
    // As a possible solution we can subclass PGtkStatusBar but if gtk developers
    // decided that stausbar should work so whether we need to override that?
    NewShadowType := aGtkShadowFromBevel[CurPanel.Bevel];
    if GTK_IS_FRAME(FrameWidget) then
      gtk_frame_set_shadow_type(PGtkFrame(FrameWidget), NewShadowType);

    // Width
    //DebugLn('  CurPanel.Width="',CurPanel.Width,'"');
    gtk_widget_set_usize(StatusPanelWidget, CurPanel.Width,
      StatusPanelWidget^.allocation.height);
    if CurPanel.Width > 0 then
      gtk_widget_show(StatusPanelWidget)
    else
      gtk_widget_hide(StatusPanelWidget);

    g_object_set_data(PGObject(StatusPanelWidget),'lcl_statusbar_id',
      @AStatusBar.Panels[Index].ID);
    if AStatusBar.Panels[Index].Style = psOwnerDraw then
      g_signal_connect_after(StatusPanelWidget, 'expose-event',
        TGtkSignalFunc(@gtk2PaintStatusBarWidget), AStatusBar);

  end;
end;

function gtkListGetSelectionMode(list: PGtkList): TGtkSelectionMode; cdecl;
begin
  Result:=TGtkSelectionMode(
       (list^.flag0 and bm_TGtkList_selection_mode) shr bp_TGtkList_selection_mode);
end;

{------------------------------------------------------------------------------
  SaveSizeNotification
  Params: Widget: PGtkWidget  A widget that is the handle of a lcl control.

  When the gtk sends a size signal, it is not send directly to the LCL. All gtk
  size/move messages are collected and only the last one for each widget is sent
  to the LCL.
  This is neccessary, because the gtk sends size messages several times and
  it replays resizes. Since the LCL reacts to every size notification and
  resizes child controls, this results in a perpetuum mobile.
 ------------------------------------------------------------------------------}
procedure SaveSizeNotification(Widget: PGtkWidget);
{$IFDEF VerboseSizeMsg}
var
  LCLControl: TWinControl;
{$ENDIF}
begin
  {$IFDEF VerboseSizeMsg}
  DbgOut('SaveSizeNotification Widget=',DbgS(Widget));
  LCLControl:=TWinControl(GetLCLObject(Widget));
  if (LCLControl<>nil) then begin
    if LCLControl is TWinControl then
      DebugLn(' ',LCLControl.Name,':',LCLControl.ClassName)
    else
      DebugLn(' ERROR: ',LCLControl.ClassName);
  end else begin
    DebugLn(' ERROR: LCLControl=nil');
  end;
  {$ENDIF}
  if not FWidgetsResized.Contains(Widget) then
    FWidgetsResized.Add(Widget);
end;

{------------------------------------------------------------------------------
  SaveClientSizeNotification
  Params: FixWidget: PGtkWidget  A widget that is the fixed widget
                                 of a lcl control.

  When the gtk sends a size signal, it is not sent directly to the LCL. All gtk
  size/move messages are collected and only the last one for each widget is sent
  to the LCL.
  This is neccessary, because the gtk sends size messages several times and
  it replays resizes. Since the LCL reacts to every size notification and
  resizes child controls, this results in a perpetuum mobile.
 ------------------------------------------------------------------------------}
procedure SaveClientSizeNotification(FixWidget: PGtkWidget);
{$IFDEF VerboseSizeMsg}
var
  LCLControl: TWinControl;
  MainWidget: PGtkWidget;
{$ENDIF}
begin
  {$IFDEF VerboseSizeMsg}
  MainWidget:=GetMainWidget(FixWidget);
  //write('SaveClientSizeNotification',
  //  ' FixWidget=',DbgS(FixWidget),
  //  ' MainWIdget=',DbgS(MainWidget));
  LCLControl:=TWinControl(GetLCLObject(MainWidget));
  if (LCLControl<>nil) then begin
    if LCLControl is TWinControl then begin
      //DebugLn('SaveClientSizeNotification ',LCLControl.Name,':',LCLControl.ClassName,
      //  ' FixWidget=',DbgS(FixWidget),
      //  ' MainWidget=',DbgS(MainWidget));
    end else begin
      DbgOut('ERROR: SaveClientSizeNotification ',
        ' LCLControl=',LCLControl.ClassName,
        ' FixWidget=',DbgS(FixWidget),
        ' MainWidget=',DbgS(MainWidget));
      RaiseGDBException('SaveClientSizeNotification');
    end;
  end else begin
    DbgOut('ERROR: SaveClientSizeNotification LCLControl=nil',
      ' FixWidget=',DbgS(FixWidget),
      ' MainWIdget=',DbgS(MainWidget));
    RaiseGDBException('SaveClientSizeNotification');
  end;
  {$ENDIF}
  if not FFixWidgetsResized.Contains(FixWidget) then
    FFixWidgetsResized.Add(FixWidget);
end;

{-------------------------------------------------------------------------------
  CreateTopologicalSortedWidgets
  Params: HashArray: TDynHashArray  of PGtkWidget
  
  Creates a topologically sorted TFPList of PGtkWidget.
-------------------------------------------------------------------------------}
function CreateTopologicalSortedWidgets(HashArray: TDynHashArray): TFPList;
type
  PTopologicalEntry = ^TTopologicalEntry;
  TTopologicalEntry = record
      Widget: PGtkWidget;
      ParentLevel: integer;
    end;
    
  function GetParentLevel(AControl: TControl): integer;
  // nil has lvl -1
  // a control without parent has lvl 0
  begin
    Result:=-1;
    while AControl<>nil do begin
      inc(Result);
      AControl:=AControl.Parent;
    end;
  end;
  
var
  TopologicalList: PTopologicalEntry;
  HashItem: PDynHashArrayItem;
  i, Lvl, MaxLevel: integer;
  LCLControl: TControl;
  LevelCounts: PInteger;
begin
  Result:=TFPList.Create;
  if HashArray.Count=0 then exit;
  
  // put all widgets into an array and calculate their parent levels
  GetMem(TopologicalList,SizeOf(TTopologicalEntry)*HashArray.Count);
  HashItem:=HashArray.FirstHashItem;
  i:=0;
  MaxLevel:=0;
  //DebugLn('CreateTopologicalSortedWidgets HashArray.Count=',HashArray.Count);
  while HashItem<>nil do begin
    TopologicalList[i].Widget:=HashItem^.Item;
    //DebugLn('CreateTopologicalSortedWidgets i=',i,' Widget=',DbgS(TopologicalList[i].Widget));
    LCLControl:=TControl(GetLCLObject(TopologicalList[i].Widget));
    if (LCLControl=nil) or (not (LCLControl is TControl)) then
      RaiseGDBException('CreateTopologicalSortedWidgets: '
                             +'Widget without LCL control');
    Lvl:=GetParentLevel(LCLControl);
    TopologicalList[i].ParentLevel:=Lvl;
    if MaxLevel<Lvl then
      MaxLevel:=Lvl;
    //DebugLn('CreateTopologicalSortedWidgets i=',i,' Lvl=',Lvl,' MaxLvl=',MaxLevel,' LCLControl=',LCLControl.Name,':',LCLControl.ClassName);
    inc(i);
    HashItem:=HashItem^.Next;
  end;
  inc(MaxLevel);
  
  // bucket sort the widgets
  
  // count each number of levels (= bucketsizes)
  GetMem(LevelCounts,SizeOf(Integer)*MaxLevel);
  FillChar(LevelCounts^,SizeOf(Integer)*MaxLevel,0);
  for i:=0 to HashArray.Count-1 do
    inc(LevelCounts[TopologicalList[i].ParentLevel]);

  // calculate bucketends
  for i:=1 to MaxLevel-1 do
    inc(LevelCounts[i],LevelCounts[i-1]);

  // bucket sort the widgets in Result
  Result.Count:=HashArray.Count;
  for i:=0 to HashArray.Count-1 do
    Result[i]:=nil;
  for i:=0 to HashArray.Count-1 do begin
    Lvl:=TopologicalList[i].ParentLevel;
    dec(LevelCounts[Lvl]);
    //DebugLn('CreateTopologicalSortedWidgets bucket sort i=',i,' Lvl=',Lvl,' LevelCounts[Lvl]=',LevelCounts[Lvl],
    //  ' Widget=',DbgS(TopologicalList[i].Widget));
    Result[LevelCounts[Lvl]]:=TopologicalList[i].Widget;
  end;
  
  FreeMem(LevelCounts);
  FreeMem(TopologicalList);
end;

procedure GetGTKDefaultWidgetSize(AWinControl: TWinControl;
  var PreferredWidth, PreferredHeight: integer; WithThemeSpace: Boolean);
var
  Widget: PGtkWidget;
  Requisition: TGtkRequisition;
  FixedWidget, LblWidget: PGtkWidget;
begin
  Widget := {%H-}PGtkWidget(AWinControl.Handle);
  {$IFDEF VerboseCalculatePreferredSize}
  if AWinControl.Name='GroupBox1' then
    DebugLn(['GetGTKDefaultWidgetSize ',GetWidgetDebugReport(Widget)]);
  {$ENDIF}

  // set size to default
  gtk_widget_set_size_request(Widget, -1, -1);
  // ask default size
  gtk_widget_size_request(Widget,@Requisition);
  PreferredWidth:=Requisition.width;
  PreferredHeight:=Requisition.height;

  {$IFDEF VerboseCalculatePreferredSize}
  if AWinControl.Name='GroupBox1' then
    DebugLn(['GetGTKDefaultWidgetSize Allocation=',Widget^.allocation.x,',',Widget^.allocation.y,',',Widget^.allocation.width,',',Widget^.allocation.height,
     ' requisition=',Widget^.requisition.width,',',Widget^.requisition.height,
     ' PreferredWidth=',PreferredWidth,' PreferredHeight=',PreferredHeight,
     ' WithThemeSpace=',WithThemeSpace]);
  {$ENDIF}

  if GtkWidgetIsA(Widget,GTK_TYPE_EVENT_BOX)
  and (AWinControl.ControlCount>0) then begin
    // ignore client area (child controls)
    FixedWidget:=PGtkWidget(GetFixedWidget(Widget));
    if FixedWidget<>nil then begin
      {$IFDEF VerboseCalculatePreferredSize}
      if AWinControl.Name='GroupBox1' then
        debugln(['GetGTKDefaultWidgetSize Fixed ',
         ' allocation=',FixedWidget^.allocation.x,',',FixedWidget^.allocation.y,',',FixedWidget^.allocation.width,',',FixedWidget^.allocation.height,
         ' requisition=',FixedWidget^.requisition.width,',',FixedWidget^.requisition.height]);
      {$ENDIF}
      dec(PreferredWidth,Max(0,FixedWidget^.requisition.width));
      dec(PreferredHeight,Max(0,FixedWidget^.requisition.height));
    end;
  end;

  // Do not truncate Groupbox caption. Issue #32621
  if AWinControl is TCustomGroupBox then begin
    LblWidget := gtk_frame_get_label_widget(PGtkFrame(PGtkBin(Widget)^.child));
    if LblWidget <> nil then
      PreferredWidth := Max(PreferredWidth, LblWidget^.allocation.x * 2 + LblWidget^.requisition.width);
  end;

  // restore size
  gtk_widget_set_size_request(Widget, AWinControl.Width, AWinControl.Height);
  {$IFDEF VerboseCalculatePreferredSize}
  if AWinControl.Name='GroupBox1' then
    debugln('GetGTKDefaultSize PreferredWidth=',dbgs(PreferredWidth),' PreferredHeight=',dbgs(PreferredHeight));
  {$ENDIF}
end;

procedure SendSizeNotificationToLCL(aWidget: PGtkWidget);
var
  LCLControl: TWinControl;
  LCLLeft, LCLTop, LCLWidth, LCLHeight: integer;
  GtkLeft, GtkTop, GtkWidth, GtkHeight: integer;
  TopLeftChanged, WidthHeightChanged, IsTopLevelWidget: boolean;
  MessageDelivered: boolean;
  SizeMsg: TLMSize;
  MoveMsg: TLMMove;
  PosMsg : TLMWindowPosChanged;
  MainWidget: PGtkWidget;
  FixedWidget: PGtkWidget;

  procedure UpdateLCLPos;
  begin
    LCLLeft:=LCLControl.Left;
    LCLTop:=LCLControl.Top;
    TopLeftChanged:=(LCLLeft<>GtkLeft) or (LCLTop<>GtkTop);
  end;
    
  procedure UpdateLCLSize;
  begin
    LCLWidth:=LCLControl.Width;
    LCLHeight:=LCLControl.Height;
    WidthHeightChanged:=(LCLWidth<>GtkWidth) or (LCLHeight<>GtkHeight);
    if LCLControl.ClientRectNeedsInterfaceUpdate then begin
      WidthHeightChanged:=true;
      //DebugLn(['UpdateLCLSize InvalidateClientRectCache ',DbgSName(LCLControl)]);
      LCLControl.InvalidateClientRectCache(false);
    end;
  end;

begin
  LCLControl:=TWinControl(GetLCLObject(aWidget));
  if LCLControl=nil then exit;
  {$IFDEF VerboseSizeMsg}
  DebugLn('SendSizeNotificationToLCL checking ... ',DbgSName(LCLControl),' Widget=',WidgetFlagsToString(aWidget));
  {$ENDIF}
  MainWidget:={%H-}PGtkWidget(LCLControl.Handle);
  FixedWidget:=PGtkWidget(GetFixedWidget(MainWidget));

  FWidgetsResized.Remove(MainWidget);
  FFixWidgetsResized.Remove(FixedWidget);

  GetWidgetRelativePosition(MainWidget,GtkLeft,GtkTop);

  gtk_widget_get_size_request(MainWidget, @GtkWidth, @GtkHeight);

  if GtkWidth < 0 then
    GtkWidth:=MainWidget^.Allocation.Width
  else
    MainWidget^.Allocation.Width:=GtkWidth;
  if GtkHeight < 0 then
    GtkHeight:=MainWidget^.Allocation.Height
  else
    MainWidget^.Allocation.Height:=GtkHeight;
  //DebugLn(['SendSizeNotificationToLCL ',DbgSName(LCLControl),' gtk=',GtkLeft,',',GtkTop,',',GtkWidth,'x',GtkHeight,' Allocation=',MainWidget^.Allocation.Width,'x',MainWidget^.Allocation.Height]);

  if GtkWidth<0 then GtkWidth:=0;
  if GtkHeight<0 then GtkHeight:=0;

  IsTopLevelWidget:=(LCLControl is TCustomForm) and (LCLControl.Parent=nil);
  if IsTopLevelWidget then begin
    if not GTK_WIDGET_VISIBLE(MainWidget) then begin
      // size/move messages of invisible windows are not reliable
      // -> ignore
      exit;
    end;
    if (GtkWidth=1) and (GtkHeight=1) then begin
      // this is default size of the gtk. Ignore.
      exit;
    end;
    //DebugLn(['SendSizeNotificationToLCL FORM ',GetWidgetDebugReport(MainWidget)]);

    {$IFDEF VerboseFormPositioning}
    DebugLn(['VFP SendSizeNotificationToLCL ',DbgSName(LCLControl),' ',
      GtkLeft,',',GtkTop,',',GtkWidth,'x',GtkHeight,' ',GetWidgetDebugReport(MainWidget)]);
    {$ENDIF}
  end;

  UpdateLCLPos;
  UpdateLCLSize;

  // first send a LM_WINDOWPOSCHANGED message
  if TopLeftChanged or WidthHeightChanged then begin
    {$IFDEF VerboseSizeMsg}
    DebugLn('SendSizeNotificationToLCL ',DbgSName(LCLControl),
      ' GTK=',dbgs(GtkLeft)+','+dbgs(GtkTop)+','+dbgs(GtkWidth)+'x'+dbgs(GtkHeight),
      ' LCL=',dbgs(LCLLeft)+','+dbgs(LCLTop)+','+dbgs(LCLWidth)+'x'+dbgs(LCLHeight)
      );
    {$ENDIF}
    PosMsg.Msg := LM_WINDOWPOSCHANGED; //LM_SIZEALLOCATE;
    PosMsg.Result := 0;
    New(PosMsg.WindowPos);
    try
      with PosMsg.WindowPos^ do begin
        hWndInsertAfter := 0;
        x := GtkLeft;
        y := GtkTop;
        cx := GtkWidth;
        cy := GtkHeight;
        flags:=0;
        // flags := SWP_SourceIsInterface;
      end;
      MessageDelivered := DeliverMessage(LCLControl, PosMsg) = 0;
    finally
      Dispose(PosMsg.WindowPos);
    end;
    if (not MessageDelivered) then exit;
    if FWidgetsWithResizeRequest.Contains(MainWidget) then exit;
    UpdateLCLPos;
    UpdateLCLSize;
  end;

  // then send a LM_SIZE message
  if WidthHeightChanged then begin
    {$IFDEF VerboseSizeMsg}
    DebugLn('Send LM_SIZE To LCL ',LCLControl.Name,':',LCLControl.ClassName);
    {$ENDIF}
    with SizeMsg do
    begin
      Result := 0;
      Msg := LM_SIZE;
      if LCLControl is TCustomForm then begin
        // if the LCL gets an event without a State it resets it to SIZE_RESTORED
        // so we send it the state it already is
        case TCustomForm(LCLControl).WindowState of
          wsNormal: SizeType := SIZE_RESTORED;
          wsMinimized: SizeType := SIZE_MINIMIZED;
          wsMaximized: SizeType := SIZE_MAXIMIZED;
          wsFullScreen: SizeType := SIZE_FULLSCREEN;
        end;
      end
      else
        SizeType := 0;
      SizeType := SizeType or Size_SourceIsInterface;
      Width := SmallInt(GtkWidth);
      Height := SmallInt(GtkHeight);
    end;
    MessageDelivered := (DeliverMessage(LCLControl, SizeMsg) = 0);
    if not MessageDelivered then exit;
    if FWidgetsWithResizeRequest.Contains(MainWidget) then exit;
    UpdateLCLPos;
  end;

  // then send a LM_MOVE message
  if TopLeftChanged then begin
    {$IFDEF VerboseSizeMsg}
    DebugLn('Send LM_MOVE To LCL ',dbgsname(LCLControl));
    {$ENDIF}
    with MoveMsg do
    begin
      Result := 0;
      Msg := LM_MOVE;
      MoveType := Move_SourceIsInterface;
      XPos := SmallInt(GtkLeft);
      YPos := SmallInt(GtkTop);
    end;
    MessageDelivered := (DeliverMessage(LCLControl,  MoveMsg) = 0);
    if not MessageDelivered then exit;
  end;

  {$IFDEF EnableGtk2WidgetDrawOnLCLSizeMessage}
  if GtkWidgetIsA(aWidget, GTKAPIWidget_Type) and
     not (wwiNoEraseBkgnd in GetWidgetInfo(aWidget)^.Flags)
  then begin
    //debugln(['SendSizeNotificationToLCL ',DbgSName(LCLControl)]);
    gtk_widget_queue_draw(aWidget);
  end;
  {$ENDIF}
end;

procedure SendCachedGtkResizeNotifications;
{ This proc sends all cached size messages from the gtk to lcl but in an
  optimized order.
  When sending the LCL a size/move/windowposchanged messages the LCL will
  automatically realign all child controls. This realigning is based on the
  clientrect.
  Therefore, before a size message is sent to the lcl, all clientrect must be
  updated.
  If a size message results in resizing a widget that was also resized, then
  the message for the dependent widget is not sent to the lcl, because the lcl
  resize was after the gtk resize.
}
var
  FixWidget, MainWidget: PGtkWidget;
  LCLControl: TWinControl;
  List: TFPList;
  i: integer;

  procedure RaiseInvalidLCLControl;
  begin
    RaiseGDBException(Format('SendCachedGtkResizeNotifications FixWidget=%p MainWidget=%p LCLControl=%p',
                  [FixWidget, MainWidget, Pointer(LCLControl)]));
  end;

begin
  if (FWidgetsResized.Count=0) and (FFixWidgetsResized.Count=0) then exit;

  List:=TFPList.Create;

  { if any fixed widget was resized then a client area of a LCL control was
    resized
    -> invalidate client rectangles
  }
  {$IFDEF VerboseSizeMsg}
  DebugLn('HHH1 SendCachedGtkClientResizeNotifications Invalidating ClientRects ... '
  ,' FixSizeMsgCount=',dbgs(FFixWidgetsResized.Count));
  {$ENDIF}
  FFixWidgetsResized.AssignTo(List);
  for i:=0 to List.Count-1 do begin
    FixWidget:=List[i];
    MainWidget:=GetMainWidget(FixWidget);
    LCLControl:=TWinControl(GetLCLObject(MainWidget));
    if (LCLControl=nil) or (not (LCLControl is TWinControl)) then
      RaiseInvalidLCLControl;
    LCLControl.InvalidateClientRectCache(false);
  end;

  { if any main widget (= not fixed widget) was resized
    then a LCL control was resized
    -> send WMSize, WMMove, and WMWindowPosChanged messages
  }
  {$IFDEF VerboseSizeMsg}
  if FWidgetsResized.First<>nil then
    DebugLn('HHH2 SendCachedGtkClientResizeNotifications SizeMsgCount=',dbgs(FWidgetsResized.Count));
  {$ENDIF}
  repeat
    MainWidget:=FWidgetsResized.First;
    if MainWidget<>nil then begin
      FWidgetsResized.Remove(MainWidget);
      if not FWidgetsWithResizeRequest.Contains(MainWidget) then begin
        SendSizeNotificationToLCL(MainWidget);
      end;
    end else break;
  until Application.Terminated;

  { if any client area was resized, which MainWidget Size was already in sync
    with the LCL, no message was sent. So, tell each changed client area to
    check its size.
  }
  {$IFDEF VerboseSizeMsg}
  if FFixWidgetsResized.First<>nil then
    DebugLn('HHH3 SendCachedGtkClientResizeNotifications Updating ClientRects ...');
  {$ENDIF}
  repeat
    FixWidget:=FFixWidgetsResized.First;
    if FixWidget<>nil then begin
      FFixWidgetsResized.Remove(FixWidget);
      MainWidget:=GetMainWidget(FixWidget);
      LCLControl:=TWinControl(GetLCLObject(MainWidget));
      LCLControl.DoAdjustClientRectChange(False);
    end else begin
      break;
    end;
  until Application.Terminated;

  List.Free;
  {$IFDEF VerboseSizeMsg}
  DebugLn('HHH4 SendCachedGtkClientResizeNotifications  completed.');
  {$ENDIF}
end;

procedure ResizeHandle(LCLControl: TWinControl);
var
  Widget: PGtkWidget;
  Later: Boolean;
  IsTopLevelWidget: Boolean;
begin
  Widget := {%H-}PGtkWidget(LCLControl.Handle);
  if not WidgetSizeIsEditable(Widget) then
    Exit;
  Later := true;
  // add resize request immediately
  IsTopLevelWidget:= (LCLControl is TCustomForm) and
                     (LCLControl.Parent = nil) and
                     (LCLControl.ParentWindow = 0);
  if not IsTopLevelWidget then
  begin
    SetWidgetSizeAndPosition(LCLControl);
    Later := false;
  end;
  if Later then
    SetResizeRequest(Widget);
end;

procedure SetWidgetSizeAndPosition(LCLControl: TWinControl);
var
  Requisition: TGtkRequisition;
  FixedWidget: PGtkWidget;
  allocation: TGtkAllocation;
  LCLLeft: LongInt;
  LCLTop: LongInt;
  LCLWidth: LongInt;
  LCLHeight: LongInt;
  Widget: PGtkWidget;
  ParentWidget: PGtkWidget;
  ParentFixed: PGtkWidget;
  WinWidgetInfo: PWidgetInfo;
  {$IFDEF VerboseSizeMsg}
  LCLObject: TObject;
  {$ENDIF}

  procedure WriteBigWarning;
  begin
    DebugLn('WARNING: SetWidgetSizeAndPosition: resizing BIG ',
      ' Control=',LCLControl.Name,':',LCLControl.ClassName,
      ' NewSize=',dbgs(LCLWidth),',',dbgs(LCLHeight));
    //RaiseGDBException('');
  end;

  procedure WriteWarningParentWidgetNotFound;
  begin
    DebugLn('WARNING: SetWidgetSizeAndPosition - '
            ,'Parent''s Fixed Widget not found');
    DebugLn('  Control=',LCLControl.Name,':',LCLControl.ClassName,
      ' Parent=',LCLControl.Parent.Name,':',LCLControl.Parent.ClassName,
      ' ParentWidget=',DbgS(ParentWidget),
      '');
  end;

const
  MaxSize = 32000; // some limit to spot endless loops and bad values
begin
  {$IFDEF VerboseSizeMsg}
  DebugLn(['SetWidgetSizeAndPosition ',DbgSName(LCLControl)]);
  {$ENDIF}
  Widget:={%H-}PGtkWidget(LCLControl.Handle);
  
  LCLLeft := LCLControl.Left;
  LCLTop := LCLControl.Top;

  // move widget on the fixed widget of parent control
  if ((LCLControl.Parent <> nil) and (LCLControl.Parent.HandleAllocated)) or
     ((LCLControl.Parent = nil) and (LCLControl.ParentWindow <> 0)) then
  begin
    if LCLControl.Parent <> nil then
      ParentWidget := {%H-}PGtkWidget(LCLControl.Parent.Handle)
    else
      ParentWidget := {%H-}PGtkWidget(LCLControl.ParentWindow);
    ParentFixed := GetFixedWidget(ParentWidget);
    if GtkWidgetIsA(ParentFixed,GTK_FIXED_GET_TYPE) or
       GtkWidgetIsA(ParentFixed,GTK_LAYOUT_GET_TYPE) then
    begin
      //DebugLn(['SetWidgetSizeAndPosition ',DbgSName(LCLControl),' Widget=[',GetWidgetDebugReport(Widget),'] ParentFixed=[',GetWidgetDebugReport(ParentFixed),']']);
      FixedMoveControl(ParentFixed, Widget, LCLLeft, LCLTop);
    end
    else
    begin
      WinWidgetInfo := GetWidgetInfo(Widget);
      if (WinWidgetInfo = nil) or (not (wwiNotOnParentsClientArea in WinWidgetInfo^.Flags)) then
        WriteWarningParentWidgetNotFound;
    end;
  end;

  // resize widget
  LCLWidth := LCLControl.Width;
  if LCLWidth <= 0 then
    LCLWidth := 1;
  LCLHeight := LCLControl.Height;
  if LCLHeight <= 0 then
    LCLHeight := 1;
  if (LCLWidth > MaxSize) or (LCLHeight > MaxSize) then
  begin
    WriteBigWarning;
    if LCLWidth > MaxSize then
      LCLWidth := MaxSize;
    if LCLHeight > MaxSize then
      LCLHeight := MaxSize;
  end;

  {$IFDEF VerboseSizeMsg}
  LCLObject:=GetNearestLCLObject(Widget);
  DbgOut('TGtkWidgetSet.SetWidgetSizeAndPosition Widget='+DbgS(Widget)+WidgetFlagsToString(Widget)+
    ' New='+dbgs(LCLWidth)+','+dbgs(LCLHeight));
  if LCLObject is TControl then begin
    with TControl(LCLObject) do
      DebugLn(' LCL=',Name,':',ClassName,' ',dbgs(Left),',',dbgs(Top),',',dbgs(Width),',',dbgs(Height));
  end else begin
    DebugLn(' LCL=',DbgS(LCLObject));
  end;
  {$ENDIF}

  if GtkWidgetIsA(Widget,GTK_TYPE_SCROLLBAR) then
  begin
    // the width of a scrollbar is fixed and depends only on the theme
    gtk_widget_size_request(widget, @Requisition);
    if GtkWidgetIsA(Widget, GTK_TYPE_HSCROLLBAR) then
    begin
      LCLHeight:=Requisition.height;
    end else begin
      LCLWidth:=Requisition.width;
    end;
    //DebugLn('TGtkWidgetSet.SetWidgetSizeAndPosition A ',LCLwidth,',',LCLheight);
  end;

  gtk_widget_set_usize(Widget, LCLWidth, LCLHeight);
  //DebugLn(['TGtkWidgetSet.SetWidgetSizeAndPosition ',GetWidgetDebugReport(Widget),' LCLWidth=',LCLWidth,' LCLHeight=',LCLHeight]);

  if GtkWidgetIsA(Widget,gtk_toolbar_get_type) then begin
    FixedWidget:=GetFixedWidget(Widget);
    if (FixedWidget<>nil) and (FixedWidget<>Widget) then begin
      //DebugLn('WARNING: ToDo TGtkWidgetSet.SetWidgetSizeAndPosition for TToolBar ',LCLWidth,',',LCLHeight);
      gtk_widget_set_usize(FixedWidget,LCLWidth,LCLHeight);
    end;
  end;

  if (Widget^.parent<>nil)
  and GtkWidgetIsA(Widget^.parent,GTK_TYPE_FIXED)
  and GTK_WIDGET_NO_WINDOW(Widget^.parent)
  then begin
    inc(LCLLeft, Widget^.parent^.allocation.x);
    inc(LCLTop, Widget^.parent^.allocation.y);
  end;
  
  // commit size and position
  allocation:=Widget^.allocation;
  allocation.x:=LCLLeft;
  allocation.y:=LCLTop;
  allocation.width:=LCLWidth;
  allocation.height:=LCLHeight;
  //DebugLn(['SetWidgetSizeAndPosition ',DbgSName(LCLControl),' LCL=',dbgs(LCLControl.BoundsRect),' allocation=',dbgs(allocation),' ',GetWidgetDebugReport(Widget)]);
  gtk_widget_size_allocate(Widget,@allocation);// Beware: this triggers callbacks
end;

{------------------------------------------------------------------------------
  Method: SetWindowSizeAndPosition
  Params:  Widget: PGtkWidget; AWinControl: TWinControl
  Returns: Nothing

  Set the size and position of a top level window.
 ------------------------------------------------------------------------------}
procedure SetWindowSizeAndPosition(Window: PGtkWindow;
  AWinControl: TWinControl);
var
  Width, Height: integer;
  allocation: TGtkAllocation;
  //Info: PGtkWindowGeometryInfo;
begin
  Width:=AWinControl.Width;
  // 0 and negative values have a special meaning, so don't use them
  if Width<=0 then Width:=1;
  Height:=AWinControl.Height;
  if Height<=0 then Height:=1;

  {$IFDEF VerboseSizeMsg}
  DebugLn(['TGtkWidgetSet.SetWindowSizeAndPosition START ',DbgSName(AWinControl),' ',AWinControl.Visible,' Old=',PGtkWidget(Window)^.allocation.Width,',',PGtkWidget(Window)^.allocation.Width,' New=',Width,',',Height]);
  {$ENDIF}
  // set geometry default size
  //Info:=gtk_window_get_geometry_info(Window, TRUE);
  //if (Info^.default_width<>Width) or (Info^.default_height<>Height) then
    gtk_window_set_default_size(Window, Width, Height);

  // resize
  gtk_window_resize(Window, Width, Height);
  // reposition
  gtk_window_move(Window, AWinControl.Left, AWinControl.Top);
  // force early resize
  allocation := PGtkWidget(Window)^.allocation;
  allocation.width := Width;
  allocation.height := Height;
  //DebugLn(['SetWindowSizeAndPosition ',DbgSName(AWinControl),' ',dbgs(allocation)]);
  gtk_widget_size_allocate(PGtkWidget(Window), @allocation);// Beware: this triggers callbacks

  if (PGtkWidget(Window)^.Window <> nil) then
  begin
    // resize gdkwindow directly (sometimes the gtk forgets this)
    gdk_window_move_resize(PGtkWidget(Window)^.Window,AWinControl.Left,
      AWinControl.Top,Width,Height)
  end;

  {$IFDEF VerboseSizeMsg}
  DebugLn(['SetWindowSizeAndPosition B ',DbgSName(AWinControl),
    ' Visible=',AWinControl.Visible,
    ' Cur=',PGtkWidget(Window)^.allocation.X,',',PGtkWidget(Window)^.allocation.Y,
    ' New=',AWinControl.Left,',',AWinControl.Top,',',Width,'x',Height]);
  {$ENDIF}
end;

{-------------------------------------------------------------------------------
  GetWidgetRelativePosition
  
  Returns the Left, Top, relative to the client origin of its parent
-------------------------------------------------------------------------------}
procedure GetWidgetRelativePosition(aWidget: PGtkWidget; out Left, Top: integer);
var
  GdkWindow: PGdkWindow;
  LCLControl: TWinControl;
  GtkLeft, GtkTop: GInt;
begin
  Left:=aWidget^.allocation.X;
  Top:=aWidget^.allocation.Y;

  if (aWidget^.parent<>nil)
  and (not GtkWidgetIsA(aWidget^.parent,GTK_TYPE_FIXED))
  and (not GtkWidgetIsA(aWidget^.parent,GTK_TYPE_LAYOUT))
  then begin
    // widget is not on a normal client area. e.g. TPage
    Left:=0;
    Top:=0;
  end
  else
  if (aWidget^.parent<>nil)
  and GtkWidgetIsA(aWidget^.parent,GTK_TYPE_FIXED)
  and GTK_WIDGET_NO_WINDOW(aWidget^.parent)
  then begin
    // widget on a fixed, but fixed w/o window
    Dec(Left, PGtkWidget(aWidget^.parent)^.allocation.x);
    Dec(Top, PGtkWidget(aWidget^.parent)^.allocation.y);
  end;

  if GtkWidgetIsA(aWidget,GTK_TYPE_WINDOW) then begin
    GdkWindow:=GetControlWindow(aWidget);
    if (GdkWindow<>nil) and (GTK_WIDGET_MAPPED(aWidget)) then begin
      // window is mapped = window manager has put the window somewhere
      gdk_window_get_root_origin(GdkWindow, @GtkLeft, @GtkTop);
      Left := GtkLeft;
      Top := GtkTop;
    end else begin
      // the gtk has not yet put the window to the final position
      // => the gtk/gdk position is not reliable
      // => use the LCL coords
      LCLControl:=GetLCLObject(aWidget) as TWinControl;
      Left:=LCLControl.Left;
      Top:=LCLControl.Top;
    end;
    //DebugLn(['TGtkWidgetSet.GetWindowRelativePosition ',GetWidgetDebugReport(aWidget),' Left=',Left,' Top=',Top,' GdkWindow=',GdkWindow<>nil]);
  end;
  //DebugLn(['TGtkWidgetSet.GetWindowRelativePosition ',GetWidgetDebugReport(aWidget),' Left=',Left,' Top=',Top]);
end;

{------------------------------------------------------------------------------
  UnsetResizeRequest
  Params: Widget: PGtkWidget

  Unset the mark for the Widget to send a ResizeRequest to the gtk.
  LCL size requests for a widget are cached and only the last one is sent. Some
  widgets like forms send a resize request immediately. To avoid sending resize
  requests multiple times they can unset the mark with this procedure.
 ------------------------------------------------------------------------------}
procedure UnsetResizeRequest(Widget: PGtkWidget);
begin
  {$IFDEF VerboseSizeMsg}
  if FWidgetsWithResizeRequest.Contains(Widget) then begin
    DebugLn(['UnsetResizeRequest ',GetWidgetDebugReport(Widget)]);
  end;
  {$ENDIF}
  FWidgetsWithResizeRequest.Remove(Widget);
end;

{------------------------------------------------------------------------------
  TGtkWidgetSet SetResizeRequest
  Params: Widget: PGtkWidget

  Marks the widget to send a ResizeRequest to the gtk.
  When the LCL resizes a control the new bounds will not be set directly, but
  cached. This is needed, because it is common behaviour to set the bounds step
  by step. For example: Left:=10; Top:=10; Width:=100; Height:=50; results in
  SetBounds(10,0,0,0);
  SetBounds(10,10,0,0);
  SetBounds(10,10,100,0);
  SetBounds(10,10,100,50);
  Because the gtk puts all size requests into a queue, it will process the
  requests not immediately, but _after_ all requests. This results in changing
  the widget size four times and everytime the LCL gets a message. If the
  control has children, this will resize the children four times.
  Therefore LCL size requests for a widget are cached and only the final one is
  sent in: TGtkWidgetSet.SendCachedLCLMessages.
 ------------------------------------------------------------------------------}
procedure SetResizeRequest(Widget: PGtkWidget);
{$IFDEF VerboseSizeMsg}
var
  LCLControl: TWinControl;
{$ENDIF}
begin
  if not WidgetSizeIsEditable(Widget) then exit;
  {$IFDEF VerboseSizeMsg}
  LCLControl:=TWinControl(GetLCLObject(Widget));
  DbgOut('SetResizeRequest Widget=',DbgS(Widget));
  if LCLControl is TWinControl then
    DebugLn(' ',DbgSName(LCLControl),' LCLBounds=',dbgs(LCLControl.BoundsRect))
  else
    DebugLn(' ERROR: ',DbgSName(LCLControl));
  {$ENDIF}
  if not FWidgetsWithResizeRequest.Contains(Widget) then
    FWidgetsWithResizeRequest.Add(Widget);
end;

{------------------------------------------------------------------------------
  function WidgetSizeIsEditable(Widget: PGtkWidget): boolean;

  True if the widget can be resized.
  False if the size is under complete control of the gtk.
------------------------------------------------------------------------------}
function WidgetSizeIsEditable(Widget: PGtkWidget): boolean;
begin
  if Widget=nil then exit(false);
  if (GtkWidgetIsA(Widget,GTK_TYPE_WINDOW))
  or (GtkWidgetIsA(Widget^.Parent,gtk_fixed_get_type))
  or (GtkWidgetIsA(Widget^.Parent,gtk_layout_get_type))
  then
    Result:=true
  else
    Result:=false;
end;

procedure ReportNotObsolete(const Texts : String);
Begin
  DebugLn('*********************************************');
  DebugLn('*********************************************');
  DebugLn('*************Non-Obsolete report*************');
  DebugLn('*********************************************');
  DebugLn('*************'+Texts+'*is being used yet.****');
  DebugLn('*******Please remove this function from******');
  DebugLn('*******the obsolete section in gtkproc.inc***');
  DebugLn('*********************************************');
  DebugLn('*********************************************');
  DebugLn('*********************************************');
  DebugLn('*********************************************');
end;

function TGDKColorToTColor(const value : TGDKColor) : TColor;
begin
  Result := ((Value.Blue shr 8) shl 16) + ((Value.Green shr 8) shl 8)
           + (Value.Red shr 8);
end;

function TColortoTGDKColor(const value : TColor) : TGDKColor;
var
  newColor : TGDKColor;
begin
  if Value<0 then begin
    FillChar(Result{%H-},SizeOf(Result),0);
    exit;
  end;

  newColor.pixel := 0;
  newColor.red   := (value and $ff) * 257;
  newColor.green := ((value shr 8) and $ff) * 257;
  newColor.blue  := ((value shr 16) and $ff) * 257;

  Result := newColor;
end;

{------------------------------------------------------------------------------
  Function: UpdateSysColorMap
  Params:  none
  Returns: none

  Reads the system colors.
 ------------------------------------------------------------------------------}
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
  if Widget=nil then exit;
  if not (Lgs in [lgsButton, lgsWindow, lgsMenuBar, lgsMenuitem,
    lgsVerticalScrollbar, lgsHorizontalScrollbar, lgsTooltip, lgsComboBox]) then exit;

  {$IFDEF NoStyle}
  exit;
  {$ENDIF}
  //debugln('UpdateSysColorMap ',GetWidgetDebugReport(Widget));
  gtk_widget_set_rc_style(Widget);
  MainStyle := gtk_widget_get_style(Widget);
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
      lgsButton, lgsComboBox:
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
          SysColorMap[COLOR_HIGHLIGHT] := TGDKColorToTColor(base[GTK_STATE_SELECTED]);
          SysColorMap[COLOR_HIGHLIGHTTEXT] := TGDKColorToTColor(fg[GTK_STATE_SELECTED]);
          SysColorMap[COLOR_WINDOW] := TGDKColorToTColor(base[GTK_STATE_NORMAL]);
          SysColorMap[COLOR_WINDOWTEXT] := TGDKColorToTColor(text[GTK_STATE_NORMAL]);
          SysColorMap[COLOR_HOTLIGHT] := TGDKColorToTColor(light[GTK_STATE_NORMAL]);
          SysColorMap[COLOR_BACKGROUND] := TGDKColorToTColor(bg[GTK_STATE_PRELIGHT]);
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


{------------------------------------------------------------------------------
  Function: WaitForClipbrdAnswerDummyTimer
  
  this is a helper function for WaitForClipboardAnswer
 ------------------------------------------------------------------------------}
function WaitForClipbrdAnswerDummyTimer(Client: Pointer): gboolean; cdecl;
begin
  if CLient=nil then ;
  Result:=GdkTrue; // go on, make sure getting a message at least every second
end;

function GetScreenWidthMM(GdkValue: boolean): integer;
begin
  Result:=gdk_screen_width_mm;
  if (Result<=0) and not GdkValue then
    Result:=300; // some TV-out screens don't know there size
end;

function GetScreenHeightMM(GdkValue: boolean): integer;
begin
  Result:=gdk_screen_height_mm;
  if (Result<=0) and not GdkValue then
    Result:=300; // some TV-out screens don't know there size
end;

{------------------------------------------------------------------------------
  Function: WaitForClipboardAnswer
  Params: none
  Returns: true, if clipboard data arrived

  waits til clipboard/selection answer arrived (max 1 second)
  ! While waiting the messagequeue will be processed !
 ------------------------------------------------------------------------------}
function WaitForClipboardAnswer(c: PClipboardEventData): boolean;
var
  Timer: cardinal;
  StartTime: TDateTime;

  function ValidDateSelection : boolean;
  begin
    result := c^.Data.Selection<>0;
  end;
  
begin
  Result:=false;
  {$IFDEF DEBUG_CLIPBOARD}
  DebugLn('[WaitForClipboardAnswer] A');
  {$ENDIF}
  if (ValidDateSelection) or (c^.Waiting) or (c^.Stopping) then begin
    {$IFDEF DEBUG_CLIPBOARD}
    DebugLn('[WaitForClipboardAnswer] ValidDateSelection=',dbgs(ValidDateSelection),' Waiting=',dbgs(c^.Waiting),' Stopping=',dbgs(c^.Stopping));
    {$ENDIF}
    Result:=(ValidDateSelection);
    exit;
  end;
  c^.Waiting:=true;
  StartTime:=Now;
  //DebugLn('[WaitForClipboardAnswer] C');
  Application.ProcessMessages;
  //DebugLn('[WaitForClipboardAnswer] D');
  if (ValidDateSelection) or (c^.Stopping) then begin
    {$IFDEF DEBUG_CLIPBOARD}
    DebugLn('[WaitForClipboardAnswer] E  Yeah, Response received after processing messages');
    {$ENDIF}
    Result:=(ValidDateSelection);
    exit;
  end;
  //DebugLn('[WaitForClipboardAnswer] F');
  // start a timer to make sure not waiting forever
  Timer := gtk_timeout_add(500, @WaitForClipbrdAnswerDummyTimer, nil);
  try
    repeat
      // just wait ...
      {$IFDEF DEBUG_CLIPBOARD}
      DebugLn('[WaitForClipboardAnswer] G');
      {$ENDIF}
      Application.ProcessMessages;
      if (ValidDateSelection) or (c^.Stopping) then begin
        {$IFDEF DEBUG_CLIPBOARD}
        DebugLn('[WaitForClipboardAnswer] H  Yeah, Response received after waiting with timer');
        {$ENDIF}
        Result:=(ValidDateSelection);
        exit;
      end;
      // give the system some time to process the request
      Sleep(1);
    until Abs(StartTime-Now)*86400>1.0; // wait at most a second
  finally
    {$IFDEF DEBUG_CLIPBOARD}
    DebugLn('[WaitForClipboardAnswer] H');
    {$ENDIF}
    // stop the timer
    gtk_timeout_remove(Timer);
    //DebugLn('[WaitForClipboardAnswer] END');
  end;
  { $IFDEF DEBUG_CLIPBOARD}
  DebugLn('[WaitForClipboardAnswer] WARNING: no answer received in time');
  { $ENDIF}
end;

{------------------------------------------------------------------------------
  Function: RequestSelectionData
  Params: ClipboardWidget - widget with connected signals 'selection_get'
                            and 'selection_clear_event'
          ClipboardType
          FormatID - the selection target format wanted
  Returns: the TGtkSelectionData record

  requests the format FormatID of clipboard of type ClipboardType and
  waits til clipboard/selection answer arrived (max 1 second)
  ! While waiting the messagequeue will be processed !
 ------------------------------------------------------------------------------}
function RequestSelectionData(ClipboardWidget: PGtkWidget;
  ClipboardType: TClipboardType; FormatID: PtrUInt): TGtkSelectionData;
var
  StartTime: TDateTime;
  TimeID: cardinal;
  EventData: PClipboardEventData;
  TypeAtom: TGdkAtom;
begin
  {$IFDEF DEBUG_CLIPBOARD}
  DebugLn('[RequestSelectionData] FormatID=',dbgs(FormatID));
  {$ENDIF}
  FillChar(Result{%H-},SizeOf(TGtkSelectionData),0);
  if (ClipboardWidget=nil) or (FormatID=0) 
  or (ClipboardTypeAtoms[ClipboardType]=0) then exit;

  if ClipboardSelectionData.Count > 0 then begin
    { Multiple outstanding requests seems to cause problems, so
      wait for most recent request (if any) before starting a new one }
    StartTime := Now;
    while not WaitForClipboardAnswer(PClipboardEventData(ClipboardSelectionData[ClipboardSelectionData.Count-1])) do begin
      Application.ProcessMessages;
      if Now - StartTime > 1000/MSecsPerDay then
        Exit; { Previous request timed out, so don't wait for another timeout period }
    end;
  end;
  New(EventData);
  FillChar(EventData^,SizeOf(TClipboardEventData),0);
  TimeID:= gdk_event_get_time(gtk_get_current_event);
  // IMPORTANT: To retrieve data from xterm or kde applications the time id must be 0 or event^.time
  EventData^.TimeID:=TimeID;
  ClipboardSelectionData.Add(EventData);
  try
    TypeAtom := ClipboardTypeAtoms[ClipboardType];
    {$IFDEF DEBUG_CLIPBOARD}
    DebugLn('[RequestSelectionData] TimeID=',dbgs(TimeID),' Type=',GdkAtomToStr(TypeAtom),' FormatID=',GdkAtomToStr(FormatID));
    {$ENDIF}
    if gtk_selection_convert(ClipboardWidget,TypeAtom,FormatID,TimeID) <> GdkFalse then
    begin
      gtk_clipboard_wait_for_contents(gtk_clipboard_get(TypeAtom), FormatID);
      Result:=EventData^.Data;
    end;
  finally
    ClipboardSelectionData.Remove(EventData);
    Dispose(EventData);
  end;
end;

{------------------------------------------------------------------------------
  Function: FreeClipboardTargetEntries
  Params: ClipboardType
  Returns: -

  frees the memory of a ClipboardTargetEntries list
 ------------------------------------------------------------------------------}
procedure FreeClipboardTargetEntries(ClipboardType: TClipboardType);
var i: integer;
begin
  if ClipboardTargetEntries[ClipboardType]<>nil then begin
    for i:=0 to ClipboardTargetEntryCnt[ClipboardType]-1 do
      StrDispose(ClipboardTargetEntries[ClipboardType][i].Target);
    FreeMem(ClipboardTargetEntries[ClipboardType]);
  end;
end;


{------------------------------------------------------------------------------
  function GdkAtomToStr(const Atom: TGdkAtom): string;

  Returns the associated string
 ------------------------------------------------------------------------------}
function GdkAtomToStr(const Atom: TGdkAtom): string;
var
  p: Pgchar;
begin
  p:=gdk_atom_name(Atom);
  Result:=p;
  if p<>nil then g_free(p);
end;

{-------------------------------------------------------------------------------
  function CreateFormContents(AForm: TCustomForm;
    var FormWidget: Pointer): Pointer;

  Creates the contents for the form (normally a hbox plus a client area.
  The hbox is needed for the menu.) The FormWidget is the main widget, for which
  the client area is associated. If FormWidget=nil then the hbox will be used
  as main widget.
-------------------------------------------------------------------------------}
function CreateFormContents(AForm: TCustomForm;
  var FormWidget: Pointer; AWidgetInfo: PWidgetInfo = nil): Pointer;
var
  ScrolledWidget, ClientAreaWidget: PGtkWidget;
//  WindowStyle: PGtkStyle;
  Adjustment: PGtkAdjustment;
begin
  // Create the VBox. We need that to place controls outside
  // the client area (like menu)
  Result := gtk_vbox_new(False, 0);

  if FormWidget = nil then
    FormWidget := Result;

  // Create the form client area (a scrolled window with a gtklayout
  // with the style of a window)
  ScrolledWidget := gtk_scrolled_window_new(nil, nil);
  gtk_box_pack_end(Result, ScrolledWidget, True, True, 0);
  gtk_widget_show(ScrolledWidget);

  ClientAreaWidget := gtk_layout_new(nil, nil);
  // issue #16183: not sure why the GtkLayout is given a GtkWindow style here,
  // this prevents setting color to the GtkLayout
//  WindowStyle := GetStyle(lgsWindow);
//  gtk_widget_set_style(ClientAreaWidget, WindowStyle);
  //debugln('CreateFormContents Style=',GetStyleDebugReport(WindowStyle));
  gtk_container_add(PGtkContainer(ScrolledWidget), ClientAreaWidget);

  g_object_set_data(FormWidget, odnScrollArea, ScrolledWidget);

  gtk_widget_show(ClientAreaWidget);
  SetFixedWidget(FormWidget, ClientAreaWidget);
  SetMainWidget(FormWidget, ClientAreaWidget);

  if ScrolledWidget <> nil then
  begin
    GTK_WIDGET_UNSET_FLAGS(PGtkScrolledWindow(ScrolledWidget)^.hscrollbar,
                           GTK_CAN_FOCUS);
    GTK_WIDGET_UNSET_FLAGS(PGtkScrolledWindow(ScrolledWidget)^.vscrollbar,
                           GTK_CAN_FOCUS);
    gtk_scrolled_window_set_policy(PGtkScrolledWindow(ScrolledWidget),
                                   GTK_POLICY_NEVER,GTK_POLICY_NEVER);
                                   
    Adjustment := gtk_scrolled_window_get_vadjustment(PGTKScrolledWindow(ScrolledWidget));
    if Adjustment <> nil then
      g_object_set_data(PGObject(Adjustment), odnScrollBar,
        PGTKScrolledWindow(ScrolledWidget)^.vscrollbar);

    Adjustment := gtk_scrolled_window_get_hadjustment(PGTKScrolledWindow(ScrolledWidget));
    if Adjustment <> nil then
      g_object_set_data(PGObject(Adjustment), odnScrollBar,
        PGTKScrolledWindow(ScrolledWidget)^.hscrollbar);

    if (AWidgetInfo <> nil) and
      (gtk_major_version >= 2) and (gtk_minor_version > 8) then
    begin
      g_signal_connect(PGTKScrolledWindow(ScrolledWidget)^.hscrollbar, 'change-value',
        TGCallback(@Gtk2RangeScrollCB), AWidgetInfo);
      g_signal_connect(PGTKScrolledWindow(ScrolledWidget)^.vscrollbar, 'change-value',
        TGCallback(@Gtk2RangeScrollCB), AWidgetInfo);
      g_signal_connect(PGTKScrolledWindow(ScrolledWidget)^.hscrollbar, 'value-changed',
        TGCallback(@Gtk2RangeValueChanged), AWidgetInfo);
      g_signal_connect(PGTKScrolledWindow(ScrolledWidget)^.vscrollbar, 'value-changed',
        TGCallback(@Gtk2RangeValueChanged), AWidgetInfo);
      g_signal_connect(PGTKScrolledWindow(ScrolledWidget)^.hscrollbar, 'button-press-event',
        TGCallback(@Gtk2RangeScrollPressCB), AWidgetInfo);
      g_signal_connect(PGTKScrolledWindow(ScrolledWidget)^.hscrollbar, 'button-release-event',
        TGCallback(@Gtk2RangeScrollReleaseCB), AWidgetInfo);
      g_signal_connect(PGTKScrolledWindow(ScrolledWidget)^.vscrollbar, 'button-press-event',
        TGCallback(@Gtk2RangeScrollPressCB), AWidgetInfo);
      g_signal_connect(PGTKScrolledWindow(ScrolledWidget)^.vscrollbar, 'button-release-event',
        TGCallback(@Gtk2RangeScrollReleaseCB), AWidgetInfo);
    end;

  end;
end;

function IndexOfStyle(aStyle: TLazGtkStyle): integer;
begin
  Result:=IndexOfStyleWithName(LazGtkStyleNames[aStyle]);
end;

{------------------------------------------------------------------------------
  Function: IndexOfWithNameStyle
  Params: WName
  Returns: Index of Style

  Returns the Index within the Styles property of WNAME
 ------------------------------------------------------------------------------}
function IndexOfStyleWithName(const WName : String): integer;
begin
  if Styles<>nil then begin
    for Result:=0 to Styles.Count-1 do
      if CompareText(WName,Styles[Result])=0 then exit;
  end;
  Result:=-1;
end;

{------------------------------------------------------------------------------
  Function: ReleaseStyle
  Params: WName
  Returns: nothing

  Tries to release a Style corresponding to the Widget Name passed, aka 'button',
  'default', checkbox', etc. This should only be called on theme change or on
  application terminate.
 ------------------------------------------------------------------------------}
function NewStyleObject : PStyleObject;
begin
  New(Result);
  FillChar(Result^, SizeOf(TStyleObject), 0);
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
      if GTK_WIDGET_TOPLEVEL(StyleObject^.Owner) then
        gtk_widget_destroy(StyleObject^.Owner)
      else
        g_object_unref(StyleObject^.Owner);
    end;
    if StyleObject^.Style <> nil then
      if StyleObject^.Style^.attach_count > 0 then
        gtk_style_unref(StyleObject^.Style);
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
  if Styles=nil then exit;

  if DefaultPangoLayout<>nil then begin
    g_object_unref(DefaultPangoLayout);
    DefaultPangoLayout:=nil;
  end;

  for i:=Styles.Count-1 downto 0 do begin
    StyleObject:=PStyleObject(Styles.Objects[i]);
    FreeStyleObject(StyleObject);
  end;
  Styles.Clear;
  for lgs:=Low(TLazGtkStyle) to High(TLazGtkStyle) do
    StandardStyles[lgs]:=nil;
end;

procedure ReleaseStyle(aStyle: TLazGtkStyle);
var
  StyleObject: PStyleObject;
  l: Integer;
begin
  if Styles=nil then exit;
  if aStyle in [lgsUserDefined] then
    RaiseGDBException('');// user styles are defined by name
  StyleObject:=StandardStyles[aStyle];
  if StyleObject<>nil then begin
    l:=IndexOfStyle(aStyle);
    Styles.Delete(l);
    StandardStyles[aStyle]:=nil;
    FreeStyleObject(StyleObject);
  end;
end;

procedure ReleaseStyleWithName(const WName : String);
var
  l : Longint;
  s : PStyleObject;
begin
  if Styles=nil then exit;
  l := IndexOfStyleWithName(WName);
  If l >= 0 then begin
    If Styles.Objects[l] <> nil then
      Try
        s := PStyleObject(Styles.Objects[l]);
        FreeStyleObject(S);
      Except
        DebugLn('[ReleaseStyle] : Unable To Unreference Style');
      end;
    Styles.Delete(l);
  end;
end;

function GetStyle(aStyle: TLazGtkStyle): PGTKStyle;
begin
  if Styles = nil then Exit(nil);
  if aStyle in [lgsUserDefined] then
    RaiseGDBException(''); // user styles are defined by name
  if StandardStyles[aStyle] <> nil then // already created
    Result := StandardStyles[aStyle]^.Style
  else // create it
    Result := GetStyleWithName(LazGtkStyleNames[aStyle]);
end;

procedure tooltip_window_style_set(Widget: PGtkWidget; {%H-}PreviousStyle: PGtkStyle;
          StyleObject: PStyleObject); cdecl;
begin
  StyleObject^.Style := gtk_widget_get_style(Widget);
  UpdateSysColorMap(Widget, lgsToolTip);
end;

{------------------------------------------------------------------------------
  Function: GetStyleWithName
  Params: none
  Returns: Returns a Corresponding Style

  Tries to get the Style corresponding to the Widget Name passed, aka 'button',
  'default', checkbox', etc. for use within such routines as DrawFrameControl
  to attempt to supply theme dependent drawing. Styles are stored in a TStrings
  list which is only updated on theme change, to ensure fast efficient retrieval
  of Styles.
 ------------------------------------------------------------------------------}
function GetStyleWithName(const WName: String) : PGTKStyle;
var
  StyleObject : PStyleObject;

  function CreateStyleNotebook: PGTKWidget;
  var
    NoteBookWidget: PGtkNotebook;
    //NoteBookPageWidget: PGtkWidget;
    NoteBookPageClientAreaWidget: PGtkWidget;
    NoteBookTabLabel: PGtkWidget;
    NoteBookTabMenuLabel: PGtkWidget;
  begin
    Result:=gtk_notebook_new;
    NoteBookWidget := PGtkNoteBook(Result);
    //NoteBookPageWidget := gtk_hbox_new(false, 0);
    NoteBookPageClientAreaWidget := CreateFixedClientWidget{$IFNDEF GtkFixedWithWindow}(false){$ENDIF};
    gtk_widget_show(NoteBookPageClientAreaWidget);
    //gtk_container_add(GTK_CONTAINER(NoteBookPageWidget),
    //                  NoteBookPageClientAreaWidget);
    //gtk_widget_show(NoteBookPageWidget);
    NoteBookTabLabel:=gtk_label_new('Lazarus');
    gtk_widget_show(NoteBookTabLabel);
    NoteBookTabMenuLabel:=gtk_label_new('Lazarus');
    gtk_widget_show(NoteBookTabMenuLabel);
    gtk_notebook_append_page_menu(NoteBookWidget,NoteBookPageClientAreaWidget,
                                  NoteBookTabLabel,NoteBookTabMenuLabel);
    gtk_widget_set_usize(Result,400,400);
  end;
  
  procedure ResizeWidget(CurWidget: PGTKWidget; NewWidth, NewHeight: integer);
  var
    allocation: TGtkAllocation;
  begin
    allocation.x:=0;
    allocation.y:=0;
    allocation.width:=NewWidth;
    allocation.height:=NewHeight;
    //gtk_widget_set_usize(StyleObject^.Widget,NewWidth,NewHeight);
    gtk_widget_size_allocate(CurWidget,@allocation);
    StyleObject^.FrameBordersValid:=false;
  end;

var
  Tp : Pointer;
  l : Longint;
  lgs: TLazGtkStyle;
  WidgetName: String;
  AddToStyleWindow: Boolean;
  AddReference: Boolean;
  StyleWindowWidget: PGtkWidget;
  Requisition: TGtkRequisition;
  WindowFixedWidget: PGtkWidget;
  VBox: PGtkWidget;
  lscreen: PGdkScreen;
  lscreenrect: TGdkRectangle;
begin
  Result := nil;
  if Styles=nil then exit;
  {$IFDEF NoStyle}
  exit;
  {$ENDIF}
  
  if (WName='') then exit;
  l:=IndexOfStyleWithName(WName);
  //DebugLn(['GetStyleWithName START ',WName,' ',l]);

  if l >= 0 then
  begin
    StyleObject:=PStyleObject(Styles.Objects[l]);
    Result := StyleObject^.Style;
  end else
  begin
    // create a new style object
    StyleObject := NewStyleObject;
    lgs := lgsUserDefined;
    Tp := nil;
    AddToStyleWindow := True;
    AddReference := True;
    WidgetName := 'LazStyle' + WName;
    // create a style widget
    If CompareText(WName,LazGtkStyleNames[lgsButton])=0 then begin
        StyleObject^.Widget := GTK_BUTTON_NEW;
        lgs:=lgsButton;
      end
    else
      If CompareText(WName,LazGtkStyleNames[lgsLabel])=0 then begin
        StyleObject^.Widget := GTK_LABEL_NEW('StyleLabel');
        lgs:=lgsLabel;
      end
    else
      If CompareText(WName,LazGtkStyleNames[lgsDefault])=0 then begin
        lgs:=lgsDefault;
        AddToStyleWindow:=false;
        AddReference:=false;
        // GTK2 does not allow to instantiate the abstract base Widget
        // so we use the "invisible" widget, which should never be defined
        // by the theme.
        // It is created with a real reference count=1 (not floating)
        // because it is a treated as top level widget.
        StyleObject^.Widget := gtk_invisible_new;
      end
    else
      If CompareText(WName,LazGtkStyleNames[lgsWindow])=0 then begin
        lgs:=lgsWindow;
        StyleObject^.Widget := GTK_WINDOW_NEW(GTK_WINDOW_TOPLEVEL);
        AddToStyleWindow:=false;
        AddReference:=false;
        gtk_widget_hide(StyleObject^.Widget);
        // create the fixed widget
        // (where to put all style widgets, that need a parent for realize)
        VBox:=gtk_vbox_new(false,0);// vbox is needed for menu above and fixed widget below
        gtk_widget_show(VBox);
        gtk_container_add(PGtkContainer(StyleObject^.Widget), VBox);
        g_object_set_data(PGObject(StyleObject^.Widget),'vbox',VBox);
        WindowFixedWidget:=CreateFixedClientWidget;
        gtk_widget_show(WindowFixedWidget);
        gtk_container_add(PGtkContainer(VBox), WindowFixedWidget);
        g_object_set_data(PGObject(StyleObject^.Widget),'fixedwidget',WindowFixedWidget);
        gtk_widget_realize(StyleObject^.Widget);
      end
    else
      If CompareText(WName,LazGtkStyleNames[lgsCheckbox])=0 then begin
        lgs:=lgsCheckbox;
        StyleObject^.Widget := GTK_CHECK_BUTTON_NEW;
      end
    else
      If CompareText(WName,LazGtkStyleNames[lgsComboBox])=0 then begin
        lgs:=lgsComboBox;
        StyleObject^.Widget := gtk_combo_box_new;
      end
    else
      If CompareText(WName,LazGtkStyleNames[lgsRadiobutton])=0 then begin
        lgs:=lgsRadiobutton;
        StyleObject^.Widget := GTK_RADIO_BUTTON_NEW(nil);
      end
    else
      if CompareText(WName,LazGtkStyleNames[lgsMenu])=0 then
      begin
        lgs:=lgsMenu;
        StyleObject^.Widget := gtk_menu_new;
        // we need REAL menu size for SM_CYMENU
        // menuitem will be destroyed with menu by gtk.
        VBox := gtk_menu_item_new_with_label('DUMMYITEM');
        gtk_menu_shell_append(PGtkMenuShell(StyleObject^.Widget), VBox);
      end
    else
      If CompareText(WName,LazGtkStyleNames[lgsMenuBar])=0 then begin
        lgs:=lgsMenuBar;
        StyleObject^.Widget := gtk_menu_bar_new;
      end
    else
      If CompareText(WName,LazGtkStyleNames[lgsMenuitem])=0 then begin
        lgs:=lgsMenuitem;
        // image menu item is needed to correctly return theme options
        StyleObject^.Widget := gtk_image_menu_item_new;
      end
    else
      If CompareText(WName,LazGtkStyleNames[lgsStatusBar])=0 then begin
        lgs:=lgsStatusBar;
        AddToStyleWindow:=true;
        StyleObject^.Widget := gtk_statusbar_new;
      end
    else
      If CompareText(WName,LazGtkStyleNames[lgsCalendar])=0 then begin
        lgs:=lgsCalendar;
        AddToStyleWindow:=true;
        StyleObject^.Widget := gtk_calendar_new;
      end
    else
      If CompareText(WName,LazGtkStyleNames[lgsList])=0 then begin
        lgs:=lgsList;
        StyleObject^.Widget := gtk_list_new;
      end
    else
      If CompareText(WName,LazGtkStyleNames[lgsVerticalScrollbar])=0 then begin
        lgs:=lgsVerticalScrollbar;
        StyleObject^.Widget := gtk_vscrollbar_new(nil);
      end
    else
      If CompareText(WName,LazGtkStyleNames[lgsHorizontalScrollbar])=0 then begin
        lgs:=lgsHorizontalScrollbar;
        StyleObject^.Widget := gtk_hscrollbar_new(nil);
      end
    else
      If CompareText(WName,LazGtkStyleNames[lgsVerticalPaned])=0 then begin
        lgs:=lgsVerticalPaned;
        StyleObject^.Widget := gtk_vpaned_new;
      end
    else
      If CompareText(WName,LazGtkStyleNames[lgsHorizontalPaned])=0 then begin
        lgs:=lgsHorizontalPaned;
        StyleObject^.Widget := gtk_hpaned_new;
      end
    else
      If CompareText(WName,LazGtkStyleNames[lgsNotebook])=0 then begin
        lgs:=lgsNotebook;
        StyleObject^.Widget := CreateStyleNotebook;
      end
    else
      if CompareText(WName,LazGtkStyleNames[lgsTooltip])=0 then
      begin
        lgs := lgsTooltip;
        Tp := gtk_tooltips_new;
        gtk_tooltips_force_window(Tp);
        StyleObject^.Widget := PGTKTooltips(Tp)^.Tip_Window;

        g_signal_connect(StyleObject^.Widget, 'style-set',
          TGCallback(@tooltip_window_style_set), StyleObject);

        WidgetName := 'gtk-tooltip-lcl';
        StyleObject^.Owner := Tp;
        Tp := nil;
      end
    else
      If CompareText(WName,LazGtkStyleNames[lgsHScale])=0 then begin
        lgs:=lgsHScale;
        TP := PGtkWidget( gtk_adjustment_new (0, 0, 100, 1, 10, 0));
        StyleObject^.Widget := gtk_hscale_new (PGTKADJUSTMENT (TP));
      end
    else
      If CompareText(WName,LazGtkStyleNames[lgsVScale])=0 then begin
        lgs:=lgsVScale;
        TP := PGtkWidget( gtk_adjustment_new (0, 0, 100, 1, 10, 0));
        StyleObject^.Widget := gtk_vscale_new (PGTKADJUSTMENT (TP));
      end
    else
      If CompareText(WName,LazGtkStyleNames[lgsGroupBox])=0 then begin
        lgs:=lgsGroupBox;
        StyleObject^.Widget := gtk_frame_new('GroupBox');
        WindowFixedWidget:=CreateFixedClientWidget{$IFNDEF GtkFixedWithWindow}(false){$ENDIF};
        gtk_widget_show(WindowFixedWidget);
        gtk_container_add(PGtkContainer(StyleObject^.Widget), WindowFixedWidget);
        g_object_set_data(PGObject(StyleObject^.Widget),'fixedwidget',WindowFixedWidget);
      end

    else
      If CompareText(WName,LazGtkStyleNames[lgsTreeView])=0 then begin
        lgs:=lgsTreeView;
        StyleObject^.Widget := gtk_tree_view_new;
      end

    else
      If CompareText(WName,LazGtkStyleNames[lgsToolBar])=0 then begin
        lgs:=lgsToolBar;
        StyleObject^.Widget := gtk_toolbar_new;
      end
    else
      If CompareText(WName,LazGtkStyleNames[lgsToolButton])=0 then begin
        lgs:=lgsToolButton;
        StyleObject^.Widget := PGtkWidget(gtk_tool_button_new(nil, 'B'));
        gtk_toolbar_insert(PGtkToolbar(GetStyleWidget(lgsToolBar)), PGtkToolItem(StyleObject^.Widget), -1);
      end
    else
      if CompareText(WName,LazGtkStyleNames[lgsScrolledWindow])=0 then begin
        lgs:=lgsScrolledWindow;
        StyleObject^.Widget := gtk_scrolled_window_new(nil, nil);
      end
    else
      If CompareText(WName,LazGtkStyleNames[lgsGTK_Default])=0 then begin
        lgs:=lgsGTK_Default;
        AddToStyleWindow:=false;
        StyleObject^.Widget := nil;
        StyleObject^.Style := gtk_style_new;
      end
    else begin
      // unknown style name -> bug
      FreeStyleObject(StyleObject);
      AddToStyleWindow:=false;
      RaiseGDBException('');
    end;
    
    if (lgs<>lgsUserDefined) and (StandardStyles[lgs]<>nil) then begin
      // consistency error
      RaiseGDBException('');
    end;

    // ensure style of the widget
    If (StyleObject^.Widget <> nil) then begin

      if not Assigned(StyleObject^.Owner) then
        StyleObject^.Owner := StyleObject^.Widget;

      // Widgets are created with a floating reference, except for top level.
      // Here the floating reference is acquired, or reference count increased
      // in case the floating reference is already owned (the widget has been
      // added to a container).
      if AddReference then
      begin
        if g_object_ref_sink = nil then
        begin
          // Deprecated since 2.10.
          gtk_object_ref(PGtkObject(StyleObject^.Owner));
          gtk_object_sink(PGtkObject(StyleObject^.Owner));
        end
        else
          g_object_ref_sink(PGObject(StyleObject^.Owner));
      end;

      // Put style widget on style window, so that it can be realized.
      if AddToStyleWindow then
      begin
        gtk_widget_show_all(StyleObject^.Widget);
        if GtkWidgetIsA(StyleObject^.Widget,GTK_TYPE_MENU) then
        begin
          // Do nothing. Don't need to attach it to a widget to get the style.
        end
        else
        if GtkWidgetIsA(StyleObject^.Widget,GTK_TYPE_MENU_BAR) then
        begin
          StyleWindowWidget:=GetStyleWidget(lgsWindow);
          // add menu above the forms client area (fixed widget)
          VBox:=PGTKWidget(
                     g_object_get_data(PGObject(StyleWindowWidget),'vbox'));
          gtk_box_pack_start(PGTKBox(VBox), StyleObject^.Widget, False, False, 0);
        end
        else
        if GtkWidgetIsA(StyleObject^.Widget,GTK_TYPE_MENU_ITEM) then
        begin
          gtk_menu_bar_append( GetStyleWidget(lgsMenuBar), StyleObject^.Widget);
        end
        else
        if (lgs = lgsToolButton) or
           (lgs = lgsTooltip) then
        begin
          // already on a parent => nothing to do
        end
        else
        begin
          StyleWindowWidget:=GetStyleWidget(lgsWindow);
          // add widget on client area of form
          WindowFixedWidget:=PGTKWidget(
                 g_object_get_data(PGObject(StyleWindowWidget),'fixedwidget'));
          //DebugLn('GetStyleWithName adding on hidden stylewindow ',WName,' ',GetWidgetDebugReport(StyleObject^.Widget));
          if WindowFixedWidget <> nil then
            gtk_fixed_put(PGtkFixed(WindowFixedWidget),StyleObject^.Widget,10,10);
        end;
      end;

      gtk_widget_set_name(StyleObject^.Widget,PChar(WidgetName));
      gtk_widget_ensure_style(StyleObject^.Widget);

      // request default sizing
      FillChar(Requisition{%H-},SizeOf(Requisition),0);
      gtk_widget_size_request(StyleObject^.Widget, @Requisition);
      
      StyleObject^.Style:=gtk_widget_get_style(StyleObject^.Widget);
      // ToDo: find out, why sometimes the style is not initialized.
      // for example: why the following occurs:
      if CompareText(WName,'button')=0 then begin
        if StyleObject^.Style^.light_gc[GTK_STATE_NORMAL]=nil then begin
          //DebugLn('GetStyleWithName ',WName);
        end;
      end;
      if AddToStyleWindow then begin
        if not GtkWidgetIsA(StyleObject^.Widget,GTK_WINDOW_GET_TYPE) then begin
          //DebugLn(['GetStyleWithName realizing ...']);
          gtk_widget_realize(StyleObject^.Widget);
          //treeview columns must be added after realize otherwise they will have invalid styles
          if lgs = lgsTreeView then
          begin
            gtk_tree_view_append_column(PGtkTreeView(StyleObject^.Widget), gtk_tree_view_column_new);
            gtk_tree_view_append_column(PGtkTreeView(StyleObject^.Widget), gtk_tree_view_column_new);
            gtk_tree_view_append_column(PGtkTreeView(StyleObject^.Widget), gtk_tree_view_column_new);
          end;
          //DebugLn('AddToStyleWindow realized: ',WName,' ',GetWidgetDebugReport(StyleObject^.Widget));
        end;
        lscreen := gdk_screen_get_default();
        gdk_screen_get_monitor_geometry(lscreen, 0, @lscreenrect);
        ResizeWidget(StyleObject^.Widget,lscreenrect.width,lscreenrect.height);
      end;
    end;

    // increase refcount of style
    if StyleObject^.Style <> nil then
      if CompareText(WName,LazGtkStyleNames[lgsGTK_Default])<>0 then
        StyleObject^.Style := GTK_Style_Ref(StyleObject^.Style);
        
    // if successful add to style objects list
    if StyleObject^.Style <> nil then
    begin
      Styles.AddObject(WName, TObject(StyleObject));
      if lgs <> lgsUserDefined then
        StandardStyles[lgs] := StyleObject;
      Result := StyleObject^.Style;
      UpdateSysColorMap(StyleObject^.Widget, lgs);
        
      // ToDo: create all gc of the style
      //gtk_widget_set_rc_style(StyleObject^.Widget);

      if lgs = lgsTooltip then
        gtk_widget_hide_all(StyleObject^.Widget);
    end
    else begin
      // no success, clean up
      FreeStyleObject(StyleObject);
      DebugLn('WARNING: GetStyleWithName ',WName,' failed');
    end;

    // clean up
    if Tp <> nil then
      gtk_object_destroy(Tp);
  end;
end;

function GetStyleWidget(aStyle: TLazGtkStyle) : PGTKWidget;
begin
  if aStyle in [lgsUserDefined] then
    RaiseGDBException('');// user styles are defined by name
  if StandardStyles[aStyle]<>nil then
    // already created
    Result:=StandardStyles[aStyle]^.Widget
  else
    // create it
    Result:=GetStyleWidgetWithName(LazGtkStyleNames[aStyle]);
end;

function GetStyleWidgetWithName(const WName : String) : PGTKWidget;
var
  l : Longint;
begin
  Result := nil;
  // init style
  GetStyleWithName(WName);
  // return widget
  l:=IndexOfStyleWithName(WName);
  if l>=0 then
    Result := PStyleObject(Styles.Objects[l])^.Widget;
end;

{------------------------------------------------------------------------------
  Function: LoadDefaultFont(Desc)
  Params: none
  Returns: Returns the default Font

  For Text/Font Routines: if the Font is invalid, this can be used instead, or
  if the DT_internal flag is used(aka use system font) this is used. This is
  also the font returned by GetStockObject(SYSTEM_FONT).

  It attempts to get the font from the default Style, or if none is available,
  a new style(aka try and get GTK builtin values), if that fails tries to get
  a generic fixed font, if THAT fails, it gets whatever font is available.
  If the result is not nil it MUST be GDK_FONT_UNREF'd when done.
 ------------------------------------------------------------------------------}
function LoadDefaultFont: TGtkIntfFont;
begin
  Result:=gtk_widget_create_pango_layout(GetStyleWidget(lgsdefault), nil);
  If Result <> nil then
    ReferenceGtkIntfFont(Result);
end;

function LoadDefaultFontDesc: PPangoFontDescription;
var
  Style : PGTKStyle;
begin
  Result := nil;
  
  {$IFDEF VerboseGtkToDos}{$WARNING ToDo LoadDefaultFontDesc: get a working default pango font description}{$ENDIF}
  Result := pango_font_description_from_string('sans 12');

  exit;
  
  Style := GetStyle(lgsLabel);
  if Style = nil then
    Style := GetStyle(lgsDefault);
  if Style = nil then
    Style := GetStyle(lgsGTK_Default);

  If (Style <> nil) then begin
    Result := pango_font_description_copy(Style^.font_desc);
  end;

  If Result = nil then
    Result := pango_font_description_from_string('sans 12');

  if Result = nil then
    Result := pango_font_description_from_string('12');
end;

function GetDefaultFontName: string;
var
  Style: PGtkStyle;
  PangoFontDesc: PPangoFontDescription;
begin
  Result:='';
  Style := GetStyle(lgsDefault);
  if Style = nil then
    Style := GetStyle(lgsGTK_Default);

  If Style <> nil then begin
    If (Style <> nil) then begin
      PangoFontDesc := Style^.font_desc;
      if PangoFontDesc<>nil then begin
        Result:=pango_font_description_get_family(PangoFontDesc);
      end;
    end;
  end;
  {$IFDEF VerboseFonts}
  DebugLn('GetDefaultFontName: DefaultFont=',result);
  {$ENDIF}
end;

procedure RealizeGDKColor(ColorMap: PGdkColormap; Color: PGDKColor);
var
  AllocResult: gboolean;
begin
  if ColorMap=nil then ColorMap:=gdk_colormap_get_system;
  if (Color^.pixel = 0)
  and ((Color^.red<>0) or (Color^.blue<>0) or (Color^.green<>0)) then
    gdk_colormap_alloc_colors(ColorMap, Color, 1, false, true, @AllocResult)
  else
    gdk_colormap_query_color(ColorMap, Color^.pixel, Color);
end;

procedure RealizeGtkStyleColor(Style: PGTKStyle; Color: PGDKColor);
begin
  if (Style<>nil) then
    RealizeGDKColor(Style^.ColorMap,Color)
  else
    RealizeGDKColor(nil,Color);
end;

function GetSysGCValues(Color: TColorRef;
  ThemeWidget: PGtkWidget): TGDKGCValues;
// ThemeWidget can be nil

  function GetWidgetWithBackgroundWindow(Widget: PGtkWidget): PGtkWidget;
  // returns the gtk widget which has the background gdk window
  var
    WindowOwnerWidget: PGtkWidget;
  begin
    Result:=Widget;
    if Result=nil then exit;
    if Result^.window=nil then exit;
    gdk_window_get_user_data(Result^.window,PGPointer(@WindowOwnerWidget));
    Result:=WindowOwnerWidget;
    if Result=nil then exit;
  end;

var
  Style: PGTKStyle;
  GC: PGDKGC;
  Pixmap: PGDKPixmap;
  BaseColor: TColor;
  Red, Green, Blue: byte;
begin
  // Set defaults in case something goes wrong
  FillChar(Result{%H-}, SizeOf(Result), 0);
  Style := nil;
  GC := nil;
  Pixmap := nil;

  Result.Fill := GDK_Solid;
  RedGreenBlue(ColorToRGB(TColor(Color)), Red, Green, Blue);
  Result.foreground.Red:=gushort(Red) shl 8 + Red;
  Result.foreground.Green:=gushort(Green) shl 8 + Green;
  Result.foreground.Blue:=gushort(Blue) shl 8 + Blue;

  {$IfDef Disable_GC_SysColors}
  exit;
  {$EndIf}
  BaseColor := TColor(Color and $FF);
  case BaseColor of
    {These are WM/X defined, but might be possible to get

    COLOR_CAPTIONTEXT
    COLOR_INACTIVECAPTIONTEXT}

    {These Are incompatible or WM defined
    
    COLOR_ACTIVECAPTION
    COLOR_INACTIVECAPTION
    COLOR_GRADIENTACTIVECAPTION
    COLOR_GRADIENTINACTIVECAPTION
    COLOR_WINDOWFRAME
    COLOR_ACTIVEBORDER
    COLOR_INACTIVEBORDER}
    
    COLOR_BACKGROUND:
      begin
        Style := GetStyle(lgsDefault);
        if Style = nil then
          Style := GetStyle(lgsWindow);
        if Style = nil then
          exit;
        Pixmap := Style^.bg_pixmap[GTK_STATE_NORMAL];
        if Pixmap <> nil then
        begin
          Result.Fill := GDK_Tiled;
          Result.Tile := Pixmap;
        end
        else
        begin
          GC := Style^.bg_gc[GTK_STATE_NORMAL];
          if GC = nil then
          begin
            Result.Fill := GDK_Solid;
            Result.foreground := Style^.bg[GTK_STATE_PRELIGHT];
          end
          else
            GDK_GC_Get_Values(GC, @Result);
        end;
      end;

    COLOR_INFOBK :
      begin
        Style := GetStyle(lgsTooltip);
        if Style = nil then
          Style := GetStyle(lgsWindow);
        if Style = nil then
          exit;

        Pixmap := Style^.bg_pixmap[GTK_STATE_NORMAL];
        if Pixmap <> nil then
        begin
          Result.Fill := GDK_Tiled;
          Result.Tile := Pixmap;
        end
        else
        begin
          GC := Style^.bg_gc[GTK_STATE_NORMAL];
          if GC = nil then
          begin
            Result.Fill := GDK_Solid;
            Result.foreground := Style^.bg[GTK_STATE_NORMAL];
          end
          else
            GDK_GC_Get_Values(GC, @Result);
        end;
      end;

    COLOR_INFOTEXT :
      begin
        Style := GetStyle(lgsTooltip);

        if Style = nil then
          Style := GetStyle(lgsWindow);

        if Style = nil then
          exit;

        GC := Style^.fg_gc[GTK_STATE_NORMAL];
        if GC = nil then
        begin
          Result.Fill := GDK_Solid;
          Result.foreground := Style^.fg[GTK_STATE_NORMAL];
        end
        else
          GDK_GC_Get_Values(GC, @Result);
      end;

    COLOR_FORM,
    COLOR_MENU,
    COLOR_SCROLLBAR,
    COLOR_BTNFACE :
      begin
        case BaseColor of
          COLOR_FORM: Style := GetStyle(lgsWindow);
          COLOR_BTNFACE: Style := GetStyle(lgsButton);
          COLOR_MENU: Style := GetStyle(lgsMenu);
          COLOR_SCROLLBAR: Style := GetStyle(lgsHorizontalScrollbar);
        end;
        if Style = nil then
          exit;
        Pixmap := Style^.bg_pixmap[GTK_STATE_NORMAL];
        if Pixmap <> nil then
        begin
          Result.Fill := GDK_Tiled;
          Result.Tile := Pixmap;
        end else
        begin
          GC := Style^.bg_gc[GTK_STATE_NORMAL];
          if GC = nil then
          begin
            Result.Fill := GDK_Solid;
            Result.foreground := Style^.bg[GTK_STATE_NORMAL];
          end
          else
            GDK_GC_Get_Values(GC, @Result);
        end;
      end;

    COLOR_3DDKSHADOW,
    COLOR_BTNSHADOW :
      begin
        Style := GetStyle(lgsButton);
        if Style = nil then
          exit;
        GC := Style^.dark_gc[GTK_STATE_NORMAL];
        if GC = nil then
        begin
          Result.Fill := GDK_Solid;
          Result.foreground := Style^.dark[GTK_STATE_NORMAL];
        end
        else
          GDK_GC_Get_Values(GC, @Result);
      end;

    COLOR_GRAYTEXT :
      begin
        Style := GetStyle(lgsDefault);
        if Style = nil then
          exit;
        GC := Style^.text_gc[GTK_STATE_INSENSITIVE];
        if GC = nil then
        begin
          Result.Fill := GDK_Solid;
          Result.foreground := Style^.text[GTK_STATE_NORMAL];
        end else
          GDK_GC_Get_Values(GC, @Result);
      end;

    COLOR_MENUTEXT,
    COLOR_BTNTEXT :
      begin
        case BaseColor of
          COLOR_BTNTEXT : Style := GetStyle(lgsButton);
          COLOR_MENUTEXT : Style := GetStyle(lgsMenuitem);
        end;
        if Style = nil then
          exit;
        GC := Style^.fg_gc[GTK_STATE_NORMAL];
        if GC = nil then
        begin
          Result.Fill := GDK_Solid;
          Result.foreground := Style^.fg[GTK_STATE_NORMAL];
        end
        else
          GDK_GC_Get_Values(GC, @Result);
      end;

    COLOR_WINDOWTEXT:
      begin
        Style := GetStyle(lgsDefault);
        if Style = nil then
          exit;
        GC := Style^.text_gc[GTK_STATE_NORMAL];
        if GC = nil then
        begin
          Result.Fill := GDK_Solid;
          Result.foreground := Style^.text[GTK_STATE_NORMAL];
        end
        else
          GDK_GC_Get_Values(GC, @Result);
      end;

    COLOR_3DLIGHT,
    COLOR_BTNHIGHLIGHT :
      begin
        Style := GetStyle(lgsButton);
        if Style = nil then
          exit;
        GC := Style^.light_gc[GTK_STATE_NORMAL];
        if GC = nil then
        begin
          Result.Fill := GDK_Solid;
          Result.foreground := Style^.light[GTK_STATE_NORMAL];
        end
        else
          GDK_GC_Get_Values(GC, @Result);
      end;

    COLOR_WINDOW :
      begin
        Style := GetStyle(lgsList);
        if Style = nil then
          exit;
        GC := Style^.base_gc[GTK_STATE_NORMAL];
        if (GC = nil) then
        begin
          Result.Fill := GDK_Solid;
          if Style^.base[GTK_STATE_NORMAL].Pixel<>0 then
          begin
            Result.foreground := Style^.base[GTK_STATE_NORMAL];
            Result.background := Style^.base[GTK_STATE_NORMAL];
          end;
        end
        else
          GDK_GC_Get_Values(GC, @Result);
      end;

    COLOR_HIGHLIGHT :
      begin
        Style := GetStyle(lgsDefault);
        if Style = nil then
          exit;
        GC := Style^.bg_gc[GTK_STATE_SELECTED];
        if GC = nil then
        begin
          Result.Fill := GDK_Solid;
          Result.foreground := Style^.bg[GTK_STATE_SELECTED];
        end
        else
          GDK_GC_Get_Values(GC, @Result);
      end;

    COLOR_HIGHLIGHTTEXT :
      begin
        Style := GetStyle(lgsDefault);
        if Style = nil then
          exit;
        GC := Style^.text_gc[GTK_STATE_SELECTED];
        if GC = nil then
        begin
          Result.Fill := GDK_Solid;
          Result.foreground := Style^.bg[GTK_STATE_PRELIGHT];
        end
        else
          GDK_GC_Get_Values(GC, @Result);
      end;

    {?????????????
    COLOR_HOTLIGHT :
      begin
      end;
    ?????????????}

    {?????????????????
    COLOR_APPWORKSPACE :
      begin
      end;
    ?????????????????}
  end;

  RealizeGtkStyleColor(Style, @Result.foreground);
end;

function StyleForegroundColor(Color: TColorRef;
  DefaultColor: PGDKColor): PGDKColor;
var
  style : PGTKStyle;
begin
  style := nil;
  Result := DefaultColor;

  Case TColor(Color) of
    clINFOTEXT :
      begin
        Style := GetStyle(lgsTooltip);

        If Style = nil then
          exit;

        Result := @Style^.fg[GTK_STATE_NORMAL];
      end;

    cl3DDKSHADOW,
    clBTNSHADOW :
      begin
        Style := GetStyle(lgsButton);
        If Style = nil then
          exit;
        Result := @Style^.dark[GTK_STATE_NORMAL];
      end;

    clGRAYTEXT :
      begin
        Style := GetStyle(lgsDefault);
        If Style = nil then
          exit;
        Result := @Style^.text[GTK_STATE_INSENSITIVE];
      end;

    clMENUTEXT,
    clBTNTEXT :
      begin
        Case TColor(Color) of
          clBTNTEXT : Style := GetStyle(lgsButton);
          clMENUTEXT : Style := GetStyle(lgsMenuitem);
        end;
        If Style = nil then
          exit;
        Result := @Style^.fg[GTK_STATE_NORMAL];
      end;

    clWINDOWTEXT:
      begin
        Style := GetStyle(lgsDefault);
        If Style = nil then
          exit;
        Result := @Style^.text[GTK_STATE_NORMAL];
      end;

    cl3DLIGHT,
    clBTNHIGHLIGHT :
      begin
        Style := GetStyle(lgsButton);
        If Style = nil then
          exit;
        Result := @Style^.light[GTK_STATE_NORMAL];
      end;

    clHIGHLIGHTTEXT :
      begin
        DebugLn(['StyleForegroundColor clHIGHLIGHTTEXT']);
        Style := GetStyle(lgsDefault);
        If Style = nil then
          exit;
        Result := @Style^.text[GTK_STATE_PRELIGHT];
        DebugLn(['StyleForegroundColor clHIGHLIGHTTEXT 2 ',Result<>nil]);
      end;
  end;

  If Result = nil then
    Result := DefaultColor;

  if (Result <> nil) and (Result <> DefaultColor) then
    RealizeGtkStyleColor(Style,Result);
end;

function GetStyleGroupboxFrameBorders: TRect;
const s = 200;
var
  StyleObject: PStyleObject;
  allocation: TGtkAllocation;
  FrameWidget: PGtkFrame;
  f: TRect;
begin
  GetStyleWidget(lgsGroupBox);
  StyleObject:=StandardStyles[lgsGroupBox];
  if not StyleObject^.FrameBordersValid then begin
    allocation.x:=0;
    allocation.y:=0;
    allocation.width:=s;
    allocation.height:=s;
    gtk_widget_size_allocate(StyleObject^.Widget,@allocation);
    FrameWidget:=pGtkFrame(StyleObject^.Widget);
    GTK_FRAME_GET_CLASS(FrameWidget)^.compute_child_allocation(
      FrameWidget,@allocation);
    //DebugLn(['GetStyleGroupboxFrame BBB2 ',dbgs(allocation)]);
    f.Left:=Min(s,Max(0,allocation.x));
    f.Top:=Min(s,Max(0,allocation.y));
    f.Right:=Max(0,Min(s-f.Left,s-allocation.x-allocation.width));
    f.Bottom:=Max(0,Min(s-f.Top,s-allocation.x-allocation.width));
    StyleObject^.FrameBorders:=f;
    //DebugLn(['GetStyleGroupboxFrame FrameBorders=',dbgs(StyleObject^.FrameBorders)]);
    StyleObject^.FrameBordersValid:=true;
  end;
  Result:=StyleObject^.FrameBorders;
end;

function GetStyleNotebookFrameBorders: TRect;
const s = 400;
var
  StyleObject: PStyleObject;
  allocation: TGtkAllocation;
  f: TRect;
  PageWidget: PGtkWidget;
begin
  GetStyleWidget(lgsNotebook);
  StyleObject:=StandardStyles[lgsNotebook];
  if not StyleObject^.FrameBordersValid then begin
    allocation.x:=0;
    allocation.y:=0;
    allocation.width:=s;
    allocation.height:=s;
    gtk_widget_size_allocate(StyleObject^.Widget,@allocation);
    PageWidget:=gtk_notebook_get_nth_page(PGtkNoteBook(StyleObject^.Widget),0);
    //DebugLn(['GetStyleNotebookFrameBorders BBB2 ',dbgs(allocation)]);
    allocation:=PageWidget^.allocation;
    f.Left:=Min(s,Max(0,allocation.x));
    f.Top:=Min(s,Max(0,allocation.y));
    f.Right:=Max(0,Min(s-f.Left,s-allocation.x-allocation.width));
    f.Bottom:=Max(0,Min(s-f.Top,s-allocation.x-allocation.width));
    StyleObject^.FrameBorders:=f;
    //DebugLn(['GetStyleNotebookFrameBorders FrameBorders=',dbgs(StyleObject^.FrameBorders)]);
    StyleObject^.FrameBordersValid:=true;
  end;
  Result:=StyleObject^.FrameBorders;
end;

function GetStyleFormFrameBorders(WithMenu: boolean): TRect;
const s = 400;
var
  StyleObject: PStyleObject;
  allocation: TGtkAllocation;
  f: TRect;
  InnerWidget: PGtkWidget;
  Outer: TGdkRectangle;
  Inner: TGdkRectangle;
begin
  GetStyleWidget(lgsMenu);
  StyleObject:=StandardStyles[lgsWindow];
  if not StyleObject^.FrameBordersValid then begin
    allocation.x:=0;
    allocation.y:=0;
    allocation.width:=s;
    allocation.height:=s;
    gtk_widget_size_allocate(StyleObject^.Widget,@allocation);
    InnerWidget:=PGTKWidget(
          g_object_get_data(PGObject(StyleObject^.Widget),'fixedwidget'));
    allocation:=InnerWidget^.allocation;
    //DebugLn(['GetStyleFormFrameBorders BBB2 ',dbgs(allocation),' WithMenu=',WithMenu,' ClientWidget=',GetWidgetDebugReport(InnerWidget)]);
    f.Left:=Min(s,Max(0,allocation.x));
    f.Top:=Min(s,Max(0,allocation.y));
    f.Right:=Max(0,Min(s-f.Left,s-allocation.x-allocation.width));
    f.Bottom:=Max(0,Min(s-f.Top,s-allocation.x-allocation.width));
    StyleObject^.FrameBorders:=f;
    //DebugLn(['GetStyleFormFrameBorders FrameBorders=',dbgs(StyleObject^.FrameBorders)]);
    StyleObject^.FrameBordersValid:=true;
  end;
  
  if WithMenu then begin
    InnerWidget:=PGTKWidget(
                 g_object_get_data(PGObject(StyleObject^.Widget),'vbox'));
  end else begin
    InnerWidget:=PGTKWidget(
          g_object_get_data(PGObject(StyleObject^.Widget),'fixedwidget'));
  end;
  Outer:=StyleObject^.Widget^.allocation;
  Inner:=InnerWidget^.allocation;
  Result.Left:=Min(Outer.width,Max(0,Inner.x));
  Result.Top:=Min(Outer.height,Max(0,Inner.y));
  Result.Right:=Max(0,Min(Outer.width-f.Left,Outer.width-Inner.x-Inner.width));
  Result.Bottom:=Max(0,Min(Outer.height-f.Top,Outer.height-Inner.x-Inner.width));
  //DebugLn(['GetStyleFormFrameBorders BBB3 Inner=',dbgs(Inner),' Outer=',dbgs(Outer),' WithMenu=',WithMenu,' InnerWidget=',GetWidgetDebugReport(InnerWidget),' Result=',dbgs(Result)]);
end;

procedure StyleFillRectangle(drawable : PGDKDrawable; GC : PGDKGC;
  Color : TColorRef; x, y, width, height : gint;
  AClipArea: PGdkRectangle);
var
  style: PGTKStyle;
  widget: PGTKWidget;
  state: TGTKStateType;
  shadow: TGtkShadowType;
  detail: pgchar;
begin
  style := nil;
  shadow := GTK_SHADOW_NONE;
  state := GTK_STATE_NORMAL;

  case TColor(Color) of
   { clMenu:
      begin
        Style := GetStyle('menuitem');
        widget := GetStyleWidget('menuitem');
        detail := 'menuitem';
      end;

    clBtnFace :
      begin
        Style := GetStyle('button');
        widget := GetStyleWidget('button');
        detail := 'button';
      end;

    clWindow :
      begin
        Style := GetStyle('default');
        widget := GetStyleWidget('default');
        detail := 'list';
      end;   }

    clBackground:
      begin
        Style := GetStyle(lgsWindow);
        widget := GetStyleWidget(lgsWindow);
        detail := 'window';
      end;

    clInfoBk :
      begin
        Style := GetStyle(lgsToolTip);
        Widget := GetStyleWidget(lgsToolTip);
        shadow := GTK_SHADOW_OUT;
        detail := 'tooltip';
      end;

    clForm :
      begin
        Style := GetStyle(lgsWindow);
        widget := GetStyleWidget(lgsWindow);
        detail := 'window';
      end;
  end;

  if Assigned(Style) then
    gtk_paint_flat_box(style, drawable, state, shadow, AClipArea, widget,
                       detail, x, y, width, height)
  else
    gdk_draw_rectangle(drawable, GC, 1, x, y, width, height);
end;

procedure UpdateWidgetStyleOfControl(AWinControl: TWinControl);
var
  RCStyle : PGtkRCStyle;
  Widget, FixWidget : PGTKWidget;
  MainWidget: PGtkWidget;
  FreeFontName: boolean;

  procedure CreateRCStyle;
  begin
    if RCStyle=nil then
      RCStyle:=gtk_rc_style_new;
  end;
  
begin
  {$IFDEF NoStyle}
  exit;
  {$ENDIF}

  if not AWinControl.HandleAllocated then exit;

  MainWidget:={%H-}PGtkWidget(AWinControl.Handle);
  FixWidget:=GetFixedWidget(MainWidget);
  if (FixWidget <> nil) and (FixWidget <> MainWidget) then
    Widget := FixWidget
  else
    Widget := MainWidget;

  RCStyle:=nil;
  FreeFontName:=false;
  try
    // set default background
    if (AWinControl.Color=clNone) then 
    begin
      // clNone => remove default background
      if (FixWidget<>nil) and (FixWidget^.Window<>nil) then
      begin
        gdk_window_set_back_pixmap(FixWidget^.Window, nil, GdkFalse);
      end;
    end
    else
    if not IsColorDefault(AWinControl) and ((AWinControl.Color and SYS_COLOR_BASE)=0) then 
    begin
      // set background to user defined color

      // don't set background for custom controls, which paint themselves
      // (this prevents flickering)
      if (csOpaque in AWinControl.ControlStyle)
      and GtkWidgetIsA(MainWidget,GTKAPIWidget_Type) then exit;

      {for i:=0 to 4 do begin
        RCStyle^.bg[i]:=NewColor;

        // Indicate which colors the GtkRcStyle will affect;
        // unflagged colors will follow the theme
        RCStyle^.color_flags[i]:=
          RCStyle^.color_flags[i] or GTK_RC_BG;
      end;}
      
      //DebugLn('UpdateWidgetStyleOfControl ',DbgSName(AWinControl),' Color=',DbgS(AWinControl.Color));
    end;
    
    {if (AWinControl is TCustomForm) then begin
      gdk_window_set_back_pixmap(FixWidget^.Window,nil,GdkFalse);

      NewColor:=TColorToTGDKColor(clRed);

      CreateRCStyle;
      for i:=0 to 4 do begin
        debugln('UpdateWidgetStyleOfControl i=',dbgs(i),' ',RCStyle^.bg_pixmap_name[i],' ',RCStyle^.Name);
        RCStyle^.bg[i]:=NewColor;

        // Indicate which colors the GtkRcStyle will affect;
        // unflagged colors will follow the theme
        RCStyle^.color_flags[i]:=
          RCStyle^.color_flags[i] or GTK_RC_BG;
      end;
    end;}
    
    // set font color

    // set font (currently only TCustomLabel)
    if (GtkWidgetIsA(Widget,gtk_label_get_type)
    or GtkWidgetIsA(Widget,gtk_editable_get_type)
    or GtkWidgetIsA(Widget,gtk_check_button_get_type))
    and (not AWinControl.Font.IsDefault)
    then begin
       // allocate font (just read it)
       if AWinControl.Font.Reference.Handle=0 then ;
    end;
    
  finally
    if RCStyle<>nil then begin
      //DebugLn('UpdateWidgetStyleOfControl Apply Modifications ',AWinControl.Name,' ',GetWidgetClassName(Widget));
      gtk_widget_modify_style(Widget,RCStyle);

      if FreeFontName then begin
        pango_font_description_free(RCStyle^.font_desc);
        RCStyle^.font_desc:=nil;
      end;
      //DebugLn('UpdateWidgetStyleOfControl END ',DbgSName(AWinControl),' Widget=',GetWidgetDebugReport(Widget),' Style=',GetWidgetStyleReport(Widget));
      gtk_rc_style_unref(RCStyle);
    end;
  end;
end;

{-------------------------------------------------------------------------------
  Creates a new PChar. Deletes escaping ampersands, replaces the first single
  ampersand with an underscore and deletes all other single ampersands.
-------------------------------------------------------------------------------}
function Ampersands2Underscore(Src: PChar) : PChar;
var
  s: String;
begin
  s := StrPas(Src);
  s := Ampersands2Underscore(s);
  Result := StrAlloc(Length(s)+1); // +1 for #0 char at end
  strcopy(Result, PChar(s));
end;

{-------------------------------------------------------------------------------
  Deletes escaping ampersands, replaces the first single
  ampersand with an underscore and deletes all other single ampersands.
-------------------------------------------------------------------------------}
function Ampersands2Underscore(const ASource: String): String;
var
  n: Integer;
  FirstFound: Boolean;
begin
  //TODO: escape underscores
  FirstFound := False;
  Result := ASource;
  n := 1;
  while n <= Length(Result) do
  begin
    if Result[n] = '&' then
    begin
      if FirstFound
      or ( (n < Length(Result)) and (Result[n+1] = '&') ) // got &&
      then begin
        Delete(Result, n, 1);
        if not FirstFound then
          Inc(n);               // Skip the second & of &&
      end
      else begin
        FirstFound := True;
        Result[n] := '_';
      end;
    end;
    Inc(n);
  end;
end;

function EscapeUnderscores(const Str: String): String;
begin
  Result := StringReplace(Str, '_', '__', [rfReplaceAll]);
end;

{-------------------------------------------------------------------------------
  procedure LabelFromAmpersands(var AText, APattern: String; var AAccelChar: Char)

  Removes all escaping ampersands &&, creates an underscore pattern and returns
  the first ampersand char as accelerator char
-------------------------------------------------------------------------------}
procedure LabelFromAmpersands(var AText, APattern: String; var AAccelChar: Char);
var
  n: Integer;
  FirstFound: Boolean;
begin
  FirstFound := False;
  APattern := StringOfChar(' ', Length(AText));
  AAccelChar := #0;
  n := 1;
  while n <= Length(AText) do
  begin
    case AText[n] of
      '&': begin
        if (n < Length(AText))
        and (AText[n + 1] = '&')
        then begin
          // we got a &&, remove the first
          Delete(AText, n, 1);
          Delete(APattern, n, 1);
          Inc(n);
        end else begin
          Delete(AText, n, 1);
          Delete(APattern, n, 1);
          if FirstFound
          then Continue; // simply remove it

          // if we are here it's our first
          FirstFound := True;
          AAccelChar := System.lowerCase(AText[n]);
          // is there a next char we can underline ?
          if n <= Length(APattern)
          then APattern[n] := '_';
        end;
      end;
      '_': begin
        AText[n] := ' ';
        APattern[n] := '_';
      end;
    end;
    Inc(n);
  end;
end;


{-------------------------------------------------------------------------------
  function GetTextExtentIgnoringAmpersands(TheFont: PGDKFont;
    Str : PChar; StrLength: integer;
    MaxWidth: Longint; lbearing, rbearing, width, ascent, descent : Pgint);

  Gets text extent of a string, ignoring escaped Ampersands.
  That means, ampersands are not counted.
  Negative MaxWidth means no limit.
-------------------------------------------------------------------------------}
procedure GetTextExtentIgnoringAmpersands(TheFont: TGtkIntfFont;
  Str : PChar; StrLength: integer;
  lbearing, rbearing, width, ascent, descent : Pgint);
var
  NewStr: PChar;
begin
  // check if Str contains an ampersand before removing them all.
  if StrLScan(Str, '&', StrLength) <> nil then
    NewStr := RemoveAmpersands(Str, StrLength)
  else
    NewStr := Str;
  gdk_text_extents(TheFont, NewStr, StrLength,
                   lbearing, rBearing, width, ascent, descent);
  if NewStr <> Str then
    StrDispose(NewStr);
end;

{------------------------------------------------------------------------------
  function FontIsDoubleByteCharsFont(TheFont: TGtkIntfFont): boolean;

  This is only a heuristic
 ------------------------------------------------------------------------------}
function FontIsDoubleByteCharsFont(TheFont: TGtkIntfFont): boolean;
var
  SingleCharLen, DoubleCharLen: integer;
begin
  pango_layout_set_single_paragraph_mode(TheFont, TRUE);
  pango_layout_set_width(TheFont, -1);
  pango_layout_set_text(TheFont, 'A', 1);
  pango_layout_get_pixel_size(TheFont, @SingleCharLen, nil);
  pango_layout_set_text(TheFont, #0'A', 2);
  pango_layout_get_pixel_size(TheFont, @DoubleCharLen, nil);
  Result:=(SingleCharLen=0) and (DoubleCharLen>0);
end;

{------------------------------------------------------------------------------
  function FontIsMonoSpaceFont(TheFont: TGtkIntfFont): boolean;

  This is only a heuristic
 ------------------------------------------------------------------------------}
function FontIsMonoSpaceFont(TheFont: TGtkIntfFont): boolean;
var
  MWidth: LongInt;
  IWidth: LongInt;
begin
  pango_layout_set_single_paragraph_mode(TheFont, TRUE);
  pango_layout_set_width(TheFont, -1);
  pango_layout_set_text(TheFont, 'm', 1);
  pango_layout_get_pixel_size(TheFont, @MWidth, nil);
  pango_layout_set_text(TheFont, 'i', 1);
  pango_layout_get_pixel_size(TheFont, @IWidth, nil);
  Result:=MWidth=IWidth;
end;

{------------------------------------------------------------------------------
  Method:   GDKPixel2GDIRGB
  Params:
            Pixel - a GDK Pixel, refers to Index in Colormap/Visual
            Visual - a GDK Visual, if nil, the System Default is used
            Colormap - a GDK Colormap, if nil, the System Default is used
  Returns:  TGDIRGB

  A convenience function for use with GDK Image's. It takes a pixel value
  retrieved from gdk_image_get_pixel, and uses the passed Visual and Colormap
  to try and look up actual RGB values.
 ------------------------------------------------------------------------------}
function GDKPixel2GDIRGB(Pixel: Longint; Visual: PGDKVisual;
  Colormap: PGDKColormap) : TGDIRGB;
var
  Color: TGDKColor;
begin
  FillChar(Result{%H-}, SizeOf(TGDIRGB),0);

  If (Visual = nil) or (Colormap = nil) then begin
    Visual := GDK_Visual_Get_System;
    Colormap := GDK_Colormap_Get_System;
  end;
  
  gdk_colormap_query_color(colormap, pixel, @color);

  Result.Red := Color.Red shr 8;
  Result.Green := Color.Green shr 8;
  Result.Blue := Color.Blue shr 8;
end;

{------------------------------------------------------------------------------
  function GetWindowDecorations(AForm : TCustomForm) : Longint;
  
 ------------------------------------------------------------------------------}
function GetWindowDecorations(AForm : TCustomForm) : Longint;
var
  ABorderStyle: TFormBorderStyle;
begin
  Result := 0;

  if not (csDesigning in AForm.ComponentState) then
    ABorderStyle:=AForm.BorderStyle
  else
    ABorderStyle:=bsSizeable;

  case ABorderStyle of
    bsNone: Result := 0;

    bsSingle: Result := GDK_DECOR_TITLE or
                 GDK_DECOR_MENU or GDK_DECOR_MINIMIZE or
                 GDK_DECOR_MAXIMIZE;

    bsSizeable: Result := GDK_DECOR_BORDER or GDK_DECOR_TITLE or
                 GDK_DECOR_MENU or GDK_DECOR_MINIMIZE or GDK_DECOR_MAXIMIZE
                 or GDK_DECOR_RESIZEH;

    bsDialog: Result := GDK_DECOR_BORDER or GDK_DECOR_TITLE or
                 GDK_DECOR_MENU or GDK_DECOR_MINIMIZE;

    bsToolWindow: Result := GDK_DECOR_TITLE or GDK_DECOR_MENU;

    bsSizeToolWin: Result := GDK_DECOR_BORDER or GDK_DECOR_TITLE or
                   GDK_DECOR_MENU or GDK_DECOR_RESIZEH;
  end;

  if not (csDesigning in AForm.ComponentState) then
  begin
    if not (biMinimize in AForm.BorderIcons) then
      Result := Result and not GDK_DECOR_MINIMIZE;
    if not (biMaximize in AForm.BorderIcons) then
      Result := Result and not GDK_DECOR_MAXIMIZE;
    if not (biSystemMenu in AForm.BorderIcons) then
      Result := Result and not GDK_DECOR_MENU;
  end;
  //DebugLn('GetWindowDecorations ',DbgSName(AForm),' ',dbgs(ord(ABorderStyle)),' ',binStr(Result,8));
end;

{------------------------------------------------------------------------------
  function GetWindowFunction(AForm : TCustomForm) : Longint;

 ------------------------------------------------------------------------------}
function GetWindowFunction(AForm : TCustomForm) : Longint;
var
  ABorderStyle: TFormBorderStyle;
begin
  Result:=0;
  if not (csDesigning in AForm.ComponentState) then
    ABorderStyle:=AForm.BorderStyle
  else
    ABorderStyle:=bsSizeable;

  case ABorderStyle of
    bsNone : Result := GDK_FUNC_RESIZE or GDK_FUNC_CLOSE {$ifndef windows}or GDK_FUNC_MOVE{$endif};

    bsSingle : Result := GDK_FUNC_MOVE or GDK_FUNC_MINIMIZE or GDK_FUNC_CLOSE;

    bsSizeable : Result := GDK_FUNC_RESIZE or GDK_FUNC_MOVE or
                GDK_FUNC_MINIMIZE or GDK_FUNC_CLOSE or GDK_FUNC_MAXIMIZE;

    bsDialog : Result := GDK_FUNC_CLOSE or GDK_FUNC_MINIMIZE
                or GDK_FUNC_MOVE;

    bsToolWindow : Result := GDK_FUNC_MOVE or GDK_FUNC_CLOSE or
      GDK_FUNC_MINIMIZE;

    bsSizeToolWin : Result := GDK_FUNC_RESIZE or GDK_FUNC_MOVE or
      GDK_FUNC_CLOSE or GDK_FUNC_MINIMIZE or GDK_FUNC_MAXIMIZE;
  end;

  // X warns if marking a fixed size window resizeable:
  if ((AForm.Constraints.MinWidth>0)
  and (AForm.Constraints.MinWidth=AForm.Constraints.MaxWidth))
  and ((AForm.Constraints.MinHeight>0)
  and (AForm.Constraints.MinHeight=AForm.Constraints.MaxHeight)) then
    Result:=Result-GDK_FUNC_RESIZE;

  if (not (csDesigning in AForm.ComponentState)) then
  begin
    if not (biMinimize in AForm.BorderIcons) then
      Result:=Result and not GDK_FUNC_MINIMIZE;
    if not (biMaximize in AForm.BorderIcons) then
      Result:=Result and not GDK_FUNC_MAXIMIZE;
  end;
  //DebugLn('GetWindowFunction ',DbgSName(AForm),' ',dbgs(ord(ABorderStyle)),' ',binStr(Result,8));
end;

{$IFDEF GTK2OLDENUMFONTFAMILIES}
procedure FillScreenFonts(ScreenFonts : TStrings);
var
  Widget : PGTKWidget;
  Context : PPangoContext;
  families : PPPangoFontFamily;
  Tmp: AnsiString;
  I, N: Integer;
begin
  ScreenFonts.Clear;
  Widget := GetStyleWidget(lgsDefault);
  if Widget = nil then begin
    exit;//raise an error here I guess
  end;
  Context := gtk_widget_get_pango_context(Widget);
  if Context = nil then begin
    exit;//raise an error here I guess
  end;
  families := nil;
  pango_context_list_families(Context, @families, @n);

  for I := 0 to N - 1 do
    if families[I] <> nil then begin
      Tmp := StrPas(pango_font_family_get_name(families[I]));
      if Tmp <> '' then
        if ScreenFonts.IndexOf(Tmp) < 0 then
          ScreenFonts.Append(Tmp);
   end;
  if (families <> nil) then
    g_free(families);
end;
{$ENDIF}

function GetTextHeight(DCTextMetric: TDevContextTextMetric): integer;
// IMPORTANT: Before this call:  UpdateDCTextMetric(TGtkDeviceContext(DC));
begin
  {$IfDef Win32}
  Result := DCTextMetric.TextMetric.tmHeight div 2;
  {$Else}
  Result := DCTextMetric.TextMetric.tmAscent;
  {$EndIf}
end;

{$IFDEF HasX}
function  XGetWorkarea(out ax,ay,awidth,aheight:gint): gint;

var
  XDisplay: PDisplay;
  XScreen: PScreen;
  XWindow: TWindow;
  AtomType: x.TAtom;
  Format: gint;
  nitems: gulong;
  bytes_after: gulong;
  current_desktop: pclong; // format=32 returns an array of "c" longs which in 64-bit app
                           // will be 64-bit values that are padded in the upper 4 bytes
  res   : Integer;
begin
  Result := -1;
  xdisplay := gdk_display;
  xscreen := XDefaultScreenOfDisplay(xdisplay);
  xwindow := XRootWindowOfScreen(xscreen);
  res:=XGetWindowProperty (xdisplay, xwindow,
             XInternAtom(xdisplay, '_NET_WORKAREA', false),
             0, MaxInt, False, XA_CARDINAL, @atomtype, @format, @nitems,
             @bytes_after, gpointer(@current_desktop));
  if (atomtype = XA_CARDINAL) and (format = 32) and  (nitems > 0) then
  begin
    result:=res;
    ax:=current_desktop[0];
    ay:=current_desktop[1];
    awidth:=current_desktop[2];
    aheight:=current_desktop[3];
  end else
  begin
    ax:=0;
    ay:=0;
    awidth:=0;
    aheight:=0;
  end;
  if current_desktop <> nil then
    XFree (current_desktop);
end;
{$ENDIF}

function FindFocusWidget(AWidget: PGtkWidget): PGtkWidget;
var
  WinWidgetInfo: PWinWidgetInfo;
  ImplWidget: PGtkWidget;
  GList: PGlist;
  LastFocusWidget: PGtkWidget;
begin
  // Default to the widget, try to find other
  Result := AWidget;

  // Combo
  if GtkWidgetIsA(AWidget, gtk_combo_get_type)
  then begin
    // handle is a gtk combo
    {$IfDef VerboseFocus}
    DebugLn('D taking gtkcombo entry');
    {$EndIf}
    Result := PgtkWidget(PGtkCombo(AWidget)^.entry);
    Exit;
  end;

  // check if widget has a WinWidgetInfo record
  WinWidgetInfo := GetWidgetInfo(AWidget);
  if WinWidgetInfo = nil then Exit;

  ImplWidget:= WinWidgetInfo^.CoreWidget;
  if ImplWidget = nil then Exit;
  // set default to the implementation widget
  Result := ImplWidget;

  // handle has an ImplementationWidget
  if GtkWidgetIsA(ImplWidget, gtk_list_get_type)
  then begin
    {$IfDef VerboseFocus}
    DebugLn('E using list');
    {$EndIf}
    // Try the last added selected
    if not (selection_mode(PGtkList(ImplWidget)^) in [GTK_SELECTION_SINGLE, GTK_SELECTION_BROWSE])
    and (PGtkList(ImplWidget)^.last_focus_child <> nil)
    then begin
      LastFocusWidget:=PGtkList(ImplWidget)^.last_focus_child;
      if g_list_find(PGtkList(ImplWidget)^.selection,LastFocusWidget)<>nil
      then begin
        Result := PGtkList(ImplWidget)^.last_focus_child;
        {$IfDef VerboseFocus}
        DebugLn('E.1 using last_focus_child');
        {$EndIf}
        Exit;
      end;
    end;

    // If there is a selection, try the first
    GList := PGtkList(ImplWidget)^.selection;
    if (GList <> nil) and (GList^.data <> nil)
    then begin
      Result := GList^.data;
      {$IfDef VerboseFocus}
      DebugLn('E.2 using 1st selection');
      {$EndIf}
      Exit;
    end;

    // If not in browse mode, set focus to the first child
    // in browsemode, the focused item cannot be selected by mouse
//      if selection_mode(PGtkList(ImplWidget)^) = GTK_SELECTION_BROWSE
//      then begin
//        {$IfDef VerboseFocus}
//        DebugLn('  E.3 Browse mode -> using ImplWidget');
//        {$EndIf}
//        Exit;
//      end;

    GList := PGtkList(ImplWidget)^.children;
    if GList = nil then Exit;
    if GList^.Data = nil then Exit;
    Result := GList^.Data;
    {$IfDef VerboseFocus}
    DebugLn('E.4 using 1st child');
    {$EndIf}

    Exit;
  end;

  {$IfDef VerboseFocus}
  DebugLn('E taking ImplementationWidget');
  {$EndIf}
end;


{$IFDEF ASSERT_IS_ON}
  {$UNDEF ASSERT_IS_ON}
  {$C-}
{$ENDIF}

// included by gtk2proc.pp

{%MainUnit carbonprivate.pp}
{
 *****************************************************************************
  This file is part of the Lazarus Component Library (LCL)

  See the file COPYING.modifiedLGPL.txt, included in this distribution,
  for details about the license.
 *****************************************************************************
}

// ==================================================================
// H A N D L E R S 
// ==================================================================


procedure SendMenuActivate(AMenu: MenuRef; MenuIdx: MenuItemIndex);
var
  CarbonMenu  : TCarbonMenu;
  Msg         : TLMessage;
  S : ByteCount;
begin
  if GetMenuItemProperty(AMenu, MenuIdx, LAZARUS_FOURCC,
       WIDGETINFO_FOURCC, SizeOf(TCarbonMenu), S{%H-}, @CarbonMenu) = noErr then
  begin
    FillChar(Msg{%H-}, SizeOf(Msg), 0);
    Msg.msg := LM_ACTIVATE;
    CarbonMenu.LCLMenuItem.Dispatch(Msg);
  end;
end;



{------------------------------------------------------------------------------
  Name: CarbonWindow_Close
 ------------------------------------------------------------------------------}
function CarbonWindow_Close(ANextHandler: EventHandlerCallRef;
  AEvent: EventRef;
  AWidget: TCarbonWidget): OSStatus; {$IFDEF darwin}mwpascal;{$ENDIF}
var
  Msg: TLMessage;
begin
  {$IFDEF VerboseWindowEvent}
    DebugLn('CarbonWindow_Close: ', DbgSName(AWidget.LCLObject));
  {$ENDIF}
  // Do canclose query, if false then exit

  FillChar(Msg{%H-}, SizeOf(Msg),0);
  Msg.msg := LM_CLOSEQUERY;

  // Message results : 0 - do nothing, 1 - destroy window
  if DeliverMessage(AWidget.LCLObject, Msg) = 0 then
  begin
    Result := noErr;
    Exit;
  end;
  
  {$IFDEF VerboseWindowEvent}
    DebugLn('CarbonWindow_Close Free: ', DbgSName(AWidget.LCLObject));
  {$ENDIF}
    
  Result := CallNextEventHandler(ANextHandler, AEvent);
end;

{------------------------------------------------------------------------------
  Name: CarbonWindow_MouseProc
  Handles mouse events
 ------------------------------------------------------------------------------}
function CarbonWindow_MouseProc(ANextHandler: EventHandlerCallRef;
  AEvent: EventRef;
  AWidget: TCarbonWidget): OSStatus; {$IFDEF darwin}mwpascal;{$ENDIF}
var
  Control: ControlRef;    // the control we are dealing with
                          // or the rootcontrol if none found
  Widget: TCarbonWidget;  // the widget specific to the mouse event
                          // or the window's widgetinfo if none found
  Postpone: Boolean;
const
  SName = 'CarbonWindow_MouseProc';
                                
//
// helper functions used commonly
//
  function GetClickCount: Integer;
  var
    ClickCount: UInt32;
  begin
    Result := 1;
    
    if OSError(
      GetEventParameter(AEvent, kEventParamClickCount, typeUInt32, nil,
        SizeOf(ClickCount), nil, @ClickCount),
      SName, SGetEvent, 'kEventParamClickCount') then Exit;

    Result := Integer(ClickCount);
    {debugln('GetClickCount ClickCount=',dbgs(ClickCount));}
  end;

  function GetMousePoint: TPoint;
  var
    MousePoint: HIPoint;
  begin
    if OSError(
      GetEventParameter(AEvent, kEventParamWindowMouseLocation, typeHIPoint, nil,
        SizeOf(MousePoint), nil, @MousePoint),
      SName, SGetEvent, 'kEventParamWindowMouseLocation') then Exit;
    Result:=Widget.GetWindowRelativePos(Trunc(MousePoint.X), Trunc(MousePoint.Y));
  end;

  function GetMouseWheelDelta: Integer;
  var
    WheelDelta: SInt32;
    CCtl: TCarbonCustomControl;
    ScrollInfo: TScrollInfo;
  begin
    Result := 0;
    
    if OSError(
      GetEventParameter(AEvent, kEventParamMouseWheelDelta, typeSInt32, nil,
        SizeOf(WheelDelta), nil, @WheelDelta),
      SName, SGetEvent, 'kEventParamMouseWheelDelta') then Exit;

    // Carbon's WheelDelta is the number of lines to be scrolled
    // LCL expects the delta to be 120 for each wheel step, which should scroll
    // Mouse.WheelScrollLines lines (defaults to three)
    // Update: 20111212 by zeljko: All widgetsets sends WheelDelta +-120
    // mac sends 1 or -1 so we just recalc that to wheel delta. see issue #20888
    Result := (120 * WheelDelta) div Mouse.WheelScrollLines;
    if Widget.ClassType = TCarbonCustomControl then
    begin
      CCtl := TCarbonCustomControl(Widget);
      if CCtl.GetScrollbarVisible(SB_VERT) then
      begin
        FillChar(ScrollInfo{%H-}, SizeOf(ScrollInfo), #0);
        ScrollInfo.fMask := SIF_TRACKPOS;
        ScrollInfo.cbSize := SizeOf(ScrollInfo);
        CCtl.GetScrollInfo(SB_VERT, ScrollInfo);
        if (WheelDelta > 0) and (ScrollInfo.nTrackPos = 0) then
          Result := 120;
      end;
    end;
    {$IFDEF VerboseMouse}
      DebugLn('GetMouseWheelDelta WheelDelta=', DbgS(WheelDelta), ' ', HexStr(WheelDelta, 8));
    {$ENDIF}
  end;

//
// handler functions
//
  procedure HandleMouseDownEvent(var AMsg);
  const
    // array of clickcount x buttontype
    MSGKIND: array[1..4, 1..3] of Integer = (
      (LM_LBUTTONDOWN, LM_RBUTTONDOWN, LM_MBUTTONDOWN),
      (LM_LBUTTONDBLCLK, LM_RBUTTONDBLCLK, LM_MBUTTONDBLCLK),
      (LM_LBUTTONTRIPLECLK, LM_RBUTTONTRIPLECLK, LM_MBUTTONTRIPLECLK),
      (LM_LBUTTONQUADCLK, LM_RBUTTONQUADCLK, LM_MBUTTONQUADCLK)
    );
  var
    MouseButton: Integer;
    ClickCount: Integer;
    MousePoint: TPoint;
    Msg: ^TLMMouse;
  begin
    {$IFDEF VerboseMouse}
      DebugLn('HandleMouseDownEvent');
    {$ENDIF}
    Msg := @AMsg;

    ClickCount := GetClickCount;
    MouseButton := GetCarbonMouseButton(AEvent);
    MousePoint := GetMousePoint;

    if (ClickCount < Low(MSGKIND)) or (ClickCount > High(MSGKIND)) then
      ClickCount := (ClickCount mod High(MSGKIND))+1;
    
    if (MouseButton < Low(MSGKIND[1])) or (MouseButton > High(MSGKIND[1])) then Exit;
    Msg^.Msg := MSGKIND[ClickCount, MouseButton];
    //debugln('HandleMouseDownEvent CliCount=',dbgs(ClickCount),' MouseButton=',dbgs(MouseButton),' Pos=',dbgs(MousePoint));


    Msg^.XPos := MousePoint.X;                         
    Msg^.YPos := MousePoint.Y;
    Msg^.Keys := GetCarbonMsgKeyState;
    
    CarbonWidgetSet.SetCaptureWidget(HWND(Widget));

    if ClickCount > 1 then Postpone := True;
  end;

  procedure HandleMouseUpEvent(var AMsg);
  const 
    MSGKIND: array[1..3] of Integer = (LM_LBUTTONUP, LM_RBUTTONUP, LM_MBUTTONUP);
  var
    MouseButton: Integer;
    MousePoint: TPoint;
    Msg: ^TLMMouse;
  begin
    {$IFDEF VerboseMouse}
      DebugLn('HandleMouseUpEvent');
    {$ENDIF}
    // this is not called if NextHandler is called on MouseDown
    // perhaps mousetracking can fix this
    Msg := @AMsg;

    MouseButton := GetCarbonMouseButton(AEvent);
    MousePoint := GetMousePoint;
    
    if  (MouseButton >= Low(MSGKIND)) and (MouseButton <= High(MSGKIND)) then
      Msg^.Msg := MSGKIND[MouseButton];

    Msg^.XPos := MousePoint.X;
    Msg^.YPos := MousePoint.Y;
    Msg^.Keys := GetCarbonMsgKeyState;
    
    CarbonWidgetSet.SetCaptureWidget(0);
  end;

  procedure HandleMouseMovedEvent(var AMsg);
  var
    MousePoint: TPoint;
    MSg: ^TLMMouseMove;
  begin
    {$IFDEF VerboseMouse}
      DebugLn('HandleMouseMovedEvent');
    {$ENDIF}
    Msg := @AMsg;
    
    MousePoint := GetMousePoint;
    
    Msg^.Msg := LM_MOUSEMOVE;
    Msg^.XPos := SmallInt(MousePoint.X);
    Msg^.YPos := SmallInt(MousePoint.Y);
    Msg^.Keys := GetCarbonMsgKeyState;
  end;

  procedure HandleMouseDraggedEvent(var {%H-}AMsg);
  begin
    {$IFDEF VerboseMouse}
      DebugLn('-- mouse dragged --');
    {$ENDIF}
    // TODO
  end;

  procedure HandleMouseWheelEvent(var AMsg);
  var
    MousePoint: TPoint;
    MSg: ^TLMMouseEvent;
  begin
    {$IFDEF VerboseMouse}
      DebugLn('HandleMouseWheelEvent');
    {$ENDIF}
    Msg := @AMsg;

    MousePoint := GetMousePoint;

    Msg^.Msg := LM_MOUSEWHEEL;
    Msg^.Button := GetCarbonMouseButton(AEvent);
    Msg^.X := MousePoint.X;
    Msg^.Y := MousePoint.Y;
    Msg^.State := GetCarbonShiftState;
    Msg^.WheelDelta := GetMouseWheelDelta;
  end;
  
var
  Msg: record
    Message: TLMessage;
    Extra: array[0..20] of Byte; // some messages are a bit larger, make some room
  end;  
  EventKind: UInt32;
  Part: WindowPartCode;
  DesignControl: TControl;
  DesignWidget: TCarbonWidget;
  DesignView: HIViewRef;
  P, ClientPt, ControlPt: TPoint;
  DesignPt: HIPoint;
  ViewPart: HIViewPartCode;
  lTmpWidget: TCarbonWidget;
begin
  Result := EventNotHandledErr;
  Postpone := False;
  
  // check window part code
  Part := inContent;
  if not OSError(
    GetEventParameter(AEvent, kEventParamWindowPartCode, typeWindowPartCode, nil,
      SizeOf(WindowPartCode), nil, @Part),
    SName, SGetEvent, 'kEventParamWindowPartCode', eventParameterNotFoundErr) then
  begin
    if Part <> inContent then Exit;
  end;
  
  //Find out which control the mouse event should occur for
  Control := nil;
  if OSError(HIViewGetViewForMouseEvent(AWidget.Content, AEvent, Control),
    SName, SViewForMouse) then Exit;
  if Control = nil then Exit;
  
  Widget := GetCarbonWidget(Control);
  while Assigned(Widget) and not Widget.IsEnabled do
  begin
    // Here we need to avoid an endless loop which might occur in case
    // GetParent returns the same widget that we passed
    lTmpWidget := TCarbonWidget(CarbonWidgetset.GetParent(HWND(Widget)));
    if lTmpWidget = Widget then Break;
    Widget := lTmpWidget;
  end;
  if Widget = nil then Exit;

  FillChar(Msg{%H-}, SizeOf(Msg), 0);
  
  EventKind := GetEventKind(AEvent);
  case EventKind of
    kEventMouseDown       : HandleMouseDownEvent(Msg);
    kEventMouseUp         : HandleMouseUpEvent(Msg);
    kEventMouseMoved,//      : HandleMouseMovedEvent(Msg);
    kEventMouseDragged    : HandleMouseMovedEvent(Msg);//HandleMouseDraggedEvent(Msg);

    // For the enter and exit events tracking must be enabled
    // tracking is enabled by defining a rect that you want to track
    // TODO: Tracking
    kEventMouseEntered    : Msg.Message.Msg := LM_MOUSEENTER;
    kEventMouseExited     : Msg.Message.Msg := LM_MOUSELEAVE;

    kEventMouseWheelMoved : HandleMouseWheelEvent(Msg);
  else
    Exit(EventNotHandledErr);
  end;
  
  if Postpone then
  begin
    PostponedDown := True;
    PostponedDownMsg := TLMMouse(Msg.Message);
    Result := CallNextEventHandler(ANextHandler, AEvent);
  end
  else
  begin
    if Widget.NeedDeliverMouseEvent(Msg.Message.Msg, Msg) then begin
      // Msg is set in the Appropriate HandleMousexxx procedure
      NotifyApplicationUserInput(Widget.LCLObject, Msg.Message.Msg);
      if DeliverMessage(Widget.LCLObject, Msg) = 0 then
      begin
        Result := EventNotHandledErr;
      end
      else  // the LCL does not want the event propagated
        Result := noErr;
    end
    else
      Result := CallNextEventHandler(ANextHandler, AEvent);
  end;

  // interactive design
  if (EventKind = kEventMouseDown)
  and Assigned(Widget.LCLObject)
  and ((csDesigning in Widget.LCLObject.ComponentState) or (Widget is TCarbonDesignWindow))
  and (GetCarbonMouseButton(AEvent) = 1) then
  begin
    P := GetMousePoint;
    DesignControl := Widget.LCLObject.ControlAtPos(P,
      [capfAllowDisabled, capfAllowWinControls, capfRecursive]);
    if DesignControl = nil then
      DesignControl := Widget.LCLObject;
      
    if DesignControl is TWinControl then
    begin
      ClientPt := DesignControl.ScreenToClient(Widget.LCLObject.ClientToScreen(P));
      ControlPt := DesignControl.ScreenToControl(Widget.LCLObject.ClientToScreen(P));
      
      if (DesignControl as TWinControl).HandleAllocated then
      begin
        DesignWidget := TCarbonWidget((DesignControl as TWinControl).Handle);
        if DesignWidget.IsDesignInteractive(ClientPt) then
        begin
          DesignView := DesignWidget.WidgetAtPos(ControlPt);
          DesignPt := PointToHIPoint(ControlPt);
          OSError(HIViewConvertPoint(DesignPt, DesignWidget.Widget, DesignView),
            SName, 'HIViewConvertPoint');

          ViewPart := 0;
          OSError(HIViewGetPartHit(DesignView, DesignPt, ViewPart),
            SName, 'HIViewGetPartHit');
          OSError(HIViewSimulateClick(DesignView, ViewPart, GetCarbonMsgKeyState, nil),
            SName, 'HIViewSimulateClick');
        end;
      end;
    end;
  end;
end;

{------------------------------------------------------------------------------
  Name: CarbonWindow_KeyboardProc
  Handles key events
 ------------------------------------------------------------------------------}
function CarbonWindow_KeyboardProc(ANextHandler: EventHandlerCallRef;
  AEvent: EventRef;
  AWidget: TCarbonWidget): OSStatus; {$IFDEF darwin}mwpascal;{$ENDIF}
var
  Control: ControlRef;      // the control we are dealing with
                            // or the rootcontrol if none found
  Widget: TCarbonWidget;    // the widget specific to the mouse event
                            // or the window's widget if none found
  KeyChar : char;           //Ascii char, when possible (xx_(SYS)CHAR)
  VKKeyChar: char;          // Ascii char without modifiers
  UTF8Character: TUTF8Char; //char to send via IntfUtf8KeyPress
  UTF8VKCharacter: TUTF8Char; //char without modifiers, used for VK_ key value
  VKKeyCode : word;         //VK_ code
  SendChar : boolean;       //Should we send char?
  IsSysKey: Boolean;        //Is alt (option) key down?
  KeyData : PtrInt;         //Modifiers (ctrl, alt, mouse buttons...)
  EventKind: UInt32;        //The kind of this event
const
  SName = 'CarbonWindow_KeyboardProc';
  AGetEvent = 'GetEventParameter';
  ASetEvent = 'SetEventParameter';

  // See what changed in the modifiers flag so that we can emulate a keyup/keydown
  // Note: this function assumes that only a bit of the flag can be modified at
  // once
  function EmulateModifiersDownUp : boolean;
  var CurMod, diff : UInt32;
  begin
    Result:=false;
    SendChar:=false;
    if OSError(
      GetEventParameter(AEvent, kEventParamKeyModifiers, typeUInt32, nil,
        SizeOf(CurMod), nil, @CurMod), SName, AGetEvent,
      'kEventParamKeyModifiers') then Exit;

    //see what changed. we only care of bits 8 through 12
    diff:=(PrevKeyModifiers xor CurMod) and $1F00;

    //diff is now equal to the mask of the bit that changed, so we can determine
    //if this change is a keydown (PrevKeyModifiers didn't have the bit set) or
    //a keyup (PrevKeyModifiers had the bit set)
    if (PrevKeyModifiers and diff)=0 then EventKind:=kEventRawKeyDown
    else EventKind:=kEventRawKeyUp;

    PrevKeyModifiers:=CurMod;

    case diff of
      0          : exit;  //nothing (that we cared of) changed
      controlKey : VKKeyCode := VK_CONTROL; //command mapped to control
      shiftKey   : VKKeyCode := VK_SHIFT;
      alphaLock  : VKKeyCode := VK_CAPITAL; //caps lock
      optionKey  : VKKeyCode := VK_MENU;    //option is alt
      cmdKey     : VKKeyCode := VK_LWIN;    //meta... map to left Windows Key?
      else begin
        debugln(['CarbonWindow_KeyboardProc.EmulateModifiersDownUp TODO: more than one modifier changed ',diff]);
        exit; //Error! More that one bit changed in the modifiers?
      end;
    end;
    Result:=true;
    
    {$IFDEF VerboseKeyboard}
      DebugLn('[CarbonWindow_KeyboardProc.EmulateModifiersDownUp] VK =', DbgsVKCode(VKKeyCode));
    {$ENDIF}
  end;


(*
  Mac keycodes handling is not so straight. For an explanation, see
  mackeycodes.inc
  In this function, we do the following:
   1) Get the raw keycode, if it is a known "non-printable" key, translate it
      to a known VK_ keycode.
      This will be reported via xx_KeyDown/KeyUP messages only, and we can stop
      here.
   2) else, we must send both KeyDown/KeyUp and IntfUTF8KeyPress/xx_(SYS)CHAR
      So, get the unicode character and the "ascii" character (note: if it's
      not a true ascii character (>127) use the Mac character).
    2a) Try to determine a known VK_ keycode (e.g: VK_A, VK_SPACE and so on)
    2b) If no VK_ keycode exists, use a dummy keycode to trigger LCL events
        (see later in the code for a more in depth explanation)
*)

  function TranslateMacKeyCode : boolean;
  var KeyCode, DeadKeys: UInt32;
      TextLen : UInt32;
      CharLen : integer;
      widebuf: array[1..2] of widechar;
      U: Cardinal;
      Layout: UCKeyboardLayoutPtr;
      KeyboardLayout: KeyboardLayoutRef;
  begin
    Result:=false;
    SendChar:=false;
    VKKeyCode:=VK_UNKNOWN;

    KeyData:=GetCarbonMsgKeyState;
    IsSysKey:=(GetCurrentEventKeyModifiers and cmdKey)>0;

    if OSError(GetEventParameter(AEvent, kEventParamKeyCode, typeUInt32, nil,
        Sizeof(KeyCode), nil, @KeyCode), SName, AGetEvent,
      'kEventParamKeyCode') then Exit;

    //non-printable keys (see mackeycodes.inc)
    //for these keys, only send keydown/keyup (not char or UTF8KeyPress)
    case KeyCode of
      MK_F1       : VKKeyCode:=VK_F1;
      MK_F2       : VKKeyCode:=VK_F2;
      MK_F3       : VKKeyCode:=VK_F3;
      MK_F4       : VKKeyCode:=VK_F4;
      MK_F5       : VKKeyCode:=VK_F5;
      MK_F6       : VKKeyCode:=VK_F6;
      MK_F7       : VKKeyCode:=VK_F7;
      MK_F8       : VKKeyCode:=VK_F8;
      MK_F9       : VKKeyCode:=VK_F9;
      MK_F10      : VKKeyCode:=VK_F10;
      MK_F11      : VKKeyCode:=VK_F11;
      MK_F12      : VKKeyCode:=VK_F12;
      MK_F13      : VKKeyCode:=VK_SNAPSHOT;
      MK_F14      : VKKeyCode:=VK_SCROLL;
      MK_F15      : VKKeyCode:=VK_PAUSE;
      MK_POWER    : VKKeyCode:=VK_SLEEP; //?
      MK_TAB      : VKKeyCode:=VK_TAB; //strangely enough, tab is "non printable"
      MK_INS      : VKKeyCode:=VK_INSERT;
      MK_DEL      : VKKeyCode:=VK_DELETE;
      MK_HOME     : VKKeyCode:=VK_HOME;
      MK_END      : VKKeyCode:=VK_END;
      MK_PAGUP    : VKKeyCode:=VK_PRIOR;
      MK_PAGDN    : VKKeyCode:=VK_NEXT;
      MK_UP       : VKKeyCode:=VK_UP;
      MK_DOWN     : VKKeyCode:=VK_DOWN;
      MK_LEFT     : VKKeyCode:= VK_LEFT;
      MK_RIGHT    : VKKeyCode:= VK_RIGHT;
      MK_NUMLOCK  : VKKeyCode:= VK_NUMLOCK;
    end;
    
    if VKKeyCode<>VK_UNKNOWN then
    begin
      //stop here, we won't send char or UTF8KeyPress
      {$IFDEF VerboseKeyboard}
       DebugLn('[TranslateMacKeyCode] non printable VK = ', DbgsVKCode(VKKeyCode));
      {$ENDIF}
      Result:=true;
      exit;
    end;

    // get untranslated key (key without modifiers)
    OSError(KLGetCurrentKeyboardLayout(KeyboardLayout{%H-}), SName, 'KLGetCurrentKeyboardLayout');
    OSError(KLGetKeyboardLayoutProperty(KeyboardLayout, kKLuchrData, Layout{%H-}), SName, 'KLGetKeyboardLayoutProperty');
    {$IFDEF VerboseKeyboard}
    DebugLn('[Keyboard layout] UCHR layout = ', DbgS(Layout));
    {$ENDIF}

    TextLen:=0;
    DeadKeys:=0;
    UTF8VKCharacter:='';
    VKKeyChar:=#0;
    CharLen:=0;

    if Layout <> nil then
    begin
      OSError(UCKeyTranslate(Layout^, KeyCode, kUCKeyActionDisplay,
          0, LMGetKbdType,
          kUCKeyTranslateNoDeadKeysMask, DeadKeys, 6, TextLen, @WideBuf[1]), SName, 'UCKeyTranslate');

      if TextLen>0 then begin
        u:=UTF16CharacterToUnicode(@WideBuf[1],CharLen);
        if CharLen>0 then begin
          UTF8VKCharacter:=LazUTF8.UnicodeToUTF8(u);
          if (UTF8VKCharacter<>'') and (ord(Utf8VKCharacter[1])<=127) then //It's (true) ascii.
            VKKeyChar:=Utf8VKCharacter[1]
          else //not ascii, get the Mac character.
            OSError(
              GetEventParameter(AEvent, kEventParamKeyMacCharCodes, typeChar, nil,
                Sizeof(VKKeyChar), nil, @VKKeyChar), SName, AGetEvent,
              'kEventParamKeyMacCharCodes');
        end;
      end;

      TextLen := 0;

      if IsSysKey then
      begin // workaround for Command modifier suppressing shift
        DeadKeys := 0;
        OSError(UCKeyTranslate(Layout^, KeyCode, kUCKeyActionDisplay,
            (GetCurrentEventKeyModifiers and not cmdkey) shr 8, LMGetKbdType,
            kUCKeyTranslateNoDeadKeysMask, DeadKeys, 6, TextLen, @WideBuf[1]), SName, 'UCKeyTranslate');
        {$IFDEF VerboseKeyboard}
        debugln(['TranslateMacKeyCode IsSysKey: TextLen=',TextLen,' CharLen=',CharLen,' UTF8VKCharacter=',UTF8VKCharacter]);
        {$ENDIF}
      end;
    end
    else
    begin
      // uchr style keyboard layouts not always available - fall back to older style
      OSError(KLGetKeyboardLayoutProperty(KeyboardLayout, kKLKCHRData, Layout), SName, 'KLGetKeyboardLayoutProperty');
      {$IFDEF VerboseKeyboard}
       DebugLn('[Keyboard layout] KCHR layout = ', DbgS(Layout));
      {$ENDIF}
      VKKeyChar := Char(KeyTranslate(Layout, KeyCode, DeadKeys) and 255);
      { TODO: workaround for Command modifier suppressing shift? }
    end;

    {$IFDEF VerboseKeyboard}
    debugln(['TranslateMacKeyCode TextLen=',TextLen,' CharLen=',CharLen,' UTF8VKCharacter=',UTF8VKCharacter,' VKKeyChar=',DbgStr(VKKeyChar)]);
    {$ENDIF}

    //printable keys
    //for these keys, send char or UTF8KeyPress

    if TextLen = 0 then
    begin
      if OSError(
        GetEventParameter(AEvent, kEventParamKeyUnicodes, typeUnicodeText, nil,
          6, @TextLen, @WideBuf[1]), SName, AGetEvent, 'kEventParamKeyUnicodes') then Exit;
    end;

    if TextLen>0 then
    begin
      SendChar:=true;

      u:=UTF16CharacterToUnicode(@WideBuf[1],CharLen);
      if CharLen=0 then exit;
      UTF8Character:=LazUTF8.UnicodeToUTF8(u);

      if (UTF8Character<>'') and (ord(Utf8Character[1])<=127) then //It's (true) ascii.
        KeyChar:=Utf8Character[1]
      else //not ascii, get the Mac character.
        if OSError(
          GetEventParameter(AEvent, kEventParamKeyMacCharCodes, typeChar, nil,
            Sizeof(KeyChar), nil, @KeyChar), SName, AGetEvent,
          'kEventParamKeyMacCharCodes') then Exit;

      {$IFDEF VerboseKeyboard}
      debugln(['TranslateMacKeyCode printable key: TextLen=',TextLen,' UTF8Character=',UTF8Character,' KeyChar=',DbgStr(KeyChar),' VKKeyChar=',DbgStr(VKKeyChar)]);
      {$ENDIF}

      // the VKKeyCode is independent of the modifier
      // => use the VKKeyChar instead of the KeyChar
      case VKKeyChar of
        'a'..'z': VKKeyCode:=VK_A+ord(VKKeyChar)-ord('a');
        'A'..'Z': VKKeyCode:=ord(VKKeyChar);
        #27     : VKKeyCode:=VK_ESCAPE;
        #8      : VKKeyCode:=VK_BACK;
        ' '     : VKKeyCode:=VK_SPACE;
        #13     : VKKeyCode:=VK_RETURN;
        '0'..'9':
          case KeyCode of
            MK_NUMPAD0: VKKeyCode:=VK_NUMPAD0;
            MK_NUMPAD1: VKKeyCode:=VK_NUMPAD1;
            MK_NUMPAD2: VKKeyCode:=VK_NUMPAD2;
            MK_NUMPAD3: VKKeyCode:=VK_NUMPAD3;
            MK_NUMPAD4: VKKeyCode:=VK_NUMPAD4;
            MK_NUMPAD5: VKKeyCode:=VK_NUMPAD5;
            MK_NUMPAD6: VKKeyCode:=VK_NUMPAD6;
            MK_NUMPAD7: VKKeyCode:=VK_NUMPAD7;
            MK_NUMPAD8: VKKeyCode:=VK_NUMPAD8;
            MK_NUMPAD9: VKKeyCode:=VK_NUMPAD9
            else VKKeyCode:=ord(VKKeyChar);
          end;
        else
        case KeyCode of
          MK_PADDIV  : VKKeyCode:=VK_DIVIDE;
          MK_PADMULT : VKKeyCode:=VK_MULTIPLY;
          MK_PADSUB  : VKKeyCode:=VK_SUBTRACT;
          MK_PADADD  : VKKeyCode:=VK_ADD;
          MK_PADDEC  : VKKeyCode:=VK_DECIMAL;
          MK_PADENTER:
            begin
              VKKeyCode:=VK_RETURN;
              VKKeyChar:=#13;
              UTF8Character:=VKKeyChar;
            end;
          MK_TILDE: VKKeyCode := VK_OEM_3;
          MK_MINUS: VKKeyCode := VK_OEM_MINUS;
          MK_EQUAL: VKKeyCode := VK_OEM_PLUS;
          MK_BACKSLASH:    VKKeyCode := VK_OEM_5;
          MK_LEFTBRACKET:  VKKeyCode := VK_OEM_4;
          MK_RIGHTBRACKET: VKKeyCode := VK_OEM_6;
          MK_SEMICOLON:    VKKeyCode := VK_OEM_1;
          MK_QUOTE:  VKKeyCode := VK_OEM_7;
          MK_COMMA:  VKKeyCode := VK_OEM_COMMA;
          MK_PERIOD: VKKeyCode := VK_OEM_PERIOD;
          MK_SLASH:  VKKeyCode := VK_OEM_2;
        end;
      end;

      if VKKeyCode=VK_UNKNOWN then
      begin
        // There is no known VK_ code for this characther. Use a dummy keycode
        // (E8, which is unused by Windows) so that KeyUp/KeyDown events will be
        // triggered by LCL.
        // Note: we can't use the raw mac keycode, since it could collide with
        // well known VK_ keycodes (e.g on my italian ADB keyboard, keycode for
        // "&egrave;" is 33, which is the same as VK_PRIOR)
        VKKeyCode:=$E8;
      end;

      {$IFDEF VerboseKeyboard}
      DebugLn('[TranslateMacKeyCode] VKKeyCode=', DbgsVKCode(VKKeyCode), ' Utf8="',
         UTF8Character, '" VKKeyChar="', DbgStr(VKKeyChar), '" KeyChar="',DbgStr(KeyChar),'"' );
      {$ENDIF}

      Result := True;
    end
    else DebugLn('[TranslateMacKeyCode] Error Unable to get Unicode char RawKeyCode = ',
      DbgsVKCode(KeyCode));
  end;


  function LCLCharToMacEvent(const AUTF8Char: AnsiString): Boolean;
  var
    WideBuf: WideString;
  begin
    if AUTF8Char='' then Exit;
    // only one character should be used
    WideBuf:={%H-}UTF8Encode(LazUTF8.UTF8Copy(AUTF8Char, 1,1));
    Result:=(length(WideBuf)>0) and
      (not OSError(SetEventParameter(AEvent, kEventParamKeyUnicodes, typeUnicodeText,
        length(WideBuf)*2, @WideBuf[1]), SName, ASetEvent, 'kEventParamKeyUnicodes'));
  end;


  function HandleRawKeyDownEvent: OSStatus;
  var
    KeyMsg: TLMKeyDown;
    CharMsg: TLMChar;
    OrigChar: AnsiString;

    Menu: MenuRef;
    MenuIdx: MenuItemIndex;
  begin
    Result:=EventNotHandledErr;
    {$IFDEF VerboseKeyboard}
      DebugLN('[HandleRawKeyDownEvent] Widget.LCLObject=', DbgSName(Widget.LCLObject));
    {$ENDIF}

    // create the CN_KEYDOWN message
    FillChar(KeyMsg{%H-}, SizeOf(KeyMsg), 0);
    if IsSysKey then KeyMsg.Msg := CN_SYSKEYDOWN
    else KeyMsg.Msg := CN_KEYDOWN;
    KeyMsg.KeyData := KeyData;
    KeyMsg.CharCode := VKKeyCode;
    
    // is the key combination help key (Cmd + ?)
    if SendChar and IsSysKey and (UTF8Character = '?') then
    begin
      //DebugLn('Application.ShowHelpForObject');
      Application.ShowHelpForObject(Widget.LCLObject);
    end;
    
    // widget can filter some keys from being send to Carbon control
    if Widget.FilterKeyPress(IsSysKey, UTF8Character) then Result := noErr;
    
    //Send message to LCL
    if VKKeyCode<>VK_UNKNOWN then
    begin
      if (DeliverMessage(Widget.LCLObject, KeyMsg) <> 0) or (KeyMsg.CharCode=VK_UNKNOWN) then
      begin
        // the LCL handled the key
        {$IFDEF VerboseKeyboard}
          DebugLn('[HandleRawKeyDownEvent] LCL handled CN_KEYDOWN, exiting');
        {$ENDIF}
        
        NotifyApplicationUserInput(Widget.LCLObject, KeyMsg.Msg);
        Result := noErr;
        Exit;
      end;

      //Here is where we (interface) can do something with the key
      //Call the standard handler. Only Up/Down events are notified.
      Widget.ProcessKeyEvent(KeyMsg);

      //Send a LM_(SYS)KEYDOWN
      if IsSysKey then KeyMsg.Msg := LM_SYSKEYDOWN
      else KeyMsg.Msg := LM_KEYDOWN;
      if (DeliverMessage(Widget.LCLObject, KeyMsg) <> 0) or (KeyMsg.CharCode=VK_UNKNOWN) then
      begin
        // the LCL handled the key
        {$IFDEF VerboseKeyboard}
          DebugLn('[HandleRawKeyDownEvent] LCL handled LM_KEYDOWN, exiting');
        {$ENDIF}
        //Result already set by CallNextEventHandler
        
        NotifyApplicationUserInput(Widget.LCLObject, KeyMsg.Msg);
        Exit;
      end;
    end;

    //We should send a character
    if SendChar then
    begin
      // send the UTF8 keypress
      OrigChar:=UTF8Character;
      if TWinControl(Widget.LCLObject).IntfUTF8KeyPress(UTF8Character,1,IsSysKey) then
      begin
        // the LCL has handled the key
        {$IFDEF VerboseKeyboard}
          Debugln('[HandleRawKeyDownEvent] LCL handled IntfUTF8KeyPress, exiting');
        {$ENDIF}
        if Result=EventNotHandledErr then
          Result := noErr;
        Exit;
      end;
      if OrigChar<>UTF8Character then
        LCLCharToMacEvent(UTF8Character);

      // create the CN_CHAR / CN_SYSCHAR message
      FillChar(CharMsg{%H-}, SizeOf(CharMsg), 0);
      if IsSysKey then CharMsg.Msg := CN_SYSCHAR
      else CharMsg.Msg := CN_CHAR;
      CharMsg.KeyData := KeyData;
      CharMsg.CharCode := ord(KeyChar);

      //Send message to LCL
      if (DeliverMessage(Widget.LCLObject, CharMsg) <> 0) or (CharMsg.CharCode=VK_UNKNOWN) then
      begin
        // the LCL handled the key
        {$IFDEF VerboseKeyboard}
          Debugln('[HandleRawKeyDownEvent] LCL handled CN_CHAR, exiting');
        {$ENDIF}
        if Result=EventNotHandledErr then
          Result := noErr;
          
        NotifyApplicationUserInput(Widget.LCLObject, CharMsg.Msg);
        Exit;
      end;
      if CharMsg.CharCode<>ord(KeyChar) then
        LCLCharToMacEvent(Char(CharMsg.CharCode));

      if Result<>noErr then
        Result:=CallNextEventHandler(ANextHandler, AEvent);

      if IsMenuKeyEvent(nil, GetCurrentEvent, kMenuEventQueryOnly, @Menu, @MenuIdx) then
      begin
        // re-handling menu
        SendMenuActivate(Menu, MenuIdx);
      end;

      //Send a LM_(SYS)CHAR
      if IsSysKey then
      begin
        //CharMsg.Msg := LM_SYSCHAR
        // Do not send LM_SYSCHAR message - workaround for disabling
        // accelerators like "Cmd + C" for &Caption
        Exit;
      end
      else CharMsg.Msg := LM_CHAR;
      
      if DeliverMessage(Widget.LCLObject, CharMsg) <> 0 then
      begin
        // the LCL handled the key
        {$IFDEF VerboseKeyboard}
          Debugln('[HandleRawKeyDownEvent] LCL handled LM_CHAR, exiting');
        {$ENDIF}
        if Result=EventNotHandledErr then
          Result := noErr;
          
        NotifyApplicationUserInput(Widget.LCLObject, CharMsg.Msg);
        Exit;
      end;
    end;
  end;

  function HandleRawKeyUpEvent : OSStatus;
  var
    KeyMsg: TLMKeyUp;
  begin
    Result:=EventNotHandledErr;
    {$IFDEF VerboseKeyboard}
      DebugLN('[HandleRawKeyUpEvent] Widget.LCLObject=',DbgSName(Widget.LCLObject));
    {$ENDIF}

    // create the CN_KEYUP message
    FillChar(KeyMsg{%H-}, SizeOf(KeyMsg), 0);
    if IsSysKey then KeyMsg.Msg := CN_SYSKEYUP
    else KeyMsg.Msg := CN_KEYUP;
    KeyMsg.KeyData := KeyData;
    KeyMsg.CharCode := VKKeyCode;

    //Send message to LCL
    if VKKeyCode<>VK_UNKNOWN then
    begin
      if (DeliverMessage(Widget.LCLObject, KeyMsg) <> 0) or (KeyMsg.CharCode=VK_UNKNOWN) then
      begin
        // the LCL has handled the key
        {$IFDEF VerboseKeyboard}
          Debugln('[HandleRawKeyUpEvent] LCL handled CN_KEYUP, exiting');
        {$ENDIF}
        Result := noErr;
        
        NotifyApplicationUserInput(Widget.LCLObject, KeyMsg.Msg);
        Exit;
      end;
      
      //Here is where we (interface) can do something with the key
      //Call the standard handler.
      Widget.ProcessKeyEvent(KeyMsg);
      Result:=CallNextEventHandler(ANextHandler, AEvent);

      //Send a LM_(SYS)KEYUP
      if IsSysKey then KeyMsg.Msg := LM_SYSKEYUP
      else KeyMsg.Msg := LM_KEYUP;
      if DeliverMessage(Widget.LCLObject, KeyMsg) <> 0 then
      begin
        // the LCL handled the key
        {$IFDEF VerboseKeyboard}
          Debugln('[HandleRawKeyUpEvent] LCL handled LM_KEYUP, exiting');
        {$ENDIF}
        if Result=EventNotHandledErr then
          Result := noErr;
          
        NotifyApplicationUserInput(Widget.LCLObject, KeyMsg.Msg);
        Exit;
      end;
    end;

  end;

begin
  Result := EventNotHandledErr;

  Control := nil;
  if OSError(GetKeyboardFocus( TCarbonWindow(AWidget).fWindowRef, Control), SName,
    SGetKeyboardFocus) then Exit;
  if Control = nil then Control := AWidget.Content;

  // if a control other than root is found, send the message
  // to the control instead of the window
  // if a lower control without widget is found, use its parent
  Widget := nil;
  while Control <> AWidget.Content do
  begin
    Widget := GetCarbonControl(Pointer(Control));
    if Widget <> nil then Break;
    Control := HIViewGetSuperview(Control);
  end;
  if (Widget = nil) or (Control = AWidget.Content) then Widget := AWidget;

  Widget.BeginEventProc;
  try

    EventKind := GetEventKind(AEvent);
    if EventKind = kEventRawKeyModifiersChanged then
    begin
      if not EmulateModifiersDownUp then Exit;
    end
    else
      if not TranslateMacKeyCode then
      begin
        Debugln('[CarbonWindow_KeyboardProc] ***WARNING: TranslateMacKeyCode failed***');
        Exit;
      end;

    case EventKind of
      kEventRawKeyDown  : Result := HandleRawKeyDownEvent;
      kEventRawKeyRepeat: Result := HandleRawKeyDownEvent;
      kEventRawKeyUp    : Result := HandleRawKeyUpEvent;
    end;
  finally
    Widget.EndEventProc;
  end;
end;

{------------------------------------------------------------------------------
  Name: CarbonWindow_ActivateProc
  Handles window activating/deactivating
 ------------------------------------------------------------------------------}
function CarbonWindow_ActivateProc(ANextHandler: EventHandlerCallRef;
  AEvent: EventRef;
  AWidget: TCarbonWidget): OSStatus; {$IFDEF darwin}mwpascal;{$ENDIF}
var
  DoActivate: Boolean;
  EventKind: UInt32;
  Control: ControlRef;
  FocusWidget: TCarbonWidget;
begin
  {$IFDEF VerboseWindowEvent}
    DebugLn('CarbonWindow_ActivateProc ', DbgSName(AWidget.LCLObject));
  {$ENDIF}
  Result := CallNextEventHandler(ANextHandler, AEvent);
  
  EventKind := GetEventKind(AEvent);
  case EventKind of
    kEventWindowActivated:
      begin
        DoActivate:=true;
        if (AWidget.LCLObject is TCustomForm) then
        begin
          if (TCustomForm(AWidget.LCLObject).Menu <> nil) and
             (TCustomForm(AWidget.LCLObject).Menu.HandleAllocated) then
            CarbonWidgetSet.SetRootMenu(TCustomForm(AWidget.LCLObject).Menu.Handle)
          else
            CarbonWidgetSet.SetRootMenu(0);
        end;
      end;
    kEventWindowDeactivated: DoActivate:=false;
  else
    DebugLn('CarbonWindow_ActivateProc invalid event kind: ' + DbgS(EventKind));
    Exit;
  end;

  if DoActivate
  then LCLSendActivateMsg(AWidget.LCLObject, WA_ACTIVE, false)
  else LCLSendActivateMsg(AWidget.LCLObject, WA_INACTIVE, false);

  // force set and kill focus of focused control
  Control := nil;
  OSError(GetKeyboardFocus(TCarbonWindow(AWidget).fWindowRef, Control), 'CarbonWindow_ActivateProc', SGetKeyboardFocus);
  if Control <> nil
  then FocusWidget := GetCarbonControl(Control)
  else FocusWidget := nil;

  // Focusing the form without controls
  if (FocusWidget = nil) and DoActivate then FocusWidget:=AWidget;

  if FocusWidget <> nil then
  begin
    if DoActivate
    then FocusWidget.FocusSet
    else FocusWidget.FocusKilled;
  end;
end;

{------------------------------------------------------------------------------
  Name: CarbonWindow_ShowWindow
  Handles window minimizing/maximizing/restoring
 ------------------------------------------------------------------------------}
function CarbonWindow_ShowWindow(ANextHandler: EventHandlerCallRef;
  AEvent: EventRef;
  AWidget: TCarbonWidget): OSStatus; {$IFDEF darwin}mwpascal;{$ENDIF}
var
  EventKind: UInt32;
  WidgetBounds: TRect;
  Kind: Integer;
begin
  {$IFDEF VerboseWindowEvent}
    DebugLn('CarbonWindow_ShowWindow ', DbgSName(AWidget.LCLObject));
  {$ENDIF}
  
  Result := CallNextEventHandler(ANextHandler, AEvent);

  EventKind := GetEventKind(AEvent);
  
  Kind := -1;
  case EventKind of
  kEventWindowCollapsed: Kind := SIZE_MINIMIZED;
  kEventWindowExpanded, kEventWindowZoomed:
    begin
      if IsWindowInStandardState(TCarbonWindow(AWidget).fWindowRef, nil, nil) then
        Kind := SIZE_MAXIMIZED
      else
        Kind := SIZE_RESTORED;
    end;
  else
    DebugLn('CarbonWindow_ShowWindow invalid event kind: ' + DbgS(EventKind));
    Exit;
  end;
  
  {$IFDEF VerboseWindowEvent}
    DebugLn('CarbonWindow_ShowWindow Event: ', DbgS(EventKind) + ' Kind: ' +
      DbgS(Kind) + ' Showing: ' + DbgS(AWidget.LCLObject.Showing));
  {$ENDIF}
  
  if Kind >= 0 then
  begin
    AWidget.GetBounds(WidgetBounds{%H-});
    LCLSendSizeMsg(AWidget.LCLObject, WidgetBounds.Right - WidgetBounds.Left,
      WidgetBounds.Bottom - WidgetBounds.Top, Size_SourceIsInterface or Kind);
  end;
end;

{ TCarbonWindow }

procedure TCarbonWindow.BoundsChanged;
begin
  inherited BoundsChanged;

{  if Assigned(fWindowRef) then begin
    GetClientRect(r);
    hr.origin := GetHIPoint(0,0);
    hr.size := GetHISize(r.Right - r.Left, r.Bottom - r.Top);
    HIViewSetFrame(FScrollView, hr);
  end;}
end;

procedure TCarbonWindow.RegisterWindowEvents;
var
  MouseSpec: array [0..6] of EventTypeSpec;
  TmpSpec: EventTypeSpec;
  KeySpecs: array[0..3] of EventTypeSpec;
  ActivateSpecs: array[0..1] of EventTypeSpec;
  ShowWindowSpecs: array[0..2] of EventTypeSpec;
  WinContent: HIViewRef;
begin
  // Window Events

  TmpSpec := MakeEventSpec(kEventClassWindow, kEventWindowClose);
  InstallWindowEventHandler(fWindowRef,
    RegisterEventHandler(@CarbonWindow_Close),
    1, @TmpSpec, Pointer(Self), nil);

  TmpSpec := MakeEventSpec(kEventClassWindow, kEventWindowClosed);
  InstallWindowEventHandler(fWindowRef,
    RegisterEventHandler(@CarbonCommon_Dispose),
    1, @TmpSpec, Pointer(Self), nil);

  MouseSpec[0].eventClass := kEventClassMouse;
  MouseSpec[0].eventKind := kEventMouseDown;
  MouseSpec[1].eventClass := kEventClassMouse;
  MouseSpec[1].eventKind := kEventMouseUp;
  MouseSpec[2].eventClass := kEventClassMouse;
  MouseSpec[2].eventKind := kEventMouseMoved;
  MouseSpec[3].eventClass := kEventClassMouse;
  MouseSpec[3].eventKind := kEventMouseDragged;
  MouseSpec[4].eventClass := kEventClassMouse;
  MouseSpec[4].eventKind := kEventMouseEntered;
  MouseSpec[5].eventClass := kEventClassMouse;
  MouseSpec[5].eventKind := kEventMouseExited;
  MouseSpec[6].eventClass := kEventClassMouse;
  MouseSpec[6].eventKind := kEventMouseWheelMoved;

  InstallWindowEventHandler(fWindowRef,
    RegisterEventHandler(@CarbonWindow_MouseProc),
    7, @MouseSpec[0], Pointer(Self), nil);

  KeySpecs[0].eventClass := kEventClassKeyboard;
  KeySpecs[0].eventKind := kEventRawKeyDown;
  KeySpecs[1].eventClass := kEventClassKeyboard;
  KeySpecs[1].eventKind := kEventRawKeyRepeat;
  KeySpecs[2].eventClass := kEventClassKeyboard;
  KeySpecs[2].eventKind := kEventRawKeyUp;
  KeySpecs[3].eventClass := kEventClassKeyboard;
  KeySpecs[3].eventKind := kEventRawKeyModifiersChanged;

  InstallWindowEventHandler(fWindowRef,
    RegisterEventHandler(@CarbonWindow_KeyboardProc),
    4, @KeySpecs[0], Pointer(Self), nil);

  ActivateSpecs[0].eventClass := kEventClassWindow;
  ActivateSpecs[0].eventKind := kEventWindowActivated;
  ActivateSpecs[1].eventClass := kEventClassWindow;
  ActivateSpecs[1].eventKind := kEventWindowDeactivated;

  InstallWindowEventHandler(fWindowRef,
    RegisterEventHandler(@CarbonWindow_ActivateProc),
    2, @ActivateSpecs[0], Pointer(Self), nil);

  ShowWindowSpecs[0].eventClass := kEventClassWindow;
  ShowWindowSpecs[0].eventKind := kEventWindowCollapsed;
  ShowWindowSpecs[1].eventClass := kEventClassWindow;
  ShowWindowSpecs[1].eventKind := kEventWindowExpanded;
  ShowWindowSpecs[2].eventClass := kEventClassWindow;
  ShowWindowSpecs[2].eventKind := kEventWindowZoomed;

  InstallWindowEventHandler(fWindowRef,
    RegisterEventHandler(@CarbonWindow_ShowWindow),
    3, @ShowWindowSpecs[0], Pointer(Self), nil);

  TmpSpec := MakeEventSpec(kEventClassWindow, kEventWindowBoundsChanged);
  InstallWindowEventHandler(fWindowRef,
    RegisterEventHandler(@CarbonCommon_BoundsChanged),
    1, @TmpSpec, Pointer(Self), nil);

  // cursor change
  TmpSpec := MakeEventSpec(kEventClassWindow, kEventWindowCursorChange);
  InstallWindowEventHandler(fWindowRef,
    RegisterEventHandler(@CarbonCommon_CursorChange),
    1, @TmpSpec, Pointer(Self), nil);

  // user messages
  TmpSpec := MakeEventSpec(LCLCarbonEventClass, LCLCarbonEventKindUser);
  InstallWindowEventHandler(fWindowRef,
    RegisterEventHandler(@CarbonCommon_User),
    1, @TmpSpec, Pointer(Self), nil);

  // paint content message
  if (HIViewFindByID( HIViewGetRoot(fWindowRef), kHIViewWindowContentID, WinContent{%H-}) = noErr) then
  begin
    TmpSpec := MakeEventSpec(kEventClassControl, kEventControlDraw);
    InstallControlEventHandler(WinContent,
      RegisterEventHandler(@CarbonWindow_ContentDraw),
      1, @TmpSpec, Pointer(Self), nil);
  end;
end;

procedure TCarbonWindow.CreateWindow(const AParams: TCreateParams);
var
  AWindow: WindowRef;
  NewWindowClass: Integer;
  GroupClass: Integer;
  MinSize, MaxSize: HISize;
  Attributes: WindowAttributes;
begin
  // apply appropriate form style and form border style
  FSheetWin := nil;
  if csDesigning in LCLObject.ComponentState then
  begin
    GroupClass := kDocumentWindowClass;
    Attributes := kWindowInWindowMenuAttribute or
      GetBorderWindowAttrs(bsSizeable, [biMaximize, biMinimize, biSystemMenu]);
  end
  else
  begin
    Attributes := 0;
    case (LCLObject as TCustomForm).FormStyle of
    fsStayOnTop, fsSplash:
      GroupClass := kFloatingWindowClass;
    fsSystemStayOnTop:
      GroupClass := kUtilityWindowClass;
    else
      GroupClass := kDocumentWindowClass;
      Attributes := kWindowInWindowMenuAttribute;
    end;
    Attributes := Attributes or
      GetBorderWindowAttrs((LCLObject as TCustomForm).BorderStyle,
        (LCLObject as TCustomForm).BorderIcons);
    {case NewWindowClass of
      kMovableModalWindowClass:
        Attributes := Attributes and (not kWindowInWindowMenuAttribute);
      kFloatingWindowClass:
        Attributes := Attributes and (not (kWindowInWindowMenuAttribute or kWindowCollapseBoxAttribute));
    end;}
    if CREATESHEETWINDOW = PtrUInt(LCLObject) then
    begin
      CREATESHEETWINDOW := 0;
      GroupClass := kSheetWindowClass;
    end;
  end;

  //DebugLn('TCarbonWindow.CreateWidget ' + DbgS(ParamsToCarbonRect(AParams)));

  if GroupClass = kSheetWindowClass then
  begin
    NewWindowClass := GroupClass;
    Attributes := kWindowCompositingAttribute or kWindowStandardHandlerAttribute;
  end else
  begin
    NewWindowClass:=kDocumentWindowClass;
    Attributes := Attributes or kWindowCompositingAttribute or kWindowStandardHandlerAttribute
      or kWindowLiveResizeAttribute;
  end;

  // Makes the window look good in Retina displays
  Attributes := Attributes or kWindowFrameworkScaledAttribute;

  if OSError(
    CreateNewWindow(NewWindowClass,
      Attributes, GetCarbonRect(0, 0, 0, 0), AWindow{%H-}),
    Self, SCreateWidget, 'CreateNewWindow') then
  begin
    DebugLn('Unable to create a window with selected class '+IntToStr(NewWindowClass)+ ', and attributes,'+IntToStr(Attributes)+', fallback to kDocumentWindowClass');
    if OSError(CreateNewWindow(kDocumentWindowClass,
      Attributes, GetCarbonRect(0, 0, 0, 0), AWindow),
    Self, SCreateWidget, 'CreateNewWindow') then RaiseCreateWidgetError(LCLObject);
  end;

  fWindowRef := AWindow;

  OSError(
    SetWindowGroup(fWindowRef, GetWindowGroupOfClass(GroupClass)), Self,
    SCreateWidget, 'SetWindowGroup');

  // creating wrapped views
  if OSError(
    HIViewFindByID(HIViewGetRoot(fWindowRef), kHIViewWindowContentID, fWinContent),
    Self, SCreateWidget, 'HIViewGetRoot') then RaiseCreateWidgetError(LCLObject);

  OSError(
    SetWindowProperty(AWindow, LAZARUS_FOURCC, WIDGETINFO_FOURCC, SizeOf(Self), @Self),
    Self, SCreateWidget, 'SetWindowProperty');
  OSError(
    SetControlProperty(fWinContent, LAZARUS_FOURCC, WIDGETINFO_FOURCC, SizeOf(Self), @Self),
    Self, SCreateWidget, SSetControlProp);

  SetBounds(LCLObject.BoundsRect);
  SetText(AParams.Caption);
  //DebugLn('TCarbonWindow.CreateWidget succeeds');
  SetColor(LCLObject.Color);

  MinSize.width := LCLObject.Constraints.EffectiveMinWidth;
  MinSize.height := LCLObject.Constraints.EffectiveMinHeight;
  MaxSize.width := LCLObject.Constraints.EffectiveMaxWidth;
  MaxSize.height := LCLObject.Constraints.EffectiveMaxHeight;
  if MaxSize.width <= 0 then MaxSize.width := 10000;
  if MaxSize.height <= 0 then MaxSize.height := 10000;

  OSError(SetWindowResizeLimits(AWindow, @MinSize, @MaxSize), Self, SCreateWidget,
    'SetWindowResizeLimits');
end;

{------------------------------------------------------------------------------
  Method:  TCarbonWindow.RegisterEvents

  Registers event handlers for window and its content area
 ------------------------------------------------------------------------------}
procedure TCarbonWindow.RegisterEvents;
begin
  inherited;
end;

procedure SetClientAlign(Child, Parent: HIViewRef; FullAlign: Boolean);
var
  Layout: HILayoutInfo;
begin
  HIViewGetLayoutInfo(Child, Layout{%H-});
  if FullAlign then
  begin
    Layout.binding.left.kind  := kHILayoutBindLeft;
    Layout.binding.right.kind := kHILayoutBindRight;
    Layout.binding.top.kind    := kHILayoutBindTop;
    Layout.binding.bottom.kind := kHILayoutBindBottom;
  end else
  begin
    Layout.binding.left.kind  := kHILayoutBindNone;
    Layout.binding.right.kind := kHILayoutBindNone;
    Layout.binding.top.kind    := kHILayoutBindNone;
    Layout.binding.bottom.kind := kHILayoutBindNone;
  end;
  Layout.binding.left.toView := Parent;
  Layout.binding.right.toView := Parent;
  Layout.binding.top.toView := Parent;
  Layout.binding.bottom.toView := Parent;
  HIViewSetLayoutInfo(Child, Layout);
end;

{------------------------------------------------------------------------------
  Method:  TCarbonWindow.CreateWidget
  Params:  AParams - Creation parameters

  Creates Carbon window
 ------------------------------------------------------------------------------}
procedure TCarbonWindow.CreateWidget(const AParams: TCreateParams);
var
  Params  : TCreateParams;
begin
  CreateWindow(AParams);
  RegisterWindowEvents;

  Params := AParams;
  Params.X := 0;
  Params.Y := 0;
  inherited CreateWidget(Params);

  HIViewAddSubview(fWinContent, fScrollView);
  SetClientAlign(fScrollView, fWinContent, true);
  HIViewSetVisible(fScrollView, true);
end;

{------------------------------------------------------------------------------
  Method:  TCarbonWindow.DestroyWidget

  Override to do some clean-up
 ------------------------------------------------------------------------------}
procedure TCarbonWindow.DestroyWidget;
begin
  if Assigned(fWindowRef) then begin
    DisposeWindow(fWindowRef);
    fWindowRef := nil;
    fWinContent := nil;
    fHiddenWin := nil;
  end;
  inherited;
  //Widget := nil;
end;

function TCarbonWindow.GetPreferredSize: TPoint;
const
  MinWinSize = 20;
begin
  //todo: find a proper way to determine prefered window size
  //      by default Carbon returns a height too large
  Result.x:=MinWinSize;
  Result.y:=MinWinSize;
end;

{------------------------------------------------------------------------------
  Method:  TCarbonWindow.AddToWidget
  Params:  AParent - Parent widget

  Adds window to parent widget
 ------------------------------------------------------------------------------}
procedure TCarbonWindow.AddToWidget(AParent: TCarbonWidget);
begin
  if Assigned(AParent) then
  begin
    fHiddenWin := fWindowRef;
    fWindowRef := nil;
    if IsWindowVisible(fHiddenWin) then HideWindow(fHiddenWin);
    OSError(HIViewAddSubview(AParent.Content, FScrollView), Self, 'AddToWidget', SViewAddView);
    AParent.ControlAdded;
    SetClientAlign(FScrollView, fWinContent, false);
  end else begin
    if IsVisible then
    begin
      ShowWindow(fHiddenWin);
      OSError(HIViewAddSubview(fWinContent, FScrollView), Self, 'AddToWidget', SViewAddView);
    end;
    SetClientAlign(FScrollView, fWinContent, true);
    fWindowRef := fHiddenWin;
  end;
end;

{------------------------------------------------------------------------------
  Method:  TCarbonWindow.GetMousePos
  Returns: The position of mouse cursor in local coordinates
 ------------------------------------------------------------------------------}
function TCarbonWindow.GetWindowRelativePos(winX, winY: Integer): TPoint;
var
  R,G: MacOSAll.Rect;
begin
  if Assigned(fWindowRef) then
  begin
    OSError(GetWindowBounds(fWindowRef, kWindowStructureRgn, G{%H-}),
      Self, 'GetMousePos', SGetWindowBounds);
    OSError(GetWindowBounds(fWindowRef, kWindowContentRgn, R{%H-}),
      Self, 'GetMousePos', SGetWindowBounds);
    Result.X := winX - (R.left-G.Left);
    Result.Y := winY - (R.Top-G.Top);
  end
  else
    Result := inherited GetWindowRelativePos(winX, winY);
end;

{------------------------------------------------------------------------------
  Method:  TCarbonWindow.GetTopParentWindow
  Returns: Retrieves the window reference
 ------------------------------------------------------------------------------}
function TCarbonWindow.GetTopParentWindow: WindowRef;
begin
  if Assigned(fWindowRef) then
    Result := fWindowRef
  else
    Result := inherited GetTopParentWindow;
end;

{------------------------------------------------------------------------------
  Method:  TCarbonWindow.GetClientRect
  Params:  ARect - Record for client area coordinates
  Returns: If the function succeeds

  Returns the window client rectangle relative to the window frame origin
 ------------------------------------------------------------------------------}
function TCarbonWindow.GetClientRect(var ARect: TRect): Boolean;
var
  AWndRect, AClientRect: MacOSAll.Rect;
const
  SName = 'GetClientRect';
begin
  if Assigned(fWindowRef) then begin
    Result := False;
    if OSError(
      GetWindowBounds(fWindowRef, kWindowStructureRgn, AWndRect{%H-}), Self,
      SName, SGetWindowBounds, 'kWindowStructureRgn') then Exit;
    if OSError(
      GetWindowBounds(fWindowRef, kWindowContentRgn, AClientRect{%H-}), Self,
      SName, SGetWindowBounds, 'kWindowContentRgn') then Exit;

    ARect.Left := AClientRect.Left - AWndRect.Left;
    ARect.Top := AClientRect.Top - AWndRect.Top;
    ARect.Right := AClientRect.Right - AWndRect.Left;
    ARect.Bottom := AClientRect.Bottom - AWndRect.Top;

    Result := True;
  end else
    Result := inherited GetClientRect(ARect);
end;

{------------------------------------------------------------------------------
  Method:  TCarbonWindow.Invalidate
  Params:  Rect - Pointer to rect (optional)

  Invalidates the specified rect or entire area of window content
 ------------------------------------------------------------------------------}
procedure TCarbonWindow.Invalidate(Rect: PRect);
var
  R: TRect;
begin
  if Rect = nil then
    OSError(HiViewSetNeedsDisplay(HIViewRef(Content), True), Self, SInvalidate,
      SViewNeedsDisplay)
  else
  begin
    R := Rect^;
    InflateRect(R, 1, 1);
    OSError(
      HiViewSetNeedsDisplayInRect(HIViewRef(Content), RectToCGRect(R), True),
      Self, SInvalidate, SViewNeedsDisplayRect);
  end;
end;

{------------------------------------------------------------------------------
  Method:  TCarbonWindow.IsEnabled
  Returns: If window is enabled
 ------------------------------------------------------------------------------}
function TCarbonWindow.IsEnabled: Boolean;
begin
  Result := IsControlEnabled(Content);
end;

{------------------------------------------------------------------------------
  Method:  TCarbonWindow.IsVisible
  Returns: If window is visible
 ------------------------------------------------------------------------------}
function TCarbonWindow.IsVisible: Boolean;
begin
  if Assigned(fWindowRef) then
    Result := MacOSAll.IsWindowVisible(fWindowRef)
  else
    Result := inherited IsVisible;

end;

{------------------------------------------------------------------------------
  Method:  TCarbonWindow.Enable
  Params:  AEnable - if enable
  Returns: If window is enabled

  Changes window enabled
 ------------------------------------------------------------------------------}
function TCarbonWindow.Enable(AEnable: Boolean): boolean;
begin
  if Assigned(fWindowRef) then begin
    Result := not MacOSAll.IsControlEnabled(Content);

    // enable/disable window content
    // add/remove standard handler

    if AEnable then
    begin
      OSError(MacOSAll.EnableControl(Content), Self, SEnable, SEnableControl);
      OSError(
        ChangeWindowAttributes(fWindowRef,kWindowStandardHandlerAttribute,
          kWindowNoAttributes), Self, SEnable, SChangeWindowAttrs);
    end
    else
    begin
      OSError(MacOSAll.DisableControl(Content), Self, SEnable, SDisableControl);
      OSError(
        ChangeWindowAttributes(fWindowRef, kWindowNoAttributes,
          kWindowStandardHandlerAttribute), Self, SEnable, SChangeWindowAttrs);
    end;
  end else
    Result := inherited Enable(AEnable)
end;

{------------------------------------------------------------------------------
  Method:  TCarbonWindow.GetBounds
  Params:  ARect - Record for window coordinates
  Returns: If function succeeds

  Returns the window bounding rectangle relative to the client origin of its
  parent
  Note: only the pos of rectangle is exact, its size is size of client area
 ------------------------------------------------------------------------------}
function TCarbonWindow.GetBounds(var ARect: TRect): Boolean;
var
  AWndRect, AClientRect: MacOSAll.Rect;
const
  SName = 'GetBounds';
begin
  if Assigned(fWindowRef) then begin
    Result := False;

    if OSError(
      MacOSAll.GetWindowBounds(fWindowRef, kWindowStructureRgn, AWndRect{%H-}),
      Self, SName, SGetWindowBounds, 'kWindowStructureRgn') then Exit;
    if OSError(
      MacOSAll.GetWindowBounds(fWindowRef, kWindowContentRgn, AClientRect{%H-}),
      Self, SName, SGetWindowBounds, 'kWindowContentRgn') then Exit;

    ARect.Left := AWndRect.Left;
    ARect.Top := AWndRect.Top;
    ARect.Right := ARect.Left + (AClientRect.Right - AClientRect.Left);
    ARect.Bottom := ARect.Top + (AClientRect.Bottom - AClientRect.Top);

    Result := True;
  end else
    Result := inherited GetBounds(ARect);
end;

{------------------------------------------------------------------------------
  Method:  TCarbonWindow.GetScreenBounds
  Params:  ARect - Record for window coordinates
  Returns: If function succeeds

  Returns the window bounding rectangle relative to the screen
  Note: only the pos of rectangle is exact, its size is size of client area
 ------------------------------------------------------------------------------}
function TCarbonWindow.GetScreenBounds(var ARect: TRect): Boolean;
begin
  Result := GetBounds(ARect);
end;

{------------------------------------------------------------------------------
  Method:  TCarbonWindow.SetBounds
  Params:  ARect - Record for window coordinates
  Returns: If function succeeds

  Sets the window content bounding rectangle relative to the window frame origin
 ------------------------------------------------------------------------------}
function TCarbonWindow.SetBounds(const ARect: TRect): Boolean;
const
  SName = 'SetBounds';
begin
  if Assigned(fWindowRef) then begin //
    Result := False;
    BeginUpdate(fWindowRef);
    Resizing := True;
    try
      // set window width, height
      if OSError(MacOSAll.SetWindowBounds(fWindowRef, kWindowContentRgn,
        GetCarbonRect(ARect)), Self, SName, 'SetWindowBounds') then Exit;
      // set window left, top
      if OSError(MoveWindowStructure(fWindowRef, ARect.Left, ARect.Top),
        Self, SName, 'MoveWindowStructure') then Exit;
    finally
      Resizing := False;
      EndUpdate(fWindowRef);
    end;
    Result := True;
  end else
    Result := inherited SetBounds(ARect);
end;

{------------------------------------------------------------------------------
  Method:  TCarbonWindow.SetFocus

  Sets the focus to window
 ------------------------------------------------------------------------------}
procedure TCarbonWindow.SetFocus;
begin
  if Assigned(fWindowRef) then
    OSError(
      SetUserFocusWindow(fWindowRef), Self, SSetFocus, SSetUserFocusWindow)
  else
    inherited;
end;

{------------------------------------------------------------------------------
  Method:  TCarbonWindow.SetColor
  Params:  AColor - New color

  Sets the color of window content
 ------------------------------------------------------------------------------}
procedure TCarbonWindow.SetColor(const AColor: TColor);
var
  Color: TColor;
begin
  if Assigned(fWindowRef) then
  begin
    Color := AColor;
    if Color = clDefault then
      Color := LCLObject.GetDefaultColor(dctBrush);
    OSError(SetWindowContentColor(fWindowRef, ColorToRGBColor(Color)),
      Self, SSetColor, 'SetWindowContentColor');
  end
  else
    inherited SetColor(AColor);
end;

{------------------------------------------------------------------------------
  Method:  TCarbonWindow.SetFont
  Params:  AFont - New font

  Sets the font of window
 ------------------------------------------------------------------------------}
procedure TCarbonWindow.SetFont(const AFont: TFont);
begin
  if Assigned(fWindowRef) then // not supported
  else
    inherited SetFont(AFont);
end;

{------------------------------------------------------------------------------
  Method:  TCarbonWindow.SetZOrder
  Params:  AOrder     - Order
           ARefWidget - Reference widget

  Sets the Z order of window
 ------------------------------------------------------------------------------}
procedure TCarbonWindow.SetZOrder(AOrder: HIViewZOrderOp;
  ARefWidget: TCarbonWidget);
begin
  if Assigned(fWindowRef) then // not supported
  else
    inherited SetZOrder(AOrder, ARefWidget);
end;

{------------------------------------------------------------------------------
  Method:  TCarbonWindow.ShowHide
  Params:  AVisible - if show

  Shows or hides window
 ------------------------------------------------------------------------------}
procedure TCarbonWindow.ShowHide(AVisible: Boolean);
begin
  //DebugLn('TCarbonWindow.ShowHide ' + DbgSName(LCLobject),' ', DbgS(AVisible));
  if Assigned(fWindowRef) then begin
    if AVisible or (csDesigning in LCLobject.ComponentState) then
    begin
      MacOSAll.ShowWindow(fWindowRef);
    end
    else
      MacOSAll.HideWindow(fWindowRef);
  end else
    inherited ShowHide(AVisible);
end;

{------------------------------------------------------------------------------
  Method:  TCarbonWindow.GetText
  Params:  S - Text
  Returns: If the function succeeds

  Gets the title of window
 ------------------------------------------------------------------------------}
function TCarbonWindow.GetText(var S: String): Boolean;
begin
  Result := False; // window title is static
end;

{------------------------------------------------------------------------------
  Method:  TCarbonWindow.SetText
  Params:  S - New text
  Returns: If the function succeeds

  Sets the title of window
 ------------------------------------------------------------------------------}
function TCarbonWindow.SetText(const S: String): Boolean;
var
  CFString: CFStringRef;
begin
  //todo: S must be stored, to restore the text when switched between Window and Control mode

  if Assigned(fWindowRef) then begin
    Result := False;
    CreateCFString(S, CFString);
    try
      if OSError(SetWindowTitleWithCFString(fWindowRef, CFString), Self,
        SSetText, 'SetWindowTitleWithCFString') then Exit;
      Result := True;
    finally
      FreeCFString(CFString);
    end;
  end else
    Result := inherited SetText(S);
end;

{------------------------------------------------------------------------------
  Method:  TCarbonWindow.Update
  Returns: If the function succeeds

  Updates window content
 ------------------------------------------------------------------------------}
function TCarbonWindow.Update: Boolean;
begin
  Result := False;
  if OSError(HIViewRender(Widget), Self, 'Update', SViewRender) then Exit;
  Result := True;
end;

{------------------------------------------------------------------------------
  Method:  TCarbonWindow.WidgetAtPos
  Params:  P
  Returns: Retrieves the embedded Carbon control at the specified pos
 ------------------------------------------------------------------------------}
function TCarbonWindow.WidgetAtPos(const P: TPoint): ControlRef;
begin
  Result := Content;
end;

{------------------------------------------------------------------------------
  Method:  TCarbonWindow.Activate
  Returns: If the function suceeds

  Activates Carbon window
 ------------------------------------------------------------------------------}
function TCarbonWindow.Activate: Boolean;
begin
  Result := False;
  if not Assigned(fWindowRef) then Exit;
  
  if OSError(ActivateWindow(fWindowRef, True), Self, 'Activate',
    'ActivateWindow') then Exit;

  Result := True;
end;

{------------------------------------------------------------------------------
  Method:  TCarbonWindow.CloseModal

  Closes modal Carbon window
 ------------------------------------------------------------------------------}
procedure TCarbonWindow.CloseModal;
begin
  if not Assigned(fWindowRef) then Exit; // not possible to show modal if not Window mode

  //if ((LCLObject as TCustomForm).Menu <> nil) and ((LCLObject as TCustomForm).Menu.HandleAllocated) and
  //   (CarbonWidgetSet.MainMenu <>  (LCLObject as TCustomForm).Menu.Handle) then
  CarbonWidgetSet.SetMainMenuEnabled(fPrevMenuEnabled);

  OSError(
    SetWindowModality(fWindowRef, kWindowModalityNone, nil),
    Self, 'CloseModal', SSetModality);
end;

{------------------------------------------------------------------------------
  Method:  TCarbonWindow.ShowModal

  Shows modal Carbon window
 ------------------------------------------------------------------------------}
procedure TCarbonWindow.ShowModal;
begin
  if not Assigned(fWindowRef) then Exit; // not possible to show modal if not Window mode

  OSError(
    SetWindowModality(fWindowRef, kWindowModalityAppModal, nil),
    Self, 'ShowModal', SSetModality);

  SelectWindow(fWindowRef);

  fPrevMenuEnabled:=CarbonWidgetset.MenuEnabled;

  if ((LCLObject as TCustomForm).Menu <> nil) and
     ((LCLObject as TCustomForm).Menu.HandleAllocated) and
     (CarbonWidgetSet.MainMenu = (LCLObject as TCustomForm).Menu.Handle) then
  begin
    CarbonWidgetSet.SetMainMenuEnabled(True)
  end
  else
    // Disable the main menu, so the modal window cannot be called again
    // if it's previously called by the menu shortcut
    // see bug #15913
    CarbonWidgetSet.SetMainMenuEnabled(False);
end;

{------------------------------------------------------------------------------
  Method:  TCarbonWindow.IsIconic

  Check if window is minimized
 ------------------------------------------------------------------------------}
function TCarbonWindow.IsIconic: Boolean;
begin
  if not Assigned(fWindowRef) then Exit(False);
  Result := IsWindowCollapsed(fWindowRef);
end;

{------------------------------------------------------------------------------
  Method:  TCarbonWindow.IsZoomed

  Check if window is maximized
 ------------------------------------------------------------------------------}
function TCarbonWindow.IsZoomed: Boolean;
begin
  if not Assigned(fWindowRef) then Exit(False);
  Result := IsWindowInStandardState(fWindowRef, nil, nil);
end;

{------------------------------------------------------------------------------
  Method:  TCarbonWindow.SetForeground
  Returns: If the function succeeds

  Brings the Carbon window to front and activates it
------------------------------------------------------------------------------}
function TCarbonWindow.SetForeground: Boolean;
begin
  Result := False;
  if not Assigned(fWindowRef) then Exit;

  SelectWindow(fWindowRef); // activate and move window to front
  Result := True;
end;

{------------------------------------------------------------------------------
  Method:  TCarbonWindow.Show
  Params:  AShow - (SW_SHOWNORMAL, SW_MINIMIZE, SW_SHOWMAXIMIZED)
  Returns: If the function succeeds

  Shows the Carbon window normal, minimized or maximized
------------------------------------------------------------------------------}
function TCarbonWindow.Show(AShow: Integer): Boolean;
var
  P: MacOSAll.Point;
  Maximized: Boolean;
  FullScreen: Boolean;
  UIMode: SystemUIMode;
  UIOptions: SystemUIOptions;
const
  SName = 'Show';
  SCollapse = 'CollapseWindow';
  SZoomIdeal = 'ZoomWindowIdeal';
begin
  Result := False;
  if not Assigned(fWindowRef) then
    Exit;
  //DebugLn('TCarbonWindow.Show ' + DbgS(AShow));

  case AShow of
  SW_SHOW, SW_HIDE:
  begin
    ShowHide(AShow = SW_SHOW);
    Result := True;
  end;

  SW_SHOWNORMAL, SW_SHOWMAXIMIZED, SW_SHOWFULLSCREEN:
  begin
    if IsWindowCollapsed(fWindowRef) then
      if OSError(CollapseWindow(fWindowRef, False),
        Self, SName, SCollapse) then Exit;

    // for checking if any change is necessary
    Maximized := IsWindowInStandardState(fWindowRef, nil, nil);
    GetSystemUIMode(@UIMode, @UIOptions);
    FullScreen := (UIMode = kuiModeAllHidden) and (UIOptions = kUIOptionAutoShowMenuBar);

    if FullScreen then
    begin
      SetSystemUIMode(kuiModeNormal, 0);
      if OSError(ZoomWindowIdeal(fWindowRef, inZoomIn, P{%H-}),
        Self, SName, SZoomIdeal, 'inZoomIn') then Exit;
      exit(True);
    end;

    if (AShow = SW_SHOWNORMAL) then
    begin
      if Maximized then
        if OSError(ZoomWindowIdeal(fWindowRef, inZoomIn, P),
          Self, SName, SZoomIdeal, 'inZoomIn') then Exit;
    end
    else
    begin
      if AShow = SW_SHOWFULLSCREEN then
        SetSystemUIMode(kuiModeAllHidden, kUIOptionAutoShowMenuBar);

      if not Maximized or (AShow = SW_SHOWFULLSCREEN) then
      begin
        P.v := $3FFF;
        P.h := $3FFF;
        if OSError(ZoomWindowIdeal(fWindowRef, inZoomOut, P),
         Self, SName, SZoomIdeal, 'inZoomOut') then Exit;
      end;
    end;
    SetForeground;
  end;
  SW_MINIMIZE:
    begin
      if OSError(CollapseWindow(fWindowRef, True),
        Self, SName, SCollapse) then Exit;
    end;
  end;

  Result := True;
end;

{------------------------------------------------------------------------------
  Method:  TCarbonWSCustomForm.SetBorderIcons
  Params:  ABorderIcons - Border icons

  Sets the border icons of Carbon window
 ------------------------------------------------------------------------------}
procedure TCarbonWindow.SetBorderIcons(ABorderIcons: TBorderIcons);
var
  AttrsSet, AttrsRemove: WindowAttributes;
begin
  if not Assigned(fWindowRef) then Exit;

  if csDesigning in LCLObject.ComponentState then Exit;
  BeginUpdate(fWindowRef);
  try
    AttrsSet := GetBorderWindowAttrs((LCLObject as TCustomForm).BorderStyle,
      ABorderIcons);
    AttrsRemove := (kWindowNoTitleBarAttribute or kWindowCloseBoxAttribute or
      kWindowCollapseBoxAttribute or kWindowFullZoomAttribute or
      kWindowResizableAttribute) and (not AttrsSet);

    if OSError(
      ChangeWindowAttributes(fWindowRef, AttrsSet, AttrsRemove), Self,
        'SetBorderIcons', SChangeWindowAttrs) then Exit;
  finally
    EndUpdate(fWindowRef);
  end;
end;

{------------------------------------------------------------------------------
  Method:  TCarbonWSCustomForm.SetFormBorderStyle
  Params:  AFormBorderStyle - Form border style

  Sets the form border style of Carbon window
 ------------------------------------------------------------------------------}
procedure TCarbonWindow.SetFormBorderStyle(AFormBorderStyle: TFormBorderStyle);
var
  AttrsSet, AttrsRemove: WindowAttributes;
begin

  if (csDesigning in LCLObject.ComponentState) or not Assigned(fWindowRef) then Exit;
  BeginUpdate(fWindowRef);
  try
    AttrsSet := GetBorderWindowAttrs(AFormBorderStyle,
      (LCLObject as TCustomForm).BorderIcons);
    AttrsRemove := (kWindowNoTitleBarAttribute or kWindowCloseBoxAttribute or
      kWindowCollapseBoxAttribute or kWindowFullZoomAttribute or
      kWindowResizableAttribute) and (not AttrsSet);

    if OSError(
      ChangeWindowAttributes(fWindowRef, AttrsSet, AttrsRemove), Self,
        'SetFormBorderStyle', SChangeWindowAttrs) then Exit;
  finally
    EndUpdate(fWindowRef);
  end;
end;

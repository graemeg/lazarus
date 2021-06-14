{%MainUnit win32int.pp}

{
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
type
  TWinControlAccess = class(TWinControl);
{*************************************************************}
{            callback routines                                }
{*************************************************************}

procedure PrepareSynchronize;
begin
  TWin32WidgetSet(WidgetSet).HandleWakeMainThread(nil);
end;

{-----------------------------------------------------------------------------
  Function: PropEnumProc
  Params: Window - The window with the property
          Str    - The property name
          Data   - The property value
  Returns: Whether the enumeration should continue

  Enumerates and removes properties for the target window
 -----------------------------------------------------------------------------}
function PropEnumProc(Window: Hwnd; Str: PChar; Data: Handle): LongBool; stdcall;
begin
  Result:=false;
  if PtrUInt(Str) <= $FFFF then exit; // global atom handle
  RemoveProp(Window, Str);
  Result := True;
end;

{------------------------------------------------------------------------------
 Function: CallDefaultWindowProc
 Params: Window - The window that receives a message
         Msg    - The message received
         WParam - Word parameter
         LParam - Long-integer parameter
 Returns: 0 if Msg is handled; non-zero long-integer result otherwise

 Passes message on to 'default' handler. This can be a control specific window
 procedure or the default window procedure.
 ------------------------------------------------------------------------------}
function CallDefaultWindowProc(Window: HWnd; Msg: UInt; WParam: Windows.WParam;
  LParam: Windows.LParam): LResult;
  
  function IsComboboxAndHasEdit(Window: HWnd): Boolean;
  var
    Info: TComboboxInfo;
  begin
    Result := WndClassName(Window) = LCLComboboxClsName;
    if not Result then
      Exit;
    Info.cbSize := SizeOf(Info);
    Win32Extra.GetComboBoxInfo(Window, @Info);
    Result := (Info.hwndItem <> 0) and GetWin32WindowInfo(Info.hwndItem)^.isComboEdit;
  end;
var
  PrevWndProc: Windows.WNDPROC;
{$if defined(MSG_DEBUG) or defined(DBG_SendPaintMessage)}
  depthLen: integer;
{$endif}
  setComboWindow: boolean;
  WindowInfo: PWin32WindowInfo;
begin
{$if defined(MSG_DEBUG) or defined(DBG_SendPaintMessage)}
  depthLen := Length(MessageStackDepth);
  if depthLen > 0 then
    MessageStackDepth[depthLen] := '#';
{$endif}
  WindowInfo := GetWin32WindowInfo(Window);
  PrevWndProc := WindowInfo^.DefWndProc;
  if (PrevWndProc = nil) or (PrevWndProc = @WindowProc) // <- prevent recursion
  then begin
    if (WindowInfo^.WinControl is TCustomForm) and not (csDesigning in WindowInfo^.WinControl.ComponentState) then
    begin
      case TCustomForm(WindowInfo^.WinControl).FormStyle of
        fsMDIForm:
        begin
          if Msg <> WM_COMMAND then
            Result := Windows.DefFrameProcW(Window, Win32WidgetSet.MDIClientHandle, Msg, WParam, LParam)
          else
          if (LoWord(WParam)=SC_CLOSE) or
             (LoWord(WParam)=SC_MAXIMIZE) or
             (LoWord(WParam)=SC_MINIMIZE) or
             (LoWord(WParam)=SC_RESTORE) or
             (LoWord(WParam)=SC_NEXTWINDOW) or
             (LoWord(WParam)=SC_PREVWINDOW)
          then
            Result := Windows.DefFrameProcW(Window, Win32WidgetSet.MDIClientHandle, Msg, WParam, LParam)
          else
            Result := Windows.DefWindowProcW(Window, Msg, WParam, LParam);
        end;
        fsMDIChild:
          Result := Windows.DefMDIChildProcW(Window, Msg, WParam, LParam);
      else
        Result := Windows.DefWindowProcW(Window, Msg, WParam, LParam);
      end;
    end else
      Result := Windows.DefWindowProcW(Window, Msg, WParam, LParam);
  end
  else begin
    // combobox child edit weirdness: combobox handling WM_SIZE will compare text
    // to list of strings, and if appears in there, will set the text, and select it
    // WM_GETTEXTLENGTH, WM_GETTEXT, WM_SETTEXT, EM_SETSEL
    // combobox sends WM_SIZE to itself indirectly, check recursion
    setComboWindow :=
        (Msg = WM_SIZE) and
        (ComboBoxHandleSizeWindow = 0) and
        IsComboboxAndHasEdit(Window);
    if setComboWindow then
      ComboBoxHandleSizeWindow := Window;
    Result := Windows.CallWindowProcW(PrevWndProc, Window, Msg, WParam, LParam);
    if setComboWindow then
      ComboBoxHandleSizeWindow := 0;
  end;
{$if defined(MSG_DEBUG) or defined(DBG_SendPaintMessage)}
  if depthLen > 0 then
    MessageStackDepth[depthLen] := ' ';
{$endif}
end;

procedure DrawParentBackground(Window: HWND; ControlDC: HDC);
var
  Parent: HWND;
  P: TPoint;
begin
  if ThemeServices.ThemesEnabled then
    ThemeServices.DrawParentBackground(Window, ControlDC, nil, False)
  else
  begin
    Parent := Windows.GetParent(Window);
    P.X := 0;
    P.Y := 0;
    Windows.MapWindowPoints(Window, Parent, P, 1);
    Windows.OffsetViewportOrgEx(ControlDC, -P.X, -P.Y, P);
    Windows.SendMessage(Parent, WM_ERASEBKGND, WParam(ControlDC), 0);
    Windows.SendMessage(Parent, WM_PRINTCLIENT, WParam(ControlDC), PRF_CLIENT);
    Windows.SetViewportExtEx(ControlDC, P.X, P.Y, nil);
  end;
end;

type
  TEraseBkgndCommand =
  (
    ecDefault,             // todo: add comments
    ecDiscard,             //
    ecDiscardNoRemove,     //
    ecDoubleBufferNoRemove //
  );
const
  EraseBkgndStackMask = $3;
  EraseBkgndStackShift = 2;
var
  EraseBkgndStack: dword = 0;

{$if defined(MSG_DEBUG) or defined(DBG_SendPaintMessage)}
function EraseBkgndStackToString: string;
var
  I: dword;
begin
  SetLength(Result, 8);
  for I := 0 to 7 do
    Result[8-I] := char(ord('0') + ((EraseBkgndStack shr (I*2)) and $3));
end;
{$endif}

procedure PushEraseBkgndCommand(Command: TEraseBkgndCommand);
begin
{$if defined(MSG_DEBUG) or defined(DBG_SendPaintMessage)}
  case Command of
    ecDiscard: DebugLn(MessageStackDepth,
      ' *forcing next WM_ERASEBKGND to discard message');
    ecDiscardNoRemove: DebugLn(MessageStackDepth,
      ' *forcing next WM_ERASEBKGND to discard message, no remove');
    ecDoubleBufferNoRemove: DebugLn(MessageStackDepth,
      ' *forcing next WM_ERASEBKGND to use double buffer, after that, discard no remove');
  end;
  DebugLn(MessageStackDepth, ' *erasebkgndstack: ', EraseBkgndStackToString);
{$endif}
  EraseBkgndStack := (EraseBkgndStack shl EraseBkgndStackShift) or dword(Ord(Command));
end;

type
  TDoubleBuffer = record
    DC: HDC;
    Bitmap: HBITMAP;
    BitmapWidth: integer;
    BitmapHeight: integer;
  end;

var
  CurDoubleBuffer: TDoubleBuffer = (DC: 0; Bitmap: 0; BitmapWidth: 0; BitmapHeight: 0);
  DisabledForms: TList = nil;
  CurrentWindow: HWND = 0;

function GetNeedParentPaint(AWindowInfo: PWin32WindowInfo; AWinControl: TWinControl): boolean;
begin
  Result := AWindowInfo^.needParentPaint
    and ((AWinControl = nil) or not (csOpaque in AWinControl.ControlStyle));
  if ThemeServices.ThemesEnabled then
    Result := Result or (Assigned(AWinControl) and ([csParentBackground, csOpaque] * AWinControl.ControlStyle = [csParentBackground]));
end;

procedure DisposeComboEditWindowInfo(ComboBox: TCustomComboBox);
var
  Buddy: HWND;
  Info: TComboboxInfo;
begin
  Info.cbSize := SizeOf(Info);
  Win32Extra.GetComboBoxInfo(Combobox.Handle, @Info);
  Buddy := Info.hwndItem;
  if (Buddy <> Info.hwndCombo) and (Buddy <> 0) then
    DisposeWindowInfo(Buddy);
end;

function GetLCLWindowFromPoint(BaseControl: TControl; const Point: TPoint): HWND;
var
  ParentForm: TCustomForm;
  ParentRect: TRect;
  TheControl: TControl;
begin
  Result := 0;
  ParentForm := GetParentForm(BaseControl);
  if ParentForm <> nil then
  begin
    TheControl := ParentForm.ControlAtPos(ParentForm.ScreenToClient(Point), [capfAllowDisabled, capfAllowWinControls,
      capfRecursive, capfHasScrollOffset]);
    if TheControl is TWinControl then
      Result := TWinControlAccess(TheControl).WindowHandle;
    if Result = 0 then
    begin
      ParentRect := Rect(ParentForm.Left, ParentForm.Top,
        ParentForm.Left + ParentForm.Width, ParentForm.Top + ParentForm.Height);
      if PtInRect(ParentRect, Point) then
        Result := ParentForm.Handle;
    end;
  end;
end;

// Used by WindowProc :

function GetMenuParent(ASearch, AParent: HMENU): HMENU;
var
  c, i: integer;
  sub: HMENU;
begin
  c := GetMenuItemCount(AParent);
  for i:= 0 to c - 1 do
  begin
    sub := GetSubMenu(AParent, i);
    if sub = ASearch then
      Exit(AParent);
    Result := GetMenuParent(ASearch, sub);     // Recursive call
    if Result <> 0 then Exit;
  end;
  Result := 0;
end;

function GetIsNativeControl(AWindow: HWND): Boolean;
var
  S: String;
begin
  S := WndClassName(AWindow);
  Result := (S <> ClsName) and (S <> ClsHintName);
end;

procedure ClearSiblingRadioButtons(RadioButton: TRadioButton);
var
  Parent: TWinControl;
  Sibling: TControl;
  WinControl: TWinControlAccess absolute Sibling;
  LParamFlag: LRESULT;
  i: Integer;
begin
  Parent := RadioButton.Parent;
  for i:= 0 to Parent.ControlCount - 1 do
  begin
    Sibling := Parent.Controls[i];
    if (Sibling is TRadioButton) and (Sibling <> RadioButton) then
    begin
      // Pass previous state through LParam so the event handling can decide
      // when to propagate LM_CHANGE (New State <> Previous State)
      LParamFlag := Windows.SendMessage(WinControl.WindowHandle, BM_GETCHECK, 0, 0);
      // Pass SKIP_LMCHANGE through LParam if previous state is already unchecked
      if LParamFlag = BST_UNCHECKED then
        LParamFlag := SKIP_LMCHANGE;
      Windows.SendMessage(WinControl.WindowHandle, BM_SETCHECK,
        Windows.WParam(BST_UNCHECKED), Windows.LParam(LParamFlag));
    end;
  end;
end;

// sets the text of the combobox,
// because some events are risen, before the text is actually changed
procedure UpdateComboBoxText(ComboBox: TCustomComboBox);
var
  Index: Integer;
begin
  Index := ComboBox.ItemIndex;
  // Index might be -1, if current text is not in the list.
  if (Index>=0) then
    TWin32WSWinControl.SetText(ComboBox, ComboBox.Items[Index]);
end;

// A helper class for WindowProc to make it easier to split code into smaller pieces.
// The original function was about 2400 lines.

type
  TAccessCustomEdit = class(TCustomEdit);

  { TWindowProcHelper }

  TWindowProcHelper = record
  private
    procedure SetlWinControl(AValue: TWinControl);
  private
    // WindowProc parameters
    Window: HWnd;            // DWord / QWord
    Msg: UInt;               // LongWord
    WParam: Windows.WParam;  // PtrInt
    LParam: Windows.LParam;  // PtrInt
    // Other variables
    LMessage: TLMessage;
    PLMsg: PLMessage;
    FlWinControl: TWinControl;
    WinProcess: Boolean;
    NotifyUserInput: Boolean;
    WindowInfo: PWin32WindowInfo;
    // Used by SendPaintMessage
    BackupBuffer: TDoubleBuffer;
    WindowWidth, WindowHeight: Integer;
    PaintMsg: TLMPaint;
    RTLLayout: Boolean;
    // Structures for message handling
    OrgCharCode: word; // used in WM_CHAR handling
    LMScroll: TLMScroll; // used by WM_HSCROLL
    LMKey: TLMKey; // used by WM_KEYDOWN WM_KEYUP
    LMChar: TLMChar; // used by WM_CHAR
    LMMouse: TLMMouse; // used by WM_LBUTTONDBLCLK
    LMContextMenu: TLMContextMenu;
    LMMouseMove: TLMMouseMove; // used by WM_MOUSEMOVE
    LMMouseEvent: TLMMouseEvent; // used by WM_MOUSEWHEEL
    LMMove: TLMMove; // used by WM_MOVE
    LMNotify: TLMNotify; // used by WM_NOTIFY
    DrawListItemStruct: TDrawListItemStruct; //used by WM_DRAWITEM
    NMHdr: PNMHdr; // used by WM_NOTIFY

    procedure CalcClipRgn(PaintRegion: HRGN);
    function DoChildEdit(out WinResult: LResult): Boolean;
    procedure DoCmdCheckBoxParam;
    function DoCmdComboBoxParam: Boolean;
    procedure DoMsgActivateApp;
    procedure DoMsgChar(var WinResult: LResult);
    procedure DoMsgColor(ChildWindowInfo: PWin32WindowInfo);
    procedure DoMsgDrawItem;
    procedure DoMsgEnable;
    function DoMsgEraseBkgnd(var WinResult: LResult): Boolean;
    procedure DoMsgKeyDownUp(aMsg: Cardinal; var WinResult: LResult);
    procedure DoMsgMeasureItem;
    procedure DoMsgMouseMove;
    procedure DoMsgMouseDownUpClick(aButton: Byte; aIsDblClick: Boolean; aMouseDown: Boolean);
    procedure DoMsgContextMenu;
    function DoMsgMouseWheel(var WinResult: LResult; AHorz: Boolean): Boolean;
    function DoMsgMove: Boolean;
    procedure DoMsgNCLButtonDown;
    function DoMsgNotify(var WinResult: LResult): Boolean;
    procedure DoMsgShowWindow;
    procedure DoMsgSize;
    procedure DoMsgSysKey(aMsg: Cardinal);
    procedure DoSysCmdKeyMenu;
    procedure DoSysCmdMinimize;
    procedure DoSysCmdRestore;
    function GetPopMenuItemObject: TObject;
    function GetMenuItemObject(ByPosition: Boolean): TObject;
    function PrepareDoubleBuffer(out DoubleBufferBitmapOld: HBITMAP): Boolean;
    procedure SetLMCharData(aMsg: Cardinal; UpdateKeyData: Boolean = False);
    procedure SetLMKeyData(aMsg: Cardinal; UpdateKeyData: Boolean = False);
    procedure SetLMessageAndParams(aMsg: Cardinal; ResetWinProcess: Boolean = False);
    procedure SendPaintMessage(ControlDC: HDC);
    procedure HandleScrollMessage(LMsg: integer);
    procedure HandleSetCursor;
    procedure HandleSysCommand;
    function IsComboEditSelection: boolean;
    procedure HandleBitBtnCustomDraw(ABitBtn: TCustomBitBtn);
    procedure HandleDropFiles;
    function HandleUnicodeChar(var AChar: WideChar): boolean;
    procedure UpdateDrawItems;
    procedure UpdateDrawListItem(aMsg: UInt);
    procedure UpdateLMMovePos(X, Y: Smallint);
    procedure UpdateUIState(CharCode: Word);
    function DoWindowProc: LResult;    // Called from the actual WindowProc.
    property lWinControl: TWinControl read FlWinControl write SetlWinControl;
  end;
  PWindowProcHelper = ^TWindowProcHelper;

  { TWindProcNotificationReceiver }

  TWindProcNotificationReceiver = class
    procedure ReceiveDestroyNotify(Sender: TObject);
  end;


// Implementation of TWindowProcHelper

procedure TWindowProcHelper.SetLMCharData(aMsg: Cardinal; UpdateKeyData: Boolean);
begin
  LMChar.Msg := aMsg;
  LMChar.CharCode := Word(WParam);
  if UpdateKeyData then
    LMChar.KeyData := LParam;
end;

procedure TWindowProcHelper.SetLMKeyData(aMsg: Cardinal; UpdateKeyData: Boolean);
begin
  LMKey.Msg := aMsg;
  LMKey.CharCode := Word(WParam);
  if UpdateKeyData then
    LMKey.KeyData := LParam;
end;

procedure TWindowProcHelper.SetLMessageAndParams(aMsg: Cardinal; ResetWinProcess: Boolean);
begin
  LMessage.Msg := aMsg;
  LMessage.WParam := WParam;
  LMessage.LParam := LParam;
  if ResetWinProcess then
    WinProcess := False;
end;

function TWindowProcHelper.GetPopMenuItemObject: TObject;
var
  MainMenuHandle: HMENU;
  MenuInfo: MENUITEMINFO;
begin
  MenuInfo.cbSize := MMenuItemInfoSize;
  MenuInfo.fMask := MIIM_DATA;

  MainMenuHandle := GetMenuParent(HMENU(WParam), GetMenu(Window));
  if GetMenuItemInfo(MainMenuHandle, LOWORD(LParam), true, @MenuInfo) then
    Result := TObject(MenuInfo.dwItemData)
  else
    Result := nil;
end;

function TWindowProcHelper.GetMenuItemObject(ByPosition: Boolean): TObject;
var
  MenuInfo: MENUITEMINFO;
  PopupMenu: TPopupMenu;
  Menu: HMENU;
begin
  // first we have to decide if the command is from a popup menu
  // or from the window main menu
  // if the 'PopupMenu' property exists, there is a big probability
  // that the command is from a popup menu

  PopupMenu := WindowInfo^.PopupMenu;
  if Assigned(PopupMenu) then
  begin
    Result := PopupMenu.FindItem(LOWORD(Integer(WParam)), fkCommand);
    if Assigned(Result) then
      Exit;
  end;

  // nothing found, process main menu
  MenuInfo.cbSize := MMenuItemInfoSize;
  MenuInfo.fMask := MIIM_DATA;

  if ByPosition then
    Menu := HMENU(LParam)
  else
    Menu := GetMenu(Window);
  if GetMenuItemInfo(Menu, LOWORD(Integer(WParam)), ByPosition, @MenuInfo) then
    Result := TObject(MenuInfo.dwItemData)
  else
    Result := nil;
end;

function TWindowProcHelper.PrepareDoubleBuffer(out DoubleBufferBitmapOld: HBITMAP): Boolean;
// Returns True if BackupBuffer was saved.
var
  DC: HDC;
begin
  Result := CurDoubleBuffer.DC <> 0;
  if Result then
  begin
    // we've been called from another paint handler. To prevent killing of
    // not own DC and HBITMAP lets save then and restore on exit
    BackupBuffer := CurDoubleBuffer;
    FillChar(CurDoubleBuffer, SizeOf(CurDoubleBuffer), 0);
  end;
  CurDoubleBuffer.DC := Windows.CreateCompatibleDC(0);

  GetWindowSize(Window, WindowWidth, WindowHeight);
  if (CurDoubleBuffer.BitmapWidth < WindowWidth) or (CurDoubleBuffer.BitmapHeight < WindowHeight) then
  begin
    DC := Windows.GetDC(0);
    if CurDoubleBuffer.Bitmap <> 0 then
      Windows.DeleteObject(CurDoubleBuffer.Bitmap);
    CurDoubleBuffer.BitmapWidth := WindowWidth;
    CurDoubleBuffer.BitmapHeight := WindowHeight;
    CurDoubleBuffer.Bitmap := Windows.CreateCompatibleBitmap(DC, WindowWidth, WindowHeight);
    Windows.ReleaseDC(0, DC);
    if RTLLayout then  // change the default layout - LTR - of memory DC
      {if (GetLayout(vDC) and LAYOUT_BITMAPORIENTATIONPRESERVED) > 0 then  // GetLayout is not in win32extra
        SetLayout(CurDoubleBuffer.DC, LAYOUT_RTL or LAYOUT_BITMAPORIENTATIONPRESERVED)
      else //}
        SetLayout(CurDoubleBuffer.DC, LAYOUT_RTL);
  end;
  DoubleBufferBitmapOld := Windows.SelectObject(CurDoubleBuffer.DC, CurDoubleBuffer.Bitmap);
  PaintMsg.DC := CurDoubleBuffer.DC;
  {$ifdef MSG_DEBUG}
    DebugLn(MessageStackDepth, ' *double buffering on DC: ', IntToHex(CurDoubleBuffer.DC, sizeof(HDC)*2));
  {$endif}
end;

procedure TWindowProcHelper.SetlWinControl(AValue: TWinControl);
begin
  if FlWinControl = AValue then Exit;
  if FlWinControl <> nil then begin
    FlWinControl.DecLCLRefCount;
    FlWinControl.RemoveHandlerOnBeforeDestruction(@TWindProcNotificationReceiver(@Self).ReceiveDestroyNotify);
  end;

  FlWinControl := AValue;

  if FlWinControl <> nil then begin
    FlWinControl.AddHandlerOnBeforeDestruction(@TWindProcNotificationReceiver(@Self).ReceiveDestroyNotify);
    FlWinControl.IncLCLRefCount;
  end;
end;

procedure TWindowProcHelper.CalcClipRgn(PaintRegion: HRGN);
var
  nSize: DWORD;
  RgnData: PRgnData;
  WindowOrg: Windows.POINT;
  XFRM: TXFORM;
  MirroredPaintRgn: HRGN;
begin
  // winnt returns in screen coordinates
  // win9x returns in window coordinates
  if Win32Platform = VER_PLATFORM_WIN32_NT then
  begin
    WindowOrg.X := 0;
    WindowOrg.Y := 0;
    MapWindowPoints(Window, 0, WindowOrg, 1);
    if RTLLayout then // We need the left side of the client area in screen coordinates
      WindowOrg.X := WindowOrg.X - lWinControl.ClientWidth;
    Windows.OffsetRgn(PaintRegion, -WindowOrg.X, -WindowOrg.Y);
  end;

  if RTLLayout then // Paint region needs to be mirrored before using it for clipping!
  begin
    {
    //Method 1 - Switch Layout to LTR, Clip, Switch back to RTL
    //Sometimes it's off by one or two pixels!!
    SetLayout(CurDoubleBuffer.DC, LAYOUT_LTR);
    Windows.SelectClipRgn(CurDoubleBuffer.DC, PaintRegion);
    SetLayout(CurDoubleBuffer.DC, LAYOUT_RTL);//}

    //Method 2 - Create a mirrored region based on the one we have
    nSize := GetRegionData(PaintRegion, 0, nil);
    RgnData := GetMem(nSize);
    XFRM.eDx:=0;   XFRM.eDy:=0;
    XFRM.eM11:=-1; XFRM.eM12:=0;
    XFRM.eM21:=0;  XFRM.eM22:=1;

    MirroredPaintRgn := ExtCreateRegion(@XFRM, nSize, RgnData^);
    Windows.SelectClipRgn(CurDoubleBuffer.DC, MirroredPaintRgn);
    Windows.DeleteObject(MirroredPaintRgn);
    Freemem(RgnData);
  end
  else
    Windows.SelectClipRgn(CurDoubleBuffer.DC, PaintRegion);
end;

procedure TWindowProcHelper.SendPaintMessage(ControlDC: HDC);
var
  DC: HDC;
  PaintRegion: HRGN;
  PS : TPaintStruct;
  DoubleBufferBitmapOld: HBITMAP;
  ORect: TRect;
{$ifdef DEBUG_DOUBLEBUFFER}
  ClipBox: Windows.RECT;
{$endif}
  ParentPaintWindow: HWND;
  DCIndex: integer;
  parLeft, parTop: integer;
  BufferWasSaved: Boolean;
  useDoubleBuffer: Boolean;
  isNativeControl: Boolean;
  needParentPaint: Boolean;
begin
  // note: ignores the received DC
  // do not use default deliver message
  if lWinControl = nil then
  begin
    lWinControl := GetWin32WindowInfo(Window)^.PWinControl;
    if lWinControl = nil then exit;
  end;

  // create a paint message
  isNativeControl := GetIsNativeControl(Window);
  needParentPaint := GetNeedParentPaint(WindowInfo, lWinControl);
  // if needParentPaint and not isTabPage then background will be drawn in
  // WM_ERASEBKGND and WM_CTLCOLORSTATIC for native controls
  // sent by default paint handler
  if WindowInfo^.isTabPage or (needParentPaint and (not isNativeControl or (ControlDC <> 0))) then
    ParentPaintWindow := Windows.GetParent(Window)
  else
    ParentPaintWindow := 0;
{$IFDEF DBG_SendPaintMessage}
  DebugLnEnter(['>>> SendPaintMessage for CtrlDC=', dbgs(ControlDC), ' Window=', dbgs(Window),
     ' WinCtrl=',dbgs(PtrUInt(lWinControl)), ' ', DbgSName(lWinControl),
     ' NativeCtrl=', dbgs(isNativeControl), ' ndParentPaint=', dbgs(needParentPaint),
     ' isTab=', dbgs(WindowInfo^.isTabPage)    ]);
  try
{$ENDIF}

  // if painting background of some control for tabpage, don't handle erase background
  // in parent of tabpage
  if WindowInfo^.isTabPage then
    PushEraseBkgndCommand(ecDiscard);

  // check if double buffering is requested
  useDoubleBuffer := (ControlDC = 0) and (
      ((csDesigning in lWinControl.ComponentState) and (GetSystemMetrics(SM_REMOTESESSION)=0)) // force double buffer in the designer
    or TWSWinControlClass(TWinControl(lWinControl).WidgetSetClass).GetDoubleBuffered(lWinControl));

  if useDoubleBuffer then
    BufferWasSaved := PrepareDoubleBuffer(DoubleBufferBitmapOld)
  else
    BufferWasSaved := False;
{$ifdef MSG_DEBUG}
  if not useDoubleBuffer then
    DebugLn(MessageStackDepth, ' *painting, but not double buffering');
{$endif}
  WinProcess := false;
  try
    if ControlDC = 0 then
    begin
      // ignore first erase background on themed control, paint will do everything
      if ThemeServices.ThemesEnabled then
        PushEraseBkgndCommand(ecDoubleBufferNoRemove);
      DC := Windows.BeginPaint(Window, @PS);
{$IFDEF DBG_SendPaintMessage}
      if ThemeServices.ThemesEnabled then
        DebugLn(['SendPaintMessage for CtrlDC=', dbgs(ControlDC), ' Remove one from EraseBkgndStack val=', (EraseBkgndStack and 3)]);
{$ENDIF}
      if ThemeServices.ThemesEnabled then
        EraseBkgndStack := EraseBkgndStack shr EraseBkgndStackShift;
      if useDoubleBuffer then
      begin
        RTLLayout := (GetWindowLong(Window, GWL_EXSTYLE) and WS_EX_LAYOUTRTL) = WS_EX_LAYOUTRTL;

        ORect.Left := 0;
        ORect.Top := 0;
        ORect.Right := CurDoubleBuffer.BitmapWidth;
        ORect.Bottom := CurDoubleBuffer.BitmapHeight;
        Windows.FillRect(CurDoubleBuffer.DC, ORect, GetSysColorBrush(COLOR_BTNFACE));

        PaintRegion := CreateRectRgn(0, 0, 1, 1);
        if GetRandomRgn(DC, PaintRegion, SYSRGN) = 1 then
          CalcClipRgn(PaintRegion);
{$ifdef DEBUG_DOUBLEBUFFER}
        Windows.GetClipBox(CurDoubleBuffer.DC, ClipBox);
        DebugLn('Double buffering in DC ', IntToHex(CurDoubleBuffer.DC, sizeof(HDC)*2),
          ' with clipping rect (',
          IntToStr(ClipBox.Left), ',', IntToStr(ClipBox.Top), ';',
          IntToStr(ClipBox.Right), ',', IntToStr(ClipBox.Bottom), ')');
{$endif}
        // a copy of the region is selected into the DC, so we
        // can free our region immediately
        Windows.DeleteObject(PaintRegion);
      end;
    end else begin
      FillChar(PS, SizeOf(PS), 0);
      PS.hdc := ControlDC;
      Windows.GetUpdateRect(Window, @PS.rcPaint, False);
      DC := ControlDC;
      PaintRegion := 0;
    end;

    if ParentPaintWindow <> 0 then
      GetWin32ControlPos(Window, ParentPaintWindow, parLeft, parTop);
    //Is not necessary to check the result of GetLCLClientBoundsOffset since
    //the false condition (lWincontrol = nil or lWincontrol <> TWinControl) is never met
    //The rect is always initialized with 0
    GetLCLClientBoundsOffset(lWinControl, ORect);
    PaintMsg.Msg := LM_PAINT;
    PaintMsg.PaintStruct := @PS;
    if not useDoubleBuffer then
      PaintMsg.DC := DC;
    if not needParentPaint then
    begin
      // send through message to allow message override, moreover use SendMessage
      // to allow subclass window proc override this message too
{$IFDEF DBG_SendPaintMessage}
      DebugLnEnter('> SendPaintMessage call WM_ERASEBKGND for CtrlDC=', dbgs(ControlDC), ' Window=', dbgs(Window), ' WinCtrl=',dbgs(PtrUInt(lWinControl)), ' ', DbgSName(lWinControl));
{$ENDIF}
      Include(TWinControlAccess(lWinControl).FWinControlFlags, wcfEraseBackground);
      Windows.SendMessage(lWinControl.Handle, WM_ERASEBKGND, Windows.WPARAM(PaintMsg.DC), 0);
      Exclude(TWinControlAccess(lWinControl).FWinControlFlags, wcfEraseBackground);
{$IFDEF DBG_SendPaintMessage}
      DebugLnExit('< SendPaintMessage back from WM_ERASEBKGND for CtrlDC=', dbgs(ControlDC), ' Window=', dbgs(Window), ' WinCtrl=',dbgs(PtrUInt(lWinControl)), ' ', DbgSName(lWinControl));
{$ENDIF}
    end;
    if ParentPaintWindow <> 0 then
    begin
{$ifdef MSG_DEBUG}
      DebugLn(MessageStackDepth, ' *painting background by sending paint message to parent window ',
        IntToHex(ParentPaintWindow, 8));
{$endif}
      // tabpage parent and got a dc to draw in, divert paint to parent
      DCIndex := Windows.SaveDC(PaintMsg.DC);
      DrawParentBackground(Window, PaintMsg.DC);
      Windows.RestoreDC(PaintMsg.DC, DCIndex);
    end;
    if (ControlDC = 0) or not needParentPaint then
    begin
      DCIndex := Windows.SaveDC(PaintMsg.DC);
      MoveWindowOrgEx(PaintMsg.DC, ORect.Left, ORect.Top);
{$ifdef DEBUG_DOUBLEBUFFER}
      Windows.GetClipBox(PaintMsg.DC, ClipBox);
      DebugLn('LCL Drawing in DC ', IntToHex(PaintMsg.DC, 8), ' with clipping rect (',
        IntToStr(ClipBox.Left), ',', IntToStr(ClipBox.Top), ';',
        IntToStr(ClipBox.Right), ',', IntToStr(ClipBox.Bottom), ')');
{$endif}
{$IFDEF DBG_SendPaintMessage}
      DebugLnEnter('> SendPaintMessage call DeliverMessage for CtrlDC=', dbgs(ControlDC), ' Window=', dbgs(Window), ' WinCtrl=',dbgs(PtrUInt(lWinControl)), ' ', DbgSName(lWinControl));
{$ENDIF}
      DeliverMessage(lWinControl, PaintMsg);
{$IFDEF DBG_SendPaintMessage}
      DebugLnExit('< SendPaintMessage back from DeliverMessage Ufor CtrlDC=', dbgs(ControlDC), ' Window=', dbgs(Window), ' WinCtrl=',dbgs(PtrUInt(lWinControl)), ' ', DbgSName(lWinControl));
{$ENDIF}
      Windows.RestoreDC(PaintMsg.DC, DCIndex);
    end;
    if useDoubleBuffer then
      Windows.BitBlt(DC, 0, 0, WindowWidth, WindowHeight, CurDoubleBuffer.DC, 0, 0, SRCCOPY);
    if ControlDC = 0 then
      Windows.EndPaint(Window, @PS);
  finally
    if useDoubleBuffer then
    begin
      SelectObject(CurDoubleBuffer.DC, DoubleBufferBitmapOld);
      DeleteDC(CurDoubleBuffer.DC);
      CurDoubleBuffer.DC := 0;
      if BufferWasSaved then
      begin
        if CurDoubleBuffer.Bitmap <> 0 then
          DeleteObject(CurDoubleBuffer.Bitmap);
        CurDoubleBuffer := BackupBuffer;
      end;
{$ifdef DEBUG_DOUBLEBUFFER}
      if CopyBitmapToClipboard then
      begin
//        Windows.OpenClipboard(0);
//        Windows.EmptyClipboard;
//        Windows.SetClipboardData(CF_BITMAP, DoubleBufferBitmap);
//        Windows.CloseClipboard;
        CopyBitmapToClipboard := false;
      end;
{$endif}
    end;
  end;
{$IFDEF DBG_SendPaintMessage}
  finally
  DebugLnExit('<<< SendPaintMessage for CtrlDC=', dbgs(ControlDC), ' Window=', dbgs(Window), ' WinCtrl=',dbgs(PtrUInt(lWinControl)), ' ', DbgSName(lWinControl));
  end;
{$ENDIF}
end;

procedure TWindowProcHelper.HandleScrollMessage(LMsg: integer);
var
  ScrollInfo: TScrollInfo;
begin
  with LMScroll do
  begin
    Msg := LMsg;
    ScrollCode := LOWORD(LongInt(WParam));
    SmallPos := 0;
    ScrollBar := HWND(LParam);
    Pos := 0;
  end;

  if not (LOWORD(LongInt(WParam)) in [SB_THUMBTRACK, SB_THUMBPOSITION])
  then begin
    WindowInfo^.TrackValid := False;
    Exit;
  end;

  // Note on thumb tracking
  // When using the scrollwheel, windows sends SB_THUMBTRACK
  // messages, but only when scroll.max < 32K. So in that case
  // Hi(WParam) won't cycle.
  // When ending scrollbar tracking we also get those
  // messages. Now Hi(WParam) is cycling.
  // To get the correct value you need to use GetScrollInfo.
  //
  // Now there is a problem. GetScrollInfo returns always the old
  // position. So in case we get track messages, we'll keep the
  // last trackposition.
  // To get the correct position, we use the most significant
  // part of the last known value (or the value returned by
  // ScrollInfo). The missing least significant part is given
  // by Hi(WParam), since it is cycling, the or of both will give
  // the position
  // This only works if the difference between the last pos and
  // the new pos is < 64K, so it might fail if we don't get track
  // messages
  // MWE.

  ScrollInfo.cbSize := SizeOf(ScrollInfo);
  if LOWORD(LongInt(WParam)) = SB_THUMBTRACK
  then begin
    ScrollInfo.fMask := SIF_TRACKPOS;
    // older windows versions may not support trackpos, so fill it with some default
    if WindowInfo^.TrackValid
    then ScrollInfo.nTrackPos := Integer(WindowInfo^.TrackPos and $FFFF0000) or HIWORD(LongInt(WParam))
    else ScrollInfo.nTrackPos := HIWORD(LongInt(WParam));
  end
  else begin
    ScrollInfo.fMask := SIF_POS;
    ScrollInfo.nPos := HIWORD(LongInt(WParam));
  end;

  if LParam <> 0
  then begin
    // The message is send by a scrollbar
    GetScrollInfo(HWND(LongInt(LParam)), SB_CTL, ScrollInfo);
  end
  else begin
    // The message is send by a window's standard scrollbar
    if LMsg = LM_HSCROLL
    then GetScrollInfo(Window, SB_HORZ, ScrollInfo)
    else GetScrollInfo(Window, SB_VERT, ScrollInfo);
  end;

  if LOWORD(LongInt(WParam)) = SB_THUMBTRACK
  then begin
    LMScroll.Pos := ScrollInfo.nTrackPos;
    WindowInfo^.TrackPos := ScrollInfo.nTrackPos;
    WindowInfo^.TrackValid := True;
  end
  else begin
    if WindowInfo^.TrackValid
    then LMScroll.Pos := LongInt(WindowInfo^.TrackPos and $FFFF0000) or HIWORD(LongInt(WParam))
    else LMScroll.Pos := (ScrollInfo.nPos and $FFFF0000) or HIWORD(LongInt(WParam));
  end;

  if LMScroll.Pos < High(LMScroll.SmallPos)
  then LMScroll.SmallPos := LMScroll.Pos
  else LMScroll.SmallPos := High(LMScroll.SmallPos);

  if (lWinControl is TCustomListbox) and (LMsg = LM_VSCROLL) then
  begin
    // WM_VSCROLL message carries only 16 bits of scroll box position data.
    // This workaround is needed, to scroll higher than a position value of 65536.
    WinProcess := False;
    TCustomListBox(lWinControl).TopIndex := LMScroll.Pos;
  end;
end;

// FlashWindowEx is not (yet) in FPC
type
  FLASHWINFO = record
    cbSize: UINT;
    hwnd: HWND;
    dwFlags: DWORD;
    uCount: UINT;
    dwTimeout: DWORD;
  end;
  PFLASHWINFO = ^FLASHWINFO;

function FlashWindowEx(pfwi:PFLASHWINFO):WINBOOL; stdcall; external 'user32' name 'FlashWindowEx';

procedure TWindowProcHelper.HandleSetCursor;
var
  lControl: TControl;
  BoundsOffset: TRect;
  ACursor: TCursor;
  MouseMessage: Word;
  P: TPoint;
  lWindow: HWND;
  FlashInfo: FLASHWINFO;
begin
  if Assigned(lWinControl) then
  begin
    if not (csDesigning in lWinControl.ComponentState) and (LOWORD(LParam) = HTCLIENT) then
    begin
      ACursor := Screen.RealCursor;
      if ACursor = crDefault then
      begin
        Windows.GetCursorPos(Windows.POINT(P));
        Windows.ScreenToClient(Window, Windows.POINT(P));
        if GetLCLClientBoundsOffset(lWinControl, BoundsOffset) then
        begin
          Dec(P.X, BoundsOffset.Left);
          Dec(P.Y, BoundsOffset.Top);
        end;
        // TGraphicControl controls do not get WM_SETCURSOR messages...
        lControl := lWinControl.ControlAtPos(P, [capfOnlyClientAreas,
          capfAllowWinControls, capfHasScrollOffset, capfRecursive]);
        if lControl = nil then
          lControl := lWinControl;
        ACursor := lControl.Cursor;
      end;
      if ACursor <> crDefault then
      begin
        // DebugLn('Set cursor. Control = ', LControl.Name, ' cur = ',ACursor);
        Windows.SetCursor(Screen.Cursors[ACursor]);
        LMessage.Result := 1;
      end;
    end
    else
    if (LOWORD(LParam) = Word(HTERROR)) then
    begin
      MouseMessage := HIWORD(LParam);
      // a mouse click on a window
      if ((MouseMessage = WM_LBUTTONDOWN) or
          (MouseMessage = WM_RBUTTONDOWN) or
          (MouseMessage = WM_MBUTTONDOWN) or
          (MouseMessage = WM_XBUTTONDOWN))
      and Assigned(Screen)
      then
      begin
        // A mouse click is happen on our application window which is not active
        // we need to active it ourself. This is needed only when click is happen
        // on disabled window (e.g. ShowModal is called and non modal window is clicked)
        // We also flash the modal window and beep (default windows behavior).

        // search for modal window with GetLastActivePopup
        if Application.MainFormOnTaskBar and (Application.MainFormHandle <> 0) then
          lWindow := GetLastActivePopup(Application.MainFormHandle)
        else
          lWindow := GetLastActivePopup(Win32WidgetSet.AppHandle);

        if lWindow <> 0 then // modal window found
        begin
          if lWindow <> GetActiveWindow then
          begin
            // Activate the application in case it is not active without beep+flash
            Win32WidgetSet.AppBringToFront;
            LMessage.Result := 1; // disable native beep+flash, we don't want it
          end else
          begin
            // Simulate default MS Windows beep+flash
            // because MS Windows is able to flash only modal windows if
            // a disabled window from the same parent chain was clicked on.
            // This code flashes the dialog if whatever disabled form was clicked on.
            Beep;
            FillChar(FlashInfo{%H-}, SizeOf(FlashInfo), 0);
            FlashInfo.cbSize := SizeOf(FlashInfo);
            FlashInfo.hwnd := lWindow;
            FlashInfo.dwFlags := 1; // FLASHW_CAPTION
            FlashInfo.uCount := 6;
            FlashInfo.dwTimeout := 70;
            FlashWindowEx(@flashinfo);
            LMessage.Result := 1; // disable native beep+flash, we already beep+flashed
          end;
        end;
      end;
    end;
  end;
  if LMessage.Result = 0 then
    SetLMessageAndParams(LM_SETCURSOR);
  WinProcess := False;
end;

procedure TWindowProcHelper.DoSysCmdKeyMenu;
var
  ParentForm: TCustomForm;
  TargetWindow, prevFocus: HWND;
begin
  ParentForm := GetParentForm(lWinControl);
  if (ParentForm <> nil) and ((ParentForm.Menu = nil) or (csDesigning in ParentForm.ComponentState))
  and (Application <> nil) and (Application.MainForm <> nil)
  and (Application.MainForm <> ParentForm)
  and Application.MainForm.HandleAllocated then
  begin
    TargetWindow := Application.MainFormHandle;
    if IsWindowEnabled(TargetWindow) and IsWindowVisible(TargetWindow) then
    begin
      prevFocus := Windows.GetFocus;
      Windows.SetFocus(targetWindow);
      PLMsg^.Result := Windows.SendMessage(TargetWindow, WM_SYSCOMMAND, WParam, LParam);
      Windows.SetFocus(prevFocus);
      WinProcess := False;
    end;
  end;
end;

procedure TWindowProcHelper.DoSysCmdMinimize;
begin
  if Assigned(lWinControl) and (Application.MainForm = lWinControl)
  and not Application.MainFormOnTaskBar then
    Window := Win32WidgetSet.AppHandle; //redirection

  if (Window = Win32WidgetSet.AppHandle) and not Application.MainFormOnTaskBar then
  begin
    HidePopups(Win32WidgetSet.AppHandle);
    if Assigned(Application.MainForm) then
    begin
      Windows.SetWindowPos(Window, HWND_TOP,
        Application.MainForm.Left, Application.MainForm.Top,
        Application.MainForm.Width, 0, SWP_NOACTIVATE);
      if Application.MainForm.HandleAllocated then
        Windows.ShowWindow(Application.MainFormHandle, SW_HIDE);
    end;
    PLMsg^.Result := Windows.DefWindowProc(Window, WM_SYSCOMMAND, WParam, LParam);
    WinProcess := False;
    Application.IntfAppMinimize;
  end
  else
  if Assigned(lWinControl) and (lWinControl = Application.MainForm) then
  begin
    PLMsg^.Result := Windows.DefWindowProc(Window, WM_SYSCOMMAND, WParam, LParam);
    WinProcess := False;
    Application.IntfAppMinimize;
  end else
  if Assigned(lWinControl) and (fsModal in TCustomForm(lWinControl).FormState) then
  begin
    // issue #26463
    PLMsg^.Result := 1;
    WinProcess := False;
    Win32WidgetSet.AppMinimize;
  end;
end;

procedure TWindowProcHelper.DoSysCmdRestore;
begin
  if (Window = Win32WidgetSet.AppHandle) and not Application.MainFormOnTaskBar then
  begin
    PLMsg^.Result := Windows.DefWindowProc(Window, WM_SYSCOMMAND, WParam, LParam);
    WinProcess := False;
    if Assigned(Application.MainForm) and Application.MainForm.HandleAllocated then
    begin
      if Application.MainForm.HandleObjectShouldBeVisible then
        Windows.ShowWindow(Application.MainFormHandle, SW_SHOWNA);
      RestorePopups;
    end;
    Application.IntfAppRestore;
  end
  else if Assigned(lWinControl) and (lWinControl = Application.MainForm) then
  begin
    Application.IntfAppRestore;
  end else
  if Assigned(lWinControl) and (fsModal in TCustomForm(lWinControl).FormState) then
  begin
    // issue #26463
    PLMsg^.Result := 1;
    Win32WidgetSet.AppRestore;
  end;
end;

procedure TWindowProcHelper.HandleSysCommand;
begin
  // forward keystroke to show window menu, if parent form has no menu
  // if wparam contains SC_KEYMENU, lparam contains key pressed
  // keymenu+space should always bring up system menu
  case (WParam and $FFF0) of
    SC_KEYMENU:
      if (lWinControl <> nil) and (lParam <> VK_SPACE) then
        DoSysCmdKeyMenu;
    SC_MINIMIZE:
      if Assigned(Application) then
        DoSysCmdMinimize;
    SC_RESTORE:
      if Assigned(Application) then
        DoSysCmdRestore;
  end;
end;

function TWindowProcHelper.IsComboEditSelection: boolean;
begin
  Result := WindowInfo^.isComboEdit and (ComboBoxHandleSizeWindow = Windows.GetParent(Window));
end;

procedure TWindowProcHelper.HandleBitBtnCustomDraw(ABitBtn: TCustomBitBtn);
var
  DrawInfo: PNMCustomDraw;
  ARect: TRect;
  ShowFocus: Boolean;
begin
  DrawInfo := PNMCustomDraw(NMHdr);
  case DrawInfo^.dwDrawStage of
    CDDS_PREPAINT, CDDS_POSTPAINT:
    begin
      lmNotify.Result := CDRF_DODEFAULT or CDRF_NOTIFYPOSTPAINT;
      WinProcess := False;
      if ABitBtn.Focused then
      begin
        if WindowsVersion >= wv2000 then
          ShowFocus := (Windows.SendMessage(ABitBtn.Handle, WM_QUERYUISTATE, 0, 0) and UISF_HIDEFOCUS) = 0
        else
          ShowFocus := True;
        if ShowFocus then
        begin
          ARect := DrawInfo^.rc;
          InflateRect(ARect, -3, -3);
          if not IsRectEmpty(ARect) then
            Windows.DrawFocusRect(DrawInfo^.hdc, ARect);
        end;
      end;
    end;
  end;
end;

procedure TWindowProcHelper.HandleDropFiles;
var
  Files: Array of String;
  Drop: HDROP;
  L: LongWord;
  I, C: Integer;
  DropForm: TWinControl;
  WideBuffer: WideString;
begin
  Drop := HDROP(WParam);
  try
    C := DragQueryFile(Drop, $FFFFFFFF, nil, 0); // get dropped files count
    if C <= 0 then Exit;

    SetLength(Files, C);
    for I := 0 to C - 1 do
    begin
      L := DragQueryFileW(Drop, I, nil, 0); // get I. file name length
      SetLength(WideBuffer, L);
      L := DragQueryFileW(Drop, I, @WideBuffer[1], L + 1);
      SetLength(WideBuffer, L);
      Files[I] := UTF16ToUTF8(WideBuffer);
    end;

    if Length(Files) > 0 then
    begin
      DropForm := lWinControl.IntfGetDropFilesTarget;
      if DropForm is TCustomForm then
        TCustomForm(DropForm).IntfDropFiles(Files);
      if Application <> nil then
        Application.IntfDropFiles(Files);
    end;
  finally
    DragFinish(Drop);
  end;
end;

// returns false if the UnicodeChar is not handled
function TWindowProcHelper.HandleUnicodeChar(var AChar: WideChar): boolean;
var
  OldUTF8Char, UTF8Char: TUTF8Char;
  WS: WideString;
begin
  Result := False;
  UTF8Char := UTF16ToUTF8(WideString(AChar));
  OldUTF8Char := UTF8Char;
  if Assigned(lWinControl) then
  begin
    // if somewhere key is changed to '' then don't process this message
    WinProcess := not lWinControl.IntfUTF8KeyPress(UTF8Char, 1, False);
    // if somewhere key is changed then don't perform a regular keypress
    Result := not WinProcess or (UTF8Char <> OldUTF8Char);
    if Result then
    begin
      WS := UTF8ToUTF16(UTF8Char);
      if Length(WS) > 0 then
        AChar := WS[1]
      else
        AChar := #0;
    end;
  end;
end;

procedure TWindowProcHelper.UpdateUIState(CharCode: Word);
// This piece of code is taken from ThemeMgr.pas of Mike Lischke
// Beginning with Windows 2000 the UI in an application may hide focus rectangles and accelerator key indication.
// We have to take care to show them if the user starts navigating using the keyboard.

  function FindParentForm: TCustomForm; inline;
  begin
    if lWinControl <> nil then
      Result := GetParentForm(lWinControl)
    else
    if Application <> nil then
      Result := Application.MainForm
    else
      Result := nil;
  end;

var
  ParentForm: TCustomForm;
begin
  case CharCode of
    VK_LEFT..VK_DOWN, VK_TAB:
      begin
        ParentForm := FindParentForm;
        if ParentForm <> nil then
          SendMessage(ParentForm.Handle, WM_CHANGEUISTATE, MakeLong(UIS_CLEAR, UISF_HIDEFOCUS), 0);
      end;
    VK_MENU:
      begin
        ParentForm := FindParentForm;
        if ParentForm <> nil then
          SendMessage(ParentForm.Handle, WM_CHANGEUISTATE, MakeLong(UIS_CLEAR, UISF_HIDEACCEL), 0);
      end;
  end;
end;

function TWindowProcHelper.DoChildEdit(out WinResult: LResult): Boolean;
var
  Info: TComboboxInfo;
begin
  // combobox child edit weirdness
  // prevent combobox WM_SIZE message to get/set/compare text to list, to select text
  if IsComboEditSelection then
  begin
    case Msg of
      WM_GETTEXTLENGTH, EM_SETSEL:
      begin
        WinResult := 0;
        Exit(True);
      end;
      WM_GETTEXT:
      begin
        if WParam > 0 then
          PChar(LParam)^ := #0;
        WinResult := 0;
        Exit(True);
      end;
    end;
  end;
  lWinControl := WindowInfo^.AWinControl;
  {for ComboBox IME sends WM_IME_NOTIFY with WParam=WM_IME_ENDCOMPOSITION}
  if (Msg = WM_IME_NOTIFY) and (WPARAM=WM_IME_ENDCOMPOSITION) then
    WindowInfo^.IMEComposed:=True;

  // filter messages we want to pass on to LCL
  if (Msg <> WM_KILLFOCUS) and (Msg <> WM_SETFOCUS)
    {$ifndef RedirectDestroyMessages}and (Msg <> WM_NCDESTROY){$endif}
    and not ((Msg >= WM_CUT) and (Msg <= WM_CLEAR))
    and ((Msg < WM_KEYFIRST) or (Msg > WM_KEYLAST))
    and ((Msg < WM_MOUSEFIRST) or (Msg > WM_MOUSELAST))
    and (Msg <> WM_CONTEXTMENU) then
  begin
    WinResult := CallDefaultWindowProc(Window, Msg, WParam, LParam);
    Exit(True);
  end
  else
  if (Msg = WM_KILLFOCUS) or (Msg = WM_SETFOCUS) then
  begin
    // if focus jumps inside combo then no need to notify LCL
    Info.cbSize := SizeOf(Info);
    Win32Extra.GetComboBoxInfo(lWinControl.Handle, @Info);
    if (HWND(WParam) = Info.hwndList) or
       (HWND(WParam) = Info.hwndItem) or
       (HWND(WParam) = Info.hwndCombo) then
    begin
      WinResult := CallDefaultWindowProc(Window, Msg, WParam, LParam);
      Exit(True);
    end;
  end;
  Result := False;
end;

procedure TWindowProcHelper.DoMsgChar(var WinResult: LResult);
begin
  OrgCharCode := Word(WParam);
  // Process surrogate pairs later
  {$IF FPC_FULLVERSION>=30000}
  if TCharacter.IsSurrogate(WideChar(OrgCharCode)) then
  {$ELSE}
  if False then
  {$ENDIF}
    WinProcess := True
  // first send a IntfUTF8KeyPress to the LCL
  // if the key was not handled send a CN_CHAR for AnsiChar<=#127
  else if not HandleUnicodeChar(WideChar(OrgCharCode)) then
  begin
    PLMsg := @LMChar;
    with LMChar do
    begin
      Msg := CN_CHAR;
      KeyData := LParam;
      CharCode := Word(Char(WideChar(WParam)));
      OrgCharCode := CharCode;
      WinResult := 0;
    end;
    WinProcess := false;
  end
  else
    WParam := OrgCharCode;
end;

procedure TWindowProcHelper.DoCmdCheckBoxParam;
var
  Flags: dword;
begin
  case HIWORD(WParam) of
    BN_CLICKED:
      begin
        // to allow cbGrayed state at the same time as not AllowGrayed
        // in checkboxes (needed by dbcheckbox for null fields) we need
        // to handle checkbox state ourselves, according to msdn state
        // sequence goes from checked->cleared->grayed etc.
        Flags := SendMessage(lWinControl.Handle, BM_GETCHECK, 0, 0);
        //do not update the check state if is TRadioButton and is already checked
        if (Flags <> BST_CHECKED) or not (lWinControl is TRadioButton) then
        begin
          if (Flags=BST_CHECKED) then
            Flags := BST_UNCHECKED
          else
          if (Flags=BST_UNCHECKED) and
             TCustomCheckbox(lWinControl).AllowGrayed then
            Flags := BST_INDETERMINATE
          else
            Flags := BST_CHECKED;
          //pass 0 through LParam to force sending LM_CHANGE
          Windows.SendMessage(lWinControl.Handle, BM_SETCHECK, Windows.WPARAM(Flags), 0);
        end;
        LMessage.Msg := LM_CLICKED;
      end;
    BN_KILLFOCUS:
      LMessage.Msg := LM_EXIT;
  end
end;

function TWindowProcHelper.DoCmdComboBoxParam: Boolean;
begin
  case HIWORD(WParam) of
    CBN_DROPDOWN: TCustomCombobox(lWinControl).IntfGetItems;
    CBN_EDITCHANGE: LMessage.Msg := LM_CHANGED;
    { CBN_EDITCHANGE is only sent after the user changes the edit box.
      CBN_SELCHANGE is sent when the user changes the text by
      selecting in the list, but before text is actually changed.
      itemindex is updated, so set text manually }
    CBN_SELCHANGE:
    begin
      if TCustomComboBox(lWinControl).Style.HasEditBox then
        UpdateComboBoxText(TCustomComboBox(lWinControl));
      SendSimpleMessage(lWinControl, LM_CHANGED);
      LMessage.Msg := LM_SELCHANGE;
    end;
    CBN_CLOSEUP:
    begin
      // according to msdn CBN_CLOSEUP can happen before CBN_SELCHANGE and
      // unfortunately it is simple truth. but we need correct order in the LCL
      PostMessage(lWinControl.Handle, CN_COMMAND, WParam, LParam);
      Exit(True);
    end;
  end;
  Result := False;
end;

procedure TWindowProcHelper.DoMsgColor(ChildWindowInfo: PWin32WindowInfo);
var
  WindowDC: HDC;
  WindowColor: TColor;
  ChildWinControl: TWinControl;
  EditFont: TFont;
begin
  WindowDC := HDC(WParam);
  ChildWinControl := ChildWindowInfo^.WinControl;
  if ChildWinControl = nil then
    ChildWinControl := ChildWindowInfo^.AWinControl;

  case Msg of
    WM_CTLCOLORSTATIC,
    WM_CTLCOLORBTN: begin
      if GetNeedParentPaint(ChildWindowInfo, ChildWinControl) and
        not ChildWindowInfo^.ThemedCustomDraw then
      begin
        // need to draw transparently, draw background
        DrawParentBackground(HWND(LParam), WindowDC);
        LMessage.Result := GetStockObject(HOLLOW_BRUSH);
        SetBkMode(WindowDC, TRANSPARENT);
        WinProcess := false;
      end;
    end;
    WM_CTLCOLORSCROLLBAR: begin
      WinProcess := false;
    end;
  end;

  if WinProcess then
  begin
    if ChildWinControl <> nil then
    begin
      if (ChildWinControl is TCustomEdit)
      and (TCustomEdit(ChildWinControl).EmulatedTextHintStatus = thsShowing) then
      begin
        EditFont := CreateEmulatedTextHintFont(ChildWinControl);
        try
          WindowColor := EditFont.Color;
        finally
          EditFont.Free;
        end;
      end else
        WindowColor := ChildWinControl.Font.Color;
      if WindowColor = clDefault then
        WindowColor := ChildWinControl.GetDefaultColor(dctFont);
      Windows.SetTextColor(WindowDC, ColorToRGB(WindowColor));
      WindowColor := ChildWinControl.Brush.Color;
      if WindowColor = clDefault then
        WindowColor := ChildWinControl.GetDefaultColor(dctBrush);
      Windows.SetBkColor(WindowDC, ColorToRGB(WindowColor));
      LMessage.Result := LResult(ChildWinControl.Brush.Reference.Handle);
      // Override default handling
      WinProcess := false;
    end;
  end;
end;

procedure TWindowProcHelper.UpdateDrawListItem(aMsg: UInt);
var
  PDrawIS: PDrawItemStruct;
begin
  PDrawIS := PDrawItemStruct(LParam);
  if PDrawIS^.itemID <> dword(-1) then
  begin
    LMessage.Msg := aMsg;
    TLMDrawListItem(LMessage).DrawListItemStruct := @DrawListItemStruct;
    with DrawListItemStruct do
    begin
      ItemID := PDrawIS^.itemID;
      Area := PDrawIS^.rcItem;
      ItemState := TOwnerDrawState(PDrawIS^.itemState);
      DC := PDrawIS^._hDC;
    end;
    if (aMsg = LM_DRAWLISTITEM) and (WindowInfo <> @DefaultWindowInfo) then
    begin
      WindowInfo^.DrawItemIndex := PDrawIS^.itemID;
      WindowInfo^.DrawItemSelected := (PDrawIS^.itemState and ODS_SELECTED) = ODS_SELECTED;
    end;
    WinProcess := false;
  end;
end;

procedure TWindowProcHelper.UpdateDrawItems;
begin
  with TLMDrawItems(LMessage) do
  begin
    Msg := LM_DRAWITEM;
    Ctl := 0;
    DrawItemStruct := PDrawItemStruct(LParam);
  end;
  WinProcess := false;
end;

procedure TWindowProcHelper.DoMsgDrawItem;
var
  menuItem: TObject;
  PDrawIS: PDrawItemStruct;
  isDrawListItem: Boolean;
  DrawItemMsg: Integer;
begin
  PDrawIS := PDrawItemStruct(LParam);
  if (WParam = 0) and (PDrawIS^.ctlType = ODT_MENU) then
  begin
    menuItem := TObject(PDrawIS^.itemData);
    if menuItem is TMenuItem then
      DrawMenuItem(TMenuItem(menuItem),
        PDrawIS^._hDC, PDrawIS^.rcItem, PDrawIS^.itemAction, PDrawIS^.itemState);
    UpdateDrawItems;
  end
  else
  begin
    WindowInfo := GetWin32WindowInfo(PDrawIS^.hwndItem);
    if WindowInfo^.WinControl<>nil then
      lWinControl := WindowInfo^.WinControl;
    {$IFDEF MSG_DEBUG}
    debugln(format('Received WM_DRAWITEM type %d handle %x',
                   [PDrawIS^.ctlType, integer(PDrawIS^.hwndItem)]));
    {$ENDIF}

    if (lWinControl<>nil) and
       (((lWinControl is TCustomListbox) and
          (TCustomListBox(lWinControl).Style <> lbStandard)) or
       ((lWinControl is TCustomCombobox) and
           TCustomCombobox(lWinControl).Style.IsOwnerDrawn))
    then
      UpdateDrawListItem(LM_DRAWLISTITEM)
    else if Assigned(WindowInfo^.DrawItemHandler) then begin
      DrawItemMsg := 0;
      isDrawListItem := False;
      WindowInfo^.DrawItemHandler(lWinControl, Window, Msg, WParam, PDrawIS^,
        DrawItemMsg, isDrawListItem);
      if isDrawListItem and (DrawItemMsg<>0) then
        UpdateDrawListItem(DrawItemMsg)
      else
        UpdateDrawItems;
    end else
      UpdateDrawItems;
  end;
end;

procedure TWindowProcHelper.DoMsgEnable;
begin
  LMessage.Msg := LM_ENABLE;
  if Window = Win32WidgetSet.AppHandle then
    if WParam = 0 then
    begin
      RemoveStayOnTopFlags(Window);
      DisabledForms := Screen.DisableForms(nil, DisabledForms);
    end
    else begin
      RestoreStayOnTopFlags(Window);
      Screen.EnableForms(DisabledForms);
    end;

  // When themes are not enabled, it is necessary to redraw the BitMap associated
  // with the TCustomBitBtn so Windows will reflect the new UI appearence.
  if not ThemeServices.ThemesEnabled and (lWinControl is TCustomBitBtn) then
    DrawBitBtnImage(TCustomBitBtn(lWinControl), TCustomBitBtn(lWinControl).Caption);
end;

function TWindowProcHelper.DoMsgEraseBkgnd(var WinResult: LResult): Boolean;
var
  eraseBkgndCommand: TEraseBkgndCommand;
begin
  eraseBkgndCommand := TEraseBkgndCommand(EraseBkgndStack and EraseBkgndStackMask);
{$if defined(MSG_DEBUG) or defined(DBG_SendPaintMessage)}
  DebugLnEnter(['>>> Do WM_ERASEBKGND for WParam= ', WParam, ' LParam=',LParam,
      ' CurDbleBuffer.DC=', dbgs(CurDoubleBuffer.DC), ' Window=', dbgs(Window),
      ' WinCtrl=',PtrUInt(lWinControl), ' ', DbgSName(lWinControl),
      ' isTab=', dbgs(WindowInfo^.isTabPage)  ]);
  try
  case eraseBkgndCommand of
    ecDefault: DebugLn(MessageStackDepth, ' *command: default');
    ecDiscardNoRemove, ecDiscard: DebugLn(MessageStackDepth, ' *command: completely ignore');
    ecDoubleBufferNoRemove: DebugLn(MessageStackDepth, ' *command: use double buffer');
  end;
  DebugLn(MessageStackDepth, ' *erasebkgndstack: ', EraseBkgndStackToString);
{$endif}
  if eraseBkgndCommand = ecDoubleBufferNoRemove then
  begin
    if CurDoubleBuffer.DC <> 0 then
      WParam := Windows.WParam(CurDoubleBuffer.DC);
    if WindowInfo^.isTabPage then
      EraseBkgndStack := (EraseBkgndStack and not ((1 shl EraseBkgndStackShift)-1))
        or dword(ecDiscardNoRemove);
  end
  else
  if eraseBkgndCommand <> ecDiscardNoRemove then
    EraseBkgndStack := EraseBkgndStack shr EraseBkgndStackShift;
  if eraseBkgndCommand in [ecDiscard, ecDiscardNoRemove] then
  begin
    WinResult := 0;
    Exit(True);
  end;
  if not GetNeedParentPaint(WindowInfo, lWinControl) or (eraseBkgndCommand = ecDoubleBufferNoRemove) then
  begin
{$if defined(MSG_DEBUG) or defined(DBG_SendPaintMessage)}
    DebugLn(['WM_ERASEBKGND  *NO* ParentPaint for WParam= ', WParam, ' LParam=',LParam, ' Window=', dbgs(Window) ]);
{$endif}
    SetLMessageAndParams(LM_ERASEBKGND);
  end else
  begin
{$if defined(MSG_DEBUG) or defined(DBG_SendPaintMessage)}
    DebugLn(['WM_ERASEBKGND got NeedParentPaint for WParam= ', WParam, ' LParam=',LParam, ' Window=', dbgs(Window) ]);
{$endif}
    if not ThemeServices.ThemesEnabled then
      SendPaintMessage(HDC(WParam));
    LMessage.Result := 1;
  end;
  WinProcess := False;
{$if defined(MSG_DEBUG) or defined(DBG_SendPaintMessage)}
  finally
  DebugLnExit(['<<< Do WM_ERASEBKGND for WParam= ', WParam, ' LParam=',LParam,
      ' Window=', dbgs(Window), ' MsgStackDepth=', MessageStackDepth, ' *erasebkgndstack: ', EraseBkgndStackToString
       ]);
  end;
{$endif}
  Result := False;
end;

procedure TWindowProcHelper.DoMsgKeyDownUp(aMsg: Cardinal; var WinResult: LResult);
begin
  NotifyUserInput := True;
  PLMsg := @LMKey;
  UpdateUIState(Word(WParam));
  SetLMKeyData(aMsg, True);
  WinResult := 0;
  WinProcess := false;
end;

procedure TWindowProcHelper.DoMsgMouseDownUpClick(aButton: Byte;
  aIsDblClick: Boolean; aMouseDown: Boolean);
var
  MousePos: TPoint;
begin
  GetCursorPos(MousePos{%H-});

  NotifyUserInput := True;
  PLMsg := @LMMouse;
  LMMouse.Msg := CheckMouseButtonDownUp(Window, lWinControl, LastMouse, MousePos, aButton, aMouseDown);

  LMMouse.XPos := GET_X_LPARAM(LParam);
  LMMouse.YPos := GET_Y_LPARAM(LParam);
  LMMouse.Keys := WParam;
  if (lWinControl is TCustomListView) then // workaround #30234
    case Msg of
      WM_LBUTTONUP, WM_RBUTTONUP, WM_MBUTTONUP, WM_XBUTTONUP:
        LMMouse.Keys := LMMouse.Keys or ShiftStateToKeys(KeyboardStateToShiftState);
    end;
  case LastMouse.ClickCount of
    2: LMMouse.Keys := LMMouse.Keys or MK_DOUBLECLICK;
    3: LMMouse.Keys := LMMouse.Keys or MK_TRIPLECLICK;
    4: LMMouse.Keys := LMMouse.Keys or MK_QUADCLICK;
  end;
end;

procedure TWindowProcHelper.DoMsgContextMenu;
begin
  WinProcess := False;
  NotifyUserInput := True;
  PLMsg := @LMContextMenu;
  with LMContextMenu do
  begin
    Msg := LM_CONTEXTMENU;
    XPos := GET_X_LPARAM(LParam);
    YPos := GET_Y_LPARAM(LParam);
    hWnd := Window;
  end;
end;

procedure TWindowProcHelper.DoMsgMouseMove;
begin
  NotifyUserInput := True;
  PLMsg := @LMMouseMove;
  with LMMouseMove Do
  begin
    Msg := LM_MOUSEMOVE;
    XPos := GET_X_LPARAM(LParam);
    YPos := GET_Y_LPARAM(LParam);
    Keys := WParam;
    // check if this is a spurious WM_MOUSEMOVE message, pos not actually changed
    if (XPos = WindowInfo^.MouseX) and (YPos = WindowInfo^.MouseY) then
    begin
      // do not fire message after all (position not changed)
      Msg := LM_NULL;
      NotifyUserInput := false;
    end else
    if WindowInfo <> @DefaultWindowInfo then
    begin
      // position changed, update window info
      WindowInfo^.MouseX := XPos;
      WindowInfo^.MouseY := YPos;
    end;
  end;
end;

function TWindowProcHelper.DoMsgMouseWheel(var WinResult: LResult; AHorz: Boolean): Boolean;
var
  NCode: integer;
  TargetWindow: HWND;
  P: TPoint;
begin
  if AHorz then
    NCode := WM_MOUSEHWHEEL
  else
    NCode := WM_MOUSEWHEEL;
  NotifyUserInput := True;
  PLMsg := @LMMouseEvent;
  with LMMouseEvent Do
  begin
    X := GET_X_LPARAM(LParam);
    Y := GET_Y_LPARAM(LParam);
    // check if mouse cursor within this window, otherwise send message to
    // window the mouse is hovering over
    P.X := X;
    P.Y := Y;
    TargetWindow := Win32WidgetSet.WindowFromPoint(P);
    //fallback to LCL function to get the actual window
    if TargetWindow = 0 then
      TargetWindow := GetLCLWindowFromPoint(lWinControl, P);
    if (TargetWindow = 0) or not IsWindowEnabled(TargetWindow) then
      Exit(True);

    // check if the window is an edit control of a combobox, if so,
    // redirect it to the combobox, not the edit control
    if GetWin32WindowInfo(TargetWindow)^.isComboEdit then
      TargetWindow := Windows.GetParent(TargetWindow);

    // check InMouseWheelRedirection to prevent recursion
    if not InMouseWheelRedirection and (TargetWindow <> Window) then
    begin
      InMouseWheelRedirection := true;
      WinResult := SendMessage(TargetWindow, NCode, WParam, LParam);
      InMouseWheelRedirection := false;
      Exit(True);
    end
    else if TargetWindow <> Window then
      Exit(True);
    // the mousewheel message is for us
    Msg := NCode;
    // important: LM_MOUSEWHEEL needs client coordinates (windows WM_MOUSEWHEEL are screen coordinates)
    Windows.ScreenToClient(TargetWindow, P);
    X := P.X;
    Y := P.Y;
    Button := LOWORD(Integer(WParam));
    WheelDelta := SmallInt(HIWORD(Integer(WParam)));
    State := KeysToShiftState(Button);
    WinResult := 0;
    UserData := Pointer(GetWindowLong(Window, GWL_USERDATA));
    WinProcess := false;
  end;
  Result := False;
end;

procedure TWindowProcHelper.DoMsgNCLButtonDown;
begin
  SetLMessageAndParams(Msg);
  NotifyUserInput := True;

  //Drag&Dock support TCustomForm => Start BeginDrag()
  if (lWinControl <> nil) and not (csDesigning in lWinControl.ComponentState) then
  begin
    if WParam = HTCAPTION  then
      if lWinControl is TCustomForm then
        if (TWinControlAccess(lWinControl).DragKind = dkDock)
        and (TWinControlAccess(lWinControl).DragMode = dmAutomatic) then
          lWinControl.BeginDrag(true);
  end;
  // I see no other way to prevent crash at moment. This message calls WM_CLOSE
  // which frees our form and we get a destructed lWinControl
  lWinControl := nil;
end;

function TWindowProcHelper.DoMsgNotify(var WinResult: LResult): Boolean;
begin
  WindowInfo := GetWin32WindowInfo(PNMHdr(LParam)^.hwndFrom);
{$ifdef MSG_DEBUG}
  DebugLn([MessageStackDepth, 'Notify code: ', PNMHdr(LParam)^.code]);
{$endif}
  if Assigned(WindowInfo^.ParentMsgHandler) then
  begin
    LMNotify.Result := 0;
    if WindowInfo^.ParentMsgHandler(WindowInfo^.WinControl,
      Window, WM_NOTIFY, WParam, LParam, LMNotify.Result, WinProcess) then
    begin
      WinResult := LMNotify.Result;
      Exit(True);
    end;
  end;
  case PNMHdr(LParam)^.code of
    MCN_SELCHANGE:
    begin
      LMessage.Msg := LM_CHANGED;
      if WindowInfo^.WinControl <> nil then
        lWinControl := WindowInfo^.WinControl;
    end;
  else
    PLMsg:=@LMNotify;
    LMNotify.Msg := LM_NOTIFY;
    LMNotify.IDCtrl := WParam;
    LMNotify.NMHdr := PNMHDR(LParam);
    case LMNotify.NMHdr^.code of
      NM_CUSTOMDRAW:
      begin
        if WindowInfo^.WinControl is TCustomBitBtn then
          HandleBitBtnCustomDraw(TCustomBitBtn(WindowInfo^.WinControl))
        else
        if GetNeedParentPaint(WindowInfo, lWinControl) and WindowInfo^.ThemedCustomDraw then
        begin
          case PNMCustomDraw(LParam)^.dwDrawStage of
            CDDS_PREPAINT:
            begin
              WinResult := CDRF_NOTIFYITEMDRAW;
              WinProcess := false;
            end;
            CDDS_ITEMPREPAINT:
            begin
              WinResult := CDRF_DODEFAULT;
              WinProcess := false;
            end;
          end;
        end;
      end;
    end;
  end;
  Result := False;
end;

procedure TWindowProcHelper.DoMsgShowWindow;
var
  Flags: dword;
begin
  with TLMShowWindow(LMessage) Do
  begin
    Msg := LM_SHOWWINDOW;
    Show := WParam <> 0;
    Status := LParam;
  end;
  if Assigned(lWinControl) and ((WParam <> 0) or not lWinControl.Visible) and
      ((WParam = 0) or lWinControl.Visible) and Assigned(Application) and
      (lWinControl = Application.MainForm) and not Application.MainFormOnTaskBar then
  begin
    if WParam=0 then
      Flags := SW_HIDE
    else
      Flags := SW_SHOWNOACTIVATE;
    Windows.ShowWindow(Win32WidgetSet.AppHandle, Flags);
  end
  else
  if Assigned(lWinControl) and (WParam <> 0) and not lWinControl.Visible then
    WinProcess := false;
end;

procedure TWindowProcHelper.DoMsgSysKey(aMsg: Cardinal);
begin
  NotifyUserInput := True;
  PLMsg := @LMKey;
  SetLMKeyData(aMsg, True);
  WinProcess := false;
end;

procedure TWindowProcHelper.DoMsgMeasureItem;
var
  menuItem: TObject;
  menuHDC: HDC;
  TmpSize: TSize; // used by WM_MEASUREITEM
begin
  case PMeasureItemStruct(LParam)^.CtlType of
    ODT_MENU:
      begin
        menuItem := TObject(PMeasureItemStruct(LParam)^.itemData);
        if menuItem is TMenuItem then
        begin
          menuHDC := GetDC(Window);
          TmpSize := MenuItemSize(TMenuItem(menuItem), menuHDC);
          PMeasureItemStruct(LParam)^.itemWidth := TmpSize.cx;
          PMeasureItemStruct(LParam)^.itemHeight := TmpSize.cy;
          ReleaseDC(Window, menuHDC);
          Winprocess := False;
        end
        {$ifdef MSG_DEBUG}
        else
          DebugLn('WM_MEASUREITEM for a menuitem catched but menuitem is not TmenuItem');
        {$endif}
      end;
    else
    if WParam <> 0 then
    begin
      lWinControl := TWinControl(WParam);
      //if Assigned(lWinControl) then   <- already tested
      SetLMessageAndParams(LM_MEASUREITEM, True);
    end;
  end;
end;

procedure TWindowProcHelper.DoMsgActivateApp;
begin
  if Window = Win32WidgetSet.AppHandle then
  begin
    if WParam <> 0 then // activated
    begin
      //WriteLn('Restore');
      RestoreStayOnTopFlags(Window);
      if Assigned(Application) then
        Application.IntfAppActivate(True);
    end
    else begin // deactivated
      //WriteLn('Remove');
      RemoveStayOnTopFlags(Window);
      if Assigned(Application) then
        Application.IntfAppDeactivate(True);
    end;
  end;
end;

procedure TWindowProcHelper.UpdateLMMovePos(X, Y: Smallint);
begin
  LMMove.XPos := X;
  LMMove.YPos := Y;
end;

function TWindowProcHelper.DoMsgMove: Boolean;
var
  NewLeft, NewTop: integer;
  WindowPlacement: TWINDOWPLACEMENT;
  R: TRect;
begin
  PLMsg := @LMMove;
  LMMove.Msg := LM_MOVE;
  // MoveType := WParam;   WParam is not defined!
  LMMove.MoveType := Move_SourceIsInterface;
  if GetWindowLong(Window, GWL_STYLE) and WS_CHILD = 0 then
  begin
    WindowPlacement.length := SizeOf(WindowPlacement);
    if IsIconic(Window) and GetWindowPlacement(Window, @WindowPlacement) then
      UpdateLMMovePos(WindowPlacement.rcNormalPosition.Left,
                      WindowPlacement.rcNormalPosition.Top)
    else if Windows.GetWindowRect(Window, @R) then
      UpdateLMMovePos(R.Left, R.Top)
    else
      LMMove.Msg := LM_NULL;
  end else
  begin
    if GetWindowRelativePosition(Window, NewLeft, NewTop) then
      UpdateLMMovePos(NewLeft, NewTop)
    else
      LMMove.Msg := LM_NULL;
  end;
  if lWinControl <> nil then
  begin
    {$IFDEF VerboseSizeMsg}
  with LMMove Do begin
      DebugLn('Win32CallBack WM_MOVE ', dbgsName(lWinControl),
        ' NewPos=',dbgs(XPos),',',dbgs(YPos));
  end;
      {$ENDIF}
    if (lWinControl.Left = LMMove.XPos) and (lWinControl.Top = LMMove.YPos) then
      Exit(True);
  end;
  Result := False;
end;

procedure TWindowProcHelper.DoMsgSize;
var
  NewWidth, NewHeight: integer;
  OverlayWindow: HWND;
{$IFDEF VerboseSizeMsg}
  R: TRect;
{$ENDIF}
begin
  with TLMSize(LMessage) do
  begin
    Msg := LM_SIZE;
    SizeType := WParam or Size_SourceIsInterface;

    // this is needed since we don't minimize the main form window
    // we only hide and show it back on mimize and restore in case MainFormOnTaskbar = False
    if (Window = Win32WidgetSet.AppHandle) and
       Assigned(Application.MainForm) and Application.MainForm.HandleAllocated then
    begin
      lWinControl := Application.MainForm;
      Window := Application.MainFormHandle;
      // lie LCL about the window state
      if IsIconic(Win32WidgetSet.AppHandle) then
        SizeType := SIZE_MINIMIZED or Size_SourceIsInterface
      else
      if IsZoomed(Window) then
        SizeType := SIZE_MAXIMIZED or Size_SourceIsInterface
      else
        SizeType := SIZE_RESTORED or Size_SourceIsInterface;
    end;

    GetWindowSize(Window, NewWidth, NewHeight);
    Width := NewWidth;
    Height := NewHeight;
    if Assigned(lWinControl) then
    begin
      {$IFDEF VerboseSizeMsg}
      GetClientRect(Window,R);
      DebugLn('Win32Callback: WM_SIZE '+ dbgsName(lWinControl)+
        ' NewSize=', dbgs(Width)+','+dbgs(Height)+
        ' HasVScroll='+dbgs((GetWindowLong(Window, GWL_STYLE) and WS_VSCROLL) <> 0)+
        ' HasHScroll='+dbgs((GetWindowLong(Window, GWL_STYLE) and WS_HSCROLL) <> 0)+
        ' OldClientSize='+dbgs(lWinControl.CachedClientWidth)+','+dbgs(lWinControl.CachedClientHeight)+
        ' NewClientSize='+dbgs(R.Right)+','+dbgs(R.Bottom));
      {$ENDIF}
      lWinControl.InvalidateClientRectCache(false);
    end;
    OverlayWindow := GetWin32WindowInfo(Window)^.Overlay;
    if OverlayWindow <> 0 then
      Windows.SetWindowPos(OverlayWindow, HWND_TOP, 0, 0, NewWidth, NewHeight, SWP_NOMOVE);
  end;
end;

{ TWindProcNotificationReceiver }

procedure TWindProcNotificationReceiver.ReceiveDestroyNotify(Sender: TObject);
begin
  assert(PWindowProcHelper(Self)^.FlWinControl = Sender, 'TWindProcNotificationReceiver.ReceiveDestroyNotify: PWindowProcHelper(Self)^.FlWinControl = Sender');
  PWindowProcHelper(Self)^.lWinControl := nil;
end;

// This is called from the actual WindowProc.

function TWindowProcHelper.DoWindowProc: LResult;
var
  ChildWindowInfo: PWin32WindowInfo;
  TargetObject: TObject;
  TargetWindow: HWND;
  WmSysCommandProcess: Boolean;
  CancelEndSession : Boolean; // used by WM_QUERYENDSESSION
  // used by WM_CHAR, WM_SYSCHAR and WM_KEYDOWN, WM_KEYUP, WM_SYSKEYDOWN, WM_SYSKEYUP
  CharCodeNotEmpty: boolean;
  R: TRect;
  ACtl: TWinControl;
  LMouseEvent: TTRACKMOUSEEVENT;
  MaximizedActiveChild: WINBOOL;
{$IF NOT DECLARED(WM_DPICHANGED)} // WM_DPICHANGED was added in FPC 3.1.1
const
  WM_DPICHANGED = $02E0;
{$ENDIF}
begin
  try
  FillChar(LMessage, SizeOf(LMessage), 0);
  PLMsg := @LMessage;
  WinProcess := True;
  NotifyUserInput := False;

  WindowInfo := GetWin32WindowInfo(Window);
  if WindowInfo^.isChildEdit then
  begin
    if DoChildEdit(Result) then Exit;
  end else begin
    lWinControl := WindowInfo^.WinControl;
  end;

  if (IgnoreNextCharWindow <> 0) and ((Msg = WM_CHAR) or (Msg = WM_SYSCHAR)) then
  begin
    if IgnoreNextCharWindow = Window then
    begin
      IgnoreNextCharWindow := 0;
      Result := 1;
      Exit;
    end;
    IgnoreNextCharWindow := 0;
  end;
  if IgnoreKeyUp and (Msg = WM_KEYUP) then
    Exit(1);

  case Msg of
    WM_MOUSEFIRST..WM_MOUSELAST:
    if (LastMouseTracking<>lWinControl) then
    begin
      // register for WM_MOUSELEAVE
      FillChar(LMouseEvent, SizeOf(TTRACKMOUSEEVENT), 0);
      LMouseEvent.cbSize := SizeOf(TTRACKMOUSEEVENT);
      LMouseEvent.dwFlags := TME_LEAVE;
      LMouseEvent.hwndTrack := Window;
      LMouseEvent.dwHoverTime := HOVER_DEFAULT;
      _TrackMouseEvent(@LMouseEvent);
      LastMouseTracking := lWinControl;
    end;
  end;

  case Msg of
    WM_NULL:
      if (Window = Win32WidgetSet.AppHandle) then
      begin
        CheckSynchronize;
        TWin32Widgetset(Widgetset).CheckPipeEvents;
      end;
    WM_ENTERIDLE: Application.Idle(False);
    WM_ACTIVATE:  SetLMessageAndParams(LM_ACTIVATE);
    WM_DPICHANGED: SetLMessageAndParams(LM_DPICHANGED);
    WM_IME_ENDCOMPOSITION:
    begin
      {IME Windows the composition has finished}
      WindowInfo^.IMEComposed:=True;
      SetLMessageAndParams(Msg);  //WinProcess := False;
    end;
    WM_CANCELMODE:     LMessage.Msg := LM_CANCELMODE;
    WM_CAPTURECHANGED: LMessage.Msg := LM_CAPTURECHANGED;
    WM_CHAR:           DoMsgChar(Result);

    WM_MENUCHAR:
    begin
      PLMsg^.Result := FindMenuItemAccelerator(LOWORD(WParam), HMENU(LParam));
      WinProcess := false;
    end;

    WM_CLOSE:
    begin
      if (Window = Win32WidgetSet.AppHandle) and Assigned(Application.MainForm) then
        Windows.SendMessage(Application.MainFormHandle, WM_CLOSE, 0, 0)
      else
        LMessage.Msg := LM_CLOSEQUERY;
      // default is to destroy window, inhibit
      WinProcess := false;
    end;
    
    WM_INITMENUPOPUP:
    begin
      if HIWORD(lParam) = 0 then //if not system menu
      begin
        TargetObject := GetPopMenuItemObject;
        // Check if the menu was the maximized icon menu for an MDI child window and ignore it in that case
        if (LoWord(LParam)=0) and (lWinControl=Application.MainForm) and (Application.MainForm.FormStyle=fsMDIForm) then
        begin
          MaximizedActiveChild := False;
          if SendMessage(Win32WidgetSet.MDIClientHandle, WM_MDIGETACTIVE, 0, Windows.WPARAM(@MaximizedActiveChild)) <> 0 then
          begin
            if MaximizedActiveChild then
              TargetObject := nil;
          end;
        end;
        if TargetObject is TMenuItem then
        begin
          LMessage.Msg := LM_ACTIVATE;
          TargetObject.Dispatch(LMessage);
          lWinControl := nil;
        end;
      end;
    end;
    
    WM_MENUSELECT:
    begin
      TargetObject := GetMenuItemObject((HIWORD(Integer(WParam)) and MF_POPUP) <> 0);
      // Check if the menu was the maximized icon menu for an MDI child window and ignore it in that case
      if (LoWord(Integer(WParam))=0) and (lWinControl=Application.MainForm) and (Application.MainForm.FormStyle=fsMDIForm) then
      begin
        MaximizedActiveChild := False;
        if SendMessage(Win32WidgetSet.MDIClientHandle, WM_MDIGETACTIVE, 0, Windows.WPARAM(@MaximizedActiveChild)) <> 0 then
        begin
          if MaximizedActiveChild then
            TargetObject := nil;
        end;
      end;
      if TargetObject is TMenuItem then
        TMenuItem(TargetObject).IntfDoSelect
      else
        Application.Hint := '';
    end;
    
    WM_COMMAND:
    begin
      if LParam = 0 then
      begin
        {menuitem or shortcut}
        TargetObject := GetMenuItemObject(False);
        if TargetObject is TMenuItem then
        begin
          if (HIWORD(WParam) = 0) or (HIWORD(WParam) = 1) then
          begin
            LMessage.Msg := LM_ACTIVATE;
            TargetObject.Dispatch(LMessage);
          end;
          lWinControl := nil;
        end;
      end
      else begin
        ChildWindowInfo := GetWin32WindowInfo(HWND(LParam));
        lWinControl := ChildWindowInfo^.WinControl;
        // buddy controls use 'awincontrol' to designate associated wincontrol
        if lWinControl = nil then
          lWinControl := ChildWindowInfo^.AWinControl;

        if Assigned(ChildWindowInfo^.ParentMsgHandler) then
        begin
          if ChildWindowInfo^.ParentMsgHandler(lWinControl,
            Window, WM_COMMAND, WParam, LParam, LMessage.Result, WinProcess) then Exit(LMessage.Result);
        end;

        // TToggleBox is a TCustomCheckBox too, but we don't want to handle
        // state changes of TToggleBox ourselfves
        if (lWinControl is TCustomCheckBox) and not (lWinControl is TToggleBox) then
          DoCmdCheckBoxParam
        else if lWinControl is TButtonControl then
          case HIWORD(WParam) of
            BN_CLICKED:   LMessage.Msg := LM_CLICKED;
            BN_KILLFOCUS: LMessage.Msg := LM_EXIT;
          end
        else
        if (lWinControl is TCustomEdit) then
        begin
          if (lWinControl is TCustomMemo) then
          case HIWORD(WParam) of
            // multiline edit doesn't send EN_CHANGE, so use EN_UPDATE
            EN_UPDATE: LMessage.Msg := CM_TEXTCHANGED;
          end
          else
          case HIWORD(WParam) of
            EN_CHANGE: LMessage.Msg := CM_TEXTCHANGED;
          end;
        end
        else if (lWinControl is TCustomListBox) then
          case HIWORD(WParam) of
            LBN_SELCHANGE:  LMessage.Msg := LM_SELCHANGE;
          end
        else if lWinControl is TCustomCombobox then
          if DoCmdComboBoxParam then Exit;
      end;

      // no specific message found? try send a general msg
      lWinControl.Perform(CN_COMMAND, WParam, LParam);
    end;

    WM_CTLCOLORMSGBOX..WM_CTLCOLORSTATIC:
    begin
      // it's needed for winxp themes where controls send the WM_ERASEBKGND
      // message to their parent to clear their background and then draw
      // transparently
      // only static and button controls have transparent parts
      // others need to erased with their window color
      // scrollbar also has buttons
      ChildWindowInfo := GetWin32WindowInfo(HWND(LParam));
      if Assigned(ChildWindowInfo^.ParentMsgHandler)
      and ChildWindowInfo^.ParentMsgHandler(lWinControl,
        Window, Msg, WParam, LParam, LMessage.Result, WinProcess) then Exit(LMessage.Result);
      DoMsgColor(ChildWindowInfo);
    end;
    WM_CLEAR:
    begin
      LMessage.Msg := LM_CLEAR;
      WinProcess := False;
    end;
    WM_COPY:
    begin
      LMessage.Msg := LM_COPY;
      WinProcess := False;
    end;
    WM_CUT:
    begin
      LMessage.Msg := LM_CUT;
      WinProcess := False;
    end;
    {$ifndef RedirectDestroyMessages}
    WM_DESTROY:
    begin
      if CurrentWindow=Window then
        CurrentWindow := 0;
      if lWinControl is TCustomComboBox then
        DisposeComboEditWindowInfo(TCustomComboBox(lWinControl));
      if WindowInfo^.Overlay<>HWND(nil) then
        Windows.DestroyWindow(WindowInfo^.Overlay);
      LMessage.Msg := LM_DESTROY;
    end;
    {$endif}
    WM_DESTROYCLIPBOARD:
    begin
      if assigned(OnClipBoardRequest) then begin
        {$IFDEF VerboseWin32Clipbrd}
        debugln('WM_DESTROYCLIPBOARD');
        {$ENDIF}
        OnClipBoardRequest(0, nil);
        OnClipBoardRequest := nil;
        LMessage.Result := 0;
      end;
    end;
    WM_DRAWITEM: DoMsgDrawItem;
    WM_ENABLE:   DoMsgEnable;
    WM_ERASEBKGND:
      if DoMsgEraseBkgnd(Result) then Exit;
    WM_EXITMENULOOP:
      // is it a popup menu
      if longbool(WPARAM) and Assigned(WindowInfo^.PopupMenu) then
        WindowInfo^.PopupMenu.Close;
    WM_GETDLGCODE:
    begin
      LMessage.Result := DLGC_WANTALLKEYS;
      WinProcess := False;
    end;
    WM_HELP:
      // Don't ask windows to process the message here. It will be processed
      // either by TCustomForm LM_HELP handler or passed to parent by DefaultHandler
      SetLMessageAndParams(LM_HELP, True);
    WM_HOTKEY:
      SetLMessageAndParams(WM_HOTKEY, True);
    WM_HSCROLL,
    WM_VSCROLL:
    begin
      PLMsg := @LMScroll;
      if LParam <> 0 then
      begin
        ChildWindowInfo := GetWin32WindowInfo(HWND(LParam));
        lWinControl := ChildWindowInfo^.WinControl;
        if Assigned(ChildWindowInfo^.ParentMsgHandler) then
          if ChildWindowInfo^.ParentMsgHandler(lWinControl,
            Window, Msg, WParam, LParam, PLMsg^.Result, WinProcess) then Exit(PLMsg^.Result);
      end;
      HandleScrollMessage(Msg);
    end;
    WM_KEYDOWN:
    begin
      DoMsgKeyDownUp(CN_KEYDOWN, Result);
      WindowInfo^.IMEComposed:=False;
      IgnoreNextCharWindow := Window;
      IgnoreKeyUp := False;
    end;
    WM_KEYUP:
    begin
      DoMsgKeyDownUp(CN_KEYUP, Result);
      if WindowInfo^.IMEComposed then
        LMKey.Msg:=LM_NULL;
    end;
    WM_KILLFOCUS:
    begin
{$ifdef DEBUG_CARET}
      DebugLn(['WM_KILLFOCUS received for window ', IntToHex(Window, 8), ' NewFocus = ', IntToHex(WParam, 8), ' Text = ', WndText(WParam)]);
{$endif}
      LMessage.Msg := LM_KILLFOCUS;
      LMessage.WParam := WParam;
    end;
    //TODO:LM_KILLCHAR,LM_KILLWORD,LM_KILLLINE
    WM_LBUTTONDBLCLK: DoMsgMouseDownUpClick(1, True, True);
    WM_LBUTTONDOWN:   DoMsgMouseDownUpClick(1, False, True);
    WM_LBUTTONUP:     DoMsgMouseDownUpClick(1, False, False);
    WM_RBUTTONDBLCLK: DoMsgMouseDownUpClick(2, True, True);
    WM_RBUTTONDOWN:   DoMsgMouseDownUpClick(2, False, True);
    WM_RBUTTONUP:
    begin
      DoMsgMouseDownUpClick(2, False, False);
      WinProcess := false;
      Result := 0;
    end;
    WM_MBUTTONDBLCLK: DoMsgMouseDownUpClick(3, True, True);
    WM_MBUTTONDOWN:   DoMsgMouseDownUpClick(3, False, True);
    WM_MBUTTONUP:     DoMsgMouseDownUpClick(3, False, False);
    WM_XBUTTONDBLCLK: DoMsgMouseDownUpClick(4, True, True);
    WM_XBUTTONDOWN:   DoMsgMouseDownUpClick(4, False, True);
    WM_XBUTTONUP:     DoMsgMouseDownUpClick(4, False, False);
    WM_MOUSEHOVER:
    begin
      NotifyUserInput := True;
      LMessage.Msg := LM_MOUSEENTER;
    end;
    WM_MOUSELEAVE:
    begin
      NotifyUserInput := True;
      LMessage.Msg := LM_MOUSELEAVE;
      if lWinControl=LastMouseTracking then
      begin
        Application.DoBeforeMouseMessage(nil);
        LastMouseTracking := nil;
      end;
    end;
    WM_MOUSEMOVE:  DoMsgMouseMove;
    WM_MOUSEWHEEL: if DoMsgMouseWheel(Result, False) then Exit;
    WM_MOUSEHWHEEL: if DoMsgMouseWheel(Result, True) then Exit;
    WM_DROPFILES:
      begin
        {$IFDEF EnableWMDropFiles}
        SetLMessageAndParams(LM_DROPFILES);
        {$ENDIF}
        HandleDropFiles;
      end;
    //TODO:LM_MOVEPAGE,LM_MOVETOROW,LM_MOVETOCOLUMN
    WM_NCHITTEST:     SetLMessageAndParams(LM_NCHITTEST);
    WM_NCLBUTTONDOWN: DoMsgNCLButtonDown;

    WM_NCMOUSEMOVE,
    WM_NCMOUSEHOVER:
    begin
      SetLMessageAndParams(Msg);
      NotifyUserInput := True;
      Application.DoBeforeMouseMessage(nil);
    end;
    WM_NOTIFY: if DoMsgNotify(Result) then Exit;
    WM_PAINT: SendPaintMessage(HDC(WParam)); // SendPaintMessage sets winprocess to false
    WM_PRINTCLIENT:
      if ((LParam and PRF_CLIENT) = PRF_CLIENT) and (lWinControl <> nil) then
        SendPaintMessage(HDC(WParam));
    WM_PASTE:
    begin
      LMessage.Msg := LM_PASTE;
      WinProcess := False;
    end;
    WM_CONTEXTMENU:
    begin
      DoMsgContextMenu;
      Result := 0;
    end;
    WM_SETCURSOR:  HandleSetCursor;
    CM_ACTIVATE:
    begin
      if (Window = Win32WidgetSet.AppHandle) then
      begin
        // if application window is still focused then move the focus
        // to the next top window
        if not IsIconic(Window) and (GetFocus = Window) then
        begin
          TargetWindow := LookupTopWindow(Window);

          if TargetWindow <> Window then
          begin
            // issues #26463, #29744
            if (Application.ModalLevel > 0) and IsIconic(TargetWindow) then
            begin
              ACtl := FindControl(TargetWindow);
              if (ACtl is TCustomForm) and (fsModal in TCustomForm(ACtl).FormState) then
                Win32WidgetSet.AppRestore;
            end;
            SetFocus(TargetWindow);
          end;
        end;
        Result := 0;
        Exit;
      end;
      WinProcess := False;
    end;
    WM_SETFOCUS:
    begin
{$ifdef DEBUG_CARET}
      DebugLn('WM_SETFOCUS received for window ', IntToHex(Window, 8));
{$endif}
      // move focus to another application window but process event first
      if (Window = Win32WidgetSet.AppHandle) then
        PostMessage(Window, CM_ACTIVATE, 0, 0);
      LMessage.Msg := LM_SETFOCUS;
    end;
    WM_SHOWWINDOW: DoMsgShowWindow;
    WM_SYSCHAR:
    begin
      PLMsg := @LMChar;
      SetLMCharData(CN_SYSCHAR, True);
      Result := 0;
      WinProcess := false;
    end;
    WM_SYSCOMMAND:
    begin
      HandleSysCommand;
      SetLMessageAndParams(Msg);
      WmSysCommandProcess := WinProcess;
      WinProcess := False;
    end;
    WM_SYSKEYDOWN:
    begin
      UpdateUIState(Word(WParam));
      DoMsgSysKey(CN_SYSKEYDOWN);
      Result := 0;
      IgnoreNextCharWindow := Window;
    end;
    WM_SYSKEYUP:
    begin
      DoMsgSysKey(CN_SYSKEYUP);
      Result := 0;
    end;
    WM_TIMER:  SetLMessageAndParams(LM_TIMER);
    WM_WINDOWPOSCHANGING:
    begin
      with TLMWindowPosMsg(LMessage) Do
      begin
        Msg := LM_WINDOWPOSCHANGING;
        Unused := WParam;
        WindowPos := PWindowPos(LParam);
      end;
    end;
    WM_WINDOWPOSCHANGED:
    begin
      with TLMWindowPosMsg(LMessage) Do
      begin
        Msg := LM_WINDOWPOSCHANGED;
        Unused := WParam;
        WindowPos := PWindowPos(LParam);
      end;
      // cross-interface compatible: complete invalidate on resize
      if (PWindowPos(LParam)^.flags and SWP_NOSIZE) = 0 then
        Windows.InvalidateRect(Window, nil, True);
    end;
    WM_MEASUREITEM:   DoMsgMeasureItem;
    WM_SETTINGCHANGE: Application.IntfSettingsChange;
    WM_THEMECHANGED:
      // winxp theme changed, recheck whether themes are enabled
      if Window = Win32WidgetSet.AppHandle then
      begin
        ThemeServices.UpdateThemes;
        Graphics.UpdateHandleObjects;
        ThemeServices.IntfDoOnThemeChange;
      end;
    WM_UPDATEUISTATE:
      if ThemeServices.ThemesEnabled then
        InvalidateRect(Window, nil, True);

    { >= WM_USER }

    WM_LCL_SOCK_ASYNC:
    begin
      if (Window = Win32WidgetSet.AppHandle) and
          Assigned(Win32WidgetSet.FOnAsyncSocketMsg) then
        Exit(Win32WidgetSet.FOnAsyncSocketMsg(WParam, LParam))
    end;
    WM_IME_COMPOSITION,
    WM_IME_COMPOSITIONFULL,
    WM_IME_CONTROL,
    //WM_IME_ENDCOMPOSITION,
    WM_IME_NOTIFY,
    WM_IME_REQUEST,
    WM_IME_SELECT,
    WM_IME_SETCONTEXT,
    WM_IME_STARTCOMPOSITION:
      SetLMessageAndParams(Msg, True);
    WM_ACTIVATEAPP:
    begin
      if (Application<>nil) and Application.MainFormOnTaskBar and not Win32WidgetSet.AppMinimizing then
        RestorePopups;
    end;
    WM_DISPLAYCHANGE:
    begin
      if Application.MainFormHandle = Window then
        Screen.UpdateMonitors;
    end;
  else
    // pass along user defined messages
    if Msg >= WM_USER then
      SetLMessageAndParams(Msg, True);
  end;  // case Msg of

  // Update MDI form client bounds
  if WinProcess and (Msg=WM_SIZE) and Assigned(Application.MainForm)
  and (Application.MainForm.FormStyle=fsMDIForm)
  and Application.MainForm.HandleAllocated and (Window=Application.MainForm.Handle) then
  begin
    Win32WidgetSet.UpdateMDIClientBounds;
    WinProcess := False;
  end;

  if WinProcess then
  begin
    PLMsg^.Result := CallDefaultWindowProc(Window, Msg, WParam, LParam);
    WinProcess := False;
  end;

  case Msg of
    WM_ACTIVATEAPP: DoMsgActivateApp;
    WM_MOVE:        if DoMsgMove then Exit(0);
    WM_SIZE:        DoMsgSize;
    BM_SETCHECK:
    begin
      //LParam holds BST_CHECKED, BST_UNCHECKED or SKIP_LMCHANGE;
      if LParam <> SKIP_LMCHANGE then
        LMessage.Msg := LM_CHANGED;
      if lWinControl is TRadioButton then
      begin
        //Uncheck siblings
        if WParam = BST_CHECKED then
          ClearSiblingRadioButtons(TRadioButton(lWinControl));
      end;
    end;
    WM_ENDSESSION:
    begin
      if Assigned(Application) and (Win32WidgetSet.AppHandle = Window) and
         (WParam > 0) then
      begin
        // look at WM_QUERYENDSESSION about LParam
        LMessage.Msg := LM_NULL; // no need to go through delivermessage
        Application.IntfEndSession();
        LMessage.Result := 0;
      end;
    end;

    WM_QUERYENDSESSION:
    begin
      if Assigned(Application) and (Win32WidgetSet.AppHandle = Window) then
      begin
        LMessage.Msg := LM_NULL; // no need to go through delivermessage
        CancelEndSession := LMessage.Result=0;
        // it is possible to pass whether user LogOff or Shutdonw through a flag
        // but seems there is no way to do this in a cross-platform way =>
        // skip it for now
        Application.IntfQueryEndSession(CancelEndSession);
        if CancelEndSession
          then LMessage.Result := 0
          else LMessage.Result := 1;
      end;
    end;
    WM_NCPAINT:
    begin
      if TWin32ThemeServices(ThemeServices).ThemesEnabled and
        (lWinControl is TCustomControl) and not (lWinControl is TCustomForm) then
      begin
        TWin32ThemeServices(ThemeServices).PaintBorder(lWinControl, True);
        LMessage.Result := 0;
      end;
    end;
  end;  // case Msg of

  // convert from win32 client to lcl client pos.
  //
  // hack to prevent GetLCLClientBoundsOffset from changing mouse client
  // coordinates for TScrollingWinControls, this is required in
  // IsControlMouseMsg and ControlAtPos where unscrolled client coordinates
  // are expected.
  if (PLMsg = @LMMouseMove) and not (lWinControl is TScrollingWinControl) then
  begin
    if GetLCLClientBoundsOffset(lWinControl, R) then
    begin
      Dec(LMMouseMove.XPos, R.Left);
      Dec(LMMouseMove.YPos, R.Top);
    end;
  end else
  if (PLMsg = @LMMouse) and not (lWinControl is TScrollingWinControl) then
  begin
    if GetLCLClientBoundsOffset(lWinControl, R) then
    begin
      Dec(LMMouse.XPos, R.Left);
      Dec(LMMouse.YPos, R.Top);
    end;
  end;

  // application processing
  if NotifyUserInput then
  begin
    CurrentWindow := Window;
    NotifyApplicationUserInput(lWinControl, PLMsg^.Msg);
    // Invalidate associated lWinControl if current window has been destroyed
    if CurrentWindow = 0 then
      lWinControl := nil;
  end;

  if Assigned(lWinControl) and (PLMsg^.Msg <> LM_NULL) then
    DeliverMessage(lWinControl, PLMsg^);

  // respond to result of LCL handling the message
  case PLMsg^.Msg of
    LM_ERASEBKGND, LM_SETCURSOR, LM_RBUTTONUP, LM_CONTEXTMENU:
      if PLMsg^.Result = 0 then
        WinProcess := True;

    WM_SYSCOMMAND:
      WinProcess := WmSysCommandProcess;

    CN_CHAR, CN_SYSCHAR:
    begin
      // if key not yet processed, let windows process it
      WinProcess := LMChar.Result = 0;
      // if charcode was modified by LCL, convert ansi char
      // to unicode char, if not change was made WParam has
      // the right unicode char so just use it.
      if (LMChar.Result = 1) or (OrgCharCode <> LMChar.CharCode) then
        WParam := Word(WideChar(LMChar.CharCode));
    end;

    CN_KEYDOWN, CN_KEYUP, CN_SYSKEYDOWN, CN_SYSKEYUP:
    begin
      // if key not yet processed, let windows process it
      WinProcess := LMKey.Result = 0;
      WParam := LMKey.CharCode;
    end;
    WM_IME_COMPOSITION,
    WM_IME_COMPOSITIONFULL,
    WM_IME_CONTROL,
    WM_IME_ENDCOMPOSITION,
    WM_IME_NOTIFY,
    WM_IME_REQUEST,
    WM_IME_SELECT,
    WM_IME_SETCONTEXT,
    WM_IME_STARTCOMPOSITION,
    LM_CUT,
    LM_COPY,
    LM_PASTE,
    LM_CLEAR:
    begin
      WinProcess := LMessage.Result = 0;
    end;
  else
    case Msg of
      {$ifndef RedirectDestroyMessages}
      WM_NCDESTROY:
      begin
        // free our own data associated with window
        if DisposeWindowInfo(Window) then
          WindowInfo := nil;
        EnumProps(Window, @PropEnumProc);
      end;
      {$endif}
    end;
  end;

  if WinProcess then
  begin
    if ((Msg=WM_CHAR) and ((WParam=VK_RETURN) or (WPARAM=VK_ESCAPE)) and
       ((lWinControl is TCustomCombobox) or
        ((lWinControl is TCustomEdit) and not (lWinControl is TCustomMemo ))
       ))
       or (Msg=WM_SYSCHAR)      // Windows message processing is postponed
    then
      // this thing will beep, don't call defaultWindowProc
    else
      PLMsg^.Result := CallDefaultWindowProc(Window, Msg, WParam, LParam);

    case Msg of
      WM_CHAR, WM_KEYDOWN, WM_KEYUP,
      WM_SYSCHAR, WM_SYSKEYDOWN, WM_SYSKEYUP:
      begin
        PLMsg^.Result := 0;
        case Msg of
          WM_CHAR:
          begin
            // if want chars, then handled already
            PLMsg^.Result := CallDefaultWindowProc(Window, WM_GETDLGCODE, WParam, 0) and DLGC_WANTCHARS;
            SetLMCharData(LM_CHAR);
          end;
          WM_SYSCHAR:    SetLMCharData(LM_SYSCHAR);
          WM_KEYDOWN:    SetLMKeyData(LM_KEYDOWN);
          WM_KEYUP:      SetLMKeyData(LM_KEYUP);
          WM_SYSKEYDOWN: SetLMKeyData(LM_SYSKEYDOWN);
          WM_SYSKEYUP:   SetLMKeyData(LM_SYSKEYUP);
        end;

        case Msg of
          WM_CHAR, WM_SYSCHAR:
            CharCodeNotEmpty := (LMChar.CharCode<>0);
          else
            CharCodeNotEmpty := (LMKey.CharCode<>0);
        end;
        // we cannot tell for sure windows didn't want the key
        // for WM_CHAR check WM_GETDLGCODE/DLGC_WANTCHARS
        // winapi too inconsistent about return value
        if (lWinControl <> nil) and (PLMsg^.Result = 0) and CharCodeNotEmpty then
          DeliverMessage(lWinControl, PLMsg^);

        // Windows message processing for WM_SYSCHAR not processed (will get WM_MENUCHAR)
        if (Msg=WM_SYSCHAR) and (PLMsg^.Result = 0) and CharCodeNotEmpty then
          PLMsg^.Result := CallDefaultWindowProc(Window, Msg, WParam, LParam);

        // handle Ctrl-A for edit controls
        if (PLMsg^.Result = 0) and (Msg = WM_KEYDOWN) and (WParam = Ord('A'))
          and (GetKeyState(VK_CONTROL) < 0) and (GetKeyState(VK_MENU) >= 0) then
        begin
          if WndClassName(Window) = EditClsName then
            Windows.SendMessage(Window, EM_SETSEL, 0, -1);  // select all
        end;
      end;
    end;
  end;

  // ignore WM_(SYS)CHAR message if LCL handled WM_(SYS)KEYDOWN
  if ((Msg = WM_KEYDOWN) or (Msg = WM_SYSKEYDOWN)) then
    if (PLMsg^.Result = 0) then
      IgnoreNextCharWindow := 0;

  { LMInsertText has no Result field }

  if      PLMsg = @LMScroll     then Result := LMScroll.Result
  else if PLMsg = @LMKey        then Result := LMKey.Result
  else if PLMsg = @LMChar       then Result := LMChar.Result
  else if PLMsg = @LMMouse      then Result := LMMouse.Result
  else if PLMsg = @LMMouseMove  then Result := LMMouseMove.Result
  else if PLMsg = @LMMove       then Result := LMMove.Result
  else if PLMsg = @LMNotify     then Result := LMNotify.Result
  else if PLMsg = @LMMouseEvent then Result := LMMouseEvent.Result
  else                               Result := PLMsg^.Result;

  finally
    lWinControl := nil;
  end;
end;

{------------------------------------------------------------------------------
 Function: WindowProc
 Params: Window - The window that receives a message
         Msg    - The message received
         WParam - Word parameter
         LParam - Long-integer parameter
  Returns: 0 if Msg is handled; non-zero long-integer result otherwise

  Handles the messages sent to the specified window, in parameter Window, by
  Windows or other applications
 ------------------------------------------------------------------------------}
function
{$ifdef MSG_DEBUG}
  RealWindowProc
{$else}
  WindowProc
{$endif}
  (Window: HWnd; Msg: UInt; WParam: Windows.WParam; LParam: Windows.LParam): LResult; stdcall;
var
  Helper: TWindowProcHelper;
begin
  FillChar(Helper, SizeOf(TWindowProcHelper), 0);
  Helper.Window := Window;
  Helper.Msg := Msg;
  Helper.WParam := WParam;
  Helper.LParam := LParam;
  Helper.NMHdr := PNMHdr(LParam);
  Result := Helper.DoWindowProc;
  Helper.lWinControl := nil;
end;

{$ifdef MSG_DEBUG}

function WindowProc(Window: HWnd; Msg: UInt; WParam: Windows.WParam;
    LParam: Windows.LParam): LResult; stdcall;
begin
  DebugLn(MessageStackDepth, 'WindowProc called for window=', IntToHex(Window, 8),' msg=',
    WM_To_String(msg),' wparam=', IntToHex(WParam, sizeof(WParam)*2), ' lparam=', IntToHex(lparam, sizeof(lparam)*2));
  MessageStackDepth := MessageStackDepth + ' ';

  Result := RealWindowProc(Window, Msg, WParam, LParam);

  setlength(MessageStackDepth, length(MessageStackDepth)-1);
end;

{$endif}

{------------------------------------------------------------------------------
 Function: OverlayWindowProc
 Params: Window - The window that receives a message
         Msg    - The message received
         WParam - Word parameter
         LParam - Long-integer parameter
  Returns: 0 if Msg is handled; non-zero long-integer result otherwise

  Handles messages specifically for the window used by GetDesignerDC
 ------------------------------------------------------------------------------}
function OverlayWindowProc(Window: HWnd; Msg: UInt; WParam: Windows.WParam;
    LParam: Windows.LParam): LResult; stdcall;
var
  Parent: HWND;
  Owner: TWinControl;
  Control: TControl;
  P: TPoint;
  LRect: Windows.RECT;
begin
  case Msg of
    WM_ERASEBKGND:
    begin
      Result := 1;
    end;
    WM_NCHITTEST:
    begin
      // By default overlay window handle all mouse messages
      Result := HTCLIENT;
      
      // Check if overlayed control want to handle mouse messages
      Parent := Windows.GetParent(Window);
      Owner := GetWin32WindowInfo(Parent)^.WinControl;
      P.x := GET_X_LPARAM(lParam);
      P.y := GET_Y_LPARAM(lParam);
      Windows.ScreenToClient(Parent, P);
      if (Owner is TCustomForm) then
      begin
        // ask form about control under mouse. we need TWinControl
        Control := Owner.ControlAtPos(P, [capfAllowWinControls, capfRecursive]);
        if (Control <> nil) and not (Control is TWinControl) then
          Control := Control.Parent;
      end
      else
        Control := nil;
      if (Control <> nil) then
      begin
        // Now ask control is it needs mouse messages
        MapWindowPoints(Parent, TWinControl(Control).Handle, P, 1);
        if TWSWinControlClass(TWinControl(Control).WidgetSetClass).GetDesignInteractive(TWinControl(Control), P) then
          Result := HTTRANSPARENT
      end;
    end;
    WM_KEYFIRST..WM_KEYLAST, WM_MOUSEFIRST..WM_MOUSELAST:
    begin
      // parent of overlay is the form
      Result := Windows.SendMessage(Windows.GetParent(Window), Msg, WParam, LParam);
    end;
    WM_NCDESTROY:
    begin
      // free our own data associated with window
      DisposeWindowInfo(Window);
      Result := 0;
    end;
    WM_MOVE:
    begin
      if (Int16(LoWord(LParam)) <> 0) or (Int16(HiWord(LParam)) <> 0) then
      begin
        Parent := Windows.GetParent(Window);
        Windows.GetClientRect(Parent, LRect);
        Windows.SetWindowPos(Window, HWND_TOP, 0, 0, LRect.Right, LRect.Bottom, 0);
      end;
    end;
  else
    Result := Windows.DefWindowProcW(Window, Msg, WParam, LParam)
  end;
end;

{$ifdef RedirectDestroyMessages}
{------------------------------------------------------------------------------
 Function: DestroyWindowProc
 Params: Window - The window that receives a message
         Msg    - The message received
         WParam - Word parameter
         LParam - Long-integer parameter
  Returns: 0 if Msg is handled; non-zero long-integer result otherwise

  Handles messages after handle is destroyed
 ------------------------------------------------------------------------------}

function DestroyWindowProc(Window: HWnd; Msg: UInt; WParam: Windows.WParam;
    LParam: Windows.LParam): LResult; stdcall;
var
  LMessage: TLMessage;
  WindowInfo: PWin32WindowInfo;
  lWinControl: TWinControl;
begin
  CallDefaultWindowProc(Window, Msg, WParam, LParam);
  case Msg of
    WM_DESTROY:
    begin
      WindowInfo := GetWin32WindowInfo(Window);
      if WindowInfo^.isChildEdit then
        lWinControl := WindowInfo^.AWinControl
      else
        lWinControl := WindowInfo^.WinControl;
      if CurrentWindow = Window then
        CurrentWindow := 0;
      if lWinControl is TCustomComboBox then
        DisposeComboEditWindowInfo(TCustomComboBox(lWinControl));
      if WindowInfo^.Overlay<>HWND(nil) then
        Windows.DestroyWindow(WindowInfo^.Overlay);
      if lWinControl <> nil then
      begin
        FillChar(LMessage, SizeOf(LMessage), 0);
        LMessage.Msg := LM_DESTROY;
        DeliverMessage(lWinControl, LMessage);
      end;
    end;
    WM_NCDESTROY:
    begin
      // free our own data associated with window
      DisposeWindowInfo(Window);
      EnumProps(Window, @PropEnumProc);
    end;
  end;
end;
{$endif}

{------------------------------------------------------------------------------
 Procedure: TimerCallBackProc
 Params: window_hnd - handle of window for timer message, not set in this implementation
         msg        - WM_TIMER message
         idEvent    - timer identifier
         dwTime     - current system time

 Calls the timerfunction in the Timer Object in the LCL
 ------------------------------------------------------------------------------}
procedure TimerCallBackProc(window_hwnd : hwnd; msg : DWORD; idEvent: UINT_PTR; dwTime: DWORD); stdcall;
Var
  TimerInfo: PWin32TimerInfo;
  n: Integer;
begin
  if Assigned(Application) and Application.Terminated then exit;
  n := FTimerData.Count;
  while (n>0) do begin
    dec(n);
    TimerInfo := FTimerData[n];
    if TimerInfo^.TimerID=idEvent then begin
      TimerInfo^.TimerFunc;
      break;
    end;
  end;
end;

{$IFDEF ASSERT_IS_ON}
  {$UNDEF ASSERT_IS_ON}
  {$C-}
{$ENDIF}


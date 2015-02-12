{ $Id$}
{
 *****************************************************************************
 *                               QtWSForms.pp                                * 
 *                               ------------                                * 
 *                                                                           *
 *                                                                           *
 *****************************************************************************

 *****************************************************************************
  This file is part of the Lazarus Component Library (LCL)

  See the file COPYING.modifiedLGPL.txt, included in this distribution,
  for details about the license.
 *****************************************************************************
}
unit QtWSForms;

{$mode objfpc}{$H+}

interface

{$I qtdefines.inc}

uses
  // Bindings
  qt4,
  qtobjects, qtwidgets, qtproc,
  // LCL
  SysUtils, Classes, types, Controls, LCLType, Forms,
  // Widgetset
  InterfaceBase, WSForms, WSProc, WSLCLClasses;

type

  { TQtWSScrollingWinControl }

  TQtWSScrollingWinControl = class(TWSScrollingWinControl)
  published
    class procedure ScrollBy(const AWinControl: TScrollingWinControl;
      const DeltaX, DeltaY: integer); override;
  end;

  { TQtWSScrollBox }

  TQtWSScrollBox = class(TWSScrollBox)
  published
  end;

  { TQtWSCustomFrame }

  TQtWSCustomFrame = class(TWSCustomFrame)
  published
  end;

  { TQtWSFrame }

  TQtWSFrame = class(TWSFrame)
  published
  end;

  { TQtWSCustomForm }

  TQtWSCustomForm = class(TWSCustomForm)
  private
    class function GetQtBorderStyle(const AFormBorderStyle: TFormBorderStyle): QtWindowFlags;
    class function GetQtBorderIcons(const AFormBorderStyle: TFormBorderStyle; ABorderIcons: TBorderIcons): QtWindowFlags;
    class function GetQtFormStyle(const AFormStyle: TFormStyle): QtWindowFlags;
    class procedure UpdateWindowFlags(const AWidget: TQtMainWindow;
      ABorderStyle: TFormBorderStyle; ABorderIcons: TBorderIcons; AFormStyle: TFormStyle);
  published
    class function GetDefaultClientRect(const AWinControl: TWinControl;
             const {%H-}aLeft, {%H-}aTop, aWidth, aHeight: integer; var aClientRect: TRect
             ): boolean; override;
    class function  CanFocus(const AWinControl: TWinControl): Boolean; override;
    class function CreateHandle(const AWinControl: TWinControl; const AParams: TCreateParams): TLCLIntfHandle; override;

    class procedure CloseModal(const ACustomForm: TCustomForm); override;
    class procedure DestroyHandle(const AWinControl: TWinControl); override;
    class procedure ScrollBy(const AWinControl: TScrollingWinControl;
      const DeltaX, DeltaY: integer); override;
    class procedure SetAllowDropFiles(const AForm: TCustomForm; AValue: Boolean); override;
    class procedure SetFormBorderStyle(const AForm: TCustomForm; const AFormBorderStyle: TFormBorderStyle); override;
    class procedure SetFormStyle(const AForm: TCustomform; const AFormStyle, AOldFormStyle: TFormStyle); override;
    class procedure SetIcon(const AForm: TCustomForm; const Small, Big: HICON); override;
    class procedure SetPopupParent(const ACustomForm: TCustomForm;
       const APopupMode: TPopupMode; const APopupParent: TCustomForm); override;
    class procedure SetShowInTaskbar(const AForm: TCustomForm; const AValue: TShowInTaskbar); override;
    class procedure ShowHide(const AWinControl: TWinControl); override; //TODO: rename to SetVisible(control, visible)
    class procedure ShowModal(const ACustomForm: TCustomForm); override;
    class procedure SetBorderIcons(const AForm: TCustomForm; const ABorderIcons: TBorderIcons); override;
    class procedure SetAlphaBlend(const ACustomForm: TCustomForm;
       const AlphaBlend: Boolean; const Alpha: Byte); override;

    { mdi support }
    class function ActiveMDIChild(const AForm: TCustomForm): TCustomForm; override;
    class function Cascade(const AForm: TCustomForm): Boolean; override;
    class function GetClientHandle(const AForm: TCustomForm): HWND; override;
    class function GetMDIChildren(const AForm: TCustomForm; AIndex: Integer): TCustomForm; override;
    class function Next(const AForm: TCustomForm): Boolean; override;
    class function Previous(const AForm: TCustomForm): Boolean; override;
    class function Tile(const AForm: TCustomForm): Boolean; override;
    class function MDIChildCount(const AForm: TCustomForm): Integer; override;

  end;

  { TQtWSForm }

  TQtWSForm = class(TWSForm)
  published
  end;

  { TQtWSHintWindow }

  TQtWSHintWindow = class(TWSHintWindow)
  published
    class function CreateHandle(const AWinControl: TWinControl; const AParams: TCreateParams): TLCLIntfHandle; override;
  end;

  { TQtWSScreen }

  TQtWSScreen = class(TWSScreen)
  published
  end;

  { TQtWSApplicationProperties }

  TQtWSApplicationProperties = class(TWSApplicationProperties)
  published
  end;


implementation

uses qtint, LCLIntf
  {$IFDEF VerboseQtResize}, LCLProc{$ENDIF}
  ;

{ TQtWSScrollingWinControl }

class procedure TQtWSScrollingWinControl.ScrollBy(
  const AWinControl: TScrollingWinControl; const DeltaX, DeltaY: integer);
var
  Widget: TQtCustomControl;
begin
  if not WSCheckHandleAllocated(AWinControl, 'ScrollBy') then
    Exit;
  Widget := TQtCustomControl(AWinControl.Handle);
  Widget.viewport.scroll(DeltaX, DeltaY);
end;

{------------------------------------------------------------------------------
  Method: TQtWSCustomForm.CreateHandle
  Params:  None
  Returns: Nothing

  Creates a Qt Form and initializes it according to it's properties
 ------------------------------------------------------------------------------}
class function TQtWSCustomForm.CreateHandle(const AWinControl: TWinControl;
  const AParams: TCreateParams): TLCLIntfHandle;
var
  QtMainWindow: TQtMainWindow;
  Str: WideString;
  PopupParent: QWidgetH;
  AForm: TCustomForm;
begin
  {$ifdef VerboseQt}
    WriteLn('[TQtWSCustomForm.CreateHandle] Height: ', IntToStr(AWinControl.Height),
     ' Width: ', IntToStr(AWinControl.Width));
  {$endif}

  // Creates the window
  {$IFDEF HASX11}
  if (QtVersionMajor = 4) and (QtVersionMinor >= 6) then
    QCoreApplication_setAttribute(QtAA_ImmediateWidgetCreation, True);
  {$ENDIF}
  if csDesigning in AWinControl.ComponentState then
    QtMainWindow := TQtDesignWidget.Create(AWinControl, AParams)
  else
    QtMainWindow := TQtMainWindow.Create(AWinControl, AParams);

  AForm := TCustomForm(AWinControl);

  QtMainWindow.QtFormBorderStyle := Ord(AForm.BorderStyle);
  QtMainWindow.QtFormStyle := Ord(AForm.FormStyle);

  Str := GetUtf8String(AWinControl.Caption);

  QtMainWindow.SetWindowTitle(@Str);

  if not (csDesigning in AForm.ComponentState) then
  begin
    UpdateWindowFlags(QtMainWindow, AForm.BorderStyle,
      AForm.BorderIcons, AForm.FormStyle);
  end;

  if (not (AForm.FormStyle in [fsMDIChild]) or (csDesigning in AForm.ComponentState)) and
     (Application <> nil) and
     (Application.MainForm <> nil) and
     (Application.MainForm.HandleAllocated) and
     (Application.MainForm <> AForm) then
  begin
    if (AForm.ShowInTaskBar in [stDefault, stNever])
       {$ifdef HASX11}
       {QtTool have not minimize button !}
       and (not (AForm.BorderStyle in [bsSizeToolWin, bsToolWindow]) or
          (csDesigning in AForm.ComponentState))
       {$endif} then
      QtMainWindow.setShowInTaskBar(False);
    if Assigned(AForm.PopupParent) then
      PopupParent := TQtWidget(AForm.PopupParent.Handle).Widget
    else
      PopupParent := nil;
    if not (csDesigning in AForm.ComponentState) then
      QtMainWindow.setPopupParent(AForm.PopupMode, PopupParent);
  end;

  {$IFDEF HASX11}
  if (QtVersionMajor = 4) and (QtVersionMinor >= 6) then
    QCoreApplication_setAttribute(QtAA_ImmediateWidgetCreation, False);
  {$ENDIF}

  // Sets Various Events
  QtMainWindow.AttachEvents;
  {$IFDEF QTSCROLLABLEFORMS}
  if Assigned(QtMainWindow.ScrollArea) then
    QtMainWindow.ScrollArea.AttachEvents;
  {$ENDIF}
  QtMainWindow.MenuBar.AttachEvents;
  
  if not (csDesigning in AForm.ComponentState) and
    (AForm.FormStyle in [fsMDIChild]) and
    (Application.MainForm.FormStyle = fsMdiForm) then
  begin
    QMdiArea_addSubWindow(
      QMdiAreaH(TQtMainWindow(Application.MainForm.Handle).MDIAreaHandle.Widget),
      QtMainWindow.Widget, QtMainWindow.windowFlags);
    QtMainWindow.MDIChildArea := TQtMainWindow(Application.MainForm.Handle).MDIAreaHandle;
  end;

  // Return the handle
  Result := TLCLIntfHandle(QtMainWindow);
end;

{------------------------------------------------------------------------------
  Method: TQtWSCustomForm.CloseModal
  Params:
  Returns: Nothing
 ------------------------------------------------------------------------------}
class procedure TQtWSCustomForm.CloseModal(const ACustomForm: TCustomForm);
begin
  inherited CloseModal(ACustomForm);
end;

class procedure TQtWSCustomForm.DestroyHandle(const AWinControl: TWinControl);
var
  w: TQtWidget;
begin
  w := TQtWidget(AWinControl.Handle);
  {forms which have another widget as parent
   eg.form inside tabpage or mdichilds
   can segfault without hiding before release.
   So we save our day here.}
  if w.getVisible and (w.getParent <> nil) then
    w.Hide;
  w.Release;
end;

class procedure TQtWSCustomForm.ScrollBy(
  const AWinControl: TScrollingWinControl; const DeltaX, DeltaY: integer);
{$IFDEF QTSCROLLABLEFORMS}
var
  Widget: TQtMainWindow;
{$ENDIF}
begin
  {$IFDEF QTSCROLLABLEFORMS}
  if not WSCheckHandleAllocated(AWinControl, 'ScrollBy') then
    Exit;
  Widget := TQtMainWindow(AWinControl.Handle);
  if Assigned(Widget.ScrollArea) then
    Widget.ScrollArea.scroll(DeltaX, DeltaY);
  {$ENDIF}
end;

{------------------------------------------------------------------------------
  Method: TQtWSCustomForm.SetAllowDropFiles
  Params:
  Returns: Nothing
 ------------------------------------------------------------------------------}
class procedure TQtWSCustomForm.SetAllowDropFiles(const AForm: TCustomForm;
  AValue: Boolean);
begin
  if AForm.HandleAllocated then
    TQtMainWindow(AForm.Handle).setAcceptDropFiles(AValue);
end;

{------------------------------------------------------------------------------
  Method: TQtWSCustomForm.SetFormBorderStyle
  Params:
  Returns: Nothing
 ------------------------------------------------------------------------------}
class procedure TQtWSCustomForm.SetFormBorderStyle(const AForm: TCustomForm;
  const AFormBorderStyle: TFormBorderStyle);
var
  QtWin: TQtMainWindow;
begin
  QtWin := TQtMainWindow(AForm.Handle);
  if (AForm.Parent <> nil) and (QtWin.QtFormBorderStyle <> Ord(AFormBorderStyle)) then
    RecreateWnd(AForm)
  else
  begin
    QtWin.QtFormBorderStyle := Ord(AFormBorderStyle);
    UpdateWindowFlags(QtWin, AFormBorderStyle,
      AForm.BorderIcons, AForm.FormStyle);
  end;
end;

class procedure TQtWSCustomForm.SetFormStyle(const AForm: TCustomform;
  const AFormStyle, AOldFormStyle: TFormStyle);
var
  QtWin: TQtMainWindow;
begin
  QtWin := TQtMainWindow(AForm.Handle);
  if (AForm.Parent <> nil) and (QtWin.QtFormStyle <> Ord(AFormStyle)) then
    RecreateWnd(AForm)
  else
  begin
    QtWin.QtFormStyle := Ord(AFormStyle);
    UpdateWindowFlags(QtWin, AForm.BorderStyle, AForm.BorderIcons, AFormStyle);
  end;
end;

{------------------------------------------------------------------------------
  Method: TQtWSCustomForm.SetIcon
  Params:
  Returns: Nothing
 ------------------------------------------------------------------------------}
class procedure TQtWSCustomForm.SetIcon(const AForm: TCustomForm; const Small, Big: HICON);
var
  Icon: TQtIcon;
begin
  Icon := TQtIcon(Big);
  if Icon <> nil then
    TQtWidget(AForm.Handle).setWindowIcon(Icon.Handle)
  else
    TQtWidget(AForm.Handle).setWindowIcon(nil);
end;

class procedure TQtWSCustomForm.SetPopupParent(const ACustomForm: TCustomForm;
  const APopupMode: TPopupMode; const APopupParent: TCustomForm);
var
  PopupParent: QWidgetH;
begin
  if Assigned(APopupParent) then
    PopupParent := TQtWidget(APopupParent.Handle).Widget
  else
    PopupParent := nil;
  TQtMainWindow(ACustomForm.Handle).setPopupParent(APopupMode, PopupParent);
end;

{------------------------------------------------------------------------------
  Method: TQtWSCustomForm.SetShowInTaskbar
  Params:
  Returns: Nothing
 ------------------------------------------------------------------------------}
class procedure TQtWSCustomForm.SetShowInTaskbar(const AForm: TCustomForm; const AValue: TShowInTaskbar);
var
  Enable: Boolean;
begin
  if (AForm.Parent<>nil) or not (AForm.HandleAllocated) then exit;

  Enable := AValue <> stNever;
  if (AValue = stDefault) and
    {$IFDEF HASX11}
    TQtMainWindow(AForm.Handle).ShowOnTaskBar and
    {$ENDIF}
     (Application<>nil) and
     (Application.MainForm <> nil) and
     (Application.MainForm <> AForm) then
    Enable := false;
  {$IFDEF HASX11}
  if (AForm.FormStyle <> fsMDIChild) then
    SetSkipX11Taskbar(TQtMainWindow(AForm.Handle).Widget, not Enable);
  {$ENDIF}
  TQtMainWindow(AForm.Handle).setShowInTaskBar(Enable);
end;

class procedure TQtWSCustomForm.ShowHide(const AWinControl: TWinControl);
const
  LCLToQtWindowState: array[TWindowState] of QtWindowState = (
 { wsNormal    } QtWindowNoState,
 { wsMinimized } QtWindowMinimized,
 { wsMaximized } QtWindowMaximized,
 { wsFullScreen} QtWindowFullScreen
  );
var
  Widget: TQtMainWindow;
  R: TRect;
  ActiveWin: HWND;
  W: QWidgetH;
  Flags: Cardinal;

  function ShowNonModalOverModal: Boolean;
  var
    AForm: TCustomForm;
    AWidget: QWidgetH;
  begin
    Result := False;
    AForm := TCustomForm(AWinControl);
    if AWinControl.HandleObjectShouldBeVisible and
      not (fsModal in AForm.FormState) and
      (AForm.FormStyle <> fsMDIChild) and
      not (AForm.FormStyle in fsAllStayOnTop) and
      (AForm.Parent = nil) and
      (QApplication_activeModalWidget() <> nil) and
      (AForm.BorderStyle in [bsDialog, bsSingle, bsSizeable]) and
      (AForm.PopupParent = nil) and (AForm.PopupMode = pmNone) then
    begin
      AWidget := TQtWidget(AForm.Handle).Widget;
      {$IFDEF DARWIN}
      QWidget_setParent(AWidget, QApplication_activeWindow());
      QWidget_setWindowFlags(Widget.Widget, QtSheet or
        GetQtBorderIcons(TCustomForm(AWinControl).BorderStyle,
          TCustomForm(AWinControl).BorderIcons));
      {$ELSE}
      QWidget_setParent(AWidget, QApplication_desktop());
      {$IFDEF MSWINDOWS}
      QWidget_setWindowFlags(Widget.Widget, QtDialog or
        QtWindowSystemMenuHint or
        GetQtBorderIcons(TCustomForm(AWinControl).BorderStyle,
          TCustomForm(AWinControl).BorderIcons));
      {$ENDIF}
      QWidget_setWindowModality(AWidget, QtWindowModal);
      {$ENDIF}
      Result := True;
    end;
  end;

begin
  if not WSCheckHandleAllocated(AWinControl, 'ShowHide') then
    Exit;

  Widget := TQtMainWindow(AWinControl.Handle);

  if AWinControl.HandleObjectShouldBeVisible then
  begin
    if fsModal in TForm(AWinControl).FormState then
    begin
      {$ifdef MSWINDOWS}
      // qt doesn't modal windows as QtTool.see issue #18709
      if (TForm(AWinControl).BorderStyle in [bsToolWindow, bsSizeToolWin]) then
        QWidget_setWindowFlags(Widget.Widget, QtDialog);
      {$endif}

      {$ifdef HASX11}
      if ((QtWidgetSet.WindowManagerName = 'kwin') and IsOldKDEInstallation) or
        (QtWidgetSet.WindowManagerName = 'xfwm4') or
        (QtWidgetSet.WindowManagerName = 'metacity') then
      begin
        W := nil;
        ActiveWin := GetActiveWindow;
        if ActiveWin <> 0 then
        begin
          if Assigned(TQtWidget(ActiveWin).LCLObject) then
          begin
            if (TQtWidget(ActiveWin).LCLObject is TCustomForm) then
            begin
              with TCustomForm(TQtWidget(ActiveWin).LCLObject) do
              begin
                if Visible and (FormStyle <> fsSplash) then
                  W := TQtWidget(Handle).Widget;
              end;
            end;
          end;
        end;
        QWidget_setParent(Widget.Widget, W);
      end else
        QWidget_setParent(Widget.Widget, QApplication_desktop());
      {$endif}

      if TCustomForm(AWinControl).BorderStyle <> bsNone then
      begin
        QWidget_setWindowFlags(Widget.Widget, QtDialog or
          {$ifdef darwin}
          QtWindowSystemMenuHint or
          {$endif}
          GetQtBorderIcons(TCustomForm(AWinControl).BorderStyle,
            TCustomForm(AWinControl).BorderIcons));
      end;

      Widget.setWindowModality(QtApplicationModal);
    end;

    if TForm(AWinControl).FormStyle = fsMDIChild then
    begin
      {MDI windows have to be resized , since titlebar is included into widget geometry !}
      if not (csDesigning in AWinControl.ComponentState)
        and not Widget.isMaximized then
      begin
        QWidget_contentsRect(Widget.Widget, @R);
        R.Right := TForm(AWinControl).Width + R.Left;
        R.Bottom := TForm(AWinControl).Height + R.Top;
        R.Left := Widget.MdiChildCount * 10;
        R.Top := Widget.MdiChildCount * 10;
        Widget.move(R.Left, R.Top);
        Widget.resize(R.Right, R.Bottom);
      end;
    end;

    if (TForm(AWinControl).FormStyle <> fsMDIChild) or
      (csDesigning in AWinControl.ComponentState) then
    begin
      if (csDesigning in AWinControl.ComponentState) and
        (TCustomForm(AWinControl).WindowState = wsMaximized) then
        Widget.setWindowState(LCLToQtWindowState[wsNormal])
      else
        Widget.setWindowState(LCLToQtWindowState[TCustomForm(AWinControl).WindowState]);
    end;
  end;

  Widget.BeginUpdate;
  if not (csDesigning in AWinControl.ComponentState) then
  begin
    if ShowNonModalOverModal then
    // issue #12459
    else
    if AWinControl.HandleObjectShouldBeVisible
      and (TCustomForm(AWinControl).FormStyle in fsAllStayOnTop) then
    begin
      Flags := Widget.windowFlags;
      if (Flags and QtWindowStaysOnTopHint = 0) then
      begin
        Flags := Flags or QtWindowStaysOnTopHint;
        Widget.setWindowFlags(Flags);
      end;
      if not Assigned(AWinControl.Parent) and
        not (fsModal in TForm(AWinControl).FormState) and
        (TForm(AWinControl).FormStyle <> fsMDIChild) and
        (QApplication_activeModalWidget() <> nil) then
          TQtMainWindow(Widget).setPopupParent(pmExplicit,
            QApplication_activeModalWidget());
    end else
    begin
      if (TCustomForm(AWinControl).FormStyle in fsAllStayOnTop) then
      begin
        if not (csDestroying in AWinControl.ComponentState) then
        begin
          Flags := Widget.windowFlags;
          Flags := Flags and not QtWindowStaysOnTopHint;
          Widget.setWindowFlags(Flags);
        end;
      end;
      {$IFDEF HASX11}
      // issue #26018
      if AWinControl.HandleObjectShouldBeVisible and
        not (TCustomForm(AWinControl).FormStyle in fsAllStayOnTop) and
        not (fsModal in TCustomForm(AWinControl).FormState) and
        (TCustomForm(AWinControl).PopupMode = pmAuto) and
        (TCustomForm(AWinControl).BorderStyle = bsNone) and
        (TCustomForm(AWinControl).PopupParent = nil) then
      begin
        W := QApplication_activeWindow;
        if (W <> nil) and not QWidget_isModal(W) then
        begin
          Flags := QWidget_windowFlags(W);
          if (Flags and QtWindowStaysOnTopHint <> QtWindowStaysOnTopHint) and
            GetAlwaysOnTopX11(W) then
          begin
            Flags := Widget.windowFlags;
            Widget.setWindowFlags(Flags or QtWindowStaysOnTopHint);
          end;
        end;
      end;
      {$ENDIF}
    end;
  end;

  Widget.setVisible(AWinControl.HandleObjectShouldBeVisible);
  Widget.EndUpdate;

  {$IFDEF HASX11}

  if Application.TaskBarBehavior = tbSingleButton then
    SetShowInTaskbar(TForm(AWinControl), TForm(AWinControl).ShowInTaskBar);

  if AWinControl.HandleObjectShouldBeVisible and
    not (csDesigning in TForm(AWinControl).ComponentState) and
        (TForm(AWinControl).FormStyle <> fsMDIChild) then
  begin
    if (fsModal in TForm(AWinControl).FormState) then
    begin
      if (Application.TaskBarBehavior <> tbSingleButton) then
      begin
        SetSkipX11Taskbar(Widget.Widget, True);
        Widget.setShowInTaskBar(False);
      end;
      if (QtWidgetSet.WindowManagerName = 'metacity') then
        X11Raise(QWidget_winID(Widget.Widget));
    end else
    if (TForm(AWinControl).FormStyle = fsSplash) then
    begin
      QWidget_repaint(Widget.GetContainerWidget);
      QCoreApplication_processEvents(QEventLoopExcludeUserInputEvents);
    end;
  end;
  {$ENDIF}
end;

{------------------------------------------------------------------------------
  Method: TQtWSCustomForm.ShowModal
  Params:
  Returns: Nothing
 ------------------------------------------------------------------------------}
class procedure TQtWSCustomForm.ShowModal(const ACustomForm: TCustomForm);
begin
  {
    Setting modal flags is done in TQtWSCustomControl.ShowHide
    Since that flags has effect only when Widget is not visible
    
    We can of course hide widget, set flags here and then show it, but we do not
    want window flickering :)
  }
end;

{------------------------------------------------------------------------------
  Method: TQtWSCustomForm.SetBorderIcons
  Params:
  Returns: Nothing
 ------------------------------------------------------------------------------}
class procedure TQtWSCustomForm.SetBorderIcons(const AForm: TCustomForm;
  const ABorderIcons: TBorderIcons);
begin
  UpdateWindowFlags(TQtMainWindow(AForm.Handle), AForm.BorderStyle, ABorderIcons, AForm.FormStyle);
end;

class procedure TQtWSCustomForm.SetAlphaBlend(const ACustomForm: TCustomForm;
  const AlphaBlend: Boolean; const Alpha: Byte);
begin
  if AlphaBlend then
    TQtMainWindow(ACustomForm.Handle).setWindowOpacity(Alpha / 255)
  else
    TQtMainWindow(ACustomForm.Handle).setWindowOpacity(1);
end;

class function TQtWSCustomForm.ActiveMDIChild(const AForm: TCustomForm
  ): TCustomForm;
var
  MDIWorkSpace: QMdiAreaH;
  ActiveChild: QWidgetH;
  i: Integer;
begin
  Result := nil;
  if not WSCheckHandleAllocated(AForm, 'ActiveMDIChild') then
    Exit;
  if not (AForm.FormStyle in [fsMDIForm, fsMDIChild]) then
    exit;
  if AForm.FormStyle = fsMDIForm then
    MDIWorkSpace := QMdiAreaH(TQtMainWindow(AForm.Handle).MDIAreaHandle.Widget)
  else
    MDIWorkSpace := QMdiSubWindow_mdiArea(QMdiSubWindowH(TQtWidget(AForm.Handle).Widget));

  if MDIWorkSpace <> nil then
  begin
    ActiveChild := QMdiArea_activeSubWindow(MDIWorkSpace);
    for i := 0 to Screen.FormCount - 1 do
    begin
      if (Screen.Forms[i].HandleAllocated) and
      (TQtWidget(Screen.Forms[i].Handle).Widget = ActiveChild) then
      begin
        Result := Screen.Forms[i];
        break;
      end;
    end;
  end;
end;

{------------------------------------------------------------------------------
  Method: TQtWSCustomForm.Cascade
  Params:  AForm fsMDIForm.
  Returns: Nothing
  Cascade mdi children.
 ------------------------------------------------------------------------------}
class function TQtWSCustomForm.Cascade(const AForm: TCustomForm): Boolean;
var
  MDIWorkspace: QMdiAreaH;
begin
  Result := False;
  if not WSCheckHandleAllocated(AForm, 'Cascade') then
    Exit;
  if AForm.FormStyle <> fsMDIForm then
    exit;
  MDIWorkSpace := QMdiAreaH(TQtMainWindow(AForm.Handle).MDIAreaHandle.Widget);
  QMdiArea_cascadeSubWindows(MDIWorkSpace);
end;

{------------------------------------------------------------------------------
  Method: TQtWSCustomForm.Next
  Params:  AForm fsMDIForm.
  Returns: Nothing
  Returns handle of mdi area container (viewport).
  Currently not implemented.
 ------------------------------------------------------------------------------}
class function TQtWSCustomForm.GetClientHandle(const AForm: TCustomForm): HWND;
begin
  {TODO: make TQtMainWindow(AForm.Handle).MDIAreaHandle TQtWidget and return that,
   but without attached events !}
  Result := 0;
  if not WSCheckHandleAllocated(AForm, 'GetClientHandle') then
    Exit;
  Result := HWND(TQtMainWindow(AForm.Handle).MDIAreaHandle);
end;

{------------------------------------------------------------------------------
  Method: TQtWSCustomForm.Next
  Params:  AForm: Parent fsMDIForm, AIndex - index of mdi child
  Returns: Nothing
  Returns MDI child window at index AIndex.
 ------------------------------------------------------------------------------}
class function TQtWSCustomForm.GetMDIChildren(const AForm: TCustomForm;
  AIndex: Integer): TCustomForm;
var
  MDIWorkspace: QMdiAreaH;
  IntAr: TPtrIntArray;
  ChildAtIndex: QWidgetH;
  i: Integer;
begin
  Result := nil;
  if not WSCheckHandleAllocated(AForm, 'GetMDIChildren') then
    Exit;
  if not (AForm.FormStyle in [fsMDIForm, fsMDIChild]) then
    exit;

  if AForm.FormStyle = fsMDIForm then
    MDIWorkSpace := QMdiAreaH(TQtMainWindow(AForm.Handle).MDIAreaHandle.Widget)
  else
    MDIWorkSpace := QMdiSubWindow_mdiArea(QMdiSubWindowH(TQtWidget(AForm.Handle).Widget));

  if MDIWorkSpace <> nil then
  begin
    QMdiArea_subWindowList(MDIWorkSpace, @IntAr);
    if (AIndex >= 0) and (AIndex <= High(IntAr)) then
    begin
      ChildAtIndex := QMdiSubWindowH(IntAr[AIndex]);
      for i := 0 to Screen.FormCount - 1 do
      begin
        if TQtWidget(Screen.Forms[i].Handle).Widget = ChildAtIndex then
        begin
          Result := Screen.Forms[i];
          break;
        end;
      end;
    end;
  end;
end;

{------------------------------------------------------------------------------
  Method: TQtWSCustomForm.Next
  Params:  AForm: Parent fsMDIForm
  Returns: Nothing
  Activates next MDI child window in chain, if next reaches last subwindow,
  it restarts from first window.
 ------------------------------------------------------------------------------}
class function TQtWSCustomForm.Next(const AForm: TCustomForm): Boolean;
var
  MDIWorkspace: QMdiAreaH;
begin
  Result := False;
  if not WSCheckHandleAllocated(AForm, 'Next') then
    Exit;
  if AForm.FormStyle <> fsMDIForm then
    exit;
  MDIWorkSpace := QMdiAreaH(TQtMainWindow(AForm.Handle).MDIAreaHandle.Widget);
  QMdiArea_activateNextSubWindow(MDIWorkSpace);
end;

{------------------------------------------------------------------------------
  Method: TQtWSCustomForm.Previous
  Params:  AForm: Parent fsMDIForm
  Returns: Nothing
  Activates previous MDI child window in chain.
 ------------------------------------------------------------------------------}
class function TQtWSCustomForm.Previous(const AForm: TCustomForm): Boolean;
var
  MDIWorkspace: QMdiAreaH;
begin
  Result := False;
  if not WSCheckHandleAllocated(AForm, 'Previous') then
    Exit;
  if AForm.FormStyle <> fsMDIForm then
    exit;
  MDIWorkSpace := QMdiAreaH(TQtMainWindow(AForm.Handle).MDIAreaHandle.Widget);
  QMdiArea_activatePreviousSubWindow(MDIWorkSpace);
end;

{------------------------------------------------------------------------------
  Method: TQtWSCustomForm.Tile
  Params:  AForm: Parent fsMDIForm
  Returns: Nothing
  Tiles mdi children.
 ------------------------------------------------------------------------------}
class function TQtWSCustomForm.Tile(const AForm: TCustomForm): Boolean;
var
  MDIWorkspace: QMdiAreaH;
begin
  Result := False;
  if not WSCheckHandleAllocated(AForm, 'Tile') then
    Exit;
  if AForm.FormStyle <> fsMDIForm then
    exit;
  MDIWorkSpace := QMdiAreaH(TQtMainWindow(AForm.Handle).MDIAreaHandle.Widget);
  QMdiArea_tileSubWindows(MDIWorkSpace);
end;

{------------------------------------------------------------------------------
  Method: TQtWSCustomForm.MDIChildCount
  Params:  AForm: Parent fsMDIForm
  Returns: Nothing
  Returns number of mdi child windows.
 ------------------------------------------------------------------------------}
class function TQtWSCustomForm.MDIChildCount(const AForm: TCustomForm
  ): Integer;
var
  MDIWorkspace: QMdiAreaH;
  IntAr: TPtrIntArray;
begin
  Result := 0;
  if not WSCheckHandleAllocated(AForm, 'MDIChildCount') then
    Exit;
  if not (AForm.FormStyle in [fsMDIForm, fsMDIChild]) then
    exit;

  if AForm.FormStyle = fsMDIForm then
    MDIWorkSpace := QMdiAreaH(TQtMainWindow(AForm.Handle).MDIAreaHandle.Widget)
  else
    MDIWorkSpace := QMdiSubWindow_mdiArea(QMdiSubWindowH(TQtWidget(AForm.Handle).Widget));

  if MDIWorkSpace <> nil then
  begin
    QMdiArea_subWindowList(MDIWorkSpace, @IntAr);
    Result := length(IntAr);
  end;
end;

{------------------------------------------------------------------------------
  Method: TQtWSCustomForm.GetQtWindowBorderStyle
  Params:  None
  Returns: Nothing

 ------------------------------------------------------------------------------}
class function TQtWSCustomForm.GetQtBorderStyle(const AFormBorderStyle: TFormBorderStyle): QtWindowFlags;
begin
  case AFormBorderStyle of
    bsNone:
      Result := QtWindow or QtFramelessWindowHint;
    bsSingle:
      Result := QtWindow or QtMSWindowsFixedSizeDialogHint;
    bsSizeable:
      Result := QtWindow;
    bsDialog:
      Result := QtDialog or QtMSWindowsFixedSizeDialogHint;
    bsToolWindow:
      Result := QtTool or QtMSWindowsFixedSizeDialogHint;
    bsSizeToolWin:
      // qt on most platforms (except windows) doesn't have sizeToolWin, it's regular qtWindow
      Result := {$ifdef windows}QtTool{$else}QtWindow{$endif}; 
    else
      Result := QtWidget;
  end;
end;

{------------------------------------------------------------------------------
  Method: TQtWSCustomForm.SetQtBorderIcons
  Params:  None
  Returns: Nothing

  Same comment as SetQtWindowBorderStyle above
 ------------------------------------------------------------------------------}
class function TQtWSCustomForm.GetQtBorderIcons(const AFormBorderStyle: TFormBorderStyle; ABorderIcons: TBorderIcons): QtWindowFlags;
begin
  Result := 0;

  case AFormBorderStyle of
    bsNone: Exit;
    bsDialog: ABorderIcons := ABorderIcons - [biMaximize, biMinimize];
    bsToolWindow, bsSizeToolWin: ABorderIcons := ABorderIcons - [biMaximize, biMinimize, biHelp];
  end;

  Result := QtCustomizeWindowHint
        or QtWindowTitleHint or QtWindowCloseButtonHint;

  if (biSystemMenu in ABorderIcons) then
    Result := Result or QtWindowSystemMenuHint;

  if (biMinimize in ABorderIcons) then
    Result := Result or QtWindowMinimizeButtonHint;

  if (biMaximize in ABorderIcons) then
    Result := Result or QtWindowMaximizeButtonHint;

  if (biHelp in ABorderIcons) then
    Result := Result or QtWindowContextHelpButtonHint;
end;

class function TQtWSCustomForm.GetQtFormStyle(const AFormStyle: TFormStyle): QtWindowFlags;
begin
  if AFormStyle in fsAllStayOnTop then
    Result := QtWindowStaysOnTopHint
  else
    Result := 0;
end;

class procedure TQtWSCustomForm.UpdateWindowFlags(const AWidget: TQtMainWindow;
  ABorderStyle: TFormBorderStyle; ABorderIcons: TBorderIcons; AFormStyle: TFormStyle);
var
  Flags: QtWindowFlags;
  AVisible: Boolean;
begin
  AWidget.BeginUpdate;
  AVisible := AWidget.getVisible;
  Flags := GetQtBorderStyle(ABorderStyle) or GetQtFormStyle(AFormStyle) or GetQtBorderIcons(ABorderStyle, ABorderIcons);
  if (Flags and QtFramelessWindowHint) = 0 then
    Flags := Flags or QtWindowTitleHint or QtCustomizeWindowHint
      or QtWindowCloseButtonHint;

  if not (csDesigning in AWidget.LCLObject.ComponentState) then
  begin
    AWidget.setWindowFlags(Flags);
    if ABorderStyle in [bsDialog, bsNone, bsSingle] then
      AWidget.Resize(AWidget.LCLObject.Width, AWidget.LCLObject.Height)
    else
    begin
      // Reset constraints.
      AWidget.setMinimumSize(QtMinimumWidgetSize, QtMinimumWidgetSize);
      AWidget.setMaximumSize(QtMaximumWidgetSize, QtMaximumWidgetSize);
    end;
  end;

  AWidget.setVisible(AVisible);
  AWidget.EndUpdate;
end;

class function TQtWSCustomForm.GetDefaultClientRect(
  const AWinControl: TWinControl; const aLeft, aTop, aWidth, aHeight: integer;
  var aClientRect: TRect): boolean;
var
  AWin: TQtMainWindow;
  ASize: TSize;
begin
  Result := False;
  if AWinControl.HandleAllocated and
     TQtMainWindow(AWinControl.Handle).testAttribute(QtWA_PendingResizeEvent) then
  begin
    if Assigned(TCustomForm(AWinControl).Menu) then
    begin
      AWin := TQtMainWindow(AWinControl.Handle);
      if Assigned(AWin.MenuBar) then
      begin
        AWin.MenuBar.sizeHint(@ASize);
        // geometry isn't updated yet
        if ASize.cy < 10 then
          ASize.cy := 0;
        // we must use real geometry, and then exclude menubar height.
        aClientRect := AWin.getGeometry;
        OffsetRect(aClientRect, -aClientRect.Left, -aClientRect.Top);
        dec(AClientRect.Bottom, ASize.cy);
        {$IFDEF VerboseQtResize}
        DebugLn('TQtWSCustomForm.getDefaultClientRect ',dbgsName(AWinControl),' ',dbgs(AWin.getClientBounds),' mnuBarHeight ',dbgs(AWin.MenuBar.getHeight),' ASize=',dbgs(ASize),' FINAL=',dbgs(AClientRect));
        {$ENDIF}
        Result := True;
      end;
    end;
  end;
end;

class function TQtWSCustomForm.CanFocus(const AWinControl: TWinControl
  ): Boolean;
var
  Widget: TQtWidget;
begin
  if AWinControl.HandleAllocated then
  begin
    Widget := TQtWidget(AWinControl.Handle);
    Result := Widget.getVisible and Widget.getEnabled;
  end else
    Result := False;
end;

{ TQtWSHintWindow }

class function TQtWSHintWindow.CreateHandle(const AWinControl: TWinControl; const AParams: TCreateParams): TLCLIntfHandle;
var
  QtMainWindow: TQtMainWindow;
begin
  QtMainWindow := TQtHintWindow.Create(AWinControl, AParams);
  // Sets Various Events
  QtMainWindow.AttachEvents;
  Result := TLCLIntfHandle(QtMainWindow);
end;

end.

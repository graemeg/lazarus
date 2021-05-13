{
 *****************************************************************************
  See the file COPYING.modifiedLGPL.txt, included in this distribution,
  for details about the license.
 *****************************************************************************

  Authors: Maciej Izak
           Michael W. Vogel

  DaThoX 2004-2015
  FreeSparta.com

  Known Issues:
    - when form / frame is moved out of screen, there the form has no designer
      grid (dots)
    - ObjectInspector eats focus of AnchorDesigner (bug or feature?)
    - Qt5 shows own menu in form, this isn't shown in anchor editor
    - designer: mouse wheel to scroll content doesn't work - csDesigning is set and
      form doesn't get a LM_MOUSEWHEEL message
  TODO:

}

unit DockedMainIDE;

{$mode objfpc}{$H+}
{ $define DEBUGDOCKEDFORMEDITOR}

interface

uses
  // RTL
  Classes, SysUtils, Contnrs,
  // LCL
  LCLIntf, Controls, Forms,
  // IdeIntf
  SrcEditorIntf, LazIDEIntf, FormEditingIntf, PropEdits, LazLoggerBase,
  // DockedFormEditor
  DockedResizer, DockedSourcePageControl, DockedTools,
  DockedOptionsIDE, DockedDesignForm,
  DockedSourceWindow;

type

  { TDockedTabMaster }

  TDockedTabMaster = class(TIDETabMaster)
  private
    // enable autosizing for docked form editor forms, see issue #32207 - disabled
    // in SourceFileManager per PreventAutoSize
    FAutoSizeControlList: TObjectList;
  protected
    function GetTabDisplayState: TTabDisplayState; override;
    function GetTabDisplayStateEditor(ASourceEditor: TSourceEditorInterface): TTabDisplayState; override;
  public
    constructor Create;
    destructor Destroy; override;
    function  AutoSizeInShowDesigner(AControl: TControl): Boolean; override;
    procedure EnableAutoSizing(AControl: TControl);
    function  GetDesigner(ASourceEditor: TSourceEditorInterface; ATabDisplayState: TTabDisplayState): TIDesigner; override;
    procedure ToggleFormUnit; override;
    procedure JumpToCompilerMessage(ASourceEditor: TSourceEditorInterface); override;
    procedure ShowCode(ASourceEditor: TSourceEditorInterface); override;
    procedure ShowDesigner(ASourceEditor: TSourceEditorInterface; AIndex: Integer = 0); override;
    procedure ShowForm(AForm: TCustomForm); override;
    procedure OptionsModified;
  end;

  { TDockedMainIDE }

  TDockedMainIDE = class(TObject)
  public
    class function GetCurrentPageControl: TSourcePageControl;

    class procedure Screen_FormAdded(Sender: TObject; AForm: TCustomForm);
    class procedure Screen_FormDel(Sender: TObject; AForm: TCustomForm);

    class procedure WindowCreate(Sender: TObject);
    class procedure WindowDestroy(Sender: TObject);
    class procedure WindowHide(Sender: TObject);
    class procedure WindowShow(Sender: TObject);

    class procedure EditorActivated(Sender: TObject);
    class procedure EditorCreate(Sender: TObject);
    class procedure EditorDestroyed(Sender: TObject);

    class procedure TabChange(Sender: TObject);

    class procedure GlobalSNOnChangeBounds(Sender: TObject);
    class procedure OnShowDesignerForm(Sender: TObject; {%H-}AEditor: TSourceEditorInterface;
                      AComponentPaletteClassSelected: Boolean);
    class procedure OnShowSrcEditor(Sender: TObject);

    class procedure OnDesignShowMethod(const Name: String);
    class procedure OnDesignRefreshPropertyValues;
    class procedure OnDesignModified(Sender: TObject);
    class procedure OnDesignPersistentAdded({%H-}APersistent: TPersistent; {%H-}Select: Boolean);
    class procedure OnDesignPersistentDeleted({%H-}APersistent: TPersistent);
    class procedure OnDesignMouseDown(Sender: TObject; {%H-}Button: TMouseButton;
                      {%H-}Shift: TShiftState; {%H-}X, {%H-}Y: Integer);
    class procedure OnDesignSetSelection(const ASelection: TPersistentSelectionList);
  end;

var
  DockedTabMaster: TDockedTabMaster absolute IDETabMaster;

implementation

{ TDockedTabMaster }

function TDockedTabMaster.GetTabDisplayState: TTabDisplayState;
begin
  Result := GetTabDisplayStateEditor(SourceEditorManagerIntf.ActiveEditor);
end;

function TDockedTabMaster.GetTabDisplayStateEditor(ASourceEditor: TSourceEditorInterface): TTabDisplayState;
var
  LPageCtrl: TSourcePageControl;
begin
  if ASourceEditor = nil then Exit(tdsNone);
  LPageCtrl := SourceWindows.FindPageControl(ASourceEditor);
  if LPageCtrl = nil then Exit(tdsNone);
  Result := LPageCtrl.ActiveTabDisplayState;
end;

constructor TDockedTabMaster.Create;
begin
  FAutoSizeControlList := TObjectList.Create(False);
end;

destructor TDockedTabMaster.Destroy;
begin
  FAutoSizeControlList.Free;
  inherited Destroy;
end;

function TDockedTabMaster.AutoSizeInShowDesigner(AControl: TControl): Boolean;
begin
  // enable autosizing for docked form editor forms, see issue #32207 - disabled
  // in SourceFileManager per PreventAutoSize
  FAutoSizeControlList.Add(AControl);
  Result := True;
end;

procedure TDockedTabMaster.EnableAutoSizing(AControl: TControl);
var
  AIndex: Integer;
  AutoSizeControl: TControl;
begin
  // enable autosizing for docked form editor forms, see issue #32207 - disabled
  // in SourceFileManager per PreventAutoSize
  {$IFDEF DEBUGDOCKEDFORMEDITOR} DebugLn('TDockedTabMaster.EnableAutoSizing: ', DbgSName(AControl)); {$ENDIF}
  if not Assigned(AControl) then Exit;
  AutoSizeControl := nil;

  if AControl is TNonFormProxyDesignerForm then
  begin
    if (TNonFormProxyDesignerForm(AControl).LookupRoot is TControl) then
      AutoSizeControl := TControl(TNonFormProxyDesignerForm(AControl).LookupRoot);
  end else
    AutoSizeControl := AControl;

  AIndex := FAutoSizeControlList.IndexOf(AutoSizeControl);
  if (AIndex >= 0) then
  begin
    FAutoSizeControlList.Delete(AIndex);
    AutoSizeControl.EnableAutoSizing{$IFDEF DebugDisableAutoSizing}('TAnchorDockMaster Delayed'){$ENDIF};
  end;
end;

function TDockedTabMaster.GetDesigner(ASourceEditor: TSourceEditorInterface; ATabDisplayState: TTabDisplayState): TIDesigner;
var
  LPageCtrl: TSourcePageControl;
begin
  if ASourceEditor = nil then Exit(nil);
  LPageCtrl := SourceWindows.FindPageControl(ASourceEditor);
  if LPageCtrl = nil then Exit(nil);
  if LPageCtrl.DesignForm = nil then Exit(nil);
  case ATabDisplayState of
    tdsDesign:
      Result := LPageCtrl.DesignForm.Designer;
    tdsOther:
      Result := LPageCtrl.DesignForm.AnchorDesigner;
    else
      Result := nil;
  end;
end;

procedure TDockedTabMaster.ToggleFormUnit;
begin
  {$IFDEF DEBUGDOCKEDFORMEDITOR} DebugLn('TDockedTabMaster.ToggleFormUnit'); {$ENDIF}
  case TabDisplayState of
    tdsCode:
      ShowDesigner(SourceEditorManagerIntf.ActiveEditor);
    else
      ShowCode(SourceEditorManagerIntf.ActiveEditor);
  end;
end;

procedure TDockedTabMaster.JumpToCompilerMessage(
  ASourceEditor: TSourceEditorInterface);
begin
  {$IFDEF DEBUGDOCKEDFORMEDITOR} DebugLn('TDockedTabMaster.JumpToCompilerMessage'); {$ENDIF}
  SourceEditorManagerIntf.ActiveEditor := ASourceEditor;
  ShowCode(ASourceEditor);
end;

procedure TDockedTabMaster.ShowCode(ASourceEditor: TSourceEditorInterface);
var
  LPageCtrl: TSourcePageControl;
begin
  {$IFDEF DEBUGDOCKEDFORMEDITOR} DebugLn('TDockedTabMaster.ShowCode'); {$ENDIF}
  if ASourceEditor = nil then Exit;
  LPageCtrl := SourceWindows.FindPageControl(ASourceEditor);
  LPageCtrl.ShowCode;
  ASourceEditor.EditorControl.SetFocus;
end;

procedure TDockedTabMaster.ShowDesigner(ASourceEditor: TSourceEditorInterface; AIndex: Integer);
var
  LPageCtrl: TSourcePageControl;
begin
  {$IFDEF DEBUGDOCKEDFORMEDITOR} DebugLn('TDockedTabMaster.ShowDesigner'); {$ENDIF}
  if ASourceEditor = nil then Exit;
  LPageCtrl := SourceWindows.FindPageControl(ASourceEditor);
  LPageCtrl.ShowDesigner(AIndex);
end;

procedure TDockedTabMaster.ShowForm(AForm: TCustomForm);
var
  LEditor: TSourceEditorInterface;
begin
  {$IFDEF DEBUGDOCKEDFORMEDITOR} DebugLn('TDockedTabMaster.ShowForm'); {$ENDIF}
  LEditor := FindSourceEditorForDesigner(AForm.Designer);
  SourceEditorManagerIntf.ActiveEditor := LEditor;
  ShowDesigner(LEditor);
end;

procedure TDockedTabMaster.OptionsModified;
var
  LPageCtrl: TSourcePageControl;
begin
  LPageCtrl := SourceWindows.LastActivePageControl;
  DesignForms.RemoveAllAnchorDesigner;
  SourceWindows.ShowCodeTabSkipCurrent(nil, nil);
  SourceWindows.RefreshAllPageControls;
  TDockedMainIDE.EditorActivated(SourceWindows.LastActiveSourceEditor);
  LPageCtrl.OnChange(LPageCtrl);
end;

{ TDockedMainIDE }

class function TDockedMainIDE.GetCurrentPageControl: TSourcePageControl;
var
  LForm: TCustomForm;
  LDesignForm: TDesignForm;
  LSourceWindowIntf: TSourceEditorWindowInterface;
begin
  Result := nil;
  if (FormEditingHook = nil) or (GlobalDesignHook = nil) then Exit;
  LForm := FormEditingHook.GetDesignerForm(GlobalDesignHook.LookupRoot);
  LDesignForm := DesignForms.Find(LForm);
  if LDesignForm = nil then Exit;
  LSourceWindowIntf := LDesignForm.LastActiveSourceWindow;
  if not Assigned(LSourceWindowIntf) then Exit;
  Result := SourceWindows.FindPageControl(LSourceWindowIntf.ActiveEditor);
end;

class procedure TDockedMainIDE.Screen_FormAdded(Sender: TObject; AForm: TCustomForm);
var
  LSourceEditor: TSourceEditorInterface;
  LDesignForm: TDesignForm;
  LPageCtrl: TSourcePageControl;
begin
  if IsFormDesign(AForm) then
  begin
    {$IFDEF DEBUGDOCKEDFORMEDITOR} DebugLn('TDockedMainIDE.Screen_FormAdded ', DbgSName(AForm)); {$ENDIF}

    // AForm like TForm1 etc...
    if not (csDesignInstance in AForm.ComponentState) and not (AForm is TNonFormProxyDesignerForm) then
      Exit;

    LDesignForm := TDesignForm.Create(AForm);
    LDesignForm.Hiding := True;
    DesignForms.Add(LDesignForm);
    LSourceEditor := FindSourceEditorForDesigner(AForm.Designer);
    if LSourceEditor <> nil then
    begin
      LPageCtrl := SourceWindows.FindPageControl(LSourceEditor);
      if LPageCtrl <> nil then
      begin
        LPageCtrl.DesignForm := LDesignForm;
        LPageCtrl.CreateTabSheetDesigner;
        if LDesignForm.IsAnchorDesign then
          LPageCtrl.CreateTabSheetAnchors;
      end;
    end;
    SetTimer(AForm.Handle, WM_SETNOFRAME, 10, nil);
  end else begin
    if AForm is TSourceEditorWindowInterface then
      AForm.AddHandlerOnChangeBounds(@GlobalSNOnChangeBounds);
  end;
end;

class procedure TDockedMainIDE.Screen_FormDel(Sender: TObject; AForm: TCustomForm);
var
  LSourceWindow: TSourceWindow;
  LPageCtrl: TSourcePageControl;
begin
  if IsFormDesign(AForm) then
  begin
    {$IFDEF DEBUGDOCKEDFORMEDITOR} DebugLn('TDockedMainIDE.Screen_FormDel ', DbgSName(AForm)); {$ENDIF}
    AForm.Parent := nil;

    for LSourceWindow in SourceWindows do
    begin
      if LSourceWindow.ActiveDesignForm <> nil then
        if LSourceWindow.ActiveDesignForm.Form = AForm then
          // don't set ActiveDesignForm := nil! we can't call OnChange tab, because tab don't exist anymore
          LSourceWindow.RemoveActiveDesignForm;

      for LPageCtrl in LSourceWindow.PageControlList do
        if LPageCtrl.DesignForm <> nil then
          if LPageCtrl.DesignForm.Form = AForm then
          begin
            LPageCtrl.DesignForm := nil;
            LPageCtrl.PageIndex := 0;
          end;
    end;
    DesignForms.Remove(AForm);
  end
  else
    if AForm is TSourceEditorWindowInterface then
      AForm.RemoveHandlerOnChangeBounds(@GlobalSNOnChangeBounds);
end;

class procedure TDockedMainIDE.WindowCreate(Sender: TObject);
var
  LSourceWindowIntf: TSourceEditorWindowInterface;
begin
  if not (Sender is TSourceEditorWindowInterface) then Exit;
  if Sender.ClassNameIs('TSourceNotebook') then
  begin
    {$IFDEF DEBUGDOCKEDFORMEDITOR} DebugLn('TDockedMainIDE.WindowCreate SourceEditor created'); {$ENDIF}
    LSourceWindowIntf := Sender as TSourceEditorWindowInterface;
    SourceWindows.Add(TSourceWindow.Create(LSourceWindowIntf));
  end;
end;

class procedure TDockedMainIDE.WindowDestroy(Sender: TObject);
var
  LDesignForm: TDesignForm;
begin
  if not (Sender is TSourceEditorWindowInterface) then Exit;
  {$IFDEF DEBUGDOCKEDFORMEDITOR} DebugLn('TDockedMainIDE.WindowDestroy'); {$ENDIF}
  for LDesignForm in DesignForms do
    if LDesignForm.LastActiveSourceWindow = Sender then
      LDesignForm.LastActiveSourceWindow := nil;
  SourceWindows.Remove(Sender as TSourceEditorWindowInterface);
end;

class procedure TDockedMainIDE.WindowHide(Sender: TObject);
var
  LSourceWindow: TSourceWindow;
  LDesignForm: TDesignForm;
begin
  {$IFDEF DEBUGDOCKEDFORMEDITOR} DebugLn('TDockedMainIDE.WindowHide'); {$ENDIF}
  LSourceWindow := SourceWindows.SourceWindow[Sender as TSourceEditorWindowInterface];
  if not Assigned(LSourceWindow) or (LSourceWindow.ActiveDesignForm = nil) then
    Exit;
  LDesignForm := LSourceWindow.ActiveDesignForm;
  LDesignForm.HideWindow;
end;

class procedure TDockedMainIDE.WindowShow(Sender: TObject);
var
  LSourceWindow: TSourceWindow;
  LDesignForm: TDesignForm;
begin
  {$IFDEF DEBUGDOCKEDFORMEDITOR} DebugLn('TDockedMainIDE.WindowShow'); {$ENDIF}
  LSourceWindow := SourceWindows.SourceWindow[Sender as TSourceEditorWindowInterface];
  if not Assigned(LSourceWindow) or (LSourceWindow.ActiveDesignForm = nil) then
    Exit;
  LDesignForm := LSourceWindow.ActiveDesignForm;
  LDesignForm.ShowWindow;
end;

class procedure TDockedMainIDE.EditorActivated(Sender: TObject);
var
  LDesigner: TIDesigner;
  LSourceEditor: TSourceEditorInterface;
var
  LPageCtrl: TSourcePageControl;
  LSourceWindowIntf: TSourceEditorWindowInterface;
  LDesignForm: TDesignForm;
begin
  if Sender is TSourceEditorInterface then
  begin
    LSourceEditor := TSourceEditorInterface(Sender);
    {$IFDEF DEBUGDOCKEDFORMEDITOR}
      DebugLn('TDockedMainIDE.EditorActivated [' + LSourceEditor.PageCaption +
              '] SourceWindow[' + SourceWindowCaption(LSourceEditor) + ']');
    {$ENDIF}
    // if we create directly new project then Activate is called without EditorCreate...
    if not (LSourceEditor.EditorControl.Parent.Parent is TSourcePageControl) then
    begin
      // possible is situation when we moved tab into other window
      // then was not called event EditorDestroy - that generates problems with switching tabs
      // or when we moving tab to first window ( then is raising : duplicates not allowed in dictionary).
      if SourceWindows.LastSourceEditorNotFound then
        EditorDestroyed(nil);
      EditorCreate(Sender);
    end;
    LDesigner := LSourceEditor.GetDesigner(True);
    // should be performed during EditorCreate (parent of parent is SourcePageControl)
    LPageCtrl := TSourcePageControl(LSourceEditor.EditorControl.Parent.Parent);
    if LPageCtrl = nil then Exit;

    LDesignForm := SourceWindows.FindDesignForm(LPageCtrl);
    if LDesigner = nil then
      LPageCtrl.RemoveDesignPages
    else begin
      if not Assigned(LPageCtrl.Resizer) then
        LPageCtrl.CreateResizer;
      LPageCtrl.CreateTabSheetDesigner;
      if LDesignForm.IsAnchorDesign then
        LPageCtrl.CreateTabSheetAnchors;
    end;

    LSourceWindowIntf := TSourceEditorWindowInterface(LPageCtrl.Owner);
    SourceWindows.LastActiveSourceWindow := LSourceWindowIntf;
    SourceWindows.LastActiveSourceEditor := LSourceEditor;

    // when we switch tab, design form should be hidden
    if (LDesigner = nil) or (LDesignForm = nil) then
      SourceWindows.SourceWindow[LSourceWindowIntf].ActiveDesignForm := nil
    else begin
      // during form  loading for example from package, ActiveDesignForm assignment,
      // blocks the message queue responsible for hiding form
      // We can't check it because there are some forms where designing is not handled yet.
      // (for that kind of forms is returned empty designform data)
      // maybe we can fix this in future
      if not LDesignForm.Hiding then
        // Prevent unexpected events (when is deactivated some control outside designed form)
        if (LDesignForm.LastActiveSourceWindow = LSourceWindowIntf)
        // important!!! for many error - switching between editors...
        and LPageCtrl.DesignerPageActive then
          SourceWindows.SourceWindow[LSourceWindowIntf].ActiveDesignForm := LDesignForm
        else
          SourceWindows.SourceWindow[LSourceWindowIntf].ActiveDesignForm := nil;
    end;

    if LPageCtrl.DesignerPageActive then
    begin
      if not LDesignForm.Hiding then
      begin
        SourceWindows.ShowCodeTabSkipCurrent(LPageCtrl, LDesignForm);
        LPageCtrl.AdjustPage;
        // don't focus designer here, focus can be on ObjectInspector, then
        // <Del> in OI Events deletes component instead event handler
      end;
    end else begin
      if LDesignForm <> nil then
        LDesignForm.HideWindow;
      LPageCtrl.InitPage;
    end;
  end else begin
    {$IFDEF DEBUGDOCKEDFORMEDITOR} DebugLn('TDockedMainIDE.EditorActivated [' + DbgSName(Sender) + '] - not a Source Editor!');{$ENDIF}
  end;
end;

class procedure TDockedMainIDE.EditorCreate(Sender: TObject);
var
  LSourceEditor: TSourceEditorInterface;
  LSourceWindowIntf: TSourceEditorWindowInterface;
  LPageCtrl: TSourcePageControl;
begin
  {$IFDEF DEBUGDOCKEDFORMEDITOR} DebugLn('TDockedMainIDE.EditorCreate'); {$ENDIF}
  LSourceEditor := Sender as TSourceEditorInterface;
  if LSourceEditor.EditorControl.Parent.Parent is TSourcePageControl then Exit;
  LPageCtrl := TSourcePageControl.Create(LSourceEditor);
  LPageCtrl.OnChange := @TabChange;
  LSourceWindowIntf := SourceWindowGet(LSourceEditor);
  SourceWindows.SourceWindow[LSourceWindowIntf].AddPageCtrl(LPageCtrl);
end;

class procedure TDockedMainIDE.EditorDestroyed(Sender: TObject);
var
  LSourceEditor: TSourceEditorInterface;
  LPageCtrl: TSourcePageControl;
  LSourceWindowIntf: TSourceEditorWindowInterface;
  LDesignForm: TDesignForm;
begin
  {$IFDEF DEBUGDOCKEDFORMEDITOR} DebugLn('TDockedMainIDE.EditorDestroyed'); {$ENDIF}
  // sender is here as special parameter, because is possible situation where is moved editor
  // to another window and was not triggered EditorDestroy - for more info goto editoractivate
  if Sender = nil then
    LSourceEditor := SourceWindows.LastActiveSourceEditor
  else
    LSourceEditor := TSourceEditorInterface(Sender);

  // parent don't exist anymore and we must search in each window...
  if Sender = nil then // but not for Sender = nil :P
    LPageCtrl := SourceWindows.LastActivePageControl
  else
    LPageCtrl := SourceWindows.FindPageControl(LSourceEditor);

  if LPageCtrl = nil then Exit;

  LDesignForm := DesignForms.Find(LSourceEditor.GetDesigner(False));

  // goto first comment (forced destroy)
  if Sender = nil then
    LSourceWindowIntf := SourceWindows.LastActiveSourceWindow
  else
    LSourceWindowIntf := TSourceEditorWindowInterface(LPageCtrl.Owner);

  if LDesignForm <> nil then
  begin
    SourceWindows.SourceWindow[LSourceWindowIntf].ActiveDesignForm := nil;
    LDesignForm.LastActiveSourceWindow := nil;
  end;

  SourceWindows.SourceWindow[LSourceWindowIntf].RemovePageCtrl(LSourceEditor);
  LPageCtrl.Free;
end;

class procedure TDockedMainIDE.TabChange(Sender: TObject);
var
  LSourceWindowIntf: TSourceEditorWindowInterface;
  LSourceWindow: TSourceWindow;
  LDesigner: TIDesigner;
  LDesignForm: TDesignForm;
  LPageCtrl: TSourcePageControl;
begin
  {$IFDEF DEBUGDOCKEDFORMEDITOR} DebugLn('TDockedMainIDE.TabChange'); {$ENDIF}
  // activate proper source editor window when user is clicking on page.
  // (at clicking time can be active other source window)
  LSourceWindowIntf := TComponent(Sender).Owner as TSourceEditorWindowInterface;
  if LSourceWindowIntf <> SourceEditorManagerIntf.ActiveSourceWindow then
    SourceEditorManagerIntf.ActiveSourceWindow := LSourceWindowIntf;

  LPageCtrl := TSourcePageControl(Sender);
  if LSourceWindowIntf.ActiveEditor = nil then Exit;
  if LPageCtrl = nil then Exit;

  LDesigner := LSourceWindowIntf.ActiveEditor.GetDesigner(True);
  LDesignForm := DesignForms.Find(LDesigner);
  if LDesignForm = nil then Exit;
  LSourceWindow := SourceWindows.SourceWindow[LSourceWindowIntf];
  if LSourceWindow = nil then Exit;

  if not LPageCtrl.DesignerPageActive then
  begin
    LSourceWindow.ActiveDesignForm := nil;
    LPageCtrl.InitPage;
    LSourceWindowIntf.ActiveEditor.EditorControl.SetFocus;
  end else begin
    LSourceWindow.ActiveDesignForm := LDesignForm;
    // enable autosizing after creating a new form
    DockedTabMaster.EnableAutoSizing(LDesignForm.Form);
    SourceWindows.ShowCodeTabSkipCurrent(LPageCtrl, LDesignForm);
    LPageCtrl.DesignerSetFocus;
  end;
end;

class procedure TDockedMainIDE.GlobalSNOnChangeBounds(Sender: TObject);
var
  LSourceWindowIntf: TSourceEditorWindowInterface;
  LSourceWindow: TSourceWindow;
  LDesignForm: TDesignForm;
  LPageCtrl: TSourcePageControl;
  LResizer: TResizer;
begin
  {$IFDEF DEBUGDOCKEDFORMEDITOR} DebugLn('TDockedMainIDE.GlobalSNOnChangeBounds'); {$ENDIF}
  // Check parent. Maybe is different? If yes then window changed state (docked/undocked) and we need to perform few actions
  LSourceWindowIntf := Sender as TSourceEditorWindowInterface;

  // dock/undock event :)
  LSourceWindow := SourceWindows.SourceWindow[LSourceWindowIntf];
  if LSourceWindow = nil then Exit;
  if LSourceWindow.LastTopParent <> LSourceWindowIntf.GetTopParent then
  begin
    LSourceWindow.LastTopParent := LSourceWindowIntf.GetTopParent;
    // refresh for popupparent
    LDesignForm := LSourceWindow.ActiveDesignForm;
    LSourceWindow.ActiveDesignForm := nil;
    LSourceWindow.ActiveDesignForm := LDesignForm;
    if LDesignForm <> nil then
    begin
      LPageCtrl := SourceWindows.FindPageControl(LSourceWindowIntf.ActiveEditor);
      if not Assigned(LPageCtrl) then Exit;
      LResizer := LPageCtrl.Resizer;
      if not Assigned(LResizer) then Exit;
      LDesignForm.Form.Parent := LResizer.FormContainer;
      SetTimer(LDesignForm.Form.Handle, WM_BOUNDTODESIGNTABSHEET, 10, nil);
    end;
  end;
end;

class procedure TDockedMainIDE.OnShowDesignerForm(Sender: TObject; AEditor: TSourceEditorInterface;
  AComponentPaletteClassSelected: Boolean);
var
  LDesignForm: TDesignForm;
  LPageCtrl: TSourcePageControl;
  LSourceWindow: TSourceWindow;
  LSourceEditorInterface: TSourceEditorInterface;
begin
  {$IFDEF DEBUGDOCKEDFORMEDITOR} DebugLn('TDockedMainIDE.OnShowDesignerForm'); {$ENDIF}
  LDesignForm := DesignForms.Find(TCustomForm(Sender).Designer);
  if (LDesignForm = nil) or LDesignForm.Hiding then Exit;
  LPageCtrl := SourceWindows.FindPageControl(SourceEditorManagerIntf.ActiveEditor);
  if LPageCtrl = nil then Exit;

  if AComponentPaletteClassSelected then
  begin
    // if form is already opened do nothing, if not then show form
    for LSourceWindow in SourceWindows do
    begin
      LSourceEditorInterface := LSourceWindow.SourceWindowIntf.ActiveEditor;
      if (LSourceEditorInterface = nil) or (LSourceEditorInterface.GetDesigner(True) <> LDesignForm.Designer) then
        Continue;
      LPageCtrl := SourceWindows.FindPageControl(LSourceEditorInterface);
      if LPageCtrl.FormPageActive then
        Exit;
    end;
  end;
  DockedTabMaster.ShowDesigner(SourceEditorManagerIntf.ActiveEditor);
end;

class procedure TDockedMainIDE.OnShowSrcEditor(Sender: TObject);
begin
  {$IFDEF DEBUGDOCKEDFORMEDITOR} DebugLn('TDockedMainIDE.OnShowSrcEditor'); {$ENDIF}
  DockedTabMaster.ShowCode(Sender as TSourceEditorInterface);
end;

class procedure TDockedMainIDE.OnDesignShowMethod(const Name: String);
var
  LDesignForm: TDesignForm;
  LSecondEditor: TSourceEditorInterface = nil;
  LSourceWindowIntf: TSourceEditorWindowInterface;
  i: Integer;
begin
  {$IFDEF DEBUGDOCKEDFORMEDITOR} DebugLn('TDockedMainIDE.OnDesignShowMethod'); {$ENDIF}
  if FormEditingHook = nil then Exit;
  LDesignForm := DesignForms.Find(FormEditingHook.GetCurrentDesigner);
  if LDesignForm = nil then Exit;
  for i := 0 to SourceEditorManagerIntf.SourceWindowCount - 1 do
  begin
    LSourceWindowIntf := SourceEditorManagerIntf.SourceWindows[i];
    if LDesignForm.LastActiveSourceWindow = LSourceWindowIntf then
      Continue;
    if LSourceWindowIntf.ActiveEditor <> nil then
      if LSourceWindowIntf.ActiveEditor.GetDesigner(True) = LDesignForm.Designer then
      begin
        LSecondEditor := LSourceWindowIntf.ActiveEditor;
        Break;
      end;
  end;

  if Assigned(LSecondEditor) then
  begin
    DockedTabMaster.ShowCode(LSecondEditor);
    LazarusIDE.DoShowMethod(LSecondEditor, Name);
  end else
    if Assigned(LDesignForm.LastActiveSourceWindow) then
      DockedTabMaster.ShowCode(LDesignForm.LastActiveSourceWindow.ActiveEditor);
end;

class procedure TDockedMainIDE.OnDesignRefreshPropertyValues;
var
  LPageCtrl: TSourcePageControl;

  function RootIsSelected: Boolean;
  var
    LSelection: TPersistentSelectionList;
    i: Integer;
  begin
    Result := False;
    LSelection := TPersistentSelectionList.Create;
    try
      GlobalDesignHook.GetSelection(LSelection);
      for i := 0 to LSelection.Count - 1 do
        if LSelection.Items[i] = GlobalDesignHook.LookupRoot then
        begin
          Result := True;
          Break;
        end;
    finally
      LSelection.Free;
    end;
  end;

begin
  {$IFDEF DEBUGDOCKEDFORMEDITOR} DebugLn('TDockedMainIDE.OnDesignRefreshPropertyValues'); {$ENDIF}
  if not (GlobalDesignHook.LookupRoot is TCustomFrame)
  and not (GlobalDesignHook.LookupRoot is TCustomForm) then Exit;

  LPageCtrl := GetCurrentPageControl;
  if not Assigned(LPageCtrl) then Exit;
  if not ((LPageCtrl.PageIndex = 2) or RootIsSelected) then Exit;
  LPageCtrl.AdjustPage;
end;

class procedure TDockedMainIDE.OnDesignModified(Sender: TObject);
var
  LPageCtrl: TSourcePageControl;
begin
  {$IFDEF DEBUGDOCKEDFORMEDITOR} DebugLn('TDockedMainIDE.OnDesignModified'); {$ENDIF}
  LPageCtrl := GetCurrentPageControl;
  if not Assigned(LPageCtrl) then Exit;
  if not Assigned(LPageCtrl.Resizer) then Exit;
  LPageCtrl.Resizer.ResizeControl.OnModified;
end;

class procedure TDockedMainIDE.OnDesignPersistentAdded(APersistent: TPersistent; Select: Boolean);
begin
  {$IFDEF DEBUGDOCKEDFORMEDITOR} DebugLn('TDockedMainIDE.OnDesignPersistentAdded'); {$ENDIF}
  OnDesignModified(nil);
end;

class procedure TDockedMainIDE.OnDesignPersistentDeleted(APersistent: TPersistent);
begin
  {$IFDEF DEBUGDOCKEDFORMEDITOR} DebugLn('TDockedMainIDE.OnDesignPersistentDeleted'); {$ENDIF}
  OnDesignModified(nil);
end;

class procedure TDockedMainIDE.OnDesignMouseDown(Sender: TObject;
  Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  LPageCtrl: TSourcePageControl;
begin
  {$IFDEF DEBUGDOCKEDFORMEDITOR} writeln('TDockedMainIDE.OnDesignMouseDown'); {$ENDIF}
  LPageCtrl := GetCurrentPageControl;
  if not Assigned(LPageCtrl) then Exit;
  LPageCtrl.DesignerSetFocus;
end;

class procedure TDockedMainIDE.OnDesignSetSelection(
  const ASelection: TPersistentSelectionList);
var
  LDesignForm: TDesignForm;
  LSelectedControl: TControl;
begin
  {$IFDEF DEBUGDOCKEDFORMEDITOR} DebugLn('TDockedMainIDE.OnDesignSetSelection'); {$ENDIF}
  LDesignForm := DesignForms.Find(FormEditingHook.GetCurrentDesigner);
  if LDesignForm = nil then Exit;
  if (ASelection.Count = 1) and (ASelection[0] is TControl) then
    LSelectedControl := TControl(ASelection[0]);
  if LSelectedControl = LDesignForm.SelectedControl then Exit;
  LDesignForm.SelectedControl := LSelectedControl;
  OnDesignModified(nil);
end;

end.


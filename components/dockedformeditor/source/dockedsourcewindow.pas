{
 *****************************************************************************
  See the file COPYING.modifiedLGPL.txt, included in this distribution,
  for details about the license.
 *****************************************************************************

 Authors: Maciej Izak
          Michael W. Vogel

 This is the access to one SourceEditor window. There can be more then just one
 (that list is SourceWindows).
 Each SourceEditor window can hold a lot of units, forms etc. available per
 SourceEditorWindowInterface in PageControlList.

}

unit DockedSourceWindow;

{$mode objfpc}{$H+}
{$modeswitch advancedrecords}
{$modeswitch typehelpers}

{ $define DEBUGDOCKEDFORMEDITOR}

interface

uses
  // RTL
  Classes, SysUtils, fgl,
  // LCL
  Forms, Controls, LCLProc,
  // IDEIntf
  SrcEditorIntf, LazIDEIntf, FormEditingIntf, ExtendedNotebook,
  // DockedFormEditor
  DockedDesignForm, DockedSourcePageControl,
  DockedOptionsIDE, DockedTools;

type

  { TSourceWindow }

  TSourceWindow = class
  private
    FActiveDesignForm: TDesignForm;
    FDefaultNotebookPageChanged: TNotifyEvent;
    FLastActiveSourceEditor: TSourceEditorInterface;
    FLastTopParent: TControl;
    FNotebook: TExtendedNotebook;
    FPageControlList: TSourcePageControls;
    FSourceWindowIntf: TSourceEditorWindowInterface;
    function GetActiveEditor: TSourceEditorInterface;
    procedure HookIntoOnPageChanged;
    procedure NoteBookPageChanged(Sender: TObject);
    procedure SetActiveDesignForm(const AValue: TDesignForm);
    procedure UpdateEditorPageCaption(Sender: TObject);
  public
    constructor Create(ASourceWindowIntf: TSourceEditorWindowInterface);
    destructor Destroy; override;
    procedure AddPageCtrl(APageControl: TSourcePageControl);
    procedure AdjustPageControl;
    function  FindPageControl(ASourceEditor: TSourceEditorInterface): TSourcePageControl;
    procedure RemoveActiveDesignForm;
    procedure RemovePageCtrl(ASourceEditor: TSourceEditorInterface);
  public
    property ActiveDesignForm: TDesignForm read FActiveDesignForm write SetActiveDesignForm;
    property ActiveEditor: TSourceEditorInterface read GetActiveEditor;
    property LastActiveSourceEditor: TSourceEditorInterface read FLastActiveSourceEditor write FLastActiveSourceEditor;
    property LastTopParent: TControl read FLastTopParent write FLastTopParent;
    property PageControlList: TSourcePageControls read FPageControlList;
    property SourceWindowIntf: TSourceEditorWindowInterface read FSourceWindowIntf;
  end;

  { TSourceWindows }

  TSourceWindows = class(specialize TFPGList<TSourceWindow>)
  private
    FLastActiveSourceWindow: TSourceEditorWindowInterface;
    function GetLastActivePageControl: TSourcePageControl;
    function GetLastActiveSourceEditor: TSourceEditorInterface;
    function GetSourceWindowIntf(ASrcEditor: TSourceWindow): TSourceEditorWindowInterface;
    function GetSourceWindow(ASourceWindowIntf: TSourceEditorWindowInterface): TSourceWindow;
    procedure SetLastActiveSourceEditor(AValue: TSourceEditorInterface);
  public
    constructor CreateNew;
    destructor Destroy; override;
    function  Contains(ASourceWindowIntf: TSourceEditorWindowInterface): Boolean;
    function  Contains(ASrcEditor: TSourceWindow): Boolean;
    procedure DeleteItem(Index: Integer);
    function  FindDesignForm(APageCtrl: TSourcePageControl): TDesignForm;
    function  FindPageControl(ASrcEditor: TSourceEditorInterface): TSourcePageControl;
    function  IndexOf(ASourceWindowIntf: TSourceEditorWindowInterface): Integer; overload;
    function  LastSourceEditorNotFound: Boolean;
    procedure RefreshActivePageControls;
    procedure RefreshAllPageControls;
    procedure Remove(ASourceWindowIntf: TSourceEditorWindowInterface); overload;
    procedure ShowCodeTabSkipCurrent(CurrentPageCtrl: TSourcePageControl; ADesignForm: TDesignForm);
  public
    property LastActiveSourceWindow: TSourceEditorWindowInterface read FLastActiveSourceWindow write FLastActiveSourceWindow;
    property LastActiveSourceEditor: TSourceEditorInterface read GetLastActiveSourceEditor write SetLastActiveSourceEditor;
    property LastActivePageControl: TSourcePageControl read GetLastActivePageControl;
    property SourceWindowIntf[ASrcEditor: TSourceWindow]: TSourceEditorWindowInterface read GetSourceWindowIntf;
    property SourceWindow[ASourceWindowIntf: TSourceEditorWindowInterface]: TSourceWindow read GetSourceWindow;
  end;

var
  SourceWindows: TSourceWindows;

implementation

{ TSourceWindow }

procedure TSourceWindow.HookIntoOnPageChanged;
var
  i: Integer;
begin
  for i := 0 to FSourceWindowIntf.ControlCount - 1 do
    if FSourceWindowIntf.Controls[i] is TExtendedNotebook then
    begin
      FNotebook := TExtendedNotebook(FSourceWindowIntf.Controls[i]);
      Break;
    end;
  if not Assigned(FNotebook) then Exit;
  FDefaultNotebookPageChanged := FNotebook.OnChange;
  FNotebook.OnChange := @NoteBookPageChanged;
end;

procedure TSourceWindow.NoteBookPageChanged(Sender: TObject);
var
  LPageCtrl: TSourcePageControl;
begin
  {$IFDEF DEBUGDOCKEDFORMEDITOR} DebugLn('TSourceWindow.NoteBookPageChanged SourceWindow[' + FSourceWindowIntf.Caption + ']'); {$ENDIF}
  FDefaultNotebookPageChanged(Sender);
  LPageCtrl := FindPageControl(ActiveEditor);
  if not Assigned(LPageCtrl) then Exit;
  if LPageCtrl.DesignerPageActive then
  begin
    LPageCtrl.AdjustPage;
    {$IF DEFINED(LCLGtk2)}
      LPageCtrl.DesignerSetFocusAsync;
    {$ELSE}
      LPageCtrl.DesignerSetFocus;
    {$ENDIF}
  end;
end;

function TSourceWindow.GetActiveEditor: TSourceEditorInterface;
begin
  Result := FSourceWindowIntf.ActiveEditor;
end;

procedure TSourceWindow.SetActiveDesignForm(const AValue: TDesignForm);
var
  LPageCtrl: TSourcePageControl;
begin
  if FActiveDesignForm = AValue then Exit;
  if FActiveDesignForm <> nil then
    // don't hide now if soon form will be hidden (for example on the IDE start)
    if not FActiveDesignForm.Hiding then
      FActiveDesignForm.HideWindow;
  FActiveDesignForm := AValue;

  LPageCtrl := FindPageControl(ActiveEditor);
  // important when we want back to tab where was oppened form
  if (AValue <> nil) then
    LazarusIDE.DoShowDesignerFormOfSrc(ActiveEditor);

  if LPageCtrl = nil then Exit;
  LPageCtrl.DesignForm := AValue;
end;

procedure TSourceWindow.UpdateEditorPageCaption(Sender: TObject);
var
  LSourceEditor: TSourceEditorInterface;
  LSourceWindowIntf: TSourceEditorWindowInterface;
begin
  // if a unit is cloned to undocked empty source editor window, the SourcePageControl
  // is not created, the only workaround I found is, to activate the new created
  // source editor in this window
  if not (Sender is TSourceEditorInterface) then Exit;
  if SourceEditorManagerIntf.ActiveSourceWindow = nil then Exit;
  LSourceEditor := TSourceEditorInterface(Sender);
  {$IFDEF DEBUGDOCKEDFORMEDITOR} DebugLn('TSourceWindow.UpdateEditorPageCaption [' + SourceWindowCaption(LSourceEditor) + ']'); {$ENDIF}
  LSourceWindowIntf := SourceWindowGet(LSourceEditor);
  if not Assigned(LSourceWindowIntf)
  or (SourceEditorManagerIntf.ActiveSourceWindow = LSourceWindowIntf)
  or (SourceWindows.LastActiveSourceWindow = LSourceWindowIntf)
  then
    Exit;
  LSourceWindowIntf.ActiveEditor := LSourceEditor;
end;

constructor TSourceWindow.Create(ASourceWindowIntf: TSourceEditorWindowInterface);
begin
  FLastActiveSourceEditor := nil;
  FSourceWindowIntf := ASourceWindowIntf;
  FPageControlList := TSourcePageControls.Create;
  FNotebook := nil;
  HookIntoOnPageChanged;
  FSourceWindowIntf.AddUpdateEditorPageCaptionHandler(@UpdateEditorPageCaption);
end;

destructor TSourceWindow.Destroy;
begin
  if Assigned(FNotebook) then
    FNotebook.OnChange := FDefaultNotebookPageChanged;
  FPageControlList.Free;
  inherited Destroy;
end;

procedure TSourceWindow.AddPageCtrl(APageControl: TSourcePageControl);
begin
  FPageControlList.Add(APageControl);
end;

procedure TSourceWindow.AdjustPageControl;
var
  LPageCtrl: TSourcePageControl;
begin
  LPageCtrl := FindPageControl(ActiveEditor);
  if LPageCtrl <> nil then
    LPageCtrl.AdjustPage;
end;

function TSourceWindow.FindPageControl(ASourceEditor: TSourceEditorInterface): TSourcePageControl;
var
  LParent: TWinControl;
begin
  if ASourceEditor = nil then
    Exit(nil);
  LParent := ASourceEditor.EditorControl.Parent;
  while LParent <> nil do
  begin
    if LParent is TSourcePageControl then
      Exit(TSourcePageControl(LParent));
    LParent := LParent.Parent;
  end;
  Result := nil;
end;

procedure TSourceWindow.RemoveActiveDesignForm;
begin
  FActiveDesignForm := nil;
end;

procedure TSourceWindow.RemovePageCtrl(ASourceEditor: TSourceEditorInterface);
begin
  FPageControlList.Remove(ASourceEditor);
  if LastActiveSourceEditor = ASourceEditor then
    LastActiveSourceEditor := nil;
end;

{ TSourceWindows }

function TSourceWindows.GetSourceWindowIntf(ASrcEditor: TSourceWindow): TSourceEditorWindowInterface;
var
  LIndex: Integer;
begin
  LIndex := IndexOf(ASrcEditor);
  if LIndex >= 0 then
    Result := Items[LIndex].SourceWindowIntf
  else
    Result := nil;
end;

function TSourceWindows.GetLastActivePageControl: TSourcePageControl;
begin
  Result := FindPageControl(LastActiveSourceEditor);
end;

function TSourceWindows.GetLastActiveSourceEditor: TSourceEditorInterface;
var
  LSourceWindow: TSourceWindow;
begin
  Result := nil;
  if not Assigned(LastActiveSourceWindow) then Exit;
  LSourceWindow := SourceWindow[LastActiveSourceWindow];
  if not Assigned(LSourceWindow) then Exit;
  Result := LSourceWindow.LastActiveSourceEditor;
end;

function TSourceWindows.GetSourceWindow(ASourceWindowIntf: TSourceEditorWindowInterface): TSourceWindow;
var
  LIndex: Integer;
begin
  LIndex := IndexOf(ASourceWindowIntf);
  if LIndex >= 0 then
    Result := Items[LIndex]
  else
    Result := nil;
end;

procedure TSourceWindows.SetLastActiveSourceEditor(AValue: TSourceEditorInterface);
var
  LSourceWindow: TSourceWindow;
begin
  if not Assigned(LastActiveSourceWindow) then Exit;
  LSourceWindow := SourceWindow[LastActiveSourceWindow];
  if not Assigned(LSourceWindow) then Exit;
  LSourceWindow.LastActiveSourceEditor := AValue;
end;

constructor TSourceWindows.CreateNew;
begin
  inherited Create;
  FLastActiveSourceWindow := nil;
end;

destructor TSourceWindows.Destroy;
begin
  while Count > 0 do
    DeleteItem(0);
  inherited Destroy;
end;

function TSourceWindows.Contains(ASourceWindowIntf: TSourceEditorWindowInterface): Boolean;
begin
  Result := IndexOf(ASourceWindowIntf) >= 0;
end;

function TSourceWindows.Contains(ASrcEditor: TSourceWindow): Boolean;
begin
  Result := IndexOf(ASrcEditor) >= 0;
end;

procedure TSourceWindows.DeleteItem(Index: Integer);
var
  LSourceWindow: TSourceWindow;
begin
  LSourceWindow := Items[Index];
  LSourceWindow.Free;
  Delete(Index);
end;

function TSourceWindows.FindDesignForm(APageCtrl: TSourcePageControl): TDesignForm;
var
  LSourceWindow: TSourceWindow;
  LSourceEditorInterface: TSourceEditorInterface;
begin
  Result := nil;
  if APageCtrl = nil then Exit;
  for LSourceWindow in Self do
  begin
    if APageCtrl.Owner = LSourceWindow.SourceWindowIntf then
    begin
      LSourceEditorInterface := LSourceWindow.ActiveEditor;
      if LSourceEditorInterface = nil then Exit;
      Result := DesignForms.Find(LSourceEditorInterface.GetDesigner(True));
      Exit;
    end;
  end;
end;

function TSourceWindows.FindPageControl(ASrcEditor: TSourceEditorInterface): TSourcePageControl;
var
  LSourceWindow: TSourceWindow;
begin
  Result := nil;
  for LSourceWindow in Self do
    if LSourceWindow.PageControlList.Contains(ASrcEditor) then
      Exit(LSourceWindow.PageControlList.PageControl[ASrcEditor]);
end;

function TSourceWindows.IndexOf(ASourceWindowIntf: TSourceEditorWindowInterface): Integer;
var
  i: Integer;
begin
  Result := -1;
  for i := 0 to Count - 1 do
    if Items[i].SourceWindowIntf = ASourceWindowIntf then
      Exit(i);
end;

function TSourceWindows.LastSourceEditorNotFound: Boolean;
var
  i: Integer;
  LPageCtrl: TSourcePageControl;
  LSourceWindow: TSourceWindow;
begin
  if (LastActiveSourceWindow = nil) or (LastActiveSourceEditor = nil) then
    Exit(False);

  LSourceWindow := SourceWindow[LastActiveSourceWindow];
  for LPageCtrl in LSourceWindow.PageControlList do
  begin
    Result := True;
    for i := 0 to LastActiveSourceWindow.Count - 1 do
      if LPageCtrl.SourceEditor = LastActiveSourceWindow.Items[i] then
      begin
        Result := False;
        Break;
      end;
    if Result then
    begin
      // after moving code editor into other window, sometimes IDE switch to other tab
      // this line prevent this.
      LSourceWindow.LastActiveSourceEditor := LPageCtrl.SourceEditor;
      Exit;
    end;
  end;
  Result := False;
end;

procedure TSourceWindows.RefreshActivePageControls;
var
  LSourceWindow: TSourceWindow;
  LPageCtrl: TSourcePageControl;
begin
  for LSourceWindow in Self do
  begin
    LPageCtrl := LSourceWindow.FindPageControl(LSourceWindow.ActiveEditor);
    // for example LPageCtrl is nil when we clone source to new window
    if (LPageCtrl = nil) or (csDestroying in LSourceWindow.SourceWindowIntf.ComponentState) then
      Continue;
    if (LSourceWindow.ActiveEditor = nil)
    or (LSourceWindow.ActiveEditor.GetDesigner(True) <> nil)
    then
      LPageCtrl.RemoveDesignPages
    else
      if Assigned(LPageCtrl.DesignForm) then
      begin
        LPageCtrl.CreateTabSheetDesigner;
        if not (LPageCtrl.DesignForm.Form is TNonControlProxyDesignerForm) then
          LPageCtrl.CreateTabSheetAnchors;
      end;
  end;
end;

procedure TSourceWindows.RefreshAllPageControls;
var
  LSourceWindow: TSourceWindow;
  LPageCtrl: TSourcePageControl;
begin
  for LSourceWindow in SourceWindows do
    for LPageCtrl in LSourceWindow.PageControlList do
    begin
      LPageCtrl.TabPosition := DockedOptions.TabPosition;
      LPageCtrl.RefreshResizer;
      if not DockedOptions.AnchorTabVisible then
        LPageCtrl.RemoveTabSheetAnchors;
    end;
end;

procedure TSourceWindows.Remove(ASourceWindowIntf: TSourceEditorWindowInterface);
var
  LIndex: Integer;
begin
  LIndex := IndexOf(ASourceWindowIntf);
  if LIndex < 0 then Exit;
  DeleteItem(LIndex);
  if LastActiveSourceWindow = ASourceWindowIntf then
    LastActiveSourceWindow := nil;
end;

procedure TSourceWindows.ShowCodeTabSkipCurrent(CurrentPageCtrl: TSourcePageControl; ADesignForm: TDesignForm);
var
  LSourceWindow: TSourceWindow;
  LPageCtrl: TSourcePageControl;
begin
  for LSourceWindow in Self do
    for LPageCtrl in LSourceWindow.PageControlList do
      if LPageCtrl = CurrentPageCtrl then
      begin
        LPageCtrl.DesignForm := ADesignForm;
        LPageCtrl.InitPage;
      end else
        if LPageCtrl.DesignForm = ADesignForm then
          LPageCtrl.ShowCode;
end;

initialization
  SourceWindows := TSourceWindows.CreateNew;

finalization
  SourceWindows.Free;

end.


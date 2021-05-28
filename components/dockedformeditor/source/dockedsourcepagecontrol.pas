{
 *****************************************************************************
  See the file COPYING.modifiedLGPL.txt, included in this distribution,
  for details about the license.
 *****************************************************************************

 Authors: Maciej Izak
          Michael W. Vogel

 The PageControl shown in source editor window.
 Every unit got a own pagecontrol

}

unit DockedSourcePageControl;

{$mode objfpc}{$H+}
{ $define DEBUGDOCKEDFORMEDITOR}

interface

uses
  // RTL
  Classes, SysUtils, fgl,
  // LCL
  Forms, ComCtrls, Controls, LCLProc,
  // IDEIntf
  SrcEditorIntf, FormEditingIntf, LazIDEIntf,
  // DockedFormEditor
  DockedDesignForm, DockedResizer, DockedOptionsIDE, DockedAnchorDesigner,
  {%H-}DockedTools, DockedStrConsts;

type

  { TSourcePageControl }

  TSourcePageControl = class(TPageControl)
  private
    FDesignerSetFocusAsyncCount: Integer;
    FDesignForm: TDesignForm;
    FResizer: TResizer;
    FSourceEditor: TSourceEditorInterface;
    FTabSheetAnchors: TTabSheet;
    FTabSheetCode: TTabSheet;
    FTabSheetDesigner: TTabSheet;
    procedure AsyncDesignerSetFocus({%H-}Data: PtrInt);
    function  GetActiveTabDisplayState: TTabDisplayState;
    procedure SourcePageControlMouseUp(Sender: TObject; {%H-}Button: TMouseButton; {%H-}Shift: TShiftState; {%H-}X, {%H-}Y: Integer);
    procedure OnAdjustPage(Sender: TObject);
  protected
    procedure SetDesignForm(const AValue: TDesignForm); virtual;
  public
    constructor Create(ASourceEditor: TSourceEditorInterface); reintroduce;
    destructor Destroy; override;
    procedure AdjustPage;
    function  AnchorPageActive: Boolean;
    procedure CreateResizer;
    procedure CreateTabSheetAnchors;
    procedure CreateTabSheetDesigner;
    procedure DesignerSetFocus;
    procedure DesignerSetFocusAsync;
    function  DesignerPageActive: Boolean;
    function  FormPageActive: Boolean;
    procedure RemoveDesignPages;
    procedure RemoveTabSheetAnchors;
    procedure InitPage;
    procedure RefreshResizer;
    procedure ShowCode;
    procedure ShowDesigner(AIndex: Integer = 0);
  public
    property ActiveTabDisplayState: TTabDisplayState read GetActiveTabDisplayState;
    property DesignForm: TDesignForm read FDesignForm write SetDesignForm;
    property Resizer: TResizer read FResizer;
    property SourceEditor: TSourceEditorInterface read FSourceEditor;
  end;

  { TSourcePageControls }

  TSourcePageControls = class(specialize TFPGList<TSourcePageControl>)
  private
    function GetPageControl(ASrcEditor: TSourceEditorInterface): TSourcePageControl;
    function GetSourceEditor(APageControl: TSourcePageControl): TSourceEditorInterface;
  public
    function Contains(APageControl: TSourcePageControl): Boolean;
    function Contains(ASrcEditor: TSourceEditorInterface): Boolean;
    function IndexOf(APageControl: TSourcePageControl): Integer; overload;
    function IndexOf(ASrcEditor: TSourceEditorInterface): Integer; overload;
    procedure Remove(ASrcEditor: TSourceEditorInterface); overload;
  public
    property PageControl[ASrcEditor: TSourceEditorInterface]: TSourcePageControl read GetPageControl;
    property SourceEditor[APageControl: TSourcePageControl]: TSourceEditorInterface read GetSourceEditor;
  end;

implementation

{ TSourcePageControl }

procedure TSourcePageControl.OnAdjustPage(Sender: TObject);
begin
  AdjustPage;
end;

procedure TSourcePageControl.SourcePageControlMouseUp(Sender: TObject;
  Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  if DesignerPageActive then
    DesignerSetFocus;
end;

procedure TSourcePageControl.AsyncDesignerSetFocus(Data: PtrInt);
begin
  {$IFDEF DEBUGDOCKEDFORMEDITOR} DebugLn('TSourcePageControl.AsyncDesignerSetFocus'); {$ENDIF}
  DesignerSetFocus;
  FDesignerSetFocusAsyncCount := 0;
end;

function TSourcePageControl.GetActiveTabDisplayState: TTabDisplayState;
begin
  Result := tdsNone;
  if ActivePage = FTabSheetCode then Exit(tdsCode)
  else if Assigned(FTabSheetDesigner) and (ActivePage = FTabSheetDesigner) then Exit(tdsDesign)
  else if Assigned(FTabSheetAnchors)  and (ActivePage = FTabSheetAnchors)  then Exit(tdsOther);
end;

procedure TSourcePageControl.SetDesignForm(const AValue: TDesignForm);
begin
  if (AValue = FDesignForm) then
    // for show lfm code, if we want after editing lfm go back to form without any error
    // (when we restart IDE some error can be raised )
    if (FResizer = nil)
    or ((AValue <> nil) and (FResizer.DesignForm = AValue)) then
      Exit;

  {$IFDEF DEBUGDOCKEDFORMEDITOR} DebugLn('TSourcePageControl.SetDesignForm: ', DbgSName(AValue)); {$ENDIF}

  FDesignForm := AValue;
  if AValue = nil then
  begin
    if Assigned(FResizer) then
      FResizer.DesignForm := nil;
  end else begin
    FDesignForm.OnAdjustPageNeeded := @OnAdjustPage;
    AValue.LastActiveSourceWindow := Owner as TSourceEditorWindowInterface;
    if Assigned(FResizer) then
      FResizer.DesignForm := AValue;
    AdjustPage;
  end;
end;

constructor TSourcePageControl.Create(ASourceEditor: TSourceEditorInterface);
var
  LParent: TWinControl;
begin
  {$IFDEF DEBUGDOCKEDFORMEDITOR} DebugLn('TSourcePageControl.Create'); {$ENDIF}

  inherited Create(ASourceEditor.EditorControl.Owner);
  FSourceEditor := ASourceEditor;
  FDesignerSetFocusAsyncCount := 0;
  FResizer := nil;

  TabPosition := DockedOptions.TabPosition;
  Align := alClient;
  ShowTabs := False;
  OnMouseUp := @SourcePageControlMouseUp;

  FTabSheetCode := TTabSheet.Create(Self);
  FTabSheetCode.PageControl := Self;
  FTabSheetCode.Caption := SCode;

  // place SynEdit into code tab
  LParent := ASourceEditor.EditorControl.Parent;
  ASourceEditor.EditorControl.Parent := FTabSheetCode;
  Parent := LParent;
end;

destructor TSourcePageControl.Destroy;
begin
  DesignForm := nil;
  inherited Destroy;
end;

procedure TSourcePageControl.AdjustPage;
begin
  if not DesignerPageActive then Exit;
  {$IFDEF DEBUGDOCKEDFORMEDITOR} DebugLn('TSourcePageControl.AdjustPage'); {$ENDIF}
  if Assigned(FResizer) then
    FResizer.AdjustResizer(nil);
end;

function TSourcePageControl.AnchorPageActive: Boolean;
begin
  Result := ActivePage = FTabSheetAnchors;
end;

procedure TSourcePageControl.CreateResizer;
begin
  {$IFDEF DEBUGDOCKEDFORMEDITOR} DebugLn('TSourcePageControl.CreateResizer'); {$ENDIF}
  if Assigned(FResizer) then
    raise Exception.Create('TSourcePageControl.CreateResizer: Resizer already created');
  FResizer := TResizer.Create(Self);
  if not Assigned(FTabSheetDesigner) then
    CreateTabSheetDesigner;
  FResizer.Parent := FTabSheetDesigner;
end;

procedure TSourcePageControl.CreateTabSheetAnchors;
begin
  if not DockedOptions.AnchorTabVisible then Exit;
  if Assigned(FTabSheetAnchors) then Exit;
  {$IFDEF DEBUGDOCKEDFORMEDITOR} DebugLn('TSourcePageControl.CreateTabSheetAnchors'); {$ENDIF}
  FTabSheetAnchors := TTabSheet.Create(Self);
  FTabSheetAnchors.PageControl := Self;
  FTabSheetAnchors.Caption := SAnchors;
end;

procedure TSourcePageControl.CreateTabSheetDesigner;
begin
  if Assigned(FTabSheetDesigner) then Exit;
  {$IFDEF DEBUGDOCKEDFORMEDITOR} DebugLn('TSourcePageControl.CreateTabSheetDesigner'); {$ENDIF}
  FTabSheetDesigner := TTabSheet.Create(Self);
  FTabSheetDesigner.PageControl := Self;
  FTabSheetDesigner.Caption := SDesigner;
end;

procedure TSourcePageControl.DesignerSetFocus;
begin
  if not Assigned(Resizer) then Exit;
  if not Assigned(DesignForm) then Exit;
  {$IFDEF DEBUGDOCKEDFORMEDITOR} DebugLn('TSourcePageControl.DesignerSetFocus'); {$ENDIF}
  Resizer.DesignerSetFocus;
end;

procedure TSourcePageControl.DesignerSetFocusAsync;
begin
  if FDesignerSetFocusAsyncCount = 0 then
    Application.QueueAsyncCall(@AsyncDesignerSetFocus, 0);
  Inc(FDesignerSetFocusAsyncCount);
end;

function TSourcePageControl.DesignerPageActive: Boolean;
begin
  Result := (ActivePage = FTabSheetDesigner) or
            (ActivePage = FTabSheetAnchors);
end;

function TSourcePageControl.FormPageActive: Boolean;
begin
  Result := ActivePage = FTabSheetDesigner;
end;

procedure TSourcePageControl.RemoveDesignPages;
begin
  {$IFDEF DEBUGDOCKEDFORMEDITOR} DebugLn('TSourcePageControls.RemoveDesignPages'); {$ENDIF}
  RemoveTabSheetAnchors;
  FreeAndNil(FTabSheetDesigner);
  ShowTabs := False;
end;

procedure TSourcePageControl.RemoveTabSheetAnchors;
begin
  if not Assigned(FTabSheetAnchors) then Exit;
  FreeAndNil(FTabSheetAnchors);
end;

procedure TSourcePageControl.InitPage;
begin
  ShowTabs := PageCount > 1;
  {$IFDEF DEBUGDOCKEDFORMEDITOR} DebugLn('TSourcePageControls.InitPage: ShowTabs[' + ShowTabs.ToString(TUseBoolStrs.True) + ']'); {$ENDIF}
  if ActivePage = FTabSheetDesigner then
  begin
    Resizer.Parent := FTabSheetDesigner;
    Resizer.ResizeControl.FormClient.Visible := True;
    Resizer.ResizeControl.AnchorContainer.Visible := False;
  end
  else if ActivePage = FTabSheetAnchors then
  begin
    Resizer.Parent := FTabSheetAnchors;
    Resizer.ResizeControl.FormClient.Visible := False;
    Resizer.ResizeControl.AnchorContainer.Visible := True;
    if not Assigned(DesignForm.AnchorDesigner) then
    begin
      DesignForm.AnchorDesigner := TAnchorDesigner.Create(DesignForm, Resizer.ResizeControl.AnchorContainer);
      DesignForm.AnchorDesigner.OnDesignerSetFocus := @DesignerSetFocus;
    end;
    DesignForm.AnchorDesigner.Refresh;
  end;
end;

procedure TSourcePageControl.RefreshResizer;
begin
  if not Assigned(FResizer) then Exit;
  {$IFDEF DEBUGDOCKEDFORMEDITOR} DebugLn('TSourcePageControls.RefreshResizer'); {$ENDIF}
  FreeAndNil(FResizer);
  CreateResizer;
end;

procedure TSourcePageControl.ShowCode;
begin
  {$IFDEF DEBUGDOCKEDFORMEDITOR} DebugLn('TSourcePageControls.ShowCode'); {$ENDIF}
  PageIndex := 0;
  InitPage;
end;

procedure TSourcePageControl.ShowDesigner(AIndex: Integer);
begin
  {$IFDEF DEBUGDOCKEDFORMEDITOR} DebugLn('TSourcePageControls.ShowDesigner'); {$ENDIF}
  if (AIndex = 0) or not (Pages[AIndex].TabVisible) then
    AIndex := 1;
  if PageCount <= AIndex then Exit;
  if not Pages[AIndex].TabVisible then Exit;
  PageIndex := AIndex;
  InitPage;
  OnChange(Self);
end;

{ TSourcePageControls }

function TSourcePageControls.GetPageControl(ASrcEditor: TSourceEditorInterface): TSourcePageControl;
var
  LIndex: Integer;
begin
  LIndex := IndexOf(ASrcEditor);
  if LIndex >= 0 then
    Result := Items[LIndex]
  else
    Result := nil;
end;

function TSourcePageControls.GetSourceEditor(APageControl: TSourcePageControl): TSourceEditorInterface;
var
  LIndex: Integer;
begin
  LIndex := IndexOf(APageControl);
  if LIndex >= 0 then
    Result := Items[LIndex].SourceEditor
  else
    Result := nil;
end;

function TSourcePageControls.Contains(APageControl: TSourcePageControl): Boolean;
begin
  Result := IndexOf(APageControl) >= 0;
end;

function TSourcePageControls.Contains(ASrcEditor: TSourceEditorInterface): Boolean;
begin
  Result := IndexOf(ASrcEditor) >= 0;
end;

function TSourcePageControls.IndexOf(APageControl: TSourcePageControl): Integer;
var
  i: Integer;
begin
  Result := -1;
  for i := 0 to Count - 1 do
    if Items[i] = APageControl then
      Exit(i);
end;

function TSourcePageControls.IndexOf(ASrcEditor: TSourceEditorInterface): Integer;
var
  i: Integer;
begin
  Result := -1;
  for i := 0 to Count - 1 do
    if Items[i].SourceEditor = ASrcEditor then
      Exit(i);
end;

procedure TSourcePageControls.Remove(ASrcEditor: TSourceEditorInterface);
var
  LIndex: Integer;
begin
  LIndex := IndexOf(ASrcEditor);
  if LIndex < 0 then Exit;
  Delete(LIndex);
end;

end.


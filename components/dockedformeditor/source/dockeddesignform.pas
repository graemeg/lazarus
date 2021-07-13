{
 *****************************************************************************
  See the file COPYING.modifiedLGPL.txt, included in this distribution,
  for details about the license.
 *****************************************************************************

 Authors: Maciej Izak
          Michael W. Vogel

}

unit DockedDesignForm;

{$mode objfpc}{$H+}
{$modeswitch advancedrecords}
{$modeswitch typehelpers}

interface

uses
  // RTL
  Classes, SysUtils, fgl,
  // LCL
  LMessages, Forms, LCLType, LCLIntf, Controls,
  // IDEIntf
  SrcEditorIntf,
  // DockedFormEditor
  DockedFormAccesses, DockedBasicAnchorDesigner;

const
  WM_SETNOFRAME            = WM_USER;
  WM_BOUNDTODESIGNTABSHEET = WM_USER + 1;

type
  { TDesignForm }

  TDesignForm = class(TDesignFormIDE)
  private
    FHiding: Boolean;
    FOnAdjustPageNeeded: TNotifyEvent;
    FWndMethod: TWndMethod;
    procedure FixF12_ActiveEditor;
    procedure FormChangeBounds(Sender: TObject);
    procedure WndMethod(var Msg: TLMessage);
  public
    constructor Create(AForm: TCustomForm); override;
    destructor Destroy; override;
  public
    property Hiding: Boolean read FHiding write FHiding;
    property OnAdjustPageNeeded: TNotifyEvent read FOnAdjustPageNeeded write FOnAdjustPageNeeded;
  end;

  { TDesignForms }

  TDesignForms = class(specialize TFPGList<TDesignForm>)
  public
    destructor Destroy; override;
    procedure DeleteDesignForm(AIndex: Integer);
    function Find(AForm: TCustomForm): TDesignForm; overload;
    function Find(ADesigner: TIDesigner): TDesignForm; overload;
    function IndexOf(AForm: TCustomForm): Integer; overload;
    procedure Remove(AForm: TCustomForm); overload;
    procedure RemoveAllAnchorDesigner;
  end;

var
  DesignForms: TDesignForms;

implementation

{ TDesignForm }

procedure TDesignForm.FixF12_ActiveEditor;
var
  i: Integer;
begin
  // Without this, button F12 don't work. (after creating new for editor is inactive)
  // Just do it for new created forms or the last loaded form becomes the active
  // source editor after reopening a project.
  if Designer <> SourceEditorManagerIntf.ActiveEditor.GetDesigner(True) then Exit;

  SourceEditorManagerIntf.ActiveEditor := nil;
  for i := 0 to SourceEditorManagerIntf.UniqueSourceEditorCount - 1 do
    if Designer = SourceEditorManagerIntf.UniqueSourceEditors[i].GetDesigner(True) then
    begin
      SourceEditorManagerIntf.ActiveEditor := SourceEditorManagerIntf.UniqueSourceEditors[i];
      Break;
    end;
end;

procedure TDesignForm.FormChangeBounds(Sender: TObject);
begin
  if not Update then
    SetTimer(Form.Handle, WM_BOUNDTODESIGNTABSHEET, 10, nil);
end;

procedure TDesignForm.WndMethod(var Msg: TLMessage);
var
  Timer: TLMTimer;
begin
  if Msg.msg = LM_TIMER then
  begin
    Timer := TLMTimer(Msg);
    case Timer.TimerID of
      WM_SETNOFRAME:
        begin
          KillTimer(Form.Handle, WM_SETNOFRAME);
          LCLIntf.ShowWindow(Form.Handle, SW_HIDE);
          FHiding := False;
          FixF12_ActiveEditor;
          Exit;
        end;
      WM_BOUNDTODESIGNTABSHEET:
        begin
          KillTimer(Form.Handle, WM_BOUNDTODESIGNTABSHEET);
          if Assigned(FOnAdjustPageNeeded) then
            FOnAdjustPageNeeded(Self);
          Exit;
        end;
    end;
  end;

  // we need to correct ActiveEditor to right form
  // this code works correctly on Windows platform
  // (is necessery for selecting controls after form resizing).
  // in Linux platforms below code brings problems with QT (inactive form)
  {$IFDEF WINDOWS}
  case Msg.msg of
    LM_LBUTTONDOWN, LM_RBUTTONDOWN, LM_MBUTTONDOWN, LM_XBUTTONDOWN:
      if LastActiveSourceWindow <> nil then
      begin
        SourceEditorManagerIntf.ActiveSourceWindow := LastActiveSourceWindow;
        SourceEditorManagerIntf.ActiveEditor := LastActiveSourceWindow.ActiveEditor;
      end;
    // Prevent usage of parent hint (SourceEditorWindow), see issue #39217
    CM_PARENTSHOWHINTCHANGED:
      Exit;
  end;
  {$ENDIF}

  FWndMethod(Msg);
end;

constructor TDesignForm.Create(AForm: TCustomForm);
begin
  inherited Create(AForm);
  AForm.AddHandlerOnChangeBounds(@FormChangeBounds);
  FWndMethod := Form.WindowProc;
  Form.WindowProc := @WndMethod;
end;

destructor TDesignForm.Destroy;
begin
  Form.WindowProc := FWndMethod; // ! important risky point :P
  Form.RemoveHandlerOnChangeBounds(@FormChangeBounds);
  inherited Destroy;
end;

{ TDesignForms }

destructor TDesignForms.Destroy;
begin
  while Count > 0 do
    DeleteDesignForm(0);
  inherited Destroy;
end;

procedure TDesignForms.DeleteDesignForm(AIndex: Integer);
var
  LDesignForm: TDesignForm;
begin
  LDesignForm := Self[AIndex];
  LDesignForm.Free;
  Delete(AIndex);
end;

function TDesignForms.Find(AForm: TCustomForm): TDesignForm;
var
  LDesignForm: TDesignForm;
begin
  // sometimes at some level of initialization form can not contain TIDesigner
  // (during ide run and when is oppened default project with some TForm1)
  Result := nil;
  if AForm = nil then Exit;
  for LDesignForm in Self do
    if LDesignForm.Form = AForm then
      Exit(LDesignForm);
end;

function TDesignForms.Find(ADesigner: TIDesigner): TDesignForm;
var
  LDesignForm: TDesignForm;
begin
  Result := nil;
  if ADesigner = nil then Exit;
  for LDesignForm in Self do
    if LDesignForm.Designer = ADesigner then
      Exit(LDesignForm);
end;

function TDesignForms.IndexOf(AForm: TCustomForm): Integer;
var
  i: Integer;
begin
  Result := -1;
  for i := 0 to Count - 1 do
    if Items[i].Form = AForm then
      Exit(i);
end;

procedure TDesignForms.Remove(AForm: TCustomForm);
var
  LIndex: Integer;
begin
  LIndex := IndexOf(AForm);
  if LIndex < 0 then Exit;
  Items[LIndex].Free;
  Delete(LIndex);
end;

procedure TDesignForms.RemoveAllAnchorDesigner;
var
  LDesignForm: TDesignForm;
  LAnchorDesigner: TBasicAnchorDesigner;
begin
  for LDesignForm in Self do
  begin
    LAnchorDesigner := LDesignForm.AnchorDesigner;
    if not Assigned(LAnchorDesigner) then Continue;
    LAnchorDesigner.Free;
    LDesignForm.AnchorDesigner := nil;
  end;
end;

initialization
  DesignForms := TDesignForms.Create;

finalization
  FreeAndNil(DesignForms);

end.


{ $Id$ }
{               ----------------------------------------------
                 evaluatedlg.pp  -  Evaluate and Modify
                ----------------------------------------------

 @created(Mon Nov 22st WET 2004)
 @lastmod($Date$)
 @author(Marc Weustink <marc@@freepascal.org>)

 This unit contains the evaluate and modify dialog.


 ***************************************************************************
 *                                                                         *
 *   This source is free software; you can redistribute it and/or modify   *
 *   it under the terms of the GNU General Public License as published by  *
 *   the Free Software Foundation; either version 2 of the License, or     *
 *   (at your option) any later version.                                   *
 *                                                                         *
 *   This code is distributed in the hope that it will be useful, but      *
 *   WITHOUT ANY WARRANTY; without even the implied warranty of            *
 *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU     *
 *   General Public License for more details.                              *
 *                                                                         *
 *   A copy of the GNU General Public License is available on the World    *
 *   Wide Web at <http://www.gnu.org/copyleft/gpl.html>. You can also      *
 *   obtain it by writing to the Free Software Foundation,                 *
 *   Inc., 51 Franklin Street - Fifth Floor, Boston, MA 02110-1335, USA.   *
 *                                                                         *
 ***************************************************************************
}

unit EvaluateDlg;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils,
  // LCL
  LCLType, Forms, Controls, ComCtrls, StdCtrls, Menus, Dialogs,
  // IdeIntf
  IDEWindowIntf, IDEImagesIntf,
  // DebuggerIntf
  DbgIntfDebuggerBase,
  // IDE
  LazarusIDEStrConsts, BaseDebugManager, InputHistory, IDEProcs,
  Debugger, DebuggerDlg, DebuggerStrConst, EnvironmentOpts;

type

  TEvalHistDirection=(EHDNone,EHDUp,EHDDown);


  { TEvaluateDlg }

  TEvaluateDlg = class(TDebuggerDlg)
    chkTypeCast: TCheckBox;
    cmbExpression: TComboBox;
    cmbNewValue: TComboBox;
    Label1: TLabel;
    Label2: TLabel;
    lblNewValue: TLabel;
    MenuItem1: TMenuItem;
    MenuItem2: TMenuItem;
    MenuItem3: TMenuItem;
    mnuHistory: TPopupMenu;
    ToolButton1: TToolButton;
    tbHistory: TToolButton;
    txtResult: TMemo;
    ToolBar1: TToolBar;
    tbInspect: TToolButton;
    tbWatch: TToolButton;
    tbModify: TToolButton;
    tbEvaluate: TToolButton;
    procedure cmbExpressionKeyUp(Sender: TObject; var {%H-}Key: Word;
      {%H-}Shift: TShiftState);
    procedure cmbExpressionSelect(Sender: TObject);
    procedure cmbNewValueKeyDown(Sender: TObject; var Key: Word;
      {%H-}Shift: TShiftState);
    procedure FormActivate(Sender: TObject);
    procedure FormClose(Sender: TObject; var {%H-}CloseAction: TCloseAction);
    procedure FormCreate(Sender: TObject);
    procedure FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure FormShow(Sender: TObject);
    procedure cmbExpressionChange(Sender: TObject);
    procedure cmbExpressionKeyDown(Sender: TObject; var Key: Word;
      {%H-}Shift: TShiftState);
    procedure MenuItem1Click(Sender: TObject);
    procedure MenuItem2Click(Sender: TObject);
    procedure MenuItem3Click(Sender: TObject);
    procedure tbEvaluateClick(Sender: TObject);
    procedure tbInspectClick(Sender: TObject);
    procedure tbModifyClick(Sender: TObject);
    procedure tbWatchClick(Sender: TObject);
    
  private
    fSkipKeySelect: Boolean;
    fHistDirection:TEvalHistDirection;
    procedure EvaluateCallback(Sender: TObject; ASuccess: Boolean;
      ResultText: String; ResultDBGType: TDBGType);
    function GetFindText: string;
    procedure SetFindText(const NewFindText: string);
    procedure Evaluate;
    procedure Modify;
  public
    constructor Create(TheOwner: TComponent); override;
    procedure Execute(const AExpression: String);
    property FindText: string read GetFindText write SetFindText;
    procedure UpdateData;
  end;

implementation

{$R *.lfm}

var
  EvaluateDlgWindowCreator: TIDEWindowCreator;

const
  RESULTSEPARATOR='-----------';
  RESULTEVAL='>>>> ';

{ TEvaluateDlg }

constructor TEvaluateDlg.Create(TheOwner:TComponent);
begin
  inherited Create(TheOwner);

  fSkipKeySelect := False;
  Caption := lisKMEvaluateModify;
  cmbExpression.Items.Assign(InputHistories.HistoryLists.
    GetList(ClassName,True,rltCaseSensitive));

  tbEvaluate.Caption := lisEvaluate;
  tbModify.Caption := lisModify;
  tbWatch.Caption := lisWatch;
  tbInspect.Caption := lisInspect;
  tbHistory.Caption := lisMenuViewHistory;

  Label1.Caption := lisDBGEMExpression;
  Label2.Caption := lisDBGEMResult;
  lblNewValue.Caption := lisDBGEMNewValue;
  chkTypeCast.Caption := drsUseInstanceClassType;
  fHistDirection:=EHDNone;

  ToolBar1.Images := IDEImages.Images_16;
  tbInspect.ImageIndex := IDEImages.LoadImage('debugger_inspect');
  tbWatch.ImageIndex := IDEImages.LoadImage('debugger_watches');
  tbModify.ImageIndex := IDEImages.LoadImage('debugger_modify');
  tbEvaluate.ImageIndex := IDEImages.LoadImage('debugger_evaluate');
  tbHistory.ImageIndex := IDEImages.LoadImage('evaluate_no_hist');

  mnuHistory.Items[0].Caption:=drsEvalHistoryNone;
  mnuHistory.Items[1].Caption:=dsrEvalHistoryUp;
  mnuHistory.Items[2].Caption:=dsrEvalHistoryDown;
end;

procedure TEvaluateDlg.Execute(const AExpression: String);
begin
  SetFindText(AExpression);
end;

procedure TEvaluateDlg.FormActivate(Sender: TObject);
begin
  cmbExpression.DropDownCount := EnvironmentOptions.DropDownCount;
  cmbNewValue.DropDownCount := EnvironmentOptions.DropDownCount;
end;

procedure TEvaluateDlg.UpdateData;
begin
  Evaluate;
end;

procedure TEvaluateDlg.EvaluateCallback(Sender: TObject; ASuccess: Boolean;
  ResultText: String; ResultDBGType: TDBGType);
var
  S: TCaption;
begin
  S := cmbExpression.Text;

  if ASuccess then begin
    if cmbExpression.Items.IndexOf(S) = -1
    then cmbExpression.Items.Insert(0, S);
    tbModify.Enabled := True;

    if (ResultDBGType <> nil) and (ResultDBGType.Attributes * [saArray, saDynArray] <> []) and (ResultDBGType.Len >= 0)
    then ResultText := Format(drsLen, [ResultDBGType.Len]) + LineEnding + ResultText;

  end
  else
    tbModify.Enabled := False;

  FreeAndNil(ResultDBGType);
  if fHistDirection<>EHDNone then
    begin
    if txtResult.Lines.Text='' then
      txtResult.Lines.Text := RESULTEVAL+ S+':'+LineEnding+ ResultText + LineEnding
    else
      if fHistDirection=EHDUp then
        txtResult.Lines.Text := RESULTEVAL+ S+':'+LineEnding+ ResultText + LineEnding
           + RESULTSEPARATOR + LineEnding + txtResult.Lines.Text
      else
        begin
        txtResult.Lines.Text := txtResult.Lines.Text + RESULTSEPARATOR + LineEnding
           + RESULTEVAL+ S+':'+LineEnding+ ResultText+LineEnding;
        txtResult.SelStart:=length(txtResult.Lines.Text);
        end;
    end
  else
    txtResult.Lines.Text := ResultText;
end;

procedure TEvaluateDlg.Evaluate;
var
  S: String;
  Opts: TDBGEvaluateFlags;
begin
  S := cmbExpression.Text;
  if S = '' then Exit;
  InputHistories.HistoryLists.Add(ClassName, S,rltCaseSensitive);
  Opts := [];
  if chkTypeCast.Checked then
    Opts := [defClassAutoCast];
  if not DebugBoss.Evaluate(S, @EvaluateCallback, Opts)
  then
    EvaluateCallback(nil, false, '', nil);
end;

procedure TEvaluateDlg.cmbExpressionChange(Sender: TObject);
var
  HasExpression: Boolean;
begin
  HasExpression := Trim(cmbExpression.Text) <> '';
  tbEvaluate.Enabled := HasExpression;
  tbModify.Enabled := HasExpression;
  tbWatch.Enabled := HasExpression;
  tbInspect.Enabled := HasExpression;
end;

procedure TEvaluateDlg.cmbExpressionKeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
  fSkipKeySelect := True;
  if (Key = VK_RETURN) and tbEvaluate.Enabled
  then begin
    Evaluate;
    Key := 0;
  end;
end;

procedure TEvaluateDlg.MenuItem1Click(Sender: TObject);
begin
  fHistDirection:=EHDNone;
  tbHistory.ImageIndex := IDEImages.LoadImage('evaluate_no_hist');
  txtResult.Lines.Clear;
end;

procedure TEvaluateDlg.MenuItem2Click(Sender: TObject);
begin
  fHistDirection:=EHDUp;
  tbHistory.ImageIndex := IDEImages.LoadImage('evaluate_up');
  txtResult.Lines.Clear;
end;

procedure TEvaluateDlg.MenuItem3Click(Sender: TObject);
begin
  fHistDirection:=EHDDown;
  tbHistory.ImageIndex := IDEImages.LoadImage('callstack_goto');
  txtResult.Lines.Clear;
end;

procedure TEvaluateDlg.SetFindText(const NewFindText: string);
begin
  if NewFindText<>'' then
  begin
    cmbExpression.Text := NewFindText;
    cmbExpressionChange(nil);
    cmbExpression.SelectAll;
    tbEvaluateClick(tbEvaluate);
  end;
  ActiveControl := cmbExpression;
end;

function TEvaluateDlg.GetFindText: string;
begin
  Result := cmbExpression.Text;
end;

procedure TEvaluateDlg.Modify;
var
  S, V: String;
begin
  S := Trim(cmbExpression.Text);
  if S = '' then Exit;
  V := cmbNewValue.Text;
  if not DebugBoss.Modify(S, V) then begin
    MessageDlg(lisCCOErrorCaption, synfTheDebuggerWasNotAbleToModifyTheValue, mtError, [mbOK],
      0);
    Exit;
  end;

  if cmbNewValue.Items.IndexOf(V) = -1
  then cmbNewValue.Items.Insert(0, V);

  Evaluate;
end;

procedure TEvaluateDlg.FormClose(Sender: TObject; var CloseAction: TCloseAction);
begin
  IDEDialogLayoutList.SaveLayout(Self);
end;

procedure TEvaluateDlg.FormCreate(Sender: TObject);
begin
  IDEDialogLayoutList.ApplyLayout(Self,400,300);
end;

procedure TEvaluateDlg.cmbNewValueKeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
  if (Key = VK_RETURN) and (tbModify.Enabled)
  then begin
    Modify;
    Key := 0;
  end;
end;

procedure TEvaluateDlg.cmbExpressionKeyUp(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
  fSkipKeySelect := False;
end;

procedure TEvaluateDlg.cmbExpressionSelect(Sender: TObject);
begin
  if not fSkipKeySelect then
    Evaluate;
end;

procedure TEvaluateDlg.FormShow(Sender: TObject);
begin
  cmbExpression.SetFocus;
end;

procedure TEvaluateDlg.FormKeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
  if (Key = VK_ESCAPE) and not Docked then
    Close
  else
    inherited;;
end;

procedure TEvaluateDlg.tbEvaluateClick(Sender: TObject);
begin
  Evaluate;
end;

procedure TEvaluateDlg.tbInspectClick(Sender: TObject);
begin
  DebugBoss.Inspect(cmbExpression.Text);
end;

procedure TEvaluateDlg.tbModifyClick(Sender: TObject);
begin
  if cmbNewValue.Text = '' then begin
    MessageDlg(lisCCOErrorCaption, synfNewValueIsEmpty, mtError, [mbOK], 0);
    exit;
  end;
  Modify;
end;

procedure TEvaluateDlg.tbWatchClick(Sender: TObject);
var
  S: String;
  Watch: TCurrentWatch;
begin
  S := cmbExpression.Text;
  if s = '' then
    exit;
  if DebugBoss.Watches.CurrentWatches.Find(S) = nil
  then begin
    DebugBoss.Watches.CurrentWatches.BeginUpdate;
    try
      Watch := DebugBoss.Watches.CurrentWatches.Add(S);
      Watch.Enabled := True;
      if EnvironmentOptions.DebuggerAutoSetInstanceFromClass then
        Watch.EvaluateFlags := Watch.EvaluateFlags + [defClassAutoCast];
    finally
      DebugBoss.Watches.CurrentWatches.EndUpdate;
    end;
  end;
  DebugBoss.ViewDebugDialog(ddtWatches);
end;

initialization

  EvaluateDlgWindowCreator := IDEWindowCreators.Add(DebugDialogNames[ddtEvaluate]);
  EvaluateDlgWindowCreator.OnCreateFormProc := @CreateDebugDialog;
  EvaluateDlgWindowCreator.CreateSimpleLayout;

end.



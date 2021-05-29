{ $Id$ }
{               ----------------------------------------------
                 watchproperydlg.pp  -  property editor for 
                                        watches
                ----------------------------------------------

 @created(Fri Dec 14st WET 2001)
 @lastmod($Date$)
 @author(Shane Miller)
 @author(Marc Weustink <marc@@dommelstein.net>)

 This unit contains the watch property dialog.


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

unit WatchPropertyDlg;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, StdCtrls, Extctrls, ButtonPanel,
  LazarusIDEStrConsts, IDEHelpIntf, DbgIntfDebuggerBase, Debugger,
  BaseDebugManager, EnvironmentOpts, DebuggerStrConst;

type

  { TWatchPropertyDlg }

  TWatchPropertyDlg = class(TForm)
    ButtonPanel: TButtonPanel;
    chkAllowFunc: TCheckBox;
    chkEnabled: TCheckBox;
    chkUseInstanceClass: TCheckBox;
    lblDigits: TLabel;
    lblExpression: TLabel;
    lblRepCount: TLabel;
    PanelTop: TPanel;
    rgStyle: TRadioGroup;
    txtDigits: TEdit;
    txtExpression: TEdit;
    txtRepCount: TEdit;
    procedure btnHelpClick(Sender: TObject);
    procedure btnOKClick(Sender: TObject);
    procedure txtExpressionChange(Sender: TObject);
  private
    FWatch: TIdeWatch;
  public
    constructor Create(AOWner: TComponent; const AWatch: TIdeWatch; const AWatchExpression: String = ''); overload;
    destructor Destroy; override;
  end;
  
implementation

{$R *.lfm}

{ TWatchPropertyDlg }

procedure TWatchPropertyDlg.btnOKClick(Sender: TObject);
const
  StyleToDispFormat: Array [0..9] of TWatchDisplayFormat =
    (wdfChar, wdfString, wdfDecimal,
     wdfHex, wdfUnsigned, wdfPointer,
     wdfStructure, wdfDefault, wdfMemDump, wdfBinary
    );
begin
  if txtExpression.Text = '' then
    exit;
  DebugBoss.Watches.CurrentWatches.BeginUpdate;
  try
    if FWatch = nil
    then begin
      FWatch := DebugBoss.Watches.CurrentWatches.Add(txtExpression.Text);
    end
    else begin
      FWatch.Expression := txtExpression.Text;
    end;

    if (rgStyle.ItemIndex >= low(StyleToDispFormat))
    and (rgStyle.ItemIndex <= High(StyleToDispFormat))
    then FWatch.DisplayFormat := StyleToDispFormat[rgStyle.ItemIndex]
    else FWatch.DisplayFormat := wdfDefault;

    if chkUseInstanceClass.Checked
    then FWatch.EvaluateFlags := [defClassAutoCast]
    else FWatch.EvaluateFlags := [];
    if chkAllowFunc.Checked
    then FWatch.EvaluateFlags := FWatch.EvaluateFlags + [defAllowFunctionCall]
    else FWatch.EvaluateFlags := [];
    FWatch.RepeatCount := StrToIntDef(txtRepCount.Text, 0);

    FWatch.Enabled := chkEnabled.Checked;
  finally
    DebugBoss.Watches.CurrentWatches.EndUpdate;
  end;
end;

procedure TWatchPropertyDlg.txtExpressionChange(Sender: TObject);
begin
  ButtonPanel.OKButton.Enabled := txtExpression.Text <> '';
end;

procedure TWatchPropertyDlg.btnHelpClick(Sender: TObject);
begin
  LazarusHelp.ShowHelpForIDEControl(Self);
end;

constructor TWatchPropertyDlg.Create(AOwner: TComponent; const AWatch: TIdeWatch;
  const AWatchExpression: String = '');
const
  DispFormatToStyle: Array [TWatchDisplayFormat] of Integer =
    (7, 6, //wdfDefault, wdfStructure,
     0, 1, //wdfChar, wdfString,
     2, 4, //wdfDecimal, wdfUnsigned, (TODO unsigned)
     7, 3, //wdfFloat, wdfHex,
     5, 8, //wdfPointer, wdfMemDump
     9     //wdfBinary
    );
begin
  FWatch := AWatch;
  inherited Create(AOwner);
  if FWatch = nil
  then begin 
    chkEnabled.Checked := True;
    txtExpression.Text := AWatchExpression;
    rgStyle.ItemIndex := 7;
    chkUseInstanceClass.Checked := EnvironmentOptions.DebuggerAutoSetInstanceFromClass;
    txtRepCount.Text := '0';
  end
  else begin
    txtExpression.Text          := FWatch.Expression;
    chkEnabled.Checked          := FWatch.Enabled;
    rgStyle.ItemIndex           := DispFormatToStyle[FWatch.DisplayFormat];
    chkUseInstanceClass.Checked := defClassAutoCast in FWatch.EvaluateFlags;
    chkAllowFunc.Checked        := defAllowFunctionCall in FWatch.EvaluateFlags;
    txtRepCount.Text            := IntToStr(FWatch.RepeatCount);
  end;
  txtExpressionChange(nil);

  lblDigits.Enabled := False;
  txtDigits.Enabled := False;
  chkAllowFunc.Enabled := EnvironmentOptions.DebuggerAllowFunctionCalls and
    (dfEvalFunctionCalls in DebugBoss.DebuggerClass.SupportedFeatures);

  Caption:= lisWatchPropert;
  lblExpression.Caption:= lisExpression;
  lblRepCount.Caption:= lisRepeatCount;
  lblDigits.Caption:= lisDigits;
  chkEnabled.Caption:= lisEnabled;
  chkAllowFunc.Caption:= lisAllowFunctio;
  chkUseInstanceClass.Caption := drsUseInstanceClassType;
  rgStyle.Caption:= lisStyle;
  rgStyle.Items[0]:= lisCharacter;
  rgStyle.Items[1]:= lisString;
  rgStyle.Items[2]:= lisDecimal;
  rgStyle.Items[3]:= lisHexadecimal;
  rgStyle.Items[4]:= lisUnsigned;
  rgStyle.Items[5]:= lisPointer;
  rgStyle.Items[6]:= lisRecordStruct;
  rgStyle.Items[7]:= lisDefault;
  rgStyle.Items[8]:= lisMemoryDump;
  rgStyle.Items[9]:= lisBinary;
  //rgStyle.Items[10]:= lisFloatingPoin;

  ButtonPanel.OKButton.Caption:=lisMenuOk;
  ButtonPanel.HelpButton.Caption:=lisMenuHelp;
  ButtonPanel.CancelButton.Caption:=lisCancel;
end;

destructor TWatchPropertyDlg.destroy;
begin
  inherited;
end;

end.


{%MainUnit ../dialogs.pp}

{******************************************************************************
                                  MessageDialogs
 ******************************************************************************

 *****************************************************************************
  This file is part of the Lazarus Component Library (LCL)

  See the file COPYING.modifiedLGPL.txt, included in this distribution,
  for details about the license.
 *****************************************************************************
  current design flaws:

  - ??? There has to be at least one :-)

  Delphi compatibility:

   - the interface is almost like in delphi 5
     
  TODO:
    - Help Context
    - Help-button
    - User ability to customize Button order

}
function ModalEscapeValue(Buttons: TMsgDlgButtons): TModalResult;
begin
    Result := mrCancel;
end;

function ModalDefaultButton(Buttons : TMsgDlgButtons) : TMsgDlgbtn;
var
  b: TMsgDlgBtn;
begin
  Result := mbYes;               // Some default return value.
  If mbYes in Buttons then
    Result := mbYes
  else
    If mbOk in Buttons then
      Result := mbOk
  else
    If mbYesToAll in Buttons then
      Result := mbYesToAll
  else
    If mbAll in Buttons then
      Result := mbAll
  else
    If mbRetry in Buttons then
      Result := mbRetry
  else
    If mbCancel in Buttons then
      Result := mbCancel
  else
    If mbNo in Buttons then
      Result := mbNo
  else
    If mbNoToAll in Buttons then
      Result := mbNoToAll
  else
    If mbAbort in Buttons then
      Result := mbAbort
  else
    If mbIgnore in Buttons then
      Result := mbIgnore
  else
  begin
    for b := Low(TMsgDlgBtn) to High(TMsgDlgBtn) do
      if b in Buttons then
        Result := b;
  end;
end;

const
  DialogIds : Array[mtWarning..mtCustom] of Longint = (idDialogWarning,
    idDialogError, idDialogInfo, idDialogConfirm, idDialogBase);

  ButtonIds : Array[TMsgDlgbtn] of Longint = (idButtonYes, idButtonNo,
    idButtonOK, idButtonCancel, idButtonAbort, idButtonRetry, idButtonIgnore,
    idButtonAll, idButtonNoToAll, idButtonYesToAll, idButtonHelp,
    idButtonClose);

  DialogResults : Array[idButtonOK..idButtonNoToAll] of TModalResult = (
      mrOk, mrCancel,
    mrNone{Help - when a mbHelp button is pressed the help system is started,
                  the dialog does not close },
    mrYes, mrNo, mrClose, mrAbort, mrRetry,
    mrIgnore, mrAll, mrYesToAll, mrNoToAll);

function GetPromptUserButtons(Buttons: TMsgDlgButtons; var CancelValue,
  DefaultIndex, ButtonCount : Longint; UseDefButton: Boolean; DefButton: TMsgDlgBtn) : PLongint;
var
  CurBtn      : TMsgDlgBtn; // variable to loop through TMsgDlgButtons
  DefaultButton : TMsgDlgBtn;
begin
 if (Buttons = []) or (Buttons = [mbHelp]) then
    Buttons := Buttons + [mbOk];
  //Native PromptUser() dialog should return mrCancel on Escape or [X]-bordericon
  //TPromptDialog.CreatMessageDialog responds to Escape in "old Delhpi" style,
  //it will return mrCancel, mrNo, or mrOK if one of these buttons is present, else it will not respons to Escape key,
  //TPromptDialog.CreatMessageDialog does not use the CancelValue variable
  CancelValue := idButtonCancel;
  if UseDefButton then
    DefaultButton := DefButton
  else
    DefaultButton := ModalDefaultButton(Buttons);
  DefaultIndex := 0;
  ButtonCount := 0;
  Result := nil;
  for CurBtn := Low(TMsgDlgBtn) to High(TMsgDlgBtn) do
  begin
    if CurBtn in Buttons then
    begin
      ReallocMem(Result, (ButtonCount + 1) * SizeOf(Longint));
      Result[ButtonCount] := ButtonIds[CurBtn];
      if DefaultButton = CurBtn then
        DefaultIndex := ButtonCount;
      Inc(ButtonCount)
    end;
  end;
end;

function MessageDlg(const aMsg: string; DlgType: TMsgDlgType;
  Buttons: TMsgDlgButtons; HelpCtx: Longint): TModalResult;
var
  DefaultIndex,
  CancelValue,
  ButtonCount : Longint;
  Btns : PLongint;
begin
  Btns := GetPromptUserButtons(Buttons, CancelValue, DefaultIndex, ButtonCount,
    False, mbYes);
  Result := DialogResults[PromptUser(ConvertLineEndings(aMsg),
    DialogIds[DlgType], Btns, ButtonCount, DefaultIndex, CancelValue)];
  ReallocMem(Btns, 0);
end;

function MessageDlg(const aCaption, aMsg: string; DlgType: TMsgDlgType;
  Buttons: TMsgDlgButtons; HelpCtx: Longint): TModalResult;
var
  DefaultIndex,
  CancelValue,
  ButtonCount : Longint;
  Btns : PLongint;
begin
  Btns := GetPromptUserButtons(Buttons, CancelValue, DefaultIndex, ButtonCount,
    False, mbYes);
  Result := DialogResults[PromptUser(aCaption, ConvertLineEndings(aMsg),
    DialogIds[DlgType], Btns, ButtonCount, DefaultIndex, CancelValue)];
  ReallocMem(Btns, 0);
end;

function MessageDlg(const aCaption, aMsg: string; DlgType: TMsgDlgType;
  Buttons: TMsgDlgButtons; HelpCtx: Longint; DefaultButton: TMsgDlgBtn): TModalResult;
var
  DefaultIndex,
  CancelValue,
  ButtonCount : Longint;
  Btns : PLongint;
begin
  Btns := GetPromptUserButtons(Buttons, CancelValue, DefaultIndex, ButtonCount,
    True, DefaultButton);
  Result := DialogResults[PromptUser(aCaption, ConvertLineEndings(aMsg),
    DialogIds[DlgType], Btns, ButtonCount, DefaultIndex, CancelValue)];
  ReallocMem(Btns, 0);
end;

function MessageDlg(const aMsg: string; DlgType: TMsgDlgType;
  Buttons: TMsgDlgButtons; HelpCtx: Longint; DefaultButton: TMsgDlgBtn
  ): TModalResult;
begin
  Result := MessageDlg('', aMsg, DlgType, Buttons, HelpCtx, DefaultButton);
end;

function MessageDlg(const aCaption, aMsg: string; DlgType: TMsgDlgType;
  Buttons: TMsgDlgButtons; const HelpKeyword: string): TModalResult;
begin
  // TODO: handle HelpKeyword
  Result:=MessageDlg(aCaption, aMsg, DlgType, Buttons, 0);
end;

function MessageDlgPos(const aMsg: string; DlgType: TMsgDlgType;
  Buttons: TMsgDlgButtons; HelpCtx: Longint; X, Y: Integer): TModalResult;
var
  DefaultIndex,
  CancelValue,
  ButtonCount : Longint;
  Btns : PLongint;
begin
  Btns := GetPromptUserButtons(Buttons, CancelValue, DefaultIndex, ButtonCount,
    False, mbYes);
  Result := DialogResults[PromptUserAtXY(ConvertLineEndings(aMsg),
    DialogIds[DlgType], Btns, ButtonCount, DefaultIndex, CancelValue, X, Y)];
  ReallocMem(Btns, 0);
end;

function MessageDlgPosHelp(const aMsg: string; DlgType: TMsgDlgType;
  Buttons: TMsgDlgButtons; HelpCtx: Longint; X, Y: Integer;
  const HelpFileName: string): TModalResult;
begin
  DebugLn ('MessageDlgPosHelp ****** NOT YET FULLY IMPLEMENTED ********');
//TODO: set helpcontext and helpfile
  result := MessageDlgPos(aMsg, DlgType, buttons, helpctx, X, Y);
end;

procedure ShowMessage(const aMsg: string);
begin
  NotifyUser(ConvertLineEndings(aMsg), idDialogBase);
end;

procedure ShowMessageFmt(const aMsg: string; Params: array of const);
begin
  NotifyUser(ConvertLineEndings(Format(aMsg, Params)), idDialogBase);
end;

procedure ShowMessagePos(const aMsg: string; X, Y: Integer);
begin
  NotifyUserAtXY(ConvertLineEndings(aMsg), idDialogBase, X, Y);
end;

//----------------------------------------------------------------------------//
//-----------------------Prompt User For Information--------------------------//
function InputBox(const ACaption, APrompt, ADefault : String) : String;
begin
  Result := ADefault;
  InputQuery(ACaption, APrompt, Result);
end;

function PasswordBox(const ACaption, APrompt : String) : String;
begin
  Result := '';
  InputQuery(ACaption, APrompt, True, Result);
end;

procedure DialogCopyToClipboard(Self, Sender: TObject; var Key: Word;
  Shift: TShiftState);
var
  S: string;
  Dlg: TCustomForm;
  Cnt, LastCnt: TControl;
begin
  if not ((Key in [VK_C, VK_INSERT]) and (Shift = [ssModifier])) then
    Exit;

  Dlg := Self as TCustomForm;

  S := Format('[%s]', [Dlg.Caption]) + sLineBreak;
  LastCnt := nil;

  if Dlg is TCustomCopyToClipboardDialog then
    S := S + sLineBreak + TCustomCopyToClipboardDialog(Dlg).GetMessageText + sLineBreak;

  for Cnt in Dlg.GetEnumeratorControls do
  begin
    if (Cnt is TCustomLabel) then
    begin
      S := S + sLineBreak + Cnt.Caption + sLineBreak;
      LastCnt := nil;
    end else
    begin
      if (LastCnt=nil) or (LastCnt.Top > Cnt.Top) then
        S := S + sLineBreak+sLineBreak
      else
        S := S + ' ';

      S := S + Format('[%s]', [StripHotKey(Cnt.Caption)]);
      LastCnt := Cnt;
    end;
  end;

  Clipboard.AsText := TrimRight(S);
end;

procedure RegisterDialogForCopyToClipboard(const ADlg: TCustomForm);
var
  Mtd: TMethod;
begin
  ADlg.KeyPreview := True;
  Mtd.Code := @DialogCopyToClipboard;
  Mtd.Data := ADlg;
  ADlg.AddHandlerOnKeyDown(TKeyEvent(Mtd));
end;

function SelectDirectory(const Caption, InitialDirectory: string;
  out Directory: string): boolean;
begin
  Result:=SelectDirectory(Caption,InitialDirectory,Directory,false);
end;

function SelectDirectory(const Caption, InitialDirectory: string;
  out Directory: string; ShowHidden: boolean; HelpCtx: Longint): boolean;
var
  SelectDirectoryDialog: TSelectDirectoryDialog;
begin
  SelectDirectoryDialog:=TSelectDirectoryDialog.Create(nil);
  try
    if ShowHidden then
      SelectDirectoryDialog.Options:=SelectDirectoryDialog.Options
                                     +[ofForceShowHidden];
    SelectDirectoryDialog.InitialDir:=InitialDirectory;
    SelectDirectoryDialog.Title:=Caption;
    SelectDirectoryDialog.HelpContext:=HelpCtx;
    Result:=SelectDirectoryDialog.Execute;
    if Result then
      Directory:=SelectDirectoryDialog.Filename
    else
      Directory:='';
  finally
    SelectDirectoryDialog.Free;
  end;
end;

function SelectDirectory(out Directory: string;
  Options: TSelectDirOpts; HelpCtx: Longint): Boolean;
var
  SelectDirectoryDialog: TSelectDirectoryDialog;
begin
  SelectDirectoryDialog:=TSelectDirectoryDialog.Create(nil);
  // TODO: sdAllowCreate,
  // TODO: sdPrompt
  try
    SelectDirectoryDialog.HelpContext:=HelpCtx;
    Result:=SelectDirectoryDialog.Execute;
    if Result then begin
      Directory:=SelectDirectoryDialog.Filename;
      if (sdPerformCreate in Options) and (not DirPathExists(Directory)) then
        ForceDirectoriesUTF8(Directory);
    end else
      Directory:='';
  finally
    SelectDirectoryDialog.Free;
  end;
end;

function InputQuery(const ACaption, APrompt : String; MaskInput : Boolean;
  var Value : String) : Boolean;
begin
  Result := LCLIntf.RequestInput(ACaption, ConvertLineEndings(APrompt),
    MaskInput, Value);
end;

function InputQuery(const ACaption, APrompt : String; var Value : String) : Boolean;
begin
  Result := InputQuery(ACaption, APrompt, False, Value);
end;

{ TDummyForInput }

type
  TDummyEditList = array of TEdit;
  PDummyEditList = ^TDummyEditList;

  TDummyForInput = class(TForm)
  public
    FEditsPtr: PDummyEditList;
    FOnCloseEvent: TInputCloseQueryEvent;
    procedure FOnClick(Sender: TObject);
  end;

procedure TDummyForInput.FOnClick(Sender: TObject);
var
  Cfm: boolean;
  Str: array of string;
  i: integer;
begin
  Cfm:= true;
  if Assigned(FOnCloseEvent) then
  begin
    SetLength(Str, Length(FEditsPtr^));
    for i:= 0 to Length(Str)-1 do
      Str[i]:= FEditsPtr^[i].Text;
    FOnCloseEvent(nil, Str, Cfm);
  end;
  if Cfm then
    ModalResult:= mrOk;
end;


function InputQuery(const ACaption: string; const APrompts: array of string;
  var AValues: array of string; ACloseEvent: TInputCloseQueryEvent): boolean;
var
  FPanels: array of TPanel;
  FEdits: array of TEdit;
  FLabels: array of TPanel;
  FButtons: TButtonPanel;
  FForm: TDummyForInput;
  Len, NSpacing, NEditWidth, i: integer;

  function GetPromptCaption(const APrompt: string): string;
  begin
    if (Length(APrompt) > 1) and (APrompt[1] < #32) then
      Result := Copy(APrompt, 2, Length(APrompt) - 1)
    else
      Result := APrompt;
  end;

  function GetPasswordChar(const APrompt: string): Char;
  begin
    if (Length(APrompt) > 1) and (APrompt[1] < #32) then
      Result := '*'
    else
      Result := #0;
  end;

begin
  Result:= false;
  if Length(APrompts)<1 then
    raise EInvalidOperation.Create('InputQuery: prompt array cannot be empty');
  if Length(APrompts)>Length(AValues) then
    raise EInvalidOperation.Create('InputQuery: prompt array length must be <= value array length');

  Len:= Length(AValues);
  SetLength(FPanels, Len);
  SetLength(FLabels, Len);
  SetLength(FEdits, Len);

  FForm:= TDummyForInput.CreateNew(nil);
  FForm.Width:= FForm.Scale96ToForm(600);
  FForm.Height:= FForm.Scale96ToForm(400);
  FForm.BorderStyle:= bsDialog;
  FForm.Position:= poScreenCenter;
  FForm.Caption:= ACaption;
  FForm.FOnCloseEvent:= ACloseEvent;

  NSpacing:= FForm.Scale96ToForm(cInputQuerySpacingSize);
  NEditWidth:= Max(
    FForm.Scale96ToForm(cInputQueryEditSizePixels),
    _InputQueryActiveMonitor.Width * cInputQueryEditSizePercents div 100);

  FButtons:= TButtonPanel.Create(FForm);
  FButtons.Parent:= FForm;
  FButtons.ShowButtons:= [pbOK, pbCancel];
  FButtons.ShowBevel:= false;
  FButtons.OKButton.OnClick:= @FForm.FOnClick;
  FButtons.OKButton.ModalResult:= mrNone;

  for i:= 0 to Len-1 do
  begin
    FPanels[i]:= TPanel.Create(FForm);
    FPanels[i].Parent:= FForm;
    FPanels[i].Align:= alTop;
    FPanels[i].BevelInner:= bvNone;
    FPanels[i].BevelOuter:= bvNone;
    FPanels[i].AutoSize:= true;
    FPanels[i].BorderSpacing.Around:= NSpacing;

    //fix order of panels
    if i>0 then
      FPanels[i].Top:= FPanels[i-1].Top+10;

    FEdits[i]:= TEdit.Create(FForm);
    FEdits[i].Parent:= FPanels[i];
    FEdits[i].Align:= alRight;
    FEdits[i].Width:= NEditWidth;
    FEdits[i].Text:= AValues[i];
    if i<Length(APrompts) then
      FEdits[i].PasswordChar:= GetPasswordChar(APrompts[i]);

    FLabels[i]:= TPanel.Create(FForm);
    FLabels[i].Parent:= FPanels[i];
    FLabels[i].Align:= alRight;
    FLabels[i].BevelInner:= bvNone;
    FLabels[i].BevelOuter:= bvNone;
    if i<Length(APrompts) then
      FLabels[i].Caption:= GetPromptCaption(APrompts[i]);
    FLabels[i].BorderSpacing.Right:= NSpacing;
    FLabels[i].Width:= FLabels[i].Canvas.TextWidth(FLabels[i].Caption);

    FEdits[i].Left:= FForm.Width; // place edits to right
  end;

  FButtons.Align:= alTop;
  FButtons.Top:= FPanels[Len-1].Top+10; // place buttons to bottom

  FForm.AutoSize:= true;
  FForm.ActiveControl:= FEdits[0];
  FForm.FEditsPtr:= @FEdits;

  try
    Result:= FForm.ShowModal=mrOk;
    if Result then
      for i:= 0 to Len-1 do
        AValues[i]:= FEdits[i].Text;
  finally
    FreeAndNil(FForm);
  end;
end;

// included by dialogs.pp


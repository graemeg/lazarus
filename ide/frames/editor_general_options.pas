{
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
unit editor_general_options;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, math,
  // LCL
  LCLProc, LCLType, StdCtrls, Controls, Graphics, ImgList,
  // LazControls
  DividerBevel,
  // SynEdit
  SynEdit, SynHighlighterPas, SynPluginMultiCaret, SynEditTypes,
  // IdeIntf
  IDEOptionsIntf, IDEOptEditorIntf, IDEUtils, SrcEditorIntf,
  // IDE
  EditorOptions, LazarusIDEStrConsts, SourceMarks;

type
  TPreviewEditor = TSynEdit;
  { TEditorGeneralOptionsFrame }

  TEditorGeneralOptionsFrame = class(TAbstractIDEOptionsEditor)
    CaretMoveClearsSelectionCheckBox: TCheckBox;
    SelectAllNoScrollCheckBox: TCheckBox;
    PersistentCursorNoBlinkCheckBox: TCheckBox;
    chkMultiCaretColumnMode: TCheckBox;
    chkMultiCaretMode: TCheckBox;
    chkMultiCaretDelSkipCr: TCheckBox;
    MultiCaretGroupDivider: TDividerBevel;
    MultiCaretOnColumnSelection: TCheckBox;
    CursorSkipsTabCheckBox: TCheckBox;
    CaretGroupDivider: TDividerBevel;
    BlockGroupDivider: TDividerBevel;
    ScrollGroupDivider: TDividerBevel;
    UndoGroupDivider: TDividerBevel;
    EndKeyJumpsToNearestStartCheckBox: TCheckBox;
    KeepCursorXCheckBox: TCheckBox;
    CenterLabel:TLabel;
    OverwriteBlockCheckBox: TCheckBox;
    PersistentCursorCheckBox: TCheckBox;
    AlwaysVisibleCursorCheckBox: TCheckBox;
    CursorSkipsSelectionCheckBox: TCheckBox;
    HomeKeyJumpsToNearestStartCheckBox: TCheckBox;
    PersistentBlockCheckBox: TCheckBox;
    HalfPageScrollCheckBox: TCheckBox;
    ScrollPastEndFileCheckBox: TCheckBox;
    ScrollPastEndLineCheckBox: TCheckBox;
    ScrollByOneLessCheckBox: TCheckBox;
    UndoAfterSaveCheckBox: TCheckBox;
    GroupUndoCheckBox: TCheckBox;
    UndoLimitComboBox: TComboBox;
    UndoLimitLabel: TLabel;
    chkScrollHint: TCheckBox;
    procedure AlwaysVisibleCursorCheckBoxChange(Sender: TObject);
    procedure CaretMoveClearsSelectionCheckBoxChange(Sender: TObject);
    procedure CursorSkipsSelectionCheckBoxChange(Sender: TObject);
    procedure CursorSkipsTabCheckBoxChange(Sender: TObject);
    procedure EndKeyJumpsToNearestStartCheckBoxChange(Sender: TObject);
    procedure GroupUndoCheckBoxChange(Sender: TObject);
    procedure HalfPageScrollCheckBoxChange(Sender: TObject);
    procedure HomeKeyJumpsToNearestStartCheckBoxChange(Sender: TObject);
    procedure KeepCursorXCheckBoxChange(Sender: TObject);
    procedure OverwriteBlockCheckBoxChange(Sender: TObject);
    procedure PersistentBlockCheckBoxChange(Sender: TObject);
    procedure PersistentCursorCheckBoxChange(Sender: TObject);
    procedure PersistentCursorNoBlinkCheckBoxChange(Sender: TObject);
    procedure ScrollByOneLessCheckBoxChange(Sender: TObject);
    procedure ScrollPastEndFileCheckBoxChange(Sender: TObject);
    procedure ScrollPastEndLineCheckBoxChange(Sender: TObject);
  private
    FDialog: TAbstractOptionsEditorDialog;
    FPasExtendedKeywordsMode: Boolean;
    FPasStringKeywordMode: TSynPasStringMode;
    function DefaultBookmarkImages: TCustomImageList;
    procedure SetExtendedKeywordsMode(const AValue: Boolean);
    procedure SetStringKeywordMode(const AValue: TSynPasStringMode);
  protected
    procedure CreateHandle; override;
  public
    PreviewEdits: array of TPreviewEditor;
    procedure AddPreviewEdit(AEditor: TPreviewEditor);
    procedure SetPreviewOption(AValue: Boolean; AnOption: TSynEditorOption); overload;
    procedure SetPreviewOption(AValue: Boolean; AnOption: TSynEditorOption2); overload;
    procedure UpdatePrevieEdits;

    constructor Create(AOwner: TComponent); override;
    function GetTitle: String; override;
    procedure Setup(ADialog: TAbstractOptionsEditorDialog); override;
    procedure ReadSettings(AOptions: TAbstractIDEOptions); override;
    procedure WriteSettings(AOptions: TAbstractIDEOptions); override;
    class function SupportedOptionsClass: TAbstractIDEOptionsClass; override;
    // current previewmode
    property PasExtendedKeywordsMode: Boolean
             read FPasExtendedKeywordsMode write SetExtendedKeywordsMode default False;
    property PasStringKeywordMode: TSynPasStringMode
             read FPasStringKeywordMode write SetStringKeywordMode default spsmDefault;
  end;

implementation

{$R *.lfm}

{ TEditorGeneralOptionsFrame }

function TEditorGeneralOptionsFrame.GetTitle: String;
begin
  Result := lisGeneral;
end;

procedure TEditorGeneralOptionsFrame.Setup(ADialog: TAbstractOptionsEditorDialog);
begin
  FDialog := ADialog;

  // undo
  UndoGroupDivider.Caption := dlgUndoGroupOptions;
  UndoAfterSaveCheckBox.Caption := dlgUndoAfterSave;
  GroupUndoCheckBox.Caption := dlgGroupUndo;
  UndoLimitLabel.Caption := dlgUndoLimit;

  // scroll
  ScrollGroupDivider.Caption := dlgScrollGroupOptions;
  HalfPageScrollCheckBox.Caption := dlgHalfPageScroll;
  ScrollByOneLessCheckBox.Caption := dlgScrollByOneLess;
  ScrollPastEndFileCheckBox.Caption := dlgScrollPastEndFile;
  ScrollPastEndLineCheckBox.Caption := dlgScrollPastEndLine;
  chkScrollHint.Caption := dlgScrollHint;

  // caret + key navigation
  CaretGroupDivider.Caption := dlgCaretGroupOptions;
  KeepCursorXCheckBox.Caption := dlgKeepCursorX;
  PersistentCursorCheckBox.Caption := dlgPersistentCursor;
  PersistentCursorNoBlinkCheckBox.Caption := dlgPersistentCursorNoBlink;
  AlwaysVisibleCursorCheckBox.Caption := dlgAlwaysVisibleCursor;
  CursorSkipsSelectionCheckBox.Caption := dlgCursorSkipsSelection;
  CaretMoveClearsSelectionCheckBox.Caption := dlgCursorMoveClearsSelection;
  //dlgCursorMoveClearsSelection
  CursorSkipsTabCheckBox.Caption := dlgCursorSkipsTab;
  HomeKeyJumpsToNearestStartCheckBox.Caption := dlgHomeKeyJumpsToNearestStart;
  EndKeyJumpsToNearestStartCheckBox.Caption := dlgEndKeyJumpsToNearestStart;
  SelectAllNoScrollCheckBox.Caption := dlgSelectAllNoScroll;

  // multi caret
  MultiCaretGroupDivider.Caption := dlgMultiCaretGroupOptions;
  MultiCaretOnColumnSelection.Caption := dlgMultiCaretOnColumnSelection;
  chkMultiCaretColumnMode.Caption := dlgMultiCaretColumnMode;
  chkMultiCaretMode.Caption := dlgMultiCaretMode;
  chkMultiCaretDelSkipCr.Caption := dlgMultiCaretDelSkipCr;

  // Block
  BlockGroupDivider.Caption := dlgBlockGroupOptions;
  PersistentBlockCheckBox.Caption := dlgPersistentBlock;
  OverwriteBlockCheckBox.Caption := dlgOverwriteBlock;
end;

procedure TEditorGeneralOptionsFrame.ReadSettings(AOptions: TAbstractIDEOptions);
var
  i: integer;
begin
  with AOptions as TEditorOptions do
  begin
    // undo
    UndoAfterSaveCheckBox.Checked := UndoAfterSave;
    GroupUndoCheckBox.Checked := eoGroupUndo in SynEditOptions;
    SetComboBoxText(UndoLimitComboBox, IntToStr(UndoLimit), cstCaseInsensitive);

    // scroll
    HalfPageScrollCheckBox.Checked := eoHalfPageScroll in SynEditOptions;
    ScrollByOneLessCheckBox.Checked := eoScrollByOneLess in SynEditOptions;
    ScrollPastEndFileCheckBox.Checked := eoScrollPastEoF in SynEditOptions;
    ScrollPastEndLineCheckBox.Checked := eoScrollPastEoL in SynEditOptions;
    chkScrollHint.Checked := eoShowScrollHint in SynEditOptions;

    // cursor
    KeepCursorXCheckBox.Checked := eoKeepCaretX in SynEditOptions;
    PersistentCursorCheckBox.Checked := eoPersistentCaret in SynEditOptions;
    PersistentCursorNoBlinkCheckBox.Checked := eoPersistentCaretStopBlink in SynEditOptions2;
    AlwaysVisibleCursorCheckBox.Checked := eoAlwaysVisibleCaret in SynEditOptions2;
    CursorSkipsSelectionCheckBox.Checked := eoCaretSkipsSelection in SynEditOptions2;
    CaretMoveClearsSelectionCheckBox.Checked := eoCaretMoveEndsSelection in SynEditOptions2;
    CursorSkipsTabCheckBox.Checked := eoCaretSkipTab in SynEditOptions2;
    HomeKeyJumpsToNearestStartCheckBox.Checked := eoEnhanceHomeKey in SynEditOptions;
    EndKeyJumpsToNearestStartCheckBox.Checked := eoEnhanceEndKey in SynEditOptions2;
    MultiCaretOnColumnSelection.Checked := MultiCaretOnColumnSelect;
    chkMultiCaretColumnMode.Checked := MultiCaretDefaultColumnSelectMode = mcmMoveAllCarets;
    chkMultiCaretMode.Checked := MultiCaretDefaultMode = mcmMoveAllCarets;
    chkMultiCaretDelSkipCr.Checked := MultiCaretDeleteSkipLineBreak;
    SelectAllNoScrollCheckBox.Checked := eoNoScrollOnSelectRange in SynEditOptions2;

    // block
    PersistentBlockCheckBox.Checked := eoPersistentBlock in SynEditOptions2;
    OverwriteBlockCheckBox.Checked := eoOverwriteBlock in SynEditOptions2;

    for i := Low(PreviewEdits) to High(PreviewEdits) do
      if PreviewEdits[i] <> nil then
        GetSynEditPreviewSettings(PreviewEdits[i]);
  end;
end;

procedure TEditorGeneralOptionsFrame.WriteSettings(AOptions: TAbstractIDEOptions);

  procedure UpdateOptionFromBool(AValue: Boolean; AnOption: TSynEditorOption); overload;
  begin
    if AValue then
      TEditorOptions(AOptions).SynEditOptions := TEditorOptions(AOptions).SynEditOptions + [AnOption]
    else
      TEditorOptions(AOptions).SynEditOptions := TEditorOptions(AOptions).SynEditOptions - [AnOption];
  end;

  procedure UpdateOptionFromBool(AValue: Boolean; AnOption: TSynEditorOption2); overload;
  begin
    if AValue then
      TEditorOptions(AOptions).SynEditOptions2 := TEditorOptions(AOptions).SynEditOptions2 + [AnOption]
    else
      TEditorOptions(AOptions).SynEditOptions2 := TEditorOptions(AOptions).SynEditOptions2 - [AnOption];
  end;

var
  i: integer;
begin
  with AOptions as TEditorOptions do
  begin
    // undo
    UndoAfterSave := UndoAfterSaveCheckBox.Checked;
    UpdateOptionFromBool(GroupUndoCheckBox.Checked, eoGroupUndo);
    i := StrToIntDef(UndoLimitComboBox.Text, 32767);
    if i < 1 then
      i := 1;
    if i > 32767 then
      i := 32767;
    UndoLimit := i;

    // scroll
    UpdateOptionFromBool(HalfPageScrollCheckBox.Checked, eoHalfPageScroll);
    UpdateOptionFromBool(ScrollByOneLessCheckBox.Checked, eoScrollByOneLess);
    UpdateOptionFromBool(ScrollPastEndFileCheckBox.Checked, eoScrollPastEoF);
    UpdateOptionFromBool(ScrollPastEndLineCheckBox.Checked, eoScrollPastEoL);
    UpdateOptionFromBool(chkScrollHint.Checked, eoShowScrollHint);

    // cursor
    UpdateOptionFromBool(KeepCursorXCheckBox.Checked, eoKeepCaretX);
    UpdateOptionFromBool(PersistentCursorCheckBox.Checked, eoPersistentCaret);
    UpdateOptionFromBool(PersistentCursorNoBlinkCheckBox.Checked, eoPersistentCaretStopBlink);
    UpdateOptionFromBool(AlwaysVisibleCursorCheckBox.Checked, eoAlwaysVisibleCaret);
    UpdateOptionFromBool(CursorSkipsSelectionCheckBox.Checked, eoCaretSkipsSelection);
    UpdateOptionFromBool(CaretMoveClearsSelectionCheckBox.Checked, eoCaretMoveEndsSelection);
    UpdateOptionFromBool(CursorSkipsTabCheckBox.Checked, eoCaretSkipTab);
    UpdateOptionFromBool(HomeKeyJumpsToNearestStartCheckBox.Checked, eoEnhanceHomeKey);
    UpdateOptionFromBool(EndKeyJumpsToNearestStartCheckBox.Checked, eoEnhanceEndKey);
    MultiCaretOnColumnSelect := MultiCaretOnColumnSelection.Checked;
    if chkMultiCaretColumnMode.Checked then
      MultiCaretDefaultColumnSelectMode := mcmMoveAllCarets
    else
      MultiCaretDefaultColumnSelectMode := mcmCancelOnCaretMove;
    if chkMultiCaretMode.Checked then
      MultiCaretDefaultMode := mcmMoveAllCarets
    else
      MultiCaretDefaultMode := mcmCancelOnCaretMove;
    MultiCaretDeleteSkipLineBreak := chkMultiCaretDelSkipCr.Checked;
    UpdateOptionFromBool(SelectAllNoScrollCheckBox.Checked, eoNoScrollOnSelectRange);

    // block
    UpdateOptionFromBool(PersistentBlockCheckBox.Checked, eoPersistentBlock);
    UpdateOptionFromBool(OverwriteBlockCheckBox.Checked, eoOverwriteBlock);
  end;
end;

class function TEditorGeneralOptionsFrame.SupportedOptionsClass: TAbstractIDEOptionsClass;
begin
  Result := TEditorOptions;
end;

procedure TEditorGeneralOptionsFrame.SetPreviewOption(AValue: Boolean; AnOption: TSynEditorOption);
var
  a: Integer;
begin
  for a := Low(PreviewEdits) to High(PreviewEdits) do
  begin
    if PreviewEdits[a] <> nil then
      if AValue then
        PreviewEdits[a].Options := PreviewEdits[a].Options + [AnOption]
      else
        PreviewEdits[a].Options := PreviewEdits[a].Options - [AnOption];
  end;
end;

procedure TEditorGeneralOptionsFrame.SetPreviewOption(AValue: Boolean; AnOption: TSynEditorOption2);
var
  a: Integer;
begin
  for a := Low(PreviewEdits) to High(PreviewEdits) do
  begin
    if PreviewEdits[a] <> nil then
      if AValue then
        PreviewEdits[a].Options2 := PreviewEdits[a].Options2 + [AnOption]
      else
        PreviewEdits[a].Options2 := PreviewEdits[a].Options2 - [AnOption];
  end;
end;

procedure TEditorGeneralOptionsFrame.UpdatePrevieEdits;
var
  a: Integer;
begin
  for a := Low(PreviewEdits) to High(PreviewEdits) do
    if PreviewEdits[a].Highlighter is TSynPasSyn then begin
      TSynPasSyn(PreviewEdits[a].Highlighter).ExtendedKeywordsMode := PasExtendedKeywordsMode;
      TSynPasSyn(PreviewEdits[a].Highlighter).StringKeywordMode := PasStringKeywordMode;
    end;
end;

procedure TEditorGeneralOptionsFrame.AlwaysVisibleCursorCheckBoxChange(
  Sender: TObject);
begin
  SetPreviewOption(AlwaysVisibleCursorCheckBox.Checked, eoAlwaysVisibleCaret);
end;

procedure TEditorGeneralOptionsFrame.CaretMoveClearsSelectionCheckBoxChange(
  Sender: TObject);
begin
  SetPreviewOption(CaretMoveClearsSelectionCheckBox.Checked, eoCaretMoveEndsSelection);
end;

procedure TEditorGeneralOptionsFrame.CursorSkipsSelectionCheckBoxChange(
  Sender: TObject);
begin
  SetPreviewOption(CursorSkipsSelectionCheckBox.Checked, eoCaretSkipsSelection);
end;

procedure TEditorGeneralOptionsFrame.CursorSkipsTabCheckBoxChange(Sender: TObject);
begin
  SetPreviewOption(CursorSkipsTabCheckBox.Checked, eoCaretSkipTab);
end;

procedure TEditorGeneralOptionsFrame.EndKeyJumpsToNearestStartCheckBoxChange(
  Sender: TObject);
begin
  SetPreviewOption(EndKeyJumpsToNearestStartCheckBox.Checked, eoEnhanceEndKey);
end;

procedure TEditorGeneralOptionsFrame.GroupUndoCheckBoxChange(Sender: TObject);
begin
  SetPreviewOption(GroupUndoCheckBox.Checked, eoGroupUndo);
end;

procedure TEditorGeneralOptionsFrame.HalfPageScrollCheckBoxChange(
  Sender: TObject);
begin
  SetPreviewOption(HalfPageScrollCheckBox.Checked, eoHalfPageScroll);
end;

procedure TEditorGeneralOptionsFrame.HomeKeyJumpsToNearestStartCheckBoxChange(
  Sender: TObject);
begin
  SetPreviewOption(HomeKeyJumpsToNearestStartCheckBox.Checked, eoEnhanceHomeKey);
end;

procedure TEditorGeneralOptionsFrame.KeepCursorXCheckBoxChange(Sender: TObject);
begin
  SetPreviewOption(KeepCursorXCheckBox.Checked, eoKeepCaretX);
end;

procedure TEditorGeneralOptionsFrame.OverwriteBlockCheckBoxChange(Sender: TObject);
begin
  SetPreviewOption(KeepCursorXCheckBox.Checked, eoOverwriteBlock);
end;

procedure TEditorGeneralOptionsFrame.PersistentBlockCheckBoxChange(Sender: TObject);
begin
  SetPreviewOption(PersistentBlockCheckBox.Checked, eoPersistentBlock);
end;

procedure TEditorGeneralOptionsFrame.PersistentCursorCheckBoxChange(
  Sender: TObject);
begin
  SetPreviewOption(PersistentCursorCheckBox.Checked, eoPersistentCaret);
end;

procedure TEditorGeneralOptionsFrame.PersistentCursorNoBlinkCheckBoxChange(
  Sender: TObject);
begin
  SetPreviewOption(PersistentCursorNoBlinkCheckBox.Checked, eoPersistentCaretStopBlink);
end;

procedure TEditorGeneralOptionsFrame.ScrollByOneLessCheckBoxChange(
  Sender: TObject);
begin
  SetPreviewOption(ScrollByOneLessCheckBox.Checked, eoScrollByOneLess);
end;

procedure TEditorGeneralOptionsFrame.ScrollPastEndFileCheckBoxChange(
  Sender: TObject);
begin
  SetPreviewOption(ScrollPastEndFileCheckBox.Checked, eoScrollPastEoF);
end;

procedure TEditorGeneralOptionsFrame.ScrollPastEndLineCheckBoxChange(
  Sender: TObject);
begin
  SetPreviewOption(ScrollPastEndLineCheckBox.Checked, eoScrollPastEoL);
end;

function TEditorGeneralOptionsFrame.DefaultBookmarkImages: TCustomImageList;
begin
  Result := SourceEditorMarks.ImgList;
end;

procedure TEditorGeneralOptionsFrame.SetExtendedKeywordsMode(const AValue: Boolean);
begin
  if FPasExtendedKeywordsMode = AValue then exit;
  FPasExtendedKeywordsMode := AValue;
  UpdatePrevieEdits;
end;

procedure TEditorGeneralOptionsFrame.SetStringKeywordMode(const AValue: TSynPasStringMode);
begin
  if FPasStringKeywordMode = AValue then exit;
  FPasStringKeywordMode := AValue;
  UpdatePrevieEdits;
end;

procedure TEditorGeneralOptionsFrame.CreateHandle;
var
  i, w: Integer;
  c: TControl;
begin
  inherited;
  w := 150;
  for i := 0 to ControlCount - 1 do begin
    c := Controls[i];
    if not (c is TCheckBox) then Continue;
    w := Max(w, Canvas.TextExtent(c.Caption).cx);
  end;
  Constraints.MinWidth := 2 * w + 60;
end;

procedure TEditorGeneralOptionsFrame.AddPreviewEdit(AEditor: TPreviewEditor);
begin
  SetLength(PreviewEdits, Length(PreviewEdits) + 1);
  PreviewEdits[Length(PreviewEdits)-1] := AEditor;
  if AEditor.BookMarkOptions.BookmarkImages = nil then
    AEditor.BookMarkOptions.BookmarkImages := DefaultBookmarkImages;
end;

constructor TEditorGeneralOptionsFrame.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  PreviewEdits := nil;
  if EditorOpts <> nil then begin
    FPasExtendedKeywordsMode := EditorOpts.PasExtendedKeywordsMode;
    FPasStringKeywordMode := EditorOpts.PasStringKeywordMode;
  end;
end;

initialization
  RegisterIDEOptionsEditor(GroupEditor, TEditorGeneralOptionsFrame, EdtOptionsGeneral);
end.


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
unit formed_options;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils,
  // LCL
  Graphics, Forms, StdCtrls, Dialogs, Spin, ColorBox,
  // IdeIntf
  IDEOptionsIntf, IDEOptEditorIntf,
  // IDE
  EnvironmentOpts, LazarusIDEStrConsts;

type
  TDesignerColor = (
    dcGrid,
    dcGridLinesLeftTop,
    dcGridLinesRightBottom,
    dcGrabber,
    dcMarker,
    dcRuberbandSelection,
    dcRuberbandCreation,
    dcNonFormBackgroundColor
  );

  { TFormEditorOptionsFrame }

  TFormEditorOptionsFrame = class(TAbstractIDEOptionsEditor)
    FormTitleBarChangesObjectInspectorCheckBox: TCheckBox;
    ForceDPIScalingInDesignTimeCheckBox: TCheckBox;
    SwitchToFavoritesOITabCheckBox:TCheckBox;
    CheckPackagesOnFormCreateCheckBox: TCheckBox;
    OpenDesignerOnOpenUnitCheckBox: TCheckBox;
    ColorBox: TColorBox;
    ColorsListBox: TColorListBox;
    CreateCompFocusNameCheckBox: TCheckBox;
    FormEditMiscGroupBox: TGroupBox;
    GridGroupBox: TGroupBox;
    GridSizeXSpinEdit: TSpinEdit;
    GridSizeXLabel: TLabel;
    GridSizeYSpinEdit: TSpinEdit;
    GridSizeYLabel: TLabel;
    GuideLinesGroupBox: TGroupBox;
    DesignerColorsGroupBox: TGroupBox;
    RightClickSelectsCheckBox: TCheckBox;
    RubberbandSelectsGrandChildsCheckBox: TCheckBox;
    ShowBorderSpaceCheckBox: TCheckBox;
    ShowComponentCaptionsCheckBox: TCheckBox;
    ShowEditorHintsCheckBox: TCheckBox;
    ShowGridCheckBox: TCheckBox;
    ShowGuideLinesCheckBox: TCheckBox;
    SnapToGridCheckBox: TCheckBox;
    SnapToGuideLinesCheckBox: TCheckBox;
    procedure ColorBoxChange(Sender: TObject);
    procedure ColorsListBoxGetColors(Sender: TCustomColorListBox; Items: TStrings);
    procedure ColorsListBoxSelectionChange(Sender: TObject; User: boolean);
    procedure CreateCompFocusNameCheckBoxChange(Sender: TObject);
    procedure FrameResize(Sender: TObject);
  private
    FLoaded: Boolean;
    procedure ChangeColor(AIndex: Integer; NewColor: TColor);
  public
    function GetTitle: String; override;
    procedure Setup({%H-}ADialog: TAbstractOptionsEditorDialog); override;
    procedure ReadSettings(AOptions: TAbstractIDEOptions); override;
    procedure WriteSettings(AOptions: TAbstractIDEOptions); override;
    class function SupportedOptionsClass: TAbstractIDEOptionsClass; override;
  end;

implementation

{$R *.lfm}

{ TFormEditorOptionsFrame }

function TFormEditorOptionsFrame.GetTitle: String;
begin
  Result := dlgFrmEditor;
end;

procedure TFormEditorOptionsFrame.Setup(ADialog: TAbstractOptionsEditorDialog);
  procedure SetupGridGroupBox;
  begin
    ShowGridCheckBox.Caption:=dlgQShowGrid;
    ShowGridCheckBox.Hint:=dlgGridConsistsOfSmallDots;
    ShowBorderSpaceCheckBox.Caption:=dlgQShowBorderSpacing;
    ShowBorderSpaceCheckBox.Hint:=dlgBorderSpaceCanBeSetInAnchorEditor;
    SnapToGridCheckBox.Caption:=dlgQSnapToGrid;
    SnapToGridCheckBox.Hint:=dlgDistanceBetweenGridPointsIsSmallestStep;
    GridSizeXSpinEdit.Hint:=dlgGridXHint;
    GridSizeXLabel.Caption:=dlgGridX;
    GridSizeYSpinEdit.Hint:=dlgGridYHint;
    GridSizeYLabel.Caption:=dlgGridY;
  end;

  procedure SetupGuideLinesGroupBox;
  begin
    ShowGuideLinesCheckBox.Caption:=dlgGuideLines;
    ShowGuideLinesCheckBox.Hint:=dlgGuideLinesHint;
    SnapToGuideLinesCheckBox.Caption:=dlgSnapGuideLines;
    SnapToGuideLinesCheckBox.Hint:=dlgSnapGuideLinesHint;
  end;

  procedure SetupMiscGroupBox;
  begin
    RubberbandSelectsGrandChildsCheckBox.Caption:=dlgRubberbandSelectsGrandChildren;
    RubberbandSelectsGrandChildsCheckBox.Hint:=dlgSelectAllChildControls;
    ShowComponentCaptionsCheckBox.Caption:=dlgShowCaptionsOfNonVisuals;
    ShowComponentCaptionsCheckBox.Hint:=dlgDrawComponentsNameBelowIt;
    ShowEditorHintsCheckBox.Caption:=dlgShowDesignerHints;
    ShowEditorHintsCheckBox.Hint:=dlgShowDesignerHintsHint;
    OpenDesignerOnOpenUnitCheckBox.Caption:=lisOpenDesignerOnOpenUnit;
    OpenDesignerOnOpenUnitCheckBox.Hint:=lisOpenDesignerOnOpenUnitHint;
    RightClickSelectsCheckBox.Caption:=dlgRightClickSelects;
    RightClickSelectsCheckBox.Hint:=dlgComponentUnderMouseCursorIsFirstSelected;
    CreateCompFocusNameCheckBox.Caption:=lisAskNameOnCreate;
    CreateCompFocusNameCheckBox.Hint:=lisAskForComponentNameAfterPuttingItOnForm;
    SwitchToFavoritesOITabCheckBox.Caption:=lisOFESwitchToObjectInspectorFavoritesTab;
    SwitchToFavoritesOITabCheckBox.Hint:=lisSwitchToFavoritesTabAfterAsking;
    CheckPackagesOnFormCreateCheckBox.Caption:=dlgCheckPackagesOnFormCreate;
    CheckPackagesOnFormCreateCheckBox.Hint:=dlgCheckPackagesOnFormCreateHint;
    FormTitleBarChangesObjectInspectorCheckBox.Caption:=dlgFormTitleBarChangesObjectInspector;
    FormTitleBarChangesObjectInspectorCheckBox.Hint:=dlgFormTitleBarChangesObjectInspectorHint;
    ForceDPIScalingInDesignTimeCheckBox.Caption:=dlgForceDPIScalingInDesignTime;
    ForceDPIScalingInDesignTimeCheckBox.Hint:=dlgForceDPIScalingInDesignTimeHint;
  end;
begin
  GridGroupBox.Caption := dlgEnvGrid;
  GuideLinesGroupBox.Caption := dlgEnvLGuideLines;
  FormEditMiscGroupBox.Caption := dlgEnvMisc;
  DesignerColorsGroupBox.Caption := dlgColors;
  SetupGridGroupBox;
  SetupGuideLinesGroupBox;
  SetupMiscGroupBox;
  FLoaded := False;
end;

procedure TFormEditorOptionsFrame.ReadSettings(AOptions: TAbstractIDEOptions);
begin
  with AOptions as TEnvironmentOptions do
  begin
    // read colors
    ColorsListBox.Items.Objects[Ord(dcGrid)] := TObject(PtrInt(GridColor));
    ColorsListBox.Items.Objects[Ord(dcGridLinesLeftTop)] := TObject(PtrInt(GuideLineColorLeftTop));
    ColorsListBox.Items.Objects[Ord(dcGridLinesRightBottom)] := TObject(PtrInt(GuideLineColorRightBottom));
    ColorsListBox.Items.Objects[Ord(dcGrabber)] := TObject(PtrInt(GrabberColor));
    ColorsListBox.Items.Objects[Ord(dcMarker)] := TObject(PtrInt(MarkerColor));
    ColorsListBox.Items.Objects[Ord(dcNonFormBackgroundColor)] := TObject(PtrInt(NonFormBackgroundColor));
    ColorsListBox.Items.Objects[Ord(dcRuberbandSelection)] := TObject(PtrInt(RubberbandSelectionColor));
    ColorsListBox.Items.Objects[Ord(dcRuberbandCreation)] := TObject(PtrInt(RubberbandCreationColor));

    ShowBorderSpaceCheckBox.Checked := ShowBorderSpacing;
    ShowGridCheckBox.Checked := ShowGrid;
    SnapToGridCheckBox.Checked := SnapToGrid;
    GridSizeXSpinEdit.Value := GridSizeX;
    GridSizeYSpinEdit.Value := GridSizeY;
    ShowGuideLinesCheckBox.Checked := ShowGuideLines;
    SnapToGuideLinesCheckBox.Checked := SnapToGuideLines;
    ShowComponentCaptionsCheckBox.Checked := ShowComponentCaptions;
    ShowEditorHintsCheckBox.Checked := ShowEditorHints;
    OpenDesignerOnOpenUnitCheckBox.Checked := AutoCreateFormsOnOpen;
    CheckPackagesOnFormCreateCheckBox.Checked := CheckPackagesOnFormCreate;
    RightClickSelectsCheckBox.Checked := RightClickSelects;
    RubberbandSelectsGrandChildsCheckBox.Checked := RubberbandSelectsGrandChilds;
    CreateCompFocusNameCheckBox.Checked := CreateComponentFocusNameProperty;
    SwitchToFavoritesOITabCheckBox.Checked := SwitchToFavoritesOITab;
    SwitchToFavoritesOITabCheckBox.Enabled := CreateCompFocusNameCheckBox.Checked;
    FormTitleBarChangesObjectInspectorCheckBox.Checked := FormTitleBarChangesObjectInspector;
    ForceDPIScalingInDesignTimeCheckBox.Checked := ForceDPIScalingInDesignTime;
  end;
  FLoaded := True;
end;

procedure TFormEditorOptionsFrame.WriteSettings(AOptions: TAbstractIDEOptions);
begin
  with AOptions as TEnvironmentOptions do
  begin
    // write colors
    GridColor := ColorsListBox.Colors[Ord(dcGrid)];
    GuideLineColorLeftTop := ColorsListBox.Colors[Ord(dcGridLinesLeftTop)];
    GuideLineColorRightBottom := ColorsListBox.Colors[Ord(dcGridLinesRightBottom)];
    GrabberColor := ColorsListBox.Colors[Ord(dcGrabber)];
    MarkerColor := ColorsListBox.Colors[Ord(dcMarker)];
    NonFormBackgroundColor := ColorsListBox.Colors[Ord(dcNonFormBackgroundColor)];
    RubberbandSelectionColor := ColorsListBox.Colors[Ord(dcRuberbandSelection)];
    RubberbandCreationColor := ColorsListBox.Colors[Ord(dcRuberbandCreation)];

    ShowBorderSpacing := ShowBorderSpaceCheckBox.Checked;
    ShowGrid := ShowGridCheckBox.Checked;
    SnapToGrid := SnapToGridCheckBox.Checked;
    GridSizeX := GridSizeXSpinEdit.Value;
    GridSizeY := GridSizeYSpinEdit.Value;
    ShowGuideLines := ShowGuideLinesCheckBox.Checked;
    SnapToGuideLines := SnapToGuideLinesCheckBox.Checked;
    ShowComponentCaptions := ShowComponentCaptionsCheckBox.Checked;
    ShowEditorHints := ShowEditorHintsCheckBox.Checked;
    AutoCreateFormsOnOpen := OpenDesignerOnOpenUnitCheckBox.Checked;
    CheckPackagesOnFormCreate := CheckPackagesOnFormCreateCheckBox.Checked;
    RightClickSelects := RightClickSelectsCheckBox.Checked;
    RubberbandSelectsGrandChilds := RubberbandSelectsGrandChildsCheckBox.Checked;
    CreateComponentFocusNameProperty := CreateCompFocusNameCheckBox.Checked;
    SwitchToFavoritesOITab := SwitchToFavoritesOITabCheckBox.Checked;
    FormTitleBarChangesObjectInspector := FormTitleBarChangesObjectInspectorCheckBox.Checked;
    ForceDPIScalingInDesignTime := ForceDPIScalingInDesignTimeCheckBox.Checked;
  end;
end;

procedure TFormEditorOptionsFrame.FrameResize(Sender: TObject);
var
  w: Integer;
begin
  w := ((ClientWidth - 3 * 5) * 5) div 10;
  GridGroupBox.Width := w;
  FormEditMiscGroupBox.Width := GridGroupBox.Width;
end;

procedure TFormEditorOptionsFrame.ChangeColor(AIndex: Integer; NewColor: TColor);
begin
  ColorsListBox.Items.Objects[AIndex] := TObject(PtrInt(NewColor));
end;

procedure TFormEditorOptionsFrame.ColorsListBoxGetColors(
  Sender: TCustomColorListBox; Items: TStrings);
begin
  Items.Add(dlgGridColor);
  Items.Add(dlgLeftTopClr);
  Items.Add(dlgRightBottomClr);
  Items.Add(dlgGrabberColor);
  Items.Add(dlgMarkerColor);
  Items.Add(dlgRuberbandSelectionColor);
  Items.Add(dlgRuberbandCreationColor);
  Items.Add(dlgNonFormBackgroundColor);
end;

procedure TFormEditorOptionsFrame.ColorBoxChange(Sender: TObject);
begin
  if not FLoaded or (ColorsListBox.ItemIndex < 0) then
    Exit;
  ChangeColor(ColorsListBox.ItemIndex, ColorBox.Selected);
  ColorsListBox.Invalidate;
end;

procedure TFormEditorOptionsFrame.ColorsListBoxSelectionChange(Sender: TObject; User: boolean);
begin
  if not (FLoaded and User) then
    Exit;
  ColorBox.Selected := ColorsListBox.Selected;
end;

procedure TFormEditorOptionsFrame.CreateCompFocusNameCheckBoxChange(Sender: TObject);
begin
  SwitchToFavoritesOITabCheckBox.Enabled := CreateCompFocusNameCheckBox.Checked;
end;

class function TFormEditorOptionsFrame.SupportedOptionsClass: TAbstractIDEOptionsClass;
begin
  Result := TEnvironmentOptions;
end;

initialization
  RegisterIDEOptionsEditor(GroupEnvironment, TFormEditorOptionsFrame, EnvOptionsFormEd);
end.


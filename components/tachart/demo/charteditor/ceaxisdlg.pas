unit ceAxisDlg;

{$mode objfpc}{$H+}
{$WARN 6058 off : Call to subroutine "$1" marked as inline is not inlined}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, ButtonPanel,
  ExtCtrls, Buttons, ComCtrls, Spin,
  TAChartAxis, TAChartAxisUtils, TATextElements, TAChartCombos, TAGraph,
  ceShapeBrushPenMarginsFrame, ceFontFrame, cePenFrame;

type

  TChartAxisParams = record
    // General visibility
    Visible: Boolean;

    // Axis title
    TitleVisible: Boolean;
    TitleText: String;
    TitleAlignment: TAlignment;
    TitleFontName: String;
    TitleFontSize: Integer;
    TitleFontStyle: TFontStyles;
    TitleFontColor: TColor;
    TitleFontOrientation: Integer;
    TitleDistance: Integer;
    TitleShape: TChartLabelShape;
    TitleBackgroundStyle: TBrushStyle;
    TitleBackgroundColor: TColor;
    TitleBorderVisible: Boolean;
    TitleBorderColor: TColor;
    TitleMarginLeft: Integer;
    TitleMarginTop: Integer;
    TitleMarginRight: Integer;
    TitleMarginBottom: Integer;

    // Axis range
    Maximum: Double;
    Minimum: Double;
    UseMax: Boolean;
    UseMin: Boolean;
    Inverted: Boolean;

    // Tick labels
    LabelsVisible: Boolean;
    LabelsFormat: String;
    LabelsDistance: Integer;
    TickLength: Integer;
    TickLengthInner: Integer;
    TickColor: TColor;
    LabelFontName: String;
    LabelFontSize: Integer;
    LabelFontStyle: TFontStyles;
    LabelFontColor: TColor;
    LabelFontOrientation: Integer;
    LabelShape: TChartLabelShape;
    LabelBackgroundStyle: TBrushStyle;
    LabelBackgroundColor: TColor;
    LabelBorderVisible: Boolean;
    LabelBorderColor: TColor;
    LabelMarginLeft: Integer;
    LabelMarginTop: Integer;
    LabelMarginRight: Integer;
    LabelMarginBottom: Integer;

    // Grid
    GridVisible: Boolean;
    GridPenStyle: TPenStyle;
    GridPenWidth: Integer;
    GridPenColor: TColor;

    // Frame
    FrameVisible: Boolean;
    FramePenStyle: TPenStyle;
    FramePenWidth: Integer;
    FramePenColor: TColor;

    // Arrow
    ArrowVisible: Boolean;
    ArrowBaseLength: Integer;
    ArrowLength: Integer;
    ArrowWidth: Integer;
  end;

  { TChartAxisEditor }

  TChartAxisEditorPage = (aepTitle, aepLabels, aepGrid, aepLine);

  TChartAxisEditor = class(TForm)
    ButtonPanel: TButtonPanel;
    Bevel1: TBevel;
    Bevel2: TBevel;
    Spacer: TBevel;
    Bevel4: TBevel;
    cbAxisLineVisible: TCheckBox;
    cbGridVisible: TCheckBox;
    cbPenColor: TColorButton;
    cbPenStyle: TChartComboBox;
    cbPenWidth: TChartComboBox;
    cbTickColor: TColorButton;
    cbShow: TCheckBox;
    cbAutoMax: TCheckBox;
    cbAutoMin: TCheckBox;
    cbTitleVisible: TCheckBox;
    cbInverted: TCheckBox;
    cbLabelsVisible: TCheckBox;
    cbFrameVisible: TCheckBox;
    cbArrowVisible: TCheckBox;
    edLabelFormat: TEdit;
    gbAxisLine: TGroupBox;
    gbGrid: TGroupBox;
    gbTitleFont: TGroupBox;
    gbLabelFont: TGroupBox;
    gbShapeFillBorder: TGroupBox;
    gbTitleShapeBrushPenMargins: TGroupBox;
    gbLabels: TGroupBox;
    gbTicks: TGroupBox;
    gbFrame: TGroupBox;
    gbArrow: TGroupBox;
    lblArrowWidth: TLabel;
    lblArrowLength: TLabel;
    lblArrowBaseLength: TLabel;
    lblLabelDistance: TLabel;
    lblPenStyle: TLabel;
    lblPenWidth: TLabel;
    lblTitleDistance: TLabel;
    lblTickLength: TLabel;
    lblTickInnerLength: TLabel;
    seTickLength: TSpinEdit;
    seTickInnerLength: TSpinEdit;
    seTitleDistance: TSpinEdit;
    seLabelDistance: TSpinEdit;
    seArrowBaseLength: TSpinEdit;
    seArrowLength: TSpinEdit;
    seArrowWidth: TSpinEdit;
    pgGrid: TTabSheet;
    gbAxisRange: TGroupBox;
    lblLabelFormat: TLabel;
    PanelTop: TPanel;
    seMaximum: TFloatSpinEdit;
    seMinimum: TFloatSpinEdit;
    lblAutomatic: TLabel;
    lblTitle: TLabel;
    mmoTitle: TMemo;
    TitleMemoPanel: TPanel;
    PageControl: TPageControl;
    TitleParamsPanel: TPanel;
    rgTitleAlignment: TRadioGroup;
    pgLabels: TTabSheet;
    pgTitle: TTabSheet;
    pgLine: TTabSheet;
    procedure cbArrowVisibleChange(Sender: TObject);
    procedure cbAutoMinChange(Sender: TObject);
    procedure cbAutoMaxChange(Sender: TObject);
    procedure cbFrameVisibleChange(Sender: TObject);
    procedure cbGridVisibleChange(Sender: TObject);
    procedure cbInvertedChange(Sender: TObject);
    procedure cbLabelsVisibleChange(Sender: TObject);
    procedure cbAxisLineVisibleChange(Sender: TObject);
    procedure cbShowChange(Sender: TObject);
    procedure cbTickColorColorChanged(Sender: TObject);
    procedure cbTitleVisibleChange(Sender: TObject);
    procedure edLabelFormatEditingDone(Sender: TObject);
    procedure FormActivate(Sender: TObject);
    procedure FormCloseQuery(Sender: TObject; var CanClose: boolean);
    procedure FormCreate(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure HelpButtonClick(Sender: TObject);
    procedure mmoTitleChange(Sender: TObject);
    procedure OKButtonClick(Sender: TObject);
    procedure rgTitleAlignmentClick(Sender: TObject);
    procedure seArrowBaseLengthChange(Sender: TObject);
    procedure seArrowLengthChange(Sender: TObject);
    procedure seArrowWidthChange(Sender: TObject);
    procedure seLabelDistanceChange(Sender: TObject);
    procedure seTitleDistanceChange(Sender: TObject);
    procedure seMinimumChange(Sender: TObject);
    procedure seMaximumChange(Sender: TObject);
    procedure seTickLengthChange(Sender: TObject);
    procedure seTickInnerLengthChange(Sender: TObject);
  private
    FAxis: TChartAxis;
    FOKClicked: Boolean;
    FSavedAxisParams: TChartAxisParams;
    FTitleFontFrame: TChartFontFrame;
    FTitleShapeBrushPenMarginsFrame: TChartShapeBrushPenMarginsFrame;
    FLabelFontFrame: TChartFontFrame;
    FGridPenFrame: TChartPenFrame;
    FFramePenFrame: TChartPenFrame;
    FAxisLinePenFrame: TChartPenFrame;
    FLabelShapeBrushPenMarginsFrame: TChartShapeBrushPenMarginsFrame;
    function GetAlignment(AItemIndex: Integer): TAlignment;
    function GetAlignmentIndex(AValue: TAlignment): Integer;
    function GetPage: TChartAxisEditorPage;
    procedure SetPage(AValue: TChartAxisEditorPage);
    procedure ChangedHandler(Sender: TObject);
    procedure LabelChangedHandler(Sender: TObject);
    procedure LabelFontChangedHandler(Sender: TObject);
    procedure LabelShapeChangedHandler(AShape: TChartLabelShape);
    procedure TitleChangedHandler(Sender: TObject);
    procedure TitleFontChangedHandler(Sender: TObject);
    procedure TitleShapeChangedHandler(AShape: TChartLabelShape);
  protected
    function GetChart: TChart;
    procedure RestoreAxisParams; virtual;
    procedure SaveAxisParams; virtual;
  public
    procedure Prepare(Axis: TChartAxis; ACaptionMask: String);
    property Page: TChartAxisEditorPage read GetPage write SetPage;

  end;

var
  AxisEditor: TChartAxisEditor;

implementation

{$R *.lfm}

uses
  Math, ceUtils;

procedure TChartAxisEditor.cbArrowVisibleChange(Sender: TObject);
begin
  FAxis.Arrow.Visible := cbArrowVisible.Checked;
end;

procedure TChartAxisEditor.cbAutoMaxChange(Sender: TObject);
begin
  FAxis.Range.UseMax := not cbAutoMax.Checked;
  seMaximum.Visible := FAxis.Range.UseMax;
end;

procedure TChartAxisEditor.cbAutoMinChange(Sender: TObject);
begin
  FAxis.Range.UseMin := not cbAutoMin.Checked;
  seMinimum.Visible := FAxis.Range.UseMin;
end;

procedure TChartAxisEditor.cbFrameVisibleChange(Sender: TObject);
begin
  GetChart.Frame.Visible := cbFrameVisible.Checked;
end;

procedure TChartAxisEditor.cbGridVisibleChange(Sender: TObject);
begin
  FAxis.Grid.Visible := cbGridVisible.Checked;
end;

procedure TChartAxisEditor.cbInvertedChange(Sender: TObject);
begin
  FAxis.Inverted := not FAxis.Inverted;
end;

procedure TChartAxisEditor.cbLabelsVisibleChange(Sender: TObject);
begin
  FAxis.Marks{%H-}.Visible := cbLabelsVisible.Checked;
end;

procedure TChartAxisEditor.cbAxisLineVisibleChange(Sender: TObject);
begin
  FAxis.AxisPen.Visible := cbAxisLineVisible.Checked;
end;

procedure TChartAxisEditor.cbShowChange(Sender: TObject);
begin
  FAxis.Visible := cbShow.Checked;
end;

procedure TChartAxisEditor.cbTickColorColorChanged(Sender: TObject);
begin
  FAxis.TickColor := cbTickColor.ButtonColor;
end;

procedure TChartAxisEditor.cbTitleVisibleChange(Sender: TObject);
begin
  FAxis.Title.Visible := cbTitleVisible.Checked;
end;

procedure TChartAxisEditor.ChangedHandler(Sender: TObject);
begin
  GetChart.Invalidate;
end;

procedure TChartAxisEditor.edLabelFormatEditingDone(Sender: TObject);
begin
  try
    FAxis.Marks{%H-}.Format := edLabelFormat.Text;
  except
  end;
end;

procedure TChartAxisEditor.FormActivate(Sender: TObject);
begin
  Constraints.MinWidth := Max(gbTitleShapeBrushPenMargins.Width, gbTitleFont.Width) * 2 + Bevel1.Width +
   TitleMemoPanel.BorderSpacing.Around*2 +
   PageControl.BorderSpacing.Left + PageControl.BorderSpacing.Right;

  Constraints.MinHeight := gbTicks.Top + gbTicks.Height + gbTicks.BorderSpacing.Bottom +
    PageControl.Height - PageControl.ClientHeight +
    PanelTop.Height +
    ButtonPanel.Height + ButtonPanel.BorderSpacing.Around * 2;

  Width := 1;   // Enforce constraints
  Height := 1;
end;

procedure TChartAxisEditor.FormCloseQuery(Sender: TObject; var CanClose: boolean);
begin
  if not CanClose then exit;
  if not FOKClicked then begin
    RestoreAxisParams;
    GetChart.Invalidate;
  end;
end;

procedure TChartAxisEditor.FormCreate(Sender: TObject);
begin
  // Insert frames at runtime - this makes life much easier...
  FTitleFontFrame := TChartFontFrame.Create(self);
  FTitleFontFrame.Parent := gbTitleFont;
  FTitleFontFrame.Name := '';
  FTitleFontFrame.Align := alClient;
  FTitleFontFrame.BorderSpacing.Left := 8;
  FTitleFontFrame.BorderSpacing.Right := 8;
  FTitleFontFrame.OnChange := @TitleFontChangedHandler;
  gbTitleFont.AutoSize := true;
  gbTitleFont.Caption := 'Font';

  FTitleShapeBrushPenMarginsFrame := TChartShapeBrushPenMarginsFrame.Create(self);
  FTitleShapeBrushPenMarginsFrame.Parent := gbTitleShapeBrushPenMargins;
  FTitleShapeBrushPenMarginsFrame.Name := '';
  FTitleShapeBrushPenMarginsFrame.BorderSpacing.Left := 8;
  FTitleShapeBrushPenMarginsFrame.BorderSpacing.Right := 8;
  FTitleShapeBrushPenMarginsFrame.BorderSpacing.Bottom := 8;
  FTitleShapeBrushPenMarginsFrame.OnChange := @TitleChangedHandler;
  FTitleShapeBrushPenMarginsFrame.OnShapeChange := @TitleShapeChangedHandler;
  FTitleShapeBrushPenMarginsFrame.AutoSize := true;
  gbTitleShapeBrushPenMargins.AutoSize := true;
  gbTitleShapeBrushPenMargins.Caption := 'Title background';

  FLabelFontFrame := TChartFontFrame.Create(self);
  FLabelFontFrame.Parent := gbLabelFont;
  FLabelFontFrame.Name := '';
  FLabelFontFrame.Align := alClient;
  FLabelFontFrame.BorderSpacing.Left := 8;
  FLabelFontFrame.BorderSpacing.Right := 8;
  FLabelFontFrame.OnChange := @LabelFontChangedHandler;
  gbLabelFont.AutoSize := true;
  gbLabelFont.Caption := 'Label font';

  FLabelShapeBrushPenMarginsFrame := TChartShapeBrushPenMarginsFrame.Create(self);
  FLabelShapeBrushPenMarginsFrame.Parent := gbShapeFillBorder;
  FLabelShapeBrushPenMarginsFrame.Name := '';
  FLabelShapeBrushPenMarginsFrame.Align := alClient;
  FLabelShapeBrushPenMarginsFrame.BorderSpacing.Left := 8;
  FLabelShapeBrushPenMarginsFrame.BorderSpacing.Right := 8;
  FLabelShapeBrushPenMarginsFrame.BorderSpacing.Bottom := 8;
  FLabelShapeBrushPenMarginsFrame.OnChange := @LabelChangedHandler;
  FLabelShapeBrushPenMarginsFrame.OnShapeChange := @LabelShapeChangedHandler;
  FLabelShapeBrushPenMarginsFrame.AutoSize := true;
  gbShapeFillBorder.AutoSize := true;
  gbShapeFillBorder.Caption := 'Label background';

  FGridPenFrame := TChartPenFrame.Create(Self);
  FGridPenFrame.Parent := gbGrid;
  FGridPenFrame.Name := '';
  FGridPenFrame.Align := alTop;
  FGridPenFrame.Top := 1000;
  FGridPenFrame.BorderSpacing.Left := 16;
  FGridPenFrame.BorderSpacing.Right := 16;
  FGridPenFrame.BorderSpacing.Bottom := 16;
  FGridPenFrame.OnChange := @ChangedHandler;
  gbGrid.AutoSize := true;
  gbGrid.Caption := 'Grid lines';

  FFramePenFrame := TChartPenFrame.Create(Self);
  FFramePenFrame.Parent := gbFrame;
  FFramePenFrame.Name := '';
  FFramePenFrame.Align := alTop;
  FFramePenFrame.Top := 1000;
  FFramePenFrame.BorderSpacing.Left := 16;
  FFramePenFrame.BorderSpacing.Right := 16;
  FFramePenFrame.BorderSpacing.Bottom := 16;
  FFramePenFrame.OnChange := @ChangedHandler;
  gbFrame.AutoSize := true;
  gbFrame.Caption := 'Frame';

  FAxisLinePenFrame := TChartPenFrame.Create(Self);
  FAxisLinePenFrame.Parent := gbAxisLine;
  FAxisLinePenFrame.Name := '';
  FAxisLinePenFrame.Align := alTop;
  FAxisLinePenFrame.Top := 1000;
  FAxisLinePenFrame.BorderSpacing.Left := 16;
  FAxisLinePenFrame.BorderSpacing.Right := 16;
  FAxisLinePenFrame.BorderSpacing.Bottom := 16;
  FAxisLinePenFrame.OnChange := @ChangedHandler;
  gbAxisLine.AutoSize := true;
  gbAxisLine.Caption := 'Axis line';

  BoldHeaders(self);

  TitleParamsPanel.AutoSize := true;
end;

procedure TChartAxisEditor.FormShow(Sender: TObject);
begin
  FOKClicked := false;
  FTitleShapeBrushPenMarginsFrame.AutoSize := false;
  FTitleShapeBrushPenMarginsFrame.Align := alClient;
end;

function TChartAxisEditor.GetAlignment(AItemIndex: Integer): TAlignment;
const
  ALIGNMENTS: array[0..2] of TAlignment = (taLeftJustify, taCenter, taRightJustify);
begin
  Result := ALIGNMENTS[AItemIndex];
end;

function TChartAxisEditor.GetAlignmentIndex(AValue: TAlignment): Integer;
const
  ALIGNMENTS: array[TAlignment] of Integer = (0, 2, 1);
begin
  Result := ALIGNMENTS[AValue];
end;

function TChartAxisEditor.GetChart: TChart;
begin
  Result := FAxis.Collection.Owner as TChart;
end;

function TChartAxisEditor.GetPage: TChartAxisEditorPage;
begin
  Result := TChartAxisEditorPage(PageControl.ActivePageIndex);
end;

procedure TChartAxisEditor.HelpButtonClick(Sender: TObject);
begin
  ModalResult := mrYesToAll;
end;

procedure TChartAxisEditor.LabelChangedHandler(Sender: TObject);
begin
  GetChart.Invalidate;
end;

procedure TChartAxisEditor.LabelFontChangedHandler(Sender: TObject);
begin
  GetChart.Invalidate;
end;

procedure TChartAxisEditor.LabelShapeChangedHandler(AShape: TChartLabelShape);
begin
  FAxis.Marks{%H-}.Shape := AShape;
end;

procedure TChartAxisEditor.mmoTitleChange(Sender: TObject);
begin
  FAxis.Title.Caption := mmoTitle.Lines.Text;
end;

procedure TChartAxisEditor.OKButtonClick(Sender: TObject);
begin
  FOKClicked := true;
end;

procedure TChartAxisEditor.Prepare(Axis: TChartAxis;
  ACaptionMask: String);
begin
  FAxis := Axis;
  SaveAxisParams;

  if FAxis.Title.Caption <> '' then
    Caption := Format(ACaptionMask, [FAxis.Title.Caption])
  else
    Caption := Format(ACaptionMask, ['#' + IntToStr(FAxis.Index)]);

  cbShow.Checked := Axis.Visible;

  // Page "Title"
  cbTitleVisible.Checked := Axis.Title.Visible;
  mmoTitle.Lines.Text := Axis.Title.Caption;
  mmoTitle.Font := Axis.Title.LabelFont;
  mmoTitle.Font.Orientation := 0;  // Memo has horizontal text only
  with Axis.Title do begin
    rgTitleAlignment.ItemIndex := GetAlignmentIndex(Alignment);
    seTitleDistance.Value := Distance;
    FTitleFontFrame.Prepare(LabelFont, true);
    FTitleShapeBrushPenMarginsFrame.Prepare(Shape, LabelBrush, Frame, Margins);
    if LabelBrush.Style <> bsClear then
      mmoTitle.Color := LabelBrush.Color
    else
      mmoTitle.Color := GetChart.Color;
  end;

  // Page "Labels"
  seMaximum.Value := Axis.Range.Max;
  seMinimum.Value := Axis.Range.Min;
  cbAutoMax.Checked := not Axis.Range.UseMax;
  cbAutoMin.Checked := not Axis.Range.UseMin;
  cbInverted.Checked := Axis.Inverted;
  seTickLength.Value := Axis.TickLength;
  seTickInnerLength.Value := Axis.TickInnerLength;
  cbTickColor.ButtonColor := Axis.TickColor;
  with Axis{%H-}.Marks do begin
    seLabelDistance.Value := Distance;
    cbLabelsVisible.Checked := Visible;
    edLabelFormat.Text := Format;
    FLabelFontFrame.Prepare(LabelFont, true);
    FLabelShapeBrushPenMarginsFrame.Prepare(Shape, LabelBrush, Frame, Margins);
  end;

  // Page "Grid"
  cbGridVisible.Checked := FAxis.Grid.EffVisible;
  FGridPenFrame.Prepare(FAxis.Grid);

  // Page "Line"
  cbFrameVisible.Checked := GetChart.Frame.EffVisible;
  FFramePenFrame.Prepare(GetChart.Frame);
  cbAxisLineVisible.Checked := FAxis.AxisPen.EffVisible;
  FAxisLinePenFrame.Prepare(FAxis.AxisPen);
  cbArrowVisible.Checked := FAxis.Arrow.Visible;
  seArrowBaseLength.Value := FAxis.Arrow.BaseLength;
  seArrowLength.Value := FAxis.Arrow.Length;
  seArrowWidth.Value := FAxis.Arrow.Width;
end;

procedure TChartAxisEditor.rgTitleAlignmentClick(Sender: TObject);
begin
  FAxis.Title.Alignment := GetAlignment(rgTitleAlignment.ItemIndex);
end;

procedure TChartAxisEditor.RestoreAxisParams;
begin
  GetChart.DisableRedrawing;
  try
    with FSavedAxisParams do
    begin
      // General visibility
      FAxis.Visible := Visible;

      // Axis title
      FAxis.Title.Visible := TitleVisible;
      FAxis.Title.Caption := TitleText;
      FAxis.Title.Alignment := TitleAlignment;
      FAxis.Title.LabelFont.Name := TitleFontName;
      FAxis.Title.LabelFont.Size := TitleFontSize;
      FAxis.Title.LabelFont.Color := TitleFontColor;
      FAxis.Title.LabelFont.Style := TitleFontStyle;
      FAxis.Title.LabelFont.Orientation := TitleFontOrientation;
      FAxis.Title.Distance := TitleDistance;
      FAxis.Title.Shape := TitleShape;
      FAxis.Title.LabelBrush.Color := TitleBackgroundColor;
      FAxis.Title.LabelBrush.Style := TitleBackgroundStyle;
      FAxis.Title.Frame.Visible := TitleBorderVisible;
      FAxis.Title.Frame.Color := TitleBorderColor;
      FAxis.Title.Margins.Left := TitleMarginLeft;
      FAxis.Title.Margins.Top := TitleMarginTop;
      FAxis.Title.Margins.Right := TitleMarginRight;
      FAxis.Title.Margins.Bottom := TitleMarginBottom;

      // Axis range
      FAxis.Range.Max := Maximum;
      FAxis.Range.Min := Minimum;
      FAxis.Range.UseMax := UseMax;
      FAxis.Range.UseMin := UseMin;
      FAxis.Inverted := Inverted;

      // Tick labels
      FAxis.Marks.Visible := LabelsVisible;
      FAxis.Marks.Format := LabelsFormat;
      FAxis.Marks.Distance := LabelsDistance;
      FAxis.TickLength := TickLength;
      FAxis.TickInnerLength := TickLengthInner;
      FAxis.TickColor := TickColor;
      FAxis.Marks.LabelFont.Name := LabelFontName;
      FAxis.Marks.LabelFont.Size := LabelFontSize;
      FAxis.Marks.LabelFont.Color := LabelFontColor;
      FAxis.Marks.LabelFont.Style := LabelFontStyle;
      FAxis.Marks.Shape := LabelShape;
      FAxis.Marks.LabelBrush.Color := LabelBackgroundColor;
      FAxis.Marks.LabelBrush.Style := LabelBackgroundStyle;
      FAxis.Marks.Frame.Visible := LabelBorderVisible;
      FAxis.Marks.Frame.Color := LabelBorderColor;
      FAxis.Marks.Margins.Left := LabelMarginLeft;
      FAxis.Marks.Margins.Top := LabelMarginTop;
      FAxis.Marks.Margins.Right := LabelMarginRight;
      FAxis.Marks.Margins.Bottom := LabelMarginBottom;

      // Grid
      FAxis.Grid.Visible := GridVisible;
      FAxis.Grid.Style := GridPenStyle;
      FAxis.Grid.Width := GridPenWidth;
      FAxis.Grid.Color := GridPenColor;

      // Frame
      GetChart.Frame.Visible := FrameVisible;
      GetChart.Frame.Style := FramePenStyle;
      GetChart.Frame.Width := FramePenWidth;
      GetChart.Frame.Color := FramePenColor;

      // Arrow
      FAxis.Arrow.Visible := ArrowVisible;
      FAxis.Arrow.BaseLength := ArrowBaseLength;
      FAxis.Arrow.Length := ArrowLength;
      FAxis.Arrow.Width := ArrowWidth;
    end;

  finally
    GetChart.EnableRedrawing;
  end;
end;

procedure TChartAxisEditor.SaveAxisParams;
begin
  with FSavedAxisParams do
  begin
    // General visibility
    Visible := FAxis.Visible;

    // Axis title
    TitleVisible := FAxis.Title.visible;
    TitleText := FAxis.Title.caption;
    TitleAlignment := FAxis.Title.Alignment;
    TitleFontName := FAxis.Title.LabelFont.Name;
    TitleFontSize := FAxis.Title.LabelFont.Size;
    TitleFontStyle := FAxis.Title.LabelFont.Style;
    TitleFontColor := FAxis.Title.LabelFont.Color;
    TitleFontOrientation := FAxis.Title.LabelFont.Orientation;
    TitleDistance := FAxis.Title.Distance;
    TitleShape := FAxis.Title.Shape;
    TitleBackgroundStyle := FAxis.Title.LabelBrush.Style;
    TitleBackgroundColor := FAxis.Title.LabelBrush.Color;
    TitleBorderVisible := FAxis.Title.Frame.Visible;
    TitleBorderColor := FAxis.Title.Frame.Color;
    TitleMarginLeft := FAxis.Title.Margins.Left;
    TitleMarginTop := FAXis.Title.Margins.Top;
    TitleMarginRight := FAxis.Title.Margins.Right;
    TitleMarginBottom := FAxis.Title.Margins.Bottom;

    // Axis range
    Maximum  := FAxis.Range.Max;
    Minimum := FAxis.Range.Min;
    UseMax := FAxis.Range.UseMax;
    UseMin := FAxis.Range.UseMin;
    Inverted := FAxis.Inverted;

    // Tick labels
    LabelsVisible := FAxis.Marks.Visible;
    LabelsFormat := FAxis.Marks.Format;
    LabelsDistance := FAxis.Marks.Distance;
    TickLength := FAxis.TickLength;
    TickLengthInner := FAxis.TickInnerLength;
    TickColor := FAxis.TickColor;
    LabelFontName := FAxis.Marks.LabelFont.Name;
    LabelFontSize := FAxis.Marks.LabelFont.Size;
    LabelFontStyle := FAxis.Marks.LabelFont.Style;
    LabelFontColor := FAxis.Marks.LabelFont.Color;
    LabelShape := FAxis.Marks.Shape;
    LabelBackgroundStyle := FAxis.Marks.LabelBrush.Style;
    LabelBackgroundColor := FAxis.Marks.LabelBrush.Color;
    LabelBorderVisible := FAxis.Marks.Frame.Visible;
    LabelBorderColor := FAxis.Marks.Frame.Color;
    LabelMarginLeft := FAxis.Marks.Margins.Left;
    LabelMarginTop := FAxis.Marks.Margins.Top;
    LabelMarginRight := FAxis.Marks.Margins.Right;
    LabelMarginBottom := FAxis.Marks.Margins.Bottom;

    // Grid
    GridVisible := FAxis.Grid.Visible;
    GridPenStyle := FAxis.Grid.Style;
    GridPenWidth := FAxis.Grid.Width;
    GridPenColor := FAxis.Grid.Color;

    // Frame
    FrameVisible := GetChart.Frame.Visible;
    FramePenStyle := GetChart.Frame.Style;
    FramePenWidth := GetChart.Frame.Width;
    FramePenColor := GetChart.Frame.Color;

    // Arrow
    ArrowVisible := FAxis.Arrow.Visible;
    ArrowBaseLength := FAxis.Arrow.BaseLength;
    ArrowLength := FAxis.Arrow.Length;
    ArrowWidth := FAxis.Arrow.Width;
  end;
end;

procedure TChartAxisEditor.seArrowBaseLengthChange(Sender: TObject);
begin
  FAxis.Arrow.BaseLength := seArrowBaseLength.value;
end;

procedure TChartAxisEditor.seArrowLengthChange(Sender: TObject);
begin
  FAxis.Arrow.Length := seArrowLength.Value;
end;

procedure TChartAxisEditor.seArrowWidthChange(Sender: TObject);
begin
  FAxis.Arrow.Width := seArrowWidth.Value;
end;

procedure TChartAxisEditor.seLabelDistanceChange(Sender: TObject);
begin
  FAxis.Marks{%H-}.Distance := seLabelDistance.Value;
end;

procedure TChartAxisEditor.seTitleDistanceChange(Sender: TObject);
begin
  FAxis.Title.Distance := seTitleDistance.Value;
end;

procedure TChartAxisEditor.seMaximumChange(Sender: TObject);
begin
  FAxis.Range.Max := seMaximum.Value;
  cbAutoMax.Checked := false;
end;

procedure TChartAxisEditor.seMinimumChange(Sender: TObject);
begin
  FAxis.Range.Min := seMinimum.Value;
  cbAutoMin.Checked := false;
end;

procedure TChartAxisEditor.seTickLengthChange(Sender: TObject);
begin
  FAxis.TickLength := seTickLength.Value;
end;

procedure TChartAxisEditor.seTickInnerLengthChange(Sender: TObject);
begin
  FAxis.TickInnerLength := seTickInnerLength.Value;
end;

procedure TChartAxisEditor.SetPage(AValue: TChartAxisEditorPage);
begin
  PageControl.ActivePageIndex := ord(AValue);
end;

procedure TChartAxisEditor.TitleChangedHandler(Sender: TObject);
begin
  if FAxis.Title.LabelBrush.Style <> bsClear then
    mmoTitle.Color := FAxis.Title.LabelBrush.Color
  else
    mmoTitle.Color := GetChart.Color;
  GetChart.Invalidate;
end;

procedure TChartAxisEditor.TitleFontChangedHandler(Sender: TObject);
begin
  mmoTitle.Font.Assign(FAxis.Title.LabelFont);
  mmoTitle.Font.Orientation := 0;
end;

procedure TChartAxisEditor.TitleShapeChangedHandler(AShape: TChartLabelShape);
begin
  FAxis.Title.Shape := AShape;
end;


end.


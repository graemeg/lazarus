unit ceAxisFrame;

{$MODE ObjFPC}{$H+}
{.$DEFINE WYSIWYG_AXISTITLE}

interface

uses
  Classes, SysUtils, Graphics, Forms,
  Controls, ExtCtrls, ComCtrls, StdCtrls, Dialogs, Spin,
  TATextElements, TAChartAxis, TAGraph,
  ceFontFrame, cePenFrame, ceShapeBrushPenMarginsFrame;

type
  TChartAxisEditorPage = (aepTitle, aepLabels, aepGrid, aepLine);

  { TChartAxisFrame }
  TChartAxisFrame = class(TFrame)
    Bevel1: TBevel;
    Bevel2: TBevel;
    cbArrowVisible: TCheckBox;
    cbAutoMax: TCheckBox;
    cbAutoMin: TCheckBox;
    cbAxisLineVisible: TCheckBox;
    cbFrameVisible: TCheckBox;
    cbGridVisible: TCheckBox;
    cbInverted: TCheckBox;
    cbLabelsVisible: TCheckBox;
    cbShow: TCheckBox;
    cbTickColor: TColorButton;
    cbTitleVisible: TCheckBox;
    edLabelFormat: TEdit;
    gbArrow: TGroupBox;
    gbAxisLine: TGroupBox;
    gbAxisRange: TGroupBox;
    gbFrame: TGroupBox;
    gbGrid: TGroupBox;
    gbLabelFont: TGroupBox;
    gbLabels: TGroupBox;
    gbShapeFillBorder: TGroupBox;
    gbTicks: TGroupBox;
    gbTitleFont: TGroupBox;
    gbTitleShapeBrushPenMargins: TGroupBox;
    lblArrowBaseLength: TLabel;
    lblArrowLength: TLabel;
    lblArrowWidth: TLabel;
    lblAutomatic: TLabel;
    lblLabelDistance: TLabel;
    lblLabelFormat: TLabel;
    lblTickInnerLength: TLabel;
    lblTickLength: TLabel;
    lblTitle: TLabel;
    lblTitleDistance: TLabel;
    mmoTitle: TMemo;
    PageControl: TPageControl;
    PanelTop: TPanel;
    pgGrid: TTabSheet;
    pgLabels: TTabSheet;
    pgLine: TTabSheet;
    pgTitle: TTabSheet;
    rgTitleAlignment: TRadioGroup;
    seArrowBaseLength: TSpinEdit;
    seArrowLength: TSpinEdit;
    seArrowWidth: TSpinEdit;
    seLabelDistance: TSpinEdit;
    seMaximum: TFloatSpinEdit;
    seMinimum: TFloatSpinEdit;
    seTickInnerLength: TSpinEdit;
    seTickLength: TSpinEdit;
    seTitleDistance: TSpinEdit;
    Spacer: TBevel;
    TitleMemoPanel: TPanel;
    TitleParamsPanel: TPanel;
    procedure cbArrowVisibleChange(Sender: TObject);
    procedure cbAutoMaxChange(Sender: TObject);
    procedure cbAutoMinChange(Sender: TObject);
    procedure cbAxisLineVisibleChange(Sender: TObject);
    procedure cbFrameVisibleChange(Sender: TObject);
    procedure cbGridVisibleChange(Sender: TObject);
    procedure cbInvertedChange(Sender: TObject);
    procedure cbLabelsVisibleChange(Sender: TObject);
    procedure cbShowChange(Sender: TObject);
    procedure cbTickColorColorChanged(Sender: TObject);
    procedure cbTitleVisibleChange(Sender: TObject);
    procedure edLabelFormatEditingDone(Sender: TObject);
    procedure mmoTitleChange(Sender: TObject);
    procedure PageControlChanging(Sender: TObject; var AllowChange: Boolean);
    procedure rgTitleAlignmentClick(Sender: TObject);
    procedure seArrowBaseLengthChange(Sender: TObject);
    procedure seArrowLengthChange(Sender: TObject);
    procedure seArrowWidthChange(Sender: TObject);
    procedure seLabelDistanceChange(Sender: TObject);
    procedure seMaximumChange(Sender: TObject);
    procedure seMinimumChange(Sender: TObject);
    procedure seTickInnerLengthChange(Sender: TObject);
    procedure seTickLengthChange(Sender: TObject);
    procedure seTitleDistanceChange(Sender: TObject);
  private
    FAxis: TChartAxis;
    FAxisMin, FAxisMax: Double;
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
    procedure CalculatePreferredSize(var PreferredWidth, PreferredHeight: integer;
      {%H-}WithThemeSpace: Boolean); override;
    function GetChart: TChart;
    function GetRealAxisMax: Double;
    function GetRealAxisMin: Double;
  public
    constructor Create(AOwner: TComponent); override;
    procedure Prepare(Axis: TChartAxis);
    function Validate(out AMsg: String; out AControl: TWinControl): Boolean;
    property Page: TChartAxisEditorPage read GetPage write SetPage;
  end;

implementation

{$R *.lfm}

uses
  Math,
  ceUtils;

constructor TChartAxisFrame.Create(AOwner: TComponent);
begin
  inherited;

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
  FTitleShapeBrushPenMarginsFrame.Align := alClient;
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

procedure TChartAxisFrame.CalculatePreferredSize(
  var PreferredWidth, PreferredHeight: integer;
  WithThemeSpace: Boolean);
var
  w: Integer = 0;
  h: Integer = 0;
begin
  gbTitleShapeBrushPenMargins.GetPreferredsize(w, h);
  inc(w, FTitleShapeBrushPenMarginsFrame.BorderSpacing.Left);
  PreferredWidth :=
    Max(w, gbTitleFont.Width) * 2 +
    Bevel1.Width +
    TitleMemoPanel.BorderSpacing.Around * 2;

  PreferredHeight :=
    Max(
      gbTicks.Top + gbTicks.Height + gbTicks.BorderSpacing.Bottom,
      gbShapeFillBorder.Top + gbShapeFillBorder.Height + gbShapeFillBorder.BorderSpacing.Bottom
    ) +
    PageControl.Height - PageControl.ClientHeight +
    PanelTop.Height;
end;

procedure TChartAxisFrame.cbArrowVisibleChange(Sender: TObject);
begin
  FAxis.Arrow.Visible := cbArrowVisible.Checked;
end;

procedure TChartAxisFrame.cbAutoMaxChange(Sender: TObject);
begin
  FAxis.Range.UseMax := not cbAutoMax.Checked;
  seMaximum.Visible := FAxis.Range.UseMax;
end;

procedure TChartAxisFrame.cbAutoMinChange(Sender: TObject);
begin
  FAxis.Range.UseMin := not cbAutoMin.Checked;
  seMinimum.Visible := FAxis.Range.UseMin;
end;

procedure TChartAxisFrame.cbAxisLineVisibleChange(Sender: TObject);
begin
  FAxis.AxisPen.Visible := cbAxisLineVisible.Checked;
end;

procedure TChartAxisFrame.cbFrameVisibleChange(Sender: TObject);
begin
  GetChart.Frame.Visible := cbFrameVisible.Checked;
end;

procedure TChartAxisFrame.cbGridVisibleChange(Sender: TObject);
begin
  FAxis.Grid.Visible := cbGridVisible.Checked;
end;

procedure TChartAxisFrame.cbInvertedChange(Sender: TObject);
begin
  FAxis.Inverted := cbInverted.Checked;
end;

procedure TChartAxisFrame.cbLabelsVisibleChange(Sender: TObject);
begin
  FAxis.Marks{%H-}.Visible := cbLabelsVisible.Checked;
end;

procedure TChartAxisFrame.cbShowChange(Sender: TObject);
begin
  FAxis.Visible := cbShow.Checked;
end;

procedure TChartAxisFrame.cbTickColorColorChanged(Sender: TObject);
begin
  FAxis.TickColor := cbTickColor.ButtonColor;
end;

procedure TChartAxisFrame.cbTitleVisibleChange(Sender: TObject);
begin
  FAxis.Title.Visible := cbTitleVisible.Checked;
end;

procedure TChartAxisFrame.ChangedHandler(Sender: TObject);
begin
  GetChart.Invalidate;
end;

procedure TChartAxisFrame.edLabelFormatEditingDone(Sender: TObject);
begin
  try
    FAxis.Marks{%H-}.Format := edLabelFormat.Text;
  except
  end;
end;

function TChartAxisFrame.GetAlignment(AItemIndex: Integer): TAlignment;
const
  ALIGNMENTS: array[0..2] of TAlignment = (taLeftJustify, taCenter, taRightJustify);
begin
  Result := ALIGNMENTS[AItemIndex];
end;

function TChartAxisFrame.GetAlignmentIndex(AValue: TAlignment): Integer;
const
  ALIGNMENTS: array[TAlignment] of Integer = (0, 2, 1);
begin
  Result := ALIGNMENTS[AValue];
end;

function TChartAxisFrame.GetChart: TChart;
begin
  Result := FAxis.Collection.Owner as TChart;
end;

function TChartAxisFrame.GetPage: TChartAxisEditorPage;
begin
  Result := TChartAxisEditorPage(PageControl.ActivePageIndex);
end;

function TChartAxisFrame.GetRealAxisMax: Double;
begin
  if cbAutoMax.Checked then
    Result := FAxisMax
  else
    Result := seMaximum.Value;
end;

function TChartAxisFrame.GetRealAxisMin: Double;
begin
  if cbAutoMin.Checked then
    Result := FAxisMin
  else
    Result := seMinimum.Value;
end;

procedure TChartAxisFrame.LabelChangedHandler(Sender: TObject);
begin
  GetChart.Invalidate;
end;

procedure TChartAxisFrame.LabelFontChangedHandler(Sender: TObject);
begin
  GetChart.Invalidate;
end;

procedure TChartAxisFrame.LabelShapeChangedHandler(AShape: TChartLabelShape);
begin
  FAxis.Marks{%H-}.Shape := AShape;
end;

procedure TChartAxisFrame.mmoTitleChange(Sender: TObject);
begin
  FAxis.Title.Caption := mmoTitle.Lines.Text;
end;

procedure TChartAxisFrame.PageControlChanging(Sender: TObject;
  var AllowChange: Boolean);
var
  msg: String;
  C: TWinControl;
begin
  if not Validate(msg, C) then
  begin
    C.SetFocus;
    MessageDlg(msg, mtError, [mbOK], 0);
    AllowChange := false;
  end;
end;

procedure TChartAxisFrame.Prepare(Axis: TChartAxis);
begin
  FAxis := Axis;

  // Page "Title"
  cbTitleVisible.Checked := Axis.Title.Visible;
  mmoTitle.Lines.Text := Axis.Title.Caption;
  {$IFDEF WYSIWYG_AXISTITLE}
  mmoTitle.Font := Axis.Title.LabelFont;
  mmoTitle.Font.Orientation := 0;  // Memo has horizontal text only
  if Axis.Title.LabelBrush.Style <> bsClear then
    mmoTitle.Color := Axis.Title.LabelBrush.Color
  else
    mmoTitle.Color := GetChart.Color;
  {$ENDIF}
  with Axis.Title do begin
    rgTitleAlignment.ItemIndex := GetAlignmentIndex(Alignment);
    seTitleDistance.Value := Distance;
    FTitleFontFrame.Prepare(LabelFont, true);
    FTitleShapeBrushPenMarginsFrame.Prepare(Shape, LabelBrush, Frame, Margins);
  end;

  // Page "Labels"
  GetChart.GetAllSeriesAxisLimits(Axis, FAxisMin, FAxisMax);
  seMaximum.Value := IfThen(Axis.Range.UseMax, Axis.Range.Max, FAxisMax);
  seMinimum.Value := IfThen(Axis.Range.UseMin, Axis.Range.Min, FAxisMin);
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

procedure TChartAxisFrame.rgTitleAlignmentClick(Sender: TObject);
begin
  FAxis.Title.Alignment := GetAlignment(rgTitleAlignment.ItemIndex);
end;

procedure TChartAxisFrame.seArrowBaseLengthChange(Sender: TObject);
begin
  FAxis.Arrow.BaseLength := seArrowBaseLength.value;
end;

procedure TChartAxisFrame.seArrowLengthChange(Sender: TObject);
begin
  FAxis.Arrow.Length := seArrowLength.Value;
end;

procedure TChartAxisFrame.seArrowWidthChange(Sender: TObject);
begin
  FAxis.Arrow.Width := seArrowWidth.Value;
end;

procedure TChartAxisFrame.seLabelDistanceChange(Sender: TObject);
begin
  FAxis.Marks{%H-}.Distance := seLabelDistance.Value;
end;

procedure TChartAxisFrame.seMaximumChange(Sender: TObject);
begin
  FAxis.Range.Max := seMaximum.Value;
  cbAutoMax.Checked := false;
end;

procedure TChartAxisFrame.seMinimumChange(Sender: TObject);
begin
  FAxis.Range.Min := seMinimum.Value;
  cbAutoMin.Checked := false;
end;

procedure TChartAxisFrame.SetPage(AValue: TChartAxisEditorPage);
begin
  PageControl.ActivePageIndex := ord(AValue);
end;

procedure TChartAxisFrame.seTickLengthChange(Sender: TObject);
begin
  FAxis.TickLength := seTickLength.Value;
end;

procedure TChartAxisFrame.seTickInnerLengthChange(Sender: TObject);
begin
  FAxis.TickInnerLength := seTickInnerLength.Value;
end;

procedure TChartAxisFrame.seTitleDistanceChange(Sender: TObject);
begin
  FAxis.Title.Distance := seTitleDistance.Value;
end;

procedure TChartAxisFrame.TitleChangedHandler(Sender: TObject);
begin
{$IFDEF WYSIWYG_AXISTITLE}
  if FAxis.Title.LabelBrush.Style <> bsClear then
    mmoTitle.Color := FAxis.Title.LabelBrush.Color
  else
    mmoTitle.Color := GetChart.Color;
{$ENDIF}
  GetChart.Invalidate;
end;

procedure TChartAxisFrame.TitleFontChangedHandler(Sender: TObject);
begin
{$IFDEF WYSIWYG_AXISTITLE}
  mmoTitle.Font.Assign(FAxis.Title.LabelFont);
  mmoTitle.Font.Orientation := 0;
{$ENDIF}
end;

procedure TChartAxisFrame.TitleShapeChangedHandler(AShape: TChartLabelShape);
begin
  FAxis.Title.Shape := AShape;
end;

function TChartAxisFrame.Validate(out AMsg: String; out AControl: TWinControl): Boolean;
begin
  Result := false;
  if GetRealAxisMin >= GetRealAxisMax then
  begin
    AMsg := 'The axis minimum must be smaller than the axis maximum.';
    if seMaximum.Visible then
      AControl := seMaximum
    else if seMinimum.Visible then
      AControl := seMinimum
    else
      AControl := cbAutoMax;
    exit;
  end;
  Result := true;
end;


end.


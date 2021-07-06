unit ceAxisDlg;

{$mode objfpc}{$H+}
{$WARN 6058 off : Call to subroutine "$1" marked as inline is not inlined}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, ButtonPanel,
  ExtCtrls, Buttons, ComCtrls,
  TAChartAxis, TAChartAxisUtils, TATextElements, TAGraph,
  ceAxisFrame;

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

  TChartAxisEditor = class(TForm)
    ButtonPanel: TButtonPanel;
    procedure FormActivate(Sender: TObject);
    procedure FormCloseQuery(Sender: TObject; var CanClose: boolean);
    procedure FormCreate(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure HelpButtonClick(Sender: TObject);
    procedure OKButtonClick(Sender: TObject);
  private
    FAxis: TChartAxis;
    FOKClicked: Boolean;
    FAxisFrame: TChartAxisFrame;
    FSavedAxisParams: TChartAxisParams;
    function GetPage: TChartAxisEditorPage;
    procedure SetPage(AValue: TChartAxisEditorPage);
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

procedure TChartAxisEditor.FormActivate(Sender: TObject);
var
  w: Integer = 0;
  h: Integer = 0;
begin
  FAxisFrame.GetPreferredSize(w, h);
  inc(w, FAxisFrame.BorderSpacing.Around*2);
  inc(h, FAxisFrame.BorderSpacing.Around*2);

  Constraints.MinWidth := w;
  Constraints.MinHeight := h + ButtonPanel.Height + ButtonPanel.BorderSpacing.Around*2;

  // Enforce constraints
  SetBounds(Left, Top, 1, 1);
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
  FAxisFrame := TChartAxisFrame.Create(self);
  FAxisFrame.Parent := Self;
  FAxisFrame.Name := '';
  FAxisFrame.Align := alClient;
  FAxisFrame.BorderSpacing.Around := 8;
  FAxisFrame.AutoSize := true;
end;

procedure TChartAxisEditor.FormShow(Sender: TObject);
begin
  FOKClicked := false;
  {
  FTitleShapeBrushPenMarginsFrame.AutoSize := false;
  FTitleShapeBrushPenMarginsFrame.Align := alClient;
  }
end;

function TChartAxisEditor.GetChart: TChart;
begin
  Result := FAxis.Collection.Owner as TChart;
end;

function TChartAxisEditor.GetPage: TChartAxisEditorPage;
begin
  Result := FAxisFrame.Page;
end;

procedure TChartAxisEditor.HelpButtonClick(Sender: TObject);
begin
  ModalResult := mrYesToAll;
end;

procedure TChartAxisEditor.OKButtonClick(Sender: TObject);
var
  msg: String;
  C: TWinControl;
begin
  if not FAxisFrame.Validate(msg, C) then
  begin
    C.SetFocus;
    MessageDlg(msg, mtError, [mbOK], 0);
    ModalResult := mrNone;
  end else
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

  FAxisFrame.Prepare(Axis);
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

procedure TChartAxisEditor.SetPage(AValue: TChartAxisEditorPage);
begin
  FAxisFrame.Page := AValue;
end;

end.


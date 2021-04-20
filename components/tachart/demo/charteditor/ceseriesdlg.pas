unit ceSeriesDlg;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, ButtonPanel, ExtCtrls,
  StdCtrls,
  TACustomSeries, TASeries, TAGraph, TAChartCombos,
  cePenFrame, ceBrushFrame, cePointerFrame;

type

  { TChartSeriesEditor }

  TChartSeriesEditor = class(TForm)
    Bevel1: TBevel;
    Bevel2: TBevel;
    Bevel3: TBevel;
    Bevel4: TBevel;
    ButtonPanel: TButtonPanel;
    cbAreaShowDropLines: TCheckBox;
    cbLineSeriesShowPoints: TCheckBox;
    cbPenColor: TColorButton;
    cbPenStyle: TChartComboBox;
    cbPenWidth: TChartComboBox;
    cbShowSeries: TCheckBox;
    cbLineSeriesShowLines: TCheckBox;
    cbBarShape: TComboBox;
    cbAreaShowContourLines: TCheckBox;
    cbShowInLegend: TCheckBox;
    cbLegendMultiplicity: TComboBox;
    cbMarksStyle: TComboBox;
    cbShowMarks: TCheckBox;
    edMarksFormat: TEdit;
    edSeriesTitle: TEdit;
    gbAreaDropLinePen: TGroupBox;
    gbLineSeriesLineStyle: TGroupBox;
    gbBarSeriesBorder: TGroupBox;
    gbBarSeriesBrush: TGroupBox;
    gbBarShape: TGroupBox;
    gbLineSeriesPointer: TGroupBox;
    gbAreaSeriesBrush: TGroupBox;
    gbAreaContourPen: TGroupBox;
    gbLegendText: TGroupBox;
    gbMarks: TGroupBox;
    Label1: TLabel;
    Label2: TLabel;
    lblSeriesMarksStyle: TLabel;
    lblPenStyle: TLabel;
    lblPenWidth: TLabel;
    nbSeriesTypes: TNotebook;
    pgAreaSeries: TPage;
    pgBarSeries: TPage;
    pgLineSeries: TPage;
    PanelTop: TPanel;
    procedure cbAreaShowContourLinesChange(Sender: TObject);
    procedure cbAreaShowDropLinesChange(Sender: TObject);
    procedure cbBarShapeChange(Sender: TObject);
    procedure cbLegendMultiplicityChange(Sender: TObject);
    procedure cbLineSeriesShowLinesChange(Sender: TObject);
    procedure cbLineSeriesShowPointsChange(Sender: TObject);
    procedure cbMarksStyleChange(Sender: TObject);
    procedure cbShowInLegendChange(Sender: TObject);
    procedure cbShowMarksChange(Sender: TObject);
    procedure cbShowSeriesChange(Sender: TObject);
    procedure edMarksFormatEditingDone(Sender: TObject);
    procedure edSeriesTitleChange(Sender: TObject);
    procedure FormCloseQuery(Sender: TObject; var CanClose: boolean);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure OKButtonClick(Sender: TObject);
  private
    FSeries: TBasicChartSeries;
    FSavedSeries: TBasicChartSeries;
    FSavedActive: Boolean;
    FOKClicked: Boolean;
    FLineSeriesPenFrame: TChartPenFrame;
    FLineSeriesPointerFrame: TChartPointerFrame;
    FBarSeriesBrushFrame: TChartBrushFrame;
    FBarSeriesPenFrame: TChartPenFrame;
    FAreaSeriesBrushFrame: TChartBrushFrame;
    FAreaSeriesContourPenFrame: TChartPenFrame;
    FAreaSeriesDropLinesPenFrame: TChartPenFrame;
    procedure ChangedHandler(Sender: TObject);
  protected
    function GetChart: TChart;

  public
    procedure Prepare(ASeries: TBasicChartSeries; ACaptionMask: String);

  end;

var
  SeriesEditor: TChartSeriesEditor;

implementation

{$R *.lfm}

uses
  TAChartUtils, TATextElements, TALegend,
  ceUtils;

procedure TChartSeriesEditor.cbShowSeriesChange(Sender: TObject);
begin
  FSeries.Active := cbShowSeries.Checked;
end;

procedure TChartSeriesEditor.edMarksFormatEditingDone(Sender: TObject);
begin
  if (FSeries is TChartSeries) then
    try
      TChartSeries(FSeries).Marks.Format := edMarksFormat.Text;
    except
    end;
end;

procedure TChartSeriesEditor.edSeriesTitleChange(Sender: TObject);
begin
  (FSeries as TCustomChartSeries).Title := edSeriesTitle.Text;
end;

procedure TChartSeriesEditor.FormCloseQuery(Sender: TObject; var CanClose: boolean);
begin
  if not CanClose then exit;
  if not FOKClicked then begin
    FSeries.Assign(FSavedSeries);
    FSeries.Active := FSavedActive;
    GetChart.Invalidate;
  end;
end;

procedure TChartSeriesEditor.FormCreate(Sender: TObject);
begin
  { Line series page }
  FLineSeriesPenFrame := TChartPenFrame.Create(self);
  FLineSeriesPenFrame.Parent := gbLineSeriesLineStyle;
  FLineSeriesPenFrame.Name := '';
  FLineSeriesPenFrame.Align := alTop;
  FLineseriesPenFrame.Top := 1000;
  FLineSeriesPenFrame.BorderSpacing.Around := 8;
  FLineSeriesPenFrame.OnChange := @ChangedHandler;
  gbLineSeriesLineStyle.Caption := 'Connecting lines';
  gbLineSeriesLineStyle.AutoSize := true;

  FLineSeriesPointerFrame := TChartPointerFrame.Create(self);
  FLineSeriesPointerFrame.Parent := gbLineSeriesPointer;
  FLineSeriesPointerFrame.Name := '';
  FLineSeriesPointerFrame.Align := alTop;
  FLineseriesPointerFrame.Top := 1000;
  FLineSeriesPointerFrame.BorderSpacing.Around := 8;
  FLineSeriesPointerFrame.OnChange := @ChangedHandler;
  gbLineSeriesPointer.Caption := 'Series pointer';
  gbLineSeriesPointer.AutoSize := true;

  { Bar series page }
  FBarSeriesBrushFrame := TChartBrushFrame.Create(self);
  FBarSeriesBrushFrame.Parent := gbBarSeriesBrush;
  FBarSeriesBrushFrame.Name := '';
  FBarSeriesBrushFrame.Align := alTop;
  FBarSeriesBrushFrame.BorderSpacing.Left := 8;
  FBarSeriesBrushFrame.BorderSpacing.Right := 8;
  FBarSeriesBrushFrame.BorderSpacing.Bottom := 8;
  FBarSeriesBrushFrame.OnChange := @ChangedHandler;
  gbBarSeriesBrush.Caption := 'Bar brush';
  gbBarSeriesBrush.AutoSize := true;

  FBarSeriesPenFrame := TChartPenFrame.Create(self);
  FBarSeriesPenFrame.Parent := gbBarSeriesBorder;
  FBarSeriesPenFrame.Name := '';
  FBarSeriesPenFrame.Align := alTop;
  FBarSeriesPenFrame.BorderSpacing.Left := 8;
  FBarSeriesPenFrame.BorderSpacing.Right := 8;
  FBarSeriesPenFrame.BorderSpacing.Bottom := 8;
  FBarSeriesPenFrame.OnChange := @ChangedHandler;
  gbBarSeriesBorder.Caption := 'Bar borders';
  gbBarSeriesBorder.AutoSize := true;

  cbBarShape.DropdownCount := DEFAULT_DROPDOWN_COUNT;

  { Area series page }
  FAreaSeriesBrushFrame := TChartBrushFrame.Create(self);
  FAreaSeriesBrushFrame.Parent := gbAreaSeriesBrush;
  FAreaSeriesBrushFrame.Name := '';
  FAreaSeriesBrushFrame.Align := alTop;
  FAreaSeriesBrushFrame.BorderSpacing.Left := 8;
  FAreaSeriesBrushFrame.BorderSpacing.Right := 8;
  FAreaSeriesBrushFrame.BorderSpacing.Bottom := 8;
  FAreaSeriesBrushFrame.OnChange := @ChangedHandler;
  gbAreaSeriesBrush.Caption := 'Area fill';
  gbAreaSeriesBrush.AutoSize := true;

  FAreaSeriesContourPenFrame := TChartPenFrame.Create(self);
  FAreaSeriesContourPenFrame.Parent := gbAreaContourPen;
  FAreaSeriesContourPenFrame.Name := '';
  FAreaSeriesContourPenFrame.Align := alTop;
  FAreaSeriesContourPenFrame.Top := 1000;
  FAreaSeriesContourPenFrame.BorderSpacing.Left := 8;
  FAreaSeriesContourPenFrame.BorderSpacing.Right := 8;
  FAreaSeriesContourPenFrame.BorderSpacing.Bottom := 8;
  FAreaSeriesContourPenFrame.OnChange := @ChangedHandler;
  gbAreaContourPen.Caption := 'Border';
  gbAreaContourPen.AutoSize := true;

  FAreaSeriesDropLinesPenFrame := TChartPenFrame.Create(self);
  FAreaSeriesDropLinesPenFrame.Parent := gbAreaDropLinePen;
  FAreaSeriesDropLinesPenFrame.Name := '';
  FAreaSeriesDropLinesPenFrame.Align := alTop;
  FAreaSeriesDropLinesPenFrame.Top := 1000;
  FAreaSeriesDropLinesPenFrame.BorderSpacing.Left := 8;
  FAreaSeriesDropLinesPenFrame.BorderSpacing.Right := 8;
  FAreaSeriesDropLinesPenFrame.BorderSpacing.Bottom := 8;
  FAreaSeriesDropLinesPenFrame.OnChange := @ChangedHandler;
  gbAreaDropLinePen.Caption := 'Drop lines';
  gbAreaDropLinePen.AutoSize := true;


  { for all }
  BoldHeaders(self);

  cbLegendMultiplicity.DropdownCount := DEFAULT_DROPDOWN_COUNT;
  cbMarksStyle.DropdownCount := DEFAULT_DROPDOWN_COUNT;
end;

procedure TChartSeriesEditor.FormDestroy(Sender: TObject);
begin
  FSavedSeries.Free;
end;

procedure TChartSeriesEditor.FormShow(Sender: TObject);
begin
  AutoSize := true;
  Constraints.MinWidth := Width;
  Constraints.MinHeight := Height;
  AutoSize := false;
end;

procedure TChartSeriesEditor.OKButtonClick(Sender: TObject);
begin
  FOKClicked := true;
end;

procedure TChartSeriesEditor.cbBarShapeChange(Sender: TObject);
begin
  if FSeries is TBarSeries then
    TBarSeries(FSeries).BarShape := TBarShape(cbBarShape.ItemIndex);
end;

procedure TChartSeriesEditor.cbLegendMultiplicityChange(Sender: TObject);
begin
  (FSeries as TCustomChartSeries).Legend.Multiplicity := TLegendMultiplicity(cbLegendMultiplicity.ItemIndex);
end;

procedure TChartSeriesEditor.cbAreaShowContourLinesChange(Sender: TObject);
begin
  if FSeries is TAreaSeries then begin
    if cbAreaShowContourLines.Checked then
      TAreaSeries(FSeries).AreaContourPen.Style := FAreaSeriesContourPenFrame.cbPenStyle.PenStyle
    else
      TAreaSeries(FSeries).AreaContourPen.Style := psClear;
  end;
end;

procedure TChartSeriesEditor.cbAreaShowDropLinesChange(Sender: TObject);
begin
  if FSeries is TAreaSeries then begin
    if cbAreaShowDropLines.Checked then
      TAreaSeries(FSeries).AreaLinesPen.Style := FAreaSeriesDropLinesPenFrame.cbPenStyle.PenStyle
    else
      TAreaSeries(FSeries).AreaLinesPen.Style := psClear;
  end;
end;

procedure TChartSeriesEditor.cbLineSeriesShowLinesChange(Sender: TObject);
begin
  if FSeries is TLineSeries then
    TLineSeries(FSeries).ShowLines := cbLineSeriesShowLines.Checked;
end;

procedure TChartSeriesEditor.cbLineSeriesShowPointsChange(Sender: TObject);
begin
  if FSeries is TLineSeries then
    TLineSeries(FSeries).ShowPoints := cbLineSeriesShowPoints.Checked;
end;

procedure TChartSeriesEditor.cbMarksStyleChange(Sender: TObject);
var
  series: TChartSeries;
begin
  if (FSeries is TChartSeries) then begin
    series := TChartSeries(FSeries);
    series.Marks.Style := TSeriesMarksStyle(cbMarksStyle.ItemIndex);
    edMarksFormat.Text := series.Marks.Format;
  end;
end;

procedure TChartSeriesEditor.cbShowInLegendChange(Sender: TObject);
begin
  (FSeries as TCustomChartSeries).Legend.Visible := cbShowInLegend.Checked;
end;

procedure TChartSeriesEditor.cbShowMarksChange(Sender: TObject);
begin
  if (FSeries is TChartSeries) then
    TChartSeries(FSeries).Marks.Visible := cbShowMarks.Checked;
end;

procedure TChartSeriesEditor.ChangedHandler(Sender: TObject);
begin
  GetChart.Invalidate;
end;

function TChartSeriesEditor.GetChart: TChart;
begin
  Result := FSeries.ParentChart;
end;

procedure TChartSeriesEditor.Prepare(ASeries: TBasicChartSeries; ACaptionMask: String);
var
  seriesClass: TSeriesClass;
  series: TCustomChartSeries;
begin
  FSeries := ASeries;
  FSavedSeries.Free;
  seriesClass := TSeriesClass(FSeries.ClassType);
  FSavedSeries := seriesClass.Create(FSeries.Owner);
  FSavedSeries.Assign(FSeries);
  FSavedActive := FSeries.Active;
  FOKClicked := false;

  if FSeries is TCustomChartSeries then
    Caption := Format(ACaptionMask, [TCustomChartSeries(FSeries).Title])
  else begin
    Caption := 'SERIES NOT SUPPORTED';
    exit;
  end;
  series := TCustomChartSeries(FSeries);

  cbShowSeries.Checked := series.Active;
  cbShowInLegend.Checked := series.Legend.Visible;
  edSeriesTitle.Text := series.Title;
  cbLegendMultiplicity.ItemIndex := ord(series.Legend.Multiplicity);

  gbMarks.Visible := (FSeries is TChartSeries);
  if (FSeries is TChartSeries) then begin
    cbMarksStyle.ItemIndex := ord(TChartSeries(FSeries).Marks.Style);
    edMarksFormat.Text := TChartSeries(FSeries).Marks.Format;
    cbShowMarks.Checked := TChartSeries(FSeries).Marks.Visible;
  end;

  if ASeries is TLineSeries then begin
    nbSeriesTypes.PageIndex := 0;
    cbLineSeriesShowLines.Checked := TLineSeries(ASeries).ShowLines;
    cbLineSeriesShowPoints.Checked := TLineSeries(ASeries).ShowPoints;
    FLineSeriesPenFrame.Prepare(TLineSeries(ASeries).LinePen);
    FLineSeriesPointerFrame.Prepare(TLineSeries(ASeries).Pointer);
  end;

  if ASeries is TBarSeries then begin
    nbSeriesTypes.PageIndex := 1;
    FBarSeriesPenFrame.Prepare(TBarSeries(ASeries).BarPen);
    FBarSeriesBrushFrame.Prepare(TBarSeries(ASeries).BarBrush);
    cbBarShape.ItemIndex := ord(TBarSeries(ASeries).BarShape);
  end;

  if ASeries is TAreaSeries then begin
    nbSeriesTypes.PageIndex := 2;
    cbAreaShowContourLines.Checked := TAreaSeries(ASeries).AreaContourPen.Style <> psClear;
    cbAreaShowDropLines.Checked := TAreaSeries(ASeries).AreaLinesPen.Style <> psClear;
    FAreaSeriesBrushFrame.Prepare(TAreaSeries(ASeries).AreaBrush);
    FAreaSeriesContourPenFrame.Prepare(TAreaSeries(ASeries).AreaContourPen);
    FAreaSeriesDropLinesPenFrame.Prepare(TAreaSeries(ASeries).AreaLinesPen);
  end;

end;

end.


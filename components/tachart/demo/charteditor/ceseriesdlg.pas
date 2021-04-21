unit ceSeriesDlg;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, ButtonPanel, ExtCtrls,
  StdCtrls,
  TACustomSeries, TASeries, TAGraph, TAChartCombos,
  ceSeriesFrame;

type

  { TChartSeriesEditor }

  TChartSeriesEditor = class(TForm)
    ButtonPanel: TButtonPanel;
    cbPenColor: TColorButton;
    cbPenStyle: TChartComboBox;
    cbPenWidth: TChartComboBox;
    lblPenStyle: TLabel;
    lblPenWidth: TLabel;
    procedure FormActivate(Sender: TObject);
    procedure FormCloseQuery(Sender: TObject; var CanClose: boolean);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure OKButtonClick(Sender: TObject);
  private
    FSeries: TBasicChartSeries;
    FSeriesFrame: TChartSeriesFrame;
    FSavedSeries: TBasicChartSeries;
    FSavedActive: Boolean;
    FOKClicked: Boolean;
  protected
    function GetChart: TChart;

  public
    procedure Prepare(ASeries: TBasicChartSeries; ACaptionMask: String);

  end;

var
  SeriesEditor: TChartSeriesEditor;

implementation

{$R *.lfm}

procedure TChartSeriesEditor.FormActivate(Sender: TObject);
var
  w: Integer = 0;
  h: Integer = 0;
begin
  FSeriesFrame.GetPreferredSize(w, h);
  inc(w, FSeriesFrame.BorderSpacing.Around*2);
  inc(h, FSeriesFrame.BorderSpacing.Around*2);
  Constraints.MinHeight := h + ButtonPanel.Height + ButtonPanel.BorderSpacing.Around;
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
  FSeriesFrame := TChartSeriesFrame.Create(self);
  FSeriesFrame.Parent := Self;
  FSeriesFrame.Name := '';
  FSeriesFrame.Align := alClient;
  FSeriesFrame.BorderSpacing.Around := 8;
  FSeriesFrame.AutoSize := true;

  AutoSize := true;
end;

procedure TChartSeriesEditor.FormDestroy(Sender: TObject);
begin
  FSavedSeries.Free;
end;

function TChartSeriesEditor.GetChart: TChart;
begin
  Result := FSeries.ParentChart;
end;

procedure TChartSeriesEditor.OKButtonClick(Sender: TObject);
begin
  FOKClicked := true;
end;

procedure TChartSeriesEditor.Prepare(ASeries: TBasicChartSeries; ACaptionMask: String);
var
  seriesClass: TSeriesClass;
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

  FSeriesFrame.Prepare(ASeries);
end;

end.


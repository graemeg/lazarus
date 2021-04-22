unit ceMain;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics,
  Dialogs, Menus, StdCtrls, ExtCtrls, Types,
  TAGraph, TATools, TAChartAxis, TATextElements, TASeries, TASources,
  TALegend, TAChartImageList,
  ceAxisFrame;

type

  { TMainForm }

  TMainForm = class(TForm)
    Bevel1: TBevel;
    Chart1: TChart;
    Chart1AreaSeries1: TAreaSeries;
    Chart1BarSeries1: TBarSeries;
    Chart1LineSeries1: TLineSeries;
    ChartToolset1: TChartToolset;
    ChartToolset1AxisClickTool1: TAxisClickTool;
    ChartToolset1DataPointClickTool1: TDataPointClickTool;
    ChartToolset1LegendClickTool1: TLegendClickTool;
    ChartToolset1TitleFootClickTool1: TTitleFootClickTool;
    cbDoubleClick: TCheckBox;
    cbUseAllInOneDialog: TCheckBox;
    Label1: TLabel;
    MainMenu: TMainMenu;
    MenuItem1: TMenuItem;
    mnuSeries: TMenuItem;
    mnuChartLegend: TMenuItem;
    mnuLeftAxis: TMenuItem;
    mnuBottomAxis: TMenuItem;
    MenuItem2: TMenuItem;
    mnuChartFooter: TMenuItem;
    mnuChartTitle: TMenuItem;
    mnuSettings: TMenuItem;
    RandomChartSource1: TRandomChartSource;
    RandomChartSource2: TRandomChartSource;
    RandomChartSource3: TRandomChartSource;
    procedure ChartToolset1AxisClickTool1Click(ASender: TChartTool;
      Axis: TChartAxis; AHit: TChartAxisHitTests);
    procedure ChartToolset1DataPointClickTool1PointClick(ATool: TChartTool;
      APoint: TPoint);
    procedure ChartToolset1LegendClickTool1Click(ASender: TChartTool;
      ALegend: TChartLegend);
    procedure ChartToolset1TitleFootClickTool1Click(ASender: TChartTool;
      ATitle: TChartTitle);
    procedure cbDoubleClickChange(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure mnuBottomAxisClick(Sender: TObject);
    procedure mnuChartFooterClick(Sender: TObject);
    procedure mnuChartLegendClick(Sender: TObject);
    procedure mnuChartTitleClick(Sender: TObject);
    procedure mnuLeftAxisClick(Sender: TObject);
  private
    procedure ChartEditor(AChart: TChart);
    procedure EditAxis(AAxis: TChartAxis; APage: TChartAxisEditorPage);
    procedure EditLegend(ALegend: TChartLegend);
    procedure EditSeries(ASeries: TBasicChartSeries);
    procedure EditTitleFoot(ATitle: TChartTitle);
    procedure MenuSeriesClick(Sender: TObject);

  public

  end;

var
  MainForm: TMainForm;

implementation

{$R *.lfm}

uses
  TAChartUtils, TACustomSeries,
  ceTitleFootDlg, ceLegendDlg, ceSeriesDlg, ceAxisDlg, ceChartEditor, ceImages;

{ TMainForm }

procedure TMainForm.ChartEditor(AChart: TChart);
var
  F: TChartEditorForm;
begin
  F := TChartEditorForm.Create(nil);
  try
    F.Chart := AChart;
    F.ShowModal;
  finally
    F.Free;
  end;
end;

procedure TMainForm.ChartToolset1TitleFootClickTool1Click(ASender: TChartTool;
  ATitle: TChartTitle);
begin
  Unused(ASender);
  EditTitleFoot(ATitle);
end;

procedure TMainForm.cbDoubleClickChange(Sender: TObject);
var
  shift: TShiftState;
  s: String;
begin
  if cbDoubleClick.Checked then
  begin
    shift := [ssLeft, ssDouble];
    s := 'Double-click';
  end else
  begin
    shift := [ssLeft];
    s := 'Click';
  end;
  Label1.Caption := s + ' on a title, axis, label, grid, data point to open the corresponding editor.';

  ChartToolset1DatapointClickTool1.Shift := shift;
  ChartToolset1TitleFootClickTool1.Shift := shift;
  ChartToolset1LegendClickTool1.Shift := shift;
  ChartToolset1AxisClickTool1.Shift := shift;
end;

procedure TMainForm.FormCreate(Sender: TObject);
var
  i: Integer;
  item: TMenuItem;
begin
  ChartImagesDM.ChartImages.Chart := Chart1;

  for i := 0 to Chart1.SeriesCount-1 do begin
    item := TMenuItem.Create(MainMenu);
    item.Caption := TCustomChartSeries(Chart1.Series[i]).Title + '...';
    item.OnClick := @MenuSeriesClick;
    item.Tag := PtrInt(Chart1.Series[i]);
    item.ImageIndex := ChartImagesDM.ChartImages.FirstSeriesIndex + i;
    mnuSeries.Add(item);
  end;
end;

procedure TMainForm.mnuBottomAxisClick(Sender: TObject);
begin
  EditAxis(Chart1.BottomAxis, aepTitle);
end;

procedure TMainForm.ChartToolset1AxisClickTool1Click(ASender: TChartTool;
  Axis: TChartAxis; AHit: TChartAxisHitTests);
var
  pg: TChartAxisEditorPage;
begin
  Unused(ASender);
  if (ahtTitle in AHit) then
    pg := aepTitle
  else if (ahtLabels in AHit) then
    pg := aepLabels
  else if (ahtLine in AHit) then
    pg := aepLine
  else if (ahtGrid in AHit) then
    pg := aepGrid
  else
    exit;
  EditAxis(Axis, pg);
end;

procedure TMainForm.ChartToolset1DataPointClickTool1PointClick(ATool: TChartTool;
  APoint: TPoint);
begin
  Unused(APoint);
  EditSeries(TDataPointClickTool(ATool).Series);
end;

procedure TMainForm.ChartToolset1LegendClickTool1Click(ASender: TChartTool;
  ALegend: TChartLegend);
begin
  Unused(ASender);
  EditLegend(ALegend);
end;

procedure TMainForm.EditAxis(AAxis: TChartAxis; APage: TChartAxisEditorPage);
var
  F: TChartAxisEditor;
begin
  if cbUseAllInOneDialog.Checked then
    EditChartAxis(AAxis, APage)
  else
  begin
    F := TChartAxisEditor.Create(nil);
    try
      F.Prepare(AAxis, 'Edit chart axis "%s"');
      F.Page := APage;
      F.ShowModal;
    finally
      F.Free;
    end;
  end;
end;

procedure TMainForm.EditLegend(ALegend: TChartLegend);
var
  F: TChartLegendEditor;
begin
  if cbUseAllInOneDialog.Checked then
    EditChartLegend(ALegend.GetOwner as TChart)
  else
  begin
    F := TChartLegendEditor.Create(nil);
    try
      F.Prepare(ALegend, 'Edit chart legend');
      F.ShowModal;
    finally
      F.Free;
    end;
  end;
end;

procedure TMainForm.EditSeries(ASeries: TBasicChartSeries);
var
  F: TChartSeriesEditor;
begin
  if cbUseAllInOneDialog.Checked then
    EditChartSeries(ASeries)
  else
  begin
    F := TChartSeriesEditor.Create(nil);
    try
      F.Prepare(ASeries, 'Edit series "%s"');
      F.ShowModal;
    finally
      F.Free;
    end;
  end;
end;

procedure TMainForm.EditTitleFoot(ATitle: TChartTitle);
var
  F: TChartTitleFootEditor;
  s: String;
begin
  if cbUseAllInOneDialog.Checked then
  begin
    if ATitle = Chart1.Title then
      EditChartTitle(ATitle.GetOwner as TChart)
    else
    if ATitle = Chart1.Foot then
      EditChartFooter(ATitle.GetOwner as TChart);
  end else
  begin
    F := TChartTitleFootEditor.Create(nil);
    try
      s := 'Edit chart %s';
      if ATitle = Chart1.Title then s := Format(s, ['title']) else s := Format(s, ['footer']);
      F.Prepare(ATitle, s);
      F.ShowModal;
    finally
      F.Free;
    end;
  end;
end;

procedure TMainForm.MenuSeriesClick(Sender: TObject);
var
  ser: TBasicChartSeries;
begin
  ser := TBasicChartSeries(TMenuItem(Sender).Tag);
  EditSeries(ser);
end;

procedure TMainForm.mnuChartFooterClick(Sender: TObject);
begin
  EditTitleFoot(Chart1.Foot);
end;

procedure TMainForm.mnuChartLegendClick(Sender: TObject);
begin
  EditLegend(Chart1.Legend);
end;

procedure TMainForm.mnuChartTitleClick(Sender: TObject);
begin
  EditTitleFoot(Chart1.Title);
end;

procedure TMainForm.mnuLeftAxisClick(Sender: TObject);
begin
  EditAxis(Chart1.LeftAxis, aepTitle);
end;

end.


unit ceLegendDlg;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, ButtonPanel,
  ExtCtrls, Buttons, ComCtrls,
  TAGraph, TALegend,
  ceLegendFrame;

type

  { TChartLegendEditor }

  TChartLegendEditor = class(TForm)
    ButtonPanel: TButtonPanel;
    procedure FormCloseQuery(Sender: TObject; var CanClose: boolean);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure OKButtonClick(Sender: TObject);
  private
    FLegend: TChartLegend;
    FLegendFrame: TChartLegendFrame;
    FSavedLegend: TChartLegend;
    FOKClicked: Boolean;
  protected
    function GetChart: TChart;
  public
    procedure Prepare(ALegend: TChartLegend; ACaption: String = '');

  end;

var
  LegendEditor: TChartLegendEditor;

implementation

{$R *.lfm}

procedure TChartLegendEditor.FormCloseQuery(Sender: TObject; var CanClose: boolean);
begin
  if not CanClose then exit;
  if not FOKClicked then begin
    FLegend.Assign(FSavedLegend);
    GetChart.Invalidate;
  end;
end;

procedure TChartLegendEditor.FormCreate(Sender: TObject);
begin
  FLegendFrame := TChartLegendFrame.Create(self);
  FLegendFrame.Parent := self;
  FLegendFrame.Name := '';
  FLegendFrame.Align := alClient;
  FLegendFrame.BorderSpacing.Around := 8;
  FLegendFrame.AutoSize := true;

  AutoSize := true;
end;

procedure TChartLegendEditor.FormDestroy(Sender: TObject);
begin
  FSavedLegend.Free;
end;

procedure TChartLegendEditor.FormShow(Sender: TObject);
begin
  FOKClicked := false;
end;

function TChartLegendEditor.GetChart: TChart;
begin
  Result := FLegend.GetOwner as TChart;
end;

procedure TChartLegendEditor.OKButtonClick(Sender: TObject);
begin
  FOKClicked := true;
end;

procedure TChartLegendEditor.Prepare(ALegend: TChartLegend;
  ACaption: String = '');
begin
  FLegend := ALegend;
  if FSavedLegend = nil then
    FSavedLegend := TChartLegend.Create(nil);
  FSavedLegend.Assign(ALegend);

  if ACaption <> '' then
    Caption := ACaption;

  FLegendFrame.Prepare(ALegend);
end;

end.


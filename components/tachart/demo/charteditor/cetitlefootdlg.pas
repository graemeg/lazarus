unit ceTitleFootDlg;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Graphics,
  Forms, Controls, Dialogs, ButtonPanel, ExtCtrls, Buttons, ComCtrls,
  TAGraph, TATextElements,
  ceTitleFootFrame;

type

  { TChartTitleFootEditor }

  TChartTitleFootEditor = class(TForm)
    ButtonPanel: TButtonPanel;
    procedure FormActivate(Sender: TObject);
    procedure FormCloseQuery(Sender: TObject; var CanClose: boolean);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure OKButtonClick(Sender: TObject);
  private
    FTitle: TChartTitle;
    FSavedTitle: TChartTitle;
    FTitleFootFrame: TChartTitleFootFrame;
    FOKClicked: boolean;
  protected
    function GetChart: TChart;
  public
    procedure Prepare(ATitle: TChartTitle; ACaption: String = '');

  end;

var
  TitleFootEditor: TChartTitleFootEditor;

implementation

{$R *.lfm}

uses
  TATypes;

procedure TChartTitleFootEditor.FormActivate(Sender: TObject);
var
  h: Integer = 0;
  w: Integer = 0;
begin
  FTitleFootFrame.GetPreferredSize(w, h);
  inc(h, FTitleFootFrame.BorderSpacing.Around * 2);
  inc(w, FTitleFootFrame.BorderSpacing.Around * 2);

  Constraints.MinHeight := h + ButtonPanel.Height + ButtonPanel.BorderSpacing.Around*2;
  Constraints.MinWidth := w;

  Width := 1;   // Enforce the constraints.
  Height := 1;
end;

procedure TChartTitleFootEditor.FormCloseQuery(Sender: TObject;
  var CanClose: boolean);
begin
  if not CanClose then exit;
  if not FOKClicked then begin
    FTitle.Assign(FSavedTitle);
    GetChart.Invalidate;
  end;
end;

procedure TChartTitleFootEditor.FormCreate(Sender: TObject);
begin
  // Insert frames at runtime - this makes life much easier...
  FTitleFootFrame := TChartTitleFootFrame.Create(self);
  FTitleFootFrame.Parent := Self;
  FTitleFootFrame.Name := '';
  FTitleFootFrame.Align := alClient;
  FTitleFootFrame.BorderSpacing.Around := 8;
  FTitleFootFrame.AutoSize := true;

//  AutoSize := true;
end;

procedure TChartTitleFootEditor.FormDestroy(Sender: TObject);
begin
  FSavedTitle.Free;
end;

function TChartTitleFootEditor.GetChart: TChart;
begin
  Result := FTitle.GetOwner as TChart;
end;

procedure TChartTitleFootEditor.OKButtonClick(Sender: TObject);
begin
  FOKClicked := true;
end;

procedure TChartTitleFootEditor.Prepare(ATitle: TChartTitle; ACaption: String = '');
begin
  FTitle := ATitle;
  if FSavedTitle = nil then
    FSavedTitle := TChartTitle.Create(GetChart);
  FSavedTitle.Assign(FTitle);

  if ACaption <> '' then
    Caption := ACaption;

  FTitleFootFrame.Prepare(ATitle);
end;

end.


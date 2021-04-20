unit ceTitleFootDlg;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, ButtonPanel,
  ExtCtrls, Buttons, ComCtrls, ceShapeBrushPenMarginsFrame,
  ceFontFrame, TAGraph, TATextElements;

type

  { TChartTitleFootEditor }

  TChartTitleFootEditor = class(TForm)
    ButtonPanel: TButtonPanel;
    cbShow: TCheckBox;
    gbShapeBrushPenMargins: TGroupBox;
    gbFont: TGroupBox;
    lblText: TLabel;
    mmoText: TMemo;
    MemoPanel: TPanel;
    PanelTop: TPanel;
    ParamsPanel: TPanel;
    rgAlignment: TRadioGroup;
    procedure cbShowChange(Sender: TObject);
    procedure FormActivate(Sender: TObject);
    procedure FormCloseQuery(Sender: TObject; var CanClose: boolean);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure mmoTextChange(Sender: TObject);
    procedure OKButtonClick(Sender: TObject);
    procedure rgAlignmentClick(Sender: TObject);
  private
    FTitle: TChartTitle;
    FSavedTitle: TChartTitle;
    FFontFrame: TChartFontFrame;
    FShapeBrushPenMarginsFrame: TChartShapeBrushPenMarginsFrame;
    FOKClicked: boolean;
    procedure ChangedHandler(Sender: TObject);
    function GetAlignment: TAlignment;
    procedure SetAlignment(AValue: TAlignment);
    procedure ShapeChangedHandler(AShape: TChartLabelShape);
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
  TATypes,
  ceUtils;

procedure TChartTitleFootEditor.cbShowChange(Sender: TObject);
begin
  FTitle.Visible := cbShow.Checked;
  lblText.Visible := cbShow.Checked;
  mmoText.Visible := cbShow.Checked;
  rgAlignment.Visible := cbShow.Checked;
  gbShapeBrushPenMargins.Visible := cbShow.Checked;
  gbFont.Visible := cbShow.Checked;
end;

procedure TChartTitleFootEditor.FormActivate(Sender: TObject);
begin
  Constraints.MinHeight :=  PanelTop.Height +
    MemoPanel.Constraints.MinHeight +
    ParamsPanel.Height + ParamsPanel.BorderSpacing.Around*2 +
    ButtonPanel.Height + ButtonPanel.BorderSpacing.Around*2;

  Constraints.MinWidth := gbFont.Width +
    gbShapeBrushPenMargins.Width + gbShapeBrushPenMargins.BorderSpacing.Left +
    ParamsPanel.BorderSpacing.Around * 2;

  Width := 1;   // Enforce the constraints.
  Height := 1;
end;

procedure TChartTitleFootEditor.ChangedHandler(Sender: TObject);
begin
  GetChart.Invalidate;
  mmoText.Font.Assign(FTitle.Font);
  mmoText.Color := FTitle.Brush.Color;
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
  FFontFrame := TChartFontFrame.Create(self);
  FFontFrame.Parent := gbFont;
  FFontFrame.Align := alClient;
  FFontFrame.BorderSpacing.Left := 8;
  FFontFrame.BorderSpacing.Right := 8;
  FFontFrame.BorderSpacing.Bottom := 0;//8;
  FFontFrame.OnChange := @ChangedHandler;
  gbFont.AutoSize := true;

  FShapeBrushPenMarginsFrame := TChartShapeBrushPenMarginsFrame.Create(self);
  FShapeBrushPenMarginsFrame.Parent := gbShapeBrushPenMargins;
  FShapeBrushPenMarginsFrame.Align := alClient;
  FShapeBrushPenMarginsFrame.BorderSpacing.Left := 8;
  FShapeBrushPenMarginsFrame.BorderSpacing.Right := 8;
  FShapeBrushPenMarginsFrame.BorderSpacing.Bottom := 8;
  FShapeBrushPenMarginsFrame.Constraints.MinWidth := 230;
  FShapeBrushPenMarginsFrame.OnChange := @ChangedHandler;
  FShapeBrushPenMarginsFrame.OnShapeChange := @ShapeChangedHandler;
  gbShapeBrushPenMargins.AutoSize := true;

  BoldHeaders(Self);

  ParamsPanel.AutoSize := true;
end;

procedure TChartTitleFootEditor.FormDestroy(Sender: TObject);
begin
  FSavedTitle.Free;
end;

procedure TChartTitleFootEditor.FormShow(Sender: TObject);
begin
  (*
  if cbShow.Checked then begin
    AutoSize := true;
    Constraints.MinWidth := Width;
    Constraints.MinHeight := Height;
    AutoSize := false;
  end;
  *)
end;

procedure TChartTitleFootEditor.mmoTextChange(Sender: TObject);
begin
  FTitle.Text.Assign(mmoText.Lines);
end;

function TChartTitleFootEditor.GetAlignment: TAlignment;
const
  ALIGNMENTS: array[0..2] of TAlignment = (taLeftJustify, taCenter, taRightJustify);
begin
  Result := ALIGNMENTS[rgAlignment.ItemIndex];
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

  cbShow.Checked := ATitle.Visible;
  mmoText.Lines.Assign(ATitle.Text);
  SetAlignment(ATitle.Alignment);

  mmoText.Font.Assign(ATitle.Font);
  mmoText.Font.Orientation := 0;
  FFontFrame.Prepare(ATitle.Font, false);
  FShapeBrushPenMarginsFrame.Prepare(ATitle.Shape, ATitle.Brush, ATitle.Frame, ATitle.Margins);
end;

procedure TChartTitleFootEditor.rgAlignmentClick(Sender: TObject);
begin
  FTitle.Alignment := GetAlignment;
end;

procedure TChartTitleFootEditor.SetAlignment(AValue: TAlignment);
const
  ALIGNMENTS: array[TAlignment] of Integer = (0, 2, 1);
begin
  rgAlignment.ItemIndex := ALIGNMENTS[AValue];
end;

procedure TChartTitleFootEditor.ShapeChangedHandler(AShape: TChartLabelShape);
begin
  FTitle.Shape := AShape;
end;

end.


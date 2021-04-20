unit ceLegendDlg;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, ButtonPanel,
  ExtCtrls, Buttons, ColorBox, ComCtrls, Spin, ceFontFrame,
  TAGraph, TALegend;

type

  { TChartLegendEditor }

  TChartLegendEditor = class(TForm)
    Bevel1: TBevel;
    ButtonPanel: TButtonPanel;
    cbFilled: TCheckBox;
    cbShowBorder: TCheckBox;
    cbShow: TCheckBox;
    cbFillColor: TColorBox;
    cbBorderColor: TColorBox;
    cbInverted: TCheckBox;
    cbUseSideBar: TCheckBox;
    cbItemFillOrder: TComboBox;
    gbBackground: TGroupBox;
    gbBorder: TGroupBox;
    gbFont: TGroupBox;
    gbMargins: TGroupBox;
    gbItems: TGroupBox;
    lblMarginX: TLabel;
    lblMarginY: TLabel;
    lblItemFillOrder: TLabel;
    lblColumns: TLabel;
    lblSymbolWidth: TLabel;
    lblSpacing: TLabel;
    PanelTop: TPanel;
    ParamsPanel: TPanel;
    rbTopLeft: TRadioButton;
    rbTopCenter: TRadioButton;
    rbTopRight: TRadioButton;
    rbCenterLeft: TRadioButton;
    rbCenterRight: TRadioButton;
    rbBottomLeft: TRadioButton;
    rbBottomCenter: TRadioButton;
    rbBottomRight: TRadioButton;
    gbAlignment: TGroupBox;
    seColumns: TSpinEdit;
    seMarginX: TSpinEdit;
    seMarginY: TSpinEdit;
    seSymbolWidth: TSpinEdit;
    seSpacing: TSpinEdit;
    procedure cbBorderColorChange(Sender: TObject);
    procedure cbFillColorChange(Sender: TObject);
    procedure cbInvertedChange(Sender: TObject);
    procedure cbItemFillOrderChange(Sender: TObject);
    procedure cbFilledChange(Sender: TObject);
    procedure cbShowBorderChange(Sender: TObject);
    procedure cbShowChange(Sender: TObject);
    procedure cbUseSideBarChange(Sender: TObject);
    procedure FormCloseQuery(Sender: TObject; var CanClose: boolean);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure OKButtonClick(Sender: TObject);
    procedure rbAlignmentChange(Sender: TObject);
    procedure seColumnsChange(Sender: TObject);
    procedure seMarginXChange(Sender: TObject);
    procedure seMarginYChange(Sender: TObject);
    procedure seSpacingChange(Sender: TObject);
    procedure seSymbolWidthChange(Sender: TObject);
  private
    FLegend: TChartLegend;
    FSavedLegend: TChartLegend;
    FOKClicked: Boolean;
    FFontFrame: TChartFontFrame;
    procedure ChangedHandler(Sender: TObject);
    function GetAlignment: TLegendAlignment;
    procedure SetAlignment(AValue: TLegendAlignment);
  protected
    function GetChart: TChart;
  public
    procedure Prepare(ALegend: TChartLegend; ACaption: String = '');

  end;

var
  LegendEditor: TChartLegendEditor;

implementation

{$R *.lfm}

uses
  ceUtils;

procedure TChartLegendEditor.cbBorderColorChange(Sender: TObject);
begin
  FLegend.Frame.Color := cbBorderColor.Selected;
end;

procedure TChartLegendEditor.cbFillColorChange(Sender: TObject);
begin
  FLegend.BackgroundBrush.Color := cbFillColor.Selected;
end;

procedure TChartLegendEditor.cbInvertedChange(Sender: TObject);
begin
  FLegend.Inverted := cbInverted.Checked;
end;

procedure TChartLegendEditor.cbItemFillOrderChange(Sender: TObject);
begin
  FLegend.ItemFillOrder := TLegendItemFillOrder(cbItemFillOrder.ItemIndex);
end;

procedure TChartLegendEditor.cbFilledChange(Sender: TObject);
begin
  cbFillColor.Visible := cbFilled.Checked;
  if cbFilled.Checked then
    FLegend.BackgroundBrush.Style := bsSolid
  else
    FLegend.BackgroundBrush.Style := bsClear;
end;

procedure TChartLegendEditor.cbShowBorderChange(Sender: TObject);
begin
  FLegend.Frame.Visible := cbShowBorder.Checked;
  cbBorderColor.Visible := cbShowBorder.Checked;
end;

procedure TChartLegendEditor.cbShowChange(Sender: TObject);
begin
  FLegend.Visible := cbShow.Checked;
  cbUseSideBar.Visible := cbShow.Checked;
  gbAlignment.Visible := cbShow.Checked;
  gbFont.Visible := cbShow.Checked;
  gbBackground.Visible := cbShow.Checked;
  gbBorder.Visible := cbShow.Checked;
  gbItems.Visible := cbShow.Checked;
  gbMargins.Visible := cbShow.Checked;
end;

procedure TChartLegendEditor.cbUseSideBarChange(Sender: TObject);
begin
  FLegend.UseSideBar := cbUseSideBar.Checked;
end;

procedure TChartLegendEditor.ChangedHandler(Sender: TObject);
begin
  GetChart.Invalidate;
end;

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
  FFontFrame := TChartFontFrame.Create(self);
  FFontFrame.Parent := gbFont;
  FFontFrame.Name := '';
  FFontFrame.Align := alClient;
  FFontFrame.BorderSpacing.Left := 8;
  FFontFrame.BorderSpacing.Right := 8;
  FFontFrame.AutoSize := true;
  FFontFrame.OnChange := @ChangedHandler;
  gbFont.AutoSize := true;
  gbFont.Caption := 'Font';

  BoldHeaders(Self);
end;

procedure TChartLegendEditor.FormDestroy(Sender: TObject);
begin
  FSavedLegend.Free;
end;

procedure TChartLegendEditor.FormShow(Sender: TObject);
begin
  if cbShow.Checked then begin
    AutoSize := true;
    Constraints.MinWidth := Width;
    Constraints.MinHeight := Height;
    AutoSize := false;
  end;

  FOKClicked := false;
end;

function TChartLegendEditor.GetAlignment: TLegendAlignment;
var
  i: Integer;
  rb: TRadioButton;
begin
  for i := 0 to gbAlignment.ControlCount-1 do
    if (gbAlignment.Controls[i] is TRadioButton) then begin
      rb := TRadioButton(gbAlignment.Controls[i]);
      if rb.Checked then begin
        Result := TLegendAlignment(rb.Tag);
        exit;
      end;
    end;
  Result := laTopRight;
end;

function TChartLegendEditor.GetChart: TChart;
begin
  Result := FLegend.GetOwner as TChart;
end;

procedure TChartLegendEditor.OKButtonClick(Sender: TObject);
begin
  FOKClicked := true;
end;

procedure TChartLegendEditor.rbAlignmentChange(Sender: TObject);
begin
  FLegend.Alignment := GetAlignment;
end;

procedure TChartLegendEditor.seColumnsChange(Sender: TObject);
begin
  FLegend.ColumnCount := seColumns.Value;
end;

procedure TChartLegendEditor.seMarginXChange(Sender: TObject);
begin
  FLegend.MarginX := seMarginX.Value;
end;

procedure TChartLegendEditor.seMarginYChange(Sender: TObject);
begin
  FLegend.MarginY := seMarginY.Value;
end;

procedure TChartLegendEditor.seSpacingChange(Sender: TObject);
begin
  FLegend.Spacing := seSpacing.Value;
end;

procedure TChartLegendEditor.seSymbolWidthChange(Sender: TObject);
begin
  FLegend.SymbolWidth := seSymbolWidth.Value;
end;

procedure TChartLegendEditor.SetAlignment(AValue: TLegendAlignment);
var
  i: Integer;
  rb: TRadioButton;
begin
  for i:=0 to gbAlignment.ControlCount-1 do
    if (gbAlignment.Controls[i] is TRadioButton) then begin
      rb := TRadioButton(gbAlignment.Controls[i]);
      if rb.Tag = ord(AValue) then begin
        rb.Checked := true;
        exit;
      end;
    end;
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

  cbShow.Checked := ALegend.Visible;
  SetAlignment(ALegend.Alignment);

  cbFilled.Checked := ALegend.BackgroundBrush.Style <> bsClear;
  cbFillColor.Selected := ColorToRGB(ALegend.BackgroundBrush.Color);

  cbShowBorder.Checked := (ALegend.Frame.Style <> psClear) and ALegend.Frame.Visible;
  cbBorderColor.Selected := ColorToRGB(ALegend.Frame.Color);

  seMarginX.Value := ALegend.MarginX;
  seMarginY.Value := ALegend.MarginY;

  cbUseSideBar.Checked := ALegend.UseSidebar;
  cbInverted.Checked := ALegend.Inverted;
  seColumns.Value := ALegend.ColumnCount;
  seSymbolWidth.Value := ALegend.SymbolWidth;
  seSpacing.Value := ALegend.Spacing;
  cbItemFillOrder.ItemIndex := ord(ALegend.ItemFillOrder);

  FFontFrame.Prepare(ALegend.Font, false);
end;

end.


unit ceLegendFrame;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, Graphics,
  Forms, Controls, ExtCtrls, ColorBox, StdCtrls, Spin,
  TALegend, TAGraph,
  ceFontFrame;

type

  { TChartLegendFrame }

  TChartLegendFrame = class(TFrame)
    Bevel1: TBevel;
    cbBorderColor: TColorBox;
    cbFillColor: TColorBox;
    cbFilled: TCheckBox;
    cbInverted: TCheckBox;
    cbItemFillOrder: TComboBox;
    cbShow: TCheckBox;
    cbShowBorder: TCheckBox;
    cbUseSideBar: TCheckBox;
    gbAlignment: TGroupBox;
    gbBackground: TGroupBox;
    gbBorder: TGroupBox;
    gbFont: TGroupBox;
    gbItems: TGroupBox;
    gbMargins: TGroupBox;
    lblColumns: TLabel;
    lblItemFillOrder: TLabel;
    lblMarginX: TLabel;
    lblMarginY: TLabel;
    lblSpacing: TLabel;
    lblSymbolWidth: TLabel;
    PanelTop: TPanel;
    ParamsPanel: TPanel;
    rbBottomCenter: TRadioButton;
    rbBottomLeft: TRadioButton;
    rbBottomRight: TRadioButton;
    rbCenterLeft: TRadioButton;
    rbCenterRight: TRadioButton;
    rbTopCenter: TRadioButton;
    rbTopLeft: TRadioButton;
    rbTopRight: TRadioButton;
    seColumns: TSpinEdit;
    seMarginX: TSpinEdit;
    seMarginY: TSpinEdit;
    seSpacing: TSpinEdit;
    seSymbolWidth: TSpinEdit;
    procedure cbBorderColorChange(Sender: TObject);
    procedure cbFillColorChange(Sender: TObject);
    procedure cbFilledChange(Sender: TObject);
    procedure cbInvertedChange(Sender: TObject);
    procedure cbItemFillOrderChange(Sender: TObject);
    procedure cbShowBorderChange(Sender: TObject);
    procedure cbShowChange(Sender: TObject);
    procedure cbUseSideBarChange(Sender: TObject);
    procedure gbAlignmentClick(Sender: TObject);
    procedure seColumnsChange(Sender: TObject);
    procedure seMarginXChange(Sender: TObject);
    procedure seMarginYChange(Sender: TObject);
    procedure seSpacingChange(Sender: TObject);
    procedure seSymbolWidthChange(Sender: TObject);
  private
    FLegend: TChartLegend;
    FFontFrame: TChartFontFrame;
    procedure ChangedHandler(Sender: TObject);
    function GetAlignment: TLegendAlignment;
    procedure SetAlignment(AValue: TLegendAlignment);
  protected
    function GetChart: TChart;
  public
    constructor Create(AOwner: TComponent); override;
    procedure Prepare(ALegend: TChartLegend);
  end;


implementation

{$R *.lfm}

uses
  ceUtils;

constructor TChartLegendFrame.Create(AOwner: TComponent);
begin
  inherited;

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

procedure TChartLegendFrame.cbBorderColorChange(Sender: TObject);
begin
  FLegend.Frame.Color := cbBorderColor.Selected;
end;

procedure TChartLegendFrame.cbFilledChange(Sender: TObject);
begin
  cbFillColor.Visible := cbFilled.Checked;
  if cbFilled.Checked then
    FLegend.BackgroundBrush.Style := bsSolid
  else
    FLegend.BackgroundBrush.Style := bsClear;
end;

procedure TChartLegendFrame.cbFillColorChange(Sender: TObject);
begin
  FLegend.BackgroundBrush.Color := cbFillColor.Selected;
end;

procedure TChartLegendFrame.cbInvertedChange(Sender: TObject);
begin
  FLegend.Inverted := cbInverted.Checked;
end;

procedure TChartLegendFrame.cbItemFillOrderChange(Sender: TObject);
begin
  FLegend.ItemFillOrder := TLegendItemFillOrder(cbItemFillOrder.ItemIndex);
end;

procedure TChartLegendFrame.cbShowChange(Sender: TObject);
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

procedure TChartLegendFrame.cbShowBorderChange(Sender: TObject);
begin
  FLegend.Frame.Visible := cbShowBorder.Checked;
  cbBorderColor.Visible := cbShowBorder.Checked;
end;

procedure TChartLegendFrame.cbUseSideBarChange(Sender: TObject);
begin
  FLegend.UseSideBar := cbUseSideBar.Checked;
end;

procedure TChartLegendFrame.ChangedHandler(Sender: TObject);
begin
  GetChart.Invalidate;
end;

function TChartLegendFrame.GetChart: TChart;
begin
  Result := FLegend.GetOwner as TChart;
end;

procedure TChartLegendFrame.Prepare(ALegend: TChartLegend);
begin
  FLegend := ALegend;

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

function TChartLegendFrame.GetAlignment: TLegendAlignment;
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

procedure TChartLegendFrame.gbAlignmentClick(Sender: TObject);
begin
  FLegend.Alignment := GetAlignment;
end;

procedure TChartLegendFrame.seColumnsChange(Sender: TObject);
begin
  FLegend.ColumnCount := seColumns.Value;
end;

procedure TChartLegendFrame.seMarginXChange(Sender: TObject);
begin
  FLegend.MarginX := seMarginX.Value;
end;

procedure TChartLegendFrame.seMarginYChange(Sender: TObject);
begin
  FLegend.MarginY := seMarginY.Value;
end;

procedure TChartLegendFrame.seSpacingChange(Sender: TObject);
begin
  FLegend.Spacing := seSpacing.Value;
end;

procedure TChartLegendFrame.seSymbolWidthChange(Sender: TObject);
begin
  FLegend.SymbolWidth := seSymbolWidth.Value;
end;

procedure TChartLegendFrame.SetAlignment(AValue: TLegendAlignment);
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

end.


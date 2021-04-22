unit ceShapeBrushPenMarginsFrame;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Graphics, Forms, Controls, StdCtrls, Dialogs, Spin, ExtCtrls,
  TATypes, TATextElements;

type

  TChartShapeChangeEvent = procedure (AShape: TChartLabelShape) of object;

  { TChartShapeBrushPenMarginsFrame }

  TChartShapeBrushPenMarginsFrame = class(TFrame)
    Spacer: TBevel;
    cbBorderColor: TColorButton;
    cbFillColor: TColorButton;
    cbFilled: TCheckBox;
    cbShowBorder: TCheckBox;
    cmbShape: TComboBox;
    gbBackground: TGroupBox;
    gbBorder: TGroupBox;
    gbMargins: TGroupBox;
    seBottomMargin: TSpinEdit;
    seLeftMargin: TSpinEdit;
    seRightMargin: TSpinEdit;
    seTopMargin: TSpinEdit;
    procedure cbBorderColorColorChanged(Sender: TObject);
    procedure cbFillColorColorChanged(Sender: TObject);
    procedure cbFilledChange(Sender: TObject);
    procedure cbShowBorderChange(Sender: TObject);
    procedure cmbShapeChange(Sender: TObject);
    procedure seBottomMarginChange(Sender: TObject);
    procedure seLeftMarginChange(Sender: TObject);
    procedure seRightMarginChange(Sender: TObject);
    procedure seTopMarginChange(Sender: TObject);
  private
    FOnChange: TNotifyEvent;
    FOnShapeChange: TChartShapeChangeEvent;
    FBrush: TBrush;
    FPen: TChartPen;
    FMargins: TChartLabelMargins;
    FShape: TChartLabelShape;
    FLockEvents: Integer;
    procedure DoChanged;
    procedure DoShapeChanged(AShape: TChartLabelShape);
    procedure UpdateControls;
  protected
    procedure CalculatePreferredSize(var PreferredWidth, PreferredHeight: integer;
      {%H-}WithThemeSpace: Boolean); override;
  public
    constructor Create(AOwner: TComponent); override;
    procedure GetData(out AShape: TChartLabelShape; ABrush: TBrush;
      APen: TChartPen; AMargins: TChartLabelMargins);
    procedure Prepare(AShape: TChartLabelShape; ABrush: TBrush; APen: TChartPen;
      AMargins: TChartLabelMargins);
    property OnChange: TNotifyEvent read FOnChange write FOnChange;
    property OnShapeChange: TChartShapeChangeEvent read FOnShapeChange write FOnShapeChange;
  end;

implementation

{$R *.lfm}

uses
  Math,
  ceUtils;

{ TChartShapeBrushPenMarginsFrame }

constructor TChartShapeBrushPenMarginsFrame.Create(AOwner: TComponent);
begin
  inherited;
  cbFillColor.Width := cbFillColor.Height;
  cbBorderColor.Width := cbBorderColor.Height;
  cmbShape.DropdownCount := DEFAULT_DROPDOWN_COUNT;
end;

procedure TChartShapeBrushPenMarginsFrame.CalculatePreferredSize(
  var PreferredWidth, PreferredHeight: integer;
  WithThemeSpace: Boolean);
begin
  PreferredHeight := cmbShape.Height +
    gbBackground.BorderSpacing.Top + gbBackground.Height +
    gbMargins.BorderSpacing.Top + gbMargins.Height;

  PreferredWidth := Max(
    Max(gbBackground.Width, gbBorder.Width) * 2 + Spacer.Width,
    gbMargins.Width
  );;
end;

procedure TChartShapeBrushPenMarginsFrame.cbBorderColorColorChanged(Sender: TObject);
begin
  FPen.Color := cbBorderColor.ButtonColor;
//  if FPen.Style <> psClear then
    DoChanged;
end;

procedure TChartShapeBrushPenMarginsFrame.cbFillColorColorChanged(Sender: TObject);
var
  bs: TBrushStyle;
begin
  bs := FBrush.Style;
  FBrush.Color := cbFillColor.ButtonColor;
  FBrush.Style := bs;
//  if FBrush.Style <> bsClear then
    DoChanged;
end;

procedure TChartShapeBrushPenMarginsFrame.cbFilledChange(Sender: TObject);
begin
  if cbFilled.Checked then FBrush.Style := bsSolid else FBrush.Style := bsClear;
  UpdateControls;
  DoChanged;
end;

procedure TChartShapeBrushPenMarginsFrame.cbShowBorderChange(Sender: TObject);
begin
  FPen.Visible := cbShowBorder.Checked;
  if FPen.Visible and (FPen.Style = psClear) then FPen.Style := psSolid;
  UpdateControls;
  DoChanged;
end;

procedure TChartShapeBrushPenMarginsFrame.cmbShapeChange(Sender: TObject);
begin
  DoShapeChanged(TChartLabelShape(cmbShape.ItemIndex));
end;

procedure TChartShapeBrushPenMarginsFrame.DoChanged;
begin
  if (FLockEvents = 0) and Assigned(FOnChange) then
    FOnChange(Self);
end;

procedure TChartShapeBrushPenMarginsFrame.DoShapeChanged(AShape: TChartLabelShape);
begin
  if (FLockEvents = 0) and Assigned(FOnShapeChange) then
    FOnShapeChange(AShape);
end;

procedure TChartShapeBrushPenMarginsFrame.seBottomMarginChange(Sender: TObject);
begin
  FMargins.Bottom := seBottomMargin.Value;
  DoChanged;
end;

procedure TChartShapeBrushPenMarginsFrame.seLeftMarginChange(Sender: TObject);
begin
  FMargins.Left := seLeftMargin.Value;
  DoChanged;
end;

procedure TChartShapeBrushPenMarginsFrame.seRightMarginChange(Sender: TObject);
begin
  FMargins.Right := seRightMargin.Value;
  DoChanged;
end;

procedure TChartShapeBrushPenMarginsFrame.seTopMarginChange(Sender: TObject);
begin
  FMargins.Top := seTopMargin.Value;
  DoChanged;
end;

procedure TChartShapeBrushPenMarginsFrame.GetData(out AShape: TChartLabelShape;
  ABrush: TBrush; APen: TChartPen; AMargins: TChartLabelMargins);
begin
  AShape := TChartLabelShape(cmbShape.ItemIndex);
  if HandleAllocated then
  begin
    if cbFilled.Checked then ABrush.Style := bsSolid else ABrush.Style := bsClear;
    ABrush.Color := cbFillColor.ButtonColor;
    APen.Visible := cbShowBorder.Checked;
    APen.Style := psSolid;
    APen.Color := cbBorderColor.ButtonColor;
  end;
  AMargins.Top := seTopMargin.Value;
  AMargins.Left := seLeftMargin.Value;
  AMargins.Right := seRightMargin.Value;
  AMargins.Bottom := seBottomMargin.Value;
end;

procedure TChartShapeBrushPenMarginsFrame.Prepare(AShape: TChartLabelShape;
  ABrush: TBrush; APen: TChartPen; AMargins: TChartLabelMargins);
begin
  inc(FLockEvents);
  FShape := AShape;
  FBrush := ABrush;
  FPen := APen;
  FMargins := AMargins;
  cmbShape.ItemIndex := ord(AShape);
  cbFilled.Checked := ABrush.Style <> bsClear;
  cbFillColor.ButtonColor := ColorToRGB(ABrush.Color);
  cbShowBorder.Checked := APen.EffVisible;
  if APen.Color = clDefault then
    cbBorderColor.ButtonColor := ColorToRGB(clWindowText)
  else
    cbBorderColor.ButtonColor := ColorToRGB(APen.Color);
  seTopMargin.Value := AMargins.Top;
  seLeftMargin.Value := AMargins.Left;
  seRightMargin.Value := AMargins.Right;
  seBottomMargin.Value := AMargins.Bottom;
  dec(FLockEvents);
end;

procedure TChartShapeBrushPenMarginsFrame.UpdateControls;
begin
  cbBorderColor.Visible := cbShowBorder.Checked;
  cmbShape.Enabled := cbShowBorder.Checked or cbFilled.Checked;
  cbFillColor.Visible := cbFilled.Checked;
end;

end.


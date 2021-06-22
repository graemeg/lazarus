{
 *****************************************************************************
  This file is part of the Printer4Lazarus package

  See the file COPYING.modifiedLGPL.txt, included in this distribution,
  for details about the license.
 *****************************************************************************
}
unit framePageSetup;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils,
  // LCL
  LCLIntf, LCLProc, LResources, Controls, Graphics, Forms, ExtCtrls, StdCtrls,
  Spin, Printers,
  // Printers
  CupsLCL, Printer4LazStrConst;

type
  { TframePageSetup }

  TframePageSetup = class(TFrame)
    cbPaper: TComboBox;
    cbSource: TComboBox;
    Label1: TLabel;
    panMargins: TPanel;
    txtLeft: TFloatSpinEdit;
    txtTop: TFloatSpinEdit;
    txtRight: TFloatSpinEdit;
    txtBottom: TFloatSpinEdit;
    gpPaper: TGroupBox;
    gpOrientation: TGroupBox;
    gpMargins: TGroupBox;
    lblSource: TLabel;
    lblPaper: TLabel;
    lblLeft: TLabel;
    lblRight: TLabel;
    lblTop: TLabel;
    lblBottom: TLabel;
    pbPreview: TPaintBox;
    panSetup: TPanel;
    panPreview: TPanel;
    radLandscape: TRadioButton;
    radPortrait: TRadioButton;
    procedure cbPaperChange(Sender: TObject);
    procedure pbPreviewPaint(Sender: TObject);
    procedure radPortraitClick(Sender: TObject);
    procedure txtLeftChange(Sender: TObject);
  private
    function NToInches: double;
    procedure RotateMargins(AOrder: boolean);
  public
    UnitInches: boolean;
    EnablePreview: boolean;
    EnableMargins: boolean;
    EnablePapers: boolean;
    EnableOrientation: boolean;
    CurPageWidth: double;
    CurPageHeight: double;
    procedure Initialize(AEnablePreview, AEnableMargins, AEnablePapers,
      AEnableOrientation: boolean);
    procedure UpdatePageSize;
    procedure UpdateMaxValues;
    procedure SetDefaultMinMargins;
  end;

implementation

{$R framepagesetup.lfm}

{ TframePageSetup }

function TframePageSetup.NToInches: double;
begin
  if UnitInches then
    Result:= 1
  else
    Result:= 1/25.4;
end;

procedure TframePageSetup.RotateMargins(AOrder: boolean);
var
  m_l, m_t, m_r, m_b: double;
begin
  m_l:= txtLeft.Value;
  m_t:= txtTop.Value;
  m_r:= txtRight.Value;
  m_b:= txtBottom.Value;

  if AOrder then
  begin
    txtLeft.Value:= m_b;
    txtTop.Value:= m_l;
    txtRight.Value:= m_t;
    txtBottom.Value:= m_r;
  end
  else
  begin
    txtLeft.Value:= m_t;
    txtTop.Value:= m_r;
    txtRight.Value:= m_b;
    txtBottom.Value:= m_l;
  end;

  // same way must change MinValues
  m_l:= txtLeft.MinValue;
  m_t:= txtTop.MinValue;
  m_r:= txtRight.MinValue;
  m_b:= txtBottom.MinValue;

  if AOrder then
  begin
    txtLeft.MinValue:= m_b;
    txtTop.MinValue:= m_l;
    txtRight.MinValue:= m_t;
    txtBottom.MinValue:= m_r;
  end
  else
  begin
    txtLeft.MinValue:= m_t;
    txtTop.MinValue:= m_r;
    txtRight.MinValue:= m_b;
    txtBottom.MinValue:= m_l;
  end;
end;

procedure TframePageSetup.pbPreviewPaint(Sender: TObject);
const
  cTopBottomMargin = 8;
  cPadding = 6;
  cShadowSize = 4;
  cDimLineHeight = 12;
  cDimLineTail = 3;
var
  rc: TRect;
  txtHeight, fHeight, fWidth, fx, fy, vCenter: Integer;
  FUnitsStr, str: string;
begin
  if not EnablePreview then
    exit;

  if UnitInches then
    FUnitsStr := p4lrsAbbrevUnitsInches
  else
    FUnitsStr := p4lrsAbbrevUnitsMm;

  with pbPreview, Canvas do
  begin
    Pen.Color := clBlack;
    txtHeight := TextHeight('A');
    // center
    vCenter := Height div 2;
    // adjust center
    if CurPageHeight > CurPageWidth then;
      vCenter := vCenter - (txtHeight + cDimLineHeight + cPadding) div 2;
    // compute height/width
    fHeight := Height - cTopBottomMargin * 2 - txtHeight - cDimLineHeight - cPadding;
    if CurPageHeight > CurPageWidth then
      fWidth := Round(CurPageWidth / CurPageHeight * fHeight)
    else
    begin
      fWidth := fHeight;
      fHeight := Round(CurPageHeight / CurPageWidth * fWidth);
    end;
    // draw paper and shadow
    fx := (Width - fWidth) div 2;
    fy := vCenter - (fHeight div 2);
    Brush.Color := clGrayText;
    Pen.Style := psClear;
    rc := Rect(fx, fy, fx + fWidth, fy + fHeight);
    rc.Offset(cShadowSize, cShadowSize);
    Rectangle(rc);
    Brush.Color := clWhite;
    Pen.Style := psSolid;
    rc.Offset(-cShadowSize, -cShadowSize);
    Rectangle(rc);
    // draw margins
    rc.Left := rc.Left + Round(txtLeft.Value * fWidth / CurPageWidth);
    rc.Top := rc.Top + Round(txtTop.Value * fHeight / CurPageHeight);
    rc.Right := rc.Right - Round(txtRight.Value * fWidth / CurPageWidth);
    rc.Bottom := rc.Bottom - Round(txtBottom.Value * fHeight / CurPageHeight);
    Pen.Color := clGray;
    Pen.Style := psDot;
    Rectangle(rc);
    // bottom dimension line
    Pen.Color := clBlack;
    Pen.Style := psSolid;
    fy := fy + fHeight + cPadding + cDimLineHeight div 2;
    Line(fx, fy, fx + fWidth, fy);
    Line(fx, fy - cDimLineTail, fx, fy + cDimLineTail + 1);
    fx := fx + fWidth - 1;
    Line(fx, fy - cDimLineTail, fx, fy + cDimLineTail + 1);
    // bottom dimension text
    Brush.Style := bsClear;
    str := FormatFloat(',0.00 ', CurPageWidth) + FUnitsStr;
    fy := fy + cDimLineHeight div 2;
    TextOut((Width - TextWidth(str)) div 2, fy, str);
    // left dimension line
    fy := vCenter - (fHeight div 2);
    fx := (Width - fWidth) div 2 - cPadding - cDimLineHeight div 2;
    Line(fx, fy, fx, fy + fHeight);
    Line(fx - cDimLineTail, fy, fx + cDimLineTail + 1, fy);
    fy := fy + fHeight - 1;
    Line(fx - cDimLineTail, fy, fx + cDimLineTail + 1, fy);
    // left dimension text
    Brush.Style := bsClear;
    str := FormatFloat(',0.00 ', CurPageHeight) + FUnitsStr;
    fy := fy - fHeight div 2 - txtHeight div 2;
    TextOut(fx - cDimLineHeight div 2 - TextWidth(str), fy, str);
  end;
end;

procedure TframePageSetup.radPortraitClick(Sender: TObject);
begin
  RotateMargins(radPortrait.Checked);
  if radPortrait.Checked then
    Printer.Orientation := poPortrait
  else
    Printer.Orientation := poLandsCape;
  UpdatePageSize;
end;

procedure TframePageSetup.txtLeftChange(Sender: TObject);
begin
  pbPreview.Invalidate;
end;

procedure TframePageSetup.cbPaperChange(Sender: TObject);
begin
  if Printer.PaperSize.DefaultPapers then
  begin
    if cbPaper.ItemIndex>=0 then
      Printer.PaperSize.PaperName := cbPaper.Items[cbPaper.ItemIndex];
  end else
    Printer.PaperSize.PaperName := GetCupsComboKeyValue(cbPaper);
  UpdatePageSize;
end;

procedure TframePageSetup.UpdatePageSize;
var
  FLastPageWidth, FLastPageHeight: Double;
begin
  if not EnablePreview then
    exit;

  with Printer.PaperSize.PaperRect do
  begin
    // save last size
    FLastPageWidth := CurPageWidth;
    FLastPageHeight := CurPageHeight;
    CurPageWidth := (PhysicalRect.Right-PhysicalRect.Left)/Printer.XDPI/NToInches;
    CurPageHeight := (PhysicalRect.Bottom-PhysicalRect.Top)/Printer.YDPI/NToInches;
  end;
  // revert to last size if invalid (custom?)
  if (CurPageWidth <= 0) or (CurPageHeight <= 0) then
  begin
    CurPageWidth := FLastPageWidth;
    CurPageHeight := FLastPageHeight;
  end;

  UpdateMaxValues;
end;

procedure TframePageSetup.UpdateMaxValues;

  procedure DoSetMax(Ctl: TFloatSpinEdit; Value: double);
  begin
    // because of TCustomFloatSpinEdit.GetLimitedValue
    // we cannot set MinValue=MaxValue, all validation will break
    if Ctl.MinValue > Value-0.2 then
      Ctl.MinValue := Value-0.2;
    Ctl.MaxValue := Value;
  end;

const
  cMul = 0.45; // max margin is almost 1/2 of page size
begin
  DoSetMax(txtLeft, CurPageWidth * cMul);
  DoSetMax(txtRight, CurPageWidth * cMul);
  DoSetMax(txtTop, CurPageHeight * cMul);
  DoSetMax(txtBottom, CurPageHeight * cMul);
end;

procedure TframePageSetup.Initialize(AEnablePreview, AEnableMargins, AEnablePapers,
  AEnableOrientation: boolean);
begin
  EnablePreview:= AEnablePreview;
  EnableMargins:= AEnableMargins;
  EnablePapers:= AEnablePapers;
  EnableOrientation:= AEnableOrientation;

  cbPaper.Items.Clear;
  cbSource.Items.Clear;
  cbPaper.ItemIndex := -1;
  cbSource.ItemIndex := -1;

  SetupCupsCombo(cbSource, nil, 'InputSlot');
  SetupCupsCombo(cbPaper, nil, 'PageSize');
  if (cbPaper.Items.Count=0) then
  begin
    // no cups printer papers, use default ones
    cbPaper.Items := Printer.PaperSize.SupportedPapers;
    cbPaper.ItemIndex:= cbPaper.Items.IndexOf(Printer.PaperSize.PaperName);
  end;
  cbPaper.Enabled := EnablePapers;
  cbSource.Enabled := EnablePapers;

  //TODO: support reverse variants too?
  gpOrientation.Enabled := EnableOrientation;
  case Printer.Orientation of
    poPortrait,poReversePortrait:
      radPortrait.Checked := true;
    poLandscape,poReverseLandscape:
      radLandscape.Checked := true;
  end;

  gpMargins.Enabled := EnableMargins;
  panPreview.Visible:= EnablePreview;

  if EnablePreview then
    UpdatePageSize;
end;

procedure TframePageSetup.SetDefaultMinMargins;
begin
  with Printer.PaperSize.PaperRect do
  begin
    txtLeft.MinValue := (WorkRect.Left-PhysicalRect.Left)/Printer.XDPI/NToInches;
    txtTop.MinValue := (WorkRect.Top-PhysicalRect.Top)/Printer.YDPI/NToInches;
    txtRight.MinValue := (PhysicalRect.Right-WorkRect.Right)/Printer.XDPI/NToInches;
    txtBottom.MinValue := (PhysicalRect.Bottom-WorkRect.Bottom)/Printer.YDPI/NToInches;
  end;
end;

end.


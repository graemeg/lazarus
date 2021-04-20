unit ceFontFrame;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Graphics, Forms, Controls, StdCtrls, Dialogs, Spin,
  ExtCtrls;

type

  { TChartFontFrame }

  TChartFontFrame = class(TFrame)
    cbBold: TCheckBox;
    cbFontColor: TColorButton;
    cbItalic: TCheckBox;
    cbUnderline: TCheckBox;
    cmbFontName: TComboBox;
    cmbFontSize: TComboBox;
    lblOrientation: TLabel;
    Panel1: TPanel;
    Panel2: TPanel;
    seOrientation: TSpinEdit;
    procedure cbBoldChange(Sender: TObject);
    procedure cbFontColorColorChanged(Sender: TObject);
    procedure cbItalicChange(Sender: TObject);
    procedure cbUnderlineChange(Sender: TObject);
    procedure cmbFontNameChange(Sender: TObject);
    procedure cmbFontSizeChange(Sender: TObject);
    procedure seOrientationChange(Sender: TObject);
  private
    FFont: TFont;
    FOnChange: TNotifyEvent;
    procedure DoChanged;

  public
    constructor Create(AOwner: TComponent); override;
    procedure GetData(AFont: TFont);
    procedure Prepare(AFont: TFont; WithOrientation: boolean);
    property OnChange: TNotifyEvent read FOnChange write FOnChange;

  end;

implementation

{$R *.lfm}

uses
  ceUtils;

const
  FONT_SIZES: array[0..20] of String = (
    'default', '8', '9', '10', '12', '14', '16', '18', '20', '22', '24', '28',
    '32', '36', '40', '44', '48', '56', '64', '72', '80');

constructor TChartFontFrame.Create(AOwner: TComponent);
var
  i: Integer;
begin
  inherited;
  cmbFontName.Items.Assign(Screen.Fonts);
  cmbFontName.Items.Insert(0, 'default');
  for i:=0 to High(FONT_SIZES) do
    cmbFontSize.Items.Add(FONT_SIZES[i]);
  cbFontColor.Width := cbFontColor.Height;

  cmbFontName.DropdownCount := DEFAULT_DROPDOWN_COUNT;
  cmbFontSize.DropdownCount := DEFAULT_DROPDOWN_COUNT;
end;

procedure TChartFontFrame.cbBoldChange(Sender: TObject);
begin
  if cbBold.Checked then
    FFont.Style := FFont.Style + [fsBold]
  else
    FFont.Style := FFont.Style - [fsBold];
  DoChanged;
end;

procedure TChartFontFrame.cbFontColorColorChanged(Sender: TObject);
begin
  FFont.Color := cbFontColor.ButtonColor;
  DoChanged;
end;

procedure TChartFontFrame.cbItalicChange(Sender: TObject);
begin
  if cbItalic.Checked then
    FFont.Style := FFont.Style + [fsItalic]
  else
    FFont.Style := FFont.Style - [fsItalic];
  DoChanged;
end;

procedure TChartFontFrame.cbUnderlineChange(Sender: TObject);
begin
  if cbUnderline.Checked then
    FFont.Style := FFont.Style + [fsUnderline]
  else
    FFont.Style := FFont.Style - [fsUnderline];
  DoChanged;
end;

procedure TChartFontFrame.cmbFontNameChange(Sender: TObject);
begin
  if cmbFontName.ItemIndex < 1 then
    FFont.Name := 'default'
  else
    FFont.Name := cmbFontName.Items[cmbFontName.ItemIndex];
  DoChanged;
end;

procedure TChartFontFrame.cmbFontSizeChange(Sender: TObject);
begin
  if cmbFontSize.ItemIndex < 1 then
    FFont.Size := 0
  else
    FFont.Size := StrToInt(cmbFontSize.Items[cmbFontSize.ItemIndex]);
  DoChanged;
end;

procedure TChartFontFrame.seOrientationChange(Sender: TObject);
begin
  FFont.Orientation := seOrientation.Value * 10;
  DoChanged;
end;

procedure TChartFontFrame.DoChanged;
begin
  if Assigned(FOnChange) then FOnChange(Self);
end;

procedure TChartFontFrame.GetData(AFont: TFont);
begin
  if cmbFontSize.ItemIndex < 1 then
    AFont.Name := cmbFontName.Items[0]
  else
    AFont.Name := cmbFontName.Items[cmbFontName.ItemIndex];
  if cmbFontSize.ItemIndex < 1 then
    AFont.Size := 0
  else
    AFont.Size := StrToInt(cmbFontSize.Items[cmbFontSize.ItemIndex]);
  AFont.Orientation := seOrientation .Value * 10;
  AFont.Color := cbFontColor.ButtonColor;
  if cbBold.Checked then AFont.Style := AFont.Style + [fsBold] else AFont.Style := [];
  if cbItalic.Checked then AFont.Style := AFont.Style + [fsItalic] else AFont.Style := [];
  if cbUnderline.Checked then AFont.Style := AFont.Style + [fsUnderline] else AFont.Style := [];
end;

procedure TChartFontFrame.Prepare(AFont: TFont; WithOrientation: Boolean);
begin
  FFont := AFont;

  cmbFontName.ItemIndex := cmbFontName.Items.IndexOf(AFont.Name);
  if cmbFontName.ItemIndex = -1 then  cmbFontName.ItemIndex := 0;

  cmbFontSize.ItemIndex := cmbFontSize.Items.IndexOf(IntToStr(AFont.Size));
  if cmbFontSize.ItemIndex = -1 then cmbFontSize.ItemIndex := 0;

  seOrientation.Value := AFont.Orientation div 10;
  cbFontColor.ButtonColor := ColorToRGB(AFont.Color);
  seOrientation.Visible := WithOrientation;
  lblOrientation.Visible := WithOrientation;

  cbBold.Checked := fsBold in AFont.Style;
  cbItalic.Checked := fsItalic in AFont.Style;
  cbUnderline.Checked := fsUnderline in AFont.Style;
end;

end.


unit cePenFrame;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Graphics, Forms, Controls, StdCtrls, Dialogs, ExtCtrls,
  TAChartCombos;

type

  { TChartPenFrame }

  TChartPenFrame = class(TFrame)
    Bevel1: TBevel;
    cbPenStyle: TChartComboBox;
    cbPenWidth: TChartComboBox;
    cbPenColor: TColorButton;
    lblPenWidth: TLabel;
    lblPenStyle: TLabel;
    procedure cbPenColorColorChanged(Sender: TObject);
    procedure cbPenStyleChange(Sender: TObject);
    procedure cbPenWidthChange(Sender: TObject);
  private
    FPen: TPen;
    FOnChange: TNotifyEvent;
    procedure DoChanged;

  public
    constructor Create(AOwner: TComponent); override;
    procedure Prepare(APen: TPen);
    property OnChange: TNotifyEvent read FOnChange write FOnChange;

  end;

implementation

{$R *.lfm}

{ TChartPenFrame }

constructor TChartPenFrame.Create(AOwner: TComponent);
begin
  inherited;
  cbPenStyle.DropdownCount := DEFAULT_DROPDOWN_COUNT;
  cbPenWidth.DropdownCount := DEFAULT_DROPDOWN_COUNT;
  cbPenColor.Width := cbPenColor.Height;
end;

procedure TChartPenFrame.cbPenColorColorChanged(Sender: TObject);
begin
  FPen.Color := cbPenColor.ButtonColor;
  DoChanged;
end;

procedure TChartPenFrame.cbPenStyleChange(Sender: TObject);
begin
  FPen.Style := cbPenStyle.PenStyle;
  DoChanged;
end;

procedure TChartPenFrame.cbPenWidthChange(Sender: TObject);
begin
  FPen.Width := cbPenWidth.PenWidth;
  DoChanged;
end;

procedure TChartPenFrame.DoChanged;
begin
  if Assigned(FOnChange) then FOnChange(FPen);
end;

procedure TChartPenFrame.Prepare(APen: TPen);
begin
  FPen := APen;
  cbPenStyle.PenStyle := FPen.Style;
  cbPenWidth.PenWidth := FPen.Width;
  cbPenColor.ButtonColor := ColorToRGB(FPen.Color);
end;

end.


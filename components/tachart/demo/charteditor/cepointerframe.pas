unit cePointerFrame;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, StdCtrls, ExtCtrls, Spin,
  TATypes, TAChartCombos, TAGraph,
  ceBrushFrame, cePenFrame;

type

  { TPointerFrame }

  TPointerFrame = class(TFrame)
    cbPointerStyle: TChartComboBox;
    GroupBox1: TGroupBox;
    gbPointerBrush: TGroupBox;
    gbPointerPen: TGroupBox;
    Label1: TLabel;
    lblPointerSize: TLabel;
    sePointerSize: TSpinEdit;
    procedure cbPointerStyleChange(Sender: TObject);
    procedure sePointerSizeChange(Sender: TObject);
  private
    FPointer: TSeriesPointer;
    FPointerBrushFrame: TBrushFrame;
    FPointerPenFrame: TPenFrame;
    FOnChange: TNotifyEvent;
    procedure ChangedHandler(Sender: TObject);
    procedure DoChange;
  protected
    function GetChart: TChart;

  public
    constructor Create(AOwner: TComponent); override;
    procedure Prepare(APointer: TSeriesPointer);
    property OnChange: TNotifyEvent read FOnChange write FOnChange;
  end;

implementation

{$R *.lfm}

type
  TSeriesPointerAccess = class(TSeriesPointer);

constructor TPointerFrame.Create(AOwner: TComponent);
begin
  inherited;
  cbPointerStyle.DropdownCount := DEFAULT_DROPDOWN_COUNT;

  FPointerBrushFrame := TBrushFrame.Create(Self);
  FPointerBrushFrame.Parent := gbPointerBrush;
  FPointerBrushFrame.Name := '';
  FPointerBrushFrame.Align := alClient;
  FPointerBrushFrame.BorderSpacing.Left := 8;
  FPointerBrushFrame.BorderSpacing.Right := 8;
  FPointerBrushFrame.BorderSpacing.Bottom := 8;
  FPointerBrushFrame.OnChange := @ChangedHandler;
  gbPointerBrush.Caption := 'Fill';
  gbPointerBrush.AutoSize := true;

  FPointerPenFrame := TPenFrame.Create(self);
  FPointerPenFrame.Parent := gbPointerPen;
  FPointerPenFrame.Name := '';
  FPointerPenFrame.Align := alClient;
  FPointerPenFrame.borderspacing.Left := 8;
  FPointerPenFrame.BorderSpacing.Right := 8;
  FPointerPenFrame.BorderSpacing.Bottom := 8;
  FPointerPenFrame.OnChange := @ChangedHandler;
  gbPointerPen.caption := 'Border';
  gbPointerPen.AutoSize := true;

  AutoSize := true;
end;

procedure TPointerFrame.cbPointerStyleChange(Sender: TObject);
begin
  FPointer.Style := cbPointerStyle.PointerStyle;
  DoChange;
end;

procedure TPointerFrame.ChangedHandler(Sender: TObject);
begin
  DoChange;
end;

procedure TPointerFrame.sePointerSizeChange(Sender: TObject);
begin
  FPointer.HorizSize := sePointerSize.Value;
  FPointer.VertSize := sePointerSize.Value;
  DoChange;
end;

procedure TPointerFrame.DoChange;
begin
  if Assigned(FOnChange) then FOnChange(FPointer);
end;

function TPointerFrame.GetChart: TChart;
begin
  Result := TSeriesPointerAccess(FPointer).GetOwner as TChart;
end;

procedure TPointerFrame.Prepare(APointer: TSeriesPointer);
begin
  FPointer := APointer;
  cbPointerStyle.PointerStyle := APointer.Style;
  sePointerSize.Value := APointer.HorizSize;
  FPointerBrushFrame.Prepare(APointer.Brush);
  FPointerPenFrame.Prepare(APointer.Pen);
end;

end.


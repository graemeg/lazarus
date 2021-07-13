unit TAChartLiveView;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, TAGraph, TAChartUtils;

type
  TChartLiveViewExtentY = (lveAuto, lveFull, lveLogical, lveMultiAxisRange);

  { TChartLiveView }

  TChartLiveView = class(TComponent)
  private
    type
      TLVAxisRange = record
        Min, Max: double;
        UseMin, UseMax: Boolean;
      end;
  private
    FActive: Boolean;
    FChart: TChart;
    FExtentY: TChartLiveViewExtentY;
    FListener: TListener;
    FViewportSize: Double;
    FAxisRanges: Array of TLVAxisRange;
    procedure FullExtentChanged(Sender: TObject);
    procedure SetActive(const AValue: Boolean);
    procedure SetChart(const AValue: TChart);
    procedure SetExtentY(const AValue: TChartLiveViewExtentY);
    procedure SetViewportSize(const AValue: Double);
    procedure UpdateViewport;
  protected
    procedure RestoreAxisRanges;
    procedure StoreAxisRanges;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  published
    property Active: Boolean read FActive write SetActive default false;
    property Chart: TChart read FChart write SetChart default nil;
    property ExtentY: TChartLiveViewExtentY read FExtentY write SetExtentY default lveAuto;
    property ViewportSize: double read FViewportSize write SetViewportSize;
  end;

procedure Register;


implementation

uses
  Math, TAChartAxis, TAChartAxisUtils, TACustomSeries;

constructor TChartLiveView.Create(AOwner: TComponent);
begin
  inherited;
  FListener := TListener.Create(@FChart, @FullExtentChanged);
end;

destructor TChartLiveView.Destroy;
begin
  FreeAndNil(FListener);
  inherited;
end;

procedure TChartLiveView.FullExtentChanged(Sender: TObject);
begin
  if (not FActive) or (FChart = nil) then
    exit;
  UpdateViewport;
end;

procedure TChartLiveView.RestoreAxisRanges;
var
  i: Integer;
  ax: TChartAxis;
begin
  if FChart = nil then
    exit;

  for i := 0 to FChart.AxisList.Count-1 do
  begin
    ax := FChart.AxisList[i];
    ax.Range.Max := FAxisRanges[i].Max;
    ax.Range.Min := FAxisRanges[i].Min;
    ax.Range.UseMax := FAxisRanges[i].UseMax;
    ax.Range.UseMin := FAxisRanges[i].UseMin;
  end;
end;

procedure TChartLiveView.SetActive(const AValue: Boolean);
begin
  if FActive = AValue then exit;

  FActive := AValue;
  if FChart <> nil then
  begin
    if FActive then
      StoreAxisRanges
    else
      RestoreAxisRanges;
  end;

  FullExtentChanged(nil);
end;

procedure TChartLiveView.SetChart(const AValue: TChart);
begin
  if FChart = AValue then exit;

  if FListener.IsListening then
    FChart.FullExtentBroadcaster.Unsubscribe(FListener);
  FChart := AValue;
  if FChart <> nil then
    FChart.FullExtentBroadcaster.Subscribe(FListener);
  StoreAxisRanges;
  FullExtentChanged(Self);
end;

procedure TChartLiveview.SetExtentY(const AValue: TChartLiveViewExtentY);
begin
  if FExtentY = AValue then exit;
  FExtentY := AValue;
  RestoreAxisRanges;
  FullExtentChanged(nil);
end;

procedure TChartLiveView.SetViewportSize(const AValue: Double);
begin
  if FViewportSize = AValue then exit;

  FViewportSize := AValue;
  FullExtentChanged(nil);
end;

procedure TChartLiveView.StoreAxisRanges;
var
  i: Integer;
  ax: TChartAxis;
begin
  SetLength(FAxisRanges, FChart.AxisList.Count);
  for i := 0 to FChart.AxisList.Count-1 do
  begin
    ax := FChart.AxisList[i];
    FAxisRanges[i].Max := ax.Range.Max;
    FAxisRanges[i].Min := ax.Range.Min;
    FAxisRanges[i].UseMax := ax.Range.UseMax;
    FAxisRanges[i].UseMin := ax.Range.UseMin;
  end;
end;

procedure TChartLiveView.UpdateViewport;
var
  fext, lext: TDoubleRect;
  w: double;
  i, j: Integer;
  ymin, ymax: Double;
  ygmin, ygmax: Double;
  ser: TChartSeries;
  ax: TChartAxis;
begin
  if not FChart.ScalingValid then
    exit;

  if Length(FAxisRanges) = 0 then
    StoreAxisRanges;

  fext := FChart.GetFullExtent();
  lext := FChart.LogicalExtent;
  if FViewportSize = 0 then
    w := lext.b.x - lext.a.x
  else
    w := FViewportSize;
  lext.b.x := fext.b.x;
  lext.a.x := lext.b.X - w;
  if lext.a.x < fext.a.x then begin
    lext.a.x := fext.a.x;
    lext.b.x := lext.a.x + w;
  end;
  case FExtentY of
    lveFull:
      begin
        lext.a.y := fext.a.y;
        lext.b.y := fext.b.y;
      end;
    lveLogical:
      ;
    lveAuto,
    lveMultiAxisRange:
      begin
        lext.a.y := Infinity;
        lext.b.y := -Infinity;
        for i := 0 to FChart.AxisList.Count-1 do
        begin
          ax := FChart.AxisList[i];
          if not (ax.Alignment in [calLeft, calRight]) then
            Continue;
          ymin := Infinity;
          ymax := -Infinity;
          for j := 0 to FChart.SeriesCount-1 do
            if FChart.Series[j] is TChartSeries then
            begin
              ser := TChartSeries(FChart.Series[j]);
              if (not ser.Active) or (ser.GetAxisY <> ax) then
                continue;
              ser.FindYRange(lext.a.x, lext.b.x, ymin, ymax);
            end;
          if (ymin = Infinity) then
          begin
            ymin := -1;
            ymax := +1;
          end else
          if (ymin = ymax) then
          begin
            if ymin = 0 then
            begin
              ymin := -1;
              ymax := +1;
            end else
            begin
              ymin := abs(ymin) * 0.9;
              ymax := abs(ymax) * 1.1;
            end;
          end;
          ax.Range.Min := ymin;
          ax.Range.Max := ymax;
          if (FExtentY = lveMultiAxisRange) then
          begin
            if FAxisRanges[i].UseMin then ax.Range.Min := FAxisRanges[i].Min;
            if FAxisRanges[i].UseMax then ax.Range.Max := FAxisRanges[i].Max;
          end;
          ax.Range.UseMin := true;
          ax.Range.UseMax := true;
          lext.a.y := Min(lext.a.y, ax.GetTransform.AxisToGraph(ymin));
          lext.b.y := Max(lext.b.y, ax.GetTransform.AxisToGraph(ymax));
        end;  // for i
      end;

  end;
  FChart.LogicalExtent := lext;
end;

procedure Register;
begin
  RegisterComponents(CHART_COMPONENT_IDE_PAGE, [TChartLiveView]);
end;

end.


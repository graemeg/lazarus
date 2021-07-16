{
 /***************************************************************************
                              TAChartLiveView.pas
                              -------------------

 TChartLiveView is a component optimized for displaying a long array of incoming
 data in a viewport showing only the most recent data while older data are
 flowing out of the viewport to the left.

 It was created on the basis of the following forum discussions:
 - https://forum.lazarus.freepascal.org/index.php/topic,15037.html
 - https://forum.lazarus.freepascal.org/index.php/topic,50759.0.html
 - https://forum.lazarus.freepascal.org/index.php/topic,55266.html

 See the file COPYING.modifiedLGPL.txt, included in this distribution,
 for details about the license.
 *****************************************************************************

  Author: Werner Pamler
}

unit TAChartLiveView;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, TAGraph, TAChartUtils;

type
  TChartLiveViewExtentY = (lveAuto, lveFull, lveLogical);

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
  protected
    procedure UpdateViewport; virtual;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure RestoreAxisRanges;
    procedure StoreAxisRanges;
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
  RestoreAxisRanges;
  FreeAndNil(FListener);
  inherited;
end;

{ A new data point has been added to the chart so that the full extent changes.
  As a consequence the viewport of the live view must be updated. }
procedure TChartLiveView.FullExtentChanged(Sender: TObject);
begin
  if (not FActive) or (FChart = nil) then
    exit;
  UpdateViewport;
end;

{ The ChartLiveView may change the Range properties of an axis. The original
  values, before applying the live view, are restored here from internal
  variables.
  Be careful when calling this procedure in user code, it may disrupt the
  operation of the live view. }
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

{ Activates the live view mode. Because the Range of the y axes can be changed
  their current Range is stored before activating, and restored after
  deactivating the mode. }
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

{ Attaches the chart on which the liveview operates. Installs a "listener"
  object so that the liveview can be notified of a change in the chart's full
  extent when a new data point has been added (method FullExtentChanged). }
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
  if FExtentY = lveAuto then
    RestoreAxisRanges;
  FExtentY := AValue;
  FullExtentChanged(nil);
end;

procedure TChartLiveView.SetViewportSize(const AValue: Double);
begin
  if FViewportSize = AValue then exit;
  FViewportSize := AValue;
  FullExtentChanged(nil);
end;

{ The ChartLiveView may change the Range properties of an axis. The original
  values, before applying the live view, are stored here in internal variables.
  Be careful when calling this procedure in user code, it may disrupt the
  operation of the live view. }
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

{ "Workhorse" method of the component. It calculates the logical extent and
  the axis ranges needed to display only the recent data values in the
  given viewport. }
procedure TChartLiveView.UpdateViewport;
var
  fext, lext: TDoubleRect;    // "full extent", "logical extent" variables
  w: double;
  i, j: Integer;
  yminAx, ymaxAx, yminSer, ymaxSer: Double;
  dy: Double;
  ser: TChartSeries;
  axis: TChartAxis;
begin
  if csDesigning in ComponentState then
    exit;

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
  // Move the extent to the right
  lext.b.x := fext.b.x;
  lext.a.x := lext.b.x - w;
  if lext.a.x < fext.a.x then begin
    lext.a.x := fext.a.x;
    lext.b.x := lext.a.x + w;
  end;
  case FExtentY of
    lveAuto:
      // The aim of lveAuto is to determine the y-axis range according to
      // the ymin/ymax of the series connected to the axis
      begin
        lext.a.y := fext.a.y;
        lext.b.y := fext.b.y;
        for i := 0 to FChart.AxisList.Count-1 do
        begin
          axis := FChart.AxisList[i];
          // Ignore x-axes
          if (axis.Alignment in [calTop, calBottom]) then
            Continue;
          ymaxAx := -Infinity;
          yminAx := Infinity;
          // Step through all active non-rotated series attached to this axis
          for j := 0 to FChart.SeriesCount-1 do
          begin
            if FChart.Series[j] is TChartSeries then
            begin
              ser := TChartSeries(FChart.Series[j]);
              if (not ser.Active) or (ser.GetAxisY <> axis) or ser.IsRotated then
                continue;
              yminSer := Infinity;
              ymaxSer := -Infinity;
              ser.FindYRange(lext.a.x, lext.b.x, yminSer, ymaxSer);
              yminAx := Min(yminAx, yminSer);
              ymaxAx := Max(ymaxAx, ymaxSer);
            end;
          end;
          // Only if an axis has no active non-rotated series, we have -infinity
          if ymaxAx > -Infinity then
          begin
            if ymaxAx = yminAx then
            begin
              if yminAx = 0 then
              begin
                yminAx := -1;
                ymaxAx := +1;
              end
              else
              // Set the range to 10% around the value, take care of the sign!
              begin
                dy := abs(yminAx) * 0.1;
                yminAx := yminAx - dy;
                ymaxAx := ymaxAx + dy;
              end;
            end;
          end
          else
          begin
            yminAx := -1;
            ymaxAx := +1;
          end;
          // Only if the user did not set its own range we set the axis range
          // determined above.
          if (not FAxisRanges[i].UseMin) then
          begin
            axis.Range.Min := yminAx;
            axis.Range.UseMin := true;  // we had stored the original UseMin in FAxisRanges
            lext.a.y := axis.GetTransform.AxisToGraph(yminAx);
          end;
          if (not FAxisRanges[i].UseMax) then
          begin
            axis.Range.Max := ymaxAx;
            axis.Range.UseMax := true;  // we had stored the original UseMax in FAxisRanges
            lext.b.y := axis.GetTransform.AxisToGraph(ymaxAx);
          end;
        end;  // series loop
      end;  // axes loop

    lveFull:
      begin
        lext.a.y := fext.a.y;
        lext.b.y := fext.b.y;
      end;

    lveLogical:
      ;
  end;

  FChart.LogicalExtent := lext;
end;

procedure Register;
begin
  RegisterComponents(CHART_COMPONENT_IDE_PAGE, [TChartLiveView]);
end;

end.


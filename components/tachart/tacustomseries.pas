{
 *****************************************************************************
  See the file COPYING.modifiedLGPL.txt, included in this distribution,
  for details about the license.
 *****************************************************************************

  Basic types for TAChart series.

  Authors: Alexander Klenin

}
unit TACustomSeries;

{$H+}

interface

uses
  Classes, GraphType, Graphics, IntfGraphics, SysUtils,
  TAChartAxis, TAChartUtils, TACustomSource, TADrawUtils, TAGraph, TALegend,
  TASources, TAStyles, TATextElements, TATypes;

const
  DEF_AXIS_INDEX = -1;
  DEF_ERR_ENDLENGTH = 5;

type
  TNearestPointParams = record
    FDistFunc: TPointDistFunc;
    FOptimizeX: Boolean;
    FPoint: TPoint;
    FRadius: Integer;
    FTargets: TNearestPointTargets;
  end;

  TNearestPointResults = record
    FDist: Integer;
    FImg: TPoint;
    FIndex: Integer;        // Point index
    FXIndex: Integer;       // Index to be used in Source.GetX()
    FYIndex: Integer;       // Index to be used in Source.GetY()
    FValue: TDoublePoint;
  end;

  TChartAxisIndex = -1..MaxInt;

  { TCustomChartSeries }

  TCustomChartSeries = class(TBasicChartSeries)
  strict private
    FAxisIndexX: TChartAxisIndex;
    FAxisIndexY: TChartAxisIndex;
    FDepthBrightnessDelta: Integer;
    FLegend: TChartSeriesLegend;
    FToolTargets: TNearestPointTargets;
    FTitle: String;
    procedure SetAxisIndexX(AValue: TChartAxisIndex);
    procedure SetAxisIndexY(AValue: TChartAxisIndex);
    procedure SetDepthBrightnessDelta(AValue: Integer);
    procedure SetLegend(AValue: TChartSeriesLegend);

  protected
    procedure AfterAdd; override;
    procedure GetLegendItems(AItems: TChartLegendItems); virtual; abstract;
    procedure GetLegendItemsBasic(AItems: TChartLegendItems); override;
    function GetShowInLegend: Boolean; override;
    procedure SetActive(AValue: Boolean); override;
    procedure SetDepth(AValue: TChartDistance); override;
    procedure SetShadow(AValue: TChartShadow); override;
    procedure SetShowInLegend(AValue: Boolean); override;
    procedure SetTitle(AValue: String); virtual;
    procedure SetTransparency(AValue: TChartTransparency); override;
    procedure SetZPosition(AValue: TChartDistance); override;
    procedure StyleChanged(Sender: TObject);
    procedure UpdateParentChart;

  protected
    procedure ReadState(Reader: TReader); override;
    procedure SetParentComponent(AParent: TComponent); override;

  strict protected
    // Set series bounds in axis coordinates.
    // Some or all bounds may be left unset, in which case they will be ignored.
    procedure GetBounds(var ABounds: TDoubleRect); virtual; abstract;
    function GetIndex: Integer; override;
    function LegendTextSingle: String;
    function LegendTextStyle(AStyle: TChartStyle): String;
    procedure SetIndex(AValue: Integer); override;
    function TitleIsStored: Boolean; virtual;
    property DepthBrightnessDelta: Integer
      read FDepthBrightnessDelta write SetDepthBrightnessDelta default 0;
    property ToolTargets: TNearestPointTargets
      read FToolTargets write FToolTargets default [nptPoint];

  public
    function AxisToGraph(const APoint: TDoublePoint): TDoublePoint; inline;
    function AxisToGraphX(AX: Double): Double; override;
    function AxisToGraphY(AY: Double): Double; override;
    function GetAxisX: TChartAxis;
    function GetAxisY: TChartAxis;
    function GetAxisBounds(AAxis: TChartAxis; out AMin, AMax: Double): Boolean; override;
    function GetDepthColor(AColor: Integer; Opposite: boolean = false): Integer; virtual;
    function GetGraphBounds: TDoubleRect; override;
    function GraphToAxis(APoint: TDoublePoint): TDoublePoint;
    function GraphToAxisX(AX: Double): Double; override;
    function GraphToAxisY(AY: Double): Double; override;
    function IsRotated: Boolean;

  public
    procedure Assign(ASource: TPersistent); override;
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    function GetNearestPoint(
      const AParams: TNearestPointParams;
      out AResults: TNearestPointResults): Boolean; virtual;
    function GetParentComponent: TComponent; override;
    procedure GetSingleLegendItem(AItems: TChartLegendItems);
    function HasParent: Boolean; override;

    property AxisIndexX: TChartAxisIndex
      read FAxisIndexX write SetAxisIndexX default DEF_AXIS_INDEX;
    property AxisIndexY: TChartAxisIndex
      read FAxisIndexY write SetAxisIndexY default DEF_AXIS_INDEX;
    property Title: String read FTitle write SetTitle stored TitleIsStored;

  published
    property Legend: TChartSeriesLegend read FLegend write SetLegend;
    property Shadow;
    property ShowInLegend: Boolean
      read GetShowInLegend write SetShowInLegend stored false default true;
      deprecated;
    property Transparency;
  end;

  TChartGetMarkEvent = procedure (
    out AFormattedMark: String; AIndex: Integer) of object;

  { TChartSeries }

  TChartSeries = class(TCustomChartSeries)
  strict private
    FBuiltinSource: TCustomChartSource;
    FListener: TListener;
    FMarks: TChartMarks;
    FOnGetMark: TChartGetMarkEvent;
    FSource: TCustomChartSource;
    FStyles: TChartStyles;
    FStylesListener: TListener;

    function GetSource: TCustomChartSource;
    function IsSourceStored: boolean;
    procedure SetMarks(AValue: TChartMarks);
    procedure SetOnGetMark(AValue: TChartGetMarkEvent);
    procedure SetSource(AValue: TCustomChartSource);
    procedure SetStyles(AValue: TChartStyles);
  protected
    procedure AfterAdd; override;
    procedure AfterDraw; override;
    procedure BeforeDraw; override;
    procedure CheckSource(ASource: TCustomChartSource);
    procedure GetBounds(var ABounds: TDoubleRect); override;
    function GetGraphPoint(AIndex: Integer): TDoublePoint; overload;
    function GetGraphPoint(AIndex, AXIndex, AYIndex: Integer): TDoublePoint; overload;
    function GetGraphPointX(AIndex: Integer): Double; overload; inline;
    function GetGraphPointX(AIndex, AXIndex: Integer): Double; overload; inline;
    function GetGraphPointY(AIndex: Integer): Double; overload; inline;
    function GetGraphPointY(AIndex, AYIndex: Integer): Double; overload; inline;
    function GetSeriesColor: TColor; virtual;
    function GetXMaxVal: Double;
    procedure SourceChanged(ASender: TObject); virtual;
    procedure VisitSources(
      AVisitor: TChartOnSourceVisitor; AAxis: TChartAxis; var AData); override;
    class procedure GetXYCountNeeded(out AXCount, AYCount: Cardinal); virtual;
  strict protected
    function LegendTextPoint(AIndex: Integer): String; inline;
  protected
    property Styles: TChartStyles read FStyles write SetStyles;
  public
    procedure Assign(ASource: TPersistent); override;
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

  public
    function  GetColor(AIndex: Integer): TColor;
    procedure GetMax(out X, Y: Double);
    procedure GetMin(out X, Y: Double);
    function  GetXImgValue(AIndex: Integer): Integer;
    function  GetXMax: Double;
    function  GetXMin: Double;
    function  GetXValue(AIndex: Integer): Double;
    function  GetXValues(AIndex, AXIndex: Integer): Double;
    function  GetYImgValue(AIndex: Integer): Integer;
    function  GetYMax: Double;
    function  GetYMin: Double;
    function  GetYValue(AIndex: Integer): Double;
    function  GetYValues(AIndex, AYIndex: Integer): Double;
    procedure SetColor(AIndex: Integer; AColor: TColor); inline;
    procedure SetText(AIndex: Integer; AValue: String); inline;
    procedure SetXValue(AIndex: Integer; AValue: Double); inline;
    procedure SetXValues(AIndex, AXIndex: Integer; AValue: Double);
    procedure SetYValue(AIndex: Integer; AValue: Double); inline;
    procedure SetYValues(AIndex, AYIndex: Integer; AValue: Double);
  public
    function Add(
      AValue: Double;
      AXLabel: String = ''; AColor: TColor = clTAColor): Integer; inline;
    function AddArray(const AValues: array of Double): Integer;
    function AddNull(ALabel: String = ''; AColor: TColor = clTAColor): Integer; inline;
    function AddX(
      AX: Double; ALabel: String = ''; AColor: TColor = clTAColor): Integer; inline;
    function AddXY(
      AX, AY: Double;
      AXLabel: String = ''; AColor: TColor = clTAColor): Integer; overload; inline;
    function AddXY(
      AX, AY: Double; const AYList: array of Double;
      AXLabel: String = ''; AColor: TColor = clTAColor): Integer; overload;
    function AddY(
      AY: Double; ALabel: String = ''; AColor: TColor = clTAColor): Integer; inline;
    procedure BeginUpdate;
    procedure Clear; virtual;
    function Count: Integer; inline;
    procedure Delete(AIndex: Integer); virtual;
    procedure EndUpdate;
    function Extent: TDoubleRect; virtual;
    procedure FindYRange(AXMin, AXMax: Double; var AYMin, AYMax: Double); virtual;
    function FormattedMark(
      AIndex: Integer; AFormat: String = ''; AYIndex: Integer = 0): String;
    function IsEmpty: Boolean; override;
    function ListSource: TListChartSource;
    property Marks: TChartMarks
      read FMarks write SetMarks;
    property Source: TCustomChartSource
      read GetSource write SetSource stored IsSourceStored;
  public
    // for Delphi compatibility
    function LastValueIndex: Integer; inline;
    function MaxXValue: Double;
    function MinXValue: Double;
    function MaxYValue: Double;
    function MinYValue: Double;
    property XValue[AIndex: Integer]: Double read GetXValue write SetXValue;
    property XValues[AIndex, AXIndex: Integer]: Double read GetXValues write SetXValues;
    property YValue[AIndex: Integer]: Double read GetYValue write SetYValue;
    property YValues[AIndex, AYIndex: Integer]: Double read GetYValues write SetYValues;
  published
    property Active default true;
    property ShowInLegend;
    property Title;
    property ZPosition;
  published
    property OnGetMark: TChartGetMarkEvent read FOnGetMark write SetOnGetMark;
  end;

  TLabelDirection = (ldLeft, ldTop, ldRight, ldBottom);

  TLinearMarkPositions = (lmpOutside, lmpPositive, lmpNegative, lmpInside);

  TSeriesPointerCustomDrawEvent = procedure (
    ASender: TChartSeries; ADrawer: IChartDrawer; AIndex: Integer;
    ACenter: TPoint) of object;

  TSeriesPointerStyleEvent = procedure (ASender: TChartSeries;
    AValueIndex: Integer; var AStyle: TSeriesPointerStyle) of object;

  TStackedNaN = (snReplaceByZero, snDoNotDraw);

  { TBasicPointSeries }

  TBasicPointSeries = class(TChartSeries)
  strict private
    FMarkPositions: TLinearMarkPositions;
    FErrorBars: array[0..1] of TChartErrorBar;
    FOnCustomDrawPointer: TSeriesPointerCustomDrawEvent;
    FOnGetPointerStyle: TSeriesPointerStyleEvent;
    function GetErrorBars(AIndex: Integer): TChartErrorBar;
    function IsErrorBarsStored(AIndex: Integer): Boolean;
    procedure SetErrorBars(AIndex: Integer; AValue: TChartErrorBar);
    procedure SetMarkPositionCentered(AValue: Boolean);
    procedure SetMarkPositions(AValue: TLinearMarkPositions);
    procedure SetPointer(AValue: TSeriesPointer);
    procedure SetStacked(AValue: Boolean);
    procedure SetStackedNaN(AValue: TStackedNaN);
  //strict
  protected
    FGraphPoints: array of TDoublePoint;
    FLoBound: Integer;
    FMinXRange: Double;
    FPointer: TSeriesPointer;
    FStacked: Boolean;
    FStackedNaN: TStackedNaN;
    FUpBound: Integer;
    FOptimizeX: Boolean;
    FSupportsZeroLevel: Boolean;
    FMarkPositionCentered: Boolean;

    procedure AfterDrawPointer(
      ADrawer: IChartDrawer; AIndex: Integer; const APos: TPoint); virtual;
    procedure DrawErrorBars(ADrawer: IChartDrawer);
    procedure DrawLabels(ADrawer: IChartDrawer; AYIndex: Integer = -1);
    procedure DrawPointers(ADrawer: IChartDrawer; AStyleIndex: Integer = 0;
      UseDataColors: Boolean = false);
    procedure FindExtentInterval(
      const AExtent: TDoubleRect; AFilterByExtent: Boolean);
    function GetLabelDataPoint(AIndex, AYIndex: Integer): TDoublePoint; virtual;
    function GetLabelDirection(AValue: Double;
      const ACenterLevel: Double): TLabelDirection;
    procedure GetLegendItemsRect(AItems: TChartLegendItems; ABrush: TBrush; APen: TPen);
    function GetXRange(AX: Double; AIndex: Integer): Double;
    function GetZeroLevel: Double; virtual;
    function HasMissingYValue(AIndex: Integer; AMaxYIndex: Integer = MaxInt): Boolean;
    function NearestXNumber(var AIndex: Integer; ADir: Integer): Double;
    procedure PrepareGraphPoints(
      const AExtent: TDoubleRect; AFilterByExtent: Boolean);
    function SkipMissingValues(AIndex: Integer): Boolean; virtual;
    function ToolTargetDistance(const AParams: TNearestPointParams;
      AGraphPt: TDoublePoint; APointIdx, AXIdx, AYIdx: Integer): Integer; virtual;
    procedure UpdateGraphPoints(AIndex: Integer; ACumulative: Boolean); overload; inline;
    procedure UpdateGraphPoints(AIndex, ALo, AUp: Integer; ACumulative: Boolean); overload;
    procedure UpdateLabelDirectionReferenceLevel(AIndex, AYIndex: Integer;
      var ALevel: Double); virtual;
    procedure UpdateMinXRange;

    property Pointer: TSeriesPointer read FPointer write SetPointer;
    property Stacked: Boolean read FStacked write SetStacked;
    property StackedNaN: TStackedNaN read FStackedNaN write SetStackedNaN default snReplaceByZero;

  protected
    procedure AfterAdd; override;
    procedure SourceChanged(ASender: TObject); override;
    procedure UpdateMargins(ADrawer: IChartDrawer; var AMargins: TRect); override;

    property MarkPositionCentered: Boolean
      read FMarkPositionCentered write SetMarkPositionCentered default false;
    property MarkPositions: TLinearMarkPositions
      read FMarkPositions write SetMarkPositions default lmpOutside;
    property XErrorBars: TChartErrorBar index 0 read GetErrorBars
      write SetErrorBars stored IsErrorBarsStored;
    property YErrorBars: TChartErrorBar index 1 read GetErrorBars
      write SetErrorBars stored IsErrorBarsStored;
    property OnCustomDrawPointer: TSeriesPointerCustomDrawEvent
      read FOnCustomDrawPointer write FOnCustomDrawPointer;
    property OnGetPointerStyle: TSeriesPointerStyleEvent
      read FOnGetPointerStyle write FOnGetPointerStyle;

  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  public
    procedure Assign(ASource: TPersistent); override;
    function Extent: TDoubleRect; override;
    procedure FindYRange(AXMin, AXMax: Double; var AYMin, AYMax: Double); override;
    function GetNearestPoint(
      const AParams: TNearestPointParams;
      out AResults: TNearestPointResults): Boolean; override;
    procedure MovePoint(var AIndex: Integer; const ANewPos: TDoublePoint); override;
    procedure MovePointEx(var AIndex: Integer; AXIndex, AYIndex: Integer;
      const ANewPos: TDoublePoint); override;
    property ToolTargets default [nptPoint, nptYList];
    property ExtentPointIndexFirst: Integer read FLoBound;
    property ExtentPointIndexLast: Integer read FUpBound;
  end;

  function CreateLazIntfImage(
    out ARawImage: TRawImage; const ASize: TPoint): TLazIntfImage;

implementation

uses
  Math, PropEdits, StrUtils, LResources, Types, GraphUtil,
  TAChartStrConsts, TAGeometry, TAMath;

function CreateLazIntfImage(
  out ARawImage: TRawImage; const ASize: TPoint): TLazIntfImage;
begin
  ARawImage.Init;
  ARawImage.Description.Init_BPP32_B8G8R8A8_BIO_TTB(ASize.X, ASize.Y);
  ARawImage.CreateData(true);
  Result := TLazIntfImage.Create(0, 0);
  Result.SetRawImage(ARawImage);
end;

{ TCustomChartSeries }

procedure TCustomChartSeries.AfterAdd;
begin
  Legend.SetOwner(FChart);
  Shadow.SetOwner(FChart);
end;

procedure TCustomChartSeries.Assign(ASource: TPersistent);
begin
  if ASource is TCustomChartSeries then
    with TCustomChartSeries(ASource) do begin
      Self.FAxisIndexX := FAxisIndexX;
      Self.FAxisIndexY := FAxisIndexY;
      Self.FDepthBrightnessDelta := FDepthBrightnessDelta;
      Self.Legend := FLegend;
      Self.FTitle := FTitle;
      Self.FToolTargets := FToolTargets;
    end;
  inherited Assign(ASource);
end;

function TCustomChartSeries.AxisToGraph(
  const APoint: TDoublePoint): TDoublePoint;
begin
  Result := DoublePoint(AxisToGraphX(APoint.X), AxisToGraphY(APoint.Y));
  if IsRotated then
    Exchange(Result.X, Result.Y);
end;

function TCustomChartSeries.AxisToGraphX(AX: Double): Double;
begin
  Result := TransformByAxis(FChart.AxisList, AxisIndexX).AxisToGraph(AX)
end;

function TCustomChartSeries.AxisToGraphY(AY: Double): Double;
begin
  Result := TransformByAxis(FChart.AxisList, AxisIndexY).AxisToGraph(AY)
end;

constructor TCustomChartSeries.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FActive := true;
  FAxisIndexX := DEF_AXIS_INDEX;
  FAxisIndexY := DEF_AXIS_INDEX;
  FLegend := TChartSeriesLegend.Create(FChart);
  FToolTargets := [nptPoint];
  FShadow := TChartShadow.Create(FChart);
end;

destructor TCustomChartSeries.Destroy;
begin
  FreeAndNil(FLegend);
  FreeAndNil(FShadow);
  inherited;
end;

function TCustomChartSeries.GetAxisBounds(AAxis: TChartAxis;
  out AMin, AMax: Double): Boolean;
var
  ex: TDoubleRect;
  axIndexX, axIndexY: Integer;
begin
  axIndexX := GetAxisX.Index;
  axIndexY := GetAxisY.Index;

  if (AAxis.Index = axIndexX) or (AAxis.Index = axIndexY) then begin
    ex := EmptyExtent;
    GetBounds(ex);
    with ex do begin
      UpdateBoundsByAxisRange(FChart.AxisList, axIndexX, a.X, b.X);
      UpdateBoundsByAxisRange(FChart.AxisList, axIndexY, a.Y, b.Y);
      if IsRotated then begin
        Exchange(a.X, a.Y);
        Exchange(b.X, b.Y);
      end;
    end;
    AMin := TDoublePointBoolArr(ex.a)[AAxis.IsVertical];
    AMax := TDoublePointBoolArr(ex.b)[AAxis.IsVertical];
    Result := true;
  end else
    Result := false;
end;

function TCustomChartSeries.GetAxisX: TChartAxis;
begin
  if InRange(AxisIndexX, 0, FChart.AxisList.Count - 1) then
    Result := FChart.AxisList[AxisIndexX]
  else
    Result := FChart.BottomAxis;
end;

function TCustomChartSeries.GetAxisY: TChartAxis;
begin
  if InRange(AxisIndexY, 0, FChart.AxisList.Count - 1) then
    Result := FChart.AxisList[AxisIndexY]
  else
    Result := FChart.LeftAxis;
end;

function TCustomChartSeries.GetDepthColor(AColor: Integer;
  Opposite: Boolean = false): Integer;
var
  h, l, s: Byte;
begin
  ColorToHLS(AColor, h, l, s);
  if Opposite then
    Result := HLSToColor(h, EnsureRange(Integer(l) - FDepthBrightnessDelta, 0, 255), s)
  else
    Result := HLSToColor(h, EnsureRange(Integer(l) + FDepthBrightnessDelta, 0, 255), s);
end;

function TCustomChartSeries.GetGraphBounds: TDoubleRect;
begin
  Result := EmptyExtent;
  if Active then GetBounds(Result);
  with Result do begin
    UpdateBoundsByAxisRange(FChart.AxisList, AxisIndexX, a.X, b.X);
    UpdateBoundsByAxisRange(FChart.AxisList, AxisIndexY, a.Y, b.Y);
    TransformByAxis(FChart.AxisList, AxisIndexX).UpdateBounds(a.X, b.X);
    TransformByAxis(FChart.AxisList, AxisIndexY).UpdateBounds(a.Y, b.Y);
    if IsRotated then begin
      Exchange(a.X, a.Y);
      Exchange(b.X, b.Y);
    end;
  end;
end;

function TCustomChartSeries.GetIndex: Integer;
begin
  Result := FChart.Series.List.IndexOf(Self);
end;

procedure TCustomChartSeries.GetLegendItemsBasic(AItems: TChartLegendItems);
var
  i, oldCount: Integer;
begin
  oldCount := AItems.Count;
  if Assigned(Legend.OnDraw) then
    for i := 0 to Legend.UserItemsCount - 1 do
      AItems.Add(TLegendItemUserDrawn.Create(i, Legend.OnDraw, LegendTextSingle))
  else
    GetLegendItems(AItems);
  for i := oldCount to AItems.Count - 1 do begin
    AItems[i].Owner := Self;
    Legend.InitItem(AItems[i], i - oldCount, FChart.Legend);
  end;
end;

function TCustomChartSeries.GetNearestPoint(
  const AParams: TNearestPointParams;
  out AResults: TNearestPointResults): Boolean;
begin
  Unused(AParams);
  AResults.FDist := MaxInt;
  AResults.FImg := Point(0, 0);
  AResults.FIndex := 0;
  AResults.FValue := ZeroDoublePoint;
  Result := false;
end;

function TCustomChartSeries.GetParentComponent: TComponent;
begin
  Result := FChart;
end;

function TCustomChartSeries.GetShowInLegend: Boolean;
begin
  Result := Legend.Visible;
end;

procedure TCustomChartSeries.GetSingleLegendItem(AItems: TChartLegendItems);
var
  oldMultiplicity: TLegendMultiplicity;
begin
  ParentChart.DisableRedrawing;
  oldMultiplicity := Legend.Multiplicity;
  try
    Legend.Multiplicity := lmSingle;
    GetLegendItemsBasic(AItems);
  finally
    Legend.Multiplicity := oldMultiplicity;
    ParentChart.EnableRedrawing;
  end;
end;

function TCustomChartSeries.GraphToAxis(APoint: TDoublePoint): TDoublePoint;
begin
  if IsRotated then
    Exchange(APoint.X, APoint.Y);
  Result := DoublePoint(GraphToAxisX(APoint.X), GraphToAxisY(APoint.Y));
end;

function TCustomChartSeries.GraphToAxisX(AX: Double): Double;
begin
  Result := TransformByAxis(FChart.AxisList, AxisIndexX).GraphToAxis(AX)
end;

function TCustomChartSeries.GraphToAxisY(AY: Double): Double;
begin
  Result := TransformByAxis(FChart.AxisList, AxisIndexY).GraphToAxis(AY)
end;

function TCustomChartSeries.HasParent: Boolean;
begin
  Result := true;
end;

function TCustomChartSeries.IsRotated: Boolean;
var
  x_normal, y_normal: Boolean;
  x_axis: TChartAxis = nil;
  y_axis: TChartAxis = nil;
begin
  if InRange(AxisIndexX, 0, FChart.AxisList.Count-1) then
    x_axis := FChart.AxisList[AxisIndexX];
  if InRange(AxisIndexY, 0, FChart.AxisList.Count-1) then
    y_axis := FChart.AxisList[AxisIndexY];
  x_normal := (x_axis = nil) or (not x_axis.IsVertical);
  y_normal := (y_axis = nil) or y_axis.IsVertical;
  Result := (not x_normal) and (not y_normal);
end;

function TCustomChartSeries.LegendTextSingle: String;
begin
  if Legend.Format = '' then
    Result := Title
  else
    Result := Format(Legend.Format, [Title, Index]);
end;

function TCustomChartSeries.LegendTextStyle(AStyle: TChartStyle): String;
begin
  if Legend.Format = '' then
    Result := AStyle.Text
  else
    Result := Format(Legend.Format, [AStyle.Text, AStyle.Index]);
end;

procedure TCustomChartSeries.ReadState(Reader: TReader);
begin
  inherited ReadState(Reader);
  if Reader.Parent is TChart then
    TChart(Reader.Parent).AddSeries(Self);
end;

procedure TCustomChartSeries.SetActive(AValue: Boolean);
begin
  if FActive = AValue then exit;
  FActive := AValue;
  UpdateParentChart;
end;

procedure TCustomChartSeries.SetAxisIndexX(AValue: TChartAxisIndex);
begin
  if FAxisIndexX = AValue then exit;
  FAxisIndexX := AValue;
  UpdateParentChart;
end;

procedure TCustomChartSeries.SetAxisIndexY(AValue: TChartAxisIndex);
begin
  if FAxisIndexY = AValue then exit;
  FAxisIndexY := AValue;
  UpdateParentChart;
end;

procedure TCustomChartSeries.SetDepth(AValue: TChartDistance);
begin
  if FDepth = AValue then exit;
  FDepth := AValue;
  UpdateParentChart;
end;

procedure TCustomChartSeries.SetDepthBrightnessDelta(AValue: Integer);
begin
  if FDepthBrightnessDelta = AValue then exit;
  FDepthBrightnessDelta := AValue;
  UpdateParentChart;
end;

procedure TCustomChartSeries.SetIndex(AValue: Integer);
begin
  with FChart.Series.List do
    Move(Index, EnsureRange(AValue, 0, Count - 1));
end;

procedure TCustomChartSeries.SetLegend(AValue: TChartSeriesLegend);
begin
  if FLegend = AValue then exit;
  FLegend.Assign(AValue);
  UpdateParentChart;
end;

procedure TCustomChartSeries.SetParentComponent(AParent: TComponent);
begin
  if not (csLoading in ComponentState) then
    (AParent as TChart).AddSeries(Self);
end;

procedure TCustomChartSeries.SetShadow(AValue: TChartShadow);
begin
  if FShadow = AValue then exit;
  FShadow.Assign(AValue);
  UpdateParentChart;
end;

procedure TCustomChartSeries.SetShowInLegend(AValue: Boolean);
begin
  Legend.Visible := AValue;
end;

procedure TCustomChartSeries.SetTitle(AValue: String);
begin
  if FTitle = AValue then exit;
  FTitle := AValue;
  UpdateParentChart;
end;

procedure TCustomChartSeries.SetTransparency(AValue: TChartTransparency);
begin
  if FTransparency = AValue then exit;
  FTransparency := AValue;
  UpdateParentChart;
end;

procedure TCustomChartSeries.SetZPosition(AValue: TChartDistance);
begin
  if FZPosition = AValue then exit;
  FZPosition := AValue;
  UpdateParentChart;
end;

procedure TCustomChartSeries.StyleChanged(Sender: TObject);
begin
  if ParentChart <> nil then
    ParentChart.StyleChanged(Sender);
end;

function TCustomChartSeries.TitleIsStored: Boolean;
begin
  Result := Title <> '';
end;

procedure TCustomChartSeries.UpdateParentChart;
begin
  if ParentChart <> nil then
    ParentChart.StyleChanged(Self);
end;

{ TChartSeries }

function TChartSeries.Add(AValue: Double; AXLabel: String; AColor: TColor): Integer;
begin
  Result := AddXY(GetXMaxVal + 1, AValue, AXLabel, AColor);
end;

function TChartSeries.AddArray(const AValues: array of Double): Integer;
var
  a: Double;
begin
  Result := ListSource.Count;
  for a in AValues do
    Add(a);
end;

function TChartSeries.AddNull(ALabel: String; AColor: TColor): Integer;
begin
  Result := ListSource.Add(SafeNan, SafeNan, ALabel, AColor);
end;

function TChartSeries.AddX(AX: Double; ALabel: String; AColor: TColor): Integer;
begin
  Result := ListSource.Add(AX, SafeNan, ALabel, AColor);
end;

function TChartSeries.AddXY(
  AX, AY: Double; const AYList: array of Double;
  AXLabel: String; AColor: TColor): Integer;
begin
  Result := ListSource.Add(AX, AY, AXLabel, AColor);
  ListSource.SetYList(Result, AYList);
end;

function TChartSeries.AddXY(
  AX, AY: Double; AXLabel: String; AColor: TColor): Integer;
begin
  Result := ListSource.Add(AX, AY, AXLabel, AColor);
end;

function TChartSeries.AddY(AY: Double; ALabel: String; AColor: TColor): Integer;
begin
  Result := Add(AY, ALabel, AColor);
end;

procedure TChartSeries.AfterAdd;
begin
  inherited;
  Marks.SetOwner(FChart);
  Marks.Arrow.SetOwner(FChart);
  Marks.Margins.SetOwner(FChart);
end;

procedure TChartSeries.AfterDraw;
begin
  inherited AfterDraw;
  Source.AfterDraw;
end;

procedure TChartSeries.Assign(ASource: TPersistent);
begin
  if ASource is TChartSeries then
    with TChartSeries(ASource) do begin
      Self.Marks.Assign(FMarks);
      Self.FOnGetMark := FOnGetMark;
      Self.Source := FSource;
      Self.Styles := FStyles;
    end;
  inherited Assign(ASource);
end;

procedure TChartSeries.BeforeDraw;
begin
  inherited BeforeDraw;
  Source.BeforeDraw;
end;

procedure TChartSeries.BeginUpdate;
begin
  ListSource.BeginUpdate;
end;

procedure TChartSeries.CheckSource(ASource: TCustomChartSource);
var
  nx, ny: Cardinal;
begin
  if ASource = nil then
    exit;
  GetXYCountNeeded(nx, ny);
  if ASource.XCount < nx then
    raise EXCountError.CreateFmt(rsSourceCountError, [ClassName, nx, 'x']);
  if ASource.YCount < ny then
    raise EYCountError.CreateFmt(rsSourceCountError, [ClassName, ny, 'y']);
end;

procedure TChartSeries.Clear;
begin
  ListSource.Clear;
end;

function TChartSeries.Count: Integer;
begin
  Result := Source.Count;
end;

function TChartSeries.LastValueIndex: Integer;
begin
  Result := Source.Count - 1;
end;

constructor TChartSeries.Create(AOwner: TComponent);
const
  BUILTIN_SOURCE_NAME = 'Builtin';
var
  nx, ny: Cardinal;
begin
  inherited Create(AOwner);

  FListener := TListener.Create(@FSource,  @SourceChanged);
  GetXYCountNeeded(nx, ny);
  FBuiltinSource := TBuiltinListChartSource.Create(Self, nx, ny);
  FBuiltinSource.Name := BUILTIN_SOURCE_NAME;
  FBuiltinSource.Broadcaster.Subscribe(FListener);
  FMarks := TChartMarks.Create(FChart);
  FStylesListener := TListener.Create(@FStyles,  @StyleChanged);
end;

procedure TChartSeries.Delete(AIndex: Integer);
begin
  ListSource.Delete(AIndex);
end;

destructor TChartSeries.Destroy;
begin
  FreeAndNil(FListener);
  FreeAndNil(FBuiltinSource);
  FreeAndNil(FMarks);
  FreeAndNil(FStylesListener);
  inherited;
end;

procedure TChartSeries.EndUpdate;
begin
  ListSource.EndUpdate;
  UpdateParentChart;
end;

function TChartSeries.Extent: TDoubleRect;
begin
  Result := Source.ExtentCumulative;
end;

procedure TChartSeries.FindYRange(AXMin, AXMax: Double;
  var AYMin, AYMax: Double);
begin
  Source.FindYRange(AXMin, AXMax, false, AYMin, AYMax);
end;

function TChartSeries.FormattedMark(
  AIndex: Integer; AFormat: String; AYIndex: Integer): String;
begin
  if Assigned(FOnGetMark) then
    FOnGetMark(Result, AIndex)
  else
    Result := Source.FormatItem(
      IfThen(AFormat = '', Marks.Format, AFormat), AIndex, AYIndex);
end;

procedure TChartSeries.GetBounds(var ABounds: TDoubleRect);
var
  i: Integer;
begin
  if IsEmpty or (not Active) then exit;
  with Extent do
    for i := Low(coords) to High(coords) do
      if not IsInfinite(coords[i]) then
        ABounds.coords[i] := coords[i];
end;

function TChartSeries.GetColor(AIndex: Integer): TColor;
begin
  Result := ColorDef(Source[AIndex]^.Color, GetSeriesColor);
end;

function TChartSeries.GetGraphPoint(AIndex: Integer): TDoublePoint;
begin
  Result.X := GetGraphPointX(AIndex);
  Result.Y := GetGraphPointY(AIndex);
  if IsRotated then
    Exchange(Result.X, Result.Y);
end;

function TChartSeries.GetGraphPoint(AIndex, AXIndex, AYIndex: Integer): TDoublePoint;
begin
  Result.X := GetGraphPointX(AIndex, AXIndex);
  Result.Y := GetGraphPointY(AIndex, AYIndex);
  if IsRotated then
    Exchange(Result.X, Result.Y);
end;

function TChartSeries.GetGraphPointX(AIndex: Integer): Double;
begin
  if Source.XCount = 0 then
    Result := AxisToGraphX(AIndex)
  else
    Result := AxisToGraphX(Source[AIndex]^.X);
end;

function TChartSeries.GetGraphPointX(AIndex, AXIndex: Integer): Double;
begin
  if Source.XCount = 0 then
    Result := AxisToGraphX(AIndex)
  else
    Result := AxisToGraphX(Source[AIndex]^.GetX(AXIndex));
end;

function TChartSeries.GetGraphPointY(AIndex: Integer): Double;
begin
  Result := AxisToGraphY(Source[AIndex]^.Y);
end;

function TChartSeries.GetGraphPointY(AIndex, AYIndex: Integer): Double;
begin
  Result := AxisToGraphY(Source[AIndex]^.GetY(AYIndex));
end;

procedure TChartSeries.GetMax(out X, Y: Double);
begin
  X := Source.XOfMax;
  Y := Extent.b.Y;
end;

procedure TChartSeries.GetMin(out X, Y: Double);
begin
  X := Source.XOfMin;
  Y := Extent.a.Y;
end;

function TChartSeries.GetSeriesColor: TColor;
begin
  Result := clTAColor;
end;

function TChartSeries.GetSource: TCustomChartSource;
begin
  if Assigned(FSource) then
    Result := FSource
  else
    Result := FBuiltinSource;
end;

function TChartSeries.GetXImgValue(AIndex: Integer): Integer;
begin
  Result := ParentChart.XGraphToImage(Source[AIndex]^.X);
end;

function TChartSeries.GetXMax: Double;
begin
  Result := Extent.b.X;
end;

function TChartSeries.MaxXValue: Double;
begin
  Result := Extent.b.X;
end;

function TChartSeries.GetXMaxVal: Double;
begin
  if Count > 0 then
    Result := Source[Count - 1]^.X
  else
    Result := 0;
end;

class procedure TChartSeries.GetXYCountNeeded(out AXCount, AYCount: Cardinal);
begin
  AXCount := 0;
  AYCount := 1;
end;

function TChartSeries.GetXMin: Double;
begin
  Result := Extent.a.X;
end;

function TChartSeries.MinXValue: Double;
begin
  Result := Extent.a.X;
end;

function TChartSeries.GetXValue(AIndex: Integer): Double;
begin
  if Source.XCount > 0 then
    Result := Source[AIndex]^.X
  else
    Result := AIndex;
end;

function TChartSeries.GetXValues(AIndex, AXIndex: Integer): Double;
begin
  if AXIndex > 0 then
    Result := Source[AIndex]^.XList[AXIndex - 1]
  else
    Result := Source[AIndex]^.X;
end;

function TChartSeries.GetYImgValue(AIndex: Integer): Integer;
begin
  Result := ParentChart.YGraphToImage(Source[AIndex]^.Y);
end;

function TChartSeries.GetYMax: Double;
begin
  Result := Extent.b.Y;
end;

function TChartSeries.MaxYValue: Double;
begin
  Result := Extent.b.Y;
end;

function TChartSeries.GetYMin: Double;
begin
  Result := Extent.a.Y;
end;

function TChartSeries.MinYValue: Double;
begin
  Result := Extent.a.Y;
end;

function TChartSeries.GetYValue(AIndex: Integer): Double;
begin
  Result := Source[AIndex]^.Y;
end;

function TChartSeries.GetYValues(AIndex, AYIndex: Integer): Double;
begin
  if AYIndex = 0 then
    Result := GetYValue(AIndex)
  else
    Result := Source[AIndex]^.YList[AYIndex - 1];
end;

function TChartSeries.IsEmpty: Boolean;
begin
  Result := Count = 0;
end;

function TChartSeries.IsSourceStored: boolean;
begin
  Result := FSource <> nil;
end;

function TChartSeries.LegendTextPoint(AIndex: Integer): String;
begin
  Result := FormattedMark(AIndex, Legend.Format);
end;

function TChartSeries.ListSource: TListChartSource;
begin
  if not (Source is TListChartSource) then
    raise EEditableSourceRequired.Create(rsSourceNotEditable);
  Result := TListChartSource(Source);
end;

procedure TChartSeries.SetColor(AIndex: Integer; AColor: TColor);
begin
  ListSource.SetColor(AIndex, AColor);
end;

procedure TChartSeries.SetMarks(AValue: TChartMarks);
begin
  if FMarks = AValue then exit;
  FMarks.Assign(AValue);
end;

procedure TChartSeries.SetOnGetMark(AValue: TChartGetMarkEvent);
begin
  if TMethod(FOnGetMark) = TMethod(AValue) then exit;
  FOnGetMark := AValue;
  UpdateParentChart;
end;

procedure TChartSeries.SetSource(AValue: TCustomChartSource);
begin
  if AValue = FBuiltinSource then
    AValue := nil;
  if FSource = AValue then
    exit;
  CheckSource(AValue);
  if FListener.IsListening then
    Source.Broadcaster.Unsubscribe(FListener);
  FSource := AValue;
  Source.Broadcaster.Subscribe(FListener);
  SourceChanged(Self);
end;

procedure TChartSeries.SetStyles(AValue: TChartStyles);
begin
  if FStyles = AValue then exit;
  if FStylesListener.IsListening then
    Styles.Broadcaster.Unsubscribe(FStylesListener);
  FStyles := AValue;
  if Styles <> nil then
    Styles.Broadcaster.Subscribe(FStylesListener);
  UpdateParentChart;
end;

procedure TChartSeries.SetText(AIndex: Integer; AValue: String);
begin
  ListSource.SetText(AIndex, AValue);
end;

procedure TChartSeries.SetXValue(AIndex: Integer; AValue: Double); inline;
begin
  ListSource.SetXValue(AIndex, AValue);
end;

procedure TChartSeries.SetXValues(AIndex, AXIndex: Integer; AValue: Double);
begin
  if AXIndex = 0 then
    ListSource.SetXValue(AIndex, AValue)
  else
    ListSource.Item[AIndex]^.XList[AXIndex - 1] := AValue;
end;

procedure TChartSeries.SetYValue(AIndex: Integer; AValue: Double); inline;
begin
  ListSource.SetYValue(AIndex, AValue);
end;

procedure TChartSeries.SetYValues(AIndex, AYIndex: Integer; AValue: Double);
begin
  if AYIndex = 0 then
    ListSource.SetYValue(AIndex, AValue)
  else
    ListSource.Item[AIndex]^.YList[AYIndex - 1] := AValue;
end;

procedure TChartSeries.SourceChanged(ASender: TObject);
begin
  if (ASender <> FBuiltinSource) and (ASender is TCustomChartSource) then
    try
      CheckSource(TCustomChartSource(ASender));
    except
      Source := nil; // revert to built-in source
      raise;
    end;
  StyleChanged(ASender);
end;

procedure TChartSeries.VisitSources(
  AVisitor: TChartOnSourceVisitor; AAxis: TChartAxis; var AData);
begin
  if (AAxis = GetAxisX) or (AAxis = GetAxisY) then
    AVisitor(Source, AData);
end;

{ TBasicPointSeries }

procedure TBasicPointSeries.AfterAdd;
var
  i: Integer;
begin
  inherited AfterAdd;
  if Pointer <> nil then
    Pointer.SetOwner(ParentChart);
  for i := 0 to 1 do
    if FErrorBars[i] <> nil then
      FErrorBars[i].SetOwner(ParentChart);
end;

procedure TBasicPointSeries.AfterDrawPointer(
  ADrawer: IChartDrawer; AIndex: Integer; const APos: TPoint);
begin
  Unused(ADrawer);
  Unused(AIndex, APos);
end;

procedure TBasicPointSeries.Assign(ASource: TPersistent);
begin
  if ASource is TBasicPointSeries then
    with TBasicPointSeries(ASource) do begin
      Self.FMarkPositions := MarkPositions;
      if Self.FPointer <> nil then
        Self.FPointer.Assign(Pointer);
      Self.Stacked := Stacked;
      Self.FSupportsZeroLevel := FSupportsZeroLevel;
      Self.FMarkPositionCentered := FMarkPositionCentered;
    end;
  inherited Assign(ASource);
end;

constructor TBasicPointSeries.Create(AOwner: TComponent);
begin
  inherited;
  FErrorBars[0] := TChartErrorBar.Create(FChart);
  FErrorBars[1] := TChartErrorBar.Create(FChart);
  FOptimizeX := true;
  FLoBound := 0;
  FUpBound := Count - 1;
  ToolTargets := [nptPoint, nptYList];
end;

destructor TBasicPointSeries.Destroy;
begin
  FreeAndNil(FErrorBars[0]);
  FreeAndNil(FErrorBars[1]);
  FreeAndNil(FPointer);
  inherited;
end;

procedure TBasicPointSeries.DrawErrorBars(ADrawer: IChartDrawer);

  procedure EndBar(p: TPoint; w: Integer; IsHorBar: Boolean);
  begin
    if IsHorBar then
      ADrawer.Line(Point(p.x, p.y-w), Point(p.x, p.y+w))
    else
      ADrawer.Line(Point(p.x-w, p.y), Point(p.x+w, p.y));
  end;

  procedure DrawErrorBar(p: TDoublePoint; vp, vn: Double; w: Integer;
    IsXError: Boolean);
  var
    p1, p2: TDoublePoint;
    imgPt1, imgPt2: TPoint;
    isHorBar: Boolean;
  begin
    isHorBar := (IsXError and not IsRotated) or (IsRotated and not IsXError);

    if IsHorBar then begin
      p1 := DoublePoint(vp, p.Y);
      p2 := DoublePoint(vn, p.Y);
    end else begin
      p1 := DoublePoint(p.X, vp);
      p2 := DoublePoint(p.X, vn);
    end;
    imgPt1 := ParentChart.GraphToImage(p1);
    imgPt2 := ParentChart.GraphToImage(p2);
    ADrawer.Line(imgPt1, imgPt2);

    EndBar(imgPt1, w, isHorBar);
    EndBar(imgPt2, w, isHorBar);
  end;

  procedure InternalDrawErrorBars(IsXError: Boolean);
  var
    i: Integer;
    p: TDoublePoint;
    vp, vn: Double;
    w, w0: Integer;
    errbar: TChartErrorBar;
  begin
    if Assigned(Pointer) then
      w0 := IfThen(IsXError, Pointer.VertSize, Pointer.HorizSize)
    else
      w0 := DEF_ERR_ENDLENGTH;
    errbar := TChartErrorBar(IfThen(IsXError, XErrorBars, YErrorBars));
    w := ADrawer.Scale(IfThen(errBar.Width = -1, w0, errBar.Width));

    for i := FLoBound to FUpBound do begin
      p := FGraphPoints[i - FLoBound];
      if not ParentChart.IsPointInViewPort(p) then continue;
      if IsXError then begin
        if Source.GetXErrorBarLimits(i, vp, vn) then
          DrawErrorBar(p, AxisToGraphX(vp), AxisToGraphX(vn), w, true);
      end else begin
        if Source.GetYErrorBarLimits(i, vp, vn) then
          DrawErrorBar(p, AxisTographY(vp), AxisToGraphY(vn), w, false);
      end;
    end;
  end;

begin
  // Draw x error bars
  if Assigned(XErrorBars) and XErrorBars.Visible and Source.HasXErrorBars then
  begin
    ADrawer.Pen := XErrorBars.Pen;
    InternalDrawErrorBars(true);
  end;

  // Draw y error bars
  if Assigned(YErrorBars) and YErrorBars.Visible and Source.HasYErrorBars then
  begin
    ADrawer.Pen := YErrorBars.Pen;
    InternalDrawErrorBars(false);
  end;
end;

procedure TBasicPointSeries.DrawLabels(ADrawer: IChartDrawer; AYIndex: Integer = -1);
// Using AYIndex is workaround for issue #35077
var
  prevLabelPoly: TPointArray;

  procedure DrawLabel(
    const AText: String; const ADataPoint: TPoint; ADir: TLabelDirection);
  const
    OFFSETS: array [TLabelDirection] of TPoint =
      ((X: -1; Y: 0), (X: 0; Y: -1), (X: 1; Y: 0), (X: 0; Y: 1));
  var
    center: TPoint;
  begin
    if AText = '' then exit;

    if Marks.RotationCenter = rcCenter then
      center := ADataPoint + OFFSETS[ADir] * Marks.CenterOffset(ADrawer, AText)
    else
      center := ADataPoint + OFFSETS[ADir] * Marks.CenterHeightOffset(ADrawer, AText);
    Marks.DrawLabel(ADrawer, ADataPoint, center, AText, prevLabelPoly);
  end;

var
  y, ysum: Double;
  g: TDoublePoint;
  i, si: Integer;
  style: TChartStyle;
  lfont: TFont;
  curr, prev: Double;
  ext: TDoubleRect;
  yIsNaN: Boolean;
  centerLvl: Double;
begin
  if not Marks.IsMarkLabelsVisible then exit;

  lfont := TFont.Create;
  try
    lfont.Assign(Marks.LabelFont);
    ParentChart.DisableRedrawing;
    ext := Extent;
    centerLvl := AxisToGraphY((ext.a.y + ext.b.y) * 0.5);
    UpdateLabelDirectionReferenceLevel(0, 0, centerLvl);

    for i := FLoBound to FUpBound do begin
      if SkipMissingValues(i) then
        continue;
      prev := IfThen(FSupportsZeroLevel, GetZeroLevel, 0.0);
      for si := 0 to Source.YCount - 1 do begin
        g := GetLabelDataPoint(i, si);
        if FStacked then begin
          if si = 0 then begin
            y := Source[i]^.Y;
            yIsNaN := IsNaN(y);
            ysum := IfThen(yIsNaN, prev, y);
          end else begin
            y := Source[i]^.YList[si-1];
            yIsNaN := IsNaN(y);
            if yIsNaN then y := 0.0;
            if Stacked then begin
              ysum += y;
              y := ysum;
            end;
          end;
          if IsRotated then
            g.X := AxisToGraphY(y)
            // Axis-to-graph transformation is independent of axis rotation ->
            // Using AxisToGraph_Y_ is correct!
          else
            g.Y := AxisToGraphY(y);
        end else
          yIsNaN := IsNaN(g.y);

        curr := TDoublePointBoolArr(g)[not IsRotated];
        if FMarkPositionCentered then begin
          if IsRotated then
            g := DoublePoint((curr + prev) * 0.5, g.y)
          else
            g := DoublePoint(g.x, (curr + prev) * 0.5);
        end;
        if Stacked then
          prev := curr;

        // Draw only the requested y index
        if (AYIndex >= 0) then begin
          if si < AYIndex then
            Continue
          else if si > AYIndex then
            break;
        end;

        with ParentChart do
          if
            ((Marks.YIndex = MARKS_YINDEX_ALL) or (Marks.YIndex = si)) and
            IsPointInViewPort(g) and (not yIsNaN)
          then begin
            if Styles <> nil then begin
              style := Styles.StyleByIndex(si);
              if style.UseFont then
                Marks.LabelFont.Assign(style.Font)
              else
                Marks.LabelFont.Assign(lfont);
            end;
            UpdateLabelDirectionReferenceLevel(i, si, centerLvl);
            DrawLabel(
              FormattedMark(i, '', si),
              GraphToImage(g),
              GetLabelDirection(IfThen(IsRotated, g.X, g.Y), centerLvl)
            );
          end;
      end;
    end;

  finally
    Marks.LabelFont.Assign(lfont);
    ParentChart.EnableRedrawing;
    lfont.Free;
  end;
end;

{ Draws the pointers of the series.
  If ChartStyles are attached to the series then the pointer brush is determined
  by the style with the specified index. }
procedure TBasicPointSeries.DrawPointers(ADrawer: IChartDrawer;
  AStyleIndex: Integer = 0; UseDataColors: Boolean = false);
var
  i: Integer;
  p: TDoublePoint;
  ai: TPoint;
  ps, saved_ps: TSeriesPointerStyle;
  brushAlreadySet: boolean;
  c: TColor;
  style: TChartStyle;
begin
  Assert(Pointer <> nil, 'Series pointer');
  if (not Pointer.Visible) or (Length(FGraphPoints) = 0) then exit;
  for i := FLoBound to FUpBound do begin
    p := FGraphPoints[i - FLoBound];
    if not ParentChart.IsPointInViewPort(p) then continue;
    ai := ParentChart.GraphToImage(p);
    if Assigned(FOnCustomDrawPointer) then
      FOnCustomDrawPointer(Self, ADrawer, i, ai)
    else begin
      if Assigned(FOnGetPointerStyle) then begin
        saved_ps := Pointer.Style;
        ps := saved_ps;
        FOnGetPointerStyle(self, i, ps);
        Pointer.SetOwner(nil);   // avoid recursion
        Pointer.Style := ps;
      end;
      brushAlreadySet := false;
      if (Styles <> nil) then
      begin
        style := Styles.StyleByIndex(AStyleIndex);
        if style <> nil then brushAlreadySet := style.UseBrush;
      end;
      if brushAlreadySet then
        Styles.Apply(ADrawer, AStyleIndex);
      if UseDataColors then c := Source[i]^.Color else c := clTAColor;
      Pointer.Draw(ADrawer, ai, c, brushAlreadySet);
      AfterDrawPointer(ADrawer, i, ai);
      if Assigned(FOnGetPointerStyle) then begin
        Pointer.Style := saved_ps;
        Pointer.SetOwner(ParentChart);
      end;
    end;
  end;
end;

function TBasicPointSeries.Extent: TDoubleRect;
begin
  if FStacked then
    Result := Source.ExtentCumulative
  else
    Result := Source.ExtentList;
end;

// Find an interval of x-values intersecting the extent.
// Requires monotonic (but not necessarily increasing) axis transformation.
procedure TBasicPointSeries.FindExtentInterval(
  const AExtent: TDoubleRect; AFilterByExtent: Boolean);
var
  axisExtent: TDoubleInterval;
begin
  FLoBound := 0;
  FUpBound := Count - 1;
  if AFilterByExtent then begin
    with AExtent do
      if IsRotated then
        axisExtent := DoubleInterval(GraphToAxisX(a.Y), GraphToAxisX(b.Y))
      else
        axisExtent := DoubleInterval(GraphToAxisX(a.X), GraphToAxisX(b.X));
    Source.FindBounds(axisExtent.FStart, axisExtent.FEnd, FLoBound, FUpBound);
    FLoBound := Max(FLoBound - 1, 0);
    FUpBound := Min(FUpBound + 1, Count - 1);
  end;
end;

procedure TBasicPointSeries.FindYRange(AXMin, AXMax: Double; var AYMin, AYMax: Double);
begin
  Source.FindYRange(AXMin, AXMax, FStacked, AYMin, AYMax);
end;

function TBasicPointSeries.GetErrorBars(AIndex: Integer): TChartErrorBar;
begin
  Result := FErrorBars[AIndex];
end;

function TBasicPointSeries.GetLabelDataPoint(AIndex, AYIndex: Integer): TDoublePoint;
begin
  Result := GetGraphPoint(AIndex, 0, AYIndex);
end;

function TBasicPointSeries.GetLabelDirection(AValue: Double;
  const ACenterLevel: Double): TLabelDirection;
const
  DIR: array [Boolean, Boolean] of TLabelDirection =
    ((ldTop, ldBottom), (ldRight, ldLeft));
var
  isNeg: Boolean;
  ref: Double;
begin
  case MarkPositions of
    lmpPositive: isNeg := false;
    lmpNegative: isNeg := true;
    lmpOutside,
    lmpInside :
      begin
        ref := IfThen(FSupportsZeroLevel, AxisToGraphY(GetZeroLevel), ACenterLevel);
        if AValue < ref then
          isNeg := true
        else
        if AValue > ref then
          isNeg := false
        else
        if not FSupportsZeroLevel then
          isNeg := false
        else
          isNeg := AValue < ACenterLevel;
        if MarkPositions = lmpInside then
          isNeg := not isNeg;
      end;
  end;
  if Assigned(GetAxisY) then
    if (IsRotated and ParentChart.IsRightToLeft) xor GetAxisY.Inverted then
      isNeg := not isNeg;
  Result := DIR[IsRotated, isNeg];
end;

procedure TBasicPointSeries.GetLegendItemsRect(
  AItems: TChartLegendItems; ABrush: TBrush; APen: TPen);
var
  i: Integer;
  li: TLegendItemBrushPenRect;
  s: TChartStyle;
begin
  case Legend.Multiplicity of
    lmSingle:
      begin
        li := TLegendItemBrushPenRect.Create(ABrush, APen, LegendTextSingle);
        li.TextFormat := Legend.TextFormat;
        AItems.Add(li);
      end;
    lmPoint:
      for i := 0 to Count - 1 do begin
        li := TLegendItemBrushPenRect.Create(ABrush, APen, LegendTextPoint(i));
        li.Color := GetColor(i);
        li.TextFormat := Legend.TextFormat;
        AItems.Add(li);
      end;
    lmStyle:
      if Styles <> nil then
        for s in Styles.Styles do
          AItems.Add(TLegendItemBrushPenRect.Create(
            IfThen(s.UseBrush, s.Brush, ABrush) as TBrush,
            IfThen(s.UsePen, s.Pen, APen) as TPen,
            LegendTextStyle(s)
          ));
  end;
end;

function TBasicPointSeries.GetNearestPoint(
  const AParams: TNearestPointParams;
  out AResults: TNearestPointResults): Boolean;

  function GetGrabBound(ARadius: Integer): Double;
  begin
    if IsRotated then
      Result := ParentChart.YImageToGraph(AParams.FPoint.Y + ARadius)
    else
      Result := ParentChart.XImageToGraph(AParams.FPoint.X + ARadius);
    Result := GraphToAxisX(Result);
  end;

var
  dist, tmpDist, i, j, lb, ub: Integer;
  sp, tmpSp: TDoublePoint;
  pt, tmpPt: TDoublePoint;
begin
  AResults.FDist := Sqr(AParams.FRadius) + 1;  // the dist func does not calc sqrt
  AResults.FIndex := -1;
  AResults.FXIndex := 0;
  AResults.FYIndex := 0;
  if IsEmpty then exit(false);
  if not RequestValidChartScaling then exit(false);

  if FOptimizeX and AParams.FOptimizeX then
    Source.FindBounds(
      GetGrabBound(-AParams.FRadius),
      GetGrabBound( AParams.FRadius), lb, ub)
  else begin
    lb := 0;
    ub := Count - 1;
  end;

  dist := AResults.FDist;
  for i := lb to ub do begin
    sp := Source[i]^.Point;
    if IsNan(sp) then
      continue;

    // Since axis transformation may be non-linear, the distance should be
    // measured in screen coordinates. With high zoom ratios this may lead to
    // an integer overflow, so ADistFunc should use saturation arithmetics.

    // Find nearest point of datapoint at (x, y)
    if (nptPoint in AParams.FTargets) and (nptPoint in ToolTargets) then
    begin
      pt := AxisToGraph(sp);
      dist := Min(dist, ToolTargetDistance(AParams, pt, i, 0, 0));
    end;

    // Find nearest point to additional y values (at x).
    // In case of stacked data points check the stacked values.
    if (dist > 0) and (nptYList in AParams.FTargets) and (nptYList in ToolTargets)
    then begin
      tmpSp := sp;
      for j := 0 to Source.YCount - 2 do begin
        if FStacked then
          tmpSp.Y += Source[i]^.YList[j] else
          tmpSp.Y := Source[i]^.YList[j];
        tmpPt := AxisToGraph(tmpSp);
        tmpDist := ToolTargetDistance(AParams, tmpPt, i, 0, j + 1);
        if tmpDist < dist then begin
          dist := tmpDist;
          sp := tmpSp;
          pt := tmpPt;
          AResults.FYIndex := j + 1;    // FYIndex = 0 refers to the regular y
        end;
      end;
    end;

    // Find nearest point of additional x values (at y)
    if (dist > 0) and (nptXList in AParams.FTargets) and (nptXList in ToolTargets)
    then begin
      tmpSp := sp;
      for j := 0 to Source.XCount - 2 do begin
        tmpSp.X := Source[i]^.XList[j];
        tmpPt := AxisToGraph(tmpSp);
        tmpDist := ToolTargetDistance(AParams, tmpPt, i, j + 1, 0);
        if tmpDist < dist then begin
          dist := tmpDist;
          sp := tmpSp;
          pt := tmpPt;
          AResults.FXIndex := j + 1;   // FXindex = 0 refers to the regular x
        end;
      end;
    end;

    // The case nptCustom is not handled here, it depends on the series type.
    // TBarSeries, for example, checks whether AParams.FPoint is inside a bar.

    if dist >= AResults.FDist then
      continue;

    AResults.FDist := dist;
    AResults.FIndex := i;
    AResults.FValue := sp;
    AResults.FImg := ParentChart.GraphToImage(pt);
    if dist = 0 then break;
  end;
  Result := AResults.FIndex >= 0;
end;

function TBasicPointSeries.GetXRange(AX: Double; AIndex: Integer): Double;
var
  wl, wr: Double;
  i: Integer;
begin
  if Source.XCount > 0 then begin
    i := AIndex - 1;
    wl := Abs(AX - NearestXNumber(i, -1));
    i := AIndex + 1;
    wr := Abs(AX - NearestXNumber(i, +1));
    Result := NumberOr(SafeMin(wl, wr), 1.0);
  end else
    Result := 1.0;
end;

function TBasicPointSeries.GetZeroLevel: Double;
begin
  Result := 0.0;
end;

{ Returns true if the data point at the given index has at least one missing
  y value (NaN) }
function TBasicPointSeries.HasMissingYValue(AIndex: Integer;
  AMaxYIndex: Integer = MaxInt): Boolean;
var
  j: Integer;
begin
  Result := IsNaN(Source[AIndex]^.Y);
  if not Result then
    for j := 0 to Min(AMaxYIndex, Source.YCount)-2 do
      if IsNaN(Source[AIndex]^.YList[j]) then
        exit(true);
end;

function TBasicPointSeries.IsErrorBarsStored(AIndex: Integer): Boolean;
begin
  with FErrorBars[AIndex] do
    Result := Visible or (Width <> -1) or (Pen.Color <> clBlack) or
      (not Pen.Cosmetic) or (Pen.EndCap <> pecRound) or
      (Pen.JoinStyle <> pjsRound) or (Pen.Mode <> pmCopy) or
      (Pen.Style <> psSolid) or (Pen.Width <> 1);
end;

procedure TBasicPointSeries.MovePoint(
  var AIndex: Integer; const ANewPos: TDoublePoint);
var
  p: TDoublePoint;
begin
  if not InRange(AIndex, 0, Count - 1) then exit;
  p := GraphToAxis(ANewPos);
  with ListSource do begin
    AIndex := SetXValue(AIndex, p.X);
    SetYValue(AIndex, p.Y);
  end;
end;

procedure TBasicPointSeries.MovePointEx(var AIndex: Integer;
  AXIndex, AYIndex: Integer; const ANewPos: TDoublePoint);
var
  sp: TDoublePoint;
  sum: Double;
  j: Integer;
begin
  Unused(AXIndex);

  if not InRange(AIndex, 0, Count - 1) then
    exit;

  sp := GraphToAxis(ANewPos);
  case AYIndex of
   -1: begin
        // ListSource.SetXValue(AIndex, sp.X);
        // ListSource.SetYValue(AIndex, sp.Y);
       end;
    0: begin
         ListSource.SetXValue(AIndex, sp.X);
         ListSource.SetYValue(AIndex, sp.Y);
       end;
    else
      if FStacked then begin
        sum := 0;
        for j := 0 to AYIndex - 1 do
          sum := sum + YValues[AIndex, j];
        YValues[AIndex, AYIndex] := sp.Y - sum;
      end else
        YValues[AIndex, AYIndex] := sp.Y;
      UpdateParentChart;
  end;
end;

function TBasicPointSeries.NearestXNumber(
  var AIndex: Integer; ADir: Integer): Double;
begin
  while InRange(AIndex, 0, Count - 1) do
    with Source[AIndex]^ do
      if IsNan(X) then
        AIndex += ADir
      else
        exit(AxisToGraphX(X));
  Result := SafeNan;
end;

procedure TBasicPointSeries.PrepareGraphPoints(
  const AExtent: TDoubleRect; AFilterByExtent: Boolean);
var
  i: Integer;
begin
  FindExtentInterval(AExtent, AFilterByExtent);

  SetLength(FGraphPoints, Max(FUpBound - FLoBound + 1, 0));
  if (AxisIndexX < 0) and (AxisIndexY < 0) then begin
    // Optimization: bypass transformations in the default case.
    if Source.XCount > 0 then
      for i := FLoBound to FUpBound do
        with Source[i]^ do
          FGraphPoints[i - FLoBound] := DoublePoint(X, Y)
    else
      for i := FLoBound to FUpBound do
        with Source[i]^ do
          FGraphPoints[i - FLoBound] := DoublePoint(i, Y);
  end else
    for i := FLoBound to FUpBound do
      FGraphPoints[i - FLoBound] := GetGraphPoint(i);
end;

procedure TBasicPointSeries.SetErrorBars(AIndex: Integer;
  AValue: TChartErrorBar);
begin
  FErrorBars[AIndex] := AValue;
  UpdateParentChart;
end;

procedure TBasicPointSeries.SetMarkPositionCentered(AValue: Boolean);
begin
  if FMarkPositionCentered = AValue then exit;
  FMarkPositionCentered := AValue;
  UpdateParentChart;
end;

procedure TBasicPointSeries.SetMarkPositions(AValue: TLinearMarkPositions);
begin
  if FMarkPositions = AValue then exit;
  FMarkPositions := AValue;
  UpdateParentChart;
end;

procedure TBasicPointSeries.SetPointer(AValue: TSeriesPointer);
begin
  FPointer.Assign(AValue);
  UpdateParentChart;
end;

procedure TBasicPointSeries.SetStacked(AValue: Boolean);
begin
  if FStacked = AValue then exit;
  FStacked := AValue;
  UpdateParentChart;
end;

procedure TBasicPointSeries.SetStackedNaN(AValue: TStackedNaN);
begin
  if FStackedNaN = AValue then exit;
  FStackedNaN := AValue;
  UpdateParentChart;
end;

{ Returns true when the data point at the specified index contains missing
  values in a way such that the point cannot be drawn. }
function TBasicPointSeries.SkipMissingValues(AIndex: Integer): Boolean;
begin
  Result := IsNan(Source[AIndex]^.X);
  if not Result then
    Result := FStacked and (FStackedNaN = snDoNotDraw) and HasMissingYValue(AIndex);
end;

function TBasicPointSeries.ToolTargetDistance(const AParams: TNearestPointParams;
  AGraphPt: TDoublePoint; APointIdx, AXIdx, AYIdx: Integer): Integer;
var
  pt: TPoint;
begin
  Unused(APointIdx);
  Unused(AXIdx, AYIdx);
  if IsNaN(AGraphPt) then
    exit(MaxInt)
  else begin
    pt := ParentChart.GraphToImage(AGraphPt);
    Result := AParams.FDistFunc(AParams.FPoint, pt);
  end;
end;

// AIndex refers to the index into YList here.
// The ordinary Y value has Index = -1.
procedure TBasicPointSeries.UpdateGraphPoints(AIndex, ALo, AUp: Integer;
  ACumulative: Boolean);
var
  i, j: Integer;
  y: Double;
begin
  if IsRotated then begin
    if ACumulative then begin
      if FStacked and (FStackedNaN = snReplaceByZero) then
        for i := ALo to AUp do
        begin
          y := NumberOr(Source[i]^.Y, IfThen(FSupportsZeroLevel, GetZeroLevel, 0.0));
          for j := 0 to AIndex do
            y += NumberOr(Source[i]^.YList[j], 0.0);
          FGraphPoints[i - ALo].X := AxisToGraphY(y)
        end
      else
        for i := ALo to AUp do
        begin
          y := Source[i]^.Y;
          for j := 0 to AIndex do
            y += Source[i]^.YList[j];
          FGraphPoints[i - ALo].X := AxisToGraphY(y);
        end;
    end else
    if AIndex = -1 then
      for i := ALo to AUp do
        FGraphPoints[i - ALo].X := AxisToGraphY(Source[i]^.Y)
    else
      for i := ALo to AUp do
        FGraphPoints[i - ALo].X := AxisToGraphY(Source[i]^.YList[AIndex]);
  end
  else begin
    if ACumulative then begin
      if FStacked and (FStackedNaN = snReplaceByZero) then
        for i := ALo to AUp do
        begin
          y := NumberOr(Source[i]^.Y, IfThen(FSupportsZeroLevel, GetZeroLevel, 0.0));
          for j := 0 to AIndex do
            y += NumberOr(Source[i]^.YList[j], 0.0);
          FGraphPoints[i - ALo].Y := AxisToGraphY(y);
        end
      else
        for i := ALo to AUp do begin
          y := Source[i]^.Y;
          for j := 0 to AIndex do
            y += Source[i]^.YList[j];
          FGraphPoints[i - ALo].Y := AxisToGraphY(y);
        end;
    end else
    if AIndex = -1 then
      for i := ALo to AUp do
        FGraphPoints[i - ALo].Y := AxisToGraphY(Source[i]^.Y)
    else
      for i := ALo to AUp do
        FGraphPoints[i - ALo].Y := AxisToGraphY(Source[i]^.YList[AIndex]);
  end;
end;

procedure TBasicPointSeries.UpdateGraphPoints(AIndex: Integer;
  ACumulative: Boolean);
begin
  UpdateGraphPoints(AIndex, FLoBound, FUpBound, ACumulative);
end;

procedure TBasicPointSeries.SourceChanged(ASender: TObject);
begin
  FLoBound := 0;
  FUpBound := Count - 1;
  inherited;
end;

procedure TBasicPointSeries.UpdateMargins(
  ADrawer: IChartDrawer; var AMargins: TRect);
var
  i, dist, j: Integer;
  labelText: String;
  dir: TLabelDirection;
  m: array [TLabelDirection] of Integer absolute AMargins;
  gp: TDoublePoint;
  scMarksDistance: Integer;
  center: Double;
  ysum: Double;
begin
  if not Marks.IsMarkLabelsVisible or not Marks.AutoMargins then exit;
  if IsEmpty then exit;

  {FLoBound and FUpBound fields may be outdated here (if axis' range has been
   changed after the last series' painting). FLoBound and FUpBound will be fully
   updated later, in a PrepareGraphPoints() call. But we need them now. If data
   source is sorted by X in the ascending order, obtaining FLoBound and FUpBound
   is very fast (binary search) - so we call FindExtentInterval() with True as
   the second parameter. Otherwise, obtaining FLoBound and FUpBound requires
   enumerating all the data points to see, if they are in the current chart's
   viewport. But this is exactly what we are going to do in the loop below, so
   obtaining true FLoBound and FUpBound values makes no sense in this case - so
   we call FindExtentInterval() with False as the second parameter, thus setting
   FLoBound to 0 and FUpBound to Count-1}
  FindExtentInterval(ParentChart.CurrentExtent, Source.IsSortedByXAsc);

  with Extent do
    center := AxisToGraphY((a.y + b.y) * 0.5);
  UpdateLabelDirectionReferenceLevel(0, 0, center);
  scMarksDistance := ADrawer.Scale(Marks.Distance);
  for i := FLoBound to FUpBound do begin
    j := 0;
    gp := GetLabelDataPoint(i, 0);
    while true do begin
      if not ParentChart.IsPointInViewPort(gp) then break;
      labelText := FormattedMark(i, '', j);
      if labelText = '' then break;

      UpdateLabelDirectionReferenceLevel(i, j, center);
      dir := GetLabelDirection(TDoublePointBoolArr(gp)[not IsRotated], center);
      with Marks.MeasureLabel(ADrawer, labelText) do
        dist := IfThen(dir in [ldLeft, ldRight], cx, cy);
      if Marks.DistanceToCenter then
        dist := dist div 2;

      m[dir] := Max(m[dir], dist + scMarksDistance);

      if (Source.YCount > 1) and (j = 0) then begin
        if FStacked then begin
          ysum := 0;
          for j := 0 to Source.YCount-1 do
            ysum += NumberOr(Source.Item[i]^.GetY(j), 0.0);
          TDoublePointBoolArr(gp)[not IsRotated] := AxisToGraphY(ysum);
        end else
          gp := GetLabelDataPoint(i, Source.YCount-1);
        j := Source.YCount-1;
      end else
        break;
    end;
  end;
end;

{ Can be overridden for a data-point dependent reference level, such as in
  TBubbleSeries. AIndex refers to chart source. }
procedure TBasicPointSeries.UpdateLabelDirectionReferenceLevel(AIndex, AYIndex: Integer;
  var ALevel: Double);
begin
  Unused(AIndex, AYIndex, ALevel);
end;

procedure TBasicPointSeries.UpdateMinXRange;
var
  x, prevX: Double;
  i: Integer;
begin
  if (Count < 2) or (Source.XCount = 0) then begin
    FMinXRange := 1.0;
    exit;
  end;
  x := Source[0]^.X;
  prevX := Source[1]^.X;
  FMinXRange := Abs(x - prevX);
  for i := 2 to Count - 1 do begin
    x := Source[i]^.X;
    FMinXRange := SafeMin(Abs(x - prevX), FMinXRange);
    prevX := x;
  end;
end;

procedure SkipObsoleteProperties;
const
  LEGEND_NOTE = 'Obsolete, use TCustomChartSeries.ShowInLegend instead';
begin
  RegisterPropertyToSkip(TCustomChartSeries, 'ShowInLegend', LEGEND_NOTE, '');
end;

initialization
  SkipObsoleteProperties;

end.


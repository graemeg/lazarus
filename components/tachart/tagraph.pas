{
 /***************************************************************************
                               TAGraph.pas
                               -----------
                    Component Library Standard Graph


 ***************************************************************************/

 *****************************************************************************
  See the file COPYING.modifiedLGPL.txt, included in this distribution,
  for details about the license.
 *****************************************************************************

  Authors: Luís Rodrigues, Philippe Martinole, Alexander Klenin

}
unit TAGraph;

{$H+}

interface

uses
  Graphics, Classes, Controls, LCLType, SysUtils,
  TAChartAxis, TAChartAxisUtils, TAChartUtils, TADrawUtils, TAGUIConnector,
  TALegend, TATextElements, TATypes;

type
  TChart = class;

  TChartDrawLegendEvent = procedure(
    ASender: TChart; ADrawer: IChartDrawer; ALegendItems: TChartLegendItems;
    ALegendItemSize: TPoint; const ALegendRect: TRect;
    AColCount, ARowCount: Integer) of object;

  { TBasicChartSeries }

  TBasicChartSeries = class(TIndexedComponent)
  protected
    FActive: Boolean;
    FChart: TChart;
    FDepth: TChartDistance;
    FDragOrigin: TPoint;
    FShadow: TChartShadow;
    FTransparency: TChartTransparency;
    FZPosition: TChartDistance;
    FSpecialPointPos: Boolean;

    procedure AfterAdd; virtual; abstract;
    procedure AfterDraw; virtual;
    procedure BeforeDraw; virtual;
    procedure GetLegendItemsBasic(AItems: TChartLegendItems); virtual; abstract;
    function GetShowInLegend: Boolean; virtual; abstract;
    function RequestValidChartScaling: Boolean; virtual;
    procedure SetActive(AValue: Boolean); virtual; abstract;
    procedure SetDepth(AValue: TChartDistance); virtual; abstract;
    procedure SetShadow(AValue: TChartShadow); virtual; abstract;
    procedure SetShowInLegend(AValue: Boolean); virtual; abstract;
    procedure SetTransparency(AValue: TChartTransparency); virtual; abstract;
    procedure SetZPosition(AValue: TChartDistance); virtual; abstract;
    procedure UpdateMargins(ADrawer: IChartDrawer; var AMargins: TRect); virtual;
    procedure VisitSources(
      AVisitor: TChartOnSourceVisitor; AAxis: TChartAxis; var AData); virtual;

  public
    function AxisToGraphX(AX: Double): Double; virtual;
    function AxisToGraphY(AY: Double): Double; virtual;
    function GraphToAxisX(AX: Double): Double; virtual;
    function GraphToAxisY(AY: Double): Double; virtual;

  public
    procedure Assign(Source: TPersistent); override;
    destructor Destroy; override;

  public
    procedure Draw(ADrawer: IChartDrawer); virtual; abstract;
    function GetAxisBounds(AAxis: TChartAxis; out AMin, AMax: Double): boolean; virtual; abstract;
    function GetGraphBounds: TDoubleRect; virtual; abstract;
    function IsEmpty: Boolean; virtual; abstract;
    procedure MovePoint(var AIndex: Integer; const ANewPos: TPoint); overload; inline;
    procedure MovePoint(var AIndex: Integer; const ANewPos: TDoublePoint); overload; virtual;
    procedure MovePointEx(var AIndex: Integer; AXIndex, AYIndex: Integer;
      const ANewPos: TDoublePoint); virtual;
    procedure UpdateBiDiMode; virtual;

    property Active: Boolean read FActive write SetActive default true;
    property Depth: TChartDistance read FDepth write SetDepth default 0;
    property DragOrigin: TPoint read FDragOrigin write FDragOrigin;
    property ParentChart: TChart read FChart;
    property Shadow: TChartShadow read FShadow write SetShadow;
    property SpecialPointPos: Boolean read FSpecialPointPos;
    property Transparency: TChartTransparency
      read FTransparency write SetTransparency default 0;
    property ZPosition: TChartDistance read FZPosition write SetZPosition default 0;
  end;

  TSeriesClass = class of TBasicChartSeries;

  { TBasicСhartTool }

  TBasicChartTool = class(TIndexedComponent)
  strict protected
    FChart: TChart;
    FStartMousePos: TPoint;

    procedure Activate; virtual;
    procedure Deactivate; virtual;
    function PopupMenuConflict: Boolean; virtual;
  public
    property Chart: TChart read FChart;
  end;

  TChartToolEventId = (
    evidKeyDown, evidKeyUp, evidMouseDown, evidMouseMove, evidMouseUp,
    evidMouseWheelDown, evidMouseWheelUp);

  { TBasicChartToolset }

  TBasicChartToolset = class(TComponent)
  public
    function Dispatch(
      AChart: TChart; AEventId: TChartToolEventId;
      AShift: TShiftState; APoint: TPoint): Boolean; virtual; abstract; overload;
    procedure Draw(AChart: TChart; ADrawer: IChartDrawer); virtual; abstract;
  end;

  TBasicChartSeriesEnumerator = class(TFPListEnumerator)
  public
    function GetCurrent: TBasicChartSeries;
    property Current: TBasicChartSeries read GetCurrent;
  end;

  { TChartSeriesList }

  TChartSeriesList = class(TPersistent)
  private
    FList: TIndexedComponentList;
    function GetItem(AIndex: Integer): TBasicChartSeries;
  public
    constructor Create;
    destructor Destroy; override;
  public
    procedure Clear;
    function Count: Integer;
    function GetEnumerator: TBasicChartSeriesEnumerator;
    procedure UpdateBiDiMode;
  public
    property Items[AIndex: Integer]: TBasicChartSeries read GetItem; default;
    property List: TIndexedComponentList read FList;
  end;

  TChartAfterCustomDrawEvent = procedure (
    ASender: TChart; ADrawer: IChartDrawer; const ARect: TRect) of object;
  TChartBeforeCustomDrawEvent = procedure (
    ASender: TChart; ADrawer: IChartDrawer; const ARect: TRect;
    var ADoDefaultDrawing: Boolean) of object;

  TChartAfterDrawEvent = procedure (
    ASender: TChart; ACanvas: TCanvas; const ARect: TRect) of object;
  TChartBeforeDrawEvent = procedure (
    ASender: TChart; ACanvas: TCanvas; const ARect: TRect;
    var ADoDefaultDrawing: Boolean) of object;
  TChartEvent = procedure (ASender: TChart) of object;
  TChartPaintEvent = procedure (
    ASender: TChart; const ARect: TRect;
    var ADoDefaultDrawing: Boolean) of object;
  TChartDrawEvent = procedure (
    ASender: TChart; ADrawer: IChartDrawer) of object;
  TChartExtentValidateEvent = procedure (
    ASender: TChart; var ALogicalExtent: TDoubleRect; var AllowChange: Boolean) of object;

  TChartRenderingParams = record
    FClipRect: TRect;
    FIsZoomed: Boolean;
    FLogicalExtent, FPrevLogicalExtent: TDoubleRect;
    FScale, FOffset: TDoublePoint;
  end;

  { TChart }

  TChart = class(TCustomChart, ICoordTransformer)
  strict private // Property fields
    FAllowZoom: Boolean;
    FAllowPanning: Boolean;
    FAntialiasingMode: TChartAntialiasingMode;
    FAxisList: TChartAxisList;
    FAxisVisible: Boolean;
    FBackColor: TColor;
    FConnectorData: TChartGUIConnectorData;
    FDepth: TChartDistance;
    FDefaultGUIConnector: TChartGUIConnector;
    FExpandPercentage: Integer;
    FExtent: TChartExtent;
    FExtentSizeLimit: TChartExtent;
    FFoot: TChartTitle;
    FFrame: TChartPen;
    FGUIConnector: TChartGUIConnector;
    FGUIConnectorListener: TListener;
    FLegend: TChartLegend;
    FLogicalExtent: TDoubleRect;
    FMargins: TChartMargins;
    FMarginsExternal: TChartMargins;
    FMinDataSpace: Integer;
    FOnAfterCustomDrawBackground: TChartAfterCustomDrawEvent;
    FOnAfterCustomDrawBackWall: TChartAfterCustomDrawEvent;
    FOnAfterDraw: TChartDrawEvent;
    FOnAfterDrawBackground: TChartAfterDrawEvent;
    FOnAfterDrawBackWall: TChartAfterDrawEvent;
    FOnBeforeCustomDrawBackground: TChartBeforeCustomDrawEvent;
    FOnBeforeCustomDrawBackWall: TChartBeforeCustomDrawEvent;
    FOnBeforeDrawBackground: TChartBeforeDrawEvent;
    FOnBeforeDrawBackWall: TChartBeforeDrawEvent;
    FOnChartPaint: TChartPaintEvent;
    FOnDrawLegend: TChartDrawLegendEvent;
    FProportional: Boolean;
    FSeries: TChartSeriesList;
    FSetLogicalExtentCounter: Integer;
    FTitle: TChartTitle;
    FToolset: TBasicChartToolset;

    function ClipRectWithoutFrame(AZPosition: TChartDistance): TRect;
    function EffectiveGUIConnector: TChartGUIConnector; inline;
  private
    FActiveToolIndex: Integer;
    FAutoFocus: Boolean;
    FBroadcaster: TBroadcaster;
    FClipRectBroadcaster: TBroadcaster;
    FBuiltinToolset: TBasicChartToolset;
    FClipRect: TRect;
    FCurrentExtent: TDoubleRect;
    FDisableRedrawingCounter: Integer;
    FExtentBroadcaster: TBroadcaster;
    FFullExtentBroadcaster: TBroadcaster;
    FIsZoomed: Boolean;
    FOffset: TDoublePoint;   // Coordinates transformation
    FOffsetInt: TPoint;      // Coordinates transformation
    FOnAfterPaint: TChartEvent;
    FOnExtentChanged: TChartEvent;
    FOnExtentChanging: TChartEvent;
    FOnExtentValidate: TChartExtentValidateEvent;
    FOnFullExtentChanged: TChartEvent;
    FPrevFullExtent: TDoubleRect;
    FPrevLogicalExtent: TDoubleRect;
    FScale: TDoublePoint;    // Coordinates transformation
    FScalingValid: Boolean;
    FMultiPassScalingNeeded: Boolean;
    FOldClipRect: TRect;
    FSavedClipRect: TRect;
    FClipRectLock: Integer;

    procedure CalculateTransformationCoeffs(const AMargin, AChartMargins: TRect;
      const AMinDataSpace: Integer);
    procedure FindComponentClass(
      AReader: TReader; const AClassName: String; var AClass: TComponentClass);
    function GetChartHeight: Integer;
    function GetChartWidth: Integer;
    function GetHorAxis: TChartAxis;
    function GetMargins(ADrawer: IChartDrawer): TRect;
    function GetRenderingParams: TChartRenderingParams;
    function GetSeriesCount: Integer;
    function GetToolset: TBasicChartToolset;
    function GetVertAxis: TChartAxis;
    procedure SetAntialiasingMode(AValue: TChartAntialiasingMode);
    procedure SetAxisList(AValue: TChartAxisList);
    procedure SetAxisVisible(Value: Boolean);
    procedure SetBackColor(AValue: TColor);
    procedure SetDepth(AValue: TChartDistance);
    procedure SetExpandPercentage(AValue: Integer);
    procedure SetExtent(AValue: TChartExtent);
    procedure SetExtentSizeLimit(AValue: TChartExtent);
    procedure SetFoot(Value: TChartTitle);
    procedure SetFrame(Value: TChartPen);
    procedure SetGUIConnector(AValue: TChartGUIConnector);
    procedure SetLegend(Value: TChartLegend);
    procedure SetLogicalExtent(AValue: TDoubleRect);
    procedure SetMargins(AValue: TChartMargins);
    procedure SetMarginsExternal(AValue: TChartMargins);
    procedure SetMinDataSpace(const AValue: Integer);
    procedure SetOnAfterCustomDrawBackground(AValue: TChartAfterCustomDrawEvent);
    procedure SetOnAfterCustomDrawBackWall(AValue: TChartAfterCustomDrawEvent);
    procedure SetOnAfterDraw(AValue: TChartDrawEvent);
    procedure SetOnAfterDrawBackground(AValue: TChartAfterDrawEvent);
    procedure SetOnAfterDrawBackWall(AValue: TChartAfterDrawEvent);
    procedure SetOnBeforeCustomDrawBackground(AValue: TChartBeforeCustomDrawEvent);
    procedure SetOnBeforeCustomDrawBackWall(AValue: TChartBeforeCustomDrawEvent);
    procedure SetOnBeforeDrawBackground(AValue: TChartBeforeDrawEvent);
    procedure SetOnBeforeDrawBackWall(AValue: TChartBeforeDrawEvent);
    procedure SetOnChartPaint(AValue: TChartPaintEvent);
    procedure SetOnDrawLegend(AValue: TChartDrawLegendEvent);
    procedure SetProportional(AValue: Boolean);
    procedure SetRenderingParams(AValue: TChartRenderingParams);
    procedure SetTitle(Value: TChartTitle);
    procedure SetToolset(AValue: TBasicChartToolset);
    procedure VisitSources(
      AVisitor: TChartOnSourceVisitor; AAxis: TChartAxis; var AData);
  protected
    FDisablePopupMenu: Boolean;
    procedure DoContextPopup(MousePos: TPoint; var Handled: Boolean); override;
    function DoMouseWheel(
      AShift: TShiftState; AWheelDelta: Integer;
      AMousePos: TPoint): Boolean; override;
    procedure MouseDown(
      Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseUp(
      AButton: TMouseButton; AShift: TShiftState; AX, AY: Integer); override;
  protected
    function GetAxisBounds(AAxis: TChartAxis): TDoubleInterval;
    function GetAxisByAlign(AAlign: TChartAxisAlignment): TChartAxis;
    procedure SetAxisByAlign(AAlign: TChartAxisAlignment; AValue: TChartAxis); inline;
  protected
    procedure Clear(ADrawer: IChartDrawer; const ARect: TRect);
    procedure DisplaySeries(ADrawer: IChartDrawer);
    procedure DrawBackWall(ADrawer: IChartDrawer);
    procedure KeyDownAfterInterface(var AKey: Word; AShift: TShiftState); override;
    procedure KeyUpAfterInterface(var AKey: Word; AShift: TShiftState); override;
    {$IFDEF LCLGtk2}
    procedure DoOnResize; override;
    {$ENDIF}
    procedure Notification(
      AComponent: TComponent; AOperation: TOperation); override;
    procedure PrepareAxis(ADrawer: IChartDrawer);
    function PrepareLegend(
      ADrawer: IChartDrawer; var AClipRect: TRect): TChartLegendDrawingData;
    procedure RequestMultiPassScaling; inline;
    procedure SetBiDiMode(AValue: TBiDiMode); override;
    procedure SetName(const AValue: TComponentName); override;

  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure EraseBackground(DC: HDC); override;
    procedure GetChildren(AProc: TGetChildProc; ARoot: TComponent); override;
    procedure Paint; override;
    procedure SetChildOrder(Child: TComponent; Order: Integer); override;

  public // Helpers for series drawing
    procedure DrawLineHoriz(ADrawer: IChartDrawer; AY: Integer);
    procedure DrawLineVert(ADrawer: IChartDrawer; AX: Integer);
    function IsPointInViewPort(const AP: TDoublePoint): Boolean;

  public
    procedure AddSeries(ASeries: TBasicChartSeries);
    procedure ClearSeries;
    function Clone: TChart; overload;
    function Clone(ANewOwner, ANewParent: TComponent): TChart; overload;
    procedure CopyToClipboard(AClass: TRasterImageClass);
    procedure CopyToClipboardBitmap;
    procedure DeleteSeries(ASeries: TBasicChartSeries);
    procedure DisableRedrawing;
    procedure Draw(ADrawer: IChartDrawer; const ARect: TRect);
    procedure DrawLegendOn(ACanvas: TCanvas; var ARect: TRect);
    procedure EnableRedrawing;
    procedure GetAllSeriesAxisLimits(AAxis: TChartAxis; out AMin, AMax: Double);
    function GetFullExtent: TDoubleRect;
    function GetLegendItems(AIncludeHidden: Boolean = false): TChartLegendItems;
    procedure Notify(ACommand: Integer; AParam1, AParam2: Pointer; var AData); override;
    procedure PaintOnAuxCanvas(ACanvas: TCanvas; ARect: TRect);
    procedure PaintOnCanvas(ACanvas: TCanvas; ARect: TRect);
    procedure Prepare;
    procedure RemoveSeries(ASeries: TBasicChartSeries); inline;
    procedure SaveToBitmapFile(const AFileName: String); inline;
    procedure SaveToFile(AClass: TRasterImageClass; AFileName: String);
    function SaveToImage(AClass: TRasterImageClass): TRasterImage;
    procedure StyleChanged(Sender: TObject); override;
    function UsesBuiltinToolset: Boolean;
    procedure ZoomFull(AImmediateRecalc: Boolean = false); override;
    property Drawer: IChartDrawer read FConnectorData.FDrawer;

  public // Coordinate conversion
    function GraphToImage(const AGraphPoint: TDoublePoint): TPoint;
    function ImageToGraph(const APoint: TPoint): TDoublePoint;
    function XGraphToImage(AX: Double): Integer; inline;
    function XImageToGraph(AX: Integer): Double; inline;
    function YGraphToImage(AY: Double): Integer; inline;
    function YImageToGraph(AY: Integer): Double; inline;
    property ScalingValid: Boolean read FScalingValid;

  public
    procedure LockClipRect;
    procedure UnlockClipRect;

  public
    property ActiveToolIndex: Integer read FActiveToolIndex;
    property Broadcaster: TBroadcaster read FBroadcaster;
    property ChartHeight: Integer read GetChartHeight;
    property ChartWidth: Integer read GetChartWidth;
    property ClipRect: TRect read FClipRect;
    property ClipRectBroadcaster: TBroadcaster read FClipRectBroadcaster;
    property CurrentExtent: TDoubleRect read FCurrentExtent;
    property ExtentBroadcaster: TBroadcaster read FExtentBroadcaster;
    property FullExtentBroadcaster: TBroadcaster read FFullExtentBroadcaster;
    property HorAxis: TChartAxis read GetHorAxis;
    property IsZoomed: Boolean read FIsZoomed;
    property LogicalExtent: TDoubleRect read FLogicalExtent write SetLogicalExtent;
    property MinDataSpace: Integer
      read FMinDataSpace write SetMinDataSpace; // default DEF_MIN_DATA_SPACE;
    property OnChartPaint: TChartPaintEvent
      read FOnChartPaint write SetOnChartPaint; experimental;
    property PrevLogicalExtent: TDoubleRect read FPrevLogicalExtent;
    property RenderingParams: TChartRenderingParams
      read GetRenderingParams write SetRenderingParams;
    property SeriesCount: Integer read GetSeriesCount;
    property VertAxis: TChartAxis read GetVertAxis;
    property XGraphMax: Double read FCurrentExtent.b.X;
    property XGraphMin: Double read FCurrentExtent.a.X;
    property YGraphMax: Double read FCurrentExtent.b.Y;
    property YGraphMin: Double read FCurrentExtent.a.Y;

  published
    property AutoFocus: Boolean read FAutoFocus write FAutoFocus default false;
    property AllowPanning: Boolean read FAllowPanning write FAllowPanning default true;
    property AllowZoom: Boolean read FAllowZoom write FAllowZoom default true;
    property AntialiasingMode: TChartAntialiasingMode
      read FAntialiasingMode write SetAntialiasingMode default amDontCare;
    property AxisList: TChartAxisList read FAxisList write SetAxisList;
    property AxisVisible: Boolean read FAxisVisible write SetAxisVisible default true;
    property BackColor: TColor read FBackColor write SetBackColor default clWindow;
    property BottomAxis: TChartAxis index calBottom read GetAxisByAlign write SetAxisByAlign stored false;
    property Depth: TChartDistance read FDepth write SetDepth default 0;
    property ExpandPercentage: Integer
      read FExpandPercentage write SetExpandPercentage default 0;
    property Extent: TChartExtent read FExtent write SetExtent;
    property ExtentSizeLimit: TChartExtent read FExtentSizeLimit write SetExtentSizeLimit;
    property Foot: TChartTitle read FFoot write SetFoot;
    property Frame: TChartPen read FFrame write SetFrame;
    property GUIConnector: TChartGUIConnector
      read FGUIConnector write SetGUIConnector;
    property LeftAxis: TChartAxis index calLeft read GetAxisByAlign write SetAxisByAlign stored false;
    property Legend: TChartLegend read FLegend write SetLegend;
    property Margins: TChartMargins read FMargins write SetMargins;
    property MarginsExternal: TChartMargins
      read FMarginsExternal write SetMarginsExternal;
    property Proportional: Boolean
      read FProportional write SetProportional default false;
    property Series: TChartSeriesList read FSeries;
    property Title: TChartTitle read FTitle write SetTitle;
    property Toolset: TBasicChartToolset read FToolset write SetToolset;

  published
    property OnAfterCustomDrawBackground: TChartAfterCustomDrawEvent
      read FOnAfterCustomDrawBackground write SetOnAfterCustomDrawBackground;
    property OnAfterCustomDrawBackWall: TChartAfterCustomDrawEvent
      read FOnAfterCustomDrawBackWall write SetOnAfterCustomDrawBackWall;
    property OnAfterDraw: TChartDrawEvent read FOnAfterDraw write SetOnAfterDraw;
      deprecated 'Use OnAfterCustomDraw instead';
    property OnAfterDrawBackground: TChartAfterDrawEvent
      read FOnAfterDrawBackground write SetOnAfterDrawBackground;
      deprecated 'Use OnAfterCustomDrawBackground instead';
    property OnAfterDrawBackWall: TChartAfterDrawEvent
      read FOnAfterDrawBackWall write SetOnAfterDrawBackWall;
      deprecated 'Use OnAfterCustomDrawBackWall instead';
    property OnAfterPaint: TChartEvent read FOnAfterPaint write FOnAfterPaint;
    property OnBeforeCustomDrawBackground: TChartBeforeCustomDrawEvent
      read FOnBeforeCustomDrawBackground write SetOnBeforeCustomDrawBackground;
    property OnBeforeDrawBackground: TChartBeforeDrawEvent
      read FOnBeforeDrawBackground write SetOnBeforeDrawBackground;
      deprecated 'Use OnBeforeCustomDrawBackground instead';
    property OnBeforeCustomDrawBackWall: TChartBeforeCustomDrawEvent
      read FOnBeforeCustomDrawBackWall write SetOnBeforeCustomDrawBackwall;
    property OnBeforeDrawBackWall: TChartBeforeDrawEvent
      read FOnBeforeDrawBackWall write SetOnBeforeDrawBackWall;
      deprecated 'Use OnBeforeCustomDrawBackWall instead';
    property OnDrawLegend: TChartDrawLegendEvent
      read FOnDrawLegend write SetOnDrawLegend;
    property OnExtentChanged: TChartEvent
      read FOnExtentChanged write FOnExtentChanged;
    property OnExtentChanging: TChartEvent
      read FOnExtentChanging write FOnExtentChanging;
      deprecated 'Used OnExtentValidate instead';
    property OnExtentValidate: TChartExtentValidateEvent
      read FOnExtentValidate write FOnExtentValidate;
    property OnFullExtentChanged: TChartEvent
      read FOnFullExtentChanged write FOnFullExtentChanged;

  published
    property Align;
    property Anchors;
    property BiDiMode;
    property BorderSpacing;
    property Color default clForm;
    property Constraints;
    property DoubleBuffered;
    property DragCursor;
    property DragMode;
    property Enabled;
    property ParentBiDiMode;
    property ParentColor default false;
    property ParentShowHint;
    property PopupMenu;
    property ShowHint;
    property Visible;

  published
    property OnClick;
    property OnContextPopup;
    property OnDblClick;
    property OnDragDrop;
    property OnDragOver;
    property OnEndDrag;
    property OnMouseDown;
    property OnMouseEnter;
    property OnMouseLeave;
    property OnMouseMove;
    property OnMouseUp;
    property OnResize;
    property OnStartDrag;
  end;

procedure Register;
procedure RegisterSeriesClass(ASeriesClass: TSeriesClass; const ACaption: String); overload;
procedure RegisterSeriesClass(ASeriesClass: TSeriesClass; ACaptionPtr: PStr); overload;

var
  SeriesClassRegistry: TClassRegistry = nil;
  OnInitBuiltinTools: function(AChart: TChart): TBasicChartToolset = nil;

implementation

{$R tagraph.res}

uses
  Clipbrd, Dialogs, GraphMath, LCLProc, LResources, Math, Types,
  TADrawerCanvas, TAGeometry, TAMath, TAStyles;

const
  SScalingNotInitialized = '[%s.%s]: Image-graph scaling not yet initialized.';
  SNestedSetLogicalExtentCall = '%s: Don''t set LogicalExtent in OnExtentValidate handler - modify %s parameter instead.';

function CompareZPosition(AItem1, AItem2: Pointer): Integer;
begin
  Result :=
    TBasicChartSeries(AItem1).ZPosition - TBasicChartSeries(AItem2).ZPosition;
end;

procedure Register;
var
  i: Integer;
  sc: TSeriesClass;
begin
  RegisterComponents(CHART_COMPONENT_IDE_PAGE, [TChart]);
  for i := 0 to SeriesClassRegistry.Count - 1 do begin
    sc := TSeriesClass(SeriesClassRegistry.GetClass(i));
    RegisterClass(sc);
    RegisterNoIcon([sc]);
  end;
end;

procedure RegisterSeriesClass(ASeriesClass: TSeriesClass; const ACaption: String);
begin
  if SeriesClassRegistry.IndexOfClass(ASeriesClass) < 0 then
    SeriesClassRegistry.Add(TClassRegistryItem.Create(ASeriesClass, ACaption));
end;

procedure RegisterSeriesClass(ASeriesClass: TSeriesClass; ACaptionPtr: PStr);
begin
  if SeriesClassRegistry.IndexOfClass(ASeriesClass) < 0 then
    SeriesClassRegistry.Add(TClassRegistryItem.CreateRes(ASeriesClass, ACaptionPtr));
end;

procedure WriteComponentToStream(AStream: TStream; AComponent: TComponent);
var
  writer: TWriter;
  destroyDriver: Boolean = false;
begin
  writer := CreateLRSWriter(AStream, destroyDriver);
  try
    writer.Root := AComponent.Owner;
    writer.WriteComponent(AComponent);
  finally
    if destroyDriver then
      writer.Driver.Free;
    writer.Free;
  end;
end;

{ TBasicChartSeriesEnumerator }

function TBasicChartSeriesEnumerator.GetCurrent: TBasicChartSeries;
begin
  Result := TBasicChartSeries(inherited GetCurrent);
end;

{ TChart }

procedure TChart.AddSeries(ASeries: TBasicChartSeries);
begin
  if ASeries.FChart = Self then exit;
  if ASeries.FChart <> nil then
    ASeries.FChart.DeleteSeries(ASeries);
  Series.FList.Add(ASeries);
  ASeries.FChart := Self;
  ASeries.AfterAdd;
  StyleChanged(ASeries);
end;

procedure TChart.CalculateTransformationCoeffs(const AMargin, AChartMargins: TRect;
  const AMinDataSpace: Integer);
var
  rX, rY: TAxisCoeffHelper;
begin
  rX.Init(
    HorAxis, FClipRect.Left, FClipRect.Right, AMargin.Left, -AMargin.Right,
    AChartMargins.Left, AChartMargins.Right, AMinDataSpace,
    false, @FCurrentExtent.a.X, @FCurrentExtent.b.X);
  rY.Init(
    VertAxis, FClipRect.Bottom, FClipRect.Top, -AMargin.Bottom, AMargin.Top,
    AChartMargins.Bottom, AChartMargins.Top, AMinDataSpace,
    true, @FCurrentExtent.a.Y, @FCurrentExtent.b.Y);

  FScale.X := rX.CalcScale(1);
  FScale.Y := rY.CalcScale(-1);
  if Proportional then begin
    if Abs(FScale.X) > Abs(FScale.Y) then
      FScale.X := Abs(FScale.Y) * Sign(FScale.X)
    else
      FScale.Y := Abs(FScale.X) * Sign(FScale.Y);
  end;
  FOffset.X := rX.CalcOffset(FScale.X);
  FOffset.Y := rY.CalcOffset(FScale.Y);
  FOffsetInt := Point(0, 0);
  FScalingValid := True;
  rX.UpdateMinMax(@XImageToGraph);
  rY.UpdateMinMax(@YImageToGraph);
end;

procedure TChart.Clear(ADrawer: IChartDrawer; const ARect: TRect);
var
  defaultDrawing: Boolean = true;
  ic: IChartTCanvasDrawer;
begin
  ADrawer.PrepareSimplePen(Color);
  ADrawer.SetBrushParams(bsSolid, Color);

  if Assigned(FOnBeforeCustomDrawBackground) then
    OnBeforeCustomDrawBackground(Self, ADrawer, ARect, defaultDrawing)
  else
  if Supports(ADrawer, IChartTCanvasDrawer, ic) and Assigned(OnBeforeDrawBackground) then
    OnBeforeDrawBackground(Self, ic.Canvas, ARect, defaultDrawing);

  if defaultDrawing then
    ADrawer.FillRect(ARect.Left, ARect.Top, ARect.Right, ARect.Bottom);
//    ADrawer.Rectangle(ARect);

  if Assigned(OnAfterCustomDrawBackground) then
    OnAfterCustomDrawBackground(Self, ADrawer, ARect);
  if Supports(ADrawer, IChartTCanvasDrawer, ic) and Assigned(OnAfterDrawBackground) then
    OnAfterDrawBackground(Self, ic.Canvas, ARect);
end;

procedure TChart.ClearSeries;
begin
  FSeries.Clear;
  StyleChanged(Self);
end;

function TChart.ClipRectWithoutFrame(AZPosition: TChartDistance): TRect;
begin
  Result := FClipRect;
  if (AZPosition > 0) or not Frame.EffVisible then exit;
  Result.Left += (Frame.Width + 1) div 2;
  Result.Top += (Frame.Width + 1) div 2;
  Result.Bottom -= Frame.Width div 2;
  Result.Right -= Frame.Width div 2;
end;

function TChart.Clone: TChart;
begin
  Result := Clone(Owner, Parent);
end;

function TChart.Clone(ANewOwner, ANewParent: TComponent): TChart;
var
  ms: TMemoryStream;
  cloned: TComponent = nil;
begin
  ms := TMemoryStream.Create;
  try
    WriteComponentToStream(ms, Self);
    ms.Seek(0, soBeginning);
    ReadComponentFromBinaryStream(
      ms, cloned, @FindComponentClass, ANewOwner, ANewParent, Owner);
    Result := cloned as TChart;
  finally
    ms.Free;
  end;
end;

procedure TChart.CopyToClipboard(AClass: TRasterImageClass);
begin
  with SaveToImage(AClass) do
    try
      SaveToClipboardFormat(RegisterClipboardFormat(MimeType));
    finally
      Free;
    end;
end;

procedure TChart.CopyToClipboardBitmap;
begin
  CopyToClipboard(TBitmap);
end;

constructor TChart.Create(AOwner: TComponent);
const
  DEFAULT_CHART_WIDTH = 300;
  DEFAULT_CHART_HEIGHT = 200;
  DEFAULT_CHART_TITLE = 'TAChart';
  FONT_VERTICAL = 900;
begin
  inherited Create(AOwner);

  FBroadcaster := TBroadcaster.Create;
  FClipRectBroadcaster := TBroadcaster.Create;
  FExtentBroadcaster := TBroadcaster.Create;
  FFullExtentBroadcaster := TBroadcaster.Create;
  FAllowZoom := true;
  FAllowPanning := true;
  FAntialiasingMode := amDontCare;
  FAxisVisible := true;
  FConnectorData.FCanvas := Canvas;
  FDefaultGUIConnector := TChartGUIConnectorCanvas.Create(Self);
  FDefaultGUIConnector.CreateDrawer(FConnectorData);
  FGUIConnectorListener := TListener.Create(@FGUIConnector, @StyleChanged);

  FScale := DoublePoint(1, -1);
  FScalingValid := False;
  FMultiPassScalingNeeded := False;

  Width := DEFAULT_CHART_WIDTH;
  Height := DEFAULT_CHART_HEIGHT;

  FSeries := TChartSeriesList.Create;
  Color := clForm;
  FBackColor := clWindow;
  FIsZoomed := false;
  FLegend := TChartLegend.Create(Self);

  FTitle := TChartTitle.Create(Self);
  FTitle.Alignment := taCenter;
  FTitle.Text.Add(DEFAULT_CHART_TITLE);
  FFoot := TChartTitle.Create(Self);

  FAxisList := TChartAxisList.Create(Self);
  FAxisList.OnVisitSources := @VisitSources;
  with TChartAxis.Create(FAxisList) do begin
    Alignment := calLeft;
    Title.LabelFont.Orientation := FONT_VERTICAL;
  end;
  with TChartAxis.Create(FAxisList) do
    Alignment := calBottom;

  FFrame :=  TChartPen.Create;
  FFrame.OnChange := @StyleChanged;

  FExtent := TChartExtent.Create(Self);
  FExtentSizeLimit := TChartExtent.Create(Self);
  FMargins := TChartMargins.Create(Self);
  FMarginsExternal := TChartMargins.Create(Self);
  FMinDataSpace := DEF_MIN_DATA_SPACE;

  if OnInitBuiltinTools <> nil then
    FBuiltinToolset := OnInitBuiltinTools(Self);
  FActiveToolIndex := -1;

  FLogicalExtent := EmptyExtent;
  FPrevLogicalExtent := EmptyExtent;
  FPrevFullExtent := EmptyExtent;
end;

procedure TChart.DeleteSeries(ASeries: TBasicChartSeries);
var
  i: Integer;
begin
  i := FSeries.FList.IndexOf(ASeries);
  if i < 0 then exit;
  FSeries.FList.Delete(i);
  ASeries.FChart := nil;
  StyleChanged(Self);
end;

destructor TChart.Destroy;
begin
  FreeAndNil(FSeries);

  FreeAndNil(FLegend);
  FreeAndNil(FTitle);
  FreeAndNil(FFoot);
  FreeAndNil(FAxisList);
  FreeAndNil(FFrame);
  FreeAndNil(FGUIConnectorListener);
  FreeAndNil(FExtent);
  FreeAndNil(FExtentSizeLimit);
  FreeAndNil(FMargins);
  FreeAndNil(FMarginsExternal);
  FreeAndNil(FBuiltinToolset);
  FreeAndNil(FBroadcaster);
  FreeAndNil(FClipRectBroadcaster);
  FreeAndNil(FExtentBroadcaster);
  FreeAndNil(FFullExtentBroadcaster);
  FreeAndNil(FDefaultGUIConnector);

  DrawData.DeleteByChart(Self);
  inherited;
end;

procedure TChart.DisableRedrawing;
begin
  FDisableRedrawingCounter += 1;
end;

procedure TChart.DisplaySeries(ADrawer: IChartDrawer);

  procedure OffsetDrawArea(ADX, ADY: Integer); inline;
  begin
    FOffsetInt.X += ADX;
    FOffsetInt.Y += ADY;
    OffsetRect(FClipRect, ADX, ADY);
  end;

  procedure OffsetWithDepth(AZPos, ADepth: Integer);
  begin
    AZPos := ADrawer.Scale(AZPos);
    ADepth := ADrawer.Scale(ADepth);
    OffsetDrawArea(-AZPos, AZPos);
    FClipRect.Right += ADepth;
    FClipRect.Top -= ADepth;
  end;

  procedure DrawOrDeactivate(
    ASeries: TBasicChartSeries; ATransparency: TChartTransparency);
  begin
    try
      ADrawer.SetTransparency(ATransparency);
      ASeries.Draw(ADrawer);
    except
      ASeries.Active := false;
      raise;
    end;
  end;

var
  axisIndex: Integer;
  seriesInZOrder: TChartSeriesList;
  s: TBasicChartSeries;
begin
  axisIndex := 0;
  if SeriesCount > 0 then begin
    seriesInZOrder := TChartSeriesList.Create;
    try
      seriesInZOrder.List.Assign(FSeries.List);
      seriesInZOrder.List.Sort(@CompareZPosition);

      for s in seriesInZOrder do begin
        if not s.Active then continue;
        // Interleave axes with series according to ZPosition.
        if AxisVisible then
          AxisList.Draw(s.ZPosition, axisIndex);
        OffsetWithDepth(Min(s.ZPosition, Depth), Min(s.Depth, Depth));
        ADrawer.ClippingStart(ClipRectWithoutFrame(s.ZPosition));

        try
          with s.Shadow do
            if Visible then begin
              OffsetDrawArea(OffsetX, OffsetY);
              ADrawer.SetMonochromeColor(Color);
              try
                DrawOrDeactivate(s, Transparency);
              finally
                ADrawer.SetMonochromeColor(clTAColor);
                OffsetDrawArea(-OffsetX, -OffsetY);
              end;
            end;
          DrawOrDeactivate(s, s.Transparency);
        finally
          OffsetWithDepth(-Min(s.ZPosition, Depth), -Min(s.Depth, Depth));
          ADrawer.ClippingStop;
        end;
      end;
    finally
      seriesInZOrder.List.Clear; // Avoid freeing series.
      seriesInZOrder.Free;
      ADrawer.SetTransparency(0);
    end;
  end;
  if AxisVisible then
    AxisList.Draw(MaxInt, axisIndex);
end;

procedure TChart.DoContextPopup(MousePos: TPoint; var Handled: Boolean);
begin
  if FDisablePopupMenu then Handled := true;
  inherited;
end;

function TChart.DoMouseWheel(
  AShift: TShiftState; AWheelDelta: Integer; AMousePos: TPoint): Boolean;
const
  EV: array [Boolean] of TChartToolEventId = (
    evidMouseWheelDown, evidMouseWheelUp);
var
  ts: TBasicChartToolset;
begin
  ts := GetToolset;
  if ts = nil then
    result := false
  else
    Result := ts.Dispatch(Self, EV[AWheelDelta > 0], AShift, AMousePos) or
      inherited DoMouseWheel(AShift, AWheelDelta, AMousePos);
end;

{$IFDEF LCLGtk2}
procedure TChart.DoOnResize;
begin
  inherited;
  // FIXME: GTK does not invalidate the control on resizing, do it manually
  Invalidate;
end;
{$ENDIF}

procedure TChart.Draw(ADrawer: IChartDrawer; const ARect: TRect);
var
  NewClipRect: TRect;
  ldd: TChartLegendDrawingData;
  tmpExtent: TDoubleRect;
  tries: Integer;
  s: TBasicChartSeries;
  ts: TBasicChartToolset;
begin
  ADrawer.SetRightToLeft(BiDiMode <> bdLeftToRight);

  NewClipRect := ARect;
  with NewClipRect do begin
    Left += MarginsExternal.Left;
    Top += MarginsExternal.Top;
    Right -= MarginsExternal.Right;
    Bottom -= MarginsExternal.Bottom;
    FTitle.Measure(ADrawer, 1, Left, Right, Top);
    FFoot.Measure(ADrawer, -1, Left, Right, Bottom);
  end;

  ldd.FItems := nil;
  try
    Prepare;

    if Legend.Visible then
      ldd := PrepareLegend(ADrawer, NewClipRect);

    for tries := 3 downto 0 do
    begin
      FClipRect := NewClipRect;

      PrepareAxis(ADrawer);

      if (tries = 0) or (not FMultiPassScalingNeeded) then break;

      // FIsZoomed=true: GetFullExtent() has not been called in Prepare() above
      if FIsZoomed then break;

      // Perform a next pass of extent calculation
      tmpExtent := GetFullExtent;
      // Converged successfully if next pass has not changed the extent --> break
      if tmpExtent = FLogicalExtent then break;                                               

      // As in the Prepare() call above
      FLogicalExtent := tmpExtent;
      FCurrentExtent := FLogicalExtent;
    end;

    if Legend.Visible and not Legend.UseSidebar then
      Legend.Prepare(ldd, FClipRect);

    // Avoid jitter of chart area while dragging with PanDragTool.
    if FClipRectLock > 0 then
      FClipRect := FSavedClipRect;

    if (FPrevLogicalExtent <> FLogicalExtent) and Assigned(OnExtentChanging) then
      OnExtentChanging(Self);

    ADrawer.DrawingBegin(ARect);
    ADrawer.SetAntialiasingMode(AntialiasingMode);
    Clear(ADrawer, ARect);
    FTitle.Draw(ADrawer);
    FFoot.Draw(ADrawer);
    DrawBackWall(ADrawer);
    DisplaySeries(ADrawer);
    if Legend.Visible then begin
      if Assigned(FOnDrawLegend) then
        FOnDrawlegend(Self, ldd.FDrawer, ldd.FItems, ldd.FItemSize, ldd.FBounds,
          ldd.FColCount, ldd.FRowCount)
      else
        Legend.Draw(ldd);
    end;
  finally
    ldd.FItems.Free;
  end;
  ts := GetToolset;
  if ts <> nil then ts.Draw(Self, ADrawer);

  for s in Series do
    s.AfterDraw;

  if Assigned(OnAfterDraw) then
    OnAfterDraw(Self, ADrawer);
  ADrawer.DrawingEnd;

  tmpExtent := GetFullExtent;
  if FPrevFullExtent <> tmpExtent then begin
    FFullExtentBroadcaster.Broadcast(Self);
    if Assigned(OnFullExtentChanged) then
      OnFullExtentChanged(Self);
    FPrevFullExtent := tmpExtent;
  end;

  if FPrevLogicalExtent <> FLogicalExtent then begin
    FExtentBroadcaster.Broadcast(Self);
    if Assigned(OnExtentChanged) then
      OnExtentChanged(Self);
    FPrevLogicalExtent := FLogicalExtent;
  end;

  if FClipRect <> FOldClipRect then
  begin
    FClipRectBroadcaster.Broadcast(Self);
    FOldClipRect := FClipRect;
  end;

  // Undo changes made by the drawer (mainly for printing). The user may print
  // something else after the chart and, for example, would not expect the font
  // to be rotated (Fix for issue #0027163) or the pen to be in xor mode.
  ADrawer.ResetFont;
  ADrawer.SetXor(false);
  ADrawer.PrepareSimplePen(clBlack);     // resets canvas pen mode to pmCopy
  ADrawer.SetPenParams(psSolid, clDefault);
  ADrawer.SetBrushParams(bsSolid, clWhite);
  ADrawer.SetAntialiasingMode(amDontCare);
end;

procedure TChart.DrawBackWall(ADrawer: IChartDrawer);
var
  defaultDrawing: Boolean = true;
  ic: IChartTCanvasDrawer;
  scaled_depth: Integer;
  clr: TColor;
begin
  if Assigned(OnBeforeCustomDrawBackWall) then
    OnBeforeCustomDrawBackWall(self, ADrawer, FClipRect, defaultDrawing)
  else
  if Supports(ADrawer, IChartTCanvasDrawer, ic) and Assigned(OnBeforeDrawBackWall) then
    OnBeforeDrawBackWall(Self, ic.Canvas, FClipRect, defaultDrawing);

  if defaultDrawing then
    with ADrawer do begin
      if FFrame.Visible then
      begin
        Pen := FFrame;
        if FFrame.Color = clDefault then
          SetPenColor(GetDefaultColor(dctFont));
      end
      else
        SetPenParams(psClear, clTAColor);
      if BackColor = clDefault then
        clr := GetDefaultColor(dctBrush)
      else
        clr := BackColor;
      SetBrushParams(bsSolid, clr);
      with FClipRect do
        Rectangle(Left, Top, Right + 1, Bottom + 1);
    end;

  if Assigned(OnAfterCustomDrawBackWall) then
    OnAfterCustomDrawBackwall(Self, ADrawer, FClipRect);
  if Supports(ADrawer, IChartTCanvasDrawer, ic) and Assigned(OnAfterDrawBackWall) then
    OnAfterDrawBackWall(Self, ic.Canvas, FClipRect);

  // Z axis
  if (Depth > 0) and FFrame.Visible then begin
    scaled_depth := ADrawer.Scale(Depth);
    ADrawer.Pen := FFrame;
    with FClipRect do
      ADrawer.Line(Left, Bottom, Left - scaled_depth, Bottom + scaled_depth);
  end;
end;

procedure TChart.DrawLegendOn(ACanvas: TCanvas; var ARect: TRect);
var
  ldd: TChartLegendDrawingData;
begin
  ldd := PrepareLegend(TCanvasDrawer.Create(ACanvas), ARect);
  try
    Legend.Draw(ldd);
  finally
    ldd.FItems.Free;
  end;
end;

procedure TChart.DrawLineHoriz(ADrawer: IChartDrawer; AY: Integer);
begin
  if (FClipRect.Top < AY) and (AY < FClipRect.Bottom) then
    ADrawer.Line(FClipRect.Left, AY, FClipRect.Right, AY);
end;

procedure TChart.DrawLineVert(ADrawer: IChartDrawer; AX: Integer);
begin
  if (FClipRect.Left < AX) and (AX < FClipRect.Right) then
    ADrawer.Line(AX, FClipRect.Top, AX, FClipRect.Bottom);
end;

function TChart.EffectiveGUIConnector: TChartGUIConnector;
begin
  Result := TChartGUIConnector(
    IfThen(FGUIConnector = nil, FDefaultGUIConnector, FGUIConnector));
end;

procedure TChart.EnableRedrawing;
begin
  FDisableRedrawingCounter -= 1;
end;

procedure TChart.EraseBackground(DC: HDC);
begin
  // do not erase, since we will paint over it anyway
  Unused(DC);
end;

procedure TChart.FindComponentClass(
  AReader: TReader; const AClassName: String; var AClass: TComponentClass);
var
  i: Integer;
begin
  Unused(AReader);
  if AClassName = ClassName then begin
    AClass := TChart;
    exit;
  end;
  for i := 0 to SeriesClassRegistry.Count - 1 do begin
    AClass := TSeriesClass(SeriesClassRegistry.GetClass(i));
    if AClass.ClassNameIs(AClassName) then exit;
  end;
  AClass := nil;
end;

procedure TChart.GetAllSeriesAxisLimits(AAxis: TChartAxis; out AMin, AMax: Double);
var
  interval: TDoubleInterval;
begin
  interval := GetAxisBounds(AAxis);
  AMin := interval.FStart;
  AMax := interval.FEnd;
end;

function TChart.GetAxisBounds(AAxis: TChartAxis): TDoubleInterval;
var
  s: TBasicChartSeries;
  mn, mx: Double;
begin
  Result.FStart := SafeInfinity;
  Result.FEnd := NegInfinity;
  for s in Series do
    if s.Active and s.GetAxisBounds(AAxis, mn, mx) then begin
      Result.FStart := Min(Result.FStart, mn);
      Result.FEnd := Max(Result.FEnd, mx);
    end;
end;

function TChart.GetAxisByAlign(AAlign: TChartAxisAlignment): TChartAxis;
begin
  if (BidiMode <> bdLeftToRight) then
    case AAlign of
      calLeft: AAlign := calRight;
      calRight: AAlign := calLeft;
    end;
  Result := FAxisList.GetAxisByAlign(AAlign);
end;

function TChart.GetChartHeight: Integer;
begin
  Result := FClipRect.Bottom - FClipRect.Top;
end;

function TChart.GetChartWidth: Integer;
begin
  Result := FClipRect.Right - FClipRect.Left;
end;

procedure TChart.GetChildren(AProc: TGetChildProc; ARoot: TComponent);
var
  s: TBasicChartSeries;
begin
  // FIXME: This is a workaround for issue #16035
  if FSeries = nil then exit;
  for s in Series do
    if s.Owner = ARoot then
      AProc(s);
end;

function TChart.GetFullExtent: TDoubleRect;

  procedure SetBounds(
    var ALo, AHi: Double; AMin, AMax: Double; AUseMin, AUseMax: Boolean);
  const
    DEFAULT_WIDTH = 2.0;
  begin
    if AUseMin then ALo := AMin;
    if AUseMax then AHi := AMax;
    case CASE_OF_TWO[IsInfinite(ALo), IsInfinite(AHi)] of
      cotNone: begin // Both high and low boundary defined
        if ALo = AHi then begin
          ALo -= DEFAULT_WIDTH / 2;
          AHi += DEFAULT_WIDTH / 2;
        end
        else begin
          EnsureOrder(ALo, AHi);
          // Expand view slightly to avoid data points on the chart edge.
          ExpandRange(ALo, AHi, ExpandPercentage * PERCENT);
        end;
      end;
      cotFirst: ALo := AHi - DEFAULT_WIDTH;
      cotSecond: AHi := ALo + DEFAULT_WIDTH;
      cotBoth: begin // No boundaries defined, take some arbitrary values
        ALo := -DEFAULT_WIDTH / 2;
        AHi := DEFAULT_WIDTH / 2;
      end;
    end;
  end;

  procedure JoinBounds(const ABounds: TDoubleRect);
  begin
    with Result do begin
      a.X := Min(a.X, ABounds.a.X);
      b.X := Max(b.X, ABounds.b.X);
      a.Y := Min(a.Y, ABounds.a.Y);
      b.Y := Max(b.Y, ABounds.b.Y);
    end;
  end;

var
  axisBounds: TDoubleRect;
  s: TBasicChartSeries;
  a: TChartAxis;
begin
  //Extent.CheckBoundsOrder;
  // wp: avoid exception in IDE if min > max, but silently bring min/max
  // into correct order

  for a in AxisList do
    if a.Transformations <> nil then
      a.Transformations.ClearBounds;

  Result := EmptyExtent;
  for s in Series do begin
    try
      JoinBounds(s.GetGraphBounds);
    except
      s.Active := false;
      raise;
    end;
  end;
  for a in AxisList do begin
    axisBounds := EmptyExtent;
    if a.Range.UseMin then
      TDoublePointBoolArr(axisBounds.a)[a.IsVertical] :=
        a.GetTransform.AxisToGraph(a.Range.Min);
    if a.Range.UseMax then
      TDoublePointBoolArr(axisBounds.b)[a.IsVertical] :=
        a.GetTransform.AxisToGraph(a.Range.Max);
    JoinBounds(axisBounds);
  end;
  with Extent do begin
    SetBounds(Result.a.X, Result.b.X, XMin, XMax, UseXMin, UseXMax);
    SetBounds(Result.a.Y, Result.b.Y, YMin, YMax, UseYMin, UseYMax);
  end;
end;

function TChart.GetHorAxis: TChartAxis;
begin
  Result := BottomAxis;
  if Result = nil then Result := GetAxisByAlign(calTop);
end;

function TChart.GetLegendItems(AIncludeHidden: Boolean): TChartLegendItems;
var
  s: TBasicChartSeries;
begin
  Result := TChartLegendItems.Create;
  try
    for s in Series do
      if AIncludeHidden or (s.Active and s.GetShowInLegend) then
        try
          s.GetLegendItemsBasic(Result);
        except
          s.SetShowInLegend(AIncludeHidden);
          raise;
        end;
  except
    FreeAndNil(Result);
    raise;
  end;
end;

function TChart.GetMargins(ADrawer: IChartDrawer): TRect;
var
  i: Integer;
  a: TRectArray absolute Result;
  s: TBasicChartSeries;
begin
  Result := ZeroRect;
  for s in Series do
    if s.Active then
      s.UpdateMargins(ADrawer, Result);
  for i := Low(a) to High(a) do
    a[i] := a[i] + ADrawer.Scale(TRectArray(Margins.Data)[i]);
end;

function TChart.GetRenderingParams: TChartRenderingParams;
begin
  Result.FScale := FScale;
  Result.FOffset := FOffset;
  Result.FClipRect := FClipRect;
  Result.FLogicalExtent := FLogicalExtent;
  Result.FPrevLogicalExtent := FPrevLogicalExtent;
  Result.FIsZoomed := FIsZoomed;
end;

function TChart.GetSeriesCount: Integer;
begin
  Result := FSeries.FList.Count;
end;

function TChart.GetToolset: TBasicChartToolset;
begin
  Result := FToolset;
  if Result = nil then
    Result := FBuiltinToolset;
end;

function TChart.GetVertAxis: TChartAxis;
begin
  Result := LeftAxis;
  if Result = nil then Result := GetAxisByAlign(calRight);
end;

function TChart.GraphToImage(const AGraphPoint: TDoublePoint): TPoint;
begin
  Result := Point(XGraphToImage(AGraphPoint.X), YGraphToImage(AGraphPoint.Y));
end;

function TChart.ImageToGraph(const APoint: TPoint): TDoublePoint;
begin
  Result.X := XImageToGraph(APoint.X);
  Result.Y := YImageToGraph(APoint.Y);
end;

function TChart.IsPointInViewPort(const AP: TDoublePoint): Boolean;
begin
  Result :=
    not IsNan(AP) and
    SafeInRangeWithBounds(AP.X, XGraphMin, XGraphMax) and
    SafeInRangeWithBounds(AP.Y, YGraphMin, YGraphMax);
end;

procedure TChart.KeyDownAfterInterface(var AKey: Word; AShift: TShiftState);
var
  p: TPoint;
  ts: TBasicChartToolset;
begin
  p := ScreenToClient(Mouse.CursorPos);
  ts := GetToolset;
  if (ts <> nil) and ts.Dispatch(Self, evidKeyDown, AShift, p) then exit;
  inherited;
end;

procedure TChart.KeyUpAfterInterface(var AKey: Word; AShift: TShiftState);
var
  p: TPoint;
  ts: TBasicChartToolset;
begin
  p := ScreenToClient(Mouse.CursorPos);
  // To find a tool, toolset must see the shift state with the key still down.
  case AKey of
    VK_CONTROL: AShift += [ssCtrl];
    VK_MENU: AShift += [ssAlt];
    VK_SHIFT: AShift += [ssShift];
  end;
  ts := GetToolset;
  if (ts <> nil) and ts.Dispatch(Self, evidKeyUp, AShift, p) then exit;
  inherited;
end;

procedure TChart.LockClipRect;
begin
  FSavedClipRect := FClipRect;
  inc(FClipRectLock);
end;

procedure TChart.MouseDown(
  Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  ts: TBasicChartToolset;
begin
  ts := GetToolset;
  if (ts <> nil) and ts.Dispatch(Self, evidMouseDown, Shift, Point(X, Y)) then
    exit;
  inherited;
end;

procedure TChart.MouseMove(Shift: TShiftState; X, Y: Integer);
var
  ts: TBasicChartToolset;
begin
  if AutoFocus then
    SetFocus;
  ts := GetToolset;
  if (ts <> nil) and ts.Dispatch(Self, evidMouseMove, Shift, Point(X, Y)) then
    exit;
  inherited;
end;

procedure TChart.MouseUp(
  AButton: TMouseButton; AShift: TShiftState; AX, AY: Integer);
const
  MOUSE_BUTTON_TO_SHIFT: array [TMouseButton] of TShiftStateEnum = (
    ssLeft, ssRight, ssMiddle, ssExtra1, ssExtra2);
var
  ts: TBasicChartToolset;
begin
  // To find a tool, toolset must see the shift state with the button still down.
  Include(AShift, MOUSE_BUTTON_TO_SHIFT[AButton]);
  ts := GetToolset;
  if (ts <> nil) and ts.Dispatch(Self, evidMouseUp, AShift, Point(AX, AY)) then
    exit;
  inherited;
end;

procedure TChart.Notification(AComponent: TComponent; AOperation: TOperation);
var
  ax: TChartAxis;
begin
  if (AOperation = opRemove) and (AComponent = Toolset) then
    FToolset := nil
  else if (AOperation = opRemove) and (AComponent = GUIConnector) then
    GUIConnector := nil
  else if (AOperation = opRemove) and (AComponent is TChartStyles) then begin
    for ax in FAxisList do
      if ax.Marks.Stripes = AComponent then
        ax.Marks.Stripes := nil;
  end;

  inherited Notification(AComponent, AOperation);
end;

{ Notifies the chart of something which is specified by ACommand and both
  parameters. Needed for example by the axis to query the extent covered by
  all series using this axis (cannot be called directly because TAChartAxis
  does not "use" TACustomSeries. }

procedure TChart.Notify(ACommand: Integer; AParam1, AParam2: Pointer; var AData);
begin
  UnUsed(AParam2);
  case ACommand of
    CMD_QUERY_SERIESEXTENT:
      TDoubleInterval(AData) := GetAxisBounds(TChartAxis(AParam1));
  end;
end;


procedure TChart.Paint;
var
  defaultDrawing: Boolean = true;
begin
  FConnectorData.FBounds := GetClientRect;
  {$PUSH}
  {$WARNINGS OFF}
  if Assigned(OnChartPaint) then
    OnChartPaint(Self, FConnectorData.FBounds, defaultDrawing);
  {$POP}
  if defaultDrawing then
    with EffectiveGUIConnector do begin
      SetBounds(FConnectorData);
      Draw(Drawer, FConnectorData.FDrawerBounds);
      EffectiveGUIConnector.Display(FConnectorData);
    end;
  if Assigned(OnAfterPaint) then
    OnAfterPaint(Self);
end;

procedure TChart.PaintOnAuxCanvas(ACanvas: TCanvas; ARect: TRect);
var
  rp: TChartRenderingParams;
begin
  rp := RenderingParams;
  ExtentBroadcaster.Locked := true;
  try
    FIsZoomed := false;
    PaintOnCanvas(ACanvas, ARect);
  finally
    RenderingParams := rp;
    ExtentBroadcaster.Locked := false;
  end;
end;

procedure TChart.PaintOnCanvas(ACanvas: TCanvas; ARect: TRect);
begin
  Draw(TCanvasDrawer.Create(ACanvas), ARect);
end;

procedure TChart.PrepareAxis(ADrawer: IChartDrawer);
var
  axisMargin: TChartAxisMargins;
  aa: TChartAxisAlignment;
  cr: TRect;
  tries: Integer;
  prevExt: TDoubleRect;
  axis: TChartAxis;
  scDepth: Integer;
  scSeriesMargins: TRect;
  scChartMargins: TRect;
  scMinDataSpace: Integer;
begin
  scDepth := ADrawer.Scale(Depth);
  scSeriesMargins := GetMargins(ADrawer);
  scChartMargins.Left := ADrawer.Scale(Margins.Left);
  scChartMargins.Right := ADrawer.Scale(Margins.Right);
  scChartMargins.Top := ADrawer.Scale(Margins.Top);
  scChartMargins.Bottom := ADrawer.Scale(Margins.Bottom);
  scMinDataSpace := ADrawer.Scale(FMinDataSpace);

  if not AxisVisible then begin
    FClipRect.Left += scDepth;
    FClipRect.Bottom -= scDepth;
    CalculateTransformationCoeffs(scSeriesMargins, scChartMargins, scMinDataSpace);
    exit;
  end;

  AxisList.PrepareGroups;
  for axis in AxisList do
    axis.PrepareHelper(ADrawer, Self, @FClipRect, scDepth);

  // There is a cyclic dependency: extent -> visible marks -> margins.
  // We recalculate them iteratively hoping that the process converges.
  CalculateTransformationCoeffs(scSeriesMargins, scChartMargins, scMinDataSpace);
  cr := FClipRect;
  for tries := 1 to 10 do begin
    axisMargin := AxisList.Measure(CurrentExtent, FClipRect, scDepth);
    axisMargin[calLeft] := Max(axisMargin[calLeft], scDepth);
    axisMargin[calBottom] := Max(axisMargin[calBottom], scDepth);
    FClipRect := cr;
    for aa := Low(aa) to High(aa) do
      SideByAlignment(FClipRect, aa, -axisMargin[aa]);
    prevExt := FCurrentExtent;
    FCurrentExtent := FLogicalExtent;
    CalculateTransformationCoeffs(scSeriesMargins, scChartMargins, scMinDataSpace);
    if prevExt = FCurrentExtent then break;
    prevExt := FCurrentExtent;
  end;

  AxisList.Prepare(FClipRect);
end;

procedure TChart.Prepare;
var
  a: TChartAxis;
  s: TBasicChartSeries;
begin
  FScalingValid := False;
  FMultiPassScalingNeeded := False;

  for a in AxisList do
    if a.Transformations <> nil then
      a.Transformations.SetChart(Self);
  for s in Series do
    s.BeforeDraw;

  if not FIsZoomed then
    FLogicalExtent := GetFullExtent;
  FCurrentExtent := FLogicalExtent;
end;

function TChart.PrepareLegend(
  ADrawer: IChartDrawer; var AClipRect: TRect): TChartLegendDrawingData;
begin
  Result.FDrawer := ADrawer;
  Result.FItems := GetLegendItems;
  try
    Legend.SortItemsByOrder(Result.FItems);
    Legend.AddGroups(Result.FItems);
    Legend.Prepare(Result, AClipRect);
  except
    FreeAndNil(Result.FItems);
    raise;
  end;
end;

procedure TChart.RemoveSeries(ASeries: TBasicChartSeries);
begin
  DeleteSeries(ASeries);
end;

procedure TChart.SaveToBitmapFile(const AFileName: String);
begin
  SaveToFile(TBitmap, AFileName);
end;

procedure TChart.SaveToFile(AClass: TRasterImageClass; AFileName: String);
begin
  with SaveToImage(AClass) do
    try
      SaveToFile(AFileName);
    finally
      Free;
    end;
end;

function TChart.SaveToImage(AClass: TRasterImageClass): TRasterImage;
begin
  Result := AClass.Create;
  try
    Result.Width := Width;
    Result.Height := Height;
    PaintOnCanvas(Result.Canvas, Rect(0, 0, Width, Height));
  except
    Result.Free;
    raise;
  end;
end;

procedure TChart.SetAntialiasingMode(AValue: TChartAntialiasingMode);
begin
  if FAntialiasingMode = AValue then exit;
  FAntialiasingMode := AValue;
  StyleChanged(Self);
end;

procedure TChart.SetAxisByAlign(AAlign: TChartAxisAlignment; AValue: TChartAxis);
begin
  FAxisList.SetAxisByAlign(AAlign, AValue);
  StyleChanged(AValue);
end;

procedure TChart.SetAxisList(AValue: TChartAxisList);
begin
  FAxisList.Assign(AValue);
  StyleChanged(Self);
end;

procedure TChart.SetAxisVisible(Value: Boolean);
begin
  FAxisVisible := Value;
  StyleChanged(Self);
end;

procedure TChart.SetBackColor(AValue: TColor);
begin
  FBackColor:= AValue;
  StyleChanged(Self);
end;

procedure TChart.SetBiDiMode(AValue: TBiDiMode);
begin
  if AValue = BidiMode then
    exit;
  inherited SetBiDiMode(AValue);
  if not (csLoading in ComponentState) then begin
    AxisList.UpdateBidiMode;
    Legend.UpdateBidiMode;
    Title.UpdateBidiMode;
    Foot.UpdateBidiMode;
    Series.UpdateBiDiMode;
  end;
end;

procedure TChart.SetChildOrder(Child: TComponent; Order: Integer);
var
  i: Integer;
begin
  i := Series.FList.IndexOf(Child);
  if i >= 0 then
    Series.FList.Move(i, Order);
end;

procedure TChart.SetDepth(AValue: TChartDistance);
begin
  if FDepth = AValue then exit;
  FDepth := AValue;
  StyleChanged(Self);
end;

procedure TChart.SetExpandPercentage(AValue: Integer);
begin
  if FExpandPercentage = AValue then exit;
  FExpandPercentage := AValue;
  StyleChanged(Self);
end;

procedure TChart.SetExtent(AValue: TChartExtent);
begin
  FExtent.Assign(AValue);
  StyleChanged(Self);
end;

procedure TChart.SetExtentSizeLimit(AValue: TChartExtent);
begin
  if FExtentSizeLimit = AValue then exit;
  FExtentSizeLimit.Assign(AValue);
  StyleChanged(Self);
end;

procedure TChart.SetFoot(Value: TChartTitle);
begin
  FFoot.Assign(Value);
  StyleChanged(Self);
end;

procedure TChart.SetFrame(Value: TChartPen);
begin
  FFrame.Assign(Value);
  StyleChanged(Self);
end;

procedure TChart.SetGUIConnector(AValue: TChartGUIConnector);
begin
  if FGUIConnector = AValue then exit;
  if FGUIConnector <> nil then
    RemoveFreeNotification(FGUIConnector);
  if FGUIConnectorListener.IsListening then
    FGUIConnector.Broadcaster.Unsubscribe(FGUIConnectorListener);
  FGUIConnector := AValue;
  if FGUIConnector <> nil then begin
    FGUIConnector.Broadcaster.Subscribe(FGUIConnectorListener);
    FreeNotification(FGUIConnector);
  end;
  EffectiveGUIConnector.CreateDrawer(FConnectorData);
  StyleChanged(Self);
end;

procedure TChart.SetLegend(Value: TChartLegend);
begin
  FLegend.Assign(Value);
  StyleChanged(Self);
end;

procedure TChart.SetLogicalExtent(AValue: TDoubleRect);
var
  AllowChange: Boolean;
  w, h: Double;
begin
  if FSetLogicalExtentCounter <> 0 then
    raise EChartError.CreateFmt(SNestedSetLogicalExtentCall, [NameOrClassName(Self), 'ALogicalExtent']);

  if Assigned(OnExtentValidate) then begin
    AllowChange := true;
    Inc(FSetLogicalExtentCounter);
    try
      OnExtentValidate(Self, AValue, AllowChange);
    finally
      Dec(FSetLogicalExtentCounter);
    end;
    if not AllowChange then exit;
  end;
  if FLogicalExtent = AValue then exit;
  w := Abs(AValue.a.X - AValue.b.X);
  h := Abs(AValue.a.Y - AValue.b.Y);
  with ExtentSizeLimit do
    if
      UseXMin and (w < XMin) or UseXMax and (w > XMax) or
      UseYMin and (h < YMin) or UseYMax and (h > YMax)
    then
      exit;
  FLogicalExtent := AValue;
  FIsZoomed := true;
  StyleChanged(Self);
end;

procedure TChart.SetMargins(AValue: TChartMargins);
begin
  FMargins.Assign(AValue);
  StyleChanged(Self);
end;

procedure TChart.SetMarginsExternal(AValue: TChartMargins);
begin
  if FMarginsExternal = AValue then exit;
  FMarginsExternal.Assign(AValue);
  StyleChanged(Self);
end;

procedure TChart.SetMinDataSpace(const AValue: Integer);
begin
  if FMinDataSpace = abs(AValue) then exit;
  FMinDataSpace := abs(AValue);
  StyleChanged(Self);
end;

procedure TChart.SetName(const AValue: TComponentName);
var
  oldName: String;
begin
  if Name = AValue then exit;
  oldName := Name;
  inherited SetName(AValue);
  if csDesigning in ComponentState then
    Series.List.ChangeNamePrefix(oldName, AValue);
end;

procedure TChart.SetOnAfterDraw(AValue: TChartDrawEvent);
begin
  if TMethod(FOnAfterDraw) = TMethod(AValue) then exit;
  FOnAfterDraw := AValue;
  StyleChanged(Self);
end;

procedure TChart.SetOnAfterCustomDrawBackground(AValue: TChartAfterCustomDrawEvent);
begin
  if TMethod(FOnAfterCustomDrawBackground) = TMethod(AValue) then exit;
  FOnAfterCustomDrawBackground := AValue;
  StyleChanged(Self);
end;

procedure TChart.SetOnAfterCustomDrawBackWall(AValue: TChartAfterCustomDrawEvent);
begin
  if TMethod(FOnAfterCustomDrawBackWall) = TMethod(AValue) then exit;
  FOnAfterCustomDrawBackWall := AValue;
  StyleChanged(Self);
end;

procedure TChart.SetOnAfterDrawBackground(AValue: TChartAfterDrawEvent);
begin
  if TMethod(FOnAfterDrawBackground) = TMethod(AValue) then exit;
  FOnAfterDrawBackground := AValue;
  StyleChanged(Self);
end;

procedure TChart.SetOnAfterDrawBackWall(AValue: TChartAfterDrawEvent);
begin
  if TMethod(FOnAfterDrawBackWall) = TMethod(AValue) then exit;
  FOnAfterDrawBackWall := AValue;
  StyleChanged(Self);
end;

procedure TChart.SetOnBeforeCustomDrawBackground(AValue: TChartBeforeCustomDrawEvent);
begin
  if TMethod(FOnBeforeCustomDrawBackground) = TMethod(AValue) then exit;
  FOnBeforeCustomDrawBackground := AValue;
  StyleChanged(Self);
end;

procedure TChart.SetOnBeforeCustomDrawBackWall(AValue: TChartBeforeCustomDrawEvent);
begin
  if TMethod(FOnBeforeCustomDrawBackWall) = TMethod(AValue) then exit;
  FOnBeforeCustomDrawBackWall := AValue;
  StyleChanged(Self);
end;

procedure TChart.SetOnBeforeDrawBackground(AValue: TChartBeforeDrawEvent);
begin
  if TMethod(FOnBeforeDrawBackground) = TMethod(AValue) then exit;
  FOnBeforeDrawBackground := AValue;
  StyleChanged(Self);
end;

procedure TChart.SetOnBeforeDrawBackWall(AValue: TChartBeforeDrawEvent);
begin
  if TMethod(FOnBeforeDrawBackWall) = TMethod(AValue) then exit;
  FOnBeforeDrawBackWall := AValue;
  StyleChanged(Self);
end;

procedure TChart.SetOnChartPaint(AValue: TChartPaintEvent);
begin
  if TMethod(FOnChartPaint) = TMethod(AValue) then exit;
  FOnChartPaint := AValue;
  StyleChanged(Self);
end;

procedure TChart.SetOnDrawLegend(AValue: TChartDrawLegendEvent);
begin
  if TMethod(FOnDrawLegend) = TMethod(AValue) then exit;
  FOnDrawLegend := AValue;
  StyleChanged(self);
end;

procedure TChart.SetProportional(AValue: Boolean);
begin
  if FProportional = AValue then exit;
  FProportional := AValue;
  StyleChanged(Self);
end;

procedure TChart.SetRenderingParams(AValue: TChartRenderingParams);
begin
  FScale := AValue.FScale;
  FOffset := AValue.FOffset;
  FClipRect := AValue.FClipRect;
  FLogicalExtent := AValue.FLogicalExtent;
  FPrevLogicalExtent := AValue.FPrevLogicalExtent;
  FIsZoomed := AValue.FIsZoomed;
end;

procedure TChart.SetTitle(Value: TChartTitle);
begin
  FTitle.Assign(Value);
  StyleChanged(Self);
end;

procedure TChart.SetToolset(AValue: TBasicChartToolset);
begin
  if FToolset = AValue then exit;
  if FToolset <> nil then
    RemoveFreeNotification(FToolset);
  FToolset := AValue;
  FActiveToolIndex := -1;
  if FToolset <> nil then
    FreeNotification(FToolset);
end;

procedure TChart.StyleChanged(Sender: TObject);
begin
  if FDisableRedrawingCounter > 0 then exit;
  if Sender is TChartExtent then
    ZoomFull;
  Invalidate;
  Broadcaster.Broadcast(Sender);
end;

procedure TChart.UnlockCliprect;
begin
  dec(FClipRectLock);
  if FClipRectLock = 0 then Invalidate;
end;

function TChart.UsesBuiltinToolset: Boolean;
begin
  Result := (GetToolset = FBuiltinToolset);
end;

procedure TChart.VisitSources(
  AVisitor: TChartOnSourceVisitor; AAxis: TChartAxis; var AData);
var
  s: TBasicChartSeries;
begin
  for s in Series do
    if s.Active then
      s.VisitSources(AVisitor, AAxis, AData);
end;

function TChart.XGraphToImage(AX: Double): Integer;
begin
  {$IFDEF CHECK_VALID_SCALING}
  if not FScalingValid then
    raise EChartError.CreateFmt(SScalingNotInitialized, [NameOrClassName(self), 'XGraphToImage']);
  {$ENDIF}
  Result := ImgRoundChecked(FScale.X * AX + FOffset.X) + FOffsetInt.X;
end;

function TChart.XImageToGraph(AX: Integer): Double;
begin
  {$IFDEF CHECK_VALID_SCALING}
  if not FScalingValid then
    raise EChartError.CreateFmt(SScalingNotInitialized, [NameOrClassName(self), 'XImageToGraph']);
  {$ENDIF}
  Result := ((AX - FOffsetInt.X) - FOffset.X) / FScale.X;
end;

function TChart.YGraphToImage(AY: Double): Integer;
begin
  {$IFDEF CHECK_VALID_SCALING}
  if not FScalingValid then
    raise EChartError.CreateFmt(SScalingNotInitialized, [NameOrClassName(self), 'YGraphToImage']);
  {$ENDIF}
  Result := ImgRoundChecked(FScale.Y * AY + FOffset.Y) + FOffsetInt.Y;
end;

function TChart.YImageToGraph(AY: Integer): Double;
begin
  {$IFDEF CHECK_VALID_SCALING}
  if not FScalingValid then
    raise EChartError.CreateFmt(SScalingNotInitialized, [NameOrClassName(self), 'YImageToGraph']);
  {$ENDIF}
  Result := ((AY - FOffsetInt.Y) - FOffset.Y) / FScale.Y;
end;

procedure TChart.RequestMultiPassScaling;
begin
  FMultiPassScalingNeeded := True;
end;

procedure TChart.ZoomFull(AImmediateRecalc: Boolean);
begin
  if AImmediateRecalc then
    FLogicalExtent := GetFullExtent;
  if not FIsZoomed then exit;
  FIsZoomed := false;
  Invalidate;
end;

{ TBasicChartSeries }

procedure TBasicChartSeries.AfterDraw;
begin
  // empty
end;

procedure TBasicChartSeries.Assign(Source: TPersistent);
begin
  if Source is TBasicChartSeries then
    with TBasicChartSeries(Source) do begin
      Self.FActive := FActive;
      Self.FDepth := FDepth;
      Self.FZPosition := FZPosition;
    end;
end;

function TBasicChartSeries.AxisToGraphX(AX: Double): Double;
begin
  Result := AX;
end;

function TBasicChartSeries.AxisToGraphY(AY: Double): Double;
begin
  Result := AY;
end;

procedure TBasicChartSeries.BeforeDraw;
begin
  // empty
end;

destructor TBasicChartSeries.Destroy;
begin
  if FChart <> nil then
    FChart.DeleteSeries(Self);
  inherited;
end;

function TBasicChartSeries.GraphToAxisX(AX: Double): Double;
begin
  Result := AX;
end;

function TBasicChartSeries.GraphToAxisY(AY: Double): Double;
begin
  Result := AY;
end;

procedure TBasicChartSeries.MovePoint(
  var AIndex: Integer; const ANewPos: TDoublePoint);
begin
  Unused(AIndex, ANewPos)
end;

procedure TBasicChartSeries.MovePoint(
  var AIndex: Integer; const ANewPos: TPoint);
begin
  MovePoint(AIndex, FChart.ImageToGraph(ANewPos));
end;

procedure TBasicChartSeries.MovePointEx(
  var AIndex: Integer; AXIndex, AYIndex: Integer; const ANewPos: TDoublePoint);
begin
  Unused(AXIndex, AYIndex);
  MovePoint(AIndex, ANewPos);
end;

function TBasicChartSeries.RequestValidChartScaling: Boolean;
begin
  Result := false;
  if not Assigned(FChart) then exit;

  // We request a valid scaling from FChart. Scaling is not initialized during
  // the first phase of scaling calculation, so we request more phases. If we
  // are already beyond the scaling calculation loop, our request will be just
  // ignored.
  FChart.RequestMultiPassScaling;

  Result := FChart.ScalingValid;
end;

procedure TBasicChartSeries.UpdateBiDiMode;
begin
  // normally nothing to do. Override, e.g., to flip arrows
end;

procedure TBasicChartSeries.UpdateMargins(
  ADrawer: IChartDrawer; var AMargins: TRect);
begin
  Unused(ADrawer, AMargins);
end;

procedure TBasicChartSeries.VisitSources(
  AVisitor: TChartOnSourceVisitor; AAxis: TChartAxis; var AData);
begin
  Unused(AVisitor, AAxis);
  Unused(AData);
end;

{ TChartSeriesList }

procedure TChartSeriesList.Clear;
var
  i: Integer;
begin
  if FList.Count > 0 then
    Items[0].FChart.StyleChanged(Items[0].FChart);
  for i := 0 to FList.Count - 1 do begin
    Items[i].FChart := nil;
    Items[i].Free;
  end;
  FList.Clear;
end;

function TChartSeriesList.Count: Integer;
begin
  Result := FList.Count;
end;

constructor TChartSeriesList.Create;
begin
  FList := TIndexedComponentList.Create;
end;

destructor TChartSeriesList.Destroy;
begin
  Clear;
  FreeAndNil(FList);
  inherited;
end;

function TChartSeriesList.GetEnumerator: TBasicChartSeriesEnumerator;
begin
  Result := TBasicChartSeriesEnumerator.Create(FList);
end;

function TChartSeriesList.GetItem(AIndex: Integer): TBasicChartSeries;
begin
  Result := TBasicChartSeries(FList.Items[AIndex]);
end;

procedure TChartSeriesList.UpdateBiDiMode;
var
  s: TBasicChartseries;
begin
  for s in self do
    s.UpdateBiDiMode;
end;

{ TBasicChartTool }

procedure TBasicChartTool.Activate;
begin
  FChart.FActiveToolIndex := Index;
  FChart.MouseCapture := true;
  FChart.FDisablePopupMenu := false;
  FStartMousePos := Mouse.CursorPos;
end;

procedure TBasicChartTool.Deactivate;
begin
  FChart.MouseCapture := false;
  FChart.FActiveToolIndex := -1;
  if PopupMenuConflict then
    FChart.FDisablePopupMenu := true;
end;

function TBasicChartTool.PopupMenuConflict: Boolean;
begin
  Result := false;
end;

procedure SkipObsoleteChartProperties;
const
  MIRRORX_NOTE = 'Obsolete, use BottomAxis.Invert instead';
  AXIS_COLOR_NOTE = 'Obsolete, use Axis.TickColor instead';
  ANGLE_NOTE = 'Obsolete, use Font.Orientation instead';
  NOTE = 'Obsolete, use Extent instead';
  NAMES: array [1..4] of String = (
    'XGraph', 'YGraph', 'AutoUpdateX', 'AutoUpdateY');
var
  i: Integer;
begin
  RegisterPropertyToSkip(TChart, 'MirrorX', MIRRORX_NOTE, '');
  RegisterPropertyToSkip(TChart, 'AxisColor', AXIS_COLOR_NOTE, '');
  RegisterPropertyToSkip(TChartAxisTitle, 'Angle', ANGLE_NOTE, '');
  for i := 1 to High(NAMES) do begin
    RegisterPropertyToSkip(TChart, NAMES[i] + 'Min', NOTE, '');
    RegisterPropertyToSkip(TChart, NAMES[i] + 'Max', NOTE, '');
  end;
end;

initialization
  SkipObsoleteChartProperties;
  SeriesClassRegistry := TClassRegistry.Create;
  ShowMessageProc := @ShowMessage;

finalization
  FreeAndNil(SeriesClassRegistry);

end.

{
 /***************************************************************************
                               TATypes.pas
                               -----------
              Component Library Standard Graph Element Types


 ***************************************************************************/

 *****************************************************************************
  See the file COPYING.modifiedLGPL.txt, included in this distribution,
  for details about the license.
 *****************************************************************************

  Authors: Luнs Rodrigues, Philippe Martinole, Alexander Klenin

}
unit TATypes;

{$H+}

interface

uses
  Classes, Graphics, Controls, FPCanvas,
  TAChartUtils, TADrawUtils;

const
  DEF_MARGIN = 4;
  DEF_MIN_DATA_SPACE = 10;
  DEF_MARKS_DISTANCE = 20;
  DEF_POINTER_SIZE = 4;
  MARKS_YINDEX_ALL = -1;
  DEF_ARROW_LENGTH = 10;
  DEF_ARROW_WIDTH = 5;
  DEF_SHADOW_OFFSET = 8;
  DEF_SHADOW_TRANSPARENCY = 128;
  CMD_QUERY_SERIESEXTENT = 0;


type
  TCustomChart = class(TCustomControl)
  public
    procedure Notify(ACommand: Integer; AParam1, AParam2: Pointer; var Data); virtual; abstract;
    procedure StyleChanged(Sender: TObject); virtual; abstract;
    procedure ZoomFull(AImmediateRecalc: Boolean = false); virtual; abstract;
  end;

  { TChartPen }

  TChartPen = class(TPen)
  strict private
    FVisible: Boolean;
    procedure SetVisible(AValue: Boolean);
  public
    constructor Create; override;
  public
    procedure Assign(ASource: TPersistent); override;
    function EffVisible: Boolean; inline;
  published
    property Color default clDefault;
    property Visible: Boolean read FVisible write SetVisible default true;
  end;

  TClearBrush = class(TBrush)
  public
    constructor Create; override;
  published
   // property Style default bsClear;
  { wp: Removed because bsClear would no longer work - TBrush.SetColor switches
        Style to clSolid if Style is bsClear }
  end;

  TFPCanvasHelperClass = class of TFPCanvasHelper;

  { TChartElement }

  TChartElement = class(TPersistent)
  strict protected
    FOwner: TCustomChart;
    FVisible: Boolean;
    procedure InitHelper(var AResult; AClass: TFPCanvasHelperClass);
    procedure SetVisible(AValue: Boolean);
    procedure StyleChanged(Sender: TObject); virtual;
  protected
  public
    constructor Create(AOwner: TCustomChart);
  public
    procedure Assign(ASource: TPersistent); override;
    function GetOwner: TPersistent; override;
    procedure SetOwner(AOwner: TCustomChart);
    property Visible: Boolean read FVisible write SetVisible;
  end;

  TSeriesPointerStyle = (
    psNone, psRectangle, psCircle, psCross, psDiagCross, psStar,
    psLowBracket, psHighBracket, psLeftBracket, psRightBracket, psDiamond,
    psTriangle, psLeftTriangle, psRightTriangle, psVertBar, psHorBar, psPoint,
    psDownTriangle, psHexagon, psFullStar);

  { TSeriesPointer }

  TSeriesPointer = class(TChartElement)
  strict private
    FBrush: TBrush;
    FHorizSize: Integer;
    FOverrideColor: TOverrideColors;
    FPen: TChartPen;
    FStyle: TSeriesPointerStyle;
    FVertSize: Integer;

    procedure SetBrush(AValue: TBrush);
    procedure SetHorizSize(AValue: Integer);
    procedure SetOverrideColor(AValue: TOverrideColors);
    procedure SetPen(AValue: TChartPen);
    procedure SetStyle(AValue: TSeriesPointerStyle);
    procedure SetVertSize(AValue: Integer);
  public
    constructor Create(AOwner: TCustomChart);
    destructor Destroy; override;
  public
    procedure Assign(Source: TPersistent); override;
    procedure Draw(ADrawer: IChartDrawer; ACenter: TPoint; AColor: TColor;
      ABrushAlreadySet: Boolean = false);
    procedure DrawSize(ADrawer: IChartDrawer; ACenter, ASize: TPoint;
      AColor: TColor; AAngle: Double = 0.0; ABrushAlreadySet: Boolean = false);
  published
    property Brush: TBrush read FBrush write SetBrush;
    property HorizSize: Integer read FHorizSize write SetHorizSize default DEF_POINTER_SIZE;
    property OverrideColor: TOverrideColors
      read FOverrideColor write SetOverrideColor default [ocBrush];
    property Pen: TChartPen read FPen write SetPen;
    property Style: TSeriesPointerStyle read FStyle write SetStyle default psRectangle;
    property VertSize: Integer read FVertSize write SetVertSize default DEF_POINTER_SIZE;
    property Visible default false;
  end;

  EExtentError = class(EChartError);

  TChartRange = class(TChartElement)
  strict private
    FBounds: array [1..2] of Double;
    FUseBounds: array [1..2] of Boolean;

    function GetBounds(AIndex: Integer): Double;
    function GetUseBounds(AIndex: integer): Boolean;
    function IsBoundsStored(AIndex: Integer): Boolean;
    procedure SetBounds(AIndex: Integer; const AValue: Double);
    procedure SetUseBounds(AIndex: Integer; AValue: Boolean);
  public
    procedure Assign(ASource: TPersistent); override;
    procedure CheckBoundsOrder;
    procedure Intersect(var AMin, AMax: Double);
  published
    property Max: Double index 2 read GetBounds write SetBounds stored IsBoundsStored;
    property Min: Double index 1 read GetBounds write SetBounds stored IsBoundsStored;
    property UseMax: Boolean index 2 read GetUseBounds write SetUseBounds default false;
    property UseMin: Boolean index 1 read GetUseBounds write SetUseBounds default false;
  end;

  { TChartExtent }

  TChartExtent = class(TChartElement)
  strict private
    FExtent: TDoubleRect;
    FUseBounds: array [1..4] of Boolean;

    function GetBounds(AIndex: Integer): Double;
    function GetUseBounds(AIndex: integer): Boolean;
    function IsBoundsStored(AIndex: Integer): Boolean;
    procedure SetBounds(AIndex: Integer; const AValue: Double);
    procedure SetUseBounds(AIndex: Integer; AValue: Boolean);
  public
    procedure Assign(ASource: TPersistent); override;
    procedure CheckBoundsOrder;
    procedure FixTo(const ABounds: TDoubleRect);
  published
    property UseXMax: Boolean index 3 read GetUseBounds write SetUseBounds default false;
    property UseXMin: Boolean index 1 read GetUseBounds write SetUseBounds default false;
    property UseYMax: Boolean index 4 read GetUseBounds write SetUseBounds default false;
    property UseYMin: Boolean index 2 read GetUseBounds write SetUseBounds default false;
    property XMax: Double index 3 read GetBounds write SetBounds stored IsBoundsStored;
    property XMin: Double index 1 read GetBounds write SetBounds stored IsBoundsStored;
    property YMax: Double index 4 read GetBounds write SetBounds stored IsBoundsStored;
    property YMin: Double index 2 read GetBounds write SetBounds stored IsBoundsStored;
  end;

  TChartExtentHistory = specialize THistory<TDoubleRect>;

  TRectArray = array [1..4] of Integer;

  { TChartMargins }

  TChartMargins = class(TChartElement)
  strict private
    FData: record
      case Integer of
        0: (FRect: TRect;);
        1: (FCoords: TRectArray;);
      end;
  public
    constructor Create(AOwner: TCustomChart);

    function GetValue(AIndex: Integer): Integer;
    procedure SetValue(AIndex: Integer; AValue: TChartDistance);
  public
    procedure Assign(Source: TPersistent); override;
    procedure ExpandRectScaled(ADrawer: IChartDrawer; var ARect: TRect);
    property Data: TRect read FData.FRect;
  published
    property Left: TChartDistance index 1 read GetValue write SetValue default DEF_MARGIN;
    property Top: TChartDistance index 2 read GetValue write SetValue default DEF_MARGIN;
    property Right: TChartDistance index 3 read GetValue write SetValue default DEF_MARGIN;
    property Bottom: TChartDistance index 4 read GetValue write SetValue default DEF_MARGIN;
  end;

  TChartArrow = class(TChartElement)
  strict private
    FBaseLength: TChartDistance;
    FInverted: Boolean;
    FLength: TChartDistance;
    FWidth: TChartDistance;
    procedure SetBaseLength(AValue: TChartDistance);
    procedure SetInverted(AValue: Boolean);
    procedure SetLength(AValue: TChartDistance);
    procedure SetWidth(AValue: TChartDistance);
  public
    constructor Create(AOwner: TCustomChart);
  public
    procedure Assign(ASource: TPersistent); override;
    procedure Draw(
      ADrawer: IChartDrawer; const AEndPos: TPoint; AAngle: Double;
      APen: TFPCustomPen);
  published
    property BaseLength: TChartDistance
      read FBaseLength write SetBaseLength default 0;
    property Inverted: Boolean
      read FInverted write SetInverted default false;
    property Length: TChartDistance
      read FLength write SetLength default DEF_ARROW_LENGTH;
    property Visible default false;
    property Width: TChartDistance
      read FWidth write SetWidth default DEF_ARROW_WIDTH;
  end;

  TChartShadow = class(TChartElement)
  strict private
    FColor: TColor;
    FOffset: TPoint;
    FTransparency: TChartTransparency;
    procedure SetColor(AValue: TColor);
    procedure SetOffsetX(AValue: Integer);
    procedure SetOffsetY(AValue: Integer);
    procedure SetTransparency(AValue: TChartTransparency);
  public
    constructor Create(AOwner: TCustomChart);
  public
    procedure Assign(ASource: TPersistent); override;
  published
    property Color: TColor read FColor write SetColor default clBlack;
    property OffsetX: Integer read FOffset.X write SetOffsetX default DEF_SHADOW_OFFSET;
    property OffsetY: Integer read FOffset.Y write SetOffsetY default DEF_SHADOW_OFFSET;
    property Transparency: TChartTransparency
      read FTransparency write SetTransparency default DEF_SHADOW_TRANSPARENCY;
    property Visible default false;
  end;

  TChartErrorBar = class(TChartElement)
  private
    FWidth: Integer;
    FPen: TPen;
    procedure SetPen(const AValue: TPen);
    procedure SetWidth(const AValue: Integer);
  public
    constructor Create(AOwner: TCustomChart);
    destructor Destroy; override;
    procedure Assign(ASource: TPersistent); override;
  published
    property Pen: TPen read FPen write SetPen;
    property Visible default false;
    property Width: Integer read FWidth write SetWidth default -1;
  end;

implementation

uses
  Math, SysUtils,
  TAGeometry;

{ TChartPen }

procedure TChartPen.Assign(ASource: TPersistent);
begin
  if ASource is TChartPen then
    FVisible := TChartPen(ASource).Visible;
  inherited Assign(ASource);
end;

constructor TChartPen.Create;
begin
  inherited Create;
  SetPropDefaults(Self, ['Color', 'Style', 'Visible']);
end;

function TChartPen.EffVisible: Boolean;
begin
  Result := Visible and (Style <> psClear);
end;

procedure TChartPen.SetVisible(AValue: Boolean);
begin
  FVisible := AValue;
  if Assigned(OnChange) then OnChange(Self);
end;

{ TClearBrush }

constructor TClearBrush.Create;
begin
  inherited;
  Style := bsClear;
end;

{ TChartElement }

procedure TChartElement.Assign(ASource: TPersistent);
begin
  if ASource is TChartElement then
    with TChartElement(ASource) do begin
      Self.FVisible := FVisible;
      Self.FOwner := FOwner;
    end;
end;

constructor TChartElement.Create(AOwner: TCustomChart);
begin
  inherited Create;
  FOwner := AOwner;
end;

function TChartElement.GetOwner: TPersistent;
begin
  Result := FOwner;
end;

procedure TChartElement.InitHelper(var AResult; AClass: TFPCanvasHelperClass);
begin
  TFPCanvasHelper(AResult) := AClass.Create;
  TFPCanvasHelper(AResult).OnChange := @StyleChanged;
end;

procedure TChartElement.SetOwner(AOwner: TCustomChart);
begin
  FOwner := AOwner;
end;

procedure TChartElement.SetVisible(AValue: Boolean);
begin
  if FVisible = AValue then exit;
  FVisible := AValue;
  StyleChanged(Self);
end;

procedure TChartElement.StyleChanged(Sender: TObject);
begin
  if FOwner <> nil then
    FOwner.StyleChanged(Sender);
end;

{ TSeriesPointer }

procedure TSeriesPointer.Assign(Source: TPersistent);
begin
  if Source is TSeriesPointer then
    with TSeriesPointer(Source) do begin
      Self.FBrush.Assign(Brush);
      Self.FHorizSize := HorizSize;
      Self.FOverrideColor := OverrideColor;
      Self.FPen.Assign(Pen);
      Self.FStyle := Style;
      Self.FVertSize := VertSize;
    end;
  inherited Assign(Source);
end;

constructor TSeriesPointer.Create(AOwner: TCustomChart);
begin
  inherited Create(AOwner);

  InitHelper(FBrush, TBrush);
  InitHelper(FPen, TChartPen);

  FHorizSize := DEF_POINTER_SIZE;
  SetPropDefaults(Self, ['OverrideColor', 'Style']);
  FVertSize := DEF_POINTER_SIZE;
  FVisible := false;
end;

destructor TSeriesPointer.Destroy;
begin
  FreeAndNil(FBrush);
  FreeAndNil(FPen);
  inherited;
end;

{ Draws the pointer.
  If ABrushAlreadySet is true then the method assumes that the brush already has
  been set by the calling routine and does not change it any further (needed
  for applying ChartStyle brush). }
procedure TSeriesPointer.Draw(ADrawer: IChartDrawer; ACenter: TPoint;
  AColor: TColor; ABrushAlreadySet: Boolean = false);
begin
  DrawSize(ADrawer,
    ACenter,
    Point(ADrawer.Scale(HorizSize), ADrawer.Scale(VertSize)),
    AColor,
    0,
    ABrushAlreadySet
  );
end;

procedure TSeriesPointer.DrawSize(ADrawer: IChartDrawer;
  ACenter, ASize: TPoint; AColor: TColor; AAngle: Double; ABrushAlreadySet: Boolean);

  function PointByIndex(AIndex: Char): TPoint; inline;
  // 7--8--9
  // 4  5  6
  // 1--2--3
  const
    V: array ['1'..'9'] of -1..1 = (1, 1, 1, 0, 0, 0, -1, -1, -1);
    H: array ['1'..'9'] of -1..1 = (-1, 0, 1, -1, 0, 1, -1, 0, 1);
  begin
    Result := ACenter + RotatePoint(
      Point(H[AIndex] * ASize.X, V[AIndex] * ASize.Y), AAngle);
  end;

  procedure DrawByString(const AStr: String);
  var
    pts: array of TPoint = nil;
    i: Integer;
    j: Integer = 0;
    notClosed: Boolean;
  begin
    notClosed := (AStr[1] <> AStr[Length(AStr) - 1]);
    SetLength(pts, Length(AStr));
    for i := 1 to Length(AStr) do begin
      if AStr[i] = ' ' then begin
        if (Brush.Style = bsClear) or notClosed then
          ADrawer.Polyline(pts, 0, j)
        else
          ADrawer.Polygon(pts, 0, j); // Winding?
        j := 0;
      end
      else begin
        pts[j] := PointByIndex(AStr[i]);
        Inc(j);
      end;
    end;
  end;

  procedure DrawPolygon(AStyle: TSeriesPointerStyle);
  const
    INNER = 0.5;
  var
    p: array of TPoint = nil;
    pt: TDoublePoint;
    phi, sinphi, cosphi, dPhi: Math.float;
    i: Integer;
  begin
    case AStyle of
      psHexagon  : begin dPhi := pi / 3; SetLength(p, 7); end;
      psFullStar : begin dPhi := pi / 6; SetLength(p, 13); end;
    end;
    phi := 0;
    for i := 0 to High(p) do 
    begin
      SinCos(phi, sinphi, cosphi);
      pt := DoublePoint(ASize.X * cosPhi, ASize.Y * sinPhi);
      if odd(i) and (AStyle = psFullStar) then
        pt := pt * INNER;
      p[i] := ACenter + RoundPoint(RotatePoint(pt, AAngle));
      phi += dPhi;
    end;
    ADrawer.Polygon(p, 0, Length(p));
  end;


const
  DRAW_STRINGS: array [TSeriesPointerStyle] of String = (
    // psNone, psRectangle, psCircle, psCross, psDiagCross, psStar,
    // psLowBracket, psHighBracket, psLeftBracket, psRightBracket, psDiamond,
    // psTriangle, psLeftTriangle, psRightTriangle, psVertBar, psHorBar,
    // psPoint, pwDownTriangle, psHexagon, psFullStar
    '', '17931', '', '28 46', '19 73', '', //28 46 19 73',
    '41236', '47896', '87412', '89632', '84268',
    '1831', '8428', '8628', '82', '46',
    '', '7927', '', '');
begin
  if not ABrushAlreadySet then begin
    ADrawer.Brush := Brush;
    if (ocBrush in OverrideColor) and (AColor <> clTAColor) then
      ADrawer.BrushColor := AColor;
  end;

  ADrawer.Pen := Pen;
  if (ocPen in OverrideColor) and (AColor <> clTAColor) then
    ADrawer.SetPenParams(Pen.Style, AColor);

  case Style of
    psNone    : ;
    psPoint   : ADrawer.PutPixel(ACenter.X, ACenter.Y, Pen.Color);
    psCircle  : ADrawer.Ellipse(
                  ACenter.X - ASize.X, ACenter.Y - ASize.Y,
                  ACenter.X + ASize.X + 1, ACenter.Y + ASize.Y + 1);
    psHexagon : DrawPolygon(psHexagon);
    psStar    : begin
                  DrawByString(DRAW_STRINGS[psCross] + ' ');
                  ASize := Point(ASize.X * 7 div 10, ASize.Y * 7 div 10);
                  DrawByString(DRAW_STRINGS[psDiagCross] + ' ');
                end;
    psFullStar: DrawPolygon(psFullStar);
    else        DrawByString(DRAW_STRINGS[Style] + ' ');
  end;
end;

procedure TSeriesPointer.SetBrush(AValue: TBrush);
begin
  FBrush.Assign(AValue);
  StyleChanged(Self);
end;

procedure TSeriesPointer.SetHorizSize(AValue: Integer);
begin
  if FHorizSize = AValue then exit;
  FHorizSize := AValue;
  StyleChanged(Self);
end;

procedure TSeriesPointer.SetOverrideColor(AValue: TOverrideColors);
begin
  if FOverrideColor = AValue then exit;
  FOverrideColor := AValue;
  StyleChanged(Self);
end;

procedure TSeriesPointer.SetPen(AValue: TChartPen);
begin
  FPen.Assign(AValue);
  StyleChanged(Self);
end;

procedure TSeriesPointer.SetStyle(AValue: TSeriesPointerStyle);
begin
  if FStyle = AValue then exit;
  FStyle := AValue;
  StyleChanged(Self);
end;

procedure TSeriesPointer.SetVertSize(AValue: Integer);
begin
  if FVertSize = AValue then exit;
  FVertSize := AValue;
  StyleChanged(Self);
end;


{ TChartRange }

procedure TChartRange.Assign(ASource: TPersistent);
begin
  if ASource is TChartRange then
    with TChartRange(ASource) do begin
      Self.FBounds := FBounds;
      Self.FUseBounds := FUseBounds;
    end;
  inherited Assign(ASource);
end;

procedure TChartRange.CheckBoundsOrder;
begin
  if UseMin and UseMax and (Min >= Max) then begin
    UseMin := false;
    UseMax := false;
    raise EExtentError.Create('ChartRange: Min >= Max');
  end;
end;

function TChartRange.GetBounds(AIndex: Integer): Double;
begin
  Result := FBounds[AIndex];
end;

function TChartRange.GetUseBounds(AIndex: integer): Boolean;
begin
  Result := FUseBounds[AIndex];
end;

procedure TChartRange.Intersect(var AMin, AMax: Double);
begin
  if UseMin and (Min > AMin) then
    AMin := Min;
  if UseMax and (Max < AMax)then
    AMax := Max;
end;

function TChartRange.IsBoundsStored(AIndex: Integer): Boolean;
begin
  Result := not SameValue(FBounds[AIndex], 0);
end;

procedure TChartRange.SetBounds(AIndex: Integer; const AValue: Double);
begin
  FBounds[AIndex] := AValue;
  StyleChanged(Self);
end;

procedure TChartRange.SetUseBounds(AIndex: Integer; AValue: Boolean);
begin
  FUseBounds[AIndex] := AValue;
  StyleChanged(Self);
end;

{ TChartExtent }

procedure TChartExtent.Assign(ASource: TPersistent);
begin
  if ASource is TChartExtent then
    with TChartExtent(ASource) do begin
      Self.FExtent := FExtent;
      Self.FUseBounds := FUseBounds;
    end;
  inherited Assign(ASource);
end;

procedure TChartExtent.CheckBoundsOrder;
begin
  if UseXMin and UseXMax and (XMin >= XMax) then begin
    UseXMin := false;
    UseXMax := false;
    raise EExtentError.Create('ChartExtent: XMin >= XMax');
  end;
  if UseYMin and UseYMax and (YMin >= YMax) then begin
    UseYMin := false;
    UseYMax := false;
    raise EExtentError.Create('ChartExtent: YMin >= YMax');
  end;
end;

procedure TChartExtent.FixTo(const ABounds: TDoubleRect);
begin
  FExtent := ABounds;
  FillChar(FUseBounds, SizeOf(FUseBounds), true);
  StyleChanged(Self);
end;

function TChartExtent.GetBounds(AIndex: Integer): Double;
begin
  Result := FExtent.coords[AIndex];
end;

function TChartExtent.GetUseBounds(AIndex: Integer): Boolean;
begin
  Result := FUseBounds[AIndex];
end;

function TChartExtent.IsBoundsStored(AIndex: Integer): Boolean;
begin
  Result := not SameValue(FExtent.coords[AIndex], 0.0);
end;

procedure TChartExtent.SetBounds(AIndex: Integer; const AValue: Double);
begin
  FExtent.coords[AIndex] := AValue;
  StyleChanged(Self);
end;

procedure TChartExtent.SetUseBounds(AIndex: Integer; AValue: Boolean);
begin
  FUseBounds[AIndex] := AValue;
  StyleChanged(Self);
end;

{ TChartMargins }

procedure TChartMargins.Assign(Source: TPersistent);
begin
  if Source is TChartMargins then
    TChartMargins(Source).FData.FRect := Data;
  inherited Assign(Source);
end;

constructor TChartMargins.Create(AOwner: TCustomChart);
begin
  inherited Create(AOwner);
  SetPropDefaults(Self, ['Left', 'Top', 'Right', 'Bottom']);
end;

procedure TChartMargins.ExpandRectScaled(
  ADrawer: IChartDrawer; var ARect: TRect);
begin
  ARect.TopLeft -= Point(ADrawer.Scale(Left), ADrawer.Scale(Top));
  ARect.BottomRight += Point(ADrawer.Scale(Right), ADrawer.Scale(Bottom));
end;

function TChartMargins.GetValue(AIndex: Integer): Integer;
begin
  Result := FData.FCoords[AIndex];
end;

procedure TChartMargins.SetValue(AIndex: Integer; AValue: TChartDistance);
begin
  if FData.FCoords[AIndex] = AValue then exit;
  FData.FCoords[AIndex] := AValue;
  StyleChanged(Self);
end;

{ TChartArrow }

procedure TChartArrow.Assign(ASource: TPersistent);
begin
  if ASource is TChartArrow then
    with TChartArrow(ASource) do begin
      Self.FBaseLength := FBaseLength;
      Self.FLength := FLength;
      Self.FWidth := FWidth;
    end;
  inherited Assign(ASource);
end;

constructor TChartArrow.Create(AOwner: TCustomChart);
begin
  inherited Create(AOwner);
  FLength := DEF_ARROW_LENGTH;
  FVisible := false;
  FWidth := DEF_ARROW_WIDTH;
end;

procedure TChartArrow.Draw(
  ADrawer: IChartDrawer; const AEndPos: TPoint; AAngle: Double;
  APen: TFPCustomPen);
var
  da: Double;
  diag: Integer;
  pt1, pt2, ptBase: TPoint;
  sgn: Integer;
begin
  if not Visible then exit;
  da := ArcTan2(Width, Length);

  sgn := Math.IfThen(FInverted, -1, +1);
  diag := -ADrawer.Scale(Round(Sqrt(Sqr(Length) + Sqr(Width))));
  pt1 := AEndPos + RotatePointX(diag, AAngle - da)*sgn;
  pt2 := AEndPos + RotatePointX(diag, AAngle + da)*sgn;
  ADrawer.SetPenParams(psSolid, FPColorToTColor(APen.FPColor), APen.Width);
  if BaseLength > 0 then begin
    ptBase := AEndPos + RotatePointX(-ADrawer.Scale(BaseLength), AAngle)*sgn;
    ADrawer.SetBrushParams(bsSolid, FPColorToChartColor(APen.FPColor));
    ADrawer.Polygon([pt1, AEndPos, pt2, ptBase], 0, 4);
  end
  else
    ADrawer.Polyline([pt1, AEndPos, pt2], 0, 3);
end;

procedure TChartArrow.SetBaseLength(AValue: TChartDistance);
begin
  if FBaseLength = AValue then exit;
  FBaseLength := AValue;
  StyleChanged(Self);
end;

procedure TChartArrow.SetInverted(AValue: Boolean);
begin
  if FInverted = AValue then exit;
  FInverted := AValue;
  StyleChanged(Self);
end;

procedure TChartArrow.SetLength(AValue: TChartDistance);
begin
  if FLength = AValue then exit;
  FLength := AValue;
  StyleChanged(Self);
end;

procedure TChartArrow.SetWidth(AValue: TChartDistance);
begin
  if FWidth = AValue then exit;
  FWidth := AValue;
  StyleChanged(Self);
end;

{ TChartShadow }

procedure TChartShadow.Assign(ASource: TPersistent);
begin
  if ASource is TChartShadow then
    with TChartShadow(ASource) do begin
      Self.FColor := Color;
      Self.FOffset := FOffset;
      Self.FTransparency := Transparency;
    end;
  inherited Assign(ASource);
end;

constructor TChartShadow.Create(AOwner: TCustomChart);
begin
  inherited Create(AOwner);
  FColor := clBlack;
  FOffset := Point(DEF_SHADOW_OFFSET, DEF_SHADOW_OFFSET);
  FTransparency := DEF_SHADOW_TRANSPARENCY;
end;

procedure TChartShadow.SetColor(AValue: TColor);
begin
  if FColor = AValue then exit;
  FColor := AValue;
  StyleChanged(Self);
end;

procedure TChartShadow.SetOffsetX(AValue: Integer);
begin
  if FOffset.X = AValue then exit;
  FOffset.X := AValue;
  StyleChanged(Self);
end;

procedure TChartShadow.SetOffsetY(AValue: Integer);
begin
  if FOffset.Y = AValue then exit;
  FOffset.Y := AValue;
  StyleChanged(Self);
end;

procedure TChartShadow.SetTransparency(AValue: TChartTransparency);
begin
  if FTransparency = AValue then exit;
  FTransparency := AValue;
  StyleChanged(Self);
end;

{ TChartErrorBar }

constructor TChartErrorBar.Create(AOwner: TCustomChart);
begin
  inherited Create(AOwner);
  FWidth := -1;     // -1 = same width as series pointer
  FPen := TPen.Create;
  FPen.OnChange := @StyleChanged;
  FVisible := false;
end;

destructor TChartErrorBar.Destroy;
begin
  FPen.Free;
  inherited Destroy;
end;

procedure TChartErrorBar.Assign(ASource: TPersistent);
begin
  if ASource is TChartErrorBar then begin
    FPen.Assign(TChartErrorBar(ASource).Pen);
    FWidth := TChartErrorBar(ASource).Width;
  end;
  inherited;
end;

procedure TChartErrorBar.SetPen(const AValue: TPen);
begin
  FPen.Assign(AValue);
  StyleChanged(Self);
end;

procedure TChartErrorBar.SetWidth(const AValue: Integer);
begin
  if FWidth = AValue then exit;
  FWidth := AValue;
  StyleChanged(self);
end;

end.


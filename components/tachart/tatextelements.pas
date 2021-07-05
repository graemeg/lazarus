{

 *****************************************************************************
  See the file COPYING.modifiedLGPL.txt, included in this distribution,
  for details about the license.
 *****************************************************************************

  Authors: Alexander Klenin

}
unit TATextElements;

{$H+}

interface

uses
  Classes, Graphics, Types,
  TAChartUtils, TADrawUtils, TATypes,

  // Workaround for issue #22850.
  GraphMath, Math, SysUtils,
  TACustomSource, TAGeometry;

const
  DEF_LABEL_MARGIN_X = 4;
  DEF_LABEL_MARGIN_Y = 2;

type
  TChartMarksOverlapPolicy = (opIgnore, opHideNeighbour);

  TChartLabelMargins = class(TChartMargins)
  published
    property Bottom default DEF_LABEL_MARGIN_Y;
    property Left default DEF_LABEL_MARGIN_X;
    property Right default DEF_LABEL_MARGIN_X;
    property Top default DEF_LABEL_MARGIN_Y;
  end;

  TChartLabelShape = (
    clsRectangle, clsEllipse, clsRoundRect, clsRoundSide, clsUserDefined);

  TChartTextRotationCenter = (rcCenter, rcEdge, rcLeft, rcRight);

  TChartTextElement = class;

  TChartGetShapeEvent = procedure (
    ASender: TChartTextElement; const ABoundingBox: TRect;
    var APolygon: TPointArray) of object;

  TChartTextElement = class(TChartElement)
  strict private
    FCalloutAngle: Cardinal;
    FClipped: Boolean;
    FMargins: TChartLabelMargins;
    FOnGetShape: TChartGetShapeEvent;
    FOverlapPolicy: TChartMarksOverlapPolicy;
    FShape: TChartLabelShape;
    FTextFormat: TChartTextFormat;
    FTextRect: TRect;
    procedure SetAlignment(AValue: TAlignment);
    procedure SetCalloutAngle(AValue: Cardinal);
    procedure SetClipped(AValue: Boolean);
    procedure SetMargins(AValue: TChartLabelMargins);
    procedure SetOnGetShape(AValue: TChartGetShapeEvent);
    procedure SetOverlapPolicy(AValue: TChartMarksOverlapPolicy);
    procedure SetRotationCenter(AValue: TChartTextRotationCenter);
    procedure SetShape(AValue: TChartLabelShape);
    procedure SetTextFormat(AValue: TChartTextFormat);
  strict protected
    FAlignment: TAlignment;
    FInsideDir: TDoublePoint;
    FRotationCenter: TChartTextRotationCenter;
    procedure ApplyLabelFont(ADrawer: IChartDrawer); virtual;
    procedure DrawLink(
      ADrawer: IChartDrawer; ADataPoint, ALabelCenter: TPoint); virtual;
    function GetBoundingBox(
      ADrawer: IChartDrawer; const ATextSize: TPoint): TRect;
    function GetTextShiftNeeded: Boolean;
    function IsMarginRequired: Boolean;
  strict protected
    function GetFrame: TChartPen; virtual; abstract;
    function GetLabelAngle: Double; virtual;
    function GetLabelBrush: TBrush; virtual; abstract;
    function GetLabelFont: TFont; virtual; abstract;
    function GetLinkPen: TChartPen; virtual;
    property RotationCenter: TChartTextRotationCenter
      read FRotationCenter write SetRotationCenter default rcCenter;
  public
    constructor Create(AOwner: TCustomChart);
    destructor Destroy; override;
  public
    procedure Assign(ASource: TPersistent); override;
    procedure DrawLabel(
      ADrawer: IChartDrawer; const ADataPoint, ALabelCenter: TPoint;
      const AText: String; var APrevLabelPoly: TPointArray);
    function GetLabelPolygon(
      ADrawer: IChartDrawer; ASize: TPoint): TPointArray;
    function GetTextRect: TRect;
    function MeasureLabel(ADrawer: IChartDrawer; const AText: String): TSize;
    function MeasureLabelHeight(ADrawer: IChartDrawer; const AText: String): TSize;
    procedure SetInsideDir(dx, dy: Double);
  public
    property CalloutAngle: Cardinal
      read FCalloutAngle write SetCalloutAngle default 0;
    // If false, labels may overlap axises and legend.
    property Clipped: Boolean read FClipped write SetClipped default true;
    property OverlapPolicy: TChartMarksOverlapPolicy
      read FOverlapPolicy write SetOverlapPolicy default opIgnore;
    property OnGetShape: TChartGetShapeEvent
      read FOnGetShape write SetOnGetShape;
    property Shape: TChartLabelShape
      read FShape write SetShape default clsRectangle;
    property TextFormat: TChartTextFormat
      read FTextFormat write SetTextFormat default tfNormal;
  published
    property Alignment: TAlignment
      read FAlignment write SetAlignment;
    property Margins: TChartLabelMargins read FMargins write SetMargins;
  end;

  TChartTitleFramePen = class(TChartPen)
  published
    property Visible default false;
  end;

  { TChartTitle }

  TChartTitle = class(TChartTextElement)
  strict private
    FBrush: TBrush;
    FCenter: TPoint;
    FFont: TFont;
    FFrame: TChartTitleFramePen;
    FMargin: TChartDistance;
    FPolygon: TPointArray;
    FText: TStrings;
    FWordWrap: Boolean;
    FWrappedCaption: String;

    function GetRealCaption: String;
    function IsWordwrapped: Boolean;
    procedure SetBrush(AValue: TBrush);
    procedure SetFont(AValue: TFont);
    procedure SetFrame(AValue: TChartTitleFramePen);
    procedure SetMargin(AValue: TChartDistance);
    procedure SetText(AValue: TStrings);
    procedure SetWordwrap(AValue: Boolean);
    procedure WordWrapCaption(ADrawer: IChartDrawer; AMaxWidth: Integer);
  strict protected
    function GetFrame: TChartPen; override;
    function GetLabelBrush: TBrush; override;
    function GetLabelFont: TFont; override;
  public
    constructor Create(AOwner: TCustomChart);
    destructor Destroy; override;
  public
    procedure Assign(ASource: TPersistent); override;
    procedure Draw(ADrawer: IChartDrawer);
    function IsPointInBounds(APoint: TPoint): boolean;
    procedure Measure(
      ADrawer: IChartDrawer; ADir, ALeft, ARight: Integer; var AY: Integer);
    procedure UpdateBidiMode;
  published
    property Alignment default taCenter;
    property Brush: TBrush read FBrush write SetBrush;
    property Font: TFont read FFont write SetFont;
    property Frame: TChartTitleFramePen read FFrame write SetFrame;
    property Margin: TChartDistance
      read FMargin write SetMargin default DEF_MARGIN;
    property OnGetShape;
    property Shape;
    property Text: TStrings read FText write SetText;
    property TextFormat;
    property Visible default false;
    property Wordwrap: Boolean read FWordwrap write SetWordwrap default false;
  end;

  TChartMarkAttachment = (maDefault, maEdge, maCenter);

  { TGenericChartMarks }

  {$IFNDEF fpdoc}  // Workaround for issue #18549.
  generic TGenericChartMarks<_TLabelBrush, _TLinkPen, _TFramePen> =
    class(TChartTextElement)
  {$ELSE}
  TGenericChartMarks = class(TChartTextElement)
  {$ENDIF}
  strict private
    FAdditionalAngle: Double;
    FArrow: TChartArrow;
    FLinkDistance: Integer;
    FAttachment: TChartMarkAttachment;
    FAutoMargins: Boolean;
    FFrame: _TFramePen;
    FYIndex: Integer;
    function GetDistanceToCenter: Boolean;
    procedure SetArrow(AValue: TChartArrow);
    procedure SetAttachment(AValue: TChartMarkAttachment);
    procedure SetAutoMargins(AValue: Boolean);
    procedure SetDistance(AValue: TChartDistance);
    procedure SetDistanceToCenter(AValue: Boolean);
    procedure SetFormat(AValue: String);
    procedure SetFrame(AValue: _TFramePen);
    procedure SetLabelBrush(AValue: _TLabelBrush);
    procedure SetLabelFont(AValue: TFont);
    procedure SetLinkDistance(AValue: Integer);
    procedure SetLinkPen(AValue: _TLinkPen);
    procedure SetStyle(AValue: TSeriesMarksStyle);
    procedure SetYIndex(AValue: Integer);
  strict protected
    FDistance: TChartDistance;
    FFormat: String;
    FLabelBrush: _TLabelBrush;
    FLabelFont: TFont;
    FLinkPen: _TLinkPen;
    FStyle: TSeriesMarksStyle;
  strict protected
    procedure ApplyLabelFont(ADrawer: IChartDrawer); override;
    procedure DrawLink(
      ADrawer: IChartDrawer; ADataPoint, ALabelCenter: TPoint); override;
    function GetFrame: TChartPen; override;
    function GetLabelAngle: Double; override;
    function GetLabelBrush: TBrush; override;
    function GetLabelFont: TFont; override;
    function GetLinkPen: TChartPen; override;
  public
    constructor Create(AOwner: TCustomChart);
    destructor Destroy; override;
  public
    procedure Assign(ASource: TPersistent); override;
    function CenterHeightOffset(ADrawer: IChartDrawer; const AText: String): TSize;
    function CenterOffset(ADrawer: IChartDrawer; const AText: String): TSize;
    function IsMarkLabelsVisible: Boolean;
    procedure SetAdditionalAngle(AAngle: Double);
  public
    property Arrow: TChartArrow read FArrow write SetArrow;
    property AutoMargins: Boolean
      read FAutoMargins write SetAutoMargins default true;
    property DistanceToCenter: Boolean
      read GetDistanceToCenter write SetDistanceToCenter
      stored false default false;
    property Format: String read FFormat write SetFormat;
    property Frame: _TFramePen read FFrame write SetFrame;
    property LabelBrush: _TLabelBrush read FLabelBrush write SetLabelBrush;
    property LinkDistance: Integer read FLinkDistance write SetLinkDistance default 0;
    property LinkPen: _TLinkPen read FLinkPen write SetLinkPen;
    property Style: TSeriesMarksStyle read FStyle write SetStyle;
    property YIndex: Integer read FYIndex write SetYIndex default 0;
  published
    property Alignment default taLeftJustify;
    property Attachment: TChartMarkAttachment
      read FAttachment write SetAttachment default maDefault;
    // Distance between labelled object and label.
    property Clipped;
    property Distance: TChartDistance read FDistance write SetDistance;
    property LabelFont: TFont read FLabelFont write SetLabelFont;
    property OnGetShape;
    property Shape;
    property Visible default true;
  end;

  TChartLinkPen = class(TChartPen)
  published
    property Color default clWhite;
  end;

  TChartLabelBrush = class(TBrush)
  published
    property Color default clYellow;
  end;

  {$IFNDEF fpdoc}  // Workaround for issue #18549.
  TCustomChartMarks =
    specialize TGenericChartMarks<TChartLabelBrush, TChartLinkPen, TChartPen>;
  {$ENDIF}

  { TChartMarks }

  TChartMarks = class(TCustomChartMarks)
  public
    procedure Assign(Source: TPersistent); override;
    constructor Create(AOwner: TCustomChart);
  published
    property Arrow;
    property AutoMargins;
    property CalloutAngle;
    property Distance default DEF_MARKS_DISTANCE;
    property Format;
    property Frame;
    property LabelBrush;
    property LinkDistance;
    property LinkPen;
    property OverlapPolicy;
    property RotationCenter;
    property Style default smsNone;
    property TextFormat;
    property YIndex;
  end;

implementation

{ TChartTextElement }

procedure TChartTextElement.ApplyLabelFont(ADrawer: IChartDrawer);
begin
  ADrawer.Font := GetLabelFont;
end;

procedure TChartTextElement.Assign(ASource: TPersistent);
begin
  if ASource is TChartTextElement then
    with TChartTextElement(ASource) do begin
      Self.FAlignment := Alignment;
      Self.FCalloutAngle := FCalloutAngle;
      Self.FClipped := FClipped;
      Self.FMargins.Assign(FMargins);
      Self.FOverlapPolicy := FOverlapPolicy;
      Self.FShape := FShape;
      Self.FTextFormat := FTextFormat;
      Self.FInsideDir := FInsideDir;
    end;
  inherited Assign(ASource);
end;

constructor TChartTextElement.Create(AOwner: TCustomChart);
begin
  inherited Create(AOwner);
  FClipped := true;
  FMargins := TChartLabelMargins.Create(AOwner);
  FOverlapPolicy := opIgnore;
end;

destructor TChartTextElement.Destroy;
begin
  FreeAndNil(FMargins);
  inherited;
end;

procedure TChartTextElement.DrawLabel(
  ADrawer: IChartDrawer; const ADataPoint, ALabelCenter: TPoint;
  const AText: String; var APrevLabelPoly: TPointArray);
var
  labelPoly: TPointArray;
  ptText, P: TPoint;
  i, w: Integer;
begin
  ApplyLabelFont(ADrawer);
  ptText := ADrawer.TextExtent(AText, FTextFormat);
  w := ptText.X;
  labelPoly := GetLabelPolygon(ADrawer, ptText);
  for i := 0 to High(labelPoly) do
    labelPoly[i] += ALabelCenter;
  if CalloutAngle > 0 then
    labelPoly := MakeCallout(
      labelPoly, ALabelCenter, ADataPoint, OrientToRad(CalloutAngle));

  if (OverlapPolicy = opHideNeighbour) and
    IsPolygonIntersectsPolygon(APrevLabelPoly, labelPoly)
  then
    exit;
  APrevLabelPoly := labelPoly;

  if not Clipped then
    ADrawer.ClippingStop;

  DrawLink(ADrawer, ADataPoint, ALabelCenter);
  with GetLabelBrush do
    ADrawer.SetBrushParams(Style, ColorToRGB(Color));
  if IsMarginRequired then begin
    if GetFrame.Visible then
      ADrawer.Pen := GetFrame
    else
      ADrawer.SetPenParams(psClear, clTAColor);
    ADrawer.Polygon(labelPoly, 0, Length(labelPoly));
  end;

  case FRotationCenter of
    rcCenter: P := -ptText div 2;
    rcEdge,
    rcLeft  : begin
                P := Point(0, -ptText.y div 2);
                if (FRotationCenter = rcEdge) and GetTextShiftNeeded then
                  P.x := -ptText.x;
              end;
    rcRight : P := Point(-ptText.x, -ptText.y div 2);
  end;
  ptText := RotatePoint(P, GetLabelAngle) + ALabelCenter;

  ADrawer.TextOut.TextFormat(FTextFormat).Pos(ptText).Alignment(Alignment).Width(w).Text(AText).Done;
  if not Clipped then
    ADrawer.ClippingStart;
end;

procedure TChartTextElement.DrawLink(
  ADrawer: IChartDrawer; ADataPoint, ALabelCenter: TPoint);
var
  p: TChartPen;
begin
  if ADataPoint = ALabelCenter then exit;
  p := GetLinkPen;
  if p.Visible then begin
    ADrawer.Pen := p;
    ADrawer.Line(ADataPoint, ALabelCenter);
  end;
end;

function TChartTextElement.GetBoundingBox(
  ADrawer: IChartDrawer; const ATextSize: TPoint): TRect;
begin
  Result := ZeroRect;
  InflateRect(Result, ATextSize.X div 2, ATextSize.Y div 2);

  case FRotationCenter of
    rcCenter : ;
    rcLeft,
    rcEdge   : begin
                 OffsetRect(Result, ATextSize.x div 2, 0);
                 if (FRotationCenter = rcEdge) and GetTextShiftNeeded then
                   OffsetRect(Result, -ATextSize.x, 0);
               end;
    rcRight  : OffsetRect(Result, -ATextSize.x div 2, 0);
  end;

  if IsMarginRequired then
    Margins.ExpandRectScaled(ADrawer, Result);
end;

function TChartTextElement.GetLabelAngle: Double;
begin
  // Negate to take into account top-down Y axis.
  Result := -OrientToRad(GetLabelFont.Orientation);
end;

function TChartTextElement.GetLabelPolygon(
  ADrawer: IChartDrawer; ASize: TPoint): TPointArray;
const
  STEP = 3;
var
  a: Double;
  b: TRect;
  i: Integer;
begin
  b := GetBoundingBox(ADrawer, ASize);
  case Shape of
    clsRectangle:
      Result := TesselateRect(b);
    clsEllipse:
      Result := TesselateEllipse(b, STEP);
    clsRoundRect:
      Result := TesselateRoundRect(
        b, Min(b.Right - b.Left, b.Bottom - b.Top) div 3, STEP);
    clsRoundSide:
      Result := TesselateRoundRect(
        b, Min(b.Right - b.Left, b.Bottom - b.Top) div 2, STEP);
    clsUserDefined: ;
  end;
  if Assigned(OnGetShape) then
    OnGetShape(Self, b, Result);
  a := GetLabelAngle;
  for i := 0 to High(Result) do
    Result[i] := RotatePoint(Result[i], a);
end;

function TChartTextElement.GetLinkPen: TChartPen;
begin
  Result := nil;
end;

function TChartTextElement.GetTextRect: TRect;
begin
  Result := FTextRect;
end;

function TChartTextElement.GetTextShiftNeeded: Boolean;
var
  textdir: TDoublePoint;
  lSin, lCos: Math.float;
begin
  SinCos(-GetLabelAngle, lSin, lCos);
  textdir.y := lSin;
  textdir.x := lCos;
  Result := DotProduct(textdir, FInsideDir) > 0;
end;

function TChartTextElement.IsMarginRequired: Boolean;
begin
  Result := (GetLabelBrush.Style <> bsClear) or GetFrame.EffVisible;
end;

function TChartTextElement.MeasureLabel(
  ADrawer: IChartDrawer; const AText: String): TSize;
begin
  ApplyLabelFont(ADrawer);
  with GetBoundingBox(ADrawer, ADrawer.TextExtent(AText, FTextFormat)) do
    Result := MeasureRotatedRect(Point(Right - Left, Bottom - Top), GetLabelAngle);
end;

function TChartTextElement.MeasureLabelHeight(
  ADrawer: IChartDrawer; const AText: String): TSize;
var
  R: TRect;
begin
  ApplyLabelFont(ADrawer);
  R := Rect(0, 0, 0, ADrawer.TextExtent(AText, FTextFormat).y);
  OffsetRect(R, 0, -(R.Bottom - R.Top) div 2);
  if IsMarginRequired then
    Margins.ExpandRectScaled(ADrawer, R);
  Result := MeasureRotatedRect(Point(R.Right - R.Left, R.Bottom - R.Top), GetLabelAngle);
end;

procedure TChartTextElement.SetAlignment(AValue: TAlignment);
begin
  if FAlignment = AValue then exit;
  FAlignment := AValue;
  StyleChanged(Self);
end;

procedure TChartTextElement.SetCalloutAngle(AValue: Cardinal);
begin
  if FCalloutAngle = AValue then exit;
  FCalloutAngle := AValue;
  StyleChanged(Self);
end;

procedure TChartTextElement.SetClipped(AValue: Boolean);
begin
  if FClipped = AValue then exit;
  FClipped := AValue;
  StyleChanged(Self);
end;

procedure TChartTextElement.SetMargins(AValue: TChartLabelMargins);
begin
  if FMargins = AValue then exit;
  FMargins.Assign(AValue);
  StyleChanged(Self);
end;

procedure TChartTextElement.SetInsideDir(dx, dy: Double);
begin
  FInsideDir := DoublePoint(dx, dy);
end;

procedure TChartTextElement.SetOnGetShape(AValue: TChartGetShapeEvent);
begin
  if TMethod(FOnGetShape) = TMethod(AValue) then exit;
  FOnGetShape := AValue;
  StyleChanged(Self);
end;

procedure TChartTextElement.SetOverlapPolicy(AValue: TChartMarksOverlapPolicy);
begin
  if FOverlapPolicy = AValue then exit;
  FOverlapPolicy := AValue;
  StyleChanged(Self);
end;

procedure TChartTextElement.SetRotationCenter(AValue: TChartTextRotationCenter);
begin
  if FRotationCenter = AValue then exit;
  FRotationCenter := AValue;
  StyleChanged(Self);
end;

procedure TChartTextElement.SetShape(AValue: TChartLabelShape);
begin
  if FShape = AValue then exit;
  FShape := AValue;
  StyleChanged(Self);
end;

procedure TChartTextElement.SetTextFormat(AValue: TChartTextFormat);
begin
  if FTextFormat = AValue then exit;
  FTextFormat := AValue;
  StyleChanged(Self);
end;


{ TChartTitle }

procedure TChartTitle.Assign(ASource: TPersistent);
begin
  if ASource is TChartTitle then
    with TChartTitle(ASource) do begin
      Self.FBrush.Assign(Brush);
      Self.FFont.Assign(Font);
      Self.FFrame.Assign(Frame);
      Self.FText.Assign(Text);
   end;

  inherited Assign(ASource);
end;

constructor TChartTitle.Create(AOwner: TCustomChart);
begin
  inherited Create(AOwner);

  FAlignment := taCenter;
  InitHelper(FBrush, TBrush);
  FBrush.Color := FOwner.Color;
  InitHelper(FFont, TFont);
  FFont.Color := clDefault;
  InitHelper(FFrame, TChartTitleFramePen);
  FMargin := DEF_MARGIN;
  FText := TStringList.Create;
  TStringList(FText).OnChange := @StyleChanged;
end;

destructor TChartTitle.Destroy;
begin
  FreeAndNil(FBrush);
  FreeAndNil(FFont);
  FreeAndNil(FFrame);
  FreeAndNil(FText);

  inherited;
end;

procedure TChartTitle.Draw(ADrawer: IChartDrawer);
begin
  if not Visible or (Text.Count = 0) then exit;
  DrawLabel(ADrawer, FCenter, FCenter, GetRealCaption, FPolygon);
end;

function TChartTitle.GetFrame: TChartPen;
begin
  Result := Frame;
end;

function TChartTitle.GetLabelBrush: TBrush;
begin
  Result := Brush;
end;

function TChartTitle.GetLabelFont: TFont;
begin
  Result := Font;
end;

function TChartTitle.GetRealCaption: String;
begin
  if IsWordWrapped then
    Result := FWrappedCaption
  else
    Result := Text.Text;
end;

function TChartTitle.IsPointInBounds(APoint: TPoint): Boolean;
begin
  Result := IsPointInPolygon(APoint, FPolygon);
end;

function TChartTitle.IsWordWrapped: Boolean;
begin
  Result := FWordWrap and (Font.Orientation = 0);
end;

procedure TChartTitle.Measure(ADrawer: IChartDrawer;
  ADir, ALeft, ARight: Integer; var AY: Integer);
var
  ptSize: TPoint;
begin
  if not Visible or (Text.Count = 0) then exit;

  if IsWordWrapped then
    WordwrapCaption(ADrawer, ARight - ALeft);

  ptSize := MeasureLabel(ADrawer, GetRealCaption);
  case Alignment of
    taLeftJustify: FCenter.X := ALeft + ptSize.X div 2;
    taRightJustify: FCenter.X := ARight - ptSize.X div 2;
    taCenter: FCenter.X := (ALeft + ARight) div 2;
  end;
  FCenter.Y := AY + ADir * ptSize.Y div 2;
  AY += ADir * (ptSize.Y + Margin);
end;

procedure TChartTitle.SetBrush(AValue: TBrush);
begin
  FBrush.Assign(AValue);
  StyleChanged(Self);
end;

procedure TChartTitle.SetFont(AValue: TFont);
begin
  FFont.Assign(AValue);
  StyleChanged(Self);
end;

procedure TChartTitle.SetFrame(AValue: TChartTitleFramePen);
begin
  FFrame.Assign(AValue);
  StyleChanged(Self);
end;

procedure TChartTitle.SetMargin(AValue: TChartDistance);
begin
  if FMargin = AValue then exit;
  FMargin := AValue;
  StyleChanged(Self);
end;

procedure TChartTitle.SetText(AValue: TStrings);
begin
  FText.Assign(AValue);
  StyleChanged(Self);
end;

procedure TChartTitle.SetWordWrap(AValue: Boolean);
begin
  if FWordwrap = AValue then exit;
  FWordwrap := AValue;
  StyleChanged(Self);
end;

procedure TChartTitle.UpdateBidiMode;
begin
  case Alignment of
    taLeftJustify  : Alignment := taRightJustify;
    taRightJustify : Alignment := taLeftJustify;
  end;
end;

procedure TChartTitle.WordwrapCaption(ADrawer: IChartDrawer; AMaxWidth: Integer);
begin
  ADrawer.Font := Font;
  FWrappedCaption := TADrawUtils.Wordwrap(Text.Text, ADrawer, AMaxWidth, TextFormat);
end;

{ TGenericChartMarks }

procedure TGenericChartMarks.ApplyLabelFont(ADrawer: IChartDrawer);
begin
  inherited ApplyLabelFont(ADrawer);
  if FAdditionalAngle <> 0 then
    ADrawer.AddToFontOrientation(RadToOrient(FAdditionalAngle));
end;

procedure TGenericChartMarks.Assign(ASource: TPersistent);
begin
  if ASource is Self.ClassType then
    with TGenericChartMarks(ASource) do begin
      Self.FArrow.Assign(FArrow);
      Self.FAutoMargins := FAutoMargins;
      Self.FAttachment := FAttachment;
      Self.FDistance := FDistance;
      Self.FLinkDistance := FLinkDistance;
      Self.FFormat := FFormat;
      Self.FFrame.Assign(FFrame);
      // FPC miscompiles virtual calls to generic type arguments,
      // so as a workaround these assignments are moved to the specializations.
      // Self.FLabelBrush.Assign(FLabelBrush);
      // Self.FLabelFont.Assign(FLabelFont);
      // Self.FLinkPen.Assign(FLinkPen);
      Self.FStyle := FStyle;
      Self.FYIndex := FYIndex;
    end;
  inherited Assign(ASource);
end;

function TGenericChartMarks.CenterHeightOffset(
  ADrawer: IChartDrawer; const AText: String): TSize;
var
  d: Integer;
begin
  d := ADrawer.Scale(Distance);
  Result := Size(d, d) + MeasureLabelHeight(ADrawer, AText) div 2;
end;

function TGenericChartMarks.CenterOffset(
  ADrawer: IChartDrawer; const AText: String): TSize;
var
  d: Integer;
begin
  d := ADrawer.Scale(Distance);
  Result := Size(d, d);
  if not DistanceToCenter then
    Result += MeasureLabel(ADrawer, AText) div 2;
end;

constructor TGenericChartMarks.Create(AOwner: TCustomChart);
begin
  inherited Create(AOwner);
  FArrow := TChartArrow.Create(AOwner);
  FAutoMargins := true;
  InitHelper(FFrame, _TFramePen);
  InitHelper(FLabelBrush, _TLabelBrush);
  InitHelper(FLabelFont, TFont);
  InitHelper(FLinkPen, _TLinkPen);
  FStyle := smsNone;
  FVisible := true;
end;

destructor TGenericChartMarks.Destroy;
begin
  FreeAndNil(FArrow);
  FreeAndNil(FFrame);
  FreeAndNil(FLabelBrush);
  FreeAndNil(FLabelFont);
  FreeAndNil(FLinkPen);
  inherited;
end;

procedure TGenericChartMarks.DrawLink(
  ADrawer: IChartDrawer; ADataPoint, ALabelCenter: TPoint);
var
  phi: Double;
begin
  if ADataPoint = ALabelCenter then exit;

  with (ADataPoint - ALabelCenter) do phi := ArcTan2(Y, X);
  if (FLinkDistance <> 0) then
    ADataPoint := ADataPoint + Point(round(FLinkDistance*cos(phi)), -round(FLinkDistance*sin(phi)));

  inherited;

  Arrow.Draw(ADrawer, ADataPoint, phi, GetLinkPen);
end;

function TGenericChartMarks.GetDistanceToCenter: Boolean;
begin
  Result := Attachment = maCenter;
end;

function TGenericChartMarks.GetFrame: TChartPen;
begin
  Result := Frame;
end;

function TGenericChartMarks.GetLabelAngle: Double;
begin
  Result := inherited GetLabelAngle - FAdditionalAngle;
end;

function TGenericChartMarks.GetLabelBrush: TBrush;
begin
  Result := LabelBrush;
end;

function TGenericChartMarks.GetLabelFont: TFont;
begin
  Result := LabelFont;
end;

function TGenericChartMarks.GetLinkPen: TChartPen;
begin
  Result := LinkPen;
end;

function TGenericChartMarks.IsMarkLabelsVisible: Boolean;
begin
  Result := Visible and (Style <> smsNone) and (Format <> '');
end;

procedure TGenericChartMarks.SetAdditionalAngle(AAngle: Double);
begin
  FAdditionalAngle := AAngle;
end;

procedure TGenericChartMarks.SetArrow(AValue: TChartArrow);
begin
  if FArrow = AValue then exit;
  FArrow.Assign(AValue);
  StyleChanged(Self);
end;

procedure TGenericChartMarks.SetAttachment(AValue: TChartMarkAttachment);
begin
  if FAttachment = AValue then exit;
  FAttachment := AValue;
  StyleChanged(Self);
end;

procedure TGenericChartMarks.SetAutoMargins(AValue: Boolean);
begin
  if FAutoMargins = AValue then exit;
  FAutoMargins := AValue;
  StyleChanged(Self);
end;

procedure TGenericChartMarks.SetDistance(AValue: TChartDistance);
begin
  if FDistance = AValue then exit;
  FDistance := AValue;
  StyleChanged(Self);
end;

procedure TGenericChartMarks.SetDistanceToCenter(AValue: Boolean);
begin
  if AValue then
    Attachment := maCenter
  else
    Attachment := maDefault;
end;

procedure TGenericChartMarks.SetFormat(AValue: String);
begin
  if FFormat = AValue then exit;
  TCustomChartSource.CheckFormat(AValue);
  FFormat := AValue;
  FStyle := High(FStyle);
  while (FStyle > smsCustom) and (SERIES_MARK_FORMATS[FStyle] <> AValue) do
    Dec(FStyle);
  StyleChanged(Self);
end;

procedure TGenericChartMarks.SetFrame(AValue: _TFramePen);
begin
  if FFrame = AValue then exit;
  FFrame.Assign(AValue);
  StyleChanged(Self);
end;

procedure TGenericChartMarks.SetLabelBrush(AValue: _TLabelBrush);
begin
  if FLabelBrush = AValue then exit;
  FLabelBrush.Assign(AValue);
  StyleChanged(Self);
end;

procedure TGenericChartMarks.SetLabelFont(AValue: TFont);
begin
  if FLabelFont = AValue then exit;
  FLabelFont.Assign(AValue);
  StyleChanged(Self);
end;

procedure TGenericChartMarks.SetLinkDistance(AValue: Integer);
begin
  if FLinkDistance = AValue then exit;
  FLinkDistance := AValue;
  StyleChanged(Self);
end;

procedure TGenericChartMarks.SetLinkPen(AValue: _TLinkPen);
begin
  if FLinkPen = AValue then exit;
  FLinkPen.Assign(AValue);
  StyleChanged(Self);
end;

procedure TGenericChartMarks.SetStyle(AValue: TSeriesMarksStyle);
begin
  if FStyle = AValue then exit;
  FStyle := AValue;
  if FStyle <> smsCustom then
    FFormat := SERIES_MARK_FORMATS[FStyle];
  StyleChanged(Self);
end;

procedure TGenericChartMarks.SetYIndex(AValue: Integer);
begin
  if FYIndex = AValue then exit;
  FYIndex := AValue;
  StyleChanged(Self);
end;

{ TChartMarks }

procedure TChartMarks.Assign(Source: TPersistent);
begin
  if Source is TChartMarks then
    with TChartMarks(Source) do begin
      Self.FLabelBrush.Assign(FLabelBrush);
      Self.FLabelFont.Assign(FLabelFont);
      Self.FLinkPen.Assign(FLinkPen);
    end;
  inherited Assign(Source);
end;

constructor TChartMarks.Create(AOwner: TCustomChart);
begin
  inherited Create(AOwner);
  FDistance := DEF_MARKS_DISTANCE;
  FLabelBrush.Color := clYellow;
end;

end.


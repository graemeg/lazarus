{

 *****************************************************************************
  See the file COPYING.modifiedLGPL.txt, included in this distribution,
  for details about the license.
 *****************************************************************************

  Authors: Alexander Klenin

}

unit TACustomSource;

{$mode objfpc}{$H+}
{$modeswitch advancedrecords}

interface

uses
  Classes, Types, TAChartUtils;

type
  TAxisIntervalParamOption = (
    aipGraphCoords,
    aipUseCount, aipUseMaxLength, aipUseMinLength, aipUseNiceSteps);

const
  DEF_INTERVAL_STEPS = '0.2|0.5|1.0';
  DEF_INTERVAL_OPTIONS = [aipUseMaxLength, aipUseMinLength, aipUseNiceSteps];

type
  TAxisIntervalParamOptions = set of TAxisIntervalParamOption;

  TChartAxisIntervalParams = class(TPersistent)
  strict private
    FCount: Integer;
    FMaxLength: Integer;
    FMinLength: Integer;
    FNiceSteps: String;
    FOptions: TAxisIntervalParamOptions;
    FOwner: TPersistent;
    FStepValues: TDoubleDynArray;
    FTolerance: Cardinal;
    function NiceStepsIsStored: Boolean;
    procedure ParseNiceSteps;
    procedure SetCount(AValue: Integer);
    procedure SetMaxLength(AValue: Integer);
    procedure SetMinLength(AValue: Integer);
    procedure SetNiceSteps(const AValue: String);
    procedure SetOptions(AValue: TAxisIntervalParamOptions);
    procedure SetTolerance(AValue: Cardinal);
  strict protected
    procedure Changed; virtual;
  protected
    function GetOwner: TPersistent; override;
  public
    procedure Assign(ASource: TPersistent); override;
    constructor Create(AOwner: TPersistent);
    property StepValues: TDoubleDynArray read FStepValues;
  published
    property Count: Integer read FCount write SetCount default 5;
    property MaxLength: Integer read FMaxLength write SetMaxLength default 50;
    property MinLength: Integer read FMinLength write SetMinLength default 10;
    property NiceSteps: String
      read FNiceSteps write SetNiceSteps stored NiceStepsIsStored;
    property Options: TAxisIntervalParamOptions
      read FOptions write SetOptions default DEF_INTERVAL_OPTIONS;
    property Tolerance: Cardinal read FTolerance write SetTolerance default 0;
  end;

type
  EBufferError = class(EChartError);
  EEditableSourceRequired = class(EChartError);
  EListSourceStringError = class(EChartError);
  ESortError = class(EChartError);
  EXCountError = class(EChartError);
  EYCountError = class(EChartError);

  TChartValueText = record
    FText: String;
    FValue: Double;
  end;
  PChartValueText = ^TChartValueText;

  TChartValueTextArray = array of TChartValueText;

  TChartDataItem = packed record
  public
    X, Y: Double;
    Color: TChartColor;
    Text: String;
    XList: TDoubleDynArray;
    YList: TDoubleDynArray;
    function GetX(AIndex: Integer): Double;
    function GetY(AIndex: Integer): Double;
    procedure SetX(AIndex: Integer; const AValue: Double);
    procedure SetX(const AValue: Double);
    procedure SetY(AIndex: Integer; const AValue: Double);
    procedure SetY(const AValue: Double);
    procedure MultiplyY(const ACoeff: Double);
    function Point: TDoublePoint; inline;
    procedure MakeUnique;
  end;
  PChartDataItem = ^TChartDataItem;

  TGraphToImageFunc = function (AX: Double): Integer of object;
  TIntegerTransformFunc = function (AX: Integer): Integer of object;

  TValuesInRangeParams = object
    FAxisToGraph: TTransformFunc;
    FFormat: String;
    FGraphToAxis: TTransformFunc;
    FGraphToImage: TGraphToImageFunc;
    FIntervals: TChartAxisIntervalParams;
    FMin, FMax: Double;
    FMinStep: Double;
    FScale: TIntegerTransformFunc;
    FUseY: Boolean;

    function CountToStep(ACount: Integer): Double; inline;
    function IsAcceptableStep(AStep: Int64): Boolean; inline;
    procedure RoundToImage(var AValue: Double);
    function ToImage(AX: Double): Integer; inline;
  end;

  TBasicChartSource = class(TComponent)
  strict private
    FBroadcaster: TBroadcaster;
  strict protected
    FUpdateCount: Integer;
    procedure Notify;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure BeginUpdate; virtual;
    procedure EndUpdate; virtual;
    function IsUpdating: Boolean; inline;
    property Broadcaster: TBroadcaster read FBroadcaster;
  end;

  TCustomChartSource = class;

  TCustomChartSourceEnumerator = class
  strict private
    FSource: TCustomChartSource;
    FIndex: Integer;
  public
    constructor Create(ASource: TCustomChartSource);
    function GetCurrent: PChartDataItem;
    function MoveNext: Boolean;
    procedure Reset;
    property Current: PChartDataItem read GetCurrent;
  end;

  TChartErrorBarKind = (ebkNone, ebkConst, ebkPercent, ebkChartSource);

  TChartErrorBarData = class(TPersistent)
  private
    FKind: TChartErrorBarKind;
    FValue: array[0..1] of Double;  // 0 = positive, 1 = negative
    FIndex: array[0..1] of Integer;
    FOnChange: TNotifyEvent;
    procedure Changed;
    function GetIndex(AIndex: Integer): Integer;
    function GetValue(AIndex: Integer): Double;
    function IsErrorBarValueStored(AIndex: Integer): Boolean;
    procedure SetKind(AValue: TChartErrorBarKind);
    procedure SetIndex(AIndex, AValue: Integer);
    procedure SetValue(AIndex: Integer; const AValue: Double);
  public
    constructor Create;
    procedure Assign(ASource: TPersistent); override;
    property OnChange: TNotifyEvent read FOnChange write FOnChange;
  published
    property Kind: TChartErrorBarKind read FKind write SetKind default ebkNone;
    property IndexMinus: Integer index 1 read GetIndex write SetIndex default -1;
    property IndexPlus: Integer index 0 read GetIndex write SetIndex default -1;
    property ValueMinus: Double index 1 read GetValue write SetValue stored IsErrorBarValueStored;
    property ValuePlus: Double index 0 read GetValue write SetValue stored IsErrorBarValueStored;
  end;

  TChartSortBy = (sbX, sbY, sbColor, sbText, sbCustom);
  TChartSortDir = (sdAscending, sdDescending);

  TCustomChartSource = class(TBasicChartSource)
  strict private
    FErrorBarData: array[0..1] of TChartErrorBarData;
    function GetErrorBarData(AIndex: Integer): TChartErrorBarData;
    function IsErrorBarDataStored(AIndex: Integer): Boolean;
    procedure SetErrorBarData(AIndex: Integer; AValue: TChartErrorBarData);
    procedure SortValuesInRange(
      var AValues: TChartValueTextArray; AStart, AEnd: Integer);
  strict protected
    FBasicExtent: TDoubleRect;
    FBasicExtentIsValid: Boolean;
    FCumulativeExtent: TDoubleRect;
    FCumulativeExtentIsValid: Boolean;
    FXListExtent: TDoubleRect;
    FXListExtentIsValid: Boolean;
    FYListExtent: TDoubleRect;
    FYListExtentIsValid: Boolean;
    FValuesTotal: Double;
    FValuesTotalIsValid: Boolean;
    FSortBy: TChartSortBy;
    FSortDir: TChartSortDir;
    FSortIndex: Cardinal;
    FXCount: Cardinal;
    FYCount: Cardinal;
    function CalcExtentXYList(UseXList: Boolean): TDoubleRect;
    procedure ChangeErrorBars(Sender: TObject); virtual;
    function GetCount: Integer; virtual; abstract;
    function GetErrorBarValues(APointIndex: Integer; Which: Integer;
      out AUpperDelta, ALowerDelta: Double): Boolean;
    function GetHasErrorBars(Which: Integer): Boolean;
    function GetItem(AIndex: Integer): PChartDataItem; virtual; abstract;
    function HasSameSorting(ASource: TCustomChartSource): Boolean; virtual;
    procedure InvalidateCaches;
    procedure SetSortBy(AValue: TChartSortBy); virtual;
    procedure SetSortDir(AValue: TChartSortDir); virtual;
    procedure SetSortIndex(AValue: Cardinal); virtual;
    procedure SetXCount(AValue: Cardinal); virtual; abstract;
    procedure SetYCount(AValue: Cardinal); virtual; abstract;
    property XErrorBarData: TChartErrorBarData index 0 read GetErrorBarData
      write SetErrorBarData stored IsErrorBarDataStored;
    property YErrorBarData: TChartErrorBarData index 1 read GetErrorBarData
      write SetErrorBarData stored IsErrorBarDataStored;
  protected
    property SortBy: TChartSortBy read FSortBy write SetSortBy default sbX;
    property SortDir: TChartSortDir read FSortDir write SetSortDir default sdAscending;
    property SortIndex: Cardinal read FSortIndex write SetSortIndex default 0;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  public
    procedure AfterDraw; virtual;
    procedure BeforeDraw; virtual;
    procedure BeginUpdate; override;
    procedure EndUpdate; override;
  public
    class procedure CheckFormat(const AFormat: String);
    function BasicExtent: TDoubleRect; virtual;
    function Extent: TDoubleRect; virtual;
    function ExtentCumulative: TDoubleRect; virtual;
    function ExtentList: TDoubleRect; virtual;
    function ExtentXYList: TDoubleRect; virtual;
    procedure FindBounds(AXMin, AXMax: Double; out ALB, AUB: Integer);
    procedure FindYRange(AXMin, AXMax: Double; Stacked: Boolean;
      var AYMin, AYMax: Double);
    function FormatItem(
      const AFormat: String; AIndex, AYIndex: Integer): String; inline;
    function FormatItemXYText(
      const AFormat: String; const AX, AY: Double; const AText: String): String;
    function GetEnumerator: TCustomChartSourceEnumerator;
    function GetXErrorBarLimits(APointIndex: Integer;
      out AUpperLimit, ALowerLimit: Double): Boolean;
    function GetYErrorBarLimits(APointIndex: Integer;
      out AUpperLimit, ALowerLimit: Double): Boolean;
    function GetXErrorBarValues(APointIndex: Integer;
      out AUpperDelta, ALowerDelta: Double): Boolean;
    function GetYErrorBarValues(APointIndex: Integer;
      out AUpperDelta, ALowerDelta: Double): Boolean;
    function HasXErrorBars: Boolean;
    function HasYErrorBars: Boolean;
    function IsXErrorIndex(AXIndex: Integer): Boolean;
    function IsYErrorIndex(AYIndex: Integer): Boolean;
    function IsSorted: Boolean; virtual;
    function IsSortedByXAsc: Boolean;
    procedure ValuesInRange(
      AParams: TValuesInRangeParams; var AValues: TChartValueTextArray); virtual;
    function ValuesTotal: Double; virtual;
    function XOfMax(AIndex: Integer = 0): Double;
    function XOfMin(AIndex: Integer = 0): Double;

    property Count: Integer read GetCount;
    property Item[AIndex: Integer]: PChartDataItem read GetItem; default;
    property XCount: Cardinal read FXCount write SetXCount default 1;
    property YCount: Cardinal read FYCount write SetYCount default 1;
  end;

  TChartSortCompare = function(AItem1, AItem2: Pointer): Integer of object;

  { TCustomSortedChartSource }

  TCustomSortedChartSource = class(TCustomChartSource)
  private
    FUseSortedAutoDetection: Boolean;
    FOnCompare: TChartSortCompare;
    procedure SetOnCompare(AValue: TChartSortCompare);
    procedure SetSorted(AValue: Boolean);
    procedure SetUseSortedAutoDetection(AValue: Boolean);
  protected
    FData: TFPList;
    FSorted: Boolean;
    FSortedAutoDetected: Boolean;
    function DoCompare(AItem1, AItem2: Pointer): Integer; virtual;
    procedure DoSort; virtual;
    function GetCount: Integer; override;
    function GetItem(AIndex: Integer): PChartDataItem; override;
    function GetItemInternal(AIndex: Integer): PChartDataItem; inline;
    function ItemAdd(AItem: PChartDataItem): Integer;
    procedure ItemInsert(AIndex: Integer; AItem: PChartDataItem);
    function ItemFind(AItem: PChartDataItem; L: Integer = 0; R: Integer = High(Integer)): Integer;
    function ItemModified(AIndex: Integer): Integer;
    procedure ItemDeleted({%H-}AIndex: Integer); // pass -1 if all items were deleted at once
    procedure ResetSortedAutoDetection;
    procedure SetSortedAutoDetected;
    procedure SetSortBy(AValue: TChartSortBy); override;
    procedure SetSortDir(AValue: TChartSortDir); override;
    procedure SetSortIndex(AValue: Cardinal); override;
    procedure SortNoNotify; inline;
    property ItemInternal[AIndex: Integer]: PChartDataItem read GetItemInternal;
    property OnCompare: TChartSortCompare read FOnCompare write SetOnCompare;
    property Sorted: Boolean read FSorted write SetSorted default false;
    property UseSortedAutoDetection: Boolean
      read FUseSortedAutoDetection write SetUseSortedAutoDetection default false;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  public
    function IsSorted: Boolean; override;
    procedure Sort;
  end;

  { TChartSourceBuffer }

  TChartSourceBuffer = class
  strict private
    FBuf: array of TChartDataItem;
    FCount: Cardinal;
    FStart: Cardinal;
    FSum: TChartDataItem;
    procedure AddValue(const AItem: TChartDataItem);
    function EndIndex: Cardinal; inline;
    function GetCapacity: Cardinal; inline;
    procedure SetCapacity(AValue: Cardinal); inline;
  public
    procedure AddFirst(const AItem: TChartDataItem);
    procedure AddLast(const AItem: TChartDataItem);
    procedure Clear; inline;
    function GetPtr(AOffset: Cardinal): PChartDataItem; overload;
    procedure GetSum(var AItem: TChartDataItem);
    procedure RemoveFirst;
    procedure RemoveLast;
    procedure RemoveValue(const AItem: TChartDataItem);
    property Capacity: Cardinal read GetCapacity write SetCapacity;
  end;

procedure SetDataItemDefaults(var AItem: TChartDataItem);

implementation

uses
  Math, StrUtils, SysUtils, TAMath, TAChartStrConsts;

function CompareChartValueTextPtr(AItem1, AItem2: Pointer): Integer;
begin
  Result := CompareValue(
    PChartValueText(AItem1)^.FValue,
    PChartValueText(AItem2)^.FValue);
end;

function IsValueTextsSorted(
  const AValues: TChartValueTextArray; AStart, AEnd: Integer): Boolean;
var
  i: Integer;
begin
  for i := AStart to AEnd - 1 do
    if AValues[i].FValue > AValues[i + 1].FValue then exit(false);
  Result := true;
end;

procedure SetDataItemDefaults(var AItem: TChartDataItem);
var
  i: Integer;
begin
  AItem.X := 0;
  AItem.Y := 0;
  AItem.Color := clTAColor;
  AItem.Text := '';
  for i := 0 to High(AItem.XList) do
    AItem.XList[i] := 0;
  for i := 0 to High(AItem.YList) do
    AItem.YList[i] := 0;
end;

{ TValuesInRangeParams }

function TValuesInRangeParams.CountToStep(ACount: Integer): Double;
begin
  Result := Power(10, Floor(Log10((FMax - FMin) / ACount)));
end;

function TValuesInRangeParams.IsAcceptableStep(AStep: Int64): Boolean;
begin
  with FIntervals do
    Result := not (
      (aipUseMinLength in Options) and (AStep < FScale(MinLength)) or
      (aipUseMaxLength in Options) and (AStep > FScale(MaxLength)));
end;

procedure TValuesInRangeParams.RoundToImage(var AValue: Double);

  function A2I(const AX: Double): Integer; inline;
  begin
    Result := FGraphToImage(FAxisToGraph(AX));
  end;

var
  p, rv: Double;
  x: Int64;
begin
  if
    (FIntervals.Tolerance = 0) or (AValue = 0) or IsInfinite(AValue) or IsNan(AValue)
  then
    exit;
  x := A2I(AValue);
  p := Power(10, Floor(Log10(Abs(AValue)) - Log10(High(Int64)) + 1));
  while AValue <> 0 do begin
    rv := Round(AValue / p) * p;
    if Abs(A2I(rv) - x) >= FIntervals.Tolerance then break;
    AValue := rv;
    p *= 10;
  end;
end;

function TValuesInRangeParams.ToImage(AX: Double): Integer;
begin
  if not (aipGraphCoords in FIntervals.Options) then
    AX := FAxisToGraph(AX);
  Result := FGraphToImage(AX);
end;

{ TChartAxisIntervalParams }

procedure TChartAxisIntervalParams.Assign(ASource: TPersistent);
begin
  if ASource is TChartAxisIntervalParams then
    with TChartAxisIntervalParams(ASource) do begin
      Self.FCount := Count;
      Self.FMaxLength := MaxLength;
      Self.FMinLength := MinLength;
      Self.FNiceSteps := NiceSteps;
      Self.FOptions := Options;
    end
  else
    inherited Assign(ASource);
end;

procedure TChartAxisIntervalParams.Changed;
begin
  if not (FOwner is TCustomChartSource) then exit;
  with TCustomChartSource(FOwner) do begin
    BeginUpdate;
    EndUpdate;
  end;
end;

constructor TChartAxisIntervalParams.Create(AOwner: TPersistent);
begin
  FOwner := AOwner;
  SetPropDefaults(Self, ['Count', 'MaxLength', 'MinLength', 'Options']);
  FNiceSteps := DEF_INTERVAL_STEPS;
  ParseNiceSteps;
end;

function TChartAxisIntervalParams.GetOwner: TPersistent;
begin
  Result := FOwner;
end;

function TChartAxisIntervalParams.NiceStepsIsStored: Boolean;
begin
  Result := NiceSteps <> DEF_INTERVAL_STEPS;
end;

procedure TChartAxisIntervalParams.ParseNiceSteps;
var
  parts: TStrings;
  i: Integer;
begin
  parts := Split(StrUtils.IfThen(NiceSteps = '', DEF_INTERVAL_STEPS, NiceSteps));
  try
    SetLength(FStepValues, parts.Count);
    for i := 0 to parts.Count - 1 do
      FStepValues[i] := StrToFloatDefSep(parts[i]);
  finally
    parts.Free;
  end;
end;

procedure TChartAxisIntervalParams.SetCount(AValue: Integer);
begin
  if FCount = AValue then exit;
  FCount := AValue;
  Changed;
end;

procedure TChartAxisIntervalParams.SetMaxLength(AValue: Integer);
begin
  if FMaxLength = AValue then exit;
  FMaxLength := AValue;
  Changed;
end;

procedure TChartAxisIntervalParams.SetMinLength(AValue: Integer);
begin
  if FMinLength = AValue then exit;
  FMinLength := AValue;
  Changed;
end;

procedure TChartAxisIntervalParams.SetNiceSteps(const AValue: String);
begin
  if FNiceSteps = AValue then exit;
  FNiceSteps := AValue;
  ParseNiceSteps;
  Changed;
end;

procedure TChartAxisIntervalParams.SetOptions(
  AValue: TAxisIntervalParamOptions);
begin
  if FOptions = AValue then exit;
  FOptions := AValue;
  Changed;
end;

procedure TChartAxisIntervalParams.SetTolerance(AValue: Cardinal);
begin
  if FTolerance = AValue then exit;
  FTolerance := AValue;
  Changed;
end;

{ TChartDataItem }

function TChartDataItem.GetX(AIndex: Integer): Double;
begin
  AIndex := EnsureRange(AIndex, 0, Length(XList));
  if AIndex = 0 then
    Result := X
  else
    Result := XList[AIndex - 1];
end;

function TChartDataItem.GetY(AIndex: Integer): Double;
begin
  AIndex := EnsureRange(AIndex, 0, Length(YList));
  if AIndex = 0 then
    Result := Y
  else
    Result := YList[AIndex - 1];
end;

procedure TChartDataItem.MakeUnique;
begin
  // using SetLength() is a documented way of making the dynamic array unique:
  // "the reference count after a call to SetLength will be 1"
  UniqueString(Text);
  SetLength(XList, Length(XList));
  SetLength(YList, Length(YList));
end;

procedure TChartDataItem.MultiplyY(const ACoeff: Double);
var
  i: Integer;
begin
  Y *= ACoeff;
  for i := 0 to High(YList) do
    YList[i] *= ACoeff;
end;

function TChartDataItem.Point: TDoublePoint;
begin
  Result.X := X;
  Result.Y := Y;
end;

procedure TChartDataItem.SetX(const AValue: Double);
var
  i: Integer;
begin
  X := AValue;
  for i := 0 to High(XList) do
    XList[i] := AValue;
end;

procedure TChartDataItem.SetX(AIndex: Integer; const AValue: Double);
begin
  if AIndex = 0 then
    X := AValue
  else
    XList[AIndex - 1] := AValue;
end;

procedure TChartDataItem.SetY(const AValue: Double);
var
  i: Integer;
begin
  Y := AValue;
  for i := 0 to High(YList) do
    YList[i] := AValue;
end;

procedure TChartDataItem.SetY(AIndex: Integer; const AValue: Double);
begin
  if AIndex = 0 then
    Y := AValue
  else
    YList[AIndex - 1] := AValue;
end;


{ TBasicChartSource }

constructor TBasicChartSource.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FBroadcaster := TBroadcaster.Create;
end;

destructor TBasicChartSource.Destroy;
begin
  FreeAndNil(FBroadcaster);
  inherited Destroy;
end;

procedure TBasicChartSource.BeginUpdate;
begin
  Inc(FUpdateCount);
end;

procedure TBasicChartSource.EndUpdate;
begin
  Dec(FUpdateCount);
  if FUpdateCount > 0 then exit;
  Notify;
end;

function TBasicChartSource.IsUpdating: Boolean; inline;
begin
  Result := FUpdateCount > 0;
end;

procedure TBasicChartSource.Notify;
begin
  if not IsUpdating then
    FBroadcaster.Broadcast(Self);
end;


{ TChartSourceBuffer }

procedure TChartSourceBuffer.AddFirst(const AItem: TChartDataItem);
begin
  if Capacity = 0 then
    raise EBufferError.Create('');
  FStart := (FStart + Cardinal(High(FBuf))) mod Capacity;
  if FCount = Capacity then
    RemoveValue(FBuf[FStart])
  else
    FCount += 1;
  FBuf[FStart] := AItem;
  AddValue(AItem);
end;

procedure TChartSourceBuffer.AddLast(const AItem: TChartDataItem);
begin
  if Capacity > 0 then
    if FCount = Capacity then begin
      RemoveValue(FBuf[FStart]);
      FBuf[FStart] := AItem;
      FStart := (FStart + 1) mod Capacity;
    end
    else begin
      FCount += 1;
      FBuf[EndIndex] := AItem;
    end;
  AddValue(AItem);
end;

procedure TChartSourceBuffer.AddValue(const AItem: TChartDataItem);
var
  i, oldLen: Integer;
begin
  with FSum do begin
    Y += AItem.Y;
    oldLen := Length(YList);
    SetLength(YList, Max(Length(AItem.YList), oldLen));
    for i := oldLen to High(YList) do
      YList[i] := 0;
    for i := 0 to Min(High(YList), High(AItem.YList)) do
      YList[i] += AItem.YList[i];
  end;
end;

procedure TChartSourceBuffer.Clear;
begin
  FCount := 0;
  FStart := 0;
  FSum.Y := 0;
  FSum.YList := nil;
end;

function TChartSourceBuffer.EndIndex: Cardinal;
begin
  Result := (FStart + Cardinal(FCount - 1)) mod Capacity;
end;

function TChartSourceBuffer.GetCapacity: Cardinal;
begin
  Result := Length(FBuf);
end;

function TChartSourceBuffer.GetPtr(AOffset: Cardinal): PChartDataItem;
begin
  if AOffset >= FCount then
    raise EBufferError.Create('AOffset');
  Result := @FBuf[(FStart + AOffset + Capacity) mod Capacity];
end;

procedure TChartSourceBuffer.GetSum(var AItem: TChartDataItem);
begin
  AItem.Y := FSum.Y;
  AItem.YList := Copy(FSum.YList);
end;

procedure TChartSourceBuffer.RemoveFirst;
begin
  if FCount = 0 then
    raise EBufferError.Create('Empty');
  RemoveValue(FBuf[FStart]);
  FCount -= 1;
  FStart := (FStart + 1) mod Capacity;
end;

procedure TChartSourceBuffer.RemoveLast;
begin
  if FCount = 0 then
    raise EBufferError.Create('Empty');
  RemoveValue(FBuf[EndIndex]);
  FCount -= 1;
end;

procedure TChartSourceBuffer.RemoveValue(const AItem: TChartDataItem);
var
  i: Integer;
begin
  with AItem do begin
    FSum.Y -= Y;
    for i := 0 to Min(High(FSum.YList), High(YList)) do
      FSum.YList[i] -= YList[i];
  end;
end;

procedure TChartSourceBuffer.SetCapacity(AValue: Cardinal);
begin
  if AValue = Capacity then exit;
  SetLength(FBuf, AValue);
  Clear;
end;

{ TCustomChartSourceEnumerator }

constructor TCustomChartSourceEnumerator.Create(ASource: TCustomChartSource);
begin
  FSource := ASource;
  FIndex := -1;
end;

function TCustomChartSourceEnumerator.GetCurrent: PChartDataItem;
begin
  Result := FSource[FIndex];
end;

function TCustomChartSourceEnumerator.MoveNext: Boolean;
begin
  FIndex += 1;
  Result := FIndex < FSource.Count;
end;

procedure TCustomChartSourceEnumerator.Reset;
begin
  FIndex := 0;
end;


{ TChartErrorBarData }

constructor TChartErrorBarData.Create;
begin
  inherited;
  FIndex[0] := -1;
  FIndex[1] := -1;
  FValue[0] := 0;
  FValue[1] := -1;
  FKind := ebkNone;
end;

procedure TChartErrorBarData.Assign(ASource: TPersistent);
begin
  if ASource is TChartErrorBarData then begin
    FValue := TChartErrorBarData(ASource).FValue;
    FIndex := TChartErrorBarData(ASource).FIndex;
    FKind := TChartErrorBarData(ASource).Kind;
  end else
    inherited;
end;

procedure TChartErrorBarData.Changed;
begin
  if Assigned(FOnChange) then FOnChange(Self);
end;

function TChartErrorBarData.GetIndex(AIndex: Integer): Integer;
begin
  Result := FIndex[AIndex];
end;

function TChartErrorBarData.GetValue(AIndex: Integer): Double;
begin
  Result := FValue[AIndex];
end;

function TChartErrorBarData.IsErrorBarValueStored(AIndex: Integer): Boolean;
begin
  if AIndex = 0 then
    Result := FValue[0] <> 0
  else
    Result := FValue[1] <> -1;
end;

procedure TChartErrorBarData.SetIndex(AIndex, AValue: Integer);
begin
  if FIndex[AIndex] = AValue then exit;
  FIndex[AIndex] := AValue;
  Changed;
end;

procedure TChartErrorBarData.SetKind(AValue: TChartErrorBarKind);
begin
  if FKind = AValue then exit;
  FKind := AValue;
  Changed;
end;

procedure TChartErrorBarData.SetValue(AIndex: Integer; const AValue: Double);
begin
  if FValue[AIndex] = AValue then exit;
  FValue[AIndex] := AValue;
  Changed;
end;


{ TCustomChartSource }

procedure TCustomChartSource.AfterDraw;
begin
  // empty
end;

function TCustomChartSource.BasicExtent: TDoubleRect;
var
  i: Integer;
  vhi, vlo: Double;
begin
  if FBasicExtentIsValid then
    exit(FBasicExtent);

  FBasicExtent := EmptyExtent;

  if Count > 0 then begin
    if XCount > 0 then begin
      if HasXErrorBars then
        for i := 0 to Count - 1 do begin
          GetXErrorBarLimits(i, vhi, vlo);
          UpdateMinMax(vhi, FBasicExtent.a.X, FBasicExtent.b.X);
          UpdateMinMax(vlo, FBasicExtent.a.X, FBasicExtent.b.X);
        end
      else
      if IsSorted and (FSortBy = sbX) and (FSortIndex = 0) then begin
        UpdateMinMax(Item[0]^.X, FBasicExtent.a.X, FBasicExtent.b.X);
        UpdateMinMax(Item[Count-1]^.X, FBasicExtent.a.X, FBasicExtent.b.X);
      end else
        for i:=0 to Count - 1 do
          UpdateMinMax(Item[i]^.X, FBasicExtent.a.X, FBasicExtent.b.X);
    end else begin
      FBasicExtent.a.X := 0;
      FBasicExtent.b.X := Count - 1;
    end;

    if YCount > 0 then begin
      if HasYErrorBars then
        for i := 0 to Count - 1 do begin
          GetYErrorBarLimits(i, vhi, vlo);
          UpdateMinMax(vhi, FBasicExtent.a.Y, FBasicExtent.b.Y);
          UpdateMinMax(vlo, FBasicExtent.a.Y, FBasicExtent.b.Y);
        end
      else
      if IsSorted and (FSortBy = sbY) and (FSortIndex = 0) then begin
        UpdateMinMax(Item[0]^.Y, FBasicExtent.a.Y, FBasicExtent.b.Y);
        UpdateMinMax(Item[Count-1]^.Y, FBasicExtent.a.Y, FBasicExtent.b.Y);
      end else
        for i:=0 to Count - 1 do
          UpdateMinMax(Item[i]^.Y, FBasicExtent.a.Y, FBasicExtent.b.Y);
    end;
  end;

  FBasicExtentIsValid := not IsUpdating;  // When updating, we are not allowed
    // to set "Valid" for caches - see comment in TListChartSource.ClearCaches()
  Result := FBasicExtent;
end;

procedure TCustomChartSource.BeforeDraw;
begin
  // empty
end;

{ Calculates the extent including multiple x and/or y values (non-stacked)
  UseXList = true: consider both XList and YList, otherwise only YList. }
function TCustomChartSource.CalcExtentXYList(UseXList: Boolean): TDoubleRect;
var
  i, j: Integer;
  jxp, jxn: Integer;
  jyp, jyn: Integer;
begin
  Result := Extent;

  if UseXList and (XCount > 1) then begin
    if not FXListExtentIsValid then begin
      FXListExtent := EmptyExtent;

      // Skip the x values used for error bars when calculating the list extent.
      if XErrorBarData.Kind = ebkChartSource then begin
        jxp := XErrorBarData.IndexPlus - 1;  // -1 because XList index is offset by 1
        jxn := XErrorBarData.IndexMinus - 1;
      end else begin
        jxp := -1;
        jxn := -1;
      end;

      for i := 0 to Count - 1 do
        with Item[i]^ do begin
          for j := 0 to High(XList) do
            if (j <> jxp) and (j <> jxn) then
              UpdateMinMax(XList[j], FXListExtent.a.X, FXListExtent.b.X);
        end;

      FXListExtentIsValid := not IsUpdating;  // When updating, we are not allowed
        // to set "Valid" for caches - see comment in TListChartSource.ClearCaches()
    end;

    Result.a.X := Min(Result.a.X, FXListExtent.a.X);
    Result.b.X := Max(Result.b.X, FXListExtent.b.X);
  end;

  if (YCount > 1) then begin
    if not FYListExtentIsValid then begin
      FYListExtent := EmptyExtent;

      // Skip the y values used for error bars when calculating the list extent.
      if YErrorBarData.Kind = ebkChartSource then begin
        jyp := YErrorBarData.IndexPlus - 1;  // -1 because YList index is offset by 1
        jyn := YErrorBarData.IndexMinus - 1;
      end else begin
        jyp := -1;
        jyn := -1;
      end;

      for i := 0 to Count - 1 do
        with Item[i]^ do begin
          for j := 0 to High(YList) do
            if (j <> jyp) and (j <> jyn) then
              UpdateMinMax(YList[j], FYListExtent.a.Y, FYListExtent.b.Y);
        end;

      FYListExtentIsValid := not IsUpdating;  // When updating, we are not allowed
        // to set "Valid" for caches - see comment in TListChartSource.ClearCaches()
    end;

    Result.a.Y := Min(Result.a.Y, FYListExtent.a.Y);
    Result.b.Y := Max(Result.b.Y, FYListExtent.b.Y);
  end;
end;

class procedure TCustomChartSource.CheckFormat(const AFormat: String);
begin
  Format(AFormat, [0.0, 0.0, '', 0.0, 0.0]);
end;

constructor TCustomChartSource.Create(AOwner: TComponent);
var
  i: Integer;
begin
  inherited Create(AOwner);
  FSortBy := sbX;
  FSortDir := sdAscending;
  FSortIndex := 0;
  FXCount := 1;
  FYCount := 1;
  for i:=Low(FErrorBarData) to High(FErrorBarData) do begin
    FErrorBarData[i] := TChartErrorBarData.Create;
    FErrorBarData[i].OnChange := @ChangeErrorBars;
  end;
end;

destructor TCustomChartSource.Destroy;
var
  i: Integer;
begin
  for i:= Low(FErrorBarData) to High(FErrorBarData) do
    FErrorBarData[i].Free;
  inherited;
end;

procedure TCustomChartSource.ChangeErrorBars(Sender: TObject);
begin
  Unused(Sender);
  InvalidateCaches;
  Notify;
end;

procedure TCustomChartSource.BeginUpdate;
begin
  // Caches will be eventually invalidated in a corresponding EndUpdate() call.
  // Since, at this moment, we are already sure, that caches will be invalidated,
  // it's better to invalidate them immediately - this will prevent useless efforts
  // to keep caches coherent between BeginUpdate() and EndUpdate() calls.
  if FUpdateCount = 0 then
    InvalidateCaches;
  Inc(FUpdateCount);
end;

procedure TCustomChartSource.EndUpdate;
begin
  Dec(FUpdateCount);
  if FUpdateCount > 0 then exit;
  // Values can be set directly between BeginUpdate and EndUpdate.
  InvalidateCaches;
  Notify;
end;

function TCustomChartSource.Extent: TDoubleRect;
begin
  Result := BasicExtent;
end;

{ Calculates the extent of multiple y values stacked onto each other. }
function TCustomChartSource.ExtentCumulative: TDoubleRect;
var
  h: Double;
  i, j: Integer;
  jyp, jyn: Integer;
begin
  Result := Extent;

  if (YCount > 1) then begin
    if not FCumulativeExtentIsValid then begin
      FCumulativeExtent := EmptyExtent;

      // Skip the y values used for error bars when calculating the cumulative sum.
      if YErrorBarData.Kind = ebkChartSource then begin
        jyp := YErrorBarData.IndexPlus - 1;  // -1 because YList index is offset by 1
        jyn := YErrorBarData.IndexMinus - 1;
      end else begin
        jyp := -1;
        jyn := -1;
      end;

      for i := 0 to Count - 1 do
        with Item[i]^ do begin
          h := NumberOr(Y);
          for j := 0 to High(YList) do
            if (j <> jyp) and (j <> jyn) then begin
              h += NumberOr(YList[j]);
              // If some of the Y values are negative, h may be non-monotonic.
              UpdateMinMax(h, FCumulativeExtent.a.Y, FCumulativeExtent.b.Y);
            end;
        end;

      FCumulativeExtentIsValid := not IsUpdating;  // When updating, we are not allowed
        // to set "Valid" for caches - see comment in TListChartSource.ClearCaches()
    end;

    Result.a.Y := Min(Result.a.Y, FCumulativeExtent.a.Y);
    Result.b.Y := Max(Result.b.Y, FCumulativeExtent.b.Y);
  end;
end;

{ Calculates the extent including multiple y values (non-stacked) }
function TCustomChartSource.ExtentList: TDoubleRect;
begin
  Result := CalcExtentXYList(false);
end;

{ Calculates the extent including multiple x and y values (non-stacked) }
function TCustomChartSource.ExtentXYList: TDoubleRect;
begin
  Result := CalcExtentXYList(true);
end;

// ALB -> leftmost item where X >= AXMin, or Count if no such item
// AUB -> rightmost item where X <= AXMax, or -1 if no such item
// If the source is sorted by X in the ascending order, performs
// binary search. Otherwise, skips NaNs.
procedure TCustomChartSource.FindBounds(
  AXMin, AXMax: Double; out ALB, AUB: Integer);

  function FindLB(const X: Double; L, R: Integer): Integer;
  begin
    while L <= R do begin
      Result := (R - L) div 2 + L;
      if Item[Result]^.X < X then
        L := Result + 1
      else
        R := Result - 1;
    end;
    Result := L;
  end;

  function FindUB(const X: Double; L, R: Integer): Integer;
  begin
    while L <= R do begin
      Result := (R - L) div 2 + L;
      if Item[Result]^.X <= X then
        L := Result + 1
      else
        R := Result - 1;
    end;
    Result := R;
  end;

begin
  EnsureOrder(AXMin, AXMax);
  if (XCount = 0) then begin
    if AXMin > Count-1 then ALB := Count
      else if AXMin < 0 then ALB := 0
      else ALB := ceil(AXMin);
    if AXMax > Count-1 then AUB := Count - 1
      else if AXMax < 0 then AUB := -1
      else AUB := trunc(AXMax);
  end else
  if IsSortedByXAsc then begin
    ALB := FindLB(AXMin, 0, Count - 1);
    AUB := FindUB(AXMax, 0, Count - 1);
  end
  else begin
    ALB := 0;
    while ALB < Count do begin
      with Item[ALB]^ do
        if not IsNan(X) and (X >= AXMin) then break;
      ALB += 1;
    end;
    AUB := Count - 1;
    while AUB >= 0 do begin
      with Item[AUB]^ do
        if not IsNan(X) and (X <= AXMax) then break;
      AUB -= 1;
    end;
  end;
end;

procedure TCustomChartSource.FindYRange(AXMin, AXMax: Double; Stacked: Boolean;
  var AYMin, AYMax: Double);
var
  lb, ub: Integer;
  i, j: Integer;
  sum: Double;
begin
  FindBounds(AXMin, AXMax, lb, ub);
  for i := lb to ub do
  begin
    if YCount = 1 then
      UpdateMinMax(Item[i]^.Y, AYMin, AYMax)
    else
      if Stacked then
      begin
        sum := Item[i]^.Y;
        for j := 0 to YCount-2 do
          sum := sum + Item[i]^.YList[j];
        UpdateMinMax(sum, AYMin, AYMax);
      end else
      begin
        UpdateMinMax(Item[i]^.Y, AYMin, AYMax);
        for j := 0 to YCount-2 do
          UpdateMinMax(Item[i]^.YList[j], AYMin, AYMax);
      end;
  end
end;

function TCustomChartSource.FormatItem(
  const AFormat: String; AIndex, AYIndex: Integer): String;
begin
  with Item[AIndex]^ do
    Result := FormatItemXYText(AFormat, Math.IfThen(XCount > 0, X, Double(AIndex)), GetY(AYIndex), Text);
end;

function TCustomChartSource.FormatItemXYText(
  const AFormat: String; const AX, AY: Double; const AText: String): String;
const
  TO_PERCENT = 100;
var
  total, percent: Double;
begin
  total := ValuesTotal;
  if total = 0 then
    percent := 0
  else
    percent := TO_PERCENT / total;
  Result := Format(AFormat, [AY, AY * percent, AText, total, AX]);
end;

function TCustomChartSource.GetEnumerator: TCustomChartSourceEnumerator;
begin
  Result := TCustomChartSourceEnumerator.Create(Self);
end;

function TCustomChartSource.GetErrorBarData(AIndex: Integer): TChartErrorBarData;
begin
  Result := FErrorBarData[AIndex];
end;

{ Returns the error bar values in positive and negative direction for the
  x (which = 0) or y (which = 1) coordinates of the data point at the specified
  index. The result is false if there is no error bar. }
function TCustomChartSource.GetErrorBarValues(APointIndex: Integer;
  Which: Integer; out AUpperDelta, ALowerDelta: Double): Boolean;
var
  v: Double;
  pidx, nidx: Integer;
begin
  Result := false;
  AUpperDelta := 0;
  ALowerDelta := 0;

  if Which = 0 then
    v := Math.IfThen(XCount > 0, Item[APointIndex]^.X, APointIndex)
  else
    v := Item[APointIndex]^.Y;

  if IsNaN(v) then
    exit;

  if Assigned(FErrorBarData[Which]) then begin
    case FErrorBarData[Which].Kind of
      ebkNone:
        exit;
      ebkConst:
        begin
          AUpperDelta := FErrorBarData[Which].ValuePlus;
          if FErrorBarData[Which].ValueMinus = -1 then
            ALowerDelta := AUpperDelta
          else
            ALowerDelta := FErrorBarData[Which].ValueMinus;
        end;
      ebkPercent:
        begin
          AUpperDelta := v * FErrorBarData[Which].ValuePlus * PERCENT;
          if FErrorBarData[Which].ValueMinus = -1 then
            ALowerDelta := AUpperDelta
          else
            ALowerDelta := v * FErrorBarData[Which].ValueMinus * PERCENT;
        end;
      ebkChartSource:
        if Which = 0 then begin
          pidx := FErrorBarData[0].IndexPlus;
          nidx := FErrorBarData[0].IndexMinus;
          if not InRange(pidx, 0, XCount-1) then exit;
          if (nidx <> -1) and not InRange(nidx, 0, XCount-1) then exit;
          AUpperDelta := Item[APointIndex]^.GetX(pidx);
          if nidx = -1 then
            ALowerDelta := AUpperDelta
          else
            ALowerDelta := Item[APointIndex]^.GetX(nidx);
        end else begin
          pidx := FErrorBarData[1].IndexPlus;
          nidx := FErrorBarData[1].IndexMinus;
          if not InRange(pidx, 0, YCount-1) then exit;
          if (nidx <> -1) and not InRange(nidx, 0, YCount-1) then exit;
          AUpperDelta := Item[APointIndex]^.GetY(pidx);
          if nidx = -1 then
            ALowerDelta := AUpperDelta
          else
            ALowerDelta := Item[APointIndex]^.GetY(nidx);
        end;
    end;
    AUpperDelta := abs(AUpperDelta);
    ALowerDelta := abs(ALowerDelta);
    Result := (AUpperDelta <> 0) and (ALowerDelta <> 0);
  end;
end;

function TCustomChartSource.GetXErrorBarLimits(APointIndex: Integer;
  out AUpperLimit, ALowerLimit: Double): Boolean;
var
  v, dxp, dxn: Double;
begin
  Result := GetErrorBarValues(APointIndex, 0, dxp, dxn);
  v := Math.IfThen(XCount > 0, Item[APointIndex]^.X, APointIndex);
  if Result and not IsNaN(v) then begin
    AUpperLimit := v + dxp;
    ALowerLimit := v - dxn;
  end else begin
    AUpperLimit := v;
    ALowerLimit := v;
  end;
end;

function TCustomChartSource.GetYErrorBarLimits(APointIndex: Integer;
  out AUpperLimit, ALowerLimit: Double): Boolean;
var
  v, dyp, dyn: Double;
begin
  Result := GetErrorBarValues(APointIndex, 1, dyp, dyn);
  v := Item[APointIndex]^.Y;
  if Result and not IsNaN(v) then begin
    AUpperLimit := v + dyp;
    ALowerLimit := v - dyn;
  end else begin
    AUpperLimit := v;
    ALowerLimit := v;
  end;
end;

function TCustomChartSource.GetXErrorBarValues(APointIndex: Integer;
  out AUpperDelta, ALowerDelta: Double): Boolean;
begin
  Result := GetErrorBarValues(APointIndex, 0, AUpperDelta, ALowerDelta);
end;

function TCustomChartSource.GetYErrorBarValues(APointIndex: Integer;
  out AUpperDelta, ALowerDelta: Double): Boolean;
begin
  Result := GetErrorBarValues(APointIndex, 1, AUpperDelta, ALowerDelta);
end;

function TCustomChartSource.GetHasErrorBars(Which: Integer): Boolean;
var
  errbar: TChartErrorBarData;
begin
  Result := false;
  errbar := FErrorBarData[Which];
  if Assigned(errbar) then
    case errbar.Kind of
      ebkNone:
        ;
      ebkConst, ebkPercent:
        Result := (errbar.ValuePlus > 0) and
                  ((errbar.ValueMinus = -1) or (errbar.ValueMinus > 0));
      ebkChartSource:
        Result := (errbar.IndexPlus > -1) and (errbar.IndexMinus >= -1);
    end;
end;

function TCustomChartSource.HasSameSorting(ASource: TCustomChartSource): Boolean;
begin
  case SortBy of
    sbX, sbY:
      Result := ASource.IsSorted and (ASource.SortBy = SortBy) and
                (ASource.SortDir = SortDir) and (ASource.SortIndex = SortIndex);
    sbColor, sbText:
      Result := ASource.IsSorted and (ASource.SortBy = SortBy) and
                (ASource.SortDir = SortDir);
    sbCustom:
      Result := false;
  end;
end;

function TCustomChartSource.HasXErrorBars: Boolean;
begin
  Result := GetHasErrorBars(0);
end;

function TCustomChartSource.HasYErrorBars: Boolean;
begin
  Result := GetHasErrorBars(1);
end;

procedure TCustomChartSource.InvalidateCaches;
begin
  FBasicExtentIsValid := false;
  FValuesTotalIsValid := false;
  FCumulativeExtentIsValid := false;
  FXListExtentIsValid := false;
  FYListExtentIsValid := false;
end;

function TCustomChartSource.IsErrorBarDataStored(AIndex: Integer): Boolean;
begin
  with FErrorBarData[AIndex] do
    Result := (FIndex[AIndex] <> -1) or (FValue[AIndex] <> -1) or (FKind <> ebkNone);
end;

function TCustomChartSource.IsSorted: Boolean;
begin
  Result := false;
end;

function TCustomChartSource.IsSortedByXAsc: Boolean;
begin
  Result := IsSorted and (FSortBy = sbX) and (FSortDir = sdAscending) and (FSortIndex = 0);
end;

function TCustomChartSource.IsXErrorIndex(AXIndex: Integer): Boolean;
begin
  Result :=
    (XErrorBarData.Kind = ebkChartSource) and
    ((XErrorBarData.IndexPlus = AXIndex) or (XErrorBarData.IndexMinus = AXIndex) and
    (AXIndex > -1)
  );
end;

function TCustomChartSource.IsYErrorIndex(AYIndex: Integer): Boolean;
begin
  Result :=
    (YErrorBarData.Kind = ebkChartSource) and
    ((YErrorBarData.IndexPlus = AYIndex) or (YErrorBarData.IndexMinus = AYIndex)) and
    (AYIndex > -1);
end;

procedure TCustomChartSource.SetErrorBarData(AIndex: Integer;
  AValue: TChartErrorBarData);
begin
  FErrorBarData[AIndex] := AValue;
  Notify;
end;

procedure TCustomChartSource.SetSortBy(AValue: TChartSortBy);
begin
  if FSortBy <> AValue then
    raise ESortError.CreateFmt(rsSourceSortError, [ClassName]);
end;

procedure TCustomChartSource.SetSortDir(AValue: TChartSortDir);
begin
  if FSortDir <> AValue then
    raise ESortError.CreateFmt(rsSourceSortError, [ClassName]);
end;

procedure TCustomChartSource.SetSortIndex(AValue: Cardinal);
begin
  if FSortIndex <> AValue then
    raise ESortError.CreateFmt(rsSourceSortError, [ClassName]);
end;

procedure TCustomChartSource.SortValuesInRange(
  var AValues: TChartValueTextArray; AStart, AEnd: Integer);
var
  i, j, next: Integer;
  lst: TFPList;
  p: PChartValueText;
  tmp: TChartValueText;
begin
  lst := TFPList.Create;
  try
    lst.Count := AEnd - AStart + 1;
    for i := AStart to AEnd do
      lst[i - AStart] := @AValues[i];
    lst.Sort(@CompareChartValueTextPtr);
    for i := AStart to AEnd do begin
      if lst[i - AStart] = nil then continue;
      j := i;
      tmp := AValues[j];
      while true do begin
        p := PChartValueText(lst[j - AStart]);
        lst[j - AStart] := nil;
        {$PUSH}
        {$HINTS OFF} // Work around the fpc bug #19582.
        next := (PtrUInt(p) - PtrUInt(@AValues[0])) div SizeOf(p^);
        {$POP}
        if next = i then break;
        AValues[j] := p^;
        j := next;
      end;
      AValues[j] := tmp;
    end;
  finally
    lst.Free;
  end;
end;

procedure TCustomChartSource.ValuesInRange(
  AParams: TValuesInRangeParams; var AValues: TChartValueTextArray);

  procedure Put(
    out ADest: TChartValueText; AValue: Double; AIndex: Integer); inline;
  var
    nx, ny: Double;
  begin
    AParams.RoundToImage(AValue);
    ADest.FValue := AValue;
    with Item[AIndex]^ do begin
      if AParams.FUseY then begin
        nx := Math.IfThen(XCount > 0, X, AIndex);
        ny := AValue;
      end
      else begin
        nx := AValue;
        ny := Y;
      end;
      ADest.FText := FormatItemXYText(AParams.FFormat, nx, ny, Text);
    end;
  end;

var
  prevImagePos: Integer = MaxInt;

  function IsTooClose(const AValue: Double): Boolean;
  var
    imagePos: Integer;
  begin
    with AParams do
      if aipUseMinLength in FIntervals.Options then begin
        imagePos := ToImage(AValue);
        Result := Abs(imagePos - prevImagePos) < FScale(FIntervals.MinLength);
      end;
    if not Result then
      prevImagePos := imagePos;
  end;

  function EnsureMinLength(AStart, AEnd: Integer): Integer;
  var
    i: Integer;
    v: Double;
  begin
    prevImagePos := MaxInt;
    Result := AStart;
    for i := AStart to AEnd do begin
      v := AValues[i].FValue;
      if InRange(v, AParams.FMin, AParams.FMax) and IsTooClose(v) then continue;
      AValues[Result] := AValues[i];
      Result += 1;
    end;
  end;

var
  i, cnt, start: Integer;
  v: Double;
  lo, hi: TChartValueText;
begin
  // Select all values in a given range, plus lower and upper bound values.
  // Proceed through the (possibly unsorted) data source in a single pass.
  start := Length(AValues);
  SetLength(AValues, start + Count + 2);
  cnt := start;
  lo.FValue := NegInfinity;
  hi.FValue := SafeInfinity;
  AValues[start].FValue := SafeNan;
  for i := 0 to Count - 1 do begin
    with Item[I]^ do
      v := Math.IfThen(AParams.FUseY, Y, Math.IfThen(XCount > 0, X, I));
    if IsNan(v) then continue;
    if v < AParams.FMin then begin
      if v > lo.FValue then
        Put(lo, v, i);
    end
    else if v > AParams.FMax then begin
      if v < hi.FValue then
        Put(hi, v, i);
    end
    else begin
      if (aipUseMinLength in AParams.FIntervals.Options) and IsTooClose(v) then
        continue;
      if not IsInfinite(lo.FValue) and (cnt = start) then
        cnt += 1;
      Put(AValues[cnt], v, i);
      cnt += 1;
    end;
  end;

  if not IsInfinite(lo.FValue) then begin
    if not IsNan(AValues[start].FValue) then begin
      // The lower bound value occurred after the first in-range value,
      // so we did not reserve space for it. Hopefully rare case.
      for i := cnt downto start + 1 do
        AValues[i] := AValues[i - 1];
      cnt += 1;
    end;
    AValues[start] := lo;
    if cnt = start then
      cnt += 1;
  end;
  if not IsInfinite(hi.FValue) then begin
    AValues[cnt] := hi;
    cnt += 1;
  end;

  if not IsSortedByXAsc and not IsValueTextsSorted(AValues, start, cnt - 1) then begin
    SortValuesInRange(AValues, start, cnt - 1);
    if aipUseMinLength in AParams.FIntervals.Options then
      cnt := EnsureMinLength(start, cnt - 1);
  end;
  SetLength(AValues, cnt);
end;

function TCustomChartSource.ValuesTotal: Double;
var
  i: Integer;
begin
  if FValuesTotalIsValid then exit(FValuesTotal);
  FValuesTotal := 0;
  for i := 0 to Count - 1 do
    with Item[i]^ do
      FValuesTotal += NumberOr(Y);
  FValuesTotalIsValid := not IsUpdating;  // When updating, we are not allowed
    // to set "Valid" for caches - see comment in TListChartSource.ClearCaches()
  Result := FValuesTotal;
end;

function TCustomChartSource.XOfMax(AIndex: Integer = 0): Double;
var
  i: Integer;
begin
  for i := 0 to Count - 1 do
    with Item[i]^ do
      if not IsNaN(Y) and (Y = Extent.b.Y) then begin
        if XCount > 0 then
          exit(GetX(AIndex))
        else
          exit(i);
      end;
  Result := 0.0;
end;

function TCustomChartSource.XOfMin(AIndex: Integer = 0): Double;
var
  i: Integer;
begin
  for i := 0 to Count - 1 do
    with Item[i]^ do
      if not IsNaN(Y) and (Y = Extent.a.Y) then begin
        if XCount > 0 then
          exit(GetX(AIndex))
        else
          exit(i);
      end;
  Result := 0.0;
end;


{ TCustomSortedChartSource }

constructor TCustomSortedChartSource.Create(AOwner: TComponent);
begin
  inherited;
  FData := TFPList.Create;
end;

destructor TCustomSortedChartSource.Destroy;
begin
  FreeAndNil(FData);
  inherited;
end;

function CompareFloat(const x1, x2: Double): Integer;
begin
  if IsNaN(x1) then begin
    if IsNaN(x2) then
      Result := 0
    else
      Result := +1;
  end else
  if IsNaN(x2) then
    Result := -1
  else
    Result := CompareValue(x1, x2);
end;

function TCustomSortedChartSource.DoCompare(AItem1, AItem2: Pointer): Integer;
var
  item1: PChartDataItem absolute AItem1;
  item2: PChartDataItem absolute AItem2;
  d1, d2: Double;
begin
  case FSortBy of
    sbX:
      if FSortIndex = 0 then
        Result := CompareFloat(item1^.X, item2^.X)
      else
      if FSortIndex < FXCount then begin
        if FSortIndex <= Cardinal(Length(item1^.XList)) then
          d1 := item1^.XList[FSortIndex - 1]
        else
          d1 := SafeNan;
        if FSortIndex <= Cardinal(Length(item2^.XList)) then
          d2 := item2^.XList[FSortIndex - 1]
        else
          d2 := SafeNan;
        Result := CompareFloat(d1, d2);
      end else
        Result := 0;
    sbY:
      if FSortIndex = 0 then
        Result := CompareFloat(item1^.Y, item2^.Y)
      else
      if FSortIndex < FYCount then begin
        if FSortIndex <= Cardinal(Length(item1^.YList)) then
          d1 := item1^.YList[FSortIndex - 1]
        else
          d1 := SafeNan;
        if FSortIndex <= Cardinal(Length(item2^.YList)) then
          d2 := item2^.YList[FSortIndex - 1]
        else
          d2 := SafeNan;
        Result := CompareFloat(d1, d2);
      end else
        Result := 0;
    sbColor:
      Result := CompareValue(item1^.Color, item2^.Color);
    sbText:
      Result := CompareText(item1^.Text, item2^.Text);
    sbCustom:
      if Assigned(FOnCompare) then
        Result := FOnCompare(AItem1, AItem2)
      else
        Result := 0;
  end;
  if FSortDir = sdDescending then Result := -Result;
end;

{ Built-in sorting algorithm of the ChartSource - a QuickSort algorithm, copied
  from the Classes unit and modified. Modifications are:
  - uses an object's method for comparisons,
  - does NOT exchange equal items - this would have some side effect here: let's
    consider sorting by X, in the ascending order, for the following data points:
      X=3, Text='ccc'
      X=2, Text='bbb 1'
      X=2, Text='bbb 2'
      X=2, Text='bbb 3'
      X=1, Text='aaa'

    after sorting, data would be (note the reversed 'bbb' order):
      X=1, Text='aaa'
      X=2, Text='bbb 3'
      X=2, Text='bbb 2'
      X=2, Text='bbb 1'
      X=3, Text='ccc'

    after sorting AGAIN, data would be (note the original 'bbb' order):
      X=1, Text='aaa'
      X=2, Text='bbb 1'
      X=2, Text='bbb 2'
      X=2, Text='bbb 3'
      X=3, Text='ccc'
}
procedure QuickSort(const List: PPointerList; const Compare: TChartSortCompare;
  L, R: Longint); stdcall; // optimization: thanks to "stdcall", procedure
                           // parameters don't need to be copied on the stack
                           // in the "begin" code - they are already pushed on
                           // the stack
var
  I, J: Longint;
  P, Q: Pointer;
begin
  repeat
    I := L;
    J := R;
    P := List^[(L + R) div 2];
    repeat
      while Compare(P, List^[I]) > 0 do
        I := I + 1;
      while Compare(P, List^[J]) < 0 do
        J := J - 1;
      if I <= J then
      begin
        // do NOT exchange equal items
        if Compare(List^[I], List^[J]) <> 0 then begin
          Q := List^[I];
          List^[I] := List^[J];
          List^[J] := Q;
        end;
        I := I + 1;
        J := J - 1;
      end;
    until I > J;
    if J - L < R - I then
    begin
      if L < J then
        QuickSort(List, Compare, L, J);
      L := I;
    end
    else
    begin
      if I < R then
        QuickSort(List, Compare, I, R);
      R := J;
    end;
  until L >= R;
end;

procedure TCustomSortedChartSource.DoSort;
begin
  if FData.Count < 2 then exit;
  QuickSort(FData.List, @DoCompare, 0, FData.Count - 1);
end;

function TCustomSortedChartSource.GetCount: Integer;
begin
  Result := FData.Count;
end;

function TCustomSortedChartSource.GetItem(AIndex: Integer): PChartDataItem;
begin
  Result := PChartDataItem(FData.Items[AIndex]);

  // Values can be set directly between BeginUpdate and EndUpdate.
  // Getting a pointer to the item allows modifying item's data
  // directly, so we can no longer be sure, that dataset is sorted -
  // so, if FSortedAutoDetected is set, reset it.
  if IsUpdating and FSortedAutoDetected then
    ResetSortedAutoDetection;
end;

function TCustomSortedChartSource.GetItemInternal(AIndex: Integer): PChartDataItem;
var
  SaveSortedAutoDetected: Boolean;
begin
  // try..finally..end is not required here - it makes the execution slower,
  // and the worst thing, that can theoretically happen here (in case of
  // exception) is disabling the FSortedAutoDetected optimization
  SaveSortedAutoDetected := FSortedAutoDetected;
  Result := GetItem(AIndex);
  FSortedAutoDetected := SaveSortedAutoDetected;
end;

function TCustomSortedChartSource.ItemAdd(AItem: PChartDataItem): Integer;
begin
  if IsSorted then begin
    if FSorted then begin
      Result := ItemFind(AItem);
      FData.Insert(Result, AItem);
    end else begin
      Result := FData.Add(AItem);
      if Result > 0 then
        if DoCompare(FData.List^[Result - 1], AItem) > 0 then
          ResetSortedAutoDetection; // must be called AFTER adding new data
    end;
  end else
    Result := FData.Add(AItem);
end;

procedure TCustomSortedChartSource.ItemInsert(AIndex: Integer; AItem: PChartDataItem);
begin
  if IsSorted then
    if AIndex <> ItemFind(AItem) then
      if FSorted then
        raise ESortError.CreateFmt('%0:s.ItemInsert cannot insert data at the requested '+
          'position, because source is sorted', [ClassName])
      else begin
        FData.Insert(AIndex, AItem);
        ResetSortedAutoDetection; // must be called AFTER inserting new data
        exit;
      end;
  FData.Insert(AIndex, AItem);
end;

function TCustomSortedChartSource.ItemFind(AItem: PChartDataItem; L: Integer = 0; R: Integer = High(Integer)): Integer;
var
  I: Integer;
begin
  if L < 0 then
    L := 0;
  if R >= FData.Count then
    R := FData.Count - 1;

  // special optimization for adding sorted data at the end
  if L > R then
    exit(L);
  if DoCompare(FData.List^[R], AItem) <= 0 then
    exit(R + 1);

  if not IsSorted then
    raise ESortError.CreateFmt('%0:s.ItemFind failed, because source is not sorted', [ClassName]);

  // use binary search
  while L <= R do
  begin
    I := L + (R - L) div 2;
    if DoCompare(FData.List^[I], AItem) <= 0 then
      L := I + 1
    else
      R := I - 1;
  end;
  Result := L;
end;

function TCustomSortedChartSource.ItemModified(AIndex: Integer): Integer;
begin
  Result := AIndex;
  if IsSorted then begin
    if FData.Count < 2 then exit;
    if (AIndex < 0) or (AIndex >= FData.Count) then exit;

    if AIndex > 0 then
      if DoCompare(FData.List^[AIndex - 1], FData.List^[AIndex]) > 0 then begin
        if FSorted then begin
          Result := ItemFind(FData.List^[AIndex], 0, AIndex - 1);
          // no Dec(Result) here, as it is below
          FData.Move(AIndex, Result);
        end else
          ResetSortedAutoDetection;
        exit; // optimization: the item cannot be unsorted from both sides
              // simultaneously, so we can exit now
      end;

    if AIndex < FData.Count - 1 then
      if DoCompare(FData.List^[AIndex], FData.List^[AIndex + 1]) > 0 then begin
        if FSorted then begin
          Result := ItemFind(FData.List^[AIndex], AIndex + 1, FData.Count - 1);
          Dec(Result);
          FData.Move(AIndex, Result);
        end else
          ResetSortedAutoDetection;
      end;
  end;
end;

procedure TCustomSortedChartSource.ItemDeleted(AIndex: Integer);
begin
  // deleting decreases item count - so, if FSortedAutoDetected
  // is not set, try to set it again, if possible
  if not FSortedAutoDetected then
    ResetSortedAutoDetection;
end;

function TCustomSortedChartSource.IsSorted: Boolean;
begin
  Result := false;
  if FSorted or FSortedAutoDetected then
    case FSortBy of
      sbX:
        Result := (FSortIndex = 0) or (FSortIndex < FXCount);
      sbY:
        Result := (FSortIndex = 0) or (FSortIndex < FYCount);
      sbColor, sbText:
        Result := true;
      sbCustom:
        Result := Assigned(FOnCompare);
    end;
end;

procedure TCustomSortedChartSource.ResetSortedAutoDetection;
begin
  FSortedAutoDetected := FUseSortedAutoDetection and (FData.Count < 2) and
                         (FSortBy <> sbCustom);
end;

procedure TCustomSortedChartSource.SetSortedAutoDetected;
begin
  FSortedAutoDetected := FUseSortedAutoDetection and (FSortBy <> sbCustom);
end;

procedure TCustomSortedChartSource.SetOnCompare(AValue: TChartSortCompare);
begin
  if FOnCompare = AValue then exit;
  FOnCompare := AValue;

  // reset FSortedAutoDetected state and perform resorting only
  // if FOnCompare is currently used
  if FSortBy = sbCustom then begin
    ResetSortedAutoDetection;
    if IsSorted then SortNoNotify;
  end;

  Notify;
end;

procedure TCustomSortedChartSource.SetSortBy(AValue: TChartSortBy);
begin
  if FSortBy = AValue then exit;
  FSortBy := AValue;
  ResetSortedAutoDetection;
  if IsSorted then SortNoNotify;
  Notify;
end;

procedure TCustomSortedChartSource.SetSortDir(AValue: TChartSortDir);
begin
  if FSortDir = AValue then exit;
  FSortDir := AValue;
  ResetSortedAutoDetection;
  if IsSorted then SortNoNotify;
  Notify;
end;

procedure TCustomSortedChartSource.SetSorted(AValue: Boolean);
begin
  if FSorted = AValue then exit;
  FSorted := AValue;

  // FSortedAutoDetected set to True means, that data is (already) sorted
  // by using current sorting settings - in this case omit the code below,
  // to avoid losing FSortedAutoDetected state and useless resorting
  if not FSortedAutoDetected then begin
    ResetSortedAutoDetection;
    if IsSorted then SortNoNotify;
  end;

  Notify;
end;

procedure TCustomSortedChartSource.SetSortIndex(AValue: Cardinal);
begin
  if FSortIndex = AValue then exit;
  FSortIndex := AValue;

  // reset FSortedAutoDetected state and perform resorting only
  // if FSortIndex is currently used (in sbCustom mode it may be
  // potentially used by the user's code)
  if FSortBy in [sbX, sbY, sbCustom] then begin
    ResetSortedAutoDetection;
    if IsSorted then SortNoNotify;
  end;

  Notify;
end;

procedure TCustomSortedChartSource.SetUseSortedAutoDetection(AValue: Boolean);
begin
  if FUseSortedAutoDetection = AValue then exit;
  FUseSortedAutoDetection := AValue;
  ResetSortedAutoDetection;
end;


procedure TCustomSortedChartSource.Sort;
var
  SaveSorted: Boolean;
begin
  if csLoading in ComponentState then exit;

  // Avoid useless sorting and notification, if data is already
  // sorted or if current sorting settings are invalid
  if FSortedAutoDetected then exit;
  SaveSorted := FSorted;
  try
    FSorted := true;
    if not IsSorted then exit;
  finally
    FSorted := SaveSorted;
  end;

  DoSort;
  SetSortedAutoDetected;

  Notify;
end;

procedure TCustomSortedChartSource.SortNoNotify;
begin
  { Don't call BeginUpdate() to avoid invalidating the caches. }
  Inc(FUpdateCount);
  try
    Sort;
  finally
    Dec(FUpdateCount);
  end;
end;

end.

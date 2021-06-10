{
 *****************************************************************************
  See the file COPYING.modifiedLGPL.txt, included in this distribution,
  for details about the license.
 *****************************************************************************

  Authors: Werner Pamler, Alexander Klenin

  Usage:
  - Add the ChartListbox to a form with a TChart
  - Connect the chart to the listbox by setting the chart property of the
    TChartlistbox. The ChartListbox will be populated with the series in the
    chart and will automatically track changes of the series.
  - Check/uncheck series in the ChartListbox to show/hide them in the chart.
    As usual, checking is done by mouse clicks or by pressing the space bar.
  - Play with the properties to modify the standard behavior, e.g. set
    CheckStyle to cbsRadioButton in order to get a radiobutton behavior, i.e. to
    allow only one visible series.
}

unit TAChartListbox;

{$MODE objfpc}{$H+}

{$IFDEF DARWIN}
  {$DEFINE USE_BITMAPS}
{$ENDIF}

interface

uses
  Classes, Controls, SysUtils, Types, Math,
  StdCtrls, Graphics, LCLIntf, LCLType, Themes,
  IntegerList, LazUTF8,
  TAChartUtils, TACustomSeries, TALegend, TAGraph,
  TACustomSource, TADrawerCanvas, TADrawUtils, TAEnumerators, TAGeometry;


type
  TChartListbox = class;

  TChartListboxIndexEvent = procedure (
    ASender: TObject; AIndex: Integer) of object;

  TChartListboxAddSeriesEvent = procedure (
    ASender: TChartListbox; ASeries: TCustomChartSeries;
    AItems: TChartLegendItems; var ASkip: Boolean
  ) of object;

  TCheckBoxesStyle = (cbsCheckbox, cbsRadiobutton);

  TChartListOption = (cloShowCheckboxes, cloShowIcons, cloRefreshOnSourceChange);
  TChartListOptions = set of TChartListOption;

const
  SHOW_ALL = [cloShowCheckboxes, cloShowIcons];

type
  TChartListbox = class(TCustomListbox)
  private
    FChart: TChart;
    FCheckBoxSize: TSize;
    FCheckStyle: TCheckBoxesStyle;
    FDown: Boolean;
    FHot: Boolean;
    FLegendItems: TChartLegendItems;
    FListener: TListener;
    FOnAddSeries: TChartListboxAddSeriesEvent;
    FOnCheckboxClick: TChartListboxIndexEvent;
    FOnItemClick: TChartListboxIndexEvent;
    FOnPopulate: TNotifyEvent;
    FOnSeriesIconDblClick: TChartListboxIndexEvent;
    FOptions: TChartListOptions;
    FSeriesIconClicked: Integer;
    function GetChecked(AIndex: Integer): Boolean;
    function GetSeries(AIndex: Integer): TCustomChartSeries;
    function GetSeriesCount: Integer;
    procedure EnsureSingleChecked(AIndex: Integer = -1);
    procedure SetChart(AValue: TChart);
    procedure SetChecked(AIndex: Integer; AValue: Boolean);
    procedure SetCheckStyle(AValue: TCheckBoxesStyle);
    procedure SetOnAddSeries(AValue: TChartListboxAddSeriesEvent);
    procedure SetOnPopulate(AValue: TNotifyEvent);
    procedure SetOptions(AValue: TChartListOptions);

  protected
    procedure DblClick; override;
    procedure DrawItem(
      AIndex: Integer; ARect: TRect; AState: TOwnerDrawState); override;
    procedure KeyDown(var AKey: Word; AShift: TShiftState); override;
    procedure MouseDown(AButton: TMouseButton; AShift: TShiftState; AX, AY: Integer); override;
    procedure MouseEnter; override;
    procedure MouseLeave; override;
    procedure MouseUp(AButton: TMouseButton; AShift: TShiftState; AX, AY: Integer); override;
  protected
    procedure CalcRects(
      const AItemRect: TRect; out ACheckboxRect, ASeriesIconRect: TRect);
    procedure ClickedCheckbox(AIndex: Integer); virtual;
    procedure ClickedItem(AIndex: Integer); virtual;
    procedure ClickedSeriesIcon(AIndex: Integer); virtual;
    function CreateLegendItems: TChartLegendItems;
    procedure Notification(AComponent: TComponent; AOperation: TOperation); override;

  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure ExchangeSeries(AIndex1, AIndex2: Integer);
    function FindSeriesIndex(ASeries: TCustomChartSeries): Integer;
    procedure MeasureItem(AIndex: Integer; var AHeight: Integer); override;
    procedure Populate;
    procedure RemoveSeries(ASeries: TCustomChartSeries);
    procedure SeriesChanged(ASender: TObject);
    procedure Sort(Descending: Boolean = false);

    property Checked[AIndex: Integer]: Boolean read GetChecked write SetChecked;
    property Series[AIndex: Integer]: TCustomChartSeries read GetSeries;
    property SeriesCount: Integer read GetSeriesCount;

  published
    property Chart: TChart read FChart write SetChart;
    property CheckStyle: TCheckBoxesStyle
      read FCheckStyle write SetCheckStyle default cbsCheckbox;
    property Options: TChartListOptions
      read FOptions write SetOptions default SHOW_ALL;
  published
    property OnAddSeries: TChartListboxAddSeriesEvent
      read FOnAddSeries write SetOnAddSeries;
    property OnCheckboxClick: TChartListboxIndexEvent
      read FOnCheckboxClick write FOnCheckboxClick;
    property OnItemClick: TChartListboxIndexEvent
      read FOnItemClick write FOnItemClick;
    property OnPopulate: TNotifyEvent read FOnPopulate write SetOnPopulate;
    property OnSeriesIconDblClick: TChartListboxIndexEvent
      read FOnSeriesIconDblClick write FOnSeriesIconDblClick;
  published
    property Align;
//    property AllowGrayed;
    property Anchors;
    property BidiMode;
    property BorderSpacing;
    property BorderStyle;
    property Color;
    property Columns;
    property Constraints;
    property DragCursor;
    property DragMode;
    property Enabled;
    property ExtendedSelect;
    property Font;
    property IntegralHeight;
//    property Items;
    property ItemHeight;
    property MultiSelect;
    property OnChangeBounds;
    property OnClick;
//    property OnClickCheck;
    property OnContextPopup;
    property OnDblClick;
    property OnDragDrop;
    property OnDragOver;
    property OnDrawItem;
    property OnEndDrag;
    property OnEnter;
    property OnExit;
//    property OnItemClick;
    property OnKeyDown;
    property OnKeyPress;
    property OnKeyUp;
    property OnMouseDown;
    property OnMouseEnter;
    property OnMouseLeave;
    property OnMouseMove;
    property OnMouseUp;
    property OnMouseWheel;
    property OnMouseWheelDown;
    property OnMouseWheelUp;
    property OnResize;
    property OnShowHint;
    property OnStartDrag;
    property OnUTF8KeyPress;
    property ParentBidiMode;
    property ParentFont;
    property ParentShowHint;
    property PopupMenu;
    property ShowHint;
    property Sorted;
//    property Style;
    property TabOrder;
    property TabStop;
    property TopIndex;
    property Visible;
  end;

procedure Register;


implementation

type
  TThemedStatesUsed = {%H-}tbRadioButtonUnCheckedNormal..tbCheckboxCheckedDisabled;

{$IFDEF USE_BITMAPS}
var
  ThemedBitmaps: Array[TThemedStatesUsed] of TBitmap;

function CreateBitmap(AThemedButton: TThemedButton; ABkColor: TColor): TBitmap;
var
  s: TSize;
  details: TThemedElementDetails;
begin
  Result := ThemedBitmaps[AThemedButton];
  if Assigned(Result) and (Result.Canvas.Pixels[0, 0] = ABkColor) then
    exit;
  FreeAndNil(Result);
  Result := TBitmap.Create;
  details := ThemeServices.GetElementDetails(AThemedButton);
  s := ThemeServices.GetDetailSize(details);
  Result.SetSize(s.CX, s.CY);
  Result.Canvas.Brush.Color := ABkColor;
  Result.Canvas.FillRect(0, 0, Result.Width, Result.Height);
  ThemeServices.DrawElement(Result.Canvas.Handle, details, Rect(0, 0, Result.Width, Result.Height));
  ThemedBitmaps[AThemedButton] := Result;
end;

procedure InitBitmaps;
var
  tb: TThemedButton;
begin
  for tb in TThemedStatesUsed do
    ThemedBitmaps[tb] := nil;
end;

procedure FreeBitmaps;
var
  tb: TThemedButton;
begin
  for tb in TThemedStatesUsed do
    FreeAndNil(ThemedBitmaps[tb]);
end;
{$ENDIF}

{ TChartListbox }

constructor TChartListbox.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  Style := lbOwnerDrawFixed;
  FListener := TListener.Create(@FChart, @SeriesChanged);
  FOptions := SHOW_ALL;
end;

destructor TChartListbox.Destroy;
begin
  FreeAndNil(FListener);
  FreeAndNil(FLegendItems);
  inherited;
end;

procedure TChartListbox.CalcRects(
  const AItemRect: TRect; out ACheckboxRect, ASeriesIconRect: TRect);
{ based on the rect of a listbox item, calculates the locations of the
  checkbox and of the series icon }
const
  MARGIN = 4;
var
  x: Integer;
begin
  ACheckBoxRect := ZeroRect;
  ASeriesIconRect := ZeroRect;

  x := AItemRect.Left + MARGIN;
  if cloShowCheckboxes in Options then begin
    ACheckBoxRect := Rect(0, 0, FCheckboxSize.CX, FCheckboxSize.CY);
    OffsetRect(ACheckboxRect, x, (AItemRect.Top + AItemRect.Bottom - FCheckboxSize.CY) div 2);
    if cloShowIcons in Options then
      x += ACheckboxRect.Right;
  end
  else begin
    if cloShowIcons in Options then
      x += AItemRect.Left;
  end;
  if cloShowIcons in Options then
    ASeriesIconRect := Rect(
      x, AItemRect.Top + 2, x + FChart.Legend.SymbolWidth, AItemRect.Bottom - 2);
end;

procedure TChartListbox.ClickedCheckbox(AIndex: Integer);
begin
  Checked[AIndex] := not Checked[AIndex];
  if Assigned(OnCheckboxClick) then
    OnCheckboxClick(Self, AIndex);
end;

procedure TChartListbox.ClickedItem(AIndex: Integer);
begin
  if Assigned(OnItemClick) then
    OnItemClick(Self, AIndex);
end;

procedure TChartListbox.ClickedSeriesIcon(AIndex: Integer);
begin
  if Assigned(OnSeriesIconDblClick) then
    OnSeriesIconDblClick(Self, AIndex);
end;

function TChartListbox.CreateLegendItems: TChartLegendItems;
{ creates the a TLegendItems list and populates it with information for
  all series contained in the Chart. In case of MultiLegend items, only
  a single legend item is used }
var
  skip: Boolean;
  s: TCustomChartSeries;
begin
  Result := TChartLegendItems.Create;
  try
    if FChart = nil then exit;
    for s in CustomSeries(Chart) do begin
      if Assigned(OnAddSeries) then begin
        skip := false;
        FOnAddSeries(Self, s, Result, skip);
        if skip then continue;
      end;
      s.GetSingleLegendItem(Result);
    end;
  except
    FreeAndNil(Result);
    raise;
  end;
end;

procedure TChartListbox.DblClick;
begin
  inherited DblClick;
  if FSeriesIconClicked <> -1 then
    ClickedSeriesIcon(FSeriesIconClicked);
end;

function GetThemedButtonOffset(Hot, Pressed, Disabled: Boolean): Integer;
begin
  Result := 0;
  if Disabled then
    Result := 3
  else if Hot then
    Result := 1
  else if Pressed then
    Result := 2;
end;

procedure TChartListbox.DrawItem(
  AIndex: Integer; ARect: TRect; AState: TOwnerDrawState);
{ draws the listbox item }
const
  THEMED_BASE: array [TCheckboxesStyle, Boolean] of TThemedButton = (
    (tbCheckBoxUncheckedNormal, tbCheckBoxCheckedNormal),
    (tbRadioButtonUnCheckedNormal, tbRadioButtonCheckedNormal)
  );
var
  id: IChartDrawer;
  rcb, ricon: TRect;
  x: Integer;
  tb: TThemedButton;
  tbBase, tbOffs: Integer;
  {$IFDEF USE_BITMAPS}
  bmp: TBitmap;
  {$ELSE}
  ted: TThemedElementDetails;
  {$ENDIF}
begin
  if Assigned(OnDrawItem) then begin
    OnDrawItem(Self, AIndex, ARect, AState);
    exit;
  end;

  if (FChart = nil) or not InRange(AIndex, 0, Count - 1) then
    exit;

  Canvas.FillRect(ARect);
  if cloShowCheckboxes in Options then begin
    tbBase := ord(THEMED_BASE[FCheckStyle, Checked[AIndex]]);
    tbOffs := GetThemedButtonOffset(FHot, FDown, false);
    tb := TThemedButton(ord(tbBase) + tbOffs);
    {$IFDEF USE_BITMAPS}
    bmp := CreateBitmap(tb, Canvas.Brush.Color);
    FCheckboxSize := Size(bmp.Width, bmp.Height);
    {$ELSE}
    ted := ThemeServices.GetElementDetails(tb);
    FCheckboxSize := ThemeServices.GetDetailSize(ted);
    {$ENDIF}
  end;

  CalcRects(ARect, rcb, ricon);

  if cloShowCheckboxes in Options then begin
    {$IFDEF USE_BITMAPS}
    Canvas.Draw(rcb.Left, rcb.Top, bmp);
    {$ELSE}
    ThemeServices.DrawElement(Canvas.Handle, ted, rcb);
    {$ENDIF}
    x := rcb.Right;
  end
  else
    x := ARect.Left;

  Canvas.Brush.Style := bsClear;
  if cloShowIcons in Options then begin
    id := TCanvasDrawer.Create(Canvas);
    id.Pen := Chart.Legend.SymbolFrame;
    FLegendItems[AIndex].Draw(id, ricon);
  end
  else
    Canvas.TextOut(x + 2, ARect.Top, FLegendItems.Items[AIndex].Text);
end;

procedure TChartListbox.EnsureSingleChecked(AIndex: Integer);
var
  i: Integer;
  ser: TCustomChartSeries;
begin
  if (FCheckStyle <> cbsRadioButton) or not (cloShowCheckboxes in Options) then
    exit;
  if FLegendItems = nil then
    exit;

  FListener.OnNotify := nil;
  try
    for i := 0 to FLegendItems.Count - 1 do begin
      ser := GetSeries(i);
      if ser = nil then continue;
      if (AIndex < 0) and ser.Active then
        AIndex := i
      else
        ser.Active := AIndex = i;
    end;
  finally
    FListener.OnNotify := @SeriesChanged;
  end;
end;

{ Exchanges the series at the specified listbox indices . }
procedure TChartListbox.ExchangeSeries(AIndex1, AIndex2: Integer);
var
  serIndex1, serIndex2: Integer;
begin
  FChart.DisableRedrawing;
  serIndex1 := Series[AIndex1].Index;
  serIndex2 := Series[AIndex2].Index;
  Series[AIndex1].Index := serIndex2;
  Series[AIndex2].Index := serIndex1;
  Populate;
  FChart.EnableRedrawing;
end;

function TChartListbox.FindSeriesIndex(ASeries: TCustomChartSeries): Integer;
{ searches the internal legend items list for the specified series }
begin
  for Result := 0 to FLegendItems.Count - 1 do
    if GetSeries(Result) = ASeries then exit;
  Result := -1;
end;

function TChartListbox.GetChecked(AIndex: Integer): Boolean;
{ report the checked status. This is determined by the visibility of the
  series with the given index. }
var
  ser: TBasicChartSeries;
begin
  ser := GetSeries(AIndex);
  Result := (ser <> nil) and ser.Active;
end;

function TChartListbox.GetSeries(AIndex: Integer): TCustomChartSeries;
{ extracts, for the given index, the series from the internal
  legend items list. }
var
  legitem: TLegendItem;
begin
  legitem := FLegendItems[AIndex];
  if (legitem <> nil) and (legitem.Owner is TCustomChartSeries) then
    Result := TCustomChartSeries(legitem.Owner)
  else
    Result := nil;
end;

function TChartListbox.GetSeriesCount : Integer;
{ determines the number of series displayed in the listbox.
  Note that this may be different from the Chart.SeriesCount if
  RemoveSeries has been called }
begin
  Result := FLegendItems.Count;
end;

procedure TChartListbox.KeyDown(var AKey: Word; AShift: TShiftState);
{ allows checking/unchecking of items by means of pressing the space bar }
begin
  if
    (AKey = VK_SPACE) and (AShift = []) and
    (cloShowCheckboxes in Options) and (ItemIndex >= 0)
  then begin
    ClickedCheckbox(ItemIndex);
    AKey := VK_UNKNOWN;
  end
  else
    inherited KeyDown(AKey, AShift);
end;

// Item height is determined as maximum of:
// checkbox height, text height, ItemHeight property value.
procedure TChartListbox.MeasureItem(AIndex: Integer; var AHeight: Integer);
begin
  inherited MeasureItem(AIndex, AHeight);
  AHeight := Max(CalculateStandardItemHeight, AHeight);
  if cloShowCheckboxes in Options then
    AHeight := Max(AHeight, GetSystemMetrics(SM_CYMENUCHECK) + 2);
end;

{ standard MouseDown handler: checks if the click occurred on the checkbox,
  on the series icon, or on the text.
  The visibility state of the item's series is changed when clicking on the
  checkbox, and an event OnCheckboxClick is generated.
  An event OnSeriesIconClick is generated when double-clicking on the
  series icon; the method stores the series list index here.
  An event OnItemClick is generated when the click occurred neither on the
  checkbox nor the series icon.
}
procedure TChartListbox.MouseDown(
  AButton: TMouseButton; AShift: TShiftState; AX, AY: Integer);
var
  rcb, ricon: TRect;
  index: Integer;
  p: TPoint;
begin
  FDown := true;
  FSeriesIconClicked := -1;
  try
    if AButton <> mbLeft then exit;
    p := Point(AX, AY);
    index := GetIndexAtXY(AX, AY);
    if index < 0 then exit;
    CalcRects(ItemRect(index), rcb, ricon);
    if (cloShowCheckboxes in Options) and IsPointInRect(p, rcb) then
      ClickedCheckbox(index)
    else if (cloShowIcons in Options) and IsPointInRect(p, ricon) then
      // Remember clicked index for the double click event.
      FSeriesIconClicked := index
    else
      ClickedItem(index);
  finally
    inherited MouseDown(AButton, AShift, AX, AY);
  end;
end;

procedure TChartListbox.MouseEnter;
begin
  FHot := true;
  inherited;
end;

procedure TChartListbox.MouseLeave;
begin
  FHot := false;
  inherited;
end;

procedure TChartListBox.MouseUp(
  AButton: TMouseButton; AShift: TShiftState; AX, AY: Integer);
begin
  FDown := false;
  inherited;
end;
procedure TChartListbox.Notification(AComponent: TComponent; AOperation: TOperation);
begin
  if (AOperation = opRemove) and (AComponent = FChart) then
    FChart := nil;
  inherited Notification(AComponent, AOperation);
end;

procedure TChartListbox.Populate;
{ Populates the listbox with all series contained in the chart. Use the event
  OnPopulate if you don't omit special series from the listbox (RemoveSeries) }
var
  li: TLegendItem;
  list: TIntegerList;
  i, idx: Integer;
begin
  Items.BeginUpdate;
  list := TIntegerList.Create;
  try
    // In case of multiselect, the selected items would get lost here.
    // Store series belonging to selected items in temporary list
    for i:=0 to Items.Count-1 do
      if Selected[i] then
        list.Add(i);

    Items.Clear;
    if (FChart = nil) or (FChart.Series = nil) then exit;
    FreeAndNil(FLegendItems);
    FLegendItems := CreateLegendItems;
    Chart.Legend.SortItemsByOrder(FLegendItems);
    for li in FLegendItems do begin
      // The caption is owner-drawn, but add it anyway for user convenience.
      idx := Items.AddObject(li.Text, li);
      // Restore selected state from temporary list
      if (li.Owner is TCustomChartSeries) and (list.IndexOf(idx) <> -1) then
        Selected[idx] := true;
    end;
    if Assigned(OnPopulate) then
      OnPopulate(Self);
  finally
    list.Free;
    Items.EndUpdate;
  end;
end;

procedure TChartListbox.RemoveSeries(ASeries: TCustomChartSeries);
{ removes the series from the listbox, but keeps it in the chart }
var
  index: Integer;
begin
  index := FindSeriesIndex(ASeries);
  if index = -1 then exit;
  FLegendItems.Delete(index);
  Items.Delete(index);
  Invalidate;
end;

procedure TChartListbox.SeriesChanged(ASender: TObject);
{ Notification procedure of the listener. Responds to chart broadcasts
  by populating the listbox with the chart's series }
begin
  if
    (ASender is TCustomChartSource) and
    not (cloRefreshOnSourceChange in Options)
  then
    exit;
  Populate;
  { in case of radiobutton mode, it is necessary to uncheck the other
    series; there can be only one active series in this mode }
  if
    (ASender is TCustomChartSeries) and TCustomChartSeries(ASender).Active
  then
    EnsureSingleChecked(FindSeriesIndex(TCustomChartSeries(ASender)))
  else
    EnsureSingleChecked;
end;

procedure TChartListbox.SetChart(AValue: TChart);
{ connects the ListBox to the chart }
begin
  if FChart = AValue then exit;

  if FListener.IsListening then
    FChart.Broadcaster.Unsubscribe(FListener);
  FChart := AValue;
  if FChart <> nil then
    FChart.Broadcaster.Subscribe(FListener);
  SeriesChanged(Self);
end;

procedure TChartListbox.SetChecked(AIndex: Integer; AValue: Boolean);
{ shows/hides the series with the specified index of its listbox item.
  In case of radiobutton style, all other series are hidden if AValue=true }
var
  ser: TCustomChartSeries;
begin
  ser := GetSeries(AIndex);
  if (ser = nil) or (ser.Active = AValue) then exit;
  // Do not listen to this change since we know what changed.
  FListener.OnNotify := nil;
  try
    ser.Active := AValue;
  finally
    FListener.OnNotify := @SeriesChanged;
  end;
  if AValue then
    EnsureSingleChecked(FindSeriesIndex(ser));
  Invalidate;
end;

procedure TChartListbox.SetCheckStyle(AValue: TCheckBoxesStyle);
{ selects "checkbox" or "radiobutton" styles. In radiobutton mode, only
  one series can be visible }
begin
  if FCheckStyle = AValue then exit;
  FCheckStyle := AValue;
  EnsureSingleChecked;
  Invalidate;
end;

procedure TChartListbox.SetOnAddSeries(AValue: TChartListboxAddSeriesEvent);
begin
  if TMethod(FOnAddSeries) = TMethod(AValue) then exit;
  FOnAddSeries := AValue;
  Populate;
end;

procedure TChartListbox.SetOnPopulate(AValue: TNotifyEvent);
begin
  if TMethod(FOnPopulate) = TMethod(AValue) then exit;
  FOnPopulate := AValue;
  Populate;
end;

procedure TChartListbox.SetOptions(AValue: TChartListOptions);
begin
  if FOptions = AValue then exit;
  FOptions := AValue;
  EnsureSingleChecked;
  Invalidate;
end;

{ Sorts the listbox by the series names in ascending or descending order.
  Note that only series with Legend.Order = -1 are considered, i.e.
  series having a given legend position are ignored. }
procedure TChartListbox.Sort(Descending: Boolean = false);
var
  list: TStringListUTF8Fast;
  ser: TCustomChartSeries;
  i: Integer;
  selSeries: TCustomChartSeries = nil;
begin
  if ItemIndex > -1 then
    selSeries := Series[ItemIndex];

  list := TStringListUTF8Fast.Create;
  try
    for ser in CustomSeries(FChart) do
      list.AddObject(ser.Title, ser);
    list.Sort;

    FChart.DisableRedrawing;
    try
      for i := 0 to list.Count-1 do
      begin
        ser := TCustomChartSeries(list.Objects[i]);
        ser.Index := IfThen(Descending, list.Count - 1 - i, i);
      end;
      Populate;
      if selSeries <> nil then ItemIndex := FindSeriesIndex(selSeries);
    finally
      FChart.EnableRedrawing;
    end;
  finally
    list.Free;
  end
end;

procedure Register;
begin
  RegisterComponents(CHART_COMPONENT_IDE_PAGE, [TChartListbox]);
end;

{$IFDEF USE_BITMAPS}
initialization
  InitBitmaps;

finalization
  FreeBitmaps;
{$ENDIF}

end.


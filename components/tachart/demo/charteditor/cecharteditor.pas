unit ceChartEditor;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, ButtonPanel, ComCtrls,
  ExtCtrls, StdCtrls,
  TAGraph, TAChartAxis, TACustomSeries, TASeries, TAChartImageList,
  ceAxisFrame;

type

  { TChartEditorForm }

  TChartEditorForm = class(TForm)
    ApplyButton: TPanelBitBtn;
    ButtonPanel: TButtonPanel;
    Image1: TImage;
    Label1: TLabel;
    Notebook: TNotebook;
    TitlePanel: TPanel;
    Splitter1: TSplitter;
    Tree: TTreeView;
    procedure ApplyButtonClick(Sender: TObject);
    procedure FormActivate(Sender: TObject);
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure OKButtonClick(Sender: TObject);
    procedure TreeChanging(Sender: TObject; Node: TTreeNode;
      var AllowChange: Boolean);
    procedure TreeDeletion(Sender: TObject; Node: TTreeNode);
    procedure TreeSelectionChanged(Sender: TObject);
  private
    FChart: TChart;
    FSavedChartStream: TMemoryStream;
    FSavedSeriesStreams: array of TMemoryStream;
    FTitleNode: TTreeNode;
    FFooterNode: TTreeNode;
    FLegendNode: TTreeNode;
    FAxesNode: TTreeNode;
    FSeriesNode: TTreeNode;
    FOKClicked: Boolean;
    function AddFrame(AParentNode: TTreeNode; ACaption: String; AFrame: TFrame;
      AImageIndex: Integer): TTreeNode;
    procedure FindComponentClass({%H-}AReader: TReader; const AClassName: String;
      var AClass: TComponentClass);
    function GetPageIndexOfNode(ANode: TTreeNode): Integer;
    procedure SeriesChangedHandler(Sender: TObject);
    procedure SetChart(AValue: TChart);
    procedure UpdateImages;
  protected
    procedure CalculatePreferredSize(var PreferredWidth, PreferredHeight: integer;
      {%H-}WithThemeSpace: Boolean); override;
    procedure PopulateAxes(AChart: TChart);
    procedure PopulateSeries(AChart: TChart);
    procedure SaveChartToStream;
    procedure SelectNode(ANode: TTreeNode);
    procedure RestoreChartFromStream;
    function Validate(ANode: TTreeNode; out AMsg: String; out AControl: TWinControl): boolean;
  public
    procedure SelectAxis(AxisIndex: Integer; APage: TChartAxisEditorPage);
    procedure SelectFooter;
    procedure SelectLegend;
    procedure SelectSeries(ASeriesIndex: Integer);
    procedure SelectTitle;
    property Chart: TChart read FChart write SetChart;
  end;

var
  ChartEditorForm: TChartEditorForm;

procedure EditChartTitle(AChart: TChart);
procedure EditChartFooter(AChart: TChart);
procedure EditChartLegend(AChart: TChart);
procedure EditChartAxis(AChartAxis: TChartAxis; APage: TChartAxisEditorPage);
procedure EditChartSeries(ASeries: TBasicChartSeries);

implementation

{$R *.lfm}

uses
  LResources, Math,
  TAEnumerators,
  ceTitleFootFrame, ceLegendFrame, ceSeriesFrame, ceImages;

const
  TITLE_NODE_NAME = 'Title';
  FOOTER_NODE_NAME = 'Footer';
  LEGEND_NODE_NAME = 'Legend';
  AXIS_NODE_NAME = 'Axes';
  SERIES_NODE_NAME = 'Series';

{ Helper procedures }

function CreateChartEditorForm(AChart: TChart): TChartEditorForm;
begin
  Result := TChartEditorForm.Create(nil);
  Result.Position := poScreenCenter;
  Result.Chart := AChart;
end;

procedure SelectChartElement(AChart: TChart; ATreeCaption: String);
var
  F: TChartEditorForm;
begin
  F := TChartEditorForm.Create(nil);
  try
    F.Position := poScreenCenter;
    F.Chart := AChart;
    F.Tree.Selected := F.Tree.Items.FindNodeWithText(ATreeCaption);
    F.TreeSelectionChanged(nil);
    F.ShowModal;
  finally
    F.Free;
  end;
end;

{ Global procedures }

procedure EditChartTitle(AChart: TChart);
var
  F: TChartEditorForm;
begin
  F := CreateChartEditorForm(AChart);
  try
    F.SelectTitle;
    F.ShowModal;
  finally
    F.Free;
  end;
end;

procedure EditChartFooter(AChart: TChart);
var
  F: TChartEditorForm;
begin
  F := CreateChartEditorForm(AChart);
  try
    F.SelectFooter;
    F.ShowModal;
  finally
    F.Free;
  end;
end;

procedure EditChartLegend(AChart: TChart);
var
  F: TChartEditorForm;
begin
  F := CreateChartEditorForm(AChart);
  try
    F.SelectLegend;
    F.ShowModal;
  finally
    F.Free;
  end;
end;

procedure EditChartAxis(AChartAxis: TChartAxis; APage: TChartAxisEditorPage);
var
  F: TChartEditorForm;
begin
  F := CreateChartEditorForm(AChartAxis.GetChart as TChart);
  try
    F.SelectAxis(AChartAxis.Index, APage);
    F.ShowModal;
  finally
    F.Free;
  end;
end;

procedure EditChartSeries(ASeries: TBasicChartSeries);
var
  F: TChartEditorForm;
begin
  if not ( (ASeries is TLineSeries) or
           (ASeries is TBarSeries) or
           (ASeries is TAreaSeries)
         ) then
  begin
    raise Exception.Create('Series type not supported for direct editing.');
  end;

  F := CreateChartEditorForm(ASeries.ParentChart);
  try
    F.SelectSeries(ASeries.Index);
    F.ShowModal;
  finally
    F.Free;
  end;
end;


{ TChartEditorForm }

function TChartEditorForm.AddFrame(AParentNode: TTreeNode; ACaption: String;
  AFrame: TFrame; AImageIndex: Integer): TTreeNode;
var
  page: TPage;
begin
  NoteBook.Pages.Add(ACaption);
  page := NoteBook.Page[Notebook.PageCount-1];
  AFrame.Parent := page;
  AFrame.Name := '';
  AFrame.Align := alClient;
  Result := Tree.Items.AddChildObject(AParentNode, ACaption, AFrame);
  Result.ImageIndex := AImageIndex;
  Result.SelectedIndex := AImageIndex;
end;

procedure TChartEditorForm.ApplyButtonClick(Sender: TObject);
var
  msg: String;
  C: TWinControl;
begin
  if not Validate(Tree.Selected, msg, C) then
  begin
    C.SetFocus;
    MessageDlg(msg, mtError, [mbOK], 0);
    ModalResult := mrNone;
  end else
    RestoreChartFromStream;
end;

procedure TChartEditorForm.FormActivate(Sender: TObject);
var
  w: Integer = 0;
  h: Integer = 0;
begin
  GetPreferredSize(w, h);
  Constraints.MinWidth := w;
  Constraints.MinHeight := h;
end;

procedure TChartEditorForm.CalculatePreferredSize(var PreferredWidth, PreferredHeight: integer;
  {%H-}WithThemeSpace: Boolean);
var
  w: Integer = 0;
  h: Integer = 0;
  wm, hm: Integer;
  node: TTreeNode;
begin
  TChartTitleFootFrame(FTitleNode.Data).GetPreferredSize(w, h);
  wm := w;
  hm := h;

  TChartLegendFrame(FLegendNode.Data).GetPreferredSize(w, h);
  wm := Max(w, wm);
  hm := Max(h, hm);

  node := FAxesNode.GetFirstChild;
  if node <> nil then
  begin
    TChartAxisFrame(node.Data).GetPreferredSize(w, h);
    wm := Max(w, wm);
    hm := Max(h, hm);
  end;

  node := FSeriesNode.GetFirstChild;
  if node <> nil then
  begin
    TChartSeriesFrame(node.Data).GetPreferredSize(w, h);
    wm := Max(w, wm);
    hm := Max(h, hm);
  end;

  PreferredWidth := Tree.Constraints.MinWidth +
    Tree.BorderSpacing.Left + Tree.Borderspacing.Right + Splitter1.Width +
    wm +  Notebook.BorderSpacing.Left + Notebook.BorderSpacing.Right;

  PreferredHeight := TitlePanel.Height + TitlePanel.BorderSpacing.Top + hm +
    Notebook.BorderSpacing.Top + Notebook.BorderSpacing.Bottom +
    ButtonPanel.Height + 2*ButtonPanel.BorderSpacing.Around;
end;

// Adapted from private TChart method
procedure TChartEditorForm.FindComponentClass(AReader: TReader;
  const AClassName: String; var AClass: TComponentClass);
var
  i: Integer;
begin
  if AClassName = FChart.ClassName then begin
    AClass := TChart;
    exit;
  end;
  for i := 0 to SeriesClassRegistry.Count - 1 do begin
    AClass := TSeriesClass(SeriesClassRegistry.GetClass(i));
    if AClass.ClassNameIs(AClassName) then exit;
  end;
  AClass := nil;
end;

procedure TChartEditorForm.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
begin
  if not CanClose then
    exit;
  if not FOKClicked then
    RestoreChartFromStream;
end;

procedure TChartEditorForm.FormCreate(Sender: TObject);
begin
  ceImages.ChartImagesDM.ChartImages.GetBitmap(7, ButtonPanel.CloseButton.Glyph);
  Tree.Items.BeginUpdate;
  try
    Tree.Items.Clear;
    FTitleNode := AddFrame(nil, TITLE_NODE_NAME, TChartTitleFootFrame.Create(self), 0);
    FFooterNode := AddFrame(nil, FOOTER_NODE_NAME, TChartTitleFootFrame.Create(self), 1);
    FLegendNode := AddFrame(nil, LEGEND_NODE_NAME, TChartLegendFrame.Create(self), 2);
    FAxesNode := Tree.Items.AddChildObject(nil, AXIS_NODE_NAME, nil);
    FSeriesNode := Tree.Items.AddChildObject(nil, SERIES_NODE_NAME, nil);
    Tree.FullExpand;
  finally
    Tree.Items.EndUpdate;
  end;

  AutoSize := true;
end;

procedure TChartEditorForm.FormDestroy(Sender: TObject);
var
  i: Integer;
begin
  FSavedChartStream.Free;
  for i:=0 to FChart.SeriesCount-1 do
    FSavedSeriesStreams[i].Free;
end;

function TChartEditorForm.GetPageIndexOfNode(ANode: TTreeNode): Integer;
var
  i: Integer;
  page: TPage;
  frame: TFrame;
begin
  frame := TFrame(ANode.Data);
  for i := 0 to Notebook.PageCount-1 do
  begin
    page := Notebook.Page[i];
    if page.ContainsControl(frame) then
    begin
      Result := i;
      exit;
    end;
  end;
  Result := -1;
end;

procedure TChartEditorForm.OKButtonClick(Sender: TObject);
var
  msg: String;
  C: TWinControl;
begin
  if not Validate(Tree.selected, msg, C) then
  begin
    C.SetFocus;
    MessageDlg(msg, mtError, [mbOK], 0);
    ModalResult := mrNone;
  end else
    FOKClicked := true;
end;

procedure TChartEditorForm.TreeChanging(Sender: TObject; Node: TTreeNode;
  var AllowChange: Boolean);
var
  msg: String;
  C: TWinControl;
begin
  if not Validate(Tree.Selected, msg, C) then
  begin
    C.SetFocus;
    MessageDlg(msg, mtError, [mbOk], 0);
    AllowChange := false;
  end;
end;

procedure TChartEditorForm.PopulateAxes(AChart: TChart);
var
  i: Integer;
  frame: TChartAxisFrame;
  axis: TChartAxis;
  imgIdx: Integer;
begin
  FAxesNode.DeleteChildren;
  if AChart <> nil then
  begin
    for i := 0 to AChart.AxisList.Count-1 do
    begin
      axis := AChart.AxisList.Axes[i];
      frame := TChartAxisFrame.Create(self);
      frame.Prepare(axis);
      imgIdx := ord(axis.Alignment) + 3;
      AddFrame(FAxesNode, axis.DisplayName, frame, imgIdx);
    end;
    FAxesNode.Expand(true);
  end;
end;

procedure TChartEditorForm.PopulateSeries(AChart: TChart);
var
  ser: TCustomChartSeries;
  frame: TChartSeriesFrame;
  imgIdx: Integer;
begin
  FSeriesNode.DeleteChildren;
  if AChart <> nil then
  begin
    ChartImagesDM.ChartImages.Chart := nil;
    imgIdx := ChartImagesDM.ChartImages.Count;
    ChartImagesDM.ChartImages.Chart := AChart;
    for ser in CustomSeries(AChart) do
    begin
      frame := TChartSeriesFrame.Create(self);
      frame.Prepare(ser);
      frame.OnChanged := @SeriesChangedHandler;
      AddFrame(FSeriesNode, ser.Title, frame, imgIdx);
      inc(imgIdx);
    end;
    FSeriesNode.Expand(true);
  end;
end;

procedure TChartEditorForm.RestoreChartFromStream;
var
  i: Integer;
  ser: TBasicChartSeries;
begin
  FSavedChartStream.Position := 0;
  ReadComponentFromTextStream(FSavedChartStream, TComponent(FChart), @FindComponentClass);
  for i := 0 to FChart.SeriesCount-1 do
  begin
    FSavedSeriesStreams[i].Position := 0;
    ser := nil;
    ReadComponentFromTextStream(FSavedSeriesStreams[i], TComponent(ser), @FindComponentClass);
    FChart.Series[i].Assign(ser);
  end;
  FChart.Invalidate;
end;

procedure TChartEditorForm.SaveChartToStream;
var
  i: Integer;
begin
  WriteComponentAsTextToStream(FSavedChartStream, FChart);
  for i := 0 to FChart.SeriesCount-1 do
    WriteComponentAsTextToStream(FSavedSeriesStreams[i], FChart.Series[i]);
end;

procedure TChartEditorForm.SelectAxis(AxisIndex: Integer; APage: TChartAxisEditorPage);
var
  node: TTreeNode;
  idx: Integer;
  frame: TChartAxisFrame;
begin
  idx := 0;
  node := FAxesNode.GetFirstChild;
  while node <> nil do begin
    if idx = AxisIndex then
    begin
      SelectNode(node);
      frame := TChartAxisFrame(node.Data);
      frame.Page := APage;
      exit;
    end;
    node := node.GetNextSibling;
    inc(idx);
  end;
end;

procedure TChartEditorForm.SelectFooter;
begin
  SelectNode(FFooterNode);
end;

procedure TChartEditorForm.SelectLegend;
begin
  SelectNode(FLegendNode);
end;

procedure TChartEditorForm.SelectNode(ANode: TTreeNode);
begin
  Tree.Selected := ANode;
  TreeSelectionChanged(nil);
end;

procedure TChartEditorForm.SelectSeries(ASeriesIndex: Integer);
var
  idx: Integer;
  node: TTreeNode;
begin
  idx := 0;
  node := FSeriesNode.GetFirstChild;
  while (node <> nil) do
  begin
    if idx = ASeriesIndex then
    begin
      SelectNode(node);
      exit;
    end;
    node := node.GetNextSibling;
    inc(idx);
  end;
end;

procedure TChartEditorForm.SelectTitle;
begin
  SelectNode(FTitleNode);
end;

procedure TChartEditorForm.SeriesChangedHandler(Sender: TObject);
begin
  UpdateImages;
end;

procedure TChartEditorForm.SetChart(AValue: TChart);
var
  titleFrame: TChartTitleFootFrame;
  legendFrame: TChartLegendFrame;
  i: Integer;
begin
  if FChart = AValue then
    exit;

  FChart := AValue;

  // Save inital chart and series properties for restoring when Cancel is pressed.
  if FSavedChartStream = nil then
  begin
    FSavedChartStream := TMemoryStream.Create;
    SetLength(FSavedSeriesStreams, FChart.SeriesCount);
    for i := 0 to FChart.SeriesCount-1 do
      FSavedSeriesStreams[i] := TMemoryStream.Create;
  end else
  begin
    FSavedChartStream.Clear;
    for i := 0 to FChart.SeriesCount-1 do
      FSavedSeriesStreams[i].Clear;
  end;
  SaveChartToStream;

  titleFrame := TChartTitleFootFrame(FTitleNode.Data);
  titleFrame.Prepare(FChart.Title);

  titleFrame := TChartTitleFootFrame(FFooterNode.Data);
  titleFrame.Prepare(FChart.Foot);

  legendFrame := TChartLegendFrame(FLegendNode.Data);
  legendFrame.Prepare(FChart.Legend);

  PopulateAxes(FChart);
  PopulateSeries(FChart);

  FOKClicked := false;
end;

procedure TChartEditorForm.TreeDeletion(Sender: TObject; Node: TTreeNode);
var
  pageIdx: Integer;
begin
  if (Node.Data = nil) or (csDestroying in ComponentState) then
    exit;
  pageIdx := GetPageIndexOfNode(Node);
  if pageIdx > -1 then
    Notebook.Page[pageIdx].Free;    // Page owns and destroys the frame
end;

procedure TChartEditorForm.TreeSelectionChanged(Sender: TObject);
var
  pageIdx: Integer;
  s: String;
begin
  pageIdx := GetPageIndexOfNode(Tree.Selected);
  if pageIdx > -1 then
  begin
    Notebook.PageIndex := pageIdx;
    s := Tree.Selected.Text;
    if Tree.Selected.Parent = FAxesNode then
      Label1.Caption := 'Axis: ' + s
    else if Tree.Selected.Parent = FSeriesNode then
      Label1.Caption := 'Series: "' + s + '"'
    else
      Label1.Caption := s;
    ChartImagesDM.ChartImages.GetBitmap(Tree.Selected.ImageIndex, Image1.Picture.Bitmap);
  end;
end;

procedure TChartEditorForm.UpdateImages;
begin
  ChartImagesDM.ChartImages.Chart := nil;
  ChartImagesDM.ChartImages.Chart := FChart;
  ChartImagesDM.ChartImages.GetBitmap(Tree.Selected.ImageIndex, Image1.Picture.Bitmap);
end;

function TChartEditorForm.Validate(ANode: TTreeNode; out AMsg: String;
  out AControl: TWinControl): Boolean;
begin
  if ANode = nil then
    exit(true);

  if TObject(ANode.Data) is TChartAxisFrame then
  begin
    Result := TChartAxisFrame(ANode.Data).Validate(AMsg, AControl);
    if not Result then exit;
  end;
  Result := true;
end;

end.


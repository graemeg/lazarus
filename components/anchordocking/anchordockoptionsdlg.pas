{ For license see anchordocking.pas

}
unit AnchorDockOptionsDlg;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, types,
  Forms, Controls, ButtonPanel, StdCtrls, ComCtrls, ExtCtrls, Spin,
  AnchorDocking, AnchorDockStr;

type
  TAnchorDockOptionsFlag = (
    adofShow_ShowHeader, // if option ShowHeader is shown to the user
    adofSpinEdits // use spin edits instead of trackbars
    );
  TAnchorDockOptionsFlags = set of TAnchorDockOptionsFlag;

  { TAnchorDockOptionsFrame }

  TAnchorDockOptionsFrame = class(TFrame)
    DragThresholdLabel: TLabel;
    DragThresholdSpinEdit: TSpinEdit;
    DragThresholdTrackBar: TTrackBar;
    FilledHeadersCheckBox: TCheckBox;
    FlattenHeadersCheckBox: TCheckBox;
    HeaderAlignLeftLabel: TLabel;
    HeaderAlignLeftSpinEdit: TSpinEdit;
    HeaderAlignLeftTrackBar: TTrackBar;
    HeaderAlignTopLabel: TLabel;
    HeaderAlignTopSpinEdit: TSpinEdit;
    HeaderAlignTopTrackBar: TTrackBar;
    HeaderStyleComboBox: TComboBox;
    HeaderStyleLabel: TLabel;
    HideHeaderCaptionForFloatingCheckBox: TCheckBox;
    HighlightFocusedCheckBox: TCheckBox;
    DockSitesCanBeMinimized: TCheckBox;
    FloatingWindowsOnTop: TCheckBox;
    ScaleOnResizeCheckBox: TCheckBox;
    MultiLinePagesCheckBox: TCheckBox;
    ShowHeaderCaptionCheckBox: TCheckBox;
    ShowHeaderCheckBox: TCheckBox;
    SplitterWidthLabel: TLabel;
    SplitterWidthSpinEdit: TSpinEdit;
    SplitterWidthTrackBar: TTrackBar;
    procedure HeaderStyleComboBoxDrawItem({%H-}Control: TWinControl; Index: Integer;
      ARect: TRect; {%H-}State: TOwnerDrawState);
    procedure OkClick(Sender: TObject);
    procedure DragThresholdTrackBarChange(Sender: TObject);
    procedure HeaderAlignLeftTrackBarChange(Sender: TObject);
    procedure HeaderAlignTopTrackBarChange(Sender: TObject);
    procedure ShowHeaderCheckBoxChange(Sender: TObject);
    procedure SplitterWidthTrackBarChange(Sender: TObject);
  private
    FFlags: TAnchorDockOptionsFlags;
    FMaster: TAnchorDockMaster;
    FSettings: TAnchorDockSettings;
    procedure SetFlags(AValue: TAnchorDockOptionsFlags);
    procedure SetMaster(const AValue: TAnchorDockMaster);
    procedure SetSettings(AValue: TAnchorDockSettings);
    procedure UpdateDragThresholdLabel;
    procedure UpdateHeaderAlignTopLabel;
    procedure UpdateHeaderAlignLeftLabel;
    procedure UpdateSplitterWidthLabel;
    procedure UpdateHeaderOptions;
  public
    constructor Create(TheOwner: TComponent); override;
    procedure SaveToMaster;
    procedure LoadFromMaster;
    procedure SaveToSettings(TheSettings: TAnchorDockSettings);
    procedure LoadFromSettings(TheSettings: TAnchorDockSettings);
    property Master: TAnchorDockMaster read FMaster write SetMaster;
    property Settings: TAnchorDockSettings read FSettings write SetSettings;
    property Flags: TAnchorDockOptionsFlags read FFlags write SetFlags;
  end;

var
  DefaultAnchorDockOptionFlags: TAnchorDockOptionsFlags = [];

function ShowAnchorDockOptions(ADockMaster: TAnchorDockMaster): TModalResult;

implementation

function ShowAnchorDockOptions(ADockMaster: TAnchorDockMaster): TModalResult;
var
  Dlg: TForm;
  OptsFrame: TAnchorDockOptionsFrame;
  BtnPanel: TButtonPanel;
begin
  Dlg:=TForm.Create(nil);
  try
    Dlg.DisableAutoSizing{$IFDEF DebugDisableAutoSizing}('ShowAnchorDockOptions'){$ENDIF};
    try
      Dlg.Position:=poScreenCenter;
      Dlg.AutoSize:=true;
      Dlg.Caption:=adrsGeneralDockingOptions;

      OptsFrame:=TAnchorDockOptionsFrame.Create(Dlg);
      OptsFrame.Align:=alClient;
      OptsFrame.Parent:=Dlg;
      OptsFrame.Master:=ADockMaster;

      BtnPanel:=TButtonPanel.Create(Dlg);
      BtnPanel.ShowButtons:=[pbOK, pbCancel];
      BtnPanel.OKButton.OnClick:=@OptsFrame.OkClick;
      BtnPanel.Parent:=Dlg;
    finally
      Dlg.EnableAutoSizing{$IFDEF DebugDisableAutoSizing}('ShowAnchorDockOptions'){$ENDIF};
    end;
    Result:=Dlg.ShowModal;
  finally
    Dlg.Free;
  end;
end;

{$R *.lfm}

{ TAnchorDockOptionsFrame }

procedure TAnchorDockOptionsFrame.HeaderAlignLeftTrackBarChange(Sender: TObject);
begin
  UpdateHeaderAlignLeftLabel;
end;

procedure TAnchorDockOptionsFrame.HeaderAlignTopTrackBarChange(Sender: TObject);
begin
  UpdateHeaderAlignTopLabel;
end;

procedure TAnchorDockOptionsFrame.ShowHeaderCheckBoxChange(Sender: TObject);
begin
  UpdateHeaderOptions;
end;

procedure TAnchorDockOptionsFrame.SplitterWidthTrackBarChange(Sender: TObject);
begin
  UpdateSplitterWidthLabel;
end;

procedure TAnchorDockOptionsFrame.OkClick(Sender: TObject);
begin
  if Settings<>nil then
    SaveToSettings(Settings);
  if Master<>nil then
    SaveToMaster;
end;

procedure TAnchorDockOptionsFrame.HeaderStyleComboBoxDrawItem(
  Control: TWinControl; Index: Integer; ARect: TRect; State: TOwnerDrawState);
var
 st:TADHeaderStyle;
begin
  st:=DockMaster.HeaderStyleName2ADHeaderStyle.Data[Index];
  st.DrawProc(Canvas,st.StyleDesc,ARect,true,true);
end;

procedure TAnchorDockOptionsFrame.DragThresholdTrackBarChange(Sender: TObject);
begin
  UpdateDragThresholdLabel;
end;

procedure TAnchorDockOptionsFrame.SetMaster(const AValue: TAnchorDockMaster);
begin
  if FMaster=AValue then exit;
  FMaster:=AValue;
  if Master<>nil then
    LoadFromMaster;
end;

procedure TAnchorDockOptionsFrame.SetFlags(AValue: TAnchorDockOptionsFlags);
var
  AddedFlags, RemovedFlags: TAnchorDockOptionsFlags;
begin
  if FFlags=AValue then Exit;
  AddedFlags:=AValue-FFlags;
  RemovedFlags:=FFlags-AValue;
  FFlags:=AValue;

  DisableAlign;
  try
    ShowHeaderCheckBox.Visible:=adofShow_ShowHeader in Flags;
    if ShowHeaderCheckBox.Visible then
      ShowHeaderCaptionCheckBox.BorderSpacing.Left:=15
    else
      ShowHeaderCaptionCheckBox.BorderSpacing.Left:=0;

    if adofSpinEdits in AddedFlags then begin
      DragThresholdSpinEdit.Visible:=true;
      DragThresholdTrackBar.Visible:=false;
      DragThresholdSpinEdit.AnchorParallel(akTop,10,Self);
      DragThresholdLabel.AnchorVerticalCenterTo(DragThresholdSpinEdit);
      UpdateDragThresholdLabel;

      SplitterWidthSpinEdit.Visible:=true;
      SplitterWidthTrackBar.Visible:=false;
      SplitterWidthSpinEdit.AnchorToNeighbour(akTop,6,DragThresholdSpinEdit);
      SplitterWidthLabel.AnchorVerticalCenterTo(SplitterWidthSpinEdit);
      UpdateSplitterWidthLabel;

      HeaderAlignTopSpinEdit.Visible:=true;
      HeaderAlignTopTrackBar.Visible:=false;
      HeaderAlignTopSpinEdit.AnchorToNeighbour(akTop,6,DockSitesCanBeMinimized);
      HeaderAlignTopLabel.AnchorVerticalCenterTo(HeaderAlignTopSpinEdit);
      UpdateHeaderAlignTopLabel;

      HeaderAlignLeftSpinEdit.Visible:=true;
      HeaderAlignLeftTrackBar.Visible:=false;
      HeaderAlignLeftSpinEdit.AnchorToNeighbour(akTop,6,HeaderAlignTopSpinEdit);
      HeaderAlignLeftLabel.AnchorVerticalCenterTo(HeaderAlignLeftSpinEdit);
      UpdateHeaderAlignLeftLabel;
    end;
    if adofSpinEdits in RemovedFlags then begin
      DragThresholdSpinEdit.Visible:=false;
      DragThresholdTrackBar.Visible:=true;
      DragThresholdLabel.AnchorParallel(akTop,10,Self);
      UpdateDragThresholdLabel;

      SplitterWidthSpinEdit.Visible:=false;
      SplitterWidthTrackBar.Visible:=true;
      SplitterWidthLabel.AnchorToNeighbour(akTop,6,DragThresholdTrackBar);
      UpdateSplitterWidthLabel;

      HeaderAlignTopSpinEdit.Visible:=false;
      HeaderAlignTopTrackBar.Visible:=true;
      HeaderAlignTopLabel.AnchorToNeighbour(akTop,6,SplitterWidthTrackBar);
      UpdateHeaderAlignTopLabel;

      HeaderAlignLeftSpinEdit.Visible:=false;
      HeaderAlignLeftTrackBar.Visible:=true;
      HeaderAlignLeftLabel.AnchorToNeighbour(akTop,6,HeaderAlignTopTrackBar);
      UpdateHeaderAlignLeftLabel;
    end;
    UpdateHeaderOptions;
  finally
    EnableAlign;
  end;
end;

procedure TAnchorDockOptionsFrame.SetSettings(AValue: TAnchorDockSettings);
begin
  if FSettings=AValue then Exit;
  FSettings:=AValue;
  if Settings<>nil then
    LoadFromSettings(Settings);
end;

procedure TAnchorDockOptionsFrame.UpdateDragThresholdLabel;
var
  s: String;
begin
  s:=adrsDragThreshold;
  if not (adofSpinEdits in Flags) then
    s+=' ('+IntToStr(DragThresholdTrackBar.Position)+')';
  DragThresholdLabel.Caption:=s;
end;

procedure TAnchorDockOptionsFrame.UpdateHeaderAlignTopLabel;
var
  s: String;
begin
  s:=adrsHeaderAlignTop;
  if not (adofSpinEdits in Flags) then
    s+=' ('+IntToStr(HeaderAlignTopTrackBar.Position)+')';
  HeaderAlignTopLabel.Caption:=s;
end;

procedure TAnchorDockOptionsFrame.UpdateHeaderAlignLeftLabel;
var
  s: String;
begin
  s:=adrsHeaderAlignLeft;
  if not (adofSpinEdits in Flags) then
    s+=' ('+IntToStr(HeaderAlignLeftTrackBar.Position)+')';
  HeaderAlignLeftLabel.Caption:=s;
end;

procedure TAnchorDockOptionsFrame.UpdateSplitterWidthLabel;
var
  s: String;
begin
  s:=adrsSplitterWidth;
  if not (adofSpinEdits in Flags) then
    s+=' ('+IntToStr(SplitterWidthTrackBar.Position)+')';
  SplitterWidthLabel.Caption:=s;
end;

procedure TAnchorDockOptionsFrame.UpdateHeaderOptions;
var
  HasHeaders: Boolean;
begin
  HasHeaders:=ShowHeaderCheckBox.Checked;
  ShowHeaderCaptionCheckBox.Enabled:=HasHeaders;
  HideHeaderCaptionForFloatingCheckBox.Enabled:=HasHeaders;
  FlattenHeadersCheckBox.Enabled:=HasHeaders;
  FilledHeadersCheckBox.Enabled:=HasHeaders;
  HeaderStyleLabel.Enabled:=HasHeaders;
  HeaderStyleComboBox.Enabled:=HasHeaders;
  HighlightFocusedCheckBox.Enabled:=HasHeaders;
  DockSitesCanBeMinimized.Enabled:=HasHeaders;
end;

constructor TAnchorDockOptionsFrame.Create(TheOwner: TComponent);
begin
  inherited Create(TheOwner);
  Flags:=DefaultAnchorDockOptionFlags;
end;

procedure TAnchorDockOptionsFrame.SaveToMaster;
var
  CurSettings: TAnchorDockSettings;
begin
  CurSettings:=TAnchorDockSettings.Create;
  try
    Master.SaveSettings(CurSettings);
    SaveToSettings(CurSettings);
    Master.LoadSettings(CurSettings);
  finally
    CurSettings.Free;
  end;
end;

procedure TAnchorDockOptionsFrame.LoadFromMaster;
var
  CurSettings: TAnchorDockSettings;
begin
  CurSettings:=TAnchorDockSettings.Create;
  try
    Master.SaveSettings(CurSettings);
    LoadFromSettings(CurSettings);
  finally
    CurSettings.Free;
  end;
end;

procedure TAnchorDockOptionsFrame.SaveToSettings(
  TheSettings: TAnchorDockSettings);
begin
  if adofSpinEdits in Flags then begin
    TheSettings.DragTreshold:=DragThresholdSpinEdit.Value;
    TheSettings.HeaderAlignTop:=HeaderAlignTopSpinEdit.Value;
    TheSettings.HeaderAlignLeft:=HeaderAlignLeftSpinEdit.Value;
    TheSettings.SplitterWidth:=SplitterWidthSpinEdit.Value;
  end else begin
    TheSettings.DragTreshold:=DragThresholdTrackBar.Position;
    TheSettings.HeaderAlignTop:=HeaderAlignTopTrackBar.Position;
    TheSettings.HeaderAlignLeft:=HeaderAlignLeftTrackBar.Position;
    TheSettings.SplitterWidth:=SplitterWidthTrackBar.Position;
  end;
  TheSettings.DockSitesCanBeMinimized:=DockSitesCanBeMinimized.Checked;
  TheSettings.FloatingWindowsOnTop:=FloatingWindowsOnTop.Checked;
  TheSettings.HeaderFilled:=FilledHeadersCheckBox.Checked;
  TheSettings.HeaderFlatten:=FlattenHeadersCheckBox.Checked;
  TheSettings.HeaderHighlightFocused:=HighlightFocusedCheckBox.Checked;
  TheSettings.HeaderStyle:=DockMaster.HeaderStyleName2ADHeaderStyle.Data[HeaderStyleComboBox.ItemIndex].StyleDesc.Name;
  TheSettings.HideHeaderCaptionFloatingControl:=HideHeaderCaptionForFloatingCheckBox.Checked;
  TheSettings.MultiLinePages:=MultiLinePagesCheckBox.Checked;
  TheSettings.ScaleOnResize:=ScaleOnResizeCheckBox.Checked;
  TheSettings.ShowHeader:=ShowHeaderCheckBox.Checked;
  TheSettings.ShowHeaderCaption:=ShowHeaderCaptionCheckBox.Checked;
end;

procedure TAnchorDockOptionsFrame.LoadFromSettings(
  TheSettings: TAnchorDockSettings);
var
  StyleIndex,CurrentStyleIndex: Integer;
  sl: TStringList;
begin
  DragThresholdTrackBar.Hint:=
    adrsAmountOfPixelTheMouseHasToDragBeforeDragStarts;
  DragThresholdTrackBar.Position:=TheSettings.DragTreshold;
  DragThresholdSpinEdit.Value:=TheSettings.DragTreshold;
  UpdateDragThresholdLabel;

  HeaderAlignTopTrackBar.Hint:=
    adrsMoveHeaderToTopWhenWidthHeight100HeaderAlignTop;
  HeaderAlignTopTrackBar.Position:=TheSettings.HeaderAlignTop;
  HeaderAlignTopSpinEdit.Value:=TheSettings.HeaderAlignTop;
  UpdateHeaderAlignTopLabel;

  HeaderAlignLeftTrackBar.Hint:=
    adrsMoveHeaderToLeftWhenWidthHeight100HeaderAlignLeft;
  HeaderAlignLeftTrackBar.Position:=TheSettings.HeaderAlignLeft;
  HeaderAlignLeftSpinEdit.Value:=TheSettings.HeaderAlignLeft;
  UpdateHeaderAlignLeftLabel;

  SplitterWidthTrackBar.Hint:=adrsSplitterThickness;
  SplitterWidthTrackBar.Position:=TheSettings.SplitterWidth;
  SplitterWidthSpinEdit.Value:=TheSettings.SplitterWidth;
  UpdateSplitterWidthLabel;

  ScaleOnResizeCheckBox.Caption:=adrsScaleOnResize;
  ScaleOnResizeCheckBox.Hint:=adrsScaleSubSitesWhenASiteIsResized;
  ScaleOnResizeCheckBox.Checked:=TheSettings.ScaleOnResize;

  ShowHeaderCheckBox.Caption:=adrsShowHeaders;
  ShowHeaderCheckBox.Hint:=
    adrsEachDockedWindowHasAHeaderThatAllowsDraggingHasACo;
  ShowHeaderCheckBox.Checked:=TheSettings.ShowHeader;
  UpdateHeaderOptions;

  ShowHeaderCaptionCheckBox.Caption:=adrsShowHeaderCaptions;
  ShowHeaderCaptionCheckBox.Hint:=adrsShowCaptionsOfDockedControlsInTheHeader;
  ShowHeaderCaptionCheckBox.Checked:=TheSettings.ShowHeaderCaption;

  HideHeaderCaptionForFloatingCheckBox.Caption:=adrsNoCaptionsForFloatingSites;
  HideHeaderCaptionForFloatingCheckBox.Hint:=
    adrsHideHeaderCaptionsForSitesWithOnlyOneDockedControl;
  HideHeaderCaptionForFloatingCheckBox.Checked:=
    TheSettings.HideHeaderCaptionFloatingControl;

  FlattenHeadersCheckBox.Checked:=TheSettings.HeaderFlatten;
  FlattenHeadersCheckBox.Caption:=adrsFlattenHeaders;
  FlattenHeadersCheckBox.Hint:=adrsFlattenHeadersHint;

  FilledHeadersCheckBox.Checked:=TheSettings.HeaderFilled;
  FilledHeadersCheckBox.Caption:=adrsFilledHeaders;
  FilledHeadersCheckBox.Hint:=adrsFilledHeadersHint;

  sl:=TStringList.Create;
  try
    for StyleIndex:=0 to DockMaster.HeaderStyleName2ADHeaderStyle.Count-1 do begin
      sl.Add(DockMaster.HeaderStyleName2ADHeaderStyle.Data[StyleIndex].StyleDesc.Name);
      if DockMaster.HeaderStyleName2ADHeaderStyle.Data[StyleIndex].StyleDesc.Name=TheSettings.HeaderStyle then
        CurrentStyleIndex:=StyleIndex;
    end;
    HeaderStyleComboBox.Items.Assign(sl);
  finally
    sl.Free;
  end;
  HeaderStyleLabel.Caption:=adrsHeaderStyle;
  HeaderStyleComboBox.ItemIndex:=CurrentStyleIndex;

  HighlightFocusedCheckBox.Checked:=TheSettings.HeaderHighlightFocused;
  HighlightFocusedCheckBox.Caption:=adrsHighlightFocused;
  HighlightFocusedCheckBox.Hint:=adrsHighlightFocusedHint;

  DockSitesCanBeMinimized.Checked:=TheSettings.DockSitesCanBeMinimized;
  DockSitesCanBeMinimized.Caption:=adrsAllowDockSitesToBeMinimized;
  DockSitesCanBeMinimized.Hint:=adrsAllowDockSitesToBeMinimized;

  MultiLinePagesCheckBox.Caption:=adrsMultiLinePages;
  MultiLinePagesCheckBox.Hint:=adrsMultiLinePagesHint;
  MultiLinePagesCheckBox.Checked:=TheSettings.MultiLinePages;

  FloatingWindowsOnTop.Caption:=adrsFloatingWindowsOnTop;
  FloatingWindowsOnTop.Hint:=adrsFloatingWindowsOnTopHint;
  FloatingWindowsOnTop.Checked:=TheSettings.FloatingWindowsOnTop;
end;

end.


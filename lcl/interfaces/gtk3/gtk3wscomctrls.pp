{
 *****************************************************************************
 *                             Gtk3WSComCtrls.pp                             *
 *                             -----------------                             * 
 *                                                                           *
 *                                                                           *
 *****************************************************************************

 *****************************************************************************
  This file is part of the Lazarus Component Library (LCL)

  See the file COPYING.modifiedLGPL.txt, included in this distribution,
  for details about the license.
 *****************************************************************************
}
unit Gtk3WSComCtrls;

{$mode objfpc}{$H+}
{$I gtk3defines.inc}

interface

uses
  // libs
  LazGtk3, LazGdk3, LazGlib2,
  // RTL, FCL, LCL
  ComCtrls, Classes, LCLType, LMessages, Controls, Graphics, StdCtrls, Forms,
  LCLProc, LCLIntf, ImgList, Math, Sysutils, ctypes, InterfaceBase,
  // widgetset
  WSComCtrls, WSLCLClasses, WSControls, WSProc,
  Gtk3WSControls, Gtk3Int, gtk3widgets;
  
type
  { TGtk3WSCustomPage }

  TGtk3WSCustomPage = class(TWSCustomPage)
  published
    class function CreateHandle(const AWinControl: TWinControl;
      const AParams: TCreateParams): TLCLIntfHandle; override;
    class procedure UpdateProperties(const ACustomPage: TCustomPage); override;
    class procedure SetBounds(const {%H-}AWinControl: TWinControl; const {%H-}ALeft, {%H-}ATop, {%H-}AWidth, {%H-}AHeight: Integer); override;
    class procedure SetFont(const AWinControl: TWinControl; const AFont: TFont); override;
    class procedure ShowHide(const AWinControl: TWinControl); override;
    class function GetDefaultClientRect(const AWinControl: TWinControl;
             const {%H-}aLeft, {%H-}aTop, {%H-}aWidth, {%H-}aHeight: integer; var aClientRect: TRect
             ): boolean; override;
  end;

  { TGtk3WSCustomTabControl }

  TGtk3WSCustomTabControl = class(TWSCustomTabControl)
  published
    class function CreateHandle(const AWinControl: TWinControl;
                                const AParams: TCreateParams): TLCLIntfHandle; override;
    (*
    class function GetDefaultClientRect(const AWinControl: TWinControl;
            const {%H-}aLeft, {%H-}aTop, aWidth, aHeight: integer; var aClientRect: TRect
            ): boolean; override;
    *)
    class procedure AddPage(const ATabControl: TCustomTabControl;
      const AChild: TCustomPage; const AIndex: integer); override;
    class procedure MovePage(const ATabControl: TCustomTabControl;
      const AChild: TCustomPage; const NewIndex: integer); override;
    class procedure RemovePage(const ATabControl: TCustomTabControl; const AIndex: integer); override;

    class function GetCapabilities: TCTabControlCapabilities; override;
    class function GetNotebookMinTabHeight(const AWinControl: TWinControl): integer; override;
    class function GetNotebookMinTabWidth(const AWinControl: TWinControl): integer; override;
    class function GetTabIndexAtPos(const ATabControl: TCustomTabControl; const AClientPos: TPoint): integer; override;
    class function GetTabRect(const ATabControl: TCustomTabControl; const AIndex: Integer): TRect; override;
    class procedure SetPageIndex(const ATabControl: TCustomTabControl; const AIndex: integer); override;
    class procedure SetTabCaption(const ATabControl: TCustomTabControl; const AChild: TCustomPage; const AText: string); override;
    class procedure SetTabPosition(const ATabControl: TCustomTabControl; const ATabPosition: TTabPosition); override;
    class procedure ShowTabs(const ATabControl: TCustomTabControl; AShowTabs: boolean); override;
    class procedure UpdateProperties(const ATabControl: TCustomTabControl); override;
  end;

  { TGtk3WSStatusBar }

  TGtk3WSStatusBar = class(TWSStatusBar)
  published
    class function CreateHandle(const AWinControl: TWinControl; const AParams: TCreateParams): TLCLIntfHandle; override;
    class procedure PanelUpdate(const AStatusBar: TStatusBar; PanelIndex: integer); override;
    class procedure SetPanelText(const AStatusBar: TStatusBar; PanelIndex: integer); override;
    class procedure Update(const AStatusBar: TStatusBar); override;
    class procedure GetPreferredSize(const {%H-}AWinControl: TWinControl;
                        var {%H-}PreferredWidth, PreferredHeight: integer;
                        {%H-}WithThemeSpace: Boolean); override;

    class procedure SetSizeGrip(const AStatusBar: TStatusBar; {%H-}SizeGrip: Boolean); override;
  end;

  { TGtk3WSTabSheet }

  TGtk3WSTabSheet = class(TWSTabSheet)
  published
  end;

  { TGtk3WSPageControl }

  TGtk3WSPageControl = class(TWSPageControl)
  published
  end;

  { TGtk3WSCustomListView }

  TGtk3WSCustomListView = class(TWSCustomListView)
  private
    class procedure SetPropertyInternal(const ALV: TCustomListView; const AProp: TListViewProperty; const AIsSet: Boolean);
  published
    // columns
    class procedure ColumnDelete(const ALV: TCustomListView; const AIndex: Integer); override;
    class function  ColumnGetWidth(const ALV: TCustomListView; const {%H-}AIndex: Integer; const AColumn: TListColumn): Integer; override;
    class procedure ColumnInsert(const ALV: TCustomListView; const AIndex: Integer; const AColumn: TListColumn); override;
    class procedure ColumnMove(const ALV: TCustomListView; const AOldIndex, ANewIndex: Integer; const {%H-}AColumn: TListColumn); override;
    class procedure ColumnSetAlignment(const ALV: TCustomListView; const AIndex: Integer; const {%H-}AColumn: TListColumn; const AAlignment: TAlignment); override;
    class procedure ColumnSetAutoSize(const ALV: TCustomListView; const AIndex: Integer; const {%H-}AColumn: TListColumn; const AAutoSize: Boolean); override;
    class procedure ColumnSetCaption(const ALV: TCustomListView; const AIndex: Integer; const {%H-}AColumn: TListColumn; const ACaption: String); override;
    class procedure ColumnSetImage(const ALV: TCustomListView; const {%H-}AIndex: Integer; const {%H-}AColumn: TListColumn; const {%H-}AImageIndex: Integer); override;
    class procedure ColumnSetMaxWidth(const ALV: TCustomListView; const AIndex: Integer; const {%H-}AColumn: TListColumn; const AMaxWidth: Integer); override;
    class procedure ColumnSetMinWidth(const ALV: TCustomListView; const AIndex: Integer; const {%H-}AColumn: TListColumn; const AMinWidth: integer); override;
    class procedure ColumnSetWidth(const ALV: TCustomListView; const AIndex: Integer; const {%H-}AColumn: TListColumn; const AWidth: Integer); override;
    class procedure ColumnSetVisible(const ALV: TCustomListView; const AIndex: Integer; const {%H-}AColumn: TListColumn; const AVisible: Boolean); override;
    class procedure ColumnSetSortIndicator(const ALV: TCustomListView; const AIndex: Integer;
      const AColumn: TListColumn; const ASortIndicator: TSortIndicator);override;

    // items
    class procedure ItemDelete(const ALV: TCustomListView; const AIndex: Integer); override;
    class function  ItemDisplayRect(const ALV: TCustomListView; const AIndex, ASubItem: Integer; {%H-}ACode: TDisplayCode): TRect; override;
    class procedure ItemExchange(const ALV: TCustomListView; {%H-}AItem: TListItem; const AIndex1, AIndex2: Integer); override;
    class procedure ItemMove(const ALV: TCustomListView; {%H-}AItem: TListItem; const AFromIndex, AToIndex: Integer); override;
    class function  ItemGetChecked(const {%H-}ALV: TCustomListView; const {%H-}AIndex: Integer; const AItem: TListItem): Boolean; override;
    class function  ItemGetState(const ALV: TCustomListView; const AIndex: Integer; const {%H-}AItem: TListItem; const AState: TListItemState; out AIsSet: Boolean): Boolean; override; // returns True if supported
    class procedure ItemInsert(const ALV: TCustomListView; const AIndex: Integer; const {%H-}AItem: TListItem); override;
    class procedure ItemSetChecked(const ALV: TCustomListView; const {%H-}AIndex: Integer; const {%H-}AItem: TListItem; const {%H-}AChecked: Boolean); override;
    class procedure ItemSetImage(const ALV: TCustomListView; const AIndex: Integer; const {%H-}AItem: TListItem; const {%H-}ASubIndex, AImageIndex: Integer); override;
    class procedure ItemSetState(const ALV: TCustomListView; const AIndex: Integer; const {%H-}AItem: TListItem; const AState: TListItemState; const AIsSet: Boolean); override;
    class procedure ItemSetText(const ALV: TCustomListView; const AIndex: Integer; const {%H-}AItem: TListItem; const {%H-}ASubIndex: Integer; const {%H-}AText: String); override;
    class procedure ItemShow(const ALV: TCustomListView; const AIndex: Integer; const {%H-}AItem: TListItem; const {%H-}PartialOK: Boolean); override;
    class function  ItemGetPosition(const ALV: TCustomListView; const AIndex: Integer): TPoint; override;
    class procedure ItemUpdate(const ALV: TCustomListView; const {%H-}AIndex: Integer; const {%H-}AItem: TListItem); override;

    // lv
    class function CreateHandle(const AWinControl: TWinControl; const AParams: TCreateParams): TLCLIntfHandle; override;
    // class procedure DestroyHandle(const AWinControl: TWinControl); override;

    class procedure BeginUpdate(const ALV: TCustomListView); override;
    class procedure EndUpdate(const ALV: TCustomListView); override;

    class function GetBoundingRect(const ALV: TCustomListView): TRect; override;
    class function GetDropTarget(const ALV: TCustomListView): Integer; override;
    class function GetFocused(const ALV: TCustomListView): Integer; override;
    class function GetHoverTime(const ALV: TCustomListView): Integer; override;
    class function GetItemAt(const ALV: TCustomListView; x,y: integer): Integer; override;
    class function GetSelCount(const ALV: TCustomListView): Integer; override;
    class function GetSelection(const ALV: TCustomListView): Integer; override;
    class function GetTopItem(const ALV: TCustomListView): Integer; override;
    class function GetViewOrigin(const ALV: TCustomListView): TPoint; override;
    class function GetVisibleRowCount(const ALV: TCustomListView): Integer; override;

    class procedure SetAllocBy(const ALV: TCustomListView; const {%H-}AValue: Integer); override;
    class procedure SetColor(const AWinControl: TWinControl); override;
    class procedure SetDefaultItemHeight(const ALV: TCustomListView; const {%H-}AValue: Integer); override;
    class procedure SetFont(const AWinControl: TWinControl; const AFont: TFont); override;
    class procedure SetHotTrackStyles(const ALV: TCustomListView; const {%H-}AValue: TListHotTrackStyles); override;
    class procedure SetHoverTime(const ALV: TCustomListView; const {%H-}AValue: Integer); override;
    //    class procedure SetIconOptions(const ALV: TCustomListView; const AValue: TIconOptions); override;
    class procedure SetImageList(const ALV: TCustomListView; const AList: TListViewImageList; const AValue: TCustomImageListResolution); override;
    class procedure SetItemsCount(const ALV: TCustomListView; const {%H-}Avalue: Integer); override;
    class procedure SetProperty(const ALV: TCustomListView; const AProp: TListViewProperty; const AIsSet: Boolean); override;
    class procedure SetProperties(const ALV: TCustomListView; const AProps: TListViewProperties); override;
    class procedure SetScrollBars(const ALV: TCustomListView; const AValue: TScrollStyle); override;
    class procedure SetSort(const ALV: TCustomListView; const {%H-}AType: TSortType; const {%H-}AColumn: Integer;
      const {%H-}ASortDirection: TSortDirection); override;
    class procedure SetViewOrigin(const ALV: TCustomListView; const AValue: TPoint); override;
    class procedure SetViewStyle(const ALV: TCustomListView; const AValue: TViewStyle); override;
  end;

  { TGtk3WSListView }

  TGtk3WSListView = class(TWSListView)
  published
  end;

  { TGtk3WSProgressBar }

  TGtk3WSProgressBar = class(TWSProgressBar)
  published
    class function CreateHandle(const AWinControl: TWinControl; const AParams: TCreateParams): TLCLIntfHandle; override;
    class procedure ApplyChanges(const AProgressBar: TCustomProgressBar); override;
    class procedure SetPosition(const AProgressBar: TCustomProgressBar; const NewPosition: integer); override;
    class procedure SetStyle(const AProgressBar: TCustomProgressBar; const NewStyle: TProgressBarStyle); override;
  end;

  { TGtk3WSCustomUpDown }

  TGtk3WSCustomUpDown = class(TWSCustomUpDown)
  published
  end;

  { TGtk3WSUpDown }

  TGtk3WSUpDown = class(TWSUpDown)
  published
  end;

  { TGtk3WSToolButton }

  TGtk3WSToolButton = class(TWSToolButton)
  published
  end;

  { TGtk3WSToolBar }

  TGtk3WSToolBar = class(TWSToolBar)
  published
    class function CreateHandle(const AWinControl: TWinControl; const AParams: TCreateParams): TLCLIntfHandle; override;
  end;

  { TGtk3WSTrackBar }

  TGtk3WSTrackBar = class(TWSTrackBar)
  published
    class function CreateHandle(const AWinControl: TWinControl; const AParams: TCreateParams): TLCLIntfHandle; override;
    class procedure ApplyChanges(const ATrackBar: TCustomTrackBar); override;
    class function  GetPosition(const ATrackBar: TCustomTrackBar): integer; override;
    class procedure SetPosition(const ATrackBar: TCustomTrackBar; const NewPosition: integer); override;
    class procedure SetOrientation(const ATrackBar: TCustomTrackBar; const {%H-}AOrientation: TTrackBarOrientation); override;
  end;

  { TGtk3WSCustomTreeView }

  TGtk3WSCustomTreeView = class(TWSCustomTreeView)
  published
  end;

  { TGtk3WSTreeView }

  TGtk3WSTreeView = class(TWSTreeView)
  published
  end;


implementation
uses gtk3procs;

{ TGtk3WSTrackBar }

class function TGtk3WSTrackBar.CreateHandle(const AWinControl: TWinControl;
  const AParams: TCreateParams): TLCLIntfHandle;
var
  ATrack: TGtk3TrackBar;
  APt: TPoint;
begin
  ATrack := TGtk3TrackBar.Create(AWinControl, AParams);
  Result := TLCLIntfHandle(ATrack);
end;

class procedure TGtk3WSTrackBar.ApplyChanges(const ATrackBar: TCustomTrackBar);
var
  ATrack: TGtk3TrackBar;
  APt: TPoint;
begin
  // inherited ApplyChanges(ATrackBar);
  if not WSCheckHandleAllocated(ATrackBar, 'ApplyChanges') then
    Exit;
  ATrack := TGtk3TrackBar(ATrackBar.Handle);
  APt.X := ATrackBar.Min;
  APt.Y := ATrackBar.Max;
  ATrack.BeginUpdate;
  ATrack.Range := APt;
  ATrack.Position:=ATrackBar.Position;
  ATrack.SetStep(ATrackBar.Frequency, ATrackBar.PageSize);
  ATrack.SetScalePos(ATrackBar.ScalePos);
  ATrack.SetTickMarks(ATrackbar.TickMarks, ATrackBar.TickStyle);
  ATrack.Reversed := ATrackBar.Reversed;
  ATrack.EndUpdate;
end;

class function TGtk3WSTrackBar.GetPosition(const ATrackBar: TCustomTrackBar
  ): integer;
begin
  if not WSCheckHandleAllocated(ATrackBar, 'GetPosition') then
    Exit(0);
  Result := TGtk3TrackBar(ATrackBar.Handle).Position;
end;

class procedure TGtk3WSTrackBar.SetPosition(const ATrackBar: TCustomTrackBar;
  const NewPosition: integer);
begin
  if not WSCheckHandleAllocated(ATrackBar, 'SetPosition') then
    Exit;
  TGtk3TrackBar(ATrackBar.Handle).BeginUpdate;
  TGtk3TrackBar(ATrackBar.Handle).Position := NewPosition;
  TGtk3TrackBar(ATrackBar.Handle).EndUpdate;
end;

class procedure TGtk3WSTrackBar.SetOrientation(
  const ATrackBar: TCustomTrackBar; const AOrientation: TTrackBarOrientation);
begin
  // inherited SetOrientation(ATrackBar, AOrientation);
  if not WSCheckHandleAllocated(ATrackBar, 'SetOrientation') then
    Exit;
  if TGtk3TrackBar(ATrackBar.Handle).GetTrackBarOrientation <> AOrientation then
    RecreateWnd(ATrackBar);
end;

{ TGtk3WSToolBar }

class function TGtk3WSToolBar.CreateHandle(const AWinControl: TWinControl;
  const AParams: TCreateParams): TLCLIntfHandle;
var
  AToolBar: TGtk3ToolBar;
begin
  AToolBar := TGtk3ToolBar.Create(AWinControl, AParams);
  Result := TLCLIntfHandle(AToolBar);
end;

{ TGtk3WSProgressBar }

class function TGtk3WSProgressBar.CreateHandle(const AWinControl: TWinControl;
  const AParams: TCreateParams): TLCLIntfHandle;
var
  AProgress: TGtk3ProgressBar;
begin
  AProgress := TGtk3ProgressBar.Create(AWinControl, AParams);
  Result := TLCLIntfHandle(AProgress);
end;

class procedure TGtk3WSProgressBar.ApplyChanges(
  const AProgressBar: TCustomProgressBar);
begin
  // inherited ApplyChanges(AProgressBar);
  if not WSCheckHandleAllocated(AProgressBar, 'ApplyChanges') then
    Exit;
  TGtk3ProgressBar(AProgressBar.Handle).BeginUpdate;
  SetPosition(AProgressBar, AProgressBar.Position);
  SetStyle(AProgressBar, AProgressBar.Style);
  TGtk3ProgressBar(AProgressBar.Handle).ShowText := AProgressBar.BarShowText;
  TGtk3ProgressBar(AProgressBar.Handle).Orientation := AProgressBar.Orientation;
  TGtk3ProgressBar(AProgressBar.Handle).EndUpdate;
end;

class procedure TGtk3WSProgressBar.SetPosition(
  const AProgressBar: TCustomProgressBar; const NewPosition: integer);
begin
  if not WSCheckHandleAllocated(AProgressBar, 'SetPosition') then
    Exit;
  TGtk3ProgressBar(AProgressBar.Handle).BeginUpdate;
  TGtk3ProgressBar(AProgressBar.Handle).Position := NewPosition;
  TGtk3ProgressBar(AProgressBar.Handle).EndUpdate;
end;

class procedure TGtk3WSProgressBar.SetStyle(
  const AProgressBar: TCustomProgressBar; const NewStyle: TProgressBarStyle);
begin
  // inherited SetStyle(AProgressBar, NewStyle);
  if not WSCheckHandleAllocated(AProgressBar, 'SetStyle') then
    Exit;
  TGtk3ProgressBar(AProgressBar.Handle).BeginUpdate;
  TGtk3ProgressBar(AProgressBar.Handle).Style := NewStyle;
  TGtk3ProgressBar(AProgressBar.Handle).EndUpdate;
end;

{ TGtk3WSCustomListView }

class function TGtk3WSCustomListView.CreateHandle(
  const AWinControl: TWinControl; const AParams: TCreateParams): TLCLIntfHandle;
var
  AListView: TGtk3ListView;
begin
  // DebugLn('TGtk3WSCustomListView.CreateHandle');
  AListView := TGtk3ListView.Create(AWinControl, AParams);
  Result := TLCLIntfHandle(AListView);
end;
(*
class procedure TGtk3WSCustomListView.DestroyHandle(
  const AWinControl: TWinControl);
begin
  inherited DestroyHandle(AWinControl);
end;
*)

class procedure TGtk3WSCustomListView.SetPropertyInternal(
  const ALV: TCustomListView; const AProp: TListViewProperty;
  const AIsSet: Boolean);
const
  BoolToSelectionMode: array[Boolean] of TGtkSelectionMode = (
    1 {GTK_SELECTION_SINGLE},
    3 {GTK_SELECTION_MULTIPLE}
  );
begin
  case AProp of
    lvpAutoArrange:
    begin
      // TODO: implement ??
    end;
    lvpCheckboxes:
    begin
      // if TListView(ALV).ViewStyle in [vsReport,vsList] then
      // AddRemoveCheckboxRenderer(ALV, GetWidgetInfo(Widgets^.MainView), AIsSet);
    end;
    lvpColumnClick:
    begin
      // allow only column modifications when in report mode
      if TListView(ALV).ViewStyle <> vsReport then Exit;
      if TGtk3ListView(ALV.Handle).IsTreeView then
        PGtkTreeView(TGtk3ListView(ALV.Handle).GetContainerWidget)^.set_headers_clickable(AIsSet);
    end;
    lvpFlatScrollBars:
    begin
      // TODO: implement ??
    end;
    lvpFullDrag:
    begin
      // TODO: implement ??
    end;
    lvpGridLines:
    begin
      // TODO: better implementation
      // maybe possible with some cellwidget hacking
      // this create rows with alternating colors
      if TGtk3ListView(ALV.Handle).IsTreeView then
      begin
        if AIsSet then
          PGtkTreeView(TGtk3ListView(ALV.Handle).GetContainerWidget)^.set_grid_lines(GTK_TREE_VIEW_GRID_LINES_BOTH)
        else
          PGtkTreeView(TGtk3ListView(ALV.Handle).GetContainerWidget)^.set_grid_lines(GTK_TREE_VIEW_GRID_LINES_NONE);
      end;
    end;
    lvpHideSelection:
    begin
      // TODO: implement
      // should be possible with some focus in/out events
    end;
    lvpHotTrack:
    begin
      // TODO: implement
      // should be possible with some mouse tracking
    end;
    lvpMultiSelect:
    begin
      if TGtk3ListView(ALV.Handle).IsTreeView then
        PGtkTreeView(TGtk3ListView(ALV.Handle).GetContainerWidget)^.get_selection^.set_mode(BoolToSelectionMode[AIsSet])
      else
        PGtkIconView(TGtk3ListView(ALV.Handle).GetContainerWidget)^.set_selection_mode(BoolToSelectionMode[AIsSet]);
    end;
    lvpOwnerDraw:
    begin
      // TODO: implement
      // use custom images/widgets ?
    end;
    lvpReadOnly:
    begin
      // TODO: implement inline editor ?
    end;
    lvpRowSelect:
    begin
      // TODO: implement ???
      // how to do cell select
    end;
    lvpShowColumnHeaders:
    begin
      // allow only column modifications when in report mode
      if not (TListView(ALV).ViewStyle in [vsList, vsReport]) then Exit;
      if TGtk3ListView(ALV.Handle).IsTreeView then
      begin
        PGtkTreeView(TGtk3ListView(ALV.Handle).GetContainerWidget)^.set_headers_visible(AIsSet and (TListView(ALV).ViewStyle = vsReport));
        PGtkTreeView(TGtk3ListView(ALV.Handle).GetContainerWidget)^.resize_children;
      end;
    end;
    lvpShowWorkAreas:
    begin
      // TODO: implement ???
    end;
    lvpWrapText:
    begin
      // TODO: implement ???
    end;
  end;
end;

class procedure TGtk3WSCustomListView.ColumnDelete(const ALV: TCustomListView;
  const AIndex: Integer);
begin
  if not WSCheckHandleAllocated(ALV, 'ColumnDelete') then
    Exit;
  // DebugLn('TGtk3WSCustomListView.ColumnDelete ');
  TGtk3ListView(ALV.Handle).ColumnDelete(AIndex);
end;

class function TGtk3WSCustomListView.ColumnGetWidth(const ALV: TCustomListView;
  const AIndex: Integer; const AColumn: TListColumn): Integer;
begin
  if not WSCheckHandleAllocated(ALV, 'ColumnGetWidth') then
    Exit;
  // DebugLn('TGtk3WSCustomListView.ColumnGetWidth ');
  Result := TGtk3ListView(ALV.Handle).ColumnGetWidth(AIndex);
end;

class procedure TGtk3WSCustomListView.ColumnInsert(const ALV: TCustomListView;
  const AIndex: Integer; const AColumn: TListColumn);
begin
  // DebugLn('TGtk3WSCustomListView.ColumnInsert ');
  if not WSCheckHandleAllocated(ALV, 'ColumnInsert') then
    Exit;
  TGtk3ListView(ALV.Handle).ColumnInsert(AIndex, AColumn);
  // inherited ColumnInsert(ALV, AIndex, AColumn);
end;

class procedure TGtk3WSCustomListView.ColumnMove(const ALV: TCustomListView;
  const AOldIndex, ANewIndex: Integer; const AColumn: TListColumn);
begin
  DebugLn('TGtk3WSCustomListView.ColumnMove ');
  // inherited ColumnMove(ALV, AOldIndex, ANewIndex, AColumn);
end;

class procedure TGtk3WSCustomListView.ColumnSetAlignment(
  const ALV: TCustomListView; const AIndex: Integer;
  const AColumn: TListColumn; const AAlignment: TAlignment);
begin
  if not WSCheckHandleAllocated(ALV, 'ColumnSetAlignment') then
    Exit;
  // DebugLn('TGtk3WSCustomListView.ColumnSetAlignment ');
  // inherited ColumnSetAlignment(ALV, AIndex, AColumn, AAlignment);
  TGtk3ListView(ALV.Handle).SetAlignment(AIndex, AColumn, AAlignment);
end;

class procedure TGtk3WSCustomListView.ColumnSetAutoSize(
  const ALV: TCustomListView; const AIndex: Integer;
  const AColumn: TListColumn; const AAutoSize: Boolean);
begin
  if not WSCheckHandleAllocated(ALV, 'ColumnSetAutoSize') then
    Exit;
  // DebugLn('TGtk3WSCustomListView.ColumnSetAutoSize ');
  TGtk3ListView(ALV.Handle).SetColumnAutoSize(AIndex, AColumn, AAutoSize);
  // inherited ColumnSetAutoSize(ALV, AIndex, AColumn, AAutoSize);
end;

class procedure TGtk3WSCustomListView.ColumnSetCaption(
  const ALV: TCustomListView; const AIndex: Integer;
  const AColumn: TListColumn; const ACaption: String);
begin
  if not WSCheckHandleAllocated(ALV, 'ColumnSetCaption') then
    Exit;
  // DebugLn('TGtk3WSCustomListView.ColumnSetCaption ');
  // inherited ColumnSetCaption(ALV, AIndex, AColumn, ACaption);
  TGtk3ListView(ALV.Handle).SetColumnCaption(AIndex, AColumn, ACaption);
end;

class procedure TGtk3WSCustomListView.ColumnSetImage(
  const ALV: TCustomListView; const AIndex: Integer;
  const AColumn: TListColumn; const AImageIndex: Integer);
begin
  // DebugLn('TGtk3WSCustomListView.ColumnSetImage ');
  // inherited ColumnSetImage(ALV, AIndex, AColumn, AImageIndex);
end;

class procedure TGtk3WSCustomListView.ColumnSetMaxWidth(
  const ALV: TCustomListView; const AIndex: Integer;
  const AColumn: TListColumn; const AMaxWidth: Integer);
begin
  if not WSCheckHandleAllocated(ALV, 'ColumnSetMaxWidth') then
    Exit;
  // DebugLn('TGtk3WSCustomListView.ColumnSetMaxWidth ');
  TGtk3ListView(ALV.Handle).SetColumnMaxWidth(AIndex, AColumn, AMaxWidth);
  // inherited ColumnSetMaxWidth(ALV, AIndex, AColumn, AMaxWidth);
end;

class procedure TGtk3WSCustomListView.ColumnSetMinWidth(
  const ALV: TCustomListView; const AIndex: Integer;
  const AColumn: TListColumn; const AMinWidth: integer);
begin
  if not WSCheckHandleAllocated(ALV, 'ColumnSetMinWidth') then
    Exit;
  // DebugLn('TGtk3WSCustomListView.ColumnSetMinWidth ');
  TGtk3ListView(ALV.Handle).SetColumnMinWidth(AIndex, AColumn, AMinWidth);
  // inherited ColumnSetMinWidth(ALV, AIndex, AColumn, AMinWidth);
end;

class procedure TGtk3WSCustomListView.ColumnSetWidth(
  const ALV: TCustomListView; const AIndex: Integer;
  const AColumn: TListColumn; const AWidth: Integer);
begin
  if not WSCheckHandleAllocated(ALV, 'ColumnSetWidth') then
    Exit;
  // DebugLn('TGtk3WSCustomListView.ColumnSetWidth ');
  // inherited ColumnSetWidth(ALV, AIndex, AColumn, AWidth);
  TGtk3ListView(ALV.Handle).SetColumnWidth(AIndex, AColumn, AWidth);
end;

class procedure TGtk3WSCustomListView.ColumnSetVisible(
  const ALV: TCustomListView; const AIndex: Integer;
  const AColumn: TListColumn; const AVisible: Boolean);
begin
  if not WSCheckHandleAllocated(ALV, 'ColumnSetVisible') then
    Exit;
  // DebugLn('TGtk3WSCustomListView.ColumnSetVisible ');
  // inherited ColumnSetVisible(ALV, AIndex, AColumn, AVisible);
  TGtk3ListView(ALV.Handle).SetColumnVisible(AIndex, AColumn, AVisible);
end;

class procedure TGtk3WSCustomListView.ColumnSetSortIndicator(
  const ALV: TCustomListView; const AIndex: Integer;
  const AColumn: TListColumn; const ASortIndicator: TSortIndicator);
begin
  if not WSCheckHandleAllocated(ALV, 'ColumnSetSortIndicator') then
    Exit;

  TGtk3ListView(ALV.Handle).ColumnSetSortIndicator(AIndex,AColumn,ASortIndicator);
end;




type
  TListItemHack = class(TListItem)
  end;

class procedure TGtk3WSCustomListView.ItemDelete(const ALV: TCustomListView;
  const AIndex: Integer);
begin
  if not WSCheckHandleAllocated(ALV, 'ItemDelete') then
    Exit;
  TGtk3ListView(ALV.Handle).ItemDelete(AIndex);
  // DebugLn('TGtk3WSCustomListView.ItemDelete ');
  // inherited ItemDelete(ALV, AIndex);
end;

class function TGtk3WSCustomListView.ItemDisplayRect(
  const ALV: TCustomListView; const AIndex, ASubItem: Integer;
  ACode: TDisplayCode): TRect;
begin
  DebugLn('TGtk3WSCustomListView.ItemDisplayRect ');
  Result := Rect(0, 0, 0, 0);
end;

class procedure TGtk3WSCustomListView.ItemExchange(const ALV: TCustomListView;
  AItem: TListItem; const AIndex1, AIndex2: Integer);
begin
  DebugLn('TGtk3WSCustomListView.ItemExchange ');
  // inherited ItemExchange(ALV, AItem, AIndex1, AIndex2);
end;

class procedure TGtk3WSCustomListView.ItemMove(const ALV: TCustomListView;
  AItem: TListItem; const AFromIndex, AToIndex: Integer);
begin
  DebugLn('TGtk3WSCustomListView.ItemMove ');
  // inherited ItemMove(ALV, AItem, AFromIndex, AToIndex);
end;

class function TGtk3WSCustomListView.ItemGetChecked(const ALV: TCustomListView;
  const AIndex: Integer; const AItem: TListItem): Boolean;
begin
  if not WSCheckHandleAllocated(ALV, 'ItemGetChecked') then
    Exit;
  // DebugLn('TGtk3WSCustomListView.ItemGetChecked ');
  Result := TListItemHack(AItem).GetCheckedInternal;
end;

class function TGtk3WSCustomListView.ItemGetState(const ALV: TCustomListView;
  const AIndex: Integer; const AItem: TListItem; const AState: TListItemState;
  out AIsSet: Boolean): Boolean;
begin
  if not WSCheckHandleAllocated(ALV, 'ItemGetState') then
    Exit;
  // DebugLn('TGtk3WSCustomListView.ItemGetState ');
  Result := TGtk3ListView(ALV.Handle).ItemGetState(AIndex, AItem, AState, AIsSet);
end;

class procedure TGtk3WSCustomListView.ItemInsert(const ALV: TCustomListView;
  const AIndex: Integer; const AItem: TListItem);
begin
  if not WSCheckHandleAllocated(ALV, 'ItemInsert') then
    Exit;
  // DebugLn('TGtk3WSCustomListView.ItemInsert ');
  TGtk3ListView(ALV.Handle).ItemInsert(AIndex, AItem);
end;

class procedure TGtk3WSCustomListView.ItemSetChecked(
  const ALV: TCustomListView; const AIndex: Integer; const AItem: TListItem;
  const AChecked: Boolean);
begin
  if not WSCheckHandleAllocated(ALV, 'ItemSetChecked') then
    Exit;
  // not needed
  // DebugLn('TGtk3WSCustomListView.ItemSetChecked ');
  // inherited ItemSetChecked(ALV, AIndex, AItem, AChecked);
end;

class procedure TGtk3WSCustomListView.ItemSetImage(const ALV: TCustomListView;
  const AIndex: Integer; const AItem: TListItem; const ASubIndex,
  AImageIndex: Integer);
begin
  if not WSCheckHandleAllocated(ALV, 'ItemSetImage') then
    Exit;
  TGtk3ListView(ALV.Handle).BeginUpdate;
  TGtk3ListView(ALV.Handle).ItemSetImage(AIndex,ASubIndex, AItem);
  TGtk3ListView(ALV.Handle).EndUpdate;
end;

class procedure TGtk3WSCustomListView.ItemSetState(const ALV: TCustomListView;
  const AIndex: Integer; const AItem: TListItem; const AState: TListItemState;
  const AIsSet: Boolean);
begin
  if not WSCheckHandleAllocated(ALV, 'ItemSetState') then
    Exit;
   // DebugLn('TGtk3WSCustomListView.ItemSetState ');
  // inherited ItemSetState(ALV, AIndex, AItem, AState, AIsSet);
  TGtk3ListView(ALV.Handle).BeginUpdate;
  TGtk3ListView(ALV.Handle).ItemSetState(AIndex, AItem, AState, AIsSet);
  TGtk3ListView(ALV.Handle).EndUpdate;
end;

class procedure TGtk3WSCustomListView.ItemSetText(const ALV: TCustomListView;
  const AIndex: Integer; const AItem: TListItem; const ASubIndex: Integer;
  const AText: String);
begin
  if not WSCheckHandleAllocated(ALV, 'ItemSetText') then
    Exit;
  // DebugLn('TGtk3WSCustomListView.ItemSetText ');
  TGtk3ListView(ALV.Handle).ItemSetText(AIndex, ASubIndex, AItem, AText);
end;

class procedure TGtk3WSCustomListView.ItemShow(const ALV: TCustomListView;
  const AIndex: Integer; const AItem: TListItem; const PartialOK: Boolean);
begin
  DebugLn('TGtk3WSCustomListView.ItemShow ');
  // inherited ItemShow(ALV, AIndex, AItem, PartialOK);
end;

class function TGtk3WSCustomListView.ItemGetPosition(
  const ALV: TCustomListView; const AIndex: Integer): TPoint;
begin
  DebugLn('TGtk3WSCustomListView.ItemGetPosition ');
  Result := Point(0, 0); // inherited ItemGetPosition(ALV, AIndex);
end;

class procedure TGtk3WSCustomListView.ItemUpdate(const ALV: TCustomListView;
  const AIndex: Integer; const AItem: TListItem);
begin
  DebugLn('TGtk3WSCustomListView.ItemUpdate ');
  // inherited ItemUpdate(ALV, AIndex, AItem);
end;

class procedure TGtk3WSCustomListView.BeginUpdate(const ALV: TCustomListView);
begin
  // inherited BeginUpdate(ALV);
  DebugLn('TGtk3WSCustomListView.BeginUpdate ');
end;

class procedure TGtk3WSCustomListView.EndUpdate(const ALV: TCustomListView);
begin
  // inherited EndUpdate(ALV);
  DebugLn('TGtk3WSCustomListView.EndUpdate ');
end;

class function TGtk3WSCustomListView.GetBoundingRect(const ALV: TCustomListView
  ): TRect;
begin
  DebugLn('TGtk3WSCustomListView.GetBoundingRect ');
  Result := Rect(0, 0, 0, 0);
end;

class function TGtk3WSCustomListView.GetDropTarget(const ALV: TCustomListView
  ): Integer;
begin
  DebugLn('TGtk3WSCustomListView.GetDropTarget ');
  Result := -1;
end;

class function TGtk3WSCustomListView.GetFocused(const ALV: TCustomListView
  ): Integer;
begin
  DebugLn('TGtk3WSCustomListView.GetFocused ');
  Result := -1;
end;

class function TGtk3WSCustomListView.GetHoverTime(const ALV: TCustomListView
  ): Integer;
begin
  DebugLn('TGtk3WSCustomListView.GetHoverTime ');
  Result := 0;
end;

class function TGtk3WSCustomListView.GetItemAt(const ALV: TCustomListView; x,
  y: integer): Integer;
var
  ItemPath: PGtkTreePath;
  Column: PGtkTreeViewColumn;
  cx, cy: gint;
begin
  Result := -1;
  if not WSCheckHandleAllocated(ALV, 'GetItemAt') then
    Exit;
  if TGtk3ListView(ALV.Handle).IsTreeView then
  begin
    //PGtkTreeView(TGtk3ListView(ALV.Handle).GetContainerWidget)^.get_bin_window^.get_position(@cx, @cy);
    //Dec(x, cx);
    //Dec(y, cy);
    ItemPath := nil;
    Column := nil;
    if PGtkTreeView(TGtk3ListView(ALV.Handle).GetContainerWidget)^.get_path_at_pos(x, y, @ItemPath, @Column, nil, nil) then
    begin
      if ItemPath <> nil then
      begin
        Result := gtk_tree_path_get_indices(ItemPath)^;
        gtk_tree_path_free(ItemPath);
      end;
    end;
  end else
  begin
    ItemPath := PGtkIconView(TGtk3ListView(ALV.Handle).GetContainerWidget)^.get_path_at_pos(x, y);
    if ItemPath <> nil then
    begin
      Result := gtk_tree_path_get_indices(ItemPath)^;
      gtk_tree_path_free(ItemPath);
    end;
  end;
end;

class function TGtk3WSCustomListView.GetSelCount(const ALV: TCustomListView
  ): Integer;
begin
  DebugLn('TGtk3WSCustomListView.GetSelCount ');
  Result := 0;
end;

class function TGtk3WSCustomListView.GetSelection(const ALV: TCustomListView
  ): Integer;
begin
  DebugLn('TGtk3WSCustomListView.GetSelection ');
  Result := -1;
end;

class function TGtk3WSCustomListView.GetTopItem(const ALV: TCustomListView
  ): Integer;
begin
  DebugLn('TGtk3WSCustomListView.GetTopItem ');
  Result := 0;
end;

class function TGtk3WSCustomListView.GetViewOrigin(const ALV: TCustomListView
  ): TPoint;
begin
  DebugLn('TGtk3WSCustomListView.GetViewOrigin ');
  Result := Point(0, 0);
  // Result:=inherited GetViewOrigin(ALV);
end;

class function TGtk3WSCustomListView.GetVisibleRowCount(
  const ALV: TCustomListView): Integer;
begin
  DebugLn('TGtk3WSCustomListView.GetVisibleRowCount ');
  Result := 0;
  // Result:=inherited GetVisibleRowCount(ALV);
end;

class procedure TGtk3WSCustomListView.SetAllocBy(const ALV: TCustomListView;
  const AValue: Integer);
begin
  // DebugLn('TGtk3WSCustomListView.SetAllocBy ');
  // inherited SetAllocBy(ALV, AValue);
end;

class procedure TGtk3WSCustomListView.SetColor(const AWinControl: TWinControl);
begin
  DebugLn('TGtk3WSCustomListView.SetColor ');
  inherited SetColor(AWinControl);
end;

class procedure TGtk3WSCustomListView.SetDefaultItemHeight(
  const ALV: TCustomListView; const AValue: Integer);
begin
  if not WSCheckHandleAllocated(ALV, 'SetDefaultItemHeight') then
    Exit;
  // DebugLn('TGtk3WSCustomListView.SetDefaultItemHeight ',dbgs(AValue));
  if TGtk3ListView(ALV.Handle).IsTreeView then
    PGtkTreeView(TGtk3ListView(ALV.Handle).GetContainerWidget)^.set_fixed_height_mode(AValue > 0);
end;

class procedure TGtk3WSCustomListView.SetFont(const AWinControl: TWinControl;
  const AFont: TFont);
begin
  DebugLn('TGtk3WSCustomListView.SetFont ');
  inherited SetFont(AWinControl, AFont);
end;

class procedure TGtk3WSCustomListView.SetHotTrackStyles(
  const ALV: TCustomListView; const AValue: TListHotTrackStyles);
begin
  // DebugLn('TGtk3WSCustomListView.SetHotTrackStyles ');
  // inherited SetHotTrackStyles(ALV, AValue);
end;

class procedure TGtk3WSCustomListView.SetHoverTime(const ALV: TCustomListView;
  const AValue: Integer);
begin
  // DebugLn('TGtk3WSCustomListView.SetHoverTime ');
  // inherited SetHoverTime(ALV, AValue);
end;

class procedure TGtk3WSCustomListView.SetImageList(const ALV: TCustomListView;
  const AList: TListViewImageList; const AValue: TCustomImageListResolution);
var
  AView: TGtk3ListView;
  i: Integer;
  Bmp: TBitmap;
begin
  if not WSCheckHandleAllocated(ALV, 'SetImageList') then
    exit;
  DebugLn('TGtk3WSCustomListView.SetImageList ');
  AView := TGtk3ListView(ALV.Handle);
  // inherited SetImageList(ALV, AList, AValue);
  if ((AList = lvilLarge) and not AView.IsTreeView) or
     ((AList = lvilSmall) and AView.IsTreeView) then
  begin
    if Assigned(AView.Images) then
      AView.ClearImages
    else
      AView.Images := TFPList.Create;
    if Assigned(AValue) then
    begin
      for i := 0 to AValue.Count - 1 do
      begin
        Bmp := TBitmap.Create;
        AValue.GetBitmap(i, Bmp);
        AView.Images.Add(Bmp);
      end;
    end;

    if AView.IsTreeView then
      AView.UpdateImageCellsSize;

    AView.Update(nil);
  end;
end;

class procedure TGtk3WSCustomListView.SetItemsCount(const ALV: TCustomListView;
  const Avalue: Integer);
begin
  DebugLn('TGtk3WSCustomListView.SetItemsCount ');
  // inherited SetItemsCount(ALV, Avalue);
end;

class procedure TGtk3WSCustomListView.SetProperty(const ALV: TCustomListView;
  const AProp: TListViewProperty; const AIsSet: Boolean);
begin
  if not WSCheckHandleAllocated(ALV, 'SetProperty') then
    Exit;
  // DebugLn('TGtk3WSCustomListView.SetProperty ');
  SetPropertyInternal(ALV, AProp, AIsSet);
end;

class procedure TGtk3WSCustomListView.SetProperties(const ALV: TCustomListView;
  const AProps: TListViewProperties);
var
  Prop: TListViewProperty;
begin
  if not WSCheckHandleAllocated(ALV, 'SetProperties') then
    Exit;
  for Prop := Low(Prop) to High(Prop) do
    SetPropertyInternal(ALV, Prop, Prop in AProps);
end;

class procedure TGtk3WSCustomListView.SetScrollBars(const ALV: TCustomListView;
  const AValue: TScrollStyle);
var
  SS: TPoint;
begin
  if not WSCheckHandleAllocated(ALV, 'SetScrollBars') then
    Exit;
  // DebugLn('TGtk3WSCustomListView.SetScrollbars ');
  // inherited SetScrollBars(ALV, AValue);
  SS := Gtk3TranslateScrollStyle(AValue);
  TGtk3ListView(ALV.Handle).GetScrolledWindow^.set_policy(SS.X, SS.Y);
end;

class procedure TGtk3WSCustomListView.SetSort(const ALV: TCustomListView;
  const AType: TSortType; const AColumn: Integer;
  const ASortDirection: TSortDirection);
begin
  if not WSCheckHandleAllocated(ALV, 'SetSort') then
    Exit;
  if TGtk3ListView(ALV.Handle).GetContainerWidget^.get_realized then
    TGtk3ListView(ALV.Handle).GetContainerWidget^.queue_draw;
  // DebugLn('TGtk3WSCustomListView.SetSort ');
  // inherited SetSort(ALV, AType, AColumn, ASortDirection);
end;

class procedure TGtk3WSCustomListView.SetViewOrigin(const ALV: TCustomListView;
  const AValue: TPoint);
begin
  if not WSCheckHandleAllocated(ALV, 'SetViewOrigin') then
    Exit;
  if not TGtk3ListView(ALV.Handle).GetContainerWidget^.get_realized then
    exit;
  // DebugLn('TGtk3WSCustomListView.SetViewOrigin ');
  if TGtk3ListView(ALV.Handle).IsTreeView then
    PGtkTreeView(TGtk3ListView(ALV.Handle).GetContainerWidget)^.scroll_to_point(AValue.X, AValue.Y);
  // TODO: else
  //  PGtkIconView(TGtk3ListView(ALV.Handle).GetContainerWidget)^.scroll_to_path();
end;

class procedure TGtk3WSCustomListView.SetViewStyle(const ALV: TCustomListView;
  const AValue: TViewStyle);
begin
  if not WSCheckHandleAllocated(ALV, 'SetViewStyle') then
    Exit;
  DebugLn('TGtk3WSCustomListView.SetViewStyle ');
  // inherited SetViewStyle(ALV, AValue);
end;

{ TGtk3WSStatusBar }

class function TGtk3WSStatusBar.CreateHandle(const AWinControl: TWinControl;
  const AParams: TCreateParams): TLCLIntfHandle;
var
  AStatusBar: TGtk3StatusBar;
begin
  AStatusBar := TGtk3StatusBar.Create(AWinControl, AParams);
  Result := TLCLIntfHandle(AStatusBar);
end;

class procedure TGtk3WSStatusBar.PanelUpdate(const AStatusBar: TStatusBar;
  PanelIndex: integer);
begin
  // inherited PanelUpdate(AStatusBar, PanelIndex);
end;

class procedure TGtk3WSStatusBar.SetPanelText(const AStatusBar: TStatusBar;
  PanelIndex: integer);
begin
  // inherited SetPanelText(AStatusBar, PanelIndex);
end;

class procedure TGtk3WSStatusBar.Update(const AStatusBar: TStatusBar);
begin
  // inherited Update(AStatusBar);
end;

class procedure TGtk3WSStatusBar.GetPreferredSize(
  const AWinControl: TWinControl; var PreferredWidth, PreferredHeight: integer;
  WithThemeSpace: Boolean);
begin
  inherited GetPreferredSize(AWinControl, PreferredWidth, PreferredHeight,
    WithThemeSpace);
end;

class procedure TGtk3WSStatusBar.SetSizeGrip(const AStatusBar: TStatusBar;
  SizeGrip: Boolean);
begin
  // inherited SetSizeGrip(AStatusBar, SizeGrip);
end;

{ TGtk3WSCustomTabControl }

class function TGtk3WSCustomTabControl.CreateHandle(
  const AWinControl: TWinControl; const AParams: TCreateParams): TLCLIntfHandle;
begin
  if AWinControl is TTabControl then
    Result := TLCLIntfHandle(TGtk3CustomControl.Create(AWinControl, AParams))
  else
    Result := TLCLIntfHandle(TGtk3NoteBook.Create(AWinControl, AParams));
end;

(*
class function TGtk3WSCustomTabControl.GetDefaultClientRect(
  const AWinControl: TWinControl; const aLeft, aTop, aWidth, aHeight: integer;
  var aClientRect: TRect): boolean;
begin
  Result:=inherited GetDefaultClientRect(AWinControl, aLeft, aTop, aWidth,
    aHeight, aClientRect);
end;
*)

class procedure TGtk3WSCustomTabControl.AddPage(
  const ATabControl: TCustomTabControl; const AChild: TCustomPage;
  const AIndex: integer);
begin
  if not WSCheckHandleAllocated(ATabControl, 'AddPage') then
    Exit;
  // set LCL size
  AChild.SetBounds(AChild.Left, AChild.Top, ATabControl.ClientWidth, ATabControl.ClientHeight);

  if AChild.TabVisible then
    TGtk3Widget(AChild.Handle).Show;

  if ATabControl is TTabControl then
    exit;

  TGtk3Notebook(ATabControl.Handle).InsertPage(AChild, AIndex);
end;

class procedure TGtk3WSCustomTabControl.MovePage(
  const ATabControl: TCustomTabControl; const AChild: TCustomPage;
  const NewIndex: integer);
begin
  if not WSCheckHandleAllocated(ATabControl, 'MovePage') then
    Exit;
  if (ATabControl is TTabControl) then
    exit;
  TGtk3Notebook(ATabControl.Handle).MovePage(AChild, NewIndex);
end;

class procedure TGtk3WSCustomTabControl.RemovePage(
  const ATabControl: TCustomTabControl; const AIndex: integer);
begin
  if not WSCheckHandleAllocated(ATabControl, 'RemovePage') then
    Exit;
  if (ATabControl is TTabControl) then
    exit;
  TGtk3Notebook(ATabControl.Handle).RemovePage(AIndex);
end;

class function TGtk3WSCustomTabControl.GetCapabilities: TCTabControlCapabilities;
begin
  Result := [nbcShowCloseButtons, nbcMultiLine, nbcPageListPopup, nbcShowAddTabButton];
end;

class function TGtk3WSCustomTabControl.GetNotebookMinTabHeight(
  const AWinControl: TWinControl): integer;
begin
  Result := inherited GetNotebookMinTabHeight(AWinControl);
  // inherited GetNotebookMinTabHeight(AWinControl);
end;

class function TGtk3WSCustomTabControl.GetNotebookMinTabWidth(
  const AWinControl: TWinControl): integer;
begin
  Result := TWSCustomTabControl.GetNotebookMinTabWidth(AWinControl);
end;

class function TGtk3WSCustomTabControl.GetTabIndexAtPos(
  const ATabControl: TCustomTabControl; const AClientPos: TPoint): integer;
var
  NoteBookWidget: PGtkNotebook;
  TabWidget, PageWidget: PGtkWidget;
  i: integer;
  AList: PGList;
  Allocation: TGtkAllocation;
  ARect: TRect;
begin
  Result:=-1;
  if (ATabControl is TTabControl) then
    exit;
  NoteBookWidget := PGtkNotebook(TGtk3NoteBook(ATabControl.Handle).GetContainerWidget);
  if (NotebookWidget=nil) then exit;

  AList := NoteBookWidget^.get_children;
  try
    for i := 0 to g_list_length(AList) - 1 do
    begin
      PageWidget := NoteBookWidget^.get_nth_page(i);
      if (PageWidget<>nil) then
      begin
        TabWidget := NoteBookWidget^.get_tab_label(PageWidget);
        if TabWidget <> nil then
        begin
          gtk_widget_get_allocation(TabWidget, @Allocation);
          ARect := RectFromGdkRect(Allocation);
          if PtInRect(ARect, AClientPos) then
          begin
            Result := I;
            break;
          end;
        end;
      end;
    end;
  finally
    if AList <> nil then
      g_list_free(Alist);
  end;
end;

class function TGtk3WSCustomTabControl.GetTabRect(
  const ATabControl: TCustomTabControl; const AIndex: Integer): TRect;
var
  NoteBookWidget: PGtkNotebook;
  TabWidget, PageWidget: PGtkWidget;
  Count: guint;
  AList: PGList;
  Allocation: TGtkAllocation;
  X, Y: gint;
begin
  Result := inherited;
  if (ATabControl is TTabControl) then
    exit;
  Result := Rect(0, 0, 0, 0);

  NoteBookWidget := PGtkNotebook(TGtk3NoteBook(ATabControl.Handle).GetContainerWidget);
  if (NotebookWidget=nil) then exit;

  AList := NoteBookWidget^.get_children;
  try
    Count := g_list_length(AList);
    PageWidget := NoteBookWidget^.get_nth_page(AIndex);
    if (PageWidget<>nil) and (AIndex < Count) then
    begin
      TabWidget := NoteBookWidget^.get_tab_label(PageWidget);
      if TabWidget <> nil then
      begin
        gtk_widget_get_allocation(TabWidget, @Allocation);
        Result := RectFromGdkRect(Allocation);
        gtk_widget_get_allocation(NoteBookWidget, @Allocation);
        Y := Allocation.y;
        X := Allocation.x;
        if Y <= 0 then
          exit;
        case ATabControl.TabPosition of
          tpTop, tpBottom:
              OffsetRect(Result, 0, -Y);
          tpLeft, tpRight:
            OffsetRect(Result, -X, -Y);
        end;
      end;
    end;
  finally
    if AList <> nil then
      g_list_free(Alist);
  end;
end;

class procedure TGtk3WSCustomTabControl.SetPageIndex(
  const ATabControl: TCustomTabControl; const AIndex: integer);
begin
  if (ATabControl is TTabControl) then
    exit;
  if not WSCheckHandleAllocated(ATabControl, 'SetPageIndex') then
    Exit;
  TGtk3Notebook(ATabControl.Handle).BeginUpdate;
  TGtk3Notebook(ATabControl.Handle).SetPageIndex(AIndex);
  TGtk3Notebook(ATabControl.Handle).EndUpdate;
end;

class procedure TGtk3WSCustomTabControl.SetTabCaption(
  const ATabControl: TCustomTabControl; const AChild: TCustomPage;
  const AText: string);
begin
  if (ATabControl is TTabControl) then
    exit;
  if not WSCheckHandleAllocated(ATabControl, 'SetTabCaption') then
    Exit;
  TGtk3NoteBook(ATabControl.Handle).SetTabLabelText(AChild, AText);
end;

class procedure TGtk3WSCustomTabControl.SetTabPosition(
  const ATabControl: TCustomTabControl; const ATabPosition: TTabPosition);
begin
  if (ATabControl is TTabControl) then
    exit;
  if not WSCheckHandleAllocated(ATabControl, 'SetTabPosition') then
    Exit;
  TGtk3NoteBook(ATabControl.Handle).SetTabPosition(ATabPosition);
end;

class procedure TGtk3WSCustomTabControl.ShowTabs(
  const ATabControl: TCustomTabControl; AShowTabs: boolean);
begin
  if ATabControl is TTabControl then
    exit;
  if not WSCheckHandleAllocated(ATabControl, 'ShowTabs') then
    Exit;
  TGtk3NoteBook(ATabControl.Handle).SetShowTabs(AShowTabs);
end;

class procedure TGtk3WSCustomTabControl.UpdateProperties(
  const ATabControl: TCustomTabControl);
begin
  if ATabControl is TTabControl then
    exit;
  // inherited UpdateProperties(ATabControl);
  if not WSCheckHandleAllocated(ATabControl, 'ATabControl') then
    Exit;

  if (nboHidePageListPopup in ATabControl.Options) then
    PGtkNotebook(TGtk3NoteBook(ATabControl.Handle).GetContainerWidget)^.popup_disable
  else
    PGtkNotebook(TGtk3NoteBook(ATabControl.Handle).GetContainerWidget)^.popup_enable;
end;


{ TGtk3WSCustomPage }

class function TGtk3WSCustomPage.CreateHandle(const AWinControl: TWinControl;
  const AParams: TCreateParams): TLCLIntfHandle;
begin
  Result := TLCLIntfHandle(TGtk3Page.Create(AWinControl, AParams));
end;

class procedure TGtk3WSCustomPage.UpdateProperties(
  const ACustomPage: TCustomPage);
begin
  // inherited UpdateProperties(ACustomPage);
  DebugLn('TGtk3WSCustomPage.UpdateProperties missing implementation ');
end;

class procedure TGtk3WSCustomPage.SetBounds(const AWinControl: TWinControl;
  const ALeft, ATop, AWidth, AHeight: Integer);
begin
  // ignore lcl bounds
  // inherited SetBounds(AWinControl, ALeft, ATop, AWidth, AHeight);
end;

class procedure TGtk3WSCustomPage.SetFont(const AWinControl: TWinControl;
  const AFont: TFont);
begin
  inherited SetFont(AWinControl, AFont);
end;

class procedure TGtk3WSCustomPage.ShowHide(const AWinControl: TWinControl);
begin
  // DebugLn('TGtk3WSCustomPage.ShowHide ',AWinControl.Caption);
  inherited ShowHide(AWinControl);
end;

class function TGtk3WSCustomPage.GetDefaultClientRect(
  const AWinControl: TWinControl; const aLeft, aTop, aWidth, aHeight: integer;
  var aClientRect: TRect): boolean;
begin
  Result:=false;
  if AWinControl.Parent = nil then exit;
  if AWinControl.HandleAllocated and AWinControl.Parent.HandleAllocated and
    (TGtk3Widget(AWinControl.Handle).Widget^.parent <> nil) then
  begin

  end else
  begin
    Result := True;
    aClientRect := AWinControl.Parent.ClientRect;
    // DebugLn(['TGtk3WSCustomPage.GetDefaultClientRect ',DbgSName(AWinControl),' Parent=',DbgSName(AWinControl.Parent),' ParentBounds=',dbgs(AWinControl.Parent.BoundsRect),' ParentClient=',dbgs(AWinControl.Parent.ClientRect)]);
  end;
end;

end.

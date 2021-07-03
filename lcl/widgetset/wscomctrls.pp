{
 *****************************************************************************
 *                               WSComCtrls.pp                               * 
 *                               -------------                               * 
 *                                                                           *
 *                                                                           *
 *****************************************************************************

 *****************************************************************************
  This file is part of the Lazarus Component Library (LCL)

  See the file COPYING.modifiedLGPL.txt, included in this distribution,
  for details about the license.
 *****************************************************************************
}
unit WSComCtrls;

{$mode objfpc}{$H+}
{$I lcl_defines.inc}

interface
////////////////////////////////////////////////////
// I M P O R T A N T                                
////////////////////////////////////////////////////
// 1) Only class methods allowed
// 2) Class methods have to be published and virtual
// 3) To get as little as posible circles, the uses
//    clause should contain only those LCL units 
//    needed for registration. WSxxx units are OK
// 4) To improve speed, register only classes in the 
//    initialization section which actually 
//    implement something
// 5) To enable your XXX widgetset units, look at
//    the uses clause of the XXXintf.pp
////////////////////////////////////////////////////
uses
  Classes,
////////////////////////////////////////////////////
// To get as little as posible circles,
// uncomment only when needed for registration
////////////////////////////////////////////////////
  Graphics, ImgList, Controls, StdCtrls, ComCtrls,
////////////////////////////////////////////////////
  WSLCLClasses, WSControls, WSExtCtrls, WSToolwin, WSFactory;

type
  { TWSCustomPage }

  TWSCustomPageClass = class of TWSCustomPage;
  TWSCustomPage = class(TWSWinControl)
  published
    class procedure UpdateProperties(const ACustomPage: TCustomPage); virtual;
  end;

  { TWSCustomTabControl }

  TWSCustomTabControl = class(TWSWinControl)
  published
    class procedure AddPage(const ATabControl: TCustomTabControl; const AChild: TCustomPage; const AIndex: integer); virtual;
    class procedure MovePage(const ATabControl: TCustomTabControl; const AChild: TCustomPage; const NewIndex: integer); virtual;
    class procedure RemovePage(const ATabControl: TCustomTabControl; const AIndex: integer); virtual;

    class function GetNotebookMinTabHeight(const AWinControl: TWinControl): integer; virtual;
    class function GetNotebookMinTabWidth(const AWinControl: TWinControl): integer; virtual;
    class function GetTabIndexAtPos(const ATabControl: TCustomTabControl; const AClientPos: TPoint): integer; virtual;
    class function GetTabRect(const ATabControl: TCustomTabControl; const AIndex: Integer): TRect; virtual;
    class function GetCapabilities: TCTabControlCapabilities; virtual;
    class procedure SetTabSize(const ATabControl: TCustomTabControl; const ATabWidth, ATabHeight: integer); virtual;
    class procedure SetImageList(const ATabControl: TCustomTabControl; const AImageList: TCustomImageListResolution); virtual;
    class procedure SetPageIndex(const ATabControl: TCustomTabControl; const AIndex: integer); virtual;
    class procedure SetTabCaption(const ATabControl: TCustomTabControl; const AChild: TCustomPage; const AText: string); virtual;
    class procedure SetTabPosition(const ATabControl: TCustomTabControl; const ATabPosition: TTabPosition); virtual;
    class procedure ShowTabs(const ATabControl: TCustomTabControl; AShowTabs: boolean); virtual;
    class procedure UpdateProperties(const ATabControl: TCustomTabControl); virtual;
  end;
  TWSCustomTabControlClass = class of TWSCustomTabControl;

  { TWSStatusBar }

  TWSStatusBarClass = class of TWSStatusBar;
  TWSStatusBar = class(TWSWinControl)
  published
    class procedure PanelUpdate(const AStatusBar: TStatusBar; PanelIndex: integer); virtual;
    class procedure SetPanelText(const AStatusBar: TStatusBar; PanelIndex: integer); virtual;
    class procedure SetSizeGrip(const AStatusBar: TStatusBar; SizeGrip: Boolean); virtual;
    class procedure Update(const AStatusBar: TStatusBar); virtual;
    class function GetDefaultColor(const AControl: TControl; const ADefaultColorType: TDefaultColorType): TColor; override;
  end;

  { TWSTabSheet }

  TWSTabSheet = class(TWSCustomPage)
  published
    class function GetDefaultColor(const AControl: TControl;
      const ADefaultColorType: TDefaultColorType): TColor; override;
  end;

  { TWSPageControl }

  TWSPageControl = class(TWSCustomTabControl)
  published
  end;

  { TWSCustomListView }
  TWSListViewItemChange = (lvicText, lvicImage);
  TWSListViewItemChanges = set of TWSListViewItemChange;

  TWSCustomListView = class(TWSWinControl)
  published
    // Column
    class procedure ColumnDelete(const ALV: TCustomListView; const AIndex: Integer); virtual;
    class function  ColumnGetWidth(const ALV: TCustomListView; const AIndex: Integer; const AColumn: TListColumn): Integer; virtual;
    class procedure ColumnInsert(const ALV: TCustomListView; const AIndex: Integer; const AColumn: TListColumn); virtual;
    class procedure ColumnMove(const ALV: TCustomListView; const AOldIndex, ANewIndex: Integer; const AColumn: TListColumn); virtual;
    class procedure ColumnSetAlignment(const ALV: TCustomListView; const AIndex: Integer; const AColumn: TListColumn; const AAlignment: TAlignment); virtual;
    class procedure ColumnSetAutoSize(const ALV: TCustomListView; const AIndex: Integer; const AColumn: TListColumn; const AAutoSize: Boolean); virtual;
    class procedure ColumnSetCaption(const ALV: TCustomListView; const AIndex: Integer; const AColumn: TListColumn; const ACaption: String); virtual;
    class procedure ColumnSetImage(const ALV: TCustomListView; const AIndex: Integer; const AColumn: TListColumn; const AImageIndex: Integer); virtual;
    class procedure ColumnSetMaxWidth(const ALV: TCustomListView; const AIndex: Integer; const AColumn: TListColumn; const AMaxWidth: Integer); virtual;
    class procedure ColumnSetMinWidth(const ALV: TCustomListView; const AIndex: Integer; const AColumn: TListColumn; const AMinWidth: integer); virtual;
    class procedure ColumnSetWidth(const ALV: TCustomListView; const AIndex: Integer; const AColumn: TListColumn; const AWidth: Integer); virtual;
    class procedure ColumnSetVisible(const ALV: TCustomListView; const AIndex: Integer; const AColumn: TListColumn; const AVisible: Boolean); virtual;
    class procedure ColumnSetSortIndicator(const ALV: TCustomListView; const AIndex: Integer; const AColumn: TListColumn; const ASortIndicator: TSortIndicator); virtual;
              
    // Item          
    class procedure ItemDelete(const ALV: TCustomListView; const AIndex: Integer); virtual;
    class function  ItemDisplayRect(const ALV: TCustomListView; const AIndex, ASubItem: Integer; ACode: TDisplayCode): TRect; virtual;
    class procedure ItemExchange(const ALV: TCustomListView; AItem: TListItem; const AIndex1, AIndex2: Integer); virtual;
    class procedure ItemMove(const ALV: TCustomListView; AItem: TListItem; const AFromIndex, AToIndex: Integer); virtual;
    class function  ItemGetChecked(const ALV: TCustomListView; const AIndex: Integer; const AItem: TListItem): Boolean; virtual;
    class function  ItemGetPosition(const ALV: TCustomListView; const AIndex: Integer): TPoint; virtual;
    class function  ItemGetState(const ALV: TCustomListView; const AIndex: Integer; const AItem: TListItem; const AState: TListItemState; out AIsSet: Boolean): Boolean; virtual; // returns True if supported
    class function  ItemGetStates(const ALV: TCustomListView; const AIndex: Integer; out AStates: TListItemStates): Boolean; virtual; // returns True if supported
    class procedure ItemInsert(const ALV: TCustomListView; const AIndex: Integer; const AItem: TListItem); virtual;
    class procedure ItemSetChecked(const ALV: TCustomListView; const AIndex: Integer; const AItem: TListItem; const AChecked: Boolean); virtual;
    class procedure ItemSetImage(const ALV: TCustomListView; const AIndex: Integer; const AItem: TListItem; const ASubIndex, AImageIndex: Integer); virtual;
    class function ItemSetPosition(const ALV: TCustomListView; const AIndex: Integer; const ANewPosition: TPoint): Boolean; virtual;
    class procedure ItemSetStateImage(const ALV: TCustomListView; const AIndex: Integer; const AItem: TListItem; const ASubIndex, AStateImageIndex: Integer); virtual;
    class procedure ItemSetState(const ALV: TCustomListView; const AIndex: Integer; const AItem: TListItem; const AState: TListItemState; const AIsSet: Boolean); virtual;
    class procedure ItemSetText(const ALV: TCustomListView; const AIndex: Integer; const AItem: TListItem; const ASubIndex: Integer; const AText: String); virtual;
    class procedure ItemShow(const ALV: TCustomListView; const AIndex: Integer; const AItem: TListItem; const PartialOK: Boolean); virtual;
    class procedure ItemUpdate(const ALV: TCustomListView; const AIndex: Integer; const AItem: TListItem); virtual;
    
    // LV
    class procedure BeginUpdate(const ALV: TCustomListView); virtual;
    class procedure EndUpdate(const ALV: TCustomListView); virtual;

    class function GetBoundingRect(const ALV: TCustomListView): TRect; virtual;
    class function GetDropTarget(const ALV: TCustomListView): Integer; virtual;
    class function GetFocused(const ALV: TCustomListView): Integer; virtual;
    class function GetHitTestInfoAt( const ALV: TCustomListView; X, Y: Integer ) : THitTests; virtual;
    class function GetHoverTime(const ALV: TCustomListView): Integer; virtual;
    class function GetItemAt(const ALV: TCustomListView; x,y: integer): Integer; virtual;
    class function GetSelCount(const ALV: TCustomListView): Integer; virtual;
    class function GetSelection(const ALV: TCustomListView): Integer; virtual;
    class function GetTopItem(const ALV: TCustomListView): Integer; virtual;
    class function GetViewOrigin(const ALV: TCustomListView): TPoint; virtual;
    class function GetVisibleRowCount(const ALV: TCustomListView): Integer; virtual;
    class function GetNextItem(const ALV: TCustomListView; const StartItem: TListItem; const Direction: TSearchDirection; const States: TListItemStates): TListItem; virtual;

    class procedure SelectAll(const ALV: TCustomListView; const AIsSet: Boolean); virtual;
    class procedure SetAllocBy(const ALV: TCustomListView; const AValue: Integer); virtual;
    class procedure SetDefaultItemHeight(const ALV: TCustomListView; const AValue: Integer); virtual;
    class procedure SetHotTrackStyles(const ALV: TCustomListView; const AValue: TListHotTrackStyles); virtual;
    class procedure SetHoverTime(const ALV: TCustomListView; const AValue: Integer); virtual;
    class procedure SetIconArrangement(const ALV: TCustomListView; const AValue: TIconArrangement); virtual;
    class procedure SetImageList(const ALV: TCustomListView; const AList: TListViewImageList; const AValue: TCustomImageListResolution); virtual;
    class procedure SetItemsCount(const ALV: TCustomListView; const Avalue: Integer); virtual;
    class procedure SetOwnerData(const ALV: TCustomListView; const AValue: Boolean); virtual;
    class procedure SetProperty(const ALV: TCustomListView; const AProp: TListViewProperty; const AIsSet: Boolean); virtual;
    class procedure SetProperties(const ALV: TCustomListView; const AProps: TListViewProperties); virtual;
    class procedure SetScrollBars(const ALV: TCustomListView; const AValue: TScrollStyle); virtual;
    class procedure SetSort(const ALV: TCustomListView; const AType: TSortType; const AColumn: Integer;
      const ASortDirection: TSortDirection); virtual;
    class procedure SetViewOrigin(const ALV: TCustomListView; const AValue: TPoint); virtual;
    class procedure SetViewStyle(const ALV: TCustomListView; const Avalue: TViewStyle); virtual;
    // if returns true, then LCL will call SetItemChecked after calling SetSort
    // for every item previously checked. Only widgetsets that don't support native sort
    // AND/OR that don't support native checkboxes should have this method return true
    class function RestoreItemCheckedAfterSort(const ALV: TCustomListView): Boolean; virtual;
  end;

  TWSCustomListViewClass = class of TWSCustomListView;

  { TWSListView }                             

  TWSListView = class(TWSCustomListView)
  published
  end;

  { TWSProgressBar }

  TWSProgressBarClass = class of TWSProgressBar;
  TWSProgressBar = class(TWSWinControl)
  published
    class procedure ApplyChanges(const AProgressBar: TCustomProgressBar); virtual;
    class procedure SetPosition(const AProgressBar: TCustomProgressBar; const NewPosition: integer); virtual;
    class procedure SetStyle(const AProgressBar: TCustomProgressBar; const NewStyle: TProgressBarStyle); virtual;
  end;

  { TWSCustomUpDown }

  TWSCustomUpDown = class(TWSCustomControl)
  published
    class procedure SetIncrement(const AUpDown: TCustomUpDown; AValue: Double); virtual;
    class procedure SetMaxPosition(const AUpDown: TCustomUpDown; AValue: Double); virtual;
    class procedure SetMinPosition(const AUpDown: TCustomUpDown; AValue: Double); virtual;
    class procedure SetOrientation(const AUpDown: TCustomUpDown; AOrientation: TUDOrientation); virtual;
    class procedure SetPosition(const AUpDown: TCustomUpDown; AValue: Double); virtual;
    // class procedure SetRepeatInterval(const AUpDown: TWSCustomUpDown; ms: Integer); virtual;
    class procedure SetUseArrowKeys(const AUpDown: TCustomUpDown; AUseArrow: Boolean); virtual;
    class procedure SetWrap(const AUpDown: TCustomUpDown; ADoWrap: Boolean); virtual;
  end;
  TWSCustomUpDownClass = class of TWSCustomUpDown;

  { TWSUpDown }

  TWSUpDown = class(TWSCustomUpDown)
  published
  end;

  { TWSToolButton }

  TWSToolButton = class(TWSCustomControl)
  published
  end;

  { TWSToolBar }

  TWSToolbarClass = class of TWSToolbar;
  TWSToolBar = class(TWSToolWindow)
  published
{$ifdef OldToolbar}  
    class function  GetButtonCount(const AToolBar: TToolBar): integer; virtual;
    class procedure InsertToolButton(const AToolBar: TToolbar; const AControl: TControl); virtual;
    class procedure DeleteToolButton(const AToolBar: TToolbar; const AControl: TControl); virtual;
{$endif}    
  end;

  { TWSTrackBar }

  TWSTrackBar = class(TWSWinControl)
  published
    class procedure ApplyChanges(const ATrackBar: TCustomTrackBar); virtual;
    class function GetPosition(const ATrackBar: TCustomTrackBar): integer; virtual;
    class procedure SetOrientation(const ATrackBar: TCustomTrackBar; const AOrientation: TTrackBarOrientation); virtual;
    class procedure SetPosition(const ATrackBar: TCustomTrackBar; const NewPosition: integer); virtual;
    class procedure SetTick(const ATrackBar: TCustomTrackBar; const ATick: integer); virtual;
    class procedure SetTickStyle(const ATrackBar: TCustomTrackBar; const ATickStyle: TTickStyle); virtual;
  end;
  TWSTrackBarClass = class of TWSTrackBar;

  { TWSCustomTreeView }

  TWSCustomTreeView = class(TWSCustomControl)
  published
  end;

  { TWSTreeView }

  TWSTreeView = class(TWSCustomTreeView)
  published
  end;

  { WidgetSetRegistration }

  procedure RegisterStatusBar;
  procedure RegisterTabSheet;
  procedure RegisterPageControl;
  procedure RegisterCustomListView;
  procedure RegisterCustomProgressBar;
  procedure RegisterCustomUpDown;
  procedure RegisterCustomToolButton;
  procedure RegisterToolBar;
  procedure RegisterCustomTrackBar;
  procedure RegisterCustomTreeView;

implementation

uses
  LResources;

{ TWSCustomUpDown }

class procedure TWSCustomUpDown.SetUseArrowKeys(const AUpDown: TCustomUpDown;
  AUseArrow: Boolean);
begin

end;

class procedure TWSCustomUpDown.SetMinPosition(const AUpDown: TCustomUpDown;
  AValue: Double);
begin

end;

class procedure TWSCustomUpDown.SetMaxPosition(const AUpDown: TCustomUpDown;
  AValue: Double);
begin

end;

class procedure TWSCustomUpDown.SetPosition(const AUpDown: TCustomUpDown;
  AValue: Double);
begin

end;

class procedure TWSCustomUpDown.SetIncrement(const AUpDown: TCustomUpDown;
  AValue: Double);
begin

end;

class procedure TWSCustomUpDown.SetOrientation(const AUpDown: TCustomUpDown;
  AOrientation: TUDOrientation);
begin

end;

class procedure TWSCustomUpDown.SetWrap(const AUpDown: TCustomUpDown;
  ADoWrap: Boolean);
begin

end;

{ TWSTabSheet }

class function TWSTabSheet.GetDefaultColor(const AControl: TControl;
  const ADefaultColorType: TDefaultColorType): TColor;
begin
  Result:=DefBtnColors[ADefaultColorType];
end;

{ TWSCustomPage }

class procedure TWSCustomPage.UpdateProperties(const ACustomPage: TCustomPage);
begin
end;

{ TWSCustomTabControl }

{ -----------------------------------------------------------------------------
  Method: TWSCustomTabControl.AddPage
  Params: ATabControl - A notebook control
          AChild - Page to insert
          AIndex  - The position in the notebook to insert the page
  Returns: Nothing

  Adds a new page to a notebook
 ------------------------------------------------------------------------------}
class procedure TWSCustomTabControl.AddPage(const ATabControl: TCustomTabControl; const AChild: TCustomPage; const AIndex: integer);
begin
end;

{------------------------------------------------------------------------------
  Method: TWSCustomTabControl.MovePage
  Params: ATabControl - The notebook control
          AChild    - The page to move
          NewIndex  - The new index of the page
  Returns: Nothing

  Moves a page in a notebook control
 ------------------------------------------------------------------------------}
class procedure TWSCustomTabControl.MovePage(const ATabControl: TCustomTabControl;
  const AChild: TCustomPage; const NewIndex: integer);
begin
end;

{------------------------------------------------------------------------------
  Method: TWSCustomTabControl.RemovePage
  Params: ATabControl - The notebook control
          AIndex    - The index of the page to delete
  Returns: Nothing

  Removes a page from a notebook control
 ------------------------------------------------------------------------------}
class procedure TWSCustomTabControl.RemovePage(const ATabControl: TCustomTabControl; const AIndex: integer);
begin
end;

{-------------------------------------------------------------------------------
  function TWSCustomTabControl.GetNotebookMinTabHeight(
    const AWinControl: TWinControl): integer;

  Returns the minimum height of the horizontal tabs of a notebook. That is the
  Notebook with TabPosition in [tpTop,tpBottom] without the client panel.
-------------------------------------------------------------------------------}
class function  TWSCustomTabControl.GetNotebookMinTabHeight(
  const AWinControl: TWinControl): integer;
begin
  Result:=30;
end;

{-------------------------------------------------------------------------------
  function TWSCustomTabControl.GetNotebookMinTabWidth(
    const AWinControl: TWinControl): integer;

  Returns the minimum width of the vertical tabs of a notebook. That is the
  Notebook with TabPosition in [tpLeft,tpRight] without the client panel.
-------------------------------------------------------------------------------}
class function TWSCustomTabControl.GetNotebookMinTabWidth(const AWinControl: TWinControl
  ): integer;
begin
  Result:=60;
end;

class function TWSCustomTabControl.GetTabIndexAtPos(const ATabControl: TCustomTabControl;
  const AClientPos: TPoint): integer;
begin
  Result := -1;
end;

class function TWSCustomTabControl.GetTabRect(const ATabControl: TCustomTabControl;
  const AIndex: Integer): TRect;
begin
  Result := Rect(-1,-1,-1,-1);
end;

class function TWSCustomTabControl.GetCapabilities: TCTabControlCapabilities;
begin
  Result:=[];
end;

class procedure TWSCustomTabControl.SetTabSize(
  const ATabControl: TCustomTabControl; const ATabWidth, ATabHeight: integer);
begin
end;

class procedure TWSCustomTabControl.SetImageList(
  const ATabControl: TCustomTabControl; const AImageList: TCustomImageListResolution);
begin
end;

class procedure TWSCustomTabControl.SetPageIndex(const ATabControl: TCustomTabControl;
  const AIndex: integer);
begin
end;

class procedure TWSCustomTabControl.SetTabCaption(const ATabControl: TCustomTabControl;
  const AChild: TCustomPage; const AText: string);
begin
end;

class procedure TWSCustomTabControl.SetTabPosition(const ATabControl: TCustomTabControl;
  const ATabPosition: TTabPosition);
begin
end;

class procedure TWSCustomTabControl.ShowTabs(const ATabControl: TCustomTabControl;
  AShowTabs: boolean);
begin
end;

class procedure TWSCustomTabControl.UpdateProperties(
  const ATabControl: TCustomTabControl);
begin

end;

{ TWSStatusBar }

class procedure TWSStatusBar.PanelUpdate(const AStatusBar: TStatusBar; PanelIndex: integer);
begin
end;

class procedure TWSStatusBar.SetPanelText(const AStatusBar: TStatusBar; PanelIndex: integer);
begin
end;

class procedure TWSStatusBar.SetSizeGrip(const AStatusBar: TStatusBar;
  SizeGrip: Boolean);
begin
end;

class procedure TWSStatusBar.Update(const AStatusBar: TStatusBar);
begin
end;

class function TWSStatusBar.GetDefaultColor(const AControl: TControl; const ADefaultColorType: TDefaultColorType): TColor;
begin
  Result := DefBtnColors[ADefaultColorType];
end;
    
{ TWSCustomListView }

class procedure TWSCustomListView.ColumnDelete(const ALV: TCustomListView;
  const AIndex: Integer);
begin
end;

class function TWSCustomListView.ColumnGetWidth(const ALV: TCustomListView;
  const AIndex: Integer; const AColumn: TListColumn): Integer;
begin
  Result := -1;
end;

class procedure TWSCustomListView.ColumnInsert(const ALV: TCustomListView;
  const AIndex: Integer; const AColumn: TListColumn);
begin
end;

class procedure TWSCustomListView.ColumnMove(const ALV: TCustomListView;
  const AOldIndex, ANewIndex: Integer; const AColumn: TListColumn);
begin
end;

class procedure TWSCustomListView.ColumnSetAlignment(const ALV: TCustomListView;
  const AIndex: Integer; const AColumn: TListColumn;
  const AAlignment: TAlignment);
begin
end;

class procedure TWSCustomListView.ColumnSetAutoSize(const ALV: TCustomListView;
  const AIndex: Integer; const AColumn: TListColumn; const AAutoSize: Boolean);
begin
end;

class procedure TWSCustomListView.ColumnSetCaption(const ALV: TCustomListView;
  const AIndex: Integer; const AColumn: TListColumn; const ACaption: String);
begin
end;

class procedure TWSCustomListView.ColumnSetImage(const ALV: TCustomListView;
  const AIndex: Integer; const AColumn: TListColumn; const AImageIndex: Integer);
begin
end;

class procedure TWSCustomListView.ColumnSetMaxWidth(const ALV: TCustomListView;
  const AIndex: Integer; const AColumn: TListColumn; const AMaxWidth: Integer);
begin
end;

class procedure TWSCustomListView.ColumnSetMinWidth(const ALV: TCustomListView;
  const AIndex: Integer; const AColumn: TListColumn; const AMinWidth: integer);
begin
end;

class procedure TWSCustomListView.ColumnSetWidth(const ALV: TCustomListView;
  const AIndex: Integer; const AColumn: TListColumn; const AWidth: Integer);
begin
end;

class procedure TWSCustomListView.ColumnSetVisible(const ALV: TCustomListView;
  const AIndex: Integer; const AColumn: TListColumn; const AVisible: Boolean);
begin
end;

class procedure TWSCustomListView.ColumnSetSortIndicator(
  const ALV: TCustomListView; const AIndex: Integer;
  const AColumn: TListColumn; const ASortIndicator: TSortIndicator);
begin

end;

class procedure TWSCustomListView.ItemDelete(const ALV: TCustomListView;
  const AIndex: Integer);
begin
end;

class function TWSCustomListView.ItemDisplayRect(const ALV: TCustomListView; const AIndex, ASubItem: Integer; ACode: TDisplayCode): TRect;
begin
  Result := Rect(0,0,0,0);
end;

class procedure TWSCustomListView.ItemExchange(const ALV: TCustomListView;
  AItem: TListItem; const AIndex1, AIndex2: Integer);
begin
end;

class procedure TWSCustomListView.ItemMove(const ALV: TCustomListView;
  AItem: TListItem; const AFromIndex, AToIndex: Integer);
begin
end;

class function TWSCustomListView.ItemGetChecked(const ALV: TCustomListView; const AIndex: Integer; const AItem: TListItem): Boolean;
begin
  Result := False;
end;

class function TWSCustomListView.ItemGetPosition(const ALV: TCustomListView;
  const AIndex: Integer): TPoint;
begin
  Result := Point(0, 0);
end;

class function TWSCustomListView.ItemGetState(const ALV: TCustomListView;
  const AIndex: Integer; const AItem: TListItem; const AState: TListItemState;
  out AIsSet: Boolean): Boolean;
begin
  // returns True if supported
  Result := False;
  AIsSet:=false;
end;

class function TWSCustomListView.ItemGetStates(const ALV: TCustomListView; const AIndex: Integer; out AStates: TListItemStates): Boolean;
begin
  // returns True if supported
  Result := False;
end;

class procedure TWSCustomListView.ItemInsert(const ALV: TCustomListView;
  const AIndex: Integer; const AItem: TListItem);
begin
end;

class procedure TWSCustomListView.ItemSetChecked(const ALV: TCustomListView; const AIndex: Integer; const AItem: TListItem; const AChecked: Boolean);
begin
end;

class procedure TWSCustomListView.ItemSetImage(const ALV: TCustomListView;
  const AIndex: Integer; const AItem: TListItem;
  const ASubIndex, AImageIndex: Integer);
begin
end;

class function TWSCustomListView.ItemSetPosition(const ALV: TCustomListView;
  const AIndex: Integer; const ANewPosition: TPoint): Boolean;
begin
  Result := False;
end;

class procedure TWSCustomListView.ItemSetStateImage(const ALV: TCustomListView;
  const AIndex: Integer; const AItem: TListItem;
  const ASubIndex, AStateImageIndex: Integer);
begin
end;

class procedure TWSCustomListView.ItemSetState(const ALV: TCustomListView;
  const AIndex: Integer; const AItem: TListItem; const AState: TListItemState;
  const AIsSet: Boolean);
begin
end;

class procedure TWSCustomListView.ItemSetText(const ALV: TCustomListView;
  const AIndex: Integer; const AItem: TListItem; const ASubIndex: Integer;
  const AText: String);
begin
end;

class procedure TWSCustomListView.ItemShow(const ALV: TCustomListView;
  const AIndex: Integer; const AItem: TListItem; const PartialOK: Boolean);
begin
end;

class procedure TWSCustomListView.ItemUpdate(const ALV: TCustomListView;
  const AIndex: Integer; const AItem: TListItem);
begin
end;

class procedure TWSCustomListView.BeginUpdate(const ALV: TCustomListView);
begin
end;

class procedure TWSCustomListView.EndUpdate(const ALV: TCustomListView);
begin
end;

class function TWSCustomListView.GetBoundingRect(const ALV: TCustomListView): TRect;
begin
  Result := Rect(0,0,0,0);
end;

class function TWSCustomListView.GetDropTarget(const ALV: TCustomListView): Integer;
begin       
  Result := -1;
end;

class function TWSCustomListView.GetFocused(const ALV: TCustomListView): Integer;
begin
  Result := -1;
end;

class function TWSCustomListView.GetHitTestInfoAt( const ALV: TCustomListView; X, Y: Integer ) : THitTests;
begin
  Result := [];
end;

class function TWSCustomListView.GetHoverTime(const ALV: TCustomListView): Integer;
begin
  Result := -1;
end;

class function TWSCustomListView.GetItemAt(const ALV: TCustomListView; x,y: integer): Integer;
begin
  result:=-1;
end;

class function TWSCustomListView.GetSelCount(const ALV: TCustomListView): Integer;
begin
  Result := 0;
end;

class function TWSCustomListView.GetSelection(const ALV: TCustomListView): Integer;
begin
  Result := -1;
end;

class function TWSCustomListView.GetTopItem(const ALV: TCustomListView): Integer;
begin
  Result := -1;
end;

class function TWSCustomListView.GetViewOrigin(const ALV: TCustomListView): TPoint;
begin
  Result := Point(0, 0);
end;

class function TWSCustomListView.GetVisibleRowCount(const ALV: TCustomListView): Integer;
begin
  Result := 0;
end;

class procedure TWSCustomListView.SetAllocBy(const ALV: TCustomListView; const AValue: Integer);
begin
end;

class procedure TWSCustomListView.SetDefaultItemHeight(const ALV: TCustomListView; const AValue: Integer);
begin
end;

class procedure TWSCustomListView.SetHotTrackStyles(const ALV: TCustomListView; const AValue: TListHotTrackStyles);
begin
end;

class procedure TWSCustomListView.SetHoverTime(const ALV: TCustomListView; const AValue: Integer);
begin
end;

class procedure TWSCustomListView.SetIconArrangement(
  const ALV: TCustomListView; const AValue: TIconArrangement);
begin
end;

class procedure TWSCustomListView.SetImageList(const ALV: TCustomListView;
  const AList: TListViewImageList; const AValue: TCustomImageListResolution);
begin
end;

class procedure TWSCustomListView.SetOwnerData(const ALV: TCustomListView;
  const AValue: Boolean);
begin
end;

class procedure TWSCustomListView.SetProperty(const ALV: TCustomListView; const AProp: TListViewProperty; const AIsSet: Boolean);
begin
end;

// Default implementation based on SetProperty
class procedure TWSCustomListView.SetProperties(const ALV: TCustomListView; const AProps: TListViewProperties);
begin
  SetProperty(ALV, lvpAutoArrange, lvpAutoArrange in AProps);
  SetProperty(ALV, lvpCheckboxes, lvpCheckboxes in AProps);
  SetProperty(ALV, lvpColumnClick, lvpColumnClick in AProps);
  SetProperty(ALV, lvpFlatScrollBars, lvpFlatScrollBars in AProps);
  SetProperty(ALV, lvpFullDrag, lvpFullDrag in AProps);
  SetProperty(ALV, lvpGridLines, lvpGridLines in AProps);
  SetProperty(ALV, lvpHideSelection, lvpHideSelection in AProps);
  SetProperty(ALV, lvpHotTrack, lvpHotTrack in AProps);
  SetProperty(ALV, lvpMultiSelect, lvpMultiSelect in AProps);
  SetProperty(ALV, lvpOwnerDraw, lvpOwnerDraw in AProps);
  SetProperty(ALV, lvpReadOnly, lvpReadOnly in AProps);
  SetProperty(ALV, lvpRowSelect, lvpRowSelect in AProps);
  SetProperty(ALV, lvpShowColumnHeaders, lvpShowColumnHeaders in AProps);
  SetProperty(ALV, lvpShowWorkAreas, lvpShowWorkAreas in AProps);
  SetProperty(ALV, lvpWrapText, lvpWrapText in AProps);
  SetProperty(ALV, lvpToolTips, lvpToolTips in AProps);
end;

class procedure TWSCustomListView.SetScrollBars(const ALV: TCustomListView; const AValue: TScrollStyle);
begin
end;

class procedure TWSCustomListView.SetSort(const ALV: TCustomListView;
  const AType: TSortType; const AColumn: Integer;
  const ASortDirection: TSortDirection);
begin
end;

class procedure TWSCustomListView.SetViewOrigin(const ALV: TCustomListView; const AValue: TPoint);
begin
end;

class procedure TWSCustomListView.SetViewStyle(const ALV: TCustomListView; const Avalue: TViewStyle);
begin
end;

class function TWSCustomListView.RestoreItemCheckedAfterSort(const ALV: TCustomListView
  ): Boolean;
begin
  Result := false;
end;

class procedure TWSCustomListView.SetItemsCount(const ALV: TCustomListView; const Avalue: Integer); 
begin
end;

class procedure TWSCustomListView.SelectAll(const ALV: TCustomListView;
  const AIsSet: Boolean);
begin

end;

//Default implementation
class function TWSCustomListView.GetNextItem(const ALV: TCustomListView;
  const StartItem: TListItem; const Direction: TSearchDirection; const States: TListItemStates): TListItem;
var
  ACount: Integer;
  StartIndex, AIndex: Integer;
begin
  Result := nil;
  if StartItem = nil then
    Exit;
  StartIndex := StartItem.Index;
  AIndex := StartIndex;
  ACount := ALV.Items.Count;
  case Direction of
    sdAbove:
      while AIndex>0 do
      begin
        dec(AIndex);
        if States <= ALV.Items[AIndex].GetStates then
          Exit(ALV.Items[AIndex]);
      end;
    sdBelow:
      while AIndex < ACount-1 do
      begin
        inc(AIndex);
        if States <= ALV.Items[AIndex].GetStates then
          Exit(ALV.Items[AIndex]);
      end;
    sdAll:
      while True do
      begin
        inc(AIndex);
        Assert(AIndex <> StartIndex, 'TWSCustomListView.GetNextItem: AIndex=StartIndex');
        if AIndex >= ACount then
          Exit;
{       begin           Do not wrap around. Will never return Nil. Issue #38565.
          AIndex := -1;  continue;
        end;  }
        if States <= ALV.Items[AIndex].GetStates then
          Exit(ALV.Items[AIndex]);
      end;
  end;
end;

{ TWSProgressBar }

class procedure TWSProgressBar.ApplyChanges(const AProgressBar: TCustomProgressBar);
begin
end;

class procedure TWSProgressBar.SetPosition(const AProgressBar: TCustomProgressBar;
  const NewPosition: integer);
begin
end;

class procedure TWSProgressBar.SetStyle(const AProgressBar: TCustomProgressBar;
  const NewStyle: TProgressBarStyle);
begin
end;

{ TWSToolbar }

{$ifdef OldToolbar}

class function TWSToolbar.GetButtonCount(const AToolBar: TToolBar): integer;
begin
  Result := 0;
end;

class procedure TWSToolbar.InsertToolButton(const AToolBar: TToolbar; const AControl: TControl);
begin
end;

class procedure TWSToolbar.DeleteToolButton(const AToolBar: TToolbar; const AControl: TControl);
begin
end;

{$endif}

{ TWSTrackBar }

class procedure TWSTrackBar.ApplyChanges(const ATrackBar: TCustomTrackBar);
begin
end;

class function  TWSTrackBar.GetPosition(const ATrackBar: TCustomTrackBar): integer;
begin
  Result := 0;
end;

class procedure TWSTrackBar.SetOrientation(const ATrackBar: TCustomTrackBar;
  const AOrientation: TTrackBarOrientation);
begin
  RecreateWnd(ATrackBar);
end;

class procedure TWSTrackBar.SetPosition(const ATrackBar: TCustomTrackBar; const NewPosition: integer);
begin
end;

class procedure TWSTrackBar.SetTick(const ATrackBar: TCustomTrackBar; const ATick: integer);
begin
end;

class procedure TWSTrackBar.SetTickStyle(const ATrackBar: TCustomTrackBar; const ATickStyle: TTickStyle);
begin
  RecreateWnd(ATrackBar);
end;

{ WidgetSetRegistration }

procedure RegisterStatusBar;
const
  Done: Boolean = False;
begin
  if Done then exit;
  WSRegisterStatusBar;
  RegisterPropertyToSkip(TStatusBar, 'Font', 'VCL compatibility property', '');
  RegisterPropertyToSkip(TStatusBar, 'TabOrder', 'VCL compatibility property', '');
  RegisterPropertyToSkip(TStatusBar, 'TabStop', 'VCL compatibility property', '');
  RegisterPropertyToSkip(TStatusBar, 'UseSystemFont', 'VCL compatibility property', '');
//  if not WSRegisterStatusBar then
//    RegisterWSComponent(TStatusBar, TWSStatusBar);
  Done := True;
end;

procedure RegisterTabSheet;
const
  Done: Boolean = False;
begin
  if Done then exit;
  WSRegisterTabSheet;
//  if not WSRegisterTabSheet then
//    RegisterWSComponent(TTabSheet, TWSTabSheet)
  Done := True;
end;

procedure RegisterPageControl;
const
  Done: Boolean = False;
begin
  if Done then exit;
  WSRegisterPageControl;
  RegisterPropertyToSkip(TPageControl, 'OnPageChanged', 'Was removed in Laz 0.9.31 due to incompatibilities with OnChange, which does the same thing.', '');
//  if not WSRegisterPageControl then
//    RegisterWSComponent(TPageControl, TWSPageControl);
  Done := True;
end;

procedure RegisterCustomListView;
const
  Done: Boolean = False;
begin
  if Done then exit;
  WSRegisterCustomListView;
  RegisterPropertyToSkip(TListColumn, 'WidthType', 'VCL compatibility property', '');
//  if not WSRegisterCustomListView then
//    RegisterWSComponent(TCustomListView, TWSCustomListView);
  Done := True;
end;

procedure RegisterCustomProgressBar;
const
  Done: Boolean = False;
begin
  if Done then exit;
  WSRegisterCustomProgressBar;
//  if not WSRegisterCustomProgressBar then
//    RegisterWSComponent(TCustomProgressBar, TWSCustomProgressBar);
  Done := True;
end;

procedure RegisterCustomUpDown;
const
  Done: Boolean = False;
begin
  if Done then exit;
  WSRegisterCustomUpDown;
//  if not WSRegisterCustomUpDown then
//    RegisterWSComponent(TCustomUpDown, TWSCustomUpDown);
  Done := True;
end;

procedure RegisterCustomToolButton;
const
  Done: Boolean = False;
begin
  if Done then exit;
  WSRegisterCustomToolButton;
//  if not WSRegisterCustomToolButton then
//    RegisterWSComponent(TCustomToolButton, TWSToolButton);
  Done := True;
end;

procedure RegisterToolBar;
const
  Done: Boolean = False;
begin
  if Done then exit;
  WSRegisterToolBar;
//  if not WSRegisterToolBar then
//    RegisterWSComponent(TToolBar, TWSToolBar);
  Done := True;
end;

procedure RegisterCustomTrackBar;
const
  Done: Boolean = False;
begin
  if Done then exit;
  WSRegisterCustomTrackBar;
  RegisterPropertyToSkip(TCustomTrackBar, 'ThumbLength', 'VCL compatibility property', '');
//  if not WSRegisterCustomTrackBar then
//    RegisterWSComponent(TCustomTrackBar, TWSCustomTrackBar);
  Done := True;
end;

procedure RegisterCustomTreeView;
const
  Done: Boolean = False;
begin
  if Done then exit;
  WSRegisterCustomTreeView;
  RegisterPropertyToSkip(TCustomTreeView, 'BevelInner', 'VCL compatibility property', '');
  RegisterPropertyToSkip(TCustomTreeView, 'MultiSelect', 'VCL compatibility property', '');
//  if not WSRegisterStatusBar then
//    RegisterWSComponent(TCustomTreeView, TWSCustomTreeView);
  Done := True;
end;

end.

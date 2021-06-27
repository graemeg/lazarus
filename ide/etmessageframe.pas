{
 ***************************************************************************
 *                                                                         *
 *   This source is free software; you can redistribute it and/or modify   *
 *   it under the terms of the GNU General Public License as published by  *
 *   the Free Software Foundation; either version 2 of the License, or     *
 *   (at your option) any later version.                                   *
 *                                                                         *
 *   This code is distributed in the hope that it will be useful, but      *
 *   WITHOUT ANY WARRANTY; without even the implied warranty of            *
 *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU     *
 *   General Public License for more details.                              *
 *                                                                         *
 *   A copy of the GNU General Public License is available on the World    *
 *   Wide Web at <http://www.gnu.org/copyleft/gpl.html>. You can also      *
 *   obtain it by writing to the Free Software Foundation,                 *
 *   Inc., 51 Franklin Street - Fifth Floor, Boston, MA 02110-1335, USA.   *
 *                                                                         *
 ***************************************************************************

  Author: Mattias Gaertner

  Abstract:
    Frame for messages - output lines for (compiler) messages.
}
unit etMessageFrame;

{$mode objfpc}{$H+}

{$I ide.inc}

interface

uses
  Math, StrUtils, Classes, SysUtils, Laz_AVL_Tree,
  // LCL
  Forms, Buttons, ExtCtrls, Controls, LMessages, LCLType, LCLIntf,
  Graphics, Themes, ImgList, Menus, Clipbrd, Dialogs, StdCtrls,
  // LazUtils
  GraphType, UTF8Process, LazUTF8, LazFileCache, LazFileUtils, IntegerList, LazLoggerBase,
  // SynEdit
  SynEdit, SynEditMarks,
  // BuildIntf
  ProjectIntf, PackageIntf, CompOptsIntf, IDEExternToolIntf,
  // IDEIntf
  IDEImagesIntf, MenuIntf, IDECommands, IDEDialogs, LazIDEIntf,
  // IDE
  LazarusIDEStrConsts, EnvironmentOpts, HelpFPCMessages, etSrcEditMarks,
  MsgWnd_Options, etQuickFixes, ExtTools, IDEOptionDefs, CompilerOptions;

const
  CustomViewCaption = '------------------------------';

type
  TMessagesCtrl = class;

  { TLMsgWndView }

  TLMsgWndView = class(TLazExtToolView)
  private
    FAsyncQueued: boolean;
    FControl: TMessagesCtrl;
    FFilter: TLMsgViewFilter;
    fPaintBottom: integer; // only valid if FPaintStamp=Control.FPaintStamp
    FPaintStamp: int64;
    fPaintTop: integer; // only valid if FPaintStamp=Control.FPaintStamp
    FPendingChanges: TETMultiSrcChanges;
    procedure SetFilter(AValue: TLMsgViewFilter);
    procedure OnMarksFixed(ListOfTMessageLine: TFPList); // (main thread) called after mlfFixed was added to these messages
    procedure CallOnChangedInMainThread({%H-}Data: PtrInt); // (main thread)
  protected
    procedure SetToolState(AValue: TLMVToolState); override;
    procedure FetchAllPending; override; // (main thread)
    procedure ToolExited; override; // (main thread)
    procedure QueueAsyncOnChanged; override; // (worker thread)
    procedure RemoveAsyncOnChanged; override; // (worker thread)
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    function LineFits(Line: TMessageLine): boolean; override; // (worker thread)
    property Control: TMessagesCtrl read FControl;
    function HasContent: boolean;
    function GetShownLineCount(WithHeader, WithProgressLine: boolean): integer;
    procedure RebuildLines; // (main thread)
    function ApplySrcChanges(Changes: TETSingleSrcChanges): boolean; // true if something changed
  public
    // requires Enter/LeaveCriticalSection, write only via main thread
    property Filter: TLMsgViewFilter read FFilter write SetFilter;
    property PendingChanges: TETMultiSrcChanges read FPendingChanges;// src changes for messages adding to view
  end;

  { TMsgCtrlUrgencyStyle }

  TMsgCtrlUrgencyStyle = class
  private
    FColor: TColor;
    FControl: TMessagesCtrl;
    FImageIndex: integer;
    FTranslated: string;
    FUrgency: TMessageLineUrgency;
    procedure SetColor(AValue: TColor);
    procedure SetImageIndex(AValue: integer);
    procedure SetTranslated(AValue: string);
    procedure Changed;
  public
    constructor Create(AControl: TMessagesCtrl; TheUrgency: TMessageLineUrgency);
    function Equals(Obj: TObject): boolean; override;
    procedure Assign(Src: TMsgCtrlUrgencyStyle);
    procedure SetValues(TheTranslated: string; TheImageIndex: integer = -1; TheColor: TColor = clDefault);
    property Control: TMessagesCtrl read FControl;
    property Urgency: TMessageLineUrgency read FUrgency;
    property Translated: string read FTranslated write SetTranslated;
    property ImageIndex: integer read FImageIndex write SetImageIndex default -1;
    property Color: TColor read FColor write SetColor default clDefault;
  end;

type
  TOnOpenMessageLine = function(Sender: TObject; Msg: TMessageLine): boolean of object;

  TMsgCtrlState = (
    mcsFocused
    );
  TMsgCtrlStates = set of TMsgCtrlState;

  TMsgCtrlOption = (
    mcoSingleClickOpensFile, // otherwise double click
    mcoShowStats, // show numbers of errors, warnings and hints in view header line
    mcoShowTranslated, // show translation (e.g. messages from German message file)
    mcoShowMessageID,  // show message ID
    mcoShowMsgIcons,
    mcoAutoOpenFirstError, // when all views stopped, open first error
    mcoSrcEditPopupSelect, // when user right clicks on gutter mark,
                           // scroll and select message of the quickfixes
    mcoWndStayOnTop,       // use fsStayOnTop
    mcoAlwaysDrawFocused   // draw selected item as focused, even if the window is not
    );
  TMsgCtrlOptions = set of TMsgCtrlOption;
const
  MCDefaultOptions = [mcoShowStats,mcoShowTranslated,
                      mcoAutoOpenFirstError,mcoShowMsgIcons,
                      mcoSrcEditPopupSelect];

type

  { TMessagesCtrl }

  TMessagesCtrl = class(TCustomControl)
  private
    FActiveFilter: TLMsgViewFilter;
    FBackgroundColor: TColor;
    FFilenameStyle: TMsgWndFileNameStyle;
    FHeaderBackground: array[TLMVToolState] of TColor;
    FIdleConnected: boolean;
    FImageChangeLink: TChangeLink;
    FImages: TCustomImageList;
    FItemHeight: integer;
    FOnAllViewsStopped: TNotifyEvent;
    FOnOpenMessage: TOnOpenMessageLine;
    FOnOptionsChanged: TNotifyEvent;
    FOptions: TMsgCtrlOptions;
    FScrollLeft: integer;
    FScrollTop: integer;
    fScrollTopMax: integer;
    FSearchText: string;
    FSelectedLines: TIntegerList;
    FSelectedView: TLMsgWndView;
    FSourceMarks: TETMarks;
    FTextColor: TColor;
    fUpdateLock: integer;
    FUpdateTimer: TTimer;
    fSomeViewsRunning: boolean;
    fUrgencyStyles: array[TMessageLineUrgency] of TMsgCtrlUrgencyStyle;
    FAutoHeaderBackground: TColor;
    procedure CreateSourceMark(MsgLine: TMessageLine; aSynEdit: TSynEdit);
    procedure CreateSourceMarks(View: TLMsgWndView; StartLineNumber: Integer);
    function GetActiveFilter: TLMsgViewFilter; inline;
    function GetHeaderBackground(aToolState: TLMVToolState): TColor;
    function GetSelectedLine: integer;
    function GetUrgencyStyles(Urgency: TMessageLineUrgency): TMsgCtrlUrgencyStyle;
    function GetViews(Index: integer): TLMsgWndView;
    procedure OnViewChanged(Sender: TObject); // (main thread)
    procedure MsgUpdateTimerTimer(Sender: TObject);
    procedure SetActiveFilter(AValue: TLMsgViewFilter); inline;
    procedure SetBackgroundColor(AValue: TColor);
    procedure SetFilenameStyle(AValue: TMsgWndFileNameStyle);
    procedure SetHeaderBackground(aToolState: TLMVToolState; AValue: TColor);
    procedure SetIdleConnected(AValue: boolean);
    procedure SetImages(AValue: TCustomImageList);
    procedure SetItemHeight(AValue: integer);
    procedure SetOptions(NewOptions: TMsgCtrlOptions);
    procedure SetScrollLeft(AValue: integer);
    procedure SetScrollTop(AValue: integer);
    procedure SetSearchText(AValue: string);
    procedure SetSelectedLine(AValue: integer);
    procedure SetSelectedView(AValue: TLMsgWndView);
    procedure SetSourceMarks(AValue: TETMarks);
    procedure SetTextColor(AValue: TColor);
    procedure SetUrgencyStyles(Urgency: TMessageLineUrgency;
      AValue: TMsgCtrlUrgencyStyle);
    procedure SetAutoHeaderBackground(AValue: TColor);
    procedure WMHScroll(var Msg: TLMScroll); message LM_HSCROLL;
    procedure WMVScroll(var Msg: TLMScroll); message LM_VSCROLL;
    procedure WMMouseWheel(var Message: TLMMouseEvent); message LM_MOUSEWHEEL;
    procedure WMSetFocus(var Message: TLMSetFocus); message LM_SETFOCUS;
    procedure WMKillFocus(var Message: TLMKillFocus); message LM_KILLFOCUS;
    procedure ImageListChange(Sender: TObject);
    procedure OnIdle(Sender: TObject; var {%H-}Done: Boolean);
    procedure OnFilterChanged(Sender: TObject);
    function GetPageScroll: integer;
  protected
    FViews: TFPList;// list of TMessagesViewMap
    FStates: TMsgCtrlStates;
    FPaintStamp: int64;
    fLastSearchStartView: TLMsgWndView;
    fLastSearchStartLine: integer;
    fLastLoSearchText: string; // lower case search text
    procedure FetchNewMessages;
    function FetchNewMessages(View: TLMsgWndView): boolean; // true if new lines
    procedure Notification(AComponent: TComponent; Operation: TOperation);
      override;
    procedure Paint; override;
    procedure UpdateScrollBar(InvalidateScrollMax: boolean);
    procedure CreateWnd; override;
    procedure DoSetBounds(ALeft, ATop, AWidth, AHeight: integer); override;
    //procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure KeyDown(var Key: Word; Shift: TShiftState); override;
    procedure DoOnShowHint(HintInfo: PHintInfo); override;
    procedure DoAllViewsStopped;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure BeginUpdate;
    procedure EndUpdate;
    procedure EraseBackground({%H-}DC: HDC); override;
    procedure ApplyEnvironmentOptions;
    function UrgencyToStr(Urgency: TMessageLineUrgency): string;

    // views
    function ViewCount: integer; inline;
    property Views[Index: integer]: TLMsgWndView read GetViews;
    function IndexOfView(View: TLMsgWndView): integer;
    procedure ClearViews(OnlyFinished: boolean); // deletes/frees all views
    procedure RemoveView(View: TLMsgWndView); // remove without free
    function GetView(aCaption: string; CreateIfNotExist: boolean): TLMsgWndView;
    function GetLineAt(Y: integer; out View: TLMsgWndView; out Line: integer): boolean;
    function GetLineText(Line: TMessageLine): string;
    function GetHeaderText(View: TLMsgWndView): string;
    function FindUnfinishedView: TLMsgWndView; // running or waiting for run
    function GetLastViewWithContent: TLMsgWndView;

    // filter
    property ActiveFilter: TLMsgViewFilter read GetActiveFilter write SetActiveFilter;
    function Filters: TLMsgViewFilters; inline;

    // select, search
    procedure AddToSelection(View: TLMsgWndView; LineNumber: integer);
    procedure ExtendSelection(View: TLMsgWndView; LineNumber: integer);
    function SearchNext(StartView: TLMsgWndView; StartLine: integer;
      SkipStart, Downwards: boolean;
      out View: TLMsgWndView; out LineNumber: integer): boolean;
    procedure Select(View: TLMsgWndView; LineNumber: integer; DoScroll, FullyVisible: boolean);
    procedure Select(Msg: TMessageLine; DoScroll: boolean);
    function SelectNextOccurrence(Downwards: boolean): boolean;
    function SelectNextShown(Offset: integer): boolean;
    function SelectLast(DoScroll, FullyVisible: boolean): boolean;
    function SelectFirst(DoScroll, FullyVisible: boolean): boolean;
    function GetSelectedMsg: TMessageLine;
    function SearchNextUrgent(StartView: TLMsgWndView; StartLine: integer;
      SkipStart, Downwards: boolean;
      aMinUrgency: TMessageLineUrgency; WithSrcPos: boolean;
      out View: TLMsgWndView; out LineNumber: integer): boolean;
    function SelectFirstUrgentMessage(aMinUrgency: TMessageLineUrgency;
      WithSrcPos: boolean): boolean;
    function SelectNextUrgentMessage(aMinUrgency: TMessageLineUrgency;
      WithSrcPos: boolean; Downwards: boolean): boolean;

    // scroll
    function IsLineVisible(View: TLMsgWndView; LineNumber: integer): boolean;
    function IsLastLineVisible(View: TLMsgWndView): boolean;
    procedure ScrollToLine(View: TLMsgWndView; LineNumber: integer; FullyVisible: boolean);
    function GetLineTop(View: TLMsgWndView; LineNumber: integer; Scrolled: boolean): integer;
    property ScrollLeft: integer read FScrollLeft write SetScrollLeft;
    property ScrollTop: integer read FScrollTop write SetScrollTop;
    function ScrollLeftMax: integer;
    function ScrollTopMax: integer;
    procedure StoreSelectedAsSearchStart;

    // file
    function OpenSelection: boolean;
    procedure CreateMarksForFile(aSynEdit: TSynEdit; aFilename: string; DeleteOld: boolean);
    function ApplySrcChanges(Changes: TETSingleSrcChanges): boolean; // true if something changed
  public
    // properties
    property AutoHeaderBackground: TColor read FAutoHeaderBackground write SetAutoHeaderBackground default MsgWndDefAutoHeaderBackground;
    property BackgroundColor: TColor read FBackgroundColor write SetBackgroundColor default MsgWndDefBackgroundColor;
    property Color default clWindow;
    property FilenameStyle: TMsgWndFileNameStyle read FFilenameStyle write SetFilenameStyle;
    property HeaderBackground[aToolState: TLMVToolState]: TColor read GetHeaderBackground write SetHeaderBackground;
    property IdleConnected: boolean read FIdleConnected write SetIdleConnected;
    property Images: TCustomImageList read FImages write SetImages;
    property ItemHeight: integer read FItemHeight write SetItemHeight;
    property OnAllViewsStopped: TNotifyEvent read FOnAllViewsStopped write FOnAllViewsStopped;
    property OnOpenMessage: TOnOpenMessageLine read FOnOpenMessage write FOnOpenMessage;
    Property OnOptionsChanged: TNotifyEvent read FOnOptionsChanged write FOnOptionsChanged;
    property Options: TMsgCtrlOptions read FOptions write SetOptions default MCDefaultOptions;
    property SearchText: string read FSearchText write SetSearchText;
    // First initially selected line, -1=header line, can be on progress line (=View.Count)
    property SelectedLine1: integer read GetSelectedLine write SetSelectedLine;
    property SelectedView: TLMsgWndView read FSelectedView write SetSelectedView;
    property ShowHint default true;
    property SourceMarks: TETMarks read FSourceMarks write SetSourceMarks;
    property TextColor: TColor read FTextColor write SetTextColor default MsgWndDefTextColor;
    property UrgencyStyles[Urgency: TMessageLineUrgency]: TMsgCtrlUrgencyStyle read GetUrgencyStyles write SetUrgencyStyles;
  end;

  { TMessagesFrame }

  TMessagesFrame = class(TFrame)
    HideSearchSpeedButton: TSpeedButton;
    MsgCtrlPopupMenu: TPopupMenu;
    SearchEdit: TEdit;
    SearchNextSpeedButton: TSpeedButton;
    SearchPanel: TPanel;
    SearchPrevSpeedButton: TSpeedButton;
    procedure AboutToolMenuItemClick(Sender: TObject);
    procedure AddFilterMenuItemClick(Sender: TObject);
    procedure ClearFilterMsgTypesMenuItemClick(Sender: TObject);
    procedure ClearMenuItemClick(Sender: TObject);
    procedure CopyAllMenuItemClick(Sender: TObject);
    procedure CopyFilenameMenuItemClick(Sender: TObject);
    procedure CopyMsgMenuItemClick(Sender: TObject);
    procedure CopyShownMenuItemClick(Sender: TObject);
    procedure EditHelpMenuItemClick(Sender: TObject);
    procedure FileStyleMenuItemClick(Sender: TObject);
    procedure FindMenuItemClick(Sender: TObject);
    procedure HelpMenuItemClick(Sender: TObject);
    procedure FilterHintsWithoutPosMenuItemClick(Sender: TObject);
    procedure FilterMsgOfTypeMenuItemClick(Sender: TObject);
    procedure FilterUrgencyMenuItemClick(Sender: TObject);
    procedure HideSearchSpeedButtonClick(Sender: TObject);
    procedure MoreOptionsMenuItemClick(Sender: TObject);
    procedure MsgCtrlPopupMenuPopup(Sender: TObject);
    procedure OnSelectFilterClick(Sender: TObject);
    procedure OpenToolsOptionsMenuItemClick(Sender: TObject);
    procedure RemoveCompOptHideMsgClick(Sender: TObject);
    procedure SaveAllToFileMenuItemClick(Sender: TObject);
    procedure SaveShownToFileMenuItemClick(Sender: TObject);
    procedure SearchEditChange(Sender: TObject);
    procedure SearchEditKeyDown(Sender: TObject; var Key: Word;
      {%H-}Shift: TShiftState);
    procedure SearchNextSpeedButtonClick(Sender: TObject);
    procedure SearchPrevSpeedButtonClick(Sender: TObject);
    procedure ShowIDMenuItemClick(Sender: TObject);
    procedure SrcEditLinesChanged(Sender: TObject);
    procedure TranslateMenuItemClick(Sender: TObject);
    procedure RemoveFilterMsgTypeClick(Sender: TObject);
    procedure WndStayOnTopMenuItemClick(Sender: TObject);
  private
    FImages: TLCLGlyphs;
    function AllMessagesAsString(const OnlyShown: boolean): String;
    function GetAboutView: TLMsgWndView;
    function GetViews(Index: integer): TLMsgWndView;
    procedure HideSearch;
    procedure ImagesGetWidthForPPI(Sender: TCustomImageList; {%H-}AImageWidth,
      {%H-}APPI: Integer; var AResultWidth: Integer);
    procedure SaveClicked(OnlyShown: boolean);
    procedure CopyAllClicked(OnlyShown: boolean);
    procedure CopyMsgToClipboard(OnlyFilename: boolean);
    function GetMsgPattern(SubTool: string; MsgId: integer;
      WithUrgency: boolean; MaxLen: integer): string;
  protected
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
  public
    MessagesCtrl: TMessagesCtrl;
    constructor Create(TheOwner: TComponent); override;
    destructor Destroy; override;

    procedure ApplyIDEOptions;

    // Views
    function ViewCount: integer;
    property Views[Index: integer]: TLMsgWndView read GetViews;
    function GetView(aCaption: string; CreateIfNotExist: boolean): TLMsgWndView;
    function FindUnfinishedView: TLMsgWndView;
    procedure DeleteView(View: TLMsgWndView); // free view
    function IndexOfView(View: TLMsgWndView): integer;
    procedure ClearViews(OnlyFinished: boolean); // deletes/frees all views

    // source marks
    procedure CreateMarksForFile(aSynEdit: TSynEdit; aFilename: string;
      DeleteOld: boolean);
    procedure ApplySrcChanges(Changes: TETSingleSrcChanges);
    procedure ApplyMultiSrcChanges(Changes: TETMultiSrcChanges);
    procedure SourceEditorPopup(MarkLine: TSynEditMarkLine;
      const LogicalCaretXY: TPoint);
    procedure SourceEditorHint(MarkLine: TSynEditMarkLine;
      var HintStr: string);

    // message lines
    procedure SelectMsgLine(Msg: TMessageLine; DoScroll: boolean);
    function SelectFirstUrgentMessage(aMinUrgency: TMessageLineUrgency;
      WithSrcPos: boolean): boolean;
    function SelectNextUrgentMessage(aMinUrgency: TMessageLineUrgency;
      WithSrcPos, Downwards: boolean): boolean;
    procedure ClearCustomMessages(const ViewCaption: string='');
    function AddCustomMessage(TheUrgency: TMessageLineUrgency; Msg: string;
      aFilename: string = ''; LineNumber: integer = 0; Column: integer = 0;
      const ViewCaption: string = CustomViewCaption): TMessageLine;
  end;

const
  MessagesMenuRootName = 'Messages';
var
  MsgFindMenuItem: TIDEMenuCommand;
  MsgQuickFixMenuSection: TIDEMenuSection;
  MsgAboutSection: TIDEMenuSection;
    MsgAboutToolMenuItem: TIDEMenuCommand;
    MsgOpenToolOptionsMenuItem: TIDEMenuCommand;
  MsgFilterMsgOfTypeMenuItem: TIDEMenuCommand;
  MsgRemoveCompOptHideMenuSection: TIDEMenuSection;
  MsgRemoveMsgTypeFilterMenuSection: TIDEMenuSection;
    MsgRemoveFilterMsgOneTypeMenuSection: TIDEMenuSection;
    MsgRemoveFilterAllMsgTypesMenuItem: TIDEMenuCommand;
  MsgFilterBelowMenuSection: TIDEMenuSection;
    MsgFilterWarningsMenuItem: TIDEMenuCommand;
    MsgFilterNotesMenuItem: TIDEMenuCommand;
    MsgFilterHintsMenuItem: TIDEMenuCommand;
    MsgFilterVerboseMenuItem: TIDEMenuCommand;
    MsgFilterDebugMenuItem: TIDEMenuCommand;
    MsgFilterNoneMenuItem: TIDEMenuCommand;
  MsgFilterHintsWithoutPosMenuItem: TIDEMenuCommand;
  MsgFiltersMenuSection: TIDEMenuSection;
    MsgSelectFilterMenuSection: TIDEMenuSection;
    MsgAddFilterMenuItem: TIDEMenuCommand;
  MsgCopyMenuSection: TIDEMenuSection;
    MsgCopyFilenameMenuItem: TIDEMenuCommand;
    MsgCopyMsgMenuItem: TIDEMenuCommand;
    MsgCopyShownMenuItem: TIDEMenuCommand;
    MsgCopyAllMenuItem: TIDEMenuCommand;
  MsgSaveToFileMenuSection: TIDEMenuSection;
    MsgSaveAllToFileMenuItem: TIDEMenuCommand;
    MsgSaveShownToFileMenuItem: TIDEMenuCommand;
  MsgHelpMenuItem: TIDEMenuCommand;
  MsgEditHelpMenuItem: TIDEMenuCommand;
  MsgClearMenuItem: TIDEMenuCommand;
  MsgOptionsMenuSection: TIDEMenuSection;
    MsgWndStayOnTopMenuItem: TIDEMenuCommand;
    MsgFilenameStyleMenuSection: TIDEMenuSection;
      MsgFileStyleShortMenuItem: TIDEMenuCommand;
      MsgFileStyleRelativeMenuItem: TIDEMenuCommand;
      MsgFileStyleFullMenuItem: TIDEMenuCommand;
    MsgTranslateMenuItem: TIDEMenuCommand;
    MsgShowIDMenuItem: TIDEMenuCommand;
    MsgMoreOptionsMenuItem: TIDEMenuCommand;

procedure RegisterStandardMessagesViewMenuItems;

implementation

procedure RegisterStandardMessagesViewMenuItems;
var
  Parent: TIDEMenuSection;
  Root: TIDEMenuSection;
begin
  MessagesMenuRoot := RegisterIDEMenuRoot(MessagesMenuRootName);
  Root:=MessagesMenuRoot;
  MsgFindMenuItem := RegisterIDEMenuCommand(Root, 'Find', lisFind);
  MsgQuickFixMenuSection := RegisterIDEMenuSection(Root, 'Quick Fix');
  MsgAboutSection:=RegisterIDEMenuSection(Root,'About');
    Parent:=MsgAboutSection;
    Parent.ChildrenAsSubMenu:=true;
    Parent.Caption:=lisAbout;
    MsgAboutToolMenuItem:=RegisterIDEMenuCommand(Parent, 'About', lisAbout);
    MsgOpenToolOptionsMenuItem:=RegisterIDEMenuCommand(Parent, 'Open Tool '
      +'Options', lisOpenToolOptions);
  MsgFilterMsgOfTypeMenuItem:=RegisterIDEMenuCommand(Root,'FilterMsgOfType',lisFilterAllMessagesOfCertainType);
  MsgRemoveCompOptHideMenuSection:=RegisterIDEMenuSection(Root,'RemoveCompOptHideMsg');
    Parent:=MsgRemoveCompOptHideMenuSection;
    Parent.ChildrenAsSubMenu:=true;
    Parent.Caption:=lisRemoveCompilerOptionHideMessage;
  MsgRemoveMsgTypeFilterMenuSection:=RegisterIDEMenuSection(Root,'RemoveMsgTypeFilters');
    Parent:=MsgRemoveMsgTypeFilterMenuSection;
    Parent.ChildrenAsSubMenu:=true;
    Parent.Caption:=lisRemoveMessageTypeFilter;
    MsgRemoveFilterMsgOneTypeMenuSection:=RegisterIDEMenuSection(Parent,'RemoveOneMsgTypeFilterSection');
    MsgRemoveFilterAllMsgTypesMenuItem:=RegisterIDEMenuCommand(Parent, 'Remove'
      +' all message type filters', lisRemoveAllMessageTypeFilters);
  MsgFilterBelowMenuSection:=RegisterIDEMenuSection(Root,'Filter Below Section');
    Parent:=MsgFilterBelowMenuSection;
    Parent.ChildrenAsSubMenu:=true;
    Parent.Caption:=lisFilterNonUrgentMessages;
    MsgFilterWarningsMenuItem:=RegisterIDEMenuCommand(Parent,
      'Filter Warnings', lisFilterWarningsAndBelow);
    MsgFilterWarningsMenuItem.RadioItem:=true;
    MsgFilterWarningsMenuItem.GroupIndex:=2;
    MsgFilterNotesMenuItem:=RegisterIDEMenuCommand(Parent, 'Filter Notes',
      lisFilterNotesAndBelow);
    MsgFilterNotesMenuItem.RadioItem:=true;
    MsgFilterNotesMenuItem.GroupIndex:=2;
    MsgFilterHintsMenuItem:=RegisterIDEMenuCommand(Parent, 'Filter Hints',
      lisFilterHintsAndBelow);
    MsgFilterHintsMenuItem.RadioItem:=true;
    MsgFilterHintsMenuItem.GroupIndex:=2;
    MsgFilterVerboseMenuItem:=RegisterIDEMenuCommand(Parent, 'Filter Verbose '
      +'Messages', lisFilterVerboseMessagesAndBelow);
    MsgFilterVerboseMenuItem.RadioItem:=true;
    MsgFilterVerboseMenuItem.GroupIndex:=2;
    MsgFilterDebugMenuItem:=RegisterIDEMenuCommand(Parent, 'Filter Debug '
      +'Messages', lisFilterDebugMessagesAndBelow);
    MsgFilterDebugMenuItem.RadioItem:=true;
    MsgFilterDebugMenuItem.GroupIndex:=2;
    MsgFilterNoneMenuItem:=RegisterIDEMenuCommand(Parent, 'Filter None, do not'
      +' filter by urgency', lisFilterNoneDoNotFilterByUrgency);
    MsgFilterNoneMenuItem.RadioItem:=true;
    MsgFilterNoneMenuItem.GroupIndex:=2;
  MsgFilterHintsWithoutPosMenuItem:=RegisterIDEMenuCommand(Root, 'Filter Hints'
    +' without Source Position', lisFilterHintsWithoutSourcePosition);
  MsgFiltersMenuSection:=RegisterIDEMenuSection(Root,'Switch Filter Section');
    Parent:=MsgFiltersMenuSection;
    Parent.ChildrenAsSubMenu:=true;
    Parent.Caption:=lisSwitchFilterSettings;
    MsgSelectFilterMenuSection:=RegisterIDEMenuSection(Parent,'Filters');
    MsgAddFilterMenuItem:=RegisterIDEMenuCommand(Parent, 'Add Filter',
      lisAddFilter);
  MsgCopyMenuSection:=RegisterIDEMenuSection(Root,'Copy');
    Parent:=MsgCopyMenuSection;
    Parent.ChildrenAsSubMenu:=true;
    Parent.Caption:=lisCopy;
    MsgCopyFilenameMenuItem:=RegisterIDEMenuCommand(Parent, 'Filename',
      lisCopyFileNameToClipboard);
    MsgCopyMsgMenuItem := RegisterIDEMenuCommand(Parent, 'Selected',lisCopySelectedMessagesToClipboard);
    MsgCopyShownMenuItem := RegisterIDEMenuCommand(Parent, 'Shown', lisCopyAllShownMessagesToClipboard);
    MsgCopyAllMenuItem:=RegisterIDEMenuCommand(Parent, 'All',
      lisCopyAllOriginalMessagesToClipboard);
  MsgSaveToFileMenuSection:=RegisterIDEMenuSection(Root,'Save');
    Parent:=MsgSaveToFileMenuSection;
    Parent.ChildrenAsSubMenu:=true;
    Parent.Caption:=lisSave;
    MsgSaveShownToFileMenuItem:=RegisterIDEMenuCommand(Parent, 'Save Shown '
      +'Messages to File', lisSaveShownMessagesToFile);
    MsgSaveAllToFileMenuItem:=RegisterIDEMenuCommand(Parent, 'Save All '
      +'Messages to File', lisSaveAllOriginalMessagesToFile);
  MsgHelpMenuItem := RegisterIDEMenuCommand(Root, 'Help for this message',lisHelp);
  MsgEditHelpMenuItem := RegisterIDEMenuCommand(Root, 'Edit help for messages',lisEditHelp);
  MsgClearMenuItem := RegisterIDEMenuCommand(Root, 'Clear', lisClear);
  MsgOptionsMenuSection:=RegisterIDEMenuSection(Root,'Option Section');
    Parent:=MsgOptionsMenuSection;
    Parent.ChildrenAsSubMenu:=true;
    Parent.Caption:=lisOptions;
    MsgWndStayOnTopMenuItem:=RegisterIDEMenuCommand(Parent,
      'Window stay on top', lisWindowStaysOnTop);
    MsgFilenameStyleMenuSection:=RegisterIDEMenuSection(Parent,'Filename Styles');
      Parent:=MsgFilenameStyleMenuSection;
      Parent.ChildrenAsSubMenu:=true;
      Parent.Caption:=lisFilenameStyle;
      MsgFileStyleShortMenuItem:=RegisterIDEMenuCommand(Parent, 'Short',
        lisShortNoPath);
      MsgFileStyleRelativeMenuItem:=RegisterIDEMenuCommand(Parent, 'Relative',
        lisRelative);
      MsgFileStyleFullMenuItem:=RegisterIDEMenuCommand(Parent, 'Full', lisFull);
    Parent:=MsgOptionsMenuSection;
    MsgTranslateMenuItem:=RegisterIDEMenuCommand(Parent, 'Translate',
      lisTranslateTheEnglishMessages);
    MsgShowIDMenuItem:=RegisterIDEMenuCommand(Parent, 'ShowID',
      lisShowMessageTypeID);
    MsgMoreOptionsMenuItem:=RegisterIDEMenuCommand(Parent, 'More Options',
      lisDlgMore);
end;

{$R *.lfm}

{ TLMsgWndView }

procedure TLMsgWndView.OnMarksFixed(ListOfTMessageLine: TFPList);
var
  i: Integer;
  ViewLine: TMessageLine;
  j: Integer;
  WorkerMsg: TMessageLine;
begin
  //debugln(['TLMsgWndView.OnMarksFixed START ',ListOfTMessageLine.Count]);
  // apply marks to WorkerMessages
  if Tool<>nil then begin
    Tool.EnterCriticalSection;
    try
      for i:=0 to ListOfTMessageLine.Count-1 do begin
        ViewLine:=TMessageLine(ListOfTMessageLine[i]);
        j:=Tool.WorkerMessages.IndexOfOutputIndex(ViewLine.OutputIndex);
        if j<0 then continue;
        WorkerMsg:=Tool.WorkerMessages[j];
        WorkerMsg.Flags:=ViewLine.Flags;
        //debugln(['TLMsgWndView.OnMarksFixed j=',j,' ',dbgs(WorkerMsg.Flags),' ',dbgs(Pointer(WorkerMsg)),' WorkerMsg.OutputIndex=',WorkerMsg.OutputIndex,' ViewLine.OutputIndex=',ViewLine.OutputIndex]);
      end;
    finally
      Tool.LeaveCriticalSection;
    end;
  end;

  // delete messages from view
  for i:=ListOfTMessageLine.Count-1 downto 0 do begin
    ViewLine:=TMessageLine(ListOfTMessageLine[i]);
    Lines.Delete(ViewLine);
  end;
  ListOfTMessageLine.Clear;

  // update control
  Control.UpdateScrollBar(true);
  Control.Invalidate;
end;

procedure TLMsgWndView.SetToolState(AValue: TLMVToolState);
begin
  if ToolState=AValue then Exit;
  inherited;
  Control.Invalidate;
end;

procedure TLMsgWndView.SetFilter(AValue: TLMsgViewFilter);
begin
  FFilter.Assign(AValue);
end;

procedure TLMsgWndView.FetchAllPending;
var
  OldLineCount: Integer;
  i: Integer;
  OldUpdateSortedSrcPos: Boolean;
  MsgLine: TMessageLine;
  Line: Integer;
  Col: Integer;
begin
  OldLineCount:=Lines.Count;
  inherited FetchAllPending;
  if OldLineCount=Lines.Count then exit;

  // apply pending src changes
  OldUpdateSortedSrcPos:=Lines.UpdateSortedSrcPos;
  if FPendingChanges.Count>0 then begin
    Lines.UpdateSortedSrcPos:=false;
    try
      for i:=OldLineCount to Lines.Count-1 do begin
        MsgLine:=Lines[i];
        //debugln(['TLMsgWndView.FetchAllPending ',i,' ',MsgLine.Msg]);
        Line:=MsgLine.Line;
        Col:=MsgLine.Column;
        FPendingChanges.AdaptCaret(MsgLine.GetFullFilename,Line,Col,
          mlfLeftToken in MsgLine.Flags);
        MsgLine.SetSourcePosition(MsgLine.Filename,Line,Col);
      end;
    finally
      Lines.UpdateSortedSrcPos:=OldUpdateSortedSrcPos;
    end;
  end;
end;

procedure TLMsgWndView.ToolExited;
var
  ErrCount: Integer;
  u: TMessageLineUrgency;
  MsgLine: TMessageLine;
  i: Integer;
  StartLine: Integer;
  sl: TStringList;
begin
  inherited ToolExited;
  if Tool.Terminated then begin
    ToolState:=lmvtsFailed;
  end else if (ExitStatus<>0) or (ExitCode<>0) then begin
    // tool stopped with errors
    ErrCount:=0;
    EnterCriticalSection;
    try
      for u:=mluError to high(TMessageLineUrgency) do
        inc(ErrCount,Lines.UrgencyCounts[u]+PendingLines.UrgencyCounts[u]);
    finally
      LeaveCriticalSection;
    end;
    if ErrCount=0 then begin
      // parser did not add an error message
      // => add an error message
      // add up the last 100 lines of output with panic urgency
      Tool.EnterCriticalSection; // Note: always lock Tool *before* View
      try
        EnterCriticalSection;
        try
          StartLine:=Max(0,Tool.WorkerOutput.Count-100);
          if PendingLines.Count>0 then
            StartLine:=Max(StartLine,PendingLines[PendingLines.Count-1].OutputIndex+1);
          if Lines.Count>0 then
            StartLine:=Max(StartLine,Lines[Lines.Count-1].OutputIndex+1);
          for i:=StartLine to Tool.WorkerOutput.Count-1 do
          begin
            MsgLine:=PendingLines.CreateLine(-1);
            MsgLine.Msg:=Tool.WorkerOutput[i];
            MsgLine.Urgency:=mluPanic;
            PendingLines.Add(MsgLine);
          end;
          MsgLine:=PendingLines.CreateLine(-1);
          MsgLine.Urgency:=mluPanic;
          if ExitCode<>0 then
            MsgLine.Msg:=Format(
              lisToolStoppedWithExitCodeUseContextMenuToGetMoreInfo, [IntToStr(
              ExitCode)])
          else
            MsgLine.Msg:=Format(
              lisToolStoppedWithExitStatusUseContextMenuToGetMoreInfo, [
              IntToStr(ExitStatus)]);
          PendingLines.Add(MsgLine);
        finally
          LeaveCriticalSection;
        end;
      finally
        Tool.LeaveCriticalSection;
      end;
    end;
    ToolState:=lmvtsFailed;
  end else if Tool.ErrorMessage<>'' then begin
    // error executing the tool
    EnterCriticalSection;
    try
      sl:=TStringList.Create;
      try
        sl.Text:=Tool.ErrorMessage;
        for i:=0 to sl.Count-1 do begin
          if sl[i]='' then continue;
          MsgLine:=PendingLines.CreateLine(-1);
          MsgLine.Urgency:=mluPanic;
          MsgLine.Msg:=Format(lisInternalError, [sl[i]]);
          PendingLines.Add(MsgLine);
        end;
      finally
        sl.Free;
      end;
    finally
      LeaveCriticalSection;
    end;
    ToolState:=lmvtsFailed;
  end else
    ToolState:=lmvtsSuccess;
end;

procedure TLMsgWndView.CallOnChangedInMainThread(Data: PtrInt);
begin
  FAsyncQueued:=false;
  if csDestroying in ComponentState then exit;
  if Assigned(OnChanged) then
    OnChanged(Self);
end;

procedure TLMsgWndView.QueueAsyncOnChanged;
begin
  if FAsyncQueued then exit;
  FAsyncQueued:=true;
  if Application<>nil then
    Application.QueueAsyncCall(@CallOnChangedInMainThread,0);
end;

procedure TLMsgWndView.RemoveAsyncOnChanged;
begin
  if not FAsyncQueued then exit;
  FAsyncQueued:=false;
  if Application<>nil then
    Application.RemoveAsyncCalls(Self);
end;

constructor TLMsgWndView.Create(AOwner: TComponent);
begin
  fMessageLineClass:=TLMsgViewLine;
  inherited Create(AOwner);
  Lines.OnMarksFixed:=@OnMarksFixed;
  FFilter:=TLMsgViewFilter.Create;
  fPendingChanges:=TETMultiSrcChanges.Create(nil);
end;

destructor TLMsgWndView.Destroy;
begin
  inherited Destroy;
  FreeAndNil(FPendingChanges);
  FreeAndNil(FFilter);
end;

function TLMsgWndView.LineFits(Line: TMessageLine): boolean;
begin
  if FFilter<>nil then
    Result:=FFilter.LineFits(Line)
  else
    Result:=inherited LineFits(Line);
end;

function TLMsgWndView.HasContent: boolean;
begin
  Result:=GetShownLineCount(true,true)>0;
end;

function TLMsgWndView.GetShownLineCount(WithHeader, WithProgressLine: boolean
  ): integer;
begin
  Result:=Lines.Count;
  // the header is only shown if there SummaryMsg<>'' or ProgressLine.Msg<>'' or Lines.Count>0
  if ProgressLine.Msg<>'' then begin
    if WithHeader then
      inc(Result);
    if WithProgressLine then
      inc(Result);
  end else if Caption<>'' then begin
    if WithHeader then
      inc(Result);
  end else if (Result>0) and WithHeader then
    inc(Result);
end;

procedure TLMsgWndView.RebuildLines;
// called by main thread
var
  i: Integer;
  SrcMsg: TMessageLine;
  NewProgressLine: TMessageLine;
  NewMsg: TMessageLine;
  Line: Integer;
  Col: Integer;
begin
  if Tool=nil then exit;
  Tool.EnterCriticalSection; // lock Tool before View
  try
    EnterCriticalSection;
    try
      ClearLines;
      NewProgressLine:=nil;
      for i:=0 to Tool.WorkerMessages.Count-1 do begin
        SrcMsg:=Tool.WorkerMessages[i];
        //if Pos('"db"',SrcMsg.Msg)>0 then
         // debugln(['TLMsgWndView.RebuildLines i=',i,' Msg="',SrcMsg.Msg,'" Fits=',LineFits(SrcMsg),' ',dbgs(SrcMsg.Flags),' ',SrcMsg.OutputIndex]);
        if LineFits(SrcMsg) then begin
          NewProgressLine:=nil;
          NewMsg:=Lines.CreateLine(-1);
          NewMsg.Assign(SrcMsg);
          // adapt line,col due to src changes
          Line:=NewMsg.Line;
          Col:=NewMsg.Column;
          FPendingChanges.AdaptCaret(NewMsg.GetFullFilename,Line,Col,
                                     mlfLeftToken in NewMsg.Flags);
          NewMsg.SetSourcePosition(NewMsg.Filename,Line,Col);
          //debugln(['TLMsgWndView.RebuildLines NewMsg=',Lines.Count,'="',NewMsg.Msg,'"']);
          Lines.Add(NewMsg);
        end else begin
          NewProgressLine:=SrcMsg;
        end;
      end;
      FLastWorkerMessageCount:=Tool.WorkerMessages.Count-1;
      if (NewProgressLine<>nil) and Running then begin
        ProgressLine.Assign(NewProgressLine);
      end
      else if ProgressLine.Msg<>'' then begin
        ProgressLine.Clear;
      end;
    finally
      LeaveCriticalSection;
    end;
  finally
    Tool.LeaveCriticalSection;
  end;
end;

function TLMsgWndView.ApplySrcChanges(Changes: TETSingleSrcChanges): boolean;

  function ApplyChanges(CurChanges: TETSingleSrcChanges;
    CurLines: TMessageLines): boolean;
  var
    FromY: integer;
    MaxY: integer;
    LineDiffBehindMaxY: integer;
    ToY: Integer;
    MsgLine: TMessageLine;
    Line: Integer;
    Col: Integer;
    OldUpdateSortedSrcPos: Boolean;
  begin
    Result:=false;
    if CurChanges.First=nil then exit;
    CurChanges.GetRange(FromY,MaxY,LineDiffBehindMaxY);
    if LineDiffBehindMaxY=0 then
      ToY:=MaxY
    else
      ToY:=High(Integer);
    OldUpdateSortedSrcPos:=Lines.UpdateSortedSrcPos;
    CurLines.UpdateSortedSrcPos:=false;
    try
      {if CurLines=Lines then begin
        debugln(['ApplyChanges MinY=',FromY,' MaxY=',MaxY,' LineDiffBehindMaxY=',LineDiffBehindMaxY]);
        CurChanges.WriteDebugReport('Changes:');
      end;}
      for MsgLine in CurLines.EnumerateFile(CurChanges.Filename,FromY,ToY)
      do begin
        Line:=MsgLine.Line;
        Col:=MsgLine.Column;
        if Line>MaxY then
          inc(Line,LineDiffBehindMaxY)
        else
          CurChanges.AdaptCaret(Line,Col,mlfLeftToken in MsgLine.Flags);
        //if CurLines=Lines then
        //  debugln(['ApplyChanges ',MsgLine.Msg,' Old=',MsgLine.Line,',',MsgLine.Column,' New=',Line,',',Col]);

        if (Line=MsgLine.Line) and (MsgLine.Column=Col) then continue;
        MsgLine.SetSourcePosition(MsgLine.Filename,Line,Col);
        Result:=true;
      end;
    finally
      CurLines.UpdateSortedSrcPos:=OldUpdateSortedSrcPos;
    end;
  end;

var
  Queue: TETSingleSrcChanges;
  Change: TETSrcChange;
  Node: TAvlTreeNode;
  aFilename: String;
begin
  Result:=false;
  //debugln(['TLMsgWndView.ApplySrcChanges START ',Changes.Filename,' ',Changes.First<>nil]);
  // check if there are changes
  if Changes.First=nil then exit;
  aFilename:=Changes.Filename;
  if aFilename='' then exit;

  // update visible lines
  Result:=ApplyChanges(Changes,Lines);

  // update pending lines
  if Tool<>nil then begin
    Tool.EnterCriticalSection; // lock Tool before View
    try
      EnterCriticalSection;
      try
        Queue:=PendingChanges.GetChanges(aFilename,true);
        Change:=Changes.First;
        while Change<>nil do begin
          Queue.Add(Change.Action,Change.FromPos,Change.ToPos);
          Change:=Change.Next;
        end;
        if not Running then begin
          // apply all pending changes to Tool.WorkerMessages
          Node:=PendingChanges.AllChanges.FindLowest;
          while Node<>nil do begin
            ApplyChanges(TETSingleSrcChanges(Node.Data),Tool.WorkerMessages);
            Node:=Node.Successor;
          end;
          PendingChanges.Clear;
        end;
      finally
        LeaveCriticalSection;
      end;
    finally
      Tool.LeaveCriticalSection;
    end;
  end;
end;

{ TMsgCtrlUrgencyStyle }

procedure TMsgCtrlUrgencyStyle.SetColor(AValue: TColor);
begin
  if FColor=AValue then Exit;
  FColor:=AValue;
  Changed;
end;

procedure TMsgCtrlUrgencyStyle.SetImageIndex(AValue: integer);
begin
  if FImageIndex=AValue then Exit;
  FImageIndex:=AValue;
  Changed;
end;

procedure TMsgCtrlUrgencyStyle.SetTranslated(AValue: string);
begin
  if FTranslated=AValue then Exit;
  FTranslated:=AValue;
  Changed;
end;

procedure TMsgCtrlUrgencyStyle.Changed;
begin
  Control.Invalidate;
end;

constructor TMsgCtrlUrgencyStyle.Create(AControl: TMessagesCtrl;
  TheUrgency: TMessageLineUrgency);
begin
  FControl:=AControl;
  fUrgency:=TheUrgency;
  FImageIndex:=-1;
  FColor:=clDefault;
end;

function TMsgCtrlUrgencyStyle.Equals(Obj: TObject): boolean;
var
  Src: TMsgCtrlUrgencyStyle;
begin
  if Obj is TMsgCtrlUrgencyStyle then begin
    Src:=TMsgCtrlUrgencyStyle(Obj);
    Result:=(ImageIndex=Src.ImageIndex)
        and (Color=Src.Color)
        and (Translated=Src.Translated);
  end else
    Result:=inherited Equals(Obj);
end;

procedure TMsgCtrlUrgencyStyle.Assign(Src: TMsgCtrlUrgencyStyle);
begin
  if Equals(Src) then exit;
  fImageIndex:=Src.ImageIndex;
  fColor:=Src.Color;
  fTranslated:=Src.Translated;
  Changed;
end;

procedure TMsgCtrlUrgencyStyle.SetValues(TheTranslated: string;
  TheImageIndex: integer; TheColor: TColor);
begin
  Translated:=TheTranslated;
  ImageIndex:=TheImageIndex;
  Color:=TheColor;
end;

{ TMessagesCtrl }

// inline
function TMessagesCtrl.ViewCount: integer;
begin
  Result:=FViews.Count;
end;

// inline
function TMessagesCtrl.Filters: TLMsgViewFilters;
begin
  Result:=EnvironmentOptions.MsgViewFilters;
end;

// inline
function TMessagesCtrl.GetActiveFilter: TLMsgViewFilter;
begin
  Result:=Filters.ActiveFilter;
end;

// inline
procedure TMessagesCtrl.SetActiveFilter(AValue: TLMsgViewFilter);
begin
  Filters.ActiveFilter:=AValue;
end;

function TMessagesCtrl.GetViews(Index: integer): TLMsgWndView;

  procedure RaiseOutOfBounds;
  begin
    raise Exception.Create('TMessagesCtrl.GetViews '+IntToStr(Index)+' out of bounds '+IntToStr(ViewCount));
  end;

begin
  if (Index<0) or (Index>=ViewCount) then
    RaiseOutOfBounds;
  Result:=TLMsgWndView(FViews[Index]);
end;

procedure TMessagesCtrl.OnViewChanged(Sender: TObject);
var
  AllViewsStopped: Boolean;
  i: Integer;
begin
  for i:=0 to ViewCount-1 do begin
    if Views[i].Running then begin
      // the views may change many times
      // reduce the update of the control to a few per second by using a timer
      fSomeViewsRunning:=true;
      FUpdateTimer.Enabled:=true;
      exit;
    end;
  end;
  // no views are running
  // The variable fSomeViewsRunning contains the last state
  // if fSomeViewsRunning was true, then all views have stopped
  AllViewsStopped:=fSomeViewsRunning;
  fSomeViewsRunning:=false;
  // no views running => update immediately
  FetchNewMessages;

  if AllViewsStopped then
    DoAllViewsStopped;
end;

procedure TMessagesCtrl.FetchNewMessages;
// called when new messages are available from the worker threads
// calls Views to fetch and filter new messages
// scrolls to new message
var
  i: Integer;
begin
  if csDestroying in ComponentState then exit;
  BeginUpdate;
  try
    for i:=0 to ViewCount-1 do
      FetchNewMessages(Views[i]);
  finally
    EndUpdate;
  end;
  UpdateScrollBar(true);
end;

function TMessagesCtrl.FetchNewMessages(View: TLMsgWndView): boolean;
var
  OldLineCount: Integer;
  i: Integer;
  OtherView: TLMsgWndView;
  MaxY: Integer;
  y: Integer;
begin
  Result:=false;
  if csDestroying in ComponentState then exit;
  if IndexOfView(View)<0 then exit;

  OldLineCount:=View.Lines.Count;
  if not View.ApplyPending then
    exit; // no new lines
  Result:=true;
  CreateSourceMarks(View,OldLineCount);
  UpdateScrollBar(true);
  Invalidate;

  // auto scroll
  if SelectedView<>nil then
    exit; // user has selected a non progress line -> do not auto scroll

  for i:=0 to ViewCount-1 do
  begin
    OtherView:=Views[i];
    if OtherView=View then break;
    if OtherView.Running then begin
      // there is still a prior View running
      // -> keep the last line of the other View visible
      MaxY:=GetLineTop(OtherView,OtherView.GetShownLineCount(true,true),false);
      y:=GetLineTop(View,View.GetShownLineCount(false,true),false);
      ScrollTop:=Min(MaxY,y);
      exit;
    end;
  end;
  // scroll to last line
  ScrollToLine(View,View.GetShownLineCount(false,true),true);
end;

procedure TMessagesCtrl.MsgUpdateTimerTimer(Sender: TObject);
begin
  FUpdateTimer.Enabled:=false;
  FetchNewMessages;
end;

procedure TMessagesCtrl.SetBackgroundColor(AValue: TColor);
begin
  if FBackgroundColor=AValue then Exit;
  FBackgroundColor:=AValue;
  Invalidate;
end;

procedure TMessagesCtrl.SetFilenameStyle(AValue: TMsgWndFileNameStyle);
begin
  if FFilenameStyle=AValue then Exit;
  FFilenameStyle:=AValue;
  Invalidate;
end;

procedure TMessagesCtrl.SetHeaderBackground(aToolState: TLMVToolState;
  AValue: TColor);
begin
  if FHeaderBackground[aToolState]=AValue then exit;
  FHeaderBackground[aToolState]:=AValue;
  Invalidate;
end;

procedure TMessagesCtrl.SetIdleConnected(AValue: boolean);
begin
  if FIdleConnected=AValue then Exit;
  FIdleConnected:=AValue;
  if IdleConnected then
    Application.AddOnIdleHandler(@OnIdle)
  else
    Application.RemoveOnIdleHandler(@OnIdle);
end;

procedure TMessagesCtrl.SetImages(AValue: TCustomImageList);
begin
  if FImages=AValue then Exit;
  if Images <> nil then
    Images.UnRegisterChanges(FImageChangeLink);
  FImages:=AValue;
  if Images <> nil then begin
    Images.RegisterChanges(FImageChangeLink);
    Images.FreeNotification(Self);
    if ItemHeight<Images.Height+2 then
      ItemHeight:=Images.Height+2;
  end;
  Invalidate;
end;

procedure TMessagesCtrl.SetItemHeight(AValue: integer);
begin
  FItemHeight:=Max(0,FItemHeight);
  if FItemHeight=AValue then Exit;
  FItemHeight:=AValue;
  UpdateScrollBar(true);
  Invalidate;
end;

procedure TMessagesCtrl.SetOptions(NewOptions: TMsgCtrlOptions);
var
  ChangedOptions: TMsgCtrlOptions;
begin
  if FOptions=NewOptions then Exit;
  ChangedOptions:=(FOptions-NewOptions)+(NewOptions-FOptions);
  FOptions:=NewOptions;
  if [mcoShowStats,mcoShowTranslated,mcoShowMessageID,mcoShowMsgIcons,
    mcoAlwaysDrawFocused]*ChangedOptions<>[]
  then
    Invalidate;
  if Assigned(OnOptionsChanged) then
    OnOptionsChanged(Self);
end;

procedure TMessagesCtrl.SetScrollLeft(AValue: integer);
begin
  AValue:=Max(0,Min(AValue,ScrollLeftMax));
  if FScrollLeft=AValue then Exit;
  FScrollLeft:=AValue;
  UpdateScrollBar(false);
  Invalidate;
end;

procedure TMessagesCtrl.SetScrollTop(AValue: integer);
begin
  AValue:=Max(0,Min(AValue,ScrollTopMax));
  if FScrollTop=AValue then Exit;
  FScrollTop:=AValue;
  UpdateScrollBar(false);
  Invalidate;
end;

procedure TMessagesCtrl.SetSearchText(AValue: string);
begin
  if FSearchText=AValue then Exit;
  FSearchText:=AValue;
  IdleConnected:=true;
end;

procedure TMessagesCtrl.SetSelectedLine(AValue: integer);
// Select the given line, clear possibly existing selections.
var
  LineCnt: Integer;
begin
  Assert(AValue>=-1, 'TMessagesCtrl.SetSelectedLine: AValue < -1.');
  Assert(Assigned(SelectedView), 'TMessagesCtrl.SetSelectedLine: View = Nil.');
  LineCnt:=SelectedView.GetShownLineCount(false,true)-1;
  Assert(AValue<=LineCnt, 'TMessagesCtrl.SetSelectedLine: Value '+IntToStr(AValue)
                        + ' > line count ' + IntToStr(LineCnt));
  //AValue:=Min(AValue, SelectedView.GetShownLineCount(false,true)-1);
  if (FSelectedLines.Count>0) and (FSelectedLines[0]=AValue) then
    Exit;
  FSelectedLines.Count:=1;    // One line.
  FSelectedLines[0]:=AValue;
  Invalidate;
end;

procedure TMessagesCtrl.SetSelectedView(AValue: TLMsgWndView);
begin
  if FSelectedView=AValue then Exit;
  FSelectedView:=AValue;
  Invalidate;
end;

procedure TMessagesCtrl.SetSourceMarks(AValue: TETMarks);
begin
  if FSourceMarks=AValue then Exit;
  FSourceMarks:=AValue;
  if SourceMarks<>nil then
    FreeNotification(SourceMarks);
end;

procedure TMessagesCtrl.SetTextColor(AValue: TColor);
begin
  if FTextColor=AValue then Exit;
  FTextColor:=AValue;
  Invalidate;
end;

procedure TMessagesCtrl.SetUrgencyStyles(Urgency: TMessageLineUrgency;
  AValue: TMsgCtrlUrgencyStyle);
begin
  fUrgencyStyles[Urgency].Assign(AValue);
end;

procedure TMessagesCtrl.SetAutoHeaderBackground(AValue: TColor);
begin
  if FAutoHeaderBackground=AValue then Exit;
  FAutoHeaderBackground:=AValue;
  Invalidate;
end;

function TMessagesCtrl.UrgencyToStr(Urgency: TMessageLineUrgency): string;
begin
  if (mcoShowTranslated in Options)
  and (fUrgencyStyles[Urgency].Translated<>'') then
    Result:=fUrgencyStyles[Urgency].Translated
  else
    Result:=MessageLineUrgencyNames[Urgency];
end;

procedure TMessagesCtrl.WMHScroll(var Msg: TLMScroll);
begin
  case Msg.ScrollCode of
      // Scrolls to start / end of the line
    SB_TOP: ScrollLeft := 1;
    SB_BOTTOM: ScrollLeft := ScrollLeftMax;
      // Scrolls one char left / right
    SB_LINEDOWN: ScrollLeft := ScrollLeft + 1;
    SB_LINEUP: ScrollLeft := ScrollLeft - 1;
      // Scrolls one page of chars left / right
    SB_PAGEDOWN: ScrollLeft := ScrollLeft + (ClientWidth div 2);
    SB_PAGEUP: ScrollLeft := ScrollLeft - (ClientHeight div 2);
      // Scrolls to the current scroll bar position
    SB_THUMBPOSITION,
    SB_THUMBTRACK: ScrollLeft := Msg.Pos;
  end;
end;

procedure TMessagesCtrl.WMVScroll(var Msg: TLMScroll);
begin
  case Msg.ScrollCode of
    // Scrolls to start / end of the text
    SB_TOP:        ScrollTop := 0;
    SB_BOTTOM:     ScrollTop := ScrollTopMax;
    {$IFDEF EnableMsgWndLineWrap}
    // Scrolls one line up / down
    SB_LINEDOWN:   ScrollTop := ScrollTop + 1;
    SB_LINEUP:     ScrollTop := ScrollTop - 1;
    {$ELSE}
      // Scrolls one line up / down
    SB_LINEDOWN:   ScrollTop := ScrollTop + ItemHeight div 2;
    SB_LINEUP:     ScrollTop := ScrollTop - ItemHeight div 2;
    {$ENDIF}
    // Scrolls one page of lines up / down
    SB_PAGEDOWN:   ScrollTop := ScrollTop + GetPageScroll;
    SB_PAGEUP:     ScrollTop := ScrollTop - GetPageScroll;
    // Scrolls to the current scroll bar position
    SB_THUMBPOSITION,
    SB_THUMBTRACK: ScrollTop := Msg.Pos;
    // Ends scrolling
    SB_ENDSCROLL:  SetCaptureControl(nil); // release scrollbar capture
  end;
end;

procedure TMessagesCtrl.WMMouseWheel(var Message: TLMMouseEvent);
begin
  if Mouse.WheelScrollLines=-1 then
  begin
    // -1 : scroll by page
    ScrollTop := ScrollTop - (Message.WheelDelta * GetPageScroll) div 120;
  end else begin
    {$IFDEF EnableMsgWndLineWrap}
    // scrolling one line -> see SB_LINEDOWN and SB_LINEUP handler in WMVScroll
    ScrollTop := ScrollTop -
        (Message.WheelDelta * Mouse.WheelScrollLines) div 240;
    {$ELSE}
    // scrolling one line -> scroll half an item, see SB_LINEDOWN and SB_LINEUP
    // handler in WMVScroll
    ScrollTop := ScrollTop -
        (Message.WheelDelta * Mouse.WheelScrollLines*ItemHeight) div 240;
    {$ENDIF}
  end;
  Message.Result := 1;
end;

procedure TMessagesCtrl.WMSetFocus(var Message: TLMSetFocus);
begin
  Invalidate;
  inherited;
end;

procedure TMessagesCtrl.WMKillFocus(var Message: TLMKillFocus);
begin
  Invalidate;
  inherited;
end;

procedure TMessagesCtrl.ImageListChange(Sender: TObject);
begin
  Invalidate;
end;

procedure TMessagesCtrl.OnIdle(Sender: TObject; var Done: Boolean);
var
  View: TLMsgWndView;
  LineNumber: integer;
  i: Integer;
begin
  //debugln(['TMessagesCtrl.OnIdle fLastLoSearchText=',fLastLoSearchText,' ',UTF8LowerCase(fSearchText)]);
  for i:=0 to ViewCount-1 do begin
    View:=Views[i];
    if not View.Filter.IsEqual(ActiveFilter) then begin
      View.EnterCriticalSection;
      try
        View.Filter:=ActiveFilter;
      finally
        View.LeaveCriticalSection;
      end;
      View.RebuildLines;
      CreateSourceMarks(View,0);
      UpdateScrollBar(true);
      Invalidate;
    end;
  end;

  if fLastLoSearchText<>UTF8LowerCase(fSearchText) then begin
    fLastLoSearchText:=UTF8LowerCase(FSearchText);
    if SearchNext(fLastSearchStartView,fLastSearchStartLine,false,true,
      View,LineNumber)
    then begin
      //debugln(['TMessagesCtrl.OnIdle search text found ',LineNumber]);
      Select(View,LineNumber,true,true);
    end else begin
      //debugln(['TMessagesCtrl.OnIdle search text not found']);
    end;
    Invalidate;
  end;
  IdleConnected:=false;
end;

procedure TMessagesCtrl.OnFilterChanged(Sender: TObject);
begin
  IdleConnected:=true;
end;

function TMessagesCtrl.GetPageScroll: integer;
begin
  {$IFDEF EnableMsgWndLineWrap}
  Result:=Max(1,((ClientHeight-BorderWidth) div ItemHeight));
  {$ELSE}
  Result:=ClientHeight - ItemHeight;
  {$ENDIF}
end;

function TMessagesCtrl.GetSelectedLine: integer;
// Return the first selected line number.
begin
  if FSelectedLines.Count>0 then
    Result:=FSelectedLines[0]
  else
    Result:=-1;   // No selection.
end;

procedure TMessagesCtrl.CreateSourceMarks(View: TLMsgWndView;
  StartLineNumber: Integer);
var
  i: Integer;
begin
  if SourceMarks=nil then exit;
  for i:=StartLineNumber to View.Lines.Count-1 do
    CreateSourceMark(View.Lines[i],nil);
end;

function TMessagesCtrl.GetHeaderBackground(aToolState: TLMVToolState): TColor;
begin
  Result:=FHeaderBackground[aToolState];
end;

procedure TMessagesCtrl.CreateSourceMark(MsgLine: TMessageLine;
  aSynEdit: TSynEdit);
var
  SourceMark: TETMark;
begin
  if TLMsgViewLine(MsgLine).Mark<>nil then exit;
  if ord(MsgLine.Urgency)<ord(mluHint) then exit;
  SourceMark:=SourceMarks.CreateMark(MsgLine,aSynEdit);
  if SourceMark=nil then exit;
  TLMsgViewLine(MsgLine).Mark:=SourceMark;
end;

function TMessagesCtrl.GetUrgencyStyles(Urgency: TMessageLineUrgency
  ): TMsgCtrlUrgencyStyle;
begin
  Result:=fUrgencyStyles[Urgency];
end;

procedure TMessagesCtrl.Notification(AComponent: TComponent;
  Operation: TOperation);
begin
  inherited Notification(AComponent, Operation);
  if Operation=opRemove then begin
    if (AComponent is TLMsgWndView) and (FViews.IndexOf(AComponent)>=0) then begin
      if fLastSearchStartView=AComponent then
        fLastSearchStartView:=nil;
      if SelectedView=AComponent then
        FSelectedView:=nil;
      RemoveView(TLMsgWndView(AComponent));
    end
    else if AComponent=Images then
      Images:=nil
    else if AComponent=SourceMarks then
      SourceMarks:=nil;
  end;
end;

procedure TMessagesCtrl.Paint;
var
  LoSearchText: string;

  procedure DrawText(ARect: TRect; aTxt: string; IsSelected: boolean;
    TxtColor: TColor);
  var
    Details: TThemedElementDetails;
    TextRect: TRect;
    p: SizeInt;
    LoTxt: String;
    aLeft: Integer;
    aRight: Integer;
    LastP: Integer;
  begin
    Canvas.Font.Color:=Font.Color;
    TextRect:=ARect;
    TextRect.Right:=TextRect.Left+Canvas.TextWidth(aTxt)+2;
    if IsSelected then begin
      if (mcsFocused in FStates) or (mcoAlwaysDrawFocused in Options) then
        Details:=ThemeServices.GetElementDetails(ttItemSelected)
      else
        Details:=ThemeServices.GetElementDetails(ttItemSelectedNotFocus);
      ThemeServices.DrawElement(Canvas.Handle, Details, TextRect, nil);
      TxtColor:=clDefault;
    end else
      Details:=ThemeServices.GetElementDetails(ttItemNormal);
    if LoSearchText<>'' then begin
      LoTxt:=UTF8LowerCase(aTxt);
      p:=1;
      LastP:=1;
      while p<=length(LoTxt) do begin
        p:=PosEx(LoSearchText,LoTxt,LastP);
        if p<1 then break;
        Canvas.Brush.Color:=clHighlight;
        aLeft:=TextRect.Left+Canvas.TextWidth(copy(ATxt,1,p-1));
        aRight:=aLeft+Canvas.TextWidth(copy(ATxt,p,length(LoSearchText)));
        Canvas.FillRect(aLeft,TextRect.Top+1,aRight,TextRect.Bottom-1);
        LastP:=p+length(LoSearchText);
      end;
      Canvas.Brush.Color:=BackgroundColor;
    end;
    if TxtColor=clDefault then
      ThemeServices.DrawText(Canvas, Details, ATxt, TextRect,
        DT_CENTER or DT_VCENTER or DT_SINGLELINE or DT_NOPREFIX, 0)
    else begin
      p:=(TextRect.Top+TextRect.Bottom-Canvas.TextHeight('Mg')) div 2;
      Canvas.Font.Color:=TxtColor;
      Canvas.TextOut(TextRect.Left+2,p,ATxt);
    end;
  end;

var
  i: Integer;
  View: TLMsgWndView;
  y: Integer;
  j: Integer;
  Line: TMessageLine;
  Indent: Integer;
  NodeRect: TRect;
  ImgIndex: LongInt;
  IsSelected: Boolean;
  FirstLineIsNotSelectedMessage: Boolean;
  SecondLineIsNotSelectedMessage: Boolean;
  col: TColor;
  ImgRes: TScaledImageListResolution;
begin
  if Focused then
    Include(FStates,mcsFocused)
  else
    Exclude(FStates,mcsFocused);
  //debugln(['TMessagesCtrl.Paint ',Focused,' CanFocus=',CanFocus,' TabStop=',TabStop]);
  LUIncreaseChangeStamp64(FPaintStamp);

  // paint background
  Canvas.Brush.Color:=BackgroundColor;
  Canvas.FillRect(0,0,ClientWidth,ClientHeight);

  Indent:=BorderWidth+2;
  LoSearchText:=fLastLoSearchText;

  // paint from top to bottom
  {$IFDEF EnableMsgWndLineWrap}
  y:=-ScrollTop*ItemHeight;
  {$ELSE}
  y:=-ScrollTop;
  {$ENDIF}
  for i:=0 to ViewCount-1 do begin
    if y>ClientHeight then break;
    View:=Views[i];
    if not View.HasContent then continue;

    View.FPaintStamp:=FPaintStamp;
    View.fPaintTop:=y;

    // draw header
    if (y+ItemHeight>0) and (y<ClientHeight) then begin
      // header text
      NodeRect:=Rect(0,y,ClientWidth,y+ItemHeight);
      Canvas.Brush.Color:=HeaderBackground[View.ToolState];
      Canvas.FillRect(NodeRect);
      Canvas.Pen.Style:=psDash;
      Canvas.Line(NodeRect.Left,NodeRect.Top,NodeRect.Right,NodeRect.Top);
      Canvas.Pen.Style:=psSolid;
      DrawText(NodeRect,GetHeaderText(View),
        (fSelectedView=View) and (FSelectedLines.IndexOf(-1)>=0),TextColor);
      Canvas.Brush.Color:=BackgroundColor;
    end;
    inc(y,ItemHeight);

    // draw lines
    j:=0;
    if y<0 then begin
      j:=Min((-y) div ItemHeight,View.Lines.Count);
      inc(y,j*ItemHeight);
    end;
    FirstLineIsNotSelectedMessage:=false;
    SecondLineIsNotSelectedMessage:=false;
    while (j<View.Lines.Count) and (y<ClientHeight) do begin
      Line:=View.Lines[j];
      NodeRect:=Rect(Indent,y,ClientWidth,y+ItemHeight);
      IsSelected:=(fSelectedView=View) and (FSelectedLines.IndexOf(j)>=0);
      if not IsSelected then begin
        if (y>-ItemHeight) and (y<=0) then
          FirstLineIsNotSelectedMessage:=true
        else if (y>0) and (y<=ItemHeight) then
          SecondLineIsNotSelectedMessage:=true;
      end;
      ImgIndex:=fUrgencyStyles[Line.Urgency].ImageIndex;
      if (Images<>nil) and (mcoShowMsgIcons in Options)
      and (ImgIndex>=0) and (ImgIndex<Images.Count) then begin
        ImgRes := Images.ResolutionForControl[0, Self];
        ImgRes.Draw(Canvas,
          NodeRect.Left + 1, (NodeRect.Top + NodeRect.Bottom - Images.Height) div 2,
          ImgIndex, gdeNormal);
        inc(NodeRect.Left, ImgRes.Width+2);
      end;
      // message text
      col:=UrgencyStyles[Line.Urgency].Color;
      if col=clDefault then
        col:=TextColor;
      DrawText(NodeRect,GetLineText(Line),IsSelected,col);
      inc(y,ItemHeight);
      inc(j);
    end;
    if FirstLineIsNotSelectedMessage and SecondLineIsNotSelectedMessage then begin
      // the first two lines are normal messages, not selected
      // => paint view header hint
      NodeRect:=Rect(0,0,ClientWidth,ItemHeight div 2);
      Canvas.Brush.Color:=HeaderBackground[View.ToolState];
      Canvas.Brush.Style:=bsSolid;
      Canvas.FillRect(NodeRect);
      NodeRect:=Rect(0,NodeRect.Bottom,ClientWidth,ItemHeight);
      Canvas.GradientFill(NodeRect,HeaderBackground[View.ToolState],
        AutoHeaderBackground,gdVertical);
      Canvas.Pen.Style:=psDash;
      NodeRect:=Rect(0,0,ClientWidth,ItemHeight);
      Canvas.Line(NodeRect.Left,NodeRect.Bottom,NodeRect.Right,NodeRect.Bottom);
      Canvas.Pen.Style:=psSolid;
      DrawText(NodeRect,'...'+GetHeaderText(View),false,TextColor);
      Canvas.Brush.Color:=BackgroundColor;
    end;
    inc(y,ItemHeight*(View.Lines.Count-j));

    // draw progress line
    if View.ProgressLine.Msg<>'' then begin
      if (y+ItemHeight>0) and (y<ClientHeight) then begin
        // progress text
        NodeRect:=Rect(Indent,y,ClientWidth,y+ItemHeight);
        col:=UrgencyStyles[View.ProgressLine.Urgency].Color;
        if col=clDefault then
          col:=TextColor;
        DrawText(NodeRect,View.ProgressLine.Msg,
          (fSelectedView=View) and (FSelectedLines.IndexOf(View.Lines.Count)>=0),col);
      end;
      inc(y,ItemHeight);
    end;

    View.fPaintBottom:=y;
  end;

  // call OnPaint
  inherited Paint;
end;

procedure TMessagesCtrl.UpdateScrollBar(InvalidateScrollMax: boolean);
var
  ScrollInfo: TScrollInfo;
begin
  if InvalidateScrollMax then begin
    fScrollTopMax:=-1;
  end;
  if not HandleAllocated then exit;

  ScrollInfo.cbSize := SizeOf(ScrollInfo);
  ScrollInfo.fMask := SIF_ALL or SIF_DISABLENOSCROLL;
  ScrollInfo.nMin := 0;
  ScrollInfo.nTrackPos := 0;
  ScrollInfo.nMax := ScrollTopMax+ClientHeight-1;
  if ClientHeight < 2 then
    ScrollInfo.nPage := 1
  else
    ScrollInfo.nPage := ClientHeight-1;
  if ScrollTop > ScrollTopMax then
    ScrollTop := ScrollTopMax;
  ScrollInfo.nPos := ScrollTop;
  //debugln(['TMessagesCtrl.UpdateScrollBar ScrollTop=',ScrollTop,' ScrollTopMax=',ScrollTopMax]);
  ShowScrollBar(Handle, SB_VERT, True);
  SetScrollInfo(Handle, SB_VERT, ScrollInfo, false);
end;

procedure TMessagesCtrl.CreateWnd;
begin
  inherited CreateWnd;
  ItemHeight:=Canvas.TextHeight('Mg')+2;
  UpdateScrollBar(false);
end;

procedure TMessagesCtrl.DoSetBounds(ALeft, ATop, AWidth, AHeight: integer);
begin
  inherited DoSetBounds(ALeft, ATop, AWidth, AHeight);
  UpdateScrollBar(true);
end;
{
procedure TMessagesCtrl.MouseMove(Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseMove(Shift, X, Y);
  //Application.HideHint;
end;
}
procedure TMessagesCtrl.MouseDown(Button: TMouseButton; Shift: TShiftState;
  X, Y: Integer);
var
  View: TLMsgWndView;
  LineNumber: integer;
begin
  if not Focused and CanFocus then
    SetFocus;
  inherited MouseDown(Button, Shift, X, Y);
  if GetLineAt(Y,View,LineNumber) then begin
    if not (Button in [mbLeft,mbRight]) then Exit;
    if ssCtrl in Shift then
      AddToSelection(View,LineNumber)
    else if ssShift in Shift then
      ExtendSelection(View,LineNumber)
    else begin
      if (Button=mbLeft)
      or (View<>SelectedView) or (FSelectedLines.IndexOf(LineNumber)=-1) then
      begin
        Select(View,LineNumber,true,true);
        StoreSelectedAsSearchStart;
      end;
      if (Button=mbRight) then Exit;
      if ((ssDouble in Shift) and (not (mcoSingleClickOpensFile in FOptions)))
      or ((mcoSingleClickOpensFile in FOptions) and ([ssDouble,ssTriple,ssQuad]*Shift=[]))
      then
        OpenSelection;
    end;
  end;
end;

procedure TMessagesCtrl.KeyDown(var Key: Word; Shift: TShiftState);
begin
  inherited KeyDown(Key, Shift);

  case Key of

  VK_DOWN:
    begin
      SelectNextShown(+1);
      Key:=VK_UNKNOWN;
    end;

  VK_UP:
    begin
      SelectNextShown(-1);
      Key:=VK_UNKNOWN;
    end;

  VK_HOME:
    begin
      SelectFirst(true,true);
      Key:=VK_UNKNOWN;
    end;

  VK_END:
    begin
      SelectLast(true,true);
      Key:=VK_UNKNOWN;
    end;

  VK_PRIOR: // Page Up
    begin
      SelectNextShown(-Max(1,ClientHeight div ItemHeight));
      Key:=VK_UNKNOWN;
    end;

  VK_NEXT: // Page Down
    begin
      SelectNextShown(Max(1,ClientHeight div ItemHeight));
      Key:=VK_UNKNOWN;
    end;
  end;
end;

procedure TMessagesCtrl.DoOnShowHint(HintInfo: PHintInfo);
var
  View: TLMsgWndView;
  Line: integer;
  MsgLine: TMessageLine;
  s: String;
begin
  if GetLineAt(HintInfo^.CursorPos.Y,View,Line) then begin
    MsgLine:=nil;
    s:='';
    if Line<0 then
      s:=GetHeaderText(View)
    else if Line<View.Lines.Count then begin
      MsgLine:=View.Lines[Line];
    end else begin
      MsgLine:=View.ProgressLine;
    end;
    if MsgLine<>nil then begin
      s:=GetLineText(MsgLine);
      s+=LineEnding+LineEnding;
      s+=ExternalToolList.GetMsgHint(MsgLine.SubTool,MsgLine.MsgID);
    end;
    HintInfo^.HintStr:=s;
    HintInfo^.ReshowTimeout:=0;
    HintInfo^.HideTimeout:=5000;
  end;
  inherited DoOnShowHint(HintInfo);
end;

procedure TMessagesCtrl.DoAllViewsStopped;
{off $DEFINE VerboseMsgFrame}

  {$IFDEF VerboseMsgFrame}
  procedure DbgViews;
  var
    i, j: Integer;
    View: TLMsgWndView;
    Tool: TAbstractExternalTool;
    SrcMsg: TMessageLine;
  begin
    debugln(['TMessagesCtrl.DoAllViewsStopped ']);
    debugln(['DbgViews===START========================================']);
    for i:=0 to ViewCount-1 do
    begin
      View:=Views[i];
      View.RebuildLines;
      Tool:=View.Tool;
      if Tool=nil then continue;
      debugln(['DbgViews ',i,'/',ViewCount,' Tool.Title=',Tool.Title]);
      Tool.EnterCriticalSection; // lock Tool before View
      try
        View.EnterCriticalSection;
        try
          for j:=0 to Tool.WorkerMessages.Count-1 do begin
            SrcMsg:=Tool.WorkerMessages[j];
            debugln(['WorkerMsg ',SrcMsg.Filename,'(',SrcMsg.Line,',',SrcMsg.Column,') ',UrgencyToStr(SrcMsg.Urgency),'/',SrcMsg.SubTool,': ',SrcMsg.Msg]);
          end;
          for j:=0 to View.Lines.Count-1 do begin
            SrcMsg:=View.Lines[j];
            debugln(['ViewMsg ',SrcMsg.Filename,'(',SrcMsg.Line,',',SrcMsg.Column,') ',UrgencyToStr(SrcMsg.Urgency),'/',SrcMsg.SubTool,': ',SrcMsg.Msg]);
          end;
        finally
          View.LeaveCriticalSection;
        end;
      finally
        Tool.LeaveCriticalSection;
      end;
    end;
    debugln(['DbgViews===END==========================================']);
  end;
  {$ENDIF}

var
  CurLine: TMessageLine;
begin
  if Assigned(OnAllViewsStopped) then
    OnAllViewsStopped(Self);
  if mcoAutoOpenFirstError in Options then begin
    CurLine:=GetSelectedMsg;
    if (CurLine<>nil) and (CurLine.Urgency>=mluError)
    and CurLine.HasSourcePosition then
      exit;
    if SelectFirstUrgentMessage(mluError,true) then
      OpenSelection;
  end;
  {$IFDEF VerboseMsgFrame}
  DbgViews;
  {$ENDIF}
end;

function TMessagesCtrl.SearchNext(StartView: TLMsgWndView; StartLine: integer;
  SkipStart, Downwards: boolean; out View: TLMsgWndView; out LineNumber: integer
  ): boolean;
var
  CurView: TLMsgWndView;
  CurLine: Integer;
  CurViewLineCnt: integer;
  Txt: String;

  function Next: boolean;
  var
    i: Integer;
  begin
    if Downwards then begin
      inc(CurLine);
      if CurLine>=CurViewLineCnt then begin
        i:=IndexOfView(CurView);
        repeat
          inc(i);
          if i>=ViewCount then exit(false);
          CurView:=Views[i];
        until CurView.HasContent;
        CurLine:=-1;
        CurViewLineCnt:=CurView.GetShownLineCount(true,true);
      end;
    end else begin
      dec(CurLine);
      if CurLine<-1 then begin
        i:=IndexOfView(CurView);
        repeat
          dec(i);
          if i<0 then exit(false);
          CurView:=Views[i];
        until CurView.HasContent;
        CurViewLineCnt:=CurView.GetShownLineCount(true,true);
        CurLine:=CurViewLineCnt-1;
      end;
    end;
    Result:=true;
  end;

begin
  Result:=false;
  View:=nil;
  LineNumber:=-1;
  if ViewCount=0 then exit;
  if StartView=nil then begin
    // use default start
    if Downwards then begin
      StartView:=Views[0];
      StartLine:=-1;
    end else begin
      StartView:=Views[ViewCount-1];
      StartLine:=StartView.GetShownLineCount(true,true);
    end;
  end;
  CurView:=StartView;
  CurLine:=StartLine;
  CurViewLineCnt:=CurView.GetShownLineCount(true,true);
  // skip invalid line numbers
  if CurLine<-1 then begin
    SkipStart:=false;
    if Downwards then
      CurLine:=-1
    else if not Next then
      exit;
  end else if CurLine>=CurViewLineCnt then begin
    SkipStart:=false;
    if Downwards then begin
      if not Next then exit;
    end else
      CurLine:=CurViewLineCnt-1;
  end;
  // skip invalid views
  if not CurView.HasContent then begin
    SkipStart:=false;
    if not Next then exit;
  end;
  // skip start
  if SkipStart then
    if not Next then exit;
  // search
  repeat
    if CurLine<0 then
      Txt:=GetHeaderText(CurView)
    else if CurLine<CurView.Lines.Count then
      Txt:=GetLineText(CurView.Lines[CurLine])
    else
      Txt:=CurView.ProgressLine.Msg;
    Txt:=UTF8LowerCase(Txt);
    if Pos(fLastLoSearchText,Txt)>0 then begin
      View:=CurView;
      LineNumber:=CurLine;
      exit(true);
    end;
  until not Next;
end;

procedure TMessagesCtrl.AddToSelection(View: TLMsgWndView; LineNumber: integer);
var
  i: Integer;
begin
  BeginUpdate;
  SelectedView:=View;
  if FSelectedLines.Count=0 then        // No existing selection.
    i:=-1
  else
    i:=FSelectedLines.IndexOf(LineNumber);
  if i=-1 then
    FSelectedLines.Add(LineNumber)
  else
    FSelectedLines.Delete(i);          // Was already selected -> toggle.
  Invalidate;
  EndUpdate;
end;

procedure TMessagesCtrl.ExtendSelection(View: TLMsgWndView; LineNumber: integer);
var
  i: Integer;
  Empty: Boolean;
begin
  BeginUpdate;
  SelectedView:=View;
  Empty:=FSelectedLines.Count=0;
  FSelectedLines.Count:=1; // Delete possible earlier selections except first one.
  if Empty then
    FSelectedLines[0]:=LineNumber  // No earlier selection.
  else if LineNumber<FSelectedLines[0] then
    for i:=LineNumber to FSelectedLines[0]-1 do
      FSelectedLines.Add(i)
  else if LineNumber>FSelectedLines[0] then
    for i:=FSelectedLines[0]+1 to LineNumber do
      FSelectedLines.Add(i);
  // if LineNumber=FSelectedLines[0] then do nothing.
  Invalidate;
  EndUpdate;
end;

procedure TMessagesCtrl.Select(View: TLMsgWndView; LineNumber: integer;
  DoScroll, FullyVisible: boolean);
begin
  BeginUpdate;
  SelectedView:=View;
  SelectedLine1:=LineNumber;
  if DoScroll then
    ScrollToLine(SelectedView,LineNumber,FullyVisible);
  EndUpdate;
end;

procedure TMessagesCtrl.Select(Msg: TMessageLine; DoScroll: boolean);
begin
  BeginUpdate;
  if (Msg=nil) or (Msg.Lines=nil) or not (Msg.Lines.Owner is TLMsgWndView) then
  begin
    SelectedView:=nil;
    FSelectedLines.Clear;
    Invalidate;
  end else begin
    SelectedView:=TLMsgWndView(Msg.Lines.Owner);
    SelectedLine1:=Msg.Index;
    if DoScroll then
      ScrollToLine(SelectedView,Msg.Index,true);
  end;
  EndUpdate;
end;

function TMessagesCtrl.SelectNextOccurrence(Downwards: boolean): boolean;
var
  View: TLMsgWndView;
  LineNumber: integer;
begin
  StoreSelectedAsSearchStart;
  Result:=SearchNext(SelectedView,SelectedLine1,true,Downwards,View,LineNumber);
  if not Result then exit;
  Select(View,LineNumber,true,true);
end;

function TMessagesCtrl.SelectNextShown(Offset: integer): boolean;
// returns true if selection changed
var
  View: TLMsgWndView;
  Line: Integer;
  i: Integer;
begin
  Result:=false;
  {$IFDEF VerboseMsgCtrlSelectNextShown}
  debugln(['TMessagesCtrl.SelectNextShown START']);
  {$ENDIF}
  while Offset<>0 do begin
    {$IFDEF VerboseMsgCtrlSelectNextShown}
    debugln(['TMessagesCtrl.SelectNextShown LOOP Offset=',Offset,
             ' ViewIndex=',IndexOfView(SelectedView),' Line=',SelectedLine]);
    {$ENDIF}
    if SelectedView=nil then begin
      if Offset>0 then begin
        SelectFirst(true,true);
        dec(Offset);
      end else begin
        SelectLast(true,true);
        Inc(Offset);
      end;
      Result:=true;
    end else begin
      View:=SelectedView;
      Line:=SelectedLine1;
      if Offset>0 then begin
        {$IFDEF VerboseMsgCtrlSelectNextShown}
        debugln(['TMessagesCtrl.SelectNextShown NEXT View.GetShownLineCount(false,true)=',
                 View.GetShownLineCount(false,true),' ViewIndex=',IndexOfView(View),' Line=',Line]);
        {$ENDIF}
        inc(Line,Offset);
        if Line<View.GetShownLineCount(false,true) then
          Offset:=0
        else begin
          // next view
          Offset:=Line-View.GetShownLineCount(false,true);
          i:=IndexOfView(View);
          {$IFDEF VerboseMsgCtrlSelectNextShown}
          debugln(['TMessagesCtrl.SelectNextShown Line=',Line,' Offset=',Offset,' ViewIndex=',i]);
          {$ENDIF}
          repeat
            inc(i);
            if i>=ViewCount then begin
              {$IFDEF VerboseMsgCtrlSelectNextShown}
              debugln(['TMessagesCtrl.SelectNextShown can not go further down']);
              {$ENDIF}
              exit;
            end;
            View:=Views[i];
          until View.HasContent;
          Line:=-1;
        end;
      end else begin
        inc(Line,Offset);
        if Line>=-1 then
          Offset:=0
        else begin
          // previous view
          Offset:=Line+2;
          i:=IndexOfView(View);
          repeat
            dec(i);
            if i<0 then begin
              {$IFDEF VerboseMsgCtrlSelectNextShown}
              debugln(['TMessagesCtrl.SelectNextShown can not go further up']);
              {$ENDIF}
              exit;
            end;
            View:=Views[i];
          until View.HasContent;
          Line:=View.GetShownLineCount(true,true)-1;
        end;
      end;
      {$IFDEF VerboseMsgCtrlSelectNextShown}
      debugln(['TMessagesCtrl.SelectNextShown SELECT Offset=',Offset,' ViewIndex=',IndexOfView(View),' Line=',Line]);
      {$ENDIF}
      Select(View,Line,true,true);
      Result:=true;
    end;
  end;
  {$IFDEF VerboseMsgCtrlSelectNextShown}
  debugln(['TMessagesCtrl.SelectNextShown END ViewIndex=',IndexOfView(SelectedView),' Line=',SelectedLine]);
  {$ENDIF}
end;

function TMessagesCtrl.SelectLast(DoScroll, FullyVisible: boolean): boolean;
var
  i: Integer;
begin
  i:=ViewCount-1;
  while (i>=0) do begin
    if Views[i].HasContent then begin
      Select(Views[i],Views[i].GetShownLineCount(true,true)-1,DoScroll,FullyVisible);
      exit(true);
    end;
    dec(i);
  end;
  Result:=false;
end;

function TMessagesCtrl.SelectFirst(DoScroll, FullyVisible: boolean): boolean;
var
  i: Integer;
begin
  i:=0;
  while (i<ViewCount) do begin
    if Views[i].HasContent then begin
      Select(Views[i],-1,DoScroll,FullyVisible);
      exit(true);
    end;
    inc(i);
  end;
  Result:=false;
end;

function TMessagesCtrl.GetSelectedMsg: TMessageLine;
// Return the first selected message.
var
  View: TLMsgWndView;
  Line: Integer;
begin
  Result:=nil;
  View:=SelectedView;
  if View=nil then exit;
  Line:=SelectedLine1;
  if (Line<0) then exit;
  if Line<View.Lines.Count then
    Result:=View.Lines[Line]
  else if View.ProgressLine.Msg<>'' then begin
    Assert((Line=View.Lines.Count), 'TMessagesCtrl.GetSelectedMsg: Line is too big.');
    Result:=View.ProgressLine;
  end;
end;

function TMessagesCtrl.SearchNextUrgent(StartView: TLMsgWndView;
  StartLine: integer; SkipStart, Downwards: boolean;
  aMinUrgency: TMessageLineUrgency; WithSrcPos: boolean; out
  View: TLMsgWndView; out LineNumber: integer): boolean;
var
  CurView: TLMsgWndView;
  CurLine: Integer;
  CurViewLineCnt: integer;
  MsgLine: TMessageLine;

  function Next: boolean;
  var
    i: Integer;
  begin
    if Downwards then begin
      inc(CurLine);
      if CurLine>=CurViewLineCnt then begin
        i:=IndexOfView(CurView);
        repeat
          inc(i);
          if i>=ViewCount then exit(false);
          CurView:=Views[i];
        until CurView.HasContent;
        CurLine:=-1;
        CurViewLineCnt:=CurView.GetShownLineCount(true,true);
      end;
    end else begin
      dec(CurLine);
      if CurLine<-1 then begin
        i:=IndexOfView(CurView);
        repeat
          dec(i);
          if i<0 then exit(false);
          CurView:=Views[i];
        until CurView.HasContent;
        CurViewLineCnt:=CurView.GetShownLineCount(true,true);
        CurLine:=CurViewLineCnt-1;
      end;
    end;
    Result:=true;
  end;

begin
  Result:=false;
  View:=nil;
  LineNumber:=-1;
  if ViewCount=0 then exit;
  if StartView=nil then begin
    // use default start
    if Downwards then begin
      StartView:=Views[0];
      StartLine:=-1;
    end else begin
      StartView:=Views[ViewCount-1];
      StartLine:=StartView.GetShownLineCount(true,true);
    end;
  end;
  CurView:=StartView;
  CurLine:=StartLine;
  CurViewLineCnt:=CurView.GetShownLineCount(true,true);
  // skip invalid line numbers
  if CurLine<-1 then begin
    SkipStart:=false;
    if Downwards then
      CurLine:=-1
    else if not Next then
      exit;
  end else if CurLine>=CurViewLineCnt then begin
    SkipStart:=false;
    if Downwards then begin
      if not Next then exit;
    end else
      CurLine:=CurViewLineCnt-1;
  end;
  // skip invalid views
  if not CurView.HasContent then begin
    SkipStart:=false;
    if not Next then exit;
  end;
  // skip start
  if SkipStart then
    if not Next then exit;
  // search
  repeat
    if (CurLine>=0) and (CurLine<CurView.Lines.Count) then begin
      MsgLine:=CurView.Lines[CurLine];
      if MsgLine.Urgency>=aMinUrgency then begin
        if (not WithSrcPos) or MsgLine.HasSourcePosition then begin
          View:=CurView;
          LineNumber:=CurLine;
          exit(true);
        end;
      end;
    end;
  until not Next;
end;

function TMessagesCtrl.SelectFirstUrgentMessage(
  aMinUrgency: TMessageLineUrgency; WithSrcPos: boolean): boolean;
var
  View: TLMsgWndView;
  LineNumber: integer;
begin
  Result:=false;
  if ViewCount=0 then exit;
  if not SearchNextUrgent(nil,0,false,true,aMinUrgency,WithSrcPos,View,LineNumber)
  then exit;
  Select(View,LineNumber,true,true);
  Result:=true;
end;

function TMessagesCtrl.SelectNextUrgentMessage(aMinUrgency: TMessageLineUrgency;
  WithSrcPos: boolean; Downwards: boolean): boolean;
var
  View: TLMsgWndView;
  LineNumber: integer;
begin
  Result:=false;
  if not SearchNextUrgent(SelectedView,SelectedLine1,true,Downwards,
    aMinUrgency,WithSrcPos,View,LineNumber)
  then exit;
  Select(View,LineNumber,true,true);
  Result:=true;
end;

function TMessagesCtrl.IsLineVisible(View: TLMsgWndView; LineNumber: integer): boolean;
var
  y: Integer;
begin
  Result:=false;
  if View=nil then exit;
  y:=GetLineTop(View,LineNumber,true);
  if (y+ItemHeight>0) and (y<ClientHeight) then
    Result:=true;
end;

function TMessagesCtrl.IsLastLineVisible(View: TLMsgWndView): boolean;
var
  LineNumber: Integer;
begin
  LineNumber:=View.GetShownLineCount(false,true)-1;
  Result:=IsLineVisible(View,LineNumber);
end;

function TMessagesCtrl.GetLineText(Line: TMessageLine): string;
begin
  // 'filename(line,column) '
  case FilenameStyle of
  mwfsShort: Result:=Line.GetShortFilename;
  mwfsRelative: Result:=Line.GetRelativeFilename
  else Result:=Line.GetFullFilename;
  end;
  if Line.Line>0 then begin
    Result+='('+IntToStr(Line.Line)+','+IntToStr(Line.Column)+')';
  end;
  if Result<>'' then
    Result+=' ';

  // 'error: '
  if Line.Urgency<>mluImportant then
    Result+=UrgencyToStr(Line.Urgency)+': ';

  // message id
  if (mcoShowMessageID in Options) and (Line.MsgID<>0) then
   Result+='('+IntToStr(Line.MsgID)+') ';

  // message
  if (mcoShowTranslated in Options) and (Line.TranslatedMsg<>'') then
    Result+=Line.TranslatedMsg
  else
    Result+=Line.Msg;
end;

function GetStats(Lines: TMessageLines): string;
var
  ErrCnt, WarnCnt, HintCnt: Integer;
  c: TMessageLineUrgency;
begin
  Result:='';
  ErrCnt:=0;
  WarnCnt:=0;
  HintCnt:=0;
  for c:=Low(Lines.UrgencyCounts) to high(Lines.UrgencyCounts) do begin
    //debugln(['GetStats cat=',dbgs(c),' count=',Lines.UrgencyCounts[c]]);
    if c>=mluError then
      inc(ErrCnt,Lines.UrgencyCounts[c])
    else if c=mluWarning then
      inc(WarnCnt,Lines.UrgencyCounts[c])
    else if c in [mluHint,mluNote] then
      inc(HintCnt,Lines.UrgencyCounts[c]);
  end;
  if ErrCnt>0 then
    Result+=Format(lisErrors2, [IntToStr(ErrCnt)]);
  if WarnCnt>0 then
    Result+=Format(lisWarnings, [IntToStr(WarnCnt)]);
  if HintCnt>0 then
    Result+=Format(lisHints, [IntToStr(HintCnt)]);
end;

function TMessagesCtrl.GetHeaderText(View: TLMsgWndView): string;
begin
  Result:=View.Caption;
  if Result='' then
    Result:=lisMenuViewMessages;
  if View.SummaryMsg<>'' then
    Result+=': '+View.SummaryMsg;
  if mcoShowStats in Options then begin
    Result+=GetStats(View.Lines);
  end;
end;

function TMessagesCtrl.FindUnfinishedView: TLMsgWndView;
var
  i: Integer;
begin
  for i:=0 to ViewCount-1 do begin
    Result:=Views[i];
    //debugln(['TMessagesCtrl.FindUnfinishedView ',i,' ',ViewCount,' caption="',Result.Caption,'" Result.Tool=',dbgsname(Result.Tool)]);
    if not Result.HasFinished then exit;
  end;
  Result:=nil;
end;

function TMessagesCtrl.GetLastViewWithContent: TLMsgWndView;
var
  i: Integer;
begin
  i:=ViewCount-1;
  while i>=0 do begin
    Result:=Views[i];
    if Result.HasContent then exit;
    dec(i);
  end;
  Result:=nil;
end;

procedure TMessagesCtrl.ScrollToLine(View: TLMsgWndView; LineNumber: integer;
  FullyVisible: boolean);
var
  y: Integer;
  MinScrollTop: integer;
  MaxScrollTop: Integer;
begin
  {$IFDEF EnableMsgWndLineWrap}
  {$ELSE}
  y:=GetLineTop(View,LineNumber,false);
  if FullyVisible then begin
    MinScrollTop:=Max(0,y+ItemHeight-ClientHeight);
    MaxScrollTop:=y;
  end else begin
    MinScrollTop:=Max(0,y-1-ClientHeight);
    MaxScrollTop:=y+ItemHeight-1;
  end;
  {$ENDIF}
  //debugln(['TMessagesCtrl.ScrollToLine ',LineNumber,' y=',y,' Min=',MinScrollTop,' Max=',MaxScrollTop]);
  y:=Max(Min(ScrollTop,MaxScrollTop),MinScrollTop);
  //debugln(['TMessagesCtrl.ScrollToLine y=',y,' ScrollTopMax=',ScrollTopMax]);
  ScrollTop:=y;
end;

function TMessagesCtrl.GetLineTop(View: TLMsgWndView; LineNumber: integer;
  Scrolled: boolean): integer;
var
  i: Integer;
  CurView: TLMsgWndView;
begin
  Result:=0;
  if View=nil then exit;
  for i:=0 to ViewCount-1 do begin
    CurView:=Views[i];
    if CurView=View then break;
    inc(Result,ItemHeight*CurView.GetShownLineCount(true,true));
  end;
  if LineNumber<0 then begin
    // header
  end else if LineNumber<View.Lines.Count then begin
    // normal messages
    inc(Result,(LineNumber+1)*ItemHeight);
  end else begin
    // last line
    inc(Result,(View.Lines.Count+1)*ItemHeight);
  end;
  if Scrolled then
    dec(Result,ScrollTop);
end;

constructor TMessagesCtrl.Create(AOwner: TComponent);
var
  u: TMessageLineUrgency;
begin
  inherited Create(AOwner);
  ControlStyle:=ControlStyle-[csCaptureMouse]+[csReflector];
  FOptions:=MCDefaultOptions;
  Filters.OnChanged:=@OnFilterChanged;
  FActiveFilter:=Filters[0];
  FViews:=TFPList.Create;
  FSelectedLines:=TIntegerList.Create;
  FUpdateTimer:=TTimer.Create(Self);
  FUpdateTimer.Name:='MsgUpdateTimer';
  FUpdateTimer.Interval:=200;
  FUpdateTimer.OnTimer:=@MsgUpdateTimerTimer;
  FItemHeight:=20;
  FSelectedView:=nil;
  BorderWidth:=0;
  fBackgroundColor:=MsgWndDefBackgroundColor;
  FHeaderBackground[lmvtsRunning]:=MsgWndDefHeaderBackgroundRunning;
  FHeaderBackground[lmvtsSuccess]:=MsgWndDefHeaderBackgroundSuccess;
  FHeaderBackground[lmvtsFailed]:=MsgWndDefHeaderBackgroundFailed;
  FAutoHeaderBackground:=MsgWndDefAutoHeaderBackground;
  FTextColor:=MsgWndDefTextColor;
  TabStop:=True;
  ParentColor:=False;
  FImageChangeLink:=TChangeLink.Create;
  FImageChangeLink.OnChange:=@ImageListChange;
  for u:=Low(TMessageLineUrgency) to high(TMessageLineUrgency) do
    fUrgencyStyles[u]:=TMsgCtrlUrgencyStyle.Create(Self,u);
  ShowHint:=true;
end;

destructor TMessagesCtrl.Destroy;
var
  u: TMessageLineUrgency;
begin
  IdleConnected:=false;
  Images:=nil;
  ClearViews(false);

  FreeAndNil(FSelectedLines);
  FreeAndNil(FViews);
  FreeAndNil(FUpdateTimer);
  FreeAndNil(FImageChangeLink);
  for u:=Low(TMessageLineUrgency) to high(TMessageLineUrgency) do
    FreeAndNil(fUrgencyStyles[u]);
  inherited Destroy;
end;

procedure TMessagesCtrl.BeginUpdate;
begin
  inc(fUpdateLock);
end;

procedure TMessagesCtrl.EndUpdate;
begin
  if fUpdateLock=0 then
    raise Exception.Create('');
  dec(fUpdateLock);
end;

procedure TMessagesCtrl.EraseBackground(DC: HDC);
begin
  // everything is painted, so erasing the background is not needed
end;

procedure TMessagesCtrl.ApplyEnvironmentOptions;
var
  NewOptions: TMsgCtrlOptions;
  u: TMessageLineUrgency;

  procedure SetOption(Option: TMsgCtrlOption; State: boolean);
  begin
    if State then
      NewOptions:=NewOptions+[Option]
    else
      NewOptions:=NewOptions-[Option];
  end;

begin
  for u in TMessageLineUrgency do
    UrgencyStyles[u].Color:=EnvironmentOptions.MsgColors[u];
  BackgroundColor:=EnvironmentOptions.MsgViewColors[mwBackground];
  AutoHeaderBackground:=EnvironmentOptions.MsgViewColors[mwAutoHeader];
  HeaderBackground[lmvtsRunning]:=EnvironmentOptions.MsgViewColors[mwRunning];
  HeaderBackground[lmvtsSuccess]:=EnvironmentOptions.MsgViewColors[mwSuccess];
  HeaderBackground[lmvtsFailed]:=EnvironmentOptions.MsgViewColors[mwFailed];
  TextColor:=EnvironmentOptions.MsgViewColors[mwTextColor];
  NewOptions:=Options;
  SetOption(mcoSingleClickOpensFile,not EnvironmentOptions.MsgViewDblClickJumps);
  SetOption(mcoShowMsgIcons,EnvironmentOptions.ShowMessagesIcons);
  SetOption(mcoShowTranslated,EnvironmentOptions.MsgViewShowTranslations);
  SetOption(mcoAlwaysDrawFocused,EnvironmentOptions.MsgViewAlwaysDrawFocused);
  Options:=NewOptions;
  FilenameStyle:=EnvironmentOptions.MsgViewFilenameStyle;
end;

function TMessagesCtrl.IndexOfView(View: TLMsgWndView): integer;
begin
  Result:=FViews.IndexOf(View);
end;

procedure TMessagesCtrl.ClearViews(OnlyFinished: boolean);
var
  i: Integer;
  View: TLMsgWndView;
begin
  if OnlyFinished then begin
    for i:=ViewCount-1 downto 0 do begin
      if i>=ViewCount then continue;
      View:=Views[i];
      if View.HasFinished then
        View.Free;
    end;
  end else begin
    while ViewCount>0 do
      Views[0].Free;
  end;
end;

procedure TMessagesCtrl.RemoveView(View: TLMsgWndView);
begin
  if FViews.IndexOf(View)<0 then exit;
  FViews.Remove(View);
  View.FControl:=nil;
  View.OnChanged:=nil;
  if fLastSearchStartView=View then
    fLastSearchStartView:=nil;
  if SelectedView=View then
    SelectedView:=nil;
  UpdateScrollBar(true);
  Invalidate;
end;

function TMessagesCtrl.GetView(aCaption: string; CreateIfNotExist: boolean
  ): TLMsgWndView;
var
  i: Integer;
begin
  for i:=0 to ViewCount-1 do begin
    Result:=Views[i];
    if UTF8CompareStr(aCaption,Result.Caption)=0 then exit;
  end;
  if not CreateIfNotExist then
    exit(nil);
  Result:=TLMsgWndView.Create(Self);
  Result.FControl:=Self;
  Result.Caption:=aCaption;
  Result.Filter.Assign(ActiveFilter);
  FViews.Add(Result);
  FreeNotification(Result);
  Result.OnChanged:=@OnViewChanged;
  fSomeViewsRunning:=true;
end;

function TMessagesCtrl.GetLineAt(Y: integer; out View: TLMsgWndView;
  out Line: integer): boolean;
var
  i: Integer;
begin
  for i:=0 to ViewCount-1 do begin
    View:=Views[i];
    if View.FPaintStamp<>FPaintStamp then continue;
    if (View.fPaintTop>Y) or (View.fPaintBottom<Y) then continue;
    Line:=((Y-View.fPaintTop) div ItemHeight)-1;
    Result:=true;
    exit;
  end;
  View:=nil;
  Line:=-1;
  Result:=false;
end;

function TMessagesCtrl.ScrollLeftMax: integer;
begin
  Result:=0;
end;

function TMessagesCtrl.ScrollTopMax: integer;
var
  i: Integer;
  View: TLMsgWndView;
begin
  if fScrollTopMax<0 then begin
    fScrollTopMax:=0;
    for i:=0 to ViewCount-1 do begin
      View:=Views[i];
      inc(fScrollTopMax,View.GetShownLineCount(true,true)*ItemHeight);
    end;
    fScrollTopMax:=Max(0,fScrollTopMax-ClientHeight);
  end;
  Result:=fScrollTopMax;
end;

procedure TMessagesCtrl.StoreSelectedAsSearchStart;
begin
  fLastLoSearchText:=UTF8LowerCase(FSearchText);
  fLastSearchStartView:=FSelectedView;
  fLastSearchStartLine:=SelectedLine1;
end;

function TMessagesCtrl.OpenSelection: boolean;
var
  Msg: TMessageLine;
begin
  Result:=false;
  if not Assigned(OnOpenMessage) then exit;
  Msg:=GetSelectedMsg;
  if Msg=nil then exit;
  Result:=OnOpenMessage(Self,Msg);
end;

procedure TMessagesCtrl.CreateMarksForFile(aSynEdit: TSynEdit;
  aFilename: string; DeleteOld: boolean);
var
  i: Integer;
  Lines: TMessageLines;
  Line: TMessageLine;
begin
  if DeleteOld then
    SourceMarks.RemoveMarks(aSynEdit);
  for i:=0 to ViewCount-1 do begin
    Lines:=Views[i].Lines;
    for Line in Lines.EnumerateFile(aFilename,0,High(Integer)) do begin
      //debugln(['TMessagesCtrl.CreateMarksForFile ',GetLineText(Line)]);
      CreateSourceMark(Line,aSynEdit);
    end;
  end;
end;

function TMessagesCtrl.ApplySrcChanges(Changes: TETSingleSrcChanges): boolean;
var
  i: Integer;
begin
  Result:=false;
  //debugln(['TMessagesCtrl.ApplySrcChanges ViewCount=',ViewCount]);
  for i:=0 to ViewCount-1 do
    if Views[i].ApplySrcChanges(Changes) then
      Result:=true;
  if Result then
    Invalidate;
end;

{ TMessagesFrame }

procedure TMessagesFrame.MsgCtrlPopupMenuPopup(Sender: TObject);

  procedure UpdateRemoveCompOptHideMsgItems;
  var
    i: Integer;
    View: TLMsgWndView;
    ToolData: TIDEExternalToolData;
    IDETool: TObject;
    CompOpts: TBaseCompilerOptions;
    Flag: PCompilerMsgIdFlag;
    Pattern: String;
    Pkg: TIDEPackage;
    Cnt: Integer;
    Item: TIDEMenuCommand;
    ModuleName: String;
  begin
    // create one menuitem per compiler option
    Cnt:=0;
    for i:=0 to ViewCount-1 do begin
      View:=Views[i];
      if View.Tool=nil then continue;
      ToolData:=TIDEExternalToolData(View.Tool.Data);
      if not (ToolData is TIDEExternalToolData) then continue;
      IDETool:=ExternalToolList.GetIDEObject(ToolData);
      if IDETool=nil then continue;
      if IDETool is TLazProject then begin
        CompOpts:=TLazProject(IDETool).LazCompilerOptions as TBaseCompilerOptions;
        ModuleName:=lisProjectOption;
      end else if IDETool is TIDEPackage then begin
        Pkg:=TIDEPackage(IDETool);
        CompOpts:=Pkg.LazCompilerOptions as TBaseCompilerOptions;
        ModuleName:=Format(lisPackageOption, [Pkg.Name]);
      end else
        continue;
      for Flag in CompOpts.IDEMessageFlags do begin
        if Flag^.Flag<>cfvHide then continue;
        if Cnt>=MsgRemoveCompOptHideMenuSection.Count then begin
          Item:=RegisterIDEMenuCommand(MsgRemoveCompOptHideMenuSection,'RemoveCompOptHideMsg'+IntToStr(Cnt),'');
          Item.OnClick:=@RemoveCompOptHideMsgClick;
        end else begin
          Item:=MsgRemoveCompOptHideMenuSection.Items[Cnt] as TIDEMenuCommand;
        end;
        Item.Tag:=Flag^.MsgId;
        Item.UserTag:=PtrUInt(ToolData);
        Pattern:=GetMsgPattern(SubToolFPC,Flag^.MsgID,true,40);
        Item.Caption:=ModuleName+': '+Pattern;
        inc(Cnt);
      end;
    end;
    MsgRemoveCompOptHideMenuSection.Visible:=Cnt>0;
    // delete old menu items
    while MsgRemoveCompOptHideMenuSection.Count>Cnt do
      MsgRemoveCompOptHideMenuSection[Cnt].Free;
  end;

  procedure UpdateRemoveMsgTypeFilterItems;
  var
    FilterItem: TLMVFilterMsgType;
    i: Integer;
    Item: TIDEMenuCommand;
    Cnt: Integer;
  begin
    // create one menuitem per filter item
    Cnt:=MessagesCtrl.ActiveFilter.FilterMsgTypeCount;
    MsgRemoveMsgTypeFilterMenuSection.Visible:=Cnt>0;
    for i:=0 to Cnt-1 do begin
      if i>=MsgRemoveFilterMsgOneTypeMenuSection.Count then begin
        Item:=RegisterIDEMenuCommand(MsgRemoveFilterMsgOneTypeMenuSection,'MsgRemoveMsgOfTypeFilter'+IntToStr(i),'');
        Item.Tag:=i;
        Item.OnClick:=@RemoveFilterMsgTypeClick;
      end else
        Item:=MsgRemoveFilterMsgOneTypeMenuSection.Items[i] as TIDEMenuCommand;
      FilterItem:=MessagesCtrl.ActiveFilter.FilterMsgTypes[i];
      Item.Caption:=GetMsgPattern(FilterItem.SubTool,FilterItem.MsgID,true,40);
    end;
    // delete old menu items
    while MsgRemoveFilterMsgOneTypeMenuSection.Count>Cnt do
      MsgRemoveFilterMsgOneTypeMenuSection[Cnt].Free;
    MsgRemoveFilterAllMsgTypesMenuItem.OnClick:=@ClearFilterMsgTypesMenuItemClick;
  end;

  procedure UpdateFilterItems;
  var
    i: Integer;
    Filter: TLMsgViewFilter;
    Item: TIDEMenuCommand;
    Cnt: Integer;
  begin
    Cnt:=MessagesCtrl.Filters.Count;
    for i:=0 to Cnt-1 do begin
      Filter:=MessagesCtrl.Filters[i];
      if i>=MsgSelectFilterMenuSection.Count then begin
        Item:=RegisterIDEMenuCommand(MsgSelectFilterMenuSection,'MsgSelectFilter'+IntToStr(i),'');
        Item.Tag:=i;
        Item.OnClick:=@OnSelectFilterClick;
      end else
        Item:=MsgSelectFilterMenuSection[i] as TIDEMenuCommand;
      Item.Caption:=Filter.Caption;
      Item.Checked:=Filter=MessagesCtrl.ActiveFilter;
    end;
    // delete old menu items
    while MsgSelectFilterMenuSection.Count>Cnt do
      MsgSelectFilterMenuSection[Cnt].Free;

    MsgAddFilterMenuItem.OnClick:=@AddFilterMenuItemClick;
  end;

  procedure UpdateQuickFixes(CurLine: TMessageLine);
  begin
    // delete old
    MsgQuickFixMenuSection.Clear;
    // create items
    if CurLine<>nil then begin
      IDEQuickFixes.SetMsgLines(CurLine);
      IDEQuickFixes.OnPopupMenu(MsgQuickFixMenuSection);
    end;
    MsgQuickFixMenuSection.Visible:=MsgQuickFixMenuSection.Count>0;
  end;

var
  View: TLMsgWndView;
  MinUrgency: TMessageLineUrgency;
  ToolData: TIDEExternalToolData;
  Line: TMessageLine;
  i, LineNumber, VisibleCnt: Integer;
  HasText, HasFilename, HasViewContent, Running, CanFilterMsgType: Boolean;
  MsgType, ToolOptionsCaption: String;
begin
  MessagesMenuRoot.MenuItem:=MsgCtrlPopupMenu.Items;
  //MessagesMenuRoot.BeginUpdate;
  try
    HasText:=false;
    HasFilename:=false;
    MsgType:='';
    CanFilterMsgType:=false;
    Line:=nil;
    HasViewContent:=false;
    Running:=false;

    // check all
    for i:=0 to MessagesCtrl.ViewCount-1 do begin
      View:=MessagesCtrl.Views[i];
      if View.HasContent then
        HasViewContent:=true;
      if View.Running then
        Running:=true;
    end;

    MsgFindMenuItem.OnClick:=@FindMenuItemClick;

    // check selection
    View:=MessagesCtrl.SelectedView;
    if View<>nil then begin
      for i:=0 to MessagesCtrl.FSelectedLines.Count-1 do begin
        LineNumber:=MessagesCtrl.FSelectedLines[i];
        if LineNumber=-1 then Continue;            // header
        if LineNumber=View.Lines.Count then
          Line:=View.ProgressLine                  // progress line
        else
          Line:=View.Lines[LineNumber];            // normal messages
        if Line.Filename<>'' then
          HasFilename:=True;
        if Line.Msg<>'' then
          HasText:=True;
        if (Line.SubTool<>'') and (Line.MsgID<>0) then begin
          MsgType:=GetMsgPattern(Line.SubTool,Line.MsgID,true,40);
          CanFilterMsgType:=ord(Line.Urgency)<ord(mluError);
        end;
      end;
    end else begin
      // no line selected => use last visible View
      View:=MessagesCtrl.GetLastViewWithContent;
    end;
    ToolOptionsCaption:='';

    // About
    if View<>nil then
    begin
      MsgAboutToolMenuItem.Caption:=Format(lisAbout2, [View.Caption]);
      MsgAboutSection.Visible:=true;
      if (View.Tool<>nil) and (View.Tool.Data is TIDEExternalToolData) then begin
        ToolData:=TIDEExternalToolData(View.Tool.Data);
        if ToolData.Kind=IDEToolCompilePackage then
          ToolOptionsCaption:=Format(lisCPOpenPackage, [ToolData.ModuleName]);
      end;
    end else
      MsgAboutSection.Visible:=false;
    MsgAboutToolMenuItem.OnClick:=@AboutToolMenuItemClick;
    VisibleCnt:=1;
    MsgOpenToolOptionsMenuItem.Visible:=ToolOptionsCaption<>'';
    if MsgOpenToolOptionsMenuItem.Visible then
    begin
      inc(VisibleCnt);
      //only assign caption if it is not empty to avoid its "unlocalizing",
      //this is visible e.g. in EditorToolBar menu tree
      MsgOpenToolOptionsMenuItem.Caption:=ToolOptionsCaption;
    end
    else
      //assign default caption if item is not visible (needed for EditorToolBar)
      MsgOpenToolOptionsMenuItem.Caption:=lisOpenToolOptions;
    MsgOpenToolOptionsMenuItem.OnClick:=@OpenToolsOptionsMenuItemClick;
    MsgAboutSection.ChildrenAsSubMenu:=VisibleCnt>1;

    // Filtering
    if CanFilterMsgType then begin
      MsgFilterMsgOfTypeMenuItem.Caption:=Format(lisFilterAllMessagesOfType, [MsgType]);
      MsgFilterMsgOfTypeMenuItem.Visible:=true;
    end else begin
      //assign default caption if item is not visible (needed for EditorToolBar)
      MsgFilterMsgOfTypeMenuItem.Caption:=lisFilterAllMessagesOfCertainType;
      MsgFilterMsgOfTypeMenuItem.Visible:=false;
    end;
    MsgFilterMsgOfTypeMenuItem.OnClick:=@FilterMsgOfTypeMenuItemClick;
    MsgFilterHintsWithoutPosMenuItem.Checked:=MessagesCtrl.ActiveFilter.FilterNotesWithoutPos;
    MsgFilterHintsWithoutPosMenuItem.OnClick:=@FilterHintsWithoutPosMenuItemClick;

    MinUrgency:=MessagesCtrl.ActiveFilter.MinUrgency;
    MsgFilterNoneMenuItem.Checked:=MinUrgency in [mluNone..mluDebug];
    MsgFilterNoneMenuItem.OnClick:=@FilterUrgencyMenuItemClick;
    MsgFilterDebugMenuItem.Checked:=MinUrgency in [mluVerbose3..mluVerbose];
    MsgFilterDebugMenuItem.OnClick:=@FilterUrgencyMenuItemClick;
    MsgFilterVerboseMenuItem.Checked:=MinUrgency=mluHint;
    MsgFilterVerboseMenuItem.OnClick:=@FilterUrgencyMenuItemClick;
    MsgFilterHintsMenuItem.Checked:=MinUrgency=mluNote;
    MsgFilterHintsMenuItem.OnClick:=@FilterUrgencyMenuItemClick;
    MsgFilterNotesMenuItem.Checked:=MinUrgency in [mluWarning..mluImportant];
    MsgFilterNotesMenuItem.OnClick:=@FilterUrgencyMenuItemClick;
    MsgFilterWarningsMenuItem.Checked:=MinUrgency>=mluError;
    MsgFilterWarningsMenuItem.OnClick:=@FilterUrgencyMenuItemClick;

    // Copying
    MsgCopyMsgMenuItem.Enabled:=HasText;
    MsgCopyMsgMenuItem.OnClick:=@CopyMsgMenuItemClick;
    MsgCopyFilenameMenuItem.Enabled:=HasFilename;
    MsgCopyFilenameMenuItem.OnClick:=@CopyFilenameMenuItemClick;
    MsgCopyAllMenuItem.Enabled:=not Running;
    MsgCopyAllMenuItem.OnClick:=@CopyAllMenuItemClick;
    MsgCopyShownMenuItem.Enabled:=HasViewContent;
    MsgCopyShownMenuItem.OnClick:=@CopyShownMenuItemClick;

    // Saving
    MsgSaveAllToFileMenuItem.Enabled:=not Running;
    MsgSaveAllToFileMenuItem.OnClick:=@SaveAllToFileMenuItemClick;
    MsgSaveShownToFileMenuItem.Enabled:=HasViewContent;
    MsgSaveShownToFileMenuItem.OnClick:=@SaveShownToFileMenuItemClick;
    MsgHelpMenuItem.Enabled:=HasText;
    MsgHelpMenuItem.OnClick:=@HelpMenuItemClick;
    MsgEditHelpMenuItem.OnClick:=@EditHelpMenuItemClick;
    MsgClearMenuItem.OnClick:=@ClearMenuItemClick;
    MsgClearMenuItem.Enabled:=View<>nil;

    // Options
    MsgWndStayOnTopMenuItem.Checked:=mcoWndStayOnTop in MessagesCtrl.Options;
    MsgWndStayOnTopMenuItem.OnClick:=@WndStayOnTopMenuItemClick;
    MsgFileStyleShortMenuItem.Checked:=MessagesCtrl.FilenameStyle=mwfsShort;
    MsgFileStyleShortMenuItem.OnClick:=@FileStyleMenuItemClick;
    MsgFileStyleRelativeMenuItem.Checked:=MessagesCtrl.FilenameStyle=mwfsRelative;
    MsgFileStyleRelativeMenuItem.OnClick:=@FileStyleMenuItemClick;
    MsgFileStyleFullMenuItem.Checked:=MessagesCtrl.FilenameStyle=mwfsFull;
    MsgFileStyleFullMenuItem.OnClick:=@FileStyleMenuItemClick;

    MsgTranslateMenuItem.Checked:=mcoShowTranslated in MessagesCtrl.Options;
    MsgTranslateMenuItem.OnClick:=@TranslateMenuItemClick;
    MsgShowIDMenuItem.Checked:=mcoShowMessageID in MessagesCtrl.Options;
    MsgShowIDMenuItem.OnClick:=@ShowIDMenuItemClick;
    MsgMoreOptionsMenuItem.OnClick:=@MoreOptionsMenuItemClick;

    UpdateRemoveCompOptHideMsgItems;
    UpdateRemoveMsgTypeFilterItems;
    UpdateFilterItems;

    UpdateQuickFixes(Line);
  finally
    //MessagesMenuRoot.EndUpdate;
  end;
end;

procedure TMessagesFrame.OnSelectFilterClick(Sender: TObject);
var
  Filter: TLMsgViewFilter;
  Item: TIDEMenuCommand;
begin
  Item:=Sender as TIDEMenuCommand;
  Filter:=MessagesCtrl.Filters.GetFilter(Item.Caption,false);
  if Filter=nil then exit;
  MessagesCtrl.ActiveFilter:=Filter;
end;

procedure TMessagesFrame.OpenToolsOptionsMenuItemClick(Sender: TObject);
var
  View: TLMsgWndView;
  ToolData: TIDEExternalToolData;
begin
  View:=GetAboutView;
  if (View=nil) or (View.Tool=nil) then exit;
  ToolData:=TIDEExternalToolData(View.Tool.Data);
  if not (ToolData is TIDEExternalToolData) then exit;
  if ToolData.Kind=IDEToolCompilePackage then begin
    PackageEditingInterface.DoOpenPackageFile(ToolData.Filename,
                                              [pofAddToRecent],false);
  end;
end;

procedure TMessagesFrame.RemoveCompOptHideMsgClick(Sender: TObject);
var
  Item: TIDEMenuCommand;
  MsgId: Integer;
  ToolData: TIDEExternalToolData;
  IDETool: TObject;
  CompOpts: TLazCompilerOptions;
  Pkg: TIDEPackage;
begin
  if not (Sender is TIDEMenuCommand) then exit;
  Item:=TIDEMenuCommand(Sender);
  MsgId:=Item.Tag;
  ToolData:=TIDEExternalToolData(Item.UserTag);
  IDETool:=ExternalToolList.GetIDEObject(ToolData);
  if IDETool=nil then exit;
  if IDETool is TLazProject then begin
    CompOpts:=TLazProject(IDETool).LazCompilerOptions;
    CompOpts.MessageFlags[MsgID]:=cfvNone;
  end else if IDETool is TIDEPackage then begin
    if PackageEditingInterface.DoOpenPackageFile(ToolData.Filename,
                                        [pofAddToRecent],false)<>mrOk then exit;
    Pkg:=PackageEditingInterface.FindPackageWithName(ToolData.ModuleName);
    if Pkg=nil then exit;
    CompOpts:=Pkg.LazCompilerOptions;
    CompOpts.MessageFlags[MsgID]:=cfvNone;
  end;
end;

procedure TMessagesFrame.SaveAllToFileMenuItemClick(Sender: TObject);
begin
  SaveClicked(false);
end;

procedure TMessagesFrame.SaveShownToFileMenuItemClick(Sender: TObject);
begin
  SaveClicked(true);
end;

procedure TMessagesFrame.SearchEditChange(Sender: TObject);
var
  s: TCaption;
begin
  s:=SearchEdit.Text;
  MessagesCtrl.SearchText:=s;
end;

procedure TMessagesFrame.SearchEditKeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
  if (Key=VK_ESCAPE) then
    HideSearch;
end;

procedure TMessagesFrame.SearchNextSpeedButtonClick(Sender: TObject);
begin
  MessagesCtrl.SelectNextOccurrence(true);
end;

procedure TMessagesFrame.SearchPrevSpeedButtonClick(Sender: TObject);
begin
  MessagesCtrl.SelectNextOccurrence(false);
end;

procedure TMessagesFrame.ShowIDMenuItemClick(Sender: TObject);
begin
  if mcoShowMessageID in MessagesCtrl.Options then
    MessagesCtrl.Options:=MessagesCtrl.Options-[mcoShowMessageID]
  else
    MessagesCtrl.Options:=MessagesCtrl.Options+[mcoShowMessageID];
end;

procedure TMessagesFrame.SrcEditLinesChanged(Sender: TObject);
begin
  //debugln(['TMessagesFrame.SrcEditLinesChanged ',DbgSName(Sender)]);
  if Sender is TETSynPlugin then
    ApplySrcChanges(TETSynPlugin(Sender).Changes);
end;

procedure TMessagesFrame.TranslateMenuItemClick(Sender: TObject);
begin
  if mcoShowTranslated in MessagesCtrl.Options then
    MessagesCtrl.Options:=MessagesCtrl.Options-[mcoShowTranslated]
  else
    MessagesCtrl.Options:=MessagesCtrl.Options+[mcoShowTranslated];
  EnvironmentOptions.MsgViewShowTranslations:=mcoShowTranslated in MessagesCtrl.Options;
end;

procedure TMessagesFrame.RemoveFilterMsgTypeClick(Sender: TObject);
var
  i: PtrInt;
begin
  i:=TIDEMenuCommand(Sender).Tag;
  if i<MessagesCtrl.ActiveFilter.FilterMsgTypeCount then
    MessagesCtrl.ActiveFilter.DeleteFilterMsgType(i);
end;

procedure TMessagesFrame.WndStayOnTopMenuItemClick(Sender: TObject);
begin
  if mcoWndStayOnTop in MessagesCtrl.Options then
    MessagesCtrl.Options:=MessagesCtrl.Options-[mcoWndStayOnTop]
  else
    MessagesCtrl.Options:=MessagesCtrl.Options+[mcoWndStayOnTop];
  EnvironmentOptions.MsgViewStayOnTop:=mcoWndStayOnTop in MessagesCtrl.Options;
end;

function TMessagesFrame.AllMessagesAsString(const OnlyShown: boolean): String;
var
  Tool: TAbstractExternalTool;
  View: TLMsgWndView;
  s: String;
  i, j: Integer;
begin
  s:='';
  for i:=0 to MessagesCtrl.ViewCount-1 do begin
    View:=MessagesCtrl.Views[i];
    if OnlyShown or (View.Tool=nil) then begin
      // save shown messages
      if not View.HasContent then continue;
      s+=MessagesCtrl.GetHeaderText(View)+LineEnding;
      for j:=0 to View.Lines.Count-1 do
        s+=MessagesCtrl.GetLineText(View.Lines[j])+LineEnding;
    end else begin
      // save raw data
      if View.Running then continue;
      Tool:=View.Tool;
      Tool.EnterCriticalSection;
      try
        for j:=0 to Tool.WorkerOutput.Count-1 do
          s+=Tool.WorkerOutput[j]+LineEnding;
      finally
        Tool.LeaveCriticalSection;
      end;
    end;
  end;
  Result:=s;
end;

function TMessagesFrame.GetAboutView: TLMsgWndView;
begin
  Result:=MessagesCtrl.SelectedView;
  if Result=nil then
    Result:=MessagesCtrl.GetLastViewWithContent;
end;

procedure TMessagesFrame.CopyFilenameMenuItemClick(Sender: TObject);
begin
  CopyMsgToClipboard(true);
end;

procedure TMessagesFrame.CopyMsgMenuItemClick(Sender: TObject);
begin
  CopyMsgToClipboard(false);
end;

procedure TMessagesFrame.CopyAllMenuItemClick(Sender: TObject);
begin
  CopyAllClicked(false);
end;

procedure TMessagesFrame.CopyShownMenuItemClick(Sender: TObject);
begin
  CopyAllClicked(true);
end;

procedure TMessagesFrame.EditHelpMenuItemClick(Sender: TObject);
begin
  ShowMessageHelpEditor;
end;

procedure TMessagesFrame.FileStyleMenuItemClick(Sender: TObject);
begin
  if Sender=MsgFileStyleShortMenuItem then
    MessagesCtrl.FilenameStyle:=mwfsShort
  else if Sender=MsgFileStyleRelativeMenuItem then
    MessagesCtrl.FilenameStyle:=mwfsRelative
  else if Sender=MsgFileStyleFullMenuItem then
    MessagesCtrl.FilenameStyle:=mwfsFull;
  EnvironmentOptions.MsgViewFilenameStyle:=MessagesCtrl.FilenameStyle;
end;

procedure TMessagesFrame.FindMenuItemClick(Sender: TObject);
begin
  MessagesCtrl.StoreSelectedAsSearchStart;
  SearchPanel.Visible:=true;
  SearchEdit.SetFocus;
end;

procedure TMessagesFrame.HelpMenuItemClick(Sender: TObject);
begin
  ExecuteIDECommand(Self, ecContextHelp);
end;

procedure TMessagesFrame.FilterHintsWithoutPosMenuItemClick(Sender: TObject);
begin
  MessagesCtrl.ActiveFilter.FilterNotesWithoutPos:=not MessagesCtrl.ActiveFilter.FilterNotesWithoutPos;
end;

procedure TMessagesFrame.FilterMsgOfTypeMenuItemClick(Sender: TObject);
var
  Line: TMessageLine;
begin
  Line:=MessagesCtrl.GetSelectedMsg;
  if (Line=nil) or (ord(Line.Urgency)>=ord(mluError)) then exit;
  MessagesCtrl.ActiveFilter.AddFilterMsgType(Line.SubTool,Line.MsgID);
end;

procedure TMessagesFrame.FilterUrgencyMenuItemClick(Sender: TObject);
var
  MinUrgency: TMessageLineUrgency;
begin
  //debugln(['TMessagesFrame.FilterUrgencyMenuItemClick ',DbgSName(Sender),' ',(Sender as TIDEMenuCommand).Caption,' ',(Sender as TIDEMenuCommand).Checked]);
  if Sender=MsgFilterWarningsMenuItem then
    MinUrgency:=mluError
  else if Sender=MsgFilterNotesMenuItem then
    MinUrgency:=mluWarning
  else if Sender=MsgFilterHintsMenuItem then
    MinUrgency:=mluNote
  else if Sender=MsgFilterVerboseMenuItem then
    MinUrgency:=mluHint
  else if Sender=MsgFilterDebugMenuItem then
    MinUrgency:=mluVerbose3
  else {if Sender=MsgFilterNoneMenuItem then}
    MinUrgency:=mluNone;
  MessagesCtrl.ActiveFilter.MinUrgency:=MinUrgency;
  //debugln(['TMessagesFrame.FilterUrgencyMenuItemClick ',MessageLineUrgencyNames[MinUrgency]]);
end;

procedure TMessagesFrame.HideSearchSpeedButtonClick(Sender: TObject);
begin
  HideSearch;
end;

procedure TMessagesFrame.ImagesGetWidthForPPI(Sender: TCustomImageList;
  AImageWidth, APPI: Integer; var AResultWidth: Integer);
begin
  if (16<=AResultWidth) and (AResultWidth<=20) then
    AResultWidth := 16;
end;

procedure TMessagesFrame.MoreOptionsMenuItemClick(Sender: TObject);
begin
  LazarusIDE.DoOpenIDEOptions(TMsgWndOptionsFrame);
end;

procedure TMessagesFrame.AboutToolMenuItemClick(Sender: TObject);
var
  View: TLMsgWndView;
  Form: TForm;
  s: String;
  Tool: TAbstractExternalTool;
  Proc: TProcessUTF8;
  Memo: TMemo;
  i: Integer;
begin
  View:=GetAboutView;
  if View=nil then exit;
  s:=View.Caption+LineEnding;
  s+=LineEnding;
  Tool:=View.Tool;
  if Tool<>nil then begin
    if Tool.Hint<>'' then
      s+=Tool.Hint+LineEnding+LineEnding;
    Proc:=Tool.Process;
    if Proc<>nil then begin
      if Proc.Executable<>'' then
        s+='Executable: '+LineEnding+Proc.Executable+LineEnding+LineEnding;
      if Proc.CurrentDirectory<>'' then begin
        if Tool.CurrentDirectoryIsTestDir then
          s+='CurrentDirectory is test build directory:'
        else
          s+='CurrentDirectory:';
        s+=LineEnding+Proc.CurrentDirectory+LineEnding+LineEnding;
      end;
      if Proc.Desktop<>'' then
        s+='Desktop: '+Proc.Desktop+LineEnding;
      if Tool.EnvironmentOverrides.Text<>'' then
        s+='Environment Overrides:'+LineEnding
          +Tool.EnvironmentOverrides.Text+LineEnding;
      s+='Parameters:'+LineEnding;
      s+=Proc.Parameters.Text+LineEnding;
      s+='Command Line:'+LineEnding;
      s+=StrToCmdLineParam(Tool.Process.Executable)+' '+MergeCmdLineParams(Tool.Process.Parameters)+LineEnding+LineEnding;
      s+='Parsers: ';
      if Tool.ParserCount=0 then
        s+='none'
      else begin
        for i:=0 to Tool.ParserCount-1 do begin
          if i>0 then s+=', ';
          s+=Tool.Parsers[i].GetLocalizedParserName;
        end;
      end;
      s+=LineEnding+LineEnding;

      s+='ProcessID:'+LineEnding+IntToStr(Proc.ProcessID)+LineEnding+LineEnding;
      if Tool.Terminated then
        s+='Terminated'+LineEnding+LineEnding
      else begin
        s+='ExitCode:'+LineEnding+IntToStr(Proc.ExitCode)+LineEnding;
        s+='ExitStatus:'+LineEnding+IntToStr(Proc.ExitStatus)+LineEnding+LineEnding;
      end;
    end;
    if Tool.ErrorMessage<>'' then
      s+=lisError+Tool.ErrorMessage+LineEnding+LineEnding;
  end;

  Form:=TForm.CreateNew(Self);
  try
    with Form do begin
      Name:='AboutExtToolDlg';
      Width:=500;
      Height:=300;
      Position:=poScreenCenter;
      Caption:=Format(lisAbout2, [View.Caption]);
    end;

    Memo:=TMemo.Create(Form);
    with Memo do begin
      Name:='Memo';
      Lines.Text:=s;
      Align:=alClient;
      WordWrap:=true; // carbon requires this and it is a good idea in general
      ScrollBars:=ssVertical;
      ReadOnly:=true;
      Parent:=Form;
    end;
    Form.ShowModal;
  finally
    Form.Free;
  end;
end;

procedure TMessagesFrame.AddFilterMenuItemClick(Sender: TObject);
var
  aCaption: String;
  i: Integer;
  NewFilter: TLMsgViewFilter;
  Filters: TLMsgViewFilters;
begin
  aCaption:=lisFilter;
  i:=1;
  Filters:=MessagesCtrl.Filters;
  while Filters.GetFilter(aCaption+IntToStr(i),false)<>nil do
    inc(i);
  if not InputQuery(lisCreateFilter, lisCodeToolsDefsName, aCaption) then exit;
  aCaption:=UTF8Trim(aCaption,[]);
  if aCaption='' then exit;
  if Filters.GetFilter(aCaption,false)<>nil then begin
    IDEMessageDialog(lisFilterAlreadyExists, Format(
      lisAFilterWithTheNameAlreadyExists, [aCaption]), mtError, [mbCancel], '');
    exit;
  end;
  NewFilter:=Filters.GetFilter(aCaption,true);
  NewFilter.Assign(MessagesCtrl.ActiveFilter);
  MessagesCtrl.ActiveFilter:=NewFilter;
end;

procedure TMessagesFrame.ClearFilterMsgTypesMenuItemClick(Sender: TObject);
begin
  MessagesCtrl.ActiveFilter.ClearFilterMsgTypes;
end;

procedure TMessagesFrame.ClearMenuItemClick(Sender: TObject);
begin
  MessagesCtrl.ClearViews(true);
end;

function TMessagesFrame.GetViews(Index: integer): TLMsgWndView;
begin
  Result:=MessagesCtrl.Views[Index];
end;

procedure TMessagesFrame.HideSearch;
begin
  SearchPanel.Visible:=false;
  MessagesCtrl.SearchText:='';
end;

procedure TMessagesFrame.SaveClicked(OnlyShown: boolean);
var
  Dlg: TSaveDialog;
  s: String;
  Filename: String;
  fs: TFileStream;
begin
  Dlg:=IDESaveDialogClass.Create(nil);
  try
    Dlg.Title:=lisSaveMessages;
    Dlg.FileName:='messages.txt';
    Dlg.Options:=Dlg.Options+[ofPathMustExist,ofCreatePrompt];
    InitIDEFileDialog(Dlg);
    if not Dlg.Execute then exit;
    Filename:=TrimAndExpandFilename(Dlg.FileName);
    if DirPathExistsCached(Filename) then exit;

    s:=AllMessagesAsString(OnlyShown);

    try
      fs:=TFileStream.Create(Filename,fmCreate);
      try
        if s<>'' then
          fs.Write(s[1],length(s));
      finally
        fs.Free;
      end;
    except
      on E: Exception do begin
        IDEMessageDialog(lisWriteError, Format(lisUnableToWriteFile2, [Filename]
          ),
          mtError, [mbCancel]);
      end;
    end;

  finally
    StoreIDEFileDialog(Dlg);
    Dlg.Free;
  end;
end;

procedure TMessagesFrame.CopyAllClicked(OnlyShown: boolean);
var
  s: String;
  Msg: String;
begin
  s:=AllMessagesAsString(OnlyShown);
  if length(s)>1000000 then begin
    if length(s)<10000 then
      Msg:=Format(lisByte, [IntToStr(length(s))])
    else if Length(s)<10000000 then
      Msg:=Format(lisKB, [IntToStr(length(s) div 1000)])
    else
      Msg:=Format(lisMB, [IntToStr(length(s) div 1000)]);
    if IDEMessageDialog(lisCCOWarningCaption, Format(
      lisThisWillPutALotOfTextOnTheClipboardProceed, [Msg, #13]),
      mtConfirmation,[mbYes,mbNo])<>mrYes then exit;
  end;
  Clipboard.AsText:=s;
end;

procedure TMessagesFrame.CopyMsgToClipboard(OnlyFilename: boolean);
var
  View: TLMsgWndView;
  Line: TMessageLine;
  OrderedSelection: TIntegerList;
  i, LineNumber: Integer;
  Txt: String;
begin
  Txt:='';
  View:=MessagesCtrl.SelectedView;
  if View=nil then exit;
  OrderedSelection:=TIntegerList.Create;
  try
    // The initially selected line is first in the list. The list is not sorted.
    // Here we need the line numbers sorted.
    OrderedSelection.Assign(MessagesCtrl.FSelectedLines);
    OrderedSelection.Sort;
    for i:=0 to OrderedSelection.Count-1 do begin
      LineNumber:=OrderedSelection[i];
      Assert(LineNumber<=View.Lines.Count, 'TMessagesFrame.CopyMsgToClipboard: LineNumber is too big.');
      if LineNumber=-1 then begin
        if OnlyFilename then
          Txt:=rsResourceFileName
        else
          Txt:=MessagesCtrl.GetHeaderText(View); // header
      end
      else begin
        if LineNumber=View.Lines.Count then
          Line:=View.ProgressLine                // progress line
        else
          Line:=View.Lines[LineNumber];          // normal messages
        if OnlyFilename then
          Txt+=Line.Filename
        else
          Txt+=MessagesCtrl.GetLineText(Line);
      end;
      if i<OrderedSelection.Count-1 then
        Txt+=LineEnding;
    end;
  finally
    OrderedSelection.Free;
  end;
  Clipboard.AsText:=Txt;
end;

function TMessagesFrame.GetMsgPattern(SubTool: string; MsgId: integer;
  WithUrgency: boolean; MaxLen: integer): string;
var
  Pattern: String;
  Urgency: TMessageLineUrgency;
begin
  Result:=SubTool;
  if Result=SubToolFPC then
    Result:='';
  if (MsgID<>0) then
    Result+='('+IntToStr(MsgID)+')';
  Pattern:=ExternalToolList.GetMsgPattern(SubTool,MsgID,Urgency);
  if Pattern<>'' then
    Result+=' '+Pattern;
  if WithUrgency and (not (Urgency in [mluNone,mluImportant])) then
    Result:=MessagesCtrl.UrgencyToStr(Urgency)+': '+Result;
  if UTF8Length(Result)>MaxLen then
    Result:=UTF8Copy(Result,1,MaxLen)+'...';
end;

procedure TMessagesFrame.Notification(AComponent: TComponent;
  Operation: TOperation);
begin
  inherited Notification(AComponent, Operation);
  if Operation=opRemove then begin
    if AComponent=MessagesCtrl then
      MessagesCtrl:=nil;
  end;
end;

constructor TMessagesFrame.Create(TheOwner: TComponent);
var
  ImgIDInfo: Integer;
  ImgIDHint: Integer;
  ImgIDNote: Integer;
  ImgIDWarning: Integer;
  ImgIDError: Integer;
  ImgIDFatal: Integer;
begin
  inherited Create(TheOwner);

  MessagesCtrl:=TMessagesCtrl.Create(Self);
  FImages := TLCLGlyphs.Create(Self);
  FImages.Width := 12;
  FImages.Height := 12;
  FImages.RegisterResolutions([12, 16, 24]);
  FImages.SetWidth100Suffix(16);
  FImages.OnGetWidthForPPI := @ImagesGetWidthForPPI;
  ImgIDInfo:=FImages.GetImageIndex('state_information');
  ImgIDHint:=FImages.GetImageIndex('state_hint');
  ImgIDNote:=FImages.GetImageIndex('state_note');
  ImgIDWarning:=FImages.GetImageIndex('state_warning');
  ImgIDError:=FImages.GetImageIndex('state_error');
  ImgIDFatal:=FImages.GetImageIndex('state_fatal');
  with MessagesCtrl do begin
    Name:='MessagesCtrl';
    Align:=alClient;
    Parent:=Self;

    UrgencyStyles[mluNone].SetValues('?',ImgIDInfo,EnvironmentOptions.MsgColors[mluNone]);
    UrgencyStyles[mluProgress].SetValues(lisPDProgress, ImgIDInfo,
      EnvironmentOptions.MsgColors[mluProgress]);
    UrgencyStyles[mluDebug].SetValues(lisDebug, ImgIDInfo,
      EnvironmentOptions.MsgColors[mluDebug]);
    UrgencyStyles[mluVerbose3].SetValues(lisExtremelyVerbose, ImgIDInfo,
      EnvironmentOptions.MsgColors[mluVerbose3]);
    UrgencyStyles[mluVerbose2].SetValues(lisVeryVerbose, ImgIDInfo,
      EnvironmentOptions.MsgColors[mluVerbose2]);
    UrgencyStyles[mluVerbose].SetValues(lisVerbose, ImgIDInfo,
      EnvironmentOptions.MsgColors[mluVerbose]);
    UrgencyStyles[mluHint].SetValues(lisHint, ImgIDHint,
      EnvironmentOptions.MsgColors[mluHint]);
    UrgencyStyles[mluNote].SetValues(lisNote, ImgIDNote,
      EnvironmentOptions.MsgColors[mluNote]);
    UrgencyStyles[mluWarning].SetValues(lisCCOWarningCaption, ImgIDWarning,
      EnvironmentOptions.MsgColors[mluWarning]);
    UrgencyStyles[mluImportant].SetValues(lisImportant, ImgIDInfo,
      EnvironmentOptions.MsgColors[mluImportant]);
    UrgencyStyles[mluError].SetValues(lisCCOErrorCaption, ImgIDError,
      EnvironmentOptions.MsgColors[mluError]);
    UrgencyStyles[mluFatal].SetValues(lisFatal, ImgIDFatal,
      EnvironmentOptions.MsgColors[mluFatal]);
    UrgencyStyles[mluPanic].SetValues(lisPanic, ImgIDFatal,
      EnvironmentOptions.MsgColors[mluPanic]);
    Images:=Self.FImages;
    PopupMenu:=MsgCtrlPopupMenu;
  end;
  MessagesCtrl.SourceMarks:=ExtToolsMarks;

  // search
  SearchPanel.Visible:=false; // by default the search is hidden
  HideSearchSpeedButton.Hint:=lisHideSearch;
  IDEImages.AssignImage(HideSearchSpeedButton, 'debugger_power');
  SearchNextSpeedButton.Hint:=lisUDSearchNextOccurrenceOfThisPhrase;
  IDEImages.AssignImage(SearchNextSpeedButton, 'callstack_bottom');
  SearchPrevSpeedButton.Hint:=lisUDSearchPreviousOccurrenceOfThisPhrase;
  IDEImages.AssignImage(SearchPrevSpeedButton, 'callstack_top');
  SearchEdit.TextHint:=lisUDSearch;
end;

destructor TMessagesFrame.Destroy;
begin
  MessagesCtrl.BeginUpdate;
  ClearViews(false);
  inherited Destroy;
end;

procedure TMessagesFrame.ApplyIDEOptions;
begin
  MessagesCtrl.ApplyEnvironmentOptions;
end;

function TMessagesFrame.ViewCount: integer;
begin
  Result:=MessagesCtrl.ViewCount;
end;

function TMessagesFrame.GetView(aCaption: string; CreateIfNotExist: boolean
  ): TLMsgWndView;
begin
  Result:=MessagesCtrl.GetView(aCaption,CreateIfNotExist);
end;

function TMessagesFrame.FindUnfinishedView: TLMsgWndView;
begin
  Result:=MessagesCtrl.FindUnfinishedView;
end;

procedure TMessagesFrame.DeleteView(View: TLMsgWndView);
begin
  View.Free;
end;

function TMessagesFrame.IndexOfView(View: TLMsgWndView): integer;
begin
  Result:=MessagesCtrl.IndexOfView(View);
end;

procedure TMessagesFrame.ClearViews(OnlyFinished: boolean);
begin
  MessagesCtrl.ClearViews(OnlyFinished);
end;

procedure TMessagesFrame.CreateMarksForFile(aSynEdit: TSynEdit;
  aFilename: string; DeleteOld: boolean);
begin
  MessagesCtrl.CreateMarksForFile(aSynEdit,aFilename,DeleteOld);
end;

procedure TMessagesFrame.ApplySrcChanges(Changes: TETSingleSrcChanges);
begin
  MessagesCtrl.ApplySrcChanges(Changes);
end;

procedure TMessagesFrame.ApplyMultiSrcChanges(Changes: TETMultiSrcChanges);
var
  Node: TAvlTreeNode;
begin
  for Node in Changes.PendingChanges do
    ApplySrcChanges(TETSingleSrcChanges(Node.Data));
end;

procedure TMessagesFrame.SourceEditorPopup(MarkLine: TSynEditMarkLine;
  const LogicalCaretXY: TPoint);
var
  i: Integer;
  CurMark: TETMark;
  BestMark: TETMark;
begin
  //debugln(['TMessagesFrame.SourceEditorPopup ']);
  // show quickfixes for the first TETMark in editor line
  if MarkLine=nil then exit;
  IDEQuickFixes.ClearLines;
  BestMark:=nil;
  for i:=0 to MarkLine.Count-1 do begin
    CurMark:=TETMark(MarkLine[i]);
    if not (CurMark is TETMark) then continue;
    //debugln(['TMessagesFrame.SourceEditorPopup ',CurMark.Line,',',CurMark.Column,' ID=',CurMark.MsgLine.MsgID,' Msg=',CurMark.MsgLine.Msg,' EditorXY=',dbgs(LogicalCaretXY)]);
    if (BestMark=nil) then
      BestMark:=CurMark
    else begin
      // there are multiple marks in the line
      if (LogicalCaretXY.Y=MarkLine.LineNum)
      and (LogicalCaretXY.X=CurMark.Column) then begin
        // mark at cursor position
        BestMark:=CurMark;
        break;
      end else begin
        // default: use first in line
        if CurMark.Column<BestMark.Column then
          BestMark:=CurMark;
      end;
    end;
  end;
  if BestMark=nil then
    exit;
  IDEQuickFixes.AddMsgLine(BestMark.MsgLine);
  // create items
  if IDEQuickFixes.Count>0 then begin
    IDEQuickFixes.OnPopupMenu(SrcEditMenuSectionFirstDynamic);
    if mcoSrcEditPopupSelect in MessagesCtrl.Options then
      MessagesCtrl.Select(BestMark.MsgLine,true);
  end;
end;

procedure TMessagesFrame.SourceEditorHint(MarkLine: TSynEditMarkLine;
  var HintStr: string);
var
  i: Integer;
  CurMark: TETMark;
  Msg: TMessageLine;
  CurHint: String;
begin
  if MarkLine=nil then exit;
  for i:=0 to MarkLine.Count-1 do begin
    CurMark:=TETMark(MarkLine[i]);
    if not (CurMark is TETMark) then continue;
    Msg:=CurMark.MsgLine;
    CurHint:=MessagesCtrl.UrgencyToStr(Msg.Urgency)+': '+Msg.Msg;
    if HintStr<>'' then
      HintStr:=HintStr+LineEnding;
    HintStr:=HintStr+CurHint;
  end;
end;

procedure TMessagesFrame.SelectMsgLine(Msg: TMessageLine; DoScroll: boolean);
begin
  MessagesCtrl.Select(Msg,DoScroll);
end;

function TMessagesFrame.SelectFirstUrgentMessage(
  aMinUrgency: TMessageLineUrgency; WithSrcPos: boolean): boolean;
begin
  Result:=MessagesCtrl.SelectFirstUrgentMessage(aMinUrgency,WithSrcPos);
end;

function TMessagesFrame.SelectNextUrgentMessage(
  aMinUrgency: TMessageLineUrgency; WithSrcPos, Downwards: boolean): boolean;
begin
  Result:=MessagesCtrl.SelectNextUrgentMessage(aMinUrgency,WithSrcPos,Downwards);
end;

procedure TMessagesFrame.ClearCustomMessages(const ViewCaption: string);
var
  View: TLMsgWndView;
begin
  View:=GetView(ViewCaption,false);
  if (View=nil) or (View.Lines.Count=0) then exit;
  View.Lines.Clear;
  MessagesCtrl.UpdateScrollBar(true);
  MessagesCtrl.Invalidate;
end;

function TMessagesFrame.AddCustomMessage(TheUrgency: TMessageLineUrgency;
  Msg: string; aFilename: string; LineNumber: integer; Column: integer;
  const ViewCaption: string): TMessageLine;
var
  View: TLMsgWndView;
begin
  Result:=nil;
  View:=GetView(ViewCaption,true);
  View.Running:=false;
  Result:=View.Lines.CreateLine(-1);
  Result.Msg:=Msg;
  Result.Urgency:=TheUrgency;
  Result.SetSourcePosition(aFilename,LineNumber,Column);
  View.Lines.Add(Result);
  MessagesCtrl.UpdateScrollBar(true);
  MessagesCtrl.Invalidate;
end;

end.


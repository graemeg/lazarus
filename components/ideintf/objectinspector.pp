{
 *****************************************************************************
  See the file COPYING.modifiedLGPL.txt, included in this distribution,
  for details about the license.
 *****************************************************************************

  Author: Mattias Gaertner

  Abstract:
   This unit defines the TObjectInspectorDlg.
   It uses TOIPropertyGrid and TOIPropertyGridRow which are also defined in this
   unit. The object inspector uses property editors (see TPropertyEditor) to
   display and control properties, thus the object inspector is merely an
   object viewer than an editor. The property editors do the real work.

  ToDo:
   - backgroundcolor=clNone
   - Define Init values
   - Set to init value
}
unit ObjectInspector;

{$Mode objfpc}{$H+}

{off $DEFINE DoNotCatchOIExceptions}

interface

uses
  // IMPORTANT: the object inspector is a tool and can be used in other programs
  //            too. Don't put Lazarus IDE specific things here.
  // RTL / FCL
  Classes, SysUtils, Types, TypInfo, StrUtils, math,
  // LCL
  LCLPlatformDef, InterfaceBase, LCLType, LCLIntf, Forms, Buttons, Graphics,
  StdCtrls, Controls, ComCtrls, ExtCtrls, Menus, Dialogs, Themes, LMessages,
  ImgList, ActnList,
  // LazControls
  {$IFnDEF UseOINormalCheckBox} CheckBoxThemed, {$ENDIF}
  TreeFilterEdit, ListFilterEdit,
  // LazUtils
  GraphType, LazConfigStorage, LazLoggerBase, LazStringUtils, LazUTF8,
  // IdeIntf
  IDEImagesIntf, IDEHelpIntf, ObjInspStrConsts,
  PropEdits, PropEditUtils, ComponentTreeView, OIFavoriteProperties,
  ComponentEditors, ChangeParentDlg;

const
  OIOptionsFileVersion = 3;

  DefBackgroundColor = clBtnFace;
  DefReferencesColor = clMaroon;
  DefSubPropertiesColor = clGreen;
  DefNameColor = clWindowText;
  DefValueColor = clMaroon;
  DefDefaultValueColor = clWindowText;
  DefValueDifferBackgrndColor = $F0F0FF; // Sort of pink.
  DefReadOnlyColor = clGrayText;
  DefHighlightColor = clHighlight;
  DefHighlightFontColor = clHighlightText;
  DefGutterColor = DefBackgroundColor;
  DefGutterEdgeColor = cl3DShadow;

  DefaultOITypeKinds = [
    tkUnknown, tkInteger, tkChar, tkEnumeration, tkFloat, tkSet,{ tkMethod,}
    tkSString, tkLString, tkAString, tkWString, tkVariant,
    {tkArray, tkRecord,} tkInterface, tkClass, tkObject, tkWChar, tkBool,
    tkInt64, tkQWord, tkUString, tkUChar];
type
  EObjectInspectorException = class(Exception);

  TObjectInspectorDlg = class;
  TOICustomPropertyGrid = class;

  // standard ObjectInspector pages
  TObjectInspectorPage = (
    oipgpProperties,
    oipgpEvents,
    oipgpFavorite,
    oipgpRestricted
    );
  TObjectInspectorPages = set of TObjectInspectorPage;


  { TOIOptions }

  TOIOptions = class
  private
    FComponentTreeHeight: integer;
    FConfigStore: TConfigStorage;
    FDefaultItemHeight: integer;
    FGutterColor: TColor;
    FGutterEdgeColor: TColor;
    FShowComponentTree: boolean;

    FSaveBounds: boolean;
    FLeft: integer;
    FShowPropertyFilter: boolean;
    FShowGutter: boolean;
    FShowInfoBox: boolean;
    FInfoBoxHeight: integer;
    FShowStatusBar: boolean;
    FTop: integer;
    FWidth: integer;
    FHeight: integer;
    FGridSplitterX: array[TObjectInspectorPage] of integer;

    FPropertyNameColor: TColor;
    FSubPropertiesColor: TColor;
    FValueColor: TColor;
    FDefaultValueColor: TColor;
    FValueDifferBackgrndColor: TColor;
    FReadOnlyColor: TColor;
    FReferencesColor: TColor;
    FGridBackgroundColor: TColor;
    FHighlightColor: TColor;
    FHighlightFontColor: TColor;

    FShowHints: Boolean;
    FAutoShow: Boolean;
    FCheckboxForBoolean: Boolean;
    FBoldNonDefaultValues: Boolean;
    FDrawGridLines: Boolean;
    function FPropertyGridSplitterX(Page: TObjectInspectorPage): integer;
    procedure FPropertyGridSplitterX(Page: TObjectInspectorPage;
      const AValue: integer);
  public
    constructor Create;
    function Load: boolean;
    function Save: boolean;
    procedure Assign(AnObjInspector: TObjectInspectorDlg);
    procedure AssignTo(AnObjInspector: TObjectInspectorDlg); overload;
    procedure AssignTo(AGrid: TOICustomPropertyGrid); overload;

    property ConfigStore: TConfigStorage read FConfigStore write FConfigStore;

    property SaveBounds:boolean read FSaveBounds write FSaveBounds;
    property Left:integer read FLeft write FLeft;
    property Top:integer read FTop write FTop;
    property Width:integer read FWidth write FWidth;
    property Height:integer read FHeight write FHeight;
    property GridSplitterX[Page: TObjectInspectorPage]:integer
                       read FPropertyGridSplitterX write FPropertyGridSplitterX;
    property DefaultItemHeight: integer read FDefaultItemHeight
                                        write FDefaultItemHeight;
    property ShowComponentTree: boolean read FShowComponentTree
                                        write FShowComponentTree;
    property ComponentTreeHeight: integer read FComponentTreeHeight
                                          write FComponentTreeHeight;

    property GridBackgroundColor: TColor read FGridBackgroundColor write FGridBackgroundColor;
    property SubPropertiesColor: TColor read FSubPropertiesColor write FSubPropertiesColor;
    property ReferencesColor: TColor read FReferencesColor write FReferencesColor;
    property ReadOnlyColor: TColor read FReadOnlyColor write FReadOnlyColor;
    property ValueColor: TColor read FValueColor write FValueColor;
    property DefaultValueColor: TColor read FDefaultValueColor write FDefaultValueColor;
    property ValueDifferBackgrndColor: TColor read FValueDifferBackgrndColor write FValueDifferBackgrndColor;
    property PropertyNameColor: TColor read FPropertyNameColor write FPropertyNameColor;
    property HighlightColor: TColor read FHighlightColor write FHighlightColor;
    property HighlightFontColor: TColor read FHighlightFontColor write FHighlightFontColor;
    property GutterColor: TColor read FGutterColor write FGutterColor;
    property GutterEdgeColor: TColor read FGutterEdgeColor write FGutterEdgeColor;

    property ShowHints: boolean read FShowHints write FShowHints;
    property AutoShow: boolean read FAutoShow write FAutoShow;
    property CheckboxForBoolean: boolean read FCheckboxForBoolean write FCheckboxForBoolean;
    property BoldNonDefaultValues: boolean read FBoldNonDefaultValues write FBoldNonDefaultValues;
    property DrawGridLines: boolean read FDrawGridLines write FDrawGridLines;
    property ShowPropertyFilter: boolean read FShowPropertyFilter write FShowPropertyFilter;
    property ShowGutter: boolean read FShowGutter write FShowGutter;
    property ShowStatusBar: boolean read FShowStatusBar write FShowStatusBar;
    property ShowInfoBox: boolean read FShowInfoBox write FShowInfoBox;
    property InfoBoxHeight: integer read FInfoBoxHeight write FInfoBoxHeight;
  end;

  { TOIPropertyGridRow }

  TOIPropertyGridRow = class
  private
    FTop: integer;
    FHeight: integer;
    FLvl: integer;
    FName: string;
    FExpanded: boolean;
    FTree: TOICustomPropertyGrid;
    FChildCount:integer;
    FPriorBrother,
    FFirstChild,
    FLastChild,
    FNextBrother,
    FParent: TOIPropertyGridRow;
    FEditor: TPropertyEditor;
    FWidgetSets: TLCLPlatforms;

    FIndex:integer;
    LastPaintedValue: string;

    procedure GetLvl;
  public
    constructor Create(PropertyTree: TOICustomPropertyGrid;
       PropEditor:TPropertyEditor; ParentNode:TOIPropertyGridRow; WidgetSets: TLCLPlatforms);
    destructor Destroy; override;
    function ConsistencyCheck: integer;
    function HasChild(Row: TOIPropertyGridRow): boolean;
    procedure WriteDebugReport(const Prefix: string);

    function GetBottom: integer;
    function IsReadOnly: boolean;
    function IsDisabled: boolean;
    procedure MeasureHeight(ACanvas: TCanvas);
    function Sort(const Compare: TListSortCompare): boolean; // true if changed
    function IsSorted(const Compare: TListSortCompare): boolean;
    function Next: TOIPropertyGridRow;
    function NextSkipChilds: TOIPropertyGridRow;

    property Editor: TPropertyEditor read FEditor;
    property Top: integer read FTop write FTop;
    property Height: integer read FHeight write FHeight;
    property Bottom: integer read GetBottom;
    property Lvl: integer read FLvl;
    property Name: string read FName;
    property Expanded: boolean read FExpanded;
    property Tree: TOICustomPropertyGrid read FTree;
    property Parent: TOIPropertyGridRow read FParent;
    property ChildCount: integer read FChildCount;
    property FirstChild: TOIPropertyGridRow read FFirstChild;
    property LastChild: TOIPropertyGridRow read FLastChild;
    property NextBrother: TOIPropertyGridRow read FNextBrother;
    property PriorBrother: TOIPropertyGridRow read FPriorBrother;
    property Index: integer read FIndex;
  end;

  //----------------------------------------------------------------------------
  TOIPropertyGridState = (
    pgsChangingItemIndex,
    pgsApplyingValue,
    pgsUpdatingEditControl,
    pgsBuildPropertyListNeeded,
    pgsGetComboItemsCalled,
    pgsIdleEnabled,
    pgsCallingEdit,                 // calling property editor Edit
    pgsFocusPropertyEditorDisabled  // by building PropertyList no editor should be focused
    );
  TOIPropertyGridStates = set of TOIPropertyGridState;

  { TOICustomPropertyGrid }

  TOICustomPropertyGridColumn = (
    oipgcName,
    oipgcValue
  );

  TOILayout = (
   oilHorizontal,
   oilVertical
  );
  
  TOIQuickEdit = (
    oiqeEdit,
    oiqeShowValue
  );

  TOIPropertyHintEvent = function(Sender: TObject; PointedRow: TOIPropertyGridRow;
            out AHint: string): boolean of object;

  TOIEditorFilterEvent = procedure(Sender: TObject; aEditor: TPropertyEditor;
            var aShow: boolean) of object;

  TOICustomPropertyGrid = class(TCustomControl)
  private
    FBackgroundColor: TColor;
    FColumn: TOICustomPropertyGridColumn;
    FGutterColor: TColor;
    FGutterEdgeColor: TColor;
    FHighlightColor: TColor;
    FLayout: TOILayout;
    FOnEditorFilter: TOIEditorFilterEvent;
    FOnOIKeyDown: TKeyEvent;
    FOnPropertyHint: TOIPropertyHintEvent;
    FOnSelectionChange: TNotifyEvent;
    FReferencesColor: TColor;
    FReadOnlyColor: TColor;
    FRowSpacing: integer;
    FShowGutter: Boolean;
    FCheckboxForBoolean: Boolean;
    FSubPropertiesColor: TColor;
    FChangeStep: integer;
    FCurrentButton: TControl; // nil or ValueButton
    FCurrentEdit: TWinControl;  // nil or ValueEdit or ValueComboBox or ValueCheckBox
    FCurrentEditorLookupRoot: TPersistent;
    FDefaultItemHeight:integer;
    FDragging: boolean;
    FExpandedProperties: TStringList;// used to restore expanded state when switching selected component(s)
    FExpandingRow: TOIPropertyGridRow;
    FFavorites: TOIFavoriteProperties;
    FFilter: TTypeKinds;
    FIndent: integer;
    FItemIndex: integer;
    FNameFont, FDefaultValueFont, FValueFont, FHighlightFont: TFont;
    FValueDifferBackgrndColor: TColor;
    FNewComboBoxItems: TStringListUTF8Fast;
    FOnModified: TNotifyEvent;
    FRows: TFPList;// list of TOIPropertyGridRow
    FSelection: TPersistentSelectionList;
    FNotificationComponents: TFPList;
    FPropertyEditorHook: TPropertyEditorHook;
    FPreferredSplitterX: integer; // best splitter position
    FSplitterX: integer; // current splitter position
    FStates: TOIPropertyGridStates;
    FTopY: integer;
    FDrawHorzGridLines: Boolean;
    FActiveRowImages: TLCLGlyphs;
    FFirstClickTime: DWORD;
    FKeySearchText: string;
    FHideClassNames: Boolean;
    FPropNameFilter : String;
    FPaintRc: TRect;

    // hint stuff
    FLongHintTimer: TTimer;
    FHintManager: THintWindowManager;
    FHintIndex: integer;
    FHintType: TPropEditHint;
    FShowingLongHint: boolean; // last hint was activated by the hinttimer

    ValueEdit: TEdit;
    ValueComboBox: TComboBox;
    {$IFnDEF UseOINormalCheckBox}
    ValueCheckBox: TCheckBoxThemed;
    {$ELSE}
    ValueCheckBox: TCheckBox;
    {$ENDIF}
    ValueButton: TSpeedButton;

    procedure ActiveRowImagesGetWidthForPPI(Sender: TCustomImageList;
      {%H-}AImageWidth, {%H-}APPI: Integer; var AResultWidth: Integer);
    procedure HintMouseLeave(Sender: TObject);
    procedure HintTimer(Sender: TObject);
    procedure HideHint;
    procedure HintMouseDown(Sender: TObject; Button: TMouseButton;
                            Shift: TShiftState; X, Y: Integer);
    procedure IncreaseChangeStep;
    function GridIsUpdating: boolean;

    function GetRow(Index:integer):TOIPropertyGridRow;
    function GetRowCount:integer;
    procedure ClearRows;
    function GetCurrentEditValue: string;
    procedure SetActiveControl(const AControl: TWinControl);
    procedure SetCheckboxState(NewValue: string);
    procedure SetColumn(const AValue: TOICustomPropertyGridColumn);
    procedure SetCurrentEditValue(const NewValue: string);
    procedure SetDrawHorzGridLines(const AValue: Boolean);
    procedure SetFavorites(const AValue: TOIFavoriteProperties);
    procedure SetFilter(const AValue: TTypeKinds);
    procedure SetGutterColor(const AValue: TColor);
    procedure SetGutterEdgeColor(const AValue: TColor);
    procedure SetHighlightColor(const AValue: TColor);
    procedure SetItemIndex(NewIndex:integer);
    function IsCurrentEditorAvailable: Boolean;

    function GetNameRowHeight: Integer; // temp solution untill TFont.height returns its actual value

    procedure SetItemsTops;
    procedure AlignEditComponents;
    procedure EndDragSplitter;
    procedure SetRowSpacing(const AValue: integer);
    procedure SetShowGutter(const AValue: Boolean);
    procedure SetSplitterX(const NewValue:integer);
    procedure SetTopY(const NewValue:integer);

    function GetPropNameColor(ARow: TOIPropertyGridRow):TColor;
    function GetTreeIconX(Index: integer):integer;
    function RowRect(ARow: integer):TRect;
    procedure PaintRow(ARow: integer);
    procedure DoPaint(PaintOnlyChangedValues: boolean);

    procedure SetSelection(const ASelection:TPersistentSelectionList);
    procedure SetPropertyEditorHook(NewPropertyEditorHook:TPropertyEditorHook);
    procedure UpdateSelectionNotifications;
    procedure HookGetCheckboxForBoolean(var Value: Boolean);

    procedure AddPropertyEditor(PropEditor: TPropertyEditor);
    procedure AddStringToComboBox(const s: string);
    procedure ExpandRow(Index: integer);
    procedure ShrinkRow(Index: integer);
    procedure AddSubEditor(PropEditor: TPropertyEditor);
    procedure SortSubEditors(ParentRow: TOIPropertyGridRow);
    function CanExpandRow(Row: TOIPropertyGridRow): boolean;

    procedure SetRowValue(CheckFocus, ForceValue: boolean);
    procedure DoCallEdit(Edit: TOIQuickEdit = oiqeEdit);
    procedure RefreshValueEdit;
    procedure ToggleRow;
    procedure ValueEditDblClick(Sender : TObject);
    procedure ValueControlMouseDown(Sender: TObject; {%H-}Button:TMouseButton;
      {%H-}Shift: TShiftState; {%H-}X,{%H-}Y:integer);
    procedure ValueControlMouseMove(Sender: TObject; {%H-}Shift: TShiftState;
      {%H-}X,{%H-}Y:integer);
    procedure ValueEditKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure ValueEditKeyUp(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure ValueEditExit(Sender: TObject);
    procedure ValueEditChange(Sender: TObject);
    procedure ValueEditMouseUp(Sender: TObject; Button: TMouseButton;
                               Shift: TShiftState; {%H-}X, {%H-}Y: Integer);
    procedure ValueCheckBoxKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure ValueCheckBoxKeyUp(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure ValueCheckBoxExit(Sender: TObject);
    procedure ValueCheckBoxClick(Sender: TObject);
    procedure ValueComboBoxExit(Sender: TObject);
    procedure ValueComboBoxKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure ValueComboBoxKeyUp(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure ValueComboBoxMouseUp(Sender: TObject; Button: TMouseButton;
                                   Shift: TShiftState; {%H-}X, {%H-}Y: Integer);
    procedure ValueComboBoxCloseUp(Sender: TObject);
    procedure ValueComboBoxGetItems(Sender: TObject);
    procedure ValueButtonClick(Sender: TObject);
    procedure ValueComboBoxMeasureItem({%H-}Control: TWinControl; Index: Integer;
          var AHeight: Integer);
    procedure ValueComboBoxDrawItem({%H-}Control: TWinControl; Index: Integer;
          ARect: TRect; State: TOwnerDrawState);
    procedure OnIdle(Sender: TObject; var {%H-}Done: Boolean);
    procedure SetIdleEvent(Enable: boolean);
    procedure OnGridMouseWheel(Sender: TObject; {%H-}Shift: TShiftState;
      WheelDelta: Integer; {%H-}MousePos: TPoint; var Handled: Boolean);

    procedure WMVScroll(var Msg: TLMScroll); message LM_VSCROLL;
    procedure SetBackgroundColor(const AValue: TColor);
    procedure SetReferences(const AValue: TColor);
    procedure SetSubPropertiesColor(const AValue: TColor);
    procedure SetReadOnlyColor(const AValue: TColor);
    procedure SetValueDifferBackgrndColor(AValue: TColor);
    procedure UpdateScrollBar;
    function FillComboboxItems: boolean; // true if something changed
    function EditorFilter(const AEditor: TPropertyEditor): Boolean;
  protected
    procedure CreateParams(var Params: TCreateParams); override;
    procedure CreateWnd; override;
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;

    function DoMouseWheel(Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint): Boolean; override;
    procedure MouseDown(Button:TMouseButton; Shift:TShiftState; X,Y:integer); override;
    procedure MouseMove(Shift:TShiftState; X,Y:integer);  override;
    procedure MouseUp(Button:TMouseButton; Shift:TShiftState; X,Y:integer); override;
    procedure MouseLeave; override;

    procedure KeyDown(var Key: Word; Shift: TShiftState); override;
    procedure HandleStandardKeys(var Key: Word; Shift: TShiftState); virtual;
    procedure HandleKeyUp(var Key: Word; Shift: TShiftState); virtual;
    procedure DoTabKey; virtual;
    procedure DoSetBounds(ALeft, ATop, AWidth, AHeight: integer); override;
    procedure DoSelectionChange;
  public
    constructor Create(TheOwner: TComponent); override;
    constructor CreateWithParams(AnOwner: TComponent;
                                 APropertyEditorHook: TPropertyEditorHook;
                                 TypeFilter: TTypeKinds;
                                 DefItemHeight: integer);
    destructor Destroy;  override;
    function CanEditRowValue(CheckFocus: boolean): boolean;
    procedure FocusCurrentEditor;
    procedure SaveChanges;
    function ConsistencyCheck: integer;
    procedure EraseBackground({%H-}DC: HDC); override;
    function GetActiveRow: TOIPropertyGridRow;
    function GetHintTypeAt(RowIndex: integer; X: integer): TPropEditHint;

    function GetRowByPath(const PropPath: string): TOIPropertyGridRow;
    function GridHeight: integer;
    function RealDefaultItemHeight: integer;
    function MouseToIndex(y: integer; MustExist: boolean): integer;
    function PropertyPath(Index: integer):string;
    function PropertyPath(Row: TOIPropertyGridRow):string;
    function PropertyEditorByName(const PropName: string): TPropertyEditor;
    function TopMax: integer;
    procedure BuildPropertyList(OnlyIfNeeded: Boolean = False; FocusEditor: Boolean = True);
    procedure Clear;
    procedure Paint; override;
    procedure PropEditLookupRootChange;
    procedure RefreshPropertyValues;
    procedure ScrollToActiveItem;
    procedure ScrollToItem(NewIndex: Integer);
    procedure SetBounds(aLeft, aTop, aWidth, aHeight: integer); override;
    procedure SetCurrentRowValue(const NewValue: string);
    procedure SetItemIndexAndFocus(NewItemIndex: integer;
                                   WasValueClick: Boolean = False);

    property BackgroundColor: TColor read FBackgroundColor
                                     write SetBackgroundColor default DefBackgroundColor;
    property GutterColor: TColor read FGutterColor write SetGutterColor default DefGutterColor;
    property GutterEdgeColor: TColor read FGutterEdgeColor write SetGutterEdgeColor default DefGutterEdgeColor;
    property HighlightColor: TColor read FHighlightColor write SetHighlightColor default DefHighlightColor;
    property ReferencesColor: TColor read FReferencesColor
                                     write SetReferences default DefReferencesColor;
    property SubPropertiesColor: TColor read FSubPropertiesColor
                                     write SetSubPropertiesColor default DefSubPropertiesColor;
    property ReadOnlyColor: TColor read FReadOnlyColor
                                     write SetReadOnlyColor default DefReadOnlyColor;
    property ValueDifferBackgrndColor: TColor read FValueDifferBackgrndColor
           write SetValueDifferBackgrndColor default DefValueDifferBackgrndColor;

    property NameFont: TFont read FNameFont write FNameFont;
    property DefaultValueFont: TFont read FDefaultValueFont write FDefaultValueFont;
    property ValueFont: TFont read FValueFont write FValueFont;
    property HighlightFont: TFont read FHighlightFont write FHighlightFont;

    property BorderStyle default bsSingle;
    property Column: TOICustomPropertyGridColumn read FColumn write SetColumn;
    property CurrentEditValue: string read GetCurrentEditValue
                                      write SetCurrentEditValue;
    property DefaultItemHeight:integer read FDefaultItemHeight
                                       write FDefaultItemHeight default 0;
    property DrawHorzGridLines: Boolean read FDrawHorzGridLines write
      SetDrawHorzGridLines default True;
    property ExpandedProperties: TStringList read FExpandedProperties;
    property Indent: integer read FIndent write FIndent;
    property ItemIndex: integer read FItemIndex write SetItemIndex;
    property Layout: TOILayout read FLayout write FLayout default oilHorizontal;
    property OnEditorFilter: TOIEditorFilterEvent read FOnEditorFilter write FOnEditorFilter;
    property OnModified: TNotifyEvent read FOnModified write FOnModified;
    property OnOIKeyDown: TKeyEvent read FOnOIKeyDown write FOnOIKeyDown;
    property OnSelectionChange: TNotifyEvent read FOnSelectionChange write FOnSelectionChange;
    property OnPropertyHint: TOIPropertyHintEvent read FOnPropertyHint write FOnPropertyHint;
    property PropertyEditorHook: TPropertyEditorHook read FPropertyEditorHook
                                                    write SetPropertyEditorHook;
    property RowCount: integer read GetRowCount;
    property Rows[Index: integer]: TOIPropertyGridRow read GetRow;
    property RowSpacing: integer read FRowSpacing write SetRowSpacing;
    property Selection: TPersistentSelectionList read FSelection write SetSelection;
    property ShowGutter: Boolean read FShowGutter write SetShowGutter default True;
    property CheckboxForBoolean: Boolean read FCheckboxForBoolean write FCheckboxForBoolean;
    property PreferredSplitterX: integer read FPreferredSplitterX
                                         write FPreferredSplitterX default 100;
    property SplitterX: integer read FSplitterX write SetSplitterX default 100;
    property TopY: integer read FTopY write SetTopY default 0;
    property Favorites: TOIFavoriteProperties read FFavorites write SetFavorites;
    property Filter : TTypeKinds read FFilter write SetFilter;
    property HideClassNames: Boolean read FHideClassNames write FHideClassNames;
    property PropNameFilter : String read FPropNameFilter write FPropNameFilter;
  end;


  { TOIPropertyGrid }

  TOIPropertyGrid = class(TOICustomPropertyGrid)
  published
    property Align;
    property Anchors;
    property BackgroundColor;
    property BorderStyle;
    property Constraints;
    property DefaultItemHeight;
    property DefaultValueFont;
    property Indent;
    property NameFont;
    property OnChangeBounds;
    property OnClick;
    property OnDblClick;
    property OnEnter;
    property OnExit;
    property OnKeyDown;
    property OnKeyPress;
    property OnKeyUp;
    property OnModified;
    property OnMouseDown;
    property OnMouseEnter;
    property OnMouseLeave;
    property OnMouseMove;
    property OnMouseUp;
    property OnResize;
    property OnSelectionChange;
    property PopupMenu;
    property PreferredSplitterX;
    property SplitterX;
    property Tabstop;
    property ValueFont;
    property Visible;
  end;


  { TCustomPropertiesGrid }

  TCustomPropertiesGrid = class(TOICustomPropertyGrid)
  private
    FAutoFreeHook: boolean;
    FSaveOnChangeTIObject: boolean;
    function GetTIObject: TPersistent;
    procedure SetAutoFreeHook(const AValue: boolean);
    procedure SetTIObject(const AValue: TPersistent);
  public
    constructor Create(TheOwner: TComponent); override;
    destructor Destroy; override;
    property TIObject: TPersistent read GetTIObject write SetTIObject;
    property AutoFreeHook: boolean read FAutoFreeHook write SetAutoFreeHook;
    property SaveOnChangeTIObject: boolean read FSaveOnChangeTIObject
                                           write FSaveOnChangeTIObject
                                           default true;
  end;


  //============================================================================

  TAddAvailablePersistentEvent = procedure(APersistent: TPersistent;
    var Allowed: boolean) of object;
  //copy of TGetPersistentImageIndexEvent
  TOnOINodeGetImageEvent = procedure(APersistent: TPersistent;
    var AImageIndex: integer) of object;

  TOIFlag = (
    oifRebuildPropListsNeeded
    );
  TOIFlags = set of TOIFlag;

  { TObjectInspectorDlg }

  TObjectInspectorDlg = class(TForm)
    MainPopupMenu: TPopupMenu;
    AvailPersistentComboBox: TComboBox;
    ComponentPanel: TPanel;
    CompFilterLabel: TLabel;
    CompFilterEdit: TTreeFilterEdit;
    PnlClient: TPanel;
    StatusBar: TStatusBar;
    procedure FormResize(Sender: TObject);
    procedure MainPopupMenuClose(Sender: TObject);
    procedure MainPopupMenuPopup(Sender: TObject);
    procedure AvailComboBoxCloseUp(Sender: TObject);
  private
    // These are created at run-time, no need for default published section.
    PropertyPanel: TPanel;
    PropFilterPanel: TPanel;
    PropFilterLabel: TLabel;
    PropFilterEdit: TListFilterEdit;
    RestrictedPanel: TPanel;
    RestrictedInnerPanel: TPanel;
    WidgetSetsRestrictedLabel: TLabel;
    WidgetSetsRestrictedBox: TPaintBox;
    ComponentRestrictedLabel: TLabel;
    ComponentRestrictedBox: TPaintBox;
    NoteBook: TPageControl;
    Splitter1: TSplitter;
    Splitter2: TSplitter;
    // MenuItems
    AddToFavoritesPopupMenuItem: TMenuItem;
    ViewRestrictedPropertiesPopupMenuItem: TMenuItem;
    CopyPopupmenuItem: TMenuItem;
    CutPopupmenuItem: TMenuItem;
    PastePopupmenuItem: TMenuItem;
    DeletePopupmenuItem: TMenuItem;
    ChangeClassPopupmenuItem: TMenuItem;
    ChangeParentPopupmenuItem: TMenuItem;
    FindDeclarationPopupmenuItem: TMenuItem;
    OptionsSeparatorMenuItem: TMenuItem;
    OptionsSeparatorMenuItem2: TMenuItem;
    OptionsSeparatorMenuItem3: TMenuItem;
    RemoveFromFavoritesPopupMenuItem: TMenuItem;
    ShowComponentTreePopupMenuItem: TMenuItem;
    ShowPropertyFilterPopupMenuItem: TMenuItem;
    ShowHintsPopupMenuItem: TMenuItem;
    ShowInfoBoxPopupMenuItem: TMenuItem;
    ShowStatusBarPopupMenuItem: TMenuItem;
    ShowOptionsPopupMenuItem: TMenuItem;
    UndoPropertyPopupMenuItem: TMenuItem;
    // Variables
    FAutoShow: Boolean;
    FCheckboxForBoolean: Boolean;
    FComponentEditor: TBaseComponentEditor;
    FDefaultItemHeight: integer;
    FEnableHookGetSelection: boolean;
    FFavorites: TOIFavoriteProperties;
    FFilter: TTypeKinds;
    FFlags: TOIFlags;
    FInfoBoxHeight: integer;
    FLastActiveRowName: String;
    FPropertyEditorHook: TPropertyEditorHook;
    FPropFilterUpdating: Boolean;
    FRefreshingSelectionCount: integer;
    FRestricted: TOIRestrictedProperties;
    FSelection: TPersistentSelectionList;
    FSettingSelectionCount: integer;
    FShowComponentTree: Boolean;
    FShowPropertyFilter: boolean;
    FShowFavorites: Boolean;
    FShowInfoBox: Boolean;
    FShowRestricted: Boolean;
    FShowStatusBar: Boolean;
    FStateOfHintsOnMainPopupMenu: Boolean;
    FUpdateLock: integer;
    FUpdatingAvailComboBox: Boolean;
    // Events
    FOnAddAvailablePersistent: TAddAvailablePersistentEvent;
    FOnAddToFavorites: TNotifyEvent;
    FOnAutoShow: TNotifyEvent;
    FOnFindDeclarationOfProperty: TNotifyEvent;
    FOnModified: TNotifyEvent;
    FOnNodeGetImageIndex: TOnOINodeGetImageEvent;
    FOnOIKeyDown: TKeyEvent;
    FOnPropertyHint: TOIPropertyHintEvent;
    FOnRemainingKeyDown: TKeyEvent;
    FOnRemainingKeyUp: TKeyEvent;
    FOnRemoveFromFavorites: TNotifyEvent;
    FOnSelectionChange: TNotifyEvent;
    FOnSelectPersistentsInOI: TNotifyEvent;
    FOnShowOptions: TNotifyEvent;
    FOnUpdateRestricted: TNotifyEvent;
    FOnViewRestricted: TNotifyEvent;
    FLastTreeSize: TRect;

    // These event handlers are assigned at run-time, no need for default published section.
    procedure ComponentTreeDblClick(Sender: TObject);
    procedure ComponentTreeGetNodeImageIndex(APersistent: TPersistent; var AIndex: integer);
    procedure ComponentTreeKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure ComponentTreeSelectionChanged(Sender: TObject);
    procedure GridKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure GridKeyUp(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure GridDblClick(Sender: TObject);
    procedure GridModified(Sender: TObject);
    procedure GridSelectionChange(Sender: TObject);
    function GridPropertyHint(Sender: TObject; PointedRow: TOIPropertyGridRow;
      out AHint: string): boolean;
    procedure PropEditPopupClick(Sender: TObject);
    procedure AddToFavoritesPopupmenuItemClick(Sender: TObject);
    procedure RemoveFromFavoritesPopupmenuItemClick(Sender: TObject);
    procedure ViewRestrictionsPopupmenuItemClick(Sender: TObject);
    procedure UndoPopupmenuItemClick(Sender: TObject);
    procedure FindDeclarationPopupmenuItemClick(Sender: TObject);
    procedure CutPopupmenuItemClick(Sender: TObject);
    procedure CopyPopupmenuItemClick(Sender: TObject);
    procedure PastePopupmenuItemClick(Sender: TObject);
    procedure DeletePopupmenuItemClick(Sender: TObject);
    procedure ChangeClassPopupmenuItemClick(Sender: TObject);
    procedure ComponentTreeModified(Sender: TObject);
    procedure ShowComponentTreePopupMenuItemClick(Sender: TObject);
    procedure ShowPropertyFilterPopupMenuItemClick(Sender: TObject);
    procedure ShowHintPopupMenuItemClick(Sender: TObject);
    procedure ShowInfoBoxPopupMenuItemClick(Sender: TObject);
    procedure ShowStatusBarPopupMenuItemClick(Sender: TObject);
    procedure ShowOptionsPopupMenuItemClick(Sender: TObject);
    procedure RestrictedPageShow(Sender: TObject);
    procedure WidgetSetRestrictedPaint(Sender: TObject);
    procedure ComponentRestrictedPaint(Sender: TObject);
    procedure PropFilterEditAfterFilter(Sender: TObject);
    procedure NoteBookPageChange(Sender: TObject);
    procedure ChangeParentItemClick(Sender: TObject);
    procedure CollectionAddItem(Sender: TObject);
    procedure ComponentEditorVerbMenuItemClick(Sender: TObject);
    procedure ZOrderItemClick(Sender: TObject);
    procedure TopSplitterMoved(Sender: TObject);
    // Methods
    procedure DoModified;
    procedure DoUpdateRestricted;
    procedure DoViewRestricted;
    function GetComponentPanelHeight: integer;
    function GetGridControl(Page: TObjectInspectorPage): TOICustomPropertyGrid;
    function GetInfoBoxHeight: integer;
    function GetParentCandidates: TFPList;
    function GetSelectedPersistent: TPersistent;
    function GetComponentEditorForSelection: TBaseComponentEditor;
    procedure CreateBottomSplitter;
    procedure CreateTopSplitter;
    procedure DefSelectionVisibleInDesigner;
    procedure RestrictedPaint(
      ABox: TPaintBox; const ARestrictions: TWidgetSetRestrictionsArray);
    function PersistentToString(APersistent: TPersistent): string;
    procedure AddPersistentToList(APersistent: TPersistent; List: TStrings);
    procedure HookLookupRootChange;
    procedure HookRefreshPropertyValues;
    procedure FillPersistentComboBox;
    procedure SetAvailComboBoxText;
    procedure HookGetSelection(const ASelection: TPersistentSelectionList);
    procedure HookSetSelection(const ASelection: TPersistentSelectionList);
    procedure DestroyNoteBook;
    procedure CreateNoteBook;
    procedure ShowNextPage(Delta: integer);
    // Setter
    procedure SetComponentEditor(const AValue: TBaseComponentEditor);
    procedure SetComponentPanelHeight(const AValue: integer);
    procedure SetDefaultItemHeight(const AValue: integer);
    procedure SetEnableHookGetSelection(AValue: boolean);
    procedure SetFavorites(const AValue: TOIFavoriteProperties);
    procedure SetFilter(const AValue: TTypeKinds);
    procedure SetInfoBoxHeight(const AValue: integer);
    procedure SetOnShowOptions(const AValue: TNotifyEvent);
    procedure SetPropertyEditorHook(const AValue: TPropertyEditorHook);
    procedure SetRestricted(const AValue: TOIRestrictedProperties);
    procedure SetSelection(const ASelection: TPersistentSelectionList);
    procedure SetShowComponentTree(const AValue: boolean);
    procedure SetShowPropertyFilter(const AValue: Boolean);
    procedure SetShowFavorites(const AValue: Boolean);
    procedure SetShowInfoBox(const AValue: Boolean);
    procedure SetShowRestricted(const AValue: Boolean);
    procedure SetShowStatusBar(const AValue: Boolean);
  protected
    function CanDeleteSelection: Boolean;
    procedure KeyDown(var Key: Word; Shift: TShiftState); override;
    procedure KeyUp(var Key: Word; Shift: TShiftState); override;
    procedure Resize; override;
  public
    // These are created at run-time, no need for default published section.
    ComponentTree: TComponentTreeView;
    InfoPanel: TPanel;
    EventGrid: TOICustomPropertyGrid;
    FavoriteGrid: TOICustomPropertyGrid;
    RestrictedGrid: TOICustomPropertyGrid;
    PropertyGrid: TOICustomPropertyGrid;
    //
    constructor Create(AnOwner: TComponent); override;
    destructor Destroy; override;
    procedure RefreshSelection;
    procedure RefreshComponentTreeSelection;
    procedure SaveChanges;
    procedure RefreshPropertyValues;
    procedure RebuildPropertyLists;
    procedure ChangeCompZOrderInList(APersistent: TPersistent; AZOrder: TZOrderDelete);
    procedure DeleteCompFromList(APersistent: TPersistent);
    procedure FillComponentList(AWholeTree: Boolean);
    procedure UpdateComponentValues;
    procedure BeginUpdate;
    procedure EndUpdate;
    function GetActivePropertyGrid: TOICustomPropertyGrid;
    function GetActivePropertyRow: TOIPropertyGridRow;
    function GetCurRowDefaultValue(var DefaultStr: string): Boolean;
    function HasParentCandidates: Boolean;
    procedure ChangeParent;
    procedure ActivateGrid(Grid: TOICustomPropertyGrid);
    procedure FocusGrid(Grid: TOICustomPropertyGrid = nil);
  public
    property ComponentEditor: TBaseComponentEditor read FComponentEditor write SetComponentEditor;
    property ComponentPanelHeight: integer read GetComponentPanelHeight
                                          write SetComponentPanelHeight;
    property DefaultItemHeight: integer read FDefaultItemHeight
                                        write SetDefaultItemHeight;
    property EnableHookGetSelection: Boolean read FEnableHookGetSelection
                                             write SetEnableHookGetSelection;
    property Favorites: TOIFavoriteProperties read FFavorites write SetFavorites;
    property Filter: TTypeKinds read FFilter write SetFilter;
    property GridControl[Page: TObjectInspectorPage]: TOICustomPropertyGrid
                                                            read GetGridControl;
    property InfoBoxHeight: integer read GetInfoBoxHeight write SetInfoBoxHeight;
    property PropertyEditorHook: TPropertyEditorHook read FPropertyEditorHook
                                                    write SetPropertyEditorHook;
    property RestrictedProps: TOIRestrictedProperties read FRestricted write SetRestricted;
    property Selection: TPersistentSelectionList read FSelection write SetSelection;
    property AutoShow: Boolean read FAutoShow write FAutoShow;
    property ShowComponentTree: Boolean read FShowComponentTree write SetShowComponentTree;
    property ShowPropertyFilter: boolean read FShowPropertyFilter write SetShowPropertyFilter;
    property ShowFavorites: Boolean read FShowFavorites write SetShowFavorites;
    property ShowInfoBox: Boolean read FShowInfoBox write SetShowInfoBox;
    property ShowRestricted: Boolean read FShowRestricted write SetShowRestricted;
    property ShowStatusBar: Boolean read FShowStatusBar write SetShowStatusBar;
    property LastActiveRowName: string read FLastActiveRowName;
    // Events
    property OnAddAvailPersistent: TAddAvailablePersistentEvent
                 read FOnAddAvailablePersistent write FOnAddAvailablePersistent;
    property OnAddToFavorites: TNotifyEvent read FOnAddToFavorites write FOnAddToFavorites;
    property OnAutoShow: TNotifyEvent read FOnAutoShow write FOnAutoShow;
    property OnFindDeclarationOfProperty: TNotifyEvent read FOnFindDeclarationOfProperty
                                                      write FOnFindDeclarationOfProperty;
    property OnModified: TNotifyEvent read FOnModified write FOnModified;
    property OnOIKeyDown: TKeyEvent read FOnOIKeyDown write FOnOIKeyDown;
    property OnPropertyHint: TOIPropertyHintEvent read FOnPropertyHint write FOnPropertyHint;
    property OnRemainingKeyDown: TKeyEvent read FOnRemainingKeyDown
                                         write FOnRemainingKeyDown;
    property OnRemainingKeyUp: TKeyEvent read FOnRemainingKeyUp
                                         write FOnRemainingKeyUp;
    property OnRemoveFromFavorites: TNotifyEvent read FOnRemoveFromFavorites
                                                  write FOnRemoveFromFavorites;
    property OnSelectionChange: TNotifyEvent read FOnSelectionChange write FOnSelectionChange;
    property OnSelectPersistentsInOI: TNotifyEvent read FOnSelectPersistentsInOI
                                                  write FOnSelectPersistentsInOI;
    property OnShowOptions: TNotifyEvent read FOnShowOptions write SetOnShowOptions;
    property OnUpdateRestricted: TNotifyEvent read FOnUpdateRestricted
                                         write FOnUpdateRestricted;
    property OnViewRestricted: TNotifyEvent read FOnViewRestricted write FOnViewRestricted;
    property OnNodeGetImageIndex : TOnOINodeGetImageEvent read FOnNodeGetImageIndex
                                                         write FOnNodeGetImageIndex;
  end;

const
  DefaultObjectInspectorName: string = 'ObjectInspectorDlg';

// the ObjectInspector descendant of the IDE can be found in FormEditingIntf

function dbgs(s: TOIPropertyGridState): string; overload;
function dbgs(States: TOIPropertyGridStates): string; overload;

function GetChangeParentCandidates(PropertyEditorHook: TPropertyEditorHook;
  Selection: TPersistentSelectionList): TFPList;

const
  DefaultOIPageNames: array[TObjectInspectorPage] of shortstring = (
    'PropertyPage',
    'EventPage',
    'FavoritePage',
    'RestrictedPage'
    );
  DefaultOIGridNames: array[TObjectInspectorPage] of shortstring = (
    'PropertyGrid',
    'EventGrid',
    'FavoriteGrid',
    'RestrictedGrid'
    );

implementation

{$R *.lfm}
{$R images\ideintf_images.res}

function SortGridRows(Item1, Item2 : pointer) : integer;
begin
  Result:=CompareText(TOIPropertyGridRow(Item1).Name,
                      TOIPropertyGridRow(Item2).Name);
end;

function dbgs(s: TOIPropertyGridState): string;
begin
  Result:=GetEnumName(TypeInfo(s),ord(s));
end;

function dbgs(States: TOIPropertyGridStates): string;
var
  s: TOIPropertyGridState;
begin
  Result:='';
  for s in States do
  begin
    if not (s in States) then continue;
    if Result<>'' then Result+=',';
    Result+=dbgs(s);
  end;
  Result:='['+Result+']';
end;

function GetChangeParentCandidates(PropertyEditorHook: TPropertyEditorHook;
  Selection: TPersistentSelectionList): TFPList;

  function CanBeParent(Child, Parent: TPersistent): boolean;
  begin
    Result:=false;
    if Child = Parent then exit;
    if not (Parent is TWinControl) then exit;
    if not (Child is TControl) then exit;
    if (Child is TWinControl) and
       (Child = TWinControl(Parent).Parent) then
      exit;
    if not ControlAcceptsStreamableChildComponent(TWinControl(Parent),
             TComponentClass(Child.ClassType), PropertyEditorHook.LookupRoot)
    then
      exit;
    try
      TControl(Child).CheckNewParent(TWinControl(Parent));
    except
      exit;
    end;
    Result:=true;
  end;

  function CanBeParentOfSelection(Parent: TPersistent): boolean;
  var
    i: Integer;
  begin
    for i:=0 to Selection.Count-1 do
      if not CanBeParent(Selection[i],Parent) then exit(false);
    Result:=true;
  end;

var
  i: Integer;
  Candidate: TWinControl;
begin
  Result := TFPList.Create;
  if not (PropertyEditorHook.LookupRoot is TWinControl) then
    exit; // only LCL controls are supported at the moment

  // check if any selected control can be moved
  i := Selection.Count-1;
  while i >= 0 do
  begin
    if (Selection[i] is TControl)
    and (TControl(Selection[i]).Owner = PropertyEditorHook.LookupRoot)
    then
      // this one can be moved
      break;
    dec(i);
  end;
  if i < 0 then Exit;

  // find possible new parents
  for i := 0 to TWinControl(PropertyEditorHook.LookupRoot).ComponentCount-1 do
  begin
    Candidate := TWinControl(TWinControl(PropertyEditorHook.LookupRoot).Components[i]);
    if CanBeParentOfSelection(Candidate) then
      Result.Add(Candidate);
  end;
  if CanBeParentOfSelection(PropertyEditorHook.LookupRoot) then
    Result.Add(PropertyEditorHook.LookupRoot);
end;

{ TOICustomPropertyGrid }

constructor TOICustomPropertyGrid.CreateWithParams(AnOwner:TComponent;
  APropertyEditorHook:TPropertyEditorHook; TypeFilter:TTypeKinds; DefItemHeight: integer);
var
  Details: TThemedElementDetails;
begin
  inherited Create(AnOwner);
  FLayout := oilHorizontal;

  FSelection:=TPersistentSelectionList.Create;
  FNotificationComponents:=TFPList.Create;
  PropertyEditorHook:=APropertyEditorHook;  // Through property setter.
  FFilter:=TypeFilter;
  FItemIndex:=-1;
  FStates:=[];
  FColumn := oipgcValue;
  FRows:=TFPList.Create;
  FExpandingRow:=nil;
  FDragging:=false;
  FExpandedProperties:=TStringList.Create;
  FCurrentEdit:=nil;
  FCurrentButton:=nil;

  // visible values
  FTopY:=0;
  FSplitterX:=100;
  FPreferredSplitterX:=FSplitterX;
  Details := ThemeServices.GetElementDetails(ttGlyphOpened);
  FIndent := ThemeServices.GetDetailSize(Details).cx;

  FBackgroundColor:=DefBackgroundColor;
  FReferencesColor:=DefReferencesColor;
  FSubPropertiesColor:=DefSubPropertiesColor;
  FReadOnlyColor:=DefReadOnlyColor;
  FHighlightColor:=DefHighlightColor;
  FGutterColor:=DefGutterColor;
  FGutterEdgeColor:=DefGutterEdgeColor;
  FValueDifferBackgrndColor:=DefValueDifferBackgrndColor;

  FNameFont:=TFont.Create;
  FNameFont.Color:=DefNameColor;
  FValueFont:=TFont.Create;
  FValueFont.Color:=DefValueColor;
  FDefaultValueFont:=TFont.Create;
  FDefaultValueFont.Color:=DefDefaultValueColor;
  FHighlightFont:=TFont.Create;
  FHighlightFont.Color:=DefHighlightFontColor;

  FDrawHorzGridLines := True;
  FShowGutter := True;

  SetInitialBounds(0,0,200,130);
  ControlStyle:=ControlStyle+[csAcceptsControls,csOpaque];
  BorderWidth:=0;
  BorderStyle := bsSingle;

  // create sub components
  ValueEdit:=TEdit.Create(Self);
  with ValueEdit do
  begin
    Name:='ValueEdit';
    Visible:=false;
    Enabled:=false;
    AutoSize:=false;
    SetBounds(0,-30,80,25); // hidden
    Parent:=Self;
    OnMouseDown := @ValueControlMouseDown;
    OnMouseMove := @ValueControlMouseMove;
    OnDblClick := @ValueEditDblClick;
    OnExit:=@ValueEditExit;
    OnChange:=@ValueEditChange;
    OnKeyDown:=@ValueEditKeyDown;
    OnKeyUp:=@ValueEditKeyUp;
    OnMouseUp:=@ValueEditMouseUp;
    OnMouseWheel:=@OnGridMouseWheel;
  end;

  ValueComboBox:=TComboBox.Create(Self);
  with ValueComboBox do
  begin
    Name:='ValueComboBox';
    Sorted:=true;
    AutoSelect:=true;
    AutoComplete:=true;
    Visible:=false;
    Enabled:=false;
    AutoSize:=false;
    SetBounds(0,-30,Width,Height); // hidden
    DropDownCount:=20;
    ItemHeight:=MulDiv(17, Screen.PixelsPerInch, 96);
    Parent:=Self;
    OnMouseDown := @ValueControlMouseDown;
    OnMouseMove := @ValueControlMouseMove;
    OnDblClick := @ValueEditDblClick;
    OnExit:=@ValueComboBoxExit;
    //OnChange:=@ValueComboBoxChange; the on change event is called even,
                                   // if the user is still editing
    OnKeyDown:=@ValueComboBoxKeyDown;
    OnKeyUp:=@ValueComboBoxKeyUp;
    OnMouseUp:=@ValueComboBoxMouseUp;
    OnGetItems:=@ValueComboBoxGetItems;
    OnCloseUp:=@ValueComboBoxCloseUp;
    OnMeasureItem:=@ValueComboBoxMeasureItem;
    OnDrawItem:=@ValueComboBoxDrawItem;
    OnMouseWheel:=@OnGridMouseWheel;
  end;

  ValueCheckBox:={$IFnDEF UseOINormalCheckBox} TCheckBoxThemed.Create(Self); {$ELSE} TCheckBox.Create(Self); {$ENDIF}
  with ValueCheckBox do
  begin
    Name:='ValueCheckBox';
    Visible:=false;
    Enabled:=false;
    {$IFnDEF UseOINormalCheckBox}
    AutoSize := false;
    {$ELSE}
    AutoSize := true;    // SetBounds does not work for CheckBox, AutoSize does.
    {$ENDIF}
    Parent:=Self;
    Top := -30;
    OnMouseDown := @ValueControlMouseDown;
    OnMouseMove := @ValueControlMouseMove;
    OnExit:=@ValueCheckBoxExit;
    OnKeyDown:=@ValueCheckBoxKeyDown;
    OnKeyUp:=@ValueCheckBoxKeyUp;
    OnClick:=@ValueCheckBoxClick;
    OnMouseWheel:=@OnGridMouseWheel;
  end;

  ValueButton:=TSpeedButton.Create(Self);
  with ValueButton do
  begin
    Name:='ValueButton';
    Visible:=false;
    Enabled:=false;
    Transparent:=false;
    OnClick:=@ValueButtonClick;
    Caption := '...';
    SetBounds(0,-30,Width,Height); // hidden
    Parent:=Self;
    OnMouseWheel:=@OnGridMouseWheel;
  end;

  FHintManager := THintWindowManager.Create;
  FActiveRowImages := TLCLGlyphs.Create(Self);
  FActiveRowImages.Width := 9;
  FActiveRowImages.Height := 9;
  FActiveRowImages.RegisterResolutions([9, 13, 18], [100, 150, 200]);
  FActiveRowImages.OnGetWidthForPPI := @ActiveRowImagesGetWidthForPPI;

  FDefaultItemHeight:=DefItemHeight;

  BuildPropertyList;
end;

procedure TOICustomPropertyGrid.ActiveRowImagesGetWidthForPPI(
  Sender: TCustomImageList; AImageWidth, APPI: Integer;
  var AResultWidth: Integer);
begin
  if (12<=AResultWidth) and (AResultWidth<=16) then
    AResultWidth := 13;
end;

constructor TOICustomPropertyGrid.Create(TheOwner: TComponent);
begin
  CreateWithParams(TheOwner,nil,AllTypeKinds,0);
end;

destructor TOICustomPropertyGrid.Destroy;
var
  a: integer;
begin
  SetIdleEvent(false);
  FItemIndex := -1;
  for a := 0 to FRows.Count - 1 do
    Rows[a].Free;
  FreeAndNil(FRows);
  FreeAndNil(FSelection);
  FreeAndNil(FNotificationComponents);
  FreeAndNil(FValueFont);
  FreeAndNil(FDefaultValueFont);
  FreeAndNil(FNameFont);
  FreeAndNil(FHighlightFont);
  FreeAndNil(FExpandedProperties);
  FreeAndNil(FLongHintTimer);
  FreeAndNil(FHintManager);
  FreeAndNil(FNewComboBoxItems);
  inherited Destroy;
end;

procedure TOICustomPropertyGrid.UpdateScrollBar;
var
  ScrollInfo: TScrollInfo;
  ATopMax: Integer;
begin
  if HandleAllocated then begin
    ATopMax := TopMax;
    ScrollInfo.cbSize := SizeOf(ScrollInfo);
    ScrollInfo.fMask := SIF_ALL or SIF_DISABLENOSCROLL;
    ScrollInfo.nMin := 0;
    ScrollInfo.nTrackPos := 0;
    ScrollInfo.nMax := ATopMax+ClientHeight-1;
    if ClientHeight < 2 then
      ScrollInfo.nPage := 1
    else
      ScrollInfo.nPage := ClientHeight-1;
    if TopY > ATopMax then
      TopY := ATopMax;
    ScrollInfo.nPos := TopY;
    SetScrollInfo(Handle, SB_VERT, ScrollInfo, True);
  end;
end;

function TOICustomPropertyGrid.FillComboboxItems: boolean;
var
  ExcludeUpdateFlag: boolean;
  CurRow: TOIPropertyGridRow;
begin
  Result:=false;
  ExcludeUpdateFlag:=not (pgsUpdatingEditControl in FStates);
  Include(FStates,pgsUpdatingEditControl);
  ValueComboBox.Items.BeginUpdate;
  try
    CurRow:=Rows[FItemIndex];
    if FNewComboBoxItems<>nil then FNewComboBoxItems.Clear;
    CurRow.Editor.GetValues(@AddStringToComboBox);
    if FNewComboBoxItems<>nil then begin
      FNewComboBoxItems.Sorted:=paSortList in CurRow.Editor.GetAttributes;
      if ValueComboBox.Items.Equals(FNewComboBoxItems) then exit;
      ValueComboBox.Items.Assign(FNewComboBoxItems);
      //debugln('TOICustomPropertyGrid.FillComboboxItems "',FNewComboBoxItems.Text,'" Cur="',ValueComboBox.Items.Text,'" ValueComboBox.Items.Count=',dbgs(ValueComboBox.Items.Count));
    end else if ValueComboBox.Items.Count=0 then begin
      exit;
    end else begin
      ValueComboBox.Items.Text:='';
      ValueComboBox.Items.Clear;
      //debugln('TOICustomPropertyGrid.FillComboboxItems FNewComboBoxItems=nil Cur="',ValueComboBox.Items.Text,'" ValueComboBox.Items.Count=',dbgs(ValueComboBox.Items.Count));
    end;
    Result:=true;
    //debugln(['TOICustomPropertyGrid.FillComboboxItems CHANGED']);
  finally
    FreeAndNil(FNewComboBoxItems);
    ValueComboBox.Items.EndUpdate;
    if ExcludeUpdateFlag then
      Exclude(FStates,pgsUpdatingEditControl);
  end;
end;

procedure TOICustomPropertyGrid.CreateParams(var Params: TCreateParams);
const
  ClassStylesOff = CS_VREDRAW or CS_HREDRAW;
begin
  inherited CreateParams(Params);
  with Params do begin
    {$IFOPT R+}{$DEFINE RangeChecking}{$ENDIF}
    {$R-}
    WindowClass.Style := WindowClass.Style and not ClassStylesOff;
    Style := Style or WS_VSCROLL or WS_CLIPCHILDREN;
    {$IFDEF RangeChecking}{$R+}{$UNDEF RangeChecking}{$ENDIF}
    ExStyle := ExStyle or WS_EX_CLIENTEDGE;
  end;
end;

procedure TOICustomPropertyGrid.CreateWnd;
begin
  inherited CreateWnd;
  // handle just created, set scrollbar
  ShowScrollBar(Handle, SB_VERT, True);
  UpdateScrollBar;
end;

procedure TOICustomPropertyGrid.Notification(AComponent: TComponent;
  Operation: TOperation);
var
  i: LongInt;
begin
  if (Operation=opRemove) and (FNotificationComponents<>nil) then begin
    FNotificationComponents.Remove(AComponent);
    i:=FSelection.IndexOf(AComponent);
    if i>=0 then begin
      FSelection.Delete(i);
      Include(FStates,pgsBuildPropertyListNeeded);
    end;
  end;
  inherited Notification(AComponent, Operation);
end;

procedure TOICustomPropertyGrid.WMVScroll(var Msg: TLMScroll);
begin
  case Msg.ScrollCode of
      // Scrolls to start / end of the text
    SB_TOP:        TopY := 0;
    SB_BOTTOM:     TopY := TopMax;
      // Scrolls one line up / down
    SB_LINEDOWN:   TopY := TopY + RealDefaultItemHeight div 2;
    SB_LINEUP:     TopY := TopY - RealDefaultItemHeight div 2;
      // Scrolls one page of lines up / down
    SB_PAGEDOWN:   TopY := TopY + ClientHeight - RealDefaultItemHeight;
    SB_PAGEUP:     TopY := TopY - ClientHeight + RealDefaultItemHeight;
      // Scrolls to the current scroll bar position
    SB_THUMBPOSITION,
    SB_THUMBTRACK: TopY := Msg.Pos;
      // Ends scrolling
    SB_ENDSCROLL:  SetCaptureControl(nil); // release scrollbar capture
  end;
end;

function TOICustomPropertyGrid.DoMouseWheel(Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint): Boolean;
var
  H: Boolean;
begin
  H := False;
  OnGridMouseWheel(Self, Shift, WheelDelta, MousePos, H);
  Result:=true;
end;

procedure TOICustomPropertyGrid.OnGridMouseWheel(Sender: TObject; Shift: TShiftState;
      WheelDelta: Integer; MousePos: TPoint; var Handled: Boolean);
begin
  if Mouse.WheelScrollLines=-1 then
    // -1 : scroll by page
    TopY := TopY - (WheelDelta * (ClientHeight - RealDefaultItemHeight)) div 120
  else
    // scrolling one line -> scroll half an item, see SB_LINEDOWN and SB_LINEUP
    // handler in WMVScroll
    TopY := TopY - (WheelDelta * Mouse.WheelScrollLines*RealDefaultItemHeight) div 240;
  Handled := True;
end;

function TOICustomPropertyGrid.IsCurrentEditorAvailable: Boolean;
begin
  Result := (FCurrentEdit <> nil) and InRange(FItemIndex, 0, FRows.Count - 1);
end;

procedure TOICustomPropertyGrid.FocusCurrentEditor;
begin
  if (IsCurrentEditorAvailable) and (FCurrentEdit.CanFocus) then
  begin
    FCurrentEdit.SetFocus;
    if (FCurrentEdit is TEdit) then
      TEdit(FCurrentEdit).SelStart := Length((FCurrentEdit as TEdit).Text);
  end;
end;

function TOICustomPropertyGrid.ConsistencyCheck: integer;
var
  i: integer;
begin
  for i:=0 to FRows.Count-1 do
  begin
    if Rows[i]=nil then
      Exit(-1);
    if Rows[i].Index<>i then
      Exit(-2);
    Result:=Rows[i].ConsistencyCheck;
    if Result<>0 then
      Exit(Result-100);
  end;
  Result:=0;
end;

procedure TOICustomPropertyGrid.SetSelection(const ASelection: TPersistentSelectionList);
var
  CurRow:TOIPropertyGridRow;
  OldSelectedRowPath:string;
begin
  if ASelection=nil then exit;
  if (not ASelection.ForceUpdate) and FSelection.IsEqual(ASelection) then exit;

  OldSelectedRowPath:=PropertyPath(ItemIndex);
  if FCurrentEdit = ValueEdit then
    ValueEditExit(Self);
  ItemIndex:=-1;
  ClearRows;
  FSelection.Assign(ASelection);
  UpdateSelectionNotifications;
  BuildPropertyList;
  CurRow:=GetRowByPath(OldSelectedRowPath);
  if CurRow<>nil then
    ItemIndex:=CurRow.Index;
  Column := oipgcValue;
end;

procedure TOICustomPropertyGrid.SetPropertyEditorHook(
  NewPropertyEditorHook:TPropertyEditorHook);
begin
  if FPropertyEditorHook=NewPropertyEditorHook then exit;
  FPropertyEditorHook:=NewPropertyEditorHook;
  IncreaseChangeStep;
  SetSelection(FSelection);
end;

procedure TOICustomPropertyGrid.UpdateSelectionNotifications;
var
  i: Integer;
  AComponent: TComponent;
begin
  for i:=0 to FSelection.Count-1 do begin
    if FSelection[i] is TComponent then begin
      AComponent:=TComponent(FSelection[i]);
      if FNotificationComponents.IndexOf(AComponent)<0 then begin
        FNotificationComponents.Add(AComponent);
        AComponent.FreeNotification(Self);
      end;
    end;
  end;
  for i:=FNotificationComponents.Count-1 downto 0 do begin
    AComponent:=TComponent(FNotificationComponents[i]);
    if FSelection.IndexOf(AComponent)<0 then begin
      FNotificationComponents.Delete(i);
      AComponent.RemoveFreeNotification(Self);
    end;
  end;
  //DebugLn(['TOICustomPropertyGrid.UpdateSelectionNotifications FNotificationComponents=',FNotificationComponents.Count,' FSelection=',FSelection.Count]);
end;

procedure TOICustomPropertyGrid.HookGetCheckboxForBoolean(var Value: Boolean);
begin
  Value := FCheckboxForBoolean;
end;

function TOICustomPropertyGrid.PropertyPath(Index:integer):string;
begin
  if (Index>=0) and (Index<FRows.Count) then
    Result:=PropertyPath(Rows[Index])
  else
    Result:='';
end;

function TOICustomPropertyGrid.PropertyPath(Row: TOIPropertyGridRow): string;
begin
  if Row=nil then
    Exit('');
  Result:=Row.Name;
  Row:=Row.Parent;
  while Row<>nil do begin
    Result:=Row.Name+'.'+Result;
    Row:=Row.Parent;
  end;
end;

function TOICustomPropertyGrid.PropertyEditorByName(const PropName: string): TPropertyEditor;
var
  AOIPropertyGridRow: TOIPropertyGridRow;
  i: Integer;
begin
  Result := nil;
  for i := 0 to FRows.Count - 1 do
  begin
    AOIPropertyGridRow := TOIPropertyGridRow(FRows[i]);
    if Assigned(AOIPropertyGridRow.Editor) and (AOIPropertyGridRow.Editor.GetName = PropName) then
      Exit(AOIPropertyGridRow.Editor);
  end;
end;

function TOICustomPropertyGrid.RealDefaultItemHeight: integer;
begin
  Result := FDefaultItemHeight;
  if (Result<=0) then
    Result := Canvas.TextHeight('Hg')*5 div 4 + 4;
end;

function TOICustomPropertyGrid.GetRowByPath(const PropPath: string): TOIPropertyGridRow;
// searches PropPath. Expands automatically parent rows
var
  CurName:string;
  s,e:integer;
  CurParentRow:TOIPropertyGridRow;
begin
  Result:=nil;
  if (PropPath='') or (FRows.Count=0) then exit;
  CurParentRow:=nil;
  s:=1;
  while (s<=length(PropPath)) do begin
    e:=s;
    while (e<=length(PropPath)) and (PropPath[e]<>'.') do inc(e);
    CurName:=copy(PropPath,s,e-s);
    s:=e+1;
    // search name in children
    if CurParentRow=nil then
      Result:=Rows[0]
    else
      Result:=CurParentRow.FirstChild;
    while (Result<>nil) and (CompareText(Result.Name, CurName)<>0) do
      Result:=Result.NextBrother;
    if Result=nil then begin
      exit;
    end else begin
      // expand row
      CurParentRow:=Result;
      if s<=length(PropPath) then
        ExpandRow(CurParentRow.Index);
    end;
  end;
  if s<=length(PropPath) then Result:=nil;
end;

procedure TOICustomPropertyGrid.SetRowValue(CheckFocus, ForceValue: boolean);

  function GetPropValue(Editor: TPropertyEditor; Index: integer): string;
  var
    PropKind: TTypeKind;
    PropInfo: PPropInfo;
    BoolVal: Boolean;
  begin
    Result:='';
    PropInfo := Editor.GetPropInfo;
    PropKind := PropInfo^.PropType^.Kind;
    case PropKind of
      tkInteger, tkInt64:
        Result := IntToStr(Editor.GetInt64ValueAt(Index));
      tkChar, tkWChar, tkUChar:
        Result := Char(Editor.GetOrdValueAt(Index));
      tkEnumeration:
        Result := GetEnumName(PropInfo^.PropType, Editor.GetOrdValueAt(Index));
      tkFloat:
        Result := FloatToStr(Editor.GetFloatValueAt(Index));
      tkBool: begin
        BoolVal := Boolean(Editor.GetOrdValueAt(Index));
        if FCheckboxForBoolean then
          Result := BoolToStr(BoolVal, '(True)', '(False)')
        else
          Result := BoolToStr(BoolVal, 'True', 'False');
      end;
      tkString, tkLString, tkAString, tkUString, tkWString:
        Result := Editor.GetStrValueAt(Index);
      tkSet:
        Result := Editor.GetSetValueAt(Index,true);
      tkVariant:
        if Editor.GetVarValueAt(Index) <> Null then
          Result := Editor.GetVarValueAt(Index)
        else
          Result := '(Null)';
    end;
  end;

var
  CurRow: TOIPropertyGridRow;
  NewValue: string;
  OldExpanded: boolean;
  OldChangeStep: integer;
  RootDesigner: TIDesigner;
  CompEditDsg: TComponentEditorDesigner;
  APersistent: TPersistent;
  i: integer;
  UndoVal: string;
  OldUndoValues: array of string;
  isExcept: boolean;
  prpInfo: PPropInfo;
  Editor: TPropertyEditor;
begin
  //if FItemIndex > -1 then
  //  debugln(['TOICustomPropertyGrid.SetRowValue A, FItemIndex=',dbgs(FItemIndex),
  //    ', CanEditRowValue=', CanEditRowValue(CheckFocus), ', IsReadOnly=', Rows[FItemIndex].IsReadOnly]);

  if not CanEditRowValue(CheckFocus) or Rows[FItemIndex].IsReadOnly then exit;

  NewValue:=GetCurrentEditValue;
  CurRow:=Rows[FItemIndex];
  if length(NewValue)>CurRow.Editor.GetEditLimit then
    NewValue:=LeftStr(NewValue,CurRow.Editor.GetEditLimit);

  //DebugLn(['TOICustomPropertyGrid.SetRowValue Old="',CurRow.Editor.GetVisualValue,'" New="',NewValue,'"']);
  if (CurRow.Editor.GetVisualValue=NewValue) and not ForceValue then exit;

  RootDesigner := FindRootDesigner(FCurrentEditorLookupRoot);
  if (RootDesigner is TComponentEditorDesigner) then begin
    CompEditDsg := TComponentEditorDesigner(RootDesigner);
    if CompEditDsg.IsUndoLocked then Exit;
  end else
    CompEditDsg := nil;

  // store old values for undo
  isExcept := false;
  Editor:=CurRow.Editor;
  prpInfo := nil;
  if (CompEditDsg<>nil) and (paRevertable in Editor.GetAttributes) then begin
    SetLength(OldUndoValues, Editor.PropCount);
    prpInfo := Editor.GetPropInfo;
    if prpInfo<>nil then
      for i := 0 to Editor.PropCount - 1 do
        OldUndoValues[i] := GetPropValue(Editor,i);
  end;

  OldChangeStep:=fChangeStep;
  Include(FStates,pgsApplyingValue);
  try
    {$IFNDEF DoNotCatchOIExceptions}
    try
    {$ENDIF}
      //debugln(['TOICustomPropertyGrid.SetRowValue B ClassName=',CurRow.Editor.ClassName,' Visual="',CurRow.Editor.GetVisualValue,'" NewValue="',NewValue,'" AllEqual=',CurRow.Editor.AllEqual]);
      CurRow.Editor.SetValue(NewValue);
      //debugln(['TOICustomPropertyGrid.SetRowValue C ClassName=',CurRow.Editor.ClassName,' Visual="',CurRow.Editor.GetVisualValue,'" NewValue="',NewValue,'" AllEqual=',CurRow.Editor.AllEqual]);
    {$IFNDEF DoNotCatchOIExceptions}
    except
      on E: Exception do begin
        MessageDlg(oisError, E.Message + ' with value "'+NewValue+'"', mtError, [mbOk], 0);
        isExcept := true;
      end;
    end;
    {$ENDIF}
    if (OldChangeStep<>FChangeStep) then begin
      // the selection has changed => CurRow does not exist any more
      exit;
    end;

    // add Undo action
    if (not isExcept) and (CompEditDsg<>nil) and (paRevertable in Editor.GetAttributes) then
    begin
      for i := 0 to Editor.PropCount - 1 do
      begin
        APersistent := Editor.GetComponent(i);
        if APersistent=nil then continue;
        UndoVal := GetPropValue(Editor,i);
        CompEditDsg.AddUndoAction(APersistent, uopChange, i = 0,
            Editor.GetName, OldUndoValues[i], UndoVal);
      end;
    end;

    // set value in edit control
    SetCurrentEditValue(Editor.GetVisualValue);

    // update volatile sub properties
    if (paVolatileSubProperties in Editor.GetAttributes)
    and ((CurRow.Expanded) or (CurRow.ChildCount>0)) then begin
      OldExpanded:=CurRow.Expanded;
      ShrinkRow(FItemIndex);
      if OldExpanded then
        ExpandRow(FItemIndex);
    end;
    //debugln(['TOICustomPropertyGrid.SetRowValue D ClassName=',CurRow.Editor.ClassName,' Visual="',CurRow.Editor.GetVisualValue,'" NewValue="',NewValue,'" AllEqual=',CurRow.Editor.AllEqual]);
  finally
    Exclude(FStates,pgsApplyingValue);
  end;
  if Assigned(FPropertyEditorHook) then
    FPropertyEditorHook.RefreshPropertyValues;
  if Assigned(FOnModified) then
    FOnModified(Self);
end;

procedure TOICustomPropertyGrid.DoCallEdit(Edit: TOIQuickEdit);
var
  CurRow:TOIPropertyGridRow;
  OldChangeStep: integer;
begin
  //debugln(['TOICustomPropertyGrid.DoCallEdit ',dbgs(GetFocus),' ',DbgSName(FindControl(GetFocus))]);
  if not CanEditRowValue(false) then exit;

  OldChangeStep:=fChangeStep;
  CurRow:=Rows[FItemIndex];
  if paDialog in CurRow.Editor.GetAttributes then begin
    {$IFnDEF DoNotCatchOIExceptions}
    try
    {$ENDIF}
      //if FSelection.Count > 0 then
      //  DebugLn(['# TOICustomPropertyGrid.DoCallEdit for ', CurRow.Editor.ClassName,
      //           ', Edit=', Edit=oiqeEdit, ', SelectionCount=', FSelection.Count,
      //           ', SelectionName=', FSelection[0].GetNamePath]);
      Include(FStates,pgsCallingEdit);
      try
        if Edit=oiqeShowValue then
          CurRow.Editor.ShowValue
        else if (FSelection.Count > 0) and (FSelection[0] is TComponent) then
          CurRow.Editor.Edit(TComponent(FSelection[0]))
        else
          CurRow.Editor.Edit;
      finally
        Exclude(FStates,pgsCallingEdit);
      end;
    {$IFnDEF DoNotCatchOIExceptions}
    except
      on E: Exception do
        MessageDlg(oisError, E.Message, mtError, [mbOk], 0);
    end;
    {$ENDIF}
    // CurRow is now invalid, do not access CurRow

    if (OldChangeStep<>FChangeStep) then begin
      // the selection has changed => CurRow does not exist any more
      RefreshPropertyValues;
      exit;
    end;
    RefreshValueEdit;       // update value
    Invalidate;             //invalidate changed subproperties
  end;
end;

procedure TOICustomPropertyGrid.RefreshValueEdit;
var
  CurRow: TOIPropertyGridRow;
  NewValue: string;
begin
  if not GridIsUpdating and IsCurrentEditorAvailable then begin
    CurRow:=Rows[FItemIndex];
    NewValue:=CurRow.Editor.GetVisualValue;
    {$IFDEF LCLCarbon}
    NewValue:=StringReplace(NewValue,LineEnding,LineFeedSymbolUTF8,[rfReplaceAll]);
    {$ENDIF}
    SetCurrentEditValue(NewValue);
  end;
end;

procedure TOICustomPropertyGrid.ValueEditKeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
  ScrollToActiveItem;
  HandleStandardKeys(Key,Shift);
end;

procedure TOICustomPropertyGrid.ValueEditKeyUp(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
  HandleKeyUp(Key,Shift);
end;

procedure TOICustomPropertyGrid.ValueEditExit(Sender: TObject);
begin
  SetRowValue(false, false);
end;

procedure TOICustomPropertyGrid.ValueEditChange(Sender: TObject);
var CurRow: TOIPropertyGridRow;
begin
  if (pgsUpdatingEditControl in FStates) or not IsCurrentEditorAvailable then exit;
  CurRow:=Rows[FItemIndex];
  if paAutoUpdate in CurRow.Editor.GetAttributes then
    SetRowValue(true, true);
end;

procedure TOICustomPropertyGrid.ValueEditMouseUp(Sender: TObject;
  Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  if (Button=mbLeft) and (Shift=[ssCtrl,ssLeft]) then
    DoCallEdit(oiqeShowValue);
end;

procedure TOICustomPropertyGrid.ValueCheckBoxKeyDown(Sender: TObject;
  var Key: Word; Shift: TShiftState);
begin
  ScrollToActiveItem;
  HandleStandardKeys(Key,Shift);
end;

procedure TOICustomPropertyGrid.ValueCheckBoxKeyUp(Sender: TObject;
  var Key: Word; Shift: TShiftState);
begin
  HandleKeyUp(Key,Shift);
end;

procedure TOICustomPropertyGrid.ValueCheckBoxExit(Sender: TObject);
begin
  SetRowValue(false, false);
end;

procedure TOICustomPropertyGrid.ValueCheckBoxClick(Sender: TObject);
begin
  if (pgsUpdatingEditControl in FStates) or not IsCurrentEditorAvailable then exit;
  ValueCheckBox.Caption:=BoolToStr(ValueCheckBox.Checked, '(True)', '(False)');
  SetRowValue(true, true);
end;

procedure TOICustomPropertyGrid.ValueComboBoxExit(Sender: TObject);
begin
  if pgsUpdatingEditControl in FStates then exit;
  SetRowValue(false, false);
end;

procedure TOICustomPropertyGrid.ValueComboBoxKeyDown(Sender: TObject;
  var Key: Word; Shift: TShiftState);
begin
  ScrollToActiveItem;
  HandleStandardKeys(Key,Shift);
end;

procedure TOICustomPropertyGrid.ValueComboBoxKeyUp(Sender: TObject;
  var Key: Word; Shift: TShiftState);
begin
  HandleKeyUp(Key,Shift);
end;

procedure TOICustomPropertyGrid.ValueComboBoxMouseUp(Sender: TObject;
  Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  if (Button=mbLeft) then begin
    if (Shift=[ssCtrl,ssLeft]) then
      DoCallEdit(oiqeShowValue)
    else
    if (FFirstClickTime<>0) and (GetTickCount <= FFirstClickTime + GetDoubleClickTime)
    and (not ValueComboBox.DroppedDown) then
    begin
      FFirstClickTime:=0;
      ToggleRow;
    end;
  end;
end;

procedure TOICustomPropertyGrid.ValueButtonClick(Sender: TObject);
begin
  ScrollToActiveItem;
  DoCallEdit;
end;

procedure TOICustomPropertyGrid.ValueComboBoxMeasureItem(Control: TWinControl;
  Index: Integer; var AHeight: Integer);
var
  CurRow: TOIPropertyGridRow;
begin
  if (FItemIndex >= 0) and (FItemIndex < FRows.Count) then
  begin
    CurRow := Rows[FItemIndex];
    CurRow.Editor.ListMeasureHeight('Fj', Index, ValueComboBox.Canvas, AHeight);
    AHeight := Max(AHeight, ValueComboBox.ItemHeight);
  end;
end;

procedure TOICustomPropertyGrid.SetCheckboxState(NewValue: string);
begin
  ValueCheckBox.Caption:=NewValue;
  if (NewValue='') or (NewValue=oisMixed) then
    ValueCheckBox.State:=cbGrayed
  else if NewValue='(True)' then
    ValueCheckBox.State:=cbChecked
  // Note: this condition can be removed when the right propedit is used always.
  else if NewValue='(False)' then
    ValueCheckBox.State:=cbUnchecked;
end;

procedure TOICustomPropertyGrid.SetItemIndex(NewIndex:integer);
var
  NewRow: TOIPropertyGridRow;
  NewValue: string;
  EditorAttributes: TPropertyAttributes;
begin
  {if pgsCallingEdit in FStates then begin
    DumpStack;
    debugln(['TOICustomPropertyGrid.SetItemIndex ',DbgSName(Self),' ',dbgsname(FCurrentEdit),' ',dbgs(FStates),' GridIsUpdating=',GridIsUpdating,' FItemIndex=',FItemIndex,' NewIndex=',NewIndex]);
  end;}
  if GridIsUpdating or (FItemIndex = NewIndex) then
    exit;
  // save old edit value
  SetRowValue(true, false);

  Include(FStates, pgsChangingItemIndex);
  if (FItemIndex >= 0) and (FItemIndex < FRows.Count) then
    Rows[FItemIndex].Editor.Deactivate;
  if CanFocus then
    SetCaptureControl(nil);

  FItemIndex := NewIndex;
  if FCurrentEdit <> nil then
  begin
    FCurrentEdit.Visible:=false;
    FCurrentEdit.Enabled:=false;
    FCurrentEdit:=nil;
  end;
  if FCurrentButton<>nil then
  begin
    FCurrentButton.Visible:=false;
    FCurrentButton.Enabled:=false;
    FCurrentButton:=nil;
  end;
  FCurrentEditorLookupRoot:=nil;
  if (NewIndex >= 0) and (NewIndex < FRows.Count) then
  begin
    NewRow:=Rows[NewIndex];
    ScrollToItem(NewIndex);
    if CanFocus then
      NewRow.Editor.Activate;
    EditorAttributes:=NewRow.Editor.GetAttributes;
    if paDialog in EditorAttributes then begin
      FCurrentButton:=ValueButton;
      FCurrentButton.Visible:=true;
      //DebugLn(['TOICustomPropertyGrid.SetItemIndex FCurrentButton.BoundsRect=',dbgs(FCurrentButton.BoundsRect)]);
    end;
    NewValue:=NewRow.Editor.GetVisualValue;
    if ((NewRow.Editor is TBoolPropertyEditor) or (NewRow.Editor is TSetElementPropertyEditor))
    and FCheckboxForBoolean then
    begin
      FCurrentEdit:=ValueCheckBox;
      ValueCheckBox.Enabled:=not NewRow.IsReadOnly;
      SetCheckboxState(NewValue);
    end
    else if paValueList in EditorAttributes then
    begin
      FCurrentEdit:=ValueComboBox;
      if (paCustomDrawn in EditorAttributes) and (paPickList in EditorAttributes) then
        ValueComboBox.Style:=csOwnerDrawVariable
      else if paCustomDrawn in EditorAttributes then
        ValueComboBox.Style:=csOwnerDrawEditableVariable
      else if paPickList in EditorAttributes then
        ValueComboBox.Style:=csOwnerDrawFixed
      else
        ValueComboBox.Style:=csOwnerDrawEditableFixed;
      ValueComboBox.MaxLength:=NewRow.Editor.GetEditLimit;
      ValueComboBox.Sorted:=paSortList in NewRow.Editor.GetAttributes;
      ValueComboBox.Enabled:=not NewRow.IsReadOnly;
      // Do not fill the items here, because it can be very slow.
      // Just fill in some values and update the values before the combobox popups
      ValueComboBox.Items.Text:=NewValue;
      Exclude(FStates,pgsGetComboItemsCalled);
      SetIdleEvent(true);
      ValueComboBox.Text:=NewValue;
    end
    else begin
      FCurrentEdit:=ValueEdit;
      ValueEdit.ReadOnly:=NewRow.IsReadOnly;
      ValueEdit.Enabled:=true;
      ValueEdit.MaxLength:=NewRow.Editor.GetEditLimit;
      ValueEdit.Text:=NewValue;
    end;
    AlignEditComponents;
    if FCurrentEdit<>nil then
    begin
      if FPropertyEditorHook<>nil then
        FCurrentEditorLookupRoot:=FPropertyEditorHook.LookupRoot;
      if (FCurrentEdit=ValueComboBox) or (FCurrentEdit=ValueEdit) then
      begin
        if NewRow.Editor.AllEqual then
          FCurrentEdit.Color:=clWindow
        else
          FCurrentEdit.Color:=FValueDifferBackgrndColor;
      end;
      if NewRow.Editor.ValueIsStreamed then
        FCurrentEdit.Font:=FValueFont
      else
        FCurrentEdit.Font:=FDefaultValueFont;
      FCurrentEdit.Visible:=true;
      if (FDragging=false) and FCurrentEdit.Showing and FCurrentEdit.Enabled
      and (not NewRow.IsReadOnly) and CanFocus and (Column=oipgcValue)
      and not (pgsFocusPropertyEditorDisabled in FStates)
      then
        SetActiveControl(FCurrentEdit);
    end;
    if FCurrentButton<>nil then
      FCurrentButton.Enabled:=not NewRow.IsDisabled;
  end;
  //DebugLn(['TOICustomPropertyGrid.SetItemIndex Vis=',ValueComboBox.Visible,' Ena=',ValueComboBox.Enabled,
  //         ' Items.Count=',ValueComboBox.Items.Count ,' Text=',ValueComboBox.Text]);
  Exclude(FStates, pgsChangingItemIndex);
  DoSelectionChange;
  Invalidate;
end;

function TOICustomPropertyGrid.GetNameRowHeight: Integer;
begin
  Result := Abs(FNameFont.Height);
  if Result = 0 then
    Result := 16;
  Inc(Result, 2); // margin
end;

function TOICustomPropertyGrid.GetRowCount:integer;
begin
  Result:=FRows.Count;
end;

procedure TOICustomPropertyGrid.BuildPropertyList(OnlyIfNeeded: Boolean;
  FocusEditor: Boolean);
var
  a: integer;
  CurRow: TOIPropertyGridRow;
  OldSelectedRowPath: string;
begin
  if OnlyIfNeeded and (not (pgsBuildPropertyListNeeded in FStates)) then exit;
  Exclude(FStates,pgsBuildPropertyListNeeded);
  if not FocusEditor then Include(FStates, pgsFocusPropertyEditorDisabled);
  OldSelectedRowPath:=PropertyPath(ItemIndex);
  // unselect
  ItemIndex:=-1;
  // clear
  for a:=0 to FRows.Count-1 do Rows[a].Free;
  FRows.Clear;
  // get properties
  if FSelection.Count>0 then begin
    GetPersistentProperties(FSelection, FFilter + [tkClass], FPropertyEditorHook,
      @AddPropertyEditor, @EditorFilter);
  end;
  // sort
  FRows.Sort(@SortGridRows);
  for a:=0 to FRows.Count-1 do begin
    if a>0 then
      Rows[a].FPriorBrother:=Rows[a-1]
    else
      Rows[a].FPriorBrother:=nil;
    if a<FRows.Count-1 then
      Rows[a].FNextBrother:=Rows[a+1]
    else
      Rows[a].FNextBrother:=nil;
  end;
  // set indices and tops
  SetItemsTops;
  // restore expands
  for a:=FExpandedProperties.Count-1 downto 0 do begin
    CurRow:=GetRowByPath(FExpandedProperties[a]);
    if CurRow<>nil then
      ExpandRow(CurRow.Index);
  end;
  // update scrollbar
  FTopY:=0;
  UpdateScrollBar;
  // reselect
  CurRow:=GetRowByPath(OldSelectedRowPath);
  if CurRow<>nil then
    ItemIndex:=CurRow.Index;
  Exclude(FStates, pgsFocusPropertyEditorDisabled);
  // paint
  Invalidate;
end;

procedure TOICustomPropertyGrid.AddPropertyEditor(PropEditor: TPropertyEditor);
var
  NewRow: TOIPropertyGridRow;
  WidgetSets: TLCLPlatforms;
begin
  WidgetSets := [];
  if Favorites<>nil then begin
    //debugln('TOICustomPropertyGrid.AddPropertyEditor A ',PropEditor.GetName);
    if Favorites is TOIRestrictedProperties then
    begin
      WidgetSets := TOIRestrictedProperties(Favorites).AreRestricted(
                                                  Selection,PropEditor.GetName);
      if WidgetSets = [] then
      begin
        PropEditor.Free;
        Exit;
      end;
    end
    else
      if not Favorites.AreFavorites(Selection,PropEditor.GetName) then begin
        PropEditor.Free;
        exit;
      end;
  end;
  if PropEditor is TClassPropertyEditor then
  begin
    TClassPropertyEditor(PropEditor).SubPropsNameFilter := PropNameFilter;
    TClassPropertyEditor(PropEditor).SubPropsTypeFilter := FFilter;
    TClassPropertyEditor(PropEditor).HideClassName:=FHideClassNames;
  end;
  NewRow := TOIPropertyGridRow.Create(Self, PropEditor, nil, WidgetSets);
  FRows.Add(NewRow);
  if FRows.Count>1 then begin
    NewRow.FPriorBrother:=Rows[FRows.Count-2];
    NewRow.FPriorBrother.FNextBrother:=NewRow;
  end;
end;

procedure TOICustomPropertyGrid.AddStringToComboBox(const s: string);
begin
  if FNewComboBoxItems=nil then
    FNewComboBoxItems:=TStringListUTF8Fast.Create;
  FNewComboBoxItems.Add(s);
end;

procedure TOICustomPropertyGrid.ExpandRow(Index:integer);
var
  a: integer;
  CurPath: string;
  AlreadyInExpandList: boolean;
  ActiveRow: TOIPropertyGridRow;
begin
  // Save ItemIndex
  if ItemIndex <> -1 then
    ActiveRow := Rows[ItemIndex]
  else
    ActiveRow := nil;
  FExpandingRow := Rows[Index];
  if (FExpandingRow.Expanded) or (not CanExpandRow(FExpandingRow)) then
  begin
    FExpandingRow := nil;
    Exit;
  end;
  FExpandingRow.Editor.GetProperties(@AddSubEditor);
  SortSubEditors(FExpandingRow);
  SetItemsTops;
  FExpandingRow.FExpanded := True;
  a := 0;
  CurPath:=PropertyPath(FExpandingRow.Index);
  AlreadyInExpandList:=false;
  while a < FExpandedProperties.Count do
  begin
    if LazStartsText(FExpandedProperties[a], CurPath) then
    begin
      if Length(FExpandedProperties[a]) = Length(CurPath) then
      begin
        AlreadyInExpandList := True;
        inc(a);
      end
      else
        FExpandedProperties.Delete(a);
    end
    else
      inc(a);
  end;
  if not AlreadyInExpandList then
    FExpandedProperties.Add(CurPath);
  FExpandingRow := nil;
  // restore ItemIndex
  if ActiveRow <> nil then
    FItemIndex := ActiveRow.Index
  else
    FItemIndex := -1;
  UpdateScrollBar;
  Invalidate;
end;

procedure TOICustomPropertyGrid.ShrinkRow(Index:integer);
var
  CurRow, ARow: TOIPropertyGridRow;
  StartIndex, EndIndex, a: integer;
  CurPath: string;
begin
  CurRow := Rows[Index];
  if (not CurRow.Expanded) then
    Exit;
  // calculate all children (between StartIndex..EndIndex)
  StartIndex := CurRow.Index + 1;
  EndIndex := FRows.Count - 1;
  ARow := CurRow;
  while ARow <> nil do
  begin
    if ARow.NextBrother <> nil then
    begin
      EndIndex := ARow.NextBrother.Index - 1;
      break;
    end;
    ARow := ARow.Parent;
  end;
  if (FItemIndex >= StartIndex) and (FItemIndex <= EndIndex) then
    // current row delete, set new current row
    ItemIndex:=0
  else
  if FItemIndex > EndIndex then
    // adjust current index for deleted rows
    FItemIndex := FItemIndex - (EndIndex - StartIndex + 1);
  for a := EndIndex downto StartIndex do
  begin
    Rows[a].Free;
    FRows.Delete(a);
  end;
  SetItemsTops;
  CurRow.FExpanded := False;
  CurPath := PropertyPath(CurRow.Index);
  a := 0;
  while a < FExpandedProperties.Count do
  begin
    if LazStartsText(CurPath, FExpandedProperties[a]) then
      FExpandedProperties.Delete(a)
    else
      inc(a);
  end;
  if CurRow.Parent <> nil then
    FExpandedProperties.Add(PropertyPath(CurRow.Parent.Index));
  UpdateScrollBar;
  Invalidate;
end;

procedure TOICustomPropertyGrid.AddSubEditor(PropEditor:TPropertyEditor);
var
  NewRow:TOIPropertyGridRow;
  NewIndex:integer;
begin
  if not EditorFilter(PropEditor) then
  begin
    PropEditor.Free;
    Exit;
  end;

  if PropEditor is TClassPropertyEditor then
  begin
    TClassPropertyEditor(PropEditor).SubPropsNameFilter := PropNameFilter;
    TClassPropertyEditor(PropEditor).SubPropsTypeFilter := FFilter;
    TClassPropertyEditor(PropEditor).HideClassName:=FHideClassNames;
  end;
  NewRow:=TOIPropertyGridRow.Create(Self,PropEditor,FExpandingRow, []);
  NewIndex:=FExpandingRow.Index+1+FExpandingRow.ChildCount;
  NewRow.FIndex:=NewIndex;
  FRows.Insert(NewIndex,NewRow);
  if NewIndex<FItemIndex
    then inc(FItemIndex);
  if FExpandingRow.FFirstChild=nil then
    FExpandingRow.FFirstChild:=NewRow;
  NewRow.FPriorBrother:=FExpandingRow.FLastChild;
  FExpandingRow.FLastChild:=NewRow;
  if NewRow.FPriorBrother<>nil then
    NewRow.FPriorBrother.FNextBrother:=NewRow;
  inc(FExpandingRow.FChildCount);
end;

procedure TOICustomPropertyGrid.SortSubEditors(ParentRow: TOIPropertyGridRow);
var
  Item: TOIPropertyGridRow;
  Index: Integer;
  Next: TOIPropertyGridRow;
begin
  if not ParentRow.Sort(@SortGridRows) then exit;
  // update FRows
  Item:=ParentRow.FirstChild;
  Index:=ParentRow.Index+1;
  Next:=ParentRow.NextSkipChilds;
  while (Item<>nil) and (Item<>Next) do begin
    FRows[Index]:=Item;
    Item.FIndex:=Index;
    Item:=Item.Next;
    inc(Index);
  end;
end;

function TOICustomPropertyGrid.CanExpandRow(Row: TOIPropertyGridRow): boolean;
var
  AnObject: TPersistent;
  ParentRow: TOIPropertyGridRow;
begin
  Result:=false;
  if (Row=nil) or (Row.Editor=nil) then exit;
  if (not (paSubProperties in Row.Editor.GetAttributes)) then exit;
  // check if circling
  if (Row.Editor is TPersistentPropertyEditor) then begin
    if (Row.Editor is TInterfacePropertyEditor) then
      AnObject:={%H-}TPersistent(Row.Editor.GetIntfValue)
    else
      AnObject:=TPersistent(Row.Editor.GetObjectValue);
    if FSelection.IndexOf(AnObject)>=0 then exit;
    ParentRow:=Row.Parent;
    while ParentRow<>nil do begin
      if (ParentRow.Editor is TPersistentPropertyEditor)
      and (ParentRow.Editor.GetObjectValue=AnObject) then
        exit;
      ParentRow:=ParentRow.Parent;
    end;
  end;
  Result:=true;
end;

function TOICustomPropertyGrid.MouseToIndex(y: integer; MustExist: boolean): integer;
var l,r,m:integer;
begin
  l:=0;
  r:=FRows.Count-1;
  inc(y,FTopY);
  while (l<=r) do
  begin
    m:=(l+r) shr 1;
    if Rows[m].Top>y then
      r:=m-1
    else if Rows[m].Bottom<=y then
      l:=m+1
    else
      Exit(m);
  end;
  if (MustExist=false) and (FRows.Count>0) then begin
    if y<0 then
      Result:=0
    else
      Result:=FRows.Count-1;
  end else
    Result:=-1;
end;

function TOICustomPropertyGrid.GetActiveRow: TOIPropertyGridRow;
begin
  if InRange(ItemIndex,0,FRows.Count-1) then
    Result:=Rows[ItemIndex]
  else
    Result:=nil;
end;

procedure TOICustomPropertyGrid.SetCurrentRowValue(const NewValue: string);
begin
  if not CanEditRowValue(false) or Rows[FItemIndex].IsReadOnly then exit;
  // SetRowValue reads the value from the current edit control and writes it
  // to the property editor
  // -> set the text in the current edit control without changing FLastEditValue
  SetCurrentEditValue(NewValue);
  SetRowValue(false, true);
end;

procedure TOICustomPropertyGrid.SetItemIndexAndFocus(NewItemIndex: integer;
                                                     WasValueClick: Boolean);
begin
  if not InRange(NewItemIndex, 0, FRows.Count - 1) then exit;
  ItemIndex:=NewItemIndex;
  if FCurrentEdit<>nil then
  begin
    SetActiveControl(FCurrentEdit);
    if (FCurrentEdit is TCustomEdit) then
      TCustomEdit(FCurrentEdit).SelectAll
    {$IFnDEF UseOINormalCheckBox}
    else if (FCurrentEdit is TCheckBoxThemed) and WasValueClick then
      TCheckBoxThemed(FCurrentEdit).Checked:=not TCheckBoxThemed(FCurrentEdit).Checked;
    {$ELSE}
    else if (FCurrentEdit is TCheckBox) and WasValueClick then
      TCheckBox(FCurrentEdit).Checked:=not TCheckBox(FCurrentEdit).Checked;
    {$ENDIF}
  end;
end;

function TOICustomPropertyGrid.CanEditRowValue(CheckFocus: boolean): boolean;
var
  FocusedControl: TWinControl;
begin
  Result:=
    not GridIsUpdating and IsCurrentEditorAvailable
    and (not (pgsCallingEdit in FStates))
    and ((FCurrentEditorLookupRoot = nil)
      or (FPropertyEditorHook = nil)
      or (FPropertyEditorHook.LookupRoot = FCurrentEditorLookupRoot));
  if Result and CheckFocus then begin
    FocusedControl:=FindOwnerControl(GetFocus);
    if (FocusedControl<>nil) and (FocusedControl<>Self)
    and (not IsParentOf(FocusedControl)) then
      Result:=false;
  end;
  if Result then begin
    {DebugLn(['TOICustomPropertyGrid.CanEditRowValue',
      ' pgsChangingItemIndex=',pgsChangingItemIndex in FStates,
      ' pgsApplyingValue=',pgsApplyingValue in FStates,
      ' pgsUpdatingEditControl=',pgsUpdatingEditControl in FStates,
      ' FCurrentEdit=',dbgsName(FCurrentEdit),
      ' FItemIndex=',FItemIndex,
      ' FCurrentEditorLookupRoot=',dbgsName(FCurrentEditorLookupRoot),
      ' FPropertyEditorHook.LookupRoot=',dbgsName(FPropertyEditorHook.LookupRoot)
      ]);}
  end;
end;

procedure TOICustomPropertyGrid.SaveChanges;
begin
  SetRowValue(true, false);
end;

function TOICustomPropertyGrid.GetHintTypeAt(RowIndex: integer; X: integer): TPropEditHint;
var
  IconX: integer;
begin
  Result := pehNone;
  if (RowIndex < 0) or (RowIndex >= RowCount) then 
    Exit;
  if SplitterX <= X then 
  begin
    if (FCurrentButton <> nil) and (FCurrentButton.Left <= X) then
      Result := pehEditButton
    else
      Result := pehValue;
  end else 
  begin
    IconX := GetTreeIconX(RowIndex);
    if IconX + Indent > X then
      Result := pehTree
    else
      Result := pehName;
  end;
end;

procedure TOICustomPropertyGrid.MouseDown(Button:TMouseButton; Shift:TShiftState;
  X,Y:integer);
var
  IconX,Index:integer;
  PointedRow:TOIpropertyGridRow;
  Details: TThemedElementDetails;
  Sz: TSize;
begin
  //ShowMessageDialog('X'+IntToStr(X)+',Y'+IntToStr(Y));
  inherited MouseDown(Button,Shift,X,Y);

  HideHint;

  if Button=mbLeft then begin
    FFirstClickTime:=GetTickCount;
    if Cursor=crHSplit then
      FDragging:=true
    else
    begin
      Index:=MouseToIndex(Y,false);
      if (Index>=0) and (Index<FRows.Count) then
      begin
        PointedRow:=Rows[Index];
        if CanExpandRow(PointedRow) then
        begin
          IconX:=GetTreeIconX(Index);
          if ((X>=IconX) and (X<=IconX+FIndent)) or (ssDouble in Shift) then
          begin
            if PointedRow.Expanded then
              ShrinkRow(Index)
            else
              ExpandRow(Index);
          end;
        end;
        // WasValueClick param is only for Boolean checkboxes, toggled if user
        //  clicks the square. It has no effect for Boolean ComboBox editor.
        Details := ThemeServices.GetElementDetails(tbCheckBoxCheckedNormal);
        Sz := ThemeServices.GetDetailSize(Details);
        SetItemIndexAndFocus(Index, (X>SplitterX) and (X<=SplitterX+Sz.cx));
        SetCaptureControl(Self);
        Column := oipgcValue;
      end;
    end;
  end;
end;

procedure TOICustomPropertyGrid.MouseLeave;
begin
  if Assigned(FHintManager) and Assigned(FHintManager.CurHintWindow)
  and FHintManager.CurHintWindow.Visible
  and not PtInRect(ClientRect, ScreenToClient(Mouse.CursorPos)) then
    FHintManager.HideHint;

  inherited MouseLeave;
end;

procedure TOICustomPropertyGrid.MouseMove(Shift:TShiftState; X,Y:integer);
var
  TheHint: String;
  HintType: TPropEditHint;
  fPropRow: TOIPropertyGridRow;

  procedure ShowShortHint(pt: TPoint); inline;
  //var HintFont: TFont;
  begin
    if WidgetSet.GetLCLCapability(lcTransparentWindow)=LCL_CAPABILITY_NO then
      Inc(pt.Y, fPropRow.Height);
{ By Juha :
  FValueFont and FDefaultValueFont are nearly unreadable.
  We should maybe get their negated color as the hint background is black.

    if HintType<>pehValue then
      HintFont := Screen.HintFont
    else
    if fPropRow.Editor.ValueIsStreamed then
      HintFont:=FValueFont
    else
      HintFont:=FDefaultValueFont;  }
    FHintManager.ShowHint(ClientToScreen(pt), TheHint, False{, HintFont});
    if FHintManager.CurHintWindow<>nil then
      FHintManager.CurHintWindow.OnMouseLeave := @HintMouseLeave;
  end;

var
  SplitDistance, Index, TextLeft: Integer;
  HintWillChange: Boolean;
begin
  inherited MouseMove(Shift,X,Y);
  SplitDistance := X-SplitterX;
  if FDragging then
  begin
    HideHint;
    if ssLeft in Shift then
      SplitterX:=SplitterX+SplitDistance
    else
      EndDragSplitter;
  end
  else begin
    if abs(SplitDistance) <= 2 then
      Cursor := crHSplit
    else
      Cursor := crDefault;
    if ssLeft in Shift then
    begin
      Index := MouseToIndex(Y, False);
      SetItemIndexAndFocus(Index);
      SetCaptureControl(Self);
    end;
    // The following code handler 2 kinds of hints :
    // 1. Property's name / value when it does not fit in the cell.
    // 2. Long description of a property / value, only when ShowHint option is set.
    Index := MouseToIndex(y,false);
    HintType := GetHintTypeAt(Index, x);
    HintWillChange := (Index<>FHintIndex) or (HintType<>FHintType);
    if HintWillChange then
      HideHint;                        // hide the hint of an earlier row
    // Don't show any more hints if the long hint is there.
    if FShowingLongHint or (Index = -1) then Exit;
    // Show the property text as a hint if it does not fit in its box.
    if HintWillChange or not FHintManager.HintIsVisible then
    begin
      FHintIndex := Index;
      FHintType := HintType;
      fPropRow := GetRow(Index);
      if HintType = pehName then
      begin                            // Mouse is over property name...
        TheHint := fPropRow.Name;
        TextLeft := BorderWidth + GetTreeIconX(Index) + Indent + 5;
        if (Canvas.TextWidth(TheHint) + TextLeft) >= SplitterX-2 then
          ShowShortHint(Point(TextLeft-3, fPropRow.Top-TopY-1));
      end else
      if HintType in [pehValue,pehEditButton] then
      begin                            // Mouse is over property value...
        TheHint := fPropRow.LastPaintedValue;
        if length(TheHint) > 100 then
          TheHint := copy(TheHint, 1, 100) + '...';
        TextLeft := SplitterX+2;
        if Canvas.TextWidth(TheHint) > (ClientWidth - BorderWidth - TextLeft) then
          ShowShortHint(Point(TextLeft-3, fPropRow.Top-TopY-1));
      end;
    end;
    // Initialize timer for a long hint describing the property and value.
    if not ShowHint then Exit;
    if FLongHintTimer = nil then
    begin
      FHintIndex := -1;
      FLongHintTimer := TTimer.Create(nil);
      FLongHintTimer.Interval := 500;
      FLongHintTimer.Enabled := False;
      FLongHintTimer.OnTimer := @HintTimer;
      FHintManager.OnMouseDown := @HintMouseDown;
      FHintManager.WindowName := 'This_is_a_hint_window';
      FHintManager.HideInterval := 4000;
      FHintManager.AutoHide := True;
    end;
    FLongHintTimer.Enabled := RowCount > 0;
  end; // not FDragging
end;

procedure TOICustomPropertyGrid.MouseUp(Button:TMouseButton; Shift:TShiftState;
  X,Y:integer);
begin
  if FDragging then EndDragSplitter;
  SetCaptureControl(nil);
  inherited MouseUp(Button,Shift,X,Y);
end;

procedure TOICustomPropertyGrid.KeyDown(var Key: Word; Shift: TShiftState);
begin
  HandleStandardKeys(Key,Shift);
  inherited KeyDown(Key, Shift);
end;

procedure TOICustomPropertyGrid.HandleStandardKeys(var Key: Word; Shift: TShiftState);
var
  Handled: Boolean;

  procedure FindPropertyBySearchText;
  var
    i, IIndex: Integer;
  begin
    if Column = oipgcName then
    begin
      FKeySearchText := FKeySearchText + UpCase(Chr(Key));
      if ItemIndex = -1 then
        IIndex := 0
      else
        IIndex := ItemIndex;
      for i := 0 to RowCount - 1 do
        if (Rows[i].Lvl = Rows[IIndex].Lvl)
        and LazStartsText(FKeySearchText, Rows[i].Name) then
        begin
          // Set item index. To go to Value user must hit either Tab or Enter.
          SetItemIndex(i);
          exit;
        end;
      // Left part of phrase not matched, remove added char.
      SetLength(FKeySearchText, Length(FKeySearchText) - 1);
    end;
    Handled := false;
  end;

  procedure HandleUnshifted;
  const
    Page = 20;
  begin
    Handled := true;
    case Key of
      VK_UP   : SetItemIndexAndFocus(ItemIndex - 1);
      VK_DOWN : SetItemIndexAndFocus(ItemIndex + 1);
      VK_PRIOR: SetItemIndexAndFocus(Max(ItemIndex - Page, 0));
      VK_NEXT : SetItemIndexAndFocus(Min(ItemIndex + Page, FRows.Count - 1));

      VK_TAB: DoTabKey;

      VK_RETURN:
        begin
          if Column = oipgcName then
            DoTabKey
          else
            SetRowValue(false, true);
          if FCurrentEdit is TCustomEdit then
            TCustomEdit(FCurrentEdit).SelectAll;
        end;

      VK_ESCAPE:
        begin
          RefreshValueEdit;
          FKeySearchText := '';
        end;

      VK_BACK:
        begin
          if (Column = oipgcName) then
            if (FKeySearchText <> '') then
              SetLength(FKeySearchText, Length(FKeySearchText) - 1);
          Handled := False;
        end;

      Ord('A')..Ord('Z'): FindPropertyBySearchText;

      else
        Handled := false;
    end;
  end;

begin
  //writeln('TOICustomPropertyGrid.HandleStandardKeys ',Key);
  Handled := false;
  if (Shift = []) or (Shift = [ssShift]) then
  begin
    if not (FCurrentEdit is TCustomCombobox) or
       not TCustomCombobox(FCurrentEdit).DroppedDown then
      HandleUnshifted;
  end
  else
  if Shift = [ssCtrl] then
  begin
    case Key of
      VK_RETURN:
        begin
          ToggleRow;
          Handled := true;
        end;
    end;
  end
  else 
  if Shift = [ssAlt] then
    case Key of
      VK_LEFT:
        begin
          Handled := (ItemIndex >= 0) and Rows[ItemIndex].Expanded;
          if Handled then ShrinkRow(ItemIndex);
        end;

      VK_RIGHT:
        begin
          Handled := (ItemIndex >= 0) and not Rows[ItemIndex].Expanded and
            CanExpandRow(Rows[ItemIndex]);
          if Handled then ExpandRow(ItemIndex)
        end;
    end;


  if not Handled and Assigned(OnOIKeyDown) then
  begin
    OnOIKeyDown(Self, Key, Shift);
    Handled := Key = VK_UNKNOWN;
  end;

  //writeln('TOICustomPropertyGrid.HandleStandardKeys ',Key,' Handled=',Handled);
  if Handled then
    Key := VK_UNKNOWN;
end;

procedure TOICustomPropertyGrid.HandleKeyUp(var Key: Word; Shift: TShiftState);
begin
  if (Key<>VK_UNKNOWN) and Assigned(OnKeyUp) then
    OnKeyUp(Self,Key,Shift);
end;

procedure TOICustomPropertyGrid.DoTabKey;
begin
  if Column = oipgcValue then 
  begin
    Column := oipgcName;
    Self.SetFocus;
  end else 
  begin
    Column := oipgcValue;
    if FCurrentEdit <> nil then
      FCurrentEdit.SetFocus;
  end;
  FKeySearchText := '';
end;

function TOICustomPropertyGrid.EditorFilter(const AEditor: TPropertyEditor): Boolean;
begin
  Result := IsInteresting(AEditor, FFilter, PropNameFilter);
  if Result and Assigned(OnEditorFilter) then
    OnEditorFilter(Self,AEditor,Result);
end;

procedure TOICustomPropertyGrid.EraseBackground(DC: HDC);
begin
  // everything is painted, so erasing the background is not needed
end;

procedure TOICustomPropertyGrid.DoSetBounds(ALeft, ATop, AWidth, AHeight: integer);
begin
  inherited DoSetBounds(ALeft, ATop, AWidth, AHeight);
  UpdateScrollBar;
end;

procedure TOICustomPropertyGrid.DoSelectionChange;
begin
  if Assigned(FOnSelectionChange) then
    FOnSelectionChange(Self);
end;

procedure TOICustomPropertyGrid.HintMouseDown(Sender: TObject;
  Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  pos: TPoint;
begin
  if FHintManager.HintIsVisible then begin
    pos := ScreenToClient(FHintManager.CurHintWindow.ClientToScreen(Point(X, Y)));
    MouseDown(Button, Shift, pos.X, pos.Y);
  end;
end;

procedure TOICustomPropertyGrid.HintMouseLeave(Sender: TObject);
begin
  if FindLCLControl(Mouse.CursorPos)<>Self then
    FHintManager.HideHint;
end;

procedure TOICustomPropertyGrid.EndDragSplitter;
begin
  if FDragging then begin
    Cursor:=crDefault;
    FDragging:=false;
    FPreferredSplitterX:=FSplitterX;
    if FCurrentEdit<>nil then begin
      SetCaptureControl(nil);
      if Column=oipgcValue then
        FCurrentEdit.SetFocus
      else
        Self.SetFocus;
    end;
  end;
end;

procedure TOICustomPropertyGrid.SetReadOnlyColor(const AValue: TColor);
begin
  if FReadOnlyColor = AValue then Exit;
  FReadOnlyColor := AValue;
  Invalidate;
end;

procedure TOICustomPropertyGrid.SetRowSpacing(const AValue: integer);
begin
  if FRowSpacing = AValue then exit;
  FRowSpacing := AValue;
  SetItemsTops;
end;

procedure TOICustomPropertyGrid.SetShowGutter(const AValue: Boolean);
begin
  if FShowGutter=AValue then exit;
  FShowGutter:=AValue;
  invalidate;
end;

procedure TOICustomPropertyGrid.SetSplitterX(const NewValue:integer);
var AdjustedValue:integer;
begin
  AdjustedValue:=NewValue;
  if AdjustedValue>ClientWidth then AdjustedValue:=ClientWidth;
  if AdjustedValue<1 then AdjustedValue:=1;
  if FSplitterX<>AdjustedValue then begin
    FSplitterX:=AdjustedValue;
    AlignEditComponents;
    Repaint;
  end;
end;

procedure TOICustomPropertyGrid.SetTopY(const NewValue:integer);
var
  NewTopY, d: integer;
  f: UINT;
begin
  NewTopY := TopMax;
  if NewValue < NewTopY then
    NewTopY := NewValue;
  if NewTopY < 0 then
    NewTopY := 0;
  if FTopY<>NewTopY then begin
    f := SW_INVALIDATE;
    d := FTopY-NewTopY;
    // SW_SCROLLCHILDREN can only be used, if the active editor is not
    // "scrolling in" (i.e., partly outside the clientrect)
    if (FCurrentEdit = nil) or
       ( (d > 0) and (FCurrentEdit.Top >= 0) ) or
       ( (d < 0) and (FCurrentEdit.Top <  Height - FCurrentEdit.Height) )
    then
      f := f + SW_SCROLLCHILDREN;
    if not ScrollWindowEx(Handle,0,d,nil,nil,0,nil, f) then
      Invalidate;
    FTopY:=NewTopY;
    UpdateScrollBar;
    AlignEditComponents;
  end;
end;

function TOICustomPropertyGrid.GetPropNameColor(ARow:TOIPropertyGridRow):TColor;

 function HasWriter(APropInfo: PPropInfo): Boolean; inline;
 begin
   Result := Assigned(APropInfo) and Assigned(APropInfo^.SetProc);
 end;

var
  ParentRow:TOIPropertyGridRow;
  IsObjectSubProperty:Boolean;
begin
  // Try to guest if ARow, or one of its parents, is a subproperty
  // of an object (and not an item of a set)
  IsObjectSubProperty:=false;
  ParentRow:=ARow.Parent;
  while Assigned(ParentRow) do
  begin
    if ParentRow.Editor is TPersistentPropertyEditor then
      IsObjectSubProperty:=true;
    ParentRow:=ParentRow.Parent;
  end;

  if (ItemIndex <> -1) and (ItemIndex = ARow.Index) then
    Result := FHighlightFont.Color
  else
  if not HasWriter(ARow.Editor.GetPropInfo) then
    Result := FReadOnlyColor
  else
  if ARow.Editor is TPersistentPropertyEditor then
    Result := FReferencesColor
  else
  if IsObjectSubProperty then
    Result := FSubPropertiesColor
  else
    Result := FNameFont.Color;
end;

procedure TOICustomPropertyGrid.SetBounds(aLeft,aTop,aWidth,aHeight:integer);
begin
//writeln('[TOICustomPropertyGrid.SetBounds] ',Name,' ',aLeft,',',aTop,',',aWidth,',',aHeight,' Visible=',Visible);
  inherited SetBounds(aLeft,aTop,aWidth,aHeight);
  if Visible then begin
    if not FDragging then begin
      if (SplitterX<5) and (aWidth>20) then
        SplitterX:=100
      else
        SplitterX:=FPreferredSplitterX;
    end;
    AlignEditComponents;
  end;
end;

function TOICustomPropertyGrid.GetTreeIconX(Index:integer):integer;
begin
  Result:=Rows[Index].Lvl*Indent+2;
end;

function TOICustomPropertyGrid.TopMax:integer;
begin
  Result:=GridHeight-ClientHeight+2*integer(BorderWidth);
  if Result<0 then Result:=0;
end;

function TOICustomPropertyGrid.GridHeight:integer;
begin
  if FRows.Count>0 then
    Result:=Rows[FRows.Count-1].Bottom
  else
    Result:=0;
end;

procedure TOICustomPropertyGrid.AlignEditComponents;
var
  RRect, EditCompRect, EditBtnRect: TRect;
begin
  if ItemIndex>=0 then
  begin
    RRect := RowRect(ItemIndex);
    InflateRect(RRect, 0, 1);
    EditCompRect := RRect;

    if Layout = oilHorizontal then
      EditCompRect.Left := RRect.Left + SplitterX
    else begin
      EditCompRect.Top := RRect.Top + GetNameRowHeight;
      EditCompRect.Left := RRect.Left + GetTreeIconX(ItemIndex) + Indent;
    end;

    if FCurrentButton<>nil then
    begin
      // edit dialog button
      with EditBtnRect do begin
        Top := EditCompRect.Top;
        Left := EditCompRect.Right - Scale96ToForm(20);
        Bottom := EditCompRect.Bottom - 1;
        Right := EditCompRect.Right;
        EditCompRect.Right := Left;
      end;
      if FCurrentButton.BoundsRect <> EditBtnRect then
        FCurrentButton.BoundsRect := EditBtnRect;
      //DebugLn(['TOICustomPropertyGrid.AlignEditComponents FCurrentButton.BoundsRect=',dbgs(FCurrentButton.BoundsRect),' EditBtnRect=',dbgs(EditBtnRect)]);
    end;
    if FCurrentEdit<>nil then
    begin
      // resize the edit component
      if (FCurrentEdit is TEdit) or (FCurrentEdit is TComboBox) then
      begin
        Dec(EditCompRect.Top);
      {$IFDEF UseOINormalCheckBox}
      end
      else if FCurrentEdit is TCheckBox then
      begin
        with EditCompRect do  // Align "normal" CheckBox to the middle vertically
          Inc(Top, (Bottom - Top - ValueCheckBox.Height) div 2);
      {$ELSE}
      end
      else if FCurrentEdit is TCheckBoxThemed then
      begin             // Move right as much as in TPropertyEditor.DrawCheckValue.
        Inc(EditCompRect.Left, CheckBoxThemedLeftOffs);
      {$ENDIF}
      end;
      //debugln('TOICustomPropertyGrid.AlignEditComponents A ',dbgsName(FCurrentEdit),' ',dbgs(EditCompRect));
      if ( ( (FCurrentEdit.BoundsRect.Bottom >= 0) and (FCurrentEdit.BoundsRect.Top <= Height) ) or
           ( (EditCompRect.Bottom >= 0) and (EditCompRect.Top <= Height) ) ) and
         ( FCurrentEdit.BoundsRect <> EditCompRect )
      then begin
        FCurrentEdit.BoundsRect := EditCompRect;
      end;
    end;
  end;
end;

procedure TOICustomPropertyGrid.PaintRow(ARow: integer);
var
  FullRect, NameRect, NameTextRect, NameIconRect, ValueRect: TRect;
  CurRow: TOIPropertyGridRow;

  procedure ClearBackground;
  var
    DrawValuesDiffer: Boolean;
  begin
    DrawValuesDiffer := (FValueDifferBackgrndColor<>clNone) and not CurRow.Editor.AllEqual;
    if FBackgroundColor <> clNone then
    begin
      Canvas.Brush.Color := FBackgroundColor;
      if DrawValuesDiffer then
        Canvas.FillRect(NameRect)
      else
        Canvas.FillRect(FullRect);
    end;
    if DrawValuesDiffer then
    begin
      // Make the background color darker than what the active edit control has.
      Canvas.Brush.Color := FValueDifferBackgrndColor - $282828;
      Canvas.FillRect(ValueRect);
    end;
    if ShowGutter and (Layout = oilHorizontal) and
       (FGutterColor <> FBackgroundColor) and (FGutterColor <> clNone) then
    begin
      Canvas.Brush.Color := FGutterColor;
      Canvas.FillRect(NameIconRect);
    end;
  end;

  procedure DrawIcon(IconX: integer);
  var
    Details: TThemedElementDetails;
    sz: TSize;
    IconY: integer;
    Res: TScaledImageListResolution;
  begin
    if CurRow.Expanded then
      Details := ThemeServices.GetElementDetails(ttGlyphOpened)
    else
      Details := ThemeServices.GetElementDetails(ttGlyphClosed);
    if CanExpandRow(CurRow) then
    begin
      sz := ThemeServices.GetDetailSize(Details);
      IconY:=((NameRect.Bottom - NameRect.Top - sz.cy) div 2) + NameRect.Top;
      ThemeServices.DrawElement(Canvas.Handle, Details,
                                Rect(IconX, IconY, IconX + sz.cx, IconY + sz.cy), nil)
    end else
    if (ARow = FItemIndex) then
    begin
      Res := FActiveRowImages.ResolutionForControl[0, Self];

      IconY:=((NameRect.Bottom - NameRect.Top - Res.Height) div 2) + NameRect.Top;
      Res.Draw(Canvas, IconX, IconY, FActiveRowImages.GetImageIndex('pg_active_row'));
    end;
  end;

  procedure DrawName(DrawState: TPropEditDrawState);
  var
    OldFont: TFont;
    NameBgColor: TColor;
  begin
    if (ARow = FItemIndex) and (FHighlightColor <> clNone) then
      NameBgColor := FHighlightColor
    else
      NameBgColor := FBackgroundColor;
    OldFont:=Canvas.Font;
    Canvas.Font:=FNameFont;
    Canvas.Font.Color := GetPropNameColor(CurRow);
    // set bg color to highlight if needed
    if (NameBgColor <> FBackgroundColor) and (NameBgColor <> clNone) then
    begin
      Canvas.Brush.Color := NameBgColor;
      Canvas.FillRect(NameTextRect);
    end;
    CurRow.Editor.PropDrawName(Canvas, NameTextRect, DrawState);
    Canvas.Font := OldFont;
    if FBackgroundColor <> clNone then // return color back to background
      Canvas.Brush.Color := FBackgroundColor;
  end;

  procedure DrawWidgetsets;
  var
    OldFont: TFont;
    X, Y: Integer;
    lclPlatform: TLCLPlatform;
    ImagesRes: TScaledImageListResolution;
  begin
    ImagesRes := IDEImages.Images_16.ResolutionForPPI[0, Font.PixelsPerInch, GetCanvasScaleFactor];
    X := NameRect.Right - 2;
    Y := (NameRect.Top + NameRect.Bottom - ImagesRes.Height) div 2;
    OldFont:=Canvas.Font;
    Canvas.Font:=FNameFont;
    Canvas.Font.Color := clRed;
    for lclPlatform := High(TLCLPlatform) downto Low(TLCLPlatform) do
    begin
      if lclPlatform in CurRow.FWidgetSets then
      begin
        Dec(X, ImagesRes.Width);
        ImagesRes.Draw(Canvas, X, Y,
          IDEImages.LoadImage('issue_'+LCLPlatformDirNames[lclPlatform]));
      end;
    end;
    Canvas.Font:=OldFont;
  end;

  procedure DrawValue(DrawState: TPropEditDrawState);
  var
    OldFont: TFont;
  begin
    if ARow<>ItemIndex then
    begin
      OldFont:=Canvas.Font;
      if CurRow.Editor.ValueIsStreamed then
        Canvas.Font:=FValueFont
      else
        Canvas.Font:=FDefaultValueFont;
      CurRow.Editor.PropDrawValue(Canvas,ValueRect,DrawState);
      Canvas.Font:=OldFont;
    end;
    CurRow.LastPaintedValue:=CurRow.Editor.GetVisualValue;
  end;

  procedure DrawGutterToParent;
  var
    ParentRect: TRect;
    X: Integer;
  begin
    if ARow > 0 then
    begin
      ParentRect := RowRect(ARow - 1);
      X := ParentRect.Left + GetTreeIconX(ARow - 1) + Indent + 3;
      if X <> NameIconRect.Right then
      begin
        Canvas.MoveTo(NameIconRect.Right, NameRect.Top - 1 - FRowSpacing);
        Canvas.LineTo(X - 1, NameRect.Top - 1 - FRowSpacing);
      end;
    end;
    // to parent next sibling
    if ARow < FRows.Count - 1 then
    begin
      ParentRect := RowRect(ARow + 1);
      X := ParentRect.Left + GetTreeIconX(ARow + 1) + Indent + 3;
      if X <> NameIconRect.Right then
      begin
        Canvas.MoveTo(NameIconRect.Right, NameRect.Bottom - 1);
        Canvas.LineTo(X - 1, NameRect.Bottom - 1);
      end;
    end;
  end;

var
  IconX: integer;
  DrawState: TPropEditDrawState;
begin
  CurRow := Rows[ARow];
  FullRect := RowRect(ARow);
  if (FullRect.Bottom < FPaintRc.Top) or (FullRect.Top > FPaintRc.Bottom) then
    exit;
  NameRect := FullRect;
  ValueRect := FullRect;
  Inc(FullRect.Bottom, FRowSpacing);

  if Layout = oilHorizontal then
  begin
    NameRect.Right:=SplitterX;
    ValueRect.Left:=SplitterX;
  end
  else begin
    NameRect.Bottom := NameRect.Top + GetNameRowHeight;
    ValueRect.Top := NameRect.Bottom;
  end;

  IconX := GetTreeIconX(ARow);
  NameIconRect := NameRect;
  NameIconRect.Right := IconX + Indent;
  NameTextRect := NameRect;
  NameTextRect.Left := NameIconRect.Right;

  if Layout = oilVertical then
    ValueRect.Left := NameTextRect.Left
  else
  begin
    inc(NameIconRect.Right, 2 + Ord(ShowGutter));
    inc(NameTextRect.Left, 3 + Ord(ShowGutter));
  end;

  DrawState:=[];
  if ARow = FItemIndex then
    Include(DrawState, pedsSelected);

  ClearBackground;      // clear background in one go
  DrawIcon(IconX);      // draw icon
  DrawName(DrawState);  // draw name
  DrawWidgetsets;       // draw widgetsets
  DrawValue(DrawState); // draw value

  with Canvas do
  begin
    if Layout = oilHorizontal then          // frames
    begin
      // Row Divider
      if DrawHorzGridLines then
      begin
        Pen.Style := psDot;
        Pen.EndCap := pecFlat;
        Pen.Cosmetic := False;
        Pen.Color := cl3DShadow;
        if FRowSpacing <> 0 then
        begin
          MoveTo(NameTextRect.Left, NameRect.Top - 1);
          LineTo(ValueRect.Right, NameRect.Top - 1);
        end;
        MoveTo(NameTextRect.Left, NameRect.Bottom - 1);
        LineTo(ValueRect.Right, NameRect.Bottom - 1);
      end;

      // Split lines between: icon and name, name and value
      Pen.Style := psSolid;
      Pen.Cosmetic := True;
      Pen.Color := cl3DHiLight;
      MoveTo(NameRect.Right - 1, NameRect.Bottom - 1);
      LineTo(NameRect.Right - 1, NameRect.Top - 1 - FRowSpacing);
      Pen.Color := cl3DShadow;
      MoveTo(NameRect.Right - 2, NameRect.Bottom - 1);
      LineTo(NameRect.Right - 2, NameRect.Top - 1 - FRowSpacing);

      // draw gutter line
      if ShowGutter then
      begin
        Pen.Color := GutterEdgeColor;
        MoveTo(NameIconRect.Right, NameRect.Bottom - 1);
        LineTo(NameIconRect.Right, NameRect.Top - 1 - FRowSpacing);
        if CurRow.Lvl > 0 then
          DrawGutterToParent;
      end;
    end
    else begin                              // Layout <> oilHorizontal
      Pen.Style := psSolid;
      Pen.Color := cl3DLight;
      MoveTo(ValueRect.Left, ValueRect.Bottom - 1);
      LineTo(ValueRect.Left, NameTextRect.Top);
      LineTo(ValueRect.Right - 1, NameTextRect.Top);
      Pen.Color:=cl3DHiLight;
      LineTo(ValueRect.Right - 1, ValueRect.Bottom - 1);
      LineTo(ValueRect.Left, ValueRect.Bottom - 1);

      MoveTo(NameTextRect.Left + 1, NametextRect.Bottom);
      LineTo(NameTextRect.Left + 1, NameTextRect.Top + 1);
      LineTo(NameTextRect.Right - 2, NameTextRect.Top + 1);
      Pen.Color:=cl3DLight;
      LineTo(NameTextRect.Right - 2, NameTextRect.Bottom - 1);
      LineTo(NameTextRect.Left + 2, NameTextRect.Bottom - 1);
    end;
  end;
end;

procedure TOICustomPropertyGrid.DoPaint(PaintOnlyChangedValues: boolean);
var
  a: integer;
  SpaceRect: TRect;
  GutterX: Integer;
begin
  FPaintRc := Canvas.ClipRect;

  BuildPropertyList(true);
  if not PaintOnlyChangedValues then
  begin
    with Canvas do
    begin
      // draw properties
      for a := 0 to FRows.Count - 1 do
        PaintRow(a);
      // draw unused space below rows
      SpaceRect := Rect(BorderWidth, BorderWidth,
                        ClientWidth - BorderWidth + 1, ClientHeight - BorderWidth + 1);
      if FRows.Count > 0 then
        SpaceRect.Top := Rows[FRows.Count - 1].Bottom - FTopY + BorderWidth;
      if FBackgroundColor <> clNone then
      begin
        Brush.Color := FBackgroundColor;
        FillRect(SpaceRect);
      end;

      // draw gutter if needed
      if ShowGutter and (Layout = oilHorizontal) then
      begin
        if FRows.Count > 0 then
          GutterX := RowRect(FRows.Count - 1).Left + GetTreeIconX(FRows.Count - 1)
        else
          GutterX := BorderWidth + 2;
        inc(GutterX, Indent + 3);
        SpaceRect.Right := GutterX;
        if GutterColor <> clNone then
        begin
          Brush.Color := GutterColor;
          FillRect(SpaceRect);
        end;
        MoveTo(GutterX, SpaceRect.Top);
        LineTo(GutterX, SpaceRect.Bottom);
      end;
      // don't draw border: borderstyle=bsSingle
    end;
  end else
  begin
    for a := 0 to FRows.Count-1 do
    begin
      if Rows[a].Editor.GetVisualValue <> Rows[a].LastPaintedValue then
        PaintRow(a);
    end;
  end;
end;

procedure TOICustomPropertyGrid.Paint;
begin
  inherited Paint;
  DoPaint(false);
end;

procedure TOICustomPropertyGrid.RefreshPropertyValues;
begin
  RefreshValueEdit;
  Invalidate;
end;

procedure TOICustomPropertyGrid.ScrollToActiveItem;
begin
  ScrollToItem(FItemIndex);
end;

procedure TOICustomPropertyGrid.ScrollToItem(NewIndex: Integer);
var
  NewRow: TOIPropertyGridRow;
begin
  if (NewIndex >= 0) and (NewIndex < FRows.Count) then
  begin
    NewRow := Rows[NewIndex];
    if NewRow.Bottom >= TopY + (ClientHeight - 2*BorderWidth) then
      TopY := NewRow.Bottom- (ClientHeight - 2*BorderWidth) + 1
    else
      if NewRow.Top < TopY then TopY := NewRow.Top;
  end;
end;

procedure TOICustomPropertyGrid.PropEditLookupRootChange;
begin
  // When the LookupRoot changes, no changes can be stored
  // -> undo the value editor changes
  RefreshValueEdit;
  if PropertyEditorHook<>nil then
    FCurrentEditorLookupRoot:=PropertyEditorHook.LookupRoot;
end;

function TOICustomPropertyGrid.RowRect(ARow:integer):TRect;
const
  ScrollBarWidth=0;
begin
  Result.Left:=BorderWidth;
  Result.Top:=Rows[ARow].Top-FTopY+BorderWidth;
  Result.Right:=ClientWidth-ScrollBarWidth;
  Result.Bottom:=Rows[ARow].Bottom-FTopY+BorderWidth;
end;

procedure TOICustomPropertyGrid.SetItemsTops;
// compute row tops from row heights
// set indices of all rows
var a:integer;
begin
  for a:=0 to FRows.Count-1 do begin
    Rows[a].FIndex:=a;
    Rows[a].MeasureHeight(Canvas);
  end;
  if FRows.Count>0 then
    Rows[0].Top:=0;
  for a:=1 to FRows.Count-1 do
    Rows[a].FTop:=Rows[a-1].Bottom + FRowSpacing;
end;

procedure TOICustomPropertyGrid.ClearRows;
var i:integer;
begin
  IncreaseChangeStep;
  // reverse order to make sure child rows are freed before parent rows
  for i:=FRows.Count-1 downto 0 do begin
    //debugln(['TOICustomPropertyGrid.ClearRows ',i,' ',FRows.Count,' ',dbgs(frows[i])]);
    Rows[i].Free;
    FRows[i]:=nil;
  end;
  FRows.Clear;
end;

function TOICustomPropertyGrid.GetCurrentEditValue: string;
begin
  if FCurrentEdit=ValueEdit then
  {$IFDEF LCLCarbon}
    Result:=StringReplace(ValueEdit.Text,LineFeedSymbolUTF8,LineEnding,[rfReplaceAll])
  {$ELSE}
    Result:=ValueEdit.Text
  {$ENDIF}
  else if FCurrentEdit=ValueComboBox then
    Result:=ValueComboBox.Text
  else if FCurrentEdit=ValueCheckBox then
    Result:=ValueCheckBox.Caption
  else
    Result:='';
end;

procedure TOICustomPropertyGrid.SetActiveControl(const AControl: TWinControl);
var
  F: TCustomForm;
begin
  F := GetParentForm(Self);
  if F <> nil then
    F.ActiveControl := AControl;
end;

procedure TOICustomPropertyGrid.SetColumn(const AValue: TOICustomPropertyGridColumn);
begin
  if FColumn <> AValue then
  begin
    FColumn := AValue;
    // TODO: indication
  end;
end;

procedure TOICustomPropertyGrid.SetCurrentEditValue(const NewValue: string);
begin
  if FCurrentEdit=ValueEdit then
  {$IFDEF LCLCarbon}
    ValueEdit.Text:=StringReplace(StringReplace(NewValue,#13,LineEnding,[rfReplaceAll]),LineEnding,LineFeedSymbolUTF8,[rfReplaceAll])
  {$ELSE}
    ValueEdit.Text:=NewValue
  {$ENDIF}
  else if FCurrentEdit=ValueComboBox then
  begin
    ValueComboBox.Text:=NewValue;
    if ValueComboBox.Style=csOwnerDrawVariable then
       Exclude(FStates,pgsGetComboItemsCalled);
  end
  else if FCurrentEdit=ValueCheckBox then
    SetCheckboxState(NewValue);

  if (FItemIndex>=0) and (FItemIndex<RowCount) and Assigned(FCurrentEdit) then
  begin
    if Rows[FItemIndex].Editor.ValueIsStreamed then
      FCurrentEdit.Font:=FValueFont
    else
      FCurrentEdit.Font:=FDefaultValueFont;
  end;
end;

procedure TOICustomPropertyGrid.SetDrawHorzGridLines(const AValue: Boolean);
begin
  if FDrawHorzGridLines = AValue then Exit;
  FDrawHorzGridLines := AValue;
  Invalidate;
end;

procedure TOICustomPropertyGrid.SetFavorites(
  const AValue: TOIFavoriteProperties);
begin
  //debugln('TOICustomPropertyGrid.SetFavorites ',dbgsName(Self));
  if FFavorites=AValue then exit;
  FFavorites:=AValue;
  BuildPropertyList;
end;

procedure TOICustomPropertyGrid.SetFilter(const AValue: TTypeKinds);
begin
  if (AValue<>FFilter) then
  begin
    FFilter:=AValue;
    BuildPropertyList;
  end;
end;

procedure TOICustomPropertyGrid.SetGutterColor(const AValue: TColor);
begin
  if FGutterColor=AValue then exit;
  FGutterColor:=AValue;
  invalidate;
end;

procedure TOICustomPropertyGrid.SetGutterEdgeColor(const AValue: TColor);
begin
  if FGutterEdgeColor=AValue then exit;
  FGutterEdgeColor:=AValue;
  invalidate;
end;

procedure TOICustomPropertyGrid.SetHighlightColor(const AValue: TColor);
begin
  if FHighlightColor=AValue then exit;
  FHighlightColor:=AValue;
  Invalidate;
end;

procedure TOICustomPropertyGrid.Clear;
begin
  ClearRows;
end;

function TOICustomPropertyGrid.GetRow(Index:integer):TOIPropertyGridRow;
begin
  Result:=TOIPropertyGridRow(FRows[Index]);
end;

procedure TOICustomPropertyGrid.ValueComboBoxCloseUp(Sender: TObject);
begin
  SetRowValue(false, false);
end;

procedure TOICustomPropertyGrid.ValueComboBoxGetItems(Sender: TObject);
{ This event is called whenever the widgetset updates the list.
  On gtk the list is updated just before the user popups the list.
  Other widgetsets need the list always, which is bad, as this means collecting
  all items even if the dropdown never happens.
}
var
  CurRow: TOIPropertyGridRow;
  MaxItemWidth, CurItemWidth, i, Cnt: integer;
  ItemValue, CurValue: string;
  NewItemIndex: LongInt;
  ExcludeUpdateFlag: boolean;
begin
  Include(FStates,pgsGetComboItemsCalled);
  if (FItemIndex>=0) and (FItemIndex<FRows.Count) then begin
    ExcludeUpdateFlag:=not (pgsUpdatingEditControl in FStates);
    Include(FStates,pgsUpdatingEditControl);
    ValueComboBox.Items.BeginUpdate;
    try
      CurRow:=Rows[FItemIndex];

      // Items
      if not FillComboboxItems then exit;

      // Text and ItemIndex
      CurValue:=CurRow.Editor.GetVisualValue;
      ValueComboBox.Text:=CurValue;
      NewItemIndex:=ValueComboBox.Items.IndexOf(CurValue);
      if NewItemIndex>=0 then
        ValueComboBox.ItemIndex:=NewItemIndex;

      // ItemWidth
      MaxItemWidth:=ValueComboBox.Width;
      Cnt:=ValueComboBox.Items.Count;
      for i:=0 to Cnt-1 do begin
        ItemValue:=ValueComboBox.Items[i];
        CurItemWidth:=ValueComboBox.Canvas.TextWidth(ItemValue);
        CurRow.Editor.ListMeasureWidth(ItemValue,i,ValueComboBox.Canvas,
                                       CurItemWidth);
        if MaxItemWidth<CurItemWidth then
          MaxItemWidth:=CurItemWidth;
      end;
      ValueComboBox.ItemWidth:=MaxItemWidth;
    finally
      ValueComboBox.Items.EndUpdate;
      if ExcludeUpdateFlag then
        Exclude(FStates,pgsUpdatingEditControl);
    end;
  end;
end;

procedure TOICustomPropertyGrid.ValueComboBoxDrawItem(Control: TWinControl;
  Index: Integer; ARect: TRect; State: TOwnerDrawState);
var
  CurRow: TOIPropertyGridRow;
  ItemValue: string;
  AState: TPropEditDrawState;
  FontColor: TColor;
begin
  if (FItemIndex>=0) and (FItemIndex<FRows.Count) then begin
    CurRow:=Rows[FItemIndex];
    if (Index>=0) and (Index<ValueComboBox.Items.Count) then
      ItemValue:=ValueComboBox.Items[Index]
    else
      ItemValue:='';
    AState:=[];
    if odSelected in State then Include(AState,pedsSelected);
    if odFocused in State then Include(AState,pedsFocused);
    if odComboBoxEdit in State then
      Include(AState,pedsInEdit)
    else
      Include(AState,pedsInComboList);

    if not(odBackgroundPainted in State) then
      ValueComboBox.Canvas.FillRect(ARect);

    FontColor := ValueComboBox.Canvas.Font.Color;
    ValueComboBox.Canvas.Font.Assign(FDefaultValueFont);
    if odSelected in State then
      ValueComboBox.Canvas.Font.Color := FontColor
    else
      ValueComboBox.Canvas.Font.Color := clWindowText;
    if CurRow.Editor.HasDefaultValue and (ItemValue = CurRow.Editor.GetDefaultValue) then
      ValueComboBox.Canvas.Font.Style := ValueComboBox.Canvas.Font.Style + [fsItalic];
    CurRow.Editor.ListDrawValue(ItemValue,Index,ValueComboBox.Canvas,ARect,AState);
  end;
end;

procedure TOICustomPropertyGrid.OnIdle(Sender: TObject; var Done: Boolean);
begin
  if (not (pgsGetComboItemsCalled in FStates))
  and (FCurrentEdit=ValueComboBox)
  and ValueComboBox.Enabled
  then begin
    ValueComboBoxGetItems(Self);
  end;
end;

procedure TOICustomPropertyGrid.SetIdleEvent(Enable: boolean);
begin
  if (pgsIdleEnabled in FStates)=Enable then exit;
  if Enable then begin
    Application.AddOnIdleHandler(@OnIdle);
    Include(FStates,pgsIdleEnabled);
  end else begin
    Application.RemoveOnIdleHandler(@OnIdle);
    Exclude(FStates,pgsIdleEnabled);
  end;
end;

procedure TOICustomPropertyGrid.HintTimer(Sender: TObject);
var
  PointedRow: TOIpropertyGridRow;
  Window: TWinControl;
  HintType: TPropEditHint;
  Position, ClientPosition: TPoint;
  Index: integer;
  AHint: String;
  OkToShow: Boolean;
begin
  if FLongHintTimer <> nil then
    FLongHintTimer.Enabled := False;
  Position := Mouse.CursorPos;
  Window := FindLCLWindow(Position);
  If (Window = Nil) or ((Window <> Self) and not IsParentOf(Window)) then exit;

  ClientPosition := ScreenToClient(Position);
  if ((ClientPosition.X <=0) or (ClientPosition.X >= Width) or
     (ClientPosition.Y <= 0) or (ClientPosition.Y >= Height)) then
    Exit;

  Index := MouseToIndex(ClientPosition.Y, False);
  // Don't show hint for the selected property.
  if (Index < 0) or (Index >= FRows.Count) or (Index = ItemIndex) then Exit;

  PointedRow := Rows[Index];
  if (PointedRow = Nil) or (PointedRow.Editor = Nil) then Exit;

  // Get hint
  OkToShow := True;
  HintType := GetHintTypeAt(Index, ClientPosition.X);
  if (HintType = pehName) and Assigned(OnPropertyHint) then
    OkToShow := OnPropertyHint(Self, PointedRow, AHint)
  else
    AHint := PointedRow.Editor.GetHint(HintType, Position.X, Position.Y);
  // Show hint if all is well.
  if OkToShow and FHintManager.ShowHint(Position, AHint, True, Screen.HintFont) then
  begin
    FHintIndex := Index;
    FHintType := HintType;
    FShowingLongHint := True;
  end;
end;

procedure TOICustomPropertyGrid.HideHint;
begin
  FHintIndex := -1;
  FShowingLongHint := False;
  FHintManager.HideHint;
end;

procedure TOICustomPropertyGrid.ValueControlMouseDown(Sender : TObject;
  Button: TMouseButton; Shift: TShiftState; X, Y: integer);
begin
  HideHint;
  ScrollToActiveItem;
end;

procedure TOICustomPropertyGrid.ValueControlMouseMove(Sender: TObject;
  Shift: TShiftState; X, Y: integer);
begin
  // when the cursor is divider change it to default
  if (Sender as TControl).Parent.Cursor <> crDefault then
    TControl(Sender).Parent.Cursor := crDefault;
end;

procedure TOICustomPropertyGrid.IncreaseChangeStep;
begin
  if FChangeStep<>$7fffffff then
    inc(FChangeStep)
  else
    FChangeStep:=-$7fffffff;
end;

function TOICustomPropertyGrid.GridIsUpdating: boolean;
begin
  Result:=(FStates*[pgsChangingItemIndex,pgsApplyingValue,
                    pgsBuildPropertyListNeeded]<>[])
end;

procedure TOICustomPropertyGrid.ToggleRow;
var
  CurRow: TOIPropertyGridRow;
  TypeKind : TTypeKind;
  NewIndex: Integer;
begin
  if not CanEditRowValue(false) then exit;

  if FLongHintTimer <> nil then
    FLongHintTimer.Enabled := False;

  if (FCurrentEdit = ValueComboBox) then 
  begin
    CurRow := Rows[FItemIndex];
    TypeKind := CurRow.Editor.GetPropType^.Kind;
    // Integer (like TImageIndex), Enumeration, Set, Class or Boolean ComboBox
    if TypeKind in [tkInteger, tkEnumeration, tkSet, tkClass, tkBool] then
    begin
      if ValueComboBox.Items.Count = 0 then Exit;
      // Pick the next value from list
      if ValueComboBox.ItemIndex < (ValueComboBox.Items.Count-1) then
      begin
        NewIndex := ValueComboBox.ItemIndex + 1;
        // Go to first object of tkClass. Skip '(none)' which can be in different
        // places depending on widgetset sorting rules.
        if (ValueComboBox.ItemIndex = -1) // Only happen at nil value of tkClass
        and (ValueComboBox.Items[NewIndex] = oisNone)
        and (NewIndex < (ValueComboBox.Items.Count-1)) then
          Inc(NewIndex);
      end
      else
        NewIndex := 0;
      ValueComboBox.ItemIndex := NewIndex;
      SetRowValue(false, false);
      exit;
    end;
  end;
  DoCallEdit;
end;

procedure TOICustomPropertyGrid.ValueEditDblClick(Sender: TObject);
begin
  FFirstClickTime:=0;
  ToggleRow;
end;

procedure TOICustomPropertyGrid.SetBackgroundColor(const AValue: TColor);
begin
  if FBackgroundColor=AValue then exit;
  FBackgroundColor:=AValue;
  Invalidate;
end;

procedure TOICustomPropertyGrid.SetReferences(const AValue: TColor);
begin
  if FReferencesColor=AValue then exit;
  FReferencesColor:=AValue;
  Invalidate;
end;

procedure TOICustomPropertyGrid.SetSubPropertiesColor(const AValue: TColor);
begin
  if FSubPropertiesColor=AValue then exit;
  FSubPropertiesColor:=AValue;
  Invalidate;
end;

procedure TOICustomPropertyGrid.SetValueDifferBackgrndColor(AValue: TColor);
begin
  if FValueDifferBackgrndColor=AValue then Exit;
  FValueDifferBackgrndColor:=AValue;
  Invalidate;
end;

//------------------------------------------------------------------------------

{ TOIPropertyGridRow }

constructor TOIPropertyGridRow.Create(PropertyTree: TOICustomPropertyGrid;
  PropEditor:TPropertyEditor; ParentNode:TOIPropertyGridRow; WidgetSets: TLCLPlatforms);
begin
  inherited Create;
  // tree pointer
  FTree:=PropertyTree;
  FParent:=ParentNode;
  FNextBrother:=nil;
  FPriorBrother:=nil;
  FExpanded:=false;
  // child nodes
  FChildCount:=0;
  FFirstChild:=nil;
  FLastChild:=nil;
  // director
  FEditor:=PropEditor;
  GetLvl;
  FName:=FEditor.GetName;
  FTop:=0;
  FHeight:=FTree.RealDefaultItemHeight;
  FIndex:=-1;
  LastPaintedValue:='';
  FWidgetSets:=WidgetSets;
end;

destructor TOIPropertyGridRow.Destroy;
begin
  //debugln(['TOIPropertyGridRow.Destroy ',fname,' ',dbgs(Pointer(Self))]);
  if FPriorBrother<>nil then FPriorBrother.FNextBrother:=FNextBrother;
  if FNextBrother<>nil then FNextBrother.FPriorBrother:=FPriorBrother;
  if FParent<>nil then begin
    if FParent.FFirstChild=Self then FParent.FFirstChild:=FNextBrother;
    if FParent.FLastChild=Self then FParent.FLastChild:=FPriorBrother;
    dec(FParent.FChildCount);
  end;
  if FEditor<>nil then FEditor.Free;
  inherited Destroy;
end;

function TOIPropertyGridRow.ConsistencyCheck: integer;
var
  OldLvl, RealChildCount: integer;
  AChild: TOIPropertyGridRow;
begin
  if Top<0 then
    exit(-1);
  if Height<0 then
    exit(-2);
  if Lvl<0 then
    exit(-3);
  OldLvl:=Lvl;
  GetLvl;
  if Lvl<>OldLvl then
    exit(-4);
  if Name='' then
    exit(-5);
  if NextBrother<>nil then begin
    if NextBrother.PriorBrother<>Self then
      exit(-6);
    if NextBrother.Index<Index+1 then
      exit(-7);
  end;
  if PriorBrother<>nil then begin
    if PriorBrother.NextBrother<>Self then
      exit(-8);
    if PriorBrother.Index>Index-1 then
      Result:=-9
  end;
  if (Parent<>nil) then begin
    // has parent
    if (not Parent.HasChild(Self)) then
      exit(-10);
  end else begin
    // no parent
  end;
  if FirstChild<>nil then begin
    if Expanded then
      if (FirstChild.Index<>Index+1) then
        exit(-11);
  end else begin
    if LastChild<>nil then
      exit(-12);
  end;
  RealChildCount:=0;
  AChild:=FirstChild;
  while AChild<>nil do begin
    if AChild.Parent<>Self then
      exit(-13);
    inc(RealChildCount);
    AChild:=AChild.NextBrother;
  end;
  if RealChildCount<>ChildCount then
    exit(-14);
  Result:=0;
end;

function TOIPropertyGridRow.HasChild(Row: TOIPropertyGridRow): boolean;
var
  ChildRow: TOIPropertyGridRow;
begin
  ChildRow:=FirstChild;
  while ChildRow<>nil do
    if ChildRow=Row then
      exit(true);
  Result:=false;
end;

procedure TOIPropertyGridRow.WriteDebugReport(const Prefix: string);
var
  i: Integer;
  Item: TOIPropertyGridRow;
begin
  DebugLn([Prefix+'TOIPropertyGridRow.WriteDebugReport ',Name]);
  i:=0;
  Item:=FirstChild;
  while Item<>nil do begin
    DebugLn([Prefix+'  ',i,' ',Item.Name]);
    inc(i);
    Item:=Item.NextBrother;
  end;
end;

procedure TOIPropertyGridRow.GetLvl;
var n:TOIPropertyGridRow;
begin
  FLvl:=0;
  n:=FParent;
  while n<>nil do begin
    inc(FLvl);
    n:=n.FParent;
  end;
end;

function TOIPropertyGridRow.GetBottom:integer;
begin
  Result:=FTop+FHeight;
  if FTree.Layout = oilVertical
  then Inc(Result, FTree.GetNameRowHeight);
end;

function TOIPropertyGridRow.IsReadOnly: boolean;
begin
  Result:=Editor.IsReadOnly or IsDisabled;
end;

function TOIPropertyGridRow.IsDisabled: boolean;
var
  CurRow: TOIPropertyGridRow;
begin
  CurRow:=Self;
  while (CurRow<>nil) do begin
    if paDisableSubProperties in CurRow.Editor.GetAttributes then
      exit(true);
    CurRow:=CurRow.Parent;
  end;
  Result:=false;
end;

procedure TOIPropertyGridRow.MeasureHeight(ACanvas: TCanvas);
begin
  FHeight:=FTree.RealDefaultItemHeight;
  Editor.PropMeasureHeight(Name,ACanvas,FHeight);
end;

function TOIPropertyGridRow.Sort(const Compare: TListSortCompare): boolean;
var
  List: TFPList;
  Item: TOIPropertyGridRow;
  i: Integer;
begin
  if IsSorted(Compare) then exit(false);
  List:=TFPList.Create;
  try
    // create a TFPList of the children
    List.Capacity:=ChildCount;
    Item:=FirstChild;
    while Item<>nil do begin
      List.Add(Item);
      Item:=Item.NextBrother;
    end;
    // sort the TFPList
    List.Sort(Compare);
    // sort in double linked list
    for i:=0 to List.Count-1 do begin
      Item:=TOIPropertyGridRow(List[i]);
      if i=0 then begin
        FFirstChild:=Item;
        Item.FPriorBrother:=nil;
      end else
        Item.FPriorBrother:=TOIPropertyGridRow(List[i-1]);
      if i=List.Count-1 then begin
        FLastChild:=Item;
        Item.FNextBrother:=nil;
      end else
        Item.FNextBrother:=TOIPropertyGridRow(List[i+1]);
    end;
  finally
    List.Free;
  end;
  Result:=true;
end;

function TOIPropertyGridRow.IsSorted(const Compare: TListSortCompare): boolean;
var
  Item1: TOIPropertyGridRow;
  Item2: TOIPropertyGridRow;
begin
  if ChildCount<2 then exit(true);
  Item1:=FirstChild;
  while true do begin
    Item2:=Item1.NextBrother;
    if Item2=nil then break;
    if Compare(Item1,Item2)>0 then exit(false);
    Item1:=Item2;
  end;
  Result:=true;
end;

function TOIPropertyGridRow.Next: TOIPropertyGridRow;
begin
  if fFirstChild<>nil then
    Result:=fFirstChild
  else
    Result:=NextSkipChilds;
end;

function TOIPropertyGridRow.NextSkipChilds: TOIPropertyGridRow;
begin
  Result:=Self;
  while (Result<>nil) do begin
    if Result.NextBrother<>nil then begin
      Result:=Result.NextBrother;
      exit;
    end;
    Result:=Result.Parent;
  end;
end;

//==============================================================================


{ TOIOptions }

function TOIOptions.FPropertyGridSplitterX(Page: TObjectInspectorPage): integer;
begin
  Result:=FGridSplitterX[Page];
end;

procedure TOIOptions.FPropertyGridSplitterX(Page: TObjectInspectorPage;
  const AValue: integer);
begin
  FGridSplitterX[Page]:=AValue;
end;

constructor TOIOptions.Create;
var
  p: TObjectInspectorPage;
begin
  inherited Create;

  FSaveBounds:=false;
  FLeft:=0;
  FTop:=0;
  FWidth:=250;
  FHeight:=400;
  for p:=Low(TObjectInspectorPage) to High(TObjectInspectorPage) do
    FGridSplitterX[p]:=110;
  FDefaultItemHeight:=0;
  FShowComponentTree:=true;
  FComponentTreeHeight:=160;
  FInfoBoxHeight:=80;

  FGridBackgroundColor := DefBackgroundColor;
  FSubPropertiesColor := DefSubPropertiesColor;
  FValueColor := DefValueColor;
  FDefaultValueColor := DefDefaultValueColor;
  FValueDifferBackgrndColor := DefValueDifferBackgrndColor;
  FReadOnlyColor := DefReadOnlyColor;
  FReferencesColor := DefReferencesColor;
  FPropertyNameColor := DefNameColor;
  FHighlightColor := DefHighlightColor;
  FHighlightFontColor := DefHighlightFontColor;
  FGutterColor := DefGutterColor;
  FGutterEdgeColor := DefGutterEdgeColor;

  FCheckboxForBoolean := True;
  FBoldNonDefaultValues := True;
  FDrawGridLines := True;
  FShowPropertyFilter := True;
  FShowGutter := True;
  FShowStatusBar := True;
  FShowInfoBox := True;
end;

function TOIOptions.Load: boolean;
var
  Path: String;
  FileVersion: integer;
  Page: TObjectInspectorPage;
begin
  Result:=False;
  if ConfigStore=nil then exit;
  try
    Path:='ObjectInspectorOptions/';
    FileVersion:=ConfigStore.GetValue(Path+'Version/Value',0);
    FSaveBounds:=ConfigStore.GetValue(Path+'Bounds/Valid',False);
    if FSaveBounds then begin
      FLeft:=ConfigStore.GetValue(Path+'Bounds/Left',0);
      FTop:=ConfigStore.GetValue(Path+'Bounds/Top',0);
      FWidth:=ConfigStore.GetValue(Path+'Bounds/Width',250);
      FHeight:=ConfigStore.GetValue(Path+'Bounds/Height',400);
    end;
    if FileVersion>=2 then begin
      for Page:=Low(TObjectInspectorPage) to High(TObjectInspectorPage) do
        FGridSplitterX[Page]:=ConfigStore.GetValue(
           Path+'Bounds/'+DefaultOIPageNames[Page]+'/SplitterX',110);
    end else begin
      FGridSplitterX[oipgpProperties]:=ConfigStore.GetValue(Path+'Bounds/PropertyGridSplitterX',110);
      FGridSplitterX[oipgpEvents]:=ConfigStore.GetValue(Path+'Bounds/EventGridSplitterX',110);
    end;
    for Page:=Low(TObjectInspectorPage) to High(TObjectInspectorPage) do
      if FGridSplitterX[Page]<10 then
        FGridSplitterX[Page]:=10;

    FDefaultItemHeight:=ConfigStore.GetValue(Path+'Bounds/DefaultItemHeight',0);
    FShowComponentTree:=ConfigStore.GetValue(Path+'ComponentTree/Show/Value',True);
    FComponentTreeHeight:=ConfigStore.GetValue(Path+'ComponentTree/Height/Value',160);

    FGridBackgroundColor:=ConfigStore.GetValue(Path+'Color/GridBackground',DefBackgroundColor);
    FSubPropertiesColor:=ConfigStore.GetValue(Path+'Color/SubProperties',DefSubPropertiesColor);
    FValueColor:=ConfigStore.GetValue(Path+'Color/Value',DefValueColor);
    FDefaultValueColor:=ConfigStore.GetValue(Path+'Color/DefaultValue',DefDefaultValueColor);
    FValueDifferBackgrndColor:=ConfigStore.GetValue(Path+'Color/ValueDifferBackgrnd',DefValueDifferBackgrndColor);
    FReadOnlyColor:=ConfigStore.GetValue(Path+'Color/ReadOnly',DefReadOnlyColor);
    FReferencesColor:=ConfigStore.GetValue(Path+'Color/References',DefReferencesColor);
    FPropertyNameColor:=ConfigStore.GetValue(Path+'Color/PropertyName',DefNameColor);
    FHighlightColor:=ConfigStore.GetValue(Path+'Color/Highlight',DefHighlightColor);
    FHighlightFontColor:=ConfigStore.GetValue(Path+'Color/HighlightFont',DefHighlightFontColor);
    FGutterColor:=ConfigStore.GetValue(Path+'Color/Gutter',DefGutterColor);
    FGutterEdgeColor:=ConfigStore.GetValue(Path+'Color/GutterEdge',DefGutterEdgeColor);

    FShowHints:=ConfigStore.GetValue(Path+'ShowHints',FileVersion>=3);
    FAutoShow := ConfigStore.GetValue(Path+'AutoShow',True);
    FCheckboxForBoolean := ConfigStore.GetValue(Path+'CheckboxForBoolean',True);
    FBoldNonDefaultValues := ConfigStore.GetValue(Path+'BoldNonDefaultValues',True);
    FDrawGridLines := ConfigStore.GetValue(Path+'DrawGridLines',True);
    FShowPropertyFilter := ConfigStore.GetValue(Path+'ShowPropertyFilter',True);
    FShowGutter := ConfigStore.GetValue(Path+'ShowGutter',True);
    FShowStatusBar := ConfigStore.GetValue(Path+'ShowStatusBar',True);
    FShowInfoBox := ConfigStore.GetValue(Path+'ShowInfoBox',True);
    FInfoBoxHeight := ConfigStore.GetValue(Path+'InfoBoxHeight',80);
  except
    on E: Exception do begin
      DebugLn('ERROR: TOIOptions.Load: ',E.Message);
      exit;
    end;
  end;
  Result:=True;
end;

function TOIOptions.Save: boolean;
var
  Page: TObjectInspectorPage;
  Path: String;
begin
  Result:=False;
  if ConfigStore=nil then exit;
  try
    Path:='ObjectInspectorOptions/';
    ConfigStore.SetValue(Path+'Version/Value',OIOptionsFileVersion);
    ConfigStore.SetDeleteValue(Path+'Bounds/Valid',FSaveBounds,False);
    if FSaveBounds then begin
      ConfigStore.SetValue(Path+'Bounds/Left',FLeft);
      ConfigStore.SetValue(Path+'Bounds/Top',FTop);
      ConfigStore.SetValue(Path+'Bounds/Width',FWidth);
      ConfigStore.SetValue(Path+'Bounds/Height',FHeight);
    end;
    for Page:=Low(TObjectInspectorPage) to High(TObjectInspectorPage) do
      ConfigStore.SetDeleteValue(Path+'Bounds/'+DefaultOIPageNames[Page]+'/SplitterX',
                                 FGridSplitterX[Page],110);
    ConfigStore.SetDeleteValue(Path+'Bounds/DefaultItemHeight',FDefaultItemHeight,0);
    ConfigStore.SetDeleteValue(Path+'ComponentTree/Show/Value',FShowComponentTree,True);
    ConfigStore.SetDeleteValue(Path+'ComponentTree/Height/Value',FComponentTreeHeight,160);

    ConfigStore.SetDeleteValue(Path+'Color/GridBackground',FGridBackgroundColor,DefBackgroundColor);
    ConfigStore.SetDeleteValue(Path+'Color/SubProperties',FSubPropertiesColor,DefSubPropertiesColor);
    ConfigStore.SetDeleteValue(Path+'Color/Value',FValueColor,DefValueColor);
    ConfigStore.SetDeleteValue(Path+'Color/DefaultValue',FDefaultValueColor,DefDefaultValueColor);
    ConfigStore.SetDeleteValue(Path+'Color/ValueDifferBackgrnd',FValueDifferBackgrndColor,DefValueDifferBackgrndColor);
    ConfigStore.SetDeleteValue(Path+'Color/ReadOnly',FReadOnlyColor,DefReadOnlyColor);
    ConfigStore.SetDeleteValue(Path+'Color/References',FReferencesColor,DefReferencesColor);
    ConfigStore.SetDeleteValue(Path+'Color/PropertyName',FPropertyNameColor,DefNameColor);
    ConfigStore.SetDeleteValue(Path+'Color/Highlight',FHighlightColor,DefHighlightColor);
    ConfigStore.SetDeleteValue(Path+'Color/HighlightFont',FHighlightFontColor,DefHighlightFontColor);
    ConfigStore.SetDeleteValue(Path+'Color/Gutter',FGutterColor,DefGutterColor);
    ConfigStore.SetDeleteValue(Path+'Color/GutterEdge',FGutterEdgeColor,DefGutterEdgeColor);

    ConfigStore.SetDeleteValue(Path+'ShowHints',FShowHints, True);
    ConfigStore.SetDeleteValue(Path+'AutoShow',FAutoShow, True);
    ConfigStore.SetDeleteValue(Path+'CheckboxForBoolean',FCheckboxForBoolean, True);
    ConfigStore.SetDeleteValue(Path+'BoldNonDefaultValues',FBoldNonDefaultValues, True);
    ConfigStore.SetDeleteValue(Path+'DrawGridLines',FDrawGridLines, True);
    ConfigStore.SetDeleteValue(Path+'ShowPropertyFilter',FShowPropertyFilter, True);
    ConfigStore.SetDeleteValue(Path+'ShowGutter',FShowGutter, True);
    ConfigStore.SetDeleteValue(Path+'ShowStatusBar',FShowStatusBar, True);
    ConfigStore.SetDeleteValue(Path+'ShowInfoBox',FShowInfoBox, True);
    ConfigStore.SetDeleteValue(Path+'InfoBoxHeight',FInfoBoxHeight,80);
  except
    on E: Exception do begin
      DebugLn('ERROR: TOIOptions.Save: ',E.Message);
      exit;
    end;
  end;
  Result:=true;
end;

procedure TOIOptions.Assign(AnObjInspector: TObjectInspectorDlg);
var
  Page: TObjectInspectorPage;
begin
  FLeft:=AnObjInspector.Left;
  FTop:=AnObjInspector.Top;
  FWidth:=AnObjInspector.Width;
  FHeight:=AnObjInspector.Height;
  for Page:=Low(TObjectInspectorPage) to High(TObjectInspectorPage) do
    if AnObjInspector.GridControl[Page]<>nil then
      FGridSplitterX[Page]:=AnObjInspector.GridControl[Page].PreferredSplitterX;
  FDefaultItemHeight:=AnObjInspector.DefaultItemHeight;
  FShowComponentTree:=AnObjInspector.ShowComponentTree;
  FComponentTreeHeight:=AnObjInspector.ComponentPanelHeight;

  FGridBackgroundColor:=AnObjInspector.PropertyGrid.BackgroundColor;
  FSubPropertiesColor:=AnObjInspector.PropertyGrid.SubPropertiesColor;
  FReferencesColor:=AnObjInspector.PropertyGrid.ReferencesColor;
  FValueColor:=AnObjInspector.PropertyGrid.ValueFont.Color;
  FDefaultValueColor:=AnObjInspector.PropertyGrid.DefaultValueFont.Color;
  FValueDifferBackgrndColor:=AnObjInspector.PropertyGrid.ValueDifferBackgrndColor;
  FReadOnlyColor:=AnObjInspector.PropertyGrid.ReadOnlyColor;
  FPropertyNameColor:=AnObjInspector.PropertyGrid.NameFont.Color;
  FHighlightColor:=AnObjInspector.PropertyGrid.HighlightColor;
  FHighlightFontColor:=AnObjInspector.PropertyGrid.HighlightFont.Color;
  FGutterColor:=AnObjInspector.PropertyGrid.GutterColor;
  FGutterEdgeColor:=AnObjInspector.PropertyGrid.GutterEdgeColor;

  FShowHints := AnObjInspector.PropertyGrid.ShowHint;
  FAutoShow := AnObjInspector.AutoShow;
  FCheckboxForBoolean := AnObjInspector.FCheckboxForBoolean;
  FBoldNonDefaultValues := fsBold in AnObjInspector.PropertyGrid.ValueFont.Style;
  FDrawGridLines := AnObjInspector.PropertyGrid.DrawHorzGridLines;
  FShowPropertyFilter := AnObjInspector.ShowPropertyFilter;
  FShowGutter := AnObjInspector.PropertyGrid.ShowGutter;
  FShowStatusBar := AnObjInspector.ShowStatusBar;
  FShowInfoBox := AnObjInspector.ShowInfoBox;
  FInfoBoxHeight := AnObjInspector.InfoBoxHeight;
end;

procedure TOIOptions.AssignTo(AnObjInspector: TObjectInspectorDlg);
var
  Page: TObjectInspectorPage;
  Grid: TOICustomPropertyGrid;
begin
  if FSaveBounds then
  begin
    AnObjInspector.SetBounds(FLeft,FTop,FWidth,FHeight);
  end;

  for Page := Low(TObjectInspectorPage) to High(TObjectInspectorPage) do
  begin
    Grid := AnObjInspector.GridControl[Page];
    if Grid = nil then
      Continue;
    Grid.PreferredSplitterX := FGridSplitterX[Page];
    Grid.SplitterX := FGridSplitterX[Page];
    AssignTo(Grid);
  end;
  AnObjInspector.DefaultItemHeight := DefaultItemHeight;
  AnObjInspector.AutoShow := AutoShow;
  AnObjInspector.FCheckboxForBoolean := FCheckboxForBoolean;
  AnObjInspector.ShowComponentTree := ShowComponentTree;
  AnObjInspector.ShowPropertyFilter := ShowPropertyFilter;
  AnObjInspector.ShowInfoBox := ShowInfoBox;
  AnObjInspector.ComponentPanelHeight := ComponentTreeHeight;
  AnObjInspector.InfoBoxHeight := InfoBoxHeight;
  AnObjInspector.ShowStatusBar := ShowStatusBar;
end;

procedure TOIOptions.AssignTo(AGrid: TOICustomPropertyGrid);
begin
  AGrid.BackgroundColor := FGridBackgroundColor;
  AGrid.SubPropertiesColor := FSubPropertiesColor;
  AGrid.ReferencesColor := FReferencesColor;
  AGrid.ReadOnlyColor := FReadOnlyColor;
  AGrid.ValueDifferBackgrndColor := FValueDifferBackgrndColor;
  AGrid.ValueFont.Color := FValueColor;
  if FBoldNonDefaultValues then
    AGrid.ValueFont.Style := [fsBold]
  else
    AGrid.ValueFont.Style := [];
  AGrid.DefaultValueFont.Color := FDefaultValueColor;
  AGrid.NameFont.Color := FPropertyNameColor;
  AGrid.HighlightColor := FHighlightColor;
  AGrid.HighlightFont.Color := FHighlightFontColor;
  AGrid.GutterColor := FGutterColor;
  AGrid.GutterEdgeColor := FGutterEdgeColor;
  AGrid.ShowHint := FShowHints;
  AGrid.DrawHorzGridLines := FDrawGridLines;
  AGrid.ShowGutter := FShowGutter;
  AGrid.CheckboxForBoolean := FCheckboxForBoolean;
end;


//==============================================================================

{ TObjectInspectorDlg }

constructor TObjectInspectorDlg.Create(AnOwner: TComponent);

  procedure AddPopupMenuItem(var NewMenuItem: TMenuItem;
    ParentMenuItem: TMenuItem; const AName, ACaption, AHint, AResourceName: string;
    AnOnClick: TNotifyEvent; CheckedFlag, EnabledFlag, VisibleFlag: boolean);
  begin
    NewMenuItem:=TMenuItem.Create(Self);
    with NewMenuItem do 
    begin
      Name:=AName;
      Caption:=ACaption;
      Hint:=AHint;
      OnClick:=AnOnClick;
      Checked:=CheckedFlag;
      Enabled:=EnabledFlag;
      Visible:=VisibleFlag;
      if AResourceName <> '' then
        ImageIndex := IDEImages.LoadImage(AResourceName);
    end;
    if ParentMenuItem<>nil then
      ParentMenuItem.Add(NewMenuItem)
    else
      MainPopupMenu.Items.Add(NewMenuItem);
  end;

  function AddSeparatorMenuItem(ParentMenuItem: TMenuItem; const AName: string; VisibleFlag: boolean): TMenuItem;
  begin
    Result := TMenuItem.Create(Self);
    with Result do
    begin
      Name := AName;
      Caption := cLineCaption;
      Visible := VisibleFlag;
    end;
    if ParentMenuItem <> nil then
      ParentMenuItem.Add(Result)
    else
      MainPopupMenu.Items.Add(Result);
  end;

begin
  inherited Create(AnOwner);
  FEnableHookGetSelection := true;
  FPropertyEditorHook := nil;
  FSelection := TPersistentSelectionList.Create;
  FAutoShow := True;
  FDefaultItemHeight := 0;
  ComponentPanelHeight := 160;
  FShowComponentTree := True;
  FShowPropertyFilter := True;
  FShowFavorites := False;
  FShowRestricted := False;
  FShowStatusBar := True;
  FInfoBoxHeight := 80;
  FPropFilterUpdating := False;
  FShowInfoBox := True;
  FComponentEditor := nil;
  FFilter := DefaultOITypeKinds;

  Caption := oisObjectInspector;
  CompFilterLabel.Caption := oisBtnComponents;
  MainPopupMenu.Images := IDEImages.Images_16;

  AddPopupMenuItem(AddToFavoritesPopupMenuItem,nil,'AddToFavoritePopupMenuItem',
     oisAddtofavorites,'Add property to favorites properties', '',
     @AddToFavoritesPopupmenuItemClick,false,true,true);
  AddPopupMenuItem(RemoveFromFavoritesPopupMenuItem,nil,
     'RemoveFromFavoritesPopupMenuItem',
     oisRemovefromfavorites,'Remove property from favorites properties', '',
     @RemoveFromFavoritesPopupmenuItemClick,false,true,true);
  AddPopupMenuItem(ViewRestrictedPropertiesPopupMenuItem,nil,
     'ViewRestrictedPropertiesPopupMenuItem',
     oisViewRestrictedProperties,'View restricted property descriptions', '',
     @ViewRestrictionsPopupmenuItemClick,false,true,true);
  AddPopupMenuItem(UndoPropertyPopupMenuItem,nil,'UndoPropertyPopupMenuItem',
     oisUndo,'Set property value to last valid value', '',
     @UndoPopupmenuItemClick,false,true,true);
  AddPopupMenuItem(FindDeclarationPopupmenuItem,nil,'FindDeclarationPopupmenuItem',
     oisFinddeclaration,'Jump to declaration of property', '',
     @FindDeclarationPopupmenuItemClick,false,true,false);
  OptionsSeparatorMenuItem := AddSeparatorMenuItem(nil, 'OptionsSeparatorMenuItem', true);

  AddPopupMenuItem(CutPopupMenuItem,nil,'CutPopupMenuItem',
     oisCutComponents,'Cut selected item', 'laz_cut',
     @CutPopupmenuItemClick,false,true,true);
  AddPopupMenuItem(CopyPopupMenuItem,nil,'CopyPopupMenuItem',
     oisCopyComponents,'Copy selected item', 'laz_copy',
     @CopyPopupmenuItemClick,false,true,true);
  AddPopupMenuItem(PastePopupMenuItem,nil,'PastePopupMenuItem',
     oisPasteComponents,'Paste selected item', 'laz_paste',
     @PastePopupmenuItemClick,false,true,true);
  AddPopupMenuItem(DeletePopupMenuItem,nil,'DeletePopupMenuItem',
     oisDeleteComponents,'Delete selected item', 'delete_selection',
     @DeletePopupmenuItemClick,false,true,true);
  OptionsSeparatorMenuItem2 := AddSeparatorMenuItem(nil, 'OptionsSeparatorMenuItem2', true);

  // Change class of the component. ToDo: create a 'change_class' icon resource
  AddPopupMenuItem(ChangeClassPopupMenuItem,nil,'ChangeClassPopupMenuItem',
     oisChangeClass,'Change Class of component', '',
     @ChangeClassPopupmenuItemClick,false,true,true);
  AddPopupMenuItem(ChangeParentPopupMenuItem, nil, 'ChangeParentPopupMenuItem',
     oisChangeParent+' ...', 'Change Parent of component', '',
     @ChangeParentItemClick, False, True, True);
  OptionsSeparatorMenuItem3 := AddSeparatorMenuItem(nil, 'OptionsSeparatorMenuItem3', true);

  AddPopupMenuItem(ShowComponentTreePopupMenuItem,nil
     ,'ShowComponentTreePopupMenuItem',oisShowComponentTree, '', ''
     ,@ShowComponentTreePopupMenuItemClick,FShowComponentTree,true,true);
  ShowComponentTreePopupMenuItem.ShowAlwaysCheckable:=true;

  AddPopupMenuItem(ShowPropertyFilterPopupMenuItem,nil
     ,'ShowPropertyFilterPopupMenuItem',oisShowPropertyFilter, '', ''
     ,@ShowPropertyFilterPopupMenuItemClick,FShowPropertyFilter,true,true);
  ShowPropertyFilterPopupMenuItem.ShowAlwaysCheckable:=true;

  AddPopupMenuItem(ShowHintsPopupMenuItem,nil
     ,'ShowHintPopupMenuItem',oisShowHints,'Grid hints', ''
     ,@ShowHintPopupMenuItemClick,false,true,true);
  ShowHintsPopupMenuItem.ShowAlwaysCheckable:=true;

  AddPopupMenuItem(ShowInfoBoxPopupMenuItem,nil
     ,'ShowInfoBoxPopupMenuItem',oisShowInfoBox, '', ''
     ,@ShowInfoBoxPopupMenuItemClick,FShowInfoBox,true,true);
  ShowInfoBoxPopupMenuItem.ShowAlwaysCheckable:=true;

  AddPopupMenuItem(ShowStatusBarPopupMenuItem,nil
     ,'ShowStatusBarPopupMenuItem',oisShowStatusBar, '', ''
     ,@ShowStatusBarPopupMenuItemClick,FShowStatusBar,true,true);
  ShowStatusBarPopupMenuItem.ShowAlwaysCheckable:=true;

  AddPopupMenuItem(ShowOptionsPopupMenuItem,nil
     ,'ShowOptionsPopupMenuItem',oisOptions, '', 'oi_options'
     ,@ShowOptionsPopupMenuItemClick,false,true,FOnShowOptions<>nil);

  // combobox at top (filled with available persistents)
  with AvailPersistentComboBox do
  begin
    Sorted := true;
    AutoSelect := true;
    AutoComplete := true;
    DropDownCount := 12;
    Visible := not FShowComponentTree;
  end;

  // Component Tree at top (filled with available components)
  ComponentTree := TComponentTreeView.Create(Self);
  with ComponentTree do
  begin
    Name := 'ComponentTree';
    Parent := ComponentPanel;
    AnchorSideTop.Control := CompFilterEdit;
    AnchorSideTop.Side := asrBottom;
    AnchorSideBottom.Control := ComponentPanel;
    AnchorSideBottom.Side := asrBottom;
    BorderSpacing.Top := 3;
    BorderSpacing.Bottom := 3;
    Left := 3;
    Height := ComponentPanel.Height - BorderSpacing.Top
            - CompFilterEdit.Top - CompFilterEdit.Height;
    Width := ComponentPanel.Width-6;
    Anchors := [akTop, akLeft, akRight, akBottom];
    OnDblClick := @ComponentTreeDblClick;
    OnKeyDown := @ComponentTreeKeyDown;
    OnSelectionChanged := @ComponentTreeSelectionChanged;
    OnComponentGetImageIndex := @ComponentTreeGetNodeImageIndex;
    OnModified := @ComponentTreeModified;
    Scrollbars := ssAutoBoth;
    PopupMenu := MainPopupMenu;
  end;

  // ComponentPanel encapsulates TreeFilterEdit and ComponentTree
  ComponentPanel.Constraints.MinHeight := 8;
  ComponentPanel.Visible := FShowComponentTree;
  CompFilterEdit.FilteredTreeview := ComponentTree;

  InfoPanel := TPanel.Create(Self);
  with InfoPanel do
  begin
    Name := 'InfoPanel';
    Constraints.MinHeight := 8;
    Caption := '';
    Height := InfoBoxHeight;
    Parent := PnlClient;
    BevelOuter := bvNone;
    BevelInner := bvNone;
    Align := alBottom;
    PopupMenu := MainPopupMenu;
    Visible := FShowInfoBox;
  end;

  if ShowComponentTree then
    CreateTopSplitter;
  if ShowInfoBox then
    CreateBottomSplitter;

  //Create properties filter
  PropertyPanel := TPanel.Create(Self);
  with PropertyPanel do
  begin
    Name := 'PropertyPanel';
    Caption := '';
    Parent := PnlClient;
    BevelOuter := bvNone;
    BevelInner := bvNone;
    Align := alClient;
    Visible := True;
  end;

  PropFilterPanel := TPanel.Create(Self);
  with PropFilterPanel do
  begin
    Name := 'PropFilterPanel';
    Caption := '';
    Parent := PropertyPanel;
    BevelOuter := bvNone;
    BevelInner := bvNone;
    AutoSize := true;
    Align := alTop;
    Visible := True;
  end;

  PropFilterLabel := TLabel.Create(Self);
  PropFilterEdit:= TListFilterEdit.Create(Self);
  with PropFilterLabel do
  begin
    Parent := PropFilterPanel;
    BorderSpacing.Left := Scale96ToForm(5);
    BorderSpacing.Top := Scale96ToForm(7);
    Width := Scale96ToForm(53);
    Caption := oisBtnProperties;
    FocusControl := PropFilterEdit;
  end;

  with PropFilterEdit do
  begin
    Parent := PropFilterPanel;
    AnchorSideLeft.Control := PropFilterLabel;
    AnchorSideLeft.Side := asrBottom;
    AnchorSideTop.Control := PropFilterLabel;
    AnchorSideTop.Side := asrCenter;
    Width := PropertyPanel.Width - ( Left + 3);
    AutoSelect := False;
    ButtonWidth := Scale96ToForm(23);
    Anchors := [akTop, akLeft, akRight];
    BorderSpacing.Left := 5;
    OnAfterFilter := @PropFilterEditAfterFilter;
  end;

  CreateNoteBook;
  // TabOrder has no effect. TAB key is handled by TObjectInspectorDlg.KeyDown().
  CompFilterEdit.TabOrder := 0;
  ComponentTree.TabOrder := 1;
  PropFilterEdit.TabOrder := 2;
end;

destructor TObjectInspectorDlg.Destroy;
begin
  FreeAndNil(FSelection);
  FreeAndNil(FComponentEditor);
  FreeAndNil(PropFilterLabel);
  FreeAndNil(PropFilterEdit);
  FreeAndNil(PropFilterPanel);
  FreeAndNil(PropertyPanel);  
  inherited Destroy;
  FreeAndNil(FFavorites);
end;

procedure TObjectInspectorDlg.PropFilterEditAfterFilter(Sender: TObject);
begin
  FPropFilterUpdating := True;
  GetActivePropertyGrid.PropNameFilter := PropFilterEdit.Filter;
  RebuildPropertyLists;
  FPropFilterUpdating := False;
end;

procedure TObjectInspectorDlg.NoteBookPageChange(Sender: TObject);
begin
  PropFilterEditAfterFilter(Sender);
end;

procedure TObjectInspectorDlg.SetPropertyEditorHook(const AValue:TPropertyEditorHook);
var
  Page: TObjectInspectorPage;
  OldSelection: TPersistentSelectionList;
begin
  if FPropertyEditorHook=AValue then exit;
  if FPropertyEditorHook<>nil then begin
    FPropertyEditorHook.RemoveAllHandlersForObject(Self);
  end;
  FPropertyEditorHook:=AValue;
  if FPropertyEditorHook<>nil then begin
    FPropertyEditorHook.AddHandlerChangeLookupRoot(@HookLookupRootChange);
    FPropertyEditorHook.AddHandlerRefreshPropertyValues(@HookRefreshPropertyValues);
    FPropertyEditorHook.AddHandlerSetSelection(@HookSetSelection);
    Selection := nil;
    for Page:=Low(TObjectInspectorPage) to High(TObjectInspectorPage) do
      if GridControl[Page]<>nil then
      begin
        if Page=oipgpProperties then  // Add HookGetCheckboxForBoolean only once.
          FPropertyEditorHook.AddHandlerGetCheckboxForBoolean(
                                   @GridControl[Page].HookGetCheckboxForBoolean);
        GridControl[Page].PropertyEditorHook:=FPropertyEditorHook;
      end;
    OldSelection:=TPersistentSelectionList.Create;
    try
      FPropertyEditorHook.GetSelection(OldSelection);
      if EnableHookGetSelection then begin
        // the propertyeditorhook gets the selection from the OI
        if OldSelection.Count>0 then
          FSelection.Assign(OldSelection); // if propertyeditorhook has a selection use that
        FPropertyEditorHook.AddHandlerGetSelection(@HookGetSelection);
        if OldSelection.Count=0 then begin
          // select root component
          FSelection.Clear;
          if FPropertyEditorHook.LookupRoot is TComponent then
            FSelection.Add(TComponent(FPropertyEditorHook.LookupRoot));
        end;
      end
      else
        Selection := OldSelection; // OI gets the selection from propertyeditorhook
    finally
      OldSelection.Free;
    end;
    ComponentTree.PropertyEditorHook:=FPropertyEditorHook;
    FillComponentList(True);
    RefreshSelection;
  end;
end;

function TObjectInspectorDlg.PersistentToString(APersistent: TPersistent): string;
begin
  if APersistent is TComponent then
    Result:=TComponent(APersistent).GetNamePath+': '+APersistent.ClassName
  else
    Result:=APersistent.ClassName;
end;

procedure TObjectInspectorDlg.SetComponentPanelHeight(const AValue: integer);
begin
  if ComponentPanel.Height <> AValue then
    ComponentPanel.Height := AValue;
end;

procedure TObjectInspectorDlg.SetDefaultItemHeight(const AValue: integer);
var
  NewValue: Integer;
  Page: TObjectInspectorPage;
begin
  NewValue:=AValue;
  if NewValue<0 then
    NewValue:=0
  else if (NewValue>0) and (NewValue<10) then
    NewValue:=10
  else if NewValue>100 then NewValue:=100;
  if FDefaultItemHeight=NewValue then exit;
  FDefaultItemHeight:=NewValue;
  for Page:=Low(TObjectInspectorPage) to High(TObjectInspectorPage) do
    if GridControl[Page]<>nil then
      GridControl[Page].DefaultItemHeight:=FDefaultItemHeight;
  RebuildPropertyLists;
end;

procedure TObjectInspectorDlg.SetInfoBoxHeight(const AValue: integer);
begin
  if FInfoBoxHeight <> AValue then
  begin
    FInfoBoxHeight := AValue;
    Assert(Assigned(InfoPanel), 'TObjectInspectorDlg.SetInfoBoxHeight: InfoPanel=nil');
    InfoPanel.Height := AValue;
  end;
end;

procedure TObjectInspectorDlg.SetRestricted(const AValue: TOIRestrictedProperties);
begin
  if FRestricted = AValue then exit;
  //DebugLn('TObjectInspectorDlg.SetRestricted Count: ', DbgS(AValue.Count));
  FRestricted := AValue;
  RestrictedGrid.Favorites := FRestricted;
end;

procedure TObjectInspectorDlg.SetOnShowOptions(const AValue: TNotifyEvent);
begin
  if FOnShowOptions=AValue then exit;
  FOnShowOptions:=AValue;
  ShowOptionsPopupMenuItem.Visible:=FOnShowOptions<>nil;
end;

procedure TObjectInspectorDlg.AddPersistentToList(APersistent: TPersistent;
  List: TStrings);
var
  Allowed: boolean;
begin
  if (APersistent is TComponent)
  and (csDestroying in TComponent(APersistent).ComponentState) then exit;
  Allowed:=true;
  if Assigned(FOnAddAvailablePersistent) then
    FOnAddAvailablePersistent(APersistent,Allowed);
  if Allowed then
    List.AddObject(PersistentToString(APersistent),APersistent);
end;

procedure TObjectInspectorDlg.HookLookupRootChange;
var
  Page: TObjectInspectorPage;
begin
  for Page:=Low(TObjectInspectorPage) to High(TObjectInspectorPage) do
    if GridControl[Page]<>nil then
      GridControl[Page].PropEditLookupRootChange;
  CompFilterEdit.Filter:='';
  FillComponentList(True);
end;

procedure TObjectInspectorDlg.HookRefreshPropertyValues;
begin
  RefreshPropertyValues;
end;

procedure TObjectInspectorDlg.ChangeCompZOrderInList(APersistent: TPersistent;
  AZOrder: TZOrderDelete);
begin
  if FShowComponentTree then
    ComponentTree.ChangeCompZOrder(APersistent, AZOrder)
  else
    FillPersistentComboBox;
end;

procedure TObjectInspectorDlg.DeleteCompFromList(APersistent: TPersistent);
begin
  if FShowComponentTree then begin
    if APersistent=nil then
      ComponentTree.BuildComponentNodes(True)
    else
      ComponentTree.DeleteComponentNode(APersistent);
  end
  else
    FillPersistentComboBox;
end;

procedure TObjectInspectorDlg.FillComponentList(AWholeTree: Boolean);
begin
  if FShowComponentTree then
    ComponentTree.BuildComponentNodes(AWholeTree)
  else
    FillPersistentComboBox;
end;

procedure TObjectInspectorDlg.UpdateComponentValues;
begin
  if FShowComponentTree then
    ComponentTree.UpdateComponentNodesValues
  else
    FillPersistentComboBox;
end;

procedure TObjectInspectorDlg.FillPersistentComboBox;
var
  a: integer;
  Root: TComponent;
  OldText: AnsiString;
  NewList: TStringList;
begin
  Assert(not FUpdatingAvailComboBox,
         'TObjectInspectorDlg.FillPersistentComboBox: Updating Avail ComboBox');
  //if FUpdatingAvailComboBox then exit;
  FUpdatingAvailComboBox:=true;
  NewList:=TStringList.Create;
  try
    if (FPropertyEditorHook<>nil)
    and (FPropertyEditorHook.LookupRoot<>nil) then begin
      AddPersistentToList(FPropertyEditorHook.LookupRoot,NewList);
      if FPropertyEditorHook.LookupRoot is TComponent then begin
        Root:=TComponent(FPropertyEditorHook.LookupRoot);
  //writeln('[TObjectInspectorDlg.FillComponentComboBox] B  ',Root.Name,'  ',Root.ComponentCount);
        for a:=0 to Root.ComponentCount-1 do
          AddPersistentToList(Root.Components[a],NewList);
      end;
    end;

    if AvailPersistentComboBox.Items.Equals(NewList) then exit;

    AvailPersistentComboBox.Items.BeginUpdate;
    if AvailPersistentComboBox.Items.Count=1 then
      OldText:=AvailPersistentComboBox.Text
    else
      OldText:='';
    AvailPersistentComboBox.Items.Assign(NewList);
    AvailPersistentComboBox.Items.EndUpdate;
    a:=AvailPersistentComboBox.Items.IndexOf(OldText);
    if (OldText='') or (a<0) then
      SetAvailComboBoxText
    else
      AvailPersistentComboBox.ItemIndex:=a;

  finally
    NewList.Free;
    FUpdatingAvailComboBox:=false;
  end;
end;

procedure TObjectInspectorDlg.BeginUpdate;
begin
  inc(FUpdateLock);
end;

procedure TObjectInspectorDlg.EndUpdate;
begin
  dec(FUpdateLock);
  if FUpdateLock<0 then begin
    DebugLn('ERROR TObjectInspectorDlg.EndUpdate');
  end;
  if FUpdateLock=0 then begin
    if oifRebuildPropListsNeeded in FFLags then
      RebuildPropertyLists;
  end;
end;

function TObjectInspectorDlg.GetActivePropertyGrid: TOICustomPropertyGrid;
begin
  Result:=nil;
  if NoteBook=nil then exit;
  case NoteBook.PageIndex of
  0: Result:=PropertyGrid;
  1: Result:=EventGrid;
  2: Result:=FavoriteGrid;
  3: Result:=RestrictedGrid;
  end;
end;

function TObjectInspectorDlg.GetActivePropertyRow: TOIPropertyGridRow;
var
  CurGrid: TOICustomPropertyGrid;
begin
  Result:=nil;
  CurGrid:=GetActivePropertyGrid;
  if CurGrid=nil then exit;
  Result:=CurGrid.GetActiveRow;
end;

function TObjectInspectorDlg.GetCurRowDefaultValue(var DefaultStr: string): Boolean;
var
  CurRow: TOIPropertyGridRow;
begin
  Result:=False;
  DefaultStr:='';
  CurRow:=GetActivePropertyRow;
  if Assigned(CurRow) and (CurRow.Editor.HasDefaultValue) then
  begin
    try
      DefaultStr:=CurRow.Editor.GetDefaultValue;
      Result:=true;
    except
      DefaultStr:='';
    end;
  end;
end;

function TObjectInspectorDlg.GetParentCandidates: TFPList;
begin
  Result:=GetChangeParentCandidates(FPropertyEditorHook,Selection);
end;

function TObjectInspectorDlg.HasParentCandidates: Boolean;
var
  Candidates: TFPList=nil;
begin
  try
    Candidates := GetParentCandidates;
    Result := (Candidates.Count>1);  // single candidate is current parent
  finally
    Candidates.Free;
  end;
end;

procedure TObjectInspectorDlg.ChangeParent;
var
  i: Integer;
  Control: TControl;
  NewParentName: String;
  NewParent: TPersistent;
  NewSelection: TPersistentSelectionList;
  Candidates: TFPList = nil;
  RootDesigner: TIDesigner;
  CompEditDsg: TComponentEditorDesigner;
begin
  if (Selection.Count < 1) then Exit;
  try
    Candidates := GetParentCandidates;
    if not ShowChangeParentDlg(Selection, Candidates, NewParentName) then
      Exit;
  finally
    Candidates.Free;
  end;

  if NewParentName = TWinControl(FPropertyEditorHook.LookupRoot).Name then
    NewParent := FPropertyEditorHook.LookupRoot
  else
    NewParent := TWinControl(FPropertyEditorHook.LookupRoot).FindComponent(NewParentName);
  if not (NewParent is TWinControl) then Exit;

  // Find designer for Undo actions.
  RootDesigner := FindRootDesigner(FPropertyEditorHook.LookupRoot);
  if (RootDesigner is TComponentEditorDesigner) then
    CompEditDsg := TComponentEditorDesigner(RootDesigner) //if CompEditDsg.IsUndoLocked then Exit;
  else
    CompEditDsg := nil;

  for i := 0 to Selection.Count-1 do
  begin
    if not (Selection[i] is TControl) then Continue;
    Control := TControl(Selection[i]);
    if Control.Parent = nil then Continue;
    if Assigned(CompEditDsg) then
      CompEditDsg.AddUndoAction(Control, uopChange, i=0, 'Parent',
                                Control.Parent.Name, NewParentName);
    Control.Parent := TWinControl(NewParent);
  end;

  // Ensure the order of controls in the OI now reflects the new ZOrder
  // This code is based on ZOrderItemClick().
  NewSelection := TPersistentSelectionList.Create;
  try
    NewSelection.ForceUpdate:=True;
    NewSelection.Add(NewParent);
    for i:=0 to Selection.Count-1 do
      NewSelection.Add(Selection.Items[i]);
    SetSelection(NewSelection);
    NewSelection.ForceUpdate:=True;
    NewSelection.Delete(0);
    SetSelection(NewSelection);
  finally
    NewSelection.Free;
  end;
  DoModified;
  FillComponentList(True);
end;

procedure TObjectInspectorDlg.SetSelection(const ASelection: TPersistentSelectionList);
begin
  if FSettingSelectionCount > 0 then Exit; // Prevent a recursive loop.
  Inc(FSettingSelectionCount);
  try
    if ASelection<>nil then begin
      // Nothing changed or endless loop -> quit.
      if FSelection.IsEqual(ASelection) and not ASelection.ForceUpdate then
        Exit;
    end else begin
      if FSelection.Count=0 then
        Exit;
    end;
    if ASelection<>nil then
      FSelection.Assign(ASelection)
    else
      FSelection.Clear;
    SetAvailComboBoxText;
    RefreshSelection;
    if Assigned(FOnSelectPersistentsInOI) then
      FOnSelectPersistentsInOI(Self);
  finally
    Dec(FSettingSelectionCount);
  end;
end;

procedure TObjectInspectorDlg.RefreshSelection;
var
  Page: TObjectInspectorPage;
begin
  if FRefreshingSelectionCount > 0 then Exit; // Prevent a recursive loop.
  Inc(FRefreshingSelectionCount);

  if NoteBook.Page[3].Visible then
  begin
    DoUpdateRestricted;
    // invalidate RestrictedProps
    WidgetSetsRestrictedBox.Invalidate;
    ComponentRestrictedBox.Invalidate;
  end;

  for Page := Low(TObjectInspectorPage) to High(TObjectInspectorPage) do
    if GridControl[Page] <> nil then
      GridControl[Page].Selection := FSelection;
  RefreshComponentTreeSelection;
  if (not Visible) and AutoShow and (FSelection.Count > 0) then
    if Assigned(OnAutoShow) then
      OnAutoShow(Self)
    else
      Visible := True;
  Dec(FRefreshingSelectionCount);
end;

procedure TObjectInspectorDlg.RefreshComponentTreeSelection;
begin
  ComponentTree.Selection := FSelection;
  ComponentTree.MakeSelectionVisible;
end;

procedure TObjectInspectorDlg.SaveChanges;
var
  Page: TObjectInspectorPage;
begin
  for Page:=Low(TObjectInspectorPage) to High(TObjectInspectorPage) do
    if GridControl[Page]<>nil then
      GridControl[Page].SaveChanges;
end;

procedure TObjectInspectorDlg.RefreshPropertyValues;
var
  Page: TObjectInspectorPage;
begin
  for Page:=Low(TObjectInspectorPage) to High(TObjectInspectorPage) do
    if GridControl[Page]<>nil then
      GridControl[Page].RefreshPropertyValues;
end;

procedure TObjectInspectorDlg.RebuildPropertyLists;
var
  Page: TObjectInspectorPage;
begin
  if FUpdateLock>0 then
    Include(FFLags,oifRebuildPropListsNeeded)
  else begin
    Exclude(FFLags,oifRebuildPropListsNeeded);
    for Page:=Low(TObjectInspectorPage) to High(TObjectInspectorPage) do
      if GridControl[Page]<>nil then
        GridControl[Page].BuildPropertyList(False, not FPropFilterUpdating);
  end;
end;

procedure TObjectInspectorDlg.AvailComboBoxCloseUp(Sender:TObject);
var
  NewComponent,Root:TComponent;
  a:integer;

  procedure SetSelectedPersistent(c:TPersistent);
  begin
    if (FSelection.Count=1) and (FSelection[0]=c) then exit;
    FSelection.Clear;
    FSelection.Add(c);
    RefreshSelection;
    if Assigned(FOnSelectPersistentsInOI) then
      FOnSelectPersistentsInOI(Self);
  end;

begin
  if FUpdatingAvailComboBox then exit;
  if (FPropertyEditorHook=nil) or (FPropertyEditorHook.LookupRoot=nil) then
    exit;
  if not (FPropertyEditorHook.LookupRoot is TComponent) then begin
    // not a TComponent => no children => select always only the root
    SetSelectedPersistent(FPropertyEditorHook.LookupRoot);
    exit;
  end;
  Root:=TComponent(FPropertyEditorHook.LookupRoot);
  if (AvailPersistentComboBox.Text=PersistentToString(Root)) then begin
    SetSelectedPersistent(Root);
  end else begin
    for a:=0 to Root.ComponentCount-1 do begin
      NewComponent:=Root.Components[a];
      if AvailPersistentComboBox.Text=PersistentToString(NewComponent) then
      begin
        SetSelectedPersistent(NewComponent);
        break;
      end;
    end;
  end;
end;

function TObjectInspectorDlg.GetComponentEditorForSelection: TBaseComponentEditor;
var
  APersistent: TPersistent;
  AComponent: TComponent absolute APersistent;
  ADesigner: TIDesigner;
begin
  APersistent := GetSelectedPersistent;
  if not (APersistent is TComponent) then
    Exit(nil);
  ADesigner := FindRootDesigner(AComponent);
  if not (ADesigner is TComponentEditorDesigner) then
    Exit(nil);
  Result := GetComponentEditor(AComponent, TComponentEditorDesigner(ADesigner));
end;

procedure TObjectInspectorDlg.ComponentTreeDblClick(Sender: TObject);
var
  CompEditor: TBaseComponentEditor;
begin
  if (PropertyEditorHook = nil) or (PropertyEditorHook.LookupRoot = nil) then
    Exit;
  if not FSelection.IsEqual(ComponentTree.Selection) then
    ComponentTreeSelectionChanged(Sender);
  CompEditor := GetComponentEditorForSelection;
  if Assigned(CompEditor) then
  begin
    try
      CompEditor.Edit;
    finally
      CompEditor.Free;
    end;
  end;
end;

function TObjectInspectorDlg.CanDeleteSelection: Boolean;
var
  persistent: TPersistent;
  intf: IObjInspInterface;
  i: Integer;
begin
  Result := true;
  for i:=0 to ComponentTree.Selection.Count - 1 do begin
    persistent := ComponentTree.Selection[i];
    if persistent.GetInterface(GUID_ObjInspInterface, intf) and not intf.AllowDelete then
      exit(false);
  end;
end;

procedure TObjectInspectorDlg.ComponentTreeKeyDown(Sender: TObject;
  var Key: Word; Shift: TShiftState);
begin
  if (Shift = []) and (Key = VK_DELETE) and
     (Selection.Count > 0) and CanDeleteSelection and
     (MessageDlg(oiscDelete, mtConfirmation,[mbYes, mbNo],0) = mrYes) then
  begin
    DeletePopupmenuItemClick(nil);
  end;
end;        

procedure TObjectInspectorDlg.ComponentTreeSelectionChanged(Sender: TObject);
begin
  if (PropertyEditorHook=nil) or (PropertyEditorHook.LookupRoot=nil) then exit;
  if FSelection.IsEqual(ComponentTree.Selection) then exit;
  FSelection.Assign(ComponentTree.Selection);
  RefreshSelection;
  DefSelectionVisibleInDesigner;
  if Assigned(FOnSelectPersistentsInOI) then
    FOnSelectPersistentsInOI(Self);
end;

procedure TObjectInspectorDlg.MainPopupMenuClose(Sender: TObject);
begin
  if FStateOfHintsOnMainPopupMenu then ShowHintPopupMenuItemClick(nil);
end;

procedure TObjectInspectorDlg.FormResize(Sender: TObject);
begin
  ComponentPanel.Constraints.MaxHeight := Height-50;
end;

procedure TObjectInspectorDlg.GridKeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
var
  Handled: Boolean;
begin
  Handled := false;

  //CTRL-[Shift]-TAB will select next or previous notebook tab
  if (Key=VK_TAB) and (ssCtrl in Shift) then
  begin
    Handled := true;
    if ssShift in Shift then
      ShowNextPage(-1)
    else
      ShowNextPage(1);
  end;

  //CTRL-ArrowDown will dropdown the component combobox
  if (not Handled) and ((Key=VK_DOWN) or (Key=VK_UP)) and (ssCtrl in Shift) then
  begin
    Handled := true;
    if AvailPersistentComboBox.Canfocus then
      AvailPersistentComboBox.SetFocus;
    AvailPersistentComboBox.DroppedDown := true;
  end;

  if not Handled then
  begin
    if Assigned(OnOIKeyDown) then
      OnOIKeyDown(Self,Key,Shift);
    if (Key<>VK_UNKNOWN) and Assigned(OnRemainingKeyDown) then
      OnRemainingKeyDown(Self,Key,Shift);
  end
  else
    Key := VK_UNKNOWN;
end;

procedure TObjectInspectorDlg.GridKeyUp(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
  if Assigned(OnRemainingKeyUp) then OnRemainingKeyUp(Self,Key,Shift);
end;

procedure TObjectInspectorDlg.GridDblClick(Sender: TObject);
begin
  //
end;

procedure TObjectInspectorDlg.PropEditPopupClick(Sender: TObject);
var
  CurGrid: TOICustomPropertyGrid;
  CurRow: TOIPropertyGridRow;
  s: String;
begin
  CurGrid:=GetActivePropertyGrid;
  CurRow := GetActivePropertyRow;
  CurRow.Editor.ExecuteVerb((Sender as TMenuItem).Tag);
  s := CurRow.Editor.GetVisualValue;
  CurGrid.CurrentEditValue := s;
  RefreshPropertyValues;
  Invalidate;
  DebugLn(['Executed verb number ', (Sender as TMenuItem).Tag, ', VisualValue: ', s, ', CurRow: ', CurRow]);
end;

procedure TObjectInspectorDlg.AddToFavoritesPopupmenuItemClick(Sender: TObject);
begin
  //debugln('TObjectInspectorDlg.OnAddToFavoritePopupmenuItemClick');
  if Assigned(OnAddToFavorites) then OnAddToFavorites(Self);
end;

procedure TObjectInspectorDlg.RemoveFromFavoritesPopupmenuItemClick(Sender: TObject);
begin
  if Assigned(OnRemoveFromFavorites) then OnRemoveFromFavorites(Self);
end;

procedure TObjectInspectorDlg.ViewRestrictionsPopupmenuItemClick(Sender: TObject);
begin
  DoViewRestricted;
end;

procedure TObjectInspectorDlg.UndoPopupmenuItemClick(Sender: TObject);
var
  CurGrid: TOICustomPropertyGrid;
  CurRow: TOIPropertyGridRow;
begin
  CurGrid:=GetActivePropertyGrid;
  CurRow:=GetActivePropertyRow;
  if CurRow=nil then exit;
  CurGrid.CurrentEditValue:=CurRow.Editor.GetVisualValue;
end;

procedure TObjectInspectorDlg.FindDeclarationPopupmenuItemClick(Sender: TObject);
begin
  if Assigned(OnFindDeclarationOfProperty) then
    OnFindDeclarationOfProperty(Self);
end;

procedure TObjectInspectorDlg.CutPopupmenuItemClick(Sender: TObject);
var
  ADesigner: TIDesigner;
begin
  if (Selection.Count > 0) and (Selection[0] is TComponent) then
  begin
    ADesigner := FindRootDesigner(Selection[0]);
    if ADesigner is TComponentEditorDesigner then
      TComponentEditorDesigner(ADesigner).CutSelection;
  end;
end;

procedure TObjectInspectorDlg.CopyPopupmenuItemClick(Sender: TObject);
var
  ADesigner: TIDesigner;
begin
  if (Selection.Count > 0) and (Selection[0] is TComponent) then
  begin
    ADesigner := FindRootDesigner(Selection[0]);
    if ADesigner is TComponentEditorDesigner then
      TComponentEditorDesigner(ADesigner).CopySelection;
  end;
end;

procedure TObjectInspectorDlg.PastePopupmenuItemClick(Sender: TObject);
var
  ADesigner: TIDesigner;
begin
  if Selection.Count > 0 then
  begin
    ADesigner := FindRootDesigner(Selection[0]);
    if ADesigner is TComponentEditorDesigner then
      TComponentEditorDesigner(ADesigner).PasteSelection([]);
  end;
end;

procedure TObjectInspectorDlg.DeletePopupmenuItemClick(Sender: TObject);
var
  ADesigner: TIDesigner;
  ACollection: TCollection;
  i: integer;
begin
  if (Selection.Count > 0) then
  begin
    ADesigner := FindRootDesigner(Selection[0]);
    if ADesigner is TComponentEditorDesigner then
    begin
      if Selection[0] is TCollection then
      begin
        ACollection := TCollection(Selection[0]);
        Selection.BeginUpdate;
        Selection.Clear;
        for i := 0 to ACollection.Count - 1 do
          Selection.Add(ACollection.Items[i]);
        Selection.EndUpdate;
        if Assigned(FOnSelectPersistentsInOI) then
          FOnSelectPersistentsInOI(Self);
      end;
      TComponentEditorDesigner(ADesigner).DeleteSelection;
    end;
  end;
end;

procedure TObjectInspectorDlg.ChangeClassPopupmenuItemClick(Sender: TObject);
var
  ADesigner: TIDesigner;
begin
  if (Selection.Count = 1) then
  begin
    ADesigner := FindRootDesigner(Selection[0]);
    if ADesigner is TComponentEditorDesigner then
      TComponentEditorDesigner(ADesigner).ChangeClass;
  end;
end;

procedure TObjectInspectorDlg.GridModified(Sender: TObject);
begin
  DoModified;
end;

procedure TObjectInspectorDlg.GridSelectionChange(Sender: TObject);
var
  Row: TOIPropertyGridRow;
begin
  Row := GetActivePropertyRow;
  if Assigned(Row) then
    FLastActiveRowName := Row.Name;
  if Assigned(FOnSelectionChange) then
    FOnSelectionChange(Self);
end;

function TObjectInspectorDlg.GridPropertyHint(Sender: TObject;
  PointedRow: TOIPropertyGridRow; out AHint: string): boolean;
begin
  Result := False;
  if Assigned(FOnPropertyHint) then
    Result := FOnPropertyHint(Sender, PointedRow, AHint);
end;

procedure TObjectInspectorDlg.SetAvailComboBoxText;
begin
  case FSelection.Count of
    0: // none selected
       AvailPersistentComboBox.Text:='';
    1: // single selection
       AvailPersistentComboBox.Text:=PersistentToString(FSelection[0]);
  else
    // multi selection
    AvailPersistentComboBox.Text:=Format(oisItemsSelected, [FSelection.Count]);
  end;
end;

procedure TObjectInspectorDlg.HookGetSelection(const ASelection: TPersistentSelectionList);
begin
  if ASelection=nil then exit;
  ASelection.Assign(FSelection);
end;

procedure TObjectInspectorDlg.HookSetSelection(const ASelection: TPersistentSelectionList);
begin
  Selection := ASelection;
end;

procedure TObjectInspectorDlg.SetShowComponentTree(const AValue: boolean);
begin
  if FShowComponentTree = AValue then Exit;
  FShowComponentTree := AValue;
  BeginUpdate;
  try
    ShowComponentTreePopupMenuItem.Checked := FShowComponentTree;
    // hide / show / rebuild controls
    AvailPersistentComboBox.Visible := not FShowComponentTree;
    ComponentPanel.Visible := FShowComponentTree;
    if FShowComponentTree then
      CreateTopSplitter
    else
      FreeAndNil(Splitter1);
    FillComponentList(True);
  finally
    EndUpdate;
  end;
end;

procedure TObjectInspectorDlg.SetShowPropertyFilter(const AValue: Boolean);
begin
  if FShowPropertyFilter = AValue then exit;
  FShowPropertyFilter := AValue;
  PropFilterPanel.Visible := AValue;
  ShowPropertyFilterPopupMenuItem.Checked := AValue;
end;

procedure TObjectInspectorDlg.SetShowInfoBox(const AValue: Boolean);
begin
  if FShowInfoBox = AValue then exit;
  FShowInfoBox := AValue;
  ShowInfoBoxPopupMenuItem.Checked := AValue;
  InfoPanel.Visible := AValue;
  if AValue then begin
    CreateBottomSplitter;
    if Assigned(FOnSelectionChange) then
      FOnSelectionChange(Self);
  end
  else
    FreeAndNil(Splitter2);
end;

procedure TObjectInspectorDlg.SetShowStatusBar(const AValue: Boolean);
begin
  if FShowStatusBar = AValue then exit;
  FShowStatusBar := AValue;
  StatusBar.Visible := AValue;
  ShowStatusBarPopupMenuItem.Checked := AValue;
  if ShowInfoBox then // make sure StatusBar goes below InfoPanel.
    StatusBar.Top := InfoPanel.Top + InfoPanel.Height + 1;
end;

procedure TObjectInspectorDlg.SetShowFavorites(const AValue: Boolean);
begin
  if FShowFavorites = AValue then exit;
  FShowFavorites := AValue;
  NoteBook.Page[2].TabVisible := AValue;
end;

procedure TObjectInspectorDlg.SetShowRestricted(const AValue: Boolean);
begin
  if FShowRestricted = AValue then exit;
  FShowRestricted := AValue;
  NoteBook.Page[3].TabVisible := AValue;
end;

procedure TObjectInspectorDlg.ShowNextPage(Delta: integer);
var
  NewPageIndex: Integer;
begin
  NewPageIndex := NoteBook.PageIndex;
  repeat
    NewPageIndex := NewPageIndex + Delta;
    if NewPageIndex >= NoteBook.PageCount then
      NewPageIndex := 0;
    if NewPageIndex < 0 then
      NewPageIndex := NoteBook.PageCount - 1;
    if NoteBook.Page[NewPageIndex].TabVisible then
    begin
      NoteBook.PageIndex := NewPageIndex;
      break;
    end;
  until NewPageIndex = NoteBook.PageIndex;
end;

procedure TObjectInspectorDlg.RestrictedPageShow(Sender: TObject);
begin
  //DebugLn('RestrictedPageShow');
  DoUpdateRestricted;
end;

procedure TObjectInspectorDlg.RestrictedPaint(
  ABox: TPaintBox; const ARestrictions: TWidgetSetRestrictionsArray);

  function OutVertCentered(AX: Integer; const AStr: String): TSize;
  begin
    Result := ABox.Canvas.TextExtent(AStr);
    ABox.Canvas.TextOut(AX, (ABox.Height - Result.CY) div 2, AStr);
  end;

var
  X, Y: Integer;
  lclPlatform: TLCLPlatform;
  None: Boolean;
  OldStyle: TBrushStyle;
  ImagesRes: TScaledImageListResolution;
  dist: Integer;
begin
  ImagesRes := IDEImages.Images_16.ResolutionForPPI[0, Font.PixelsPerInch, GetCanvasScaleFactor];
  dist := Scale96ToForm(4);
  X := 0;
  Y := (ABox.Height - ImagesRes.Height) div 2;
  OldStyle := ABox.Canvas.Brush.Style;
  try
    ABox.Canvas.Brush.Style := bsClear;
    None := True;
    for lclPlatform := Low(TLCLPlatform) to High(TLCLPlatform) do
    begin
      if ARestrictions[lclPlatform] = 0 then continue;
      None := False;
      ImagesRes.Draw(
        ABox.Canvas, X, Y,
        IDEImages.LoadImage('issue_'+LCLPlatformDirNames[lclPlatform]));
      Inc(X, ImagesRes.Width);
      Inc(X, Scale96ToForm(OutVertCentered(X, IntToStr(ARestrictions[lclPlatform])).CX));
      Inc(X, dist);
    end;

    if None then
      OutVertCentered(4, oisNone);
  finally
    ABox.Canvas.Brush.Style := OldStyle;
  end;
end;

procedure TObjectInspectorDlg.WidgetSetRestrictedPaint(Sender: TObject);
begin
  if RestrictedProps <> nil then
    RestrictedPaint(WidgetSetsRestrictedBox, RestrictedProps.WidgetSetRestrictions);
end;

procedure TObjectInspectorDlg.ComponentRestrictedPaint(Sender: TObject);
var
  I, J: Integer;
  WSRestrictions: TWidgetSetRestrictionsArray;
  RestrProp: TOIRestrictedProperty;
begin
  if (RestrictedProps = nil) or (Selection = nil) then exit;

  FillChar(WSRestrictions{%H-}, SizeOf(WSRestrictions), 0);
  for I := 0 to RestrictedProps.Count - 1 do
  begin
    if not (RestrictedProps.Items[I] is TOIRestrictedProperty) then continue;
    RestrProp:=TOIRestrictedProperty(RestrictedProps.Items[I]);
    for J := 0 to Selection.Count - 1 do
      with RestrProp do
        CheckRestrictions(Selection[J].ClassType, WSRestrictions);
  end;

  RestrictedPaint(ComponentRestrictedBox, WSRestrictions);
end;

procedure TObjectInspectorDlg.TopSplitterMoved(Sender: TObject);
begin
  Assert(Assigned(ComponentTree));
  ComponentTree.Invalidate;  // Update Scrollbars.
end;

procedure TObjectInspectorDlg.CreateTopSplitter;
// vertical splitter between component tree and notebook
begin
  Splitter1 := TSplitter.Create(Self);
  with Splitter1 do
  begin
    Name := 'Splitter1';
    Parent := PnlClient;
    Align := alTop;
    Top := ComponentPanelHeight;
    Height := 5;
    OnMoved := @TopSplitterMoved;
  end;
end;

procedure TObjectInspectorDlg.DefSelectionVisibleInDesigner;
  procedure ShowPage(const aPage: TTabSheet);
  begin
    if aPage.Parent is TPageControl then
      TPageControl(aPage.Parent).PageIndex := aPage.PageIndex;
  end;
  procedure ShowPage(const aPage: TPage);
  begin
    if aPage.Parent is TNotebook then
      TNotebook(aPage.Parent).PageIndex := aPage.PageIndex;
  end;
var
  Cnt: TControl;
begin
  if (Selection.Count = 0) or (Selection[0] = nil) or not(Selection[0] is TControl) then
    Exit;

  Cnt := TControl(Selection[0]);
  while Cnt<>nil do
  begin
    if Cnt is TTabSheet then
      ShowPage(TTabSheet(Cnt))
    else
    if Cnt is TPage then
      ShowPage(TPage(Cnt));

    Cnt := Cnt.Parent;
  end;
end;

procedure TObjectInspectorDlg.CreateBottomSplitter;
// vertical splitter between notebook and info panel
begin
  Splitter2 := TSplitter.Create(Self);
  with Splitter2 do
  begin
    Name := 'Splitter2';
    Parent := PnlClient;
    Align := alBottom;
    Top := InfoPanel.Top - 1;
    Height := 5;
  end;
end;

procedure TObjectInspectorDlg.DestroyNoteBook;
begin
  if NoteBook<>nil then
    NoteBook.Visible:=false;
  FreeAndNil(PropertyGrid);
  FreeAndNil(EventGrid);
  FreeAndNil(FavoriteGrid);
  FreeAndNil(RestrictedGrid);
  FreeAndNil(NoteBook);
end;

procedure TObjectInspectorDlg.CreateNoteBook;

  function CreateGrid(
    ATypeFilter: TTypeKinds; AOIPage: TObjectInspectorPage;
    ANotebookPage: Integer): TOICustomPropertyGrid;
  begin
    Result:=TOICustomPropertyGrid.CreateWithParams(
      Self, PropertyEditorHook, ATypeFilter, FDefaultItemHeight);
    with Result do
    begin
      Name := DefaultOIGridNames[AOIPage];
      Selection := Self.FSelection;
      Align := alClient;
      PopupMenu := MainPopupMenu;
      OnModified := @GridModified;
      OnSelectionChange := @GridSelectionChange;
      OnPropertyHint := @GridPropertyHint;
      OnOIKeyDown := @GridKeyDown;
      OnKeyUp := @GridKeyUp;
      OnDblClick := @GridDblClick;
      OnMouseWheel := @OnGridMouseWheel;

      Parent := NoteBook.Page[ANotebookPage];
    end;
  end;

  function AddPage(PageName, TabCaption: string): TTabSheet;
  begin
    Result:=TTabSheet.Create(Self);
    Result.Name:=PageName;
    Result.Caption:=TabCaption;
    Result.Parent:=NoteBook;
  end;
var
  APage: TTabSheet;
begin
  DestroyNoteBook;

  // NoteBook
  NoteBook:=TPageControl.Create(Self);
  with NoteBook do
  begin
    Name := 'NoteBook';
    Parent := PropertyPanel;
    Align := alClient;
    PopupMenu := MainPopupMenu;
    OnChange := @NoteBookPageChange;
    BorderSpacing.Top := 2;
  end;

  AddPage(DefaultOIPageNames[oipgpProperties],oisProperties);

  AddPage(DefaultOIPageNames[oipgpEvents],oisEvents);

  APage:=AddPage(DefaultOIPageNames[oipgpFavorite],oisFavorites);
  APage.TabVisible := ShowFavorites;

  APage:=AddPage(DefaultOIPageNames[oipgpRestricted],oisRestricted);
  APage.TabVisible := ShowRestricted;
  APage.OnShow := @RestrictedPageShow;
    
  NoteBook.PageIndex:=0;

  PropertyGrid := CreateGrid(Filter - [tkMethod], oipgpProperties, 0);
  EventGrid := CreateGrid([tkMethod], oipgpEvents, 1);
  FavoriteGrid := CreateGrid(Filter + [tkMethod], oipgpFavorite, 2);
  FavoriteGrid.Favorites := FFavorites;
  RestrictedGrid := CreateGrid(Filter + [tkMethod], oipgpRestricted, 3);

  RestrictedPanel := TPanel.Create(Self);
  with RestrictedPanel do
  begin
    Align := alTop;
    BevelOuter := bvNone;
    Parent := NoteBook.Page[3];
  end;
  
  RestrictedInnerPanel := TPanel.Create(Self);
  with RestrictedInnerPanel do
  begin
    BevelOuter := bvNone;
    BorderSpacing.Around := 6;
    Parent := RestrictedPanel;
  end;
  
  WidgetSetsRestrictedLabel := TLabel.Create(Self);
  with WidgetSetsRestrictedLabel do
  begin
    Caption := oisWidgetSetRestrictions;
    Top := 1;
    Align := alTop;
    AutoSize := True;
    Parent := RestrictedInnerPanel;
  end;
  
  WidgetSetsRestrictedBox := TPaintBox.Create(Self);
  with WidgetSetsRestrictedBox do
  begin
    Top := 2;
    Align := alTop;
    Height := 24;
    OnPaint := @WidgetSetRestrictedPaint;
    Parent := RestrictedInnerPanel;
  end;
  
  ComponentRestrictedLabel := TLabel.Create(Self);
  with ComponentRestrictedLabel do
  begin
    Caption := oisComponentRestrictions;
    Top := 3;
    Align := alTop;
    AutoSize := True;
    Parent := RestrictedInnerPanel;
  end;
  
  ComponentRestrictedBox := TPaintBox.Create(Self);
  with ComponentRestrictedBox do
  begin
    Top := 4;
    Align := alTop;
    Height := 24;
    OnPaint := @ComponentRestrictedPaint;
    Parent := RestrictedInnerPanel;
  end;
  
  RestrictedInnerPanel.AutoSize := True;
  RestrictedPanel.AutoSize := True;
end;

procedure TObjectInspectorDlg.KeyDown(var Key: Word; Shift: TShiftState);
var
  CurGrid: TOICustomPropertyGrid;
begin
  // ToDo: Allow TAB key to FilterEdit, TreeView and Grid. Now the Grid gets seleted always.
  //DebugLn(['TObjectInspectorDlg.KeyDown: Key=', Key, ', ActiveControl=', ActiveControl]);
  //Do not disturb the combobox navigation while it has focus
  if not AvailPersistentComboBox.DroppedDown then begin
    CurGrid:=GetActivePropertyGrid;
    if CurGrid<>nil then begin
      CurGrid.HandleStandardKeys(Key,Shift);
      if Key=VK_UNKNOWN then exit;
    end;
  end;
  inherited KeyDown(Key, Shift);
  if (Key<>VK_UNKNOWN) and Assigned(OnRemainingKeyDown) then
    OnRemainingKeyDown(Self,Key,Shift);
end;

procedure TObjectInspectorDlg.KeyUp(var Key: Word; Shift: TShiftState);
begin
  inherited KeyUp(Key, Shift);
  if (Key<>VK_UNKNOWN) and Assigned(OnRemainingKeyUp) then
    OnRemainingKeyUp(Self,Key,Shift);
end;

procedure TObjectInspectorDlg.Resize;
begin
  inherited Resize;
  // BUG: resize gets called, even if nothing changed
  if Assigned(ComponentTree) and (FLastTreeSize <> ComponentTree.BoundsRect) then begin
    ComponentTree.Invalidate;  // Update Scrollbars.
    FLastTreeSize := ComponentTree.BoundsRect;
  end;
end;

procedure TObjectInspectorDlg.ComponentTreeModified(Sender: TObject);
begin
  DoModified;
end;

function TObjectInspectorDlg.GetSelectedPersistent: TPersistent;
begin
  if ComponentTree.Selection.Count = 1 then
    Result := ComponentTree.Selection[0]
  else
    Result := nil;
end;

procedure TObjectInspectorDlg.ShowComponentTreePopupMenuItemClick(Sender: TObject);
begin
  ShowComponentTree:=not ShowComponentTree;
end;

procedure TObjectInspectorDlg.ShowPropertyFilterPopupMenuItemClick(Sender: TObject);
begin
  ShowPropertyFilter := not ShowPropertyFilter;
end;

procedure TObjectInspectorDlg.ShowHintPopupMenuItemClick(Sender : TObject);
var
  Page: TObjectInspectorPage;
begin
  for Page := Low(TObjectInspectorPage) to High(TObjectInspectorPage) do
    if GridControl[Page] <> nil then
      GridControl[Page].ShowHint := not GridControl[Page].ShowHint;
end;

procedure TObjectInspectorDlg.ShowInfoBoxPopupMenuItemClick(Sender: TObject);
begin
  ShowInfoBox:=not ShowInfoBox;
end;

procedure TObjectInspectorDlg.ShowStatusBarPopupMenuItemClick(Sender: TObject);
begin
  ShowStatusBar:=not ShowStatusBar;
end;

procedure TObjectInspectorDlg.ShowOptionsPopupMenuItemClick(Sender: TObject);
begin
  if Assigned(FOnShowOptions) then FOnShowOptions(Sender);
end;
// ---

procedure TObjectInspectorDlg.MainPopupMenuPopup(Sender: TObject);
const
  PropertyEditorMIPrefix = 'PropertyEditorVerbMenuItem';
  ComponentEditorMIPrefix = 'ComponentEditorVerbMenuItem';
var
  ComponentEditorVerbSeparator: TMenuItem;
  PropertyEditorVerbSeparator: TMenuItem;

  procedure RemovePropertyEditorMenuItems;
  var
    I: Integer;
  begin
    PropertyEditorVerbSeparator := nil;
    for I := MainPopupMenu.Items.Count - 1 downto 0 do
      if Pos(PropertyEditorMIPrefix, MainPopupMenu.Items[I].Name) = 1 then
        MainPopupMenu.Items[I].Free;
  end;

  procedure AddPropertyEditorMenuItems(Editor: TPropertyEditor);
  var
    I, VerbCount: Integer;
    Item: TMenuItem;
  begin
    VerbCount := Editor.GetVerbCount;
    for I := 0 to VerbCount - 1 do
    begin
      Item := NewItem(Editor.GetVerb(I), 0, False, True,
        @PropEditPopupClick, 0, PropertyEditorMIPrefix + IntToStr(i));
      Editor.PrepareItem(I, Item);
      Item.Tag:=I;
      MainPopupMenu.Items.Insert(I, Item);
    end;
    // insert the separator
    if VerbCount > 0 then
    begin
      PropertyEditorVerbSeparator := Menus.NewLine;
      PropertyEditorVerbSeparator.Name := PropertyEditorMIPrefix + IntToStr(VerbCount);
      MainPopupMenu.Items.Insert(VerbCount, PropertyEditorVerbSeparator);
    end;
  end;

  procedure RemoveComponentEditorMenuItems;
  var
    I: Integer;
  begin
    ComponentEditorVerbSeparator:=nil;
    for I := MainPopupMenu.Items.Count - 1 downto 0 do
      if Pos(ComponentEditorMIPrefix, MainPopupMenu.Items[I].Name) = 1 then
        MainPopupMenu.Items[I].Free;
  end;

  procedure AddComponentEditorMenuItems;
  var
    I, VerbCount: Integer;
    Item: TMenuItem;
  begin
    VerbCount := ComponentEditor.GetVerbCount;
    for I := 0 to VerbCount - 1 do
    begin
      Item := NewItem(ComponentEditor.GetVerb(I), 0, False, True,
        @ComponentEditorVerbMenuItemClick, 0, ComponentEditorMIPrefix + IntToStr(i));
      ComponentEditor.PrepareItem(I, Item);
      Item.Tag:=I;
      MainPopupMenu.Items.Insert(I, Item);
    end;
    // insert the separator
    if VerbCount > 0 then
    begin
      ComponentEditorVerbSeparator := Menus.NewLine;
      ComponentEditorVerbSeparator.Name := ComponentEditorMIPrefix + IntToStr(VerbCount);
      MainPopupMenu.Items.Insert(VerbCount, ComponentEditorVerbSeparator);
    end;
  end;

  procedure AddCollectionEditorMenuItems({%H-}ACollection: TCollection);
  var
    Item: TMenuItem;
    intf: IObjInspInterface;
  begin
    if ACollection.GetInterface(GUID_ObjInspInterface, intf) and not intf.AllowAdd then
      exit;

    Item := NewItem(oisAddCollectionItem, 0, False, True,
      @CollectionAddItem, 0, ComponentEditorMIPrefix+'0');
    MainPopupMenu.Items.Insert(0, Item);
    ComponentEditorVerbSeparator := NewLine;
    ComponentEditorVerbSeparator.Name := ComponentEditorMIPrefix+'1';
    MainPopupMenu.Items.Insert(1, ComponentEditorVerbSeparator);
  end;

  procedure AddZOrderMenuItems;
  var
    ZItem, Item: TMenuItem;
  begin
    ZItem := NewSubMenu(oisZOrder, 0, ComponentEditorMIPrefix+'ZOrder', [], True);
    Item := NewItem(oisOrderMoveToFront, 0, False, True, @ZOrderItemClick, 0, '');
    Item.ImageIndex := IDEImages.LoadImage('Order_move_front');
    Item.Tag := 0;
    ZItem.Add(Item);
    Item := NewItem(oisOrderMoveToBack, 0, False, True, @ZOrderItemClick, 0, '');
    Item.ImageIndex := IDEImages.LoadImage('Order_move_back');
    Item.Tag := 1;
    ZItem.Add(Item);
    Item := NewItem(oisOrderForwardOne, 0, False, True, @ZOrderItemClick, 0, '');
    Item.ImageIndex := IDEImages.LoadImage('Order_forward_one');
    Item.Tag := 2;
    ZItem.Add(Item);
    Item := NewItem(oisOrderBackOne, 0, False, True, @ZOrderItemClick, 0, '');
    Item.ImageIndex := IDEImages.LoadImage('Order_back_one');
    Item.Tag := 3;
    ZItem.Add(Item);
    if ComponentEditorVerbSeparator <> nil then
      MainPopupMenu.Items.Insert(ComponentEditorVerbSeparator.MenuIndex + 1, ZItem)
    else
      MainPopupMenu.Items.Insert(0, ZItem);
    Item := NewLine;
    Item.Name := ComponentEditorMIPrefix+'ZOrderSeparator';
    MainPopupMenu.Items.Insert(ZItem.MenuIndex + 1, Item);
  end;

var
  b, CanBeCopyPasted, CanBeDeleted, CanChangeClass, HasParentCand: Boolean;
  i: Integer;
  CurRow: TOIPropertyGridRow;
  Persistent: TPersistent;
  Page: TObjectInspectorPage;
begin
  RemovePropertyEditorMenuItems;
  RemoveComponentEditorMenuItems;
  ShowHintsPopupMenuItem.Checked := PropertyGrid.ShowHint;
  FStateOfHintsOnMainPopupMenu:=PropertyGrid.ShowHint;
  for Page := Low(TObjectInspectorPage) to High(TObjectInspectorPage) do
    if GridControl[Page] <> nil then
      GridControl[Page].ShowHint := False;
  Persistent := GetSelectedPersistent;
  CanBeCopyPasted := False;
  CanBeDeleted := False;
  CanChangeClass := False;
  HasParentCand := False;
  // show component editors only for component treeview
  if MainPopupMenu.PopupComponent = ComponentTree then
  begin
    ComponentEditor := GetComponentEditorForSelection;
    if ComponentEditor <> nil then
      AddComponentEditorMenuItems
    else
    begin
      // check if it is a TCollection
      if Persistent is TCollection then
        AddCollectionEditorMenuItems(TCollection(Persistent))
      else if Persistent is TCollectionItem then
        AddCollectionEditorMenuItems(TCollectionItem(Persistent).Collection);
    end;
    for i:=0 to Selection.Count-1 do
      if Selection[i] is TComponent then
      begin
        CanBeDeleted := True;
        // ToDo: Figure out why TMenuItem or TAction cannot be copy / pasted in OI,
        if not (Selection[i] is TMenuItem) and
           not (Selection[i] is TAction) then     // then fix it.
          CanBeCopyPasted := True;
      end;
    CanChangeClass := (Selection.Count = 1) and (Selection[0] is TComponent)
                  and (Selection[0] <> FPropertyEditorHook.LookupRoot);
    // add Z-Order menu
    if (Selection.Count = 1) and (Selection[0] is TControl) then
      AddZOrderMenuItems;
    // check existing of Change Parent candidates
    if CanBeCopyPasted then
      HasParentCand := HasParentCandidates;
  end;
  CutPopupMenuItem.Visible := CanBeCopyPasted;
  CopyPopupMenuItem.Visible := CanBeCopyPasted;
  PastePopupMenuItem.Visible := CanBeCopyPasted;
  DeletePopupMenuItem.Visible := CanBeDeleted;
  OptionsSeparatorMenuItem2.Visible := CanBeCopyPasted or CanBeDeleted;
  ChangeClassPopupmenuItem.Visible := CanChangeClass;
  ChangeParentPopupmenuItem.Visible := HasParentCand;
  OptionsSeparatorMenuItem3.Visible := CanChangeClass or HasParentCand;

  // The editors can do menu actions, for example set defaults and constraints
  CurRow := GetActivePropertyRow;
  if (MainPopupMenu.PopupComponent is TOICustomPropertyGrid) then
  begin
    // popup menu of property grid
    if CurRow<>nil then
      AddPropertyEditorMenuItems(CurRow.Editor);

    b := (Favorites <> nil) and ShowFavorites and (GetActivePropertyRow <> nil);
    AddToFavoritesPopupMenuItem.Visible := b and
      (GetActivePropertyGrid <> FavoriteGrid) and Assigned(OnAddToFavorites);
    RemoveFromFavoritesPopupMenuItem.Visible := b and
      (GetActivePropertyGrid = FavoriteGrid) and Assigned(OnRemoveFromFavorites);

    UndoPropertyPopupMenuItem.Visible := True;
    UndoPropertyPopupMenuItem.Enabled := (CurRow<>nil)
      and (CurRow.Editor.GetVisualValue <> GetActivePropertyGrid.CurrentEditValue);
    if CurRow=nil then begin
      FindDeclarationPopupmenuItem.Visible := False;
    end
    else begin
      FindDeclarationPopupmenuItem.Visible := true;
      FindDeclarationPopupmenuItem.Caption := Format(oisJumpToDeclarationOf, [CurRow.Name]);
      FindDeclarationPopupmenuItem.Hint := Format(oisJumpToDeclarationOf,
                                              [CurRow.Editor.GetPropertyPath(0)]);
    end;
    ViewRestrictedPropertiesPopupMenuItem.Visible := True;
    OptionsSeparatorMenuItem.Visible := True;
  end
  else
  begin
    // default popup menu
    AddToFavoritesPopupMenuItem.Visible := False;
    RemoveFromFavoritesPopupMenuItem.Visible := False;
    UndoPropertyPopupMenuItem.Visible := False;
    FindDeclarationPopupmenuItem.Visible := False;
    ViewRestrictedPropertiesPopupMenuItem.Visible := False;
    OptionsSeparatorMenuItem.Visible := False;
  end;
  //debugln(['TObjectInspectorDlg.OnMainPopupMenuPopup ',FindDeclarationPopupmenuItem.Visible]);
end;

procedure TObjectInspectorDlg.DoModified;
begin
  if Assigned(FOnModified) then FOnModified(Self);
end;

procedure TObjectInspectorDlg.DoUpdateRestricted;
begin
  if Assigned(FOnUpdateRestricted) then FOnUpdateRestricted(Self);
end;

procedure TObjectInspectorDlg.DoViewRestricted;
begin
  if Assigned(FOnViewRestricted) then FOnViewRestricted(Self);
end;

procedure TObjectInspectorDlg.ChangeParentItemClick(Sender: TObject);
begin
  if Selection.Count > 0 then
    ChangeParent;
end;

procedure TObjectInspectorDlg.ComponentEditorVerbMenuItemClick(Sender: TObject);
var
  Verb: integer;
  AMenuItem: TMenuItem;
begin
  if Sender is TMenuItem then
    AMenuItem := TMenuItem(Sender)
  else
    Exit;
  Verb := AMenuItem.Tag;
  ComponentEditor.ExecuteVerb(Verb);
end;

procedure TObjectInspectorDlg.CollectionAddItem(Sender: TObject);
var
  Persistent: TPersistent;
  Collection: TCollection absolute Persistent;
  ci: TCollectionItem;
begin
  Persistent := GetSelectedPersistent;
  if Persistent = nil then
    Exit;
  if Persistent is TCollectionItem then
    Persistent := TCollectionItem(Persistent).Collection;
  if not (Persistent is TCollection) then
    Exit;
  ci:=Collection.Add;
  GlobalDesignHook.PersistentAdded(ci,false);
  DoModified;
  Selection.ForceUpdate := True;
  try
    SetSelection(Selection);
  finally
    Selection.ForceUpdate := False;
  end;
end;

procedure TObjectInspectorDlg.ZOrderItemClick(Sender: TObject);
var
  Control: TControl;
  ZOrder: TZOrderDelete;
  NewSelection: TPersistentSelectionList;
begin
  if not (Sender is TMenuItem) then Exit;
  if (Selection.Count <> 1) or not (Selection[0] is TControl) then Exit;
  Control := TControl(Selection[0]);
  if Control.Parent = nil then Exit;
  // The enum matches with the Tag numbers.
  ZOrder := TZOrderDelete(TMenuItem(Sender).Tag);
  case ZOrder of
    zoToFront: Control.BringToFront;
    zoToBack:  Control.SendToBack;
    zoForward: Control.Parent.SetControlIndex(Control, Control.Parent.GetControlIndex(Control) + 1);
    zoBackward:Control.Parent.SetControlIndex(Control, Control.Parent.GetControlIndex(Control) - 1);
  end;

  // Ensure controls that belong to a container are rearranged if required.
  Control.Parent.ReAlign;

  // Ensure the order of controls in the OI now reflects the new ZOrder
  NewSelection := TPersistentSelectionList.Create;
  try
    NewSelection.ForceUpdate:=True;
    NewSelection.Add(Control.Parent);
    SetSelection(NewSelection);
    NewSelection.Clear;
    NewSelection.ForceUpdate:=True;
    NewSelection.Add(Control);
    SetSelection(NewSelection);
  finally
    NewSelection.Free;
  end;
  DoModified;
  ChangeCompZOrderInList(Control, ZOrder);
end;

function TObjectInspectorDlg.GetComponentPanelHeight: integer;
begin
  Result := ComponentPanel.Height;
end;

function TObjectInspectorDlg.GetInfoBoxHeight: integer;
begin
  Result := InfoPanel.Height;
end;

procedure TObjectInspectorDlg.SetEnableHookGetSelection(AValue: boolean);
begin
  if FEnableHookGetSelection=AValue then Exit;
  FEnableHookGetSelection:=AValue;
  if PropertyEditorHook<>nil then
    if EnableHookGetSelection then
      FPropertyEditorHook.AddHandlerGetSelection(@HookGetSelection)
    else
      FPropertyEditorHook.RemoveHandlerGetSelection(@HookGetSelection)
end;

procedure TObjectInspectorDlg.SetFilter(const AValue: TTypeKinds);
begin
  if FFilter=AValue then Exit;
  FFilter:=AValue;
  PropertyGrid.Filter := Filter - [tkMethod];
  FavoriteGrid.Filter := Filter + [tkMethod];
  RestrictedGrid.Filter := Filter + [tkMethod];
end;

procedure TObjectInspectorDlg.ActivateGrid(Grid: TOICustomPropertyGrid);
begin
  if Grid=PropertyGrid then NoteBook.PageIndex:=0
  else if Grid=EventGrid then NoteBook.PageIndex:=1
  else if Grid=FavoriteGrid then NoteBook.PageIndex:=2
  else if Grid=RestrictedGrid then NoteBook.PageIndex:=3;
end;

procedure TObjectInspectorDlg.FocusGrid(Grid: TOICustomPropertyGrid);
var
  Index: Integer;
begin
  if Grid=nil then
    Grid := GetActivePropertyGrid
  else
    ActivateGrid(Grid);
  if Grid <> nil then
  begin
    Index := Grid.ItemIndex;
    if Index < 0 then
      Index := 0;
    Grid.SetItemIndexAndFocus(Index);
  end;
end;

function TObjectInspectorDlg.GetGridControl(Page: TObjectInspectorPage
  ): TOICustomPropertyGrid;
begin
  case Page of
  oipgpFavorite: Result:=FavoriteGrid;
  oipgpEvents: Result:=EventGrid;
  oipgpRestricted: Result:=RestrictedGrid;
  else  Result:=PropertyGrid;
  end;
end;

procedure TObjectInspectorDlg.SetComponentEditor(const AValue: TBaseComponentEditor);
begin
  if FComponentEditor <> AValue then
  begin
    FComponentEditor.Free;
    FComponentEditor := AValue;
  end;
end;

procedure TObjectInspectorDlg.SetFavorites(const AValue: TOIFavoriteProperties);
begin
  //debugln('TObjectInspectorDlg.SetFavorites ',dbgsName(Self));
  if FFavorites=AValue then exit;
  FFavorites:=AValue;
  FavoriteGrid.Favorites:=FFavorites;
end;

procedure TObjectInspectorDlg.ComponentTreeGetNodeImageIndex(
  APersistent: TPersistent; var AIndex: integer);
begin
  //ask TMediator
  if assigned(FOnNodeGetImageIndex) then
    FOnNodeGetImageIndex(APersistent, AIndex);
end;

{ TCustomPropertiesGrid }

function TCustomPropertiesGrid.GetTIObject: TPersistent;
begin
  if PropertyEditorHook<>nil then
    Result:=PropertyEditorHook.LookupRoot
  else
    Result:=Nil;
end;

procedure TCustomPropertiesGrid.SetAutoFreeHook(const AValue: boolean);
begin
  if FAutoFreeHook=AValue then exit;
  FAutoFreeHook:=AValue;
end;

procedure TCustomPropertiesGrid.SetTIObject(const AValue: TPersistent);
var
  NewSelection: TPersistentSelectionList;
begin
  if (TIObject=AValue) then begin
    if ((AValue<>nil) and (Selection.Count=1) and (Selection[0]=AValue))
    or (AValue=nil) then
      exit;
  end;
  if SaveOnChangeTIObject then
    SaveChanges;
  if PropertyEditorHook=nil then
  begin
    fAutoFreeHook:=true;
    PropertyEditorHook:=TPropertyEditorHook.Create(Self);
  end;
  PropertyEditorHook.LookupRoot:=AValue;
  if (AValue=nil) or (Selection.Count<>1) or (Selection[0]<>AValue) then
  begin
    NewSelection:=TPersistentSelectionList.Create;
    try
      if AValue<>nil then
        NewSelection.Add(AValue);
      Selection:=NewSelection;
    finally
      NewSelection.Free;
    end;
  end;
end;

constructor TCustomPropertiesGrid.Create(TheOwner: TComponent);
var
  Hook: TPropertyEditorHook;
begin
  Hook:=TPropertyEditorHook.Create(Self);
  FAutoFreeHook:=true;
  FSaveOnChangeTIObject:=true;
  CreateWithParams(TheOwner,Hook,AllTypeKinds,0);
end;

destructor TCustomPropertiesGrid.Destroy;
begin
  if FAutoFreeHook then
    FreeAndNil(FPropertyEditorHook);
  inherited Destroy;
end;
  
end.


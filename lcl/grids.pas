{ $Id$}
{
 /***************************************************************************
                               Grids.pas
                               ---------
                     An interface to DB aware Controls
                     Initial Revision : Sun Sep 14 2003


 ***************************************************************************/

 *****************************************************************************
  This file is part of the Lazarus Component Library (LCL)

  See the file COPYING.modifiedLGPL.txt, included in this distribution,
  for details about the license.
 *****************************************************************************
}
{

TCustomGrid, TDrawGrid and TStringGrid for Lazarus
Copyright (C) 2002  Jesus Reyes Aguilar.
email: jesusrmx@yahoo.com.mx

}

unit Grids;

{$mode objfpc}{$H+}
{$modeswitch nestedprocvars}
{$define NewCols}

interface

uses
  // RTL + FCL
  Classes, SysUtils, Types, TypInfo, Math, FPCanvas, HtmlDefs, StrUtils,
  // LCL
  LCLStrConsts, LCLType, LCLIntf, Controls, Graphics, Forms,
  LMessages, StdCtrls, LResources, MaskEdit, Buttons, Clipbrd, Themes, imglist,
  // LazUtils
  LazFileUtils, DynamicArray, Maps, LazUTF8, Laz2_XMLCfg,
  LazLoggerBase, LazUtilities, LCSVUtils, IntegerList
{$ifdef WINDOWS}
  ,messages, imm
{$endif}
  ;

const
  //GRIDFILEVERSION = 1; // Original
  //GRIDFILEVERSION = 2; // Introduced goSmoothScroll
  GRIDFILEVERSION = 3; // Introduced Col/Row FixedAttr and NormalAttr

const
  GM_SETVALUE   = LM_INTERFACELAST + 100;
  GM_GETVALUE   = LM_INTERFACELAST + 101;
  GM_SETGRID    = LM_INTERFACELAST + 102;
  GM_SETBOUNDS  = LM_INTERFACELAST + 103;
  GM_SELECTALL  = LM_INTERFACELAST + 104;
  GM_SETMASK    = LM_INTERFACELAST + 105;
  GM_SETPOS     = LM_INTERFACELAST + 106;
  GM_READY      = LM_INTERFACELAST + 107;
  GM_GETGRID    = LM_INTERFACELAST + 108;


const
  EO_AUTOSIZE     =   $1;
  EO_HOOKKEYDOWN  =   $2;
  EO_HOOKKEYPRESS =   $4;
  EO_HOOKKEYUP    =   $8;
  EO_SELECTALL    =   $10;
  EO_IMPLEMENTED  =   $20;

const
  DEFCOLWIDTH         = 64;
  DEFBUTTONWIDTH      = 25;
  DEFIMAGEPADDING     = 2;

type
  EGridException = class(Exception);

type
  TGridOption = (
    goFixedVertLine,      // Ya
    goFixedHorzLine,      // Ya
    goVertLine,           // Ya
    goHorzLine,           // Ya
    goRangeSelect,        // Ya
    goDrawFocusSelected,  // Ya
    goRowSizing,          // Ya
    goColSizing,          // Ya
    goRowMoving,          // Ya
    goColMoving,          // Ya
    goEditing,            // Ya
    goAutoAddRows,        // JuMa
    goTabs,               // Ya
    goRowSelect,          // Ya
    goAlwaysShowEditor,   // Ya
    goThumbTracking,      // ya
    // Additional Options
    goColSpanning,        // Enable cellextent calcs
    goRelaxedRowSelect,   // User can see focused cell on goRowSelect
    goDblClickAutoSize,   // dblclicking columns borders (on hdrs) resize col.
    goSmoothScroll,       // Switch scrolling mode (pixel scroll is by default)
    goFixedRowNumbering,  // Ya
    goScrollKeepVisible,  // keeps focused cell visible while scrolling
    goHeaderHotTracking,  // Header cells change look when mouse is over them
    goHeaderPushedLook,   // Header cells looks pushed when clicked
    goSelectionActive,    // Setting grid.Selection moves also cell cursor
    goFixedColSizing,     // Allow to resize fixed columns
    goDontScrollPartCell, // clicking partially visible cells will not scroll
    goCellHints,          // show individual cell hints
    goTruncCellHints,     // show cell hints if cell text is too long
    goCellEllipsis,       // show "..." if cell text is too long
    goAutoAddRowsSkipContentCheck,//BB Also add a row (if AutoAddRows in Options) if last row is empty
    goRowHighlight        // Highlight the current Row
  );
  TGridOptions = set of TGridOption;

  TGridOption2 = (
    goScrollToLastCol,  // allow scrolling to last column (so that last column can be leftcol)
    goScrollToLastRow   // allow scrolling to last row (so that last row can be toprow)
  );
  TGridOptions2 = set of TGridOption2;

  TGridSaveOptions = (
    soDesign,             // Save grid structure (col/row count and Options)
    soAttributes,         // Save grid attributes (Font,Brush,TextStyle)
    soContent,            // Save Grid Content (Text in stringgrid)
    soPosition            // Save Grid cursor and selection position
  );
  TSaveOptions = set of TGridSaveOptions;

  TGridDrawState = set of (gdSelected, gdFocused, gdFixed, gdHot, gdPushed, gdRowHighlight);
  TGridState =(gsNormal, gsSelecting, gsRowSizing, gsColSizing, gsRowMoving,
    gsColMoving, gsHeaderClicking, gsButtonColumnClicking);

  TGridZone = (gzNormal, gzFixedCols, gzFixedRows, gzFixedCells, gzInvalid);
  TGridZoneSet = set of TGridZone;

  TAutoAdvance = (aaNone,aaDown,aaRight,aaLeft, aaRightDown, aaLeftDown,
    aaRightUp, aaLeftUp);

  { Option goRangeSelect: --> select a single range only, or multiple ranges }
  TRangeSelectMode = (rsmSingle, rsmMulti);

  TItemType = (itNormal,itCell,itColumn,itRow,itFixed,itFixedColumn,itFixedRow,itSelected);

  TColumnButtonStyle = (
    cbsAuto,
    cbsEllipsis,
    cbsNone,
    cbsPickList,
    cbsCheckboxColumn,
    cbsButton,
    cbsButtonColumn
  );

  TTitleStyle = (tsLazarus, tsStandard, tsNative);

  TGridFlagsOption = (gfEditorUpdateLock, gfNeedsSelectActive, gfEditorTab,
    gfRevEditorTab, gfVisualChange, gfColumnsLocked,
    gfEditingDone, gfSizingStarted, gfPainting, gfUpdatingSize, gfClientRectChange,
    gfAutoEditPending, gfUpdatingScrollbar);
  TGridFlags = set of TGridFlagsOption;

  TSortOrder = (soAscending, soDescending);

  TPrefixOption = (poNone, poHeaderClick);

  TMouseWheelOption = (mwCursor, mwGrid);

  TCellHintPriority = (chpAll, chpAllNoDefault, chpTruncOnly);
  // The grid can display three types of hint: the default hint (Hint property),
  // individual cell hints (OnCellHint event), and hints for truncated cells.
  // TCellHintPriority determines how the overall hint is combined when more
  // multiple hint texts are to be displayed.

  TCellProcessType = (cpCopy, cpPaste);

const
  soAll: TSaveOptions = [soDesign, soAttributes, soContent, soPosition];

  DefaultGridOptions = [goFixedVertLine, goFixedHorzLine,
       goVertLine, goHorzLine, goRangeSelect, goSmoothScroll ];
  DefaultGridOptions2 = [];

  constRubberSpace: byte = 2;
  constCellPadding: byte = 3;
  constColRowBorderTolerance: byte = 3;

var
  // Values to be used after HighDPI scaling
  varRubberSpace: byte;
  varCellpadding: byte;
  varColRowBorderTolerance: byte;

type

  TCustomGrid = class;
  TGridColumn = class;

  PCellProps= ^TCellProps;
  TCellProps=record
    Attr: pointer;
    Data: TObject;
    Text: pchar;
  end;

  PColRowProps= ^TColRowProps;
  TColRowProps=record
    Size: Integer;
    FixedAttr: pointer;
    NormalAttr: pointer;
  end;

  PGridMessage=^TGridMessage;
  TGridMessage=record
    LclMsg: TLMessage;
    Grid: TCustomGrid;
    Col,Row: Integer;
    Value: string;
    CellRect: TRect;
    Options: Integer;
  end;

 type
  { Default cell editor for TStringGrid }
  { TStringCellEditor }

  TStringCellEditor=class(TCustomMaskEdit)
  private
    FGrid: TCustomGrid;
    FCol,FRow:Integer;
  protected
    procedure WndProc(var TheMessage : TLMessage); override;
    procedure Change; override;
    procedure KeyDown(var Key : Word; Shift : TShiftState); override;
    procedure msg_SetMask(var Msg: TGridMessage); message GM_SETMASK;
    procedure msg_SetValue(var Msg: TGridMessage); message GM_SETVALUE;
    procedure msg_GetValue(var Msg: TGridMessage); message GM_GETVALUE;
    procedure msg_SetGrid(var Msg: TGridMessage); message GM_SETGRID;
    procedure msg_SelectAll(var Msg: TGridMessage); message GM_SELECTALL;
    procedure msg_SetPos(var Msg: TGridMessage); message GM_SETPOS;
    procedure msg_GetGrid(var Msg: TGridMessage); message GM_GETGRID;
  public
    constructor Create(Aowner : TComponent); override;
    procedure EditingDone; override;
    property EditText;
    property OnEditingDone;
  end;

  { TButtonCellEditor }

  TButtonCellEditor = class(TButton)
  private
    FGrid: TCustomGrid;
    FCol,FRow: Integer;
  protected
    procedure msg_SetGrid(var Msg: TGridMessage); message GM_SETGRID;
    procedure msg_SetBounds(var Msg: TGridMessage); message GM_SETBOUNDS;
    procedure msg_SetPos(var Msg: TGridMessage); message GM_SETPOS;
    procedure msg_Ready(var Msg: TGridMessage); message GM_READY;
    procedure msg_GetGrid(var Msg: TGridMessage); message GM_GETGRID;
  public
    property Col: Integer read FCol;
    property Row: Integer read FRow;
  end;

  { TPickListCellEditor }

  TPickListCellEditor = class(TCustomComboBox)
  private
    FGrid: TCustomGrid;
    FCol,FRow: Integer;
  protected
    procedure WndProc(var TheMessage : TLMessage); override;
    procedure KeyDown(var Key : Word; Shift : TShiftState); override;
    procedure DropDown; override;
    procedure CloseUp; override;
    procedure Select; override;
    procedure Change; override;
    procedure msg_GetValue(var Msg: TGridMessage); message GM_GETVALUE;
    procedure msg_SetGrid(var Msg: TGridMessage); message GM_SETGRID;
    procedure msg_SetValue(var Msg: TGridMessage); message GM_SETVALUE;
    procedure msg_SetPos(var Msg: TGridMessage); message GM_SETPOS;
    procedure msg_GetGrid(var Msg: TGridMessage); message GM_GETGRID;
  public
    procedure EditingDone; override;
    property BorderStyle;
    property OnEditingDone;
  end;

  { TCompositeCellEditor }

  TEditorItem = record
    Editor: TWinControl;
    Align: TAlign;
    ActiveControl: boolean;
  end;

  TCompositeCellEditor = class(TWinControl)
  private
    FGrid: TCustomGrid;
    FCol,FRow: Integer;
    FEditors: array of TEditorItem;
    procedure DispatchMsg(msg: TGridMessage);
    function GetMaxLength: Integer;
    procedure SetMaxLength(AValue: Integer);
  protected
    function  DoUTF8KeyPress(var UTF8Key: TUTF8Char): boolean; override;
    procedure msg_GetValue(var Msg: TGridMessage); message GM_GETVALUE;
    procedure msg_SetGrid(var Msg: TGridMessage); message GM_SETGRID;
    procedure msg_SetValue(var Msg: TGridMessage); message GM_SETVALUE;
    procedure msg_SetBounds(var Msg: TGridMessage); message GM_SETBOUNDS;
    procedure msg_SetMask(var Msg: TGridMessage); message GM_SETMASK;
    procedure msg_SelectAll(var Msg: TGridMessage); message GM_SELECTALL;
    procedure CMControlChange(var Message: TLMEssage); message CM_CONTROLCHANGE;
    procedure msg_SetPos(var Msg: TGridMessage); message GM_SETPOS;
    procedure msg_GetGrid(var Msg: TGridMessage); message GM_GETGRID;
    function GetActiveControl: TWinControl;
    procedure VisibleChanging; override;
    function  SendChar(AChar: TUTF8Char): Integer;
    procedure WndProc(var TheMessage : TLMessage); override;
  public
    destructor Destroy; override;
    procedure AddEditor(aEditor: TWinControl; aAlign: TAlign; ActiveCtrl:boolean);
    procedure SetFocus; override;
    function  Focused: Boolean; override;
    property MaxLength: Integer read GetMaxLength write SetMaxLength;
    property ActiveControl: TWinControl read GetActiveControl;
  end;


  TOnDrawCell =
    procedure(Sender: TObject; aCol, aRow: Integer; aRect: TRect;
              aState:TGridDrawState) of object;

  TOnSelectCellEvent =
    procedure(Sender: TObject; aCol, aRow: Integer;
              var CanSelect: Boolean) of object;

  TOnSelectEvent =
    procedure(Sender: TObject; aCol, aRow: Integer) of object;

  TGridOperationEvent =
    procedure (Sender: TObject; IsColumn:Boolean;
               sIndex, tIndex: Integer) of object;

  THdrEvent =
    procedure(Sender: TObject; IsColumn: Boolean; Index: Integer) of object;

  TOnCompareCells =
    procedure (Sender: TObject; ACol, ARow, BCol,BRow: Integer;
               var Result: integer) of object;

  TSelectEditorEvent =
    procedure(Sender: TObject; aCol, aRow: Integer;
              var Editor: TWinControl) of object;

  TOnPrepareCanvasEvent =
    procedure(sender: TObject; aCol, aRow: Integer;
              aState: TGridDrawState) of object;

  TUserCheckBoxBitmapEvent =
    procedure(Sender: TObject; const aCol, aRow: Integer;
              const CheckedState: TCheckboxState;
              var ABitmap: TBitmap) of object;

  TUserCheckBoxImageEvent =
    procedure(Sender: TObject; const aCol, aRow: Integer;
              const CheckedState: TCheckBoxState;
              var ImageList: TCustomImageList;
              var ImageIndex: TImageIndex) of object;

  TValidateEntryEvent =
    procedure(sender: TObject; aCol, aRow: Integer;
              const OldValue: string; var NewValue: String) of object;

  TToggledCheckboxEvent = procedure(sender: TObject; aCol, aRow: Integer;
                                    aState: TCheckboxState) of object;

  THeaderSizingEvent = procedure(sender: TObject; const IsColumn: boolean;
                                    const aIndex, aSize: Integer) of object;

  TCellProcessEvent = procedure(Sender: TObject; aCol, aRow: Integer;
                                processType: TCellProcessType;
                                var aValue: string) of object;

  TGetCellHintEvent = procedure (Sender: TObject; ACol, ARow: Integer;
                                 var HintText: String) of object;

  TSaveColumnEvent = procedure (Sender, aColumn: TObject; aColIndex: Integer;
                                aCfg: TXMLConfig; const aVersion: integer;
                                const aPath: string) of object;

  { TVirtualGrid }

  TVirtualGrid=class
    private
      FColCount: Integer;
      FRowCount: Integer;
      FCellArr, FColArr, FRowArr: TPointerPointerArray;
      function  GetCells(Col, Row: Integer): PCellProps;
      function  GetRows(Row: Integer): PColRowProps;
      function  GetCols(Col: Integer): PColRowProps;
      procedure SetCells(Col, Row: Integer; const AValue: PCellProps);
      procedure SetRows(Row: Integer; const Avalue: PColRowProps);
      procedure SetColCount(const Avalue: Integer);
      procedure SetRowCount(const Avalue: Integer);
      procedure SetCols(Col: Integer; const Avalue: PColRowProps);
    protected
      procedure doDestroyItem(Sender: TObject; Col,Row: Integer; var Item: Pointer);
      procedure doNewItem(Sender: TObject; Col,Row: Integer; var Item: Pointer);
      procedure DeleteColRow(IsColumn: Boolean; index: Integer);
      procedure MoveColRow(IsColumn: Boolean; FromIndex, ToIndex: Integer);
      procedure ExchangeColRow(IsColumn: Boolean; index, WithIndex: Integer);
      procedure InsertColRow(IsColumn: Boolean; Index: Integer);
      procedure DisposeCell(var P: PCellProps); virtual;
      procedure DisposeColRow(var p: PColRowProps); virtual;
      function  IsColumnIndexValid(AIndex: Integer): boolean; inline;
      function  IsRowIndexValid(AIndex: Integer): boolean; inline;
    public
      constructor Create;
      destructor Destroy; override;
      procedure Clear;
      function GetDefaultCell: PcellProps;
      function GetDefaultColRow: PColRowProps;

      property ColCount: Integer read FColCount write SetColCount;
      property RowCount: Integer read FRowCount write SetRowCount;

      property Celda[Col,Row: Integer]: PCellProps read GetCells write SetCells;
      property Cols[Col: Integer]: PColRowProps read GetCols write SetCols;
      property Rows[Row: Integer]: PColRowProps read GetRows write SetRows;
  end;

  { TGridColumnTitle }

  TGridColumnTitle = class(TPersistent)
  private
    FColumn: TGridColumn;
    FCaption: PChar;
    FColor: ^TColor;
    FAlignment: ^TAlignment;
    FFont: TFont;
    FImageIndex: TImageIndex;
    FImageLayout: TButtonLayout;
    FIsDefaultTitleFont: boolean;
    FLayout: ^TTextLayout;
    FPrefixOption: TPrefixOption;
    FMultiline: Boolean;
    FIsDefaultCaption: boolean;
    procedure FontChanged(Sender: TObject);
    function GetAlignment: TAlignment;
    function GetColor: TColor;
    function GetFont: TFont;
    function GetLayout: TTextLayout;
    function IsAlignmentStored: boolean;
    function IsCaptionStored: boolean;
    function IsColorStored: boolean;
    function IsFontStored: boolean;
    function IsLayoutStored: boolean;
    procedure SetAlignment(const AValue: TAlignment);
    procedure SetColor(const AValue: TColor);
    procedure SetFont(const AValue: TFont);
    procedure SetImageIndex(const AValue: TImageIndex);
    procedure SetImageLayout(const AValue: TButtonLayout);
    procedure SetLayout(const AValue: TTextLayout);
    procedure SetMultiLine(const AValue: Boolean);
    procedure SetPrefixOption(const AValue: TPrefixOption);
    procedure WriteCaption(Writer: TWriter);

    property IsDefaultFont: boolean read FIsDefaultTitleFont;
  protected
    function  GetDefaultCaption: string; virtual;
    function  GetDefaultAlignment: TAlignment;
    function  GetDefaultColor: TColor;
    function  GetDefaultLayout: TTextLayout;
    function  GetOwner: TPersistent; override;
    function  GetCaption: TCaption;
    procedure SetCaption(const AValue: TCaption); virtual;
    procedure DefineProperties(Filer: TFiler); override;
  public
    constructor Create(TheColumn: TGridColumn); virtual;
    destructor Destroy; override;
    procedure Assign(Source: TPersistent); override;
    procedure FillTitleDefaultFont;
    procedure FixDesignFontsPPI(const ADesignTimePPI: Integer); virtual;
    procedure ScaleFontsPPI(const AToPPI: Integer; const AProportion: Double); virtual;
    function IsDefault: boolean;
    property Column: TGridColumn read FColumn;
  published
    property Alignment: TAlignment read GetAlignment write SetAlignment stored IsAlignmentStored;
    property Caption: TCaption read GetCaption write SetCaption stored IsCaptionStored;
    property Color: TColor read GetColor write SetColor stored IsColorStored;
    property Font: TFont read GetFont write SetFont stored IsFontStored;
    property ImageIndex: TImageIndex read FImageIndex write SetImageIndex default -1;
    property ImageLayout: TButtonLayout read FImageLayout write SetImageLayout default blGlyphRight;
    property Layout: TTextLayout read GetLayout write SetLayout stored IsLayoutStored;
    property MultiLine: Boolean read FMultiLine write SetMultiLine default false;
    property PrefixOption: TPrefixOption read FPrefixOption write SetPrefixOption default poNone;
  end;

  { TGridColumn }

  TGridColumn = class(TCollectionItem)
  private
    FButtonStyle: TColumnButtonStyle;
    FDropDownRows: Longint;
    FTitle: TGridColumnTitle;
    FWidthChanged: boolean;
    FAlignment: ^TAlignment;
    FColor: ^TColor;
    FLayout: ^TTextLayout;
    FVisible: ^Boolean;
    FReadOnly: ^Boolean;
    FWidth: ^Integer;
    FFont: TFont;
    FisDefaultFont: Boolean;
    FPickList: TStrings;
    FMinSize, FMaxSize, FSizePriority: ^Integer;
    FValueChecked,FValueUnchecked: PChar;
    FTag: PtrInt;
    procedure FontChanged(Sender: TObject);
    function GetAlignment: TAlignment;
    function GetColor: TColor;
    function GetExpanded: Boolean;
    function GetFont: TFont;
    function GetGrid: TCustomGrid;
    function GetLayout: TTextLayout;
    function GetMaxSize: Integer;
    function GetMinSize: Integer;
    function GetSizePriority: Integer;
    function GetReadOnly: Boolean;
    function GetStoredWidth: Integer;
    function GetVisible: Boolean;
    function GetWidth: Integer;
    function IsAlignmentStored: boolean;
    function IsColorStored: boolean;
    function IsFontStored: boolean;
    function IsLayoutStored: boolean;
    function IsMinSizeStored: boolean;
    function IsMaxSizeStored: boolean;
    function IsReadOnlyStored: boolean;
    function IsSizePriorityStored: boolean;
    function IsValueCheckedStored: boolean;
    function IsValueUncheckedStored: boolean;
    function IsVisibleStored: boolean;
    function IsWidthStored: boolean;
    procedure SetAlignment(const AValue: TAlignment);
    procedure SetButtonStyle(const AValue: TColumnButtonStyle);
    procedure SetColor(const AValue: TColor);
    procedure SetExpanded(const AValue: Boolean);
    procedure SetFont(const AValue: TFont);
    procedure SetLayout(const AValue: TTextLayout);
    procedure SetMaxSize(const AValue: Integer);
    procedure SetMinSize(const Avalue: Integer);
    procedure SetPickList(const AValue: TStrings);
    procedure SetReadOnly(const AValue: Boolean);
    procedure SetSizePriority(const AValue: Integer);
    procedure SetTitle(const AValue: TGridColumnTitle);
    procedure SetValueChecked(const AValue: string);
    procedure SetValueUnchecked(const AValue: string);
    procedure SetVisible(const AValue: Boolean);
    procedure SetWidth(const AValue: Integer);
  protected
    function  GetDisplayName: string; override;
    function  GetDefaultAlignment: TAlignment; virtual;
    function  GetDefaultColor: TColor; virtual;
    function  GetDefaultLayout: TTextLayout; virtual;
    function  GetDefaultMaxSize: Integer; virtual;
    function  GetDefaultMinSize: Integer; virtual;
    function  GetDefaultReadOnly: boolean; virtual;
    function  GetDefaultSizePriority: Integer;
    function  GetDefaultVisible: boolean; virtual;
    function  GetDefaultValueChecked: string; virtual;
    function  GetDefaultValueUnchecked: string; virtual;
    function  GetDefaultWidth: Integer; virtual;
    function  GetPickList: TStrings; virtual;
    function  GetValueChecked: string;
    function  GetValueUnchecked: string;
    procedure ColumnChanged; virtual;
    procedure AllColumnsChange;
    function  CreateTitle: TGridColumnTitle; virtual;
    procedure SetIndex(Value: Integer); override;

    property  IsDefaultFont: boolean read FIsDefaultFont;
  public
    constructor Create(ACollection: TCollection); override;
    destructor Destroy; override;
    procedure Assign(Source: TPersistent); override;
    procedure FillDefaultFont;
    procedure FixDesignFontsPPI(const ADesignTimePPI: Integer); virtual;
    procedure ScaleFontsPPI(const AToPPI: Integer; const AProportion: Double); virtual;
    function  IsDefault: boolean; virtual;
    property Grid: TCustomGrid read GetGrid;
    property DefaultWidth: Integer read GetDefaultWidth;
    property StoredWidth: Integer read GetStoredWidth;
    property WidthChanged: boolean read FWidthChanged;

  published
    property Alignment: TAlignment read GetAlignment write SetAlignment stored IsAlignmentStored;
    property ButtonStyle: TColumnButtonStyle read FButtonStyle write SetButtonStyle default cbsAuto;
    property Color: TColor read GetColor write SetColor stored IsColorStored;
    property DropDownRows: Longint read FDropDownRows write FDropDownRows default 7;
    property Expanded: Boolean read GetExpanded write SetExpanded default True;
    property Font: TFont read GetFont write SetFont stored IsFontStored;
    property Layout: TTextLayout read GetLayout write SetLayout stored IsLayoutStored;
    property MinSize: Integer read GetMinSize write SetMinSize stored IsMinSizeStored;
    property MaxSize: Integer read GetMaxSize write SetMaxSize stored isMaxSizeStored;
    property PickList: TStrings read GetPickList write SetPickList;
    property ReadOnly: Boolean read GetReadOnly write SetReadOnly stored IsReadOnlyStored;
    property SizePriority: Integer read GetSizePriority write SetSizePriority stored IsSizePriorityStored;
    property Tag: PtrInt read FTag write FTag default 0;
    property Title: TGridColumnTitle read FTitle write SetTitle;
    property Width: Integer read GetWidth write SetWidth stored IsWidthStored;
    property Visible: Boolean read GetVisible write SetVisible stored IsVisibleStored;
    property ValueChecked: string read GetValueChecked write SetValueChecked
      stored IsValueCheckedStored;
    property ValueUnchecked: string read GetValueUnchecked write SetValueUnchecked
      stored IsValueUncheckedStored;
  end;

  TGridPropertyBackup=record
    ValidData: boolean;
    FixedRowCount: Integer;
    FixedColCount: Integer;
    RowCount: Integer;
    ColCount: Integer;
  end;

  { TGridColumns }

  TGridColumns = class(TCollection)
  private
    FGrid: TCustomGrid;
    function GetColumn(Index: Integer): TGridColumn;
    function GetEnabled: Boolean;
    procedure SetColumn(Index: Integer; Value: TGridColumn);
    function GetVisibleCount: Integer;
  protected
    function GetOwner: TPersistent; override;
    procedure Update(Item: TCollectionItem); override;
    procedure TitleFontChanged;
    procedure FontChanged;
    procedure RemoveColumn(Index: Integer);
    procedure MoveColumn(FromIndex,ToIndex: Integer); virtual;
    procedure ExchangeColumn(Index,WithIndex: Integer);
    procedure InsertColumn(Index: Integer);
  public
    constructor Create(AGrid: TCustomGrid; aItemClass: TCollectionItemClass);
    function Add: TGridColumn;
    procedure Clear;
    function ColumnByTitle(const aTitle: string): TGridColumn;
    function RealIndex(Index: Integer): Integer;
    function IndexOf(Column: TGridColumn): Integer;
    function IsDefault: boolean;
    function HasIndex(Index: Integer): boolean;
    function VisibleIndex(Index: Integer): Integer;
    property Grid: TCustomGrid read FGrid;
    property Items[Index: Integer]: TGridColumn read GetColumn write SetColumn; default;
    property VisibleCount: Integer read GetVisibleCount;
    property Enabled: Boolean read GetEnabled;
  end;

  type
    TGridCoord = TPoint;
    TGridRect  = TRect;
    TGridRectArray = array of TGridRect;

    TSizingRec = record
      Index: Integer;
      OffIni,OffEnd: Integer;
      DeltaOff: Integer;
      PrevLine: boolean;
      PrevOffset: Integer;
    end;

    TGridDataCache=record
      FixedWidth: Integer;        // Sum( Fixed ColsWidths[i] )
      FixedHeight: Integer;       // Sum( Fixed RowsHeights[i] )
      GridWidth: Integer;         // Sum( ColWidths[i] )
      GridHeight: Integer;        // Sum( RowHeights[i] )
      ClientWidth: Integer;       // Width-VertScrollbar.Size
      ClientHeight: Integer;      // Height-HorzScrollbar.Size
      ClientRect: TRect;          // Cache for ClientRect - GetBorderWidth need for Bidi
      ScrollWidth: Integer;       // ClientWidth-FixedWidth
      ScrollHeight: Integer;      // ClientHeight-FixedHeight
      HScrollBarNetRange: Integer;//ScrollBar Range-Page
      VisibleGrid: TRect;         // Visible non fixed rectangle of cellcoordinates
      MaxClientXY: Tpoint;        // VisibleGrid.BottomRight (pixel) coordinates
      ValidRows: boolean;         // true if there are not fixed columns to show
      ValidCols: boolean;         // true if there are not fixed rows to show
      ValidGrid: boolean;         // true if there are not fixed cells to show
      AccumWidth: TIntegerList;   // Accumulated width per column
      AccumHeight: TIntegerList;  // Accumulated Height per row
      TLColOff,TLRowOff: Integer; // TopLeft Offset in pixels
      MaxTopLeft: TPoint;         // Max Top left ( cell coorditates)
      MaxTLOffset: TPoint;        // Max Top left offset of the last cell
      HotCell: TPoint;            // currently hot cell
      HotCellPainted: boolean;    // HotCell was already painter?
      HotGridZone: TGridZone;     // GridZone of last MouseMove
      ClickCell: TPoint;          // Cell coords of the latest mouse click
      ClickMouse: TPoint;         // mouse coords of the latest mouse click
      PushedCell: TPoint;         // Cell coords of cell being pushed
      PushedMouse: TPoint;        // mouse Coords of the cell being pushed
      ClickCellPushed: boolean;   // Header Cell is currently pushed?
      FullVisibleGrid: TRect;     // visible cells excluding partially visible cells
      MouseCell: TPoint;          // Cell which contains the mouse
      OldMaxTopLeft: TPoint;      // previous MaxTopleft (before col sizing)
    end;

    TGridCursorState = (gcsDefault, gcsColWidthChanging, gcsRowHeightChanging, gcsDragging);

type

  { TCustomGrid }

  TCustomGrid=class(TCustomControl)
  private
    FAlternateColor: TColor;
    FAutoAdvance: TAutoAdvance;
    FAutoEdit: boolean;
    FAutoFillColumns: boolean;
    FBorderColor: TColor;
    FDefaultDrawing: Boolean;
    FEditor: TWinControl;
    FEditorHidingCount: Integer;
    FEditorMode: Boolean;
    FEditorOldValue: string;
    FEditorShowing: Boolean;
    FEditorKey: Boolean;
    FEditorOptions: Integer;
    FExtendedSelect: boolean;
    FFastEditing: boolean;
    FAltColorStartNormal: boolean;
    FFlat: Boolean;
    FOnAfterSelection: TOnSelectEvent;
    FOnLoadColumn: TSaveColumnEvent;
    FOnSaveColumn: TSaveColumnEvent;
    FRangeSelectMode: TRangeSelectMode;
    FSelections: TGridRectArray;
    FOnUserCheckboxBitmap: TUserCheckboxBitmapEvent;
    FOnUserCheckboxImage: TUserCheckBoxImageEvent;
    FSortOrder: TSortOrder;
    FSortColumn: Integer;
    FSortLCLImages: TLCLGlyphs;
    FTabAdvance: TAutoAdvance;
    FTitleImageList: TImageList;
    FTitleImageListWidth: Integer;
    FTitleStyle: TTitleStyle;
    FAscImgInd: TImageIndex;
    FDescImgInd: TImageIndex;
    FOnCompareCells: TOnCompareCells;
    FGridLineStyle: TPenStyle;
    FGridLineWidth: Integer;
    FDefColWidth, FDefRowHeight: Integer;
    FRealizedDefColWidth, FRealizedDefRowHeight: Integer;
    FCol,FRow, FFixedCols, FFixedRows: Integer;
    FOnEditButtonClick: TNotifyEvent;
    FOnButtonClick: TOnSelectEvent;
    FOnPickListSelect: TNotifyEvent;
    FOnCheckboxToggled: TToggledCheckboxEvent;
    FOnPrepareCanvas: TOnPrepareCanvasEvent;
    FOnSelectEditor: TSelectEditorEvent;
    FOnValidateEntry: TValidateEntryEvent;
    FGridLineColor, FFixedGridLineColor: TColor;
    FFixedColor, FFixedHotColor, FFocusColor, FSelectedColor: TColor;
    FDisabledFontColor: TColor;
    FFocusRectVisible: boolean;
    FCols,FRows: TIntegerList;
    FsaveOptions: TSaveOptions;
    FScrollBars: TScrollStyle;
    FSelectActive: Boolean;
    FTopLeft: TPoint;
    FPivot: TPoint;
    FRange: TRect;
    FDragDx: Integer;
    FMoveLast: TPoint;
    FUpdateCount: Integer;
    FGCache: TGridDataCache;
    FOptions: TGridOptions;
    FOptions2: TGridOptions2;
    FOnDrawCell: TOnDrawcell;
    FOnBeforeSelection: TOnSelectEvent;
    FOnSelection: TOnSelectEvent;
    FOnTopLeftChanged: TNotifyEvent;
    FUseXORFeatures: boolean;
    FValidateOnSetSelection: boolean;
    FVSbVisible, FHSbVisible: ShortInt; // state: -1 not initialized, 0 hidden, 1 visible
    FDefaultTextStyle: TTextStyle;
    FLastWidth: Integer;
    FTitleFont, FLastFont: TFont;
    FTitleFontIsDefault: boolean;
    FColumns: TGridColumns;
    FButtonEditor: TButtonCellEditor;
    FStringEditor: TStringCellEditor;
    FButtonStringEditor: TCompositeCellEditor;
    FPickListEditor: TPickListCellEditor;
    FExtendedColSizing: boolean;
    FExtendedRowSizing: boolean;
    FUpdatingAutoFillCols: boolean;
    FGridBorderStyle: TBorderStyle;
    FGridFlags: TGridFlags;
    FGridPropBackup: TGridPropertyBackup;
    FStrictSort: boolean;
    FIgnoreClick: boolean;
    FAllowOutboundEvents: boolean;
    FColumnClickSorts: boolean;
    FHeaderHotZones: TGridZoneSet;
    FHeaderPushZones: TGridZoneSet;
    FCursorChangeLock: Integer;
    FCursorState: TGridCursorState;
    FColRowDragIndicatorColor: TColor;
    FSavedCursor: TCursor;
    FSpecialCursors: array[gcsColWidthChanging..gcsDragging] of TCursor;
    FSizing: TSizingRec;
    FRowAutoInserted: Boolean;
    FMouseWheelOption: TMouseWheelOption;
    FSavedHint: String;
    FCellHintPriority: TCellHintPriority;
    FOnGetCellHint: TGetCellHintEvent;
    procedure AdjustCount(IsColumn:Boolean; OldValue, NewValue:Integer);
    procedure CacheVisibleGrid;
    procedure CancelSelection;
    procedure CheckFixedCount(aCol,aRow,aFCol,aFRow: Integer);
    procedure CheckCount(aNewColCount, aNewRowCount: Integer; FixEditor: boolean=true);
    procedure CheckIndex(IsColumn: Boolean; Index: Integer);
    function  CheckTopLeft(aCol,aRow: Integer; CheckCols,CheckRows: boolean): boolean;
    function  GetQuickColRow: TPoint;
    procedure SetQuickColRow(AValue: TPoint);
    function  IsCellButtonColumn(ACell: TPoint): boolean;
    function  GetSelectedColumn: TGridColumn;
    procedure SetAlternateColor(const AValue: TColor);
    procedure SetAutoFillColumns(const AValue: boolean);
    procedure SetBorderColor(const AValue: TColor);
    procedure SetColumnClickSorts(const AValue: boolean);
    procedure SetColumns(const AValue: TGridColumns);
    procedure SetEditorOptions(const AValue: Integer);
    procedure SetEditorBorderStyle(const AValue: TBorderStyle);
    procedure SetAltColorStartNormal(const AValue: boolean);
    procedure SetFlat(const AValue: Boolean);
    procedure SetFocusRectVisible(const AValue: Boolean);
    procedure SetTitleImageList(const AValue: TImageList);
    procedure SetTitleImageListWidth(const aTitleImageListWidth: Integer);
    procedure SetTitleFont(const AValue: TFont);
    procedure SetTitleStyle(const AValue: TTitleStyle);
    procedure SetUseXorFeatures(const AValue: boolean);
    function  doColSizing(X,Y: Integer): Boolean;
    function  doRowSizing(X,Y: Integer): Boolean;
    procedure doColMoving(X,Y: Integer);
    procedure doPushCell;
    procedure doRowMoving(X,Y: Integer);
    procedure doTopleftChange(DimChg: Boolean);
    procedure DrawXORVertLine(X: Integer);
    procedure DrawXORHorzLine(Y: Integer);
    function  EditorGetValue(validate:boolean=false): boolean;
    procedure EditorPos;
    procedure EditorShowChar(Ch: TUTF8Char);
    procedure EditorSetMode(const AValue: Boolean);
    procedure EditorSetValue;
    function  EditorAlwaysShown: Boolean;
    procedure FixPosition(IsColumn: Boolean; aIndex: Integer);
    procedure FixScroll;
    function  GetLeftCol: Integer;
    function  GetColCount: Integer;
    function  GetColWidths(Acol: Integer): Integer;
    function  GetColumns: TGridColumns;
    function GetDefColWidth: Integer;
    function GetDefRowHeight: Integer;
    function  GetEditorBorderStyle: TBorderStyle;
    function  GetBorderWidth: Integer;
    procedure GetTitleImageInfo(aColumnIndex:Integer; out ImgIndex: Integer; out ImgLayout: TButtonLayout);
    procedure GetSortTitleImageInfo(aColumnIndex:Integer; out ImgList: TCustomImageList;
      out ImgIndex, ImgListWidth: Integer; out NativeSortGlyphs: Boolean);
    function  GetRowCount: Integer;
    function  GetRowHeights(Arow: Integer): Integer;
    function  GetSelectedRange(AIndex: Integer): TGridRect;
    function  GetSelectedRangeCount: Integer;
    function  GetSelection: TGridRect;
    function  GetSpecialCursor(ACursorState: TGridCursorState): TCursor;
    function  GetTopRow: Longint;
    function  GetVisibleColCount: Integer;
    function  GetVisibleGrid: TRect;
    function  GetVisibleRowCount: Integer;
    procedure HeadersMouseMove(const X,Y:Integer);
    procedure InternalAutoFillColumns;
    function  InternalNeedBorder: boolean;
    procedure InternalSetColWidths(aCol,aValue: Integer);
    procedure InternalUpdateColumnWidths;
    procedure InvalidateMovement(DCol,DRow: Integer; OldRange: TRect);
    function  IsAltColorStored: boolean;
    function  IsColumnsStored: boolean;
    function  IsPushCellActive: boolean;
    procedure LoadColumns(cfg: TXMLConfig; Version: integer);
    function  LoadResBitmapImage(const ResName: string): TBitmap;
    procedure LoadSub(ACfg: TXMLConfig);
    procedure OnTitleFontChanged(Sender: TObject);
    procedure ReadColumns(Reader: TReader);
    procedure ReadColWidths(Reader: TReader);
    procedure ReadRowHeights(Reader: TReader);
    procedure ResetHotCell;
    procedure ResetPushedCell(ResetColRow: boolean=True);
    procedure RestoreCursor;
    procedure SaveColumns(cfg: TXMLConfig; Version: integer);
    function  ScrollToCell(const aCol,aRow: Integer; const ForceFullyVisible: Boolean = True): Boolean;
    function  ScrollGrid(Relative:Boolean; DCol,DRow: Integer): TPoint;
    procedure SetCol(AValue: Integer);
    procedure SetColWidths(Acol: Integer; Avalue: Integer);
    procedure SetColRowDragIndicatorColor(const AValue: TColor);
    procedure SetDefColWidth(AValue: Integer);
    procedure SetDefRowHeight(AValue: Integer);
    procedure SetDefaultDrawing(const AValue: Boolean);
    procedure SetEditor(AValue: TWinControl);
    procedure SetFocusColor(const AValue: TColor);
    procedure SetGridLineColor(const AValue: TColor);
    procedure SetFixedGridLineColor(const AValue: TColor);
    procedure SetGridLineStyle(const AValue: TPenStyle);
    procedure SetGridLineWidth(const AValue: Integer);
    procedure SetLeftCol(const AValue: Integer);
    procedure SetOptions(const AValue: TGridOptions);
    procedure SetOptions2(const AValue: TGridOptions2);
    procedure SetRangeSelectMode(const AValue: TRangeSelectMode);
    procedure SetRow(AValue: Integer);
    procedure SetRowCount(AValue: Integer);
    procedure SetRowHeights(Arow: Integer; Avalue: Integer);
    procedure SetScrollBars(const AValue: TScrollStyle);
    procedure SetSelectActive(const AValue: Boolean);
    procedure SetSelection(const AValue: TGridRect);
    procedure SetSpecialCursor(ACursorState: TGridCursorState; const AValue: TCursor);
    procedure SetTopRow(const AValue: Integer);
    function  StartColSizing(const X, Y: Integer): boolean;
    procedure ChangeCursor(ACursor: TCursor; ASaveCurrentCursor: Boolean = true);
    function TitleFontIsStored: Boolean;
    function  TrySmoothScrollBy(aColDelta, aRowDelta: Integer): Boolean;
    procedure TryScrollTo(aCol,aRow: Integer; ClearColOff, ClearRowOff: Boolean);
    procedure UpdateCachedSizes;
    procedure UpdateSBVisibility;
    procedure UpdateSizes;
    procedure WriteColumns(Writer: TWriter);
    procedure WriteColWidths(Writer: TWriter);
    procedure WriteRowHeights(Writer: TWriter);
    procedure WMEraseBkgnd(var message: TLMEraseBkgnd); message LM_ERASEBKGND;
    procedure WMGetDlgCode(var Msg: TLMNoParams); message LM_GETDLGCODE;
  protected
    fGridState: TGridState;
    function RTLSign: Integer;
    class procedure WSRegisterClass; override;
    procedure AddSelectedRange;
    procedure AdjustClientRect(var ARect: TRect); override;
    procedure AdjustEditorBounds(NewCol,NewRow:Integer); virtual;
    procedure AfterMoveSelection(const prevCol,prevRow: Integer); virtual;
    procedure AssignTo(Dest: TPersistent); override;
    procedure AutoAdjustColumn(aCol: Integer); virtual;
    procedure BeforeMoveSelection(const DCol,DRow: Integer); virtual;
    procedure BeginAutoDrag; override;
    function  BoxRect(ALeft,ATop,ARight,ABottom: Longint): TRect;
    procedure CacheMouseDown(const X,Y:Integer);
    procedure CalcAutoSizeColumn(const Index: Integer; var AMin,AMax,APriority: Integer); virtual;
    procedure CalcCellExtent(acol, aRow: Integer; var aRect: TRect); overload; virtual; deprecated 'old function';
    procedure CalcFocusRect(var ARect: TRect; adjust: boolean = true);
    procedure CalcMaxTopLeft;
    procedure CalcScrollbarsRange;
    procedure CalculatePreferredSize(var PreferredWidth,
      PreferredHeight: integer; WithThemeSpace: Boolean); override;
    function  CanEditShow: Boolean; virtual;
    function  CanGridAcceptKey(Key: Word; Shift: TShiftState): Boolean; virtual;
    procedure CellClick(const aCol,aRow: Integer; const Button:TMouseButton); virtual;
    procedure CellExtent(const aCol,aRow: Integer; var R: TRect; out exCol:Integer);
    procedure CheckLimits(var aCol,aRow: Integer);
    procedure CheckLimitsWithError(const aCol, aRow: Integer);
    procedure CMBiDiModeChanged(var Message: TLMessage); message CM_BIDIMODECHANGED;
    procedure CMMouseEnter(var Message: TLMessage); message CM_MOUSEENTER;
    procedure CMMouseLeave(var Message :TLMessage); message CM_MouseLeave;
    procedure ColRowDeleted(IsColumn: Boolean; index: Integer); virtual;
    procedure ColRowExchanged(IsColumn: Boolean; index,WithIndex: Integer); virtual;
    procedure ColRowInserted(IsColumn: boolean; index: integer); virtual;
    procedure ColRowMoved(IsColumn: Boolean; FromIndex,ToIndex: Integer); virtual;
    function  ColRowToOffset(IsCol, Relative: Boolean; Index:Integer;
                             out StartPos, EndPos: Integer): Boolean;
    function  ColumnIndexFromGridColumn(Column: Integer): Integer;
    function  ColumnFromGridColumn(Column: Integer): TGridColumn;
    procedure ColumnsChanged(aColumn: TGridColumn);
    procedure ColWidthsChanged; virtual;
    function  CreateColumns: TGridColumns; virtual;
    procedure CheckNewCachedSizes(var AGCache:TGridDataCache); virtual;
    procedure CreateWnd; override;
    procedure CreateParams(var Params: TCreateParams); override;
    procedure Click; override;
    procedure DblClick; override;
    function  DefaultColWidthIsStored: Boolean;
    function  DefaultRowHeightIsStored: Boolean;
    procedure DefineProperties(Filer: TFiler); override;
    procedure DestroyHandle; override;
    function  DialogChar(var Message: TLMKey): boolean; override;
    function  DoCompareCells(Acol,ARow,Bcol,BRow: Integer): Integer; virtual;
    procedure DoCopyToClipboard; virtual;
    procedure DoCutToClipboard; virtual;
    procedure DoEditButtonClick(const ACol,ARow: Integer); virtual;
    procedure DoEditorHide; virtual;
    procedure DoEditorShow; virtual;
    procedure DoExit; override;
    procedure DoEnter; override;
    procedure DoLoadColumn(sender: TCustomGrid; aColumn: TGridColumn; aColIndex: Integer;
                            aCfg: TXMLConfig; aVersion: Integer; aPath: string); virtual;
    procedure DoSaveColumn(sender: TCustomGrid; aColumn: TGridColumn; aColIndex: Integer;
                            aCfg: TXMLConfig; aVersion: Integer; aPath: string); virtual;
    function  DoMouseWheel(Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint): Boolean; override;
    function  DoMouseWheelDown(Shift: TShiftState; MousePos: TPoint): Boolean; override;
    function  DoMouseWheelUp(Shift: TShiftState; MousePos: TPoint): Boolean; override;
    function  DoMouseWheelLeft(Shift: TShiftState; MousePos: TPoint): Boolean; override;
    function  DoMouseWheelRight(Shift: TShiftState; MousePos: TPoint): Boolean; override;
    procedure DoAutoAdjustLayout(const AMode: TLayoutAdjustmentPolicy;
      const AXProportion, AYProportion: Double); override;
    procedure DoOnChangeBounds; override;
    procedure DoOPDeleteColRow(IsColumn: Boolean; index: Integer);
    procedure DoOPExchangeColRow(IsColumn: Boolean; index, WithIndex: Integer);
    procedure DoOPInsertColRow(IsColumn: boolean; index: integer);
    procedure DoOPMoveColRow(IsColumn: Boolean; FromIndex, ToIndex: Integer);
    procedure DoPasteFromClipboard; virtual;
    procedure DoPrepareCanvas(aCol,aRow:Integer; aState: TGridDrawState); virtual;
    procedure DoOnResize; override;
    procedure DoSetBounds(ALeft, ATop, AWidth, AHeight: integer); override;
    function  DoUTF8KeyPress(var UTF8Key: TUTF8Char): boolean; override;
    procedure DrawBorder;
    procedure DrawAllRows; virtual;
    procedure DrawFillRect(aCanvas:TCanvas; R:TRect);// Use FillRect after calc the new rect depened on Right To Left
    procedure DrawCell(aCol,aRow:Integer; aRect:TRect; aState:TGridDrawState); virtual;
    procedure DrawCellGrid(aCol,aRow: Integer; aRect: TRect; aState: TGridDrawState); virtual;
    procedure DrawTextInCell(aCol,aRow: Integer; aRect: TRect; aState: TGridDrawState); virtual;
    procedure DrawThemedCell(aCol,aRow: Integer; aRect: TRect; aState: TGridDrawState);
    procedure DrawCellText(aCol,aRow: Integer; aRect: TRect; aState: TGridDrawState; aText: String); virtual;
    procedure DrawGridCheckboxBitmaps(const aCol,aRow: Integer; const aRect: TRect;
                                        const aState: TCheckboxState); virtual;
    procedure DrawButtonCell(const aCol,aRow: Integer; aRect: TRect; const aState:TGridDrawState);
    procedure DrawColRowMoving;
    procedure DrawColumnText(aCol,aRow: Integer; aRect: TRect; aState:TGridDrawState); virtual;
    procedure DrawColumnTitleImage(var ARect: TRect; AColumnIndex: Integer);
    procedure DrawEdges;
    procedure DrawFocusRect(aCol,aRow:Integer; ARect:TRect); virtual;
    procedure DrawRow(aRow: Integer); virtual;
    procedure EditButtonClicked(Sender: TObject);
    procedure EditordoGetValue; virtual;
    procedure EditordoResetValue; virtual;
    procedure EditordoSetValue; virtual;
    function  EditorCanAcceptKey(const ch: TUTF8Char): boolean; virtual;
    function  EditorIsReadOnly: boolean; virtual;
    procedure EditorHide; virtual;
    function  EditorLocked: boolean;
    Function  EditingAllowed(ACol : Integer = -1) : Boolean; virtual; // Returns true if grid and current column allow editing
    procedure EditorSelectAll;
    procedure EditorShow(const SelAll: boolean); virtual;
    procedure EditorShowInCell(const aCol,aRow:Integer); virtual;
    procedure EditorWidthChanged(aCol,aWidth: Integer); virtual;
    function  FirstGridColumn: integer; virtual;
    function  FixedGrid: boolean;
    procedure FontChanged(Sender: TObject); override;
    procedure GetAutoFillColumnInfo(const Index: Integer; var aMin,aMax,aPriority: Integer); virtual;
    function  GetCellHintText(ACol, ARow: Integer): string; virtual;
    function  GetCells(ACol, ARow: Integer): string; virtual;
    function  GetColumnAlignment(Column: Integer; ForTitle: Boolean): TAlignment;
    function  GetColumnColor(Column: Integer; ForTitle: Boolean): TColor;
    function  GetColumnFont(Column: Integer; ForTitle: Boolean): TFont;
    function  GetColumnLayout(Column: Integer; ForTitle: boolean): TTextLayout;
    function  GetColumnReadonly(Column: Integer): boolean;
    function  GetColumnTitle(Column: Integer): string;
    function  GetColumnWidth(Column: Integer): Integer;
    function  GetDeltaMoveNext(const Inverse: boolean; var ACol,ARow: Integer; const AAutoAdvance: TAutoAdvance): boolean; virtual;
    function  GetDefaultColumnAlignment(Column: Integer): TAlignment; virtual;
    function  GetDefaultColumnWidth(Column: Integer): Integer; virtual;
    function  GetDefaultColumnLayout(Column: Integer): TTextLayout; virtual;
    function  GetDefaultColumnReadOnly(Column: Integer): boolean; virtual;
    function  GetDefaultColumnTitle(Column: Integer): string; virtual;
    function  GetDefaultEditor(Column: Integer): TWinControl; virtual;
    function  GetDefaultRowHeight: integer; virtual;
    function  GetGridDrawState(ACol, ARow: Integer): TGridDrawState;
    procedure GetImageForCheckBox(const aCol,aRow: Integer;
      CheckBoxView: TCheckBoxState; var ImageList: TCustomImageList;
      var ImageIndex: TImageIndex; var Bitmap: TBitmap); virtual;
    function  GetScrollBarPosition(Which: integer): Integer;
    function  GetSmoothScroll(Which: Integer): Boolean; virtual;
    procedure GetSBVisibility(out HsbVisible,VsbVisible:boolean);virtual;
    procedure GetSBRanges(const HsbVisible,VsbVisible: boolean;
                  out HsbRange,VsbRange,HsbPage,VsbPage,HsbPos,VsbPos:Integer); virtual;
    procedure GetSelectedState(AState: TGridDrawState; out IsSelected:boolean); virtual;
    function  GetEditMask(ACol, ARow: Longint): string; virtual;
    function  GetEditText(ACol, ARow: Longint): string; virtual;
    function  GetFixedcolor: TColor; virtual;
    function  GetFirstVisibleColumn: Integer;
    function  GetFirstVisibleRow: Integer;
    function  GetLastVisibleColumn: Integer;
    function  GetLastVisibleRow: Integer;
    function  GetSelectedColor: TColor; virtual;
    function  GetTitleShowPrefix(Column: Integer): boolean;
    function  GetPxTopLeft: TPoint;
    function  GetTruncCellHintText(ACol, ARow: Integer): string; virtual;
    function  GridColumnFromColumnIndex(ColumnIndex: Integer): Integer;
    procedure GridMouseWheel(Shift: TShiftState; Delta: Integer); virtual;
    procedure HeaderClick(IsColumn: Boolean; index: Integer); virtual;
    procedure HeaderSized(IsColumn: Boolean; index: Integer); virtual;
    procedure HeaderSizing(const IsColumn:boolean; const AIndex,ASize:Integer); virtual;
    procedure HideCellHintWindow;
    procedure InternalSetColCount(ACount: Integer);
    procedure InvalidateCell(aCol, aRow: Integer; Redraw: Boolean); overload;
    procedure InvalidateFromCol(ACol: Integer);
    procedure InvalidateGrid;
    procedure InvalidateFocused;
    function  IsColumnIndexValid(AIndex: Integer): boolean;
    function  IsRowIndexValid(AIndex: Integer): boolean;
    function  IsColumnIndexVariable(AIndex: Integer): boolean;
    function  IsRowIndexVariable(AIndex: Integer): boolean;
    function  GetIsCellTitle(aCol,aRow: Integer): boolean; virtual;
    function  GetIsCellSelected(aCol, aRow: Integer): boolean; virtual;
    function  IsEmptyRow(ARow: Integer): Boolean;
    function  IsMouseOverCellButton(X,Y: Integer): boolean;
    procedure KeyDown(var Key : Word; Shift : TShiftState); override;
    procedure KeyUp(var Key : Word; Shift : TShiftState); override;
    procedure KeyPress(var Key: char); override;
    procedure LoadContent(cfg: TXMLConfig; Version: Integer); virtual;
    procedure LoadGridOptions(cfg: TXMLConfig; Version: Integer); virtual;
    procedure Loaded; override;
    procedure LockEditor;
    function  MouseButtonAllowed(Button: TMouseButton): boolean; virtual;
    procedure MouseDown(Button: TMouseButton; Shift:TShiftState; X,Y:Integer); override;
    procedure MouseMove(Shift: TShiftState; X,Y: Integer); override;
    procedure MouseUp(Button: TMouseButton; Shift:TShiftState; X,Y:Integer); override;
    function  MoveExtend(Relative: Boolean; DCol, DRow: Integer; ForceFullyVisible: Boolean = True): Boolean;
    function  MoveNextAuto(const Inverse: boolean): boolean;
    function  MoveNextSelectable(Relative:Boolean; DCol, DRow: Integer): Boolean; virtual;
    procedure MoveSelection; virtual;
    function  OffsetToColRow(IsCol, Physical: Boolean; Offset: Integer;
                             out Index, Rest: Integer): Boolean;
    procedure Paint; override;
    procedure PickListItemSelected(Sender: TObject);
    procedure PrepareCanvas(aCol,aRow: Integer; aState:TGridDrawState); virtual;
    procedure PrepareCellHints(ACol, ARow: Integer); virtual;
    procedure ResetDefaultColWidths; virtual;
    procedure ResetEditor;
    procedure ResetLastMove;
    function  ResetOffset(chkCol, ChkRow: Boolean): Boolean;
    procedure ResetSizes; virtual;
    procedure ResizeColumn(aCol, aWidth: Integer);
    procedure ResizeRow(aRow, aHeight: Integer);
    procedure RowHeightsChanged; virtual;
    procedure SaveContent(cfg: TXMLConfig); virtual;
    procedure SaveGridOptions(cfg: TXMLConfig); virtual;
    procedure ScrollBarRange(Which:Integer; aRange,aPage,aPos: Integer);
    procedure ScrollBarPosition(Which, Value: integer);
    function  ScrollBarIsVisible(Which:Integer): Boolean;
    procedure ScrollBarPage(Which: Integer; aPage: Integer);
    procedure ScrollBarShow(Which: Integer; aValue: boolean);
    function  ScrollBarAutomatic(Which: TScrollStyle): boolean; virtual;
    procedure ScrollBy(DeltaX, DeltaY: Integer); override;
    procedure SelectEditor; virtual;
    function  SelectCell(ACol, ARow: Integer): Boolean; virtual;
    procedure SetCanvasFont(aFont: TFont);
    procedure SetColCount(AValue: Integer); virtual;
    procedure SetColor(Value: TColor); override;
    procedure SetColRow(const ACol,ARow: Integer; withEvents: boolean = false);
    procedure SetCursor(AValue: TCursor); override;
    procedure SetEditText(ACol, ARow: Longint; const Value: string); virtual;
    procedure SetBorderStyle(NewStyle: TBorderStyle); override;
    procedure SetFixedcolor(const AValue: TColor); virtual;
    procedure SetFixedCols(const AValue: Integer); virtual;
    procedure SetFixedRows(const AValue: Integer); virtual;
    procedure SetRawColWidths(ACol: Integer; AValue: Integer);
    procedure SetSelectedColor(const AValue: TColor); virtual;
    procedure ShowCellHintWindow(APoint: TPoint);
    procedure SizeChanged(OldColCount, OldRowCount: Integer); virtual;
    procedure Sort(ColSorting: Boolean; index,IndxFrom,IndxTo:Integer); virtual;
    procedure StartPushCell;
    procedure TopLeftChanged; virtual;
    function  TryMoveSelection(Relative: Boolean; var DCol, DRow: Integer): Boolean;
    procedure UnLockEditor;
    procedure UnprepareCellHints; virtual;
    procedure UpdateHorzScrollBar(const aVisible: boolean; const aRange,aPage,aPos: Integer); virtual;
    procedure UpdateSelectionRange;
    procedure UpdateVertScrollbar(const aVisible: boolean; const aRange,aPage,aPos: Integer); virtual;
    procedure UpdateBorderStyle;
    function  ValidateEntry(const ACol,ARow:Integer; const OldValue:string; var NewValue:string): boolean; virtual;
    procedure VisualChange; virtual;
    procedure WMSize(var Message: TLMSize); message LM_SIZE;
    procedure WMHScroll(var message : TLMHScroll); message LM_HSCROLL;
    procedure WMVScroll(var message : TLMVScroll); message LM_VSCROLL;
    procedure WMKillFocus(var message: TLMKillFocus); message LM_KILLFOCUS;
    procedure WMSetFocus(var message: TLMSetFocus); message LM_SETFOCUS;
    procedure WndProc(var TheMessage : TLMessage); override;

    property AllowOutboundEvents: boolean read FAllowOutboundEvents write FAllowOutboundEvents default true;
    property AlternateColor: TColor read FAlternateColor write SetAlternateColor stored IsAltColorStored;
    property AutoAdvance: TAutoAdvance read FAutoAdvance write FAutoAdvance default aaRight;
    property AutoEdit: boolean read FAutoEdit write FAutoEdit default true;
    property AutoFillColumns: boolean read FAutoFillColumns write SetAutoFillColumns default false;
    property BorderStyle:TBorderStyle read FGridBorderStyle write SetBorderStyle default bsSingle;
    property BorderColor: TColor read FBorderColor write SetBorderColor default cl3DDKShadow;
    property CellHintPriority: TCellHintPriority read FCellHintPriority write FCellHintPriority default chpAllNoDefault;
    property Col: Integer read FCol write SetCol;
    property ColCount: Integer read GetColCount write SetColCount default 5;
    property ColRow: TPoint read GetQuickColRow write SetQuickColRow;
    property ColRowDraggingCursor: TCursor index gcsDragging read GetSpecialCursor write SetSpecialCursor default crMultiDrag;
    property ColRowDragIndicatorColor: TColor read FColRowDragIndicatorColor write SetColRowDragIndicatorColor default clRed;
    property ColSizingCursor: TCursor index gcsColWidthChanging read GetSpecialCursor write SetSpecialCursor default crHSplit;
    property ColumnClickSorts: boolean read FColumnClickSorts write SetColumnClickSorts default false;
    property Columns: TGridColumns read GetColumns write SetColumns stored IsColumnsStored;
    property ColWidths[aCol: Integer]: Integer read GetColWidths write SetColWidths;
    property DefaultColWidth: Integer read GetDefColWidth write SetDefColWidth stored DefaultColWidthIsStored;
    property DefaultRowHeight: Integer read GetDefRowHeight write SetDefRowHeight stored DefaultRowHeightIsStored;
    property DefaultDrawing: Boolean read FDefaultDrawing write SetDefaultDrawing default True;
    property DefaultTextStyle: TTextStyle read FDefaultTextStyle write FDefaultTextStyle;
    property DisabledFontColor: TColor read FDisabledFontColor write FDisabledFontColor default clGrayText;
    property DragDx: Integer read FDragDx write FDragDx;
    property Editor: TWinControl read FEditor write SetEditor;
    property EditorBorderStyle: TBorderStyle read GetEditorBorderStyle write SetEditorBorderStyle;
    property EditorMode: Boolean read FEditorMode write EditorSetMode;
    property EditorKey: boolean read FEditorKey write FEditorKey;
    property EditorOptions: Integer read FEditorOptions write SetEditorOptions;
    property EditorShowing: boolean read FEditorShowing write FEditorShowing;
    property ExtendedColSizing: boolean read FExtendedColSizing write FExtendedColSizing;
    property ExtendedRowSizing: boolean read FExtendedRowSizing write FExtendedRowSizing;
    property ExtendedSelect: boolean read FExtendedSelect write FExtendedSelect default true;
    property FastEditing: boolean read FFastEditing write FFastEditing;
    property AltColorStartNormal: boolean read FAltColorStartNormal write SetAltColorStartNormal;
    property FixedCols: Integer read FFixedCols write SetFixedCols default 1;
    property FixedRows: Integer read FFixedRows write SetFixedRows default 1;
    property FixedColor: TColor read GetFixedColor write SetFixedcolor default clBtnFace;
    property FixedGridLineColor: TColor read FFixedGridLineColor write SetFixedGridLineColor default cl3DDKShadow;
    property FixedHotColor: TColor read FFixedHotColor write FFixedHotColor default cl3DLight;
    property Flat: Boolean read FFlat write SetFlat default false;
    property FocusColor: TColor read FFocusColor write SetFocusColor;
    property FocusRectVisible: Boolean read FFocusRectVisible write SetFocusRectVisible;
    property GCache: TGridDataCache read FGCAChe;
    property GridFlags: TGridFlags read FGridFlags write FGridFlags;
    property GridHeight: Integer read FGCache.GridHeight;
    property GridLineColor: TColor read FGridLineColor write SetGridLineColor default clSilver;
    property GridLineStyle: TPenStyle read FGridLineStyle write SetGridLineStyle;
    property GridLineWidth: Integer read FGridLineWidth write SetGridLineWidth default 1;
    property GridWidth: Integer read FGCache.GridWidth;
    property HeaderHotZones: TGridZoneSet read FHeaderHotZones write FHeaderHotZones default [gzFixedCols];
    property HeaderPushZones: TGridZoneSet read FHeaderPushZones write FHeaderPushZones default [gzFixedCols];
    property ImageIndexSortAsc: TImageIndex read FAscImgInd write FAscImgInd default -1;
    property ImageIndexSortDesc: TImageIndex read FDescImgInd write FDescImgInd default -1;
    property TabAdvance: TAutoAdvance read FTabAdvance write FTabAdvance default aaRightDown;
    property TitleImageList: TImageList read FTitleImageList write SetTitleImageList;
    property TitleImageListWidth: Integer read FTitleImageListWidth write SetTitleImageListWidth default 0;
    property InplaceEditor: TWinControl read FEditor;
    property IsCellSelected[aCol,aRow: Integer]: boolean read GetIsCellSelected;
    property LeftCol:Integer read GetLeftCol write SetLeftCol;
    property MouseWheelOption: TMouseWheelOption read FMouseWheelOption write FMouseWheelOption default mwCursor;
    property Options: TGridOptions read FOptions write SetOptions default DefaultGridOptions;
    property Options2: TGridOptions2 read FOptions2 write SetOptions2 default DefaultGridOptions2;
    property RangeSelectMode: TRangeSelectMode read FRangeSelectMode write SetRangeSelectMode default rsmSingle;
    property Row: Integer read FRow write SetRow;
    property RowCount: Integer read GetRowCount write SetRowCount default 5;
    property RowSizingCursor: TCursor index gcsRowHeightChanging read GetSpecialCursor write SetSpecialCursor default crVSplit;
    property RowHeights[aRow: Integer]: Integer read GetRowHeights write SetRowHeights;
    property SaveOptions: TSaveOptions read FsaveOptions write FSaveOptions;
    property SelectActive: Boolean read FSelectActive write SetSelectActive;
    property SelectedColor: TColor read GetSelectedColor write SetSelectedColor;
    property SelectedColumn: TGridColumn read GetSelectedColumn;
    property Selection: TGridRect read GetSelection write SetSelection;
    property ScrollBars: TScrollStyle read FScrollBars write SetScrollBars default ssAutoBoth;
    property StrictSort: boolean read FStrictSort write FStrictSort;
    property TitleFont: TFont read FTitleFont write SetTitleFont stored TitleFontIsStored;
    property TitleStyle: TTitleStyle read FTitleStyle write SetTitleStyle default tsLazarus;
    property TopRow: Integer read GetTopRow write SetTopRow;
    property UseXORFeatures: boolean read FUseXORFeatures write SetUseXorFeatures default false;
    property ValidateOnSetSelection: boolean read FValidateOnSetSelection write FValidateOnSetSelection;
    property VisibleColCount: Integer read GetVisibleColCount stored false;
    property VisibleRowCount: Integer read GetVisibleRowCount stored false;

    property OnAfterSelection: TOnSelectEvent read FOnAfterSelection write FOnAfterSelection;
    property OnBeforeSelection: TOnSelectEvent read FOnBeforeSelection write FOnBeforeSelection;
    property OnCheckboxToggled: TToggledCheckboxEvent read FOnCheckboxToggled write FOnCheckboxToggled;
    property OnCompareCells: TOnCompareCells read FOnCompareCells write FOnCompareCells;
    property OnPrepareCanvas: TOnPrepareCanvasEvent read FOnPrepareCanvas write FOnPrepareCanvas;
    property OnDrawCell: TOnDrawCell read FOnDrawCell write FOnDrawCell;
    // Deprecated in favor of OnButtonClick.
    property OnEditButtonClick: TNotifyEvent read FOnEditButtonClick write FOnEditButtonClick; deprecated;
    property OnButtonClick: TOnSelectEvent read FOnButtonClick write FOnButtonClick;
    property OnPickListSelect: TNotifyEvent read FOnPickListSelect write FOnPickListSelect;
    property OnSelection: TOnSelectEvent read fOnSelection write fOnSelection;
    property OnSelectEditor: TSelectEditorEvent read FOnSelectEditor write FOnSelectEditor;
    property OnTopLeftChanged: TNotifyEvent read FOnTopLeftChanged write FOnTopLeftChanged;
    property OnUserCheckboxBitmap: TUserCheckboxBitmapEvent read FOnUserCheckboxBitmap write FOnUserCheckboxBitmap;
    property OnUserCheckboxImage: TUserCheckBoxImageEvent read FOnUserCheckboxImage write FOnUserCheckboxImage;
    property OnValidateEntry: TValidateEntryEvent read FOnValidateEntry write FOnValidateEntry;
    // Bidi functions
    function FlipRect(ARect: TRect): TRect;
    function FlipPoint(P: TPoint): TPoint;
    function FlipX(X: Integer): Integer;
    // Hint-related
    property OnGetCellHint : TGetCellHintEvent read FOnGetCellHint write FOnGetCellHint;
    property OnSaveColumn: TSaveColumnEvent read FOnSaveColumn write FOnSaveColumn;
    property OnLoadColumn: TSaveColumnEvent read FOnLoadColumn write FOnLoadColumn;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure Invalidate; override;
    procedure EditingDone; override;

    { Exposed procs }
    procedure AdjustInnerCellRect(var ARect: TRect);
    procedure AutoAdjustColumns; virtual;
    procedure BeginUpdate;
    function  CellRect(ACol, ARow: Integer): TRect;
    function  CellToGridZone(aCol,aRow: Integer): TGridZone;
    procedure CheckPosition;
    function ClearCols: Boolean;
    function ClearRows: Boolean;
    procedure Clear;
    procedure ClearSelections;

    function  EditorByStyle(Style: TColumnButtonStyle): TWinControl; virtual;
    procedure EditorKeyDown(Sender: TObject; var Key:Word; Shift:TShiftState);
    procedure EditorKeyPress(Sender: TObject; var Key: Char);
    procedure EditorKeyUp(Sender: TObject; var key:Word; shift:TShiftState);
    procedure EditorTextChanged(const aCol,aRow: Integer; const aText:string); virtual;

    procedure EndUpdate(aRefresh: boolean = true);
    procedure EraseBackground(DC: HDC); override;
    procedure FixDesignFontsPPI(const ADesignTimePPI: Integer); override;
    function  Focused: Boolean; override;
    function  HasMultiSelection: Boolean;
    procedure HideSortArrow;
    procedure InvalidateCell(aCol, aRow: Integer); overload;
    procedure InvalidateCol(ACol: Integer);
    procedure InvalidateRange(const aRange: TRect);
    procedure InvalidateRow(ARow: Integer);
    function  IsCellVisible(aCol, aRow: Integer): Boolean;
    function  IsFixedCellVisible(aCol, aRow: Integer): boolean;
    procedure LoadFromFile(FileName: string); virtual;
    procedure LoadFromStream(AStream: TStream); virtual;
    function  MouseCoord(X,Y: Integer): TGridCoord;
    function  MouseToCell(const Mouse: TPoint): TPoint; overload;
    procedure MouseToCell(X,Y: Integer; out ACol,ARow: Longint); overload;
    function  MouseToLogcell(Mouse: TPoint): TPoint;
    function  MouseToGridZone(X,Y: Integer): TGridZone;
    procedure SaveToFile(FileName: string); virtual;
    procedure SaveToStream(AStream: TStream); virtual;
    procedure ScaleFontsPPI(const AToPPI: Integer; const AProportion: Double); override;
    procedure SetFocus; override;

    property CursorState: TGridCursorState read FCursorState;
    property SelectedRange[AIndex: Integer]: TGridRect read GetSelectedRange;
    property SelectedRangeCount: Integer read GetSelectedRangeCount;
    property SortOrder: TSortOrder read FSortOrder write FSortOrder;
    property SortColumn: Integer read FSortColumn;
    property TabStop default true;
{$ifdef WINDOWS}
  protected
    procedure IMEStartComposition(var Msg:TMessage); message WM_IME_STARTCOMPOSITION;
    procedure IMEComposition(var Msg:TMessage); message WM_IME_COMPOSITION;
    procedure IMEEndComposition(var Msg:TMessage); message WM_IME_ENDCOMPOSITION;
{$endif}
  end;

  TGetEditEvent = procedure (Sender: TObject; ACol, ARow: Integer; var Value: string) of object;
  TSetEditEvent = procedure (Sender: TObject; ACol, ARow: Integer; const Value: string) of object;
  TGetCheckboxStateEvent = procedure (Sender: TObject; ACol, ARow: Integer; var Value: TCheckboxState) of object;
  TSetCheckboxStateEvent = procedure (Sender: TObject; ACol, ARow: Integer; const Value: TCheckboxState) of object;

  { TCustomDrawGrid }

  TCustomDrawGrid=class(TCustomGrid)
  private
    FEditorRow, FEditorCol: Integer;
    FOnColRowDeleted: TgridOperationEvent;
    FOnColRowExchanged: TgridOperationEvent;
    FOnColRowInserted: TGridOperationEvent;
    FOnColRowMoved: TgridOperationEvent;
    FOnGetCheckboxState: TGetCheckboxStateEvent;
    FOnGetEditMask: TGetEditEvent;
    FOnGetEditText: TGetEditEvent;
    FOnHeaderClick, FOnHeaderSized: THdrEvent;
    FOnHeaderSizing: THeaderSizingEvent;
    FOnSelectCell: TOnSelectcellEvent;
    FOnSetCheckboxState: TSetCheckboxStateEvent;
    FOnSetEditText: TSetEditEvent;
    function CellNeedsCheckboxBitmaps(const aCol,aRow: Integer): boolean;
    procedure DrawCellCheckboxBitmaps(const aCol,aRow: Integer; const aRect: TRect);
    function  GetEditorValue(ACol, ARow: Integer): String;
  protected
    FGrid: TVirtualGrid;
    procedure CellClick(const aCol,aRow: Integer; const Button:TMouseButton); override;
    procedure ColRowDeleted(IsColumn: Boolean; index: Integer); override;
    procedure ColRowExchanged(IsColumn: Boolean; index,WithIndex: Integer); override;
    procedure ColRowInserted(IsColumn: boolean; index: integer); override;
    procedure ColRowMoved(IsColumn: Boolean; FromIndex,ToIndex: Integer); override;
    function  CreateVirtualGrid: TVirtualGrid; virtual;
    procedure DrawCell(aCol,aRow: Integer; aRect: TRect; aState:TGridDrawState); override;
    procedure DrawCellAutonumbering(aCol,aRow: Integer; aRect: TRect; const aValue: string); virtual;
    procedure DrawFocusRect(aCol,aRow: Integer; ARect: TRect); override;
    function  GetCells(ACol, ARow: Integer): string; override;
    procedure GetCheckBoxState(const aCol, aRow:Integer; var aState:TCheckboxState); virtual;
    function  GetEditMask(aCol, aRow: Longint): string; override;
    function  GetEditText(aCol, aRow: Longint): string; override;
    procedure GridMouseWheel(shift: TShiftState; Delta: Integer); override;
    procedure HeaderClick(IsColumn: Boolean; index: Integer); override;
    procedure HeaderSized(IsColumn: Boolean; index: Integer); override;
    procedure HeaderSizing(const IsColumn:boolean; const AIndex,ASize:Integer); override;
    procedure KeyDown(var Key : Word; Shift : TShiftState); override;
    procedure NotifyColRowChange(WasInsert,IsColumn:boolean; FromIndex,ToIndex:Integer);
    function  SelectCell(aCol,aRow: Integer): boolean; override;
    procedure SetColor(Value: TColor); override;
    procedure SetCheckboxState(const aCol, aRow:Integer; const aState: TCheckboxState); virtual;
    procedure SetEditText(ACol, ARow: Longint; const Value: string); override;
    procedure SizeChanged(OldColCount, OldRowCount: Integer); override;
    procedure ToggleCheckbox; virtual;

    property OnGetCheckboxState: TGetCheckboxStateEvent
                              read FOnGetCheckboxState write FOnGetCheckboxState;
    property OnSetCheckboxState: TSetCheckboxStateEvent
                              read FOnSetCheckboxState write FOnSetCheckboxState;

  public

    // to easy user call
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure DeleteColRow(IsColumn: Boolean; index: Integer);
    procedure DeleteCol(Index: Integer); virtual;
    procedure DeleteRow(Index: Integer); virtual;
    procedure ExchangeColRow(IsColumn: Boolean; index, WithIndex: Integer); virtual;
    procedure InsertColRow(IsColumn: boolean; index: integer);
    procedure MoveColRow(IsColumn: Boolean; FromIndex, ToIndex: Integer);
    procedure SortColRow(IsColumn: Boolean; index:Integer); overload;
    procedure SortColRow(IsColumn: Boolean; Index,FromIndex,ToIndex: Integer); overload;

    procedure DefaultDrawCell(aCol,aRow: Integer; var aRect: TRect; aState:TGridDrawState); virtual;
    // properties
    property AllowOutboundEvents;
    property BorderColor;
    property Canvas;
    property Col;
    property ColWidths;
    property ColRow;
    property DisabledFontColor;
    property Editor;
    property EditorBorderStyle;
    property EditorMode;
    property ExtendedColSizing;
    property AltColorStartNormal;
    property FastEditing;
    property FixedGridLineColor;
    property FocusColor;
    property FocusRectVisible;
    property GridHeight;
    property GridLineColor;
    property GridLineStyle;
    property GridWidth;
    property IsCellSelected;
    property LeftCol;
    property Row;
    property RowHeights;
    property SaveOptions;
    property SelectedColor;
    property SelectedColumn;
    property Selection;
    property StrictSort;
    //property TabStops;
    property TopRow;
    property UseXORFeatures;
  public
    property Align;
    property Anchors;
    property AutoAdvance;
    property AutoFillColumns;
    //property BiDiMode;
    property BorderSpacing;
    property BorderStyle;
    property Color default clWindow;
    property ColCount;
    property Columns;
    property Constraints;
    property DefaultColWidth;
    property DefaultDrawing;
    property DefaultRowHeight;
    //property DragCursor;
    //property DragKind;
    //property DragMode;
    property Enabled;
    property FixedColor;
    property FixedCols;
    property FixedHotColor;
    property FixedRows;
    property Flat;
    property Font;
    property GridLineWidth;
    property Options;
    property Options2;
    //property ParentBiDiMode;
    //property ParentColor;
    //property ParentFont;
    property ParentShowHint;
    property PopupMenu;
    property RowCount;
    property ScrollBars;
    property ShowHint;
    property TabAdvance;
    property TabOrder;
    property TabStop;
    property Visible;
    property VisibleColCount;
    property VisibleRowCount;

    property OnAfterSelection;
    property OnBeforeSelection;
    property OnClick;
    property OnColRowDeleted: TgridOperationEvent read FOnColRowDeleted write FOnColRowDeleted;
    property OnColRowExchanged: TgridOperationEvent read FOnColRowExchanged write FOnColRowExchanged;
    property OnColRowInserted: TGridOperationEvent read FOnColRowInserted write FOnColRowInserted;
    property OnColRowMoved: TgridOperationEvent read FOnColRowMoved write FOnColRowMoved;
    property OnCompareCells;
    property OnContextPopup;
    property OnDblClick;
    property OnDragDrop;
    property OnDragOver;
    property OnDrawCell;
    property OnEditButtonClick; deprecated;
    property OnButtonClick;
    property OnEndDock;
    property OnEndDrag;
    property OnEnter;
    property OnExit;
    property OnGetEditMask: TGetEditEvent read FOnGetEditMask write FOnGetEditMask;
    property OnGetEditText: TGetEditEvent read FOnGetEditText write FOnGetEditText;
    property OnHeaderClick: THdrEvent read FOnHeaderClick write FOnHeaderClick;
    property OnHeaderSized: THdrEvent read FOnHeaderSized write FOnHeaderSized;
    property OnHeaderSizing: THeaderSizingEvent read FOnHeaderSizing write FOnHeaderSizing;
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
    property OnPickListSelect;
    property OnPrepareCanvas;
    property OnSelectEditor;
    property OnSelection;
    property OnSelectCell: TOnSelectCellEvent read FOnSelectCell write FOnSelectCell;
    property OnSetEditText: TSetEditEvent read FOnSetEditText write FOnSetEditText;
    property OnStartDock;
    property OnStartDrag;
    property OnTopleftChanged;
    property OnUTF8KeyPress;
    property OnValidateEntry;
  end;



  { TDrawGrid }

  TDrawGrid = class(TCustomDrawGrid)
  public
    property InplaceEditor;
  published
    property Align;
    property AlternateColor;
    property Anchors;
    property AutoAdvance;
    property AutoEdit;
    property AutoFillColumns;
    //property BiDiMode;
    property BorderSpacing;
    property BorderStyle;
//    property CellHintPriority;
    property Color;
    property ColCount;
    property ColRowDraggingCursor;
    property ColRowDragIndicatorColor;
    property ColSizingCursor;
    property ColumnClickSorts;
    property Columns;
    property Constraints;
    property DefaultColWidth;
    property DefaultDrawing;
    property DefaultRowHeight;
    property DoubleBuffered;
    property DragCursor;
    property DragKind;
    property DragMode;
    property Enabled;
    property ExtendedSelect;
    property FixedColor;
    property FixedCols;
    property FixedRows;
    property Flat;
    property Font;
    property GridLineWidth;
    property HeaderHotZones;
    property HeaderPushZones;
    property ImageIndexSortAsc;
    property ImageIndexSortDesc;
    property MouseWheelOption;
    property Options;
    property Options2;
    //property ParentBiDiMode;
    property ParentColor default false;
    property ParentDoubleBuffered;
    property ParentFont;
    property ParentShowHint;
    property PopupMenu;
    property RangeSelectMode;
    property RowCount;
    property RowSizingCursor;
    property ScrollBars;
    property ShowHint;
    property TabAdvance;
    property TabOrder;
    property TabStop;
    property TitleFont;
    property TitleImageList;
    property TitleImageListWidth;
    property TitleStyle;
    property UseXORFeatures;
    property Visible;
    property VisibleColCount;
    property VisibleRowCount;

    property OnAfterSelection;
    property OnBeforeSelection;
    property OnCheckboxToggled;
    property OnClick;
    property OnColRowDeleted;
    property OnColRowExchanged;
    property OnColRowInserted;
    property OnColRowMoved;
    property OnCompareCells;
    property OnContextPopup;
    property OnDblClick;
    property OnDragDrop;
    property OnDragOver;
    property OnDrawCell;
    property OnEditButtonClick; deprecated;
    property OnButtonClick;
    property OnEditingDone;
    property OnEndDock;
    property OnEndDrag;
    property OnEnter;
    property OnExit;
    property OnGetCellHint;
    property OnGetCheckboxState;
    property OnGetEditMask;
    property OnGetEditText;
    property OnHeaderClick;
    property OnHeaderSized;
    property OnHeaderSizing;
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
    property OnMouseWheelHorz;
    property OnMouseWheelLeft;
    property OnMouseWheelRight;
    property OnPickListSelect;
    property OnPrepareCanvas;
    property OnSelectEditor;
    property OnSelection;
    property OnSelectCell;
    property OnSetCheckboxState;
    property OnSetEditText;
    property OnStartDock;
    property OnStartDrag;
    property OnTopleftChanged;
    property OnUserCheckboxBitmap;
    property OnUserCheckboxImage;
    property OnUTF8KeyPress;
    property OnValidateEntry;
  end;

  TCustomStringGrid = class;

  { TStringGridStrings }

  TStringGridStrings = class(TStrings)
  private
    FAddedCount: Integer;
    FGrid: TCustomStringGrid;
    FIsCol: Boolean;
    FIndex: Integer;
    FOwner: TMap;
    function ConvertIndexLineCol(Index: Integer; var Line, Col: Integer): boolean;
  protected
    function Get(Index: Integer): string; override;
    function GetCount: Integer; override;
    function GetObject(Index: Integer): TObject; override;
    procedure Put(Index: Integer; const S: string); override;
    procedure PutObject(Index: Integer; aObject: TObject); override;
  public
    constructor Create(aGrid: TCustomStringGrid; OwnerMap:TMap; aIsCol: Boolean; aIndex: Longint);
    destructor Destroy; override;
    function Add(const S: string): Integer; override;
    procedure Assign(Source: TPersistent); override;
    procedure Clear; override;
    procedure Delete(Index: Integer); override;
    procedure Insert(Index: Integer; const S: string); override;
  end;


  { TCustomStringGrid }

  TCustomStringGrid = class(TCustomDrawGrid)
  private
    FModified: boolean;
    FColsMap,FRowsMap: TMap;
    fOnCellProcess: TCellProcessEvent;
    function  GetCols(index: Integer): TStrings;
    function  GetObjects(ACol, ARow: Integer): TObject;
    function  GetRows(index: Integer): TStrings;
    procedure MapFree(var aMap: TMap);
    function  MapGetColsRows(IsCols: boolean; Index:Integer; var AMap:TMap):TStrings;
    procedure ReadCells(Reader: TReader);
    procedure SetCols(index: Integer; const AValue: TStrings);
    procedure SetObjects(ACol, ARow: Integer; AValue: TObject);
    procedure SetRows(index: Integer; const AValue: TStrings);
    procedure WriteCells(Writer: TWriter);
    procedure CopyCellRectToClipboard(const R:TRect);
  protected
    procedure AssignTo(Dest: TPersistent); override;
    procedure AutoAdjustColumn(aCol: Integer); override;
    procedure CalcCellExtent(acol, aRow: Integer; var aRect: TRect); override;
    procedure DefineProperties(Filer: TFiler); override;
    procedure DefineCellsProperty(Filer: TFiler); virtual;
    function  DoCompareCells(Acol,ARow,Bcol,BRow: Integer): Integer; override;
    procedure DoCopyToClipboard; override;
    procedure DoCutToClipboard; override;
    procedure DoPasteFromClipboard; override;
    procedure DoCellProcess(aCol, aRow: Integer; processType: TCellProcessType; var aValue: string); virtual;
    procedure DrawColumnText(aCol, aRow: Integer; aRect: TRect; aState: TGridDrawState); override;
    procedure DrawTextInCell(aCol,aRow: Integer; aRect: TRect; aState: TGridDrawState); override;
    procedure DrawCellAutonumbering(aCol,aRow: Integer; aRect: TRect; const aValue: string); override;
    //procedure EditordoGetValue; override;
    //procedure EditordoSetValue; override;
    function  GetCells(ACol, ARow: Integer): string; override;
    procedure GetCheckBoxState(const aCol, aRow:Integer; var aState:TCheckboxState); override;
    function  GetEditText(aCol, aRow: Integer): string; override;
    procedure LoadContent(cfg: TXMLConfig; Version: Integer); override;
    procedure Loaded; override;
    procedure SaveContent(cfg: TXMLConfig); override;
    //procedure DrawInteriorCells; override;
    //procedure SelectEditor; override;
    procedure SelectionSetText(TheText: String);
    procedure SelectionSetHTML(TheHTML, TheText: String);
    procedure SetCells(ACol, ARow: Integer; const AValue: string); virtual;
    procedure SetCheckboxState(const aCol, aRow:Integer; const aState: TCheckboxState); override;
    procedure SetEditText(aCol, aRow: Longint; const aValue: string); override;

    property Modified: boolean read FModified write FModified;
    property OnCellProcess: TCellProcessEvent read fOnCellProcess write fOnCellProcess;

  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure AutoSizeColumn(aCol: Integer);
    procedure AutoSizeColumns;
    procedure Clean; overload;
    procedure Clean(CleanOptions: TGridZoneSet); overload;
    procedure Clean(aRect: TRect; CleanOptions: TGridZoneSet); overload;
    procedure Clean(StartCol,StartRow,EndCol,EndRow: integer; CleanOptions: TGridZoneSet); overload;
    procedure CopyToClipboard(AUseSelection: boolean = false);
    procedure InsertRowWithValues(Index: Integer; Values: array of String);
    procedure LoadFromCSVStream(AStream: TStream; ADelimiter: Char=',';
      UseTitles: boolean=true; FromLine: Integer=0; SkipEmptyLines: Boolean=true); virtual;
    procedure LoadFromCSVFile(AFilename: string; ADelimiter: Char=',';
      UseTitles: boolean=true; FromLine: Integer=0; SkipEmptyLines: Boolean=true);
    procedure SaveToCSVStream(AStream: TStream; ADelimiter: Char=',';
      WriteTitles: boolean=true; VisibleColumnsOnly: boolean=false);
    procedure SaveToCSVFile(AFileName: string; ADelimiter: Char=',';
      WriteTitles: boolean=true; VisibleColumnsOnly: boolean=false);

    property Cells[ACol, ARow: Integer]: string read GetCells write SetCells;
    property Cols[index: Integer]: TStrings read GetCols write SetCols;
    property DefaultTextStyle;
    property EditorMode;
    property ExtendedSelect;
    property Objects[ACol, ARow: Integer]: TObject read GetObjects write SetObjects;
    property Rows[index: Integer]: TStrings read GetRows write SetRows;
    property UseXORFeatures;
    property ValidateOnSetSelection;
  end;


  { TStringGrid }

  TStringGrid = class(TCustomStringGrid)
  protected
    class procedure WSRegisterClass; override;
  public
    property Modified;
    property InplaceEditor;
  published
    property Align;
    property AlternateColor;
    property Anchors;
    property AutoAdvance;
    property AutoEdit;
    property AutoFillColumns;
    property BiDiMode;
    property BorderSpacing;
    property BorderStyle;
    property CellHintPriority;
    property Color;
    property ColCount;
    property ColRowDraggingCursor;
    property ColRowDragIndicatorColor;
    property ColSizingCursor;
    property ColumnClickSorts;
    property Columns;
    property Constraints;
    property DefaultColWidth;
    property DefaultDrawing;
    property DefaultRowHeight;
    property DoubleBuffered;
    property DragCursor;
    property DragKind;
    property DragMode;
    property Enabled;
    property ExtendedSelect;
    property FixedColor;
    property FixedCols;
    property FixedRows;
    property Flat;
    property Font;
    property GridLineWidth;
    property HeaderHotZones;
    property HeaderPushZones;
    property ImageIndexSortAsc;
    property ImageIndexSortDesc;
    property MouseWheelOption;
    property Options;
    property Options2;
    property ParentBiDiMode;
    property ParentColor default false;
    property ParentDoubleBuffered;
    property ParentFont;
    property ParentShowHint;
    property PopupMenu;
    property RangeSelectMode;
    property RowCount;
    property RowSizingCursor;
    property ScrollBars;
    property ShowHint;
    property TabAdvance;
    property TabOrder;
    property TabStop;
    property TitleFont;
    property TitleImageList;
    property TitleStyle;
    property UseXORFeatures;
    property Visible;
    property VisibleColCount;
    property VisibleRowCount;

    property OnAfterSelection;
    property OnBeforeSelection;
    property OnCellProcess;
    property OnChangeBounds;
    property OnCheckboxToggled;
    property OnClick;
    property OnColRowDeleted;
    property OnColRowExchanged;
    property OnColRowInserted;
    property OnColRowMoved;
    property OnCompareCells;
    property OnContextPopup;
    property OnDragDrop;
    property OnDragOver;
    property OnDblClick;
    property OnDrawCell;
    property OnEditButtonClick; deprecated;
    property OnButtonClick;
    property OnEditingDone;
    property OnEndDock;
    property OnEndDrag;
    property OnEnter;
    property OnExit;
    property OnGetCellHint;
    property OnGetCheckboxState;
    property OnGetEditMask;
    property OnGetEditText;
    property OnHeaderClick;
    property OnHeaderSized;
    property OnHeaderSizing;
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
    property OnMouseWheelHorz;
    property OnMouseWheelLeft;
    property OnMouseWheelRight;
    property OnPickListSelect;
    property OnPrepareCanvas;
    property OnResize;
    property OnSelectEditor;
    property OnSelection;
    property OnSelectCell;
    property OnSetCheckboxState;
    property OnSetEditText;
    property OnShowHint;
    property OnStartDock;
    property OnStartDrag;
    property OnTopLeftChanged;
    property OnUserCheckboxBitmap;
    property OnUserCheckboxImage;
    property OnUTF8KeyPress;
    property OnValidateEntry;
  end;

procedure DrawRubberRect(Canvas: TCanvas; aRect: TRect; Color: TColor; DrawBits:Byte=BF_RECT);
function  GetWorkingCanvas(const Canvas: TCanvas): TCanvas;
procedure FreeWorkingCanvas(canvas: TCanvas);

procedure Register;

implementation

{$R lcl_grid_images.res}

uses
  WSGrids;

{$WARN SYMBOL_DEPRECATED OFF}
{$IFDEF FPC_HAS_CPSTRING}
  {$WARN IMPLICIT_STRING_CAST OFF}
  {$WARN IMPLICIT_STRING_CAST_LOSS OFF}
{$ENDIF}

const
  MULTISEL_MODIFIER = {$IFDEF Darwin}ssMeta{$ELSE}ssCtrl{$ENDIF};

function BidiFlipX(X: Integer; const Width: Integer; const Flip: Boolean): Integer;
begin
  if Flip then
    //-1 because it zero based
    Result := Width - X - 1
  else
    Result := X;
end;

function BidiFlipX(X: Integer; const ParentRect: TRect; const Flip: Boolean): Integer;
begin
  Result := BidiFlipX(X, ParentRect.Right, Flip);
end;

function BidiFlipPoint(P: TPoint; const ParentRect: TRect; const Flip: Boolean): TPoint;
begin
  Result := P;
  Result.Y := BidiFlipX(Result.Y, ParentRect, Flip);
end;

function PointIgual(const P1,P2: TPoint): Boolean;
begin
  result:=(P1.X=P2.X)and(P1.Y=P2.Y);
end;

function NormalizarRect(const R:TRect): TRect;
begin
  Result.Left:=Min(R.Left, R.Right);
  Result.Top:=Min(R.Top, R.Bottom);
  Result.Right:=Max(R.Left, R.Right);
  Result.Bottom:=Max(R.Top, R.Bottom);
end;

procedure SwapInt(var I1,I2: Integer);
var
  Tmp: Integer;
begin
  Tmp:=I1;
  I1:=I2;
  I2:=Tmp;
end;

{$ifdef GridTraceMsg}
function TransMsg(const S: String; const TheMsg: TLMessage): String;
begin
  case TheMsg.Msg of
    CM_BASE..CM_MOUSEWHEEL:
      case TheMsg.Msg of
        CM_MOUSEENTER:            exit; //Result := 'CM_MOUSEENTER';
        CM_MOUSELEAVE:            exit; //Result := 'CM_MOUSELEAVE';
        CM_TEXTCHANGED:           Result := 'CM_TEXTCHANGED';
        CM_UIACTIVATE:            Result := 'CM_UIACTIVATE';
        CM_CONTROLLISTCHANGE:     Result := 'CM_CONTROLLISTCHANGE';

        CM_PARENTCOLORCHANGED:    Result := 'CM_PARENTCOLORCHANGED';
        CM_PARENTSHOWHINTCHANGED: Result := 'CM_PARENTSHOWHINTCHANGED';
        CM_PARENTBIDIMODECHANGED: Result := 'CM_PARENTBIDIMODECHANGED';
        CM_CONTROLCHANGE:         Result := 'CM_CONTROLCHANGE';
        CM_SHOWINGCHANGED:        Result := 'CM_SHOWINGCHANGED';
        CM_VISIBLECHANGED:        Result := 'CM_VISIBLECHANGED';
        CM_HITTEST:               exit;//Result := 'CM_HITTEST';
        else                      Result := 'CM_BASE + '+ IntToStr(TheMsg.Msg - CM_BASE);
      end;
    else
      case TheMsg.Msg of
        //CN_BASE MESSAGES
        CN_COMMAND:               Result := 'CN_COMMAND';
        CN_KEYDOWN:               Result := 'CN_KEYDOWN';
        CN_KEYUP:                 Result := 'CN_KEYUP';
        CN_CHAR:                  Result := 'CN_CHAR';

        // NORMAL MESSAGES
        LM_SETFOCUS:              Result := 'LM_SetFocus';
        LM_LBUTTONDOWN:           Result := 'LM_MOUSEDOWN';
        LM_LBUTTONUP:             Result := 'LM_LBUTTONUP';
        LM_LBUTTONDBLCLK:         Result := 'LM_LBUTTONDBLCLK';
        LM_RBUTTONDOWN:           Result := 'LM_RBUTTONDOWN';
        LM_RBUTTONUP:             Result := 'LM_RBUTTONUP';
        LM_RBUTTONDBLCLK:         Result := 'LM_RBUTTONDBLCLK';
        LM_GETDLGCODE:            Result := 'LM_GETDLGCODE';
        LM_KEYDOWN:               Result := 'LM_KEYDOWN';
        LM_KEYUP:                 Result := 'LM_KEYUP';
        LM_CAPTURECHANGED:        Result := 'LM_CAPTURECHANGED';
        LM_ERASEBKGND:            Result := 'LM_ERASEBKGND';
        LM_KILLFOCUS:             Result := 'LM_KILLFOCUS';
        LM_CHAR:                  Result := 'LM_CHAR';
        LM_SHOWWINDOW:            Result := 'LM_SHOWWINDOW';
        LM_SIZE:                  Result := 'LM_SIZE';
        LM_WINDOWPOSCHANGED:      Result := 'LM_WINDOWPOSCHANGED';
        LM_HSCROLL:               Result := 'LM_HSCROLL';
        LM_VSCROLL:               Result := 'LM_VSCROLL';
        LM_MOUSEMOVE:             exit;//Result := 'LM_MOUSEMOVE';
        LM_MOUSEWHEEL:            Result := 'LM_MOUSEWHEEL';
        1105:                     exit;//Result := '?EM_SETWORDBREAKPROCEX?';
        else                      Result := GetMessageName(TheMsg.Msg);
      end;
  end;
  Result:= S + '['+IntToHex(TheMsg.msg, 8)+'] W='+IntToHex(TheMsg.WParam,8)+
    ' L='+IntToHex(TheMsg.LParam,8)+' '+Result;
  DebugLn(Result);
end;
{$Endif GridTraceMsg}

function dbgs(zone: TGridZone):string; overload;
begin
  case Zone of
    gzFixedCells: Result := 'gzFixedCells';
    gzFixedCols:  Result := 'gzFixedCols';
    gzFixedRows:  Result := 'gzFixedRows';
    gzNormal:     Result := 'gzNormal';
    gzInvalid:    Result := 'gzInvalid';
    else
      result:= 'gz-error';
  end;
end;

function dbgs(zones: TGridZoneSet):string; overload;
  procedure add(const s:string);
  begin
    if result<>'' then
      result := result + ',' + s
    else
      result := s;
  end;
begin
  result:='';
  if gzFixedCells in zones then add('gzFixedCells');
  if gzFixedCols  in zones then add('gzFixedCols');
  if gzFixedRows  in zones then add('gzFixedRows');
  if gzNormal in zones then add('gzNormal');
  if gzInvalid in zones then add('gzInvalid');
  result := '['+result+']';
end;

{$ifdef DbgScroll}
function SbToStr(Which: Integer): string;
begin
  case Which of
    SB_VERT: result := 'vert';
    SB_HORZ: result := 'horz';
    SB_BOTH: result := 'both';
    else
      result := '????';
  end;
end;
{$endif}

procedure CfgSetFontValue(cfg: TXMLConfig; AKey: WideString; AFont: TFont);
begin
  cfg.SetValue(AKey + '/name/value', AFont.Name);
  cfg.SetValue(AKey + '/size/value', AFont.Size);
  cfg.SetValue(AKey + '/color/value', ColorToString(AFont.Color));
  cfg.SetValue(AKey + '/style/value', Integer(AFont.Style));
end;

procedure CfgGetFontValue(cfg: TXMLConfig; AKey: WideString; AFont: TFont);
begin
  AFont.Name := cfg.GetValue(AKey + '/name/value', 'default');
  AFont.Size := cfg.GetValue(AKey + '/size/value', 0);
  AFont.Color:= StringToColor(cfg.GetValue(AKey + '/color/value', 'clWindowText'));
  AFont.Style:= TFontStyles(cfg.GetValue(AKey + '/style/value', 0));
end;

// Draws a dotted rectangle by drawing each enabled side. By default all sides are
// enabled. The DrawBits parameter set sides to drawn, it has this layout: xxxxBRTL
procedure DrawRubberRect(Canvas: TCanvas; aRect: TRect; Color: TColor;
  DrawBits: Byte);
  procedure DrawVertLine(X1,Y1,Y2: integer);
  begin
    if Y2<Y1 then
      while Y2<Y1 do begin
        Canvas.Pixels[X1, Y1] := Color;
        dec(Y1, varRubberSpace);
      end
    else
      while Y1<Y2 do begin
        Canvas.Pixels[X1, Y1] := Color;
        inc(Y1, varRubberSpace);
      end;
  end;
  procedure DrawHorzLine(X1,Y1,X2: integer);
  begin
    if X2<X1 then
      while X2<X1 do begin
        Canvas.Pixels[X1, Y1] := Color;
        dec(X1, varRubberSpace);
      end
    else
      while X1<X2 do begin
        Canvas.Pixels[X1, Y1] := Color;
        inc(X1, varRubberSpace);
      end;
  end;
begin
  with aRect do begin
    if (DrawBits and BF_TOP = BF_TOP) then DrawHorzLine(Left, Top, Right-1);
    if (DrawBits and BF_RIGHT = BF_RIGHT) then DrawVertLine(Right-1, Top, Bottom-1);
    if (DrawBits and BF_BOTTOM = BF_BOTTOM) then DrawHorzLine(Right-1, Bottom-1, Left);
    if (DrawBits and BF_LEFT = BF_LEFT) then DrawVertLine(Left, Bottom-1, Top);
  end;
end;

function GetWorkingCanvas(const Canvas: TCanvas): TCanvas;
var
  DC: HDC;
begin

  if (Canvas=nil) or (not Canvas.HandleAllocated) then begin
    DC := GetDC(0);
    Result := TCanvas.Create;
    Result.Handle := DC;
  end else
    Result := Canvas;

end;

procedure FreeWorkingCanvas(canvas: TCanvas);
begin

  ReleaseDC(0, Canvas.Handle);
  Canvas.Free;

end;

function Between(const AValue,AMin,AMax: Integer): boolean;
begin
  if AMin<AMax then
    result := InRange(AValue, AMin, AMax)
  else
    result := InRange(AValue, AMax, AMin);
end;

{ TCustomGrid }

function TCustomGrid.GetRowHeights(Arow: Integer): Integer;
begin
  if IsRowIndexValid(aRow) then
    Result:=FRows[aRow]
  else
    Result:=-1;
  if Result<0 then
    Result:=DefaultRowHeight;
end;

function TCustomGrid.GetTopRow: Longint;
begin
  Result:=fTopLeft.y;
end;

function TCustomGrid.GetVisibleColCount: Integer;
begin
  with FGCache do begin
    Result := VisibleGrid.Right-VisibleGrid.Left;
    if GridWidth<=ClientWidth then
      inc(Result)
  end;
end;

function TCustomGrid.GetVisibleRowCount: Integer;
begin
  with FGCache do begin
    Result:=VisibleGrid.bottom-VisibleGrid.top;
    if GridHeight<=ClientHeight then
      inc(Result);
  end;
end;

procedure TCustomGrid.HeadersMouseMove(const X, Y: Integer);
var
  P: TPoint;
  Gz: TGridZone;
  ButtonColumn: boolean;
begin

  with FGCache do begin

    Gz := MouseToGridZone(X,Y);
    ButtonColumn := IsMouseOverCellButton(X, Y);
    P := MouseToCell(Point(X, Y));

    if (gz<>HotGridZone) or (P.x<>HotCell.x) or (P.y<>HotCell.y) then begin
      ResetHotCell;
      if (P.x>=0) and (P.y>=0) then begin
        if ButtonColumn or (goHeaderHotTracking in Options) then begin
          InvalidateCell(P.X, P.Y);
          HotCell := P;
        end;
      end;
    end;

    if ButtonColumn or (goHeaderPushedLook in Options) then begin
      if ClickCellPushed then begin
        if (P.X<>PushedCell.x) or (P.Y<>PushedCell.Y) then
          ResetPushedCell(False);
      end else
      if IsPushCellActive() then begin
        if (P.X=PushedCell.X) and (P.Y=PushedCell.Y) then begin
          ClickCellPushed:=True;
          InvalidateCell(P.X, P.Y);
        end;
      end;
    end;

    HotGridZone := Gz;
  end;
end;

procedure TCustomGrid.InternalAutoFillColumns;

  procedure SetColumnWidth(aCol,aWidth: Integer);
  begin
    if csLoading in ComponentState then
      SetRawColWidths(aCol, aWidth)
    else
      SetColWidths(aCol, aWidth);
  end;

var
  I, ForcedIndex: Integer;
  Count: Integer;
  aPriority, aMin, aMax: Integer;
  AvailableSize: Integer;
  TotalWidth: Integer;     // total grid's width
  FixedSizeWidth: Integer; // total width of Fixed Sized Columns
begin
  if not AutoFillColumns then
    exit;

  if FUpdatingAutoFillCols then
    exit;

  FUpdatingAutoFillCols:=True;
  try
    // if needed, last size can be obtained from FLastWidth
    // when InternalAutoFillColumns is called from DoChangeBounds
    // for example.

    // Insert the algorithm that modify ColWidths accordingly
    //
    // For testing purposes, a simple algortihm is implemented:
    // if SizePriority=0, column size should be unmodified
    // if SizePriority<>0 means variable size column, its size
    // is the average avalilable size.

    Count := 0;
    FixedSizeWidth := 0;
    TotalWidth := 0;
    for i:=0 to ColCount-1 do begin
      GetAutoFillColumnInfo(i, aMin, aMax, aPriority);
      AvailableSize := GetColWidths(i);
      if aPriority>0 then
        Inc(Count)
      else
        Inc(FixedSizeWidth, AvailableSize);
      Inc(TotalWidth, AvailableSize);
    end;

    if Count=0 then begin
      //it's an autofillcolumns grid, so at least one
      // of the columns must fill completely the grid's
      // available width, let it be that column the last
      ForcedIndex := ColCount-1;
      if ForcedIndex>=FixedCols then
        Dec(FixedSizeWidth, GetColWidths(ForcedIndex));
      Count := 1;
    end else
      ForcedIndex := -1;

    AvailableSize := ClientWidth - FixedSizeWidth - GetBorderWidth;
    if AvailableSize<0 then begin
      // There is no space available to fill with
      // Variable Size Columns, what to do?

      // Simply set all Variable Size Columns
      // to 0, decreasing the size beyond this
      // shouldn't be allowed.
      for i:=0 to ColCount-1 do begin
        GetAutoFillColumnInfo(i, aMin, aMax, aPriority);
        if aPriority>0 then
          SetColumnWidth(i, 0);
      end;
    end else begin
      // Simpler case: There is actually available space to
      //     to be shared for variable size columns.
      FixedSizeWidth := AvailableSize mod Count; // space left after filling columns
      AvailableSize := AvailableSize div Count;
      for i:=0 to ColCount-1 do begin
        GetAutoFillColumnInfo(i, aMin, aMax, aPriority);
        if (APriority>0) or (i=ForcedIndex) then begin
          if i=ColCount-1 then
            // the last column gets all space left
            SetColumnWidth(i, AvailableSize + FixedSizeWidth)
          else
            SetColumnWidth(i, AvailableSize);
        end;
      end;
    end;
  finally
    FUpdatingAutoFillCols:=False;
  end;
end;

function TCustomGrid.InternalNeedBorder: boolean;
begin
  result := FFlat and (FGridBorderStyle = bsSingle);
end;

procedure TCustomGrid.InternalSetColCount(ACount: Integer);
var
  OldC: Integer;
  NewRowCount: Integer;
begin
  OldC := FCols.Count;
  if ACount=OldC then
    Exit;
  if ACount<1 then
    Clear
  else begin
    if EditorMode and (ACount<=Col) then
      EditorMode:=False;
    NewRowCount := RowCount;
    if (OldC=0) and FGridPropBackup.ValidData then begin
      NewRowCount := FGridPropBackup.RowCount;
      FFixedRows := Min(FGridPropBackup.FixedRowCount, NewRowCount);
      FFixedCols := Min(FGridPropBackup.FixedColCount, ACount);
    end;
    CheckFixedCount(ACount, NewRowCount, FFixedCols, FFixedRows);
    CheckCount(ACount, NewRowCount);
    AdjustCount(True, OldC, ACount);
    FGridPropBackup.ValidData := false;
  end;
end;

procedure TCustomGrid.InternalSetColWidths(aCol, aValue: Integer);
var
  OldSize,NewSize: Integer;
  R: TRect;
  Bigger: boolean;
begin
  NewSize := AValue;
  if NewSize<0 then begin
    AValue:=-1;
    NewSize := DefaultColWidth;
  end;

  OldSize := FCols[ACol];
  if NewSize<>OldSize then begin

    if OldSize<0 then
      OldSize := DefaultColWidth;

    Bigger := NewSize>OldSize;
    SetRawColWidths(ACol, AValue);

    if not (csLoading in ComponentState) and HandleAllocated then begin

      if FUpdateCount=0 then begin
        UpdateSizes;
        R := CellRect(aCol, 0);
        R.Bottom := FGCache.MaxClientXY.Y+GetBorderWidth+1;
        if UseRightToLeftAlignment then begin
          //Bigger or not bigger i will refresh
          R.Left := FGCache.ClientRect.Left;
          if aCol=FTopLeft.x then
            R.Right := FGCache.ClientRect.Right - FGCache.FixedWidth;
        end
        else begin
          if Bigger then
            R.Right := FGCache.MaxClientXY.X+GetBorderWidth+1
          else
            R.Right := FGCache.ClientWidth;
          if aCol=FTopLeft.x then
            R.Left := FGCache.FixedWidth;
        end;
        InvalidateRect(handle, @R, False);
      end;

      if (FEditor<>nil)and(Feditor.Visible)and(ACol<=FCol) then
        EditorWidthChanged(aCol, aValue);
      ColWidthsChanged;
    end;

  end;
end;

procedure TCustomGrid.InternalUpdateColumnWidths;
var
  i: Integer;
  C: TGridColumn;
begin
  for i:= FixedCols to ColCount-1 do begin
    C := ColumnFromGridColumn(i);
    if C<>nil then
      SetRawColWidths(i, C.Width);
  end;
end;

procedure TCustomGrid.InvalidateMovement(DCol, DRow: Integer; OldRange: TRect);

  procedure doInvalidateRange(Col1,Row1,Col2,Row2: Integer);
  begin
    InvalidateRange(Rect(Col1,Row1,Col2,Row2));
  end;

begin
  if (goRowHighlight in Options) then
    OldRange := Rect(FFixedCols, OldRange.Top, Colcount-1, OldRange.Bottom);
  if SelectActive then begin

    if DCol>FCol then begin
      // expanded cols
      if not (goRowSelect in Options) then
        doInvalidateRange(FCol, OldRange.Top, DCol, Oldrange.Bottom)

      else if (goRelaxedRowSelect in Options) and (DRow=FRow) then
        InvalidateRow(DRow)

    end else if DCol<FCol then begin
      // shrunk cols
      if not (goRowSelect in Options) then
        doInvalidateRange(DCol,OldRange.Top,FCol,OldRange.Bottom)

      else if (goRelaxedRowSelect in Options) and (DRow=FRow) then
        InvalidateRow(DRow)

    end;

    if DRow>FRow then
      // expanded rows
      doInvalidateRange(OldRange.Left, FRow, OldRange.Right, DRow)

    else if DRow<FRow then
      // shrunk rows
      doInvalidateRange(OldRange.Left, DRow, OldRange.Right, FRow);

    if not ((goRowSelect in Options) or (goRowHighlight in Options)) then begin

      // Above rules do work only if either rows or cols remain
      // constant, if both rows and cols change there may be gaps
      //
      // four cases are left.
      //

      if (DCol>FCol)and(DRow<FRow) then // (1: I   Cuadrant)
        // Rect(FCol+1,FRow-1,DCol,DRow) normalized -v
        doInvalidateRange(FCol+1, DRow, DCol, FRow-1)
      else
      if (DCol<FCol)and(DRow<FRow) then // (2: II  Cuadrant)
        // Rect(FCol-1,FRow-1,DCol,DRow) normalized -v
        doInvalidateRange(DCol, DRow, FCol-1, FRow-1)
      else
      if (DCol<FCol)and(DRow>FRow) then // (3: III Cuadrant)
        // Rect(FCol-1,FRow+1,DCol,DRow) normalized -v
        doInvalidateRange(DCol, FRow+1, FCol-1, DRow)
      else
      if (DCol>FCol)and(DRow>FRow) then // (4: IV  Cuadrant)
        // normalization not needed
        doInvalidateRange(FCol+1,FRow+1,DCol,DRow);

    end;

  end else begin

    if (OldRange.Right-OldRange.Left>0) or
      (OldRange.Bottom-OldRange.Top>0) then
      // old selected range gone, invalidate old area
      InvalidateRange(OldRange)
    else
      // Single cell
      InvalidateCell(FCol, FRow);

    // and invalidate current selecion, cell or full row
    if ((goRowSelect in Options) or (goRowHighlight in Options)) then
      InvalidateRow(Drow)
    else
      InvalidateCell(DCol, DRow);

  end;

end;

function TCustomGrid.IsColumnsStored: boolean;
begin
  result := Columns.Enabled;
end;

function TCustomGrid.IsPushCellActive: boolean;
begin
  with FGCache do
    result := (PushedCell.X<>-1) and (PushedCell.Y<>-1);
end;

function TCustomGrid.LoadResBitmapImage(const ResName: string): TBitmap;
var
  C: TPortableNetworkGraphic;
begin
  C := TPortableNetworkGraphic.Create;
  try
    C.LoadFromResourceName(hInstance, ResName);
    Result := TBitmap.Create;
    Result.Assign(C);
  finally
    C.Free;
  end;
end;

function TCustomGrid.MouseButtonAllowed(Button: TMouseButton): boolean;
begin
  result := (Button=mbLeft);
end;

function TCustomGrid.GetLeftCol: Integer;
begin
  result:=fTopLeft.x;
end;

function TCustomGrid.GetPxTopLeft: TPoint;
begin
  if (FTopLeft.x >= 0) and (FTopLeft.x < FGCache.AccumWidth.Count) then
    Result.x := FGCache.AccumWidth[FTopLeft.x]+FGCache.TLColOff-FGCache.FixedWidth
  else if FTopLeft.x > 0 then
    Result.x := FGCache.GridWidth+FGCache.TLColOff-FGCache.FixedWidth
  else
    Result.x := 0;

  if (FTopLeft.y >= 0) and (FTopLeft.y < FGCache.AccumHeight.Count) then
    Result.y := FGCache.AccumHeight[FTopLeft.y]+FGCache.TLRowOff-FGCache.FixedHeight
  else if FTopLeft.y > 0 then
    Result.y := FGCache.GridHeight+FGCache.TLRowOff-FGCache.FixedHeight
  else
    Result.y := 0;
end;

function TCustomGrid.GetColCount: Integer;
begin
  Result:=FCols.Count;
end;

function TCustomGrid.GetRowCount: Integer;
begin
  Result:=FRows.Count;
end;

function TCustomGrid.IsColumnIndexValid(AIndex: Integer): boolean;
begin
  Result := (AIndex>=0) and (AIndex<ColCount);
end;

function TCustomGrid.IsRowIndexValid(AIndex: Integer): boolean;
begin
  Result := (AIndex>=0) and (AIndex<RowCount);
end;

function TCustomGrid.IsColumnIndexVariable(AIndex: Integer): boolean;
begin
  Result := (AIndex>=FFixedCols) and (AIndex<ColCount);
end;

function TCustomGrid.IsRowIndexVariable(AIndex: Integer): boolean;
begin
  Result := (AIndex>=FFixedRows) and (AIndex<RowCount);
end;

function TCustomGrid.GetColWidths(Acol: Integer): Integer;
var
  C: TGridColumn;
begin
  if not Columns.Enabled or (aCol<FirstGridColumn) then
  begin
    if IsColumnIndexValid(aCol) then
      Result:=FCols[aCol]
    else
      Result:=-1;
  end else
  begin
    C := ColumnFromGridColumn(Acol);
    if C<>nil then
      Result:=C.Width
    else
      Result:=-1;
  end;
  if Result<0 then
    Result:=DefaultColWidth;
end;

procedure TCustomGrid.SetEditor(AValue: TWinControl);
var
  Msg: TGridMessage;
begin
  if FEditor=AValue then exit;

  {$ifdef DbgGrid}
  DebugLnEnter('TCustomGrid.SetEditor %s oldEd=%s newEd=%s INIT',[dbgsName(self),dbgsName(FEditor),dbgsName(Avalue)]);
  {$endif}
  if (FEditor<>nil) and FEditor.Visible then
    EditorHide;

  FEditor:=AValue;
  if FEditor<>nil then begin

    if FEditor.Parent=nil then
      FEditor.Visible:=False;

    if FEditor.Parent<>Self then
      FEditor.Parent:=Self;

    Msg.LclMsg.msg:=GM_SETGRID;
    Msg.Grid:=Self;
    Msg.Options:=0;
    FEditor.Dispatch(Msg);

    FEditorOptions := Msg.Options + 1; // force new editor setup
    SetEditorOptions(Msg.Options);
  end;
  {$ifdef DbgGrid}
  DebugLnExit('TCustomGrid.SetEditor DONE');
  {$endif}
end;

procedure TCustomGrid.SetFixedCols(const AValue: Integer);
begin
  if FFixedCols=AValue then begin
    if FixedGrid and FGridPropBackup.ValidData then begin
      // user modified fixed properties in fixed grid
      // update stored values
      FGridPropBackup.FixedColCount := AValue;
    end;
    exit;
  end;
  CheckFixedCount(ColCount, RowCount, AValue, FFixedRows);

  if EditorMode then
    EditorMode:=False;

  FFixedCols:=AValue;
  FTopLeft.x:=AValue;

  if Columns.Enabled then begin

    FCol:=AValue;
    UpdateSelectionRange;
    if not (csLoading in componentState) then
      doTopleftChange(true);

    ColumnsChanged(nil)

  end else begin

    if not (csLoading in componentState) then
      doTopleftChange(true);

    MoveNextSelectable(False, FixedCols, FRow);
    UpdateSelectionRange;
  end;
end;

procedure TCustomGrid.SetFixedRows(const AValue: Integer);
begin
  if FFixedRows=AValue then begin
    if FixedGrid and FGridPropBackup.ValidData then begin
      // user modified fixed properties in fixed grid
      // update stored values
      FGridPropBackup.FixedRowCount := AValue;
    end;
    exit;
  end;
  CheckFixedCount(ColCount, RowCount, FFixedCols, AValue);

  if EditorMode then
    EditorMode:=False;

  FFixedRows:=AValue;
  FTopLeft.y:=AValue;

  if not (csLoading in ComponentState) then
    doTopleftChange(true);

  MoveNextSelectable(False, FCol, FixedRows);
  UpdateSelectionRange;
end;

procedure TCustomGrid.SetGridLineColor(const AValue: TColor);
begin
  if FGridLineColor=AValue then exit;
  FGridLineColor:=AValue;
  Invalidate;
end;

procedure TCustomGrid.SetFixedGridLineColor(const AValue: TColor);
begin
  if FFixedGridLineColor=AValue then exit;
  FFixedGridLineColor:=AValue;
  Invalidate;
end;

procedure TCustomGrid.SetLeftCol(const AValue: Integer);
begin
  TryScrollTo(AValue, FTopLeft.Y, True, False);
end;

procedure TCustomGrid.SetOptions(const AValue: TGridOptions);
begin
  if FOptions=AValue then exit;
  FOptions:=AValue;
  UpdateSelectionRange;
  if goEditing in Options then
    SelectEditor;
  if goAlwaysShowEditor in Options then
    EditorShow(true)
  else
    EditorHide;
  if goAutoAddRowsSkipContentCheck in Options then
    FRowAutoInserted := False;
  VisualChange;
end;

procedure TCustomGrid.SetOptions2(const AValue: TGridOptions2);
begin
  if FOptions2=AValue then exit;
  FOptions2:=AValue;
  VisualChange;
end;

procedure TCustomGrid.SetScrollBars(const AValue: TScrollStyle);
begin
  if FScrollBars=AValue then exit;
  FScrollBars:=AValue;
  VisualChange;
end;

procedure TCustomGrid.SetTopRow(const AValue: Integer);
begin
  TryScrollTo(FTopLeft.X, Avalue, False, True);
end;

function TCustomGrid.StartColSizing(const X, Y: Integer):boolean;
var
  OrgIndex, TmpIndex: Integer;
  ACase: Integer;
begin

  result := false;
  with FSizing do begin

    OrgIndex := FGCache.ClickCell.X;
    if OrgIndex<0 then begin
      // invalid starting cell
      if not AllowOutBoundEvents and (FCursorState=gcsColWidthChanging) then
        // resizing still allowed if mouse is within "resizeable region"
        OrgIndex := Index
      else
        exit;
    end;

    Index := OrgIndex;
    ColRowToOffset(true, true, Index, OffIni, OffEnd);

    if (Min(OffEnd, FGCache.ClientRect.Right)-FGCache.ClickMouse.X) <  (FGCache.ClickMouse.X-OffIni) then begin
      if X>FGCache.ClickMouse.X then
        ACase := 4  // dragging right side to the right
      else
        ACase := 3; // dragging right side to the left
    end else begin
      if X>FGCache.ClickMouse.X then
        ACase := 2  // dragging left side to the right
      else
        ACase := 1; // dragging left side to the left
    end;

    if UseRightToLeftAlignment then begin
      case ACase of
        1: ACase := 4;
        2: ACase := 3;
        3: ACase := 2;
        4: ACase := 1;
      end;
    end;

    case ACase of
      3: ; // current column is the right one to resize
      4:   // find following covered column (visible 0-width) at the right side
        begin
          TmpIndex := Index;
          while (TmpIndex<ColCount-1) and (ColWidths[TmpIndex+1]=0) do begin
            Inc(TmpIndex);
            if not Columns.Enabled or ColumnFromGridColumn(TmpIndex).Visible then
              Index := TmpIndex;
          end;
        end;
      2:   // find previous visible (width>0) or covered column
        begin
          Dec(Index);
          while (Index>FixedCols) do begin
            if not Columns.Enabled or ColumnFromGridColumn(Index).Visible then
              break;
            Dec(Index);
          end;
        end;
      1:   // find previous visible (width>0) column
        begin
          Dec(Index);
          while (Index>FixedCols) do begin
            if ColWidths[Index]>0 then
              break;
            Dec(Index);
          end;
        end;
    end;

    if OrgIndex<>Index then
      ColRowToOffset(True, True, Index, OffIni, OffEnd);

    // if precision on changing cursor from normal to split is expanded, there
    // will be a starting big jump on size, to fix it, uncomment next lines
    // TODO: check for RTL
    //DeltaOff := OffEnd - FGCache.ClickMouse.X;
    DeltaOff := 0;

    if goFixedColSizing in Options then
      result := (Index>=0)
    else
      result := (Index>=FixedCols);
  end;

end;

procedure TCustomGrid.ChangeCursor(ACursor: TCursor;
  ASaveCurrentCursor: Boolean = true);
begin
  if FCursorChangeLock = 0 then
  begin
    if ASaveCurrentCursor then
      FSavedCursor := Cursor;
    inc(FCursorChangeLock);
    Cursor := ACursor;
    dec(FCursorChangeLock);
  end;
end;

procedure TCustomGrid.RestoreCursor;
begin
  Cursor := FSavedCursor;
  FCursorState := gcsDefault;
end;

procedure TCustomGrid.SetRowHeights(Arow: Integer; Avalue: Integer);
var
  OldSize,NewSize: Integer;
  R: TRect;
  Bigger: boolean;
begin

  NewSize := AValue;
  if NewSize<0 then begin
    AValue:=-1;
    NewSize := DefaultRowHeight;
  end;

  OldSize := FRows[ARow];
  if AValue<>OldSize then begin

    if OldSize<0 then
      OldSize := DefaultRowHeight;

    bigger := NewSize > OldSize;

    FRows[ARow]:=AValue;

    if not (csLoading in ComponentState) and HandleAllocated then begin
      if FUpdateCount=0 then begin
        UpdateSizes;

        R := CellRect(0, aRow);
        if UseRightToLeftAlignment then
        begin
          R.Left := FlipX(FGCache.MaxClientXY.X+GetBorderWidth);
          R.Right := R.Right + 1;
        end
        else
          R.Right := FGCache.MaxClientXY.X+GetBorderWidth+1;
        if bigger then
          R.Bottom := FGCache.MaxClientXY.Y+GetBorderWidth+1
        else
          R.Bottom := FGCache.ClientHeight;
        if aRow=FTopLeft.y then
          R.Top := FGCache.FixedHeight;

        InvalidateRect(handle, @R, False);
      end;

      if (FEditor<>nil)and(Feditor.Visible)and(ARow<=FRow) then EditorPos;
      RowHeightsChanged;
    end;

  end;
end;

procedure TCustomGrid.SetColWidths(Acol: Integer; Avalue: Integer);
var
  c: TGridColumn;
  OldWidth: Integer;
begin
  if not Columns.Enabled or (aCol<FFixedCols) then
    internalSetColWidths(aCol, aValue)
  else begin
    C := ColumnFromGridColumn(ACol);
    if C<>nil then begin
      OldWidth := C.Width;
      C.Width := AValue;
      SetRawColWidths(ACol, AValue);
      if OldWidth<>C.Width then
        EditorWidthChanged(aCol, C.Width);
    end;
  end;
end;

procedure TCustomGrid.SetRawColWidths(ACol: Integer; AValue: Integer);
begin
  if ACol < FCols.Count then      // Prevent a range error in case of a bug.
    FCols[ACol]:=Avalue
  else
    DebugLn(['TCustomGrid.SetRawColWidths with Range Error: ACol=', ACol, ', Cols.Count=', FCols.Count]);
end;

procedure TCustomGrid.AdjustCount(IsColumn: Boolean; OldValue, NewValue: Integer);

  procedure AddDel(Lst: TIntegerList; aCount: Integer);
  begin
    while lst.Count<aCount do
      Lst.Add(-1); // default width/height
    Lst.Count:=aCount;
  end;

var
  OldCount, NewCount: integer;
begin
  if IsColumn then begin
    AddDel(FCols, NewValue);
    FGCache.AccumWidth.Count:=NewValue;
    OldCount:=RowCount;
    if (OldValue=0)and(NewValue>=0) then begin
      FTopLeft.X:=FFixedCols;
      if RowCount=0 then begin
        if FGridPropBackup.ValidData then begin
          NewCount := FGridPropBackup.RowCount;
          FFixedRows := Min(FGridPropBackup.FixedRowCount, NewCount);
        end
        else
          NewCount := 1;
        FTopLeft.Y:=FFixedRows;
        AddDel(FRows, NewCount);
        FGCache.AccumHeight.Count:=NewCount;
      end;
    end;
    UpdateCachedSizes;
    SizeChanged(OldValue, OldCount);
    // if new count makes current col out of range, adjust position
    // if not, position should not change (fake changed col to be the last one)
    Dec(NewValue);
    if NewValue<Col then
      NewValue:=Col;
    FixPosition(True, NewValue);
  end else begin
    AddDel(FRows, NewValue);
    FGCache.AccumHeight.Count:=NewValue;
    OldCount:=ColCount;
    if (OldValue=0)and(NewValue>=0) then begin
      FTopleft.Y:=FFixedRows;
      //DebugLn('TCustomGrid.AdjustCount B ',DbgSName(Self),' FTopLeft=',dbgs(FTopLeft));
      if FCols.Count=0 then begin
        if FGridPropBackup.ValidData then begin
          NewCount := FGridPropBackup.ColCount;
          FFixedCols := Min(FGridPropBackup.FixedColCount, NewCount);
        end
        else begin
          NewCount := 1;
          FFixedCols := 0;
        end;
        FTopLeft.X:=FFixedCols;
        AddDel(FCols, NewCount);
        FGCache.AccumWidth.Count:=NewCount;
      end;
    end;
    UpdateCachedSizes;
    SizeChanged(OldCount, OldValue);
    // if new count makes current row out of range, adjust position
    // if not, position should not change (fake changed row to be the last one)
    Dec(NewValue);
    if NewValue<Row then
      NewValue:=Row;
    FixPosition(False, NewValue);
  end;
end;

procedure TCustomGrid.AdjustEditorBounds(NewCol,NewRow:Integer);
begin
  SetColRow(NewCol,NewRow);
  if EditorMode then
    EditorPos;
end;

procedure TCustomGrid.AfterMoveSelection(const prevCol, prevRow: Integer);
begin
  if Assigned(OnAfterSelection) then
    OnAfterSelection(Self, prevCol, prevRow);
end;

procedure TCustomGrid.AssignTo(Dest: TPersistent);
var
  Target: TCustomGrid;
begin
  if Dest is TCustomGrid then begin

    Target := TCustomGrid(Dest);
    Target.BeginUpdate;

    // structure
    Target.FixedCols := 0;
    Target.FixedRows := 0;
    if Columns.Enabled then
      Target.Columns.Assign(Columns)
    else begin
      Target.ColCount :=ColCount;
    end;
    Target.RowCount := RowCount;
    Target.FixedCols := FixedCols;
    Target.FixedRows := FixedRows;
    if DefaultRowHeightIsStored then
      Target.DefaultRowHeight := DefaultRowHeight
    else
      Target.DefaultRowHeight := -1;
    if DefaultColWidthIsStored then
      Target.DefaultColWidth := DefaultColWidth
    else
      Target.DefaultColWidth := -1;
    if not Columns.Enabled then
      Target.FCols.Assign(FCols);
    Target.FRows.Assign(FRows);

    // Options
    Target.Options := Options;
    Target.Color := Color;
    Target.FixedColor := FixedColor;
    Target.AlternateColor := AlternateColor;
    Target.Font := Font;
    Target.TitleFont := TitleFont;

    // position
    Target.TopRow := TopRow;
    Target.LeftCol := LeftCol;
    Target.Col := Col;
    Target.Row := Row;
    Target.FRange := FRange;

    Target.EndUpdate;

  end else
    inherited AssignTo(Dest);
end;

procedure TCustomGrid.SetColCount(AValue: Integer);
begin
  if Columns.Enabled then
    raise EGridException.Create('Use Columns property to add/remove columns');
  InternalSetColCount(AValue);
end;

procedure TCustomGrid.SetRowCount(AValue: Integer);
var
  OldR, NewColCount: Integer;
begin
  OldR := FRows.Count;
  if AValue<>OldR then begin
    if AValue>=0 then begin
      if EditorMode and (AValue<=Row) then
        EditorMode:=False;
      NewColCount := ColCount;
      if (OldR=0) and FGridPropBackup.ValidData then begin
        NewColCount := FGridPropBackup.ColCount;
        FFixedCols := Min(FGridPropBackup.FixedColCount, NewColCount);
        FFixedRows := Min(FGridPropBackup.FixedRowCount, AValue);
        FTopLeft.X := FFixedCols;
        FTopLeft.Y := FFixedRows;
        // ignore backedup value of rowcount because
        // finally rowcount will be AValue
        FGridPropBackup.RowCount := AValue;
      end;
      if Columns.Enabled then begin
        // setup custom columns
        Self.ColumnsChanged(nil);
        FGridPropBackup.ValidData := false;
        // still need to adjust rowcount?
        if AValue=FRows.Count then
          exit;
      end;
      CheckFixedCount(NewColCount, AValue, FFixedCols, FFixedRows);
      CheckCount(NewColCount, AValue);
      AdjustCount(False, OldR, AValue);
    end
    else
      ClearRows;
  end;
end;

procedure TCustomGrid.SetDefColWidth(AValue: Integer);
var
  OldLeft,OldRight,NewLeft,NewRight: Integer;
begin
  if AValue=fDefColwidth then
    Exit;
  FDefColWidth:=AValue;
  FRealizedDefColWidth := 0;

  if EditorMode then
    ColRowToOffset(True, True, FCol, OldLeft, OldRight);

  ResetDefaultColWidths;

  if EditorMode then begin
    ColRowToOffset(True, True, FCol, NewLeft, NewRight);
    if (NewLeft<>OldLeft) or (NewRight<>OldRight) then
      EditorWidthChanged(FCol, GetColWidths(FCol));
  end;
end;

procedure TCustomGrid.SetDefRowHeight(AValue: Integer);
var
  i: Integer;
  OldTop,OldBottom,NewTop,NewBottom: Integer;
begin
  if (AValue<>fDefRowHeight) or (csLoading in ComponentState) then
  begin
    FDefRowheight:=AValue;
    FRealizedDefRowHeight := 0;

    if EditorMode then
      ColRowToOffSet(False,True, FRow, OldTop, OldBottom);

    for i:=0 to RowCount-1 do
      FRows[i] := -1;
    VisualChange;

    if EditorMode then
    begin
      ColRowToOffSet(False,True, FRow, NewTop, NewBottom);
      if (NewTop<>OldTOp) or (NewBottom<>OldBottom) then
        EditorPos;
    end;
  end;
end;

procedure TCustomGrid.SetCol(AValue: Integer);
begin
  if AValue=FCol then Exit;
  if not AllowOutboundEvents then
    CheckLimitsWithError(AValue, FRow);
  MoveExtend(False, AValue, FRow, True);
  Click;
end;

procedure TCustomGrid.SetRangeSelectMode(const AValue: TRangeSelectMode);
begin
  if FRangeSelectMode=AValue then exit;
  FRangeSelectMode := AValue;
  ClearSelections;
end;

procedure TCustomGrid.SetRow(AValue: Integer);
begin
  if AValue=FRow then Exit;
  if not AllowOutBoundEvents then
    CheckLimitsWithError(FCol, AValue);
  MoveExtend(False, FCol, AValue, True);
  Click;
end;

procedure TCustomGrid.Sort(ColSorting: Boolean; index, IndxFrom, IndxTo: Integer);
  procedure QuickSort(L,R: Integer);
  var
    I,J: Integer;
    P{,Q}: Integer;
  begin
    repeat
      I:=L;
      J:=R;
      P:=(L+R) div 2;
      repeat
        if ColSorting then begin
          while DoCompareCells(index, P, index, I)>0 do I:=I+1;
          while DoCompareCells(index, P, index, J)<0 do J:=J-1;
        end else begin
          while DoCompareCells(P, index, I, index)>0 do I:=I+1;
          while DoCompareCells(P, index, J, index)<0 do J:=J-1;
        end;
        if I<=J then begin

          if I<>J then
            if not FStrictSort or
              (ColSorting     and (DoCompareCells(index, I, index, J)<>0)) or
              (not ColSorting and (DoCompareCells(I, index, J, index)<>0))
            then
              DoOPExchangeColRow(not ColSorting, I,J);

          if P=I then
            P:=J
          else if P=J then
            P:=I;

          I:=I+1;
          J:=J-1;
        end;
      until I>J;

      if L<J then
        QuickSort(L,J);

      L:=I;
    until I>=R;
  end;
begin
  if RowCount>FixedRows then begin
    CheckIndex(ColSorting, Index);
    CheckIndex(not ColSorting, IndxFrom);
    CheckIndex(not ColSorting, IndxTo);
    BeginUpdate;
    QuickSort(IndxFrom, IndxTo);
    EndUpdate;
  end;
end;

procedure TCustomGrid.HideSortArrow;
begin
  FSortColumn := -1;
  InvalidateGrid;
end;

procedure TCustomGrid.doTopleftChange(DimChg: Boolean);
begin
  TopLeftChanged;
  VisualChange;
end;

procedure TCustomGrid.DrawXORVertLine(X: Integer);
var
  OldPenMode: TPenMode;
  OldPenColor: TColor;
begin
  OldPenMode := Canvas.Pen.Mode;
  OldPenColor := Canvas.Pen.Color;
  Canvas.Pen.Color := clWhite;
  Canvas.Pen.Mode := pmXOR;
  Canvas.MoveTo(X,0);
  Canvas.LineTo(X,FGCache.MaxClientXY.Y);
  Canvas.Pen.Mode := OldPenMode;
  Canvas.Pen.Color := OldPenColor;
end;

procedure TCustomGrid.DrawXORHorzLine(Y: Integer);
var
  OldPenMode: TPenMode;
  OldPenColor: TColor;
begin
  OldPenMode := Canvas.Pen.Mode;
  OldPenColor := Canvas.Pen.Color;
  Canvas.Pen.Color := clWhite;
  Canvas.Pen.Mode := pmXOR;
  if UseRightToLeftAlignment then begin
    Canvas.MoveTo(FlipX(FGCache.MaxClientXY.X)+1,Y);
    Canvas.LineTo(FGCache.ClientRect.Right,Y);
  end
  else begin
    Canvas.MoveTo(0,Y);
    Canvas.LineTo(FGCache.MaxClientXY.X,Y);
  end;
  Canvas.Pen.Mode := OldPenMode;
  Canvas.Pen.Color := OldPenColor;
end;

procedure TCustomGrid.VisualChange;
begin
  if (FUpdateCount<>0) then
    exit;

  {$ifdef DbgVisualChange}
  DebugLn('TCustomGrid.VisualChange INIT ',DbgSName(Self));
  {$endif}

  UpdateSizes;

  Invalidate;
  {$ifdef DbgVisualChange}
  DebugLn('TCustomGrid.VisualChange END ',DbgSName(Self));
  {$endif}
end;

procedure TCustomGrid.ResetSizes;
begin
  //DebugLn('TCustomGrid.VisualChange ',DbgSName(Self));
  if (FCols=nil) or ([csLoading,csDestroying]*ComponentState<>[])
  or (not HandleAllocated) then
    exit; // not yet initialized or already destroyed

  UpdateCachedSizes;
  CheckNewCachedSizes(FGCache);
  CacheVisibleGrid;
  {$Ifdef DbgVisualChange}
  DebugLn('TCustomGrid.ResetSizes %s Width=%d Height=%d',[DbgSName(Self),Width,Height]);
  DebugLn('  Cache: ClientWidth=%d ClientHeight=%d GWidth=%d GHeight=%d',
    [FGCAche.ClientWidth, FGCache.ClientHeight,FGCache.GridWidth, FGCache.GridHeight]);
  DebugLn('  Reald: ClientWidth=%d ClientHeight=%d',[ClientWidth, ClientHeight]);
  DebugLn('  MaxTopLeft',dbgs(FGCache.MaxTopLeft));
  {$Endif}
end;

procedure TCustomGrid.CreateParams(var Params: TCreateParams);
const
  ClassStylesOff = CS_VREDRAW or CS_HREDRAW;
begin
  inherited CreateParams(Params);
  with Params do begin
    WindowClass.Style := WindowClass.Style and DWORD(not ClassStylesOff);
    Style := Style or WS_VSCROLL or WS_HSCROLL or WS_CLIPCHILDREN;
  end;
end;

procedure TCustomGrid.Click;
begin
  {$IFDEF dbgGrid} DebugLn('FIgnoreClick=', dbgs(FIgnoreClick)); {$ENDIF}
  if not FIgnoreClick then
    inherited Click;
end;

procedure TCustomGrid.ScrollBarRange(Which: Integer; aRange,aPage,aPos: Integer);
var
  ScrollInfo: TScrollInfo;
begin
  if HandleAllocated then begin
    {$Ifdef DbgScroll}
    DebugLn('ScrollbarRange: Which=%s Range=%d Page=%d Pos=%d',
      [SbToStr(Which),aRange,aPage,aPos]);
    {$endif}
    FillChar(ScrollInfo, SizeOf(ScrollInfo), 0);
    ScrollInfo.cbSize := SizeOf(ScrollInfo);
    ScrollInfo.fMask := SIF_RANGE or SIF_PAGE or SIF_DISABLENOSCROLL;
    if not (gfPainting in FGridFlags) then
      ScrollInfo.fMask := ScrollInfo.fMask or SIF_POS;
    {$ifdef Unix}
    ScrollInfo.fMask := ScrollInfo.fMask or SIF_UPDATEPOLICY;
    if goThumbTracking in Options then
      ScrollInfo.ntrackPos := SB_POLICY_CONTINUOUS
    else
      ScrollInfo.ntrackPos := SB_POLICY_DISCONTINUOUS;
    {$endif}
    ScrollInfo.nMin := 0;
    ScrollInfo.nMax := aRange;
    ScrollInfo.nPos := aPos;
    if APage<0 then
      APage := 0;
    ScrollInfo.nPage := APage;
    if (Which=SB_HORZ) and UseRightToLeftAlignment then begin
      ScrollInfo.nPos := ScrollInfo.nMax-ScrollInfo.nPage-ScrollInfo.nPos;
      {$Ifdef DbgScroll}
      DebugLn('ScrollbarRange: RTL nPos=%d',[ScrollInfo.nPos]);
      {$endif}
    end;
    SetScrollInfo(Handle, Which, ScrollInfo, True);
  end;
end;

procedure TCustomGrid.ScrollBarPosition(Which, Value: integer);
var
  ScrollInfo: TScrollInfo;
  Vis: Boolean;
begin
  if HandleAllocated then begin
    {$Ifdef DbgScroll}
    DebugLn('ScrollbarPosition: Which=',SbToStr(Which), ' Value= ',IntToStr(Value));
    {$endif}
    Vis := ScrollBarIsVisible(Which);
    FillChar(ScrollInfo, SizeOf(ScrollInfo), 0);
    ScrollInfo.cbSize := SizeOf(ScrollInfo);
    if (Which=SB_HORZ) and Vis and UseRightToLeftAlignment then begin
      ScrollInfo.fMask := SIF_PAGE or SIF_RANGE;
      GetScrollInfo(Handle, SB_HORZ, ScrollInfo);
      Value := (ScrollInfo.nMax-ScrollInfo.nPage)-Value;
      {$Ifdef DbgScroll}
      DebugLn('ScrollbarPosition: Which=',SbToStr(Which), ' RTL Value= ',IntToStr(Value));
      {$endif}
    end;
    ScrollInfo.fMask := SIF_POS;
    ScrollInfo.nPos:= Value;
    SetScrollInfo(Handle, Which, ScrollInfo, Vis);
  end;
end;

function TCustomGrid.ScrollBarIsVisible(Which: Integer): Boolean;
begin
  Result:=false;
  if HandleAllocated then begin
    // Don't use GetScrollbarvisible from the widgetset - it sends WM_PAINT message (Gtk2). Issue #30160
    if Which = SB_VERT then result := (FVSbVisible=1) else
    if Which = SB_HORZ then result := (FHsbVisible=1) else
    if Which = SB_BOTH then result := (FVSbVisible=1) and (FHsbVisible=1);
  end;
end;

procedure TCustomGrid.ScrollBarPage(Which: Integer; aPage: Integer);
var
  ScrollInfo: TScrollInfo;
begin
  if HandleAllocated then begin
    {$Ifdef DbgScroll}
    DebugLn('Scrollbar Page: Which=',SbToStr(Which), ' Avalue=',dbgs(aPage));
    {$endif}
    ScrollInfo.cbSize := SizeOf(ScrollInfo);
    ScrollInfo.fMask := SIF_PAGE;
    ScrollInfo.nPage:= aPage;
    SetScrollInfo(Handle, Which, ScrollInfo, True);
  end;
end;

procedure TCustomGrid.ScrollBarShow(Which: Integer; aValue: boolean);
begin
  if HandleAllocated then begin
    {$Ifdef DbgScroll}
    DebugLn('ScrollbarShow: Which=',SbToStr(Which), ' Avalue=',dbgs(AValue));
    {$endif}
    Include(FGridFlags, gfUpdatingScrollbar);
    try
      ShowScrollBar(Handle,Which,aValue);
    finally
      Exclude(FGridFlags, gfUpdatingScrollbar);
    end;
    if Which in [SB_BOTH, SB_VERT] then FVSbVisible := Ord(AValue);
    if Which in [SB_BOTH, SB_HORZ] then FHSbVisible := Ord(AValue);
  end;
end;

procedure TCustomGrid.ScrollBy(DeltaX, DeltaY: Integer);
var
  ClipArea: TRect;
  ScrollFlags: Integer;
begin
  if (DeltaX=0) and (DeltaY=0) then
    Exit;

  ScrollFlags := SW_INVALIDATE or SW_ERASE;
  if DeltaX<>0 then
  begin
    ClipArea := ClientRect;
    if Flat then
      InflateRect(ClipArea, -1, -1);
    if BiDiMode <> bdRightToLeft then
      Inc(ClipArea.Left, FGCache.FixedWidth)
    else
      Dec(ClipArea.Right, FGCache.FixedWidth);
    ScrollWindowEx(Handle, DeltaX, 0, @ClipArea, @ClipArea, 0, nil, ScrollFlags);
  end;
  if DeltaY<>0 then
  begin
    ClipArea := ClientRect;
    if Flat then
      InflateRect(ClipArea, -1, -1);
    Inc(ClipArea.Top, FGCache.FixedHeight);
    ScrollWindowEx(Handle, 0, DeltaY, @ClipArea, @ClipArea, 0, nil, ScrollFlags);
  end;

  CacheVisibleGrid;
  CalcScrollbarsRange;
end;

function TCustomGrid.ScrollBarAutomatic(Which: TScrollStyle): boolean;
begin
  result:=false;
  if (Which=ssVertical)or(Which=ssHorizontal) then begin
    if Which=ssVertical then Which:=ssAutoVertical
    else Which:=ssAutoHorizontal;
    Result:= FScrollBars in [Which, ssAutoBoth];
  end;
end;

// Returns a rectagle corresponding to a physical cell[aCol,aRow]
function TCustomGrid.CellRect(ACol, ARow: Integer): TRect;
var
  ok: Boolean;
begin
  ok := ColRowToOffset(True, True, ACol, Result.Left, Result.Right);
  if ok then begin
    ok := ColRowToOffSet(False, True, ARow, Result.Top, Result.Bottom);
    if ok and (goColSpanning in Options) then
      CalcCellExtent(ACol, ARow, Result);
  end;

  if not ok then
    Result:=Rect(0,0,0,0);
end;

// The visible grid Depends on  TopLeft and ClientWidht,ClientHeight,
// Col/Row Count, So it Should be called inmediately after changing
// those properties.
function TCustomGrid.GetVisibleGrid: TRect;
var
  W, H: Integer;
begin

  if (FTopLeft.X<0)or(FTopLeft.y<0)or(csLoading in ComponentState) then begin
    Result := Rect(0,0,-1,-1);
    FGCache.MaxClientXY := point(0,0);
    Exit;
  end;
  // visible TopLeft Cell
  Result.TopLeft:=fTopLeft;
  Result.BottomRight:=Result.TopLeft;

  // Left Margin of next visible Column and Rightmost visible cell
  if ColCount>FixedCols then begin
    W:=GetColWidths(Result.Left) + FGCache.FixedWidth;
    if GetSmoothScroll(SB_Horz) then
      W := W - FGCache.TLColOff;
    while (Result.Right<ColCount-1)and(W<FGCache.ClientWidth) do begin
      Inc(Result.Right);
      W:=W+GetColWidths(Result.Right);
    end;
    FGCache.MaxClientXY.X := W;
  end else begin
    FGCache.MaxClientXY.X := FGCache.FixedWidth;
    Result.Right := Result.Left - 1; // no visible cells here
  end;

  // Top Margin of next visible Row and Bottom most visible cell
  if RowCount>FixedRows then begin
    H:=GetRowheights(Result.Top) + FGCache.FixedHeight;
    if GetSmoothScroll(SB_Vert) then
      H := H - FGCache.TLRowOff;
    while (Result.Bottom<RowCount-1)and(H<FGCache.ClientHeight) do begin
      Inc(Result.Bottom);
      H:=H+GetRowHeights(Result.Bottom);
    end;
    FGCache.MaxClientXY.Y := H;
  end else begin
    FGCache.MaxClientXY.Y := FGCache.FixedHeight;
    Result.Bottom := Result.Top - 1; // no visible cells here
  end;
end;

{ Scroll the grid until cell[aCol,aRow] is shown }
function TCustomGrid.ScrollToCell(const aCol, aRow: Integer;
  const ForceFullyVisible: Boolean): Boolean;
var
  RNew, RNewStored: TRect;
  OldTopLeft:TPoint;
  Xinc,YInc: Integer;
  CHeight,CWidth: Integer;
  TLRowOffChanged, TLColOffChanged: Boolean;
begin
  OldTopLeft:=fTopLeft;
  TLRowOffChanged:=False;
  TLColOffChanged:=False;

  CHeight := FGCache.ClientHeight + GetBorderWidth;
  CWidth  := FGCache.ClientWidth  + GetBorderWidth;

  {$IFDEF dbgGridScroll}
  DebugLn('aCol=%d aRow=%d FixHeight=%d CHeight=%d FixWidth=%d CWidth=%d',
          [aCol,aRow,FGCache.FixedHeight,CHeight, FGCache.FixedWidth, CWidth]);
  {$Endif}

  while IsColumnIndexValid(fTopLeft.x) and
        IsRowIndexValid(fTopLeft.y) do
  begin
    RNew:=CellRect(aCol,aRow);
    if UseRightToLeftAlignment then begin
      XInc := RNew.Right;
      RNew.Right := FlipX(RNew.Left)+1;
      RNew.Left := FlipX(XInc)+1;
    end;
    RNewStored := RNew;

    Xinc := 0;
    if RNew.Right <= FGCache.FixedWidth+GetBorderWidth then
      Xinc := -1              // hidden at the left of fixedwidth line
    else
    if (RNew.Left > FGCache.FixedWidth+GetBorderWidth) and (RNew.Left >= CWidth) and not GetSmoothScroll(SB_Horz) then
      Xinc := 1               // hidden at the right of clientwidth line
    else
    if (RNew.Left > FGCache.FixedWidth+GetBorderWidth) and
       (CWidth < RNew.Right) and
       (not (goDontScrollPartCell in Options) or ForceFullyVisible) then
    begin  // hidden / partially visible at the right
      if not GetSmoothScroll(SB_Horz) then
        Xinc := 1
      else
      begin
        Inc(FGCache.TLColOff, RNew.Right-CWidth); // support smooth scroll
        TLColOffChanged := True;
      end;
    end;

    Yinc := 0;
    if RNew.Bottom <= FGCache.FixedHeight+GetBorderWidth then
      Yinc := -1              // hidden at the top of fixedheight line
    else
    if (RNew.Top > FGCache.FixedHeight+GetBorderWidth) and (RNew.Top >= CHeight) and not GetSmoothScroll(SB_Vert) then
      YInc := 1               // hidden at the bottom of clientheight line
    else
    if (RNew.Top > FGCache.FixedHeight+GetBorderWidth) and
       (CHeight < RNew.Bottom) and
       (not (goDontScrollPartCell in Options) or ForceFullyVisible) then
    begin  // hidden / partially visible at bottom
      if not GetSmoothScroll(SB_Vert) then
        Yinc := 1
      else
      begin
        Inc(FGCache.TLRowOff, RNew.Bottom-CHeight); // support smooth scroll
        TLRowOffChanged := True;
      end;
    end;

    {$IFDEF dbgGridScroll}
    with FTopLeft,RNew,FGCache do
    DebugLn('  TL.C=%d TL.R=%d RNew:L=%d T=%d R=%d B=%d Xinc=%d YInc=%d ColOff=%d RowOff=%d',
      [X,Y,Left,Top,Right,Bottom,XInc,YInc,TLColOff,TLRowOff]);
    {$ENDIF}

    if ((XInc=0)and(YInc=0)) or // the cell is already visible
       ((FTopLeft.X=aCol)and(FTopLeft.Y=aRow)) or // the cell is visible by definition
       not IsColumnIndexValid(FTopLeft.X+XInc) or
       not IsRowIndexValid(FTopLeft.Y+YInc)
    then
      Break;
    Inc(FTopLeft.x, XInc);
    if XInc<>0 then
      FGCache.TLColOff := 0; // cancel col-offset for next calcs
    Inc(FTopLeft.y, YInc);
    if YInc<>0 then
      FGCache.TLRowOff := 0; // cancel row-offset for next calcs
  end;

  // fix offsets
  while (FTopLeft.x < ColCount-1) and (FGCache.TLColOff > ColWidths[FTopLeft.x]) do
  begin
    Dec(FGCache.TLColOff, ColWidths[FTopLeft.x]);
    Inc(FTopLeft.x);
    TLColOffChanged := True;
  end;
  while (FTopLeft.y < RowCount-1) and (FGCache.TLRowOff > RowHeights[FTopLeft.y]) do
  begin
    Dec(FGCache.TLRowOff, RowHeights[FTopLeft.y]);
    Inc(FTopLeft.y);
    TLRowOffChanged := True;
  end;

  Result:=not PointIgual(OldTopleft,FTopLeft)
    or TLColOffChanged or TLRowOffChanged;

  BeginUpdate;
  try
    if Result then begin
      if not PointIgual(OldTopleft,FTopLeft) then
        doTopleftChange(False)
      else
        VisualChange;
    end;
    if not (goDontScrollPartCell in Options) or ForceFullyVisible then
    begin
      RNew := RNewStored;
      if ResetOffset(
        not GetSmoothScroll(SB_Horz) or
        (RNew.Left < FGCache.FixedWidth+GetBorderWidth), // partially visible on left
        (not GetSmoothScroll(SB_Vert) or
        (RNew.Top < FGCache.FixedHeight+GetBorderWidth))) // partially visible on top
      then
        Result := True;
    end;
  finally
    EndUpdate(Result);
  end;
end;

{Returns a valid TopLeft from a proposed TopLeft[DCol,DRow] which are
 relative or absolute coordinates }
function TCustomGrid.ScrollGrid(Relative: Boolean; DCol, DRow: Integer): TPoint;
begin
  Result:=FTopLeft;
  if not Relative then begin
    DCol:=DCol-Result.x;
    DRow:=DRow-Result.y;
  end;

  if DCol<>0 then begin
    if DCol+Result.x<FFixedCols then DCol:=Result.x-FFixedCols else
    if DCol+Result.x>ColCount-1 then DCol:=ColCount-1-Result.x;
  end;
  if DRow<>0 then begin
    if DRow+Result.y<FFixedRows then DRow:=Result.y-FFixedRows else
    if DRow+Result.y>RowCount-1 then DRow:=RowCount-1-Result.y;
  end;

  Inc(Result.x, DCol);
  Inc(Result.y, DRow);

  Result.x := Max(FixedCols, Min(Result.x, FGCache.MaxTopLeft.x));
  Result.y := Max(FixedRows, Min(Result.y, FGCache.MaxTopLeft.y));
end;

procedure TCustomGrid.TopLeftChanged;
begin
  if Assigned(OnTopLeftChanged) and not (csDesigning in ComponentState) then
    OnTopLeftChanged(Self);
end;

procedure TCustomGrid.HeaderClick(IsColumn: Boolean; index: Integer);
var
  ColOfs: Integer;
begin
  if IsColumn and FColumnClickSorts then begin
    // Determine the sort order.
    if index = FSortColumn then begin
      case FSortOrder of        // Same column clicked again -> invert the order.
        soAscending:  FSortOrder:=soDescending;
        soDescending: FSortOrder:=soAscending;
      end;
    end
    else
      FSortOrder := soAscending;          // Ascending order to start with.

    FSortColumn := index;
    Sort(True, index, FFixedRows, RowCount-1);
  end;
end;

procedure TCustomGrid.HeaderSized(IsColumn: Boolean; index: Integer);
begin
end;

procedure TCustomGrid.ColRowMoved(IsColumn: Boolean; FromIndex,ToIndex: Integer);
begin
end;

// Notification to inform derived grids to exchange their actual rows data
procedure TCustomGrid.ColRowExchanged(IsColumn: Boolean; index, WithIndex: Integer);
begin
end;

procedure TCustomGrid.ColRowInserted(IsColumn: boolean; index: integer);
begin
end;

procedure TCustomGrid.DrawFocusRect(aCol, aRow: Integer; ARect: TRect);
begin
end;

procedure TCustomGrid.AutoAdjustColumn(aCol: Integer);
begin
end;

procedure TCustomGrid.SizeChanged(OldColCount, OldRowCount: Integer);
begin
end;

procedure TCustomGrid.ColRowDeleted(IsColumn: Boolean; index: Integer);
begin
end;

function TCustomGrid.CanEditShow: Boolean;
begin
  Result := EditingAllowed(FCol) and not (csDesigning in ComponentState)
            and CanFocus;
end;

procedure TCustomGrid.Paint;
{$ifdef DbgPaint}
var
  R: TRect;
{$endif}
begin
  //
  {$ifdef DbgPaint}
  R := Canvas.ClipRect;
  DebugLn('TCustomGrid.Paint %s Row=%d Clip=%s',[DbgSName(Self),Row,Dbgs(R)]);
  {$endif}
  if ([gfVisualChange,gfClientRectChange]*fGridFlags<>[]) or
     (ClientWidth<>FGCache.ClientWidth) or
     (ClientHeight<>FGCache.ClientHeight) then begin
    {$ifdef DbgVisualChange}
    DebugLnEnter('Resetting Sizes in Paint INIT');
    {$endif}
    FGridFlags := FGridFlags + [gfPainting];
    ResetSizes;
    FGridFlags := FGridFlags - [gfVisualChange, gfPainting, gfClientRectChange];
    {$ifdef DbgVisualChange}
    DebugLnExit('Resetting Sizes in Paint DONE');
    {$endif}
  end;
  inherited Paint;
  if FUpdateCount=0 then begin
    DrawEdges;
    DrawAllRows;
    DrawColRowMoving;
    DrawBorder;
  end;
end;

procedure TCustomGrid.PickListItemSelected(Sender: TObject);
begin
  if Assigned(OnPickListSelect) then
    OnPickListSelect(Self);
end;

procedure TCustomGrid.PrepareCanvas(aCol, aRow: Integer; aState: TGridDrawState);
  function GetNotSelectedColor: TColor;
  begin
    Result := GetColumnColor(aCol, gdFixed in AState);
    if (gdFixed in AState) and (gdHot in aState) then
      Result := FFixedHotColor;
    if not (gdFixed in AState) and (FAlternateColor<>Result) then  begin
      if Result=Color then begin
        // column color = grid Color, Allow override color
        // 1. default color after fixed rows
        // 2. always use absolute alternate color based in odd & even row
        if (FAltColorStartNormal and Odd(ARow-FixedRows)) {(1)} or
           (not FAltColorStartNormal and Odd(ARow)) {(2)} then
            Result := FAlternateColor;
      end;
    end;
    if (gdRowHighlight in aState) and not (gdFixed in AState) then
      Result := ColorToRGB(Result) xor $1F1F1F
  end;
var
  AColor: TColor;
  CurrentTextStyle: TTextStyle;
  IsSelected: boolean;
  gc: TGridColumn;
begin
  if (gdFixed in aState) or DefaultDrawing then begin
    Canvas.Pen.Mode := pmCopy;
    GetSelectedState(aState, IsSelected);
    if IsSelected then begin
      if FEditorMode and (aCol = Self.Col)
      and (((FEditor=FStringEditor) and (FStringEditor.BorderStyle=bsNone))
         or (FEditor=FButtonStringEditor))
      then
        Canvas.Brush.Color := FEditor.Color
      else if FEditorMode and (aCol = Self.Col) and (FEditor=FPicklistEditor) then
        Canvas.Brush.Color := GetNotSelectedColor
      else
        Canvas.Brush.Color := SelectedColor;
      SetCanvasFont(GetColumnFont(aCol, False));
      if not IsCellButtonColumn(point(aCol,aRow)) then
        Canvas.Font.Color := clHighlightText;
      FLastFont:=nil;
    end else begin
      Canvas.Brush.Color := GetNotSelectedColor;
      SetCanvasFont(GetColumnFont(aCol, ((gdFixed in aState) and (aRow < FFixedRows))));
    end;
    if not Enabled and (FDisabledFontColor<>clNone) then
      Canvas.Font.Color := FDisabledFontColor;
    CurrentTextStyle := DefaultTextStyle;
    CurrentTextStyle.Alignment := BidiFlipAlignment(GetColumnAlignment(aCol, gdFixed in AState), UseRightToLeftAlignment);
    CurrentTextStyle.Layout := GetColumnLayout(aCol, gdFixed in AState);
    CurrentTextStyle.ShowPrefix := ((gdFixed in aState) and (aRow < FFixedRows)) and GetTitleShowPrefix(aCol);
    CurrentTextStyle.RightToLeft := UseRightToLeftReading;
    CurrentTextStyle.EndEllipsis := (goCellEllipsis in Options);
    gc := ColumnFromGridColumn(aCol);
    CurrentTextStyle.SingleLine := (gc = nil) or (not gc.Title.MultiLine);
    Canvas.TextStyle := CurrentTextStyle;
  end else begin
    CurrentTextStyle := DefaultTextStyle;
    CurrentTextStyle.Alignment := BidiFlipAlignment(CurrentTextStyle.Alignment, UseRightToLeftAlignment);
    CurrentTextStyle.RightToLeft := UseRightToLeftAlignment;
    Canvas.TextStyle := CurrentTextStyle;
    Canvas.Brush.Color := clWindow;
    Canvas.Font.Color := clWindowText;
  end;

  DoPrepareCanvas(aCol, aRow, aState);
end;

procedure TCustomGrid.PrepareCellHints(ACol, ARow: Integer);
begin
end;

procedure TCustomGrid.ResetDefaultColWidths;
var
  i: Integer;
begin
  if not AutoFillColumns then begin
    for i:=0 to ColCount-1 do
      FCols[i] := -1;
    VisualChange;
  end;
end;

procedure TCustomGrid.UnprepareCellHints;
begin
end;

procedure TCustomGrid.ResetEditor;
begin
  EditorGetValue(True);
  if EditorAlwaysShown then
    EditorShow(True);
end;

// Reset the last Row or Col movement
procedure TCustomGrid.ResetLastMove;
begin
  FMoveLast:=Point(-1,-1);
end;

procedure TCustomGrid.ResetHotCell;
begin
  with FGCache do begin
    if HotCellPainted and IsColumnIndexValid(HotCell.x) and IsRowIndexValid(HotCell.y) then
      InvalidateCell(HotCell.X, HotCell.Y);
    HotCell := Point(-1,-1);
    HotCellPainted := False;
    HotGridZone := gzInvalid;
  end;
end;

procedure TCustomGrid.ResetPushedCell(ResetColRow: boolean=True);
begin
  with FGCache do begin
    if ClickCellPushed then
      InvalidateCell(PushedCell.X, PushedCell.Y);
    if ResetColRow then
      PushedCell := Point(-1,-1);
    ClickCellPushed := False;
  end;
end;

function TCustomGrid.ResetOffset(chkCol, ChkRow: Boolean): Boolean;
begin
  if ChkCol then ChkCol:=FGCache.TLColOff<>0;
  if ChkCol then FGCache.TlColOff:=0;
  if ChkRow then ChkRow:=FGCache.TLRowOff<>0;
  if ChkRow then FGCache.TlRowOff:=0;
  Result := ChkRow or ChkCol;
  if Result then
  begin
    CacheVisibleGrid;
    VisualChange;
  end;
end;

procedure TCustomGrid.ResizeColumn(aCol, aWidth: Integer);
begin
  if aWidth<0 then
    aWidth:=0;
  ColWidths[aCol] := aWidth;
end;

procedure TCustomGrid.ResizeRow(aRow, aHeight: Integer);
begin
  if aHeight<0 then
    aHeight:=0;
  RowHeights[aRow] := aHeight;
end;

procedure TCustomGrid.HeaderSizing(const IsColumn: boolean; const AIndex,
  ASize: Integer);
begin
end;

procedure TCustomGrid.ShowCellHintWindow(APoint: TPoint);
var
  cell: TPoint;
  txt1, txt2, txt, AppHint: String;
  w: Integer;
  gds: TGridDrawState;

  procedure AddToHint(var AHint: String; const ANew: String);
  begin
    if ANew = '' then
      exit;
    if AHint = '' then AHint := ANew else AHint := AHint + LineEnding + ANew;
  end;

begin
  if not ShowHint then
    exit;

  cell := MouseToCell(APoint);
  if (cell.x = -1) or (cell.y = -1) then
    exit;

  txt1 := '';          // Hint returned by OnGetCellHint
  txt2 := '';          // Hint returned by GetTruncCellHintText
  AppHint := '';       // Hint to be displayed in Statusbar
  txt := '';           // Hint to be displayed as popup
  PrepareCellHints(cell.x, cell.y); // in DBGrid, set the active record to cell.y
  try
    if (goCellHints in Options) and (FCellHintPriority <> chpTruncOnly) then
      txt1 := GetCellHintText(cell.x, cell.y);
    if (goTruncCellHints in Options) then begin
      txt2 := GetTruncCellHintText(cell.x, cell.y);
      gds := GetGridDrawState(cell.x, cell.y);
      PrepareCanvas(cell.x, cell.y, gds);
      w := Canvas.TextWidth(txt2) + varCellPadding*2;
      if w < ColWidths[cell.x] then
        txt2 := '';
    end;
  finally
    UnprepareCellHints;
  end;

  case FCellHintPriority of
    chpAll:
      begin
        AddToHint(txt, GetShortHint(FSavedHint));
        AddToHint(txt, GetShortHint(txt1));
        AddToHint(txt, txt2);
        AddToHint(AppHint, GetLongHint(FSavedHint));
        AddToHint(AppHint, GetLongHint(txt1));
      end;
    chpAllNoDefault:
      begin
        AddToHint(txt, GetShortHint(txt1));
        AddToHint(txt, txt2);
        AddToHint(AppHint, GetLongHint(txt1));
      end;
    chpTruncOnly:
      begin
        AddToHint(txt, txt2);
        AppHint := txt;
        if Pos('|', AppHint) = 0 then
          AppHint := AppHint + '|';
      end;
  end;

  (*
  if (txt = '') and (FSavedHint <> '') then
    txt := FSavedHint;
  if (AppHint = '') then AppHint := FSavedhint;
    *)

  if not EditorMode and not (csDesigning in ComponentState) then begin
    Hint := txt;
    //set Application.Hint as well (issue #0026957)
    Application.Hint := GetLongHint(AppHint);
    Application.ActivateHint(APoint, true);
  end else
    HideCellHintWindow;
end;

procedure TCustomGrid.HideCellHintWindow;
begin
  Hint := FSavedHint;
  Application.CancelHint;
end;

procedure TCustomGrid.StartPushCell;
begin
  fGridState := gsButtonColumnClicking;
  DoPushCell;
end;

function TCustomGrid.TitleFontIsStored: Boolean;
begin
  Result := not FTitleFontIsDefault;
end;

function TCustomGrid.SelectCell(ACol, ARow: Integer): Boolean;
begin
  Result := (ColWidths[aCol] > 0) and (RowHeights[aRow] > 0);
end;

procedure TCustomGrid.SetCanvasFont(aFont: TFont);
begin
  if (aFont<>FLastFont) or
    not Canvas.Font.IsEqual(aFont) then
  begin
    Canvas.Font := aFont;
    FLastFont := AFont;
  end;
end;

procedure TCustomGrid.SetColor(Value: TColor);
begin
  if AlternateColor = Color then
    FAlternateColor := Value;
  inherited SetColor(Value);
end;

procedure TCustomGrid.SetColRow(const ACol, ARow: Integer; withEvents: boolean);
begin
  if withEvents then begin
    MoveExtend(false, aCol, aRow, true);
    Click;
  end else begin
    FCol := ACol;
    FRow := ARow;
    UpdateSelectionRange;
  end;
end;

procedure TCustomGrid.SetCursor(AValue: TCursor);
begin
  inherited;
  ChangeCursor(AValue);
end;

procedure TCustomGrid.DrawBorder;
var
  R: TRect;
begin
  if InternalNeedBorder then begin
    R := Rect(0,0,ClientWidth-1, Clientheight-1);
    // The following line is a simple workaround for a more complex problem
    // caused by Canvas.SaveHandleState and Canvas.RestoreHandleState in DoDrawCell
    // see the notes in the related bug report #34890
    Canvas.Pen.Color := fBorderColor + 1;
    Canvas.Pen.Color := fBorderColor;
    Canvas.Pen.Width := 1;
    Canvas.MoveTo(0,0);
    Canvas.LineTo(0,R.Bottom);
    Canvas.LineTo(R.Right, R.Bottom);
    Canvas.LineTo(R.Right, 0);
    Canvas.LineTo(0,0);
  end;
end;

procedure TCustomGrid.DrawColRowMoving;
{$ifdef AlternativeMoveIndicator}
var
  x, y, dx, dy: Integer;
  R: TRect;
{$endif}
begin
  if (FGridState=gsColMoving)and(fMoveLast.x>=0) then begin
    {$ifdef AlternativeMoveIndicator}
    dx := 4;
    dy := 4;
    Canvas.pen.Width := 1;
    Canvas.Pen.Color := clBlack;
    Canvas.Brush.Color := clWhite;
    R := CellRect(FMoveLast.X, 0);
    Y := R.Top + (R.Bottom-R.Top) div 2;
    X := R.Left - 2*dx;
    Canvas.Polygon([Point(x,y+dy),point(x,y-dy),point(x+dx,y), point(x,y+dy)]);
    X := R.Left + 2*dx;
    Canvas.Polygon([Point(x,y+dy),point(x,y-dy),point(x-dx,y), point(x,y+dy)]);
    {$else}
    Canvas.Pen.Width:=3;
    Canvas.Pen.Color:=FColRowDragIndicatorColor;
    Canvas.MoveTo(fMoveLast.y, 0);
    Canvas.Lineto(fMovelast.y, FGCache.MaxClientXY.Y);
    Canvas.Pen.Width:=1;
    {$endif}
  end else
  if (FGridState=gsRowMoving)and(FMoveLast.y>=0) then begin
    {$ifdef AlternativeMoveIndicator}
    dx := 4;
    dy := 4;
    Canvas.pen.Width := 1;
    Canvas.Pen.Color := clBlack;
    Canvas.Brush.Color := clWhite;
    R := CellRect(0, FMoveLast.Y);
    X := R.Left + (R.Right-R.Left) div 2;
    Y := R.Top - 2*dy;
    Canvas.Polygon([Point(x-dx,y),point(x+dx,y),point(x,y+dy), point(x-dx,y)]);
    Y := R.Top + 2*dy;
    Canvas.Polygon([Point(x-dx,y),point(x+dx,y),point(x,y-dy), point(x-dx,y)]);
    {$else}
    Canvas.Pen.Width:=3;
    Canvas.Pen.Color:=FColRowDragIndicatorColor;
    if UseRightToLeftAlignment then begin
      Canvas.MoveTo(FGCache.ClientRect.Right, FMoveLast.X);
      Canvas.LineTo(FlipX(FGCache.MaxClientXY.X), FMoveLast.X);
    end
    else begin
      Canvas.MoveTo(0, FMoveLast.X);
      Canvas.LineTo(FGCache.MaxClientXY.X, FMoveLast.X);
    end;
    Canvas.Pen.Width:=1;
    {$endif}
  end;
end;

procedure TCustomGrid.DrawColumnText(aCol, aRow: Integer; aRect: TRect;
  aState: TGridDrawState);
begin
  DrawColumnTitleImage(aRect, aCol);
  DrawCellText(aCol,aRow,aRect,aState,GetColumnTitle(aCol))
end;

procedure TCustomGrid.DrawColumnTitleImage(
  var ARect: TRect; AColumnIndex: Integer);
var
  w, h, rw, rh, ImgIndex, ImgListWidth: Integer;
  p: TPoint;
  r: TRect;
  ImgLayout: TButtonLayout;
  ImgList: TCustomImageList;
  ImgRes: TScaledImageListResolution;
  s: TSize;
  Details: TThemedElementDetails;
  NativeSortGlyphs: Boolean;
begin
  if FSortColumn = AColumnIndex then
  begin
    GetSortTitleImageInfo(AColumnIndex, ImgList, ImgIndex, ImgListWidth, NativeSortGlyphs);
    if NativeSortGlyphs then// draw native sort buttons
    begin
      case FSortOrder of
        soAscending: Details := ThemeServices.GetElementDetails(thHeaderSortArrowSortedUp);
        soDescending: Details := ThemeServices.GetElementDetails(thHeaderSortArrowSortedDown);
      end;

      s := ThemeServices.GetDetailSize(Details);
    end else
      s := Size(-1, -1);
    if s.cx>0 then // theme services support sorted arrows
    begin
      w := Scale96ToFont(s.cx);
      h := Scale96ToFont(s.cy);

      if IsRightToLeft then begin
        r.Left := ARect.Left + DEFIMAGEPADDING;
        Inc(ARect.Left, w + DEFIMAGEPADDING);
      end else begin
        Dec(ARect.Right, w + DEFIMAGEPADDING);
        r.Left := ARect.Right - DEFIMAGEPADDING;
      end;
      r.Right := r.Left + w;
      r.Top := ARect.Top + (ARect.Bottom - ARect.Top - h) div 2;
      r.Bottom := r.Top + h;

      ThemeServices.DrawElement(Canvas.Handle, Details, r, nil);
    end else
    begin
      ImgRes := ImgList.ResolutionForPPI[ImgListWidth, Font.PixelsPerInch, GetCanvasScaleFactor];
      w := ImgRes.Width;
      h := ImgRes.Height;

      if IsRightToLeft then begin
        P.X := ARect.Left + DEFIMAGEPADDING;
        Inc(ARect.Left, w + DEFIMAGEPADDING);
      end else begin
        Dec(ARect.Right, w + DEFIMAGEPADDING);
        p.X := ARect.Right - DEFIMAGEPADDING;
      end;
      p.Y := ARect.Top + (ARect.Bottom - ARect.Top - h) div 2;

      ImgRes.Draw(Canvas, p.X, p.Y, ImgIndex);
    end;
  end;

  if FTitleImageList<>nil then
  begin
    GetTitleImageInfo(AColumnIndex, ImgIndex, ImgLayout);
    if ImgIndex>=0 then
    begin
      ImgRes := FTitleImageList.ResolutionForPPI[FTitleImageListWidth, Font.PixelsPerInch, GetCanvasScaleFactor];
      w := ImgRes.Width;
      h := ImgRes.Height;
      rw := ARect.Right - ARect.Left - DEFIMAGEPADDING * 2;
      rh := ARect.Bottom - ARect.Top - DEFIMAGEPADDING * 2;

      case ImgLayout of
        blGlyphRight, blGlyphLeft:
          p.Y := ARect.Top + (rh - h) div 2 + DEFIMAGEPADDING;
        blGlyphTop, blGlyphBottom:
          p.X := ARect.Left + (rw - w) div 2 + DEFIMAGEPADDING;
      end;
      case ImgLayout of
        blGlyphRight: begin
          Dec(ARect.Right, w + DEFIMAGEPADDING * 2);
          p.X := ARect.Right + DEFIMAGEPADDING;
        end;
        blGlyphLeft: begin
          p.X := ARect.Left + DEFIMAGEPADDING;
          Inc(ARect.Left, w + DEFIMAGEPADDING * 2);
        end;
        blGlyphTop: begin
          p.Y := ARect.Top + DEFIMAGEPADDING;
          Inc(ARect.Top, w + DEFIMAGEPADDING * 2);
        end;
        blGlyphBottom: begin
          Dec(ARect.Bottom, w + DEFIMAGEPADDING * 2);
          p.Y := ARect.Bottom + DEFIMAGEPADDING;
        end;
      end;

      ImgRes.Draw(Canvas, p.X, p.Y, ImgIndex);
    end;
  end;
end;

procedure TCustomGrid.DrawCell(aCol, aRow: Integer; aRect: TRect;
  aState: TGridDrawState);
begin
  PrepareCanvas(aCol, aRow, aState);
  DrawFillRect(Canvas, aRect);
  DrawCellGrid(aCol,aRow,aRect,aState);
end;

procedure TCustomGrid.DrawAllRows;
var
  i: Integer;
begin
  // Draw Rows
  with FGCache.VisibleGrid do
    for i:=Top to Bottom do
      DrawRow(i);
  // Draw Fixed Rows
  for i:=0 to FFixedRows-1 do
    DrawRow(i);
end;

procedure TCustomGrid.DrawFillRect(aCanvas: TCanvas; R: TRect);
begin
  if UseRightToLeftAlignment then
    OffsetRect(R, 1, 0);
  aCanvas.FillRect(R);
end;

function VerticalIntersect(const aRect,bRect: TRect): boolean;
begin
  result := (aRect.Top < bRect.Bottom) and (aRect.Bottom > bRect.Top);
end;

function HorizontalIntersect(const aRect,bRect: TRect): boolean;
begin
  result := (aRect.Left < bRect.Right) and (aRect.Right > bRect.Left);
end;

procedure TCustomGrid.DrawRow(aRow: Integer);
var
  gds: TGridDrawState;
  aCol, exCol, orgTop, orgBottom: Integer;
  Rs, colSpanning: Boolean;
  R: TRect;
  ClipArea: Trect;

  procedure DoDrawCell;
  begin
    with FGCache do begin
      if (aCol=HotCell.x) and (aRow=HotCell.y) and not IsPushCellActive() then begin
        Include(gds, gdHot);
        HotCellPainted := True;
      end;
      if ClickCellPushed and (aCol=PushedCell.x) and (aRow=PushedCell.y) then begin
        Include(gds, gdPushed);
      end;
    end;

    Canvas.SaveHandleState;
    try
      InterSectClipRect(Canvas.Handle, R.Left, R.Top, R.Right, R.Bottom);
      DrawCell(aCol, aRow, R, gds);
    finally
      Canvas.RestoreHandleState;
    end;
  end;
begin

  // Upper and Lower bounds for this row
  ColRowToOffSet(False, True, aRow, R.Top, R.Bottom);
  orgTop := R.Top;
  orgBottom := R.Bottom;
  // is this row within the ClipRect?
  ClipArea := Canvas.ClipRect;
  if (R.Top>=R.Bottom) or not VerticalIntersect(R, ClipArea) then begin
    {$IFDEF DbgVisualChange}
    DebugLn('Drawrow: Skipped row: ', IntToStr(aRow));
    {$ENDIF}
    exit;
  end;

  colSpanning := (goColSpanning in Options);

  // Draw columns in this row
  with FGCache.VisibleGrid do begin

    aCol := left;
    while aCol<=Right do begin
      ColRowToOffset(True, True, aCol, R.Left, R.Right);
      if (R.Left<R.Right) and HorizontalIntersect(R, ClipArea) then begin

        if colSpanning then
          CellExtent(aCol, aRow, R, exCol);

        gds := GetGridDrawState(ACol, ARow);
        DoDrawCell;

        if colSpanning then begin
          aCol := exCol;
          R.Top    := orgTop;
          R.Bottom := orgBottom;
        end;
      end;
      inc(aCol);
    end;

    Rs := (goRowSelect in Options);
    // Draw the focus Rect
    if FFocusRectVisible and (ARow=FRow) and
       ((Rs and (ARow>=Top) and (ARow<=Bottom)) or IsCellVisible(FCol,ARow))
    then begin
      if EditorMode then begin
      //if EditorAlwaysShown and (FEditor<>nil) and FEditor.Visible then begin
        //DebugLn('No Draw Focus Rect');
      end else begin
        if Rs then
          CalcFocusRect(R, false) // will be adjusted when calling DrawFocusRect
        else begin
          ColRowToOffset(True, True, FCol, R.Left, R.Right);
          if colSpanning then
            CellExtent(FCol, aRow, R, exCol);
        end;
        // is this column within the ClipRect?
        if HorizontalIntersect(R, ClipArea) then
          DrawFocusRect(FCol,FRow, R);
      end;
    end;

  end;


  // Draw Fixed Columns
  aCol := 0;
  while aCol<=FFixedCols-1 do begin
    gds:=[gdFixed];
    ColRowToOffset(True, True, aCol, R.Left, R.Right);
    // is this column within the ClipRect?
    if (R.Left<R.Right) and HorizontalIntersect(R, ClipArea) then begin
      if colSpanning then
        CellExtent(aCol, aRow, R, exCol);
      DoDrawCell;
      if colSpanning then begin
        aCol := exCol;
        R.Top    := orgTop;
        R.Bottom := orgBottom;
      end;
    end;
    inc(aCol);
  end;
end;

procedure TCustomGrid.EditButtonClicked(Sender: TObject);
begin
  if Assigned(OnEditButtonClick) or Assigned(OnButtonClick) then begin
    if Sender=FButtonEditor then
      DoEditButtonClick(FButtonEditor.Col, FButtonEditor.Row)
    else
      DoEditButtonClick(FCol, FRow);
  end;
end;

procedure TCustomGrid.DrawEdges;
var
  P:  TPoint;
  Cr: TRect;
begin
  P:=FGCache.MaxClientXY;
  Cr:=Bounds(0,0, FGCache.ClientWidth, FGCache.ClientHeight);
  if P.x<Cr.Right then begin
    if UseRightToLeftAlignment then
      Cr.Right:=Cr.Right - P.x
    else
      Cr.Left:=P.x;
    Canvas.Brush.Color:= Color;
    Canvas.FillRect(cr);
    if UseRightToLeftAlignment then begin
      Cr.Left := Cr.Right;
      Cr.Right:=FGCache.ClientWidth;
    end
    else begin
      Cr.Right:=Cr.Left;
      Cr.Left:=0;
    end;
  end;
  if P.y<Cr.Bottom then begin
    Cr.Top:=p.y;
    Canvas.Brush.Color:= Color;
    Canvas.FillRect(cr);
  end;
end;

procedure TCustomGrid.DrawCellGrid(aCol,aRow: Integer; aRect: TRect; aState: TGridDrawState);
var
  dv,dh: Boolean;
  OldCosmeticUsed, OldCosmetic: Boolean;
begin
  OldCosmeticUsed := false;

  with Canvas do begin

    // fixed cells
    if (gdFixed in aState) then begin
      Dv := goFixedVertLine in Options;
      Dh := goFixedHorzLine in Options;
      Pen.Style := psSolid;
      if FGridLineWidth > 0 then
        Pen.Width := 1
      else
        Pen.Width := 0;
      if not FFlat then begin
        if FTitleStyle=tsNative then
          exit
        else
        if FGridLineWidth > 0 then begin
          if gdPushed in aState then
            Pen.Color := cl3DShadow
          else
            Pen.Color := cl3DHilight;
          if UseRightToLeftAlignment then begin
            //the light still on the left but need to new x
            MoveTo(aRect.Right, aRect.Top);
            LineTo(aRect.Left + 1, aRect.Top);
            LineTo(aRect.Left + 1, aRect.Bottom);
          end else begin
            MoveTo(aRect.Right - 1, aRect.Top);
            LineTo(aRect.Left, aRect.Top);
            LineTo(aRect.Left, aRect.Bottom);
          end;
          if FTitleStyle=tsStandard then begin
            // more contrast
            if gdPushed in aState then
              Pen.Color := cl3DHilight
            else
              Pen.Color := cl3DShadow;
            if UseRightToLeftAlignment then begin
              MoveTo(aRect.Left+2, aRect.Bottom-2);
              LineTo(aRect.Right, aRect.Bottom-2);
              LineTo(aRect.Right, aRect.Top);
            end else begin
              MoveTo(aRect.Left+1, aRect.Bottom-2);
              LineTo(aRect.Right-2, aRect.Bottom-2);
              LineTo(aRect.Right-2, aRect.Top);
            end;
          end;
        end;
        Pen.Color := cl3DDKShadow;
      end else begin
        Pen.Color := FFixedGridLineColor;
      end;
    end else begin
      Dv := goVertLine in Options;
      Dh := goHorzLine in Options;
      OldCosmeticUsed := true;
      OldCosmetic := Pen.Cosmetic;
      Pen.Cosmetic := false;
      Pen.Style := fGridLineStyle;
      Pen.Color := fGridLineColor;
      Pen.Width := fGridLineWidth;
    end;

    // non-fixed cells
    if fGridLineWidth > 0 then begin
      if Dh then begin
        MoveTo(aRect.Left, aRect.Bottom - 1);
        LineTo(aRect.Right, aRect.Bottom - 1);
      end;
      if Dv then begin
        if UseRightToLeftAlignment then begin
          MoveTo(aRect.Left, aRect.Top);
          LineTo(aRect.Left, aRect.Bottom);
        end else begin
          MoveTo(aRect.Right - 1, aRect.Top);
          LineTo(aRect.Right - 1, aRect.Bottom);
        end;
      end;
    end;

    if OldCosmeticUsed then
      Pen.Cosmetic := OldCosmetic;
  end; // with canvas,rect
end;

procedure TCustomGrid.DrawTextInCell(aCol, aRow: Integer; aRect: TRect;
  aState: TGridDrawState);
begin
  //
end;

procedure TCustomGrid.DrawThemedCell(aCol, aRow: Integer; aRect: TRect;
  aState: TGridDrawState);
var
  details: TThemedElementDetails;
begin
  if gdPushed in aState then
    Details := ThemeServices.GetElementDetails(thHeaderItemPressed)
  else
  if gdHot in aState then
    Details := ThemeServices.GetElementDetails(thHeaderItemHot)
  else
    Details := ThemeServices.GetElementDetails(thHeaderItemNormal);
  ThemeSErvices.DrawElement(Canvas.Handle, Details, aRect, nil);
end;

procedure TCustomGrid.DrawCellText(aCol, aRow: Integer; aRect: TRect;
  aState: TGridDrawState; aText: String);
begin
  dec(ARect.Right, varCellPadding);
  case Canvas.TextStyle.Alignment of
    Classes.taLeftJustify: Inc(ARect.Left, varCellPadding);
    Classes.taRightJustify: Dec(ARect.Right, 1);
  end;
  case Canvas.TextStyle.Layout of
    tlTop: Inc(ARect.Top, varCellPadding);
    tlBottom: Dec(ARect.Bottom, varCellPadding);
  end;

  if ARect.Right<ARect.Left then
    ARect.Right:=ARect.Left;
  if ARect.Left>ARect.Right then
    ARect.Left:=ARect.Right;
  if ARect.Bottom<ARect.Top then
    ARect.Bottom:=ARect.Top;
  if ARect.Top>ARect.Bottom then
    ARect.Top:=ARect.Bottom;

  if (ARect.Left<>ARect.Right) and (ARect.Top<>ARect.Bottom) then
    Canvas.TextRect(aRect,ARect.Left,ARect.Top, aText);
end;

procedure TCustomGrid.DrawGridCheckboxBitmaps(const aCol,aRow: Integer;
  const aRect: TRect; const aState: TCheckboxState);
const
  arrtb:array[TCheckboxState] of TThemedButton =
    (tbCheckBoxUncheckedNormal, tbCheckBoxCheckedNormal, tbCheckBoxMixedNormal);
var
  ChkBitmap: TBitmap;
  XPos,YPos: Integer;
  Details: TThemedElementDetails;
  PaintRect: TRect;
  CSize: TSize;
  bmpAlign: TAlignment;
  bmpLayout: TTextLayout;
  ChkIL: TCustomImageList;
  ChkII: TImageIndex;
  ChkILRes: TScaledImageListResolution;
begin

  if Columns.Enabled then
  begin
    bmpAlign := GetColumnAlignment(aCol, false);
    bmpLayout := GetColumnLayout(aCol, false);
  end else
  begin
    bmpAlign := taCenter;
    bmpLayout := Canvas.TextStyle.Layout;
  end;

  Details.State := -1;
  ChkIL := nil;
  ChkILRes := TScaledImageListResolution.Create(nil, 0);
  ChkII := -1;
  ChkBitmap := nil;

  GetImageForCheckBox(aCol, aRow, AState, ChkIL, ChkII, ChkBitmap);
  if Assigned(ChkBitmap) then
    CSize := Size(ChkBitmap.Width, ChkBitmap.Height)
  else if (Assigned(ChkIL) and (ChkII>=0)) then
  begin
    ChkILRes := ChkIL.ResolutionForPPI[ChkIL.Width, Font.PixelsPerInch, GetCanvasScaleFactor];
    CSize := ChkILRes.Size;
  end else
  begin
    Details := ThemeServices.GetElementDetails(arrtb[AState]);
    CSize := ThemeServices.GetDetailSize(Details);
    CSize.cx := MulDiv(CSize.cx, Font.PixelsPerInch, Screen.PixelsPerInch);
    CSize.cy := MulDiv(CSize.cy, Font.PixelsPerInch, Screen.PixelsPerInch);
  end;

  case bmpAlign of
    taCenter: PaintRect.Left := (aRect.Left + aRect.Right - CSize.cx) div 2;
    taLeftJustify: PaintRect.Left := ARect.Left + varCellPadding;
    taRightJustify: PaintRect.Left := ARect.Right - CSize.Cx - varCellPadding - 1;
  end;

  case bmpLayout of
    tlTop    : PaintRect.Top := aRect.Top + varCellPadding;
    tlCenter : PaintRect.Top := (aRect.Top + aRect.Bottom - CSize.cy) div 2;
    tlBottom : PaintRect.Top := aRect.Bottom - varCellPadding - CSize.cy - 1;
  end;
  PaintRect := Bounds(PaintRect.Left, PaintRect.Top, CSize.cx, CSize.cy);

  if Details.State>=0 then
    ThemeServices.DrawElement(Canvas.Handle, Details, PaintRect, nil)
  else
  if Assigned(ChkBitmap) then
    Canvas.StretchDraw(PaintRect, ChkBitmap)
  else
  if Assigned(ChkILRes.Resolution) then
    ChkILRes.StretchDraw(Canvas, ChkII, PaintRect);
end;

procedure TCustomGrid.DrawButtonCell(const aCol, aRow: Integer; aRect: TRect;
  const aState: TGridDrawState);
var
  details: TThemedElementDetails;
begin
  Dec(aRect.Right);
  Dec(aRect.Bottom);
  if gdPushed in aState then
    Details := ThemeServices.GetElementDetails(tbPushButtonPressed)
  else
  if gdHot in aState then
    Details := ThemeServices.GetElementDetails(tbPushButtonHot)
  else
    Details := ThemeServices.GetElementDetails(tbPushButtonNormal);
  ThemeServices.DrawElement(Canvas.Handle, Details, aRect, nil);
end;

procedure TCustomGrid.OnTitleFontChanged(Sender: TObject);
begin
  FTitleFontIsDefault := False;
  if FColumns.Enabled then begin
    FColumns.TitleFontChanged;
    ColumnsChanged(nil);
  end else
    VisualChange;
end;

procedure TCustomGrid.ReadColumns(Reader: TReader);
begin
  Columns.Clear;
  Reader.ReadValue;
  Reader.ReadCollection(Columns);
end;

procedure TCustomGrid.ReadColWidths(Reader: TReader);
var
  i: integer;
begin
  with Reader do begin
    ReadListBegin;
    for i:=0 to ColCount-1 do
      ColWidths[I] := ReadInteger;
    ReadListEnd;
  end;
end;

procedure TCustomGrid.ReadRowHeights(Reader: TReader);
var
  i: integer;
begin
  with Reader do begin
    ReadListBegin;
    for i:=0 to RowCount-1 do
      RowHeights[I] := ReadInteger;
    ReadListEnd;
  end;
end;

procedure TCustomGrid.WMEraseBkgnd(var message: TLMEraseBkgnd);
begin
  message.Result:=1;
end;

procedure TCustomGrid.WMGetDlgCode(var Msg: TLMNoParams);
begin
  Msg.Result := DLGC_WANTARROWS or DLGC_WANTCHARS;
  if goTabs in Options then Msg.Result:= Msg.Result or DLGC_WANTTAB;
end;

procedure TCustomGrid.WMHScroll(var message: TLMHScroll);
var
  SP: TPoint;
begin
  SP := GetPxTopLeft;

  case message.ScrollCode of
    SB_THUMBPOSITION,
    SB_THUMBTRACK: begin
      if (message.ScrollCode=SB_THUMBPOSITION) or (goThumbTracking in Options) then
      begin
        if BiDiMode = bdRightToLeft then
          TrySmoothScrollBy(FGCache.HScrollBarNetRange-message.Pos-SP.x, 0)
        else
          TrySmoothScrollBy(message.Pos-SP.x, 0);
      end;
      message.Result := 0;
    end;
    SB_PAGELEFT: TrySmoothScrollBy(-(ClientWidth-FGCache.FixedWidth)*RTLSign, 0);
    SB_PAGERIGHT: TrySmoothScrollBy((ClientWidth-FGCache.FixedWidth)*RTLSign, 0);
    SB_LINELEFT: TrySmoothScrollBy(-DefaultColWidth*RTLSign, 0);
    SB_LINERIGHT: TrySmoothScrollBy(DefaultColWidth*RTLSign, 0);
  end;

  if EditorMode then
    EditorPos;
end;

procedure TCustomGrid.WMVScroll(var message: TLMVScroll);
var
  SP: TPoint;
begin
  SP := GetPxTopLeft;

  case message.ScrollCode of
    SB_THUMBPOSITION,
    SB_THUMBTRACK: begin
      if (message.ScrollCode=SB_THUMBPOSITION) or (goThumbTracking in Options) then
        TrySmoothScrollBy(0, message.Pos-SP.y);
      message.Result := 0;
    end;
    SB_PAGEUP: TrySmoothScrollBy(0, -(ClientHeight-FGCache.FixedHeight));
    SB_PAGEDOWN: TrySmoothScrollBy(0, ClientHeight-FGCache.FixedHeight);
    SB_LINEUP: TrySmoothScrollBy(0, -DefaultRowHeight);
    SB_LINEDOWN: TrySmoothScrollBy(0, DefaultRowHeight);
  end;

  if EditorMode then
    EditorPos;
end;

procedure TCustomGrid.WMKillFocus(var message: TLMKillFocus);
begin
  if csDestroying in ComponentState then
    exit;
  {$ifdef dbgGrid}
  DbgOut('*** grid.WMKillFocus, FocusedWnd=%x WillFocus=',[Message.FocusedWnd]);
  if EditorMode and (Message.FocusedWnd = FEditor.Handle) then
    DebugLn('Editor')
  else begin
    DbgOut('ExternalWindow: ');
    if GetProp(Message.FocusedWnd, 'WinControl')<>nil then
      DebugLn(dbgsname(TObject(GetProp(Message.FocusedWnd, 'WinControl'))))
    else
      DebugLn(' Unknown Window');
  end;
  {$endif}
  inherited WMKillFocus(Message);
  InvalidateFocused;
end;

procedure TCustomGrid.WMSetFocus(var message: TLMSetFocus);
begin
  {$ifdef dbgGrid}
  DbgOut('*** grid.WMSetFocus, FocusedWnd=', dbgs(Message.FocusedWnd),'[',dbgs(pointer(Message.FocusedWnd)),'] ');
  if EditorMode and (Message.FocusedWnd = FEditor.Handle) then
    DebugLn('Editor')
  else begin
    if Message.FocusedWnd=Self.Handle then
      DebugLn('Same Grid!')
    else
      DebugLn('ExternalWindow');
  end;
  {$endif}
  inherited WMSetFocus(Message);
  InvalidateFocused;
end;

procedure TCustomGrid.WMSize(var Message: TLMSize);
begin
  if gfUpdatingScrollbar in FGridFlags then // ignore WMSize when updating scrollbars. issue #31715
    Exit;
  inherited WMSize(Message);
end;

class procedure TCustomGrid.WSRegisterClass;
begin
  inherited WSRegisterClass;
  RegisterCustomGrid;
end;

procedure TCustomGrid.AddSelectedRange;
var
  n: Integer;
begin
  if (goRangeSelect in Options) and (FRangeSelectMode = rsmMulti) then begin
    n := Length(FSelections);
    SetLength(FSelections, n+1);
    FSelections[n] := FRange;
  end;
end;

procedure TCustomGrid.AdjustClientRect(var ARect: TRect);
begin
  inherited AdjustClientRect(ARect);
  include(FGridFlags, gfClientRectChange);
end;

procedure TCustomGrid.WndProc(var TheMessage: TLMessage);
begin
  {$ifdef GridTraceMsg}
  TransMsg('GRID: ', TheMessage);
  {$endif}
  case TheMessage.Msg of
    LM_HSCROLL, LM_VSCROLL:
      if csDesigning in ComponentState then
        exit;
    {$IFDEF MSWINDOWS}
    // Ignore LM_SIZE while another sizing is being processed.
    // Windows sends WM_SIZE when showing/hiding scrollbars.
    // Scrollbars can be shown/hidden when processing DoOnChangeBounds.
    LM_SIZE:
      if gfUpdatingSize in FGridFlags then
        exit;
    {$ENDIF}
  end;
  inherited WndProc(TheMessage);
end;

procedure TCustomGrid.CreateWnd;
begin
  //DebugLn('TCustomGrid.CreateWnd ',DbgSName(Self));
  inherited CreateWnd;
  FVSbVisible := Ord(GetScrollbarvisible(Handle, SB_Vert));
  FHSbVisible := Ord(GetScrollbarvisible(Handle, SB_Horz));
  CheckPosition;
  VisualChange;
end;

{ Scroll grid to the given Topleft[aCol,aRow] as needed }
procedure TCustomGrid.TryScrollTo(aCol, aRow: Integer; ClearColOff,
  ClearRowOff: Boolean);
var
  TryTL: TPoint;
  NewCol,NewRow: Integer;
  TLChange: Boolean;
begin
  TryTL:=ScrollGrid(False,aCol, aRow);
  TLChange := not PointIgual(TryTL, FTopLeft);
  if TLChange
  or (not PointIgual(TryTL, Point(aCol, aRow)) and (goSmoothScroll in Options))
  or (ClearColOff and (FGCache.TLColOff<>0))
  or (ClearRowOff and (FGCache.TLRowOff<>0)) then
  begin
    NewCol := TryTL.X - FTopLeft.X + Col;
    NewRow := TryTL.Y - FTopLeft.Y + Row;
    FTopLeft:=TryTL;
    if ClearColOff then
      FGCache.TLColOff := 0;
    if ClearRowOff then
      FGCache.TLRowOff := 0;
    if (aCol>TryTL.X) and (goSmoothScroll in Options) then
      FGCache.TLColOff := FGCache.MaxTLOffset.X;
    if (aRow>TryTL.Y) and (goSmoothScroll in Options) then
      FGCache.TLRowOff := FGCache.MaxTLOffset.Y;
    {$ifdef dbgscroll}
    DebugLn('TryScrollTo: TopLeft=%s NewCol=%d NewRow=%d',
      [dbgs(FTopLeft), NewCol, NewRow]);
    {$endif}
    // To-Do: move rect with ScrollBy_WS and invalidate only new (not scrolled) rects
    if TLChange then
      doTopleftChange(False)
    else
      VisualChange;
    if goScrollKeepVisible in Options then
      MoveNextSelectable(False, NewCol, NewRow);
  end;
end;

function TCustomGrid.TrySmoothScrollBy(aColDelta, aRowDelta: Integer): Boolean;
var
  OldTopLeft, OldTopLeftXY, NewTopLeftXY, OldOff: TPoint;
begin
  if (aColDelta=0) and (aRowDelta=0) then
    Exit(True);

  OldTopLeft := FTopLeft;
  OldTopLeftXY := GetPxTopLeft;
  OldOff := Point(FGCache.TLColOff, FGCache.TLRowOff);

  Inc(FGCache.TLColOff, aColDelta);
  Inc(FGCache.TLRowOff, aRowDelta);

  while (FTopLeft.x < GCache.MaxTopLeft.x) and (FGCache.TLColOff >= ColWidths[FTopLeft.x]) do
  begin
    Dec(FGCache.TLColOff, ColWidths[FTopLeft.x]);
    Inc(FTopLeft.x);
  end;
  while (FTopLeft.x > FixedCols) and (FGCache.TLColOff < 0) do
  begin
    Dec(FTopLeft.x);
    Inc(FGCache.TLColOff, ColWidths[FTopLeft.x]);
  end;

  while (FTopLeft.y < GCache.MaxTopLeft.y) and (FGCache.TLRowOff >= RowHeights[FTopLeft.y]) do
  begin
    Dec(FGCache.TLRowOff, RowHeights[FTopLeft.y]);
    Inc(FTopLeft.y);
  end;
  while (FTopLeft.y > FixedRows) and (FGCache.TLRowOff < 0) do
  begin
    Dec(FTopLeft.y);
    Inc(FGCache.TLRowOff, RowHeights[FTopLeft.y]);
  end;

  FGCache.TLColOff := Max(0, FGCache.TLColOff);
  FGCache.TLRowOff := Max(0, FGCache.TLRowOff);
  if FTopLeft.x=FGCache.MaxTopLeft.x then
    FGCache.TLColOff := Min(FGCache.MaxTLOffset.x, FGCache.TLColOff);
  if FTopLeft.y=FGCache.MaxTopLeft.y then
    FGCache.TLRowOff := Min(FGCache.MaxTLOffset.y, FGCache.TLRowOff);

  if not GetSmoothScroll(SB_Horz) then
    FGCache.TLColOff := 0;
  if not GetSmoothScroll(SB_Vert) then
    FGCache.TLRowOff := 0;

  if not PointIgual(OldTopleft,FTopLeft) then begin
    TopLeftChanged;
    if goScrollKeepVisible in Options then
      MoveNextSelectable(False, FTopLeft.x - oldTopLeft.x + col,
                                FTopLeft.y - oldTopLeft.y + row);
  end;

  NewTopLeftXY := GetPxTopLeft;
  ScrollBy((OldTopLeftXY.x-NewTopLeftXY.x)*RTLSign, OldTopLeftXY.y-NewTopLeftXY.y);

  //Result is false if this function failed due to a too high/wide cell (applicable only if goSmoothScroll not used)
  Result :=
       not PointIgual(OldTopLeftXY, NewTopLeftXY)
    or ((NewTopLeftXY.x = 0) and (aColDelta < 0))
    or ((FTopLeft.x = FGCache.MaxTopLeft.x) and (FGCache.TLColOff = FGCache.MaxTLOffset.x) and (aColDelta > 0))
    or ((NewTopLeftXY.y = 0) and (aRowDelta < 0))
    or ((FTopLeft.y = FGCache.MaxTopLeft.y) and (FGCache.TLRowOff = FGCache.MaxTLOffset.y) and (aRowDelta > 0));
end;

procedure TCustomGrid.SetGridLineWidth(const AValue: Integer);
begin
  if FGridLineWidth = AValue then
    exit;
  FGridLineWidth := AValue;
  Invalidate;
end;

procedure TCustomGrid.UpdateCachedSizes;
var
  i: Integer;
  TLChanged: Boolean;
begin
  if AutoFillColumns then
    InternalAutoFillColumns;

  // Calculate New Cached Values
  FGCache.GridWidth:=0;
  FGCache.FixedWidth:=0;
  for i:=0 to ColCount-1 do begin
    FGCache.AccumWidth[i]:=FGCache.GridWidth;
    FGCache.GridWidth:=FGCache.GridWidth + GetColWidths(i);
    if i<FixedCols then
      FGCache.FixedWidth:=FGCache.GridWidth;
  end;

  FGCache.Gridheight:=0;
  FGCache.FixedHeight:=0;
  for i:=0 to RowCount-1 do begin
    FGCache.AccumHeight[i]:=FGCache.Gridheight;
    FGCache.Gridheight:=FGCache.Gridheight+GetRowHeights(i);
    if i<FixedRows then
      FGCache.FixedHeight:=FGCache.GridHeight;
  end;

  FGCache.ClientRect := ClientRect;
  FGCache.ClientWidth := ClientWidth;
  FGCache.ClientHeight := ClientHeight;

  FGCache.ScrollWidth := FGCache.ClientWidth-FGCache.FixedWidth;
  FGCache.ScrollHeight := FGCache.ClientHeight-FGCache.FixedHeight;
  CalcMaxTopLeft;

  TLChanged := False;
  if fTopLeft.y > FGCache.MaxTopLeft.y then
  begin
    fTopLeft.y := FGCache.MaxTopLeft.y;
    FGCache.TLRowOff := FGCache.MaxTLOffset.y;
    TLChanged := True;
  end else
  if FTopLeft.y < FixedRows then
  begin
    fTopLeft.y := FixedRows;
    TLChanged := True;
  end;
  if fTopLeft.x > FGCache.MaxTopLeft.x then
  begin
    fTopLeft.x := FGCache.MaxTopLeft.x;
    FGCache.TLColOff := FGCache.MaxTLOffset.x;
    TLChanged := True;
  end else
  if FTopLeft.x < FixedCols then
  begin
    fTopLeft.x := FixedCols;
    TLChanged := True;
  end;
  if TopRow=FGCache.MaxTopLeft.y then
    FGCache.TLRowOff := Min(FGCache.TLRowOff, FGCache.MaxTLOffset.y)
  else
    FGCache.TLRowOff := Min(FGCache.TLRowOff, RowHeights[TopRow]);
  if LeftCol=FGCache.MaxTopLeft.x then
    FGCache.TLColOff := Min(FGCache.TLColOff, FGCache.MaxTLOffset.x)
  else
    FGCache.TLColOff := Min(FGCache.TLColOff, ColWidths[LeftCol]);
  if TLChanged then
    TopLeftChanged;

  {$ifdef dbgVisualChange}
  DebugLn('TCustomGrid.updateCachedSizes: ');
  with FGCache do
  DebugLn(' GWidth=%d GHeight=%d FWidth=%d FHeight=%d CWidth=%d CHeight=%d MTL.X=%d MTL.Y=%d',
    [GridWidth,GridHeight,FixedWidth,FixedHeight,ClientWidth,ClientHeight,
     MaxTopLeft.X, MaxTopLeft.Y]);
  {$endif}
end;

procedure TCustomGrid.GetSBVisibility(out HsbVisible,VsbVisible:boolean);
var
  autoVert,autoHorz: boolean;
  ClientW,ClientH,ExtraW,ExtraH: Integer;
  BarW,BarH: Integer;
begin
  AutoVert := ScrollBarAutomatic(ssVertical);
  AutoHorz := ScrollBarAutomatic(ssHorizontal);

  // get client bounds free of bars
  ClientW  := ClientWidth;
  ClientH  := ClientHeight;
  BarW := GetSystemMetrics(SM_CXVSCROLL) +
          GetSystemMetrics(SM_SWSCROLLBARSPACING);
  if ScrollBarIsVisible(SB_VERT) then
    ClientW := ClientW + BarW;
  BarH := GetSystemMetrics(SM_CYHSCROLL) +
          GetSystemMetrics(SM_SWSCROLLBARSPACING);
  if ScrollBarIsVisible(SB_HORZ) then
    ClientH := ClientH + BarH;
  ExtraW := 0;
  if goScrollToLastCol in FOptions2 then
  begin
    Inc(ExtraW, ClientWidth - FGCache.FixedWidth);
    if ColCount>FixedCols then
      Dec(ExtraW, ColWidths[ColCount-1]);
  end;
  ExtraH := 0;
  if goScrollToLastRow in FOptions2 then
  begin
    Inc(ExtraH, ClientHeight - FGCache.FixedHeight);
    if RowCount>FixedRows then
      Dec(ExtraH, RowHeights[RowCount-1]);
  end;

  // first find out if scrollbars need to be visible by
  // comparing against client bounds free of bars
  HsbVisible := (FScrollBars in [ssHorizontal, ssBoth]) or
                (AutoHorz and (FGCache.GridWidth+ExtraW>ClientW));

  VsbVisible := (FScrollBars in [ssVertical, ssBoth]) or
                (AutoVert and (FGCache.GridHeight+ExtraH>ClientH));

  // then for automatic scrollbars check if grid bounds are
  // in some part of area occupied by scrollbars
  if ExtraW>0 then
    Dec(ExtraW, BarW);
  if not HsbVisible and AutoHorz and VsbVisible then
    HsbVisible := FGCache.GridWidth+ExtraW  > (ClientW-BarW);

  if ExtraH>0 then
    Dec(ExtraH, BarH);
  if not VsbVisible and AutoVert and HsbVisible then
    VsbVisible := FGCache.GridHeight+ExtraH > (ClientH-BarH);

  if AutoHorz then
    HsbVisible := HsbVisible and not AutoFillColumns;

  // update new cached client values according to visibility
  // of scrollbars
  if HsbVisible then
    FGCache.ClientHeight := ClientH - BarH;
  if VsbVisible then
    FGCache.ClientWidth := ClientW - BarW;

  {$ifdef dbgscroll}
  DebugLn('TCustomGrid.GetSBVisibility:');
  DebugLn(['  Horz=',HsbVisible,' GW=',FGCache.GridWidth,
    ' CW=',ClientWidth,' CCW=',FGCache.ClientWidth,' BarW=',BarW]);
  DebugLn(['  Vert=',VsbVisible,' GH=',FGCache.GridHeight,
    ' CH=',ClientHeight,' CCH=',FGCache.ClientHeight,' BarH=',BarH]);
  {$endif}
end;

procedure TCustomGrid.GetSBRanges(const HsbVisible, VsbVisible: boolean; out
  HsbRange, VsbRange, HsbPage, VsbPage, HsbPos, VsbPos: Integer);
begin
  HsbRange := 0;
  HsbPos := 0;
  if HsbVisible then
  begin
    if not GetSmoothScroll(SB_Horz) then
    begin
      if IsColumnIndexValid(FGCache.MaxTopLeft.x) then
        HsbRange := FGCache.AccumWidth[FGCache.MaxTopLeft.x]+ClientWidth-FGCache.FixedWidth
    end else
    begin
      HsbRange:=GridWidth - GetBorderWidth;
      if goScrollToLastCol in FOptions2 then
      begin
        Inc(HsbRange, ClientWidth - FGCache.FixedWidth);
        if ColCount>FixedCols then
          Dec(HsbRange, ColWidths[ColCount-1]);
      end;
    end;
    if IsColumnIndexValid(FTopLeft.x) then
      HsbPos := FGCache.AccumWidth[FTopLeft.x]+FGCache.TLColOff-FGCache.FixedWidth;
  end;

  VsbRange := 0;
  VsbPos := 0;
  if VsbVisible then
  begin
    if not GetSmoothScroll(SB_Vert) then
    begin
      if IsRowIndexValid(FGCache.MaxTopLeft.y)  then
        VsbRange := FGCache.AccumHeight[FGCache.MaxTopLeft.y]+ClientHeight-FGCache.FixedHeight
    end else
    begin
      VSbRange:= GridHeight - GetBorderWidth;
      if goScrollToLastRow in FOptions2 then
      begin
        Inc(VsbRange, ClientHeight - FGCache.FixedHeight);
        if RowCount>FixedRows then
          Dec(VsbRange, RowHeights[RowCount-1]);
      end;
    end;
    if IsRowIndexValid(FTopLeft.y) then
      VsbPos := FGCache.AccumHeight[FTopLeft.y]+FGCache.TLRowOff-FGCache.FixedHeight;
  end;

  HsbPage := ClientWidth;
  VSbPage := ClientHeight;

  FGCache.HScrollBarNetRange := HsbRange-HsbPage;

  {$ifdef dbgscroll}
  DebugLn('GetSBRanges: HRange=%d HPage=%d HPos=%d VRange=%d VPage=%d VPos=%d',
    [HSbRange,HsbPage,HsbPos, VsbRange, VsbPage, VsbPos]);
  {$endif}
end;

procedure TCustomGrid.GetSelectedState(AState: TGridDrawState; out
  IsSelected: boolean);
begin
  IsSelected := (gdSelected in aState);
  if IsSelected and (gdFocused in aState) then
    IsSelected := (goDrawFocusSelected in Options) or
          ((goRowSelect in Options) and not (goRelaxedRowSelect in Options));
end;

procedure TCustomGrid.UpdateSBVisibility;
var
  HSbVisible, VSbVisible: boolean;
begin
  GetSBVisibility(HSbVisible, VSbVisible);
  ScrollBarShow(SB_VERT, VSbVisible);
  ScrollBarShow(SB_HORZ, HSbVisible);
end;

procedure TCustomGrid.UpdateSizes;
begin
  if (FUpdateCount<>0) then
    exit;

  Include(FGridFlags, gfVisualChange);

  UpdateCachedSizes;
  CacheVisibleGrid;
  CalcScrollbarsRange;
end;

procedure TCustomGrid.UpdateSelectionRange;
begin
  if goRowSelect in Options then begin
    FRange:=Rect(FFixedCols, FRow, ColCount-1, FRow);
  end
  else
    FRange:=Rect(FCol,FRow,FCol,FRow);
end;

procedure TCustomGrid.WriteColumns(Writer: TWriter);
begin
  if Columns.IsDefault then
    Writer.WriteCollection(nil)
  else
    Writer.WriteCollection(Columns);
end;

procedure TCustomGrid.WriteColWidths(Writer: TWriter);
var
  i: Integer;
begin
  with writer do begin
    WriteListBegin;
    for i:=0 to ColCount-1 do
      WriteInteger(ColWidths[i]);
    WriteListEnd;
  end;
end;

procedure TCustomGrid.WriteRowHeights(Writer: TWriter);
var
  i: integer;
begin
  with writer do begin
    WriteListBegin;
    for i:=0 to RowCount-1 do
      WriteInteger(RowHeights[i]);
    WriteListEnd;
  end;
end;

procedure TCustomGrid.CheckFixedCount(aCol,aRow,aFCol,aFRow: Integer);
begin
  if AFRow<0 then
    raise EGridException.Create('FixedRows<0');
  if AFCol<0 then
    raise EGridException.Create('FixedCols<0');

  if csLoading in ComponentState then
    exit;

  if (aCol=0)and(aFCol=0) then // fixed grid
  else if (aFCol>ACol) then
    raise EGridException.Create(rsFixedColsTooBig);

  if (aRow=0)and(aFRow=0) then // fixed grid
  else if (aFRow>ARow) then
    raise EGridException.Create(rsFixedRowsTooBig);
end;

procedure TCustomGrid.CheckCount(aNewColCount, aNewRowCount: Integer; FixEditor: boolean=true);
var
  NewCol,NewRow: Integer;
begin
  if HandleAllocated then begin
    if Col >= aNewColCount then NewCol := aNewColCount-1
    else                        NewCol := Col;
    if Row >= aNewRowCount then NewRow := aNewRowCount-1
    else                        NewRow := Row;
    if (NewCol>=0) and (NewRow>=0) and ((NewCol <> Col) or (NewRow <> Row)) then
    begin
      CheckTopleft(NewCol, NewRow , NewCol<>Col, NewRow<>Row);
      if FixEditor and (aNewColCount<>FFixedCols) and (aNewRowCount<>FFixedRows) then
        MoveNextSelectable(false, NewCol, NewRow);
    end;
  end;
end;

procedure TCustomGrid.CheckIndex(IsColumn: Boolean; Index: Integer);
begin
  if (IsColumn and not IsColumnIndexValid(Index)) or
     (not IsColumn and not IsRowIndexValid(Index)) then
    raise EGridException.Create(rsGridIndexOutOfRange);
end;

function TCustomGrid.CheckTopLeft(aCol,aRow: Integer; CheckCols, CheckRows: boolean): boolean;
var
  OldTopLeft: TPoint;
  W: Integer;
begin
  OldTopLeft := FTopLeft;
  Result := False;

  if CheckCols and (FTopleft.X > FixedCols) then begin
    W := FGCache.ScrollWidth-ColWidths[aCol]-FGCache.AccumWidth[aCol];
    while (FTopleft.x > FixedCols)
    and (W+FGCache.AccumWidth[FTopleft.x] >= ColWidths[FTopleft.x-1]) do
      Dec(FTopleft.x);
  end;

  if CheckRows and (FTopleft.Y > FixedRows) then begin
    W := FGCache.ScrollHeight-RowHeights[aRow]-FGCache.AccumHeight[aRow];
    while (FTopleft.y > FixedRows)
    and (W+FGCache.AccumHeight[FTopleft.y] >= RowHeights[FTopleft.y-1]) do
      Dec(FTopleft.y);
    //DebugLn('TCustomGrid.CheckTopLeft A ',DbgSName(Self),' FTopLeft=',dbgs(FTopLeft));
  end;

  Result := not PointIgual(OldTopleft,FTopLeft);
  if Result then
    doTopleftChange(False)
end;

function TCustomGrid.GetQuickColRow: TPoint;
begin
  result.x := Col;
  result.y := Row;
end;

procedure TCustomGrid.SetQuickColRow(AValue: TPoint);
begin
  if (AValue.x=FCol) and (AValue.y=FRow) then Exit;
  if not AllowOutboundEvents then
    CheckLimitsWithError(AValue.x, AValue.y);
  SetColRow(aValue.x, aValue.y, true);
end;

procedure TCustomGrid.doPushCell;
begin
  with FGCache do
  begin
    PushedCell := ClickCell;
    ClickCellPushed:=True;
    InvalidateCell(PushedCell.x, PushedCell.y);
  end;
end;

function TCustomGrid.IsCellButtonColumn(ACell: TPoint): boolean;
var
  Column: TGridColumn;
begin
  Column := ColumnFromGridColumn(ACell.X);
  result := (Column<>nil) and (Column.ButtonStyle=cbsButtonColumn) and
            (ACell.y>=FixedRows);
end;

function TCustomGrid.GetIsCellTitle(aCol, aRow: Integer): boolean;
begin
  result := (FixedRows>0) and (aRow=0) {and Columns.Enabled} and (aCol>=FirstGridColumn);
    // Columns.Enabled removed in order to allow sort arrows also without columns
end;

function TCustomGrid.GetIsCellSelected(aCol, aRow: Integer): boolean;
var
  i: Integer;
begin
  Result:=  (FRange.Left<=aCol)   and
            (aCol<=FRange.Right)  and
            (FRange.Top<=aRow)    and
            (aRow<=FRange.Bottom);

  if not Result and (goRangeSelect in FOptions) and (RangeSelectMode = rsmMulti)
  then
    for i:=0 to High(FSelections) do
      if (FSelections[i].Left <= aCol)  and
         (ACol <= FSelections[i].Right) and
         (FSelections[i].Top <= ARow)   and
         (ARow <= FSelections[i].Bottom)
      then begin
        Result := true;
        exit;
      end;
end;

function TCustomGrid.IsEmptyRow(ARow: Integer): Boolean;
var
  i: Integer;
begin
  Result := False;
  for i:=FixedCols to ColCount-1 do
  if GetCells(i, ARow)<>'' then begin
    Exit;
  end;
  Result := True;
end;

function TCustomGrid.GetDefColWidth: Integer;
begin
  if FDefColWidth<0 then
  begin
    if FRealizedDefColWidth <= 0 then
      FRealizedDefColWidth := Scale96ToFont(DEFCOLWIDTH);
    Result := FRealizedDefColWidth;
  end else
    Result := FDefColWidth;
end;

function TCustomGrid.GetDefRowHeight: Integer;
begin
  if FDefRowHeight<0 then
  begin
    if FRealizedDefRowHeight <= 0 then
      FRealizedDefRowHeight := GetDefaultRowHeight;
    Result := FRealizedDefRowHeight;
  end else
    Result := FDefRowHeight;
end;

function TCustomGrid.GetSelectedColumn: TGridColumn;
begin
  Result := ColumnFromGridColumn(Col);
end;

function TCustomGrid.IsAltColorStored: boolean;
begin
  result := FAlternateColor <> Color;
end;

procedure TCustomGrid.SetAlternateColor(const AValue: TColor);
begin
  if FAlternateColor=AValue then exit;
  FAlternateColor:=AValue;
  Invalidate;
end;

function TCustomGrid.GetEditorBorderStyle: TBorderStyle;
begin
  result := bsSingle;
  if FEditor = FStringEditor then
    Result := FStringEditor.BorderStyle
  else if FEditor = FPickListEditor then
    Result := FPickListEditor.BorderStyle;
end;

function TCustomGrid.GetBorderWidth: Integer;
begin
  if InternalNeedBorder then
    Result := 1
  else
    Result := 0
end;

procedure TCustomGrid.GetTitleImageInfo(aColumnIndex: Integer; out
  ImgIndex: Integer; out ImgLayout: TButtonLayout);
var
  c: TGridColumn;
  ResName: string;
begin
  c := ColumnFromGridColumn(AColumnIndex);
  if (c <> nil) and (FTitleImageList <> nil) and InRange(c.Title.FImageIndex, 0, FTitleImageList.Count - 1) then
  begin
    ImgIndex := c.Title.FImageIndex;
    ImgLayout := c.Title.ImageLayout;
  end else
  begin
    ImgIndex := -1;
    ImgLayout := blGlyphRight;
  end;
  if IsRightToLeft then begin
    if ImgLayout = blGlyphRight then
      ImgLayout := blGlyphLeft
    else if ImgLayout = blGlyphLeft then
      ImgLayout := blGlyphRight;
  end;
end;

procedure TCustomGrid.GetSortTitleImageInfo(aColumnIndex: Integer; out
  ImgList: TCustomImageList; out ImgIndex, ImgListWidth: Integer; out
  NativeSortGlyphs: Boolean);
var
  ResName: string;
begin
  NativeSortGlyphs := False;
  ImgIndex := -1;
  ImgList := nil;
  ImgListWidth := 0;

  if aColumnIndex<>FSortColumn then
    Exit;

  if (FTitleImageList<>nil) and (FSortOrder=soAscending) and (FAscImgInd>=0) then
  begin
    ImgList := FTitleImageList;
    ImgListWidth := FTitleImageListWidth;
    ImgIndex := FAscImgInd;
  end else
  if (FTitleImageList<>nil) and (FSortOrder=soDescending) and (FDescImgInd>=0) then
  begin
    ImgList := FTitleImageList;
    ImgListWidth := FTitleImageListWidth;
    ImgIndex := FDescImgInd;
  end else
  begin
    if FSortLCLImages=nil then
    begin
      FSortLCLImages := TLCLGlyphs.Create(Self);
      FSortLCLImages.Width := 8;
      FSortLCLImages.Height := 8;
      FSortLCLImages.RegisterResolutions([8, 12, 16]);
      FSortLCLImages.SetWidth100Suffix(16);
    end;
    ImgList := FSortLCLImages;
    case FSortOrder of
      soAscending: ResName := 'sortasc';
      soDescending: ResName := 'sortdesc';
    end;
    ImgIndex := FSortLCLImages.GetImageIndex(ResName);
    NativeSortGlyphs := FTitleStyle = tsNative;
  end;
end;

procedure TCustomGrid.GetImageForCheckBox(const aCol, aRow: Integer;
  CheckBoxView: TCheckBoxState; var ImageList: TCustomImageList;
  var ImageIndex: TImageIndex; var Bitmap: TBitmap);
begin
  if Assigned(OnUserCheckboxBitmap) then
    OnUserCheckboxBitmap(Self, aCol, aRow, CheckBoxView, Bitmap);
  if (Bitmap = nil) and Assigned(OnUserCheckBoxImage) then
    OnUserCheckboxImage(Self, aCol, aRow, CheckBoxView, ImageList, ImageIndex);
end;

procedure TCustomGrid.AdjustInnerCellRect(var ARect: TRect);
begin
  if (GridLineWidth>0) then begin
    if goHorzLine in Options then Dec(ARect.Bottom);
    if goVertLine in Options then Dec(ARect.Right);
  end;
end;

function TCustomGrid.GetColumns: TGridColumns;
begin
  result := FColumns;
end;

function TCustomGrid.CreateColumns: TGridColumns;
begin
  result := TGridColumns.Create(Self, TGridColumn);
end;

procedure TCustomGrid.CheckNewCachedSizes(var AGCache:TGridDataCache);
begin

end;

procedure TCustomGrid.SetAutoFillColumns(const AValue: boolean);
begin
  FAutoFillColumns := AValue;
  if FAutoFillColumns then begin
    VisualChange;
    if FTopleft.x<>FixedCols then begin
      FTopLeft.x := FixedCols;
      TopLeftChanged;
    end;
  end;
end;

procedure TCustomGrid.SetBorderColor(const AValue: TColor);
begin
  if FBorderColor=AValue then exit;
  FBorderColor:=AValue;
  if BorderStyle<>bsNone then
    Invalidate;
end;

procedure TCustomGrid.SetColumnClickSorts(const AValue: boolean);
begin
  if FColumnClickSorts=AValue then exit;
  FColumnClickSorts:=AValue;
end;

procedure TCustomGrid.SetColumns(const AValue: TGridColumns);
begin
  FColumns.Assign(Avalue);
end;

procedure TCustomGrid.SetEditorOptions(const AValue: Integer);
begin
  if FEditorOptions<>AValue then begin
    if FEditor=nil then exit;
    FEditorOptions:=AValue;

    if FEditorOptions and EO_HOOKKEYDOWN = EO_HOOKKEYDOWN then begin
      FEditor.OnKeyDown:=@EditorKeyDown;
    end;
    if FEditorOptions and EO_HOOKKEYPRESS = EO_HOOKKEYPRESS then begin
      FEditor.OnKeyPress := @EditorKeyPress;
    end;
    if FEditorOptions and EO_HOOKKEYUP = EO_HOOKKEYUP then begin
      FEditor.OnKeyUp := @EditorKeyUp;
    end;

    {$IfDef DbgGrid}
    DBGOut('EditorOptions ',FEditor.Name,' ');
    if FEditorOptions and EO_AUTOSIZE = EO_AUTOSIZE then DBGOut('EO_AUTOSIZE ');
    if FEditorOptions and EO_HOOKKEYDOWN = EO_HOOKKEYDOWN then DBGOut('EO_HOOKKEYDOWN ');
    if FEditorOptions and EO_HOOKKEYPRESS = EO_HOOKKEYPRESS then DBGOut('EO_HOOKKEYPRESS ');
    if FEditorOptions and EO_HOOKKEYUP = EO_HOOKKEYUP then DBGOut('EO_HOOKKEYUP ');
    if FEditorOptions and EO_SELECTALL= EO_SELECTALL then DBGOut('EO_SELECTALL ');
    DebugLn;
    {$Endif}
  end;
end;

procedure TCustomGrid.SetEditorBorderStyle(const AValue: TBorderStyle);
begin
  // supposedly instances cannot access protected properties
  // of parent classes, so why the next works?
  {
  if FEditor.BorderStyle <> AValue then begin
    FEditor.BorderStyle := AValue;
    if EditorMode then
      EditorPos;
  end;
  }
  if FStringEditor.BorderStyle<>AValue then begin
    FStringEditor.BorderStyle := AValue;
    if (FEditor = FStringEditor) and EditorMode then
      EditorPos;
  end;
  if FPicklistEditor.BorderStyle<>AValue then begin
    FPicklistEditor.BorderStyle := AValue;
    if (FEditor = FPicklistEditor) and EditorMode then
      EditorPos;
  end;
end;

procedure TCustomGrid.SetAltColorStartNormal(const AValue: boolean);
begin
  if FAltColorStartNormal=AValue then exit;
  FAltColorStartNormal:=AValue;
  if IsAltColorStored then
    Invalidate;
end;

procedure TCustomGrid.SetFlat(const AValue: Boolean);
begin
  if FFlat=AValue then exit;
  FFlat:=AValue;
  if FGridBorderStyle=bsSingle then
    UpdateBorderStyle
  else
    Invalidate;
end;

procedure TCustomGrid.SetFocusRectVisible(const AValue: Boolean);
begin
  if FFocusRectVisible<>AValue then begin
    FFocusRectVisible := AValue;
    Invalidate;
  end;
end;

procedure TCustomGrid.SetTitleFont(const AValue: TFont);
begin
  FTitleFont.Assign(AValue);
  VisualChange;
end;

procedure TCustomGrid.SetTitleImageList(const AValue: TImageList);
begin
  if FTitleImageList = AValue then exit;
  FTitleImageList := AValue;
  VisualChange;
end;

procedure TCustomGrid.SetTitleImageListWidth(
  const aTitleImageListWidth: Integer);
begin
  if FTitleImageListWidth = aTitleImageListWidth then Exit;
  FTitleImageListWidth := aTitleImageListWidth;
  VisualChange;
end;

procedure TCustomGrid.SetTitleStyle(const AValue: TTitleStyle);
begin
  if FTitleStyle=AValue then exit;
  FTitleStyle:=AValue;
  Invalidate;
end;

procedure TCustomGrid.SetUseXorFeatures(const AValue: boolean);
begin
  if FUseXORFeatures=AValue then exit;
  FUseXORFeatures:=AValue;
  Invalidate;
end;

procedure TCustomGrid.SetBorderStyle(NewStyle: TBorderStyle);
begin
  if FGridBorderStyle<>NewStyle then begin
    FGridBorderStyle := NewStyle;
    UpdateBorderStyle;
  end;
end;

{ Save to the cache the current visible grid (excluding fixed cells) }
procedure TCustomGrid.CacheVisibleGrid;
var
  CellR: TRect;
begin
  with FGCache do begin
    VisibleGrid:=GetVisibleGrid;
    with VisibleGrid do begin
      ValidRows := (left>=0) and (Right>=Left) and (ColCount>0) and (RowCount>0);
      ValidCols := (top>=0) and (bottom>=Top) and (ColCount>0) and (RowCount>0);
      ValidGrid := ValidRows and ValidCols;
    end;
    FullVisibleGrid := VisibleGrid;
    if ValidGrid then begin
      if GetSmoothScroll(SB_Horz) and (TLColOff>0) then
        FullVisibleGrid.Left := Min(FullVisibleGrid.Left+1, FullVisibleGrid.Right);
      if GetSmoothScroll(SB_Vert) and (TLRowOff>0) then
        FullVisibleGrid.Top  := Min(FullVisibleGrid.Top+1, FullVisibleGrid.Bottom);

      CellR := CellRect(FullVisibleGrid.Right, FullVisibleGrid.Bottom);
      if CellR.Right>(ClientWidth+GetBorderWidth) then
        FullVisibleGrid.Right := Max(FullVisibleGrid.Right-1, FullVisibleGrid.Left);
      if CellR.Bottom>(ClientHeight+GetBorderWidth) then
        FullVisibleGrid.Bottom := Max(FullVisibleGrid.Bottom-1, FullVisibleGrid.Top);
    end;
  end;
end;

procedure TCustomGrid.CancelSelection;
begin
  if (FRange.Bottom-FRange.Top>0) or
    ((FRange.Right-FRange.Left>0) and not (goRowSelect in Options)) then begin
    InvalidateRange(FRange);
    if goRowSelect in Options then
      FRange:=Rect(FFixedCols, FRow, ColCount-1, FRow)
    else
      FRange:=Rect(FCol,FRow,FCol,FRow);
  end;
  SelectActive := False;
end;

function TCustomGrid.GetSelectedRange(AIndex: Integer): TGridRect;
begin
  if AIndex >= Length(FSelections) then
    Result := FRange
  else
    Result := FSelections[AIndex];
end;

function TCustomGrid.GetSelectedRangeCount: Integer;
begin
  Result := Length(FSelections) + 1;
    // add 1 because the current selection (FRange) is not stored in the array
end;

function TCustomGrid.GetSelection: TGridRect;
begin
  Result:=FRange;
end;

function TCustomGrid.GetSpecialCursor(ACursorState: TGridCursorState): TCursor;
begin
  Result := FSpecialCursors[ACursorState];
end;

function TCustomGrid.GetSmoothScroll(Which: Integer): Boolean;
begin
  Result := goSmoothScroll in Options;
end;

procedure TCustomGrid.SetColRowDragIndicatorColor(const AValue: TColor);
begin
  if FColRowDragIndicatorColor = AValue then exit;
  FColRowDragIndicatorColor := AValue;
  if FGridState = gsColMoving then
    DrawColRowMoving;
end;

procedure TCustomGrid.SetDefaultDrawing(const AValue: Boolean);
begin
  if FDefaultDrawing=AValue then exit;
  FDefaultDrawing:=AValue;
  Invalidate;
end;

procedure TCustomGrid.SetFocusColor(const AValue: TColor);
begin
  if FFocusColor=AValue then exit;
  FFocusColor:=AValue;
  InvalidateCell(FCol,FRow);
end;

procedure TCustomGrid.SetGridLineStyle(const AValue: TPenStyle);
begin
  if FGridLineStyle=AValue then exit;
  FGridLineStyle:=AValue;
  Invalidate;
end;

procedure TCustomGrid.SetSelectActive(const AValue: Boolean);
begin
  if FSelectActive=AValue then exit;
  FSelectActive:=AValue and
    (not EditingAllowed(FCol) or (ExtendedSelect and not EditorAlwaysShown));
  if FSelectActive then FPivot:=Point(FCol,FRow);
end;

procedure TCustomGrid.SetSelection(const AValue: TGridRect);
begin
  if goRangeSelect in Options then
  begin
    if (AValue.Left<0)and(AValue.Top<0)and(AValue.Right<0)and(AValue.Bottom<0) then
      CancelSelection
    else begin
      fRange:=NormalizarRect(aValue);
      if fRange.Right>=ColCount then fRange.Right:=ColCount-1;
      if fRange.Bottom>=RowCount then fRange.Bottom:=RowCount-1;
      if fRange.Left<FixedCols then fRange.Left := FixedCols;
      if fRange.Top<FixedRows then fRange.Top := FixedRows;
      if goSelectionActive in Options then begin
        FPivot := FRange.TopLeft;
        FSelectActive := True;
        MoveExtend(false, FRange.Right, FRange.Bottom, True);
      end;
      Invalidate;
    end;
  end;
end;

procedure TCustomGrid.SetSpecialCursor(ACursorState: TGridCursorState;
  const AValue: TCursor);
begin
  if AValue = GetSpecialCursor(ACursorState) then
    exit;
  FSpecialCursors[ACursorState] := AValue;
  if FCursorState <> gcsDefault then
    ChangeCursor(AValue, false);
end;

function TCustomGrid.doColSizing(X, Y: Integer): Boolean;
var
  Offset: Integer;

  procedure FindPrevColumn;
  begin
    Dec(FSizing.Index);
    while (FSizing.Index>FixedCols) and (ColWidths[FSizing.Index]=0) do
      Dec(FSizing.Index);
  end;

begin
  Result:=False;

  with FSizing do
  if gsColSizing = fGridState then begin

    if not (gfSizingStarted in FGridFlags) then
      if not StartColSizing(X,Y) then
        exit;
    Include(FGridFlags, gfSizingStarted);

    if FUseXORFeatures then begin

      if UseRightToLeftAlignment then begin
        if (OffEnd - x) <=0 then
          x:= OffEnd;
      end
      else
      if (X-OffIni)<=0 then
        X := OffIni;

      if X<>PrevOffset then begin
        if PrevLine then
          DrawXorVertLine(PrevOffset);
        DrawXorVertLine(X);
        PrevLine:=True;
        PrevOffset:=X;
      end;

    end else begin
      if UseRightToLeftAlignment then
        ResizeColumn(Index, OffEnd - X + DeltaOff)
      else
        ResizeColumn(Index, X - OffIni + DeltaOff);
    end;
    HeaderSizing(true, Index, X - OffIni + DeltaOff);
    exit(true);
  end else
  if (fGridState=gsNormal) and
     ((Y<FGCache.FixedHeight) or (FExtendedColSizing and (Y<FGCache.MaxClientXY.Y))) and
     ((goFixedColSizing in Options) or ((ColCount>FixedCols) and (FlipX(X)>FGCache.FixedWidth)))
  then begin

    // find closest cell and cell boundaries
    if (FlipX(X)>FGCache.GridWidth-1) then
      Index := ColCount-1
    else
      OffsetToColRow(True, True, X, Index, Offset);
    ColRowToOffset(True, true, Index, OffIni, OffEnd);

    if OffEnd>FGCache.ClientWidth then
      Offset := FGCache.ClientWidth
    else if (OffEnd-X)<(X-OffIni) then begin
      Offset := OffEnd;
      if UseRightToLeftAlignment then
        FindPrevColumn;
    end else begin
      Offset := OffIni;
      if not UseRightToLeftAlignment then
        FindPrevColumn;
    end;

    // check if cursor is near boundary and it's a valid column
    if (Abs(Offset-x)<=varColRowBorderTolerance) then begin
      if goFixedColSizing in Options then
        Offset := 0
      else
        Offset := FFixedCols;
      if Index>=Offset then begin
        // start resizing
        if FCursorState<>gcsColWidthChanging then begin
          PrevLine := false;
          PrevOffset := -1;
          ChangeCursor(ColSizingCursor);
          FCursorState := gcsColWidthChanging;
        end;
        exit(true);
      end;
    end;

  end;

  if (FCursorState=gcsColWidthChanging) then
    RestoreCursor;
end;

function TCustomGrid.doRowSizing(X, Y: Integer): Boolean;
var
  Offset: Integer;
begin
  Result:=False;

  with FSizing do
  if gsRowSizing = fGridState then begin
    if FUseXORFeatures then begin
      if (y-OffIni)<=0 then
        y:= OffIni;
      if y<>PrevOffset then begin
        if PrevLine then
          DrawXorHorzLine(PrevOffset);
        DrawXorHorzLine(Y);
        PrevLine:=True;
        PrevOffset:=y;
      end;
    end else
      ResizeRow(Index, y-OffIni);
    HeaderSizing(false, Index, y-OffIni);
    exit(true);
  end else
  if (fGridState=gsNormal) and (RowCount>FixedRows) and
     ((FlipX(X)<FGCache.FixedWidth) or
      (FExtendedRowSizing and (FlipX(X)<FGCache.MaxClientXY.X))) and
     (Y>FGCache.FixedHeight) then
  begin

    // find closest cell and cell boundaries
    if Y>FGCache.GridHeight-1 then
      Index := RowCount-1
    else
      OffsetToColRow(False, True, Y, Index, OffEnd{dummy});
    ColRowToOffset(False, True, Index, OffIni, OffEnd);

    // find out what cell boundary is closer to Y
    if OffEnd>FGCache.ClientHeight then
      Offset := FGCache.ClientHeight
    else
    if (OffEnd-Y)<(Y-OffIni) then
      Offset := OffEnd
    else begin
      Offset := OffIni;
      Dec(Index);
      ColRowToOffset(False, True, Index, OffIni, OffEnd);
    end;

    // check if it's not fixed row and if cursor is close enough to
    // selected boundary
    if (Index>=FFixedRows)and(Abs(Offset-Y)<=varColRowBorderTolerance) then begin
      // start resizing
      if FCursorState<>gcsRowHeightChanging then begin
        ChangeCursor(RowSizingCursor);
        FCursorState := gcsRowHeightChanging;
        PrevLine := False;
        PrevOffset := -1;
      end;
      exit(true);
    end

  end;

  if (FCursorState=gcsRowHeightChanging) then
    RestoreCursor;
end;

procedure TCustomGrid.doColMoving(X, Y: Integer);
var
  CurCell: TPoint;
  R: TRect;
begin
  CurCell:=MouseToCell(Point(X,Y));

  with FGCache do begin

    if (Abs(ClickMouse.X-X)>FDragDX) and (FCursorState<>gcsDragging) then begin
      ChangeCursor(ColRowDraggingCursor);
      FCursorState := gcsDragging;
      ResetLastMove;
    end;

    if (FCursorState=gcsDragging) and
       (CurCell.X>=FFixedCols) and
       ((CurCell.X<=ClickCell.X) or (CurCell.X>ClickCell.X)) and
       (CurCell.X<>FMoveLast.X) then begin

      R := CellRect(CurCell.X, CurCell.Y);
      if CurCell.X<=ClickCell.X then
        FMoveLast.Y := R.Left
      else
        FMoveLast.Y := R.Right;

      FMoveLast.X := CurCell.X;
      {$ifdef AlternativeMoveIndicator}
      InvalidateRow(0);
      {$else}
      Invalidate;
      {$endif}
    end;
  end;
end;

procedure TCustomGrid.doRowMoving(X, Y: Integer);
var
  CurCell: TPoint;
  R: TRect;
begin
  CurCell:=MouseToCell(Point(X,Y));

  with FGCache do begin

    if (FCursorState<>gcsDragging) and (Abs(ClickMouse.Y-Y)>FDragDX) then begin
      ChangeCursor(ColRowDraggingCursor);
      FCursorState := gcsDragging;
      ResetLastMove;
    end;

    if (FCursorState=gcsDragging)and
       (CurCell.Y>=FFixedRows) and
       ((CurCell.Y<=ClickCell.Y) or (CurCell.Y>ClickCell.Y))and
       (CurCell.Y<>FMoveLast.Y) then begin

      R:=CellRect(CurCell.X, CurCell.Y);
      if CurCell.Y<=ClickCell.Y then
        FMoveLast.X:=R.Top
      else
        FMoveLast.X:=R.Bottom;
      FMoveLast.Y:=CurCell.Y;
      Invalidate;
    end;
  end;
end;


function TCustomGrid.OffsetToColRow(IsCol, Physical: Boolean; Offset: Integer;
  out Index, Rest: Integer): Boolean;
begin
  Index:=0;
  Rest:=0;
  Result := False;
  if IsCol and UseRightToLeftAlignment then
    Offset := FlipX(Offset);
  Offset := Offset - GetBorderWidth;
  if Offset<0 then Exit; // Out of Range;

  with FGCache do begin
    if IsCol then begin
      // begin to count Cols from 0 but ...
      if Physical and (Offset>FixedWidth-1) then begin
        Index := FTopLeft.X;  // In scrolled view, then begin from FTopLeft col
        if IsColumnIndexValid(Index) then begin
          Offset:=Offset-FixedWidth+AccumWidth[Index];
          if GetSmoothScroll(SB_Horz) then
            Offset:=Offset+TLColOff;
        end;
        if not IsColumnIndexValid(Index) or (Offset>GridWidth-1) then begin
          if AllowOutboundEvents then
            Index := ColCount-1
          else
            Index := -1;
          exit;
        end;
      end;

      while Offset > AccumWidth[Index]+GetColWidths(Index)-1 do begin
        Inc(Index);
        if not IsColumnIndexValid(Index) then begin
          if AllowOutBoundEvents then
            Index := ColCount-1
          else
            Index := -1;
          exit;
        end;
      end;

      Rest:=Offset;
      if Index<>0 then
        Rest:=Offset-AccumWidth[Index];

    end else begin

      //DebugLn('TCustomGrid.OffsetToColRow ',DbgSName(Self),' Physical=',dbgs(Physical),' Offset=',dbgs(Offset),' FixedHeight=',dbgs(FixedHeight),' FTopLeft=',dbgs(FTopLeft),' RowCount=',dbgs(RowCount),' TLRowOff=',dbgs(TLRowOff));
      if Physical and (Offset>FixedHeight-1) then begin
        Index:=FTopLeft.Y;
        if IsRowIndexValid(Index) then
          Offset:=Offset-FixedHeight+AccumHeight[Index]+TLRowOff;
        if not IsRowIndexValid(Index) or (Offset>GridHeight-1) then begin
          if AllowOutboundEvents then
            Index := RowCount-1
          else
            Index := -1;
          Exit; // Out of Range
        end;
      end;

      while Offset > AccumHeight[Index]+GetRowHeights(Index)-1 do
        Inc(Index);

      Rest:=Offset;
      if Index<>0 then
        Rest:=Offset-AccumHeight[Index];

    end;
  end;
  result := True;
end;

{ ------------------------------------------------------------------------------
  Example:
  IsCol=true, Index:=100, TopLeft.x:=98, FixedCols:=1, all ColWidths:=20
  Relative => StartPos := WidthfixedCols+WidthCol98+WidthCol99
  not Relative = Absolute => StartPos := WidthCols(0..99) }
function TCustomGrid.ColRowToOffset(IsCol, Relative: Boolean; Index: Integer;
  out StartPos, EndPos: Integer): Boolean;
var
  Dim: Integer;
begin
  Result:=false;
  with FGCache do begin
    if IsCol then begin
      if not IsColumnIndexValid(Index) then
        exit;
      StartPos:=AccumWidth[index];
      Dim:=GetColWidths(index);
    end else begin
      if not IsRowIndexValid(Index) then
        exit;
      StartPos:=AccumHeight[index];
      Dim:= GetRowHeights(index);
    end;
    StartPos := StartPos + GetBorderWidth;
    if not Relative then begin
      EndPos:=StartPos + Dim;
      Exit;
    end;
    if IsCol then begin
      if IsColumnIndexVariable(Index) then begin
        StartPos:=StartPos-AccumWidth[FTopLeft.X] + FixedWidth;
        if GetSmoothScroll(SB_Horz) then
          StartPos := StartPos - TLColOff;
      end;
    end else begin
      if IsRowIndexVariable(Index) then begin
        StartPos:=StartPos-AccumHeight[FTopLeft.Y] + FixedHeight;
        if GetSmoothScroll(SB_Vert) then
          StartPos := StartPos - TLRowOff;
      end;
    end;
    if IsCol and UseRightToLeftAlignment then
    begin
      EndPos := FlipX(StartPos) + 1;
      StartPos := EndPos - Dim;
    end
    else
      EndPos:=StartPos + Dim;
  end;
  Result:=true;
end;

function TCustomGrid.ColumnIndexFromGridColumn(Column: Integer): Integer;
begin
  if Columns.Enabled and (Column>=FirstGridColumn) then
    result := Columns.RealIndex(Column - FirstGridColumn)
  else
    result := -1;
end;

function TCustomGrid.ColumnFromGridColumn(Column: Integer): TGridColumn;
var
  ColIndex: Integer;
begin
  ColIndex := ColumnIndexFromGridColumn(Column);
  if ColIndex>=0 then
    result := Columns[ColIndex]
  else
    result := nil;
end;

procedure TCustomGrid.ColumnsChanged(aColumn: TGridColumn);
var
  aCol: Integer;
begin
  if csDestroying in ComponentState then
    exit;

  if AColumn=nil then begin
    if Columns.Enabled then begin
      if FirstGridColumn + Columns.VisibleCount <> ColCount then
        InternalSetColCount( FirstGridColumn + Columns.VisibleCount )
      else
        VisualChange;
    end else
    if not (csLoading in ComponentState) then
      ColCount := FixedCols;
  end else begin
    aCol := Columns.IndexOf(AColumn);
    if ACol>=0 then begin
      VisualChange;
      {
      if aColumn.WidthChanged then
        VisualChange
      else
        InvalidateCol(FixedCols + ACol);
      }
    end;
  end;

end;

function TCustomGrid.MouseToGridZone(X, Y: Integer): TGridZone;
var
  aBorderWidth: Integer;
  aCol, aRow: Longint;
begin
  aBorderWidth := GetBorderWidth;
  if FlipX(X)<FGCache.FixedWidth+aBorderWidth then begin
    // in fixedwidth zone
    if Y<FGcache.FixedHeight+aBorderWidth then
      Result:= gzFixedCells
    else begin
      OffsetToColRow(False, True, Y, aRow, aCol);
      if (aRow<0) or (RowCount<=FixedRows) then
        Result := gzInvalid
      else
        Result := gzFixedRows;
    end;
  end
  else if Y<FGCache.FixedHeight+aBorderWidth then begin
    // if fixedheight zone
    if FlipX(X)<FGCache.FixedWidth+aBorderWidth then
      Result:=gzFixedCells
    else begin
      OffsetToColRow(True, True, X, aCol, aRow);
      if (aCol<0) or (ColCount<=FixedCols) then
        Result := gzInvalid
      else
        Result := gzFixedCols;
    end;
  end
  else if not FixedGrid then begin
    // in normal cell zone (though, might be outbounds)
    MouseToCell(x, y, aCol, aRow);
    if (aCol<0) or (aRow<0) then
      result := gzInvalid
    else
      result := gzNormal;
  end
  else
    result := gzInvalid;
end;

function TCustomGrid.CellToGridZone(aCol, aRow: Integer): TGridZone;
begin
  if (aCol<0) or (aRow<0) then
    Result := gzInvalid
  else
  if (aCol<FFixedCols) then
    if aRow<FFixedRows then
      Result:= gzFixedCells
    else
      Result:= gzFixedRows
  else
  if (aRow<FFixedRows) then
    if aCol<FFixedCols then
      Result:= gzFixedCells
    else
      Result:= gzFixedCols
  else
    Result := gzNormal;
end;

procedure TCustomGrid.DoOPExchangeColRow(IsColumn: Boolean; index, WithIndex: Integer);
var
  aColRow: integer;
begin

  if IsColumn and Columns.Enabled then begin
    Columns.ExchangeColumn( ColumnIndexFromGridColumn(Index),
      ColumnIndexFromGridColumn(WithIndex));
    ColRowExchanged(IsColumn, index, WithIndex);
    exit;
  end;
  // exchanges column widths or row heights
  if IsColumn then
    FCols.Exchange(index, WithIndex)
  else
    FRows.Exchange(index, WithIndex);
  ColRowExchanged(IsColumn, index, WithIndex);
  VisualChange;

  // adjust editor bounds
  if IsColumn then
    aColRow := FCol
  else
    aColRow := FRow;

  if Between(aColRow, Index, WithIndex) then begin
    if aColRow=Index then
      aColRow:=WithIndex
    else
    if aColRow=WithIndex then
      aColRow:=Index;
    if IsColumn then
      AdjustEditorBounds(aColRow, FRow)
    else
      AdjustEditorBounds(FCol, aColRow);
  end;

  // adjust sort column
  if IsColumn and (FSortColumn>=0) then begin
    if Between(FSortColumn, Index, WithIndex) then begin
      if FSortColumn=Index then
        FSortColumn := WithIndex
      else
      if FSortColumn=WithIndex then
        FSortColumn := Index;
    end;
  end;
end;

procedure TCustomGrid.DoOPInsertColRow(IsColumn: boolean; index: integer);
var
  NewCol,NewRow: Integer;
begin
  if IsColumn and (RowCount = 0) then
    Raise EGridException.Create(rsGridHasNoRows);
  if not IsColumn then
  begin
    if (Columns.Enabled and (Columns.Count = 0)) or (not Columns.Enabled and (ColCount = 0)) then
      Raise EGridException.Create(rsGridHasNoCols);
  end;

  if Index<0 then
    Index:=0;

  NewCol := Col;
  NewRow := Row;
  if IsColumn then begin
    if Index>ColCount-1 then
      Index := ColCount-1;
    if Index<FixedCols then
      inc(FFixedCols);
    if columns.Enabled then begin
      Columns.InsertColumn(ColumnIndexFromGridColumn(index));
      ColRowInserted(true, index);
      exit;
    end else begin
      FCols.Insert(Index, -1);
      FGCache.AccumWidth.Insert(Index, -1);
    end;
  end else begin
    Frows.Insert(Index, -1);
    FGCache.AccumHeight.Insert(Index, -1);
    if Index<FixedRows then
      inc(FFixedRows);
  end;
  ColRowInserted(IsColumn, index);
  VisualChange;

  // adjust editor bounds
  if IsColumn then begin
    if NewCol<FixedCols then
      NewCol := FixedCols
    else
    if Index<=NewCol then
      Inc(NewCol);
  end else begin
    if NewRow<FixedRows then
      NewRow := FixedRows
    else
    if Index<=NewRow then
      Inc(NewRow);
  end;
  AdjustEditorBounds(NewCol, NewRow);

  // adjust sorted column
  if IsColumn and (FSortColumn>=Index) then
    Inc(FSortColumn);
end;

procedure TCustomGrid.DoOPMoveColRow(IsColumn: Boolean; FromIndex,
  ToIndex: Integer);
var
  aColRow: Integer;
begin
  if FromIndex=ToIndex then
    exit;

  CheckIndex(IsColumn, FromIndex);
  CheckIndex(IsColumn, ToIndex);

  // move custom columns if they are not locked
  if IsColumn and Columns.Enabled and (not(gfColumnsLocked in FGridFlags)) then begin
    Columns.MoveColumn(ColumnIndexFromGridColumn(FromIndex),
      ColumnIndexFromGridColumn(ToIndex));
    // done
    exit;
  end;

  // move grids content
  if IsColumn then
    FCols.Move(FromIndex, ToIndex)
  else
    FRows.Move(FromIndex, ToIndex);
  ColRowMoved(IsColumn, FromIndex, ToIndex);

  if not IsColumn or not Columns.Enabled then
    VisualChange;

  // adjust editor bounds
  if IsColumn then
    aColRow:=FCol
  else
    aColRow:=FRow;
  if Between(aColRow, FromIndex, ToIndex) then begin
    if aColRow=FromIndex then
      aColRow := ToIndex
    else
    if FromIndex<aColRow then
      aColRow := aColRow-1
    else
      aColRow := aColRow+1;
    if IsColumn then
      AdjustEditorBounds(aColRow, FRow)
    else
      AdjustEditorBounds(FCol, aColRow);
  end;

  // adjust sorted column
  if IsColumn and (FSortColumn>=0) then
    if Between(FSortColumn, FromIndex, ToIndex) then begin
      if FSortColumn=FromIndex then
        FSortColumn := ToIndex
      else
      if FromIndex<FSortColumn then
        Dec(FSortColumn)
      else
        Inc(FSortColumn);
    end;
end;

procedure TCustomGrid.DoOPDeleteColRow(IsColumn: Boolean; index: Integer);

  procedure doDeleteColumn;
  var
    tmpIndex: Integer;
  begin
    CheckFixedCount(ColCount-1, RowCount, FFixedCols, FFixedRows);
    CheckCount(ColCount-1, RowCount, false);

    // before deleteing column hide editor
    if EditorMode and (Index=Col) then
      EditorMode:=False;

    if Columns.Enabled then
      tmpIndex := ColumnIndexFromGridColumn(Index);

    if Index<FixedCols then begin
      Dec(FFixedCols);
      FTopLeft.x := FFixedCols;
    end;

    FCols.Delete(Index);
    FGCache.AccumWidth.Delete(Index);

    ColRowDeleted(True, Index);

    if Columns.Enabled then
      Columns.RemoveColumn(tmpIndex);

    FixPosition(True, Index);
  end;

  procedure doDeleteRow;
  begin
    CheckFixedCount(ColCount, RowCount-1, FFixedCols, FFixedRows);
    CheckCount(ColCount, RowCount-1, false);
    // before deleteing row hide editor
    if EditorMode and (Index=Row) then
      EditorMode:=False;
    if Index<FixedRows then begin
      Dec(FFixedRows);
      FTopLeft.y := FFixedRows;
    end;
    FRows.Delete(Index);
    FGCache.AccumHeight.Delete(Index);
    ColRowDeleted(False,Index);
    FixPosition(False, Index);

    If FRowAutoInserted And (Index=FixedRows+(RowCount-1)) Then
      FRowAutoInserted := False;
  end;

begin
  CheckIndex(IsColumn,Index);
  if IsColumn then begin
    doDeleteColumn;
    if FSortColumn=Index then
      FSortColumn :=-1
    else
    if FSortColumn>Index then
      Dec(FSortColumn);
  end
  else
    doDeleteRow;
end;

function TCustomGrid.EditorByStyle(Style: TColumnButtonStyle): TWinControl;
begin
  case Style of
    cbsEllipsis:
      Result := FButtonStringEditor;
    cbsButton:
      Result := FButtonEditor;
    cbsPicklist:
      Result := FPicklistEditor;
    cbsAuto:
      Result := FStringEditor;
    else {cbsNone, cbsCheckboxColumn, cbsButtonColumn:}
      Result := nil;
  end;
end;

procedure TCustomGrid.MouseDown(Button: TMouseButton; Shift: TShiftState; X,
  Y: Integer);

  function CheckAutoEdit: boolean;
  begin
    result := FAutoEdit and not(csNoFocus in ControlStyle) and
              EditingAllowed(FCol) and (FGCache.ClickCell.X=Col) and (FGCache.ClickCell.Y=Row);
    if result then
      GridFlags := GridFlags + [gfAutoEditPending];
  end;

begin
  inherited MouseDown(Button, Shift, X, Y);

  if (csDesigning in componentState) or not MouseButtonAllowed(Button) then
    Exit;

  {$IfDef dbgGrid}DebugLnEnter('MouseDown %s INIT',[dbgsName(self)]); {$Endif}

  FIgnoreClick := True;

  {$IFDEF dbgGrid}
  DebugLn('Mouse was in ', dbgs(FGCache.HotGridZone));
  {$ENDIF}

  if not Focused and not(csNoFocus in ControlStyle) then begin
    SetFocus;
    if not Focused then begin
      {$ifDef dbgGrid} DebugLnExit('TCustomGrid.MouseDown EXIT: Focus not allowed'); {$Endif}
      exit;
    end;
  end;

  CacheMouseDown(X,Y);

  case FGCache.HotGridZone of

    gzFixedCells:
      begin
        if (goColSizing in Options) and (goFixedColSizing in Options) and
           (FCursorState=gcsColWidthChanging) then
          fGridState:= gsColSizing
        else begin
          FGridState := gsHeaderClicking;
          if ((goHeaderPushedLook in Options) and
              (FGCache.HotGridZone in FHeaderPushZones)) then
            DoPushCell;
        end;
      end;

    gzFixedCols:
      begin
        if (goColSizing in Options) and (FCursorState=gcsColWidthChanging) then begin
          fGridState:= gsColSizing;
          FGCache.OldMaxTopLeft := FGCache.MaxTopLeft;
        end
        else begin
          // ColMoving or Clicking
          if fGridState<>gsColMoving then begin
            fGridState:=gsColMoving;
            ResetLastMove;
          end;

          if ((goHeaderPushedLook in Options) and
              (FGCache.HotGridZone in FHeaderPushZones)) then
            DoPushCell;
        end;
      end;

    gzFixedRows:
      if (goRowSizing in Options) and (FCursorState=gcsRowHeightChanging) then
        fGridState:= gsRowSizing
      else begin
        // RowMoving or Clicking
        fGridState:=gsRowMoving;
        ResetLastMove;
        if ((goHeaderPushedLook in Options) and
            (FGCache.HotGridZone in FHeaderPushZones)) then
          DoPushCell;
      end;

    gzNormal:
      begin
        LockEditor;
        FIgnoreClick := False;
        UnlockEditor;
        if IsMouseOverCellButton(X, Y) then begin
          StartPushCell;
          Exit;
        end else
        if FExtendedColSizing and
          (FCursorState=gcsColWidthChanging) and
          (goColSizing in Options) then begin
          // extended column sizing
          fGridState:= gsColSizing;

        end
        else if not FixedGrid then begin
          // normal selecting
          fGridState:=gsSelecting;

          if not EditingAllowed(FCol) or
            (ExtendedSelect and not EditorAlwaysShown) then begin

            if ssShift in Shift then
              SelectActive:=(goRangeSelect in Options)
            else begin
              if (goRangeSelect in Options) and (FRangeSelectMode = rsmMulti)
              then begin
                if (MULTISEL_MODIFIER in Shift) then
                  AddSelectedRange
                else begin
                  ClearSelections;
                  Invalidate;
                end;
              end;

              // shift is not pressed any more cancel SelectActive if necessary
              if SelectActive then
                CancelSelection;

              if not SelectActive then begin
                CheckAutoEdit;
                GridFlags := GridFlags + [gfNeedsSelectActive];
                FPivot:=FGCache.ClickCell;

              end;
            end;

          end else if CheckAutoEDit then begin
            {$ifDef dbgGrid} DebugLnExit('MouseDown (autoedit) EXIT'); {$Endif}
            Exit;
          end;

          include(fGridFlags, gfEditingDone);
          try
            if not MoveExtend(False, FGCache.ClickCell.X, FGCache.ClickCell.Y, False) then begin
              if EditorAlwaysShown then begin
                SelectEditor;
                EditorShow(true);
              end;
              MoveSelection;
            end else
              FGridState:=gsSelecting;
          finally
            exclude(fGridFlags, gfEditingDone);
          end;

        end;
      end;
  end;
  {$ifDef dbgGrid}DebugLnExit('MouseDown END'); {$Endif}
end;

procedure TCustomGrid.MouseMove(Shift: TShiftState; X, Y: Integer);
var
  p: TPoint;
  obe: boolean;  // stored "AllowOutboundEvents"
begin
  inherited MouseMove(Shift, X, Y);

  if Dragging then
    exit;

  HeadersMouseMove(X,Y);

  case FGridState of
    gsHeaderClicking, gsButtonColumnClicking:
      ;
    gsSelecting:
      if not FixedGrid and (not EditingAllowed(-1) or
        (ExtendedSelect and not EditorAlwaysShown)) then begin
        P:=MouseToLogcell(Point(X,Y));
        if gfNeedsSelectActive in GridFlags then
          SelectActive := (P.x<>FPivot.x)or(P.y<>FPivot.y);
        MoveExtend(false, P.X, P.Y, false);
      end;
    gsColMoving:
      if goColMoving in Options then
        doColMoving(X,Y);
    gsRowMoving:
      if goRowMoving in Options then
        doRowMoving(X,Y);

    else
      begin
        if goColSizing in Options then
          doColSizing(X,Y);

        if goRowSizing in Options then
          doRowSizing(X,Y);

        obe := AllowOutboundEvents;
        AllowOutboundEvents := false;
        try
          p := MouseCoord(X, Y);
        finally
          AllowOutboundEvents := obe;
        end;

        // if we are not over a cell
        if p.X < 0 then
          begin
            // empty hints
            Application.Hint := '';
            Hint := '';
            // if FCellHintPriority = chpAll, restore default hint
            if ShowHint and (FCellHintPriority = chpAll) then
              begin
                Hint := FSavedHint;
                Application.Hint := GetLongHint(FSavedHint);
              end;
          end;

        with FGCache do
          if (MouseCell.X <> p.X) or (MouseCell.Y <> p.Y) then begin
            Application.CancelHint;
            ShowCellHintWindow(Point(X,Y));
            MouseCell := p;
          end;
      end;
  end;
end;

procedure TCustomGrid.MouseUp(Button: TMouseButton; Shift: TShiftState; X,
  Y: Integer);
var
   Cur: TPoint;
   Gz: TGridZone;

   function IsValidCellClick: boolean;
   begin
     result := (Cur.X=FGCache.ClickCell.X) and (Cur.Y=FGCache.ClickCell.Y) and (gz<>gzInvalid);
   end;

   procedure DoAutoEdit;
   begin
     if (gfAutoEditPending in GridFlags){ and not (ssDouble in Shift)} then begin
       SelectEditor;
       EditorShow(True);
     end;
   end;

begin
  inherited MouseUp(Button, Shift, X, Y);
  {$IfDef dbgGrid}DebugLn('MouseUP INIT');{$Endif}

  Cur:=MouseToCell(Point(x,y));
  Gz :=CellToGridZone(cur.x, cur.y);

  case fGridState of

    gsHeaderClicking, gsButtonColumnClicking:
      if IsValidCellClick then begin
        if fGridState=gsHeaderClicking then
          HeaderClick(True, FGCache.ClickCell.X)
        else
        if Assigned(OnEditButtonClick) or Assigned(OnButtonClick) then
          DoEditButtonClick(Cur.X, Cur.Y);
      end;

    gsNormal:
      if not FixedGrid and IsValidCellClick then begin
        doAutoEdit;
        CellClick(cur.x, cur.y, Button);
      end;

    gsSelecting:
      begin
        if SelectActive then
          MoveExtend(False, Cur.x, Cur.y, False)
        else begin
          doAutoEdit;
          CellClick(cur.x, cur.y, Button);
        end;
      end;

    gsColMoving:
      begin
        //DebugLn('Move Col From ',Fsplitter.x,' to ', FMoveLast.x);
        RestoreCursor;

        if FMoveLast.X>=0 then
          DoOPMoveColRow(True, FGCache.ClickCell.X, FMoveLast.X)
        else
        if Cur.X=FGCache.ClickCell.X then
          HeaderClick(True, FGCache.ClickCell.X)
      end;

    gsRowMoving:
      begin
        //DebugLn('Move Row From ',Fsplitter.Y,' to ', FMoveLast.Y);
        RestoreCursor;

        if FMoveLast.Y>=0 then
          DoOPMoveColRow(False, FGCache.ClickCell.Y, FMoveLast.Y)
        else
        if Cur.Y=FGCache.ClickCell.Y then
          HeaderClick(False, FGCache.ClickCell.Y);
      end;

    gsColSizing:
      if gfSizingStarted in FGridFlags then
      with FSizing do begin
        if FUseXORFeatures then begin
          if PrevLine then
            DrawXorVertLine(PrevOffset);
          PrevLine := False;
          PrevOffset := -1;
        end;
        if UseRightToLeftAlignment then
          ResizeColumn(Index, OffEnd - X + DeltaOff)
        else
          ResizeColumn(Index, X - OffIni + DeltaOff);
        FixScroll;
        HeaderSized(True, Index);
      end;

    gsRowSizing:
      with FSizing do begin
        if FUseXORFeatures then begin
          if PrevLine then
            DrawXorHorzLine(PrevOffset);
          PrevLine := False;
          PrevOffset := -1;
        end;
        ResizeRow(Index, Y - OffIni);
        HeaderSized(False, Index);
      end;

  end;

  GridFlags := GridFlags - [gfNeedsSelectActive, gfSizingStarted, gfAutoEditPending];

  if IsPushCellActive() then begin
    ResetPushedCell;
  end;

  if (FMoveLast.X>=0) or (FMoveLast.Y>=0) then begin
    {$ifdef AlternativeMoveIndicator}
    begin
      if FMoveLast.X>=0 then InvalidateRow(0);
      if FMoveLast.Y>=0 then InvalidateCol(0);
    end;
    {$else}
    Invalidate;
    {$endif}
    if not (fGridState in [gsColMoving,gsRowMoving]) then
      RestoreCursor;
  end;

  FGCache.ClickCell := point(-1, -1);

  fGridState:=gsNormal;
  {$IfDef dbgGrid}DebugLn('MouseUP  END  RND=', FloatToStr(Random));{$Endif}
end;

procedure TCustomGrid.DblClick;
var
  OldWidth: Integer;
begin
  {$IfDef dbgGrid}DebugLn('DoubleClick INIT');{$Endif}
  SelectActive:=False;
  fGridState:=gsNormal;
  if (goColSizing in Options) and (FCursorState=gcsColWidthChanging) then begin
    if (goDblClickAutoSize in Options) then begin
      OldWidth := ColWidths[FSizing.Index];
      AutoAdjustColumn( FSizing.Index );
      if OldWidth<>ColWidths[FSizing.Index] then begin
        RestoreCursor;
        HeaderSized(True, FSizing.Index);
      end;
    end {else
      DebugLn('Got Doubleclick on Col Resizing: AutoAdjust?');}
  end else
  if  (goDblClickAutoSize in Options) and
      (goRowSizing in Options) and
      (FCursorState=gcsRowHeightChanging) then begin
      {
        DebugLn('Got DoubleClick on Row Resizing: AutoAdjust?');
      }
  end
  else
    Inherited DblClick;
  {$IfDef dbgGrid}DebugLn('DoubleClick END');{$Endif}
end;

function TCustomGrid.DefaultColWidthIsStored: Boolean;
begin
  Result := FDefColWidth>=0;
end;

function TCustomGrid.DefaultRowHeightIsStored: Boolean;
begin
  Result := FDefRowHeight>=0;
end;

procedure TCustomGrid.DefineProperties(Filer: TFiler);

  function SonRowsIguales(aGrid: TCustomGrid): boolean;
  var
    i: Integer;
  begin
    result := aGrid.RowCount = RowCount;
    if Result then
      for i:=0 to RowCount-1 do
        if aGrid.RowHeights[i]<>RowHeights[i] then begin
          result := false;
          break;
        end;
  end;

  function SonColsIguales(aGrid: TCustomGrid): boolean;
  var
    i: Integer;
  begin
    result := aGrid.ColCount = ColCount;
    if Result then
      for i:=0 to ColCount-1 do
        if aGrid.ColWidths[i]<>ColWidths[i] then begin
          result := false;
          break;
        end;
  end;

  function SonDefault(IsColumn: Boolean; L1: TIntegerList): boolean;
  var
    i: Integer;
    DefValue: Integer;
  begin
    Result := True;
    if IsColumn then DefValue := DefaultColWidth
    else             DefValue := DefaultRowHeight;
    for i:=0 to L1.Count-1 do begin
      Result := (L1[i] = DefValue) or (L1[i] < 0);
      if not Result then
        break;
    end;
  end;

  function NeedWidths: boolean;
  begin
    if Filer.Ancestor is TCustomGrid then
      Result := not SonColsIguales(TCustomGrid(Filer.Ancestor))
    else
      Result := not SonDefault(True, FCols);
    //result := Result and not AutoFillColumns;
  end;

  function NeedHeights: boolean;
  begin
    if Filer.Ancestor is TCustomGrid then
      Result := not SonRowsIguales(TCustomGrid(Filer.Ancestor))
    else
      Result := not SonDefault(false, FRows);
  end;

  function HasColumns: boolean;
  var
    C: TGridColumns;
  begin
    if Filer.Ancestor is TCustomGrid then
      C := TCustomGrid(Filer.Ancestor).Columns
    else
      C := Columns;
    if C<>nil then
      result := not C.IsDefault
    else
      result := false;
  end;

begin
  inherited DefineProperties(Filer);
  with Filer do begin
    //DefineProperty('Columns',    @ReadColumns,    @WriteColumns,    HasColumns);
    DefineProperty('ColWidths',  @ReadColWidths,  @WriteColWidths,  NeedWidths);
    DefineProperty('RowHeights', @ReadRowHeights, @WriteRowHeights, NeedHeights);
  end;
end;

procedure TCustomGrid.DestroyHandle;
begin
  inherited DestroyHandle;
  editorGetValue;
end;

function TCustomGrid.DialogChar(var Message: TLMKey): boolean;
var
  i: Integer;
begin
  for i:=0 to Columns.Count-1 do
    if Columns[i].Visible and (Columns[i].Title.PrefixOption<>poNone) then
      if IsAccel(Message.CharCode, Columns[i].Title.Caption) then begin
        result := true;
        HeaderClick(True, GridColumnFromColumnIndex(i));
        exit;
      end;
  result := inherited DialogChar(Message);
end;

function TCustomGrid.DoCompareCells(Acol, ARow, Bcol, BRow: Integer): Integer;
begin
  result := 0;
  if Assigned(OnCompareCells) then
    OnCompareCells(Self, ACol, ARow, BCol, BRow, Result);
end;

procedure TCustomGrid.DoCopyToClipboard;
begin
end;

procedure TCustomGrid.DoCutToClipboard;
begin
end;

procedure TCustomGrid.DoEditButtonClick(const ACol, ARow: Integer);
var
  OldCol,OldRow: Integer;
begin
  OldCol:=FCol;
  OldRow:=FRow;
  try
    FCol:=ACol;
    FRow:=ARow;
    if Assigned(OnEditButtonClick) then
      OnEditButtonClick(Self);
    if Assigned(OnButtonClick) then
      OnButtonClick(Self, ACol, ARow);
  finally
    if (FCol=ACol) and (FRow=ARow) then
    begin
      // didn't change FRow or FCol, restore old index.
      FCol:=OldCol;
      FRow:=OldRow;
    end;
  end;
end;

procedure TCustomGrid.DoEditorHide;
var
  ParentForm: TCustomForm;
begin
  {$ifdef dbgGrid}DebugLnEnter('grid.DoEditorHide [',Editor.ClassName,'] INIT');{$endif}
  if gfEditingDone in FGridFlags then begin
    ParentForm := GetParentForm(Self);
    if Self.CanFocus then
      ParentForm.ActiveControl := self;
  end;
  Editor.Visible:=False;
  {$ifdef dbgGrid}DebugLnExit('grid.DoEditorHide [',Editor.ClassName,'] END');{$endif}
end;
procedure TCustomGrid.DoEditorShow;
var
  ParentChanged: Boolean;
  Column: TGridColumn;
begin
  {$ifdef dbgGrid}DebugLnEnter('grid.DoEditorShow [',Editor.ClassName,'] INIT');{$endif}
  ScrollToCell(FCol,FRow, True);
  // Under carbon, Editor.Parent:=nil destroy Editor handle, but not immediately
  // as in this case where keyboard event on editor is being handled.
  // After Editor.Visible:=true, a new handle is allocated but it's got overwritten
  // once the delayed destroying of previous handle happens, the result is a stalled
  // unparented editor ....
  ParentChanged := (Editor.Parent<>Self);
  if ParentChanged then
    Editor.Parent := nil;
  EditorSetValue;
  if ParentChanged then
    Editor.Parent:=Self;
  if (FEditor = FStringEditor) or (FEditor = FButtonStringEditor) then
  begin
    Column:=ColumnFromGridColumn(FCol);
    if Column<>nil then
      FStringEditor.Alignment:=Column.Alignment
    else
      FStringEditor.Alignment:=taLeftJustify;
  end;
  Editor.Visible:=True;
  if Focused and Editor.CanFocus then
    Editor.SetFocus;
  InvalidateCell(FCol,FRow,True);
  {$ifdef dbgGrid}DebugLnExit('grid.DoEditorShow [',Editor.ClassName,'] END');{$endif}
end;

procedure TCustomGrid.DoAutoAdjustLayout(const AMode: TLayoutAdjustmentPolicy;
  const AXProportion, AYProportion: Double);
var
  i: Integer;
  C: TGridColumn;
begin
  inherited;

  if AMode in [lapAutoAdjustWithoutHorizontalScrolling, lapAutoAdjustForDPI] then
  begin
    BeginUpdate;
    try
      for i := Columns.Count - 1 downto 0 do
      begin
        C := Columns.Items[i];
        C.MaxSize := Round(C.MaxSize * AXProportion);
        C.MinSize := Round(C.MinSize * AXProportion);
        if C.IsWidthStored then
          C.Width := Round(C.Width * AXProportion);
      end;

      for i := FRows.Count - 1 downto 0 do
        if FRows[i]>=0 then
          FRows[i] := Round(FRows[i] * AYProportion);

      for i := FCols.Count - 1 downto 0 do
        if FCols[i]>=0 then
          FCols[i] := Round(FCols[i] * AXProportion);

      if DefaultColWidthIsStored then
        DefaultColWidth := Round(DefaultColWidth * AXProportion)
      else
        FRealizedDefColWidth := 0;
      if DefaultRowHeightIsStored then
        DefaultRowHeight := Round(DefaultRowHeight * AYProportion)
      else
        FRealizedDefRowHeight := 0;
    finally
      EndUpdate;
    end;
  end;
end;

procedure TCustomGrid.DoPasteFromClipboard;
begin
  //
end;

procedure TCustomGrid.DoPrepareCanvas(aCol,aRow:Integer; aState: TGridDrawState);
begin
  if Assigned(OnPrepareCanvas) then
    OnPrepareCanvas(Self, aCol, aRow, aState);
end;

procedure TCustomGrid.DoOnResize;
begin
  inherited DoOnResize;
  if FUpdateCount=0 then
    TWSCustomGridClass(WidgetSetClass).Invalidate(Self);
end;

procedure TCustomGrid.DoSetBounds(ALeft, ATop, AWidth, AHeight: integer);
begin
  FLastWidth := ClientWidth;
  inherited DoSetBounds(ALeft, ATop, AWidth, AHeight);
end;

function TCustomGrid.DoUTF8KeyPress(var UTF8Key: TUTF8Char): boolean;
begin
  Result := inherited DoUTF8KeyPress(UTF8Key);
  if EditingAllowed(FCol) and (not result) and (Length(UTF8Key)>1) then begin
    EditorShowChar(UTF8Key);
    UTF8Key := '';
    Result := true
  end;
end;

function TCustomGrid.FlipRect(ARect: TRect): TRect;
begin
  Result := BidiFlipRect(ARect, GCache.ClientRect, UseRightToLeftAlignment);
end;

function TCustomGrid.FlipPoint(P: TPoint): TPoint;
begin
  Result := BidiFlipPoint(P, GCache.ClientRect, UseRightToLeftAlignment);
end;

function TCustomGrid.FlipX(X: Integer): Integer;
begin
  Result := BidiFlipX(X, GCache.ClientRect, UseRightToLeftAlignment);
end;

function TCustomGrid.IsMouseOverCellButton(X, Y: Integer): boolean;
var
  oldAOE: Boolean;
  P: TPoint;
begin
  oldAOE := AllowOutboundEvents;
  AllowOutboundEvents := false;
  P := MouseToCell(Point(X,Y));
  AllowOutBoundEvents := OldAOE;
  result := IsCellButtonColumn(P);
end;

procedure TCustomGrid.DoExit;
begin
  if not (csDestroying in ComponentState) then begin
    {$IfDef dbgGrid}DebugLnEnter('DoExit - INIT');{$Endif}
    if FEditorShowing then begin
      {$IfDef dbgGrid}DebugLn('DoExit - EditorShowing');{$Endif}
    end else begin
      {$IfDef dbgGrid}DebugLn('DoExit - Ext');{$Endif}
      if not EditorAlwaysShown then
        InvalidateFocused;
      ResetEditor;
      if FgridState=gsSelecting then begin
        if SelectActive then
          FSelectActive := False;
        FGridState := gsNormal;
      end;
    end;
  end;
  inherited DoExit;
  {$IfDef dbgGrid}DebugLnExit('DoExit - END');{$Endif}
end;

procedure TCustomGrid.DoEnter;
begin
  {$IfDef dbgGrid}DebugLnEnter('DoEnter %s INIT',[dbgsname(self)]);{$Endif}
  inherited DoEnter;
  if EditorLocked then begin
    {$IfDef dbgGrid}DebugLn('DoEnter - EditorLocked');{$Endif}
  end else begin
    {$IfDef dbgGrid}DebugLn('DoEnter - Ext');{$Endif}
    if EditorAlwaysShown then begin
      // try to show editor only if focused cell is visible area
      // so a mouse click would use click coords to show up
      if IsCellVisible(Col,Row) then begin
        SelectEditor;
        if Feditor<>nil then
          EditorShow(true);
      end else begin
      {$IfDef dbgGrid}DebugLn('DoEnter - Ext - Cell was not visible');{$Endif}
      end;
    end else
      InvalidateFocused;
  end;
  {$IfDef dbgGrid}DebugLnExit('DoEnter - END');{$Endif}
end;

procedure TCustomGrid.DoLoadColumn(sender: TCustomGrid; aColumn: TGridColumn;
  aColIndex: Integer; aCfg: TXMLConfig; aVersion: Integer; aPath: string);
begin
  if Assigned(FOnLoadColumn) then
    FOnLoadColumn(Self, aColumn, aColIndex, aCfg, aVersion, aPath);
end;

procedure TCustomGrid.DoSaveColumn(sender: TCustomGrid; aColumn: TGridColumn;
  aColIndex: Integer; aCfg: TXMLConfig; aVersion: Integer; aPath: string);
begin
  if Assigned(FOnSaveColumn) then
    FOnSaveColumn(Self, aColumn, aColIndex, aCfg, aVersion, aPath);
end;

function TCustomGrid.DoMouseWheel(Shift: TShiftState; WheelDelta: Integer;
  MousePos: TPoint): Boolean;
begin
  if FMouseWheelOption=mwCursor then
    FSelectActive := false;
  Result:=inherited DoMouseWheel(Shift, WheelDelta, MousePos);
end;

function TCustomGrid.DoMouseWheelDown(Shift: TShiftState; MousePos: TPoint
  ): Boolean;
begin
  {$ifdef dbgScroll}DebugLn('doMouseWheelDown INIT');{$endif}
  Result:=inherited DoMouseWheelDown(Shift, MousePos);
  if not Result then begin
    GridMouseWheel(Shift, 1);
    Result := True; // handled, no further scrolling by the widgetset
  end;
  {$ifdef dbgScroll}DebugLn('doMouseWheelDown END');{$endif}
end;

function TCustomGrid.DoMouseWheelUp(Shift: TShiftState; MousePos: TPoint
  ): Boolean;
begin
  {$ifdef dbgScroll}DebugLn('doMouseWheelUP INIT');{$endif}
  Result:=inherited DoMouseWheelUp(Shift, MousePos);
  if not Result then begin
    GridMouseWheel(Shift, -1);
    Result := True; // handled, no further scrolling by the widgetset
  end;
  {$ifdef dbgScroll}DebugLn('doMouseWheelUP END');{$endif}
end;

function TCustomGrid.DoMouseWheelLeft(Shift: TShiftState; MousePos: TPoint
  ): Boolean;
begin
  {$ifdef dbgScroll}DebugLn('doMouseWheelLEFT INIT');{$endif}
  Result:=inherited DoMouseWheelLeft(Shift, MousePos);
  if not Result then begin
    GridMouseWheel([ssCtrl], -1);
    Result := True; // handled, no further scrolling by the widgetset
  end;
  {$ifdef dbgScroll}DebugLn('doMouseWheelLEFT END');{$endif}
end;

function TCustomGrid.DoMouseWheelRight(Shift: TShiftState; MousePos: TPoint
  ): Boolean;
begin
  {$ifdef dbgScroll}DebugLn('doMouseWheelRIGHT INIT');{$endif}
  Result:=inherited DoMouseWheelRight(Shift, MousePos);
  if not Result then begin
    GridMouseWheel([ssCtrl], 1);
    Result := True; // handled, no further scrolling by the widgetset
  end;
  {$ifdef dbgScroll}DebugLn('doMouseWheelRIGHT END');{$endif}
end;

procedure TCustomGrid.DoOnChangeBounds;
var
  OldTopLeft: TPoint;
  OldColOff, OldRowOff: Integer;
begin
  inherited DoOnChangeBounds;

  if FUpdateCount=0 then
  begin
    OldTopLeft := fTopLeft;
    OldColOff := FGCache.TLColOff;
    OldRowOff := FGCache.TLRowOff;
    UpdateSizes;
    if (OldTopLeft.X<>FTopLeft.X) or (OldTopLeft.Y<>FTopLeft.Y)
    or (OldColOff<>FGCache.TLColOff) or (OldRowOff<>FGCache.TLRowOff) then // reduce unnecessary repaints
      Invalidate;
  end;
end;

procedure TCustomGrid.KeyDown(var Key: Word; Shift: TShiftState);
var
  Sh, PreserveRowAutoInserted: Boolean;
  R: TRect;
  Relaxed: Boolean;
  DeltaCol,DeltaRow: Integer;

  procedure MoveSel(Rel: Boolean; aCol,aRow: Integer);
  begin
    // Do not reset Offset in keyboard Events - see issue #29420
    //FGCache.TLColOff:=0;
    //FGCache.TLRowOff:=0;
    SelectActive:=Sh;
    Include(FGridFlags, gfEditingDone);
    if MoveNextSelectable(Rel, aCol, aRow) then
      Click;
    Exclude(FGridFlags, gfEditingDone);
    Key := 0; { Flag key as handled, even if selected cell did not move }
  end;

  procedure TabCheckEditorKey;
  begin
    if FEditorKey then begin
      {$IFDEF dbggrid}
      DebugLn('Got TAB, shift=',dbgs(sh));
      {$endif}
      if sh then
        GridFlags := GridFlags + [gfRevEditorTab]
      else
        GridFlags := GridFlags + [gfEditorTab];
    end;
  end;

const
  cBidiMove: array[Boolean] of Integer = (1, -1);
begin
  {$ifdef dbgGrid}DebugLn('Grid.KeyDown INIT Key=',IntToStr(Key));{$endif}
  inherited KeyDown(Key, Shift);
  //Don't touch FRowAutoInserted flag if user presses only Ctrl,Shift,Altor Meta/Win key
  PreserveRowAutoInserted := (Key in [VK_SHIFT,VK_CONTROL,VK_LWIN,VK_RWIN,VK_MENU]);

  //if not FGCache.ValidGrid then Exit;
  if not CanGridAcceptKey(Key, Shift) then
    Key:=0;  // Allow CanGridAcceptKey to override Key behaviour
  Sh:=(ssShift in Shift);
  Relaxed := not (goRowSelect in Options) or (goRelaxedRowSelect in Options);

  case Key of
    VK_TAB:
      if goTabs in Options then begin
        if GetDeltaMoveNext(Sh, DeltaCol,DeltaRow,FTabAdvance) then begin
          Sh := False;
          MoveSel(True, DeltaCol, DeltaRow);
          PreserveRowAutoInserted := True;
          Key:=0;
        end else if (goAutoAddRows in Options) and (DeltaRow = 1) then begin
          //prevent selecting multiple cells when user presses Shift
          Sh := False;
          if (goAutoAddRowsSkipContentCheck in Options) or (not IsEmptyRow(Row)) then MoveSel(True, DeltaCol, DeltaRow);
          Key := 0;
          PreserveRowAutoInserted := True;
        end else
        if (TabAdvance=aaNone) or
           ((TabAdvance=aaDown) and (Row>=GetLastVisibleRow)) or
           (sh and (Col<=GetFirstVisibleColumn)) or
           ((not sh) and (Col>=GetLastVisibleColumn)) then
          TabCheckEditorKey
        else
          Key := 0;
      end else
        TabCheckEditorKey;
    VK_LEFT:
      //Don't move to another cell is user is editing
      if not FEditorKey then
      begin
        if Relaxed then
          MoveSel(True, -cBidiMove[UseRightToLeftAlignment], 0)
        else
          MoveSel(True, 0,-1);
      end;
    VK_RIGHT:
      //Don't move to another cell is user is editing
      if not FEditorKey then
      begin
        if Relaxed then
          MoveSel(True, cBidiMove[UseRightToLeftAlignment], 0)
        else
          MoveSel(True, 0, 1);
      end;
    VK_UP:
        MoveSel(True, 0, -1);
    VK_DOWN:
        MoveSel(True, 0, 1);
    VK_PRIOR:
      begin
        R:=FGCache.FullVisiblegrid;
        MoveSel(True, 0, R.Top-R.Bottom);
      end;
    VK_NEXT:
      begin
        R:=FGCache.FullVisibleGrid;
        MoveSel(True, 0, R.Bottom-R.Top);
      end;
    VK_HOME:
      if ssCtrl in Shift then MoveSel(False, FCol, FFixedRows)
      else
        if Relaxed then MoveSel(False, FFixedCols, FRow)
        else            MoveSel(False, FCol, FFixedRows);
    VK_END:
      if ssCtrl in Shift then MoveSel(False, FCol, RowCount-1)
      else
        if Relaxed then MoveSel(False, ColCount-1, FRow)
        else            MoveSel(False, FCol, RowCount-1);
    VK_APPS:
      if not FEditorKey and EditingAllowed(FCol) then
        EditorShow(False);               // Will show popup menu in the editor.
    VK_F2:
      if not FEditorKey and EditingAllowed(FCol) then begin
        SelectEditor;
        EditorShow(False);
        Key:=0;
      end ;
    VK_BACK:
      // Workaround: LM_CHAR doesnt trigger with BACKSPACE
      if not FEditorKey and EditingAllowed(FCol) then begin
        EditorShowChar(^H);
        key:=0;
      end;
    VK_C:
      if not FEditorKey and (Shift = [ssModifier]) then
        doCopyToClipboard;
    VK_V:
      if not FEditorKey and (Shift = [ssModifier]) then
        doPasteFromClipboard;
    VK_X:
      if not FEditorKey and (Shift = [ssShift]) then
        doCutToClipboard;
    VK_DELETE:
      if not FEditorKey and EditingAllowed(FCol) and
         not (csDesigning in ComponentState) then begin
        if Editor=nil then
          SelectEditor;
        if Editor is TCustomEdit then begin
          EditorShow(False);
          TCustomEdit(Editor).Text:='';
          InvalidateCell(FCol,FRow,True);
          EditorShow(True);
          Key := 0;
        end;
      end;
    VK_ESCAPE:
      begin
        EditordoResetValue;
        EditorHide;
        Key := 0;
      end;
  end;
  if FEditorKey and (not PreserveRowAutoInserted) then
    FRowAutoInserted:=False;
  {$ifdef dbgGrid}DebugLn('Grid.KeyDown END Key=',IntToStr(Key));{$endif}
end;

procedure TCustomGrid.KeyUp(var Key: Word; Shift: TShiftState);
begin
  inherited KeyUp(Key, Shift);
end;

procedure TCustomGrid.KeyPress(var Key: char);
begin
  inherited KeyPress(Key);
  if not EditorKey then
    // we are interested in these keys only if they came from the grid
    if not EditorMode and EditingAllowed(FCol) then begin
      if (Key=#13) then begin
        SelectEditor;
        EditorShow(True);
        Key := #0;
      end else
      if (Key in [^H, #32..#255]) then begin
        EditorShowChar(Key);
        Key := #0;
      end;
    end;
end;

{ Convert a physical Mouse coordinate into a physical cell coordinate }
function TCustomGrid.MouseToCell(const Mouse: TPoint): TPoint;
begin
  MouseToCell(Mouse.X, Mouse.Y, Result.X, Result.Y);
end;

procedure TCustomGrid.MouseToCell(X, Y: Integer; out ACol, ARow: Longint);
var
  dummy: Integer;
begin
  // Do not raise Exception if out of range
  OffsetToColRow(True, True, X, ACol, dummy);
  if ACol<0 then
    ARow := -1
  else begin
    OffsetToColRow(False,True, Y, ARow, dummy);
    if ARow<0 then
      ACol := -1;
  end;
end;

{ Convert a physical Mouse coordinate into a logical cell coordinate }
function TCustomGrid.MouseToLogcell(Mouse: TPoint): TPoint;
var
  gz: TGridZone;
begin
  Gz:=MouseToGridZone(Mouse.x, Mouse.y);
  Result:=MouseToCell(Mouse);
  if gz<>gzNormal then begin
    if (gz=gzFixedRows)or(gz=gzFixedCells) then begin
      Result.x:= fTopLeft.x-1;
      if Result.x<FFixedCols then Result.x:=FFixedCols;
    end;
    if (gz=gzFixedCols)or(gz=gzFixedCells) then begin
      Result.y:=fTopleft.y-1;
      if Result.y<fFixedRows then Result.y:=FFixedRows;
    end;
  end;
end;

function TCustomGrid.MouseCoord(X, Y: Integer): TGridCoord;
begin
  Result := MouseToCell(Point(X,Y));
end;

function TCustomGrid.IsCellVisible(aCol, aRow: Integer): Boolean;
begin
  with FGCache.VisibleGrid do
    Result:= (Left<=ACol)and(aCol<=Right)and(Top<=aRow)and(aRow<=Bottom);
end;

function TCustomGrid.IsFixedCellVisible(aCol, aRow: Integer): boolean;
begin
  with FGCache.VisibleGrid do
    result := ((aCol<FixedCols) and ((aRow<FixedRows) or ((aRow>=Top)and(aRow<=Bottom)))) or
              ((aRow<FixedRows) and ((aCol<FixedCols) or ((aCol>=Left)and(aCol<=Right))));
end;

procedure TCustomGrid.InvalidateCol(ACol: Integer);
var
  R: TRect;
begin
  {$ifdef dbgPaint} DebugLn('InvalidateCol  Col=',IntToStr(aCol)); {$Endif}
  if not HandleAllocated then
    exit;
  R:=CellRect(aCol, FTopLeft.y);
  R.Top:=0; // Full Column
  R.Bottom:=FGCache.MaxClientXY.Y;
  InvalidateRect(Handle, @R, True);
end;

procedure TCustomGrid.InvalidateFromCol(ACol: Integer);
var
  R: TRect;
begin
  {$IFDEF dbgPaint} DebugLn('InvalidateFromCol  Col=',IntToStr(aCol)); {$Endif}
  if not HandleAllocated then
    exit;
  R:=CellRect(aCol, FTopLeft.y);
  R.Top:=0; // Full Column
  R.BottomRight := FGCache.MaxClientXY;
  InvalidateRect(Handle, @R, True);
end;

procedure TCustomGrid.InvalidateRow(ARow: Integer);
var
  R: TRect;
begin
  {$ifdef DbgPaint} DebugLn('InvalidateRow  Row=',IntToStr(aRow)); {$Endif}
  if not HandleAllocated then
    exit;
  R:=CellRect(fTopLeft.x, aRow);
  if UseRightToLeftAlignment then begin
    R.Left:=FlipX(FGCache.MaxClientXY.X);
    R.Right:=FGCache.ClientRect.Right;
  end
  else begin
    R.Left:=0; // Full row
    R.Right:=FGCache.MaxClientXY.X;
  end;
  InvalidateRect(Handle, @R, True);
end;

procedure TCustomGrid.InvalidateFocused;
begin
  if FGCache.ValidGrid then begin
    {$ifdef dbgGrid}DebugLn('InvalidateFocused');{$Endif}
    if ((goRowSelect in Options) or (goRowHighlight in Options)) then
      InvalidateRow(Row)
    else
      InvalidateCell(Col,Row);
  end;
end;

function TCustomGrid.MoveExtend(Relative: Boolean; DCol, DRow: Integer;
  ForceFullyVisible: Boolean): Boolean;
var
  OldRange: TRect;
  prevCol, prevRow: Integer;
begin
  Result:=TryMoveSelection(Relative,DCol,DRow);
  if (not Result) then Exit;

  Result:=EditorGetValue(true);
  if (not Result) then Exit;

  {$IfDef dbgGrid}DebugLnEnter('MoveExtend INIT FCol= ',IntToStr(FCol), ' FRow= ',IntToStr(FRow));{$Endif}
  BeforeMoveSelection(DCol,DRow);

  OldRange := FRange;
  PrevRow := FRow;
  PrevCol := FCol;

  if goRowSelect in Options then
    FRange:=Rect(FFixedCols, DRow, Colcount-1, DRow)
  else
    FRange:=Rect(DCol,DRow,DCol,DRow);

  if SelectActive and (goRangeSelect in Options) then
    if goRowSelect in Options then begin
      FRange.Top:=Min(fPivot.y, DRow);
      FRange.Bottom:=Max(fPivot.y, DRow);
    end else
      FRange:=NormalizarRect(Rect(Fpivot.x,FPivot.y, DCol, DRow));

  if not ScrollToCell(DCol, DRow, ForceFullyVisible) then
    InvalidateMovement(DCol, DRow, OldRange);

  FCol := DCol;
  FRow := DRow;

  MoveSelection;
  SelectEditor;

  if (FEditor<>nil) and EditorAlwaysShown then begin
    // if editor visibility was changed on BeforeMoveSelection or MoveSelection
    // make sure editor will be updated.
    // TODO: cell coords of last time editor was visible
    //       could help here too, if they are not the same as the
    //       current cell, editor should be hidden first too.
    if FEditor.Visible then
      EditorHide;
    EditorShow(true);
  end;

  AfterMoveSelection(PrevCol,PrevRow);

  {$IfDef dbgGrid}DebugLnExit('MoveExtend END FCol= ',IntToStr(FCol), ' FRow= ',IntToStr(FRow));{$Endif}
end;

function TCustomGrid.MoveNextAuto(const Inverse: boolean): boolean;
var
  aCol,aRow: Integer;
begin
  Result := GetDeltaMoveNext(Inverse, ACol, ARow, FAutoAdvance);
  if Result then
    MoveNextSelectable(true, aCol, aRow);
end;

function TCustomGrid.MoveNextSelectable(Relative: Boolean; DCol, DRow: Integer): Boolean;
var
  CInc,RInc: Integer;
  NCol,NRow: Integer;
begin
  // Reference
  if not Relative then begin
    NCol:=DCol;
    NRow:=DRow;
    DCol:=NCol-FCol;
    DRow:=NRow-FRow;
  end else begin
    NCol:=FCol+DCol;
    NRow:=FRow+DRow;
    if (goEditing in options) and (goAutoAddRows in options) then begin
      if (DRow=1) and (NRow>=RowCount) then begin
        // If the last row has data or goAutoAddRowsSkipContentCheck is set, add a new row.
        if (not FRowAutoInserted) then begin
          if (goAutoAddRowsSkipContentCheck in Options) or (not IsEmptyRow(FRow)) then begin
            RowCount:=RowCount+1;
            if not (goAutoAddRowsSkipContentCheck in Options) then FRowAutoInserted:=True;
          end;
        end;
      end
      else if FRowAutoInserted and (DRow=-1) then begin
        RowCount:=RowCount-1;
        FRowAutoInserted:=False;
        ScrollToCell(Col, Row, True);
      end;
    end;
  end;

  Checklimits(NCol, NRow);

  // Increment
  if DCol<0 then CInc:=-1 else
  if DCol>0 then CInc:= 1
  else           CInc:= 0;
  if DRow<0 then RInc:=-1 else
  if DRow>0 then RInc:= 1
  else           RInc:= 0;

  // Calculate
  Result:=False;
  while ((ColWidths[NCol]=0)  and (CInc<>0))
     or ((RowHeights[NRow]=0) and (RInc<>0)) do
  begin
    if not (IsRowIndexVariable(NRow+RInc) and IsColumnIndexVariable(NCol+CInc)) then
      Exit;
    Inc(NCol, CInc);
    Inc(NRow, RInc);
  end;
  Result:=MoveExtend(False, NCol, NRow, True);

  // whether or not a movement was valid if goAlwaysShowEditor
  // is set, editor should pop up.
  if not EditorMode and EditorAlwaysShown then begin
    SelectEditor;
    if Feditor<>nil then
      EditorShow(true);
  end;
end;

function TCustomGrid.TryMoveSelection(Relative: Boolean; var DCol, DRow: Integer
  ): Boolean;
begin
  Result:=False;

  if FixedGrid then
    exit;

  if Relative then begin
    Inc(DCol, FCol);
    Inc(DRow, FRow);
  end;

  CheckLimits(DCol, DRow);

  // Change on Focused cell?
  if (DCol=FCol) and (DRow=FRow) then
    SelectCell(DCol,DRow)
  else
    Result:=SelectCell(DCol,DRow);
end;

procedure TCustomGrid.UnLockEditor;
begin
  if FEDitorHidingCount>0 then
    Dec(FEditorHidingCount)
  else
    DebugLn('WARNING: unpaired Unlock Editor');
  {$ifdef dbgGrid}DebugLn('==< LockEditor: ', dbgs(FEditorHidingCount)); {$endif}
end;

procedure TCustomGrid.UpdateHorzScrollBar(const aVisible: boolean;
  const aRange,aPage,aPos: Integer);
var
  NeedUpdate: Boolean;
begin
  {$ifdef DbgScroll}
  DebugLn('TCustomGrid.UpdateHorzScrollbar: Vis=%s Range=%d Page=%d aPos=%d',
    [dbgs(aVisible),aRange, aPage, aPos]);
  {$endif}
  NeedUpdate := FHSbVisible <> Ord(AVisible);
  if NeedUpdate then
    ScrollBarShow(SB_HORZ, aVisible);
  if aVisible or NeedUpdate then
    ScrollBarRange(SB_HORZ, aRange, aPage, aPos);
end;

procedure TCustomGrid.UpdateVertScrollbar(const aVisible: boolean;
  const aRange,aPage,aPos: Integer);
begin
  {$ifdef DbgScroll}
  DebugLn('TCustomGrid.UpdateVertScrollbar: Vis=%s Range=%d Page=%d aPos=%d',
    [dbgs(aVisible),aRange, aPage, aPos]);
  {$endif}
  if FVSbVisible<>Ord(aVisible) then
    ScrollBarShow(SB_VERT, aVisible);
  if aVisible then
    ScrollbarRange(SB_VERT, aRange, aPage, aPos );
end;

procedure TCustomGrid.UpdateBorderStyle;
var
  ABorderStyle: TBorderStyle;
begin
  if not Flat and (FGridBorderStyle=bsSingle) then
    ABorderStyle := bsSingle
  else
    ABorderStyle := bsNone;
  inherited SetBorderStyle(ABorderStyle);
  if HandleAllocated and ([csDestroying,csLoading]*ComponentState=[]) then
  begin
    VisualChange;
    if CheckTopLeft(Col, Row, True, True) then
      VisualChange;
  end;
end;

function TCustomGrid.ValidateEntry(const ACol, ARow: Integer;
  const OldValue:string; var NewValue:string): boolean;
begin
  result := true;
  if assigned(OnValidateEntry) then begin
    try
      OnValidateEntry(Self, ACol, ARow, OldValue, NewValue);
    except
      on E:Exception do begin
        result := false;
        if FGridState=gsSelecting then
          FGridState := gsNormal;
        Application.HandleException(E);
      end;
    end;
  end;
end;

procedure TCustomGrid.BeforeMoveSelection(const DCol,DRow: Integer);
begin
  if Assigned(OnBeforeSelection) then OnBeforeSelection(Self, DCol, DRow);
end;

procedure TCustomGrid.BeginAutoDrag;
begin
  if ((goColSizing in Options) and (FCursorState=gcsColWidthChanging)) or
     ((goRowSizing in Options) and (FCursorState=gcsRowHeightChanging))
  then
    // TODO: Resizing in progress, add an option to forbid resizing
    //       when DragMode=dmAutomatic
  else
    BeginDrag(False);
end;

procedure TCustomGrid.CalcAutoSizeColumn(const Index: Integer; var AMin, AMax,
  APriority: Integer);
begin
  APriority := 0;
end;

procedure TCustomGrid.CalcCellExtent(acol, aRow: Integer; var aRect: TRect);
begin
  //
end;

procedure TCustomGrid.CalcFocusRect(var ARect: TRect; adjust: boolean = true);
begin
  if goRowSelect in Options then begin

    if UseRightToLeftAlignment then begin
      aRect.Left := GCache.ClientWidth - GCache.MaxClientXY.x;
      aRect.Right := GCache.ClientWidth - GCache.FixedWidth;
    end else begin
      aRect.Left := GCache.FixedWidth;
      aRect.Right := GCache.MaxClientXY.x;
    end;

    FlipRect(aRect);
  end;

  if not adjust then
    exit;

  if goHorzLine in Options then
    dec(aRect.Bottom, 1 + FGridLineWidth div 2);

  if goVertLine in Options then
    if UseRightToLeftAlignment then
      inc(aRect.Left, 1 + FGridLineWidth div 2)
    else
      dec(aRect.Right, 1 + FGridLineWidth div 2);
end;

procedure TCustomGrid.CalcScrollbarsRange;
var
  HsbVisible, VsbVisible: boolean;
  HsbRange,VsbRange: Integer;
  HsbPage, VsbPage: Integer;
  HsbPos, VsbPos: Integer;
begin
  with FGCache do begin
    GetSBVisibility(HsbVisible, VsbVisible);
    GetSBRanges(HsbVisible,VsbVisible,HsbRange,VsbRange,HsbPage,VsbPage,HsbPos,VsbPos);
    UpdateVertScrollBar(VsbVisible, VsbRange, VsbPage, VsbPos);
    UpdateHorzScrollBar(HsbVisible, HsbRange, HsbPage, HsbPos);
    {$ifdef DbgScroll}
    DebugLn('VRange=',dbgs(VsbRange),' Visible=',dbgs(VSbVisible));
    DebugLn('HRange=',dbgs(HsbRange),' Visible=',dbgs(HSbVisible));
    {$endif}
  end;
end;

procedure TCustomGrid.CalculatePreferredSize(var PreferredWidth,
  PreferredHeight: integer; WithThemeSpace: Boolean);
begin
  PreferredWidth:=0;
  PreferredHeight:=0;
end;

procedure TCustomGrid.CalcMaxTopLeft;
var
  i: Integer;
  W,H: Integer;
begin
  FGCache.MaxTopLeft:=Point(ColCount-1, RowCount-1);
  FGCache.MaxTLOffset.x:=0;
  FGCache.MaxTLOffset.y:=0;
  W:=0;
  if not(goScrollToLastCol in FOptions2) then
  begin
    for i:=ColCount-1 downto FFixedCols do
    begin
      W:=W+GetColWidths(i);
      if W<=FGCache.ScrollWidth then
        FGCache.MaxTopLeft.x:=i
      else
      begin
        if GetSmoothScroll(SB_Horz) then
        begin
          FGCache.MaxTopLeft.x:=i;
          FGCache.MaxTLOffset.x:=W-FGCache.ScrollWidth;
        end;
        Break;
      end;
    end;
  end;
  H:=0;
  if not(goScrollToLastRow in FOptions2) then
  begin
    for i:=RowCount-1 downto FFixedRows do
    begin
      H:=H+GetRowHeights(i);
      if H<=FGCache.ScrollHeight then
        FGCache.MaxTopLeft.y:=i
      else
      begin
        if GetSmoothScroll(SB_Vert) then
        begin
          FGCache.MaxTopLeft.y:=i;
          FGCache.MaxTLOffset.y:=H-FGCache.ScrollHeight
        end;
        Break;
      end;
    end;
  end;
  FGCache.MaxTopLeft.x:=Max(FGCache.MaxTopLeft.x, FixedCols);
  FGCache.MaxTopLeft.y:=Max(FGCache.MaxTopLeft.y, FixedRows);
end;

procedure TCustomGrid.CellClick(const aCol, aRow: Integer; const Button:TMouseButton);
begin
end;

procedure TCustomGrid.CellExtent(const aCol, aRow: Integer; var R: TRect; out
  exCol: Integer);
var
  Extent: TRect;
begin
  Extent := R;
  exCol := aCol;
  CalcCellExtent(aCol, aRow, R);
  // TODO: check RTL
  while (exCol<=FGCache.VisibleGrid.Right) and (Extent.Right<R.Right) do begin
    inc(exCol);
    ColRowToOffset(True, True, exCol, Extent.Left, Extent.Right);
  end;
end;

procedure TCustomGrid.CheckLimits(var aCol, aRow: Integer);
begin
  if aCol<FFixedCols then aCol:=FFixedCols else
  if aCol>ColCount-1 then acol:=ColCount-1;
  if aRow<FFixedRows then aRow:=FFixedRows else
  if aRow>RowCount-1 then aRow:=RowCount-1;
end;

// We don't want to do this inside CheckLimits() because keyboard handling
// shouldn't raise an error whereas setting the Row or Col property it should.
procedure TCustomGrid.CheckLimitsWithError(const aCol, aRow: Integer);
begin
  if not IsColumnIndexValid(aCol) or not IsRowIndexValid(aRow) then
    raise EGridException.Create(rsGridIndexOutOfRange);
end;

procedure TCustomGrid.ClearSelections;
begin
  SetLength(FSelections, 0);
  UpdateSelectionRange;
  FPivot := Point(Col, Row);
  InvalidateGrid;
end;

procedure TCustomGrid.CMBiDiModeChanged(var Message: TLMessage);
begin
  VisualChange;
  inherited CMBidiModeChanged(Message);
end;

procedure TCustomGrid.CMMouseEnter(var Message: TLMessage);
begin
  inherited;
  FSavedHint := Hint;
  // Note: disable hint when entering grid's border, we'll manage our own hints
  Application.Hint := '';
  Application.CancelHint;
end;

procedure TCustomGrid.CMMouseLeave(var Message: TLMessage);
begin
  Hint := FSavedHint;
  ResetHotCell;
  inherited CMMouseLeave(Message);
end;

// This procedure checks if cursor cell position is allowed
// if not it tries to find a suitable position based on
// AutoAdvance and SelectCell.
procedure TCustomGrid.CheckPosition;
var
  OldAA: TAutoAdvance;
  DeltaCol,DeltaRow: Integer;
begin
  // first tries to find if current position is allowed
  if SelectCell(Col,Row) then
    exit;

  // current position is not valid, look for another position
  OldAA := FAutoAdvance;

  if OldAA=aaNone then
    FAutoAdvance := aaRightDown;

  try
    // try first normal movement then inverse movement
    if GetDeltaMoveNext(false, DeltaCol,DeltaRow,FAutoAdvance) or
       GetDeltaMoveNext(true,  DeltaCol,DeltaRow,FAutoAdvance)
    then begin
      MoveNextSelectable(True, DeltaCol, DeltaRow)
    end else begin
      // some combinations of AutoAdvance and current position
      // will always fail, for example if user set current
      // column not selectable and autoadvance is aaDown will
      // fail always, in this case as a last resource do a full
      // scan until a cell is available
      for DeltaCol:=FixedCols to ColCount-1 do
        for DeltaRow:=FixedRows to RowCount-1 do begin
          if SelectCell(DeltaCol,DeltaRow) then begin
            // found one selectable cell
            MoveNextSelectable(False, DeltaCol,DeltaRow);
            exit;
          end;
        end;
      // user has created weird situation.
      // can't do more about it.
    end;

  finally
    FAutoAdvance := OldAA;
  end;
end;

procedure TCustomGrid.MoveSelection;
begin
  if Assigned(OnSelection) then OnSelection(Self, FCol, FRow);
end;

procedure TCustomGrid.BeginUpdate;
begin
  Inc(FUpdateCount);
end;

function TCustomGrid.BoxRect(ALeft, ATop, ARight, ABottom: Longint): TRect;
begin
  if ARight<ALeft then
    SwapInt(ALeft, ARight);
  if ABottom<ATop then
    SwapInt(ATop, ABottom);

  Result := CellRect(ALeft, ATop);
  Result.BottomRight := CellRect(ARight, ABottom).BottomRight;

  IntersectRect(Result, Result, FGCache.VisibleGrid);
end;

procedure TCustomGrid.CacheMouseDown(const X, Y: Integer);
var
  ParentForm: TCustomForm;
begin
  FGCache.ClickMouse := Point(X,Y);
  FGCache.ClickCell  := MouseToCell(FGCache.ClickMouse);
  if (FGCache.HotGridZone=gzInvalid) then begin
    ParentForm := GetParentForm(Self);
    if (ParentForm<>nil) and ParentForm.Active then
      FGCache.HotGridZone := CellToGridZone(FGCache.ClickCell.X, FGCache.ClickCell.Y);
  end;
end;

procedure TCustomGrid.EndUpdate(aRefresh: boolean = true);
begin
  Dec(FUpdateCount);
  if (FUpdateCount=0) and aRefresh then
    VisualChange;
end;

procedure TCustomGrid.EraseBackground(DC: HDC);
begin
  //
end;

function TCustomGrid.Focused: Boolean;
begin
  Result := CanTab and (HandleAllocated and
    (FindOwnerControl(GetFocus)=Self) or
     ((FEditor<>nil) and FEditor.Visible and FEditor.Focused));
end;

procedure TCustomGrid.InvalidateCell(aCol, aRow: Integer);
begin
  InvalidateCell(ACol,ARow, False);
end;

function TCustomGrid.HasMultiSelection: Boolean;
begin
  Result := (goRangeSelect in Options) and
    (FRangeSelectMode = rsmMulti) and (Length(FSelections) > 0);
end;

procedure TCustomGrid.InvalidateCell(aCol, aRow: Integer; Redraw: Boolean);
var
  R: TRect;
begin
  {$IfDef dbgPaint}
    DebugLn(['InvalidateCell  Col=',aCol,
      ' Row=',aRow,' Redraw=', Redraw]);
  {$Endif}
  if HandleAllocated and (IsCellVisible(aCol, aRow) or IsFixedCellVisible(aCol, aRow)) then begin
    R:=CellRect(aCol, aRow);
    InvalidateRect(Handle, @R, Redraw);
  end;
end;

procedure TCustomGrid.InvalidateRange(const aRange: TRect);
var
  RIni,RFin: TRect;
begin
  if not HandleAllocated then
    exit;
  RIni := CellRect(aRange.Left, aRange.Top);
  RFin := CellRect(aRange.Right, aRange.Bottom);
  if UseRightToLeftAlignment then
    RIni.Left := RFin.Left
  else
    RIni.Right := RFin.Right;
  RIni.Bottom:= RFin.Bottom;
  InvalidateRect(Handle, @RIni, False);
end;

procedure TCustomGrid.InvalidateGrid;
begin
  if FUpdateCount=0 then Invalidate;
end;

procedure TCustomGrid.Invalidate;
begin
  if FUpdateCount=0 then begin
    {$IfDef dbgPaint} DebugLn('Invalidate');{$Endif}
    inherited Invalidate;
  end;
end;

procedure TCustomGrid.EditingDone;
begin
  if not FEditorShowing then
    inherited EditingDone;
end;

function TCustomGrid.EditorGetValue(validate:boolean=false): boolean;
var
  CurValue,NewValue: string;
begin
  result := true;
  if (([csDesigning, csDestroying] * ComponentState) = [])
  and (Editor<>nil) and Editor.Visible then begin

    if validate then begin
      CurValue := GetCells(FCol,FRow);
      NewValue := CurValue;
      result := ValidateEntry(FCol,FRow,FEditorOldValue,NewValue);
      if (CurValue<>NewValue) then begin
        SetEditText(FCol,FRow,NewValue);
        if result then
          EditorHide
        else
          EditorDoSetValue;
        exit;
      end;
    end;

    if result then begin
      EditorDoGetValue;
      EditorHide;
    end;
  end;
end;

procedure TCustomGrid.EditorSetValue;
begin
  if not (csDesigning in ComponentState) then begin
    EditorPos;
    EditordoSetValue;
  end;
end;

procedure TCustomGrid.EditorHide;
var
  WasFocused: boolean;
begin
  if not EditorLocked and (Editor<>nil) and Editor.Visible then
  begin
    FEditorMode := False;
    FGridState := gsNormal;
    if Editor.Parent<>nil then  // May be nil when the form is closing.
    begin
      WasFocused := Editor.Focused;
      {$ifdef dbgGrid}DebugLnEnter('EditorHide [',Editor.ClassName,'] INIT FCol=',IntToStr(FCol),' FRow=',IntToStr(FRow));{$endif}
      LockEditor;
      try
        DoEditorHide;
      finally
        if WasFocused then
          SetFocus;
        UnLockEditor;
      end;
      {$ifdef dbgGrid}DebugLnExit('EditorHide END');{$endif}
    end;
  end;
end;

function TCustomGrid.EditorLocked: boolean;
begin
  Result := FEditorHidingCount <> 0;
end;

function TCustomGrid.EditingAllowed(ACol: Integer = -1): Boolean;
var
  C: TGridColumn;
begin
  Result:=(goEditing in options) and IsColumnIndexValid(ACol) and (RowCount>FixedRows);
  if Result and Columns.Enabled then begin
    C:=ColumnFromGridColumn(ACol);
    Result:=(C<>nil) and (not C.ReadOnly);
  end;
end;

procedure TCustomGrid.EditorShow(const SelAll: boolean);
begin
  if ([csLoading,csDestroying,csDesigning]*ComponentState<>[])
  or (not Enabled) or (not IsVisible)
  or (not HandleAllocated) then
    Exit;

  if EditingAllowed(FCol) and CanEditShow and (not FEditorShowing) and
     (Editor<>nil) and (not Editor.Visible) and (not EditorLocked) then
  begin
    {$ifdef dbgGrid} DebugLnEnter('EditorShow [',Editor.ClassName,'] INIT FCol=',IntToStr(FCol),' FRow=',IntToStr(FRow));{$endif}
    FEditorMode:=True;
    FEditorOldValue := GetCells(FCol,FRow);
    FEditorShowing:=True;
    doEditorShow;
    FEditorShowing:=False;
    if SelAll then
      EditorSelectAll;
    FGridState := gsNormal;
    {$ifdef dbgGrid} DebugLnExit('EditorShow END');{$endif}
  end;
end;

procedure TCustomGrid.EditorShowInCell(const aCol, aRow: Integer);
var
  OldCol,OldRow: Integer;
begin
  OldCol:=FCol;
  OldRow:=FRow;
  try
    EditorGetValue;
    FCol:=aCol;
    FRow:=aRow;
    SelectEditor;
    EditorShow(True);
  finally
    if (FCol=aCol)and(FRow=aRow) then
    begin
      // Current col,row didn't change, restore old ones
      FCol:=OldCol;
      FRow:=OldRow;
    end;
  end;
end;

procedure TCustomGrid.EditorTextChanged(const aCol,aRow: Integer; const aText:string);
begin
  SetEditText(aCol, aRow, aText);
end;

procedure TCustomGrid.EditorWidthChanged(aCol, aWidth: Integer);
begin
  EditorPos;
end;

function TCustomGrid.FirstGridColumn: integer;
begin
  result := FixedCols;
end;

procedure TCustomGrid.FixDesignFontsPPI(const ADesignTimePPI: Integer);
var
  LTitleFontIsDefault: Boolean;
  I: Integer;
begin
  inherited FixDesignFontsPPI(ADesignTimePPI);

  LTitleFontIsDefault := FTitleFontIsDefault;
  DoFixDesignFontPPI(TitleFont, ADesignTimePPI);
  FTitleFontIsDefault := LTitleFontIsDefault;
  for I := 0 to FColumns.Count-1 do
    FColumns[I].FixDesignFontsPPI(ADesignTimePPI);
end;

function TCustomGrid.FixedGrid: boolean;
begin
  result := (FixedCols=ColCount) or (FixedRows=RowCount)
end;

procedure TCustomGrid.FontChanged(Sender: TObject);
begin
  FRealizedDefRowHeight := 0;
  FRealizedDefColWidth := 0;
  if csCustomPaint in ControlState then
    Canvas.Font := Font
  else begin
    inherited FontChanged(Sender);
    if FColumns.Enabled then
      FColumns.FontChanged;
    if FTitleFontIsDefault then begin
      FTitleFont.Assign(Font);
      FTitleFontIsDefault := True;
    end;
  end;
end;

procedure TCustomGrid.EditorPos;
var
  msg: TGridMessage;
  CellR: TRect;
  PosValid: Boolean;
begin
  {$ifdef dbgGrid} DebugLn('Grid.EditorPos INIT');{$endif}
  if HandleAllocated and (FEditor<>nil) then begin

    // send editor position
    Msg.LclMsg.msg:=GM_SETPOS;
    Msg.Grid:=Self;
    Msg.Col:=FCol;
    Msg.Row:=FRow;
    FEditor.Dispatch(Msg);

    // send editor bounds
    PosValid := ColRowToOffset(True, True, FCol, CellR.Left, CellR.Right)
            and ColRowToOffSet(False,True, FRow, CellR.Top, CellR.Bottom);
    if not PosValid then // Can't position editor; ensure sane values
      CellR := Rect(0,0,FEditor.Width, FEditor.Height);

    if not PosValid or (CellR.Top<FGCache.FixedHeight) or (CellR.Top>FGCache.ClientHeight) or
       (UseRightToLeftAlignment and ((CellR.Right-1>FlipX(FGCache.FixedWidth)) or (CellR.Right<0))) or
       (not UseRightToLeftAlignment and ((CellR.Left<FGCache.FixedWidth) or (CellR.Left>FGCache.ClientWidth)))
    then
      // if editor will be out of sight, make the out of sight coords fixed
      // this should avoid range check errors on widgetsets that can't handle
      // high control coords (like GTK2)
      CellR := Bounds(-FEditor.Width-100, -FEditor.Height-100, CellR.Right-CellR.Left, CellR.Bottom-CellR.Top);

    // Make sure to use the grid font, not that of the title (issue #38203).
    Canvas.Font.Assign(Font);

    if FEditorOptions and EO_AUTOSIZE = EO_AUTOSIZE then begin
      if (FEditor = FStringEditor) and (EditorBorderStyle = bsNone) then
        CellR := TWSCustomGridClass(WidgetSetClass).
          GetEditorBoundsFromCellRect(Canvas, CellR, GetColumnLayout(FCol, False))
      else
        AdjustInnerCellRect(CellR);
      FEditor.BoundsRect := CellR;
    end else begin
      Msg.LclMsg.msg:=GM_SETBOUNDS;
      Msg.CellRect:=CellR;
      Msg.Grid:=Self;
      Msg.Col:=FCol;
      Msg.Row:=FRow;
      FEditor.Dispatch(Msg);
    end;
  end;
  {$ifdef dbgGrid} DebugLn('Grid.EditorPos END');{$endif}
end;

procedure TCustomGrid.EditorSelectAll;
var
  Msg: TGridMessage;
begin
  {$ifdef dbgGrid}DebugLn('EditorSelectALL INIT');{$endif}
  if FEditor<>nil then
    if FEditorOptions and EO_SELECTALL = EO_SELECTALL then begin
      Msg.LclMsg.msg:=GM_SELECTALL;
      FEditor.Dispatch(Msg);
    end;
  {$ifdef dbgGrid}DebugLn('EditorSelectALL END');{$endif}
end;

procedure TCustomGrid.EditordoGetValue;
var
  msg: TGridMessage;
begin
  if (FEditor<>nil) and FEditor.Visible then begin
    Msg.LclMsg.msg:=GM_GETVALUE;
    Msg.grid:=Self;
    Msg.Col:=FCol;
    Msg.Row:=FRow;
    Msg.Value:=GetCells(FCol, FRow);
    FEditor.Dispatch(Msg);
    SetEditText(Msg.Col, Msg.Row, Msg.Value);
  end;
end;

procedure TCustomGrid.EditordoResetValue;
var
  msg: TGridMessage;
begin
  if (FEditor<>nil) and FEditor.Visible then begin
    Msg.LclMsg.msg:=GM_SETVALUE;
    Msg.grid:=Self;
    Msg.Col:=FCol;
    Msg.Row:=FRow;
    Msg.Value:=FEditorOldValue;
    FEditor.Dispatch(Msg);
    SetEditText(Msg.Col, Msg.Row, Msg.Value);
  end;
end;

procedure TCustomGrid.EditordoSetValue;
var
  msg: TGridMessage;
begin
  if FEditor<>nil then begin
    // Set the editor mask
    Msg.LclMsg.msg:=GM_SETMASK;
    Msg.Grid:=Self;
    Msg.Col:=FCol;
    Msg.Row:=FRow;
    Msg.Value:=GetEditMask(FCol, FRow);
    FEditor.Dispatch(Msg);
    // Set the editor value
    Msg.LclMsg.msg:=GM_SETVALUE;
    Msg.Grid:=Self;
    Msg.Col:=FCol;
    Msg.Row:=FRow;
    Msg.Value:=GetEditText(Fcol, FRow);
    FEditor.Dispatch(Msg);
  end;
end;

function TCustomGrid.EditorCanAcceptKey(const ch: TUTF8Char): boolean;
begin
  result := True;
end;

function TCustomGrid.EditorIsReadOnly: boolean;
begin
  result := GetColumnReadonly(Col);
end;

procedure TCustomGrid.GetAutoFillColumnInfo(const Index: Integer; var aMin,aMax,aPriority: Integer);
var
  C: TGridColumn;
begin
  if Index<FixedCols then
    APriority := 0
  else if Columns.Enabled then begin
    C := ColumnFromGridColumn(Index);
    if C<>nil then begin
      aMin := C.MinSize;
      aMax := C.MaxSize;
      aPriority := C.SizePriority;
    end else
      APriority := 1;
  end else
    APriority := 1;
end;

function TCustomGrid.GetCellHintText(ACol, ARow: Integer): string;
begin
  Result := '';
  if Assigned(FOnGetCellHint) then
    FOnGetCellHint(self, ACol, ARow, result);
end;

function TCustomGrid.GetTruncCellHintText(ACol, ARow: Integer): string;
begin
  Result := GetCells(ACol, ARow);
  if Assigned(FOnGetCellHint) and (FCellHintPriority = chpTruncOnly) then
    FOnGetCellHint(self, ACol, ARow, result);
end;

function TCustomGrid.GetCells(ACol, ARow: Integer): string;
begin
  result := '';
end;

procedure TCustomGrid.EditorKeyDown(Sender: TObject; var Key:Word; Shift:TShiftState);
begin
  {$ifdef dbgGrid}DebugLn('Grid.EditorKeyDown Key=',dbgs(Key),' INIT');{$endif}
  FEditorKey:=True; // Just a flag to see from where the event comes
  KeyDown(Key, shift);
  FEditorKey:=False;
  {$ifdef dbgGrid}DebugLn('Grid.EditorKeyDown Key=',dbgs(Key),' END');{$endif}
end;

procedure TCustomGrid.EditorKeyPress(Sender: TObject; var Key: Char);
var
  AChar: TUTF8Char;
{$ifdef dbgGrid}
function PrintKey:String;
begin
  Result := Dbgs(ord(key))+' $' + IntToHex(ord(key),2);
  if Key>#31 then
    Result := Key + ' ' + Result
end;
{$endif}
begin
  {$ifdef dbgGrid}DebugLn('Grid.EditorKeyPress: INIT Key=',PrintKey);{$Endif}
  FEditorKey := True;
  KeyPress(Key); // grid must get all keypresses, even if they are from the editor
  {$ifdef dbgGrid}DebugLn('Grid.EditorKeyPress: inter Key=',PrintKey);{$Endif}
  case Key of
    #0, ^C,^V,^X:;

    ^M:
    begin
      Include(FGridFlags, gfEditingDone);
      if not MoveNextAuto(GetKeyState(VK_SHIFT) < 0) then
        ResetEditor;
      Exclude(FGridFlags, gfEditingDone);
      Key := #0;
    end;

    else begin
      AChar := Key;
      if not EditorCanAcceptKey(AChar) or EditorIsReadOnly then
        Key := #0
      else
        Key := AChar[1];
    end;
  end;
  FEditorKey := False;
  {$ifdef dbgGrid}DebugLn('Grid.EditorKeyPress: END Key=',PrintKey);{$Endif}
end;

procedure TCustomGrid.EditorKeyUp(Sender: TObject; var key: Word;
  shift: TShiftState);
begin
  FEditorKey := True;
  KeyUp(Key, Shift);
  FEditorKey := False;
end;

procedure TCustomGrid.SelectEditor;
var
  aEditor: TWinControl;
begin
  {$ifdef DbgGrid}
  DebugLnEnter('TCustomGrid.SelectEditor INIT');
  {$endif}
  aEditor := GetDefaultEditor(Col);
  if EditingAllowed(FCol) and Assigned(OnSelectEditor) then begin
    // in some situations there are only non-selectable cells
    // if goAlwaysShowEditor is on set initially editor to nil,
    // user can modify this value in OnSelectEditor if needed
    if not SelectCell(FCol,FRow) then
      aEditor:=nil;
    OnSelectEditor(Self, fCol, FRow, aEditor);
  end;
  if aEditor<>Editor then
    Editor := aEditor;
  if Assigned(Editor) and not Assigned(Editor.Popupmenu) then
    Editor.PopupMenu := PopupMenu;
  {$ifdef DbgGrid}
  DebugLnExit('TCustomGrid.SelectEditor END');
  {$endif}
end;

function TCustomGrid.EditorAlwaysShown: Boolean;
begin
  Result:=EditingAllowed(FCol) and (goAlwaysShowEditor in Options) and not FixedGrid;
end;

//
procedure TCustomGrid.FixPosition(IsColumn: Boolean; aIndex: Integer);
var
  OldCol,OldRow: Integer;

  procedure FixSelection;
  begin
    if FRow > FRows.Count - 1 then
      FRow := FRows.Count - 1
    else if (FRow < FixedRows) and (FixedRows<FRows.Count) then
      FRow := FixedRows;
    if FCol > FCols.Count - 1 then
      FCol := FCols.Count - 1
    else if (FCol < FixedCols) and (FixedCols<FCols.Count) then
      FCol := FixedCols;
  end;
  procedure FixTopLeft;
  var
    oldTL: TPoint;
    VisCount: Integer;
  begin
    OldTL:=FTopLeft;
    VisCount := FGCache.VisibleGrid.Right-FGCache.VisibleGrid.Left+1;
    if OldTL.X+VisCount>FCols.Count then begin
      OldTL.X := FCols.Count - VisCount;
      if OldTL.X<FixedCols then
        OldTL.X := FixedCols;
    end;
    VisCount := FGCache.VisibleGrid.Bottom-FGCache.VisibleGrid.Top+1;
    if OldTL.Y+VisCount>FRows.Count then begin
      OldTL.Y := FRows.Count - VisCount;
      if OldTL.Y<FixedRows then
        OldTL.Y:=FixedRows;
    end;
    if not PointIgual(OldTL, FTopleft) then begin
      fTopLeft := OldTL;
      //DebugLn('TCustomGrid.FixPosition ',DbgSName(Self),' FTopLeft=',dbgs(FTopLeft));
      topleftChanged;
    end;
  end;
  procedure FixEditor;
  var
    ColRow: Integer;
  begin
    if FixedGrid then begin
      EditorMode:=False;
      exit;
    end;
    if IsColumn then
      ColRow:=OldCol
    else
      ColRow:=OldRow;
    {$ifdef dbgeditor}
    DebugLn('FixEditor: aIndex=%d ColRow=%d EditorMode=%s',[aIndex,ColRow,dbgs(EditorMode)]);
    {$endif}
    // Changed index is same as current colrow, new colrow may change
    if AIndex=ColRow then begin
      EditorMode:=False;
      if EditorAlwaysShown then begin
        SelectEditor;
        EditorMode:=True;
      end;
    end else
    // Changed index in before current colrow, just translate editor
    if (AIndex<ColRow) and EditorMode then begin
      if IsColumn then
        AdjustEditorBounds(ColRow-1, OldRow)
      else
        AdjustEditorBounds(OldCol, ColRow-1)
    end;
    // else: changed index is after current colrow, it doesn't affect editor
  end;
begin
  OldCol := Col;
  OldRow := Row;
  FixTopleft;
  FixSelection;
  CheckPosition;
  UpdateSelectionRange;
  VisualChange;
  FixEditor;
end;

procedure TCustomGrid.FixScroll;
var
  OldColOffset: Integer;
  OldTopLeft: TPoint;
begin
  // TODO: fix rows too
  // column handling
  if FGCache.OldMaxTopLeft.x<>FGCache.MaxTopLeft.x then begin
    // keeping FullVisibleGrid try to find a better topleft. We care are only
    // if the grid is smaller than before, comparing GridWidth should work also
    // but MaxTopLeft has better granularity
    if FGCache.MaxTopLeft.x<FGCache.OldMaxTopLeft.x then begin
      OldColOffset := FGCache.TLColOff;
      OldTopLeft := fTopLeft;
      FGCache.TLColOff := 0;
      fTopleft.x := FixedCols;
      if not ScrollToCell(FGCache.FullVisibleGrid.Right, Row, True) then begin
        // target cell is now visible ....
        if OldTopLeft.x<>fTopLeft.x then
          // but the supposed startig left col is not the same as the current one
          doTopleftChange(False)
        else begin
          FGCache.TLColOff := OldColOffset;
          fTopLeft := OldTopLeft;
        end;
      end;
    end;
  end;
end;

procedure TCustomGrid.EditorShowChar(Ch: TUTF8Char);
begin
  SelectEditor;
  if FEDitor<>nil then begin
    if EditorCanAcceptKey(ch) and not EditorIsReadOnly then begin
      EditorShow(true);
      TWSCustomGridClass(WidgetSetClass).SendCharToEditor(Editor, Ch);
      //this method bypasses Self.KeyDown and therefore will not reset FRowAutoInserted there
      //So, set it to false, unless pressing a backspace caused the editor to pop-up
      if (Ch <> ^H) then FRowAutoInserted := False;
    end;
  end;
end;

procedure TCustomGrid.EditorSetMode(const AValue: Boolean);
begin
  {$ifdef dbgGrid}DebugLn('Grid.EditorSetMode=',dbgs(Avalue),' INIT');{$endif}
  if not AValue then
    EditorHide
  else
    EditorShow(false);
  {$ifdef dbgGrid}DebugLn('Grid.EditorSetMode END');{$endif}
end;

function TCustomGrid.GetSelectedColor: TColor;
begin
  Result:=FSelectedColor;
end;

function TCustomGrid.GetTitleShowPrefix(Column: Integer): boolean;
var
  C: TGridColumn;
begin
  C := ColumnFromGridColumn(Column);
  if C<>nil then
    result := C.Title.PrefixOption<>poNone
  else
    result := false;
end;

function TCustomGrid.GridColumnFromColumnIndex(ColumnIndex: Integer): Integer;
begin
  {$ifdef NewCols}
  result := ColumnIndex + FirstGridColumn;
  if Result>ColCount-1 then
    Result := -1;
  {$else}
  result := Columns.VisibleIndex(ColumnIndex);
  if result>=0 then
    result := result + FixedCols;
  {$endif}
end;

procedure TCustomGrid.GridMouseWheel(Shift: TShiftState; Delta: Integer);
begin
  // Ctrl-key is to support horiz scrolling with basic mouse
  if ssCtrl in Shift then
    MoveNextSelectable(true, Delta, 0)
  else
    MoveNextSelectable(true, 0, Delta);
end;

function TCustomGrid.GetEditMask(ACol, ARow: Longint): string;
begin
  result:='';
end;

function TCustomGrid.GetEditText(ACol, ARow: Longint): string;
begin
  result:='';
end;

function TCustomGrid.GetColumnAlignment(Column: Integer; ForTitle: Boolean): TAlignment;
var
  C: TGridColumn;
begin
  C := ColumnFromGridColumn(Column);
  if C<>nil then
    if ForTitle then
      Result := C.Title.Alignment
    else
      Result := C.Alignment
  else
    result := GetDefaultColumnAlignment(Column);
end;

function TCustomGrid.GetColumnColor(Column: Integer; ForTitle: Boolean): TColor;
var
  C: TGridColumn;
begin
  C := ColumnFromGridColumn(Column);
  if C<>nil then
    if ForTitle then
      result := C.Title.Color
    else
      result := C.Color
  else
    if ForTitle then
      result := FixedColor
    else
      result := Self.Color;
end;

function TCustomGrid.GetColumnFont(Column: Integer; ForTitle: Boolean): TFont;
var
  C: TGridColumn;
begin
  C := ColumnFromGridColumn(Column);
  if C<>nil then
    if ForTitle then
      Result := C.Title.Font
    else
      Result := C.Font
  else begin
    if ForTitle then
      Result := TitleFont
    else
      Result := Self.Font;
  end;
end;

function TCustomGrid.GetColumnLayout(Column: Integer; ForTitle: boolean): TTextLayout;
var
  C: TGridColumn;
begin
  C := ColumnFromGridColumn(Column);
  if C<>nil then
    if ForTitle then
      Result := C.Title.Layout
    else
      Result := C.Layout
  else
    result := GetDefaultColumnLayout(Column);
end;

function TCustomGrid.GetColumnReadonly(Column: Integer): boolean;
var
  C: TGridColumn;
begin
  C := ColumnFromGridColumn(Column);
  if C<>nil then
    result := C.ReadOnly
  else
    result := GetDefaultColumnReadOnly(Column);
end;

function TCustomGrid.GetColumnTitle(Column: Integer): string;
var
  C: TGridColumn;
begin
  C := ColumnFromGridColumn(Column);
  if C<>nil then
    Result := C.Title.Caption
  else
    result := GetDefaultColumnTitle(Column);
end;

function TCustomGrid.GetColumnWidth(Column: Integer): Integer;
var
  C: TGridColumn;
begin
  C := ColumnFromGridColumn(Column);
  if C<>nil then
    Result := C.Width
  else
    Result := GetDefaultColumnWidth(Column);
end;

// return the relative cell coordinate of the next cell
// considering AutoAdvance property and selectable cells.
function TCustomGrid.GetDeltaMoveNext(const Inverse: boolean;
  var ACol, ARow: Integer; const AAutoAdvance: TAutoAdvance): boolean;
var

  DeltaCol,DeltaRow: Integer;

  function CalcNextStep: boolean;
  var
    aa: TAutoAdvance;
    cCol,cRow: Integer;
  begin

    DeltaCol := 0;
    DeltaRow := 0;

    aa := AAutoAdvance;
    if Inverse then
      case aa of
        aaRight:      aa := aaLeft;
        aaLeft:       aa := aaRight;
        aaRightDown:  aa := aaLeftUp;
        aaLeftDown:   aa := aaRightUp;
        aaRightUP:    aa := aaLeftDown;
        aaLeftUP:     aa := aaRightDown;
      end;

    case aa of
      aaRight:
        DeltaCol := 1;

      aaLeft:
        DeltaCol := -1;

      aaDown:
        DeltaRow := 1;

      aaRightDown:
        if ACol<ColCount-1 then
          DeltaCol := 1
        else begin
          DeltaCol := FixedCols-ACol;
          DeltaRow := 1;
        end;

      aaRightUP:
        if ACol<ColCount-1 then
          DeltaCol := 1
        else begin
          DeltaCol := FixedCols-ACol;
          DeltaRow := -1;
        end;

      aaLeftUP:
        if ACol>FixedCols then
          DeltaCol := -1
        else begin
          DeltaCol := ColCount-1-ACol;
          DeltaRow := -1;
        end;

      aaLeftDown:
        if ACol>FixedCols then
          DeltaCol := -1
        else begin
          DeltaCol := ColCount-1-ACol;
          DeltaRow := 1;
        end;
    end;

    CCol := ACol + DeltaCol;
    CRow := ARow + DeltaRow;

    // is CCol,CRow within range?
    result :=
      (CCol<=ColCount-1)and(CCol>=FixedCols)and
      (CRow<=RowCount-1)and(CRow>=FixedRows);
  end;

begin
  ACol := FCol;
  ARow := FRow;

  result := False;

  if AAutoAdvance=aaNone then begin
    ACol := 0;
    ARow := 0;
    exit; // quick case, no auto movement allowed
  end;

  if [goRowSelect,goRelaxedRowSelect]*Options=[goRowSelect] then begin
    if Inverse then
      ACol := FixedCols
    else
      ACol := ColCount-1;
  end;

  // browse the grid in autoadvance order
  while CalcNextStep do begin
    ACol := ACol + DeltaCol;
    ARow := ARow + DeltaRow;
    // is cell ACol,ARow selectable?
    result := SelectCell(ACol,ARow);
    if Result then
      break;
  end;

  if result then begin
    // return relative position
    ACol := ACol - FCol;
    ARow := ARow - FRow;
  end else begin
    // no available next cell, return delta anyway
    ACol := DeltaCol;
    ARow := DeltaRow;
  end;
end;

function TCustomGrid.GetDefaultColumnAlignment(Column: Integer): TAlignment;
begin
  result := DefaultTextStyle.Alignment;
end;

function TCustomGrid.GetDefaultEditor(Column: Integer): TWinControl;
var
  C: TGridColumn;
  bs: TColumnButtonStyle;
begin
  result := nil;
  if EditingAllowed(Col) then begin
    C := ColumnFromGridColumn(Column);
    if C<>nil then begin
      bs := C.ButtonStyle;
      if (bs=cbsAuto) and (C.PickList<>nil) and (C.PickList.Count>0) then
        bs := cbsPicklist
    end else
      bs := cbsAuto;

    result := EditorByStyle( Bs );

    // by default do the editor setup here
    // if user wants to change our setup, this can
    // be done in OnSelectEditor
    if (bs=cbsPickList) and (C<>nil) and (C.PickList<>nil) and
        (result = FPicklistEditor) then begin
      FPickListEditor.Items.Assign(C.PickList);
      FPickListEditor.DropDownCount := C.DropDownRows;
    end

  end;
end;

function TCustomGrid.GetDefaultRowHeight: integer;
var
  TmpCanvas: TCanvas;
begin
  tmpCanvas := GetWorkingCanvas(Canvas);
  tmpCanvas.Font := Font;
  tmpCanvas.Font.PixelsPerInch := Font.PixelsPerInch;
  result := tmpCanvas.TextHeight('Fj')+7;
  if tmpCanvas<>Canvas then
    FreeWorkingCanvas(tmpCanvas);
end;

function TCustomGrid.GetGridDrawState(ACol, ARow: Integer): TGridDrawState;
begin
  Result := [];
  if ARow < FFixedRows then
    include(Result, gdFixed)
  else begin
    if (aCol = FCol) and (aRow = FRow) then
      Result := Result + [gdFocused, gdSelected]
    else
    if IsCellSelected[aCol, aRow] then
      include(Result, gdSelected);
  end;
  if (aRow=FRow) and (goRowHighlight in FOptions) and not (gdFixed in Result) then
     Result := Result + [gdRowHighlight];
  with FGCache do begin
    if (ACol = HotCell.x) and (ARow = HotCell.y) and not IsPushCellActive()
      then Include(Result, gdHot);
    if ClickCellPushed and (ACol = PushedCell.x) and (ARow = PushedCell.y)
      then Include(Result, gdPushed);
  end;
end;

function TCustomGrid.GetScrollBarPosition(Which: integer): Integer;
var
  ScrollInfo: TScrollInfo;
begin
  if HandleAllocated then begin
    ScrollInfo.cbSize := SizeOf(ScrollInfo);
    ScrollInfo.fMask := SIF_POS;
    GetScrollInfo(Handle, Which, ScrollInfo);
    Result:=ScrollInfo.nPos;
  end
  else
    Result:=0;
end;

function TCustomGrid.GetDefaultColumnWidth(Column: Integer): Integer;
begin
  Result := FDefColWidth;
end;

function TCustomGrid.GetDefaultColumnLayout(Column: Integer): TTextLayout;
begin
  result := DefaultTextStyle.Layout;
end;

function TCustomGrid.GetDefaultColumnReadOnly(Column: Integer): boolean;
begin
  result := false;
end;

function TCustomGrid.GetDefaultColumnTitle(Column: Integer): string;
begin
  result := '';
end;

procedure TCustomGrid.SetEditText(ACol, ARow: Longint; const Value: string);
begin
end;

function TCustomGrid.CanGridAcceptKey(Key: Word; Shift: TShiftState): Boolean;
begin
  Result := True;
end;

procedure TCustomGrid.SetSelectedColor(const AValue: TColor);
begin
  if FSelectedColor<>AValue then begin
    FSelectedColor:=AValue;
    Invalidate;
  end;
end;

procedure TCustomGrid.SetFixedcolor(const AValue: TColor);
begin
  if FFixedColor<>AValue then begin
    FFixedColor:=Avalue;
    Invalidate;
  end;
end;

function TCustomGrid.GetFixedcolor: TColor;
begin
  result:=FFixedColor;
end;

function TCustomGrid.GetFirstVisibleColumn: Integer;
begin
  result := FixedCols;
  while (result<ColCount) and (ColWidths[result]=0) do
    inc(result); // extreme case may return colcount
end;

function TCustomGrid.GetFirstVisibleRow: Integer;
begin
  result := FixedRows;
  while (result<RowCount) and (RowHeights[result]=0) do
    inc(result); // ditto
end;

function TCustomGrid.GetLastVisibleColumn: Integer;
begin
  result := ColCount-1;
  while (result>=0) and (ColWidths[result]=0) do
    dec(result); // extreme case may return -1
end;

function TCustomGrid.GetLastVisibleRow: Integer;
begin
  result := RowCount-1;
  while (result>=0) and (RowHeights[result]=0) do
    dec(result); // ditto
end;

procedure TCustomGrid.ColWidthsChanged;
begin
  //
end;
procedure TCustomGrid.RowHeightsChanged;
begin
  //
end;

function TCustomGrid.RTLSign: Integer;
const
  cRTLSign: array[TBiDiMode] of Integer = (1, -1, 1, 1);
begin
  Result := cRTLSign[BiDiMode];
end;

procedure TCustomGrid.SaveColumns(cfg: TXMLConfig; Version: integer);
var
  Path,cPath: string;
  i: Integer;
  c: TGridColumn;
begin
  Path := 'grid/design/columns/';
  cfg.SetValue(Path + 'columnsenabled', True);
  cfg.SetValue(Path + 'columncount', columns.Count);
  for i := 0 to columns.Count - 1 do begin
    c := Columns[i];
    cPath := Path + 'column' + IntToStr(i);
    cfg.setValue(cPath + '/index/value', c.Index);
    if c.IsWidthStored then
      cfg.setValue(cPath + '/width/value', c.Width);
    if c.IsAlignmentStored then
      cfg.setValue(cPath + '/alignment/value', ord(c.Alignment));
    if c.IsLayoutStored then
      cfg.setValue(cPath + '/layout/value', ord(c.Layout));
    cfg.setValue(cPath + '/buttonstyle/value', ord(c.ButtonStyle));
    if c.IsColorStored then
      cfg.setValue(cPath + '/color/value', colortostring(c.Color));
    if c.IsValueCheckedStored then
      cfg.setValue(cPath + '/valuechecked/value', c.ValueChecked);
    if c.IsValueUncheckedStored then
      cfg.setValue(cPath + '/valueunchecked/value', c.ValueUnChecked);
    if c.PickList.Count>0 then
      cfg.SetValue(cPath + '/picklist/value', c.PickList.CommaText);
    if c.IsSizePriorityStored then
      cfg.SetValue(cPath + '/sizepriority/value', c.SizePriority);
    if not c.IsDefaultFont then
      CfgSetFontValue(cfg, cPath + '/font', c.Font);
    cfg.setValue(cPath + '/title/caption/value', c.Title.Caption);
    if not c.Title.IsDefaultFont then
      CfgSetFontValue(cfg, cPath + '/title/font', c.Title.Font);
    if c.Title.IsAlignmentStored then
      cfg.setValue(cPath + '/title/alignment/value', ord(c.Title.Alignment));
    if c.Title.IsColorStored then
      cfg.setValue(cPath + '/title/color/value', colortostring(c.Title.Color));
    if c.Title.IsLayoutStored then
      cfg.setValue(cPath + '/title/layout/value', ord(c.Title.Layout));

    doSaveColumn(self, c, -1, Cfg, Version, cPath);
  end;
end;

procedure TCustomGrid.SaveContent(cfg: TXMLConfig);
var
  i,j,k: Integer;
  Path, tmpPath: string;
begin
  cfg.SetValue('grid/version', GRIDFILEVERSION);

  Cfg.SetValue('grid/saveoptions/create', soDesign in SaveOptions);
  if soDesign in SaveOptions then begin
    Cfg.SetValue('grid/design/columncount',  ColCount);
    Cfg.SetValue('grid/design/rowcount',  RowCount);
    Cfg.SetValue('grid/design/fixedcols', FixedCols);
    Cfg.SetValue('grid/design/fixedrows', Fixedrows);
    Cfg.SetValue('grid/design/defaultcolwidth', DefaultColWidth);
    Cfg.SetValue('grid/design/isdefaultcolwidth', ord(DefaultColWidthIsStored));
    Cfg.SetValue('grid/design/defaultrowheight',DefaultRowHeight);
    Cfg.SetValue('grid/design/isdefaultrowheight', ord(DefaultRowHeightIsStored));
    Cfg.Setvalue('grid/design/color',ColorToString(Color));

    if Columns.Enabled then
      saveColumns(cfg, GRIDFILEVERSION)
    else begin
      j:=0;
      for i:=0 to ColCount-1 do begin
        k:=FCols[i];
        if (k>=0)and(k<>DefaultColWidth) then begin
          inc(j);
          tmpPath := 'grid/design/columns/column'+IntToStr(j);
          cfg.SetValue('grid/design/columns/columncount',j);
          cfg.SetValue(tmpPath+'/index', i);
          cfg.SetValue(tmpPath+'/width', k);
          doSaveColumn(self, nil, i, Cfg, GRIDFILEVERSION, tmpPath);
        end;
      end;
    end;

    j:=0;
    for i:=0 to RowCount-1 do begin
      k:=FRows[i];
      if (k>=0)and(k<>DefaultRowHeight) then begin
        inc(j);
        cfg.SetValue('grid/design/rows/rowcount',j);
        cfg.SetValue('grid/design/rows/row'+IntToStr(j)+'/index', i);
        cfg.SetValue('grid/design/rows/row'+IntToStr(j)+'/height',k);
      end;
    end;

    SaveGridOptions(Cfg);
  end;

  Cfg.SetValue('grid/saveoptions/position', soPosition in SaveOptions);
  if soPosition in SaveOptions then begin
    Cfg.SetValue('grid/position/topleftcol',ftopleft.x);
    Cfg.SetValue('grid/position/topleftrow',ftopleft.y);
    Cfg.SetValue('grid/position/col',fCol);
    Cfg.SetValue('grid/position/row',fRow);
    if goRangeSelect in Options then begin
      Cfg.SetValue('grid/position/selection/left',Selection.left);
      Cfg.SetValue('grid/position/selection/top',Selection.top);
      Cfg.SetValue('grid/position/selection/right',Selection.right);
      Cfg.SetValue('grid/position/selection/bottom',Selection.bottom);
    end;
  end;
end;

procedure TCustomGrid.SaveGridOptions(cfg: TXMLConfig);
var
  Path: string;
begin
  Path:='grid/design/options/';
  Cfg.SetValue(Path+'goFixedVertLine/value', goFixedVertLine in options);
  Cfg.SetValue(Path+'goFixedHorzLine/value', goFixedHorzLine in options);
  Cfg.SetValue(Path+'goVertLine/value',  goVertLine in options);
  Cfg.SetValue(Path+'goHorzLine/value',  goHorzLine in options);
  Cfg.SetValue(Path+'goRangeSelect/value', goRangeSelect in options);
  Cfg.SetValue(Path+'goDrawFocusSelected/value', goDrawFocusSelected in options);
  Cfg.SetValue(Path+'goRowSizing/value', goRowSizing in options);
  Cfg.SetValue(Path+'goColSizing/value', goColSizing in options);
  Cfg.SetValue(Path+'goRowMoving/value', goRowMoving in options);
  Cfg.SetValue(Path+'goColMoving/value', goColMoving in options);
  Cfg.SetValue(Path+'goEditing/value', goEditing in options);
  Cfg.SetValue(Path+'goAutoAddRows/value', goAutoAddRows in options);
  Cfg.SetValue(Path+'goTabs/value', goTabs in options);
  Cfg.SetValue(Path+'goRowSelect/value', goRowSelect in options);
  Cfg.SetValue(Path+'goAlwaysShowEditor/value', goAlwaysShowEditor in options);
  Cfg.SetValue(Path+'goThumbTracking/value', goThumbTracking in options);
  Cfg.SetValue(Path+'goColSpanning/value', goColSpanning in options);
  cfg.SetValue(Path+'goRelaxedRowSelect/value', goRelaxedRowSelect in options);
  cfg.SetValue(Path+'goDblClickAutoSize/value', goDblClickAutoSize in options);
  Cfg.SetValue(Path+'goSmoothScroll/value', goSmoothScroll in Options);
  Cfg.SetValue(Path+'goAutoAddRowsSkipContentCheck/value', goAutoAddRowsSkipContentCheck in Options);
  Cfg.SetValue(Path+'goRowHighlight/value', goRowHighlight in Options);
  Cfg.SetValue(Path+'goScrollToLastCol/value', goScrollToLastCol in Options2);
  Cfg.SetValue(Path+'goScrollToLastRow/value', goScrollToLastRow in Options2);
end;

procedure TCustomGrid.LoadColumns(cfg: TXMLConfig; Version: integer);
var
  i, k: integer;
  path, cPath, s: string;
  c: TGridColumn;
begin
  Path := 'grid/design/columns/';
  k := cfg.getValue(Path + 'columncount', 0);
  for i := 0 to k - 1 do
    Columns.Add;
  for i := 0 to k - 1 do begin
    c := Columns[i];
    cPath := Path + 'column' + IntToStr(i);
    c.index := cfg.getValue(cPath + '/index/value', i);
    s := cfg.GetValue(cPath + '/width/value', '');
    if s<>'' then
      c.Width := StrToIntDef(s, 64);
    s := cfg.getValue(cPath + '/alignment/value', '');
    if s<>'' then
      c.Alignment := TAlignment(StrToIntDef(s, 0));
    s := cfg.GetValue(cPath + '/layout/value', '');
    if s<>'' then
      c.Layout := TTextLayout(StrToIntDef(s, 0));
    s := cfg.getValue(cPath + '/buttonstyle/value', '0');
    c.ButtonStyle := TColumnButtonStyle(StrToInt(s));
    s := cfg.getValue(cPath + '/color/value', '');
    if s<>'' then
      c.Color := StringToColor(s);
    s := cfg.getValue(cPath + '/valuechecked/value', '');
    if s<>'' then
      c.ValueChecked := s;
    s := cfg.getValue(cPath + '/valueunchecked/value', '');
    if s<>'' then
      c.ValueUnChecked := s;
    s := cfg.GetValue(cPath + '/picklist/value', '');
    if s<>'' then
      c.PickList.CommaText := s;
    s := cfg.GetValue(cPath + '/sizepriority/value', '');
    if s<>'' then
      c.SizePriority := StrToIntDef(s, 0);
    s := cfg.GetValue(cPath + '/font/name/value', '');
    if s<>'' then
      cfgGetFontValue(cfg, cPath + '/font', c.Font);
    c.Title.Caption := cfg.getValue(cPath + '/title/caption/value', 'title ' + IntToStr(i));
    s := cfg.GetValue(cPath + '/title/font/name/value', '');
    if s<>'' then
      cfgGetFontValue(cfg, cPath + '/title/font', c.Title.Font);
    s := cfg.getValue(cPath + '/title/alignment/value', '');
    if s<>'' then
      c.Title.Alignment := TAlignment(StrToIntDef(s, 0));
    s := cfg.getValue(cPath + '/title/color/value', '');
    if s<>'' then
      c.Title.Color := StringToColor(s);
    s := cfg.GetValue(cPath + 'title/layout/value', '');
    if s<>'' then
      c.Title.Layout := TTextLayout(StrToIntDef(s, 0));

    doLoadColumn(self, c, -1, cfg, version, cpath);
  end;
end;


procedure TCustomGrid.LoadContent(cfg: TXMLConfig; Version: Integer);
var
  CreateSaved: Boolean;
  i,j,k: Integer;
  Path, tmpPath: string;
begin
  if soDesign in FSaveOptions then begin
    CreateSaved:=Cfg.GetValue('grid/saveoptions/create', false);
    if CreateSaved then begin
      Clear;
      Columns.Clear;
      FixedCols:=0;
      FixedRows:=0;

      if cfg.getValue('grid/design/columns/columnsenabled', False) then
        LoadColumns(cfg, version)
      else
        ColCount := Cfg.GetValue('grid/design/columncount', 5);

      RowCount:=Cfg.GetValue('grid/design/rowcount', 5);
      FixedCols:=Cfg.GetValue('grid/design/fixedcols', 1);
      FixedRows:=Cfg.GetValue('grid/design/fixedrows', 1);

      k := Cfg.GetValue('grid/design/isdefaultrowheight', -1);
      if k<>0 then
        DefaultRowheight:=Cfg.GetValue('grid/design/defaultrowheight', -1)
      else
        DefaultRowheight:=-1;

      k := Cfg.GetValue('grid/design/isdefaultcolwidth', -1);
      if k<>0 then
        DefaultColWidth:=Cfg.getValue('grid/design/defaultcolwidth', -1)
      else
        DefaultColWidth:=-1;

      try
        Color := StringToColor(cfg.GetValue('grid/design/color', 'clWindow'));
      except
      end;

      if not Columns.Enabled then begin
        Path:='grid/design/columns/';
        k:=cfg.getValue(Path+'columncount',0);
        for i:=1 to k do begin
          tmpPath := Path+'column'+IntToStr(i);
          j:=cfg.getValue(tmpPath+'/index',-1);
          if IsColumnIndexValid(j) then begin
            ColWidths[j]:=cfg.getValue(tmpPath+'/width',-1);
            doLoadColumn(self, nil, j, Cfg, Version, tmpPath);
          end;
        end;
      end;

      Path:='grid/design/rows/';
      k:=cfg.getValue(Path+'rowcount',0);
      for i:=1 to k do begin
        j:=cfg.getValue(Path+'row'+IntToStr(i)+'/index',-1);
        if IsRowIndexValid(j) then begin
          RowHeights[j]:=cfg.getValue(Path+'row'+IntToStr(i)+'/height',-1);
        end;
      end;

      LoadGridOptions(cfg, Version);
    end;

    CreateSaved:=Cfg.GetValue('grid/saveoptions/position', false);
    if CreateSaved then begin
      i:=Cfg.GetValue('grid/position/topleftcol',-1);
      j:=Cfg.GetValue('grid/position/topleftrow',-1);
      if CellToGridZone(i,j)=gzNormal then begin
        TryScrollTo(i,j,True,True);
      end;
      i:=Cfg.GetValue('grid/position/col',-1);
      j:=Cfg.GetValue('grid/position/row',-1);
      if IsColumnIndexVariable(i) and
         IsRowIndexVariable(j) then begin
        MoveExtend(false, i,j, True);
      end;
      if goRangeSelect in Options then begin
        FRange.left:=Cfg.getValue('grid/position/selection/left',FCol);
        FRange.Top:=Cfg.getValue('grid/position/selection/top',FRow);
        FRange.Right:=Cfg.getValue('grid/position/selection/right',FCol);
        FRange.Bottom:=Cfg.getValue('grid/position/selection/bottom',FRow);
      end;
    end;
  end;
end;

procedure TCustomGrid.LoadGridOptions(cfg: TXMLConfig; Version: Integer);
var
  Opt: TGridOptions;
  Opt2: TGridOptions2;
  Path: string;

  procedure GetValue(optStr:string; aOpt:TGridOption);
  begin
    if Cfg.GetValue(Path+OptStr+'/value', False) then Opt:=Opt+[aOpt];
  end;
  procedure GetValue2(optStr:string; aOpt:TGridOption2);
  begin
    if Cfg.GetValue(Path+OptStr+'/value', False) then Opt2:=Opt2+[aOpt];
  end;
begin
  Opt:=[];
  Opt2:=[];
  Path:='grid/design/options/';
  GetValue('goFixedVertLine', goFixedVertLine);
  GetValue('goFixedHorzLine', goFixedHorzLine);
  GetValue('goVertLine',goVertLine);
  GetValue('goHorzLine',goHorzLine);
  GetValue('goRangeSelect',goRangeSelect);
  GetValue('goDrawFocusSelected',goDrawFocusSelected);
  GetValue('goRowSizing',goRowSizing);
  GetValue('goColSizing',goColSizing);
  GetValue('goRowMoving',goRowMoving);
  GetValue('goColMoving',goColMoving);
  GetValue('goEditing',goEditing);
  GetValue('goAutoAddRows',goAutoAddRows);
  GetValue('goRowSelect',goRowSelect);
  GetValue('goTabs',goTabs);
  GetValue('goAlwaysShowEditor',goAlwaysShowEditor);
  GetValue('goThumbTracking',goThumbTracking);
  GetValue('goColSpanning', goColSpanning);
  GetValue('goRelaxedRowSelect',goRelaxedRowSelect);
  GetValue('goDblClickAutoSize',goDblClickAutoSize);
  GetValue('goAutoAddRowsSkipContentCheck',goAutoAddRowsSkipContentCheck);
  GetValue('goRowHighlight',goRowHighlight);
  if Version>=2 then begin
    GetValue('goSmoothScroll',goSmoothScroll);
  end;
  GetValue2('goScrollToLastRow',goScrollToLastRow);
  GetValue2('goScrollToLastCol',goScrollToLastCol);

  Options:=Opt;
  Options2:=Opt2;
end;

procedure TCustomGrid.Loaded;
begin
  inherited Loaded;
  VisualChange;
end;

procedure TCustomGrid.LockEditor;
begin
  inc(FEditorHidingCount);
  {$ifdef dbgGrid}DebugLn('==> LockEditor: ', dbgs(FEditorHidingCount)); {$endif}
end;

constructor TCustomGrid.Create(AOwner: TComponent);
begin
  // Inherited create Calls SetBounds->WM_SIZE->VisualChange so
  // fGrid needs to be created before that
  FCols:=TIntegerList.Create;
  FRows:=TIntegerList.Create;
  FGCache.AccumWidth:=TIntegerList.Create;
  FGCache.AccumHeight:=TIntegerList.Create;
  FGCache.ClickCell := point(-1, -1);
  inherited Create(AOwner);

  FVSbVisible := -1;
  FHSbVisible := -1;

  FColumns := CreateColumns;

  FTitleFont := TFont.Create;
  FTitleFont.OnChange := @OnTitleFontChanged;
  FTitleFontIsDefault := True;

  FAutoAdvance := aaRight;
  FTabAdvance := aaRightDown;
  FAutoEdit := True;
  FFocusRectVisible := True;
  FDefaultDrawing := True;
  FOptions:=
    [goFixedVertLine, goFixedHorzLine, goVertLine, goHorzLine, goRangeSelect,
     goSmoothScroll ];
  FScrollbars:=ssAutoBoth;
  fGridState:=gsNormal;
  FDefColWidth:=-1;
  FDefRowHeight:=-1;
  FGridLineColor:=clSilver;
  FFixedGridLineColor := cl3DDKShadow;
  FGridLineStyle:=psSolid;
  FGridLineWidth := 1;
  fFocusColor:=clRed;
  FFixedColor:=clBtnFace;
  FFixedHotColor:=cl3DLight;
  FSelectedColor:= clHighlight;
  FDisabledFontColor:=clGrayText;
  FRange:=Rect(-1,-1,-1,-1);
  FDragDx:=3;
  SetBounds(0,0,200,100);
  ColCount:=5;
  RowCount:=5;
  FixedCols:=1;
  FixedRows:=1;
  Editor:=nil;
  FBorderColor := cl3DDKShadow;
  FGridBorderStyle := bsSingle;
  UpdateBorderStyle;
  FIgnoreClick := False;

  ParentColor := False;
  Color:=clWindow;
  FAlternateColor := Color;
  FAltColorStartNormal := true;

  FDefaultTextStyle := Canvas.TextStyle;
  FDefaultTextStyle.Wordbreak := False;
  FDefaultTextStyle.SingleLine:= True;

  FCellHintPriority := chpAllNoDefault;

  FButtonEditor := TButtonCellEditor.Create(nil);
  FButtonEditor.Name:='ButtonEditor';
  FButtonEditor.Caption:='...';
  FButtonEditor.Visible:=False;
  FButtonEditor.Width:=25;
  FButtonEditor.OnClick := @EditButtonClicked;

  FStringEditor := TStringCellEditor.Create(nil);
  FStringEditor.name :='StringEditor';
  FStringEditor.Text:='';
  FStringEditor.Visible:=False;
  FStringEditor.Align:=alNone;
  FStringEditor.BorderStyle := bsNone;

  FPicklistEditor := TPickListCellEditor.Create(nil);
  FPickListEditor.Name := 'PickListEditor';
  FPickListEditor.Visible := False;
  FPickListEditor.AutoSize := false;

  FButtonStringEditor := TCompositeCellEditor.Create(nil);
  FButtonStringEditor.Name:='ButtonTextEditor';
  FButtonStringEditor.Visible:=False;
  FButtonStringEditor.AddEditor(FStringEditor, alClient, true);
  FButtonStringEditor.AddEditor(FButtonEditor, alRight, false);

  FFastEditing := True;
  TabStop := True;
  FAllowOutboundEvents:=True;

  FHeaderHotZones := [gzFixedCols];
  FHeaderPushZones := [gzFixedCols];
  ResetHotCell;
  ResetPushedCell;
  FSortOrder := soAscending;
  FSortColumn:=-1;
  FAscImgInd:=-1;
  FDescImgInd:=-1;

  FValidateOnSetSelection := false;

  FColRowDragIndicatorColor := clRed;

  FSpecialCursors[gcsColWidthChanging] := crHSplit;
  FSpecialCursors[gcsRowHeightChanging] := crVSplit;
  FSpecialCursors[gcsDragging] := crMultiDrag;

  varRubberSpace := Scale96ToScreen(constRubberSpace);
  varCellPadding := Scale96ToScreen(constCellPadding);
  varColRowBorderTolerance := Scale96ToScreen(constColRowBorderTolerance);
end;

destructor TCustomGrid.Destroy;
begin
  {$Ifdef DbgGrid}DebugLn('TCustomGrid.Destroy');{$Endif}
  FreeThenNil(FButtonStringEditor);
  FreeThenNil(FPickListEditor);
  FreeThenNil(FStringEditor);
  FreeThenNil(FButtonEditor);
  FreeThenNil(FColumns);
  FreeThenNil(FGCache.AccumWidth);
  FreeThenNil(FGCache.AccumHeight);
  FreeThenNil(FCols);
  FreeThenNil(FRows);
  FreeThenNil(FTitleFont);
  FEditor := nil;
  inherited Destroy;
end;

procedure TCustomGrid.LoadSub(ACfg: TXMLConfig);
var
  Version: Integer;
begin
  Version:=ACfg.GetValue('grid/version',-1);
  if Version=-1 then raise Exception.Create(rsNotAValidGridFile);
  BeginUpdate;
  LoadContent(ACfg, Version);
  EndUpdate;
end;

procedure TCustomGrid.LoadFromFile(FileName: string);
var
  Cfg: TXMLConfig;
begin
  if not FileExistsUTF8(FileName) then
    raise Exception.Create(rsGridFileDoesNotExist);
  Cfg:=TXMLConfig.Create(nil);
  Try
    Cfg.Filename := FileName;
    LoadSub(Cfg);
  Finally
    FreeThenNil(Cfg);
  end;
end;

procedure TCustomGrid.LoadFromStream(AStream: TStream);
var
  Cfg: TXMLConfig;
begin
  Cfg:=TXMLConfig.Create(nil);
  Try
    Cfg.ReadFromStream(AStream);
    LoadSub(Cfg);
  Finally
    FreeThenNil(Cfg);
  end;
end;

procedure TCustomGrid.SaveToFile(FileName: string);
var
  Cfg: TXMLConfig;
begin
  if FileExistsUTF8(FileName) then
    DeleteFileUTF8(FileName);
  Cfg:=TXMLConfig.Create(nil);
  Try
    Cfg.FileName := FileName;
    SaveContent(Cfg);
    Cfg.Flush;
  Finally
    FreeThenNil(Cfg);
  end;
end;

procedure TCustomGrid.SaveToStream(AStream: TStream);
var
  Cfg: TXMLConfig;
begin
  Cfg:=TXMLConfig.Create(nil);
  Try
    Cfg.Clear;
    SaveContent(Cfg);
    Cfg.WriteToStream(AStream);
  Finally
    FreeThenNil(Cfg);
  end;
end;

procedure TCustomGrid.ScaleFontsPPI(const AToPPI: Integer; const AProportion: Double);
var
  LTitleFontIsDefault: Boolean;
  I: Integer;
begin
  inherited ScaleFontsPPI(AToPPI, AProportion);
  LTitleFontIsDefault := FTitleFontIsDefault;
  DoScaleFontPPI(TitleFont, AToPPI, AProportion);
  FTitleFontIsDefault := LTitleFontIsDefault;
  for I := 0 to FColumns.Count-1 do
    FColumns[I].ScaleFontsPPI(AToPPI, AProportion);
end;

type
  TWinCtrlAccess=class(TWinControl);

procedure TCustomGrid.SetFocus;
var
  NextControl: TWinControl;
  ParentForm: TCustomForm;
  ForwardTab: boolean;
begin
  {$IFDEF dbgGrid}
  DebugLnEnter('TCustomGrid.SetFocus INIT.');
  {$ENDIF}
  if (Editor<>nil) and Editor.Focused and
    ([gfEditorTab,gfRevEditorTab]*GridFlags<>[]) then begin
    // Editor was doing TAB. Focus next control instead
    ForwardTab:= gfEditorTab in GridFlags;
    GridFlags:=GridFlags-[gfEditorTab,gfRevEditorTab];
    ParentForm:=GetParentForm(Self);
    if ParentForm<>nil then begin
      NextControl:=TWinCtrlAccess(Pointer(ParentForm)).FindNextControl(Self,
                                                      ForwardTab, true, false);
      if NextControl<>nil then begin
        {$IFDEF dbgGrid}
        DebugLn('Was tabbing, will focus: ',dbgsname(NextControl));
        {$ENDIF}
        if (NextControl<>Self) and (NextControl<>Editor) then begin
          NextControl.SetFocus;
          {$ifdef DbgGrid}
          DebugLnExit('Skipping inherited, EXIT');
          {$endif}
          exit;
        end;
      end;
    end;
  end;

  if (Editor <> nil) and (Editor.Visible) then
     Editor.SetFocus
  else
     inherited SetFocus;

  {$IFDEF dbgGrid}
  DebugLnExit('TCustomGrid.SetFocus END');
  {$ENDIF}
end;

{$ifdef WINDOWS}
// editor focusing make bad on IME input.
procedure TCustomGrid.IMEStartComposition(var Msg: TMessage);
begin
  EditorSetValue;
  if EditingAllowed(FCol) and CanEditShow and (not FEditorShowing) and
     (Editor<>nil) and (not Editor.Visible) and (not EditorLocked) then
  begin
    // prepare IME input on Editor
    Editor.Visible:=True;
    FEditorOldValue := GetCells(FCol,FRow);
    EditorSelectAll;
    FGridState := gsNormal;
    Editor.Dispatch(Msg);
  end;
end;

procedure TCustomGrid.IMEComposition(var Msg: TMessage);
begin
  if EditingAllowed(FCol) and CanEditShow and (not FEditorShowing) and
     (Editor<>nil) and (not Editor.Visible) and (not EditorLocked) then
    Editor.Dispatch(Msg);
end;

procedure TCustomGrid.IMEEndComposition(var Msg: TMessage);
begin
  if EditingAllowed(FCol) and CanEditShow and (not FEditorShowing) and
     (Editor<>nil) and (not Editor.Visible) and (not EditorLocked) then
    Editor.Dispatch(Msg);
end;

{$endif}

function TCustomGrid.ClearCols: Boolean;
begin
  Result:=False;
  if FCols.Count=0 then
    exit; // already cleared
  if EditorMode then
    EditorMode:=False;
  // save some properties
  FGridPropBackup.FixedColCount := FFixedCols;
  FGridPropBackup.ColCount      := ColCount;
  // clear structure
  FFixedCols:=0;
  FCols.Count:=0;
  FGCache.TLColOff := 0;
  Result:=True;
end;

function TCustomGrid.ClearRows: Boolean;
begin
  Result:=False;
  if FRows.Count=0 then
    exit; // already cleared
  if EditorMode then
    EditorMode:=False;
  // save some properties
  FGridPropBackup.FixedRowCount := FFixedRows;
  FGridPropBackup.RowCount      := RowCount;
  // clear structure
  FFixedRows:=0;
  FRows.Count:=0;
  FGCache.TlRowOff := 0;
  Result:=True;
end;

procedure TCustomGrid.Clear;
var
  OldR,OldC: Integer;
  RowChanged, ColChanged: Boolean;
begin
  if EditorMode then
    EditorMode := false;
  OldR:=RowCount;
  OldC:=ColCount;
  RowChanged := ClearRows;
  ColChanged := ClearCols;
  if not (RowChanged or ColChanged) then
    exit; // already cleared
  FGridPropBackup.ValidData := True;
  FTopLeft:=Point(-1,-1);
  FRange:=Rect(-1,-1,-1,-1);
  FGCache.HotCellPainted := false;
  ResetHotCell;
  VisualChange;
  SizeChanged(OldR,OldC);
end;

procedure TCustomGrid.AutoAdjustColumns;
var
  i: Integer;
begin
  For i:=0 to ColCount-1 do
    AutoAdjustColumn(i);
end;

{ TVirtualGrid }

function TVirtualGrid.GetCells(Col, Row: Integer): PCellProps;
begin
  // todo: Check range
  Result:=nil;
  if not IsColumnIndexValid(Col) or not IsRowIndexValid(Row) then
    raise EGridException.CreateFmt(rsIndexOutOfRange, [Col, Row]);
  Result:=FCellArr[Col,Row];
end;

function TVirtualGrid.GetRows(Row: Integer): PColRowProps;
begin
  Result:= FRowArr[Row, 0];
end;

function TVirtualGrid.GetCols(Col: Integer): PColRowProps;
begin
  result:=FColArr[Col, 0];
end;

procedure TVirtualGrid.SetCells(Col, Row: Integer; const AValue: PCellProps);
var
   Cell: PCellProps;
begin
  // todo: Check range
  Cell:=FCellArr[Col,Row];
  if Cell<>nil then
    DisposeCell(Cell);
  Cell:=AValue;
  FCellArr[Col,Row]:=Cell;
end;

procedure TVirtualGrid.SetRows(Row: Integer; const Avalue: PColRowProps);
var
   C: PColRowProps;
begin
  // todo: Check range
  C:=FRowArr[Row,0];
  if C<>nil then DisposeColRow(C);
  FRowArr[Row,0]:=AValue;
end;

procedure TVirtualGrid.SetColCount(const Avalue: Integer);
begin
  if FColCount=Avalue then Exit;
  {$Ifdef dbgMem}
    DebugLn('TVirtualGrid.SetColCount Value=',AValue);
  {$Endif}
  FColCount:=AValue;
  {$Ifdef dbgMem}
    DBGOut('TVirtualGrid.SetColCount->FCOLS: ');
  {$Endif}
  FColArr.SetLength(FColCount, 1);
  {$Ifdef dbgMem}
    DBGOut('TVirtualGrid.SetColCount->FCELLS(',FColCount,',',FRowCount,'): ');
  {$Endif}
  FCellArr.SetLength(FColCount, FRowCount);
end;


procedure TVirtualGrid.SetRowCount(const Avalue: Integer);
begin
  if FRowCount=AValue then Exit;
  {$Ifdef dbgMem}
    DebugLn('TVirtualGrid.SetRowCount Value=',AValue);
  {$Endif}
  FRowCount:=AValue;
  {$Ifdef dbgMem}
    DBGOut('TVirtualGrid.SetRowCount->FROWS: ');
  {$Endif}
  FRowArr.SetLength(FRowCount,1);
  {$Ifdef dbgMem}
    DBGOut('TVirtualGrid.SetRowCount->FCELLS(',FColCount,',',FRowCount,'): ');
  {$Endif}
  FCellArr.SetLength(FColCount, FRowCount);
end;

procedure TVirtualGrid.SetCols(Col: Integer; const Avalue: PColRowProps);
var
   C: PColRowProps;
begin
  // todo: Check range
  C:=FColArr[Col,0];
  if C<>nil then DisposeColRow(C);
  FColArr[Col,0]:=AValue;
end;

procedure TVirtualGrid.Clear;
begin
  {$Ifdef dbgMem}DBGOut('FROWARR: ');{$Endif}FRowArr.Clear;
  {$Ifdef dbgMem}DBGOut('FCOLARR: ');{$Endif}FColArr.Clear;
  {$Ifdef dbgMem}DBGOut('FCELLARR: ');{$Endif}FCellArr.Clear;
  FColCount:=0;
  FRowCount:=0;
end;

procedure TVirtualGrid.DisposeCell(var P: PCellProps);
begin
  if P<>nil then begin
    if P^.Text<>nil then StrDispose(P^.Text);
    Dispose(P);
    P:=nil;
  end;
end;

procedure TVirtualGrid.DisposeColRow(var p: PColRowProps);
begin
  if P<>nil then begin
    Dispose(P);
    P:=nil;
  end;
end;

function TVirtualGrid.IsColumnIndexValid(AIndex: Integer): boolean;
begin
  Result := (AIndex>=0) and (AIndex<ColCount);
end;

function TVirtualGrid.IsRowIndexValid(AIndex: Integer): boolean;
begin
  Result := (AIndex>=0) and (AIndex<RowCount);
end;

function TVirtualGrid.GetDefaultCell: PcellProps;
begin
  New(Result);
  Result^.Text:=nil;
  Result^.Attr:=nil;
end;

function TVirtualGrid.GetDefaultColRow: PColRowProps;
begin
  New(Result);
  Result^.FixedAttr:=nil;
  Result^.NormalAttr:=nil;
  Result^.Size:=-1;
end;

procedure TVirtualGrid.doDestroyItem(Sender: TObject; Col,Row: Integer;
  var Item: Pointer);
begin
  {$Ifdef dbgMem}
    DebugLn('TVirtualGrid.doDestroyItem Col=',Col,' Row= ',
            Row,' Item=',Integer(Item));
  {$endif}
  if Item<>nil then begin
    if (Sender=FColArr)or(Sender=FRowArr) then begin
      DisposeColRow(PColRowProps(Item));
    end else begin
      DisposeCell(PCellProps(Item));
    end;
    Item:=nil;
  end;
end;

procedure TVirtualGrid.doNewItem(Sender: TObject; Col,Row: Integer;
  var Item: Pointer);
begin
  {$Ifdef dbgMem}
    DebugLn('TVirtualGrid.doNewItem Col=',Col,' Row= ',
            Row,' Item=',Integer(Item));
  {$endif}
  if Sender=FColArr then begin
    // Procesar Nueva Columna
    Item:=GetDefaultColRow;
  end else
  if Sender=FRowArr then begin
    // Procesar Nuevo Renglon
    Item:=GetDefaultColRow;
  end else begin
    // Procesar Nueva Celda
    Item:=nil;
  end;
end;

constructor TVirtualGrid.Create;
begin
  Inherited Create;
  {$Ifdef DbgGrid}DebugLn('TVirtualGrid.Create');{$Endif}
  FCellArr:=TPointerPointerArray.Create;
  FCellArr.OnDestroyItem:=@doDestroyItem;
  FCellArr.OnNewItem:=@doNewItem;
  FColArr:= TPointerPointerArray.Create;
  FColArr.OnDestroyItem:=@doDestroyItem;
  FColArr.OnNewItem:=@doNewItem;
  FRowArr:=TPointerPointerArray.Create;
  FRowArr.OnDestroyItem:=@doDestroyItem;
  FRowArr.OnNewItem:=@doNewItem;
  RowCount:=4;
  ColCount:=4;
end;

destructor TVirtualGrid.Destroy;
begin
  {$Ifdef DbgGrid}DebugLn('TVirtualGrid.Destroy');{$Endif}
  Clear;
  FreeThenNil(FRowArr);
  FreeThenNil(FColArr);
  FreeThenNil(FCellArr);
  inherited Destroy;
end;

procedure TVirtualGrid.DeleteColRow(IsColumn: Boolean; index: Integer);
begin
  FCellArr.DeleteColRow(IsColumn, index);
  if IsColumn then begin
    FColArr.DeleteColRow(True, index);
    Dec(FColCount);
  end else begin
    FRowArr.DeleteColRow(True, index);
    Dec(fRowCount);
  end;
end;

procedure TVirtualGrid.MoveColRow(IsColumn: Boolean; FromIndex, ToIndex: Integer);
begin
  FCellArr.MoveColRow(IsColumn, FromIndex, ToIndex);
  if IsColumn then FColArr.MoveColRow(True, FromIndex, ToIndex)
  else             FRowArr.MoveColRow(True, FromIndex, ToIndex);
end;

procedure TVirtualGrid.ExchangeColRow(IsColumn: Boolean; index, WithIndex: Integer);
begin
  FCellArr.ExchangeColRow(IsColumn, index, WithIndex);
  if IsColumn then FColArr.ExchangeColRow(true, index, WithIndex)
  else             FRowArr.ExchangeColRow(True, index, WithIndex);
end;

procedure TVirtualGrid.InsertColRow(IsColumn: Boolean; Index: Integer);
begin
  if IsColumn then begin
    ColCount := ColCount + 1;
    MoveColRow(true, ColCount-1, Index);
  end else begin
    RowCount := RowCount + 1;
    MoveColRow(false, RowCount-1, Index);
  end;
end;

procedure TStringCellEditor.WndProc(var TheMessage: TLMessage);
begin
	{$IfDef GridTraceMsg}
	TransMsg('StrCellEditor: ', TheMessage);
	{$Endif}
  if FGrid<>nil then
    case TheMessage.Msg of
      LM_CLEAR,
      LM_CUT,
      LM_PASTE:
        begin
          if FGrid.EditorIsReadOnly then
            exit;
        end;
    end;
  inherited WndProc(TheMessage);
end;

{ TStringCellEditor }

procedure TStringCellEditor.Change;
begin
  {$IfDef DbgGrid} DebugLn('TStringCellEditor.Change INIT text=',Text);{$ENDIF}
  inherited Change;
  if (FGrid<>nil) and Visible then begin
    FGrid.EditorTextChanged(FCol, FRow, Text);
  end;
  {$IfDef DbgGrid} DebugLn('TStringCellEditor.Change END');{$ENDIF}
end;

procedure TStringCellEditor.EditingDone;
begin
  inherited EditingDone;
  if FGrid<>nil then
    FGrid.EditingDone;
end;

procedure TStringCellEditor.KeyDown(var Key: Word; Shift: TShiftState);
  function AllSelected: boolean;
  begin
    result := (SelLength>0) and (SelLength=UTF8Length(Text));
  end;
  function AtStart: Boolean;
  begin
    Result:= (SelStart=0);
  end;
  function AtEnd: Boolean;
  begin
    result := ((SelStart+1)>UTF8Length(Text)) or AllSelected;
  end;
  procedure doEditorKeyDown;
  begin
    if FGrid<>nil then
      FGrid.EditorkeyDown(Self, key, shift);
  end;
  procedure doGridKeyDown;
  begin
    if FGrid<>nil then
      FGrid.KeyDown(Key, shift);
  end;
  function GetFastEntry: boolean;
  begin
    if FGrid<>nil then
      Result := FGrid.FastEditing
    else
      Result := False;
  end;
  procedure CheckEditingKey;
  begin
    if (FGrid=nil) or FGrid.EditorIsReadOnly then
      Key := 0;
  end;
var
  IntSel: boolean;
begin
  {$IfDef dbgGrid}
  DebugLn('TStringCellEditor.KeyDown INIT: Key=', Dbgs(Key),
    ' SelStart=',Dbgs(SelStart),' SelLenght=',dbgs(SelLength),
    ' Len(text)=',dbgs(Length(Text)),' Utf8Len(Text)=',dbgs(UTF8Length(Text)));
  {$Endif}
  inherited KeyDown(Key,Shift);
  case Key of
    VK_F2:
      if AllSelected then begin
        SelLength := 0;
        SelStart := Length(Text);
      end;
    VK_DELETE, VK_BACK:
      CheckEditingKey;
    VK_UP, VK_DOWN:
      doGridKeyDown;
    VK_LEFT, VK_RIGHT:
      if GetFastEntry then begin
        IntSel:=
          ((Key=VK_LEFT) and not AtStart) or
          ((Key=VK_RIGHT) and not AtEnd);
      if not IntSel then begin
          doGridKeyDown;
      end;
    end;
    VK_END, VK_HOME:
      ;
    VK_ESCAPE:
      begin
        doGridKeyDown;
        if key<>0 then begin
          SetEditText(FGrid.FEditorOldValue);
          FGrid.EditorHide;
        end;
      end;
    else
      doEditorKeyDown;
  end;
  {$IfDef dbgGrid}
  DebugLn('TStringCellEditor.KeyDown END: Key=', Dbgs(Key),
    ' SelStart=',Dbgs(SelStart),' SelLenght=',Dbgs(SelLength));
  {$Endif}
end;

procedure TStringCellEditor.msg_SetMask(var Msg: TGridMessage);
begin
  EditMask:=msg.Value;
end;


procedure TStringCellEditor.msg_SetValue(var Msg: TGridMessage);
begin
  Text:=Msg.Value;
  SelStart := UTF8Length(Text);
end;

procedure TStringCellEditor.msg_GetValue(var Msg: TGridMessage);
begin
  Msg.Col:=FCol;
  Msg.Row:=FRow;
  Msg.Value:=Text;
end;

procedure TStringCellEditor.msg_SetGrid(var Msg: TGridMessage);
begin
  FGrid:=Msg.Grid;
  Msg.Options:=EO_AUTOSIZE or EO_SELECTALL or EO_HOOKKEYPRESS or EO_HOOKKEYUP;
end;

procedure TStringCellEditor.msg_SelectAll(var Msg: TGridMessage);
begin
  SelectAll;
end;

procedure TStringCellEditor.msg_SetPos(var Msg: TGridMessage);
begin
  FCol := Msg.Col;
  FRow := Msg.Row;
end;

procedure TStringCellEditor.msg_GetGrid(var Msg: TGridMessage);
begin
  Msg.Grid := FGrid;
  Msg.Options:= EO_IMPLEMENTED;
end;

constructor TStringCellEditor.Create(Aowner: TComponent);
begin
  inherited Create(Aowner);
  AutoSize := false;
end;

{ TStringGridStrings }

function TStringGridStrings.ConvertIndexLineCol(Index: Integer; var Line, Col: Integer): boolean;
begin
  if FIsCol then
    if (Index < 0) or (Index >= FGrid.RowCount) then
      Result := False
    else begin
      Line := FIndex;
      Col := Index;
      Result := True;
    end
  else
    if (Index < 0) or (Index >= FGrid.ColCount) then
      Result := False
    else begin
      Line := Index;
      Col := FIndex;
      Result := True;
    end;
end;

procedure TStringGridStrings.Clear;
var
  I: Integer;
begin
  if FIsCol then begin
    for I := 0 to FGrid.RowCount - 1 do begin
      FGrid.Cells[FIndex, I] := '';
      FGrid.Objects[FIndex, I] := nil;
    end;
  end else begin
    for I := 0 to FGrid.ColCount - 1 do begin
      FGrid.Cells[I, FIndex] := '';
      FGrid.Objects[I, FIndex] := nil;
    end;
  end;
  FAddedCount := 0;
end;

function TStringGridStrings.Add(const S: string): Integer;
var
  Line, Col: Integer;
begin
  if ConvertIndexLineCol(FAddedCount, Line, Col) then begin
    FGrid.Cells[Line, Col] := S;
    Result := FAddedCount;
    Inc(FAddedCount);
  end else
    Result := -1;
end;

function TStringGridStrings.Get(Index: Integer): string;
var
  Line, Col: Integer;
begin
  if ConvertIndexLineCol(Index, Line, Col) then
    Result := FGrid.Cells[Line, Col]
  else
    Result := ''
end;

function TStringGridStrings.GetCount: Integer;
begin
  if FIsCol then
    Result := FGrid.RowCount
  else
    Result := FGrid.ColCount;
end;

function TStringGridStrings.GetObject(Index: Integer): TObject;
var
  Line, Col: Integer;
begin
  if ConvertIndexLineCol(Index, Line, Col) then
    Result := FGrid.Objects[Line, Col]
  else
    Result := nil;
end;

procedure TStringGridStrings.Put(Index: Integer; const S: string);
var
  Line, Col: Integer;

  procedure RaiseError;
  begin
    raise EGridException.Create('Can not add String');
  end;

begin
  if ConvertIndexLineCol(Index, Line, Col) then
    FGrid.Cells[Line, Col] := S
  else
    RaiseError;
end;

procedure TStringGridStrings.PutObject(Index: Integer; aObject: TObject);
var
  Line, Col: Integer;

  procedure RaiseError;
  begin
    raise EGridException.Create('Can not add Object');
  end;

begin
  if ConvertIndexLineCol(Index, Line, Col) then
    FGrid.Objects[Line, Col] := aObject
  else
    RaiseError;
end;

constructor TStringGridStrings.Create(aGrid: TCustomStringGrid; OwnerMap: TMap; aIscol: boolean;
  aIndex: Longint);
begin
  inherited Create;
  FGrid := aGrid;
  FIsCol := aIsCol;
  FIndex := aIndex;
  FOwner := OwnerMap;
  if FOwner<>nil then
    FOwner.Add(FIndex, Self);
end;

destructor TStringGridStrings.Destroy;
begin
  if FOwner<>nil then
    FOwner.Delete(FIndex);
  inherited Destroy;
end;

procedure TStringGridStrings.Assign(Source: TPersistent);
var
  I, StrNum: Integer;
begin
  if Source is TStrings then begin
    try
      BeginUpdate;
      StrNum := TStrings(Source).Count;
      if StrNum > GetCount then StrNum := GetCount;
      for I := 0 to StrNum - 1 do begin
        Put(I, TStrings(Source).Strings[I]);
        PutObject(I, TStrings(Source).Objects[I]);
      end;
    finally
      EndUpdate;
    end;
  end else
    inherited Assign(Source);
end;

procedure TStringGridStrings.Delete(Index: Integer);
begin
  raise EGridException.Create('Can not delete value.');
end;

procedure TStringGridStrings.Insert(Index: Integer; const S: string);
begin
  raise EGridException.Create('Can not insert value.');
end;



{ TCustomDrawGrid }

function TCustomDrawGrid.CellNeedsCheckboxBitmaps(const aCol, aRow: Integer): boolean;
var
  C: TGridColumn;
begin
  Result := false;
  if (aRow>=FixedRows) and Columns.Enabled then begin
    C := ColumnFromGridColumn(aCol);
    result := (C<>nil) and (C.ButtonStyle=cbsCheckboxColumn)
  end;
end;

procedure TCustomDrawGrid.DrawCellCheckboxBitmaps(const aCol, aRow: Integer;
  const aRect: TRect);
var
  AState: TCheckboxState;
begin
  AState := cbUnchecked;
  GetCheckBoxState(aCol, aRow, aState);
  DrawGridCheckboxBitmaps(aCol, aRow, aRect, aState);
end;

function TCustomDrawGrid.GetEditorValue(ACol, ARow: Integer): String;
var
  msg: TGridMessage;
begin
  if Assigned(Editor) and Editor.Visible then begin
    Msg.LclMsg.msg:=GM_GETVALUE;
    Msg.grid:=Self;
    Msg.Col:=ACol;
    Msg.Row:=ARow;
    Msg.Value:='';
    Editor.Dispatch(Msg);
    Result:=Msg.Value;
  end;
end;

procedure TCustomDrawGrid.CellClick(const ACol, ARow: Integer; const Button:TMouseButton);
begin
  if (Button=mbLeft) and CellNeedsCheckboxBitmaps(ACol, ARow) then
    ToggleCheckbox;
end;

procedure TCustomDrawGrid.DrawCell(aCol,aRow: Integer; aRect: TRect;
  aState:TGridDrawState);
var
  OldDefaultDrawing: boolean;
begin
  if Assigned(OnDrawCell) and not(CsDesigning in ComponentState) then begin
    PrepareCanvas(aCol, aRow, aState);
    if DefaultDrawing then
      DefaultDrawCell(aCol, aRow, aRect, aState);
    OnDrawCell(Self,aCol,aRow,aRect,aState)
  end else begin
    OldDefaultDrawing:=FDefaultDrawing;
    FDefaultDrawing:=True;
    try
      PrepareCanvas(aCol, aRow, aState);
    finally
      FDefaultDrawing:=OldDefaultDrawing;
    end;
    DefaultDrawCell(aCol,aRow,aRect,aState);
  end;
  DrawCellGrid(aCol,aRow,aRect,aState);
end;

procedure TCustomDrawGrid.DrawFocusRect(aCol, aRow: Integer; ARect: TRect);
var
  OldFocusColor: TColor;
  OldPenMode: TFPPenMode;
  DrawBits: Byte;
begin
  // Draw focused cell if we have the focus
  if DefaultDrawing and (Self.Focused or
    (EditorAlwaysShown and ((Feditor=nil) or not Feditor.Focused))) then
  begin
    CalcFocusRect(aRect);
    if FUseXORFeatures then begin
      Canvas.SaveHandleState;
      OldFocusColor := FFocusColor;
      FFocusColor:= clWhite;
      OldPenMode:=Canvas.Pen.Mode;
      Canvas.Pen.Mode := pmXOR;
    end;
    DrawBits := BF_RECT;
    if (goRowSelect in Options) and ((fTopLeft.x<>FixedCols) or (FGCache.TLColOff<>0)) then
      DrawBits := DrawBits and not BF_LEFT;
    DrawRubberRect(Canvas, aRect, FFocusColor, DrawBits);
    if FUseXORFeatures then begin
      Canvas.Pen.Mode := OldPenMode;
      Canvas.RestoreHandleState;
      FFocusColor := OldFocusColor;
    end;
  end;
end;

function TCustomDrawGrid.GetCells(ACol, ARow: Integer): string;
begin
  Result:=inherited GetCells(ACol, ARow);
  if (ACol = FEditorCol) and (ARow = FEditorRow) then
    Result:=GetEditorValue(ACol, ARow);
end;

procedure TCustomDrawGrid.GetCheckBoxState(const aCol, aRow: Integer;
  var aState: TCheckboxState);
begin
  if assigned(FOnGetCheckboxState) then
    OnGetCheckboxState(self, aCol, aRow, aState);
end;

procedure TCustomDrawGrid.ColRowExchanged(IsColumn:Boolean; index, WithIndex: Integer);
begin
  if not IsColumn or not Columns.Enabled then
    Fgrid.ExchangeColRow(IsColumn, index, WithIndex);
  if Assigned(OnColRowExchanged) then
    OnColRowExchanged(Self, IsColumn, index, WithIndex);
end;

procedure TCustomDrawGrid.ColRowInserted(IsColumn: boolean; index: integer);
begin
  if not IsColumn or not Columns.Enabled then
    FGrid.InsertColRow(IsColumn, Index);
  NotifyColRowChange(True, IsColumn, Index, Index);
end;

procedure TCustomDrawGrid.ColRowDeleted(IsColumn: Boolean; index: Integer);
begin
  FGrid.DeleteColRow(IsColumn, index);
  NotifyColRowChange(False, IsColumn, Index, Index);
end;

procedure TCustomDrawGrid.ColRowMoved(IsColumn: Boolean; FromIndex, ToIndex: Integer);
begin
  inherited ColRowMoved(IsColumn, FromIndex, ToIndex);

  // now move content, if Columns.Enabled and IsColumn then
  // first row header has been already moved, what is in
  // cells[0,0]-cells[colCount-1,0] doesn't matter because
  // columns should take precedence.
  FGrid.MoveColRow(IsColumn, FromIndex, ToIndex);

  if Assigned(OnColRowMoved) then
    OnColRowMoved(Self, IsColumn, FromIndex, toIndex);
end;

procedure TCustomDrawGrid.HeaderClick(IsColumn: Boolean; index: Integer);
begin
  inherited HeaderClick(IsColumn, index);
  if Assigned(OnHeaderClick) then OnHeaderClick(Self, IsColumn, index);
end;

procedure TCustomDrawGrid.HeaderSized(IsColumn: Boolean; index: Integer);
begin
  inherited HeaderSized(IsColumn, index);
  if Assigned(OnHeaderSized) then OnHeaderSized(Self, IsColumn, index);
end;

procedure TCustomDrawGrid.HeaderSizing(const IsColumn: boolean; const AIndex,
  ASize: Integer);
begin
  inherited HeaderSizing(IsColumn, AIndex, ASize);
  if Assigned(OnHeaderSizing) then
    OnHeaderSizing(self, IsColumn, AIndex, ASize);
end;

procedure TCustomDrawGrid.KeyDown(var Key: Word; Shift: TShiftState);
begin
  inherited KeyDown(Key, Shift);

  if (Key=VK_SPACE) and CellNeedsCheckboxBitmaps(col, row) then begin
    ToggleCheckbox;
    Key:=0;
  end;
end;

function TCustomDrawGrid.GetEditMask(aCol, aRow: Longint): string;
begin
  result:='';
  if assigned(OnGetEditMask) then OnGetEditMask(self, aCol, aRow, Result);
end;

function TCustomDrawGrid.GetEditText(aCol, aRow: Longint): string;
begin
  result:='';
  if assigned(OnGetEditText) then OnGetEditText(self, aCol, aRow, Result);
  FEditorOldValue:=Result;
  FEditorCol:=aCol;
  FEditorRow:=aRow;
end;

procedure TCustomDrawGrid.GridMouseWheel(shift: TShiftState; Delta: Integer);
var
  ScrollCols: boolean;
begin
  if MouseWheelOption=mwCursor then
    inherited GridMouseWheel(shift, Delta)
  else
  if Delta<>0 then begin
    ScrollCols := (ssCtrl in shift);
    if ScrollCols then
    begin
      if not TrySmoothScrollBy(Delta*DefaultColWidth, 0) then
        TryScrollTo(FTopLeft.x+Delta, FTopLeft.y, True, False);
    end else
    begin
      if not TrySmoothScrollBy(0, Delta*DefaultRowHeight*Mouse.WheelScrollLines) then
        TryScrollTo(FTopLeft.x, FTopLeft.y+Delta, False, True); // scroll only 1 line if above scrolling failed (probably due to too high line)
    end;
    if EditorMode then
      EditorPos;
  end;
end;

procedure TCustomDrawGrid.NotifyColRowChange(WasInsert, IsColumn: boolean;
  FromIndex,ToIndex: Integer);
begin
  if WasInsert then begin
    if assigned(OnColRowInserted) then
      OnColRowInserted(Self, IsColumn, FromIndex, ToIndex)
  end else begin
    if assigned(OnColRowDeleted) then
      OnColRowDeleted(Self, IsColumn, FromIndex, ToIndex);
  end;
end;

procedure TCustomDrawGrid.SetEditText(ACol, ARow: Longint; const Value: string);
begin
  if Assigned(OnSetEditText) then
    OnSetEditText(Self, aCol, aRow, Value);
  inherited SetEditText(aCol, aRow, Value);
end;

procedure TCustomDrawGrid.SizeChanged(OldColCount, OldRowCount: Integer);
begin
  if OldColCount<>ColCount then begin
    fGrid.ColCount:=ColCount;
    if OldColCount>ColCount then
      NotifyColRowChange(False, True, ColCount, OldColCount-1)
    else
      NotifyColRowChange(True, True, OldColCount, ColCount-1);
  end;
  if OldRowCount<>RowCount then begin
    fGrid.RowCount:=RowCount;
    if OldRowCount>RowCount then
      NotifyColRowChange(False, False, RowCount, OldRowCount-1)
    else
      NotifyColRowChange(True, False, OldRowCount, RowCount-1);
  end;
end;

procedure TCustomDrawGrid.ToggleCheckbox;
var
  TempColumn: TGridColumn;
  AState: TCheckboxState;
begin
  if not EditingAllowed(Col) then
    exit;

  TempColumn := ColumnFromGridColumn(Col);
  if (TempColumn<>nil) and not TempColumn.ReadOnly then
  begin

    AState := cbGrayed;
    GetCheckboxState(Col, Row, AState);

    if AState=cbChecked then
      AState := cbUnchecked
    else
      AState := cbChecked;

    SetCheckboxState(Col, Row, AState);

    if Assigned(OnCheckboxToggled) then
      OnCheckboxToggled(self, Col, Row, AState);
  end;
end;

procedure TCustomDrawGrid.DrawCellAutonumbering(aCol, aRow: Integer;
  aRect: TRect; const aValue: string);
begin
  DrawCellText(aCol, aRow, aRect, [], aValue);
end;

function TCustomDrawGrid.SelectCell(aCol, aRow: Integer): boolean;
begin
  Result := inherited SelectCell(aCol, aRow);
  if Assigned(OnSelectCell) then
    OnSelectCell(Self, aCol, aRow, Result);
end;

procedure TCustomDrawGrid.SetColor(Value: TColor);
begin
  inherited SetColor(Value);
  Invalidate;
end;

procedure TCustomDrawGrid.SetCheckboxState(const aCol, aRow: Integer;
  const aState: TCheckboxState);
begin
  if assigned(FOnSetCheckboxState) then begin
    OnSetCheckboxState(self, aCol, aRow, aState);
    if DefaultDrawing then
      InvalidateCell(aCol, aRow);
  end;
end;

function TCustomDrawGrid.CreateVirtualGrid: TVirtualGrid;
begin
  Result:=TVirtualGrid.Create;
end;

constructor TCustomDrawGrid.Create(AOwner: TComponent);
begin
  fGrid:=CreateVirtualGrid;
  inherited Create(AOwner);
end;

destructor TCustomDrawGrid.Destroy;
begin
  {$Ifdef DbgGrid}DebugLn('TCustomDrawGrid.Destroy');{$Endif}
  FreeThenNil(FGrid);
  inherited Destroy;
end;

procedure TCustomDrawGrid.DeleteColRow(IsColumn: Boolean; index: Integer);
begin
  DoOPDeleteColRow(IsColumn, Index);
end;

procedure TCustomDrawGrid.DeleteCol(Index: Integer);
begin
  DeleteColRow(True, Index);
end;

procedure TCustomDrawGrid.DeleteRow(Index: Integer);
begin
  DeleteColRow(False, Index);
end;

procedure TCustomDrawGrid.ExchangeColRow(IsColumn: Boolean; index,
  WithIndex: Integer);
begin
  DoOPExchangeColRow(IsColumn, Index, WithIndex);
end;

procedure TCustomDrawGrid.InsertColRow(IsColumn: boolean; index: integer);
begin
  doOPInsertColRow(IsColumn, Index);
end;

procedure TCustomDrawGrid.MoveColRow(IsColumn: Boolean; FromIndex,
  ToIndex: Integer);
begin
  DoOPMoveColRow(IsColumn, FromIndex, ToIndex);
end;

procedure TCustomDrawGrid.SortColRow(IsColumn: Boolean; index: Integer);
begin
  if IsColumn then begin
    if (FFixedRows < RowCount) and (RowCount > 0) then
      Sort(IsColumn, index, FFixedRows, RowCount-1)
  end
  else begin
    if (FFixedCols < ColCount) and (ColCount > 0) then
      Sort(IsColumn, index, FFixedCols, ColCount-1);
  end
end;

procedure TCustomDrawGrid.SortColRow(IsColumn: Boolean; Index, FromIndex,
  ToIndex: Integer);
begin
  Sort(IsColumn, Index, FromIndex, ToIndex);
end;

procedure TCustomDrawGrid.DefaultDrawCell(aCol, aRow: Integer; var aRect: TRect;
  aState: TGridDrawState);
begin
  if (FTitleStyle=tsNative) and (gdFixed in AState) then
    DrawThemedCell(aCol, aRow, aRect, aState)
  else
    DrawFillRect(Canvas, aRect);

  if CellNeedsCheckboxBitmaps(aCol,aRow) then
    DrawCellCheckboxBitmaps(aCol,aRow,aRect)
  else
  begin
    if IsCellButtonColumn(Point(aCol,aRow)) then begin
      DrawButtonCell(aCol,aRow,aRect,aState);
    end
    else begin
      if (goFixedRowNumbering in Options) and (ARow>=FixedRows) and (aCol=0) and
         (FixedCols>0)
      then
        DrawCellAutonumbering(aCol, aRow, aRect, IntToStr(aRow-FixedRows+1));
    end;
    //draw text
    if GetIsCellTitle(aCol, aRow) then
      DrawColumnText(aCol, aRow, aRect, aState)
    else
      DrawTextInCell(aCol,aRow, aRect,aState);
  end;
end;

{ TCustomStringGrid }

procedure TCustomStringGrid.MapFree(var aMap: TMap);
var
  Iterator: TMapIterator;
  SGL: TStringGridStrings;
begin
  if AMap=nil then
    exit;
  Iterator := TMapIterator.Create(AMap);
  Iterator.First;
  while not Iterator.EOM do begin
    Iterator.GetData(SGL);
    if SGL<>nil then
      SGL.Free;
    Iterator.Next;
  end;
  Iterator.Free;
  FreeAndNil(AMap);
end;

function TCustomStringGrid.MapGetColsRows(IsCols: boolean; Index: Integer;
  var AMap: TMap): TStrings;
begin
  if AMap=nil then
    AMap := TMap.Create(itu4, SizeOf(TStringGridStrings));

  if AMap.HasId(Index) then
    AMap.GetData(index, Result)
  else
    Result:=TStringGridStrings.Create(Self, AMap, IsCols, index);
end;

function TCustomStringGrid.GetCells(ACol, ARow: Integer): string;
var
   C: PCellProps;
begin
  Result:='';
  C:=FGrid.Celda[aCol,aRow];
  if C<>nil then Result:=C^ .Text;
end;

function TCustomStringGrid.GetCols(index: Integer): TStrings;
begin
  Result := MapGetColsRows(True,  Index, FColsMap);
end;

function TCustomStringGrid.GetObjects(ACol, ARow: Integer): TObject;
var
  C: PCellProps;
begin
  Result:=nil;
  C:=Fgrid.Celda[aCol,aRow];
  if C<>nil then Result:=C^.Data;
end;

function TCustomStringGrid.GetRows(index: Integer): TStrings;
begin
  Result := MapGetColsRows(False, Index, FRowsMap);
end;

procedure TCustomStringGrid.ReadCells(Reader: TReader);
var
  aCol,aRow: Integer;
  i, c: Integer;
begin
  with Reader do begin
    ReadListBegin;
    c := ReadInteger;
    for i:=1 to c do begin
      aCol := ReadInteger;
      aRow := ReadInteger;
      Cells[aCol,aRow]:= ReadString;
    end;
    {
    repeat
      aCol := ReadInteger;
      aRow := ReadInteger;
      Cells[aCol,aRow] := ReadString;
    until NextValue = vaNull;
    }
    ReadListEnd;
  end;
end;

procedure TCustomStringGrid.SetCells(ACol, ARow: Integer; const AValue: string);
  procedure UpdateCell;
  begin
    if EditorMode and (aCol=FCol)and(aRow=FRow) and
      not (gfEditorUpdateLock in GridFlags) then
    begin
      EditorDoSetValue;
    end;
    InvalidateCell(aCol, aRow);
  end;
var
  C: PCellProps;
begin
  C:= FGrid.Celda[aCol,aRow];
  if C<>nil then begin
    if C^.Text<>nil then
      StrDispose(C^.Text);
    C^.Text:=StrNew(pchar(aValue));
    UpdateCell;
    FModified := True;
  end else begin
    if AValue<>'' then begin
      New(C);
      C^.Text:=StrNew(pchar(Avalue));
      C^.Attr:=nil;
      C^.Data:=nil;
      FGrid.Celda[aCol,aRow]:=C;
      UpdateCell;
      FModified := True;
    end;
  end;
end;

procedure TCustomStringGrid.SetCols(index: Integer; const AValue: TStrings);
var
  SGL: TStringGridStrings;
begin
  SGL := TStringGridStrings.Create(Self, nil, True, index);
  SGL.Assign(AValue);
  SGL.Free;
end;

procedure TCustomStringGrid.SetObjects(ACol, ARow: Integer; AValue: TObject);
var
  c: PCellProps;
begin
  C:=FGrid.Celda[aCol,aRow];
  if c<>nil then C^.Data:=AValue
  else begin
    c:=fGrid.GetDefaultCell;
    c^.Data:=Avalue;
    FGrid.Celda[aCol,aRow]:=c;
  end;
end;

procedure TCustomStringGrid.SetRows(index: Integer; const AValue: TStrings);
var
  SGL: TStringGridStrings;
begin
  SGL := TStringGridStrings.Create(Self, nil, False, index);
  SGL.Assign(AValue);
  SGL.Free;
end;

procedure TCustomStringGrid.WriteCells(Writer: TWriter);
var
  i,j: Integer;
  c: Integer;
begin
  with writer do begin
    WriteListBegin;
    //cell count
    c:=0;
    for i:=0 to ColCount-1 do
      for j:=0 to RowCount-1 do
        if Cells[i,j]<>'' then Inc(c);
    WriteInteger(c);

    for i:=0 to ColCount-1 do
      for j:=0 to RowCount-1 do
        if Cells[i,j]<>'' then begin
          WriteInteger(i);
          WriteInteger(j);
          WriteString(Cells[i,j]);
        end;
    WriteListEnd;
  end;
end;

procedure TCustomStringGrid.CopyCellRectToClipboard(const R: TRect);
var
  SelStr, SelHTMLStr: String;
  aRow,aCol,k: LongInt;

  function QuoteText(s: string): string;
  begin
    DoCellProcess(aCol, aRow, cpCopy, s);
    if (pos(#9, s)>0) or //Excel and Calc convert tab symbol # 9 in cell to whitespace.
       (pos(#10, s)>0) or
       (pos(#13, s)>0)
    then
      result := AnsiQuotedStr(s, '"')
    else
      result := s;
  end;

  function PrepareToHTML(s: string): string;
  var
    i1: Integer;
    s1: string;
  begin
    Result := '';
    for i1 := 1 to Length(s) do
    begin
      case s[i1] of
        #13: s1 := '<br>';
        #10: if i1 > 1 then if s[i1 - 1] = #13 then s1 := '' else s1 := '<br>';
        '<': s1 := '&lt;';
        '>': s1 := '&gt;';
        '"': s1 := '&quot;';
        '&': s1 := '&amp;';
        else s1 := s[i1];
      end;
      Result := Result + s1;
    end;
  end;

begin
  SelStr := '';
  SelHTMLStr := '<table>';
  for aRow := R.Top to R.Bottom do begin

    SelHTMLStr := SelHTMLStr + '<tr>';

    for aCol := R.Left to R.Right do begin

      if Columns.Enabled and (aCol >= FirstGridColumn) then begin

        k := ColumnIndexFromGridColumn(aCol);
        if not Columns[k].Visible then
          continue;

        if (aRow = 0) and (FixedRows > 0) then
        begin
          SelStr := SelStr + QuoteText(Columns[k].Title.Caption);
          SelHTMLStr := SelHTMLStr + '<td>' + PrepareToHTML(Columns[k].Title.Caption) + '</td>';
        end
        else
        begin
          SelStr := SelStr + QuoteText(Cells[aCol,aRow]);
          SelHTMLStr := SelHTMLStr + '<td>' + PrepareToHTML(Cells[aCol,aRow]) + '</td>';
        end;

      end else
        begin
          SelStr := SelStr + QuoteText(Cells[aCol,aRow]);
          SelHTMLStr := SelHTMLStr + '<td>' + PrepareToHTML(Cells[aCol,aRow]) + '</td>';
        end;

      if aCol <> R.Right then
        SelStr := SelStr + #9;
    end;

    SelStr := SelStr + sLineBreak;
    SelHTMLStr := SelHTMLStr + '</tr>';
  end;
  SelHTMLStr := SelHTMLStr + '</table>';
  Clipboard.SetAsHtml(SelHTMLStr, SelStr);
end;

procedure TCustomStringGrid.AssignTo(Dest: TPersistent);
var
  i, j: Integer;
begin
  if Dest is TCustomStringGrid then begin
    BeginUpdate;
    inherited AssignTo(Dest);
    for i:=0 to ColCount-1 do
      for j:=0 to RowCount-1 do
        TCustomStringGrid(Dest).Cells[i,j] := Cells[i,j];
    EndUpdate;
  end else
    inherited AssignTo(Dest);
end;

procedure TCustomStringGrid.AutoAdjustColumn(aCol: Integer);
var
  i,W, imgWidth: Integer;
  Ts: TSize;
  TmpCanvas: TCanvas;
  C: TGridColumn;
  aRect: TRect;
  isMultiLine, B: Boolean;
  aText: string;
  aLayout: TButtonLayout;
  imgList: TCustomImageList;
begin
  if not IsColumnIndexValid(aCol) then
    Exit;

  GetTitleImageInfo(aCol, i, aLayout);
  if (i>=0) and (FTitleImageList<>nil) and (aLayout in [blGlyphLeft, blGlyphRight]) then
    imgWidth := FTitleImageList.WidthForPPI[FTitleImageListWidth, Font.PixelsPerInch] + 2*DEFIMAGEPADDING
  else
    imgWidth := 0;
  GetSortTitleImageInfo(aCol, imgList, i, W, B);
  if (imgList<>nil) and (i>=0) then
    Inc(imgWidth, imgList.WidthForPPI[W, Font.PixelsPerInch] + DEFIMAGEPADDING);

  tmpCanvas := GetWorkingCanvas(Canvas);

  C := ColumnFromGridColumn(aCol);
  isMultiLine := (C<>nil) and C.Title.MultiLine;

  try
    W:=0;
    for i := 0 to RowCount-1 do begin

      if C<>nil then begin
        if i<FixedRows then
          tmpCanvas.Font := C.Title.Font
        else
          tmpCanvas.Font := C.Font;
      end else begin
        if i<FixedRows then
          tmpCanvas.Font := TitleFont
        else
          tmpCanvas.Font := Font;
      end;

      if (i=0) and (FixedRows>0) and (C<>nil) then
        aText := C.Title.Caption
      else
        aText := Cells[aCol, i];

      if isMultiLine then begin
        aRect := rect(0, 0, MaxInt, MaxInt);
        DrawText(tmpCanvas.Handle, pchar(aText), Length(aText), aRect, DT_CALCRECT or DT_WORDBREAK);
        Ts.cx := aRect.Right-aRect.Left;
      end else
        Ts := tmpCanvas.TextExtent(aText);

      if Ts.Cx>W then
        W := Ts.Cx;
    end;
  finally
    if tmpCanvas<>Canvas then
      FreeWorkingCanvas(tmpCanvas);
  end;

  W := W + imgWidth;
  if W=0 then
    W := DefaultColWidth
  else
    W := W + 2*varCellpadding + 1;

  ColWidths[aCol] := W;
end;

procedure TCustomStringGrid.CalcCellExtent(acol, aRow: Integer; var aRect: TRect);
var
  S: string;
  Ts: Tsize;
  nc: PcellProps;
  i: integer;
  TextStyle : TTextStyle;
begin
  inherited CalcCellExtent(acol,arow, aRect);
  S:=Cells[aCol,aRow];
  TextStyle := Canvas.TextStyle;
  if not TextStyle.Clipping then begin
  //if not FCellAttr.TextStyle.Clipping then begin
    // Calcular el numero de celdas necesarias para contener todo
    // El Texto
    Ts:=Canvas.TextExtent(S);
    i:=aCol;
    while (Ts.Cx>(aRect.Right-aRect.Left))and(i<ColCount) do begin
      inc(i);
      Nc:=FGrid.Celda[i, aRow];
      if (nc<>nil)and(Nc^.Text<>'')then Break;
      aRect.Right:=aRect.Right + getColWidths(i);
    end;
    //fcellAttr.TextStyle.Clipping:=i<>aCol;
    TextStyle.Clipping:=i<>aCol;
    Canvas.TextStyle:=TextStyle;
  end;
end;

procedure TCustomStringGrid.DefineProperties(Filer: TFiler);
begin
  inherited DefineProperties(Filer);
  DefineCellsProperty(Filer);
end;

procedure TCustomStringGrid.DefineCellsProperty(Filer: TFiler);
  function NeedCells: boolean;
  var
    i,j: integer;
    AntGrid: TCustomStringGrid;
  begin
    result := false;
    if Filer.Ancestor is TCustomStringGrid then begin
      AntGrid := TCustomStringGrid(Filer.Ancestor);
      result := (AntGrid.ColCount<>ColCount) or (AntGrid.RowCount<>RowCount);
      if not result then
        for i:=0 to AntGrid.ColCount-1 do
          for j:=0 to AntGrid.RowCount-1 do
            if Cells[i,j]<>AntGrid.Cells[i,j] then begin
              result := true;
              break;
            end
    end else
      for i:=0 to ColCount-1 do
        for j:=0 to RowCount-1 do
          if Cells[i,j]<>'' then begin
            result := true;
            break;
          end;
  end;
begin
  with Filer do begin
    DefineProperty('Cells',  @ReadCells,  @WriteCells,  NeedCells);
  end;
end;

function TCustomStringGrid.DoCompareCells(Acol, ARow, Bcol, BRow: Integer): Integer;
begin
  if Assigned(OnCompareCells) then
    Result:=inherited DoCompareCells(Acol, ARow, Bcol, BRow)
  else begin
    Result:=UTF8CompareLatinTextFast(Cells[ACol,ARow], Cells[BCol,BRow]);
    if SortOrder=soDescending then
      result:=-result;
  end;
end;

procedure TCustomStringGrid.DoCopyToClipboard;
begin
  CopyCellRectToClipboard(Selection);
end;

procedure TCustomStringGrid.DoCutToClipboard;
begin
  if EditingAllowed(Col) then begin
    doCopyToClipboard;
    Clean(Selection, []);
  end;
end;

procedure TCustomStringGrid.DoPasteFromClipboard;
begin
  // Unpredictable results when a multiple selection is pasted back in.
  // Therefore we inhibit this here.
  if HasMultiSelection then
    exit;

  if EditingAllowed(Col) then
  begin
    if Clipboard.HasFormat(CF_TEXT) and not Clipboard.HasFormat(CF_HTML) then SelectionSetText(Clipboard.AsText);
    if Clipboard.HasFormat(CF_TEXT) and Clipboard.HasFormat(CF_HTML) then SelectionSetHTML(Clipboard.GetAsHtml(True), Clipboard.AsText);
  end;
end;

procedure TCustomStringGrid.DoCellProcess(aCol, aRow: Integer;
  processType: TCellProcessType; var aValue: string);
begin
  if Assigned(fOnCellProcess) then
    OnCellProcess(Self, aCol, aRow, processType, aValue);
end;

procedure TCustomStringGrid.DrawTextInCell(aCol, aRow: Integer; aRect: TRect;
  aState: TGridDrawState);
begin
  DrawCellText(aCol, aRow, aRect, aState, Cells[aCol,aRow]);
end;

procedure TCustomStringGrid.DrawCellAutonumbering(aCol, aRow: Integer;
  aRect: TRect; const aValue: string);
begin
  if Cells[aCol,aRow]='' then
    inherited DrawCellAutoNumbering(aCol,aRow,aRect,aValue);
end;

procedure TCustomStringGrid.DrawColumnText(aCol, aRow: Integer; aRect: TRect;
  aState: TGridDrawState);
begin
  if Columns.Enabled then
    inherited
  else begin
    DrawColumnTitleImage(aRect, aCol);
    DrawCellText(aCol,aRow,aRect,aState,Cells[aCol,aRow])
  end;
end;

procedure TCustomStringGrid.GetCheckBoxState(const aCol, aRow: Integer;
  var aState: TCheckboxState);
var
  s:string;
begin
  if Assigned(OnGetCheckboxState) then
    inherited GetCheckBoxState(aCol, aRow, aState)
  else begin
    s := Cells[ACol, ARow];
    if s=ColumnFromGridColumn(aCol).ValueChecked then
      aState := cbChecked
    else
    if s=ColumnFromGridColumn(aCol).ValueUnChecked then
      aState := cbUnChecked
    else
      aState := cbGrayed;
  end;
end;

function TCustomStringGrid.GetEditText(aCol, aRow: Integer): string;
begin
  Result:=Cells[aCol, aRow];
  if Assigned(OnGetEditText) then OnGetEditText(Self, aCol, aRow, result);
end;

procedure TCustomStringGrid.SaveContent(cfg: TXMLConfig);
var
  i,j,k: Integer;
  c: PCellProps;
begin
  inherited SaveContent(cfg);
  cfg.SetValue('grid/saveoptions/content', soContent in SaveOptions);
  if soContent in SaveOptions then begin
    // Save Cell Contents
    k:=0;
    For i:=0 to ColCount-1 do
      For j:=0 to RowCount-1 do begin
        C:=fGrid.Celda[i,j];
        if (c<>nil) and (C^.Text<>'') then begin
          Inc(k);
          Cfg.SetValue('grid/content/cells/cellcount',k);
          cfg.SetValue('grid/content/cells/cell'+IntToStr(k)+'/column',i);
          cfg.SetValue('grid/content/cells/cell'+IntToStr(k)+'/row',j);
          cfg.SetValue('grid/content/cells/cell'+IntToStr(k)+'/text', UTF8Decode(C^.Text));
        end;
      end;
   end;
end;

procedure TCustomStringGrid.SelectionSetText(TheText: String);
var
  StartCol,StartRow: Integer;
  Stream: TStringStream;

  procedure LoadTSV(Fields: TStringList);
  var
    i, aCol, aRow: Integer;
    NewValue: string;
  begin
    if StartRow<RowCount then begin
      aRow := StartRow;
      for i := 0 to Fields.Count-1 do begin
        aCol := StartCol + i;
        if (aCol<ColCount) and not GetColumnReadonly(aCol) then begin
          NewValue := Fields[i];
          if ValidateOnSetSelection and not ValidateEntry(aCol,aRow,Cells[aCol,aRow],NewValue) then
            break;
          DoCellProcess(aCol, aRow, cpPaste, NewValue);
          Cells[aCol, aRow] := NewValue;
        end;
      end;
      inc(StartRow);
    end;
  end;

begin
  Stream := TStringStream.Create(TheText);
  try
    StartCol := Selection.left;
    StartRow := Selection.Top;
    LCSVUtils.LoadFromCSVStream(Stream, @LoadTSV, #9);
  finally
    Stream.Free;
    if ValidateOnSetSelection then
      EditingDone;
  end;
end;


procedure TCustomStringGrid.SelectionSetHTML(TheHTML, TheText: String);
var
  bStartCol, bStartRow, bCol, bRow: Integer;
  bCellStr: string;
  bSelRect: TRect;

  bCellData, bTagEnd: Boolean;
  bStr, bEndStr: PChar;

  function ReplaceEntities(const cSt: string): string;
  var
    dName: widestring;
    dEntity: WideChar;
    pAmp, pSemi, pStart: Integer;
  begin
    //debugln(['ReplaceEntities: cSt=',cSt]);
    Result := '';
    if (cSt = '') then
      Exit;
    pStart := 1;
    while true do begin
      //debugln(['  pStart=',pStart]);
      pAmp := PosEx('&', cSt, pStart);
      if (pAmp > 0) then
        pSemi := PosEx(';', cSt, pAmp);
      if ((pAmp and pSemi) = 0) then  begin
        //debugln('  pAmp or pSemi = 0');
        Result := Result + Copy(cSt, pStart, MaxInt);
        Exit;
      end;
      //debugln(['  pAmp=',pAmp,', pSemi=',pSemi]);
      dName := Utf8Decode(Copy(cSt, pAmp + 1, pSemi - pAmp - 1));
      //debugln(['  dName=',Utf8Encode(dName)]);
      Result := Result + Copy(cSt, pStart, pAmp - pStart);
      pStart := pSemi + 1;

      dEntity := ' ';
      if ResolveHTMLEntityReference(dName, dEntity) then begin
        //debugln(['dEntity=',Utf8Encode(dEntity)]);
        result := result + Utf8Encode(dEntity);
      end
      else begin
        //illegal html entity
        //debugln('  illegal html entity: replace with "?"');
        Result := Result + '?';
      end;
    end;
  end;

begin
  if theHTML <> '' then
  begin
    bSelRect := Selection;
    bStartCol := Selection.Left;
    bStartRow := Selection.Top;
    bCol := bStartCol;
    bRow := bStartRow;
    bStr := PChar(theHTML);
    bEndStr := bStr + StrLen(bStr) - 4;
    bCellStr := '';
    bCellData := False;

    while bStr < bEndStr do
    begin
      if bStr^ = '<' then // tag start sign '<'
      begin
        bTagEnd := False;
        Inc(bStr);

        if UpCase(bStr^) = 'B' then
        begin
          Inc(bStr);
          if (UpCase(bStr^) = 'R') and bCellData then bCellStr := bCellStr + #10; // tag <br> in table cell
        end;

        if bStr^ = '/' then // close tag sign '/'
        begin
          bTagEnd := True;
          Inc(bStr);
        end;

        if UpCase(bStr^) = 'T' then
        begin
          Inc(bStr);

          if UpCase(bStr^) = 'R' then // table start row tag <tr>
          begin
            bCellData := False;
            if bTagEnd then // table end row tag  </tr>
            begin
              bSelRect.Bottom := bRow;
              Inc(bRow);
              bCol := bStartCol;
            end;
          end;

          if UpCase(bStr^) = 'D' then // table start cell tag <td>
          begin
            bCellData := not bTagEnd;
            if bTagEnd then // table end cell tag </td>
            begin
              if IsColumnIndexValid(bCol) and IsRowIndexValid(bRow) then
              begin
                bCellStr := ReplaceEntities(bCellStr);
                DoCellProcess(bCol, bRow, cpPaste, bCellStr);
                Cells[bCol, bRow] := bCellStr;
              end;
              bSelRect.Right := bCol;
              Inc(bCol);
              bCellStr := '';
            end;
          end;
        end;

        while bStr < bEndStr do
        begin
          Inc(bStr);
          if bStr^ = '>' then // tag end sign '>'
          begin
            Inc(bStr);
            Break;
          end;
        end;
      end else
      begin
        if (bStr^ <> #13) and (bStr^ <> #10) and (bStr^ <> #9) and bCellData then bCellStr := bCellStr + bStr^;
        Inc(bStr);
      end;
    end;

    if (bCol = bStartCol) and (bRow = bStartRow) then
    begin
      DoCellProcess(bCol, bRow, cpPaste, TheText);
      Cells[bCol, bRow] := TheText; //set text in cell if clipboard has CF_HTML fomat, but havent HTML table
    end;
    Selection := bSelRect; // set correct selection
  end;
end;


procedure TCustomStringGrid.SetCheckboxState(const aCol, aRow: Integer;
  const aState: TCheckboxState);
begin
  if Assigned(OnSetCheckboxState) then
    inherited SetCheckBoxState(aCol, aRow, aState)
  else begin
    if aState=cbChecked then
      Cells[ACol, ARow] := ColumnFromGridColumn(aCol).ValueChecked
    else
      Cells[ACol, ARow] := ColumnFromGridColumn(aCol).ValueUnChecked;
  end;
end;

procedure TCustomStringGrid.LoadContent(cfg: TXMLConfig; Version: Integer);
var
  ContentSaved: Boolean;
  i,j,k: Integer;
begin
  inherited LoadContent(Cfg, Version);
  if soContent in FSaveOptions then begin
    ContentSaved:=Cfg.GetValue('grid/saveoptions/content', false);
    if ContentSaved then begin
      k:=cfg.getValue('grid/content/cells/cellcount', 0);
      while k>0 do begin
        i:=cfg.GetValue('grid/content/cells/cell'+IntToStr(k)+'/column', -1);
        j:=cfg.GetValue('grid/content/cells/cell'+IntTostr(k)+'/row',-1);
        if IsRowIndexValid(j) and IsColumnIndexValid(i) then
          Cells[i,j]:=UTF8Encode(cfg.GetValue('grid/content/cells/cell'+IntToStr(k)+'/text',''));
        Dec(k);
      end;
    end;
  end;
end;

procedure TCustomStringGrid.Loaded;
begin
  inherited Loaded;
  FModified := False;
end;

procedure TCustomStringGrid.SetEditText(aCol, aRow: Longint; const aValue: string);
begin
  if not EditorIsReadOnly then begin
    GridFlags := GridFlags + [gfEditorUpdateLock];
    try
      if Cells[aCol, aRow]<>aValue then
        Cells[aCol, aRow]:= aValue;
    finally
      GridFlags := GridFlags - [gfEditorUpdateLock];
    end;
  end;
  inherited SetEditText(aCol, aRow, aValue);
end;

constructor TCustomStringGrid.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  with DefaultTextStyle do begin
    Alignment := taLeftJustify;
    Layout := tlCenter;
    Clipping := True;
    //WordBreak := False
  end;
  ExtendedSelect := True;
  SaveOptions := [soContent];
end;

destructor TCustomStringGrid.Destroy;
begin
  MapFree(FRowsMap);
  MapFree(FColsMap);
  inherited Destroy;
end;

procedure TCustomStringGrid.AutoSizeColumn(aCol: Integer);
begin
  AutoAdjustColumn(aCol);
end;

procedure TCustomStringGrid.AutoSizeColumns;
var
  i: Integer;
begin
  for i:=0 to ColCount-1 do
    AutoAdjustColumn(i)
end;

procedure TCustomStringGrid.Clean;
begin
  Clean([gzNormal, gzFixedCols, gzFixedRows, gzFixedCells]);
end;

procedure TCustomStringGrid.Clean(CleanOptions: TGridZoneSet);
begin
  Clean(0,0,ColCount-1,RowCount-1, CleanOptions);
end;

procedure TCustomStringGrid.Clean(aRect: TRect; CleanOptions: TGridZoneSet);
begin
  with aRect do
    Clean(Left, Top, Right, Bottom, CleanOptions);
end;

procedure TCustomStringGrid.Clean(StartCol, StartRow, EndCol, EndRow: integer;
  CleanOptions: TGridZoneSet);
var
  aCol: LongInt;
  aRow: LongInt;
begin
  if StartCol>EndCol then SwapInt(StartCol,EndCol);
  if StartRow>EndRow then SwapInt(StartRow,EndRow);

  if StartCol<0 then StartCol:=0;
  if EndCol>ColCount-1 then EndCol:=ColCount-1;
  if StartRow<0 then StartRow:=0;
  if EndRow>RowCount-1 then EndRow:=RowCount-1;

  BeginUpdate;
  for aCol:=StartCol to EndCol do
    for aRow:= StartRow to EndRow do
      if (CleanOptions=[]) or (CellToGridZone(aCol,aRow) in CleanOptions) then
        Cells[aCol,aRow] := '';
  EndUpdate;
end;

procedure TCustomStringGrid.CopyToClipboard(AUseSelection: boolean = false);
begin
  if AUseSelection then
    doCopyToClipboard
  else
    CopyCellRectToClipboard(Rect(0,0,ColCount-1,RowCount-1));
end;

procedure TCustomStringGrid.InsertRowWithValues(Index: Integer;
  Values: array of String);
var
  i, OldRC, Diff: Integer;
begin
  OldRC := RowCount;
  Diff := Length(Values) - ColCount;
  if Diff > 0 then
  begin
    if Columns.Enabled then
    begin
      for i := 1 to Diff do with Columns.Add do Title.Caption := '';
    end
    else
      ColCount := Length(Values);
  end;
  InsertColRow(false, Index);
  //if RowCount was 0, then setting ColCount restores RowCount (from FGridPropBackup)
  //which is unwanted here, so reset it (Issue #0026943)
  if (OldRc = 0) then RowCount := 1;
  for i := 0 to Length(Values)-1 do
    Cells[i, Index] := Values[i];
end;

procedure TCustomStringGrid.LoadFromCSVStream(AStream: TStream;
  ADelimiter: Char=','; UseTitles: boolean=true; FromLine: Integer=0;
  SkipEmptyLines: Boolean=true);
var
  MaxCols: Integer = 0;
  MaxRows: Integer = 0;
  LineCounter: Integer = -1;

  function RowOffset: Integer;
  begin
    // return row offset of current CSV record (MaxRows) which is 1 based
    if UseTitles then
      result := Max(0, FixedRows-1) + Max(MaxRows-1, 0)
    else
      result := FixedRows + Max(MaxRows-1, 0);
  end;

  procedure NewRecord(Fields:TStringlist);
  var
    i, aRow, aIndex: Integer;
  begin
    inc(LineCounter);
    if (LineCounter < FromLine) then
      exit;

    if Fields.Count=0 then
      exit;

    if SkipEmptyLines and (Fields.Count=1) and (Fields[0]='') then
      exit;

    // make sure we have enough columns
    if MaxCols<Fields.Count then
      MaxCols := Fields.Count;
    if Columns.Enabled then begin
      while Columns.VisibleCount+FirstGridColumn>MaxCols do Columns.Delete(Columns.Count-1);
      while Columns.VisibleCount+FirstGridColumn<MaxCols do Columns.Add;
    end
    else begin
      if ColCount<MaxCols then
        ColCount := MaxCols;
    end;

    // setup columns captions if enabled by UseTitles
    if (MaxRows = 0) and UseTitles then begin
      for i:= 0 to Fields.Count-1 do begin
        if Columns.Enabled and (i>=FirstGridColumn) then begin
          aIndex := ColumnIndexFromGridColumn(i);
          if aIndex>=0 then
            Columns[aIndex].Title.Caption:=Fields[i];
        end else
          Cells[i, 0] := Fields[i]
      end;
      inc(MaxRows);
      exit;
    end;

    // Make sure we have enough rows
    Inc(MaxRows);
    aRow := RowOffset;
    if aRow>RowCount-1 then
      RowCount := aRow + 20;

    // Copy line data to cells
    for i:=0 to Fields.Count-1 do
      Cells[i, aRow] := Fields[i];
  end;

begin
  BeginUpdate;
  try
    LCSVUtils.LoadFromCSVStream(AStream, @NewRecord, ADelimiter);

    // last row offset + 1 (offset is 0 based)
    RowCount := RowOffset + 1;

    if not Columns.Enabled then
      ColCount := MaxCols
    else
      while Columns.Count > MaxCols do
        Columns.Delete(Columns.Count-1);

  finally
    EndUpdate;
  end;
end;

procedure TCustomStringGrid.LoadFromCSVFile(AFilename: string;
  ADelimiter: Char=','; UseTitles: boolean=true; FromLine: Integer=0;
  SkipEmptyLines: Boolean=true);
var
  TheStream: TFileStream;
begin
  TheStream:=TFileStream.Create(AFileName,fmOpenRead or fmShareDenyWrite);
  try
    LoadFromCSVStream(TheStream, ADelimiter, UseTitles, FromLine, SkipEmptyLines);
  finally
    TheStream.Free;
  end;
end;

procedure TCustomStringGrid.SaveToCSVStream(AStream: TStream; ADelimiter: Char;
  WriteTitles: boolean=true; VisibleColumnsOnly: boolean=false);
var
  i,j,StartRow: Integer;
  HeaderL, Lines: TStringList;
  C: TGridColumn;
begin
  if (RowCount=0) or (ColCount=0) then
    exit;
  Lines := TStringList.Create;
  try
    if WriteTitles then begin
      if Columns.Enabled then begin
        if FixedRows>0 then begin
          HeaderL := TStringList.Create;
          try
            // Collect header column names to a temporary StringList
            for i := 0 to ColCount-1 do begin
              c := ColumnFromGridColumn(i);
              if (c <> nil) then begin
                if c.Visible or not VisibleColumnsOnly then
                  HeaderL.Add(c.Title.Caption);
              end
              else
              if not VisibleColumnsOnly then
                HeaderL.Add(Cells[i, 0]);
            end;
            HeaderL.Delimiter:=ADelimiter;
            Headerl.StrictDelimiter := False; //force quoting of strings that contain whitespace or Delimiter
            Lines.Add(HeaderL.DelimitedText); // Add as a first row in Lines
          finally
            HeaderL.Free;
          end;
        end;
        StartRow := FixedRows;
      end else
      if FixedRows>0 then
        StartRow := FixedRows-1
      else
        StartRow := 0;
    end else
      StartRow := FixedRows;
    for i:=StartRow to RowCount-1 do begin
      if Columns.Enabled and VisibleColumnsOnly then begin
        HeaderL := TStringList.Create;
        try
        for j := 0 to ColCount-1 do begin
          c := ColumnFromGridColumn(j);
          if c=nil then Continue;
          if c.Visible then
            HeaderL.Add(Cells[j,i]);
        end;
        HeaderL.Delimiter:=ADelimiter;
        HeaderL.StrictDelimiter := False; //force quoting of strings that contain whitespace or Delimiter
        Lines.Add(HeaderL.DelimitedText); // Add the row in Lines
        finally
          HeaderL.Free;
        end;
      end
      else
      begin
      Rows[i].StrictDelimiter := False; //force quoting of strings that contain whitespace or Delimiter
      Rows[i].Delimiter:=ADelimiter;
      Lines.Add(Rows[i].DelimitedText);
    end;
    end;
    Lines.SaveToStream(AStream);
  finally
    Lines.Free;
  end;
end;

procedure TCustomStringGrid.SaveToCSVFile(AFileName: string; ADelimiter: Char;
  WriteTitles: boolean=true; VisibleColumnsOnly: boolean=false);
var
  TheStream: TFileStream;
begin
  TheStream:=TFileStream.Create(AFileName,fmCreate);
  try
    SaveToCSVStream(TheStream, ADelimiter, WriteTitles, VisibleColumnsOnly);
  finally
    TheStream.Free;
  end;
end;

procedure Register;
begin
  RegisterComponents('Additional',[TStringGrid,TDrawGrid]);
end;


{ TGridColumnTitle }

procedure TGridColumnTitle.WriteCaption(Writer: TWriter);
var
  aStr: string;
  PropInfo: PPropInfo;
begin
  if not FIsDefaultCaption then  aStr := FCaption
  else                           aStr := Caption;
  if Assigned(Writer.OnWriteStringProperty) then begin
    PropInfo := GetPropInfo(Self, 'Caption');
    Writer.OnWriteStringProperty(Writer, Self, PropInfo, aStr);
  end;
  Writer.WriteString(aStr);
end;

procedure TGridColumnTitle.FontChanged(Sender: TObject);
begin
  FisDefaultTitleFont := False;
  FColumn.ColumnChanged;
end;

function TGridColumnTitle.GetAlignment: TAlignment;
begin
  if FAlignment = nil then
    result := GetDefaultAlignment
  else
    result := FAlignment^;
end;

function TGridColumnTitle.GetCaption: TCaption;
begin
  if (FCaption = nil) and FIsDefaultCaption then
    result := GetDefaultCaption
  else
    result := FCaption;
end;

function TGridColumnTitle.GetColor: TColor;
begin
  if FColor = nil then
    result := GetDefaultColor
  else
    result := FColor^;
end;

procedure TGridColumnTitle.FillTitleDefaultFont;
var
  AGrid: TCustomGrid;
begin
  AGrid :=  FColumn.Grid;
  if AGrid<>nil then
    FFont.Assign( AGrid.TitleFont )
  else
    FFont.Assign( FColumn.Font );
  FIsDefaultTitleFont := True;
end;

procedure TGridColumnTitle.FixDesignFontsPPI(const ADesignTimePPI: Integer);
var
  LIsDefaultTitleFont: Boolean;
begin
  LIsDefaultTitleFont := FIsDefaultTitleFont;
  FColumn.Grid.DoFixDesignFontPPI(Font, ADesignTimePPI);
  FIsDefaultTitleFont := LIsDefaultTitleFont;
end;

function TGridColumnTitle.GetFont: TFont;
begin
  Result := FFont;
end;

function TGridColumnTitle.GetLayout: TTextLayout;
begin
  if FLayout = nil then
    result := GetDefaultLayout
  else
    result := FLayout^;
end;

function TGridColumnTitle.IsAlignmentStored: boolean;
begin
  result := FAlignment <> nil;
end;

function TGridColumnTitle.IsCaptionStored: boolean;
begin
  result := false;
end;

function TGridColumnTitle.IsColorStored: boolean;
begin
  result := FColor <> nil;
end;

function TGridColumnTitle.IsFontStored: boolean;
begin
  result := not IsDefaultFont;
end;

function TGridColumnTitle.IsLayoutStored: boolean;
begin
  result := FLayout <> nil;
end;

procedure TGridColumnTitle.ScaleFontsPPI(const AToPPI: Integer; const AProportion: Double);
var
  LIsDefaultTitleFont: Boolean;
begin
  LIsDefaultTitleFont := FIsDefaultTitleFont;
  FColumn.Grid.DoScaleFontPPI(Font, AToPPI, AProportion);
  FIsDefaultTitleFont := LIsDefaultTitleFont;
end;

procedure TGridColumnTitle.SetAlignment(const AValue: TAlignment);
begin
  if Falignment = nil then begin
    if AValue = GetDefaultAlignment then
      exit;
    New(Falignment)
  end else if FAlignment^ = AValue then
    exit;
  FAlignment^ := AValue;
  FColumn.ColumnChanged;
end;

procedure TGridColumnTitle.SetCaption(const AValue: TCaption);
begin
  if (FCaption=nil)or(AValue<>StrPas(FCaption)) then begin
    if FCaption<>nil then
      StrDispose(FCaption);
    FCaption := StrNew(PChar(AValue));
    FIsDefaultCaption := false;
    FColumn.ColumnChanged;
  end;
end;

procedure TGridColumnTitle.DefineProperties(Filer: TFiler);
begin
  inherited DefineProperties(Filer);
  Filer.DefineProperty('Caption',  nil,  @WriteCaption, true);
end;

procedure TGridColumnTitle.SetColor(const AValue: TColor);
begin
  if FColor=nil then begin
    if AValue = GetDefaultColor then
      exit;
    New(FColor)
  end else if FColor^=AValue then
    exit;
  FColor^ := AValue;
  FColumn.ColumnChanged;
end;

procedure TGridColumnTitle.SetFont(const AValue: TFont);
begin
  if not FFont.IsEqual(AValue) then
    FFont.Assign(AValue);
end;

procedure TGridColumnTitle.SetImageIndex(const AValue: TImageIndex);
begin
  if FImageIndex = AValue then exit;
  FImageIndex := AValue;
  FColumn.ColumnChanged;
end;

procedure TGridColumnTitle.SetImageLayout(const AValue: TButtonLayout);
begin
  if FImageLayout = AValue then exit;
  FImageLayout := AValue;
  FColumn.ColumnChanged;
end;

procedure TGridColumnTitle.SetLayout(const AValue: TTextLayout);
begin
  if FLayout = nil then begin
    if AValue = GetDefaultLayout then
      exit;
    New(FLayout)
  end else if FLayout^ = AValue then
    exit;
  FLayout^ := AValue;
  FColumn.ColumnChanged;
end;

procedure TGridColumnTitle.SetMultiLine(const AValue: Boolean);
begin
  if FMultiLine = AValue then exit;
  FMultiLine := AValue;
  FColumn.ColumnChanged;
end;

procedure TGridColumnTitle.SetPrefixOption(const AValue: TPrefixOption);
begin
  if FPrefixOption=AValue then exit;
  FPrefixOption:=AValue;
  FColumn.ColumnChanged;
end;

procedure TGridColumnTitle.Assign(Source: TPersistent);
begin
  if Source is TGridColumnTitle then begin
    Alignment := TGridColumnTitle(Source).Alignment;
    Layout := TGridColumnTitle(Source).Layout;
    Caption := TGridColumnTitle(Source).Caption;
    Color := TGridColumnTitle(Source).Color;
    Font := TGridColumnTitle(Source).Font;
    ImageIndex := TGridColumnTitle(Source).ImageIndex;
  end else
    inherited Assign(Source);
end;

function TGridColumnTitle.GetDefaultCaption: string;
begin
  Result := 'Title'
end;

function TGridColumnTitle.GetDefaultAlignment: TAlignment;
begin
  result := taLeftJustify
end;

function TGridColumnTitle.GetDefaultColor: TColor;
begin
  if FColumn.Grid <> nil then
    result := FColumn.Grid.FixedColor
  else
    result := clBtnFace
end;

function TGridColumnTitle.GetDefaultLayout: TTextLayout;
begin
  result := tlCenter
end;

function TGridColumnTitle.GetOwner: TPersistent;
begin
  Result := FColumn;
end;

constructor TGridColumnTitle.Create(TheColumn: TGridColumn);
begin
  inherited Create;
  FColumn := TheColumn;
  FIsDefaultTitleFont := True;
  FFont := TFont.Create;
  FillTitleDefaultFont;
  FFont.OnChange := @FontChanged;
  FImageIndex := -1;
  FImageLayout := blGlyphRight;
  FIsDefaultCaption := true;
end;

destructor TGridColumnTitle.Destroy;
begin
  if FFont<>nil then FFont.Free;
  if FAlignment<>nil then Dispose(FAlignment);
  if FColor<>nil then Dispose(FColor);
  if FCaption<>nil then StrDispose(FCaption); //DisposeStr(FCaption);
  if FLayout<>nil then Dispose(FLayout);
  inherited Destroy;
end;

function TGridColumnTitle.IsDefault: boolean;
begin
  Result :=  (FAlignment = nil) and (FColor = nil) and (FCaption = nil) and
    IsDefaultFont and (FLayout = nil) and
    (FImageIndex = 0) and (FImageLayout = blGlyphRight);
end;

{ TGridColumn }

procedure TGridColumn.FontChanged(Sender: TObject);
begin
  FisDefaultFont := False;
  ColumnChanged;
end;

function TGridColumn.GetAlignment: TAlignment;
begin
  if FAlignment=nil then
    Result := GetDefaultAlignment
  else
    Result := FAlignment^;
end;

function TGridColumn.GetColor: TColor;
begin
  if FColor=nil then
    result := GetDefaultColor
  else
    result := FColor^
end;

function TGridColumn.GetExpanded: Boolean;
begin
  result := True;
end;

function TGridColumn.GetFont: TFont;
begin
  result := FFont;
end;

function TGridColumn.GetGrid: TCustomGrid;
begin
  if Collection is TGridColumns then
    result := (Collection as TGridColumns).Grid
  else
    result := nil;
end;

function TGridColumn.GetLayout: TTextLayout;
begin
  if FLayout=nil then
    result := GetDefaultLayout
  else
    result := FLayout^;
end;

function TGridColumn.GetMaxSize: Integer;
begin
  if FMaxSize=nil then
    result := GetDefaultMaxSize
  else
    result := FMaxSize^;
end;

function TGridColumn.GetMinSize: Integer;
begin
  if FMinSize=nil then
    result := GetDefaultMinSize
  else
    result := FMinSize^;
end;

function TGridColumn.GetSizePriority: Integer;
begin
  if not Visible then
    result := 0
  else
  if FSizePriority=nil then
    result := GetDefaultSizePriority
  else
    result := FSizePriority^;
end;

function TGridColumn.GetPickList: TStrings;
begin
  Result := FPickList;
end;

function TGridColumn.GetReadOnly: Boolean;
begin
  if FReadOnly=nil then
    result := GetDefaultReadOnly
  else
    result := FReadOnly^;
end;

function TGridColumn.GetStoredWidth: Integer;
begin
  if FWidth=nil then
    result := -1
  else
    result := FWidth^;
end;

function TGridColumn.GetValueChecked: string;
begin
  if FValueChecked = nil then
    Result := GetDefaultValueChecked
  else
    Result := FValueChecked;
end;

function TGridColumn.GetValueUnchecked: string;
begin
  if FValueUnChecked = nil then
    Result := GetDefaultValueUnChecked
  else
    Result := FValueUnChecked;
end;

function TGridColumn.GetVisible: Boolean;
begin
  if FVisible=nil then begin
    result := GetDefaultVisible;
  end else
    result := FVisible^;
end;

function TGridColumn.GetWidth: Integer;
var
  tmpGrid: TCustomGrid;
begin
  {$ifdef newcols}
  if not Visible then
    exit(0);
  {$endif}
  if FWidth=nil then
    result := GetDefaultWidth
  else
    result := FWidth^;
  if (result<0) then
  begin
    tmpGrid := Grid;
    if tmpGrid<>nil then
      result := tmpGrid.DefaultColWidth;
  end;
end;

function TGridColumn.IsAlignmentStored: boolean;
begin
  result := FAlignment <> nil;
end;

function TGridColumn.IsColorStored: boolean;
begin
  result := FColor <> nil;
end;

function TGridColumn.IsFontStored: boolean;
begin
  result := not FisDefaultFont;
end;

function TGridColumn.IsLayoutStored: boolean;
begin
  result := FLayout <> nil;
end;

function TGridColumn.IsMinSizeStored: boolean;
begin
  result := FMinSize <> nil;
end;

function TGridColumn.IsMaxSizeStored: boolean;
begin
  result := FMaxSize <> nil;
end;

function TGridColumn.IsReadOnlyStored: boolean;
begin
  result := FReadOnly <> nil;
end;

function TGridColumn.IsSizePriorityStored: boolean;
begin
  result := FSizePriority <> nil;
end;

function TGridColumn.IsValueCheckedStored: boolean;
begin
  result := FValueChecked <> nil;
end;

function TGridColumn.IsValueUncheckedStored: boolean;
begin
  Result := FValueUnchecked <> nil;
end;

function TGridColumn.IsVisibleStored: boolean;
begin
  result := (FVisible<>nil) and not FVisible^;
end;

function TGridColumn.IsWidthStored: boolean;
begin
  result := FWidth <> nil;
end;

procedure TGridColumn.ScaleFontsPPI(const AToPPI: Integer; const AProportion: Double);
var
  LisDefaultFont: Boolean;
begin
  LisDefaultFont := FisDefaultFont;
  Grid.DoScaleFontPPI(Font, AToPPI, AProportion);
  FisDefaultFont := LisDefaultFont;
  Title.ScaleFontsPPI(AToPPI, AProportion);
end;

procedure TGridColumn.SetAlignment(const AValue: TAlignment);
begin
  if FAlignment = nil then begin
    if AValue=GetDefaultAlignment then
      exit;
    New(FAlignment);
  end else if FAlignment^ = AValue then
    exit;
  FAlignment^ := AValue;
  ColumnChanged;
end;

procedure TGridColumn.SetButtonStyle(const AValue: TColumnButtonStyle);
begin
  if FButtonStyle=AValue then exit;
  FButtonStyle:=AValue;
  ColumnChanged;
end;

procedure TGridColumn.SetColor(const AValue: TColor);
begin
  if FColor = nil then begin
    if AValue=GetDefaultColor then
      exit;
    New(FColor)
  end else if FColor^ = AValue then
   exit;
  FColor^ := AValue;
  ColumnChanged;
end;

procedure TGridColumn.SetExpanded(const AValue: Boolean);
begin
  //todo
end;

procedure TGridColumn.SetFont(const AValue: TFont);
begin
  if not FFont.IsEqual(AValue) then
    FFont.Assign(AValue);
end;

procedure TGridColumn.SetLayout(const AValue: TTextLayout);
begin
  if FLayout = nil then begin
    if AValue=GetDefaultLayout then
      exit;
    New(FLayout)
  end else if FLayout^ = AValue then
    exit;
  FLayout^ := AValue;
  ColumnChanged;
end;

procedure TGridColumn.SetMaxSize(const AValue: Integer);
begin
  if FMaxSize = nil then begin
    if AValue = GetDefaultMaxSize then
      exit;
    New(FMaxSize)
  end else if FMaxSize^ = AVAlue then
    exit;
  FMaxSize^ := AValue;
  ColumnChanged;
end;

procedure TGridColumn.SetMinSize(const Avalue: Integer);
begin
  if FMinSize = nil then begin
    if AValue = GetDefaultMinSize then
      exit;
    New(FMinSize)
  end else if FMinSize^ = AVAlue then
    exit;
  FMinSize^ := AValue;
  ColumnChanged;
end;

procedure TGridColumn.SetPickList(const AValue: TStrings);
begin
  if AValue=nil then
    FPickList.Clear
  else
    FPickList.Assign(AValue);
end;

procedure TGridColumn.SetReadOnly(const AValue: Boolean);
begin
  if FReadOnly = nil then begin
    if AValue = GetDefaultReadOnly then
      exit;
    New(FReadOnly)
  end else if FReadOnly^ = AValue then
    exit;
  FReadOnly^ := Avalue;
  ColumnChanged;
end;

procedure TGridColumn.SetSizePriority(const AValue: Integer);
begin
  if FSizePriority = nil then begin
    if AValue = GetDefaultSizePriority then
      exit;
    New(FSizePriority)
  end else if FSizePriority^ = AVAlue then
    exit;
  FSizePriority^ := AValue;
  ColumnChanged;
end;

procedure TGridColumn.SetTitle(const AValue: TGridColumnTitle);
begin
  FTitle.Assign(AValue);
end;

procedure TGridColumn.SetValueChecked(const AValue: string);
begin
  if (FValueChecked=nil)or(CompareText(AValue, FValueChecked)<>0) then begin
    if FValueChecked<>nil then
      StrDispose(FValueChecked)
    else
    if CompareText(AValue, GetDefaultValueChecked)=0 then
      exit;
    FValueChecked := StrNew(PChar(AValue));
    Changed(False);
  end;
end;

procedure TGridColumn.SetValueUnchecked(const AValue: string);
begin
  if (FValueUnchecked=nil)or(CompareText(AValue, FValueUnchecked)<>0) then begin
    if FValueUnchecked<>nil then
      StrDispose(FValueUnchecked)
    else
      if CompareText(AValue, GetDefaultValueUnchecked)=0 then
        exit;
    FValueUnchecked := StrNew(PChar(AValue));
    Changed(False);
  end;
end;

procedure TGridColumn.SetVisible(const AValue: Boolean);
begin
  if FVisible = nil then begin
    if AValue=GetDefaultVisible then
      exit;
    New(FVisible)
  end else if FVisible^ = AValue then
    exit;
  FVisible^ := AValue;
  AllColumnsChange;
end;

procedure TGridColumn.SetWidth(const AValue: Integer);
begin
  if (AValue=0) and not Visible then
    exit;
  if AValue>=0 then begin
    if FWidth = nil then begin
      New(FWidth)
    end else if FWidth^ = AVAlue then
      exit;
    FWidth^ := AValue;
  end else begin
    // negative value is handed over - dispose FWidth to use DefaultWidth
    if FWidth <> nil then begin
      Dispose(FWidth);
      FWidth := nil;
    end else
      exit;
  end;
  FWidthChanged:=true;
  ColumnChanged;
end;

function TGridColumn.GetDefaultReadOnly: boolean;
begin
  result := false;
end;

function TGridColumn.GetDefaultLayout: TTextLayout;
begin
  result := tlCenter
end;

function TGridColumn.GetDefaultVisible: boolean;
begin
  Result := True;
end;

function TGridColumn.GetDefaultValueChecked: string;
begin
  result := '1';
end;

function TGridColumn.GetDefaultValueUnchecked: string;
begin
  result := '0';
end;

function TGridColumn.GetDefaultWidth: Integer;
var
  tmpGrid: TCustomGrid;
begin
  tmpGrid := Grid;
  if tmpGrid<>nil then
    result := tmpGrid.DefaultColWidth
  else
    result := -1;
end;

function TGridColumn.GetDefaultMaxSize: Integer;
begin
  // get a better default
  Result := 200;
end;

function TGridColumn.GetDefaultMinSize: Integer;
begin
  // get a better default
  result := 10;
end;

function TGridColumn.GetDefaultColor: TColor;
var
  TmpGrid: TCustomGrid;
begin
  TmpGrid := Grid;
  if TmpGrid<>nil then
    result := TmpGrid.Color
  else
    result := clWindow
end;

function TGridColumn.GetDefaultSizePriority: Integer;
begin
  Result := 1;
end;

procedure TGridColumn.Assign(Source: TPersistent);
begin
  if Source is TGridColumn then begin
    //DebugLn('Assigning TGridColumn[',dbgs(Index),'] a TgridColumn')
    Collection.BeginUpdate;
    try
      Alignment := TGridColumn(Source).Alignment;
      ButtonStyle := TGridColumn(Source).ButtonStyle;
      Color := TGridColumn(Source).Color;
      DropDownRows := TGridColumn(Source).DropDownRows;
      //Expanded := TGridColumn(Source).Expanded; //todo
      Font := TGridColumn(Source).Font;
      Layout := TGridColumn(Source).Layout;
      MinSize := TGridColumn(Source).MinSize;
      MaxSize := TGridColumn(Source).MaxSize;
      PickList := TGridColumn(Source).PickList;
      ReadOnly := TGridColumn(Source).ReadOnly;
      SizePriority := TGridColumn(Source).SizePriority;
      Title := TGridColumn(Source).Title;
      Width := TGridCOlumn(Source).Width;
      Visible := TGridColumn(Source).Visible;
    finally
      Collection.EndUpdate;
    end;
  end else
    inherited Assign(Source);
end;

function TGridColumn.GetDisplayName: string;
begin
  if Title.Caption<>'' then
    Result := Title.Caption
  else
    Result := 'GridColumn';
end;

function TGridColumn.GetDefaultAlignment: TAlignment;
begin
  if ButtonStyle in [cbsCheckboxColumn,cbsButtonColumn] then
    result := taCenter
  else
    result := taLeftJustify;
end;

procedure TGridColumn.ColumnChanged;
begin
  Changed(False);
  FWidthChanged := False;
end;

procedure TGridColumn.AllColumnsChange;
begin
  Changed(True);
  FWidthChanged := False;
end;

function TGridColumn.CreateTitle: TGridColumnTitle;
begin
  result := TGridColumnTitle.Create(Self);
end;

procedure TGridColumn.SetIndex(Value: Integer);
var
  AGrid: TCustomGrid;
  CurCol,DstCol: Integer;
begin
  AGrid := Grid;
  if (Value<>Index) and (AGrid<>nil) then begin
    // move grid content
    CurCol := Grid.GridColumnFromColumnIndex(Index);
    DstCol := Grid.GridColumnFromColumnIndex(Value);
    if (CurCol>=0) and (DstCol>=0) then begin
      AGrid.GridFlags:=AGrid.GridFlags + [gfColumnsLocked];
      AGrid.DoOPMoveColRow(true, CurCol, DstCol);
      AGrid.GridFlags:=AGrid.GridFlags - [gfColumnsLocked];
    end;
  end;
  // move column item index
  inherited SetIndex(Value);
end;

constructor TGridColumn.Create(ACollection: TCollection);
begin
  inherited Create(ACollection);
  FTitle := CreateTitle;

  FIsDefaultFont := True;
  FFont := TFont.Create;
  FillDefaultFont;
  FFont.OnChange := @FontChanged;

  FPickList:= TStringList.Create;
  FButtonStyle := cbsAuto;
  FDropDownRows := 7;
end;

destructor TGridColumn.Destroy;
begin
  if FAlignment<>nil then Dispose(FAlignment);
  if FColor<>nil then Dispose(FColor);
  if FVisible<>nil then Dispose(FVisible);
  if FReadOnly<>nil then Dispose(FReadOnly);
  if FWidth<>nil then Dispose(FWidth);
  if FLayout<>nil then Dispose(FLayout);
  if FMaxSize<>nil then Dispose(FMaxSize);
  if FMinSize<>nil then Dispose(FMinSize);
  if FSizePriority<>nil then Dispose(FSizePriority);
  if FValueChecked<>nil then StrDispose(FValueChecked);
  if FValueUnchecked<>nil then StrDispose(FValueUnchecked);

  FreeThenNil(FPickList);
  FreeThenNil(FFont);
  FreeThenNil(FTitle);
  inherited Destroy;
end;

procedure TGridColumn.FillDefaultFont;
var
  AGrid: TCustomGrid;
begin
  AGrid := Grid;
  if (AGrid<>nil) then begin
    FFont.Assign(AGrid.Font);
    FIsDefaultFont := True;
  end;
end;

procedure TGridColumn.FixDesignFontsPPI(const ADesignTimePPI: Integer);
var
  LisDefaultFont: Boolean;
begin
  LisDefaultFont := FisDefaultFont;
  Grid.DoFixDesignFontPPI(Font, ADesignTimePPI);
  FisDefaultFont := LisDefaultFont;
  Title.FixDesignFontsPPI(ADesignTimePPI);
end;

function TGridColumn.IsDefault: boolean;
begin
  result := FTitle.IsDefault and (FAlignment=nil) and (FColor=nil)
    and (FVisible=nil) and (FReadOnly=nil) and (FWidth=nil) and FIsDefaultFont
    and (FLayout=nil) and (FMaxSize=nil) and (FMinSize=nil)
    and (FSizePriority=nil);
end;

{ TGridColumns }

function TGridColumns.GetColumn(Index: Integer): TGridColumn;
begin
  result := TGridColumn( inherited Items[Index] );
end;

function TGridColumns.GetEnabled: Boolean;
begin
  result := VisibleCount > 0;
end;

procedure TGridColumns.SetColumn(Index: Integer; Value: TGridColumn);
begin
  Items[Index].Assign( Value );
end;

function TGridColumns.GetVisibleCount: Integer;
{$ifNdef newcols}
var
  i: Integer;
{$endif}
begin
  {$ifdef newcols}
  result := Count;
  {$else}
  result := 0;
  for i:=0 to Count-1 do
    if Items[i].Visible then
      inc(result);
  {$endif}
end;

function TGridColumns.GetOwner: TPersistent;
begin
  Result := FGrid;
end;

procedure TGridColumns.Update(Item: TCollectionItem);
begin
  //if (FGrid<>nil) and not (csLoading in FGrid.ComponentState) then
    FGrid.ColumnsChanged(TGridColumn(Item));
end;

procedure TGridColumns.TitleFontChanged;
var
  c: TGridColumn;
  i: Integer;
begin
  for i:=0 to Count-1 do begin
    c := Items[i];
    if (c<>nil)and(c.Title.IsDefaultFont) then begin
      c.Title.FillTitleDefaultFont;
    end;
  end;
end;

procedure TGridColumns.FontChanged;
var
  c: TGridColumn;
  i: Integer;
begin
  for i:=0 to Count-1 do begin
    c := Items[i];
    if (c<>nil)and(c.IsDefaultFont) then begin
      c.FillDefaultFont;
    end;
  end;
end;

procedure TGridColumns.RemoveColumn(Index: Integer);
begin
  if HasIndex(Index) then
    Delete(Index)
  else
    raise Exception.Create('Index out of range')
end;

procedure TGridColumns.MoveColumn(FromIndex, ToIndex: Integer);
begin
  if HasIndex(FromIndex) then
    if HasIndex(ToIndex) then
      Items[FromIndex].Index := ToIndex
    else
      raise Exception.Create('ToIndex out of range')
  else
    raise Exception.Create('FromIndex out of range')
end;

procedure TGridColumns.ExchangeColumn(Index, WithIndex: Integer);
begin
  if HasIndex(Index) then
    if HasIndex(WithIndex) then begin
      BeginUpdate;
      Items[WithIndex].Index := Index;
      Items[Index+1].Index := WithIndex;
      EndUpdate;
    end else
      raise Exception.Create('WithIndex out of range')
  else
    raise Exception.Create('Index out of range')
end;

procedure TGridColumns.InsertColumn(Index: Integer);
begin
  FGrid.BeginUpdate;
  Add;
  MoveColumn(Count-1, Index);
  FGrid.EndUpdate;
end;

constructor TGridColumns.Create(AGrid: TCustomGrid;
  aItemClass: TCollectionItemClass);
begin
  inherited Create( aItemClass );
  FGrid := AGrid;
end;

function TGridColumns.Add: TGridColumn;
begin
  result := TGridColumn( inherited add );
end;

procedure TGridColumns.Clear;
begin
  BeginUpdate;
  inherited Clear;
  EndUpdate
end;

function TGridColumns.ColumnByTitle(const aTitle: string): TGridColumn;
var
  i: Integer;
begin
  result := nil;
  for i:=0 to Count-1 do
    if SameText(Items[i].Title.Caption, aTitle) then begin
      result := Items[i];
      break;
    end;
end;

function TGridColumns.RealIndex(Index: Integer): Integer;
{$ifNdef NewCols}
var
  i: Integer;
{$endif}
begin
  {$ifdef NewCols}
  if Index>Count-1 then
    result := -1
  else
    result := Index;
  {$else}
  result := -1;
  if Index>=0 then
    for i:=0 to Count-1 do begin
      if Items[i].Visible then begin
        Dec(index);
        if Index<0 then begin
          result := i;
          exit;
        end;
      end;
    end;
  {$endif}
end;

function TGridColumns.IndexOf(Column: TGridColumn): Integer;
var
  i: Integer;
begin
  result := -1;
  for i:=0 to Count-1 do
    if Items[i]=Column then begin
      result := i;
      break;
    end;
end;

function TGridColumns.IsDefault: boolean;
var
  i: Integer;
begin
  result := True;
  for i:=0 to Count-1 do
    result := Result and Items[i].IsDefault;
end;

function TGridColumns.HasIndex(Index: Integer): boolean;
begin
  result := (index>-1)and(index<count);
end;

function TGridColumns.VisibleIndex(Index: Integer): Integer;
var
  i: Integer;
begin
  result := -1;
  if HasIndex(Index) and Items[Index].Visible then
    for i:=0 to Index do
      if Items[i].Visible then
        inc(result);
end;

{ TButtonCellEditor }

procedure TButtonCellEditor.msg_SetGrid(var Msg: TGridMessage);
begin
  FGrid:=Msg.Grid;
  Msg.Options:=EO_HOOKKEYDOWN or EO_HOOKKEYPRESS or EO_HOOKKEYUP;
end;

procedure TButtonCellEditor.msg_SetBounds(var Msg: TGridMessage);
var
  r: TRect;
begin
  r := Msg.CellRect;
  FGrid.AdjustInnerCellRect(r);
  if r.Right-r.Left>DEFBUTTONWIDTH then
    r.Left:=r.Right-DEFBUTTONWIDTH;
  SetBounds(r.Left, r.Top, r.Right-r.Left, r.Bottom-r.Top);
end;

procedure TButtonCellEditor.msg_SetPos(var Msg: TGridMessage);
begin
  FCol := Msg.Col;
  FRow := Msg.Row;
end;

procedure TButtonCellEditor.msg_Ready(var Msg: TGridMessage);
begin
  Width := DEFBUTTONWIDTH;
end;

procedure TButtonCellEditor.msg_GetGrid(var Msg: TGridMessage);
begin
  Msg.Grid := FGrid;
  Msg.Options:= EO_IMPLEMENTED;
end;

{ TPickListCellEditor }
procedure TPickListCellEditor.WndProc(var TheMessage: TLMessage);
begin
  {$IfDef GridTraceMsg}
  TransMsg('PicklistEditor: ', TheMessage);
  {$Endif}
  if TheMessage.msg=LM_KILLFOCUS then begin
    if HWND(TheMessage.WParam) = HWND(Handle) then begin
      // lost the focus but it returns to ourselves
      // eat the message.
      TheMessage.Result := 0;
      exit;
    end;
  end;
  inherited WndProc(TheMessage);
end;

procedure TPickListCellEditor.KeyDown(var Key: Word; Shift: TShiftState);
  function AllSelected: boolean;
  begin
    result := (SelLength>0) and (SelLength=Length(Text));
  end;
  function AtStart: Boolean;
  begin
    Result:= (SelStart=0);
  end;
  function AtEnd: Boolean;
  begin
    result := ((SelStart+1)>Length(Text)) or AllSelected;
  end;
  procedure doEditorKeyDown;
  begin
    if FGrid<>nil then
      FGrid.EditorkeyDown(Self, key, shift);
  end;
  procedure doGridKeyDown;
  begin
    if FGrid<>nil then
      FGrid.KeyDown(Key, shift);
  end;
  function GetFastEntry: boolean;
  begin
    if FGrid<>nil then
      Result := FGrid.FastEditing
    else
      Result := False;
  end;
  procedure CheckEditingKey;
  begin
    // if editor is not readonly, start editing
    // else not interested
    if (FGrid=nil) or FGrid.EditorIsReadOnly then
      Key := 0;
  end;
var
  IntSel: boolean;
begin
  {$IfDef dbgGrid}
  DebugLn('TPickListCellEditor.KeyDown INIT: Key=',Dbgs(Key));
  {$Endif}
  inherited KeyDown(Key,Shift);
  case Key of

    VK_F2:
      if AllSelected then begin
        SelLength := 0;
        SelStart := Length(Text);
      end;

    VK_RETURN:
      if DroppedDown then begin
        CheckEditingKey;
        DroppedDown := False;
        if Key<>0 then begin
          doEditorKeyDown;
          Key:=0;
        end;
      end else
        doEditorKeyDown;

    VK_DELETE:
      CheckEditingKey;

    VK_UP, VK_DOWN:
      if not DroppedDown then
        doGridKeyDown;

    VK_LEFT, VK_RIGHT:
      if GetFastEntry then begin
        IntSel:=
          ((Key=VK_LEFT) and not AtStart) or
          ((Key=VK_RIGHT) and not AtEnd);
        if not IntSel then begin
            doGridKeyDown;
      end;
    end;

    VK_END, VK_HOME:
      ;
    VK_ESCAPE:
      begin
        doGridKeyDown;
        FGrid.EditorHide;
      end;
    else
      doEditorKeyDown;
  end;
  {$IfDef dbgGrid}
  DebugLn('TPickListCellEditor.KeyDown END: Key=',Dbgs(Key));
  {$Endif}
end;

procedure TPickListCellEditor.EditingDone;
begin
  {$ifdef dbgGrid}DebugLn('TPickListCellEditor.EditingDone INIT');{$ENDIF}
  inherited EditingDone;
  if FGrid<>nil then
    FGrid.EditingDone;
  {$ifdef dbgGrid}DebugLn('TPickListCellEditor.EditingDone END');{$ENDIF}
end;

procedure TPickListCellEditor.DropDown;
begin
  {$ifDef dbgGrid} DebugLn('TPickListCellEditor.DropDown INIT'); {$Endif}
  inherited DropDown;
  {$ifDef dbgGrid} DebugLn('TPickListCellEditor.DropDown END'); {$Endif}
end;

procedure TPickListCellEditor.CloseUp;
begin
  {$ifDef dbgGrid} DebugLn('TPickListCellEditor.CloseUp INIT'); {$Endif}
  inherited CloseUp;
  {$ifDef dbgGrid} DebugLn('TPickListCellEditor.CloseUp END'); {$Endif}
end;

procedure TPickListCellEditor.Select;
begin
  if FGrid<>nil then begin
    FGrid.EditorTextChanged(FCol, FRow, Text);
    FGrid.PickListItemSelected(Self);
  end;
  inherited Select;
end;

procedure TPickListCellEditor.Change;
begin
  if FGrid<>nil then
    FGrid.EditorTextChanged(FCol, FRow, Text);
  inherited Change;
end;

procedure TPickListCellEditor.msg_GetValue(var Msg: TGridMessage);
begin
  Msg.Col := FCol;
  Msg.Row := FRow;
  Msg.Value:=Text;
end;

procedure TPickListCellEditor.msg_SetGrid(var Msg: TGridMessage);
begin
  FGrid:=Msg.Grid;
  Msg.Options:=EO_AUTOSIZE or EO_SELECTALL or EO_HOOKKEYPRESS or EO_HOOKKEYUP;
end;

procedure TPickListCellEditor.msg_SetValue(var Msg: TGridMessage);
begin
  Text := Msg.Value;
  SelStart := Length(Text);
end;

procedure TPickListCellEditor.msg_SetPos(var Msg: TGridMessage);
begin
  FCol := Msg.Col;
  FRow := Msg.Row;
end;

procedure TPickListCellEditor.msg_GetGrid(var Msg: TGridMessage);
begin
  Msg.Grid := FGrid;
  Msg.Options:= EO_IMPLEMENTED;
end;

{ TCompositeCellEditor }

procedure TCompositeCellEditor.DispatchMsg(msg: TGridMessage);
var
  i: Integer;
begin
  for i:=0 to Length(FEditors)-1 do
    if FEditors[i].Editor<>nil then
      Feditors[i].Editor.Dispatch(msg);
end;

function TCompositeCellEditor.GetMaxLength: Integer;
var
  AEditor: TWinControl;
begin
  result := 0;
  AEditor := GetActiveControl;
  if AEditor is TCustomEdit then
    result := TCustomEdit(AEditor).MaxLength;
end;

procedure TCompositeCellEditor.SetMaxLength(AValue: Integer);
var
  AEditor: TWinControl;
begin
  AEditor := GetActiveControl;
  if AEditor is TCustomEdit then
    TCustomEdit(AEditor).MaxLength := AValue;
end;

function TCompositeCellEditor.GetActiveControl: TWinControl;
var
  i: Integer;
begin
  result := nil;
  for i:=0 to Length(Feditors)-1 do
    if (FEditors[i].Editor<>nil) and
       (FEditors[i].ActiveControl) then begin
      Result := FEditors[i].Editor;
      break;
    end;
end;

procedure TCompositeCellEditor.msg_GetValue(var Msg: TGridMessage);
var
  i: Integer;
  DefaultValue: string;
  LocalMsg: TGridMessage;
begin
  Msg.Col := FCol;
  Msg.Row := FRow;

  DefaultValue := Msg.Value;
  for i:=0 to Length(FEditors)-1 do begin

    if FEditors[i].Editor=nil then
      continue;

    LocalMsg := Msg;
    Feditors[i].Editor.Dispatch(LocalMsg);
    if CompareText(DEfaultValue, LocalMsg.Value)<>0 then begin
      // on multiple editors, simply return the first one has
      // a different value than default value
      Msg := LocalMsg;
      break;
    end;

  end;
end;

procedure TCompositeCellEditor.msg_SetGrid(var Msg: TGridMessage);
var
  LocalMsg,ResMsg: TGridMessage;
  i: Integer;
begin
  FGrid:=Msg.Grid;
  ResMsg := Msg;
  for i:=0 to Length(FEditors)-1 do begin
    if FEditors[i].Editor=nil then
      continue;

    LocalMsg := Msg;
    Feditors[i].Editor.Dispatch(LocalMsg);

    if LocalMsg.Options and EO_SELECTALL <> 0 then
      ResMsg.Options := ResMsg.Options or EO_SELECTALL;
    if LocalMsg.Options and EO_HOOKKEYDOWN <> 0 then
      ResMsg.Options := ResMsg.Options or EO_HOOKKEYDOWN;
    if LocalMsg.Options and EO_HOOKKEYPRESS <> 0 then
      ResMsg.Options := ResMsg.Options or EO_HOOKKEYPRESS;
    if LocalMsg.Options and EO_HOOKKEYUP <> 0 then
      ResMsg.Options := ResMsg.Options or EO_HOOKKEYUP;

  end;
  Msg := ResMsg;
end;

procedure TCompositeCellEditor.msg_SetValue(var Msg: TGridMessage);
begin
  DispatchMsg(msg);
end;

procedure TCompositeCellEditor.msg_SetBounds(var Msg: TGridMessage);
var
   r: TRect;
begin
  r := Msg.CellRect;
  FGrid.AdjustInnerCellRect(r);
  SetBounds(r.Left, r.Top, r.Right-r.Left, r.Bottom-r.Top);
end;

procedure TCompositeCellEditor.msg_SetMask(var Msg: TGridMessage);
begin
  DispatchMsg(Msg);
end;

procedure TCompositeCellEditor.msg_SelectAll(var Msg: TGridMessage);
begin
  DispatchMsg(Msg);
end;

procedure TCompositeCellEditor.CMControlChange(var Message: TLMEssage);
begin
  if (Message.WParam<>0) and (not Boolean(Message.LParam)) then
    TControl(Message.WParam).Align:=alNone;
end;

procedure TCompositeCellEditor.msg_SetPos(var Msg: TGridMessage);
begin
  FCol := Msg.Col;
  FRow := Msg.Row;
  DispatchMsg(Msg);
end;

procedure TCompositeCellEditor.msg_GetGrid(var Msg: TGridMessage);
begin
  Msg.Grid := FGrid;
  Msg.Options:= EO_IMPLEMENTED;
end;

procedure TCompositeCellEditor.VisibleChanging;
var
  i: Integer;
  Msg: TGridMessage;
begin
  inherited VisibleChanging;

  if Visible then begin
    // hidding: hide all editors
    for i:=0 to Length(Feditors)-1 do
      if FEditors[i].Editor<>nil then
        FEDitors[i].Editor.Visible:= not Visible;
  end else begin
    Msg.LclMsg.msg:=GM_READY;
    // showing: show all editors
    for i:=0 to Length(Feditors)-1 do begin
      if FEditors[i].Editor=nil then
        continue;
      FEditors[i].Editor.Parent := Self;
      FEditors[i].Editor.Visible:= True;
      FEditors[i].Editor.Align:=FEditors[i].Align;
      // notify now that it's now shown
      FEditors[i].Editor.Dispatch(Msg);
    end;
  end;
end;

procedure TCompositeCellEditor.SetFocus;
var
  ActCtrl: TWinControl;
begin
  if Visible then begin
    ActCtrl := GetActiveControl;
    if ActCtrl<>nil then begin
      ActCtrl.Visible:=true;
      ActCtrl.SetFocus;
      exit;
    end;
  end;
  inherited SetFocus;
end;

function TCompositeCellEditor.Focused: Boolean;
var
  i: Integer;
begin
  Result:=inherited Focused;
  if not result then
    for i:=0 to Length(Feditors)-1 do
      if (FEditors[i].Editor<>nil) and (FEditors[i].Editor.Focused) then begin
        result := true;
        break;
      end;
end;

procedure TCompositeCellEditor.WndProc(var TheMessage: TLMessage);
begin
  with TheMessage do
  if msg=LM_CHAR then begin
    Result := SendChar(Char(WParam));
    if Result=1 then
      exit;
  end;
  inherited WndProc(TheMessage);
end;


function TCompositeCellEditor.DoUTF8KeyPress(var UTF8Key: TUTF8Char): boolean;
begin
  Result:=inherited DoUTF8KeyPress(UTF8Key);
  if not Result and (Length(UTF8Key)>1) then begin
    if SendChar(UTF8Key)=1 then begin
      UTF8Key := '';
      Result := true;
    end;
  end;
end;

function TCompositeCellEditor.SendChar(AChar: TUTF8Char): Integer;
var
  ActCtrl: TWinControl;
begin
  Result := 0;
  ActCtrl := GetActiveControl;
  if (ActCtrl<>nil) and ActCtrl.HandleAllocated then begin
    TWSCustomGridClass(FGrid.WidgetSetClass).SendCharToEditor(ActCtrl, AChar);
    Result:=1;
  end;
end;

destructor TCompositeCellEditor.Destroy;
begin
  SetLength(FEditors, 0);
  inherited destroy;
end;

procedure TCompositeCellEditor.AddEditor(aEditor: TWinControl; aAlign: TAlign;
  ActiveCtrl: boolean);
var
  i: Integer;
begin
  i := Length(FEditors);
  SetLength(FEditors, i+1);
  FEditors[i].Editor := aEditor;
  FEditors[i].Align := aAlign;
  FEditors[i].ActiveControl:=ActiveCtrl;
end;

{ TStringGrid }

class procedure TStringGrid.WSRegisterClass;
const
  Done: Boolean = False;
begin
  if Done then
    Exit;
  RegisterPropertyToSkip(Self, 'VisibleRowCount',
    'Property streamed in by older compiler', '');
  RegisterPropertyToSkip(Self, 'VisibleColCount',
    'Property streamed in by older compiler', '');
  inherited WSRegisterClass;
  Done := True;
end;

end.


{*****************************************}
{                                         }
{             FastReport v2.3             }
{             Report classes              }
{                                         }
{  Copyright (c) 1998-99 by Tzyganenko A. }
{                                         }
{*****************************************}

unit LR_Class;

interface

{$I LR_Vers.inc}

uses
  SysUtils, Math, strutils, DateUtils, {$IFDEF UNIX}CLocale,{$ENDIF}
  Classes, TypInfo, MaskUtils, Variants, DB, DOM, XMLWrite, XMLRead, XMLConf,
  Controls, Forms, Dialogs, Menus, Graphics, LCLProc, LCLType, LCLIntf,
  Printers, osPrinters,
  // LazUtils
  LazFileUtils, LazUTF8,
  // IDEIntf
  PropEdits,
  // LazReport
  LR_View, LR_Pars, LR_Intrp, LR_DSet, LR_DBSet, LR_DBRel, LR_Const, DbCtrls
  {$IFDEF LCLNOGUI}
  ,lr_ngcanvas
  {$ENDIF}
  ;

const
  lrMaxBandsInReport       = 256; //temp fix. in future need remove this limit
  lrSnapDistance: Integer  = 10;

const
// object flags
  flStretched              = $01;
  flWordWrap               = $02;
  flWordBreak              = $04;
  flAutoSize               = $08;
  flHideDuplicates         = $10;
  flStartRecord            = $20;
  flEndRecord              = $40;
  flHideZeros              = $80;

  flBandNewPageAfter       = 2;
  flBandPrintifSubsetEmpty = 4;
  flBandPageBreak          = 8;
  flBandOnFirstPage        = $10;
  flBandOnLastPage         = $20;
  flBandRepeatHeader       = $40;
  flBandPrintChildIfNotVisible = $100;
  flBandKeepChild          = $200;

  flPictCenter             = 2;
  flPictRatio              = 4;
  flWantHook               = $8000;
  flIsDuplicate            = $4000;

// object types
  gtMemo                   = 0;
  gtPicture                = 1;
  gtBand                   = 2;
  gtSubReport              = 3;
  gtLine                   = 4;
  gtAddIn                  = 10;

//format type
  fmtText                  = 0;
  fmtNumber                = 1;
  fmtDate                  = 2;
  fmtTime                  = 3;
  fmtBoolean               = 4;
  
type
  TfrSetOfTyp = set of byte;
  TfrDrawMode = (drAll, drCalcHeight, drAfterCalcHeight, drPart);
  TfrBandType = (btReportTitle, btReportSummary,
                 btPageHeader, btPageFooter,
                 btMasterHeader, btMasterData, btMasterFooter,
                 btDetailHeader, btDetailData, btDetailFooter,
                 btSubDetailHeader, btSubDetailData, btSubDetailFooter,
                 btOverlay, btColumnHeader, btColumnFooter,
                 btGroupHeader, btGroupFooter,
                 btCrossHeader, btCrossData, btCrossFooter, btChild, btNone);
  TfrBandTypes = set of TfrBandType;
  TfrDataSetPosition = (psLocal, psGlobal);
  TfrValueType = (vtNotAssigned, vtDBField, vtOther, vtFRVar);
  TfrPageMode = (pmNormal, pmBuildList);
  TfrBandRecType = (rtShowBand, rtFirst, rtNext);
  TfrRgnType = (rtNormal, rtExtended);
  TfrReportType = (rtSimple, rtMultiple);
  TfrStreamMode = (smDesigning, smPrinting);
  TfrFrameBorder = (frbLeft, frbTop, frbRight, frbBottom);
  TfrFrameBorders = set of TfrFrameBorder;
  TfrFrameStyle = (frsSolid,frsDash, frsDot, frsDashDot, frsDashDotDot,frsDouble);
  TfrPageType = (ptReport, ptDialog);   //todo: - remove this

  TfrReportOption = (roIgnoreFieldNotFound, roIgnoreSymbolNotFound, roHideDefaultFilter,
                     roDontUpgradePreparedReport,   // on saving an old prepared report don't update to current version
                     roSaveAndRestoreBookmarks,     // try to save and later restore dataset bookmarks on building report
                     roPageHeaderBeforeReportTitle, // PageHeader band is printed before ReportTitle band
                     roDisableCancelBuild           // Disable cancel button in build progress form
                     );

  TfrReportOptions = set of TfrReportOption;
  TfrObjectType = (otlReportView, otlUIControl);

  TlrDesignOption = (doUndoDisable, doChildComponent);
  TlrDesignOptions = set of TlrDesignOption;

  TlrRestriction = (lrrDontModify,  lrrDontSize, lrrDontMove, lrrDontDelete);
  TlrRestrictions = set of TlrRestriction;

  TfrObject = class;
  TfrView   = class;
  TfrBand   = class;
  TfrPage   = class;
  TfrReport = class;
  TfrExportFilter  = class;
  TfrMemoStrings   = class;
  TfrScriptStrings = class;

  TDetailEvent = procedure(const ParName: String; var ParValue: Variant) of object;
  TEnterRectEvent = procedure(Memo: TStringList; View: TfrView) of object;
  TBeginDocEvent = procedure of object;
  TEndDocEvent = procedure of object;
  TBeginPageEvent = procedure(pgNo: Integer) of object;
  TEndPageEvent = procedure(pgNo: Integer) of object;
  TBeginBandEvent = procedure(Band: TfrBand) of object;
  TEndBandEvent = procedure(Band: TfrBand) of object;
  TfrProgressEvent = procedure(n: Integer) of object;
  TBeginColumnEvent = procedure(Band: TfrBand) of object;
  TPrintColumnEvent = procedure(ColNo: Integer; var AWidth: Integer) of object;
  TManualBuildEvent = procedure(Page: TfrPage) of object;
  TObjectClickEvent = procedure(View: TfrView) of object;
  TMouseOverObjectEvent = procedure(View: TfrView; var ACursor: TCursor) of object;
  TPrintReportEvent = procedure(Sender: TfrReport) of object;
  TFormPageBookmarksEvent = procedure(Sender: TfrReport; Backup: boolean) of object;
  TExecScriptEvent = procedure(frObject:TfrObject; AScript:TfrScriptStrings) of object;
  TBeforePreviewFormEvent = procedure( var PrForm : TfrPreviewForm ) of Object;

  TfrHighlightAttr = packed record
    FontStyle: Word;
    FontColor, FillColor: TColor;
  end;

  // print info about page size, margins e.t.c
  TfrPrnInfo = record
    PPgw, PPgh, Pgw, Pgh : Integer; // page width/height (printer/screen)
    POfx, POfy, Ofx, Ofy : Integer; // offset x/y
    PPw, PPh, Pw, Ph     : Integer; // printable width/height
    ResX, ResY           : Integer; // printer resolution
  end;

  PfrPageInfo = ^TfrPageInfo;
  TfrPageInfo = packed record // pages of a preview
    R         : TRect;
    pgSize    : Word;
    pgWidth   : Integer;
    pgHeight  : Integer;
    pgOr      : TPrinterOrientation;
    pgMargins : Boolean;
    PrnInfo   : TfrPrnInfo;
    Visible   : Boolean;
    Stream    : TMemoryStream;
    Page      : TfrPage;
  end;

  PfrBandRec = ^TfrBandRec;
  TfrBandRec = packed record
    Band   : TfrBand;
    Action : TfrBandRecType;
  end;
  
  TLayoutOrder = (loColumns, loRows);

  ELazReportException = class(Exception);

  TfrMemoStrings  =Class(TStringList);
  TfrScriptStrings=Class(TStringList);
  
  TfrDialogForm = Class(TForm);
  
  { TLrXMLConfig }

  TLrXMLConfig = class (TXMLConfig)
  public
    procedure LoadFromStream(const Stream: TStream);
    procedure SaveToStream(const Stream: TStream);
    procedure SetValue(const APath: string; const AValue: string); overload;
    function  GetValue(const APath: string; const ADefault: string): string; overload;
  end;

  { TfrObject }

  TfrObject = class(TPersistent)
  private
    fMemo   : TfrMemoStrings;
    fName   : string;
    fScript : TfrScriptStrings;
    fVisible: Boolean;
    fUpdate : Integer;
    
    procedure SetMemo(const AValue: TfrMemoStrings);
    procedure SetScript(const AValue: TfrScriptStrings);
  protected
    FDesignOptions:TlrDesignOptions;
    BaseName  : String;
    OwnerPage : TfrPage;
    FOnExecScriptEvent : TExecScriptEvent;

    function GetSaveProperty(const Prop : String; aObj : TPersistent=nil) : string;
    procedure RestoreProperty(const Prop,aValue : String; aObj : TPersistent=nil);
    procedure SetName(const AValue: string); virtual;
    procedure AfterLoad;virtual;
    procedure AfterCreate;virtual;
    function ExecMetod(const {%H-}AName: String; {%H-}p1, {%H-}p2, {%H-}p3: Variant; var {%H-}Val: Variant):boolean;virtual;
    function GetLeft: Integer;virtual;
    function GetTop: Integer;virtual;
    function GetWidth: Integer;virtual;
    function GetHeight: Integer;virtual;
    procedure SetLeft(AValue: Integer);virtual;
    procedure SetTop(AValue: Integer);virtual;
    procedure SetWidth(AValue: Integer);virtual;
    procedure SetHeight(AValue: Integer);virtual;
    procedure SetVisible(AValue: Boolean);virtual;
    function GetText:string;virtual;
    procedure SetText(AValue:string);virtual;
    procedure InternalExecScript;virtual;
  public
    x, y, dx, dy: Integer;

    constructor Create(AOwnerPage:TfrPage); virtual;
    destructor Destroy; override;

    { TODO : check this!! }
    procedure AssignTo(Dest: TPersistent); override;
    procedure Assign(Source: TPersistent); override; //virtual; overload;

    procedure BeginUpdate;virtual;
    procedure EndUpdate;virtual;
    
    procedure CreateUniqueName;

    procedure LoadFromXML(XML: TLrXMLConfig; const Path: String); virtual;
    procedure SaveToXML(XML: TLrXMLConfig; const Path: String); virtual;

    property Memo   : TfrMemoStrings read fMemo write SetMemo;
    property Script : TfrScriptStrings read fScript write SetScript;
    property Left   : Integer read GetLeft write SetLeft;
    property Top    : Integer read GetTop write SetTop;
    property Width  : Integer read GetWidth write SetWidth;
    property Height : Integer read GetHeight write SetHeight;
    property DesignOptions:TlrDesignOptions read FDesignOptions;
  published
    property Name   : string read fName write SetName;
    property Visible: Boolean read fVisible write SetVisible;
  end;
  
  { TfrView }

  TfrView = class(TfrObject)
  private
    FFillColor : TColor;
    fCanvas    : TCanvas;
    fFrameColor: TColor;
    fFrames    : TfrFrameBorders;
    fFrameStyle: TfrFrameStyle;
    fFrameWidth: Double;
    FRestrictions: TlrRestrictions;
    fStreamMode: TfrStreamMode;
    fFormat    : Integer;
    fFormatStr : string;
    fFrameTyp  : word;
    FTag: string;
    FURLInfo: string;
    FFindHighlight : boolean;
    FGapX:Integer;
    FGapY:Integer;

    function GetDataField: string;
    function GetLeft: Double;
    function GetStretched: Boolean;
    function GetTop: Double;
    procedure P1Click(Sender: TObject);
    procedure SetDataField(AValue: string);
    procedure SetFillColor(const AValue: TColor);
    procedure SetFormat(const AValue: Integer);
    procedure SetFormatStr(const AValue: String);
    procedure SetFrameColor(const AValue: TColor);
    procedure SetFrames(const AValue: TfrFrameBorders);
    procedure SetFrameStyle(const AValue: TfrFrameStyle);
    procedure SetFrameWidth(const AValue: Double);
    procedure SetStretched(const AValue: Boolean);
  protected
    SaveX, SaveY, SaveDX, SaveDY: Integer;
    SaveFW: Double;

    InternalGapX, InternalGapY: Integer;
    Memo1: TStringList;
    FDataSet: TfrTDataSet;
    FField: String;
    olddy: Integer;
    oldy: Integer;

    procedure ShowBackGround; virtual;
    procedure ShowFrame; virtual;
    procedure BeginDraw(ACanvas: TCanvas);
    procedure GetBlob(b: TfrTField); virtual;
    procedure OnHook(View: TfrView); virtual;
    procedure BeforeChange; virtual;
    procedure AfterChange; virtual;
    procedure ResetLastValue; virtual;
    function GetFrames: TfrFrameBorders; virtual;
    procedure ModifyFlag(aFlag: Word; aValue:Boolean);
    procedure MenuItemCheckFlag(Sender:TObject; aFlag: Word);
    procedure SetHeight(const AValue: Double);virtual;
    procedure SetLeft(const AValue: Double);virtual;
    procedure SetTop(const AValue: Double);virtual;
    procedure SetWidth(const AValue: Double);virtual;
    function GetHeight: Double;virtual;
    function GetWidth: Double;virtual;
    procedure PrepareObject;virtual;
    property DataField : string read GetDataField write SetDataField;
  public
    Parent: TfrBand;
    ID: Integer;
    Typ: Byte;
    Selected: Boolean;
    OriginalRect: TRect;
    ScaleX, ScaleY: Double;   // used for scaling objects in preview
    OffsX, OffsY: Integer;    //
    IsPrinting: Boolean;
    Flags: Word;
    DRect: TRect;
    ParentBandType: TfrBandType; // identify parent band type on exporting view

    constructor Create(AOwnerPage:TfrPage); override;
    destructor Destroy; override;
    
    procedure Assign(Source: TPersistent); override;
    procedure CalcGaps; virtual;
    procedure RestoreCoord; virtual;
    procedure Draw(aCanvas: TCanvas); virtual; abstract;
    procedure Print(Stream: TStream); virtual;
    procedure ExportData; virtual;
    procedure LoadFromStream(Stream: TStream); virtual;
    procedure SaveToStream(Stream: TStream); virtual;

    procedure LoadFromXML(XML: TLrXMLConfig; const Path: String); override;
    procedure SaveToXML(XML: TLrXMLConfig; const Path: String); override;

    procedure Resized; virtual;
    procedure DefinePopupMenu(Popup: TPopupMenu); virtual;
    function GetClipRgn(rt: TfrRgnType): HRGN; virtual;
    procedure SetBounds(aLeft, aTop, aWidth, aHeight: Integer);

    function PointInView(aX,aY : Integer) : Boolean; virtual;
    function FindAlignSide(const vert:boolean; const value: Integer; out found: Integer): boolean; virtual;
    procedure Invalidate;

    property Canvas : TCanvas read fCanvas write fCanvas;

    property FillColor : TColor read FFillColor write SetFillColor;
    property Stretched : Boolean read GetStretched write SetStretched;

    property Frames : TfrFrameBorders read GetFrames write SetFrames;
    property FrameColor : TColor read fFrameColor write SetFrameColor;
    property FrameStyle : TfrFrameStyle read fFrameStyle write SetFrameStyle;
    property FrameWidth : Double read fFrameWidth write SetFrameWidth;
    property Format     : Integer read fFormat write SetFormat;
    property FormatStr  : String read fFormatStr write SetFormatStr;

    property StreamMode: TfrStreamMode read fStreamMode write fStreamMode;
    property Restrictions:TlrRestrictions read FRestrictions write FRestrictions;
    property FindHighlight : boolean read FFindHighlight write FFindHighlight;
    property GapX:Integer read FGapX write FGapX;
    property GapY:Integer read FGapY write FGapY;
  published
    property Left: double read GetLeft write SetLeft;
    property Top: double read GetTop write SetTop;
    property Tag: string read FTag write FTag;
    property URLInfo: string read FURLInfo write FURLInfo;
    property Width: double read GetWidth write SetWidth;
    property Height: double read GetHeight write SetHeight;
  end;
  TfrViewClass = Class of TFRView;

  TfrStretcheable = class(TfrView)
  protected
    ActualHeight: Integer;
    DrawMode: TfrDrawMode;

    function CalcHeight: Integer; virtual; abstract;
    function MinHeight: Integer; virtual; abstract;
    function RemainHeight: Integer; virtual; abstract;
  published
    property Stretched;
  end;

  { TfrControl }

  TfrControl = class(TfrView)
  protected
    procedure PaintDesignControl; virtual;abstract;
  public
    procedure UpdateControlPosition; virtual;
    procedure AttachToParent; virtual;
    function OwnerForm:TWinControl; virtual;
    constructor Create(AOwnerPage:TfrPage); override;
    procedure Draw(ACanvas: TCanvas); override;
    procedure DefinePopupMenu(Popup: TPopupMenu); override;
  published
    property Restrictions;
  end;

  { TfrNonVisualControl }

  TfrNonVisualControl = class(TfrControl)
  protected
    ControlImage: TCustomBitmap;
    procedure PaintDesignControl; override;
  public
    constructor Create(AOwnerPage:TfrPage); override;
    destructor Destroy; override;
    procedure Draw(ACanvas: TCanvas); override;
  end;


  { TfrCustomMemoView }

  TfrCustomMemoView = class(TfrStretcheable)
  private
    FCursor: TCursor;
    FDetailReport: string;
    fFont        : TFont;
    fLastValue   : TStringList;
    FOnClick: TfrScriptStrings;
    FOnMouseEnter: TfrScriptStrings;
    FOnMouseLeave: TfrScriptStrings;
    FParagraphGap: integer;

    function GetAlignment: TAlignment;
    function GetAngle: Byte;
    function GetAutoSize: Boolean;
    function GetHideDuplicates: Boolean;
    function GetHideZeroValues: Boolean;
    function GetIsLastValueSet: boolean;
    function GetJustify: boolean;
    function GetLayout: TTextLayout;
    function GetWordBreak: Boolean;
    function GetWordWrap: Boolean;
    procedure P1Click(Sender: TObject);
    procedure P2Click(Sender: TObject);
    procedure P3Click(Sender: TObject);
    procedure P4Click(Sender: TObject);
    procedure P5Click(Sender: TObject);
    procedure P6Click(Sender: TObject);
    procedure SetAlignment(const AValue: TAlignment);
    procedure SetAngle(const AValue: Byte);
    procedure SetAutoSize(const AValue: Boolean);
    procedure SetCursor(AValue: TCursor);
    procedure SetFont(Value: TFont);
    procedure SetHideDuplicates(const AValue: Boolean);
    procedure SetHideZeroValues(AValue: Boolean);
    procedure SetIsLastValueSet(const AValue: boolean);
    procedure SetJustify(AValue: boolean);
    procedure SetLayout(const AValue: TTextLayout);
    procedure SetOnClick(AValue: TfrScriptStrings);
    procedure SetOnMouseEnter(AValue: TfrScriptStrings);
    procedure SetOnMouseLeave(AValue: TfrScriptStrings);
    procedure SetWordBreak(AValue: Boolean);
    procedure SetWordWrap(const AValue: Boolean);
  protected
    Streaming: Boolean;
    TextHeight: Integer;
    CurStrNo: Integer;
    Exporting: Boolean;
    FLineSpacing: Integer;

    procedure ExpandVariables;
    procedure AssignFont(aCanvas: TCanvas);
    procedure WrapMemo;
    procedure ShowMemo;
    function CalcWidth(aMemo: TStringList): Integer;
    function CalcHeight: Integer; override;
    function MinHeight: Integer; override;
    function RemainHeight: Integer; override;
    procedure GetBlob(b: TfrTField); override;
    procedure FontChange({%H-}sender: TObject);
    procedure ResetLastValue; override;

    procedure DoRunScript(AScript: TfrScriptStrings);

    procedure DoOnClick;
    procedure DoMouseEnter;
    procedure DoMouseLeave;

    property IsLastValueSet: boolean read GetIsLastValueSet write SetIsLastValueSet;
  public
    Adjust: Integer; // bit format xxxLLRAA: LL=Layout, R=Rotated, AA=Alignment
    Highlight: TfrHighlightAttr;
    HighlightStr: String;
    CharacterSpacing: Integer;
    LastLine: boolean; // are we painting/exporting the last line?
    FirstLine: boolean;
    
    constructor Create(AOwnerPage:TfrPage); override;
    destructor Destroy; override;
    
    procedure Assign(Source: TPersistent); override;
    procedure Draw(aCanvas: TCanvas); override;
    procedure Print(Stream: TStream); override;
    procedure ExportData; override;
    procedure LoadFromStream(Stream: TStream); override;
    procedure LoadFromXML(XML: TLrXMLConfig; const Path: String); override;
    procedure SaveToStream(Stream: TStream); override;
    procedure SaveToXML(XML: TLrXMLConfig; const Path: String); override;
    procedure DefinePopupMenu(Popup: TPopupMenu); override;

    procedure MonitorFontChanges;
    property Justify: boolean read GetJustify write SetJustify;
    
    property Cursor: TCursor read FCursor write SetCursor default crDefault;
    property DetailReport   : string read FDetailReport write FDetailReport;
    property Font      : TFont read fFont write SetFont;
    property Alignment : TAlignment read GetAlignment write SetAlignment;
    property Layout    : TTextLayout read GetLayout write SetLayout;
    property Angle     : Byte read GetAngle write SetAngle;
    property WordBreak : Boolean read GetWordBreak write SetWordBreak;
    property WordWrap  : Boolean read GetWordWrap write SetWordWrap;
    property AutoSize  : Boolean read GetAutoSize write SetAutoSize;
    property HideDuplicates: Boolean read GetHideDuplicates write SetHideDuplicates;
    property HideZeroValues : Boolean read GetHideZeroValues write SetHideZeroValues;
    property OnClick   : TfrScriptStrings read FOnClick write SetOnClick;
    property OnMouseEnter : TfrScriptStrings read FOnMouseEnter write SetOnMouseEnter;
    property OnMouseLeave : TfrScriptStrings read FOnMouseLeave write SetOnMouseLeave;
    property ParagraphGap : integer read FParagraphGap write FParagraphGap;
    property LineSpacing : integer read FLineSpacing write FLineSpacing;
  end;

  TfrMemoView = class(TfrCustomMemoView)
  published
    property Cursor;
    property DetailReport;
    property Font;
    property Alignment;
    property Layout;
    property Angle;
    property WordBreak;
    property WordWrap;
    property AutoSize;
    property HideDuplicates;
    property HideZeroValues;
    property FillColor;
    property Memo;
    property Script;
    property Frames;
    property FrameColor;
    property FrameStyle;
    property FrameWidth;
    property Format;
    property FormatStr;
    property Restrictions;
    property ParagraphGap;
    property OnClick;
    property OnMouseEnter;
    property OnMouseLeave;
    property LineSpacing;
    property GapX;
    property GapY;
  end;

  { TfrBandView }

  TfrBandView = class(TfrView)
  private
    fDataSetStr : String;
    fBandType   : TfrBandType;
    fCondition  : String;
    fChild      : String;

    procedure P1Click(Sender: TObject);
    procedure P2Click(Sender: TObject);
    procedure P3Click(Sender: TObject);
    procedure P4Click(Sender: TObject);
    procedure P5Click(Sender: TObject);
    procedure P6Click(Sender: TObject);
    procedure P7Click(Sender: TObject);
    procedure P8Click(Sender: TObject);
    function  GetTitleRect: TRect;
    function  TitleSize: Integer;
    procedure CalcTitleSize;
    procedure FixPrintChildIfNotVisible;
  protected
    procedure SetHeight(const AValue: Double); override;
    procedure SetVisible(AValue: Boolean);override;
  public
    constructor Create(AOwnerPage:TfrPage); override;

    procedure Assign(Source: TPersistent); override;
    
    procedure LoadFromStream(Stream: TStream); override;
    procedure LoadFromXML(XML: TLrXMLConfig; const Path: String); override;
    procedure SaveToStream(Stream: TStream); override;
    procedure SaveToXML(XML: TLrXMLConfig; const Path: String); override;
    

    procedure Draw(aCanvas: TCanvas); override;
    procedure DefinePopupMenu(Popup: TPopupMenu); override;
    function GetClipRgn(rt: TfrRgnType): HRGN; override;
    
    function PointInView(aX,aY : Integer) : Boolean; override;


  published
    property DataSet: String read fDataSetStr write fDataSetStr;
    property GroupCondition: String read fCondition write fCondition;
    property Child: String read fChild write fChild;

    property BandType: TfrBandType read fBandType write fBandType;

    property Script;
    property Stretched;
    property Restrictions;
  end;

  { TfrSubReportView }

  TfrSubReportView = class(TfrView)
  private
    FSubPageIndex: Integer; //temp var for find page on load
    FSubPage : TfrPage;
  protected
    procedure AfterLoad;override;
  public
    //SubPage: Integer;
    constructor Create(AOwnerPage:TfrPage); override;
    procedure Assign(Source: TPersistent); override;
    procedure Draw(aCanvas: TCanvas); override;
    procedure LoadFromStream(Stream: TStream); override;
    procedure LoadFromXML(XML: TLrXMLConfig; const Path: String); override;
    procedure SaveToStream(Stream: TStream); override;
    procedure SaveToXML(XML: TLrXMLConfig; const Path: String); override;
    procedure DefinePopupMenu({%H-}Popup: TPopupMenu); override;
    property SubPage : TfrPage read FSubPage write FSubPage;
  published
    property Restrictions;
  end;

  { TfrPictureView }

  TfrPictureView = class(TfrView)
  private
    fPicture: TPicture;
    FSharedName: string;
    
    function GetCentered: boolean;
    function GetKeepAspect: boolean;
    procedure P1Click(Sender: TObject);
    procedure P2Click(Sender: TObject);
    function GetPictureType: byte;
    function PictureTypeToGraphic(b: Byte): TGraphic;
    function ExtensionToGraphic(const Ext: string): TGraphic;
    procedure SetCentered(AValue: boolean);
    procedure SetKeepAspect(AValue: boolean);
    function StreamToGraphic(M: TMemoryStream): TGraphic;
    procedure SetPicture(const AValue: TPicture);
  protected
    procedure GetBlob(b: TfrTField); override;
  public
    constructor Create(AOwnerPage:TfrPage); override;
    destructor Destroy; override;
    
    procedure Assign(Source: TPersistent); override;
    procedure Draw(aCanvas: TCanvas); override;
    procedure LoadFromStream(Stream: TStream); override;
    procedure LoadFromXML(XML: TLrXMLConfig; const Path: String); override;
    procedure SaveToStream(Stream: TStream); override;
    procedure SaveToXML(XML: TLrXMLConfig; const Path: String); override;
    procedure DefinePopupMenu(Popup: TPopupMenu); override;
  published
    property Picture : TPicture read fPicture write SetPicture;

    property KeepAspect:boolean read GetKeepAspect write SetKeepAspect;
    property Centered: boolean read GetCentered write SetCentered;
    property DataField;
    property Memo;
    property Script;
    property Frames;
    property FrameColor;
    property FrameStyle;
    property FrameWidth;
    property Stretched;
    property SharedName: string read FSharedName write FSharedName;
    property FillColor;  //: TColor read FFillColor write SetFillColor;
    property Restrictions;
  end;

  { TfrLineView }

  TfrLineView = class(TfrView)
  protected
    function GetFrames: TfrFrameBorders; override;
  public
    constructor Create(AOwnerPage:TfrPage); override;

    procedure Draw(aCanvas: TCanvas); override;
    function GetClipRgn(rt: TfrRgnType): HRGN; override;
    function PointInView(aX,aY: Integer): Boolean; override;
    
  published
    property FrameColor;
    property FrameStyle;
    property FrameWidth;
    property Stretched;
    property Restrictions;
  end;

  TfrRect = Class(TPersistent)
  private
    fBottom: Integer;
    fLeft: Integer;
    fRight: Integer;
    fTop: Integer;
    function GetRect: TRect;
    procedure SetRect(const AValue: TRect);
  public
    property AsRect : TRect read GetRect write SetRect;
    
  published
    property Left : Integer read fLeft write fLeft;
    property Top  : Integer read fTop  write fTop;
    property Right: Integer read fRight write fRight;
    property Bottom : Integer read fBottom write fBottom;
  end;
  
  TfrBand = class(TfrObject)
  private
    Parent: TfrPage;
    View: TfrView;
    Flags: Word;
    Next, Prev: TfrBand;
    SubIndex, MaxY: Integer;
    EOFArr: Array[0..lrMaxBandsInReport - 1] of Boolean;
    Positions: Array[TfrDatasetPosition] of Integer;
    LastGroupValue: Variant;
    HeaderBand, FooterBand, LastBand: TfrBand;
    ChildBand: TfrBand;
    Values: TStringList;
    Count: Integer;
    DisableInit: Boolean;
    CalculatedHeight: Integer;

    procedure InitDataSet(const Desc: String);
    procedure DoError(const AErrorMsg: String);
    function CalcHeight: Integer;
    procedure StretchObjects(MaxHeight: Integer);
    procedure UnStretchObjects;
    procedure DrawObject(t: TfrView);
    procedure PrepareSubReports;
    procedure DoSubReports;
    function DrawObjects: Boolean;
    procedure DrawCrossCell(Parnt: TfrBand; CurX: Integer);
    procedure DrawCross;
    function CheckPageBreak(ay, ady: Integer; PBreak: Boolean): Boolean;
    function CheckNextColumn: boolean;
    procedure DrawPageBreak;
    function HasCross: Boolean;
    function DoCalcHeight: Integer;
    procedure DoDraw;
    function Draw: Boolean;
    procedure InitValues;
    procedure DoAggregate;
    procedure ResetLastValues;
    function getName: string;
  public
    EOFReached: Boolean;
    MaxDY: Integer;

    Typ: TfrBandType;
    PrintIfSubsetEmpty, NewPageAfter, Stretched, PageBreak: Boolean;
    PrintChildIfNotVisible: Boolean;
    Objects: TFpList;
    DataSet: TfrDataSet;
    IsVirtualDS: Boolean;
    VCDataSet: TfrDataSet;
    IsVirtualVCDS: Boolean;
    GroupCondition: String;
    ForceNewPage, ForceNewColumn: Boolean;

    constructor Create(ATyp: TfrBandType; AParent: TfrPage); overload;
    destructor Destroy; override;
    function IsDataBand: boolean;
    property Name: string read getName;
  end;

  TfrValue = class
  public
    Typ       : TfrValueType;
    OtherKind : Integer;     // for vtOther - typ, for vtDBField - format
    DataSet   : String;      // for vtDBField
    Field     : String;      // here is an expression for vtOther
    DSet      : TfrTDataSet;
  end;

  { TfrValues }

  TfrValues = class(TPersistent)
  private
    FItems: TStringList;
    function GetValue(Index: Integer): TfrValue;
  public
    constructor Create; virtual;
    destructor Destroy; override;

    function AddValue: Integer;
    function FindVariable(const s: String): TfrValue;
    procedure ReadBinaryData(Stream: TStream);
    procedure ReadBinaryDataFromXML(XML: TLrXMLConfig; const Path: String);
    procedure WriteBinaryData(Stream: TStream);
    procedure WriteBinaryDataToXML(XML: TLrXMLConfig; const Path: String);
    procedure Clear;

    property Items: TStringList read FItems write FItems;
    property Objects[Index: Integer]: TfrValue read GetValue;
  end;

  { TfrPage }

  TfrPage = class(TfrObject)
  private
    fColCount         : Integer;
    fColGap           : Integer;
    fColWidth         : Integer;
    fLastBandType     : TfrBandType;
    fLastRowHeight    : Integer;
    fMargins          : TfrRect;
    fOrientation      : TPrinterOrientation;
    fPrintToPrevPage  : Boolean;
    fRowStarted       : boolean;
    fUseMargins       : Boolean;
    Skip              : Boolean;
    InitFlag          : Boolean;
    CurColumn         : Integer;
    LastStaticColumnY : Integer;
    XAdjust           : Integer;
    LastBand          : TfrBand;
    ColPos            : Integer;
    CurPos            : Integer;
    PageType          : TfrPageType;  //todo: - remove this
    fLayoutOrder      : TLayoutOrder;
    procedure DoAggregate(a: Array of TfrBandType);
    procedure AddRecord(b: TfrBand; rt: TfrBandRecType);
    procedure ClearRecList;
    procedure DrawPageFooters;
    function BandExists(b: TfrBand): Boolean;
    function GetPageIndex: integer;
    procedure LoadFromStream(Stream: TStream);
    procedure SaveToStream(Stream: TStream);
    procedure SetPageIndex(AValue: integer);

    procedure ShowBand(b: TfrBand);
  protected
    List              : TFpList;
    Bands             : Array[TfrBandType] of TfrBand;
    Mode              : TfrPageMode;
    PlayFrom          : Integer;
    function PlayRecList: Boolean;
    procedure InitReport; virtual;
    procedure DoneReport; virtual;
    procedure TossObjects; virtual;
    procedure PrepareObjects; virtual;
    procedure FormPage; virtual;
    procedure AfterPrint; virtual;
    procedure AfterLoad;override;
  public
    pgSize    : Integer;
    PrnInfo   : TfrPrnInfo;
    Objects   : TFpList;
    RTObjects : TFpList;
    CurY      : Integer;
    CurBottomY: Integer;
    
    constructor Create(AOwnerPage:TfrPage); override;
    destructor Destroy; override;

    constructor Create(ASize, AWidth, AHeight: Integer; AOr: TPrinterOrientation);
    constructor CreatePage; virtual;
    
    procedure LoadFromXML(XML: TLrXMLConfig; const Path: String); override;
    procedure SavetoXML(XML: TLrXMLConfig; const Path: String); override;

    function TopMargin: Integer;
    function BottomMargin: Integer;
    function LeftMargin: Integer;
    function RightMargin: Integer;
    procedure Clear;
    procedure Delete(Index: Integer);
    function FindObjectByID(ID: Integer): Integer;
    function FindObject(const aName: String): TfrObject;
    function FindRTObject(const aName: String): TfrObject;
    procedure ChangePaper(ASize, AWidth, AHeight: Integer; AOr: TPrinterOrientation);
    procedure ShowBandByName(const s: String);
    procedure ShowBandByType(bt: TfrBandType);
    procedure NewPage;
    procedure NewColumn(Band: TfrBand);
    procedure NextColumn({%H-}Band: TFrBand);
    function RowsLayout: boolean;
    procedure StartColumn;
    procedure StartRowsLayoutNonDataBand(Band: TfrBand);
    function  AdvanceRow(Band: TfrBand): boolean;
    
    property ColCount : Integer read fColCount write fColCount;
    property ColWidth : Integer read fColWidth write fColWidth;
    property ColGap   : Integer read fColGap write fColGap;
    property UseMargins : Boolean read fUseMargins write fUseMargins;
    property Margins    : TfrRect read fMargins write fMargins;
    property PrintToPrevPage : Boolean read fPrintToPrevPage write fPrintToPrevPage;
    property Orientation : TPrinterOrientation read fOrientation write fOrientation;
    property LayoutOrder: TLayoutOrder read fLayoutOrder write fLayoutOrder;
    property LastRowHeight: Integer read fLastRowHeight write fLastRowHeight;
    property RowStarted: boolean read fRowStarted write fRowStarted;
    property LastBandType: TfrBandType read fLastBandType write fLastbandType;

  published
    property Script;
    property Height;
    property Width;
    property PageIndex:integer read GetPageIndex write SetPageIndex;
  end;

  TFrPageClass = Class of TfrPage;
  
  { TfrPageReport }

  TfrPageReport = Class(TfrPage)
  public
    procedure LoadFromXML(XML: TLrXMLConfig; const Path: String); override;
    procedure SavetoXML(XML: TLrXMLConfig; const Path: String); override;
    
    constructor CreatePage; override;
  published
    property ColCount;
    property ColWidth;
    property ColGap;
    property UseMargins;
    property Margins;
    property PrintToPrevPage;
    property Orientation;
    property LayoutOrder;
  end;

  { TfrPageDialog }

  TfrPageDialog = Class(TfrPage)
  private
    fHasVisibleControls : Boolean;
    FForm               : TfrDialogForm;
    FCaption            : string;
    procedure EditFormDestroy(Sender: TObject);
    function GetCaption: string;
    procedure SetCaption(AValue: string);
    procedure UpdateControlPosition;
  protected
    procedure PrepareObjects; override;
    procedure InitReport; override;
    procedure DoneReport; override;
    procedure SetLeft(AValue: Integer);override;
    procedure SetTop(AValue: Integer);override;
    procedure SetWidth(AValue: Integer);override;
    procedure SetHeight(AValue: Integer);override;
    procedure ExecScript;
  public
    constructor Create(AOwnerPage:TfrPage); override;
    destructor Destroy; override;

    procedure LoadFromXML(XML: TLrXMLConfig; const Path: String); override;
    procedure SavetoXML(XML: TLrXMLConfig; const Path: String); override;
    property Form:TfrDialogForm read FForm;
  published
    property Caption : string read GetCaption write SetCaption;
    property Left;
    property Top;
  end;

  { TfrPages }

  TfrPages = class(TObject)
  private
    FPages: TFpList;
    Parent: TfrReport;

    function GetCount: Integer;
    function GetPages(Index: Integer): TfrPage;
    procedure AfterLoad;
  public
    constructor Create(AParent: TfrReport);
    destructor Destroy; override;

    procedure Clear;
    function Add(const aClassName : string='TfrPageReport'):TfrPage;
    procedure Delete(Index: Integer);
    procedure Move(OldIndex, NewIndex: Integer);
    procedure LoadFromStream(Stream: TStream);
    procedure LoadFromXML(XML: TLrXMLConfig; const Path: String);
    procedure SaveToStream(Stream: TStream);
    procedure SavetoXML(XML: TLrXMLConfig; const Path: String);
    function PageByName(const APageName: string): TfrPage;

    property Pages[Index: Integer]: TfrPage read GetPages; default;
    property Count: Integer read GetCount;
  end;

  { TfrEMFPages }

  TfrEMFPages = class(TObject)
  private
    FPages: TFpList;
    Parent: TfrReport;
    function GetCount: Integer;
    function GetPages(Index: Integer): PfrPageInfo;
    procedure ExportData(Index: Integer);
    procedure PageToObjects(Index: Integer);
  public
    constructor Create(AParent: TfrReport);
    destructor Destroy; override;
    procedure Clear;
    procedure ObjectsToPage(Index: Integer);
    procedure Draw(Index: Integer; Canvas: TCanvas; DrawRect: TRect);
    procedure Add(APage: TfrPage);
    procedure Insert(Index: Integer; APage: TfrPage);
    procedure Delete(Index: Integer);

    procedure ResetFindData;

    function DoMouseClick(Index: Integer; pt: TPoint; var AInfo: String): Boolean;
    function DoMouseMove(Index: Integer; pt: TPoint; var Cursor: TCursor; var AInfo: String): TfrView;

    procedure LoadFromStream(AStream: TStream);
    procedure AddPagesFromStream(AStream: TStream; AReadHeader: boolean=true);
    procedure LoadFromXML({%H-}XML: TLrXMLConfig; const {%H-}Path: String);
    procedure SaveToStream(AStream: TStream);
    procedure SavePageToStream(PageNo:Integer; AStream: TStream);
    procedure SaveToXML({%H-}XML: TLrXMLConfig; const {%H-}Path: String);
    procedure UpgradeToCurrentVersion;
    property Pages[Index: Integer]: PfrPageInfo read GetPages; default;
    property Count: Integer read GetCount;
  end;

  { TfrExportFilter }

  TExportFilterSetup = procedure(Sender: TfrExportFilter) of object;

  TfrExportFilter = class(TObject)
  private
    FOnSetup: TExportFilterSetup;
    FBandTypes: TfrBandTypes;
    FUseProgressBar: boolean;
    FLineIndex: Integer;
  protected
    Stream: TStream;
    Lines: TFpList;
    procedure ClearLines;
    function Setup:boolean; virtual;
    function  AddData({%H-}x, {%H-}y: Integer; view: TfrView): pointer; virtual;
    procedure NewRec(View: TfrView; const AText:string; var P:Pointer); virtual;
    procedure AddRec(ALineIndex: Integer; ARec: Pointer); virtual;
    function  GetviewText(View:TfrView): string; virtual;
    function  CheckView({%H-}View:TfrView): boolean; virtual;
    procedure AfterExport; virtual;
  public
    constructor Create(AStream: TStream); virtual;
    destructor Destroy; override;
    procedure OnBeginDoc; virtual;
    procedure OnEndDoc; virtual;
    procedure OnBeginPage; virtual;
    procedure OnEndPage; virtual;
    procedure OnData({%H-}x, {%H-}y: Integer; {%H-}View: TfrView); virtual;
    procedure OnText({%H-}x, {%H-}y: Integer; const {%H-}text: String; {%H-}View: TfrView); virtual;
    procedure OnExported({%H-}x, {%H-}y: Integer; {%H-}View: TfrView); virtual;

    property BandTypes: TfrBandTypes read FBandTypes write FBandTypes;
    property UseProgressbar: boolean read FUseProgressBar write FUseProgressBar;
    property OnSetup: TExportFilterSetup read FOnSetup write FOnSetup;
  end;

  TfrExportFilterClass = class of TfrExportFilter;

  { TlrDetailReport }

  TlrDetailReport = class
  private
    FReportBody: TStream;
    FReportDescription: string;
    FReportName: string;
  public
    constructor Create;
    destructor Destroy; override;
    procedure LoadFromXML(XML: TLrXMLConfig; const Path: String);
    procedure SaveToXML(XML: TLrXMLConfig; const Path: String);

    procedure SaveToStream(Stream: TStream);
    procedure LoadFromStream(Stream: TStream);

    property ReportDescription:string read FReportDescription write FReportDescription;
    property ReportBody:TStream read FReportBody;
    property ReportName:string read FReportName write FReportName;
  end;

  { TlrDetailReports }

  TlrDetailReports = class
  private
    FList:TFPList;
    function GetCount: integer;
    function GetItems(AReportName: string): TlrDetailReport;
    procedure Clear;
  public
    constructor Create;
    destructor Destroy; override;
    procedure LoadFromStream(Stream: TStream);
    procedure LoadFromXML(XML: TLrXMLConfig; const Path: String);
    procedure SaveToStream(Stream: TStream);
    procedure SaveToXML(XML: TLrXMLConfig; const Path: String);
    function GetItem(AItem:integer): TlrDetailReport;
    function Add(AReportName: string):TlrDetailReport;
    property Items[AReportName:string]:TlrDetailReport read GetItems; default;
    property Count:integer read GetCount;
  end;

  TfrDataType = (dtDataSet,dtDataSource);

  { TfrReport }

  TfrReport = class(TComponent)
  private
    FDataType: TfrDataType;
    FDefaultCollate: boolean;
    FDetailReports: TlrDetailReports;
    FOnAfterPrint: TPrintReportEvent;
    FOnBeforePrint: TPrintReportEvent;
    FOnDBImageRead: TOnDBImageRead;
    FDefaultCopies: Integer;
    FMouseOverObject: TMouseOverObjectEvent;
    FObjectClick: TObjectClickEvent;
    FOnExportFilterSetup: TExportFilterSetup;
    fOnFormPageBookmarks: TFormPageBookmarksEvent;
    fOnBeforePreview : TBeforePreviewFormEvent;
    FPages: TfrPages;
    FEMFPages: TfrEMFPages;
    FRebuildPrinter: boolean;
    FReportAutor: string;
    FReportCreateDate: TDateTime;
    FReportLastChange: TDateTime;
    FReportOptions: TfrReportOptions;
    FReportVersionBuild: string;
    FReportVersionMajor: string;
    FReportVersionMinor: string;
    FReportVersionRelease: string;
    FScript: TfrScriptStrings;
    FVars: TStrings;
    FVal: TfrValues;
    FDataset: TfrDataset;
    FGrayedButtons: Boolean;
    FReportType: TfrReportType;
    FShowProgress: Boolean;
    FModalPreview: Boolean;
    FModifyPrepared: Boolean;
    FStoreInDFM: Boolean;
    FStoreInForm: Boolean;
    FPreview: TfrPreview;
    FPreviewButtons: TfrPreviewButtons;
    FInitialZoom: TfrPreviewZoom;
    FOnBeginDoc: TBeginDocEvent;
    FOnEndDoc: TEndDocEvent;
    FOnBeginPage: TBeginPageEvent;
    FOnEndPage: TEndPageEvent;
    FOnBeginBand: TBeginBandEvent;
    FOnEndBand: TEndBandEvent;
    FOnGetValue: TDetailEvent;
    FOnEnterRect: TEnterRectEvent;
    FOnProgress: TfrProgressEvent;
    FOnFunction: TFunctionEvent;
    FOnBeginColumn: TBeginColumnEvent;
    FOnPrintColumn: TPrintColumnEvent;
    FOnManualBuild: TManualBuildEvent;
    FCurrentFilter: TfrExportFilter;
    FPageNumbers  : String;
    FCopies       : Integer;
//    FCurPage      : TfrPage;
    
//    FDefaultTitle : String;
    FTitle        : String;
    FSubject      : string;
    FKeyWords     : string;
    FComments     : TStringList;
    FDFMStream    : TStream;
    FXMLReport    : string;
    fDefExportFilterClass: string;
    fDefExportFileName: string;


    procedure OnGetParsFunction(const aName: String; p1, p2, p3: Variant;
                                var val: Variant);
    function DoInterpFunction(const aName: String; p1, p2, p3: Variant;
                         var val: Variant):boolean;
    procedure PrepareDataSets;
    procedure BuildBeforeModal(Sender: TObject);
    procedure ExportBeforeModal(Sender: TObject);
    procedure PrintBeforeModal(Sender: TObject);
    function DoPrepareReport: Boolean;
    procedure DoBuildReport; virtual;
    procedure DoPrintReport(const PageNumbers: String; Copies: Integer);
    procedure SetComments(const AValue: TStringList);
    procedure SetPrinterTo(const PrnName: String);
    procedure SetReportOptions(AValue: TfrReportOptions);
    procedure SetScript(AValue: TfrScriptStrings);
    procedure SetVars(Value: TStrings);
    procedure ClearAttribs;
    function FindObjectByName(AName: string): TfrObject;
    procedure ExecScript;
    procedure CheckFileExists(FName: string);
  protected
    function DoObjectClick(AObj:TfrView):boolean;
    procedure DoBeginBand(Band: TfrBand); virtual;
    procedure DoBeginColumn(Band: TfrBand); virtual;
    procedure DoBeginDoc; virtual;
    procedure DoBeginPage(pgNo: Integer); virtual;
    procedure DoEndBand(Band: TfrBand); virtual;
    procedure DoEndDoc; virtual;
    procedure DoEndPage(pgNo: Integer); virtual;
    procedure DoEnterRect(Memo: TStringList; View: TfrView); virtual;
    procedure DoGetValue(const ParName: String; var ParValue: Variant); virtual;
    procedure DoPrintColumn(ColNo: Integer; var Width: Integer); virtual;
    procedure DoUserFunction(const AName: String; p1, p2, p3: Variant; var Val: Variant); virtual;
    procedure DefineProperties(Filer: TFiler); override;
    procedure ReadBinaryData(Stream: TStream);
    procedure ReadStoreInDFM(Reader: TReader);
    procedure ReadReportXML(Reader: TReader);
    procedure WriteReportXML(Writer: TWriter);
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
    procedure Loaded; override;
  public
    CanRebuild                : Boolean;            // true, if report can be rebuilded
    Terminated                : Boolean;
    PrintToDefault, DoublePass: WordBool;
    FinalPass                 : Boolean;
    FileName                  : String;
    ExportFilename            : string;   // filename used when exporting a report

    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure Clear;
    // service methods
    function FormatValue(V: Variant; AFormat: Integer; const AFormatStr: String): String;
    function FindVariable(Variable: String): Integer;
    procedure GetVariableValue(const s: String; var aValue: Variant);
    procedure GetVarList(CatNo: Integer; List: TStrings);
    procedure GetIntrpValue(const AName: String; var AValue: Variant);
    procedure GetCategoryList(List: TStrings);
    function FindObject(const aName: String): TfrObject;
    // internal events used through report building
    procedure InternalOnEnterRect(Memo: TStringList; View: TfrView);
    procedure InternalOnExportData(View: TfrView);
    procedure InternalOnExportText(x, y: Integer; const text: String; View: TfrView);
    procedure InternalOnExported(View: TfrView);
    procedure InternalOnGetValue(ParName: String; var ParValue: String);
    procedure InternalOnProgress(Percent: Integer);
    procedure FillQueryParams;
    // load/save methods
    procedure LoadFromStream(Stream: TStream);
    procedure LoadFromXML(XML: TLrXMLConfig; const Path: String);
    procedure SaveToStream(Stream: TStream);
    procedure LoadFromFile(const FName: String);
    procedure LoadFromXMLFile(const Fname: String);
    procedure LoadFromXMLStream(const Stream: TStream);
    procedure SaveToFile(FName: String);
    procedure SavetoXML(XML: TLrXMLConfig; const Path: String);
    procedure SaveToXMLFile(const FName: String);
    procedure SaveToXMLStream(const Stream: TStream);

    procedure LoadFromDB(Table: TDataSet; DocN: Integer);
    procedure SaveToDB(Table: TDataSet; DocN: Integer);

    procedure LoadTemplate(const fname: String; comm: TStrings;
      Bmp: TBitmap; Load: Boolean);
    procedure LoadTemplateXML(const fname: String; comm: TStrings;
      Bmp: TBitmap; Load: Boolean);
    procedure SaveTemplate(const fname: String; comm: TStrings; Bmp: TBitmap);
    procedure SaveTemplateXML(const fname: String; Desc: TStrings; Bmp: TBitmap);
    procedure LoadPreparedReport(const FName: String);
    procedure SavePreparedReport(const FName: String);
    // report manipulation methods
    function DesignReport: Integer;
    function PrepareReport: Boolean;
    function ExportTo(FilterClass: TfrExportFilterClass; aFileName: String):Boolean; overload;
    function ExportTo(FilterClass: TfrExportFilterClass; exportStream: TStream; freeStream:boolean=false): boolean; overload;
    procedure ShowReport;
    procedure ShowPreparedReport;
    procedure PrintPreparedReport(const PageNumbers: String; Copies: Integer);
    function ChangePrinter(OldIndex, NewIndex: Integer): Boolean;
    procedure EditPreparedReport(PageIndex: Integer);
    //
    property Subject : string read FSubject write FSubject;
    property KeyWords : string read FKeyWords write FKeyWords;
    property Comments : TStringList read FComments write SetComments;
    property ReportAutor : string read FReportAutor write FReportAutor;
    property ReportVersionMajor : string read FReportVersionMajor write FReportVersionMajor;
    property ReportVersionMinor : string read FReportVersionMinor write FReportVersionMinor;
    property ReportVersionRelease : string read FReportVersionRelease write FReportVersionRelease;
    property ReportVersionBuild : string read FReportVersionBuild write FReportVersionBuild;
    property ReportCreateDate : TDateTime read FReportCreateDate write FReportCreateDate;
    property ReportLastChange : TDateTime read FReportLastChange write FReportLastChange;
    //
    property Pages: TfrPages read FPages;
    property EMFPages: TfrEMFPages read FEMFPages write FEMFPages;
    property Variables: TStrings read FVars write SetVars;
    property Values: TfrValues read FVal write FVal;
    property Script : TfrScriptStrings read FScript write SetScript;
    //
    property DefExportFilterClass: string read fDefExportFilterClass write fDefExportFilterClass;
    property DefExportFileName: string read fDefExportFileName write fDefExportFileName;

    property DefaultCollate : boolean read FDefaultCollate write FDefaultCollate;

    property DetailReports:TlrDetailReports read FDetailReports;
  published
    property Dataset: TfrDataset read FDataset write FDataset;
    property DefaultCopies: Integer read FDefaultCopies write FDefaultCopies default 1;
    property GrayedButtons: Boolean read FGrayedButtons write FGrayedButtons default False;
    property InitialZoom: TfrPreviewZoom read FInitialZoom write FInitialZoom;
    property ModalPreview: Boolean read FModalPreview write FModalPreview default True;
    property ModifyPrepared: Boolean read FModifyPrepared write FModifyPrepared default True;
    property Options: TfrReportOptions read FReportOptions write SetReportOptions;
    property Preview: TfrPreview read FPreview write FPreview;
    property PreviewButtons: TfrPreviewButtons read FPreviewButtons write FPreviewButtons;
    property RebuildPrinter: boolean read FRebuildPrinter write FRebuildPrinter default False;
    property ReportType: TfrReportType read FReportType write FReportType default rtSimple;
    property ShowProgress: Boolean read FShowProgress write FShowProgress default True;
    property StoreInForm: Boolean read FStoreInForm write FStoreInForm default False;
    property DataType : TfrDataType read FDataType write FDataType;

    property Title: String read FTitle write FTitle;

    property OnBeginDoc: TBeginDocEvent read FOnBeginDoc write FOnBeginDoc;
    property OnEndDoc: TEndDocEvent read FOnEndDoc write FOnEndDoc;
    property OnBeginPage: TBeginPageEvent read FOnBeginPage write FOnBeginPage;
    property OnEndPage: TEndPageEvent read FOnEndPage write FOnEndPage;
    property OnBeginBand: TBeginBandEvent read FOnBeginBand write FOnBeginBand;
    property OnEndBand: TEndBandEvent read FOnEndBand write FOnEndBand;
    property OnGetValue: TDetailEvent read FOnGetValue write FOnGetValue;
    property OnEnterRect: TEnterRectEvent read FOnEnterRect write FOnEnterRect;
    property OnUserFunction: TFunctionEvent read FOnFunction write FOnFunction;
    property OnProgress: TfrProgressEvent read FOnProgress write FOnProgress;
    property OnBeginColumn: TBeginColumnEvent read FOnBeginColumn write FOnBeginColumn;
    property OnPrintColumn: TPrintColumnEvent read FOnPrintColumn write FOnPrintColumn;
    property OnManualBuild: TManualBuildEvent read FOnManualBuild write FOnManualBuild;
    property OnExportFilterSetup: TExportFilterSetup read FOnExportFilterSetup write FOnExportFilterSetup;
    property OnBeforePrint: TPrintReportEvent read FOnBeforePrint write FOnBeforePrint;
    property OnAfterPrint: TPrintReportEvent read FOnAfterPrint write FOnAfterPrint;
    // If wanted, you can use your own handler to determine the graphic class of the image
    property OnDBImageRead: TOnDBImageRead read FOnDBImageRead write FOnDBImageRead;
    property OnObjectClick: TObjectClickEvent read FObjectClick write FObjectClick;
    property OnMouseOverObject: TMouseOverObjectEvent read FMouseOverObject write FMouseOverObject;
    property OnFormPageBookmarks: TFormPageBookmarksEvent read fOnFormPageBookmarks write fOnFormPageBookmarks;
    property OnBeforePreview : TBeforePreviewFormEvent read  fOnBeforePreview write fOnBeforePreview;
  end;

  TfrCompositeReport = class(TfrReport)
  private
    procedure DoBuildReport; override;
  public
    Reports: TFpList;
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  end;

  { TfrReportDesigner }

  TfrReportDesigner = class(TForm)
  private
    FModified: Boolean;
  protected
    procedure SetModified(AValue: Boolean);virtual;
  public
    Page: TfrPage;
    PreparedReportEditor:boolean;
    procedure {%H-}RegisterObject(ButtonBmp: TBitmap; const ButtonHint: String;
      ButtonTag: Integer; ObjectType:TfrObjectType); virtual; abstract;
    procedure {%H-}RegisterTool(const MenuCaption: String; ButtonBmp: TBitmap;
      NotifyOnClick: TNotifyEvent); virtual; abstract;
    procedure {%H-}BeforeChange; virtual; abstract;
    procedure {%H-}AfterChange; virtual; abstract;
    procedure {%H-}RedrawPage; virtual; abstract;
    //
    function {%H-}PointsToUnits(x: Integer): Double;  virtual; abstract;
    function {%H-}UnitsToPoints(x: Double): Integer;  virtual; abstract;
    property Modified: Boolean read FModified write SetModified;
  end;

  TfrDataManager = class(TObject)
  public
    procedure Clear; virtual; abstract;
    procedure LoadFromStream(Stream: TStream); virtual; abstract;
    procedure LoadFromXML(XML:TLrXMLConfig; const Path: String); virtual; abstract;
    procedure SaveToStream(Stream: TStream); virtual; abstract;
    procedure SaveToXML(XML:TLrXMLConfig; const Path: String); virtual; abstract;
    procedure BeforePreparing; virtual; abstract;
    procedure AfterPreparing; virtual; abstract;
    procedure PrepareDataSet(ds: TfrTDataSet); virtual; abstract;
    function ShowParamsDialog: Boolean; virtual; abstract;
    procedure AfterParamsDialog; virtual; abstract;
  end;

  TfrObjEditorForm = class(TForm)
  public
    procedure ShowEditor({%H-}t: TfrView); virtual;
  end;

  TlrObjEditorProc = function(lrObj: TfrView) : boolean;


  TfrFunctionDescription = class(TObject)
    funName:string;
    funGroup:string;
    funDescription:string;
  end;
  
  { TfrFunctionLibrary }

  TfrFunctionLibrary = class(TObject)
  private
    List, Extra: TStringList;
    function GetCount: integer;
    function GetDescription(AIndex: Integer): TfrFunctionDescription;
  public
    constructor Create; virtual;
    destructor Destroy; override;
    function OnFunction(const FName: String; p1, p2, p3: Variant;
      var val: Variant): Boolean;
    procedure {%H-}DoFunction(FNo: Integer; p1, p2, p3: Variant; var val: Variant);
      virtual; abstract;
    procedure UpdateDescriptions; virtual;
    procedure Add(const funName:string; IsExtra:boolean=false);
    procedure AddFunctionDesc(const funName, funGroup, funDescription:string);
    property FunctionCount:integer read GetCount;
    property Description[AIndex:Integer]:TfrFunctionDescription read GetDescription;
  end;

  TfrCompressor = class(TObject)
  public
    Enabled: Boolean;
    procedure Compress({%H-}StreamIn, {%H-}StreamOut: TStream); virtual;
    procedure DeCompress({%H-}StreamIn, {%H-}StreamOut: TStream); virtual;
  end;

  TfrAddinInitProc = procedure;

  {$IFDEF LCLNOGUI}
  TLazreportBitmap = TVirtualBitmap;
  {$ELSE}
  TLazreportBitmap = TBitmap;
  {$ENDIF}

function frCreateObject(Typ: Byte; const ClassName: String; AOwnerPage:TfrPage): TfrView;
procedure frRegisterObject(ClassRef: TFRViewClass; ButtonBmp: TBitmap;
  const ButtonHint: String; EditorForm: TfrObjEditorForm; ObjectType:TfrObjectType;
  InitProc:TfrAddinInitProc; EditorProc : TlrObjEditorProc = nil);

procedure frRegisterObject(ClassRef: TFRViewClass; ButtonBmp: TBitmap;
  const ButtonHint: String; EditorForm: TfrObjEditorForm; InitProc:TfrAddinInitProc=nil);

procedure frSetAddinEditor(ClassRef: TfrViewClass; EditorForm: TfrObjEditorForm);
procedure frSetAddinIcon(ClassRef: TfrViewClass; ButtonBmp: TBitmap);
procedure frSetAddinHint(ClassRef: TfrViewClass; ButtonHint: string);
procedure frRegisterExportFilter(ClassRef: TfrExportFilterClass;
  const FilterDesc, FilterExt: String);
procedure frRegisterFunctionLibrary(ClassRef: TClass);
procedure frRegisterTool(const MenuCaption: String; ButtonBmp: TBitmap; OnClick: TNotifyEvent);
function GetDefaultDataSet: TfrTDataSet;
procedure SetBit(var w: Word; e: Boolean; m: Integer);
function frGetBandName(BandType: TfrBandType): string;
procedure frSelectHyphenDictionary(ADict: string);
function FindObjectProps(AObjStr:string; out frObj:TfrObject; out PropName:string;
  out PropIndex:Integer):PPropInfo;

const
  lrTemplatePath = 'LazReportTemplate/';
  frCurrentVersion = 31;
    // version 2.5: lazreport: added to binary stream ParentBandType variable
    //                         on TfrView, used to extend export facilities
    // version 2.6: lazreport: added to binary stream Tag property on TfrView
    // version 2.7: lazreport: added to binary stream FOnClick, FOnMouseEnter, FOnMouseLeave, FCursor property on TfrMemoView
    // version 2.8: lazreport: added support for child bands
    // version 2.9: lazreport: added support LineSpacing and GapX, GapY
    // version 3.0: lazreport: decoupled flHideZeros and flBandPrintChildIfNotVisible
    // version 3.1: lazreport: Save Restrictions to stream


  frSpecCount = 9;
  frSpecFuncs: Array[0..frSpecCount - 1] of String = ('PAGE#', '',
    'DATE', 'TIME', 'LINE#', 'LINETHROUGH#', 'COLUMN#', 'CURRENT#', 'TOTALPAGES');

  frAllFrames=[frbLeft, frbTop, frbRight, frbBottom];

  frUnwrapRead: boolean = false; // TODO: remove this for 0.9.28
  
type
  PfrTextRec = ^TfrTextRec;
  TfrTextRec = record
    Next: PfrTextRec;
    X: Integer;
    W: Integer;
    Text: string;
    FontName: String[32];
    FontSize, FontStyle, FontColor, FontCharset, FillColor: Integer;
    Alignment: TAlignment;
    Borders: TfrFrameBorders;
    BorderColor: TColor;
    BorderStyle: TfrFrameStyle;
    BorderWidth: Integer;
    Typ: Byte;
  end;

  TfrAddInObjectInfo = record
    ClassRef: TfrViewClass;
    EditorForm: TfrObjEditorForm;
    ButtonBmp: TBitmap;
    ButtonHint: String;
    InitializeProc: TfrAddinInitProc;
    ObjectType:TfrObjectType;
    EditorProc : TlrObjEditorProc;
  end;

  { TExportFilterItem }

  TExportFilterItem = class
  private
    FClassRef: TfrExportFilterClass;
    FEnabled: boolean;
    FFilterDesc: String;
    FFilterExt: String;
  public
    constructor Create;
    property ClassRef: TfrExportFilterClass read FClassRef;
    property FilterDesc: String read FFilterDesc;
    property FilterExt: String read FFilterExt;
    property Enabled:boolean read FEnabled write FEnabled;
  end;

  { TExportFilters }

  TExportFilters = class
  private
    FList:TFPList;
    function GetCount: integer;
    procedure Clear;
    function GetItems(AItem: Integer): TExportFilterItem;
  public
    constructor Create;
    destructor Destroy; override;
    procedure RegisterFilter(AClassRef: TfrExportFilterClass; const AFilterDesc, AFilterExt: String);
    procedure DisableFilter(AFilterExt: String);
    procedure EnableFilter(AFilterExt: String);
    function FindFilter(AFilterExt: String):TExportFilterItem;
    function FilterIndex(AClassRef: TfrExportFilterClass; AFilterExt:string): Integer;
    property Count:integer read GetCount;
    property Items[AItem:Integer]:TExportFilterItem read GetItems;default;
  end;


  TfrFunctionInfo = record
    FunctionLibrary: TfrFunctionLibrary;
  end;

  TfrToolsInfo = record
    Caption: String;
    ButtonBmp: TBitmap;
    OnClick: TNotifyEvent;
  end;

var
  frDesigner: TfrReportDesigner;                  // designer reference
  frDataManager: TfrDataManager;                  // data manager reference
  frParser: TfrParser;                            // parser reference
  frInterpretator: TfrInterpretator;              // interpretator reference
  frVariables: TfrVariables;                      // report variables reference
  frCompressor: TfrCompressor;                    // compressor reference
  CurReport: TfrReport;                           // currently proceeded report
  MasterReport: TfrReport;                        // reference to main composite report
  CurView: TfrView;                               // currently proceeded view
  CurBand: TfrBand;                               // currently proceeded band
  CurPage: TfrPage;                               // currently proceeded page
  DocMode: (dmDesigning, dmPrinting);             // current mode
  DisableDrawing: Boolean;
  frAddIns: Array[0..31] of TfrAddInObjectInfo;   // add-in objects
  frAddInsCount: Integer;
  frFunctions: Array[0..31] of TfrFunctionInfo;   // function libraries
  frFunctionsCount: Integer;
  frTools: Array[0..31] of TfrToolsInfo;          // tools
  frToolsCount: Integer;
  PageNo: Integer;                                // current page number in Building mode
  frCharset: 0..255;
  frBandNames: Array[btReportTitle..btNone] of String;
  frSpecArr: Array[0..frSpecCount - 1] of String;
  frDateFormats, frTimeFormats: Array[0..3] of String;
  frVersion: Byte;                       // version of currently loaded report
  SMemo: TStringList;          // temporary memo used during TfrView drawing
  ShowBandTitles: Boolean = True;
  ProcedureInitDesigner : Procedure = nil;
  
(*
  FRE_COMPATIBLEREAD variable added for migrating from older versions 
  of FreeReport and will be removed in next releases as soon as possible.
*)
{$IFDEF FREEREP2217READ}
  FRE_COMPATIBLE_READ: Boolean = False;
{$ENDIF}
  LRE_OLDV25_FRF_READ: Boolean = False;  // read broken frf v25 reports, bug 25037
  LRE_OLDV28_FRF_READ: Boolean = False;  // read frf v28 (lazarus 1.4.4) reports, bug 29966

  // variables used through report building
  TempBmp: TLazreportBitmap;                    // temporary bitmap used by TfrMemoView

function ExportFilters:TExportFilters;
implementation

uses
  LR_Fmted, LR_Prntr, LR_Progr, LR_Utils
  {$IFDEF JPEG}, JPEG {$ENDIF}, lr_hyphen;

type

  { TfrStdFunctionLibrary }

  TfrStdFunctionLibrary = class(TfrFunctionLibrary)
  public
    constructor Create; override;
    procedure UpdateDescriptions; override;
    procedure DoFunction(FNo: Integer; p1, p2, p3: Variant; var val: Variant); override;
  end;

  { TInterpretator }

  TInterpretator = class(TfrInterpretator)
  protected
  public
    procedure GetValue(const Name: String; var Value: Variant); override;
    procedure SetValue(const Name: String; Value: Variant); override;
    procedure DoFunction(const name: String; p1, p2, p3: Variant;
                         var val: Variant); override;
  end;


var
  VHeight: Integer;            // used for height calculation of TfrMemoView
  SBmp: TBitmap;               // small bitmap used by TfrBandView drawing
  CurDate, CurTime: TDateTime; // date/time of report starting
  CurValue: Variant;           // used for highlighting
  AggrBand: TfrBand = nil;           // used for aggregate functions
  CurVariable: String;
  IsColumns: Boolean;
  SavedAllPages: Integer;      // number of pages in entire report
  ErrorFlag: Boolean;          // error occurred through TfrView drawing
  ErrorStr: String;            // error description
  SubValue: String;            // used in GetValue event handler
  ObjID: Integer = 0;
  BoolStr: Array[0..3] of String;
  HookList: TFpList;
  FRInitialized: Boolean = False;
  FHyp: THyphen = nil;
  PrevY, PrevBottomY, ColumnXAdjust: Integer;
  AppendPage, WasPF: Boolean;
  CompositeMode: Boolean;
  MaxTitleSize: Integer = 0;
  FExportFilters:TExportFilters = nil;


  {-----------------------------------------------------------------------------}
const
  PropCount = 6;
  PropNames: Array[0..PropCount - 1] of String =
      ('Text','FontName', 'FontSize', 'FontStyle', 'FontColor', 'Adjust');

{$IFDEF DebugLR}
function Bandtyp2str(typ: TfrBandType): string;
begin
  WriteStr(Result, typ);
end;

function DbgDset(ds: TfrDataset): string;
begin
  if ds=nil then
    result := 'nil'
  else
    result := dbgsName(ds);
end;

function BandInfo(Band: TfrBand): string;
begin
  result := format('"%s":%s typ=%s ds=%s',[Band.Name, dbgsname(band), BandTyp2str(Band.typ), dbgDset(Band.DataSet)]);
end;

function ViewInfo(View: TfrView): string;
begin
  if View=nil then
    result := 'View is nil'
  else
    result := format('"%s":%s typ=%s',[View.Name, dbgsname(View), frTypeObjectToStr(View.Typ)]);
end;

function ViewInfoDim(View: TfrView): string;
begin
  with View do
  result := sysutils.format('"%s":%s typ=%s DIM:%d %d %d %d',
    [Name, dbgsname(View), frTypeObjectToStr(Typ), x, y, dx, dy]);
end;

function VarStr(V:Variant): string;
begin
  if VarIsNull(v) then
    result := '{null}'
  else
  if VarIsEmpty(v) then
    result := '{empty}'
  else begin
    if VarIsStr(v) then
      result := quotedstr(v)
    else
      result := v;
  end;
end;

{$ENDIF}

function IsCustomProp(const aPropName: string; out aIndex: Integer): boolean;
var
  i: Integer;
begin
  result := false;
  aIndex := -1;
  for i:=0 to High(PropNames) do
  begin
    if SameText(aPropName, PropNames[i]) then
    begin
      aIndex := i;
      result := true;
      break;
    end;
  end;
end;

function FindObjectProps(AObjStr:string; out frObj:TfrObject; out PropName:string;
  out PropIndex: Integer):PPropInfo;
var
  FPageName:string;
  FObjName:string;

  P:integer;
  FPage:TfrPage;
begin
  Result:=nil;
  frObj:=nil;
  PropName:='';
  PropIndex:=-1;

  P:=Pos('.', AObjStr);
  if (P = 0) then
  begin
    if Assigned(CurView) then
    begin
      Result:=GetPropInfo(CurView, AObjStr); //Retreive property informations
      if Assigned(Result) or IsCustomProp(aObjStr, PropIndex) then
      begin
        frObj:=CurView;
        PropName:=AObjStr;
      end;
    end;
  end
  else
  begin
    FPageName:='';
    FObjName:='';

    FObjName:=Copy2SymbDel(AObjStr, '.');

    P:=Pos('.', AObjStr);
    if P <> 0 then
    begin
      FPageName:=FObjName;
      FObjName:=Copy2SymbDel(AObjStr, '.');
    end;
    PropName:=AObjStr;


    if FPageName<>'' then
    begin
      FPage:=CurReport.Pages.PageByName(FPageName);
      if not Assigned(FPage) then
        exit;
    end
    else
    begin
      FPage:=CurPage;
    end;

    if Assigned(FPage) then
      frObj := FPage.FindRTObject(FObjName);
    if not Assigned(frObj) then
      frObj := CurReport.FindObject(FObjName);

    if Assigned(frObj) then
    begin
      Result:=GetPropInfo(frObj, PropName); //Retreive property informations
      if not Assigned(Result) then
        IsCustomProp(PropName, PropIndex);
    end;

  end;
end;

function ExportFilters: TExportFilters;
begin
  if not Assigned(FExportFilters) then
    FExportFilters:=TExportFilters.Create;
  Result:=FExportFilters;
end;

function DoFindObjMetod(S: string; out AObjProp: string
  ): TfrObject;
begin
  Result:=nil;
  if Assigned(CurReport) and (Pos('.', S)>0) then
  begin
    AObjProp:=S;
    Result:=CurReport.FindObject(Copy2SymbDel(AObjProp, '.'));
  end;
end;

procedure UpdateLibraryDescriptions;
var
  i: integer;
begin
  for i:=0 to frFunctionsCount-1 do
    frFunctions[i].FunctionLibrary.UpdateDescriptions;
end;

procedure UpdateObjectStringResources;
begin
  frCharset := StrToInt(sCharset);

  frBandNames[btReportTitle] := sBand1;
  frBandNames[btReportSummary] := sBand2;
  frBandNames[btPageHeader] := sBand3;
  frBandNames[btPageFooter] := sBand4;
  frBandNames[btMasterHeader] := sBand5;
  frBandNames[btMasterData] := sBand6;
  frBandNames[btMasterFooter] := sBand7;
  frBandNames[btDetailHeader] := sBand8;
  frBandNames[btDetailData] := sBand9;
  frBandNames[btDetailFooter] := sBand10;
  frBandNames[btSubDetailHeader] := sBand11;
  frBandNames[btSubDetailData] := sBand12;
  frBandNames[btSubDetailFooter] := sBand13;
  frBandNames[btOverlay] := sBand14;
  frBandNames[btColumnHeader] := sBand15;
  frBandNames[btColumnFooter] := sBand16;
  frBandNames[btGroupHeader] := sBand17;
  frBandNames[btGroupFooter] := sBand18;
  frBandNames[btCrossHeader] := sBand19;
  frBandNames[btCrossData] := sBand20;
  frBandNames[btCrossFooter] := sBand21;
  frBandNames[btChild] := sBand22;
  frBandNames[btNone] := sBand23;

  frSpecArr[0] := sVar1;
  frSpecArr[1] := sVar2;
  frSpecArr[2] := sVar3;
  frSpecArr[3] := sVar4;
  frSpecArr[4] := sVar5;
  frSpecArr[5] := sVar6;
  frSpecArr[6] := sVar7;
  frSpecArr[7] := sVar8;
  frSpecArr[8] := sVar9;

  BoolStr[0] :=SFormat51;
  BoolStr[1] :=SFormat52;
  BoolStr[2] :=SFormat53;
  BoolStr[3] :=SFormat54;

  frDateFormats[0] :=sDateFormat1;
  frDateFormats[1] :=sDateFormat2;
  frDateFormats[2] :=sDateFormat3;
  frDateFormats[3] :=sDateFormat4;

  frTimeFormats[0] :=sTimeFormat1;
  frTimeFormats[1] :=sTimeFormat2;
  frTimeFormats[2] :=sTimeFormat3;
  frTimeFormats[3] :=sTimeFormat4;

  UpdateLibraryDescriptions;
end;

{----------------------------------------------------------------------------}
function frCreateObject(Typ: Byte; const ClassName: String; AOwnerPage:TfrPage): TfrView;
var
  i: Integer;
begin
  Result := nil;
  case Typ of
    gtMemo:      Result := TfrMemoView.Create(AOwnerPage);
    gtPicture:   Result := TfrPictureView.Create(AOwnerPage);
    gtBand:      Result := TfrBandView.Create(AOwnerPage);
    gtSubReport: Result := TfrSubReportView.Create(AOwnerPage);
    gtLine:      Result := TfrLineView.Create(AOwnerPage);
    gtAddIn:
      begin
        for i := 0 to frAddInsCount - 1 do
        begin
          {$IFDEF DebugLR}
          DebugLn('frCreateObject classname compare %s=%s',[frAddIns[i].ClassRef.ClassName,ClassName]);
          {$ENDIF}

          if CompareText(frAddIns[i].ClassRef.ClassName, ClassName)=0 then
          begin
            Result := frAddIns[i].ClassRef.Create(AOwnerPage);
//            Result.Create;
            Result.Typ := gtAddIn;
            break;
          end;
        end;
        if Result = nil then
          raise EClassNotFound.Create(Format(sClassObjectNotFound,[ClassName]));
      end;
  end;
  
  if Result <> nil then
  begin
    {$IFDEF DebugLR}
    DebugLn('frCreateObject instance classname=%s',[ClassName]);
    {$ENDIF}

    Result.ID := ObjID;
    Inc(ObjID);
    Result.AfterCreate;
  end;
end;

procedure frRegisterObject(ClassRef: TFRViewClass; ButtonBmp: TBitmap;
  const ButtonHint: String; EditorForm: TfrObjEditorForm;
  ObjectType: TfrObjectType; InitProc: TfrAddinInitProc;
  EditorProc: TlrObjEditorProc = nil);
begin
  frAddIns[frAddInsCount].ClassRef := ClassRef;
  frAddIns[frAddInsCount].EditorForm := EditorForm;
  frAddIns[frAddInsCount].ButtonBmp := ButtonBmp;
  frAddIns[frAddInsCount].ButtonHint := ButtonHint;
  frAddIns[frAddInsCount].InitializeProc := InitProc;
  frAddIns[frAddInsCount].ObjectType:=ObjectType;
  frAddIns[frAddInsCount].EditorProc:= EditorProc;
  if frDesigner <> nil then begin
    if Assigned(InitProc) then
      InitProc;
    frDesigner.RegisterObject(ButtonBmp, ButtonHint,
      Integer(gtAddIn) + frAddInsCount, ObjectType);
  end;
  Inc(frAddInsCount);
end;

procedure frRegisterObject(ClassRef: TFRViewClass; ButtonBmp: TBitmap;
  const ButtonHint: String; EditorForm: TfrObjEditorForm;
  InitProc: TfrAddinInitProc);
begin
  frRegisterObject(ClassRef, ButtonBmp, ButtonHint, EditorForm, otlReportView, InitProc);
end;

function frGetAddinIndex(ClassRef: TfrViewClass): Integer;
var
  i: Integer;
begin
  result := -1;
  for i:=0 to frAddinsCount-1 do
    if frAddIns[i].ClassRef = ClassRef then
    begin
      result := i;
      break;
    end;
end;

procedure frSetAddinEditor(ClassRef: TfrViewClass; EditorForm: TfrObjEditorForm);
var
  i: Integer;
begin
  i := frGetAddinIndex(ClassRef);
  if i>=0 then
    frAddins[i].EditorForm := EditorForm
  else
    raise Exception.CreateFmt(sClassObjectNotFound,[Classref.ClassName]);
end;

procedure frSetAddinIcon(ClassRef: TfrViewClass; ButtonBmp: TBitmap);
var
  i: Integer;
begin
  i := frGetAddinIndex(ClassRef);
  if i>=0 then
    frAddins[i].ButtonBmp := ButtonBmp
  else
    raise Exception.CreateFmt(sClassObjectNotFound,[Classref.ClassName]);
end;

procedure frSetAddinHint(ClassRef: TfrViewClass; ButtonHint: string);
var
  i: Integer;
begin
  i := frGetAddinIndex(ClassRef);
  if i>=0 then
    frAddins[i].ButtonHint := ButtonHint
  else
    raise Exception.CreateFmt(sClassObjectNotFound,[Classref.ClassName]);
end;

procedure frRegisterExportFilter(ClassRef: TfrExportFilterClass;
  const FilterDesc, FilterExt: String);
begin
  ExportFilters.RegisterFilter(ClassRef,  FilterDesc, FilterExt);
end;

procedure frRegisterFunctionLibrary(ClassRef: TClass);
begin
  frFunctions[frFunctionsCount].FunctionLibrary :=
    TfrFunctionLibrary(ClassRef.NewInstance);
  frFunctions[frFunctionsCount].FunctionLibrary.Create;
  Inc(frFunctionsCount);
end;

procedure frRegisterTool(const MenuCaption: String; ButtonBmp: TBitmap; OnClick: TNotifyEvent);
begin
  frTools[frToolsCount].Caption := MenuCaption;
  frTools[frToolsCount].ButtonBmp := ButtonBmp;
  frTools[frToolsCount].OnClick := OnClick;
  if frDesigner <> nil then
    frDesigner.RegisterTool(MenuCaption, ButtonBmp, OnClick);
  Inc(frToolsCount);
end;

function Create90Font(Font: TFont): HFont;
var
  F: TLogFont;
begin
  GetObject(Font.Handle, SizeOf(TLogFont), @F);
  F.lfEscapement := 900;
  F.lfOrientation := 900;
  Result := CreateFontIndirect(F);
end;

function GetDefaultDataSet: TfrTDataSet;
var
  FRDataset: TfrDataset;
begin
  Result := nil;
  if CurPage is TfrPageReport then
  begin
    FRDataset := nil;
    if CurBand <> nil then
    begin
      case CurBand.Typ of
        btMasterData, btReportSummary, btMasterFooter,
        btGroupHeader, btGroupFooter:
          if Assigned(CurPage.Bands[btMasterData]) then
            FRDataset := CurPage.Bands[btMasterData].DataSet
          else
            FRDataset := nil;
        btDetailData, btDetailFooter:
          if Assigned(CurPage.Bands[btDetailData]) then
            FRDataset := CurPage.Bands[btDetailData].DataSet
          else
            FRDataset := nil;
        btSubDetailData, btSubDetailFooter:
          if Assigned(CurPage.Bands[btSubDetailData]) then
            FRDataset := CurPage.Bands[btSubDetailData].DataSet
          else
            FRDataset := nil;
        btCrossData, btCrossFooter:
          if Assigned(CurPage.Bands[btCrossData]) then
            FRDataset := CurPage.Bands[btCrossData].DataSet
          else
            FRDataset := nil;
      end;
    end;
    if FRDataset is TfrDBDataset then
      Result := TfrDBDataSet(FRDataset).GetDataSet
  end;
end;

function ReadString(Stream: TStream): String;
begin
  if frVersion >= 23 then
{$IFDEF FREEREP2217READ}
      Result := frReadString(Stream) // load in current format
  else
    if (frVersion = 22) and FRE_COMPATIBLE_READ then
      Result := frReadString2217(Stream) // load in bad format
    else
{$ELSE}
    Result := frReadString(Stream) else
{$ENDIF}
    Result := frReadString22(Stream);
end;

procedure ReadMemo(Stream: TStream; Memo: TStrings);
begin
  if frVersion >= 23 then
{$IFDEF FREEREP2217READ}
      frReadMemo(Stream, Memo) // load in current format
  else
    if (frVersion = 22) and FRE_COMPATIBLE_READ then
      Memo.Text := frReadMemoText2217(Stream) // load in bad format
    else
{$ELSE}
    frReadMemo(Stream, Memo) else
{$ENDIF}
    frReadMemo22(Stream, Memo);
end;

procedure CreateDS(const Desc: String; var DataSet: TfrDataSet; var IsVirtualDS: Boolean);
begin
  if (Desc <> '') and (Desc[1] in ['1'..'9']) then
  begin
    DataSet := TfrUserDataSet.Create(nil);
    DataSet.RangeEnd := reCount;
    DataSet.RangeEndCount := StrToInt(Desc);
    IsVirtualDS := True;
  end
  else
    DataSet := frFindComponent(CurReport.Owner, Desc) as TfrDataSet;
  if DataSet <> nil then
    DataSet.Init;
end;

// locale neutral StrToFloatDef
function StringToFloatDef(const S:String; const ADefault:Double): Double;
var
  Code: Integer;
begin
  if S='' then
    Code:=1
  else
    Val(S, Result, Code);
  if Code>0 then
    Result:=ADefault;
end;

procedure SetBit(var w: Word; e: Boolean; m: Integer);
begin
  if e then
    w:=w or m
  else
    w:=w and not m;
end;

function frGetBandName(BandType: TfrBandType): string;
begin
  result := GetEnumName(TypeInfo(TFrBandType), ord(BandType));
  result := copy(result, 3, Length(result));
end;

procedure frSelectHyphenDictionary(ADict: string);
begin
  if FHyp = nil then
    FHyp := THyphen.create;
  FHyp.Dictionary:=ADict;
  try
    FHyp.BreakWord('lazreport');
  except
    on E:EHyphenationException do
      DebugLn('Error: ', e.message,'. Hyphenation support will be disabled');
  end;
end;

{ TExportFilterItem }

constructor TExportFilterItem.Create;
begin
  inherited Create;
  FEnabled:=true;
end;

{ TExportFilters }

function TExportFilters.GetCount: integer;
begin
  Result:=FList.Count;
end;

procedure TExportFilters.Clear;
var
  i: Integer;
begin
  for i:=0 to FList.Count-1 do
    TExportFilterItem(FList[i]).Free;
  FList.Clear;
end;

function TExportFilters.GetItems(AItem: Integer): TExportFilterItem;
begin
  Result:=TExportFilterItem(FList[AItem]);
end;

constructor TExportFilters.Create;
begin
  inherited Create;
  FList:=TFPList.Create;
end;

destructor TExportFilters.Destroy;
begin
  Clear;
  FList.Free;
  inherited Destroy;
end;

procedure TExportFilters.RegisterFilter(AClassRef: TfrExportFilterClass;
  const AFilterDesc, AFilterExt: String);
var
  F: TExportFilterItem;
begin
  if FilterIndex(AClassRef, AFilterExt) > -1 then exit;
  F:=TExportFilterItem.Create;
  F.FClassRef:=AClassRef;
  F.FFilterExt:=AFilterExt;
  F.FFilterDesc:=AFilterDesc;

  FList.Add(F);
end;

procedure TExportFilters.DisableFilter(AFilterExt: String);
var
  F: TExportFilterItem;
begin
  F:=FindFilter(AFilterExt);
  if Assigned(F) then
    F.FEnabled:=true;
end;

procedure TExportFilters.EnableFilter(AFilterExt: String);
var
  F: TExportFilterItem;
begin
  F:=FindFilter(AFilterExt);
  if Assigned(F) then
    F.FEnabled:=false;
end;

function TExportFilters.FindFilter(AFilterExt: String): TExportFilterItem;
var
  i: Integer;
begin
  Result:=nil;
  AFilterExt:=UTF8UpperCase(AFilterExt);
  for i:=0 to FList.Count-1 do
    if UTF8UpperCase(TExportFilterItem(FList[i]).FFilterExt) = AFilterExt then
    begin
      Result:=TExportFilterItem(FList[i]);
      exit;
    end;
end;

function TExportFilters.FilterIndex(AClassRef: TfrExportFilterClass;
  AFilterExt: string): Integer;
var
  i: Integer;
begin
  Result:=-1;
  AFilterExt:=UTF8UpperCase(AFilterExt);
  for i:=0 to FList.Count-1 do
    if (TExportFilterItem(FList[i]).FClassRef = AClassRef) and
       (UTF8UpperCase(TExportFilterItem(FList[i]).FilterExt) = AFilterExt) then
    begin
      Result:=i;
      exit;
    end;
end;

{
procedure CanvasTextRectJustify(const Canvas:TCanvas;
  const ARect: TRect; X1, X2, Y: integer; const Text: string;
  Trimmed: boolean);
var
  WordCount,SpcCount,SpcSize:Integer;
  Arr: TArrUTF8Item;
  PxSpc,RxSpc,Extra: Integer;
  i: Integer;
  Cini,Cend: Integer;
  SpaceWidth, AvailWidth: Integer;
  s:string;
begin

  AvailWidth := (X2-X1);
  // count words
  Arr := UTF8CountWords(Text, WordCount, SpcCount, SpcSize);

  // handle trimmed text
  s := Text;
  if (SpcCount>0) then
  begin
    Cini := 0;
    CEnd := Length(Arr)-1;
    if Trimmed then
    begin
      s := UTF8Trim(Text, [u8tKeepStart]);
      if Arr[CEnd].Space then
      begin
        Dec(CEnd);
        Dec(SpcCount);
      end;
    end;
    AvailWidth := AvailWidth - Canvas.TextWidth(s);
  end;

  // check if long way is needed
  if (SpcCount>0) and (AvailWidth>0) then
  begin

    SpaceWidth := Canvas.TextWidth(' ');
    PxSpc := AvailWidth div SpcCount;
    RxSpc := AvailWidth mod SpcCount;
    if PxSPC=0 then
    begin
      PxSPC := 1;
      RxSpc := 0;
    end;

    for i:=CIni to CEnd do
      if Arr[i].Space then
      begin
        X1 := X1 + Arr[i].Count * SpaceWidth;
        if AvailWidth>0 then
        begin
          Extra := PxSpc;
          if RxSpc>0 then
          begin
            Inc(Extra);
            Dec(RxSpc);
          end;
          X1 := X1 + Extra;
          Dec(AvailWidth, Extra);
        end;
      end
      else
      begin
        s := Copy(Text, Arr[i].Index, Arr[i].Count);
        Canvas.TextRect(ARect, X1, Y, s);
        X1 := X1 + Canvas.TextWidth(s);
      end;

  end else
    Canvas.TextRect(ARect, X1, Y, s);

  SetLength(Arr, 0);
end;
}
{ TlrDetailReports }

function TlrDetailReports.GetItems(AReportName: string): TlrDetailReport;
var
  i: Integer;
begin
  Result:=nil;
  if Trim(AReportName) = '' then exit;
  for i:=0 to FList.Count - 1 do
    if TlrDetailReport(FList[i]).FReportName = AReportName then
    begin;
      Result:=TlrDetailReport(FList[i]);
      exit
    end;
end;

function TlrDetailReports.GetCount: integer;
begin
  Result:=FList.Count;
end;

function TlrDetailReports.Add(AReportName: string): TlrDetailReport;
begin
  if AReportName <> '' then
    Result:=GetItems(AReportName)
  else
    Result:=nil;
  if not Assigned(Result) then
  begin
    Result:=TlrDetailReport.Create;
    FList.Add(Result);
    Result.FReportName:=AReportName;
  end;
end;

procedure TlrDetailReports.Clear;
var
  P:TlrDetailReport;
  i: Integer;
begin
  for i:=0 to FList.Count - 1 do
  begin
    P:=TlrDetailReport(FList[i]);
    P.Free;
  end;
  FList.Clear;
end;

constructor TlrDetailReports.Create;
begin
  inherited Create;
  FList:=TFPList.Create;
end;

destructor TlrDetailReports.Destroy;
begin
  Clear;
  FreeAndNil(FList);
  inherited Destroy;
end;

procedure TlrDetailReports.LoadFromStream(Stream: TStream);
var
  Cnt, i: Integer;
  P: TlrDetailReport;
begin
  if Stream.Position = Stream.Size then exit;
  Stream.Read(Cnt, SizeOf(Cnt));
  for i:=0 to Cnt - 1 do
  begin
    P:=Add('');
    P.LoadFromStream(Stream);
  end;
end;

procedure TlrDetailReports.LoadFromXML(XML: TLrXMLConfig; const Path: String);
var
  Cnt, i: Integer;
  P:TlrDetailReport;
  S:string;
begin
  Cnt:=XML.GetValue(Path+'Count/Value', 0);
  for i:=0 to Cnt - 1 do
  begin
    S:=XML.GetValue(Path+Format('Detail%d/', [i]) + 'ReportName/Value', '');
    if S <> '' then
    begin
      P:=Add(S);
      P.LoadFromXML(XML, Path + Format('Detail%d/', [i]));
    end;
  end;
end;

procedure TlrDetailReports.SaveToStream(Stream: TStream);
var
  Cnt, i: Integer;
begin
  Cnt:=Count;
  Stream.Write(Cnt, SizeOf(Cnt));
  for i:=0 to Cnt - 1 do
    GetItem(i).SaveToStream(Stream);
end;

procedure TlrDetailReports.SaveToXML(XML: TLrXMLConfig; const Path: String);
var
  i: Integer;
begin
  XML.SetValue(Path+'Count/Value', Count);
  for i:=0 to Count - 1 do
    GetItem(i).SavetoXML(XML, Path+Format('Detail%d/', [i]));
end;

function TlrDetailReports.GetItem(AItem: integer): TlrDetailReport;
begin
  Result:=TlrDetailReport(FList[AItem]);
end;

{ TlrDetailReport }

constructor TlrDetailReport.Create;
begin
  inherited Create;
  {$IF FPC_FULLVERSION >= 30101}
  FReportBody:=TStringStream.CreateRaw('');
  {$ELSE}
  FReportBody:=TStringStream.Create('');
  {$ENDIF}
end;

destructor TlrDetailReport.Destroy;
begin
  FreeAndNil(FReportBody);
  inherited Destroy;
end;

procedure TlrDetailReport.LoadFromXML(XML: TLrXMLConfig; const Path: String);
begin
  FReportName:=XML.GetValue(Path+'ReportName/Value', '');
  FReportDescription:=XML.GetValue(Path+'ReportDescription/Value', '');
  FReportBody.Size:=0;
  TStringStream(FReportBody).WriteString(XML.GetValue(Path+'ReportBody/Value', ''));
end;

procedure TlrDetailReport.SaveToXML(XML: TLrXMLConfig; const Path: String);
begin
  XML.SetValue(Path+'ReportName/Value', FReportName);
  XML.SetValue(Path+'ReportDescription/Value', FReportDescription);
  XML.SetValue(Path+'ReportBody/Value', TStringStream(FReportBody).DataString);
end;

procedure TlrDetailReport.SaveToStream(Stream: TStream);
begin
  frWriteString(Stream, FReportName);
  frWriteString(Stream, FReportDescription);
  frWriteString(Stream, TStringStream(FReportBody).DataString);
end;

procedure TlrDetailReport.LoadFromStream(Stream: TStream);
var
  S: String;
begin
  FReportName:=frReadString(Stream);
  FReportDescription:=frReadString(Stream);
  S:=frReadString(Stream);
  TStringStream(FReportBody).Size:=0;
  TStringStream(FReportBody).WriteString(S);
end;

{ TfrReportDesigner }

procedure TfrReportDesigner.SetModified(AValue: Boolean);
begin
  if Assigned(CurReport) then
    CurReport.FReportLastChange:=Now;
  if FModified=AValue then Exit;
  FModified:=AValue;
end;

{ TfrControl }

procedure TfrControl.UpdateControlPosition;
begin

end;

procedure TfrControl.AttachToParent;
begin

end;

function TfrControl.OwnerForm: TWinControl;
begin
  if OwnerPage is TfrPageDialog then
    Result:=TfrPageDialog(OwnerPage).Form
  else
    Result:=nil;
end;

constructor TfrControl.Create(AOwnerPage: TfrPage);
begin
  inherited Create(AOwnerPage);
  Typ := gtAddIn;
end;

procedure TfrControl.Draw(ACanvas: TCanvas);
begin
  BeginDraw(ACanvas);
  CalcGaps;
  PaintDesignControl;
  RestoreCoord;
end;

procedure TfrControl.DefinePopupMenu(Popup: TPopupMenu);
begin
  inherited DefinePopupMenu(Popup);
end;

{ TfrNonVisualControl }

procedure TfrNonVisualControl.PaintDesignControl;
begin
  DrawFrameControl(Canvas.Handle, DRect, DFC_BUTTON, DFCS_BUTTONPUSH);
  Canvas.Draw(DRect.Left + 2, DRect.Top + 2, ControlImage);
end;

constructor TfrNonVisualControl.Create(AOwnerPage: TfrPage);
begin
  inherited Create(AOwnerPage);
  ControlImage := CreateBitmapFromResourceName(HInstance, ClassName);
  dx := 28;
  dy := 28;
end;

destructor TfrNonVisualControl.Destroy;
begin
  FreeAndNil(ControlImage);
  inherited Destroy;
end;

procedure TfrNonVisualControl.Draw(ACanvas: TCanvas);
begin
  dx := 28;
  dy := 28;
  BeginDraw(ACanvas);
  CalcGaps;
  ShowBackground;
  PaintDesignControl;
  RestoreCoord;
end;

{----------------------------------------------------------------------------}
constructor TfrView.Create(AOwnerPage: TfrPage);
begin
  inherited Create(AOwnerPage);
  Parent := nil;
  Memo1 := TStringList.Create;
  fFrameWidth := 1;
  fFrameColor := clBlack;
  FFillColor := clNone;
  fFormat := 2*256 + Ord(DefaultFormatSettings.DecimalSeparator);
  BaseName := 'View';
  FVisible := True;
  StreamMode := smDesigning;
  ScaleX := 1;
  ScaleY := 1;
  OffsX := 0;
  OffsY := 0;
  Flags := flStretched;
  
  fFrames:=[]; //No frame
end;

destructor TfrView.Destroy;
begin
  Memo1.Free;
  inherited Destroy;
end;

procedure TfrView.Assign(Source: TPersistent);
begin
  inherited Assign(Source);

  if Source is TfrView then
  begin
    fName := TfrView(Source).Name;
    Typ := TfrView(Source).Typ;
    Selected := TfrView(Source).Selected;
    Flags := TfrView(Source).Flags;
    fFrameWidth := TfrView(Source).FrameWidth;
    fFrameColor := TfrView(Source).FrameColor;
    fFrameStyle := TfrView(Source).FrameStyle;
    FFillColor := TfrView(Source).FillColor;
    fFormat := TfrView(Source).Format;
    fFormatStr := TfrView(Source).FormatStr;
    fVisible := TfrView(Source).Visible;
    fFrames := TfrView(Source).Frames;
    FTag := TfrView(Source).FTag;
    FURLInfo := TfrView(Source).FURLInfo;
    FRestrictions := TfrView(Source).FRestrictions;
    FGapX:=TfrView(Source).FGapX;
    FGapY:=TfrView(Source).FGapY;
  end;
end;

procedure TfrView.CalcGaps;
var
  bx, by, bx1, by1, wx1, wx2, wy1, wy2: Integer;
begin
  SaveX := x;
  SaveY := y;
  SaveDX := dx;
  SaveDY := dy;
  SaveFW := FrameWidth;
  if DocMode = dmDesigning then
  begin
    ScaleX := 1;
    ScaleY := 1;
    OffsX := 0;
    OffsY := 0;
  end;

  x := Round(x*ScaleX)+OffsX;
  y := Round(y* ScaleY)+OffsY;
  dx:= Round(dx*ScaleX);
  dy:= Round(dy*ScaleY);

  wx1 := Round((FrameWidth * ScaleX - 1) / 2);
  wx2 := Round(FrameWidth * ScaleX / 2);
  wy1 := Round((FrameWidth * ScaleY - 1) / 2);
  wy2 := Round(FrameWidth * ScaleY / 2);
  fFrameWidth := FrameWidth * ScaleX;

  InternalGapX := wx2 + 2 + FGapX;
  InternalGapY := wy2 div 2 + 1 + FGapY;

  bx := x;
  by := y;
  bx1 := Round((SaveX + SaveDX) * ScaleX + OffsX);
  by1 := Round((SaveY + SaveDY) * ScaleY + OffsY);
  
  if frbTop in Frames    then Dec(bx1, wx2);
  if frbLeft in Frames   then Dec(by1, wy2);
  if frbBottom in Frames then Inc(bx, wx1);
  if frbRight in Frames  then Inc(by, wy1);
  DRect := Rect(bx, by, bx1 + 1, by1 + 1);
  {$IFDEF DebugLR}
  DebugLn('CalcGaps: ScaleXY:%f %f OLD:%d %d %d %d NEW: %d %d %d %d GAPS: %d %d DRECT: %s',
  [ScaleX,ScaleY,SaveX,SaveY,SaveDx,SaveDy,x,y,dx,dy,gapx,gapy,dbgs(drect)]);
  {$ENDIF}
end;

procedure TfrView.RestoreCoord;
begin
  x  := SaveX;
  y  := SaveY;
  dx := SaveDX;
  dy := SaveDY;
  fFrameWidth := SaveFW;
end;

procedure TfrView.ShowBackGround;
var
  fp: TColor;
begin
  if DisableDrawing then Exit;
  if (DocMode = dmPrinting) then
    if (FillColor = clNone) and (not FFindHighlight) then Exit;

  if FFindHighlight then
    fp := clSilver
  else
  begin
    fp := FillColor;
    if (DocMode = dmDesigning) and (fp = clNone) then
      fp := clWhite;
  end;

  Canvas.Brush.Bitmap := nil;
  Canvas.Brush.Style := bsSolid;
  Canvas.Brush.Color := fp;
  if DocMode = dmDesigning then
    Canvas.FillRect(DRect)
  else
    Canvas.FillRect(Rect(x, y,
   //use calculating coords instead of dx, dy - for best view
   Round((SaveX + SaveDX) * ScaleX + OffsX), Round((SaveY + SaveDY) * ScaleY + OffsY)));
end;

procedure TfrView.ShowFrame;
var
  x1, y1: Integer;

  procedure IntLine(X11, Y11, DX11, DY11: Integer);
  begin
    Canvas.MoveTo(X11, Y11);
    Canvas.LineTo(X11+DX11, Y11+Dy11);
  end;
  
  procedure Line1(x, y, x1, y1: Integer);
  var
    i, w: Integer;
  begin
    {$IFDEF DebugLR}
    DebugLn('Line1(',InttoStr(x),',',IntToStr(y),',',IntToStr(x1),',',IntToStr(y1),')');
    {$ENDIF}

    if Canvas.Pen.Style = psSolid then
    begin
      if FrameStyle<>frsDouble then
      begin
        Canvas.MoveTo(x, y);
        Canvas.LineTo(x1, y1);
      end
      else
      begin
        if x = x1 then
        begin
          Canvas.MoveTo(x - Round(FrameWidth), y);
          Canvas.LineTo(x1 - Round(FrameWidth), y1);
          Canvas.Pen.Color := FillColor;
          Canvas.MoveTo(x, y);
          Canvas.LineTo(x1, y1);
          Canvas.Pen.Color := FrameColor;
          Canvas.MoveTo(x + Round(FrameWidth), y);
          Canvas.LineTo(x1 + Round(FrameWidth), y1);
        end
        else
        begin
          Canvas.MoveTo(x, y - Round(FrameWidth));
          Canvas.LineTo(x1, y1 - Round(FrameWidth));
          Canvas.Pen.Color := FillColor;
          Canvas.MoveTo(x, y);
          Canvas.LineTo(x1, y1);
          Canvas.Pen.Color := FrameColor;
          Canvas.MoveTo(x, y + Round(FrameWidth));
          Canvas.LineTo(x1, y1 + Round(FrameWidth));
        end;
      end
    end
    else
    begin
      Canvas.Brush.Color:=FillColor;
      w := Canvas.Pen.Width;
      Canvas.Pen.Width := 1;
      if x = x1 then
      begin
        for i := 0 to w - 1 do
        begin
          Canvas.MoveTo(x - w div 2 + i, y);
          Canvas.LineTo(x - w div 2 + i, y1);
        end
      end
      else
      begin
        for i := 0 to w - 1 do
        begin
          Canvas.MoveTo(x, y - w div 2 + i);
          Canvas.LineTo(x1, y - w div 2 + i);
        end;
      end;
      Canvas.Pen.Width := w;
    end;
  end;
begin
  if DisableDrawing then Exit;
  if (DocMode = dmPrinting) and (Frames=[]) then Exit;

  with Canvas do
  begin
    Brush.Style:= bsClear;
    Pen.Style:=psSolid;
    if (dx>0) and (dy>0) and (DocMode = dmDesigning) then
    begin
      Pen.Color := clBlack;
      Pen.Width := 1;
      IntLine(x,y+3,0,-3);
      IntLine(x,y, 4, 0);
      IntLine(x,y+dy-3, 0, 3);
      IntLine(x,y+dy, 4, 0);
      IntLine(x+dx-3,y,3,0);
      IntLine(x+dx,y,0,4);
      IntLine(x+dx-3,y+dy,3,0);
      IntLine(x+dx,y+dy,0,-4);
    end;

    Pen.Color := FrameColor;
    Pen.Width := Round(FrameWidth);
    if FrameStyle<>frsDouble then
      Pen.Style := TPenStyle(FrameStyle);

    // use calculating coords instead of dx, dy - for best view
    x1 := Round((SaveX + SaveDX) * ScaleX + OffsX);
    y1 := Round((SaveY + SaveDY) * ScaleY + OffsY);
    
    { // todo: Frame is not implemented in Win32
    if ((frbTop in Frames) and (frbLeft in Frames) and
        (frbBottom   in Frames) and (frbRight  in Frames)) and (FrameStyle=frsSolid) then
          Frame(x,y, x1 + 1, y1 + 1)
    else
    }
    begin
      if (frbRight in Frames) then Line1(x1, y, x1, y1);
      if (frbLeft   in Frames) then Line1(x, y, x, y1);
      if (frbBottom in Frames) then Line1(x, y1, x1, y1);
      if (frbTop  in Frames) then Line1(x, y, x1, y);
    end;
    
    Brush.Style := bsSolid;
  end;
end;

procedure TfrView.BeginDraw(ACanvas: TCanvas);
begin
  fCanvas := ACanvas;
  CurView := Self;
end;

procedure TfrView.Print(Stream: TStream);
var
  FTmpTag:string;

begin
  {$IFDEF DebugLR}
  DebugLn('%s.TfrView.Print()',[name]);
  {$ENDIF}
  BeginDraw(Canvas);
  Memo1.Assign(Memo);
  CurReport.InternalOnEnterRect(Memo1, Self);
  //frInterpretator.DoScript(Script);
  InternalExecScript;
  if not Visible then Exit;

  Stream.Write(Typ, 1);
  if Typ = gtAddIn then
    frWriteString(Stream, ClassName);


  FTmpTag:=FTag;
  if (FTag<>'') and (Pos('[', FTag) > 0) then
    FTag:=lrExpandVariables(FTmpTag);

  SaveToStream(Stream);
  FTag:=FTmpTag;
  {$IFDEF DebugLR}
  DebugLn('%s.TfrView.Print() end',[name]);
  {$ENDIF}
end;

procedure TfrView.ExportData;
begin
  CurReport.InternalOnExportData(Self);
  CurReport.InternalOnExported(Self);
end;

procedure TfrView.LoadFromStream(Stream: TStream);
var
  wb : Word;
  li : Longint;
  S  : Single;
  i  : Integer;
begin
  {$IFDEF DebugLR}
  DebugLn('%s.TfrView.LoadFromStream begin StreamMode=%d ClassName=%s Stream.Position=%d',
    [name,Ord(StreamMode),ClassName, Stream.Position]);
  {$ENDIF}
  with Stream do
  begin

    if (frVersion>27) or ((frVersion=27) and lrCanReadName(Stream)) or (StreamMode = smDesigning) then
    begin
      if frVersion >= 23 then
        fName := ReadString(Stream)
      else
        CreateUniqueName;
    end;
    
    //Read(x, 18); // this is equal to, but much faster:
    Read(x, 4);
    Read(y, 4);
    Read(dx, 4);
    Read(dy, 4);
    Read(Flags, 2);

    if frVersion>23 then
    begin
      S := 0;
      Read(S, SizeOf(S)); fFrameWidth := S;
      Read(fFrameColor, SizeOf(fFrameColor));
      Read(fFrames, SizeOf(fFrames));
      Read(fFrameStyle, SizeOf(fFrameStyle));
    end else
    begin
      wb := 0;
      Read(wb, 2); // frametyp
      fFrameTyp := wb;
      fFrames := [];
      if (wb and $1) <> 0 then include(fFrames, frbRight);
      if (wb and $2) <> 0 then include(fFrames, frbBottom);
      if (wb and $4) <> 0 then include(fFrames, frbLeft);
      if (wb and $8) <> 0 then include(fFrames, frbTop);
      li := 0;
      Read(li, 4);  // framewidth (single)
      if li <= 10 then
        li := li * 1000;
      fFrameWidth := li / 1000;
      Read(li, 4); // framecolor
      fFrameColor := li;
      read(wb, 2); // framestyle
      fFrameStyle := TfrFrameStyle(wb);
    end;

    Read(FFillColor, 4);

    if StreamMode = smDesigning then
    begin
      Read(fFormat, 4);
      fFormatStr := ReadString(Stream);
    end;
    ReadMemo(Stream, Memo);

    if (frVersion >= 23) and (StreamMode = smDesigning) then
    begin
      ReadMemo(Stream, Script);
      wb := 0;
      Read(wb,2);
      Visible:=(Wb<>0);
    end;

    if (frVersion >= 25) then
    begin
      I := 0;
      Read(I, 4);
      ParentBandType := TfrBandType(I);
    end;

    if frVersion>25 then
    begin
      FTag := frReadString(Stream);
      FURLInfo := frReadString(Stream);
    end;

    if frVersion >= 29 then
    begin
      Stream.Read(FGapX, SizeOf(FGapX));
      Stream.Read(FGapY, SizeOf(FGapX));
    end;

    if frVersion >= 30 then
    begin
      Stream.Read(FRestrictions, SizeOf(TlrRestrictions));
    end;
  end;
  {$IFDEF DebugLR}
  DebugLn('%s.TfrView.LoadFromStream end Position=%d',[name, Stream.Position]);
  {$ENDIF}
end;

procedure TfrView.LoadFromXML(XML: TLrXMLConfig; const Path: String);
var
  S:string;
begin
  inherited LoadFromXML(XML,Path);
  StreamMode := TfrStreamMode(XML.GetValue(Path+'StreamMode/Value'{%H-}, 0)); // TODO Check default
{
  if StreamMode = smDesigning then
  begin
    if frVersion >= 23 then
      Name := XML.GetValue(Path+'Name/Value', 'checkthis!') // TODO Check default
    else
      CreateUniqueName;
  end;
}
  x  := XML.GetValue(Path + 'Size/Left/Value'{%H-}, 0);
  y  := XML.GetValue(Path + 'Size/Top/Value'{%H-}, 0);
  dx := XML.GetValue(Path + 'Size/Width/Value'{%H-}, 100);
  dy := XML.GetValue(Path + 'Size/Height/Value'{%H-}, 100);
  Flags := Word(XML.GetValue(Path + 'Flags/Value'{%H-}, 0)); // TODO Check default

  FFrameWidth := StringToFloatDef(XML.GetValue(Path+'Frames/FrameWidth/Value', ''), 1.0);
  FFramecolor := StringToColor(XML.GetValue(Path+'Frames/FrameColor/Value', 'clBlack')); // TODO Check default

  S:=XML.GetValue(Path+'Frames/FrameBorders/Value','');
  if S<>'' then
    RestoreProperty('Frames',S)
  else
    Frames:=[];

  S:=XML.GetValue(Path+'Frames/FrameStyle/Value','');
  if S<>'' then
    RestoreProperty('FrameStyle',S);

  FFillColor := StringToColor(XML.GetValue(Path+'FillColor/Value', 'clWindow')); // TODO Check default
  if StreamMode = smDesigning then
  begin
    fFormat     := XML.GetValue(Path+'Data/Format/Value'{%H-}, Format); // TODO Check default
    fFormatStr  := XML.GetValue(Path+'Data/FormatStr/Value', FormatStr);
    Memo.Text  := XML.GetValue(Path+'Data/Memo/Value', '');   // TODO Check default
    Script.Text:= XML.GetValue(Path+'Data/Script/Value', '');   // TODO Check default
  end
  else
    memo1.text := XML.GetValue(Path+'Data/Memo1/Value', ''); // TODO Check default

  FTag:=XML.GetValue(Path+'Tag/Value', '');
  FURLInfo:=XML.GetValue(Path+'FURLInfo/Value', '');

  S:=XML.GetValue(Path+'Frames/Restrictions/Value','');
  if S<>'' then
    RestoreProperty('Restrictions',S);

  FGapX:=XML.GetValue(Path+'Data/GapX/Value', 0);
  FGapY:=XML.GetValue(Path+'Data/GapY/Value', 0);
end;

procedure TfrView.SaveToStream(Stream: TStream);
var
  S: Single;
  B: Integer;
  FTmpS:string;
  {$IFDEF DebugLR}
  st: string;
  {$ENDIF}
begin
  {$IFDEF DebugLR}
  WriteStr(st, StreamMode);
  DebugLn('%s.SaveToStream begin StreamMode=%s',[name, st]);
  {$ENDIF}

  with Stream do
  begin
//    if StreamMode = smDesigning then
      frWriteString(Stream, Name);
//    Write(x, 18); // this is equal to, but much faster:
    Write(x, 4);
    Write(y, 4);
    Write(dx, 4);
    Write(dy, 4);
    Write(Flags, 2);

    S := fFrameWidth; Write(s,SizeOf(s));
    Write(fFrameColor, SizeOf(fFrameColor));
    Write(fFrames,SizeOf(fFrames));
    Write(fFrameStyle, SizeOf(fFrameStyle));

    Write(FFillColor, 4);

    if StreamMode = smDesigning then
    begin
      Write(fFormat, 4);
      frWriteString(Stream, fFormatStr);
      frWriteMemo(Stream, Memo);
      frWriteMemo(Stream, Script);
      Write(Visible, 2);
    end
    else
      frWriteMemo(Stream, Memo1);

    // parent band type new in stream format 25
    B := 0;
    if Parent<>nil then
      B := ord(Parent.Typ);
    Write(B, 4);

    //Tag property stream format 26
    if StreamMode = smDesigning then
    begin
      frWriteString(Stream, FTag);
      frWriteString(Stream, FURLInfo);
    end
    else
    begin
      FTmpS:=lrExpandVariables(FTag);
      frWriteString(Stream, FTmpS);
      FTmpS:=lrExpandVariables(FURLInfo);
      frWriteString(Stream, FTmpS);
    end;

    Stream.Write(FGapX, SizeOf(FGapX));
    Stream.Write(FGapY, SizeOf(FGapX));

    Stream.Write(FRestrictions, SizeOf(TlrRestrictions));

  end;
  {$IFDEF DebugLR}
  Debugln('%s.SaveToStream end',[name]);
  {$ENDIF}
end;

procedure TfrView.SaveToXML(XML: TLrXMLConfig; const Path: String);
begin
  inherited SaveToXML(XML,Path);
  XML.SetValue(Path+'Typ/Value', frTypeObjectToStr(Typ));
  XML.SetValue(Path+'StreamMode/Value'{%H-}, Ord(StreamMode)); //todo: use symbolic valuess
  XML.SetValue(Path+'Size/Left/Value'{%H-}, x);
  XML.SetValue(Path+'Size/Top/Value'{%H-}, y);
  XML.SetValue(Path+'Size/Width/Value'{%H-}, dx);
  XML.SetValue(Path+'Size/Height/Value'{%H-}, dy);
  XML.SetValue(Path+'Flags/Value'{%H-}, flags);
  
  if IsPublishedProp(self,'FillColor') then
    XML.SetValue(Path+'FillColor/Value', GetSaveProperty('FillColor'));

  if IsPublishedProp(self,'FrameColor') then
    XML.SetValue(Path+'Frames/FrameColor/Value', GetSaveProperty('FrameColor'));

  if IsPublishedProp(self,'FrameStyle') then
    XML.SetValue(Path+'Frames/FrameStyle/Value', GetSaveProperty('FrameStyle'));

  if IsPublishedProp(self,'FrameWidth') then
    XML.SetValue(Path+'Frames/FrameWidth/Value', GetSaveProperty('FrameWidth'));

  if IsPublishedProp(self,'Frames') then
    XML.SetValue(Path+'Frames/FrameBorders/Value', GetSaveProperty('Frames'));

  if StreamMode = smDesigning then
  begin
    if IsPublishedProp(self,'Format') then
      XML.SetValue(Path+'Data/Format/Value'{%H-}, Format);
    if IsPublishedProp(self,'FormatStr') then
       XML.SetValue(Path+'Data/FormatStr/Value', FormatStr);
    if IsPublishedProp(self,'Memo') then
      XML.SetValue(Path+'Data/Memo/Value', TStrings(Memo).Text);
    if IsPublishedProp(self,'Script') then
      XML.SetValue(Path+'Data/Script/Value', TStrings(Script).Text);

  end
  else
    XML.SetValue(Path+'Data/Memo1/Value', Memo1.Text);
  XML.SetValue(Path+'Tag/Value', FTag);
  XML.SetValue(Path+'FURLInfo/Value', FURLInfo);

  if IsPublishedProp(self,'Restrictions') then
    XML.SetValue(Path+'Frames/Restrictions/Value', GetSaveProperty('Restrictions'));

  XML.SetValue(Path+'Data/GapX/Value', FGapX);
  XML.SetValue(Path+'Data/GapY/Value', FGapY);
end;

procedure TfrView.Resized;
begin
end;

procedure TfrView.GetBlob(b: TfrTField);
begin
  if b=nil then;
end;

procedure TfrView.OnHook(View: TfrView);
begin
  if view=nil then;
end;

procedure TfrView.BeforeChange;
begin
  if (frDesigner<>nil) and (fUpdate=0) and (DocMode=dmDesigning) then
    frDesigner.BeforeChange;
end;

procedure TfrView.AfterChange;
begin
  if (frDesigner<>nil) and (fUpdate=0) and (DocMode=dmDesigning) then
    frDesigner.AfterChange;
end;

procedure TfrView.ResetLastValue;
begin
  // to be overriden in TfrMemoView
end;

function TfrView.GetClipRgn(rt: TfrRgnType): HRGN;
var
  bx, by, bx1, by1, w1, w2: Integer;
begin
  if FrameStyle=frsDouble then
  begin
    w1 := Round(FrameWidth * 1.5);
    w2 := Round((FrameWidth - 1) / 2 + FrameWidth);
  end
  else
  begin
    w1 := Round(FrameWidth / 2);
    w2 := Round((FrameWidth - 1) / 2);
  end;
  bx:=x;
  by:=y;
  bx1:=x+dx+1;
  by1:=y+dy+1;
  
  if (frbTop  in Frames) then Inc(bx1, w2);
  if (frbLeft  in Frames) then Inc(by1, w2);
  if (frbBottom  in Frames) then Dec(bx, w1);
  if (frbRight  in Frames) then Dec(by, w1);
  if rt = rtNormal then
    Result := CreateRectRgn(bx, by, bx1, by1)
  else
    Result := CreateRectRgn(bx - 10, by - 10, bx1 + 10, by1 + 10);
end;

procedure TfrView.SetBounds(aLeft, aTop, aWidth, aHeight: Integer);
begin
  Self.x  := aLeft;
  Self.y   := aTop;
  Self.dx := aWidth;
  Self.dy:= aHeight;
end;

function TfrView.PointInView(aX,aY: Integer): Boolean;
Var Rc : TRect;
    bx, by, bx1, by1, w1, w2: Integer;
begin
  if FrameStyle=frsDouble then
  begin
    w1 := Round(FrameWidth * 1.5);
    w2 := Round((FrameWidth - 1) / 2 + FrameWidth);
  end
  else
  begin
    w1 := Round(FrameWidth / 2);
    w2 := Round((FrameWidth - 1) / 2);
  end;
  bx:=x;
  by:=y;
  bx1:=dx+1;
  by1:=dy+1;

  if (frbTop  in Frames) then Inc(bx1, w2);
  if (frbLeft  in Frames) then Inc(by1, w2);
  if (frbBottom in Frames) then Dec(bx, w1);
  if (frbRight  in Frames) then Dec(by, w1);
  Rc:=Bounds(bx, by, bx1, by1);

  Result:=((aX>Rc.Left) and (aX<Rc.Right) and (aY>Rc.Top) and (aY<Rc.Bottom));
end;

function TfrView.FindAlignSide(const vert: boolean; const value: Integer;
  out found: Integer): boolean;
begin
  result := false;
  if vert then
  begin
    found := y;
    if abs(value-found)<=lrSnapDistance then exit(true);
    found := y+dy;
    if abs(value-found)<=lrSnapDistance then exit(true);
    found := y+dy div 2;
    if abs(value-found)<=lrSnapDistance then exit(true);
  end else
  begin
    found := x;
    if abs(value-found)<=lrSnapDistance then exit(true);
    found := x+dx;
    if abs(value-found)<=lrSnapDistance then exit(true);
    found := x+dx div 2;
    if abs(value-found)<=lrSnapDistance then exit(true);
  end;
end;

procedure TfrView.Invalidate;
begin
  if Assigned(Canvas) and (fUpdate=0) then
    Draw(Canvas);
end;

procedure TfrView.DefinePopupMenu(Popup: TPopupMenu);
var
  m: TMenuItem;
begin
  m := TMenuItem.Create(Popup);
  m.Caption := '-';
  Popup.Items.Add(m);

  m := TMenuItem.Create(Popup);
  m.Caption := sStretched;
  m.OnClick := @P1Click;
  m.Checked := Stretched;
  Popup.Items.Add(m);
end;

procedure TfrView.P1Click(Sender: TObject);
begin
  MenuItemCheckFlag(Sender, flStretched);
end;

procedure TfrView.SetDataField(AValue: string);
begin
  if (AValue <> '') and (AValue[1]<>'[') then
    AValue:='[' + AValue + ']';

  if Memo.Count = 0 then
    Memo.Add(AValue)
  else
    Memo[0]:=AValue;
end;

function TfrView.GetLeft: Double;
begin
  if frDesigner<>nil then
    result := frDesigner.PointsToUnits(x)
  else
    result := x;
end;

function TfrView.GetDataField: string;
begin
  if Memo.Count>0 then
    Result:=Memo[0]
  else
    Result:='';

  if Result <> '' then
    Result:=lrGetUnBrackedStr(Result);
end;

function TfrView.GetStretched: Boolean;
begin
  Result:=((Flags and flStretched)<>0);
end;

function TfrView.GetHeight: Double;
begin
  if frDesigner<>nil then
    result := frDesigner.PointsToUnits(dy)
  else
    result := dy;
end;

function TfrView.GetFrames: TfrFrameBorders;
begin
  result :=  fFrames;
end;

procedure TfrView.ModifyFlag(aFlag: Word; aValue: Boolean);
begin
  BeforeChange;
  SetBit(Flags, AValue, AFlag);
  AfterChange;
end;

procedure TfrView.MenuItemCheckFlag(Sender:TObject; aFlag: Word);
var
  i: Integer;
  t: TfrView;
begin
  frDesigner.BeforeChange;
  with Sender as TMenuItem do
  begin
    Checked := not Checked;
    for i := 0 to frDesigner.Page.Objects.Count - 1 do
    begin
      t := TfrView(frDesigner.Page.Objects[i]);
      if t.Selected then
        SetBit(t.Flags, Checked, aFlag);
    end;
  end;
  frDesigner.AfterChange;
end;

function TfrView.GetTop: Double;
begin
  if frDesigner<>nil then
    result := frDesigner.PointsToUnits(y)
  else
    result := y;
end;

function TfrView.GetWidth: Double;
begin
  if frDesigner<>nil then
    result := frDesigner.PointsToUnits(dx)
  else
    result := dx;
end;

procedure TfrView.PrepareObject;
begin

end;

procedure TfrView.SetFillColor(const AValue: TColor);
begin
  if aValue<>FFillColor then
  begin
    BeforeChange;
    fFillColor:=aValue;
    AfterChange;
  end;
end;

procedure TfrView.SetFormat(const AValue: Integer);
begin
  if fFormat<>AValue then
  begin
    BeforeChange;
    fFormat := AValue;
    AfterChange;
  end;
end;

procedure TfrView.SetFormatStr(const AValue: String);
begin
  if fFormatStr<>AValue then
  begin
    BeforeChange;
    fFormatStr := AValue;
    AFterChange;
  end;
end;

procedure TfrView.SetFrameColor(const AValue: TColor);
begin
  if fFramecolor<>AValue then
  begin
    BeforeChange;
    fFrameColor := AValue;
    AfterChange;
  end;
end;

procedure TfrView.SetFrames(const AValue: TfrFrameBorders);
begin
  if (aValue<>fFrames) then
  begin
    BeforeChange;
    fFrames:=AValue;
    AfterChange;
  end;
end;

procedure TfrView.SetFrameStyle(const AValue: TfrFrameStyle);
begin
  if fFrameStyle<>AValue then
  begin
    BeforeChange;
    fFrameStyle := AValue;
    AfterChange;
  end;
end;

procedure TfrView.SetFrameWidth(const AValue: Double);
begin
  if fFrameWidth<>AValue then
  begin
    BeforeChange;
    fFrameWidth := AValue;
    AfterChange;
  end;
end;

procedure TfrView.SetHeight(const AValue: Double);
begin
  if frDesigner<>nil then begin
    BeforeChange;
    dy := frDesigner.UnitsToPoints(AValue);
    AfterChange;
  end else
    dy := round(Avalue);
end;

procedure TfrView.SetLeft(const AValue: Double);
begin
  if frDesigner<>nil then begin
    BeforeChange;
    x := frDesigner.UnitsToPoints(AValue);
    AfterChange;
  end else
    x := round(AValue);
end;

procedure TfrView.SetStretched(const AValue: Boolean);
begin
  if Stretched<>AValue then
    ModifyFlag(flStretched, AValue);
end;

procedure TfrView.SetTop(const AValue: Double);
begin
  if frDesigner<>nil then begin
    BeforeChange;
    y := frDesigner.UnitsToPoints(AValue);
    AfterChange;
  end else
    y := round(AValue);
end;

procedure TfrView.SetWidth(const AValue: Double);
begin
  if frDesigner<>nil then begin
    BeforeChange;
    dx := frDesigner.UnitsToPoints(AValue);
    AfterChange;
  end else
    dx := round(AValue);
end;

{----------------------------------------------------------------------------}
constructor TfrCustomMemoView.Create(AOwnerPage: TfrPage);
begin
  inherited Create(AOwnerPage);
  fOnClick:=TfrScriptStrings.Create;
  FCursor:=crDefault;
  FDetailReport:='';
  FOnMouseEnter:=TfrScriptStrings.Create;
  FOnMouseLeave:=TfrScriptStrings.Create;
  FFindHighlight:=false;
  FParagraphGap:=0;

  Typ := gtMemo;
  FFont := TFont.Create;
  FFont.Name := 'Arial';
  FFont.Size := 10;
  FFont.Color := clBlack;
  FFont.Charset := frCharset;
  Highlight.FontColor := clBlack;
  Highlight.FillColor := clWhite;
  Highlight.FontStyle := 2; // fsBold
  BaseName := 'Memo';
  Flags := flStretched + flWordWrap;
  LineSpacing := 2;
  CharacterSpacing := 0;
  Adjust := 0;
end;

destructor TfrCustomMemoView.Destroy;
begin
  FFont.Free;
  if FLastValue<>nil then
    FLastValue.Free;

  FreeAndNil(FOnMouseEnter);
  FreeAndNil(FOnMouseLeave);
  FreeAndNil(fOnClick);
  inherited Destroy;
end;

procedure TfrCustomMemoView.SetFont(Value: TFont);
begin
  BeforeChange;
  fFont.Assign(Value);
  AfterChange;
end;

procedure TfrCustomMemoView.SetHideDuplicates(const AValue: Boolean);
begin
  if HideDuplicates<>AValue then
    ModifyFlag(flHideDuplicates, AValue);
end;

procedure TfrCustomMemoView.SetHideZeroValues(AValue: Boolean);
begin
  if WordBreak<>AValue then
    ModifyFlag(flHideZeros, AValue);
end;

procedure TfrCustomMemoView.SetIsLastValueSet(const AValue: boolean);
begin
  if AValue then begin
    if FLastValue=nil then
      FLastValue := TStringList.Create;
    FLastValue.Assign(Memo1);
  end else
  if FLastValue<>nil then begin
    FLastValue.Free;
    FLastValue:=nil;
  end;
end;

procedure TfrCustomMemoView.SetJustify(AValue: boolean);
begin
  // only if AValue=true change Adjust to reflect justify
  // otherwise let it alone, so previous value of alignment is respected
  if Avalue then
    Adjust := Adjust or %11;
end;

procedure TfrCustomMemoView.SetLayout(const AValue: TTextLayout);
begin
  if Layout<>AValue then
  begin
    BeforeChange;
    Adjust := (Adjust and %11100111) or (ord(AValue) shl 3);
    AfterChange;
  end;
end;

procedure TfrCustomMemoView.SetOnClick(AValue: TfrScriptStrings);
begin
  BeforeChange;
  fOnClick.Assign(AValue);
  AfterChange;
end;

procedure TfrCustomMemoView.SetOnMouseEnter(AValue: TfrScriptStrings);
begin
  BeforeChange;
  FOnMouseEnter.Assign(AValue);
  AfterChange;
end;

procedure TfrCustomMemoView.SetOnMouseLeave(AValue: TfrScriptStrings);
begin
  BeforeChange;
  FOnMouseLeave.Assign(AValue);
  AfterChange;
end;

procedure TfrCustomMemoView.SetWordBreak(AValue: Boolean);
begin
  if WordBreak<>AValue then
    ModifyFlag(flWordBreak, AValue);
end;

procedure TfrCustomMemoView.SetWordWrap(const AValue: Boolean);
begin
  if WordWrap<>AValue then
    ModifyFlag(flWordWrap, AValue);
end;

procedure TfrCustomMemoView.Assign(Source: TPersistent);
begin
  inherited Assign(Source);

  if Source is TfrCustomMemoView then
  begin
    FFont.Assign(TfrCustomMemoView(Source).Font);
    Adjust := TfrCustomMemoView(Source).Adjust;
    Highlight := TfrCustomMemoView(Source).Highlight;
    HighlightStr := TfrCustomMemoView(Source).HighlightStr;
    LineSpacing := TfrCustomMemoView(Source).LineSpacing;

    FOnClick.Assign(TfrCustomMemoView(Source).FOnClick);
    FOnMouseEnter.Assign(TfrCustomMemoView(Source).FOnMouseEnter);
    FOnMouseLeave.Assign(TfrCustomMemoView(Source).FOnMouseLeave);
    FDetailReport:=TfrCustomMemoView(Source).FDetailReport;
    FCursor:=TfrCustomMemoView(Source).FCursor;
    FParagraphGap:=TfrCustomMemoView(Source).FParagraphGap;
  end;
end;

procedure TfrCustomMemoView.ExpandVariables;
var
  i: Integer;
  procedure GetData(var s: String);
  var
    i, j: Integer;
    s1, s2: String;
  begin
    i := 1;
    repeat
      while (i < Length(s)) and (s[i] <> '[') do Inc(i);
      s1 := GetBrackedVariable(s, i, j);
      if i <> j then
      begin
        Delete(s, i, j - i + 1);
        s2 := '';
        CurReport.InternalOnGetValue(s1, s2);
        Insert(s2, s, i);
        Inc(i, Length(s2));
        j := 0;
      end;
    until i = j;
  end;
  
var
  s: string;
begin
  Memo1.Clear;
  for i := 0 to Memo.Count - 1 do
  begin
    s := Memo[i];
    if Length(s) > 0 then
    begin
      GetData(s);
      Memo1.Add(s)
    end
    else
      Memo1.Add('');
  end;
end;

procedure TfrCustomMemoView.AssignFont(aCanvas: TCanvas);
var
  fs: Integer;
begin
  {$IFDEF DebugLR}
  DebugLnEnter('AssignFont (%s) INIT: Self.Font.Size=%d aCanvas.Font.Size=%d',
    [self.Font.Name,Self.Font.Size,ACanvas.Font.Size]);
  {$ENDIF}
  //**    Brush.Style := bsClear;
  aCanvas.Font.Assign(Self.Font);
  if Self.Font.Name='' then
    aCanvas.Font.Name := 'default';
  //Font := Self.Font;
  if not IsPrinting and (ScaleY<>0) then
  begin
    if Self.Font.Size = 0 then
      fs := Round((-GetFontData(Self.Font.Handle).Height * 72 / Self.Font.PixelsPerInch))
    else
      fs := Self.Font.Size;
    ACanvas.Font.Height := -Round(fs * 96 / 72 * ScaleY);
  end;
  {$IFDEF DebugLR}
  DebugLnExit('AssignFont (%s) DONE: Self.Font.Size=%d aCanvas.Font.Size=%d',
    [self.Font.Name,Self.Font.Size,ACanvas.Font.Size]);
  {$ENDIF}
end;

type
  TWordBreaks = string;

const
  gl : string = 'АЕЁИОУЫЭЮЯаеёиоуыэюя';
  r_sogl :string = 'ЪЬьъ';

function BreakWord(s: string): TWordBreaks;

  function IsCharIn(i:integer; target:string):boolean;
  begin
    result := Pos(UTF8Copy(s, i, 1), target)>0;
  end;

var
  i,len: Integer;
  IsCh1,IsCh2,CanBreak: Boolean;
begin
  Result := '';
  Len := UTF8Length(s);
  if  Len > 4 then
  begin
    i := 2;
    repeat
      CanBreak := False;
      IsCh1 := IsCharIn(i + 1,gl);
      IsCh2 := IsCharIn(i + 2,gl);
      if IsCharIn(i,gl) then
      begin
        if IsCh1 or IsCh2 then
          CanBreak := True;
      end
      else
      begin
        if not IsCh1 and not IsCharIn(i + 1,r_sogl) and IsCh2 then
          CanBreak := True;
      end;
      if CanBreak then
        Result := Result + Chr(i);
      Inc(i);
    until i > Len - 2;
  end;
  {$IFDEF DebugLR}
  DebugLnEnter('');
  debugLn('breakword: s=%s result=%s',[dbgstr(s),dbgstr(result)]);
  DebugLnExit('');
  {$ENDIF}
end;

procedure TfrCustomMemoView.WrapMemo;
var
  size, size1, maxwidth: Integer;
  b: TWordBreaks;
  WCanvas: TCanvas;
  aword: string;

  // Using UnicodeString in OutLine() and WrapLine() is an ugly hack.
  // It only supports UCS-2 and does not support combining codepoints.
  // The procedures should be written for UTF-8 properly. See issues #34871 and #37170.
  // Anyway this is better than supporting plain ASCII.
  procedure OutLine(const str: UnicodeString);
  var
    n, w: Word;
  begin
    n := Length(str);
    if (n > 0) and (str[n] = #1) then
      w := WCanvas.TextWidth(Copy(str, 1, n - 1))
    else
      w := WCanvas.TextWidth(str);
    {$IFDEF DebugLR_detail}
    debugLn('Outline: str="%s" w/=%d w%%=%d',[copy(str,1,12),w div 256, w mod 256]);
    {$ENDIF}
    SMemo.Add(Utf8Encode(str) + Chr(w div 256) + Chr(w mod 256));
    Inc(size, size1);
    if Angle=0 then
      maxWidth := dx - InternalGapX - InternalGapX;
  end;

  procedure WrapLine(const s: UnicodeString);
  var
    i, cur, beg, last, len: Integer;
    WasBreak, CRLF, IsCR: Boolean;
    ch: char;
  begin

    CRLF := False;
    for i := 1 to Length(s) do
    begin
      if s[i] in [#10, #13] then
      begin
        CRLF := True;
        break;
      end;
    end;

    last := 1; beg := 1;
    if not CRLF and ((Length(s) <= 1) or (WCanvas.TextWidth(s) <= maxwidth)) then
    begin
      OutLine(s + #1)
    end else
    begin

      cur := 1;
      Len := length(s);

      while cur <= Len do
      begin
        Ch := s[cur];

        // check for items with soft-breaks
        IsCR := Ch=#13;
        if IsCR then
        begin
          //handle composite newline
          if (cur < length(s)) then
          begin
            ch := s[cur+1];
            //dont increase char index if next char is LF (#10)
            if s[cur+1]<>#10 then
              Inc(Cur);
          end;
        end;
        if Ch=#10 then
        begin
          OutLine(copy(s, beg, cur - beg) + #1);
          //increase the char index since it's pointing to CR (#13)
          if IsCR then
            Inc(cur);
          Inc(cur);
          beg := cur;
          last := beg;
          Continue;
        end;

        if ch <> ' ' then
        if WCanvas.TextWidth(copy(s, beg, cur - beg + 1)) > maxwidth then
        begin

          WasBreak := False;
          if (Flags and flWordBreak) <> 0 then
          begin

            // in case of breaking in the middle, get the full word
            i := cur;
            while (i <= Len) and not (ch in [' ', '.', ',', '-']) do
            begin
              Inc(i);
              ch := s[i];
            end;

            // find word's break points using some simple hyphenator algorithm
            // TODO: implement interface so users can use their own hyphenator
            //       algorithm
            aWord := copy(s, last, i - last);
            if (FHyp<>nil) and (FHyp.Loaded) then
            begin
              try
                b := FHyp.BreakWord(UTF8Lowercase(aWord));
              except
                b := '';
              end;
            end else
              b := BreakWord(aWord);

            // if word can be broken in many segments, find the last segment that
            // fits within maxwidth
            if Length(b) > 0 then
            begin
              i := 1;
              while (i <= Length(b)) and
                (WCanvas.TextWidth(copy(s, beg, last - beg + Ord(b[i])) + '-') <= maxwidth) do
              begin
                WasBreak := True;
                cur := last + Ord(b[i]);  // cur now points to next char after breaking word
                Inc(i);
              end;
            end;

            if (not WasBreak) and (FHyp<>nil) and FHyp.Loaded then
              // if hyphenator was specified and is valid don't break
              // words which hyphenator didn't break
            else
              // last now points to nex char to be processed
              last := cur;
          end
          else
          begin
            if last = beg then
              last := cur;
          end;

          if WasBreak then
          begin
            // if word has been broken, output the partial word plus an hyphen
            OutLine(copy(s, beg, last - beg) + '-');
          end else
          begin
            // output the portion of word that fits maxwidth
            OutLine(copy(s, beg, last - beg));
            // if space was found, advance to next no space char
            while (s[last] = ' ') and (last < Length(s)) do
              Inc(last);
          end;

          beg := last;
        end;

        if Ch in [' ', '.', ',', '-'] then
          last := cur;
        Inc(cur);
      end;

      if beg <> cur then
        OutLine(copy(s, beg, cur - beg + 1) + #1);
    end;
  end;

  procedure OutMemo;
  var
    i: Integer;
  begin
    size := y + InternalGapY;
    size1 := -WCanvas.Font.Height + LineSpacing;
//    maxWidth := dx - gapx - gapx;
    {$IFDEF DebugLR}
    DebugLn('OutMemo I: Size=%d Size1=%d MaxWidth=%d DIM:%d %d %d %d gapxy:%d %d',
      [Size,Size1,MaxWidth,x,y,dx,dy,gapx,gapy]);
    {$ENDIF}
    for i := 0 to Memo1.Count - 1 do
    begin
      maxWidth := dx - InternalGapX - InternalGapX - FParagraphGap;
      if (Flags and flWordWrap) <> 0 then
        WrapLine(Memo1[i])
      else
        OutLine(Memo1[i] + #1);
    end;
    VHeight := size - y + InternalGapY;
    TextHeight := size1;
    {$IFDEF DebugLR}
    DebugLn('OutMemo E: Size=%d Size1=%d MaxWidth=%d DIM:%d %d %d %d gapxy:%d %d',
      [Size,Size1,MaxWidth,x,y,dx,dy,gapx,gapy]);
    {$ENDIF}
  end;

  procedure OutMemo90;
  var
    i: Integer;
    h, oldh: HFont;
  begin
    h := Create90Font(WCanvas.Font);
    oldh := SelectObject(WCanvas.Handle, h);
    size := x + InternalGapX;
    size1 := -WCanvas.Font.Height + LineSpacing;
    maxwidth := dy - InternalGapY - InternalGapY;
    for i := 0 to Memo1.Count - 1 do
    begin
      if (Flags and flWordWrap) <> 0 then
        WrapLine(Memo1[i])
      else
        OutLine(Memo1[i]);
    end;
    
    SelectObject(WCanvas.Handle, oldh);
    DeleteObject(h);
    VHeight := size - x + InternalGapX;
    TextHeight := size1;
  end;

begin
  WCanvas := TempBmp.Canvas;
  WCanvas.Font.Assign(Font);
  if WCanvas.Font.Size = 0 then
    size := Round((-GetFontData(WCanvas.Font.Handle).Height * 72 / WCanvas.Font.PixelsPerInch))
  else
    size := WCanvas.Font.Size;
  WCanvas.Font.Height := -Round(size * 96 / 72);
  {$IFDEF DebugLR}
  DebugLnEnter('TfrMemoView.WrapMemo INI Font.PPI=%d Font.Size=%d Canvas.Font.PPI=%d WCanvas.Font.Size=%d',
    [Font.PixelsPerInch, Font.Size,Canvas.Font.PixelsPerInch,WCanvas.Font.Size]);
  {$ENDIF}

  {$IFDEF LCLNOGUI}
  // TODO: TVirtualCanvas(WCanvas).CharacterSpacing := CharacterSpacing;
  {$ELSE}
  SetTextCharacterExtra(WCanvas.Handle, CharacterSpacing);
  {$ENDIF}

  SMemo.Clear;
  if Angle<>0 then
    OutMemo90
  else
    OutMemo;
  {$IFDEF DebugLR}
  DebugLnExit('TfrMemoView.WrapMemo DONE',[]);
  {$ENDIF}
end;

procedure TfrCustomMemoView.ShowMemo;
var
  DR         : TRect;
  SavX,SavY  : Integer;
  
  procedure OutMemo;
  var
    i: Integer;
    curyf, thf, linespc: double;
    FTmpFL:boolean;

    function OutLine(st: String): Boolean;
    var
      {$IFDEF DebugLR}
      aw: Integer;
      {$ENDIF}
      cond: boolean;
      n, {nw, w, }curx, lasty: Integer;
      lastyf: Double;
      Ts: TTextStyle;
    begin
      lastyf := curyf + thf - LineSpc - 1;
      lastY := Round(lastyf);
      cond := not streaming and (lasty<=DR.Bottom);
      {$IFDEF DebugLR_detail}
      DebugLn('OutLine curyf=%f + thf=%f - gapy=%d = %f (%d) <= dr.bottom=%d == %s',
        [curyf,thf,gapy,lastyf,lasty,dr.bottom,dbgs(Cond)]);
      {$ENDIF}
      if not Streaming and cond then
      begin
        n := Length(St);
        //w := Ord(St[n - 1]) * 256 + Ord(St[n]);
        LastLine := true;
        SetLength(St, n - 2);
        if Length(St) > 0 then
        begin
          FTmpFL:=false;
          if St[Length(St)] = #1 then
          begin
            FTmpFL:=true;
            SetLength(St, Length(St) - 1);
          end
          else
            LastLine := false;
        end;

        // handle any alignment with same code
        Ts := Canvas.TextStyle;
        Ts.Layout    :=tlTop;
        Ts.Alignment := taLeftJustify;
        Ts.Wordbreak :=false;
        Ts.SingleLine:=True;
        Ts.Clipping  :=True;
        Canvas.TextStyle := Ts;

        (*
        // the disabled code allows for text-autofitting adjusting font size
        // TODO: waiting for users mising this and make it an option or remove it
        nw := Round(w * ScaleX);                    // needed width
        {$IFDEF DebugLR_detail}
        DebugLn('TextWidth=%d st=%s',[Canvas.TextWidth(St),copy(st, 1, 20)]);
        {$ENDIF}
        while (Canvas.TextWidth(St) > nw) and (Canvas.Font.Size>1) do
        begin
          Canvas.Font.Size := Canvas.Font.Size-1;
          {$IFDEF DebugLR}
          DebugLn('Rescal font %d',[Canvas.Font.Size]);
          {$ENDIF}
        end;
        {$IFDEF DebugLR_detail}
        Debugln('Canvas.Font.Size=%d TextWidth=%d',[Canvas.Font.Size,Canvas.TextWidth(St)]);
        aw := Canvas.TextWidth(St);                // actual width
        DebugLn('nw=%d  aw=%d',[nw,aw]);
        {$ENDIF}
        *)
        case Alignment of
          Classes.taLeftJustify : CurX :=x+InternalGapX;
          Classes.taRightJustify: CurX :=x+dx-1-InternalGapX-Canvas.TextWidth(St);
          Classes.taCenter      : CurX :=x+InternalGapX+(dx-InternalGapX-InternalGapX-Canvas.TextWidth(St)) div 2;
        end;

        if not Exporting then
        begin
          if Justify and not LastLine then
          begin
            if FirstLine then
              CanvasTextRectJustify(Canvas, DR, x+InternalGapX + FParagraphGap, x+dx-1-InternalGapX, round(CurYf), St, true)
            else
              CanvasTextRectJustify(Canvas, DR, x+InternalGapX, x+dx-1-InternalGapX, round(CurYf), St, true)
          end
          else
          begin
            if FirstLine then
              Canvas.TextRect(DR, CurX + FParagraphGap, round(curYf), St)
            else
              Canvas.TextRect(DR, CurX, round(curYf), St);
          end;
        end
        else
        begin
          if FirstLine then
            CurReport.InternalOnExportText(X + FParagraphGap, round(curYf), St, Self)
          else
            CurReport.InternalOnExportText(X, round(curYf), St, Self);
        end;

        Inc(CurStrNo);
        Result := False;
      end
      else
        Result := True;

      curyf := curyf + thf;
      FirstLine:=FTmpFL;
    end;

  begin {OutMemo}
    if Alignment in [Classes.taLeftJustify..Classes.taCenter] then
    begin
      if Layout=tlCenter then
        y:=y+(dy-VHeight) div 2
      else
      if Layout=tlBottom then
        y:=y+dy-VHeight;
    end;
    curyf := y + InternalGapY;

    LineSpc := LineSpacing * ScaleY;
    // calc our reference at 100% and then scale it
    // NOTE: this should not be r((Self.Font.Size*96/72 + LineSpacing)*ScaleY)
    //       as our base at 100% is rounded.
    if Self.Font.Size = 0 then
      i := Round((-GetFontData(Self.Font.Handle).Height * 72 / Self.Font.PixelsPerInch))
    else
      i := Self.Font.Size;
    thf := Round(i*96/72 + LineSpacing)* ScaleY;
    // Corrects font height, that's the total line height minus the scaled linespacing
    Canvas.Font.Height := -Round(thf - LineSpc);
    {$IFDEF DebugLR}
    DebugLn('curyf=%f thf=%f Font.height=%d TextHeight(H)=%d DR=%s Memo1.Count=%d',
      [curyf, thf, Canvas.Font.Height, Canvas.Textheight('H'), dbgs(DR), Memo1.Count]);
    {$ENDIF}
    CurStrNo := 0;

    FirstLine:=true;

    for i := 0 to Memo1.Count - 1 do
      if OutLine(Memo1[i]) then
        break;

    {$IFDEF DebugLR}
    DebugLn('CurStrNo=%d CurYf=%f Last"i"=%d',[CurStrNo, CurYf, i]);
    {$ENDIF}
  end;

  procedure OutMemo90;
  var
    i, th, curx: Integer;
    oldFont: TFont;
    rotatedFont: TFont;

    procedure OutLine(str: String);
    var
      cury: Integer;
      Ts: TTextStyle;
    begin
      SetLength(str, Length(str) - 2);
      if (str<>'') and (str[Length(str)] = #1) then
        SetLength(str, Length(str) - 1);
      cury := 0;

      Ts := Canvas.TextStyle;
      Ts.Layout    :=tlTop;
      Ts.Alignment :=self.Alignment;
      Ts.Wordbreak :=false;
      Ts.SingleLine:=True;
      Ts.Clipping  :=True;
      Canvas.TextStyle := Ts;

      case Alignment of
          Classes.taLeftJustify : CurY :=y + dy-InternalGapY;
          Classes.taRightJustify: CurY :=y + InternalGapY + 1 + Canvas.TextWidth(str);
          Classes.taCenter      : CurY :=y + InternalGapY + (dy + Canvas.TextWidth(str)) div 2;
      end;
      if not Exporting then
         canvas.TextOut(curx,cury,str)
      else
        if Angle <> 0 then
          CurReport.InternalOnExportText(CurX, CurY, str, Self)
        else
          CurReport.InternalOnExportText(CurX, Y, str, Self);
      Inc(CurStrNo);
      curx := curx + th;
    end;

  begin {OutMemo90}
    rotatedFont := TFont.Create;
    try
      rotatedFont.assign(Canvas.Font);
      rotatedFont.Orientation := 900;
      oldFont := Canvas.Font;
      Canvas.Font := rotatedFont;
      if Alignment in [Classes.taLeftJustify..Classes.taCenter] then
      begin
        if Layout=tlCenter then
          x := x +(dx-VHeight) div 2
        else if Layout=tlBottom then
          x:=x+dx-VHeight;
      end;
      curx := x + InternalGapX;
      if Canvas.Font.Height = 0 then
        i := GetFontData(Canvas.Font.Reference.Handle).Height
      else
        i := Canvas.Font.Height;
      th := -i + Round(LineSpacing * ScaleY);
      CurStrNo := 0;
      for i := 0 to Memo1.Count - 1 do
        OutLine(Memo1[i]);
    finally
      Canvas.Font := OldFont;
      rotatedFont.Free
    end;
  end;

begin
  {$IFDEF DebugLR}
  DebugLnEnter('TfrMemoView.ShowMemo INIT Font.Size=%d Canvas.Font.Size=%d',
    [Font.Size, Canvas.Font.Size]);
  {$ENDIF}
  AssignFont(Canvas);
  SavX:=X;
  SavY:=Y;
  Try
    SetTextCharacterExtra(Canvas.Handle, Round(CharacterSpacing * ScaleX));
    DR:=Rect(DRect.Left + 1, DRect.Top, DRect.Right - 2, DRect.Bottom - 1);
    VHeight:=Round(VHeight*ScaleY);

    if Angle <> 0 then
      OutMemo90
    else
      OutMemo;

  finally
    X:=SavX;
    Y:=SavY;
    {$IFDEF DebugLR}
    DebugLnExit('TfrMemoView.ShowMemo DONE Font.Size=%d Canvas.Font.Size=%d',[Font.Size, Canvas.Font.Size]);
    {$ENDIF}
  end;
  (*
  if (Adjust and $18) <> 0 then
  begin
    ad := Adjust;
    ox := x;
    oy := y;
    Adjust := Adjust and $7;
    if (ad and $4) <> 0 then
    begin
      if (ad and $18) = $8 then
        x := x + (dx - VHeight) div 2
      else if (ad and $18) = $10 then
               x := x + dx - VHeight;
      OutMemo90;
    end
    else
    begin
      if (ad and $18) = $8 then
        y := y + (dy - VHeight) div 2
      else if (ad and $18) = $10 then
        y := y + dy - VHeight;
      OutMemo;
    end;
    Adjust := ad;
    x := ox; y := oy;
  end
  else if (Adjust and $4) <> 0 then
          OutMemo90
       else
         OutMemo;
  *)
end;

function TfrCustomMemoView.CalcWidth(aMemo: TStringList): Integer;
var
  CalcRect: TRect;
  s: String;
  n: Integer;
  DTFlags: Cardinal;
begin
  {$IFDEF DebugLR}
  DebugLnEnter('TfrMemoView.CalcWidth INIT text=%s Font.PPI=%d Font.Size=%d dx=%d dy=%d',
    [aMemo.Text,Font.PixelsPerInch,Font.Size,Dx,dy]);
  {$ENDIF}
  CalcRect := Rect(0, 0, dx, dy);
  Canvas.Font.Assign(Font);
  if Font.Size = 0 then
    n := Round((-GetFontData(Font.Handle).Height * 72 / Font.PixelsPerInch))
  else
    n := Font.Size;
  Canvas.Font.Height := -Round(n * 96 / 72);
  {$IFDEF DebugLR}
  DebugLn('Canvas.Font.PPI=%d Canvas.Font.Size=%d',[Canvas.Font.PixelsPerInch,Canvas.Font.Size]);
  {$ENDIF}
  DTFlags := DT_CALCRECT;
  if Flags and flWordBreak <> 0 then
    DTFlags := DT_CALCRECT or DT_WORDBREAK;

  s := aMemo.Text;
  n := Length(s);
  if n > 2 then
    if (s[n - 1] = #13) and (s[n] = #10) then
      SetLength(s, n - 2);
  {$IFDEF LCLNOGUI}
  DrawTextNoGui(Canvas, s, CalcRect, DTFlags);
  {$ELSE}
  SetTextCharacterExtra(Canvas.Handle, Round(CharacterSpacing * ScaleX));
  DrawText(Canvas.Handle, PChar(s), Length(s), CalcRect, DTFlags);
  {$ENDIF}
  Result := CalcRect.Right + Round(2 * FrameWidth) + 2;
  {$IFDEF DebugLR}
  DebugLnExit('TfrMemoView.CalcWidth DONE Width=%d Rect=%s',[Result,dbgs(CalcRect)]);
  {$ENDIF}
end;

procedure TfrCustomMemoView.Draw(aCanvas: TCanvas);
var
  NeedWrap: Boolean;
  newdx: Integer;
  OldScaleX, OldScaleY: Double;
  IsVisible: boolean;
begin
  BeginDraw(aCanvas);
  {$IFDEF DebugLR}
    DebugLn('');
    DebuglnEnter('TfrMemoView.Draw: INIT Name=%s Printing=%s Canvas.Font.PPI=%d',
      [Name,dbgs(IsPrinting),Canvas.Font.PixelsPerInch]);
  NewDx := 0;
  {$ENDIF}
  if ((Flags and flAutoSize) <> 0) and (Memo.Count > 0) and  (DocMode <> dmDesigning) then
  begin
    newdx := CalcWidth(Memo);

    if Alignment=Classes.taRightJustify then
    begin
      x := x + dx - newdx;
      dx := newdx;
    end
    else
      dx := newdx;
  end;
  {$IFDEF DebugLR}
  DebugLn('NewDx=%d Dx=%d',[NewDx,dx]);
  {$ENDIF}
  Streaming := False;
  Memo1.Assign(Memo);

  OldScaleX := ScaleX;
  OldScaleY := ScaleY;
  ScaleX := 1;
  ScaleY := 1;
  CalcGaps;
  ScaleX := OldScaleX;
  ScaleY := OldScaleY;
  RestoreCoord;
  if Memo1.Count > 0 then
  begin
    NeedWrap := Pos(#1, Memo1.Text) = 0;
    {$IFDEF DebugLR}
    DebugLn('Memo1: Count=%d Text=%s NeedWrap=%s', [Memo1.Count,dbgstr(Memo1.text),dbgs(needwrap)]);
    {$ENDIF}
    if Memo1[Memo1.Count - 1] = #1 then
      Memo1.Delete(Memo1.Count - 1);

    if NeedWrap then
    begin
      WrapMemo;
      Memo1.Assign(SMemo);
    end;
  end;

  CalcGaps;

  if Flags and flHideDuplicates <> 0 then
    IsVisible := (flIsDuplicate and Flags = 0)
  else
    IsVisible := true;

  if IsVisible then
  begin
    if not Exporting then ShowBackground;
    if not Exporting then ShowFrame;
    if Memo1.Count > 0 then
      ShowMemo;
  end;

  RestoreCoord;
  {$IFDEF DebugLR}
  DebuglnExit('TfrMemoView.Draw: DONE',[]);
  {$Endif}
end;

procedure TfrCustomMemoView.Print(Stream: TStream);
var
  St: String;
  CanExpandVar: Boolean;
  OldFont: TFont;
  OldFill: Integer;
  i: Integer;
begin
  {$IFDEF DebugLR}
  WriteStr(St, DrawMode);
  DebugLnEnter('TfrMemoView.Print INIT %s DrawMode=%s Visible=%s',[ViewInfoDIM(Self), st, dbgs(Visible)]);
  {$ENDIF}
  BeginDraw(TempBmp.Canvas);
  Streaming := True;
  if DrawMode = drAll then
    InternalExecScript;
    //frInterpretator.DoScript(Script);

  CanExpandVar := True;
  if (DrawMode = drAll) and (Assigned(CurReport.OnEnterRect) or
     ((FDataSet <> nil) and frIsBlob(TfrTField(FDataSet.FindField(FField))))) then
  begin
    Memo1.Assign(Memo);
    St:=Memo1.Text;
    {$IFDEF DebugLR}
    try
      CurReport.InternalOnEnterRect(Memo1, Self);
    except
      on E:Exception do begin
        DebugLnExit('TfrMemoView.Print EXIT by Exception in OnEnterRect: %s',[E.Message]);
        raise;
      end;
    end;
    {$ELSE}
    CurReport.InternalOnEnterRect(Memo1, Self);
    {$ENDIF}
    if St<>Memo1.Text then
       CanExpandVar:= False;
  end
  else if DrawMode = drAfterCalcHeight then
           CanExpandVar := False;
  if DrawMode <> drPart then
    if CanExpandVar then ExpandVariables;

  if HideDuplicates then begin
    if IsLastValueSet then
      SetBit(Flags, FLastValue.Equals(Memo1), flIsDuplicate)
    else
      SetBit(Flags, false, flIsDuplicate);
    IsLastValueSet := True;
  end;

  if not Visible then
  begin
    {$IFDEF DebugLR}
    DebugLnExit('TfrMemoView.Print EXIT Not Visible!');
    {$ENDIF}
    DrawMode := drAll;
    Exit;
  end;

  OldFont := TFont.Create;
  OldFont.Assign(Font);
  OldFill := FillColor;
  if Length(HighlightStr) <> 0 then
  begin
    if frParser.Calc(HighlightStr) <> 0 then
    begin
      Font.Style:= frSetFontStyle(Highlight.FontStyle);
      Font.Color:= Highlight.FontColor;
      FFillColor := Highlight.FillColor;
    end;
  end;
  
  if (DrawMode = drPart) then
  begin
    CalcGaps;
    Streaming:=False;
    ShowMemo;
    SMemo.Assign(Memo1);
    while Memo1.Count > CurStrNo do
      Memo1.Delete(CurStrNo);
    if (Memo1.Count>0) and (Pos(#1, Memo1.Text) = 0) then
      Memo1.Add(#1);
  end;

  Stream.Write(Typ, 1);
  if Typ = gtAddIn then
    frWriteString(Stream, ClassName);
    
  SaveToStream(Stream);
  
  if DrawMode = drPart then
  begin
    Memo1.Assign(SMemo);
    for i := 0 to CurStrNo - 1 do
      Memo1.Delete(0);
  end;

  Font.Assign(OldFont);
  OldFont.Free;
  FFillColor := OldFill;
  DrawMode := drAll;
  {$IFDEF DebugLR}
  WriteStr(St, DrawMode);
  DebugLnExit('TfrMemoView.Print DONE %s DrawMode=%s',[ViewInfo(Self), st]);
  {$ENDIF}
end;

procedure TfrCustomMemoView.ExportData;
begin
  CurReport.InternalOnExportData(Self);
  Exporting := True;
  Draw(TempBmp.Canvas);
  Exporting := False;
  CurReport.InternalOnExported(Self);
end;

function TfrCustomMemoView.CalcHeight: Integer;
var
  s: String;
  CanExpandVar: Boolean;
  OldFont: TFont;
  OldFill: Integer;
begin
  Result := 0;
  DrawMode := drAfterCalcHeight;
  BeginDraw(TempBmp.Canvas);
  //frInterpretator.DoScript(Script);
  InternalExecScript;

  if not Visible then Exit;
  {$IFDEF DebugLR}
  DebugLnEnter('TfrMemoView.CalcHeight %s INIT',[ViewInfo(Self)]);
  {$ENDIF}
  CanExpandVar := True;
  Memo1.Assign(Memo);
  s := Memo1.Text;
  CurReport.InternalOnEnterRect(Memo1, Self);
  if s <> Memo1.Text then CanExpandVar := False;
  if CanExpandVar then ExpandVariables;

  OldFont := TFont.Create;
  OldFont.Assign(Font);
  OldFill := FillColor;
  if Length(HighlightStr) <> 0 then
    if frParser.Calc(HighlightStr) <> 0 then
    begin
      Font.Style := frSetFontStyle(Highlight.FontStyle);
      Font.Color := Highlight.FontColor;
      FFillColor := Highlight.FillColor;
    end;
  if ((Flags and flAutoSize) <> 0) and (Memo1.Count > 0) and
     (DocMode <> dmDesigning) then
    dx := CalcWidth(Memo1);

  CalcGaps;
  if Memo1.Count <> 0 then
  begin
    WrapMemo;
    Result := VHeight;
    {$IFDEF DebugLR}
    DebugLn('Memo1.Count!=0: VHeight=%d',[VHeight]);
    {$ENDIF}
  end;
  Font.Assign(OldFont);
  OldFont.Free;
  FFillColor := OldFill;
  {$IFDEF DebugLR}
  DebugLnExit('TfrMemoView.CalcHeight DONE result=%d',[Result]);
  {$ENDIF}
end;

function TfrCustomMemoView.MinHeight: Integer;
begin
  Result := TextHeight;
end;

function TfrCustomMemoView.RemainHeight: Integer;
begin
  Result := Memo1.Count * TextHeight;
end;

procedure TfrCustomMemoView.LoadFromStream(Stream: TStream);
var
  w: Word;
  i: Integer;
  tmpLayout: TTextLayout;
  tmpAngle: Byte;
begin
  {$IFDEF DebugLR}
  DebugLn('Stream.Position=%d Stream.Size=%d',[Stream.Position,Stream.Size]);
  {$ENDIF}

  inherited LoadFromStream(Stream);
  Font.Name := ReadString(Stream);
  with Stream do
  begin
    Read(i{%H-}, 4);
    Font.Size := i;
    Read(w{%H-}, 2);
    Font.Style := frSetFontStyle(w);
    Read(i, 4);
    Font.Color := i;
    if frVersion=23 then
      Read(Adjust, 4);
    Read(w, 2);
    if frVersion < 23 then
      w := frCharset;
    Font.Charset := w;
    if StreamMode = smDesigning then
    begin
      Read(Highlight, 10);
      HighlightStr := ReadString(Stream);
    end;
    if frVersion>23 then
    begin
      if LRE_OLDV25_FRF_READ and (frVersion=25) then
      begin
        Read(i, 4);
        tmpAngle := byte(i);
      end else
        Read(tmpAngle, SizeOf(tmpAngle));
      Adjust := (Adjust and not 3) or (tmpAngle and %11);
      Read(TmpLayout{%H-},SizeOf(TmpLayout));
      tmpAngle := 0;
      Read(tmpAngle,SizeOf(tmpAngle));

      BeginUpdate;
      Layout := tmpLayout;
      Angle := tmpAngle;
      EndUpdate;
    end;


    if frVersion>26 then
    begin
      Stream.Read(FCursor, SizeOf(FCursor));
      frReadMemo(Stream, FOnClick);
      frReadMemo(Stream, FOnMouseEnter);
      frReadMemo(Stream, FOnMouseLeave);
      FDetailReport:=frReadString(Stream);
      if LRE_OLDV28_FRF_READ and (frVersion=28) then
        //
      else
        Stream.Read(FParagraphGap, SizeOf(FParagraphGap));
    end;

    if frVersion >= 29 then
    begin
      Stream.Read(FLineSpacing, SizeOf(FLineSpacing));
    end;
  end;

  if frVersion = 21 then
    Flags := Flags or flWordWrap;
end;

procedure TfrCustomMemoView.LoadFromXML(XML: TLrXMLConfig; const Path: String);
begin
  inherited LoadFromXML(XML, Path);

  Font.Name := XML.GetValue(Path+'Font/Name/Value', 'Arial'); // todo chk
  Font.Size := XML.GetValue(Path+'Font/Size/Value'{%H-}, 10); // todo chk
  RestoreProperty('CharSet', XML.GetValue(Path+'Font/Charset/Value', '0'), Font);
  RestoreProperty('Style',XML.GetValue(Path+'Font/Style/Value',''), Font);
  Font.Color := StringToColor(XML.GetValue(Path+'Font/Color/Value','clBlack')); // todo chk

  if StreamMode = smDesigning then begin
    Highlight.FontStyle := XML.GetValue(Path+'Highlight/FontStyle/Value'{%H-}, 0); // todo chk
    Highlight.FontColor := StringToColor(XML.GetValue(Path+'Highlight/FontColor/Value', 'clBlack'));
    Highlight.FillColor := StringToColor(XML.GetValue(Path+'Highlight/FillColor/Value', 'clWhite'));
    HighlightStr := XML.GetValue(Path+'Highlight/HighlightStr/Value', HighlightStr);
  end;
  
  RestoreProperty('Alignment',XML.GetValue(Path+'Alignment/Value',''));
  RestoreProperty('Layout',XML.GetValue(Path+'Layout/Value',''));
  Angle := XML.GetValue(Path+'Angle/Value'{%H-}, 0);
  Justify := XML.GetValue(Path+'Justify/Value', false);

  FCursor:=TCursor(XML.GetValue(Path+'Cursor/Value'{%H-}, crDefault));

  FOnClick.Text:= XML.GetValue(Path+'Data/OnClick/Value', '');
  FOnMouseEnter.Text:= XML.GetValue(Path+'Data/OnMouseEnter/Value', '');
  FOnMouseLeave.Text:= XML.GetValue(Path+'Data/OnMouseLeave/Value', '');

  FDetailReport:= XML.GetValue(Path+'Data/DetailReport/Value', '');
  FParagraphGap:=XML.GetValue(Path+'Data/ParagraphGap/Value', 0);
  FLineSpacing:=XML.GetValue(Path+'Data/LineSpacing/Value', 2);
end;

procedure TfrCustomMemoView.SaveToStream(Stream: TStream);
var
  i: Integer;
  w: Word;
  tmpLayout: TTextLayout;
  tmpAngle: Byte;
  tmpByteAlign: Byte;
begin
  inherited SaveToStream(Stream);
  frWriteString(Stream, Font.Name);
  with Stream do
  begin
    i := Font.Size;
    Write(i, 4);
    w := frGetFontStyle(Font.Style);
    Write(w, 2);
    i := Font.Color;
    Write(i, 4);
    w := Font.Charset;
    Write(w, 2);
    if StreamMode = smDesigning then
    begin
      Write(Highlight, 10);
      frWriteString(Stream, HighlightStr);
    end;

    tmpByteAlign := Adjust and %11;
    tmpLayout := Layout;
    tmpAngle := Angle;
    Write(tmpByteAlign, SizeOf(tmpByteAlign));
    Write(tmpLayout,SizeOf(tmpLayout));
    Write(tmpAngle,SizeOf(tmpAngle));

    Stream.Write(FCursor, SizeOf(FCursor));
    frWriteMemo(Stream, FOnClick);
    frWriteMemo(Stream, FOnMouseEnter);
    frWriteMemo(Stream, FOnMouseLeave);
    frWriteString(Stream, FDetailReport);
    Stream.Write(FParagraphGap, SizeOf(FParagraphGap));
    Stream.Write(FLineSpacing, SizeOf(FLineSpacing));
  end;
end;

procedure TfrCustomMemoView.SaveToXML(XML: TLrXMLConfig; const Path: String);
begin
  inherited SaveToXML(XML, Path);
  XML.SetValue(Path+'Font/Name/Value', Font.name);
  XML.SetValue(Path+'Font/Size/Value'{%H-}, Font.Size);
  XML.SetValue(Path+'Font/Color/Value', ColorToString(Font.Color));
  XML.SetValue(Path+'Font/Charset/Value', GetSaveProperty('CharSet',Font));
  XML.SetValue(Path+'Font/Style/Value', GetSaveProperty('Style',Font));

  if StreamMode=smDesigning then
  begin
    XML.SetValue(Path+'Highlight/FontStyle/Value'{%H-}, HighLight.FontStyle);
    XML.SetValue(Path+'Highlight/FontColor/Value', ColorToString(Highlight.FontColor));
    XML.SetValue(Path+'Highlight/FillColor/Value', ColorToString(Highlight.FillColor));
    XML.SetValue(Path+'Highlight/HighlightStr/Value', HighlightStr);
  end;
  XML.SetValue(Path+'Alignment/Value',GetSaveProperty('Alignment'));
  XML.SetValue(Path+'Layout/Value', GetSaveProperty('Layout'));
  XML.SetValue(Path+'Angle/Value'{%H-}, Angle);
  XML.SetValue(Path+'Justify/Value', Justify);
  XML.SetValue(Path+'Cursor/Value'{%H-}, FCursor);

  XML.SetValue(Path+'Data/OnClick/Value', FOnClick.Text);
  XML.SetValue(Path+'Data/OnMouseEnter/Value', FOnMouseEnter.Text);
  XML.SetValue(Path+'Data/OnMouseLeave/Value', FOnMouseLeave.Text);

  XML.SetValue(Path+'Data/DetailReport/Value', FDetailReport);
  XML.SetValue(Path+'Data/ParagraphGap/Value', FParagraphGap);
  XML.SetValue(Path+'Data/LineSpacing/Value', FLineSpacing);
end;

procedure TfrCustomMemoView.GetBlob(b: TfrTField);
begin
  Memo1.Text := TBlobField(b).AsString;
end;

procedure TfrCustomMemoView.FontChange(sender: TObject);
begin
  AfterChange;
end;

procedure TfrCustomMemoView.ResetLastValue;
begin
  IsLastValueSet := False;
end;

procedure TfrCustomMemoView.DoRunScript(AScript: TfrScriptStrings);
var
  FSaveView:TfrView;
  FSavePage:TfrPage;
  CmdList, ErrorList:TStringList;
begin
  FSaveView:=CurView;
  FSavePage:=CurPage;

  CmdList:=TStringList.Create;
  ErrorList:=TStringList.Create;
  try
    CurView := Self;
    CurPage:=OwnerPage;
    frInterpretator.PrepareScript(AScript, CmdList, ErrorList);
    frInterpretator.DoScript(CmdList);
  finally
    CurPage:=FSavePage;
    CurView := FSaveView;

    FreeAndNil(CmdList);
    FreeAndNil(ErrorList);
  end;
end;

procedure TfrCustomMemoView.DoOnClick;
var
  FSaveRep:TfrReport;
  FSaveView:TfrView;
  FSavePage:TfrPage;
  CmdList, ErrorList:TStringList;

  FSaveGetPValue:TGetPValueEvent;
  FSaveFunEvent:TFunctionEvent;

  FDR:TlrDetailReport;
begin
  if not Assigned(CurReport) then
    exit;

  if (FOnClick.Count>0) and (Trim(FOnClick.Text)<>'') then
    DoRunScript(FOnClick);

  FDR:=CurReport.DetailReports[FDetailReport];
  if Assigned(FDR) and (FDR.ReportBody.Size>0) then
  begin
    FSaveView:=CurView;
    FSavePage:=CurPage;
    FSaveRep:=CurReport;
    FSaveGetPValue:=frParser.OnGetValue;
    FSaveFunEvent:=frParser.OnFunction;

    FDR.ReportBody.Position:=0;

    CurView := nil;
    CurPage := nil;
    CurReport:=TfrReport.Create(FSaveRep.Owner);

    CurReport.OnBeginBand:=FSaveRep.OnBeginBand;
    CurReport.OnBeginColumn:=FSaveRep.OnBeginColumn;
    CurReport.OnBeginDoc:=FSaveRep.OnBeginDoc;
    CurReport.OnBeginPage:=FSaveRep.OnBeginPage;
    CurReport.OnDBImageRead:=FSaveRep.OnDBImageRead;
    CurReport.OnEndBand:=FSaveRep.OnEndBand;
    CurReport.OnEndDoc:=FSaveRep.OnEndDoc;
    CurReport.OnEndPage:=FSaveRep.OnEndPage;
    CurReport.OnEnterRect:=FSaveRep.OnEnterRect;
    CurReport.OnExportFilterSetup:=FSaveRep.OnExportFilterSetup;
    CurReport.OnGetValue:=FSaveRep.OnGetValue;
    CurReport.OnManualBuild:=FSaveRep.OnManualBuild;
    CurReport.OnMouseOverObject:=FSaveRep.OnMouseOverObject;
    CurReport.OnObjectClick:=FSaveRep.OnObjectClick;
    CurReport.OnPrintColumn:=FSaveRep.OnPrintColumn;
    CurReport.OnProgress:=FSaveRep.OnProgress;
    CurReport.OnUserFunction:=FSaveRep.OnUserFunction;


    CmdList:=TStringList.Create;
    ErrorList:=TStringList.Create;
    try
      CurReport.LoadFromXMLStream(FDR.ReportBody);
      CurReport.ShowReport;
    finally
      FreeAndNil(CurReport);
      CurReport:=FSaveRep;
      CurPage:=FSavePage;
      CurView := FSaveView;
      frParser.OnGetValue:=FSaveGetPValue;
      frParser.OnFunction:=FSaveFunEvent;
      FreeAndNil(CmdList);
      FreeAndNil(ErrorList);
    end;
  end;
end;

procedure TfrCustomMemoView.DoMouseEnter;
begin
  if (FOnMouseEnter.Count>0) and (Trim(FOnMouseEnter.Text)<>'') and (Assigned(CurReport))then
    DoRunScript(FOnMouseEnter);
end;

procedure TfrCustomMemoView.DoMouseLeave;
begin
  if (FOnMouseLeave.Count>0) and (Trim(FOnMouseLeave.Text)<>'') and (Assigned(CurReport))then
    DoRunScript(FOnMouseLeave);
end;

procedure TfrCustomMemoView.DefinePopupMenu(Popup: TPopupMenu);
var
  m: TMenuItem;
begin
  m := TMenuItem.Create(Popup);
  m.Caption := sVarFormat;
  m.OnClick := @P1Click;
  Popup.Items.Add(m);

  m := TMenuItem.Create(Popup);
  m.Caption := sFont;
  m.OnClick := @P4Click;
  Popup.Items.Add(m);
  inherited DefinePopupMenu(Popup);

  m := TMenuItem.Create(Popup);
  m.Caption := sWordWrap;
  m.OnClick := @P2Click;
  m.Checked := WordWrap;
  Popup.Items.Add(m);

  m := TMenuItem.Create(Popup);
  m.Caption := sWordBreak;
  m.OnClick := @P3Click;
  m.Enabled := WordWrap;
  if m.Enabled then
     m.Checked := WordBreak;
  Popup.Items.Add(m);

  m := TMenuItem.Create(Popup);
  m.Caption := sAutoSize;
  m.OnClick := @P5Click;
  m.Checked := AutoSize;
  Popup.Items.Add(m);

  m := TMenuItem.Create(Popup);
  m.Caption := sHideZeroValues;
  m.OnClick := @P6Click;
  m.Checked := HideZeroValues;
  Popup.Items.Add(m);
end;

procedure TfrCustomMemoView.MonitorFontChanges;
begin
  FFont.OnChange:= @FontChange;
end;

procedure TfrCustomMemoView.P1Click(Sender: TObject);
var
  t: TfrView;
  i: Integer;
begin
  BeforeChange;
  frFmtForm := TfrFmtForm.Create(nil);
  try
    with frFmtForm do
    begin
      EdFormat := Self.Format;
      EdFormatStr := Self.FormatStr;
      if ShowModal = mrOk then
      begin
        for i := 0 to frDesigner.Page.Objects.Count - 1 do
        begin
          t := TfrView(frDesigner.Page.Objects[i]);
          if t.Selected then
          begin
            TfrCustomMemoView(t).Format := EdFormat;
            TfrCustomMemoView(t).FormatStr := EdFormatStr;
          end;
        end;
      end;
    end;
  finally
    frFmtForm.Free;
    AfterChange
  end;
end;

function TfrCustomMemoView.GetAutoSize: Boolean;
begin
  Result:=((Flags and flAutoSize)<>0);
end;

function TfrCustomMemoView.GetHideDuplicates: Boolean;
begin
  result:=((Flags and flHideDuplicates)<>0);
end;

function TfrCustomMemoView.GetHideZeroValues: Boolean;
begin
  Result:=((Flags and flHideZeros)<>0);
end;

function TfrCustomMemoView.GetIsLastValueSet: boolean;
begin
  result := FLastValue<>nil;
end;

function TfrCustomMemoView.GetJustify: boolean;
begin
  result := (Adjust and %11) = %11;
end;

function TfrCustomMemoView.GetLayout: TTextLayout;
begin
  result := TTextLayout((adjust shr 3) and %11);
end;

function TfrCustomMemoView.GetWordBreak: Boolean;
begin
  Result := ((Flags and flWordBreak)<>0);
end;

function TfrCustomMemoView.GetAlignment: TAlignment;
begin
  if (Adjust and %11) = %11 then
    result := taLeftJustify
  else
    Result:=Classes.TAlignment(Adjust and %11);
end;

function TfrCustomMemoView.GetAngle: Byte;
begin
  if Adjust and 4 <> 0 then
    Result := 90
  else
    Result := 0
end;

function TfrCustomMemoView.GetWordWrap: Boolean;
begin
  Result:=((Flags and flWordWrap)<>0);
end;

procedure TfrCustomMemoView.P2Click(Sender: TObject);
begin
  MenuItemCheckFlag(Sender, flWordWrap);
end;

procedure TfrCustomMemoView.P3Click(Sender: TObject);
begin
  MenuItemCheckFlag(Sender, flWordBreak);
end;

procedure TfrCustomMemoView.P4Click(Sender: TObject);
var
  t: TfrView;
  i: Integer;
  fd: TFontDialog;
begin
  frDesigner.BeforeChange;
  fd := TFontDialog.Create(nil);
  with fd do
  begin
    Font.Assign(Self.Font);
    if Execute then
      for i := 0 to frDesigner.Page.Objects.Count - 1 do
      begin
        t :=TfrView(frDesigner.Page.Objects[i]);
        if t.Selected then
        begin
          if Font.Name <> Self.Font.Name then
            TfrMemoView(t).Font.Name := Font.Name;
          if Font.Size <> Self.Font.Size then
            TfrMemoView(t).Font.Size := Font.Size;
          if Font.Color <> Self.Font.Color then
            TfrMemoView(t).Font.Color := Font.Color;
          if Font.Style <> Self.Font.Style then
            TfrMemoView(t).Font.Style := Font.Style;
          if Font.Charset <> Self.Font.Charset then
            TfrMemoView(t).Font.Charset := Font.Charset;
        end;
      end;
  end;
  fd.Free;
  frDesigner.AfterChange;
end;

procedure TfrCustomMemoView.P5Click(Sender: TObject);
begin
  MenuItemCheckFlag(Sender, flAutoSize);
end;

procedure TfrCustomMemoView.P6Click(Sender: TObject);
begin
  MenuItemCheckFlag(Sender, flHideZeros);
end;

procedure TfrCustomMemoView.SetAlignment(const AValue: TAlignment);
var
  b: byte;
begin
  if Alignment<>AValue then
  begin
    BeforeChange;
    // just in case, check for crazy value stored by alignment=justify
    // in previous versions.
    b := byte(AValue) and %11;
    Adjust := (Adjust and not 3) or b;
    AfterChange;
  end;
end;

procedure TfrCustomMemoView.SetAngle(const AValue: Byte);
begin
  if AValue <> Angle then
  begin
    BeforeChange;
    if AValue <> 0 then
      Adjust := Adjust or $04
    else
      Adjust := Adjust and $FB;
    AfterChange
  end;
end;

procedure TfrCustomMemoView.SetAutoSize(const AValue: Boolean);
begin
  if AutoSize<>AValue then
    ModifyFlag(flAutoSize, AValue);
end;

procedure TfrCustomMemoView.SetCursor(AValue: TCursor);
begin
  if FCursor=AValue then Exit;
  BeforeChange;
  FCursor:=AValue;
  AfterChange;
end;

{----------------------------------------------------------------------------}
constructor TfrBandView.Create(AOwnerPage: TfrPage);
begin
  inherited Create(AOwnerPage);
  Typ := gtBand;
  fFormat := 0;
  BaseName := 'Band';
  Flags := flBandOnFirstPage + flBandOnLastPage;
end;

procedure TfrBandView.Assign(Source: TPersistent);
begin
  inherited Assign(Source);
  if Source is TfrBandView then
  begin
    BandType := TFrBandView(Source).BandType;
    DataSet  := TFrBandView(Source).DataSet;
    GroupCondition:=TFrBandView(Source).GroupCondition;
    Child := TFrBandView(Source).Child;
  end;
end;

procedure TfrBandView.LoadFromStream(Stream: TStream);
begin
  inherited LoadFromStream(Stream);

  With Stream do
  if frVersion>23 then begin
    Read(fBandType,SizeOf(BandType));
    if (frVersion<28) and (fBandType=btChild) then
      fBandType := btNone; // btNone and btChild were swapped in version 29
    fCondition :=ReadString(Stream);
    fDataSetStr:=ReadString(Stream);
    if frVersion>=28 then
      fChild :=ReadString(Stream);
    fixPrintChildIfNotVisible;
  end else
  begin
    if StreamMode=smDesigning then begin
      fBandType := TfrBandType(fFrameTyp);
      fCondition := FormatStr;
      fDatasetStr := FormatStr;
    end;
  end;
end;

procedure TfrBandView.LoadFromXML(XML: TLrXMLConfig; const Path: String);
begin
  inherited LoadFromXML(XML, Path);
  RestoreProperty('BandType',XML.GetValue(Path+'BandType/Value','')); // todo chk
  FCondition := XML.GetValue(Path+'Condition/Value', ''); // todo chk
  FDatasetStr := XML.GetValue(Path+'DatasetStr/Value', ''); // todo chk
  FChild := XML.GetValue(Path+'Child/Value', '');
  FixPrintChildIfNotVisible;
end;

procedure TfrBandView.SaveToStream(Stream: TStream);
begin
  inherited SaveToStream(Stream);
  
  with Stream do
  begin
    Write(fBandType,SizeOf(fBandType));
    frWriteString(Stream, fCondition);
    frWriteString(Stream, fDataSetStr);
    frWriteString(Stream, fChild);
  end;
end;

procedure TfrBandView.SaveToXML(XML: TLrXMLConfig; const Path: String);
begin
  inherited SaveToXML(XML, Path);
  XML.SetValue(Path+'BandType/Value', GetSaveProperty('BandType')); //Ord(FBandType)); // todo: use symbolic values
  XML.SetValue(Path+'Condition/Value', FCondition);
  XML.SetValue(Path+'DatasetStr/Value', FDatasetStr);
  XML.SetValue(Path+'Child/Value', FChild);
end;

procedure TfrBandView.Draw(aCanvas: TCanvas);
var
  St     : String;
  R      : TRect;
begin
  fFrameWidth := 1;
  if BandType in [btCrossHeader..btCrossFooter] then
  begin
    y := 0;
    dy := frDesigner.Page.PrnInfo.Pgh;
  end
  else
  begin
    x := 0;
    dx := frDesigner.Page.PrnInfo.Pgw;
  end;
  BeginDraw(aCanvas);
  CalcGaps;
  with Canvas do
  begin
    //Brush.Bitmap := SBmp;
    Brush.Bitmap := nil;
    Brush.Style := bsSolid;
    Brush.Color:=clBtnFace;
    FillRect(DRect);
    Brush.Color:=clLtGray;
    Brush.Style:=bsDiagCross;
    FillRect(DRect);
    frInitFont(Font,clBlack,8,[]);
    Pen.Width := 1;
    Pen.Color := clBtnFace;
    Pen.Style := psSolid;
    Brush.Style := bsClear;
    Rectangle(x, y, x + dx + 1, y + dy + 1);
    Brush.Color := clBtnFace;
    Brush.Style := bsSolid;
    CalcTitleSize;
    R := GetTitleRect;
    if ShowBandTitles then
    begin
      FillRect(R);
      if BandType in [btCrossHeader..btCrossFooter] then
      begin
        Pen.Color := clBtnShadow;
        MoveTo(r.left, r.Bottom-2); LineTo(r.right, r.Bottom-2);
        Pen.Color := clBlack;
        MoveTo(r.left, r.Bottom-1); LineTo(r.right, r.Bottom-1);
        Pen.Color := clBtnHighlight;
        MoveTo(r.left, r.bottom-1); lineto(r.left, r.top);
        Font.Orientation := 900;
        Brush.Color:=clBtnFace;
        TextOut(r.Left + 3, r.bottom-6, frBandNames[BandType]);
      end
      else
      begin
        Pen.Color := clBtnShadow;
        MoveTo(r.Right-2, r.Top);
        LineTo(r.Right-2, r.Bottom);
        Pen.Color := clBlack;
        MoveTo(r.Right-1, r.Top);
        LineTo(r.Right-1, r.Bottom);
        st:=frBandNames[BandType];
        Font.Orientation := 0;
        Brush.Color:=clBtnFace;
        TextOut(r.left+5, r.top+1, st);
      end;
    end
    else
    begin
      Brush.Style := bsClear;
      if BandType in [btCrossHeader..btCrossFooter] then
      begin
        Font.Orientation := 900;
        Brush.Color:=clBtnFace;
        TextOut(x + 2, r.bottom-6, frBandNames[BandType]);
      end
      else
      begin
        Font.Orientation := 0;
        Brush.Color:=clBtnFace;
        TextOut(x + 4, y + 2, frBandNames[BandType]);
      end;
    end;
  end;
end;

function TfrBandView.GetClipRgn(rt: TfrRgnType): HRGN;
var
  R,R1,R2: HRGN;
begin
  if not ShowBandTitles then
  begin
    Result := inherited GetClipRgn(rt);
    Exit;
  end;

  if rt = rtNormal then
    R1 := CreateRectRgn(x, y, x + dx + 1, y + dy + 1)
  else
    R1 := CreateRectRgn(x - 10, y - 10, x + dx + 10, y + dy + 10);

  with GetTitleRect do
    R := CreateRectRgn(Left,Top,Right,Bottom);

  R2:=CreateRectRgn(0,0,0,0);

  CombineRgn(R2, R, R1, RGN_OR);
  Result:=R2;

  
  DeleteObject(R);
  DeleteObject(R1);
end;

function TfrBandView.PointInView(aX,aY: Integer): Boolean;
var
    Rc : TRect;
begin
  Rc:=Bounds(x, y,dx+1,dy + 1);
  Result:=((aX>Rc.Left) and (aX<Rc.Right) and (aY>Rc.Top) and (aY<Rc.Bottom));
  {$IFDEF DebugLR}
  DebugLn('PointInView, Bounds=%s Point=%d,%d Res=%s',[dbgs(rc),ax,ay,BoolToStr(result)]);
  {$ENDIF}

  if not Result and ShowBandTitles then
  begin
    Rc := GetTitleRect;
    Result := PtInRect(Rc, Point(Ax,Ay));
    {$IFDEF DebugLR}
    DebugLn('PointInView, TitleRect=%s Point=%d,%d Res=%s',[dbgs(rc),ax,ay,BoolToStr(result)]);
    {$ENDIF}
  end;
end;

procedure TfrBandView.DefinePopupMenu(Popup: TPopupMenu);
var
  m: TMenuItem;
begin
  if BandType in [btReportTitle, btReportSummary, btPageHeader, btCrossHeader,
    btMasterHeader..btSubDetailFooter, btGroupHeader, btGroupFooter, btChild] then
    inherited DefinePopupMenu(Popup);

  if BandType in [btReportTitle, btReportSummary, btMasterData, btDetailData,
    btSubDetailData, btMasterFooter, btDetailFooter,
    btSubDetailFooter, btGroupHeader] then
  begin
    m := TMenuItem.Create(Popup);
    m.Caption := sFormNewPage;
    m.OnClick := @P1Click;
    m.Checked := (Flags and flBandNewPageAfter) <> 0;
    Popup.Items.Add(m);
  end;

  if BandType in [btMasterData, btDetailData] then
  begin
    m := TMenuItem.Create(Popup);
    m.Caption := sPrintIfSubsetEmpty;
    m.OnClick := @P2Click;
    m.Checked := (Flags and flBandPrintIfSubsetEmpty) <> 0;
    Popup.Items.Add(m);
  end;

  if BandType in [btReportTitle, btReportSummary, btMasterHeader..btSubDetailFooter,
    btGroupHeader, btGroupFooter] then
  begin
    m := TMenuItem.Create(Popup);
    m.Caption := sBreaked;
    m.OnClick := @P3Click;
    m.Checked := (Flags and flBandPageBreak) <> 0;
    Popup.Items.Add(m);
  end;

  if BandType in [btPageHeader, btPageFooter] then
  begin
    m := TMenuItem.Create(Popup);
    m.Caption := sOnFirstPage;
    m.OnClick := @P4Click;
    m.Checked := (Flags and flBandOnFirstPage) <> 0;
    Popup.Items.Add(m);
  end;

  if BandType = btPageFooter then
  begin
    m := TMenuItem.Create(Popup);
    m.Caption := sOnLastPage;
    m.OnClick := @P5Click;
    m.Checked := (Flags and flBandOnLastPage) <> 0;
    Popup.Items.Add(m);
  end;

  if BandType in [btMasterHeader, btDetailHeader, btSubDetailHeader,
    btCrossHeader, btGroupHeader] then
  begin
    m := TMenuItem.Create(Popup);
    m.Caption := sRepeatHeader;
    m.OnClick := @P6Click;
    m.Checked := (Flags and flBandRepeatHeader) <> 0;
    Popup.Items.Add(m);
  end;

  if BandType <> btPageFooter then
  begin
    m := TMenuItem.Create(Popup);
    m.Caption := sPrintChildIfNotVisible;
    m.OnClick := @P7Click;
    m.Checked := (Flags and flBandPrintChildIfNotVisible) <> 0;
    Popup.Items.Add(m);
  end;

  if not (BandType in [btChild, btPageFooter]) then
  begin
    m := TMenuItem.Create(Popup);
    m.Caption := sKeepChild;
    m.OnClick := @P8Click;
    m.Checked := (Flags and flBandKeepChild) <> 0;
    Popup.Items.Add(m);
  end;
end;

procedure TfrBandView.P1Click(Sender: TObject);
var
  i: Integer;
  t: TfrView;
begin
  frDesigner.BeforeChange;
  with Sender as TMenuItem do
  begin
    Checked := not Checked;
    for i := 0 to frDesigner.Page.Objects.Count - 1 do
    begin
      t :=TfrView(frDesigner.Page.Objects[i]);
      if t.Selected then
        t.Flags := (t.Flags and not flBandNewPageAfter) +
          Word(Checked) * flBandNewPageAfter;
    end;
  end;
end;

procedure TfrBandView.P2Click(Sender: TObject);
var
  i: Integer;
  t: TfrView;
begin
  frDesigner.BeforeChange;
  with Sender as TMenuItem do
  begin
    Checked := not Checked;
    for i := 0 to frDesigner.Page.Objects.Count - 1 do
    begin
      t :=TfrView(frDesigner.Page.Objects[i]);
      if t.Selected then
        t.Flags := (t.Flags and not flBandPrintifSubsetEmpty) +
          Word(Checked) * flBandPrintifSubsetEmpty;
    end;
  end;
end;

procedure TfrBandView.P3Click(Sender: TObject);
var
  i: Integer;
  t: TfrView;
begin
  frDesigner.BeforeChange;
  with Sender as TMenuItem do
  begin
    Checked := not Checked;
    for i := 0 to frDesigner.Page.Objects.Count - 1 do
    begin
      t :=TfrView(frDesigner.Page.Objects[i]);
      if t.Selected then
        t.Flags := (t.Flags and not flBandPageBreak) + Word(Checked) * flBandPageBreak;
    end;
  end;
end;

procedure TfrBandView.P4Click(Sender: TObject);
begin
  frDesigner.BeforeChange;
  with Sender as TMenuItem do
  begin
    Checked := not Checked;
    Flags := (Flags and not flBandOnFirstPage) + Word(Checked) * flBandOnFirstPage;
  end;
end;

procedure TfrBandView.P5Click(Sender: TObject);
begin
  frDesigner.BeforeChange;
  with Sender as TMenuItem do
  begin
    Checked := not Checked;
    Flags := (Flags and not flBandOnLastPage) + Word(Checked) * flBandOnLastPage;
  end;
end;

procedure TfrBandView.P6Click(Sender: TObject);
begin
  frDesigner.BeforeChange;
  with Sender as TMenuItem do
  begin
    Checked := not Checked;
    Flags := (Flags and not flBandRepeatHeader) + Word(Checked) * flBandRepeatHeader;
  end;
end;

procedure TfrBandView.P7Click(Sender: TObject);
begin
  frDesigner.BeforeChange;
  with Sender as TMenuItem do
  begin
    Checked := not Checked;
    Flags := (Flags and not flBandPrintChildIfNotVisible) + Word(Checked) * flBandPrintChildIfNotVisible;
  end;
end;

procedure TfrBandView.P8Click(Sender: TObject);
begin
  frDesigner.BeforeChange;
  with Sender as TMenuItem do
  begin
    Checked := not Checked;
    Flags := (Flags and not flBandKeepChild) + Word(Checked) * flBandKeepChild;
  end;
end;

function TfrBandView.GetTitleRect: TRect;
begin
  if BandType in [btCrossHeader..btCrossFooter] then
    result := rect(x - 18, y, x, y + TitleSize + 10)
  else
    result := rect(x, y-18, x + TitleSize + 10, y);
end;

function TfrBandView.TitleSize: Integer;
begin
  if MaxTitleSize<100 then
    result := 100
  else
    result := MaxTitleSize;
end;

procedure TfrBandView.CalcTitleSize;
var
  Bt: TfrBandType;
  W: Integer;
begin
  if MaxTitleSize=0 then begin
    MaxTitleSize := Canvas.TextWidth('-'); // work around gtk2 first calc is not right
    for bt := btReportTitle to btNone do begin
      W := Canvas.TextWidth(frBandNames[bt]);
      if W>MaxTitleSize then
        MaxTitleSize := W;
    end;
  end;
end;

procedure TfrBandView.FixPrintChildIfNotVisible;
begin
  if ((frVersion=28) or (frVersion=29)) and (flags and $80 <> 0) then
  begin
    flags := flags and not $80;
    flags := flags or flBandPrintChildIfNotVisible;
  end;
end;

procedure TfrBandView.SetHeight(const AValue: Double);
begin
  inherited SetHeight(AValue);
  if Assigned(Parent) then
    Parent.dy := Round(Avalue);
end;

procedure TfrBandView.SetVisible(AValue: Boolean);
begin
  inherited SetVisible(AValue);
  if Assigned(Parent) then
    Parent.Visible := Avalue;
end;

procedure TfrSubReportView.AfterLoad;
begin
  inherited AfterLoad;
  FSubPage:= CurReport.Pages[FSubPageIndex];
end;

{----------------------------------------------------------------------------}
constructor TfrSubReportView.Create(AOwnerPage: TfrPage);
begin
  inherited Create(AOwnerPage);
  Typ := gtSubReport;
  BaseName := 'SubReport';
end;

procedure TfrSubReportView.Assign(Source: TPersistent);
begin
  inherited Assign(Source);
  if Source is TfrSubReportView then
    FSubPage := TfrSubReportView(Source).FSubPage;
end;

procedure TfrSubReportView.Draw(aCanvas: TCanvas);
begin
  BeginDraw(aCanvas);
  fFrameWidth := 1;
  CalcGaps;
  with aCanvas do
  begin
    Font.Name := 'Arial';
    Font.Style := [];
    Font.Size := 8;
    Font.Color := clBlack;
    Font.Charset := frCharset;
    Pen.Width := 1;
    Pen.Color := clBlack;
    Pen.Style := psSolid;
    Brush.Color := clWhite;
    Rectangle(x, y, x + dx + 1, y + dy + 1);
    Brush.Style := bsClear;
    TextRect(DRect, x + 2, y + 2, sSubReportOnPage + ' ' + IntToStr(SubPage.PageIndex + 1));
  end;
  RestoreCoord;
end;

procedure TfrSubReportView.DefinePopupMenu(Popup: TPopupMenu);
begin
  // no specific items in popup menu
end;

procedure TfrSubReportView.LoadFromStream(Stream: TStream);
begin
  inherited LoadFromStream(Stream);
  Stream.Read(FSubPageIndex, 4);
end;

procedure TfrSubReportView.LoadFromXML(XML: TLrXMLConfig; const Path: String);
begin
  inherited LoadFromXML(XML, Path);
  FSubPageIndex := XML.GetValue(Path+'SubPage/Value'{%H-}, 0); // todo chk
end;

procedure TfrSubReportView.SaveToStream(Stream: TStream);
begin
  inherited SaveToStream(Stream);
  Stream.Write(SubPage, 4);
end;

procedure TfrSubReportView.SaveToXML(XML: TLrXMLConfig; const Path: String);
begin
  inherited SaveToXML(XML, Path);
  FSubPageIndex:=FSubPage.PageIndex;
  XML.SetValue(Path+'SubPage/Value'{%H-}, FSubPageIndex);
end;

{----------------------------------------------------------------------------}
constructor TfrPictureView.Create(AOwnerPage: TfrPage);
begin
  inherited Create(AOwnerPage);
  Typ := gtPicture;
  fPicture := TPicture.Create;
  Flags := flStretched + flPictRatio;
  BaseName := 'Picture';
end;

destructor TfrPictureView.Destroy;
begin
  Picture.Free;
  inherited Destroy;
end;

procedure TfrPictureView.Assign(Source: TPersistent);
begin
  inherited Assign(Source);
  if Source is TfrPictureView then
  begin
    Picture.Assign(TfrPictureView(Source).Picture);
    FSharedName := TFrPictureView(Source).SharedName;
  end;
end;

procedure TfrPictureView.Draw(aCanvas: TCanvas);
var
  r: TRect;
  kx, ky: Double;
  w, h, w1, h1, PictureHeight, PictureWidth: Integer;
  {$IFDEF LCLNOGUI}
  bmp: TLazreportBitmap;
  {$ELSE}
  ClipRgn, PreviousClipRgn: HRGN;
  ClipNeeded: Boolean;
  {$ENDIF}

begin
  {$IFDEF DebugLR}
  DebugLnEnter('TfrPictureView.Draw INI');
  {$ENDIF}
  BeginDraw(aCanvas);
  CalcGaps;
  w := DRect.Right - DRect.Left - 1;
  h := DRect.Bottom - DRect.Top - 1;
  with aCanvas do
  begin
    ShowBackground;
    if ((Picture.Graphic = nil) or Picture.Graphic.Empty) and (DocMode = dmDesigning) then
    begin
      Font.Name := 'Arial';
      Font.Size := 8;
      Font.Style := [];
      Font.Color := clBlack;
      Font.Charset := frCharset;
      TextOut(x + 2, y + 2, sPicture);
    end
    else if not ((Picture.Graphic = nil) or Picture.Graphic.Empty) then
    begin
      r := DRect;
      Dec(r.Bottom);
      Dec(r.Right);
      if (Flags and flStretched) <> 0 then
      begin
        if (Flags and flPictRatio) <> 0 then
        begin
          kx := dx / Picture.Width;
          ky := dy / Picture.Height;
          if kx < ky then
            r.Bottom := r.Top + Round(Picture.Height * kx)
          else
            r.Right := r.Left + Round(Picture.Width * ky);
          w1 := r.Right - r.Left;
          h1 := r.Bottom - r.Top;
          if (Flags and flPictCenter) <> 0 then
            OffsetRect(r, (w - w1) div 2, (h - h1) div 2);
        end;
        {$IFDEF LCLNOGUI}
        bmp := TLazreportBitmap.create;
        bmp.LoadFromGraphic(Picture.Graphic);
        TVirtualCanvas(aCanvas).StretchDraw(r, bmp);
        bmp.Free;
        {$ELSE}
        StretchDraw(r, Picture.Graphic);
        {$ENDIF}
      end
      else
      begin
        PictureWidth := Round(Picture.Width * ScaleX);
        PictureHeight := Round(Picture.Height * ScaleY);
        if (Flags and flPictCenter) <> 0 then
          OffsetRect(r, (w - PictureWidth) div 2, (h - PictureHeight) div 2);
        {$IFDEF LCLNOGUI}
        bmp := TLazreportBitmap.create;
        bmp.LoadFromGraphic(Picture.Graphic);
        TVirtualCanvas(aCanvas).Draw(r.Left, r.Top, bmp);
        bmp.Free;
        {$ELSE}
        ClipNeeded := (PictureHeight > h) or (PictureWidth > w);
        if ClipNeeded then
        begin
          ClipRgn := CreateRectRgn(r.Left, r.Top, r.Right, r.Bottom);
          PreviousClipRgn := CreateRectRgn(0, 0, 0, 0);
          LCLIntf.GetClipRgn(Handle, PreviousClipRgn);
          SelectClipRgn(Handle, ClipRgn);
        end;
        r.Right := r.Left + PictureWidth;
        r.Bottom := r.Top + PictureHeight;
        StretchDraw(r, Picture.Graphic);
        if ClipNeeded then
        begin
          SelectClipRGN(Handle, PreviousClipRgn);
          DeleteObject(PreviousClipRgn);
          DeleteObject(ClipRgn);
        end;
        {$ENDIF}
      end;
    end;
    ShowFrame;
  end;
  RestoreCoord;
  {$IFDEF DebugLR}
  DebugLnExit('TfrPictureView.Draw DONE');
  {$ENDIF}
end;

const
  pkNone = 0;
  pkBitmap = 1;
  pkMetafile = 2;
  pkIcon = 3;
  pkJPEG = 4;
  pkPNG  = 5;
  pkAny  = 255;

procedure StreamToXML(XML: TLrXMLConfig; Path: String; Stream: TStream);
var
  Buf: array[0..1023] of byte;
  S: string;
  i,c: integer;
  procedure WriteBuf(Count: Integer);
  var
    j: Integer;
    St: string[3];
  begin
    for j:=0 to Count-1 do begin
      St := IntToHex(Buf[j], 2);
      Move(St[1], S[C], 2);
      inc(c,2);
    end;
  end;
begin
  XML.SetValue(Path+'Size/Value'{%H-}, Stream.Size);
  SetLength(S, Stream.Size*2);
  c := 1;
  for i:=1 to Stream.Size div SizeOf(Buf) do begin
    Stream.Read(Buf{%H-}, SizeOf(buf));
    WriteBuf(SizeOf(Buf));
  end;
  i := Stream.Size mod SizeOf(Buf);
  if i>0 then begin
    Stream.Read(Buf, i);
    Writebuf(i);
  end;
  XML.SetValue(Path+'Data/Value', S);
end;

procedure XMLToStream(XML: TLrXMLConfig; Path: String; Stream: TStream);
var
  S: String;
  i,Size,{%H-}cd: integer;
  B: Byte;
begin
  Size := XML.GetValue(Path+'Size/Value'{%H-}, 0);
  if Size>0 then begin
    S := XML.GetValue(Path+'Data/Value', '');
    if S<>'' then
      for i:=1 to Size do begin
        Val('$'+S[i*2-1]+S[i*2], B, cd);
        Stream.Write(B, 1);
      end;
  end;
end;

procedure TfrPictureView.LoadFromStream(Stream: TStream);
var
  b: Byte;
  n: Integer;
  Graphic: TGraphic;
begin
  inherited LoadFromStream(Stream);
  b := 0;
  Stream.Read(b, 1);

  if frVersion<=23 then
  begin
    n := 0;
    Stream.Read(n, 4);
    Graphic := PictureTypeToGraphic(b);
    if b=pkMetafile then
      raise exception.Create('LazReport does not support TMetafile');
  end else
  begin
    if b=pkAny then
      Graphic := ExtensionToGraphic(Stream.ReadAnsiString)
    else
      Graphic := PictureTypeToGraphic(b);
    FSharedName := Stream.ReadAnsiString;
    n := 0;
    Stream.Read(n, 4);
  end;

  Picture.Graphic := Graphic;
  if Graphic <> nil then
  begin
    Graphic.Free;
    Picture.Graphic.LoadFromStream(Stream);
  end;
  Stream.Seek(n, soFromBeginning);
end;

procedure TfrPictureView.LoadFromXML(XML: TLrXMLConfig; const Path: String);
var
  b: Byte;
  m: TMemoryStream;
  Graphic: TGraphic;
  Ext: string;

  procedure GetPictureStream;
  begin
    M := TMemoryStream.Create;
    try
      XMLToStream(XML, Path+'Picture/', M);
    except
      M.Free;
      M := nil;
    end;
  end;

begin
  inherited LoadFromXML(XML, Path);

  SharedName := XML.GetValue(Path+'Picture/SharedName/Value','');
  b := XML.GetValue(Path+'Picture/Type/Value'{%H-}, pkNone);
  Ext := XML.GetValue(Path+'Picture/Type/Ext', '');

  M := nil;
  if (b=pkAny) and (Ext<>'') then
    Graphic := ExtensionToGraphic(Ext)
  else
  if (b>pkBitmap) and (b<pkAny) then
    Graphic := PictureTypeToGraphic(b)
  else begin
    GetPictureStream;
    Graphic := StreamToGraphic(M);
  end;

  Picture.Graphic := Graphic;
  try
    if Graphic <> nil then
    begin
      Graphic.Free;
      if M=nil then
        GetPictureStream;
      try
        M.Position := 0;
        Picture.Graphic.LoadFromStream(M);
      except
        ShowMessage('Unknown Image Format!');
      end;
    end;
  finally
    M.Free;
  end;
end;

procedure TfrPictureView.SaveToStream(Stream: TStream);
var
  b: Byte;
  n, o: Integer;
  ext: string;
begin
  inherited SaveToStream(Stream);

  b := GetPictureType;
  Stream.Write(b, 1);
  if b<>pkNone then
  begin
    ext := GraphicExtension(TGraphicClass(Picture.Graphic.ClassType));
    Stream.WriteAnsiString(ext);
  end;
  Stream.WriteAnsiString(FSharedName);
  n := Stream.Position;
  Stream.Write(n, 4);
  if b <> pkNone then
    Picture.Graphic.SaveToStream(Stream);
  o := Stream.Position;
  Stream.Seek(n, soFromBeginning);
  Stream.Write(o, 4);
  Stream.Seek(0, soFromEnd);
end;

procedure TfrPictureView.SaveToXML(XML: TLrXMLConfig; const Path: String);
var
  b: Byte;
  m: TMemoryStream;
begin
  inherited SaveToXML(XML, Path);
  b := GetPictureType;

  XML.SetValue(Path+'Picture/SharedName/Value', SharedName);
  XML.SetValue(Path+'Picture/Type/Value'{%H-}, b);
  if b <> pkNone then
  begin
    XML.SetValue(Path+'Picture/Type/Ext',
                 GraphicExtension(TGraphicClass(Picture.Graphic.ClassType)));
    M := TMemoryStream.Create;
    try
      Picture.Graphic.SaveToStream(M);
      M.Position:=0;
      StreamToXML(XML, Path+'Picture/', M);
    finally
      M.Free;
    end;
  end;
end;

procedure TfrPictureView.GetBlob(b: TfrTField);
var
  s: TStream;
  GraphExt: string;
  gc: TGraphicClass;
  AGraphic: TGraphic;
  CurPos: Int64;

  function LoadImageFromStream: boolean;
  begin
    result := (s<>nil);
    if result then
      try
        curPos := s.Position;
        Picture.LoadFromStream(s);
      except
        s.Position := Curpos;
        result := false;
      end;
  end;

  procedure GraphExtToClass;
  begin
    gc := GetGraphicClassForFileExtension(GraphExt);
  end;

  procedure ReadImageHeader;
  begin
    CurPos := s.Position;
    try
      GraphExt := s.ReadAnsiString;
    except
      s.Position := CurPos;
      GraphExt := '';
    end;
    GraphExtToClass;
    if gc=nil then
      s.Position := CurPos;
  end;

begin

  Picture.Clear;

  if b.IsNull then
    exit;

  // todo: TBlobField.AssignTo is not implemented yet
  s := TDataset(FDataSet).CreateBlobStream(TField(b),bmRead);
  if (s=nil) or (s.Size = 0) then
  begin
    s.Free;
    exit;
  end;

  try
    GraphExt := '';
    AGraphic := nil;

    if assigned(CurReport.OnDBImageRead) then
      begin
      // External method to identify graphic type
      // returns file extension for graphic type (e.g. jpg)
      // If user implements CurReport.OnDBImageRead, the control assumes that
      // the programmer either:
      //
      // -- Returns a valid identifier that matches a graphic class and
      //    the remainder of stream contains the image data. An instance of
      //    of graphic class will be used to load the image data.
      // or
      // -- Returns an invalid identifier that doesn't match a graphic class
      //    and the remainder of stream contains the image data. The control
      //    will try to load the image trying to identify the format
      //    by it's content
      //
      // In particular, returning an invalid identifier while the stream has
      // a image header will not work.
      CurReport.OnDBImageRead(self,s,GraphExt);
      GraphExtToClass;
      end
    else
      ReadImageHeader;

    if gc<>nil then
      begin
      AGraphic := gc.Create;
      AGraphic.LoadFromStream(s);
      Picture.Assign(AGraphic);
      end
    else
      begin
      if not LoadImageFromStream then
        Picture.Clear;
      end;

  finally
    s.Free;
    AGraphic.Free;
  end;

end;

procedure TfrPictureView.DefinePopupMenu(Popup: TPopupMenu);
var
  m: TMenuItem;
begin
  inherited DefinePopupMenu(Popup);
  m := TMenuItem.Create(Popup);
  m.Caption := sPictureCenter;
  m.OnClick := @P1Click;
  m.Checked := Centered;
  Popup.Items.Add(m);

  m := TMenuItem.Create(Popup);
  m.Caption := sKeepAspectRatio;
  m.OnClick := @P2Click;
  m.Enabled := Stretched;
  if m.Enabled then
    m.Checked := KeepAspect;
  Popup.Items.Add(m);
end;

procedure TfrPictureView.P1Click(Sender: TObject);
begin
  MenuItemCheckFlag(Sender, flPictCenter);
end;

function TfrPictureView.GetKeepAspect: boolean;
begin
  Result:=((Flags and flPictRatio)<>0);
end;

function TfrPictureView.GetCentered: boolean;
begin
  Result:=((Flags and flPictCenter)<>0);
end;

procedure TfrPictureView.P2Click(Sender: TObject);
begin
  MenuItemCheckFlag(Sender, flPictRatio);
end;

function TfrPictureView.GetPictureType: byte;
begin
  result := pkNone;
  if Picture.Graphic <> nil then
    result := pkAny;
end;

function TfrPictureView.PictureTypeToGraphic(b: Byte): TGraphic;
begin
  result := nil;
  case b of
    pkBitmap:   result := TBitmap.Create;
    pkIcon:     result := TIcon.Create;
    pkJPEG:     result := TJPEGImage.Create;
    pkPNG:      result := TPortableNetworkGraphic.Create;
  end;
end;

function TfrPictureView.ExtensionToGraphic(const Ext: string): TGraphic;
var
  AGraphicClass: TGraphicClass;
begin
  AGraphicClass := GetGraphicClassForFileExtension(Ext);
  if AGraphicClass<>nil then
    result := AGraphicClass.Create
  else
    result := nil;
end;

procedure TfrPictureView.SetCentered(AValue: boolean);
begin
  if Centered<>AValue then
    ModifyFlag(flPictCenter, AValue);
end;

procedure TfrPictureView.SetKeepAspect(AValue: boolean);
begin
  if KeepAspect<>AValue then
    ModifyFlag(flPictRatio, AValue);
end;

function TfrPictureView.StreamToGraphic(M: TMemoryStream): TGraphic;

  function ReadString(Len: Integer): string;
  begin
    SetLength(result, Len);
    M.Read(result[1], Len);
  end;

  function TestStreamIsPNG: boolean;
  begin
    result := ReadString(8) = #137'PNG'#13#10#26#10;
    M.Position := 0;
  end;

  function TestStreamIsJPEG: boolean;
  begin
    Result := ReadString(4) = #$FF#$D8#$FF#$E0;
    if result then begin
      M.Position := 6;
      result := ReadString(5) = 'JFIF'#0
    end;
    M.Position := 0;
  end;

begin

  if M=nil then begin
    result := nil;
    exit;
  end;

  M.Position := 0;

  if TestStreamIsBMP(M) then
  begin
    result := PictureTypeToGraphic(pkBitmap);
    exit;
  end;

  if TestStreamIsIcon(M) then begin
    result := PictureTypeToGraphic(pkIcon);
    exit;
  end;

  if TestStreamIsXPM(M) then
  begin
    result := TPixmap.Create;
    exit;
  end;

  if TestStreamIsPNG then
  begin
    result := PictureTypeToGraphic(pkPNG);
    exit;
  end;

  if TestStreamIsJPEG then
  begin
    result := PictureTypeToGraphic(pkJPEG);
    exit;
  end;

  result := nil;
end;

procedure TfrPictureView.SetPicture(const AValue: TPicture);
begin
  BeforeChange;
  fPicture := AValue;
  AfterChange;
end;

function TfrLineView.GetFrames: TfrFrameBorders;
begin
  if dx > dy then
  begin
    dy := 0;
    fFrames:=[frbTop];
  end
  else
  begin
    dx := 0;
    fFrames:=[frbLeft];
  end;
  Result:=fFrames;
end;

{----------------------------------------------------------------------------}
constructor TfrLineView.Create(AOwnerPage: TfrPage);
begin
  inherited Create(AOwnerPage);
  Typ := gtLine;
  fFrames:=[frbLeft];
  BaseName := 'Line';
  SetBit(Flags, false, flStretched);
end;

procedure TfrLineView.Draw(aCanvas: TCanvas);
begin
  BeginDraw(aCanvas);
  GetFrames;
  CalcGaps;
  ShowFrame;
  RestoreCoord;
end;

function TfrLineView.GetClipRgn(rt: TfrRgnType): HRGN;
var
  bx, by, bx1, by1, dd: Integer;
begin
  bx := x; by := y; bx1 := x + dx + 1; by1 := y + dy + 1;
  if FrameStyle<>frsDouble then
    dd := Round(FrameWidth / 2)
  else
    dd := Round(FrameWidth * 1.5);
  if Frames=[frbLeft] then
  begin
    Dec(bx, dd);
    Inc(bx1, dd);
  end
  else
  begin
    Dec(by, dd);
    Inc(by1, dd);
  end;
  if rt = rtNormal then
    Result := CreateRectRgn(bx, by, bx1, by1)
  else
    Result := CreateRectRgn(bx - 10, by - 10, bx1 + 10, by1 + 10);
end;

function TfrLineView.PointInView(aX, aY: Integer): Boolean;
var
  bx, by, bx1, by1, w1: Integer;
  tmp: Double;
begin

  if FrameWidth<1.0 then
    tmp := 1.0
  else
    tmp := FrameWidth;

  if FrameStyle=frsDouble then
    w1 := Round(tmp * 1.5)
  else
    w1 := Round(tmp);

  bx:=x-w1;
  by:=y-w1;
  bx1:=x+dx+w1;
  by1:=y+dy+w1;

  Result:=(ax>=bx) and (ax<=bx1) and (ay>=by) and (ay<=by1);
end;

{----------------------------------------------------------------------------}
constructor TfrBand.Create(ATyp: TfrBandType; AParent: TfrPage);
begin
  inherited Create(nil);
  Typ := ATyp;
  Parent := AParent;
  Objects := TFpList.Create;
  Values := TStringList.Create;
  Next := nil;
  Positions[psLocal] := 1;
  Positions[psGlobal] := 1;
  Visible:=True;
end;

destructor TfrBand.Destroy;
begin
  if Next <> nil then
    Next.Free;
  Objects.Free;
  Values.Free;
  if DataSet <> nil then
    DataSet.Exit;
  if IsVirtualDS then
    DataSet.Free;
  if VCDataSet <> nil then
    VCDataSet.Exit;
  if IsVirtualVCDS then
    VCDataSet.Free;
  inherited Destroy;
end;

function TfrBand.IsDataBand: boolean;
begin
  result := (typ in [btMasterData, btDetailData, btSubDetailData]);
end;

function TfrBand.getName: string;
begin
  if Assigned(View) then
    Result:= View.Name
  else Result:= '';
end;

procedure TfrBand.InitDataSet(const Desc: String);
begin
  if Typ = btGroupHeader then
    GroupCondition := Desc
  else
    if Pos(';', Desc) = 0 then
      CreateDS(Desc, DataSet, IsVirtualDS);
  if (Typ = btMasterData) and (Dataset = nil) and
     (CurReport.ReportType = rtSimple) then
    DataSet := CurReport.Dataset;
end;

procedure TfrBand.DoError(const AErrorMsg: String);
var
  i: Integer;
begin
  ErrorFlag := True;
  ErrorStr := sErrorOccurred;
  for i := 0 to CurView.Memo.Count - 1 do
    ErrorStr := ErrorStr + LineEnding + CurView.Memo[i];
  ErrorStr := ErrorStr + LineEnding +
    sDoc + ' ' + CurReport.Name + LineEnding +
    sCurMemo + ' ' + CurView.Name;
  if Assigned(CurView.Parent) then
    ErrorStr := ErrorStr + LineEnding +
      sBand + ' ' + CurView.Parent.Name;  //frBandNames[Integer(CurView.Parent.Typ)];

  if AErrorMsg<>'' then
    ErrorStr := ErrorStr + LineEnding + AErrorMsg;

  MasterReport.Terminated := True;
end;

function TfrBand.CalcHeight: Integer;
var
  Bnd: TfrBand;
  DS : TfrDataSet;
  ddx: Integer;
  BM : Pointer;
  
  function SubDoCalcHeight(CheckAll: Boolean): Integer;
  var
    i, h, vh: Integer;
    t: TfrView;
  begin
    CurBand := Self;
    AggrBand := Self;
    Result := dy;
    for i := 0 to Objects.Count - 1 do
    begin
      t :=TfrView(Objects[i]);
      t.olddy := t.dy;
      if t is TfrStretcheable then
        if (t.Parent = Self) or CheckAll then
        begin
          vh := TfrStretcheable(t).CalcHeight;
          h := vh + t.y;
          {$IFDEF DebugLR}
          DebugLn('View=%s t.y=%d t.dy=%d vh=%d h=%d result=%d',[ViewInfo(t),t.y,t.dy,vh,h,result]);
          {$ENDIF}
          if h > Result then
            Result := h;
          if CheckAll then
            TfrStretcheable(t).DrawMode := drAll;
        end
    end;
  end;
begin
  {$IFDEF DebugLR}
  DebugLnEnter('TfrBand.CalcHeight INIT CurDy=%d',[dy]);
  {$ENDIF}
  Result := dy;
  if HasCross and (Typ <> btPageFooter) then
  begin
    Parent.ColPos := 1;
    CurReport.DoBeginColumn(Self);
    if Parent.BandExists(Parent.Bands[btCrossData]) then
    begin
      Bnd := Parent.Bands[btCrossData];
      if Bnd.DataSet <> nil then
        DS := Bnd.DataSet
      else
        DS := VCDataSet;
      if DS <> nil then
      begin
        BM:=DS.GetBookMark;
        DS.DisableControls;
        try
          DS.First;
          while not DS.Eof do
          begin
            ddx := 0;
            CurReport.DoPrintColumn(Parent.ColPos, ddx);
            CalculatedHeight := SubDoCalcHeight(True);
            if CalculatedHeight > Result then
              Result := CalculatedHeight;
            Inc(Parent.ColPos);
            DS.Next;
            if MasterReport.Terminated then break;
          end;
        finally
          DS.GotoBookMark(BM);
          DS.FreeBookMark(BM);
          DS.EnableControls;
        end;
      end;
    end;
  end
  else
    Result := SubDoCalcHeight(False);
  CalculatedHeight := Result;
  {$IFDEF DebugLR}
  DebugLnExit('TfrBand.CalcHeight DONE CalculatedHeight=%d',[CalculatedHeight]);
  {$ENDIF}
end;

procedure TfrBand.StretchObjects(MaxHeight: Integer);
var
  i: Integer;
  t: TfrView;
begin
  {$IFDEF DebugLR}
  DebugLnEnter('TfrBand.StretchObjects INIT MaxHeight=%d Self.dy=%d',[MaxHeight,Self.dy]);
  {$ENDIF}
  for i := 0 to Objects.Count - 1 do
  begin
    t :=TfrView(Objects[i]);
    if (t is TfrStretcheable) or (t is TfrLineView) then
      if (t.Flags and flStretched) <> 0 then
      begin
        {$IFDEF DebugLR}
        DebugLn('i=%d View=%s Antes: y=%d dy=%d',[i,ViewInfo(t), t.y,t.dy]);
        {$ENDIF}
        t.oldy := t.y;
        if t.dy=0 then
          t.y := t.y + (MaxHeight - self.dy)
        else
          t.dy := MaxHeight - t.y;
        {$IFDEF DebugLR}
        DebugLn('i=%d View=%s After: y=%d dy=%d',[i,ViewInfo(t), t.y,t.dy]);
        {$ENDIF}
      end;
  end;
  {$IFDEF DebugLR}
  DebugLnExit('TfrBand.StretchObjects DONE');
  {$ENDIF}
end;

procedure TfrBand.UnStretchObjects;
var
  i: Integer;
  t: TfrView;
begin
  for i := 0 to Objects.Count - 1 do
  begin
    t :=TfrView(Objects[i]);
    t.dy := t.olddy;
    t.y := t.oldy;
  end;
end;

procedure TfrBand.DrawObject(t: TfrView);
var
  ox,oy: Integer;
begin
  {$IFDEF DebugLR}
  DebugLnEnter('TfrBand.DrawObject INI y=%d t=%s Xadj=%d Margin=%d DiableDrawing=%s',
  [y,ViewInfoDIM(t),Parent.XAdjust,Parent.LeftMargin,BoolToStr(DisableDrawing,true)]);
  {$ENDIF}
  CurPage := Parent;
  CurBand := Self;
  AggrBand := Self;
  try
    if (t.Parent = Self) and not DisableDrawing then
    begin
      ox := t.x; Inc(t.x, Parent.XAdjust - Parent.LeftMargin);
      oy := t.y; Inc(t.y, y);
      t.Print(MasterReport.EMFPages[PageNo]^.Stream);
      t.x := ox; t.y := oy;
      if (t is TfrMemoView) and
         (TfrMemoView(t).DrawMode in [drAll, drAfterCalcHeight]) then
        Parent.AfterPrint;
    end;
  except
    on E:Exception do
      DoError(E.Message);
  end;
  {$IFDEF DebugLR}
  DebugLnExit('TfrBand.DrawObject DONE t=%s:%s',[dbgsname(t),t.name]);
  {$ENDIF}
end;

procedure TfrBand.PrepareSubReports;
var
  i: Integer;
  t: TfrView;
  Page: TfrPage;
begin
  for i := SubIndex to Objects.Count - 1 do
  begin
    t :=TfrView(Objects[i]);
    if t is TfrSubReportView then
    begin
      Page := (t as TfrSubReportView).SubPage;
      Page.Mode := pmBuildList;
      Page.FormPage;
      Page.CurY := y + t.y;
      Page.CurBottomY := Parent.CurBottomY;
      Page.XAdjust := Parent.XAdjust + t.x;
      Page.ColCount := 1;
      Page.PlayFrom := 0;
      EOFArr[i - SubIndex] := False;
    end;
  end;
  Parent.LastBand := nil;
end;

procedure TfrBand.DoSubReports;
var
  i: Integer;
  t: TfrView;
  Page: TfrPage;
begin
  repeat
    if not EOFReached then
      for i := SubIndex to Objects.Count - 1 do
      begin
        t :=TfrView(Objects[i]);
        if t is TfrSubReportView then
        begin
          Page := (t as TfrSubReportView).SubPage;
          if Typ = btPageFooter then
          begin
            Parent.CurY := Parent.Bands[btPageFooter].y + t.y;
            Parent.CurBottomY := Parent.Bands[btPageFooter].y +
                                Parent.Bands[btPageFooter].dy;
          end;
          Page.CurY := Parent.CurY;
          Page.CurBottomY := Parent.CurBottomY;
        end;
      end;
    EOFReached := True;
    MaxY := Parent.CurY;
    for i := SubIndex to Objects.Count - 1 do
    begin
      t :=TfrView(Objects[i]);
      if (t is TfrSubReportView) and (not EOFArr[i - SubIndex]) then
      begin
        Page := (t as TfrSubReportView).SubPage;
        if Page.PlayRecList then
          EOFReached := False
        else
        begin
          EOFArr[i - SubIndex] := True;
          if Page.CurY > MaxY then MaxY := Page.CurY;
        end;
      end;
    end;
    
    if not EOFReached then
    begin
      if Parent.Skip then
      begin
        Parent.LastBand := Self;
        Exit;
      end
      else
      if Typ <> btPageFooter then
        Parent.NewPage;
    end;
    
  until EOFReached or MasterReport.Terminated;
  
  for i := SubIndex to Objects.Count - 1 do
  begin
    t :=TfrView(Objects[i]);
    if t is TfrSubReportView then
    begin
      Page := (t as TfrSubReportView).SubPage;
      Page.ClearRecList;
    end;
  end;

  Parent.CurY := MaxY;
  Parent.LastBand := nil;
end;

function TfrBand.DrawObjects: Boolean;
var
  i: Integer;
  t: TfrView;
begin
  {$ifdef DebugLR}
  DebugLnEnter('DrawObjects INIT');
  {$endif}
  Result := False;
  for i := 0 to Objects.Count - 1 do
  begin
    t :=TfrView(Objects[i]);
    if t.Typ = gtSubReport then
    begin
      SubIndex := i;
      Result := True;
      PrepareSubReports;
      DoSubReports;
      break;
    end;

    t.Flags:=t.Flags and not (flStartRecord or flEndRecord);
    if i=0 then               t.Flags := t.Flags or flStartRecord;
    if i=Objects.Count-1 then t.Flags := t.Flags or flEndRecord;

    DrawObject(t);
    if MasterReport.Terminated then break;
  end;
  {$ifdef DebugLR}
  DebugLnExit('DrawObjects DONE result=%s',[BoolToStr(result,true)]);
  {$endif}
end;

procedure TfrBand.DrawCrossCell(Parnt: TfrBand; CurX: Integer);
var
  i, sfx, sfy: Integer;
  t: TfrView;
begin
  CurBand := Self;
  CurBand.Positions[psGlobal] := Parnt.Positions[psGlobal];
  CurBand.Positions[psLocal] := Parnt.Positions[psLocal];
  if Typ = btCrossData then
    AggrBand := Parnt;
  try
    for i := 0 to Objects.Count - 1 do
    begin
      t := TfrView(Objects[i]);
      if Parnt.Objects.IndexOf(t) <> -1 then
        if not DisableDrawing then
        begin
          sfx := t.x; Inc(t.x, CurX);
          sfy := t.y; Inc(t.y, Parnt.y);
    	  t.Print(MasterReport.EMFPages[PageNo]^.Stream);
	  if (t is TfrMemoView) and
             (TfrMemoView(t).DrawMode in [drAll, drAfterCalcHeight]) then
            Parent.AfterPrint;
          t.Parent := Self;
          t.x := sfx;
          t.y := sfy;
        end
        else
        begin
          CurView := t;
          frInterpretator.DoScript(t.Script);
        end;
    end;
  except
    on E:Exception do
      DoError(E.Message); //(E);
  end;
end;

procedure TfrBand.DrawCross;
var
  Bnd       : TfrBand;
  sfpage    : Integer;
  CurX, ddx : Integer;
  DS        : TfrDataSet;
  BM        : Pointer;
  
  procedure CheckColumnPageBreak(ddx: Integer);
  var
    sfy: Integer;
    b: TfrBand;
  begin
    if CurX + ddx > Parent.RightMargin then
    begin
      Inc(ColumnXAdjust, CurX - Parent.LeftMargin);
      CurX := Parent.LeftMargin;
      Inc(PageNo);
      if PageNo >= MasterReport.EMFPages.Count then
      begin
        MasterReport.EMFPages.Add(Parent);
        sfy := Parent.CurY;
        Parent.ShowBand(Parent.Bands[btOverlay]);
        Parent.CurY := Parent.TopMargin;
        if (sfPage <> 0) or
          ((Parent.Bands[btPageHeader].Flags and flBandOnFirstPage) <> 0) then
          Parent.ShowBand(Parent.Bands[btPageHeader]);
        Parent.CurY := sfy;
        CurReport.InternalOnProgress(PageNo);
      end;
      if Parent.BandExists(Parent.Bands[btCrossHeader]) then
        if (Parent.Bands[btCrossHeader].Flags and flBandRepeatHeader) <> 0 then
        begin
          b := Parent.Bands[btCrossHeader];
          b.DrawCrossCell(Self, Parent.LeftMargin);
          CurX := Parent.LeftMargin + b.dx;
        end;
    end;
  end;
begin
  ColumnXAdjust := 0;
  Parent.ColPos := 1;
  CurX := 0;
  sfpage := PageNo;
  if Typ = btPageFooter then Exit;
  IsColumns := True;
  CurReport.DoBeginColumn(Self);

  if Parent.BandExists(Parent.Bands[btCrossHeader]) then
  begin
    Bnd := Parent.Bands[btCrossHeader];
    Bnd.DrawCrossCell(Self, Bnd.x);
    CurX := Bnd.x + Bnd.dx;
  end;

  if Parent.BandExists(Parent.Bands[btCrossData]) then
  begin
    Bnd := Parent.Bands[btCrossData];
    if CurX = 0 then CurX := Bnd.x;
    if Bnd.DataSet <> nil then
      DS := Bnd.DataSet
    else
      DS := VCDataSet;
      
    if DS <> nil then
    begin
      BM:=DS.GetBookMark;
      DS.DisableControls;
      try
        DS.First;
        while not DS.Eof do
        begin
          ddx := Bnd.dx;
          CurReport.DoPrintColumn(Parent.ColPos, ddx);
          CheckColumnPageBreak(ddx);
          Bnd.DrawCrossCell(Self, CurX);

          if Typ in [btMasterData, btDetailData, btSubdetailData] then
            Parent.DoAggregate([btPageFooter, btMasterFooter, btDetailFooter,
               btSubDetailFooter, btGroupFooter, btCrossFooter, btReportSummary]);

          Inc(CurX, ddx);
          Inc(Parent.ColPos);
          DS.Next;
          if MasterReport.Terminated then break;
        end;
      finally
        DS.GotoBookMark(BM);
        DS.FreeBookMark(BM);
        DS.EnableControls;
      end;
    end;
  end;
  
  if Parent.BandExists(Parent.Bands[btCrossFooter]) then
  begin
    Bnd := Parent.Bands[btCrossFooter];
    if CurX = 0 then CurX := Bnd.x;
    CheckColumnPageBreak(Bnd.dx);
    AggrBand := Bnd;
    Bnd.DrawCrossCell(Self, CurX);
    Bnd.InitValues;
  end;
  PageNo := sfpage;
  ColumnXAdjust := 0;
  IsColumns := False;
end;

function TfrBand.CheckPageBreak(ay, ady: Integer; PBreak: Boolean): Boolean;
begin
  {$IFDEF DebugLR}
  DebugLnEnter('TfrBand.CheckPageBreak INI ay=%d ady=%d Pbreak=%d',[ay,ady,ord(pbreak)]);
  {$ENDIF}
  Result := False;
  with Parent do begin
    {$IFDEF DebugLR}
    DebugLn('ay+ColFoot.dy+ady=%d CurBottomY=%d',[ay+Bands[btColumnFooter].dy+ady,CurBottomY]);
    {$ENDIF}
    if not RowsLayout then begin
      if (Parent.Bands[btColumnFooter] <> self) and
      	(ay + Bands[btColumnFooter].dy + ady > CurBottomY) then
      begin
        if not PBreak then
          NewColumn(Self);
        Result := True;
      end;
    end;
  end;
  {$IFDEF DebugLR}
  DebugLnExit('TfrBand.CheckPageBreak END ay=%d ady=%d Result=%d',[ay,ady,ord(Result)]);
  {$ENDIF}
end;

function TfrBand.CheckNextColumn: boolean;
var
  BandHeight: Integer;
begin
  with Parent do begin
    if (CurColumn=0) and (typ=btMasterData) then begin
      BandHeight := DoCalcHeight;
      {$IFDEF DebugLR}
      DebugLn('TfrBand.CheckNextColumn INI CurY=%d BHeight=%d CurY+BH=%d CurBottomY=%d',
        [CurY,BandHeight,CurY+BandHeight,CurBottomY]);
      {$ENDIF}
      // check left height space when on last column
      if CurY + BandHeight>CurBottomY then
        NewPage;
      {$IFDEF DebugLR}
      DebugLn('TfrBand.CheckNextColumn END CurY=%d BHeight=%d CurY+BH=%d CurBottomY=%d',
        [CurY,BandHeight,CurY+BandHeight,CurBottomY]);
      {$ENDIF}
    end;
  end;
  Result := true;
end;

procedure TfrBand.DrawPageBreak;
var
  i, j, k, ty: Integer;
  newDy, oldy, olddy, aMaxy, newDy1: Integer;
  t: TfrView;
  Flag: Boolean;
  PgArr: array of integer;

  procedure CorrY(t: TfrView; dy: Integer);
  var
    i: Integer;
    t1: TfrView;
  begin
    for i := 0 to Objects.Count - 1 do
    begin
      t1 :=TfrView(Objects[i]);
      if t1 <> t then
        if (t1.y > t.y + t.dy) and (t1.x >= t.x) and (t1.x <= t.x + t.dx) then
          Inc(t1.y, dy);
    end;
  end;

begin
  {$IFDEF DebugLR}
  DebugLnEnter('DrawPageBreak INI y=%d Maxdy=%d',[y,maxdy]);
  {$ENDIF}
  SetLength(PgArr,0);
  for i := 0 to Objects.Count - 1 do
  begin
    t :=TfrView(Objects[i]);
    t.Selected := True;
    t.OriginalRect := Rect(t.x, t.y, t.dx, t.dy);
  end;

  if not CheckPageBreak(y, maxdy, True) then
    DrawObjects
  else
  begin

    // space left of each column after headers and footers
    newDy := Parent.CurBottomY - Parent.Bands[btColumnFooter].dy - y - 2;
    newDy1 := Parent.CurBottomY - Parent.Bands[btColumnFooter].dy    - 2;

    for i := 0 to Objects.Count - 1 do
    begin
      t :=TfrView(Objects[i]);
      if t is TfrStretcheable then
        TfrStretcheable(t).ActualHeight := 0;
      if t is TfrMemoView then
      begin
        {$IFDEF DebugLR}
        DebugLnEnter('CalcHeight Memo INI');
        {$ENDIF}
        TfrMemoView(t).CalcHeight; // wraps a memo onto separate lines
        t.Memo1.Assign(SMemo);
        {$IFDEF DebugLR}
        DebugLnExit('CalcHeight Memo DONE');
        {$ENDIF}
        // all stretcheable objects "end" at the same pixel
        // here t.y coordinate is relative to current band, so is 0 based

        // roughly, how many columns we will need?
        k := ((t.y+t.dy) div newDy) + 2; // +2 = 1 for probable remainder + 1 extra
        if k > Length(pgArr) then
          SetLength(pgArr, k);
      end;
    end;

    // some objects do not fully use "newdy" pixels on each page, because of
    // the granularity of "min height", some use as much space as "lines" fit
    for j:=0 to Length(pgArr)-1 do
    begin
      if j>0 then
        newDy := newDy1;
      pgArr[j] := newDy;

      for i := 0 to Objects.Count - 1 do
      begin
        // calc the number of pixels really used by stretchable objects
        // on each page.
        t :=TfrView(Objects[i]);
        if not (t is TfrStretcheable) then
          continue;

        ty := t.y;
        if j>0 then
          ty := 0;  // on each additional page, each object starts at 0, not t.y

        // additionally, when objects are drawn, they are offseted t.gapy pixels
        // but this is object dependant, for TfrMemoView they are.
        if (t is TfrMemoView) then
          ty := ty + t.InternalGapY;

        k := Max(TfrStretcheable(t).MinHeight, 1);
        pgArr[j] := Min(pgArr[j], ty + (newDy-ty) div k * k);
      end;
    end;

    k := 0;
    repeat
      if k>(Length(pgArr)-1) then
        break; // TODO: raise exception?
      newDy := pgArr[k];

      aMaxy := 0;
      {$IFDEF DebugLR}
      WriteLn('Parent.CurBottomy=',Parent.CurBottomY,' NewDY=',newDY);
      {$ENDIF}
      for i := 0 to Objects.Count - 1 do
      begin
        t :=TfrView(Objects[i]);
        if not t.Selected then
          continue;

        if (t.y >= 0) and (t.y < newdy) then
        begin
          if (t.y + t.dy < newdy) then
          begin
            // draw objects that fit on page and remove from
            // pending objects
            if aMaxy < t.y + t.dy then
              aMaxy := t.y + t.dy;
            DrawObject(t);
            t.Selected := False;
          end
          else
          begin
            // objects that doesn't fit on page
            if t is TfrStretcheable then
            begin
              olddy := t.dy;
              t.dy := newdy - t.y + 1;
              Inc(TfrStretcheable(t).ActualHeight, t.dy);
              if t.dy > TfrStretcheable(t).MinHeight then
              begin
                TfrStretcheable(t).DrawMode := drPart;
                DrawObject(t);
              end;
              t.dy := olddy;
            end
            else
              t.y := newdy
          end
        end
        else if t is TfrStretcheable then
        begin
          if (t.y < 0) and (t.y + t.dy >= 0) then
          begin
            // drawing the remaining part of some object
            if t.y + t.dy > newdy then
            begin
              {$IFDEF DebugLR}
              DebugLn('BIGGER THAN PAGE: t=%s Acumdy=%d y+dy=%d newdy=%d',
                [ViewInfoDIM(t), TfrStretcheable(t).ActualHeight, t.y + t.dy,newdy]);
              {$ENDIF}
              // the rest of "t" is too large to fit in the rest of the page
              oldy := t.y; olddy := t.dy;
              t.y := 0; t.dy := newdy;
              Inc(TfrStretcheable(t).ActualHeight, t.dy);
              TfrStretcheable(t).DrawMode := drPart;
              DrawObject(t);
              t.y := oldy; t.dy := olddy;
              t.Selected := true;
            end else
            begin
              {$IFDEF DebugLR}
              DebugLn('REMAINING OF PAGE: t=%s Acumdy=%d y+dy=%d newdy=%d',
                [ViewInfoDIM(t),TfrStretcheable(t).ActualHeight, t.y + t.dy,newdy]);
              {$ENDIF}
              // the rest of "t" fits within the remaining space on page
              oldy := t.y; olddy := t.dy;
              t.dy := t.y + t.dy;
              t.y := 0;
              Inc(TfrStretcheable(t).ActualHeight, t.dy);
              TfrStretcheable(t).DrawMode := drPart;
              DrawObject(t);
              if aMaxy < t.y + t.dy then
                aMaxy := t.y + t.dy;
              t.y := oldy; t.dy := olddy;
              CorrY(t, TfrStretcheable(t).ActualHeight - t.dy);
              t.Selected := False;
            end;
          end;
        end;

      end;
      Flag := False;
      for i := 0 to Objects.Count - 1 do
      begin
        t :=TfrView(Objects[i]);
        if t.Selected then Flag := True;
        Dec(t.y, newdy);
      end;

      if Flag then
        CheckPageBreak(y, 10000, False);
      y := Parent.CurY;

      inc(k);

      if MasterReport.Terminated then
        break;
    until not Flag;
    maxdy := aMaxy;
  end;
  for i := 0 to Objects.Count - 1 do
  begin
    t :=TfrView(Objects[i]);
    t.y := t.OriginalRect.Top;
    t.dy := t.OriginalRect.Bottom;
  end;
  Inc(Parent.CurY, maxdy);
  SetLength(pgArr, 0);
  {$IFDEF DebugLR}
  DebugLnExit('DrawPageBreak END Parent.CurY=%d',[Parent.CurY]);
  {$ENDIF}
end;

function TfrBand.HasCross: Boolean;
var
  i: Integer;
  t: TfrView;
begin
  Result := False;
  for i := 0 to Objects.Count - 1 do
  begin
    t :=TfrView(Objects[i]);
    if t.Parent <> Self then
    begin
      Result := True;
      break;
    end;
  end;
end;

procedure TfrBand.DoDraw;
var
  sfy, sh: Integer;
  UseY, WasSub: Boolean;

begin
  if Objects.Count = 0 then Exit;
  sfy := y;
  UseY := not (Typ in [btPageFooter, btOverlay, btNone]);
  if UseY then
    y := Parent.CurY;
  {$IFDEF DebugLR}
  DebugLnEnter('TfrBand.DoDraw INI Band=%s sfy=%d y=%d dy=%d XAdjust=%d CurY=%d Stretch=%d PageBreak=%d',
    [bandInfo(self), sfy, y, dy, Parent.XAdjust, parent.cury, Ord(Stretched), Ord(PageBreak)]);
  {$ENDIF}

  Parent.RowStarted := True;
    
  if Stretched then
  begin
    sh := CalculatedHeight;
    {$IFDEF DebugLR}
    DebugLn('Height=%d CalculatedHeight=%d',[dy,sh]);
    {$ENDIF}
    StretchObjects(sh);
    maxdy := sh;
    if not PageBreak then
      CheckPageBreak(y, sh, False);
    y := Parent.CurY;
    WasSub := False;
    if PageBreak then
    begin
      DrawPageBreak;
      sh := 0;
    end
    else
    begin
      WasSub := DrawObjects;
      if HasCross then
        DrawCross;
    end;
    UnStretchObjects;

    Parent.LastRowHeight := sh;

    if not WasSub then
      Inc(Parent.CurY, sh);
  end
  else
  begin

    if UseY then
    begin
      if not PageBreak then
        CheckPageBreak(y, dy, False);
      y := Parent.CurY;
    end;

    if PageBreak then
    begin
      maxdy := CalculatedHeight;
      DrawPageBreak;
      Parent.LastRowHeight := maxdy;
    end
    else
    begin
      WasSub := DrawObjects;
      if HasCross then
        DrawCross;
      if UseY and not WasSub then begin

        Parent.LastRowHeight := dy;

        if Parent.AdvanceRow(Self) then
          Inc(Parent.CurY, dy);
      end;
    end;
  end;
  y := sfy;
  if Typ in [btMasterData, btDetailData, btSubDetailData] then
    Parent.DoAggregate([btPageFooter, btMasterFooter, btDetailFooter,
                 btSubDetailFooter, btGroupFooter, btReportSummary]);
  {$IFDEF DebugLR}
  DebugLnExit('TfrBand.DoDraw END sfy=%d y=%d dy=%d xadjust=%d CurY=%d',
    [sfy, y, dy, parent.xadjust, parent.cury]);
  {$ENDIF}
end;

function TfrBand.DoCalcHeight: Integer;
var
  b: TfrBand;
begin
  if (Typ in [btMasterData, btDetailData, btSubDetailData]) and
    (Next <> nil) and (Next.Dataset = nil) then
  begin
    b := Self;
    Result := 0;
    repeat
      Result := Result + b.CalcHeight;
      b := b.Next;
    until b = nil;
  end
  else
  begin
    Result := dy;
    CalculatedHeight := dy;
    if Stretched then Result := CalcHeight;
  end;
  if (Flags and flBandKeepChild) <> 0 then
  begin
    b := Self.ChildBand;
    while Assigned(b) do
    begin
      Result := Result + b.CalcHeight;
      b := b.ChildBand;
    end;
  end;
end;

function TfrBand.Draw: Boolean;
var
  b: TfrBand;
begin
  {$IFDEF debugLr}
  DebugLnEnter('TFrBand.Draw INI Band=%s y=%d dy=%d vis=%s',[BandInfo(self),y,dy,BoolToStr(Visible,true)]);
  {$endif}
  Result := False;
  CurView := View;
  CurBand := Self;
  AggrBand := Self;
  CalculatedHeight := -1;
  ForceNewPage := False;
  ForceNewColumn := False;
  CurReport.DoBeginBand(Self);
  frInterpretator.DoScript(Script);

  if Parent.RowsLayout and IsDataBand then
  begin
    if Visible then
    begin
      if Objects.Count > 0 then
      begin
        if not (Typ in [btPageFooter, btOverlay, btNone]) then
        begin
          if Parent.Skip then
            exit
          else
            CheckNextColumn;
        end;
        EOFReached := True;
        // only masterdata band supported in RowsLayout columns report
        if typ=btMasterData then
        begin
          DoDraw;
          Parent.NextColumn(Self);
        end;
        if not EOFReached then
          Result := True;
      end;
    end;
  end
  else
  begin
    if Parent.RowsLayout and (typ<>btColumnHeader) then
      Parent.StartRowsLayoutNonDataBand(Self)
    else
    // new page was requested in script
    if ForceNewPage then
    begin
      Parent.CurColumn := Parent.ColCount - 1;
      Parent.NewColumn(Self);
    end;
    if ForceNewColumn then
      Parent.NewColumn(Self);

    if Visible then
    begin
      if Typ = btColumnHeader then
        Parent.LastStaticColumnY := Parent.CurY;
      if Typ = btPageFooter then
        y := Parent.CurBottomY;
      if Objects.Count > 0 then
      begin
        if not (Typ in [btPageFooter, btOverlay, btNone]) then
          if (Parent.CurY + DoCalcHeight > Parent.CurBottomY) and not PageBreak then
          begin
            Result := True;
            if Parent.Skip then
              Exit
            else
              CheckPageBreak(0, 10000, False);
          end;
        EOFReached := True;

        // dealing with multiple bands
        if (Typ in [btMasterData, btDetailData, btSubDetailData]) and
          (Next <> nil) and (Next.Dataset = nil) and (DataSet <> nil) then
        begin
          b := Self;
          repeat
            b.DoDraw;
            b := b.Next;
          until b = nil;
        end
        else
        begin
          DoDraw;
          if (ChildBand <> nil) then
            ChildBand.Draw;
          if not (Typ in [btMasterData, btDetailData, btSubDetailData, btGroupHeader]) and
            NewPageAfter then
            Parent.NewPage;
        end;
        if not EOFReached then Result := True;
      end;
    end
    // if band is not visible, just performing aggregate calculations
    // relative to it
    else
    begin
      if (ChildBand <> nil) and PrintChildIfNotVisible then
        ChildBand.Draw;
      if Typ in [btMasterData, btDetailData, btSubDetailData] then
        Parent.DoAggregate([btPageFooter, btMasterFooter, btDetailFooter,
                            btSubDetailFooter, btGroupFooter, btReportSummary]);
    end;

    // check if multiple pagefooters (in cross-tab report) - resets last of them
    if not DisableInit then
      if (Typ <> btPageFooter) or (PageNo = MasterReport.EMFPages.Count - 1) then
        InitValues;

    // if in rows layout, reset starting column after non-data band
    if Parent.RowsLayout and (typ<>btColumnHeader) then
      Parent.StartColumn;
  end;
  
  CurReport.DoEndBand(Self);
  Parent.LastBandType := typ;
  {$IFDEF debugLr}
  DebugLnExit('TFrBand.Draw END %s y=%d PageNo=%d EOFReached=',[dbgsname(self),y, PageNo]);
  {$endif}
end;

procedure TfrBand.InitValues;
var
  b: TfrBand;
begin
  if Typ = btGroupHeader then
  begin
    b := Self;
    while b <> nil do
    begin
      if b.FooterBand <> nil then
      begin
        b.FooterBand.Values.Clear;
        b.FooterBand.Count := 0;
      end;
      b.LastGroupValue := frParser.Calc(b.GroupCondition);
      b := b.Next;
    end;
  end
  else
  begin
    Values.Clear;
    Count := 0;
  end
end;

{$ifdef DebugLR}
function DecodeValue(s:string):string;
var
  p: Integer;
begin
  result := s;
  p := pos('=',result) + 2;
  if result<>'' then
    insert('|',result,p);
end;
{$endif}
procedure TfrBand.DoAggregate;
var
  i: Integer;
  t: TfrView;
  s: String;
  v: Boolean;
begin
  {$ifdef DebugLR}
  DebugLnEnter('TfrBand.DoAggregate INIT Band=%s',[BandInfo(self)]);
  {$endif}
 for i := 0 to Values.Count - 1 do
  begin
    s := Values[i];
    {$ifdef DebugLR}
    DbgOut('Mangling Values[',dbgs(i),']=',QuotedStr(DecodeValue(s)),' ==> ');
    {$endif}
    Values[i] := Copy(s, 1, Pos('=', s) - 1) + '=0' + Copy(s, Pos('=', s) + 2, 255);
    {$ifdef DebugLR}
    DebugLn(QuotedStr(DecodeValue(Values[i])));
    {$endif}
  end;

  v := Visible;
  Visible := False;
  AggrBand := Self;
  for i := 0 to Objects.Count - 1 do
  begin
    t :=TfrView(Objects[i]);
    CurView := t;
    if t is TfrMemoView then
      TfrMemoView(t).ExpandVariables;
  end;
  Visible := v;
  Inc(Count);
  {$ifdef DebugLR}
  DebugLnExit('TfrBand.DoAggregate DONE Band=%s',[BandInfo(self)]);
  {$endif}
end;

procedure TfrBand.ResetLastValues;
var
  i: Integer;
  t: TfrView;
begin
  for i := 0 to Objects.Count - 1 do
  begin
    t :=TfrView(Objects[i]);
    t.ResetLastValue;
  end;
end;

{----------------------------------------------------------------------------}
type
  TfrBandParts = (bpHeader, bpData, bpFooter);
const
  MAXBNDS = 3;
  Bnds: Array[1..MAXBNDS, TfrBandParts] of TfrBandType =
   ((btMasterHeader, btMasterData, btMasterFooter),
    (btDetailHeader, btDetailData, btDetailFooter),
    (btSubDetailHeader, btSubDetailData, btSubDetailFooter));


constructor TfrPage.Create(ASize, AWidth, AHeight: Integer;
  AOr: TPrinterOrientation);
begin
  {$ifdef DbgPrinter}
  DebugLnEnter('TfrPage.Create INIT');
  {$endif}

  Self.Create(nil);
  
  ChangePaper(ASize, AWidth, AHeight, AOr);
  PrintToPrevPage := False;
  UseMargins := True;
  {$ifdef DbgPrinter}
  DebugLnExit('TfrPage.Create END');
  {$endif}
end;

constructor TfrPage.CreatePage;
begin
  self.Create(nil);
end;

destructor TfrPage.Destroy;
begin
  Clear;
  Objects.Free;
  RTObjects.Free;
  ClearRecList;
  List.Free;
  fMargins.Free;
  if Assigned(frDesigner) and (frDesigner.Page = Self) then
    frDesigner.Page:=nil;
  inherited Destroy;
end;

procedure TfrPage.ChangePaper(ASize, AWidth, AHeight: Integer;
  AOr: TPrinterOrientation);
begin
  {$ifdef DbgPrinter}
  DebugLnEnter('TfrPage.ChangePaper INIT');
  {$endif}
  try
    Prn.SetPrinterInfo(ASize, AWidth, AHeight, AOr);
    Prn.FillPrnInfo(PrnInfo);
  except
    on E:exception do
    begin
      {$ifdef DbgPrinter}
      Debugln('Exception: %s', [E.Message]);
      {$endif}
    end;
  end;
  pgSize := Prn.PaperSize;
  Width := Prn.PaperWidth;
  Height := Prn.PaperHeight;
  Orientation:= Prn.Orientation;
  {$ifdef DbgPrinter}
  DebugLnExit('TfrPage.ChangePaper END pgSize=%d Width=%d Height=%d Orientation=%d',
    [pgSize,Width,Height,ord(Orientation)]);
  {$endif}
end;

procedure TfrPage.Clear;
begin
  while Objects.Count > 0 do
    Delete(0);
end;

procedure TfrPage.Delete(Index: Integer);
begin
  if not (doChildComponent in TfrView(Objects[Index]).FDesignOptions) then
    TfrView(Objects[Index]).Free;
  Objects.Delete(Index);
end;

function TfrPage.FindObjectByID(ID: Integer): Integer;
var
  i: Integer;
begin
  Result := -1;
  for i := 0 to Objects.Count - 1 do
  begin
    if TfrView(Objects[i]).ID = ID then
    begin
      Result := i;
      break;
    end;
  end;
end;

function TfrPage.FindObject(const aName: String): TfrObject;
var
  i: Integer;
begin
  Result := nil;
  if CompareText(Name, aName) = 0 then
    Result:=Self
  else
  for i := 0 to Objects.Count - 1 do
    if CompareText(TfrObject(Objects[i]).Name, aName) = 0 then
      Exit(TfrObject(Objects[i]));
end;

function TfrPage.FindRTObject(const aName: String): TfrObject;
var
  i: Integer;
begin
  Result := nil;
  if AnsiCompareText(Self.Name, aName) = 0 then
    Result:=Self
  else
    for i := 0 to RTObjects.Count - 1 do
    begin
      if AnsiCompareText(TfrObject(RTObjects[i]).Name, aName) = 0 then
      begin
        Result :=TfrObject(RTObjects[i]);
        Exit;
      end;
    end;
end;

procedure TfrPage.InitReport;
var
  b: TfrBandType;
begin
  for b := btReportTitle to btNone do
    Bands[b] := TfrBand.Create(b, Self);
  while RTObjects.Count > 0 do
  begin
    TfrView(RTObjects[0]).Free;
    RTObjects.Delete(0);
  end;
  TossObjects;
  InitFlag := True;
  CurPos := 1; ColPos := 1;
end;

procedure TfrPage.DoneReport;
var
  b: TfrBandType;
begin
  if InitFlag then
  begin
    for b := btReportTitle to btNone do
      Bands[b].Free;
    while RTObjects.Count > 0 do
    begin
      TfrView(RTObjects[0]).Free;
      RTObjects.Delete(0);
    end;
  end;
  InitFlag := False;
end;

function TfrPage.TopMargin: Integer;
begin
  if UseMargins then
  begin
    if Margins.Top = 0 then
      Result := PrnInfo.Ofy
    else
      Result := Margins.Top;
  end
  else Result := 0;
end;

function TfrPage.BottomMargin: Integer;
begin
  with PrnInfo do
    if UseMargins then
      if Margins.Bottom = 0 then
        Result:=Ofy+Ph
      else
        Result:=Pgh-Margins.Bottom
    else
      Result:=Pgh;
  if (DocMode <> dmDesigning) and BandExists(Bands[btPageFooter]) then
    Result := Result - Bands[btPageFooter].dy;
end;

function TfrPage.LeftMargin: Integer;
begin
  if UseMargins then
  begin
    if Margins.Left = 0 then
      Result := PrnInfo.Ofx
    else
      Result := Margins.Left;
  end
  else Result := 0;
end;

function TfrPage.RightMargin: Integer;
begin
  with PrnInfo do
  begin
    if UseMargins then
    begin
      if Margins.Right = 0 then
        Result := Ofx + Pw
      else
        Result := Pgw - Margins.Right;
    end
    else Result := Pgw;
  end;
end;

procedure TfrPage.TossObjects;
var
  i, j, n, last, miny: Integer;
  b: TfrBandType;
  bt, t: TfrView;
  Bnd, Bnd1: TfrBand;
  FirstBand, Flag: Boolean;
  BArr: Array[0..lrMaxBandsInReport - 1] of TfrBand;
  s: String;
begin
  {$IFDEF DebugLR}
  DebugLnEnter('TfrPage.TossObjects INIT ', []);
  {$ENDIF}
  for i := 0 to Objects.Count - 1 do
  begin
    bt :=TfrView(Objects[i]);
    if not (doChildComponent in bt.DesignOptions) then
    begin
      t := frCreateObject(bt.Typ, bt.ClassName, nil);
      t.Assign(bt);
      t.StreamMode := smPrinting;
      T.OwnerPage:=Self;
      RTObjects.Add(t);

      if (t.Flags and flWantHook) <> 0 then
        HookList.Add(t);
    end;
  end;

  for i := 0 to RTObjects.Count - 1 do // select all objects exclude bands
  begin
    t :=TfrView(RTObjects[i]);
    t.Selected := t.Typ <> gtBand;
    t.Parent := nil;
    frInterpretator.PrepareScript(t.Script, t.Script, SMemo);
    if t.Typ = gtSubReport then
      (t as TfrSubReportView).SubPage.Skip := True;
  end;
  Flag := False;
  for i := 0 to RTObjects.Count - 1 do // search for btCrossXXX bands
  begin
    bt :=TfrView(RTObjects[i]);
    if (bt.Typ = gtBand) and
       (TfrBandView(bt).BandType in [btCrossHeader..btCrossFooter]) then
    with Bands[TfrBandView(bt).BandType] do
    begin
      Memo.Assign(bt.Memo);
      Script.Assign(bt.Script);
      x := bt.x; dx := bt.dx;
      InitDataSet(TfrBandView(bt).DataSet);
      View := bt;
      Flags := bt.Flags;
      Visible := bt.Visible;
      bt.Parent := Bands[TfrBandView(bt).BandType];
      Flag := True;
    end;
  end;

  if Flag then // fill a ColumnXXX bands at first
    for b := btCrossHeader to btCrossFooter do
    begin
      Bnd := Bands[b];
      for i := 0 to RTObjects.Count - 1 do
      begin
        t :=TfrView(RTObjects[i]);
        if t.Selected then
         if (t.x >= Bnd.x) and (t.x + t.dx <= Bnd.x + Bnd.dx) then
         begin
           t.x := t.x - Bnd.x;
           t.Parent := Bnd;
           Bnd.Objects.Add(t);
           {$IFDEF DebugLR}
           DebugLn('A - Placed %s over %s',[ViewInfo(t), BandInfo(Bnd)]);
           {$ENDIF}
         end;
      end;
    end;

  for b := btReportTitle to btChild do // fill other bands
  if not (b in [btCrossHeader..btCrossFooter]) then
  begin
    FirstBand := True;
    Bnd := Bands[b];
    BArr[0] := Bnd;
    Last := 1;
    for i := 0 to RTObjects.Count - 1 do // search for specified band
    begin
      bt :=TfrView(RTObjects[i]);
      if (bt.Typ = gtBand) and (TfrBandView(bt).BandType=b) then
      begin
        if not FirstBand then
        begin
          Bnd.Next := TfrBand.Create(b,Self);
          Bnd := Bnd.Next;
          BArr[Last] := Bnd;
          Inc(Last);
        end;
        FirstBand := False;
        Bnd.Memo.Assign(bt.Memo);
        Bnd.Script.Assign(bt.Script);
        Bnd.y := bt.y;
        Bnd.dy := bt.dy;
        Bnd.View := bt;
        Bnd.Flags := bt.Flags;
        Bnd.Visible := bt.Visible;
        bt.Parent := Bnd;
        with bt as TfrBandView, Bnd do
        begin
          if Typ = btGroupHeader then
            InitDataSet(TfrBandView(Bt).fCondition)
          else
            InitDataSet(TfrBandView(Bt).DataSet);
          Stretched := (Flags and flStretched) <> 0;
          PrintIfSubsetEmpty := (Flags and flBandPrintIfSubsetEmpty) <> 0;
          PrintChildIfNotVisible := (Flags and flBandPrintChildIfNotVisible) <> 0;
          if Skip then
          begin
            NewPageAfter := False;
            PageBreak := False;
          end
          else
          begin
            NewPageAfter := (Flags and flBandNewPageAfter) <> 0;
            PageBreak := (Flags and flBandPageBreak) <> 0;
          end;
        end;
        for j := 0 to RTObjects.Count - 1 do // placing objects over band
        begin
          t :=TfrView(RTObjects[j]);
          if (t.Parent = nil) and (t.Typ <> gtSubReport) then
           if t.Selected then
            if (t.y >= Bnd.y) and (t.y <= Bnd.y + Bnd.dy) then
            begin
              t.Parent := Bnd;
              t.y := t.y - Bnd.y;
              t.Selected := False;
              Bnd.Objects.Add(t);
              {$IFDEF DebugLR}
              DebugLn('B - Placed %s over %s',[ViewInfo(t), BandInfo(Bnd)]);
              {$ENDIF}
            end;
        end;
        for j := 0 to RTObjects.Count - 1 do // placing ColumnXXX objects over band
        begin
          t :=TfrView(RTObjects[j]);
          if t.Parent <> nil then
           if t.Selected then
            if (t.y >= Bnd.y) and (t.y <= Bnd.y + Bnd.dy) then
            begin
              t.y := t.y - Bnd.y;
              t.Selected := False;
              Bnd.Objects.Add(t);
              {$IFDEF DebugLR}
              DebugLn('C - Placed %s over %s',[ViewInfo(t), BandInfo(Bnd)]);
              {$ENDIF}
            end;
        end;
        for j := 0 to RTObjects.Count - 1 do // placing subreports over band
        begin
          t :=TfrView(RTObjects[j]);
          if (t.Parent = nil) and (t.Typ = gtSubReport) then
           if t.Selected then
            if (t.y >= Bnd.y) and (t.y <= Bnd.y + Bnd.dy) then
            begin
              t.Parent := Bnd;
              t.y := t.y - Bnd.y;
              t.Selected := False;
              Bnd.Objects.Add(t);
              {$IFDEF DebugLR}
              DebugLn('D - Placed %s over %s',[ViewInfo(t), BandInfo(Bnd)]);
              {$ENDIF}
            end;
        end;
      end;
    end;
    for i := 0 to Last - 1 do // sorting bands
    begin
      miny := BArr[i].y; n := i;
      for j := i + 1 to Last - 1 do
        if BArr[j].y < miny then
        begin
          miny := BArr[j].y;
          n := j;
        end;
      Bnd := BArr[i]; BArr[i] := BArr[n]; BArr[n] := Bnd;
    end;
    Bnd := BArr[0]; Bands[b] := Bnd;
    Bnd.Prev := nil;
    for i := 1 to Last - 1 do  // finally ordering
    begin
      Bnd.Next := BArr[i];
      Bnd := Bnd.Next;
      Bnd.Prev := BArr[i - 1];
    end;
    Bnd.Next := nil;
    Bands[b].LastBand := Bnd;
  end;

  for i := 0 to RTObjects.Count - 1 do // place other objects on btNone band
  begin
    t :=TfrView(RTObjects[i]);
    if t.Selected then
    begin
      t.Parent := Bands[btNone];
      Bands[btNone].y := 0;
      Bands[btNone].Objects.Add(t);
      {$IFDEF DebugLR}
      DebugLn('E - Placed %s over %s',[ViewInfo(t), BandInfo(Bands[btNone])]);
      {$ENDIF}
    end;
  end;

  for i := 1 to MAXBNDS do  // connect header & footer to each data-band
  begin
    Bnd := Bands[Bnds[i, bpHeader]];
    while Bnd <> nil do
    begin
      Bnd1 := Bands[Bnds[i, bpData]];
      while Bnd1 <> nil do
      begin
        if Bnd1.y > Bnd.y + Bnd.dy then break;
        Bnd1 := Bnd1.Next;
      end;
      if (Bnd1 <> nil) and (Bnd1.HeaderBand = nil) then
        Bnd1.HeaderBand := Bnd;

      Bnd := Bnd.Next;
    end;

    Bnd := Bands[Bnds[i, bpFooter]];
    while Bnd <> nil do
    begin
      Bnd1 := Bands[Bnds[i, bpData]];
      while Bnd1 <> nil do
      begin
        if Bnd1.y + Bnd1.dy > Bnd.y then
        begin
          Bnd1 := Bnd1.Prev;
          break;
        end;
        if Bnd1.Next = nil then break;
        Bnd1 := Bnd1.Next;
      end;
      if (Bnd1 <> nil) and (Bnd1.FooterBand = nil) then
        Bnd1.FooterBand := Bnd;

      Bnd := Bnd.Next;
    end;
  end;

  Bnd := Bands[btGroupHeader].LastBand;
  Bnd1 := Bands[btGroupFooter];
  repeat
    Bnd.FooterBand := Bnd1;
    Bnd := Bnd.Prev;
    Bnd1 := Bnd1.Next;
  until (Bnd = nil) or (Bnd1 = nil);

  if BandExists(Bands[btCrossData]) and (Pos(';', TfrBandView(Bands[btCrossData].View).DataSet) <> 0) then
  begin
    s := TfrBandView(Bands[btCrossData].View).DataSet;

    i := 1;
    while i < Length(s) do
    begin
      j := i;
      while s[j] <> '=' do Inc(j);
      n := j;
      while s[n] <> ';' do Inc(n);
      for b := btMasterHeader to btGroupFooter do
      begin
        Bnd := Bands[b];
        while Bnd <> nil do
        begin
          if Bnd.View <> nil then
            if AnsiCompareText(Bnd.View.Name, Copy(s, i, j - i)) = 0 then
              CreateDS(Copy(s, j + 1, n - j - 1), Bnd.VCDataSet, Bnd.IsVirtualVCDS);
          Bnd := Bnd.Next;
        end;
      end;
      i := n + 1;
    end;
  end;

  for b := btReportTitle to btChild do
  begin
    Bnd := Bands[b];
    while Bnd <> nil do
    begin
      if Bnd.View <> nil then
      begin
        s := TfrBandView(Bnd.View).Child;

        for i := 0 to RTObjects.Count - 1 do
        begin
          bt :=TfrView(RTObjects[i]);
          if (bt.Typ = gtBand) and (TfrBandView(bt).BandType=btChild) and (bt.Name=s) then
            Bnd.ChildBand:=bt.Parent;
        end;
      end;
      Bnd := Bnd.Next;
    end;
  end;

  if ColCount = 0 then ColCount := 1;
  ColWidth := (RightMargin - LeftMargin - (ColCount-1)*ColGap) div ColCount;
  {$IFDEF DebugLR}
  DebugLnExit('TfrPage.TossObjects DONE ', []);
  {$ENDIF}
end;

procedure TfrPage.PrepareObjects;
var
  i, j: Integer;
  t: TfrView;
  Value: TfrValue;
  s: String;
  DSet: TfrTDataSet;
  Field: TfrTField;
begin
  {$ifdef DebugLR}
  DebugLnEnter('TfrPage.PrepareObjects INIT');
  {$endif}

  CurPage := Self;
  for i := 0 to RTObjects.Count - 1 do
  begin
    t :=TfrView(RTObjects[i]);
    t.FField := '';
    if t.Memo.Count > 0 then
      s := t.Memo[0];
    j := Length(s);
    if (j > 2) and (s[1] = '[') then
    begin
      while (j > 0) and (s[j] <> ']') do Dec(j);
      s := Copy(s, 2, j - 2);
      t.FDataSet := nil;
      t.FField := '';
      Value := CurReport.Values.FindVariable(s);
      if Value = nil then
      begin
        CurBand := t.Parent;
        DSet := GetDefaultDataset;
        frGetDatasetAndField(s, DSet, Field);
        if Field <> nil then
        begin
          {$ifdef DebugLR}
          DebugLn('For View=%s found Field=%s',[ViewInfo(t),Field.FieldName]);
          {$endif}
          t.FDataSet := DSet;
          t.FField := Field.FieldName;
        end;
      end
      else if Value.Typ = vtDBField then
        if Value.DSet <> nil then
        begin
          t.FDataSet := Value.DSet;
          t.FField := Value.Field;
        end;
    end;
    T.PrepareObject;
  end;
  {$ifdef DebugLR}
  DebugLnExit('TfrPage.PrepareObjects DONE');
  {$endif}
end;

procedure TfrPage.ShowBand(b: TfrBand);
begin
  if b <> nil then
  begin
    {$IFDEF DebugLR}
    DebugLn;
    DebugLnEnter('TfrPage.ShowBand INI Band=%s',[BandInfo(b)]);
    {$ENDIF}
    if Mode = pmBuildList then
      AddRecord(b, rtShowBand) else
      b.Draw;
    {$IFDEF DebugLR}
    DebugLnExit('TfrPage.ShowBand END Band=%s',[BandInfo(b)]);
    {$ENDIF}
  end;
end;

constructor TfrPage.Create(AOwnerPage: TfrPage);
begin
  inherited Create(AOwnerPage);
  FillChar(Bands, 0, SizeOf(Bands));

  fMargins:=TfrRect.Create;
  BaseName:='Page';
  
  List := TFpList.Create;
  Objects := TFpList.Create;
  RTObjects := TFpList.Create;
  PageType:=ptReport;  //todo: - remove this
end;

procedure TfrPage.ShowBandByName(const s: String);
var
  bt: TfrBandType;
  b: TfrBand;
begin
  for bt := btReportTitle to btNone do
  begin
    b := Bands[bt];
    while b <> nil do
    begin
      if b.View <> nil then
        if AnsiCompareText(b.View.Name, s) = 0 then
        begin
          b.Draw;
          Exit;
        end;
      b := b.Next;
    end;
  end;
end;

procedure TfrPage.ShowBandByType(bt: TfrBandType);
var
  b: TfrBand;
begin
  b := Bands[bt];
  if b <> nil then
    b.Draw;
end;

procedure TfrPage.AddRecord(b: TfrBand; rt: TfrBandRecType);
var
  p: PfrBandRec;
begin
  GetMem(p, SizeOf(TfrBandRec));
  p^.Band := b;
  p^.Action := rt;
  List.Add(p);
end;

procedure TfrPage.ClearRecList;
var
  i: Integer;
begin
  for i := 0 to List.Count - 1 do
    FreeMem(PfrBandRec(List[i]), SizeOf(TfrBandRec));
  List.Clear;
end;

function TfrPage.PlayRecList: Boolean;
var
  p: PfrBandRec;
  b: TfrBand;
begin
  Result := False;
  while PlayFrom < List.Count do
  begin
    p := List[PlayFrom];
    b := p^.Band;
    case p^.Action of
      rtShowBand:
        begin
          if LastBand <> nil then
          begin
            LastBand.DoSubReports;
            if LastBand <> nil then
            begin
              Result := True;
              Exit;
            end;
          end
          else
            if b.Draw then
            begin
              Result := True;
              Exit;
            end;
        end;
      rtFirst:
        begin
          b.DataSet.First;
          b.Positions[psLocal] := 1;
        end;
      rtNext:
        begin
          b.DataSet.Next;
          Inc(CurPos);
          Inc(b.Positions[psGlobal]);
          Inc(b.Positions[psLocal]);
        end;
    end;
    Inc(PlayFrom);
  end;
end;

procedure TfrPage.DrawPageFooters;
begin
  {$IFDEF DebugLR}
  DebugLn('TFrPage.DrawPageFootersPage INI PageNo=%d XAdjust=%d CurColumn=%d',
    [PageNo, XAdjust, CurColumn]);
  {$ENDIF}
  CurColumn := 0;
  XAdjust := LeftMargin;
  if (PageNo <> 0) or ((Bands[btPageFooter].Flags and flBandOnFirstPage) <> 0) then
    while PageNo < MasterReport.EMFPages.Count do
    begin
      if not (AppendPage and WasPF) then
      begin
        if CurReport <> nil then
          CurReport.DoEndPage(PageNo);
        if (MasterReport <> CurReport) and (MasterReport <> nil) then
          MasterReport.DoEndPage(PageNo);
        if not RowsLayout then
          ShowBand(Bands[btPageFooter]);
      end;
      Inc(PageNo);
    end;
  PageNo := MasterReport.EMFPages.Count;
  {$IFDEF DebugLR}
  DebugLn('TFrPage.DrawPageFootersPage END PageNo=%d XAdjust=%d CurColumn=%d',
    [PageNo, XAdjust, CurColumn]);
  {$ENDIF}
end;

procedure TfrPage.NewPage;
begin
  {$IFDEF DebugLR}
  DebugLnEnter('TFrPage.NewPage INI PageNo=%d CurBottomY=%d CurY=%d XAdjust=%d',
    [PageNo, CurBottomY, CurY, XAdjust]);
  {$ENDIF}

  CurReport.InternalOnProgress(PageNo + 1);
  if not RowsLayout then
    ShowBand(Bands[btColumnFooter]);
  DrawPageFooters;
  CurBottomY := BottomMargin;
  MasterReport.EMFPages.Add(Self);
  AppendPage := False;
  {$IFDEF DebugLR}
  DebugLn('---- Start of new page ----');
  {$ENDIF}
  ColPos := 1;
  ShowBand(Bands[btOverlay]);
  CurY := TopMargin;
  ShowBand(Bands[btPageHeader]);
  if not RowsLayout then
    ShowBand(Bands[btColumnHeader]);
  {$IFDEF DebugLR}
  DebugLnExit('TFrPage.NewPage END PageNo=%d CurBottomY=%d CurY=%d XAdjust=%d',
    [PageNo, CurBottomY, CurY, XAdjust]);
  {$ENDIF}
end;

procedure TfrPage.NewColumn(Band: TfrBand);
var
  b: TfrBand;
begin
  {$IFDEF DebugLR}
  DebugLnEnter('TfrPage.NewColumn INI CurColumn=%d ColCount=%d CurY=%d XAdjust=%d',
    [CurColumn, ColCount, CurY, XAdjust]);
  {$ENDIF}
  if CurColumn < ColCount - 1 then
  begin
    ShowBand(Bands[btColumnFooter]);
    Inc(CurColumn);
    Inc(XAdjust, ColWidth + ColGap);
    Inc(ColPos);
    CurY := LastStaticColumnY;
    ShowBand(Bands[btColumnHeader]);
  end
  else
    NewPage;
  b := Bands[btGroupHeader];
  if b <> nil then
    while (b <> nil) and (b <> Band) do
    begin
      b.DisableInit := True;
      if (b.Flags and flBandRepeatHeader) <> 0 then
        ShowBand(b);
      b.DisableInit := False;
      b := b.Next;
    end;
  if Band.Typ in [btMasterData, btDetailData, btSubDetailData] then
  begin
    if (Band.HeaderBand <> nil) and
      ((Band.HeaderBand.Flags and flBandRepeatHeader) <> 0) then
      ShowBand(Band.HeaderBand);
    Band.ResetLastValues;
  end;
  {$IFDEF DebugLR}
  DebugLnExit('TfrPage.NewColumn END CurColumn=%d ColCount=%d CurY=%d XAdjust=%d',
    [CurColumn, ColCount, CurY, XAdjust]);
  {$ENDIF}
end;

procedure TfrPage.NextColumn(Band: TFrBand);
begin
  {$IFDEF DebugLR}
  DebugLnEnter('TfrPage.NextColumn INI CurColumn=%d ColCount=%d CurY=%d XAdjust=%d',
    [CurColumn, ColCount, CurY, XAdjust]);
  {$ENDIF}
  if CurColumn < ColCount - 1 then
  begin
    Inc(CurColumn);
    Inc(XAdjust, ColWidth + ColGap);
    Inc(ColPos);
  end
  else
    StartColumn;
  {$IFDEF DebugLR}
  DebugLnExit('TfrPage.NextColumn END CurColumn=%d ColCount=%d CurY=%d XAdjust=%d',
    [CurColumn, ColCount, CurY, XAdjust]);
  {$ENDIF}
end;

function TfrPage.RowsLayout: boolean;
begin
  result := (ColCount>1) and (LayoutOrder=loRows)
end;

procedure TfrPage.StartColumn;
begin
  CurColumn := 0;
  ColPos:=1;
  XAdjust := LeftMargin;
end;

procedure TfrPage.StartRowsLayoutNonDataBand(Band: TfrBand);
begin

  // reset starting column
  if Band.ForceNewPage then begin
    CurColumn := ColCount - 1;
    NewColumn(Band);
  end else
    StartColumn;

  // check for partial rows
  if LastBandType in [btMasterData, btDetailData, btSubdetailData] then
  begin
    if not RowStarted then
      Inc(CurY, LastRowHeight);
  end;

end;

function TfrPage.AdvanceRow(Band: TfrBand): boolean;
begin
  result := not RowsLayout or (not Band.IsDataBand) or (CurColumn=ColCount-1);
  RowStarted := result;
end;

procedure TfrPage.DoAggregate(a: array of TfrBandType);
var
  i: Integer;
  procedure DoAggregate1(bt: TfrBandType);
  var
    b: TfrBand;
  begin
    b := Bands[bt];
    while b <> nil do
    begin
      b.DoAggregate;
      b := b.Next;
    end;
  end;
begin
  for i := Low(a) to High(a) do
    DoAggregate1(a[i]);
end;

procedure TfrPage.FormPage;
type
  TBookRecord = record
    Dataset: TfrDataset;
    Bookmark: Pointer;
  end;
var
  BndStack: Array[1..MAXBNDS * 3] of TfrBand;
  MaxLevel, BndStackTop: Integer;
  i, sfPage            : Integer;
  HasGroups            : Boolean;
  DetailCount          : Integer;
  BooksBkUp            : array of TBookRecord;
  CurGroupValue        : variant;
  BookPrev             : pointer;
  {$IFDEF DebugLR}
  mys                  : string;
  {$ENDIF}
  
  procedure AddToStack(b: TfrBand);
  begin
    if b <> nil then
    begin
      Inc(BndStackTop);
      {$IFDEF DebugLR}
      DebugLn('AddToStack b=%s',[BandInfo(b)]);
      {$ENDIF}
      BndStack[BndStackTop] := b;
    end;
  end;

  procedure BackupBookmarks;
  var
    b: TfrBand;
    i, n: Integer;
  begin
    SetLength(BooksBkUp, 0);
    for i := 1 to MAXBNDS do
    begin
      b := Bands[Bnds[i, bpData]];
      if BandExists(b) and (b.DataSet<>nil) then
      begin
        n := Length(BooksBkUp);
        SetLength(BooksBkUp, n+1);
        BooksBkUp[n].Dataset := b.Dataset;
        BooksBkUp[n].Bookmark := b.Dataset.GetBookmark;
      end;
    end;
  end;

  procedure RestoreBookmarks;
  var
    n: Integer;
  begin
    for n:=0 to Length(BooksBkUp)-1 do
    with BooksBkUp[n] do begin
      Dataset.GotoBookMark(Bookmark);
      Dataset.FreeBookMark(Bookmark);
    end;
    SetLength(BooksBkUp, 0);
  end;

  procedure DisableControls;
  var
    i: Integer;
    b: TfrBand;
  begin
    if DetailCount=0 then
      for i := 1 to MAXBNDS do
      begin
        b := Bands[Bnds[i, bpData]];
        if BandExists(b) and (b.DataSet<>nil) then
          b.DataSet.DisableControls;
      end;
  end;

  procedure EnableControls;
  var
    i: Integer;
    b: TfrBand;
  begin
    if DetailCount=0 then
      for i := 1 to MAXBNDS do
      begin
        b := Bands[Bnds[i, bpData]];
        if BandExists(b) and (b.Dataset<>nil) then
          b.DataSet.EnableControls;
      end;
  end;

  procedure ShowStack;
  var
    i: Integer;
  begin
    {$IFDEF DebugLR}
    DebugLnEnter('ShowStack INI BndStackTop=%d',[BndStackTop]);
    {$ENDIF}
    for i := 1 to BndStackTop do
      if BandExists(BndStack[i]) then
        ShowBand(BndStack[i]);
    BndStackTop := 0;
    {$IFDEF DebugLR}
    DebugLnExit('ShowStack END');
    {$ENDIF}
  end;

  procedure DoLoop(Level: Integer);
  var
    WasPrinted: Boolean;
    b, b1, b2: TfrBand;
    procedure InitGroups(b: TfrBand);
    begin
      while b <> nil do
      begin
        Inc(b.Positions[psLocal]);
        Inc(b.Positions[psGlobal]);
        ShowBand(b);
        b := b.Next;
      end;
    end;

  begin
    b := Bands[Bnds[Level, bpData]];
    {$IFDEF DebugLR}
    DebugLnEnter('Doop(Level=%d) INI b=%s mode=',[Level,bandinfo(b)]);
    {$ENDIF}
    while (b <> nil) and (b.Dataset <> nil) do
    begin
      b.ResetLastValues;
      try
        b.DataSet.First;

        //if Level<>1 then begin
        //  b.Dataset.Refresh;
        //end;

        if Mode = pmBuildList then
          AddRecord(b, rtFirst)
        else
          b.Positions[psLocal] := 1;

        b1 := Bands[btGroupHeader];
        while b1 <> nil do
        begin
          b1.Positions[psLocal] := 0;
          b1.Positions[psGlobal] := 0;
          b1 := b1.Next;
        end;

        if not b.DataSet.Eof then
        begin
          if (Level = 1) and HasGroups then
            InitGroups(Bands[btGroupHeader]);
          if b.HeaderBand <> nil then
            AddToStack(b.HeaderBand);
          if b.FooterBand <> nil then
            b.FooterBand.InitValues;

          while not b.DataSet.Eof do
          begin
            Application.ProcessMessages;
            if MasterReport.Terminated then
              break;
            AddToStack(b);
            WasPrinted := True;
            if Level < MaxLevel then
            begin
              DoLoop(Level + 1);
              if BndStackTop > 0 then
                if b.PrintIfSubsetEmpty then
                  ShowStack
                else
                begin
                  Dec(BndStackTop);
                  WasPrinted := False;
                end;
            end
            else
              ShowStack;

            if (Level = 1) and HasGroups then
            begin
              // get a bookmark to current record it will be used in case
              // a group change is detected and there are remaining group
              // footers.
              BookPrev := b.DataSet.GetBookMark;
              try
                b.DataSet.Next;
                b1 := Bands[btGroupHeader];
                while b1 <> nil do
                begin
                  if not b.dataset.eof then
                    curGroupValue := frParser.Calc(b1.GroupCondition);
                  {$IFDEF DebugLR}
                  DebugLn('GroupCondition=%s LastGroupValue=%s curGroupValue=%s',
                    [b1.GroupCondition,varstr(b1.LastGroupValue),varstr(curGroupValue)]);
                  {$ENDIF}
                  if b.dataset.eof or (curGroupValue <> b1.LastGroupValue) then
                  begin
                    // next bands should be printed on the previous record context
                    // if we have a valid bookmark to previous record
                    if BookPrev<>nil then
                      b.DataSet.GotoBookMark(BookPrev);
                    ShowBand(b.FooterBand);
                    b2 := Bands[btGroupHeader].LastBand;
                    while b2 <> b1 do
                    begin
                      ShowBand(b2.FooterBand);
                      b2.Positions[psLocal] := 0;
                      b2 := b2.Prev;
                    end;
                    ShowBand(b1.FooterBand);
                    // advance to the actual current record
                    // if we really were on previous record
                    if BookPrev<>nil then
                      b.DataSet.Next;
                    if not b.Dataset.Eof then
                    begin
                      if b1.NewPageAfter then NewPage;
                      InitGroups(b1);
                      ShowBand(b.HeaderBand);
                      b.Positions[psLocal] := 0;
                    end;
                    b.ResetLastValues;
                    break;
                  end;
                  b1 := b1.Next;
                end;
              finally
                b.DataSet.FreeBookMark(BookPrev);
              end;
            end else
              b.DataSet.Next;

            if Mode = pmBuildList then
              AddRecord(b, rtNext)
            else if WasPrinted then
            begin
              Inc(CurPos);
              Inc(b.Positions[psGlobal]);
              Inc(b.Positions[psLocal]);
              if not b.DataSet.Eof and b.NewPageAfter then
              begin
                NewPage;
                b.ResetLastValues;
              end;
            end;
            if MasterReport.Terminated then
              break;
          end;
          if BndStackTop = 0 then
            ShowBand(b.FooterBand) else
            Dec(BndStackTop);
        end else
        if b.PrintIfSubsetEmpty then begin
          if b.HeaderBand <> nil then
            ShowBand(b.HeaderBand);
          if b.FooterBand <> nil then begin
            b.FooterBand.InitValues;
            ShowBand(b.FooterBand);
          end;
        end;
      finally
      end;
      b := b.Next;
    end;
    {$IFDEF DebugLR}
    DebugLnExit('Doop(Level=%d) END',[Level]);
    {$ENDIF}
  end;

begin
  {$IFDEF DebugLR}
  WriteStr(Mys, Mode);
  DebugLnEnter('TfrPage.FormPage INI Mode=%s',[MyS]);
  {$ENDIF}
  if Mode = pmNormal then
  begin
    if AppendPage then
    begin
      if PrevY = PrevBottomY then
      begin
        AppendPage := False;
        WasPF := False;
        PageNo := MasterReport.EMFPages.Count;
      end;
    end;
    
    if AppendPage and WasPF then
      CurBottomY := PrevBottomY
    else
      CurBottomY := BottomMargin;
      
    CurColumn := 0;
    XAdjust := LeftMargin;
    {$IFDEF DebugLR}
    DebugLn('XAdjust=%d CurBottomY=%d PrevY=%d',[XAdjust,CurBottomY,PrevY]);
    {$ENDIF}
    if not AppendPage then
    begin
      MasterReport.EMFPages.Add(Self);
      CurY := TopMargin;
      ShowBand(Bands[btOverlay]);
      ShowBand(Bands[btNone]);
    end
    else
      CurY := PrevY;
    sfPage := PageNo;
    {$IFDEF DebugLR}
    DebugLn('XAdjust=%d CurY=%d sfPage=%d',[XAdjust,CurY,sfpage]);
    {$ENDIF}
    if not (roPageHeaderBeforeReportTitle in MasterReport.Options) then
      ShowBand(Bands[btReportTitle]);
    if PageNo = sfPage then // check if new page was formed
    begin
      if BandExists(Bands[btPageHeader]) and
        ((Bands[btPageHeader].Flags and flBandOnFirstPage) <> 0) then
        ShowBand(Bands[btPageHeader]);
      if roPageHeaderBeforeReportTitle in MasterReport.Options then
        ShowBand(Bands[btReportTitle]);
      if not RowsLayout then
        ShowBand(Bands[btColumnHeader]);
    end;
  end;

  BndStackTop := 0;
  DetailCount := 0;
  for i := 1 to MAXBNDS do
    if BandExists(Bands[Bnds[i, bpData]]) then begin
      MaxLevel := i;
      if Bands[Bnds[i, bpData]].Typ in [btDetailData,btSubDetailData] then
        inc(DetailCount);
    end;

  if roSaveAndRestoreBookmarks in MasterReport.Options theN
  begin
    if Assigned(MasterReport.OnFormPageBookmarks) then
      MasterReport.OnFormPageBookmarks(MasterReport, true)
    else
      BackupBookmarks;
  end;

  HasGroups := Bands[btGroupHeader].Objects.Count > 0;
  {$IFDEF DebugLR}
  DebugLn('GroupsCount=%d MaxLevel=%d doing DoLoop(1)',[
    Bands[btGroupHeader].Objects.Count, MaxLevel]);
  {$ENDIF}
  DisableControls;
  DoLoop(1);

  if roSaveAndRestoreBookmarks in MasterReport.Options then
  begin
    if Assigned(MasterReport.OnFormPageBookmarks) then
      MasterReport.OnFormPageBookmarks(MasterReport, false)
    else
      RestoreBookmarks; // this also enablecontrols
  end;
  EnableControls;

  if Mode = pmNormal then
  begin
    if not RowsLayout then
      ShowBand(Bands[btColumnFooter]);
    ShowBand(Bands[btReportSummary]);
    PrevY := CurY;
    PrevBottomY := CurBottomY;
    if CurColumn > 0 then
      PrevY := BottomMargin;
    CurColumn := 0;
    XAdjust := LeftMargin;
    sfPage := PageNo;
    WasPF := False;
    if (Bands[btPageFooter].Flags and flBandOnLastPage) <> 0 then
    begin
      WasPF := BandExists(Bands[btPageFooter]);
      if WasPF then
         DrawPageFooters;
    end;
    PageNo := sfPage + 1;
  end;
  {$IFDEF DebugLR}
  DebugLnExit('TfrPage.FormPage END PrevY=%d PrevBottomY=%d PageNo=%d XAdjust=%d',
    [PrevY,PrevBottomY,PageNo,XAdjust]);
  {$ENDIF}
end;

function TfrPage.BandExists(b: TfrBand): Boolean;
begin
  Result := b.Objects.Count > 0;
end;

function TfrPage.GetPageIndex: integer;
begin
  Result:=CurReport.Pages.FPages.IndexOf(Self);
end;

procedure TfrPage.AfterPrint;
var
  i: Integer;
begin
  for i := 0 to HookList.Count - 1 do
    TfrView(HookList[i]).OnHook(CurView);
end;

procedure TfrPage.AfterLoad;
var
  i:integer;
begin
  for i:=0 to Objects.Count - 1 do
    TfrObject(Objects[i]).AfterLoad;
end;

procedure TfrPage.LoadFromStream(Stream: TStream);
var
  b: Byte;
  s: String[6];
  Bool : WordBool;
  Rc   : TRect;
  APageType:TfrPageType; //todo: - remove this
begin
  with Stream do
  begin
    Read(pgSize, 4);
    Read(dx, 4); //Width
    Read(dy, 4); //Height
    Read(Rc{%H-}, Sizeof(Rc));
    Margins.AsRect:=Rc;
    b := 0;
    Read(b, 1);
    Orientation:=TPrinterOrientation(b);
    if frVersion < 23 then
      Read({%H-}s[1], 6);
    Bool := false;
    Read(Bool, 2);
    PrintToPrevPage:=Bool;
    Read(Bool, 2);
    UseMargins:=Bool;
    Read(fColCount, 4);
    Read(fColGap, 4);
    if frVersion>=24 then                         //todo: - remove this
      Read(APageType, SizeOf(TfrPageType));  //todo: - remove this
    if frVersion>=25 then
    Read(fLayoutOrder, 4);
  end;
  ChangePaper(pgSize, Width, Height, Orientation);
end;

procedure TfrPage.LoadFromXML(XML: TLrXMLConfig; const Path: String);
{var
  b:byte; }
begin
  inherited LoadFromXML(XML,Path);
  
  dx := XML.GetValue(Path+'Width/Value'{%H-}, 0); // TODO chk
  dy := XML.GetValue(Path+'Height/Value'{%H-}, 0); // TODO chk
{  b := XML.GetValue(Path+'PageType/Value'{%H-}, ord(PageType));
  PageType:=TfrPageType(b);}

  Script.Text:=XML.GetValue(Path+'Script/Value'{%H-}, '');
end;

procedure TfrPage.SaveToStream(Stream: TStream);
var
  b: Byte;
  Bool : WordBool;
  Rc   : TRect;
begin
  with Stream do
  begin
    Write(pgSize, 4);
    Write(Width, 4);
    Write(Height, 4);
    Rc:=Margins.AsRect;
    Write(Rc, Sizeof(Rc));
    b := Byte(Orientation);
    Write(b, 1);
    Bool:=PrintToPrevPage;
    Write(Bool, 2);
    Bool:=UseMargins;
    Write(Bool, 2);
    Write(ColCount, 4);
    Write(ColGap, 4);
    // new in 2.4
    Write(ord(PageType), SizeOf(TfrPageType));  //todo: - remove this
    // new in 2.5
    Write(LayoutOrder, 4);
  end;
end;

procedure TfrPage.SetPageIndex(AValue: integer);
begin
  if (AValue>-1) and (AValue < CurReport.Pages.Count) and (GetPageIndex <> AValue) then
    CurReport.Pages.Move(GetPageIndex, AValue);
end;

procedure TfrPage.SavetoXML(XML: TLrXMLConfig; const Path: String);
begin
  Inherited SavetoXML(XML,Path);
  XML.SetValue(Path+'Width/Value'{%H-}, Width);
  XML.SetValue(Path+'Height/Value'{%H-}, Height);
//  XML.SetValue(Path+'PageType/Value'{%H-}, ord(PageType));
  XML.SetValue(Path+'Script/Value'{%H-}, Script.Text);
end;

{-----------------------------------------------------------------------}
constructor TfrPages.Create(AParent: TfrReport);
begin
  inherited Create;
  Parent := AParent;
  FPages := TFpList.Create;
end;

destructor TfrPages.Destroy;
begin
  Clear;
  FPages.Free;
  inherited Destroy;
end;

function TfrPages.GetCount: Integer;
begin
  Result := FPages.Count;
end;

function TfrPages.GetPages(Index: Integer): TfrPage;
begin
  Result :=TfrPage(FPages[Index]);
end;

procedure TfrPages.AfterLoad;
var
  i:integer;
begin
  for i := 0 to Count - 1 do // adding pages at first
    Pages[i].AfterLoad;
end;

procedure TfrPages.Clear;
var
  i: Integer;
begin
  for i := 0 to FPages.Count - 1 do
    Pages[i].Free;
  FPages.Clear;
end;

function TfrPages.Add(const aClassName: string): TfrPage;
var
  Rf : TFrPageClass;
begin
  Result := nil;

  Rf:=TFrPageClass(GetClass(aClassName));
  if Assigned(Rf) then
  begin
    Result := Rf.CreatePage;
    
    if Assigned(Result) then
    begin
      Result.CreateUniqueName;
      FPages.Add(Result);
    end;
  end
  else
    ShowMessage(Format('Class %s not found',[aClassName]))
end;

procedure TfrPages.Delete(Index: Integer);
begin
  Pages[Index].Free;
  FPages.Delete(Index);
end;

procedure TfrPages.Move(OldIndex, NewIndex: Integer);
begin
  FPages.Move(OldIndex, NewIndex);
end;

procedure TfrPages.LoadFromStream(Stream: TStream);
var
  b: Byte;
  t: TfrView;
  s: String;
  buf: String[8];

  procedure AddObject(ot: Byte; clname: String);
  begin
    Stream.Read(b, 1);
    t :=frCreateObject(ot, clname, Pages[b]);
{    Pages[b].Objects.Add(frCreateObject(ot, clname, Pages[b]));
    t :=TfrView(Pages[b].Objects.Items[Pages[b].Objects.Count - 1]);}
  end;

begin
  Clear;
  Stream.Read(Parent.PrintToDefault, 2);
  Stream.Read(Parent.DoublePass, 2);
  Parent.SetPrinterTo(ReadString(Stream));
  while Stream.Position < Stream.Size do
  begin
    {$IFDEF DebugLR}
    DebugLn('TfrPages.LoadFromStream');
    {$ENDIF}
    Stream.Read(b, 1);
    if b = $FF then  // page info
    begin
      if frVersion>23 then
      begin
        S:=ReadString(Stream);
        Add(S);
      end
      else
        Add;
      Pages[Count - 1].LoadFromStream(Stream);
    end
    else if b = $FE then // values
    begin
      Parent.FVal.ReadBinaryData(Stream);
      ReadMemo(Stream, SMemo);
      Parent.Variables.Assign(SMemo);
    end
    else if b = $FD then // datasets
    begin
      if frDataManager <> nil then
        frDataManager.LoadFromStream(Stream);
      break;
    end
    else
    begin
      if b > Integer(gtAddIn) then
      begin
        raise Exception.Create('');
        break;
      end;
      s := '';
      if b = gtAddIn then
      begin
        s := ReadString(Stream);
        if CompareText(s, 'TFRFRAMEDMEMOVIEW') = 0 then
          AddObject(gtMemo, '')
        else
          AddObject(gtAddIn, s);
      end
      else
        AddObject(b, '');
      t.LoadFromStream(Stream);
      if CompareText(s, 'TFRFRAMEDMEMOVIEW') = 0 then
        Stream.Read({%H-}buf[1], 8);
    end;
  end;
  AfterLoad;
end;

procedure TfrPages.LoadFromXML(XML: TLrXMLConfig; const Path: String);
var
  t: TfrView;
  procedure AddObject(aPage: TFrPage; ot: Byte; clname: String);
  begin
{    aPage.Objects.Add(frCreateObject(ot, clname, aPage));
    t :=TfrView(aPage.Objects.Items[aPage.Objects.Count - 1]);}
    t:=frCreateObject(ot, clname, aPage);
  end;
var
  i,j,aCount,oCount: Integer;
  aTyp: byte;
  aPath,aSubPath,clName: string;
begin
  Clear;
  {$IFDEF DebugLR}
  DebugLn('TfrPages.LoadFromXML: LoadingFrom: ', Path);
  {$ENDIF}
  Parent.PrintToDefault:= XML.GetValue(Path+'PrintToDefault/Value'{%H-}, True);
  Parent.DoublePass :=    XML.GetValue(Path+'DoublePass/Value'{%H-}, False); // TODO: check default
  clName :=               XML.GetValue(Path+'SelectedPrinter/Value','');
  Parent.SetPrinterTo(clName); // TODO: check default
  aCount := XML.GetValue(Path+'PageCount/Value'{%H-}, 0);
  for i := 0 to aCount - 1 do // adding pages at first
  begin
    aPath := Path+'Page'+IntToStr(i+1)+'/';
    clname:= XML.GetValue(aPath+'ClassName/Value', 'TFRPAGEREPORT');
    add(clName);
    
    Inc(Pages[i].fUpdate);
    Pages[i].LoadFromXML(XML, aPath);
    Dec(Pages[i].fUpdate);

    oCount := XML.GetValue(aPath+'ObjectCount/Value'{%H-}, 0);
    for j:=0 to oCount - 1 do
    begin
      aSubPath := aPath + 'Object'+IntTostr(j+1)+'/';
      aTyp := StrTofrTypeObject(XML.GetValue(aSubPath+'Typ/Value', '0'));
      if aTyp>gtAddin then
        raise Exception.Create('');
      clname := XML.GetValue(aSubPath+'ClassName/Value', 'TFRVIEW'); // TODO: Check default
      if aTyp=gtAddin then
      begin
        if CompareText(clname,'TFRFRAMEDMEMOVIEW') = 0 then
          addObject(Pages[i], gtMemo, '')
        else
          addObject(Pages[i], gtAddin, clName)
      end else
        AddObject(Pages[i], aTyp, '');
      Inc(t.fUpdate);
      t.LoadFromXML(XML, aSubPath);
      Dec(t.fUpdate);
    end;
  end;
  Parent.FVal.ReadBinaryDataFromXML(XML, Path+'FVal/');
  Parent.Variables.Text:= XML.GetValue(Path+'ParentVars/Value', '' );
  if frDataManager<>nil then
    frDatamanager.LoadFromXML(XML, Path+'Datamanager/');
  AfterLoad;
end;

procedure TfrPages.SaveToStream(Stream: TStream);
var
  b: Byte;
  i, j: Integer;
  t: TfrView;
begin
  Stream.Write(Parent.PrintToDefault, 2);
  Stream.Write(Parent.DoublePass, 2);
  frWriteString(Stream, Prn.Printers[Prn.PrinterIndex]);
  for i := 0 to Count - 1 do // adding pages at first
  begin
    b := $FF;
    Stream.Write(b, 1);      // page info
    frWriteString(Stream, Pages[i].Classname);
    Pages[i].SaveToStream(Stream);
  end;
  for i := 0 to Count - 1 do
  begin
    for j := 0 to Pages[i].Objects.Count - 1 do // then adding objects
    begin
      t :=TfrView(Pages[i].Objects[j]);
      if not (doChildComponent in T.FDesignOptions) then
      begin
        b := Byte(t.Typ);
        Stream.Write(b, 1);
        if t.Typ = gtAddIn then
          frWriteString(Stream, t.ClassName);
        Stream.Write(i, 1);
        t.SaveToStream(Stream);
      end;
    end;
  end;
  b := $FE;
  Stream.Write(b, 1);
  Parent.FVal.WriteBinaryData(Stream);
  SMemo.Assign(Parent.Variables);
  frWriteMemo(Stream, SMemo);
  if frDataManager <> nil then
  begin
    b := $FD;
    Stream.Write(b, 1);
    frDataManager.SaveToStream(Stream);
  end;
end;

procedure TfrPages.SavetoXML(XML: TLrXMLConfig; const Path: String);
var
  i, j, C: Integer;
  t: TfrView;
  aPath,aSubPath: String;
begin
  XML.SetValue(Path+'PrintToDefault/Value'{%H-}, Parent.PrintToDefault);
  XML.SetValue(Path+'DoublePass/Value'{%H-}, Parent.DoublePass);
  XML.SetValue(Path+'SelectedPrinter/Value', Prn.Printers[Prn.PrinterIndex]);
  XML.SetValue(Path+'PageCount/Value'{%H-}, Count);
  for i := 0 to Count - 1 do // adding pages at first
  begin
    aPath := Path+'Page'+IntToStr(i+1)+'/';
    Pages[i].SaveToXML(XML, aPath);
    C:=0;
    for j:=0 to Pages[i].Objects.count - 1 do
    begin
      T := TfrView(Pages[i].Objects[j]);
      if not (doChildComponent in T.FDesignOptions) then
      begin
        aSubPath := aPath + 'Object'+IntTostr(C + 1)+'/';
        T.SaveToXML(XML, aSubPath);
        Inc(C);
      end;
    end;
    XML.SetValue(aPath+'ObjectCount/Value'{%H-}, C);
  end;
  Parent.FVal.WriteBinaryDataToXML(XML, Path+'FVal/');
  XML.SetValue(Path+'ParentVars/Value',Parent.Variables.Text);
  if frDataManager <> nil then
  begin
    frDataManager.SaveToXML(XML, Path+'Datamanager/');
  end;
end;

function TfrPages.PageByName(const APageName: string): TfrPage;
var
  i:integer;
begin
  Result:=nil;
  for i:=0 to FPages.Count - 1 do
    if CompareText(APageName, TfrPage(FPages[i]).Name) = 0 then
      Exit(TfrPage(FPages[i]));
end;

{-----------------------------------------------------------------------}
constructor TfrEMFPages.Create(AParent: TfrReport);
begin
  inherited Create;
  Parent := AParent;
  FPages := TFpList.Create;
end;

destructor TfrEMFPages.Destroy;
begin
  Clear;
  FPages.Free;
  inherited Destroy;
end;

function TfrEMFPages.GetCount: Integer;
begin
  Result := FPages.Count;
end;

function TfrEMFPages.GetPages(Index: Integer): PfrPageInfo;
begin
  Result := FPages[Index];
end;

procedure TfrEMFPages.Clear;
begin
  while FPages.Count > 0 do
    Delete(0);
end;

procedure TfrEMFPages.Draw(Index: Integer; Canvas: TCanvas; DrawRect: TRect);
var
  p: PfrPageInfo;
  t: TfrView;
  i: Integer;
  sx, sy: Double;
  v, IsPrinting: Boolean;
  h: THandle;
  oldRgn, pageRgn: HRGN;
begin
  IsPrinting := Printer.Printing and (Canvas is TPrinterCanvas);
  {$IFDEF DebugLR}
  DebugLn('TfrEMFPages.Draw IsPrinting=%d PageIndex=%d Canvas.ClassName=%s '+
          'CanvasPPI=%d',[ord(IsPrinting), Index, Canvas.ClassName,
          Canvas.Font.pixelsPerInch]);
  {$ENDIF}
  pageRgn := 0;
  oldRgn := CreateRectRgn(0, 0, 0, 0);
  LCLIntf.GetClipRgn(Canvas.Handle, oldRgn);
  try

    DocMode := dmPrinting;
    p := FPages[Index];
    with p^ do
    begin
      if Visible then
      begin
        if Page = nil then
          ObjectsToPage(Index);

        sx:=(DrawRect.Right-DrawRect.Left)/PrnInfo.PgW;
        sy:=(DrawRect.Bottom-DrawRect.Top)/PrnInfo.PgH;
        h:= Canvas.Handle;
        pageRgn := CreateRectRgn(DrawRect.Left+1, DrawRect.Top+1, DrawRect.Right-1, DrawRect.Bottom-1);
        LCLIntf.SelectClipRGN(Canvas.Handle, pageRgn);

        for i := 0 to Page.Objects.Count - 1 do
        begin
          t :=TfrView(Page.Objects[i]);
          v := True;
          {$IFNDEF LCLNOGUI}
          if not IsPrinting then
          begin
            with t, DrawRect do
            begin
              v := RectVisible(h, Rect(Round(x * sx) + Left - 10,
                                       Round(y * sy) + Top - 10,
                                       Round((x + dx) * sx) + Left + 10,
                                       Round((y + dy) * sy) + Top + 10));
            end;
          end;
          {$ENDIF}
          if v then
          begin
            t.ScaleX := sx;
            t.ScaleY := sy;
            t.OffsX := DrawRect.Left;
            t.OffsY := DrawRect.Top;
            t.IsPrinting := IsPrinting;
            t.Draw(Canvas);
          end;
        end;

        LCLIntf.DeleteObject(pageRgn);
        pageRgn := 0;

      end
  {    else
      begin
        Page.Free;
        Page := nil;
      end;}
    end;
  finally
    if pageRgn<>0 then
      LCLIntf.DeleteObject(pageRgn);
    LCLIntf.SelectClipRGN(Canvas.Handle, oldRgn);
    LCLIntf.DeleteObject(oldRgn);
  end;
end;

procedure TfrEMFPages.ExportData(Index: Integer);
var
  p: PfrPageInfo;
  b: Byte;
  t: TfrView;
  s: String;
begin
  p := FPages[Index];
  with p^ do
  begin
    Stream.Position := 0;
    Stream.Read(frVersion, 1);
    while Stream.Position < Stream.Size do
    begin
      b := 0;
      Stream.Read(b, 1);
      if b = gtAddIn then
        s := ReadString(Stream) else
        s := '';
      t := frCreateObject(b, s, nil);
      t.StreamMode := smPrinting;
      t.LoadFromStream(Stream);
      t.ExportData;
      t.Free;
    end;
  end;
end;

procedure TfrEMFPages.ObjectsToPage(Index: Integer);
var
  p: PfrPageInfo;
  b: Byte;
  t: TfrView;
  s: String;
begin
  p := FPages[Index];
  with p^ do
  begin
    if Page <> nil then
      Page.Free;
    Page := TfrPageReport.Create(pgSize, pgWidth, pgHeight, pgOr);
    Stream.Position := 0;
    Stream.Read(frVersion, 1);
    while Stream.Position < Stream.Size do
    begin
      b := 0;
      Stream.Read(b, 1);
      if b = gtAddIn then
        s := ReadString(Stream)
      else
        s := '';
      t := frCreateObject(b, s, P^.Page);
      try
        t.StreamMode := smPrinting;
        t.LoadFromStream(Stream);
        t.StreamMode := smDesigning;
      except
        if frVersion in [25, 28] then
          ShowMessage(format(sReportCorruptOldKnowVersion,[frVersion]))
        else
          ShowMessage(format(sReportCorruptUnknownVersion,[frVersion]));
        break;
      end;
//      Page.Objects.Add(t);
    end;
  end;
end;

procedure TfrEMFPages.PageToObjects(Index: Integer);
var
  i: Integer;
  p: PfrPageInfo;
  t: TfrView;
begin
  p := FPages[Index];
  with p^ do
  begin
    Stream.Clear;
    frVersion := frCurrentVersion;
    Stream.Write(frVersion, 1);
    for i := 0 to Page.Objects.Count - 1 do
    begin
      t :=TfrView(Page.Objects[i]);
      if not (doChildComponent in T.DesignOptions) then
      begin
        t.StreamMode := smPrinting;
        Stream.Write(t.Typ, 1);
        if t.Typ = gtAddIn then
          frWriteString(Stream, t.ClassName);
        t.Memo1.Assign(t.Memo);
        t.SaveToStream(Stream);
      end;
    end;
  end;

  P^.pgOr:=P^.Page.Orientation;
end;

procedure TfrEMFPages.Insert(Index: Integer; APage: TfrPage);
var
  p: PfrPageInfo;
begin
  GetMem(p, SizeOf(TfrPageInfo));
  FillChar(p^, SizeOf(TfrPageInfo), 0);
  if Index >= FPages.Count then
    FPages.Add(p)
  else
    FPages.Insert(Index, p);
    
  with p^ do
  begin
    Stream := TMemoryStream.Create;
    frVersion := frCurrentVersion;
    Stream.Write(frVersion, 1);
    pgSize := APage.pgSize;
    pgWidth := APage.Width;
    pgHeight := APage.Height;
    pgOr := APage.Orientation;
    pgMargins := APage.UseMargins;
    PrnInfo := APage.PrnInfo;
  end;
end;

procedure TfrEMFPages.Add(APage: TfrPage);
begin
  Insert(FPages.Count, APage);
  if CurReport <> nil then
    CurReport.DoBeginPage(PageNo);
  if (MasterReport <> CurReport) and (MasterReport <> nil) then
    MasterReport.DoBeginPage(PageNo);
end;

procedure TfrEMFPages.Delete(Index: Integer);
begin
  if Pages[Index]^.Page <> nil then Pages[Index]^.Page.Free;
  if Pages[Index]^.Stream <> nil then Pages[Index]^.Stream.Free;
  FreeMem(Pages[Index], SizeOf(TfrPageInfo));
  FPages.Delete(Index);
end;

procedure TfrEMFPages.ResetFindData;
var
  i: Integer;
  j: Integer;
  P: PfrPageInfo;
begin
  for i:=0 to Count - 1 do
  begin
    P:=Pages[i];
    if Assigned(P^.Page) then
      for j:=0 to P^.Page.Objects.Count - 1 do
        TfrView(P^.Page.Objects[j]).FindHighlight:=false;
  end;
end;

function TfrEMFPages.DoMouseClick(Index: Integer; pt: TPoint; var AInfo: String
  ): Boolean;
var
  PgInf:  PfrPageInfo;
  V: TfrView;
  i: Integer;
  R1:TRect;
begin
  Result := False;
  PgInf := FPages[Index];
  if not Assigned(PgInf) then exit;

  AInfo := '';
  if not Assigned(PgInf^.Page) then
    ObjectsToPage(Index);

  for i := 0 to PgInf^.Page.Objects.Count - 1 do
  begin
    V := TfrView(PgInf^.Page.Objects[i]);
    R1:=Rect(Round(V.X), Round(V.Y), Round((V.X + V.DX)), Round((V.Y + V.DY)));
    if PtInRect(R1, pt) then
    begin
      Result:=Parent.DoObjectClick(V);
      if Result then
        AInfo:=V.FURLInfo;
      exit;
    end;
  end;
end;

function TfrEMFPages.DoMouseMove(Index: Integer; pt: TPoint;
  var Cursor: TCursor; var AInfo: String): TfrView;
var
  PgInf:  PfrPageInfo;
  V: TfrView;
  i: Integer;
  R1:TRect;
begin
  Result := nil;
  PgInf := FPages[Index];
  if not Assigned(PgInf) then exit;

  AInfo := '';
  if not Assigned(PgInf^.Page) then
    ObjectsToPage(Index);

  for i := 0 to PgInf^.Page.Objects.Count - 1 do
  begin
    V := TfrView(PgInf^.Page.Objects[i]);
    R1:=Rect(Round(V.X), Round(V.Y), Round((V.X + V.DX)), Round((V.Y + V.DY)));
    if PtInRect(R1, pt) then
    begin
      Result := V;

      if Result is TfrMemoView then
        Cursor:=TfrMemoView(Result).Cursor;

      if Assigned(Parent.OnMouseOverObject) then
        Parent.OnMouseOverObject(V, Cursor);
      exit;
    end;
  end;
end;

procedure TfrEMFPages.LoadFromStream(AStream: TStream);
var
  i, o, c: Integer;
  b, compr: Byte;
  p: PfrPageInfo;
  procedure ReadVersion22;
  var
    Pict: TfrPictureView;
  begin
    frReadMemo22(AStream, SMemo);
    if SMemo.Count > 0 then
      Parent.SetPrinterTo(SMemo[0]);
    AStream.Read(c, 4);
    i := 0;
    repeat
      AStream.Read(o, 4);
      GetMem(p, SizeOf(TfrPageInfo));
      FillChar(p^, SizeOf(TfrPageInfo), 0);
      FPages.Add(p);
      with p^ do
      begin
        AStream.Read(pgSize, 2);
        AStream.Read(pgWidth, 4);
        AStream.Read(pgHeight, 4);
        AStream.Read(b, 1);
        pgOr := TPrinterOrientation(b);
        AStream.Read(b, 1);
        pgMargins := Boolean(b);
        Prn.SetPrinterInfo(pgSize, pgWidth, pgHeight, pgOr);
        Prn.FillPrnInfo(PrnInfo);

        Pict := TfrPictureView.Create(P^.Page);
        Pict.SetBounds(0, 0, PrnInfo.PgW, PrnInfo.PgH);
        Pict.Picture.Graphic.LoadFromStream(AStream);

        Stream := TMemoryStream.Create;
        b := frCurrentVersion;
        Stream.Write(b, 1);
        Pict.StreamMode := smPrinting;
        Stream.Write(Pict.Typ, 1);
        Pict.SaveToStream(Stream);
        Pict.Free;
      end;
      AStream.Seek(o, soFromBeginning);
      Inc(i);
    until i >= c;
  end;

begin
  {$ifdef DebugLR}
  DebugLnEnter('TfrEMFPages.LoadFromStream: INIT',[]);
  {$endif}
  Clear;
  compr := 0;
  AStream.Read(compr, 1);
  if not (compr in [0, 1, 255]) then
  begin
    AStream.Seek(0, soFromBeginning);
    ReadVersion22;
    Exit;
  end;
  AddPagesFromStream(AStream, false);
  {$ifdef DebugLR}
  DebugLnExit('TfrEMFPages.LoadFromStream: DONE',[]);
  {$endif}
end;

procedure TfrEMFPages.AddPagesFromStream(AStream: TStream;
  AReadHeader: boolean=true);
var
  i, o, c: Integer;
  b, compr: Byte;
  p: PfrPageInfo;
  s: TMemoryStream;

begin
  {$ifdef DebugLR}
  DebugLnEnter('TfrEMFPages.AddPagesFromStream: INIT',[]);
  {$endif}
  Compr := 0;
  if AReadHeader then begin
    AStream.Read(compr, 1);
    if not (compr in [0, 1, 255]) then
    begin
      Exit;
    end;
  end;
  Parent.SetPrinterTo(frReadString(AStream));
  c := 0;
  AStream.Read(c, 4);
  i := 0;
  repeat
    o := 0;
    AStream.Read(o, 4);
    GetMem(p, SizeOf(TfrPageInfo));
    FillChar(p^, SizeOf(TfrPageInfo), #0);
    FPages.Add(p);
    with p^ do
    begin
      AStream.Read(pgSize, 2);
      AStream.Read(pgWidth, 4);
      AStream.Read(pgHeight, 4);
      b := 0;
      AStream.Read(b, 1);
      pgOr := TPrinterOrientation(b);
      AStream.Read(b, 1);
      pgMargins := Boolean(b);
      if compr <> 0 then
      begin
        s := TMemoryStream.Create;
        s.CopyFrom(AStream, o - AStream.Position);
        Stream := TMemoryStream.Create;
        frCompressor.DeCompress(s, Stream);
        s.Free;
      end
      else
      begin
        Stream := TMemoryStream.Create;
        Stream.CopyFrom(AStream, o - AStream.Position);
      end;
      Prn.SetPrinterInfo(pgSize, pgWidth, pgHeight, pgOr);
      Prn.FillPrnInfo(PrnInfo);
    end;
    AStream.Seek(o, soFromBeginning);
    Inc(i);
  until i >= c;
  {$ifdef DebugLR}
  DebugLnExit('TfrEMFPages.AddPagesFromStream: DONE',[]);
  {$endif}
end;

procedure TfrEMFPages.LoadFromXML(XML: TLrXMLConfig; const Path: String);
begin
  // todo
end;

procedure TfrEMFPages.SaveToStream(AStream: TStream);
var
  i, o, n: Integer;
  b: Byte;
  s: TMemoryStream;
begin
  b := Byte(frCompressor.Enabled);
  AStream.Write(b, 1);
  frWriteString(AStream, Prn.Printers[Prn.PrinterIndex]);
  n := Count;
  AStream.Write(n, 4);
  i := 0;
  repeat
    o := AStream.Position;
    AStream.Write(o, 4); // dummy write
    with Pages[i]^ do
    begin
      AStream.Write(pgSize, 2);
      AStream.Write(pgWidth, 4);
      AStream.Write(pgHeight, 4);
      b := Byte(pgOr);
      AStream.Write(b, 1);
      b := Byte(pgMargins);
      AStream.Write(b, 1);
      Stream.Position := 0;
      if frCompressor.Enabled then
      begin
        s := TMemoryStream.Create;
        frCompressor.Compress(Stream, s);
        AStream.CopyFrom(s, s.Size);
        s.Free;
      end
      else
        AStream.CopyFrom(Stream, Stream.Size);
    end;
    n := AStream.Position;
    AStream.Seek(o, soFromBeginning);
    AStream.Write(n, 4);
    AStream.Seek(0, soFromEnd);
    Inc(i);
  until i >= Count;
end;

procedure TfrEMFPages.SavePageToStream(PageNo:Integer; AStream: TStream);
var
  o, n: Integer;
  b: Byte;
  s: TMemoryStream;
begin
  if (PageNo >= 0) and (PageNo < Count) then  // fool-proof :)
  begin
    b := Byte(frCompressor.Enabled);
    AStream.Write(b, 1);
    frWriteString(AStream, Prn.Printers[Prn.PrinterIndex]);
    n := 1;
    AStream.Write(n, 4);
    o := AStream.Position;
    AStream.Write(o, 4); // dummy write
    with Pages[PageNo]^ do
    begin
      AStream.Write(pgSize, 2);
      AStream.Write(pgWidth, 4);
      AStream.Write(pgHeight, 4);
      b := Byte(pgOr);
      AStream.Write(b, 1);
      b := Byte(pgMargins);
      AStream.Write(b, 1);
      Stream.Position := 0;
      if frCompressor.Enabled then
      begin
        s := TMemoryStream.Create;
        frCompressor.Compress(Stream, s);
        AStream.CopyFrom(s, s.Size);
        s.Free;
      end
      else
        AStream.CopyFrom(Stream, Stream.Size);
    end;
    n := AStream.Position;
    AStream.Seek(o, soFromBeginning);
    AStream.Write(n, 4);
    AStream.Seek(0, soFromEnd);
  end
  else
    raise ERangeError.CreateFmt('Save page: PageNo %d out of range [0..%d]', [PageNo, Count-1]);
end;

procedure TfrEMFPages.SaveToXML(XML: TLrXMLConfig; const Path: String);
begin
  // Todo
end;

procedure TfrEMFPages.UpgradeToCurrentVersion;
var
  i: Integer;
begin
  for i:=0 to Count-1 do begin
    ObjectsToPage(i);
    PageToObjects(i);
  end;
end;

{-----------------------------------------------------------------------}
constructor TfrValues.Create;
begin
  inherited Create;
  FItems := TStringList.Create;
end;

destructor TfrValues.Destroy;
begin
  Clear;
  FItems.Free;
  inherited Destroy;
end;

procedure TfrValues.WriteBinaryData(Stream: TStream);
var
  i, n: Integer;

  procedure WriteStr(s: String);
  var
    n: Byte;
  begin
    n := Length(s);
    Stream.Write(n, 1);
    Stream.Write(s[1], n);
  end;

begin
  with Stream do
  begin
    n := FItems.Count;
    WriteBuffer(n, SizeOf(n));
    for i := 0 to n - 1 do
    with Objects[i] do
    begin
      WriteBuffer(Typ, SizeOf(Typ));
      WriteBuffer(OtherKind, SizeOf(OtherKind));
      WriteStr(DataSet);
      WriteStr(Field);
      WriteStr(FItems[i]);
    end;
  end;
end;

procedure TfrValues.WriteBinaryDataToXML(XML: TLrXMLConfig; const Path: String);
var
  i: integer;
  aSubPath: String;
begin
  XML.SetValue(Path+'Count/Value'{%H-}, FItems.Count);
  for i:= 0 to FItems.Count-1 do
  with Objects[i] do
  begin
    aSubPath := Path+'Objects'+InttoStr(i+1)+'/';
    XML.SetValue(aSubPath+'Typ/Value'{%H-}, Ord(Typ));
    XML.SetValue(aSubPath+'OtherKind/Value'{%H-}, OtherKind);
    XML.SetValue(aSubPath+'Dataset/Value', DataSet);
    XML.SetValue(aSubPath+'Field/Value', Field);
    XML.SetValue(aSubPath+'Item/Value', FItems[i]);
  end;
end;

procedure TfrValues.ReadBinaryData(Stream: TStream);
var
  i, j, n: Integer;
  li: longint;
  b: byte;
  val: TfrValue;

  function ReadStr: String;
  var
    n: Byte;
  begin
    n := 0;
    Stream.Read(n, 1);
    SetLength(Result, n);
    Stream.Read(Result[1], n);
  end;

begin
  Clear;
  FItems.Sorted := False;
  with Stream do
  begin
    n := 0;
    ReadBuffer(n, SizeOf(n));
    for i := 0 to n - 1 do
    begin
      j := AddValue;
      val := Objects[j];
      with val do
      begin
        if frVersion=23 then
        begin
          Read(b, 1);
          Read(li, 4);
          typ := TfrValueType(b);
          OtherKind := li;
        end else
        if frVersion>23 then
        begin
          ReadBuffer(Typ, SizeOf(Typ));
          ReadBuffer(OtherKind, SizeOf(OtherKind));
        end;
        DataSet := ReadStr;
        Field := ReadStr;
        FItems[j] := ReadStr;
      end;
    end;
  end;
end;

procedure TfrValues.ReadBinaryDataFromXML(XML: TLrXMLConfig; const Path: String);
var
  i,j,n: Integer;
  aSubPath: String;
begin
  clear;
  FItems.Sorted := False;
  n := XML.GetValue(Path+'Count/Value'{%H-}, 0);
  for i:= 0 to n - 1 do
  begin
    j := AddValue;
    with Objects[j] do
    begin
      aSubPath := Path+'Objects'+InttoStr(i+1)+'/';
      Typ := TfrValueType(XML.GetValue(aSubPath+'Typ/Value'{%H-}, 0)); // TODO check default value
      OtherKind := XML.GetValue( aSubPath+'OtherKind/Value'{%H-}, 0); // TODO check default value
      DataSet := XML.GetValue(aSubPath+'Dataset/Value', ''); // TODO check default value
      Field := XML.GetValue(aSubPath+'Field/Value', ''); // TODO check default value
      FItems[j] := XML.GetValue(aSubPath+'Item/Value', ''); // TODO check default value
    end;
  end;
end;

function TfrValues.GetValue(Index: Integer): TfrValue;
begin
  Result := TfrValue(FItems.Objects[Index]);
end;

function TfrValues.AddValue: Integer;
begin
  Result := FItems.AddObject('', TfrValue.Create);
end;

procedure TfrValues.Clear;
var
  i: Integer;
begin
  for i := 0 to FItems.Count - 1 do
    TfrValue(FItems.Objects[i]).Free;
  FItems.Clear;
end;

function TfrValues.FindVariable(const s: String): TfrValue;
var
  i: Integer;
begin
  Result := nil;
  i := FItems.IndexOf(s);
  if i <> -1 then
    Result := Objects[i];
end;

{----------------------------------------------------------------------------}
constructor TfrReport.Create(AOwner: TComponent);
const
  Clr: Array[0..1] of TColor = (clWhite, clSilver);

var
  j: Integer;
  i: Integer;
begin
  inherited Create(AOwner);
  FRebuildPrinter:=false;

  {$IFDEF LCLNOGUI}
  FRInitialized := True;
  TempBmp := TVirtualBitmap.Create;
  FDetailReports:=TlrDetailReports.Create;
  FPages := TfrPages.Create(Self);
  FEMFPages := TfrEMFPages.Create(Self);
  FVars := TStringList.Create;
  FVal := TfrValues.Create;
  FileName := sUntitled;
  FComments:=TStringList.Create;
  FScript:=TfrScriptStrings.Create;
  UpdateObjectStringResources;
  {$ELSE}
  if not FRInitialized then
  begin
    FRInitialized := True;
    SBmp := TBitmap.Create;
    TempBmp := TBitmap.Create;
    SBmp.Width := 8;
    SBmp.Height := 8;
    TempBmp.Width := 8;
    TempBmp.Height := 8;
    for j := 0 to 7 do
    begin
      for i := 0 to 7 do
        SBmp.Canvas.Pixels[i, j] := Clr[(j + i) mod 2];
    end;
    frProgressForm := TfrProgressForm.Create(nil);
  end;

  FDetailReports:=TlrDetailReports.Create;
  FPages := TfrPages.Create(Self);
  FEMFPages := TfrEMFPages.Create(Self);
  FVars := TStringList.Create;
  FVal := TfrValues.Create;
  FShowProgress := True;
  FModalPreview := True;
  FModifyPrepared := True;
  FPreviewButtons := [pbZoom, pbLoad, pbSave, pbPrint, pbFind, pbHelp, pbExit];
  FInitialZoom := pzDefault;
  FDefaultCopies := 1;
  FileName := sUntitled;
  FComments:=TStringList.Create;
  FScript:=TfrScriptStrings.Create;
  UpdateObjectStringResources;
  {$ENDIF}
end;

destructor TfrReport.Destroy;
begin
  if CurReport=Self then
    CurReport:=nil;
  FVal.Free;
  FVars.Free;
  FEMFPages.Free;
  FEMFPages := nil;
  FPages.Free;
  FComments.Free;
  FreeAndNil(FDetailReports);
  FreeAndNil(FScript);
  inherited Destroy;
end;

procedure TfrReport.Clear;
begin
  Pages.Clear;
  if frDataManager <> nil then
    frDataManager.Clear;
  DoublePass := False;
  ClearAttribs;
  FDetailReports.Clear;
  DocMode := dmDesigning;
end;

procedure TfrReport.DefineProperties(Filer: TFiler);
begin
  inherited DefineProperties(Filer);
  Filer.DefineProperty('StoreInDFM', @ReadStoreInDFM, nil, false);
  Filer.DefineProperty('ReportXML', @ReadReportXML, @WriteReportXML, fStoreInForm);
  Filer.DefineBinaryProperty('ReportForm', @ReadBinaryData, nil, false);
end;

procedure TfrReport.ReadBinaryData(Stream: TStream);
var
  n: Integer;
begin
  n := 0;
  Stream.Read(n, 4); // version
  if FStoreInDFM then
  begin
    Stream.Read(n, 4);
    FDFMStream := TMemoryStream.Create;
    FDFMStream.CopyFrom(Stream, n);
    FDFMStream.Position := 0;
  end;
end;

procedure TfrReport.Notification(AComponent: TComponent; Operation: TOperation);
begin
  inherited Notification(AComponent, Operation);
  if (Operation = opRemove) and (AComponent = Dataset) then
    Dataset := nil;
  if (Operation = opRemove) and (AComponent = Preview) then
    Preview := nil;
end;

// report building events
procedure TfrReport.InternalOnProgress(Percent: Integer);
begin
  if Assigned(FOnProgress) then
    FOnProgress(Percent)
  else
    if fShowProgress then
    begin
      with frProgressForm do
      begin
        if (MasterReport.DoublePass and MasterReport.FinalPass) or
            (FCurrentFilter <> nil) then
          Label1.Caption:=Format('%s %d %s %d',[FirstCaption,Percent,sFrom,SavedAllPages])
        else
          Label1.Caption:=Format('%s %d',[FirstCaption,Percent]);
          
        Application.ProcessMessages;
      end;
    end;
end;

function CopyVarString(V: Variant): String;
begin
  Result := pchar(TVarData(V).VString)
end;

procedure TfrReport.InternalOnGetValue(ParName: String; var ParValue: String);
var
  i, j, AFormat: Integer;
  AFormatStr: String;
begin
  SubValue := '';
  if Assigned(CurView) then
  begin
    AFormat := CurView.Format;
    AFormatStr := CurView.FormatStr;
  end
  else
  begin
    AFormat := 0;
    AFormatStr := '';
  end;
  i := Pos(' #', ParName);
  if i <> 0 then
  begin
    AFormatStr := Copy(ParName, i + 2, Length(ParName) - i - 1);
    ParName := Copy(ParName, 1, i - 1);

    if AFormatStr[1] in ['0'..'9', 'N', 'n'] then
    begin
      if AFormatStr[1] in ['0'..'9'] then
        AFormatStr := 'N' + AFormatStr;
      AFormat := $01000000;
      if AFormatStr[2] in ['0'..'9'] then
        AFormat := AFormat + $00010000;
      i := Length(AFormatStr);
      while i > 1 do
      begin
        if AFormatStr[i] in ['.', ',', '-'] then
        begin
          AFormat := AFormat + Ord(AFormatStr[i]);
          AFormatStr[i] := '.';
          if AFormatStr[2] in ['0'..'9'] then
          begin
            Inc(i);
            j := i;
            while (i <= Length(AFormatStr)) and (AFormatStr[i] in ['0'..'9']) do
              Inc(i);
            AFormat := AFormat + 256 * StrToInt(Copy(AFormatStr, j, i - j));
          end;
          break;
        end;
        Dec(i);
      end;
      if not (AFormatStr[2] in ['0'..'9']) then
      begin
        AFormatStr := Copy(AFormatStr, 2, 255);
        AFormat := AFormat + $00040000;
      end;
    end
    else if AFormatStr[1] in ['D', 'T', 'd', 't'] then
    begin
      AFormat := $02040000;
      AFormatStr := Copy(AFormatStr, 2, 255);
    end
    else if AFormatStr[1] in ['B', 'b'] then
    begin
      AFormat := $04040000;
      AFormatStr := Copy(AFormatStr, 2, 255);
    end;
  end;

  CurVariable := ParName;
  CurValue := 0;
  GetVariableValue(ParName, CurValue);
  ParValue := FormatValue(CurValue, AFormat, AFormatStr);
  {
  if TVarData(CurValue).VType=varString then
    ValStr := CopyVarString(CurValue)
  else
    ValStr := CurValue;
  ParValue := FormatValueStr(ValStr, Format, FormatStr);
  }
  {$IFDEF DebugLR}
  DebugLn('TfrReport.InternalOnGetValue(%s) Value=%s',[ParName,ParValue]);
  {$ENDIF}
end;

procedure TfrReport.InternalOnEnterRect(Memo: TStringList; View: TfrView);
begin
  {$IFDEF DebugLR}
  DebugLn('TfrReport.InternalOnEnterRect View=%s',[ViewInfo(View)]);
  {$ENDIF}
  with View do
    if (FDataSet <> nil) and frIsBlob(TfrTField(FDataSet.FindField(FField))) then
      GetBlob(TfrTField(FDataSet.FindField(FField)));
  DoEnterRect(Memo, View);
end;

procedure TfrReport.InternalOnExportData(View: TfrView);
begin
  FCurrentFilter.OnData(View.x, View.y, View);
end;

procedure TfrReport.InternalOnExportText(x, y: Integer; const text: String;
  View: TfrView);
begin
  FCurrentFilter.OnText(x, y, text, View);
end;

procedure TfrReport.InternalOnExported(View: TfrView);
begin
  FCurrentFilter.OnExported(View.x, View.y, View);
end;

procedure TfrReport.ReadStoreInDFM(Reader: TReader);
begin
  FStoreInDFM := Reader.ReadBoolean;
end;

procedure TfrReport.ReadReportXML(Reader: TReader);
begin
  FXMLReport := Reader.ReadString;
end;

procedure TfrReport.WriteReportXML(Writer: TWriter);
var
  st: TStringStream;
begin
  {$IF FPC_FULLVERSION >= 30101}
  st := TStringStream.CreateRaw('');
  {$ELSE}
  st := TStringStream.Create('');
  {$ENDIF}
  SaveToXMLStream(st);
  Writer.WriteString(st.DataString);
  st.free;
end;

function TfrReport.FormatValue(V: Variant; AFormat: Integer; const AFormatStr: String): String;
var
  f1, f2: Integer;
  c: Char;
  s: String;
  Dummy: Extended;
  IsNumeric: Boolean;
begin
  if (TVarData(v).VType = varEmpty) {VarIsEmpty(v)} or VarIsNull(v) then
  begin
    Result := ' ';
    Exit;
  end;
  
  c := DefaultFormatSettings.DecimalSeparator;
  f1 := (AFormat div $01000000) and $0F;
  f2 := (AFormat div $00010000) and $FF;
  try
    case f1 of
      fmtText:
        begin
          if VarIsType(v, varDate) and (trunc(Extended(v))=0) then
          begin
            Result := TimeToStr(v);
            if Result='' then
              Result := FormatDateTime('hh:nn:ss', v, [fdoInterval]);
          end
          else
            Result := v;
        end;
      fmtNumber:
        begin
          IsNumeric := VarIsNumeric(v) or TryStrToFloat(v, Dummy);
          if not IsNumeric then
            result := v
          else begin
            DefaultFormatSettings.DecimalSeparator := Chr(AFormat and $FF);
            case f2 of
              0: Result := FormatFloat('###.##', v);
              1: Result := FloatToStrF(Extended(v), ffFixed, 15, (AFormat div $0100) and $FF);
              2: Result := FormatFloat('#,###.##', v);
              3: Result := FloatToStrF(Extended(v), ffNumber, 15, (AFormat div $0100) and $FF);
              4: Result := FormatFloat(AFormatStr, v);
            end;
          end;
        end;
      fmtDate:
        if v=0 then
          Result := ''  // date is null
        else
        if f2 = 4 then
          Result := SysToUTF8(FormatDateTime(AFormatStr, v, [fdoInterval]))
        else
          Result := FormatDateTime(frDateFormats[f2], v, [fdoInterval]);
      fmtTime:
         if f2 = 4 then
           Result := FormatDateTime(AFormatStr, v, [fdoInterval])
         else
           Result := FormatDateTime(frTimeFormats[f2], v, [fdoInterval]);
      fmtBoolean :
         begin
           if f2 = 4 then
             s := AFormatStr
           else
             s := BoolStr[f2];
           if Integer(v) = 0 then
             Result := Copy(s, 1, Pos(';', s) - 1)
           else
             Result := Copy(s, Pos(';', s) + 1, 255);
         end;
    end;
  except
    on e:exception do
      Result := v;
  end;
  DefaultFormatSettings.DecimalSeparator := c;
end;

procedure TfrReport.GetVariableValue(const s: String; var aValue: Variant);
var
  Value: TfrValue;
  D: TfrTDataSet;
  F: TfrTField;
  s1, SE1: String;
  aCursr: Longint;

  function MasterBand: TfrBand;
  begin
    Result := CurBand;
    if Result.DataSet = nil then
      while Result.Prev <> nil do
        Result := Result.Prev;
  end;

begin
  TVarData(aValue).VType := varEmpty;

  DoGetValue(s,aValue);
     
  if TVarData(aValue).VType = varEmpty then
  begin
    Value := Values.FindVariable(s);
    if Assigned(Value) then
    begin
      with Value do
      begin
         case Typ of
          vtNotAssigned: aValue := '';
          vtDBField    : begin
                            F := TfrTField(DSet.FindField(Field));
                            if not F.DataSet.Active then
                              F.DataSet.Open;
                            if Assigned(F.OnGetText) then
                              aValue:=F.DisplayText
                            else
                              aValue:=lrGetFieldValue(F);//F.AsVariant;
                          end;
          vtFRVar       : aValue := frParser.Calc(Field);
          vtOther       : begin
                            if OtherKind = 1 then
                              aValue:=frParser.Calc(Field)
                            else
                              aValue:=frParser.Calc(frSpecFuncs[OtherKind]);
                          end;
         end;
      end;
    end
    else
    begin
      TVarData(aValue).VType := varEmpty;
      GetIntrpValue(s, aValue);
      if TVarData(aValue).VType = varEmpty then
      begin
        D := GetDefaultDataSet;
        frGetDataSetAndField(s, D, F);
        if F <> nil then
        begin
          if not F.DataSet.Active then
            F.DataSet.Open;
          if Assigned(F.OnGetText) then
             aValue:=F.DisplayText
          else
             aValue:=lrGetFieldValue(F); ///F.AsVariant
        end
        else
        if (D<>nil) and (roIgnoreFieldNotFound in FReportOptions) and
                lrValidFieldReference(s) then
          aValue := Null
        else
        begin
          s1 := UpperCase(s);
          if s1 = 'VALUE' then
            aValue:= CurValue
          else if s1 = frSpecFuncs[0] then
            aValue:= PageNo + 1
          else if s1 = frSpecFuncs[2] then
            aValue := CurDate
          else if s1 = frSpecFuncs[3] then
            aValue:= CurTime
          else if s1 = frSpecFuncs[4] then
            aValue:= MasterBand.Positions[psLocal]
          else if s1 = frSpecFuncs[5] then
            aValue:= MasterBand.Positions[psGlobal]
          else if s1 = frSpecFuncs[6] then
            aValue:= CurPage.ColPos
          else if s1 = frSpecFuncs[7] then
            aValue:= CurPage.CurPos
          else if s1 = frSpecFuncs[8] then
            aValue:= SavedAllPages
          else
          begin
            if frVariables.IndexOf(s) <> -1 then
            begin
              aValue:= frVariables[s];
              Exit;
            end else
            if s1 = 'REPORTTITLE' then
            begin
              aValue := Title;
              Exit;
            end
            else
            if IdentToCursor(S, aCursr) then
            begin
              aValue:=aCursr;
              exit;
            end;
            if s <> SubValue then
            begin
              SubValue := s;
              aValue:= frParser.Calc(s);
              SubValue := '';
            end
            else
            begin
              if roIgnoreSymbolNotFound in FReportOptions then
                aValue := Null
              else
              begin
                SE1:='';
                if Assigned(CurView) then
                  SE1:=SE1 + 'Object : ' + CurView.Name + #13;
                if Assigned(CurBand) then
                  SE1:=SE1 + 'Band : ' + CurBand.Name + #13;
                if Assigned(CurPage) then
                  SE1:=SE1 + 'Page : ' + CurPage.Name + #13;
                raise(EParserError.Create(SE1 + 'Undefined symbol: ' + SubValue));
              end;
            end;
          end;
        end;
      end;
    end;
  end;
  //check if CurView is TfrBandView to avoid clash with flBandPrintChildIfNotVisible. Issue 29313
  if Assigned(CurView) and ((CurView.Flags and flHideZeros <> 0) and not (CurView is TfrBandView)) then
  begin
    if TVarData(aValue).VType in [varSmallInt, varInteger, varCurrency,
       varDecimal, varShortInt, varByte, varWord, varLongWord, varInt64,
       varQWord, varDouble, varSingle] then
    begin
      if aValue = 0 then
        aValue:=Null;
    end;
  end;
end;

procedure TfrReport.OnGetParsFunction(const aName: String; p1, p2, p3: Variant;
   var val: Variant);

function ProcessObjMethods(Method:string):boolean;
var
  ObjName:string;
  Obj:TfrObject;
  Page:TfrPage;
  i, j:integer;
begin
  Result:=false;
  Obj:=nil;
  ObjName:=Copy2SymbDel(Method, '.');

  for i:=0 to CurReport.Pages.Count - 1 do
  begin
    Page := CurReport.Pages[i];
    if CompareText(Page.Name, ObjName) = 0 then
    begin
      // PageName.ObjName.Method
      Obj:=Page;
      
      if Method<>'' then
      begin
        ObjName:=Copy2SymbDel(Method, '.');
        for j:=0 to Page.Objects.Count - 1  do
        begin
          if CompareText(TfrObject(Page.Objects[j]).Name, ObjName) = 0 then
          begin
            Obj:=TfrObject(Page.Objects[j]);
            break;
          end;
        end;
      end;

      Break;
    end
    else
    begin
      for j:=0 to Page.Objects.Count - 1  do
      begin
        if CompareText(TfrObject(Page.Objects[j]).Name, ObjName) = 0 then
        begin
            Obj:=TfrObject(Page.Objects[j]);
            break;
        end;
      end;
      if Assigned(Obj) then
        break;
    end;
  end;

  if Assigned(Obj) then
    Result:=Obj.ExecMetod(UpperCase(Method), p1, p2, p3, val);
end;

var
  i: Integer;
begin
  val := varempty;
  {$ifdef DebugLR}
  DebugLn('OnGetParsFunction aName=%s p1=%s p2=%s p3=%s',[aName,p1,p2,p3]);
  {$endif}
  for i := 0 to frFunctionsCount - 1 do
    if frFunctions[i].FunctionLibrary.OnFunction(aName, p1, p2, p3, val) then
      exit;

  if (Pos('.', aName)>0) and ProcessObjMethods(aName) then
    exit;

  if not DoInterpFunction(aName, p1, p2, p3, val) then
  begin
    if Assigned(AggrBand){ and AggrBand.Visible } then
      DoUserFunction(aName, p1, p2, p3, val);
  end;
end;

function TfrReport.DoInterpFunction(const aName: String; p1, p2, p3: Variant;
  var val: Variant): boolean;
var
  Obj:TfrObject;
  ObjProp:string;
  ArrInd:Variant;
begin
  Result:=true;
  if aName = 'NEWPAGE' then
  begin
    CurBand.ForceNewPage := True;
    Val := '0';
  end
  else
  if aName = 'NEWCOLUMN' then
  begin
    CurBand.ForceNewColumn := True;
    Val := '0';
  end
  else
  if aName = 'STOPREPORT' then
    CurReport.Terminated:=true
  else
  if aName = 'SHOWBAND' then
    CurPage.ShowBandByName(p1)
  else
  if aName = 'INC' then
  begin
    frParser.OnGetValue(p1, ArrInd);
    frInterpretator.SetValue(p1, ArrInd + 1);
  end
  else
  if aName = 'DEC' then
  begin
    frParser.OnGetValue(p1, ArrInd);
    frInterpretator.SetValue(p1, ArrInd - 1);
  end
  else
  if aName = 'SETARRAY' then
  begin
    ObjProp:='';
    Obj:=DoFindObjMetod(p1, ObjProp);

    if Assigned(Obj) then
      Obj.ExecMetod('SETINDEXPROPERTY', UpperCase(ObjProp), frParser.Calc(p2), frParser.Calc(p3), Val)
    else
      frVariables['frA_' + p1 + '_' + VarToStr(frParser.Calc(p2))] := frParser.Calc(p3);
  end
  else
  if aName = 'GETARRAY' then
  begin
    ObjProp:='';
    Obj:=DoFindObjMetod(p1, ObjProp);

    if Assigned(Obj) then
      Obj.ExecMetod('GETINDEXPROPERTY', UpperCase(ObjProp), frParser.Calc(p2), frParser.Calc(p3), Val)
    else
      Val:=frVariables['frA_' + p1 + '_' + VarToStr(frParser.Calc(p2))];
  end
  else
    Result:=false;
end;

// load/save methods
procedure TfrReport.LoadFromStream(Stream: TStream);
begin

  CurReport := Self;
  if Stream.Read(frVersion, 1)<>1 then
    raise ELazReportException.CreateFmt('%s: %s', [sInvalidFRFReport, sUnableToReadVersion]);

  if frVersion < 21 then
  begin
    frVersion := 21;
    Stream.Position := 0;
  end;
  if frVersion <= frCurrentVersion then
  try
{$IFDEF FREEREP2217READ}
    if FRE_COMPATIBLE_READ and (frVersion >= 23) then
      frVersion := 22;
{$ENDIF}
    Pages.LoadFromStream(Stream);

    if frVersion>26 then
      FDetailReports.LoadFromStream(Stream);

  except
    on E:Exception do
    begin
      Pages.Clear;
      Pages.Add;
      MessageDlg(sInvalidFRFReport+^M+E.Message,mtError,[mbOk],0)
    end;
  end
  else
    raise ELazReportException.CreateFmt('%s: %s (%d)', [sInvalidFRFReport, sInvalidFRFVersion, frVersion]);
end;

procedure TfrReport.LoadFromXML(XML: TLrXMLConfig; const Path: String);
var
  ATitle: string;
begin

  ATitle := XML.GetValue(Path+'Version/Value', 'LR-ERROR');
  if ATitle='LR-ERROR' then
    raise ELazReportException.CreateFmt('%s: %s',[sReportLoadingError, sInvalidLRFReport]);

  CurReport := Self;
  frVersion := XML.GetValue(Path+'Version/Value'{%H-}, 21);
  fComments.Text := XML.GetValue(Path+'Comments/Value', '');
  fKeyWords := XML.GetValue(Path+'KeyWords/Value', '');
  fSubject  := XML.GetValue(Path+'Subject/Value', '');
  ATitle    := XML.GetValue(Path+'Title/Value', '');
  if ATitle<>'' then
    fTitle := ATitle;

  FReportCreateDate:=lrStrToDateTime(XML.GetValue(Path+'ReportCreateDate/Value', lrDateTimeToStr(Now)));
  FReportLastChange:=lrStrToDateTime(XML.GetValue(Path+'ReportLastChange/Value', lrDateTimeToStr(Now)));

  FReportVersionBuild:=XML.GetValue(Path+'ReportVersionBuild/Value', '');
  FReportVersionMajor:=XML.GetValue(Path+'ReportVersionMajor/Value', '');
  FReportVersionMinor:=XML.GetValue(Path+'ReportVersionMinor/Value', '');
  FReportVersionRelease:=XML.GetValue(Path+'ReportVersionRelease/Value', '');
  FReportAutor:=XML.GetValue(Path+'ReportAutor/Value', '');
  FScript.Text:= XML.GetValue(Path+'Script/Value', '');

  if frVersion < 21 then
    frVersion := 21;

  if frVersion <= frCurrentVersion then
    try
      {$IFDEF FREEREP2217READ}
      if FRE_COMPATIBLE_READ and (frVersion >= 23) then
        frVersion := 22;
      {$ENDIF}
      pages.LoadFromXML(XML, Path+'Pages/');
    except
      on E:Exception do
      begin
        Pages.Clear;
        Pages.Add;
        MessageDlg(sReportLoadingError+^M+E.Message,mtError,[mbOk],0)
      end;
    end
  else
    MessageDlg(sReportLoadingError,mtError,[mbOk],0);

  FDetailReports.LoadFromXML(XML, Path+'DetailReports/');
end;

procedure TfrReport.SaveToStream(Stream: TStream);
begin
  CurReport := Self;
  frVersion := frCurrentVersion;
  Stream.Write(frVersion, 1);
  Pages.SaveToStream(Stream);
  FDetailReports.SaveToStream(Stream);
end;

procedure TfrReport.LoadFromFile(const FName: String);
var
  Stream: TFileStream;
  Ext   : String;
begin
  Ext:=ExtractFileExt(fName);
  if SameText('.lrf',Ext) then
    LoadFromXMLFile(fName)
  else
  begin
    CheckFileExists(fName);
    Stream := TFileStream.Create(FName, fmOpenRead);
    LoadFromStream(Stream);
    Stream.Free;
    FileName := FName;
  end;
end;

procedure TfrReport.LoadFromXMLFile(const Fname: String);
var
  XML: TLrXMLConfig;
begin
  CheckFileExists(FName);
  XML := TLrXMLConfig.Create(nil);
  XML.Filename := UTF8ToSys(FName);
  try
    LoadFromXML(XML, 'LazReport/');
    FileName := FName;
  finally
    XML.Free;
  end;
end;

procedure TfrReport.LoadFromXMLStream(const Stream: TStream);
var
  XML: TLrXMLConfig;
begin
  XML := TLrXMLConfig.Create(nil);
  try
    XML.LoadFromStream(Stream);
    LoadFromXML(XML, 'LazReport/');
    FileName := '-stream-';
  finally
    XML.Free;
  end;
end;

procedure TfrReport.SaveToFile(FName: String);
var
  Stream: TFileStream;
  Ext   : string;
begin
  Ext:=ExtractFileExt(fName);
  if (Ext='') or (Ext='.') then
  begin
    Ext:='.lrf';
    fName:=ChangeFileExt(fName,Ext);
  end;
  
  if SameText('.lrf',Ext) then
    SaveToXMLFile(fName)
  else
  begin
    Stream := TFileStream.Create(FName, fmCreate);
    SaveToStream(Stream);
    Stream.Free;
  end;
end;

procedure TfrReport.SavetoXML(XML: TLrXMLConfig; const Path: String);
begin
  CurReport := Self;
  frVersion := frCurrentVersion;
  XML.SetValue(Path+'Version/Value'{%H-}, frVersion);

  XML.SetValue(Path+'Title/Value', fTitle);
  XML.SetValue(Path+'Subject/Value', fSubject);
  XML.SetValue(Path+'KeyWords/Value', fKeyWords);
  XML.SetValue(Path+'Comments/Value', fComments.Text);

  XML.SetValue(Path+'ReportCreateDate/Value', lrDateTimeToStr(FReportCreateDate));
  XML.SetValue(Path+'ReportLastChange/Value', lrDateTimeToStr(FReportLastChange));
  XML.SetValue(Path+'ReportVersionBuild/Value', FReportVersionBuild);
  XML.SetValue(Path+'ReportVersionMajor/Value', FReportVersionMajor);
  XML.SetValue(Path+'ReportVersionMinor/Value', FReportVersionMinor);
  XML.SetValue(Path+'ReportVersionRelease/Value', FReportVersionRelease);
  XML.SetValue(Path+'ReportAutor/Value', FReportAutor);

  XML.SetValue(Path+'Script/Value', FScript.Text);

  Pages.SaveToXML(XML, Path+'Pages/');

  FDetailReports.SaveToXML(XML, Path+'DetailReports/');
end;

procedure TfrReport.SaveToXMLFile(const FName: String);
var
  XML: TLrXMLConfig;
begin
  XML := TLrXMLConfig.Create(nil);
  XML.StartEmpty := True;
  XML.Filename := UTF8ToSys(FName);
  try
    SaveToXML(XML, 'LazReport/');
    XML.Flush;
  finally
    XML.Free;
  end;
end;

procedure TfrReport.SaveToXMLStream(const Stream: TStream);
var
  XML: TLrXMLConfig;
begin
  XML := TLrXMLConfig.Create(nil);
  XML.StartEmpty := True;
  try
    SaveToXML(XML, 'LazReport/');
    XML.SaveToStream(Stream);
  finally
    XML.Free;
  end;
end;

procedure TfrReport.LoadFromDB(Table: TDataSet; DocN: Integer);
var
  Stream: TMemoryStream;
begin
  Table.First;
  while not Table.Eof do
  begin
    if Table.Fields[0].AsInteger = DocN then
    begin
      Stream := TMemoryStream.Create;
      TfrTBlobField(Table.Fields[1]).SaveToStream(Stream);
      Stream.Position := 0;
      LoadFromStream(Stream);
      Stream.Free;
      Exit;
    end;
    Table.Next;
  end;
end;

procedure TfrReport.SaveToDB(Table: TDataSet; DocN: Integer);
var
  Stream: TMemoryStream;
  Found: Boolean;
begin
  Found := False;
  Table.First;
  while not Table.Eof do
  begin
    if Table.Fields[0].AsInteger = DocN then
    begin
      Found := True;
      break;
    end;
    Table.Next;
  end;

  if Found then
    Table.Edit else
    Table.Append;
  Table.Fields[0].AsInteger := DocN;
  Stream := TMemoryStream.Create;
  SaveToStream(Stream);
  Stream.Position := 0;
  TfrTBlobField(Table.Fields[1]).LoadFromStream(Stream);
  Stream.Free;
  Table.Post;
end;

procedure TfrReport.LoadPreparedReport(const FName: String);
var
  Stream: TFileStream;
begin
  Stream := TFileStream.Create(FName, fmOpenRead);
  EMFPages.LoadFromStream(Stream);
  Stream.Free;
  CanRebuild := False;
end;

procedure TfrReport.SavePreparedReport(const FName: String);
var
  Stream: TFileStream;
begin
  Stream := TFileStream.Create(FName, fmCreate);
  if not CanRebuild and not (roDontUpgradePreparedReport in Options) then
    EMFPages.UpgradeToCurrentVersion;
  EMFPages.SaveToStream(Stream);
  Stream.Free;
end;

procedure TfrReport.LoadTemplate(const fname: String; comm: TStrings;
  Bmp: TBitmap; Load: Boolean);
var
  Stream: TFileStream;
  b: Byte;
  fb: TBitmap;
  fm: TStringList;
  pos: Integer;
begin
  fb := TBitmap.Create;
  fm := TStringList.Create;
  Stream := TFileStream.Create(FName, fmOpenRead);
  if Load then
  begin
    ReadMemo(Stream, fm);
    pos := 0;
    Stream.Read(pos, 4);
    b := 0;
    Stream.Read(b, 1);
    if b <> 0 then
      fb.LoadFromStream(Stream);
    Stream.Position := pos;
    Stream.Read(frVersion, 1);
    Pages.LoadFromStream(Stream);
  end
  else
  begin
    ReadMemo(Stream, Comm);
    Stream.Read(pos, 4);
    Bmp.Assign(nil);
    Stream.Read(b, 1);
    if b <> 0 then
      Bmp.LoadFromStream(Stream);
  end;
  fm.Free; fb.Free;
  Stream.Free;
end;

procedure TfrReport.LoadTemplateXML(const fname: String; comm: TStrings;
  Bmp: TBitmap; Load: Boolean);
var
  XML: TLrXMLConfig;
  BMPSize:integer;
  M:TMemoryStream;
begin
  XML := TLrXMLConfig.Create(nil);
  XML.Filename := UTF8ToSys(FName);
  try
    if Load then
    begin
      LoadFromXML(XML, lrTemplatePath);
      FileName := '';
    end
    else
    begin
      comm.Text:=XML.GetValue(lrTemplatePath + 'Description/Value', '');
      BMPSize:=XML.GetValue(lrTemplatePath + 'Picture/Size/Value', 0);
      if BMPSize>0 then
      begin
        M:=TMemoryStream.Create;
        XMLToStream(XML, lrTemplatePath + 'Picture/', M);
        M.Position:=0;
        BMP.LoadFromStream(M);
        M.Free;
      end;
    end;
  finally
    XML.Free;
  end;
end;

procedure TfrReport.SaveTemplate(const fname: String; comm: TStrings; Bmp: TBitmap);
var
  Stream: TFileStream;
  b: Byte;
  pos, lpos: Integer;
begin
  Stream := TFileStream.Create(FName, fmCreate);
  frWriteMemo(Stream, Comm);
  b := 0;
  pos := Stream.Position;
  lpos := 0;
  Stream.Write(lpos, 4);
  if Bmp.Empty then
    Stream.Write(b, 1)
  else
  begin
    b := 1;
    Stream.Write(b, 1);
    Bmp.SaveToStream(Stream);
  end;
  lpos := Stream.Position;
  Stream.Position := pos;
  Stream.Write(lpos, 4);
  Stream.Position := lpos;
  frVersion := frCurrentVersion;
  Stream.Write(frVersion, 1);
  Pages.SaveToStream(Stream);
  Stream.Free;
end;

procedure TfrReport.SaveTemplateXML(const fname: String; Desc: TStrings;
  Bmp: TBitmap);
var
  XML: TLrXMLConfig;

procedure SavePicture;
var
  m: TMemoryStream;
begin
  M := TMemoryStream.Create;
  try
    BMP.SaveToStream(M);
    M.Position:=0;
    StreamToXML(XML, lrTemplatePath+'Picture/', M);
  finally
    M.Free;
  end;
end;

begin
  XML := TLrXMLConfig.Create(nil);
  XML.StartEmpty := True;
  XML.Filename := UTF8ToSys(FName);
  try
    XML.SetValue(lrTemplatePath + 'Description/Value', Desc.Text);
    if not Bmp.Empty then
      SavePicture;
    SaveToXML(XML, lrTemplatePath);
    XML.Flush;
  finally
    XML.Free;
  end;
end;

// report manipulation methods
function TfrReport.DesignReport: Integer;
var
  HF: String;
begin
  CurReport := Self;
  if Pages.Count = 0 then
    Pages.Add;
  HF := Application.HelpFile;
  Application.HelpFile := 'FRuser.hlp';
  if not Assigned(frDesigner)  and Assigned(ProcedureInitDesigner)  then
    ProcedureInitDesigner();
  if frDesigner <> nil then
  begin
    {$IFDEF MODALDESIGNER}
    Result:=frDesigner.ShowModal;
    {$ELSE}
    frDesigner.Show;
    Result:=mrOk;
    {$ENDIF}
  end;
  Application.HelpFile := HF;
end;

var
  FirstPassTerminated, FirstTime: Boolean;

procedure TfrReport.BuildBeforeModal(Sender: TObject);
begin
  {$IFDEF DebugLR}
  DebugLnEnter('TfrReport.BuildBeforeModal INIT FinalPass=%s DoublePass=%s',[dbgs(FinalPass),dbgs(DoublePass)]);
  {$ENDIF}
  DoBuildReport;
  if FinalPass then
  begin
    if frProgressForm<>nil then
    begin
      if Terminated then
        frProgressForm.ModalDone(mrCancel)
      else
        frProgressForm.ModalDone(mrOk);
    end;
  end
  else
  begin
    FirstPassTerminated := Terminated;
    SavedAllPages := EMFPages.Count;
    DoublePass := False;
    FirstTime := False;
    DoPrepareReport; // do final pass
    DoublePass := True;
  end;
  {$IFDEF DebugLR}
  DebugLnExit('TfrReport.BuildBeforeModal DONE');
  {$ENDIF}
end;

function TfrReport.PrepareReport: Boolean;
var
  ParamOk: Boolean;
begin
  {$IFDEF DebugLR}
  DebugLnEnter('TfrReport.PrepareReport INIT');
  {$ENDIF}
  AggrBand:= nil;
  DocMode := dmPrinting;
  CurDate := Date;
  CurTime := Time;
  MasterReport := Self;
  CurReport := Self;
  Values.Items.Sorted := True;
  frParser.OnGetValue := @GetVariableValue;
  frParser.OnFunction := @OnGetParsFunction;
  DoBeginDoc;

  Result := False;
  ParamOk := True;
  if frDataManager <> nil then
  begin
    FillQueryParams;
    ParamOk := frDataManager.ShowParamsDialog;
  end;
  
  if ParamOk then
    Result := DoPrepareReport;
    
  FinalPass := False;
  if frDataManager <> nil then
    frDataManager.AfterParamsDialog;
    
  DoEndDoc;
  {$IFDEF DebugLR}
  DebugLnExit('TfrReport.PrepareReport DONE');
  {$ENDIF}
end;

function TfrReport.DoPrepareReport: Boolean;
var
  s: String;
begin
  Result := True;
  Terminated := False;
  AppendPage := False;
  DisableDrawing := False;
  FinalPass := True;
  FirstTime := True;
  PageNo := 0;
  EMFPages.Clear;

  {$IFDEF DebugLR}
  DebugLnEnter('DoPrepareReport INIT DoublePass=%s',[BoolToStr(DoublePass)]);
  {$ENDIF}

  s := sReportPreparing;
  if DoublePass then
  begin
    {$IFDEF DebugLR}
    DebugLnEnter('DoPrepareReport FirstPass INIT');
    {$ENDIF}

    DisableDrawing := True;
    FinalPass := False;
    if not Assigned(FOnProgress) and FShowProgress then
    begin
      with frProgressForm do
      begin
        if Title = '' then
          Caption := s
        else
          Caption := s + ' - ' + Title;
          
        FirstCaption := sFirstPass;
        Label1.Caption := FirstCaption + '  1';
        OnBeforeModal := @BuildBeforeModal;
        Show_Modal(Self);
      end;
    end
    else BuildBeforeModal(nil);
    {$IFDEF DebugLR}
    DebugLnExit('DoPrepareReport FirstPass DONE');
    {$ENDIF}
    {$IFDEF DebugLR}
    DebugLnExit('DoPrepareReport EXIT: FirstPass');
    {$ENDIF}
    Exit;
  end;
  
  if not Assigned(FOnProgress) and FShowProgress then
  begin
    {$IFDEF DebugLR}
    DebugLnEnter('DoPrepareReport SecondPass INIT');
    {$ENDIF}

    with frProgressForm do
    begin
      {$IFDEF DebugLR}
      DebugLn('1');
      {$ENDIF}
      if Title = '' then
        Caption := s
      else
        Caption := s + ' - ' + Title;
      FirstCaption := sPagePreparing;
      Label1.Caption := FirstCaption + '  1';
      OnBeforeModal:=@BuildBeforeModal;
      {$IFDEF DebugLR}
      DebugLn('2');
      {$ENDIF}
      if Visible then
      begin
        {$IFDEF DebugLR}
        DebugLn('3');
        {$ENDIF}
        if not FirstPassTerminated then
           DoublePass := True;
           
        BuildBeforeModal(nil);
        {$IFDEF DebugLR}
        DebugLn('4');
        {$ENDIF}
      end
      else
      begin
        {$IFDEF DebugLR}
        DebugLn('5');
        {$ENDIF}
        SavedAllPages := 0;
        if Show_Modal(Self) = mrCancel then
          Result := False;
        {$IFDEF DebugLR}
        DebugLn('6');
        {$ENDIF}
      end;
      
      {$IFDEF DebugLR}
      DebugLnExit('DoPrepareReport SecondPass DONE');
      {$ENDIF}
    end;
  end
  else BuildBeforeModal(nil);
  Terminated := False;
  {$IFDEF DebugLR}
  DebugLnExit('DoPrepareReport DONE');
  {$ENDIF}
end;

var
  ExportStream: TFileStream;

procedure TfrReport.ExportBeforeModal(Sender: TObject);
var
  i: Integer;
begin
  Application.ProcessMessages;
  for i := 0 to EMFPages.Count - 1 do
  begin
    FCurrentFilter.OnBeginPage;
    EMFPages.ExportData(i);
    InternalOnProgress(i + 1);
    Application.ProcessMessages;
    FCurrentFilter.OnEndPage;
  end;
  FCurrentFilter.OnEndDoc;
  if frProgressForm<>nil then
    frProgressForm.ModalResult := mrOk;
end;

function TfrReport.ExportTo(FilterClass: TfrExportFilterClass; aFileName: String
  ): Boolean;
begin

  if (aFileName='') and (fDefExportFileName<>'') then
    aFileName := fDefExportFileName;

  if Trim(aFilename) = '' then
    raise Exception.create(sNoValidExportFilenameWasSupplied);

  ExportStream := TFileStream.Create(aFileName, fmCreate);
  result := ExportTo(FilterClass, exportStream, true);
  if result then
  begin
    fDefExportFileName := aFileName;
  end;

end;

// Export the report to exportStream using the FilterClass filter
// if exportStream is TFileStream, freeStream should be true because when
// Filter.AfterExport is called, the stream might not be yet written to disk
// this decision, however, is left to the user of this routine.
function TfrReport.ExportTo(FilterClass: TfrExportFilterClass;
  exportStream: TStream; freeStream: boolean): boolean;
var
  s: String;
  i: Integer;
begin
  // try to find a export filter from registered list
  if (FilterClass=nil) and (fDefExportFilterClass<>'') then
  begin
    for i:=0 to ExportFilters.Count - 1 do
      if (ExportFilters[i].FClassRef.ClassName=fDefExportFilterClass) then
      begin
        FilterClass := ExportFilters[i].FClassRef;
        break;
      end;
  end;

  if FilterClass=nil then
    raise Exception.Create(sNoValidFilterClassWasSupplied);

  FCurrentFilter := FilterClass.Create(exportStream);
  try

    CurReport := Self;
    MasterReport := Self;

    FCurrentFilter.OnSetup:=CurReport.OnExportFilterSetup;

    if FCurrentFilter.Setup then
    begin
      FCurrentFilter.OnBeginDoc;

      SavedAllPages := EMFPages.Count;

      if FCurrentFilter.UseProgressbar then
      with frProgressForm do
      begin
        s := sReportPreparing;
        if Title = '' then
          Caption := s
        else
          Caption := s + ' - ' + Title;
        FirstCaption := sPagePreparing;
        Label1.Caption := FirstCaption + '  1';
        OnBeforeModal := @ExportBeforeModal;
        Show_Modal(Self);
      end else
        ExportBeforeModal(nil);

      fDefExportFilterClass := FCurrentFilter.ClassName;
      Result:=true;
    end
    else
      Result:=false;

    FCurrentFilter.Stream := nil;

    if freeStream then
    begin
      //it is necessary to destroy the file stream before calling FCurrentFilter.AfterExport
      //to ensure the exported file is properly written to the file system
      exportStream.free;
    end;

    if Result then
      FCurrentFilter.AfterExport;

  finally
    if result then
    begin
      fDefExportFilterClass := FCurrentFilter.ClassName;
    end;
    FreeAndNil(FCurrentFilter);
  end;

end;

procedure TfrReport.FillQueryParams;
var
  i, j: Integer;
  t: TfrView;
  procedure PrepareDS(ds: TComponent);
  begin
    if ds is TfrDBDataSet then
      frDataManager.PrepareDataSet(TfrDBDataSet(ds).GetDataSet);
  end;
begin
  if frDataManager = nil then Exit;
  frDataManager.BeforePreparing;
  PrepareDS(DataSet);
  for i := 0 to Pages.Count - 1 do
    for j := 0 to Pages[i].Objects.Count-1 do
    begin
      t :=TfrView(Pages[i].Objects[j]);
      if t is TfrBandView then
        PrepareDS(frFindComponent(CurReport.Owner, TfrBandView(t).DataSet));
    end;
  frDataManager.AfterPreparing;
end;

procedure TfrReport.DoBuildReport;
var
  i  : Integer;
  b  : Boolean;
  BM : Pointer;
begin
  {$IFDEF DebugLR}
  DebugLnEnter('TfrReport.DoBuildReport INIT');
  {$ENDIF}
  HookList.Clear;
  CanRebuild := True;
  DocMode := dmPrinting;
  CurReport := Self;
  Values.Items.Sorted := True;
  frParser.OnGetValue := @GetVariableValue;
  frParser.OnFunction := @OnGetParsFunction;
  ErrorFlag := False;
  b := (Dataset <> nil) and (ReportType = rtMultiple);
  if b then
  begin
    BM:=DataSet.GetBookMark;
    DataSet.DisableControls;
    Dataset.Init;
    Dataset.First;
  end;
  try
    if (DoublePass and not FinalPass) or (not DoublePass) then
    begin
      ExecScript;

      for i := 0 to Pages.Count - 1 do
        Pages[i].Skip := False;

      for i := 0 to Pages.Count - 1 do
      begin
        if Pages[i] is TfrPageDialog then
        begin
          Pages[i].InitReport;
          if Terminated then
          begin
            FinalPass:=true;
            break;
          end;
        end;
      end;
    end;

    if not Terminated then
    begin
      for i := 0 to Pages.Count - 1 do
        if Pages[i] is TfrPageReport then
            Pages[i].InitReport;

      PrepareDataSets;
      for i := 0 to Pages.Count - 1 do
        if Pages[i] is TfrPageReport then
            Pages[i].PrepareObjects;

      repeat
        {$IFDEF DebugLR}
        DebugLn('p1');
        {$ENDIF}
        InternalOnProgress(PageNo + 1);
        {$IFDEF DebugLR}
        DebugLn('p2');
        {$ENDIF}

        for i := 0 to Pages.Count - 1 do
        begin
          if Pages[i] is TfrPageReport then
          begin
            //FCurPage := Pages[i];
            CurPage := Pages[i];
            if CurPage.Skip or (not CurPage.Visible) then
              Continue;
            CurPage.Mode := pmNormal;
            if Assigned(FOnManualBuild) then
              FOnManualBuild(CurPage)
            else
              CurPage.FormPage;

          {$IFDEF DebugLR}
          debugLn('p3');
          {$ENDIF}

            AppendPage := False;
            if ((i = Pages.Count - 1) and CompositeMode and (not b or Dataset.Eof)) or
               ((i <> Pages.Count - 1) and Pages[i + 1].PrintToPrevPage) then
            begin
              Dec(PageNo);
              AppendPage := True;
            end;
            if not AppendPage then
            begin
              PageNo := MasterReport.EMFPages.Count;
              InternalOnProgress(PageNo);
            end;
            if MasterReport.Terminated then
              Break;
          end;
        end;
        {$IFDEF DebugLR}
        DebugLn('p4');
        {$ENDIF}

        InternalOnProgress(PageNo);
        if b then
          Dataset.Next;
      until MasterReport.Terminated or not b or Dataset.Eof;

      for i := 0 to Pages.Count - 1 do
        Pages[i].DoneReport;

    end;
  finally
    if b then
    begin
      Dataset.Exit;
      DataSet.GotoBookMark(BM);
      DataSet.FreeBookMark(BM);
      DataSet.EnableControls;
    end;
  end;
  if (frDataManager <> nil) and FinalPass then
    frDataManager.AfterPreparing;
  Values.Items.Sorted := False;
  {$IFDEF DebugLR}
  DebugLnExit('TfrReport.DoBuildReport DONE');
  {$ENDIF}
end;

procedure TfrReport.ShowReport;
begin
  PrepareReport;
  if ErrorFlag then
  begin
    MessageDlg(ErrorStr,mtError,[mbOk],0);
    EMFPages.Clear;
  end
  else
    ShowPreparedReport;
end;

procedure TfrReport.ShowPreparedReport;
var
  s: String;
  p: TfrPreviewForm;
begin
  {$IFDEF DebugLR}
  DebugLnEnter('TfrReport.ShowPreparedReport INIT');
  {$ENDIF}
  CurReport := Self;
  MasterReport := Self;
  DocMode := dmPrinting;
  if EMFPages.Count = 0 then Exit;
  s := sPreview;
  if Title <> '' then
    s := s + ' - ' + Title;
    
  if not (csDesigning in ComponentState) and Assigned(Preview) then
  begin
    Preview.Connect(Self);
  end
  else
  begin
    p := TfrPreviewForm.Create(nil);
    p.BorderIcons:=p.BorderIcons - [biMinimize];
    {$IFDEF DebugLR}
    DebugLn('1 TfrPreviewForm.visible=%s',[BooLToStr(p.Visible)]);
    {$ENDIF}
    p.Caption := s;
    {$IFDEF DebugLR}
    DebugLn('2 TfrPreviewForm.visible=%s',[BooLToStr(p.Visible)]);
    {$ENDIF}
    if ExportFilename<>'' then
    begin
      p.SaveDialog.InitialDir := ExtractFilePath(ExportFileName);
      p.SaveDialog.FileName := ExportFilename;
    end;
    if Assigned( OnBeforePreview ) then
      OnBeforePreview( p );
    p.Show_Modal(Self);
  end;
  {$IFDEF DebugLR}
  DebugLnExit('TfrReport.ShowPreparedReport DONE');
  {$ENDIF}
end;

procedure TfrReport.PrintBeforeModal(Sender: TObject);
begin
  DoPrintReport(FPageNumbers, FCopies);
  frProgressForm.ModalResult := mrOk;
end;

procedure TfrReport.PrintPreparedReport(const PageNumbers: String; Copies: Integer);
var
  s: String;
begin
  CurReport:=Self;
  MasterReport:=Self;
  s:=sReportPreparing;
  Terminated:=False;
  FPageNumbers:=PageNumbers;
  FCopies:=Copies;
  
  if not Assigned(FOnProgress) and FShowProgress then
  begin
    with frProgressForm do
    begin
      if Title = '' then
        Caption := s
      else
        Caption := s + ' - ' + Title;
        
      FirstCaption := sPagePrinting;
      Label1.Caption := FirstCaption;
      OnBeforeModal := @PrintBeforeModal;

      Show_Modal(Self);
    end
  end
  else PrintBeforeModal(nil);

  Terminated := False;
end;

procedure TfrReport.DoPrintReport(const PageNumbers: String; Copies: Integer);
var
  k, FCollateCopies: Integer;
  isFirstPage: Boolean;
  pgList: TStringList;
  printerTitle: string;

  procedure ParsePageNumbers;
  var
    i, j, n1, n2: Integer;
    s: String;
    IsRange: Boolean;
  begin
    s := PageNumbers;
    
    while Pos(' ', s) <> 0 do
      Delete(s, Pos(' ', s), 1);
    if s = '' then Exit;

    s := s + ',';
    i := 1; j := 1; n1 := 1;
    IsRange := False;
    while i <= Length(s) do
    begin
      if s[i] = ',' then
      begin
        n2 := StrToInt(Copy(s, j, i - j));
        j := i + 1;
        if IsRange then
        begin
          while n1 <= n2 do
          begin
            pgList.Add(IntToStr(n1));
            Inc(n1);
          end;
        end
        else
          pgList.Add(IntToStr(n2));
          
        IsRange := False;
      end
      else if s[i] = '-' then
           begin
             IsRange := True;
             n1 := StrToInt(Copy(s, j, i - j));
             j := i + 1;
           end;
           
      Inc(i);
    end;
  end;

  procedure PrintPage(n: Integer);
  begin
    {$ifdef DebugLR}
    DebugLnEnter('PrintPage: %d INIT',[n]);
    {$endif}
    with Printer, EMFPages[n]^ do
    begin
      if not Prn.IsEqual(pgSize, pgWidth, pgHeight, pgOr) then
      begin
        EndDoc;
        {$ifdef DebugLR}
        DebugLn('Page %d done ',[n]);
        {$endif}
        Title := Format('%s page %d',[printerTitle, n]);
        Prn.SetPrinterInfo(pgSize, pgWidth, pgHeight, pgOr);
        BeginDoc;
      end
      else if not isFirstPage then
             NewPage;
             
      Prn.FillPrnInfo(PrnInfo);
      Visible := True;

      with PrnInfo do
      begin
        if pgMargins then
          EMFPages.Draw(n, Printer.Canvas, Rect(-POfx, -POfy, PPgw - POfx, PPgh - POfy))
        else
          EMFPages.Draw(n, Printer.Canvas, Rect(0, 0, PPw, PPh));
      end;
      
      Visible := False;
      EMFPages.Draw(n, Printer.Canvas, Rect(0, 0, 0, 0));
    end;
    InternalOnProgress(n + 1);
    Application.ProcessMessages;
    isFirstPage := False;
    {$ifdef DebugLR}
    DebugLnExit('PrintPage: DONE',[]);
    {$endif}
  end;
  {$IFDEF DebugLR}
  procedure DebugPrnInfo(msg: string);
  var
    k: integer;
  begin
    DebugLn('--------------------------------------------------');
    DebugLn(Msg);
    for k:=0 to EMFPages.Count-1 do begin
      DebugLn('EMFPage ',dbgs(k));
      with EmfPages[k]^.PrnInfo do begin
        DebugLn(Format('  Ppgw=%d PPgh=%d Pgw=%d Pgh=%d',[PPgw,PPgh,Pgw,Pgh]));
        DebugLn(Format('  Pofx=%d POfy=%d Ofx=%d Ofy=%d',[POfx,POfy,Ofx,Ofy]));
        DebugLn(Format('   Ppw=%d  Pph=%d  Pw=%d  Ph=%d',[Ppw,Pph,Pw,Ph]));
      end;
    end;
  end;
  {$ENDIF}

  procedure InternalPrintEMFPage;
  var
    i, j:integer;
  begin
    for i := 0 to EMFPages.Count - 1 do
    begin
      if (pgList.Count = 0) or (pgList.IndexOf(IntToStr(i + 1)) <> -1) then
      begin
        for j := 0 to Copies - 1 do
        begin
          PrintPage(i);

          if Terminated then
          begin
            Printer.Abort;
            pgList.Free;
            Exit;
          end;
        end;
      end;
    end;
  end;

begin
  {$ifdef DebugLR}
  DebugLnEnter('TfrReport.DoPrintReport: INIT ',[]);
  DebugPrnInfo('PageSizes');
  {$endif}
  if Prn.UseVirtualPrinter then
    ChangePrinter(Prn.PrinterIndex, Printer.PrinterIndex);

  if Assigned(FOnBeforePrint) then
    OnBeforePrint(Self);

  Prn.Printer := Printer;
  pgList := TStringList.Create;

  ParsePageNumbers;

  if Copies <= 0 then
    Copies := 1;

  FCollateCopies:=Copies;

  with EMFPages[0]^ do
  begin
    Prn.SetPrinterInfo(pgSize, pgWidth, pgHeight, pgOr);
    Prn.FillPrnInfo(PrnInfo);
  end;
  if Title <> '' then
    printerTitle:=Format('%s',[Title])
  else
    printerTitle:=Format('LazReport : %s',[sUntitled]);
  Printer.Title := printerTitle;

  Printer.BeginDoc;
  isFirstPage:= True;

  if FDefaultCollate then
  begin
    Copies:=1;
    for k:=1 to FCollateCopies do
      InternalPrintEMFPage;
  end
  else
    InternalPrintEMFPage;

  Printer.EndDoc;
  pgList.Free;

  if Assigned(FOnAfterPrint) then
    OnAfterPrint(Self);

  {$ifdef DebugLR}
  DebugLnExit('TfrReport.DoPrintReport: DONE',[]);
  {$endif}
end;

procedure TfrReport.SetComments(const AValue: TStringList);
begin
  FComments.Assign(AValue);
end;

// printer manipulation methods

procedure TfrReport.SetPrinterTo(const PrnName: String);
begin
  {$ifdef dbgPrinter}
  DebugLn;
  DebugLnENTER('TfrReport.SetPrinterTo PrnName="%s" PrnExist?=%s CurPrinter=%s',
    [prnName, dbgs(Prn.Printers.IndexOf(PrnName)>=0), prn.Printer.PrinterName]);
  DebugLn(['PrintToDefault=',PrintToDefault,' prnIndex=',prn.PrinterIndex,
    ' PrinterIndex=',Prn.Printer.PrinterIndex]);
  {$endif}
  if not PrintToDefault then
  begin
    prn.DocumentUnits := puPoints;
    if Prn.Printers.IndexOf(PrnName) <> -1 then
      Prn.PrinterIndex := Prn.Printers.IndexOf(PrnName)
    else
      if Prn.Printers.Count>0 then
        Prn.PrinterIndex := 0; // either the system default or
                               // own virtual default printer
  end else
    Prn.DocumentUnits := puTenthsMM;
  {$ifdef dbgPrinter}
  DebugLnExit('TfrReport.SetPrinterTo DONE CurPrinter="%s" UseVirtualPrinter=%s',
    [Prn.Printer.PrinterName, dbgs(Prn.UseVirtualPrinter)]);
  {$endif}
end;

procedure TfrReport.SetReportOptions(AValue: TfrReportOptions);
begin
  if FReportOptions=AValue then Exit;
  FReportOptions:=AValue;

  if Assigned(frProgressForm) then
    frProgressForm.Button1.Enabled:=not (roDisableCancelBuild in FReportOptions);
end;

procedure TfrReport.SetScript(AValue: TfrScriptStrings);
begin
  fScript.Assign(AValue);
end;

function TfrReport.ChangePrinter(OldIndex, NewIndex: Integer): Boolean;

  procedure ChangePages;
  var
    i: Integer;
  begin
    for i := 0 to Pages.Count - 1 do
    begin
      if Pages[i] is TfrPageReport then
        Pages[i].ChangePaper(Pages[i].pgSize, Pages[i].Width, Pages[i].Height, Pages[i].Orientation);
    end;
  end;
  
begin
  {$ifdef dbgPrinter}
  DebugLn;
  DebugLnEnter('TfrReport.ChangePrinter INIT CurIndex=%d OldIndex=%d NewIndex=%d',
    [Prn.PrinterIndex,OldIndex,NewIndex]);
  DebugLn('CurPrinter=%s NewPrinter=%s',[prn.Printer.PrinterName, prn.Printer.Printers[NewIndex]]);
  {$endif}
  Result := True;
  try
    Prn.PrinterIndex := NewIndex;
    Prn.PaperSize := -1;
    ChangePages;
  except
    on E:Exception do
    begin
      {$ifdef dbgPrinter}DebugLn('Change printer error: %s',[E.Message]);{$endif}
      MessageDlg(sPrinterError,mtError,[mbOk],0);
      Prn.PrinterIndex := OldIndex;
      ChangePages;
      Result := False;
    end;
  end;
  {$ifdef dbgPrinter}
  DebugLnExit('TfrReport.ChangePrinter DONE Printer=%s', [Prn.Printer.PrinterName]);
  {$endif}
end;

procedure TfrReport.EditPreparedReport(PageIndex: Integer);
var
  p: PfrPageInfo;
  Stream: TMemoryStream;
  Designer: TfrReportDesigner;
  DesName: String;
begin
  if frDesigner = nil then Exit;
  Screen.Cursor := crHourGlass;
  Designer := frDesigner;
  DesName := Designer.Name;
  Designer.Name := DesName + '__';
  Designer.Page := nil;
  frDesigner := TfrReportDesigner(frDesigner.ClassType.NewInstance);
  frDesigner.Create(nil){%H-};
  frDesigner.PreparedReportEditor:=true;
  Stream := TMemoryStream.Create;
  SaveToXMLStream(Stream); //**!
  Pages.Clear;
  EMFPages.ObjectsToPage(PageIndex);
  p := EMFPages[PageIndex];
  Pages.FPages.Add(p^.Page);
  CurReport := Self;
  Screen.Cursor := crDefault;
  try
    frDesigner.ShowModal;
    if frDesigner.Modified then
      if MessageDlg(sSaveChanges+' ?',mtConfirmation,[mbYes,mbNo],0)=mrYes then
        EMFPages.PageToObjects(PageIndex);
  finally
    Pages.FPages.Clear;
    Stream.Position := 0;
    LoadFromXMLStream(Stream); ///
    Stream.Free;
    frDesigner.Free;
    frDesigner := Designer;
    frDesigner.Name := DesName;
    if Pages.Count>0 then
    begin
     frDesigner.Page := Pages[0];
     frDesigner.RedrawPage;
    end
    else
      frDesigner.Page := nil;
  end;
end;


// miscellaneous methods
procedure TfrReport.PrepareDataSets;
var
  i: Integer;
begin
  with Values do
  for i := 0 to Items.Count - 1 do
    with Objects[i] do
    if Typ = vtDBField then
      DSet := frGetDataSet(DataSet);
end;

procedure TfrReport.SetVars(Value: TStrings);
begin
  FVars.Assign(Value);
end;

procedure TfrReport.ClearAttribs;
begin
//  FDefaultTitle:='';
  FTitle:='';
  FSubject:='';
  FKeyWords:='';
  FComments.Clear;

  ReportAutor := '';
  ReportVersionMajor := '';
  ReportVersionMinor := '';
  ReportVersionRelease := '';
  ReportVersionBuild := '';
  ReportCreateDate := Now;
  ReportLastChange := Now;
end;

function TfrReport.FindObjectByName(AName: string): TfrObject;
var
  APgName:string;
  Pg:TfrPage;
begin
  Result:=nil;
  if (Pos('.', AName)>0) then
  begin
    APgName:=Copy2SymbDel(AName, '.');
    Pg:=FPages.PageByName(APgName);
    if Assigned(Pg) then
      Result:=Pg.FindObject(AName);
  end
  else
    Result:=FindObject(AName);
end;

procedure TfrReport.ExecScript;
var
  CmdList, ErrorList:TStringList;
begin
  if DocMode = dmPrinting then
  begin
    CmdList:=TStringList.Create;
    ErrorList:=TStringList.Create;
    try
      CurView := nil;
      CurPage := nil;
      frInterpretator.PrepareScript(Script, CmdList, ErrorList);
      frInterpretator.DoScript(CmdList);
    finally
      FreeAndNil(CmdList);
      FreeAndNil(ErrorList);
    end;
  end;
end;

procedure TfrReport.CheckFileExists(FName: string);
begin
  if not FileExistsUTF8(FName) then
    raise ELazReportException.CreateFmt('%s: %s (%s)',
      [sReportLoadingError, sFileNotFound, FName]);
end;

function TfrReport.DoObjectClick(AObj: TfrView): boolean;
begin
  Result:=false;
  if AObj is TfrMemoView then
    TfrMemoView(AObj).DoOnClick;

  Result:=Assigned(OnObjectClick);
  if Assigned(OnObjectClick) then
    OnObjectClick(AObj);
end;

procedure TfrReport.DoBeginBand(Band: TfrBand);
begin
  if Assigned(FOnBeginBand) then
    FOnBeginBand(Band);
end;

procedure TfrReport.DoBeginColumn(Band: TfrBand);
begin
  if Assigned(FOnBeginColumn) then
    OnBeginColumn(Band);
end;

procedure TfrReport.DoBeginDoc;
begin
  if Assigned(FOnBeginDoc) then
    FOnBeginDoc;
end;

procedure TfrReport.DoBeginPage(pgNo: Integer);
begin
  if Assigned(FOnBeginPage) then
    FOnBeginPage(pgNo);
end;

procedure TfrReport.DoEndBand(Band: TfrBand);
begin
  if Assigned(FOnEndBand) then
    FOnEndBand(Band);
end;

procedure TfrReport.DoEndDoc;
begin
  if Assigned(FOnEndDoc) then
    FOnEndDoc;
end;

procedure TfrReport.DoEndPage(pgNo: Integer);
begin
  if Assigned(FOnEndPage) then
    FOnEndPage(pgNo);
end;

procedure TfrReport.DoEnterRect(Memo: TStringList; View: TfrView);
begin
  if Assigned(FOnEnterRect) then
    FOnEnterRect(Memo, View);
end;

procedure TfrReport.DoGetValue(const ParName: String; var ParValue: Variant);
begin
  if Assigned(FOnGetValue) then
    FOnGetValue(ParName, ParValue);
end;

procedure TfrReport.DoPrintColumn(ColNo: Integer; var Width: Integer);
begin
  if Assigned(FOnPrintColumn) then
    FOnPrintColumn(ColNo, Width);
end;

procedure TfrReport.DoUserFunction(const AName: String; p1, p2, p3: Variant;
  var Val: Variant);
begin
  if Assigned(FOnFunction) then
    FOnFunction(AName, p1, p2, p3, Val);
end;

procedure TfrReport.Loaded;
var
  st: TStringStream;
begin
  inherited Loaded;
  if FXMLReport<>'' then
  begin
    {$IF FPC_FULLVERSION >= 30101}
    st := TStringStream.CreateRaw(FXMLReport);
    {$ELSE}
    st := TStringStream.Create(FXMLReport);
    {$ENDIF}
    LoadFromXMLStream(st);
    st.free;
    FXMLReport := '';
  end;
  if assigned(FDFMStream) then
  begin
    LoadFromStream(FDFMStream);
    FreeAndNil(FDFMStream);
    FStoreInForm := true;
    FStoreInDFM := false;
  end;
end;

procedure TfrReport.GetVarList(CatNo: Integer; List: TStrings);
var
  i, n: Integer;
  s: String;
begin
  List.Clear;
  i := 0; n := 0;
  if FVars.Count > 0 then
    repeat
      s := FVars[i];
      if Length(s) > 0 then
        if s[1] <> ' ' then Inc(n);
      Inc(i);
    until n > CatNo;
  while i < FVars.Count do
  begin
    s := FVars[i];
    if (s <> '') and (s[1] = ' ') then
      List.Add(Copy(s, 2, Length(s) - 1)) else
      break;
    Inc(i);
  end;
end;

procedure TfrReport.GetIntrpValue(const AName: String; var AValue: Variant);
var
  t:  TfrObject;
  PropName: String;
  PropInfo:PPropInfo;
  St:string;
  i:integer;
  FColorVal:TColor;
begin

  t := nil;

  if frVariables.IndexOf(AName) <> -1 then
  begin
    AValue := frVariables[AName];
    exit;
  end;

  if AName = 'FREESPACE' then
  begin
    AValue:=IntToStr(CurPage.CurBottomY-CurPage.CurY);
    exit;
  end;

  PropInfo:=FindObjectProps(AName, t, PropName, i);
  if Assigned(t) then
  begin
       //Retreive property informations
    if Assigned(PropInfo) then
    begin
      {$IFDEF DebugLR}
      DebugLn('TInterpretator.GetValue(',Name,') Prop=',PropName, ' Kind=',InttoStr(Ord(PropInfo^.PropType^.Kind)));
      {$ENDIF}
      case PropInfo^.PropType^.Kind of
        tkChar,tkAString,tkWString,
        tkSString,tkLString :
          begin
            St:=GetStrProp(t, PropInfo);
            {$IFDEF DebugLR}
            DebugLn('St=',St);
            {$ENDIF}
            AValue:=St;
          end;
        tkBool,tkInt64,tkQWord,
        tkInteger                   : AValue:=GetOrdProp(t, PropInfo);
        tkSet                       : begin
                                            St:=GetSetProp(t, PropInfo, false);
                                            {$IFDEF DebugLR}
                                            DebugLn('St=',St);
                                            {$ENDIF}
                                            AValue:=St;
                                          end;
        tkFloat                     : AValue:=GetFloatProp(t,PropInfo);
        tkEnumeration               : begin
                                            St:=GetEnumProp(t,PropInfo);
                                            {$IFDEF DebugLR}
                                            DebugLn('St=',St);
                                            {$ENDIF}
                                            AValue:=St;
                                          end;
      end;
    end
    else
    if not (t is TfrBandView) and (i>=0) then
    begin
      {$IFDEF DebugLR}
      DbgOut('A CustomField was found ', PropName);
      if i=0 then
        DbgOut(', t.memo.text=',DbgStr(t.Memo.Text));
      DebugLn;
      {$ENDIF}
      case i of
        0: AValue := t.GetText; //t.Memo.Text;
        1: AValue := TfrMemoView(t).Font.Name;
        2: AValue := TfrMemoView(t).Font.Size;
        3: AValue := frGetFontStyle(TfrMemoView(t).Font.Style);
        4: AValue := TfrMemoView(t).Font.Color;
        5: AValue := TfrMemoView(t).Adjust;
      end;
    end;

    {$IFDEF DebugLR}
    DebugLn('TInterpretator.GetValue(',Name,') No Propinfo for Prop=',PropName,' Value=',dbgs(AValue));
    {$ENDIF}
  end
  else
  begin
    // it's not a property of t, try with known color names first
    if IdentToColor(AName, FColorVal) then
      AValue := FColorVal
    else
    if CompareText(AName, 'MROK') = 0 then //try std ModalResult values
      AValue := mrOk
    else
    if CompareText(AName, 'MRCANCEL') = 0 then //try std ModalResult values
      AValue := mrCancel
    else
    if (CompareText(AName, 'FINALPASS') = 0) and Assigned(CurReport) then
      AValue := CurReport.FinalPass
    else
    if (CompareText(AName, 'CURY') = 0) and Assigned(CurPage) then
      AValue := CurPage.CurY
    else
    if (CompareText(AName, 'PAGEHEIGHT') = 0) and Assigned(CurPage) then
      AValue := CurPage.Height
    else
    if (CompareText(AName, 'PAGEWIDTH') = 0) and Assigned(CurPage) then
      AValue := CurPage.Width;
  end;
end;

procedure TfrReport.GetCategoryList(List: TStrings);
var
  i: Integer;
  s: String;
begin
  List.Clear;
  for i := 0 to FVars.Count - 1 do
  begin
    s := FVars[i];
    if (Length(s)>0) and (s[1]<>' ') then
       List.Add(s);
  end;
end;

function TfrReport.FindVariable(Variable: String): Integer;
var
  i: Integer;
begin
  Result := -1;
  Variable := ' ' + Variable;
  for i := 0 to FVars.Count - 1 do
    if Variable = FVars[i] then
    begin
      Result := i;
      break;
    end;
end;

function TfrReport.FindObject(const aName: String): TfrObject;
var
  i: Integer;
begin
  Result := nil;
  for i := 0 to Pages.Count - 1 do
  begin
    Result:=Pages[i].FindObject(aName);
    if Assigned(Result) then
      Break;
  end;
end;


{----------------------------------------------------------------------------}
constructor TfrCompositeReport.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  Reports := TFpList.Create;
end;

destructor TfrCompositeReport.Destroy;
begin
  Reports.Free;
  inherited Destroy;
end;

procedure TfrCompositeReport.DoBuildReport;
var
  i: Integer;
  Doc: TfrReport;
  ParamOk: Boolean;
begin
  CanRebuild := True;
  PageNo := 0;
  for i := 0 to Reports.Count - 1 do
  begin
    Doc := TfrReport(Reports[i]);
    CompositeMode := False;
    if i <> Reports.Count - 1 then
      if (TfrReport(Reports[i + 1]).Pages.Count > 0) and
        TfrReport(Reports[i + 1]).Pages[0].PrintToPrevPage then
        CompositeMode := True;
    CurReport := Doc;
    if FirstTime then
      Doc.DoBeginDoc;
    ParamOk := True;
    if (frDataManager <> nil) and FirstTime then
    begin
      Doc.FillQueryParams;
      ParamOk := frDataManager.ShowParamsDialog;
    end;
    if ParamOk then
      Doc.DoBuildReport;
    if (frDataManager <> nil) and FinalPass then
      frDataManager.AfterParamsDialog;
    if FinalPass then
      Doc.DoEndDoc;
    AppendPage := CompositeMode;
    CompositeMode := False;
    if Terminated then break;
  end;
end;


{----------------------------------------------------------------------------}
procedure TfrObjEditorForm.ShowEditor(t: TfrView);
begin
// abstract method
end;


{----------------------------------------------------------------------------}
constructor TfrExportFilter.Create(AStream: TStream);
begin
  inherited Create;
  Stream := AStream;
  Lines := TFpList.Create;
  FBandTypes := [btReportTitle..btNone];
end;

destructor TfrExportFilter.Destroy;
begin
  ClearLines;
  Lines.Free;
  inherited Destroy;
end;

procedure TfrExportFilter.ClearLines;
var
  i: Integer;
  p, p1: PfrTextRec;
begin
  for i := 0 to Lines.Count - 1 do
  begin
    p := PfrTextRec(Lines[i]);
    while p <> nil do
    begin
      p1 := p;
      p := p^.Next;
      SetLength(p1^.Text, 0);
      FreeMem(p1, SizeOf(TfrTextRec));
    end;
  end;
  Lines.Clear;
  FLineIndex := -1;
end;

function TfrExportFilter.Setup: boolean;
begin
  Result:=true;
  if assigned(FOnSetup) then
    FOnSetup(Self);
end;

function TfrExportFilter.AddData(x, y: Integer; view: TfrView):pointer;
var
  p: PfrTextRec;
  s: string;
begin
  result := nil;

  if (View = nil) or not (View.ParentBandType in BandTypes) then
    exit;

  if View.Flags and flStartRecord<>0 then
    Inc(FLineIndex);

  if CheckView(View) then
  begin
    s := GetViewText(View);
    p := nil;
    NewRec(View, s, p);
    AddRec(FLineIndex, p);
    result := p;
  end;
end;

procedure TfrExportFilter.NewRec(View: TfrView; const AText: string;
  var P: Pointer);
begin
  GetMem(p, SizeOf(TfrTextRec));
  FillChar(p^, SizeOf(TfrTextRec), 0);
  with PfrTextRec(p)^ do
  begin
    Next  := nil;
    X     := View.X;
    W     := round(View.Width);
    Typ   := View.Typ;
    Text  := AText;
    FillColor   := View.FillColor;
    Borders     := View.Frames;
    BorderColor := View.FrameColor;
    BorderStyle := View.FrameStyle;
    BorderWidth := Round(View.FrameWidth);
    if View is TfrMemoView then
      with View as TfrMemoView do
      begin
        FontName    := Font.Name;
        FontSize    := Font.Size;
        FontStyle   := frGetFontStyle(Font.Style);
        FontColor   := Font.Color;
        FontCharset := Font.Charset;
        Alignment   := Alignment;
      end;
  end;
end;

procedure TfrExportFilter.AddRec(ALineIndex: Integer; ARec: Pointer);
var
  p, p1, p2: PfrTextRec;
begin

  p := ARec;
  p1 := Lines[ALineIndex];
  if p1 = nil then
    Lines[ALineIndex] := TObject(p)
  else
  begin
    p2 := p1;
    while (p1 <> nil) and (p1^.X <= p^.X) do
    begin
      p2 := p1;
      p1 := p1^.Next;
    end;
    if p2 <> p1 then
    begin
      p2^.Next := p;
      p^.Next := p1;
    end
    else
    begin
      Lines[ALineIndex] := TObject(p);
      p^.Next := p1;
    end;
  end;

end;

function TfrExportFilter.GetviewText(View: TfrView): string;
var
  i: Integer;
begin
  result := '';
  for i:=0 to View.Memo.Count-1 do begin
    result := result + View.Memo[i];
    if i<>View.Memo.Count-1 then
      result := result + LineEnding;
  end;
end;

function TfrExportFilter.CheckView(View: TfrView): boolean;
begin
  result := true;
end;

procedure TfrExportFilter.AfterExport;
begin
  // abstract method
end;

procedure TfrExportFilter.OnBeginDoc;
begin
// abstract method
end;

procedure TfrExportFilter.OnEndDoc;
begin
// abstract method
end;

procedure TfrExportFilter.OnBeginPage;
begin
// abstract method
end;

procedure TfrExportFilter.OnEndPage;
begin
// abstract method
end;

procedure TfrExportFilter.OnData(x, y: Integer; View: TfrView);
begin
// abstract method
end;

procedure TfrExportFilter.OnText(x, y: Integer; const text: String; View: TfrView);
begin
// abstract method
end;

procedure TfrExportFilter.OnExported(x, y: Integer; View: TfrView);
begin
end;

function TfrFunctionLibrary.GetCount: integer;
begin
  result := List.Count + Extra.Count;
end;

function TfrFunctionLibrary.GetDescription(AIndex: Integer
  ): TfrFunctionDescription;
begin
  result := nil;
  if (AIndex>=0) and (AIndex<FunctionCount) then
  begin
    if AIndex<List.Count then
      result := TfrFunctionDescription(List.Objects[AIndex])
    else
      result := TfrFunctionDescription(Extra.Objects[AIndex-List.Count]);
  end;
end;

{----------------------------------------------------------------------------}
constructor TfrFunctionLibrary.Create;
begin
  inherited Create;
  List := TStringList.Create;
  Extra:= TStringList.Create;
  //List.Sorted := True;
end;

destructor TfrFunctionLibrary.Destroy;
  procedure FreeList(AList:TStringList);
  var
    i:integer;
  begin
    for i:=0 to AList.Count-1 do
      if Assigned(AList.Objects[i]) then
      begin
        AList.Objects[i].Free;
        AList.Objects[i]:=nil;
      end;
    AList.Free;
  end;

begin
  FreeList(List);
  FreeList(Extra);
  inherited Destroy;
end;

function TfrFunctionLibrary.OnFunction(const FName: String; p1, p2, p3: Variant;
  var val: Variant): Boolean;
var
  i: Integer;
begin
  Result := False;
//  if List.Find(FName, i) then
  I:=List.IndexOf(FName);
  if I>=0 then
  begin
    DoFunction(i, p1, p2, p3, val);
    Result := True;
  end;
end;

procedure TfrFunctionLibrary.UpdateDescriptions;
begin
end;

procedure TfrFunctionLibrary.Add(const funName: string; IsExtra:boolean=false);
begin
  if IsExtra then
    Extra.Add(funName)
  else
    List.Add(FunName);
end;

procedure TfrFunctionLibrary.AddFunctionDesc(const funName, funGroup,
  funDescription: string);
var
  i: Integer;

  procedure AddDesc(AList:TStringList);
  begin
    if not Assigned(AList.Objects[i]) then
      AList.Objects[i]:=TfrFunctionDescription.Create;
    TfrFunctionDescription(AList.Objects[i]).funName:=funName;
    TfrFunctionDescription(AList.Objects[i]).funGroup:=funGroup;
    TfrFunctionDescription(AList.Objects[i]).funDescription:=funDescription;
  end;

begin
  i:=List.IndexOf(funName);
  if i>=0 then
    AddDesc(List)
  else
  begin
    i := Extra.IndexOf(funName);
    if i>=0 then
      AddDesc(Extra);
  end;
end;


{----------------------------------------------------------------------------}
constructor TfrStdFunctionLibrary.Create;
begin
  inherited Create;
  Add('AVG');               {0}
  Add('COUNT');             {1}
  Add('DAYOF');             {2}
  Add('FORMATDATETIME');    {3}
  Add('FORMATFLOAT');       {4}
  Add('FORMATTEXT');        {5}
  Add('INPUT');             {6}
  Add('LENGTH');            {7}
  Add('LOWERCASE');         {8}
  Add('MAX');               {9}
  Add('MAXNUM');            {10}
  Add('MESSAGEBOX');        {11}
  Add('MIN');               {12}
  Add('MINNUM');            {13}
  Add('MONTHOF');           {14}
  Add('NAMECASE');          {15}
  Add('POS');               {16}
  Add('STRTODATE');         {17}
  Add('STRTOTIME');         {18}
  Add('SUM');               {19}
  Add('TRIM');              {20}
  Add('UPPERCASE');         {21}
  Add('YEAROF');            {22}
  // internal functions/operators
  Add('COPY', true);
  Add('STR', true);
  Add('INT', true);
  Add('ROUND', true);
  Add('FRAC', true);
  Add('MOD', true);

  Add('NEWPAGE', true);
  Add('NEWCOLUMN', true);
  Add('STOPREPORT', true);
  Add('SHOWBAND', true);
  Add('INC', true);
  Add('DEC', true);
  Add('IF', true);
end;

procedure TfrStdFunctionLibrary.UpdateDescriptions;
begin
  AddFunctionDesc('AVG', SAggregateCategory, SDescriptionAVG);
  AddFunctionDesc('COUNT', SAggregateCategory, SDescriptionCOUNT);
  AddFunctionDesc('MAX', SAggregateCategory, SDescriptionMAX);
  AddFunctionDesc('MIN', SAggregateCategory, SDescriptionMIN);
  AddFunctionDesc('SUM', SAggregateCategory, SDescriptionSUM);

  AddFunctionDesc('DAYOF', SDateTimeCategory, SDescriptionDAYOF);
  AddFunctionDesc('MONTHOF', SDateTimeCategory, SDescriptionMONTHOF);
  AddFunctionDesc('STRTODATE', SDateTimeCategory, SDescriptionSTRTODATE);
  AddFunctionDesc('STRTOTIME', SDateTimeCategory, SDescriptionSTRTOTIME);
  AddFunctionDesc('YEAROF', SDateTimeCategory, SDescriptionYEAROF);

  AddFunctionDesc('FORMATDATETIME', SStringCategory, SDescriptionFORMATDATETIME);
  AddFunctionDesc('FORMATFLOAT', SStringCategory, SDescriptionFORMATFLOAT);
  AddFunctionDesc('FORMATTEXT', SStringCategory, SDescriptionFORMATTEXT);
  AddFunctionDesc('LENGTH', SStringCategory, SDescriptionLENGTH);
  AddFunctionDesc('LOWERCASE', SStringCategory, SDescriptionLOWERCASE);
  AddFunctionDesc('NAMECASE', SStringCategory, SDescriptionNAMECASE);
  AddFunctionDesc('TRIM', SStringCategory, SDescriptionTRIM);
  AddFunctionDesc('UPPERCASE', SStringCategory, SDescriptionUPPERCASE);
  AddFunctionDesc('POS', SStringCategory, SDescriptionPOS);
  AddFunctionDesc('COPY', SStringCategory, SDescriptionCOPY);
  AddFunctionDesc('STR', SStringCategory, SDescriptionSTR);

  AddFunctionDesc('INPUT', SOtherCategory, SDescriptionINPUT);
  AddFunctionDesc('MESSAGEBOX', SOtherCategory, SDescriptionMESSAGEBOX);
  AddFunctionDesc('IF', SOtherCategory, SDescriptionIF);

  AddFunctionDesc('MAXNUM', SMathCategory, SDescriptionMAXNUM);
  AddFunctionDesc('MINNUM', SMathCategory, SDescriptionMINNUM);
  AddFunctionDesc('INT', SMathCategory, SDescriptionINT);
  AddFunctionDesc('ROUND', SMathCategory, SDescriptionROUND);
  AddFunctionDesc('FRAC', SMathCategory, SDescriptionFRAC);

  AddFunctionDesc('NEWPAGE', SInterpretator, SDescriptionNEWPAGE);
  AddFunctionDesc('NEWCOLUMN', SInterpretator, SDescriptionNEWCOLUMN);
  AddFunctionDesc('STOPREPORT', SInterpretator, SDescriptionSTOPREPORT);
  AddFunctionDesc('SHOWBAND', SInterpretator, SDescriptionSHOWBAND);
  AddFunctionDesc('INC', SInterpretator, SDescriptionINC);
  AddFunctionDesc('DEC', SInterpretator, SDescriptionDEC);
end;

procedure TfrStdFunctionLibrary.DoFunction(FNo: Integer; p1, p2, p3: Variant;
  var val: Variant);
var
  DataSet: TfrTDataSet;
  Field: TfrTField;
  Obj: TFrObject;
  s1, s2, VarName: String;
  min, max, avg, sum, count, d, v: Double;
  dk: (dkNone, dkSum, dkMin, dkMax, dkAvg, dkCount);
  vv, v2, v1: Variant;
  BM : TBookMark;
  {$IFDEF DebugLR}
  function FNoStr: string;
  begin
    if FNo<=List.Count then
      result := List[FNo]
    else
      result := '???';
  end;
  {$ENDIF}
begin
  {$IFDEF DebugLR}
  DebugLnEnter('TfrStdFunctionLibrary.DoFunction INIT FNo=%d (%s) p1=%s p2=%s p3=%s val=%s',[FNo,FNoStr,p1,p2,p3,val]);
  {$ENDIF}
  dk := dkNone;
  val := '0';
  case FNo of
    0: dk := dkAvg;                                           //Add('AVG');               {0}
    1: dk := dkCount;                                         //Add('COUNT');             {1}
    2: val := DayOf(frParser.Calc(p1));                       //Add('DAYOF');             {2}
    3: val := FormatDateTime(frParser.Calc(p1), frParser.Calc(p2), [fdoInterval]); //Add('FORMATDATETIME');    {3}
    4: val := FormatFloat(frParser.Calc(p1), lrVarToFloatDef(frParser.Calc(p2))); //Add('FORMATFLOAT');       {4}
    5: val := FormatMaskText(frParser.Calc(p1) + ';0; ', frParser.Calc(p2));  //Add('FORMATTEXT');        {5}
    6:begin                                                   //Add('INPUT');             {6}
        s1 := InputBox('', frParser.Calc(p1), frParser.Calc(p2));
        val := s1;
      end;
    7:val := UTF8Length(frParser.Calc(p1));                   //Add('LENGTH');            {7}
    8: val := UTF8LowerCase(frParser.Calc(p1));               //Add('LOWERCASE');         {8}
    9: dk := dkMax;                                           //Add('MAX');               {9}
   10:begin                                                   //Add('MAXNUM');            {10}
        v2 := frParser.Calc(p1);
        v1 := frParser.Calc(p2);
        if v2 > v1 then
          val := v2 else
          val := v1;
      end;
   11:val := Application.MessageBox(PChar(String(frParser.Calc(p1))), //Add('MESSAGEBOX');        {11}
          PChar(String(frParser.Calc(p2))), frParser.Calc(p3));
   12: dk := dkMin;                                           //Add('MIN');               {12}
   13:begin                                                   //Add('MINNUM');            {13}
        v2 := frParser.Calc(p1);
        v1 := frParser.Calc(p2);
        if v2 < v1 then
          val := v2 else
          val := v1;
      end;
   14: val := MonthOf(frParser.Calc(p1));                     //Add('MONTHOF');           {14}
   15:begin                                                   //Add('NAMECASE');          {15}
        s1 := UTF8LowerCase(frParser.Calc(p1));
        if Length(s1) > 0 then
          val := UTF8UpperCase(UTF8Copy(S1, 1, 1)) + UTF8Copy(s1, 2, UTF8Length(s1))
        else
          val := '';
      end;
   16:begin                                                   // Add('POS');               {16}
        S1:=frParser.Calc(p1);
        S2:=frParser.Calc(p2);
        val := UTF8Pos(S1, S2);
      end;
   17: val := StrToDate(frParser.Calc(p1));                   //Add('STRTODATE');         {17}
   18: val := StrToTime(frParser.Calc(p1));                   //Add('STRTOTIME');         {18}
   19: dk := dkSum;                                           //Add('SUM');               {19}
   20: begin                                                  //Add('TRIM');              {20}
         S1:=frParser.Calc(p1);
         val := Trim(S1);
       end;
   21: val := UTF8UpperCase(frParser.Calc(p1));               //Add('UPPERCASE');         {21}
   22: val := YearOf(frParser.Calc(p1));                      //Add('YEAROF');            {22}
  end;
  
  if dk <> dkNone then
  begin

    if dk = dkCount then
      DataSet := frGetDataSet(lrGetUnBrackedStr(p1))
    else
    begin
      // if bandname is provided if yes, don't try to use dataset/field
      Obj := curPage.FindObject(trim(P2));

      if (obj is TfrBandView) and
        (TfrBandView(Obj).BandType in [btMasterData,btDetailData,
          btSubDetailData,btCrossData])
      then
        DataSet := nil
      else begin
        Dataset := nil;
        frGetDataSetAndField(lrGetUnBrackedStr(p1), DataSet, Field);
      end;
    end;
      
    if (DataSet <> nil) and (Field <> nil) and AggrBand.Visible then
    begin
      min := 1e200; max := -1e200; sum := 0; count := 0; avg := 0;
      BM:=DataSet.GetBookMark;
      DataSet.DisableControls;
      try
        DataSet.First;
        while not DataSet.Eof do
        begin
          v := 0;
          if dk <> dkCount then
          begin
            if not Field.IsNull then
              v := Field.AsFloat
            else
              v := 0;
          end;

          if v > max then max := v;
          if v < min then min := v;
          sum := sum + v;
          count := count + 1;
          DataSet.Next;
        end;
      finally
        DataSet.GotoBookMark(BM);
        DataSet.FreeBookMark(BM);
        DataSet.EnableControls;
      end;
      
      if count > 0 then
        avg := sum / count;
      d := 0;
      case dk of
        dkSum: d := sum;
        dkMin: d := min;
        dkMax: d := max;
        dkAvg: d := avg;
        dkCount: d := count;
      end;
      val := d;
    end
    else if (CurBand.View<>nil) and ((DataSet = nil) or (Field = nil)) then
    begin
      {$IFDEF DebugLR}
      DebugLn('CurBand=%s CurBand.View=%s AggrBand=%s',
        [BandInfo(CurBand),dbgsName(CurBand.View),BandInfo(AggrBand)]);
      {$ENDIF}
      if dk <> dkCount then begin
        // p1 = field
        // p2 = data band
        // p3 = InvisibleToo
        s1 := trim(string(p2));
        if s1='' then
          s1 := CurBand.View.Name;
        s2 := Trim(string(p3))
      end
      else begin
        // p1 = data band
        // p2 = InvisibleToo
        s1 := Trim(string(p1));
        s2 := Trim(string(p2));
        if s2<>'1' then
          s2 := '0';
      end;
      // s1 = data band
      // s2 = '1' o '0' (1 means process invisible records too)

      if (AggrBand.Typ in [btPageFooter, btMasterFooter, btDetailFooter,
        btSubDetailFooter, btGroupFooter, btCrossFooter, btReportSummary]) and
         ((s2 = '1') or ((s2 <> '1') and CurBand.Visible)) then
      begin
        VarName := List[FNo] + StringReplace(p1, '=', '_', [rfReplaceAll]);
        if IsColumns then
          if AggrBand.Typ = btCrossFooter then
            VarName := VarName + '00' else
            VarName := VarName + IntToStr(CurPage.ColPos);
        {$ifdef DebugLR}
        dbgOut('VarName=', QuotedStr(VarName));
        {$endif}
        if not AggrBand.Visible and (AnsiCompareText(CurBand.View.Name, s1) = 0) then
        begin
          s1 := AggrBand.Values.Values[VarName];
          {$IFDEF DebugLR}
          dbgOut(' values[',QuotedStr(VarName),']=',QuotedStr(DecodeValue(s1)));
          {$ENDIF}
          if (s1='') or ((s1 <> '') and (s1[1] <> '1')) then
          begin
            s1 := Copy(s1, 2, 255);
            vv := 0;
            if dk <> dkCount then
              vv := frParser.Calc(p1);
            if  VarIsNull(vv) or (TVarData(vv).VType=varEmpty)  then
              vv := 0;
            {$IFDEF DebugLR}
            dbgOut(' Calc(',QuotedStr(p1),')=',varstr(vv));
            {$ENDIF}
            d := vv;
            if s1 = '' then
              if dk = dkMin then s1 := '1e200'
              else if dk = dkMax then s1 := '-1e200'
              else s1 := '0';
            v := StrToFloat(s1);
            case dk of
              dkAvg: v := v + d;
              dkCount: v := v + 1;
              dkMax: if v < d then v := d;
              dkMin: if v > d then v := d;
              dkSum: v := v + d;
            end;
            AggrBand.Values.Values[VarName] := '1' + FloatToStr(v);
            {$IFDEF DebugLR}
            dbgOut(' NewVal=',dbgs(v),' values[',Quotedstr(VarName),']=',DecodeValue(AggrBand.Values.Values[VarName]));
            {$ENDIF}
          end;
          {$ifdef DebugLR}
          DebugLn('');
          {$endif}
        end
        else if AggrBand.Visible then
        begin
          val := StrToFloatDef(Copy(AggrBand.Values.Values[VarName], 2, 255),0);
          if dk = dkAvg then
            val := val / AggrBand.Count;
          {$ifdef DebugLR}
          DebugLn('Value=%s',[Val]);
          {$endif}
        end;
      end;
    end;
  end;
  {$IFDEF DebugLR}
  DebugLnExit('TfrStdFunctionLibrary.DoFunction DONE val=%s',[val]);
  {$ENDIF}
end;

procedure TInterpretator.GetValue(const Name: String; var Value: Variant);
begin
  if Assigned(frParser.OnGetValue) then
    frParser.OnGetValue(Name, Value);
end;

procedure TInterpretator.SetValue(const Name: String; Value: Variant);
var
  t         : TfrObject;
  PropName  : String;
  PropInfo  : PPropInfo;
  S         : String;
  i         : Integer;
begin
  {$IFDEF DebugLR}
  DebugLn('TInterpretator.SetValue(',Name,',',Value,')');

  if VarIsNull(Value) or VarIsEmpty(Value) then
        DebugLn('Value=NULL');
  {$ENDIF}

  PropInfo:=FindObjectProps(Name, t, PropName, i);

  if Assigned(PropInfo) then
  begin
    S:=VarToStr(Value);
    {$IFDEF DebugLR}
    DebugLn('PropInfo for ',propName,' found, Setting Value=',S);
    {$ENDIF}

    Case PropInfo^.PropType^.Kind of
      tkChar,tkAString,tkWString,
      tkSString,tkLString         : SetStrProp(t,PropInfo,S);
      tkBool,tkInt64,tkQWord,
      tkInteger                   : begin
                                      if AnsiCompareText(PropInfo^.PropType^.Name,'TGraphicsColor')=0 then
                                        SetOrdProp(t,PropInfo,StringToColor(S))
                                      else
                                        SetOrdProp(t,PropInfo,Value)
                                    end;
      tkSet                       : SetSetProp(t,PropInfo,S);
      tkFloat                     : SetFloatProp(t,PropInfo, Value);
      tkEnumeration               : SetEnumProp(t,PropInfo, S);
    end;
  end
  else
  begin
    if Assigned(t) and not (t is TfrBandView) then
    begin
      // try with customized properties not included directly in t
      if i>=0 then begin
        {$IFDEF DebugLR}
        DbgOut('A CustomField was found ', PropName);
        if i=0 then
          DbgOut(', t.memo.text=',DbgStr(t.Memo.Text),' nuevo valor=',VarToStr(Value));
        DebugLn;
        {$ENDIF}
        case i of
          0: T.SetText(Value); //t.Memo.Text := Value;
          1: TfrMemoView(t).Font.Name := Value;
          2: TfrMemoView(t).Font.Size := Value;
          3: TfrMemoView(t).Font.Style := frSetFontStyle(Value);
          4: TfrMemoView(t).Font.Color := Value;
          5: TfrMemoView(t).Adjust := Value;
        end;
        exit;
      end;
    end;
    // not found, treat it as a variable
    {$IFDEF DebugLR}
    DebugLn('frVariables[',Name,'] := ',Value);
    {$ENDIF}

    if IsValidIdent(Name) then
      frVariables[Name] := Value
    else
      raise Exception.CreateFmt( sInvalidVariableName, [Name]);
  end;
end;

procedure TInterpretator.DoFunction(const name: String; p1, p2, p3: Variant;
  var val: Variant);
begin
  frParser.OnFunction(Name, p1, p2, p3, val);
end;


{----------------------------------------------------------------------------}
procedure TfrCompressor.Compress(StreamIn, StreamOut: TStream);
begin
// abstract method
end;

procedure TfrCompressor.DeCompress(StreamIn, StreamOut: TStream);
begin
// abstract method
end;

{----------------------------------------------------------------------------}



procedure DoInit;
begin
  RegisterClasses([TfrPageReport,TfrPageDialog]);
  
  frDesigner:=nil;
  
  SMemo := TStringList.Create;

  frRegisterFunctionLibrary(TfrStdFunctionLibrary);

  frParser := TfrParser.Create;
  frInterpretator := TInterpretator.Create;
  frVariables := TfrVariables.Create;
  frCompressor := TfrCompressor.Create;
  HookList := TFpList.Create;
end;

procedure DoExit;
var
  i: Integer;
begin
  FHyp.Free;
  SBmp.Free;
  TempBmp.Free;
  SMemo.Free;
  frProgressForm.Free;
  for i := 0 to frFunctionsCount - 1 do
    frFunctions[i].FunctionLibrary.Free;
  frParser.Free;
  frInterpretator.Free;
  frVariables.Free;
  frCompressor.Free;
  HookList.Free;
  if Assigned(FExportFilters) then
    FreeAndNil(FExportFilters);
end;

{ TfrObject }

procedure TfrObject.SetMemo(const AValue: TfrMemoStrings);
begin
  if fMemo=AValue then exit;
  fMemo.Assign(AValue);
end;

function TfrObject.GetHeight: Integer;
begin
  Result:=DY;
end;

procedure TfrObject.SetHeight(AValue: Integer);
begin
  DY:=AValue;
  if Assigned(frDesigner) then
    frDesigner.Invalidate;
end;

function TfrObject.GetWidth: Integer;
begin
  Result:=DX;
end;

function TfrObject.GetTop: Integer;
begin
  Result:=Y;
end;

function TfrObject.GetLeft: Integer;
begin
  Result:=X;
end;

procedure TfrObject.SetLeft(AValue: Integer);
begin
  X:=AValue;
  if Assigned(frDesigner) then
    frDesigner.Invalidate;
end;

procedure TfrObject.SetName(const AValue: string);
begin
  if fName=AValue then exit;

  if (frDesigner<>nil) and (CurReport<>nil) then
  begin
    if CurReport.FindObject(AValue)<>nil then
    begin
      MessageDlg(format(sDuplicatedObjectName,[AValue]),mtError,[mbOk],0);
      exit;
    end;
  end;

  fName:=AValue;
end;

procedure TfrObject.AfterLoad;
begin
  //
end;

procedure TfrObject.AfterCreate;
begin

end;

function TfrObject.ExecMetod(const AName: String; p1, p2, p3: Variant;
  var Val: Variant): boolean;
begin
  Result:=false;
end;

procedure TfrObject.SetScript(const AValue: TfrScriptStrings);
begin
  if fScript=AValue then exit;
  fScript.Assign(AValue);
end;

procedure TfrObject.SetVisible(AValue: Boolean);
begin
  if fVisible=AValue then Exit;
  fVisible:=AValue;
end;

function TfrObject.GetText: string;
begin
  Result:=fMemo.Text;
end;

procedure TfrObject.SetText(AValue: string);
begin
  fMemo.Text:=AValue;
end;

procedure TfrObject.InternalExecScript;
begin
  if Assigned(FOnExecScriptEvent) then
    FOnExecScriptEvent(Self, Script)
  else
    frInterpretator.DoScript(Script);
end;

procedure TfrObject.SetWidth(AValue: Integer);
begin
  DX:=AValue;
  if Assigned(frDesigner) then
    frDesigner.Invalidate;
end;

procedure TfrObject.SetTop(AValue: Integer);
begin
  Y:=AValue;
  if Assigned(frDesigner) then
    frDesigner.Invalidate;
end;

//Code from FormStorage
function TfrObject.GetSaveProperty(const Prop: String; aObj : TPersistent=nil): string;
Var PropInfo  : PPropInfo;
    Obj       : TObject;
begin
  Result:='';

  if not Assigned(aObj) then
    aObj:=Self;
    
  Try
    PropInfo:=GetPropInfo(aObj,Prop);
    if Assigned(PropInfo) then
    begin
      Case PropInfo^.PropType^.Kind of
        tkChar,tkAString,tkWString,
        tkSString,tkLString         : Result:=GetStrProp(aObj,Prop);
        tkBool,tkInt64,tkQWord,
        tkInteger                   : begin
                                        if PropInfo^.PropType^.Name='TGraphicsColor' then
                                          Result:=ColorToString(GetOrdProp(aObj,PropInfo))
                                        else
                                          Result:=IntToStr(GetOrdProp(aObj,PropInfo));
                                      end;
        tkSet                       : Result:=GetSetProp(aObj,Prop);
        tkFloat                     : begin
                                        lrNormalizeLocaleFloats(True);
                                        Result := FloatToStr(GetFloatProp(aObj,Prop));
                                        lrNormalizeLocaleFloats(false);
                                      end;
        tkEnumeration               : Result:=GetEnumProp(aObj,Prop);
        tkClass                     : Begin
                                        Obj:=GetObjectProp(aObj,Prop);
                                        if Obj Is TStrings then
                                          Result:=TStrings(Obj).CommaText
                                        else
                                          Result:=Format('Object "%s" not implemented',[PropInfo^.PropType^.Name]);
                                      end;
      end;
    end
    else Result:='??';
  Except
  End;
end;

//Code from formStorage
procedure TfrObject.RestoreProperty(const Prop, aValue: String;  aObj : TPersistent=nil);
Var PropInfo  : PPropInfo;
    Obj       : TObject;
begin
  Try
    if not Assigned(aObj) then
      aObj:=Self;
      
    PropInfo:=GetPropInfo(aObj,Prop);
    if Assigned(PropInfo) then
    begin
      Case PropInfo^.PropType^.Kind of
        tkChar,tkAString,tkWString,
        tkSString,tkLString         : SetStrProp(aObj,Prop,aValue);
        tkBool,tkInt64,tkQWord,
        tkInteger                   : begin
                                        if PropInfo^.PropType^.Name='TGraphicsColor' then
                                          SetOrdProp(aObj,PropInfo,StringToColor(aValue))
                                        else
                                          SetOrdProp(aObj,PropInfo,StrToInt(aValue))
                                      end;
        tkSet                       : SetSetProp(aObj,Prop,aValue);
        tkFloat                     : begin
                                        lrNormalizeLocaleFloats(true);
                                        SetFloatProp(aObj,Prop,StrToFloat(aValue));
                                        lrNormalizeLocaleFloats(false);
                                      end;
        tkEnumeration               : SetEnumProp(aObj,Prop,aValue);
        tkClass                     : Begin
                                        Obj:=GetObjectProp(aObj,Prop);
                                        if Obj Is TStrings then
                                          TStrings(Obj).CommaText:=aValue;
                                      end;
      end;
    end;
  Except
  End;
end;

constructor TfrObject.Create(AOwnerPage: TfrPage);
begin
  inherited Create;
  OwnerPage:=AOwnerPage;
  fUpdate:=0;
  BaseName:='LRObj';
  fVisible:=True;
  fMemo:=TfrMemoStrings.Create;
  fScript:=TfrScriptStrings.Create;
  FDesignOptions:=[];

  if Assigned(OwnerPage) then
    OwnerPage.Objects.Add(Self);
end;

destructor TfrObject.Destroy;
begin
  fmemo.Free;
  fScript.Free;
  
  inherited Destroy;
end;

procedure TfrObject.AssignTo(Dest: TPersistent);
begin
  //
end;

procedure TfrObject.Assign(Source: TPersistent);
begin
  inherited Assign(Source);

  if Source is TfrObject then
  begin
    x  := TfrObject(Source).x;
    y  := TfrObject(Source).y;
    dx := TfrObject(Source).dx;
    dy := TfrObject(Source).dy;

    Memo.Assign(TfrObject(Source).Memo);
    Script.Assign(TfrObject(Source).Script);
    Visible:=TfrObject(Source).Visible;
    FOnExecScriptEvent:=TfrObject(Source).FOnExecScriptEvent;
  end;
end;

procedure TfrObject.BeginUpdate;
begin
  Inc(fUpdate)
end;

procedure TfrObject.EndUpdate;
begin
  if fUpdate>0 then
    Dec(fUpdate)
end;

procedure TfrObject.CreateUniqueName;
var
  i: Integer;
begin
  fName := '';
  if Assigned(CurReport) then
  begin
    i:=1;
    while Assigned(CurReport.FindObject(BaseName + IntToStr(i))) do
      inc(i);
    Name := BaseName + IntToStr(i);
  end
  else
    Name := BaseName + '1';
end;

procedure TfrObject.LoadFromXML(XML: TLrXMLConfig; const Path: String);
begin
  //ClassName not read here.
  Name:=XML.GetValue(Path+'Name/Value','');
  if Name='' then
    CreateUniqueName;

  Visible:=XML.GetValue(Path+'Visible/Value'{%H-}, true);
end;

procedure TfrObject.SaveToXML(XML: TLrXMLConfig; const Path: String);
begin
  XML.SetValue(Path+'Name/Value', GetSaveProperty('Name'));
  XML.SetValue(Path+'ClassName/Value', self.Classname);
  
  XML.SetValue(Path+'Visible/Value', Visible);
end;

{ TfrRect }

function TfrRect.GetRect: TRect;
begin
  Result:=Rect(Left,Top,Right,Bottom);
end;

procedure TfrRect.SetRect(const AValue: TRect);
begin
  fLeft:=aValue.Left;
  fRight:=aValue.Right;
  fBottom:=aValue.Bottom;
  fTop:=aValue.Top;
end;

{ TfrPageReport }

procedure TfrPageReport.LoadFromXML(XML: TLrXMLConfig; const Path: String);
var
  Rc   : TRect;
begin
  {$ifdef DbgPrinter}
  DebugLnEnter('TfrPageReport.LoadFromXML INIT');
  {$endif}
  inherited LoadFromXML(XML, Path);


  pgSize := XML.GetValue(Path+'PgSize/Value'{%H-}, 0); // TODO chk
  rc.left := XML.GetValue(Path+'Margins/left/Value'{%H-}, 0); // TODO chk
  rc.top := XML.GetValue(Path+'Margins/Top/Value'{%H-}, 0); // TODO chk
  rc.Right := XML.GetValue(Path+'Margins/Right/Value'{%H-}, 0); // TODO chk
  rc.Bottom := XML.GetValue(Path+'Margins/Bottom/Value'{%H-}, 0); // TODO chk
  Margins.AsRect := rc;
  RestoreProperty('Orientation',XML.GetValue(Path+'Orientation/Value',''));

  UseMargins := XML.GetValue(Path+'UseMargins/Value'{%H-}, True); // TODO chk
  PrintToPrevPage := XML.GetValue(Path+'PrintToPrevPage/Value'{%H-}, True); // TODO chk
  ColCount := XML.GetValue(Path+'ColCount/Value'{%H-}, 1); // TODO chk
  ColGap := XML.GetValue(Path+'ColGap/Value'{%H-}, 0);
  RestoreProperty('LayoutOrder',XML.GetValue(Path+'LayoutOrder/Value','loColumns'));
  ChangePaper(pgSize, Width, Height, Orientation);
  {$ifdef DbgPrinter}
  DebugLnExit('TfrPageReport.LoadFromXML END');
  {$endif}
end;

procedure TfrPageReport.SavetoXML(XML: TLrXMLConfig; const Path: String);
var
  Rc   : TRect;
begin
  inherited SavetoXML(XML, Path);
  
  Rc:=Margins.AsRect;
  XML.SetValue(Path+'PgSize/Value'{%H-}, PgSize);
  XML.SetValue(Path+'Margins/left/Value'{%H-}, Rc.Left);
  XML.SetValue(Path+'Margins/Top/Value'{%H-}, Rc.Top);
  XML.SetValue(Path+'Margins/Right/Value'{%H-}, Rc. Right);
  XML.SetValue(Path+'Margins/Bottom/Value'{%H-}, Rc.Bottom);
  XML.SetValue(Path+'Orientation/Value', GetSaveProperty('Orientation'));
  XML.SetValue(Path+'UseMargins/Value'{%H-}, UseMargins);
  XML.SetValue(Path+'PrintToPrevPage/Value'{%H-}, PrintToPrevPage);
  XML.SetValue(Path+'ColCount/Value'{%H-}, ColCount);
  XML.SetValue(Path+'ColGap/Value'{%H-}, ColGap);
  XML.SetValue(Path+'LayoutOrder/Value', GetSaveProperty('LayoutOrder'));
end;

constructor TfrPageReport.CreatePage;
begin
  self.Create(prn.DefaultPageSize, 0, 0, poPortrait);
end;

{ TfrPageDialog }

procedure TfrPageDialog.EditFormDestroy(Sender: TObject);
begin
  FForm:=nil;
end;

function TfrPageDialog.GetCaption: string;
begin
  Result:=FCaption;
end;

procedure TfrPageDialog.SetCaption(AValue: string);
begin
  FCaption:=AValue;
  if Assigned(FForm) then
    FForm.Caption:=AValue;
end;

procedure TfrPageDialog.UpdateControlPosition;
begin
  if Assigned(FForm) then
  begin
    FForm.Left:=Left;
    FForm.Top:=Top;
    FForm.Width:=Width;
    FForm.Height:=Height - 20;
    FForm.Position:=poScreenCenter;
  end;
end;

procedure TfrPageDialog.PrepareObjects;
begin
  //Do nothing
end;

procedure TfrPageDialog.InitReport;
var
  i:integer;
  P:TfrControl;

  S:string;
  F:TComponent;
begin
  if not fVisible then
    exit;
  fHasVisibleControls:=False;

  FForm   :=TfrDialogForm.CreateNew(Application);
  FForm.OnDestroy:=@EditFormDestroy;
  FForm.Caption:=FCaption;
  FForm.ShowHint:=true;
  S:=FName;
  F:=Application.FindComponent(S);
  if Assigned(F) and (F<>FForm) then
  begin
    i:=1;
    while Assigned(Application.FindComponent(FName + IntToStr(i))) do inc(i);
    S:=FName + IntToStr(i);
  end;

  FForm.Name:=S;

  for i:=0 to Objects.Count - 1 do
  begin
    P:=TfrControl(Objects[i]);
    P.AttachToParent;
    if not (P is TfrNonVisualControl) then
    begin
      fHasVisibleControls:=true;
      P.UpdateControlPosition;
    end;
  end;

  ExecScript;

  if fHasVisibleControls then
  begin
    UpdateControlPosition;
    if FForm.ShowModal <> mrOk then
      CurReport.Terminated:=true;
  end;
end;

procedure TfrPageDialog.DoneReport;
begin
  inherited DoneReport;
  FreeAndNil(FForm);
end;

procedure TfrPageDialog.SetLeft(AValue: Integer);
begin
  inherited SetLeft(AValue);
  UpdateControlPosition;
end;

procedure TfrPageDialog.SetTop(AValue: Integer);
begin
  inherited SetTop(AValue);
  UpdateControlPosition;
end;

procedure TfrPageDialog.SetWidth(AValue: Integer);
begin
  inherited SetWidth(AValue);
  UpdateControlPosition;
end;

procedure TfrPageDialog.SetHeight(AValue: Integer);
begin
  inherited SetHeight(AValue);
  UpdateControlPosition;
end;

procedure TfrPageDialog.ExecScript;
var
  FSavePage:TfrPage;
  CmdList, ErrorList:TStringList;
begin
  if DocMode = dmPrinting then
  begin
    FSavePage:=CurPage;

    CmdList:=TStringList.Create;
    ErrorList:=TStringList.Create;
    try
      CurView := nil;
      CurPage := Self;
      frInterpretator.PrepareScript(Script, CmdList, ErrorList);
      frInterpretator.DoScript(CmdList);
    finally
      CurPage:=FSavePage;
      FreeAndNil(CmdList);
      FreeAndNil(ErrorList);
    end;
  end;
end;


constructor TfrPageDialog.Create(AOwnerPage: TfrPage);
begin
  inherited Create(AOwnerPage);
  BaseName:='Dialog';
  
  Width :=400;
  Height:=250;
  PageType:=ptDialog;
end;

destructor TfrPageDialog.Destroy;
begin
  inherited Destroy;
  if Assigned(fForm) then
  begin
    fForm.OnDestroy:=nil;
    FreeAndNil(fForm);
  end;
end;

procedure TfrPageDialog.LoadFromXML(XML: TLrXMLConfig; const Path: String);
begin
  inherited LoadFromXML(XML, Path);
  Caption:=XML.GetValue(Path+'Caption/Value', '');
end;

procedure TfrPageDialog.SavetoXML(XML: TLrXMLConfig; const Path: String);
begin
  inherited SavetoXML(XML, Path);
  XML.SetValue(Path+'Caption/Value', Caption);
end;

{ TLrXMLConfig }

procedure TLrXMLConfig.LoadFromStream(const Stream: TStream);
begin

  Flush;
  FreeAndNil(Doc);

  if csLoading in ComponentState then
    exit;

  if assigned(Stream) and not StartEmpty then
    ReadXMLFile(Doc, Stream);

  if not Assigned(Doc) then
    Doc := TXMLDocument.Create;

  if not Assigned(Doc.DocumentElement) then
    Doc.AppendChild(Doc.CreateElement(RootName))
  else
    if Doc.DocumentElement.NodeName <> RootName then
      raise EXMLConfigError.Create(SWrongRootName);
end;

procedure TLrXMLConfig.SaveToStream(const Stream: TStream);
begin
  WriteXMLFile(Doc, Stream);
  Flush;
end;

procedure TLrXMLConfig.SetValue(const APath: string; const AValue: string);
begin
  inherited SetValue(UTF8Decode(APath), UTF8Decode(AValue));
end;

function TLrXMLConfig.GetValue(const APath: string; const ADefault: string): string;
{var
  wValue: widestring;}
begin
  if frUnWrapRead then
    result := {%H-}inherited GetValue(APath, ADefault{%H-})
  else
  begin
    result := UTF16ToUTF8(inherited GetValue(APath, ADefault));
{    WValue := inherited GetValue(UTF8Decode(APath), UTF8Decode(ADefault));
    Result := UTF8Encode(WValue);}
  end;
end;

initialization
  DoInit;

finalization
  DoExit;

end.



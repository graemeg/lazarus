
{*****************************************}
{                                         }
{             FastReport v2.3             }
{             Report Designer             }
{                                         }
{  Copyright (c) 1998-99 by Tzyganenko A. }
{                                         }
{*****************************************}

unit LR_Desgn;

interface

{$I lr_vers.inc}
{.$Define ExtOI} // External Custom Object inspector (Christian)
{.$Define StdOI} // External Standard Object inspector (Jesus)
{$define sbod}  // status bar owner draw
{$define ppaint}
uses
  Classes, SysUtils, Types, LazFileUtils, LazUTF8, LMessages,
  Forms, Controls, Graphics, Dialogs, ComCtrls,
  ExtCtrls, Buttons, StdCtrls, Menus,

  LCLType,LCLIntf,LCLProc,GraphType,Printers, ActnList,

  ObjectInspector, PropEdits, GraphPropEdits,
  
  LR_Class, LR_Color,LR_Edit;


const
  MaxUndoBuffer         = 100;
  crPencil              = 11;
  dtFastReportForm      = 1;
  dtFastReportTemplate  = 2;
  dtLazReportForm       = 3;
  dtLazReportTemplate   = 4;

type
  TLoadReportEvent = procedure(Report: TfrReport; var ReportName: String) of object;
  TSaveReportEvent = procedure(Report: TfrReport; var ReportName: String;
    SaveAs: Boolean; var Saved: Boolean) of object;

  TfrDesignerForm = class;
  //TlrTabEditControl = class(TCustomTabControl);

  { TfrDesigner }

  TfrDesigner = class(TComponent)  // fake component
  private
    FOnLoadReport: TLoadReportEvent;
    FOnSaveReport: TSaveReportEvent;
    FTemplDir: String;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure Loaded; override;
  published
    property TemplateDir: String read FTemplDir write FTemplDir;
    property OnLoadReport: TLoadReportEvent read FOnLoadReport write FOnLoadReport;
    property OnSaveReport: TSaveReportEvent read FOnSaveReport write FOnSaveReport;
  end;

  TfrSelectionType = (ssBand, ssMemo, ssOther, ssMultiple, ssClipboardFull);
  TfrSelectionStatus = set of TfrSelectionType;
  TfrReportUnits = (ruPixels, ruMM, ruInches);
  TfrShapeMode = (smFrame, smAll);

  TfrUndoAction = (acInsert, acDelete, acEdit, acZOrder, acDuplication);
  PfrUndoObj = ^TfrUndoObj;
  TfrUndoObj = record
    Next: PfrUndoObj;
    ObjID: Integer;
    ObjPtr: TfrView;
    Int: Integer;
  end;

  TfrUndoRec = record
    Action: TfrUndoAction;
    Page: Integer;
    Objects: PfrUndoObj;
  end;

  PfrUndoRec1 = ^TfrUndoRec1;
  TfrUndoRec1 = record
    ObjPtr: TfrView;
    Int: Integer;
  end;

  PfrUndoBuffer = ^TfrUndoBuffer;
  TfrUndoBuffer = Array[0..MaxUndoBuffer - 1] of TfrUndoRec;

  TfrMenuItemInfo = class(TObject)
  private
    MenuItem: TMenuItem;
    Btn     : TSpeedButton;
  end;
  
  TfrDesignerDrawMode = (dmAll, dmSelection, dmShape);
  TfrCursorType       = (ctNone, ct1, ct2, ct3, ct4, ct5, ct6, ct7, ct8);
  TfrDesignMode       = (mdInsert, mdSelect);
  
  TfrSplitInfo = record
    SplRect: TRect;
    SplX   : Integer;
    View1,
    View2  : TfrView;
  end;

  TViewAction = procedure(View: TFrView; Data:PtrInt) of object;

  { TfrObjectInspector }
  TfrObjectInspector = Class({$IFDEF EXTOI}TForm{$ELSE}TPanel{$ENDIF})
  private
    FSelectedObject: TObject;
    fPropertyGrid : TCustomPropertiesGrid;
    {$IFNDEF EXTOI}
    fcboxObjList  : TComboBox;
    fBtn,fBtn2    : TButton;
    fPanelHeader  : TPanel;
    fLastHeight   : Word;
    fDown         : Boolean;
    fPt           : TPoint;

    procedure BtnClick(Sender : TObject);
    procedure HeaderMDown(Sender: TOBject; Button: TMouseButton;
                  {%H-}Shift: TShiftState; X, Y: Integer);
    procedure HeaderMMove(Sender: TObject; {%H-}Shift: TShiftState; {%H-}X,
                  {%H-}Y: Integer);
    procedure HeaderMUp(Sender: TOBject; {%H-}Button: TMouseButton;
                   {%H-}Shift: TShiftState; {%H-}X, {%H-}Y: Integer);
    {$ENDIF}
  protected
    procedure CMVisibleChanged(var TheMessage: TLMessage); message CM_VISIBLECHANGED;
    {$IFDEF EXTOI}
    procedure DoHide; override;
    {$ENDIF}
  public
    constructor Create(aOwner : TComponent); override;
    destructor Destroy; override;

    procedure Select(Obj: TObject);
    procedure cboxObjListOnChanged(Sender: TObject);
    procedure SetModifiedEvent(AEvent: TNotifyEvent);
    procedure Refresh;
    property SelectedObject:TObject read FSelectedObject;
  end;

  TPaintSel = class;
  TAlignGuides = class;

  { TfrDesignerPage }

  TfrDesignerPage = class(TCustomControl)
  private
    Down,                          // mouse button was pressed
    Moved,                         // mouse was moved (with pressed btn)
    DFlag,                         // was double click
    RFlag: Boolean;                // selecting objects by framing
    Mode : TfrDesignMode;          // current mode
    CT   : TfrCursorType;          // cursor type
    LastX, LastY: Integer;         // here stored last mouse coords
    SplitInfo: TfrSplitInfo;
    RightBottom: Integer;
    LeftTop: TPoint;
    FirstBandMove: Boolean;
    FDesigner: TfrDesignerForm;
    
    fOldFocusRect : TRect;
    fPaintSel: TPaintSel;
    fPainting: boolean;
    fResizeDialog:boolean;
    fGuides: TAlignGuides;

    procedure NormalizeRect(var r: TRect);
    procedure NormalizeCoord(t: TfrView);
    function FindNearestEdge(var x, y: Integer): Boolean;
    procedure RoundCoord(var x, y: Integer);
    procedure Draw(N: Integer; AClipRgn: HRGN);
    procedure DrawPage(DrawMode: TfrDesignerDrawMode);
    procedure DrawRectLine(Rect: TRect);
    procedure DrawFocusRect(aRect: TRect);
    procedure DrawHSplitter(Rect: TRect);
    procedure DrawSelection(t: TfrView);
    procedure DrawShape(t: TfrView);
    
    procedure DrawDialog(N: Integer; AClipRgn: HRGN);

    procedure MDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure MUp(Sender: TObject; Button: TMouseButton; {%H-}Shift: TShiftState; {%H-}X, {%H-}Y: Integer);
    procedure MMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
    procedure CMMouseLeave(var {%H-}Message: TLMessage); message CM_MOUSELEAVE;
    procedure DClick(Sender: TObject);
    procedure MoveResize(Kx,Ky:Integer; UseFrames,AResize: boolean);
    procedure EnableEvents(aOk: boolean = true);

    // focusrect
    procedure NPDrawFocusRect;
    procedure NPEraseFocusRect;
    // objects
    procedure NPDrawLayerObjects(Rgn: HRGN; Start:Integer=10000);
    procedure NPRedrawViewCheckBand(t: TfrView);
    // selection
    procedure NPPaintSelection;                   // this is the only function that works during Paint
    procedure NPDrawSelection;
    procedure NPEraseSelection;

  protected
    procedure Paint; override;
    procedure WMEraseBkgnd(var {%H-}Message: TLMEraseBkgnd); message LM_ERASEBKGND;
    procedure DoContextPopup(MousePos: TPoint; var Handled: Boolean); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor destroy; override;

    procedure Init;
    procedure SetPage;
    procedure GetMultipleSelected;
    procedure CheckGuides;
  end;

  TPaintTimeStatusItem = (ptsFocusRect);
  TPaintTimeStatus = set of TPaintTimeStatusItem;

  { TPaintSel }

  TPaintSel=class
  private
    fStatus: TPaintTimeStatus;
    fFocusRect: TRect;
    fOwner: TfrDesignerPage;
    fGreenBullet,fGrayBullet: TPortableNetworkGraphic;
    procedure InvalidateFocusRect;
    procedure DrawOrInvalidateViewHandles(t:TfrView; aDraw:boolean);
    procedure DrawOrInvalidateSelection(aDraw:boolean);
  public
    constructor Create(AOwner: TfrDesignerPage);
    destructor Destroy; override;
    procedure FocusRect(aRect:TRect);
    procedure RemoveFocusRect;
    procedure InvalidateSelection;
    procedure PaintSelection;
    procedure Paint;
  end;

  { TAlignGuides }

  TAlignGuides = class
  private
    fOwner: TfrDesignerPage;
    fSelBounds: TRect;
    fSelMouse: TPoint;
    fX,fY: Integer;
    px,py: PInteger;
    fMoveSelectionTracking: boolean;
    procedure InvalidateHorzGuide;
    procedure InvalidateVertGuide;
    procedure PaintGuides;
    procedure ChangeGuide(vert, show: boolean; value:Integer);
    function  FindAnyGuide(const vert: boolean; const ax,ay:Integer; out snap: Integer;
                           skipSel:boolean; skipTyp:TfrSetOfTyp): boolean;
  public
    constructor Create(aOwner: TfrDesignerPage);
    procedure Paint;
    procedure FindGuides(ax, ay:Integer; skipSel:boolean=false; skipTyp:TfrSetOfTyp=[]);
    function  SnapToGuide(var ax, ay: Integer): boolean;
    function  SnapSelectionToGuide(const kx, ky: Integer; var ax, ay:Integer): boolean;
    procedure HideGuides;
    procedure ResetMoveSelection(ax, ay: Integer);
    //property X: PInteger read px;
    //property Y: PInteger read py;
  end;

  { TfrDesignerForm }

  TfrDesignerForm = class(TfrReportDesigner)
    acDuplicate: TAction;
    edtRedo: TAction;
    edtUndo: TAction;
    btnGuides: TSpeedButton;
    MenuItem2: TMenuItem;
    IEPopupMenu: TPopupMenu;
    IEButton: TSpeedButton;
    tlsDBFields: TAction;
    FileBeforePrintScript: TAction;
    FileOpen: TAction;
    FilePreview: TAction;
    FileSaveAs: TAction;
    FileSave: TAction;
    acToggleFrames: TAction;
    actList: TActionList;
    frSpeedButton1: TSpeedButton;
    frSpeedButton2: TSpeedButton;
    frSpeedButton3: TSpeedButton;
    frSpeedButton4: TSpeedButton;
    frSpeedButton5: TSpeedButton;
    frSpeedButton6: TSpeedButton;
    frTBSeparator16: TPanel;
    Image1: TImage;
    ActionsImageList: TImageList;
    ImgIndic: TImageList;
    LinePanel: TPanel;
    MenuItem1: TMenuItem;
    OB7: TSpeedButton;
    panTab: TPanel;
    panForDlg: TPanel;
    PgB4: TSpeedButton;
    Tab1: TTabControl;
    ScrollBox1: TScrollBox;
    StatusBar1: TStatusBar;
    frDock1: TPanel;
    frDock2: TPanel;
    Popup1: TPopupMenu;
    N1: TMenuItem;
    N2: TMenuItem;
    N3: TMenuItem;
    N5: TMenuItem;
    N6: TMenuItem;
    MainMenu1: TMainMenu;
    FileMenu: TMenuItem;
    EditMenu: TMenuItem;
    ToolMenu: TMenuItem;
    N10: TMenuItem;
    N11: TMenuItem;
    N12: TMenuItem;
    N13: TMenuItem;
    N19: TMenuItem;
    N20: TMenuItem;
    N21: TMenuItem;
    N23: TMenuItem;
    N24: TMenuItem;
    N25: TMenuItem;
    N27: TMenuItem;
    N28: TMenuItem;
    N26: TMenuItem;
    N29: TMenuItem;
    N30: TMenuItem;
    N31: TMenuItem;
    N32: TMenuItem;
    N33: TMenuItem;
    N36: TMenuItem;
    OpenDialog1: TOpenDialog;
    SaveDialog1: TSaveDialog;
    ImageList1: TImageList;
    Pan5: TMenuItem;
    N8: TMenuItem;
    ImageList2: TImageList;
    N38: TMenuItem;
    Pan6: TMenuItem;
    N39: TMenuItem;
    N40: TMenuItem;
    N42: TMenuItem;
    MastMenu: TMenuItem;
    N16: TMenuItem;
    Panel2: TPanel;
    FileBtn1: TSpeedButton;
    FileBtn2: TSpeedButton;
    FileBtn3: TSpeedButton;
    FileBtn4: TSpeedButton;
    CutB: TSpeedButton;
    CopyB: TSpeedButton;
    PstB: TSpeedButton;
    ZB1: TSpeedButton;
    ZB2: TSpeedButton;
    SelAllB: TSpeedButton;
    PgB1: TSpeedButton;
    PgB2: TSpeedButton;
    PgB3: TSpeedButton;
    GB1: TSpeedButton;
    GB2: TSpeedButton;
    ExitB: TSpeedButton;
    Panel3: TPanel;
    AlB1: TSpeedButton;
    AlB2: TSpeedButton;
    AlB3: TSpeedButton;
    AlB4: TSpeedButton;
    AlB5: TSpeedButton;
    FnB1: TSpeedButton;
    FnB2: TSpeedButton;
    FnB3: TSpeedButton;
    ClB2: TSpeedButton;
    HlB1: TSpeedButton;
    AlB6: TSpeedButton;
    AlB7: TSpeedButton;
    Panel1: TPanel;
    FrB1: TSpeedButton;
    FrB2: TSpeedButton;
    FrB3: TSpeedButton;
    FrB4: TSpeedButton;
    ClB1: TSpeedButton;
    ClB3: TSpeedButton;
    FrB5: TSpeedButton;
    FrB6: TSpeedButton;
    frTBSeparator1: TPanel;
    frTBSeparator2: TPanel;
    frTBSeparator3: TPanel;
    frTBSeparator4: TPanel;
    frTBSeparator5: TPanel;
    frTBPanel1: TPanel;
    C3: TComboBox;
    C2: TComboBox;
    frTBPanel2: TPanel;
    frTBSeparator6: TPanel;
    frTBSeparator7: TPanel;
    frTBSeparator8: TPanel;
    frTBSeparator9: TPanel;
    frTBSeparator10: TPanel;
    N37: TMenuItem;
    Pan2: TMenuItem;
    Pan3: TMenuItem;
    Pan1: TMenuItem;
    Pan4: TMenuItem;
    Panel4: TPanel;
    OB1: TSpeedButton;
    OB2: TSpeedButton;
    OB3: TSpeedButton;
    OB4: TSpeedButton;
    OB5: TSpeedButton;
    frTBSeparator12: TPanel;
    Panel5: TPanel;
    Align1: TSpeedButton;
    Align2: TSpeedButton;
    Align3: TSpeedButton;
    Align4: TSpeedButton;
    Align5: TSpeedButton;
    Align6: TSpeedButton;
    Align7: TSpeedButton;
    Align8: TSpeedButton;
    Align9: TSpeedButton;
    Align10: TSpeedButton;
    frTBSeparator13: TPanel;
    frDock4: TPanel;
    HelpMenu: TMenuItem;
    N34: TMenuItem;
    GB3: TSpeedButton;
    N46: TMenuItem;
    N47: TMenuItem;
    UndoB: TSpeedButton;
    frTBSeparator14: TPanel;
    AlB8: TSpeedButton;
    RedoB: TSpeedButton;
    N48: TMenuItem;
    OB6: TSpeedButton;
    frTBSeparator15: TPanel;
    Panel6: TPanel;
    Pan7: TMenuItem;
    N14: TMenuItem;
    Panel7: TPanel;
    PBox1: TPaintBox;
    N17: TMenuItem;
    E1: TEdit;
    Panel8: TPanel;
    SB1: TSpeedButton;
    SB2: TSpeedButton;
    HelpBtn: TSpeedButton;
    frTBSeparator11: TPanel;
    N18: TMenuItem;
    N22: TMenuItem;
    N35: TMenuItem;
    Popup2: TPopupMenu;
    N41: TMenuItem;
    N43: TMenuItem;
    N44: TMenuItem;
    StB1: TSpeedButton;
    procedure acDuplicateExecute(Sender: TObject);
    procedure acToggleFramesExecute(Sender: TObject);
    procedure btnGuidesClick(Sender: TObject);
    procedure C2GetItems(Sender: TObject);
    procedure edtRedoExecute(Sender: TObject);
    procedure edtUndoExecute(Sender: TObject);
    procedure FileBeforePrintScriptExecute(Sender: TObject);
    procedure FileOpenExecute(Sender: TObject);
    procedure FilePreviewExecute(Sender: TObject);
    procedure FileSaveAsExecute(Sender: TObject);
    procedure FileSaveExecute(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormKeyDown(Sender: TObject; var Key: Word;  Shift: TShiftState);
    procedure DoClick(Sender: TObject);
    procedure ClB1Click(Sender: TObject);
    procedure GB1Click(Sender: TObject);
    procedure ScrollBox1DragDrop(Sender, Source: TObject; X, Y: Integer);
    procedure ScrollBox1DragOver(Sender, Source: TObject; X, Y: Integer;
      State: TDragState; var Accept: Boolean);
    procedure IEButtonClick(Sender: TObject);
    procedure tlsDBFieldsExecute(Sender: TObject);
    procedure ZB1Click(Sender: TObject);
    procedure ZB2Click(Sender: TObject);
    procedure PgB1Click(Sender: TObject);
    procedure PgB2Click(Sender: TObject);
    procedure OB2MouseDown(Sender: TObject; {%H-}Button: TMouseButton;
      Shift: TShiftState; {%H-}X, {%H-}Y: Integer);
    procedure OB1Click(Sender: TObject);
    procedure CutBClick(Sender: TObject);
    procedure CopyBClick(Sender: TObject);
    procedure PstBClick(Sender: TObject);
    procedure SelAllBClick(Sender: TObject);
    procedure ExitBClick(Sender: TObject);
    procedure PgB3Click(Sender: TObject);
    procedure FormResize(Sender: TObject);
    procedure N5Click(Sender: TObject);
    procedure N6Click(Sender: TObject);
    procedure GB2Click(Sender: TObject);
    procedure FileBtn1Click(Sender: TObject);
    //procedure FileBtn3Click(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure FormHide(Sender: TObject);
    procedure N8Click(Sender: TObject);
    procedure C2DrawItem({%H-}Control: TWinControl; Index: Integer; Rect: TRect;
      {%H-}State: TOwnerDrawState);
    procedure HlB1Click(Sender: TObject);
    procedure N42Click(Sender: TObject);
    procedure Popup1Popup(Sender: TObject);
    procedure N23Click(Sender: TObject);
    procedure N37Click(Sender: TObject);
    procedure Pan2Click(Sender: TObject);
    procedure N14Click(Sender: TObject);
    procedure Align1Click(Sender: TObject);
    procedure Align2Click(Sender: TObject);
    procedure Align3Click(Sender: TObject);
    procedure Align4Click(Sender: TObject);
    procedure Align5Click(Sender: TObject);
    procedure Align6Click(Sender: TObject);
    procedure Align7Click(Sender: TObject);
    procedure Align8Click(Sender: TObject);
    procedure Align9Click(Sender: TObject);
    procedure Align10Click(Sender: TObject);
    procedure Tab1Change(Sender: TObject);
    procedure N34Click(Sender: TObject);
    procedure GB3Click(Sender: TObject);
    //procedure N20Click(Sender: TObject);
    procedure PBox1Paint(Sender: TObject);
    procedure SB1Click(Sender: TObject);
    procedure SB2Click(Sender: TObject);
    procedure HelpBtnClick(Sender: TObject);
    procedure FormMouseDown(Sender: TObject; {%H-}Button: TMouseButton;
      {%H-}Shift: TShiftState; {%H-}X, {%H-}Y: Integer);
    procedure N22Click(Sender: TObject);
    procedure Tab1MouseDown(Sender: TObject; Button: TMouseButton;
      {%H-}Shift: TShiftState; {%H-}X, {%H-}Y: Integer);
    procedure frDesignerFormClose(Sender: TObject; var {%H-}CloseAction: TCloseAction);
    procedure frDesignerFormCloseQuery(Sender: TObject; var CanClose: boolean);
    procedure frSpeedButton1Click(Sender: TObject);
    procedure StB1Click(Sender: TObject);
  private
    //
    FirstSelected      : TfrView;     // First Selected Object
    SelNum             : Integer;     // number of objects currently selected
    MRFlag             : Boolean;     // several objects was selected
    ObjRepeat          : Boolean;     // was pressed Shift + Insert Object

    { Private declarations }
    fInBuildPage : Boolean;
    
    PageView: TfrDesignerPage;
    EditorForm: TfrEditorForm;
    ColorSelector: TColorSelector;
    MenuItems: TFpList;
    ItemWidths: TStringList;
    FCurPage: Integer;
    FGridSize: Integer;
    FGridShow, FGridAlign, FGuidesShow: Boolean;
    FUnits: TfrReportUnits;
    FGrayedButtons: Boolean;
    FUndoBuffer, FRedoBuffer: TfrUndoBuffer;
    FUndoBufferLength, FRedoBufferLength: Integer;
    FirstTime: Boolean;
    MaxItemWidth, MaxShortCutWidth: Integer;
//    FirstInstance: Boolean;
    EditAfterInsert: Boolean;
    FCurDocName, FCaption: String;
    fCurDocFileType: Integer;
    ShapeMode: TfrShapeMode;
    FReportPopupPoint: TPoint;
    FLastOpenDirectory: string;
    FLastSaveDirectory: string;
    
    {$IFDEF StdOI}
    ObjInsp  : TObjectInspector;
    PropHook : TPropertyEditorHook;
    {$ELSE}
    ObjInsp  : TfrObjectInspector;
    {$ENDIF}
    procedure CreateNewReport;
    procedure DuplicateSelection;
    procedure ObjInspSelect(Obj:TObject);
    procedure ObjInspRefresh;
    procedure DataInspectorRefresh;

    procedure GetFontList;
    procedure SetMenuBitmaps;
    procedure SetCurPage(Value: Integer);
    procedure SetGridSize(Value: Integer);
    procedure SetGridShow(Value: Boolean);
    procedure SetGridAlign(Value: Boolean);
    procedure SetGuidesShow(AValue: boolean);
    procedure SetUnits(Value: TfrReportUnits);
    procedure SetGrayedButtons(Value: Boolean);
    procedure SetCurDocName(Value: String);
    procedure SelectionChanged;
    procedure ShowPosition;
    procedure ShowContent;
    procedure EnableControls;
    procedure ResetSelection;
    procedure DeleteObjects;
    procedure AddPage(ClName : string);
    procedure RemovePage(n: Integer);
    procedure SetPageTitles;
//**    procedure WMGetMinMaxInfo(var Msg: TWMGetMinMaxInfo); message WM_GETMINMAXINFO;
    procedure FillInspFields;
    function RectTypEnabled: Boolean;
    function FontTypEnabled: Boolean;
    function ZEnabled: Boolean;
    function CutEnabled: Boolean;
    function CopyEnabled: Boolean;
    function PasteEnabled: Boolean;
    function DelEnabled: Boolean;
    function EditEnabled: Boolean;
    procedure ColorSelected(Sender: TObject);
    procedure SelectAll;
    procedure Unselect;
    procedure CutToClipboard;
    procedure CopyToClipboard;
    procedure SaveState;
    procedure RestoreState;
    procedure ClearBuffer(Buffer: TfrUndoBuffer; var BufferLength: Integer);
    procedure ClearUndoBuffer;
    procedure ClearRedoBuffer;
    procedure Undo(Buffer: PfrUndoBuffer);
    procedure ReleaseAction(ActionRec: TfrUndoRec);
    procedure AddAction(Buffer: PfrUndoBuffer; a: TfrUndoAction; List: TFpList);
    procedure AddUndoAction(AUndoAction: TfrUndoAction);
    procedure DoDrawText(aCanvas: TCanvas; aCaption: string;
      Rect: TRect; Selected, aEnabled: Boolean; Flags: Longint);
    procedure MeasureItem(AMenuItem: TMenuItem; ACanvas: TCanvas;
      var AWidth, AHeight: Integer);
    procedure DrawItem(AMenuItem: TMenuItem; ACanvas: TCanvas;
      ARect: TRect; Selected: Boolean);
    function FindMenuItem(AMenuItem: TMenuItem): TfrMenuItemInfo;
    procedure SetMenuItemBitmap(AMenuItem: TMenuItem; ABtn:TSpeedButton);
    procedure FillMenuItems(MenuItem: TMenuItem);
    procedure DeleteMenuItems(MenuItem: TMenuItem);
    procedure OnActivateApp(Sender: TObject);
    procedure OnDeactivateApp(Sender: TObject);
    procedure GetDefaultSize(var dx, dy: Integer);
    function SelStatus: TfrSelectionStatus;
    procedure UpdScrollbars;
//    procedure InsertDbFields;
    {$ifdef sbod}
    procedure DrawStatusPanel(const ACanvas:TCanvas; const rect:  TRect);
    procedure StatusBar1DrawPanel(StatusBar: TStatusBar; Panel: TStatusPanel;
      const Rect: TRect);
    {$endif}
    procedure DefineExtraPopupSelected(popup: TPopupMenu);
    procedure SelectSameClassClick(Sender: TObject);
    procedure SelectSameClass(View: TfrView);
    function CheckFileModified: Integer;
  private
    FDuplicateCount: Integer;
    FDupDeltaX,FDupDeltaY: Integer;
    FDuplicateList: TFpList;
    procedure ViewsAction(Views: TFpList; TheAction:TViewAction; Data: PtrInt;
      OnlySel:boolean=true; WithUndoAction:boolean=true; WithRedraw:boolean=true);
    procedure ToggleFrames(View: TfrView; Data: PtrInt);
    procedure DuplicateView(View: TfrView; Data: PtrInt);
    procedure ResetDuplicateCount;
    function lrDesignAcceptDrag(const Source: TObject): TControl;
    procedure InplaceEditorMenuClick(Sender: TObject);
  private
    FTabMouseDown:boolean;
    //FTabsPage:TlrTabEditControl;
    procedure TabsEditDragOver(Sender, Source: TObject; X, Y: Integer; State: TDragState; var Accept: Boolean);
    procedure TabsEditDragDrop(Sender, Source: TObject; X, Y: Integer);
    procedure TabsEditMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure TabsEditMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
    procedure TabsEditMouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure ShowIEButton(AView: TfrMemoView);
    procedure HideIEButton;
  protected
    procedure SetModified(AValue: Boolean);override;
    function IniFileName:string;
  public
    constructor Create(aOwner : TComponent); override;
    destructor Destroy; override;
    
    procedure WndProc(var Message: TLMessage); override;
    procedure RegisterObject(ButtonBmp: TBitmap; const ButtonHint: String;
      ButtonTag: Integer; ObjectType:TfrObjectType); override;
    procedure RegisterTool(const MenuCaption: String; ButtonBmp: TBitmap;
      OnClickEvnt: TNotifyEvent); override;
    procedure BeforeChange; override;
    procedure AfterChange; override;
    procedure ShowMemoEditor;
    procedure ShowEditor;
    procedure ShowDialogPgEditor(APage:TfrPageDialog);
    procedure RedrawPage; override;
    procedure OnModify({%H-}sender: TObject);
    function PointsToUnits(x: Integer): Double;  override;
    function UnitsToPoints(x: Double): Integer;  override;
    procedure MoveObjects(dx, dy: Integer; aResize: Boolean);
    procedure UpdateStatus;

    property CurDocName: String read FCurDocName write SetCurDocName;
    property CurPage: Integer read FCurPage write SetCurPage;
    property GridSize: Integer read FGridSize write SetGridSize;
    property ShowGrid: Boolean read FGridShow write SetGridShow;
    property GridAlign: Boolean read FGridAlign write SetGridAlign;
    property ShowGuides: boolean read FGuidesShow write SetGuidesShow;
    property Units: TfrReportUnits read FUnits write SetUnits;
    property GrayedButtons: Boolean read FGrayedButtons write SetGrayedButtons;
  end;

procedure frSetGlyph(aColor: TColor; sb: TSpeedButton; n: Integer);
function frCheckBand(b: TfrBandType): Boolean;

var
  frTemplateDir: String;
  edtScriptFontName : string = '';
  edtScriptFontSize : integer = 0;
  edtUseIE          : boolean = false;

implementation

{$R *.lfm}
{$R bullets.res}
{$R fr_pencil.res}

uses
  LR_Pgopt, LR_GEdit, LR_Templ, LR_Newrp, LR_DsOpt, LR_Const, LR_Pars,
  LR_Prntr, LR_Hilit, LR_Flds, LR_Dopt, LR_Ev_ed, LR_BndEd, LR_VBnd,
  LR_BTyp, LR_Utils, LR_GrpEd, LR_About, LR_IFlds, LR_DBRel,LR_DBSet,
  DB, lr_design_ins_filed, IniFiles, LR_DSet, math;

type
  THackView = class(TfrView)
  end;

function GetUnusedBand: TfrBandType; forward;
procedure SendBandsToDown; forward;
procedure ClearClipBoard; forward;
function Objects: TFpList; forward;
procedure GetRegion; forward;
function TopSelected: Integer; forward;

var
//  FirstInst          : Boolean=True;// First instance
{
  FirstSelected      : TfrView;     // First Selected Object
  SelNum             : Integer;     // number of objects currently selected
  MRFlag             : Boolean;     // several objects was selected
  ObjRepeat          : Boolean;     // was pressed Shift + Insert Object
}
  WasOk              : Boolean;     // was Ok pressed in dialog
  OldRect,OldRect1   : TRect;       // object rect after mouse was clicked
  Busy               : Boolean;     // busy flag. need!
  ShowSizes          : Boolean;
  LastFontName       : String;
  LastFontSize       : Integer;
  LastAdjust         : Integer;
  LastFrameWidth     : Single;
  LastLineWidth      : Single;
  LastFrames         : TfrFrameBorders;
  LastFontStyle      : Word;
  LastFrameColor     : TColor;
  LastFillColor      : TColor;
  LastFontColor      : TColor;
  ClrButton          : TSpeedButton;
  FirstChange        : Boolean;
  ClipRgn            : HRGN;

// globals
  ClipBd             : TFpList;       // clipboard
  GridBitmap         : TBitmap;     // for drawing grid in design time
  ColorLocked        : Boolean;     // true to avoid unwished color change

  frDesignerComp     : TfrDesigner;


{----------------------------------------------------------------------------}
procedure AddRgn(var HR: HRGN; T: TfrView);
var
  tr: HRGN;
begin
  tr := t.GetClipRgn(rtExtended);
  CombineRgn(HR, HR, TR, RGN_OR);
  DeleteObject(TR);
end;

function SelectionBounds(out r: TRect): boolean;
var
  i: Integer;
  t: TfrView;
begin
  r := rect(Maxint, MaxInt, 0 , 0);
  result := false;
  with r do
    for i:=0 to Objects.Count-1 do
    begin
      t := TfrView(Objects[i]);
      if t.Selected then begin
        if t.x<left then left := t.x;
        if t.x+t.dx>right then right := t.x+t.dx;
        if t.y<top then top := t.y;
        if t.y+t.dy>bottom then bottom := t.y+t.dy;
        result := true;
      end;
    end;
end;

{ TAlignGuides }

procedure TAlignGuides.InvalidateHorzGuide;
var
  r: TRect;
begin
  if (px<>nil) then
  begin
    r := Rect(px^-4, 0 , px^+4, fOwner.ClientHeight-1);
    InvalidateRect(fOwner.Handle, @r, false);
  end;
end;

procedure TAlignGuides.InvalidateVertGuide;
var
  r: TRect;
begin
  if (py<>nil) then
  begin
    r := Rect(0, py^-4, fOwner.ClientWidth-1, py^+4);
    InvalidateRect(fOwner.Handle, @r, false);
  end;
end;

procedure TAlignGuides.PaintGuides;
var
  oldStyle: TPenStyle;
  oldColor: TColor;
  oldCosmetic: Boolean;
  i, v, oldWidth: Integer;
  t: TfrView;
begin
  if (px<>nil) or (py<>nil) then
    with fOwner.Canvas do
    begin
      oldStyle := Pen.Style;
      oldColor := Pen.Color;
      oldCosmetic := Pen.Cosmetic;
      oldWidth := Pen.Width;

      // paint object's aligned sides
      // TODO: make an option for the fixed values
      // TODO: a different visualization hint could be having
      //       the view redraw itself in a distinctive color?

      Pen.Cosmetic := true;
      Pen.Style := psSolid;
      Pen.Width := 5;
      Pen.Color := clSkyBlue;

      for i:=0 to Objects.Count-1 do
      begin
        t := TfrView(Objects[i]);
        if px<>nil then
          if t.FindAlignSide(false, px^, v) and (v=px^) then
          begin
            MoveTo(px^, t.y);
            LineTo(px^, t.y + t.dy);
          end;
        if py<>nil then
          if t.FindAlignSide(true, py^, v) and (v=py^) then
          begin
            MoveTo(t.x, py^);
            LineTo(t.x + t.dx, py^);
          end;
      end;

      // paint guides
      // TODO: make an option for the fixed values

      Pen.Style := psDash;
      Pen.Cosmetic := false;
      Pen.Width := 1;

      if px<>nil then
      begin
        Pen.Color := clRed;
        MoveTo(px^, 0);
        LineTo(px^, fOwner.ClientHeight);
      end;
      if py<>nil then
      begin
        Pen.Color := clBlue;
        MoveTo(0, py^);
        LineTo(fOwner.ClientWidth, py^);
      end;

      Pen.Cosmetic := oldCosmetic;
      Pen.Style := oldStyle;
      Pen.Color := oldColor;
      Pen.Width := oldWidth;
    end;
end;

procedure TAlignGuides.ChangeGuide(vert, show: boolean; value: Integer);
begin
  if vert then
  begin
    InvalidateVertGuide;
    if show then begin
      fy := value;
      py := @fy;
      InvalidateVertGuide;
    end else
      py := nil;
  end else
  begin
    InvalidateHorzGuide;
    if show then begin
      fx := value;
      px := @fx;
      InvalidateHorzGuide;
    end else
      px := nil;
  end;
end;

procedure TAlignGuides.Paint;
begin
  PaintGuides;
end;

function TAlignGuides.FindAnyGuide(const vert: boolean; const ax, ay: Integer;
  out snap: Integer; skipSel: boolean; skipTyp: TfrSetOfTyp): boolean;
var
  i, value: Integer;
  t: TfrView;
begin
  result := false;

  // TODO: start looking at the nearest object to (ax, ay)

  if vert then  value := ay
  else          value := ax;

  for i := Objects.Count-1 downto 0 do
  begin
    t := TfrView(Objects[i]);
    if (skipSel and t.Selected) or
       (t.typ in skipTyp) then
         continue;
    if t.FindAlignSide(vert, value, snap) then begin
      result := true;
      break;
    end;
  end;

  if vert then
  begin
    if result and (py<>nil) and (py^=snap) then
      exit;
    ChangeGuide(true, result, snap);
  end else
  begin
    if result and (px<>nil) and (px^=snap) then 
      exit;
    ChangeGuide(false, result, snap);
  end;
end;

constructor TAlignGuides.Create(aOwner: TfrDesignerPage);
begin
  inherited create;
  fOwner := aOwner;
end;

procedure TAlignGuides.FindGuides(ax, ay: Integer; skipSel: boolean;
  skipTyp: TfrSetOfTyp);
var
  dummy: Integer;
begin
  FindAnyGuide(true,  ax, ay, dummy, skipSel, skipTyp);
  FindAnyGuide(false, ax, ay, dummy, skipSel, skipTyp);
end;

function TAlignGuides.SnapToGuide(var ax, ay: Integer): boolean;
var
  newX, newY: Integer;
begin
  newX := ax; newY := ay;
  if (px<>nil) and (Abs(ax-px^)<=lrSnapDistance) then
    newX := px^;
  if (py<>nil) and (Abs(ay-py^)<=lrSnapDistance) then
    newY := py^;
  result := (newX<>ax) or (newY<>ay);
  if result then
  begin
    ax := newX;
    ay := newY;
  end;
end;

function TAlignGuides.SnapSelectionToGuide(const kx, ky: Integer; var ax,
  ay: Integer): boolean;
var
  moveBounds, displayedBounds: TRect;
  snap, deltaX, deltaY, snapDeltaX, snapDeltaY: Integer;
  pts: array[0..2] of TPoint;

  procedure TestPoints(vert: boolean; var delta:integer);
  var
    p: TPoint;
  begin
    delta := 0;
    for p in pts do
    begin
      if FindAnyGuide(vert, p.x, p.y, snap, true, []) then
      begin
        if vert then delta := snap - p.y
        else         delta := snap - p.x;
        result := true;
        break;
      end;
    end;
  end;

begin
  result := false;

  if not fMoveSelectionTracking then begin
    if not SelectionBounds(fSelBounds) then 
      exit;
    HideGuides;
    fMoveSelectionTracking := true;
  end;

  // real bounds
  moveBounds := fSelBounds;
  deltaX := ax - fSelMouse.x;
  deltaY := ay - fSelMouse.y;
  moveBounds.Offset(deltaX, deltaY);

  // find potential snap points
  snapDeltaX := 0;
  snapDeltaY := 0;

  pts[2] := Point(ax, ay);  // could be ommited if less matching guides are needed

  if deltaX<0 then
  begin
    pts[0] := Point(moveBounds.left, ay);
    pts[1] := Point(moveBounds.right, ay);
  end else
  if deltaX>0 then
  begin
    pts[0] := Point(moveBounds.right, ay);
    pts[1] := Point(moveBounds.left, ay);
  end;
  if deltaX<>0 then
    TestPoints(false, snapDeltaX);

  if deltaY<0 then
  begin
    pts[0] := Point(ax, moveBounds.top);
    pts[1] := Point(ax, moveBounds.Bottom);
  end else
  if deltaY>0 then
  begin
    pts[0] := Point(ax, moveBounds.Bottom);
    pts[1] := Point(ax, moveBounds.top);
  end;
  if deltaY<>0 then
    TestPoints(true, snapDeltaY);

  // adjust the moving bounds by the extra snapping if it exists
  moveBounds.Offset(snapDeltaX, snapDeltaY);
  // get displayed bounds
  // TODO: Optmize: should not be necessary to compute displayed bounds for this
  SelectionBounds(displayedBounds);
  // cheating new mouse values
  ax := (ax - kx) + (moveBounds.Left - displayedBounds.Left);
  ay := (ay - ky) + (moveBounds.Top - displayedBounds.Top);

  result := true; // either we snap to something or not, we always succeed
end;

procedure TAlignGuides.HideGuides;
begin
  InvalidateHorzGuide;
  InvalidateVertGuide;
  px := nil;
  py := nil;
  fMoveSelectionTracking := false;
end;

procedure TAlignGuides.ResetMoveSelection(ax, ay: Integer);
begin
  fMoveSelectionTracking := false;
  fSelMouse := Point(ax, ay);
end;

{ TPaintSel }

constructor TPaintSel.Create(AOwner: TfrDesignerPage);
begin
  inherited Create;
  fOwner := AOwner;
  fGreenBullet := TPortableNetworkGraphic.Create;
  fGrayBullet := TPortableNetworkGraphic.Create;
  fGreenBullet.LoadFromResourceName(HInstance, 'bulletgreen');
  fGrayBullet.LoadFromResourceName(HInstance, 'bulletgray');
end;

destructor TPaintSel.Destroy;
begin
  fGrayBullet.Free;
  fGreenBullet.Free;
  inherited Destroy;
end;

procedure TPaintSel.FocusRect(aRect: TRect);
begin
  fFocusRect := aRect;
  Include(fStatus, ptsFocusRect);
  InvalidateFocusRect;
end;

procedure TPaintSel.RemoveFocusRect;
begin
  InvalidateFocusRect;
end;

procedure TPaintSel.InvalidateSelection;
begin
  DrawOrInvalidateSelection(false);
end;

procedure TPaintSel.PaintSelection;
begin
  DrawOrInvalidateSelection(true);
end;

procedure TPaintSel.DrawOrInvalidateSelection(aDraw:boolean);
var
  i: Integer;
  t: TfrView;
  Lst: TfpList;
begin
  Lst := Objects;
  if not Assigned(Lst) then exit;
  for i:=0 to Lst.Count-1 do
  begin
    t := TfrView(Lst[i]);
    if not t.Selected then
      continue;
    DrawOrInvalidateViewHandles(t, aDraw);
  end;
end;

procedure TPaintSel.InvalidateFocusRect;
var
  R: TRect;
begin
  R := fFocusRect;
  fOwner.NormalizeRect(R);
  InvalidateFrame(fOwner.Handle, @R, false, 1);
end;

procedure TPaintSel.DrawOrInvalidateViewHandles(t: TfrView; aDraw:boolean);
var
  Bullet: TGraphic;
  bdx, bdy: Integer;

  procedure UpdateBullet(aBullet: TGraphic);
  begin
    Bullet := aBullet;
    bdx := Bullet.Width div 2;
    bdy := Bullet.Height div 2;
  end;

  procedure DrawPoint(x,y: Integer);
  var
    r: TRect;
  begin
    if aDraw then
      //fOwner.Canvas.EllipseC(x, y, 1, 1)
      fOwner.Canvas.Draw(x-bdx, y-bdy, Bullet)
    else
    begin
      r := rect(x-bdx,y-bdy,x+bdx+1,y+bdy+1);
      InvalidateRect(fOwner.Handle, @r, false);
    end;
  end;

var
  px, py: Integer;
begin

  with t, fOwner.Canvas do
  begin
    if TfrDesignerForm(frDesigner).SelNum>1 then
      UpdateBullet(fGrayBullet)
    else
      UpdateBullet(fGreenBullet);

    px := x + dx div 2;
    py := y + dy div 2;

    DrawPoint(x, y);

    if dx>0 then
      DrawPoint(x + dx, y);

    if dy>0 then
      DrawPoint(x, y + dy);

    if TfrDesignerForm(frDesigner).SelNum = 1 then
    begin
      if px>x then
        DrawPoint(px, y);

      if py>y then
        DrawPoint(x, py);

      if (py>y) and (px>x) then
      begin
        DrawPoint(px, y + dy);
        DrawPoint(x + dx, py);
      end;
    end;

    if (dx>0) and (dy>0) then
    begin
      if aDraw and (Objects.IndexOf(t) = fOwner.RightBottom) then
        UpdateBullet(fGreenBullet);
      DrawPoint(x + dx, y + dy);
    end;

  end;

end;

procedure TPaintSel.Paint;
begin
  if ptsFocusRect in FStatus then
  begin
    fOwner.Canvas.Brush.Style := bsSolid;
    fOwner.Canvas.Pen.Style := psDot;
    fOwner.Canvas.Pen.Color := clSkyBlue;
    fOwner.Canvas.Brush.Style := bsClear;
    fOwner.Canvas.Rectangle(fFocusRect);
    Exclude(Fstatus, ptsFocusRect);
  end;
end;

constructor TfrDesigner.Create(AOwner: TComponent);
begin
  if Assigned(frDesignerComp) then
    raise Exception.Create(sFRDesignerExists);
  inherited Create(AOwner);
  frDesignerComp:=Self;
end;

destructor TfrDesigner.Destroy;
begin
  frDesignerComp:=nil;
  inherited Destroy;
end;

{----------------------------------------------------------------------------}
procedure TfrDesigner.Loaded;
begin
  inherited Loaded;
  frTemplateDir := TemplateDir;
end;

{--------------------------------------------------}
constructor TfrDesignerPage.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  Parent      := AOwner as TWinControl;
  Color       := clWhite;
  EnableEvents;
  fPaintSel   := TPaintSel.Create(self);
  fGuides     := TAlignGuides.Create(self);
end;

destructor TfrDesignerPage.destroy;
begin
  fGuides.Free;
  fPaintSel.Free;
  inherited destroy;
end;

procedure TfrDesignerPage.Init;
begin
  Down := False;
  DFlag:= False;
  RFlag := False;
  Cursor := crDefault;
  CT := ctNone;
end;

procedure TfrDesignerPage.SetPage;
var
  Pgw,Pgh: Integer;
begin
  if not Assigned(FDesigner.Page) then Exit;
  
  FDesigner.panForDlg.Visible:=(FDesigner.Page is TfrPageDialog);
  FDesigner.panel4.Visible   :=not FDesigner.panForDlg.Visible;
  
  if (FDesigner.Page is TfrPageDialog) then
  begin
    Color:=clBtnFace;
    SetBounds(10, 10,TfrPageDialog(FDesigner.Page).Width,TfrPageDialog(FDesigner.Page).Height);
  end
  else
  begin
    Pgw := FDesigner.Page.PrnInfo.Pgw;
    Pgh := FDesigner.Page.PrnInfo.Pgh;
    if Pgw > Parent.Width then
      SetBounds(10, 10, Pgw, Pgh)
    else
      SetBounds((Parent.Width - Pgw) div 2, 10, Pgw, Pgh);
  end;
end;

procedure TfrDesignerPage.Paint;
begin
  fPainting := true;
  Draw(10000, 0);
  fGuides.Paint;
  fPaintSel.Paint;
  fPainting := false;
end;

procedure TfrDesignerPage.WMEraseBkgnd(var Message: TLMEraseBkgnd);
begin
  //do nothing to avoid flicker
end;

procedure TfrDesignerPage.DoContextPopup(MousePos: TPoint; var Handled: Boolean
  );
begin
  Handled := true;
end;

procedure TfrDesignerPage.NormalizeCoord(t: TfrView);
begin
  if t.dx < 0 then
  begin
    t.dx := -t.dx;
    t.x := t.x - t.dx;
  end;
  if t.dy < 0 then
  begin
    t.dy := -t.dy;
    t.y := t.y - t.dy;
  end;
end;

procedure TfrDesignerPage.NormalizeRect(var r: TRect);
var
  i: Integer;
begin
  with r do
  begin
    if Left > Right then
    begin
      i := Left;
      Left := Right;
      Right := i;
    end;
    if Top > Bottom then
    begin
      i := Top;
      Top := Bottom;
      Bottom := i;
    end;
  end;
end;

procedure TfrDesignerPage.DrawHSplitter(Rect: TRect);
begin
  with Canvas do
  begin
    Pen.Mode := pmXor;
    Pen.Color := clSilver;
    Pen.Width := 1;
    MoveTo(Rect.Left, Rect.Top);
    LineTo(Rect.Right, Rect.Bottom);
    Pen.Mode := pmCopy;
  end;
end;

procedure TfrDesignerPage.DrawRectLine(Rect: TRect);
begin
  with Canvas do
  begin
    Pen.Mode := pmNot;
    Pen.Style := psSolid;
    Pen.Width := Round(LastLineWidth);
    with Rect do
    begin
      if Abs(Right - Left) > Abs(Bottom - Top) then
      begin
        MoveTo(Left, Top);
        LineTo(Right, Top);
      end
      else
      begin
        MoveTo(Left, Top);
        LineTo(Left, Bottom);
      end;
    end;
    Pen.Mode := pmCopy;
  end;
end;

procedure DrawRubberRect(Canvas: TCanvas; aRect: TRect; Color: TColor);
  procedure DrawVertLine(X1,Y1,Y2: integer);
  Var Cl : TColor;
  begin
    Cl:=Canvas.Pen.Color;
    try
      if Y2<Y1 then
        while Y2<Y1 do
        begin
          Canvas.Pen.Color:=Color;
          Canvas.MoveTo(X1,Y1);
          Canvas.LineTo(X1,Y1+1);
          //Canvas.Pixels[X1, Y1] := Color;
          dec(Y1, 2);
        end
      else
        while Y1<Y2 do
        begin
          Canvas.Pen.Color:=Color;
          Canvas.MoveTo(X1,Y1);
          Canvas.LineTo(X1,Y1+1);
          //Canvas.Pixels[X1, Y1] := Color;
          inc(Y1, 2);
        end;
    finally
      Canvas.Pen.Color:=cl;
    end;
  end;
  
  procedure DrawHorzLine(X1,Y1,X2: integer);
  Var Cl : TColor;
  begin
    Cl:=Canvas.Pen.Color;
    try
      if X2<X1 then
        while X2<X1 do
        begin
          Canvas.Pen.Color:=Color;
          Canvas.MoveTo(X1,Y1);
          Canvas.LineTo(X1+1,Y1);
          //Canvas.Pixels[X1, Y1] := Color;
          dec(X1, 2);
        end
      else
        while X1<X2 do
        begin
          Canvas.Pen.Color:=Color;
          Canvas.MoveTo(X1,Y1);
          Canvas.LineTo(X1+1,Y1);
          //Canvas.Pixels[X1, Y1] := Color;
          inc(X1, 2);
        end;
    finally
      Canvas.Pen.Color:=cl;
    end;
  end;
begin
  with aRect do
  begin
    DrawHorzLine(Left, Top, Right-1);
    DrawVertLine(Right-1, Top, Bottom-1);
    DrawHorzLine(Right-1, Bottom-1, Left);
    DrawVertLine(Left, Bottom-1, Top);
  end;
end;

procedure TfrDesignerPage.DrawFocusRect(aRect: TRect);
var
  DCIndex: Integer;
begin
  with Canvas do
  begin
    DCIndex := SaveDC(Handle);
    Pen.Mode := pmXor;
    Pen.Color := clWhite;
    //DrawRubberRect(Canvas, aRect, clWhite);
    Pen.Width := 1;
    Pen.Style := psDot;
    MoveTo(aRect.Left, aRect.Top);
    LineTo(aRect.Right, aRect.Top);
    LineTo(aRect.Right, aRect.Bottom);
    LineTo(aRect.left, aRect.Bottom);
    LineTo(aRect.left, aRect.Top);
    //Brush.Style := bsClear;
    //Rectangle(aRect);
    RestoreDC(Handle, DCIndex);
    Pen.Mode := pmCopy;
    fOldFocusRect:=aRect;
  end;
end;

procedure TfrDesignerPage.DrawSelection(t: TfrView);
var
  px, py: Word;
  procedure DrawPoint(x, y: Word);
  begin
    Canvas.EllipseC(x,y,1,1);
    //Canvas.MoveTo(x, y);
    //Canvas.LineTo(x, y);
  end;
begin
  if t.Selected then
  with t, Self.Canvas do
  begin
    Pen.Width := 5;
    Pen.Mode := pmXor;
    Pen.Color := clWhite;
    px := x + dx div 2;
    py := y + dy div 2;

    DrawPoint(x, y); 

    if dx>0 then
      DrawPoint(x + dx, y);

    if dy>0 then
      DrawPoint(x, y + dy);

    if (dx>0) and (dy>0) then
    begin
      if Objects.IndexOf(t) = RightBottom then
        Pen.Color := clTeal;
      DrawPoint(x + dx, y + dy);
    end;

    Pen.Color := clWhite;
    if TfrDesignerForm(frDesigner).SelNum = 1 then
    begin
      if px>x then
        DrawPoint(px, y);

      if py>y then
        DrawPoint(x, py);

      if (py>y) and (px>x) then
      begin
        DrawPoint(px, y + dy);
        DrawPoint(x + dx, py);
      end;
    end;
    Pen.Mode := pmCopy;
    // NOTE: ROP mode under gtk is used not only to draw with pen but
    //       also any other filled graphics, the problem is that brush
    //       handle is not invalidated when pen has changed as result
    //       the ROP mode is not updated and next operation will use
    //       the old XOR mode.
    // TODO: Solve this problem in LCL-gtk, as workaround draw something
    //       using new pen.
    EllipseC(-100,-100,1,1);
  end;
end;

procedure TfrDesignerPage.DrawShape(t: TfrView);
begin
  if t.Selected then
  with t do
    DrawFocusRect(Rect(x, y, x + dx + 1, y + dy + 1));
end;

procedure TfrDesignerPage.DrawDialog(N: Integer; AClipRgn: HRGN);
Var
  Dlg : TfrPageDialog;
  i, iy      : Integer;
  t         : TfrView;
  Objects   : TFpList;
begin
  Dlg:=TfrPageDialog(FDesigner.Page);

  with Canvas do
  begin
    Brush.Color := clGray;
    FillRect(Rect(0,0, Width, Height + 20));
    
    Brush.Color := clBtnFace;
    Brush.Style := bsSolid;
    Rectangle(Rect(0,0,FDesigner.Page.Width-1,FDesigner.Page.Height-1));
    Brush.Color := clBlue;
    Rectangle(Rect(0,0,FDesigner.Page.Width-1,20));
    
    Canvas.TextRect(Rect(0,0,FDesigner.Page.Width-1,20), 1, 5, Dlg.Caption);

  end;


  Objects := FDesigner.Page.Objects;

  for i:=0 to Objects.Count-1 do
  begin
    t := TfrView(Objects[i]);
    t.draw(Canvas);

    iy:=1;
    //Show indicator if script it's not empty
    if t.Script.Count>0 then
    begin
      FDesigner.ImgIndic.Draw(Canvas, t.x+1, t.y+iy, 0);
      iy:=10;
    end;

  end;

  FDesigner.ImageList2.Draw(Canvas, Width-14, Height-14, 1);
  if not Down then
    NPPaintSelection;

end;

procedure TfrDesignerPage.Draw(N: Integer; AClipRgn: HRGN);
var
  i,iy      : Integer;
  t         : TfrView;
  R, R1     : HRGN;
  Objects   : TFpList;

  procedure DrawBackground;
  var
    i, j: Integer;
    Re: TRect;
  begin
    with Canvas do
    begin
      if FDesigner.ShowGrid and (FDesigner.GridSize <> 18) then
      begin
        with GridBitmap.Canvas do
        begin
          Brush.Color := clWhite;
          FillRect(Rect(0, 0, 8, 8));
          Pixels[0, 0] := clBlack;
          if FDesigner.GridSize = 4 then
          begin
            Pixels[4, 0] := clBlack;
            Pixels[0, 4] := clBlack;
            Pixels[4, 4] := clBlack;
          end;
        end;
        Brush.Bitmap := GridBitmap;
      end
      else
      begin
        Brush.Color := clWhite;
        Brush.Style := bsSolid;
        Brush.Bitmap:= nil;
      end;
      
      //FillRgn(Handle, R, Brush.Handle);
      GetRgnBox(R, @Re);
      FillRect(Re);

      if FDesigner.ShowGrid and (FDesigner.GridSize = 18) then
      begin
        i := 0;
        while i < Width do
        begin
          j := 0;
          while j < Height do
          begin
            if RectVisible(Handle, Rect(i, j, i + 1, j + 1)) then
              Pixels[i,j]:=clBlack;
            Inc(j, FDesigner.GridSize);
          end;
          Inc(i, FDesigner.GridSize);
        end;
      end;
      Brush.Style := bsClear;
      Pen.Width := 1;
      Pen.Color := clSilver;
      Pen.Style := psSolid;
      Pen.Mode := pmCopy;
      with FDesigner.Page do
      begin
        if UseMargins then
          Rectangle(LeftMargin, TopMargin, RightMargin, BottomMargin);
        if ColCount > 1 then
        begin
          ColWidth := (RightMargin - LeftMargin - (ColCount-1)*ColGap) div ColCount;
          Pen.Style := psDot;
          j := LeftMargin;
          for i := 1 to ColCount do
          begin
            Rectangle(j, -1, j + ColWidth + 1,  PrnInfo.Pgh + 1);
            Inc(j, ColWidth + ColGap);
          end;
          Pen.Style := psSolid;
        end;
      end;
    end;
  end;

  function ViewIsVisible(t: TfrView): Boolean;
  var
    Rn: HRGN;
  begin
    Rn := t.GetClipRgn(rtNormal);
    Result := CombineRgn(Rn, Rn, AClipRgn, RGN_AND) <> NULLREGION;
    if Result then
      // will this view be really visible?
      Result := CombineRgn(Rn, AClipRgn, R, RGN_AND) <> NULLREGION;
    DeleteObject(Rn);
  end;

begin
  if FDesigner.Page = nil then Exit;

  DocMode := dmDesigning;

  Objects := FDesigner.Page.Objects;

  if FDesigner.Page is TfrPageDialog then
  begin
    DrawDialog(N, AClipRgn);
    Exit;
  end;

  {$IFDEF DebugLR}
  DebugLnEnter('TfrDesignerPage.Draw INIT N=%d AClipRgn=%d',[N,AClipRgn]);
  {$ENDIF}

  if AClipRgn = 0 then
  begin
    with Canvas.ClipRect do
      AClipRgn := CreateRectRgn(Left, Top, Right, Bottom);
  end;

  R:=CreateRectRgn(0, 0, Width, Height);
  for i:=Objects.Count-1 downto 0 do
  begin
    t := TfrView(Objects[i]);
    {$IFDEF DebugLR}
    DebugLn('Draw ',InttoStr(i),' ',t.Name);
    {$ENDIF}
    if i <= N then
    begin
      if t.selected then
        t.draw(canvas)
      else
      if ViewIsVisible(t) then
      begin
        R1 := CreateRectRgn(0, 0, 1, 1);
        CombineRgn(R1, AClipRgn, R, RGN_AND);
        SelectClipRgn(Canvas.Handle, R1);
        DeleteObject(R1);

        t.Draw(Canvas);

        iy:=1;
        //Show indicator if script it's not empty
        if t.Script.Count>0 then
        begin
          FDesigner.ImgIndic.Draw(Canvas, t.x+1, t.y+iy, 0);
          iy:=10;
        end;

        //Show indicator if hightlight it's not empty
        if (t is TfrCustomMemoView) and (Trim(TfrCustomMemoView(t).HighlightStr)<>'') then
          FDesigner.ImgIndic.Draw(Canvas, t.x+1, t.y+iy, 1);
      end;
    end;
    R1 := t.GetClipRgn(rtNormal);
    CombineRgn(R, R, R1, RGN_DIFF);
    DeleteObject(R1);
    SelectClipRgn(Canvas.Handle, R);
  end;

  CombineRgn(R, R, AClipRgn, RGN_AND);

  DrawBackground;

  DeleteObject(R);
  DeleteObject(AClipRgn);
  if AClipRgn=ClipRgn then
    ClipRgn := 0;

  SelectClipRgn(Canvas.Handle, 0);

  if not Down then
    NPPaintSelection;

  {$IFDEF DebugLR}
  DebugLnExit('TfrDesignerPage.Draw DONE');
  {$ENDIF}
end;

procedure TfrDesignerPage.DrawPage(DrawMode: TfrDesignerDrawMode);
var
  i: Integer;
  t: TfrView;
begin
  if DocMode <> dmDesigning then Exit;
  {$ifdef ppaint}
  if DrawMode=dmSelection then
  begin
    if not fPainting then
      fPaintSel.InvalidateSelection;
    exit;
  end;
  {$endif}
  for i:=0 to Objects.Count-1 do
  begin
    t := TfrView(Objects[i]);
    case DrawMode of
      dmAll: t.Draw(Canvas);
      dmSelection: DrawSelection(t);
      dmShape: DrawShape(t);
    end;
  end;
end;

function TfrDesignerPage.FindNearestEdge(var x, y: Integer): Boolean;
var
  i: Integer;
  t: TfrView;
  min: Double;
  p: TPoint;
  
  function DoMin(a: Array of TPoint): Boolean;
  var
    i: Integer;
    d: Double;
  begin
    Result := False;
    for i := Low(a) to High(a) do
    begin
      d := sqrt((x - a[i].x) * (x - a[i].x) + (y - a[i].y) * (y - a[i].y));
      if d < min then
      begin
        min := d;
        p := a[i];
        Result := True;
      end;
    end;
  end;
  
begin
  Result := False;
  min := FDesigner.GridSize;
  p := Point(x, y);
  for i := 0 to Objects.Count - 1 do
  begin
    t := TfrView(Objects[i]);
    if DoMin([Point(t.x, t.y), Point(t.x + t.dx, t.y),
         Point(t.x + t.dx, t.y + t.dy),  Point(t.x, t.y + t.dy)]) then
      Result := True;
  end;

  x := p.x;
  y := p.y;
end;

procedure TfrDesignerPage.RoundCoord(var x, y: Integer);
begin
  with FDesigner do
  begin

    if ShowGuides and fGuides.SnapToGuide(x, y) then
      exit;

    if GridAlign then
    begin
      x := x div GridSize * GridSize;
      y := y div GridSize * GridSize;
    end;
  end;
end;

procedure TfrDesignerPage.GetMultipleSelected;
var
  i, j, k: Integer;
  t: TfrView;
begin
  j := 0; k := 0;
  LeftTop := Point(10000, 10000);
  RightBottom := -1;
  TfrDesignerForm(frDesigner).MRFlag := False;
  if TfrDesignerForm(frDesigner).SelNum > 1 then                  {find right-bottom element}
  begin
    for i := 0 to Objects.Count-1 do
    begin
      t := TfrView(Objects[i]);
      if t.Selected then
      begin
        t.OriginalRect := Rect(t.x, t.y, t.dx, t.dy);
        if (t.x + t.dx > j) or ((t.x + t.dx = j) and (t.y + t.dy > k)) then
        begin
          j := t.x + t.dx;
          k := t.y + t.dy;
          RightBottom := i;
        end;
        if t.x < LeftTop.x then LeftTop.x := t.x;
        if t.y < LeftTop.y then LeftTop.y := t.y;
      end;
    end;
    t := TfrView(Objects[RightBottom]);
    OldRect := Rect(LeftTop.x, LeftTop.y, t.x + t.dx, t.y + t.dy);
    OldRect1 := OldRect;
    TfrDesignerForm(frDesigner).MRFlag := True;
  end;
end;

procedure TfrDesignerPage.CheckGuides;
begin
  if not FDesigner.ShowGuides then
    fGuides.HideGuides;
end;

procedure TfrDesignerPage.MDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
var
  i: Integer;
  f, DontChange, v: Boolean;
  t: TfrView;
  p: TPoint;
begin
  {$IFDEF DebugLR}
  DebugLnEnter('TfrDesignerPage.MDown(X=%d,Y=%d) INIT',[x,y]);
  DebugLn('Down=%s RFlag=%s',[dbgs(Down),dbgs(RFlag)]);
  {$ENDIF}

  // In Lazarus there is no mousedown after doubleclick so
  // just ignore mousedown when doubleclick is coming.
  if ssDouble in Shift then begin
    {$IFDEF DebugLR}
    DebugLnExit('TfrDesignerPage.MDown DONE: doubleclick expected');
    {$ENDIF}
    exit;
  end;

  if (Button = mbRight) and Down and RFlag then
    NPEraseFocusRect;

  RFlag := False;
  NPEraseSelection;
  Down := True;
  DontChange := False;
  if Button = mbLeft then
  begin
    if (ssCtrl in Shift) or (Cursor = crCross) then
    begin
      RFlag := True;
      if Cursor = crCross then
      begin
        NPEraseFocusRect;
        RoundCoord(x, y);
        OldRect1 := OldRect;
      end;
      OldRect := Rect(x, y, x, y);
      FDesigner.Unselect;
      TfrDesignerForm(frDesigner).SelNum := 0;
      RightBottom := -1;
      TfrDesignerForm(frDesigner).MRFlag := False;
      TfrDesignerForm(frDesigner).FirstSelected := nil;
      {$IFDEF DebugLR}
      DebugLnExit('TfrDesignerPage.MDown DONE: Ctrl+Left o cursor=crCross');
      {$ENDIF}
      {$ifdef ppaint}
      NPDrawSelection;
      {$endif}
      Exit;
    end
    else if Cursor = crPencil then
         begin
            with FDesigner do
            begin
              if ShowGuides and fGuides.SnapToGuide(x, y) then
                // x and/or y are at the right value now
              else begin
                if GridAlign then
                begin
                  if not FindNearestEdge(x, y) then
                  begin
                    x := Round(x / GridSize) * GridSize;
                    y := Round(y / GridSize) * GridSize;
                  end;
                end;
              end;
            end;
            OldRect := Rect(x, y, x, y);
            FDesigner.Unselect;
            TfrDesignerForm(frDesigner).SelNum := 0;
            RightBottom := -1;
            TfrDesignerForm(frDesigner).MRFlag := False;
            TfrDesignerForm(frDesigner).FirstSelected := nil;
            LastX := x;
            LastY := y;
            {$IFDEF DebugLR}
            DebugLnExit('TfrDesignerPage.MDown DONE: Left + cursor=crPencil');
            {$ENDIF}
            {$ifdef ppaint}
            NPDrawSelection;
            {$endif}
            Exit;
         end;
  end;

  if FDesigner.ShowGuides then
    fGuides.ResetMoveSelection(x, y);

  if Cursor = crDefault then
  begin
    f := False;
    for i := Objects.Count - 1 downto 0 do
    begin
      t := TfrView(Objects[i]);
      V:=t.PointInView(X,Y);
      {$IFDEF DebugLR}
      DebugLn(t.Name,' PointInView(Rgn, X, Y)=',dbgs(V),' Selected=',dbgs(t.selected));
      {$ENDIF}
      if v then
      begin
        if ssShift in Shift then
        begin
          t.Selected := not t.Selected;
          if t.Selected then
            Inc(TfrDesignerForm(frDesigner).SelNum)
          else
            Dec(TfrDesignerForm(frDesigner).SelNum);
        end
        else
        begin
          if not t.Selected then
          begin
            FDesigner.Unselect;
            TfrDesignerForm(frDesigner).SelNum := 1;
            t.Selected := True;
          end
          else DontChange := True;
        end;

        if TfrDesignerForm(frDesigner).SelNum = 0 then
          TfrDesignerForm(frDesigner).FirstSelected := nil
        else
        if TfrDesignerForm(frDesigner).SelNum = 1 then
          TfrDesignerForm(frDesigner).FirstSelected := t
        else
        if TfrDesignerForm(frDesigner).FirstSelected <> nil then
          if not TfrDesignerForm(frDesigner).FirstSelected.Selected then
            TfrDesignerForm(frDesigner).FirstSelected := nil;
        f := True;
        break;
      end;
    end;
    
    if not f then
    begin
      FDesigner.Unselect;
      TfrDesignerForm(frDesigner).SelNum := 0;
      TfrDesignerForm(frDesigner).FirstSelected := nil;
      if Button = mbLeft then
      begin
        RFlag := True;
        OldRect := Rect(x, y, x, y);
        {$IFDEF DebugLR}
        DebugLnExit('TfrDesignerPage.MDown DONE: Deselection o no selection');
        {$ENDIF}
        {$ifdef ppaint}
        NPDrawSelection;
        {$endif}

        Exit;
      end;
    end;
    
    GetMultipleSelected;
    if not DontChange then
    begin
      FDesigner.SelectionChanged;
      FDesigner.ResetDuplicateCount;
    end;
  end
  else
  if (Cursor = crSizeNWSE) and (FDesigner.Page is TfrPageDialog) then
  begin
    if (X > FDesigner.Page.Width - 10) and (X < FDesigner.Page.Width +10) and (Y > FDesigner.Page.Height - 10) and (Y < FDesigner.Page.Height + 10) then
      fResizeDialog:=true
    else
      fResizeDialog:=false;
    Exit;
  end;

  if TfrDesignerForm(frDesigner).SelNum = 0 then
  begin // reset multiple selection
    RightBottom := -1;
    TfrDesignerForm(frDesigner).MRFlag := False;
  end;
  
  LastX := x;
  LastY := y;
  Moved := False;
  FirstChange := True;
  FirstBandMove := True;
  
  if Button = mbRight then
  begin
    NPDrawSelection;
    Down := False;
    GetCursorPos(p{%H-});
    //FDesigner.Popup1Popup(nil);
    
    FDesigner.Popup1.PopUp(p.X,p.Y);
    //**
    {TrackPopupMenu(FDesigner.Popup1.Handle,
      TPM_LEFTALIGN or TPM_RIGHTBUTTON, p.X, p.Y, 0, FDesigner.Handle, nil);
    }
  end
  else if FDesigner.ShapeMode = smFrame then
           DrawPage(dmShape);
           
  {$IFDEF DebugLR}
  DebugLnExit('TfrDesignerPage.MDown DONE');
  {$ENDIF}
end;

procedure TfrDesignerPage.MUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState;
  X, Y: Integer);
var
  i, k, dx, dy: Integer;
  t: TfrView;
  ObjectInserted: Boolean;
  
  procedure AddObject(ot: Byte);
  begin
{    Objects.Add(frCreateObject(ot, '', FDesigner.Page));
    t := TfrView(Objects.Last);}
    t:=frCreateObject(ot, '', FDesigner.Page);
    if t is TfrCustomMemoView then
      TfrCustomMemoView(t).MonitorFontChanges;
  end;
  
  procedure CreateSection;
  var
    s: String;
  begin
    frBandTypesForm := TfrBandTypesForm.Create(FDesigner);
    try
      ObjectInserted := frBandTypesForm.ShowModal = mrOk;
      if ObjectInserted then
      begin
{        Objects.Add(TfrBandView.Create(FDesigner.Page));
        t := TfrView(Objects.Last);}
        t:=TfrBandView.Create(FDesigner.Page);
        (t as TfrBandView).BandType := frBandTypesForm.SelectedTyp;
        s := frGetBandName(frBandTypesForm.SelectedTyp);
        THackView(t).BaseName := s;
        SendBandsToDown;
      end;
    finally
      frBandTypesForm.Free;
    end;
  end;
  
  procedure CreateSubReport;
  begin
    t:=TfrSubReportView.Create(FDesigner.Page);
    (t as TfrSubReportView).SubPage := CurReport.Pages.Add;
  end;

begin
  {$IFDEF DebugLR}
  DebugLnEnter('TfrDesignerPage.MUp INIT Button=%d Cursor=%d RFlag=%s',
    [ord(Button),Cursor,dbgs(RFlag)]);
  {$ENDIF}
  if Button <> mbLeft then
  begin
    {$IFDEF DebugLR}
    DebugLnExit('TfrDesignerPage.MUp DONE: Button<>mbLeft');
    {$ENDIF}
    Exit;
  end;

  Down := False;
  if FDesigner.ShapeMode = smFrame then
    DrawPage(dmShape);

  //inserting a new object
  if Cursor = crCross then
  begin
    {$IFDEF DebugLR}
    DebugLnEnter('Inserting a New Object INIT');
    {$ENDIF}
    EnableEvents(false);
    Mode := mdSelect;
    if (OldRect.Left = OldRect.Right) and (OldRect.Top = OldRect.Bottom) then
      OldRect := OldRect1
    else
      NPEraseFocusRect;
    NormalizeRect(OldRect);
    RFlag := False;
    ObjectInserted := True;

    if FDesigner.Panel4.Visible then
    begin
      with FDesigner.Panel4 do
      begin
        for i := 0 to ControlCount - 1 do
        begin
          if Controls[i] is TSpeedButton then
          begin
            with Controls[i] as TSpeedButton do
            begin
              if Down then
              begin
                if Tag = gtBand then
                begin
                  if GetUnusedBand <> btNone then
                    CreateSection
                  else
                  begin
                    {$IFDEF DebugLR}
                    DebugLnExit('Inserting a new object DONE: GetUnusedBand=btNone');
                    DebugLnExit('TfrDesignerPage.MUp DONE: Inserting..');
                    {$ENDIF}
                    EnableEvents;
                    Exit;
                  end;
                end
                else if Tag = gtSubReport then
                         CreateSubReport
                else
                begin
                  if Tag >= gtAddIn then
                  begin
                    k := Tag - gtAddIn;
{                    Objects.Add(frCreateObject(gtAddIn, frAddIns[k].ClassRef.ClassName, FDesigner.Page));
                    t := TfrView(Objects.Last);}
                    t:=frCreateObject(gtAddIn, frAddIns[k].ClassRef.ClassName, FDesigner.Page);
                  end
                  else
                    AddObject(Tag);
                end;
                break;
              end;
            end;
          end;
        end;
      end;
    end
    else
    begin
      with FDesigner.panForDlg do
      begin
        for i := 0 to ControlCount - 1 do
        begin
          if Controls[i] is TSpeedButton then
          begin
            with Controls[i] as TSpeedButton do
            begin
              if Down then
              begin
                if Tag >= gtAddIn then
                begin
                  k := Tag - gtAddIn;
{                  Objects.Add(frCreateObject(gtAddIn, frAddIns[k].ClassRef.ClassName, FDesigner.Page));
                  t := TfrView(Objects.Last);}
                  t:=frCreateObject(gtAddIn, frAddIns[k].ClassRef.ClassName, FDesigner.Page);
                end
                else
                  AddObject(Tag);
                break;
              end;
            end;
          end;
        end;
      end;
    end;

    if ObjectInserted then
    begin
      {$IFDEF DebugLR}
      debugLn('Object inserted begin');
      {$ENDIF}
      t.CreateUniqueName;
      t.Canvas:=Canvas;
      
      with OldRect do
      begin
        if (Left = Right) or (Top = Bottom) then
        begin
          dx := 40;
          dy := 40;
          if t is TfrCustomMemoView then
            FDesigner.GetDefaultSize(dx, dy);
          OldRect := Rect(Left, Top, Left + dx, Top + dy);
        end;
      end;
      {$ifdef ppaint}
      NPEraseSelection;
      {$endif}
      FDesigner.Unselect;
      t.x := OldRect.Left;
      t.y := OldRect.Top;
      t.dx := OldRect.Right - OldRect.Left;
      t.dy := OldRect.Bottom - OldRect.Top;
      
      if (t is TfrBandView) and
         (TfrBandView(t).BandType in [btCrossHeader..btCrossFooter]) and
         (t.dx > Width - 10) then
            t.dx := 40;
      t.FrameWidth := LastFrameWidth;
      t.FrameColor := LastFrameColor;
      t.FillColor  := LastFillColor;
      t.Selected   := True;
      
      if t.Typ <> gtBand then
        t.Frames:=LastFrames;
        
      if t is TfrCustomMemoView then
      begin
        with t as TfrCustomMemoView do
        begin
          Font.Name := LastFontName;
          Font.Size := LastFontSize;
          Font.Color := LastFontColor;
          Font.Style := frSetFontStyle(LastFontStyle);
          Adjust := LastAdjust;
        end;
      end
      else
      if t is TfrControl then
        TfrControl(T).UpdateControlPosition;
      
      TfrDesignerForm(frDesigner).SelNum := 1;
      NPRedrawViewCheckBand(t);

      with FDesigner do
      begin
        SelectionChanged;
        AddUndoAction(acInsert);
        if EditAfterInsert then
          ShowEditor;
      end;

      {$IFDEF DebugLR}
      DebugLn('Object inserted end');
      {$ENDIF}
    end;

    if not TfrDesignerForm(frDesigner).ObjRepeat then
    begin
      if FDesigner.Page is TfrPageReport then
        FDesigner.OB1.Down := True
      else
        FDesigner.OB7.Down := True
    end
    else
      NPEraseFocusRect;

    {$IFDEF DebugLR}
    DebugLnExit('Inserting a New Object DONE');
    DebugLnExit('TfrDesignerPage.MUp DONE: Inserting ...');
    {$ENDIF}
    EnableEvents;
    Exit;
  end;
  
  //line drawing
  if Cursor = crPencil then
  begin
    DrawRectLine(OldRect);
    AddObject(gtLine);
    t.CreateUniqueName;
    t.x := OldRect.Left; t.y := OldRect.Top;
    t.dx := OldRect.Right - OldRect.Left;
    t.dy := OldRect.Bottom - OldRect.Top;
    if t.dx < 0 then
    begin
      t.dx := -t.dx; if Abs(t.dx) > Abs(t.dy) then t.x := OldRect.Right;
    end;
    if t.dy < 0 then
    begin
      t.dy := -t.dy; if Abs(t.dy) > Abs(t.dx) then t.y := OldRect.Bottom;
    end;
    t.Selected := True;
    t.BeginUpdate;
    t.FrameWidth := LastLineWidth;
    t.FrameColor := LastFrameColor;
    t.EndUpdate;
    TfrDesignerForm(frDesigner).SelNum := 1;
    NPRedrawViewCheckBand(t);
    FDesigner.SelectionChanged;
    FDesigner.AddUndoAction(acInsert);
    {$IFDEF DebugLR}
    DebugLnExit('TfrDesignerPage.MUp DONE: Line Drawing');
    {$ENDIF}
    Exit;
  end;

  // calculating which objects contains in frame (if user select it with mouse+Ctrl key)
  if RFlag then
  begin
    NPEraseFocusRect;
    RFlag := False;
    NormalizeRect(OldRect);
    for i := 0 to Objects.Count - 1 do
    begin
      t := TfrView(Objects[i]);
      with OldRect do
      begin
        if t.Typ <> gtBand then
        begin
          if not ((t.x > Right) or (t.x + t.dx < Left) or
                  (t.y > Bottom) or (t.y + t.dy < Top)) then
          begin
            t.Selected := True;
            Inc(TfrDesignerForm(frDesigner).SelNum);
          end;
        end;
      end;
    end;
    GetMultipleSelected;
    FDesigner.SelectionChanged;
    NPDrawSelection;
    {$IFDEF DebugLR}
    DebugLnExit('TfrDesignerPage.MUp DONE: objects contained in frame');
    {$ENDIF}
    Exit;
  end;
  
  //splitting
  if Moved and TfrDesignerForm(frDesigner).MRFlag and (Cursor = crHSplit) then
  begin
    with SplitInfo do
    begin
      dx := SplRect.Left - SplX;
      if (View1.dx + dx > 0) and (View2.dx - dx > 0) then
      begin
        Inc(View1.dx, dx);
        Inc(View2.x, dx);
        Dec(View2.dx, dx);
      end;
    end;
    GetMultipleSelected;
    NPDrawLayerObjects(ClipRgn, TopSelected);
    {$IFDEF DebugLR}
    DebugLnExit('TfrDesignerPage.MUp DONE: Splitting');
    {$ENDIF}
    Exit;
  end;

  //resizing several objects
  if Moved and TfrDesignerForm(frDesigner).MRFlag and (Cursor <> crDefault) then
  begin
    {$ifdef ppaint}
    NPDrawSelection;
    DeleteObject(ClipRgn);
    ClipRgn:=0;
    {$else}
    NPDrawLayerObjects(ClipRgn, TopSelected);
    {$endif}
    {$IFDEF DebugLR}
    DebugLnExit('TfrDesignerPage.MUp DONE: resizing several objects');
    {$ENDIF}
    Exit;
  end;
  
  //redrawing all moved or resized objects
  if not Moved then
  begin
    NPDrawSelection;
    {$IFDEF DebugLR}
    DebugLn('redrawing all moved or resized objects');
    {$ENDIF}
  end;

  if (TfrDesignerForm(frDesigner).SelNum >= 1) and Moved then
  begin
    if TfrDesignerForm(frDesigner).SelNum > 1 then
    begin
      //JRA DebugLn('HERE, ClipRgn', Dbgs(ClipRgn));
      {$ifdef ppaint}
      NPDrawSelection;
      if ClipRgn<>0 then
        DeleteObject(ClipRgn);
      ClipRgn:=0;
      {$else}
      NPDrawLayerObjects(ClipRgn, TopSelected);
      {$endif}
      GetMultipleSelected;
      FDesigner.ShowPosition;
    end
    else
    begin
      t := TfrView(Objects[TopSelected]);
      NormalizeCoord(t);
      if Cursor <> crDefault then
        t.Resized;

      if T is TfrControl then
        TfrControl(T).UpdateControlPosition;

      {$ifdef ppaint}
      NPDrawSelection;
      if ClipRgn<>0 then
      begin
        DeleteObject(ClipRgn);
        Invalidate;
      end;
      ClipRgn:=0;
      {$else}
      NPDrawLayerObjects(ClipRgn, TopSelected);
      {$endif}
      FDesigner.ShowPosition;

      if T is TfrMemoView then
        FDesigner.ShowIEButton(T as TfrMemoView);
    end;
  end;

  if (FDesigner.Page is TfrPageDialog) and (fResizeDialog ) then
  begin
    Width:=X;
    Height:=Y;
    fResizeDialog:=false;
    Mode:=mdSelect;
    FDesigner.Page.Width:=X;
    FDesigner.Page.Height:=Y;
    DrawPage(dmAll);
    FDesigner.Modified:=true;
    for i := 0 to Objects.Count - 1 do
    begin
      t := TfrView(Objects[i]);
      if T is TfrControl then
        TfrControl(T).UpdateControlPosition;
    end;
  end;


  Moved := False;
  CT := ctNone;
  {$IFDEF DebugLR}
  DebugLnExit('TfrDesignerPage.MUp DONE');
  {$ENDIF}
end;

procedure TfrDesignerPage.MMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
var
  i, j, kx, ky, w, dx, dy: Integer;
  t, t1, Bnd: TfrView;
  nx, ny, x1, x2, y1, y2: Double;
  hr, hr1,Hr2: HRGN;

  function Cont(px, py, x, y: Integer): Boolean;
  begin
    Result := (x >= px - w) and (x <= px + w + 1) and
      (y >= py - w) and (y <= py + w + 1);
  end;
  
  function GridCheck:Boolean;
  begin
    with FDesigner do
    begin
      Result := (kx >= GridSize) or (kx <= -GridSize) or
                (ky >= GridSize) or (ky <= -GridSize);
      if Result then
      begin
        kx := kx - kx mod GridSize;
        ky := ky - ky mod GridSize;
      end;
    end;
  end;

  function SnapCoords: boolean;
  begin
    result := true;
    if FDesigner.ShowGuides and fGuides.SnapToGuide(x, y) then begin
      kx := x - LastX;
      ky := y - LastY;
    end else begin
      kx := x - LastX;
      ky := y - LastY;
      if FDesigner.GridAlign and not GridCheck then
        result := false;
    end;
  end;

begin
  {$IFDEF DebugLR}
  DebugLnEnter('TfrDesignerPage.MMove(X=%d,Y=%d)  INIT',[x,y]);
  {$ENDIF}
  Moved := True;
  w := 2;

  if FDesigner.ShowGuides then
  begin
    if not down then
      // normal snap guide to any object
      fGuides.FindGuides(x, y)
    else
    if (Cursor = crPencil) or
       (Cursor = crCross) then
      // normal snap to guide for inserting objects or drawing lines
      fGuides.FindGuides(x, y)
    else
    if (TfrDesignerForm(frDesigner).SelNum >= 1) then
      // don't create a guide for the object(s) being resized
      fGuides.FindGuides(x, y, true);
  end;

  if FirstChange and Down and not RFlag then
  begin
    kx := x - LastX;
    ky := y - LastY;
    if not FDesigner.GridAlign or GridCheck then
    begin
      GetRegion; //JRA 1
      FDesigner.AddUndoAction(acEdit);
    end;
  end;

  if not Down then
  begin
    if FDesigner.panForDlg.Visible then
    begin
      if FDesigner.OB7.Down then
      begin
        Mode := mdSelect;
        if (X > FDesigner.Page.Width - 10) and (X < FDesigner.Page.Width + 10) and (Y > FDesigner.Page.Height - 10) and (Y < FDesigner.Page.Height + 10) then
          Cursor := crSizeNWSE
        else
          Cursor := crDefault;


      end
      else
      begin
        Mode := mdInsert;
        if Cursor <> crCross then
        begin
          RoundCoord(x, y);
          kx := Width; ky := 40;
//          if not FDesigner.OB3.Down then
          FDesigner.GetDefaultSize(kx, ky);
          OldRect := Rect(x, y, x + kx, y + ky);
          NPDrawFocusRect;
        end;
        Cursor := crCross;
      end;
    end
    else
    if FDesigner.OB6.Down then
    begin
      Mode := mdSelect;
      Cursor := crPencil;
    end
    else
    if FDesigner.OB1.Down then
    begin
      Mode := mdSelect;
      Cursor := crDefault;
    end
    else
    begin
      Mode := mdInsert;
      if Cursor <> crCross then
      begin
        RoundCoord(x, y);
        kx := Width; ky := 40;
        if not FDesigner.OB3.Down then
          FDesigner.GetDefaultSize(kx, ky);
        OldRect := Rect(x, y, x + kx, y + ky);
        NPDrawFocusRect;
      end;
      Cursor := crCross;
    end;
  end;

  {$IFDEF DebugLR}
  DebugLn('Mode Insert=%s Down=%s',[dbgs(Mode=mdInsert),dbgs(Down)]);
  {$ENDIF}

  if (Mode = mdInsert) and not Down then
  begin
    NPEraseFocusRect;
    RoundCoord(x, y);
    OffsetRect(OldRect, x - OldRect.Left, y - OldRect.Top);
    NPDrawFocusRect;
    ShowSizes := True;
    FDesigner.UpdateStatus;
    ShowSizes := False;
    {$IFDEF DebugLR}
    DebugLnExit('TfrDesignerPage.MMove DONE: Mode Insert and not Down');
    {$ENDIF}
    Exit;
  end;

  //cursor shapes
  if not Down and (TfrDesignerForm(frDesigner).SelNum = 1) and (Mode = mdSelect) and
    not FDesigner.OB6.Down then
  begin
    t := TfrView(Objects[TopSelected]);
    if Cont(t.x, t.y, x, y) or Cont(t.x + t.dx, t.y + t.dy, x, y) then
      Cursor := crSizeNWSE
    else if Cont(t.x + t.dx, t.y, x, y) or Cont(t.x, t.y + t.dy, x, y)then
      Cursor := crSizeNESW
    else if Cont(t.x + t.dx div 2, t.y, x, y) or Cont(t.x + t.dx div 2, t.y + t.dy, x, y) then
      Cursor := crSizeNS
    else if Cont(t.x, t.y + t.dy div 2, x, y) or Cont(t.x + t.dx, t.y + t.dy div 2, x, y) then
      Cursor := crSizeWE
    else
      Cursor := crDefault;
  end;

  if Down then
    FDesigner.HideIEButton;

  //selecting a lot of objects
  if Down and RFlag then
  begin
    NPEraseFocusRect;
    if Cursor = crCross then
      RoundCoord(x, y);
    OldRect := Rect(OldRect.Left, OldRect.Top, x, y);
    NPDrawFocusRect;
    ShowSizes := True;
    if Cursor = crCross then
      FDesigner.UpdateStatus;
    ShowSizes := False;
    {$IFDEF DebugLR}
    DebugLnExit('TfrDesignerPage.MMove DONE: DOWN and RFLag (sel alot of objs)');
    {$ENDIF}
    Exit;
  end;
  
  //line drawing
  if Down and (Cursor = crPencil) then
  begin
    if not SnapCoords then begin
      {$IFDEF DebugLR}
      DebugLnExit('TfrDesignerPage.MMove DONE: not gridcheck and gridalign');
      {$ENDIF}
      Exit;
    end;
    DrawRectLine(OldRect);
    OldRect := Rect(OldRect.Left, OldRect.Top, OldRect.Right + kx, OldRect.Bottom + ky);
    DrawRectLine(OldRect);
    Inc(LastX, kx);
    Inc(LastY, ky);
    {$IFDEF DebugLR}
    DebugLnExit('TfrDesignerPage.MMove DONE: Line drawing');
    {$ENDIF}
    Exit;
  end;

  //check for multiple selected objects - right-bottom corner
  if not Down and (TfrDesignerForm(frDesigner).SelNum > 1) and (Mode = mdSelect) then
  begin
    t := TfrView(Objects[RightBottom]);
    if Cont(t.x + t.dx, t.y + t.dy, x, y) then
      Cursor := crSizeNWSE
  end;
  
  //split checking
  if not Down and (TfrDesignerForm(frDesigner).SelNum > 1) and (Mode = mdSelect) then
  begin
    for i := 0 to Objects.Count-1 do
    begin
      t := TfrView(Objects[i]);
      if (t.Typ <> gtBand) and t.Selected then
        if (x >= t.x) and (x <= t.x + t.dx) and (y >= t.y) and (y <= t.y + t.dy) then
        begin
          for j := 0 to Objects.Count - 1 do
          begin
            t1 := TfrView(Objects[j]);
            if (t1.Typ <> gtBand) and (t1 <> t) and t1.Selected then
              if ((t.x = t1.x + t1.dx) and ((x >= t.x) and (x <= t.x + 2))) or
              ((t1.x = t.x + t.dx) and ((x >= t1.x - 2) and (x <= t.x))) then
              begin
                Cursor := crHSplit;
                with SplitInfo do
                begin
                  SplRect := Rect(x, t.y, x, t.y + t.dy);
                  if t.x = t1.x + t1.dx then
                  begin
                    SplX := t.x;
                    View1 := t1;
                    View2 := t;
                  end
                  else
                  begin
                    SplX := t1.x;
                    View1 := t;
                    View2 := t1;
                  end;
                  SplRect.Left := SplX;
                  SplRect.Right := SplX;
                end;
              end;
          end;
        end;
    end;
  end;
  
  // splitting
  if Down and TfrDesignerForm(frDesigner).MRFlag and (Mode = mdSelect) and (Cursor = crHSplit) then
  begin
    kx := x - LastX;
    ky := 0;
    if FDesigner.GridAlign and not GridCheck then begin
      {$IFDEF DebugLR}
      DebugLnExit('TfrDesignerPage.MMove DONE: Splitting not grid check');
      {$ENDIF}
      Exit;
    end;
    with SplitInfo do
    begin
      DrawHSplitter(SplRect);
      SplRect := Rect(SplRect.Left + kx, SplRect.Top, SplRect.Right + kx, SplRect.Bottom);
      DrawHSplitter(SplRect);
    end;
    Inc(LastX, kx);
    {$IFDEF DebugLR}
    DebugLnExit('TfrDesignerPage.MMove DONE: Splitting');
    {$ENDIF}
    Exit;
  end;
  
  // sizing several objects
  if Down and TfrDesignerForm(frDesigner).MRFlag and (Mode = mdSelect) and (Cursor <> crDefault) then
  begin
    if not SnapCoords then begin
      {$IFDEF DebugLR}
      DebugLnExit('TfrDesignerPage.MMove DONE: sizing seveal, not gridcheck');
      {$ENDIF}
      Exit;
    end;

    if FDesigner.ShapeMode = smFrame then
      DrawPage(dmShape)
    else
    begin
      hr := CreateRectRgn(0, 0, 0, 0);
      hr1 := CreateRectRgn(0, 0, 0, 0);
    end;
    
    OldRect := Rect(OldRect.Left, OldRect.Top, OldRect.Right + kx, OldRect.Bottom + ky);
    nx := (OldRect.Right - OldRect.Left) / (OldRect1.Right - OldRect1.Left);
    ny := (OldRect.Bottom - OldRect.Top) / (OldRect1.Bottom - OldRect1.Top);
    for i := 0 to Objects.Count - 1 do
    begin
      t := TfrView(Objects[i]);
      if (t.Selected) and not (lrrDontSize in T.Restrictions) then
      begin
        if FDesigner.ShapeMode = smAll then
          AddRgn(hr, t);
        x1 := (t.OriginalRect.Left - LeftTop.x) * nx;
        x2 := t.OriginalRect.Right * nx;
        dx := Round(x1 + x2) - (Round(x1) + Round(x2));
        t.x := LeftTop.x + Round(x1);
        t.dx := Round(x2) + dx;

        y1 := (t.OriginalRect.Top - LeftTop.y) * ny;
        y2 := t.OriginalRect.Bottom * ny;
        dy := Round(y1 + y2) - (Round(y1) + Round(y2));
        t.y := LeftTop.y + Round(y1);
        t.dy := Round(y2) + dy;
        if FDesigner.ShapeMode = smAll then
          AddRgn(hr1, t);
      end;
    end;

    if FDesigner.ShapeMode = smFrame then
      DrawPage(dmShape)
    else
    begin
      NPDrawLayerObjects(hr);
      NPDrawLayerObjects(hr1);
    end;
    
    Inc(LastX, kx);
    Inc(LastY, ky);
    FDesigner.UpdateStatus;
    {$IFDEF DebugLR}
    DebugLnExit('TfrDesignerPage.MMove DONE: Sizing several objects');
    {$ENDIF}
    Exit;
  end;
  
  //moving
  if Down and (Mode = mdSelect) and (TfrDesignerForm(frDesigner).SelNum >= 1) and (Cursor = crDefault) then
  begin
    kx := x - LastX;
    ky := y - LastY;
    if FDesigner.ShowGuides and fGuides.SnapSelectionToGuide(kx, ky, x, y) then
    begin
      kx := x - LastX;
      ky := y - LastY;
    end else begin
      if FDesigner.GridAlign and not GridCheck then begin
        {$IFDEF DebugLR}
        DebugLnExit('TfrDesignerPage.MMove DONE: moving');
        {$ENDIF}
        Exit;
      end;
    end;
    if FirstBandMove and (TfrDesignerForm(frDesigner).SelNum = 1) and ((kx <> 0) or (ky <> 0)) and
      not (ssAlt in Shift) then
    begin
      if Assigned(Objects[TopSelected]) and (TFrView(Objects[TopSelected]).Typ = gtBand) then
      begin
        Bnd := TfrView(Objects[TopSelected]);
        for i := 0 to Objects.Count-1 do
        begin
          t := TfrView(Objects[i]);
          if t.Typ <> gtBand then
          begin
          
            if (t.x >= Bnd.x) and (t.x + t.dx <= Bnd.x + Bnd.dx) and
               (t.y >= Bnd.y) and (t.y + t.dy <= Bnd.y + Bnd.dy) then
            begin
              t.Selected := True;
              Inc(TfrDesignerForm(frDesigner).SelNum);
            end;
          end;
        end;
        ColorLocked := True;
        FDesigner.SelectionChanged;
        GetMultipleSelected;
        ColorLocked := False;
      end;
    end;
    
    FirstBandMove := False;

    MoveResize(kx,ky,FDesigner.ShapeMode=smFrame, false);

    Inc(LastX, kx);
    Inc(LastY, ky);
    FDesigner.UpdateStatus;
  end;
{$IFDEF DebugLR}
//  else debugLn('Down=',BoolToStr(Down),' Mode=',IntToStr(Ord(Mode)),' SelNum=',IntToStr(Selnum),' Cursor=',IntToStr(Cursor));
{$ENDIF}

  //resizing
  if Down and (Mode = mdSelect) and (TfrDesignerForm(frDesigner).SelNum = 1) and (Cursor <> crDefault) then
  begin
    if FDesigner.ShowGuides then
      fGuides.SnapToGuide(x, y);
    kx := x - LastX;
    ky := y - LastY;
    if FDesigner.GridAlign and not GridCheck then begin
      {$IFDEF DebugLR}
      DebugLnExit('TfrDesignerPage.MMove DONE: resizing');
      {$ENDIF}
      Exit;
    end;
    
    t := TfrView(Objects[TopSelected]);
    if (lrrDontSize in T.Restrictions) then
      exit;

    if FDesigner.ShapeMode = smFrame then
      DrawPage(dmShape)
    else
      hr:=t.GetClipRgn(rtExtended);
    w := 3;

    if Cursor = crSizeNWSE then
    begin
      if (CT <> ct2) and ((CT = ct1) or Cont(t.x, t.y, LastX, LastY)) then
      begin
        t.x := t.x + kx;
        t.dx := t.dx - kx;
        t.y := t.y + ky;
        t.dy := t.dy - ky;
        CT := ct1;
      end
      else
      begin
        t.dx := t.dx + kx;
        t.dy := t.dy + ky;
        CT := ct2;
      end;
    end;
    
    if Cursor = crSizeNESW then
    begin
      if (CT <> ct4) and ((CT = ct3) or Cont(t.x + t.dx, t.y, LastX, LastY)) then
      begin
        t.y := t.y + ky;
        t.dx := t.dx + kx;
        t.dy := t.dy - ky;
        CT := ct3;
      end
      else
      begin
        t.x := t.x + kx;
        t.dx := t.dx - kx;
        t.dy := t.dy + ky;
        CT := ct4;
      end;
    end;
    
    if Cursor = crSizeWE then
    begin
      if (CT <> ct6) and ((CT = ct5) or Cont(t.x, t.y + t.dy div 2, LastX, LastY)) then
      begin
        t.x := t.x + kx;
        t.dx := t.dx - kx;
        CT := ct5;
      end
      else
      begin
        t.dx := t.dx + kx;
        CT := ct6;
      end;
    end;
    
    if Cursor = crSizeNS then
    begin
      if (CT <> ct8) and ((CT = ct7) or Cont(t.x + t.dx div 2, t.y, LastX, LastY)) then
      begin
        t.y := t.y + ky;
        t.dy := t.dy - ky;
        CT := ct7;
      end
      else
      begin
        t.dy := t.dy + ky;
        CT := ct8;
      end;
    end;
    
    if FDesigner.ShapeMode = smFrame then
    begin
      DrawPage(dmShape);
      {$IFDEF DebugLR}
      DebugLn('MDown resizing 1');
      {$ENDIF}
    end
    else
    begin
      Hr1:=CreateRectRgn(0,0,0,0);
      Hr2:=t.GetClipRgn(rtExtended);
      CombineRgn(hr1, hr, hr2, RGN_OR);
      DeleteObject(Hr2);
      NPDrawLayerObjects(hr1);
      DeleteObject(Hr);
      {$IFDEF DebugLR}
      DebugLn('MDown resizing 2');
      {$ENDIF}
    end;

    Inc(LastX, kx);
    Inc(LastY, ky);
  end;

  if fResizeDialog then
  begin
    Width:=X;
    Height:=Y;
    FDesigner.Page.Width:=X;
    FDesigner.Page.Height:=Y;
    DrawPage(dmAll);
//    Invalidate;
//    DrawDialog(0,0);
  end;

  {$IFDEF DebugLR}
  DebugLnExit('TfrDesignerPage.MMove END');
  {$ENDIF}
end;

procedure TfrDesignerPage.DClick(Sender: TObject);
begin
  {$IFDEF DebugLR}
  DebugLnEnter('TfrDesignerPage.DClick INIT DFlag=%s',[dbgs(DFlag)]);
  {$ENDIF}
  Down := False;
  if TfrDesignerForm(frDesigner).SelNum = 0 then
  begin
    if FDesigner.Page is TfrPageDialog then
      FDesigner.ShowDialogPgEditor(TfrPageDialog(FDesigner.Page))
      //FDesigner.ShowEditor
    else
      FDesigner.PgB3Click(nil);
    DFlag := True;
  end
  else
  if TfrDesignerForm(frDesigner).SelNum = 1 then
  begin
    DFlag := True;
    FDesigner.ShowEditor;
  end;
  {$IFDEF DebugLR}
  DebugLnExit('TfrDesignerPage.DClick DONE DFlag=%s',[dbgs(DFlag)]);
  {$ENDIF}
end;

procedure TfrDesignerPage.MoveResize(Kx, Ky: Integer; UseFrames,AResize: boolean);
var
  hr,hr1: HRGN;
  i: Integer;
  t: TFrView;
begin
  If UseFrames then
    DrawPage(dmShape)
  else
  begin
    hr := CreateRectRgn(0, 0, 0, 0);
    hr1 := CreateRectRgn(0, 0, 0, 0);
  end;

  for i := 0 to Objects.Count - 1 do
  begin
    t := TfrView(Objects[i]);
    if (not t.Selected) or (AResize and (lrrDontSize in T.Restrictions)) or
       ((lrrDontMove in T.Restrictions) and not AResize) then
       continue;

    if FDesigner.ShapeMode = smAll then
      AddRgn(hr, t);
    if aResize then
    begin
      t.dx := t.dx + kx;
      t.dy := t.dy + ky;
    end
    else
    begin
      t.x := t.x + kx;
      t.y := t.y + ky;
    end;
    if FDesigner.ShapeMode = smAll then
      AddRgn(hr1, t);
  end;

  if UseFrames then
    DrawPage(dmShape)
  else
  begin
    CombineRgn(hr, hr, hr1, RGN_OR);
    DeleteObject(hr1);
    NPDrawLayerObjects(hr);
  end;
end;

procedure TfrDesignerPage.EnableEvents(aOk: boolean);
begin
  if aOk then
  begin
    OnMouseDown := @MDown;
    OnMouseUp   := @MUp;
    OnMouseMove := @MMove;
    OnDblClick  := @DClick;
  end else
  begin
    OnMouseDown := nil;
    OnMouseUp   := nil;
    OnMouseMove := nil;
    OnDblClick  := nil;
  end;
end;

procedure TfrDesignerPage.NPDrawFocusRect;
begin
  {$ifdef ppaint}
  fPaintSel.FocusRect(OldRect);
  {$else}
  DrawFocusRect(OldRect);
  {$endif}
end;

procedure TfrDesignerPage.NPEraseFocusRect;
begin
  {$ifdef ppaint}
  fPaintSel.RemoveFocusRect;
  {$else}
  DrawFocusRect(OldRect);
  {$endif}
end;

procedure TfrDesignerPage.NPDrawLayerObjects(Rgn: HRGN; Start:Integer=10000);
{$ifdef ppaint}
var
  R: HRGN;
  t: TfrView;
  i: Integer;
{$endif}
begin
  {$ifdef ppaint}
  if Rgn = 0 then
  begin
    // here just make sure all objects, starting at Start
    // are invalidated so in next paint cycle they are drawn
    Rgn := CreateRectRgn(0, 0, 0, 0);
    for i := Objects.Count-1 downto 0 do
    if i<=Start then begin
      t := TfrView(Objects[i]);
      R := t.GetClipRgn(rtNormal);
      CombineRgn(Rgn, Rgn, R, RGN_OR);
      DeleteObject(R);
    end;
  end;

  InvalidateRgn(Handle, Rgn, false);

  DeleteObject(Rgn);
  if Rgn=ClipRgn then
    ClipRgn := 0;

  SelectClipRgn(Canvas.Handle, 0);

  {$else}
  Draw(Start, Rgn);
  {$endif}
end;

procedure TfrDesignerPage.NPDrawSelection;
begin
  {$ifdef ppaint}
  fPaintSel.InvalidateSelection;
  {$else}
  DrawPage(dmSelection);
  {$endif}
end;

procedure TfrDesignerPage.NPPaintSelection;
begin
  {$ifdef ppaint}
  fPaintSel.PaintSelection;
  {$else}
  DrawPage(dmSelection);
  {$endif}
end;

procedure TfrDesignerPage.NPEraseSelection;
begin
  {$ifdef ppaint}
  fPaintSel.InvalidateSelection;
  {$else}
  DrawPage(dmSelection);
  {$endif}
end;

procedure TfrDesignerPage.NPRedrawViewCheckBand(t: TfrView);
begin
  {$ifdef ppaint}
  if t.typ = gtBand then
    NPDrawLayerObjects(t.GetClipRgn(rtExtended))
  else
    fPaintSel.InvalidateSelection;
  {$else}
  if t.Typ = gtBand then
  begin
    {$IFDEF DebugLR}
    DebugLn('A new band was inserted');
    {$ENDIF}
    Draw(10000, t.GetClipRgn(rtExtended))
  end
  else
  begin
    t.Draw(Canvas);
    DrawSelection(t);
  end;
  {$endif}
end;

procedure TfrDesignerPage.CMMouseLeave(var Message: TLMessage);
begin
  if (Mode = mdInsert) and not Down then
  begin
    NPEraseFocusRect;
    OffsetRect(OldRect, -10000, -10000);
  end;
  fGuides.HideGuides;
end;

{-----------------------------------------------------------------------------}
procedure BDown(SB: TSpeedButton);
begin
  SB.Down := True;
end;

procedure BUp(SB: TSpeedButton);
begin
  SB.Down := False;
end;
{
function EnumFontsProc(var LogFont: TLogFont; var TextMetric: TTextMetric;
  FontType: Integer; Data: Pointer): Integer; stdcall;
begin
  TfrDesignerForm(frDesigner).C2.Items.AddObject(StrPas(LogFont.lfFaceName), TObject(FontType));
  Result := 1;
end;
}

function EnumFontsProc(
  var LogFont: TEnumLogFontEx;
  var {%H-}Metric: TNewTextMetricEx;
  FontType: Longint;
  {%H-}Data: LParam):LongInt; stdcall;
var
  S: String;
  Lst: TStrings;
begin
  s := StrPas(LogFont.elfLogFont.lfFaceName);
  Lst := TStrings(PtrInt(Data));
  Lst.AddObject(S, TObject(PtrInt(FontType)));
  Result := 1;
end;

constructor TfrDesignerForm.Create(aOwner: TComponent);
begin
  inherited Create(aOwner);
  fInBuildPage:=False;
  {$IFDEF STDOI}
  // create the ObjectInspector
  PropHook:= TPropertyEditorHook.Create;
  ObjInsp := TObjectInspector.Create(Self);
  ObjInsp.SetInitialBounds(10,10,220,400);
  ObjInsp.ShowComponentTree := False;
  ObjInsp.ShowFavoritePage := False;
  ObjInsp.PropertyEditorHook := PropHook;
  {$ELSE}
  ObjInsp := TFrObjectInspector.Create(Self);
  ObjInsp.SetModifiedEvent(@OnModify);
  {$ENDIF}
  {$ifdef sbod}
  StatusBar1.Panels[1].Style := psOwnerDraw;
  StatusBar1.OnDrawPanel := @StatusBar1Drawpanel;
  Panel7.Visible := false;
  {$endif}

{  FTabsPage:=TlrTabEditControl((Tab1.Tabs as TTabControlNoteBookStrings).NoteBook);
  FTabsPage.DragMode:=dmManual;
  FTabsPage.OnDragOver:=@TabsEditDragOver;
  FTabsPage.OnDragDrop:=@TabsEditDragDrop;
  FTabsPage.OnMouseDown:=@TabsEditMouseDown;
  FTabsPage.OnMouseMove:=@TabsEditMouseMove;
  FTabsPage.OnMouseUp:=@TabsEditMouseUp;}

  Tab1.DragMode:=dmManual;
  Tab1.OnDragOver:=@TabsEditDragOver;
  Tab1.OnDragDrop:=@TabsEditDragDrop;
  Tab1.OnMouseDown:=@TabsEditMouseDown;
  Tab1.OnMouseMove:=@TabsEditMouseMove;
  Tab1.OnMouseUp:=@TabsEditMouseUp;

end;

destructor TfrDesignerForm.Destroy;
begin
  {$IFDEF EXTOI}
  ObjInsp.Free;
  {$ENDIF}
  {$IFDEF STDOI}
  PropHook.Free;
  {$ENDIF}
  inherited Destroy;
end;

procedure TfrDesignerForm.GetFontList;
var
  DC: HDC;
  Lf: TLogFont;
  SysList: TStringList;
  {$IFDEF USE_PRINTER_FONTS}
  PrnList: TStringList;
  i: Integer;
  j: PtrInt;
  {$ENDIF}
begin
  SysList := TStringList.Create;
  SysList.Duplicates := dupIgnore;
  SysList.Sorted := true;
  try
    DC := GetDC(0);
    try
      Lf.lfFaceName := '';
      Lf.lfCharSet := DEFAULT_CHARSET;
      Lf.lfPitchAndFamily := 0;
      EnumFontFamiliesEx(DC, @Lf, @EnumFontsProc, PtrInt(SysList), 0);
    finally
      ReleaseDC(0, DC);
    end;
    {$IFDEF USE_PRINTER_FONTS}
    if not CurReport.PrintToDefault then
    begin
      PrnList := TStringList.Create;
      PrnList.Duplicates := dupIgnore;
      PrnList.Sorted := true;
      try
        // we could use prn.Printer.Fonts but we would be tied to
        // implementation detail of list.objects[] encoded with fonttype
        // that's why we collect the fonts ourselves here
        //
        EnumFontFamiliesEx(Prn.Printer.Canvas.Handle, @Lf, @EnumFontsProc, PtrInt(PrnList), 0);
        for i:=0 to PrnList.Count-1 do
          if SysList.IndexOf(PrnList[i])<0 then begin
            j := PtrInt(PrnList.Objects[i]) or $100;
            SysList.AddObject(PrnList[i], TObject(PtrInt(j)));
          end;
      finally
        PrnList.Free;
      end;
    end;
    {$ENDIF}
    if (SelNum>0) and (FirstSelected is TfrCustomMemoView) then
    begin
      // font of selected memo has preference, select it
      LastFontname := TfrCustomMemoView(FirstSelected).Font.Name;
      LastFontSize := TfrCustomMemoView(FirstSelected).Font.Size;
    end else
    if SysList.IndexOf(LastFontName)>=0 then
      // last font name remains valid, keep it together with lastFontSize
    else begin
      // setup an initial font name and size
      if SysList.Count>0 then
        LastFontName := SysList[0]
      else
        LastFontName := '';
      if SysList.IndexOf('Arial') <> -1 then
        LastFontName := 'Arial'
      else if SysList.IndexOf('helvetica [urw]')<>-1 then
        LastFontName := 'helvetica [urw]'
      else if SysList.IndexOf('Arial Cyr') <> -1 then
        LastFontName := 'Arial Cyr';
      LastFontSize := 10;
    end;
  finally
    C2.Items.Assign(SysList);
    SysList.Free;
  end;
end;

procedure TfrDesignerForm.FormCreate(Sender: TObject);
var
  i: Integer;
begin
  FGridSize := 4;
  FGridAlign := True;
  FGridShow := False; //True;
  FUnits := TfrReportUnits(0);
  EditAfterInsert := True;
  ShapeMode := TfrShapeMode(1);

  Busy := True;
  FirstTime := True;
//  FirstInstance := FirstInst;

  PageView := TfrDesignerPage.Create(Self{ScrollBox1});
  PageView.Parent := ScrollBox1;
  PageView.FDesigner := Self;
  PageView.PopupMenu := Popup1;
  PageView.ShowHint := True;

  PageView.OnDragDrop:=@ScrollBox1DragDrop;
  PageView.OnDragOver:=@ScrollBox1DragOver;
  IEPopupMenu.Parent:=PageView;

  ColorSelector := TColorSelector.Create(Self);
  ColorSelector.OnColorSelected := @ColorSelected;
  ColorSelector.Hide;

  for i := 0 to frAddInsCount - 1 do
  with frAddIns[i] do
  begin
    if Assigned(frAddIns[i].InitializeProc) then
      frAddIns[i].InitializeProc;
    RegisterObject(ButtonBMP, ButtonHint, Integer(gtAddIn) + i, ObjectType);
  end;

  for i := 0 to frToolsCount - 1 do
    RegisterTool(frTools[i].Caption, frTools[i].ButtonBMP, frTools[i].OnClick);

  EditorForm := TfrEditorForm.Create(nil);

  MenuItems := TFpList.Create;
  ItemWidths := TStringlist.Create;

  IEPopupMenu.Parent:=PageView;
{
  if FirstInstance then
  begin
    //** Application.OnActivate := OnActivateApp;
    //** Application.OnDeactivate := OnDeactivateApp;
  end
  else
  begin
    PgB1.Enabled := False;
    PgB2.Enabled := False;
    N41.Enabled := False;
    N43.Enabled := False;
    N29.Enabled := False;
    N30.Enabled := False;
  end;
  FirstInst := False;
}
  FCaption :=         sFRDesignerFormCapt;
  //Panel1.Caption :=   sFRDesignerFormrect;
  //Panel2.Caption :=   sFRDesignerFormStd;
  //Panel3.Caption :=   sFRDesignerFormText;
  //Panel5.Caption :=   sFRDesignerFormAlign;
  //Panel6.Caption :=   sFRDesignerFormTools;
  FileBtn1.Hint :=    sFRDesignerFormNewRp;
  //FileBtn2.Hint :=    sFRDesignerFormOpenRp;
  FileOpen.Hint:=     sFRDesignerFormOpenRp;
  FileOpen.Caption:=  sFRDesignerForm_Open;

  FileSave.Hint:=        sFRDesignerFormSaveRp;
  FilePreview.Hint :=    sFRDesignerFormPreview;

  edtUndo.Caption :=      sFRDesignerForm_Undo;
  edtUndo.Hint :=         sFRDesignerFormUndo;
  edtRedo.Caption :=      sFRDesignerForm_Redo;
  edtRedo.Hint :=         sFRDesignerFormRedo;

  CutB.Hint :=        sFRDesignerFormCut;
  CopyB.Hint :=       sFRDesignerFormCopy;
  PstB.Hint :=        sFRDesignerFormPast;
  ZB1.Hint :=         sFRDesignerFormBring;
  ZB2.Hint :=         sFRDesignerFormBack;
  SelAllB.Hint :=     sFRDesignerFormSelectAll;
  PgB1.Hint :=        sFRDesignerFormAddPg;
  PgB2.Hint :=        sFRDesignerFormRemovePg;
  PgB3.Hint :=        sFRDesignerFormPgOption;
  GB1.Hint :=         sFRDesignerFormGrid;
  GB2.Hint :=         sFRDesignerFormGridAlign;
  GB3.Hint :=         sFRDesignerFormFitGrid;
  HelpBtn.Hint :=     sPreviewFormHelp;
  ExitB.Caption :=    sFRDesignerFormClose;
  ExitB.Hint :=       sFRDesignerFormCloseDesigner;
  AlB1.Hint :=        sFRDesignerFormLeftAlign;
  AlB2.Hint :=        sFRDesignerFormRightAlign;
  AlB3.Hint :=        sFRDesignerFormCenerAlign;
  AlB4.Hint :=        sFRDesignerFormNormalText;
  AlB5.Hint :=        sFRDesignerFormVertCenter;
  AlB6.Hint :=        sFRDesignerFormTopAlign;
  AlB7.Hint :=        sFRDesignerFormBottomAlign;
  AlB8.Hint :=        sFRDesignerFormWidthAlign;
  FnB1.Hint :=        sFRDesignerFormBold;
  FnB2.Hint :=        sFRDesignerFormItalic;
  FnB3.Hint :=        sFRDesignerFormUnderLine;
  ClB2.Hint :=        sFRDesignerFormFont;
  HlB1.Hint :=        sFRDesignerFormHightLight;
  C3.Hint :=          sFRDesignerFormFontSize;
  C2.Hint :=          sFRDesignerFormFontName;
  FrB1.Hint :=        sFRDesignerFormTopFrame;
  FrB2.Hint :=        sFRDesignerFormleftFrame;
  FrB3.Hint :=        sFRDesignerFormBottomFrame;
  FrB4.Hint :=        sFRDesignerFormRightFrame;
  FrB5.Hint :=        sFRDesignerFormAllFrame;
  FrB6.Hint :=        sFRDesignerFormNoFrame;
  ClB1.Hint :=        sFRDesignerFormBackColor;
  ClB3.Hint :=        sFRDesignerFormFrameColor;
  E1.Hint :=          sFRDesignerFormFrameWidth;
  OB1.Hint :=         sFRDesignerFormSelObj;
  OB2.Hint :=         sFRDesignerFormInsRect;
  OB3.Hint :=         sFRDesignerFormInsBand;
  OB4.Hint :=         sFRDesignerFormInsPict;
  OB5.Hint :=         sFRDesignerFormInsSub;
  OB6.Hint :=         sFRDesignerFormDrawLine;
  Align1.Hint :=      sFRDesignerFormAlignLeftedge;
  Align2.Hint :=      sFRDesignerFormAlignHorzCenter;
  Align3.Hint :=      sFRDesignerFormCenterHWind;
  Align4.Hint :=      sFRDesignerFormSpace;
  Align5.Hint :=      sFRDesignerFormAlignRightEdge;
  Align6.Hint :=      sFRDesignerFormAligneTop;
  Align7.Hint :=      sFRDesignerFormAlignVertCenter;
  Align8.Hint :=      sFRDesignerFormCenterVertWing;
  Align9.Hint :=      sFRDesignerFormSpaceEqVert;
  Align10.Hint :=     sFRDesignerFormAlignBottoms;
  N2.Caption :=       sFRDesignerForm_Cut;
  N1.Caption :=       sFRDesignerForm_Copy;
  N3.Caption :=       sFRDesignerForm_Paste;
  N5.Caption :=       sFRDesignerForm_Delete;
  N16.Caption :=      sFRDesignerForm_SelectAll;
  N6.Caption :=       sFRDesignerForm_Edit;
  FileMenu.Caption := sFRDesignerForm_File;
  N23.Caption :=      sFRDesignerForm_New;
  //N19.Caption :=      sFRDesignerForm_Open;
  //N20.Caption :=      sFRDesignerForm_Save;
  //N17.Caption :=      sFRDesignerForm_SaveAs;
  FileSave.Caption:=   sFRDesignerForm_Save;
  FileSaveAs.Caption:=   sFRDesignerForm_SaveAs;
  FileBeforePrintScript.Caption := sFRDesignerForm_BeforePrintScript;
  N42.Caption :=      sFRDesignerForm_Var;
  N8.Caption :=       sFRDesignerForm_RptOpt;
  N25.Caption :=      sFRDesignerForm_PgOpt;
  N39.Caption :=      sFRDesignerForm_preview;
  N10.Caption :=      sFRDesignerForm_Exit;
  EditMenu.Caption := sFRDesignerForm_Edit2;
  N11.Caption :=      sFRDesignerForm_Cut;
  N12.Caption :=      sFRDesignerForm_Copy;
  N13.Caption :=      sFRDesignerForm_Paste;
  N27.Caption :=      sFRDesignerForm_Delete;
  N28.Caption :=      sFRDesignerForm_SelectAll;
  N36.Caption :=      sFRDesignerForm_Editp;
  N29.Caption :=      sFRDesignerForm_AddPg;
  N30.Caption :=      sFRDesignerForm_RemovePg;
  N32.Caption :=      sFRDesignerForm_Bring;
  N33.Caption :=      sFRDesignerForm_Back;
  ToolMenu.Caption := sFRDesignerForm_Tools;
  N37.Caption :=      sFRDesignerForm_ToolBars;
  MastMenu.Caption := sFRDesignerForm_Tools2;
  N14.Caption :=      sFRDesignerForm_Opts;
  Pan1.Caption :=     sFRDesignerForm_Rect;
  Pan2.Caption :=     sFRDesignerForm_Std;
  Pan3.Caption :=     sFRDesignerForm_Text;
  Pan4.Caption :=     sFRDesignerForm_Obj;
  Pan5.Caption :=     sFRDesignerForm_Insp;
  Pan6.Caption :=     sFRDesignerForm_AlignPalette;
  Pan7.Caption :=     sFRDesignerForm_Tools3;
  MenuItem2.Caption:= sFRDesignerForm_DataInsp;
  N34.Caption :=      sFRDesignerForm_About;
  N22.Caption :=      sFRDesignerForm_Help1;
  N35.Caption :=      sFRDesignerForm_Help2;
  StB1.Hint   :=      sFRDesignerForm_Line;
  //** FnB1.Glyph.Handle := LoadBitmap(hInstance, 'FR_BOLD');
  //** FnB2.Glyph.Handle := LoadBitmap(hInstance, 'FR_ITALIC');
  //** FnB3.Glyph.Handle := LoadBitmap(hInstance, 'FR_UNDRLINE');

  N41.Caption :=      N29.Caption;
  N41.OnClick :=      N29.OnClick;
  N43.Caption :=      N30.Caption;
  N43.OnClick :=      N30.OnClick;
  N44.Caption :=      N25.Caption;
  N44.OnClick :=      N25.OnClick;
end;

procedure TfrDesignerForm.C2GetItems(Sender: TObject);
var
  i: Integer;
begin
  if C2.Items.Count=0 then begin
    Screen.Cursor := crHourglass;
    GetFontList;
    i := C2.Items.IndexOf(LastFontName);
    if i<>-1 then
      C2.ItemIndex := i;
    Screen.Cursor := crDefault;
  end;
end;

procedure TfrDesignerForm.edtRedoExecute(Sender: TObject);
begin
  Undo(@FRedoBuffer);
end;

procedure TfrDesignerForm.edtUndoExecute(Sender: TObject);
begin
  Undo(@FUndoBuffer);
end;

procedure TfrDesignerForm.FileBeforePrintScriptExecute(Sender: TObject);
begin
  //EditorForm.View := nil;
  EditorForm.M2.Lines.Assign(CurReport.Script);
  EditorForm.MemoPanel.Visible:=false;
  EditorForm.CB1.OnClick:=nil;
  EditorForm.CB1.Checked:=true;
  EditorForm.CB1.OnClick:=@EditorForm.CB1Click;
  EditorForm.ScriptPanel.Align:=alClient;
  if EditorForm.ShowEditor(nil) = mrOk then
  begin
    CurReport.Script.Assign(EditorForm.M2.Lines);
  end;
  EditorForm.ScriptPanel.Align:=alBottom;
  EditorForm.MemoPanel.Visible:=true;
end;

procedure TfrDesignerForm.FileOpenExecute(Sender: TObject);
var
  FRepName:string;
begin
  if CheckFileModified=mrCancel then
    exit;


  if Assigned(frDesignerComp) and Assigned(frDesignerComp.FOnLoadReport) then
  begin
    FRepName:='';
    frDesignerComp.FOnLoadReport(CurReport, FRepName);
    FCurDocFileType := dtLazReportForm;
    CurDocName := FRepName;
  end
  else
  with OpenDialog1 do
  begin
    Filter := sFormFile + ' (*.frf)|*.frf|' +
              sLazFormFile + ' (*.lrf)|*.lrf' +
              '';
    if InitialDir='' then
    begin
      InitialDir := FLastOpenDirectory;
      if InitialDir='' then
        InitialDir := FLastSaveDirectory;
      if InitialDir='' then
        InitialDir:=ExtractFilePath(ParamStrUTF8(0));
    end;

    FileName := CurDocName;
    FilterIndex := 2;
    if Execute then
    begin
      ClearUndoBuffer;
      CurDocName := OpenDialog1.FileName;
      case FilterIndex of
        1: // fastreport form format
          begin
            FLastOpenDirectory := ExtractFilePath(CurDocName);
            CurReport.LoadFromFile(CurDocName);
            FCurDocFileType := dtFastReportForm;
          end;
        2: // lasreport form xml format
          begin
            FLastOpenDirectory := ExtractFilePath(CurDocName);
            CurReport.LoadFromXMLFile(CurDocName);
            FCurDocFileType := dtLazReportForm;
          end;
        else
          raise Exception.Create('Unrecognized file format');
      end;
      //FileModified := False;
      Modified := False;
      CurPage := 0; // do all
    end;
  end;
end;

procedure TfrDesignerForm.FilePreviewExecute(Sender: TObject); // preview
var
  TestRepStream:TMemoryStream;
  Rep, SaveR:TfrReport;
  FSaveGetPValue: TGetPValueEvent;
  FSaveFunEvent: TFunctionEvent;

procedure DoClearFormsName;
var
  i:integer;
begin
  for i:=0 to CurReport.Pages.Count - 1 do
    if CurReport.Pages[i] is TfrPageDialog then
      TfrPageDialog(CurReport.Pages[i]).Form.Name:='';
end;

procedure DoResoreFormsName;
var
  i:integer;
begin
  for i:=0 to CurReport.Pages.Count - 1 do
    if CurReport.Pages[i] is TfrPageDialog then
      TfrPageDialog(CurReport.Pages[i]).Form.Name:=TfrPageDialog(CurReport.Pages[i]).Name;
end;
begin
  if CurReport is TfrCompositeReport then Exit;
  Application.ProcessMessages;
  SaveR:=CurReport;
  TestRepStream:=TMemoryStream.Create;
  CurReport.SaveToXMLStream(TestRepStream);
  TestRepStream.Position:=0;

//  DoClearFormsName;
  CurReport:=nil;

  FSaveGetPValue:=frParser.OnGetValue;
  FSaveFunEvent:=frParser.OnFunction;

  Rep:=TfrReport.Create(SaveR.Owner);

  Rep.OnBeginBand:=SaveR.OnBeginBand;
  Rep.OnBeginColumn:=SaveR.OnBeginColumn;
  Rep.OnBeginDoc:=SaveR.OnBeginDoc;
  Rep.OnBeginPage:=SaveR.OnBeginPage;
  Rep.OnDBImageRead:=SaveR.OnDBImageRead;
  Rep.OnEndBand:=SaveR.OnEndBand;
  Rep.OnEndDoc:=SaveR.OnEndDoc;
  Rep.OnEndPage:=SaveR.OnEndPage;
  Rep.OnEnterRect:=SaveR.OnEnterRect;
  Rep.OnExportFilterSetup:=SaveR.OnExportFilterSetup;
  Rep.OnGetValue:=SaveR.OnGetValue;
  Rep.OnManualBuild:=SaveR.OnManualBuild;
  Rep.OnMouseOverObject:=SaveR.OnMouseOverObject;
  Rep.OnObjectClick:=SaveR.OnObjectClick;
  Rep.OnPrintColumn:=SaveR.OnPrintColumn;
  Rep.OnProgress:=SaveR.OnProgress;
  Rep.OnUserFunction:=SaveR.OnUserFunction;

  try
    Rep.LoadFromXMLStream(TestRepStream);
    Rep.FileName:=SaveR.FileName;
    Rep.ShowReport;
    FreeAndNil(Rep)
  except
    on E:Exception do
    begin
      ShowMessage(E.Message);
      if Assigned(Rep) then
        FreeAndNil(Rep)
    end;
  end;
  TestRepStream.Free;
  CurReport:=SaveR;
  CurPage := 0;
  frParser.OnGetValue := FSaveGetPValue;
  frParser.OnFunction := FSaveFunEvent;
//  DoResoreFormsName;
end;

procedure TfrDesignerForm.FileSaveAsExecute(Sender: TObject);
var
  s: String;
begin
  WasOk := False;
  if Assigned(frDesignerComp) and Assigned(frDesignerComp.FOnSaveReport) then
  begin
    S:='';
    frDesignerComp.FOnSaveReport(CurReport, S, true, WasOk);
    if WasOk then
    begin
      CurDocName:=S;
      Modified:=false;
    end;
  end
  else
  begin
    with SaveDialog1 do
    begin
      Filter := sFormFile + ' (*.frf)|*.frf|' +
                  sTemplFile + ' (*.frt)|*.frt|' +
                  sLazFormFile + ' (*.lrf)|*.lrf|' +
                  sLazTemplateFile + ' (*.lrt)|*.lrt';

      if InitialDir='' then
      begin
        InitialDir := FLastSaveDirectory;
        if InitialDir='' then
          InitialDir := FLastOpenDirectory;
        if InitialDir='' then
          InitialDir:=ExtractFilePath(ParamStrUTF8(0));
      end;
      FileName := CurDocName;
      FilterIndex := 3;
      if Execute then
      begin
        FLastSaveDirectory := ExtractFilePath(Filename);
        FCurDocFileType := FilterIndex;
      end;
      case FCurDocFileType of
        dtFastReportForm:
          begin
                s := ChangeFileExt(FileName, '.frf');
                CurReport.SaveToFile(s);
                CurDocName := s;
                WasOk := True;
          end;
        dtFastReportTemplate,
        dtLazReportTemplate:
              begin
                if FCurDocFileType = dtLazReportTemplate then
                  s := ExtractFileName(ChangeFileExt(FileName, '.lrt'))
                else
                  s := ExtractFileName(ChangeFileExt(FileName, '.frt'));
                if frTemplateDir <> '' then
                  s := AppendPathDelim(frTemplateDir) + s;
                frTemplNewForm := TfrTemplNewForm.Create(nil);
                if frTemplNewForm.ShowModal = mrOk then
                begin
                  if frTemplateDir<>'' then
                  begin
                    if not DirectoryExistsUTF8(frTemplateDir) then begin
                      if not ForceDirectoriesUTF8(frTemplateDir) then begin
                        ShowMessage(sFrDesignerFormUnableToCreateTemplateDir);
                        exit;
                      end;
                    end;
                  end;
                  if FCurDocFileType = dtLazReportTemplate then
                    CurReport.SaveTemplateXML(s, frTemplNewForm.Memo1.Lines, frTemplNewForm.Image1.Picture.Bitmap)
                  else
                    CurReport.SaveTemplate(s, frTemplNewForm.Memo1.Lines, frTemplNewForm.Image1.Picture.Bitmap);
                  WasOk := True;
                end;
                frTemplNewForm.Free;
              end;
        dtLazReportForm: // lasreport form xml format
              begin
                s := ChangeFileExt(FileName, '.lrf');
                CurReport.SaveToXMLFile(s);
                CurDocName := s;
                WasOk := True;
              end;
      end;
    end;
  end;
end;

procedure TfrDesignerForm.FileSaveExecute(Sender: TObject);
var
  S:string;
  F:boolean;
begin
  if CurDocName <> sUntitled then
  begin
    if Assigned(frDesignerComp) and Assigned(frDesignerComp.FOnSaveReport) then
    begin
      S:=CurDocName;
      F:=false;
      frDesignerComp.FOnSaveReport(CurReport, S, false, F);
      if F then
      begin
        CurDocName:=S;
        Modified := False;
      end;
    end
    else
    begin
      if FCurDocFileType=dtLazReportForm then
        CurReport.SaveToXMLFile(curDocName)
      else
        CurReport.SaveToFile(CurDocName);
      Modified := False;
    end;
  end
  else
    FileSaveAs.Execute;
end;

procedure TfrDesignerForm.acDuplicateExecute(Sender: TObject);
begin
  DuplicateSelection;
end;

procedure TfrDesignerForm.acToggleFramesExecute(Sender: TObject);
begin
  if DelEnabled then
    ViewsAction(nil, @ToggleFrames, -1);
end;

procedure TfrDesignerForm.btnGuidesClick(Sender: TObject);
begin
  ShowGuides := btnGuides.Down;
end;

procedure TfrDesignerForm.FormShow(Sender: TObject);
var
  CursorImage: TCursorImage;
begin
  CursorImage := TCursorImage.Create;
  try
    CursorImage.LoadFromResourceName(hInstance, 'FR_PENCIL');
    Screen.Cursors[crPencil] := CursorImage.ReleaseHandle;
  finally
    CursorImage.Free;
  end;    
  {$ifndef sbod}
  Panel7.Hide;
  {$endif}
  if FirstTime then
    SetMenuBitmaps;
  FirstTime := False;
//  FileBtn1.Enabled := FirstInstance;
  FilePreview.Enabled := {FirstInstance and }not (CurReport is TfrCompositeReport);
{  N23.Enabled := FirstInstance;
  OB3.Enabled := FirstInstance;
  OB5.Enabled := FirstInstance;}

  ClearUndoBuffer;
  ClearRedoBuffer;
  Modified := False;
  //FileModified := False;
  Busy := True;
  DocMode := dmDesigning;
  
  if C2.Items.Count=0 then
    GetFontList;

  LastFontSize := 10;
  {$IFDEF MSWINDOWS}
  LastFontName := 'Arial';
  {$ELSE}
  LastFontName := 'helvetica [urw]';
  {$ENDIF}

  //** C2.Perform(CB_SETDROPPEDWIDTH, 170, 0);
  CurPage := 0; // this cause page sizing
  CurDocName := CurReport.FileName;
  Unselect;

  PageView.Init;
  EnableControls;

  BDown(OB1);
  
  ColorLocked:=True;
  frSetGlyph(clNone, ClB1, 1);
  frSetGlyph(clNone, ClB2, 0);
  frSetGlyph(clNone, ClB3, 2);
  ColorLocked:=False;

  ColorSelector.Hide;

  LinePanel.Hide;

  ShowPosition;
  RestoreState;
  FormResize(nil);
end;

procedure TfrDesignerForm.FormHide(Sender: TObject);
begin
  ClearUndoBuffer;
  ClearRedoBuffer;
  SaveState;

  if CurReport<>nil then
    CurReport.FileName := CurDocName;
end;

procedure TfrDesignerForm.FormDestroy(Sender: TObject);
var
  i: Integer;
begin
  for i := 0 to MenuItems.Count - 1 do
    TfrMenuItemInfo(MenuItems[i]).Free;
  MenuItems.Free;
  ItemWidths.Free;
  PageView.Free;
  ColorSelector.Free;
  EditorForm.Free;
end;

procedure TfrDesignerForm.FormResize(Sender: TObject);
begin
  if csDestroying in ComponentState then Exit;

  //{$IFDEF WIN32}
  //if FirstTime then
  //  self.OnShow(self);
  //{$ENDIF}
    
  with ScrollBox1 do
  begin
    HorzScrollBar.Position := 0;
    VertScrollBar.Position := 0;
  end;
  if PageView<>nil then
    PageView.SetPage;
  StatusBar1.Top:=Height-StatusBar1.Height-3;
  {$ifndef sbod}
  Panel7.Top := StatusBar1.Top + 3;
  Panel7.Show;
  {$endif}
  UpdScrollbars;
end;

//**
{
procedure TfrDesignerForm.WMGetMinMaxInfo(var Msg: TWMGetMinMaxInfo);
begin // for best view - not actual in Win98 :(
  with Msg.MinMaxInfo^ do
  begin
    ptMaxSize.x := Screen.Width;
    ptMaxSize.y := Screen.Height;
    ptMaxPosition.x := 0;
    ptMaxPosition.y := 0;
  end;
end;
}
procedure TfrDesignerForm.SetCurPage(Value: Integer);
begin // setting curpage and do all manipulation
  fInBuildPage:=True;
  try
    FCurPage := Value;
    Page := CurReport.Pages[CurPage];
    ScrollBox1.VertScrollBar.Position := 0;
    ScrollBox1.HorzScrollBar.Position := 0;
    PageView.SetPage;
    SetPageTitles;
    Tab1.TabIndex := Value;
    ResetSelection;
    SendBandsToDown;
    PageView.Invalidate;
    UpdScrollbars;
  finally
    fInBuildPage:=False;
  end;
end;

procedure TfrDesignerForm.SetGridSize(Value: Integer);
begin
  if FGridSize = Value then Exit;
  FGridSize := Value;
  PageView.Invalidate;
end;

procedure TfrDesignerForm.SetGridShow(Value: Boolean);
begin
  if FGridShow = Value then Exit;
  FGridShow:= Value;
  GB1.Down := Value;
  PageView.Invalidate;
end;

procedure TfrDesignerForm.SetGridAlign(Value: Boolean);
begin
  if FGridAlign = Value then Exit;
  GB2.Down := Value;
  FGridAlign := Value;
end;

procedure TfrDesignerForm.SetGuidesShow(AValue: boolean);
begin
  if FGuidesShow = AValue then Exit;
  FGuidesShow := AValue;
  btnGuides.Down := AValue;
  PageView.CheckGuides;
end;

procedure TfrDesignerForm.SetUnits(Value: TfrReportUnits);
var
  s: String;
begin
  FUnits := Value;
  case Value of
    ruPixels: s := sPixels;
    ruMM:     s := sMM;
    ruInches: s := sInches;
  end;
  StatusBar1.Panels[0].Text := s;
  ShowPosition;
end;

procedure TfrDesignerForm.SetGrayedButtons(Value: Boolean);
  procedure DoButtons(t: Array of TControl);
  var
    i, j: Integer;
    c: TWinControl;
    c1: TControl;
  begin
    for i := Low(t) to High(t) do
    begin
      c := TWinControl(t[i]);
      for j := 0 to c.ControlCount - 1 do
      begin
        c1 := c.Controls[j];
        if c1 is TSpeedButton then
          TSpeedButton(c1).Enabled := FGrayedButtons; //** GrayedInactive := FGrayedButtons;
      end;
    end;
  end;
begin
  FGrayedButtons := Value;
  DoButtons([Panel1, Panel2, Panel3, Panel4, Panel5, Panel6]);
end;

procedure TfrDesignerForm.SetCurDocName(Value: String);
begin
  FCurDocName := Value;
//  if FirstInstance then
    Caption := FCaption + ' - ' + ExtractFileName(Value)
//  else
//    Caption := FCaption;
end;

procedure TfrDesignerForm.RegisterObject(ButtonBmp: TBitmap;
  const ButtonHint: String; ButtonTag: Integer; ObjectType: TfrObjectType);
var
  b: TSpeedButton;
begin
  b := TSpeedButton.Create(Self);
  with b do
  begin
    Glyph  := ButtonBmp;
    Hint   := ButtonHint;
    Flat   := True;
    GroupIndex := 1;
    Align:=alTop;
    SetBounds(1000, 1000, 22, 22);
    Visible:=True;
    Tag := ButtonTag;
    if ObjectType = otlReportView then
    begin
      OnMouseDown := @OB2MouseDown;
      Parent := Panel4;
    end
    else
    begin
      OnMouseDown := @OB2MouseDown;
      Parent := panForDlg;
    end;
  end;
end;

procedure TfrDesignerForm.RegisterTool(const MenuCaption: String; ButtonBmp: TBitmap;
  OnClickEvnt: TNotifyEvent);
var
  m: TMenuItem;
  b: TSpeedButton;
  w:integer;
  i: Integer;
begin
  m := TMenuItem.Create(MastMenu);
  m.Caption := MenuCaption;
  m.OnClick := OnClickEvnt;
  MastMenu.Enabled := True;
  MastMenu.Add(m);
  M.Bitmap.Assign(ButtonBmp);
  Panel6.Height := 26;
  Panel6.Width := 26;

  W:=0;
  for i:=0 to Panel6.ControlCount-1 do
    if Panel6.Controls[i] is TSpeedButton then
    begin
      W:=W + Panel6.Controls[i].Width;
    end;

  b := TSpeedButton.Create(Self);

  with b do
  begin
    Parent := Panel6;
    Glyph := ButtonBmp;
    Hint := MenuCaption;
    Flat := True;
    Align:=alLeft;
//    Align:=alTop;
    SetBounds(W, 1, 22, 22);
    Visible:=True;
    ShowHint:=True;
    Tag := 36;
  end;
  b.OnClick := OnClickEvnt;

  if Panel6.Width < (B.Left + B.Width) then
    Panel6.Width:=W + B.Width + 4;
end;

procedure TfrDesignerForm.AddPage(ClName : string);
begin
  fInBuildPage:=True;
  try
    CurReport.Pages.Add(ClName);

    Page := CurReport.Pages[CurReport.Pages.Count - 1];
    if Page is TfrPageReport then
       PgB3Click(nil)
    else
       WasOk:=True;

    if WasOk then
    begin
      Modified := True;
      CurPage := CurReport.Pages.Count - 1
    end
    else
    begin
      CurReport.Pages.Delete(CurReport.Pages.Count - 1);
      CurPage := CurPage;
    end;
  finally
    fInBuildPage:=False;
  end;
end;

procedure TfrDesignerForm.RemovePage(n: Integer);

procedure AdjustSubReports(APage:TfrPage);
var
  i, j: Integer;
  t: TfrView;
begin
  for i := 0 to CurReport.Pages.Count - 1 do
  begin
    j := 0;
    while j < CurReport.Pages[i].Objects.Count do
    begin
      t := TfrView(CurReport.Pages[i].Objects[j]);
      if (T is TfrSubReportView) and (TfrSubReportView(t).SubPage = APage) then
      begin
        CurReport.Pages[i].Delete(j);
        Dec(j);
      end;
      Inc(j);
    end;
  end;
end;

begin
  fInBuildPage:=True;
  try
    Modified := True;
    with CurReport do
    begin
      if (n >= 0) and (n < Pages.Count) then
        if Pages.Count = 1 then
          Pages[n].Clear
        else
        begin
          AdjustSubReports(Pages[n]);
          CurReport.Pages.Delete(n);
          Tab1.Tabs.Delete(n);
          Tab1.TabIndex := 0;
          CurPage := 0;
        end;
    end;
    ClearUndoBuffer;
    ClearRedoBuffer;
  finally
    fInBuildPage:=False;
  end;
end;

procedure TfrDesignerForm.SetPageTitles;
var
  i: Integer;
  s: String;
  
function IsSubreport(PageN: Integer): Boolean;
var
  i, j: Integer;
  t: TfrView;
begin
  Result := False;
  for i := 0 to CurReport.Pages.Count - 1 do
    for j := 0 to CurReport.Pages[i].Objects.Count - 1 do
    begin
      t := TfrView(CurReport.Pages[i].Objects[j]);
      if (T is TfrSubReportView) and (TfrSubReportView(t).SubPage = CurReport.Pages[PageN]) then
      begin
        s := t.Name;
        Result := True;
        Exit;
      end;
    end;
end;
  
begin
  if Tab1.Tabs.Count = CurReport.Pages.Count then
  begin
   for i := 0 to Tab1.Tabs.Count - 1 do
   begin
     if not IsSubreport(i) then
       s := sPg + IntToStr(i + 1);
     if Tab1.Tabs[i] <> s then
       Tab1.Tabs[i] := s;
   end;
  end
  else
  begin
    Tab1.Tabs.Clear;
    for i := 0 to CurReport.Pages.Count - 1 do
    begin
      if not IsSubreport(i) then
        s := sPg + IntToStr(i + 1);
      Tab1.Tabs.Add(s);
    end;
  end;
end;

procedure TfrDesignerForm.CutToClipboard;
var
  i: Integer;
  T: TfrView;
begin
  ClearClipBoard;
  for i := 0 to Objects.Count - 1 do
  begin
    t := TfrView(Objects[i]);
    if (t.Selected) and not (lrrDontDelete in T.Restrictions) and not (doChildComponent in T.DesignOptions) then
    begin
//      ClipBd.Add(frCreateObject(t.Typ, t.ClassName, Page));
      ClipBd.Add(frCreateObject(t.Typ, t.ClassName, nil));
      TfrView(ClipBd.Last).Assign(t);
    end;
  end;
  for i := Objects.Count - 1 downto 0 do
  begin
    t := TfrView(Objects[i]);
    if t.Selected and not (lrrDontDelete in T.Restrictions) and not (doChildComponent in T.DesignOptions) then
      Page.Delete(i);
  end;
  SelNum := 0;
  PageView.Invalidate;
end;

procedure TfrDesignerForm.CopyToClipboard;
var
  i: Integer;
  t: TfrView;
begin
  ClearClipBoard;
  for i := 0 to Objects.Count - 1 do
  begin
    t := TfrView(Objects[i]);
    if t.Selected and not (doChildComponent in T.DesignOptions)  then
    begin
      ClipBd.Add(frCreateObject(t.Typ, t.ClassName, nil));
      TfrView(ClipBd.Last).Assign(t);
    end;
  end;
end;

procedure TfrDesignerForm.SelectAll;
var
  i: Integer;
begin
  SelNum := 0;
  for i := 0 to Objects.Count - 1 do
  begin
    TfrView(Objects[i]).Selected := True;
    Inc(SelNum);
  end;
end;

procedure TfrDesignerForm.Unselect;
var
  i: Integer;
begin
  SelNum := 0;
  for i := 0 to Objects.Count - 1 do
    TfrView(Objects[i]).Selected := False;
end;

procedure TfrDesignerForm.ResetSelection;
begin
  Unselect;
  EnableControls;
  ShowPosition;
end;

function TfrDesignerForm.PointsToUnits(x: Integer): Double;
begin
  Result := x;
  case FUnits of
    ruMM: Result := x / 18 * 5;
    ruInches: Result := x / 18 * 5 / 25.4;
  end;
end;

function TfrDesignerForm.UnitsToPoints(x: Double): Integer;
begin
  Result := Round(x);
  case FUnits of
    ruMM: Result := Round(x / 5 * 18);
    ruInches: Result := Round(x * 25.4 / 5 * 18);
  end;
end;

procedure TfrDesignerForm.RedrawPage;
begin
  PageView.NPDrawLayerObjects(0);
end;

procedure TfrDesignerForm.OnModify(sender: TObject);
begin
  Modified:=true;
  SelectionChanged;
end;

procedure TfrDesignerForm.FormKeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
var
  StepX, StepY: Integer;
  i, tx, ty, tx1, ty1, d, d1: Integer;
  t, t1: TfrView;

  procedure CheckStepFactor(var pStep: integer; aValue: integer);
  begin
    if (ssAlt in Shift) or (Shift = [ssShift,ssCtrl]) then
      pStep := aValue * 10
    else
      pStep := aValue;
  end;

  procedure CheckPastePoint;
  var
    P: TPoint;
  begin
    P := PageView.ScreenToClient(Mouse.CursorPos);
    if PtInRect(PageView.ClientRect, p) then
      FReportPopupPoint := p;
  end;

begin
  {$IFNDEF EXTOI}
  if (ActiveControl<>nil) and (ActiveControl.Parent=ObjInsp.fPropertyGrid) then
    exit;
  {$ENDIF}
  StepX := 0; StepY := 0;
  if (Key=VK_F11) then
    ObjInsp.Visible:=not ObjInsp.Visible;

  if (Key = VK_RETURN) and (ActiveControl = C3) then
  begin
    Key := 0;
    DoClick(C3);
  end;
  if (Key = VK_RETURN) and (ActiveControl = E1) then
  begin
    Key := 0;
    DoClick(E1);
  end;
  if (Key = VK_DELETE) and DelEnabled then
  begin
    DeleteObjects;
    Key := 0;
  end;
  if (Key = VK_RETURN) and EditEnabled then
  begin
    if ssCtrl in Shift then
      ShowMemoEditor
    else
      ShowEditor;
  end;
  if (Chr(Key) in ['1'..'9']) and (ssCtrl in Shift) and DelEnabled then
  begin
    E1.Text := Chr(Key);
    DoClick(E1);
    Key := 0;
  end;
  if (Chr(Key) = 'G') and (ssCtrl in Shift) then
  begin
    ShowGrid := not ShowGrid;
    Key := 0;
  end;
  if (Chr(Key) = 'B') and (ssCtrl in Shift) then
  begin
    GridAlign := not GridAlign;
    Key := 0;
  end;
  if (Chr(Key) = 'V') and (ssCtrl in Shift) and PasteEnabled then
    CheckPastePoint;

  if CutEnabled then
    if (Key = VK_DELETE) and (ssShift in Shift) then CutBClick(Self);
  if CopyEnabled then
    if (Key = VK_INSERT) and (ssCtrl in Shift) then CopyBClick(Self);
  if PasteEnabled then
    if (Key = VK_INSERT) and (ssShift in Shift) then PstBClick(Self);
    
  if Key = VK_PRIOR then
    with ScrollBox1.VertScrollBar do
    begin
      Position := Position - 200;
      Key := 0;
    end;
  if Key = VK_NEXT then
    with ScrollBox1.VertScrollBar do
    begin
      Position := Position + 200;
      Key := 0;
    end;
  if SelNum > 0 then
  begin
    if Key = vk_Up then CheckStepFactor(StepY, -1)
    else if Key = vk_Down then CheckStepFactor(StepY, 1)
    else if Key = vk_Left then CheckStepFactor(StepX, -1)
    else if Key = vk_Right then CheckStepFactor(StepX, 1);
    if (StepX <> 0) or (StepY <> 0) then
    begin
      if ssCtrl in Shift then
        MoveObjects(StepX, StepY, False)
      else if ssShift in Shift then
        MoveObjects(StepX, StepY, True)
      else if SelNum = 1 then
      begin
        t := TfrView(Objects[TopSelected]);
        tx := t.x; ty := t.y; tx1 := t.x + t.dx; ty1 := t.y + t.dy;
        d := 10000; t1 := nil;
        for i := 0 to Objects.Count-1 do
        begin
          t := TfrView(Objects[i]);
          if not t.Selected and (t.Typ <> gtBand) then
          begin
            d1 := 10000;
            if StepX <> 0 then
            begin
              if t.y + t.dy < ty then
                d1 := ty - (t.y + t.dy)
              else if t.y > ty1 then
                d1 := t.y - ty1
              else if (t.y <= ty) and (t.y + t.dy >= ty1) then
                d1 := 0
              else
                d1 := t.y - ty;
              if ((t.x <= tx) and (StepX = 1)) or
                 ((t.x + t.dx >= tx1) and (StepX = -1)) then
                d1 := 10000;
              if StepX = 1 then
                if t.x >= tx1 then
                  d1 := d1 + t.x - tx1 else
                  d1 := d1 + t.x - tx
              else if t.x + t.dx <= tx then
                  d1 := d1 + tx - (t.x + t.dx) else
                  d1 := d1 + tx1 - (t.x + t.dx);
            end
            else if StepY <> 0 then
            begin
              if t.x + t.dx < tx then
                d1 := tx - (t.x + t.dx)
              else if t.x > tx1 then
                d1 := t.x - tx1
              else if (t.x <= tx) and (t.x + t.dx >= tx1) then
                d1 := 0
              else
                d1 := t.x - tx;
              if ((t.y <= ty) and (StepY = 1)) or
                 ((t.y + t.dy >= ty1) and (StepY = -1)) then
                d1 := 10000;
              if StepY = 1 then
                if t.y >= ty1 then
                  d1 := d1 + t.y - ty1 else
                  d1 := d1 + t.y - ty
              else if t.y + t.dy <= ty then
                  d1 := d1 + ty - (t.y + t.dy) else
                  d1 := d1 + ty1 - (t.y + t.dy);
            end;
            if d1 < d then
            begin
              d := d1;
              t1 := t;
            end;
          end;
        end;
        if t1 <> nil then
        begin
          t := TfrView(Objects[TopSelected]);
          if not (ssAlt in Shift) then
          begin
            PageView.NPEraseSelection;
            Unselect;
            SelNum := 1;
            t1.Selected := True;
            PageView.NPDrawSelection;
          end
          else
          begin
            if (t1.x >= t.x + t.dx) and (Key = VK_RIGHT) then
              t.x := t1.x - t.dx
            else if (t1.y > t.y + t.dy) and (Key = VK_DOWN) then
              t.y := t1.y - t.dy
            else if (t1.x + t1.dx <= t.x) and (Key = VK_LEFT) then
              t.x := t1.x + t1.dx
            else if (t1.y + t1.dy <= t.y) and (Key = VK_UP) then
              t.y := t1.y + t1.dy;
            RedrawPage;
          end;
          SelectionChanged;
        end;
      end;
      Key := 0;
    end; // if (StepX <> 0) or (StepY <> 0)
  end; // if SelNum > 0 then
end;

procedure TfrDesignerForm.MoveObjects(dx, dy: Integer; aResize: Boolean);
begin
  AddUndoAction(acEdit);
  PageView.NPEraseSelection;
  PageView.MoveResize(Dx,Dy, false, aResize);
  ShowPosition;
  PageView.GetMultipleSelected;
end;

procedure TfrDesignerForm.UpdateStatus;
begin
  {$ifdef sbod}
  StatusBar1.Update;
  {$else}
  PBox1Paint(nil);
  {$endif}
end;

procedure TfrDesignerForm.DeleteObjects;
var
  i: Integer;
  t: TfrView;
begin
  AddUndoAction(acDelete);
  PageView.NPEraseSelection;
  for i := Objects.Count - 1 downto 0 do
  begin
    t := TfrView(Objects[i]);
    if t.Selected and not (lrrDontDelete in T.Restrictions) then
      Page.Delete(i);
  end;
  SetPageTitles;
  ObjInsp.Select(nil);
  ResetSelection;
  FirstSelected := nil;
  PageView.Invalidate;
end;

function TfrDesignerForm.SelStatus: TfrSelectionStatus;
var
  t: TfrView;
begin
  Result := [];
  if SelNum = 1 then
  begin
    t := TfrView(Objects[TopSelected]);
    if t.Typ = gtBand then
      Result := [ssBand]
    else
    if t is TfrCustomMemoView then
      Result := [ssMemo]
    else
      Result := [ssOther];
  end
  else if SelNum > 1 then
          Result := [ssMultiple];
          
  if ClipBd.Count > 0 then
    Result := Result + [ssClipboardFull];
end;

procedure TfrDesignerForm.UpdScrollbars;
begin
  ScrollBox1.Autoscroll := False;
  ScrollBox1.Autoscroll := True;
  ScrollBox1.VertScrollBar.Range := ScrollBox1.VertScrollBar.Range + 10;
end;

{$PUSH}
{$HINTS OFF}
{$ifdef sbod}
procedure TfrDesignerForm.DrawStatusPanel(const ACanvas: TCanvas;
  const rect: TRect);
var
  t: TfrView;
  s: String;
  nx, ny: Double;
  x, y, dx, dy: Integer;
begin
  with ACanvas do
  begin
    Brush.Color := StatusBar1.Color;
    FillRect(Rect);
    ImageList1.Draw(ACanvas, Rect.Left + 2, Rect.Top+2, 0);
    ImageList1.Draw(ACanvas, Rect.Left + 92, Rect.Top+2, 1);
    if (SelNum = 1) or ShowSizes then
    begin
      t := nil;
      if ShowSizes then
      begin
        x := OldRect.Left;
        y := OldRect.Top;
        dx := OldRect.Right - x;
        dy := OldRect.Bottom - y;
      end
      else
      begin
        t := TfrView(Objects[TopSelected]);
        x := t.x;
        y := t.y;
        dx := t.dx;
        dy := t.dy;
      end;

      if FUnits = ruPixels then
        s := IntToStr(x) + ';' + IntToStr(y)
      else
        s := FloatToStrF(PointsToUnits(x), ffFixed, 4, 2) + '; ' +
              FloatToStrF(PointsToUnits(y), ffFixed, 4, 2);

      TextOut(Rect.Left + 20, Rect.Top + 1, s);
      if FUnits = ruPixels then
        s := IntToStr(dx) + ';' + IntToStr(dy)
      else
        s := FloatToStrF(PointsToUnits(dx), ffFixed, 4, 2) + '; ' +
               FloatToStrF(PointsToUnits(dy), ffFixed, 4, 2);
      TextOut(Rect.Left + 110, Rect.Top + 1, s);

      if not ShowSizes and (t.Typ = gtPicture) then
      begin
        with t as TfrPictureView do
        begin
          if (Picture.Graphic <> nil) and not Picture.Graphic.Empty then
          begin
            s := IntToStr(dx * 100 div Picture.Width) + ',' +
                 IntToStr(dy * 100 div Picture.Height);
            TextOut(Rect.Left + 170, Rect.Top + 1, '% ' + s);
          end;
        end;
      end;
    end
    else if (SelNum > 0) and MRFlag then
         begin
            nx := 0;
            ny := 0;
            if OldRect1.Right - OldRect1.Left <> 0 then
              nx := (OldRect.Right - OldRect.Left) / (OldRect1.Right - OldRect1.Left);
            if OldRect1.Bottom - OldRect1.Top <> 0 then
              ny := (OldRect.Bottom - OldRect.Top) / (OldRect1.Bottom - OldRect1.Top);
            s := IntToStr(Round(nx * 100)) + ',' + IntToStr(Round(ny * 100));
            TextOut(Rect.left + 170, Rect.Top + 1, '% ' + s);
         end;
  end;
end;

procedure TfrDesignerForm.StatusBar1DrawPanel(StatusBar: TStatusBar;
  Panel: TStatusPanel; const Rect: TRect);
begin
  if Panel.Index=1 then
    DrawStatusPanel(StatusBar.Canvas, Rect);
end;

procedure TfrDesignerForm.DefineExtraPopupSelected(popup: TPopupMenu);
var
  m: TMenuItem;
begin
  m := TMenuItem.Create(Popup);
  m.Caption := '-';
  Popup.Items.Add(m);

  m := TMenuItem.Create(Popup);
  m.Caption := sFRDesignerFormSelectSameClass;
  m.OnClick := @SelectSameClassClick;
  m.Tag := PtrInt(Objects[TopSelected]);
  Popup.Items.Add(m);
end;

procedure TfrDesignerForm.SelectSameClassClick(Sender: TObject);
var
  View: TfrView;
begin
  if Sender is TMenuItem then
  begin
    View := TfrView(TMenuItem(Sender).Tag);
    if Objects.IndexOf(View)>=0 then
    begin
      PageView.NPEraseSelection;
      SelectSameClass(View);
      PageView.GetMultipleSelected;
      PageView.NPDrawSelection;
      SelectionChanged;
    end;
  end;
end;

procedure TfrDesignerForm.SelectSameClass(View: TfrView);
var
  i: Integer;
  v: TfrView;
begin
  SelNum := 0;
  for i := 0 to Objects.Count - 1 do
  begin
    v := TfrView(Objects[i]);
    if v.ClassName=View.ClassName then
    begin
      v.Selected := True;
      Inc(SelNum);
    end;
  end;
end;

function TfrDesignerForm.CheckFileModified: Integer;
begin
  result := mrNo;
//  if FileModified then
  if Modified then
  begin
    result:=MessageDlg(sSaveChanges + ' ' + sTo + ' ' +
      ExtractFileName(CurDocName) + '?',mtConfirmation,
      [mbYes,mbNo,mbCancel],0);

    if result = mrCancel then Exit;
    if result = mrYes then
    begin
      FileSave.Execute;
//      FileBtn3Click(nil);
      if not WasOk then
        result := mrCancel;
    end;
  end;
end;

// if AList is specified always process the list being objects selected or not
// if AList is not specified, all objects are processed but check Selected state
procedure TfrDesignerForm.ViewsAction(Views: TFpList; TheAction: TViewAction;
  Data: PtrInt; OnlySel:boolean=true; WithUndoAction:boolean=true;
  WithRedraw:boolean=true);
var
  i, n: Integer;
  List: TFpList;
begin
  if not assigned(TheAction) then
    exit;

 List := Views;
  if List=nil then
   List := Objects;

  n := 0;
  for i:=List.Count-1 downto 0 do begin
    if (Views=nil) and OnlySel and not TfrView(List[i]).Selected then
      continue;
    inc(n);
  end;

  if n=0 then
    exit;

  if WithUndoAction then
    AddUndoAction(acEdit);

  if WithRedraw then begin
    PageView.NPEraseSelection;
    GetRegion;
  end;

  for i:=List.Count-1 downto 0 do begin
    if (Views=nil) and OnlySel and not TfrView(List[i]).Selected then
      continue;
    TheAction(TfrView(List[i]), Data);
  end;

  if WithRedraw then
    PageView.NPDrawLayerObjects(ClipRgn, TopSelected);
end;

// data=0 remove all borders
// data=1 set all borders
// data=-1 toggle all borders
procedure TfrDesignerForm.ToggleFrames(View: TfrView; Data: PtrInt);
begin
  if (Data=0) or ((Data=-1) and (View.Frames<>[])) then
    View.Frames := []
  else
  if (Data=1) or ((Data=-1) and (View.Frames=[])) then
    View.Frames := [frbLeft, frbTop, frbRight, frbBottom];

  if SelNum=1 then
    LastFrames := View.Frames;
end;

procedure TfrDesignerForm.DuplicateView(View: TfrView; Data: PtrInt);
var
  t: TfrView;
begin
  // check if view is unique instance band kind and if there is already one
  if (View is TfrBandView) and
     not (TfrBandView(View).BandType in [btMasterHeader..btSubDetailFooter,
                                         btGroupHeader, btGroupFooter])
     and frCheckBand(TfrBandView(View).BandType)
  then
    exit;

  t := frCreateObject(View.Typ, View.ClassName, Page);
  TfrView(t).Assign(View);
  t.y := t.y + FDuplicateCount * FDupDeltaY;
  t.x := t.x + FDuplicateCount * FDupDeltaX;
  t.Selected := false;

  if CurReport.FindObject(t.Name) <> nil then
    t.CreateUniqueName;

//  Objects.Add(t);
end;

procedure TfrDesignerForm.ResetDuplicateCount;
begin
  FDuplicateCount := 0;
  FreeThenNil(FDuplicateList);
end;

function TfrDesignerForm.lrDesignAcceptDrag(const Source: TObject): TControl;
begin
  if Source is TControl then
    Result:=Source as TControl
  else
  if Source is TDragControlObject then
    Result:=(Source as TDragControlObject).Control
  else
    Result:=nil;
end;

procedure TfrDesignerForm.InplaceEditorMenuClick(Sender: TObject);
var
  t: TfrView;
begin
  t := TfrView(Objects[TopSelected]);
  if T is TfrMemoView then
  begin
    TfrMemoView(T).Memo.Text:='[' + (Sender as TMenuItem).Caption + ']';
    PageView.Invalidate;
    frDesigner.Modified:=true;
  end;
end;

{$endif}

procedure TfrDesignerForm.TabsEditDragOver(Sender, Source: TObject; X,
  Y: Integer; State: TDragState; var Accept: Boolean);
begin
  //Accept:=(Source = FTabsPage) and (FTabsPage.IndexOfPageAt(X, Y) <> Tab1.TabIndex);
  Accept:=(Source = Tab1) and (Tab1.IndexOfTabAt(X, Y) <> Tab1.TabIndex);
end;

procedure TfrDesignerForm.TabsEditDragDrop(Sender, Source: TObject; X,
  Y: Integer);
var
  NewIndex: Integer;
begin
  //NewIndex:=FTabsPage.IndexOfPageAt(X, Y);
  NewIndex:=Tab1.IndexOfTabAt(X, Y);
  //ShowMessageFmt('New index = %d', [NewIndex]);
  if (NewIndex>-1) and (NewIndex < CurReport.Pages.Count) then
  begin
    CurReport.Pages.Move(CurPage, NewIndex);
    Tab1.Tabs.Move(CurPage, NewIndex);
    SetPageTitles;

    ClearUndoBuffer;
    ClearRedoBuffer;
    Modified := True;
    Tab1.TabIndex:=NewIndex;
    RedrawPage;
  end;
end;

procedure TfrDesignerForm.TabsEditMouseDown(Sender: TObject;
  Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  FTabMouseDown:=true;
end;

procedure TfrDesignerForm.TabsEditMouseMove(Sender: TObject;
  Shift: TShiftState; X, Y: Integer);
begin
  if FTabMouseDown then
    //FTabsPage.BeginDrag(false);
    Tab1.BeginDrag(false);
end;

procedure TfrDesignerForm.TabsEditMouseUp(Sender: TObject;
  Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  FTabMouseDown:=false;
end;

procedure TfrDesignerForm.ShowIEButton(AView:TfrMemoView);
var
  lrObj: TfrObject;
  Band: TfrBandView;
  i, L, j: Integer;
  C: TComponent;
  M: TMenuItem;
begin
  if not edtUseIE then exit;
  Band:=nil;
  for i:=0 to Objects.Count-1 do
  begin
    lrObj:=TfrObject(Objects[i]);
    if lrObj is TfrBandView then
    begin
      if (AView.y >= TfrBandView(lrObj).y) and ((AView.dy + AView.y) <= (lrObj.y+lrObj.dy)) then
        Band:=TfrBandView(lrObj);
    end;
  end;
  if not Assigned(Band) then exit;


  C:=frFindComponent(CurReport.Owner, Band.DataSet);
  if C is TfrDBDataSet then
    C:=TfrDBDataSet(C).DataSet;

  if  (not Assigned(C)) or (not (C is TDataSet)) then exit;

  L:=TDataSet(C).Fields.Count;
  if (L = 0) then
  begin
    TDataSet(C).FieldDefs.Update;
    L:=TDataSet(C).FieldDefs.Count;
  end;

  if L > 0 then
  begin
    IEButton.Parent:=PageView;
    IEButton.Visible:=true;
    IEButton.Left:=AView.X + AView.dx;
    IEButton.Top:=AView.y;
    IEButton.Height:=Max(10, AView.dy);

    IEPopupMenu.Items.Clear;
    if TDataSet(C).Fields.Count>0 then
    begin
      for j:=0 to TDataSet(C).Fields.Count-1 do
      begin
        M:=TMenuItem.Create(IEPopupMenu.Owner);
        M.Caption:=TDataSet(C).Name + '."'+TDataSet(C).Fields[j].FieldName+'"';
        M.OnClick:=@InplaceEditorMenuClick;
        IEPopupMenu.Items.Add(M);
      end;
    end
    else
    begin
      for j:=0 to TDataSet(C).FieldDefs.Count-1 do
      begin
        M:=TMenuItem.Create(IEPopupMenu.Owner);
        M.Caption:=TDataSet(C).Name + '."'+TDataSet(C).FieldDefs[j].Name+'"';
        M.OnClick:=@InplaceEditorMenuClick;
        IEPopupMenu.Items.Add(M);
      end;
    end;
  end;
end;

procedure TfrDesignerForm.HideIEButton;
begin
  IEButton.Visible:=false;
end;

procedure TfrDesignerForm.SetModified(AValue: Boolean);
begin
  inherited SetModified(AValue);
  if AValue then
    StatusBar1.Panels[2].Text:=sFRDesignerForm_Modified
  else
    StatusBar1.Panels[2].Text:='';
  FileSave.Enabled:=AValue;
end;

function TfrDesignerForm.IniFileName: string;
begin
  Result:=AppendPathDelim(lrConfigFolderName(false))+'lrDesigner.cfg';
end;

{$POP}

function TfrDesignerForm.RectTypEnabled: Boolean;
begin
  Result := [ssMemo, ssOther, ssMultiple] * SelStatus <> [];
end;

function TfrDesignerForm.FontTypEnabled: Boolean;
begin
  Result := [ssMemo, ssMultiple] * SelStatus <> [];
end;

function TfrDesignerForm.ZEnabled: Boolean;
begin
  Result := [ssBand, ssMemo, ssOther, ssMultiple] * SelStatus <> [];
end;

function TfrDesignerForm.CutEnabled: Boolean;
begin
  Result := [ssBand, ssMemo, ssOther, ssMultiple] * SelStatus <> [];
end;

function TfrDesignerForm.CopyEnabled: Boolean;
begin
  Result := [ssBand, ssMemo, ssOther, ssMultiple] * SelStatus <> [];
end;

function TfrDesignerForm.PasteEnabled: Boolean;
begin
  Result := ssClipboardFull in SelStatus;
end;

function TfrDesignerForm.DelEnabled: Boolean;
begin
  Result := [ssBand, ssMemo, ssOther, ssMultiple] * SelStatus <> [];
end;

function TfrDesignerForm.EditEnabled: Boolean;
begin
  Result:=[ssBand,ssMemo,ssOther]*SelStatus <> [];
end;

procedure TfrDesignerForm.EnableControls;

  procedure SetCtrlEnabled(const Ar: Array of TObject; en: Boolean);
  var
    i: Integer;
  begin
    for i := Low(Ar) to High(Ar) do
      if Ar[i] is TControl then
        (Ar[i] as TControl).Enabled := en
      else if Ar[i] is TMenuItem then
        (Ar[i] as TMenuItem).Enabled := en;
  end;
  
begin
  SetCtrlEnabled([FrB1, FrB2, FrB3, FrB4, FrB5, FrB6, ClB1, ClB3, E1, SB1, SB2, StB1],
    RectTypEnabled);
  SetCtrlEnabled([ClB2, C2, C3, FnB1, FnB2, FnB3, AlB1, AlB2, AlB3, AlB4, AlB5, AlB6, AlB7, AlB8, HlB1],
    FontTypEnabled);
  SetCtrlEnabled([ZB1, ZB2, N32, N33, GB3], ZEnabled);
  SetCtrlEnabled([CutB, N11, N2], CutEnabled);
  SetCtrlEnabled([CopyB, N12, N1], CopyEnabled);
  SetCtrlEnabled([PstB, N13, N3], PasteEnabled);
  SetCtrlEnabled([N27, N5], DelEnabled);
  SetCtrlEnabled([N36, N6], EditEnabled);
  if not C2.Enabled then
  begin
    C2.ItemIndex := -1;
    C3.Text := '';
  end;

  StatusBar1.Repaint;
  {$ifndef sbod}
  PBox1.Invalidate;
  {$endif}
end;

procedure TfrDesignerForm.SelectionChanged;
var
  t: TfrView;
begin
  {$IFDEF DebugLR}
  debugLnEnter('TfrDesignerForm.SelectionChanged INIT, SelNum=%d',[SelNum]);
  {$ENDIF}
  HideIEButton;
  Busy := True;
  ColorSelector.Hide;
  LinePanel.Hide;
  EnableControls;
  if Page is TfrPageReport then
  begin
    if SelNum = 1 then
    begin
      t := TfrView(Objects[TopSelected]);
      if t.Typ <> gtBand then
      with t do
      begin
        {$IFDEF DebugLR}
        DebugLn('Not a band');
        {$ENDIF}
        FrB1.Down := (frbTop in Frames);
        FrB2.Down := (frbLeft in Frames);
        FrB3.Down := (frbBottom in Frames);
        FrB4.Down := (frbRight  in Frames);
        E1.Text := FloatToStrF(FrameWidth, ffGeneral, 2, 2);
        frSetGlyph(FillColor, ClB1, 1);
        frSetGlyph(FrameColor, ClB3, 2);
        if t is TfrCustomMemoView then
        with t as TfrCustomMemoView do
        begin
          frSetGlyph(Font.Color, ClB2, 0);
          if C2.ItemIndex <> C2.Items.IndexOf(Font.Name) then
            C2.ItemIndex := C2.Items.IndexOf(Font.Name);

          if C3.Text <> IntToStr(Font.Size) then
            C3.Text := IntToStr(Font.Size);

          FnB1.Down := fsBold in Font.Style;
          FnB2.Down := fsItalic in Font.Style;
          FnB3.Down := fsUnderline in Font.Style;

          AlB4.Down := (Adjust and $4) <> 0;
          AlB5.Down := (Adjust and $18) = $8;
          AlB6.Down := (Adjust and $18) = 0;
          AlB7.Down := (Adjust and $18) = $10;
          case (Adjust and $3) of
            0: BDown(AlB1);
            1: BDown(AlB2);
            2: BDown(AlB3);
            3: BDown(AlB8);
          end;
        end;
      end;


      if T is TfrMemoView then
        ShowIEButton(T as TfrMemoView);
    end
    else if SelNum > 1 then
    begin
      {$IFDEF DebugLR}
      DebugLn('Multiple selection');
      {$ENDIF}

      BUp(FrB1);
      BUp(FrB2);
      BUp(FrB3);
      BUp(FrB4);
      ColorLocked := True;
      frSetGlyph(0, ClB1, 1);
      ColorLocked := False;
      E1.Text := '1';
      C2.ItemIndex := -1;
      C3.Text := '';
      BUp(FnB1);
      BUp(FnB2);
      BUp(FnB3);
      BDown(AlB1);
      BUp(AlB4);
      BUp(AlB5);
    end;
  end
  else
  begin
    if ObjInsp.SelectedObject = Page then
      PageView.Invalidate;
  end;
  Busy := False;
  ShowPosition;
  ShowContent;
  ActiveControl := nil;
  {$IFDEF DebugLR}
  debugLnExit('TfrDesignerForm.SelectionChanged END, SelNum=%d',[SelNum]);
  {$ENDIF}
end;

procedure TfrDesignerForm.ShowPosition;
begin
  FillInspFields;
  StatusBar1.Repaint;
  {$ifndef sbod}
  PBox1.Invalidate;
  {$endif}
end;

procedure TfrDesignerForm.ShowContent;
var
  t: TfrView;
  s: String;
begin
  s := '';
  if SelNum = 1 then
  begin
    t := TfrView(Objects[TopSelected]);
    s := t.Name;
    if t is TfrBandView then
      s := s + ': ' + frBandNames[TfrBandView(t).BandType]
    else if t.Memo.Count > 0 then
      s := s + ': ' + t.Memo[0];
  end;
  StatusBar1.Panels[3].Text := s;
end;

procedure TfrDesignerForm.DoClick(Sender: TObject);
var
  i, j, b: Integer;
  s      : String;
  t      : TfrView;
begin
  if Busy then
    Exit;
  AddUndoAction(acEdit);
  PageView.NPEraseSelection;
  GetRegion;
  b:=(Sender as TControl).Tag;
  
  for i := 0 to Objects.Count - 1 do
  begin
    t := TfrView(Objects[i]);
    if t.Selected and ((t.Typ <> gtBand) or (b = 16)) then
    with t do
    begin
      if t is TfrCustomMemoView then
      with t as TfrCustomMemoView do
        case b of
          7: if C2.ItemIndex >= 0 then
             begin
               Font.Name := C2.Items[C2.ItemIndex];
               LastFontName := Font.Name;
             end;
          8: begin
               Font.Size := StrToIntDef(C3.Text, LastFontSize);
               LastFontSize := Font.Size;
             end;
          9: begin
               LastFontStyle := frGetFontStyle(Font.Style);
               //SetBit(LastFontStyle, not FnB1.Down, 2);
               SetBit(LastFontStyle, FnB1.Down, 2);
               Font.Style := frSetFontStyle(LastFontStyle);
             end;
         10: begin
               LastFontStyle := frGetFontStyle(Font.Style);
               //SetBit(LastFontStyle, not FnB2.Down, 1);
               SetBit(LastFontStyle, FnB2.Down, 1);
               Font.Style := frSetFontStyle(LastFontStyle);
             end;
         11..13:
             begin
               Adjust := (Adjust and $FC) + (b-11);
               LastAdjust := Adjust;
             end;
         14: begin
               Adjust := (Adjust and $FB) + Word(AlB4.Down) * 4;
               LastAdjust := Adjust;
             end;
         15: begin
               Adjust := (Adjust and $E7) + Word(AlB5.Down) * 8 + Word(AlB7.Down) * $10;
               LastAdjust := Adjust;
             end;
         17: begin
               Font.Color := ColorSelector.Color;
               LastFontColor := Font.Color;
             end;
         18: begin
               LastFontStyle := frGetFontStyle(Font.Style);
//               SetBit(LastFontStyle, not FnB3.Down, 4);
               SetBit(LastFontStyle, FnB3.Down, 4);
               Font.Style := frSetFontStyle(LastFontStyle);
             end;
         22: begin
               //Alignment:=tafrJustify;
               Adjust := (Adjust and $FC) + 3;
               LastAdjust := Adjust;
             end;
        end;
        
      case b of
        1:
         begin //Top frame
           if (Sender=frB1) and frB1.Down then
             Frames:=Frames+[frbTop]
           else
             Frames:=Frames-[frbTop];
           DRect := Rect(t.x - 10, t.y - 10, t.x + t.dx + 10, t.y + 10)
         end;
        2: //Left frame
         begin
           if (Sender=FrB2) and frB2.Down then
             Frames:=Frames+[frbLeft]
           else
             Frames:=Frames-[frbLeft];
           DRect := Rect(t.x - 10, t.y - 10, t.x + 10, t.y + t.dy + 10)
         end;
        3: //Bottom Frame
         begin
           if (Sender=FrB3) and frB3.Down then
             Frames:=Frames+[frbBottom]
           else
             Frames:=Frames-[frbBottom];
           DRect := Rect(t.x - 10, t.y + t.dy - 10, t.x + t.dx + 10, t.y + t.dy + 10)
         end;
        4: //Right Frame
         begin
           if (Sender=FrB4) and frB4.Down then
             Frames:=Frames+[frbRight]
           else
             Frames:=Frames-[frbRight];
           DRect := Rect(t.x + t.dx - 10, t.y - 10, t.x + t.dx + 10, t.y + t.dy + 10)
         end;
        20:
         begin
           if (Sender=FrB5) then
             Frames:=[frbLeft, frbTop, frbRight, frbBottom];

           LastFrames:=Frames;
         end;
        21:
         begin
           if (Sender=FrB6) then
             Frames:=[];
           LastFrames:=[];
         end;
        5:
         begin
           FillColor:=ColorSelector.Color;
           LastFillColor := FillColor;
         end;
        6:
         begin
           s := E1.Text;
           for j := 1 to Length(s) do
             if s[j] in ['.', ','] then
               s[j] := DecimalSeparator;
           FrameWidth := StrToFloat(s);
           if t is TfrLineView then
             LastLineWidth := FrameWidth
           else
             LastFrameWidth := FrameWidth;
         end;
        19:
         begin
           FrameColor := ColorSelector.Color;
           LastFrameColor := FrameColor;
         end;
        25..30:
          FrameStyle:=TfrFrameStyle(b - 25);
      end;
    end;
  end;

  PageView.NPDrawLayerObjects(ClipRgn, TopSelected);
  if b<>8 then // without this you can't enter more then 1 digits in Fontsize-combobox
    ActiveControl := nil;
  if b in [20, 21] then
    SelectionChanged;
end;

procedure TfrDesignerForm.frSpeedButton1Click(Sender: TObject);
begin
  LinePanel.Hide;
  DoClick(Sender);
end;

procedure TfrDesignerForm.HlB1Click(Sender: TObject);
var
  t: TfrCustomMemoView;
begin
  t := TfrCustomMemoView(Objects[TopSelected]);
  frHilightForm := TfrHilightForm.Create(nil);
  with frHilightForm do
  begin
    FontColor := t.Highlight.FontColor;
    FillColor := t.Highlight.FillColor;
    CB1.Checked := (t.Highlight.FontStyle and $2) <> 0;
    CB2.Checked := (t.Highlight.FontStyle and $1) <> 0;
    CB3.Checked := (t.Highlight.FontStyle and $4) <> 0;
    Edit1.Text := t.HighlightStr;
    if ShowModal = mrOk then
    begin
      AddUndoAction(acEdit);
      t.HighlightStr := Edit1.Text;
      t.Highlight.FontColor := FontColor;
      t.Highlight.FillColor := FillColor;
      SetBit(t.Highlight.FontStyle, CB1.Checked, 2);
      SetBit(t.Highlight.FontStyle, CB2.Checked, 1);
      SetBit(t.Highlight.FontStyle, CB3.Checked, 4);
    end;
  end;
  frHilightForm.Free;
end;

procedure TfrDesignerForm.FillInspFields;
var
  t: TfrView;
begin
  if SelNum = 0 then
    ObjInspSelect(Page)
  else
  if SelNum = 1 then
  begin
    t := TfrView(Objects[TopSelected]);
    ObjInspSelect(t);
  end else
  if SelNum > 1 then
    ObjInspSelect(Objects);
  ObjInspRefresh;
end;

{
procedure TfrDesignerForm.OnModify(Item: Integer; var EditText: String);
var
  t: TfrView;
  i, k: Integer;
begin
  AddUndoAction(acEdit);
  if (Item = 0) and (SelNum = 1) then
  begin
    t := TfrView(Objects[TopSelected]);
    if CurReport.FindObject(fld[0]) = nil then
      t.Name := fld[0] else
      EditText := t.Name;
    SetPageTitles;
  end
  else if Item in [1..5] then
  begin
    EditText := frParser.Calc(fld[Item]);
    if Item <> 6 then
      k := UnitsToPoints(StrToFloat(EditText)) else
      k := StrToInt(EditText);
    for i := 0 to Objects.Count-1 do
    begin
      t := TfrView(Objects[i]);
      if t.Selected then
      with t do
        case Item of
          1: if (k > 0) and (k < Page.PrnInfo.Pgw) then
               x := k;
          2: if (k > 0) and (k < Page.PrnInfo.Pgh) then
             y := k;
          3: if (k > 0) and (k < Page.PrnInfo.Pgw) then
             dx := k;
          4: if (k > 0) and (k < Page.PrnInfo.Pgh) then
             dy := k;
          5: Visible := Boolean(k);
        end;
    end;
  end;
  FillInspFields;
  if Item in [1..5] then
    EditText := fld[Item];
  RedrawPage;
  StatusBar1.Repaint;
  PBox1.Invalidate;
end;
}
procedure TfrDesignerForm.StB1Click(Sender: TObject);
var
  p: TPoint;
begin
  if not LinePanel.Visible then
  begin
    LinePanel.Parent := Self;
    with (Sender as TControl) do
      p := Self.ScreenToClient(Parent.ClientToScreen(Point(Left, Top)));
    LinePanel.SetBounds(p.X,p.Y + 26,LinePanel.Width,LinePanel.Height);
  end;
  LinePanel.Visible := not LinePanel.Visible;
end;

procedure TfrDesignerForm.ObjInspSelect(Obj: TObject);
{$IFDEF STDOI}
var
  Selection: TPersistentSelectionList;
  i: Integer;
{$ENDIF}
begin
  {$IFDEF STDOI}
  Selection := TPersistentSelectionList.Create;
  PropHook.LookupRoot:=nil;
  if Obj is TPersistent then
  begin
    Selection.Add(TPersistent(Obj));
    PropHook.LookupRoot:=TPersistent(Obj);
  end else
  if Obj is TFpList then
    with frDesigner.page do
      for i:=0 to Objects.Count-1 do
        if TfrView(Objects[i]).Selected then
        begin
          if PropHook.LookupRoot=nil then
            PropHook.LookupRoot := TPersistent(Objects[i]);
          Selection.Add(TPersistent(Objects[i]));
        end;
  ObjInsp.Selection := Selection;
  Selection.Free;
  {$ELSE}
  ObjInsp.Select(Obj);
  {$ENDIF}
end;

procedure TfrDesignerForm.DuplicateSelection;
var
  t: TfrView;
  q: TPoint;
  p: TPoint;
  i: Integer;
  OldCount: Integer;
begin
  if not DelEnabled then
    exit;

  OldCount := Objects.Count;
  if OldCount=0 then
    exit;

  if FDuplicateList=nil then
  begin
    FDuplicateList := TFpList.Create;
    for i:=0 to OldCount-1 do
      if TfrView(Objects[i]).Selected then
        FDuplicateList.Add(Objects[i]);
  end;

  if (FDuplicateList.Count=0) then
  begin
    ResetDuplicateCount;
    exit;
  end;

  Inc(FDuplicateCount);

  if FDuplicateCount=1 then
  begin

    // find reference rect in screen coords
    if SelNum>1 then
    begin
      p := OldRect.TopLeft;
      q := OldRect.BottomRight;
    end else
    begin
      t := TfrView(Objects[TopSelected]);
      p := Point(t.x, t.y);
      q := point(t.x+t.dx, t.y+t.dy);
    end;
    p := PageView.ControlToScreen(p);
    q := PageView.ControlToScreen(q);

    // find duplicates delta based on current mouse cursor position
    FDupDeltaX := (q.x-p.x);
    FDupDeltaY := (q.y-p.y);
    with Mouse.CursorPos do
    begin
      if x < p.x then
        FDupDeltaX := -FDupDeltaX
      else
      if x < q.x then
        FDupDeltaX := 0;

      if y < p.y then
        FDupDeltaY := -FDupDeltaY
      else
      if y < q.y then
        FDupDeltaY := 0;
    end;
  end;

  ViewsAction(FDuplicateList, @DuplicateView, 0, false, false, false);

  if OldCount<>Objects.Count then
  begin
    SendBandsToDown;
    PageView.GetMultipleSelected;
    RedrawPage;
    AddUndoAction(acDuplication);
  end else
    Dec(FDuplicateCount);
end;

procedure TfrDesignerForm.CreateNewReport;
begin
  if CheckFileModified=mrCancel then
    exit;
  ClearUndoBuffer;
  CurReport.Pages.Clear;
  CurReport.Pages.Add;
  CurPage := 0;
  CurDocName := sUntitled;
  //FileModified := False;
  Modified := False;
  CurReport.ReportCreateDate:=Now;

  FCurDocFileType := 3;
end;

procedure TfrDesignerForm.ObjInspRefresh;
begin
  {$IFDEF STDOI}
  //TODO: refresh
  {$ELSE}
  ObjInsp.Refresh;
  {$ENDIF}
end;

procedure TfrDesignerForm.DataInspectorRefresh;
begin
  if Assigned(lrFieldsList) then
    lrFieldsList.RefreshDSList;
end;

procedure TfrDesignerForm.ClB1Click(Sender: TObject);
var p  : TPoint;
    t  : TfrView;
    CL : TColor;
begin
  with (Sender as TControl) do
    p := Self.ScreenToClient(Parent.ClientToScreen(Point(Left, Top)));
  if ColorSelector.Left = p.X then
    ColorSelector.Visible := not ColorSelector.Visible
  else
  begin
    with ColorSelector do SetBounds(p.X,p.Y + 26,Width,Height);
    ColorSelector.Visible := True;
  end;
  ClrButton := Sender as TSpeedButton;
  t := TfrView(Objects[TopSelected]);
  CL:=clNone;
  if Sender=ClB1 then
    CL:=t.FillColor;
  if (Sender=ClB2) and (t is TfrCustomMemoView) then
    CL:=TfrCustomMemoView(t).Font.Color;
  if Sender=ClB3 then
    CL:=t.FrameColor;
  ColorSelector.Color:=CL;
end;

procedure TfrDesignerForm.ColorSelected(Sender: TObject);
var
  n: Integer;
begin
  n := 0;
  if ClrButton = ClB1 then
    n := 1
  else
    if ClrButton = ClB3 then
       n := 2;
  {$IFDEF DebugLR}
  DebugLn('ColorSelected');
  {$ENDIF}
  frSetGlyph(ColorSelector.Color, ClrButton, n);

  DoClick(ClrButton);
end;

procedure TfrDesignerForm.PBox1Paint(Sender: TObject);
var
  t: TfrView;
  s: String;
  nx, ny: Double;
  x, y, dx, dy: Integer;
begin
  with PBox1.Canvas do
  begin
    FillRect(Rect(0, 0, PBox1.Width, PBox1.Height));
    ImageList1.Draw(PBox1.Canvas, 2, 0, 0);
    ImageList1.Draw(PBox1.Canvas, 92, 0, 1);
    if (SelNum = 1) or ShowSizes then
    begin
      t := nil;
      if ShowSizes then
      begin
        x := OldRect.Left;
        y := OldRect.Top;
        dx := OldRect.Right - x;
        dy := OldRect.Bottom - y;
      end
      else
      begin
        t := TfrView(Objects[TopSelected]);
        x := t.x;
        y := t.y;
        dx := t.dx;
        dy := t.dy;
      end;
      
      if FUnits = ruPixels then
        s := IntToStr(x) + ';' + IntToStr(y)
      else
        s := FloatToStrF(PointsToUnits(x), ffFixed, 4, 2) + '; ' +
              FloatToStrF(PointsToUnits(y), ffFixed, 4, 2);
              
      TextOut(20, 1, s);
      if FUnits = ruPixels then
        s := IntToStr(dx) + ';' + IntToStr(dy)
      else
        s := FloatToStrF(PointsToUnits(dx), ffFixed, 4, 2) + '; ' +
               FloatToStrF(PointsToUnits(dy), ffFixed, 4, 2);
      TextOut(110, 1, s);

      if not ShowSizes and (t.Typ = gtPicture) then
      begin
        with t as TfrPictureView do
        begin
          if (Picture.Graphic <> nil) and not Picture.Graphic.Empty then
          begin
            s := IntToStr(dx * 100 div Picture.Width) + ',' +
                 IntToStr(dy * 100 div Picture.Height);
            TextOut(170, 1, '% ' + s);
          end;
        end;
      end;
    end
    else if (SelNum > 0) and MRFlag then
         begin
            nx := 0;
            ny := 0;
            if OldRect1.Right - OldRect1.Left <> 0 then
              nx := (OldRect.Right - OldRect.Left) / (OldRect1.Right - OldRect1.Left);
            if OldRect1.Bottom - OldRect1.Top <> 0 then
              ny := (OldRect.Bottom - OldRect.Top) / (OldRect1.Bottom - OldRect1.Top);
            s := IntToStr(Round(nx * 100)) + ',' + IntToStr(Round(ny * 100));
            TextOut(170, 1, '% ' + s);
         end;
  end;
end;

procedure TfrDesignerForm.C2DrawItem(Control: TWinControl; Index: Integer;
  Rect: TRect; State: TOwnerDrawState);
var
  j: PtrInt;
begin
  with C2.Canvas do
  begin
    Font.Name := 'default';
    FillRect(Rect);
    j := PtrInt(C2.Items.Objects[Index]);
    {$IFDEF USE_PRINTER_FONTS}
    if (j and $100 <> 0) then
      ImageList2.Draw(C2.Canvas, Rect.Left, Rect.Top +1, 2)
    else
    {$ENDIF}
    if ( j and TRUETYPE_FONTTYPE) <> 0 then
      ImageList2.Draw(C2.Canvas, Rect.Left, Rect.Top + 1, 0);
    TextOut(Rect.Left + 20, Rect.Top + 1, C2.Items[Index]);
  end;
end;

procedure TfrDesignerForm.ShowMemoEditor;
begin
  if EditorForm.ShowEditor(TfrView(Objects[TopSelected])) = mrOk then
  begin
    PageView.NPDrawSelection;
    PageView.NPDrawLayerObjects(EditorForm.View.GetClipRgn(rtExtended), TopSelected);
  end;

  ActiveControl := nil;
end;

procedure TfrDesignerForm.ShowEditor;
var
  t: TfrView;
  i: Integer;
  bt: TfrBandType;
begin
  SetCaptureControl(nil);
  t := TfrView(Objects[TopSelected]);

  if lrrDontModify in T.Restrictions then
    exit;

  if t.Typ = gtMemo then
    ShowMemoEditor
  else
  if t.Typ = gtPicture then
  begin
    frGEditorForm := TfrGEditorForm.Create(nil);
    with frGEditorForm do
    begin
      Image1.Picture.Assign((t as TfrPictureView).Picture);
      if ShowModal = mrOk then
      begin
        AddUndoAction(acEdit);
        (t as TfrPictureView).Picture.Assign(Image1.Picture);
        PageView.NPDrawSelection;
        PageView.NPDrawLayerObjects(t.GetClipRgn(rtExtended), TopSelected);
      end;
    end;
    frGEditorForm.Free;
  end
  else
  if t.Typ = gtBand then
  begin
    PageView.NPEraseSelection;
    bt := (t as TfrBandView).BandType;
    if bt in [btMasterData, btDetailData, btSubDetailData] then
    begin
      frBandEditorForm := TfrBandEditorForm.Create(nil);
      frBandEditorForm.ShowEditor(t);
      frBandEditorForm.Free;
    end
    else if bt = btGroupHeader then
    begin
      frGroupEditorForm := TfrGroupEditorForm.Create(nil);
      frGroupEditorForm.ShowEditor(t);
      frGroupEditorForm.Free;
    end
    else if bt = btCrossData then
    begin
      frVBandEditorForm := TfrVBandEditorForm.Create(nil);
      frVBandEditorForm.ShowEditor(t);
      frVBandEditorForm.Free;
    end
    else
      PageView.DFlag := False;
    PageView.NPDrawLayerObjects(t.GetClipRgn(rtExtended), TopSelected);
  end
  else
  if t.Typ = gtSubReport then
    CurPage := (t as TfrSubReportView).SubPage.PageIndex
  else
  if t.Typ = gtAddIn then
  begin
    for i := 0 to frAddInsCount - 1 do
      if frAddIns[i].ClassRef.ClassName = t.ClassName then
      begin
        if Assigned(frAddIns[i].EditorProc) then
        begin
          if frAddIns[i].EditorProc(t) then
            Modified:=true;
        end
        else
        if frAddIns[i].EditorForm <> nil then
        begin
          PageView.NPEraseSelection;
          frAddIns[i].EditorForm.ShowEditor(t);
          PageView.NPDrawLayerObjects(t.GetClipRgn(rtExtended), TopSelected);
        end
        else
          ShowMemoEditor;
        break;
      end;
  end;
  ShowContent;
  ShowPosition;
  ActiveControl := nil;
end;

procedure TfrDesignerForm.ShowDialogPgEditor(APage: TfrPageDialog);
begin
  EditorForm.M2.Lines.Assign(APage.Script);
  EditorForm.MemoPanel.Visible:=false;
  EditorForm.CB1.OnClick:=nil;
  EditorForm.CB1.Checked:=true;
  EditorForm.CB1.OnClick:=@EditorForm.CB1Click;
  EditorForm.ScriptPanel.Align:=alClient;
  if EditorForm.ShowEditor(nil) = mrOk then
  begin
    APage.Script.Assign(EditorForm.M2.Lines);
    frDesigner.Modified:=true;
  end;
  EditorForm.ScriptPanel.Align:=alBottom;
  EditorForm.MemoPanel.Visible:=true;
  ActiveControl := nil;
end;

procedure TfrDesignerForm.ReleaseAction(ActionRec: TfrUndoRec);
var
  p, p1: PfrUndoObj;
begin
  p := ActionRec.Objects;
  while p <> nil do
  begin
    if ActionRec.Action in [acDelete, acEdit] then
      p^.ObjPtr.Free;
    p1 := p;
    p := p^.Next;
    FreeMem(p1, SizeOf(TfrUndoObj));
  end;
end;

procedure TfrDesignerForm.ClearBuffer(Buffer: TfrUndoBuffer; var BufferLength: Integer);
var
  i: Integer;
begin
  for i := 0 to BufferLength - 1 do
    ReleaseAction(Buffer[i]);
  BufferLength := 0;
end;

procedure TfrDesignerForm.ClearUndoBuffer;
begin
  ClearBuffer(FUndoBuffer, FUndoBufferLength);
  edtUndo.Enabled := False;
end;

procedure TfrDesignerForm.ClearRedoBuffer;
begin
  ClearBuffer(FRedoBuffer, FRedoBufferLength);
  edtRedo.Enabled := False;
end;

procedure TfrDesignerForm.Undo(Buffer: PfrUndoBuffer);
var
  p, p1: PfrUndoObj;
  r: PfrUndoRec1;
  BufferLength: Integer;
  List: TFpList;
  a: TfrUndoAction;
begin
  if Buffer = @FUndoBuffer then
    BufferLength := FUndoBufferLength
  else
    BufferLength := FRedoBufferLength;

  if (Buffer^[BufferLength - 1].Page <> CurPage) then Exit;

  List := TFpList.Create;
  a := Buffer^[BufferLength - 1].Action;
  p := Buffer^[BufferLength - 1].Objects;
  while p <> nil do
  begin
    GetMem(r, SizeOf(TfrUndoRec1));
    r^.ObjPtr := p^.ObjPtr;
    r^.Int := p^.Int;
    List.Add(r);
    case Buffer^[BufferLength - 1].Action of
      acInsert:
        begin
          r^.Int := Page.FindObjectByID(p^.ObjID);
          r^.ObjPtr := TfrView(Objects[r^.Int]);
          a := acDelete;
        end;
      acDelete: a := acInsert;
      acEdit:   r^.ObjPtr := TfrView(Objects[p^.Int]);
      acZOrder:
        begin
          r^.Int := Page.FindObjectByID(p^.ObjID);
          r^.ObjPtr := TfrView(Objects[r^.Int]);
          p^.ObjPtr := r^.ObjPtr;
        end;
    end;
    p := p^.Next;
  end;
  if Buffer = @FUndoBuffer then
    AddAction(@FRedoBuffer, a, List) else
    AddAction(@FUndoBuffer, a, List);
  List.Free;

  p := Buffer^[BufferLength - 1].Objects;
  while p <> nil do
  begin
    case Buffer^[BufferLength - 1].Action of
      acInsert: Page.Delete(Page.FindObjectByID(p^.ObjID));
      acDelete: Objects.Insert(p^.Int, p^.ObjPtr);
      acEdit:
        begin
          TfrView(Objects[p^.Int]).Assign(p^.ObjPtr);
          p^.ObjPtr.Free;
        end;
      acZOrder: Objects[p^.Int] := p^.ObjPtr;
    end;
    p1 := p;
    p := p^.Next;
    FreeMem(p1, SizeOf(TfrUndoObj));
  end;

  if Buffer = @FUndoBuffer then
    Dec(FUndoBufferLength)
  else
    Dec(FRedoBufferLength);

  ResetSelection;
  PageView.Invalidate;
  edtUndo.Enabled := FUndoBufferLength > 0;
  edtRedo.Enabled := FRedoBufferLength > 0;
end;

procedure TfrDesignerForm.AddAction(Buffer: PfrUndoBuffer; a: TfrUndoAction; List: TFpList);
var
  i: Integer;
  p, p1: PfrUndoObj;
  r: PfrUndoRec1;
  t, t1: TfrView;
  BufferLength: Integer;
begin
  if Buffer = @FUndoBuffer then
    BufferLength := FUndoBufferLength
  else
    BufferLength := FRedoBufferLength;
  if BufferLength >= MaxUndoBuffer then
  begin
    ReleaseAction(Buffer^[0]);
    for i := 0 to MaxUndoBuffer - 2 do
      Buffer^[i] := Buffer^[i + 1];
    BufferLength := MaxUndoBuffer - 1;
  end;
  Buffer^[BufferLength].Action := a;
  Buffer^[BufferLength].Page := CurPage;
  Buffer^[BufferLength].Objects := nil;
  p := nil;
  for i := 0 to List.Count - 1 do
  begin
    r := List[i];
    t := r^.ObjPtr;
    GetMem(p1, SizeOf(TfrUndoObj));
    p1^.Next := nil;

    if Buffer^[BufferLength].Objects = nil then
      Buffer^[BufferLength].Objects := p1
    else
      p^.Next := p1;
      
    p := p1;
    case a of
      acInsert: p^.ObjID := t.ID;
      acDelete, acEdit:
        begin
          t1 := frCreateObject(t.Typ, t.ClassName, nil);
          t1.Assign(t);
          t1.ID := t.ID;
          p^.ObjID := t.ID;
          p^.ObjPtr := t1;
          p^.Int := r^.Int;
        end;
      acZOrder:
        begin
          p^.ObjID := t.ID;
          p^.Int := r^.Int;
        end;
    end;
    FreeMem(r, SizeOf(TfrUndoRec1));
  end;
  if Buffer = @FUndoBuffer then
  begin
    FUndoBufferLength := BufferLength + 1;
    edtUndo.Enabled := True;
  end
  else
  begin
    FRedoBufferLength := BufferLength + 1;
    edtRedo.Enabled := True;
  end;
  Modified := True;
  //FileModified := True;
end;

procedure TfrDesignerForm.AddUndoAction(AUndoAction: TfrUndoAction);
var
  i,j: Integer;
  t: TfrView;
  List: TFpList;
  F:boolean;

  procedure AddCurrent;
  var
    p: PfrUndoRec1;
  begin
    GetMem(p, SizeOf(TfrUndoRec1));
    p^.ObjPtr := t;
    p^.Int := i;
    List.Add(p);
  end;

begin
  ClearRedoBuffer;
  if not Assigned(Objects) then exit;

  List := TFpList.Create;

  // last FDuplicateList.Count objectes were duplicated
  if AUndoAction = acDuplication then
    j := Objects.Count - FDuplicateList.Count
  else
    j := 0;

  for i := j to Objects.Count - 1 do
  begin
    t := TfrView(Objects[i]);
    F:= ((AUndoAction = acDelete) and not (lrrDontDelete in t.Restrictions))
      or
        ((AUndoAction = acEdit) and not (lrrDontModify in t.Restrictions))
      or
        (not (AUndoAction in [acDelete, acEdit]));

    if (not (doUndoDisable in T.DesignOptions)) and ((AUndoAction in [acDuplication, acZOrder]) or t.Selected) and F then
      AddCurrent;
  end;

  if List.Count>0 then
  begin
    if AUndoAction = acDuplication then
       AUndoAction := acInsert;
    AddAction(@FUndoBuffer, AUndoAction, List);
  end;
  List.Free;
end;

procedure TfrDesignerForm.BeforeChange;
begin
  AddUndoAction(acEdit);
end;

procedure TfrDesignerForm.AfterChange;
begin
  PageView.NPDrawSelection;
  PageView.NPDrawLayerObjects(0, TopSelected);
  ObjInspRefresh;
  DataInspectorRefresh;
end;

//Move selected object from front
procedure TfrDesignerForm.ZB1Click(Sender: TObject);   // go up
var
  i, j, n: Integer;
  t: TfrView;
begin
  AddUndoAction(acZOrder);
  n:=Objects.Count;
  i:=0;
  j:=0;
  while j < n do
  begin
    t := TfrView(Objects[i]);
    if t.Selected then
    begin
      Objects.Delete(i);
      Objects.Add(t);
    end
    else Inc(i);
    Inc(j);
  end;
  SendBandsToDown;
  RedrawPage;
end;

//Send selected object to back
procedure TfrDesignerForm.ZB2Click(Sender: TObject);    // go down
var
  t: TfrView;
  i, j, n: Integer;
begin
  AddUndoAction(acZOrder);
  n:=Objects.Count;
  j:=0;
  i:=n-1;
  while j < n do
  begin
    t := TfrView(Objects[i]);
    if t.Selected then
    begin
      Objects.Delete(i);
      Objects.Insert(0, t);
    end
    else Dec(i);
    Inc(j);
  end;
  SendBandsToDown;
  RedrawPage;
end;

procedure TfrDesignerForm.PgB1Click(Sender: TObject); // add page
begin
  ResetSelection;
  if Sender<>pgB4 then
     AddPage('TfrPageReport')
  else
     AddPage('TfrPageDialog');
end;

procedure TfrDesignerForm.PgB2Click(Sender: TObject); // remove page
begin
  if MessageDlg(sRemovePg,mtConfirmation,[mbYes,mbNo],0)=mrYes then
       RemovePage(CurPage);
end;

procedure TfrDesignerForm.OB1Click(Sender: TObject);
begin
  ObjRepeat := False;
end;

procedure TfrDesignerForm.OB2MouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  ObjRepeat := ssShift in Shift;
  PageView.Cursor := crDefault;
end;

procedure TfrDesignerForm.CutBClick(Sender: TObject); //cut
begin
  AddUndoAction(acDelete);
  CutToClipboard;
  FirstSelected := nil;
  EnableControls;
  ShowPosition;
  RedrawPage;
end;

procedure TfrDesignerForm.CopyBClick(Sender: TObject); //copy
begin
  CopyToClipboard;
  EnableControls;
end;

procedure TfrDesignerForm.PstBClick(Sender: TObject); //paste
var
  i, minx, miny, xoffset, yoffset: Integer;
  t, t1: TfrView;
begin
  Unselect;
  SelNum := 0;
  minx := 32767;
  miny := 32767;
  xoffset := FReportPopupPoint.x;
  yoffset := FReportPopupPoint.y;
  for i := 0 to ClipBd.Count-1 do
  begin
    t := TfrView(ClipBd[i]);
    if t.x < minx then minx := t.x;
    if t.y < miny then miny := t.y;
  end;
  for i := 0 to ClipBd.Count - 1 do
  begin
    t := TfrView(ClipBd[i]);
    if t.Typ = gtBand then
      if not (TfrBandView(t).BandType in [btMasterHeader..btSubDetailFooter,
                                          btGroupHeader, btGroupFooter]) and
        frCheckBand(TfrBandView(t).BandType) then
        continue;
    t.x := t.x - minx + xoffset;
    if PageView.Left < 0 then
      t.x := t.x + ((-PageView.Left) div GridSize * GridSize);
    t.y := t.y - miny + yoffset;
    if PageView.Top < 0 then
      t.y := t.y + ((-PageView.Top) div GridSize * GridSize);
    Inc(SelNum);
    t1 := frCreateObject(t.Typ, t.ClassName, Page);
    t1.Assign(t);
    if CurReport.FindObject(t1.Name) <> nil then
      t1.CreateUniqueName;
  end;
  SelectionChanged;
  SendBandsToDown;
  PageView.GetMultipleSelected;
  RedrawPage;
  AddUndoAction(acInsert);
end;

procedure TfrDesignerForm.SelAllBClick(Sender: TObject); // select all
begin
  PageView.NPEraseSelection;
  SelectAll;
  PageView.GetMultipleSelected;
  PageView.NPDrawSelection;
  SelectionChanged;
end;

procedure TfrDesignerForm.ExitBClick(Sender: TObject);
begin
  {$IFDEF MODALDESIGNER}
  ModalResult := mrOk;
  {$ELSE}
  Close;
  {$ENDIF}
end;


procedure TfrDesignerForm.N5Click(Sender: TObject); // popup delete command
begin
  DeleteObjects;
end;

procedure TfrDesignerForm.N6Click(Sender: TObject); // popup edit command
begin
  ShowEditor;
end;

procedure TfrDesignerForm.FileBtn1Click(Sender: TObject); // create new
begin
  CreateNewReport;
end;

procedure TfrDesignerForm.N23Click(Sender: TObject); // create new from template
begin
  frTemplForm := TfrTemplForm.Create(nil);
  with frTemplForm do
  if ShowModal = mrOk then
  begin
    if DefaultTemplate then
      CreateNewReport
    else
    begin
      ClearUndoBuffer;
      if ExtractFileExt(TemplName) = '.lrt' then
        CurReport.LoadTemplateXML(TemplName, nil, nil, True)
      else
        CurReport.LoadTemplate(TemplName, nil, nil, True);
      CurDocName := sUntitled;
      CurPage := 0; // do all
    end;
  end;
  frTemplForm.Free;
end;

procedure TfrDesignerForm.N42Click(Sender: TObject); // var editor
begin
  if ShowEvEditor(CurReport) then
    Modified := True;
end;

procedure TfrDesignerForm.PgB3Click(Sender: TObject); // page setup
var
  w, h, p: Integer;
  function PointsToMMStr(value:Integer): string;
  begin
    result := IntToStr(Trunc(value*5/18+0.5));
  end;
  function MMStrToPoints(value:string): Integer;
  begin
    result := Trunc(Trunc(StrToFloatDef(value, 0.0))*18/5+0.5)
  end;
begin
  frPgoptForm := TfrPgoptForm.Create(nil);
  with frPgoptForm, Page do
  begin
    CB1.Checked := PrintToPrevPage;
    CB5.Checked := not UseMargins;
    if Orientation = poPortrait then
      RB1.Checked := True
    else
      RB2.Checked := True;
    Prn.FillPapers(COMB1.Items);
    ComB1.ItemIndex := COMB1.Items.IndexOfObject(TObject(PtrInt(pgSize)));
    E1.Text := ''; E2.Text := '';

    if pgSize = $100 then
    begin
      PaperWidth := round(Width * 25.4 / 72);      // pt to mm
      PaperHeight := round(Height * 25.4 / 72);    // pt to mm
    end;
    
    E3.Text := PointsToMMStr(Margins.Left);
    E4.Text := PointsToMMStr(Margins.Top);
    E5.Text := PointsToMMStr(Margins.Right);
    E6.Text := PointsToMMStr(Margins.Bottom);
    E7.Text := PointsToMMStr(ColGap);

    ecolCount.Value := ColCount;
    if LayoutOrder = loColumns then
      RBColumns.Checked := true
    else
      RBRows.Checked := true;
    WasOk := False;
    if ShowModal = mrOk then
    begin
      Modified := True;
//      FileModified := True;
      WasOk := True;
      PrintToPrevPage :=  CB1.Checked;
      UseMargins := not CB5.Checked;
      if RB1.Checked then
        Orientation := poPortrait
      else
        Orientation := poLandscape;
      if RBColumns.Checked then
        LayoutOrder := loColumns
      else
        LayoutOrder := loRows;
        
      p := frPgoptForm.pgSize;
      w := 0; h := 0;
      if p = $100 then
        try
          w := round(PaperWidth * 72 / 25.4);    // mm to pt
          h := round(PaperHeight * 72 / 25.4);   // mm to pt
        except
          on exception do p := 9; // A4
        end;

      Margins.Left := MMStrToPoints(E3.Text);
      Margins.Top := MMStrToPoints(E4.Text);
      Margins.Right := MMStrToPoints(E5.Text);
      Margins.Bottom := MMStrToPoints(E6.Text);
      ColGap := MMStrToPoints(E7.Text);

      ColCount := ecolCount.Value;
      ChangePaper(p, w, h, Orientation);
      CurPage := CurPage; // for repaint and other
      UpdScrollbars;
    end;
  end;
  frPgoptForm.Free;
end;

procedure TfrDesignerForm.N8Click(Sender: TObject); // report setup
begin
  frDocOptForm := TfrDocOptForm.Create(nil);
  with frDocOptForm do
  begin
    CB1.Checked     := not CurReport.PrintToDefault;
    CB2.Checked     := CurReport.DoublePass;
    edTitle.Text    := CurReport.Title;
    edComments.Text := CurReport.Comments.Text;
    edKeyWords.Text := CurReport.KeyWords;
    edSubject.Text  := CurReport.Subject;
    edAutor.Text    := CurReport.ReportAutor;
    edtMaj.Text     := CurReport.ReportVersionMajor;
    edtMinor.Text   := CurReport.ReportVersionMinor;
    edtRelease.Text := CurReport.ReportVersionRelease;
    edtBuild.Text   := CurReport.ReportVersionBuild;
    edtRepCreateDate.Text   := DateTimeToStr(CurReport.ReportCreateDate);
    edtRepLastChangeDate.Text   := DateTimeToStr(CurReport.ReportLastChange);
    if ShowModal = mrOk then
    begin
      CurReport.PrintToDefault := not CB1.Checked;
      CurReport.DoublePass := CB2.Checked;
      CurReport.ChangePrinter(Prn.PrinterIndex, ListBox1.ItemIndex);
      {$IFDEF USE_PRINTER_FONTS}
      // printer may have been changed, invalidate current list of fonts
      C2.Items.Clear;
      {$ENDIF}
      CurReport.Title:=edTitle.Text;
      CurReport.Subject:=edSubject.Text;
      CurReport.KeyWords:=edKeyWords.Text;
      CurReport.Comments.Text:=edComments.Text;
      CurReport.ReportVersionMajor:=edtMaj.Text;
      CurReport.ReportVersionMinor:=edtMinor.Text;
      CurReport.ReportVersionRelease:=edtRelease.Text;
      CurReport.ReportVersionBuild:=edtBuild.Text;
      CurReport.ReportAutor:=edAutor.Text;
      Modified := True;
    end;
    CurPage := CurPage;
    Free;
  end;
end;

procedure TfrDesignerForm.N14Click(Sender: TObject); // grid menu
var
  DesOptionsForm: TfrDesOptionsForm;
begin
  DesOptionsForm := TfrDesOptionsForm.Create(nil);
  with DesOptionsForm do
  begin
    CB1.Checked := ShowGrid;
    CB2.Checked := GridAlign;
    case GridSize of
      4: RB1.Checked := True;
      8: RB2.Checked := True;
      18: RB3.Checked := True;
    end;
    if ShapeMode = smFrame then
      RB4.Checked := True
    else
      RB5.Checked := True;
      
    case Units of
      ruPixels: RB6.Checked := True;
      ruMM:     RB7.Checked := True;
      ruInches: RB8.Checked := True;
    end;
    
    //CB3.Checked := not GrayedButtons;
    CB4.Checked := EditAfterInsert;
    CB5.Checked := ShowBandTitles;

    DesOptionsForm.ComboBox2.Text:=edtScriptFontName;
    DesOptionsForm.SpinEdit2.Value:=edtScriptFontSize;
    DesOptionsForm.CheckBox2.Checked:=edtUseIE;

    if ShowModal = mrOk then
    begin
      ShowGrid := CB1.Checked;
      GridAlign := CB2.Checked;
      if RB1.Checked then
        GridSize := 4
      else if RB2.Checked then
        GridSize := 8
      else
        GridSize := 18;
      if RB4.Checked then
        ShapeMode := smFrame
      else
        ShapeMode := smAll;
      if RB6.Checked then
        Units := ruPixels
      else if RB7.Checked then
        Units := ruMM
      else
        Units := ruInches;
      //GrayedButtons := not CB3.Checked;
      EditAfterInsert := CB4.Checked;
      ShowBandTitles := CB5.Checked;

      edtScriptFontName:=DesOptionsForm.ComboBox2.Text;
      edtScriptFontSize:=DesOptionsForm.SpinEdit2.Value;
      edtUseIE:=DesOptionsForm.CheckBox2.Checked;

      RedrawPage;
      SaveState;
    end;
    Free;
  end;
end;

procedure TfrDesignerForm.GB1Click(Sender: TObject);
begin
  ShowGrid := GB1.Down;
end;

procedure TfrDesignerForm.ScrollBox1DragDrop(Sender, Source: TObject; X,
  Y: Integer);
var
  Control :TControl;
  t : TfrCustomMemoView;
  dx, dy:integer;
begin
  Control:=lrDesignAcceptDrag(Source);
  if Assigned(lrFieldsList) and ((Control = lrFieldsList.lbFieldsList) or (Control = lrFieldsList.ValList)) then
  begin

{    Objects.Add(frCreateObject(gtMemo, '', Page));
    t:=TfrCustomMemoView(Objects.Last);}
    t:=frCreateObject(gtMemo, '', Page) as TfrCustomMemoView;
    if Assigned(t) then
    begin
      t.MonitorFontChanges;
      t.Memo.Text:='['+lrFieldsList.SelectedField+']';

      t.CreateUniqueName;
      t.Canvas:=Canvas;

      GetDefaultSize(dx, dy);

      t.x := X;
      t.y := Y;
      t.dx := DX;
      t.dy := DY;

      {$ifdef ppaint}
      PageView.NPEraseSelection;
      {$endif}
      Unselect;

      t.FrameWidth := LastFrameWidth;
      t.FrameColor := LastFrameColor;
      t.FillColor  := LastFillColor;
      t.Selected   := True;

      if t.Typ <> gtBand then
        t.Frames:=LastFrames;

      t.Font.Name := LastFontName;
      t.Font.Size := LastFontSize;
      t.Font.Color := LastFontColor;
      t.Font.Style := frSetFontStyle(LastFontStyle);
      t.Adjust := LastAdjust;

      SelNum := 1;
      PageView.NPRedrawViewCheckBand(t);

      SelectionChanged;
      AddUndoAction(acInsert);

      if Page is TfrPageReport then
        OB1.Down := True
      else
        OB7.Down := True

    end;
  end;
end;

procedure TfrDesignerForm.ScrollBox1DragOver(Sender, Source: TObject; X,
  Y: Integer; State: TDragState; var Accept: Boolean);
var
  Control :TControl;
begin
  Accept:= false;
  if Page is TfrPageDialog then Exit;
  Control:=lrDesignAcceptDrag(Source);
  if Assigned(lrFieldsList) then
    Accept:= (Control = lrFieldsList.lbFieldsList) or (Control = lrFieldsList.ValList);
end;

procedure TfrDesignerForm.IEButtonClick(Sender: TObject);
var
  P: TPoint;
begin
  P:=IEButton.ClientToScreen(Point(IEButton.Width, IEButton.Height));
  IEPopupMenu.PopUp(P.X, P.Y);
end;

procedure TfrDesignerForm.tlsDBFieldsExecute(Sender: TObject);
begin
  if Assigned(lrFieldsList) then
    FreeThenNil(lrFieldsList)
  else
    lrFieldsList:=TlrFieldsList.Create(Self);
  tlsDBFields.Checked:=Assigned(lrFieldsList);
end;

procedure TfrDesignerForm.GB2Click(Sender: TObject);
begin
  GridAlign := GB2.Down;
end;

procedure TfrDesignerForm.GB3Click(Sender: TObject);
var
  i: Integer;
  t: TfrView;
begin
  AddUndoAction(acEdit);
  for i := 0 to Objects.Count - 1 do
  begin
    t := TfrView(Objects[i]);
    if t.Selected then
    begin
      t.x := Round(t.x / GridSize) * GridSize;
      t.y := Round(t.y / GridSize) * GridSize;
      t.dx := Round(t.dx / GridSize) * GridSize;
      t.dy := Round(t.dy / GridSize) * GridSize;
      if t.dx = 0 then t.dx := GridSize;
      if t.dy = 0 then t.dy := GridSize;
    end;
  end;
  RedrawPage;
  ShowPosition;
  PageView.GetMultipleSelected;
end;

procedure TfrDesignerForm.Tab1Change(Sender: TObject);
begin
  if not fInBuildPage and (Tab1.TabIndex>=0) and (CurPage<>Tab1.TabIndex) then
    CurPage := Tab1.TabIndex;
end;

procedure TfrDesignerForm.Popup1Popup(Sender: TObject);
var
  i: Integer;
  t, t1: TfrView;
  fl: Boolean;
begin
  FReportPopupPoint := PageView.ScreenToClient(Popup1.PopupPoint);
  DeleteMenuItems(N2.Parent);
  EnableControls;

  while Popup1.Items.Count > 7 do
    Popup1.Items.Delete(7);

  if SelNum = 1 then
  begin
    DefineExtraPopupSelected(Popup1);
    TfrView(Objects[TopSelected]).DefinePopupMenu(Popup1);
  end
  else
    if SelNum > 1 then
    begin
      t := TfrView(Objects[TopSelected]);
      fl := True;
      for i := 0 to Objects.Count - 1 do
      begin
        t1 := TfrView(Objects[i]);
        if t1.Selected then
          if not (((t is TfrCustomMemoView) and (t1 is TfrCustomMemoView)) or
             ((t.Typ <> gtAddIn) and (t.Typ = t1.Typ)) or
             ((t.Typ = gtAddIn) and (t.ClassName = t1.ClassName))) then
          begin
            fl := False;
            break;
          end;
      end;
      
      if fl and not (t.Typ = gtBand) then
        t.DefinePopupMenu(Popup1);
    end;

  FillMenuItems(N2.Parent);
  SetMenuItemBitmap(N2, CutB);
  SetMenuItemBitmap(N1, CopyB);
  SetMenuItemBitmap(N3, PstB);
  SetMenuItemBitmap(N16, SelAllB);
end;

procedure TfrDesignerForm.N37Click(Sender: TObject);
begin // toolbars
  Pan1.Checked := Panel1.IsVisible;
  Pan2.Checked := Panel2.IsVisible;
  Pan3.Checked := Panel3.IsVisible;
  Pan4.Checked := Panel4.IsVisible;
  Pan5.Checked := ObjInsp.Visible;
  Pan6.Checked := Panel5.Visible;
  Pan7.Checked := Panel6.Visible;
end;

procedure TfrDesignerForm.Pan2Click(Sender: TObject);

  procedure SetShow(c: Array of TWinControl; i: Integer; b: Boolean);
  begin
    if c[i] is TPanel then
    begin
      with c[i] as TPanel do
      begin
        Visible:=b;
        {if IsFloat then
          FloatWindow.Visible := b
        else
        begin
          if b then
            AddToDock(Parent as TPanel);
          Visible := b;
          (Parent as TPanel).AdjustBounds;
        end; }
      end;
    end
    else  TForm(c[i]).Visible:=b;
  end;

begin // each toolbar
  with Sender as TMenuItem do
  begin
    Checked := not Checked;
    SetShow([Panel1, Panel2, Panel3, Panel4, Panel5, ObjInsp, Panel6], Tag, Checked);
  end;
end;

procedure TfrDesignerForm.N34Click(Sender: TObject);
begin // about box
  frAboutForm := TfrAboutForm.Create(nil);
  frAboutForm.ShowModal;
  frAboutForm.Free;
end;

procedure TfrDesignerForm.Tab1MouseDown(Sender: TObject;
  Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  p: TPoint;
begin
  GetCursorPos(p{%H-});
  
  if Button = mbRight then
    Popup2.PopUp(p.X,p.Y);
    
 //**
 {if Button = mbRight then
    TrackPopupMenu(Popup2.Handle,
      TPM_LEFTALIGN or TPM_RIGHTBUTTON, p.X, p.Y, 0, Handle, nil);
 }
end;

procedure TfrDesignerForm.frDesignerFormClose(Sender: TObject;
  var CloseAction: TCloseAction);
begin
  ObjInsp.ShowHint := False;
end;

procedure TfrDesignerForm.frDesignerFormCloseQuery(Sender: TObject;
  var CanClose: boolean);
var
  Res:integer;
begin
//  if FileModified and (CurReport<>nil) and
  if (not PreparedReportEditor) and Modified and (CurReport<>nil) and
    (not ((csDesigning in CurReport.ComponentState) and CurReport.StoreInForm)) then
  begin
    Res:=Application.MessageBox(PChar(sSaveChanges + ' ' + sTo + ' ' + ExtractFileName(CurDocName) + '?'),
      PChar(sConfirm), mb_IconQuestion + mb_YesNoCancel);
      
    case Res of
      mrNo:
        begin
          CanClose := True;
//          FileModified := False; // no means don't want changes
          Modified := False; // no means don't want changes
          ModalResult := mrCancel;
        end;
      mrYes:
          begin
            FileSave.Execute;
//            FileBtn3Click(nil);
//            CanClose := not FileModified;
            CanClose := not Modified;
          end;
    else
      CanClose := False;
    end;
  end;
end;

{----------------------------------------------------------------------------}
// state storing/retrieving
const
  rsGridShow = 'GridShow';
  rsGridAlign = 'GridAlign';
  rsGridSize = 'GridSize';
  rsGuidesShow = 'GuidesShow';
  rsUnits = 'Units';
  rsButtons = 'GrayButtons';
  rsEdit = 'EditAfterInsert';
  rsSelection = 'Selection';


procedure TfrDesignerForm.SaveState;
var
  Ini:TIniFile;

  procedure DoSaveToolbars(t: Array of TPanel);
  var
    i: Integer;
  begin
    for i := Low(t) to High(t) do
    begin
{      if FirstInstance or (t[i] <> Panel6) then
        SaveToolbarPosition(t[i]);
      t[i].IsVisible:= False;}
    end;
  end;

begin
  Ini:=TIniFile.Create(UTF8ToSys(IniFileName));
  Ini.WriteString('frEditorForm', 'ScriptFontName', edtScriptFontName);
  Ini.WriteInteger('frEditorForm', 'ScriptFontSize', edtScriptFontSize);

  Ini.WriteBool('frEditorForm', rsGridShow, ShowGrid);
  Ini.WriteBool('frEditorForm', rsGridAlign, GridAlign);
  Ini.WriteBool('frEditorForm', rsGuidesShow, ShowGuides);
  Ini.WriteInteger('frEditorForm', rsGridSize, GridSize);
  Ini.WriteInteger('frEditorForm', rsUnits, Word(Units));
  Ini.WriteBool('frEditorForm', rsButtons, GrayedButtons);
  Ini.WriteBool('frEditorForm', rsEdit, EditAfterInsert);
  Ini.WriteInteger('frEditorForm', rsSelection, Integer(ShapeMode));
  Ini.WriteBool('frEditorForm', 'UseInplaceEditor', edtUseIE);
  Ini.WriteString('frEditorForm', 'LastOpenDirectory', FLastOpenDirectory);
  Ini.WriteString('frEditorForm', 'LastSaveDirectory', FLastSaveDirectory);

  DoSaveToolbars([Panel1, Panel2, Panel3, Panel4, Panel5, Panel6]);

  //  Save ObjInsp Position
  Ini.WriteInteger('ObjInsp', 'Left', ObjInsp.Left);
  Ini.WriteInteger('ObjInsp', 'Top', ObjInsp.Top);
{  if IEButton.Caption = '+' then
    Ini.WriteInteger('Position', 'Height', FLastHeight)
  else
    Ini.WriteInteger('Position', 'Height', Height);}
  Ini.WriteInteger('ObjInsp', 'Width', ObjInsp.Width);
  Ini.WriteBool('ObjInsp', 'Visible', ObjInsp.Visible);

  Ini.Free;
//  ObjInsp.Visible:=False;
end;

procedure TfrDesignerForm.RestoreState;
var
  Ini:TIniFile;

{var
  Ini: TRegIniFile;
  Nm: String;
  
//**  procedure DoRestoreToolbars(t: Array of TPanel);
  var
    i: Integer;
  begin
    for i := Low(t) to High(t) do
      RestoreToolbarPosition(t[i]);
  end;
}
begin
  if FileExistsUTF8(IniFileName) then
  begin
    Ini:=TIniFile.Create(UTF8ToSys(IniFileName));
    edtScriptFontName:=Ini.ReadString('frEditorForm', 'ScriptFontName', edtScriptFontName);
    edtScriptFontSize:=Ini.ReadInteger('frEditorForm', 'ScriptFontSize', edtScriptFontSize);
    GridSize := Ini.ReadInteger('frEditorForm', rsGridSize, 4);
    GridAlign := Ini.ReadBool('frEditorForm', rsGridAlign, True);
    ShowGrid := Ini.ReadBool('frEditorForm', rsGridShow, True);
    ShowGuides := Ini.ReadBool('frEditorForm', rsGuidesShow, true);
    Units := TfrReportUnits(Ini.ReadInteger('frEditorForm', rsUnits, 0));
//    GrayedButtons := Ini.ReadBool('frEditorForm', rsButtons, False);
    EditAfterInsert := Ini.ReadBool('frEditorForm', rsEdit, True);
    ShapeMode := TfrShapeMode(Ini.ReadInteger('frEditorForm', rsSelection, 1));
    edtUseIE:=Ini.ReadBool('frEditorForm', 'UseInplaceEditor', edtUseIE);
    FLastOpenDirectory := Ini.ReadString('frEditorForm', 'LastOpenDirectory', '');
    FLastSaveDirectory := Ini.ReadString('frEditorForm', 'LastSaveDirectory', '');

    ObjInsp.Left:=Ini.ReadInteger('ObjInsp', 'Left', ObjInsp.Left);
    ObjInsp.Top:=Ini.ReadInteger('ObjInsp', 'Top', ObjInsp.Top);
  {  if IEButton.Caption = '+' then
      Ini.WriteInteger('Position', 'Height', FLastHeight)
    else
      Ini.WriteInteger('Position', 'Height', Height);}
    ObjInsp.Width:=Ini.ReadInteger('ObjInsp', 'Width', ObjInsp.Width);
    ObjInsp.Visible:=Ini.ReadBool('ObjInsp', 'Visible', ObjInsp.Visible);

    Ini.Free;
  end;

  {  Ini := TRegIniFile.Create(RegRootKey);
  Nm := rsForm + Name;
  Ini.Free;
//**  DoRestoreToolbars([Panel1, Panel2, Panel3, Panel4, Panel5, Panel6]);
  if Panel6.Height < 26 then
    Panel6.Height := 26;
  if Panel6.Width < 26 then
    Panel6.Width := 26;
  if Panel6.ControlCount < 2 then
    Panel6.Hide;
  frDock1.AdjustBounds;
  frDock2.AdjustBounds;
  frDock3.AdjustBounds;
  frDock4.AdjustBounds;
  RestoreFormPosition(InspForm);
}
  //TODO: restore ObjInsp position and size
(*
  GridSize := 4;
  GridAlign := True;
  ShowGrid := False; //True;
  Units := TfrReportUnits(0);
  //GrayedButtons := True; //False;
  EditAfterInsert := True;
  ShapeMode := TfrShapeMode(1);
*)

  if Panel6.Height < 26 then
    Panel6.Height := 26;
  if Panel6.Width < 26 then
    Panel6.Width := 26;
  if Panel6.ControlCount < 2 then
    Panel6.Hide;
end;


{----------------------------------------------------------------------------}
// menu bitmaps
procedure TfrDesignerForm.SetMenuBitmaps;
begin
  MaxItemWidth := 0; MaxShortCutWidth := 0;

  FillMenuItems(FileMenu);
  FillMenuItems(EditMenu);
  FillMenuItems(ToolMenu);
  FillMenuItems(HelpMenu);

  SetMenuItemBitmap(N23, FileBtn1);
//  SetMenuItemBitmap(N19, FileBtn2);
//  SetMenuItemBitmap(N20, FileBtn3);
//  SetMenuItemBitmap(N39, FileBtn4);
  SetMenuItemBitmap(N10, ExitB);

  SetMenuItemBitmap(N11, CutB);
  SetMenuItemBitmap(N12, CopyB);
  SetMenuItemBitmap(N13, PstB);
  SetMenuItemBitmap(N28, SelAllB);
  SetMenuItemBitmap(N29, PgB1);
  SetMenuItemBitmap(N30, PgB2);
  SetMenuItemBitmap(N32, ZB1);
  SetMenuItemBitmap(N33, ZB2);
  SetMenuItemBitmap(N35, HelpBtn);
{
  for i := 0 to  Panel6.ControlCount-1 - 1 do
  begin
    if Panel6.Controls[i] is TSpeedButton then
      SetMenuItemBitmap(MastMenu.Items[i], Panel6.Controls[i] as TSpeedButton);
  end;
}
  SetMenuItemBitmap(N41, PgB1);
  SetMenuItemBitmap(N43, PgB2);
  SetMenuItemBitmap(N44, PgB3);
end;

function TfrDesignerForm.FindMenuItem(AMenuItem: TMenuItem): TfrMenuItemInfo;
var
  i: Integer;
begin
  Result := nil;
  for i := 0 to MenuItems.Count - 1 do
    if TfrMenuItemInfo(MenuItems[i]).MenuItem = AMenuItem then
    begin
      Result := TfrMenuItemInfo(MenuItems[i]);
      Exit;
    end;
end;

procedure TfrDesignerForm.SetMenuItemBitmap(AMenuItem: TMenuItem; ABtn: TSpeedButton);
var
  m: TfrMenuItemInfo;
begin
  m := FindMenuItem(AMenuItem);
  if m = nil then
  begin
    m := TfrMenuItemInfo.Create;
    m.MenuItem := AMenuItem;
    MenuItems.Add(m);
  end;
  m.Btn := ABtn;
//**
{  ModifyMenu(AMenuItem.Parent.Handle, AMenuItem.MenuIndex,
    MF_BYPOSITION + MF_OWNERDRAW, AMenuItem.Command, nil);
}
end;

procedure TfrDesignerForm.FillMenuItems(MenuItem: TMenuItem);
var
  i: Integer;
  m: TMenuItem;
begin
  for i := 0 to MenuItem.Count - 1 do
  begin
    m := MenuItem.Items[i];
    SetMenuItemBitmap(m, nil);
    if m.Count > 0 then FillMenuItems(m);
  end;
end;

procedure TfrDesignerForm.DeleteMenuItems(MenuItem: TMenuItem);
var
  i, j: Integer;
  m: TMenuItem;
begin
  for i := 0 to MenuItem.Count - 1 do
  begin
    m := MenuItem.Items[i];
    for j := 0 to MenuItems.Count - 1 do
    if TfrMenuItemInfo(MenuItems[j]).MenuItem = m then
    begin
      TfrMenuItemInfo(MenuItems[j]).Free;
      MenuItems.Delete(j);
      break;
    end;
  end;
end;

procedure TfrDesignerForm.DoDrawText(aCanvas: TCanvas; aCaption: string;
  Rect: TRect; Selected, aEnabled: Boolean; Flags: Longint);
begin
  with aCanvas do
  begin
    Brush.Style := bsClear;
    if not aEnabled then
    begin
      if not Selected then
      begin
        OffsetRect(Rect, 1, 1);
        Font.Color := clBtnHighlight;
        DrawText(Handle, PChar(Caption), Length(Caption), Rect, Flags);
        OffsetRect(Rect, -1, -1);
      end;
      Font.Color := clBtnShadow;
    end;
    DrawText(Handle, PChar(aCaption), Length(aCaption), Rect, Flags);
    
    Brush.Style := bsSolid;
  end;
end;

procedure TfrDesignerForm.DrawItem(AMenuItem: TMenuItem; ACanvas: TCanvas;
  ARect: TRect; Selected: Boolean);
var
  GlyphRect: TRect;
  Btn: TSpeedButton;
  Glyph: TBitmap;
begin
  MaxItemWidth := 0;
  MaxShortCutWidth := 0;
  with ACanvas do
  begin
    if Selected then
    begin
      Brush.Color := clHighlight;
      Font.Color := clHighlightText
    end
    else
    begin
      Brush.Color := clMenu;
      Font.Color := clMenuText;
    end;
    if AMenuItem.Caption <> '-' then
    begin
      FillRect(ARect);
      Btn := FindMenuItem(AMenuItem).Btn;
      GlyphRect := Bounds(ARect.Left + 1, ARect.Top + (ARect.Bottom - ARect.Top - 16) div 2, 16, 16);

      if AMenuItem.Checked then
      begin
        Glyph := TBitmap.Create;
        if AMenuItem.RadioItem then
        begin
          // todo
          //** Glyph.Handle := LoadBitmap(hInstance, 'FR_RADIO');
          //BrushCopy(GlyphRect, Glyph, Rect(0, 0, 16, 16), Glyph.TransparentColor);
        end
        else
        begin
          //** Glyph.Handle := LoadBitmap(hInstance, 'FR_CHECK');
          Draw(GlyphRect.Left, GlyphRect.Top, Glyph);
        end;
        Glyph.Free;
      end
      else if Btn <> nil then
      begin
        Glyph := TBitmap.Create;
        Glyph.Width := 16; Glyph.Height := 16;
        // todo
        //** Btn.DrawGlyph(Glyph.Canvas, 0, 0, AMenuItem.Enabled);
        //BrushCopy(GlyphRect, Glyph, Rect(0, 0, 16, 16), Glyph.TransparentColor);
        Glyph.Free;
      end;
      ARect.Left := GlyphRect.Right + 4;
    end;

    if AMenuItem.Caption <> '-' then
    begin
      OffsetRect(ARect, 0, 2);
      DoDrawText(ACanvas, AMenuItem.Caption, ARect, Selected, AMenuItem.Enabled, DT_LEFT);
      if AMenuItem.ShortCut <> 0 then
      begin
        ARect.Left := StrToInt(ItemWidths.Values[AMenuItem.Parent.Name]) + 6;
        DoDrawText(ACanvas, ShortCutToText(AMenuItem.ShortCut), ARect,
          Selected, AMenuItem.Enabled, DT_LEFT);
      end;
    end
    else
    begin
      Inc(ARect.Top, 4);
      DrawEdge(Handle, ARect, EDGE_ETCHED, BF_TOP);
    end;
  end;
end;

procedure TfrDesignerForm.MeasureItem(AMenuItem: TMenuItem; ACanvas: TCanvas;
  var AWidth, AHeight: Integer);
var
  w: Integer;
begin
  w := ACanvas.TextWidth(AMenuItem.Caption) + 31;
  if MaxItemWidth < w then
    MaxItemWidth := w;
  ItemWidths.Values[AMenuItem.Parent.Name] := IntToStr(MaxItemWidth);

  if AMenuItem.ShortCut <> 0 then
  begin
    w := ACanvas.TextWidth(ShortCutToText(AMenuItem.ShortCut)) + 15;
    if MaxShortCutWidth < w then
      MaxShortCutWidth := w;
  end;

  if frGetWindowsVersion = '98' then
    AWidth := MaxItemWidth
  else
    AWidth := MaxItemWidth + MaxShortCutWidth;
  if AMenuItem.Caption <> '-' then
    AHeight := 19 else
    AHeight := 10;
end;

procedure TfrDesignerForm.WndProc(var Message: TLMessage);
//var
  //MenuItem: TMenuItem;
  //CCanvas: TCanvas;

  function FindItem(ItemId: Integer): TMenuItem;
  begin
    Result := MainMenu1.FindItem(ItemID, fkCommand);
    if Result = nil then
      Result := Popup1.FindItem(ItemID, fkCommand);
    if Result = nil then
      Result := Popup2.FindItem(ItemID, fkCommand);
  end;

begin
  case Message.Msg of
    LM_COMMAND:
      if Popup1.DispatchCommand(Message.wParam) or
         Popup2.DispatchCommand(Message.wParam) then Exit;
//**
{    LM_INITMENUPOPUP:
      with TWMInitMenuPopup(Message) do
        if Popup1.DispatchPopup(MenuPopup) or
           Popup2.DispatchPopup(MenuPopup) then Exit;
}
(*
    LM_DRAWITEM:
      with PDrawItemStruct(Message.LParam)^ do
      begin
        if (CtlType = ODT_MENU) and (Message.WParam = 0) then
        begin
          MenuItem := FindItem(ItemId);
          if MenuItem <> nil then
          begin
            CCanvas := TControlCanvas.Create;
            with CCanvas do
            begin
              Handle := _hDC;
              DrawItem(MenuItem, CCanvas, rcItem, ItemState{//** and ODS_SELECTED} <> 0);
              Free;
            end;
            Exit;
          end;
        end;
      end;
    LM_MEASUREITEM:
      with PMeasureItemStruct(Message.LParam)^ do
      begin
        if (CtlType = ODT_MENU) and (Message.WParam = 0) then
        begin
          MenuItem := FindItem(ItemId);
          if MenuItem <> nil then
          begin
            MeasureItem(MenuItem, Canvas, Integer(ItemWidth), Integer(ItemHeight));
            Exit;
          end;
        end;
      end;
*)
  end;
  inherited WndProc(Message);
end;


{----------------------------------------------------------------------------}
// alignment palette
function GetFirstSelected: TfrView;
begin
  if TfrDesignerForm(frDesigner).FirstSelected <> nil then
    Result := TfrDesignerForm(frDesigner).FirstSelected
  else
    Result :=TfrView(Objects[TopSelected]);
end;

function GetLeftObject: Integer;
var
  i: Integer;
  t: TfrView;
  x: Integer;
begin
  t := TfrView(Objects[TopSelected]);
  x := t.x;
  Result := TopSelected;
  for i := 0 to Objects.Count - 1 do
  begin
    t := TfrView(Objects[i]);
    if t.Selected then
      if t.x < x then
      begin
        x := t.x;
        Result := i;
      end;
  end;
end;

function GetRightObject: Integer;
var
  i: Integer;
  t: TfrView;
  x: Integer;
begin
  t :=TfrView(Objects[TopSelected]);
  x := t.x + t.dx;
  Result := TopSelected;
  for i := 0 to Objects.Count - 1 do
  begin
    t := TfrView(Objects[i]);
    if t.Selected then
      if t.x + t.dx > x then
      begin
        x := t.x + t.dx;
        Result := i;
      end;
  end;
end;

function GetTopObject: Integer;
var
  i: Integer;
  t: TfrView;
  y: Integer;
begin
  t := TfrView(Objects[TopSelected]);
  y := t.y;
  Result := TopSelected;
  for i := 0 to Objects.Count - 1 do
  begin
    t := TfrView(Objects[i]);
    if t.Selected then
      if t.y < y then
      begin
        y := t.y;
        Result := i;
      end;
  end;
end;

function GetBottomObject: Integer;
var
  i: Integer;
  t: TfrView;
  y: Integer;
begin
  t := TfrView(Objects[TopSelected]);
  y := t.y + t.dy;
  Result := TopSelected;
  for i := 0 to Objects.Count - 1 do
  begin
    t := TfrView(Objects[i]);
    if t.Selected then
      if t.y + t.dy > y then
      begin
        y := t.y + t.dy;
        Result := i;
      end;
  end;
end;

procedure TfrDesignerForm.Align1Click(Sender: TObject);
var
  i: Integer;
  t: TfrView;
  x: Integer;
begin
  if SelNum < 2 then Exit;
  BeforeChange;
  t := GetFirstSelected;
  x := t.x;
  for i := 0 to Objects.Count - 1 do
  begin
    t := TfrView(Objects[i]);
    if t.Selected then
      t.x := x;
  end;
  PageView.GetMultipleSelected;
  RedrawPage;
end;

procedure TfrDesignerForm.Align6Click(Sender: TObject);
var
  i: Integer;
  t: TfrView;
  y: Integer;
begin
  if SelNum < 2 then Exit;
  BeforeChange;
  t := GetFirstSelected;
  y := t.y;
  for i := 0 to Objects.Count - 1 do
  begin
    t := TfrView(Objects[i]);
    if t.Selected then
      t.y := y;
  end;
  PageView.GetMultipleSelected;
  RedrawPage;
end;

procedure TfrDesignerForm.Align5Click(Sender: TObject);
var
  i: Integer;
  t: TfrView;
  x: Integer;
begin
  if SelNum < 2 then Exit;
  BeforeChange;
  t := GetFirstSelected;
  x := t.x+t.dx;
  for i := 0 to Objects.Count - 1 do
  begin
    t := TfrView(Objects[i]);
    if t.Selected then
      t.x := x - t.dx;
  end;
  PageView.GetMultipleSelected;
  RedrawPage;
end;

procedure TfrDesignerForm.Align10Click(Sender: TObject);
var
  i: Integer;
  t: TfrView;
  y: Integer;
begin
  if SelNum < 2 then Exit;
  BeforeChange;
  t := GetFirstSelected;
  y := t.y + t.dy;
  for i := 0 to Objects.Count - 1 do
  begin
    t := TfrView(Objects[i]);
    if t.Selected then
      t.y := y - t.dy;
  end;
  PageView.GetMultipleSelected;
  RedrawPage;
end;

procedure TfrDesignerForm.Align2Click(Sender: TObject);
var
  i: Integer;
  t: TfrView;
  x: Integer;
begin
  if SelNum < 2 then Exit;
  BeforeChange;
  t := GetFirstSelected;
  x := t.x + t.dx div 2;
  for i := 0 to Objects.Count - 1 do
  begin
    t := TfrView(Objects[i]);
    if t.Selected then
      t.x := x - t.dx div 2;
  end;
  PageView.GetMultipleSelected;
  RedrawPage;
end;

procedure TfrDesignerForm.Align7Click(Sender: TObject);
var
  i: Integer;
  t: TfrView;
  y: Integer;
begin
  if SelNum < 2 then Exit;
  BeforeChange;
  t := GetFirstSelected;
  y := t.y + t.dy div 2;
  for i := 0 to Objects.Count - 1 do
  begin
    t := TfrView(Objects[i]);
    if t.Selected then
      t.y := y - t.dy div 2;
  end;
  PageView.GetMultipleSelected;
  RedrawPage;
end;

procedure TfrDesignerForm.Align3Click(Sender: TObject);
var
  i: Integer;
  t: TfrView;
  x: Integer;
begin
  if SelNum = 0 then Exit;
  BeforeChange;
  t := TfrView(Objects[GetLeftObject]);
  x := t.x;
  t := TfrView(Objects[GetRightObject]);
  x := x + (t.x + t.dx - x - Page.PrnInfo.Pgw) div 2;
  for i := 0 to Objects.Count - 1 do
  begin
    t := TfrView(Objects[i]);
    if t.Selected then Dec(t.x, x);
  end;
  PageView.GetMultipleSelected;
  RedrawPage;
end;

procedure TfrDesignerForm.Align8Click(Sender: TObject);
var
  i: Integer;
  t: TfrView;
  y: Integer;
begin
  if SelNum = 0 then Exit;
  BeforeChange;
  t := TfrView(Objects[GetTopObject]);
  y := t.y;
  t := TfrView(Objects[GetBottomObject]);
  y := y + (t.y + t.dy - y - Page.PrnInfo.Pgh) div 2;
  for i := 0 to Objects.Count - 1 do
  begin
    t := TfrView(Objects[i]);
    if t.Selected then Dec(t.y, y);
  end;
  PageView.GetMultipleSelected;
  RedrawPage;
end;

procedure TfrDesignerForm.Align4Click(Sender: TObject);
var
  s: TStringList;
  i, dx: Integer;
  t: TfrView;
begin
  if SelNum < 3 then Exit;
  BeforeChange;
  s := TStringList.Create;
  s.Sorted := True;
  s.Duplicates := dupAccept;
  for i := 0 to Objects.Count - 1 do
  begin
    t := TfrView(Objects[i]);
    if t.Selected then s.AddObject(Format('%4.4d', [t.x]), t);
  end;
  dx := (TfrView(s.Objects[s.Count - 1]).x - TfrView(s.Objects[0]).x) div (s.Count - 1);
  for i := 1 to s.Count - 2 do
    TfrView(s.Objects[i]).x := TfrView(s.Objects[i-1]).x + dx;
  s.Free;
  PageView.GetMultipleSelected;
  RedrawPage;
end;

procedure TfrDesignerForm.Align9Click(Sender: TObject);
var
  s: TStringList;
  i, dy: Integer;
  t: TfrView;
begin
  if SelNum < 3 then Exit;
  BeforeChange;
  s := TStringList.Create;
  s.Sorted := True;
  s.Duplicates := dupAccept;
  for i := 0 to Objects.Count - 1 do
  begin
    t := TfrView(Objects[i]);
    if t.Selected then s.AddObject(Format('%4.4d', [t.y]), t);
  end;
  dy := (TfrView(s.Objects[s.Count - 1]).y - TfrView(s.Objects[0]).y) div (s.Count - 1);
  for i := 1 to s.Count - 2 do
    TfrView(s.Objects[i]).y := TfrView(s.Objects[i - 1]).y + dy;
  s.Free;
  PageView.GetMultipleSelected;
  RedrawPage;
end;


{----------------------------------------------------------------------------}
// miscellaneous
function Objects: TFpList;
begin
  if Assigned(frDesigner) and Assigned(frDesigner.Page) then
    Result := frDesigner.Page.Objects
  else
    Result := nil;
end;

procedure frSetGlyph(aColor: TColor; sb: TSpeedButton; n: Integer);
var
  b : TBitmap;
  s : TMemoryStream;
  r : TRect;
  t : TfrView;
  i : Integer;
begin
  {$IFDEF DebugLR}
  DebugLn('frSetGlyph(%s,%s,%d)',[colortostring(acolor),sb.Name,n]);
  DebugLn('ColorLocked=%s sb.tag=%s',[dbgs(ColorLocked),dbgs(sb.tag)]);
  {$ENDIF}
  B:=sb.Glyph;
  b.Width := 32;
  b.Height:= 16;
  with b.Canvas do
  begin
    b.Canvas.Handle;  // force handle creation
    Brush.Color:=clWhite;
    FillRect(ClipRect);
    r := Rect(n * 32, 0, n * 32 + 32, 16);
    CopyRect(Rect(0, 0, 32, 16),
       TfrDesignerForm(frDesigner).Image1.Picture.Bitmap.Canvas, r);
    // JRA: workaround for copyrect not using transparency
    //      and bitmap using transparency only on reading stream
    S := TMemorystream.Create;
    B.SaveToStream(S);
    S.Position:=0;
    B.Transparent := True;
    B.LoadFromStream(S);
    S.Free;
    
    if aColor = clNone then
    begin
       Brush.Color:=clBtnFace;
       Pen.Color  :=clBtnFace;
    end
    else
    begin
       Brush.Color:=aColor;
       Pen.Color:=aColor;
    end;
    Rectangle(Rect(0,12,15,15));
  end;

  i:=TopSelected;
  if (i>-1) and not ColorLocked then
  begin
    t := TfrView(Objects[i]);
    {$IFDEF DebugLR}
    DebugLn('frSetGlyph: TopSelected=%s', [t.Name]);
    {$ENDIF}

    Case Sb.Tag of
      5 : t.FillColor:=aColor; {ClB1}
     17 : if (t is TfrCustomMemoView) then {ClB2}
               TfrCustomMemoView(t).Font.Color:=aColor;
     19 : t.FrameColor:=aColor; {ClB3}
    end;
  end;
end;

function TopSelected: Integer;
var
  i: Integer;
begin
  if Assigned(Objects) then
  begin
    Result := Objects.Count - 1;
    for i := Objects.Count - 1 downto 0 do
      if TfrView(Objects[i]).Selected then
      begin
        Result := i;
        break;
      end;
  end
  else
    Result:=-1;
end;

function frCheckBand(b: TfrBandType): Boolean;
var
  i: Integer;
  t: TfrView;
begin
  Result := False;
  for i := 0 to Objects.Count - 1 do
  begin
    t := TfrView(Objects[i]);
    if t.Typ = gtBand then
      if b = TfrBandView(t).BandType then
      begin
        Result := True;
        break;
      end;
  end;
end;

function GetUnusedBand: TfrBandType;
var
  b: TfrBandType;
begin
  Result := btNone;
  for b := btReportTitle to btNone do
    if not frCheckBand(b) then
    begin
      Result := b;
      break;
    end;
  if Result = btNone then Result := btMasterData;
end;

procedure SendBandsToDown;
var
  i, j, n, k: Integer;
  t: TfrView;
begin
  n := Objects.Count; j := 0; i := n - 1;
  k := 0;
  while j < n do
  begin
    t := TfrView(Objects[i]);
    if t.Typ = gtBand then
    begin
      Objects.Delete(i);
      Objects.Insert(0, t);
      Inc(k);
    end
    else Dec(i);
    Inc(j);
  end;
  for i := 0 to n - 1 do // sends btOverlay to back
  begin
    t := TfrView(Objects[i]);
    if (t.Typ = gtBand) and (TfrBandView(t).BandType = btOverlay) then
    begin
      Objects.Delete(i);
      Objects.Insert(0, t);
      break;
    end;
  end;
  i := 0; j := 0;
  while j < n do // sends btCrossXXX to front
  begin
    t := TfrView(Objects[i]);
    if (t.Typ = gtBand) and
       (TfrBandView(t).BandType in [btCrossHeader..btCrossFooter]) then
    begin
      Objects.Delete(i);
      Objects.Insert(k - 1, t);
    end
    else Inc(i);
    Inc(j);
  end;
end;

procedure ClearClipBoard;
var
  t: TfrView;
begin
  if Assigned(ClipBd) then
    with ClipBd do
    while Count > 0 do
    begin
      t := TfrView(Items[0]);
      t.Free;
      Delete(0);
    end;
end;

procedure GetRegion;
var
  i: Integer;
  t: TfrView;
  R,R1: HRGN;
begin
  ClipRgn := CreateRectRgn(0, 0, 0, 0);
  for i := 0 to Objects.Count - 1 do
  begin
    t := TfrView(Objects[i]);
    if t.Selected then
    begin
      R := t.GetClipRgn(rtExtended);
      R1:=CreateRectRgn(0, 0, 0, 0);
      CombineRgn(ClipRgn, R1, R, RGN_OR);
      DeleteObject(R);
      DeleteObject(R1);
    end;
  end;
  FirstChange := False;
end;

procedure TfrDesignerForm.GetDefaultSize(var dx, dy: Integer);
begin
  dx := 96;
  if GridSize = 18 then dx := 18 * 6;
  dy := 18;
  if GridSize = 18 then dy := 18;
  if LastFontSize in [12, 13] then dy := 20;
  if LastFontSize in [14..16] then dy := 24;
end;


procedure TfrDesignerForm.SB1Click(Sender: TObject);
var
  d: Double;
begin
  d := StrToFloat(E1.Text);
  d := d + 1;
  E1.Text := FloatToStrF(d, ffGeneral, 2, 2);
  DoClick(E1);
end;

procedure TfrDesignerForm.SB2Click(Sender: TObject);
var
  d: Double;
begin
  d := StrToFloat(E1.Text);
  d := d - 1;
  if d <= 0 then d := 1;
  E1.Text := FloatToStrF(d, ffGeneral, 2, 2);
  DoClick(E1);
end;

{type
  THackBtn = class(TSpeedButton);
}

procedure TfrDesignerForm.HelpBtnClick(Sender: TObject);
begin
  HelpBtn.Down := True;
  Screen.Cursor := crHelp;
  SetCaptureControl(Self);
  //** THackBtn(HelpBtn).FMouseInControl := False;
  HelpBtn.Invalidate;
end;

procedure TfrDesignerForm.FormMouseDown(Sender: TObject;
  Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  c: TControl;
  t: Integer;
begin
  if HelpBtn.Down and (GetCaptureControl=Self) then
    SetCaptureControl(nil);
  HelpBtn.Down := False;
  Screen.Cursor := crDefault;
  c := FindControlAtPosition(Mouse.CursorPos, true);
  if (c <> nil) and (c <> HelpBtn) then
  begin
    t := c.Tag;
    if (c.Parent = Panel4) and (t > 4) then
      t := 5;
    if c.Parent = Panel4 then
      Inc(t, 430) else
      Inc(t, 400);
    //DebugLn('TODO: HelpContext for tag=%d',[t]);
    //** Application.HelpCommand(HELP_CONTEXTPOPUP, t);
  end;
end;

procedure TfrDesignerForm.N22Click(Sender: TObject);
begin
  //** Application.HelpCommand(HELP_FINDER, 0);
end;

procedure TfrDesignerForm.OnActivateApp(Sender: TObject);

  procedure SetWinZOrder(Form: TForm);
  begin
    SetWindowPos(Form.Handle, HWND_TOPMOST, 0, 0, 0, 0, SWP_NOMOVE or
      SWP_NOSIZE or SWP_NOACTIVATE);
  end;
begin
//  SetWinZOrder(InspForm);
{//**
  if Panel1.IsFloat then SetWinZOrder(Panel1.FloatWindow);
  if Panel2.IsFloat then SetWinZOrder(Panel2.FloatWindow);
  if Panel3.IsFloat then SetWinZOrder(Panel3.FloatWindow);
  if Panel4.IsFloat then SetWinZOrder(Panel4.FloatWindow);
  if Panel5.IsFloat then SetWinZOrder(Panel5.FloatWindow);
  if Panel6.IsFloat then SetWinZOrder(Panel6.FloatWindow);
}
end;

procedure TfrDesignerForm.OnDeactivateApp(Sender: TObject);

  procedure SetWinZOrder(Form: TForm);
  begin
    SetWindowPos(Form.Handle, HWND_NOTOPMOST, 0, 0, 0, 0, SWP_NOMOVE or
      SWP_NOSIZE or SWP_NOACTIVATE);
  end;
  
begin
  if not Visible then Exit;
//  SetWinZOrder(InspForm);
{//**
  if Panel1.IsFloat then SetWinZOrder(Panel1.FloatWindow);
  if Panel2.IsFloat then SetWinZOrder(Panel2.FloatWindow);
  if Panel3.IsFloat then SetWinZOrder(Panel3.FloatWindow);
  if Panel4.IsFloat then SetWinZOrder(Panel4.FloatWindow);
  if Panel5.IsFloat then SetWinZOrder(Panel5.FloatWindow);
  if Panel6.IsFloat then SetWinZOrder(Panel6.FloatWindow);
}
end;

Procedure InitGlobalDesigner;
begin
  if Assigned(frDesigner) then
    Exit;
  frDesigner := TfrDesignerForm.Create(nil);
end;

{ TfrPanelObjectInspector }

{$IFNDEF EXTOI}
procedure TfrObjectInspector.BtnClick(Sender: TObject);
begin
  if Sender=fBtn then
  begin
    if fBtn.Caption='-' then
    begin
      fLastHeight:=Height;
      Height:=fPanelHeader.Height + 2*BorderWidth + 3;
      fBtn.Caption:='+';
    end
    else
    begin
      Height:=fLastHeight;
      fBtn.Caption:='-';
    end;
  end
  else Visible:=False;
end;

procedure TfrObjectInspector.HeaderMDown(Sender: TOBject;
  Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  if Button=mbLeft then
  begin
    fDown:=True;
    if (x>4) and (x<fPanelHeader.Width-4) and (y<=16) then
    begin
      {$IFDEF DebugLR}
      debugLn('TfrObjectInspector.HeaderMDown()');
      {$ENDIF}
      fPanelHeader.Cursor:=crSize;
      // get absolute mouse position (X,Y can not be used, because they
      // are relative to what is moving)
      fPt:=Mouse.CursorPos;
      //DebugLn(['TfrObjectInspector.HeaderMDown ',dbgs(fPt)]);
    end;
  end;
end;

procedure TfrObjectInspector.HeaderMMove(Sender: TObject;
  Shift: TShiftState; X, Y: Integer);
var
  NewPt: TPoint;
begin
  if fDown then
  begin
    {$IFDEF DebugLR}
    debugLn('TfrObjectInspector.HeaderMMove()');
    {$ENDIF}

    Case fPanelHeader.Cursor of
      crSize :
        begin
          NewPt:=Mouse.CursorPos;
          //DebugLn(['TfrObjectInspector.HeaderMDown ',dbgs(fPt),' New=',dbgs(NewPt)]);
          SetBounds(Left+NewPt.X-fPt.X,Top+NewPt.Y-fPt.Y,Width,Height);
          fPt:=NewPt;
        end;
    end;
  end
end;

procedure TfrObjectInspector.HeaderMUp(Sender: TOBject;
  Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  {$IFDEF DebugLR}
  DebugLn('TfrObjectInspector.HeaderMUp()');
  {$ENDIF}
  fDown:=False;
  fPanelHeader.Cursor:=crDefault;
end;

{$ENDIF}

procedure TfrObjectInspector.CMVisibleChanged(var TheMessage: TLMessage);
begin
  Inherited CMVisibleChanged(TheMessage);
  
  if Visible then
  begin
    DoOnResize;
    BringToFront;
    Select(Objects);
  end;
  {$IFDEF DebugLR}
  debugLn('TfrObjectInspector.CMVisibleChanged: %s', [dbgs(Visible)]);
  {$ENDIF}
end;

{$IFDEF EXTOI}
procedure TfrObjectInspector.DoHide;
begin
  //TODO Uncheck Menue Item
end;
{$ENDIF}

constructor TfrObjectInspector.Create(aOwner: TComponent);
begin
  inherited Create(aOwner);

  {$IFDEF EXTOI}
  Width  :=220;
  Height :=300;
  Top    :=Screen.Height div 2;
  Left   :=40;
  Visible     :=False;
  Caption := 'Object Inspector';
  FormStyle := fsStayOnTop;
  // create the ObjectInspector
  fPropertyGrid:=TCustomPropertiesGrid.Create(aOwner);
  with fPropertyGrid do
  begin
    Name  :='PropertyGrid';
    Parent:=Self;
    align := alclient;
    ShowHint:=false; //cause problems in windows
  end;

  {$ELSE}

  Parent :=TWinControl(aOwner);
  Width  :=220;
  Height :=300;
  Top    :=120;
  Left   :=40;
  Borderstyle :=bsNone;
  BevelInner  :=bvLowered;
  BevelOuter  :=bvRaised;
  BorderWidth :=1;
  Visible     :=False;

  fDown       :=False;

  fPanelHeader:=TPanel.Create(self);
  with fPanelHeader do
  begin
    Parent:=Self;
    Color :=clSilver;
    BorderStyle:=bsNone;
    BevelInner:=bvNone;
    BevelOuter:=bvNone;
    Caption:=sObjectInspector;
    AnchorSideLeft.Control := self;
    AnchorSideTop.Control := self;
    AnchorSideRight.Control := self;
    AnchorSideRight.Side := asrBottom;
    Anchors := [akTop, akLeft, akRight];
    Top := 0;
    Height := 18;
    OnMouseDown:=@HeaderMDown;
    OnMouseMove:=@HeaderMMove;
    OnMouseUp  :=@HeaderMUp;
  end;

  fBtn2:=TButton.Create(fPanelHeader);
  with fBtn2 do
  begin
    Parent:=fPanelHeader;
    AnchorSideTop.Control := fPanelHeader;
    AnchorSideRight.Control := fPanelHeader;
    AnchorSideRight.Side := asrBottom;
    AnchorSideBottom.Control := fPanelHeader;
    AnchorSideBottom.Side := asrBottom;
    Anchors := [akTop, akRight, akBottom];
    BorderSpacing.Around := 1;
    Width := fPanelHeader.Height - 2*BorderSpacing.Around;
    Caption:='x';
    TabStop:=False;
    OnClick:=@BtnClick;
  end;

  fBtn:=TButton.Create(fPanelHeader);
  with fBtn do
  begin
    Parent:=fPanelHeader;
    AnchorSideTop.Control := fPanelHeader;
    AnchorSideRight.Control := fBtn2;
    AnchorSideBottom.Control := fPanelHeader;
    AnchorSideBottom.Side := asrBottom;
    Anchors := [akTop, akRight, akBottom];
    BorderSpacing.Around := 1;
    Width := fPanelHeader.Height - 2*BorderSpacing.Around;
    Caption:='-';
    TabStop:=False;
    OnClick:=@BtnClick;
  end;


  fcboxObjList  := TComboBox.Create(Self);
  with fcboxObjList do
  begin
    Parent:=Self;
    AnchorSideLeft.Control := Self;
    AnchorSideTop.Control := fPanelHeader;
    AnchorSideTop.Side := asrBottom;
    AnchorSideRight.Control := self;
    AnchorSideRight.Side := asrBottom;
    Anchors := [akTop, akLeft, akRight];
    ShowHint := false; //cause problems in windows
    Onchange := @cboxObjListOnChanged;
  end;
  fcboxObjList.Sorted:=true;

  // create the ObjectInspector
  fPropertyGrid:=TCustomPropertiesGrid.Create(aOwner);
  with fPropertyGrid do
  begin
    Name  :='PropertyGrid';
    Parent:=Self;
    AnchorSideLeft.Control := Self;
    AnchorSideTop.Control := fcboxObjList;
    AnchorSideTop.Side := asrBottom;
    AnchorSideRight.Control := Self;
    AnchorSideRight.Side := asrBottom;
    AnchorSideBottom.Control := Self;
    AnchorSideBottom.Side := asrBottom;
    Anchors := [akTop, akLeft, akRight, akBottom];
    ShowHint:=false; //cause problems in windows
    fPropertyGrid.SaveOnChangeTIObject:=false;
    DefaultItemHeight := fcboxObjList.Height-3;
  end;
  {$ENDIF}
end;

destructor TfrObjectInspector.Destroy;
begin
  //fPropertyGrid.Free; // it's owned by OI form/Panel
  inherited Destroy;
end;

procedure TfrObjectInspector.Select(Obj: TObject);
var
  i      : Integer;
  NewSel : TPersistentSelectionList;
begin
  if (Objects.Count <> fcboxObjList.Items.Count) or (Assigned(Obj) and (fcboxObjList.Items.IndexOfObject(Obj) < 0)) then
  begin

    fcboxObjList.Clear;
    fcboxObjList.AddItem(TfrObject(frDesigner.Page).Name, TObject(frDesigner.Page));

    for i:=0 to Objects.Count-1 do
       fcboxObjList.AddItem(TfrView(Objects[i]).Name, TObject(Objects[i]));

  end;

  FSelectedObject:=nil;

  if (Obj=nil) or (Obj is TPersistent) then
  begin
    FSelectedObject:=Obj;
    NewSel := TPersistentSelectionList.Create;
    try
      if Obj<>nil then
      begin
        fcboxObjList.ItemIndex := fcboxObjList.Items.IndexOfObject(Obj);
        NewSel.Add(TfrView(Obj));
      end;
      fPropertyGrid.Selection := NewSel
    finally
      NewSel.Free;
    end;
  end
  else
  if Obj is TFpList then
    with TFpList(Obj) do
    begin
      NewSel:=TPersistentSelectionList.Create;
      try
        for i:=0 to Count-1 do
          if TfrView(Items[i]).Selected then
            NewSel.Add(TfrView(Items[i]));
        fPropertyGrid.Selection:=NewSel;
      finally
        NewSel.Free;
      end;
    end;
end;

procedure TfrObjectInspector.cboxObjListOnChanged(Sender: TObject);
var
  i: Integer;
  vObj: TObject;
begin
  if fcboxObjList.ItemIndex >= 0 then
  begin
    TfrDesignerForm(frDesigner).SelNum := 0;
    for i := 0 to Objects.Count - 1 do
      TfrView(Objects[i]).Selected := False;
    vObj := fcboxObjList.Items.Objects[fcboxObjList.ItemIndex];
    if vObj is TfrView then
    begin
      TfrView(vObj).Selected:=True;
      TfrDesignerForm(frDesigner).SelNum := 1;
      frDesigner.Invalidate;
    end;
    Select(vObj);
  end;
end;

procedure TfrObjectInspector.SetModifiedEvent(AEvent: TNotifyEvent);
begin
  fPropertyGrid.OnModified:=AEvent;
end;

procedure TfrObjectInspector.Refresh;
begin
  if not visible then
    exit;
  fPropertyGrid.RefreshPropertyValues;
end;

type
  { TfrCustomMemoViewDetailReportProperty }

  TfrCustomMemoViewDetailReportProperty = class(TStringProperty)
  private
    FSaveRep:TfrReport;
    FEditView:TfrCustomMemoView;
    FDetailRrep: TlrDetailReport;
    procedure DoSaveReportEvent(Report: TfrReport; var ReportName: String;
      SaveAs: Boolean; var Saved: Boolean);
  public
    function  GetAttributes: TPropertyAttributes; override;
    procedure Edit; override;
    procedure GetValues(Proc: TGetStrProc); override;
  end;


  TfrViewDataFieldProperty = class(TStringProperty)
  public
    function  GetAttributes: TPropertyAttributes; override;
    procedure Edit; override;
  end;

  { TTfrBandViewChildProperty }

  TTfrBandViewChildProperty = class(TStringProperty)
  public
    function  GetAttributes: TPropertyAttributes; override;
    procedure GetValues(Proc: TGetStrProc); override;
  end;

{ TTfrBandViewChildProperty }

function TTfrBandViewChildProperty.GetAttributes: TPropertyAttributes;
begin
  Result:=inherited GetAttributes + [paValueList, paSortList];
end;

procedure TTfrBandViewChildProperty.GetValues(Proc: TGetStrProc);
var
  I: Integer;
begin
  if Assigned(frDesigner) and Assigned(frDesigner.Page) then
  begin
    for i:=0 to frDesigner.Page.Objects.Count-1 do
      if TObject(frDesigner.Page.Objects[i]) is TfrBandView then
        if (TfrBandView(frDesigner.Page.Objects[i]).BandType = btChild) and
           (TfrBandView(GetComponent(0)) <> TfrBandView(frDesigner.Page.Objects[i])) then
          Proc(TfrBandView(frDesigner.Page.Objects[i]).Name);
  end;
end;

{ TfrPictureViewDataFieldProperty }

function TfrViewDataFieldProperty.GetAttributes: TPropertyAttributes;
begin
  Result := inherited GetAttributes + [paDialog{, paValueList, paSortList}];
end;

type
  TfrHackView = class(TfrView);

procedure TfrViewDataFieldProperty.Edit;
begin
  if (GetComponent(0) is TfrView) and Assigned(CurReport) then
  begin
    frFieldsForm := TfrFieldsForm.Create(Application);
    try
      if frFieldsForm.ShowModal = mrOk then
      begin
        TfrHackView(GetComponent(0)).DataField:='[' + frFieldsForm.DBField + ']';
        frDesigner.Modified:=true;
      end;
    finally
      frFieldsForm.Free;
    end;
  end;
end;

procedure TfrCustomMemoViewDetailReportProperty.DoSaveReportEvent(Report: TfrReport;
  var ReportName: String; SaveAs: Boolean; var Saved: Boolean);
begin
  if Assigned(FDetailRrep) then
  begin
    FDetailRrep.ReportBody.Size:=0;
    CurReport.SaveToXMLStream(FDetailRrep.ReportBody);
    FDetailRrep.ReportDescription:=CurReport.Comments.Text;
    Saved:=true;
  end
  else
    Saved:=false;
end;

function TfrCustomMemoViewDetailReportProperty.GetAttributes: TPropertyAttributes;
begin
  Result := inherited GetAttributes + [paDialog, paValueList, paSortList];
end;

procedure TfrCustomMemoViewDetailReportProperty.Edit;
var
  FSaveDesigner:TfrReportDesigner;
  FSaveView:TfrView;
  FSaveBand: TfrBand;                               // currently proceeded band
  FSavePage: TfrPage;                               // currently proceeded page
  FSaveGetPValue:TGetPValueEvent;
  FSaveFunEvent:TFunctionEvent;
  FSaveReportEvent: TSaveReportEvent;
begin
  if (GetComponent(0) is TfrCustomMemoView) and Assigned(CurReport) then
  begin
    FEditView:=GetComponent(0) as TfrCustomMemoView;

    if FEditView.DetailReport = '' then
      FEditView.DetailReport:=FEditView.Name + '_DetailReport';
    FDetailRrep:=CurReport.DetailReports.Add(FEditView.DetailReport);
    if not Assigned(FDetailRrep) then exit;

    FSaveGetPValue:=frParser.OnGetValue;
    FSaveFunEvent:=frParser.OnFunction;
    FSaveDesigner:=frDesigner;
    FSaveRep:=CurReport;
    FSaveView:=CurView;
    FSaveBand:=CurBand;
    FSavePage:=CurPage;

    frDesigner:=nil;

    CurReport:=TfrReport.Create(nil);
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

    FSaveReportEvent:=frDesignerComp.OnSaveReport;
    frDesignerComp.OnSaveReport:=@DoSaveReportEvent;

    try
      FDetailRrep.ReportBody.Position:=0;
      if FDetailRrep.ReportBody.Size > 0 then
        CurReport.LoadFromXMLStream(FDetailRrep.ReportBody);

      if CurReport.DesignReport = mrOk then
      begin
        FDetailRrep.ReportBody.Size:=0;
        CurReport.SaveToXMLStream(FDetailRrep.ReportBody);
        FDetailRrep.ReportDescription:=CurReport.Comments.Text;
      end;

      if Assigned(frDesigner) then
        FreeAndNil(frDesigner);
    finally
      frDesigner := FSaveDesigner;
      CurReport  := FSaveRep;
      CurView := FSaveView;
      CurBand := FSaveBand;
      CurPage := FSavePage;
      frParser.OnGetValue:=FSaveGetPValue;
      frParser.OnFunction:=FSaveFunEvent;
      frDesignerComp.OnSaveReport:=FSaveReportEvent;

      frDesigner.Modified:=true;
    end;
  end;
end;

procedure TfrCustomMemoViewDetailReportProperty.GetValues(Proc: TGetStrProc);
var
  I: Integer;
begin
  if Assigned(CurReport) then
  begin
    for i:=0 to CurReport.DetailReports.Count-1 do
      Proc(CurReport.DetailReports.GetItem(i).ReportName);
  end;
end;

type

  { TlrInternalTools }

  TlrInternalTools = class
  private
    lrBMPInsFields : TBitmap;
    procedure InsFieldsClick(Sender: TObject);
    procedure InsertFieldsFormCloseQuery(Sender: TObject; var {%H-}CanClose: boolean);
    procedure InsertDbFields;
  public
    constructor Create;
    destructor Destroy; override;
  end;

var
  FlrInternalTools:TlrInternalTools = nil;

{ TlrInternalTools }

procedure TlrInternalTools.InsFieldsClick(Sender: TObject);
begin
  frInsertFieldsForm := TfrInsertFieldsForm.Create(nil);
  frInsertFieldsForm.OnCloseQuery := @InsertFieldsFormCloseQuery;
  Try
    frInsertFieldsForm.ShowModal;
  finally
    frInsertFieldsForm.Free;
    frInsertFieldsForm:=nil;
  end;
end;

procedure TlrInternalTools.InsertFieldsFormCloseQuery(Sender: TObject;
  var CanClose: boolean);
begin
  if (Sender=frInsertFieldsForm) and (frInsertFieldsForm.ModalResult=mrOk) then
    InsertDbFields;
end;

procedure TlrInternalTools.InsertDbFields;
var
  i, x, y, dx, dy, pdx, adx: Integer;
  HeaderL, DataL: TFpList;
  t, t1: TfrView;
  b: TfrBandView;
  f: TfrTField;
  f1: TFieldDef;
  fSize: Integer;
  fName: String;

  function FindDataset(DataSet: TfrTDataSet): String;
  var
    i,j: Integer;

    function EnumComponents(f: TComponent): String;
    var
      i: Integer;
      c: TComponent;
      d: TfrDBDataSet;
    begin
      Result := '';
      for i := 0 to f.ComponentCount - 1 do
      begin
        c := f.Components[i];
        if c is TfrDBDataSet then
        begin
          d := c as TfrDBDataSet;
          if d.GetDataSet = DataSet then
          begin
            if d.Owner = CurReport.Owner then
              Result := d.Name else
              Result := d.Owner.Name + '.' + d.Name;
            break;
          end;
        end;
      end;
    end;

  begin
    Result := '';
    for i := 0 to Screen.FormCount - 1 do
    begin
      Result := EnumComponents(Screen.Forms[i]);
      if Result <> '' then Exit;
    end;

    with Screen do
    begin
      for i := 0 to CustomFormCount - 1 do
        with CustomForms[i] do
        if (ClassName = 'TDataModuleForm')  then
          for j := 0 to ComponentCount - 1 do
          begin
            if (Components[j] is TDataModule) then
              Result:=EnumComponents(Components[j]);
              if Result <> '' then Exit;
          end;
    end;
  end;
begin
  if frInsertFieldsForm=nil then
    exit;

  with frInsertFieldsForm do
  begin
    if (DataSet=nil) or (FieldsL.Items.Count = 0) or (FieldsL.SelCount = 0) then
      exit;

    HeaderL := TFpList.Create;
    DataL := TFpList.Create;
    try
      x := frDesigner.Page.LeftMargin;
      y := frDesigner.Page.TopMargin;
      TfrDesignerForm(frDesigner).Unselect;
      TfrDesignerForm(frDesigner).SelNum := 0;
      for i := 0 to FieldsL.Items.Count - 1 do
        if FieldsL.Selected[i] then
        begin
          f := TfrTField(DataSet.FindField(FieldsL.Items[i]));
          fSize := 0;
          if f <> nil then
          begin
            fSize := f.DisplayWidth;
            fName := f.DisplayName;
          end
          else
          begin
            f1 := DataSet.FieldDefs[i];
            fSize := f1.Size;
            fName := f1.Name;
          end;

          if (fSize = 0) or (fSize > 255) then
            fSize := 6;

          t := frCreateObject(gtMemo, '', frDesigner.Page);
          t.CreateUniqueName;
          t.x := x;
          t.y := y;
          TfrDesignerForm(frDesigner).GetDefaultSize(t.dx, t.dy);
          with t as TfrCustomMemoView do
          begin
            Font.Name := LastFontName;
            Font.Size := LastFontSize;
            if HeaderCB.Checked then
              Font.Style := [fsBold];
            MonitorFontChanges;
          end;
          TfrDesignerForm(frDesigner).PageView.Canvas.Font.Assign(TfrCustomMemoView(t).Font);
          t.Selected := True;
          Inc(TfrDesignerForm(frDesigner).SelNum);
          if HeaderCB.Checked then
          begin
            t.Memo.Add(fName);
            t.dx := TfrDesignerForm(frDesigner).PageView.Canvas.TextWidth(fName + '   ') div TfrDesignerForm(frDesigner).GridSize * TfrDesignerForm(frDesigner).GridSize;
          end
          else
          begin
            t.Memo.Add('[' + DatasetCB.Items[DatasetCB.ItemIndex] +
              '."' + FieldsL.Items[i] + '"]');
            t.dx := (fSize * TfrDesignerForm(frDesigner).PageView.Canvas.TextWidth('=')) div TfrDesignerForm(frDesigner).GridSize * TfrDesignerForm(frDesigner).GridSize;
          end;
          dx := t.dx;
//          TfrDesignerForm(frDesigner).Page.Objects.Add(t);
          if HeaderCB.Checked then
            HeaderL.Add(t) else
            DataL.Add(t);
          if HeaderCB.Checked then
          begin
            t := frCreateObject(gtMemo, '', TfrDesignerForm(frDesigner).Page);
            t.CreateUniqueName;
            t.x := x;
            t.y := y;
            TfrDesignerForm(frDesigner).GetDefaultSize(t.dx, t.dy);
            if HorzRB.Checked then
              Inc(t.y, 72) else
              Inc(t.x, dx + TfrDesignerForm(frDesigner).GridSize * 2);
            with t as TfrCustomMemoView do
            begin
              Font.Name := LastFontName;
              Font.Size := LastFontSize;
              MonitorFontChanges;
            end;
            t.Selected := True;
            Inc(TfrDesignerForm(frDesigner).SelNum);
            t.Memo.Add('[' + DatasetCB.Items[DatasetCB.ItemIndex] +
              '."' + FieldsL.Items[i] + '"]');
            t.dx := (fSize * TfrDesignerForm(frDesigner).PageView.Canvas.TextWidth('=')) div TfrDesignerForm(frDesigner).GridSize * TfrDesignerForm(frDesigner).GridSize;
//            TfrDesignerForm(frDesigner).Page.Objects.Add(t);
            DataL.Add(t);
          end;
          if HorzRB.Checked then
            Inc(x, t.dx + TfrDesignerForm(frDesigner).GridSize)
          else
            Inc(y, t.dy + TfrDesignerForm(frDesigner).GridSize);

          if t is TfrControl then
            TfrControl(T).UpdateControlPosition;
        end;

      if HorzRB.Checked then
      begin
        t := TfrView(DataL[DataL.Count - 1]);
        adx := t.x + t.dx;
        pdx := TfrDesignerForm(frDesigner).Page.RightMargin - TfrDesignerForm(frDesigner).Page.LeftMargin;
        x := TfrDesignerForm(frDesigner).Page.LeftMargin;
        if adx > pdx then
        begin
          for i := 0 to DataL.Count - 1 do
          begin
            t := TfrView(DataL[i]);
            t.x := Round((t.x - x) / (adx / pdx)) + x;
            t.dx := Round(t.dx / (adx / pdx));
          end;
          if HeaderCB.Checked then
            for i := 0 to DataL.Count - 1 do
            begin
              t := TfrView(HeaderL[i]);
              t1 := TfrView(DataL[i]);
              t.x := Round((t.x - x) / (adx / pdx)) + x;
              if t.dx > t1.dx then
                t.dx := t1.dx;
            end;
        end;
      end;

      if BandCB.Checked then
      begin
        if HeaderCB.Checked then
          t := TfrView(HeaderL[DataL.Count - 1])
        else
          t := TfrView(DataL[DataL.Count - 1]);
        dy := t.y + t.dy - TfrDesignerForm(frDesigner).Page.TopMargin;
        b := frCreateObject(gtBand, '', TfrDesignerForm(frDesigner).Page) as TfrBandView;
        b.CreateUniqueName;
        b.y := TfrDesignerForm(frDesigner).Page.TopMargin;
        b.dy := dy;
        b.Selected := True;
        Inc(TfrDesignerForm(frDesigner).SelNum);
        if not HeaderCB.Checked or not HorzRB.Checked then
        begin
//          TfrDesignerForm(frDesigner).Page.Objects.Add(b);
          b.BandType := btMasterData;
          b.DataSet := FindDataset(DataSet);
        end
        else
        begin
          if frCheckBand(btPageHeader) then
          begin
            Dec(TfrDesignerForm(frDesigner).SelNum);
            b.Free;
          end
          else
          begin
            b.BandType := btPageHeader;
//            TfrDesignerForm(frDesigner).Page.Objects.Add(b);
          end;
          b := frCreateObject(gtBand, '', TfrDesignerForm(frDesigner).Page) as TfrBandView;
          b.BandType := btMasterData;
          b.DataSet := FindDataset(DataSet);
          b.CreateUniqueName;
          b.y := TfrDesignerForm(frDesigner).Page.TopMargin + 72;
          b.dy := dy;
          b.Selected := True;
          Inc(TfrDesignerForm(frDesigner).SelNum);
//          TfrDesignerForm(frDesigner).Page.Objects.Add(b);
        end;
      end;
      TfrDesignerForm(frDesigner).SelectionChanged;
      SendBandsToDown;
      TfrDesignerForm(frDesigner).PageView.GetMultipleSelected;
      TfrDesignerForm(frDesigner).RedrawPage;
      TfrDesignerForm(frDesigner).AddUndoAction(acInsert);
    finally
      HeaderL.Free;
      DataL.Free;
    end;
  end;
end;

constructor TlrInternalTools.Create;
begin
  inherited Create;
  lrBMPInsFields := TBitmap.Create;
  lrBMPInsFields.LoadFromResourceName(HInstance, 'lrd_ins_fields');
  frRegisterTool(sInsertFields, lrBMPInsFields, @InsFieldsClick);
end;

destructor TlrInternalTools.Destroy;
begin
  lrBMPInsFields.Free;
  inherited destroy;
end;

initialization
  frDesigner:=nil;
  ProcedureInitDesigner:=@InitGlobalDesigner;
  
  ClipBd := TFpList.Create;
  GridBitmap := TBitmap.Create;
  with GridBitmap do
  begin
    Width := 8; Height := 8;
  end;
  LastFrames:=[];
  LastFrameWidth := 1;
  LastLineWidth := 2;
  LastFillColor := clNone;
  LastFrameColor := clBlack;
  LastFontColor := clBlack;
  LastFontStyle := 0;
  LastAdjust := 0;
  //** RegRootKey := 'Software\FastReport\' + Application.Title;

  RegisterPropertyEditor(TypeInfo(String), TfrCustomMemoView, 'DetailReport', TfrCustomMemoViewDetailReportProperty);
  RegisterPropertyEditor(TypeInfo(String), TfrView, 'DataField', TfrViewDataFieldProperty);

  RegisterPropertyEditor(TypeInfo(String), TfrBandView, 'Child', TTfrBandViewChildProperty);

  FlrInternalTools:=TlrInternalTools.Create;
finalization
  If Assigned(frDesigner) then
  begin
    {$IFNDEF MODALDESIGNER}
    if frDesigner.Visible then
      frDesigner.Hide;
    {$ENDIF}
    frDesigner.Free;
  end;
  ClearClipBoard;
  ClipBd.Free;
  GridBitmap.Free;
  FreeAndNil(FlrInternalTools);
end.


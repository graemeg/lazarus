{ /***************************************************************************
                   designer.pp  -  Lazarus IDE unit
                   --------------------------------

              Initial Revision  : Sat May 10 23:15:32 CST 1999


 ***************************************************************************/

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
}
unit Designer;

{$mode objfpc}{$H+}

interface

{off $DEFINE VerboseDesigner}
{off $DEFINE VerboseDesignerDraw}
{off $DEFINE VerboseDesignerSelect}

uses
  // RTL + FCL
  Types, Classes, Math, SysUtils, Variants, TypInfo,
  // LCL
  LCLProc, LCLType, LResources, LCLIntf, LMessages, InterfaceBase,
  Forms, Controls, Graphics, Dialogs, ExtCtrls, Menus, ClipBrd,
  // LazUtils
  GraphType, LazFileUtils, LazFileCache, LazLoggerBase,
  // IDEIntf
  IDEDialogs, PropEdits, PropEditUtils, ComponentEditors, MenuIntf,
  IDEImagesIntf, FormEditingIntf, ComponentReg, IDECommands, LazIDEIntf,
  ProjectIntf, ObjectInspector,
  // IDE
  LazarusIDEStrConsts, EnvironmentOpts, EditorOptions, SourceEditor,
  // Designer
  AlignCompsDlg, SizeCompsDlg, ScaleCompsDlg, DesignerProcs, CustomFormEditor,
  AskCompNameDlg, ControlSelection, ChangeClassDialog, ImgList;

type
  TDesigner = class;

  TOnGetSelectedComponentClass = procedure(Sender: TObject;
    var RegisteredComponent: TRegisteredComponent) of object;
  TOnSetDesigning = procedure(Sender: TObject; Component: TComponent;
    Value: boolean) of object;
  TOnPasteComponents = procedure(Sender: TObject; LookupRoot: TComponent;
    TxtCompStream: TStream; Parent: TWinControl;
    NewComponents: TFPList) of object;
  TOnPastedComponents = procedure(Sender: TObject; LookupRoot: TComponent) of object;
  TOnPersistentDeleted = procedure(Sender: TObject; APersistent: TPersistent)
    of object;
  TOnGetNonVisualCompIcon = procedure(Sender: TObject;
    AComponent: TComponent; var ImageList: TCustomImageList; var ImageIndex: TImageIndex) of object;
  TOnRenameComponent = procedure(Designer: TDesigner; AComponent: TComponent;
    const NewName: string) of object;
  TOnProcessCommand = procedure(Sender: TObject; Command: word;
    var Handled: boolean) of object;
  TOnComponentAdded = procedure(Sender: TObject; AComponent: TComponent;
                           ARegisteredComponent: TRegisteredComponent) of object;
  TOnForwardKeyToObjectInspector = procedure(Sender: TObject; Key: TUTF8Char) of object;
  TOnHasParentCandidates = function: Boolean of object;

  TDesignerFlag = (
    dfHasSized,
    dfNeedPainting,
    dfDuringPaintControl,
    dfDestroyingForm,
    dfShowEditorHints,
    dfShowComponentCaptions,
    dfShowNonVisualComponents
    );
  TDesignerFlags = set of TDesignerFlag;

  TUndoItem = record
    obj: string;
    fieldName: string;
    propInfo: PPropInfo;
    oldVal, newVal: Variant;
    compName, parentName: TComponentName;
    opType: TUndoOpType;
    isValid: Boolean;
    GroupId: int64;
  end;

  { TDesigner }

  TDesigner = class(TComponentEditorDesigner)
  private
    FDesignerPopupMenu: TPopupMenu;
    FDefaultFormBounds: TRect;
    FLastFormBounds: TRect;
    FFlags: TDesignerFlags;
    FGridColor: TColor;
    FMediator: TDesignerMediator;
    FOnChangeParent: TNotifyEvent;
    FOnPastedComponents: TOnPastedComponents;
    FProcessingDesignerEvent: Integer;
    FOnActivated: TNotifyEvent;
    FOnCloseQuery: TNotifyEvent;
    FOnShowObjectInspector: TNotifyEvent;
    FOnShowAnchorEditor: TNotifyEvent;
    FOnShowTabOrderEditor: TNotifyEvent;
    FOnPersistentDeleted: TOnPersistentDeleted;
    FOnGetNonVisualCompIcon: TOnGetNonVisualCompIcon;
    FOnGetSelectedComponentClass: TOnGetSelectedComponentClass;
    FOnModified: TNotifyEvent;
    FOnPasteComponent: TOnPasteComponents;
    FOnProcessCommand: TOnProcessCommand;
    FOnPropertiesChanged: TNotifyEvent;
    FOnRenameComponent: TOnRenameComponent;
    FOnSaveAsXML: TNotifyEvent;
    FOnSetDesigning: TOnSetDesigning;
    FOnShowOptions: TNotifyEvent;
    FOnComponentAdded: TOnComponentAdded;
    FOnViewLFM: TNotifyEvent;
    FOnForwardKeyToObjectInspector: TOnForwardKeyToObjectInspector;
    FShiftState: TShiftState;
    FTheFormEditor: TCustomFormEditor;
    FPopupMenuComponentEditor: TBaseComponentEditor;
    FUndoList: array of TUndoItem;
    FUndoCurr: integer;
    FUndoLock: integer;
    FUndoGroupId: int64;

    //hint stuff
    FHintTimer: TTimer;
    FHintWIndow: THintWindow;

    // component drawing
    FDDC: TDesignerDeviceContext;
    FSurface: TBitmap;

    procedure DrawNonVisualComponent(AComponent: TComponent);
    function GetGridColor: TColor;
    function GetGridSizeX: integer;
    function GetGridSizeY: integer;
    function GetIsControl: Boolean;
    function GetShowBorderSpacing: boolean;
    function GetShowComponentCaptions: boolean;
    function GetShowEditorHints: boolean;
    function GetShowGrid: boolean;
    function GetSnapToGrid: boolean;
    procedure HintTimer(Sender : TObject);
    procedure InvalidateWithParent(AComponent: TComponent);
    procedure SetDefaultFormBounds(const AValue: TRect);
    procedure SetGridColor(const AValue: TColor);
    procedure SetGridSizeX(const AValue: integer);
    procedure SetGridSizeY(const AValue: integer);
    procedure SetMediator(const AValue: TDesignerMediator);
    procedure SetPopupMenuComponentEditor(const AValue: TBaseComponentEditor);
    procedure SetShowBorderSpacing(const AValue: boolean);
    procedure SetShowComponentCaptions(const AValue: boolean);
    procedure SetShowEditorHints(const AValue: boolean);
    procedure SetShowGrid(const AValue: boolean);
    procedure SetSnapToGrid(const AValue: boolean);
    procedure DoOnForwardKeyToObjectInspector(Sender: TObject; Key: TUTF8Char);
  protected
    MouseDownComponent: TComponent;
    MouseDownSender: TComponent;
    MouseDownPos: TPoint;
    MouseDownShift: TShiftState;
    MouseUpPos: TPoint;
    LastMouseMovePos: TPoint;
    LastFormCursor: TCursor;
    DeletingPersistent: TList;
    LastPaintSender: TControl;

    // event handlers for designed components
    function PaintControl(Sender: TControl; TheMessage: TLMPaint): Boolean;
    function SizeControl(Sender: TControl; TheMessage: TLMSize): Boolean;
    function MoveControl(Sender: TControl; TheMessage: TLMMove): Boolean;
    procedure MouseDownOnControl(Sender: TControl; var TheMessage: TLMMouse);
    procedure MouseMoveOnControl(Sender: TControl; var TheMessage: TLMMouse);
    procedure MouseUpOnControl(Sender: TControl; var TheMessage: TLMMouse);
    procedure KeyDown(Sender: TControl; var TheMessage: TLMKEY);
    procedure KeyUp(Sender: TControl; var TheMessage: TLMKEY);
    function  HandleSetCursor(var TheMessage: TLMessage): boolean;
    procedure HandlePopupMenu(Sender: TControl; var Message: TLMContextMenu);
    procedure GetMouseMsgShift(TheMessage: TLMMouse; out Shift: TShiftState;
                               out Button: TMouseButton);
    function GetShowNonVisualComponents: boolean; override;
    procedure SetShowNonVisualComponents(AValue: boolean); override;

    // procedures for working with components and persistents
    function GetDesignControl(AControl: TControl): TControl;
    function DoDeleteSelectedPersistents: boolean;
    procedure DoDeleteSelectedPersistentsAsync({%H-}Data: PtrInt);
    procedure CutSelectionAsync({%H-}Data: PtrInt);
    procedure DoSelectAll;
    procedure DoDeletePersistent(APersistent: TPersistent; FreeIt: boolean);
    function GetSelectedComponentClass: TRegisteredComponent;
    procedure NudgePosition(DiffX, DiffY: Integer);
    procedure NudgeSize(DiffX, DiffY: Integer);
    procedure NudgeSelection(DiffX, DiffY: Integer); overload;
    procedure NudgeSelection(SelectNext: Boolean); overload;
    procedure SelectParentOfSelection;
    function DoCopySelectionToClipboard: boolean;
    function GetPasteParent: TWinControl;
    procedure DoModified;
    function DoPasteSelectionFromClipboard(PasteFlags: TComponentPasteSelectionFlags
                                           ): boolean;
    function DoInsertFromStream(s: TStream; PasteParent: TWinControl;
                                PasteFlags: TComponentPasteSelectionFlags): Boolean;

    function DoUndo: Boolean;
    function DoRedo: Boolean;
    procedure ExecuteUndoItem(IsActUndo: boolean);
    procedure SetNextUndoGroupId; inline;

    procedure DoShowAnchorEditor;
    procedure DoShowTabOrderEditor;
    procedure DoShowObjectInspector;
    procedure DoChangeZOrder(TheAction: Integer);

    procedure NotifyComponentAdded(AComponent: TComponent);
    function  ComponentClassAtPos(const AClass: TComponentClass;
                                  const APos: TPoint; const UseRootAsDefault,
                                  IgnoreHidden: boolean): TComponent;
    procedure SetTempCursor(ARoot: TWinControl; ACursor: TCursor);

    // popup menu
    procedure BuildPopupMenu;
    procedure DesignerPopupMenuPopup(Sender: TObject);
    procedure OnComponentEditorVerbMenuItemClick(Sender: TObject);
    procedure OnAlignPopupMenuClick(Sender: TObject);
    procedure OnMirrorHorizontalPopupMenuClick(Sender: TObject);
    procedure OnMirrorVerticalPopupMenuClick(Sender: TObject);
    procedure OnScalePopupMenuClick(Sender: TObject);
    procedure OnSizePopupMenuClick(Sender: TObject);
    procedure OnResetPopupMenuClick(Sender: TObject);
    procedure OnAnchorEditorMenuClick(Sender: TObject);
    procedure OnTabOrderMenuClick(Sender: TObject);
    procedure OnOrderMoveToFrontMenuClick(Sender: TObject);
    procedure OnOrderMoveToBackMenuClick(Sender: TObject);
    procedure OnOrderForwardOneMenuClick(Sender: TObject);
    procedure OnOrderBackOneMenuClick(Sender: TObject);
    procedure OnCopyMenuClick(Sender: TObject);
    procedure OnCutMenuClick(Sender: TObject);
    procedure OnPasteMenuClick(Sender: TObject);
    procedure OnDeleteSelectionMenuClick(Sender: TObject);
    procedure OnSelectAllMenuClick(Sender: TObject);
    procedure OnChangeClassMenuClick(Sender: TObject);
    procedure OnChangeParentMenuClick(Sender: TObject);
    procedure OnShowNonVisualComponentsMenuClick(Sender: TObject);
    procedure OnSnapToGridOptionMenuClick(Sender: TObject);
    procedure OnShowOptionsMenuItemClick(Sender: TObject);
    procedure OnSnapToGuideLinesOptionMenuClick(Sender: TObject);
    procedure OnViewLFMMenuClick(Sender: TObject);
    procedure OnSaveAsXMLMenuClick(Sender: TObject);
    procedure OnCenterFormMenuClick(Sender: TObject);

    // hook
    function GetPropertyEditorHook: TPropertyEditorHook; override;
    function DoFormActivated(Active: boolean): boolean;
    function DoFormCloseQuery: boolean;

    property PopupMenuComponentEditor: TBaseComponentEditor read FPopupMenuComponentEditor write SetPopupMenuComponentEditor;
  public
    Selection: TControlSelection;
    DDC: TDesignerDeviceContext;

    constructor Create(TheDesignerForm: TCustomForm; AControlSelection: TControlSelection);
    procedure PrepareFreeDesigner(AFreeComponent: boolean); override;
    procedure DisconnectComponent; override;
    destructor Destroy; override;

    procedure Modified; override;
    procedure SelectOnlyThisComponent(AComponent: TComponent); override;
    function CopySelection: boolean; override;
    function CutSelection: boolean; override;
    function CanCopy: Boolean; override;
    function CanPaste: Boolean; override;
    function PasteSelection(PasteFlags: TComponentPasteSelectionFlags): boolean; override;
    function ClearSelection: boolean; override;
    function DeleteSelection: boolean; override;
    function CopySelectionToStream(AllComponentsStream: TStream): boolean; override;
    function InsertFromStream(s: TStream; Parent: TWinControl;
                              PasteFlags: TComponentPasteSelectionFlags): Boolean; override;
    function InvokeComponentEditor(AComponent: TComponent): boolean; override;
    function ChangeClass: boolean; override;

    procedure DoProcessCommand(Sender: TObject; var Command: word;
                               var Handled: boolean);

    function CanUndo: Boolean; override;
    function CanRedo: Boolean; override;
    function Undo: Boolean; override;
    function Redo: Boolean; override;
    function AddUndoAction(const aPersistent: TPersistent; aOpType: TUndoOpType;
      StartNewGroup: boolean; aFieldName: string; const aOldVal, aNewVal: Variant): boolean; override;
    function IsUndoLocked: boolean; override;
    procedure ClearUndoItem(AIndex: Integer);
    procedure AddComponent(const NewRegisteredComponent: TRegisteredComponent;
      const NewComponentClass: TComponentClass; const NewParent: TComponent;
      const NewLeft, NewTop, NewWidth, NewHeight: Integer); override;
    procedure AddComponentCheckParent(var NewParent: TComponent;
      const OriginComponent: TComponent; const OriginWinControl: TWinControl;
      const NewComponentClass: TComponentClass); override;

    function NonVisualComponentLeftTop(AComponent: TComponent): TPoint;
    function NonVisualComponentAtPos(X, Y: integer): TComponent;
    procedure MoveNonVisualComponentIntoForm(AComponent: TComponent);
    procedure MoveNonVisualComponentsIntoForm;
    function WinControlAtPos(x,y: integer; UseRootAsDefault,
                             IgnoreHidden: boolean): TWinControl;
    function ControlAtPos(x,y: integer; UseRootAsDefault,
                          IgnoreHidden: boolean): TControl;
    function ComponentAtPos(x,y: integer; UseRootAsDefault,
                            IgnoreHidden: boolean): TComponent;
    function GetDesignedComponent(AComponent: TComponent): TComponent;
    function GetComponentEditorForSelection: TBaseComponentEditor;
    function GetShiftState: TShiftState; override;

    procedure AddComponentEditorMenuItems(AComponentEditor: TBaseComponentEditor;
                                          ClearOldOnes: boolean);

    function IsDesignMsg(Sender: TControl;
                                  var TheMessage: TLMessage): Boolean; override;
    procedure UTF8KeyPress(var UTF8Key: TUTF8Char); override;
    function UniqueName(const BaseName: string): string; override;
    Procedure RemovePersistentAndChilds(APersistent: TPersistent);
    procedure Notification({%H-}AComponent: TComponent;
                           Operation: TOperation); override;
    procedure ValidateRename(AComponent: TComponent;
       const CurName, NewName: string); override;
    function CreateUniqueComponentName(const AClassName: string): string; override;

    procedure PaintGrid; override;
    procedure PaintClientGrid(AWinControl: TWinControl;
       aDDC: TDesignerDeviceContext);
    procedure DrawNonVisualComponents(aDDC: TDesignerDeviceContext);
    procedure DrawDesignerItems(OnlyIfNeeded: boolean); override;
    procedure CheckFormBounds;
    procedure DoPaintDesignerItems;
    function ComponentIsIcon(AComponent: TComponent): boolean;
    function GetParentFormRelativeClientOrigin(AComponent: TComponent): TPoint;
  public
    property Flags: TDesignerFlags read FFlags;
    property GridSizeX: integer read GetGridSizeX write SetGridSizeX;
    property GridSizeY: integer read GetGridSizeY write SetGridSizeY;
    property GridColor: TColor read GetGridColor write SetGridColor;
    property IsControl: Boolean read GetIsControl;
    property Mediator: TDesignerMediator read FMediator write SetMediator;
    property ProcessingDesignerEvent: Integer read FProcessingDesignerEvent;
    property OnActivated: TNotifyEvent read FOnActivated write FOnActivated;
    property OnCloseQuery: TNotifyEvent read FOnCloseQuery write FOnCloseQuery;
    property OnPersistentDeleted: TOnPersistentDeleted
                             read FOnPersistentDeleted write FOnPersistentDeleted;
    property OnGetNonVisualCompIcon: TOnGetNonVisualCompIcon
                      read FOnGetNonVisualCompIcon write FOnGetNonVisualCompIcon;
    property OnGetSelectedComponentClass: TOnGetSelectedComponentClass
                                             read FOnGetSelectedComponentClass
                                             write FOnGetSelectedComponentClass;
    property OnProcessCommand: TOnProcessCommand
                                 read FOnProcessCommand write FOnProcessCommand;
    property OnModified: TNotifyEvent read FOnModified write FOnModified;
    property OnPasteComponents: TOnPasteComponents read FOnPasteComponent
                                                 write FOnPasteComponent;
    property OnPastedComponents: TOnPastedComponents read FOnPastedComponents
                                                 write FOnPastedComponents;
    property OnPropertiesChanged: TNotifyEvent
                           read FOnPropertiesChanged write FOnPropertiesChanged;
    property OnRenameComponent: TOnRenameComponent
                               read FOnRenameComponent write FOnRenameComponent;
    property OnSetDesigning: TOnSetDesigning read FOnSetDesigning write FOnSetDesigning;
    property OnComponentAdded: TOnComponentAdded read FOnComponentAdded
                                                write FOnComponentAdded;
    property OnShowOptions: TNotifyEvent read FOnShowOptions write FOnShowOptions;
    property OnViewLFM: TNotifyEvent read FOnViewLFM write FOnViewLFM;
    property OnSaveAsXML: TNotifyEvent read FOnSaveAsXML write FOnSaveAsXML;
    property OnShowObjectInspector: TNotifyEvent read FOnShowObjectInspector write FOnShowObjectInspector;
    property OnShowAnchorEditor: TNotifyEvent read FOnShowAnchorEditor write FOnShowAnchorEditor;
    property OnShowTabOrderEditor: TNotifyEvent read FOnShowTabOrderEditor write FOnShowTabOrderEditor;
    property OnForwardKeyToObjectInspector: TOnForwardKeyToObjectInspector read FOnForwardKeyToObjectInspector
                                                                          write FOnForwardKeyToObjectInspector;
    property OnChangeParent: TNotifyEvent read FOnChangeParent write FOnChangeParent;

    property ShowGrid: boolean read GetShowGrid write SetShowGrid;
    property ShowBorderSpacing: boolean read GetShowBorderSpacing write SetShowBorderSpacing;
    property ShowEditorHints: boolean read GetShowEditorHints write SetShowEditorHints;
    property ShowComponentCaptions: boolean read GetShowComponentCaptions
                                           write SetShowComponentCaptions;
    property ShowNonVisualComponents: boolean read GetShowNonVisualComponents write SetShowNonVisualComponents;
    property SnapToGrid: boolean read GetSnapToGrid write SetSnapToGrid;
    property TheFormEditor: TCustomFormEditor read FTheFormEditor write FTheFormEditor;
    property DefaultFormBounds: TRect read FDefaultFormBounds write SetDefaultFormBounds;
  end;

const
  DesignerMenuRootName = 'Designer';
var
  DesignerMenuAlign: TIDEMenuCommand;
  DesignerMenuMirrorHorizontal: TIDEMenuCommand;
  DesignerMenuMirrorVertical: TIDEMenuCommand;
  DesignerMenuScale: TIDEMenuCommand;
  DesignerMenuSize: TIDEMenuCommand;
  DesignerMenuReset: TIDEMenuCommand;

  DesignerMenuAnchorEditor: TIDEMenuCommand;
  DesignerMenuTabOrder: TIDEMenuCommand;
    DesignerMenuOrderMoveToFront: TIDEMenuCommand;
    DesignerMenuOrderMoveToBack: TIDEMenuCommand;
    DesignerMenuOrderForwardOne: TIDEMenuCommand;
    DesignerMenuOrderBackOne: TIDEMenuCommand;

  DesignerMenuCut: TIDEMenuCommand;
  DesignerMenuCopy: TIDEMenuCommand;
  DesignerMenuPaste: TIDEMenuCommand;
  DesignerMenuDeleteSelection: TIDEMenuCommand;
  DesignerMenuSelectAll: TIDEMenuCommand;

  DesignerMenuChangeClass: TIDEMenuCommand;
  DesignerMenuChangeParent: TIDEMenuCommand;
  DesignerMenuViewLFM: TIDEMenuCommand;
  DesignerMenuSaveAsXML: TIDEMenuCommand;
  DesignerMenuCenterForm: TIDEMenuCommand;

  DesignerMenuShowNonVisualComponents: TIDEMenuCommand;
  DesignerMenuSnapToGridOption: TIDEMenuCommand;
  DesignerMenuSnapToGuideLinesOption: TIDEMenuCommand;
  DesignerMenuShowOptions: TIDEMenuCommand;


procedure RegisterStandardDesignerMenuItems;


implementation

type
  TCustomFormAccess = class(TCustomForm);
  TControlAccess = class(TControl);
  TWinControlAccess = class(TWinControl);
  TComponentAccess = class(TComponent);

  { TComponentSearch }

  TComponentSearch = class(TComponent)
  public
    Best: TComponent;
    BestLevel: integer;
    BestIsNonVisual: boolean;
    Level: integer;
    AtPos: TPoint;
    MinClass: TComponentClass;
    IgnoreHidden: boolean;
    OnlyNonVisual: boolean;
    IgnoreNonVisual: boolean;
    Mediator: TDesignerMediator;
    Root: TComponent;
    procedure Gather(Child: TComponent);
    procedure Search(ARoot: TComponent);
  end;

{ TComponentSearch }

procedure TComponentSearch.Gather(Child: TComponent);
var
  Control: TControl;
  ChildBounds: TRect;
  OldRoot: TComponent;
  IsNonVisual: Boolean;
begin
  if Assigned(Best) and BestIsNonVisual and (BestLevel < Level) then exit;
  {$IFDEF VerboseDesignerSelect}
  DebugLn(['TComponentSearch.Gather ',DbgSName(Child),' ',dbgs(AtPos),' MinClass=',DbgSName(MinClass)]);
  {$ENDIF}
  // check if child is at position
  if Child is TControl then
  begin
    Control := TControl(Child);
    if IgnoreHidden and (csNoDesignVisible in Control.ControlStyle) then
      exit;
    if csNoDesignSelectable in Control.ControlStyle then
      exit;
  end
  else
    Control := nil;
  ChildBounds := GetParentFormRelativeBounds(Child);
  {$IFDEF VerboseDesignerSelect}
  DebugLn(['TComponentSearch.Gather PtInRect=',PtInRect(ChildBounds, AtPos),' ChildBounds=',dbgs(ChildBounds)]);
  {$ENDIF}
  if not PtInRect(ChildBounds, AtPos) then Exit;

  if Assigned(Mediator) then
    IsNonVisual := Mediator.ComponentIsIcon(Child)
  else
    IsNonVisual := DesignerProcs.ComponentIsNonVisual(Child);

  if IsNonVisual then begin
    if IgnoreNonVisual then exit;
    if Assigned(IDEComponentsMaster)
    and not IDEComponentsMaster.DrawNonVisualComponents(Root) then
      Exit;
  end;

  if Child.InheritsFrom(MinClass) and (IsNonVisual or not OnlyNonVisual) then
  begin
    Best := Child;
    BestIsNonVisual := IsNonVisual;
    BestLevel := Level;
    {$IFDEF VerboseDesignerSelect}
    DebugLn(['TComponentSearch.Gather Best=',DbgSName(Best)]);
    {$ENDIF}
  end;

  // search in children
  if (csInline in Child.ComponentState) or
     (Assigned(Control) and not (csOwnedChildrenNotSelectable in Control.ControlStyle)) then
  begin
    {$IFDEF VerboseDesignerSelect}
    DebugLn(['TComponentSearch.Gather search in children of ',DbgSName(Child)]);
    {$ENDIF}
    OldRoot := Root;
    try
      inc(Level);
      if csInline in Child.ComponentState then
        Root := Child;
      {$IFDEF VerboseDesignerSelect}
      DebugLn(['TComponentSearch.Gather Root=',DbgSName(Root)]);
      {$ENDIF}
      TComponentAccess(Child).GetChildren(@Gather, Root);
    finally
      dec(Level);
      Root := OldRoot;
    end;
    {$IFDEF VerboseDesignerSelect}
    DebugLn(['TComponentSearch.Gather searched in children of ',DbgSName(Child)]);
    {$ENDIF}
  end;
end;

procedure TComponentSearch.Search(ARoot: TComponent);
begin
  Root := ARoot;
  Level := 1;
  TComponentAccess(Root).GetChildren(@Gather, Root);
  Level := 0;
end;

const
  mk_lbutton =   1;
  mk_rbutton =   2;
  mk_shift   =   4;
  mk_control =   8;
  mk_mbutton = $10;

procedure RegisterStandardDesignerMenuItems;
begin
  DesignerMenuRoot:=RegisterIDEMenuRoot(DesignerMenuRootName);

  // register the dynamic section for the component editor
  DesignerMenuSectionComponentEditor:=RegisterIDEMenuSection(DesignerMenuRoot,
                                                    'Component editor section');

  // register the custom dynamic section
  DesignerMenuSectionCustomDynamic:=RegisterIDEMenuSection(DesignerMenuRoot,
                                                      'Custom dynamic section');

  // register align section
  DesignerMenuSectionAlign:=RegisterIDEMenuSection(DesignerMenuRoot,'Align section');
    DesignerMenuAlign:=RegisterIDEMenuCommand(DesignerMenuSectionAlign,
        'Align',fdmAlignMenu, nil, nil, nil, 'align');
    DesignerMenuMirrorHorizontal:=RegisterIDEMenuCommand(DesignerMenuSectionAlign,
        'Mirror horizontal',fdmMirrorHorizontal, nil, nil, nil, 'mirror_horizontal');
    DesignerMenuMirrorVertical:=RegisterIDEMenuCommand(DesignerMenuSectionAlign,
        'Mirror vertical',fdmMirrorVertical, nil, nil, nil, 'mirror_vertical');
    DesignerMenuScale:=RegisterIDEMenuCommand(DesignerMenuSectionAlign,
        'Scale',fdmScaleMenu, nil, nil, nil, 'scale');
    DesignerMenuSize:=RegisterIDEMenuCommand(DesignerMenuSectionAlign,
        'Size',fdmSizeMenu, nil, nil, nil, 'size');
    DesignerMenuReset:=RegisterIDEMenuCommand(DesignerMenuSectionAlign,
        'Reset', fdmResetMenu, nil, nil, nil, '');

  // register tab and z-order section
  DesignerMenuSectionOrder:=RegisterIDEMenuSection(DesignerMenuRoot,'Order section');
    DesignerMenuAnchorEditor:=RegisterIDEMenuCommand(DesignerMenuSectionOrder,
        'Anchor Editor',lisMenuViewAnchorEditor, nil, nil, nil, 'menu_view_anchor_editor');
    DesignerMenuTabOrder:=RegisterIDEMenuCommand(DesignerMenuSectionOrder,
        'Tab order',lisMenuViewTabOrder, nil, nil, nil, 'tab_order');
    DesignerMenuSectionZOrder:=RegisterIDESubMenu(DesignerMenuSectionOrder,
        'ZOrder section', fdmZOrder);
      DesignerMenuOrderMoveToFront:=RegisterIDEMenuCommand(DesignerMenuSectionZOrder,
          'Move to z order front',fdmOrderMoveTofront, nil, nil, nil, 'Order_move_front');
      DesignerMenuOrderMoveToBack:=RegisterIDEMenuCommand(DesignerMenuSectionZOrder,
          'Move to z order back',fdmOrderMoveToBack, nil, nil, nil, 'Order_move_back');
      DesignerMenuOrderForwardOne:=RegisterIDEMenuCommand(DesignerMenuSectionZOrder,
          'Move z order forward one',fdmOrderForwardOne, nil, nil, nil, 'Order_forward_one');
      DesignerMenuOrderBackOne:=RegisterIDEMenuCommand(DesignerMenuSectionZOrder,
          'Move z order backwards one',fdmOrderBackOne, nil, nil, nil, 'Order_back_one');

  // register clipboard section
  DesignerMenuSectionClipboard:=RegisterIDEMenuSection(DesignerMenuRoot,'Clipboard section');
    DesignerMenuCut:=RegisterIDEMenuCommand(DesignerMenuSectionClipboard,
        'Cut',lisCut, nil, nil, nil, 'laz_cut');
    DesignerMenuCopy:=RegisterIDEMenuCommand(DesignerMenuSectionClipboard,
        'Copy',lisCopy, nil, nil, nil, 'laz_copy');
    DesignerMenuPaste:=RegisterIDEMenuCommand(DesignerMenuSectionClipboard,
        'Paste',lisPaste, nil, nil, nil, 'laz_paste');
    DesignerMenuDeleteSelection:=RegisterIDEMenuCommand(DesignerMenuSectionClipboard,
        'Delete Selection',fdmDeleteSelection, nil, nil, nil, 'delete_selection');
    DesignerMenuSelectAll:=RegisterIDEMenuCommand(DesignerMenuSectionClipboard,
        'Select All',fdmSelectAll, nil, nil, nil, 'menu_select_all');

  // register miscellaneous section
  DesignerMenuSectionMisc:=RegisterIDEMenuSection(DesignerMenuRoot,'Miscellaneous section');
    DesignerMenuChangeClass:=RegisterIDEMenuCommand(DesignerMenuSectionMisc,
                                                 'Change class',lisDlgChangeClass);
    DesignerMenuChangeParent:=RegisterIDEMenuCommand(DesignerMenuSectionMisc,
                                                 'Change parent',lisChangeParent+' ...');
    DesignerMenuViewLFM:=RegisterIDEMenuCommand(DesignerMenuSectionMisc,
                                                'View LFM',lisViewSourceLfm);
    DesignerMenuSaveAsXML:=RegisterIDEMenuCommand(DesignerMenuSectionMisc,
                                                'Save as XML',fdmSaveFormAsXML);
    DesignerMenuCenterForm:=RegisterIDEMenuCommand(DesignerMenuSectionMisc,
                                                'Center form', lisCenterForm);

  // register options section
  DesignerMenuSectionOptions:=RegisterIDEMenuSection(DesignerMenuRoot,'Options section');
    DesignerMenuShowNonVisualComponents:=RegisterIDEMenuCommand(DesignerMenuSectionMisc,
                                                'Show non visual components',
                                                  lisDsgShowNonVisualComponents);
    DesignerMenuShowNonVisualComponents.ShowAlwaysCheckable:=true;
    DesignerMenuSnapToGridOption:=RegisterIDEMenuCommand(DesignerMenuSectionOptions,
                                            'Snap to grid',fdmSnapToGridOption);
    DesignerMenuSnapToGuideLinesOption:=RegisterIDEMenuCommand(DesignerMenuSectionOptions,
                               'Snap to guide lines',fdmSnapToGuideLinesOption);
    DesignerMenuShowOptions:=RegisterIDEMenuCommand(DesignerMenuSectionOptions,
        'Show options',lisOptions, nil, nil, nil, 'menu_environment_options');
end;

// inline
procedure TDesigner.SetNextUndoGroupId;
begin
  LUIncreaseChangeStamp64(FUndoGroupId);
end;

constructor TDesigner.Create(TheDesignerForm: TCustomForm;
  AControlSelection: TControlSelection);
var
  LNonControlDesigner: INonControlDesigner;
  i: integer;
begin
  inherited Create;
  //debugln(['TDesigner.Create Self=',dbgs(Pointer(Self)),' TheDesignerForm=',DbgSName(TheDesignerForm)]);
  FForm := TheDesignerForm;
  if FForm is BaseFormEditor1.NonFormProxyDesignerForm[NonControlProxyDesignerFormId] then begin
    LNonControlDesigner := FForm as INonControlDesigner;
    FLookupRoot := LNonControlDesigner.LookupRoot;
    Mediator := LNonControlDesigner.Mediator;
  end
  else if FForm is BaseFormEditor1.NonFormProxyDesignerForm[FrameProxyDesignerFormId] then
    FLookupRoot := (FForm as IFrameDesigner).LookupRoot
  else
    FLookupRoot := FForm;

  Selection := AControlSelection;
  FFlags := [dfShowNonVisualComponents];
  FGridColor := clGray;

  FHintTimer := TTimer.Create(nil);
  FHintTimer.Interval := 500;
  FHintTimer.Enabled := False;
  FHintTimer.OnTimer := @HintTimer;

  FHintWindow := THintWindow.Create(nil);

  FHIntWindow.Visible := False;
  FHintWindow.HideInterval := 4000;
  FHintWindow.AutoHide := True;

  DDC:=TDesignerDeviceContext.Create;
  LastFormCursor := crDefault;
  DeletingPersistent:=TList.Create;
  FPopupMenuComponentEditor := nil;

  SetLength(FUndoList, 64);
  for i := Low(FUndoList) to High(FUndoList) do
    ClearUndoItem(i);
  FUndoCurr := Low(FUndoList);
  FUndoLock := 0;
  FUndoState := ucsNone;
  FUndoGroupId := 1;
end;

procedure TDesigner.AddComponent(
  const NewRegisteredComponent: TRegisteredComponent;
  const NewComponentClass: TComponentClass; const NewParent: TComponent;
  const NewLeft, NewTop, NewWidth, NewHeight: Integer);
var
  NewComponent: TComponent;
  DisableAutoSize: Boolean;
  NewControl: TControl;
begin
  if NewParent=nil then exit;
  if NewComponentClass = nil then exit;

  // add a new component
  Selection.RubberbandActive:=false;
  Selection.Clear;

  if not PropertyEditorHook.BeforeAddPersistent(Self, NewComponentClass, NewParent)
  then begin
    DebugLn('Note: TDesigner.AddComponent BeforeAddPersistent failed: ComponentClass=',
            NewComponentClass.ClassName,' NewParent=',DbgSName(NewParent));
    exit;
  end;

  // check cycles
  if TheFormEditor.ClassDependsOnComponent(NewComponentClass, LookupRoot) then
  begin
    IDEMessageDialog(lisA2PInvalidCircularDependency,
      Format(lisIsAThisCircularDependencyIsNotAllowed, [dbgsName(LookupRoot),
        dbgsName(NewComponentClass), LineEnding]),
      mtError,[mbOk],'');
    exit;
  end;

  // create component and component interface
  DebugLn(['AddComponent ',DbgSName(NewComponentClass),' Parent=',DbgSName(NewParent),' ',NewLeft,',',NewTop,',',NewWidth,',',NewHeight]);
  DisableAutoSize:=true;
  NewComponent := TheFormEditor.CreateComponent(
     NewParent,NewComponentClass,'',
     NewLeft,NewTop,NewWidth,NewHeight,DisableAutoSize);
  if NewComponent=nil then exit;
  if DisableAutoSize and (NewComponent is TControl) then
    TControl(NewComponent).EnableAutoSizing{$IFDEF DebugDisableAutoSizing}('TDesigner.AddComponent'){$ENDIF};
  TheFormEditor.FixupReferences(NewComponent); // e.g. frame references a datamodule

  // modified
  Modified;

  // set initial properties
  if NewComponent is TControl then begin
    NewControl:=TControl(NewComponent);
    //debugln(['AddComponent ',DbgSName(Self),' Bounds=',dbgs(NewControl.BoundsRect),' BaseBounds=',dbgs(NewControl.BaseBounds),' BaseParentClientSize=',dbgs(NewControl.BaseParentClientSize)]);
    NewControl.Visible:=true;
    if csSetCaption in NewControl.ControlStyle then
      NewControl.Caption:=NewComponent.Name;
  end;
  if Assigned(FOnSetDesigning) then
    FOnSetDesigning(Self,NewComponent,True);

  if EnvironmentOptions.CreateComponentFocusNameProperty then
    ShowComponentNameDialog(LookupRoot,NewComponent);  // ask user for name

  // tell IDE about the new component (e.g. add it to the source)
  NotifyComponentAdded(NewComponent);

  // creation completed
  // -> select new component
  SelectOnlyThisComponent(NewComponent);
  if Assigned(FOnComponentAdded) then // this resets the component palette to the selection tool
    FOnComponentAdded(Self, NewComponent, NewRegisteredComponent);

  {$IFDEF VerboseDesigner}
  DebugLn('NEW COMPONENT ADDED: Form.ComponentCount=',DbgS(Form.ComponentCount),
     '  NewComponent.Owner.Name=',NewComponent.Owner.Name);
  {$ENDIF}
  AddUndoAction(NewComponent, uopAdd, true, 'Name', '', NewComponent.Name);
end;

procedure TDesigner.AddComponentCheckParent(var NewParent: TComponent;
  const OriginComponent: TComponent; const OriginWinControl: TWinControl;
  const NewComponentClass: TComponentClass);
var
  NewParentControl: TWinControl;
begin
  if Mediator<>nil then begin
    // mediator, non LCL components
    if NewParent=nil then
      NewParent:=OriginComponent;
    while (NewParent<>nil)
    and (not Mediator.ParentAcceptsChild(NewParent,NewComponentClass)) do
      NewParent:=NewParent.GetParentComponent;
    if NewParent=nil then
      NewParent:=FLookupRoot;
  end else if (FLookupRoot is TCustomForm) or (FLookupRoot is TCustomFrame)
  then begin
    // LCL controls
    if NewParent<>nil then begin
      if not (NewParent is TWinControl) then begin
        debugln(['ERROR: AddComponent failed: AddClicked returned not a TWinControl: ',DbgSName(NewParent)]);
        exit;
      end;
      NewParentControl := TWinControl(NewParent);
    end else if OriginComponent is TWinControl then
      NewParentControl := TWinControl(OriginComponent)
    else
      NewParentControl := OriginWinControl;

    while (NewParentControl <> nil)
    and not ControlAcceptsStreamableChildComponent(NewParentControl,
                                                NewComponentClass,FLookupRoot)
    do
      NewParentControl := NewParentControl.Parent;
    NewParent := NewParentControl;
    //debugln(['AddComponent NewParent=',DbgSName(NewParent)]);
  end else begin
    // TDataModule
    NewParent := FLookupRoot;
  end;
end;

procedure TDesigner.PrepareFreeDesigner(AFreeComponent: boolean);
begin
  // was FinalizeFreeDesigner
  Include(FFlags, dfDestroyingForm);
  // free or hide the form
  DebugLn(['TDesigner.PrepareFreeDesigner: TheFormEditor=', TheFormEditor, ', Designer=', Self]);
  TheFormEditor.DeleteComponent(FLookupRoot,AFreeComponent);
  DisconnectComponent;
  Free;
end;

procedure TDesigner.DisconnectComponent;
begin
  //debugln(['TDesigner.DisconnectComponent Self=',dbgs(Pointer(Self))]);
  inherited DisconnectComponent;
  if Mediator<>nil then begin
    Mediator.Designer:=nil;
    FMediator:=nil;
  end;
  FLookupRoot:=nil;
end;

destructor TDesigner.Destroy;
begin
  //debugln(['TDesigner.Destroy Self=',dbgs(Pointer(Self))]);
  Application.RemoveAsyncCalls(Self);
  PopupMenuComponentEditor := nil;
  FreeAndNil(FDesignerPopupMenu);
  FreeAndNil(FHintWIndow);
  FreeAndNil(FHintTimer);
  FreeAndNil(DDC);
  FreeAndNil(DeletingPersistent);
  inherited Destroy;
end;

procedure TDesigner.NudgePosition(DiffX, DiffY : Integer);
begin
  {$IFDEF VerboseDesigner}
  DebugLn('[TDesigner.NudgePosition]');
  {$ENDIF}
  if (Selection.SelectionForm<>Form)
  or Selection.LookupRootSelected then exit;
  Selection.MoveSelection(DiffX, DiffY, False);
  Modified;
end;

procedure TDesigner.NudgeSize(DiffX, DiffY: Integer);
begin
  {$IFDEF VerboseDesigner}
  DebugLn('[TDesigner.NudgeSize]');
  {$ENDIF}
  if (Selection.SelectionForm<>Form)
  or Selection.LookupRootSelected then exit;
  Selection.SizeSelection(DiffX, DiffY);
  Modified;
end;

function ComponentsSortByLeft(Item1, Item2: Pointer): Integer;
var
  Comp1: TComponent absolute Item1;
  Comp2: TComponent absolute Item2;
  L1, L2: Integer;
begin
  L1 := GetComponentLeft(Comp1);
  L2 := GetComponentLeft(Comp2);
  if L1 < L2 then
    Result := -1
  else
  if L1 > L2 then
    Result := 1
  else
    Result := 0;
end;

function ComponentsSortByTop(Item1, Item2: Pointer): Integer;
var
  Comp1: TComponent absolute Item1;
  Comp2: TComponent absolute Item2;
  T1, T2: Integer;
begin
  T1 := GetComponentTop(Comp1);
  T2 := GetComponentTop(Comp2);
  if T1 < T2 then
    Result := -1
  else
  if T1 > T2 then
    Result := 1
  else
    Result := 0;
end;

procedure TDesigner.NudgeSelection(DiffX, DiffY: Integer);
const
  Delta = 50; // radius for searching components
var
  List: TFPList;
  Coord, Test: TPoint;
  Current, AComponent: TComponent;
  i: integer;
begin
  if (Selection.SelectionForm <> Form) or
     (Selection.SelectionForm.ComponentCount = 0) or
     Selection.LookupRootSelected or
     (Selection.Count <> 1) then Exit;
  if not Selection[0].IsTComponent then Exit;

  // create a list of components at the similar top/left
  Current := TComponent(Selection[0].Persistent);
  AComponent := nil;
  List := TFPList.Create;
  try
    Coord := GetParentFormRelativeClientOrigin(Current);
    if DiffX <> 0 then
    begin
      for i := 0 to Selection.SelectionForm.ComponentCount - 1 do
      begin
        AComponent := Selection.SelectionForm.Components[i];
        if (AComponent = Current) or ComponentIsInvisible(AComponent) then
          Continue;
        Test := GetParentFormRelativeClientOrigin(AComponent);
        if (Abs(Test.Y - Coord.Y) <= Delta) and
           (Sign(Test.X - Coord.X) = Sign(DiffX)) then
          List.Add(AComponent);
      end;
      if List.Count > 0 then
      begin
        List.Sort(@ComponentsSortByLeft);
        if DiffX > 0 then
          AComponent := TComponent(List[0])
        else
          AComponent := TComponent(List[List.Count - 1]);
      end
      else
        AComponent := nil;
    end
    else
    if DiffY <> 0 then
    begin
      for i := 0 to Selection.SelectionForm.ComponentCount - 1 do
      begin
        AComponent := Selection.SelectionForm.Components[i];
        if (AComponent = Current) or ComponentIsInvisible(AComponent) then
          Continue;
        Test := GetParentFormRelativeClientOrigin(AComponent);
        if (Abs(Test.X - Coord.X) <= Delta) and
           (Sign(Test.Y - Coord.Y) = Sign(DiffY)) then
          List.Add(AComponent);
      end;
      if List.Count > 0 then
      begin
        List.Sort(@ComponentsSortByTop);
        if DiffY > 0 then
          AComponent := TComponent(List[0])
        else
          AComponent := TComponent(List[List.Count - 1]);
      end
      else
        AComponent := nil;
    end;
  finally
    List.Free;
  end;
  if AComponent <> nil then
  begin
    Selection.AssignPersistent(AComponent);
    Modified;
  end;
end;

procedure TDesigner.NudgeSelection(SelectNext: Boolean);

  function StepIndex(Index: Integer): Integer;
  begin
    Result := Index;
    if SelectNext then
      Inc(Result)
    else
      Dec(Result);

    if Result >= Selection.SelectionForm.ComponentCount then
      Result := 0
    else
    if Result < 0 then
      Result := Selection.SelectionForm.ComponentCount - 1;
  end;

var
  Index, StartIndex: Integer;
  AComponent: TComponent;
begin
  if (Selection.SelectionForm <> Form) or
     (Selection.SelectionForm.ComponentCount = 0) then Exit;
  if (Selection.Count = 1) and Selection[0].IsTComponent then
    Index := TComponent(Selection[0].Persistent).ComponentIndex
  else
    Index := -1;

  Index := StepIndex(Index);
  StartIndex := Index;

  AComponent := nil;
  while AComponent = nil do
  begin
    AComponent := Selection.SelectionForm.Components[Index];
    if ComponentIsInvisible(AComponent) then
    begin
      AComponent := nil;
      Index := StepIndex(Index);
      if Index = StartIndex then
        break;
    end;
  end;

  if AComponent <> nil then
  begin
    Selection.AssignPersistent(AComponent);
    Modified;
  end;
end;

procedure TDesigner.SelectParentOfSelection;

  function ParentComponent(AComponent: TComponent): TComponent;
  begin
    Result := AComponent.GetParentComponent;
    if (Result = nil) and ComponentIsIcon(AComponent) then
      Result := AComponent.Owner;
  end;

var
  i: Integer;
begin
  // resizing or moving
  if dfHasSized in FFlags then
  begin
    Selection.RestoreBounds;
    Selection.ActiveGrabber := nil;
    if Selection.RubberbandActive then
      Selection.RubberbandActive := False;
    LastMouseMovePos.X := -1;
    Exclude(FFlags, dfHasSized);
    MouseDownComponent := nil;
    MouseDownSender := nil;
    Exit;
  end;

  if Selection.OnlyInvisiblePersistentsSelected then
    Exit;

  if Selection.LookupRootSelected then
  begin
    SelectOnlyThisComponent(FLookupRoot);
    Exit;
  end;

  // if not component moving then select parent
  i := Selection.Count - 1;
  while (i >= 0) and
        (Selection[i].ParentInSelection or
         not Selection[i].IsTComponent or
         (ParentComponent(TComponent(Selection[i].Persistent)) = nil)) do
    Dec(i);
  if i >= 0 then
    SelectOnlyThisComponent(ParentComponent(TComponent(Selection[i].Persistent)));
end;

function TDesigner.CopySelectionToStream(AllComponentsStream: TStream): boolean;

  function UnselectDistinctControls: boolean;
  var
    i: Integer;
    AParent, CurParent: TWinControl;
  begin
    Result:=false;
    AParent:=nil;
    i:=0;
    while i<Selection.Count do begin
      if Selection[i].IsTControl then begin
        // unselect controls from which the parent is selected too
        if Selection[i].ParentInSelection then begin
          Selection.Delete(i);
          continue;
        end;

        // check if not the top level component is selected
        CurParent:=TControl(Selection[i].Persistent).Parent;
        if CurParent=nil then begin
          IDEMessageDialog(lisCanNotCopyTopLevelComponent,
            lisCopyingAWholeFormIsNotImplemented,
            mtError,[mbOk]);
          exit;
        end;

        // unselect all controls, that do not have the same parent
        if (AParent=nil) then
          AParent:=CurParent
        else if (AParent<>CurParent) then begin
          Selection.Delete(i);
          continue;
        end;
      end;
      inc(i);
    end;
    Result:=true;
  end;

var
  i: Integer;
  BinCompStream: TMemoryStream;
  TxtCompStream: TMemoryStream;
  CurComponent: TComponent;
  DestroyDriver: Boolean;
  Writer: TWriter;
begin
  Result:=false;
  if (Selection.Count=0) then exit;

  // Because controls will be pasted on a single parent,
  // unselect all controls, that do not have the same parent
  if not UnselectDistinctControls then exit;

  for i:=0 to Selection.Count-1 do begin
    if not Selection[i].IsTComponent then continue;

    BinCompStream:=TMemoryStream.Create;
    TxtCompStream:=TMemoryStream.Create;
    try
      // write component binary stream
      try
        CurComponent:=TComponent(Selection[i].Persistent);

        DestroyDriver:=false;
        Writer := CreateLRSWriter(BinCompStream,DestroyDriver);
        try
          Writer.OnWriteMethodProperty:=@BaseFormEditor1.WriteMethodPropertyEvent;
          Writer.Root:=FLookupRoot;
          Writer.WriteComponent(CurComponent);
        finally
          if DestroyDriver then Writer.Driver.Free;
          Writer.Destroy;
        end;
      except
        on E: Exception do begin
          IDEMessageDialog(lisUnableToStreamSelectedComponents,
            Format(lisThereWasAnErrorDuringWritingTheSelectedComponent, [
              CurComponent.Name, CurComponent.ClassName, LineEnding, E.Message]),
            mtError,[mbOk]);
          exit;
        end;
      end;
      BinCompStream.Position:=0;
      // convert binary to text stream
      try
        LRSObjectBinaryToText(BinCompStream,TxtCompStream);
      except
        on E: Exception do begin
          IDEMessageDialog(lisUnableConvertBinaryStreamToText,
            Format(lisThereWasAnErrorWhileConvertingTheBinaryStreamOfThe, [
              CurComponent.Name, CurComponent.ClassName, LineEnding, E.Message]),
            mtError,[mbOk]);
          exit;
        end;
      end;
      // add text stream to the all stream
      TxtCompStream.Position:=0;
      AllComponentsStream.CopyFrom(TxtCompStream,TxtCompStream.Size);
    finally
      BinCompStream.Free;
      TxtCompStream.Free;
    end;
  end;
  Result:=true;
end;

function TDesigner.InsertFromStream(s: TStream; Parent: TWinControl;
  PasteFlags: TComponentPasteSelectionFlags): Boolean;
begin
  Result:=DoInsertFromStream(s,Parent,PasteFlags);
end;

function TDesigner.DoCopySelectionToClipboard: boolean;
var
  AllComponentsStream: TMemoryStream;
  AllComponentText: string;
begin
  Result := false;
  if Selection.Count = 0 then exit;
  if Selection.OnlyInvisiblePersistentsSelected then exit;

  AllComponentsStream:=TMemoryStream.Create;
  try
    // copy components to stream
    if not CopySelectionToStream(AllComponentsStream) then exit;
    SetLength(AllComponentText{%H-},AllComponentsStream.Size);
    if AllComponentText<>'' then begin
      AllComponentsStream.Position:=0;
      AllComponentsStream.Read(AllComponentText[1],length(AllComponentText));
    end;

    // copy to clipboard
    try
      ClipBoard.AsText:=AllComponentText;
    except
      on E: Exception do begin
        IDEMessageDialog(lisUnableCopyComponentsToClipboard,
          Format(lisThereWasAnErrorWhileCopyingTheComponentStreamToCli,
                 [LineEnding, E.Message]),
          mtError,[mbOk]);
        exit;
      end;
    end;
  finally
    AllComponentsStream.Free;
  end;
  Result:=true;
end;

function TDesigner.GetPasteParent: TWinControl;
var
  i: Integer;
begin
  Result:=nil;
  for i:=0 to Selection.Count-1 do begin
    if (Selection[i].IsTWinControl)
    and (csAcceptsControls in
         TWinControl(Selection[i].Persistent).ControlStyle)
    and (not Selection[i].ParentInSelection) then begin
      Result:=TWinControl(Selection[i].Persistent);
      if GetLookupRootForComponent(Result)<>FLookupRoot then
        Result:=nil;
      break;
    end;
  end;
  if (Result=nil) and (FLookupRoot is TWinControl) then
    Result:=TWinControl(FLookupRoot);
end;

procedure TDesigner.DoModified;
begin
  if Assigned(OnModified) then
    OnModified(Self)
end;

function TDesigner.DoPasteSelectionFromClipboard(
  PasteFlags: TComponentPasteSelectionFlags): boolean;
var
  AllComponentText: string;
  CurTextCompStream: TMemoryStream;
begin
  Result:=false;
  if not CanPaste then exit;
  // read component stream from clipboard
  AllComponentText:=ClipBoard.AsText;
  if AllComponentText='' then exit;
  CurTextCompStream:=TMemoryStream.Create;
  try
    CurTextCompStream.Write(AllComponentText[1],length(AllComponentText));
    CurTextCompStream.Position:=0;
    if not DoInsertFromStream(CurTextCompStream,nil,PasteFlags) then
      exit;
  finally
    CurTextCompStream.Free;
  end;
  Result:=true;
end;

function TDesigner.DoInsertFromStream(s: TStream;
  PasteParent: TWinControl; PasteFlags: TComponentPasteSelectionFlags): Boolean;
var
  NewSelection: TPersistentSelectionList;
  NewComps: TFPList;

  procedure FindUniquePosition(AComponent: TComponent);
  var
    OverlappedComponent: TComponent;
    P: TPoint;
    AControl: TControl;
    AParent: TWinControl;
    i: Integer;
    OverlappedControl: TControl;
  begin
    if AComponent is TControl then begin
      AControl:=TControl(AComponent);
      AParent:=AControl.Parent;
      if AParent=nil then exit;
      P:=Point(AControl.Left,AControl.Top);
      i:=AParent.ControlCount-1;
      while i>=0 do begin
        OverlappedControl:=AParent.Controls[i];
        if (NewComps.IndexOf(OverlappedControl)<0)
        and (OverlappedControl.Left=P.X)
        and (OverlappedControl.Top=P.Y) then begin
          inc(P.X,NonVisualCompWidth);
          inc(P.Y,NonVisualCompWidth);
          if (P.X>AParent.ClientWidth-AControl.Width)
          or (P.Y>AParent.ClientHeight-AControl.Height) then
            break;
          i:=AParent.ControlCount-1;
        end else
          dec(i);
      end;
      P.x:=Max(0,Min(P.x,AParent.ClientWidth-AControl.Width));
      P.y:=Max(0,Min(P.y,AParent.ClientHeight-AControl.Height));
      AControl.SetBounds(P.x,P.y,AControl.Width,AControl.Height);
    end else begin
      P:=GetParentFormRelativeTopLeft(AComponent);
      repeat
        OverlappedComponent:=NonVisualComponentAtPos(P.x,P.y);
        if (OverlappedComponent=nil) then break;
        inc(P.X,NonVisualCompWidth);
        inc(P.Y,NonVisualCompWidth);
        if (P.X+NonVisualCompWidth>Form.ClientWidth)
        or (P.Y+NonVisualCompWidth>Form.ClientHeight) then
          break;
      until false;
      AComponent.DesignInfo := LeftTopToDesignInfo(
        SmallInt(Max(0, Min(P.x, Form.ClientWidth - NonVisualCompWidth))),
        SmallInt(Max(0, Min(P.y, Form.ClientHeight - NonVisualCompWidth))));
    end;
  end;

var
  i: Integer;
  NewComponent: TComponent;
begin
  Result:=false;
  //debugln('TDesigner.DoInsertFromStream A');
  if (cpsfReplace in PasteFlags) and (not DeleteSelection) then exit;

  //debugln('TDesigner.DoInsertFromStream B s.Size=',dbgs(s.Size),' S.Position=',dbgs(S.Position));
  if PasteParent=nil then PasteParent:=GetPasteParent;
  NewSelection:=TPersistentSelectionList.Create;
  NewComps:=TFPList.Create;
  try
    Form.DisableAutoSizing{$IFDEF DebugDisableAutoSizing}('TDesigner.DoInsertFromStream'){$ENDIF};
    try

      // read component stream from clipboard
      if (s.Size<=S.Position) then begin
        debugln('TDesigner.DoInsertFromStream Stream Empty s.Size=',dbgs(s.Size),' S.Position=',dbgs(S.Position));
        exit;
      end;

      // create components and add to LookupRoot
      FOnPasteComponent(Self,FLookupRoot,s,PasteParent,NewComps);
      // add new component to new selection
      for i:=0 to NewComps.Count-1 do begin
        NewComponent:=TComponent(NewComps[i]);
        NewSelection.Add(NewComponent);
        // set new nice bounds
        if cpsfFindUniquePositions in PasteFlags then
          FindUniquePosition(NewComponent);
        // finish adding component
        NotifyComponentAdded(NewComponent);
        Modified;
        // add action in undo list
        AddUndoAction(NewComponent, uopAdd, i = 0, 'Name', '', NewComponent.Name);
      end;

      if NewSelection.Count>0 then
        FOnPastedComponents(Self,FLookupRoot);

    finally
      Form.EnableAutoSizing{$IFDEF DebugDisableAutoSizing}('TDesigner.DoInsertFromStream'){$ENDIF};
    end;
  finally
    NewComps.Free;
    if NewSelection.Count>0 then
      Selection.AssignSelection(NewSelection);
    NewSelection.Free;
  end;
  Result:=true;
end;

function TDesigner.DoUndo: Boolean;
var GroupId: int64;
begin
  repeat
    Result := CanUndo;
    if not Result then Exit;
    Dec(FUndoCurr);
    GroupId := FUndoList[FUndoCurr].GroupId;
    ExecuteUndoItem(true);
  until (FUndoCurr=Low(FUndoList)) or (GroupId <> FUndoList[FUndoCurr - 1].GroupId);
end;

function TDesigner.DoRedo: Boolean;
var GroupId: int64;
begin
  repeat
    Result := CanRedo;
    if not Result then Exit;
    ExecuteUndoItem(false);
    GroupId := FUndoList[FUndoCurr].GroupId;
    Inc(FUndoCurr);
  until (FUndoCurr>High(FUndoList)) or (GroupId <> FUndoList[FUndoCurr].GroupId);
end;

procedure TDesigner.ExecuteUndoItem(IsActUndo: boolean);
var
  AValue: Variant;
  ValueStr, tmpFieldN: string;
  tmpObj: TComponent;

  procedure SetPublished;         // published field
  var
    aPropType: PTypeInfo;
    s: string;
    i: integer;
  begin
    aPropType:=FUndoList[FUndoCurr].propInfo^.propType;
    case aPropType^.Kind of
      tkInteger, tkInt64:
      begin
        if (aPropType^.Name = 'TColor') or
           (aPropType^.Name = 'TGraphicsColor') then
          SetOrdProp(tmpObj, tmpFieldN, StringToColor(ValueStr))
        else if aPropType^.Name = 'TCursor' then
          SetOrdProp(tmpObj, tmpFieldN, StringToCursor(ValueStr))
        else
          SetOrdProp(tmpObj, tmpFieldN, StrToInt(ValueStr));
      end;
      tkChar, tkWChar, tkUChar:
      begin
        if Length(ValueStr) = 1 then
          SetOrdProp(tmpObj, tmpFieldN, Ord(ValueStr[1]))
        else if (ValueStr[1] = '#') then
        begin
          s := Copy(ValueStr, 2, Length(ValueStr) - 1);
          if TryStrToInt(s, i) and (i >= 0) and (i <= High(Byte)) then
            SetOrdProp(tmpObj, tmpFieldN, i);
        end;
      end;
      tkEnumeration:
        SetEnumProp(tmpObj, tmpFieldN, ValueStr);
      tkFloat:
        SetFloatProp(tmpObj, tmpFieldN, StrToFloat(ValueStr));
      tkBool:
        SetOrdProp(tmpObj, tmpFieldN, Integer(StrToBoolOI(ValueStr)));
      tkString, tkLString, tkAString, tkUString, tkWString:
        SetStrProp(tmpObj, tmpFieldN, ValueStr);
      tkSet:
        SetSetProp(tmpObj, tmpFieldN, ValueStr);
      tkVariant:
        SetVariantProp(tmpObj, tmpFieldN, AValue);
      else
        ShowMessage(Format('error: unknown TTypeKind(%d)', [Integer(aPropType^.Kind)]));
    end;
  end;

  procedure SetUnPublished;       // field is not published
  var
    NewParent: TComponent;
  begin
    if tmpObj is TControl then
    begin
      if CompareText(tmpFieldN,'Parent')=0 then  // Special treatment for Parent.
      begin
        if FForm.Name <> ValueStr then           // Find the parent by name.
          NewParent := FForm.FindComponent(ValueStr)
        else
          NewParent := FForm;
        Assert(NewParent is TWinControl, 'TDesigner.ExecuteUndoItem: New Parent "'
                                         + DbgS(NewParent) + '" is not a TWinControl.');
        TControl(tmpObj).Parent := TWinControl(NewParent);
      end;
    end;
  end;

var
  CurTextCompStream: TMemoryStream;
  SaveControlSelection: TControlSelection;
  CompN: TComponentName;
begin
  // Undo Add component
  if (IsActUndo and (FUndoList[FUndoCurr].opType = uopAdd)) or
    (not IsActUndo and (FUndoList[FUndoCurr].opType = uopDelete)) then
  begin
    Selection.BeginUpdate;
    try
      SaveControlSelection := TControlSelection.Create;
      try
        Inc(FUndoLock);
        SaveControlSelection.Assign(Selection);
        Selection.AssignPersistent(FForm.FindComponent(FUndoList[FUndoCurr].compName));
        DeleteSelection;
      finally
        Dec(FUndoLock);
        Selection.Assign(SaveControlSelection);
        SaveControlSelection.Free;
      end;
    finally
      Selection.EndUpdate;
    end;
  end;

  // Undo Delete component
  if (IsActUndo and (FUndoList[FUndoCurr].opType = uopDelete)) or
    (not IsActUndo and (FUndoList[FUndoCurr].opType = uopAdd)) then
  begin
    CurTextCompStream := TMemoryStream.Create;
    try
      Inc(FUndoLock);
      CurTextCompStream.Write(FUndoList[FUndoCurr].obj[1], Length(FUndoList[FUndoCurr].obj));
      CurTextCompStream.Position := 0;
      DoInsertFromStream(CurTextCompStream,
        TWinControl(FForm.FindChildControl(FUndoList[FUndoCurr].parentName)), []);
    finally
      Dec(FUndoLock);
      CurTextCompStream.Free;
    end;
  end;

  // Undo Change properties of component
  if FUndoList[FUndoCurr].opType = uopChange then
  begin
    Inc(FUndoLock);
    try
      tmpFieldN := FUndoList[FUndoCurr].fieldName;
      if tmpFieldN = 'Name' then
      begin
        if IsActUndo then
          CompN := FUndoList[FUndoCurr].newVal
        else
          CompN := FUndoList[FUndoCurr].oldVal;
      end
      else
        CompN := FUndoList[FUndoCurr].compName;

      if FForm.Name <> CompN then
        tmpObj := FForm.FindSubComponent(CompN)
      else
        tmpObj := FForm;

      if IsActUndo then
        AValue := FUndoList[FUndoCurr].oldVal
      else
        AValue := FUndoList[FUndoCurr].newVal;
      if VarIsError(AValue) or VarIsEmpty(AValue) or VarIsNull(AValue) then
        ShowMessage('error: invalid var type');
      ValueStr := VarToStr(AValue);
      //DebugLn(['TDesigner.ExecuteUndoItem: FForm=', FForm.Name, ', CompName=', CompN,
      //  ', FieldName=', tmpFieldN, ', tmpObj=', tmpObj, ', tmpStr=', ValueStr, ', IsActUndo=', IsActUndo]);

      if FUndoList[FUndoCurr].propInfo<>nil then
        SetPublished
      else
        SetUnPublished;
      PropertyEditorHook.Modified(tmpObj);
    finally
      Dec(FUndoLock);
    end;
  end;

  PropertyEditorHook.RefreshPropertyValues;
end;

procedure TDesigner.DoShowAnchorEditor;
begin
  if Assigned(FOnShowAnchorEditor) then
    FOnShowAnchorEditor(Self);
end;

procedure TDesigner.DoShowTabOrderEditor;
begin
  if Assigned(FOnShowTabOrderEditor) then
    FOnShowTabOrderEditor(Self);
end;

procedure TDesigner.DoShowObjectInspector;
begin
  if Assigned(FOnShowObjectInspector) then
    OnShowObjectInspector(Self);
end;

procedure TDesigner.DoChangeZOrder(TheAction: Integer);
var
  Control: TControl;
  Parent: TWinControl;
  OI: TObjectInspectorDlg;
begin
  if Selection.Count <> 1 then Exit;
  if not Selection[0].IsTControl then Exit;

  Control := TControl(Selection[0].Persistent);
  Parent := Control.Parent;
  if (Parent = nil) and (TheAction in [2, 3]) then Exit;

  case TheAction of
   0: Control.BringToFront;
   1: Control.SendToBack;
   2: Parent.SetControlIndex(Control, Parent.GetControlIndex(Control) + 1);
   3: Parent.SetControlIndex(Control, Parent.GetControlIndex(Control) - 1);
  end;

  // Ensure the order of controls in the OI now reflects the new ZOrder
  // Unfortunately, if there is no parent, this code doesn't achieve a refresh
  // of ComponentTree in the OI
  if assigned(Parent) then
  begin
    Parent.ReAlign;
    SelectOnlyThisComponent(Parent);
  end;
  SelectOnlyThisComponent(Control);

  Modified;
  OI := FormEditingHook.GetCurrentObjectInspector;
  if Assigned(OI) then
    OI.ComponentTree.BuildComponentNodes(True);
end;

procedure TDesigner.NotifyComponentAdded(AComponent: TComponent);
var
  i: Integer;
  SubContrl: TControl;
begin
  try
    if AComponent.Name='' then
      AComponent.Name:=UniqueName(AComponent.ClassName);
    // Iterating Controls is needed at least for Side1 and Side2 of TPairSplitter.
    if AComponent is TWinControl then
      for i:=0 to TWinControl(AComponent).ControlCount-1 do
      begin
        SubContrl:=TWinControl(AComponent).Controls[i];
        if (SubContrl.Owner<>AComponent) and (SubContrl.Name='') then
          SubContrl.Name:=UniqueName(SubContrl.ClassName);
      end;
    GlobalDesignHook.PersistentAdded(AComponent,false);
  except
    on E: Exception do
      IDEMessageDialog('Error:',E.Message,mtError,[mbOk]);
  end;
end;

procedure TDesigner.SelectOnlyThisComponent(AComponent: TComponent);
begin
  Selection.AssignPersistent(AComponent);
end;

function TDesigner.CopySelection: boolean;
begin
  Result := DoCopySelectionToClipboard;
end;

function TDesigner.CutSelection: boolean;
begin
  Result := DoCopySelectionToClipboard and DoDeleteSelectedPersistents;
end;

procedure TDesigner.CutSelectionAsync(Data: PtrInt);
begin
  CutSelection;
end;

function TDesigner.CanCopy: Boolean;
begin
  Result := (Selection.Count > 0) and
            (Selection.SelectionForm = Form) and
            Selection.OkToCopy and
            not Selection.OnlyInvisiblePersistentsSelected and
            not Selection.LookupRootSelected;
end;

function TDesigner.CanPaste: Boolean;
begin
  Result:= Assigned(Form) and
           Assigned(FLookupRoot) and
           ClipBoard.HasFormat(CF_Text) and
           not (csDestroying in FLookupRoot.ComponentState);
end;

function TDesigner.PasteSelection(
  PasteFlags: TComponentPasteSelectionFlags): boolean;
begin
  Result:=DoPasteSelectionFromClipboard(PasteFlags);
end;

function TDesigner.ClearSelection: boolean;
begin
  Selection.Clear;
  Result:=Selection.Count=0;
end;

function TDesigner.DeleteSelection: boolean;
begin
  Result:=DoDeleteSelectedPersistents;
end;

function TDesigner.InvokeComponentEditor(AComponent: TComponent): boolean;
begin
  Result:=false;
  DebugLn('TDesigner.InvokeComponentEditor A ',AComponent.Name,':',AComponent.ClassName);
  PopupMenuComponentEditor:=TheFormEditor.GetComponentEditor(AComponent);
  if PopupMenuComponentEditor=nil then begin
    DebugLn('TDesigner.InvokeComponentEditor WARNING: no component editor found for ',
            AComponent.Name,':',AComponent.ClassName);
    exit;
  end;
  DebugLn('TDesigner.InvokeComponentEditor B ',PopupMenuComponentEditor.ClassName);
  try
    PopupMenuComponentEditor.Edit;
    Result:=true;
  except
    on E: Exception do begin
      DebugLn('TDesigner.InvokeComponentEditor ERROR: ',E.Message);
      IDEMessageDialog(Format(lisErrorIn, [PopupMenuComponentEditor.ClassName]),
        Format(lisTheComponentEditorOfClassHasCreatedTheError,
               [PopupMenuComponentEditor.ClassName, LineEnding, E.Message]),
        mtError,[mbOk]);
    end;
  end;
end;

function TDesigner.ChangeClass: boolean;
begin
  if (Selection.Count=1) and (not Selection.LookupRootSelected) then
    Result:=ShowChangeClassDialog(Self,Selection[0].Persistent)=mrOK
  else
    Result:=false;
end;

procedure TDesigner.DoProcessCommand(Sender: TObject; var Command: word;
  var Handled: boolean);
begin
  if Assigned(OnProcessCommand) and (Command <> ecNone)
  then begin
    OnProcessCommand(Self,Command,Handled);
    Handled := Handled or (Command = ecNone);
  end;

  if Handled then Exit;

  case Command of
    ecDesignerSelectParent : SelectParentOfSelection;
    ecDesignerCopy         : CopySelection;
    ecDesignerCut          : CutSelection;
    ecDesignerPaste        : PasteSelection([cpsfFindUniquePositions]);
    ecDesignerMoveToFront  : DoChangeZOrder(0);
    ecDesignerMoveToBack   : DoChangeZOrder(1);
    ecDesignerForwardOne   : DoChangeZOrder(2);
    ecDesignerBackOne      : DoChangeZOrder(3);
    ecDesignerToggleNonVisComps: ShowNonVisualComponents:=not ShowNonVisualComponents;
  else
    Exit;
  end;
  
  Handled := True;
end;

function TDesigner.CanUndo: Boolean;
begin
  Result := Assigned(Form) and (FUndoCurr > Low(FUndoList)) and
    (FUndoList[FUndoCurr - 1].isValid) and (FUndoList[FUndoCurr - 1].opType <> uopNone);
end;

function TDesigner.CanRedo: Boolean;
begin
  Result := Assigned(Form) and (FUndoCurr <= High(FUndoList)) and
    (FUndoList[FUndoCurr].isValid) and (FUndoList[FUndoCurr].opType <> uopNone);
end;

function TDesigner.Undo: Boolean;
begin
  Result := DoUndo;
end;

function TDesigner.Redo: Boolean;
begin
  Result := DoRedo;
end;

function TDesigner.AddUndoAction(const aPersistent: TPersistent;
  aOpType: TUndoOpType; StartNewGroup: boolean; aFieldName: string;
  const aOldVal, aNewVal: Variant): boolean;

  procedure ShiftUndoList;
  var
    i: integer;
  begin
    for i := Low(FUndoList) + 1 to High(FUndoList) do
      FUndoList[i - 1] := FUndoList[i];
    ClearUndoItem(High(FUndoList));
    Dec(FUndoCurr);
  end;

var
  i: integer;
  SaveControlSelection: TControlSelection;
  AStream: TStringStream;
  APropInfo: PPropInfo;
  Comp: TComponent;
begin
  Result := (FUndoLock = 0);
  if not Result then Exit;

  APropInfo := GetPropInfo(aPersistent, aFieldName);

  Inc(FUndoLock);
  try
    if FUndoCurr > High(FUndoList) then
      ShiftUndoList;

    // clear Redo items
    i := FUndoCurr;
    while (i <= High(FUndoList)) do
    begin
      ClearUndoItem(i);
      Inc(i);
    end;

    if StartNewGroup then
      SetNextUndoGroupId;

    if (aOpType in [uopAdd, uopDelete]) and (FForm <> aPersistent) then
    begin
      Selection.BeginUpdate;
      try
        SaveControlSelection := TControlSelection.Create;
        try
          SaveControlSelection.Assign(Selection);
          AStream := TStringStream.Create('');
          try
            Selection.AssignPersistent(aPersistent);
            CopySelectionToStream(AStream);
            FUndoList[FUndoCurr].obj := AStream.DataString;
          finally
            AStream.Free;
          end;
        finally
          Selection.Assign(SaveControlSelection);
          SaveControlSelection.Free;
        end;
      finally
        Selection.EndUpdate;
      end;
    end;

    // add to FUndoList
    with FUndoList[FUndoCurr] do
    begin
      oldVal := aOldVal;
      newVal := aNewVal;
      fieldName := aFieldName;
      compName := '';
      parentName := '';
      if aPersistent is TComponent then begin
        Comp := TComponent(aPersistent);
        compName := Comp.Name;
        // Add owner to the name of a subcomponent.
        if Assigned(Comp.Owner) and (Comp.Owner <> LookupRoot) then
          compName := Comp.Owner.Name + '.' + compName;
        if Comp.HasParent then
          parentName := Comp.GetParentComponent.Name;
      end;
      opType := aOpType;
      isValid := true;
      GroupId := FUndoGroupId;
      propInfo := APropInfo;
    end;
    Inc(FUndoCurr);
  finally
    Dec(FUndoLock);
  end;
end;

function TDesigner.IsUndoLocked: boolean;
begin
  Result := FUndoLock > 0;
end;

procedure TDesigner.ClearUndoItem(AIndex: Integer);
begin
  if (AIndex < 0) or (AIndex >= Length(FUndoList)) then Exit;
  with FUndoList[AIndex] do
  begin
    obj := '';
    fieldName := '';
    VarClear(oldVal);
    VarClear(newVal);
    compName := '';
    parentName := '';
    opType := uopNone;
    isValid := false;
    GroupId := 0;
  end;
end;

function TDesigner.NonVisualComponentLeftTop(AComponent: TComponent): TPoint;
var
  ParentForm: TPoint;
begin
  Result.X := LeftFromDesignInfo(AComponent.DesignInfo);
  Result.Y := TopFromDesignInfo(AComponent.DesignInfo);
  // convert to lookuproot coords
  if (AComponent.Owner <> FLookupRoot) then
  begin
    ParentForm:=GetParentFormRelativeClientOrigin(AComponent.Owner);
    inc(Result.X,ParentForm.X);
    inc(Result.Y,ParentForm.Y);
  end;
end;

procedure TDesigner.InvalidateWithParent(AComponent: TComponent);
begin
  {$IFDEF VerboseDesigner}
  DebugLn('TDesigner.INVALIDATEWITHPARENT ',AComponent.Name,':',AComponent.ClassName);
  {$ENDIF}
  if AComponent is TControl then begin
    if TControl(AComponent).Parent<>nil then
      TControl(AComponent).Parent.Invalidate
    else
      TControl(AComponent).Invalidate;
  end else begin
    FForm.Invalidate;
  end;
end;

procedure TDesigner.SetDefaultFormBounds(const AValue: TRect);
begin
  FDefaultFormBounds:=AValue;
end;

procedure TDesigner.SetGridColor(const AValue: TColor);
begin
  if GridColor=AValue then exit;
  EnvironmentOptions.GridColor:=AValue;
  Form.Invalidate;
end;

procedure TDesigner.SetShowBorderSpacing(const AValue: boolean);
begin
  if ShowBorderSpacing=AValue then exit;
  EnvironmentOptions.ShowBorderSpacing:=AValue;
  Form.Invalidate;
end;

procedure TDesigner.SetShowComponentCaptions(const AValue: boolean);
begin
  if AValue=ShowComponentCaptions then exit;
  if AValue then
    Include(FFlags, dfShowComponentCaptions)
  else
    Exclude(FFlags, dfShowComponentCaptions);
  Form.Invalidate;
end;

function TDesigner.PaintControl(Sender: TControl; TheMessage: TLMPaint): Boolean;
var
  OldDuringPaintControl: boolean;
begin
  Result:=true;

  {$IFDEF VerboseDsgnPaintMsg}
  writeln('***  TDesigner.PaintControl A ',Sender.Name,':',Sender.ClassName,
          ' DC=',DbgS(TheMessage.DC));
  {$ENDIF}
  // Set flag
  OldDuringPaintControl:=dfDuringPaintControl in FFlags;
  Include(FFlags,dfDuringPaintControl);

  // send the Paint message to the control, so that it paints itself
  //writeln('TDesigner.PaintControl B ',Sender.Name);
  Sender.Dispatch(TheMessage);
  //writeln('TDesigner.PaintControl C ',Sender.Name,' DC=',DbgS(TheMessage.DC));

  // paint the Designer stuff
  if TheMessage.DC <> 0 then begin
    Include(FFlags,dfNeedPainting);

    if Sender is TControl then
      DDC.SetDC(Form, TControl(Sender), TheMessage.DC)
    else
    if Sender <> nil then
      DDC.SetDC(Form, Sender.Parent, TheMessage.DC)
    else
      DDC.SetDC(Form, nil, TheMessage.DC);
    {$IFDEF VerboseDesignerDraw}
    writeln('TDesigner.PaintControl D ',dbgsname(Sender),
      ' DC=',DbgS(DDC.DC,8),
     {' FormOrigin=',DDC.FormOrigin.X,',',DDC.FormOrigin.Y,}
      ' DCOrigin=',DDC.DCOrigin.X,',',DDC.DCOrigin.Y,
      ' FormClientOrigin=',DDC.FormClientOrigin.X,',',DDC.FormClientOrigin.Y
      );
    {$ENDIF}
    if LastPaintSender=Sender then begin
      //writeln('NOTE: TDesigner.PaintControl E control painted twice: ',
      //  Sender.Name,':',Sender.ClassName,' DC=',DbgS(TheMessage.DC));
      //RaiseGDBException('');
    end;
    LastPaintSender:=Sender;

    if IsDesignerDC(Form.Handle, TheMessage.DC) then
      DoPaintDesignerItems
    else
    begin
      // client grid
      if (Sender is TWinControl) and (csAcceptsControls in Sender.ControlStyle) then
        PaintClientGrid(TWinControl(Sender),DDC);
    end;
   
    // clean up
    DDC.Clear;
  end;
  //writeln('TDesigner.PaintControl END ',Sender.Name);

  if not OldDuringPaintControl then
    Exclude(FFlags,dfDuringPaintControl);
end;

function TDesigner.HandleSetCursor(var TheMessage: TLMessage): boolean;
begin
  Result := Lo(DWord(TheMessage.LParam)) = HTCLIENT;
  if Result then
  begin
    SetTempCursor(Form, LastFormCursor);
    TheMessage.Result := 1;
  end;
end;

procedure TDesigner.HandlePopupMenu(Sender: TControl; var Message: TLMContextMenu);
var
  PopupPos: TPoint;
begin
  if Message.XPos = -1 then
  begin
    PopupMenuComponentEditor := GetComponentEditorForSelection;
    BuildPopupMenu;
    with Selection do
      PopupPos := Point(Left + Width, Top);
    with Form.ClientToScreen(PopupPos) do
      FDesignerPopupMenu.Popup(X, Y);
  end;
  Message.Result := 1;
end;

procedure TDesigner.GetMouseMsgShift(TheMessage: TLMMouse; out
  Shift: TShiftState; out Button: TMouseButton);
begin
  Shift := [];
  Button := mbLeft;
  if (TheMessage.Keys and MK_Shift) = MK_Shift then
    Include(Shift, ssShift);
  if (TheMessage.Keys and MK_Control) = MK_Control then
    Include(Shift, ssCtrl);

  if GetKeyState(VK_MENU) < 0 then Include(Shift, ssAlt);
  if (GetKeyState(VK_LWIN) < 0) or (GetKeyState(VK_RWIN) < 0) then Include(Shift, ssMeta);

  case TheMessage.Msg of
  LM_LBUTTONUP,LM_LBUTTONDBLCLK,LM_LBUTTONTRIPLECLK,LM_LBUTTONQUADCLK:
    begin
      Include(Shift, ssLeft);
      Button := mbLeft;
    end;
  LM_MBUTTONUP,LM_MBUTTONDBLCLK,LM_MBUTTONTRIPLECLK,LM_MBUTTONQUADCLK:
    begin
      Include(Shift, ssMiddle);
      Button := mbMiddle;
    end;
  LM_RBUTTONUP,LM_RBUTTONDBLCLK,LM_RBUTTONTRIPLECLK,LM_RBUTTONQUADCLK:
    begin
      Include(Shift, ssRight);
      Button := mbRight;
    end;
  else
    if (TheMessage.Keys and MK_MButton) <> 0 then
    begin
      Include(Shift, ssMiddle);
      Button := mbMiddle;
    end;
    if (TheMessage.Keys and MK_RButton) <> 0 then
    begin
      Include(Shift, ssRight);
      Button := mbRight;
    end;
    if (TheMessage.Keys and MK_LButton) <> 0 then
    begin
      Include(Shift, ssLeft);
      Button := mbLeft;
    end;
    if (TheMessage.Keys and MK_XBUTTON1) <> 0 then
    begin
      Include(Shift, ssExtra1);
      Button := mbExtra1;
    end;
    if (TheMessage.Keys and MK_XBUTTON2) <> 0 then
    begin
      Include(Shift, ssExtra2);
      Button := mbExtra2;
    end;
  end;

  case TheMessage.Msg of
  LM_LBUTTONDBLCLK,LM_MBUTTONDBLCLK,LM_RBUTTONDBLCLK,LM_XBUTTONDBLCLK:
    Include(Shift, ssDouble);
  LM_LBUTTONTRIPLECLK,LM_MBUTTONTRIPLECLK,LM_RBUTTONTRIPLECLK,LM_XBUTTONTRIPLECLK:
    Include(Shift, ssTriple);
  LM_LBUTTONQUADCLK,LM_MBUTTONQUADCLK,LM_RBUTTONQUADCLK,LM_XBUTTONQUADCLK:
    Include(Shift, ssQuad);
  end;
end;

function TDesigner.GetDesignControl(AControl: TControl): TControl;
// checks if AControl is designable.
// if not check Owner.
// AControl can be a TNonControlDesignerForm
var
  OwnerControl: TControl;
  AComponent: TComponent;
begin
  Result:=AControl;
  if (Result=nil) or (Result=LookupRoot) or (Result.Owner=LookupRoot) then exit;
  if Result=Form then exit;
  if (Result.Owner is TControl) then begin
    OwnerControl:=TControl(Result.Owner);
    if (not (csOwnedChildrenNotSelectable in OwnerControl.ControlStyle)) then
      exit;
    Result:=GetDesignControl(OwnerControl);
  end else begin
    AComponent:=GetDesignedComponent(AControl);
    if AComponent is TControl then
      Result:=TControl(AComponent)
    else
      Result:=nil;
  end;
end;

function TDesigner.SizeControl(Sender: TControl; TheMessage: TLMSize): Boolean;
begin
  Result := True;
  Sender.Dispatch(TheMessage);
  if Selection.SelectionForm = Form then
  begin
    Selection.CheckForLCLChanges(True);
  end;
end;

function TDesigner.MoveControl(Sender: TControl; TheMessage: TLMMove): Boolean;
begin
  Result := True;
  Sender.Dispatch(TheMessage);
  //debugln('***  TDesigner.MoveControl A ',Sender.Name,':',Sender.ClassName,' ',Selection.SelectionForm=Form,' ',not Selection.IsResizing,' ',Selection.IsSelected(Sender));
  if Selection.SelectionForm = Form then
  begin
    if not Selection.CheckForLCLChanges(True) and (Sender = Form) and
       Selection.LookupRootSelected then
    begin
      // the selected form was moved (nothing else has changed)
      // Selection does not need an update, but properties like
      // Form.Left/Top have to be updated in the OI
      OnPropertiesChanged(Self);
    end;
  end;
end;

procedure TDesigner.MouseDownOnControl(Sender: TControl; var TheMessage: TLMMouse);
var
  CompIndex:integer;
  SelectedCompClass: TRegisteredComponent;
  ParentForm: TCustomForm;
  Shift: TShiftState;
  DesignSender: TControl;
  Button: TMouseButton;
  Handled: Boolean;
  MouseDownControl: TControl;
  p: types.TPoint;
begin
  FHintTimer.Enabled := False;
  FHintWindow.Visible := False;

  Exclude(FFLags, dfHasSized);
  SetCaptureControl(nil);
  DesignSender := GetDesignControl(Sender);
  ParentForm := GetDesignerForm(DesignSender);
  //DebugLn(['TDesigner.MouseDownOnControl DesignSender=',dbgsName(DesignSender),' ParentForm=',dbgsName(ParentForm)]);
  if (ParentForm = nil) then exit;
  
  MouseDownPos := GetFormRelativeMousePosition(Form);
  LastMouseMovePos := MouseDownPos;
  MouseDownSender := nil;
  MouseDownComponent := ComponentAtPos(MouseDownPos.X, MouseDownPos.Y, True, True);
  if (MouseDownComponent = nil) then exit;

  if ComponentIsIcon(MouseDownComponent) then
  begin
    if Assigned(IDEComponentsMaster) then
      if not IDEComponentsMaster.DrawNonVisualComponents(FLookupRoot) then
      begin
        MouseDownComponent := nil;
        Exit;
      end;
    MoveNonVisualComponentIntoForm(MouseDownComponent);
  end;

  MouseDownSender := DesignSender;

  GetMouseMsgShift(TheMessage,Shift,Button);
  MouseDownShift:=Shift;

  {$IFDEF VerboseDesigner}
  DebugLn('************************************************************');
  DbgOut('MouseDownOnControl');
  DbgOut(' Sender=',dbgsName(Sender),' DesignSender=',dbgsName(DesignSender));
  //write(' Msg=',TheMessage.Pos.X,',',TheMessage.Pos.Y);
  //write(' Mouse=',MouseDownPos.X,',',MouseDownPos.Y);
  //writeln('');

  if (TheMessage.Keys and MK_Shift) = MK_Shift then
    DbgOut(' Shift down')
  else
    DbgOut(' No Shift down');

  if (TheMessage.Keys and MK_Control) = MK_Control then
    DebugLn(', CTRL down')
  else
    DebugLn(', No CTRL down');
  {$ENDIF}

  if MouseDownComponent is TControl then
  begin
    MouseDownControl:=TControl(MouseDownComponent);
    p:=MouseDownControl.ScreenToClient(Form.ClientToScreen(MouseDownPos));
    if (csDesignInteractive in MouseDownControl.ControlStyle)
    or (MouseDownControl.Perform(CM_DESIGNHITTEST, TheMessage.Keys, Longint(SmallPoint(p.X, p.Y))) > 0) then
    begin
      TControlAccess(MouseDownComponent).MouseDown(Button, Shift, p.X, p.Y);
      Exit;
    end;
  end
  else
    p:=Point(0,0);

  if Mediator<>nil then begin
    Handled:=false;
    Mediator.MouseDown(Button,Shift,MouseDownPos,Handled);
    if Handled then exit;
  end;

  SelectedCompClass := GetSelectedComponentClass;

  if Button=mbLeft then begin
    // left button
    // -> check if a grabber was activated
    Selection.ActiveGrabber:=Selection.GrabberAtPos(MouseDownPos.X, MouseDownPos.Y);
    SetCaptureControl(ParentForm);

    if SelectedCompClass = nil then begin
      // selection mode
      if Selection.ActiveGrabber=nil then begin
        // no grabber resizing

        CompIndex:=Selection.IndexOf(MouseDownComponent);
        if ssCtrl in Shift then begin
          // child selection
        end
        else if (ssShift in Shift) then begin
          // shift key pressed (multiselection)

          if CompIndex<0 then begin
            // not selected
            // add component to selection
            if (Selection.SelectionForm<>nil)
            and (Selection.SelectionForm<>Form)
            then begin
              IDEMessageDialog(lisInvalidMultiselection,
                fdInvalidMultiselectionText,
                mtInformation,[mbOk]);
            end else begin
              Selection.Add(MouseDownComponent);
            end;
          end else begin
            // remove from multiselection
            Selection.Delete(CompIndex);
          end;
        end else begin
          // no shift key (single selection or keeping multiselection)

          if (CompIndex<0) then begin
            // select only this component
            Selection.AssignPersistent(MouseDownComponent);
          end else
            // sync with the interface
            Selection.UpdateBounds;
        end;
      end else begin
        // mouse down on grabber -> begin sizing
        // grabber is already activated
        // the sizing is handled in mousemove and mouseup
      end;
    end else begin
      // add component mode -> handled in mousemove and mouseup
      // but check if we pressed mouse on the form which is not selected
      if (Selection.SelectionForm <> Form) then
        Selection.AssignPersistent(MouseDownComponent);
    end;
  end else begin
    // not left button
    Selection.ActiveGrabber := nil;
    if (Button = mbRight) and EnvironmentOptions.RightClickSelects and
       (Selection.SelectionForm <> Form) then
      Selection.AssignPersistent(MouseDownComponent);
  end;

  if PropertyEditorHook<>nil then
    PropertyEditorHook.DesignerMouseDown(Sender, Button, Shift, p.X, p.Y);

  if not Selection.OnlyVisualComponentsSelected and ShowComponentCaptions then
    Form.Invalidate;

  {$IFDEF VerboseDesigner}
  DebugLn('[TDesigner.MouseDownOnControl] END');
  {$ENDIF}
end;

procedure TDesigner.MouseUpOnControl(Sender : TControl; var TheMessage:TLMMouse);
var
  Button: TMouseButton;
  Shift: TShiftState;
  SelectedCompClass: TRegisteredComponent;

  procedure DoAddComponent;
  var
    NewParent: TComponent;
    NewComponentClass: TComponentClass;
    NewLeft, NewTop, NewWidth, NewHeight: Integer;
    ParentClientOrigin: TPoint;
  begin
    if MouseDownComponent=nil then exit;
    NewComponentClass := SelectedCompClass.GetCreationClass;
    //debugln(['AddComponent NewComponentClass=',DbgSName(NewComponentClass)]);

    // find a parent for the new component
    NewParent:=nil;
    if not PropertyEditorHook.AddClicked(Self,MouseDownComponent,Button,Shift,
      MouseUpPos.X,MouseUpPos.Y,NewComponentClass,NewParent) then exit;

    AddComponentCheckParent(NewParent, MouseDownComponent,
      WinControlAtPos(MouseUpPos.X, MouseUpPos.Y, true, true), NewComponentClass);
    if not Assigned(NewParent) then exit;

    // calculate initial bounds
    NewLeft:=Min(MouseDownPos.X,MouseUpPos.X);
    NewTop:=Min(MouseDownPos.Y,MouseUpPos.Y);
    if (Mediator<>nil) then begin
      ParentClientOrigin:=Mediator.GetComponentOriginOnForm(NewParent);
      DebugLn(['AddComponent ParentClientOrigin=',dbgs(ParentClientOrigin)]);
      // adjust left,top to parent origin
      dec(NewLeft,ParentClientOrigin.X);
      dec(NewTop,ParentClientOrigin.Y);
    end else if NewComponentClass.InheritsFrom(TControl) then
    begin
      ParentClientOrigin:=GetParentFormRelativeClientOrigin(NewParent);
      // adjust left,top to parent origin
      dec(NewLeft,ParentClientOrigin.X);
      dec(NewTop,ParentClientOrigin.Y);
    end;
    NewWidth:=Abs(MouseUpPos.X-MouseDownPos.X);
    NewHeight:=Abs(MouseUpPos.Y-MouseDownPos.Y);
    if Abs(NewWidth+NewHeight)<7 then begin
      // this very small component is probably only a wag, take default size
      NewWidth:=0;
      NewHeight:=0;
    end;
    //DebugLn(['AddComponent ',dbgsName(NewComponentClass)]);
    if NewComponentClass = nil then exit;
    AddComponent(SelectedCompClass,NewComponentClass,NewParent,NewLeft,NewTop,NewWidth,NewHeight);
  end;

  procedure RubberbandSelect;
  var
    MaxParentComponent: TComponent;
    SelectionChanged, NewRubberSelection: boolean;
  begin
    if (ssShift in Shift)
    and (Selection.SelectionForm<>nil)
    and (Selection.SelectionForm<>Form)
    then begin
      IDEMessageDialog(lisInvalidMultiselection,
        fdInvalidMultiselectionText,
        mtInformation,[mbOk]);
      exit;
    end;

    // check if start new selection or add/remove:
    NewRubberSelection:= (not (ssShift in Shift)) or (Selection.SelectionForm<>Form);
    // update non visual components
    MoveNonVisualComponentsIntoForm;
    // if user press the Control key, then component candidates are only
    // children of the control, where the mouse started
    if (ssCtrl in shift) then begin
      if MouseDownComponent=Form then
        MaxParentComponent:=FLookupRoot
      else
        MaxParentComponent:=MouseDownComponent;
    end else
      MaxParentComponent:=FLookupRoot;
    SelectionChanged:=false;
    Selection.SelectWithRubberBand(
      FLookupRoot,Mediator,NewRubberSelection,ssShift in Shift,
      SelectionChanged,MaxParentComponent);
    if Selection.Count=0 then begin
      Selection.Add(FLookupRoot);
      SelectionChanged:=true;
    end;
    Selection.RubberbandActive:=false;
    {$IFDEF VerboseDesigner}
    DebugLn('RubberbandSelect ',DbgS(ControlSelection.Grabbers[0]));
    {$ENDIF}
    Form.Invalidate;
  end;

var
  SenderParentForm: TCustomForm;
  SelectedPersistent: TSelectedControl;
  DesignSender, MouseDownControl: TControl;
  RubberBandWasActive, Handled: Boolean;
  p, PopupPos: TPoint;
  i, j: Integer;
begin
  FHintTimer.Enabled := False;
  FHintWindow.Visible := False;

  SetCaptureControl(nil);

  // check if the message is for the designed form and there was a mouse down before
  DesignSender:=GetDesignControl(Sender);
  SenderParentForm:=GetDesignerForm(DesignSender);
  //DebugLn(['TDesigner.MouseUpOnControl DesignSender=',dbgsName(DesignSender),' SenderParentForm=',dbgsName(SenderParentForm),' ',TheMessage.XPos,',',TheMessage.YPos]);
  if (MouseDownComponent=nil) or (SenderParentForm=nil) or (SenderParentForm<>Form)
  or ( (Selection.SelectionForm<>nil) and (Selection.SelectionForm<>Form) ) then
  begin
    MouseDownComponent:=nil;
    MouseDownSender:=nil;
    exit;
  end;

  Selection.ActiveGrabber:=nil;
  RubberBandWasActive:=Selection.RubberBandActive;
  SelectedCompClass:=GetSelectedComponentClass;

  GetMouseMsgShift(TheMessage,Shift,Button);
  MouseUpPos:=GetFormRelativeMousePosition(Form);

  {$IFDEF VerboseDesigner}
  DebugLn('************************************************************');
  DbgOut('MouseUpOnControl');
  DbgOut(' Sender=',dbgsName(Sender),' DesignSender=',dbgsName(DesignSender));
  //write(' Msg=',TheMessage.Pos.X,',',TheMessage.Pos.Y);
  DebugLn('');
  {$ENDIF}

  if MouseDownComponent is TControl then
  begin
    MouseDownControl:=TControl(MouseDownComponent);
    p:=MouseDownControl.ScreenToClient(Form.ClientToScreen(MouseUpPos));
    if (csDesignInteractive in MouseDownControl.ControlStyle)
    or (MouseDownControl.Perform(CM_DESIGNHITTEST, TheMessage.Keys, Longint(SmallPoint(p.X, p.Y))) > 0) then
    begin
      TControlAccess(MouseDownComponent).MouseUp(Button, Shift, p.X, p.Y);
      Exit;
    end;
  end
  else
    p:=Point(0,0);

  if Mediator<>nil then
  begin
    Handled:=false;
    Mediator.MouseUp(Button,Shift,MouseUpPos,Handled);
    if Handled then exit;
  end;

  Selection.BeginUpdate;
  if Button=mbLeft then
  begin
    if SelectedCompClass = nil then
    begin
      if (FUndoState = ucsSaveChange) then
      begin
        // update undo list stored component bounds (Left, Top, Width, Height)
        // see TControlSelection.EndResizing
        // the list of all TComponent, Left,Top,Width,Height
        // Note: not every component has all four properties.
        j := FUndoCurr - 1;
        i := Selection.Count-1;
        while i>=0 do
        begin
          SelectedPersistent:=Selection.Items[i];
          if SelectedPersistent.IsTComponent then
          begin
            while (j>=0) do
            begin
              if (FUndoList[j].compName <> TComponent(SelectedPersistent.Persistent).Name)
              then begin
                // this is not a list of bounds -> stop
                i:=0;
                break;
              end;
              if (FUndoList[j].fieldName = 'Width') then
                FUndoList[j].newVal := SelectedPersistent.Width
              else if (FUndoList[j].fieldName = 'Height') then
                FUndoList[j].newVal := SelectedPersistent.Height
              else if (FUndoList[j].fieldName = 'Left') then
                FUndoList[j].newVal := SelectedPersistent.Left
              else if (FUndoList[j].fieldName = 'Top') then
                FUndoList[j].newVal := SelectedPersistent.Top
              else begin
                // this is not a list of bounds -> stop
                i:=0;
                break;
              end;
              dec(j);
            end;
          end;
          dec(i);
        end;
      end;
      FUndoState := ucsNone;

      // layout mode (selection, moving and resizing)
      if not (dfHasSized in FFlags) then
      begin
        // new selection
        if RubberBandWasActive then
          RubberbandSelect     // rubberband selection
        else if not (ssShift in Shift) then
        begin          // point selection, select only the mouse down component
          Selection.AssignPersistent(MouseDownComponent);
          if (ssDouble in MouseDownShift) and (Selection.SelectionForm = Form) then
          begin        // Double Click -> invoke 'Edit' of the component editor
            PopupMenuComponentEditor := GetComponentEditorForSelection;
            Assert(Assigned(PopupMenuComponentEditor),
                  'TDesigner.MouseUpOnControl: no component editor found for '
                  +MouseDownComponent.Name+':'+MouseDownComponent.ClassName);
            PopupMenuComponentEditor.Edit;
          end;
        end;
      end
      else
        Selection.UpdateBounds;
    end else
      DoAddComponent;  // create new a component on the form
  end
  else if Button=mbRight then
  begin
    // right click -> popup menu
    Selection.RubberbandActive := False;
    Selection.EndUpdate;
    if EnvironmentOptions.RightClickSelects
    and (not Selection.IsSelected(MouseDownComponent))
    and (Shift - [ssRight] = []) then    // select only the mouse down component
      Selection.AssignPersistent(MouseDownComponent);
    PopupMenuComponentEditor := GetComponentEditorForSelection;
    BuildPopupMenu;
    PopupPos := Form.ClientToScreen(MouseUpPos);
    FDesignerPopupMenu.Popup(PopupPos.X, PopupPos.Y);
    Selection.BeginUpdate;
  end;
  Selection.RubberbandActive := False;
  LastMouseMovePos.X:=-1;
  if (not Selection.OnlyVisualComponentsSelected and ShowComponentCaptions)
  or (dfHasSized in FFlags) then
    Form.Invalidate;
  Exclude(FFlags,dfHasSized);
  MouseDownComponent:=nil;
  MouseDownSender:=nil;
  if PropertyEditorHook<>nil then
    PropertyEditorHook.DesignerMouseUp(Sender, Button, Shift, p.X, p.Y);

  Selection.EndUpdate;

  {$IFDEF VerboseDesigner}
  DebugLn('[TDesigner.MouseUpOnControl] END');
  {$ENDIF}
end;

procedure TDesigner.MouseMoveOnControl(Sender: TControl;
  var TheMessage: TLMMouse);
var
  Button: TMouseButton;
  Shift : TShiftState;
  SenderParentForm:TCustomForm;
  OldMouseMovePos: TPoint;
  Grabber: TGrabber;
  ACursor: TCursor;
  SelectedCompClass: TRegisteredComponent;
  CurSnappedMousePos, OldSnappedMousePos: TPoint;
  DesignSender: TControl;
  Handled: Boolean;
  MouseMoveComponent: TComponent;
  MouseMoveControl: TControl;
  p: types.TPoint;
begin
  GetMouseMsgShift(TheMessage, Shift, Button);

  if [dfShowEditorHints] * FFlags <> [] then
  begin
    FHintTimer.Enabled := False;
    // hide hint
    FHintTimer.Enabled := Shift * [ssLeft, ssRight, ssMiddle] = [];
    if not (dfHasSized in FFlags) then
      FHintWindow.Visible := False;
  end;

  DesignSender := GetDesignControl(Sender);
  //DebugLn('TDesigner.MouseMoveOnControl Sender=',dbgsName(Sender),' ',dbgsName(DesignSender));
  SenderParentForm := GetDesignerForm(DesignSender);
  if (SenderParentForm = nil) or (SenderParentForm <> Form) then Exit;

  OldMouseMovePos := LastMouseMovePos;
  LastMouseMovePos := GetFormRelativeMousePosition(Form);
  if (OldMouseMovePos.X = LastMouseMovePos.X) and (OldMouseMovePos.Y = LastMouseMovePos.Y) then
    Exit;

  MouseMoveComponent := MouseDownComponent;
  if MouseMoveComponent = nil then
    MouseMoveComponent := ComponentAtPos(LastMouseMovePos.X, LastMouseMovePos.Y, True, True);
  if MouseMoveComponent is TControl then
  begin
    MouseMoveControl:=TControl(MouseMoveComponent);
    p:=MouseMoveControl.ScreenToClient(Form.ClientToScreen(LastMouseMovePos));
    if (csDesignInteractive in MouseMoveControl.ControlStyle)
    or (MouseMoveControl.Perform(CM_DESIGNHITTEST, TheMessage.Keys, Longint(SmallPoint(p.X, p.Y))) > 0) then
    begin
      TControlAccess(MouseMoveComponent).MouseMove(Shift, p.X, p.Y);
      Exit;
    end;
  end;

  if Mediator <> nil then
  begin
    Handled := False;
    Mediator.MouseMove(Shift, LastMouseMovePos, Handled);
    if Handled then Exit;
  end;

  if Selection.SelectionForm = Form then
    Grabber := Selection.GrabberAtPos(LastMouseMovePos.X, LastMouseMovePos.Y)
  else
    Grabber := nil;

  if MouseDownComponent = nil then
  begin
    if Grabber = nil then
      ACursor := crDefault
    else
      ACursor := Grabber.Cursor;

    if ACursor <> LastFormCursor then
    begin
      LastFormCursor := ACursor;
      SetTempCursor(Form, ACursor);
    end;
    Exit;
  end;

  if (Selection.SelectionForm = nil) or (Selection.SelectionForm = Form) then
  begin
    if Button = mbLeft then // left button pressed
    begin
      if (Selection.ActiveGrabber <> nil) then // grabber active => resizing
      begin
        // grabber moving -> size selection
        if not Selection.LookupRootSelected then // if not current form is selected then resize selection
        begin
          if not (dfHasSized in FFlags) then
          begin
            Selection.SaveBounds(false);
            Include(FFlags, dfHasSized);
          end;
          // skip snapping when Alt is pressed
          if not (ssAlt in Shift) then
          begin
            OldSnappedMousePos := Selection.SnapGrabberMousePos(OldMouseMovePos);
            CurSnappedMousePos := Selection.SnapGrabberMousePos(LastMouseMovePos);
          end
          else
          begin
            OldSnappedMousePos := OldMouseMovePos;
            CurSnappedMousePos := LastMouseMovePos;
          end;
          Selection.SizeSelection(
            CurSnappedMousePos.X - OldSnappedMousePos.X,
            CurSnappedMousePos.Y - OldSnappedMousePos.Y);
          DoModified;
        end;
      end
      else
      begin // no grabber active => moving
        SelectedCompClass := GetSelectedComponentClass;
        if (not Selection.RubberBandActive) and
           (SelectedCompClass=nil) and
           ((Shift=[ssLeft]) or (Shift=[ssAlt, ssLeft])) and
           (Selection.Count>=1) and
           (not Selection.LookupRootSelected) then
        begin // move selection
          if not (dfHasSized in FFlags) then
          begin
            Selection.SaveBounds(false);
            Include(FFlags, dfHasSized);
          end;
          //debugln('TDesigner.MouseMoveOnControl Move MouseDownComponent=',dbgsName(MouseDownComponent),' OldMouseMovePos=',dbgs(OldMouseMovePos),' MouseMovePos',dbgs(LastMouseMovePos),' MouseDownPos=',dbgs(MouseDownPos));
          if (ssAlt in Shift) then begin
            if Selection.MoveSelection(LastMouseMovePos.X - MouseDownPos.X, LastMouseMovePos.Y - MouseDownPos.Y, True) then
              DoModified;
          end else begin
            if Selection.MoveSelectionWithSnapping(LastMouseMovePos.X - MouseDownPos.X, LastMouseMovePos.Y - MouseDownPos.Y) then
              DoModified;
          end;
        end
        else
        begin          // rubberband sizing (selection or creation)
          Selection.RubberBandBounds := Rect(MouseDownPos.X, MouseDownPos.Y,
                                             LastMouseMovePos.X, LastMouseMovePos.Y);
          if SelectedCompClass = nil then
            Selection.RubberbandType := rbtSelection
          else
            Selection.RubberbandType := rbtCreating;
          Selection.RubberBandActive := True;
        end;
      end;
    end
    else
      Selection.ActiveGrabber:=nil;
  end;
  if [dfShowEditorHints, dfHasSized] * FFlags = [dfShowEditorHints, dfHasSized] then
    HintTimer(Self);
end;


{
-----------------------------K E Y D O W N -------------------------------
}
{
  Handles the keydown messages.  DEL deletes the selected controls, CTRL-ARROR
  moves the selection up one, SHIFT-ARROW resizes, etc.
}
procedure TDesigner.KeyDown(Sender: TControl; var TheMessage: TLMKEY);
var
  Shift: TShiftState;
  Command: word;
  Handled: boolean;
  Current: TComponent;
  NameRes: TAskCompNameDialogResult;
  UTF8Char: TUTF8Char;

  procedure Nudge(x, y: integer);
  begin
    if (ssCtrl in Shift) then
    begin
      if ssShift in Shift then
      begin
        x := x * GetGridSizeX;
        y := y * GetGridSizeY;
      end;
      NudgePosition(x, y)
    end
    else
    if (ssShift in Shift) then
      NudgeSize(x, y)
    else
    if (Shift = []) then
      NudgeSelection(x, y);
  end;

begin
  {$IFDEF VerboseDesigner}
  DebugLn(['TDesigner.KEYDOWN ',TheMessage.CharCode,' ',TheMessage.KeyData]);
  {$ENDIF}
  Shift := KeyDataToShiftState(TheMessage.KeyData);
  Handled := False;
  if Mediator<>nil then
    Mediator.KeyDown(Sender,TheMessage.CharCode,Shift);

  Command := FTheFormEditor.TranslateKeyToDesignerCommand(TheMessage.CharCode, Shift);
  //DebugLn(['TDesigner.KEYDOWN Command=',dbgs(Command),' ',TheMessage.CharCode,' ',dbgs(Shift)]);
  DoProcessCommand(Self, Command, Handled);
  //DebugLn(['TDesigner.KeyDown Command=',Command,' Handled=',Handled,' TheMessage.CharCode=',TheMessage.CharCode]);

  if not Handled and (SourceEditorManager.ActiveSourceWindow<>nil)
  and (GetParentForm(SourceEditorManager.ActiveSourceWindow) = GetParentForm(Sender)) then
  begin
    // send special commands to current editor if they have same parent (designer is docked to the editor)
    case Command of
      ecNextEditor, ecPrevEditor,  ecNextEditorInHistory, ecPrevEditorInHistory:
      begin
        FillChar(UTF8Char{%H-}, SizeOf(UTF8Char), 0);
        SourceEditorManager.ActiveSourceWindow.ProcessParentCommand(Self, Command, UTF8Char, nil, Handled);
      end;
    end;
  end;

  if not Handled then
  begin
    Handled := True;
    case TheMessage.CharCode of
      VK_DELETE:
        if not Selection.OnlyInvisiblePersistentsSelected then
          DoDeleteSelectedPersistents;

      VK_UP:
        Nudge(0,-1);

      VK_DOWN:
        Nudge(0,1);

      VK_RIGHT:
        Nudge(1,0);

      VK_LEFT:
        Nudge(-1,0);

      VK_TAB:
        if Shift = [ssShift] then
          NudgeSelection(False)
        else
        if Shift = [] then
          NudgeSelection(True)
        else
          Handled := False;

      VK_RETURN:
        if Shift = [] then
          DoShowObjectInspector
        else
          Handled := False;

      VK_A:
        if Shift = [ssCtrl] then
          DoSelectAll
        else
          Handled := False;

      VK_F2:
        if (Selection.Count=1) and Selection[0].IsTComponent then begin
          Current := TComponent(Selection[0].Persistent);
          NameRes := ShowComponentNameDialog(LookupRoot, Current);
          if NameRes.NameChanged then
            GlobalDesignHook.ComponentRenamed(Current);
          if NameRes.TextChanged then
            GlobalDesignHook.Modified(Current, NameRes.TextPropertyName);
          if NameRes.Changed then
            Modified;
        end; // don't forget the semicolon before else !!!

      else
        Handled := False;
    end;
  end;

  if Handled then
  begin
    TheMessage.CharCode := 0;
    TheMessage.Result := 1;
  end;
end;


{------------------------------------K E Y U P --------------------------------}
procedure TDesigner.KeyUp(Sender: TControl; var TheMessage: TLMKEY);
var
  Shift: TShiftState;
Begin
  {$IFDEF VerboseDesigner}
  //Writeln('TDesigner.KEYUP ',TheMessage.CharCode,' ',TheMessage.KeyData);
  {$ENDIF}
  if Mediator<>nil then begin
    Shift := KeyDataToShiftState(TheMessage.KeyData);
    Mediator.KeyUp(Sender,TheMessage.CharCode,Shift);
  end;
end;

function TDesigner.DoDeleteSelectedPersistents: boolean;
var
  i: integer;
  APersistent: TPersistent;
  AncestorRoot: TComponent;
  AComponent: TComponent;
begin
  Result:=true;
  if (Selection.Count=0) or (Selection.SelectionForm<>Form) then
    exit;
  Result:=false;
  // check if a component is the lookup root (can not be deleted)
  if (Selection.LookupRootSelected) then begin
    if Selection.Count>1 then
      IDEMessageDialog(lisInvalidDelete,
       lisTheRootComponentCanNotBeDeleted, mtInformation,
       [mbOk]);
    exit;
  end;
  // check if a selected component is inherited (can not be deleted)
  for i:=0 to Selection.Count-1 do begin
    if not Selection[i].IsTComponent then continue;
    AncestorRoot:=TheFormEditor.GetAncestorLookupRoot(
                                    TComponent(Selection[i].Persistent));
    if AncestorRoot<>nil then begin
      IDEMessageDialog(lisInvalidDelete,
       Format(lisTheComponentIsInheritedFromToDeleteAnInheritedComp,
         [dbgsName(Selection[i].Persistent), dbgsName(AncestorRoot), LineEnding]),
       mtInformation, [mbOk]);
      exit;
    end;
  end;
  // check if a selected component is not owned by lookuproot (can not be deleted)
  for i:=0 to Selection.Count-1 do begin
    if not Selection[i].IsTComponent then continue;
    AComponent:=TComponent(Selection[i].Persistent);
    if AComponent.Owner<>FLookupRoot then begin
      IDEMessageDialog(lisInvalidDelete,
       Format(lisTheComponentCanNotBeDeletedBecauseItIsNotOwnedBy, [dbgsName(
         Selection[i].Persistent), dbgsName(FLookupRoot)]),
       mtInformation, [mbOk]);
      exit;
    end;
  end;

  for i := 0 to Selection.Count - 1 do
  begin
    if not Selection[i].IsTComponent then continue;
    AComponent := TComponent(Selection[i].Persistent);
    AddUndoAction(AComponent, uopDelete, i = 0, 'Name', AComponent.Name, '');
  end;

  // mark selected components for deletion
  for i:=0 to Selection.Count-1 do
  begin
    APersistent := Selection[i].Persistent;
    if DeletingPersistent.IndexOf(APersistent) = -1 then
      DeletingPersistent.Add(APersistent);
  end;
  // clear selection by selecting the LookupRoot
  SelectOnlyThisComponent(FLookupRoot);
  // delete marked components
  try
    if DeletingPersistent.Count=0 then exit;
    while DeletingPersistent.Count>0 do begin
      APersistent:=TPersistent(DeletingPersistent[DeletingPersistent.Count-1]);
      //debugln(['TDesigner.DoDeleteSelectedComponents A ',dbgsName(APersistent),' ',(APersistent is TComponent) and (TheFormEditor.FindComponent(TComponent(APersistent))<>nil)]);
      RemovePersistentAndChilds(APersistent);
    end;
    MouseDownComponent := Nil;
  finally
    Modified;
  end;
  Result:=true;
end;

procedure TDesigner.DoDeleteSelectedPersistentsAsync(Data: PtrInt);
begin
  DoDeleteSelectedPersistents;
end;

procedure TDesigner.DoSelectAll;
begin
  Selection.BeginUpdate;
  Selection.Clear;
  Selection.SelectAll(FLookupRoot);
  Selection.EndUpdate;
  Form.Invalidate;
end;

procedure TDesigner.DoDeletePersistent(APersistent: TPersistent; FreeIt: boolean);
var
  Hook: TPropertyEditorHook;
  Special: Boolean;
begin
  if APersistent=nil then exit;
  try
    //debugln(['TDesigner.DoDeletePersistent A ',dbgsName(APersistent),' FreeIt=',FreeIt]);
    // unselect component
    Selection.Remove(APersistent);
    if APersistent is TComponent then begin
      PopupMenuComponentEditor:=nil;
      if csDestroying in TComponent(APersistent).ComponentState then
        FreeIt:=false;
    end;
    if GetDesignerForm(APersistent)=nil then begin
      // has no designer
      // -> do not call handlers and simply get rid of the rubbish
      if FreeIt then begin
        //debugln('TDesigner.DoDeletePersistent UNKNOWN in formeditor: ',dbgsName(APersistent));
        APersistent.Free;
      end;
      exit;
    end;
    // call component deleting handlers
    Hook:=GetPropertyEditorHook;
    if Assigned(Hook) then
      Hook.PersistentDeleting(APersistent);
    Special := (Copy(APersistent.ClassName,1,3) = 'TPS') // A hack for PSScript plugins. ToDo...
      or ((APersistent is TWinControl) and TWinControl(APersistent).IsSpecialSubControl);
    // delete component
    if APersistent is TComponent then
      TheFormEditor.DeleteComponent(TComponent(APersistent),FreeIt)
    else if FreeIt then
      APersistent.Free;
    // call ComponentDeleted handler
    if Assigned(FOnPersistentDeleted) then begin
      if Special then       // Special treatment is needed for TPairSplitterSide.
        FOnPersistentDeleted(Self,nil)          // Will rebuild whole OI Tree.
      else
        FOnPersistentDeleted(Self,APersistent);
    end;
    if Assigned(Hook) then
      Hook.PersistentDeleted(APersistent);
  finally
    // unmark component
    DeletingPersistent.Remove(APersistent);
  end;
end;

function TDesigner.GetSelectedComponentClass: TRegisteredComponent;
begin
  Result:=nil;
  if Assigned(FOnGetSelectedComponentClass) then
    FOnGetSelectedComponentClass(Self,Result);
end;

function TDesigner.IsDesignMsg(Sender: TControl; var TheMessage: TLMessage): Boolean;
var
  Act: Word;
begin
  Result := false;
  if csDesigning in Sender.ComponentState then begin
    Result:=true;
    Inc(FProcessingDesignerEvent);
    try
      case TheMessage.Msg of
        LM_PAINT:       Result := PaintControl(Sender, TLMPaint(TheMessage));
        CN_KEYDOWN,CN_SYSKEYDOWN: KeyDown(Sender,TLMKey(TheMessage));
        CN_KEYUP,CN_SYSKEYUP:     KeyUP(Sender,TLMKey(TheMessage));
        LM_LBUTTONDOWN,
        LM_RBUTTONDOWN,
        LM_LBUTTONDBLCLK: MouseDownOnControl(Sender,TLMMouse(TheMessage));
        LM_LBUTTONUP,
        LM_RBUTTONUP:   MouseUpOnControl(Sender, TLMMouse(TheMessage));
        LM_MOUSEMOVE:   MouseMoveOnControl(Sender, TLMMouse(TheMessage));
        LM_SIZE:        Result:=SizeControl(Sender, TLMSize(TheMessage));
        LM_MOVE:        Result:=MoveControl(Sender, TLMMove(TheMessage));
        LM_ACTIVATE: begin
          {$IFDEF VerboseComponentPalette}
          DebugLn(['TDesigner.IsDesignMsg: Got LM_ACTIVATE message.',
                   ' Message.Active=',TLMActivate(TheMessage).Active]);
          {$ENDIF}
          Act:=TLMActivate(TheMessage).Active;
          Result:=DoFormActivated(Act in [WA_ACTIVE, WA_CLICKACTIVE]);
        end;
        LM_CLOSEQUERY:  Result:=DoFormCloseQuery;
        LM_SETCURSOR:   Result:=HandleSetCursor(TheMessage);
        LM_CONTEXTMENU: HandlePopupMenu(Sender, TLMContextMenu(TheMessage));
      else
        Result:=false;
      end;
    finally
      Dec(FProcessingDesignerEvent);
    end;
  end else begin
    if (TheMessage.Msg=LM_PAINT)
    or (TheMessage.Msg=CN_KEYDOWN)
    or (TheMessage.Msg=CN_KEYUP)
    or (TheMessage.Msg=LM_LBUTTONDOWN)
    or (TheMessage.Msg=LM_RBUTTONDOWN)
    or (TheMessage.Msg=LM_LBUTTONDBLCLK)
    or (TheMessage.Msg=LM_LBUTTONUP)
    or (TheMessage.Msg=LM_RBUTTONUP)
    or (TheMessage.Msg=LM_MOUSEMOVE)
    or (TheMessage.Msg=LM_SIZE)
    or (TheMessage.Msg=LM_MOVE)
    or (TheMessage.Msg=LM_ACTIVATE)
    or (TheMessage.Msg=LM_CLOSEQUERY)
    or (TheMessage.Msg=LM_SETCURSOR)
    then
      DebugLn(['TDesigner.IsDesignMsg NOT DESIGNING? ',dbgsName(Sender),' TheMessage.Msg=',GetMessageName(TheMessage.Msg)]);
  end;
end;

function TDesigner.UniqueName(const BaseName: string): string;
begin
  Result:=TheFormEditor.CreateUniqueComponentName(BaseName,LookupRoot);
end;

procedure TDesigner.UTF8KeyPress(var UTF8Key: TUTF8Char);
begin
  if ((Length(UTF8Key) = 1) and (Ord(UTF8Key[1]) < 32))
  or (UTF8Key = sLineBreak) then // pass only printable characters
    Exit;

  if UTF8Key<>'' then
  begin
    DoOnForwardKeyToObjectInspector(Self, UTF8Key);
    UTF8Key := '';
  end;
end;

procedure TDesigner.Modified;
Begin
  Selection.SaveBounds;
  DoModified;
  inherited Modified;
end;

procedure TDesigner.RemovePersistentAndChilds(APersistent: TPersistent);
var
  i: integer;
  AWinControl: TWinControl;
  ChildControl: TControl;
Begin
  if APersistent=nil then exit;
  {$IFDEF VerboseDesigner}
  DebugLn('[TDesigner.RemovePersistentAndChilds] START ',dbgsName(APersistent),' ',DbgS(APersistent));
  {$ENDIF}
  if (APersistent=FLookupRoot) or (APersistent=Form)
  then exit;
  // remove all child controls owned by the LookupRoot
  if (APersistent is TWinControl) then begin
    AWinControl:=TWinControl(APersistent);
    // Component may auto-create new components during deletion unless informed.
    // ComponentState does not have csDestroying yet when removing children.
    AWinControl.DesignerDeleting := True;
    i:=AWinControl.ControlCount-1;
    while (i>=0) do begin
      ChildControl:=AWinControl.Controls[i];
      if ChildControl.Owner=FLookupRoot then begin
        //Debugln(['[TDesigner.RemoveComponentAndChilds] B ',dbgsName(APersistent),' Child=',dbgsName(ChildControl),' i=',i,' ',TheFormEditor.FindComponent(ChildControl)<>nil]);
        RemovePersistentAndChilds(ChildControl);
        // the component list of the form has changed -> restart the search
        i:=AWinControl.ControlCount-1;
      end else
        dec(i);
    end;
    AWinControl.DesignerDeleting := False;
  end;
  // remove component
  {$IFDEF VerboseDesigner}
  DebugLn('[TDesigner.RemovePersistentAndChilds] DoDeletePersistent ',dbgsName(APersistent));
  {$ENDIF}
  DoDeletePersistent(APersistent,true);
end;

procedure TDesigner.Notification(AComponent: TComponent; Operation: TOperation);
begin
  if Operation = opInsert then begin
    {$IFDEF VerboseDesigner}
    DebugLn('opInsert ',dbgsName(AComponent),' ',DbgS(AComponent));
    {$ENDIF}
  end
  else
  if Operation = opRemove then begin
    {$IFDEF VerboseDesigner}
    DebugLn('[TDesigner.Notification] opRemove ',dbgsName(AComponent));
    {$ENDIF}
    // Notification is usually triggered by TheFormEditor.DeleteComponent in DoDeletePersistent.
    DoDeletePersistent(AComponent,false);
  end;
end;

procedure TDesigner.PaintGrid;
begin
  // This is normally done in PaintControls
  if FLookupRoot<>FForm then begin
    // this is a special designer form -> lets draw itself
    TCustomFormAccess(FForm).Paint;
  end;
end;

procedure TDesigner.PaintClientGrid(AWinControl: TWinControl;
  aDDC: TDesignerDeviceContext);
var
  Clip: integer;
  Count: integer;
  i: integer;
  CurControl: TControl;
begin
  if (AWinControl=nil)
  or (not (csAcceptsControls in AWinControl.ControlStyle))
  or ((not ShowGrid) and (not ShowBorderSpacing)) then exit;

  aDDC.BeginPainting;
  try
    // exclude all child control areas
    Count:=AWinControl.ControlCount;
    for i := 0 to Count - 1 do begin
      with AWinControl.Controls[I] do begin
        if (Visible or ((csDesigning in ComponentState)
          and not (csNoDesignVisible in ControlStyle)))
        then begin
          Clip := ExcludeClipRect(aDDC.DC, Left, Top, Left + Width, Top + Height);
          if Clip = NullRegion then exit;
        end;
      end;
    end;

    // paint points
    if ShowGrid then
    begin
      ADDC.Canvas.Pen.Color := GridColor;
      ADDC.Canvas.Pen.Width := 1;
      ADDC.Canvas.Pen.Style := psSolid;
      DrawGrid(ADDC.Canvas.Handle, TWinControlAccess(AWinControl).GetLogicalClientRect,
               GridSizeX, GridSizeY);
    end;
    
    if ShowBorderSpacing then
    begin
      aDDC.Canvas.Brush.Color := clRed;
      for i := 0 to Count - 1 do
      begin
        CurControl := AWinControl.Controls[i];
        if csNoDesignSelectable in CurControl.ControlStyle then
          Continue;
        aDDC.Canvas.FrameRect(
          CurControl.Left-CurControl.BorderSpacing.GetSideSpace(akLeft),
          CurControl.Top-CurControl.BorderSpacing.GetSideSpace(akTop),
          CurControl.Left+CurControl.Width+CurControl.BorderSpacing.GetSideSpace(akRight),
          CurControl.Top+CurControl.Height+CurControl.BorderSpacing.GetSideSpace(akBottom)
          );
      end;
    end;
  finally
    aDDC.EndPainting;
  end;
end;

procedure TDesigner.ValidateRename(AComponent: TComponent;
  const CurName, NewName: string);
begin
  // check if component is initialized
  if (CurName='') or (NewName='')
  or ((AComponent<>nil) and (csDestroying in AComponent.ComponentState)) then
    exit;

  // check if component is the LookupRoot
  if AComponent=nil then AComponent:=FLookupRoot;

  // consistency check
  if CurName<>AComponent.Name then
    DebugLn('WARNING: TDesigner.ValidateRename: OldComponentName="',CurName,'" <> AComponent=',dbgsName(AComponent));
  if Assigned(OnRenameComponent) then
    OnRenameComponent(Self,AComponent,NewName);
end;

function TDesigner.GetShiftState: TShiftState;
begin
  Result:=FShiftState;
end;

function TDesigner.CreateUniqueComponentName(const AClassName: string): string;
begin
  Result:=TheFormEditor.CreateUniqueComponentName(AClassName,FLookupRoot);
end;

procedure TDesigner.OnComponentEditorVerbMenuItemClick(Sender: TObject);
var
  Verb: integer;
  VerbCaption: string;
  AMenuItem: TMenuItem;
begin
  if (PopupMenuComponentEditor=nil) or (Sender=nil) then exit;
  //DebugLn(['TDesigner.OnComponentEditorVerbMenuItemClick Sender=',dbgsName(Sender)]);
  if Sender is TMenuItem then
    AMenuItem:=TMenuItem(Sender)
  else if Sender is TIDEMenuCommand then
    AMenuItem:=TIDEMenuCommand(Sender).MenuItem
  else
    exit;
  Verb:=PopupMenuComponentEditor.GetVerbCount-1;
  VerbCaption:=AMenuItem.Caption;
  while (Verb>=0) and (VerbCaption<>PopupMenuComponentEditor.GetVerb(Verb)) do
    dec(Verb);
  if Verb<0 then exit;
  try
    PopupMenuComponentEditor.ExecuteVerb(Verb);
  except
    on E: Exception do begin
      DebugLn('TDesigner.OnComponentEditorVerbMenuItemClick ERROR: ',E.Message);
      IDEMessageDialog(Format(lisErrorIn, [PopupMenuComponentEditor.ClassName]),
        Format(lisTheComponentEditorOfClassInvokedWithVerbHasCreated,
               [PopupMenuComponentEditor.ClassName, LineEnding, IntToStr(Verb),
                VerbCaption, LineEnding, LineEnding, E.Message]),
        mtError,[mbOk]);
    end;
  end;
end;

procedure TDesigner.OnDeleteSelectionMenuClick(Sender: TObject);
begin
  Application.QueueAsyncCall(@DoDeleteSelectedPersistentsAsync, 0);
end;

procedure TDesigner.OnSelectAllMenuClick(Sender: TObject);
begin
  DoSelectAll;
end;

procedure TDesigner.OnChangeClassMenuClick(Sender: TObject);
begin
  ChangeClass;
end;

procedure TDesigner.OnChangeParentMenuClick(Sender: TObject);
begin
  if Assigned(OnChangeParent) then
    OnChangeParent(Self);
end;

procedure TDesigner.OnShowNonVisualComponentsMenuClick(Sender: TObject);
begin
  ShowNonVisualComponents:=not ShowNonVisualComponents;
end;

procedure TDesigner.OnSnapToGridOptionMenuClick(Sender: TObject);
begin
  EnvironmentOptions.SnapToGrid := not EnvironmentOptions.SnapToGrid;
end;

procedure TDesigner.OnShowOptionsMenuItemClick(Sender: TObject);
begin
  if Assigned(OnShowOptions) then OnShowOptions(Self);
end;

procedure TDesigner.OnSnapToGuideLinesOptionMenuClick(Sender: TObject);
begin
  EnvironmentOptions.SnapToGuideLines := not EnvironmentOptions.SnapToGuideLines;
end;

procedure TDesigner.OnViewLFMMenuClick(Sender: TObject);
begin
  if Assigned(OnViewLFM) then OnViewLFM(Self);
end;

procedure TDesigner.OnSaveAsXMLMenuClick(Sender: TObject);
begin
  if Assigned(OnSaveAsXML) then OnSaveAsXML(Self);
end;

procedure TDesigner.OnCenterFormMenuClick(Sender: TObject);
var
  NewLeft: Integer;
  NewTop: Integer;
begin
  if Form=nil then exit;
  NewLeft:=Max(30,(Screen.Width-Form.Width) div 2);
  NewTop:=Max(30,(Screen.Height-Form.Height) div 2);
  Form.SetBounds(NewLeft,NewTop,Form.Width,Form.Height);
  if Assigned(IDETabMaster) then
    IDETabMaster.ShowForm(Form);
end;

procedure TDesigner.OnCopyMenuClick(Sender: TObject);
begin
  CopySelection;
end;

procedure TDesigner.OnCutMenuClick(Sender: TObject);
begin
  Application.QueueAsyncCall(@CutSelectionAsync, 0);
end;

procedure TDesigner.OnPasteMenuClick(Sender: TObject);
begin
  PasteSelection([cpsfFindUniquePositions]);
end;

procedure TDesigner.OnAnchorEditorMenuClick(Sender: TObject);
begin
  DoShowAnchorEditor;
end;

procedure TDesigner.OnTabOrderMenuClick(Sender: TObject);
begin
  DoShowTabOrderEditor;
end;

function TDesigner.GetGridColor: TColor;
begin
  Result:=EnvironmentOptions.GridColor;
end;

function TDesigner.GetShowBorderSpacing: boolean;
begin
  Result:=EnvironmentOptions.ShowBorderSpacing;
end;

function TDesigner.GetShowComponentCaptions: boolean;
begin
  Result:=dfShowComponentCaptions in FFlags;
end;

function TDesigner.GetShowGrid: boolean;
begin
  Result:=EnvironmentOptions.ShowGrid;
end;

function TDesigner.GetShowNonVisualComponents: boolean;
begin
  Result:=dfShowNonVisualComponents in FFlags;
end;

function TDesigner.GetGridSizeX: integer;
begin
  Result:=EnvironmentOptions.GridSizeX;
  if Result<2 then Result:=2;
end;

function TDesigner.GetGridSizeY: integer;
begin
  Result:=EnvironmentOptions.GridSizeY;
  if Result<2 then Result:=2;
end;

function TDesigner.GetIsControl: Boolean;
Begin
  Result := True;
end;

function TDesigner.GetShowEditorHints: boolean;
begin
  Result:=dfShowEditorHints in FFlags;
end;

function TDesigner.GetSnapToGrid: boolean;
begin
  Result := EnvironmentOptions.SnapToGrid;
end;

procedure TDesigner.SetShowGrid(const AValue: boolean);
begin
  if ShowGrid=AValue then exit;
  EnvironmentOptions.ShowGrid:=AValue;
  Form.Invalidate;
end;

procedure TDesigner.SetShowNonVisualComponents(AValue: boolean);
var
  i: Integer;
begin
  if ShowNonVisualComponents=AValue then exit;

  if AValue then begin
    Include(FFlags,dfShowNonVisualComponents);
    Form.Invalidate;
  end else begin
    Exclude(FFlags,dfShowNonVisualComponents);
    Selection.BeginUpdate;
    try
      for i:=Selection.Count-1 downto 0 do
        if Selection[i].IsNonVisualComponent then
          Selection.Delete(i);
    finally
      Selection.EndUpdate;
      Form.Invalidate;
    end;
  end;
end;

procedure TDesigner.SetGridSizeX(const AValue: integer);
begin
  if GridSizeX=AValue then exit;
  EnvironmentOptions.GridSizeX:=AValue;
end;

procedure TDesigner.SetGridSizeY(const AValue: integer);
begin
  if GridSizeY=AValue then exit;
  EnvironmentOptions.GridSizeY:=AValue;
end;

procedure TDesigner.SetMediator(const AValue: TDesignerMediator);
begin
  if Mediator=AValue then exit;
  if Mediator<>nil then Mediator.Designer:=nil;
  FMediator:=AValue;
  if Mediator<>nil then Mediator.Designer:=Self;
end;

procedure TDesigner.SetPopupMenuComponentEditor(const AValue: TBaseComponentEditor);
begin
   if FPopupMenuComponentEditor <> AValue then
   begin
     FPopupMenuComponentEditor.Free;
     FPopupMenuComponentEditor := AValue;
   end;
end;

procedure TDesigner.SetShowEditorHints(const AValue: boolean);
begin
  if AValue = ShowEditorHints then Exit;
  if AValue then
    Include(FFlags, dfShowEditorHints)
  else
    Exclude(FFlags, dfShowEditorHints);
end;

procedure TDesigner.DrawNonVisualComponent(AComponent: TComponent);
var
  ItemLeft, ItemTop, ItemRight, ItemBottom: integer;
  Diff, ItemLeftTop: TPoint;
  OwnerRect, IconRect, TextRect: TRect;
  TextSize: TSize;
  IsSelected: Boolean;
  RGN: HRGN;
  IL: TCustomImageList;
  II: TImageIndex;
  Res: TScaledImageListResolution;
  Icon: TBitmap;
  ScaleFactor: Double;
begin
  if (AComponent is TControl)
  and (csNoDesignVisible in TControl(AComponent).ControlStyle) then
    exit;
  if (csDestroying in AComponent.ComponentState) then
    exit;

  // draw children
  if (AComponent.Owner=nil) then
  begin
    FDDC.BeginPainting;
    TComponentAccess(AComponent).GetChildren(@DrawNonVisualComponent, AComponent);
    FDDC.EndPainting;
  end
  else if (csInline in AComponent.ComponentState) then
  begin
    if AComponent is TControl then
    begin
      // clip to client area
      FDDC.BeginPainting;
      FDDC.Canvas.SaveHandleState;
      OwnerRect := TControl(AComponent).ClientRect;
      Diff := GetParentFormRelativeClientOrigin(AComponent);
      OffsetRect(OwnerRect, Diff.X, Diff.Y);
      with OwnerRect do
        RGN := CreateRectRGN(Left, Top, Right, Bottom);
      SelectClipRGN(FDDC.DC, RGN);
      DeleteObject(RGN);
    end;
    TComponentAccess(AComponent).GetChildren(@DrawNonVisualComponent, AComponent);
    if AComponent is TControl then
    begin
      FDDC.Canvas.RestoreHandleState;
      FDDC.EndPainting;
    end;
  end
  else
    TComponentAccess(AComponent).GetChildren(@DrawNonVisualComponent, AComponent.Owner);

  if not ComponentIsIcon(AComponent) or (AComponent.Owner = nil) then
    Exit;
  // actual draw
  Diff := FDDC.FormOrigin;
  //DebugLn(['FDDC.FormOrigin - ', Diff.X, ' : ' ,Diff.Y]);
  // non-visual component
  if FDDC.Form<>nil then
    ScaleFactor := FDDC.Form.GetCanvasScaleFactor
  else
    ScaleFactor := 1;
  ItemLeftTop := NonVisualComponentLeftTop(AComponent);
  ItemLeft := ItemLeftTop.X - Diff.X;
  ItemTop := ItemLeftTop.Y - Diff.Y;
  ItemRight := ItemLeft + NonVisualCompWidth;
  ItemBottom := ItemTop + NonVisualCompWidth;
  if not FDDC.RectVisible(ItemLeft, ItemTop, ItemRight, ItemBottom) then
    Exit;

  IsSelected := Selection.IsSelected(AComponent);

  if FSurface = nil then
  begin
    FSurface := TBitmap.Create;
    FSurface.SetSize(Round(NonVisualCompWidth*ScaleFactor),
      Round(NonVisualCompWidth*ScaleFactor));
    FSurface.Canvas.Brush.Color := clBtnFace;
    FSurface.Canvas.Pen.Width := 1;
  end;

  IconRect := Rect(0, 0, Round(NonVisualCompWidth*ScaleFactor),
    Round(NonVisualCompWidth*ScaleFactor));
  FSurface.Canvas.Frame3D(IconRect, 1, bvRaised);
  FSurface.Canvas.FillRect(IconRect);

  // draw component Name
  if ShowComponentCaptions
  and (((GetKeyState(VK_LBUTTON) and $80) = 0) or not IsSelected) then
  begin
    // workarounds gtk2 problem with DrawText on gc with GDK_INCLUDE_INFERIORS
    // it uses pango drawing and this for some reason does not take subwindow_mode
    // into account
    Icon := TBitmap.Create;
    try
      Icon.Canvas.Font.Assign(FDDC.Canvas.Font);
      Icon.Canvas.Font.PixelsPerInch := FDDC.Canvas.Font.PixelsPerInch;
      Icon.Canvas.Font.Height := Round(GetFontData(FDDC.Canvas.Font.Reference.Handle).Height*ScaleFactor);
      TextSize := Icon.Canvas.TextExtent(AComponent.Name);
      Icon.SetSize(TextSize.cx, TextSize.cy);
      TextRect := Rect(0, 0, TextSize.cx, TextSize.cy);
      if FDDC.Form <> nil then
        Icon.Canvas.Brush.Color := FDDC.Form.Brush.Color
      else
        Icon.Canvas.Brush.Color := clBtnFace;
      Icon.Canvas.FillRect(TextRect);
      Icon.Canvas.Font.Color := clWindowText;
      DrawText(Icon.Canvas.Handle, PChar(AComponent.Name), -1, TextRect,
        DT_CENTER or DT_VCENTER or DT_SINGLELINE or DT_NOCLIP);
      TextRect.Left := (ItemLeft + ItemRight - LongInt(Round(TextSize.cx/ScaleFactor))) div 2;
      TextRect.Top := (ItemBottom + NonVisualCompBorder + 2);
      TextRect.Right := TextRect.Left + Round(TextSize.cx/ScaleFactor);
      TextRect.Bottom := TextRect.Top + Round(TextSize.cy/ScaleFactor);
      FDDC.Canvas.StretchDraw(TextRect, Icon);
    finally
      Icon.Free;
    end;
  end;
  // draw component icon
  if Assigned(FOnGetNonVisualCompIcon) then
  begin
    Icon := nil;
    FOnGetNonVisualCompIcon(Self, AComponent, IL{%H-}, II{%H-});
    if (IL<>nil) and (II>=0) then
    begin
      Res := IL.ResolutionForPPI[0, FDDC.Canvas.Font.PixelsPerInch, ScaleFactor];
      InflateRect(IconRect,
        - (IconRect.Right-IconRect.Left-Res.Resolution.Width) div 2,
        - (IconRect.Bottom-IconRect.Top-Res.Resolution.Height) div 2);
      Res.StretchDraw(FSurface.Canvas, II, IconRect);
    end;
  end;
  FDDC.Canvas.StretchDraw(Rect(ItemLeft, ItemTop, ItemRight, ItemBottom), FSurface);
  if (Selection.Count > 1) and IsSelected then
    Selection.DrawMarkerAt(FDDC,
      ItemLeft, ItemTop, NonVisualCompWidth, NonVisualCompWidth);
end;

procedure TDesigner.DrawNonVisualComponents(aDDC: TDesignerDeviceContext);
begin
  if not ShowNonVisualComponents then exit;
  FSurface := nil;
  FDDC := aDDC;
  DrawNonVisualComponent(FLookupRoot);
  FDDC := nil;
  FreeAndNil(FSurface);
end;

procedure TDesigner.DrawDesignerItems(OnlyIfNeeded: boolean);
var
  DesignerDC: HDC;
begin
  if WidgetSet.GetLCLCapability(lcCanDrawOutsideOnPaint) = 0 then Exit;
  if OnlyIfNeeded and (not (dfNeedPainting in FFlags)) then exit;
  Exclude(FFlags,dfNeedPainting);

  if (Form=nil) or (not Form.HandleAllocated) then exit;

  //writeln('TDesigner.DrawDesignerItems B painting');
  DesignerDC := GetDesignerDC(Form.Handle);
  DDC.SetDC(Form, Form, DesignerDC);
  DDC.BeginPainting;
  DoPaintDesignerItems;
  DDC.EndPainting;
  DDC.Clear;
  ReleaseDesignerDC(Form.Handle, DesignerDC);
end;

procedure TDesigner.CheckFormBounds;
// check if the Form was moved or resized
// Note: During form loading the window manager can resize and position
//       the Form. Such initial changes are ignored, by waiting and comparing
//       not before the IDE becomes idle. When the IDE becomes the first time
//       idle, the form bounds are stored and used as default.
//       After that any change of the Form Bounds is treated as a user move
//       and thus calls Modified.
var
  NewFormBounds: TRect;
begin
  NewFormBounds:=Form.BoundsRect;
  if FDefaultFormBoundsValid then begin
    if (not CompareRect(@NewFormBounds,@FLastFormBounds))
    and (not CompareRect(@NewFormBounds,@FDefaultFormBounds)) then begin
      //debugln('TDesigner.CheckFormBounds');
      Modified;
      if Selection.SelectionForm=Form then begin
        Selection.CheckForLCLChanges(true);
      end;
    end;
  end else begin
    FDefaultFormBoundsValid:=true;
    FDefaultFormBounds:=NewFormBounds;
  end;
  FLastFormBounds:=NewFormBounds;
end;

procedure TDesigner.DoPaintDesignerItems;
begin
  // marker (multi selection markers)
  if (Selection.SelectionForm = Form) and (Selection.Count > 1) then
  begin
    Selection.DrawMarkers(DDC);
  end;
  // non visual component icons
  if not Assigned(IDEComponentsMaster)
  or IDEComponentsMaster.DrawNonVisualComponents(FLookupRoot) then
    DrawNonVisualComponents(DDC);

  // guidelines and grabbers
  if (Selection.SelectionForm=Form) then
  begin
    if EnvironmentOptions.ShowGuideLines then
      Selection.DrawGuideLines(DDC);
    Selection.DrawGrabbers(DDC);
  end;
  // rubberband
  if Selection.RubberBandActive and
     ((Selection.SelectionForm = Form) or (Selection.SelectionForm = nil)) then
  begin
    Selection.DrawRubberBand(DDC);
  end;
end;

function TDesigner.ComponentIsIcon(AComponent: TComponent): boolean;
begin
  Result:=ComponentIsNonVisual(AComponent);
  if Result and (Mediator<>nil) then
    Result:=Mediator.ComponentIsIcon(AComponent);
end;

function TDesigner.GetParentFormRelativeClientOrigin(AComponent: TComponent): TPoint;
begin
  if Mediator<>nil then begin
    Result:=Mediator.GetComponentOriginOnForm(AComponent);
  end else begin
    Result:=DesignerProcs.GetParentFormRelativeClientOrigin(AComponent);
  end;
end;

function TDesigner.GetDesignedComponent(AComponent: TComponent): TComponent;
begin
  Result:=AComponent;
  if AComponent=Form then begin
    Result:=FLookupRoot;
  end else begin
    while (Result<>nil)
    and (Result<>FLookupRoot)
    and (Result.Owner<>FLookupRoot)
    and (Result is TControl) do
      Result:=TControl(Result).Parent;
  end;
end;

function TDesigner.GetComponentEditorForSelection: TBaseComponentEditor;
begin
  Result := nil;
  if (Selection.Count <> 1) or
     (Selection.SelectionForm <> Form) or
     (not Selection[0].IsTComponent) then Exit;
  Result := TheFormEditor.GetComponentEditor(TComponent(Selection[0].Persistent));
end;

procedure TDesigner.AddComponentEditorMenuItems(
  AComponentEditor: TBaseComponentEditor; ClearOldOnes: boolean);
var
  VerbCount, i: integer;
  NewMenuCmd: TIDEMenuCommand;
begin
  if ClearOldOnes then
    DesignerMenuSectionComponentEditor.Clear;

  if (AComponentEditor = nil) or (DesignerMenuSectionComponentEditor = nil) then
    Exit;

  VerbCount := AComponentEditor.GetVerbCount;
  for i := 0 to VerbCount - 1 do
  begin
    NewMenuCmd:=RegisterIDEMenuCommand(DesignerMenuSectionComponentEditor,
      'ComponentEditorVerMenuItem' + IntToStr(i),
      AComponentEditor.GetVerb(i),
      @OnComponentEditorVerbMenuItemClick);
    if NewMenuCmd.MenuItem<>nil then
      AComponentEditor.PrepareItem(i, NewMenuCmd.MenuItem);
  end;
end;

function TDesigner.NonVisualComponentAtPos(X, Y: integer): TComponent;
var
  s: TComponentSearch;
begin
  // Note: Do not check ShowNonVisualComponents
  s := TComponentSearch.Create(nil);
  try
    s.MinClass := TComponent;
    s.AtPos := Point(X,Y);
    s.IgnoreHidden := true;
    s.OnlyNonVisual := true;
    s.Search(FLookupRoot);
    s.Mediator := Mediator;
    Result := s.Best;
  finally
    s.Free;
  end;
end;

procedure TDesigner.MoveNonVisualComponentIntoForm(AComponent: TComponent);
var
  X, Y: SmallInt;
begin
  DesignInfoToLeftTop(AComponent.DesignInfo, X, Y);
  AComponent.DesignInfo := LeftTopToDesignInfo(X, Y);
end;

procedure TDesigner.MoveNonVisualComponentsIntoForm;
var
  i: Integer;
  AComponent: TComponent;
begin
  for i:=0 to FLookupRoot.ComponentCount-1 do begin
    AComponent:=FLookupRoot.Components[i];
    if ComponentIsIcon(AComponent) then begin
      MoveNonVisualComponentIntoForm(AComponent);
    end;
  end;
end;

function TDesigner.ComponentClassAtPos(const AClass: TComponentClass;
  const APos: TPoint; const UseRootAsDefault, IgnoreHidden: boolean): TComponent;
var
  s: TComponentSearch;
  MediatorFlags: TDMCompAtPosFlags;
begin
  if Mediator <> nil then
  begin
    MediatorFlags := [];
    if IgnoreHidden then
      Include(MediatorFlags, dmcapfOnlyVisible);
    Result := Mediator.ComponentAtPos(APos,AClass,MediatorFlags);
  end
  else
  begin
    s := TComponentSearch.Create(nil);
    try
      s.AtPos := APos;
      s.MinClass := AClass;
      s.IgnoreHidden := IgnoreHidden;
      s.IgnoreNonVisual := not ShowNonVisualComponents;
      s.Search(FLookupRoot);
      s.Mediator := Mediator;
      Result := s.Best;
    finally
      s.Free;
    end;
  end;
  if (Result = nil) and UseRootAsDefault and (FLookupRoot.InheritsFrom(AClass)) then
    Result := LookupRoot;
end;

procedure TDesigner.SetTempCursor(ARoot: TWinControl; ACursor: TCursor);

  procedure Traverse(ARoot: TWinControl);
  var
    i: integer;
  begin
    for i := 0 to ARoot.ControlCount - 1 do
    begin
      ARoot.Controls[i].SetTempCursor(ACursor);
      if ARoot.Controls[i] is TWinControl then
        Traverse(TWinControl(ARoot.Controls[i]));
    end;
  end;

begin
  Traverse(ARoot);
  ARoot.SetTempCursor(ACursor);
end;

function TDesigner.WinControlAtPos(x, y: integer; UseRootAsDefault,
  IgnoreHidden: boolean): TWinControl;
begin
  Result := TWinControl(ComponentClassAtPos(TWinControl, Point(x,y),
                                            UseRootAsDefault, IgnoreHidden));
end;

function TDesigner.ControlAtPos(x, y: integer; UseRootAsDefault,
  IgnoreHidden: boolean): TControl;
begin
  Result := TControl(ComponentClassAtPos(TControl, Point(x,y), UseRootAsDefault,
                                IgnoreHidden));
end;

function TDesigner.ComponentAtPos(x, y: integer; UseRootAsDefault,
  IgnoreHidden: boolean): TComponent;
begin
  Result := ComponentClassAtPos(TComponent, Point(x,y), UseRootAsDefault,
                                IgnoreHidden);
end;

procedure TDesigner.BuildPopupMenu;
begin
  if FDesignerPopupMenu = nil then
  begin
    FDesignerPopupMenu:=TPopupMenu.Create(nil);
    with FDesignerPopupMenu do
    begin
      Name := 'DesignerPopupmenu';
      OnPopup := @DesignerPopupMenuPopup;
      Images := IDEImages.Images_16;
    end;
  end;
  // assign the root TMenuItem to the registered menu root.
  // This will automatically create all registered items
  {$IFDEF VerboseMenuIntf}
  FDesignerPopupMenu.Items.WriteDebugReport('TSourceNotebook.BuildPopupMenu ');
  DesignerMenuRoot.ConsistencyCheck;
  {$ENDIF}
  DesignerMenuRoot.MenuItem := FDesignerPopupMenu.Items;

  DesignerMenuAlign.OnClick := @OnAlignPopupMenuClick;
  DesignerMenuMirrorHorizontal.OnClick := @OnMirrorHorizontalPopupMenuClick;
  DesignerMenuMirrorVertical.OnClick := @OnMirrorVerticalPopupMenuClick;
  DesignerMenuScale.OnClick := @OnScalePopupMenuClick;
  DesignerMenuSize.OnClick := @OnSizePopupMenuClick;
  DesignerMenuReset.OnClick := @OnResetPopupMenuClick;

  DesignerMenuAnchorEditor.OnClick:=@OnAnchorEditorMenuClick;
  DesignerMenuTabOrder.OnClick:=@OnTabOrderMenuClick;
    DesignerMenuOrderMoveToFront.OnClick := @OnOrderMoveToFrontMenuClick;
    DesignerMenuOrderMoveToFront.MenuItem.ShortCut :=
                     EditorOpts.KeyMap.CommandToShortCut(ecDesignerMoveToFront);
    DesignerMenuOrderMoveToBack.OnClick := @OnOrderMoveToBackMenuClick;
    DesignerMenuOrderMoveToBack.MenuItem.ShortCut :=
                     EditorOpts.KeyMap.CommandToShortCut(ecDesignerMoveToBack);
    DesignerMenuOrderForwardOne.OnClick := @OnOrderForwardOneMenuClick;
    DesignerMenuOrderForwardOne.MenuItem.ShortCut :=
                     EditorOpts.KeyMap.CommandToShortCut(ecDesignerForwardOne);
    DesignerMenuOrderBackOne.OnClick := @OnOrderBackOneMenuClick;
    DesignerMenuOrderBackOne.MenuItem.ShortCut :=
                     EditorOpts.KeyMap.CommandToShortCut(ecDesignerBackOne);

  DesignerMenuCut.OnClick:=@OnCutMenuClick;
  DesignerMenuCopy.OnClick:=@OnCopyMenuClick;
  DesignerMenuPaste.OnClick:=@OnPasteMenuClick;
  DesignerMenuDeleteSelection.OnClick:=@OnDeleteSelectionMenuClick;
  DesignerMenuSelectAll.OnClick:=@OnSelectAllMenuClick;

  DesignerMenuChangeClass.OnClick:=@OnChangeClassMenuClick;
  DesignerMenuChangeParent.OnClick:=@OnChangeParentMenuClick;
  DesignerMenuViewLFM.OnClick:=@OnViewLFMMenuClick;
  DesignerMenuSaveAsXML.OnClick:=@OnSaveAsXMLMenuClick;
  DesignerMenuCenterForm.OnClick:=@OnCenterFormMenuClick;

  DesignerMenuShowNonVisualComponents.OnClick:=@OnShowNonVisualComponentsMenuClick;
  DesignerMenuShowNonVisualComponents.ShowAlwaysCheckable:=true;
  DesignerMenuSnapToGridOption.OnClick:=@OnSnapToGridOptionMenuClick;
  DesignerMenuSnapToGridOption.ShowAlwaysCheckable:=true;
  DesignerMenuSnapToGuideLinesOption.OnClick:=@OnSnapToGuideLinesOptionMenuClick;
  DesignerMenuSnapToGuideLinesOption.ShowAlwaysCheckable:=true;
  DesignerMenuShowOptions.OnClick:=@OnShowOptionsMenuItemClick;
end;

procedure TDesigner.DesignerPopupMenuPopup(Sender: TObject);
var
  ControlSelIsNotEmpty,
  LookupRootIsSelected,
  OnlyNonVisualsAreSelected,
  CompsAreSelected: boolean;
  MultiCompsAreSelected: boolean;
  OneControlSelected: Boolean;
  SelectionVisible: Boolean;
  SrcFile: TLazProjectFile;
  UnitIsVirtual, DesignerCanCopy, HasChangeParentCandidates,
    HasAncestorComponent: Boolean;
  PersistentSelection: TPersistentSelectionList;
  ChangeParentCandidates: TFPList;
  i: Integer;
  Item: TSelectedControl;
  AComponent, AncestorComponent: TComponent;
begin
  SrcFile:=LazarusIDE.GetProjectFileWithDesigner(Self);
  ControlSelIsNotEmpty:=(Selection.Count>0)
                    and (Selection.SelectionForm=Form);
  LookupRootIsSelected:=Selection.LookupRootSelected;
  OnlyNonVisualsAreSelected := Selection.OnlyNonVisualPersistentsSelected;
  SelectionVisible:=not Selection.OnlyInvisiblePersistentsSelected;
  CompsAreSelected:=ControlSelIsNotEmpty and SelectionVisible
                    and not LookupRootIsSelected;
  OneControlSelected := ControlSelIsNotEmpty and not Selection[0].IsNonVisualComponent;
  MultiCompsAreSelected := CompsAreSelected and (Selection.Count>1);
  UnitIsVirtual:=(SrcFile=nil) or not FilenameIsAbsolute(SrcFile.Filename);
  PersistentSelection:=TPersistentSelectionList.Create;
  try
    Selection.GetSelection(PersistentSelection);

    ChangeParentCandidates:=GetChangeParentCandidates(GlobalDesignHook,PersistentSelection);
    HasChangeParentCandidates:=ChangeParentCandidates.Count>0;
    FreeAndNil(ChangeParentCandidates);

    HasAncestorComponent:=false;
    for i:=0 to Selection.Count-1 do
    begin
      Item:=Selection[i];
      AComponent:=TComponent(Item.Persistent);
      AncestorComponent:=TheFormEditor.GetAncestorInstance(AComponent);
      if AncestorComponent<>nil then
      begin
        HasAncestorComponent:=true;
        break;
      end;
    end;
  finally
    FreeAndNil(PersistentSelection);
  end;

  AddComponentEditorMenuItems(PopupMenuComponentEditor,true);

  DesignerMenuAlign.Enabled := CompsAreSelected and not OnlyNonVisualsAreSelected;
  DesignerMenuMirrorHorizontal.Enabled := MultiCompsAreSelected and not OnlyNonVisualsAreSelected;
  DesignerMenuMirrorVertical.Enabled := MultiCompsAreSelected and not OnlyNonVisualsAreSelected;
  DesignerMenuScale.Enabled := CompsAreSelected and not OnlyNonVisualsAreSelected;
  DesignerMenuSize.Enabled := CompsAreSelected and not OnlyNonVisualsAreSelected;
  DesignerMenuReset.Enabled := HasAncestorComponent;

  DesignerMenuAnchorEditor.Enabled := (FLookupRoot is TWinControl) and (TWinControl(FLookupRoot).ControlCount > 0);
  DesignerMenuTabOrder.Enabled := (FLookupRoot is TWinControl) and (TWinControl(FLookupRoot).ControlCount > 0);
  DesignerMenuSectionZOrder.Enabled := CompsAreSelected and not OnlyNonVisualsAreSelected;
    DesignerMenuOrderMoveToFront.Enabled := OneControlSelected and not OnlyNonVisualsAreSelected;
    DesignerMenuOrderMoveToBack.Enabled := OneControlSelected and not OnlyNonVisualsAreSelected;
    DesignerMenuOrderForwardOne.Enabled := OneControlSelected and not OnlyNonVisualsAreSelected;
    DesignerMenuOrderBackOne.Enabled := OneControlSelected and not OnlyNonVisualsAreSelected;

  DesignerCanCopy := CanCopy;
  DesignerMenuCut.Enabled := DesignerCanCopy;
  DesignerMenuCopy.Enabled := DesignerCanCopy;
  DesignerMenuPaste.Enabled := CanPaste;
  DesignerMenuDeleteSelection.Enabled := CompsAreSelected;

  DesignerMenuChangeClass.Enabled := CompsAreSelected and (Selection.Count = 1);
  // Disable ViewLFM menu item for virtual units. There is no form file yet.
  DesignerMenuViewLFM.Enabled := not UnitIsVirtual;
  DesignerMenuChangeParent.Enabled := HasChangeParentCandidates;
  DesignerMenuSnapToGridOption.Checked := EnvironmentOptions.SnapToGrid;
  DesignerMenuShowNonVisualComponents.Checked := ShowNonVisualComponents;
  DesignerMenuSnapToGuideLinesOption.Checked := EnvironmentOptions.SnapToGuideLines;
end;

procedure TDesigner.OnAlignPopupMenuClick(Sender: TObject);
var
  HorizAlignment, VertAlignment: TComponentAlignment;
  HorizAlignID, VertAlignID: integer;
begin
  if ShowAlignComponentsDialog(HorizAlignID,VertAlignID)=mrOk then 
  begin
    case HorizAlignID of
     1: HorizAlignment:=csaSides1;
     2: HorizAlignment:=csaCenters;
     3: HorizAlignment:=csaSides2;
     4: HorizAlignment:=csaCenterInWindow;
     5: HorizAlignment:=csaSpaceEqually;
     6: HorizAlignment:=csaSide1SpaceEqually;
     7: HorizAlignment:=csaSide2SpaceEqually;
     else HorizAlignment:=csaNone;  // value=0, this prevents compiler warning.
    end;
    case VertAlignID of
     1: VertAlignment:=csaSides1;
     2: VertAlignment:=csaCenters;
     3: VertAlignment:=csaSides2;
     4: VertAlignment:=csaCenterInWindow;
     5: VertAlignment:=csaSpaceEqually;
     6: VertAlignment:=csaSide1SpaceEqually;
     7: VertAlignment:=csaSide2SpaceEqually;
     else VertAlignment:=csaNone;  // value=0, this prevents compiler warning.
    end;
    Selection.AlignComponents(HorizAlignment,VertAlignment);
    Modified;
  end;
end;

procedure TDesigner.OnMirrorHorizontalPopupMenuClick(Sender: TObject);
begin
  Selection.MirrorHorizontal;
  Modified;
end;

procedure TDesigner.OnMirrorVerticalPopupMenuClick(Sender: TObject);
begin
  Selection.MirrorVertical;
  Modified;
end;

procedure TDesigner.OnScalePopupMenuClick(Sender: TObject);
var
  ScaleInPercent: integer;
begin
  if ShowScaleComponentsDialog(ScaleInPercent)=mrOk then 
  begin
    Selection.ScaleComponents(ScaleInPercent);
    Modified;
  end;
end;

procedure TDesigner.OnSizePopupMenuClick(Sender: TObject);
var
  HorizSizing, VertSizing: TComponentSizing;
  HorizSizingID, VertSizingID: integer;
  AWidth, AHeight: integer;
begin
  if ShowSizeComponentsDialog(HorizSizingID,AWidth,VertSizingID,AHeight) = mrOk then 
  begin
    case HorizSizingID of
     1: HorizSizing:=cssShrinkToSmallest;
     2: HorizSizing:=cssGrowToLargest;
     3: HorizSizing:=cssFixed;
     else HorizSizing:=cssNone;  // value=0, this prevents compiler warning.
    end;
    case VertSizingID of
     1: VertSizing:=cssShrinkToSmallest;
     2: VertSizing:=cssGrowToLargest;
     3: VertSizing:=cssFixed;
     else VertSizing:=cssNone;  // value=0, this prevents compiler warning.
    end;
    Selection.SizeComponents(HorizSizing,AWidth,VertSizing,AHeight);
    Modified;
  end;
end;

procedure TDesigner.OnResetPopupMenuClick(Sender: TObject);
var
  ResetComps: TFPList;
  HasChanged: Boolean;

  procedure ResetControl(AControl: TControl; Recursive: boolean);
  var
    Ancestor: TControl;
    i: Integer;
    OldBounds: TRect;
    NewBounds: TRect;
  begin
    if ResetComps.IndexOf(AControl)>=0 then exit;
    ResetComps.Add(AControl);
    Ancestor:=TControl(TheFormEditor.GetAncestorInstance(AControl));
    if not (Ancestor is TControl) then exit;
    OldBounds:=AControl.BoundsRect;
    NewBounds:=Ancestor.BoundsRect;
    if not CompareRect(@OldBounds,@NewBounds) then begin
      AControl.BoundsRect:=NewBounds;
      HasChanged:=true;
    end;
    if Recursive and (AControl is TWinControl) then begin
      for i:=0 to TWinControl(AControl).ControlCount-1 do
        ResetControl(TWinControl(AControl).Controls[i],true);
    end;
  end;

var
  MsgResult: TModalResult;
  i: Integer;
  Item: TSelectedControl;
  AComponent: TComponent;
  AncestorComponent: TComponent;
begin
  MsgResult:=IDEQuestionDialog(lisReset,
      lisResetLeftTopWidthHeightOfSelectedComponentsToTheir,
      mtConfirmation, [mrYes, lisSelected,
                       mrYesToAll, lisSelectedAndChildControls,
                       mrCancel]);
  if not (MsgResult in [mrYes,mrYesToAll]) then exit;
  HasChanged:=false;
  Form.DisableAutoSizing{$IFDEF DebugDisableAutoSizing}('TDesigner.OnResetPopupMenuClick'){$ENDIF};
  ResetComps:=TFPList.Create;
  try
    for i:=0 to Selection.Count-1 do begin
      Item:=Selection[i];
      if Item.IsTControl then begin
        ResetControl(TControl(Item.Persistent),MsgResult=mrYesToAll);
      end else if Item.IsTComponent then begin
        AComponent:=TComponent(Item.Persistent);
        if ResetComps.IndexOf(AComponent)>=0 then continue;
        ResetComps.Add(AComponent);
        if Item.IsNonVisualComponent then begin
          AncestorComponent:=TheFormEditor.GetAncestorInstance(AComponent);
          if AncestorComponent=nil then continue;
          if AComponent.DesignInfo=AncestorComponent.DesignInfo then continue;
          AComponent.DesignInfo:=AncestorComponent.DesignInfo;
          HasChanged:=true;
        end;
      end;
    end;
  finally
    ResetComps.Free;
    Form.EnableAutoSizing{$IFDEF DebugDisableAutoSizing}('TDesigner.OnResetPopupMenuClick'){$ENDIF};
    if HasChanged then
      Modified;
  end;
end;

procedure TDesigner.OnOrderMoveToFrontMenuClick(Sender: TObject);
begin
  DoChangeZOrder(0);
end;

procedure TDesigner.OnOrderMoveToBackMenuClick(Sender: TObject);
begin
  DoChangeZOrder(1);
end;

procedure TDesigner.OnOrderForwardOneMenuClick(Sender: TObject);
begin
  DoChangeZOrder(2);
end;

procedure TDesigner.OnOrderBackOneMenuClick(Sender: TObject);
begin
  DoChangeZOrder(3);
end;

procedure TDesigner.HintTimer(Sender: TObject);

  function GetComponentHintText(AComponent: TComponent): String;
  const
    HintNameStr = '%s: %s';
    HintPositionStr = 'Position: %d, %d';
    HintSizeStr = 'Size: %d x %d';
    HintTabStr = 'TabStop: %s; TabOrder: %d';
  var
    AControl: TControl absolute AComponent;
    AWinControl: TWinControl absolute AComponent;
    AComponentEditor: TBaseComponentEditor;
    S: String;
  begin
    // component name and classname
    Result := Format(HintNameStr, [AComponent.Name, AComponent.ClassName]);
    // component position
    Result := Result + LineEnding + Format(HintPositionStr, [GetComponentLeft(AComponent), GetComponentTop(AComponent)]);
    if AComponent is TControl then // more info for controls
    begin
      // size
      Result := Result + '; ' + Format(HintSizeStr, [AControl.Width, AControl.Height]);
      // and TabStop, TabOrder for TWinControl
      if (AComponent is TWinControl) and not (AComponent = Form) then
        Result := Result + LineEnding + Format(HintTabStr, [BoolToStr(AWinControl.TabStop, True), AWinControl.TabOrder]);
    end;
    AComponentEditor := TheFormEditor.GetComponentEditor(AComponent);
    if Assigned(AComponentEditor) then
    begin
      S := AComponentEditor.GetCustomHint;
      if S <> '' then
        Result := Result + LineEnding + S;
      AComponentEditor.Free;
    end;
  end;

  function ParentComponent(AComponent: TComponent): TComponent;
  begin
    Result := AComponent.GetParentComponent;
    if (Result = nil) and ComponentIsIcon(AComponent) then
      Result := AComponent.Owner;
  end;

  function GetSelectionSizeHintText: String;
  begin
    Result := Format('%d x %d', [Selection.Width, Selection.Height]);
  end;

  function GetSelectionPosHintText: String;
  var
    BaseParent, TestParent: TComponent;
    BaseFound: Boolean;
    i: integer;
    P: TPoint;
  begin
    BaseFound := Selection[0].IsTComponent;
    // search for one parent of our selection
    if BaseFound then
    begin
      BaseParent := ParentComponent(TComponent(Selection[0].Persistent));
      BaseFound := BaseParent is TWinControl;
      if BaseFound then
      begin
        for i := 1 to Selection.Count - 1 do
        begin
          if Selection[0].IsTComponent then
            TestParent := ParentComponent(TComponent(Selection[0].Persistent))
          else
            TestParent := nil;
          if TestParent <> BaseParent then
          begin
            BaseFound := False;
            Break;
          end;
        end;
      end;
    end;
    P := Point(Selection.Left, Selection.Top);
    if BaseFound then
      P := TWinControl(BaseParent).ScreenToClient(Form.ClientToScreen(P));
    Result := Format('%d, %d', [P.X, P.Y]);
  end;

var
  Rect: TRect;
  AHint: String;
  Position, ClientPos: TPoint;
  AWinControl: TWinControl;
  AComponent: TComponent;
begin
  FHintTimer.Enabled := False;
  if ([dfShowEditorHints]*FFlags=[]) or (Form=nil) then exit;

  Position := Mouse.CursorPos;
  if not (dfHasSized in FFlags) then
  begin
    AWinControl := FindLCLWindow(Position);
    if not (Assigned(AWinControl)) then Exit;
    if GetDesignerForm(AWinControl) <> Form then exit;

    // search a component at the position
    ClientPos := Form.ScreenToClient(Position);
    AComponent := ComponentAtPos(ClientPos.X,ClientPos.Y,true,true);
    if not Assigned(AComponent) then
      AComponent := AWinControl;
    AComponent := GetDesignedComponent(AComponent);
    if AComponent = nil then exit;
    AHint := GetComponentHintText(AComponent);
  end
  else
  begin
    // components are either resize or move
    if (Selection.LookupRoot <> Form) or (Selection.Count = 0) then
      Exit;
    if Selection.ActiveGrabber <> nil then
      AHint := GetSelectionSizeHintText
    else
      AHint := GetSelectionPosHintText;
  end;

  Rect := FHintWindow.CalcHintRect(0, AHint, Nil);  //no maxwidth
  Rect.Left := Position.X + 15;
  Rect.Top := Position.Y + 15;
  Rect.Right := Rect.Left + Rect.Right;
  Rect.Bottom := Rect.Top + Rect.Bottom;
  FHintWindow.ActivateHint(Rect, AHint);
end;

procedure TDesigner.SetSnapToGrid(const AValue: boolean);
begin
  if SnapToGrid=AValue then exit;
  EnvironmentOptions.SnapToGrid:=AValue;
end;

procedure TDesigner.DoOnForwardKeyToObjectInspector(Sender: TObject;
  Key: TUTF8Char);
begin
  if Assigned(FOnForwardKeyToObjectInspector) then
    FOnForwardKeyToObjectInspector(Self, Key);
end;

function TDesigner.DoFormActivated(Active: boolean): boolean;
begin
  if Active then begin
    // designer form was activated.
    if Assigned(FOnActivated) then FOnActivated(Self);
  end else begin
    // designer form deactivated
  end;
  Result:=false; // pass message to form, needed for focussing
end;

function TDesigner.DoFormCloseQuery: boolean;
begin
  if Assigned(FOnCloseQuery) then FOnCloseQuery(Self);
  Result:=true; // do not pass to form
end;

function TDesigner.GetPropertyEditorHook: TPropertyEditorHook;
begin
  Result:=TheFormEditor.PropertyEditorHook;
end;

end.


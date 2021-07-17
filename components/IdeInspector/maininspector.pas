unit MainInspector;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, types, typinfo, math,
  // LCL
  LCLProc, Forms, Controls, Graphics, Dialogs, ExtCtrls, ComCtrls, StdCtrls,
  Buttons, Menus,
  // LazUtils
  FileUtil, LazConfigStorage, LazStringUtils,
  // IdeIntf
  BaseIDEIntf, MenuIntf, LazIDEIntf, ObjectInspector, PropEdits,
  // IdeInspector
  IdeInspectKeyGrapper;

type

  { THistoryEntry }

  THistoryEntry = class
  private
    FBaseDisplay: string;
  public
    Comp: TComponent;
    Display: string;
    IdentifierName: string;
    TheUnitName: string;
    FileName: string;
    Line: Integer;
    procedure Assign(Other: THistoryEntry);
    procedure UpdateDisplayName;
  end;

  { TIdeInspectForm }

  TIdeInspectForm = class(TForm)
    ComboHistory: TComboBox;
    EditUnit: TEdit;
    EditFile: TEdit;
    ImageList1: TImageList;
    menuFollowForm: TMenuItem;
    menuFollowFrame: TMenuItem;
    Panel1: TPanel;
    Panel2: TPanel;
    popComponent: TPopupMenu;
    popSubComponent: TPopupMenu;
    popControls: TPopupMenu;
    popFollowType: TPopupMenu;
    btnOpenFile: TSpeedButton;
    btnSaveHist: TSpeedButton;
    Splitter1: TSplitter;
    TabControl1: TTabControl;
    ToolBar1: TToolBar;
    btnComponent: TToolButton;
    btnSubComponent: TToolButton;
    ToolButton1: TToolButton;
    btnRemoveSelected: TToolButton;
    ToolButton2: TToolButton;
    btnControls: TToolButton;
    ToolButton3: TToolButton;
    ToolButton4: TToolButton;
    btnEndModal: TToolButton;
    sepModal: TToolButton;
    btnKeepTop: TToolButton;
    ToolButtonKey: TToolButton;
    ToolButtonActiveType: TToolButton;
    ToolButtonFollowActive: TToolButton;
    TreeView1: TTreeView;
    procedure btnControlsClick(Sender: TObject);
    procedure btnEndModalClick(Sender: TObject);
    procedure btnKeepTopClick(Sender: TObject);
    procedure btnOpenFileClick(Sender: TObject);
    procedure btnSaveHistClick(Sender: TObject);
    procedure btnSubComponentClick(Sender: TObject);
    procedure ComboHistoryChange(Sender: TObject);
    procedure FormClose(Sender: TObject; var CloseAction: TCloseAction);
    procedure FormShow(Sender: TObject);
    procedure menuFollowFormClick(Sender: TObject);
    procedure menuFollowFrameClick(Sender: TObject);
    procedure MenuItem1Click(Sender: TObject);
    procedure btnComponentClick(Sender: TObject);
    procedure popComponentPopup(Sender: TObject);
    procedure popControlsPopup(Sender: TObject);
    procedure popSubComponentPopup(Sender: TObject);
    procedure btnRemoveSelectedClick(Sender: TObject);
    procedure TabControl1Change(Sender: TObject);
    procedure ToolButtonActiveTypeClick(Sender: TObject);
    procedure ToolButtonFollowActiveClick(Sender: TObject);
    procedure ToolButtonKeyClick(Sender: TObject);
    procedure TreeView1Change(Sender: TObject; Node: TTreeNode);
    procedure TreeView1Click(Sender: TObject);
  private
    FSelected: TComponent;
    FFollowFrames: Boolean;
    FHistoryList: TList;
    FCurEntry: THistoryEntry;
    FIsUpdatingHistory: Boolean;
    FConf: TConfigStorage;
    FKeyGrabForm: TIdeInspectKeyGrabForm;
    FShortCutKey: Word;
    FShortCutShift: TShiftState;
    procedure DoPropSelChanged(Sender: TObject);
  protected
    FPropertiesGrid: TCustomPropertiesGrid;
    procedure UpdateTree;
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
    procedure DoActiveFormChanged(Sender: TObject; Form: TCustomForm);
    procedure DoActiveControChanged(Sender: TObject; LastControl: TControl);
    procedure DoKeyDownBefore(Sender: TObject; var Key: Word; Shift: TShiftState);

    function  IndexOfCurrent: Integer;
    procedure SetSelected(AComp: TComponent);
    procedure UpdateCurrent; // set to Fselected
    procedure DisplayCurrent;
    procedure UpdateHistory(ForceAdd: Boolean = False);
  public
    constructor Create(TheOwner: TComponent); override;
    destructor Destroy; override;
  end;

var
  IdeInspectForm: TIdeInspectForm;

resourcestring
  ideinspInspectIDE = 'Inspect IDE';
  ideinspApplicationComponents = 'Application.Components';
  ideinspScreenForms = 'Screen.Forms';
  ideinspQuickLinks = 'Quick links';
  ideinspComponentsOwned = 'Components (Owned)';
  ideinspRemoveSelectedItemSFromTree = 'Remove selected item(s) from tree';
  ideinspControlsChildren = 'Controls (Children)';
  ideinspInspectingNameClass = 'Inspecting %s';
  ideinspIdeInspector = 'Ide Inspector';

procedure Register;

implementation

{$R *.lfm}

const
  MAX_HIST_CNT = 25;
  IDE_INSPECT_CONF_FILE = 'ide_inspector_config.xml';
  ShiftStateNames: Array [TShiftStateEnum] of string =
    ('ssShift', 'ssAlt', 'ssCtrl',
     'ssLeft', 'ssRight', 'ssMiddle', 'ssDouble',
    // Extra additions
    'ssMeta', 'ssSuper', 'ssHyper', 'ssAltGr', 'ssCaps', 'ssNum',
    'ssScroll', 'ssTriple', 'ssQuad', 'ssExtra1', 'ssExtra2');

var
  OriginalBackTraceStrFunc: TBackTraceStrFunc;

type

  { TExtMenuItem }

  TExtMenuItem = class(TMenuItem)
  private
    FTheObject: TPersistent;
  public
    property TheObject: TPersistent read FTheObject write FTheObject;
  end;

{ THistoryEntry }

procedure THistoryEntry.Assign(Other: THistoryEntry);
begin
  Comp := Other.Comp;
  FBaseDisplay := Other.FBaseDisplay;
  Display := Other.Display;
  TheUnitName := Other.TheUnitName;
  IdentifierName := Other.IdentifierName;
  Line := Other.Line;
  FileName := Other.FileName;
end;

procedure THistoryEntry.UpdateDisplayName;
begin
  if Comp <> nil then begin
    FBaseDisplay := Comp.Name + ': ' + Comp.ClassName;
    Display := FBaseDisplay + ' (' + IntToHex(PtrUInt(Comp), SizeOf(Pointer)*2) + ')';
  end else
    Display := FBaseDisplay;
end;

{ TIdeInspectForm }

procedure TIdeInspectForm.MenuItem1Click(Sender: TObject);
begin
  SetSelected(TComponent(TExtMenuItem(Sender).TheObject));
end;

procedure TIdeInspectForm.btnSubComponentClick(Sender: TObject);
begin
  btnSubComponent.CheckMenuDropdown;
end;

procedure TIdeInspectForm.ComboHistoryChange(Sender: TObject);
var
  i: LongInt;
begin
  if FIsUpdatingHistory then exit;
  i := ComboHistory.ItemIndex;
  // ignore current entry re-select
  if i <= 0 then
    exit;
  if ComboHistory.Items.Count > FHistoryList.Count then begin
    ComboHistory.Items.Delete(0); // the none-history curent entry
    dec(i);
  end;
  FCurEntry.Assign(THistoryEntry(FHistoryList[i]));
  if i > 0 then begin
    FHistoryList.Move(i, 0);
    ComboHistory.Items.Move(i, 0);
  end;
  if FCurEntry.Comp <> nil then
    SetSelected(FCurEntry.Comp);
  DisplayCurrent;
end;

procedure TIdeInspectForm.FormClose(Sender: TObject; var CloseAction: TCloseAction);
begin
  FConf.SetDeleteValue('IDEInspect/FormPos/Left', Left, 400);
  FConf.SetDeleteValue('IDEInspect/FormPos/top', Top, 50);
  FConf.SetDeleteValue('IDEInspect/FormPos/Heigh', Height, 520);
  FConf.SetDeleteValue('IDEInspect/FormPos/Width', Width, 500);
  FConf.WriteToDisk;
end;

procedure TIdeInspectForm.FormShow(Sender: TObject);
begin
  Left := FConf.GetValue('IDEInspect/FormPos/Left', 400);
  Top  := FConf.GetValue('IDEInspect/FormPos/top', 50);
  Height := Max(220, FConf.GetValue('IDEInspect/FormPos/Heigh', 520));
  Width  := Max(280, FConf.GetValue('IDEInspect/FormPos/Width', 500));

  //if Screen.MonitorFromPoint(IdeInspectForm.ClientToScreen
  //                           (Point(IdeInspectForm.Left, IdeInspectForm.Top))) = nil
  //then
  MakeFullyVisible;
end;

procedure TIdeInspectForm.DoPropSelChanged(Sender: TObject);
var
  i: LongInt;
  Row: TOIPropertyGridRow;
  Method: TMethod;
  s, s2, OName: string;
  MethName: String;
begin
  Row := FPropertiesGrid.GetActiveRow;
  Method.Code := nil;;
  if (Row <> nil) then begin
    if (Row.Editor is TMethodPropertyEditor) then begin
      Method := TMethodPropertyEditor(Row.Editor).GetMethodValue;
      FPropertiesGrid.PropertyEditorHook.LookupRoot := nil; // prevent edit
    end
    else
      FPropertiesGrid.PropertyEditorHook.LookupRoot := FSelected;
  end;

  if Method.Code = nil then begin
    UpdateCurrent;
    exit;
  end;

  If TObject(Method.Data) is TComponent then
    OName := '('+TComponent(Method.Data).Name+')'
  else
    OName := '';

  MethName := TObject(Method.Data).MethodName(Method.Code);
  s := MethName;;
  if s = '' then
    s := IntToHex(QWord(PtrUint(Method.Code)), 2*SizeOf(Pointer));

  s := TObject(Method.Data).ClassName + OName + '.' + s;

  FCurEntry.Line := -1;
  try
    s2 := Trim(OriginalBackTraceStrFunc(Method.Code));
    i := pos(' ', s2);
    if (s2 <> '') and (s2[1] = '$') and (i > 0) then
      s2 := copy(s2, i, length(s));
    if s2<>'' then
      s := s + '  ' + s2;
    i := PosI('line ', s);
    if i > 0 then begin
      s2 := Trim(copy(s, i+4, length(s2)));
      i := pos(' ', s2)-1;
      if i < 1 then i := length(s2);
      FCurEntry.Line := StrToIntDef(copy(s2, 1, i), -1);
    end;
  except
  end;


  FCurEntry.Display := s;
  FCurEntry.Comp := nil;
  FCurEntry.TheUnitName := GetClassUnitName(TObject(Method.Data).ClassType);
  FCurEntry.FileName := LazarusIDE.FindUnitFile(FCurEntry.TheUnitName, LazarusIDE);
  if MethName <> '' then
    FCurEntry.IdentifierName := TObject(Method.Data).ClassName + '.' + MethName
  else
    FCurEntry.IdentifierName := '';

  UpdateHistory;
end;

procedure TIdeInspectForm.menuFollowFormClick(Sender: TObject);
begin
  FFollowFrames := False;
  ToolButtonActiveType.Caption := menuFollowForm.Caption;
  ToolButtonFollowActive.Down := True;

  FConf.SetDeleteValue('IDEInspect/FollowActive/Type', 0, 0);
  FConf.WriteToDisk;
end;

procedure TIdeInspectForm.menuFollowFrameClick(Sender: TObject);
begin
  FFollowFrames := True;
  ToolButtonActiveType.Caption := menuFollowFrame.Caption;
  ToolButtonFollowActive.Down := True;

  FConf.SetDeleteValue('IDEInspect/FollowActive/Type', 1, 0);
  FConf.WriteToDisk;
end;

procedure TIdeInspectForm.btnControlsClick(Sender: TObject);
begin
  btnControls.CheckMenuDropdown;
end;

procedure TIdeInspectForm.btnEndModalClick(Sender: TObject);
begin
  ModalResult := mrOK;
end;

procedure TIdeInspectForm.btnKeepTopClick(Sender: TObject);
begin
  if btnKeepTop.Down then
    FormStyle := fsStayOnTop
  else
    FormStyle := fsNormal;
  FConf.SetDeleteValue('IDEInspect/FormPos/KeepTop', btnKeepTop.Down, False);
  FConf.WriteToDisk;
end;

procedure TIdeInspectForm.btnOpenFileClick(Sender: TObject);
begin
  if (FCurEntry.IdentifierName <> '') and
     (LazarusIDE.DoOpenFileAndJumpToIdentifier
      (EditFile.Text, FCurEntry.IdentifierName, -1, -1, [ofOnlyIfExists, ofRegularFile])
      = mrOK)
  then
    exit;

  if FCurEntry.Line > 0 then
    LazarusIDE.DoOpenFileAndJumpToPos(EditFile.Text, Point(1,FCurEntry.Line), Max(FCurEntry.Line-1,1), -1, -1, [ofOnlyIfExists, ofRegularFile])
  else
    LazarusIDE.DoOpenEditorFile(EditFile.Text, -1, -1, [ofOnlyIfExists, ofRegularFile]);
end;

procedure TIdeInspectForm.btnSaveHistClick(Sender: TObject);
begin
  UpdateHistory(True);
end;

procedure TIdeInspectForm.btnComponentClick(Sender: TObject);
begin
  btnComponent.CheckMenuDropdown;
end;

procedure TIdeInspectForm.popComponentPopup(Sender: TObject);
var
  m: TExtMenuItem;
  i: Integer;
begin
  popComponent.Items.Clear;

  m := TExtMenuItem.Create(Self);
  m.Caption := ideinspApplicationComponents + ' (' + IntToStr(Application.ComponentCount) + ')' ;
  m.Enabled := False;
  popComponent.Items.Add(m);
  for i := 0 to Application.ComponentCount - 1 do begin
    m := TExtMenuItem.Create(Self);
    m.Caption := Application.Components[i].Name +
                 ' ['+Application.Components[i].ClassName+']'+
                 ' ('+IntToStr(Application.Components[i].ComponentCount)+')';
    m.TheObject := Application.Components[i];
    m.OnClick := @MenuItem1Click;
    popComponent.Items.Add(m);
  end;

  m := TExtMenuItem.Create(Self);
  m.Caption := ideinspScreenForms + ' (' + IntToStr(Screen.FormCount) + ')' ;
  m.Enabled := False;
  popComponent.Items.Add(m);
  for i := 0 to Screen.FormCount - 1 do begin
    m := TExtMenuItem.Create(Self);
    m.Caption := Screen.Forms[i].Name +
                 ' ['+Screen.Forms[i].ClassName+']'+
                 ' ('+IntToStr(Screen.Forms[i].ComponentCount)+')';
    m.TheObject := Screen.Forms[i];
    m.OnClick := @MenuItem1Click;
    popComponent.Items.Add(m);
 end;
end;

procedure TIdeInspectForm.popControlsPopup(Sender: TObject);
var
  i: Integer;
  m: TExtMenuItem;
begin
  popControls.Items.Clear;
  if (FSelected = nil) or not(FSelected is TWinControl) then
    exit;

  for i := 0 to TWinControl(FSelected).ControlCount - 1 do begin
    m := TExtMenuItem.Create(Self);
    m.Caption := TWinControl(FSelected).Controls[i].Name +
                 ' ['+TWinControl(FSelected).Controls[i].ClassName+']'+
                 ' ('+IntToStr(TWinControl(FSelected).Controls[i].ComponentCount)+')';
    m.TheObject := TWinControl(FSelected).Controls[i];
    m.OnClick := @MenuItem1Click;
    popControls.Items.Add(m);
  end;
end;

procedure TIdeInspectForm.popSubComponentPopup(Sender: TObject);
var
  i: Integer;
  m: TExtMenuItem;
begin
  popSubComponent.Items.Clear;

  for i := 0 to FSelected.ComponentCount - 1 do begin
    m := TExtMenuItem.Create(Self);
    m.Caption := FSelected.Components[i].Name +
                 ' ['+FSelected.Components[i].ClassName+']'+
                 ' ('+IntToStr(FSelected.Components[i].ComponentCount)+')';
    m.TheObject := FSelected.Components[i];
    m.OnClick := @MenuItem1Click;
    popSubComponent.Items.Add(m);
  end;
end;

procedure TIdeInspectForm.btnRemoveSelectedClick(Sender: TObject);
var
  CurSel: TTreeNode;
begin
  CurSel:= TreeView1.Selected;
  if CurSel = nil then
    exit;
  if CurSel.Parent <> nil then
    SetSelected(TComponent(TreeView1.Selected.Parent.Data))
  else
    SetSelected(nil);
  CurSel.Delete;
  UpdateTree;
end;

procedure TIdeInspectForm.TabControl1Change(Sender: TObject);
begin
  case TabControl1.TabIndex of
    0: FPropertiesGrid.Filter := [low(TTypeKind)..high(TTypeKind)] - [tkMethod];
    1: FPropertiesGrid.Filter := [tkMethod];
    2: FPropertiesGrid.Filter := [];
  end;
end;

procedure TIdeInspectForm.ToolButtonActiveTypeClick(Sender: TObject);
begin
  ToolButtonActiveType.CheckMenuDropdown;
end;

procedure TIdeInspectForm.ToolButtonFollowActiveClick(Sender: TObject);
begin
  if ToolButtonFollowActive.Down then
    SetSelected(Self);
  FConf.SetDeleteValue('IDEInspect/FollowActive/Enabled', ToolButtonFollowActive.Down, False);
  FConf.WriteToDisk;
end;

procedure TIdeInspectForm.ToolButtonKeyClick(Sender: TObject);
var
  i: TShiftStateEnum;
begin
  FKeyGrabForm.KeyBox.Key := FShortCutKey;
  FKeyGrabForm.KeyBox.ShiftState := FShortCutShift;
  if FKeyGrabForm.ShowModal = mrOK then begin
    FShortCutKey := FKeyGrabForm.KeyBox.Key;
    FShortCutShift := FKeyGrabForm.KeyBox.ShiftState;

    FConf.SetDeleteValue('IDEInspect/KeyShortCut/Key', FShortCutKey, 0);
    for i := low(TShiftStateEnum) to high(TShiftStateEnum) do
      FConf.SetDeleteValue('IDEInspect/KeyShortCut/' + ShiftStateNames[i],
                           i in FShortCutShift, False);
    FConf.WriteToDisk;
  end;
end;

procedure TIdeInspectForm.TreeView1Change(Sender: TObject; Node: TTreeNode);
begin
  TreeView1Click(nil);
end;

procedure TIdeInspectForm.TreeView1Click(Sender: TObject);
begin
  if (TreeView1.Selected = nil) or (TreeView1.Selected.Data = nil) then
    exit;
  SetSelected(TComponent(TreeView1.Selected.Data));
end;

procedure TIdeInspectForm.UpdateTree;
  function FindNode(AComp: TComponent): TTreeNode;
  var
    AParent: TTreeNode;
  begin
    Result := TreeView1.Items.FindNodeWithData(AComp);
    if Result = nil then begin
      if AComp.Owner <> nil then begin
        AParent := FindNode(AComp.Owner);
        Result := AParent.TreeNodes.AddChildObject
          (AParent,
           AComp.Name + ': ' + AComp.ClassName
           + ' ('+IntToStr(AComp.ComponentCount)+')'
             + ' ' + IntToHex(PtrUInt(AComp), 8),
           AComp);
      end else begin
        Result := TreeView1.Items.AddObject
          (nil,
           AComp.Name + ': ' + AComp.ClassName
           + ' ('+IntToStr(AComp.ComponentCount)+')'
           + ' ' + IntToHex(PtrUInt(AComp), 8),
           AComp);
      end;
      AComp.FreeNotification(Self);
    end;
  end;
var
  ANode: TTreeNode;
begin
  if FSelected = nil then begin
    TreeView1.Selected := nil;
    exit;
  end;

  ANode := FindNode(FSelected);
  ANode.Expanded := True;
  ANode.Selected := True;
end;

procedure TIdeInspectForm.Notification(AComponent: TComponent; Operation: TOperation);
var
  ANode: TTreeNode;
  i: Integer;
  f: Boolean;
begin
  if (Operation = opRemove) and (FCurEntry <> nil) and (FCurEntry.Comp = AComponent) then begin
    FCurEntry.Comp := nil;
    FCurEntry.UpdateDisplayName;
    DisplayCurrent;
  end;
  if (Operation = opRemove) and (FHistoryList <> nil) then begin
    f := False;
    for i := 0 to FHistoryList.Count - 1 do
      if THistoryEntry(FHistoryList[i]).Comp = AComponent then begin
        THistoryEntry(FHistoryList[i]).Comp := nil;
        THistoryEntry(FHistoryList[i]).UpdateDisplayName;
        f := True;
      end;
    if f then
      UpdateHistory;
  end;
  if (Operation = opRemove) and (TreeView1 <> nil) then begin
    ANode := TreeView1.Items.FindNodeWithData(AComponent);
    if ANode <> nil then begin
      ANode.DeleteChildren;
      if (AComponent = FSelected) or (TreeView1.Items.FindNodeWithData(FSelected) = nil) then begin
        if ANode.Parent <> nil then
          SetSelected(TComponent(ANode.Parent.Data))
        else
          SetSelected(nil);
      end;
      ANode.Delete;
      UpdateTree;
    end
    else
    if AComponent = FSelected then
      SetSelected(nil);
  end;
  inherited Notification(AComponent, Operation);
end;

procedure TIdeInspectForm.DoActiveFormChanged(Sender: TObject; Form: TCustomForm);
begin
  If (not ToolButtonFollowActive.Down) or (not Self.Visible) then
    exit;

  if Form <> Self then
    SetSelected(Form);
end;

procedure TIdeInspectForm.DoActiveControChanged(Sender: TObject; LastControl: TControl);
begin
  If (not ToolButtonFollowActive.Down) or (not FFollowFrames) or (not Self.Visible) then
    exit;
  if Screen.ActiveForm = Self then
    exit;

  if (Screen.ActiveControl <> nil) and (Screen.ActiveControl.Owner <> nil) then
    SetSelected(Screen.ActiveControl.Owner);
end;

procedure TIdeInspectForm.DoKeyDownBefore(Sender: TObject; var Key: Word; Shift: TShiftState);
var
  CurVisible: Boolean;
begin
  if (Screen.ActiveForm = self) or (Screen.ActiveForm = FKeyGrabForm) then exit;
  if FShortCutKey = 0 then exit;

  if (FShortCutKey <> Key) or (FShortCutShift <> Shift) then
    exit;

  Key := 0;
  if Application.ModalLevel = 0  then begin
    Self.Show;
    exit;
  end;

  CurVisible := Visible;
  Close;
  DestroyHandle;
  btnOpenFile.Visible := False;
  btnSaveHist.Visible := True;
  btnEndModal.Visible := True;
  sepModal.Visible := True;
  sepModal.Left := 1;
  btnEndModal.Left := 1;
  btnRemoveSelected.Left := 2;
  if Self. ShowModal <> mrOK then
    CurVisible := False;
  btnSaveHist.Visible := False;
  btnOpenFile.Visible := True;
  btnEndModal.Visible := False;
  sepModal.Visible := False;
  Visible := CurVisible;
end;

function TIdeInspectForm.IndexOfCurrent: Integer;
begin
  if FCurEntry.Comp = nil then exit(-1);;
  Result := FHistoryList.Count - 1;
  while (Result >= 0) and (THistoryEntry(FHistoryList[Result]).Comp <> FCurEntry.Comp) do
    dec(Result);
end;

procedure TIdeInspectForm.UpdateHistory(ForceAdd: Boolean = False);
var
  i: Integer;
  FNewHist: THistoryEntry;
  CanAdd: Boolean;
begin
  FIsUpdatingHistory := True;
  CanAdd := (FCurEntry.Comp is TCustomForm) or (FCurEntry.Comp is TCustomFrame)
         or ForceAdd;

  i := -1;
  if (FCurEntry.Comp <> nil) and CanAdd then begin
    i := IndexOfCurrent;
    if i < 0 then begin
      FNewHist := THistoryEntry.Create;
      FNewHist.Assign(FCurEntry);
      FHistoryList.Insert(0, FNewHist);
      while FHistoryList.Count > MAX_HIST_CNT do begin
        THistoryEntry(FHistoryList[FHistoryList.Count - 1]).Free;
        FHistoryList.Delete(FHistoryList.Count - 1);
      end;
    end
    else begin
      if i > 0 then
        FHistoryList.Move(i, 0);
    end;
  end;

  ComboHistory.Clear;
  if (FHistoryList.Count = 0) or
     (THistoryEntry(FHistoryList[0]).Display <> FCurEntry.Display)
  then
    ComboHistory.Items.Add(FCurEntry.Display);
  for i := 0 to FHistoryList.Count - 1 do
    ComboHistory.Items.Add(THistoryEntry(FHistoryList[i]).Display);

  FIsUpdatingHistory := False;
  DisplayCurrent;
end;

procedure TIdeInspectForm.SetSelected(AComp: TComponent);
begin
  FSelected := AComp;
  FPropertiesGrid.TIObject := FSelected;
  btnSubComponent.Enabled := (FSelected <> nil) and (FSelected.ComponentCount > 0);
  btnControls.Enabled := (FSelected <> nil) and
                         (FSelected is TWinControl) and (TWinControl(FSelected).ControlCount > 0);
  UpdateTree;

  UpdateCurrent;
end;

procedure TIdeInspectForm.UpdateCurrent;
begin
  // keep date, if the component gets destroyed
  if FCurEntry.Comp <> FSelected then begin
    FCurEntry.Comp := FSelected;
    FCurEntry.UpdateDisplayName;
    if FSelected <> nil then begin
      FCurEntry.TheUnitName := GetClassUnitName(FSelected.ClassType);
      FCurEntry.FileName := LazarusIDE.FindUnitFile(FCurEntry.TheUnitName, LazarusIDE);
      FCurEntry.IdentifierName := FSelected.ClassName;
      FCurEntry.Line := -1;
    end
    else begin
      FCurEntry.TheUnitName := '';
      FCurEntry.FileName := '';
      FCurEntry.IdentifierName := '';
      FCurEntry.Line := -1;
    end;
    UpdateHistory;
  end;
end;

procedure TIdeInspectForm.DisplayCurrent;
begin
  FIsUpdatingHistory := True;
  ComboHistory.Text :=  FCurEntry.Display;
  EditUnit.Text := FCurEntry.TheUnitName;
  EditFile.Text := FCurEntry.FileName;
  if FCurEntry.Comp<> nil then
    Caption := Format(ideinspInspectingNameClass, [FCurEntry.Display])
  else
    Caption := ideinspIdeInspector;
  btnOpenFile.Enabled := EditFile.Text <> '';
  FIsUpdatingHistory := False;

  btnSaveHist.Enabled := (FCurEntry.Comp <> nil) and (IndexOfCurrent < 0);
end;

constructor TIdeInspectForm.Create(TheOwner: TComponent);
var
  i: TShiftStateEnum;
begin
  FKeyGrabForm := TIdeInspectKeyGrabForm.Create(Self);
  FHistoryList := TList.Create;
  FCurEntry := THistoryEntry.Create;
  Screen.AddHandlerActiveFormChanged(@DoActiveFormChanged);
  Screen.AddHandlerActiveControlChanged(@DoActiveControChanged);
  Application.AddOnKeyDownBeforeHandler(@DoKeyDownBefore);
  inherited Create(TheOwner);

  FPropertiesGrid := TCustomPropertiesGrid.Create(Self);
  with FPropertiesGrid do
  begin
    Name := 'FPropertiesGrid';
    Parent := TabControl1;
    Align := alClient;
    SaveOnChangeTIObject := False;
    OnSelectionChange  := @DoPropSelChanged;
  end;

  btnComponent.Caption := ideinspQuickLinks;
  btnSubComponent.Caption := ideinspComponentsOwned;
  btnControls.Caption := ideinspControlsChildren;
  btnRemoveSelected.Hint := ideinspRemoveSelectedItemSFromTree;

  FConf := GetIDEConfigStorage(IDE_INSPECT_CONF_FILE, True);

  FFollowFrames := FConf.GetValue('IDEInspect/FollowActive/Type', 0) > 0;
  if FFollowFrames then
    ToolButtonActiveType.Caption := menuFollowFrame.Caption
  else
    ToolButtonActiveType.Caption := menuFollowForm.Caption;
  TabControl1Change(nil);
  SetSelected(Application);

  FShortCutKey := FConf.GetValue('IDEInspect/KeyShortCut/Key', 0);
  FShortCutShift := [];
  for i := low(TShiftStateEnum) to high(TShiftStateEnum) do
    if FConf.GetValue('IDEInspect/KeyShortCut/' + ShiftStateNames[i], False) then
      FShortCutShift := FShortCutShift + [i];

  btnKeepTop.Down := FConf.GetValue('IDEInspect/FormPos/KeepTop', False);
  ToolButtonFollowActive.Down := FConf.GetValue('IDEInspect/FollowActive/Enabled', False);
end;

destructor TIdeInspectForm.Destroy;
var
  i: Integer;
begin
  FreeAndNil(fConf);
  Application.RemoveOnKeyDownBeforeHandler(@DoKeyDownBefore);
  Screen.RemoveHandlerActiveControlChanged(@DoActiveControChanged);
  Screen.RemoveHandlerActiveFormChanged(@DoActiveFormChanged);
  for i := 0 to FHistoryList.Count - 1 do
    THistoryEntry(FHistoryList[i]).Free;
  FreeAndNil(FHistoryList);
  FreeAndNil(FCurEntry);
  FreeAndNil(TreeView1);
  FreeAndNil(FKeyGrabForm);
  inherited Destroy;
end;

procedure IDEMenuClicked(Sender: TObject);
begin
  IdeInspectForm.Show;
end;

procedure Register;
begin
  IdeInspectForm := TIdeInspectForm.Create(Application);
  RegisterIDEMenuCommand(itmViewIDEInternalsWindows, 'mnuIdeInspector', ideinspInspectIDE, nil,
    @IDEMenuClicked);
end;

initialization
  OriginalBackTraceStrFunc := BackTraceStrFunc;


end.


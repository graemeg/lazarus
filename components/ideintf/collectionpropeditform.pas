unit CollectionPropEditForm;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils,
  // LCL
  LCLType, Forms, Controls, Dialogs, ComCtrls, StdCtrls, ActnList,
  // LazUtils
  LazLoggerBase,
  // IdeIntf
  ObjInspStrConsts, PropEditUtils, IDEImagesIntf, IDEWindowIntf;


type
  { TCollectionPropertyEditorForm }

  TCollectionPropertyEditorForm = class(TForm)
    actAdd: TAction;
    actDel: TAction;
    actMoveUp: TAction;
    actMoveDown: TAction;
    ActionList1: TActionList;
    CollectionListBox: TListBox;
    ToolBar1: TToolBar;
    AddButton: TToolButton;
    DeleteButton: TToolButton;
    DividerToolButton: TToolButton;
    MoveUpButton: TToolButton;
    MoveDownButton: TToolButton;
    procedure actAddExecute(Sender: TObject);
    procedure actDelExecute(Sender: TObject);
    procedure actMoveUpDownExecute(Sender: TObject);
    procedure CollectionListBoxClick(Sender: TObject);
    procedure FormClose(Sender: TObject; var {%H-}CloseAction: TCloseAction);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
  private
    FCollection: TCollection;
    FOwnerPersistent: TPersistent;
    FPropertyName: String;
    procedure FillCollectionListBox;
    procedure ClearSelectionInObjectInspector;
    procedure SelectInObjectInspector(ForceUpdate: Boolean);
    procedure SelectionChanged(NewOwnerPersistent: TPersistent);
    procedure Modified;
  protected
    procedure UpdateCaption;
    procedure PersistentAdded({%H-}APersistent: TPersistent; {%H-}Select: boolean);
    procedure ComponentRenamed(AComponent: TComponent);
    procedure GlobalSetSelection(const ASelection: TPersistentSelectionList);
    procedure PersistentDeleting(APersistent: TPersistent);
    procedure RefreshPropertyValues;
  public
    procedure SetCollection(NewCollection: TCollection;
                    NewOwnerPersistent: TPersistent; const NewPropName: String);
    procedure UpdateButtons;
  public
    property Collection: TCollection read FCollection;
    property OwnerPersistent: TPersistent read FOwnerPersistent;
    property PropertyName: String read FPropertyName;
  end;

implementation

{$R *.lfm}

uses
  PropEdits, FormEditingIntf, ObjectInspector;

type
  TPersistentAccess = class(TPersistent)

  end;

procedure TCollectionPropertyEditorForm.FormCreate(Sender: TObject);
begin
  ToolBar1.Images := IDEImages.Images_16;
  actAdd.Caption := oiColEditAdd;
  actDel.Caption := oiColEditDelete;
  actMoveUp.Caption := oiColEditUp;
  actMoveDown.Caption := oiColEditDown;
  actAdd.ImageIndex := IDEImages.LoadImage('laz_add');
  actDel.ImageIndex := IDEImages.LoadImage('laz_delete');
  actMoveUp.ImageIndex := IDEImages.LoadImage('arrow_up');
  actMoveDown.ImageIndex := IDEImages.LoadImage('arrow_down');
  actMoveUp.ShortCut := scCtrl or VK_UP;
  actMoveDown.ShortCut := scCtrl or VK_DOWN;

  actAdd.Hint := oiColEditAdd;
  actDel.Hint := oiColEditDelete;
  actMoveUp.Hint := oiColEditUp;
  actMoveDown.Hint := oiColEditDown;
  IDEDialogLayoutList.ApplyLayout(Self);
end;

procedure TCollectionPropertyEditorForm.FormClose(Sender: TObject;
  var CloseAction: TCloseAction);
begin
  IDEDialogLayoutList.SaveLayout(Self);
end;

procedure TCollectionPropertyEditorForm.FormDestroy(Sender: TObject);
begin
  if GlobalDesignHook <> nil then
    GlobalDesignHook.RemoveAllHandlersForObject(Self);
end;

procedure TCollectionPropertyEditorForm.CollectionListBoxClick(Sender: TObject);
begin
  UpdateButtons;
  UpdateCaption;
  SelectInObjectInspector(False);
end;

procedure TCollectionPropertyEditorForm.actAddExecute(Sender: TObject);
begin
  if Collection = nil then Exit;
  Collection.Add;

  FillCollectionListBox;
  if CollectionListBox.Items.Count > 0 then
    CollectionListBox.ItemIndex := CollectionListBox.Items.Count - 1;
  SelectInObjectInspector(True);
  UpdateButtons;
  UpdateCaption;
  Modified;
end;

procedure TCollectionPropertyEditorForm.actDelExecute(Sender: TObject);
var
  I : Integer;
  NewItemIndex: Integer;
begin
  if Collection = nil then Exit;

  I := CollectionListBox.ItemIndex;
  if (I >= 0) and (I < Collection.Count) then
  begin
    if MessageDlg(oisConfirmDelete,
      Format(oisDeleteItem, [Collection.Items[I].DisplayName]),
      mtConfirmation, [mbYes, mbNo], 0) = mrYes then
    begin
      // select other item, or unselect
      NewItemIndex := I + 1;
      while (NewItemIndex < CollectionListBox.Items.Count)
      and (CollectionListBox.Selected[NewItemIndex]) do Inc(NewItemIndex);

      if NewItemIndex = CollectionListBox.Items.Count then
      begin
        NewItemIndex := 0;
        while (NewItemIndex < Pred(I))
        and not (CollectionListBox.Selected[NewItemIndex]) do Inc(NewItemIndex);

        if NewItemIndex = I then NewItemIndex := -1;
      end;

      CollectionListBox.ItemIndex := -1;

      if NewItemIndex > I then Dec(NewItemIndex);
      //debugln('TCollectionPropertyEditorForm.DeleteClick A NewItemIndex=',dbgs(NewItemIndex),' ItemIndex=',dbgs(CollectionListBox.ItemIndex),' CollectionListBox.Items.Count=',dbgs(CollectionListBox.Items.Count),' Collection.Count=',dbgs(Collection.Count));
      // unselect all items in OI (collections can act strange on delete)
      ClearSelectionInObjectInspector;
      // now delete
      Collection.Items[I].Free;
      // update listbox after whatever happened
      FillCollectionListBox;
      // set NewItemIndex
      if NewItemIndex < CollectionListBox.Items.Count then
      begin
        CollectionListBox.ItemIndex := NewItemIndex;
        SelectInObjectInspector(False);
      end;
      //debugln('TCollectionPropertyEditorForm.DeleteClick B');
      Modified;
    end;
  end;
  UpdateButtons;
  UpdateCaption;
end;

procedure TCollectionPropertyEditorForm.actMoveUpDownExecute(Sender: TObject);
var
  I, Direction: Integer;
begin
  if Collection = nil then Exit;
  I := CollectionListBox.ItemIndex;

  if TComponent(Sender).Name = 'actMoveUp' then
  begin
    Direction := -1;
    Assert(I > 0, 'TCollectionPropertyEditorForm.actMoveUpDownExecute: wrong index.');
  end
  else begin
    Direction := 1;
    Assert(I < Collection.Count-1, 'TCollectionPropertyEditorForm.actMoveUpDownExecute: wrong index.');
  end;

  Collection.Items[I].Index := I + Direction;

  CollectionListBox.Items.Move(I + Direction, I);
  CollectionListBox.ItemIndex := I + Direction;

  FillCollectionListBox;
  SelectInObjectInspector(False);
  Modified;
end;

procedure TCollectionPropertyEditorForm.UpdateCaption;
var
  NewCaption: String;
begin
  //I think to match Delphi this should be formatted like
  //"Editing ComponentName.PropertyName[Index]"
  if OwnerPersistent is TComponent then
    NewCaption := TComponent(OwnerPersistent).Name
  else
    if OwnerPersistent <> nil then
      NewCaption := OwnerPersistent.GetNamePath
    else
      NewCaption := '';

  if NewCaption <> '' then
    NewCaption := NewCaption + '.';
  NewCaption := oiColEditEditing + ' ' + NewCaption + PropertyName;

  if CollectionListBox.ItemIndex > -1 then
    NewCaption := NewCaption + '[' + IntToStr(CollectionListBox.ItemIndex) + ']';
  Caption := NewCaption;
end;

procedure TCollectionPropertyEditorForm.UpdateButtons;
var
  I: Integer;
begin
  I := CollectionListBox.ItemIndex;
  actAdd.Enabled := (Collection <> nil) and actAdd.Visible;
  actDel.Enabled := (I > -1) and actDel.Visible;
  actMoveUp.Enabled := I > 0;
  actMoveDown.Enabled := (I >= 0) and (I < CollectionListBox.Items.Count - 1);
end;

procedure TCollectionPropertyEditorForm.PersistentAdded(APersistent: TPersistent; Select: boolean);
begin
  //DebugLn('*** TCollectionPropertyEditorForm.PersistentAdded called ***');
  FillCollectionListBox;
end;

procedure TCollectionPropertyEditorForm.ComponentRenamed(AComponent: TComponent);
begin
  //DebugLn('*** TCollectionPropertyEditorForm.ComponentRenamed called ***');
  if AComponent = OwnerPersistent then
    UpdateCaption;
end;

procedure TCollectionPropertyEditorForm.GlobalSetSelection(const ASelection: TPersistentSelectionList);
begin
  // When a control of the same class is changed in OI or Designer, the properties
  // of the current control has to be shown. See issue #38910
  if not Visible then Exit;
  if not Assigned(ASelection) then Exit;
  if ASelection.Count = 0 then Exit;
  if ASelection[0] = OwnerPersistent then Exit;
  if ASelection[0].ClassType <> OwnerPersistent.ClassType then Exit;
  SelectionChanged(ASelection[0]);
end;

procedure TCollectionPropertyEditorForm.PersistentDeleting(APersistent: TPersistent);
begin
  // For some reason this is called only when the whole collection is deleted,
  // for example when changing to another project. Thus clear the whole collection.
  DebugLn(['TCollectionPropertyEditorForm.PersistentDeleting: APersistent=', APersistent,
           ', OwnerPersistent=', OwnerPersistent]);
  SetCollection(nil, nil, '');
  Hide;
  UpdateButtons;
  UpdateCaption;
end;

procedure TCollectionPropertyEditorForm.RefreshPropertyValues;
begin
  FillCollectionListBox;
  //DebugLn('*** TCollectionPropertyEditorForm.RefreshPropertyValues called ***');
end;

procedure TCollectionPropertyEditorForm.FillCollectionListBox;
var
  I: Integer;
  CurItem: String;
  Cnt: Integer;
begin
  CollectionListBox.Items.BeginUpdate;
  try
    if Collection <> nil then
      Cnt := Collection.Count
    else
      Cnt := 0;

    // add or replace list items
    for I := 0 to Cnt - 1 do
    begin
      CurItem := IntToStr(I) + ' - ' + Collection.Items[I].DisplayName;
      if I >= CollectionListBox.Items.Count then
        CollectionListBox.Items.Add(CurItem)
      else
        CollectionListBox.Items[I] := CurItem;
    end;

    // delete unneeded list items
    if Cnt > 0 then
    begin
      while CollectionListBox.Items.Count > Cnt do
        CollectionListBox.Items.Delete(CollectionListBox.Items.Count - 1);
    end
    else
      CollectionListBox.Items.Clear;
  finally
    CollectionListBox.Items.EndUpdate;
    UpdateButtons;
    UpdateCaption;
  end;
end;

procedure TCollectionPropertyEditorForm.ClearSelectionInObjectInspector;
var
  NewSelection: TPersistentSelectionList;
begin
  if GlobalDesignHook = nil then Exit;
  // select in OI
  NewSelection := TPersistentSelectionList.Create;
  NewSelection.ForceUpdate := True;
  try
    GlobalDesignHook.SetSelection(NewSelection);
    GlobalDesignHook.LookupRoot := GetLookupRootForComponent(OwnerPersistent);
  finally
    NewSelection.Free;
  end;
end;

procedure TCollectionPropertyEditorForm.SelectInObjectInspector(ForceUpdate: Boolean);
var
  I: Integer;
  NewSelection: TPersistentSelectionList;
begin
  if (Collection = nil) or (GlobalDesignHook = nil) then Exit;
  // select in OI
  NewSelection := TPersistentSelectionList.Create;
  NewSelection.ForceUpdate := ForceUpdate;
  try
    for I := 0 to CollectionListBox.Items.Count - 1 do
      if CollectionListBox.Selected[I] then
        NewSelection.Add(Collection.Items[I]);
    GlobalDesignHook.SetSelection(NewSelection);
    GlobalDesignHook.LookupRoot := GetLookupRootForComponent(OwnerPersistent);
  finally
    NewSelection.Free;
  end;
end;

procedure TCollectionPropertyEditorForm.SelectionChanged(NewOwnerPersistent: TPersistent);
var
  AGrid: TOICustomPropertyGrid;
  AEditor: TPropertyEditor;
  NewCollection: TCollection;
begin
//  DebugLn('TCollectionPropertyEditorForm.SelectionChanged Old: ', DbgSName(OwnerPersistent), ' New: ', DbgSName(NewOwnerPersistent));
  AGrid := FormEditingHook.GetCurrentObjectInspector.GridControl[oipgpProperties];
  AEditor := AGrid.PropertyEditorByName(PropertyName);
  if not Assigned(AEditor) then Exit;
  NewCollection := TCollection(AEditor.GetObjectValue);
  if NewCollection = nil then
    raise Exception.Create('NewCollection=nil');
  SetCollection(NewCollection, NewOwnerPersistent, PropertyName);
end;

procedure TCollectionPropertyEditorForm.SetCollection(NewCollection: TCollection;
  NewOwnerPersistent: TPersistent; const NewPropName: String);
begin
  if (FCollection = NewCollection) and (FOwnerPersistent = NewOwnerPersistent)
    and (FPropertyName = NewPropName) then Exit;

  FCollection := NewCollection;
  FOwnerPersistent := NewOwnerPersistent;
  FPropertyName := NewPropName;
  //debugln('TCollectionPropertyEditorForm.SetCollection A Collection=',dbgsName(FCollection),
  //        ' OwnerPersistent=',dbgsName(OwnerPersistent),' PropName=',PropertyName);
  if GlobalDesignHook <> nil then
  begin
    GlobalDesignHook.RemoveAllHandlersForObject(Self);
    if FOwnerPersistent <> nil then
    begin
      GlobalDesignHook.AddHandlerPersistentAdded(@PersistentAdded);
      GlobalDesignHook.AddHandlerComponentRenamed(@ComponentRenamed);
      GlobalDesignHook.AddHandlerPersistentDeleting(@PersistentDeleting);
      GlobalDesignHook.AddHandlerRefreshPropertyValues(@RefreshPropertyValues);
      GlobalDesignHook.AddHandlerSetSelection(@GlobalSetSelection);
    end;
  end;

  FillCollectionListBox;
  CollectionListBox.ItemIndex := -1;  // Some widgetsets select the last item.
  UpdateCaption;
end;

procedure TCollectionPropertyEditorForm.Modified;
begin
  //debugln(['TCollectionPropertyEditorForm.Modified FOwnerPersistent=',DbgSName(FOwnerPersistent),
  //  ' FCollection=',DbgSName(FCollection),' GlobalDesignHook.LookupRoot=',DbgSName(GlobalDesignHook.LookupRoot)]);
  if GlobalDesignHook <> nil then
    GlobalDesignHook.Modified(Self);
end;

end.


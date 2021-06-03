{%MainUnit ../stdctrls.pp}
{
 *****************************************************************************
  This file is part of the Lazarus Component Library (LCL)

  See the file COPYING.modifiedLGPL.txt, included in this distribution,
  for details about the license.
 *****************************************************************************
}
{ if not HandleAllocated then
    FItems contains a TExtendedStringList
  else
    FItems contains an interface specific TStrings descendent
}

type
  TCustomListBoxItemRecord = record
    TheObject: TObject;
    Selected: Boolean;
  end;
  PCustomListBoxItemRecord = ^TCustomListBoxItemRecord;

{------------------------------------------------------------------------------
 procedure TCustomListBox.AssignCacheToItemData
------------------------------------------------------------------------------}
procedure TCustomListBox.AssignCacheToItemData(const AIndex: Integer;
  const AData: Pointer);
var
  SelectedItem: Boolean;
begin
  if MultiSelect then
    SelectedItem := PCustomListBoxItemRecord(AData)^.Selected
  else
    SelectedItem := FItemIndex = AIndex;
  if SelectedItem then
  begin
    LockSelectionChange;
    SendItemSelected(AIndex, True);
    UnlockSelectionChange;
  end;
end;

procedure TCustomListBox.BeforeDragStart;
begin
  if HandleAllocated then
    TWSCustomListBoxClass(WidgetSetClass).DragStart(Self);
end;

procedure TCustomListBox.BeginAutoDrag;
begin
  BeginDrag(False);
end;

function TCustomListBox.CalculateStandardItemHeight: Integer;
var
  B: TBitmap;
begin
  // Paul: This will happen only once if Style = lbStandard then CheckListBox is
  // OwnerDrawFixed in real (under windows). Handle is not allocated and we
  // can not use Canvas since it will cause recursion but we need correct font height
  B := TBitmap.Create;
  try
    B.Canvas.Font := Font;
    Result := B.Canvas.TextHeight('Fj');
  finally
    B.Free;
  end;
end;

procedure TCustomListBox.CreateParams(var Params: TCreateParams);
const
  MultiSelectStyle: array[Boolean] of DWord = (LBS_MULTIPLESEL, LBS_EXTENDEDSEL);
begin
  inherited CreateParams(Params);
  if Sorted then
    Params.Style := Params.Style or LBS_SORT;
  if MultiSelect then
    Params.Style := Params.Style or MultiSelectStyle[ExtendedSelect];
  if Columns > 1 then
    Params.Style := Params.Style or LBS_MULTICOLUMN;

  case Style of
    lbOwnerDrawFixed: Params.Style := Params.Style or LBS_OWNERDRAWFIXED;
    lbOwnerDrawVariable: Params.Style := Params.Style or LBS_OWNERDRAWVARIABLE;
  end;
  Params.Style := Params.Style or
    (WS_HSCROLL or WS_VSCROLL or LBS_NOINTEGRALHEIGHT or LBS_HASSTRINGS or LBS_NOTIFY);
end;

{------------------------------------------------------------------------------
 procedure TCustomListBox.AssignItemDataToCache
------------------------------------------------------------------------------}
procedure TCustomListBox.AssignItemDataToCache(const AIndex: Integer;
  const AData: Pointer);
begin
  PCustomListBoxItemRecord(AData)^.Selected := Selected[AIndex];
end;

procedure TCustomListBox.ClearSelectedCache;
var
  i: Integer;
  CacheItems: TExtendedStringList;
begin
  if not FCacheValid then
    raise EInvalidOperation.Create('Cache is not valid.');
  CacheItems := FItems as TExtendedStringList;
  for i := 0 to CacheItems.Count - 1 do
    PCustomListBoxItemRecord(CacheItems.Records[i])^.Selected := False;
end;

procedure TCustomListBox.SetSelectedCache(Index: Integer; IsSelected: Boolean);
var
  CacheItems: TExtendedStringList;
begin
  if not FCacheValid then
    raise EInvalidOperation.Create('Cache is not valid.');
  CacheItems := FItems as TExtendedStringList;
  PCustomListBoxItemRecord(CacheItems.Records[Index])^.Selected := IsSelected;
end;

function TCustomListBox.GetSelectedCache(Index: Integer): Boolean;
var
  CacheItems: TExtendedStringList;
begin
  if not FCacheValid then
    raise EInvalidOperation.Create('Cache is not valid.');
  CacheItems := FItems as TExtendedStringList;
  Result := PCustomListBoxItemRecord(CacheItems.Records[Index])^.Selected;
end;

{------------------------------------------------------------------------------
 procedure TCustomListBox.InitializeWnd
------------------------------------------------------------------------------}
procedure TCustomListBox.InitializeWnd;
var
  NewStrings: TStrings;
  OldItems: TExtendedStringList;
  i: integer;
begin
  LockSelectionChange;
  inherited InitializeWnd;
  // fetch the interface item list
  NewStrings := TWSCustomListBoxClass(WidgetSetClass).GetStrings(Self);
  // copy the items (text+objects)
  OldItems := FItems as TExtendedStringList;

  OldItems.Sorted := False;// make sure the items are not reordered (needed for ItemIndex and attributes)
  NewStrings.Assign(FItems);

  // new item list is the interface item list
  FItems := NewStrings;
  FCacheValid := False;

  // don't reset item index without a need - on windows this may cause an undesired selection of
  // item for multiselect listbox
  if FItemIndex <> TWSCustomListBoxClass(WidgetSetClass).GetItemIndex(Self) then
    SendItemIndex;

  // copy items attributes
  for i := 0 to OldItems.Count - 1 do
    AssignCacheToItemData(i, OldItems.Records[i]);
  // free old items
  OldItems.Free;
  TWSCustomListBoxClass(WidgetSetClass).SetSorted(Self, FItems, FSorted);
  TWSCustomListBoxClass(WidgetSetClass).SetScrollWidth(Self, FScrollWidth);
  UnlockSelectionChange;
end;

procedure TCustomListBox.DestroyWnd;
begin
  inherited;
  if FCanvas <> nil then
    TControlCanvas(FCanvas).FreeHandle;
end;

{------------------------------------------------------------------------------
 procedure TCustomListBox.FinalizeWnd
------------------------------------------------------------------------------}
procedure TCustomListBox.FinalizeWnd;
var
  NewStrings: TExtendedStringList;
  i: integer;
begin
  LockSelectionChange;

  // save ItemIndex on destroy handle
  if ([csDestroying,csLoading]*ComponentState=[]) then
    GetItemIndex;
  // create internal item list
  if Assigned(FItems) then
  begin
    NewStrings := TExtendedStringList.Create(GetCachedDataSize);

    // copy items (text+objects) from the interface items list
    NewStrings.Assign(Items);
    // copy items attributes
    for i:=0 to Items.Count-1 do
      AssignItemDataToCache(i, NewStrings.Records[i]);

    // free the interface items list
    TWSCustomListBoxClass(WidgetSetClass).FreeStrings(FItems);
    // new item list is the internal item list
    NewStrings.Sorted:=FSorted;
    FItems:= NewStrings;
    FCacheValid := True;
  end;
  inherited FinalizeWnd;
  UnlockSelectionChange;
end;

class function TCustomListBox.GetControlClassDefaultSize: TSize;
begin
  Result.CX := 100;
  Result.CY := 80;
end;

{------------------------------------------------------------------------------
 procedure TCustomListBox.UpdateSelectionMode
------------------------------------------------------------------------------}
procedure TCustomListBox.UpdateSelectionMode;
begin
  if not HandleAllocated then exit;
  LockSelectionChange;
  TWSCustomListBoxClass(WidgetSetClass).SetSelectionMode(Self, 
    ExtendedSelect, MultiSelect);
  UnlockSelectionChange;
end;

{------------------------------------------------------------------------------
  function TCustomListBox.GetTopIndex: Integer;
------------------------------------------------------------------------------}
function TCustomListBox.GetTopIndex: Integer;
begin
  if HandleAllocated then
    FTopIndex := TWSCustomListBoxClass(WidgetSetClass).GetTopIndex(Self);
  Result := FTopIndex;
end;

procedure TCustomListBox.RaiseIndexOutOfBounds(AIndex: integer);
begin
  raise Exception.CreateFmt(rsIndexOutOfBounds, [ClassName, AIndex, FItems.Count-1]);
end;

procedure TCustomListBox.SetColumns(const AValue: Integer);
begin
  if (FColumns = AValue) or (AValue < 0) then
    Exit;
  FColumns := AValue;
  if HandleAllocated then
    TWSCustomListBoxClass(WidgetSetClass).SetColumnCount(Self, FColumns);
end;

procedure TCustomListBox.SetScrollWidth(const AValue: Integer);
begin
  FScrollWidth := AValue;
  if HandleAllocated then
    TWSCustomListBoxClass(WidgetSetClass).SetScrollWidth(Self, FScrollWidth);
end;

{------------------------------------------------------------------------------
  function TCustomListBox.GetCount: Integer;
------------------------------------------------------------------------------}
function TCustomListBox.GetCount: Integer;
begin
  Result := Items.Count;
end;

function TCustomListBox.GetScrollWidth: Integer;
begin
  Result := FScrollWidth;
  if (Result > 0) or (csDesigning in ComponentState) then Exit;
  if HandleAllocated then
    Result := TWSCustomListBoxClass(WidgetSetClass).GetScrollWidth(Self);
end;

{------------------------------------------------------------------------------
  procedure TCustomListBox.SetTopIndex(const AValue: Integer);
------------------------------------------------------------------------------}
procedure TCustomListBox.SetTopIndex(const AValue: Integer);
begin
  // don't check if changed. If the item is only partly visible, the message
  // will make it complete visible.
  FTopIndex := AValue;
  if HandleAllocated and ([csLoading,csDestroying]*ComponentState=[]) then
    TWSCustomListBoxClass(WidgetSetClass).SetTopIndex(Self, AValue);
end;

{------------------------------------------------------------------------------
  procedure TCustomListBox.UpdateSorted;
------------------------------------------------------------------------------}
procedure TCustomListBox.UpdateSorted;
begin
  if HandleAllocated then
  begin
    LockSelectionChange;
    TWSCustomListBoxClass(WidgetSetClass).SetSorted(Self, FItems, FSorted);
    UnlockSelectionChange;
  end
  else
    TExtendedStringList(FItems).Sorted := FSorted;
end;

{------------------------------------------------------------------------------
  procedure TCustomListBox.LMDrawListItem(var TheMessage: TLMDrawListItem);

  Handler for custom drawing items.
 ------------------------------------------------------------------------------}
procedure TCustomListBox.LMDrawListItem(var TheMessage: TLMDrawListItem);
begin
  with TheMessage.DrawListItemStruct^ do
  begin
    FCanvas.Handle := DC;
    if Assigned(Font) then
    begin
      FCanvas.Font := Font;
      FCanvas.Font.PixelsPerInch := Font.PixelsPerInch;
    end;
    if Assigned(Brush) then
      FCanvas.Brush := Brush;
    if (ItemID <> UINT(-1)) and (odSelected in ItemState) then
    begin
      FCanvas.Brush.Color := clHighlight;
      FCanvas.Font.Color := clHighlightText
    end else
    begin
      FCanvas.Brush.Color := GetColorResolvingParent;
      FCanvas.Font.Color := clWindowText;
    end;
    DrawItem(ItemID, Area, ItemState);
    if (odFocused in ItemState) and (lboDrawFocusRect in FOptions) then
      DrawFocusRect(DC, Area);
    FCanvas.Handle := 0;
  end;
end;

procedure TCustomListBox.LMMeasureItem(var TheMessage: TLMMeasureItem);
var
  AHeight: Integer;
begin
  with TheMessage.MeasureItemStruct^ do 
  begin
    if Self.ItemHeight <> 0 then
      AHeight := Self.ItemHeight
    else begin
      Canvas.Font := Font;
      AHeight := Canvas.TextHeight('Hg');
    end;
    MeasureItem(Integer(ItemId), AHeight);
    if AHeight > 0 then
      ItemHeight := AHeight;
  end;
end;

{------------------------------------------------------------------------------
  procedure TCustomListBox.LMSelChange(var TheMessage);
------------------------------------------------------------------------------}
procedure TCustomListBox.LMSelChange(var TheMessage);
begin
  if [csLoading,csDestroying,csDesigning]*ComponentState<>[] then exit;
  DoSelectionChange(FLockSelectionChange = 0);
end;

procedure TCustomListBox.WMLButtonUp(var Message: TLMLButtonUp);
begin
  // prevent Click to be called twice when using selchange as click
  if ClickOnSelChange and FClickTriggeredBySelectionChange then
    Exclude(FControlState, csClicked);
  inherited WMLButtonUp(Message);
  // reset flag
  FClickTriggeredBySelectionChange := False;
end;

{------------------------------------------------------------------------------
  procedure TCustomListBox.SendItemSelected(Index: integer; IsSelected: boolean);

  Tell the interface whether an item is selected.
------------------------------------------------------------------------------}
procedure TCustomListBox.SendItemSelected(Index: integer; IsSelected: boolean);
begin
  if HandleAllocated then
    TWSCustomListBoxClass(WidgetSetClass).SelectItem(Self, Index, IsSelected);
end;

class procedure TCustomListBox.WSRegisterClass;
begin
  inherited WSRegisterClass;
  RegisterCustomListBox;
end;

{------------------------------------------------------------------------------}
{ procedure TCustomListBox.SetExtendedSelect                                   }
{------------------------------------------------------------------------------}
procedure TCustomListBox.SetExtendedSelect(Val: boolean);
begin
  if Val <> FExtendedSelect then
  begin
    FExtendedSelect:= Val;
    UpdateSelectionMode;
  end;
end;

{------------------------------------------------------------------------------}
{ procedure TCustomListBox.SetMultiSelect                                      }
{------------------------------------------------------------------------------}
procedure TCustomListBox.SetMultiSelect(Val: boolean);
begin
  if Val <> FMultiSelect then
  begin
    FMultiSelect := Val;
    UpdateSelectionMode;
  end;
end;

{------------------------------------------------------------------------------}
{ procedure TCustomListBox.SetSelected                                         }
{------------------------------------------------------------------------------}
procedure TCustomListBox.SetSelected(Index: integer; Val: boolean);
begin
  CheckIndex(Index);

  if not MultiSelect then
  begin
    if Val then
      ItemIndex := Index
    else
    if Index = ItemIndex then
      ItemIndex := -1;
  end else
  begin
    if HandleAllocated then
      SendItemSelected(Index, Val)
    else
      SetSelectedCache(Index, Val);
  end;
end;

{------------------------------------------------------------------------------}
{ function TCustomListBox.GetSelected                                          }
{------------------------------------------------------------------------------}
function TCustomListBox.GetSelected(Index: integer): boolean;
begin
  CheckIndex(Index);
  if HandleAllocated then
    Result := TWSCustomListBoxClass(WidgetSetClass).GetSelected(Self, Index)
  else
    Result := GetSelectedCache(Index);
end;

{------------------------------------------------------------------------------}
{ function TCustomListBox.GetSelCount                                          }
{------------------------------------------------------------------------------}
function TCustomListBox.GetSelCount: integer;
begin
  if HandleAllocated then
    Result := TWSCustomListBoxClass(WidgetSetClass).GetSelCount(Self)
  else
    Result := 0;
end;

function TCustomListBox.GetItemHeight: Integer;
begin
  if HandleAllocated and (Style = lbStandard) then
  begin
    with ItemRect(TopIndex) do
      Result := Bottom - Top;
  end
  else
    Result := FItemHeight;
end;

procedure TCustomListBox.SetItemHeight(Value: Integer);
begin
  if (FItemHeight <> Value) and (Value >= 0) then
  begin
    FItemHeight := Value;
    if (not HandleAllocated) or (csLoading in ComponentState) then exit;
    // TODO: remove RecreateWnd
    RecreateWnd(Self);
  end;
end;

{------------------------------------------------------------------------------}
{ procedure TCustomListBox.SetSorted                                          }
{------------------------------------------------------------------------------}
procedure TCustomListBox.SetSorted(Val: boolean);
begin
  if Val <> FSorted then
  begin
    FSorted:= Val;
    UpdateSorted;
  end;
end;

{------------------------------------------------------------------------------
  procedure TCustomListBox.SetStyle
------------------------------------------------------------------------------}
procedure TCustomListBox.SetStyle(Val: TListBoxStyle);
begin
  if Val <> FStyle then
  begin
    FStyle:= Val;
    if HandleAllocated then
      TWSCustomListBoxClass(WidgetSetClass).SetStyle(Self);
  end;
end;

procedure TCustomListBox.DrawItem(Index: Integer; ARect: TRect;
  State: TOwnerDrawState);
begin
  if Assigned(FOnDrawItem) then
    FOnDrawItem(Self, Index, ARect, State)
  else
  begin
    if not(odBackgroundPainted in State) then
      FCanvas.FillRect(ARect);
    if (Index>=0) and (Index < Items.Count) then
      InternalDrawItem(Self, FCanvas, ARect, Items[Index]);
  end;
end;

procedure TCustomListBox.DoAutoAdjustLayout(
  const AMode: TLayoutAdjustmentPolicy; const AXProportion, AYProportion: Double
  );
begin
  inherited;

  if AMode in [lapAutoAdjustWithoutHorizontalScrolling, lapAutoAdjustForDPI] then
  begin
    if FItemHeight > 0 then
      ItemHeight := Round(ItemHeight * AYProportion);
  end;
end;

procedure TCustomListBox.DoSelectionChange(User: Boolean);
begin
  if Assigned(OnSelectionChange) then
    OnSelectionChange(Self, User);
  if User and ClickOnSelChange then
  begin
    Click;
    // set flag, that we triggered a Click, so that a possible MouseClick will
    // not trigger it again
    FClickTriggeredBySelectionChange := True;
  end;
end;

procedure TCustomListBox.SendItemIndex;
begin
  TWSCustomListBoxClass(WidgetSetClass).SetItemIndex(Self, FItemIndex);
end;

procedure TCustomListBox.WMGetDlgCode(var Message: TLMNoParams);
begin
  inherited;
  Message.Result := Message.Result or DLGC_WANTARROWS;
end;

{------------------------------------------------------------------------------
  function TCustomListBox.GetCachedData
------------------------------------------------------------------------------}
function TCustomListBox.GetCachedData(const AIndex: Integer): Pointer;
begin
  if not FCacheValid then
    raise EInvalidOperation.Create('Reading form invalid cache');
  Result := TExtendedStringList(FItems).Records[AIndex];
end;

{------------------------------------------------------------------------------
  function TCustomListBox.GetCachedDataSize

  Returns the amount of data needed when the widged isn't realized in the
  interface
------------------------------------------------------------------------------}
function TCustomListBox.GetCachedDataSize: Integer;
begin
  Result := SizeOf(TCustomListBoxItemRecord);
end;

{------------------------------------------------------------------------------
  function TCustomListBox.SetItems
------------------------------------------------------------------------------}
procedure TCustomListBox.SetItems(Value: TStrings);
begin
  if (Value <> FItems) then
  begin
    LockSelectionChange;
    FItems.Assign(Value);
    UnlockSelectionChange;
  end;
end;

{------------------------------------------------------------------------------
  function TCustomListBox.Create
------------------------------------------------------------------------------}
constructor TCustomListBox.Create(TheOwner: TComponent);
begin
  inherited Create(TheOwner);
  fCompStyle := csListBox;
  BorderStyle:= bsSingle;
  FItems := TExtendedStringList.Create(GetCachedDataSize);
  FCacheValid := True;
  FClickOnSelChange:= True;
  FItemIndex:=-1;
  FExtendedSelect := true;
  //FScrollWidth := 0;
  FOptions := DefOptions;
  FCanvas := TControlCanvas.Create;
  TControlCanvas(FCanvas).Control := Self;
  ParentColor := false;
  TabStop := true;
  with GetControlClassDefaultSize do
    SetInitialBounds(0, 0, CX, CY);
end;

{------------------------------------------------------------------------------
  function TCustomListBox.Destroy
------------------------------------------------------------------------------}
destructor TCustomListBox.Destroy;
begin
  FreeAndNil(FCanvas);
  FreeAndNil(FItems);
  inherited Destroy;
end;

procedure TCustomListBox.AddItem(const Item: String; AnObject: TObject);
begin
  Items.AddObject(Item, AnObject);
end;

function TCustomListBox.GetItemIndex: integer;
begin
  if HandleAllocated then
  begin
    Result := TWSCustomListBoxClass(WidgetSetClass).GetItemIndex(Self);
    if (Result < 0) or (Result >= Count) then
      Result := -1;
    FItemIndex := Result;
  end
  else
    Result := FItemIndex;
end;

procedure TCustomListBox.SetItemIndex(AIndex: integer);
begin
  if AIndex=GetItemIndex then
    exit;
  if (AIndex >= FItems.Count) then
    RaiseIndexOutOfBounds(AIndex);
  if AIndex < 0 then AIndex := -1;
  FItemIndex := AIndex;
  if HandleAllocated then
  begin
    if ([csLoading,csDestroying]*ComponentState=[]) then
      SendItemIndex;
  end
  else
  begin
    ClearSelectedCache;
    if FItemIndex >= 0 then
      SetSelectedCache(FItemIndex, True);
  end;
  DoSelectionChange(false);
end;

{------------------------------------------------------------------------------
  procedure TCustomListBox.CheckIndex
------------------------------------------------------------------------------}
procedure TCustomListBox.CheckIndex(const AIndex: Integer);
begin
  if (AIndex < 0) or (AIndex >= Items.Count) then
    RaiseIndexOutOfBounds(AIndex);
end;

{------------------------------------------------------------------------------
  procedure TCustomListBox.Clear

  Delete all items.
------------------------------------------------------------------------------}
procedure TCustomListBox.Clear;
begin
  FItems.Clear;
  FItemIndex := -1;
end;

procedure TCustomListBox.ClearSelection;
var
  i: integer;
begin
  if MultiSelect then
    for i := 0 to Items.Count - 1 do
      Selected[i] := False
  else
    ItemIndex := -1; // no need to traverse all items - look at SetSelected
end;

procedure TCustomListBox.LockSelectionChange;
begin
  inc(FLockSelectionChange);
end;

procedure TCustomListBox.UnlockSelectionChange;
begin
  dec(FLockSelectionChange);
end;

procedure TCustomListBox.Click;
begin
  inherited Click;
  Changed;
end;

{------------------------------------------------------------------------------
  procedure TCustomListBox.MeasureItem(Index: Integer; var TheHeight: Integer);

 ------------------------------------------------------------------------------}
procedure TCustomListBox.MeasureItem(Index: Integer; var TheHeight: Integer);
begin
  if Assigned(OnMeasureItem) then
    OnMeasureItem(Self, Index, TheHeight);
end;

procedure TCustomListBox.SelectAll;
var
  i: Integer;
begin
  if (Count=0) then
    Exit;
  SelectRange(0, Count-1, True);
end;

procedure TCustomListBox.SelectRange(ALow, AHigh: integer; ASelected: boolean);
var
  i: Integer;
begin
  if (ALow<0) or (AHigh>=Items.Count) then Exit;
  if MultiSelect then
  begin
    TWSCustomListBoxClass(WidgetSetClass).SelectRange(Self, ALow, AHigh, ASelected);
    DoSelectionChange(false);
  end
  else
  begin
    i := ItemIndex;
    if (i>=ALow) and (i<=AHigh) then
      Selected[i] := ASelected;
  end;
end;

procedure TCustomListBox.DeleteSelected;
var
  i: Integer;
begin
  if MultiSelect then
  begin
    i := Items.Count;
    while i > 0 do
    begin
      dec(i);
      if Selected[i] then
        FItems.Delete(i);
    end;
  end else
    if ItemIndex>=0 then
      Items.Delete(ItemIndex);
end;

{------------------------------------------------------------------------------
  function TCustomListBox.GetIndexAtXY(X, Y: integer): integer;

  Returns item index at x, y coordinate (including scrolling)
------------------------------------------------------------------------------}
function TCustomListBox.GetIndexAtXY(X, Y: integer): integer;
begin
  Result := -1;
  if (not HandleAllocated) then Exit;
  Result := TWSCustomListBoxClass(WidgetSetClass).GetIndexAtXY(Self, X, Y);
end;

function TCustomListBox.GetIndexAtY(Y: integer): integer;
begin
  Result := GetIndexAtXY(1, Y);
end;

{------------------------------------------------------------------------------
  function TCustomListBox.GetSelectedText: string;

  Returns Text of all selected items, separated by LineEnding
------------------------------------------------------------------------------}
function TCustomListBox.GetSelectedText: string;
var
  i: Integer;
begin
  Result := '';
  if ItemIndex < 0 then
    Exit;
  for i := 0 to Items.Count - 1 do
    if Selected[i] then
      if Result = '' then
        Result := Items[i]
      else
        Result := Result + LineEnding + Items[i]
end;

{------------------------------------------------------------------------------
  function TCustomListBox.ItemAtPos(const Pos: TPoint; Existing: Boolean
    ): Integer;

  Returns item index at y coordinate (including scrolling)
------------------------------------------------------------------------------}
function TCustomListBox.ItemAtPos(const Pos: TPoint; Existing: Boolean
  ): Integer;
begin
  Result := GetIndexAtXY(Pos.X, Pos.Y);
  if Existing then
  begin
    if Result >= Items.Count then
      Result := -1;
  end else
  begin
    if (Result < 0) and (Result > Items.Count) and PtInRect(ClientRect, Pos) then
      Result := Items.Count;
  end;
end;

{------------------------------------------------------------------------------
  function TCustomListBox.ItemRect(Index: Integer): TRect;

  Returns coordinates of an item (including scrolling)
  Special: If Index=Count the rectangle is guessed (like VCL).
------------------------------------------------------------------------------}
function TCustomListBox.ItemRect(Index: Integer): TRect;
begin
  FillChar(Result, SizeOf(Result), 0);
  if not HandleAllocated then
    Exit;
  if (Index >= 0) and (Index < Items.Count) then
    TWSCustomListBoxClass(WidgetSetClass).GetItemRect(Self, Index, Result)
  else
  if (Index=Items.Count) and (Index>0) then
  begin
    TWSCustomListBoxClass(WidgetSetClass).GetItemRect(Self, Index - 1, Result);
    OffsetRect(Result, 0, Result.Bottom - Result.Top);
  end;
end;

{------------------------------------------------------------------------------
  function TCustomListBox.ItemVisible(Index: Integer): boolean;

  Returns true if Item is partially visible.
------------------------------------------------------------------------------}
function TCustomListBox.ItemVisible(Index: Integer): boolean;
var
  ARect: TRect;
begin
  Result := False;
  if (Index < 0) or (Index >= Items.Count) then Exit;
  if not TWSCustomListBoxClass(WidgetSetClass).GetItemRect(Self, Index, ARect) then
    Exit;
  if (ARect.Bottom < 0) or (ARect.Top > ClientHeight) then
    Exit;
  Result := True;
end;

{------------------------------------------------------------------------------
  function TCustomListBox.ItemFullyVisible(Index: Integer): boolean;

  Returns true if Item is fully visible.
------------------------------------------------------------------------------}
function TCustomListBox.ItemFullyVisible(Index: Integer): boolean;
var
  ARect: TRect;
begin
  Result := False;
  if (Index < 0) or (Index >= Items.Count) then Exit;
  if not TWSCustomListBoxClass(WidgetSetClass).GetItemRect(Self, Index, ARect) then
    Exit;
  if (ARect.Top < 0) or (ARect.Bottom > ClientHeight) then
    Exit;
  Result := True;
end;

procedure TCustomListBox.MakeCurrentVisible;
var
  i: Integer;
begin
  i := ItemIndex;
  
  if (i < 0) or (i >= Items.Count) then Exit;
  // don't change top index if items is already fully visible
  if ItemFullyVisible(i) then Exit;
  
  TopIndex := ItemIndex;
end;


// back to stdctrls.pp

{%MainUnit ../comctrls.pp}
{
 *****************************************************************************
  This file is part of the Lazarus Component Library (LCL)

  See the file COPYING.modifiedLGPL.txt, included in this distribution,
  for details about the license.
 *****************************************************************************
}

{ TIconOptions }

procedure TIconOptions.SetArrangement(Value: TIconArrangement);
begin
  if FArrangement <> Value then
  begin
    FArrangement := Value;
    if FListView.HandleAllocated then
      TWSCustomListViewClass(FListView.WidgetSetClass).SetIconArrangement(FListView, Arrangement);
  end;
end;

function TIconOptions.GetAutoArrange: Boolean;
begin
  Result := FListView.GetProperty(Ord(lvpAutoArrange));
end;

function TIconOptions.GetWrapText: Boolean;
begin
  Result := FListView.GetProperty(Ord(lvpWrapText));
end;

procedure TIconOptions.SetAutoArrange(Value: Boolean);
begin
  FListView.SetProperty(Ord(lvpAutoArrange), Value);
end;

procedure TIconOptions.SetWrapText(Value: Boolean);
begin
  FListView.SetProperty(Ord(lvpWrapText), Value);
end;

procedure TIconOptions.AssignTo(Dest: TPersistent);
var
  DestOptions: TIconOptions absolute Dest;
begin
  if Dest is TIconOptions then
  begin
    DestOptions.Arrangement := Arrangement;
    DestOptions.AutoArrange := AutoArrange;
    DestOptions.WrapText := WrapText;
  end
  else
    inherited AssignTo(Dest);
end;

function TIconOptions.GetOwner: TPersistent;
begin
  Result := FListView;
end;

constructor TIconOptions.Create(AOwner: TCustomListView);
begin
  inherited Create;
  FListView := AOwner;
  FArrangement := iaTop;
end;

{ TCustomListViewEditor }

procedure TCustomListViewEditor.ListViewEditorKeyDown(Sender: TObject;
  var Key: Word; Shift: TShiftState);
begin
  if (Shift = []) and Visible then
  begin
    if Key = VK_ESCAPE then
    begin
      Key := 0;
      FItem := nil;
      Visible := False;
      Parent.SetFocus;
    end else
    if Key = VK_RETURN then
    begin
      Key := 0;
      Parent.SetFocus;
    end;
  end;
end;

procedure TCustomListViewEditor.DoExit;
begin
  TCustomListView(Parent).HideEditor;
  inherited DoExit;
end;

constructor TCustomListViewEditor.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FItem := nil;
  OnKeyDown := @ListViewEditorKeyDown;
end;

{------------------------------------------------------------------------------
   TCustomListView Constructor
------------------------------------------------------------------------------}
constructor TCustomListView.Create(AOwner: TComponent);
var
  lvil: TListViewImageList;
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle - [csCaptureMouse];
  FAutoSort := True;
  FAutoWidthLastColumn := False;
  FSortDirection := sdAscending;
  FIconOptions := TIconOptions.Create(Self);
  FColumns := TListColumns.Create(Self);
  FListItems := CreateListItems;
  BorderStyle := bsSingle;
  FScrollBars := ssBoth;
  FCompStyle := csListView;
  FViewStyle := vsList;
  FSortType := stNone;
  FSortColumn := -1;

  for lvil := Low(TListViewImageList) to High(TListViewImageList) do
  begin
    FImageChangeLinks[lvil] := TChangeLink.Create;
    FImageChangeLinks[lvil].OnChange := @ImageChanged;
    FImageChangeLinks[lvil].OnDestroyResolutionHandle := @ImageResolutionHandleDestroyed;
  end;
  FHoverTime := -1;
  TabStop := true;
  with GetControlClassDefaultSize do
    SetInitialBounds(0, 0, CX, CY);
  ParentColor := False;
  Color := {$ifdef UseCLDefault}clDefault{$else}clWindow{$endif};
  FCanvas := TControlCanvas.Create;
  TControlCanvas(FCanvas).Control := Self;
  FProperties := [lvpColumnClick, lvpHideSelection, lvpShowColumnHeaders, lvpToolTips, lvpWrapText];
  
  FOwnerDataItem := TOwnerDataListItem.Create(FListItems);
  FEditor := TCustomListViewEditor.Create(Self);
  FEditor.ControlStyle := FEditor.ControlStyle + [csNoDesignVisible, csNoDesignSelectable];
  FEditor.AutoSize := False;
  FEditor.Visible := False;
  FEditor.Parent := Self;
end;

{------------------------------------------------------------------------------
   TCustomListView CustomDraw
------------------------------------------------------------------------------}
function TCustomListView.CustomDraw(const ARect: TRect; AStage: TCustomDrawStage): Boolean;
begin
  Result := True;
  if Assigned(FOnCustomDraw) and (AStage = cdPrePaint)
  then FOnCustomDraw(Self, ARect, Result);

  if Assigned(FOnAdvancedCustomDraw)
  then FOnAdvancedCustomDraw(Self, ARect, AStage, Result)
end;

{------------------------------------------------------------------------------}
{   TCustomListView CustomDrawItem                                             }
{------------------------------------------------------------------------------}
function TCustomListView.CustomDrawItem(AItem: TListItem; AState: TCustomDrawState; AStage: TCustomDrawStage): Boolean;
begin
  Result := True;
  if Assigned(FOnCustomDrawItem) and (AStage = cdPrePaint)
  then FOnCustomDrawItem(Self, AItem, AState, Result);
  
  if Assigned(FOnAdvancedCustomDrawItem)
  then FOnAdvancedCustomDrawItem(Self, AItem, AState, AStage, Result);
end;

{------------------------------------------------------------------------------}
{   TCustomListView CustomDrawSubItem                                          }
{------------------------------------------------------------------------------}
function TCustomListView.CustomDrawSubItem(AItem: TListItem; ASubItem: Integer; AState: TCustomDrawState; AStage: TCustomDrawStage): Boolean;
begin
  Result := True;
  if Assigned(FOnCustomDrawSubItem) and (AStage = cdPrePaint)
  then FOnCustomDrawSubItem(Self, AItem, ASubItem, AState, Result);
  
  if Assigned(FOnAdvancedCustomDrawSubItem)
  then FOnAdvancedCustomDrawSubItem(Self, AItem, ASubItem, AState, AStage, Result);

end;

{------------------------------------------------------------------------------}
{   TCustomListView Change                                                     }
{------------------------------------------------------------------------------}
procedure TCustomListView.Change(AItem: TListItem; AChange: Integer);
var
  ItemChange: TItemChange;
begin
  case AChange of
    LVIF_TEXT: ItemChange := ctText;
    LVIF_IMAGE: ItemChange := ctImage;
    LVIF_STATE: ItemChange := ctState;
  else
    Exit;
  end;
  if Assigned(FOnChange)
  then FOnChange(Self, AItem, ItemChange);
end;

{------------------------------------------------------------------------------}
{   TCustomListView ColClick                                                   }
{------------------------------------------------------------------------------}
procedure TCustomListView.ColClick(AColumn: TListColumn);
const
  DirToIndicator : array [TSortDirection] of TSortIndicator = (siAscending, siDescending);
var
  i: Integer;
begin
  if IsEditing then
  begin
    if FEditor.Focused then
    begin
      SetFocus;
      HideEditor;
    end;
  end;
  if Assigned(FOnColumnClick) and ColumnClick then FOnColumnClick(Self, AColumn);
  // we set autosort after FOnColumnClick, maybe programmer want to
  // stop autosorting after some special column is clicked.
  if FAutoSort then
  begin
    if SortType <> stNone then
    begin
      if AColumn.Index <> SortColumn then begin
        if FAutoSortIndicator then
          for i:=0 to Columns.Count-1 do
            if (i <> AColumn.Index) and (Columns[i].SortIndicator <> siNone) then
              Columns[i].SortIndicator := siNone;

        SortColumn := AColumn.Index;
        SortDirection := sdAscending;
        if FAutoSortIndicator then AColumn.SortIndicator := siAscending;
      end
      else
      begin
        // with same column we are changing only direction
        if SortDirection = sdAscending then
          SortDirection := sdDescending
        else
          SortDirection := sdAscending;
        if FAutoSortIndicator then AColumn.SortIndicator := DirToIndicator[SortDirection];
      end;
    end;
  end;
end;

{------------------------------------------------------------------------------}
{   TCustomListView CNNotify                                                   }
{------------------------------------------------------------------------------}
procedure TCustomListView.CNNotify(var AMessage: TLMNotify);
var
  nm: PNMListView;
  Item: TListItem;
  n: Integer;
begin
  nm := PNMListView(AMessage.NMHdr);
  // ignore any notifications while initializing items
  if (nm^.iItem >= Items.Count) or
     not (OwnerData or (lisfWSItemsCreated in FListItems.Flags)) then Exit;
  //remark: NMHdr^.code is normally unhanged by the win32 interface, so the others
  //        maps there codes to the of win32
  case AMessage.NMHdr^.code of 
//  HDN_TRACK:
//  NM_CUSTOMDRAW:
      // Custom Drawing is handled direct from the interfaces by IntfCustomDraw
//  LVN_BEGINDRAG:
    LVN_DELETEITEM: begin
      Item := FListItems[nm^.iItem];
      if FSelected = Item then
        InvalidateSelected;
      if Item = nil then Exit; //? nm^.iItem > Items.Count ?
      Exclude(Item.FFlags, lifCreated);
      if not (lifDestroying in Item.FFlags)
      then Item.Delete;
    end;
    LVN_DELETEALLITEMS: begin
      InvalidateSelected;
      for n := FListItems.Count - 1 downto 0 do
      begin
        Item := FListItems[n];
        Exclude(Item.FFlags, lifCreated);
        if not (lifDestroying in Item.FFlags)
        then Item.Delete;
      end;
    end;
//    LVN_GETDISPINFO:
//    LVN_ODCACHEHINT:
//    LVN_ODFINDITEM:
//    LVN_ODSTATECHANGED:
//    LVN_BEGINLABELEDIT: implemented via TCustomListViewEditor
//    LVN_ENDLABELEDIT:   implemented via TCustomListViewEditor
    LVN_COLUMNCLICK:
    begin
      ColClick(Columns[nm^.iSubItem]);
    end;
    LVN_INSERTITEM: begin
      // don't call insert yet,
      // there is no solution available when we have inserted the item first
      // see delete
      // besides... who's inserting items
    end;
    LVN_ITEMCHANGING: begin
      //Check
    end;
    LVN_ITEMCHANGED:
    begin
      if nm^.iItem < 0 then
        Item := nil
      else
        Item := Items[nm^.iItem];
      //DebugLn('TCustomListView.CNNotify Count=',dbgs(Items.Count),' nm^.iItem=',dbgs(nm^.iItem),' destroying=',dbgs(lifDestroying in Item.FFlags));
      if (Item <> nil) and (not OwnerData) and (lifDestroying in Item.FFlags) then
      begin
        if Item=FFocused then
          FFocused:=nil;
        if Item=FSelected then
          InvalidateSelected;
      end else
      begin
        if (nm^.uChanged = LVIF_STATE) then
        begin
          // checkbox
          if Checkboxes then
            DoItemChecked(Item);

          // focus
          if (nm^.uOldState and LVIS_FOCUSED) <>
            (nm^.uNewState and LVIS_FOCUSED) then
          begin
            // focus state changed
            if (nm^.uNewState and LVIS_FOCUSED) = 0 then
            begin
              if FFocused = Item then
                FFocused := nil;
            end else
            begin
              FFocused := Item;
            end;
          end;
          // select
          if (nm^.uOldState and LVIS_SELECTED) <>
            (nm^.uNewState and LVIS_SELECTED) then
          begin
            // select state changed
            if (nm^.uNewState and LVIS_SELECTED) = 0 then
            begin
              if not OwnerData then
              begin
                if FSelected = Item then
                  InvalidateSelected
              end else
                if (nm^.iItem < 0) or (nm^.iItem = FSelectedIdx) then
                  InvalidateSelected;
            end else
            begin
              FSelected := Item;
              Include(FFlags,lffSelectedValid);
              if OwnerData then
              begin
                FSelectedIdx:=nm^.iItem;
              end;
              //DebugLn('TCustomListView.CNNotify FSelected=',dbgs(FSelected));
            end;
            Change(Item, nm^.uChanged);
            DoSelectItem(Item, (nm^.uNewState and LVIS_SELECTED) <> 0);
          end;
        end
        else
          Change(Item, nm^.uChanged);
      end;
    end;
//    LVN_GETINFOTIP:
//    NM_CLICK:
//    NM_RCLICK:
  end;
end;

procedure TCustomListView.DrawItem(AItem: TListItem; ARect: TRect;
  AState: TOwnerDrawState);
begin
  if Assigned(FOnDrawItem) then FOnDrawItem(Self, AItem, ARect, AState)
  else
  begin
    FCanvas.FillRect(ARect);
    FCanvas.TextOut(ARect.Left + 2, ARect.Top, AItem.Caption);
  end;
end;

procedure TCustomListView.CNDrawItem(var Message: TLMDrawListItem);
var
  State: TOwnerDrawState;
  SaveIndex: Integer;
begin
  if Assigned(FCanvas) then
  begin
    with Message.DrawListItemStruct^ do
    begin
      State := ItemState;
      SaveIndex := SaveDC(DC);
      FCanvas.Lock;
      try
        FCanvas.Handle := DC;
        FCanvas.Font := Font;
        FCanvas.Brush := Brush;
        if itemID = DWORD(-1) then
          FCanvas.FillRect(Area)
        else
          DrawItem(Items[itemID], Area, State);
      finally
        FCanvas.Handle := 0;
        FCanvas.Unlock;
        RestoreDC(DC, SaveIndex);
      end;
    end;
    Message.Result := 1;
  end;
end;

procedure TCustomListView.InvalidateSelected;
begin
  FSelected:=nil;
  FSelectedIdx := -1;
  Exclude(FFlags,lffSelectedValid);
end;

procedure TCustomListView.HideEditor;
var
  S: String;
begin
  S := FEditor.Text;
  if FEditor.Item <> nil then
    DoEndEdit(FEditor.Item, S);
  FEditor.Item := nil;
  FEditor.Visible := False;
  FEditor.SetBounds(0, 0, 0, 0);
end;

procedure TCustomListView.ShowEditor;
var
  Item: TListItem;
  R: TRect;
  TempHeight: Integer;
  S: String;
begin
  if (ItemIndex >= 0) and (ItemIndex < Items.Count) then
    Item := Items[ItemIndex]
  else
    Item := nil;
  HideEditor;
  if Item = nil then
    exit;
  if not CanEdit(Item) then
    exit;

  R := Item.DisplayRect(drLabel);
  if LCLIntf.IsRectEmpty(R) then
    exit;
  S := Item.Caption;
  if S = '' then
    S := 'H';
  TempHeight := Canvas.TextHeight(S);
  if TempHeight >= R.Bottom - R.Top then
    TempHeight := TempHeight - (R.Bottom - R.Top) + 4 {border above and below text}
  else
    TempHeight := 0;
  with R do
    FEditor.SetBounds(Left, Top, Right - Left, (Bottom - Top) + TempHeight);
  FEditor.Item := Item;
  FEditor.Text := Item.Caption;
  FEditor.Visible := True;
  FEditor.SetFocus;
end;

procedure TCustomListView.WMHScroll(var message: TLMHScroll);
begin
  if IsEditing then
  begin
    if FEditor.Focused then
      SetFocus
    else
      HideEditor;
  end;
end;

procedure TCustomListView.WMVScroll(var message: TLMVScroll);
begin
  if IsEditing then
  begin
    if FEditor.Focused then
      SetFocus
    else
      HideEditor;
  end;
end;

{------------------------------------------------------------------------------}
{   TCustomListView IsCustomDrawn                                              }
{------------------------------------------------------------------------------}
function TCustomListView.IsCustomDrawn(ATarget: TCustomDrawTarget; AStage: TCustomDrawStage): Boolean;
begin
  case ATarget of
    dtControl: Result := Assigned(FOnAdvancedCustomDraw)
                      or Assigned(FOnAdvancedCustomDrawItem)
                      or Assigned(FOnAdvancedCustomDrawSubItem);
    dtItem:    Result := Assigned(FOnAdvancedCustomDrawItem)
                      or Assigned(FOnAdvancedCustomDrawSubItem);
    dtSubItem: Result := Assigned(FOnAdvancedCustomDrawSubItem);
  end;
  
  if Result then exit;

  // check the normal events only in the prepaint stage
  if AStage <> cdPrePaint then Exit;

  case ATarget of
    dtControl: Result := Assigned(FOnCustomDraw)
                      or Assigned(FOnCustomDrawItem)
                      or Assigned(FOnCustomDrawSubItem);
    dtItem:    Result := Assigned(FOnCustomDrawItem)
                      or Assigned(FOnCustomDrawSubItem);
    dtSubItem: Result := Assigned(FOnCustomDrawSubItem);
  end;
end;

{------------------------------------------------------------------------------}
{   TCustomListView InitializeWnd                                              }
{------------------------------------------------------------------------------}
procedure TCustomListView.InitializeWnd;
var
  LVC: TWSCustomListViewClass;
  lvil: TListViewImageList;
begin
  inherited InitializeWnd;
  
  LVC := TWSCustomListViewClass(WidgetSetClass);

  // set the style first
  LVC.SetViewStyle(Self, FViewStyle);
  
  // add columns
  FColumns.WSCreateColumns;
  
  // set imagelists and item depending properties
  for lvil := Low(TListViewImageList) to High(TListViewImageList) do
  begin
    if FImages[lvil] <> nil
    then LVC.SetImageList(Self, lvil, FImages[lvil].ResolutionForPPI[FImagesWidth[lvil], Font.PixelsPerInch, 1].Resolution); // to-do: support scaling factor
  end;
  LVC.SetScrollBars(Self, FScrollBars);
  LVC.SetViewOrigin(Self, FViewOriginCache) ;
  LVC.SetProperties(Self, FProperties);
  LVC.SetSort(Self, FSortType, FSortColumn, FSortDirection);

  // add items
  if not OwnerData then 
  begin
    FListItems.WSCreateItems;
    // set other properties
    LVC.SetAllocBy(Self, FAllocBy);
  end 
  else 
  begin
    LVC.SetOwnerData(Self, True);
    LVC.SetItemsCount(Self, FListItems.Count);
  end;
  
  LVC.SetDefaultItemHeight(Self, FDefaultItemHeight);
  LVC.SetHotTrackStyles(Self, FHotTrackStyles);
  LVC.SetHoverTime(Self, FHoverTime);

  if FSelected <> nil 
  then LVC.ItemSetState(Self, FSelected.Index, FSelected, lisSelected, True);
  if FFocused <> nil
  then LVC.ItemSetState(Self, FFocused.Index, FFocused, lisFocused, True);
end;

{------------------------------------------------------------------------------}
{   TCustomListView DoDeletion                                                 }
{------------------------------------------------------------------------------}
procedure TCustomListView.DoDeletion(AItem: TListItem);
begin
  if not (TMethod(@Self.Delete).Code = Pointer(@TCustomListView.Delete)) then
    //There is an override for Delete, so use that for Delphi compatibility. Issue #0038263
    Delete(AItem)
  else
  //if you change the code below, make sure to change it in TCustomListView.Delete as well
  if not (csDestroying in ComponentState) and Assigned(FOnDeletion) then
    FOnDeletion(Self, AItem);
end;

{------------------------------------------------------------------------------}
{   TCustomListView Delete                                                     }
{------------------------------------------------------------------------------}
procedure TCustomListView.Delete(AItem : TListItem);
begin
  {
    In Delphi Delete is called in reaction to Items.Delete, but
    if you call it directly it will also do the actual deletion and then call the OnDeletion handler
    In that case we simply call Items.Delete and this will then call Delete again and in the second run
    we call the OnDeletion handler.
    Not 100% Delphi compatible, but more compatible then it was before. (BB)
  }
  //debugln(['TCustomListView.Delete: (lifDestroying in AItem.FFlags)=',(lifDestroying in AItem.FFlags)]);
  if not (lifDestroying in AItem.FFlags) then
  begin
    AItem.Delete;
    Exit;
  end;
  if not (csDestroying in ComponentState) and Assigned(FOnDeletion) then
    FOnDeletion(Self, AItem);
end;

{------------------------------------------------------------------------------}
{   TCustomListView DoInsert                                                   }
{------------------------------------------------------------------------------}
procedure TCustomListView.DoInsert(AItem: TListItem);
begin
  if not (TMethod(@Self.InsertItem).Code = Pointer(@TCUstomListView.InsertItem)) then
    //There is an override for InsertItem, so use that for Delphi compatibility. Issue #0038263
    InsertItem(AItem)
  else
    //if you change the code below, make sure to change it in TCustomListView.Delete as well
    if Assigned(FOnInsert) then FOnInsert(Self, AItem);
end;

{------------------------------------------------------------------------------}
{   TCustomListView InsertItem                                                 }
{------------------------------------------------------------------------------}
procedure TCustomListView.InsertItem(AItem : TListItem);
begin
  if Assigned(FOnInsert) then FOnInsert(Self, AItem);
end;

{------------------------------------------------------------------------------}
{   TCustomListView DoItemChecked                                              }
{------------------------------------------------------------------------------}
procedure TCustomListView.DoItemChecked(AItem: TListItem);
var
  B: Boolean;
begin
  if (not HandleAllocated) or (csLoading in ComponentState) then exit;
  B := TWSCustomListViewClass(WidgetSetClass).ItemGetChecked(Self,
    AItem.Index, AItem);
  if B <> AItem.GetCheckedInternal then
  begin
    AItem.Checked := B;
    if Assigned(FOnItemChecked) then
      FOnItemChecked(Self, AItem);
  end;
end;

{------------------------------------------------------------------------------}
{   TCustomListView DoSelectItem                                               }
{------------------------------------------------------------------------------}
procedure TCustomListView.DoSelectItem(AItem: TListItem; ASelected: Boolean);
begin
  if Assigned(AItem) then
    AItem.Selected:=ASelected;
  if Assigned(FOnSelectItem) and
    ([lffItemsMoving, lffItemsSorting] * FFlags = []) then
      FOnSelectItem(Self, AItem, ASelected);
end;

procedure TCustomListView.DoAutoAdjustLayout(
  const AMode: TLayoutAdjustmentPolicy; const AXProportion, AYProportion: Double
  );
var
  i: Integer;
  C: TListColumn;
  L: TListViewImageList;
begin
  inherited;

  if AMode in [lapAutoAdjustWithoutHorizontalScrolling, lapAutoAdjustForDPI] then
  begin
    for i := ColumnCount - 1 downto 0 do
    begin
      C := Column[i];
      C.MaxWidth := Round(C.MaxWidth * AXProportion);
      C.MinWidth := Round(C.MinWidth * AXProportion);
      C.Width := Round(C.Width * AXProportion);
    end;

    for L in TListViewImageList do
      SetImageListWS(L);
  end;
end;

procedure TCustomListView.DoSetBounds(ALeft, ATop, AWidth, AHeight: integer);
begin
  inherited DoSetBounds(ALeft, ATop, AWidth, AHeight);
  if AutoWidthLastColumn then
    ResizeLastColumn;
end;

procedure TCustomListView.DoEndEdit(AItem: TListItem; const AValue: String);
var
  S: string;
begin
  if not (TMethod(@Self.Edit).Code = Pointer(@TCustomListView.Edit)) then
    //There is an override for Edit, so use that for Delphi compatibility. Issue #0038263
    Edit(AItem)
  else
  begin
    //if you change the code below, make sure to change it in TCustomListView.Edit as well
    S := AValue;
    if Assigned(FOnEdited) then
      FOnEdited(Self, AItem, S);
    if AItem <> nil then
      AItem.Caption := S;
  end;
end;

procedure TCustomListView.Edit(AItem: TListItem);
var
  S: String;
begin
  //debugln(['TCustomListView.Edit: FEditor.Text=',FEditor.Text]);
  S := FEditor.Text;
  if Assigned(FOnEdited) then
    FOnEdited(Self, AItem, S);
  if AItem <> nil then
    AItem.Caption := S;
end;

{------------------------------------------------------------------------------}
{   TCustomListView ItemDeleted                                                }
{------------------------------------------------------------------------------}
procedure TCustomListView.ItemDeleted(const AItem: TListItem);  //called by TListItems
begin
  //DebugLn('TCustomListView.ItemDeleted ',dbgs(AItem),' FSelected=',dbgs(FSelected));
  if FSelected = AItem then InvalidateSelected;
  if FFocused = AItem then FFocused := nil;
  DoDeletion(AItem);
end;

{------------------------------------------------------------------------------}
{   TCustomListView ItemInserted                                               }
{------------------------------------------------------------------------------}
procedure TCustomListView.ItemInserted(const AItem: TListItem);
begin
  if csDestroying in Componentstate then Exit;
  DoInsert(AItem);
end;

class procedure TCustomListView.WSRegisterClass;
begin
  RegisterPropertyToSkip(Self, 'ItemIndex', 'Property streamed in older Lazarus revision', '');
  RegisterPropertyToSkip(Self, 'BevelKind', 'VCL compatibility property', '');
  RegisterPropertyToSkip(TListItem, 'OverlayIndex', 'VCL compatibility property', '');
  inherited WSRegisterClass;
  RegisterCustomListView;
end;

class function TCustomListView.GetControlClassDefaultSize: TSize;
begin
  Result.CX := 250;
  Result.CY := 150;
end;

{------------------------------------------------------------------------------}
{   TCustomListView SetItems                                                   }
{------------------------------------------------------------------------------}
procedure TCustomListView.SetItems(const AValue : TListItems);
begin
end;

{------------------------------------------------------------------------------}
{   TCustomListView SetItemVisible                                             }
{------------------------------------------------------------------------------}
procedure TCustomListView.SetItemVisible(const AValue : TListItem;
                                                     const APartialOK: Boolean);
begin
  if (not HandleAllocated) or (csLoading in ComponentState) then exit;
  TWSCustomListViewClass(WidgetSetClass).ItemShow(
                                        Self, AValue.Index, AValue, APartialOK);
end;



function TCustomListView.IntfCustomDraw(ATarget: TCustomDrawTarget; AStage: TCustomDrawStage; AItem, ASubItem: Integer; AState: TCustomDrawState; const ARect: PRect): TCustomDrawResult;
begin
  Result := [];
  
  // in the prepaint stage, return the notifications we want
  if AStage = cdPrePaint
  then begin
    case ATarget of
      dtControl: begin
        if IsCustomDrawn(dtItem, cdPrePaint) or IsCustomDrawn(dtItem, cdPreErase)
        then Include(Result, cdrNotifyItemDraw);

        if IsCustomDrawn(dtItem, cdPostPaint)
        then Include(Result, cdrNotifyPostPaint);

        if IsCustomDrawn(dtItem, cdPostErase)
        then Include(Result, cdrNotifyPostErase);

        if IsCustomDrawn(dtSubItem, cdPrePaint)
        then Include(Result, cdrNotifySubitemDraw);
      end;
      dtItem: begin
        if IsCustomDrawn(dtItem, cdPostPaint)
        then Include(Result, cdrNotifyPostPaint);

        if IsCustomDrawn(dtItem, cdPostErase)
        then Include(Result, cdrNotifyPostErase);

        if IsCustomDrawn(dtSubItem, cdPrePaint)
        then Include(Result, cdrNotifySubitemDraw);
      end;
      dtSubItem: begin
        if IsCustomDrawn(dtSubItem, cdPostPaint)
        then Include(Result, cdrNotifyPostPaint);

        if IsCustomDrawn(dtSubItem, cdPostErase)
        then Include(Result, cdrNotifyPostErase);
      end;
    end;
  end;

  if not IsCustomDrawn(ATarget, AStage) then Exit;


  case ATarget of
    dtControl: if CustomDraw(ARect^, AStage) then Exit;
    dtItem:    if CustomDrawItem(Items[AItem], AState, AStage) then Exit;
    dtSubItem: if CustomDrawSubItem(Items[AItem], ASubItem, AState, AStage) then Exit;
  end;

  // if we are here, a custom step returned false, so no default drawing
  if AStage = cdPrePaint
  then Result := [cdrSkipDefault];
end;

function TCustomListView.GetUpdateCount: Integer;
begin
  Result := FUpdateCount;
end;

procedure TCustomListView.DoGetOwnerData(Item: TListItem); 
begin
  if Assigned(OnData) then OnData(Self, Item);
end;

function TCustomListView.DoOwnerDataHint(AStartIndex, AEndIndex: Integer
  ): Boolean;
begin
  Result := Assigned(FOnDataHint);
  if Result then
    FOnDataHint(Self, AStartIndex, AEndIndex);
end;

function TCustomListView.DoOwnerDataStateChange(AStartIndex,
  AEndIndex: Integer; AOldState, ANewState: TListItemStates): Boolean;
begin
  Result := Assigned(FOnDataStateChange);
  if Result then
    FOnDataStateChange(Self, AStartIndex, AEndIndex, AOldState, ANewState);
end;

procedure TCustomListView.QueuedShowEditor(Data: PtrInt);
begin
  if fShowEditorQueued and IsVisible then
  begin
    fShowEditorQueued:=false;
    ShowEditor;
  end;
end;

procedure TCustomListView.DblClick;
begin
  inherited DblClick;
  if not ReadOnly and Assigned(FEditor) then
    ShowEditorQueued:=true;
end;

procedure TCustomListView.KeyDown(var Key: Word; Shift: TShiftState);
begin
  if not ReadOnly and (Key = VK_F2) and (Shift = []) then
  begin
    ShowEditor;
    Key := 0;
  end else
    inherited KeyDown(Key, Shift);
end;

{------------------------------------------------------------------------------}
{   TCustomListView SetColumns                                                 }
{------------------------------------------------------------------------------}
procedure TCustomListView.SetColumns(const AValue: TListColumns);
begin
  if AValue=FColumns then exit;
  BeginUpdate;
  FColumns.Assign(AValue);
  EndUpdate;
  if ([csDesigning,csLoading,csReading]*ComponentState=[csDesigning]) then
    OwnerFormDesignerModified(Self);
end;


{------------------------------------------------------------------------------}
{   TCustomListView SetViewOrigin                                              }
{------------------------------------------------------------------------------}
procedure TCustomListView.SetViewOrigin(AValue: TPoint);
begin
  if AValue.X < 0 then AValue.X := 0;
  if AValue.Y < 0 then AValue.Y := 0;
  if HandleAllocated
  then begin
    TWSCustomListViewClass(WidgetSetClass).SetViewOrigin(Self, AValue);
  end
  else begin
    FViewOriginCache := AValue;
  end;
end;

{------------------------------------------------------------------------------}
{   TCustomListView SetViewStyle                                               }
{------------------------------------------------------------------------------}
procedure TCustomListView.SetViewStyle(const Avalue: TViewStyle);
begin
  if FViewStyle = AValue then Exit;
  FViewStyle := AValue;
  if not HandleAllocated then Exit;
  TWSCustomListViewClass(WidgetSetClass).SetViewStyle(Self, AValue);
end;

{------------------------------------------------------------------------------}
{   TCustomListView SetSortType                                                }
{------------------------------------------------------------------------------}
procedure TCustomListView.SetSortType(const AValue: TSortType);
begin
  if FSortType = AValue then Exit;
  FSortType := AValue;
  Sort;
end;

{------------------------------------------------------------------------------}
{   TCustomListView SetSortColumn                                              }
{------------------------------------------------------------------------------}
procedure TCustomListView.SetSortColumn(const AValue : Integer);
begin
  if FSortColumn = AValue then Exit;
  FSortColumn := AValue;
  Sort;
end;

procedure TCustomListView.SetSortDirection(const AValue: TSortDirection);
begin
  if FSortDirection=AValue then exit;
  FSortDirection:=AValue;
  Sort;
end;

function _CompareListViewItems_CustomSort(Item1, Item2: Pointer): Integer;
var
  ListView: TCustomListView;
begin
  Result := 0;
  ListView := TListItem(Item1).Owner.Owner;

  if Assigned(ListView.FCustomSort_Func) then
    Result := ListView.FCustomSort_Func(TListItem(Item1), TListItem(Item2), ListView.FCustomSort_Param)
  else
  if Assigned(ListView.FOnCompare) then
    ListView.FOnCompare(ListView, TListItem(Item1), TListItem(Item2), 0, Result);
end;

function _CompareListViewItems(Item1, Item2: Pointer): Integer;
var
  Str1: String;
  Str2: String;
  ListView: TCustomListView;
begin
  Result := 0;
  ListView := TListItem(Item1).Owner.Owner;
  if Assigned(ListView.FOnCompare) then
    ListView.FOnCompare(ListView, TListItem(Item1), TListItem(Item2),0 ,Result)
  else
  begin
    if ListView.SortType in [stData] then
      Result := CompareValue(PtrUInt(TListItem(Item1).Data), PtrUInt(TListItem(Item2).Data))
    else
    begin
      if ListView.FSortColumn = 0 then
      begin
        Str1 := TListItem(Item1).Caption;
        Str2 := TListItem(Item2).Caption;
      end else
      begin
        if ListView.FSortColumn <= TListItem(Item1).SubItems.Count then
          Str1 := TListItem(Item1).SubItems.Strings[ListView.FSortColumn-1]
        else
          Str1 := '';
        if ListView.FSortColumn <= TListItem(Item2).SubItems.Count then
          Str2 := TListItem(Item2).SubItems.Strings[ListView.FSortColumn-1]
        else
          Str2 := '';
      end;
      Result := AnsiCompareText(Str1, Str2);
    end;
    if ListView.SortDirection = sdDescending then
      Result := -Result;
  end;
end;

{------------------------------------------------------------------------------}
{   TCustomListView Sort                                                       }
{------------------------------------------------------------------------------}
procedure TCustomListView.Sort;
begin
  if FSortType = stNone then exit;
  if (FSortColumn < 0) or (FSortColumn >= ColumnCount) then exit;
  SortWithParams(@_CompareListViewItems);
end;

function TCustomListView.CustomSort(ASortProc: TLVCompare; AOptionalParam: PtrInt): Boolean;
begin
  Result := Assigned(ASortProc) or Assigned(FOnCompare);
  if Result then
  begin
    FCustomSort_Func := ASortProc;
    FCustomSort_Param := AOptionalParam;
    SortWithParams(@_CompareListViewItems_CustomSort);
  end;
end;

procedure TCustomListView.SortWithParams(ACompareFunc: TListSortCompare);
var
  FSavedSelection: TFPList;
  FSavedFocused: TListItem;
  FSavedChecked: TFPList;
  FSavedCheckItem: TListItem;
  i: Integer;
  AItemIndex: Integer;
begin
  if FListItems.Count < 2 then exit;
  if lffPreparingSorting in FFlags then exit;

  if HandleAllocated then
  begin
    Include(FFlags, lffItemsSorting);
    FSavedSelection := TFPList.Create;
    FSavedChecked := nil;
    try
      if (ItemIndex >= 0) then
        FSavedFocused := Items[ItemIndex]
      else
        FSavedFocused := nil;
      if Assigned(Selected) then
      begin
        FSavedSelection.Add(Selected);
        if MultiSelect then
          for i := 0 to Items.Count-1 do
            if Items[i].Selected and (Items[i] <> Selected) then
              FSavedSelection.Add(Items[i]);
      end;
      if (TWSCustomListViewClass(WidgetSetClass).RestoreItemCheckedAfterSort(Self))
        and Items.WSUpdateAllowed
        and not OwnerData then
      begin
        FSavedChecked := TFPList.Create;
        for i := 0 to Items.Count - 1 do
          if Items[i].Checked then
            FSavedChecked.Add(Items[i]);
      end;

      Items.FCacheIndex := -1;
      Items.FCacheItem := nil;

      FListItems.FItems.Sort(ACompareFunc);
      TWSCustomListViewClass(WidgetSetClass).SetSort(Self, FSortType,
        FSortColumn, FSortDirection);

      if (FSavedSelection.Count > 0) or Assigned(FSavedFocused) then
      begin
        Selected := nil; // unselect all

        if FSavedFocused <> nil then
          TWSCustomListViewClass(WidgetSetClass).ItemSetState(Self,
            FSavedFocused.Index, FSavedFocused, lisFocused, True);

        for i := FSavedSelection.Count - 1 downto 0 do
        begin
          AItemIndex := Items.IndexOf(TListItem(FSavedSelection.Items[i]));
          if AItemIndex <> -1 then
            TWSCustomListViewClass(WidgetSetClass).ItemSetState(Self,
              AItemIndex, Items[AItemIndex], lisSelected, True);
        end;

        if FSavedChecked <> nil then
        begin
          for i := 0 to FSavedChecked.Count - 1 do
          begin
            FSavedCheckItem := TListItem( FSavedChecked[i] );
            // todo: this is inefficient, because FSavedCheckItem.Index must be called again
            TWSCustomListViewClass(WidgetSetClass).ItemSetChecked(Self,
              FSavedCheckItem.Index, FSavedCheckItem, True);
          end;
          FSavedChecked.Free;
        end;

      end;
    finally
      FreeThenNil(FSavedSelection);
      Exclude(FFlags, lffItemsSorting);
    end;
  end else
    FListItems.FItems.Sort(ACompareFunc);
end;

{------------------------------------------------------------------------------}
{   TCustomListView Destructor                                                 }
{------------------------------------------------------------------------------}
destructor TCustomListView.Destroy;
var
  lvil: TListViewImageList;
begin
  Application.RemoveAsyncCalls(Self);
  // Better destroy the wincontrol (=widget) first. So wo don't have to delete
  // all items/columns and we won't get notifications for each.
  FreeAndNil(FCanvas);
  inherited Destroy;
  FreeAndNil(FColumns);
  for lvil := Low(TListViewImageList) to High(TListViewImageList) do
    FreeAndNil(FImageChangeLinks[lvil]);
  FreeAndNil(FOwnerDataItem);
  FreeAndNil(FListItems);
  FreeAndNil(FIconOptions);
end;

procedure TCustomListView.AddItem(Item: string; AObject: TObject);
var
  AItem: TListItem;
begin
  AItem := Items.Add;
  AItem.Caption := Item;
  AItem.Data := AObject;
end;

function TCustomListView.AlphaSort: Boolean;
begin
  Result := False;
  Include(FFlags, lffPreparingSorting);
  // always reset direction, so sort triggers later !
  SortDirection := sdDescending;
  SortType := stText;
  SortColumn := 0;
  Exclude(FFlags, lffPreparingSorting);
  // now trigger sort when all rules are applied
  SortDirection := sdAscending;
  Result := True;
end;

{------------------------------------------------------------------------------
   TCustomListView DestroyWnd
   Params: None
   Result: none

   Frees the canvas
 ------------------------------------------------------------------------------}
procedure TCustomListView.DestroyWnd; 
begin
  if FCanvas<>nil then
    TControlCanvas(FCanvas).FreeHandle;
  inherited DestroyWnd;
end;

procedure TCustomListView.BeginAutoDrag;
begin
  BeginDrag(False);
end;

function TCustomListView.CreateListItem: TListItem;
var
  AItemClass: TListItemClass;
begin
  AItemClass := TListItem;
  if Assigned(OnCreateItemClass) then
    OnCreateItemClass(Self, AItemClass);
  Result := AItemClass.Create(Items);
end;

function TCustomListView.CreateListItems: TListItems;
begin
  Result := TListItems.Create(Self);
end;

{------------------------------------------------------------------------------
   TCustomListView BeginUpdate
   Params: None
   Result: none

   Increases the update count. Use this procedure before any big change, so that
   the interface will not show any single step.
 ------------------------------------------------------------------------------}
procedure TCustomListView.BeginUpdate;
begin
  Inc(FUpdateCount);
  Include(FFlags, lffPreparingSorting);
  if (FUpdateCount = 1) and HandleAllocated
  then TWSCustomListViewClass(WidgetSetClass).BeginUpdate(Self);
end;

function TCustomListView.CanEdit(Item: TListItem): Boolean;
begin
  Result := True;
  if Assigned(FOnEditing) then
    FOnEditing(Self, Item, Result);
end;

procedure TCustomListView.Clear;
begin
  FListItems.Clear;
end;

{------------------------------------------------------------------------------}
{   TCustomListView EndUpdate                                               }
{------------------------------------------------------------------------------}
procedure TCustomListView.EndUpdate;
begin
  if FUpdateCount <= 0
  then RaiseGDBException('TCustomListView.EndUpdate FUpdateCount=0');
  
  Dec(FUpdateCount);
  if FUpdateCount=0 then Exclude(FFlags, lffPreparingSorting);
  if (FUpdateCount = 0) and HandleAllocated
  then TWSCustomListViewClass(WidgetSetClass).EndUpdate(Self);
end;

procedure TCustomListView.Repaint;
begin
  if OwnerData then
    // the last cached item might be left updated, because OnData isn't called!
    FOwnerDataItem.SetDataIndex(-1);
  inherited Repaint;
end;

procedure TCustomListView.FinalizeWnd;
begin
  FShowEditorQueued:=false;
  // store origin
  FViewOriginCache := TWSCustomListViewClass(WidgetSetClass).GetViewOrigin(Self);
  if not OwnerData then
    FListItems.DoFinalizeWnd;
  Columns.DoFinalizeWnd;
  inherited FinalizeWnd;
end;

function TCustomListView.FindCaption(StartIndex: Integer; Value: string;
  Partial, Inclusive, Wrap: Boolean; PartStart: Boolean = True): TListItem;
begin
  Result := FListItems.FindCaption(StartIndex, Value, Partial, Inclusive, Wrap, PartStart);
end;

function TCustomListView.FindData(StartIndex: Integer; Value: Pointer;
  Inclusive, Wrap: Boolean): TListItem;
begin
  Result := FListItems.FindData(StartIndex, Value, Inclusive, Wrap);
end;

function TCustomListView.GetBoundingRect: TRect;
begin
  if not HandleAllocated
  then Result := Rect(0,0,0,0)
  else Result := TWSCustomListViewClass(WidgetSetClass).GetBoundingRect(Self);
end;

function TCustomListView.GetColumnCount: Integer;
begin
  Result := FColumns.Count;
end;

function TCustomListView.GetColumnFromIndex(AIndex: Integer): TListColumn;
begin
  Result := FColumns[AIndex];
end;

function TCustomListView.GetDropTarget: TListItem;
var
  idx: Integer;
begin
  if not HandleAllocated
  then idx := -1
  else idx := TWSCustomListViewClass(WidgetSetClass).GetDropTarget(Self);
  if idx = -1
  then Result := nil
  else Result := FListItems[idx];
end;

function TCustomListView.GetFocused: TListItem;
begin
  Result := FFocused;
end;

function TCustomListView.GetImageList(const ALvilOrd: Integer): TCustomImageList;
begin
  Result := FImages[TListViewImageList(ALvilOrd)];
end;

function TCustomListView.GetImageListWidth(const ALvilOrd: Integer): Integer;
begin
  Result := FImagesWidth[TListViewImageList(ALvilOrd)];
end;

function TCustomListView.GetHoverTime: Integer;
begin
  if HandleAllocated
  then Result := TWSCustomListViewClass(WidgetSetClass).GetHoverTime(Self)
  else Result := FHoverTime;
end;

function TCustomListView.GetItemIndex: Integer;
begin
  Result := -1;
  if not OwnerData then begin
    if Selected = nil then Exit;
    Result := Selected.Index
  end else
    Result := FSelectedIdx;
end;

function TCustomListView.GetHitTestInfoAt(X, Y: Integer): THitTests;
begin
  Result := [];
  if HandleAllocated then
    Result := TWSCustomListViewClass(WidgetSetClass).GetHitTestInfoAt( Self, X, Y );
end;

function TCustomListView.GetItemAt(x, y: integer): TListItem;
var 
  Item: Integer;
begin      
  Result := nil; 
  if HandleAllocated
  then begin
    Item := TWSCustomListViewClass(WidgetSetClass).GetItemAt(Self,x,y);
    if Item <> -1 
    then Result := Items[Item];
  end;
end;

function TCustomListView.GetNearestItem(APoint: TPoint;
  Direction: TSearchDirection): TListItem;
var
  AItem: TListItem;
  AIndex: Integer;
begin
  Result := nil;
  AItem := GetItemAt(APoint.x, APoint.y);
  if Assigned(AItem) then
  begin
    AIndex := AItem.Index;
    case Direction of
      sdAbove: if AIndex - 1 >= 0 then Result := Items[AIndex - 1];
      sdBelow: if AIndex - 1 < Items.Count then
        Result := Items[AIndex + 1];
    end;
  end;
end;

function TCustomListView.GetNextItem(StartItem: TListItem;
  Direction: TSearchDirection; States: TListItemStates): TListItem;
begin
  Result := nil;
  if HandleAllocated then
     Result := TWSCustomListViewClass(WidgetSetClass).GetNextItem(Self, StartItem, Direction, States);
end;

procedure TCustomListView.ClearSelection;
begin
  Self.BeginUpdate;
  if MultiSelect then
  begin
    if HandleAllocated then
      TWSCustomListViewClass(WidgetSetClass).SelectAll(Self, False);
    Items.ClearSelection;
  end else
  if (ItemIndex >= 0) and (ItemIndex < Items.Count) then
    Items.Item[ItemIndex].Selected := False;
  Self.EndUpdate;
end;

procedure TCustomListView.SelectAll;
begin
  if not MultiSelect then
    exit;
  Self.BeginUpdate;
  if HandleAllocated then
    TWSCustomListViewClass(WidgetSetClass).SelectAll(Self, True);
  Items.SelectAll;
  Self.EndUpdate;
end;

function TCustomListView.IsEditing: Boolean;
begin
  Result := Assigned(Self.FEditor) and FEditor.Visible;
end;

function TCustomListView.GetProperty(const ALvpOrd: Integer): Boolean;
begin
  Result := (TListViewProperty(ALvpOrd) in FProperties);
end;

function TCustomListView.GetSelCount: Integer;
var
  i: integer;
begin
  if HandleAllocated
  then Result := TWSCustomListViewClass(WidgetSetClass).GetSelCount(Self)
  else
  begin
    Result := 0;
    for i := 0 to Items.Count - 1 do
      if Items[i].Selected then
        inc(Result);
  end;
end;

{------------------------------------------------------------------------------
   TCustomListView GetSelection
------------------------------------------------------------------------------}
function TCustomListView.GetSelection: TListItem;
var
  i: Integer;
begin
  if not OwnerData then
  begin
    {according to Delphi docs
     we always must return first selected item, not the last selected one
     see issue #16773}
    if not (lffSelectedValid in FFlags) or MultiSelect then
    begin
      FSelected := nil;
      for i := 0 to Items.Count - 1 do
      begin
        if Items[i].Selected then
        begin
          FSelected := Items[i];
          break;
        end;
      end;
      Include(FFlags, lffSelectedValid);
    end;
    Result := FSelected;
  end else begin
    if FSelectedIdx>=0 then begin
      FOwnerDataItem.SetDataIndex(FSelectedIdx);
      Result:=FOwnerDataItem;
    end else
      Result:=nil;
  end;
end;

function TCustomListView.GetTopItem: TListItem;
var
  idx: Integer;
begin
  if ViewStyle in [vsSmallIcon, vsIcon]
  then idx := -1
  else idx := TWSCustomListViewClass(WidgetSetClass).GetTopItem(Self);
  if idx = -1
  then Result := nil
  else Result := FListItems[idx];
end;

{------------------------------------------------------------------------------}
{   TCustomListView GetViewOrigin                                              }
{------------------------------------------------------------------------------}
function TCustomListView.GetViewOrigin: TPoint;
begin
  if HandleAllocated
  then begin
    Result := TWSCustomListViewClass(WidgetSetClass).GetViewOrigin(Self);
  end
  else begin
    Result := FViewOriginCache;
  end;
end;


function TCustomListView.GetVisibleRowCount: Integer;
begin
  if ViewStyle in [vsReport, vsList]
  then Result := TWSCustomListViewClass(WidgetSetClass).GetVisibleRowCount(Self)
  else Result := 0;
end;

procedure TCustomListView.SetAllocBy(const AValue: Integer);
begin
  if FAllocBy = AValue then Exit;
  FAllocBy := AValue;
  if not HandleAllocated then Exit;
  TWSCustomListViewClass(WidgetSetClass).SetAllocBy(Self, AValue);
end;

procedure TCustomListView.ResizeLastColumn;
var
  i: Integer;
  LastVisibleColumn: Integer;
  Accu: Integer;
  W: Integer;
  NewWidth: Integer;
begin
  if not (ViewStyle in [vsList, vsReport]) or (ColumnCount = 0) then
    exit;
  LastVisibleColumn := -1;

  // find last visible column
  for i := ColumnCount - 1 downto 0 do
  begin
    if Column[i].Visible then
    begin
      LastVisibleColumn := i;
      break;
    end;
  end;

  // calculate size and apply it only if it's > 0
  if LastVisibleColumn >= 0 then
  begin
    //TODO: gtk2 doesnt return correct ClientWidth. win32 and qt works ok.
    W := ClientWidth - (BorderWidth * 2);
    Accu := 0;
    for i := 0 to LastVisibleColumn - 1 do
    begin
      if Column[i].Visible then
        Accu := Accu + Column[i].Width;
    end;
    NewWidth := W - Accu;
    if NewWidth > 0 then
    begin
      // now set AutoSize and MinWidth/MaxWidth to 0
      Column[LastVisibleColumn].AutoSize := False;
      Column[LastVisibleColumn].MinWidth := 0;
      Column[LastVisibleColumn].MaxWidth := 0;
      Column[LastVisibleColumn].Width := NewWidth;
    end;
  end;
end;

procedure TCustomListView.SetAutoWidthLastColumn(AValue: Boolean);
begin
  if FAutoWidthLastColumn=AValue then Exit;
  FAutoWidthLastColumn:=AValue;
  if FAutoWidthLastColumn then
    ResizeLastColumn;
end;

procedure TCustomListView.SetDefaultItemHeight(AValue: Integer);
begin
  if AValue <=0 then AValue := 20;
  if AValue = FDefaultItemHeight then Exit;
  FDefaultItemHeight := AValue;
  if not HandleAllocated then Exit;
  TWSCustomListViewClass(WidgetSetClass).SetDefaultItemHeight(Self, AValue);
end;

procedure TCustomListView.SetDropTarget(const AValue: TListItem);
begin
  if not HandleAllocated then Exit;
  TWSCustomListViewClass(WidgetSetClass).ItemSetState(Self, AValue.Index, AValue, lisDropTarget, True);
end;

procedure TCustomListView.SetFocused(const AValue: TListItem);
begin
  if FFocused = AValue then exit;
  FFocused := AValue;
  if not HandleAllocated then
    Exit;
  if FFocused <> nil then
    TWSCustomListViewClass(WidgetSetClass).ItemSetState(Self, FFocused.Index, FFocused, lisFocused, True);
end;

procedure TCustomListView.SetHotTrackStyles(const AValue: TListHotTrackStyles);
begin
  if FHotTrackStyles = AValue then Exit;
  FHotTrackStyles := AValue;
  if not HandleAllocated then Exit;
  TWSCustomListViewClass(WidgetSetClass).SetHotTrackStyles(Self, AValue);
end;

procedure TCustomListView.SetHoverTime(const AValue: Integer);
begin
  if FHoverTime = AValue then Exit;
  FHoverTime := AValue;
  if not HandleAllocated then Exit;
  TWSCustomListViewClass(WidgetSetClass).SetHoverTime(Self, FHoverTime);
end;

procedure TCustomListView.SetIconOptions(const AValue: TIconOptions);
begin
  FIconOptions.Assign(AValue);
end;

procedure TCustomListView.SetImageList(const ALvilOrd: Integer; const AValue: TCustomImageList);
var
  lvil: TListViewImageList;
begin
  lvil := TListViewImageList(ALvilOrd);

  if FImages[lvil] = AValue then Exit;

  if FImages[lvil] <> nil
  then FImages[lvil].UnregisterChanges(FImageChangeLinks[lvil]);

  FImages[lvil] := AValue;

  if FImages[lvil] <> nil
  then begin
    FImages[lvil].RegisterChanges(FImageChangeLinks[lvil]);
    FImages[lvil].FreeNotification(self);
  end;

  SetImageListWS(lvil);
end;

procedure TCustomListView.SetImageListAsync(Data: PtrInt);
begin
  SetImageListWS(TListViewImageList(Data));
end;

procedure TCustomListView.SetImageListWidth(const ALvilOrd: Integer;
  const AValue: Integer);
var
  lvil: TListViewImageList;
begin
  lvil := TListViewImageList(ALvilOrd);

  if FImagesWidth[lvil] = AValue then Exit;

  FImagesWidth[lvil] := AValue;

  SetImageListWS(lvil);
end;

procedure TCustomListView.SetImageListWS(const ALvil: TListViewImageList);
var
  R: TCustomImageListResolution;
begin
  if not HandleAllocated then
    Exit;
  if FImages[ALvil]<>nil then
    R := FImages[ALvil].ResolutionForPPI[FImagesWidth[ALvil], Font.PixelsPerInch, 1].Resolution // to-do: support scaling factor
  else
    R := nil;
  TWSCustomListViewClass(WidgetSetClass).SetImageList(Self, ALvil, R)
end;

procedure TCustomListView.SetItemIndex(const AValue: Integer);
begin
  if (AValue < -1) or (AValue >= Items.Count) then
    raise Exception.CreateFmt(rsListIndexExceedsBounds,[AValue]);

  if AValue = -1 then
    Selected := nil
  else
  begin
    // trigger ws selection update, it'll update Selected too
    if OwnerData then
    begin
      // clean selection when itemindex is changed. issue #19825
      if MultiSelect then
        Selected := nil;
      FSelectedIdx := AValue;
      Items.Item[AValue].Selected := True;
    end else
      Selected := Items.Item[AValue];
  end;
end;

{------------------------------------------------------------------------------
   TCustomListView SetSelection
------------------------------------------------------------------------------}
procedure TCustomListView.SetSelection(const AValue: TListItem);
var
  i: integer;
begin
  if (AValue<>nil) and (AValue.ListView<>Self) then
    raise Exception.Create('Item does not belong to this listview');
  if (not FOwnerData) and (FSelected = AValue) then Exit;
  //DebugLn('TCustomListView.SetSelection FSelected=',dbgs(FSelected));
  if AValue = nil then
  begin
    if MultiSelect then
    begin
      BeginUpdate;
      try
        for i:=0 to Items.Count-1 do
          with Items[i] do
            if Selected then
              Selected:=False;
      finally
        EndUpdate;
      end;
    end else
    if FSelected <> nil then
      FSelected.Selected := False;
    FSelected := nil;
    Include(FFlags,lffSelectedValid);
  end else
  begin
    FSelected := AValue;
    if HandleAllocated then
      TWSCustomListViewClass(WidgetSetClass).ItemSetState(Self, FSelected.Index,
          FSelected, lisSelected, True);
  end;
end;

procedure TCustomListView.SetShowEditorQueued(AValue: boolean);
begin
  if FShowEditorQueued=AValue then Exit;
  FShowEditorQueued:=AValue;
  if FShowEditorQueued then
    Application.QueueAsyncCall(@QueuedShowEditor,0);
end;

procedure TCustomListView.SetOwnerData(const AValue: Boolean);
begin
  if FOwnerData=AValue then exit;
  FOwnerData:=AValue;
  FOwnerDataItem.SetOwner(nil);
  Items.Free;
  if AValue then
  begin
    FSelectedIdx := -1;
    FListItems := TOwnerDataListItems.Create(Self);
  end
  else
    FListItems := CreateListItems;

  if HandleAllocated then 
    TWSCustomListViewClass(WidgetSetClass).SetOwnerData(Self, AValue);
  FOwnerDataItem.SetOwner(FListItems);
end;

procedure TCustomListView.SetProperty(const ALvpOrd: Integer;
  const AIsSet: Boolean);
var
  AProp: TListViewProperty;
begin
  AProp := TListViewProperty(ALvpOrd);
  if (AProp in FProperties) = AIsSet then Exit;

  if AIsSet
  then Include(FProperties, AProp)
  else Exclude(FProperties, AProp);

  if not HandleAllocated then Exit;
  TWSCustomListViewClass(WidgetSetClass).SetProperty(Self, AProp, AIsSet);
end;

procedure TCustomListView.ImageChanged(Sender : TObject);
begin
  if csDestroying in ComponentState Then Exit;
// TODO: move Imagelist to interface, image changes can be update there
//  if FUpdateCount>0 then
//    Include(FStates,lvUpdateNeeded)
//  else begin
//    //image changed so redraw it all....
//    UpdateProperties;
//  end;
end;

procedure TCustomListView.ImageResolutionHandleDestroyed(
  Sender: TCustomImageList; AWidth: Integer; AReferenceHandle: TLCLHandle);
var
  lvil: TListViewImageList;
begin
  if not HandleAllocated then
    Exit;

  for lvil in TListViewImageList do
    if Sender = FImages[lvil] then
    begin
      TWSCustomListViewClass(WidgetSetClass).SetImageList(Self, lvil, nil);
      Application.QueueAsyncCall(@SetImageListAsync, Ord(lvil));
    end;
end;

procedure TCustomListView.Loaded;
begin
  // create interface columns if needed
  if HandleAllocated then
    FColumns.WSCreateColumns;
  inherited Loaded;
end;

procedure TCustomListView.Notification(AComponent: TComponent; Operation: TOperation);
begin
  inherited Notification(AComponent, Operation);
  if Operation = opRemove then begin
    if AComponent = LargeImages then LargeImages := nil;
    if AComponent = SmallImages then SmallImages := nil;
    if AComponent = StateImages then StateImages := nil;
  end;
end;

procedure TCustomListView.SetScrollBars(const AValue: TScrollStyle);
begin
  if (FScrollBars = AValue) then exit;
  FScrollBars := AValue;
  if not HandleAllocated then Exit;
  TWSCustomListViewClass(WidgetSetClass).SetScrollBars(Self, AValue);
  UpdateScrollBars;
end;

procedure TCustomListView.UpdateScrollbars;
begin
  // this needs to be done in the widgetset
  DebugLn('TODO: TCustomListView.UpdateScrollbars');
  exit;

  if not HandleAllocated then exit;
end;


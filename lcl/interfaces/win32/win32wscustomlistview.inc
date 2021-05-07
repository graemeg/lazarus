{%MainUnit win32wscomctrls.pp}
{ $Id$

 *****************************************************************************
  This file is part of the Lazarus Component Library (LCL)

  See the file COPYING.modifiedLGPL.txt, included in this distribution,
  for details about the license.
 *****************************************************************************
}

{ TWin32WSCustomListView }

type
  TLVStyleType = (lsStyle, lsInvert, lsExStyle);

const
  LV_STYLES: array[TListViewProperty] of record
    StyleType: TLVStyleType;
    Style: Integer;
  end = (
    (StyleType: lsStyle;   Style: LVS_AUTOARRANGE),        // lvpAutoArrange
    (StyleType: lsExStyle; Style: LVS_EX_CHECKBOXES),      // lvpCheckboxes
    (StyleType: lsInvert;  Style: LVS_NOSORTHEADER),       // lvpColumnClick
    (StyleType: lsExStyle; Style: LVS_EX_FLATSB),          // lvpFlatScrollBars
    (StyleType: lsExStyle; Style: LVS_EX_HEADERDRAGDROP),  // lvpFullDrag
    (StyleType: lsExStyle; Style: LVS_EX_GRIDLINES),       // lvpGridLines
    (StyleType: lsInvert;  Style: LVS_SHOWSELALWAYS),      // lvpHideSelection
    (StyleType: lsExStyle; Style: LVS_EX_TRACKSELECT),     // lvpHotTrack
    (StyleType: lsInvert;  Style: LVS_SINGLESEL),          // lvpMultiSelect
    (StyleType: lsStyle;   Style: LVS_OWNERDRAWFIXED),     // lvpOwnerDraw
    (StyleType: lsInvert;  Style: LVS_EDITLABELS),         // lvpReadOnly,
    (StyleType: lsExStyle; Style: LVS_EX_FULLROWSELECT),   // lvpRowSelect
    (StyleType: lsInvert;  Style: LVS_NOCOLUMNHEADER),     // lvpShowColumnHeaders
    (StyleType: lsExStyle; Style: LVS_EX_MULTIWORKAREAS),  // lvpShowWorkAreas
    (StyleType: lsInvert;  Style: LVS_NOLABELWRAP),        // lvpWrapText
    (StyleType: lsExStyle; Style: LVS_EX_LABELTIP)         // lvpToolTips
  );


type
  // TODO: add iImage and iOrder to exiting TLvColumn
  // this is a hack !!!
  TLvColumn_v4_7 = record
    lvc: TLvColumn;
    iImage: Integer;
    iOrder: Integer;
  end;


type
  TCustomListViewAccess = class(TCustomListView);
  TListColumnAccess = class(TListColumn);

////////////////////////////////////////////////////////////////////////////////
// Msg handlers
////////////////////////////////////////////////////////////////////////////////

var
  ListViewWindProcInfo: record
    ActiveListView: TCustomListView;
    NoMouseUp: Boolean;
  end;

function ListViewParentMsgHandler(const AWinControl: TWinControl; Window: HWnd;
      Msg: UInt; WParam: Windows.WParam; LParam: Windows.LParam;
      var MsgResult: Windows.LResult; var WinProcess: Boolean): Boolean;

type
  PNMLVOwnerData = PLVDISPINFO;
var
  NMHdr: PNMHdr absolute LParam; // used by WM_NOTIFY

  // Gets the cursor position relative to a given window
  function GetClientCursorPos(ClientWindow: HWND) : TSmallPoint;
  var
    P: TPoint;
  begin
    Windows.GetCursorPos(P);
    //if the mouse is not over the window is better to set to 0 to avoid weird behaviors
    if Windows.WindowFromPoint(P) = ClientWindow then
      Windows.ScreenToClient(ClientWindow, P)
    else
    begin
      P.X:=0;
      P.Y:=0;
    end;
    Result := Windows.PointToSmallPoint(P);
  end;

  procedure HandleListViewOwnerData(ALV: TCustomListViewAccess);
  var
    DataInfo: PNMLVOwnerData; // absolute NMHdr;
    txt: String;
    LVInfo: PWin32WindowInfo;
    idx: Integer;
    listitem: TListItem;
  begin
    LVInfo:= GetWin32WindowInfo(ALV.Handle);
    DataInfo := PNMLVOwnerData(NMHdr);
    if not Assigned(DataInfo) or (not ALV.OwnerData) then
      Exit;
    listitem := ALV.Items[DataInfo^.item.iItem];
    if not Assigned(listitem) then
      Exit;
    if (DataInfo^.item.mask and LVIF_TEXT) <> 0 then
    begin
      if DataInfo^.item.iSubItem = 0 then
        txt := listitem.Caption
      else
      begin
        idx := DataInfo^.item.iSubItem - 1;
        if idx < listitem.SubItems.Count then
          txt := listitem.SubItems[idx]
        else
          txt := '';
      end;
      if DataInfo^.hdr.code = UInt(LVN_GETDISPINFOA) then
      begin
        LVInfo^.DispInfoTextA[LVInfo^.DispInfoIndex]:=Utf8ToAnsi(txt+#0);
        DataInfo^.item.pszText := @(LVInfo^.DispInfoTextA[LVInfo^.DispInfoIndex][1]);
      end
      else
      begin
        LVInfo^.DispInfoTextW[LVInfo^.DispInfoIndex]:=UTF8Decode(txt+#0);
        DataInfo^.item.pszText := PChar(LVInfo^.DispInfoTextW[LVInfo^.DispInfoIndex]);
      end;
      inc(LVInfo^.DispInfoIndex);
      if LVInfo^.DispInfoIndex=LV_DISP_INFO_COUNT then LVInfo^.DispInfoIndex:=0;
    end;
    if (DataInfo^.item.mask and LVIF_IMAGE) <> 0 then
    begin
      if DataInfo^.item.iSubItem = 0 then
        DataInfo^.item.iImage := listitem.ImageIndex
      else
      begin
        idx := DataInfo^.item.iSubItem - 1;
        if idx < listitem.SubItems.Count then
          DataInfo^.item.iImage := listitem.SubItemImages[idx]
        else
          DataInfo^.item.iImage := -1;
      end;
      if Assigned(ALV.StateImages) then
      begin
        DataInfo^.item.state := IndexToStateImageMask(listitem.StateIndex + 1);
        DataInfo^.item.stateMask := $F000; // States start from 12 bit
        DataInfo^.item.mask := DataInfo^.item.mask or LVIF_STATE;
      end;
    end;
  end;

  procedure HandleListViewCustomDraw(ALV: TCustomListViewAccess);
    function ConvState(const State: uint): TCustomDrawState;
    begin
      Result := [];
      if state and CDIS_CHECKED <> 0 then Include(Result, cdsChecked);
      if state and CDIS_DEFAULT <> 0 then Include(Result, cdsDefault);
      if state and CDIS_DISABLED <> 0 then Include(Result, cdsDisabled);
      if state and CDIS_FOCUS <> 0 then Include(Result, cdsFocused);
      if state and CDIS_GRAYED <> 0 then Include(Result, cdsGrayed);
      if state and CDIS_HOT <> 0 then Include(Result, cdsHot);
      if state and CDIS_INDETERMINATE <> 0 then Include(Result, cdsIndeterminate);
      if state and CDIS_MARKED <> 0 then Include(Result, cdsMarked);
      if state and CDIS_SELECTED <> 0 then Include(Result, cdsSelected);
    end;

  const
    CDRFRESULT: array[TCustomDrawResultFlag] of Integer = (
      CDRF_SKIPDEFAULT,
      CDRF_NOTIFYPOSTPAINT,
      CDRF_NOTIFYITEMDRAW,
      CDRF_NOTIFYSUBITEMDRAW,
      CDRF_NOTIFYPOSTERASE,
      CDRF_NOTIFYITEMERASE
    );
  var
    DrawInfo: PNMLVCustomDraw absolute NMHdr;
    Stage: TCustomDrawStage;
    DrawResult: TCustomDrawResult;
    ResultFlag: TCustomDrawResultFlag;
    OldDC: HDC;
  begin
    MsgResult := CDRF_DODEFAULT;
    WinProcess := False;
    if not ALV.IsCustomDrawn(dtControl, cdPrePaint) then
      exit;

    case DrawInfo^.nmcd.dwDrawStage and $7 of //Get drawing state
      CDDS_PREPAINT:  Stage := cdPrePaint;
      CDDS_POSTPAINT: Stage := cdPostPaint;
      CDDS_PREERASE:  Stage := cdPreErase;
      CDDS_POSTERASE: Stage := cdPostErase;
    else
      Exit;
    end;

    OldDC := ALV.Canvas.Handle;
    ALV.Canvas.Handle := DrawInfo^.nmcd.hdc;
    ALV.Canvas.Font.Assign(ALV.Font);
    ALV.Canvas.Brush.Assign(ALV.Brush);

    if DrawInfo^.nmcd.dwDrawStage and CDDS_SUBITEM <> 0 then
    begin
      // subitem 0 is handled by dtItem
      if DrawInfo^.iSubItem = 0 then Exit;
      DrawResult := ALV.IntfCustomDraw(dtSubItem, Stage,
        DrawInfo^.nmcd.dwItemSpec, DrawInfo^.iSubItem,
        ConvState(DrawInfo^.nmcd.uItemState), nil);
    end
    else
    if DrawInfo^.nmcd.dwDrawStage and CDDS_ITEM <> 0 then
      DrawResult := ALV.IntfCustomDraw(dtItem, Stage, DrawInfo^.nmcd.dwItemSpec,
        -1, ConvState(DrawInfo^.nmcd.uItemState), nil)
    else
      DrawResult := ALV.IntfCustomDraw(dtControl, Stage, -1, -1, [], @DrawInfo^.nmcd.rc); //Whole control

    if DrawResult <> [] then
      MsgResult := 0;

    if not (cdrSkipDefault in DrawResult) and
       (DrawInfo^.nmcd.dwDrawStage and CDDS_ITEMPREPAINT = CDDS_ITEMPREPAINT) then
    begin
      DrawInfo^.clrText := ColorToRGB(ALV.Canvas.Font.Color);
      DrawInfo^.clrTextBk := ColorToRGB(ALV.Canvas.Brush.Color);
    end;
    ALV.Canvas.Handle := OldDC;

    for ResultFlag := Low(ResultFlag) to High(ResultFlag) do
    begin
      if ResultFlag in DrawResult then
        MsgResult := MsgResult or CDRFRESULT[ResultFlag];
    end;
  end;

begin
  Result := False;
  case Msg of
    WM_NOTIFY:
    begin
      case PNMHdr(LParam)^.code of
        LVN_GETDISPINFOA, LVN_GETDISPINFOW:
          HandleListViewOwnerData(TCustomListViewAccess(AWinControl));
        NM_CUSTOMDRAW:
          HandleListViewCustomDraw(TCustomListViewAccess(AWinControl));
        LVN_BEGINDRAG, LVN_BEGINRDRAG: begin
            if ListViewWindProcInfo.ActiveListView = AWinControl then
              ListViewWindProcInfo.NoMouseUp := True;
          end;
      end;
    end;
  end;
end;
////////////////////////////////////////////////////////////////////////////////
// Event code
////////////////////////////////////////////////////////////////////////////////


////////////////////////////////////////////////////////////////////////////////
// Column code
////////////////////////////////////////////////////////////////////////////////

class procedure TWin32WSCustomListView.ColumnDoAutosize(const ALV: TCustomListView; const AIndex: Integer);
var
  CaptionSize: TSize;
begin
  if (ALV.Items.Count > 0) then
    ListView_SetColumnWidth(ALV.Handle, AIndex, LVSCW_AUTOSIZE)
  else
  begin
    // normally, we have to use ListView_GetStringWidth, but it doesn't work with
    // Unicode, so we take a universal function to get the width of the caption
    if GetTextExtentPoint32W(ALV.Canvas.Handle,
                             PWideChar(UTF8ToUTF16(ALV.Column[AIndex].Caption)),
                             UTF8Length(ALV.Column[AIndex].Caption),
                             CaptionSize) then
    begin
      // to retrieve the column width that can contain the string without
      // truncating it, you must add padding to the returned string width
      // see msdn: ListView_GetStringWidth
      // there is no way to get the needed padding size for a list view caption
      // so we take the height of the current caption text, to be DPI aware
      ListView_SetColumnWidth(ALV.Handle, AIndex, CaptionSize.cx + CaptionSize.cy);
    end
    else
      ListView_SetColumnWidth(ALV.Handle, AIndex, TListColumnAccess(ALV.Column[AIndex]).GetStoredWidth);
  end;
end;

class procedure TWin32WSCustomListView.ColumnDelete(const ALV: TCustomListView; const AIndex: Integer);
var
  hHdr, hLV: THandle;
  Count: Integer;
begin
  if not WSCheckHandleAllocated(ALV, 'ColumnDelete')
  then Exit;

  hLV := ALV.Handle;
  hHdr := GetHeader(hLV);
  if hHdr = 0 then Exit; //???

  Count := Header_GetItemCount(hHdr);
  if Count <= Aindex then Exit;

  // Move column to the last, otherwise our items get shuffeled
  if AIndex <> Count - 1 then
    ColumnMove(ALV, AIndex, Count - 1, nil);
  ListView_DeleteColumn(hLV, Count - 1);
end;

class function TWin32WSCustomListView.ColumnGetWidth(const ALV: TCustomListView; const AIndex: Integer; const AColumn: TListColumn): Integer;
var
  lvc: TLvColumn;
begin
  Result := -1;
  // this implementation uses columnwidht = 0 for invisible
  // so fallback to default (= AColumn.FWidth)
  // Don't return AColumn.Width, this will cause a loop
  if not AColumn.Visible then Exit;

  if not WSCheckHandleAllocated(ALV, 'ColumnGetWidth')
  then Exit;

  // do not use ListView_GetColumnWidth since we can not detect errors
  lvc.Mask := LVCF_WIDTH;
  if ListView_GetColumn(ALV.Handle, AIndex, lvc) <> 0
  then Result := lvc.cx;
end;

class procedure TWin32WSCustomListView.ColumnInsert(const ALV: TCustomListView; const AIndex: Integer; const AColumn: TListColumn);
var
  lvc: TLvColumn;
begin
  if not WSCheckHandleAllocated(ALV, 'ColumnInsert')
  then Exit;

  lvc.Mask := LVCF_TEXT;

  lvc.pszText := PChar(PWideChar(UTF8ToUTF16(AColumn.Caption)));
  SendMessage(ALV.Handle, LVM_INSERTCOLUMNW, WPARAM(AIndex), LPARAM(@lvc));
end;

class procedure TWin32WSCustomListView.ColumnMove(const ALV: TCustomListView; const AOldIndex, ANewIndex: Integer; const AColumn: TListColumn);
var
  lvc, oldlvc: TLvColumn_v4_7;
  buf, oldbuf: array[0..1024] of Char;
  Count, idx: Integer;

begin
  if not WSCheckHandleAllocated(ALV, 'ColumnMove')
  then Exit;

  Count := AOldIndex - ANewIndex;

  // Fetch old column values
  oldlvc.lvc.Mask := LVCF_FMT or LVCF_IMAGE or LVCF_TEXT or LVCF_WIDTH;
  oldlvc.lvc.pszText := @oldbuf[0];
  oldlvc.lvc.cchTextMax := SizeOF(oldbuf);
  ListView_GetColumn(ALV.Handle, AOldIndex, oldlvc.lvc);

  idx := AOldIndex;
  while Count <> 0 do
  begin
    // get next index
    if Count < 0
    then Inc(idx)
    else Dec(idx);
    // and data
    lvc.lvc.Mask := LVCF_FMT or LVCF_IMAGE or LVCF_TEXT or LVCF_WIDTH;
    lvc.lvc.pszText := @buf[0];
    lvc.lvc.cchTextMax := SizeOF(buf);
    ListView_GetColumn(ALV.Handle, idx, lvc.lvc);
    // set data
    ListView_SetColumn(ALV.Handle, ANewIndex + Count, lvc.lvc);

    if Count < 0
    then Inc(Count)
    else Dec(Count);
  end;
  // finally copy original data to new column
  ListView_SetColumn(ALV.Handle, ANewIndex, oldlvc.lvc);
end;

class procedure TWin32WSCustomListView.ColumnSetAlignment(const ALV: TCustomListView; const AIndex: Integer; const AColumn: TListColumn; const AAlignment: TAlignment);
const
  JUSTIFICATION: array[TAlignment] of Integer = (
    LVCFMT_LEFT,
    LVCFMT_RIGHT,
    LVCFMT_CENTER
  );
var
  lvc: TLvColumn;
begin
  if not WSCheckHandleAllocated(ALV, 'ColumnSetAlignment')
  then Exit;

  lvc.Mask := LVCF_FMT;
  ListView_GetColumn(ALV.Handle, AIndex, lvc);
  lvc.fmt := (lvc.fmt and not LVCFMT_JUSTIFYMASK) or JUSTIFICATION[AAlignment];
  ListView_SetColumn(ALV.Handle, AIndex, lvc);
end;

class procedure TWin32WSCustomListView.ColumnSetAutoSize(const ALV: TCustomListView; const AIndex: Integer; const AColumn: TListColumn; const AAutoSize: Boolean);
begin
  if not WSCheckHandleAllocated(ALV, 'ColumnSetAutoSize')
  then Exit;

  if AAutoSize
  then ColumnDoAutosize(ALV, AIndex)
  else ListView_SetColumnWidth(ALV.Handle, AIndex, TListColumnAccess(AColumn).GetStoredWidth);
end;

class procedure TWin32WSCustomListView.ColumnSetCaption(const ALV: TCustomListView; const AIndex: Integer; const AColumn: TListColumn; const ACaption: String);
var
  lvc: TLvColumn;
begin
  if not WSCheckHandleAllocated(ALV, 'ColumnSetCaption')
  then Exit;

  lvc.Mask := LVCF_TEXT;

  lvc.pszText := PChar(PWideChar(UTF8ToUTF16(AColumn.Caption)));
  SendMessage(ALV.Handle, LVM_SETCOLUMNW, WPARAM(AIndex), LPARAM(@lvc));
end;

class procedure TWin32WSCustomListView.ColumnSetImage(const ALV: TCustomListView; const AIndex: Integer; const AColumn: TListColumn; const AImageIndex: Integer);
var
  lvc: TLvColumn_v4_7;
begin
  if not WSCheckHandleAllocated(ALV, 'ColumnSetImage')
  then Exit;

  // forst get the old lvc, since we have to tell the bloody thing that this
  // column has an image otherwise we will have a crash on XP using comctl 6

  lvc.lvc.Mask := LVCF_FMT;
  ListView_GetColumn(ALV.Handle, AIndex, lvc.lvc);

  if AImageIndex = -1
  then begin
    lvc.lvc.Mask := LVCF_FMT;
    lvc.lvc.fmt := lvc.lvc.fmt and not (LVCFMT_IMAGE or LVCFMT_COL_HAS_IMAGES);
  end
  else begin
    lvc.lvc.Mask := LVCF_IMAGE or LVCF_FMT;
    lvc.lvc.fmt := lvc.lvc.fmt or LVCFMT_IMAGE or LVCFMT_COL_HAS_IMAGES;
    lvc.iImage := AImageIndex;
  end;

  ListView_SetColumn(ALV.Handle, AIndex, lvc.lvc);
end;

class procedure TWin32WSCustomListView.ColumnSetMaxWidth(const ALV: TCustomListView; const AIndex: Integer; const AColumn: TListColumn; const AMaxWidth: Integer);
begin
  if not WSCheckHandleAllocated(ALV, 'ColumnSetMaxWidth')
  then Exit;

  // TODO: in messageHandler
end;

class procedure TWin32WSCustomListView.ColumnSetMinWidth(const ALV: TCustomListView; const AIndex: Integer; const AColumn: TListColumn; const AMinWidth: integer);
begin
  if not WSCheckHandleAllocated(ALV, 'ColumnSetMinWidth')
  then Exit;

  // TODO: in messageHandler
end;

class procedure TWin32WSCustomListView.ColumnSetWidth(const ALV: TCustomListView; const AIndex: Integer; const AColumn: TListColumn; const AWidth: Integer);
begin
  if not WSCheckHandleAllocated(ALV, 'ColumnSetWidth')
  then Exit;

  if AColumn.AutoSize
  then ColumnDoAutosize(ALV, AIndex)
  else ListView_SetColumnWidth(ALV.Handle, AIndex, AWidth)
end;

class procedure TWin32WSCustomListView.ColumnSetVisible(const ALV: TCustomListView; const AIndex: Integer; const AColumn: TListColumn; const AVisible: Boolean);
begin
  if not WSCheckHandleAllocated(ALV, 'ColumnSetVisible')
  then Exit;

  // TODO: implement with LV_COLUMN.subitem (associate different columns and insert/delete last.

  if AVisible
  then if AColumn.AutoSize
    then ColumnDoAutosize(ALV, AIndex)
    else ListView_SetColumnWidth(ALV.Handle, AIndex, TListColumnAccess(AColumn).GetStoredWidth)
  else ListView_SetColumnWidth(ALV.Handle, AIndex, 0);
end;

class procedure TWin32WSCustomListView.ColumnSetSortIndicator(
  const ALV: TCustomListView; const AIndex: Integer;
  const AColumn: TListColumn; const AAndicator: TSortIndicator);
var
  Hdr: HWND;
  Itm: THDITEM;
begin
  if not WSCheckHandleAllocated(ALV, 'ColumnSetSortIndicator')
  then Exit;

  Hdr := ListView_GetHeader(ALV.Handle);
  FillChar(itm, sizeof(itm),0);
  itm.mask := HDI_FORMAT;
  Header_GetItem(Hdr, AIndex, Itm);
  case AAndicator of
    siNone:        itm.fmt := itm.fmt and (not (HDF_SORTDOWN or HDF_SORTUP));
    siAscending:   itm.fmt := (itm.fmt or HDF_SORTUP) and (not HDF_SORTDOWN);
    siDescending:  itm.fmt := (itm.fmt or HDF_SORTDOWN) and (not HDF_SORTUP);
  end;
  Header_SetItem(Hdr, AIndex, Itm);
end;

////////////////////////////////////////////////////////////////////////////////
// Item code
////////////////////////////////////////////////////////////////////////////////

class procedure TWin32WSCustomListView.ItemDelete(const ALV: TCustomListView; const AIndex: Integer);
begin
  if not WSCheckHandleAllocated(ALV, 'ItemDelete')
  then Exit;

  ListView_DeleteItem(ALV.Handle, AIndex);
end;

class function TWin32WSCustomListView.ItemDisplayRect(const ALV: TCustomListView; const AIndex, ASubItem: Integer; ACode: TDisplayCode):TRect; 
const 
  DISPLAYCODES: array[TDisplayCode] of DWORD=(LVIR_BOUNDS, LVIR_ICON, LVIR_LABEL, LVIR_SELECTBOUNDS);
var
  mes: uint;
begin
  Result := Rect(0,0,0,0);
  if not WSCheckHandleAllocated(ALV, 'ItemDisplayRect')
  then Exit;                                          
  
  if ASubItem = 0 
  then mes:=LVM_GETITEMRECT
  else begin
    mes:=LVM_GETSUBITEMRECT;
    if ACode = drSelectBounds 
    then ACode := drBounds;
  end;
  Result.top := ASubItem;
  Result.left := DISPLAYCODES[ACode];
  SendMessage(ALV.Handle, mes, AIndex, lparam(@Result));
end;

class procedure TWin32WSCustomListView.LVItemAssign(const ALV: TCustomListView;
  AItem: TListItem; const AIndex: Integer);
var
  i: Integer;
  B: Boolean;
begin
  if ALV.CheckBoxes then
    B := AItem.Checked
  else
    B := False;

  // apply texts
  ItemSetText(ALV, AIndex, AItem, 0, AItem.Caption);
  for i := 0 to AItem.SubItems.Count - 1 do
    ItemSetText(ALV, AIndex, AItem, i + 1, AItem.SubItems[i]);
  // make sure no texts are left over
  for i := AItem.SubItems.Count to ALV.ColumnCount-1 do
    ItemSetText(ALV, AIndex, AItem, i + 1, '');

  // set state image
  ItemSetStateImage(ALV, AIndex,AItem,0, AItem.StateIndex);

  // set image
  ItemSetImage(ALV, AIndex, AItem, 0, AItem.ImageIndex);

  // apply checkbox state
  ItemSetChecked(ALV, AIndex, AItem, B);
end;

class procedure TWin32WSCustomListView.ItemExchange(const ALV: TCustomListView;
  AItem: TListItem; const AIndex1, AIndex2: Integer);
var
  AItem1, AItem2: TListItem;
begin
  if not WSCheckHandleAllocated(ALV, 'ItemExchange') then
    exit;

  //We have to reassign TLvItem to AIndex1 and AIndex2
  //or use RecreateWnd() which is very expensive

  AItem1 := ALV.Items[AIndex2];
  AItem2 := ALV.Items[AIndex1];

  LVItemAssign(ALV, AItem1, AIndex2);
  LVItemAssign(ALV, AItem2, AIndex1);
end;

class procedure TWin32WSCustomListView.ItemMove(const ALV: TCustomListView;
  AItem: TListItem; const AFromIndex, AToIndex: Integer);
var
  i: Integer;
begin
  if not WSCheckHandleAllocated(ALV, 'ItemMove') then
    exit;
  if AFromIndex = AToIndex then
    exit;
  if AFromIndex > AToIndex then
  begin
    for i := AToIndex to AFromIndex do
      LVItemAssign(ALV, ALV.Items[i], i);
  end else
    for i := AFromIndex to AToIndex do
      LVItemAssign(ALV, ALV.Items[i], i);
end;

class function TWin32WSCustomListView.ItemGetChecked(const ALV: TCustomListView; const AIndex: Integer; const AItem: TListItem): Boolean;
begin
  Result := False;
  if not WSCheckHandleAllocated(ALV, 'ItemGetChecked')
  then Exit;
  // shr 12 will give teh stateimage index, however a value of 
  // 0 means no image and 1 means unchecked. All other 14 are checked (?)
  // so shifting 13 will always result in something <> 0 when checked.
  Result := SendMessage(ALV.Handle, LVM_GETITEMSTATE, AIndex, LVIS_STATEIMAGEMASK) shr 13 <> 0;
end;

class function TWin32WSCustomListView.ItemGetPosition(
  const ALV: TCustomListView; const AIndex: Integer): TPoint;
begin
  Result := Point(0, 0);
  if WSCheckHandleAllocated(ALV, 'ItemGetPosition') then
    SendMessage(ALV.Handle, LVM_GETITEMPOSITION, AIndex, LPARAM(@Result));
end;

class function TWin32WSCustomListView.ItemGetState(const ALV: TCustomListView;
  const AIndex: Integer; const AItem: TListItem; const AState: TListItemState;
  out AIsSet: Boolean): Boolean;
const
  // lisCut, lisDropTarget, lisFocused, lisSelected
  FLAGS: array[TListItemState] of Integer = (LVIS_CUT, LVIS_DROPHILITED, LVIS_FOCUSED, LVIS_SELECTED);
begin
  Result := False;

  if not WSCheckHandleAllocated(ALV, 'ItemGetState')
  then Exit;

  AIsSet := 0 <> ListView_GetItemState(ALV.Handle, AIndex, FLAGS[AState]);
  Result := True;
end;

class function TWin32WSCustomListView.ItemGetStates(const ALV: TCustomListView; const AIndex: Integer; out AStates: TListItemStates): Boolean;
const
  MASK = LVIS_CUT or LVIS_DROPHILITED or LVIS_FOCUSED or LVIS_SELECTED;
var
  Flags: Integer;
begin
  Result := False;

  if not WSCheckHandleAllocated(ALV, 'ItemGetStates')
  then Exit;

  AStates := [];
  Flags := ListView_GetItemState(ALV.Handle, AIndex, MASK);
  if (Flags and LVIS_CUT) <> 0 then
    Include(AStates, lisCut);
  if (Flags and LVIS_DROPHILITED) <> 0 then
    Include(AStates, lisDropTarget);
  if (Flags and LVIS_FOCUSED) <> 0 then
    Include(AStates, lisFocused);
  if (Flags and LVIS_SELECTED) <> 0 then
    Include(AStates, lisSelected);

  Result := True;
end;

class procedure TWin32WSCustomListView.ItemInsert(const ALV: TCustomListView; const AIndex: Integer; const AItem: TListItem);
var
  lvi: TLvItem;
begin
  if not WSCheckHandleAllocated(ALV, 'ItemInsert')
  then Exit;

  lvi.Mask := LVIF_TEXT or LVIF_PARAM;
  lvi.iItem := AIndex;
  lvi.iSubItem := 0;
  lvi.lParam := LPARAM(AItem);

  lvi.pszText := PChar(PWideChar(UTF8ToUTF16(AItem.Caption)));
  SendMessage(ALV.Handle, LVM_INSERTITEMW, 0, LPARAM(@lvi));
end;

class procedure TWin32WSCustomListView.ItemSetChecked(const ALV: TCustomListView; const AIndex: Integer; const AItem: TListItem; const AChecked: Boolean);
begin
  if not WSCheckHandleAllocated(ALV, 'ItemSetChecked')
  then Exit;

  if AChecked then
    ListView_SetItemState(ALV.Handle, AIndex, IndexToStateImageMask(2), LVIS_STATEIMAGEMASK)
  else
    ListView_SetItemState(ALV.Handle, AIndex, IndexToStateImageMask(1), LVIS_STATEIMAGEMASK);
end;

class procedure TWin32WSCustomListView.ItemSetImage(const ALV: TCustomListView; const AIndex: Integer; const AItem: TListItem; const ASubIndex, AImageIndex: Integer);
var
  lvi: TLvItem;
begin
  if not WSCheckHandleAllocated(ALV, 'ItemSetImage')
  then Exit;

  lvi.Mask := LVIF_IMAGE;
  lvi.iItem := AIndex;
  lvi.iSubItem := ASubIndex;
  lvi.iImage := AImageIndex;

  ListView_SetItem(ALV.Handle, lvi);
end;

class function TWin32WSCustomListView.ItemSetPosition(const ALV: TCustomListView; const AIndex: Integer; const ANewPosition: TPoint): Boolean;
begin
  if not WSCheckHandleAllocated(ALV, 'ItemSetPosition') then
    Result := False
  else
    Result := SendMessage(ALV.Handle, LVM_SETITEMPOSITION,
      AIndex, MAKELPARAM(ANewPosition.X, ANewPosition.Y)) <> 0;
end;

class procedure TWin32WSCustomListView.ItemSetStateImage(const ALV: TCustomListView; const AIndex: Integer; const AItem: TListItem; const ASubIndex, AStateImageIndex: Integer);
begin
  if not WSCheckHandleAllocated(ALV, 'ItemSetStateImage')
  then Exit;

  ListView_SetItemState(ALV.Handle, AIndex, IndexToStateImageMask(AStateImageIndex + 1), LVIS_STATEIMAGEMASK);
end;

class procedure TWin32WSCustomListView.ItemSetState(const ALV: TCustomListView; const AIndex: Integer; const AItem: TListItem; const AState: TListItemState; const AIsSet: Boolean);
const
  // lisCut, lisDropTarget, lisFocused, lisSelected
  FLAGS: array[TListItemState] of Integer = (LVIS_CUT, LVIS_DROPHILITED, LVIS_FOCUSED, LVIS_SELECTED);
begin
  if not WSCheckHandleAllocated(ALV, 'ItemSetState')
  then Exit;
  {Don't change the state if it already has needed value}
  if ((ListView_GetItemState(ALV.Handle, AIndex, FLAGS[AState]) and FLAGS[AState]) = FLAGS[AState]) = AIsSet then exit;

  if AIsSet
  then ListView_SetItemState(ALV.Handle, AIndex, FLAGS[AState], FLAGS[AState])
  else ListView_SetItemState(ALV.Handle, AIndex, 0, FLAGS[AState]);
end;

class procedure TWin32WSCustomListView.ItemSetText(const ALV: TCustomListView; const AIndex: Integer; const AItem: TListItem; const ASubIndex: Integer; const AText: String);
var
  _gnu_lvi : LV_ITEM;
begin
  if not WSCheckHandleAllocated(ALV, 'ItemSetText')
  then Exit;

  _gnu_lvi.iSubItem := ASubIndex;
  _gnu_lvi.pszText := PChar(PWideChar(UTF8ToUTF16(AText)));

  SendMessage(ALV.Handle, LVM_SETITEMTEXTW, WPARAM(AIndex), LPARAM(@_gnu_lvi));
  // autosize is an *extreme* performance bottleneck, even if WM_SETREDRAW
  // was set to false it will ignore this and still redraw all columns.
  // We will therefore postpone all autosizing until EndUpdate where we do
  // it only once per column.

  if (ASubIndex >= 0) and (ASubIndex < ALV.ColumnCount) and ALV.Column[ASubIndex].AutoSize and (TCustomListViewAccess(ALV).GetUpdateCount = 0) then
    ColumnDoAutosize(ALV, ASubIndex);
end;

class procedure TWin32WSCustomListView.ItemShow(const ALV: TCustomListView; const AIndex: Integer; const AItem: TListItem; const PartialOK: Boolean);
begin
  if not WSCheckHandleAllocated(ALV, 'ItemShow')
  then Exit;

  ListView_EnsureVisible(ALV.Handle, AIndex, Ord(PartialOK));
end;

////////////////////////////////////////////////////////////////////////////////
// LV code
////////////////////////////////////////////////////////////////////////////////

procedure ListViewDrawItem(const AWinControl: TWinControl; Window: HWnd;
  Msg: UInt; WParam: Windows.WParam; const DrawIS: TDrawItemStruct;
  var ItemMsg: Integer; var DrawListItem: Boolean);
begin
  DrawListItem := (AWinControl is TListView) and
      (TListView(AWinControl).ViewStyle = vsReport) and
      (DrawIS.ctlType = ODT_LISTVIEW) and
      (TListView(AWinControl).OwnerDraw);
  ItemMsg := CN_DRAWITEM;
end;

function ListViewProc(Window: HWnd; Msg: UInt; WParam: Windows.WParam;
    LParam: Windows.LParam): LResult; stdcall;

  function GetClientCursorPos(ClientWindow: HWND) : TPoint;
  begin
    Windows.GetCursorPos(Result);
      Windows.ScreenToClient(ClientWindow, Result);
  end;

var
  WindowInfo: PWin32WindowInfo;
  ListItem: TListItem;
  ListView: TCustomListView;
  AMsg: UINT;
  MPos: TPoint;
begin
  case Msg of
    WM_CONTEXTMENU:
      begin
        if ListViewWindProcInfo.ActiveListView <> nil then begin
          Result := 1;
          exit;
        end;
      end;
    WM_LBUTTONDOWN, WM_RBUTTONDOWN:
      begin
      (*
         A ListView doesn't get a WM_LBUTTONUP, WM_RBUTTONUP message,
         because it keeps the message in its own event loop,
         see msdn article about "Default List-View Message Processing"
         therefore we take this notification and create a
         LM_LBUTTONUP, LM_RBUTTONUP message out of it.

         - When the ListView starts dragging (LVN_BEGIN(R)DRAG), it will get the
           mouse up
         - The WindProg for the WM_LBUTTONUP, WM_RBUTTONUP does not always
           return immediately (multi select). It will return on either mouse up
           or BeginDrag.
           The LCL mouse down event is executed with the same delay.
         - Also see issue #33330
      *)

        WindowInfo := GetWin32WindowInfo(Window);
        ListView := TListView(WindowInfo^.WinControl);
        ListItem := ListView.GetItemAt(GET_X_LPARAM(LParam), GET_Y_LPARAM(LParam));

        if Msg = WM_LBUTTONDOWN
        then AMsg := LM_LBUTTONUP
        else AMsg := LM_RBUTTONUP;

        ListViewWindProcInfo.ActiveListView := ListView;
        ListViewWindProcInfo.NoMouseUp := False;
        try
          Result := WindowProc(Window, Msg, WParam, LParam);
        finally
          ListViewWindProcInfo.ActiveListView:= nil;
        end;

        if (not ListViewWindProcInfo.NoMouseUp) and
           (Assigned(ListItem) or ListView.MultiSelect)
        then
        begin
          MPos := GetClientCursorPos(Window);
          PostMessage(Window, AMsg, 0, Windows.MakeLParam(MPos.X, MPos.Y));
        end;
        exit;
      end;
  end;
  Result := WindowProc(Window, Msg, WParam, LParam);
end;

class function TWin32WSCustomListView.CreateHandle(const AWinControl: TWinControl;
  const AParams: TCreateParams): HWND;
const
  LISTVIEWSTYLES: array[TViewStyle] of DWORD = (LVS_ICON, LVS_SMALLICON, LVS_LIST, LVS_REPORT);
  Arrangement: array[TIconArrangement] of DWord = (LVS_ALIGNTOP, LVS_ALIGNLEFT);
var
  Params: TCreateWindowExParams;
begin
  // general initialization of Params
  PrepareCreateWindow(AWinControl, AParams, Params);
  // customization of Params
  with Params do
  begin
    pClassName := WC_LISTVIEW;
    SubClassWndProc := @ListViewProc;
    WindowTitle := StrCaption;
    Flags := Flags or LISTVIEWSTYLES[TListView(AWinControl).ViewStyle] or
      LVS_SINGLESEL or LVS_SHAREIMAGELISTS or
      Arrangement[TListView(AWinControl).IconOptions.Arrangement];
    if TCustomListView(AWinControl).OwnerData then 
      Flags := Flags or LVS_OWNERDATA;
    if TListView(AWinControl).OwnerDraw then
      Flags := Flags or LVS_OWNERDRAWFIXED;
    if TCustomListView(AWinControl).BorderStyle = bsSingle then
      FlagsEx := FlagsEx or WS_EX_CLIENTEDGE;
  end;
  // create window
  FinishCreateWindow(AWinControl, Params, false);
  Params.WindowInfo^.ParentMsgHandler := @ListViewParentMsgHandler;
  Params.WindowInfo^.needParentPaint := false;
  Params.WindowInfo^.DrawItemHandler := @ListViewDrawItem;
  Result := Params.Window;
  if TCustomListView(AWinControl).checkboxes
    then UpdateExStyle(result,lvs_ex_SubitemImages or lvs_Ex_Checkboxes,lvs_ex_SubitemImages or lvs_Ex_Checkboxes) else
  UpdateExStyle(Result, LVS_EX_SUBITEMIMAGES, LVS_EX_SUBITEMIMAGES);
end;

class procedure TWin32WSCustomListView.BeginUpdate(const ALV: TCustomListView);
begin
  if not WSCheckHandleAllocated(ALV, 'BeginUpdate')
  then Exit;

  SendMessage(ALV.Handle,WM_SETREDRAW,WPARAM(False),0);
end;

class procedure TWin32WSCustomListView.EndUpdate(const ALV: TCustomListView);
var
  ColIndex : Integer;
begin
  if not WSCheckHandleAllocated(ALV, 'EndUpdate')
  then Exit;

  // we have skipped all column resizing in ItemSetText()
  // for performance reasons, so now we need to do it here.
  //
  // A further significant perfomance boost and reduced flickering
  // can be achieved by setting the widget to invisible during the
  // following operation (it ignores the state of WM_SETREDRAW for
  // column resizing, but this way we we can really enforce it).
  // ShowWindow() itself does not force an immediate redraw,
  // so it won't flicker at all.
  ShowWindow(ALV.Handle, SW_HIDE);
  for ColIndex := 0 to TCustomListViewAccess(ALV).Columns.Count - 1 do
    if ALV.Column[ColIndex].AutoSize
    then ColumnDoAutosize(ALV, ColIndex);

  SendMessage(ALV.Handle,WM_SETREDRAW,WPARAM(True),0);
  if ALV.Visible then
    ShowWindow(ALV.Handle, SW_SHOW);
end;

class function TWin32WSCustomListView.GetBoundingRect(const ALV: TCustomListView): TRect;
begin
  Result := Rect(0,0,0,0); 
  if not WSCheckHandleAllocated(ALV, 'GetBoundingRect')
  then Exit;

  ListView_GetViewRect(ALV.Handle, Result);
end;

class function TWin32WSCustomListView.GetDropTarget(const ALV: TCustomListView): Integer;
begin
  Result := -1; 
  if not WSCheckHandleAllocated(ALV, 'GetDropTarget')
  then Exit;

  Result := ListView_GetNextItem(ALV.Handle, -1, LVNI_ALL or LVNI_DROPHILITED);
end;

class function TWin32WSCustomListView.GetFocused(const ALV: TCustomListView): Integer;
begin       
  Result := -1; 
  if not WSCheckHandleAllocated(ALV, 'GetFocused')
  then Exit;

  Result := ListView_GetNextItem(ALV.Handle, -1, LVNI_ALL or LVNI_FOCUSED);
end;

class function TWin32WSCustomListView.GetHitTestInfoAt( const ALV: TCustomListView; X, Y: Integer ) : THitTests;
var
  HitInfo: LV_HITTESTINFO;

begin
  Result := [];
  if not WSCheckHandleAllocated(ALV, 'GetHitTestInfoAt')
  then Exit;

  with HitInfo do
  begin
    pt.X := X;
    pt.Y := Y;
    ListView_HitTest( ALV.Handle, HitInfo );

    if ((flags and LVHT_ABOVE) <> 0) and (Y < 0) then
      Include(Result, htAbove);

    if (flags and LVHT_BELOW) <> 0 then
      Include(Result, htBelow);

    if (flags and LVHT_NOWHERE) <> 0 then
      Include(Result, ComCtrls.htNowhere);

    if (flags and LVHT_ONITEM) = LVHT_ONITEM then
      Include(Result, htOnItem)

    else
      begin
      if (flags and LVHT_ONITEMICON) <> 0 then
        Include(Result, htOnIcon);

      if (flags and LVHT_ONITEMLABEL) <> 0 then
        Include(Result, htOnLabel);

      if (flags and LVHT_ONITEMSTATEICON) <> 0 then
        Include(Result, htOnStateIcon);

      end;

    if (flags and LVHT_TOLEFT) <> 0 then
      Include(Result, htToLeft);

    if (flags and LVHT_TORIGHT) <> 0 then
      Include(Result, htToRight);

  end;
end;

class function TWin32WSCustomListView.GetHoverTime(const ALV: TCustomListView): Integer;
begin
  Result := -1; 
  if not WSCheckHandleAllocated(ALV, 'GetHoverTime')
  then Exit;

  Result := SendMessage(ALV.Handle, LVM_GETHOVERTIME, 0, 0);
end;

class function TWin32WSCustomListView.GetItemAt(const ALV: TCustomListView; x,
  y: Integer): Integer;
var 
  HitInfo: LV_HITTESTINFO;
begin
  Result := -1; 
  if not WSCheckHandleAllocated(ALV, 'GetItemAt')
  then Exit;

  HitInfo.pt.x:=x;
  HitInfo.pt.y:=y;
  ListView_HitTest(alv.Handle,HitInfo);
  if HitInfo.flags <> LVHT_NOWHERE 
  then Result:=HitInfo.iItem;
end;

class function TWin32WSCustomListView.GetSelCount(const ALV: TCustomListView): Integer;
begin
  Result := 0;
  if not WSCheckHandleAllocated(ALV, 'GetSelCount')
  then Exit;

  Result := ListView_GetSelectedCount(ALV.Handle);
end;

class function TWin32WSCustomListView.GetSelection(const ALV: TCustomListView): Integer;
begin
  Result := -1;
  if not WSCheckHandleAllocated(ALV, 'GetSelection')
  then Exit;

  Result := ListView_GetNextItem(ALV.Handle, -1, LVNI_ALL or LVNI_SELECTED);
end;

class function TWin32WSCustomListView.GetTopItem(const ALV: TCustomListView): Integer;
begin
  Result := -1;
  if not WSCheckHandleAllocated(ALV, 'GetTopItem')
  then Exit;

  case GetWindowLong(ALV.Handle, GWL_STYLE) and LVS_TYPEMASK of
    LVS_LIST,
    LVS_REPORT: Result := ListView_GetTopIndex(ALV.Handle);
  else
    Result := -1;
  end;
end;

class function TWin32WSCustomListView.GetViewOrigin(const ALV: TCustomListView): TPoint;
begin
  if not WSCheckHandleAllocated(ALV, 'GetViewOrigin')
  then begin
    Result := Point(0, 0);
    Exit;
  end;

  ListView_GetOrigin(ALV.Handle, Result);
end;

class function TWin32WSCustomListView.GetVisibleRowCount(const ALV: TCustomListView): Integer;
begin
  Result := 0;
  if not WSCheckHandleAllocated(ALV, 'GetVisibleRowCount')
  then Exit;

  case GetWindowLong(ALV.Handle, GWL_STYLE) and LVS_TYPEMASK of
    LVS_LIST,
    LVS_REPORT: Result := ListView_GetCountPerPage(ALV.Handle);
  else
    Result := -1;
  end;
end;

class procedure TWin32WSCustomListView.SelectAll(const ALV: TCustomListView;
  const AIsSet: Boolean);
begin
  if not WSCheckHandleAllocated(ALV, 'SelectAll') then
    exit;
  // Index param -1 means select all.
  if AIsSet then
    ListView_SetItemState(ALV.Handle, -1, LVIS_SELECTED, LVIS_SELECTED)
  else
    ListView_SetItemState(ALV.Handle, -1, 0, LVIS_SELECTED);
end;

class function TWin32WSCustomListView.GetHeader(const AHandle: THandle): THandle;
begin
  Result := THandle(SendMessage(AHandle, LVM_GETHEADER, 0, 0));
  if Result <> 0 then Exit;

  // probably old version, try the first child
  Result := GetWindow(AHandle, GW_CHILD);
end;

// MWE: original from MS knowledgebase KB137520
(********************************************************************
    PositionHeader

    Call this function when the ListView is created, resized, the
    view is changed, or a WM_SYSPARAMETERCHANGE message is received.

 ********************************************************************)
class procedure TWin32WSCustomListView.PositionHeader(const AHandle: THandle);
var
  hwndHeader: HWND;
  dwStyle: PtrInt;
  rc: TRect;
  hdLayout: THDLAYOUT;
  wpos: Windows.TWINDOWPOS;
begin
  dwStyle := GetWindowLong(AHandle, GWL_STYLE);

  if dwStyle and LVS_NOSCROLL = 0 then Exit; // nothing to do
  if dwStyle and LVS_REPORT = 0 then Exit;   // nothing to do

  hwndHeader := GetHeader(AHandle);
  if hwndHeader = 0 then Exit; // nothing to do

  Windows.GetClientRect(AHandle, rc);
  FillChar(hdLayout, SizeOf(hdLayout), 0);
  hdLayout.prc := @rc;
  hdLayout.pwpos := @wpos;
  Header_Layout(hwndHeader, hdLayout);

  Windows.SetWindowPos(hwndHeader,
                       wpos.hwndInsertAfter,
                       wpos.x,
                       wpos.y,
                       wpos.cx,
                       wpos.cy,
                       wpos.flags or SWP_SHOWWINDOW);

  ListView_EnsureVisible(AHandle, 0, 0);
end;

class procedure TWin32WSCustomListView.SetAllocBy(const ALV: TCustomListView; const AValue: Integer);
begin
  if not WSCheckHandleAllocated(ALV, 'SetAllocBy')
  then Exit;

  ListView_SetItemCount(ALV.Handle, AValue);
end;

class procedure TWin32WSCustomListView.SetBorderStyle(const AWinControl: TWinControl; const ABorderStyle: TBorderStyle);
begin
  if not WSCheckHandleAllocated(AWinControl, 'TWin32WSCustomListView.SetBorder') then
    Exit;
  // changing border style by changing EXSTYLE here does not work correctly
  RecreateWnd(AWinControl);
end;

class procedure TWin32WSCustomListView.SetColor(const AWinControl: TWinControl);
var
  Color: TColor;
begin
  if not WSCheckHandleAllocated(AWinControl, 'TWin32WSCustomListView.SetColor') then
    Exit;
  Color := AWinControl.Color;
  if Color = clDefault then
    Color := AWinControl.GetDefaultColor(dctBrush);
  Windows.SendMessage(AWinControl.Handle, LVM_SETBKCOLOR, 0, ColorToRGB(Color));
  Windows.SendMessage(AWinControl.Handle, LVM_SETTEXTBKCOLOR, 0, ColorToRGB(Color));
end;

class procedure TWin32WSCustomListView.SetDefaultItemHeight(const ALV: TCustomListView; const AValue: Integer);
begin
  if not WSCheckHandleAllocated(ALV, 'SetDefaultItemHeight')
  then Exit;

  // TODO ???
end;

class procedure TWin32WSCustomListView.SetFont(const AWinControl: TWinControl; const AFont: TFont);
var
  Color: TColor;
begin
  // call inherited SetFont; need to do it this way,
  // because the compile time ancestor class is TWSCustomListView
  TWSWinControlClass(ClassParent).SetFont(AWinControl, AFont);
  Color := AFont.Color;
  if Color = clDefault then
   Color := AWinControl.GetDefaultColor(dctFont);
  Windows.SendMessage(AWinControl.Handle, LVM_SETTEXTCOLOR, 0, ColorToRGB(Color));
end;

class procedure TWin32WSCustomListView.SetHotTrackStyles(const ALV: TCustomListView; const AValue: TListHotTrackStyles);
const
  MASK = LVS_EX_ONECLICKACTIVATE or LVS_EX_TWOCLICKACTIVATE or LVS_EX_UNDERLINEHOT or LVS_EX_UNDERLINECOLD;
var
  Style: Integer;
begin
  if not WSCheckHandleAllocated(ALV, 'SetHotTrackStyles')
  then Exit;

  if htHandPoint in AValue
  then Style := LVS_EX_ONECLICKACTIVATE
  else if [htUnderlineHot, htUnderlineCold] * AValue <> []
  then Style := LVS_EX_TWOCLICKACTIVATE
  else Style := 0;

  if htUnderlineHot in AValue
  then Style := Style or LVS_EX_UNDERLINEHOT;

  if htUnderlineCold in AValue
  then Style := Style or LVS_EX_UNDERLINECOLD;

  UpdateExStyle(ALV.Handle, MASK, Style);
end;

class procedure TWin32WSCustomListView.SetHoverTime(const ALV: TCustomListView; const AValue: Integer);
begin
  if not WSCheckHandleAllocated(ALV, 'SetHoverTime')
  then Exit;

  SendMessage(ALV.Handle, LVM_SETHOVERTIME, 0, AValue);
end;

class procedure TWin32WSCustomListView.SetIconArrangement(
  const ALV: TCustomListView; const AValue: TIconArrangement);
const
  ArrangementMap: array[TIconArrangement] of DWord = (
    { iaTop  } LVS_ALIGNTOP,
    { iaLeft } LVS_ALIGNLEFT
  );
begin
  if not WSCheckHandleAllocated(ALV, 'SetIconArrangement')
  then Exit;

  // LVM_ALIGN styles are not implemented in windows (according to w7 sdk) => change style
  UpdateStyle(ALV.Handle, LVS_ALIGNMASK, ArrangementMap[AValue]);
end;

class procedure TWin32WSCustomListView.SetImageList(const ALV: TCustomListView;
  const AList: TListViewImageList; const AValue: TCustomImageListResolution);
const
  LIST_MAP: array[TListViewImageList] of WPARAM = (
   {lvilSmall} LVSIL_SMALL,
   {lvilLarge} LVSIL_NORMAL,
   {lvilState} LVSIL_STATE
  );
begin
  if not WSCheckHandleAllocated(ALV, 'SetImageList')
  then Exit;

  if AValue <> nil then
    SendMessage(ALV.Handle, LVM_SETIMAGELIST, LIST_MAP[AList], AValue.Reference._Handle)
  else
    SendMessage(ALV.Handle, LVM_SETIMAGELIST, LIST_MAP[AList], 0);
end;

class procedure TWin32WSCustomListView.SetItemsCount(const ALV: TCustomListView; const AValue: Integer); 
begin
  if not WSCheckHandleAllocated(ALV, 'SetItemsCount')
  then Exit;
  SendMessage(ALV.Handle, LVM_SETITEMCOUNT, AValue, 0);
end;

class procedure TWin32WSCustomListView.SetOwnerData(const ALV: TCustomListView; const AValue: Boolean); 
begin
  if not WSCheckHandleAllocated(ALV, 'SetOwnerData')
  then Exit;
  RecreateWnd(ALV);
end;

class procedure TWin32WSCustomListView.SetProperty(const ALV: TCustomListView; const AProp: TListViewProperty; const AIsSet: Boolean);
begin
  if not WSCheckHandleAllocated(ALV, 'SetProperty')
  then Exit;

  case LV_STYLES[AProp].StyleType of
    lsStyle: begin
      if AIsSet
      then UpdateStyle(ALV.Handle, LV_STYLES[AProp].Style, LV_STYLES[AProp].Style)
      else UpdateStyle(ALV.Handle, LV_STYLES[AProp].Style, 0);
    end;
    lsInvert:
    begin
      // we are always using readonly on ws since ListView_GetEditControl
      // requires minimum windows 2000. Editing is implemented in LCL atm,
      // can be changed later to use ws for item editing.
      // http://msdn.microsoft.com/en-us/library/windows/desktop/bb761260%28v=vs.85%29.aspx
      if (AProp = lvpReadOnly) then
        UpdateStyle(ALV.Handle, LV_STYLES[AProp].Style, 0)
      else
      if AIsSet then
        UpdateStyle(ALV.Handle, LV_STYLES[AProp].Style, 0)
      else
        UpdateStyle(ALV.Handle, LV_STYLES[AProp].Style, LV_STYLES[AProp].Style);
    end;
    lsExStyle: begin
      if AIsSet
      then UpdateExStyle(ALV.Handle, LV_STYLES[AProp].Style, LV_STYLES[AProp].Style)
      else UpdateExStyle(ALV.Handle, LV_STYLES[AProp].Style, 0);
    end;
  end;
  if(aProp=lvpCheckboxes)and aIsSet
    then ReCreateWnd(ALV)
end;

class procedure TWin32WSCustomListView.SetProperties(const ALV: TCustomListView; const AProps: TListViewProperties);
var
  Prop: TListViewProperty;
  Style, ExStyle, Mask, ExMask: Integer;
begin
  if not WSCheckHandleAllocated(ALV, 'SetProperties')
  then Exit;

  Style := 0;
  ExStyle := 0;
  Mask := 0;
  ExMask := 0;

  for Prop := Low(Prop) to High(Prop) do
  begin
    case LV_STYLES[Prop].StyleType of
      lsStyle,
      lsInvert:
      begin
        // we are always using readonly on ws since ListView_GetEditControl
        // requires minimum windows 2000. Editing is implemented in LCL atm,
        // can be changed later to use ws for item editing.
        // http://msdn.microsoft.com/en-us/library/windows/desktop/bb761260%28v=vs.85%29.aspx
        if Prop = lvpReadOnly then
          UpdateStyle(ALV.Handle, LVS_EDITLABELS, 0)
        else
        begin
          Mask := Mask or LV_STYLES[Prop].Style;
          if (LV_STYLES[Prop].StyleType = lsStyle) = (Prop in AProps)
          then Style := Style or LV_STYLES[Prop].Style
          else Style := Style and not LV_STYLES[Prop].Style;
        end;
      end;
      lsExStyle: begin
        ExMask := ExMask or LV_STYLES[Prop].Style;

        if Prop in AProps
        then ExStyle := ExStyle or LV_STYLES[Prop].Style
        else ExStyle := ExStyle and not LV_STYLES[Prop].Style;
      end;
    end;
  end;

  if Mask <> 0
  then UpdateStyle(ALV.Handle, Mask, Style);
  if ExMask <> 0
  then UpdateExStyle(ALV.Handle, ExMask, ExStyle);
end;

class procedure TWin32WSCustomListView.SetScrollBars(const ALV: TCustomListView; const AValue: TScrollStyle);
begin
  if not WSCheckHandleAllocated(ALV, 'SetScrollBars')
  then Exit;

  // we only can hide all scrollbars.
  if AValue = ssNone
  then UpdateStyle(ALV.Handle, LVS_NOSCROLL, LVS_NOSCROLL)
  else UpdateStyle(ALV.Handle, LVS_NOSCROLL, 0);
end;

function ListCompare(lParam1, lParam2: LParam; lParamSort: LParam): Integer; stdcall;
var
  Item1: TListItem absolute lParam1;
  Item2: TListItem absolute lParam2;
begin
  Result := CompareValue(Item1.Index, Item2.Index);
end;

class procedure TWin32WSCustomListView.SetSort(const ALV: TCustomListView;
  const AType: TSortType; const AColumn: Integer; const ASortDirection: TSortDirection);
begin
  if not WSCheckHandleAllocated(ALV, 'SetSort')
  then Exit;
  ListView_SortItems(ALV.Handle, @ListCompare, Windows.MAKELPARAM(Ord(AType), AColumn));
end;

class procedure TWin32WSCustomListView.SetViewOrigin(const ALV: TCustomListView; const AValue: TPoint);
var
  dx, dy: Integer;
  Origin: TPoint;
begin
  if not WSCheckHandleAllocated(ALV, 'SetViewOrigin')
  then Exit;

  ListView_GetOrigin(ALV.Handle, Origin);

  dx := AValue.X - Origin.X;
  dy := AValue.Y - Origin.Y;
  if (dx <> 0) or (dy <> 0)
  then ListView_Scroll(ALV.Handle, dx, dy);
end;

class procedure TWin32WSCustomListView.SetViewStyle(const ALV: TCustomListView; const Avalue: TViewStyle);
const
  //vsIcon, vsSmallIcon, vsList, vsReport
  STYLES: array[TViewStyle] of DWORD = (LVS_ICON, LVS_SMALLICON, LVS_LIST, LVS_REPORT);
begin
  if not WSCheckHandleAllocated(ALV, 'SetViewStyle')
  then Exit;

  UpdateStyle(ALV.Handle, LVS_TYPEMASK, STYLES[AValue]);
end;

class procedure TWin32WSCustomListView.UpdateStyle(const AHandle: THandle; const AMask, AStyle: Integer);
var
  OldStyle, NewStyle: PtrInt;
begin
  OldStyle := GetWindowLong(AHandle, GWL_STYLE);

  NewStyle := (OldStyle and not AMask) or AStyle;

  if OldStyle = NewStyle then Exit;

  SetWindowLong(AHandle, GWL_STYLE, NewStyle);

  // fix header if needed
  if (NewStyle and LVS_NOSCROLL)<> 0 then begin
    if (OldStyle and LVS_NOSCROLL = 0)
    or (NewStyle and LVS_REPORT <> 0)
    then PositionHeader(AHandle);
  end;

  //Invalidate Listview, so that changes are made visible
  Windows.InvalidateRect(AHandle, nil, true);
end;

class procedure TWin32WSCustomListView.UpdateExStyle(const AHandle: THandle; const AMask, AStyle: Integer);
var
  OldStyle, NewStyle: Integer;
begin
  OldStyle := SendMessage(AHandle, LVM_GETEXTENDEDLISTVIEWSTYLE, 0, 0);

  NewStyle := (OldStyle and not AMask) or AStyle;

  if OldStyle = NewStyle then Exit;

  SendMessage(AHandle, LVM_SETEXTENDEDLISTVIEWSTYLE, 0, NewStyle);

 //Invalidate Listview, so that changes are made visible
  Windows.InvalidateRect(AHandle, nil, true);
end;

class function TWin32WSCustomListView.GetNextItem(const ALV: TCustomListView; const StartItem: TListItem;
  const Direction: TSearchDirection; const States: TListItemStates): TListItem;
var
  Flags, Index: Integer;
begin
  Result := nil;

  if not WSCheckHandleAllocated(ALV, 'GetNextItem')
  then Exit;

  Flags := 0;
  case Direction of
    sdAbove: Flags := LVNI_ABOVE;
    sdBelow: Flags := LVNI_BELOW;
    sdLeft: Flags := LVNI_TOLEFT;
    sdRight: Flags := LVNI_TORIGHT;
    sdAll: Flags := LVNI_ALL;
  end;

  if StartItem <> nil then Index := StartItem.Index else Index := -1;

  if lisCut in States then Flags := Flags or LVNI_CUT;
  if lisDropTarget in States then Flags := Flags or LVNI_DROPHILITED;
  if lisFocused in States then Flags := Flags or LVNI_FOCUSED;
  if lisSelected in States then Flags := Flags or LVNI_SELECTED;

  Index := ListView_GetNextItem(ALV.Handle, Index, Flags);
  if Index <> -1 then Result := ALV.Items[Index];
end;

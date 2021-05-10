{
 *****************************************************************************
 *                               gtk3private.pas                             *
 *                               -------------                               *
 *                                                                           *
 *                                                                           *
 *****************************************************************************

 *****************************************************************************
  This file is part of the Lazarus Component Library (LCL)

  See the file COPYING.modifiedLGPL.txt, included in this distribution,
  for details about the license.
 *****************************************************************************
}

unit gtk3private;

{$i gtk3defines.inc}
{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils,
  // LCL
  Controls, LazGtk3, LazGLib2;

type

  TGtkListStringsState = (glsItemCacheNeedsUpdate, glsCountNeedsUpdate);
  TGtkListStringsStates = set of TGtkListStringsState;

  // PPGtkListItem = ^PGtkListItem;

  (*
  { TGtkListStringList }

  TGtkListStringList = class(TStrings)
  private
    FGtkList : PGtkList;
    FOwner: TWinControl;
    FSorted : boolean;
    FStates: TGtkListStringsStates;
    FCachedCount: integer;
    FCachedCapacity: integer;
    FCachedItems: PPGtkListItem;
    FUpdateCount: integer;
    FWithCheckBox: Boolean;
  protected
    function GetListItem(Index: integer): PGtkListItem;
    function GetLabel(Index: integer): PGtkLabel;
    function GetCount: integer; override;
    function Get(Index : Integer) : string; override;
    function GetObject(Index: Integer): TObject; override;
    procedure Put(Index: Integer; const S: string); override;
    procedure PutObject(Index: Integer; AnObject: TObject); override;
    procedure SetSorted(Val : boolean); virtual;
    procedure CheckForInvalidFocus;
    procedure ConnectItemCallbacks(Index: integer);
    procedure ConnectItemCallbacks(Li: PGtkListItem); virtual;
    procedure ConnectAllCallbacks; virtual;
    procedure RemoveItemCallbacks(Index: integer);
    procedure RemoveItemCallbacks(AItem: PGtkListItem); virtual;
    procedure RemoveAllCallbacks; virtual;
    procedure UpdateItemCache;
    function CacheValid: boolean;
  public
    constructor Create(List : PGtkList; TheOwner: TWinControl;
                       const AWithCheckBox: Boolean);
    destructor Destroy; override;
    function Add(const S: string): Integer; override;
    procedure Assign(Source : TPersistent); override;
    procedure Clear; override;
    procedure Delete(Index : integer); override;
    function IndexOf(const S: string): Integer; override;
    procedure Insert(Index : integer; const S: string); override;
    function GetInsertPosition(const S: string): integer;
    procedure Move(FromIndex, ToIndex: Integer); override;
    procedure Sort; virtual;
    function IsEqual(List: TStrings; CompareObjects: boolean): boolean;
    procedure BeginUpdate;
    procedure EndUpdate;
    procedure ConsistencyCheck;
  public
    property Sorted: boolean read FSorted write SetSorted;
    property Owner: TWinControl read FOwner;
  end;
  *)

  { TGtkListStoreStringList }

  TGtkListStoreStringList = class(TStrings)
  private
    FChangeStamp: Integer;
    FColumnIndex: Integer;
    FGtkListStore: PGtkListStore;
    FOwner: TWinControl;
    FSorted: Boolean;
    FStates: TGtkListStringsStates;
    FCachedCount: Integer;
    FCachedCapacity: Integer;
    FCachedSize: Integer;
    FCachedItems: PGtkTreeIter;
    FUpdateCount: Integer;
  protected
    function GetCount: Integer; override;
    function Get(Index: Integer): String; override;
    function GetObject(Index: Integer): TObject; override;
    procedure Put(Index: Integer; const S: String); override;
    procedure PutObject(Index: Integer; AnObject: TObject); override;
    procedure SetSorted(Val: Boolean);
    procedure UpdateItemCache;
    procedure GrowCache;
    procedure ShrinkCache;
    procedure IncreaseChangeStamp;
  public
    constructor Create(AListStore: PGtkListStore;
                       ColumnIndex: Integer; AOwner: TWinControl);
    destructor Destroy; override;
    function Add(const S: String): Integer; override;
    procedure Assign(Source: TPersistent); override;
    procedure Clear; override;
    procedure Delete(Index: Integer); override;
    function Find(const S: String; out Index: Integer): Boolean;
    function IndexOf(const S: String): Integer; override;
    procedure Insert(Index: Integer; const S: String); override;
    procedure Move(CurIndex, NewIndex: Integer); override;
    procedure Sort;
    function IsEqual(List: TStrings): Boolean;
    procedure BeginUpdate;
    procedure EndUpdate;
  public
    property Sorted: Boolean read FSorted write SetSorted;
    property Owner: TWinControl read FOwner;
    property ChangeStamp: Integer read FChangeStamp;
  end;

  { TGtk3MemoStrings }

  TGtk3MemoStrings = class(TStrings)
  private
    FGtkText : PGtkTextView;
    FGtkBuf: PGtkTextBuffer;
    FTimerMove: guint;
    FTimerSel: guint;
    FOwner: TWinControl;
    FQueueCursorMove: Integer;
    FQueueSelLength: Integer;
  protected
    function GetTextStr: string; override;
    function GetCount: integer; override;
    function Get(Index : Integer) : string; override;
    //procedure PutObject(Index: Integer; AObject: TObject); override;
    //function GetObject(Index: Integer): TObject; override;
    //procedure SetSorted(Val : boolean); virtual;
  public
    constructor Create(TheOwner: TWinControl);
    destructor Destroy; override;
    procedure Assign(Source : TPersistent); override;
    procedure AddStrings(TheStrings: TStrings); override;
    procedure Clear; override;
    procedure Delete(Index : integer); override;
    procedure Insert(Index : integer; const S: string); override;
    procedure SetTextStr(const Value: string); override;
    procedure LoadFromFile(const FileName: string); override;
    procedure SaveToFile(const FileName: string); override;
    //procedure Sort; virtual;
    procedure QueueCursorMove(APosition: Integer);
    procedure QueueSelectLength(ALength: Integer);
  public
    //property Sorted: boolean read FSorted write SetSorted;
    property Owner: TWinControl read FOwner;
    property QueueSelLength: Integer read FQueueSelLength;
  end;

implementation
uses StdCtrls, CheckLst, LCLProc, gtk3widgets, gtk3procs, Gtk3WSStdCtrls, Gtk3WSCheckLst;

{*************************************************************}
{                      TGtkListStoreStringList methods             }
{*************************************************************}

{------------------------------------------------------------------------------
  Method: TGtkListStoreStringList.Create
  Params:
  Returns:

 ------------------------------------------------------------------------------}
constructor TGtkListStoreStringList.Create(AListStore: PGtkListStore;
  ColumnIndex: Integer; AOwner: TWinControl);
begin
  inherited Create;
  if AListStore = nil
  then RaiseGDBException('TGtkListStoreStringList.Create Unspecified list store');

  FGtkListStore := AListStore;

  if (ColumnIndex < 0) or (ColumnIndex >= gtk_tree_model_get_n_columns(PGtkTreeModel(FGtkListStore))) then
    RaiseGDBException('TGtkListStoreStringList.Create Invalid Column Index');
  FColumnIndex := ColumnIndex;

  if AOwner = nil then
    RaiseGDBException('TGtkListStoreStringList.Create Unspecified owner');
  FOwner := AOwner;
  FStates := [glsItemCacheNeedsUpdate, glsCountNeedsUpdate];
end;

destructor TGtkListStoreStringList.Destroy;
begin
  FGtkListStore := nil;
  // don't destroy the widgets
  ReAllocMem(FCachedItems, 0);
  inherited Destroy;
end;

function TGtkListStoreStringList.Add(const S: String): Integer;
begin
  if FSorted then
    Find(S, Result)
  else
    Result := Count;

  //DebugLn(['TGtkListStoreStringList.Add ',S,' Count=',Result]);
  Insert(Result, S);
end;

{------------------------------------------------------------------------------
  Method: TGtkListStringList.SetSorted
  Params:
  Returns:

 ------------------------------------------------------------------------------}
procedure TGtkListStoreStringList.SetSorted(Val: Boolean);
var
  i: Integer;
begin
  if Val = FSorted then Exit;

  FSorted := Val;
  if not FSorted then Exit;

  for i := 0 to Count - 2 do
  begin
    if AnsiCompareText(Strings[i], Strings[i + 1]) < 0 then
    begin
      Sort;
      Break;
    end;
  end;
end;

{------------------------------------------------------------------------------
  procedure TGtkListStoreStringList.RemoveAllCallbacks;

 ------------------------------------------------------------------------------}

procedure TGtkListStoreStringList.UpdateItemCache;
var
  i: Integer;
begin
  if not (glsItemCacheNeedsUpdate in FStates) then exit;

  //DebugLn(['TGtkListStoreStringList.UpdateItemCache ']); DumpStack;
  FCachedSize := Count;
  FCachedCapacity := Count;
  ReAllocMem(FCachedItems, SizeOf(TGtkTreeIter) * FCachedCapacity);
  if FGtkListStore <> nil then
    for I := 0 to FCachedSize - 1 do
      gtk_tree_model_iter_nth_child(PGtkTreeModel(FGtkListStore),
        @FCachedItems[i], nil, I);
  Exclude(FStates, glsItemCacheNeedsUpdate);
end;

procedure TGtkListStoreStringList.GrowCache;
begin
  FCachedCapacity := ((FCachedCapacity * 5) div 4) + 10;
  ReAllocMem(FCachedItems, SizeOf(TGtkTreeIter) * FCachedCapacity);
end;

procedure TGtkListStoreStringList.ShrinkCache;
begin
  FCachedCapacity := FCachedSize + 1;
  ReAllocMem(FCachedItems, SizeOf(TGtkTreeIter) * FCachedCapacity);
end;

procedure TGtkListStoreStringList.IncreaseChangeStamp;
begin
  if FChangeStamp < High(FChangeStamp) then
    Inc(FChangeStamp)
  else
    FChangeStamp := Low(FChangeStamp);
end;

procedure TGtkListStoreStringList.PutObject(Index: Integer; AnObject: TObject);
var
  ListItem: TGtkTreeIter;
begin
  if (Index < 0) or (Index >= Count)
  then begin
    RaiseGDBException('TGtkListStoreStringList.PutObject Out of bounds.');
    Exit;
  end;

  if FGtkListStore = nil then Exit;

  UpdateItemCache;
  ListItem := FCachedItems[Index];
  gtk_list_store_set(FGtkListStore, @ListItem, [FColumnIndex + 1, Pointer(AnObject), -1]);
  IncreaseChangeStamp;
end;

{------------------------------------------------------------------------------
  Method: TGtkListStoreStringList.Sort
  Params:
  Returns:

 ------------------------------------------------------------------------------}
procedure TGtkListStoreStringList.Sort;
var
  sl: TStringList;
  OldSorted: Boolean;
begin
  BeginUpdate;
  // sort internally (sorting in the widget would be slow and unpretty ;)
  sl := TStringList.Create;
  sl.Assign(Self);
  sl.Sort;
  OldSorted := Sorted;
  FSorted := False;
  Assign(sl);
  FSorted := OldSorted;
  sl.Free;
  EndUpdate;
end;

function TGtkListStoreStringList.IsEqual(List: TStrings): Boolean;
var
  i, Cnt: Integer;
begin
  if List = Self then Exit(True);
  if List = nil then Exit(False);

  Cnt := Count;
  if (Cnt <> List.Count) then Exit(False);

  for i := 0 to Cnt - 1 do
  begin
    if Strings[i] <> List[i] then Exit(False);
    if Objects[i] <> List.Objects[i] then Exit(False);
  end;

  Result := True;
end;

procedure TGtkListStoreStringList.BeginUpdate;
begin
  Inc(FUpdateCount);
end;

procedure TGtkListStoreStringList.EndUpdate;
begin
  Dec(FUpdateCount);
end;

{------------------------------------------------------------------------------
  Method: TGtkListStoreStringList.Assign
  Params:
  Returns:

 ------------------------------------------------------------------------------}
procedure TGtkListStoreStringList.Assign(Source: TPersistent);
var
  i, Cnt: Integer;
  CmpList: TStrings;
  OldSorted: Boolean;
begin
  if (Source = Self) or (Source = nil) then Exit;

  if ((Source is TGtkListStoreStringList)
  and (TGtkListStoreStringList(Source).FGtkListStore = FGtkListStore)) then
    RaiseGDBException('TGtkListStoreStringList.Assign: There are 2 lists with the same FGtkListStore');

  BeginUpdate;
  OldSorted := Sorted;
  CmpList := nil;
  try
    if Source is TStrings then
    begin
      // clearing and resetting can change other properties of the widget,
      // => don't change if the content is already the same
      if Sorted then
      begin
        CmpList := TStringList.Create;
        CmpList.Assign(TStrings(Source));
        TStringList(CmpList).Sort;
      end
      else
        CmpList := TStrings(Source);

      if IsEqual(CmpList) then Exit;

      Clear;
      FSorted := False;
      Cnt := TStrings(Source).Count;
      for i := 0 to Cnt - 1 do
      begin
        AddObject(CmpList[i], CmpList.Objects[i]);
        //DebugLn(['TGtkListStoreStringList.Assign ',i,' ',CmpList[i],' ',Count]);
      end;
      // ToDo: restore other settings

      // Do not call inherited Assign as it does things we do not want to happen
    end
    else
      inherited Assign(Source);
  finally
    fSorted := OldSorted;
    if CmpList <> Source
    then CmpList.Free;

    EndUpdate;
  end;
end;

{------------------------------------------------------------------------------
  Method: TGtkListStoreStringList.Get
  Params:
  Returns:

 ------------------------------------------------------------------------------}
function TGtkListStoreStringList.Get(Index: Integer): String;
var
  Item: PChar;
  ListItem: TGtkTreeIter;
begin
  Result := '';
  if (Index < 0) or (Index >= Count)
  then begin
    RaiseGDBException('TGtkListStoreStringList.Get Out of bounds.');
    Exit;
  end;

  if not Assigned(FOwner) or not FOwner.HandleAllocated then
  begin
    DebugLn('TGtkListStoreStringList.Get exiting, no owner or handle ');
    exit;
  end;
  UpdateItemCache;
  ListItem := FCachedItems[Index];

  Item := nil;

  if Gtk3IsWidget(TGtk3Widget(FOwner.Handle).Widget) and
      (wtTreeModel in TGtk3Widget(FOwner.Handle).WidgetType) then
    gtk_tree_model_get(PGtkTreeModel(FGtkListStore), @ListItem, [FColumnIndex, @Item, -1]);

  if Item = nil then
    Exit('');

  Result := Item;

  g_free(Item);
end;

function TGtkListStoreStringList.GetObject(Index: Integer): TObject;
var
  ListItem: TGtkTreeIter;
begin
  Result := nil;
  if (Index < 0) or (Index >= Count)
  then begin
    RaiseGDBException('TGtkListStoreStringList.GetObject Out of bounds.');
    Exit(nil);
  end;
  if FGtkListStore = nil then Exit(nil);

  if not Assigned(FOwner) or not FOwner.HandleAllocated then
  begin
    // DebugLn('TGtkListStoreStringList.GetObject exiting, no owner or handle ');
    exit(nil);
  end;

  UpdateItemCache;
  ListItem := FCachedItems[Index];
  if Gtk3IsWidget(TGtk3Widget(FOwner.Handle).Widget) and
    (wtTreeModel in TGtk3Widget(FOwner.Handle).WidgetType) then
      gtk_tree_model_get(PGtkTreeModel(FGtkListStore), @ListItem, [FColumnIndex + 1, @Result, -1]);
end;

procedure TGtkListStoreStringList.Put(Index: Integer; const S: String);
var
  ListItem: TGtkTreeIter;
begin
  if (Index < 0) or (Index >= Count)
  then begin
    RaiseGDBException('TGtkListStoreStringList.Put Out of bounds.');
    Exit;
  end;
  if FGtkListStore = nil then Exit;

  UpdateItemCache;
  ListItem := FCachedItems[Index];
  gtk_list_store_set(FGtkListStore, @ListItem, [FColumnIndex, PChar(S), -1]);
  IncreaseChangeStamp;
end;

{------------------------------------------------------------------------------
  Method: TGtkListStoreStringList.GetCount
  Params:
  Returns:

 ------------------------------------------------------------------------------}
function TGtkListStoreStringList.GetCount: Integer;
begin
  if (glsCountNeedsUpdate in FStates) then
  begin
    if FGtkListStore <> nil then
      FCachedCount := gtk_tree_model_iter_n_children(PGtkTreeModel(FGtkListStore), nil)
    else
      FCachedCount := 0;
    Exclude(FStates, glsCountNeedsUpdate);
  end;
  Result := FCachedCount;
end;

{------------------------------------------------------------------------------
  Method: TGtkListStoreStringList.Clear
  Params:
  Returns:

 ------------------------------------------------------------------------------}
procedure TGtkListStoreStringList.Clear;
begin
  //DebugLn(['TGtkListStoreStringList.Clear ']);
  //while Count>0 do Delete(Count-1);

  //Lock the widget to avoid trigger events
  //Note: Assign/Clear is called inside CreateHandle before Handle is set
  if FOwner.HandleAllocated then
  begin
    // WidgetInfo := GetWidgetInfo({%H-}Pointer(FOwner.Handle), False);
    // Inc(WidgetInfo^.ChangeLock);
    TGtk3Widget(FOwner.Handle).BeginUpdate;
    try
      gtk_list_store_clear(FGtkListStore);

      //resize columns to optimal width. See issue #17837
      //TODO: see if this is needed by TComboBox and others.
      if wtListBox in TGtk3Widget(FOwner.Handle).WidgetType then
        gtk_tree_view_columns_autosize(PGtkTreeView(TGtk3Widget(FOwner.Handle).GetContainerWidget));
    finally
      TGtk3Widget(FOwner.Handle).EndUpdate;
    end;
    // Dec(WidgetInfo^.ChangeLock);
    // Update the internal Index cache
    // PInteger(WidgetInfo^.UserData)^ := -1;
  end;

  IncreaseChangeStamp;

  ReAllocMem(FCachedItems, 0);
  FCachedCapacity := 0;
  FCachedSize := 0;
  Exclude(FStates, glsItemCacheNeedsUpdate);
  FCachedCount := 0;
  Exclude(FStates, glsCountNeedsUpdate);
end;

{------------------------------------------------------------------------------
  Method: TGtkListStoreStringList.Delete
  Params:
  Returns:

 ------------------------------------------------------------------------------}
procedure TGtkListStoreStringList.Delete(Index: Integer);
var
  ListItem: TGtkTreeIter;
  // WidgetInfo: PWidgetInfo;
begin
  if not (glsItemCacheNeedsUpdate in FStates) then
    ListItem := FCachedItems[Index]
  else
    gtk_tree_model_iter_nth_child(PGtkTreeModel(FGtkListStore), @ListItem, nil, Index);

  //gtk_list_store_g
  // WidgetInfo := GetWidgetInfo({%H-}Pointer(FOwner.Handle));
  //Lock the widget to avoid trigger events
  // Inc(WidgetInfo^.ChangeLock);
  TGtk3Widget(FOwner.Handle).BeginUpdate;
  gtk_list_store_remove(FGtkListStore, @ListItem);
  TGtk3Widget(FOwner.Handle).EndUpdate;
  // Dec(WidgetInfo^.ChangeLock);
  IncreaseChangeStamp;

  if not (glsCountNeedsUpdate in FStates) then
    Dec(FCachedCount);
  if (not (glsItemCacheNeedsUpdate in FStates)) and (Index = Count) then
  begin
    // cache is valid and the last item was deleted -> just remove last item
    Dec(FCachedSize);
    if (FCachedSize < FCachedCapacity div 2) then
      ShrinkCache;
  end
  else
    Include(FStates, glsItemCacheNeedsUpdate);

  if wtComboBox in TGtk3Widget(FOwner.Handle).WidgetType then
  begin
    TGtk3WSCustomComboBox.SetText(FOwner, '');
    //Update the internal Index cache
    // PInteger(WidgetInfo^.UserData)^ := -1;
  end;
end;

function TGtkListStoreStringList.Find(const S: String; out Index: Integer): Boolean;
var
  L, R, I: Integer;
  CompareRes: Integer;
begin
  Result := False;
  // Use binary search.
  L := 0;
  R := Count - 1;
  while (L <= R) do
  begin
    I := L + (R - L) div 2;
    CompareRes := AnsiCompareText(S, Strings[I]);
    if (CompareRes > 0) then
      L := I + 1
    else
    begin
      R := I - 1;
      if (CompareRes = 0) then
      begin
        Result := True;
        L := I; // forces end of while loop
      end;
    end;
  end;
  Index := L;
end;

function TGtkListStoreStringList.IndexOf(const S: String): Integer;
begin
  Result := -1;
  BeginUpdate;
  if FSorted then
  begin
    //Binary Search
    if not Find(S, Result) then
      Result := -1;
  end else
    Result := inherited IndexOf(S);
  EndUpdate;
end;

{------------------------------------------------------------------------------
  Method: TGtkListStoreStringList.Insert
  Params:
  Returns:

 ------------------------------------------------------------------------------}
procedure TGtkListStoreStringList.Insert(Index: Integer; const S: String);
var
  li: TGtkTreeIter;
begin
  if (Index < 0) or (Index > Count)
  then begin
    RaiseGDBException('TGtkListStoreStringList.Insert: Index ' + IntToStr(Index) + ' out of bounds. Count=' + IntToStr(Count));
    Exit;
  end;

  if Owner = nil
  then begin
    RaiseGDBException('TGtkListStoreStringList.Insert Unspecified owner');
    Exit;
  end;

  BeginUpdate;
  try
    // this call is few times faster than gtk_list_store_insert, gtk_list_store_set
    gtk_list_store_insert_with_values(FGtkListStore, @li, Index, [FColumnIndex, PChar(S), -1]);
    IncreaseChangeStamp;


    if not (glsCountNeedsUpdate in FStates) then
      Inc(FCachedCount);

    if (not (glsItemCacheNeedsUpdate in FStates)) and (Index = Count - 1) then
    begin
      // cache is valid and item was added as last
      // Add item to cache (instead of updating the whole cache)
      // This accelerates Assign.
      if FCachedSize = FCachedCapacity then GrowCache;
      FCachedItems[FCachedSize] := li;
      Inc(FCachedSize);
    end
    else
      Include(FStates, glsItemCacheNeedsUpdate);
  finally
    EndUpdate;
  end;
end;

procedure TGtkListStoreStringList.Move(CurIndex, NewIndex: Integer);
const
  AState: Array[Boolean] of TCheckBoxState = (cbUnchecked, cbChecked);
var
  AItemChecked: Boolean;
begin
  if FOwner is TCheckListBox then
    AItemChecked := TCheckListBox(FOwner).Checked[CurIndex];
  inherited Move(CurIndex, NewIndex);
  if FOwner is TCheckListBox then
    TGtk3WSCustomCheckListBox.SetState(TCustomCheckListBox(FOwner),
      NewIndex, AState[AItemChecked]);

end;

function UpdateMemoCursorCB(AStrings: TGtk3MemoStrings): gboolean; cdecl;
var
  TextMark: PGtkTextMark;
  CursorIter: TGtkTextIter;
begin
  Result := gtk_false; // stop this timer

  if AStrings.FQueueCursorMove = -1 then
  begin
    // always scroll so the cursor is visible
    TextMark := gtk_text_buffer_get_insert(AStrings.FGtkBuf);
    gtk_text_buffer_get_iter_at_mark(AStrings.FGtkBuf, @CursorIter, TextMark);
  end
  else begin
    // SelStart was used and we should move to that location
    gtk_text_buffer_get_iter_at_offset(AStrings.FGtkBuf, @CursorIter, AStrings.FQueueCursorMove);
    gtk_text_buffer_place_cursor(AStrings.FGtkBuf, @CursorIter); // needed to move the cursor
    TextMark := gtk_text_buffer_get_insert(AStrings.FGtkBuf);
  end;
  gtk_text_view_scroll_to_mark(AStrings.FGtkText, TextMark, 0, True, 0, 1);

  AStrings.FQueueCursorMove := 0;
end;

function UpdateMemoSelLengthCB(AStrings: TGtk3MemoStrings): gboolean; cdecl;
var
  TextMark: PGtkTextMark;
  StartIter,
  EndIter: TGtkTextIter;
  Offset: Integer;
begin
  Result := gtk_false; // stop this timer

  TextMark := gtk_text_buffer_get_insert(AStrings.FGtkBuf);
  gtk_text_buffer_get_iter_at_mark(AStrings.FGtkBuf, @StartIter, TextMark);

  Offset := gtk_text_iter_get_offset(@StartIter);

  gtk_text_buffer_get_iter_at_offset(AStrings.FGtkBuf, @EndIter, Offset+AStrings.FQueueSelLength);

  gtk_text_buffer_select_range(AStrings.FGtkBuf, @StartIter, @EndIter);

  AStrings.FQueueSelLength := -1;
end;

function TGtk3MemoStrings.GetTextStr: string;
var
  StartIter, EndIter: TGtkTextIter;
  AText: PgChar;
begin
  Result := '';
  gtk_text_buffer_get_start_iter(FGtkBuf, @StartIter);
  gtk_text_buffer_get_end_iter(FGtkBuf, @EndIter);

  AText := gtk_text_iter_get_text(@StartIter, @EndIter);
  Result := StrPas(AText);
  if AText <> nil then
    g_free(AText);
end;

function TGtk3MemoStrings.GetCount: integer;
begin
  Result := gtk_text_buffer_get_line_count(FGtkBuf);
  if Get(Result-1) = '' then Dec(Result);
end;

function TGtk3MemoStrings.Get(Index: Integer): string;
var
  StartIter, EndIter: TGtkTextIter;
  AText: PgChar;
begin
  gtk_text_buffer_get_iter_at_line(FGtkBuf, @StartIter, Index);
  if Index = gtk_text_buffer_get_line_count(FGtkBuf) then
    gtk_text_buffer_get_end_iter(FGtkBuf, @EndIter)
  else begin
    gtk_text_buffer_get_iter_at_line(FGtkBuf, @EndIter, Index);
    gtk_text_iter_forward_to_line_end(@EndIter);
  end;
  // if a row is blank gtk_text_iter_forward_to_line_end will goto the row ahead
  // this is not desired. so if it jumped ahead a row then the row we want is blank
  if gtk_text_iter_get_line(@StartIter) = gtk_text_iter_get_line(@EndIter) then
  begin
    AText := gtk_text_iter_get_text(@StartIter, @EndIter);
    Result := StrPas(AText);
    g_free(AText);
  end
  else
    Result := '';
end;

constructor TGtk3MemoStrings.Create(TheOwner: TWinControl);
begin
  inherited Create;
  if TheOwner = nil then RaiseGDBException(
    'TGtk3MemoStrings.Create Unspecified owner');
  FGtkText:= PGtkTextView(TGtk3Widget(TheOwner.Handle).GetContainerWidget);
  FGtkBuf := FGtkText^.get_buffer;
  FOwner:=TheOwner;
  FQueueSelLength := -1;
  FTimerMove := 0;
  FTimerSel := 0;
end;

destructor TGtk3MemoStrings.Destroy;
begin
  // gtk_timeout_remove(FTimerSel);
  // gtk_timeout_remove(FTimerMove);
  // don't destroy the widgets
  inherited Destroy;
end;

procedure TGtk3MemoStrings.Assign(Source: TPersistent);
var
  S: TStrings absolute Source;
begin
  if Source is TStrings then
  begin
    // to prevent Clear and then SetText we need to use our own Assign
    QuoteChar := S.QuoteChar;
    Delimiter := S.Delimiter;
    NameValueSeparator := S.NameValueSeparator;
    TextLineBreakStyle := S.TextLineBreakStyle;
    Text := S.Text;
  end
  else
    inherited Assign(Source);
end;

procedure TGtk3MemoStrings.AddStrings(TheStrings: TStrings);
begin
  SetTextStr(GetTextStr + TStrings(TheStrings).Text);
end;

procedure TGtk3MemoStrings.Clear;
begin
  SetText('');
end;

procedure TGtk3MemoStrings.Delete(Index: integer);
var
StartIter,
EndIter: TGtkTextIter;
begin
  gtk_text_buffer_get_iter_at_line(FGtkBuf, @StartIter, Index);
  if Index = Count-1 then
  begin
    gtk_text_iter_backward_char(@StartIter);
    gtk_text_buffer_get_end_iter(FGtkBuf, @EndIter)
  end else
    gtk_text_buffer_get_iter_at_line(FGtkBuf, @EndIter, Index+1);
  gtk_text_buffer_delete(FGtkBuf, @StartIter, @EndIter);
end;

procedure TGtk3MemoStrings.Insert(Index: integer; const S: string);
var
  StartIter,
  CursorIter: TGtkTextIter;
  NewLine: String;
  TextMark: PGtkTextMark;
begin
  if Index < gtk_text_buffer_get_line_count(FGtkBuf) then begin
    //insert with LineEnding
    NewLine := S+LineEnding;
    gtk_text_buffer_get_iter_at_line(FGtkBuf, @StartIter, Index);
  end
  else begin
    //append with a preceding LineEnding
    gtk_text_buffer_get_end_iter(FGtkBuf, @StartIter);
    if gtk_text_buffer_get_line_count(FGtkBuf) = Count then
      NewLine := LineEnding+S+LineEnding
    else
      NewLine := S+LineEnding;
  end;

  if FQueueCursorMove = 0 then
  begin
    TextMark := gtk_text_buffer_get_insert(FGtkBuf);
    gtk_text_buffer_get_iter_at_mark(FGtkBuf, @CursorIter, TextMark);
    if gtk_text_iter_equal(@StartIter, @CursorIter) then
      QueueCursorMove(-1);
  end;

  // and finally insert the new text
  gtk_text_buffer_insert(FGtkBuf, @StartIter, PChar(NewLine) ,-1);
end;

procedure TGtk3MemoStrings.SetTextStr(const Value: string);
begin
  if (Value <> Text) then
  begin
    TGtk3Widget(FOwner.Handle).BeginUpdate;
    gtk_text_buffer_set_text(FGtkBuf, PChar(Value), -1);
    TGtk3Widget(FOwner.Handle).EndUpdate;
  end;
end;

procedure TGtk3MemoStrings.LoadFromFile(const FileName: string);
var
  TheStream: TFileStream;
begin
  TheStream:=TFileStream.Create(FileName,fmOpenRead or fmShareDenyWrite);
  try
    LoadFromStream(TheStream);
  finally
    TheStream.Free;
  end;
end;

procedure TGtk3MemoStrings.SaveToFile(const FileName: string);
var
  TheStream: TFileStream;
begin
  TheStream:=TFileStream.Create(FileName,fmCreate);
  try
    SaveToStream(TheStream);
  finally
    TheStream.Free;
  end;
end;

procedure TGtk3MemoStrings.QueueCursorMove(APosition: Integer);
begin
  // needed because there is a callback that updates the GtkBuffer
  // internally so that it actually knows where the cursor is
  if FQueueCursorMove = 0 then
    FTimerMove := g_timeout_add(0,TGSourceFunc(@UpdateMemoCursorCB), Pointer(Self));
  FQueueCursorMove := APosition;
end;

procedure TGtk3MemoStrings.QueueSelectLength(ALength: Integer);
begin
  // needed because there is a callback that updates the GtkBuffer
  // internally so that it actually knows where the cursor is
  if FQueueSelLength = -1 then
    FTimerSel := g_timeout_add(0,TGSourceFunc(@UpdateMemoSelLengthCB), Pointer(Self));
  FQueueSelLength := ALength;
end;

end.

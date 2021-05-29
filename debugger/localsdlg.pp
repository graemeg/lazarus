{ $Id$ }
{               ----------------------------------------------  
                 localsdlg.pp  -  Overview of local variables 
                ---------------------------------------------- 
 
 @created(Thu Mar 14st WET 2002)
 @lastmod($Date$)
 @author(Marc Weustink <marc@@dommelstein.net>)                       

 This unit contains the Locals debugger dialog.
 
 
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
unit LocalsDlg;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, StrUtils,
  // LCL
  Forms, ClipBrd, ComCtrls, ActnList, Menus,
  // LazUtils
  LazLoggerBase, LazStringUtils, LazUTF8,
  // IdeIntf
  IDEWindowIntf,
  // DebuggerIntf
  DbgIntfDebuggerBase,
  // IDE
  DebuggerStrConst, BaseDebugManager, EnvironmentOpts, Debugger, DebuggerDlg;

type

  { TLocalsDlg }

  TLocalsDlg = class(TDebuggerDlg)
    actInspect: TAction;
    actEvaluate: TAction;
    actCopyName: TAction;
    actCopyValue: TAction;
    actCopyAll: TAction;
    actCopyRAWValue: TAction;
    actEvaluateAll: TAction;
    actWath: TAction;
    ActionList1: TActionList;
    lvLocals: TListView;
    MenuItem1: TMenuItem;
    MenuItem2: TMenuItem;
    MenuItem3: TMenuItem;
    MenuItem4: TMenuItem;
    MenuItem5: TMenuItem;
    MenuItem6: TMenuItem;
    MenuItem7: TMenuItem;
    MenuItem8: TMenuItem;
    MenuItem9: TMenuItem;
    PopupMenu1: TPopupMenu;
    procedure actCopyAllExecute(Sender: TObject);
    procedure actCopyAllUpdate(Sender: TObject);
    procedure actCopyNameExecute(Sender: TObject);
    procedure actCopyValueExecute(Sender: TObject);
    procedure actEvaluateAllExecute(Sender: TObject);
    procedure actEvaluateExecute(Sender: TObject);
    procedure actInspectExecute(Sender: TObject);
    procedure actInspectUpdate(Sender: TObject);
    procedure actCopyRAWValueExecute(Sender: TObject);
    procedure actWathExecute(Sender: TObject);
  private
    FUpdateFlags: set of (ufNeedUpdating);
    EvaluateAllCallbackItem: TListItem;
    procedure CopyRAWValueEvaluateCallback(Sender: TObject; ASuccess: Boolean;
      ResultText: String; ResultDBGType: TDBGType);
    procedure CopyValueEvaluateCallback(Sender: TObject; ASuccess: Boolean;
      ResultText: String; ResultDBGType: TDBGType);
    procedure EvaluateAllCallback(Sender: TObject; ASuccess: Boolean;
      ResultText: String; ResultDBGType: TDBGType);

    procedure LocalsChanged(Sender: TObject);
    function  GetThreadId: Integer;
    function  GetSelectedThreads(Snap: TSnapshot): TIdeThreads;
    function GetStackframe: Integer;
    function  GetSelectedSnapshot: TSnapshot;
  protected
    procedure DoBeginUpdate; override;
    procedure DoEndUpdate; override;
    function  ColSizeGetter(AColId: Integer; var ASize: Integer): Boolean;
    procedure ColSizeSetter(AColId: Integer; ASize: Integer);
  public
    constructor Create(AOwner: TComponent); override;
    property LocalsMonitor;
    property ThreadsMonitor;
    property CallStackMonitor;
    property SnapshotManager;
  end;

function ValueToRAW(const AValue: string): string;
function ExtractValue(const AValue: string; AType: string = ''): string;

implementation

{$R *.lfm}

uses
  LazarusIDEStrConsts;

var
  DBG_DATA_MONITORS: PLazLoggerLogGroup;
  LocalsDlgWindowCreator: TIDEWindowCreator;

const
  COL_LOCALS_NAME   = 1;
  COL_LOCALS_VALUE  = 2;
  COL_WIDTHS: Array[0..1] of integer = ( 50,   150);

function LocalsDlgColSizeGetter(AForm: TCustomForm; AColId: Integer; var ASize: Integer): Boolean;
begin
  Result := AForm is TLocalsDlg;
  if Result then
    Result := TLocalsDlg(AForm).ColSizeGetter(AColId, ASize);
end;

procedure LocalsDlgColSizeSetter(AForm: TCustomForm; AColId: Integer; ASize: Integer);
begin
  if AForm is TLocalsDlg then
    TLocalsDlg(AForm).ColSizeSetter(AColId, ASize);
end;

function ValueToRAW(const AValue: string): string;
var
  I: Integer; //current char in AValue
  M: Integer; //max char in AValue
  L: Integer; //current char in Result

  procedure ProcessCharConsts;
  var
    xNum: string;
    xCharOrd: Integer;
  begin
    while (I <= M) and (AValue[I] = '#') do
    begin
      Inc(I);
      xNum := '';
      if (I <= M) and (AValue[I]='$') then
      begin // hex
        xNum := xNum + AValue[I];
        Inc(I);
        while (I <= M) and (AValue[I] in ['0'..'9', 'A'..'F', 'a'..'f']) do
        begin
          xNum := xNum + AValue[I]; // not really fast, but OK for this purpose
          Inc(I);
        end;
      end else
      begin // dec
        while (I <= M) and (AValue[I] in ['0'..'9']) do
        begin
          xNum := xNum + AValue[I]; // not really fast, but OK for this purpose
          Inc(I);
        end;
      end;
      if TryStrToInt(xNum, xCharOrd) then
      begin
        Result[L] := Char(xCharOrd);
        Inc(L);
      end;
    end;
  end;

  procedure ProcessQuote;
  begin
    Inc(I);
    if AValue[I] = '''' then // "''" => "'"
    begin
      Result[L] := AValue[I];
      Inc(L);
    end else
    if AValue[I] = '#' then // "'#13#10'" => [CRLF]
      ProcessCharConsts;
  end;

  procedure ProcessString;
  begin
    I := 2;
    L := 1;
    M := Length(AValue);
    if AValue[M] = '''' then
      Dec(M);
    SetLength(Result, Length(AValue)-2);
    while I <= M do
    begin
      if AValue[I] = '''' then
      begin
        ProcessQuote;
      end else
      begin
        Result[L] := AValue[I];
        Inc(L);
      end;
      Inc(I);
    end;
    SetLength(Result, L-1);
  end;

  procedure ProcessOther;
  begin
    I := Pos('(', AValue);
    if I > 0 then
    begin
      // Invalid enum value: "true (85)" => "85"
      L := PosEx(')', AValue, I+1);
      Result := Copy(AValue, I+1, L-I-1);
    end else
    begin
      //no formatting
      Result := AValue;
    end;
  end;

begin
  // try to guess and format value back to raw data, e.g.
  //   "'value'" => "value"
  //   "true (85)" => "85"
  Result := '';
  if AValue='' then
    Exit;

  if AValue[1] = '''' then
    //string "'val''ue'" => "val'ue"
    ProcessString
  else
    ProcessOther;
end;

function ExtractValue(const AValue: string; AType: string): string;
var
  StringStart: SizeInt;
begin
  Result := AValue;
  if (AType='') and (AValue<>'') and CharInSet(AValue[1], ['a'..'z', 'A'..'Z']) then
  begin                                            // no type - guess from AValue
    StringStart := Pos('(', AValue);
    if StringStart>0 then
      AType := Copy(AValue, 1, StringStart-1);
  end;
  if (PosI('char',AType)>0) or (PosI('string',AType)>0) then // extract string value
  begin
    StringStart := Pos('''', Result);
    if StringStart>0 then
      Delete(Result, 1, StringStart-1);
  end;
end;

{ TLocalsDlg }

constructor TLocalsDlg.Create(AOwner: TComponent);
var
  i: Integer;
begin
  inherited Create(AOwner);
  LocalsNotification.OnChange     := @LocalsChanged;
  ThreadsNotification.OnCurrent   := @LocalsChanged;
  CallstackNotification.OnCurrent := @LocalsChanged;
  SnapshotNotification.OnCurrent  := @LocalsChanged;

  Caption:= lisLocals;
  lvLocals.Columns[0].Caption:= lisName;
  lvLocals.Columns[1].Caption:= lisValue;
  actInspect.Caption := lisInspect;
  actWath.Caption := lisWatch;
  actEvaluate.Caption := lisEvaluateModify;
  actEvaluateAll.Caption := lisEvaluateAll;
  actCopyName.Caption := lisLocalsDlgCopyName;
  actCopyValue.Caption := lisLocalsDlgCopyValue;
  actCopyRAWValue.Caption := lisLocalsDlgCopyRAWValue;
  actCopyAll.Caption := lisCopyAll;

  for i := low(COL_WIDTHS) to high(COL_WIDTHS) do
    lvLocals.Column[i].Width := COL_WIDTHS[i];
end;

procedure TLocalsDlg.actInspectUpdate(Sender: TObject);
begin
  (Sender as TAction).Enabled := Assigned(lvLocals.Selected);
end;

procedure TLocalsDlg.actCopyRAWValueExecute(Sender: TObject);
begin
  if not DebugBoss.Evaluate(lvLocals.Selected.Caption, @CopyRAWValueEvaluateCallback, []) then
  begin
    Clipboard.Open;
    Clipboard.AsText := ValueToRAW(lvLocals.Selected.SubItems[0]);
    Clipboard.Close;
  end;
end;

procedure TLocalsDlg.actWathExecute(Sender: TObject);
var
  S: String;
  Watch: TCurrentWatch;
begin
  S := lvLocals.Selected.Caption;
  if s = '' then
    exit;
  if DebugBoss.Watches.CurrentWatches.Find(S) = nil then
  begin
    DebugBoss.Watches.CurrentWatches.BeginUpdate;
    try
      Watch := DebugBoss.Watches.CurrentWatches.Add(S);
      Watch.Enabled := True;
      if EnvironmentOptions.DebuggerAutoSetInstanceFromClass then
        Watch.EvaluateFlags := Watch.EvaluateFlags + [defClassAutoCast];
    finally
      DebugBoss.Watches.CurrentWatches.EndUpdate;
    end;
  end;
  DebugBoss.ViewDebugDialog(ddtWatches);
end;

procedure TLocalsDlg.actInspectExecute(Sender: TObject);
begin
  DebugBoss.Inspect(lvLocals.Selected.Caption);
end;

procedure TLocalsDlg.actEvaluateExecute(Sender: TObject);
begin
  DebugBoss.EvaluateModify(lvLocals.Selected.Caption);
end;

procedure TLocalsDlg.actCopyNameExecute(Sender: TObject);
begin
  Clipboard.Open;
  Clipboard.AsText := lvLocals.Selected.Caption;
  Clipboard.Close;
end;

procedure TLocalsDlg.actCopyAllExecute(Sender: TObject);
Var
  AStringList : TStringList;
  I : Integer;
begin
  if lvLocals.Items.Count > 0 then begin
    AStringList := TStringList.Create;
    for I := 0 to lvLocals.Items.Count - 1 do
      AStringList.Values[lvLocals.Items[I].Caption] := lvLocals.Items[I].SubItems[0];
    Clipboard.Open;
    Clipboard.AsText := AStringList.Text;
    Clipboard.Close;
    FreeAndNil(AStringList);
  end;
end;

procedure TLocalsDlg.actCopyAllUpdate(Sender: TObject);
begin
  (Sender as TAction).Enabled := lvLocals.Items.Count > 0;
end;

procedure TLocalsDlg.actCopyValueExecute(Sender: TObject);
begin
  if not DebugBoss.Evaluate(lvLocals.Selected.Caption, @CopyValueEvaluateCallback, []) then
  begin
    Clipboard.Open;
    Clipboard.AsText := lvLocals.Selected.SubItems[0];
    Clipboard.Close;
  end
end;

procedure TLocalsDlg.actEvaluateAllExecute(Sender: TObject);
var
  I: Integer;
begin
  for I := 0 to lvLocals.Items.Count-1 do
  begin
    EvaluateAllCallbackItem := lvLocals.Items[I];
    DebugBoss.Evaluate(EvaluateAllCallbackItem.Caption, @EvaluateAllCallback, []);
  end;
  EvaluateAllCallbackItem := nil;
end;

procedure TLocalsDlg.LocalsChanged(Sender: TObject);
var
  n, idx: Integer;                               
  List: TStringListUTF8Fast;
  Item: TListItem;
  Locals: TIDELocals;
  Snap: TSnapshot;
begin
  if (ThreadsMonitor = nil) or (CallStackMonitor = nil) or (LocalsMonitor=nil) then begin
    lvLocals.Items.Clear;
    exit;
  end;

  if IsUpdating then begin
    DebugLn(DBG_DATA_MONITORS, ['DebugDataWindow: TLocalsDlg.LocalsChanged  in IsUpdating']);
    Include(FUpdateFlags, ufNeedUpdating);
    exit;
  end;
  Exclude(FUpdateFlags, ufNeedUpdating);
  DebugLn(DBG_DATA_MONITORS, ['DebugDataMonitor: TLocalsDlg.LocalsChanged']);

  if GetStackframe < 0 then begin // TODO need dedicated validity property
    lvLocals.Items.Clear;
    exit;
  end;

  Snap := GetSelectedSnapshot;
  if (Snap <> nil)
  then begin
    Locals := LocalsMonitor.Snapshots[Snap][GetThreadId, GetStackframe];
    Caption:= lisLocals + ' ('+ Snap.LocationAsText +')';
  end
  else begin
    Locals := LocalsMonitor.CurrentLocalsList[GetThreadId, GetStackframe];
    Caption:= lisLocals;
  end;

  List := TStringListUTF8Fast.Create;
  try
    BeginUpdate;
    try
      if Locals = nil
      then begin
        lvLocals.Items.Clear;
        Item := lvLocals.Items.Add;
        Item.Caption := '';
        Item.SubItems.add(lisLocalsNotEvaluated);
        Exit;
      end;

      //Get existing items
      for n := 0 to lvLocals.Items.Count - 1 do
      begin
        Item := lvLocals.Items[n];
        List.AddObject(Item.Caption, Item);
      end;

      // add/update entries
      for n := 0 to Locals.Count - 1 do
      begin
        idx := List.IndexOf(Locals.Names[n]);
        if idx = -1
        then begin
          // New entry
          Item := lvLocals.Items.Add;
          Item.Caption := Locals.Names[n];
          Item.SubItems.Add(ExtractValue(Locals.Values[n]));
        end
        else begin
          // Existing entry
          Item := TListItem(List.Objects[idx]);
          Item.SubItems[0] := ExtractValue(Locals.Values[n]);
          List.Delete(idx);
        end;
      end;

      // remove obsolete entries
      for n := 0 to List.Count - 1 do
        lvLocals.Items.Delete(TListItem(List.Objects[n]).Index);

    finally
      EndUpdate;
    end;
  finally
    List.Free;
  end;
end;

function TLocalsDlg.GetThreadId: Integer;
var
  Threads: TIdeThreads;
begin
  Result := -1;
  if (ThreadsMonitor = nil) then exit;
  Threads := GetSelectedThreads(GetSelectedSnapshot);
  if Threads <> nil
  then Result := Threads.CurrentThreadId
  else Result := 1;
end;

function TLocalsDlg.GetSelectedThreads(Snap: TSnapshot): TIdeThreads;
begin
  if ThreadsMonitor = nil then exit(nil);
  if Snap = nil
  then Result := ThreadsMonitor.CurrentThreads
  else Result := ThreadsMonitor.Snapshots[Snap];
end;

function TLocalsDlg.GetStackframe: Integer;
var
  Snap: TSnapshot;
  Threads: TIdeThreads;
  tid: LongInt;
  Stack: TIdeCallStack;
begin
  if (CallStackMonitor = nil) or (ThreadsMonitor = nil)
  then begin
    Result := 0;
    exit;
  end;

  Snap := GetSelectedSnapshot;
  Threads := GetSelectedThreads(Snap);
  if Threads <> nil
  then tid := Threads.CurrentThreadId
  else tid := 1;

  if (Snap <> nil)
  then Stack := CallStackMonitor.Snapshots[Snap].EntriesForThreads[tid]
  else Stack := CallStackMonitor.CurrentCallStackList.EntriesForThreads[tid];

  if Stack <> nil
  then Result := Stack.CurrentIndex
  else Result := 0;
end;

function TLocalsDlg.GetSelectedSnapshot: TSnapshot;
begin
  Result := nil;
  if (SnapshotManager <> nil) and (SnapshotManager.SelectedEntry <> nil)
  then Result := SnapshotManager.SelectedEntry;
end;

procedure TLocalsDlg.DoBeginUpdate;
begin
  lvLocals.BeginUpdate;
end;

procedure TLocalsDlg.DoEndUpdate;
begin
  if ufNeedUpdating in FUpdateFlags then LocalsChanged(nil);
  lvLocals.EndUpdate;
end;

procedure TLocalsDlg.EvaluateAllCallback(Sender: TObject; ASuccess: Boolean;
  ResultText: String; ResultDBGType: TDBGType);
begin
  if ASuccess then
  begin
    if Assigned(EvaluateAllCallbackItem) then
      EvaluateAllCallbackItem.SubItems[0] := ExtractValue(ResultText, ResultDBGType.TypeName);
  end;
  FreeAndNil(ResultDBGType);
end;

function TLocalsDlg.ColSizeGetter(AColId: Integer; var ASize: Integer): Boolean;
begin
  if (AColId - 1 >= 0) and (AColId - 1 < lvLocals.ColumnCount) then begin
    ASize := lvLocals.Column[AColId - 1].Width;
    Result := (ASize <> COL_WIDTHS[AColId - 1]) and (not lvLocals.Column[AColId - 1].AutoSize);
  end
  else
    Result := False;
end;

procedure TLocalsDlg.ColSizeSetter(AColId: Integer; ASize: Integer);
begin
  case AColId of
    COL_LOCALS_NAME:   lvLocals.Column[0].Width := ASize;
    COL_LOCALS_VALUE:  lvLocals.Column[1].Width := ASize;
  end;
end;

procedure TLocalsDlg.CopyRAWValueEvaluateCallback(Sender: TObject;
  ASuccess: Boolean; ResultText: String; ResultDBGType: TDBGType);
begin
  Clipboard.Open;
  if ASuccess then
    Clipboard.AsText := ValueToRAW(ExtractValue(ResultText, ResultDBGType.TypeName))
  else
    Clipboard.AsText := ValueToRAW(lvLocals.Selected.SubItems[0]);
  Clipboard.Close;
  FreeAndNil(ResultDBGType);
end;

procedure TLocalsDlg.CopyValueEvaluateCallback(Sender: TObject;
  ASuccess: Boolean; ResultText: String; ResultDBGType: TDBGType);
begin
  Clipboard.Open;
  if ASuccess then
    Clipboard.AsText := ExtractValue(ResultText, ResultDBGType.TypeName)
  else
    Clipboard.AsText := lvLocals.Selected.SubItems[0];
  Clipboard.Close;
  FreeAndNil(ResultDBGType);
end;

initialization

  LocalsDlgWindowCreator := IDEWindowCreators.Add(DebugDialogNames[ddtLocals]);
  LocalsDlgWindowCreator.OnCreateFormProc := @CreateDebugDialog;
  LocalsDlgWindowCreator.OnSetDividerSize := @LocalsDlgColSizeSetter;
  LocalsDlgWindowCreator.OnGetDividerSize := @LocalsDlgColSizeGetter;
  LocalsDlgWindowCreator.DividerTemplate.Add('LocalsName',  COL_LOCALS_NAME,  @drsColWidthName);
  LocalsDlgWindowCreator.DividerTemplate.Add('LocalsValue', COL_LOCALS_VALUE, @drsColWidthValue);
  LocalsDlgWindowCreator.CreateSimpleLayout;

  DBG_DATA_MONITORS := DebugLogger.FindOrRegisterLogGroup('DBG_DATA_MONITORS' {$IFDEF DBG_DATA_MONITORS} , True {$ENDIF} );

end.


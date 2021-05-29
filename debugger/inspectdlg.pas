{               ----------------------------------------------
                     inspectdlg.pas  -  Inspect Dialog
                ----------------------------------------------

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
unit InspectDlg;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils,
  // LCL
  LCLProc, LCLType, Grids, StdCtrls, Menus, Forms, Controls, Graphics, ComCtrls,
  // IdeIntf
  IDEWindowIntf, IDEImagesIntf, ObjectInspector, PropEdits,
  // DebuggerIntf
  DbgIntfDebuggerBase, DbgIntfBaseTypes,
  // IDE
  LazarusIDEStrConsts, BaseDebugManager, InputHistory, IDEProcs,
  Debugger, DebuggerDlg, DebuggerStrConst, EnvironmentOpts;

type

  { TOIDBGGrid }

  TOIDBGGrid=class(TOIPropertyGrid)
  end;

  { TIDEInspectDlg }

  TIDEInspectDlg = class(TDebuggerDlg)
    EdInspect: TComboBox;
    ErrorLabel: TLabel;
    PageControl: TPageControl;
    StatusBar1: TStatusBar;
    DataPage: TTabSheet;
    PropertiesPage: TTabSheet;
    MethodsPage: TTabSheet;
    ErrorPage: TTabSheet;
    ToolBar1: TToolBar;
    btnUseInstance: TToolButton;
    btnBackward: TToolButton;
    BtnAddWatch: TToolButton;
    ToolButton2: TToolButton;
    btnColClass: TToolButton;
    btnColType: TToolButton;
    btnColVisibility: TToolButton;
    btnForward: TToolButton;
    ToolButton3: TToolButton;
    ToolButton4: TToolButton;
    procedure BtnAddWatchClick(Sender: TObject);
    procedure btnBackwardClick(Sender: TObject);
    procedure btnColClassClick(Sender: TObject);
    procedure btnForwardClick(Sender: TObject);
    procedure btnUseInstanceClick(Sender: TObject);
    procedure EdInspectEditingDone(Sender: TObject);
    procedure EdInspectKeyDown(Sender: TObject; var Key: Word; {%H-}Shift: TShiftState);
    procedure FormActivate(Sender: TObject);
    procedure FormClose(Sender: TObject; var {%H-}CloseAction: TCloseAction);
    procedure FormCreate(Sender: TObject);
    procedure FormKeyDown(Sender: TObject; var Key: Word; {%H-}Shift: TShiftState);
    procedure DataGridDoubleClick(Sender: TObject);
    procedure DataGridMouseDown(Sender: TObject; Button: TMouseButton; {%H-}Shift: TShiftState; {%H-}X,
      {%H-}Y: Integer);
  private
    //FDataGridHook,
    //FPropertiesGridHook,
    //FMethodsGridHook: TPropertyEditorHook;
    //FDataGrid,
    //FPropertiesGrid,
    //FMethodsGrid: TOIDBGGrid;
    FExpression: ansistring;
    FHumanReadable: ansistring;
    FDBGInfo: TDBGType;
    FGridData: TStringGrid;
    FGridMethods: TStringGrid;
    FUpdateLock, FUpdateNeeded, FExpressionWasEvaluated: Boolean;
    FTestUpdateLock: Boolean;
    FRowClicked: Integer;
    FHistory: TStringList;
    FHistoryIndex: Integer;
    procedure EvaluateCallback(Sender: TObject; ASuccess: Boolean;
      ResultText: String; ResultDBGType: TDBGType);
    procedure EvaluateTestCallback(Sender: TObject; ASuccess: Boolean;
      {%H-}ResultText: String; ResultDBGType: TDBGType);
    procedure Localize;
    function  ShortenedExpression: String;
    procedure ContextChanged(Sender: TObject);
    procedure InspectClass;
    procedure InspectRecord;
    procedure InspectVariant;
    procedure InspectSimple;
    procedure InspectEnum;
    procedure InspectSet;
    procedure InspectPointer;
    procedure GridDataSetup(Initial: Boolean = False);
    procedure GridMethodsSetup(Initial: Boolean = False);
    procedure ShowDataFields;
    procedure ShowMethodsFields;
    //procedure ShowError;
    procedure Clear;
    procedure GotoHistory(AIndex: Integer);
  protected
    function  ColSizeGetter(AColId: Integer; var ASize: Integer): Boolean;
    procedure ColSizeSetter(AColId: Integer; ASize: Integer);
    procedure InternalExecute(const AExpression: ansistring);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure Execute(const AExpression: ansistring);
    procedure UpdateData;
  end;

implementation

{$R *.lfm}

var
  InspectDlgWindowCreator: TIDEWindowCreator;

const
  MAX_HISTORY = 1000;
  COL_INSPECT_DNAME       = 1;
  COL_INSPECT_DTYPE       = 2;
  COL_INSPECT_DVALUE      = 3;
  COL_INSPECT_DCLASS      = 4;
  COL_INSPECT_DVISIBILITY = 5;
  COL_INSPECT_MNAME       = 11;
  COL_INSPECT_MTYPE       = 12;
  COL_INSPECT_MRETURNS    = 13;
  COL_INSPECT_MADDRESS    = 14;

function InspectDlgColSizeGetter(AForm: TCustomForm; AColId: Integer; var ASize: Integer): Boolean;
begin
  Result := AForm is TIDEInspectDlg;
  if Result then
    Result := TIDEInspectDlg(AForm).ColSizeGetter(AColId, ASize);
end;

procedure InspectDlgColSizeSetter(AForm: TCustomForm; AColId: Integer; ASize: Integer);
begin
  if AForm is TIDEInspectDlg then
    TIDEInspectDlg(AForm).ColSizeSetter(AColId, ASize);
end;

{ TIDEInspectDlg }

procedure TIDEInspectDlg.FormClose(Sender: TObject; var CloseAction: TCloseAction);
begin
  IDEDialogLayoutList.SaveLayout(Self);
end;

procedure TIDEInspectDlg.FormCreate(Sender: TObject);
begin
  IDEDialogLayoutList.ApplyLayout(Self,300,400);
end;

procedure TIDEInspectDlg.EdInspectKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if (Key = VK_RETURN) then begin
    EdInspectEditingDone(nil);
  end;
end;

procedure TIDEInspectDlg.EdInspectEditingDone(Sender: TObject);
begin
  if FExpression = EdInspect.Text then
    exit;
  Execute(EdInspect.Text);
end;

procedure TIDEInspectDlg.btnUseInstanceClick(Sender: TObject);
begin
  UpdateData;
end;

procedure TIDEInspectDlg.ContextChanged(Sender: TObject);
begin
  UpdateData;
end;

procedure TIDEInspectDlg.DataGridMouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  if Button = mbExtra1 then btnBackwardClick(nil)
  else
  if Button = mbExtra2 then btnForwardClick(nil);
end;

procedure TIDEInspectDlg.EvaluateTestCallback(Sender: TObject;
  ASuccess: Boolean; ResultText: String; ResultDBGType: TDBGType);
begin
  FTestUpdateLock := False;
  if ASuccess and (ResultDBGType <> nil) then begin
    if pos('Cannot access memory at address', ResultDBGType.Value.AsString) = 1 then begin
      FreeAndNil(ResultDBGType);
      Execute(FGridData.Cells[2, FRowClicked] + '(' + FExpression + ')[0]');
      exit;
    end;
    FreeAndNil(ResultDBGType);
  end;
  Execute('(' + FExpression + ')^');
end;

procedure TIDEInspectDlg.DataGridDoubleClick(Sender: TObject);
var
  i: Integer;
  s: String;
  TestOpts: TDBGEvaluateFlags;
begin
  if FTestUpdateLock then
    exit;

  if (FDBGInfo = nil) or (FExpression = '') then exit;

  if (FDBGInfo.Kind in [skClass, skRecord, skObject]) then begin
    i := FGridData.Row;
    if (i < 1) or (i >= FGridData.RowCount) then exit;
    s := FGridData.Cells[1, i];

    if btnUseInstance.Down and (FDBGInfo.Kind = skClass) then
      Execute(FGridData.Cells[0, i] + '(' + FExpression + ').' + s)
    else
      Execute(FExpression + '.' + s);
    exit;
  end;

  if (FDBGInfo.Kind in [skPointer]) then begin
    FTestUpdateLock := true;
    try

      FRowClicked := FGridData.Row;
      if (FRowClicked < 1) or (FRowClicked >= FGridData.RowCount) then exit;
      s := FGridData.Cells[1, FRowClicked];

      //TestOpts := [defFullTypeInfo];
      TestOpts := [];
      if btnUseInstance.Down then
        include(TestOpts, defClassAutoCast);

      if not DebugBoss.Evaluate('(' + FExpression + ')^', @EvaluateTestCallback, TestOpts) then
        EvaluateTestCallback(nil, False, '', nil);
      except
        FTestUpdateLock := False;
      end;
    exit;
  end;

  if (FDBGInfo.Kind in [skSimple]) and (FDBGInfo.Attributes*[saArray,saDynArray] <> []) then begin
    if FDBGInfo.Len < 1 then exit;
    if FDBGInfo.Fields.Count > 0 then begin
      i := FGridData.Row;
      if (i < 1) or (i >= FGridData.RowCount) then exit;
      s := FGridData.Cells[1, i];
      Execute(FExpression + '[' + s + ']');
    end
    else begin
      //
    end;
  end;

end;

procedure TIDEInspectDlg.btnColClassClick(Sender: TObject);
begin
  if (FDBGInfo = nil) then exit;

  if (FDBGInfo.Kind = skClass) then begin
    FGridData.Columns[0].Visible := btnColClass.Down;
    FGridData.Columns[4].Visible := btnColVisibility.Down;
  end;

  FGridData.Columns[2].Visible := btnColType.Down;
end;

procedure TIDEInspectDlg.btnForwardClick(Sender: TObject);
begin
  GotoHistory(FHistoryIndex + 1);
end;

procedure TIDEInspectDlg.btnBackwardClick(Sender: TObject);
begin
  GotoHistory(FHistoryIndex - 1);
end;

procedure TIDEInspectDlg.BtnAddWatchClick(Sender: TObject);
var
  w: TCurrentWatch;
begin
  if DebugBoss = nil then
    exit;
  DebugBoss.Watches.CurrentWatches.BeginUpdate;
  try
    w := DebugBoss.Watches.CurrentWatches.Find(FExpression);
    if w = nil then
      w := DebugBoss.Watches.CurrentWatches.Add(FExpression);
    if (w <> nil) then begin
      w.Enabled := True;
      if EnvironmentOptions.DebuggerAutoSetInstanceFromClass or
         btnUseInstance.Down
      then
        w.EvaluateFlags := w.EvaluateFlags + [defClassAutoCast];
      DebugBoss.ViewDebugDialog(ddtWatches, False);
    end;
  finally
    DebugBoss.Watches.CurrentWatches.EndUpdate;
  end;

end;

procedure TIDEInspectDlg.FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if (Key = VK_ESCAPE) and not Docked then
    Close;
end;

procedure TIDEInspectDlg.Localize;
begin
  Caption := lisInspectDialog;
  DataPage.Caption := lisInspectData;
  PropertiesPage.Caption := lisInspectProperties;
  MethodsPage.Caption := lisInspectMethods;

  btnUseInstance.Caption := lisInspectUseInstance;
  btnUseInstance.Hint    := lisInspectUseInstanceHint;
  btnColClass.Hint       := lisInspectShowColClass;
  btnColType.Hint        := lisInspectShowColType;
  btnColVisibility.Hint  := lisInspectShowColVisibility;
end;

function TIDEInspectDlg.ShortenedExpression: String;
const
  MAX_SHORT_EXPR_LEN = 25;
begin
  Result := FExpression;
  if Length(Result) > MAX_SHORT_EXPR_LEN then
    Result := copy(Result, 1, MAX_SHORT_EXPR_LEN-3) + '...';
end;

procedure TIDEInspectDlg.InspectClass;
begin
  DataPage.TabVisible:=true;
  PropertiesPage.TabVisible:=false;
  MethodsPage.TabVisible:=true;
  if not (PageControl.ActivePage = MethodsPage) then
    PageControl.ActivePage := DataPage;
  FGridData.Columns[0].Visible := btnColClass.Down;
  FGridData.Columns[2].Visible := btnColType.Down;
  FGridData.Columns[4].Visible := btnColVisibility.Down;
  btnUseInstance.Enabled := True;
  btnColClass.Enabled := True;
  btnColType.Enabled := True;
  btnColVisibility.Enabled := True;


  if not Assigned(FDBGInfo) then exit;
  if not Assigned(FDBGInfo.Fields) then exit;
  StatusBar1.SimpleText:=Format(lisInspectClassInherit, [ShortenedExpression, FDBGInfo.
    TypeName, FDBGInfo.Ancestor]);
  GridDataSetup;
  ShowDataFields;
  //FGridData.AutoSizeColumn(1);
  //FGridData.AutoSizeColumn(2);
  GridMethodsSetup;
  ShowMethodsFields;
  //FGridMethods.AutoSizeColumn(1);
  //FGridMethods.AutoSizeColumn(3);
end;

procedure TIDEInspectDlg.InspectVariant;
begin
  DataPage.TabVisible:=true;
  PropertiesPage.TabVisible:=false;
  MethodsPage.TabVisible:=false;
  PageControl.ActivePage := DataPage;
  FGridData.Columns[0].Visible := False;
  FGridData.Columns[2].Visible := btnColType.Down;
  FGridData.Columns[4].Visible := False;
  btnUseInstance.Enabled := False;
  btnColClass.Enabled := False;
  btnColType.Enabled := True;
  btnColVisibility.Enabled := False;

  if not Assigned(FDBGInfo) then exit;
  StatusBar1.SimpleText:=ShortenedExpression+' : Variant';
  GridDataSetup;
  FGridData.Cells[1,1]:=FExpression;
  FGridData.Cells[2,1]:='Variant';
  FGridData.Cells[3,1]:=FDBGInfo.Value.AsString;
  //FGridData.AutoSizeColumn(1);
end;

procedure TIDEInspectDlg.InspectRecord;
begin
  DataPage.TabVisible:=true;
  PropertiesPage.TabVisible:=false;
  MethodsPage.TabVisible:=false;
  PageControl.ActivePage := DataPage;
  FGridData.Columns[0].Visible := False;
  FGridData.Columns[2].Visible := btnColType.Down;
  FGridData.Columns[4].Visible := False;
  btnUseInstance.Enabled := False;
  btnColClass.Enabled := False;
  btnColType.Enabled := True;
  btnColVisibility.Enabled := False;

  if not Assigned(FDBGInfo) then exit;
  if not Assigned(FDBGInfo.Fields) then exit;
  StatusBar1.SimpleText:=ShortenedExpression+' : '+FDBGInfo.TypeName;
  GridDataSetup;
  ShowDataFields;
  //FGridData.AutoSizeColumn(2);
end;

procedure TIDEInspectDlg.InspectSimple;
var
  j: Integer;
  fld: TDBGField;
begin
  DataPage.TabVisible:=true;
  PropertiesPage.TabVisible:=false;
  MethodsPage.TabVisible:=false;
  PageControl.ActivePage := DataPage;
  FGridData.Columns[0].Visible := False;
  FGridData.Columns[2].Visible := btnColType.Down;
  FGridData.Columns[4].Visible := False;
  btnUseInstance.Enabled := False;
  btnColClass.Enabled := False;
  btnColType.Enabled := True;
  btnColVisibility.Enabled := False;

  if not Assigned(FDBGInfo) then exit;
  GridDataSetup;

  if FDBGInfo.Attributes*[saArray,saDynArray] <> [] then begin
    if FDBGInfo.Len >= 0 then
      StatusBar1.SimpleText:=ShortenedExpression+' : '+FDBGInfo.TypeName + ' = Len:' + IntToStr(FDBGInfo.Len) + ' ' + FDBGInfo.Value.AsString
    else
      StatusBar1.SimpleText:=ShortenedExpression+' : '+FDBGInfo.TypeName + ' = ' + FDBGInfo.Value.AsString;

    if FDBGInfo.Fields.Count > 0 then begin
      FGridData.RowCount:=FDBGInfo.Fields.Count+1;
      for j := 0 to FDBGInfo.Fields.Count-1 do begin
        fld := FDBGInfo.Fields[j];
        FGridData.Cells[1,j+1]:=fld.Name; // index
        FGridData.Cells[2,j+1]:=fld.DBGType.TypeName;
        FGridData.Cells[3,j+1]:=fld.DBGType.Value.AsString;
      end;
      exit;
    end;
  end
  else
    StatusBar1.SimpleText:=ShortenedExpression+' : '+FDBGInfo.TypeName + ' = ' + FDBGInfo.Value.AsString;

  FGridData.Cells[1,1]:=FExpression;
  FGridData.Cells[2,1]:=FDBGInfo.TypeName;
  FGridData.Cells[3,1]:=FDBGInfo.Value.AsString;
  //FGridData.AutoSizeColumn(2);
end;

procedure TIDEInspectDlg.InspectEnum;
begin
  DataPage.TabVisible:=true;
  PropertiesPage.TabVisible:=false;
  MethodsPage.TabVisible:=false;
  PageControl.ActivePage := DataPage;
  FGridData.Columns[0].Visible := False;
  FGridData.Columns[2].Visible := btnColType.Down;
  FGridData.Columns[4].Visible := False;
  btnUseInstance.Enabled := False;
  btnColClass.Enabled := False;
  btnColType.Enabled := True;
  btnColVisibility.Enabled := False;

  if not Assigned(FDBGInfo) then exit;
  StatusBar1.SimpleText:=ShortenedExpression+' : '+FDBGInfo.TypeName + ' = ' + FDBGInfo.Value.AsString;
  GridDataSetup;
  FGridData.Cells[1,1]:=FExpression;
  FGridData.Cells[2,1]:=FDBGInfo.TypeName;
  if (FDBGInfo.TypeName <> '') and (FDBGInfo.TypeDeclaration <> '')
  then FGridData.Cells[2,1] := FGridData.Cells[2,1] + ' = ';
  FGridData.Cells[2,1] := FGridData.Cells[2,1] + FDBGInfo.TypeDeclaration;
  FGridData.Cells[3,1]:=FDBGInfo.Value.AsString;
  //FGridData.AutoSizeColumn(2);
end;

procedure TIDEInspectDlg.InspectSet;
begin
  DataPage.TabVisible:=true;
  PropertiesPage.TabVisible:=false;
  MethodsPage.TabVisible:=false;
  PageControl.ActivePage := DataPage;
  FGridData.Columns[0].Visible := False;
  FGridData.Columns[2].Visible := btnColType.Down;
  FGridData.Columns[4].Visible := False;
  btnUseInstance.Enabled := False;
  btnColClass.Enabled := False;
  btnColType.Enabled := True;
  btnColVisibility.Enabled := False;

  if not Assigned(FDBGInfo) then exit;
  StatusBar1.SimpleText:=ShortenedExpression+' : '+FDBGInfo.TypeName + ' = ' + FDBGInfo.Value.AsString;
  GridDataSetup;
  FGridData.Cells[1,1]:=FExpression;
  FGridData.Cells[2,1]:=FDBGInfo.TypeName;
  if (FDBGInfo.TypeName <> '') and (FDBGInfo.TypeDeclaration <> '')
  then FGridData.Cells[2,1] := FGridData.Cells[2,1] + ' = ';
  FGridData.Cells[2,1] := FGridData.Cells[2,1] + FDBGInfo.TypeDeclaration;
  FGridData.Cells[3,1]:=FDBGInfo.Value.AsString;
  //FGridData.AutoSizeColumn(2);
end;

procedure TIDEInspectDlg.InspectPointer;
begin
  DataPage.TabVisible:=true;
  PropertiesPage.TabVisible:=false;
  MethodsPage.TabVisible:=false;
  PageControl.ActivePage := DataPage;
  FGridData.Columns[0].Visible := False;
  FGridData.Columns[2].Visible := btnColType.Down;
  FGridData.Columns[4].Visible := False;
  btnUseInstance.Enabled := False;
  btnColClass.Enabled := False;
  btnColType.Enabled := True;
  btnColVisibility.Enabled := False;

  if not Assigned(FDBGInfo) then exit;
  StatusBar1.SimpleText:=ShortenedExpression+' : '+FDBGInfo.TypeName + ' = ' + FDBGInfo.Value.AsString;
  GridDataSetup;
  FGridData.Cells[1,1]:=FExpression;
  if (FDBGInfo.TypeName <> '') and (FDBGInfo.TypeName[1] = '^')
  then FGridData.Cells[2, 1]:=Format(lisInspectPointerTo, [copy(FDBGInfo.
    TypeName, 2, length(FDBGInfo.TypeName))])
  else FGridData.Cells[2,1]:=FDBGInfo.TypeName;
  {$PUSH}{$RANGECHECKS OFF}
  FGridData.Cells[3,1]:=format('$%x',[{%H-}PtrUInt(FDBGInfo.Value.AsPointer)]);
  {$POP}
  //FGridData.AutoSizeColumn(2);
end;

procedure TIDEInspectDlg.GridDataSetup(Initial: Boolean = False);
begin
  if Initial then
    with FGridData do begin
      Clear;
      BorderStyle:=bsNone;
      BorderWidth:=0;
      DefaultColWidth:=100;
      Options:=[goColSizing,goDblClickAutoSize,goDrawFocusSelected, goThumbTracking,
                          goVertLine,goHorzLine,goFixedHorzLine,goSmoothScroll,
                          goTabs,goRowSelect];
      Align:=alClient;
      TitleFont.Style:=[fsBold];
      ExtendedSelect:=false;
      RowCount:=2;
      FixedRows:=1;
      FixedCols:=0;
      ColCount:=5;
      //Cols[0].Text:='Class';
      //Cols[1].Text:='Name';
      //Cols[2].Text:='Type';
      //Cols[3].Text:='Value';
      //Cols[4].Text:='Visibility';
      Color:=clBtnFace;
      Columns.Add.Title.Caption:=lisColClass;
      Columns.Add.Title.Caption:=lisName;
      Columns.Add.Title.Caption:=dlgEnvType;
      Columns.Add.Title.Caption:=lisValue;
      Columns.Add.Title.Caption:=lisColVisibility;
    end;
  FGridData.RowCount:=1;
  FGridData.RowCount:=2;
  FGridData.FixedRows:=1;
  FGridData.Visible := True;
end;

procedure TIDEInspectDlg.GridMethodsSetup(Initial: Boolean = False);
begin
  if Initial then
    with FGridMethods do begin
      Clear;
      BorderStyle:=bsNone;
      BorderWidth:=0;
      DefaultColWidth:=100;
      Options:=[goColSizing,goDblClickAutoSize,goDrawFocusSelected, goThumbTracking,
                          goVertLine,goHorzLine,goFixedHorzLine,goSmoothScroll,
                          goTabs,goRowSelect];
      Align:=alClient;
      TitleFont.Style:=[fsBold];
      ExtendedSelect:=false;
      RowCount:=2;
      FixedRows:=1;
      FixedCols:=0;
      ColCount:=4;
      Cols[0].Text:=lisName;
      Cols[1].Text:=dlgEnvType;
      Cols[2].Text:=lisColReturns;
      Cols[3].Text:=lisColAddress;
      Color:=clBtnFace;
    end;
  FGridMethods.RowCount:=1;
  FGridMethods.RowCount:=2;
  FGridMethods.FixedRows:=1;
end;

procedure TIDEInspectDlg.ShowDataFields;
const
  FieldLocationNames: array[TDBGFieldLocation] of string = //(flPrivate, flProtected, flPublic, flPublished);
    ('Private', 'Protected', 'Public', 'Published');
var
  j,k: SizeInt;
  fld: TDBGField;
begin
  k:=0;
  for j := 0 to FDBGInfo.Fields.Count-1 do begin
    case FDBGInfo.Fields[j].DBGType.Kind of
      skSimple,skRecord,skVariant,skPointer: inc(k);
    end;
  end;
  k:=k+1;
  if k<2 Then k:=2;
  FGridData.RowCount:=k;
  k:=0;
  for j := 0 to FDBGInfo.Fields.Count-1 do begin
    fld := FDBGInfo.Fields[j];
    case fld.DBGType.Kind of
      skSimple:
        begin
          inc(k);
          FGridData.Cells[1,k]:=fld.Name;
          FGridData.Cells[2,k]:=fld.DBGType.TypeName;
          if fld.DBGType.Value.AsString='$0' then begin
            if fld.DBGType.TypeName='ANSISTRING' then begin
              FGridData.Cells[3,k]:='''''';
            end else begin
              FGridData.Cells[3,k]:='nil';
            end;
          end else begin
            FGridData.Cells[3,k]:=fld.DBGType.Value.AsString;
          end;
          FGridData.Cells[0,k]:=fld.ClassName;
          FGridData.Cells[4,k]:=FieldLocationNames[fld.Location];
        end;
      skRecord:
        begin
          inc(k);
          FGridData.Cells[1,k]:=fld.Name;
          FGridData.Cells[2,k]:='Record '+fld.DBGType.TypeName;
          FGridData.Cells[3,k]:=fld.DBGType.Value.AsString;
          FGridData.Cells[0,k]:=fld.ClassName;
          FGridData.Cells[4,k]:=FieldLocationNames[fld.Location];
        end;
      skVariant:
        begin
          inc(k);
          FGridData.Cells[1,k]:=fld.Name;
          FGridData.Cells[2,k]:='Variant';
          FGridData.Cells[3,k]:=fld.DBGType.Value.AsString;
          FGridData.Cells[0,k]:=fld.ClassName;
          FGridData.Cells[4,k]:=FieldLocationNames[fld.Location];
        end;
      skProcedure,skProcedureRef:
        begin
        end;
      skFunction,skFunctionRef:
        begin
        end;
       skPointer:
        begin
          inc(k);
          FGridData.Cells[1,k]:=fld.Name;
          FGridData.Cells[2,k]:='Pointer '+fld.DBGType.TypeName;
          FGridData.Cells[3,k]:=fld.DBGType.Value.AsString;
          FGridData.Cells[0,k]:=fld.ClassName;
          FGridData.Cells[4,k]:=FieldLocationNames[fld.Location];
        end;
      else
        raise Exception.Create('Inspect: Unknown type in record ->'+inttostr(ord(fld.DBGType.Kind)));
    end;
  end;
end;

procedure TIDEInspectDlg.ShowMethodsFields;
var
  j,k: SizeInt;
begin
  k:=0;
  for j := 0 to FDBGInfo.Fields.Count-1 do begin
    case FDBGInfo.Fields[j].DBGType.Kind of
      skProcedure,skFunction,skProcedureRef, skFunctionRef: inc(k);
    end;
  end;
  k:=k+1;
  if k<2 Then k:=2;
  FGridMethods.RowCount:=k;
  k:=0;
  for j := 0 to FDBGInfo.Fields.Count-1 do begin
    case FDBGInfo.Fields[j].DBGType.Kind of
      skProcedure, skProcedureRef:
        begin
          inc(k);
          FGridMethods.Cells[0,k]:=FDBGInfo.Fields[j].Name;
          if ffDestructor in FDBGInfo.Fields[j].Flags then begin
            FGridMethods.Cells[1,k]:='Destructor';
          end else begin
            FGridMethods.Cells[1,k]:='Procedure';
          end;
          FGridMethods.Cells[2,k]:='';
          FGridMethods.Cells[3,k]:='???';
        end;
      skFunction, skFunctionRef:
        begin
          inc(k);
          FGridMethods.Cells[0,k]:=FDBGInfo.Fields[j].Name;
          if ffConstructor in FDBGInfo.Fields[j].Flags then begin
            FGridMethods.Cells[1,k]:='Constructor';
          end else begin
            FGridMethods.Cells[1,k]:='Function';
          end;
          if Assigned(FDBGInfo.Fields[j].DBGType.Result) then begin
            FGridMethods.Cells[2,k]:=FDBGInfo.Fields[j].DBGType.Result.TypeName;
          end else begin
            FGridMethods.Cells[2,k]:='';
          end;
          FGridMethods.Cells[3,k]:='???';
        end;
    end;
  end;
end;

procedure TIDEInspectDlg.Clear;
begin
  DataPage.TabVisible:=false;
  PropertiesPage.TabVisible:=false;
  MethodsPage.TabVisible:=false;
  ErrorPage.TabVisible:=false;
  GridDataSetup;
  FGridData.Visible := False;
  StatusBar1.SimpleText:='';
end;

function TIDEInspectDlg.ColSizeGetter(AColId: Integer; var ASize: Integer): Boolean;
begin
  ASize := -1;
  case AColId of
    COL_INSPECT_DNAME:    ASize := FGridData.ColWidths[1];
    COL_INSPECT_DTYPE:    ASize := FGridData.ColWidths[2];
    COL_INSPECT_DVALUE:   ASize := FGridData.ColWidths[3];
    COL_INSPECT_DCLASS:   ASize := FGridData.ColWidths[0];
    COL_INSPECT_DVISIBILITY:   ASize := FGridData.ColWidths[4];
    COL_INSPECT_MNAME:    ASize := FGridMethods.ColWidths[0];
    COL_INSPECT_MTYPE:    ASize := FGridMethods.ColWidths[1];
    COL_INSPECT_MRETURNS: ASize := FGridMethods.ColWidths[2];
    COL_INSPECT_MADDRESS: ASize := FGridMethods.ColWidths[3];
  end;
  Result := (ASize > 0) and (ASize <> 100); // The default for all
end;

procedure TIDEInspectDlg.ColSizeSetter(AColId: Integer; ASize: Integer);
begin
  case AColId of
    COL_INSPECT_DNAME:    FGridData.ColWidths[1]:= ASize;
    COL_INSPECT_DTYPE:    FGridData.ColWidths[2]:= ASize;
    COL_INSPECT_DVALUE:   FGridData.ColWidths[3]:= ASize;
    COL_INSPECT_DCLASS:   FGridData.ColWidths[0]:= ASize;
    COL_INSPECT_DVISIBILITY:   FGridData.ColWidths[4]:= ASize;
    COL_INSPECT_MNAME:    FGridMethods.ColWidths[0]:= ASize;
    COL_INSPECT_MTYPE:    FGridMethods.ColWidths[1]:= ASize;
    COL_INSPECT_MRETURNS: FGridMethods.ColWidths[2]:= ASize;
    COL_INSPECT_MADDRESS: FGridMethods.ColWidths[3]:= ASize;
  end;
end;

constructor TIDEInspectDlg.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);

  FUpdateLock := False;
  FUpdateNeeded := False;
  Localize;


  ThreadsNotification.OnCurrent := @ContextChanged;
  CallstackNotification.OnCurrent := @ContextChanged;

  FHistory := TStringList.Create;

  FGridData:=TStringGrid.Create(DataPage);
  DataPage.InsertControl(FGridData);
  GridDataSetup(True);

  FGridMethods:=TStringGrid.Create(MethodsPage);
  MethodsPage.InsertControl(FGridMethods);
  GridMethodsSetup(True);

  EdInspect.Items.Assign(InputHistories.HistoryLists.
    GetList(ClassName,True,rltCaseSensitive));

  FGridData.OnDblClick := @DataGridDoubleClick;
  FGridData.OnMouseDown := @DataGridMouseDown;
  FGridMethods.OnMouseDown := @DataGridMouseDown;

  ToolBar1.Images := IDEImages.Images_16;
  btnBackward.ImageIndex := IDEImages.LoadImage('arrow_left');
  btnBackward.Caption := '';
  btnForward.ImageIndex := IDEImages.LoadImage('arrow_right');
  btnForward.Caption := '';
  BtnAddWatch.Caption:=lisInspectAddWatch;

  btnUseInstance.Enabled := False;
  btnUseInstance.Down := EnvironmentOptions.DebuggerAutoSetInstanceFromClass;
  btnColClass.Enabled := False;
  btnColType.Enabled := False;
  btnColVisibility.Enabled := False;
  btnBackward.Enabled := FHistoryIndex > 0;
  btnForward.Enabled := FHistoryIndex < FHistory.Count - 1;

  Clear;
end;

destructor TIDEInspectDlg.Destroy;
begin
  FreeAndNil(FDBGInfo);
  FreeAndNil(FHistory);
  //FreeAndNil(FDataGridHook);
  //FreeAndNil(FPropertiesGridHook);
  //FreeAndNil(FMethodsGridHook);
  inherited Destroy;
end;

procedure TIDEInspectDlg.InternalExecute(const AExpression: ansistring);
begin
  if FHistoryIndex >= FHistory.Count then
    FHistoryIndex := FHistory.Count - 1;
  inc(FHistoryIndex);
  while FHistory.Count > FHistoryIndex do
    FHistory.Delete(FHistoryIndex);

  FHistoryIndex := FHistory.Add(AExpression);

  while FHistory.Count > MAX_HISTORY do
    FHistory.Delete(0);

  GotoHistory(FHistoryIndex);
end;

procedure TIDEInspectDlg.Execute(const AExpression: ansistring);
begin
  InternalExecute(AExpression);
end;

procedure TIDEInspectDlg.FormActivate(Sender: TObject);
begin
  EdInspect.DropDownCount := EnvironmentOptions.DropDownCount;
end;

procedure TIDEInspectDlg.GotoHistory(AIndex: Integer);
begin
  FHistoryIndex := AIndex;
  if FHistory.Count = 0 then exit;
  if FHistoryIndex >= FHistory.Count then
    FHistoryIndex := FHistory.Count - 1;
  if FHistoryIndex < 0 then
    FHistoryIndex := 0;

  btnBackward.Enabled := FHistoryIndex > 0;
  btnForward.Enabled := FHistoryIndex < FHistory.Count - 1;

  if (FExpression=FHistory[FHistoryIndex]) and FExpressionWasEvaluated then
    exit;

  FExpression:=FHistory[FHistoryIndex];
  EdInspect.Text := FExpression;
  UpdateData;
end;

procedure TIDEInspectDlg.EvaluateCallback(Sender: TObject; ASuccess: Boolean;
  ResultText: String; ResultDBGType: TDBGType);
begin
  FUpdateLock := False;
  FExpressionWasEvaluated := True;

  FHumanReadable := ResultText;
  FDBGInfo := ResultDBGType;

  if not ASuccess or not assigned(FDBGInfo) then
  begin
    FreeAndNil(FDBGInfo);
    Clear;
    StatusBar1.SimpleText:=Format(lisInspectUnavailableError, [ShortenedExpression, FHumanReadable]);
    ErrorLabel.Caption :=Format(lisInspectUnavailableError, [ShortenedExpression, FHumanReadable]);
    PageControl.ActivePage := ErrorPage;
    Exit;
  end;
  case FDBGInfo.Kind of
    skClass, skObject, skInterface: InspectClass();
    skRecord: InspectRecord();
    skVariant: InspectVariant();
    skEnum: InspectEnum;
    skSet: InspectSet;
    skProcedure, skProcedureRef: InspectSimple;
    skFunction, skFunctionRef: InspectSimple;
    skSimple,
    skInteger,
    skCardinal, skBoolean, skChar, skFloat: InspectSimple();
    skArray: InspectSimple();
    skPointer: InspectPointer();
    skString, skAnsiString, skWideString: InspectSimple;
  //  skDecomposable: ;
    else begin
        Clear;
        StatusBar1.SimpleText:=Format(lisInspectUnavailableError, [ShortenedExpression, FHumanReadable]);
        ErrorLabel.Caption :=Format(lisInspectUnavailableError, [ShortenedExpression, FHumanReadable]);
        PageControl.ActivePage := ErrorPage;
      end;
  end;
end;

procedure TIDEInspectDlg.UpdateData;
var
  Opts: TDBGEvaluateFlags;
begin
  FExpressionWasEvaluated := False;
  if DebugBoss.State in [dsRun, dsStop, dsIdle] then begin
    // No request can be running
    FUpdateLock := False;
    FTestUpdateLock := False;
  end;

  if FUpdateLock then begin
    FUpdateNeeded := True;
    exit;
  end;

  if FExpression = '' then begin
    Clear;
    StatusBar1.SimpleText := '';
    exit;
  end;

  FUpdateLock := True;
  FUpdateNeeded := False;
  try
    FreeAndNil(FDBGInfo);

    InputHistories.HistoryLists.Add(ClassName, FExpression,rltCaseSensitive);
    if EdInspect.Items.IndexOf(FExpression) = -1
    then EdInspect.Items.Insert(0, FExpression);

    Opts := [defFullTypeInfo];
    if btnUseInstance.Down then
      include(Opts, defClassAutoCast);

    if not DebugBoss.Evaluate(FExpression, @EvaluateCallback, Opts) then
      EvaluateCallback(nil, False, '', nil);

  except
    FUpdateLock := False;
  end;

  if FUpdateNeeded then
    UpdateData;
end;

initialization

  InspectDlgWindowCreator := IDEWindowCreators.Add(DebugDialogNames[ddtInspect]);
  InspectDlgWindowCreator.OnCreateFormProc := @CreateDebugDialog;
  InspectDlgWindowCreator.OnSetDividerSize := @InspectDlgColSizeSetter;
  InspectDlgWindowCreator.OnGetDividerSize := @InspectDlgColSizeGetter;
  InspectDlgWindowCreator.DividerTemplate.Add('InspectDataName',       COL_INSPECT_DNAME, @drsInspectColWidthDataName);
  InspectDlgWindowCreator.DividerTemplate.Add('InspectDataType',       COL_INSPECT_DTYPE, @drsInspectColWidthDataType);
  InspectDlgWindowCreator.DividerTemplate.Add('InspectDataValue',      COL_INSPECT_DVALUE, @drsInspectColWidthDataValue);
  InspectDlgWindowCreator.DividerTemplate.Add('InspectDataClass',      COL_INSPECT_DCLASS, @drsInspectColWidthDataClass);
  InspectDlgWindowCreator.DividerTemplate.Add('InspectDataVisibility', COL_INSPECT_DVISIBILITY, @drsInspectColWidthDataVisibility);

  InspectDlgWindowCreator.DividerTemplate.Add('InspectMethName',    COL_INSPECT_MNAME,    @drsInspectColWidthMethName);
  InspectDlgWindowCreator.DividerTemplate.Add('InspectMethType',    COL_INSPECT_MTYPE,    @drsInspectColWidthMethType);
  InspectDlgWindowCreator.DividerTemplate.Add('InspectMethReturns', COL_INSPECT_MRETURNS, @drsInspectColWidthMethReturns);
  InspectDlgWindowCreator.DividerTemplate.Add('InspectMethAddress', COL_INSPECT_MADDRESS, @drsInspectColWidthMethAddress);
  InspectDlgWindowCreator.CreateSimpleLayout;

end.


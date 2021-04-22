unit opkman_packagelistfrm;

{$mode objfpc}{$H+}
{
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

 Author: Balázs Székely
}
interface

uses
  SysUtils, Classes,
  // LCL
  Forms, Controls, Graphics, ExtCtrls, StdCtrls, laz.VirtualTrees,
  // OpkMan
  opkman_const, opkman_common, opkman_serializablepackages, opkman_options, opkman_visualtree,
  opkman_maindm;

type

  { TPackageListFrm }

  TPackageListFrm = class(TForm)
    bOk: TButton;
    bYes: TButton;
    bNo: TButton;
    lbHint: TLabel;
    lbMessage: TLabel;
    pnUpDown: TPanel;
    pnMessage: TPanel;
    pnButtons: TPanel;
    procedure FormClose(Sender: TObject; var {%H-}CloseAction: TCloseAction);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormKeyPress(Sender: TObject; var Key: char);
    procedure lbMessageResize(Sender: TObject);
  private
    FVST: TLazVirtualStringTree;
    FSL: TStringList;
    FModRes: TModalResult;
    function GetCount: Integer;
    procedure SetupControls(const ATyp: Integer);
    procedure VSTGetText(Sender: TBaseVirtualTree; Node: PVirtualNode;
      Column: TColumnIndex; {%H-}TextType: TVSTTextType; var CellText: String);
    procedure VSTGetImageIndex(Sender: TBaseVirtualTree; Node: PVirtualNode;
      {%H-}Kind: TVTImageKind; Column: TColumnIndex; var {%H-}Ghosted: Boolean;
      var ImageIndex: Integer);
    procedure VSTPaintText(Sender: TBaseVirtualTree;
      const TargetCanvas: TCanvas; Node: PVirtualNode; {%H-}Column: TColumnIndex;
      {%H-}TextType: TVSTTextType);
    procedure VSTCompareNodes(Sender: TBaseVirtualTree; Node1,
      Node2: PVirtualNode; Column: TColumnIndex; var Result: Integer);
    procedure VSTGetHint(Sender: TBaseVirtualTree; Node: PVirtualNode; Column: TColumnIndex;
      var LineBreakStyle: TVTTooltipLineBreakStyle; var HintText: String);
    procedure VSTFreeNode(Sender: TBaseVirtualTree; Node: PVirtualNode);
    function IsNodeVisible(const APackageName: String): Boolean;
    function IsLazarusCompatible(const ALazVersions: String): Boolean;
    function IsFPCCompatible(const AFPCVersions: String): Boolean;
    function IsWidgetSetCompatible(const AWidgetSets: String): Boolean;
  public
    procedure PopulateList(const ATyp: Integer; const AExtra: String = '');
    property Count: Integer read GetCount;
  end;

var
  PackageListFrm: TPackageListFrm;

implementation

{$R *.lfm}

{ TPackageListFrm }

type
  PData = ^TData;
  TData = record
    FName: string[100];
    FImageIndex: Integer;
    FSupLazVers: String;
    FIsLazComp: Boolean;
    FSupFPCVers: String;
    FIsFPCComp: Boolean;
    FSupWS: String;
    FIsWSComp: Boolean;
  end;

procedure TPackageListFrm.FormKeyPress(Sender: TObject; var Key: char);
begin
  if Key = #13 then
  begin
    FModRes := mrYes;
    Close;
  end
  else if Key = #27 then
  begin
    FModRes := mrNo;
    Close;
  end;
end;

procedure TPackageListFrm.lbMessageResize(Sender: TObject);
begin
  pnMessage.Height := lbMessage.Top + lbMessage.Height + 5;
end;

function TPackageListFrm.GetCount: Integer;
begin
  Result := FVST.RootNodeCount;
end;

procedure TPackageListFrm.SetupControls(const ATyp: Integer);
begin
  FModRes := mrNone;
  case ATyp of
    0: Caption := rsPackageListFrm_Caption0;
    1: Caption := rsPackageListFrm_Caption1;
    2: Caption := rsPackageListFrm_Caption0;
    3: begin
         Caption := rsPackageListFrm_Caption3;
         Self.Width := 650;
         Self.BorderStyle := bsSizeable;
         FVST.Header.Options := FVST.Header.Options + [hoVisible];
         FVST.Header.Columns.Items[1].Options := FVST.Header.Columns.Items[1].Options + [coVisible];
         FVST.Header.Columns.Items[2].Options := FVST.Header.Columns.Items[2].Options + [coVisible];
         FVST.Header.Columns.Items[3].Options := FVST.Header.Columns.Items[3].Options + [coVisible];
         FVST.TreeOptions.MiscOptions := FVST.TreeOptions.MiscOptions + [toReportMode];
         lbHint.Visible := True;
       end;
  end;
  bYes.Caption := rsPackageListFrm_bYes_Caption;
  bNo.Caption := rsPackageListFrm_bNo_Caption;
  bOk.Caption := rsPackageListFrm_bOk_Caption;
  lbHint.Caption := rsPackageListFrm_lbHint_Caption;
  bYes.Top := (pnButtons.Height - bYes.Height) div 2;
  bNo.Top := (pnButtons.Height - bNo.Height) div 2;
  bOk.Top := (pnButtons.Height - bOk.Height) div 2;
  pnMessage.Height := lbMessage.Top + lbMessage.Height + 5;
end;

procedure TPackageListFrm.PopulateList(const ATyp: Integer; const AExtra: String);
var
  I, J: Integer;
  Node: PVirtualNode;
  Data: PData;
  LazarusPkg: TLazarusPackage;
  ChkCnt, InvCnt: Integer;
  LazComp, FPCComp, WSComp: Boolean;
  NoURL: Boolean;
begin
  SetupControls(ATyp);
  ChkCnt := 0;
  InvCnt := 0;
  for I := 0 to SerializablePackages.Count - 1 do
  begin
    if not IsNodeVisible(SerializablePackages.Items[I].DisplayName) then
      Continue;
    if ATyp = 0 then
    begin
      for J := 0 to SerializablePackages.Items[I].LazarusPackages.Count - 1  do
      begin
        LazarusPkg := TLazarusPackage(SerializablePackages.Items[I].LazarusPackages.Items[J]);
        if (LazarusPkg.Checked) and (psInstalled in LazarusPkg.PackageStates) then
        begin
          Node := FVST.AddChild(nil);
          Data := FVST.GetNodeData(Node);
          Data^.FName := LazarusPkg.Name + '(' + LazarusPkg.InstalledFileVersion + ')';
          Data^.FImageIndex := IMG_PKG_FILE;
        end;
      end;
    end
    else if ATyp = 1 then
    begin
      if (SerializablePackages.Items[I].Checked) and (FileExists(AExtra + SerializablePackages.Items[I].RepositoryFileName)) then
      begin
        Node := FVST.AddChild(nil);
        Data := FVST.GetNodeData(Node);
        if SerializablePackages.Items[I].DisplayName <> '' then
          Data^.FName := SerializablePackages.Items[I].DisplayName
        else
          Data^.FName := SerializablePackages.Items[I].Name;
        Data^.FImageIndex := IMG_PKG_PLUS;
      end;
    end
    else if ATyp = 2 then
    begin
      if (SerializablePackages.Items[I].Checked) then
      begin
        Inc(ChkCnt);
        NoURL := (Trim(SerializablePackages.Items[I].DownloadURL) = '') or (Trim(SerializablePackages.Items[I].DownloadZipURL) = '');
        if NoURL and (not SerializablePackages.Items[I].IsDependencyPackage) then
        begin
          Inc(InvCnt);
          Node := FVST.AddChild(nil);
          Data := FVST.GetNodeData(Node);
          if SerializablePackages.Items[I].DisplayName <> '' then
            Data^.FName := SerializablePackages.Items[I].DisplayName
          else
            Data^.FName := SerializablePackages.Items[I].Name;
          Data^.FImageIndex := IMG_PKG_PLUS;
          SerializablePackages.Items[I].ChangePackageStates(ctAdd, psError);
        end;
      end;
    end
    else if ATyp = 3 then
    begin
      for J := 0 to SerializablePackages.Items[I].LazarusPackages.Count - 1  do
      begin
        LazarusPkg := TLazarusPackage(SerializablePackages.Items[I].LazarusPackages.Items[J]);
        if (LazarusPkg.Checked) then
        begin
          LazComp := IsLazarusCompatible(LazarusPkg.LazCompatibility);
          FPCComp := IsFPCCompatible(LazarusPkg.FPCCompatibility);
          WSComp := IsWidgetSetCompatible(LazarusPkg.SupportedWidgetSet);
          if (not LazComp) or (not FPCComp) or (not WSComp) then
          begin
            Node := FVST.AddChild(nil);
            Data := FVST.GetNodeData(Node);
            Data^.FName := LazarusPkg.Name + '(' + LazarusPkg.VersionAsString + ')';
            Data^.FImageIndex := IMG_PKG_FILE;
            Data^.FSupLazVers := LazarusPkg.LazCompatibility;
            Data^.FIsLazComp := LazComp;
            Data^.FSupFPCVers := LazarusPkg.FPCCompatibility;
            Data^.FIsFPCComp := FPCComp;
            Data^.FSupWS := LazarusPkg.SupportedWidgetSet;
            Data^.FIsWSComp := WSComp;
          end;
        end;
      end;
    end;
  end;
  if (ATyp = 2) and (ChkCnt = InvCnt) then
  begin
    bYes.Visible := False;
    bNo.Visible := False;
    bOk.Visible := True;
    lbMessage.Caption := rsMainFrm_PackageUpdate1;
  end;
  FVST.SortTree(0, sdAscending);
end;

procedure TPackageListFrm.FormClose(Sender: TObject;
  var CloseAction: TCloseAction);
begin
  if FModRes <> mrNone then
    ModalResult := FModRes;
end;

procedure TPackageListFrm.FormCreate(Sender: TObject);
begin
  if not Options.UseDefaultTheme then
    Self.Color := clBtnFace;
  FVST := TLazVirtualStringTree.Create(nil);
  with FVST do
  begin
    Parent := Self;
    Align := alClient;
    Anchors := [akLeft, akTop, akRight];
    Images := MainDM.Images;
    if not Options.UseDefaultTheme then
      Color := clBtnFace;
    DefaultNodeHeight := Scale96ToForm(25);
    Indent := 0;
    TabOrder := 1;
    DefaultText := '';
    Header.AutoSizeIndex := 0;
    Header.Height := Scale96ToForm(25);
    Colors.BorderColor := clBlack;
    BorderSpacing.Top := Scale96ToForm(5);
    BorderSpacing.Left := Scale96ToForm(15);
    BorderSpacing.Right := Scale96ToForm(15);
    Header.Options := [hoAutoResize, hoColumnResize, hoRestrictDrag, hoAutoSpring];
    with Header.Columns.Add do begin
      Position := 0;
      Width := Scale96ToForm(250);
      Text := rsMainFrm_VSTHeaderColumn_PackageName;
    end;
    with Header.Columns.Add do
    begin
      Position := 1;
      Width := FVST.Scale96ToForm(110);
      Alignment := taCenter;
      Options := Options - [coVisible];
      Text := 'FPC';
    end;
    with Header.Columns.Add do
    begin
      Position := 2;
      Width := FVST.Scale96ToForm(110);
      Alignment := taCenter;
      Options := Options - [coVisible];
      Text := 'Lazarus';
    end;
    with Header.Columns.Add do
    begin
      Position := 3;
      Width := FVST.Scale96ToForm(110);
      Alignment := taCenter;
      Options := Options - [coVisible];
      Text := 'Widgetset';
    end;
    Header.SortColumn := 0;
    HintMode := hmHint;
    ShowHint := True;
    TreeOptions.MiscOptions := [toFullRepaintOnResize, toInitOnSave, toToggleOnDblClick, toWheelPanning];
    TreeOptions.PaintOptions := [toHideFocusRect, toPopupMode, toShowButtons, toShowDropmark, toThemeAware, toUseBlendedImages];
    TreeOptions.SelectionOptions := [toFullRowSelect, toRightClickSelect];
    TreeOptions.AutoOptions := [toAutoTristateTracking];
    OnGetText := @VSTGetText;
    OnPaintText := @VSTPaintText;
    OnGetImageIndex := @VSTGetImageIndex;
    OnCompareNodes := @VSTCompareNodes;
    OnGetHint := @VSTGetHint;
    OnFreeNode := @VSTFreeNode;
  end;
  FVST.NodeDataSize := SizeOf(TData);
  FSL := TStringList.Create;
  FSL.Delimiter := ',';
  FSL.StrictDelimiter := True;
end;

procedure TPackageListFrm.FormDestroy(Sender: TObject);
begin
  FSL.Free;
  FVST.Clear;
  FVST.Free;
end;

procedure TPackageListFrm.VSTGetText(Sender: TBaseVirtualTree;
  Node: PVirtualNode; Column: TColumnIndex; TextType: TVSTTextType;
  var CellText: String);
var
  Data: PData;
begin
  Data := FVST.GetNodeData(Node);
  case Column of
    0: CellText := Data^.FName;
    1: if Data^.FIsFPCComp then
         CellText := 'OK'
       else
         CellText := rsPackageListFrm_Incompatible;
    2: if Data^.FIsLazComp then
         CellText := 'OK'
       else
         CellText := rsPackageListFrm_Incompatible;
    3: if Data^.FIsWSComp then
         CellText := 'OK'
       else
         CellText := rsPackageListFrm_Incompatible;
  end;
end;

procedure TPackageListFrm.VSTGetImageIndex(Sender: TBaseVirtualTree;
  Node: PVirtualNode; Kind: TVTImageKind; Column: TColumnIndex;
  var Ghosted: Boolean; var ImageIndex: Integer);
var
  Data: PData;
begin
  Data := FVST.GetNodeData(Node);
  if Column = 0 then
    ImageIndex := Data^.FImageIndex;
end;

procedure TPackageListFrm.VSTPaintText(Sender: TBaseVirtualTree;
  const TargetCanvas: TCanvas; Node: PVirtualNode; Column: TColumnIndex;
  TextType: TVSTTextType);

  function GetColor(const AIsComp: Boolean): TColor;
  begin
    if (Node = Sender.FocusedNode) then
      Result := FVST.Colors.SelectionTextColor
    else
      if AIsComp then
        Result := clBlack
      else
        Result := clRed;
  end;

var
  Data: PData;
begin
  if TextType = ttNormal then
  begin
    Data := FVST.GetNodeData(Node);
    case Column of
      1: TargetCanvas.Font.Color := GetColor(Data^.FIsFPCComp);
      2: TargetCanvas.Font.Color := GetColor(Data^.FIsLazComp);
      3: TargetCanvas.Font.Color := GetColor(Data^.FIsWSComp);
    end;
  end;
end;

procedure TPackageListFrm.VSTCompareNodes(Sender: TBaseVirtualTree; Node1,
  Node2: PVirtualNode; Column: TColumnIndex; var Result: Integer);
var
  Data1: PData;
  Data2: PData;
begin
  Data1 := Sender.GetNodeData(Node1);
  Data2 := Sender.GetNodeData(Node2);
  if Column = 0 then
    Result := CompareText(Data1^.FName, Data2^.FName);
end;

procedure TPackageListFrm.VSTGetHint(Sender: TBaseVirtualTree;
  Node: PVirtualNode; Column: TColumnIndex;
  var LineBreakStyle: TVTTooltipLineBreakStyle; var HintText: String);
var
  Data: PData;
  CurFPCVer, CurLazVer: String;
  SupFPCVers, SupLazVers: String;
begin
  Data := FVST.GetNodeData(Node);
  LineBreakStyle := hlbForceSingleLine;

  if CurFPCVersion = FPCTrunk then
    CurFPCVer := 'Trunk'
  else
    CurFPCVer := CurFPCVersion;
  SupFPCVers := StringReplace(Data^.FSupFPCVers, FPCTrunk, 'Trunk', [rfIgnoreCase, rfReplaceAll]);

  if CurLazVersion = LazTrunk then
    CurLazVer := 'Trunk'
  else
    CurLazVer := CurLazVersion;
  SupLazVers := StringReplace(Data^.FSupLazVers, LazTrunk, 'Trunk', [rfIgnoreCase, rfReplaceAll]);
  case Column of
    1: HintText := rsPackageListFrm_CurFPCVer + CurFPCVer + sLineBreak +
                   rsPackageListFrm_SupFPCVers + SupFPCVers;
    2: HintText := rsPackageListFrm_CurLazVer + CurLazVer + sLineBreak +
                   rsPackageListFrm_SupLazVers + SupLazVers;
    3: HintText := rsPackageListFrm_CurWS + CurWidgetSet + sLineBreak +
                   rsPackageListFrm_SupWSs + Data^.FSupWS;
    else
       HintText := '';
  end;
end;

procedure TPackageListFrm.VSTFreeNode(Sender: TBaseVirtualTree;
  Node: PVirtualNode);
var
  Data: PData;
begin
  Data := FVST.GetNodeData(Node);
  Finalize(Data^);
end;

function TPackageListFrm.IsNodeVisible(const APackageName: String): Boolean;
var
  Node: PVirtualNode;
  Data: opkman_visualtree.PData;
begin
  Result := False;
  Node := VisualTree.VST.GetFirst;
  while Assigned(Node) do
  begin
    Data := VisualTree.VST.GetNodeData(Node);
    if (Data^.DataType = 1) and (Data^.PackageDisplayName = APackageName) then
    begin
      Result := VisualTree.VST.IsVisible[Node];
      Break;
    end;
    Node := VisualTree.VST.GetNext(Node);
  end;
end;

function TPackageListFrm.IsLazarusCompatible(const ALazVersions: String): Boolean;
var
  LazVersion: String;
  I: Integer;
begin
  Result := False;
  FSL.Clear;
  FSL.DelimitedText := ALazVersions;
  for I := 0 to FSL.Count - 1 do
  begin
    LazVersion := Trim(FSL.Strings[I]);
    if LazVersion <> 'Trunk' then
      Result := LazVersion = CurLazVersion
    else
      Result := CurLazVersion >= LazTrunk;
    if Result then
      Exit;
  end;
end;

function TPackageListFrm.IsFPCCompatible(const AFPCVersions: String): Boolean;
var
  FPCVersion: String;
  I: Integer;
begin
  Result := False;
  FSL.Clear;
  FSL.DelimitedText := AFPCVersions;
  for I := 0 to FSL.Count - 1 do
  begin
    FPCVersion := Trim(FSL.Strings[I]);
    if FPCVersion <> 'Trunk' then
      Result := FPCVersion = CurFPCVersion
    else
      Result := CurFPCVersion >= FPCTrunk;
    if Result then
      Exit;
  end;
end;

function TPackageListFrm.IsWidgetSetCompatible(const AWidgetSets: String): Boolean;
var
  WidgetSet: String;
  I: Integer;
begin
  FSL.Clear;
  FSL.DelimitedText := AWidgetSets;
  for I := 0 to FSL.Count - 1 do
  begin
    WidgetSet := Trim(FSL.Strings[I]);
    Result := WidgetSet = CurWidgetSet;
    if Result then
      Exit;
  end;
end;

end.


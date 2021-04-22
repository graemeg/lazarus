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
 Abstract:
   Implementation of the visual tree, which displays the package sructure
   downloaded from the remote repository.
}
unit opkman_visualtree;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, contnrs, Math, dateutils, laz.VirtualTrees,
  // LCL
  Controls, Graphics, Menus, Dialogs, Forms, LCLType, Buttons,
  // LazUtils
  LazStringUtils,
  // IDEIntf
  LCLIntf, PackageIntf,
  // OpkMan
  opkman_common, opkman_serializablepackages, opkman_const,
  opkman_options, opkman_packagedetailsfrm, opkman_showhint;


type
  PData = ^TData;
  TData = record
    DataType: Integer;
    PID: Integer;
    PFID: Integer;
    Repository: String;
    PackageState: TPackageState;
    PackageName: String;
    PackageDisplayName: String;
    Category: String;
    LazarusPackageName: String;
    Version: String;
    InstalledVersion: String;
    UpdateVersion: String;
    Description: String;
    Author: String;
    LazCompatibility: String;
    FPCCompatibility: String;
    SupportedWidgetSet: String;
    PackageType: TLazPackageType;
    Dependencies: String;
    License: String;
    RepositoryFileName: String;
    RepositoryFileSize: Int64;
    RepositoryFileHash: String;
    RepositoryDate: TDateTime;
    HomePageURL: String;
    DownloadURL: String;
    DownloadZipURL: String;
    HasUpdate: Boolean;
    DisableInOPM: Boolean;
    IsUpdated: Boolean;
    SVNURL: String;
    CommunityDescription: String;
    ExternalDependencies: String;
    OrphanedPackage: Integer;
    InstallState: Integer;
    ButtonID: Integer;
    Button: TSpeedButton;
    Rating: Integer;
    IsDependencyNode: Boolean;
  end;

  TFilterBy = (fbPackageName, fbLazarusPackageName, fbPackageCategory, fbPackageState,
               fbVersion, fbDescription, fbAuthor, fbLazCompatibility, fbFPCCompatibility,
               fbSupportedWidgetsets, fbPackageType, fbDependecies, fbLicense);

  { TVisualTree }
  TOnChecking = procedure(Sender: TObject; const AIsAllChecked: Boolean) of object;
  TVisualTree = class
  private
    FVST: TLazVirtualStringTree;
    FHoverNode: PVirtualNode;
    FHoverNodeOld: PVirtualNode;
    FHoverP: TPoint;
    FHoverColumn: Integer;
    FLink: String;
    FLinkClicked: Boolean;
    FSortCol: Integer;
    FSortDir: laz.VirtualTrees.TSortDirection;
    FCheckingNodes: Boolean;
    FLeaving: Boolean;
    FOnChecking: TOnChecking;
    FOnChecked: TNotifyEvent;
    FMouseEnter: Boolean;
    FShowHintFrm: TShowHintFrm;
    FOldButtonNode: PVirtualNode;
    FStarSize: Integer;
    procedure DoOpenPackage(const APackageName: String);
    procedure VSTBeforeCellPaint(Sender: TBaseVirtualTree;
      TargetCanvas: TCanvas; Node: PVirtualNode; {%H-}Column: TColumnIndex;
      {%H-}CellPaintMode: TVTCellPaintMode; CellRect: TRect; var {%H-}ContentRect: TRect);
    procedure VSTChecking(Sender: TBaseVirtualTree; {%H-}Node: PVirtualNode;
      var NewState: TCheckState; var {%H-}Allowed: Boolean);
    procedure VSTChecked(Sender: TBaseVirtualTree; {%H-}Node: PVirtualNode);
    procedure VSTCompareNodes(Sender: TBaseVirtualTree; Node1,
      Node2: PVirtualNode; Column: TColumnIndex; var Result: Integer);
    procedure VSTGetImageIndex(Sender: TBaseVirtualTree; Node: PVirtualNode;
      {%H-}Kind: TVTImageKind; Column: TColumnIndex; var {%H-}Ghosted: Boolean;
      var ImageIndex: Integer);
    procedure VSTGetText(Sender: TBaseVirtualTree; Node: PVirtualNode;
      Column: TColumnIndex; {%H-}TextType: TVSTTextType; var CellText: String);
    procedure VSTHeaderClick(Sender: TVTHeader; HitInfo: TVTHeaderHitInfo);
    procedure VSTPaintText(Sender: TBaseVirtualTree;
      const TargetCanvas: TCanvas; Node: PVirtualNode; {%H-}Column: TColumnIndex;
      {%H-}TextType: TVSTTextType);
    procedure VSTFreeNode(Sender: TBaseVirtualTree; Node: PVirtualNode);
    procedure VSTMouseMove(Sender: TObject; {%H-}Shift: TShiftState; X, Y: Integer);
    procedure VSTMouseEnter(Sender: TObject);
    procedure VSTMouseLeave(Sender: TObject);
    procedure VSTMouseDown(Sender: TObject; Button: TMouseButton; {%H-}Shift: TShiftState; X, Y: Integer);
    procedure VSTKeyDown(Sender: TObject; var {%H-}Key: Word; {%H-}Shift: TShiftState);
    procedure VSTKeyUp(Sender: TObject; var Key: Word; {%H-}Shift: TShiftState);
    procedure VSTGetHint(Sender: TBaseVirtualTree; Node: PVirtualNode; Column: TColumnIndex;
      var LineBreakStyle: TVTTooltipLineBreakStyle; var HintText: String);
    procedure VSTAfterCellPaint(Sender: TBaseVirtualTree;  {%H-}TargetCanvas: TCanvas;
      Node: PVirtualNode; Column: TColumnIndex; const {%H-}CellRect: TRect);
    procedure VSTDblClick(Sender: TObject);
    procedure VSTScroll(Sender: TBaseVirtualTree; {%H-}DeltaX, {%H-}DeltaY: Integer);
    procedure VSTIncrementalSearch(Sender: TBaseVirtualTree; Node: PVirtualNode; const SearchText: String; var Result: Integer);
    procedure VSTClick(Sender: TObject);
    procedure VSTAfterPaint(Sender: TBaseVirtualTree; {%H-}TargetCanvas: TCanvas);
    procedure VSTEnter(Sender: TObject);
    function IsAllChecked(const AChecking: PVirtualNode): Boolean;
    procedure ButtonClick(Sender: TObject);
    procedure DrawStars(ACanvas: TCanvas; AStartIndex: Integer; P: TPoint; AAvarage: Double);
    function GetColumn(const AX: Integer): Integer;
    function TranslateCategories(const AStr: String): String;
    procedure SetButtonVisibility(Node: PVirtualNode; Column: TColumnIndex);
    procedure CallBack(Sender: TBaseVirtualTree; Node: PVirtualNode; {%H-}Data: Pointer; var {%H-}Abort: Boolean);
    procedure ShowDetails(const AButtonID: Integer);
    procedure OpenPackage(const AButtonID: Integer);
    procedure ResetDependencyNodes;
    function GetPackageAbsolutePath(APackageName: String): String;
  public
    constructor Create(const AParent: TWinControl; const AImgList: TImageList;
      APopupMenu: TPopupMenu);
    destructor Destroy; override;
  public
    procedure PopulateTree;
    procedure CheckNodes(const Checked: Boolean);
    procedure FilterTree(const AFilterBy: TFilterBy; const AText: String; const AExtraParam: Integer = -1);
    procedure ResetFilter;
    procedure ExpandEx;
    procedure CollapseEx;
    procedure GetPackageList;
    procedure UpdatePackageStates;
    procedure UpdatePackageUStatus;
    function ResolveDependencies: TModalResult;
    function GetCheckedRepositoryPackages: Integer;
    procedure SetupColors;
    procedure AutoAdjustLayout(AXProportion, AYProportion: Double);
  published
    property OnChecking: TOnChecking read FOnChecking write FOnChecking;
    property OnChecked: TNotifyEvent read FOnChecked write FOnChecked;
    property VST: TLazVirtualStringTree read FVST;
    property ShowHintFrm: TShowHintFrm read FShowHintFrm;
  end;

var
  VisualTree: TVisualTree = nil;

implementation

uses
  imgList;

{ TVisualTree }

constructor TVisualTree.Create(const AParent: TWinControl; const AImgList: TImageList;
  APopupMenu: TPopupMenu);
begin
  FVST := TLazVirtualStringTree.Create(nil);
  with FVST do
   begin
     Parent := AParent;
     Align := alClient;
     Anchors := [akLeft, akTop, akRight];
     Images := AImgList;
     PopupMenu := APopupMenu;
     DefaultNodeHeight := 25;
     Indent := 22;
     TabOrder := 1;
     DefaultText := '';
     Header.AutoSizeIndex := 4;
     Header.Height := 25;
     Colors.DisabledColor := clBlack;
     with Header.Columns.Add do
     begin
       Position := 0;
       Width := 270;
       Text := rsMainFrm_VSTHeaderColumn_PackageName;
     end;
     with Header.Columns.Add do
     begin
       Position := 1;
       Alignment := taCenter;
       Width := 90;
       {$IFDEF LCLCarbon}
       Options := Options - [coResizable];
       {$ENDIF}
       Text := rsMainFrm_VSTHeaderColumn_Installed;
     end;
     with Header.Columns.Add do
     begin
       Position := 2;
       Alignment := taCenter;
       Width := 110;
       {$IFDEF LCLCarbon}
       Options := Options - [coResizable];
       {$ENDIF}
       Text := rsMainFrm_VSTHeaderColumn_Repository;
       Hint := rsMainFrm_VSTHeaderColumn_Repository_Hint;
     end;
     with Header.Columns.Add do
     begin
       Position := 3;
       Alignment := taCenter;
       Width := 110;
       {$IFDEF LCLCarbon}
       Options := Options - [coResizable];
       {$ENDIF}
       Text := rsMainFrm_VSTHeaderColumn_Update;
       Hint := rsMainFrm_VSTHeaderColumn_Update_Hint;
     end;
     with Header.Columns.Add do
     begin
       Position := 4;
       Width := 280;
       {$IFDEF LCLCarbon}
       Options := Options - [coResizable];
       {$ENDIF}
       Text := rsMainFrm_VSTHeaderColumn_Data;
      end;
     with Header.Columns.Add do
     begin
       Position := 5;
       Alignment := taCenter;
       Width := 80;
       Options := Options - [coResizable];
       Text := rsMainFrm_VSTHeaderColumn_Rating;
     end;
     with Header.Columns.Add do
     begin
       Position := 6;
       Alignment := taCenter;
       Width := 20;
       Options := Options - [coResizable];
     end;
     Header.Options := [hoAutoResize, hoColumnResize, hoRestrictDrag, hoShowSortGlyphs, hoVisible, hoShowHint];
     {$IFDEF LCLCarbon}
     Header.Options := Header.Options - [hoShowSortGlyphs];
     {$ENDIF}
     Header.SortColumn := 0;
     HintMode := hmHint;
     ShowHint := True;
     TabOrder := 2;
     IncrementalSearch := isVisibleOnly;
     IncrementalSearchDirection := sdForward;
     IncrementalSearchStart := ssFocusedNode;
     IncrementalSearchTimeout := 3000;
     TreeOptions.MiscOptions := [toCheckSupport, toFullRepaintOnResize, toInitOnSave, toWheelPanning];
     TreeOptions.PaintOptions := [toHideFocusRect, toAlwaysHideSelection, toPopupMode, toShowButtons, toShowDropmark, toShowRoot, toThemeAware];
     TreeOptions.SelectionOptions := [toFullRowSelect, toRightClickSelect];
     TreeOptions.StringOptions := [toShowStaticText];
     TreeOptions.AutoOptions := [toAutoTristateTracking];
     OnBeforeCellPaint := @VSTBeforeCellPaint;
     OnChecking := @VSTChecking;
     OnChecked := @VSTChecked;
     OnCompareNodes := @VSTCompareNodes;
     OnGetText := @VSTGetText;
     OnPaintText := @VSTPaintText;
     OnGetImageIndex := @VSTGetImageIndex;
     OnHeaderClick := @VSTHeaderClick;
     OnMouseMove := @VSTMouseMove;
     OnMouseLeave := @VSTMouseLeave;
     OnMouseEnter := @VSTMouseEnter;
     OnMouseDown := @VSTMouseDown;
     OnKeyDown := @VSTKeyDown;
     OnKeyUp := @VSTKeyUp;
     OnDblClick := @VSTDblClick;
     OnClick := @VSTClick;
     OnGetHint := @VSTGetHint;
     OnAfterCellPaint := @VSTAfterCellPaint;
     OnAfterPaint := @VSTAfterPaint;
     OnEnter := @VSTEnter;
     OnFreeNode := @VSTFreeNode;
     OnScroll := @VSTScroll;
     OnIncrementalSearch := @VSTIncrementalSearch;
   end;
  FShowHintFrm := TShowHintFrm.Create(nil);
  if AImgList <> nil then
    FStarSize := AImgList.Width
  else
    FStarSize := 0;
end;

destructor TVisualTree.Destroy;
begin
  FVST.Free;
  FShowHintFrm.Free;
  inherited Destroy;
end;

procedure TVisualTree.PopulateTree;
var
  I, J: Integer;
  RootNode, Node, ChildNode, GrandChildNode: PVirtualNode;
  RootData, Data, ChildData, GrandChildData: PData;
  LazarusPkg: TLazarusPackage;
  UniqueID: Integer;
begin
  FHoverNode := nil;
  FHoverNodeOld := nil;
  FOldButtonNode := nil;
  FVST.Clear;
  FVST.NodeDataSize := SizeOf(TData);
  UniqueID := 0;
  //add repository(DataType = 0)
  FVST.BeginUpdate;
  try
    RootNode := FVST.AddChild(nil);
    RootData := FVST.GetNodeData(RootNode);
    RootData^.Repository := Options.RemoteRepository[Options.ActiveRepositoryIndex];
    RootData^.DataType := 0;
    for I := 0 to SerializablePackages.Count - 1 do
    begin
       //add package(DataType = 1)
       Node := FVST.AddChild(RootNode);
       Node^.CheckType := ctTriStateCheckBox;
       Data := FVST.GetNodeData(Node);
       Data^.PID := I;
       Data^.PackageName := SerializablePackages.Items[I].Name;
       Data^.PackageDisplayName := SerializablePackages.Items[I].DisplayName;
       Data^.PackageState := SerializablePackages.Items[I].PackageState;
       Data^.InstallState := SerializablePackages.GetPackageInstallState(SerializablePackages.Items[I]);
       Data^.HasUpdate := SerializablePackages.Items[I].HasUpdate;
       Data^.DisableInOPM := SerializablePackages.Items[I].DisableInOPM;
       Data^.Rating := SerializablePackages.Items[I].Rating;
       Data^.RepositoryDate := SerializablePackages.Items[I].RepositoryDate;
       FVST.IsDisabled[Node] := Data^.DisableInOPM;
       Data^.DataType := 1;
       for J := 0 to SerializablePackages.Items[I].LazarusPackages.Count - 1 do
       begin
         //add LazarusPackages(DataType = 2)
         LazarusPkg := TLazarusPackage(SerializablePackages.Items[I].LazarusPackages.Items[J]);
         ChildNode := FVST.AddChild(Node);
         ChildNode^.CheckType := ctTriStateCheckBox;
         FVST.IsDisabled[ChildNode] := FVST.IsDisabled[ChildNode^.Parent];
         ChildData := FVST.GetNodeData(ChildNode);
         ChildData^.PID := I;
         ChildData^.PFID := J;
         ChildData^.LazarusPackageName := LazarusPkg.Name;
         ChildData^.InstalledVersion := LazarusPkg.InstalledFileVersion;
         ChildData^.UpdateVersion := LazarusPkg.UpdateVersion;
         ChildData^.Version := LazarusPkg.VersionAsString;
         ChildData^.PackageState := LazarusPkg.PackageState;
         ChildData^.HasUpdate := LazarusPkg.HasUpdate;
         ChildData^.DataType := 2;
         Inc(UniqueID);
         ChildData^.ButtonID := -UniqueID;
         //add description(DataType = 3)
         GrandChildNode := FVST.AddChild(ChildNode);
         FVST.IsDisabled[GrandChildNode] := FVST.IsDisabled[GrandChildNode^.Parent];
         GrandChildData := FVST.GetNodeData(GrandChildNode);
         if ChildData^.InstalledVersion <> '' then
           GrandChildData^.Description := LazarusPkg.InstalledFileDescription
         else
           GrandChildData^.Description := LazarusPkg.Description;
         GrandChildData^.DataType := 3;
         Inc(UniqueID);
         GrandChildData^.ButtonID := UniqueID;
         //add author(DataType = 4)
         GrandChildNode := FVST.AddChild(ChildNode);
         FVST.IsDisabled[GrandChildNode] := FVST.IsDisabled[GrandChildNode^.Parent];
         GrandChildData := FVST.GetNodeData(GrandChildNode);
         GrandChildData^.Author := LazarusPkg.Author;
         GrandChildData^.DataType := 4;
         //add lazcompatibility(DataType = 5)
         GrandChildNode := FVST.AddChild(ChildNode);
         FVST.IsDisabled[GrandChildNode] := FVST.IsDisabled[GrandChildNode^.Parent];
         GrandChildData := FVST.GetNodeData(GrandChildNode);
         GrandChildData^.LazCompatibility := LazarusPkg.LazCompatibility;
         GrandChildData^.DataType := 5;
         //add fpccompatibility(DataType = 6)
         GrandChildNode := FVST.AddChild(ChildNode);
         FVST.IsDisabled[GrandChildNode] := FVST.IsDisabled[GrandChildNode^.Parent];
         GrandChildData := FVST.GetNodeData(GrandChildNode);
         GrandChildData^.FPCCompatibility := LazarusPkg.FPCCompatibility;
         GrandChildData^.DataType := 6;
         //add widgetset(DataType = 7)
         GrandChildNode := FVST.AddChild(ChildNode);
         FVST.IsDisabled[GrandChildNode] := FVST.IsDisabled[GrandChildNode^.Parent];
         GrandChildData := FVST.GetNodeData(GrandChildNode);
         GrandChildData^.SupportedWidgetSet := LazarusPkg.SupportedWidgetSet;
         GrandChildData^.DataType := 7;
         //add packagetype(DataType = 8)
         GrandChildNode := FVST.AddChild(ChildNode);
         FVST.IsDisabled[GrandChildNode] := FVST.IsDisabled[GrandChildNode^.Parent];
         GrandChildData := FVST.GetNodeData(GrandChildNode);
         GrandChildData^.PackageType := LazarusPkg.PackageType;
         GrandChildData^.DataType := 8;
         //add license(DataType = 9)
         GrandChildNode := FVST.AddChild(ChildNode);
         FVST.IsDisabled[GrandChildNode] := FVST.IsDisabled[GrandChildNode^.Parent];
         GrandChildData := FVST.GetNodeData(GrandChildNode);
         if ChildData^.InstalledVersion <> '' then
           GrandChildData^.License := LazarusPkg.InstalledFileLincese
         else
           GrandChildData^.License := LazarusPkg.License;
         GrandChildData^.DataType := 9;
         Inc(UniqueID);
         GrandChildData^.ButtonID := UniqueID;
         //add dependencies(DataType = 10)
         GrandChildNode := FVST.AddChild(ChildNode);
         FVST.IsDisabled[GrandChildNode] := FVST.IsDisabled[GrandChildNode^.Parent];
         GrandChildData := FVST.GetNodeData(GrandChildNode);
         GrandChildData^.Dependencies := LazarusPkg.DependenciesAsString;
         GrandChildData^.DataType := 10;
       end;
       //add miscellaneous(DataType = 11)
       ChildNode := FVST.AddChild(Node);
       FVST.IsDisabled[ChildNode] := FVST.IsDisabled[ChildNode^.Parent];
       ChildData := FVST.GetNodeData(ChildNode);
       ChildData^.DataType := 11;
       //add category(DataType = 12)
       GrandChildNode := FVST.AddChild(ChildNode);
       FVST.IsDisabled[GrandChildNode] := FVST.IsDisabled[GrandChildNode^.Parent];
       GrandChildData := FVST.GetNodeData(GrandChildNode);
       GrandChildData^.Category := SerializablePackages.Items[I].Category;
       GrandChildData^.DataType := 12;
       //add Repository Filename(DataType = 13)
       GrandChildNode := FVST.AddChild(ChildNode);
       FVST.IsDisabled[GrandChildNode] := FVST.IsDisabled[GrandChildNode^.Parent];
       GrandChildData := FVST.GetNodeData(GrandChildNode);
       GrandChildData^.RepositoryFileName := SerializablePackages.Items[I].RepositoryFileName;
       GrandChildData^.DataType := 13;
       //add Repository Filesize(DataType = 14)
       GrandChildNode := FVST.AddChild(ChildNode);
       FVST.IsDisabled[GrandChildNode] := FVST.IsDisabled[GrandChildNode^.Parent];
       GrandChildData := FVST.GetNodeData(GrandChildNode);
       GrandChildData^.RepositoryFileSize := SerializablePackages.Items[I].RepositoryFileSize;
       GrandChildData^.DataType := 14;
       //add Repository Hash(DataType = 15)
       GrandChildNode := FVST.AddChild(ChildNode);
       FVST.IsDisabled[GrandChildNode] := FVST.IsDisabled[GrandChildNode^.Parent];
       GrandChildData := FVST.GetNodeData(GrandChildNode);
       GrandChildData^.RepositoryFileHash := SerializablePackages.Items[I].RepositoryFileHash;
       GrandChildData^.DataType := 15;
       //add Repository Date(DataType = 16)
       GrandChildNode := FVST.AddChild(ChildNode);
       FVST.IsDisabled[GrandChildNode] := FVST.IsDisabled[GrandChildNode^.Parent];
       GrandChildData := FVST.GetNodeData(GrandChildNode);
       GrandChildData^.RepositoryDate := SerializablePackages.Items[I].RepositoryDate;
       GrandChildData^.DataType := 16;
       FVST.Expanded[ChildNode] := True;
       //add HomePageURL(DataType = 17)
       GrandChildNode := FVST.AddChild(ChildNode);
       FVST.IsDisabled[GrandChildNode] := FVST.IsDisabled[GrandChildNode^.Parent];
       GrandChildData := FVST.GetNodeData(GrandChildNode);
       GrandChildData^.HomePageURL := SerializablePackages.Items[I].HomePageURL;
       GrandChildData^.DataType := 17;
       //add DownloadURL(DataType = 18)
       GrandChildNode := FVST.AddChild(ChildNode);
       FVST.IsDisabled[GrandChildNode] := FVST.IsDisabled[GrandChildNode^.Parent];
       GrandChildData := FVST.GetNodeData(GrandChildNode);
       GrandChildData^.DownloadURL := SerializablePackages.Items[I].DownloadURL;
       GrandChildData^.DataType := 18;
       //add community description(DataType = 19) - added 2018.08.21
       GrandChildNode := FVST.AddChild(ChildNode);
       FVST.IsDisabled[GrandChildNode] := FVST.IsDisabled[GrandChildNode^.Parent];
       GrandChildData := FVST.GetNodeData(GrandChildNode);
       GrandChildData^.CommunityDescription := SerializablePackages.Items[I].CommunityDescription;
       GrandChildData^.DataType := 19;
       Inc(UniqueID);
       GrandChildData^.ButtonID := UniqueID;
       Data^.CommunityDescription := SerializablePackages.Items[I].CommunityDescription;
       //add external dependecies(DataType = 20) - added 2020.04.14
       GrandChildNode := FVST.AddChild(ChildNode);
       FVST.IsDisabled[GrandChildNode] := FVST.IsDisabled[GrandChildNode^.Parent];
       GrandChildData := FVST.GetNodeData(GrandChildNode);
       GrandChildData^.ExternalDependencies := SerializablePackages.Items[I].ExternalDependecies;
       GrandChildData^.DataType := 20;
       Inc(UniqueID);
       GrandChildData^.ButtonID := UniqueID;
       Data^.ExternalDependencies := SerializablePackages.Items[I].ExternalDependecies;
       //add orphaned package(DataType = 21) - added 2020.07.23
       GrandChildNode := FVST.AddChild(ChildNode);
       FVST.IsDisabled[GrandChildNode] := FVST.IsDisabled[GrandChildNode^.Parent];
       GrandChildData := FVST.GetNodeData(GrandChildNode);
       GrandChildData^.OrphanedPackage := SerializablePackages.Items[I].OrphanedPackage;
       GrandChildData^.DataType := 21;
       Data^.OrphanedPackage := SerializablePackages.Items[I].OrphanedPackage;
       FVST.IsVisible[GrandChildNode] := False;
    end;
    FVST.SortTree(0, laz.VirtualTrees.sdAscending);
    ExpandEx;
    CollapseEx;
  finally
    FVST.EndUpdate;
  end;
  RootNode := VST.GetFirst;
  if RootNode <> nil then
  begin
    FVST.Selected[RootNode] := True;
    FVST.FocusedNode := RootNode;
  end;
end;

function TVisualTree.IsAllChecked(const AChecking: PVirtualNode): Boolean;
var
  Node: PVirtualNode;
begin
  Result := True;
  Node := FVST.GetFirst;
  while Assigned(Node) do
  begin
    if (FVST.CheckState[Node] = csUncheckedNormal) and (Node <> AChecking) then
    begin
      Result := False;
      Break;
    end;
    Node := FVST.GetNext(Node);
  end;
end;

procedure TVisualTree.ShowDetails(const AButtonID: Integer);
var
  Node, ParentNode, MetaPackageNode: PVirtualNode;
  Data, ParentData, MetaPackageData: PData;
  Text: String;
  FrmCaption: String;
begin
  if Assigned(PackageDetailsFrm) then
    Exit;

  Node := VST.GetFirst;
  while Assigned(Node) do
  begin
    Data := VST.GetNodeData(Node);
    if Data^.ButtonID = AButtonID then
    begin
      ParentNode := Node^.Parent;
      ParentData := VST.GetNodeData(ParentNode);
      case Data^.DataType of
        3: begin
             Text := Data^.Description;
             FrmCaption := rsMainFrm_VSTText_Desc + ' "' + ParentData^.LazarusPackageName  + '"';
           end;
        9: begin
             Text := Data^.License;
             FrmCaption := rsMainFrm_VSTText_Lic  + ' "' + ParentData^.LazarusPackageName  + '"';
           end;
       19: begin
             MetaPackageNode := ParentNode^.Parent;
             if MetaPackageNode <> nil then
             begin
               MetaPackageData := VST.GetNodeData(MetaPackageNode);
               Text := Data^.CommunityDescription;
               FrmCaption := rsMainFrm_VSTText_ComDesc  + ' "' + MetaPackageData^.PackageDisplayName + '"';
             end;
           end;
       20: begin
             MetaPackageNode := ParentNode^.Parent;
             if MetaPackageNode <> nil then
             begin
               MetaPackageData := VST.GetNodeData(MetaPackageNode);
               Text := Data^.ExternalDependencies;
               FrmCaption := rsMainFrm_VSTText_ExternalMetaPackageDeps  + ' "' + MetaPackageData^.PackageDisplayName + '"';
             end;
           end;
      end;
      Break;
    end;
    Node := VST.GetNext(Node);
  end;

  PackageDetailsFrm := TPackageDetailsFrm.Create(TForm(FVST.Parent.Parent));
  try
    PackageDetailsFrm.Caption := FrmCaption;
    PackageDetailsFrm.mDetails.Text := Text;
    PackageDetailsFrm.ShowModal;
  finally
    FreeAndNil(PackageDetailsFrm);
  end;
end;

procedure TVisualTree.DoOpenPackage(const APackageName: String);
var
  PackageAbsolutePath: String;
begin
  PackageAbsolutePath  := GetPackageAbsolutePath(APackageName);
  if PackageEditingInterface.DoOpenPackageFile(PackageAbsolutePath, [], True) <> mrOk then
      MessageDlgEx(rsMainFrm_VSTText_Open_Error, mtError, [mbOk], TForm(FVST.Parent.Parent));
end;

procedure TVisualTree.OpenPackage(const AButtonID: Integer);
var
  Node: PVirtualNode;
  Data: PData;
begin
  Node := VST.GetFirst;
  while Assigned(Node) do
  begin
    Data := VST.GetNodeData(Node);
    if Data^.ButtonID = AButtonID then
    begin
      DoOpenPackage(Data^.LazarusPackageName);
      Break;
    end;
    Node := VST.GetNext(Node);
  end;
end;

procedure TVisualTree.ButtonClick(Sender: TObject);
var
  Tag: Integer;
begin
  Tag := (Sender as TSpeedButton).Tag;
  if Tag < 0 then
    OpenPackage(Tag)
  else
    ShowDetails(Tag);
end;

function TVisualTree.TranslateCategories(const AStr: String): String;
var
  SL: TStringList;
  I, J: Integer;
  Str: String;
begin
  if Categories[0] = CategoriesEng[0] then
  begin
    Result := AStr;
    Exit;
  end;
  Result := '';
  SL := TStringList.Create;
  try
    SL.Delimiter := ',';
    SL.StrictDelimiter := True;
    SL.DelimitedText := AStr;
    for I := 0 to SL.Count - 1 do
    begin
      Str := Trim(SL.Strings[I]);
      for J := 0 to MaxCategories - 1 do
      begin
        if Str = CategoriesEng[J] then
        begin
          if Result = '' then
            Result := Categories[J]
          else
            Result := Result + ', ' + Categories[J];
          Break;
        end;
      end;
    end;
  finally
    SL.Free;
  end;
  if Result = '' then
    Result := AStr;
end;

procedure TVisualTree.SetButtonVisibility(Node: PVirtualNode;
  Column: TColumnIndex);
var
  Data: PData;
  R: TRect;
begin
  Data := FVST.GetNodeData(Node);
  if Assigned(Data^.Button) then
  begin
    R := FVST.GetDisplayRect(Node, Column, False);
    Data^.Button.Left   := R.Right - Data^.Button.Width - 1;
    Data^.Button.Top    := R.Top + 1;
    Data^.Button.Height := R.Bottom - R.Top - 1;
    Data^.Button.Visible := FVST.IsVisible[Node] and IntersectRect(R, FVST.GetDisplayRect(Node, Column, False), FVST.ClientRect);
    Data^.Button.Enabled := not FVST.IsDisabled[Node];
  end;
end;

procedure TVisualTree.CallBack(Sender: TBaseVirtualTree; Node: PVirtualNode;
  Data: Pointer; var Abort: Boolean);
begin
  SetButtonVisibility(Node, 4);
end;

procedure TVisualTree.VSTAfterPaint(Sender: TBaseVirtualTree;
  TargetCanvas: TCanvas);
begin
  Sender.IterateSubtree(nil, @CallBack, nil);
end;

procedure TVisualTree.VSTEnter(Sender: TObject);
var
  Node: PVirtualNode;
begin
  if FMouseEnter then
  begin
    FMouseEnter := False;
    Exit;
  end;
  if FVST.SelectedCount = 0 then
  begin
    Node := FVST.GetFirst;
    if Node <> nil then
    begin
      FVST.Selected[Node] := True;
      FVST.FocusedNode := Node;
    end;
  end;
end;

procedure TVisualTree.DrawStars(ACanvas: TCanvas; AStartIndex: Integer;
  P: TPoint; AAvarage: Double);
var
  imgres: TScaledImageListResolution;

  procedure Draw(const AX, AY: Integer; ATyp, ACnt, AWidth: Integer);
  var
    I: Integer;
  begin
    for I := 0 to ACnt - 1 do
      imgres.Draw(ACanvas, AX + I*AWidth, AY, AStartIndex + ATyp);
  end;

var
  F: Double;
  I, X, Y: Integer;
  Stars, NoStars: Integer;
  HalfStar: Boolean;
begin
  imgres := FVST.Images.ResolutionForPPI[FVST.ImagesWidth, FVST.Font.PixelsPerInch, FVST.GetCanvasScaleFactor];

  HalfStar := False;
  F := Frac(AAvarage);
  I := Trunc(AAvarage);
  case CompareValue(F, 0.25, 0.005) of
      -1:
        begin
            Stars := I;
            NoStars := 5 - Stars;
        end;
    0, 1:
        begin
          if CompareValue(F, 0.75, 0.005) = -1 then
          begin
            Stars := I;
            NoStars := 5 - Stars - 1;
            HalfStar := True;
          end
          else
          begin
            Stars := I + 1;
            NoStars := 5 - Stars;
          end;
        end;
  end;
  X := P.X;
  Y := P.Y;
  Draw(X, Y, 0, Stars, FStarSize);
  Inc(X, Stars*FStarSize);
  if HalfStar then
  begin
    Draw(X, Y, 2, 1, FStarSize);
    Inc(X, FStarSize);
  end;
  Draw(X, Y, 1, NoStars, FStarSize);
end;

procedure TVisualTree.VSTAfterCellPaint(Sender: TBaseVirtualTree;
  TargetCanvas: TCanvas; Node: PVirtualNode; Column: TColumnIndex;
  const CellRect: TRect);
var
  Data: PData;
  R: TRect;
  P: TPoint;
  Stars: Integer;
begin
  if Column = 5 then
  begin
    Data := FVST.GetNodeData(Node);
    if Data^.DataType = 1 then
    begin
      R := FVST.GetDisplayRect(Node, Column, False);
      P.X := R.Left + 1;
      P.Y := ((R.Bottom - R.Top - FStarSize) div 2) + 1;
      if (Node = FHoverNode) and (not FLeaving) and (FHoverP.X >= P.X + 1) and (Abs(FHoverP.X - P.X) <= R.Right - R.Bottom) then
      begin
        Stars := Trunc((FHoverP.X - P.X)/FStarSize) + 1;
        if Stars > 5 then
          Stars := 5;
        DrawStars(TargetCanvas, 23, P, Stars)
      end
      else
        DrawStars(TargetCanvas, 20, P, Data^.Rating);
    end
  end;
end;

procedure TVisualTree.CheckNodes(const Checked: Boolean);
var
  Node: PVirtualNode;
begin
  FCheckingNodes := True;
  try
    Node := FVST.GetFirst;
    while Assigned(Node) do
    begin
      if Checked then
        FVST.CheckState[Node] := csCheckedNormal
      else
        FVST.CheckState[Node] := csUncheckedNormal;
      Node := FVST.GetNext(Node);
    end;
  finally
    FCheckingNodes := False;
  end;
end;

procedure TVisualTree.FilterTree(const AFilterBy: TFilterBy; const AText:
  String; const AExtraParam: Integer = -1);

  function IsAtLeastOneChildVisible(const ANode: PVirtualNode): Boolean;
  var
    Level: Integer;
    Node: PVirtualNode;
    Data: PData;
  begin
    Result := False;
    Level := FVST.GetNodeLevel(ANode);
    Node := FVST.GetFirstChild(ANode);
    while Assigned(Node) do
    begin
      Data := FVST.GetNodeData(Node);
      case Level of
        0: if (vsVisible in Node^.States) then
           begin
             Result := True;
             Break;
           end;
        1: if (vsVisible in Node^.States) and (Data^.DataType = 2) then
           begin
             Result := True;
             Break;
           end;
      end;
      Node := FVST.GetNextSibling(Node);
    end;
  end;

  procedure HideShowParentNodes(const ANode: PVirtualNode; AShow: Boolean);
  var
    Level: Integer;
    RepositoryNode, PackageNode, LazarusPkgNode: PVirtualNode;
  begin
    RepositoryNode := nil;
    PackageNode := nil;
    LazarusPkgNode := nil;
    Level := FVST.GetNodeLevel(ANode);
    case Level of
      1: begin
           RepositoryNode := ANode^.Parent;
           PackageNode := ANode;
         end;
      2: begin
           RepositoryNode := ANode^.Parent^.Parent;
           PackageNode := ANode^.Parent;
           LazarusPkgNode := ANode;
         end;
      3: begin
           RepositoryNode := ANode^.Parent^.Parent^.Parent;
           PackageNode := ANode^.Parent^.Parent;
           LazarusPkgNode := ANode^.Parent;
         end;
    end;
    if Level = 1 then
    begin
      if AShow then
        FVST.IsVisible[RepositoryNode] := True
      else
        if not IsAtLeastOneChildVisible(RepositoryNode) then
          FVST.IsVisible[RepositoryNode] := False;
    end
    else if Level = 2 then
    begin
      if AShow then
      begin
        FVST.IsVisible[PackageNode] := True;
        FVST.IsVisible[RepositoryNode] := True;
      end
      else
      begin
        if not IsAtLeastOneChildVisible(PackageNode) then
        begin
          FVST.IsVisible[PackageNode] := False;
          HideShowParentNodes(PackageNode, AShow);
        end;
      end;
    end
    else if Level = 3 then
    begin
      if AShow then
      begin
        FVST.IsVisible[LazarusPkgNode] := True;
        FVST.IsVisible[PackageNode] := True;
        FVST.IsVisible[RepositoryNode] := True;
      end
      else
      begin
        FVST.IsVisible[LazarusPkgNode] := False;
        HideShowParentNodes(LazarusPkgNode, AShow);
      end;
    end;
  end;

  procedure FilterNode(Node: PVirtualNode; ADataText: String);
  var
    P: Integer;
  begin
    P := PosI(AText, ADataText);
    if P > 0 then
      FVST.IsVisible[Node] := True
    else
      FVST.IsVisible[Node] := False;
    if AText = 'PackageCategory' then //special case for categories
    begin
      if (P > 0) then
      begin
        FVST.IsVisible[Node^.Parent^.Parent] := True;
        FVST.IsVisible[Node^.Parent^.Parent^.Parent] := True;
      end
      else
      begin
        FVST.IsVisible[Node^.Parent^.Parent] := False;
        if not IsAtLeastOneChildVisible(Node^.Parent^.Parent^.Parent) then
          FVST.IsVisible[Node^.Parent^.Parent^.Parent] := False
      end;
    end
    else
      HideShowParentNodes(Node, P > 0)
  end;

var
  Node: PVirtualNode;
  Data: PData;
begin
  Node := FVST.GetFirst;
  while Assigned(Node) do
  begin
    Data := FVST.GetNodeData(Node);
    case AFilterBy of
      fbPackageName:
        begin
          if (Data^.DataType = 1) then
            FilterNode(Node, Data^.PackageDisplayName);
        end;
      fbLazarusPackageName:
        begin
          if (Data^.DataType = 2) then
            FilterNode(Node, Data^.LazarusPackageName);
        end;
      fbPackageCategory:
        begin
          if Data^.DataType = 12 then
          begin
            if PosI(CategoriesEng[AExtraParam], Data^.Category) > 0 then
              FilterNode(Node, 'PackageCategory')
            else
              FilterNode(Node, '')
          end;
        end;
     fbPackageState:
       begin
         if Data^.DataType = 2 then
         begin
           if Data^.PackageState = TPackageState(AExtraParam) then
             FilterNode(Node, 'PackageState')
           else
             FilterNode(Node, '');
         end;
       end;
     fbVersion:
       begin
         if Data^.DataType = 2 then
           FilterNode(Node, Data^.Version);
       end;
     fbDescription:
       begin
         if Data^.DataType = 3 then
           FilterNode(Node, Data^.Description);
       end;
     fbAuthor:
       begin
         if Data^.DataType = 4 then
           FilterNode(Node, Data^.Author);
       end;
     fbLazCompatibility:
       begin
         if Data^.DataType = 5 then
           FilterNode(Node, Data^.LazCompatibility);
       end;
     fbFPCCompatibility:
       begin
         if Data^.DataType = 6 then
           FilterNode(Node, Data^.FPCCompatibility);
       end;
     fbSupportedWidgetsets:
       begin
         if Data^.DataType = 7 then
           FilterNode(Node, Data^.SupportedWidgetSet);
       end;
     fbPackageType:
       begin
         if Data^.DataType = 8 then
         begin
           if Data^.PackageType = TLazPackageType(AExtraParam) then
             FilterNode(Node, 'PackageType')
           else
             FilterNode(Node, '');
         end;
       end;
     fbLicense:
       begin
          if Data^.DataType = 9 then
           FilterNode(Node, Data^.License);
       end;
     fbDependecies:
       begin
          if Data^.DataType = 10 then
           FilterNode(Node, Data^.Dependencies);
       end;
   end;
   Node := FVST.GetNext(Node);
  end;
  Node := FVST.GetFirst;
  if Node <> nil then
    FVST.TopNode := Node;
end;

procedure TVisualTree.ResetFilter;
var
  Node: PVirtualNode;
begin
  Node := FVST.GetFirst;
  while Assigned(Node) do
  begin
    FVST.IsVisible[Node] := True;
    Node := FVST.GetNext(Node);
  end;
  Node := FVST.GetFirst;
  CollapseEx;
  if Node <> nil then
    FVST.TopNode := Node;
end;

procedure TVisualTree.ExpandEx;
var
  Node: PVirtualNode;
  Data: PData;
begin
  Node := FVST.GetFirst;
  while Assigned(Node) do
  begin
    Data := FVST.GetNodeData(Node);
    if (Data^.DataType = 0) or (Data^.DataType = 1) or (Data^.DataType = 11) then
      VST.Expanded[Node] := True;
    Node := FVST.GetNext(Node);
  end;
  Node := FVST.GetFirst;
  if Node <> nil then
    FVST.TopNode := Node;
end;

procedure TVisualTree.CollapseEx;
var
  Node: PVirtualNode;
  Data: PData;
begin
  FVST.FullCollapse;
  Node := FVST.GetFirst(True);
  while Assigned(Node) do
  begin
    Data := FVST.GetNodeData(Node);
    if (Data^.DataType = 0) or (Data^.DataType = 11) then
      VST.Expanded[Node] := True;
    Node := FVST.GetNext(Node);
  end;
end;

procedure TVisualTree.GetPackageList;
var
  Node: PVirtualNode;
  Data: PData;
  MetaPkg: TMetaPackage;
  LazarusPkg: TLazarusPackage;
begin
  Node := FVST.GetFirst;
  while Assigned(Node) do
  begin
    Data := FVST.GetNodeData(Node);
    if Data^.DataType = 1 then
    begin
      MetaPkg := SerializablePackages.Items[Data^.PID];
      if MetaPkg <> nil then
      begin
        if (FVST.CheckState[Node] = csCheckedNormal) or (FVST.CheckState[Node] = csMixedNormal) then
        begin
          if (FVST.IsVisible[Node]) or (Data^.IsDependencyNode) then
          begin
            MetaPkg.Checked := True;
            if Data^.IsDependencyNode then
              MetaPkg.IsDependencyPackage := True;
          end
          else
            MetaPkg.Checked := False;
        end
        else if FVST.CheckState[Node] = csUncheckedNormal then
          MetaPkg.Checked := False
      end;
    end;
    if Data^.DataType = 2 then
    begin
      LazarusPkg := TLazarusPackage(SerializablePackages.Items[Data^.PID].LazarusPackages.Items[Data^.PFID]);
      if LazarusPkg <> nil then
      begin
        if FVST.CheckState[Node] = csCheckedNormal then
        begin
          if (FVST.IsVisible[Node]) or (Data^.IsDependencyNode) then
          begin
            LazarusPkg.Checked := True;
            if Data^.IsDependencyNode then
              LazarusPkg.IsDependencyPackage:= True
          end
          else
            LazarusPkg.Checked := False;
        end
        else if FVST.CheckState[Node] = csUncheckedNormal then
          LazarusPkg.Checked := False
      end;
    end;
    Node := FVST.GetNext(Node);
  end;
end;

procedure TVisualTree.UpdatePackageStates;
var
  Node: PVirtualNode;
  Data: PData;
  MetaPkg: TMetaPackage;
  LazarusPkg: TLazarusPackage;
begin
  SerializablePackages.GetPackageStates;
  Node := FVST.GetFirst;
  while Assigned(Node) do
  begin
    Data := FVST.GetNodeData(Node);
    if (Data^.DataType = 1) then
    begin
      MetaPkg := SerializablePackages.Items[Data^.PID];
      if MetaPkg <> nil then
      begin
        Data^.PackageState := MetaPkg.PackageState;
        Data^.InstallState := SerializablePackages.GetPackageInstallState(MetaPkg);
        FVST.ReinitNode(Node, False);
        FVST.RepaintNode(Node);
      end;
    end;
    if Data^.DataType = 2 then
    begin
      LazarusPkg := TLazarusPackage(SerializablePackages.Items[Data^.PID].LazarusPackages.Items[Data^.PFID]);
      if LazarusPkg <> nil then
      begin
        Data^.InstalledVersion := LazarusPkg.InstalledFileVersion;
        Data^.PackageState := LazarusPkg.PackageState;
        FVST.ReinitNode(Node, False);
        FVST.RepaintNode(Node);
      end;
    end;
    Node := FVST.GetNext(Node);
  end;
end;

procedure TVisualTree.UpdatePackageUStatus;
var
  Node: PVirtualNode;
  Data, ParentData: PData;
  MetaPkg: TMetaPackage;
  LazarusPkg: TLazarusPackage;
begin
  if VisualTree = nil then
    exit;

  Node := FVST.GetFirst;
  while Assigned(Node) do
  begin
    Data := FVST.GetNodeData(Node);
    if (Data^.DataType = 1) then
    begin
      MetaPkg := SerializablePackages.Items[Data^.PID];
      if MetaPkg <> nil then
      begin
        Data^.DownloadZipURL := MetaPkg.DownloadZipURL;
        Data^.HasUpdate := MetaPkg.HasUpdate;
        Data^.DisableInOPM := MetaPkg.DisableInOPM;
        Data^.Rating := MetaPkg.Rating;
        FVST.IsDisabled[Node] := Data^.DisableInOPM;
        FVST.ReinitNode(Node, False);
        FVST.RepaintNode(Node);
      end;
    end;
    if Data^.DataType = 2 then
    begin
      LazarusPkg := TLazarusPackage(SerializablePackages.Items[Data^.PID].LazarusPackages.Items[Data^.PFID]);
      if LazarusPkg <> nil then
      begin
        Data^.UpdateVersion := LazarusPkg.UpdateVersion;
        Data^.HasUpdate := LazarusPkg.HasUpdate;
        FVST.IsDisabled[Node] := FVST.IsDisabled[Node^.Parent];
        FVST.ReinitNode(Node, False);
        FVST.RepaintNode(Node);
      end;
    end;
    if Data^.DataType in [3..20] then
    begin
      FVST.IsDisabled[Node] := FVST.IsDisabled[Node^.Parent];
      ParentData := FVST.GetNodeData(Node^.Parent);
      if (Data^.DataType = 3) or (Data^.DataType = 9) then
      begin
        case Data^.DataType of
          3: if ParentData^.InstalledVersion <> '' then
               Data^.Description := LazarusPkg.InstalledFileDescription
             else
               Data^.Description := LazarusPkg.Description;
          9: if ParentData^.InstalledVersion <> '' then
               Data^.License := LazarusPkg.InstalledFileLincese
             else
               Data^.License := LazarusPkg.License;
        end;
        if Assigned(Data^.Button) then
          Data^.Button.Enabled := not FVST.IsDisabled[Node];
      end;
      FVST.ReinitNode(Node, False);
      FVST.RepaintNode(Node);
    end;
    Node := FVST.GetNext(Node);
  end;
end;

procedure TVisualTree.VSTBeforeCellPaint(Sender: TBaseVirtualTree;
  TargetCanvas: TCanvas; Node: PVirtualNode; Column: TColumnIndex;
  CellPaintMode: TVTCellPaintMode; CellRect: TRect; var ContentRect: TRect);
var
  Data: PData;
begin
  if Options.UseDefaultTheme then
    Exit;
  if CellPaintMode = cpmPaint then
  begin
    Data := Sender.GetNodeData(Node);

    if (Data^.DataType = 0) or (Data^.DataType = 1) or (Data^.DataType = 2) then
      TargetCanvas.Brush.Color := $00E5E5E5
    else
      TargetCanvas.Brush.Color := clBtnFace;
    TargetCanvas.FillRect(CellRect);
    if (Node = Sender.FocusedNode) then
    begin
      TargetCanvas.Brush.Color := FVST.Colors.FocusedSelectionColor;
      if Column = 0 then
        TargetCanvas.FillRect(ContentRect)
     else
       TargetCanvas.FillRect(CellRect);
    end
  end;
end;

procedure TVisualTree.VSTChecking(Sender: TBaseVirtualTree; Node: PVirtualNode;
  var NewState: TCheckState; var Allowed: Boolean);
begin
  if FCheckingNodes then
    Exit;
  if NewState = csUncheckedNormal then
  begin
    if Assigned(FOnChecking) then
      FOnChecking(Self, False);
  end
  else if NewState = csCheckedNormal then
  begin
    if IsAllChecked(Node) then
      FOnChecking(Self, True);
  end;
end;

procedure TVisualTree.VSTChecked(Sender: TBaseVirtualTree; Node: PVirtualNode);
begin
  if FCheckingNodes then
    Exit;
  if Assigned(FOnChecked) then
    FOnChecked(Self);
end;

procedure TVisualTree.ResetDependencyNodes;
var
  Node: PVirtualNode;
  Data: PData;
begin
  Node := FVST.GetFirst;
  while Assigned(Node) do
  begin
    Data := FVST.GetNodeData(Node);
    Data^.IsDependencyNode := False;
    Node := FVST.GetNext(Node);
  end;
end;

function TVisualTree.ResolveDependencies: TModalResult;
var
  Parent, Node, NodeSearch: PVirtualNode;
  ParentData, Data, DataSearch: PData;
  Msg: String;
  PackageList: TObjectList;
  PkgFileName: String;
  DependencyPkg: TLazarusPackage;
  I: Integer;
begin
  Result := mrNone;
  ResetDependencyNodes;
  Node := FVST.GetFirst;
  while Assigned(Node) do
  begin
    if VST.CheckState[Node] = csCheckedNormal then
    begin
      Data := FVST.GetNodeData(Node);
      if Data^.DataType = 2 then
      begin
        PackageList := TObjectList.Create(True);
        try
          SerializablePackages.GetPackageDependencies(Data^.LazarusPackageName, PackageList, True, True);
          for I := 0 to PackageList.Count - 1 do
          begin
            PkgFileName := TPackageDependency(PackageList.Items[I]).PkgFileName + '.lpk';
            NodeSearch := VST.GetFirst;
            while Assigned(NodeSearch) do
            begin
              if NodeSearch <> Node then
              begin
                DataSearch := FVST.GetNodeData(NodeSearch);
                if DataSearch^.DataType = 2 then
                begin
                  DependencyPkg := TLazarusPackage(SerializablePackages.Items[DataSearch^.PID].LazarusPackages.Items[DataSearch^.PFID]);
                  if (FVST.CheckState[NodeSearch] <> csCheckedNormal) and
                       (CompareText(DataSearch^.LazarusPackageName, PkgFileName) = 0) and
                         ((SerializablePackages.IsDependencyOk(TPackageDependency(PackageList.Items[I]), DependencyPkg)) and
                           ((not (DependencyPkg.PackageState = psInstalled)) or ((DependencyPkg.PackageState = psInstalled) and (not (SerializablePackages.IsInstalledVersionOk(TPackageDependency(PackageList.Items[I]), DataSearch^.InstalledVersion)))))) then
                  begin
                    if (Result = mrNone) or (Result = mrYes) then
                    begin
                      Msg := Format(rsMainFrm_rsPackageDependency0, [Data^.LazarusPackageName, DataSearch^.LazarusPackageName]);
                      Result := MessageDlgEx(Msg, mtConfirmation, [mbYes, mbYesToAll, mbNo, mbNoToAll, mbCancel], TForm(FVST.Parent.Parent));
                      if Result in [mrNo, mrNoToAll] then
                        if MessageDlgEx(rsMainFrm_rsPackageDependency1, mtInformation, [mbYes, mbNo], TForm(FVST.Parent.Parent)) <> mrYes then
                          Exit(mrCancel);
                      if (Result = mrNoToAll) or (Result = mrCancel) then
                        Exit(mrCancel);
                    end;
                    if Result in [mrYes, mrYesToAll] then
                    begin
                      FVST.CheckState[NodeSearch] := csCheckedNormal;
                      FVST.ReinitNode(NodeSearch, False);
                      FVST.RepaintNode(NodeSearch);
                      DataSearch^.IsDependencyNode := True;
                      Parent := NodeSearch^.Parent;
                      if Parent <> nil then
                      begin
                        ParentData := FVST.GetNodeData(Parent);
                        ParentData^.IsDependencyNode := True;
                      end;
                    end;
                  end;
                end;
              end;
              NodeSearch := FVST.GetNext(NodeSearch);
            end;
          end;
        finally
          PackageList.Free;
        end;
      end;
    end;
    Node := FVST.GetNext(Node);
  end;
end;

function TVisualTree.GetCheckedRepositoryPackages: Integer;
var
  Node: PVirtualNode;
  Data: PData;
begin
  Result := 0;
  Node := FVST.GetFirst;
  while Assigned(Node) do
  begin
    Data := FVST.GetNodeData(Node);
    if (Data^.DataType = 1) and ((FVST.CheckState[Node] = csCheckedNormal) or (FVST.CheckState[Node] = csMixedNormal)) then
      Inc(Result);
    if Result > 1 then
      Break;
    Node := FVST.GetNext(Node);
  end;
end;

procedure TVisualTree.SetupColors;
begin
  if not Options.UseDefaultTheme then
  begin
    FVST.Color := clBtnFace;
    FVST.TreeOptions.PaintOptions := FVST.TreeOptions.PaintOptions + [toAlwaysHideSelection];
  end else
  begin
    FVST.Color := clDefault;
    FVST.TreeOptions.PaintOptions := FVST.TreeOptions.PaintOptions - [toAlwaysHideSelection];
  end;
end;

procedure TVisualTree.AutoAdjustLayout(AXProportion, AYProportion: Double);
begin
  FStarSize := round(FStarSize * AXProportion);
end;

procedure TVisualTree.VSTCompareNodes(Sender: TBaseVirtualTree; Node1,
  Node2: PVirtualNode; Column: TColumnIndex; var Result: Integer);
var
  Data1: PData;
  Data2: PData;
begin
  Data1 := Sender.GetNodeData(Node1);
  Data2 := Sender.GetNodeData(Node2);
  case Column of
    0: begin
         if (Data1^.DataType = 1) and (Data1^.DataType = 1) then
         begin
           if (Trim(Data1^.PackageDisplayName) <> '') and (Trim(Data2^.PackageDisplayName) <> '') then
             Result := CompareText(Data1^.PackageDisplayName, Data2^.PackageDisplayName)
           else
             Result := CompareText(Data1^.PackageName, Data2^.PackageName);
         end;
         if (Data1^.DataType < Data2^.DataType) then
           Result := 0
         else if (Data1^.DataType > Data2^.DataType) then
           Result := 1
         else if (Data1^.DataType = 2) and (Data1^.DataType = 2) then
           Result := CompareText(Data1^.LazarusPackageName, Data2^.LazarusPackageName);
       end;
    1: if (Data1^.DataType = 1) and (Data1^.DataType = 1) then
         Result := Data2^.InstallState - Data1^.InstallState;
    3: if (Data1^.DataType = 1) and (Data1^.DataType = 1) then
         Result := Ord(Data2^.HasUpdate) - Ord(Data1^.HasUpdate);
  end;
end;

procedure TVisualTree.VSTGetImageIndex(Sender: TBaseVirtualTree;
  Node: PVirtualNode; Kind: TVTImageKind; Column: TColumnIndex;
  var Ghosted: Boolean; var ImageIndex: Integer);
var
  Data: PData;
begin
  Data := FVST.GetNodeData(Node);
  if Column = 0 then
  begin
    case Data^.DataType of
      1: if ((Options.DaysToShowNewPackages > 0) and (DaysBetween(Now, Data^.RepositoryDate) <= Options.DaysToShowNewPackages)) and
            ((not Options.ShowRegularIcons) or ((Options.ShowRegularIcons) and (Data^.InstallState = 0))) then
           ImageIndex := 25
         else
         begin
           if Data^.OrphanedPackage = 0 then
             ImageIndex := 1
           else
             ImageIndex := 36;
         end;
     20: ImageIndex := 10;
     21: ImageIndex := 36;
     else
        ImageIndex := Data^.DataType
    end;
  end;
end;

function GetDisplayString(const AStr: String): String;
var
  SL: TStringList;
  I: Integer;
begin
  Result := '';
  SL := TStringList.Create;
  try
    SL.Text := AStr;
    for I := 0 to SL.Count - 1 do
      if Result = '' then
        Result := SL.Strings[I]
      else
        Result := Result + ' ' + SL.Strings[I];
  finally
    SL.Free;
  end;
end;

procedure TVisualTree.VSTGetText(Sender: TBaseVirtualTree; Node: PVirtualNode;
  Column: TColumnIndex; TextType: TVSTTextType; var CellText: String);
var
  Data: PData;
begin
  Data := FVST.GetNodeData(Node);
  if TextType = ttStatic then
  begin
    if Column = 0 then
    begin
      if ((Options.DaysToShowNewPackages > 0) and (DaysBetween(Now, Data^.RepositoryDate) <= Options.DaysToShowNewPackages)) and
         ((not Options.ShowRegularIcons) or ((Options.ShowRegularIcons) and (Data^.InstallState = 0))) and (Data^.DataType = 1) then
        CellText := '- ' + FormatDateTime('YYYY.MM.DD', Data^.RepositoryDate)
      else
        CellText := '';
    end
    else
      CellText := '';
  end
  else if TextType = ttNormal then
  begin
    if Column = 0 then
    begin
      case Data^.DataType of
        0: CellText := Data^.Repository;
        1: if Trim(Data^.PackageDisplayName) = '' then
             CellText := Data^.PackageName
           else
             CellText := Data^.PackageDisplayName;
        2: CellText := Data^.LazarusPackageName;
        3: CellText := rsMainFrm_VSTText_Description;
        4: CellText := rsMainFrm_VSTText_Author;
        5: CellText := rsMainFrm_VSTText_LazCompatibility;
        6: CellText := rsMainFrm_VSTText_FPCCompatibility;
        7: CellText := rsMainFrm_VSTText_SupportedWidgetsets;
        8: CellText := rsMainFrm_VSTText_Packagetype;
        9: CellText := rsMainFrm_VSTText_License;
       10: CellText := rsMainFrm_VSTText_Dependecies;
       11: CellText := rsMainFrm_VSTText_PackageInfo;
       12: CellText := rsMainFrm_VSTText_Category;
       13: CellText := rsMainFrm_VSTText_RepositoryFilename;
       14: CellText := rsMainFrm_VSTText_RepositoryFileSize;
       15: CellText := rsMainFrm_VSTText_RepositoryFileHash;
       16: CellText := rsMainFrm_VSTText_RepositoryFileDate;
       17: CellText := rsMainFrm_VSTText_HomePageURL;
       18: CellText := rsMainFrm_VSTText_DownloadURL;
       19: CellText := rsMainFrm_VSTText_CommunityDescription;
       20: CellText := rsMainFrm_VSTText_ExternalDeps;
       21: CellText := rsMainFrm_VSTText_OrphanedPackage1;
      end;
    end
    else if Column = 1 then
    begin
      case Data^.DataType of
        1: case Data^.InstallState of
            //0: CellText := rsMainFrm_VSTText_Install0;
            1: CellText := rsMainFrm_VSTText_Install1;
            2: CellText := rsMainFrm_VSTText_Install2;
        end;
        2: begin
             if Data^.InstalledVersion <> '' then
               CellText := Data^.InstalledVersion
             else
               CellText := '-';
           end
        else
          CellText := '';
      end
    end
    else if Column = 2 then
    begin
      if Data^.DataType = 2 then
        CellText := Data^.Version
      else
        CellText := '';
    end
    else if Column = 3 then
    begin
      case Data^.DataType of
        1: if Data^.HasUpdate then
             CellText := 'NEW';
        2: begin
             if (Data^.UpdateVersion <> '') then
               CellText := Data^.UpdateVersion
             else
               CellText := '-';
           end
        else
          CellText := '';
      end
    end
    else if Column = 4 then
    begin
      case Data^.DataType of
        0: CellText := '';
        1: CellText := '';
        2: case Ord(Data^.PackageState) of
             0: CellText := rsMainFrm_VSTText_PackageState0;
             1: CellText := rsMainFrm_VSTText_PackageState1;
             2: CellText := rsMainFrm_VSTText_PackageState2;
             3: begin
                  if not Data^.HasUpdate then
                  begin
                    if (Data^.UpdateVersion = '') then
                    begin
                      if Data^.InstalledVersion < Data^.Version then
                        CellText := rsMainFrm_VSTText_PackageState6
                      else if Data^.InstalledVersion = Data^.Version then
                        CellText := rsMainFrm_VSTText_PackageState4
                      else if Data^.InstalledVersion > Data^.Version then
                        CellText := rsMainFrm_VSTText_PackageState7
                    end
                    else
                    begin
                      if Data^.InstalledVersion < Data^.UpdateVersion then
                        CellText := rsMainFrm_VSTText_PackageState6
                      else if (Data^.InstalledVersion = Data^.UpdateVersion) then
                        CellText := rsMainFrm_VSTText_PackageState4
                      else if (Data^.InstalledVersion > Data^.UpdateVersion) then
                        CellText := rsMainFrm_VSTText_PackageState7
                    end;
                  end
                  else
                  begin
                    if Data^.InstalledVersion < Data^.UpdateVersion then
                      CellText := rsMainFrm_VSTText_PackageState6
                    else if Data^.InstalledVersion = Data^.UpdateVersion then
                      CellText := rsMainFrm_VSTText_PackageState4
                    else if Data^.InstalledVersion > Data^.UpdateVersion then
                      CellText := rsMainFrm_VSTText_PackageState7
                  end;
                  Data^.IsUpdated := CellText = rsMainFrm_VSTText_PackageState4;
                end;
           end;
        3: CellText := GetDisplayString(Data^.Description);
        4: CellText := Data^.Author;
        5: CellText := Data^.LazCompatibility;
        6: CellText := Data^.FPCCompatibility;
        7: CellText := Data^.SupportedWidgetSet;
        8: CellText := GetPackageTypeString(Data^.PackageType);
        9: CellText := GetDisplayString(Data^.License);
       10: CellText := Data^.Dependencies;
       11: CellText := '';
       12: CellText := TranslateCategories(Data^.Category);
       13: CellText := Data^.RepositoryFileName;
       14: CellText := FormatSize(Data^.RepositoryFileSize);
       15: CellText := Data^.RepositoryFileHash;
       16: CellText := FormatDateTime('YYYY.MM.DD', Data^.RepositoryDate);
       17: CellText := Data^.HomePageURL;
       18: CellText := Data^.DownloadURL;
       19: CellText := GetDisplayString(Data^.CommunityDescription);
       20: CellText := GetDisplayString(Data^.ExternalDependencies);
       21: case Data^.OrphanedPackage of
             0: CellText := rsMainFrm_VSTText_Install0;
             1: CellText := rsMainFrm_VSTText_Install1;
           end;
      end;
    end
    else if Column = 5 then
    begin
      CellText := '';
    end
  end;
end;

procedure TVisualTree.VSTHeaderClick(Sender: TVTHeader; HitInfo: TVTHeaderHitInfo);
begin
  if (HitInfo.Column <> 0) and (HitInfo.Column <> 1) and (HitInfo.Column <> 3) then
    Exit;
  if HitInfo.Button = mbLeft then
  begin
    with Sender, Treeview do
    begin
      if (SortColumn = NoColumn) or (SortColumn <> HitInfo.Column) then
      begin
        SortColumn    := HitInfo.Column;
        SortDirection := laz.VirtualTrees.sdAscending;
      end
      else
      begin
        if SortDirection = laz.VirtualTrees.sdAscending then
          SortDirection := laz.VirtualTrees.sdDescending
        else
          SortDirection := laz.VirtualTrees.sdAscending;
        FSortDir := SortDirection;
      end;
      SortTree(SortColumn, SortDirection, False);
      FSortCol := Sender.SortColumn;
    end;
  end;
end;

procedure TVisualTree.VSTPaintText(Sender: TBaseVirtualTree;
  const TargetCanvas: TCanvas; Node: PVirtualNode; Column: TColumnIndex;
  TextType: TVSTTextType);

 function GetTextColor(const ADefColor: TColor; AIsFocusedNode: Boolean): TColor;
 begin
   Result := ADefColor;
   if Result = clDefault then
     Result := Sender.GetDefaultColor(dctFont);
   if AIsFocusedNode then
   {$IFDEF WINDOWS}
     Result := clWhite;
   {$ENDIF}
 end;

var
  Data: PData;
begin
  Data := FVST.GetNodeData(Node);
  if TextType = ttStatic then
  begin
    if Column = 0 then
    begin
      if ((Options.DaysToShowNewPackages > 0) and (DaysBetween(Now, Data^.RepositoryDate) <= Options.DaysToShowNewPackages)) and
          ((not Options.ShowRegularIcons) or ((Options.ShowRegularIcons) and (Data^.InstallState = 0))) then
        TargetCanvas.Font.Style := TargetCanvas.Font.Style - [fsBold];
      TargetCanvas.Font.Color := GetTextColor(FVST.Font.Color, Node = Sender.FocusedNode);
    end
  end
  else if TextType = ttNormal then
  begin
    case column of
      2: begin
           if Data^.DataType = 2 then
           begin
             if (Data^.InstalledVersion = '') or ((Data^.InstalledVersion <> '') and (Data^.InstalledVersion < Data^.Version)) then
               TargetCanvas.Font.Style := TargetCanvas.Font.Style + [fsBold]
             else
               TargetCanvas.Font.Style := TargetCanvas.Font.Style - [fsBold];
           end;
           TargetCanvas.Font.Color := GetTextColor(FVST.Font.Color, Node = Sender.FocusedNode);
         end;
      3: begin
           case Data^.DataType of
             1: TargetCanvas.Font.Style := TargetCanvas.Font.Style + [fsBold];
             2: if (Data^.HasUpdate) and (Data^.UpdateVersion > Data^.InstalledVersion) then
                  TargetCanvas.Font.Style := TargetCanvas.Font.Style + [fsBold]
                else
                  TargetCanvas.Font.Style := TargetCanvas.Font.Style - [fsBold];
           end;
           TargetCanvas.Font.Color := GetTextColor(FVST.Font.Color, Node = Sender.FocusedNode);
         end;
      4: begin
           if (FHoverNode = Node) and (FHoverColumn = Column) and ((Data^.DataType = 17) or (Data^.DataType = 18)) then
           begin
             TargetCanvas.Font.Style := TargetCanvas.Font.Style + [fsUnderline];
             TargetCanvas.Font.Color := GetTextColor(clBlue, Node = Sender.FocusedNode);
           end
           else if (Data^.DataType = 2) and (Data^.IsUpdated) then
           begin
             TargetCanvas.Font.Style := TargetCanvas.Font.Style + [fsBold];
             TargetCanvas.Font.Color := GetTextColor(clGreen, Node = Sender.FocusedNode);
           end
           else
             TargetCanvas.Font.Color := GetTextColor(FVST.Font.Color, Node = Sender.FocusedNode);
         end
      else
        TargetCanvas.Font.Color := GetTextColor(FVST.Font.Color, Node = Sender.FocusedNode);
    end;
  end
end;

procedure TVisualTree.VSTFreeNode(Sender: TBaseVirtualTree; Node: PVirtualNode);
var
  Data: PData;
begin
  Data := FVST.GetNodeData(Node);
  if Assigned(Data^.Button) then
    Data^.Button.Visible := False;
  Finalize(Data^);
end;

function TVisualTree.GetColumn(const AX: Integer): Integer;
var
  I: Integer;
  L, R: Integer;
begin
  Result := -1;
  for I := 0 to VST.Header.Columns.Count - 1 do
  begin
    VST.Header.Columns.GetColumnBounds(I, L, R);
    if (AX >= L) and (AX <= R) then
    begin
      Result := I;
      Break;
    end;
  end;
end;

function TVisualTree.GetPackageAbsolutePath(APackageName: String): String;
var
  LazarusPkg: TLazarusPackage;
begin
  Result := '';
  LazarusPkg := SerializablePackages.FindLazarusPackage(APackageName);
  if (LazarusPkg <> nil) and (FileExists(LazarusPkg.PackageAbsolutePath)) then
    Result := LazarusPkg.PackageAbsolutePath;
end;

procedure TVisualTree.VSTMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
var
  Data: PData;
  ContRect: TRect;
  P: TPoint;
  Level: Integer;
begin
  FHoverColumn := -1;
  FHoverP.X := X;
  FHoverP.Y := Y;
  FHoverNode:= VST.GetNodeAt(X, Y);
  FHoverColumn := GetColumn(X);

  if (FOldButtonNode <> nil) and (FOldButtonNode <> FHoverNode) then
  begin
    Data := FVST.GetNodeData(FOldButtonNode);
    if Data^.Button <> nil then
    begin
      Data^.Button.Free;
      Data^.Button := nil;
    end;
  end;

  if ((FHoverColumn = 0) or (FShowHintFrm.Visible)) and (FHoverNode <> nil) then
  begin
    case Options.HintFormOption of
      0: begin
           if FShowHintFrm.Visible then
             FShowHintFrm.SetupTimer(300);
           Exit;
         end;
      1: begin
            P.X := X;
            P.Y := Y;
            ContRect := FVST.GetDisplayRect(FHoverNode, FHoverColumn, False);
            Level := FVST.GetNodeLevel(FHoverNode);
            if (ssShift in Shift) and PtInRect(ContRect, P) and (Level > 0) then
            begin
              P := FVST.ClientToScreen(P);
              if FShowHintFrm.Visible then
                FShowHintFrm.MoveFormTo(P.X, P.Y)
              else
                FShowHintFrm.ShowFormAt(P.X, P.Y);
              case Level of
                 2: FHoverNode := FHoverNode^.Parent;
                 3: FHoverNode := FHoverNode^.Parent^.Parent;
              end;
              if FHoverNode <> FHoverNodeOld then
              begin
                FShowHintFrm.UpdateInfo(FHoverNode);
                FHoverNodeOld := FHoverNode;
              end;
            end
        end;
      2: Exit;
    end;
  end;
  if (FHoverColumn = 5) and (FHoverNode <> nil) then
  begin
    FVST.ReinitNode(FHoverNode, False);
    FVST.RepaintNode(FHoverNode);
  end
  else if (FHoverColumn = 4) and (FHoverNode <> nil) then
  begin
    Data := VST.GetNodeData(FHoverNode);
    if ((Data^.DataType = 17) and (Trim(Data^.HomePageURL) <> '')) or
       ((Data^.DataType = 18) and (Trim(Data^.DownloadURL) <> '')) then
      FVST.Cursor := crHandPoint;

    if (Data^.Button = nil) and
       (
         ((Data^.DataType = 2) and (Data^.PackageState in [psExtracted, psInstalled]) and (GetPackageAbsolutePath(Data^.LazarusPackageName) <> '')) or
         ((Data^.DataType = 3) and (Trim(Data^.Description) <> '')) or
         ((Data^.DataType = 9) and (Trim(Data^.License) <> '')) or
         ((Data^.DataType = 19) and (Trim(Data^.CommunityDescription) <> '')) or
         ((Data^.DataType = 20) and (Trim(Data^.ExternalDependencies) <> ''))
        ) then
    begin
      Data := FVST.GetNodeData(FHoverNode);
      Data^.Button := TSpeedButton.Create(VST);
      with Data^.Button do
      begin
        if Data^.DataType = 2 then
        begin
          Width := 75;
          Caption := rsMainFrm_VSTText_Open;
        end
        else
          Caption := '...';
        Parent := FVST;
        Tag := Data^.ButtonID;
        Visible := True;
        OnClick := @ButtonClick;
      end;
      FOldButtonNode := FHoverNode;
    end;
  end
end;

procedure TVisualTree.VSTMouseEnter(Sender: TObject);
begin
  FLeaving := False;
end;

procedure TVisualTree.VSTMouseLeave(Sender: TObject);
begin
  if Assigned(FHoverNode) then
  begin
    FLeaving := True;
    FVST.ReinitNode(FHoverNode, False);
    FVST.RepaintNode(FHoverNode)
  end;
end;

procedure TVisualTree.VSTMouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
var
 Node: PVirtualNode;
 Data: PData;
 MenuItem: TMenuItem;
 DownColumn: Integer;
 R: TRect;
 PackageName: String;
 MetaPkg: TMetaPackage;
begin
  FMouseEnter := True;
  Node := FVST.GetNodeAt(X, Y);
  if Node <> nil then
  begin
    DownColumn := GetColumn(X);
    Data := FVST.GetNodeData(Node);
    if Button = mbLeft then
    begin
      case DownColumn of
        4: if (Data^.DataType = 17) or (Data^.DataType = 18) and (DownColumn = 4) then
           begin
             FLinkClicked := True;
             if (Data^.DataType = 17) and (Trim(Data^.HomePageURL) <> '') then
               FLink := Data^.HomePageURL
             else if (Data^.DataType = 18) and (Trim(Data^.DownloadURL) <> '') then
               FLink := Data^.DownloadURL;
           end;
        5: begin
             if Data^.DataType = 1 then
             begin
               R := FVST.GetDisplayRect(Node, DownColumn, False);
               Data^.Rating := Trunc((FHoverP.X - R.Left - 1)/FStarSize) + 1;
               if Data^.Rating > 5 then
                 Data^.Rating := 5;
               MetaPkg := SerializablePackages.Items[Data^.PID];
               if MetaPkg <> nil then
                 MetaPkg.Rating := Data^.Rating;
               if Data^.PackageDisplayName <> '' then
                 PackageName := Data^.PackageDisplayName
               else
                 PackageName := Data^.PackageName;
               MessageDlgEx(Format(rsMainFrm_rsPackageRating, [PackageName, InttoStr(Data^.Rating)]), mtInformation, [mbOk],  TForm(FVST.Parent.Parent));
             end;
           end;
      end;
    end
    else if Button = mbRight then
    begin
      MenuItem := FVST.PopupMenu.Items.Find(rsMainFrm_miCopyToClpBrd);
      if MenuItem <> nil then
        MenuItem.Enabled := ((Data^.DataType = 17) and (Trim(Data^.HomePageURL) <> '')) or
                            ((Data^.DataType = 18) and (Trim(Data^.DownloadURL) <> ''));
      MenuItem := FVST.PopupMenu.Items.Find(rsMainFrm_miResetRating);
      if MenuItem <> nil then
        MenuItem.Enabled := (DownColumn = 5) and (Data^.Rating <> 0);
    end;
  end
end;

procedure TVisualTree.VSTKeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
 //
end;

procedure TVisualTree.VSTKeyUp(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
  if Key = VK_SHIFT then
    if Assigned(FShowHintFrm) and FShowHintFrm.Visible and (Options.HintFormOption = 1) then
      FShowHintFrm.SetupTimer(300);
end;

procedure TVisualTree.VSTGetHint(Sender: TBaseVirtualTree; Node: PVirtualNode;
  Column: TColumnIndex; var LineBreakStyle: TVTTooltipLineBreakStyle;
  var HintText: String);
var
  Data: PData;
  P1, P2: TPoint;
  Level: Integer;
begin
  Data := FVST.GetNodeData(Node);
  if (Column <> 4) and (Column <> 0) then
    Exit;
  LineBreakStyle := hlbForceSingleLine;
  case Data^.DataType of
    1: if Options.HintFormOption = 0 then
       begin
         HintText := '';
         P1.X := 0;
         P1.Y := 0;
         GetCursorPos(P1);
         P2 := FVST.ScreenToClient(P1);
         Level := FVST.GetNodeLevel(FHoverNode);
         if PtInRect(FVST.GetDisplayRect(Node, Column, True), P2) and (Level > 0) then
         begin
           FShowHintFrm.ShowFormAt(P1.X, P1.Y);
           FShowHintFrm.SetupTimer(Application.HintHidePause);
           case Level of
              2: FHoverNode := FHoverNode^.Parent;
              3: FHoverNode := FHoverNode^.Parent^.Parent;
           end;
           if FHoverNode <> FHoverNodeOld then
           begin
             FShowHintFrm.UpdateInfo(FHoverNode);
             FHoverNodeOld := FHoverNode;
           end;
         end;
       end;
    3: HintText := Data^.Description;
    4: HintText := Data^.Author;
    5: HintText := Data^.LazCompatibility;
    6: HintText := Data^.FPCCompatibility;
    7: HintText := Data^.SupportedWidgetSet;
    8: HintText := GetPackageTypeString(Data^.PackageType);
    9: HintText := GetDisplayString(Data^.License);
    10: HintText := Data^.Dependencies;
    11: HintText := '';
    12: HintText := TranslateCategories(Data^.Category);
    13: HintText := Data^.RepositoryFileName;
    14: HintText := FormatSize(Data^.RepositoryFileSize);
    15: HintText := Data^.RepositoryFileHash;
    16: HintText := FormatDateTime('YYYY.MM.DD', Data^.RepositoryDate);
    17: HintText := Data^.HomePageURL;
    18: HintText := Data^.DownloadURL;
    19: HintText := Data^.CommunityDescription;
    20: HintText := Data^.ExternalDependencies;
   else
       HintText := '';
  end;
end;

procedure TVisualTree.VSTDblClick(Sender: TObject);
var
  Data: PData;
  Node: PVirtualNode;
begin
  Node := FVST.GetFirstSelected;
  if (Node <> nil) and (FVST.GetNodeLevel(Node) = 2) then
  begin
    Data := FVST.GetNodeData(Node);
    if (Data^.DataType = 2) and (Data^.PackageState in [psExtracted, psInstalled]) then
      DoOpenPackage(Data^.LazarusPackageName);
  end;
end;

procedure TVisualTree.VSTScroll(Sender: TBaseVirtualTree; DeltaX, DeltaY: Integer);
begin
  if FShowHintFrm.Visible then
    FShowHintFrm.Hide;
end;

procedure TVisualTree.VSTIncrementalSearch(Sender: TBaseVirtualTree;
  Node: PVirtualNode; const SearchText: String; var Result: Integer);
var
  Data: PData;
begin
  Data := FVST.GetNodeData(Node);
  if FVST.GetNodeLevel(Node) = 1 then
    Result := StrLIComp(PChar(SearchText), PChar(Data^.PackageDisplayName), Min(Length(SearchText), Length(Data^.PackageDisplayName)))
  else
    Result := -1;
end;

procedure TVisualTree.VSTClick(Sender: TObject);
begin
  if FLinkClicked then
  begin
    FLinkClicked := False;
    FHoverColumn := -1;
    FHoverNode := nil;
    if Trim(FLink) <> '' then
      OpenURL(FLink);
    FLink := '';
  end;
end;


end.


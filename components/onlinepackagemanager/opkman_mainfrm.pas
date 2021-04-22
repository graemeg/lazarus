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
   Implementation of the main dialog.
}
unit opkman_mainfrm;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpjson, Graphics, laz.VirtualTrees, md5,
  // LCL
  Forms, Controls, Dialogs, StdCtrls, ExtCtrls, Buttons, Menus, ComCtrls, Clipbrd,
  InterfaceBase, LCLIntf, LCLVersion, LCLProc, LCLPlatformDef,
  // LazUtils
  LazFileUtils, LazIDEIntf, LazVersion,
  // IdeIntf
  IDECommands, PackageIntf,
  // OpkMan
  opkman_downloader, opkman_installer, opkman_updates,
  opkman_serializablepackages, opkman_visualtree, opkman_const, opkman_common,
  opkman_progressfrm, opkman_zipper, opkman_packagelistfrm, opkman_options,
  opkman_optionsfrm, opkman_createrepositorypackagefrm, opkman_maindm,
  opkman_createjsonforupdatesfrm, opkman_createrepositoryfrm;

type

  { TMainFrm }

  TMainFrm = class(TForm)
    bReturn: TButton;
    cbFilterBy: TComboBox;
    cbPackageCategory: TComboBox;
    cbPackageState: TComboBox;
    cbPackageType: TComboBox;
    imTBDis: TImageList;
    miSaveChecked: TMenuItem;
    miFromExteranlSource: TMenuItem;
    miFromRepository: TMenuItem;
    miSaveInstalled: TMenuItem;
    miSep2: TMenuItem;
    miSep3: TMenuItem;
    miSep1: TMenuItem;
    miCreateRepository: TMenuItem;
    miLoad: TMenuItem;
    miSave: TMenuItem;
    miDateDsc: TMenuItem;
    miDateAsc: TMenuItem;
    miNameDsc: TMenuItem;
    miNameAsc: TMenuItem;
    miByDate: TMenuItem;
    miByName: TMenuItem;
    miSaveToFile: TMenuItem;
    miJSONSort: TMenuItem;
    miResetRating: TMenuItem;
    miCopyToClpBrd: TMenuItem;
    miCreateJSONForUpdates: TMenuItem;
    miCreateRepositoryPackage: TMenuItem;
    OD: TOpenDialog;
    pnReturn: TPanel;
    pmInstall: TPopupMenu;
    SD: TSaveDialog;
    tbCleanUp1: TToolButton;
    tbInstall1: TToolButton;
    tbUninstall: TToolButton;
    tbOptions: TToolButton;
    cbAll: TCheckBox;
    edFilter: TEdit;
    lbFilterBy: TLabel;
    miJSONShow: TMenuItem;
    miJSONHide: TMenuItem;
    mJSON: TMemo;
    pmMemo: TPopupMenu;
    pnFilter: TPanel;
    pnMessage: TPanel;
    pnToolBar: TPanel;
    pnTop: TPanel;
    pnMain: TPanel;
    pmTree: TPopupMenu;
    pmCreate: TPopupMenu;
    SDD: TSelectDirectoryDialog;
    spCollapse: TSpeedButton;
    spClear: TSpeedButton;
    spExpand: TSpeedButton;
    tbButtons: TToolBar;
    imTBNor: TImageList;
    tbDownload: TToolButton;
    tbInstall: TToolButton;
    tbHelp: TToolButton;
    tbRefresh: TToolButton;
    tbCleanUp: TToolButton;
    tbCreate: TToolButton;
    tbUpdate: TToolButton;
    tbOpenRepo: TToolButton;
    tmWait: TTimer;
    procedure bReturnClick(Sender: TObject);
    procedure FormCloseQuery(Sender: TObject; var CanClose: boolean);
    procedure FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure miCopyToClpBrdClick(Sender: TObject);
    procedure miCreateJSONForUpdatesClick(Sender: TObject);
    procedure miCreateRepositoryClick(Sender: TObject);
    procedure miCreateRepositoryPackageClick(Sender: TObject);
    procedure miFromExteranlSourceClick(Sender: TObject);
    procedure miFromRepositoryClick(Sender: TObject);
    procedure miLoadClick(Sender: TObject);
    procedure miNameAscClick(Sender: TObject);
    procedure miResetRatingClick(Sender: TObject);
    procedure miSaveCheckedClick(Sender: TObject);
    procedure miSaveInstalledClick(Sender: TObject);
    procedure miSaveToFileClick(Sender: TObject);
    procedure pnReturnResize(Sender: TObject);
    procedure pnToolBarResize(Sender: TObject);
    procedure tbCleanUpClick(Sender: TObject);
    procedure tbCreateClick(Sender: TObject);
    procedure tbDownloadClick(Sender: TObject);
    procedure tbHelpClick(Sender: TObject);
    procedure tbInstallClick(Sender: TObject);
    procedure tbOpenRepoClick(Sender: TObject);
    procedure tbOptionsClick(Sender: TObject);
    procedure tbRefreshClick(Sender: TObject);
    procedure cbAllClick(Sender: TObject);
    procedure cbFilterByChange(Sender: TObject);
    procedure cbPackageCategoryChange(Sender: TObject);
    procedure cbPackageStateChange(Sender: TObject);
    procedure cbPackageTypeChange(Sender: TObject);
    procedure edFilterChange(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormKeyPress(Sender: TObject; var Key: char);
    procedure FormShow(Sender: TObject);
    procedure miJSONShowClick(Sender: TObject);
    procedure pnMainResize(Sender: TObject);
    procedure pnTopResize(Sender: TObject);
    procedure spClearClick(Sender: TObject);
    procedure spExpandClick(Sender: TObject);
    procedure tbUninstallClick(Sender: TObject);
    procedure tbUpdateClick(Sender: TObject);
    procedure tmWaitTimer(Sender: TObject);
  private
    FHintTimeOut: Integer;
    FFormIsHiden: Boolean;
    procedure EnableDisableControls(const AEnable: Boolean);
    procedure SetupMessage(const AMessage: String = '');
    procedure SetupControls;
    procedure SetupColors;
    procedure GetPackageList(const ARepositoryHasChanged: Boolean = False);
    procedure DoOnChecking(Sender: TObject; const AIsAllChecked: Boolean);
    procedure DoOnChecked(Sender: TObject);
    procedure DoOnJSONProgress(Sender: TObject);
    procedure DoOnJSONDownloadCompleted(Sender: TObject; AJSON: TJSONStringType; AErrTyp: TErrorType; const AErrMsg: String = '');
    procedure DoOnProcessJSON(Sender: TObject);
    procedure DoDeactivate(Sender: TObject);
    function IsSomethingChecked(const AResolveDependencies: Boolean = True): Boolean;
    function Download(const ADstDir: String; var ADoExtract: Boolean): TModalResult;
    function Extract(const ASrcDir, ADstDir: String; var ADoOpen: Boolean; const AIsUpdate: Boolean = False): TModalResult;
    function Install(var AInstallStatus: TInstallStatus; var ANeedToRebuild: Boolean): TModalResult;
    function UpdateP(const ADstDir: String; var ADoExtract: Boolean): TModalResult;
    procedure Rebuild;
    function CheckDstDir(const ADstDir: String): Boolean;
  protected
    procedure DoAutoAdjustLayout(const AMode: TLayoutAdjustmentPolicy;
      const AXProportion, AYProportion: Double); override;
  public
    procedure ShowOptions(const AActivePageIndex: Integer = 0);
  end;

var
  MainFrm: TMainFrm;

implementation

{$R *.lfm}

{ TMainFrm }

procedure TMainFrm.FormCreate(Sender: TObject);
begin
  if MainDM = nil then
    MainDM := TMainDM.Create(self);
  VisualTree := TVisualTree.Create(pnMain, MainDM.Images, pmTree);
  VisualTree.OnChecking := @DoOnChecking;
  VisualTree.OnChecked := @DoOnChecked;
  SerializablePackages.OnProcessJSON := @DoOnProcessJSON;
  PackageDownloader.OnJSONProgress := @DoOnJSONProgress;
  PackageDownloader.OnJSONDownloadCompleted := @DoOnJSONDownloadCompleted;
  spExpand.Caption := '';
  spExpand.Images := MainDM.Images;
  spExpand.ImageIndex := IMG_EXPAND;
  spCollapse.Caption := '';
  spCollapse.Images := MainDM.Images;
  spCollapse.ImageIndex := IMG_COLLAPSE;
  spClear.Images := MainDM.Images;
  spClear.ImageIndex := IMG_CLEAR;
  FHintTimeOut := Application.HintHidePause;
  Updates := nil;
  CurLazVersion := IntToStr(laz_major) + '.' + IntToStr(laz_minor) + '.' + IntToStr(laz_release);
  CurFPCVersion := {$I %FPCVERSION%};
  CurWidgetSet := LCLPlatformDisplayNames[GetDefaultLCLWidgetType];
  Application.HintHidePause := 1000000;
  Application.AddOnDeactivateHandler(@DoDeactivate, False);
end;

procedure TMainFrm.FormDestroy(Sender: TObject);
begin
  SerializablePackages.OnProcessJSON := nil;
  PackageDownloader.OnJSONProgress := nil;
  PackageDownloader.OnJSONDownloadCompleted := nil;
  Application.RemoveOnDeactivateHandler(@DoDeactivate);
  FreeAndNil(VisualTree);
  Application.HintHidePause := FHintTimeOut;
end;

procedure TMainFrm.FormKeyPress(Sender: TObject; var Key: char);
begin
  if Key = #27 then
    Close;
end;

procedure TMainFrm.FormShow(Sender: TObject);
begin
  if not FFormIsHiden then
  begin
    SetupControls;
    SetupColors;
    tmWait.Enabled := True;
  end
end;

procedure TMainFrm.tmWaitTimer(Sender: TObject);
begin
  tmWait.Enabled := False;
  if (Options.CheckForUpdates <> 5) then
  begin
    Updates := TUpdates.Create;
    Updates.StartUpdate;
  end;
  GetPackageList;
end;


procedure TMainFrm.GetPackageList(const ARepositoryHasChanged: Boolean = False);
var
  JSONFile: String;
  JSON: TJSONStringType;
  MS: TMemoryStream;
  SuccessfullyLoaded: Boolean;
begin
  cbFilterBy.ItemIndex := 0;
  cbFilterByChange(cbFilterBy);
  Caption := rsLazarusPackageManager;
  EnableDisableControls(False);
  VisualTree.VST.Clear;
  VisualTree.VST.Invalidate;
  if ARepositoryHasChanged then
  begin
    SetupMessage(rsMainFrm_rsMessageChangingRepository);
    Sleep(1500);
  end;

  SuccessfullyLoaded := False;
  JSONFile := ExtractFilePath(LocalRepositoryConfigFile) + 'packagelist' + '_' + MD5Print(MD5String(Options.RemoteRepository[Options.ActiveRepositoryIndex])) + '.json';
  if Options.LoadJsonLocally and (Options.LoadJsonLocallyCnt < 25) and FileExists(JSONFile) and (FileSizeUtf8(JSONFile) > 0) then
  begin
    MS := TMemoryStream.Create;
    try
      MS.LoadFromFile(JSONFile);
      MS.Position := 0;
      SetLength({%H-}JSON, MS.Size);
      MS.Read(Pointer(JSON)^, Length(JSON));
      try
        SuccessfullyLoaded := SerializablePackages.JSONToPackages(JSON);
      except
      end;
      if SuccessfullyLoaded then
      begin
        DoOnJSONDownloadCompleted(Self, JSON, etNone);
        Options.LoadJsonLocallyCnt := Options.LoadJsonLocallyCnt + 1;
      end
      else
        Options.LoadJsonLocallyCnt := 25;
      Options.Changed := True;
    finally
      MS.Free;
    end;
  end;

  if not SuccessfullyLoaded then
  begin
    if Options.LoadJsonLocally then
    begin
      Options.LoadJsonLocallyCnt := 0;
      Options.Changed := True;
    end;
    SetupMessage(rsMainFrm_rsMessageDownload);
    PackageDownloader.DownloadJSON(Options.ConTimeOut*1000);
  end;
end;

function TMainFrm.IsSomethingChecked(const AResolveDependencies: Boolean = True): Boolean;
begin
  Result := VisualTree.VST.CheckedCount > 0;
  if Result then
  begin
    if AResolveDependencies then
      if VisualTree.ResolveDependencies = mrCancel then
      begin
        Result := False;
        Exit;
      end;
    VisualTree.GetPackageList;
    VisualTree.UpdatePackageStates;
  end
  else
    MessageDlgEx(rsMainFrm_rsNoPackageToDownload, mtInformation, [mbOk], Self)
end;

function TMainFrm.CheckDstDir(const ADstDir: String): Boolean;
begin
  Result := True;
  if not DirectoryExists(ADstDir) then
  begin
    if not ForceDirectories(ADstDir) then
    begin
      MessageDlgEx(Format(rsMainFrm_rsDestDirError, [ADstDir]), mtError, [mbOk], Self);
      Result := False;
    end;
  end;
end;


procedure TMainFrm.DoAutoAdjustLayout(const AMode: TLayoutAdjustmentPolicy;
  const AXProportion, AYProportion: Double);
begin
  inherited;
  if AMode in [lapAutoAdjustWithoutHorizontalScrolling, lapAutoAdjustForDPI] then
    VisualTree.AutoAdjustLayout(AXProportion, AYProportion);
end;

function TMainFrm.Download(const ADstDir: String; var ADoExtract: Boolean): TModalResult;
begin
  if not CheckDstDir(ADstDir) then
  begin
    Result := mrCancel;
    Exit;
  end;
  ADoExtract := False;
  ProgressFrm := TProgressFrm.Create(MainFrm);
  try
    ProgressFrm.SetupControls(0);
    PackageDownloader.OnPackageDownloadProgress := @ProgressFrm.DoOnPackageDownloadProgress;
    PackageDownloader.OnPackageDownloadError := @ProgressFrm.DoOnPackageDownloadError;
    PackageDownloader.OnPackageDownloadCompleted := @ProgressFrm.DoOnPackageDownloadCompleted;
    PackageDownloader.DownloadPackages(ADstDir);
    Result := ProgressFrm.ShowModal;
    if Result = mrOK then
      ADoExtract := ProgressFrm.cbExtractOpen.Checked;
  finally
    ProgressFrm.Free;
  end;
end;

function TMainFrm.Extract(const ASrcDir, ADstDir: String; var ADoOpen: Boolean;
  const AIsUpdate: Boolean = False): TModalResult;
begin
  if not CheckDstDir(ADstDir) then
  begin
    Result := mrCancel;
    Exit;
  end;
  ProgressFrm := TProgressFrm.Create(MainFrm);
  try
    PackageUnzipper := TPackageUnzipper.Create;
    ProgressFrm.SetupControls(1);
    PackageUnzipper.OnZipProgress := @ProgressFrm.DoOnZipProgress;
    PackageUnzipper.OnZipError := @ProgressFrm.DoOnZipError;
    PackageUnzipper.OnZipCompleted := @ProgressFrm.DoOnZipCompleted;
    PackageUnzipper.StartUnZip(ASrcDir, ADstDir, AIsUpdate);
    Result := ProgressFrm.ShowModal;
    if Result = mrOk then
      ADoOpen := ProgressFrm.cbExtractOpen.Checked;
 finally
   ProgressFrm.Free;
 end;
end;

function TMainFrm.Install(var AInstallStatus: TInstallStatus;
  var ANeedToRebuild: Boolean): TModalResult;
begin
  ProgressFrm := TProgressFrm.Create(MainFrm);
  try
    ProgressFrm.SetupControls(2);
    Result := ProgressFrm.ShowModal;
    if Result = mrOk then
    begin
      AInstallStatus := ProgressFrm.InstallStatus;
      ANeedToRebuild := ProgressFrm.NeedToRebuild;
    end;
  finally
    ProgressFrm.Free;
  end;
end;

function TMainFrm.UpdateP(const ADstDir: String; var ADoExtract: Boolean): TModalResult;
begin
  if not CheckDstDir(ADstDir) then
   begin
     Result := mrCancel;
     Exit;
   end;
  ADoExtract := False;
  ProgressFrm := TProgressFrm.Create(MainFrm);
  try
    ProgressFrm.SetupControls(3);
    PackageDownloader.OnPackageDownloadProgress := @ProgressFrm.DoOnPackageDownloadProgress;
    PackageDownloader.OnPackageDownloadError := @ProgressFrm.DoOnPackageDownloadError;
    PackageDownloader.OnPackageDownloadCompleted := @ProgressFrm.DoOnPackageDownloadCompleted;
    PackageDownloader.OnPackageUpdateProgress := @ProgressFrm.DoOnPackageUpdateProgress;
    PackageDownloader.OnPackageUpdateCompleted := @ProgressFrm.DoOnPackageUpdateCompleted;
    PackageDownloader.UpdatePackages(ADstDir);
    Result := ProgressFrm.ShowModal;
    if Result = mrOK then
      ADoExtract := ProgressFrm.cbExtractOpen.Checked;
  finally
    ProgressFrm.Free;
  end;
end;

procedure TMainFrm.DoOnJSONDownloadCompleted(Sender: TObject; AJSON: TJSONStringType; AErrTyp: TErrorType; const AErrMsg: String = '');
begin
  case AErrTyp of
    etNone:
      begin
        if (not Options.LoadJsonLocally) then
          SetupMessage(rsMainFrm_rsMessageParsingJSON);
        if (SerializablePackages.Count = 0) then
        begin
          EnableDisableControls(True);
          SetupMessage(rsMainFrm_rsMessageNoPackage);
          MessageDlgEx(rsMainFrm_rsMessageError1 + sLineBreak + SerializablePackages.LastError, mtInformation, [mbOk], Self);
          Exit;
        end;
        VisualTree.PopulateTree;
        VisualTree.UpdatePackageUStatus;
        EnableDisableControls(True);
        SetupMessage;
        mJSON.Text := AJSON;
        cbAll.Checked := False;
        Caption := rsLazarusPackageManager + ' ' + SerializablePackages.QuickStatistics;
      end;
    etConfig:
      begin
        EnableDisableControls(True);
        SetupMessage(rsMainFrm_rsMessageNoPackage);
        Caption := rsLazarusPackageManager;
        if MessageDlgEx('"' + AErrMsg + '"', mtConfirmation, [mbYes, mbNo], Self) = mrYes then
          ShowOptions;
      end;
    etTimeOut, etHTTPClient:
      begin
        EnableDisableControls(True);
        SetupMessage(rsMainFrm_rsMessageNoPackage);
        Caption := rsLazarusPackageManager;
        MessageDlgEx(rsMainFrm_rsMessageError0 + sLineBreak + '"' + AErrMsg + '"', mtInformation, [mbOk], Self);
      end;
  end;
end;

procedure TMainFrm.DoOnJSONProgress(Sender: TObject);
begin
  Application.ProcessMessages;
end;


procedure TMainFrm.DoOnProcessJSON(Sender: TObject);
begin
  Application.ProcessMessages;
end;

procedure TMainFrm.DoDeactivate(Sender: TObject);
begin
  if Assigned(VisualTree.ShowHintFrm) then
    if VisualTree.ShowHintFrm.Visible then
       VisualTree.ShowHintFrm.Hide;
end;

procedure TMainFrm.ShowOptions(const AActivePageIndex: Integer = 0);
var
  OldIndex: Integer;
  DefaultTheme: Boolean;
begin
  OptionsFrm := TOptionsFrm.Create(MainFrm);
  try
    OptionsFrm.SetupControls(AActivePageIndex);
    OldIndex := Options.ActiveRepositoryIndex;
    DefaultTheme := Options.UseDefaultTheme;
    if OptionsFrm.ShowModal = mrOk then
    begin
      tbRefresh.Enabled := Trim(Options.RemoteRepository[Options.ActiveRepositoryIndex]) <> '';
      GetPackageList(OldIndex <> Options.ActiveRepositoryIndex);
      if DefaultTheme <> Options.UseDefaultTheme then
        SetupColors;
    end;
  finally
    OptionsFrm.Free;
  end;
end;

procedure TMainFrm.EnableDisableControls(const AEnable: Boolean);
begin
  cbAll.Enabled := (AEnable) and (SerializablePackages.Count > 0);
  cbFilterBy.Enabled := (AEnable) and (SerializablePackages.Count > 0);
  pnFilter.Enabled := (AEnable) and (SerializablePackages.Count > 0);
  cbPackageState.Enabled := (AEnable) and (SerializablePackages.Count > 0);
  cbPackageType.Enabled := (AEnable) and (SerializablePackages.Count > 0);

  spExpand.Enabled := (AEnable) and (SerializablePackages.Count > 0);
  spCollapse.Enabled := (AEnable) and (SerializablePackages.Count > 0);
  VisualTree.VST.Enabled := (AEnable) and (SerializablePackages.Count > 0);
  if edFilter.CanFocus then
    edFilter.SetFocus;
  tbRefresh.Enabled := (AEnable) and (Trim(Options.RemoteRepository[Options.ActiveRepositoryIndex]) <> '');
  tbDownload.Enabled := (AEnable) and (SerializablePackages.Count > 0) and (VisualTree.VST.CheckedCount > 0);
  tbInstall.Enabled := (AEnable) and (SerializablePackages.Count > 0) and (VisualTree.VST.CheckedCount > 0);
  tbUninstall.Enabled := (AEnable) and (SerializablePackages.Count > 0) and (VisualTree.VST.CheckedCount > 0);
  tbUpdate.Enabled :=  (AEnable) and (SerializablePackages.Count > 0) and (VisualTree.VST.CheckedCount > 0);
  tbOpenRepo.Enabled := (AEnable);
  tbCleanUp.Enabled := (AEnable) and (SerializablePackages.Count > 0);
  tbCreate.Visible := Options.UserProfile = 1;
  if tbCreate.Visible then
  begin
    tbCreate.Left := tbOptions.Left - 10;
    tbCreate.Enabled := (AEnable);
  end;
  pnToolBarResize(pnToolbar);
  tbOptions.Enabled := (AEnable);
  tbHelp.Enabled := (AEnable);
end;

procedure TMainFrm.SetupMessage(const AMessage: String = '');
begin
  if AMessage = '' then
  begin
    pnMessage.SendToBack;
    pnMessage.Visible := False;
  end
  else
  begin
    pnMessage.Caption := AMessage;
    pnMessage.Visible := True;
    pnMessage.BringToFront;
    Application.ProcessMessages;
  end;
end;

procedure TMainFrm.DoOnChecking(Sender: TObject; const AIsAllChecked: Boolean);
begin
  cbAll.OnClick := nil;
  cbAll.Checked := AIsAllChecked;
  cbAll.OnClick := @cbAllClick;
end;

procedure TMainFrm.DoOnChecked(Sender: TObject);
begin
  EnableDisableControls(True);
end;

procedure TMainFrm.cbAllClick(Sender: TObject);
begin
  VisualTree.CheckNodes(cbAll.Checked);
  EnableDisableControls(True);
end;

procedure TMainFrm.cbFilterByChange(Sender: TObject);
begin
  VisualTree.ResetFilter;
  case cbFilterBy.ItemIndex of
    0..1, 4..9, 11..12:
      begin
        cbPackageType.Visible := False;
        cbPackageState.Visible := False;
        cbPackageCategory.Visible := False;
        pnFilter.Visible := True;
        edFilter.Text := '';
        if edFilter.CanFocus then
          edFilter.SetFocus;
      end;
   2: begin
        pnFilter.Visible := False;
        cbPackageType.Visible := False;
        cbPackageState.Visible := False;
        cbPackageCategory.Visible := True;
        cbPackageCategory.ItemIndex := 0;
        if cbPackageCategory.CanFocus then
          cbPackageCategory.SetFocus;
      end;
   3: begin
        pnFilter.Visible := False;
        cbPackageType.Visible := False;
        cbPackageState.Visible := True;
        cbPackageCategory.Visible := False;
        cbPackageState.ItemIndex := 0;
        if cbPackageState.CanFocus then
          cbPackageState.SetFocus;
      end;
   10: begin
        pnFilter.Visible := False;
        cbPackageState.Visible := False;
        cbPackageType.Visible := True;
        cbPackageCategory.Visible := False;
        cbPackageType.ItemIndex := 0;
        if cbPackageType.CanFocus then
          cbPackageType.SetFocus;
      end;
  end;
  cbPackageState.Height := cbFilterBy.Height;
  cbPackageState.Top := (pnTop.Height - cbPackageState.Height) div 2;
  cbPackageType.Height := cbFilterBy.Height;
  cbPackageType.Top := (pnTop.Height - cbPackageType.Height) div 2;
  cbPackageCategory.Height := cbFilterBy.Height;
  cbPackageCategory.Top := (pnTop.Height - cbPackageCategory.Height) div 2;
end;

procedure TMainFrm.cbPackageCategoryChange(Sender: TObject);
begin
  if cbPackageCategory.ItemIndex > 0 then
    VisualTree.FilterTree(TFilterBy(cbFilterBy.ItemIndex), 'PackageCategory', cbPackageCategory.ItemIndex - 1)
  else
    VisualTree.ResetFilter;
end;

procedure TMainFrm.cbPackageTypeChange(Sender: TObject);
begin
  if cbPackageType.ItemIndex > 0 then
    VisualTree.FilterTree(TFilterBy(cbFilterBy.ItemIndex), 'PackageType', cbPackageType.ItemIndex - 1)
  else
    VisualTree.ResetFilter;
end;

procedure TMainFrm.cbPackageStateChange(Sender: TObject);
begin
  if cbPackageState.ItemIndex > 0 then
    VisualTree.FilterTree(TFilterBy(cbFilterBy.ItemIndex), 'PackageState', cbPackageState.ItemIndex - 1)
  else
    VisualTree.ResetFilter;
end;

procedure TMainFrm.edFilterChange(Sender: TObject);
begin
  if edFilter.Text <> '' then
    VisualTree.FilterTree(TFilterBy(cbFilterBy.ItemIndex), edFilter.Text)
  else
    VisualTree.ResetFilter;
end;

procedure TMainFrm.pnTopResize(Sender: TObject);
begin
  cbFilterBy.Left := (pnTop.Width - pnFilter.Width - cbFilterBy.Width + lbFilterBy.Width - 5) div 2;
  pnFilter.Left := cbFilterBy.Left + cbFilterBy.Width + 5;
  cbPackageType.Left := pnFilter.Left;
  cbPackageState.Left := pnFilter.Left;
  cbPackageCategory.Left := pnFilter.Left;
  lbFilterBy.Left := cbFilterBy.Left - 8 - lbFilterBy.Width;
end;

procedure TMainFrm.spClearClick(Sender: TObject);
begin
  edFilter.OnChange := nil;
  edFilter.Text := '';
  VisualTree.ResetFilter;
  edFilter.OnChange := @edFilterChange;
end;

procedure TMainFrm.spExpandClick(Sender: TObject);
begin
  case TSpeedButton(Sender).Tag of
    1: VisualTree.ExpandEx;
    2: VisualTree.CollapseEx;
  end;
end;

procedure TMainFrm.tbOptionsClick(Sender: TObject);
begin
  ShowOptions;
end;

procedure TMainFrm.tbHelpClick(Sender: TObject);
begin
  OpenURL('http://wiki.freepascal.org/Online_Package_Manager');
end;

procedure TMainFrm.tbRefreshClick(Sender: TObject);
begin
  GetPackageList;
end;

procedure TMainFrm.tbDownloadClick(Sender: TObject);
var
  DstDir: String;
  CanGo: Boolean;
  DoExtract: Boolean;
  DoOpen: Boolean;
begin
  if not IsSomethingChecked(False) then
    Exit;

  SDD.InitialDir := Options.LastDownloadDir;
  if SDD.Execute then
  begin
    CanGo := True;
    DstDir := AppendPathDelim(SDD.FileName);
    VisualTree.UpdatePackageStates;
    PackageListFrm := TPackageListFrm.Create(MainFrm);
    try
      PackageListFrm.lbMessage.Caption := rsMainFrm_PackageAlreadyDownloaded;
      PackageListFrm.PopulateList(1, DstDir);
      if PackageListFrm.Count > 0 then
        CanGo := PackageListFrm.ShowModal = mrYes
      else
        CanGo := True;
    finally
      PackageListFrm.Free;
    end;
  end
  else
    CanGo := False;

  if CanGo then
  begin
    Options.LastDownloadDir := DstDir;
    Options.Changed := True;
    PackageAction := paDownloadTo;
    DoExtract := False;
    if Download(DstDir, DoExtract) = mrOK then
    begin
      if SerializablePackages.ExtractCount > 0 then
      begin
        if DoExtract then
        begin
          DoOpen := False;
          if Extract(DstDir, DstDir, DoOpen) = mrOk then
          begin
            if DoOpen then
              OpenDocument(DstDir);
          end;
        end;
      end;
    end;
  end;
  SerializablePackages.RemoveErrorState;
end;

procedure TMainFrm.Rebuild;
begin
  FFormIsHiden := True;
  Self.Hide;
  IDECommands.ExecuteIDECommand(Self, ecBuildLazarus);
  Self.Show;
  FFormIsHiden := False;
end;

procedure TMainFrm.tbUpdateClick(Sender: TObject);
var
  CanGo: Boolean;
  DoOpen: Boolean;
  DoExtract: Boolean;
  InstallStatus: TInstallStatus;
  NeedToRebuild: Boolean;
begin
  if not IsSomethingChecked(True) then
    Exit;
  CanGo := True;

  if Options.IncompatiblePackages then
  begin
    PackageListFrm := TPackageListFrm.Create(MainFrm);
    try
      PackageListFrm.lbMessage.Caption := rsMainFrm_PackageIncompatible;
      PackageListFrm.PopulateList(3);
      if PackageListFrm.Count > 0 then
        CanGo := PackageListFrm.ShowModal = mrYes
      else
        CanGo := True;
    finally
      PackageListFrm.Free;
    end;
  end;
  if CanGo then
  begin
    NeedToRebuild := False;
    VisualTree.UpdatePackageStates;
    if Options.AlreadyInstalledPackages then
    begin
      PackageListFrm := TPackageListFrm.Create(MainFrm);
      try
        PackageListFrm.lbMessage.Caption := rsMainFrm_PackageUpdate0;
        PackageListFrm.PopulateList(2);
        if PackageListFrm.Count > 0 then
          CanGo := PackageListFrm.ShowModal = mrYes
        else
          CanGo := True;
      finally
        PackageListFrm.Free;
      end;
    end;

    if CanGo then
    begin
      if MessageDlgEx(rsMainFrm_PackageUpdateWarning, mtConfirmation, [mbYes, mbNo], Self) <> mrYes then
        Exit;

      PackageAction := paUpdate;
      VisualTree.UpdatePackageStates;
      if SerializablePackages.DownloadCount > 0 then
      begin
        DoExtract := True;
        CanGo := UpdateP(Options.LocalRepositoryUpdateExpanded, DoExtract) = mrOK;
        VisualTree.UpdatePackageStates;
      end;

      if CanGo then
      begin
        if SerializablePackages.ExtractCount > 0 then
        begin
          DoOpen := False;
          CanGo := Extract(Options.LocalRepositoryUpdateExpanded, Options.LocalRepositoryPackagesExpanded, DoOpen, True) = mrOk;
          VisualTree.UpdatePackageStates;
        end;

        if CanGo then
        begin
          if Options.DeleteZipAfterInstall then
            SerializablePackages.DeleteDownloadedZipFiles;
          if SerializablePackages.InstallCount > 0 then
          begin
            InstallStatus := isFailed;
            if Install(InstallStatus, NeedToRebuild) = mrOk then
            begin
              if (InstallStatus = isSuccess) or (InstallStatus = isPartiallyFailed) then
              begin
                SerializablePackages.MarkRuntimePackages;
                VisualTree.UpdatePackageStates;
                if NeedToRebuild then
                  Rebuild;
              end;
            end;
          end;
        end;
      end;
    end;
  end;
  if not NeedToRebuild then
    SerializablePackages.RemoveErrorState;
end;

procedure TMainFrm.tbUninstallClick(Sender: TObject);

  function IsAtLeastOnePackageInstalled: Boolean;
  var
    I, J: Integer;
    LazarusPackage: TLazarusPackage;
  begin
    Result := False;
    for I := 0 to SerializablePackages.Count - 1 do
    begin
      for J := 0 to SerializablePackages.Items[I].LazarusPackages.Count - 1 do
      begin
        LazarusPackage := TLazarusPackage(SerializablePackages.Items[I].LazarusPackages.Items[J]);
        if (LazarusPackage.Checked) and (LazarusPackage.PackageState = psInstalled) then
        begin
          Result := True;
          Exit;
        end;
      end;
    end;
  end;

  function GetIDEPackage(const AFileName: String): TIDEPackage;
  var
    I: Integer;
    IDEPackge: TIDEPackage;
  begin
    Result := nil;
    for I := 0 to PackageEditingInterface.GetPackageCount - 1 do
    begin
      IDEPackge := PackageEditingInterface.GetPackages(I);
      if CompareText(IDEPackge.Filename, AFileName) = 0 then
      begin
        Result := IDEPackge;
        Break;
      end;
    end;
  end;

var
  I, J: Integer;
  LazarusPackage: TLazarusPackage;
  IDEPackage: TIDEPackage;
  FileName: String;
  NeedToRebuild: Boolean;
begin
  if not IsSomethingChecked(False) then
    Exit;

   if IsAtLeastOnePackageInstalled then
   begin
     if MessageDlgEx(Format(rsMainFrm_rsUninstall, ['             ']), mtInformation, [mbYes, mbNo], Self) <> mrYes then
       Exit;
   end
   else
   begin
     MessageDlgEx(rsMainFrm_rsUninstall_Nothing, mtInformation, [mbOk], Self);
     Exit;
   end;

  NeedToRebuild := False;
  for I := 0 to SerializablePackages.Count - 1 do
  begin
    for J := 0 to SerializablePackages.Items[I].LazarusPackages.Count - 1 do
    begin
      LazarusPackage := TLazarusPackage(SerializablePackages.Items[I].LazarusPackages.Items[J]);
      if (LazarusPackage.Checked) and (LazarusPackage.PackageState = psInstalled) then
      begin
        case LazarusPackage.PackageType of
          lptRunTime, lptRunTimeOnly:
          begin
            FileName := StringReplace(LazarusPackage.Name, '.lpk', '.opkman', [rfIgnoreCase]);
            if FileExists(Options.LocalRepositoryPackagesExpanded + SerializablePackages.Items[I].PackageBaseDir + LazarusPackage.PackageRelativePath + FileName) then
              DeleteFile(Options.LocalRepositoryPackagesExpanded + SerializablePackages.Items[I].PackageBaseDir + LazarusPackage.PackageRelativePath + FileName);
            NeedToRebuild := True;
          end;
          lptDesignTime, lptRunAndDesignTime:
          begin
            IDEPackage := GetIDEPackage(LazarusPackage.InstalledFileName);
            if IDEPackage <> nil then
            begin
              if PackageEditingInterface.UninstallPackage(IDEPackage, False) <> mrOk then
              begin
                NeedToRebuild := False;
                MessageDlgEx(Format(rsMainFrm_rsUninstall_Error, [LazarusPackage.Name]), mtError, [mbOk], Self);
                Exit;
              end
              else
                NeedToRebuild := True;
            end;
          end;
        end;
      end;
    end;
  end;
  if NeedToRebuild then
    Rebuild;
end;

procedure TMainFrm.tbInstallClick(Sender: TObject);
var
  CanGo: Boolean;
  DoExtract: Boolean;
  DoOpen: Boolean;
  InstallStatus: TInstallStatus;
  NeedToRebuild: Boolean;
begin
  if not IsSomethingChecked then
    Exit;

  CanGo := True;
  if Options.IncompatiblePackages then
  begin
    PackageListFrm := TPackageListFrm.Create(MainFrm);
    try
      PackageListFrm.lbMessage.Caption := rsMainFrm_PackageIncompatible;
      PackageListFrm.PopulateList(3);
      if PackageListFrm.Count > 0 then
        CanGo := PackageListFrm.ShowModal = mrYes
      else
        CanGo := True;
    finally
      PackageListFrm.Free;
    end;
  end;

  if CanGo then
  begin
    if Options.AlreadyInstalledPackages then
    begin
      PackageListFrm := TPackageListFrm.Create(MainFrm);
      try
        PackageListFrm.lbMessage.Caption := rsMainFrm_PackageAlreadyInstalled;
        PackageListFrm.PopulateList(0);
        if PackageListFrm.Count > 0 then
          CanGo := PackageListFrm.ShowModal = mrYes
        else
          CanGo := True;
      finally
        PackageListFrm.Free;
      end;
    end;

    if CanGo then
    begin
      PackageAction := paInstall;
      VisualTree.UpdatePackageStates;
      if SerializablePackages.DownloadCount > 0 then
      begin
        DoExtract := True;
        CanGo := Download(Options.LocalRepositoryArchiveExpanded, DoExtract) = mrOK;
        VisualTree.UpdatePackageStates;
      end;

      if CanGo then
      begin
        if SerializablePackages.ExtractCount > 0 then
        begin
          DoOpen := False;
          CanGo := Extract(Options.LocalRepositoryArchiveExpanded, Options.LocalRepositoryPackagesExpanded, DoOpen) = mrOk;
          VisualTree.UpdatePackageStates;
        end;

        if CanGo then
        begin
          if Options.DeleteZipAfterInstall then
            SerializablePackages.DeleteDownloadedZipFiles;
          if SerializablePackages.InstallCount > 0 then
          begin
            InstallStatus := isFailed;
            NeedToRebuild := False;
            if Install(InstallStatus, NeedToRebuild) = mrOk then
            begin
              SerializablePackages.MarkRuntimePackages;
              VisualTree.UpdatePackageStates;
              if (InstallStatus = isSuccess) or (InstallStatus = isPartiallyFailed) then
                if NeedToRebuild then
                  Rebuild;
            end;
          end;
        end;
      end;
    end;
  end;
  if not NeedToRebuild then
    SerializablePackages.RemoveErrorState;
end;

procedure TMainFrm.miFromRepositoryClick(Sender: TObject);
begin
  tbInstallClick(tbInstall);
end;

procedure TMainFrm.miFromExteranlSourceClick(Sender: TObject);
begin
  tbUpdateClick(tbUpdate);
end;


procedure TMainFrm.tbOpenRepoClick(Sender: TObject);
begin
  OpenDocument(Options.LocalRepositoryPackagesExpanded);
end;

procedure TMainFrm.tbCleanUpClick(Sender: TObject);
var
  Cnt: Integer;
begin
  if MessageDlgEx(rsMainFrm_rsRepositoryCleanup0, mtInformation, [mbYes, mbNo], Self) = mrYes then
  begin
    Screen.BeginWaitCursor;
    try
      Cnt := SerializablePackages.Cleanup;
    finally
      Screen.EndWaitCursor;
    end;
    MessageDlgEx(Format(rsMainFrm_rsRepositoryCleanup1, [IntToStr(Cnt)]),
      mtInformation, [mbOk], Self);
  end;
end;

procedure TMainFrm.tbCreateClick(Sender: TObject);
begin
  CreateRepositoryPackagesFrm := TCreateRepositoryPackagesFrm.Create(MainFrm);
  try
    CreateRepositoryPackagesFrm.SetType(0);
    CreateRepositoryPackagesFrm.ShowModal;
  finally
    CreateRepositoryPackagesFrm.Free;
  end;
end;

procedure TMainFrm.pnToolBarResize(Sender: TObject);
var
  I: Integer;
  W: Integer;
begin
  W := 0;
  for I := 0 to tbButtons.ButtonCount - 1 do
    if tbButtons.Buttons[I].Visible then
      W := W + tbButtons.Buttons[I].Width;
  tbButtons.Width := W + 2;
  if tbButtons.Width < 450 then
    tbButtons.Width := 450;
  tbButtons.Left := (pnToolBar.Width - tbButtons.Width) div 2;
  tbButtons.Height := tbButtons.Buttons[0].Height;
  tbButtons.Top := (pnToolBar.Height - tbButtons.Height) div 2;
end;

procedure TMainFrm.miCreateRepositoryPackageClick(Sender: TObject);
begin
  tbCreateClick(tbCreate);
end;

procedure TMainFrm.miCreateJSONForUpdatesClick(Sender: TObject);
var
  Msg: String;
begin
  case VisualTree.GetCheckedRepositoryPackages of
    0: Msg := rsCreateJSONForUpdatesFrm_Message0;
    1: Msg := '';
    2: Msg := rsCreateJSONForUpdatesFrm_Message1;
  end;
  if Msg <> '' then
  begin
    MessageDlgEx(Msg, mtInformation, [mbOk], MainFrm);
    Exit;
  end;
  VisualTree.GetPackageList;
  CreateJSONForUpdatesFrm := TCreateJSONForUpdatesFrm.Create(MainFrm);
  try
    CreateJSONForUpdatesFrm.PopluateTree;
    CreateJSONForUpdatesFrm.ShowModal;
  finally
    CreateJSONForUpdatesFrm.Free;
  end;
end;

procedure TMainFrm.miCreateRepositoryClick(Sender: TObject);
var
  CreateRepositoryFrm: TCreateRepositoryFrm;
begin
  CreateRepositoryFrm := TCreateRepositoryFrm.Create(MainFrm);
  try
    CreateRepositoryFrm.ShowModal;
  finally
    CreateRepositoryFrm.Free;
  end;
end;

procedure TMainFrm.miCopyToClpBrdClick(Sender: TObject);
var
  Data: PData;
  Node: PVirtualNode;
begin
  Node := VisualTree.VST.GetFirstSelected;
  if Node <> nil then
  begin
    Data := VisualTree.VST.GetNodeData(Node);
    case Data^.DataType of
      17: Clipboard.AsText := Data^.HomePageURL;
      18: Clipboard.AsText := Data^.DownloadURL;
    end;
  end;
end;

procedure TMainFrm.FormKeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
  if ssCtrl in Shift then
  begin
    if (Key = 82) and (tbRefresh.Enabled) then
      tbRefreshClick(tbRefresh)
    else if (Key = 68) and (tbDownload.Enabled) then
      tbDownloadClick(tbDownload)
    else if (Key = 73) and (tbInstall.Enabled) then
      tbInstallClick(tbInstall)
    else if (Key = 69) and (tbUpdate.Enabled) then
      tbUpdateClick(tbUpdate)
    else if (Key = 85) and (tbUninstall.Enabled) then
      tbUninstallClick(tbUninstall)
    else if (Key = 76) and (tbOpenRepo.Enabled) then
      tbOpenRepoClick(tbOpenRepo)
    else if (Key = 67) and (tbCleanUp.Enabled) then
      tbCleanUpClick(tbCleanUp)
    else if (Key = 80) and (tbInstall.Enabled) then
      miCreateRepositoryPackageClick(miCreateRepositoryPackage)
    else if (Key = 79) and (tbOptions.Enabled) then
      tbOptionsClick(tbOptions)
    else if (Key = 72) and (tbHelp.Enabled) then
      tbHelpClick(tbHelp);
  end;
end;

procedure TMainFrm.miResetRatingClick(Sender: TObject);
var
  Data: PData;
  Node: PVirtualNode;
  MetaPkg: TMetaPackage;
begin
  if MessageDlgEx(rsMainFrm_miResetRating + '?', mtConfirmation, [mbYes, mbNo], Self) = mrNo then
    Exit;
  Node := VisualTree.VST.GetFirstSelected;
  if Node <> nil then
  begin
    Data := VisualTree.VST.GetNodeData(Node);
    if Data^.DataType = 1 then
    begin
      Data^.Rating := 0;
      MetaPkg := SerializablePackages.FindMetaPackage(Data^.PackageName, fpbPackageName);
      if MetaPkg <> nil then
        MetaPkg.Rating := 0;
      VisualTree.VST.ReinitNode(Node, False);
      VisualTree.VST.RepaintNode(Node);
    end;
  end;
end;

procedure TMainFrm.miSaveCheckedClick(Sender: TObject);
var
  Node: PVirtualNode;
  Data: PData;
  SL: TStringList;
begin
  SD.DefaultExt := '.*.opm';
  SD.Filter := '*.opm|*.opm';

  SL := TStringList.Create;
  try
    Node := VisualTree.VST.GetFirst;
    while Node <> nil do
    begin
      if VisualTree.VST.CheckState[Node] = csCheckedNormal then
      begin
        Data := VisualTree.VST.GetNodeData(Node);
        if (Data^.DataType = 2) then
          SL.Add(Data^.LazarusPackageName);
      end;
      Node := VisualTree.VST.GetNext(Node);
    end;
    if Trim(SL.Text) = '' then
      MessageDlgEx(rsMainFrm_rsMessageNothingChacked, mtInformation, [mbOk], Self)
    else
      if SD.Execute then
      begin
         SL.SaveToFile(SD.FileName);
         MessageDlgEx(Format(rsMainFrm_resMessageChecksSaved, [IntToStr(SL.Count)]), mtInformation, [mbOk], Self)
      end;
  finally
    SL.Free;
  end;
end;

procedure TMainFrm.miSaveInstalledClick(Sender: TObject);
var
  Node: PVirtualNode;
  Data: PData;
  SL: TStringList;
begin
  SD.DefaultExt := '.*.opm';
  SD.Filter := '*.opm|*.opm';

  SL := TStringList.Create;
  try
    Node := VisualTree.VST.GetFirst;
    while Node <> nil do
    begin
      Data := VisualTree.VST.GetNodeData(Node);
      if (Data^.DataType = 2) and (Data^.InstalledVersion <> '') then
        SL.Add(Data^.LazarusPackageName);
      Node := VisualTree.VST.GetNext(Node);
    end;
    if Trim(SL.Text) = '' then
      MessageDlgEx(rsMainFrm_rsMessageNothingInstalled, mtInformation, [mbOk], Self)
    else
      if SD.Execute then
      begin
         SL.SaveToFile(SD.FileName);
         MessageDlgEx(Format(rsMainFrm_resMessageChecksSaved, [IntToStr(SL.Count)]), mtInformation, [mbOk], Self)
      end;
  finally
    SL.Free;
  end;
end;

procedure TMainFrm.miLoadClick(Sender: TObject);
var
  SL: TStringList;
  TrimmedS: String;
  I, CheckCount: Integer;
  Node: PVirtualNode;
  Data: PData;
begin
  if OD.Execute then
  begin
    CheckCount := 0;
    SL := TStringList.Create;
    try
      SL.LoadFromFile(OD.FileName);
      for I := 0 to SL.Count - 1 do
      begin
        TrimmedS := Trim(SL.Strings[I]);
        Node := VisualTree.VST.GetFirst;
        while Node <> nil do
        begin
          Data := VisualTree.VST.GetNodeData(Node);
          if CompareText(Trim(Data^.LazarusPackageName), TrimmedS) = 0 then
          begin
            VisualTree.VST.CheckState[Node] := csCheckedNormal;
            Inc(CheckCount);
            Break;
          end;
          Node := VisualTree.VST.GetNext(Node);
        end;
      end;
    finally
      SL.Free;
    end;
    if CheckCount > 0 then
       MessageDlgEx(Format(rsMainFrm_resMessageChecksLoaded, [IntToStr(CheckCount)]), mtInformation, [mbOk], Self)
  end;
end;


procedure TMainFrm.pnMainResize(Sender: TObject);
begin
  pnMessage.Left := (pnMain.Width - pnMessage.Width) div 2;
  pnMessage.Top := (pnMain.Height - pnMessage.Height) div 2;
end;

procedure TMainFrm.miJSONShowClick(Sender: TObject);
begin
  if not mJSON.Visible then
  begin
    VisualTree.VST.Visible := False;
    pnTop.Visible := False;
    pnToolBar.Visible := False;
    pnReturn.Height := 50;
    pnReturn.Visible := True;
    mJSON.Visible := True;
    mJSON.BringToFront;
  end
  else
  begin
    mJSON.SendToBack;
    mJSON.Visible := False;
    pnReturn.Visible := False;
    pnTop.Visible := True;
    pnToolBar.Visible := True;
    VisualTree.VST.Visible := True;
  end;
end;

procedure TMainFrm.bReturnClick(Sender: TObject);
begin
  miJSONShowClick(miJSONShow);
end;

procedure TMainFrm.FormCloseQuery(Sender: TObject; var CanClose: boolean);
begin
  if Assigned(Updates) then
  begin
    Updates.StopUpdate;
    Updates.Terminate;
    while Assigned(Updates) do
      CheckSynchronize(100); // wait for update thread to terminate
    // Remains the slightest chance of a mem leak, since the update thread needs still enough cpu time to finish running the destructor
  end;
end;


procedure TMainFrm.miNameAscClick(Sender: TObject);
var
  JSON: TJSONStringType;
begin
  JSON := '';
  case (Sender as TMenuItem).Tag of
    0: SerializablePackages.Sort(stName, soAscendent);
    1: SerializablePackages.Sort(stName, soDescendent);
    2: SerializablePackages.Sort(stDate, soAscendent);
    3: SerializablePackages.Sort(stDate, soDescendent);
  end;
  SerializablePackages.PackagesToJSON(JSON);
  mJSON.Lines.BeginUpdate;
  try
    mJSON.Clear;
    mJSON.Text := JSON;
  finally
    mJSON.Lines.EndUpdate;
  end;
end;

procedure TMainFrm.miSaveToFileClick(Sender: TObject);
var
  JSON: TJSONStringType;
  Ms: TMemoryStream;
begin
  SD.DefaultExt := '.*.json';
  SD.Filter := '*.json|*.json';
  if SD.Execute then
  begin
    JSON := '';
    SerializablePackages.PackagesToJSON(JSON);
    Ms := TMemoryStream.Create;
    try
      Ms.Write(Pointer(JSON)^, Length(JSON));
      Ms.Position := 0;
      Ms.SaveToFile(SD.FileName);
    finally
      Ms.Free;
    end;
  end;
end;

procedure TMainFrm.pnReturnResize(Sender: TObject);
begin
  bReturn.Left := (pnReturn.Width - bReturn.Width) div 2 ;
  bReturn.Top := (pnReturn.Height - bReturn.Height) div 2;
end;

procedure TMainFrm.SetupControls;
var
  I: Integer;
begin
  Caption := rsLazarusPackageManager;

  cbFilterBy.Clear;
  cbFilterBy.Items.Add(rsMainFrm_VSTHeaderColumn_PackageName);
  cbFilterBy.Items.Add(rsMainFrm_VSTHeaderColumn_LazarusPackage);
  cbFilterBy.Items.Add(rsMainFrm_VSTText_PackageCategory);
  cbFilterBy.Items.Add(rsMainFrm_VSTText_PackageStatus);
  cbFilterBy.Items.Add(rsMainFrm_VSTText_Version);
  cbFilterBy.Items.Add(rsMainFrm_VSTText_Description);
  cbFilterBy.Items.Add(rsMainFrm_VSTText_Author);
  cbFilterBy.Items.Add(rsMainFrm_VSTText_LazCompatibility);
  cbFilterBy.Items.Add(rsMainFrm_VSTText_FPCCompatibility);
  cbFilterBy.Items.Add(rsMainFrm_VSTText_SupportedWidgetsets);
  cbFilterBy.Items.Add(rsMainFrm_VSTText_Packagetype);
  cbFilterBy.Items.Add(rsMainFrm_VSTText_Dependecies);
  cbFilterBy.Items.Add(rsMainFrm_VSTText_License);
  cbFilterBy.ItemIndex := 0;

  cbPackageType.Clear;
  cbPackageType.Items.Add('');
  cbPackageType.Items.Add(rsMainFrm_VSTText_PackageType2);
  cbPackageType.Items.Add(rsMainFrm_VSTText_PackageType1);
  cbPackageType.Items.Add(rsMainFrm_VSTText_PackageType0);
  cbPackageType.Items.Add(rsMainFrm_VSTText_PackageType3);

  cbPackageState.Clear;
  cbPackageState.Items.Add('');
  cbPackageState.Items.Add(rsMainFrm_VSTText_PackageState0);
  cbPackageState.Items.Add(rsMainFrm_VSTText_PackageState1);
  cbPackageState.Items.Add(rsMainFrm_VSTText_PackageState2);
  cbPackageState.Items.Add(rsMainFrm_VSTText_PackageState3);

  cbPackageCategory.Clear;
  cbPackageCategory.Items.Add('');
  for I := 0 to MaxCategories - 1 do
  cbPackageCategory.Items.Add(Categories[I]);

  tbRefresh.Caption := rsMainFrm_TBRefresh_Caption;
  tbRefresh.Hint := rsMainFrm_TBRefresh_Hint;
  tbDownload.Caption := rsMainFrm_TBDownload_Caption;
  tbDownload.Hint := rsMainFrm_TBDownload_Hint;
  tbInstall.Caption := rsMainFrm_TBInstall_Caption;
  tbInstall.Hint := rsMainFrm_TBInstall_Hint;
  tbUpdate.Caption := rsMainFrm_TBUpdate_Caption;
  tbUpdate.Hint := rsMainFrm_TBUpdate_Hint;
  tbUninstall.Caption := rsMainFrm_TBUninstall_Caption;
  tbUninstall.Hint := rsMainFrm_TBUninstall_Hint;
  tbOpenRepo.Caption := rsMainFrm_TBOpenRepo_Caption;
  tbOpenRepo.Hint := rsMainFrm_TBOpenRepo_Hint;
  tbCleanUp.Caption := rsMainFrm_TBCleanUp_Caption;
  tbCleanUp.Hint := rsMainFrm_TBCleanUp_Hint;
  tbCreate.Caption := rsMainFrm_TBRepository_Caption;
  tbCreate.Hint := rsMainFrm_TBRepository_Hint;
  tbOptions.Caption := rsMainFrm_TBOptions_Caption;
  tbOptions.Hint := rsMainFrm_TBOptions_Hint;
  tbHelp.Caption := rsMainFrm_TBHelp_Caption;
  tbHelp.Hint := rsMainFrm_TBHelp_Hint;

  miFromRepository.Caption := rsMainFrm_VSTHeaderColumn_Repository;
  miFromRepository.Hint := rsMainFrm_VSTHeaderColumn_Repository_Hint;
  miFromExteranlSource.Caption := rsMainFrm_VSTHeaderColumn_Update;
  miFromExteranlSource.Hint := rsMainFrm_VSTHeaderColumn_Update_Hint;
  miCreateRepositoryPackage.Caption := rsMainFrm_miCreateRepositoryPackage;
  miCreateJSONForUpdates.Caption := rsMainFrm_miCreateJSONForUpdates;
  miCreateRepository.Caption := rsMainFrm_miCreateRepository;
  miJSONShow.Caption := rsMainFrm_miJSONShow;
  miJSONHide.Caption := rsMainFrm_miJSONHide;
  miJSONSort.Caption := rsMainFrm_miJSONSort;
  miByName.Caption := rsMainFrm_miByName;
  miNameAsc.Caption := rsMainFrm_miAscendent;
  miNameDsc.Caption := rsMainFrm_miDescendent;
  miByDate.Caption := rsMainFrm_miByDate;
  miDateAsc.Caption := rsMainFrm_miAscendent;
  miDateDsc.Caption := rsMainFrm_miDescendent;
  miSaveToFile.Caption := rsMainFrm_miSaveToFile;
  miCopyToClpBrd.Caption := rsMainFrm_miCopyToClpBrd;
  miResetRating.Caption := rsMainFrm_miResetRating;
  miSave.Caption := rsMainFrm_miSave;
  miSaveChecked.Caption := rsMainFrm_miSaveChecked;
  miSaveInstalled.Caption := rsMainFrm_miLoadInstalled;
  miLoad.Caption := rsMainFrm_miLoad;
  edFilter.Hint := rsMainFrm_edFilter_Hint;
  spClear.Hint := rsMainFrm_spClear_Hint;
  cbFilterBy.Top := (pnTop.Height - cbFilterBy.Height) div 2;
  pnFilter.Height := cbFilterBy.Height;
  pnFilter.Top := (pnTop.Height - pnFilter.Height) div 2;
  cbPackageState.Top := (pnTop.Height - cbPackageState.Height) div 2;
  cbPackageType.Top := (pnTop.Height - cbPackageType.Height) div 2;
  cbPackageCategory.Top := (pnTop.Height - cbPackageCategory.Height) div 2;
  cbAll.Top := (pnTop.Height - cbAll.Height) div 2;
  cbAll.Hint := rsMainFrm_cbAll_Hint;
  spExpand.Top:= (pnTop.Height - spExpand.Height + 1) div 2;
  spExpand.Hint := rsMainFrm_spExpand_Hint;
  spCollapse.Top:= (pnTop.Height - spCollapse.Height + 1) div 2;
  spCollapse.Hint := rsMainFrm_spCollapse_Hint;
  cbAll.Caption := rsMainFrm_cbAll_Caption;
  lbFilterBy.Top := cbFilterBy.Top + (cbFilterBy.Height - lbFilterBy.Height) div 2;
  lbFilterBy.Caption := rsMainFrm_lbFilter_Caption;
  cbFilterBy.Hint := rsMainFrm_cbFilterBy_Hint;
  bReturn.Caption := rsMainFrm_bReturn_Caption;
  cbPackageCategory.Visible := False;
  cbPackageType.Visible := False;
  cbPackageState.Visible := False;
end;

procedure TMainFrm.SetupColors;
begin
  VisualTree.SetupColors;
  if not Options.UseDefaultTheme then
  begin
    Self.Color := clBtnFace;
    pnMain.Color := clBtnFace;
    pnMessage.Color := clBtnFace;
    pnTop.Color := clBtnFace;
    mJSON.Color := clBtnFace;
  end
  else
  begin
    pnMain.Color := VisualTree.VST.GetDefaultColor(dctBrush);
    pnMessage.Color := VisualTree.VST.GetDefaultColor(dctBrush);
  end;
end;

end.


















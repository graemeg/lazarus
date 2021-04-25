{
 /***************************************************************************
                          mainbar.pp  -  Toolbar
                          ----------------------
  TMainIDEBar is the main window of the IDE, containing the menu and the
  component palette.

 ***************************************************************************/

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
unit MainBar;

{$mode objfpc}{$H+}

interface

{$I ide.inc}

uses
{$IFDEF IDE_MEM_CHECK}
  MemCheck,
{$ENDIF}
  Classes, SysUtils, Math,
  // LCL
  Forms, Controls, Menus, ComCtrls, ExtCtrls, LMessages, LCLIntf, LCLType, LCLProc,
  // LazUtils
  LazFileCache,
  // IDEIntf
  MenuIntf, LazIDEIntf, IDEWindowIntf, IDEImagesIntf, ComponentReg,
  // IDE
  EnvironmentOpts, LazarusIDEStrConsts, IdeCoolbarData;

type
  { TMainIDEBar }

  TMainIDEBar = class(TForm)
  private
    OptionsPopupMenu: TPopupMenu;
    FMainOwningComponent: TComponent;
    FOldWindowState: TWindowState;
    FOnActive: TNotifyEvent;
    procedure CreatePopupMenus(TheOwner: TComponent);
    function CalcMainIDEHeight: Integer;
    function CalcNonClientHeight: Integer;
    function FindCompScrollBox: TScrollBox;
  protected
    procedure DoActive;
    procedure WndProc(var Message: TLMessage); override;
    procedure Resizing(State: TWindowState); override;
  public
    ApplicationIsActivate: boolean;
    LastCompPaletteForm: TCustomForm;
    //Coolbar and PopUpMenus
    CoolBar: TCoolBar;
    OptionsMenuItem: TMenuItem;
    NewUFSetDefaultMenuItem: TMenuItem;
    ComponentPageControl: TPageControl; // component palette
    //GlobalMouseSpeedButton: TSpeedButton; <- what is this
    MainSplitter: TSplitter;        // splitter between the Coolbar and MainMenu
    // MainMenu
    mnuMainMenu: TMainMenu;
    //mnuMain: TIDEMenuSection;

    // file menu
    //mnuFile: TIDEMenuSection;
      //itmFileNew: TIDEMenuSection;
        itmFileNewUnit: TIDEMenuCommand;
        itmFileNewForm: TIDEMenuCommand;
        itmFileNewOther: TIDEMenuCommand;
      //itmFileOpenSave: TIDEMenuSection;
        itmFileOpen: TIDEMenuCommand;
        itmFileRevert: TIDEMenuCommand;
        itmFileOpenUnit: TIDEMenuCommand;
        //itmFileRecentOpen: TIDEMenuSection;
        itmFileSave: TIDEMenuCommand;
        itmFileSaveAs: TIDEMenuCommand;
        itmFileSaveAll: TIDEMenuCommand;
        itmFileExportHtml: TIDEMenuCommand;
        itmFileClose: TIDEMenuCommand;
        itmFileCloseAll: TIDEMenuCommand;
      //itmFileDirectories: TIDEMenuSection;
        itmFileCleanDirectory: TIDEMenuCommand;
      //itmFileIDEStart: TIDEMenuSection;
        itmFileRestart: TIDEMenuCommand;
        itmFileQuit: TIDEMenuCommand;

    // edit menu
    //mnuEdit: TIDEMenuSection;
      //itmEditReUndo: TIDEMenuSection;
        itmEditUndo: TIDEMenuCommand;
        itmEditRedo: TIDEMenuCommand;
      //itmEditClipboard: TIDEMenuSection;
        itmEditCut: TIDEMenuCommand;
        itmEditCopy: TIDEMenuCommand;
        itmEditPaste: TIDEMenuCommand;
        itmEditMultiPaste: TIDEMenuCommand;
      //itmEditSelect: TIDEMenuSection;
        itmEditSelectAll: TIDEMenuCommand;
        itmEditSelectToBrace: TIDEMenuCommand;
        itmEditSelectCodeBlock: TIDEMenuCommand;
        itmEditSelectWord: TIDEMenuCommand;
        itmEditSelectLine: TIDEMenuCommand;
        itmEditSelectParagraph: TIDEMenuCommand;
      //itmEditBlockActions: TIDEMenuSection;
        itmEditIndentBlock: TIDEMenuCommand;
        itmEditUnindentBlock: TIDEMenuCommand;
        itmEditUpperCaseBlock: TIDEMenuCommand;
        itmEditLowerCaseBlock: TIDEMenuCommand;
        itmEditSwapCaseBlock: TIDEMenuCommand;
        itmEditSortBlock: TIDEMenuCommand;
        itmEditTabsToSpacesBlock: TIDEMenuCommand;
        itmEditSelectionBreakLines: TIDEMenuCommand;
      //itmEditInsertions: TIDEMenuSection;
        itmEditInsertCharacter: TIDEMenuCommand;

    // search menu
    //mnuSearch: TIDEMenuSection;
      //itmSearchFindReplace: TIDEMenuSection;
        itmSearchFind: TIDEMenuCommand;
        itmSearchFindNext: TIDEMenuCommand;
        itmSearchFindPrevious: TIDEMenuCommand;
        itmSearchFindInFiles: TIDEMenuCommand;
        itmSearchReplace: TIDEMenuCommand;
        itmIncrementalFind: TIDEMenuCommand;
      //itmJumpings: TIDEMenuSection;
        itmGotoLine: TIDEMenuCommand;
        itmJumpBack: TIDEMenuCommand;
        itmJumpForward: TIDEMenuCommand;
        itmAddJumpPoint: TIDEMenuCommand;
        itmJumpToNextError: TIDEMenuCommand;
        itmJumpToPrevError: TIDEMenuCommand;
        itmJumpToInterface: TIDEMenuCommand;
        itmJumpToInterfaceUses: TIDEMenuCommand;
        itmJumpToImplementation: TIDEMenuCommand;
        itmJumpToImplementationUses: TIDEMenuCommand;
        itmJumpToInitialization: TIDEMenuCommand;
      //itmBookmarks: TIDEMenuSection;
        itmSetFreeBookmark: TIDEMenuCommand;
        itmJumpToNextBookmark: TIDEMenuCommand;
        itmJumpToPrevBookmark: TIDEMenuCommand;
      //itmCodeToolSearches: TIDEMenuSection;
        itmFindDeclaration: TIDEMenuCommand;
        itmFindBlockOtherEnd: TIDEMenuCommand;
        itmFindBlockStart: TIDEMenuCommand;
        itmOpenFileAtCursor: TIDEMenuCommand;
        itmGotoIncludeDirective: TIDEMenuCommand;
        itmSearchFindIdentifierRefs: TIDEMenuCommand;
        itmSearchProcedureList: TIDEMenuCommand;

    // view menu
    //mnuView: TIDEMenuSection;
      //itmViewMainWindows: TIDEMenuSection;
        itmViewToggleFormUnit: TIDEMenuCommand;
        itmViewInspector: TIDEMenuCommand;
        itmViewSourceEditor: TIDEMenuCommand;
        itmViewCodeExplorer: TIDEMenuCommand;
        itmViewFPDocEditor: TIDEMenuCommand;
        itmViewCodeBrowser: TIDEMenuCommand;
        itmSourceUnitDependencies: TIDEMenuCommand;
        itmViewRestrictionBrowser: TIDEMenuCommand;
        itmViewComponents: TIDEMenuCommand;
        itmJumpHistory: TIDEMenuCommand;
        itmMacroListView: TIDEMenuCommand;
      //itmViewSecondaryWindows: TIDEMenuSection;
        itmViewAnchorEditor: TIDEMenuCommand;
        itmViewTabOrder: TIDEMenuCommand;
        itmViewMessage: TIDEMenuCommand;
        itmViewSearchResults: TIDEMenuCommand;
        //itmViewDebugWindows: TIDEMenuSection;
          itmViewWatches: TIDEMenuCommand;
          itmViewBreakpoints: TIDEMenuCommand;
          itmViewLocals: TIDEMenuCommand;
          itmViewRegisters: TIDEMenuCommand;
          itmViewCallStack: TIDEMenuCommand;
          itmViewThreads: TIDEMenuCommand;
          itmViewAssembler: TIDEMenuCommand;
          itmViewDebugOutput: TIDEMenuCommand;
          itmViewDebugEvents: TIDEMenuCommand;
          itmViewPseudoTerminal: TIDEMenuCommand;
          itmViewDbgHistory: TIDEMenuCommand;
        //itmViewIDEInternalsWindows: TIDEMenuSection;
          itmViewFPCInfo: TIDEMenuCommand;
          itmViewIDEInfo: TIDEMenuCommand;
          itmViewNeedBuild: TIDEMenuCommand;
          itmSearchInFPDocFiles: TIDEMenuCommand;

    // source menu
    //mnuSource: TIDEMenuSection;
      //itmSourceBlockActions: TIDEMenuSection;
        itmSourceCommentBlock: TIDEMenuCommand;
        itmSourceUncommentBlock: TIDEMenuCommand;
        itmSourceToggleComment: TIDEMenuCommand;
        itmSourceEncloseBlock: TIDEMenuCommand;
        itmSourceEncloseInIFDEF: TIDEMenuCommand;
        itmSourceCompleteCodeInteractive: TIDEMenuCommand;
        itmSourceUseUnit: TIDEMenuCommand;
      //itmSourceCodeToolChecks: TIDEMenuSection;
        itmSourceSyntaxCheck: TIDEMenuCommand;
        itmSourceGuessUnclosedBlock: TIDEMenuCommand;
        {$IFDEF GuessMisplacedIfdef}
        itmSourceGuessMisplacedIFDEF: TIDEMenuCommand;
        {$ENDIF}
      //itmSourceInsertCVSKeyWord: TIDEMenuSection;
        itmSourceInsertCVSAuthor: TIDEMenuCommand;
        itmSourceInsertCVSDate: TIDEMenuCommand;
        itmSourceInsertCVSHeader: TIDEMenuCommand;
        itmSourceInsertCVSID: TIDEMenuCommand;
        itmSourceInsertCVSLog: TIDEMenuCommand;
        itmSourceInsertCVSName: TIDEMenuCommand;
        itmSourceInsertCVSRevision: TIDEMenuCommand;
        itmSourceInsertCVSSource: TIDEMenuCommand;
      //itmSourceInsertGeneral: TIDEMenuSection;
        itmSourceInsertGPLNotice: TIDEMenuCommand;
        itmSourceInsertGPLNoticeTranslated: TIDEMenuCommand;
        itmSourceInsertLGPLNotice: TIDEMenuCommand;
        itmSourceInsertLGPLNoticeTranslated: TIDEMenuCommand;
        itmSourceInsertModifiedLGPLNotice: TIDEMenuCommand;
        itmSourceInsertModifiedLGPLNoticeTranslated: TIDEMenuCommand;
        itmSourceInsertMITNotice: TIDEMenuCommand;
        itmSourceInsertMITNoticeTranslated: TIDEMenuCommand;
        itmSourceInsertUsername: TIDEMenuCommand;
        itmSourceInsertDateTime: TIDEMenuCommand;
        itmSourceInsertChangeLogEntry: TIDEMenuCommand;
        itmSourceInsertGUID: TIDEMenuCommand;
        itmSourceInsertTodo: TIDEMenuCommand;
      itmSourceInsertFilename: TIDEMenuCommand;
    // itmSourceTools
      itmSourceUnitInfo: TIDEMenuCommand;

    // refactor menu
    //mnuRefactor: TIDEMenuSection;
      //itmRefactorCodeTools: TIDEMenuSection;
        itmRefactorRenameIdentifier: TIDEMenuCommand;
        itmRefactorExtractProc: TIDEMenuCommand;
        itmRefactorInvertAssignment: TIDEMenuCommand;
      //itmRefactorAdvanced: TIDEMenuSection;
        itmRefactorShowAbstractMethods: TIDEMenuCommand;
        itmRefactorShowEmptyMethods: TIDEMenuCommand;
        itmRefactorShowUnusedUnits: TIDEMenuCommand;
        itmRefactorFindOverloads: TIDEMenuCommand;
      //itmRefactorTools: TIDEMenuSection;
        itmRefactorMakeResourceString: TIDEMenuCommand;

    // project menu
    //mnuProject: TIDEMenuSection;
      //itmProjectNewSection: TIDEMenuSection;
        itmProjectNew: TIDEMenuCommand;
        itmProjectNewFromFile: TIDEMenuCommand;
      //itmProjectOpenSection: TIDEMenuSection;
        itmProjectOpen: TIDEMenuCommand;
        //itmProjectRecentOpen: TIDEMenuSection;
        itmProjectClose: TIDEMenuCommand;
      //itmProjectSaveSection: TIDEMenuSection;
        itmProjectSave: TIDEMenuCommand;
        itmProjectSaveAs: TIDEMenuCommand;
        itmProjectResaveFormsWithI18n: TIDEMenuCommand;
        itmProjectPublish: TIDEMenuCommand;
      //itmProjectWindowSection: TIDEMenuSection;
        itmProjectInspector: TIDEMenuCommand;
        itmProjectOptions: TIDEMenuCommand;
        //itmProjectCompilerOptions: TIDEMenuCommand;
      //itmProjectAddRemoveSection: TIDEMenuSection;
        itmProjectAddTo: TIDEMenuCommand;
        itmProjectRemoveFrom: TIDEMenuCommand;
        itmProjectViewUnits: TIDEMenuCommand;
        itmProjectViewForms: TIDEMenuCommand;
        itmProjectViewSource: TIDEMenuCommand;

    // run menu
    //mnuRun: TIDEMenuSection;
      //itmRunBuilding: TIDEMenuSection;
        itmRunMenuCompile: TIDEMenuCommand;
        itmRunMenuBuild: TIDEMenuCommand;
        itmRunMenuQuickCompile: TIDEMenuCommand;
        itmRunMenuCleanUpAndBuild: TIDEMenuCommand;
        itmRunMenuBuildManyModes: TIDEMenuCommand;
        itmRunMenuAbortBuild: TIDEMenuCommand;
      //itmRunnning: TIDEMenuSection;
        itmRunMenuRunWithoutDebugging: TIDEMenuCommand;
        itmRunMenuRun: TIDEMenuCommand;
        itmRunMenuPause: TIDEMenuCommand;
        itmRunMenuShowExecutionPoint: TIDEMenuCommand;
        itmRunMenuStepInto: TIDEMenuCommand;
        itmRunMenuStepOver: TIDEMenuCommand;
        itmRunMenuStepOut: TIDEMenuCommand;
        itmRunMenuStepToCursor: TIDEMenuCommand;
        itmRunMenuRunToCursor: TIDEMenuCommand;
        itmRunMenuStop: TIDEMenuCommand;
        itmRunMenuAttach: TIDEMenuCommand;
        itmRunMenuDetach: TIDEMenuCommand;
        itmRunMenuRunParameters: TIDEMenuCommand;
        itmRunMenuResetDebugger: TIDEMenuCommand;
      //itmRunBuildingFile: TIDEMenuSection;
        itmRunMenuBuildFile: TIDEMenuCommand;
        itmRunMenuRunFile: TIDEMenuCommand;
        itmRunMenuConfigBuildFile: TIDEMenuCommand;
      //itmRunDebugging: TIDEMenuSection;
        itmRunMenuInspect: TIDEMenuCommand;
        itmRunMenuEvaluate: TIDEMenuCommand;
        itmRunMenuAddWatch: TIDEMenuCommand;
        //itmRunMenuAddBreakpoint: TIDEMenuSection;
          itmRunMenuAddBpSource: TIDEMenuCommand;
          itmRunMenuAddBpAddress: TIDEMenuCommand;
          itmRunMenuAddBpWatchPoint: TIDEMenuCommand;

    // packages menu
    //mnuComponents: TIDEMenuSection;
      //itmPkgOpening: TIDEMenuSection;
        itmPkgNewPackage: TIDEMenuCommand;
        itmPkgOpenLoadedPackage: TIDEMenuCommand;
        itmPkgOpenPackageFile: TIDEMenuCommand;
        itmPkgOpenPackageOfCurUnit: TIDEMenuCommand;
        //itmPkgOpenRecent: TIDEMenuSection;
      //itmPkgUnits: TIDEMenuSection;
        itmPkgAddCurFileToPkg: TIDEMenuCommand;
        itmPkgAddNewComponentToPkg: TIDEMenuCommand;
      //itmPkgGraphSection: TIDEMenuSection;
        itmPkgPkgGraph: TIDEMenuCommand;
        itmPkgPackageLinks: TIDEMenuCommand;
        itmPkgEditInstallPkgs: TIDEMenuCommand;

    // tools menu
    //mnuTools: TIDEMenuSection;
      //itmOptionsDialogs: TIDEMenuSection;
        itmEnvGeneralOptions: TIDEMenuCommand;
        itmToolRescanFPCSrcDir: TIDEMenuCommand;
        itmEnvCodeTemplates: TIDEMenuCommand;
        itmEnvCodeToolsDefinesEditor: TIDEMenuCommand;
      //itmCustomTools: TIDEMenuSection;
        itmToolConfigure: TIDEMenuCommand;
      //itmSecondaryTools: TIDEMenuSection;
        itmToolManageDesktops: TIDEMenuCommand;
        itmToolManageExamples: TIDEMenuCommand;
        itmToolDiff: TIDEMenuCommand;
      //itmDelphiConversion: TIDEMenuSection;
        itmToolCheckLFM: TIDEMenuCommand;
        itmToolConvertDelphiUnit: TIDEMenuCommand;
        itmToolConvertDelphiProject: TIDEMenuCommand;
        itmToolConvertDelphiPackage: TIDEMenuCommand;
        itmToolConvertDFMtoLFM: TIDEMenuCommand;
        itmToolConvertEncoding: TIDEMenuCommand;
      //itmBuildingLazarus: TIDEMenuSection;
        itmToolBuildLazarus: TIDEMenuCommand;
        itmToolConfigureBuildLazarus: TIDEMenuCommand;

    // windows menu
    //mnuWindow: TIDEMenuSection;
      //itmWindowManagers: TIDEMenuSection;
        itmWindowManager: TIDEMenuCommand;

    // help menu
    //mnuHelp: TIDEMenuSection;
      //itmOnlineHelps: TIDEMenuSection;
        itmHelpOnlineHelp: TIDEMenuCommand;
        itmHelpReportingBug: TIDEMenuCommand;
        //itmHelpConfigureHelp: TIDEMenuCommand;
      //itmInfoHelps: TIDEMenuSection;
        itmHelpAboutLazarus: TIDEMenuCommand;
      //itmHelpTools: TIDEMenuSection;

    constructor Create(TheOwner: TComponent); override;
    procedure MainIDEBarDropFiles(Sender: TObject; const FileNames: array of String);
    procedure CoolBarOnChange(Sender: TObject);
    procedure MainSplitterMoved(Sender: TObject);
    procedure SetMainIDEHeightEvent(Sender: TObject);
    procedure OnMainBarActive(Sender: TObject);
    procedure Setup(TheOwner: TComponent);
    procedure SetupHints;
    procedure UpdateIDEComponentPalette(IfFormChanged: boolean);
    procedure HideIDE;
    procedure UnhideIDE;
    property OnActive: TNotifyEvent read FOnActive write FOnActive;
    procedure UpdateDockCaption({%H-}Exclude: TControl); override;
    procedure RefreshCoolbar;
    procedure SetMainIDEHeight;
    procedure DoSetMainIDEHeight(const AIDEIsMaximized: Boolean; ANewHeight: Integer = 0);
    procedure DoSetViewComponentPalette(aVisible: Boolean);
    procedure AllowCompilation(aAllow: Boolean);
    procedure InitPaletteAndCoolBar;
  end;

var
  MainIDEBar: TMainIDEBar = nil;

implementation

{ TMainIDEBar }

procedure TMainIDEBar.MainIDEBarDropFiles(Sender: TObject;
  const FileNames: array of String);
begin
  // the Drop event comes before the Application activate event
  // => invalidate file state
  InvalidateFileStateCache;
  LazarusIDE.DoDropFiles(Sender,FileNames);
end;

procedure TMainIDEBar.DoActive;
begin
  if Assigned(FOnActive) then
    FOnActive(Self);
end;

procedure TMainIDEBar.DoSetMainIDEHeight(const AIDEIsMaximized: Boolean; ANewHeight: Integer);
begin
  if not Showing then Exit;

  //DebugLn(['TMainIDEBar.DoSetMainIDEHeight: IDEStarted=', LazarusIDE.IDEStarted]);

  DisableAutoSizing{$IFDEF DebugDisableAutoSizing}('TMainIDEBar.DoSetMainIDEHeight'){$ENDIF};
  try
    if Assigned(IDEDockMaster) then
    begin
      if EnvironmentOptions.Desktop.AutoAdjustIDEHeight then
      begin
        if ANewHeight <= 0 then
          ANewHeight := CalcMainIDEHeight;
        IDEDockMaster.AdjustMainIDEWindowHeight(Self, True, ANewHeight)
      end
      else
        IDEDockMaster.AdjustMainIDEWindowHeight(Self, False, 0);
    end else
    begin
      if (AIDEIsMaximized or EnvironmentOptions.Desktop.AutoAdjustIDEHeight) then
      begin
        if ANewHeight <= 0 then
          ANewHeight := CalcMainIDEHeight;
        Inc(ANewHeight, CalcNonClientHeight);
        if ANewHeight <> Constraints.MaxHeight then
        begin
          Constraints.MaxHeight := ANewHeight;
          Constraints.MinHeight := ANewHeight;
          ClientHeight := ANewHeight; // <- Value is -28 when issue #34377 happens.
        end else if ClientHeight <> ANewHeight then
          ClientHeight := ANewHeight;
      end else
      if Constraints.MaxHeight <> 0 then
      begin
        Constraints.MaxHeight := 0;
        Constraints.MinHeight := 0;
      end;
    end;
  finally
    EnableAutoSizing{$IFDEF DebugDisableAutoSizing}('TMainIDEBar.DoSetMainIDEHeight'){$ENDIF};
  end;
end;

function TMainIDEBar.CalcMainIDEHeight: Integer;
var
  NewHeight: Integer;
  I: Integer;
  CompScrollBox: TScrollBox;
  SBControl: TControl;
begin
  Result := 0;
  if (EnvironmentOptions=Nil) or (CoolBar=Nil) or (ComponentPageControl=Nil) then
    Exit;

  // IDE Coolbar height
  if EnvironmentOptions.Desktop.IDECoolBarOptions.Visible then
  begin
    for I := 0 to CoolBar.Bands.Count-1 do
    begin
      NewHeight := CoolBar.Bands[I].Top + CoolBar.Bands[I].Height;
      Assert(NewHeight >= 0, Format('TMainIDEBar.CalcMainIDEHeight, IDE Coolbar: '+
        'NewHeight %d < 0. Band Top=%d, Band Height=%d.',
        [NewHeight, CoolBar.Bands[I].Top, CoolBar.Bands[I].Height]) );
      Result := Max(Result, NewHeight);
    end;
  end;

  // Component palette height
  if EnvironmentOptions.Desktop.ComponentPaletteOptions.Visible
  and Assigned(ComponentPageControl.ActivePage) then
  begin
    CompScrollBox := FindCompScrollBox;
    if CompScrollBox=Nil then Exit;
    for I := 0 to CompScrollBox.ControlCount-1 do
    begin
      SBControl := CompScrollBox.Controls[I];
      NewHeight := SBControl.Top + SBControl.Height +  //button height
        //page control non-client height (tabs, borders).
        ComponentPageControl.Height - CompScrollBox.ClientHeight;
      Assert(NewHeight >= 0, Format('TMainIDEBar.CalcMainIDEHeight, Component palette : '+
        'NewHeight %d < 0. Cntrl.Top=%d, Cntrl.Height=%d, '+
        'PageControl.Height=%d, ScrollBox.ClientHeight=%d.',
        [NewHeight, SBControl.Top, SBControl.Height,
         ComponentPageControl.Height, CompScrollBox.ClientHeight]) );
      Result := Max(Result, NewHeight);

      if not EnvironmentOptions.Desktop.AutoAdjustIDEHeightFullCompPal then
        Break;  //we need only one button (we calculate one line only)
    end;
  end;
end;

function TMainIDEBar.CalcNonClientHeight: Integer;
{$IF DEFINED(LCLWin32) OR DEFINED(LCLGtk2) OR DEFINED(LCLQt) OR DEFINED(LCLQt5)}
var
  WindowRect, WindowClientRect: TRect;
{$ENDIF}
begin
  {
    This function is a bug-workaround for various LCL widgetsets.
    Every widgetset handles constrained height differently.
    In an ideal word (when the bugs are fixed), this function shouldn't be
    needed at all - it should return always 0.

    Currently tested: Win32, Gtk2, Carbon, Qt.

    List of bugs related to this workaround:
      http://bugs.freepascal.org/view.php?id=28033
      http://bugs.freepascal.org/view.php?id=28034
      http://bugs.freepascal.org/view.php?id=28036
  }
  if not Showing then
    Exit(0);

  {$IF DEFINED(LCLWin32) OR DEFINED(LCLGtk2) OR DEFINED(LCLQt) OR DEFINED(LCLQt5)}
  //Gtk2 + Win32 + Qt
  //retrieve real main menu height because
  // - Win32: multi-line is possible (SM_CYMENU reflects only single line)
  // - Gtk2, Qt:  SM_CYMENU does not work
  LclIntf.GetWindowRect(Handle, WindowRect{%H-});
  LclIntf.GetClientRect(Handle, WindowClientRect{%H-});
  LclIntf.ClientToScreen(Handle, WindowClientRect.TopLeft);

  Result := WindowClientRect.Top - WindowRect.Top;

  Assert(Result >= 0, 'TMainIDEBar.CalcNonClientHeight: Result '+IntToStr(Result)+' is below zero.');

  {$IFDEF LCLWin32}
  //Win32 the constrained height has to be without SM_CYSIZEFRAME and SM_CYCAPTION;
  Result := Result - (LCLIntf.GetSystemMetrics(SM_CYSIZEFRAME) + LCLIntf.GetSystemMetrics(SM_CYCAPTION));
  {$ENDIF LCLWin32}

  {$ELSE}
  //other widgetsets
  //Carbon tested - behaves correctly
  Result := 0;
  {$ENDIF}
end;

function TMainIDEBar.FindCompScrollBox: TScrollBox;
var
  I: Integer;
begin
  for I := 0 to ComponentPageControl.ActivePage.ControlCount-1 do
    if (ComponentPageControl.ActivePage.Controls[I] is TScrollBox) then
      Exit(TScrollBox(ComponentPageControl.ActivePage.Controls[I]));
  Result := nil;
end;

procedure TMainIDEBar.SetMainIDEHeightEvent(Sender: TObject);
begin
  SetMainIDEHeight;
end;

procedure TMainIDEBar.OnMainBarActive(Sender: TObject);
var
  i, FormCount: integer;
  AForm: TCustomForm;
begin
  if EnvironmentOptions.Desktop.SingleTaskBarButton and not ApplicationIsActivate
  and (WindowState=wsNormal) then
  begin
    ApplicationIsActivate:=true;
    FormCount:=0;
    for i:=Screen.CustomFormCount-1 downto 0 do
    begin
      AForm:=Screen.CustomForms[i];
      if (AForm.Parent=nil) and (AForm<>Self) and (AForm.IsVisible)
      and not IsFormDesign(AForm)
      and not (fsModal in AForm.FormState) then
        inc(FormCount);
    end;
    while LazarusIDE.LastActivatedWindows.Count>0 do
    begin
      AForm:=TCustomForm(LazarusIDE.LastActivatedWindows[0]);
      if Assigned(AForm) and (not (CsDestroying in AForm.ComponentState)) and
      AForm.IsVisible then
        AForm.BringToFront;
      LazarusIDE.LastActivatedWindows.Delete(0);
    end;
    Self.BringToFront;
  end;
end;

procedure TMainIDEBar.WndProc(var Message: TLMessage);
begin
  inherited WndProc(Message);
  if (Message.Msg=LM_ACTIVATE) and (Message.Result=0) then
    DoActive;
end;

procedure TMainIDEBar.UpdateDockCaption(Exclude: TControl);
begin
  // keep IDE caption
end;

constructor TMainIDEBar.Create(TheOwner: TComponent);
begin
  // This form has no resource => must be constructed using CreateNew
  inherited CreateNew(TheOwner, 1);
  AllowDropFiles:=true;
  Scaled:=true;
  OnDropFiles:=@MainIDEBarDropFiles;
  if Assigned(IDEDockMaster) then
    IDEDockMaster.SetMainDockWindow(Self);
  {$IFNDEF LCLGtk2}
  try
    Icon.LoadFromResourceName(HInstance, 'WIN_MAIN');
  except
  end;
  {$ENDIF}
end;

procedure TMainIDEBar.HideIDE;
begin
  if WindowState=wsMinimized then exit;
  FOldWindowState:=WindowState;
  WindowState:=wsMinimized;
end;

procedure TMainIDEBar.UnhideIDE;
begin
  WindowState:=FOldWindowState;
end;

procedure TMainIDEBar.CreatePopupMenus(TheOwner: TComponent);
begin
  OptionsPopupMenu := TPopupMenu.Create(TheOwner);
  OptionsPopupMenu.Images := IDEImages.Images_16;
  OptionsMenuItem := TMenuItem.Create(TheOwner);
  OptionsMenuItem.Name := 'miToolbarOption';
  OptionsMenuItem.Caption := lisMenuGeneralOptions;
  OptionsMenuItem.Enabled := True;
  OptionsMenuItem.Visible := True;
  OptionsMenuItem.ImageIndex := IDEImages.LoadImage('menu_environment_options');
  OptionsPopupMenu.Items.Add(OptionsMenuItem);
end;

procedure TMainIDEBar.Setup(TheOwner: TComponent);
begin
  FMainOwningComponent := TheOwner;
  OnActive:=@OnMainBarActive;

  MainSplitter := TSplitter.Create(TheOwner);
  MainSplitter.Parent := Self;
  MainSplitter.Align := alLeft;
  MainSplitter.MinSize := 50;
  MainSplitter.OnMoved := @MainSplitterMoved;

  // IDE Coolbar
  CoolBar := TCoolBar.Create(TheOwner);
  CoolBar.Parent := Self;
  if EnvironmentOptions.Desktop.ComponentPaletteOptions.Visible then
  begin
    CoolBar.Align := alLeft;
    CoolBar.Width := Scale96ToForm(EnvironmentOptions.Desktop.IDECoolBarOptions.Width);
  end
  else
    CoolBar.Align := alClient;

  // IDE Coolbar object wraps the actual CoolBar.
  IDECoolBar := TIDECoolBar.Create(CoolBar);
  IDECoolBar.IsVisible := EnvironmentOptions.Desktop.IDECoolBarOptions.Visible;
  CoolBar.OnChange := @CoolBarOnChange;
  CreatePopupMenus(TheOwner);
  CoolBar.PopupMenu := OptionsPopupMenu;

  // Component palette
  ComponentPageControl := TPageControl.Create(TheOwner);
  ComponentPageControl.Name := 'ComponentPageControl';
  ComponentPageControl.Align := alClient;
  ComponentPageControl.Visible := EnvironmentOptions.Desktop.ComponentPaletteOptions.Visible;
  ComponentPageControl.Parent := Self;
end;

procedure TMainIDEBar.SetupHints;
var
  CurShowHint: boolean;
  AControl: TControl;
  i, j: integer;
begin
  if EnvironmentOptions=nil then exit;
  // update all hints in the component palette
  CurShowHint:=EnvironmentOptions.ShowHintsForComponentPalette;
  for i:=0 to ComponentPageControl.PageCount-1 do begin
    for j:=0 to ComponentPageControl.Page[i].ControlCount-1 do begin
      AControl:=ComponentPageControl.Page[i].Controls[j];
      AControl.ShowHint:=CurShowHint;
    end;
  end;
  // update all hints in main ide toolbars
  //??? CurShowHint:=EnvironmentOptions.ShowHintsForMainSpeedButtons;
end;

procedure TMainIDEBar.UpdateIDEComponentPalette(IfFormChanged: boolean);
var
  LastActiveForm: TCustomForm;
begin
  // Package manager updates the palette initially.
  LastActiveForm := LazarusIDE.LastFormActivated;
  if not LazarusIDE.IDEStarted
  or (IfFormChanged and (LastCompPaletteForm=LastActiveForm)) then
    exit;
  LastCompPaletteForm := LastActiveForm;
  IDEComponentPalette.HideControls :=
    (LastActiveForm<>nil) and (LastActiveForm.Designer<>nil)
    and (LastActiveForm.Designer.LookupRoot<>nil)
    and not (LastActiveForm.Designer.LookupRoot is TControl);
  {$IFDEF VerboseComponentPalette}
  DebugLn(['* TMainIDEBar.UpdateIDEComponentPalette: Updating palette *',
           ', HideControls=', IDEComponentPalette.HideControls]);
  {$ENDIF}
  IDEComponentPalette.Update(False);
  SetupHints;
end;

procedure TMainIDEBar.InitPaletteAndCoolBar;
begin
  RefreshCoolbar;
  ComponentPageControl.OnChange(Self);//refresh component palette with button reposition
  SetMainIDEHeight;
  if IDEDockMaster<>nil then
    IDEDockMaster.ResetSplitters;
end;

procedure TMainIDEBar.RefreshCoolbar;
var
  I: Integer;
  CoolBand: TCoolBand;
  CoolBarOpts: TIDECoolBarOptions;
  CurToolBar: TIDEToolBar;
begin
  CoolBarOpts := EnvironmentOptions.Desktop.IDECoolBarOptions;
  //read general settings
  if not (CoolBarOpts.GrabStyle in [0..5]) then
    CoolBarOpts.GrabStyle := 4;
  Coolbar.GrabStyle := TGrabStyle(CoolBarOpts.GrabStyle);
  if not (CoolBarOpts.GrabWidth in [1..50]) then
    CoolBarOpts.GrabWidth := 5;
  Coolbar.GrabWidth := CoolBarOpts.GrabWidth;
  Coolbar.BandBorderStyle := TBorderStyle(CoolBarOpts.BorderStyle);
  Coolbar.Width := CoolBarOpts.Width;
  //read toolbars
  CoolBar.Bands.Clear;
  IDECoolBar.CopyFromOptions(CoolBarOpts);
  IDECoolBar.Sort;
  for I := 0 to IDECoolBar.ToolBars.Count - 1 do
  begin
    CurToolBar:=IDECoolBar.ToolBars[I];
    CurToolBar.ToolBar.BeginUpdate;
    try
      CoolBand := CoolBar.Bands.Add;
      CoolBand.Break := CurToolBar.CurrentOptions.Break;
      CoolBand.Control := CurToolBar.ToolBar;
      CoolBand.MinWidth := 25;
      CoolBand.MinHeight := 22;
      CoolBand.FixedSize := True;
      CurToolBar.UseCurrentOptions;
    finally
      CurToolBar.ToolBar.EndUpdate;
    end;
  end;
  CoolBar.AutoAdjustLayout(lapAutoAdjustForDPI, 96, PixelsPerInch, 0, 0);
  CoolBar.AutosizeBands;

  CoolBar.Visible := CoolBarOpts.Visible;
  MainSplitter.Align := alLeft;
  MainSplitter.Visible := Coolbar.Visible and ComponentPageControl.Visible;
end;

procedure TMainIDEBar.Resizing(State: TWindowState);
begin
  if LazarusIDE.IDEStarted then
    case State of
      wsMaximized, wsNormal: begin
        //DebugLn('TMainIDEBar.Resizing: Setting main IDE height');
        DoSetMainIDEHeight(State = wsMaximized);
      end;
    end;

  inherited Resizing(State);
end;

procedure TMainIDEBar.MainSplitterMoved(Sender: TObject);
begin
  EnvironmentOptions.Desktop.IDECoolBarOptions.Width := ScaleFormTo96(CoolBar.Width);
  SetMainIDEHeight;
end;

procedure TMainIDEBar.CoolBarOnChange(Sender: TObject);
begin
  IDECoolBar.CopyFromRealCoolbar(Coolbar);
  IDECoolBar.CopyToOptions(EnvironmentOptions.Desktop.IDECoolBarOptions);
  SetMainIDEHeight;
end;

procedure TMainIDEBar.SetMainIDEHeight;
begin
  DoSetMainIDEHeight(WindowState = wsMaximized);
end;

procedure TMainIDEBar.DoSetViewComponentPalette(aVisible: Boolean);
begin
  if aVisible = ComponentPageControl.Visible then Exit;
  ComponentPageControl.Visible := aVisible;
  EnvironmentOptions.Desktop.ComponentPaletteOptions.Visible := aVisible;
  if aVisible then
  begin
    if CoolBar.Align = alClient then
    begin
      CoolBar.Width := 230;
      EnvironmentOptions.Desktop.IDECoolBarOptions.Width := 230;
    end;
    CoolBar.Align := alLeft;
    CoolBar.Vertical := False;
    MainSplitter.Align := alLeft;
  end
  else
    CoolBar.Align := alClient;
  MainSplitter.Visible := Coolbar.Visible and aVisible;

  if aVisible then//when showing component palette, it must be visible to calculate it correctly
    //this will cause the IDE to flicker, but it's better than to have wrongly calculated IDE height
    DoSetMainIDEHeight(WindowState = wsMaximized, 55);
  SetMainIDEHeight;
end;

procedure TMainIDEBar.AllowCompilation(aAllow: Boolean);
// Enables or disables IDE GUI controls associated with compiling and building.
// Does it interfere with DebugBoss.UpdateButtonsAndMenuItems? Maybe should be refactored and combined.
begin
  itmRunMenuRunWithoutDebugging.Enabled:=aAllow;
  itmRunMenuRun.Enabled:=aAllow;
  itmRunMenuCompile.Enabled:=aAllow;
  itmRunMenuBuild.Enabled:=aAllow;
  itmRunMenuQuickCompile.Enabled:=aAllow;
  itmRunMenuCleanUpAndBuild.Enabled:=aAllow;
  itmPkgEditInstallPkgs.Enabled:=aAllow;
  itmToolRescanFPCSrcDir.Enabled:=aAllow;
  itmToolBuildLazarus.Enabled:=aAllow;
  //itmToolConfigureBuildLazarus.Enabled:=aAllow;
end;

end.


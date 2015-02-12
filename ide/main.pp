{
 /***************************************************************************
                    main.pp  -  the "integrated" in IDE
                    -----------------------------------
  TMainIDE is the main controlling and instance of the IDE, which connects the
  various parts of the IDE.

  main.pp      - TMainIDE = class(TMainIDEBase)
                   The highest manager/boss of the IDE. Only lazarus.pp uses
                   this unit.
  mainbase.pas - TMainIDEBase = class(TMainIDEInterface)
                   The ancestor class used by (and only by) the other
                   bosses/managers like debugmanager, pkgmanager.
  mainintf.pas - TMainIDEInterface = class(TLazIDEInterface)
                   The interface class of the top level functions of the IDE.
                   TMainIDEInterface is used by functions/units, that uses
                   several different parts of the IDE (designer, source editor,
                   codetools), so they can't be added to a specific boss and
                   which are yet too small to become a boss of their own.
  lazideintf.pas - TLazIDEInterface = class(TComponent)
                   For designtime packages, this is the interface class of the
                   top level functions of the IDE.


                 Initial Revision : Sun Mar 28 23:15:32 CST 1999


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
 *   Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.        *
 *                                                                         *
 ***************************************************************************
}
unit Main;

{$mode objfpc}{$H+}

interface

{$I ide.inc}

uses
{$IFDEF IDE_MEM_CHECK}
  MemCheck,
{$ENDIF}
  // fpc packages
  Math, Classes, SysUtils, Process, TypInfo, types, strutils, AVL_Tree,
{$IFDEF UseAsyncProcess}
  AsyncProcess,
{$ENDIF}
  // lazutils
  LazUTF8, Laz2_XMLCfg, AvgLvlTree,
  // lcl
  LCLProc, LCLType, LCLIntf, LConvEncoding, ComCtrls,
  FileUtil, LResources, Forms, Buttons, Menus, Controls, GraphType,
  HelpIntfs, Graphics, ExtCtrls, Dialogs, InterfaceBase, UTF8Process, LazLogger,
  lazutf8classes, LazFileCache,
  // codetools
  FileProcs, FindDeclarationTool, LinkScanner, BasicCodeTools, CodeToolsStructs,
  CodeToolManager, CodeCache, DefineTemplates, KeywordFuncLists, CodeTree,
  // synedit
  AllSynEdit, SynEditKeyCmds, SynBeautifier, SynEditMarks,
  // IDE interface
  IDEIntf, ObjectInspector, PropEdits, PropEditUtils,
  MacroIntf, IDECommands, IDEWindowIntf, ComponentReg,
  SrcEditorIntf, NewItemIntf, IDEExternToolIntf, IDEMsgIntf,
  PackageIntf, ProjectIntf, CompOptsIntf, MenuIntf, LazIDEIntf, IDEDialogs,
  IDEOptionsIntf, IDEImagesIntf, ComponentEditors,
  // protocol
  IDEProtocol,
  // compile
  CompilerOptions, CheckCompilerOpts, BuildProjectDlg,
  ApplicationBundle, ImExportCompilerOpts,
  ExtTools,
  // projects
  ProjectResources, Project, ProjectDefs, NewProjectDlg, 
  PublishProjectDlg, ProjectInspector, PackageDefs,
  // help manager
  IDEContextHelpEdit, IDEHelpIntf, IDEHelpManager, CodeHelp, HelpOptions,
  // designer
  JITForms, ComponentPalette, ComponentList, CompPagesPopup,
  ObjInspExt, Designer, FormEditor, CustomFormEditor, lfmUnitResource,
  ControlSelection, AnchorEditor, TabOrderDlg, MenuEditorForm,
  // LRT stuff
  Translations,
  // debugger
  LazDebuggerGdbmi,
  RunParamsOpts, BaseDebugManager, DebugManager, debugger, DebuggerDlg,
  DebugAttachDialog, DbgIntfBaseTypes, DbgIntfDebuggerBase,
  // packager
  PackageSystem, PkgManager, BasePkgManager, LPKCache,
  // source editing
  SourceEditor, CodeToolsOptions, IDEOptionDefs,
  CodeToolsDefines, DiffDialog, UnitInfoDlg, EditorOptions,
  SourceEditProcs, ViewUnit_dlg, FPDocEditWindow,
  etQuickFixes, etMessageFrame, etMessagesWnd,
  // converter
  ChgEncodingDlg, ConvertDelphi, MissingPropertiesDlg, LazXMLForms,
  // environment option frames
  editor_general_options, componentpalette_options, formed_options, OI_options,
  MsgWnd_Options, files_options, desktop_options, window_options,
  Backup_Options, naming_options, fpdoc_options,
  editor_display_options, editor_keymapping_options, editor_mouseaction_options,
  editor_mouseaction_options_advanced, editor_color_options, editor_markup_options,
  editor_markup_userdefined, editor_codetools_options, editor_codefolding_options,
  editor_general_misc_options, editor_dividerdraw_options,
  editor_multiwindow_options, editor_indent_options,
  codetools_general_options, codetools_codecreation_options,
  codetools_classcompletion_options,
  codetools_wordpolicy_options, codetools_linesplitting_options,
  codetools_space_options, codetools_identifiercompletion_options,
  debugger_general_options, debugger_eventlog_options,
  debugger_language_exceptions_options, debugger_signals_options,
  codeexplorer_update_options, codeexplorer_categories_options,
  codeobserver_options, help_general_options, env_file_filters,
  // project option frames
  project_application_options, project_forms_options, project_lazdoc_options,
  project_save_options, project_versioninfo_options, project_i18n_options,
  project_misc_options, project_resources_options,
  // project compiler option frames
  compiler_path_options, compiler_config_target, compiler_parsing_options,
  compiler_codegen_options, compiler_debugging_options, compiler_verbosity_options,
  compiler_messages_options, Compiler_Other_Options, compiler_compilation_options,
  compiler_buildmacro_options, Compiler_ModeMatrix,
  // package option frames
  package_usage_options, package_description_options, package_integration_options,
  package_provides_options, package_i18n_options,
  // rest of the ide
  Splash, IDEDefs, LazarusIDEStrConsts, LazConf, SearchResultView,
  CodeTemplatesDlg, CodeBrowser, FindUnitDlg, InspectChksumChangedDlg,
  IdeOptionsDlg, EditDefineTree, PublishModule, EnvironmentOpts, TransferMacros,
  KeyMapping, IDETranslations, IDEProcs, ExtToolDialog, ExtToolEditDlg,
  JumpHistoryView, ExampleManager,
  BuildLazDialog, BuildProfileManager, BuildManager, CheckCompOptsForNewUnitDlg,
  MiscOptions, InputHistory, UnitDependencies,
  IDEFPCInfo, IDEInfoDlg, IDEInfoNeedBuild, ProcessList, InitialSetupDlgs,
  InitialSetupProc, NewDialog, MakeResStrDlg, DialogProcs, FindReplaceDialog,
  FindInFilesDlg, CodeExplorer, BuildFileDlg, ProcedureList, ExtractProcDlg,
  FindRenameIdentifier, AbstractsMethodsDlg, EmptyMethodsDlg, UnusedUnitsDlg,
  UseUnitDlg, FindOverloadsDlg, EditorFileManager,
  CleanDirDlg, CodeContextForm, AboutFrm, CompatibilityRestrictions,
  RestrictionBrowser, ProjectWizardDlg, IDECmdLine, IDEGuiCmdLine, CodeExplOpts,
  EditorMacroListViewer, SourceFileManager,
  // main ide
  MainBar, MainIntf, MainBase;

type
  TIDECodetoolsDefines = (
    ctdReady,
    ctdNeedUpdate,
    ctdUpdating
    );

  { TMainIDE }

  TMainIDE = class(TMainIDEBase)
    // event handlers
    procedure MainIDEFormClose(Sender: TObject; var CloseAction: TCloseAction);
    procedure MainIDEFormCloseQuery(Sender: TObject; var CanClose: boolean);
    procedure OnApplicationUserInput(Sender: TObject; Msg: Cardinal);
    procedure OnApplicationIdle(Sender: TObject; var Done: Boolean);
    procedure OnApplicationActivate(Sender: TObject);
    procedure OnApplicationDeActivate(Sender: TObject);
    procedure OnApplicationKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure OnApplicationQueryEndSession(var Cancel: Boolean);
    procedure OnApplicationEndSession(Sender: TObject);
    procedure OnScreenChangedForm(Sender: TObject; Form: TCustomForm);
    procedure OnScreenRemoveForm(Sender: TObject; AForm: TCustomForm);
    procedure OnRemoteControlTimer(Sender: TObject);
    procedure OnSelectFrame(Sender: TObject; var AComponentClass: TComponentClass);
    procedure OIChangedTimerTimer(Sender: TObject);
    procedure OnMainBarActive(Sender: TObject);

    // file menu
    procedure mnuNewUnitClicked(Sender: TObject);
    procedure mnuNewFormClicked(Sender: TObject);
    procedure mnuNewOtherClicked(Sender: TObject);
    procedure mnuOpenClicked(Sender: TObject);
    procedure mnuOpenRecentClicked(Sender: TObject); override;
    procedure mnuRevertClicked(Sender: TObject);
    procedure mnuSaveClicked(Sender: TObject);
    procedure mnuSaveAsClicked(Sender: TObject);
    procedure mnuSaveAllClicked(Sender: TObject);
    procedure mnuExportHtml(Sender: TObject);
    procedure mnuCloseClicked(Sender: TObject);
    procedure mnuCloseAllClicked(Sender: TObject);
    procedure mnuCleanDirectoryClicked(Sender: TObject);
    procedure mnuRestartClicked(Sender: TObject);
    procedure mnuQuitClicked(Sender: TObject);

    // edit menu
    procedure mnuEditUndoClicked(Sender: TObject);
    procedure mnuEditRedoClicked(Sender: TObject);
    procedure mnuEditCutClicked(Sender: TObject);
    procedure mnuEditCopyClicked(Sender: TObject);
    procedure mnuEditPasteClicked(Sender: TObject);
    procedure mnuEditSelectAllClick(Sender: TObject);
    procedure mnuEditSelectCodeBlockClick(Sender: TObject);
    procedure mnuEditSelectToBraceClick(Sender: TObject);
    procedure mnuEditSelectWordClick(Sender: TObject);
    procedure mnuEditSelectLineClick(Sender: TObject);
    procedure mnuEditSelectParagraphClick(Sender: TObject);
    procedure mnuEditUpperCaseBlockClicked(Sender: TObject);
    procedure mnuEditLowerCaseBlockClicked(Sender: TObject);
    procedure mnuEditSwapCaseBlockClicked(Sender: TObject);
    procedure mnuEditIndentBlockClicked(Sender: TObject);
    procedure mnuEditUnindentBlockClicked(Sender: TObject);
    procedure mnuEditSortBlockClicked(Sender: TObject);
    procedure mnuEditTabsToSpacesBlockClicked(Sender: TObject);
    procedure mnuEditSelectionBreakLinesClicked(Sender: TObject);
    procedure mnuEditInsertCharacterClicked(Sender: TObject);

    // search menu
    procedure mnuSearchFindInFiles(Sender: TObject);
    procedure mnuSearchFindIdentifierRefsClicked(Sender: TObject);
    procedure mnuSearchFindBlockOtherEnd(Sender: TObject);
    procedure mnuSearchFindBlockStart(Sender: TObject);
    procedure mnuSearchFindDeclaration(Sender: TObject);
    procedure mnuFindDeclarationClicked(Sender: TObject);
    procedure mnuOpenFileAtCursorClicked(Sender: TObject);
    procedure mnuGotoIncludeDirectiveClicked(Sender: TObject);
    procedure mnuSearchProcedureList(Sender: TObject);
    procedure mnuSetFreeBookmark(Sender: TObject);

    // view menu
    procedure mnuViewInspectorClicked(Sender: TObject);
    procedure mnuViewSourceEditorClicked(Sender: TObject);
    procedure mnuViewFPDocEditorClicked(Sender: TObject);
    procedure mnuViewCodeExplorerClick(Sender: TObject);
    procedure mnuViewCodeBrowserClick(Sender: TObject);
    procedure mnuViewComponentsClick(Sender: TObject);
    procedure mnuViewMacroListClick(Sender: TObject);
    procedure mnuViewRestrictionBrowserClick(Sender: TObject);
    procedure mnuViewMessagesClick(Sender: TObject);
    procedure mnuViewSearchResultsClick(Sender: TObject);
    procedure mnuToggleFormUnitClicked(Sender: TObject);
    procedure mnuViewAnchorEditorClicked(Sender: TObject);
    procedure mnuViewTabOrderClicked(Sender: TObject);
    procedure mnuViewComponentPaletteClicked(Sender: TObject);
    procedure mnuViewIDESpeedButtonsClicked(Sender: TObject);
    procedure mnuViewFPCInfoClicked(Sender: TObject);
    procedure mnuViewIDEInfoClicked(Sender: TObject);
    procedure mnuViewNeedBuildClicked(Sender: TObject);

    // source menu
    procedure mnuSourceCommentBlockClicked(Sender: TObject);
    procedure mnuSourceUncommentBlockClicked(Sender: TObject);
    procedure mnuSourceToggleCommentClicked(Sender: TObject);
    procedure mnuSourceEncloseBlockClicked(Sender: TObject);
    procedure mnuSourceEncloseInIFDEFClicked(Sender: TObject);
    procedure mnuSourceCompleteCodeClicked(Sender: TObject);
    procedure mnuSourceUseUnitClicked(Sender: TObject);
    procedure mnuSourceSyntaxCheckClicked(Sender: TObject);
    procedure mnuSourceGuessUnclosedBlockClicked(Sender: TObject);
    procedure mnuSourceGuessMisplacedIFDEFClicked(Sender: TObject);
    // source->insert CVS keyword
    procedure mnuSourceInsertCVSAuthorClick(Sender: TObject);
    procedure mnuSourceInsertCVSDateClick(Sender: TObject);
    procedure mnuSourceInsertCVSHeaderClick(Sender: TObject);
    procedure mnuSourceInsertCVSIDClick(Sender: TObject);
    procedure mnuSourceInsertCVSLogClick(Sender: TObject);
    procedure mnuSourceInsertCVSNameClick(Sender: TObject);
    procedure mnuSourceInsertCVSRevisionClick(Sender: TObject);
    procedure mnuSourceInsertCVSSourceClick(Sender: TObject);
    // source->insert general
    procedure mnuSourceInsertGPLNoticeClick(Sender: TObject);
    procedure mnuSourceInsertGPLNoticeTranslatedClick(Sender: TObject);
    procedure mnuSourceInsertLGPLNoticeClick(Sender: TObject);
    procedure mnuSourceInsertLGPLNoticeTranslatedClick(Sender: TObject);
    procedure mnuSourceInsertModifiedLGPLNoticeClick(Sender: TObject);
    procedure mnuSourceInsertModifiedLGPLNoticeTranslatedClick(Sender: TObject);
    procedure mnuSourceInsertMITNoticeClick(Sender: TObject);
    procedure mnuSourceInsertMITNoticeTranslatedClick(Sender: TObject);
    procedure mnuSourceInsertUsernameClick(Sender: TObject);
    procedure mnuSourceInsertDateTimeClick(Sender: TObject);
    procedure mnuSourceInsertChangeLogEntryClick(Sender: TObject);
    procedure mnuSourceInsertGUID(Sender: TObject);
    // source->insert full Filename
    procedure mnuSourceInsertFilename(Sender: TObject);
    // source->Tools
    procedure mnuSourceUnitInfoClicked(Sender: TObject);
    procedure mnuSourceUnitDependenciesClicked(Sender: TObject);

    // refactor menu
    procedure mnuRefactorRenameIdentifierClicked(Sender: TObject);
    procedure mnuRefactorExtractProcClicked(Sender: TObject);
    procedure mnuRefactorInvertAssignmentClicked(Sender: TObject);
    procedure mnuRefactorShowAbstractMethodsClicked(Sender: TObject);
    procedure mnuRefactorShowEmptyMethodsClicked(Sender: TObject);
    procedure mnuRefactorShowUnusedUnitsClicked(Sender: TObject);
    procedure mnuRefactorFindOverloadsClicked(Sender: TObject);
    procedure mnuRefactorMakeResourceStringClicked(Sender: TObject);

    // project menu
    procedure mnuNewProjectClicked(Sender: TObject);
    procedure mnuNewProjectFromFileClicked(Sender: TObject);
    procedure mnuOpenProjectClicked(Sender: TObject); override;
    procedure mnuCloseProjectClicked(Sender: TObject);
    procedure mnuSaveProjectClicked(Sender: TObject);
    procedure mnuSaveProjectAsClicked(Sender: TObject);
    procedure mnuPublishProjectClicked(Sender: TObject);
    procedure mnuProjectInspectorClicked(Sender: TObject);
    procedure mnuAddToProjectClicked(Sender: TObject);
    procedure mnuRemoveFromProjectClicked(Sender: TObject);
    procedure mnuViewUnitsClicked(Sender: TObject);
    procedure mnuViewFormsClicked(Sender: TObject);
    procedure mnuViewProjectSourceClicked(Sender: TObject);
    procedure mnuProjectOptionsClicked(Sender: TObject);

    // run menu
    procedure mnuCompileProjectClicked(Sender: TObject);
    procedure mnuBuildProjectClicked(Sender: TObject);
    procedure mnuQuickCompileProjectClicked(Sender: TObject);
    procedure mnuCleanUpAndBuildProjectClicked(Sender: TObject);
    procedure mnuBuildManyModesClicked(Sender: TObject);
    procedure mnuAbortBuildProjectClicked(Sender: TObject);
    procedure mnuRunProjectClicked(Sender: TObject);
    procedure mnuPauseProjectClicked(Sender: TObject);
    procedure mnuShowExecutionPointClicked(Sender: TObject);
    procedure mnuStepIntoProjectClicked(Sender: TObject);
    procedure mnuStepOverProjectClicked(Sender: TObject);
    procedure mnuStepIntoInstrProjectClicked(Sender: TObject);
    procedure mnuStepOverInstrProjectClicked(Sender: TObject);
    procedure mnuStepOutProjectClicked(Sender: TObject);
    procedure mnuRunToCursorProjectClicked(Sender: TObject);
    procedure mnuStopProjectClicked(Sender: TObject);
    procedure mnuAttachDebuggerClicked(Sender: TObject);
    procedure mnuDetachDebuggerClicked(Sender: TObject);
    procedure mnuRunParametersClicked(Sender: TObject);
    procedure mnuBuildFileClicked(Sender: TObject);
    procedure mnuRunFileClicked(Sender: TObject);
    procedure mnuConfigBuildFileClicked(Sender: TObject);

    // tools menu
    procedure mnuToolDiffClicked(Sender: TObject);
    procedure mnuToolConvertDFMtoLFMClicked(Sender: TObject);
    procedure mnuToolCheckLFMClicked(Sender: TObject);
    procedure mnuToolConvertDelphiUnitClicked(Sender: TObject);
    procedure mnuToolConvertDelphiProjectClicked(Sender: TObject);
    procedure mnuToolConvertDelphiPackageClicked(Sender: TObject);
    procedure mnuToolConvertEncodingClicked(Sender: TObject);
    procedure mnuToolManageExamplesClicked(Sender: TObject);
    procedure mnuToolBuildLazarusClicked(Sender: TObject);
    procedure mnuToolBuildAdvancedLazarusClicked(Sender: TObject);
    procedure mnuToolConfigBuildLazClicked(Sender: TObject);
    procedure mnuToolConfigureUserExtToolsClicked(Sender: TObject);
    procedure mnuExternalUserToolClick(Sender: TObject);

    // options menu
    procedure mnuEnvGeneralOptionsClicked(Sender: TObject);
    procedure mnuEnvEditorOptionsClicked(Sender: TObject);
    procedure mnuEnvCodeTemplatesClicked(Sender: TObject);
    procedure mnuEnvCodeToolsDefinesEditorClicked(Sender: TObject);
    procedure mnuEnvRescanFPCSrcDirClicked(Sender: TObject);

    // windows menu
    procedure mnuWindowManagerClicked(Sender: TObject);

    // help menu
    // see helpmanager.pas

    // Handlers called when a menu opens. Can disable sub-items etc.
    procedure mnuFileClicked(Sender: TObject);      // file menu
    procedure mnuEditClicked(Sender: TObject);      // edit menu
    procedure mnuSourceClicked(Sender: TObject);    // source menu
    procedure mnuProjectClicked(Sender: TObject);   // project menu
    procedure mnuRunClicked(Sender: TObject);       // run menu
    procedure mnuPackageClicked(Sender: TObject);   // package menu
    // see pkgmanager.pas

    procedure OpenFilePopupMenuPopup(Sender: TObject);
    procedure mnuOpenFilePopupClick(Sender: TObject);
    procedure SetBuildModePopupMenuPopup(Sender: TObject);
    procedure mnuChgBuildModeClicked(Sender: TObject);
    procedure mnuSetBuildModeClick(Sender: TObject); // event for drop down items
  private
    fBuilder: TLazarusBuilder;
    procedure AllowCompilation(aAllow: Boolean);
    function DoBuildLazarusSub(Flags: TBuildLazarusFlags): TModalResult;
  public
    // Global IDE events
    procedure OnProcessIDECommand(Sender: TObject; Command: word;
                                  var Handled: boolean);
    procedure OnExecuteIDEShortCut(Sender: TObject;
                       var Key: word; Shift: TShiftState;
                       IDEWindowClass: TCustomFormClass);
    function OnExecuteIDECommand(Sender: TObject; Command: word): boolean;
    function OnSelectDirectory(const Title, InitialDir: string): string;
    procedure OnInitIDEFileDialog(AFileDialog: TFileDialog);
    procedure OnStoreIDEFileDialog(AFileDialog: TFileDialog);
    function OnIDEMessageDialog(const aCaption, aMsg: string;
                                DlgType: TMsgDlgType; Buttons: TMsgDlgButtons;
                                const HelpKeyword: string): Integer;
    function OnIDEQuestionDialog(const aCaption, aMsg: string;
                                 DlgType: TMsgDlgType; Buttons: array of const;
                                 const HelpKeyword: string): Integer;

    // Environment options dialog events
    procedure OnLoadIDEOptions(Sender: TObject; AOptions: TAbstractIDEOptions);
    procedure OnSaveIDEOptions(Sender: TObject; AOptions: TAbstractIDEOptions);
    procedure DoOpenIDEOptions(AEditor: TAbstractIDEOptionsEditorClass;
      ACaption: String; AOptionsFilter: array of TAbstractIDEOptionsClass;
      ASettings: TIDEOptionsEditorSettings); override;

    procedure DoEnvironmentOptionsBeforeRead(Sender: TObject);
    procedure DoEnvironmentOptionsBeforeWrite(Sender: TObject; Restore: boolean);
    procedure DoEnvironmentOptionsAfterWrite(Sender: TObject; Restore: boolean);
    procedure DoEditorOptionsBeforeRead(Sender: TObject);
    procedure DoEditorOptionsAfterWrite(Sender: TObject; Restore: boolean);
    procedure DoCodetoolsOptionsAfterWrite(Sender: TObject; Restore: boolean);
    procedure DoCodeExplorerOptionsAfterWrite(Sender: TObject; Restore: boolean);
    procedure DoProjectOptionsBeforeRead(Sender: TObject);
    procedure DoProjectOptionsAfterWrite(Sender: TObject; Restore: boolean);
    procedure OnCompilerOptionsDialogTest(Sender: TObject);
    function DoTestCompilerSettings(TheCompilerOptions: TCompilerOptions): TModalResult;
    function OnCheckCompOptsAndMainSrcForNewUnit(CompOpts: TLazCompilerOptions): TModalResult;

    // ComponentPalette events
    procedure ComponentPaletteClassSelected(Sender: TObject);
    // Copied from CodeTyphon
    procedure SelComponentPageButtonClick(Sender: TObject); override;

    // SourceNotebook events
    procedure OnSrcNoteBookActivated(Sender: TObject);
    procedure OnSrcNoteBookAddJumpPoint(ACaretXY: TPoint; ATopLine: integer;
      AEditor: TSourceEditor; DeleteForwardHistory: boolean);
    procedure OnSrcNoteBookClickLink(Sender: TObject;
      Button: TMouseButton; Shift: TShiftstate; X, Y: Integer);
    procedure OnSrcNoteBookMouseLink(
      Sender: TObject; X, Y: Integer; var AllowMouseLink: Boolean);
    function OnSrcNoteBookGetIndent(Sender: TObject; SrcEditor: TSourceEditor;
      LogCaret, OldLogCaret: TPoint; FirstLinePos, LastLinePos: Integer;
      Reason: TSynEditorCommand; SetIndentProc: TSynBeautifierSetIndentProc): Boolean;
    procedure OnSrcNotebookDeleteLastJumPoint(Sender: TObject);
    procedure OnSrcNotebookEditorActived(Sender: TObject);
    procedure OnSrcNotebookEditorPlaceBookmark(Sender: TObject; var Mark: TSynEditMark);
    procedure OnSrcNotebookEditorClearBookmark(Sender: TObject; var Mark: TSynEditMark);
    procedure OnSrcNotebookEditorClearBookmarkId(Sender: TObject; ID: Integer);
    procedure OnSrcNotebookEditorDoSetBookmark(Sender: TObject; ID: Integer; Toggle: Boolean);
    procedure OnSrcNotebookEditorDoGotoBookmark(Sender: TObject; ID: Integer; Backward: Boolean);
    procedure OnSrcNotebookEditorChanged(Sender: TObject);
    procedure OnSrcNotebookEditorMoved(Sender: TObject);
    procedure OnSrcNotebookEditorClosed(Sender: TObject);
    procedure OnSrcNotebookCurCodeBufferChanged(Sender: TObject);
    procedure OnSrcNotebookFileNew(Sender: TObject);
    procedure OnSrcNotebookFileOpen(Sender: TObject);
    procedure OnSrcNotebookFileOpenAtCursor(Sender: TObject);
    procedure OnSrcNotebookFileSave(Sender: TObject);
    procedure OnSrcNotebookFileSaveAs(Sender: TObject);
    procedure OnSrcNotebookFileClose(Sender: TObject; InvertedClose: boolean);
    procedure OnSrcNotebookFindDeclaration(Sender: TObject);
    procedure OnSrcNotebookInitIdentCompletion(Sender: TObject;
      JumpToError: boolean; out Handled, Abort: boolean);
    procedure OnSrcNotebookShowCodeContext(JumpToError: boolean;
                                           out Abort: boolean);
    procedure OnSrcNotebookJumpToHistoryPoint(var NewCaretXY: TPoint;
      var NewTopLine: integer; var DestEditor: TSourceEditor; JumpAction: TJumpHistoryAction);
    procedure OnSrcNotebookReadOnlyChanged(Sender: TObject);
    procedure OnSrcNotebookSaveAll(Sender: TObject);
    procedure OnSrcNotebookShowHintForSource(SrcEdit: TSourceEditor;
                                           ClientPos: TPoint; CaretPos: TPoint);
    procedure OnSrcNoteBookShowUnitInfo(Sender: TObject);
    procedure OnSrcNotebookToggleFormUnit(Sender: TObject);
    procedure OnSrcNotebookToggleObjectInsp(Sender: TObject);
    procedure OnSrcNotebookViewJumpHistory(Sender: TObject);
    procedure OnSrcNoteBookPopupMenu(const AddMenuItemProc: TAddMenuItemProc);
    procedure OnSrcNoteBookCloseQuery(Sender: TObject; var CloseAction: TCloseAction);

    // ObjectInspector + PropertyEditorHook events
    procedure CreateObjectInspector(aDisableAutoSize: boolean);
    procedure OIOnSelectPersistents(Sender: TObject);
    procedure OIOnShowOptions(Sender: TObject);
    procedure OIOnViewRestricted(Sender: TObject);
    procedure OIOnDestroy(Sender: TObject);
    procedure OIOnAutoShow(Sender: TObject);
    procedure OIRemainingKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure OIOnAddToFavorites(Sender: TObject);
    procedure OIOnRemoveFromFavorites(Sender: TObject);
    procedure OIOnFindDeclarationOfProperty(Sender: TObject);
    procedure OIOnSelectionChange(Sender: TObject);
    function OIOnPropertyHint(Sender: TObject; PointedRow: TOIPropertyGridRow;
       out AHint: string): boolean;
    procedure OIOnUpdateRestricted(Sender: TObject);
    function OnPropHookGetMethodName(const Method: TMethod;
                                     PropOwner: TObject): String;
    procedure OnPropHookGetMethods(TypeData: PTypeData; Proc:TGetStrProc);
    procedure OnPropHookGetCompatibleMethods(InstProp: PInstProp;
                                             const Proc:TGetStrProc);
    function OnPropHookCompatibleMethodExists(const AMethodName: String;
                                    InstProp: PInstProp;
                                    var MethodIsCompatible, MethodIsPublished,
                                    IdentIsMethod: boolean): boolean;
    function OnPropHookMethodExists(const AMethodName: String;
                                    TypeData: PTypeData;
                                    var MethodIsCompatible, MethodIsPublished,
                                    IdentIsMethod: boolean): boolean;
    function OnPropHookCreateMethod(const AMethodName:ShortString;
                                    ATypeInfo:PTypeInfo;
                                    APersistent: TPersistent;
                                    const APropertyPath: string): TMethod;
    procedure OnPropHookShowMethod(const AMethodName: String);
    procedure OnPropHookRenameMethod(const CurName, NewName: String);
    function OnPropHookBeforeAddPersistent(Sender: TObject;
                                           APersistentClass: TPersistentClass;
                                           AParent: TPersistent): boolean;
    procedure OnPropHookComponentRenamed(AComponent: TComponent);
    procedure OnPropHookModified(Sender: TObject);
    procedure OnPropHookPersistentAdded(APersistent: TPersistent;
                                        Select: boolean);
    procedure OnPropHookPersistentDeleting(APersistent: TPersistent);
    procedure OnPropHookDeletePersistent(var APersistent: TPersistent);
    procedure OnPropHookObjectPropertyChanged(Sender: TObject;
                                              NewObject: TPersistent);
    procedure OnPropHookAddDependency(const AClass: TClass;
                                      const AnUnitName: shortstring);
    procedure OnPropHookGetComponentNames(TypeData: PTypeData;
                                          Proc: TGetStrProc);
    function OnPropHookGetComponent(const ComponentPath: String): TComponent;

    // designer events
    procedure OnDesignerGetSelectedComponentClass(Sender: TObject;
                                 var RegisteredComponent: TRegisteredComponent);
    procedure OnDesignerComponentAdded(Sender: TObject);
    procedure OnDesignerSetDesigning(Sender: TObject; Component: TComponent;
                                     Value: boolean);
    procedure OnDesignerShowOptions(Sender: TObject);
    procedure OnDesignerPasteComponents(Sender: TObject; LookupRoot: TComponent;
                            TxtCompStream: TStream; ParentControl: TWinControl;
                            var NewComponents: TFPList);
    procedure OnDesignerPastedComponents(Sender: TObject; LookupRoot: TComponent);
    procedure OnDesignerPropertiesChanged(Sender: TObject);
    procedure OnDesignerPersistentDeleted(Sender: TObject; APersistent: TPersistent);
    procedure OnDesignerModified(Sender: TObject);
    procedure OnDesignerActivated(Sender: TObject);
    procedure OnDesignerCloseQuery(Sender: TObject);
    procedure OnDesignerRenameComponent(ADesigner: TDesigner;
                                 AComponent: TComponent; const NewName: string);
    procedure OnDesignerViewLFM(Sender: TObject);
    procedure OnDesignerSaveAsXML(Sender: TObject);
    procedure OnDesignerShowObjectInspector(Sender: TObject);
    procedure OnDesignerShowAnchorEditor(Sender: TObject);
    procedure OnDesignerShowTabOrderEditor(Sender: TObject);

    // control selection
    procedure OnControlSelectionChanged(Sender: TObject; ForceUpdate: Boolean);
    procedure OnControlSelectionPropsChanged(Sender: TObject);
    procedure OnControlSelectionFormChanged(Sender: TObject; OldForm,
                                            NewForm: TCustomForm);
    procedure OnGetDesignerSelection(const ASelection: TPersistentSelectionList);

    // project inspector
    function ProjInspectorAddUnitToProject(Sender: TObject;
                                           AnUnitInfo: TUnitInfo): TModalresult;
    function ProjInspectorRemoveFile(Sender: TObject;
                                     AnUnitInfo: TUnitInfo): TModalresult;

    // code explorer events
    procedure OnCodeExplorerGetDirectivesTree(Sender: TObject;
                                          var ADirectivesTool: TDirectivesTool);
    procedure OnCodeExplorerJumpToCode(Sender: TObject; const Filename: string;
                                       const Caret: TPoint; TopLine: integer);
    procedure OnCodeExplorerShowOptions(Sender: TObject);

    // CodeToolBoss events
    procedure OnCodeToolNeedsExternalChanges(Manager: TCodeToolManager;
                                             var Abort: boolean);
    procedure OnBeforeCodeToolBossApplyChanges(Manager: TCodeToolManager;
                                    var Abort: boolean);
    procedure OnAfterCodeToolBossApplyChanges(Manager: TCodeToolManager);
    function OnCodeToolBossSearchUsedUnit(const SrcFilename: string;
                     const TheUnitName, TheUnitInFilename: string): TCodeBuffer;
    procedure CodeToolBossGetVirtualDirectoryAlias(Sender: TObject;
                                                   var RealDir: string);
    procedure CodeToolBossGetVirtualDirectoryDefines(DefTree: TDefineTree;
                                                     DirDef: TDirectoryDefines);
    procedure OnCodeToolBossFindDefineProperty(Sender: TObject;
               const PersistentClassName, AncestorClassName, Identifier: string;
               var IsDefined: boolean);
    procedure OnCodeBufferDecodeLoaded(Code: TCodeBuffer;
         const Filename: string; var Source, DiskEncoding, MemEncoding: string);
    procedure OnCodeBufferEncodeSaving(Code: TCodeBuffer;
                                    const Filename: string; var Source: string);
    function OnCodeToolBossGetMethodName(const Method: TMethod;
                                         PropOwner: TObject): String;
    procedure CodeToolBossPrepareTree(Sender: TObject);
    procedure CodeToolBossProgress(Sender: TObject; Index, MaxIndex: integer;
                                   const Msg: string; var Abort: boolean);
    procedure OnCodeToolBossGetIndenterExamples(Sender: TObject;
                Code: TCodeBuffer; Step: integer; // starting at 0
                var CodeBuffers: TFPList; // stopping when CodeBuffers=nil
                var ExpandedFilenames: TStrings
                );
    procedure CodeToolBossFindFPCMangledSource(Sender: TObject;
      SrcType: TCodeTreeNodeDesc; const SrcName: string; out SrcFilename: string);

    function CTMacroFunctionProject(Data: Pointer): boolean;
    procedure OnCompilerParseStampIncreased;
    procedure CodeToolBossScannerInit(Self: TCodeToolManager;
      Scanner: TLinkScanner);

    // SearchResultsView events
    procedure SearchResultsViewSelectionChanged(sender: TObject);

    // JumpHistoryView events
    procedure JumpHistoryViewSelectionChanged(sender: TObject);

    // External Tools events
    procedure FPCMsgFilePoolLoadFile(aFilename: string; out s: string);

    procedure OnGetLayout(Sender: TObject; aFormName: string;
            out aBounds: TRect; out DockSibling: string; out DockAlign: TAlign);
  private
    FUserInputSinceLastIdle: boolean;
    FDesignerToBeFreed: TFilenameToStringTree; // form file names to be freed OnIdle.
    FApplicationIsActivate: boolean;
    fNeedSaveEnvironment: boolean;
    FRemoteControlTimer: TTimer;
    FRemoteControlFileAge: integer;

    FIDECodeToolsDefines: TIDECodetoolsDefines;

    FRenamingComponents: TFPList; // list of TComponents currently renaming
    FOIHelpProvider: TAbstractIDEHTMLProvider;
    FWaitForClose: Boolean;
    FFixingGlobalComponentLock: integer;
    fLastCompPaletteForm: TCustomForm;
    OldCompilerFilename, OldLanguage: String;
    OIChangedTimer: TIdleTimer;

    procedure RenameInheritedMethods(AnUnitInfo: TUnitInfo; List: TStrings);
    function OIHelpProvider: TAbstractIDEHTMLProvider;
  protected
    procedure SetToolStatus(const AValue: TIDEToolStatus); override;
    procedure Notification(AComponent: TComponent;
                           Operation: TOperation); override;
    // methods for start
    procedure StartProtocol;
    procedure LoadGlobalOptions;
    procedure SetupInteractive;
    procedure SetupMainMenu; override;
    procedure SetupStandardIDEMenuItems;
    procedure SetupStandardProjectTypes;
    procedure SetupFileMenu; override;
    procedure SetupEditMenu; override;
    procedure SetupSearchMenu; override;
    procedure SetupViewMenu; override;
    procedure SetupSourceMenu; override;
    procedure SetupProjectMenu; override;
    procedure SetupRunMenu; override;
    procedure SetupPackageMenu; override;
    procedure SetupToolsMenu; override;
    procedure SetupWindowsMenu; override;
    procedure SetupHelpMenu; override;
    procedure LoadMenuShortCuts; override;
    procedure ConnectMainBarEvents;
    procedure SetupSpeedButtons;
    procedure SetupDialogs;
    procedure SetupComponentPalette;
    procedure SetupHints;
    procedure SetupObjectInspector;
    procedure SetupFormEditor;
    procedure SetupSourceNotebook;
    procedure SetupCodeMacros;
    procedure SetupControlSelection;
    procedure SetupIDECommands;
    procedure SetupIDEMsgQuickFixItems;
    procedure SetupStartProject;
    procedure SetupRemoteControl;
    procedure SetupIDEWindowsLayout;
    procedure RestoreIDEWindows;
    procedure FreeIDEWindows;
    function CloseQueryIDEWindows: boolean;

    function GetActiveDesignerSkipMainBar: TComponentEditorDesigner;
    procedure ReloadMenuShortCuts;

    // methods for creating a project
    procedure OnLoadProjectInfoFromXMLConfig(TheProject: TProject;
                                             XMLConfig: TXMLConfig; Merge: boolean);
    procedure OnSaveProjectInfoToXMLConfig(TheProject: TProject;
                         XMLConfig: TXMLConfig; WriteFlags: TProjectWriteFlags);
    procedure OnProjectGetTestDirectory(TheProject: TProject; out TestDir: string);
    procedure OnProjectChangeInfoFile(TheProject: TProject);
    procedure OnSaveProjectUnitSessionInfo(AUnitInfo: TUnitInfo);
  public
    class procedure ParseCmdLineOptions;

    constructor Create(TheOwner: TComponent); override;
    procedure StartIDE; override;
    destructor Destroy; override;
    procedure CreateOftenUsedForms; override;
    function DoResetToolStatus(AFlags: TResetToolFlags): boolean; override;

    // files/units
    function DoNewFile(NewFileDescriptor: TProjectFileDescriptor;
        var NewFilename: string; NewSource: string;
        NewFlags: TNewFlags; NewOwner: TObject): TModalResult; override;
    procedure CreateFileDialogFilterForSourceEditorFiles(Filter: string;
        out AllEditorMask, AllMask: string);

    function DoSaveEditorFile(AEditor: TSourceEditorInterface;
                              Flags: TSaveFlags): TModalResult; override;
    function DoSaveEditorFile(const Filename: string;
                              Flags: TSaveFlags): TModalResult; override;

    function DoCloseEditorFile(AEditor: TSourceEditorInterface;
                               Flags: TCloseFlags):TModalResult; override;
    function DoCloseEditorFile(const Filename: string;
                               Flags: TCloseFlags): TModalResult; override;

    function DoSaveAll(Flags: TSaveFlags): TModalResult; override;
    function DoOpenEditorFile(AFileName:string; PageIndex, WindowIndex: integer;
                              Flags: TOpenFlags): TModalResult; override;
    function DoOpenEditorFile(AFileName:string; PageIndex, WindowIndex: integer;
                              AEditorInfo: TUnitEditorInfo;
                              Flags: TOpenFlags): TModalResult;
    procedure DoDropFiles(Sender: TObject; const FileNames: array of String;
      WindowIndex: integer=-1); override;

    function DoOpenFileAndJumpToIdentifier(const AFilename, AnIdentifier: string;
        PageIndex, WindowIndex: integer; Flags: TOpenFlags): TModalResult; override;
    function DoOpenFileAndJumpToPos(const AFilename: string;
        const CursorPosition: TPoint; TopLine: integer;
        PageIndex, WindowIndex: integer; Flags: TOpenFlags): TModalResult; override;
    function DoRevertEditorFile(const Filename: string): TModalResult; override;
    function DoOpenComponent(const UnitFilename: string; OpenFlags: TOpenFlags;
        CloseFlags: TCloseFlags; out Component: TComponent): TModalResult; override;
    function DoFixupComponentReferences(RootComponent: TComponent;
                                  OpenFlags: TOpenFlags): TModalResult; override;
    procedure BeginFixupComponentReferences;
    procedure EndFixupComponentReferences;
    procedure DoRestart;
    procedure DoExecuteRemoteControl;
    function DoViewUnitsAndForms(OnlyForms: boolean): TModalResult;
    function DoSelectFrame: TComponentClass;
    procedure DoViewUnitInfo;
    procedure DoShowCodeExplorer(State: TIWGetFormState = iwgfShowOnTop);
    procedure DoShowCodeBrowser(State: TIWGetFormState = iwgfShowOnTop);
    procedure DoShowRestrictionBrowser(const RestrictedName: String = ''; State: TIWGetFormState = iwgfShowOnTop);
    procedure DoShowComponentList(State: TIWGetFormState = iwgfShowOnTop); override;
    procedure DoShowJumpHistory(State: TIWGetFormState = iwgfShowOnTop);
    procedure DoShowInspector(State: TIWGetFormState = iwgfShowOnTop);
    procedure CreateIDEWindow(Sender: TObject; aFormName: string;
                          var AForm: TCustomForm; DoDisableAutoSizing: boolean);
    function CreateNewUniqueFilename(const Prefix, Ext: string;
       NewOwner: TObject; Flags: TSearchIDEFileFlags; TryWithoutNumber: boolean
       ): string; override;
    procedure MarkUnitsModifiedUsingSubComponent(SubComponent: TComponent);

    // project(s)
    function CreateProjectObject(ProjectDesc,
                      FallbackProjectDesc: TProjectDescriptor): TProject; override;
    function DoNewProject(ProjectDesc: TProjectDescriptor): TModalResult; override;
    function DoSaveProject(Flags: TSaveFlags): TModalResult; override;
    function DoCloseProject: TModalResult; override;
    procedure DoNoProjectWizard(Sender: TObject);
    function DoOpenProjectFile(AFileName: string;
                               Flags: TOpenFlags): TModalResult; override;
    function DoPublishProject(Flags: TSaveFlags;
                              ShowDialog: boolean): TModalResult; override;
    procedure DoShowProjectInspector(State: TIWGetFormState = iwgfShowOnTop); override;
    function DoAddActiveUnitToProject: TModalResult;
    function DoRemoveFromProjectDialog: TModalResult;
    function DoWarnAmbiguousFiles: TModalResult;
    function DoSaveForBuild(AReason: TCompileReason): TModalResult; override;
    function DoBuildProject(const AReason: TCompileReason;
                            Flags: TProjectBuildFlags): TModalResult; override;
    function UpdateProjectPOFile(AProject: TProject): TModalResult;
    function DoAbortBuild(Interactive: boolean): TModalResult;
    procedure DoCompile;
    procedure DoQuickCompile;
    function DoInitProjectRun: TModalResult; override;
    function DoRunProject: TModalResult;
    function DoSaveProjectToTestDirectory(Flags: TSaveFlags): TModalResult;
    function QuitIDE: boolean;

    // edit menu
    procedure DoCommand(ACommand: integer); override;
    procedure DoSourceEditorCommand(EditorCommand: integer;
      CheckFocus: boolean = true; FocusEditor: boolean = true);
    procedure UpdateExternalUserToolsInMenu;

    // external tools
    function PrepareForCompile: TModalResult; override;
    function DoRunExternalTool(Index: integer; ShowAbort: Boolean): TModalResult;
    function DoSaveBuildIDEConfigs(Flags: TBuildLazarusFlags): TModalResult; override;
    function DoExampleManager: TModalResult; override;
    function DoBuildLazarus(Flags: TBuildLazarusFlags): TModalResult; override;
    function DoBuildAdvancedLazarus(ProfileNames: TStringList): TModalResult;
    function DoBuildFile(ShowAbort: Boolean): TModalResult;
    function DoRunFile: TModalResult;
    function DoConfigBuildFile: TModalResult;
    function GetIDEDirectives(AnUnitInfo: TUnitInfo;
                              DirectiveList: TStrings): TModalResult;

    // useful information methods
    procedure GetCurrentUnit(out ActiveSourceEditor: TSourceEditor;
                             out ActiveUnitInfo: TUnitInfo); override;
    procedure GetDesignerUnit(ADesigner: TDesigner;
          var ActiveSourceEditor: TSourceEditor; var ActiveUnitInfo: TUnitInfo); override;
    function GetProjectFileForProjectEditor(AEditor: TSourceEditorInterface): TLazProjectFile; override;
    function GetDesignerForProjectEditor(AEditor: TSourceEditorInterface;
                              LoadForm: boolean): TIDesigner; override;
    function GetDesignerWithProjectFile(AFile: TLazProjectFile;
                             LoadForm: boolean): TIDesigner; override;
    function GetDesignerFormOfSource(AnUnitInfo: TUnitInfo;
                                     LoadForm: boolean): TCustomForm;
    function GetProjectFileWithRootComponent(AComponent: TComponent): TLazProjectFile; override;
    function GetProjectFileWithDesigner(ADesigner: TIDesigner): TLazProjectFile; override;
    procedure GetObjectInspectorUnit(
          var ActiveSourceEditor: TSourceEditor; var ActiveUnitInfo: TUnitInfo); override;
    procedure GetUnitWithForm(AForm: TCustomForm;
          var ActiveSourceEditor: TSourceEditor; var ActiveUnitInfo: TUnitInfo); override;
    procedure GetUnitWithPersistent(APersistent: TPersistent;
          var ActiveSourceEditor: TSourceEditor; var ActiveUnitInfo: TUnitInfo); override;
    function GetAncestorUnit(AnUnitInfo: TUnitInfo): TUnitInfo;
    function GetAncestorLookupRoot(AnUnitInfo: TUnitInfo): TComponent;
    procedure UpdateSaveMenuItemsAndButtons(UpdateSaveAll: boolean); override;

    // useful file methods
    function FindUnitFile(const AFilename: string; TheOwner: TObject = nil;
                          Flags: TFindUnitFileFlags = []): string; override;
    function FindSourceFile(const AFilename, BaseDirectory: string;
                            Flags: TFindSourceFlags): string; override;
    function DoCheckFilesOnDisk(Instantaneous: boolean = false): TModalResult; override;
    function DoPublishModule(Options: TPublishModuleOptions;
      const SrcDirectory, DestDirectory: string): TModalResult; override;
    procedure PrepareBuildTarget(Quiet: boolean;
                               ScanFPCSrc: TScanModeFPCSources = smsfsBackground); override;
    procedure AbortBuild; override;

    // useful frontend methods
    procedure UpdateCaption; override;
    procedure HideIDE; override;
    procedure CloseUnmodifiedDesigners;
    procedure UnhideIDE; override;
    procedure SaveIncludeLinks; override;

    // methods for codetools
    function InitCodeToolBoss: boolean;
    function BeginCodeTools: boolean; override;
    function DoJumpToSourcePosition(const Filename: string;
                               NewX, NewY, NewTopLine: integer;
                               Flags: TJumpToCodePosFlags = [jfFocusEditor]): TModalResult; override;
    function DoJumpToCodePosition(
                        ActiveSrcEdit: TSourceEditorInterface;
                        ActiveUnitInfo: TUnitInfo;
                        NewSource: TCodeBuffer; NewX, NewY, NewTopLine: integer;
                        Flags: TJumpToCodePosFlags = [jfFocusEditor]): TModalResult; override;
    procedure DoJumpToCodeToolBossError; override;
    function NeedSaveSourceEditorChangesToCodeCache(AEditor: TSourceEditorInterface): boolean; override;
    function SaveSourceEditorChangesToCodeCache(AEditor: TSourceEditorInterface): boolean; override;
    procedure ApplyCodeToolChanges;
    procedure DoJumpToOtherProcedureSection;
    procedure DoFindDeclarationAtCursor;
    procedure DoFindDeclarationAtCaret(const LogCaretXY: TPoint);
    function DoFindRenameIdentifier(Rename: boolean): TModalResult;
    function DoFindUsedUnitReferences: boolean;
    function DoShowAbstractMethods: TModalResult;
    function DoRemoveEmptyMethods: TModalResult;
    function DoRemoveUnusedUnits: TModalResult;
    function DoUseUnit: TModalResult;
    function DoFindOverloads: TModalResult;
    function DoInitIdentCompletion(JumpToError: boolean): boolean;
    function DoShowCodeContext(JumpToError: boolean): boolean;
    procedure DoCompleteCodeAtCursor;
    procedure DoExtractProcFromSelection;
    function DoCheckSyntax: TModalResult;
    procedure DoGoToPascalBlockOtherEnd;
    procedure DoGoToPascalBlockStart;
    procedure DoJumpToGuessedUnclosedBlock(FindNextUTF8: boolean);
    procedure DoJumpToGuessedMisplacedIFDEF(FindNextUTF8: boolean);
    procedure DoGotoIncludeDirective;

    // tools
    function DoMakeResourceString: TModalResult;
    function DoDiff: TModalResult;
    function DoFindInFiles: TModalResult;

    // conversion
    function DoConvertDFMtoLFM: TModalResult;
    function DoConvertDelphiProject(const DelphiFilename: string): TModalResult;
    function DoConvertDelphiPackage(const DelphiFilename: string): TModalResult;

    // message view
    function DoJumpToCompilerMessage(FocusEditor: boolean; Msg: TMessageLine = nil
      ): boolean; override;
    procedure DoJumpToNextError(DirectionDown: boolean); override;
    procedure DoShowMessagesView(BringToFront: boolean = true); override;

    // methods for debugging, compiling and external tools
    function GetTestBuildDirectory: string; override;
    function GetFPCompilerFilename: string; override;
    function GetFPCFrontEndOptions: string; override;
    procedure GetIDEFileState(Sender: TObject; const AFilename: string;
      NeededFlags: TIDEFileStateFlags; out ResultFlags: TIDEFileStateFlags); override;

    // search results
    function DoJumpToSearchResult(FocusEditor: boolean): boolean;
    procedure DoShowSearchResultsView(State: TIWGetFormState = iwgfShowOnTop); override;

    // form editor and designer
    procedure DoBringToFrontFormOrUnit;
    procedure DoBringToFrontFormOrInspector(ForceInspector: boolean);
    procedure DoShowDesignerFormOfCurrentSrc; override;
    procedure DoShowSourceOfActiveDesignerForm;
    procedure SetDesigning(AComponent: TComponent; Value: Boolean);
    procedure SetDesignInstance(AComponent: TComponent; Value: Boolean);
    function CreateDesignerForComponent(AnUnitInfo: TUnitInfo;
                                AComponent: TComponent): TCustomForm; override;
    procedure InvalidateAllDesignerForms;
    procedure UpdateIDEComponentPalette(IfFormChanged: boolean);
    procedure ShowDesignerForm(AForm: TCustomForm);
    procedure DoViewAnchorEditor(State: TIWGetFormState = iwgfShowOnTop);
    procedure DoViewTabOrderEditor(State: TIWGetFormState = iwgfShowOnTop);
    procedure DoToggleViewComponentPalette;
    procedure DoToggleViewIDESpeedButtons;

    // editor and environment options
    procedure SaveEnvironment(Immediately: boolean = false); override;
    procedure LoadDesktopSettings(TheEnvironmentOptions: TEnvironmentOptions);
    procedure SaveDesktopSettings(TheEnvironmentOptions: TEnvironmentOptions);
    procedure PackageTranslated(APackage: TLazPackage); override;
  end;


const
  CodeToolsIncludeLinkFile = 'includelinks.xml';

var
  ShowSplashScreen: boolean = false;

implementation

var
  ParamBaseDirectory: string = '';
  SkipAutoLoadingLastProject: boolean = false;
  StartedByStartLazarus: boolean = false;
  ShowSetupDialog: boolean = false;

function FindDesignComponent(const aName: string): TComponent;
var
  AnUnitInfo: TUnitInfo;
begin
  Result:=nil;
  if Project1=nil then exit;
  AnUnitInfo:=Project1.FirstUnitWithComponent;
  while AnUnitInfo<>nil do begin
    if SysUtils.CompareText(aName,AnUnitInfo.Component.Name)=0 then begin
      Result:=AnUnitInfo.Component;
      exit;
    end;
    AnUnitInfo:=AnUnitInfo.NextUnitWithComponent;
  end;
end;

//==============================================================================


{ TMainIDE }

{-------------------------------------------------------------------------------
  procedure TMainIDE.ParseCmdLineOptions;

  Parses the command line for the IDE.
-------------------------------------------------------------------------------}
class procedure TMainIDE.ParseCmdLineOptions;
const
  space = '                      ';
var
  AHelp: TStringList;
  HelpLang: string;

  procedure AddHelp(Args: array of const);
  var
    i: Integer;
    s: String;
  begin
    s:='';
    for i := Low(Args) to High(Args) do
    begin
      case Args[i].VType of
        vtInteger: s+=dbgs(Args[i].vinteger);
        vtInt64: s+=dbgs(Args[i].VInt64^);
        vtQWord: s+=dbgs(Args[i].VQWord^);
        vtBoolean: s+=dbgs(Args[i].vboolean);
        vtExtended: s+=dbgs(Args[i].VExtended^);
{$ifdef FPC_CURRENCY_IS_INT64}
        // fpc 2.x has troubles in choosing the right dbgs()
        // so we convert here
        vtCurrency: s+=dbgs(int64(Args[i].vCurrency^)/10000, 4);
{$else}
        vtCurrency: s+=dbgs(Args[i].vCurrency^);
{$endif}
        vtString: s+=Args[i].VString^;
        vtAnsiString: s+=AnsiString(Args[i].VAnsiString);
        vtChar: s+=Args[i].VChar;
        vtPChar: s+=Args[i].VPChar;
        vtPWideChar: {%H-}s+=Args[i].VPWideChar{%H-};
        vtWideChar: {%H-}s+=Args[i].VWideChar{%H-};
        vtWidestring: {%H-}s+=WideString(Args[i].VWideString){%H-};
        vtObject: s+=DbgSName(Args[i].VObject);
        vtClass: s+=DbgSName(Args[i].VClass);
        vtPointer: s+=Dbgs(Args[i].VPointer);
      end;
    end;
    AHelp.Add(s);
  end;

  procedure WriteHelp(const AText: string);
  begin
    if TextRec(Output).Mode = fmClosed then
      // Note: do not use IDEMessageDialog here:
      Dialogs.MessageDlg(lisInformation, AText, mtInformation, [mbOk],0)
    else
      WriteLn(UTF8ToConsole(AText));
    Application.Terminate;
  end;

var
  i: integer;
  ConfFileName: String;
  Cfg: TXMLConfig;
begin
  ParamBaseDirectory:=GetCurrentDirUTF8;
  StartedByStartLazarus:=false;
  SkipAutoLoadingLastProject:=false;
  EnableRemoteControl:=false;
  if IsHelpRequested then
  begin
    HelpLang := GetLanguageSpecified;
    if HelpLang = '' then
    begin
      ConfFileName:=TrimFilename(SetDirSeparators(GetPrimaryConfigPath+'/'+EnvOptsConfFileName));
      try
        Cfg:=TXMLConfig.Create(ConfFileName);
        try
          HelpLang:=Cfg.GetValue('EnvironmentOptions/Language/ID','');
        finally
          Cfg.Free;
        end;
      except
      end;
    end;
    if HelpLang<>'' then
      TranslateResourceStrings(ProgramDirectory(true), HelpLang);

    AHelp := TStringList.Create;
    AddHelp([lislazarusOptionsProjectFilename]);
    AddHelp(['']);
    AddHelp([lisIDEOptions]);
    AddHelp(['']);
    AddHelp(['--help or -?             ', listhisHelpMessage]);
    AddHelp(['']);
    AddHelp(['-v or --version          ', lisShowVersionAndExit]);
    AddHelp(['--quiet                  ', lisBeLessVerboseCanBeGivenMultipleTimes]);
    AddHelp(['--verbose                ', lisBeMoreVerboseCanBeGivenMultipleTimes]);
    AddHelp(['']);
    AddHelp([ShowSetupDialogOptLong]);
    AddHelp([BreakString(space+lisShowSetupDialogForMostImportantSettings, 75, 22)]);
    AddHelp(['']);
    AddHelp([PrimaryConfPathOptLong, ' <path>']);
    AddHelp(['or ', PrimaryConfPathOptShort, ' <path>']);
    AddHelp([BreakString(space+lisprimaryConfigDirectoryWhereLazarusStoresItsConfig,
                        75, 22), LazConf.GetPrimaryConfigPath]);
    AddHelp(['']);
    AddHelp([SecondaryConfPathOptLong,' <path>']);
    AddHelp(['or ',SecondaryConfPathOptShort,' <path>']);
    AddHelp([BreakString(space+lissecondaryConfigDirectoryWhereLazarusSearchesFor,
                        75, 22), LazConf.GetSecondaryConfigPath]);
    AddHelp(['']);
    AddHelp([DebugLogOpt,' <file>']);
    AddHelp([BreakString(space+lisFileWhereDebugOutputIsWritten, 75, 22)]);
    AddHelp(['']);
    AddHelp([DebugLogOptEnable,' [[-]OptName][,[-]OptName][...]']);
    AddHelp([BreakString(space+lisGroupsForDebugOutput, 75, 22)]);
    for i := 0 to DebugLogger.LogGroupList.Count - 1 do
      AddHelp([space + DebugLogger.LogGroupList[i]^.ConfigName]);
    AddHelp(['']);
    AddHelp([NoSplashScreenOptLong]);
    AddHelp(['or ',NoSplashScreenOptShort]);
    AddHelp([BreakString(space+lisDoNotShowSplashScreen,75, 22)]);
    AddHelp(['']);
    AddHelp([SkipLastProjectOpt]);
    AddHelp([BreakString(space+lisSkipLoadingLastProject, 75, 22)]);
    AddHelp(['']);
    AddHelp([LanguageOpt]);
    AddHelp([BreakString(space+lisOverrideLanguage,75, 22)]);
    AddHelp(['']);
    AddHelp([LazarusDirOpt,'<directory>']);
    AddHelp([BreakString(space+lisLazarusDirOverride, 75, 22)]);
    AddHelp(['']);
    AddHelp([lisCmdLineLCLInterfaceSpecificOptions]);
    AddHelp(['']);
    AddHelp([GetCmdLineParamDescForInterface]);
    AddHelp(['']);
   
    WriteHelp(AHelp.Text);
    AHelp.Free;
    exit;
  end;
  if IsVersionRequested then
  begin
    WriteHelp(GetLazarusVersionString+' '+lisSVNRevision+LazarusRevisionStr);
    exit;
  end;

  ParseGuiCmdLineParams(SkipAutoLoadingLastProject, StartedByStartLazarus,
    EnableRemoteControl, ShowSplashScreen, ShowSetupDialog);

  DebugLn('TMainIDE.ParseCmdLineOptions:');
  Debugln('  PrimaryConfigPath="',UTF8ToConsole(GetPrimaryConfigPath),'"');
  Debugln('  SecondaryConfigPath="',UTF8ToConsole(GetSecondaryConfigPath),'"');
end;

procedure TMainIDE.LoadGlobalOptions;
// load environment, miscellaneous, editor and codetools options
  function GetSecondConfDirWarning: String;
  var
    StartFile: String;
  begin
    Result:=SimpleFormat(lisIfYouWantToUseTwoDifferentLazarusVersionsYouMustSt,
                   [LineEnding+LineEnding]) + LineEnding;
    StartFile:=Application.ExeName;
    if StartedByStartLazarus then
      StartFile:=ExtractFilePath(StartFile)+'startlazarus'+GetExeExt;
    {$IFDEF Windows}
      Result+=StartFile+' --pcp=C:\test_lazarus\configs';
    {$ELSE}
      {$IFDEF darwin}
      Result+='open '+StartFile+' --pcp=~/.lazarus_test';
      {$ELSE}
      Result+=StartFile+' --pcp=~/.lazarus_test';
      {$ENDIF}
    {$ENDIF}
  end;

  function NormalizeLazExe(LazExe: string): string;
  {$IFDEF Darwin}
  var
    p: SizeInt;
  {$ENDIF}
  begin
    Result:=TrimFilename(LazExe);
    {$IFDEF Darwin}
    p:=Pos('.app/Contents/MacOS/',Result);
    if p>0 then
      Result:=LeftStr(LazExe,p-1);
    {$ENDIF}
  end;

var
  EnvOptsCfgExisted: boolean;
  s, LastCalled: String;
  OldVer: String;
  NowVer: String;
  IsUpgrade: boolean;
  MsgResult: TModalResult;
  CurPrgName: String;
  AltPrgName: String;
begin
  with EnvironmentOptions do
  begin
    EnvOptsCfgExisted := FileExistsCached(GetDefaultConfigFilename);
    OnBeforeRead := @DoEnvironmentOptionsBeforeRead;
    OnBeforeWrite := @DoEnvironmentOptionsBeforeWrite;
    OnAfterWrite := @DoEnvironmentOptionsAfterWrite;
    CreateConfig;
    Load(false);
  end;

  // read language and lazarusdir paramters, needed for translation
  if Application.HasOption('language') then
  begin
    debugln('TMainIDE.LoadGlobalOptions overriding language with command line: ',
      Application.GetOptionValue('language'));
    EnvironmentOptions.LanguageID := Application.GetOptionValue('language');
  end;
  if Application.HasOption('lazarusdir') then
  begin
    debugln('TMainIDE.LoadGlobalOptions overriding Lazarusdir with command line: ',
      Application.GetOptionValue('lazarusdir'));
    EnvironmentOptions.Lazarusdirectory:= Application.GetOptionValue('lazarusdir');
  end;

  // translate IDE resourcestrings
  Application.BidiMode := Application.Direction(EnvironmentOptions.LanguageID);
  TranslateResourceStrings(EnvironmentOptions.GetParsedLazarusDirectory,
                           EnvironmentOptions.LanguageID);
  MainBuildBoss.TranslateMacros;

  // check if this PCP was used by another lazarus exe
  s := ExtractFileName(ParamStrUTF8(0));
  CurPrgName := NormalizeLazExe(AppendPathDelim(ProgramDirectory(False)) + s);
  AltPrgName := NormalizeLazExe(AppendPathDelim(AppendPathDelim(GetPrimaryConfigPath) + 'bin') + s);
  LastCalled := NormalizeLazExe(EnvironmentOptions.LastCalledByLazarusFullPath);

  if (LastCalled = '') then
  begin
    // this PCP was not yet used (at least not with a version with LastCalledByLazarusFullPath)
    if CompareFilenames(CurPrgName,AltPrgName)=0 then
    begin
      // a custom built IDE is started and the PCP has no information about the
      // original lazarus exe
      // => Probably someone updated trunk
    end else begin
      // remember this exe in the PCP
      EnvironmentOptions.LastCalledByLazarusFullPath := CurPrgName;
      SaveEnvironment(False);
    end;
  end
  else
  if (CompareFilenames(LastCalled,CurPrgName)<>0) and
     (CompareFilenames(LastCalled,AltPrgName)<>0) and
     (CompareFilenames(CurPrgName,AltPrgName)<>0) // we can NOT check, if we only have the path inside the PCP
  then begin
    // last time the PCP was started from another lazarus exe
    // => either the user forgot to pass a --pcp
    //    or the user uninstalled and installed to another directory
    // => warn
    debugln(['TMainIDE.LoadGlobalOptions ']);
    debugln(['  LastCalled="',LastCalled,'"']);
    debugln(['  CurPrgName="',CurPrgName,'"']);
    debugln(['  AltPrgName="',AltPrgName,'"']);
    MsgResult := IDEQuestionDialog(lisIncorrectConfigurationDirectoryFound,
        SimpleFormat(lisIDEConficurationFoundMayBelongToOtherLazarus,
        [LineEnding, GetSecondConfDirWarning, GetPrimaryConfigPath,
         EnvironmentOptions.LastCalledByLazarusFullPath, CurPrgName]),
      mtWarning, [mrOK, lisUpdateInfo, mrIgnore, mrAbort]);

    case MsgResult of
      mrOk: begin
          EnvironmentOptions.LastCalledByLazarusFullPath := CurPrgName;
          SaveEnvironment(False);
        end;
      mrIgnore: ;
      else
        begin
          Application.Terminate;
          exit;
        end;
    end;
  end;

  Application.ShowButtonGlyphs := EnvironmentOptions.ShowButtonGlyphs;
  Application.ShowMenuGlyphs := EnvironmentOptions.ShowMenuGlyphs;

  OldVer:=EnvironmentOptions.OldLazarusVersion;
  NowVer:=GetLazarusVersionString;
  //debugln(['TMainIDE.LoadGlobalOptions ',EnvOptsCfgExisted,' diff=',OldVer<>NowVer,' Now=',NowVer,' Old=',OldVer,' Comp=',CompareLazarusVersion(NowVer,OldVer)]);
  if EnvOptsCfgExisted and (OldVer<>NowVer) then
  begin
    IsUpgrade:=CompareLazarusVersion(NowVer,OldVer)>0;
    if OldVer='' then
      OldVer:=SimpleFormat(lisPrior, [GetLazarusVersionString]);
    s:=SimpleFormat(lisWelcomeToLazarusThereIsAlreadyAConfigurationFromVe,
      [GetLazarusVersionString, LineEnding+LineEnding, OldVer, LineEnding, GetPrimaryConfigPath+LineEnding] );
    if IsUpgrade then
      s+=lisTheOldConfigurationWillBeUpgraded
    else
      s+=lisTheConfigurationWillBeDowngradedConverted;
    s+=LineEnding
      +LineEnding;
    s+=GetSecondConfDirWarning;
    if IsUpgrade then
      MsgResult:=IDEQuestionDialog(lisUpgradeConfiguration, s, mtConfirmation, [
        mrOK, lisUpgrade, mrAbort])
    else
      MsgResult:=IDEQuestionDialog(lisDowngradeConfiguration, s, mtWarning, [
        mrOK, lisDowngrade, mrAbort]);
    if MsgResult<>mrOk then begin
      Application.Terminate;
      exit;
    end;
  end;

  UpdateDefaultPasFileExt;
  LoadFileDialogFilter;

  EditorOpts := TEditorOptions.Create;
  EditorOpts.OnBeforeRead := @DoEditorOptionsBeforeRead;
  EditorOpts.OnAfterWrite := @DoEditorOptionsAfterWrite;
  SetupIDECommands;
  // Only after EditorOpts.KeyMap.DefineCommandCategories; in SetupIDECommands
  IDECommandList.CreateCategory(nil, EditorUserDefinedWordsKeyCatName,
    lisUserDefinedMarkupKeyGroup, IDECmdScopeSrcEditOnly);

  SetupIDEMsgQuickFixItems;
  EditorOpts.Load;

  ExternalUserTools:=TExternalUserTools(EnvironmentOptions.ExternalToolMenuItems);
  ExternalUserTools.LoadShortCuts(EditorOpts.KeyMap);

  MiscellaneousOptions := TMiscellaneousOptions.Create;
  MiscellaneousOptions.Load;

  CodeToolsOpts := TCodeToolsOptions.Create;
  with CodeToolsOpts do
  begin
    OnAfterWrite := @DoCodetoolsOptionsAfterWrite;
    SetLazarusDefaultFilename;
    Load;
  end;

  CodeExplorerOptions := TCodeExplorerOptions.Create;
  CodeExplorerOptions.OnAfterWrite := @DoCodeExplorerOptionsAfterWrite;
  CodeExplorerOptions.Load;

  DebuggerOptions := TDebuggerOptions.Create;

  MainBuildBoss.SetupInputHistories;

  CreateDirUTF8(GetProjectSessionsConfigPath);

  RunBootHandlers(libhEnvironmentOptionsLoaded);
end;

procedure TMainIDE.SetupInteractive;
var
  CfgCache: TFPCTargetConfigCache;
  OldLazDir: String;
  Note: string;
begin
  {$IFDEF DebugSearchFPCSrcThread}
  ShowSetupDialog:=true;
  {$ENDIF}

  // check lazarus directory
  if (not ShowSetupDialog)
  and (CheckLazarusDirectoryQuality(EnvironmentOptions.GetParsedLazarusDirectory,Note)<>sddqCompatible)
  then begin
    debugln(['Warning: incompatible Lazarus directory: ',EnvironmentOptions.GetParsedLazarusDirectory]);
    ShowSetupDialog:=true;
  end;

  // check compiler
  if (not ShowSetupDialog)
  and (CheckCompilerQuality(EnvironmentOptions.GetParsedCompilerFilename,Note,
                       CodeToolBoss.FPCDefinesCache.TestFilename)=sddqInvalid)
  then begin
    debugln(['Warning: invalid compiler: ',EnvironmentOptions.GetParsedCompilerFilename]);
    ShowSetupDialog:=true;
  end;

  // check FPC source directory
  if (not ShowSetupDialog) then
  begin
    CfgCache:=CodeToolBoss.FPCDefinesCache.ConfigCaches.Find(
      EnvironmentOptions.GetParsedCompilerFilename,'','','',true);
    if CheckFPCSrcDirQuality(EnvironmentOptions.GetParsedFPCSourceDirectory,Note,
      CfgCache.GetFPCVer)=sddqInvalid
    then begin
      debugln(['Warning: invalid fpc source directory: ',EnvironmentOptions.GetParsedFPCSourceDirectory]);
      ShowSetupDialog:=true;
    end;
  end;

  // check debugger
  if (not ShowSetupDialog)
  and ((EnvironmentOptions.DebuggerConfig.DebuggerClass='')
      or (EnvironmentOptions.DebuggerConfig.DebuggerClass='TGDBMIDebugger'))
  and (CheckDebuggerQuality(EnvironmentOptions.GetParsedDebuggerFilename, Note)<>sddqCompatible)
  then begin
    debugln(['Warning: missing GDB exe',EnvironmentOptions.GetParsedLazarusDirectory]);
    ShowSetupDialog:=true;
  end;

  // show setup dialog
  if ShowSetupDialog then begin
    OldLazDir:=EnvironmentOptions.LazarusDirectory;
    if ShowInitialSetupDialog<>mrOk then begin
      Application.Terminate;
      exit;
    end;
    EnvironmentOptions.Save(true);
    if OldLazDir<>EnvironmentOptions.LazarusDirectory then begin
      // fetch new translations
      CollectTranslations(EnvironmentOptions.GetParsedLazarusDirectory);
      TranslateResourceStrings(EnvironmentOptions.GetParsedLazarusDirectory,
                               EnvironmentOptions.LanguageID);
    end;
  end;

  // set global macros
  CodeToolBoss.SetGlobalValue(
    ExternalMacroStart+'LazarusDir',EnvironmentOptions.GetParsedLazarusDirectory);
  CodeToolBoss.SetGlobalValue(
    ExternalMacroStart+'ProjPath',VirtualDirectory);
  CodeToolBoss.SetGlobalValue(
    ExternalMacroStart+'LCLWidgetType',LCLPlatformDirNames[GetDefaultLCLWidgetType]);
  CodeToolBoss.SetGlobalValue(
    ExternalMacroStart+'FPCSrcDir',EnvironmentOptions.GetParsedFPCSourceDirectory);
end;

constructor TMainIDE.Create(TheOwner: TComponent);
var
  Layout: TSimpleWindowLayout;
  FormCreator: TIDEWindowCreator;
  AMenuHeight: Integer;
begin
  {$IFDEF IDE_MEM_CHECK}CheckHeapWrtMemCnt('TMainIDE.Create START');{$ENDIF}
  inherited Create(TheOwner);
  {$IFDEF IDE_MEM_CHECK}CheckHeapWrtMemCnt('TMainIDE.Create INHERITED');{$ENDIF}

  FWaitForClose := False;

  SetupDialogs;

  MainBuildBoss:=TBuildManager.Create(nil);
  MainBuildBoss.HasGUI:=true;
  {$IFDEF IDE_MEM_CHECK}CheckHeapWrtMemCnt('TMainIDE.Create BUILD MANAGER');{$ENDIF}
  // setup macros before loading options
  MainBuildBoss.SetupTransferMacros;

  // load options
  CreatePrimaryConfigPath;
  StartProtocol;
  LoadGlobalOptions;
  if Application.Terminated then exit;

  if EnvironmentOptions.SingleTaskBarButton then
    Application.TaskBarBehavior := tbSingleButton;

  // setup code templates
  SetupCodeMacros;

  // setup the code tools
  if not InitCodeToolBoss then begin
    Application.Terminate;
    exit;
  end;

  // setup interactive if neccessary
  SetupInteractive;
  if Application.Terminated then exit;

  {$IFDEF IDE_MEM_CHECK}CheckHeapWrtMemCnt('TMainIDE.Create CODETOOLS');{$ENDIF}

  MainBuildBoss.SetupExternalTools;
  MainBuildBoss.EnvOptsChanged;

  // build and position the MainIDE form
  Application.CreateForm(TMainIDEBar,MainIDEBar);
  MainIDEBar.OnActive:=@OnMainBarActive;

  AMenuHeight := LCLIntf.GetSystemMetrics(SM_CYMENU);
  if AMenuHeight > 0 then
  begin
    // what we know:
    // 1. cmd speedbuttons height = 22
    // 2. components palette buttons = 32
    // 3. menu height provided by widgetset (varies , depends on theme)
    // so we set 22 + 32 + (borders * 2).
    MainIDEBar.Constraints.MaxHeight := AMenuHeight +
      22 {cmd speedbtns} + 32 {component buttons} +
      LCLIntf.GetSystemMetrics(SM_CYSIZEFRAME) +
      (LCLIntf.GetSystemMetrics(SM_CYBORDER) * 2) {borders};
  end else
    MainIDEBar.Constraints.MaxHeight:=85;

  MainIDEBar.Name := NonModalIDEWindowNames[nmiwMainIDEName];
  FormCreator:=IDEWindowCreators.Add(MainIDEBar.Name);
  FormCreator.Right:='100%';
  FormCreator.Bottom:='+90';
  Layout:=IDEWindowCreators.SimpleLayoutStorage.ItemByFormID(MainIDEBar.Name);
  if not (Layout.WindowState in [iwsNormal,iwsMaximized]) then
    Layout.WindowState:=iwsNormal;
  if IDEDockMaster<>nil then
    IDEDockMaster.MakeIDEWindowDockSite(MainIDEBar);

  HiddenWindowsOnRun:=TFPList.Create;
  LastActivatedWindows:=TFPList.Create;

  // menu
  MainIDEBar.DisableAutoSizing{$IFDEF DebugDisableAutoSizing}('TMainIDE.Create'){$ENDIF};
  try
    SetupStandardIDEMenuItems;
    SetupMainMenu;
    SetupSpeedButtons;
    SetupComponentPalette;
    ConnectMainBarEvents;
  finally
    MainIDEBar.EnableAutoSizing{$IFDEF DebugDisableAutoSizing}('TMainIDE.Create'){$ENDIF};
  end;
  {$IFDEF IDE_MEM_CHECK}CheckHeapWrtMemCnt('TMainIDE.Create MENU');{$ENDIF}

  // create main IDE register items
  NewIDEItems:=TNewLazIDEItemCategories.Create;

  SetupStandardProjectTypes;

  // initialize the other IDE managers
  DebugBoss:=TDebugManager.Create(nil);
  DebugBoss.ConnectMainBarEvents;
  DebuggerDlg.OnProcessCommand := @OnProcessIDECommand;

  PkgBoss:=TPkgManager.Create(nil);
  PkgBoss.ConnectMainBarEvents;
  LPKInfoCache:=TLPKInfoCache.Create;
  HelpBoss:=TIDEHelpManager.Create(nil);
  HelpBoss.ConnectMainBarEvents;
  {$IFDEF IDE_MEM_CHECK}CheckHeapWrtMemCnt('TMainIDE.Create MANAGERS');{$ENDIF}
  // setup the IDE components
  MainBuildBoss.SetupCompilerInterface;
  SetupObjectInspector;
  SetupFormEditor;
  SetupSourceNotebook;
  SetupControlSelection;
  SetupTextConverters;
  // all IDE objects created => connect the events between them
  LoadMenuShortCuts;
  {$IFDEF IDE_MEM_CHECK}CheckHeapWrtMemCnt('TMainIDE.Create IDE COMPONENTS');{$ENDIF}

  // load installed packages
  PkgBoss.LoadInstalledPackages;

  EditorMacroListViewer.LoadGlobalInfo; // Must be after packages are loaded/registered.

  FormEditor1.RegisterFrame;
  {$IFDEF IDE_MEM_CHECK}CheckHeapWrtMemCnt('TMainIDE.Create INSTALLED COMPONENTS');{$ENDIF}

  // load package configs
  HelpBoss.LoadHelpOptions;
end;

procedure TMainIDE.StartIDE;
begin
  {$IFDEF IDE_MEM_CHECK}CheckHeapWrtMemCnt('TMainIDE.StartIDE START');{$ENDIF}
  // set Application handlers
  Application.AddOnUserInputHandler(@OnApplicationUserInput);
  Application.AddOnIdleHandler(@OnApplicationIdle);
  Application.AddOnActivateHandler(@OnApplicationActivate);
  Application.AddOnDeActivateHandler(@OnApplicationDeActivate);
  Application.AddOnKeyDownHandler(@OnApplicationKeyDown);
  Application.AddOnQueryEndSessionHandler(@OnApplicationQueryEndSession);
  Application.AddOnEndSessionHandler(@OnApplicationEndSession);
  Screen.AddHandlerRemoveForm(@OnScreenRemoveForm);
  Screen.AddHandlerActiveFormChanged(@OnScreenChangedForm);
  TComponentPalette(IDEComponentPalette).OnClassSelected := @ComponentPaletteClassSelected;
  SetupHints;
  SetupIDEWindowsLayout;
  RestoreIDEWindows;
  // make sure the main IDE bar is always shown
  IDEWindowCreators.ShowForm(MainIDEBar,false);
  DebugBoss.UpdateButtonsAndMenuItems; // Disable Stop-button (and some others).
  SetupStartProject;                   // Now load a project
  if Project1=nil then begin
    Application.Terminate;
    exit;
  end;
  DoShowMessagesView(false);           // reopen extra windows
  fUserInputSinceLastIdle:=true; // Idle work gets done initially before user action.
  FApplicationIsActivate:=true;
  FIDEStarted:=true;
  {$IFDEF IDE_MEM_CHECK}CheckHeapWrtMemCnt('TMainIDE.StartIDE END');{$ENDIF}
end;

destructor TMainIDE.Destroy;
begin
  ToolStatus:=itExiting;
  if Assigned(ExternalTools) then
    ExternalTools.TerminateAll;

  DebugLn('[TMainIDE.Destroy] A ');

  {$IFDEF IDE_MEM_CHECK}CheckHeapWrtMemCnt('TMainIDE.Destroy A ');{$ENDIF}
  if Assigned(MainIDEBar) then begin
    MainIDEBar.DisableAutoSizing{$IFDEF DebugDisableAutoSizing}('TMainIDE.Destroy'){$ENDIF};
    MainIDEBar.OnActive:=nil;
  end;

  if DebugBoss<>nil then DebugBoss.EndDebugging;

  if TheControlSelection<>nil then begin
    TheControlSelection.OnChange:=nil;
    TheControlSelection.OnSelectionFormChanged:=nil;
  end;

  FreeAndNil(FDesignerToBeFreed);
  FreeAndNil(JumpHistoryViewWin);
  FreeAndNil(ComponentListForm);
  FreeThenNil(ProjInspector);
  FreeThenNil(CodeExplorerView);
  FreeThenNil(CodeBrowserView);
  FreeAndNil(LazFindReplaceDialog);
  FreeAndNil(MessagesView);
  FreeThenNil(AnchorDesigner);
  FreeThenNil(SearchResultsView);
  FreeThenNil(ObjectInspector1);
  FreeThenNil(SourceEditorManagerIntf);

  // disconnect handlers
  Application.RemoveAllHandlersOfObject(Self);
  Screen.RemoveAllHandlersOfObject(Self);
  IDECommands.OnExecuteIDECommand:=nil;
  TestCompilerOptions:=nil;

  // free project, if it is still there
  FreeThenNil(Project1);

  // free IDE parts
  FreeFormEditor;
  FreeTextConverters;
  FreeThenNil(IDEQuickFixes);
  FreeThenNil(GlobalDesignHook);
  FreeThenNil(LPKInfoCache);
  FreeThenNil(PkgBoss);
  FreeThenNil(HelpBoss);
  FreeThenNil(DebugBoss);
  FreeThenNil(TheCompiler);
  FreeThenNil(HiddenWindowsOnRun);
  FreeThenNil(LastActivatedWindows);
  FreeThenNil(GlobalMacroList);
  FreeThenNil(IDEMacros);
  FreeThenNil(IDECodeMacros);
  FreeThenNil(LazProjectFileDescriptors);
  FreeThenNil(LazProjectDescriptors);
  FreeThenNil(NewIDEItems);
  FreeThenNil(IDEMenuRoots);
  // IDE options objects
  FreeThenNil(CodeToolsOpts);
  FreeThenNil(CodeExplorerOptions);
  FreeThenNil(MiscellaneousOptions);
  FreeThenNil(EditorOpts);
  IDECommandList := nil;
  FreeThenNil(DebuggerOptions);
  FreeThenNil(EnvironmentOptions);
  FreeThenNil(IDECommandScopes);
  // free control selection
  FreeThenNil(TheControlSelection);

  DebugLn('[TMainIDE.Destroy] B  -> inherited Destroy... ',ClassName);
  {$IFDEF IDE_MEM_CHECK}CheckHeapWrtMemCnt('TMainIDE.Destroy B ');{$ENDIF}
  FreeThenNil(MainBuildBoss);
  inherited Destroy;
  {$IFDEF IDE_MEM_CHECK}CheckHeapWrtMemCnt('TMainIDE.Destroy C ');{$ENDIF}

  FreeThenNil(IDEProtocolOpts);
  FreeThenNil(fBuilder);
  DebugLn('[TMainIDE.Destroy] END');
end;

procedure TMainIDE.CreateOftenUsedForms;
begin
  MessagesView:=TMessagesView.Create(nil);
  MessagesView.ApplyIDEOptions;

  LazFindReplaceDialog:=TLazFindReplaceDialog.Create(nil);
end;

procedure TMainIDE.OIOnSelectPersistents(Sender: TObject);
begin
  if ObjectInspector1=nil then exit;
  TheControlSelection.AssignSelection(ObjectInspector1.Selection);
  GlobalDesignHook.SetSelection(ObjectInspector1.Selection);
end;

procedure TMainIDE.OIOnShowOptions(Sender: TObject);
begin
  DoOpenIDEOptions(TOIOptionsFrame);
end;

procedure TMainIDE.OIOnViewRestricted(Sender: TObject);
var
  C: TClass;
begin
  if ObjectInspector1=nil then exit;
  C := nil;
  if (ObjectInspector1.Selection <> nil) and
      (ObjectInspector1.Selection.Count > 0) then
  begin
    C := ObjectInspector1.Selection[0].ClassType;
    if C.InheritsFrom(TForm) then
      C := TForm
    else if C.InheritsFrom(TCustomForm) then
      C := TCustomForm
    else if C.InheritsFrom(TDataModule) then
      C := TDataModule
    else if C.InheritsFrom(TFrame) then
      C := TFrame;
  end;

  if ObjectInspector1.GetActivePropertyRow = nil then
  begin
    if C <> nil then
      DoShowRestrictionBrowser(C.ClassName)
    else
      DoShowRestrictionBrowser;
  end
  else
  begin
    if C <> nil then
      DoShowRestrictionBrowser(C.ClassName + '.' + ObjectInspector1.GetActivePropertyRow.Name)
    else
      DoShowRestrictionBrowser;
  end;
end;

procedure TMainIDE.OIOnDestroy(Sender: TObject);
begin
  if ObjectInspector1=Sender then begin
    ObjectInspector1:=nil;
    if FormEditor1<>nil then
      FormEditor1.Obj_Inspector := nil;
  end;
end;

procedure TMainIDE.OIOnAutoShow(Sender: TObject);
begin
  IDEWindowCreators.ShowForm(Sender as TObjectInspectorDlg,false);
end;

procedure TMainIDE.OIRemainingKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  OnExecuteIDEShortCut(Sender,Key,Shift,nil);
end;

procedure TMainIDE.OIOnAddToFavorites(Sender: TObject);
begin
  if ObjectInspector1=nil then exit;
  ShowAddRemoveFavoriteDialog(ObjectInspector1,true);
end;

procedure TMainIDE.OIOnRemoveFromFavorites(Sender: TObject);
begin
  if ObjectInspector1=nil then exit;
  ShowAddRemoveFavoriteDialog(ObjectInspector1,false);
end;

procedure TMainIDE.OIOnFindDeclarationOfProperty(Sender: TObject);
var
  AnInspector: TObjectInspectorDlg;
  Code: TCodeBuffer;
  Caret: TPoint;
  NewTopLine: integer;
begin
  if Sender=nil then Sender:=ObjectInspector1;
  if Sender is TObjectInspectorDlg then begin
    if not BeginCodeTools then exit;
    AnInspector:=TObjectInspectorDlg(Sender);
    if FindDeclarationOfOIProperty(AnInspector,nil,Code,Caret,NewTopLine) then
      DoOpenFileAndJumpToPos(Code.Filename,Caret,NewTopLine,-1,-1,[]);
  end;
end;

procedure TMainIDE.OIOnSelectionChange(Sender: TObject);
begin
  if Sender is TObjectInspectorDlg then
    OIChangedTimer.AutoEnabled:=true;
end;

function TMainIDE.OIOnPropertyHint(Sender: TObject; PointedRow: TOIPropertyGridRow;
  out AHint: string): boolean;
var
  Code: TCodeBuffer;
  Caret: TPoint;
  NewTopLine: integer;
  BaseURL: string;
begin
  Result:=false;
  AHint:='';
  if (ObjectInspector1=nil) or not BeginCodeTools then exit;
  Result:=FindDeclarationOfOIProperty(ObjectInspector1,PointedRow,Code,Caret,NewTopLine)
    and (TIDEHelpManager(HelpBoss).GetHintForSourcePosition(Code.Filename,Caret,
                                                            BaseURL,aHint)=shrSuccess);
end;

procedure TMainIDE.OIOnUpdateRestricted(Sender: TObject);
begin
  if Sender = nil then
    Sender := ObjectInspector1;
  if Sender is TObjectInspectorDlg then
    (Sender as TObjectInspectorDlg).RestrictedProps := GetRestrictedProperties;
end;

function TMainIDE.OnPropHookGetMethodName(const Method: TMethod;
  PropOwner: TObject): String;
var
  JITMethod: TJITMethod;
  LookupRoot: TPersistent;
begin
  if Method.Code<>nil then begin
    if Method.Data<>nil then begin
      Result:=TObject(Method.Data).MethodName(Method.Code);
      if Result='' then
        Result:='<Unpublished>';
    end else
      Result:='<No LookupRoot>';
  end else if IsJITMethod(Method) then begin
    JITMethod:=TJITMethod(Method.Data);
    Result:=JITMethod.TheMethodName;
    if PropOwner is TComponent then begin
      LookupRoot:=GetLookupRootForComponent(TComponent(PropOwner));
      if LookupRoot is TComponent then begin
        //DebugLn(['TMainIDE.OnPropHookGetMethodName ',Result,' GlobalDesignHook.LookupRoot=',dbgsName(GlobalDesignHook.LookupRoot),' JITMethod.TheClass=',dbgsName(JITMethod.TheClass),' PropOwner=',DbgSName(PropOwner),' PropOwner-LookupRoot=',DbgSName(LookupRoot)]);
        if (LookupRoot.ClassType<>JITMethod.TheClass) then begin
          Result:=JITMethod.TheClass.ClassName+'.'+Result;
        end;
      end;
    end;
  end else
    Result:='';
  {$IFDEF VerboseDanglingComponentEvents}
  if IsJITMethod(Method) then
    DebugLn(['TMainIDE.OnPropHookGetMethodName ',Result,' ',IsJITMethod(Method)]);
  {$ENDIF}
end;

procedure TMainIDE.OnPropHookGetMethods(TypeData: PTypeData; Proc: TGetStrProc);
var 
  ActiveSrcEdit: TSourceEditor;
  ActiveUnitInfo: TUnitInfo;
begin
  ActiveSrcEdit:=nil;
  if not BeginCodeTool(ActiveSrcEdit,ActiveUnitInfo,[ctfSwitchToFormSource])
  then exit;
  {$IFDEF IDE_DEBUG}
  DebugLn('');
  DebugLn('[TMainIDE.OnPropHookGetMethods] ************');
  {$ENDIF}
  if not CodeToolBoss.GetCompatiblePublishedMethods(ActiveUnitInfo.Source,
    ActiveUnitInfo.Component.ClassName,TypeData,Proc) then
  begin
    DoJumpToCodeToolBossError;
  end;
end;

procedure TMainIDE.OnPropHookGetCompatibleMethods(InstProp: PInstProp;
  const Proc: TGetStrProc);
var
  ActiveSrcEdit: TSourceEditor;
  ActiveUnitInfo: TUnitInfo;
  CTResult: Boolean;
begin
  ActiveSrcEdit:=nil;
  if not BeginCodeTool(ActiveSrcEdit,ActiveUnitInfo,[ctfSwitchToFormSource])
  then exit;
  {$IFDEF IDE_DEBUG}
  DebugLn('');
  DebugLn('[TMainIDE.OnPropHookGetCompatibleMethods] ************');
  {$ENDIF}
  if FormEditor1.ComponentUsesRTTIForMethods(ActiveUnitInfo.Component) then begin
    CTResult:=CodeToolBoss.GetCompatiblePublishedMethods(ActiveUnitInfo.Source,
      ActiveUnitInfo.Component.ClassName,
      GetTypeData(InstProp^.PropInfo^.PropType),Proc);
  end else begin
    CTResult:=CodeToolBoss.GetCompatiblePublishedMethods(ActiveUnitInfo.Source,
      ActiveUnitInfo.Component.ClassName,
      InstProp^.Instance,InstProp^.PropInfo^.Name,Proc);
  end;
  if not CTResult then
    DoJumpToCodeToolBossError;
end;

function TMainIDE.OnPropHookCompatibleMethodExists(const AMethodName: String;
  InstProp: PInstProp; var MethodIsCompatible, MethodIsPublished,
  IdentIsMethod: boolean): boolean;
var
  ActiveSrcEdit: TSourceEditor;
  ActiveUnitInfo: TUnitInfo;
begin
  ActiveSrcEdit:=nil;
  if not BeginCodeTool(ActiveSrcEdit,ActiveUnitInfo,[ctfSwitchToFormSource]) then
    Exit;
  {$IFDEF IDE_DEBUG}
  debugln('');
  debugln('[TMainIDE.OnPropHookCompatibleMethodExists] ************ ',AMethodName);
  {$ENDIF}
  if FormEditor1.ComponentUsesRTTIForMethods(ActiveUnitInfo.Component) then begin
    Result := CodeToolBoss.PublishedMethodExists(ActiveUnitInfo.Source,
                          ActiveUnitInfo.Component.ClassName, AMethodName,
                          GetTypeData(InstProp^.PropInfo^.PropType),
                          MethodIsCompatible, MethodIsPublished, IdentIsMethod);
  end else begin
    Result := CodeToolBoss.PublishedMethodExists(ActiveUnitInfo.Source,
                          ActiveUnitInfo.Component.ClassName, AMethodName,
                          InstProp^.Instance, InstProp^.PropInfo^.Name,
                          MethodIsCompatible, MethodIsPublished, IdentIsMethod);
  end;
  if CodeToolBoss.ErrorMessage <> '' then
  begin
    DoJumpToCodeToolBossError;
    raise Exception.Create(lisUnableToFindMethod+' '+lisPleaseFixTheErrorInTheMessageWindow);
  end;
end;

procedure TMainIDE.CodeToolBossFindFPCMangledSource(Sender: TObject;
  SrcType: TCodeTreeNodeDesc; const SrcName: string; out SrcFilename: string);
var
  i: Integer;
  SrcEdit: TSourceEditorInterface;
  Code: TCodeBuffer;
  Tool: TCodeTool;
begin
  case SrcType of
  ctnProgram:
    begin
      // check active project
      if (Project1<>nil) and (Project1.MainFile<>nil) then begin
        SrcFilename:=Project1.MainFile.Filename;
        if FilenameIsAbsolute(SrcFilename)
        and ((SrcName='')
          or (SysUtils.CompareText(ExtractFileNameOnly(SrcFilename),SrcName)=0))
        then
          exit; // found
      end;
    end;
  end;
  // search in source editor
  for i:=0 to SourceEditorManagerIntf.SourceEditorCount-1 do begin
    SrcEdit:=SourceEditorManagerIntf.SourceEditors[i];
    SrcFilename:=SrcEdit.FileName;
    if CompareText(ExtractFileNameOnly(SrcFileName),SrcName)<>0 then
      continue;
    case SrcType of
    ctnUnit:
      if not FilenameIsPascalUnit(SrcFileName) then
        continue;
    else
      // a pascal program can have any file name
      // but we don't want to open program.res or program.txt
      // => check if source is Pascal
      // => load source and check if codetools can parse at least one node
      Code:=CodeToolBoss.LoadFile(SrcFilename,true,false);
      if Code=nil then continue;
      CodeToolBoss.Explore(Code,Tool,false,true);
      if (Tool=nil) or (Tool.Tree.Root=nil)  then
        continue;
    end;
    exit; // found
  end;
  // not found
  SrcFilename:='';
end;

{------------------------------------------------------------------------------}
procedure TMainIDE.MainIDEFormClose(Sender: TObject;
  var CloseAction: TCloseAction);
begin
  DoCallNotifyHandler(lihtIDEClose);
  SaveEnvironment(true);
  if IDEDockMaster<>nil then
    IDEDockMaster.CloseAll
  else
    CloseAllForms;
  SaveIncludeLinks;
  InputHistories.Save;
  PkgBoss.SaveSettings;
  if TheControlSelection<>nil then
    TheControlSelection.Clear;
  FreeIDEWindows;
end;

procedure TMainIDE.MainIDEFormCloseQuery(Sender: TObject; var CanClose: boolean);
const IsClosing: Boolean = False;
begin
  CanClose := True;
  if IsClosing then Exit;
  IsClosing := True;
  CanClose := False;
  SourceFileMgr.CheckingFilesOnDisk := True;
  try
    if (ToolStatus = itExiting) then exit;

    // stop debugging/compiling/...
    if DoAbortBuild(true)<>mrOk then exit;
    if not DoResetToolStatus([rfInteractive, rfCloseOnDone]) then exit;

    // check foreign windows
    if not CloseQueryIDEWindows then exit;

    // save packages
    if PkgBoss.DoCloseAllPackageEditors<>mrOk then exit;

    // save project
    if SourceFileMgr.AskSaveProject(lisDoYouStillWantToQuit,lisDiscardChangesAndQuit)<>mrOk then
      exit;

    CanClose:=(DoCloseProject <> mrAbort);
  finally
    IsClosing := False;
    SourceFileMgr.CheckingFilesOnDisk:=false;
    if not CanClose then
      DoCheckFilesOnDisk(false);
  end;
end;

{------------------------------------------------------------------------------}
procedure TMainIDE.SetupSpeedButtons;

  function CreateButton(AToolBar: TToolBar; const AName, APixName: String;
    const AOnClick: TNotifyEvent; const AHint: String): TToolButton;
  begin
    Result := TToolButton.Create(OwningComponent);
    with Result do
    begin
      Name := AName;
      Parent := AToolBar;
      Enabled := True;
      OnClick := AOnClick;
      ImageIndex := IDEImages.LoadImage(16, APixName);
      Hint := AHint;
    end;
  end;

  function CreateDivider(AToolBar: TToolBar): TToolButton;
  begin
    Result := TToolButton.Create(OwningComponent);
    with Result do
    begin
      Style := tbsDivider;
      AutoSize := True;
      Parent := AToolBar;
    end;
  end;

  function CreateToolBar(AName: String): TToolBar;
  begin
    Result := TToolBar.Create(OwningComponent);
    Result.Name := AName;
    Result.Parent := MainIDEBar.pnlSpeedButtons;
    Result.Images := IDEImages.Images_16;
    Result.AutoSize := true;
  end;

begin
  // Panel for buttons on the left
  MainIDEBar.pnlSpeedButtons := TPanel.Create(OwningComponent);
  with MainIDEBar.pnlSpeedButtons do 
  begin
    Name := 'pnlSpeedButtons';
    Parent := MainIDEBar;
    Align := alLeft;
    Caption := '';
    BevelOuter := bvNone;
    AutoSize := true;
    Visible := EnvironmentOptions.IDESpeedButtonsVisible;
  end;

  MainIDEBar.tbViewDebug := CreateToolBar('tbViewDebug');
  MainIDEBar.tbStandard := CreateToolBar('tbStandard');

  MainIDEBar.NewUnitSpeedBtn     := CreateButton(MainIDEBar.tbStandard , 'NewUnitSpeedBtn'    , 'item_unit'                 , @mnuNewUnitClicked, lisMenuNewUnit);
  MainIDEBar.NewFormSpeedBtn     := CreateButton(MainIDEBar.tbStandard , 'NewFormSpeedBtn'    , 'item_form'                 , @mnuNewFormClicked, lisMenuNewForm);
  MainIDEBar.tbDivider1          := CreateDivider(MainIDEBar.tbStandard);
  MainIDEBar.OpenFileSpeedBtn    := CreateButton(MainIDEBar.tbStandard , 'OpenFileSpeedBtn'   , 'laz_open'                  , @mnuOpenClicked, lisOpen);
  MainIDEBar.SaveSpeedBtn        := CreateButton(MainIDEBar.tbStandard , 'SaveSpeedBtn'       , 'laz_save'                  , @mnuSaveClicked, lisSave);
  MainIDEBar.SaveAllSpeedBtn     := CreateButton(MainIDEBar.tbStandard , 'SaveAllSpeedBtn'    , 'menu_save_all'             , @mnuSaveAllClicked, lisHintSaveAll);
  MainIDEBar.tbDivider2          := CreateDivider(MainIDEBar.tbStandard);
  MainIDEBar.ToggleFormSpeedBtn  := CreateButton(MainIDEBar.tbStandard , 'ToggleFormSpeedBtn' , 'menu_view_toggle_form_unit', @mnuToggleFormUnitCLicked, lisHintToggleFormUnit);

  MainIDEBar.ViewUnitsSpeedBtn   := CreateButton(MainIDEBar.tbViewDebug, 'ViewUnitsSpeedBtn'  , 'menu_view_units'           , @mnuViewUnitsClicked, lisHintViewUnits);
  MainIDEBar.ViewFormsSpeedBtn   := CreateButton(MainIDEBar.tbViewDebug, 'ViewFormsSpeedBtn'  , 'menu_view_forms'           , @mnuViewFormsClicked, lisHintViewForms);
  MainIDEBar.tbDivider3          := CreateDivider(MainIDEBar.tbViewDebug);
  MainIDEBar.BuildModeSpeedButton:= CreateButton(MainIDEBar.tbViewDebug, 'BuildModeSpeedButton', 'menu_compiler_options'    , @mnuChgBuildModeClicked, lisChangeBuildMode);
  MainIDEBar.RunSpeedButton      := CreateButton(MainIDEBar.tbViewDebug, 'RunSpeedButton'     , 'menu_run'                  , @mnuRunProjectClicked, lisRunButtonHint);
  MainIDEBar.PauseSpeedButton    := CreateButton(MainIDEBar.tbViewDebug, 'PauseSpeedButton'   , 'menu_pause'                , @mnuPauseProjectClicked, lisPause);
  MainIDEBar.StopSpeedButton     := CreateButton(MainIDEBar.tbViewDebug, 'StopSpeedButton'    , 'menu_stop'                 , @mnuStopProjectClicked, lisStop);
  MainIDEBar.StepIntoSpeedButton := CreateButton(MainIDEBar.tbViewDebug, 'StepIntoSpeedButton', 'menu_stepinto'             , @mnuStepIntoProjectClicked, lisHintStepInto);
  MainIDEBar.StepOverSpeedButton := CreateButton(MainIDEBar.tbViewDebug, 'StepOverpeedButton' , 'menu_stepover'             , @mnuStepOverProjectClicked, lisHintStepOver);
  MainIDEBar.StepOutSpeedButton  := CreateButton(MainIDEBar.tbViewDebug, 'StepOutSpeedButton' , 'menu_stepout'              , @mnuStepOutProjectClicked, lisHintStepOut);

  MainIDEBar.CreatePopupMenus(OwningComponent);

  MainIDEBar.OpenFileSpeedBtn.Style := tbsDropDown;
  MainIDEBar.OpenFileSpeedBtn.DropDownMenu := MainIDEBar.OpenFilePopUpMenu;
  MainIDEBar.OpenFilePopupMenu.OnPopup := @OpenFilePopupMenuPopup;

  MainIDEBar.BuildModeSpeedButton.Style:=tbsDropDown;
  MainIDEBar.BuildModeSpeedButton.DropdownMenu:=MainIDEBar.SetBuildModePopupMenu;
  MainIDEBar.SetBuildModePopupMenu.OnPopup := @SetBuildModePopupMenuPopup;
end;

procedure TMainIDE.SetupDialogs;
begin
  LazIDESelectDirectory:=@OnSelectDirectory;
  InitIDEFileDialog:=@OnInitIDEFileDialog;
  StoreIDEFileDialog:=@OnStoreIDEFileDialog;
  IDEMessageDialog:=@OnIDEMessageDialog;
  IDEQuestionDialog:=@OnIDEQuestionDialog;
  TestCompilerOptions:=@OnCompilerOptionsDialogTest;
  CheckCompOptsAndMainSrcForNewUnitEvent:=@OnCheckCompOptsAndMainSrcForNewUnit;
end;

procedure TMainIDE.SetupComponentPalette;
begin
  // Component palette
  MainIDEBar.ComponentPageControl := TPageControl.Create(OwningComponent);
  with MainIDEBar.ComponentPageControl do begin
    Name := 'ComponentPageControl';
    Align := alClient;
    Visible:=EnvironmentOptions.ComponentPaletteVisible;
    Parent := MainIDEBar;
  end;
end;

procedure TMainIDE.SetupHints;
var
  CurShowHint: boolean;
  AControl: TControl;
  i, j: integer;
begin
  if EnvironmentOptions=nil then exit;
  // update all hints in the component palette
  CurShowHint:=EnvironmentOptions.ShowHintsForComponentPalette;
  for i:=0 to MainIDEBar.ComponentPageControl.PageCount-1 do begin
    for j:=0 to MainIDEBar.ComponentPageControl.Page[i].ControlCount-1 do begin
      AControl:=MainIDEBar.ComponentPageControl.Page[i].Controls[j];
      AControl.ShowHint:=CurShowHint;
    end;
  end;
  // update all hints in main ide toolbars
  CurShowHint:=EnvironmentOptions.ShowHintsForMainSpeedButtons;
  for i:=0 to MainIDEBar.pnlSpeedButtons.ControlCount-1 do begin
    AControl:=MainIDEBar.pnlSpeedButtons.Controls[i];
    AControl.ShowHint:=CurShowHint;
  end;
end;

procedure TMainIDE.SetupObjectInspector;
begin
  IDECmdScopeObjectInspectorOnly.AddWindowClass(TObjectInspectorDlg);

  IDEWindowCreators.Add(DefaultObjectInspectorName,nil,@CreateIDEWindow,
   '0','120','+230','-120','',alNone,false,@OnGetLayout);

  ShowAnchorDesigner:=@mnuViewAnchorEditorClicked;
  ShowTabOrderEditor:=@mnuViewTabOrderClicked;
end;

procedure TMainIDE.SetupFormEditor;
begin
  GlobalDesignHook:=TPropertyEditorHook.Create(nil);
  GlobalDesignHook.GetPrivateDirectory:=AppendPathDelim(GetPrimaryConfigPath);
  GlobalDesignHook.AddHandlerGetMethodName(@OnPropHookGetMethodName);
  GlobalDesignHook.AddHandlerGetCompatibleMethods(@OnPropHookGetCompatibleMethods);
  GlobalDesignHook.AddHandlerGetMethods(@OnPropHookGetMethods);
  GlobalDesignHook.AddHandlerCompatibleMethodExists(@OnPropHookCompatibleMethodExists);
  GlobalDesignHook.AddHandlerMethodExists(@OnPropHookMethodExists);
  GlobalDesignHook.AddHandlerCreateMethod(@OnPropHookCreateMethod);
  GlobalDesignHook.AddHandlerShowMethod(@OnPropHookShowMethod);
  GlobalDesignHook.AddHandlerRenameMethod(@OnPropHookRenameMethod);
  GlobalDesignHook.AddHandlerBeforeAddPersistent(@OnPropHookBeforeAddPersistent);
  GlobalDesignHook.AddHandlerComponentRenamed(@OnPropHookComponentRenamed);
  GlobalDesignHook.AddHandlerModified(@OnPropHookModified);
  GlobalDesignHook.AddHandlerPersistentAdded(@OnPropHookPersistentAdded);
  GlobalDesignHook.AddHandlerPersistentDeleting(@OnPropHookPersistentDeleting);
  GlobalDesignHook.AddHandlerDeletePersistent(@OnPropHookDeletePersistent);
  GlobalDesignHook.AddHandlerObjectPropertyChanged(@OnPropHookObjectPropertyChanged);
  GlobalDesignHook.AddHandlerGetComponentNames(@OnPropHookGetComponentNames);
  GlobalDesignHook.AddHandlerGetComponent(@OnPropHookGetComponent);

  CreateFormEditor;
  FormEditor1.Obj_Inspector := ObjectInspector1;
  FormEditor1.OnSelectFrame := @OnSelectFrame;
end;

procedure TMainIDE.SetupSourceNotebook;
begin
  TSourceEditorManager.Create(OwningComponent);
  SourceEditorManager.RegisterChangeEvent(semWindowFocused, @OnSrcNoteBookActivated);
  SourceEditorManager.OnAddJumpPoint := @OnSrcNoteBookAddJumpPoint;
  SourceEditorManager.OnCloseClicked := @OnSrcNotebookFileClose;
  SourceEditorManager.OnClickLink := @OnSrcNoteBookClickLink;
  SourceEditorManager.OnMouseLink := @OnSrcNoteBookMouseLink;
  SourceEditorManager.OnGetIndent := @OnSrcNoteBookGetIndent;
  SourceEditorManager.OnCurrentCodeBufferChanged:=@OnSrcNotebookCurCodeBufferChanged;
  SourceEditorManager.OnDeleteLastJumpPoint := @OnSrcNotebookDeleteLastJumPoint;
  SourceEditorManager.RegisterChangeEvent(semEditorActivate, @OnSrcNotebookEditorActived);
  SourceEditorManager.RegisterChangeEvent(semEditorStatus, @OnSrcNotebookEditorChanged);
  SourceEditorManager.OnEditorMoved := @OnSrcNotebookEditorMoved;
  SourceEditorManager.RegisterChangeEvent(semEditorDestroy, @OnSrcNotebookEditorClosed);
  SourceEditorManager.OnPlaceBookmark := @OnSrcNotebookEditorPlaceBookmark;
  SourceEditorManager.OnClearBookmark := @OnSrcNotebookEditorClearBookmark;
  SourceEditorManager.OnClearBookmarkId := @OnSrcNotebookEditorClearBookmarkId;
  SourceEditorManager.OnSetBookmark := @OnSrcNotebookEditorDoSetBookmark;
  SourceEditorManager.OnGotoBookmark := @OnSrcNotebookEditorDoGotoBookmark;
  SourceEditorManager.OnEditorPropertiesClicked := @mnuEnvEditorOptionsClicked;
  SourceEditorManager.OnFindDeclarationClicked := @OnSrcNotebookFindDeclaration;
  SourceEditorManager.OnInitIdentCompletion :=@OnSrcNotebookInitIdentCompletion;
  SourceEditorManager.OnShowCodeContext :=@OnSrcNotebookShowCodeContext;
  SourceEditorManager.OnJumpToHistoryPoint := @OnSrcNotebookJumpToHistoryPoint;
  SourceEditorManager.OnOpenFileAtCursorClicked := @OnSrcNotebookFileOpenAtCursor;
  SourceEditorManager.OnProcessUserCommand := @OnProcessIDECommand;
  SourceEditorManager.OnReadOnlyChanged := @OnSrcNotebookReadOnlyChanged;
  SourceEditorManager.OnShowHintForSource := @OnSrcNotebookShowHintForSource;
  SourceEditorManager.OnShowUnitInfo := @OnSrcNoteBookShowUnitInfo;
  SourceEditorManager.OnToggleFormUnitClicked := @OnSrcNotebookToggleFormUnit;
  SourceEditorManager.OnToggleObjectInspClicked:= @OnSrcNotebookToggleObjectInsp;
  SourceEditorManager.OnViewJumpHistory := @OnSrcNotebookViewJumpHistory;
  SourceEditorManager.OnPopupMenu := @OnSrcNoteBookPopupMenu;
  SourceEditorManager.OnNoteBookCloseQuery := @OnSrcNoteBookCloseQuery;
  SourceEditorManager.OnPackageForSourceEditor := @PkgBoss.GetPackageOfSourceEditor;
  DebugBoss.ConnectSourceNotebookEvents;

  OnSearchResultsViewSelectionChanged := @SearchResultsViewSelectionChanged;
  OnSearchAgainClicked := @FindInFilesDialog.InitFromLazSearch;

  // connect search menu to sourcenotebook
  MainIDEBar.itmSearchFind.OnClick := @SourceEditorManager.FindClicked;
  MainIDEBar.itmSearchFindNext.OnClick := @SourceEditorManager.FindNextClicked;
  MainIDEBar.itmSearchFindPrevious.OnClick := @SourceEditorManager.FindPreviousClicked;
  MainIDEBar.itmSearchFindInFiles.OnClick := @mnuSearchFindInFiles;
  MainIDEBar.itmSearchReplace.OnClick := @SourceEditorManager.ReplaceClicked;
  MainIDEBar.itmIncrementalFind.OnClick := @SourceEditorManager.IncrementalFindClicked;
  MainIDEBar.itmGotoLine.OnClick := @SourceEditorManager.GotoLineClicked;
  MainIDEBar.itmJumpBack.OnClick := @SourceEditorManager.JumpBackClicked;
  MainIDEBar.itmJumpForward.OnClick := @SourceEditorManager.JumpForwardClicked;
  MainIDEBar.itmAddJumpPoint.OnClick := @SourceEditorManager.AddJumpPointClicked;
  MainIDEBar.itmJumpHistory.OnClick := @SourceEditorManager.ViewJumpHistoryClicked;
  MainIDEBar.itmJumpToNextBookmark.OnClick := @SourceEditorManager.BookMarkNextClicked;
  MainIDEBar.itmJumpToPrevBookmark.OnClick := @SourceEditorManager.BookMarkPrevClicked;
  MainIDEBar.itmFindBlockStart.OnClick:=@mnuSearchFindBlockStart;
  MainIDEBar.itmFindBlockOtherEnd.OnClick:=@mnuSearchFindBlockOtherEnd;
  MainIDEBar.itmFindDeclaration.OnClick:=@mnuSearchFindDeclaration;
  MainIDEBar.itmOpenFileAtCursor.OnClick:=@mnuOpenFileAtCursorClicked;

  SourceEditorManager.InitMacros(GlobalMacroList);
  EditorMacroListViewer.OnKeyMapReloaded := @SourceEditorManager.ReloadEditorOptions;
end;

procedure TMainIDE.SetupCodeMacros;
begin
  CreateStandardCodeMacros;
end;

procedure TMainIDE.SetupControlSelection;
begin
  TheControlSelection:=TControlSelection.Create;
  TheControlSelection.OnChange:=@OnControlSelectionChanged;
  TheControlSelection.OnPropertiesChanged:=@OnControlSelectionPropsChanged;
  TheControlSelection.OnSelectionFormChanged:=@OnControlSelectionFormChanged;
  GlobalDesignHook.AddHandlerGetSelection(@OnGetDesignerSelection);
end;

procedure TMainIDE.SetupIDECommands;
begin
  IDECommandList:=EditorOpts.KeyMap;
  IDECommands.OnExecuteIDECommand:=@OnExecuteIDECommand;
  IDECommands.OnExecuteIDEShortCut:=@OnExecuteIDEShortCut;
  CreateStandardIDECommandScopes;
  IDECmdScopeSrcEdit.AddWindowClass(TSourceEditorWindowInterface);
  IDECmdScopeSrcEdit.AddWindowClass(nil);
  IDECmdScopeSrcEditOnly.AddWindowClass(TSourceEditorWindowInterface);

  IDECmdScopeSrcEditOnlyTmplEdit.AddWindowClass(TLazSynPluginTemplateEditForm);
  IDECmdScopeSrcEditOnlyTmplEditOff.AddWindowClass(TLazSynPluginTemplateEditFormOff);

  IDECmdScopeSrcEditOnlySyncroEditSel.AddWindowClass(TLazSynPluginSyncroEditFormSel);
  IDECmdScopeSrcEditOnlySyncroEdit.AddWindowClass(TLazSynPluginSyncroEditForm);
  IDECmdScopeSrcEditOnlySyncroEditOff.AddWindowClass(TLazSynPluginSyncroEditFormOff);

  EditorOpts.KeyMap.DefineCommandCategories;
end;

procedure TMainIDE.SetupIDEMsgQuickFixItems;
begin
  IDEQuickFixes:=TIDEQuickFixes.Create(Self);
  InitCodeBrowserQuickFixItems;
  InitFindUnitQuickFixItems;
  InitInspectChecksumChangedQuickFixItems;
  InitUnitDependenciesQuickFixItems;
end;

procedure TMainIDE.SetupStartProject;

  function AskIfLoadLastFailingProject: boolean;
  begin
    debugln(['AskIfLoadLastFailingProject START']);
    Result:=IDEQuestionDialog(lisOpenProject2,
      Format(lisAnErrorOccuredAtLastStartupWhileLoadingLoadThisPro,
             [EnvironmentOptions.LastSavedProjectFile, LineEnding+LineEnding]),
      mtWarning,
      [mrYes, lisOpenProjectAgain, mrNoToAll, lisStartWithANewProject])=mrYes;
    debugln(['AskIfLoadLastFailingProject END ',dbgs(Result)]);
  end;

var
  ProjectLoaded: Boolean;
  AProjectFilename: String;
  CmdLineFiles: TStrings;
  i: Integer;
  OpenFlags: TOpenFlags;
  AFilename: String;
begin
  {$IFDEF IDE_DEBUG}
  debugln('TMainIDE.SetupStartProject A ***********');
  {$ENDIF}
  {$IFDEF IDE_MEM_CHECK}CheckHeapWrtMemCnt('TMainIDE.SetupStartProject A');{$ENDIF}
  // load command line project or last project or create a new project
  CmdLineFiles:=ExtractCmdLineFilenames;
  try
    ProjectLoaded:=false;

    // try command line project
    if (CmdLineFiles<>nil) and (CmdLineFiles.Count>0) then begin
      AProjectFilename:=CmdLineFiles[0];
      if (CompareFileExt(AProjectFilename,'.lpr',false)=0) then
        AProjectFilename:=ChangeFileExt(AProjectFilename,'.lpi');
      // only try to load .lpi files, other files are loaded later
      if (CompareFileExt(AProjectFilename,'.lpi',false)=0) then begin
        AProjectFilename:=CleanAndExpandFilename(AProjectFilename);
        if FileExistsUTF8(AProjectFilename) then begin
          CmdLineFiles.Delete(0);
          ProjectLoaded:=(DoOpenProjectFile(AProjectFilename,[])=mrOk);
        end;
      end;
    end;

    // try loading last project if lazarus didn't fail last time
    if (not ProjectLoaded)
    and (not SkipAutoLoadingLastProject)
    and (EnvironmentOptions.OpenLastProjectAtStart)
    and (EnvironmentOptions.LastSavedProjectFile<>'')
    and (EnvironmentOptions.LastSavedProjectFile<>RestoreProjectClosed)
    and (FileExistsCached(EnvironmentOptions.LastSavedProjectFile))
    then begin
      if (not IDEProtocolOpts.LastProjectLoadingCrashed)
      or AskIfLoadLastFailingProject then begin
        // protocol that the IDE is trying to load the last project and did not
        // yet succeed
        IDEProtocolOpts.LastProjectLoadingCrashed := True;
        IDEProtocolOpts.Save;
        // try loading the project
        ProjectLoaded:=
          (DoOpenProjectFile(EnvironmentOptions.LastSavedProjectFile,[])=mrOk);
        // protocol that the IDE was able to open the project without crashing
        IDEProtocolOpts.LastProjectLoadingCrashed := false;
        IDEProtocolOpts.Save;
        if not ProjectLoaded then begin
          DoCloseProject;
        end;
      end;
    end;
    {$IFDEF IDE_MEM_CHECK}CheckHeapWrtMemCnt('TMainIDE.SetupStartProject B');{$ENDIF}

    if (not ProjectLoaded) then
    begin
      if EnvironmentOptions.OpenLastProjectAtStart
      and (EnvironmentOptions.LastSavedProjectFile=RestoreProjectClosed) then begin
        // IDE was closed without a project => restore that state
      end else begin
        // create new project
        DoNewProject(ProjectDescriptorApplication);
      end;
    end;

    // load the cmd line files
    if CmdLineFiles<>nil then begin
      for i:=0 to CmdLineFiles.Count-1 do
      Begin
        AFilename:=CleanAndExpandFilename(CmdLineFiles.Strings[i]);
        if not FileExistsCached(AFilename) then begin
          debugln(['WARNING: command line file not found: "',AFilename,'"']);
          continue;
        end;
        if Project1=nil then begin
          // to open a file a project is needed
          // => create a project
          DoNewProject(ProjectDescriptorEmptyProject);
        end;
        if CompareFileExt(AFilename,'.lpk',false)=0 then begin
          if PkgBoss.DoOpenPackageFile(AFilename,[pofAddToRecent,pofMultiOpen],true)=mrAbort
          then
            break;
        end else begin
          OpenFlags:=[ofAddToRecent,ofRegularFile];
          if i<CmdLineFiles.Count then
            Include(OpenFlags,ofMultiOpen);
          if DoOpenEditorFile(AFilename,-1,-1,OpenFlags)=mrAbort then begin
            break;
          end;
        end;
      end;
    end;

    if Project1=nil then
      DoNoProjectWizard(nil);

    {$IFDEF IDE_DEBUG}
    debugln('TMainIDE.Create B');
    {$ENDIF}
    {$IFDEF IDE_MEM_CHECK}CheckHeapWrtMemCnt('TMainIDE.SetupStartProject C');{$ENDIF}
  finally
    CmdLineFiles.Free;
  end;
end;

procedure TMainIDE.SetupRemoteControl;
var
  Filename: String;
begin
  debugln(['TMainIDE.SetupRemoteControl ']);
  // delete old remote commands
  Filename:=GetRemoteControlFilename;
  if FileExistsUTF8(Filename) then
    DeleteFileUTF8(Filename);
  // start timer
  FRemoteControlTimer:=TTimer.Create(OwningComponent);
  FRemoteControlTimer.Interval:=500;
  FRemoteControlTimer.OnTimer:=@OnRemoteControlTimer;
  FRemoteControlTimer.Enabled:=true;
end;

procedure TMainIDE.SetupIDEWindowsLayout;
begin
  IDEWindowCreators.Add(NonModalIDEWindowNames[nmiwMessagesViewName],
    nil,@CreateIDEWindow,'250','75%','+70%','+100',
    NonModalIDEWindowNames[nmiwSourceNoteBookName],alBottom,false,@OnGetLayout);
  IDEWindowCreators.Add(NonModalIDEWindowNames[nmiwCodeExplorerName],
    nil,@CreateIDEWindow,'72%','120','+170','-200',
    NonModalIDEWindowNames[nmiwSourceNoteBookName],alRight);

  IDEWindowCreators.Add(NonModalIDEWindowNames[nmiwUnitDependenciesName],
    nil,@CreateIDEWindow,'200','200','','');
  IDEWindowCreators.Add(NonModalIDEWindowNames[nmiwFPDocEditorName],
    nil,@CreateIDEWindow,'250','75%','+70%','+120');
  //IDEWindowCreators.Add(NonModalIDEWindowNames[nmiwClipbrdHistoryName],
  //  nil,@CreateIDEWindow,'250','200','','');
  IDEWindowCreators.Add(NonModalIDEWindowNames[nmiwProjectInspector],
    nil,@CreateIDEWindow,'200','150','+300','+400');
  IDEWindowCreators.Add(NonModalIDEWindowNames[nmiwSearchResultsViewName],
    nil,@CreateIDEWindow,'250','250','+70%','+300');
  IDEWindowCreators.Add(NonModalIDEWindowNames[nmiwAnchorEditor],
    nil,@CreateIDEWindow,'250','250','','');
  IDEWindowCreators.Add(NonModalIDEWindowNames[nmiwTabOrderEditor],
    nil,@CreateIDEWindow,'270','270','','');
  IDEWindowCreators.Add(NonModalIDEWindowNames[nmiwCodeBrowser],
    nil,@CreateIDEWindow,'200','200','+650','+500');
  IDEWindowCreators.Add(NonModalIDEWindowNames[nmiwIssueBrowser],
    nil,@CreateIDEWindow,'250','250','','');
  IDEWindowCreators.Add(NonModalIDEWindowNames[nmiwJumpHistory],
    nil,@CreateIDEWindow,'250','250','','');
  IDEWindowCreators.Add(NonModalIDEWindowNames[nmiwComponentList],
    nil,@CreateIDEWindow,'250','250','','');
  IDEWindowCreators.Add(NonModalIDEWindowNames[nmiwEditorFileManager],
    nil,@CreateIDEWindow,'200','200','','');
end;

procedure TMainIDE.RestoreIDEWindows;
begin
  DoCallNotifyHandler(lihtIDERestoreWindows);
  if IDEDockMaster=nil then
    IDEWindowCreators.RestoreSimpleLayout;
end;

procedure TMainIDE.FreeIDEWindows;
var
  i: Integer;
  AForm: TCustomForm;
begin
  i:=Screen.CustomFormCount-1;
  while i>=0 do begin
    AForm:=Screen.CustomForms[i];
    if (AForm<>MainIDEBar)
    and ((AForm.Owner=MainIDEBar) or (AForm.Owner=Self)) then begin
      DebugLn(['TMainIDE.FreeIDEWindows ',dbgsName(AForm)]);
      AForm.Free;
    end;
    i:=Math.Min(i,Screen.CustomFormCount)-1;
  end;
end;

function TMainIDE.CloseQueryIDEWindows: boolean;
var
  i: Integer;
  AForm: TCustomForm;
begin
  for i:=0 to Screen.CustomFormCount-1 do begin
    AForm:=Screen.CustomForms[i];
    if AForm=MainIDEBar then continue;
    if AForm.Designer<>nil then continue;
    if AForm.Parent<>nil then continue;
    if not AForm.CloseQuery then exit(false);
  end;
  Result:=true;
end;

function TMainIDE.GetActiveDesignerSkipMainBar: TComponentEditorDesigner;
// returns the designer that is currently active
// the MainIDEBar is ignored
var
  ActForm: TCustomForm;
  ActControl: TWinControl;
begin
  ActForm:=Screen.ActiveCustomForm;
  if ActForm=MainIDEBar then
  begin
    ActControl:=ActForm.ActiveControl;
    if (ActControl<>nil) and (GetFirstParentForm(ActControl)<>MainIDEBar) then
      exit(nil); // a docked form has focus
    if Screen.CustomFormZOrderCount < 2 then exit(nil);
    ActForm:=Screen.CustomFormsZOrdered[1];
  end;
  if (ActForm<>nil) and (ActForm.Designer is TComponentEditorDesigner) then
    Result := TComponentEditorDesigner(ActForm.Designer)
  else
    Result := nil;
end;

procedure TMainIDE.ReloadMenuShortCuts;
begin
  //LoadMenuShortCuts;
end;

{------------------------------------------------------------------------------}
procedure TMainIDE.SetupMainMenu;
begin
  inherited SetupMainMenu;
  mnuMain.MenuItem:=MainIDEBar.mnuMainMenu.Items;
  SetupFileMenu;
  SetupEditMenu;
  SetupSearchMenu;
  SetupViewMenu;
  SetupSourceMenu;
  SetupProjectMenu;
  SetupRunMenu;
  SetupPackageMenu;
  SetupToolsMenu;
  SetupWindowsMenu;
  SetupHelpMenu;
end;

procedure TMainIDE.SetupStandardIDEMenuItems;
begin
  IDEMenuRoots:=TIDEMenuRoots.Create;
  RegisterStandardSourceTabMenuItems;
  RegisterStandardSourceEditorMenuItems;
  RegisterStandardMessagesViewMenuItems;
  RegisterStandardCodeExplorerMenuItems;
  RegisterStandardCodeTemplatesMenuItems;
  RegisterStandardDesignerMenuItems;
end;

procedure TMainIDE.SetupStandardProjectTypes;
begin
  NewIDEItems.Add(TNewLazIDEItemCategoryFile.Create(FileDescGroupName));
  NewIDEItems.Add(TNewLazIDEItemCategoryInheritedItem.Create(InheritedItemsGroupName));
  NewIDEItems.Add(TNewLazIDEItemCategoryProject.Create(ProjDescGroupName));

  // file descriptors
  LazProjectFileDescriptors:=TLazProjectFileDescriptors.Create;
  LazProjectFileDescriptors.DefaultPascalFileExt:=
                        PascalExtension[EnvironmentOptions.PascalFileExtension];
  RegisterProjectFileDescriptor(TFileDescPascalUnit.Create);
  RegisterProjectFileDescriptor(TFileDescPascalUnitWithForm.Create);
  RegisterProjectFileDescriptor(TFileDescPascalUnitWithDataModule.Create);
  RegisterProjectFileDescriptor(TFileDescPascalUnitWithFrame.Create);
  RegisterProjectFileDescriptor(TFileDescText.Create);

  RegisterProjectFileDescriptor(TFileDescInheritedComponent.Create, InheritedItemsGroupName);

  // project descriptors
  LazProjectDescriptors:=TLazProjectDescriptors.Create;
  RegisterProjectDescriptor(TProjectApplicationDescriptor.Create);
  RegisterProjectDescriptor(TProjectSimpleProgramDescriptor.Create);
  RegisterProjectDescriptor(TProjectProgramDescriptor.Create);
  RegisterProjectDescriptor(TProjectConsoleApplicationDescriptor.Create);
  RegisterProjectDescriptor(TProjectLibraryDescriptor.Create);
end;

procedure TMainIDE.SetupFileMenu;
begin
  inherited SetupFileMenu;
  mnuFile.OnClick:=@mnuFileClicked;
  with MainIDEBar do begin
    itmFileNewUnit.OnClick := @mnuNewUnitClicked;
    itmFileNewForm.OnClick := @mnuNewFormClicked;
    itmFileNewOther.OnClick := @mnuNewOtherClicked;
    itmFileOpen.OnClick := @mnuOpenClicked;
    itmFileRevert.OnClick := @mnuRevertClicked;
    SetRecentFilesMenu;
    itmFileSave.OnClick := @mnuSaveClicked;
    itmFileSaveAs.OnClick := @mnuSaveAsClicked;
    itmFileSaveAll.OnClick := @mnuSaveAllClicked;
    itmFileExportHtml.OnClick  := @mnuExportHtml;
    itmFileClose.Enabled := False;
    itmFileClose.OnClick := @mnuCloseClicked;
    itmFileCloseAll.Enabled := False;
    itmFileCloseAll.OnClick := @mnuCloseAllClicked;
    itmFileCleanDirectory.OnClick := @mnuCleanDirectoryClicked;
    itmFileRestart.OnClick := @mnuRestartClicked;
    itmFileQuit.OnClick := @mnuQuitClicked;
  end;
end;

procedure TMainIDE.SetupEditMenu;
begin
  inherited SetupEditMenu;
  mnuEdit.OnClick:=@mnuEditClicked;
  with MainIDEBar do begin
    itmEditUndo.OnClick:=@mnuEditUndoClicked;
    itmEditRedo.OnClick:=@mnuEditRedoClicked;
    itmEditCut.OnClick:=@mnuEditCutClicked;
    itmEditCopy.OnClick:=@mnuEditCopyClicked;
    itmEditPaste.OnClick:=@mnuEditPasteClicked;
    itmEditSelectAll.OnClick:=@mnuEditSelectAllClick;
    itmEditSelectToBrace.OnClick:=@mnuEditSelectToBraceClick;
    itmEditSelectCodeBlock.OnClick:=@mnuEditSelectCodeBlockClick;
    itmEditSelectWord.OnClick:=@mnuEditSelectWordClick;
    itmEditSelectLine.OnClick:=@mnuEditSelectLineClick;
    itmEditSelectParagraph.OnClick:=@mnuEditSelectParagraphClick;
    itmEditIndentBlock.OnClick:=@mnuEditIndentBlockClicked;
    itmEditUnindentBlock.OnClick:=@mnuEditUnindentBlockClicked;
    itmEditUpperCaseBlock.OnClick:=@mnuEditUpperCaseBlockClicked;
    itmEditLowerCaseBlock.OnClick:=@mnuEditLowerCaseBlockClicked;
    itmEditSwapCaseBlock.OnClick:=@mnuEditSwapCaseBlockClicked;
    itmEditSortBlock.OnClick:=@mnuEditSortBlockClicked;
    itmEditTabsToSpacesBlock.OnClick:=@mnuEditTabsToSpacesBlockClicked;
    itmEditSelectionBreakLines.OnClick:=@mnuEditSelectionBreakLinesClicked;
    itmEditInsertCharacter.OnClick:=@mnuEditInsertCharacterClicked;
  end;
end;

procedure TMainIDE.SetupSearchMenu;
begin
  inherited SetupSearchMenu;
//  mnuSearch.OnClick:=@mnuSearchClicked;
  with MainIDEBar do begin
    itmSearchFindIdentifierRefs.OnClick:=@mnuSearchFindIdentifierRefsClicked;
    itmGotoIncludeDirective.OnClick:=@mnuGotoIncludeDirectiveClicked;
    itmSearchProcedureList.OnClick := @mnuSearchProcedureList;
    itmSetFreeBookmark.OnClick := @mnuSetFreeBookmark;
  end;
end;

procedure TMainIDE.SetupViewMenu;
begin
  inherited SetupViewMenu;
  with MainIDEBar do begin
    itmViewToggleFormUnit.OnClick := @mnuToggleFormUnitClicked;
    itmViewInspector.OnClick := @mnuViewInspectorClicked;
    itmViewSourceEditor.OnClick := @mnuViewSourceEditorClicked;
    itmViewCodeExplorer.OnClick := @mnuViewCodeExplorerClick;
    itmViewCodeBrowser.OnClick := @mnuViewCodeBrowserClick;
    itmViewRestrictionBrowser.OnClick := @mnuViewRestrictionBrowserClick;
    itmViewComponents.OnClick := @mnuViewComponentsClick;
    itmMacroListView.OnClick := @mnuViewMacroListClick;
    itmViewFPDocEditor.OnClick := @mnuViewFPDocEditorClicked;
    itmViewMessage.OnClick := @mnuViewMessagesClick;
    itmViewSearchResults.OnClick := @mnuViewSearchResultsClick;
    itmViewAnchorEditor.OnClick := @mnuViewAnchorEditorClicked;
    itmViewTabOrder.OnClick := @mnuViewTabOrderClicked;
    itmViewComponentPalette.OnClick := @mnuViewComponentPaletteClicked;
    itmViewIDESpeedButtons.OnClick := @mnuViewIDESpeedButtonsClicked;

    itmViewFPCInfo.OnClick:=@mnuViewFPCInfoClicked;
    itmViewIDEInfo.OnClick:=@mnuViewIDEInfoClicked;
    itmViewNeedBuild.OnClick:=@mnuViewNeedBuildClicked;
  end;
end;

procedure TMainIDE.SetupSourceMenu;
begin
  inherited SetupSourceMenu;
  mnuSource.OnClick:=@mnuSourceClicked;
  with MainIDEBar do begin
    itmSourceCommentBlock.OnClick:=@mnuSourceCommentBlockClicked;
    itmSourceUncommentBlock.OnClick:=@mnuSourceUncommentBlockClicked;
    itmSourceToggleComment.OnClick:=@mnuSourceToggleCommentClicked;
    itmSourceEncloseBlock.OnClick:=@mnuSourceEncloseBlockClicked;
    itmSourceEncloseInIFDEF.OnClick:=@mnuSourceEncloseInIFDEFClicked;
    itmSourceCompleteCode.OnClick:=@mnuSourceCompleteCodeClicked;
    itmSourceUseUnit.OnClick:=@mnuSourceUseUnitClicked;
    // CodeTool Checks
    itmSourceSyntaxCheck.OnClick := @mnuSourceSyntaxCheckClicked;
    itmSourceGuessUnclosedBlock.OnClick := @mnuSourceGuessUnclosedBlockClicked;
    itmSourceGuessMisplacedIFDEF.OnClick := @mnuSourceGuessMisplacedIFDEFClicked;
    // Refactor
    itmRefactorRenameIdentifier.OnClick:=@mnuRefactorRenameIdentifierClicked;
    itmRefactorExtractProc.OnClick:=@mnuRefactorExtractProcClicked;
    itmRefactorInvertAssignment.OnClick:=@mnuRefactorInvertAssignmentClicked;
    // itmRefactorAdvanced
    itmRefactorShowAbstractMethods.OnClick:=@mnuRefactorShowAbstractMethodsClicked;
    itmRefactorShowEmptyMethods.OnClick:=@mnuRefactorShowEmptyMethodsClicked;
    itmRefactorShowUnusedUnits.OnClick:=@mnuRefactorShowUnusedUnitsClicked;
    {$IFDEF EnableFindOverloads}
    itmRefactorFindOverloads.OnClick:=@mnuRefactorFindOverloadsClicked;
    {$ENDIF}
    // itmRefactorTools
    itmRefactorMakeResourceString.OnClick := @mnuRefactorMakeResourceStringClicked;
    // insert CVS keyword
    itmSourceInsertCVSAuthor.OnClick:=@mnuSourceInsertCVSAuthorClick;
    itmSourceInsertCVSDate.OnClick:=@mnuSourceInsertCVSDateClick;
    itmSourceInsertCVSHeader.OnClick:=@mnuSourceInsertCVSHeaderClick;
    itmSourceInsertCVSID.OnClick:=@mnuSourceInsertCVSIDClick;
    itmSourceInsertCVSLog.OnClick:=@mnuSourceInsertCVSLogClick;
    itmSourceInsertCVSName.OnClick:=@mnuSourceInsertCVSNameClick;
    itmSourceInsertCVSRevision.OnClick:=@mnuSourceInsertCVSRevisionClick;
    itmSourceInsertCVSSource.OnClick:=@mnuSourceInsertCVSSourceClick;
    // insert general
    itmSourceInsertGPLNotice.OnClick:=@mnuSourceInsertGPLNoticeClick;
    itmSourceInsertGPLNoticeTranslated.OnClick:=@mnuSourceInsertGPLNoticeTranslatedClick;
    itmSourceInsertLGPLNotice.OnClick:=@mnuSourceInsertLGPLNoticeClick;
    itmSourceInsertLGPLNoticeTranslated.OnClick:=@mnuSourceInsertLGPLNoticeTranslatedClick;
    itmSourceInsertModifiedLGPLNotice.OnClick:=@mnuSourceInsertModifiedLGPLNoticeClick;
    itmSourceInsertModifiedLGPLNoticeTranslated.OnClick:=@mnuSourceInsertModifiedLGPLNoticeTranslatedClick;
    itmSourceInsertMITNotice.OnClick:=@mnuSourceInsertMITNoticeClick;
    itmSourceInsertMITNoticeTranslated.OnClick:=@mnuSourceInsertMITNoticeTranslatedClick;
    itmSourceInsertUsername.OnClick:=@mnuSourceInsertUsernameClick;
    itmSourceInsertDateTime.OnClick:=@mnuSourceInsertDateTimeClick;
    itmSourceInsertChangeLogEntry.OnClick:=@mnuSourceInsertChangeLogEntryClick;
    itmSourceInsertGUID.OnClick:=@mnuSourceInsertGUID;
    itmSourceInsertFilename.OnClick:=@mnuSourceInsertFilename;
    // Tools
    itmSourceUnitInfo.OnClick := @mnuSourceUnitInfoClicked;
    itmSourceUnitDependencies.OnClick := @mnuSourceUnitDependenciesClicked;
  end;
end;

procedure TMainIDE.SetupProjectMenu;
begin
  inherited SetupProjectMenu;
  mnuProject.OnClick:=@mnuProjectClicked;
  with MainIDEBar do begin
    itmProjectNew.OnClick := @mnuNewProjectClicked;
    itmProjectNewFromFile.OnClick := @mnuNewProjectFromFileClicked;
    itmProjectOpen.OnClick := @mnuOpenProjectClicked;
    SetRecentProjectFilesMenu;
    itmProjectClose.OnClick := @mnuCloseProjectClicked;
    itmProjectSave.OnClick := @mnuSaveProjectClicked;
    itmProjectSaveAs.OnClick := @mnuSaveProjectAsClicked;
    itmProjectPublish.OnClick := @mnuPublishProjectClicked;
    itmProjectInspector.OnClick := @mnuProjectInspectorClicked;
    itmProjectOptions.OnClick := @mnuProjectOptionsClicked;
    itmProjectAddTo.OnClick := @mnuAddToProjectClicked;
    itmProjectRemoveFrom.OnClick := @mnuRemoveFromProjectClicked;
    itmProjectViewUnits.OnClick := @mnuViewUnitsClicked;
    itmProjectViewForms.OnClick := @mnuViewFormsClicked;
    itmProjectViewSource.OnClick := @mnuViewProjectSourceClicked;
  end;
end;

procedure TMainIDE.SetupRunMenu;
begin
  inherited SetupRunMenu;
  mnuRun.OnClick:=@mnuRunClicked;
  with MainIDEBar do begin
    itmRunMenuCompile.OnClick := @mnuCompileProjectClicked;
    itmRunMenuBuild.OnClick := @mnuBuildProjectClicked;
    itmRunMenuQuickCompile.OnClick := @mnuQuickCompileProjectClicked;
    itmRunMenuCleanUpAndBuild.OnClick := @mnuCleanUpAndBuildProjectClicked;
    itmRunMenuBuildManyModes.OnClick := @mnuBuildManyModesClicked;
    itmRunMenuAbortBuild.OnClick := @mnuAbortBuildProjectClicked;
    itmRunMenuRun.OnClick := @mnuRunProjectClicked;
    itmRunMenuPause.OnClick := @mnuPauseProjectClicked;
    itmRunMenuShowExecutionPoint.OnClick := @mnuShowExecutionPointClicked;
    itmRunMenuStepInto.OnClick := @mnuStepIntoProjectClicked;
    itmRunMenuStepOver.OnClick := @mnuStepOverProjectClicked;
    itmRunMenuStepOut.OnClick := @mnuStepOutProjectClicked;
    itmRunMenuRunToCursor.OnClick := @mnuRunToCursorProjectClicked;
    itmRunMenuStop.OnClick := @mnuStopProjectClicked;
    itmRunMenuAttach.OnClick := @mnuAttachDebuggerClicked;
    itmRunMenuDetach.OnClick := @mnuDetachDebuggerClicked;
    itmRunMenuRunParameters.OnClick := @mnuRunParametersClicked;
    itmRunMenuBuildFile.OnClick := @mnuBuildFileClicked;
    itmRunMenuRunFile.OnClick := @mnuRunFileClicked;
    itmRunMenuConfigBuildFile.OnClick := @mnuConfigBuildFileClicked;
  end;
end;

procedure TMainIDE.SetupPackageMenu;
begin
  inherited SetupPackageMenu;
  mnuPackage.OnClick:=@mnuPackageClicked;
end;

procedure TMainIDE.SetupToolsMenu;
begin
  inherited SetupToolsMenu;
  with MainIDEBar do begin
    itmEnvGeneralOptions.OnClick := @mnuEnvGeneralOptionsClicked;
    itmToolRescanFPCSrcDir.OnClick := @mnuEnvRescanFPCSrcDirClicked;
    itmEnvCodeTemplates.OnClick := @mnuEnvCodeTemplatesClicked;
    itmEnvCodeToolsDefinesEditor.OnClick := @mnuEnvCodeToolsDefinesEditorClicked;

    itmToolConfigure.OnClick := @mnuToolConfigureUserExtToolsClicked;
    itmToolDiff.OnClick := @mnuToolDiffClicked;

    itmToolCheckLFM.OnClick := @mnuToolCheckLFMClicked;
    itmToolConvertDFMtoLFM.OnClick := @mnuToolConvertDFMtoLFMClicked;
    itmToolConvertDelphiUnit.OnClick := @mnuToolConvertDelphiUnitClicked;
    itmToolConvertDelphiProject.OnClick := @mnuToolConvertDelphiProjectClicked;
    itmToolConvertDelphiPackage.OnClick := @mnuToolConvertDelphiPackageClicked;
    itmToolConvertEncoding.OnClick := @mnuToolConvertEncodingClicked;
    itmToolManageExamples.OnClick := @mnuToolManageExamplesClicked;
    itmToolBuildLazarus.OnClick := @mnuToolBuildLazarusClicked;
    itmToolConfigureBuildLazarus.OnClick := @mnuToolConfigBuildLazClicked;
    // Set initial caption for Build Lazarus item. Will be changed in BuildLazDialog.
    if Assigned(MiscellaneousOptions) then
      itmToolBuildLazarus.Caption:=
        Format(lisMenuBuildLazarusProf, [MiscellaneousOptions.BuildLazOpts.Name]);
  end;
  UpdateExternalUserToolsInMenu;
end;

procedure TMainIDE.SetupWindowsMenu;
begin
  inherited SetupWindowsMenu;
  with MainIDEBar do begin
    itmWindowManager.OnClick := @mnuWindowManagerClicked;
  end;
end;

procedure TMainIDE.SetupHelpMenu;
begin
  inherited SetupHelpMenu;
end;

procedure TMainIDE.LoadMenuShortCuts;
begin
  inherited LoadMenuShortCuts;
  SourceEditorManager.SetupShortCuts;
  DebugBoss.SetupMainBarShortCuts;
end;

procedure TMainIDE.ConnectMainBarEvents;
begin
  MainIDEBar.OnClose := @MainIDEFormClose;
  MainIDEBar.OnCloseQuery := @MainIDEFormCloseQuery;
end;

{------------------------------------------------------------------------------}

procedure TMainIDE.mnuToggleFormUnitClicked(Sender: TObject);
begin
  DoBringToFrontFormOrUnit;
end;

procedure TMainIDE.mnuViewAnchorEditorClicked(Sender: TObject);
begin
  DoViewAnchorEditor;
end;

procedure TMainIDE.mnuViewTabOrderClicked(Sender: TObject);
begin
  DoViewTabOrderEditor;
end;

procedure TMainIDE.mnuViewComponentPaletteClicked(Sender: TObject);
begin
  DoToggleViewComponentPalette;
end;

procedure TMainIDE.mnuViewIDESpeedButtonsClicked(Sender: TObject);
begin
  DoToggleViewIDESpeedButtons;
end;

procedure TMainIDE.mnuViewFPCInfoClicked(Sender: TObject);
begin
  ShowFPCInfo;
end;

procedure TMainIDE.mnuViewIDEInfoClicked(Sender: TObject);
begin
  ShowIDEInfo;
end;

procedure TMainIDE.mnuViewNeedBuildClicked(Sender: TObject);
begin
  ShowNeedBuildDialog;
end;

procedure TMainIDE.SetDesigning(AComponent: TComponent; Value: Boolean);
begin
  SetComponentDesignMode(AComponent, Value);
  if Value then
    WidgetSet.SetDesigning(AComponent);
end;

procedure TMainIDE.SetDesignInstance(AComponent: TComponent; Value: Boolean);
begin
  SetComponentDesignInstanceMode(AComponent, Value);
end;

{------------------------------------------------------------------------------}
procedure TMainIDE.mnuFindDeclarationClicked(Sender: TObject);
begin
  DoFindDeclarationAtCursor;
end;

procedure TMainIDE.mnuNewUnitClicked(Sender: TObject);
var
  Category: TNewIDEItemCategory;
  Template: TNewIDEItemTemplate;
begin
  Category:=NewIDEItems.FindByName(FileDescGroupName);
  Template:=Category.FindTemplateByName(EnvironmentOptions.NewUnitTemplate);
  SourceFileMgr.NewUnitOrForm(Template, FileDescriptorUnit);
end;

procedure TMainIDE.mnuNewFormClicked(Sender: TObject);
var
  Category: TNewIDEItemCategory;
  Template: TNewIDEItemTemplate;
begin
  Category:=NewIDEItems.FindByName(FileDescGroupName);
  Template:=Category.FindTemplateByName(EnvironmentOptions.NewFormTemplate);
  SourceFileMgr.NewUnitOrForm(Template, FileDescriptorForm);
end;

procedure TMainIDE.mnuNewOtherClicked(Sender: TObject);
begin
  SourceFileMgr.NewOther;
end;

procedure TMainIDE.mnuOpenClicked(Sender: TObject);

  procedure UpdateEnvironment;
  begin
    SetRecentFilesMenu;
    SaveEnvironment;
  end;

var
  OpenDialog: TOpenDialog;
  AFilename: string;
  I: Integer;
  OpenFlags: TOpenFlags;
  Filter: String;
  AllEditorMask: String;
  AllMask: String;
  ASrcEdit: TSourceEditor;
  AnUnitInfo: TUnitInfo;
begin
  OpenDialog:=TOpenDialog.Create(nil);
  try
    InputHistories.ApplyFileDialogSettings(OpenDialog);
    OpenDialog.Title:=lisOpenFile;
    OpenDialog.Options:=OpenDialog.Options+[ofAllowMultiSelect];

    // set InitialDir to
    GetCurrentUnit(ASrcEdit,AnUnitInfo);
    if Assigned(AnUnitInfo) and (not AnUnitInfo.IsVirtual) then
      OpenDialog.InitialDir:=ExtractFilePath(AnUnitInfo.Filename);

    Filter := EnvironmentOptions.FileDialogFilter;

    // append a filter for all file types of the open files in the source editor
    CreateFileDialogFilterForSourceEditorFiles(Filter,AllEditorMask,AllMask);
    if (AllEditorMask<>'') then
      Filter:=Filter+ '|' + lisEditorFileTypes + ' (' + AllEditorMask + ')|' +
        AllEditorMask;

    // prepend an all normal files filter
    Filter:=lisLazarusFile + ' ('+AllMask+')|' + AllMask + '|' + Filter;

    // append an any files filter
    if TFileDialog.FindMaskInFilter(Filter,GetAllFilesMask)<1 then
      Filter:=Filter+ '|' + dlgAllFiles + ' (' + GetAllFilesMask + ')|' + GetAllFilesMask;

    OpenDialog.Filter := Filter;

    if OpenDialog.Execute and (OpenDialog.Files.Count>0) then begin
      OpenFlags:=[ofAddToRecent];
      //debugln('TMainIDE.mnuOpenClicked OpenDialog.Files.Count=',dbgs(OpenDialog.Files.Count));
      if OpenDialog.Files.Count>1 then
        Include(OpenFlags,ofRegularFile);
      try
        SourceEditorManager.IncUpdateLock;
        For I := 0 to OpenDialog.Files.Count-1 do
          Begin
            AFilename:=CleanAndExpandFilename(OpenDialog.Files.Strings[i]);
            if i<OpenDialog.Files.Count-1 then
              Include(OpenFlags,ofMultiOpen)
            else
              Exclude(OpenFlags,ofMultiOpen);
            if DoOpenEditorFile(AFilename,-1,-1,OpenFlags)=mrAbort then begin
              break;
            end;
          end;
        finally
          SourceEditorManager.DecUpdateLock;
        end;
      UpdateEnvironment;
    end;
    InputHistories.StoreFileDialogSettings(OpenDialog);
  finally
    OpenDialog.Free;
  end;
end;

procedure TMainIDE.mnuOpenRecentClicked(Sender: TObject);

  procedure UpdateEnvironment;
  begin
    SetRecentFilesMenu;
    SaveEnvironment;
  end;

var
  AFilename: string;
begin
  AFileName:=ExpandFileNameUTF8((Sender as TIDEMenuItem).Caption);
  if DoOpenEditorFile(AFilename,-1,-1,[ofAddToRecent])=mrOk then begin
    UpdateEnvironment;
  end else begin
    // open failed
    if not FileExistsUTF8(AFilename) then begin
      // file does not exist -> delete it from recent file list
      EnvironmentOptions.RemoveFromRecentOpenFiles(AFilename);
      UpdateEnvironment;
    end;
  end;
end;

procedure TMainIDE.mnuRevertClicked(Sender: TObject);
begin
  if (SourceEditorManager.ActiveSourceWindowIndex < 0)
  or (SourceEditorManager.ActiveSourceWindow.PageIndex < 0) then exit;
  DoOpenEditorFile('', SourceEditorManager.ActiveSourceWindow.PageIndex,
    SourceEditorManager.ActiveSourceWindowIndex, [ofRevert]);
end;

procedure TMainIDE.mnuOpenFileAtCursorClicked(Sender: TObject);
var
  ActiveSrcEdit: TSourceEditor;
  ActiveUnitInfo: TUnitInfo;
begin
  GetCurrentUnit(ActiveSrcEdit,ActiveUnitInfo);
  OpenFileAtCursor(ActiveSrcEdit, ActiveUnitInfo);
end;

procedure TMainIDE.mnuGotoIncludeDirectiveClicked(Sender: TObject);
begin
  DoGotoIncludeDirective;
end;

procedure TMainIDE.mnuSearchProcedureList(Sender: TObject);
begin
  ProcedureList.ExecuteProcedureList(Sender);
end;

procedure TMainIDE.mnuSetFreeBookmark(Sender: TObject);
begin
  OnSrcNotebookEditorDoSetBookmark(SourceEditorManager.SenderToEditor(Sender), -1, False);
end;

procedure TMainIDE.mnuSaveClicked(Sender: TObject);
var
  SrcEdit: TSourceEditor;
begin
  SrcEdit:=SourceEditorManager.SenderToEditor(Sender);
  if SrcEdit = nil then exit;
  DoSaveEditorFile(SrcEdit, [sfCheckAmbiguousFiles]);
end;

procedure TMainIDE.mnuSaveAsClicked(Sender: TObject);
var
  SrcEdit: TSourceEditor;
begin
  SrcEdit:=SourceEditorManager.SenderToEditor(Sender);
  if SrcEdit = nil then exit;
  DoSaveEditorFile(SrcEdit, [sfSaveAs, sfCheckAmbiguousFiles]);
end;

procedure TMainIDE.mnuSaveAllClicked(Sender: TObject);
begin
  DoSaveAll([sfCheckAmbiguousFiles]);
end;

procedure TMainIDE.mnuExportHtml(Sender: TObject);
var
  SrcEdit: TSourceEditor;
  AnUnitInfo: TUnitInfo;
  Filename: string;
  SaveDialog: TSaveDialog;
begin
  GetCurrentUnit(SrcEdit,AnUnitInfo);
  if SrcEdit = nil then exit;

  SaveDialog:=TSaveDialog.Create(nil);
  try
    SaveDialog.Title:=lisSaveSpace;
    SaveDialog.FileName:=SrcEdit.PageName+'.html';
    SaveDialog.Filter := ' (*.html;*.htm)|*.html;*.htm';
    SaveDialog.Options := [ofOverwritePrompt, ofPathMustExist{, ofNoReadOnlyReturn}]; // Does not work for desktop
    // show save dialog
    if (not SaveDialog.Execute) or (ExtractFileName(SaveDialog.Filename)='')
    then begin
      exit;
    end;
    Filename:=ExpandFileNameUTF8(SaveDialog.Filename);
  finally
    SaveDialog.Free;
  end;

  try
    SrcEdit.ExportAsHtml(Filename);
  except
    IDEMessageDialog(lisCodeToolsDefsWriteError, lisFailedToSaveFile, mtError, [mbOK]);
  end;
end;

procedure TMainIDE.mnuCloseClicked(Sender: TObject);
var
  PageIndex: integer;
  NB: TSourceNotebook;
begin
  if Sender is TTabSheet then begin
    NB := SourceEditorManager.SourceWindowWithPage(TTabSheet(Sender));
    if NB = nil then exit;
    PageIndex := NB.NotebookPages.IndexOfObject(Sender);
  end else begin
    NB := SourceEditorManager.ActiveSourceWindow;
    if (NB = nil)  or (NB.NotebookPages = nil) then exit;
    PageIndex := SourceEditorManager.ActiveSourceWindow.PageIndex;
  end;
  DoCloseEditorFile(NB.FindSourceEditorWithPageIndex(PageIndex), [cfSaveFirst]);
end;

procedure TMainIDE.mnuCloseAllClicked(Sender: TObject);
begin
  SourceFileMgr.CloseAll;
end;

procedure TMainIDE.mnuCleanDirectoryClicked(Sender: TObject);
begin
  if Project1=nil then exit;
  ShowCleanDirectoryDialog(Project1.ProjectDirectory,GlobalMacroList);
end;

procedure TMainIDE.OnSrcNotebookFileNew(Sender: TObject);
begin
  mnuNewFormClicked(Sender);
end;

procedure TMainIDE.OnSrcNotebookFileClose(Sender: TObject; InvertedClose: boolean);
var
  PageIndex: LongInt;
  SrcNoteBook: TSourceNotebook;
begin
  if InvertedClose then begin
    if Sender is TTabSheet then begin
      SrcNoteBook := SourceEditorManager.SourceWindowWithPage(TTabSheet(Sender));
      if SrcNoteBook = nil then exit;
      PageIndex := SrcNoteBook.NotebookPages.IndexOfObject(Sender);
    end else begin
      SrcNoteBook := SourceEditorManager.ActiveSourceWindow;
      if SrcNoteBook = nil then exit;
      PageIndex := SrcNoteBook.PageIndex;
    end;
    // Close all but the active editor
    SourceFileMgr.InvertedFileClose(PageIndex, SrcNoteBook);
  end
  else
    mnuCloseClicked(Sender);         // close only the clicked source editor
end;

procedure TMainIDE.OnSrcNotebookFileOpen(Sender: TObject);
begin
  mnuOpenClicked(Sender);
end;

procedure TMainIDE.OnSrcNotebookFileOpenAtCursor(Sender: TObject);
begin
  mnuOpenFileAtCursorClicked(Sender);
end;

procedure TMainIDE.OnSrcNotebookFileSave(Sender: TObject);
begin
  mnuSaveClicked(Sender);
end;

procedure TMainIDE.OnSrcNotebookFileSaveAs(Sender: TObject);
begin
  mnuSaveAsClicked(Sender);
end;

procedure TMainIDE.OnSrcNotebookFindDeclaration(Sender: TObject);
begin
  mnuFindDeclarationClicked(Sender);
end;

procedure TMainIDE.OnSrcNotebookInitIdentCompletion(Sender: TObject;
  JumpToError: boolean; out Handled, Abort: boolean);
begin
  Handled:=true;
  Abort:=not DoInitIdentCompletion(JumpToError);
end;

procedure TMainIDE.OnSrcNotebookShowCodeContext(
  JumpToError: boolean; out Abort: boolean);
begin
  Abort:=not DoShowCodeContext(JumpToError);
end;

procedure TMainIDE.OnSrcNotebookSaveAll(Sender: TObject);
begin
  mnuSaveAllClicked(Sender);
end;

procedure TMainIDE.OnSrcNotebookToggleFormUnit(Sender: TObject);
begin
  mnuToggleFormUnitClicked(Sender);
end;

procedure TMainIDE.OnSrcNotebookToggleObjectInsp(Sender: TObject);
begin
  mnuViewInspectorClicked(Sender);
end;

procedure TMainIDE.OnProcessIDECommand(Sender: TObject;
  Command: word;  var Handled: boolean);

  function IsOnWindow(Wnd: TWinControl): boolean;
  begin
    Result:=false;
    if Wnd=nil then exit;
    if not (Sender is TControl) then exit;
    if Sender=Wnd then exit(true);
    Result:=Wnd.IsParentOf(TControl(Sender));
  end;

var
  ASrcEdit: TSourceEditor;
  AnUnitInfo: TUnitInfo;
  IDECmd: TIDECommand;
  s: String;
begin
  //debugln('TMainIDE.OnProcessIDECommand ',dbgs(Command));
  Handled:=true;

  case Command of
  ecEditContextHelp: ShowContextHelpEditor(Sender);
  ecContextHelp:
    if IsOnWindow(MessagesView) then
      HelpBoss.ShowHelpForMessage()
    else if Sender is TObjectInspectorDlg then
      HelpBoss.ShowHelpForObjectInspector(Sender);
  ecSave:
    begin
      if Assigned(ObjectInspector1) then
        ObjectInspector1.GetActivePropertyGrid.SaveChanges;
      if (Sender is TDesigner) or (Sender is TObjectInspectorDlg) then begin
        if (Sender is TDesigner) then
          GetDesignerUnit(TDesigner(Sender),ASrcEdit,AnUnitInfo)
        else
          GetObjectInspectorUnit(ASrcEdit,AnUnitInfo);
        if (AnUnitInfo<>nil) and (AnUnitInfo.OpenEditorInfoCount > 0) then
          DoSaveEditorFile(ASrcEdit, [sfCheckAmbiguousFiles]);
      end
      else if Sender is TSourceNotebook then
        mnuSaveClicked(Self);
    end;
  ecOpen:                     mnuOpenClicked(Self);
  ecSaveAll:                  DoSaveAll([sfCheckAmbiguousFiles]);
  ecQuit:                     mnuQuitClicked(Self);
  ecCompile:
    DoCompile;
  ecRun:
    begin
      GetCurrentUnit(ASrcEdit,AnUnitInfo);
      if (AnUnitInfo<>nil)
      and AnUnitInfo.RunFileIfActive then
        DoRunFile
      else
        DoRunProject;
    end;
  ecAttach:
    if ToolStatus = itNone then begin
      if DebugBoss.InitDebugger([difInitForAttach]) then begin
        s := GetPidForAttach;

        if s <> '' then begin
          ToolStatus := itDebugger;
          DebugBoss.Attach(s);
        end
        else
          if ToolStatus = itDebugger then
            ToolStatus := itNone;
      end;
    end;
  ecDetach:                   DebugBoss.Detach;
  ecBuild:                    DoBuildProject(crBuild, [pbfCleanCompile]);
  ecCleanUpAndBuild:          mnuCleanUpAndBuildProjectClicked(nil);
  ecQuickCompile:             DoQuickCompile;
  ecAbortBuild:               DoAbortBuild(false);
  ecBuildFile:                DoBuildFile(false);
  ecRunFile:                  DoRunFile;
  ecJumpToPrevError:          DoJumpToNextError(false);
  ecJumpToNextError:          DoJumpToNextError(true);
  ecFindInFiles:              DoFindInFiles;
  ecFindProcedureDefinition,
  ecFindProcedureMethod:      DoJumpToOtherProcedureSection;
  ecFindDeclaration:          DoFindDeclarationAtCursor;
  ecFindIdentifierRefs:       DoFindRenameIdentifier(false);
  ecFindUsedUnitRefs:         DoFindUsedUnitReferences;
  ecRenameIdentifier:         DoFindRenameIdentifier(true);
  ecShowAbstractMethods:      DoShowAbstractMethods;
  ecRemoveEmptyMethods:       DoRemoveEmptyMethods;
  ecRemoveUnusedUnits:        DoRemoveUnusedUnits;
  ecUseUnit:                  DoUseUnit;
  ecFindOverloads:            DoFindOverloads;
  ecFindBlockOtherEnd:        DoGoToPascalBlockOtherEnd;
  ecFindBlockStart:           DoGoToPascalBlockStart;
  ecGotoIncludeDirective:     DoGotoIncludeDirective;
  ecCompleteCode:             DoCompleteCodeAtCursor;
  ecExtractProc:              DoExtractProcFromSelection;
  // user used shortcut/menu item to show the window, so focusing is ok.
  ecToggleMessages:           DoShowMessagesView;
  ecToggleCodeExpl:           DoShowCodeExplorer;
  ecToggleCodeBrowser:        DoShowCodeBrowser;
  ecToggleRestrictionBrowser: DoShowRestrictionBrowser;
  ecViewComponents:           DoShowComponentList;
  ecToggleFPDocEditor:        DoShowFPDocEditor;
  ecViewProjectUnits:         DoViewUnitsAndForms(false);
  ecViewProjectForms:         DoViewUnitsAndForms(true);
  ecProjectInspector:         DoShowProjectInspector;
  ecConfigCustomComps:        PkgBoss.ShowConfigureCustomComponents;
  ecExtToolFirst..ecExtToolLast: DoRunExternalTool(Command-ecExtToolFirst,false);
  ecSyntaxCheck:              DoCheckSyntax;
  ecGuessUnclosedBlock:       DoJumpToGuessedUnclosedBlock(true);
  ecGuessMisplacedIFDEF:      DoJumpToGuessedMisplacedIFDEF(true);
  ecMakeResourceString:       DoMakeResourceString;
  ecDiff:                     DoDiff;
  ecConvertDFM2LFM:           DoConvertDFMtoLFM;
  ecRescanFPCSrcDir:          mnuEnvRescanFPCSrcDirClicked(Self);
  ecManageExamples:           mnuToolManageExamplesClicked(Self);
  ecBuildLazarus:             mnuToolBuildLazarusClicked(Self);
  ecBuildAdvancedLazarus:     mnuToolBuildAdvancedLazarusClicked(Self);
  ecConfigBuildLazarus:       mnuToolConfigBuildLazClicked(Self);
  ecManageSourceEditors:      mnuWindowManagerClicked(Self);
  ecToggleFormUnit:           mnuToggleFormUnitClicked(Self);
  ecToggleObjectInsp:         mnuViewInspectorClicked(Self);
  ecToggleSearchResults:      mnuViewSearchResultsClick(Self);
  ecAboutLazarus:             MainIDEBar.itmHelpAboutLazarus.OnClick(Self);
  ecToggleBreakPoint:
    if Assigned(SourceEditorManager.ActiveSourceWindow) then
      SourceEditorManager.ActiveSourceWindow.ToggleBreakpointClicked(Self);
  ecRemoveBreakPoint:
    if Assigned(SourceEditorManager.ActiveSourceWindow) then
      SourceEditorManager.ActiveSourceWindow.DeleteBreakpointClicked(Self);
  ecProcedureList:            mnuSearchProcedureList(self);
  ecInsertGUID:               mnuSourceInsertGUID(self);
  ecInsertFilename:           mnuSourceInsertFilename(self);
  ecViewMacroList:            mnuViewMacroListClick(self);
  else
    Handled:=false;
    // let the bosses handle it
    DebugBoss.ProcessCommand(Command,Handled);
    if Handled then exit;
    PkgBoss.ProcessCommand(Command,Handled);
    if Handled then exit;
    // custom commands
    IDECmd:=IDECommandList.FindIDECommand(Command);
    //DebugLn('TMainIDE.OnProcessIDECommand Command=',dbgs(Command),' ',dbgs(IDECmd));
    if (IDECmd<>nil) then begin
      Handled:=IDECmd.Execute(IDECmd);
    end;
  end;
  //DebugLn('TMainIDE.OnProcessIDECommand Handled=',dbgs(Handled),' Command=',dbgs(Command));
end;

function TMainIDE.OnExecuteIDECommand(Sender: TObject; Command: word): boolean;
begin
  Result:=false;
  OnProcessIDECommand(Sender,Command,Result);
end;

function TMainIDE.OnSelectDirectory(const Title, InitialDir: string): string;
var
  Dialog: TSelectDirectoryDialog;
  DummyResult: Boolean;
begin
  Result:='';
  Dialog:=TSelectDirectoryDialog.Create(nil);
  try
    InputHistories.ApplyFileDialogSettings(Dialog);
    Dialog.Title:=Title;
    Dialog.Options:=Dialog.Options+[ofFileMustExist];
    if InitialDir<>'' then
      Dialog.InitialDir:=InitialDir;
    DummyResult:=Dialog.Execute;
    InputHistories.StoreFileDialogSettings(Dialog);
    if DummyResult and DirPathExists(Dialog.Filename) then begin
      Result:=Dialog.Filename;
    end;
  finally
    Dialog.Free;
  end;
end;

procedure TMainIDE.OnInitIDEFileDialog(AFileDialog: TFileDialog);
begin
  InputHistories.ApplyFileDialogSettings(AFileDialog);
end;

procedure TMainIDE.OnStoreIDEFileDialog(AFileDialog: TFileDialog);
begin
  InputHistories.StoreFileDialogSettings(AFileDialog);
end;

function TMainIDE.OnIDEMessageDialog(const aCaption, aMsg: string;
  DlgType: TMsgDlgType; Buttons: TMsgDlgButtons; const HelpKeyword: string): Integer;
begin
  Result:=MessageDlg{ !!! DO NOT REPLACE WITH IDEMessageDialog }
            (aCaption,aMsg,DlgType,Buttons,HelpKeyword);
end;

function TMainIDE.OnIDEQuestionDialog(const aCaption, aMsg: string;
  DlgType: TMsgDlgType; Buttons: array of const; const HelpKeyword: string): Integer;
begin
  Result:=QuestionDlg{ !!! DO NOT REPLACE WITH IDEQuestionDialog }
            (aCaption,aMsg,DlgType,Buttons,HelpKeyword);
end;

procedure TMainIDE.OnExecuteIDEShortCut(Sender: TObject; var Key: word;
  Shift: TShiftState;
  IDEWindowClass: TCustomFormClass);
var
  Command: Word;
  Handled: Boolean;
begin
  if Key=VK_UNKNOWN then exit;
  Command := EditorOpts.KeyMap.TranslateKey(Key,Shift,IDEWindowClass);
  if (Command = ecNone) then exit;
  Handled := false;
  OnProcessIDECommand(Sender, Command, Handled);
  if Handled then
    Key := VK_UNKNOWN;
end;

procedure TMainIDE.OnSrcNoteBookClickLink(Sender: TObject;
  Button: TMouseButton; Shift: TShiftstate; X, Y: Integer);
var
  ActiveSrcEdit: TSourceEditor;
  ActiveUnitInfo: TUnitInfo;
begin
  GetCurrentUnit(ActiveSrcEdit,ActiveUnitInfo);
  if ActiveSrcEdit=nil then exit;
  DoFindDeclarationAtCaret(
    ActiveSrcEdit.EditorComponent.PixelsToLogicalPos(Point(X,Y)));
end;

procedure TMainIDE.OnSrcNoteBookShowUnitInfo(Sender: TObject);
begin
  DoViewUnitInfo;
end;

{------------------------------------------------------------------------------}

procedure TMainIDE.OpenFilePopupMenuPopup(Sender: TObject);
var
  CurIndex: integer;
  OpenMenuItem: TPopupMenu;

  procedure AddFile(const Filename: string);
  var
    AMenuItem: TMenuItem;
  begin
    if MainIDEBar.OpenFilePopupMenu.Items.Count > CurIndex then
      AMenuItem := MainIDEBar.OpenFilePopupMenu.Items[CurIndex]
    else 
    begin
      AMenuItem := TMenuItem.Create(OwningComponent);
      AMenuItem.Name := MainIDEBar.OpenFilePopupMenu.Name + 'Recent' + IntToStr(CurIndex);
      AMenuItem.OnClick := @mnuOpenFilePopupClick;
      MainIDEBar.OpenFilePopupMenu.Items.Add(AMenuItem);
    end;
    AMenuItem.Caption := Filename;
    inc(CurIndex);
  end;

  procedure AddFiles(List: TStringList; MaxCount: integer);
  var 
    i: integer;
  begin
    i := 0;
    while (i < List.Count) and (i < MaxCount) do 
    begin
      AddFile(List[i]);
      inc(i);
    end;
  end;

begin
  // fill the PopupMenu:
  CurIndex := 0;
  // first add 8 recent projects
  AddFiles(EnvironmentOptions.RecentProjectFiles, 8);
  // add a separator
  AddFile('-');
  // add 12 recent files
  AddFiles(EnvironmentOptions.RecentOpenFiles, 12);
  OpenMenuItem := MainIDEBar.OpenFilePopupMenu;
  // remove unused menuitems
  while OpenMenuItem.Items.Count > CurIndex do
    OpenMenuItem.Items[OpenMenuItem.Items.Count - 1].Free;
end;

procedure TMainIDE.mnuOpenFilePopupClick(Sender: TObject);
var
  TheMenuItem: TMenuItem;
  Index, SeparatorIndex: integer;
  AFilename: string;
begin
  TheMenuItem:=(Sender as TMenuItem);
  if TheMenuItem.Caption='-' then exit;
  Index:=TheMenuItem.MenuIndex;
  SeparatorIndex:=0;
  while SeparatorIndex<MainIDEBar.OpenFilePopupMenu.Items.Count do begin
    if MainIDEBar.OpenFilePopupMenu.Items[SeparatorIndex].Caption='-' then
      break;
    inc(SeparatorIndex);
  end;
  if Index=SeparatorIndex then exit;
  if Index<SeparatorIndex then begin
    // open recent project
    AFilename:=EnvironmentOptions.RecentProjectFiles[Index];
    DoOpenProjectFile(AFileName,[ofAddToRecent]);
  end else begin
    // open recent file
    dec(Index, SeparatorIndex+1);
    if DoOpenEditorFile(EnvironmentOptions.RecentOpenFiles[Index],-1,-1,
      [ofAddToRecent])=mrOk then
    begin
      SetRecentFilesMenu;
      SaveEnvironment;
    end;
  end;
end;

procedure TMainIDE.SetBuildModePopupMenuPopup(Sender: TObject);
var
  aMenu: TPopupMenu;
  CurIndex: Integer;
  i: Integer;

  procedure AddMode(CurMode: TProjectBuildMode);
  var
    AMenuItem: TMenuItem;
  begin
    if aMenu.Items.Count > CurIndex then
      AMenuItem := aMenu.Items[CurIndex]
    else
    begin
      AMenuItem := TMenuItem.Create(OwningComponent);
      AMenuItem.Name := aMenu.Name + 'Mode' + IntToStr(CurIndex);
      AMenuItem.OnClick := @mnuSetBuildModeClick;
      aMenu.Items.Add(AMenuItem);
    end;
    AMenuItem.Caption := CurMode.GetCaption;
    AMenuItem.Checked := (Project1<>nil) and (Project1.ActiveBuildMode=CurMode);
    AMenuItem.ShowAlwaysCheckable:=true;
    inc(CurIndex);
  end;

begin
  // fill the PopupMenu:
  CurIndex := 0;
  aMenu := MainIDEBar.SetBuildModePopupMenu;
  if Project1<>nil then
    for i:=0 to Project1.BuildModes.Count-1 do
      AddMode(Project1.BuildModes[i]);
  // remove unused menuitems
  while aMenu.Items.Count > CurIndex do
    aMenu.Items[aMenu.Items.Count - 1].Free;
end;

procedure TMainIDE.mnuChgBuildModeClicked(Sender: TObject);
begin
  DoOpenIDEOptions(TCompilerPathOptionsFrame, '', [TProjectCompilerOptions], []);
end;

procedure TMainIDE.mnuSetBuildModeClick(Sender: TObject);
var
  TheMenuItem: TMenuItem;
  Index: LongInt;
  NewMode: TProjectBuildMode;
begin
  TheMenuItem:=(Sender as TMenuItem);
  if TheMenuItem.Caption='-' then exit;
  Index:=TheMenuItem.MenuIndex;
  if (Index<0) or (Index>=Project1.BuildModes.Count) then exit;
  NewMode:=Project1.BuildModes[Index];
  if NewMode=Project1.ActiveBuildMode then exit;
  if not (ToolStatus in [itNone,itDebugger]) then begin
    IDEMessageDialog('Error','You can not change the build mode while compiling.',
      mtError,[mbOk]);
    exit;
  end;

  Project1.ActiveBuildMode:=NewMode;
  MainBuildBoss.SetBuildTargetProject1(false);
  UpdateCaption;
end;

function TMainIDE.CreateDesignerForComponent(AnUnitInfo: TUnitInfo;
  AComponent: TComponent): TCustomForm;
var
  DesignerForm: TCustomForm;
begin
  {$IFDEF IDE_DEBUG}
  debugln('[TMainIDE.CreateDesignerForComponent] A ',AComponent.Name,':',AComponent.ClassName);
  {$ENDIF}
  // create designer form
  if (AComponent is TCustomForm) then
    DesignerForm := TCustomForm(AComponent)
  else
    DesignerForm := FormEditor1.CreateNonFormForm(AComponent);
  Result:=DesignerForm;
  // set component and designer form into design mode (csDesigning)
  SetDesigning(AComponent, True);
  if AComponent <> DesignerForm then
    SetDesigning(DesignerForm, True);
  SetDesignInstance(AComponent, True);
  if AComponent is TControl then
    TControl(AComponent).ControlStyle:=
      TControl(AComponent).ControlStyle-[csNoDesignVisible];
  // create designer
  DesignerForm.Designer := TDesigner.Create(DesignerForm, TheControlSelection);
  {$IFDEF IDE_DEBUG}
  debugln('[TMainIDE.CreateDesignerForComponent] B');
  {$ENDIF}
  with TDesigner(DesignerForm.Designer) do begin
    TheFormEditor := FormEditor1;
    OnActivated:=@OnDesignerActivated;
    OnCloseQuery:=@OnDesignerCloseQuery;
    OnPersistentDeleted:=@OnDesignerPersistentDeleted;
    OnGetNonVisualCompIcon:=
                 @TComponentPalette(IDEComponentPalette).OnGetNonVisualCompIcon;
    OnGetSelectedComponentClass:=@OnDesignerGetSelectedComponentClass;
    OnModified:=@OnDesignerModified;
    OnPasteComponents:=@OnDesignerPasteComponents;
    OnPastedComponents:=@OnDesignerPastedComponents;
    OnProcessCommand:=@OnProcessIDECommand;
    OnPropertiesChanged:=@OnDesignerPropertiesChanged;
    OnRenameComponent:=@OnDesignerRenameComponent;
    OnSetDesigning:=@OnDesignerSetDesigning;
    OnShowOptions:=@OnDesignerShowOptions;
    OnComponentAdded:=@OnDesignerComponentAdded;
    OnViewLFM:=@OnDesignerViewLFM;
    OnSaveAsXML:=@OnDesignerSaveAsXML;
    OnShowObjectInspector:=@OnDesignerShowObjectInspector;
    OnShowAnchorEditor:=@OnDesignerShowAnchorEditor;
    OnShowTabOrderEditor:=@OnDesignerShowTabOrderEditor;
    ShowEditorHints:=EnvironmentOptions.ShowEditorHints;
    ShowComponentCaptions := EnvironmentOptions.ShowComponentCaptions;
  end;
  if AnUnitInfo<>nil then
    AnUnitInfo.LoadedDesigner:=true;
end;

procedure TMainIDE.InvalidateAllDesignerForms;
// Calls 'Invalidate' in all designer forms.
var
  AnUnitInfo: TUnitInfo;
  CurDesignerForm: TCustomForm;
begin
  if Project1=nil then exit;
  AnUnitInfo:=Project1.FirstUnitWithComponent;
  while AnUnitInfo<>nil do begin
    if AnUnitInfo.Component<>nil then begin
      CurDesignerForm:=FormEditor1.GetDesignerForm(AnUnitInfo.Component);
      if CurDesignerForm<>nil then
        CurDesignerForm.Invalidate;
    end;
    AnUnitInfo:=AnUnitInfo.NextUnitWithComponent;
  end;
end;

procedure TMainIDE.UpdateIDEComponentPalette(IfFormChanged: boolean);
var
  OldLastCompPaletteForm: TCustomForm;
  AResult: Boolean;
begin
  // Package manager updates the palette initially.
  if not FIDEStarted
  or (IfFormChanged and (fLastCompPaletteForm=LastFormActivated)) then
    exit;
  OldLastCompPaletteForm:=fLastCompPaletteForm;
  fLastCompPaletteForm:=LastFormActivated;
  AResult:=(LastFormActivated<>nil) and (LastFormActivated.Designer<>nil)
    and (LastFormActivated.Designer.LookupRoot<>nil)
    and not (LastFormActivated.Designer.LookupRoot is TControl);
  IDEComponentPalette.HideControls:=AResult;
  // Don't update palette at the first time if not hiding controls.
  if (OldLastCompPaletteForm = Nil) and not IDEComponentPalette.HideControls then
    exit;
  {$IFDEF VerboseComponentPalette}
  DebugLn(['* TMainIDE.UpdateIDEComponentPalette: Updating palette *',
           ', HideControls=', IDEComponentPalette.HideControls]);
  {$ENDIF}
  IDEComponentPalette.Update(False);
  SetupHints;
end;

procedure TMainIDE.ShowDesignerForm(AForm: TCustomForm);
var
  ARestoreVisible: Boolean;
begin
  {$IFDEF IDE_DEBUG}
  DebugLn('TMainIDE.ShowDesignerForm(',dbgsName(AForm),')');
  {$ENDIF}
  if (csDesigning in AForm.ComponentState) and (AForm.Designer <> nil) and
    (AForm.WindowState in [wsMinimized]) then
  begin
    ARestoreVisible := AForm.Visible;
    AForm.Visible := False;
    AForm.ShowOnTop;
    AForm.Visible := ARestoreVisible;
    AForm.WindowState := wsMinimized;
    exit;
  end;
  // do not call 'AForm.Show', because it will set Visible to true
  AForm.BringToFront;
  LCLIntf.ShowWindow(AForm.Handle,SW_SHOWNORMAL);
end;

procedure TMainIDE.DoViewAnchorEditor(State: TIWGetFormState);
begin
  if AnchorDesigner=nil then
    IDEWindowCreators.CreateForm(AnchorDesigner,TAnchorDesigner,
       State=iwgfDisabled,LazarusIDE.OwningComponent)
  else if State=iwgfDisabled then
    AnchorDesigner.DisableAlign;
  if State>=iwgfShow then
    IDEWindowCreators.ShowForm(AnchorDesigner,State=iwgfShowOnTop);
end;

procedure TMainIDE.DoViewTabOrderEditor(State: TIWGetFormState);
begin
  if TabOrderDialog=nil then
    IDEWindowCreators.CreateForm(TabOrderDialog,TTabOrderDialog,
       State=iwgfDisabled,LazarusIDE.OwningComponent)
  else if State=iwgfDisabled then
    TabOrderDialog.DisableAlign;
  if State>=iwgfShow then
    IDEWindowCreators.ShowForm(TabOrderDialog,State=iwgfShowOnTop);
end;

procedure TMainIDE.DoToggleViewComponentPalette;
var
  ComponentPaletteVisible: boolean;
begin
  ComponentPaletteVisible:=not MainIDEBar.ComponentPageControl.Visible;
  MainIDEBar.itmViewComponentPalette.Checked:=ComponentPaletteVisible;
  MainIDEBar.ComponentPageControl.Visible:=ComponentPaletteVisible;
  EnvironmentOptions.ComponentPaletteVisible:=ComponentPaletteVisible;
end;

procedure TMainIDE.DoToggleViewIDESpeedButtons;
var
  SpeedButtonsVisible: boolean;
begin
  SpeedButtonsVisible:=not MainIDEBar.pnlSpeedButtons.Visible;
  MainIDEBar.itmViewIDESpeedButtons.Checked:=SpeedButtonsVisible;
  MainIDEBar.pnlSpeedButtons.Visible:=SpeedButtonsVisible;
  EnvironmentOptions.IDESpeedButtonsVisible:=MainIDEBar.pnlSpeedButtons.Visible;
end;

procedure TMainIDE.AllowCompilation(aAllow: Boolean);
// Enables or disables IDE GUI controls associated with compiling and building.
// Does it interfere with DebugBoss.UpdateButtonsAndMenuItems? Maybe should be refactored and combined.
begin
  if MainIDEBar=Nil then Exit;
  with MainIDEBar do begin
    Assert(Assigned(RunSpeedButton), 'TMainIDE.AllowCompilation: RunSpeedButton not assigned!');
    RunSpeedButton.Enabled:=aAllow;
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
end;

procedure TMainIDE.SetToolStatus(const AValue: TIDEToolStatus);
begin
  inherited SetToolStatus(AValue);
  if DebugBoss <> nil then
    DebugBoss.UpdateButtonsAndMenuItems;
  AllowCompilation(ToolStatus <> itBuilder); // Disable some GUI controls while compiling.
  if FWaitForClose and (ToolStatus = itNone) then
  begin
    FWaitForClose := False;
    MainIDEBar.Close;
  end;
end;

function TMainIDE.DoResetToolStatus(AFlags: TResetToolFlags): boolean;
begin
  Result := False;
  case ToolStatus of
    itDebugger:
      begin
        if (rfInteractive in AFlags)
        and (IDEQuestionDialog(lisStopDebugging, lisStopTheDebugging, mtConfirmation,
            [mrYes, lisStop, mrCancel, lisContinue]) <> mrYes)
        then exit;
        if (DebugBoss.DoStopProject = mrOK) and (ToolStatus = itDebugger) and (rfCloseOnDone in AFlags) then
          FWaitForClose := True;
        if rfSuccessOnTrigger in AFlags then
          exit(true);
      end;
  end;
  Result := ToolStatus = itNone;
end;

procedure TMainIDE.Notification(AComponent: TComponent; Operation: TOperation);
begin
  inherited Notification(AComponent, Operation);
end;


{------------------------------------------------------------------------------}

procedure TMainIDE.mnuRestartClicked(Sender: TObject);
begin
  DoRestart;
end;

procedure TMainIDE.mnuQuitClicked(Sender: TObject);
begin
  QuitIDE;
end;

{------------------------------------------------------------------------------}

procedure TMainIDE.mnuFileClicked(Sender: TObject);
var
  ASrcEdit: TSourceEditor;
  AnUnitInfo: TUnitInfo;
begin
  GetCurrentUnit(ASrcEdit,AnUnitInfo);
  with MainIDEBar do begin
    itmFileClose.Enabled := ASrcEdit<>nil;
    itmFileCloseAll.Enabled := ASrcEdit<>nil;
  end;
end;

procedure TMainIDE.mnuEditClicked(Sender: TObject);
var
  ASrcEdit: TSourceEditor;
  AnUnitInfo: TUnitInfo;
  Editable: Boolean;
  SelAvail: Boolean;
  SelEditable: Boolean;
  SrcEditorActive, DsgEditorActive: Boolean;
  ActiveDesigner: TComponentEditorDesigner;
begin
  GetCurrentUnit(ASrcEdit, AnUnitInfo);
  Editable := Assigned(ASrcEdit) and not ASrcEdit.ReadOnly;
  SelAvail := Assigned(ASrcEdit) and ASrcEdit.SelectionAvailable;
  SelEditable := Editable and SelAvail;
  SrcEditorActive := DisplayState = dsSource;
  DsgEditorActive := DisplayState = dsForm;
  ActiveDesigner := GetActiveDesignerSkipMainBar;
  with MainIDEBar do
  begin
    if Assigned(ActiveDesigner) then
    begin
      // activate them when Designer start to support Undo/Redo
      itmEditUndo.Enabled := DsgEditorActive and ActiveDesigner.CanUndo; {and not ActiveDesigner.ReadOnly}
      itmEditRedo.Enabled := DsgEditorActive and ActiveDesigner.CanRedo; {and not ActiveDesigner.ReadOnly}
      itmEditCut.Enabled := ActiveDesigner.CanCopy;
      itmEditCopy.Enabled := itmEditCut.Enabled;
      itmEditPaste.Enabled := ActiveDesigner.CanPaste;
    end
    else
    begin
      itmEditUndo.Enabled := Editable and SrcEditorActive and ASrcEdit.EditorComponent.CanUndo;
      itmEditRedo.Enabled := Editable and SrcEditorActive and ASrcEdit.EditorComponent.CanRedo;
      itmEditCut.Enabled := SelEditable;
      itmEditCopy.Enabled := SelAvail;
      itmEditPaste.Enabled := Editable;
    end;
  //itmEditSelect: TIDEMenuSection; [...]
  //itmEditBlockActions: TIDEMenuSection;
    itmEditIndentBlock.Enabled := Editable;
    itmEditUnindentBlock.Enabled := Editable;
    itmEditUpperCaseBlock.Enabled := SelEditable;
    itmEditLowerCaseBlock.Enabled := SelEditable;
    itmEditSwapCaseBlock.Enabled := SelEditable;
    itmEditSortBlock.Enabled := SelEditable;
    itmEditTabsToSpacesBlock.Enabled := SelEditable;
    itmEditSelectionBreakLines.Enabled := SelEditable;
    itmEditInsertCharacter.Enabled := Editable;
  end;
end;

procedure TMainIDE.mnuSourceClicked(Sender: TObject);
var
  ASrcEdit: TSourceEditor;
  AnUnitInfo: TUnitInfo;
  Editable, SelEditable, SelAvail, IdentFound, StringFound: Boolean;
  StartCode, EndCode: TCodeBuffer;
  StartPos, EndPos: TPoint;
  NewX, NewY, NewTopLine: integer;
  CursorXY: TPoint;
begin
  Editable:=False;
  SelAvail:=False;
  IdentFound:=False;
  StringFound:=False;
  ASrcEdit:=nil;
  if BeginCodeTool(ASrcEdit,AnUnitInfo,[]) then begin
    Assert(Assigned(ASrcEdit));
    Editable:=not ASrcEdit.ReadOnly;
    SelAvail:=ASrcEdit.SelectionAvailable;

    // Try to find main identifier declaration to enable rename feature.
    CursorXY:=ASrcEdit.EditorComponent.LogicalCaretXY;
    IdentFound:=CodeToolBoss.FindMainDeclaration(AnUnitInfo.Source,
                  CursorXY.X,CursorXY.Y,StartCode,NewX,NewY,NewTopLine);

    // Calculate start and end of string expr to enable ResourceString feature.
    if ASrcEdit.EditorComponent.SelAvail then
      CursorXY:=ASrcEdit.EditorComponent.BlockBegin;
    if CodeToolBoss.GetStringConstBounds(AnUnitInfo.Source,CursorXY.X,CursorXY.Y,
                                         StartCode,StartPos.X,StartPos.Y,
                                         EndCode,EndPos.X,EndPos.Y,true) then
      StringFound:=(StartCode<>EndCode) or (CompareCaret(StartPos,EndPos)<>0);
  end;
  SelEditable:=Editable and SelAvail;
  with MainIDEBar do begin
  //itmSourceBlockActions
    itmSourceCommentBlock.Enabled:=SelEditable;
    itmSourceUncommentBlock.Enabled:=SelEditable;
    itmSourceEncloseBlock.Enabled:=SelEditable;
    itmSourceEncloseInIFDEF.Enabled:=SelEditable;
    itmSourceCompleteCode.Enabled:=Editable;
    itmSourceUseUnit.Enabled:=Editable;
  //itmSourceInsertions
    //itmSourceInsertCVSKeyWord
      itmSourceInsertCVSAuthor.Enabled:=Editable;
      itmSourceInsertCVSDate.Enabled:=Editable;
      itmSourceInsertCVSHeader.Enabled:=Editable;
      itmSourceInsertCVSID.Enabled:=Editable;
      itmSourceInsertCVSLog.Enabled:=Editable;
      itmSourceInsertCVSName.Enabled:=Editable;
      itmSourceInsertCVSRevision.Enabled:=Editable;
      itmSourceInsertCVSSource.Enabled:=Editable;
    //itmSourceInsertGeneral
      itmSourceInsertGPLNotice.Enabled:=Editable;
      itmSourceInsertGPLNoticeTranslated.Visible:=
                                  Editable and (EnglishGPLNotice<>lisGPLNotice);
      itmSourceInsertLGPLNotice.Enabled:=Editable;
      itmSourceInsertLGPLNoticeTranslated.Visible:=
                                Editable and (EnglishLGPLNotice<>lisLGPLNotice);
      itmSourceInsertModifiedLGPLNotice.Enabled:=Editable;
      itmSourceInsertModifiedLGPLNoticeTranslated.Visible:=
                Editable and (EnglishModifiedLGPLNotice<>lisModifiedLGPLNotice);
      itmSourceInsertMITNotice.Enabled:=Editable;
      itmSourceInsertMITNoticeTranslated.Visible:=
                                  Editable and (EnglishMITNotice<>lisMITNotice);
      itmSourceInsertUsername.Enabled:=Editable;
      itmSourceInsertDateTime.Enabled:=Editable;
      itmSourceInsertChangeLogEntry.Enabled:=Editable;
  //itmSourceRefactor
    //itmRefactorCodeTools
      itmRefactorRenameIdentifier.Enabled:=Editable and IdentFound;
      itmRefactorExtractProc.Enabled:=Editable and SelAvail;
      itmRefactorInvertAssignment.Enabled:=Editable and SelAvail;
    //itmRefactorAdvanced
      itmRefactorMakeResourceString.Enabled:=Editable and StringFound;
  end;
end;

procedure TMainIDE.mnuProjectClicked(Sender: TObject);
var
  ASrcEdit: TSourceEditor;
  AUnitInfo: TUnitInfo;
  NotPartOfProj: Boolean;
begin
  GetCurrentUnit(ASrcEdit,AUnitInfo);
  NotPartOfProj:=Assigned(AUnitInfo) and not AUnitInfo.IsPartOfProject;
  MainIDEBar.itmProjectAddTo.Enabled:=NotPartOfProj;
end;

procedure TMainIDE.mnuRunClicked(Sender: TObject);
begin
  with MainIDEBar do begin
    itmRunMenuBuildManyModes.Enabled:=Project1.BuildModes.Count>1;
  end;
end;

procedure TMainIDE.mnuPackageClicked(Sender: TObject);
var
  ASrcEdit: TSourceEditor;
  AUnitInfo: TUnitInfo;
  PkgFile: TPkgFile;
  CanOpenPkgOfFile, CanAddCurFile: Boolean;
begin
  CanOpenPkgOfFile:=False;
  CanAddCurFile:=False;
  GetCurrentUnit(ASrcEdit,AUnitInfo);
  if Assigned(ASrcEdit) then begin
    PkgFile:=PackageGraph.FindFileInAllPackages(AUnitInfo.Filename,true,
                                            not AUnitInfo.IsPartOfProject);
    CanOpenPkgOfFile:=Assigned(PkgFile);
    CanAddCurFile:=(not AUnitInfo.IsVirtual) and FileExistsUTF8(AUnitInfo.Filename)
          and not AUnitInfo.IsPartOfProject;
  end;
  MainIDEBar.itmPkgOpenPackageOfCurUnit.Enabled:=CanOpenPkgOfFile;
  MainIDEBar.itmPkgAddCurFileToPkg.Enabled:=CanAddCurFile;
end;

{------------------------------------------------------------------------------}
procedure TMainIDE.mnuViewInspectorClicked(Sender: TObject);
begin
  DoBringToFrontFormOrInspector(true);
end;

procedure TMainIDE.mnuViewSourceEditorClicked(Sender: TObject);
var
  i: Integer;
begin
  SourceEditorManager.ActiveOrNewSourceWindow;
  for i := 0 to SourceEditorManager.SourceWindowCount - 1 do
    SourceEditorManager.SourceWindows[i].Show;
  SourceEditorManager.ShowActiveWindowOnTop(False);
end;

{------------------------------------------------------------------------------}

procedure TMainIDE.mnuViewUnitsClicked(Sender: TObject);
begin
  DoViewUnitsAndForms(false);
end;

procedure TMainIDE.mnuViewFormsClicked(Sender: TObject);
Begin
  DoViewUnitsAndForms(true);
end;

procedure TMainIDE.mnuSourceUnitInfoClicked(Sender: TObject);
begin
  DoViewUnitInfo;
end;

procedure TMainIDE.mnuSourceUnitDependenciesClicked(Sender: TObject);
begin
  ShowUnitDependenciesClicked(Sender);
end;

procedure TMainIDE.mnuViewCodeExplorerClick(Sender: TObject);
begin
  DoShowCodeExplorer;
end;

procedure TMainIDE.mnuViewCodeBrowserClick(Sender: TObject);
begin
  DoShowCodeBrowser;
end;

procedure TMainIDE.mnuViewComponentsClick(Sender: TObject);
begin
  DoShowComponentList;
end;

procedure TMainIDE.mnuViewMacroListClick(Sender: TObject);
begin
  ShowMacroListViewer;
end;

procedure TMainIDE.mnuViewRestrictionBrowserClick(Sender: TObject);
begin
  DoShowRestrictionBrowser;
end;

procedure TMainIDE.mnuViewMessagesClick(Sender: TObject);
begin
  // it was already visible, but user does not see it, try to move in view
  DoShowMessagesView;
end;

procedure TMainIDE.mnuViewSearchResultsClick(Sender: TObject);
Begin
  DoShowSearchResultsView;
End;

procedure TMainIDE.mnuNewProjectClicked(Sender: TObject);
var
  NewProjectDesc: TProjectDescriptor;
Begin
  NewProjectDesc:=nil;
  if ChooseNewProject(NewProjectDesc)<>mrOk then exit;
  //debugln('TMainIDE.mnuNewProjectClicked ',dbgsName(NewProjectDesc));
  DoNewProject(NewProjectDesc);
end;

procedure TMainIDE.mnuNewProjectFromFileClicked(Sender: TObject);
Begin
  SourceFileMgr.NewProjectFromFile;
end;

procedure TMainIDE.mnuOpenProjectClicked(Sender: TObject);
var
  MenuItem: TIDEMenuItem;
begin
  MenuItem := nil;
  if Sender is TIDEMenuItem then
    MenuItem := TIDEMenuItem(Sender);
  SourceFileMgr.OpenProject(MenuItem);
end;

procedure TMainIDE.mnuCloseProjectClicked(Sender: TObject);
var
  DlgResult: TModalResult;
begin
  if Project1=nil then exit;

  // stop debugging/compiling/...
  if not DoResetToolStatus([rfInteractive, rfSuccessOnTrigger]) then exit;

  // check foreign windows
  if not CloseQueryIDEWindows then exit;

  // check project
  if SourceFileMgr.SomethingOfProjectIsModified then begin
    DlgResult:=IDEQuestionDialog(lisProjectChanged,
      Format(lisSaveChangesToProject, [Project1.GetTitleOrName]), mtConfirmation,
      [mrYes, lisMenuSave, mrNoToAll, lisDiscardChanges,
       mrAbort, lisDoNotCloseTheProject]);
    case DlgResult of
    mrYes:
      if not (DoSaveProject([]) in [mrOk,mrIgnore]) then exit;
    mrCancel, mrAbort:
      Exit;
    end;
  end;

  // close
  DoCloseProject;

  // ask what to do next
  DoNoProjectWizard(Sender);
end;

procedure TMainIDE.mnuSaveProjectClicked(Sender: TObject);
Begin
  DoSaveProject([]);
end;

procedure TMainIDE.mnuSaveProjectAsClicked(Sender: TObject);
begin
  DoSaveProject([sfSaveAs]);
end;

procedure TMainIDE.mnuPublishProjectClicked(Sender: TObject);
begin
  DoPublishProject([],true);
end;

procedure TMainIDE.mnuProjectInspectorClicked(Sender: TObject);
begin
  DoShowProjectInspector;
end;

procedure TMainIDE.mnuAddToProjectClicked(Sender: TObject);
begin
  DoAddActiveUnitToProject;
end;

procedure TMainIDE.mnuRemoveFromProjectClicked(Sender: TObject);
begin
  DoRemoveFromProjectDialog;
end;

procedure TMainIDE.mnuViewProjectSourceClicked(Sender: TObject);
begin
  OpenMainUnit(-1,-1,[]);
end;

procedure TMainIDE.mnuProjectOptionsClicked(Sender: TObject);
begin
  if Project1=nil then exit;
  DoOpenIDEOptions(nil, Format(dlgProjectOptionsFor, [Project1.GetTitleOrName]),
    [TProjectIDEOptions, TProjectCompilerOptions], []);
end;

function TMainIDE.UpdateProjectPOFile(AProject: TProject): TModalResult;
var
  Files: TFilenameToPointerTree;
  POFilename: String;
  AnUnitInfo: TUnitInfo;
  CurFilename: String;
  POFileAge: LongInt;
  POFileAgeValid: Boolean;
  POOutDir: String;
  LRTFilename: String;
  UnitOutputDir: String;
  RSTFilename: String;
  RSJFilename: String;
  FileList: TStringList;
begin
  Result:=mrCancel;
  if (not AProject.EnableI18N) or AProject.IsVirtual then exit(mrOk);

  POFilename := MainBuildBoss.GetProjectTargetFilename(AProject);
  if POFilename='' then begin
    DebugLn(['TMainIDE.UpdateProjectPOFile unable to get project target filename']);
    exit;
  end;
  POFilename:=ChangeFileExt(POFilename, '.po');

  if AProject.POOutputDirectory <> '' then begin
    POOutDir:=AProject.GetPOOutDirectory;
    if POOutDir<>'' then begin
      if not DirPathExistsCached(POOutDir) then begin
        Result:=ForceDirectoryInteractive(POOutDir,[]);
        if Result in [mrCancel,mrAbort] then exit;
        if Result<>mrOk then
          POOutDir:=''; // e.g. ignore if failed to create dir
      end;
      if POOutDir<>'' then
        POFilename:=AppendPathDelim(POOutDir)+ExtractFileName(POFilename);
    end;
  end;

  POFileAgeValid:=false;
  if FileExistsCached(POFilename) then begin
    POFileAge:=FileAgeCached(POFilename);
    POFileAgeValid:=true;
  end;

  //DebugLn(['TMainIDE.UpdateProjectPOFile Updating POFilename="',POFilename,'"']);

  Files := TFilenameToPointerTree.Create(false);
  FileList:=TStringList.Create;
  try
    AnUnitInfo:=AProject.FirstPartOfProject;
    while AnUnitInfo<>nil do begin
      CurFilename:=AnUnitInfo.Filename;
      AnUnitInfo:=AnUnitInfo.NextPartOfProject;
      if not FilenameIsAbsolute(CurFilename) then continue;
      if (AProject.MainFilename<>CurFilename)
      and (not FilenameIsPascalUnit(CurFilename)) then
        continue;
      // check .lrt file
      LRTFilename:=ChangeFileExt(CurFilename,'.lrt');
      if FileExistsCached(LRTFilename)
      and ((not POFileAgeValid) or (FileAgeCached(LRTFilename)>POFileAge)) then
        Files[LRTFilename]:=nil;
      // check .rst/.rsj file
      RSTFilename:=ChangeFileExt(CurFilename,'.rst');
      RSJFilename:=ChangeFileExt(CurFilename,'.rsj');
      // the compiler puts the .rst in the unit output directory if -FU is given
      if AProject.CompilerOptions.UnitOutputDirectory<>'' then
      begin
        UnitOutputDir:=AProject.GetOutputDirectory;
        if UnitOutputDir<>'' then
        begin
          RSTFilename:=TrimFilename(AppendPathDelim(UnitOutputDir)+ExtractFilename(RSTFilename));
          RSJFilename:=TrimFilename(AppendPathDelim(UnitOutputDir)+ExtractFilename(RSJFilename));
        end;
      end;
      //DebugLn(['TMainIDE.UpdateProjectPOFile Looking for .rst file ="',RSTFilename,'"']);
      if FileExistsCached(RSTFilename) and ((not POFileAgeValid) or (FileAgeCached(RSTFilename)>POFileAge)) then
        Files[RSTFilename]:=nil;
      if FileExistsCached(RSJFilename) and ((not POFileAgeValid) or (FileAgeCached(RSJFilename)>POFileAge)) then
        Files[RSJFilename]:=nil;
    end;

    // update po files
    if Files.Tree.Count=0 then exit(mrOk);
    Files.GetNames(FileList);
    try
      UpdatePoFileAndTranslations(FileList, POFilename);
      Result := mrOk;
    except
      on E:EPOFileError do begin
        IDEMessageDialog(lisCCOErrorCaption, Format(lisErrorLoadingFrom,
          [ 'Update PO file '+E.POFileName, LineEnding, E.ResFileName,
            LineEnding+LineEnding, E.Message]), mtError, [mbOk]);
      end;
    end;
  finally
    FileList.Free;
    Files.Free;
  end;
end;

procedure TMainIDE.mnuCompileProjectClicked(Sender: TObject);
Begin
  DoCompile;
end;

procedure TMainIDE.mnuBuildProjectClicked(Sender: TObject);
Begin
  DoBuildProject(crBuild,[pbfCleanCompile]);
end;

procedure TMainIDE.mnuQuickCompileProjectClicked(Sender: TObject);
begin
  DoQuickCompile;
end;

procedure TMainIDE.mnuCleanUpAndBuildProjectClicked(Sender: TObject);
begin
  if SourceFileMgr.PrepareForCompileWithMsg<>mrOk then exit;
  if ShowBuildProjectDialog(Project1)<>mrOk then exit;
  DoBuildProject(crBuild,[]);
end;

procedure TMainIDE.mnuBuildManyModesClicked(Sender: TObject);
begin
  SourceFileMgr.BuildManyModes;
end;

procedure TMainIDE.mnuAbortBuildProjectClicked(Sender: TObject);
Begin
  DoAbortBuild(false);
end;

procedure TMainIDE.mnuRunProjectClicked(Sender: TObject);
var
  SrcEdit: TSourceEditor;
  AnUnitInfo: TUnitInfo;
begin
  GetCurrentUnit(SrcEdit,AnUnitInfo);
  if (AnUnitInfo<>nil) and AnUnitInfo.RunFileIfActive then
    DoRunFile
  else
    DoRunProject;
end;

procedure TMainIDE.mnuPauseProjectClicked(Sender: TObject);
begin
  DebugBoss.DoPauseProject;
end;

procedure TMainIDE.mnuShowExecutionPointClicked(Sender: TObject);
begin
  DebugBoss.DoShowExecutionPoint;
end;

procedure TMainIDE.mnuStepIntoProjectClicked(Sender: TObject);
begin
  DebugBoss.DoStepIntoProject;
end;

procedure TMainIDE.mnuStepOverProjectClicked(Sender: TObject);
begin
  DebugBoss.DoStepOverProject;
end;

procedure TMainIDE.mnuStepIntoInstrProjectClicked(Sender: TObject);
begin
  DebugBoss.DoStepIntoInstrProject;
end;

procedure TMainIDE.mnuStepOverInstrProjectClicked(Sender: TObject);
begin
  DebugBoss.DoStepOverInstrProject;
end;

procedure TMainIDE.mnuStepOutProjectClicked(Sender: TObject);
begin
  DebugBoss.DoStepOutProject;
end;

procedure TMainIDE.mnuRunToCursorProjectClicked(Sender: TObject);
begin
  DebugBoss.DoRunToCursor;
end;

procedure TMainIDE.mnuStopProjectClicked(Sender: TObject);
begin
  DebugBoss.DoStopProject;
end;

procedure TMainIDE.mnuAttachDebuggerClicked(Sender: TObject);
var
  H: boolean;
begin
  OnProcessIDECommand(nil, ecAttach, H);
end;

procedure TMainIDE.mnuDetachDebuggerClicked(Sender: TObject);
var
  H: boolean;
begin
  OnProcessIDECommand(nil, ecDetach, H);
end;

procedure TMainIDE.mnuBuildFileClicked(Sender: TObject);
begin
  DoBuildFile(false);
end;

procedure TMainIDE.mnuRunFileClicked(Sender: TObject);
begin
  DoRunFile;
end;

procedure TMainIDE.mnuConfigBuildFileClicked(Sender: TObject);
begin
  DoConfigBuildFile;
end;

procedure TMainIDE.mnuRunParametersClicked(Sender: TObject);
begin
  if Project1=nil then exit;
  if ShowRunParamsOptsDlg(Project1.RunParameterOptions)=mrOK then
    Project1.Modified:=true;
end;

//------------------------------------------------------------------------------

procedure TMainIDE.mnuToolConfigureUserExtToolsClicked(Sender: TObject);
begin
  if ShowExtToolDialog(ExternalUserTools,GlobalMacroList)=mrOk then
  begin
    // save to environment options
    SaveEnvironment(true);
    // save shortcuts to editor options
    ExternalUserTools.SaveShortCuts(EditorOpts.KeyMap);
    EditorOpts.Save;
    UpdateExternalUserToolsInMenu;
  end;
end;

procedure TMainIDE.mnuSourceSyntaxCheckClicked(Sender: TObject);
begin
  DoCheckSyntax;
end;

procedure TMainIDE.mnuSourceGuessUnclosedBlockClicked(Sender: TObject);
begin
  DoJumpToGuessedUnclosedBlock(true);
end;

procedure TMainIDE.mnuSourceGuessMisplacedIFDEFClicked(Sender: TObject);
begin
  DoJumpToGuessedMisplacedIFDEF(true);
end;

procedure TMainIDE.mnuRefactorMakeResourceStringClicked(Sender: TObject);
begin
  DoMakeResourceString;
end;

procedure TMainIDE.mnuToolDiffClicked(Sender: TObject);
begin
  DoDiff;
end;

procedure TMainIDE.mnuViewFPDocEditorClicked(Sender: TObject);
begin
  DoShowFPDocEditor;
end;

procedure TMainIDE.mnuToolConvertDFMtoLFMClicked(Sender: TObject);
begin
  DoConvertDFMtoLFM;
end;

procedure TMainIDE.mnuToolCheckLFMClicked(Sender: TObject);
var
  LFMSrcEdit: TSourceEditor;
  LFMUnitInfo: TUnitInfo;
begin
  GetCurrentUnit(LFMSrcEdit,LFMUnitInfo);
  SourceFileMgr.CheckLFMInEditor(LFMUnitInfo, false);
end;

procedure TMainIDE.mnuToolConvertDelphiUnitClicked(Sender: TObject);
var
  OpenDialog: TOpenDialog;
  OldChange: Boolean;
  Converter: TConvertDelphiUnit;
begin
  OpenDialog:=TOpenDialog.Create(nil);
  try
    InputHistories.ApplyFileDialogSettings(OpenDialog);
    OpenDialog.Title:=lisChooseDelphiUnit;
    OpenDialog.Options:=OpenDialog.Options+[ofPathMustExist,ofFileMustExist,ofAllowMultiSelect];
    OpenDialog.Filter:=lisDelphiUnit+' (*.pas)|*.pas|'+
                       dlgAllFiles+' ('+GetAllFilesMask+')|' + GetAllFilesMask;
    if InputHistories.LastConvertDelphiUnit<>'' then begin
      OpenDialog.InitialDir:=ExtractFilePath(InputHistories.LastConvertDelphiUnit);
      OpenDialog.Filename  :=ExtractFileName(InputHistories.LastConvertDelphiUnit);
    end;
    if OpenDialog.Execute and (OpenDialog.Files.Count>0) then begin
      InputHistories.LastConvertDelphiUnit:=OpenDialog.Files[0];
      OldChange:=OpenEditorsOnCodeToolChange;
      OpenEditorsOnCodeToolChange:=true;
      Converter:=TConvertDelphiUnit.Create(OpenDialog.Files);
      try
        if Converter.Convert=mrOK then begin
          SetRecentFilesMenu;
          SaveEnvironment;
        end;
      finally
        Converter.Free;
        OpenEditorsOnCodeToolChange:=OldChange;
      end;
    end;
    InputHistories.StoreFileDialogSettings(OpenDialog);
  finally
    OpenDialog.Free;
  end;
end;

procedure TMainIDE.mnuToolConvertDelphiProjectClicked(Sender: TObject);
var
  OpenDialog: TOpenDialog;
  AFilename: string;
begin
  OpenDialog:=TOpenDialog.Create(nil);
  try
    InputHistories.ApplyFileDialogSettings(OpenDialog);
    OpenDialog.Title:=lisChooseDelphiProject;
    OpenDialog.Options:=OpenDialog.Options+[ofPathMustExist,ofFileMustExist];
    OpenDialog.Filter:=lisDelphiProject+' (*.dpr)|*.dpr|'+
                       lisLazarusProject+' (*.lpr)|*.lpr|'+
                       dlgAllFiles+' ('+GetAllFilesMask+')|' + GetAllFilesMask;
    if InputHistories.LastConvertDelphiProject<>'' then begin
      OpenDialog.InitialDir:=ExtractFilePath(InputHistories.LastConvertDelphiProject);
      OpenDialog.Filename  :=ExtractFileName(InputHistories.LastConvertDelphiProject);
    end;
    if OpenDialog.Execute then begin
      AFilename:=CleanAndExpandFilename(OpenDialog.Filename);
      if FileExistsUTF8(AFilename) then
        DoConvertDelphiProject(AFilename);
      SetRecentFilesMenu;
      SaveEnvironment;
    end;
    InputHistories.StoreFileDialogSettings(OpenDialog);
  finally
    OpenDialog.Free;
  end;
end;

procedure TMainIDE.mnuToolConvertDelphiPackageClicked(Sender: TObject);
var
  OpenDialog: TOpenDialog;
  AFilename: string;
begin
  OpenDialog:=TOpenDialog.Create(nil);
  try
    InputHistories.ApplyFileDialogSettings(OpenDialog);
    OpenDialog.Title:=lisChooseDelphiPackage;
    OpenDialog.Options:=OpenDialog.Options+[ofPathMustExist,ofFileMustExist];
    OpenDialog.Filter:=lisDelphiPackage+' (*.dpk)|*.dpk|'+
                       dlgAllFiles+' ('+GetAllFilesMask+')|' + GetAllFilesMask;
    if InputHistories.LastConvertDelphiPackage<>'' then begin
      OpenDialog.InitialDir:=ExtractFilePath(InputHistories.LastConvertDelphiPackage);
      OpenDialog.Filename  :=ExtractFileName(InputHistories.LastConvertDelphiPackage);
    end;
    if OpenDialog.Execute then begin
      AFilename:=CleanAndExpandFilename(OpenDialog.Filename);
      //debugln('TMainIDE.mnuToolConvertDelphiProjectClicked A ',AFilename);
      if FileExistsUTF8(AFilename) then
        DoConvertDelphiPackage(AFilename);
      SetRecentFilesMenu;
      SaveEnvironment;
    end;
    InputHistories.StoreFileDialogSettings(OpenDialog);
  finally
    OpenDialog.Free;
  end;
end;

procedure TMainIDE.mnuToolConvertEncodingClicked(Sender: TObject);
begin
  ShowConvertEncodingDlg;
end;

procedure TMainIDE.mnuToolManageExamplesClicked(Sender: TObject);
begin
  DoExampleManager();
end;

procedure TMainIDE.mnuToolBuildLazarusClicked(Sender: TObject);
begin
  if ToolStatus<>itNone then exit;
  with MiscellaneousOptions do
    if BuildLazProfiles.ConfirmBuild then
      if IDEMessageDialog(lisConfirmation, Format(lisConfirmLazarusRebuild, [
        BuildLazProfiles.Current.Name]),
                    mtConfirmation, mbYesNo)<>mrYes then
        exit;
  DoBuildLazarus([]);
end;

procedure TMainIDE.mnuToolBuildAdvancedLazarusClicked(Sender: TObject);
var
  i: Integer;
  FoundProfToBuild: Boolean;
  s: String;
begin
  if ToolStatus<>itNone then exit;
  with MiscellaneousOptions do begin
    FoundProfToBuild:=False;
    s:=sLineBreak+sLineBreak;
    for i:=0 to BuildLazProfiles.Selected.Count-1 do
      if BuildLazProfiles.IndexByName(BuildLazProfiles.Selected[i])<>-1 then begin
        s:=s+BuildLazProfiles.Selected[i]+sLineBreak;
        FoundProfToBuild:=True;
      end;
    if not FoundProfToBuild then begin
      ShowMessage(lisNoBuildProfilesSelected);
      exit;
    end;
    if BuildLazProfiles.ConfirmBuild then
      if IDEMessageDialog(lisConfirmation, Format(lisConfirmBuildAllProfiles, [s
        +sLineBreak]), mtConfirmation, mbYesNo)<>mrYes then
        exit;
    DoBuildAdvancedLazarus(BuildLazProfiles.Selected);
  end;
end;

procedure TMainIDE.mnuToolConfigBuildLazClicked(Sender: TObject);
var
  CmdLineDefines: TDefineTemplate;
  LazSrcTemplate: TDefineTemplate;
  LazSrcDirTemplate: TDefineTemplate;
  DlgResult: TModalResult;
begin
  //if ToolStatus<>itNone then exit;
  if fBuilder=Nil then
    fBuilder:=TLazarusBuilder.Create;    // Will be freed in the very end.
  MainBuildBoss.SetBuildTargetIDE;
  try
    DlgResult:=fBuilder.ShowConfigureBuildLazarusDlg(MiscellaneousOptions.BuildLazProfiles);
  finally
    MainBuildBoss.SetBuildTargetProject1(true);
  end;

  if DlgResult in [mrOk,mrYes,mrAll] then begin
    MiscellaneousOptions.Modified:=true;
    MiscellaneousOptions.Save;
    IncreaseCompilerParseStamp;
    if DlgResult=mrAll then
      DoBuildAdvancedLazarus(MiscellaneousOptions.BuildLazProfiles.Selected)
    else if DlgResult=mrYes then begin
      LazSrcTemplate:=
        CodeToolBoss.DefineTree.FindDefineTemplateByName(StdDefTemplLazarusSources,true);
      if Assigned(LazSrcTemplate) then begin
        LazSrcDirTemplate:=LazSrcTemplate.FindChildByName(StdDefTemplLazarusSrcDir);
        if Assigned(LazSrcDirTemplate) then begin
          CmdLineDefines:=CodeToolBoss.DefinePool.CreateFPCCommandLineDefines(
                    StdDefTemplLazarusBuildOpts,
                    MiscellaneousOptions.BuildLazProfiles.Current.ExtraOptions,
                    true,CodeToolsOpts);
          CodeToolBoss.DefineTree.ReplaceChild(LazSrcDirTemplate,CmdLineDefines,
                                               StdDefTemplLazarusBuildOpts);
        end;
      end;
      DoBuildLazarus([]);
    end;
  end;
end;

procedure TMainIDE.mnuExternalUserToolClick(Sender: TObject);
// Handler for clicking on a menuitem for a custom external tool.
var
  Index: integer;
begin
  if not (Sender is TIDEMenuItem) then exit;
  Index:=itmCustomTools.IndexOf(TIDEMenuItem(Sender))-1;
  if (Index<0)
  or (Index>=ExternalUserTools.Count)
  then exit;
  if ExternalTools.RunningCount=0 then
    IDEMessagesWindow.Clear;
  DoRunExternalTool(Index,false);
end;

procedure TMainIDE.mnuEnvGeneralOptionsClicked(Sender: TObject);
begin
  DoOpenIDEOptions;
end;

//------------------------------------------------------------------------------

procedure TMainIDE.SaveDesktopSettings(TheEnvironmentOptions: TEnvironmentOptions);
// Called also before reading EnvironmentOptions
begin
  IDEWindowCreators.SimpleLayoutStorage.StoreWindowPositions;
  // do not auto show the search results view
  IDEWindowCreators.SimpleLayoutStorage.ItemByFormID(
    NonModalIDEWindowNames[nmiwSearchResultsViewName]).Visible:=false;

  if ObjectInspector1<>nil then
    TheEnvironmentOptions.ObjectInspectorOptions.Assign(ObjectInspector1);
end;

procedure TMainIDE.PackageTranslated(APackage: TLazPackage);
begin
  if APackage=PackageGraph.SynEditPackage then begin
    EditorOpts.TranslateResourceStrings;
  end;
end;

procedure TMainIDE.LoadDesktopSettings(TheEnvironmentOptions: TEnvironmentOptions);
begin
  if ObjectInspector1<>nil then
    TheEnvironmentOptions.ObjectInspectorOptions.AssignTo(ObjectInspector1);
  if MessagesView<>nil then
    MessagesView.ApplyIDEOptions;
end;

procedure TMainIDE.OnLoadIDEOptions(Sender: TObject; AOptions: TAbstractIDEOptions);
begin
  if AOptions is TEnvironmentOptions then
    LoadDesktopSettings(AOptions as TEnvironmentOptions);
end;

procedure TMainIDE.OnSaveIDEOptions(Sender: TObject; AOptions: TAbstractIDEOptions);
begin
  if AOptions is TEnvironmentOptions then
    SaveDesktopSettings(AOptions as TEnvironmentOptions);
end;

procedure TMainIDE.DoOpenIDEOptions(AEditor: TAbstractIDEOptionsEditorClass;
  ACaption: String; AOptionsFilter: array of TAbstractIDEOptionsClass;
  ASettings: TIDEOptionsEditorSettings);
var
  IDEOptionsDialog: TIDEOptionsDialog;
  OptionsFilter: TIDEOptionsEditorFilter;
  PaletteOpt: TCompPaletteOptionsFrame;
  i: Integer;
begin
  IDEOptionsDialog := TIDEOptionsDialog.Create(nil);
  try
    if ACaption <> '' then
      IDEOptionsDialog.Caption := ACaption;
    if Length(AOptionsFilter) = 0 then
    begin
      SetLength(OptionsFilter, 1);
      if AEditor <> nil then
        OptionsFilter[0] := AEditor.SupportedOptionsClass
      else
        OptionsFilter[0] := TAbstractIDEEnvironmentOptions;
    end
    else
    begin
      SetLength(OptionsFilter, Length(AOptionsFilter));
      for i := 0 to Length(AOptionsFilter) - 1 do
        OptionsFilter[i] := AOptionsFilter[i];
    end;
    IDEOptionsDialog.OptionsFilter := OptionsFilter;
    IDEOptionsDialog.Settings := ASettings;
    IDEOptionsDialog.OpenEditor(AEditor);
    IDEOptionsDialog.OnLoadIDEOptionsHook:=@Self.OnLoadIDEOptions;
    IDEOptionsDialog.OnSaveIDEOptionsHook:=@Self.OnSaveIDEOptions;
    IDEOptionsDialog.ReadAll;
    if IDEOptionsDialog.ShowModal = mrOk then begin
      IDEOptionsDialog.WriteAll(false);
      // Update component palette only when needed.
      PaletteOpt := TCompPaletteOptionsFrame(IDEOptionsDialog.FindEditor(TCompPaletteOptionsFrame));
      if Assigned(PaletteOpt) and PaletteOpt.ConfigChanged then
        IDEComponentPalette.Update(True);
      // Update TaskBarBehavior immediately.
      if EnvironmentOptions.SingleTaskBarButton then
        Application.TaskBarBehavior := tbSingleButton
      else
        Application.TaskBarBehavior := tbDefault;
    end else begin
      // restore
      IDEOptionsDialog.WriteAll(true);
    end;
  finally
    IDEOptionsDialog.Free;
  end;
end;

procedure TMainIDE.DoEnvironmentOptionsBeforeRead(Sender: TObject);
begin
  // update EnvironmentOptions (save current window positions)
  SaveDesktopSettings(EnvironmentOptions);
end;

procedure TMainIDE.DoEnvironmentOptionsBeforeWrite(Sender: TObject; Restore: boolean);
begin
  if Restore then exit;
  OldCompilerFilename:=EnvironmentOptions.CompilerFilename;
  OldLanguage:=EnvironmentOptions.LanguageID;
end;

procedure TMainIDE.DoEnvironmentOptionsAfterWrite(Sender: TObject; Restore: boolean);
var
  MacroValueChanged,
  FPCSrcDirChanged, FPCCompilerChanged,
  LazarusSrcDirChanged: boolean;

  procedure ChangeMacroValue(const MacroName, NewValue: string);
  begin
    with CodeToolBoss.GlobalValues do begin
      if Variables[ExternalMacroStart+MacroName]=NewValue then exit;
      if Macroname='FPCSrcDir' then
        FPCSrcDirChanged:=true;
      if Macroname='LazarusDir' then
        LazarusSrcDirChanged:=true;
      Variables[ExternalMacroStart+MacroName]:=NewValue;
    end;
    MacroValueChanged:=true;
  end;

  procedure UpdateDesigners;
  var
    AForm: TCustomForm;
    AnUnitInfo: TUnitInfo;
    ADesigner: TDesigner;
  begin
    if Project1=nil then exit;
    AnUnitInfo := Project1.FirstUnitWithComponent;
    while AnUnitInfo <> nil do
    begin
      if (AnUnitInfo.Component<>nil) then
      begin
        AForm := FormEditor1.GetDesignerForm(AnUnitInfo.Component);
        if AForm <> nil then
        begin
          ADesigner := TDesigner(AForm.Designer);
          if ADesigner <> nil then
          begin
            ADesigner.ShowEditorHints := EnvironmentOptions.ShowEditorHints;
            ADesigner.ShowComponentCaptions := EnvironmentOptions.ShowComponentCaptions;
          end;
        end;
      end;
      AnUnitInfo := AnUnitInfo.NextUnitWithComponent;
    end;
    InvalidateAllDesignerForms;
  end;

  procedure UpdateObjectInspector;
  begin
    if ObjectInspector1<>nil then
      EnvironmentOptions.ObjectInspectorOptions.AssignTo(ObjectInspector1);
  end;

  procedure UpdateMessagesView;
  begin
    MessagesView.ApplyIDEOptions;
  end;

begin
  if Restore then exit;
  // invalidate cached substituted macros
  IncreaseCompilerParseStamp;
  UpdateDefaultPasFileExt;
  if OldLanguage <> EnvironmentOptions.LanguageID then
  begin
    TranslateResourceStrings(EnvironmentOptions.GetParsedLazarusDirectory,
                             EnvironmentOptions.LanguageID);
    PkgBoss.TranslateResourceStrings;
  end;
  // set global variables
  MainBuildBoss.UpdateEnglishErrorMsgFilename;
  MacroValueChanged:=false;
  FPCSrcDirChanged:=false;
  FPCCompilerChanged:=OldCompilerFilename<>EnvironmentOptions.CompilerFilename;
  LazarusSrcDirChanged:=false;
  ChangeMacroValue('LazarusDir',EnvironmentOptions.GetParsedLazarusDirectory);
  ChangeMacroValue('FPCSrcDir',EnvironmentOptions.GetParsedFPCSourceDirectory);
  MainBuildBoss.EnvOptsChanged;

  if MacroValueChanged then CodeToolBoss.DefineTree.ClearCache;
  //debugln(['TMainIDE.DoEnvironmentOptionsAfterWrite FPCCompilerChanged=',FPCCompilerChanged,' FPCSrcDirChanged=',FPCSrcDirChanged,' LazarusSrcDirChanged=',LazarusSrcDirChanged]);
  if FPCCompilerChanged or FPCSrcDirChanged then
    MainBuildBoss.SetBuildTargetProject1(false);

  // update environment
  UpdateDesigners;
  UpdateObjectInspector;
  UpdateMessagesView;
  SetupHints;
  Application.ShowButtonGlyphs := EnvironmentOptions.ShowButtonGlyphs;
  Application.ShowMenuGlyphs := EnvironmentOptions.ShowMenuGlyphs;
  if EnvironmentOptions.SingleTaskBarButton then
    Application.TaskBarBehavior := tbSingleButton
  else
    Application.TaskBarBehavior := tbDefault;

  // reload lazarus packages
  if LazarusSrcDirChanged then
    PkgBoss.LazarusSrcDirChanged;
  UpdateCaption;
end;

procedure TMainIDE.DoEditorOptionsBeforeRead(Sender: TObject);
begin
  // update editor options?
  if Project1=nil then exit;
  Project1.UpdateAllCustomHighlighter;
end;

procedure TMainIDE.DoEditorOptionsAfterWrite(Sender: TObject; Restore: boolean);
begin
  if Restore then exit;
  if Project1<>nil then
    Project1.UpdateAllSyntaxHighlighter;
  SourceEditorManager.BeginGlobalUpdate;
  try
    UpdateHighlighters(True);
    SourceEditorManager.ReloadEditorOptions;
    ReloadMenuShortCuts;
    UpdateMacroListViewer;
  finally
    SourceEditorManager.EndGlobalUpdate;
  end;
end;

procedure TMainIDE.DoCodetoolsOptionsAfterWrite(Sender: TObject; Restore: boolean);
begin
  if Restore then exit;
  CodeToolsOpts.AssignTo(CodeToolBoss);
end;

procedure TMainIDE.DoCodeExplorerOptionsAfterWrite(Sender: TObject; Restore: boolean);
begin
  if Restore then exit;
  if CodeExplorerView<>nil then
    CodeExplorerView.Refresh(true);
end;

procedure TMainIDE.DoProjectOptionsBeforeRead(Sender: TObject);
var
  ActiveSrcEdit: TSourceEditor;
  ActiveUnitInfo: TUnitInfo;
  AProject: TProject;
begin
  //debugln(['TMainIDE.DoProjectOptionsBeforeRead ',DbgSName(Sender)]);
  ActiveSrcEdit:=nil;
  BeginCodeTool(ActiveSrcEdit, ActiveUnitInfo, []);
  AProject:=(Sender as TProjectIDEOptions).Project;
  AProject.BackupSession;
  AProject.BackupBuildModes;
  AProject.UpdateExecutableType;
  AProject.UseAsDefault := False;
end;

procedure TMainIDE.DoProjectOptionsAfterWrite(Sender: TObject; Restore: boolean);
var
  AProject: TProject;
  aFilename: String;

  function GetTitle: String;
  begin
    Result := '';
    if (AProject = nil) or (AProject.MainUnitID < 0) then
      Exit;
    CodeToolBoss.GetApplicationTitleStatement(AProject.MainUnitInfo.Source, Result);
  end;

  function SetTitle: Boolean;
  var
    OldTitle: String;
    NewTitle: String;
  begin
    Result := True;
    if (AProject.MainUnitID < 0) or
      (not (pfMainUnitHasTitleStatement in AProject.Flags)) then
      Exit;
    OldTitle := GetTitle;
    if (OldTitle = '') and AProject.TitleIsDefault then
      Exit;

    NewTitle:=AProject.GetTitle;
    if (OldTitle <> NewTitle) and (not AProject.TitleIsDefault) then
      if not CodeToolBoss.SetApplicationTitleStatement(AProject.MainUnitInfo.Source, NewTitle) then
      begin
        IDEMessageDialog(lisProjOptsError,
          Format(lisUnableToChangeProjectTitleInSource, [LineEnding, CodeToolBoss.ErrorMessage]),
          mtWarning, [mbOk]);
        Result := False;
        Exit;
      end;// set Application.Title:= statement

    if (OldTitle <> '') and AProject.TitleIsDefault then
      if not CodeToolBoss.RemoveApplicationTitleStatement(AProject.MainUnitInfo.Source) then
      begin
        IDEMessageDialog(lisProjOptsError,
          Format(lisUnableToRemoveProjectTitleFromSource, [LineEnding, CodeToolBoss.ErrorMessage]),
          mtWarning, [mbOk]);
        Result := False;
        Exit;
      end;// delete title
  end;

  function SetAutoCreateForms: boolean;
  var
    i: integer;
    OldList: TStrings;
  begin
    Result := True;
    if (AProject.MainUnitID < 0) or
      (not (pfMainUnitHasCreateFormStatements in AProject.Flags)) then
      Exit;
    OldList := AProject.GetAutoCreatedFormsList;
    if (OldList = nil) then
      Exit;
    try
      if OldList.Count = AProject.TmpAutoCreatedForms.Count then
      begin
        { Just exit if the form list is the same }
        i := OldList.Count - 1;
        while (i >= 0)
        and (SysUtils.CompareText(OldList[i], AProject.TmpAutoCreatedForms[i]) = 0) do
          Dec(i);
        if i < 0 then
          Exit;
      end;

      if not CodeToolBoss.SetAllCreateFromStatements(AProject.MainUnitInfo.Source,
        AProject.TmpAutoCreatedForms) then
      begin
        IDEMessageDialog(lisProjOptsError,
          Format(lisProjOptsUnableToChangeTheAutoCreateFormList, [LineEnding]),
          mtWarning, [mbOK]);
        Result := False;
        Exit;
      end;
    finally
      OldList.Free;
    end;
  end;

begin
  //debugln(['TMainIDE.DoProjectOptionsAfterWrite ',DbgSName(Sender),' Restore=',Restore]);
  AProject:=(Sender as TProjectIDEOptions).Project;
  if not Restore then
  begin
    SetTitle;
    SetAutoCreateForms;
    // extend include path
    AProject.AutoAddOutputDirToIncPath;
    if AProject.ProjResources.Modified and (AProject.MainUnitID >= 0) then
    begin
      if not AProject.ProjResources.Regenerate(AProject.MainFilename, True, False, '') then
        IDEMessageDialog(lisCCOWarningCaption, AProject.ProjResources.Messages.Text,
                         mtWarning, [mbOk]);
    end;
    UpdateCaption;
    AProject.DefineTemplates.AllChanged;
  end;
  if Restore then
    AProject.RestoreBuildModes;
  IncreaseCompilerParseStamp;
  MainBuildBoss.SetBuildTargetProject1(false);
  if (not Restore) and AProject.UseAsDefault then
  begin
    aFilename:=AppendPathDelim(GetPrimaryConfigPath)+DefaultProjectOptionsFilename;
    AProject.WriteProject([pwfSkipSeparateSessionInfo,pwfIgnoreModified],
      aFilename,EnvironmentOptions.BuildMatrixOptions);
  end;
  if Restore then
    AProject.RestoreSession;
end;

procedure TMainIDE.ComponentPaletteClassSelected(Sender: TObject);
begin
  if (Screen.CustomFormZOrderCount > 1)
  and Assigned(Screen.CustomFormsZOrdered[1].Designer) then
    // previous active form was designer form
    ShowDesignerForm(Screen.CustomFormsZOrdered[1])
  else
    DoShowDesignerFormOfCurrentSrc;
end;

procedure TMainIDE.SelComponentPageButtonClick(Sender: TObject);
var
  zPos: TPoint;
  btn: TGraphicControl;
begin
  btn := Sender as TGraphicControl;
  zPos:=point(btn.Width,btn.Height);
  zPos:=btn.ClientToScreen(zPos);
  if DlgCompPagesPopup=nil then
    Application.CreateForm(TDlgCompPagesPopup, DlgCompPagesPopup);
  if not DlgCompPagesPopup.Visible then
  begin
    DlgCompPagesPopup.Left:=zPos.x-(DlgCompPagesPopup.Width div 2);
    DlgCompPagesPopup.Top:=zPos.y-5;
    DlgCompPagesPopup.FixBounds;
    DlgCompPagesPopup.Show;
  end else
    DlgCompPagesPopup.Close;
end;

procedure TMainIDE.mnuEnvEditorOptionsClicked(Sender: TObject);
begin
  DoOpenIDEOptions(TEditorGeneralOptionsFrame);
end;

procedure TMainIDE.mnuEnvCodeTemplatesClicked(Sender: TObject);
begin
  if ShowCodeTemplateDialog=mrOk then begin
    UpdateHighlighters(True);
    SourceEditorManager.ReloadEditorOptions;
  end;
end;

procedure TMainIDE.mnuEnvCodeToolsDefinesEditorClicked(Sender: TObject);
begin
  ShowCodeToolsDefinesEditor(CodeToolBoss,CodeToolsOpts,GlobalMacroList);
end;

procedure TMainIDE.mnuEnvRescanFPCSrcDirClicked(Sender: TObject);
begin
  if ToolStatus<>itNone then exit;
  IncreaseBuildMacroChangeStamp;
  MainBuildBoss.RescanCompilerDefines(false,true,false,false);
end;

procedure TMainIDE.mnuWindowManagerClicked(Sender: TObject);
begin
  ShowEditorFileManagerForm;
end;

procedure TMainIDE.SaveEnvironment(Immediately: boolean);
begin
  if not Immediately then
  begin
    if FIDEStarted then
      fNeedSaveEnvironment:=true;
    exit;
  end;
  fNeedSaveEnvironment:=false;
  SaveDesktopSettings(EnvironmentOptions);
  EnvironmentOptions.Save(false);
  EditorMacroListViewer.SaveGlobalInfo;
  //debugln('TMainIDE.SaveEnvironment A ',dbgsName(ObjectInspector1.Favorites));
  if (ObjectInspector1<>nil) and (ObjectInspector1.Favorites<>nil) then
    SaveOIFavoriteProperties(ObjectInspector1.Favorites);
end;

function TMainIDE.DoOpenComponent(const UnitFilename: string;
  OpenFlags: TOpenFlags; CloseFlags: TCloseFlags; out Component: TComponent): TModalResult;
begin
  Result:=SourceFileMgr.OpenComponent(UnitFilename, OpenFlags, CloseFlags, Component);
end;

function TMainIDE.DoFixupComponentReferences(
  RootComponent: TComponent; OpenFlags: TOpenFlags): TModalResult;
var
  RootUnitInfo: TUnitInfo;
  UnitFilenames: TStrings;
  ComponentNameToUnitFilename: TStringToStringTree;

  procedure AddFile(List: TStrings; aFilename: string);
  var
    i: Integer;
  begin
    for i:=0 to List.Count-1 do
      if CompareFilenames(List[i],aFilename)=0 then exit;
    List.Add(aFilename);
  end;

  procedure FindUsedUnits;
  var
    CurUnitFilenames: TStrings;
    i: Integer;
    UnitFilename: string;
    LFMFilename: String;
    LFMCode: TCodeBuffer;
    LFMType: String;
    LFMComponentName: String;
    LFMClassName: String;
    ModalResult: TModalResult;
    CTResult: Boolean;
  begin
    if UnitFilenames<>nil then exit;
    UnitFilenames:=TStringList.Create;
    ComponentNameToUnitFilename:=TStringToStringTree.Create(false);

    // search in the used units of RootUnitInfo
    CurUnitFilenames:=nil;
    try
      CTResult:=CodeToolBoss.FindUsedUnitFiles(RootUnitInfo.Source,CurUnitFilenames);
      if not CTResult then begin
        DebugLn(['TMainIDE.DoFixupComponentReferences.FindUsedUnits failed parsing ',RootUnitInfo.Filename]);
        // ignore the error. This was just a fallback search.
      end;
      if (CurUnitFilenames<>nil) then begin
        for i:=0 to CurUnitFilenames.Count-1 do
          AddFile(UnitFilenames,CurUnitFilenames[i]);
      end;
    finally
      CurUnitFilenames.Free;
    end;

    // search in the used units of the .lpr file
    if RootUnitInfo.IsPartOfProject
    and (Project1.MainUnitInfo<>nil)
    and (Project1.MainUnitInfo.Source<>nil)
    and (pfMainUnitIsPascalSource in Project1.Flags) then begin
      CurUnitFilenames:=nil;
      try
        CTResult:=CodeToolBoss.FindUsedUnitFiles(Project1.MainUnitInfo.Source,
          CurUnitFilenames);
        if not CTResult then begin
          DebugLn(['TMainIDE.DoFixupComponentReferences.FindUsedUnits failed parsing ',Project1.MainUnitInfo.Filename]);
          // ignore the error. This was just a fallback search.
        end;
        if (CurUnitFilenames<>nil) then begin
          for i:=0 to CurUnitFilenames.Count-1 do
            AddFile(UnitFilenames,CurUnitFilenames[i]);
        end;
      finally
        CurUnitFilenames.Free;
      end;
    end;

    // parse once all available component names in all .lfm files
    for i:=0 to UnitFilenames.Count-1 do begin
      UnitFilename:=UnitFilenames[i];
      // ToDo: use UnitResources
      LFMFilename:=ChangeFileExt(UnitFilename,'.lfm');
      if not FileExistsCached(LFMFilename) then
        LFMFilename:=ChangeFileExt(UnitFilename,'.dfm');
      if FileExistsCached(LFMFilename) then begin
        // load the lfm file
        ModalResult:=LoadCodeBuffer(LFMCode,LFMFilename,[lbfCheckIfText],true);
        if ModalResult<>mrOk then begin
          debugln('TMainIDE.DoFixupComponentReferences Failed loading ',LFMFilename);
          if ModalResult=mrAbort then break;
        end else begin
          // read the LFM component name
          ReadLFMHeader(LFMCode.Source,LFMType,LFMComponentName,LFMClassName);
          if LFMComponentName<>'' then
            ComponentNameToUnitFilename.Add(LFMComponentName,UnitFilename);
        end;
      end;
    end;
  end;

  function FindUnitFilename(const aComponentName: string): string;
  var
    RefUnitInfo: TUnitInfo;
    UnitFilename: string;
  begin
    if RootUnitInfo.IsPartOfProject then begin
      // search in the project component names
      RefUnitInfo:=Project1.UnitWithComponentName(aComponentName,true);
      if RefUnitInfo<>nil then begin
        Result:=RefUnitInfo.Filename;
        exit;
      end;
    end;
    // ToDo: search in owner+used packages

    FindUsedUnits;

    // search in the used units
    if (ComponentNameToUnitFilename<>nil) then begin
      UnitFilename:=ComponentNameToUnitFilename[aComponentName];
      if UnitFilename<>'' then begin
        Result:=UnitFilename;
        exit;
      end;
    end;

    DebugLn(['FindUnitFilename missing: ',aComponentName]);
    Result:='';
  end;

  function LoadDependencyHidden(const RefRootName: string): TModalResult;
  var
    LFMFilename: String;
    UnitCode, LFMCode: TCodeBuffer;
    ModalResult: TModalResult;
    UnitFilename: String;
    RefUnitInfo: TUnitInfo;
  begin
    Result:=mrCancel;

    // load lfm
    UnitFilename:=FindUnitFilename(RefRootName);
    if UnitFilename='' then begin
      DebugLn(['TMainIDE.DoFixupComponentReferences.LoadDependencyHidden failed to find lfm for "',RefRootName,'"']);
      exit(mrCancel);
    end;
    // ToDo: use UnitResources
    LFMFilename:=ChangeFileExt(UnitFilename,'.lfm');
    if not FileExistsUTF8(LFMFilename) then
      LFMFilename:=ChangeFileExt(UnitFilename,'.dfm');
    ModalResult:=LoadCodeBuffer(LFMCode,LFMFilename,[lbfCheckIfText],false);
    if ModalResult<>mrOk then begin
      debugln('TMainIDE.DoFixupComponentReferences Failed loading ',LFMFilename);
      exit(mrCancel);
    end;

    RefUnitInfo:=Project1.UnitInfoWithFilename(UnitFilename);
    // create unit info
    if RefUnitInfo=nil then begin
      RefUnitInfo:=TUnitInfo.Create(nil);
      RefUnitInfo.Filename:=UnitFilename;
      Project1.AddFile(RefUnitInfo,false);
    end;

    if RefUnitInfo.Source = nil then
    begin
      ModalResult := LoadCodeBuffer(UnitCode, UnitFileName, [lbfCheckIfText],false);
      if ModalResult<>mrOk then begin
        debugln('TMainIDE.DoFixupComponentReferences Failed loading ',UnitFilename);
        exit(mrCancel);
      end;
      RefUnitInfo.Source := UnitCode;
    end;

    if RefUnitInfo.Component<>nil then begin
      Result:=mrOk;
      exit;
    end;

    if RefUnitInfo.LoadingComponent then begin
      Result:=mrRetry;
      exit;
    end;

    // load resource hidden
    Result:=SourceFileMgr.LoadLFM(RefUnitInfo,LFMCode,
                                  OpenFlags+[ofLoadHiddenResource],[]);
    //DebugLn(['LoadDependencyHidden ',dbgsname(RefUnitInfo.Component)]);
  end;

  procedure GatherRootComponents(AComponent: TComponent; List: TFPList);
  var
    i: Integer;
  begin
    List.Add(AComponent);
    for i:=0 to AComponent.ComponentCount-1 do
      if csInline in AComponent.Components[i].ComponentState then
        GatherRootComponents(AComponent.Components[i],List);
  end;

var
  CurRoot: TComponent;
  i, j: Integer;
  RefRootName: string;
  RootComponents: TFPList;
  ReferenceRootNames: TStringList;
  ReferenceInstanceNames: TStringList;
  LoadResult: TModalResult;
  LoadingReferenceNames: TStringList;
begin
  //debugln(['TMainIDE.DoFixupComponentReferences START']);
  Result:=mrOk;
  if Project1=nil then exit;

  CurRoot:=RootComponent;
  while CurRoot.Owner<>nil do
    CurRoot:=CurRoot.Owner;
  RootUnitInfo:=Project1.UnitWithComponent(CurRoot);
  if RootUnitInfo=nil then begin
    debugln(['TMainIDE.DoFixupComponentReferences WARNING: component without unitinfo: ',DbgSName(RootComponent),' CurRoot=',DbgSName(CurRoot)]);
    exit;
  end;

  UnitFilenames:=nil;
  ComponentNameToUnitFilename:=nil;
  RootComponents:=TFPList.Create;
  ReferenceRootNames:=TStringList.Create;
  ReferenceInstanceNames:=TStringList.Create;
  LoadingReferenceNames:=TStringList.Create;
  try
    BeginFixupComponentReferences;
    GatherRootComponents(RootComponent,RootComponents);
    for i:=0 to RootComponents.Count-1 do begin
      CurRoot:=TComponent(RootComponents[i]);

      // load referenced components
      ReferenceRootNames.Clear;
      GetFixupReferenceNames(CurRoot,ReferenceRootNames);
      //debugln(['TMainIDE.DoFixupComponentReferences ',i,'/',RootComponents.Count,' ',DbgSName(CurRoot),' References=',ReferenceRootNames.Count]);
      for j:=0 to ReferenceRootNames.Count-1 do begin
        RefRootName:=ReferenceRootNames[j];
        ReferenceInstanceNames.Clear;
        GetFixupInstanceNames(CurRoot,RefRootName,ReferenceInstanceNames);

        DebugLn(['TMainIDE.DoFixupComponentReferences UNRESOLVED BEFORE loading ',j,' Root=',dbgsName(CurRoot),' RefRoot=',RefRootName,' Refs="',Trim(ReferenceInstanceNames.Text),'"']);

        // load the referenced component
        LoadResult:=LoadDependencyHidden(RefRootName);

        if LoadResult=mrRetry then begin
          // the other component is still loading
          // this means both components reference each other
          LoadingReferenceNames.Add(RefRootName);
        end
        else if LoadResult<>mrOk then begin
          // ToDo: give a nice error message and give user the choice between
          // a) ignore and loose the references
          // b) undo the opening (close the designer forms)
          DebugLn(['TMainIDE.DoFixupComponentReferences failed loading component ',RefRootName]);
          Result:=mrCancel;
        end;
      end;
    end;

    // fixup references
    try
      GlobalFixupReferences;
    except
      on E: Exception do begin
        DebugLn(['TMainIDE.DoFixupComponentReferences GlobalFixupReferences ',E.Message]);
        DumpExceptionBackTrace;
      end;
    end;

    for i:=0 to RootComponents.Count-1 do begin
      CurRoot:=TComponent(RootComponents[i]);
      // clean up dangling references
      ReferenceRootNames.Clear;
      GetFixupReferenceNames(CurRoot,ReferenceRootNames);
      for j:=0 to ReferenceRootNames.Count-1 do begin
        RefRootName:=ReferenceRootNames[j];
        if UTF8SearchInStringList(LoadingReferenceNames,RefRootName)>=0
        then
          continue;
        ReferenceInstanceNames.Clear;
        GetFixupInstanceNames(CurRoot,RefRootName,ReferenceInstanceNames);
        DebugLn(['TMainIDE.DoFixupComponentReferences UNRESOLVED AFTER loading ',j,' ',dbgsName(CurRoot),' RefRoot=',RefRootName,' Refs="',Trim(ReferenceInstanceNames.Text),'"']);

        // forget the rest of the dangling references
        RemoveFixupReferences(CurRoot,RefRootName);
      end;
    end;
  finally
    EndFixupComponentReferences;
    LoadingReferenceNames.Free;
    RootComponents.Free;
    UnitFilenames.Free;
    ComponentNameToUnitFilename.Free;
    ReferenceRootNames.Free;
    ReferenceInstanceNames.Free;
  end;
end;

procedure TMainIDE.BeginFixupComponentReferences;
begin
  inc(FFixingGlobalComponentLock);
  if FFixingGlobalComponentLock=1 then
    RegisterFindGlobalComponentProc(@FindDesignComponent);
end;

procedure TMainIDE.EndFixupComponentReferences;
begin
  dec(FFixingGlobalComponentLock);
  if FFixingGlobalComponentLock=0 then
    UnregisterFindGlobalComponentProc(@FindDesignComponent);
end;

function TMainIDE.GetAncestorUnit(AnUnitInfo: TUnitInfo): TUnitInfo;
begin
  if (AnUnitInfo=nil) or (AnUnitInfo.Component=nil) then
    Result:=nil
  else
    Result:=AnUnitInfo.FindAncestorUnit;
end;

function TMainIDE.GetAncestorLookupRoot(AnUnitInfo: TUnitInfo): TComponent;
var
  AncestorUnit: TUnitInfo;
begin
  AncestorUnit:=GetAncestorUnit(AnUnitInfo);
  if AncestorUnit<>nil then
    Result:=AncestorUnit.Component
  else
    Result:=nil;
end;

procedure TMainIDE.UpdateSaveMenuItemsAndButtons(UpdateSaveAll: boolean);
var
  SrcEdit: TSourceEditor;
  AnUnitInfo: TUnitInfo;
begin
  GetCurrentUnit(SrcEdit,AnUnitInfo);
  // menu items
  if UpdateSaveAll then
    MainIDEBar.itmProjectSave.Enabled :=
     SourceFileMgr.SomethingOfProjectIsModified  or ((Project1<>nil) and Project1.IsVirtual);
  MainIDEBar.itmFileSave.Enabled := ((SrcEdit<>nil) and SrcEdit.Modified)
                              or ((AnUnitInfo<>nil) and AnUnitInfo.IsVirtual);
  MainIDEBar.itmFileExportHtml.Enabled := (SrcEdit<>nil);
  if UpdateSaveAll then
    MainIDEBar.itmFileSaveAll.Enabled := MainIDEBar.itmProjectSave.Enabled;
  // toolbar buttons
  MainIDEBar.BuildModeSpeedButton.Visible:=(Project1<>nil)
                                       and (Project1.BuildModes.Count>1);
  MainIDEBar.SaveSpeedBtn.Enabled := MainIDEBar.itmFileSave.Enabled;
  if UpdateSaveAll then
    MainIDEBar.SaveAllSpeedBtn.Enabled := MainIDEBar.itmFileSaveAll.Enabled;
end;

procedure TMainIDE.OnSaveProjectUnitSessionInfo(AUnitInfo: TUnitInfo);

  function GetWindowState(ACustomForm: TCustomForm): TWindowState;
  begin
    Result := wsNormal;
    if ACustomForm.HandleAllocated then
      if IsIconic(ACustomForm.Handle) then
        Result := wsMinimized
      else
      if IsZoomed(ACustomForm.Handle) then
        Result := wsMaximized;
  end;
var
  DesignerForm: TCustomForm;
begin
  if (AUnitInfo.Component <> nil) then
  begin
    DesignerForm := FormEditor1.GetDesignerForm(AUnitInfo.Component);
    if DesignerForm <> nil then
      AUnitInfo.ComponentState := GetWindowState(DesignerForm);
  end;
end;

procedure TMainIDE.OnLoadProjectInfoFromXMLConfig(TheProject: TProject;
  XMLConfig: TXMLConfig; Merge: boolean);
begin
  if TheProject=Project1 then
    DebugBoss.LoadProjectSpecificInfo(XMLConfig,Merge);

  if (TheProject=Project1) then
    EditorMacroListViewer.LoadProjectSpecificInfo(XMLConfig, Merge);
end;

procedure TMainIDE.OnSaveProjectInfoToXMLConfig(TheProject: TProject;
  XMLConfig: TXMLConfig; WriteFlags: TProjectWriteFlags);
begin
  if (TheProject=Project1) and (not (pwfSkipDebuggerSettings in WriteFlags)) then
    DebugBoss.SaveProjectSpecificInfo(XMLConfig,WriteFlags);

  if (TheProject=Project1) then
    EditorMacroListViewer.SaveProjectSpecificInfo(XMLConfig, WriteFlags);
end;

procedure TMainIDE.OnProjectGetTestDirectory(TheProject: TProject; out TestDir: string);
begin
  TestDir:=GetTestBuildDirectory;
end;

procedure TMainIDE.OnProjectChangeInfoFile(TheProject: TProject);
begin
  if (Project1=nil) or (TheProject<>Project1) then exit;
  if Project1.IsVirtual then
    CodeToolBoss.SetGlobalValue(ExternalMacroStart+'ProjPath',VirtualDirectory)
  else
    CodeToolBoss.SetGlobalValue(ExternalMacroStart+'ProjPath',Project1.ProjectDirectory)
end;

function TMainIDE.DoNewFile(NewFileDescriptor: TProjectFileDescriptor;
  var NewFilename: string; NewSource: string;
  NewFlags: TNewFlags; NewOwner: TObject): TModalResult;
begin
  Result := SourceFileMgr.NewFile(NewFileDescriptor, NewFilename, NewSource,
                                  NewFlags, NewOwner);
end;

procedure TMainIDE.CreateFileDialogFilterForSourceEditorFiles(Filter: string;
  out AllEditorMask, AllMask: string);
begin
  SourceFileMgr.CreateFileDialogFilterForSourceEditorFiles(Filter, AllEditorMask, AllMask);
end;

function TMainIDE.DoSaveEditorFile(AEditor: TSourceEditorInterface; Flags: TSaveFlags): TModalResult;
begin
  Result:=SourceFileMgr.SaveEditorFile(AEditor, Flags);
end;

function TMainIDE.DoSaveEditorFile(const Filename: string; Flags: TSaveFlags): TModalResult;
begin
  Result:=SourceFileMgr.SaveEditorFile(Filename, Flags);
end;

function TMainIDE.DoCloseEditorFile(const Filename: string; Flags: TCloseFlags): TModalResult;
begin
  Result:=SourceFileMgr.CloseEditorFile(Filename, Flags);
end;

function TMainIDE.DoCloseEditorFile(AEditor: TSourceEditorInterface;
  Flags: TCloseFlags): TModalResult;
begin
  Result:=SourceFileMgr.CloseEditorFile(AEditor, Flags);
end;

function TMainIDE.DoSaveAll(Flags: TSaveFlags): TModalResult;
var
  CurResult: TModalResult;
begin
  Result:=mrOk;
  CurResult:=DoCallModalFunctionHandler(lihtSavingAll);
  if CurResult=mrAbort then begin
    if ConsoleVerbosity>0 then
      debugln(['TMainIDE.DoSaveAll DoCallModalFunctionHandler(lihtSavingAll) failed']);
    exit(mrAbort);
  end;
  if CurResult<>mrOk then Result:=mrCancel;
  CurResult:=DoSaveProject(Flags);
  if CurResult<>mrOK then begin
    if ConsoleVerbosity>0 then
      debugln(['TMainIDE.DoSaveAll DoSaveProject failed']);
  end;
  SaveEnvironment(true);
  SaveIncludeLinks;
  PkgBoss.SaveSettings;
  InputHistories.Save;
  if CurResult=mrAbort then exit(mrAbort);
  if CurResult<>mrOk then Result:=mrCancel;
  CurResult:=DoCallModalFunctionHandler(lihtSavedAll);
  if CurResult<>mrOK then begin
    if ConsoleVerbosity>0 then
      debugln(['TMainIDE.DoSaveAll DoCallModalFunctionHandler(lihtSavedAll) failed']);
  end;
  if CurResult=mrAbort then
    Result:=mrAbort
  else if CurResult<>mrOk then
    Result:=mrCancel;
  UpdateSaveMenuItemsAndButtons(true);
end;

function TMainIDE.DoOpenEditorFile(AFileName: string; PageIndex, WindowIndex: integer;
  Flags: TOpenFlags): TModalResult;
begin
  Result := DoOpenEditorFile(AFileName, PageIndex, WindowIndex, nil, Flags);
end;

function TMainIDE.DoOpenEditorFile(AFileName: string; PageIndex, WindowIndex: integer;
  AEditorInfo: TUnitEditorInfo; Flags: TOpenFlags): TModalResult;
begin
  Result:=OpenEditorFile(AFileName, PageIndex, WindowIndex, AEditorInfo, Flags);
end;

procedure TMainIDE.DoDropFiles(Sender: TObject;
  const FileNames: array of String; WindowIndex: integer);
var
  OpenFlags: TOpenFlags;
  I: Integer;
  AFilename: String;
begin
  //debugln(['TMainIDE.DoDropFiles ',length(Filenames)]);
  if Length(FileNames) = 0 then exit;
  OpenFlags := [ofAddToRecent];
  if Length(FileNames) > 1 then
    OpenFlags := OpenFlags + [ofRegularFile,ofMultiOpen];
  SourceEditorManager.IncUpdateLock;
  try
    for I := 0 to High(FileNames) do
    begin
      AFilename := CleanAndExpandFilename(FileNames[I]);
      if LazarusIDE.DoOpenEditorFile(AFilename, -1, WindowIndex, OpenFlags) = mrAbort then
        Break;
    end;
  finally
    SourceEditorManager.DecUpdateLock;
  end;
  SetRecentFilesMenu;
end;

function TMainIDE.DoSelectFrame: TComponentClass;
var
  UnitList: TStringList;
  dummy: Boolean;
  i: Integer;
  aFilename: String;
  AComponent: TComponent;
begin
  Result := nil;
  UnitList := TStringList.Create;
  try
    dummy := false;
    if SourceFileMgr.SelectUnitComponents('Select Frame',piFrame,UnitList, false, dummy) <> mrOk
    then
      exit;
    for i := 0 to UnitList.Count-1 do
    begin
      aFilename:=UnitList[i];
      if not FileExistsUTF8(aFilename) then continue;
      debugln(['TMainIDE.DoSelectFrame Filename="',aFilename,'"']);
      if DoOpenComponent(aFilename,
        [ofOnlyIfExists,ofLoadHiddenResource,ofUseCache],[],AComponent)<>mrOk
      then exit;
      debugln(['TMainIDE.DoSelectFrame AncestorComponent=',DbgSName(AComponent)]);
      Result := TComponentClass(AComponent.ClassType);
      exit;
    end;
  finally
    UnitList.Free;
  end;
end;

function TMainIDE.DoViewUnitsAndForms(OnlyForms: boolean): TModalResult;
const
  UseItemType: array[Boolean] of TIDEProjectItem = (piUnit, piComponent);
  MultiSelectCheckedState: Array [Boolean] of Boolean = (True,True);
var
  UnitList: TViewUnitEntries;
  AForm: TCustomForm;
  AnUnitInfo: TUnitInfo;
  UEntry: TViewUnitsEntry;
begin
  if Project1=nil then exit(mrCancel);
  UnitList := TViewUnitEntries.Create;
  try
    if SourceFileMgr.SelectProjectItems(UnitList, UseItemType[OnlyForms],
      true, MultiSelectCheckedState[OnlyForms]) = mrOk then
    begin
      { This is where we check what the user selected. }
      AnUnitInfo := nil;
      for UEntry in UnitList do
      begin
        if not UEntry.Selected then continue;
        AnUnitInfo := Project1.Units[UEntry.ID];
        if AnUnitInfo.OpenEditorInfoCount > 0 then
        begin
          SourceEditorManager.ActiveEditor :=
            TSourceEditor(AnUnitInfo.OpenEditorInfo[0].EditorComponent);
        end else
        begin
          if Project1.MainUnitInfo = AnUnitInfo then
            Result:=OpenMainUnit(-1,-1,[])
          else
            Result:=DoOpenEditorFile(AnUnitInfo.Filename,-1,-1,[ofOnlyIfExists]);
          if Result=mrAbort then exit;
        end;
        if OnlyForms and (AnUnitInfo.ComponentName<>'') then
        begin
          AForm := GetDesignerFormOfSource(AnUnitInfo,true);
          if AForm <> nil then
            ShowDesignerForm(AForm);
        end;
      end;  { for }
      if (AnUnitInfo <> nil) and (not OnlyForms) then
        SourceEditorManager.ShowActiveWindowOnTop(True);
    end;  { if ShowViewUnitDlg... }
  finally
    UnitList.Free;
  end;
  Result := mrOk;
end;

procedure TMainIDE.DoViewUnitInfo;
var ActiveSrcEdit:TSourceEditor;
  ActiveUnitInfo:TUnitInfo;
  ShortUnitName, AFilename, FileDir: string;
  ClearIncludedByFile: boolean;
  DlgResult: TModalResult;
  SizeInBytes: Integer;
  UnitSizeWithIncludeFiles: integer;
  UnitSizeParsed: integer;
  LineCount: LongInt;
  UnitLineCountWithIncludes: LongInt;
  UnitLineCountParsed: LongInt;
  Code: TCodeBuffer;
  CTTool: TCodeTool;
  TreeOfSourceCodes: TAVLTree;
  Node: TAVLTreeNode;
  SubCode: TCodeBuffer;
begin
  GetCurrentUnit(ActiveSrcEdit,ActiveUnitInfo);
  if (ActiveSrcEdit=nil) or (ActiveUnitInfo=nil) then exit;
  ShortUnitName:=ActiveSrcEdit.PageName;
  AFilename:=ActiveUnitInfo.Filename;
  FileDir:=ExtractFilePath(AFilename);

  SizeInBytes:=length(ActiveSrcEdit.Source.Text);
  UnitSizeWithIncludeFiles:=SizeInBytes;
  UnitSizeParsed:=SizeInBytes;
  LineCount:=ActiveSrcEdit.Source.Count;
  UnitLineCountWithIncludes:=LineCount;
  UnitLineCountParsed:=LineCount;

  // check size of parsed source (without skipped code due to $ELSE)
  // and total size of all include files
  Code:=ActiveSrcEdit.CodeBuffer;
  if Code<>nil then
  begin
    CodeToolBoss.Explore(ActiveSrcEdit.CodeBuffer,CTTool,false,false);
    if CTTool<>nil then
    begin
      UnitSizeParsed:=CTTool.SrcLen;
      UnitLineCountParsed:=LineEndCount(CTTool.Src);
      if CTTool.Scanner<>nil then
      begin
        TreeOfSourceCodes:=CTTool.Scanner.CreateTreeOfSourceCodes;
        if TreeOfSourceCodes<>nil then
        begin
          UnitSizeWithIncludeFiles:=0;
          UnitLineCountWithIncludes:=0;
          Node:=TreeOfSourceCodes.FindLowest;
          while Node<>nil do begin
            SubCode:=TCodeBuffer(Node.Data);
            inc(UnitSizeWithIncludeFiles,SubCode.SourceLength);
            inc(UnitLineCountWithIncludes,SubCode.LineCount);
            Node:=TreeOfSourceCodes.FindSuccessor(Node);
          end;
          TreeOfSourceCodes.Free;
        end;
      end;
    end;
  end;

  DlgResult:=ShowUnitInfoDlg(ShortUnitName,
    GetSyntaxHighlighterCaption(ActiveUnitInfo.DefaultSyntaxHighlighter),
    ActiveUnitInfo.IsPartOfProject,
    SizeInBytes,UnitSizeWithIncludeFiles,UnitSizeParsed,
    LineCount,UnitLineCountWithIncludes,UnitLineCountParsed,
    AFilename,
    ActiveUnitInfo.Source.LastIncludedByFile,
    ClearIncludedByFile,
    TrimSearchPath(CodeToolBoss.GetUnitPathForDirectory(FileDir),FileDir),
    TrimSearchPath(CodeToolBoss.GetIncludePathForDirectory(FileDir),FileDir),
    TrimSearchPath(CodeToolBoss.GetCompleteSrcPathForDirectory(FileDir),FileDir)
    );
  if ClearIncludedByFile then
    ActiveUnitInfo.Source.LastIncludedByFile:='';
  if (DlgResult=mrYes) and (ActiveUnitInfo.Source.LastIncludedByFile<>'') then
    DoGotoIncludeDirective;
end;

procedure TMainIDE.DoShowCodeExplorer(State: TIWGetFormState);
begin
  if CodeExplorerView=nil then
  begin
    IDEWindowCreators.CreateForm(CodeExplorerView,TCodeExplorerView,
       State=iwgfDisabled,OwningComponent);
    CodeExplorerView.OnGetDirectivesTree:=@OnCodeExplorerGetDirectivesTree;
    CodeExplorerView.OnJumpToCode:=@OnCodeExplorerJumpToCode;
    CodeExplorerView.OnShowOptions:=@OnCodeExplorerShowOptions;
  end else if State=iwgfDisabled then
    CodeExplorerView.DisableAutoSizing;

  if State>=iwgfShow then begin
    IDEWindowCreators.ShowForm(CodeExplorerView,State=iwgfShowOnTop);
    CodeExplorerView.Refresh(true);
  end;
end;

procedure TMainIDE.DoShowCodeBrowser(State: TIWGetFormState);
begin
  CreateCodeBrowser(State=iwgfDisabled);
  if State>=iwgfShow then
    IDEWindowCreators.ShowForm(CodeBrowserView,State=iwgfShowOnTop);
end;

procedure TMainIDE.DoShowRestrictionBrowser(const RestrictedName: String;
  State: TIWGetFormState);
begin
  if RestrictionBrowserView = nil then
    IDEWindowCreators.CreateForm(RestrictionBrowserView,TRestrictionBrowserView,
      State=iwgfDisabled,OwningComponent)
  else if State=iwgfDisabled then
    RestrictionBrowserView.DisableAutoSizing;

  RestrictionBrowserView.SetIssueName(RestrictedName);
  if State>=iwgfShow then
    IDEWindowCreators.ShowForm(RestrictionBrowserView,State=iwgfShowOnTop);
end;

procedure TMainIDE.DoShowComponentList(State: TIWGetFormState);
begin
  if ComponentListForm = nil then
  begin
    IDEWindowCreators.CreateForm(ComponentListForm,TComponentListForm,
       State=iwgfDisabled,OwningComponent);
    ComponentListForm.Name:=NonModalIDEWindowNames[nmiwComponentList];
  end else if State=iwgfDisabled then
    ComponentListForm.DisableAutoSizing;
  if State>=iwgfShow then
    IDEWindowCreators.ShowForm(ComponentListForm,State=iwgfShowOnTop);
end;

procedure TMainIDE.DoShowJumpHistory(State: TIWGetFormState);
begin
  if JumpHistoryViewWin=nil then begin
    IDEWindowCreators.CreateForm(JumpHistoryViewWin,TJumpHistoryViewWin,
      State=iwgfDisabled,OwningComponent);
    JumpHistoryViewWin.OnSelectionChanged := @JumpHistoryViewSelectionChanged;
  end else if State=iwgfDisabled then
    JumpHistoryViewWin.DisableAutoSizing;
  if State>=iwgfShow then
    IDEWindowCreators.ShowForm(JumpHistoryViewWin,State=iwgfShowOnTop);
end;

procedure TMainIDE.DoShowInspector(State: TIWGetFormState);
begin
  CreateObjectInspector(State=iwgfDisabled);
  if State>=iwgfShow then begin
    IDEWindowCreators.ShowForm(ObjectInspector1,State=iwgfShowOnTop);
    if ObjectInspector1.IsVisible then
    begin
      ObjectInspector1.FocusGrid;
      {$IFDEF VerboseIDEDisplayState}
      debugln(['TMainIDE.DoShowInspector old=',dbgs(DisplayState)]);
      {$ENDIF}
      case DisplayState of
      dsSource: DisplayState:=dsInspector;
      dsForm: DisplayState:=dsInspector2;
      end;
    end;
  end;
end;

procedure TMainIDE.CreateIDEWindow(Sender: TObject; aFormName: string; var
  AForm: TCustomForm; DoDisableAutoSizing: boolean);

  function ItIs(Prefix: string): boolean;
  begin
    Result:=SysUtils.CompareText(copy(aFormName,1,length(Prefix)),Prefix)=0;
  end;

var
  State: TIWGetFormState;
begin
  if DoDisableAutoSizing then
    State:=iwgfDisabled
  else
    State:=iwgfEnabled;
  if ItIs(NonModalIDEWindowNames[nmiwMessagesViewName]) then
    AForm:=MessagesView
  else if ItIs(NonModalIDEWindowNames[nmiwUnitDependenciesName]) then
  begin
    ShowUnitDependencies(State);
    AForm:=UnitDependenciesWindow;
  end
  else if ItIs(NonModalIDEWindowNames[nmiwCodeExplorerName]) then
  begin
    DoShowCodeExplorer(State);
    AForm:=CodeExplorerView;
  end
  else if ItIs(NonModalIDEWindowNames[nmiwFPDocEditorName]) then
  begin
    DoShowFPDocEditor(State);
    AForm:=FPDocEditor;
  end
  // ToDo: nmiwClipbrdHistoryName:
  else if ItIs(NonModalIDEWindowNames[nmiwProjectInspector]) then
  begin
    DoShowProjectInspector(State);
    AForm:=ProjInspector;
  end
  else if ItIs(NonModalIDEWindowNames[nmiwSearchResultsViewName]) then
  begin
    DoShowSearchResultsView(State);
    AForm:=SearchResultsView;
  end
  else if ItIs(NonModalIDEWindowNames[nmiwAnchorEditor]) then
  begin
    DoViewAnchorEditor(State);
    AForm:=AnchorDesigner;
  end
  else if ItIs(NonModalIDEWindowNames[nmiwTabOrderEditor]) then
  begin
    DoViewTabOrderEditor(State);
    AForm:=TabOrderDialog;
  end
  else if ItIs(NonModalIDEWindowNames[nmiwCodeBrowser]) then
  begin
    DoShowCodeBrowser(State);
    AForm:=CodeBrowserView;
  end
  else if ItIs(NonModalIDEWindowNames[nmiwIssueBrowser]) then
  begin
    DoShowRestrictionBrowser('',State);
    AForm:=RestrictionBrowserView;
  end
  else if ItIs(NonModalIDEWindowNames[nmiwJumpHistory]) then
  begin
    DoShowJumpHistory(State);
    AForm:=JumpHistoryViewWin;
  end
  else if ItIs(NonModalIDEWindowNames[nmiwComponentList]) then
  begin
    DoShowComponentList(State);
    AForm:=ComponentListForm;
  end
  else if ItIs(NonModalIDEWindowNames[nmiwEditorFileManager]) then
  begin
    ShowEditorFileManagerForm(State);
    AForm:=EditorFileManagerForm;
  end
  else if ItIs(DefaultObjectInspectorName) then
  begin
    DoShowInspector(State);
    AForm:=ObjectInspector1;
  end;
end;

function TMainIDE.CreateNewUniqueFilename(const Prefix, Ext: string;
  NewOwner: TObject; Flags: TSearchIDEFileFlags; TryWithoutNumber: boolean): string;

  function FileIsUnique(const ShortFilename: string): boolean;
  begin
    Result:=false;

    // search in NewOwner
    if NewOwner<>nil then begin
      if (NewOwner is TProject) then begin
        if TProject(NewOwner).SearchFile(ShortFilename,Flags)<>nil then exit;
      end;
    end;

    // search in all packages
    if PkgBoss.SearchFile(ShortFilename,Flags,NewOwner)<>nil then exit;

    // search in current project
    if (NewOwner<>Project1)
    and (Project1.SearchFile(ShortFilename,Flags)<>nil) then exit;

    // search file in all loaded projects
    if (siffCheckAllProjects in Flags) then begin
    end;

    Result:=true;
  end;

var
  i: Integer;
  WorkingPrefix: String;
begin
  if TryWithoutNumber then begin
    Result:=Prefix+Ext;
    if FileIsUnique(Result) then exit;
  end;
  // remove number at end of Prefix
  WorkingPrefix:=ChompEndNumber(Prefix);
  i:=0;
  repeat
    inc(i);
    Result:=WorkingPrefix+IntToStr(i)+Ext;
  until FileIsUnique(Result);
end;

procedure TMainIDE.MarkUnitsModifiedUsingSubComponent(SubComponent: TComponent);
var
  UnitList: TFPList;
  i: Integer;
  AnUnitInfo: TUnitInfo;
  ADesigner: TDesigner;
begin
  UnitList:=TFPList.Create;
  Project1.FindUnitsUsingSubComponent(SubComponent,UnitList,true);
  for i:=0 to UnitList.Count-1 do begin
    AnUnitInfo:=TUnitInfo(UnitList[i]);
    if (AnUnitInfo.Component<>nil) then begin
      ADesigner:=TDesigner(FindRootDesigner(AnUnitInfo.Component));
      {$IFDEF VerboseIDEMultiForm}
      DebugLn(['TMainIDE.MarkUnitsModifiedUsingSubComponent ',AnUnitInfo.Filename,' ',dbgsName(ADesigner)]);
      {$ENDIF}
      if ADesigner is TDesigner then
        ADesigner.Modified;
    end;
  end;
  UnitList.Free;
end;

function TMainIDE.DoOpenFileAndJumpToIdentifier(const AFilename,
  AnIdentifier: string; PageIndex, WindowIndex: integer; Flags: TOpenFlags): TModalResult;
var
  ActiveUnitInfo: TUnitInfo;
  ActiveSrcEdit: TSourceEditor;
  NewSource: TCodeBuffer;
  NewX, NewY, NewTopLine: integer;
begin
  Result:=DoOpenEditorFile(AFilename, PageIndex, WindowIndex, Flags);
  if Result<>mrOk then exit;
  Result:=mrCancel;
  ActiveSrcEdit:=nil;
  if not BeginCodeTool(ActiveSrcEdit,ActiveUnitInfo,[]) then exit;
  if CodeToolBoss.FindDeclarationInInterface(ActiveUnitInfo.Source,
    AnIdentifier,NewSource, NewX, NewY, NewTopLine)
  then begin
    DoJumpToCodePosition(ActiveSrcEdit, ActiveUnitInfo,
                    NewSource, NewX, NewY, NewTopLine, [jfAddJumpPoint, jfFocusEditor]);
    Result:=mrOk;
  end else
    DoJumpToCodeToolBossError;
end;

function TMainIDE.DoOpenFileAndJumpToPos(const AFilename: string;
  const CursorPosition: TPoint; TopLine: integer; PageIndex,
  WindowIndex: integer; Flags: TOpenFlags): TModalResult;
var
  ActiveUnitInfo, OldActiveUnitInfo: TUnitInfo;
  ActiveSrcEdit, OldActiveSrcEdit: TSourceEditor;
begin
  GetCurrentUnit(OldActiveSrcEdit,OldActiveUnitInfo);
  Result:=DoOpenEditorFile(AFilename, PageIndex, WindowIndex, Flags);
  if Result<>mrOk then exit;
  GetCurrentUnit(ActiveSrcEdit,ActiveUnitInfo);
  if ActiveUnitInfo<>nil then begin
    DoJumpToCodePosition(OldActiveSrcEdit, OldActiveUnitInfo,
                    ActiveUnitInfo.Source,
                    CursorPosition.X, CursorPosition.Y, TopLine, [jfAddJumpPoint, jfFocusEditor]);
    Result:=mrOk;
  end else begin
    Result:=mrCancel;
  end;
end;

function TMainIDE.DoRevertEditorFile(const Filename: string): TModalResult;
var
  AnUnitInfo: TUnitInfo;
begin
  Result:=mrCancel;
  if (Project1=nil) then exit;
  AnUnitInfo:=Project1.UnitInfoWithFilename(Filename,[]);
  if (AnUnitInfo<>nil) and (AnUnitInfo.OpenEditorInfoCount > 0) then
    Result:=OpenEditorFile(AnUnitInfo.Filename,
                           AnUnitInfo.OpenEditorInfo[0].PageIndex,
                           AnUnitInfo.OpenEditorInfo[0].WindowID,
                           nil,[ofRevert],True); // Reverting one will revert all
end;

function TMainIDE.CreateProjectObject(ProjectDesc,
  FallbackProjectDesc: TProjectDescriptor): TProject;
begin
  Result:=TProject.Create(ProjectDesc);
  // custom initialization
  Result.BeginUpdate(true);
  if ProjectDesc.InitProject(Result)<>mrOk then begin
    Result.EndUpdate;
    Result.Free;
    Result:=nil;
    if FallbackProjectDesc=nil then exit;
    Result:=TProject.Create(FallbackProjectDesc);
    FallbackProjectDesc.InitProject(Result);
  end
  else
    Result.EndUpdate;

  Result.MainProject:=true;
  Result.OnFileBackup:=@MainBuildBoss.BackupFile;
  Result.OnLoadProjectInfo:=@OnLoadProjectInfoFromXMLConfig;
  Result.OnSaveProjectInfo:=@OnSaveProjectInfoToXMLConfig;
  Result.OnSaveUnitSessionInfo:=@OnSaveProjectUnitSessionInfo;
  Result.OnGetTestDirectory:=@OnProjectGetTestDirectory;
  Result.OnChangeProjectInfoFile:=@OnProjectChangeInfoFile;
  Result.IDEOptions.OnBeforeRead:=@DoProjectOptionsBeforeRead;
  Result.IDEOptions.OnAfterWrite:=@DoProjectOptionsAfterWrite;
end;

function TMainIDE.DoNewProject(ProjectDesc: TProjectDescriptor): TModalResult;
begin
  //DebugLn('TMainIDE.DoNewProject A');
  // init the descriptor (it can now ask the user for options)
  Result:=ProjectDesc.InitDescriptor;
  if Result<>mrOk then exit;

  // close current project first
  if Project1<>nil then begin
    if not DoResetToolStatus([rfInteractive, rfSuccessOnTrigger]) then exit;
    if SourceFileMgr.AskSaveProject(lisDoYouStillWantToCreateTheNewProject,
      lisDiscardChangesCreateNewProject)<>mrOK then exit;
    Result:=DoCloseProject;
    if Result=mrAbort then exit;
  end;
  // create a virtual project (i.e. unsaved and without real project directory)
  // invalidate cached substituted macros
  IncreaseCompilerParseStamp;

  // switch codetools to virtual project directory
  CodeToolBoss.SetGlobalValue(
    ExternalMacroStart+'ProjPath',VirtualDirectory);
  EnvironmentOptions.LastSavedProjectFile:='';

  // create new project
  Project1:=CreateProjectObject(ProjectDesc,ProjectDescriptorProgram);
  Result:=SourceFileMgr.InitNewProject(ProjectDesc);
end;

function TMainIDE.DoSaveProject(Flags: TSaveFlags):TModalResult;
begin
  Result:=SourceFileMgr.SaveProject(Flags);
end;

function TMainIDE.DoCloseProject: TModalResult;
begin
  Result:=SourceFileMgr.CloseProject;
end;

procedure TMainIDE.DoNoProjectWizard(Sender: TObject);
var
  ARecentProject: String;
begin
  while (Project1 = nil) do
  begin
    case ShowProjectWizardDlg(ARecentProject) of
    tpws_new:
      mnuNewProjectClicked(Sender);
    tpws_open:
      mnuOpenProjectClicked(Sender);
    tpws_openRecent:
      begin
        ARecentProject := ExpandFileNameUTF8(ARecentProject);
        if DoOpenProjectFile(ARecentProject, [ofAddToRecent]) <> mrOk then
        begin
          // open failed
          if not FileExistsUTF8(ARecentProject) then
            EnvironmentOptions.RemoveFromRecentProjectFiles(ARecentProject)
          else
            SourceFileMgr.AddRecentProjectFileToEnvironment(ARecentProject);
        end;
      end;
    tpws_examples:
      mnuToolManageExamplesClicked(Sender);
    tpws_convert:
      mnuToolConvertDelphiProjectClicked(Sender);
    tpws_closeIDE:
      if QuitIDE then exit;
    end;
  end;
end;

function TMainIDE.DoOpenProjectFile(AFileName: string; Flags: TOpenFlags): TModalResult;
var
  Ext,AText,ACaption: string;
  DiskFilename: String;
  FileReadable: Boolean;
begin
  Result:=mrCancel;

  //debugln('TMainIDE.DoOpenProjectFile A "'+AFileName+'"');
  {$IFDEF IDE_MEM_CHECK}CheckHeapWrtMemCnt('TMainIDE.DoOpenProjectFile A');{$ENDIF}
  if ExtractFileNameOnly(AFileName)='' then exit;
  //debugln('TMainIDE.DoOpenProjectFile A1 "'+AFileName+'"');
  AFilename:=ExpandFileNameUTF8(TrimFilename(AFilename));
  //debugln('TMainIDE.DoOpenProjectFile A2 "'+AFileName+'"');
  if not FilenameIsAbsolute(AFilename) then
    RaiseException('TMainIDE.DoOpenProjectFile: buggy ExpandFileNameUTF8');
  AFilename:=GetPhysicalFilenameCached(AFilename,false);

  // check if it is a directory
  if DirPathExistsCached(AFileName) then begin
    debugln(['TMainIDE.DoOpenProjectFile file is a directory']);
    exit;
  end;

  // check if file exists
  if not FileExistsCached(AFilename) then begin
    ACaption:=lisFileNotFound;
    AText:=Format(lisPkgMangFileNotFound, [AFilename]);
    Result:=IDEMessageDialog(ACaption, AText, mtError, [mbAbort]);
    exit;
  end;

  DiskFilename:=CodeToolBoss.DirectoryCachePool.FindDiskFilename(AFilename);
  if DiskFilename<>AFilename then begin
    // the case is different
    DebugLn(['TMainIDE.DoOpenProjectFile Fixing file name: ',AFilename,' -> ',DiskFilename]);
    AFilename:=DiskFilename;
  end;

  Ext:=lowercase(ExtractFileExt(AFilename));
  // if there is a project info file, load that instead
  if (Ext<>'.lpi') and (FileExistsUTF8(ChangeFileExt(AFileName,'.lpi'))) then
  begin
    // load instead of program file the project info file
    AFileName:=ChangeFileExt(AFileName,'.lpi');
    Ext:='.lpi';
  end;

  if (not FileUtil.FileIsText(AFilename,FileReadable)) and FileReadable then
  begin
    ACaption:=lisFileNotText;
    AText:=Format(lisFileDoesNotLookLikeATextFileOpenItAnyway,[AFilename,LineEnding,LineEnding]);
    Result:=IDEMessageDialog(ACaption, AText, mtConfirmation, [mbYes, mbAbort]);
    if Result=mrAbort then exit;
  end;
  if not FileReadable then begin
    Result:=IDEQuestionDialog(lisUnableToReadFile,
      Format(lisUnableToReadFile2, [AFilename]),
      mtError, [mrCancel, lisSkipFile, mrAbort, lisAbortAllLoading]);
    exit;
  end;

  if ofAddToRecent in Flags then
    SourceFileMgr.AddRecentProjectFileToEnvironment(AFileName);

  if not DoResetToolStatus([rfInteractive, rfSuccessOnTrigger]) then exit;

  // save old project
  if SourceFileMgr.AskSaveProject(lisDoYouStillWantToOpenAnotherProject,
    lisDiscardChangesAndOpenProject)<>mrOk then exit;

  Result:=DoCloseProject;
  if Result=mrAbort then exit;

  // create a new project
  //debugln('TMainIDE.DoOpenProjectFile B');
  {$IFDEF IDE_MEM_CHECK}CheckHeapWrtMemCnt('TMainIDE.DoOpenProjectFile B');{$ENDIF}
  Project1:=CreateProjectObject(ProjectDescriptorProgram,
                                ProjectDescriptorProgram);
  Result:=SourceFileMgr.InitOpenedProjectFile(AFileName, Flags);
end;

function TMainIDE.DoPublishProject(Flags: TSaveFlags; ShowDialog: boolean): TModalResult;
begin
  if Project1=nil then exit(mrCancel);

  // show the publish project dialog
  if ShowDialog then begin
    Result:=ShowPublishProjectDialog(Project1.PublishOptions);
    Project1.Modified:=Project1.PublishOptions.Modified;
    if Result<>mrOk then exit;
    IncreaseCompilerParseStamp;
  end;

  //debugln('TMainIDE.DoPublishProject A');
  // save project
  Result:=DoSaveProject(Flags);
  if Result<>mrOk then exit;

  // publish project
  //debugln('TMainIDE.DoPublishProject B');
  Result:=SourceFileMgr.PublishModule(Project1.PublishOptions,
    Project1.ProjectDirectory, MainBuildBoss.GetProjectPublishDir);
end;

procedure TMainIDE.DoShowProjectInspector(State: TIWGetFormState);
begin
  if ProjInspector=nil then begin
    IDEWindowCreators.CreateForm(ProjInspector,TProjectInspectorForm,
       State=iwgfDisabled,LazarusIDE.OwningComponent);
    ProjInspector.OnShowOptions:=@mnuProjectOptionsClicked;
    ProjInspector.OnAddUnitToProject:=@ProjInspectorAddUnitToProject;
    ProjInspector.OnAddDependency:=@PkgBoss.OnProjectInspectorAddDependency;
    ProjInspector.OnRemoveFile:=@ProjInspectorRemoveFile;
    ProjInspector.OnRemoveDependency:=@PkgBoss.OnProjectInspectorRemoveDependency;
    ProjInspector.OnReAddDependency:=@PkgBoss.OnProjectInspectorReAddDependency;
    ProjInspector.OnDragOverTreeView:=@PkgBoss.OnProjectInspectorDragOverTreeView;
    ProjInspector.OnDragDropTreeView:=@PkgBoss.OnProjectInspectorDragDropTreeView;
    ProjInspector.OnCopyMoveFiles:=@PkgBoss.OnProjectInspectorCopyMoveFiles;

    ProjInspector.LazProject:=Project1;
  end else if STate=iwgfDisabled then
    ProjInspector.DisableAlign;

  if State>=iwgfShow then
    IDEWindowCreators.ShowForm(ProjInspector,State=iwgfShowOnTop);
end;

function TMainIDE.DoAddActiveUnitToProject: TModalResult;
begin
  Result:=SourceFileMgr.AddActiveUnitToProject;
end;

function TMainIDE.DoRemoveFromProjectDialog: TModalResult;
Begin
  Result:=SourceFileMgr.RemoveFromProjectDialog;
end;

function TMainIDE.DoWarnAmbiguousFiles: TModalResult;
var
  AnUnitInfo: TUnitInfo;
  i: integer;
  DestFilename: string;
begin
  for i:=0 to Project1.UnitCount-1 do begin
    AnUnitInfo:=Project1.Units[i];
    if (AnUnitInfo.IsPartOfProject) and (not AnUnitInfo.IsVirtual) then begin
      DestFilename:=MainBuildBoss.GetTargetUnitFilename(AnUnitInfo);
      Result:=MainBuildBoss.CheckAmbiguousSources(DestFilename,true);
      if Result<>mrOk then exit;
    end;
  end;
  Result:=mrOk;
end;

function TMainIDE.DoSaveForBuild(AReason: TCompileReason): TModalResult;
begin
  if Project1=nil then exit(mrOk);

  Result:=mrCancel;
  if not (ToolStatus in [itNone,itDebugger,itBuilder]) then begin
    if ConsoleVerbosity>0 then
      DebugLn('TMainIDE.DoSaveForBuild ToolStatus forbids it: ',dbgs(ToolStatus));
    Result:=mrAbort;
    exit;
  end;
  if Project1=nil then Begin
    IDEMessageDialog(lisCCOErrorCaption, lisCreateAProjectFirst, mtError, [mbOK]);
    Exit;
  end;

  // save all files
  if not Project1.IsVirtual then
    Result:=DoSaveAll([sfCheckAmbiguousFiles])
  else
    Result:=DoSaveProjectToTestDirectory([sfSaveNonProjectFiles]);
  Project1.ProjResources.DoBeforeBuild(AReason, Project1.IsVirtual);
  Project1.UpdateExecutableType;
  if Result<>mrOk then begin
    if ConsoleVerbosity>0 then
      DebugLn('TMainIDE.DoSaveForBuild project saving failed');
    exit;
  end;

  Result:=PkgBoss.DoSaveAllPackages([]);
  if Result<>mrOK then
    if ConsoleVerbosity>0 then
      debugln(['TMainIDE.DoSaveForBuild PkgBoss.DoSaveAllPackages failed']);

  // get non IDE disk changes
  InvalidateFileStateCache;
end;

function TMainIDE.DoSaveProjectToTestDirectory(Flags: TSaveFlags): TModalResult;
var
  TestDir: String;
begin
  Result:=mrCancel;
  TestDir:=GetTestBuildDirectory;
  if (TestDir<>'') then begin
    Result:=ForceDirectoryInteractive(TestDir,[]);
    if Result<>mrOk then exit;
  end;
  if (TestDir='')
  or (not DirPathExists(TestDir)) then begin
    if (TestDir<>'') then begin
      IDEMessageDialog(lisCCOErrorCaption,
        Format(lisTheTestDirectoryCouldNotBeFoundSeeIDEOpt,
          [LineEnding, EnvironmentOptions.TestBuildDirectory, LineEnding]),
        mtError, [mbCancel]);
      Result:=mrCancel;
      exit;
    end;
    Result:=IDEMessageDialog(lisBuildNewProject,
       Format(lisTheProjectMustBeSavedBeforeBuildingIfYouSetTheTest,
              [LineEnding, LineEnding, LineEnding]),
       mtInformation, [mbYes, mbNo]);
    if Result<>mrYes then exit;
    Result:=DoSaveAll([sfCheckAmbiguousFiles]);
    exit;
  end;
  Result:=DoSaveProject([sfSaveToTestDir,sfCheckAmbiguousFiles]+Flags);
end;

function TMainIDE.DoTestCompilerSettings(
  TheCompilerOptions: TCompilerOptions): TModalResult;
begin
  Result:=mrCancel;
  if (Project1=nil) or (ToolStatus<>itNone) then begin
    IDEMessageDialog(lisBusy,
      lisCanNotTestTheCompilerWhileDebuggingOrCompiling, mtInformation, [mbOk]);
    exit;
  end;

  // change tool status
  CheckCompilerOptsDlg:=TCheckCompilerOptsDlg.Create(nil);
  try
    CheckCompilerOptsDlg.Options:=TheCompilerOptions;
    CheckCompilerOptsDlg.MacroList:=GlobalMacroList;
    Result:=CheckCompilerOptsDlg.ShowModal;
  finally
    FreeThenNil(CheckCompilerOptsDlg);
  end;
end;

function TMainIDE.QuitIDE: boolean;
begin
  Result:=true;

  if Project1=nil then
    EnvironmentOptions.LastSavedProjectFile:=RestoreProjectClosed;
  MainIDEBar.OnCloseQuery(Self, Result);
  {$IFDEF IDE_DEBUG}
  debugln('TMainIDE.QuitIDE 1');
  {$ENDIF}
  if Result then MainIDEBar.Close;
  {$IFDEF IDE_DEBUG}
  debugln('TMainIDE.QuitIDE 2');
  {$ENDIF}
end;

function CheckCompileReasons(Reason: TCompileReason;
  Options: TProjectCompilerOptions; Quiet: boolean): TModalResult;
var
  ProjToolOpts: TProjectCompilationToolOptions;
begin
  if (Reason in Options.CompileReasons)
  and (Options.CompilerPath<>'') then
    exit(mrOk);
  if Options.ExecuteBefore is TProjectCompilationToolOptions then begin
    ProjToolOpts:=TProjectCompilationToolOptions(Options.ExecuteBefore);
    if (Reason in ProjToolOpts.CompileReasons) and (ProjToolOpts.Command<>'') then
      exit(mrOk);
  end;
  if Options.ExecuteAfter is TProjectCompilationToolOptions then begin
    ProjToolOpts:=TProjectCompilationToolOptions(Options.ExecuteAfter);
    if (Reason in ProjToolOpts.CompileReasons) and (ProjToolOpts.Command<>'') then
      exit(mrOk);
  end;
  // reason is not handled
  if Quiet then exit(mrCancel);
  Result:=IDEMessageDialog('Nothing to do',
    'The project''s compiler options has no compile command.'+LineEnding
    +'See Project / Compiler Options ... / Compilation',mtInformation,
    [mbCancel,mbIgnore]);
  if Result=mrIgnore then
    Result:=mrOk;
end;

function TMainIDE.DoBuildProject(const AReason: TCompileReason;
  Flags: TProjectBuildFlags): TModalResult;
var
  SrcFilename: string;
  ToolBefore: TProjectCompilationToolOptions;
  ToolAfter: TProjectCompilationToolOptions;
  PkgFlags: TPkgCompileFlags;
  CompilerFilename: String;
  WorkingDir: String;
  CompilerParams: String;
  NeedBuildAllFlag: Boolean;
  UnitOutputDirectory: String;
  TargetExeName: String;
  TargetExeDirectory: String;
  FPCVersion, FPCRelease, FPCPatch: integer;
  aCompileHint: String;
  OldToolStatus: TIDEToolStatus;
  IsComplete: Boolean;
  StartTime: TDateTime;
begin
  if DoAbortBuild(true)<>mrOK then begin
    debugln(['TMainIDE.DoBuildProject DoAbortBuild failed']);
    exit(mrCancel);
  end;

  Result:=SourceFileMgr.PrepareForCompileWithMsg;
  if Result<>mrOk then begin
    debugln(['TMainIDE.DoBuildProject PrepareForCompile failed']);
    exit;
  end;

  if (AReason in [crCompile,crBuild])
  and ([pbfDoNotCompileProject,pbfSkipTools]*Flags=[]) then
  begin
    // warn if nothing to do
    Result:=CheckCompileReasons(AReason,Project1.CompilerOptions,false);
    if Result<>mrOk then begin
      debugln(['TMainIDE.DoBuildProject CheckCompileReasons negative']);
      exit;
    end;
  end;

  // show messages
  IDEWindowCreators.ShowForm(MessagesView,EnvironmentOptions.MsgViewFocus);

  // clear old error lines
  SourceEditorManager.ClearErrorLines;
  SourceFileMgr.ArrangeSourceEditorAndMessageView(false);

  // check common mistakes in search paths
  Result:=PkgBoss.CheckUserSearchPaths(Project1.CompilerOptions);
  if Result<>mrOk then exit;

  try
    Result:=DoSaveForBuild(AReason);
    if Result<>mrOk then begin
      debugln(['TMainIDE.DoBuildProject DoSaveForBuild failed']);
      exit;
    end;

    if (Project1.ProjResources.ResourceType=rtRes) then begin
      // FPC resources are only supported with FPC 2.4+
      CodeToolBoss.GetFPCVersionForDirectory(
        ExtractFilePath(Project1.MainFilename),FPCVersion,FPCRelease,FPCPatch);
      if (FPCVersion=2) and (FPCRelease<4) then begin
        IDEMessageDialog(lisFPCTooOld,
          lisTheProjectUsesTheNewFPCResourcesWhichRequiresAtLea,
          mtError,[mbCancel]);
        exit(mrCancel);
      end;
    end;

    // now building can start: call handler
    Result:=DoCallModalFunctionHandler(lihtProjectBuilding);
    if Result<>mrOk then begin
      debugln(['TMainIDE.DoBuildProject handler lihtProjectBuilding negative']);
      exit;
    end;

    // get main source filename
    if not Project1.IsVirtual then begin
      WorkingDir:=Project1.ProjectDirectory;
      SrcFilename:=CreateRelativePath(Project1.MainUnitInfo.Filename,WorkingDir);
    end else begin
      WorkingDir:=GetTestBuildDirectory;
      SrcFilename:=MainBuildBoss.GetTestUnitFilename(Project1.MainUnitInfo);
    end;

    // compile required packages
    if not (pbfDoNotCompileDependencies in Flags) then begin
      Result:=DoCallModalFunctionHandler(lihtProjectDependenciesCompiling);
      if Result<>mrOk then begin
        debugln(['TMainIDE.DoBuildProject handler lihtProjectDependenciesCompiling negative']);
        exit;
      end;
      PkgFlags:=[pcfDoNotSaveEditorFiles];
      if pbfCompileDependenciesClean in Flags then
        Include(PkgFlags,pcfCompileDependenciesClean);
      Result:=PkgBoss.DoCompileProjectDependencies(Project1,PkgFlags);
      if Result <> mrOk then
      begin
        debugln(['TMainIDE.DoBuildProject PkgBoss.DoCompileProjectDependencies failed']);
        exit;
      end;
      Result:=DoCallModalFunctionHandler(lihtProjectDependenciesCompiled);
      if Result<>mrOk then begin
        debugln(['TMainIDE.DoBuildProject handler lihtProjectDependenciesCompiled negative']);
        exit;
      end;
    end;

    // warn for ambiguous files
    Result:=DoWarnAmbiguousFiles;
    if Result<>mrOk then
    begin
      debugln(['TMainIDE.DoBuildProject DoWarnAmbiguousFiles negative']);
      exit;
    end;

    // check if build is needed (only if we will call the compiler)
    // and check if a 'build all' is needed
    NeedBuildAllFlag:=false;
    aCompileHint:='';
    if (AReason in Project1.CompilerOptions.CompileReasons) then begin
      Result:=MainBuildBoss.DoCheckIfProjectNeedsCompilation(Project1,
                                                 NeedBuildAllFlag,aCompileHint);
      if  (pbfOnlyIfNeeded in Flags)
      and (not (pfAlwaysBuild in Project1.Flags)) then begin
        if Result=mrNo then begin
          debugln(['TMainIDE.DoBuildProject MainBuildBoss.DoCheckIfProjectNeedsCompilation nothing to be done']);
          Result:=mrOk;
          exit;
        end;
        if Result<>mrYes then
        begin
          debugln(['TMainIDE.DoBuildProject MainBuildBoss.DoCheckIfProjectNeedsCompilation failed']);
          exit;
        end;
      end;
    end;
    if aCompileHint<>'' then
      aCompileHint:='Compile Reason: '+aCompileHint;

    // create unit output directory
    UnitOutputDirectory:=Project1.CompilerOptions.GetUnitOutPath(false);
    if Project1.IsVirtual and (not FilenameIsAbsolute(UnitOutputDirectory)) then
      UnitOutputDirectory:=TrimFilename(WorkingDir+PathDelim+UnitOutputDirectory);
    if (FilenameIsAbsolute(UnitOutputDirectory))
    and (not DirPathExistsCached(UnitOutputDirectory)) then begin
      if not FileIsInPath(UnitOutputDirectory,WorkingDir) then begin
        Result:=IDEQuestionDialog(lisCreateDirectory,
          Format(lisTheOutputDirectoryIsMissing, [UnitOutputDirectory]),
          mtConfirmation, [mrYes, lisCreateIt, mrCancel]);
        if Result<>mrYes then exit;
      end;
      Result:=ForceDirectoryInteractive(UnitOutputDirectory,[mbRetry]);
      if Result<>mrOk then begin
        debugln(['TMainIDE.DoBuildProject ForceDirectoryInteractive "',UnitOutputDirectory,'" failed']);
        exit;
      end;
    end;

    // create target output directory
    TargetExeName := Project1.CompilerOptions.CreateTargetFilename(Project1.MainFilename);
    if Project1.IsVirtual and (not FilenameIsAbsolute(TargetExeName)) then
      TargetExeName := GetTestBuildDirectory + TargetExeName;
    TargetExeDirectory:=ExtractFilePath(TargetExeName);
    if (FilenameIsAbsolute(TargetExeDirectory))
    and (not DirPathExistsCached(TargetExeDirectory)) then begin
      if not FileIsInPath(TargetExeDirectory,WorkingDir) then begin
        Result:=IDEQuestionDialog(lisCreateDirectory,
          Format(lisTheOutputDirectoryIsMissing, [TargetExeDirectory]),
          mtConfirmation, [mrYes, lisCreateIt, mrCancel]);
        if Result<>mrYes then exit;
      end;
      Result:=ForceDirectoryInteractive(TargetExeDirectory,[mbRetry]);
      if Result<>mrOk then begin
        debugln(['TMainIDE.DoBuildProject ForceDirectoryInteractive "',TargetExeDirectory,'" failed']);
        exit;
      end;
    end;

    // create application bundle
    if Project1.UseAppBundle and (Project1.MainUnitID>=0)
    and (MainBuildBoss.GetLCLWidgetType=LCLPlatformDirNames[lpCarbon])
    then begin
      Result:=CreateApplicationBundle(TargetExeName, Project1.GetTitleOrName);
      if not (Result in [mrOk,mrIgnore]) then begin
        debugln(['TMainIDE.DoBuildProject CreateApplicationBundle "',TargetExeName,'" failed']);
        exit;
      end;
      Result:=CreateAppBundleSymbolicLink(TargetExeName);
      if not (Result in [mrOk,mrIgnore]) then begin
        debugln(['TMainIDE.DoBuildProject CreateAppBundleSymbolicLink "',TargetExeName,'" failed']);
        exit;
      end;
    end;

    // update project resource files
    if not Project1.ProjResources.Regenerate(Project1.MainFilename, False, True, TargetExeDirectory)
    then begin
      debugln(['TMainIDE.DoBuildProject ProjResources.Regenerate failed']);
      exit;
    end;

    // execute compilation tool 'Before'
    if not (pbfSkipTools in Flags) then begin
      ToolBefore:=TProjectCompilationToolOptions(
                                        Project1.CompilerOptions.ExecuteBefore);
      if (AReason in ToolBefore.CompileReasons) then begin
        Result:=Project1.CompilerOptions.ExecuteBefore.Execute(
               Project1.ProjectDirectory, lisProject2+lisExecutingCommandBefore,
               aCompileHint);
        if Result<>mrOk then
        begin
          debugln(['TMainIDE.DoBuildProject CompilerOptions.ExecuteBefore.Execute failed']);
          exit;
        end;
      end;
    end;

    if (AReason in Project1.CompilerOptions.CompileReasons)
    and (not (pbfDoNotCompileProject in Flags)) then begin
      try
        // change tool status
        //  It can still be itDebugger, if the debugger is still stopping.
        //  Prevent any "Run" command after building, until the debugger is clear.
        OldToolStatus := ToolStatus;
        ToolStatus:=itBuilder;
        // compile
        CompilerFilename:=Project1.GetCompilerFilename;
        // Hint: use absolute paths, because some external tools resolve symlinked directories
        CompilerParams :=
          Project1.CompilerOptions.MakeOptionsString(SrcFilename,[ccloAbsolutePaths])
                 + ' ' + PrepareCmdLineOption(SrcFilename);
        // write state file, to avoid building clean every time
        Result:=Project1.SaveStateFile(CompilerFilename,CompilerParams,false);
        if Result<>mrOk then begin
          debugln(['TMainIDE.DoBuildProject SaveStateFile before compile failed']);
          exit;
        end;

        StartTime:=Now;
        Result:=TheCompiler.Compile(Project1,
                                WorkingDir,CompilerFilename,CompilerParams,
                                (pbfCleanCompile in Flags) or NeedBuildAllFlag,
                                pbfSkipLinking in Flags,
                                pbfSkipAssembler in Flags,aCompileHint);
        if ConsoleVerbosity>=0 then
          debugln(['TMainIDE.DoBuildProject compiler time in s: ',(Now-StartTime)*86400]);
        if Result<>mrOk then begin
          // save state, so that next time the project is not compiled clean
          Project1.LastCompilerFilename:=CompilerFilename;
          Project1.LastCompilerParams:=CompilerParams;
          Project1.LastCompilerFileDate:=FileAgeCached(CompilerFilename);
          debugln(['TMainIDE.DoBuildProject Compile failed']);
          exit;
        end;
        // compilation succeded -> write state file
        IsComplete:=[pbfSkipLinking,pbfSkipAssembler,pbfSkipTools]*Flags=[];
        Result:=Project1.SaveStateFile(CompilerFilename,CompilerParams,IsComplete);
        if Result<>mrOk then begin
          debugln(['TMainIDE.DoBuildProject SaveStateFile after compile failed']);
          exit;
        end;

        // update project .po file
        Result:=UpdateProjectPOFile(Project1);
        if Result<>mrOk then begin
          debugln(['TMainIDE.DoBuildProject UpdateProjectPOFile failed']);
          exit;
        end;

      finally
        if OldToolStatus = itDebugger then begin
          ToolStatus := OldToolStatus;
          if DebugBoss <> nil then
            DebugBoss.UpdateToolStatus;  // Maybe "Reset Debugger was called and changed the state?
        end
        else
          ToolStatus:=itNone;
      end;
    end;

    // execute compilation tool 'After'
    if not (pbfSkipTools in Flags) then begin
      ToolAfter:=TProjectCompilationToolOptions(Project1.CompilerOptions.ExecuteAfter);
      // no need to check for mrOk, we are exit if it wasn't
      if (AReason in ToolAfter.CompileReasons) then begin
        Result:=Project1.CompilerOptions.ExecuteAfter.Execute(
                            Project1.ProjectDirectory,
                            lisProject2+lisExecutingCommandAfter,aCompileHint);
        if Result<>mrOk then
        begin
          debugln(['TMainIDE.DoBuildProject CompilerOptions.ExecuteAfter.Execute failed']);
          exit;
        end;
      end;
    end;

    Project1.ProjResources.DoAfterBuild(AReason, Project1.IsVirtual);
  finally
    // check sources
    DoCheckFilesOnDisk;
  end;
  IDEWindowCreators.ShowForm(MessagesView,EnvironmentOptions.MsgViewFocus);
  Result:=mrOk;
end;

function TMainIDE.DoAbortBuild(Interactive: boolean): TModalResult;
begin
  Result:=mrOk;
  if ExternalTools.RunningCount=0 then exit;
  // IDE code is currently running a build process
  // we cannot continue, while some IDE code is waiting for the processes
  // => exit this event (no matter if the processes are stopped or not)
  Result:=mrCancel;

  if Interactive then
  begin
    if IDEQuestionDialog(lisBuilding, lisTheIDEIsStillBuilding,
      mtConfirmation, [mrAbort, lisKMAbortBuilding, mrNo, lisContinueBuilding])
      <> mrAbort
    then
      exit;
  end;
  AbortBuild;
end;

procedure TMainIDE.DoCompile;
var
  ASrcEdit: TSourceEditor;
  AnUnitInfo: TUnitInfo;
begin
  GetCurrentUnit(ASrcEdit,AnUnitInfo);
  if Assigned(AnUnitInfo) and AnUnitInfo.BuildFileIfActive then
    DoBuildFile(false)
  else
    DoBuildProject(crCompile, []);
end;

procedure TMainIDE.DoQuickCompile;
begin
  DoBuildProject(crCompile,[pbfSkipLinking,pbfSkipTools,pbfSkipAssembler]);
end;

function TMainIDE.DoInitProjectRun: TModalResult;
var
  ProgramFilename: string;
  DebugClass: TDebuggerClass;
begin
  if ToolStatus <> itNone
  then begin
    // already running so no initialization needed
    Result := mrOk;
    Exit;
  end;

  Result := mrCancel;

  // Check if this project is runnable
  if Project1=nil then exit(mrCancel);

  if not ( ((Project1.CompilerOptions.ExecutableType=cetProgram) or
            (Project1.RunParameterOptions.HostApplicationFilename<>''))
          and (pfRunnable in Project1.Flags) and (Project1.MainUnitID >= 0) )
  then begin
    debugln(['TMainIDE.DoInitProjectRun Project can not run:',
      ' pfRunnable=',pfRunnable in Project1.Flags,
      ' MainUnitID=',Project1.MainUnitID,
      ' Launchable=',(Project1.CompilerOptions.ExecutableType=cetProgram) or
            (Project1.RunParameterOptions.HostApplicationFilename<>'')
      ]);
    Exit;
  end;

  DebugClass:=DebugBoss.DebuggerClass;

  // check if debugger supports compiler flags
  if ((DebugClass <> nil)
  and (not DebugClass.CanExternalDebugSymbolsFile))
  and (Project1.CompilerOptions.UseExternalDbgSyms) then
  begin
    // this debugger does not support external debug symbols
    if IDEQuestionDialog(lisDisableOptionXg, Format(
      lisTheProjectWritesTheDebugSymbolsToAnExternalFileThe, [DebugClass.Caption
      ]),
      mtConfirmation, [mrYes, lisDisableOptionXg2, mrCancel])<>mrYes then
        exit;
    Project1.CompilerOptions.UseExternalDbgSyms:=false;
  end;

  // Build project first
  debugln('TMainIDE.DoInitProjectRun Check build ...');
  if DoBuildProject(crRun,[pbfOnlyIfNeeded]) <> mrOk then
    Exit;

  // Check project build
  ProgramFilename := MainBuildBoss.GetProjectTargetFilename(Project1);
  DebugLn(['TMainIDE.DoInitProjectRun ProgramFilename=',ProgramFilename]);
  if ((DebugClass = nil) or DebugClass.RequiresLocalExecutable)
     and not FileExistsUTF8(ProgramFilename)
  then begin
    IDEMessageDialog(lisFileNotFound,
      Format(lisNoProgramFileSFound, [ProgramFilename]),
      mtError,[mbCancel]);
    Exit;
  end;

  // Setup debugger
  if not DebugBoss.InitDebugger then Exit;

  Result := mrOK;
  ToolStatus := itDebugger;
end;

function TMainIDE.DoRunProject: TModalResult;
begin
  DebugLn('[TMainIDE.DoRunProject] INIT');

  if (DoInitProjectRun <> mrOK)
  or (ToolStatus <> itDebugger)
  then begin
    Result := mrAbort;
    Exit;
  end;
  debugln('[TMainIDE.DoRunProject] Debugger=',EnvironmentOptions.DebuggerConfig.DebuggerClass);

  Result := mrCancel;

  Result := DebugBoss.StartDebugging;

  DebugLn('[TMainIDE.DoRunProject] END');
end;

procedure TMainIDE.DoRestart;

const
  DarwinStartlazBundlePath = 'lazarus.app/Contents/Resources/startlazarus.app/Contents/MacOS/';

  procedure StartStarter;
  var
    StartLazProcess : TProcessUTF8;
    ExeName         : string;
    Params          : TStrings;
    Dummy           : Integer;
    Unused          : boolean;
    CmdLine: string;
  begin
    StartLazProcess := TProcessUTF8.Create(nil);
    try
      StartLazProcess.InheritHandles:=false;
      // use the same working directory as the IDE, so that all relative file
      // names in parameters still work
      StartLazProcess.CurrentDirectory := ParamBaseDirectory;
      //DebugLn('Parsing commandLine: ');
      Params := TStringList.Create;
      ParseCommandLine(Params, Dummy, Unused);
      //DebugLn('Done parsing CommandLine');
      {$ifdef darwin}
      ExeName := AppendPathDelim(EnvironmentOptions.GetParsedLazarusDirectory)+
             DarwinStartlazBundlePath + 'startlazarus';
      {$else}
      ExeName := AppendPathDelim(EnvironmentOptions.GetParsedLazarusDirectory) +
        'startlazarus' + GetExecutableExt;
      {$endif}
      if not FileExistsUTF8(ExeName) then begin
        IDEMessageDialog('Error',Format(lisCannotFindLazarusStarter,
                            [LineEnding, ExeName]),mtError,[mbCancel]);
        exit;
      end;
      //DebugLn('Setting CommandLine');
      CmdLine := ExeName +
         ' --lazarus-pid='+IntToStr(GetProcessID) + ' '+
         GetCommandLineParameters(Params, False);

      DebugLn('CommandLine 1 : %s', [CmdLine]);

      if (pos(PrimaryConfPathOptLong, CmdLine) = 0) and
         (pos(PrimaryConfPathOptShort, CmdLine) = 0) then
        CmdLine := CmdLine + ' "' + PrimaryConfPathOptLong + GetPrimaryConfigPath+'"';

      DebugLn('CommandLine 2 : %s', [CmdLine]);
      StartLazProcess.CommandLine := CmdLine;
      StartLazProcess.Execute;
    finally
      FreeAndNil(Params);
      StartLazProcess.Free;
    end;
  end;

var CanClose: boolean;
begin
  DebugLn(['TMainIDE.DoRestart ']);
  CanClose:=true;
  MainIDEBar.OnCloseQuery(Self, CanClose);
  if not CanClose then exit;
  MainIDEBar.Close;
  if Application.Terminated then begin
    if StartedByStartLazarus then
      ExitCode := ExitCodeRestartLazarus
    else
      StartStarter;
  end;
end;

procedure TMainIDE.DoExecuteRemoteControl;

  procedure OpenFiles(Files: TStrings);
  var
    AProjectFilename: string;
    ProjectLoaded: Boolean;
    AFilename: String;
    i: Integer;
    OpenFlags: TOpenFlags;
  begin
    if (Files=nil) or (Files.Count=0) then exit;
    ProjectLoaded:=Project1<>nil;
    DebugLn(['TMainIDE.DoExecuteRemoteControl.OpenFiles ProjectLoaded=',ProjectLoaded]);

    // open project (only the last in the list)
    AProjectFilename:='';
    for i:=Files.Count-1 downto 0 do begin
      AProjectFilename:=Files[0];
      if (CompareFileExt(AProjectFilename,'.lpr',false)=0) then
        AProjectFilename:=ChangeFileExt(AProjectFilename,'.lpi');
      if (CompareFileExt(AProjectFilename,'.lpi',false)=0) then begin
        // open a project
        Files.Delete(i); // remove from the list
        AProjectFilename:=CleanAndExpandFilename(AProjectFilename);
        if FileExistsUTF8(AProjectFilename) then begin
          DebugLn(['TMainIDE.DoExecuteRemoteControl.OpenFiles AProjectFilename="',AProjectFilename,'"']);
          if (Project1<>nil)
          and (CompareFilenames(AProjectFilename,Project1.ProjectInfoFile)=0)
          then begin
            // project is already open => do not reopen
            ProjectLoaded:=true;
          end else begin
            // open another project
            ProjectLoaded:=(DoOpenProjectFile(AProjectFilename,[])=mrOk);
          end;
        end;
      end;
    end;

    if not ProjectLoaded then begin
      // create new project
      DoNewProject(ProjectDescriptorApplication);
    end;

    // load the files
    if Files<>nil then begin
      for i:=0 to Files.Count-1 do begin
        AFilename:=CleanAndExpandFilename(Files.Strings[i]);
        DebugLn(['TMainIDE.DoExecuteRemoteControl.OpenFiles AFilename="',AFilename,'"']);
        if CompareFileExt(AFilename,'.lpk',false)=0 then begin
          if PkgBoss.DoOpenPackageFile(AFilename,[pofAddToRecent],true)=mrAbort
          then
            break;
        end else begin
          OpenFlags:=[ofAddToRecent,ofRegularFile];
          if i<Files.Count then
            Include(OpenFlags,ofMultiOpen);
          if DoOpenEditorFile(AFilename,-1,-1,OpenFlags)=mrAbort then begin
            break;
          end;
        end;
      end;
    end;
  end;

var
  Filename: String;
  List: TStringListUTF8;
  Files: TStrings;
  i: Integer;
  CmdShow: Boolean;
begin
  Filename:=GetRemoteControlFilename;
  if FileExistsUTF8(Filename) and (FRemoteControlFileAge<>FileAgeUTF8(Filename))
  then begin
    // the control file exists and has changed
    List:=TStringListUTF8.Create;
    Files:=nil;
    try
      // load and delete the file
      try
        List.LoadFromFile(Filename);
      except
        DebugLn(['TMainIDE.DoExecuteRemoteControl reading file failed: ',Filename]);
      end;
      DeleteFileUTF8(Filename);
      FRemoteControlFileAge:=-1;
      // execute
      Files:=TStringList.Create;
      CmdShow:=false;
      for i:=0 to List.Count-1 do begin
        if SysUtils.CompareText(List[i],'show')=0 then
          CmdShow:=true;
        if SysUtils.CompareText(copy(List[i],1,5),'open ')=0 then
          Files.Add(copy(List[i],6,length(List[i])));
      end;
      if CmdShow then begin
        // if minimized then restore, bring IDE to front
        Application.MainForm.ShowOnTop;
      end;
      if Files.Count>0 then begin
        OpenFiles(Files);
      end;
    finally
      List.Free;
      Files.Free;
    end;
  end else begin
    // the control file does not exist
    FRemoteControlFileAge:=-1;
  end;
end;

//-----------------------------------------------------------------------------

function TMainIDE.DoRunExternalTool(Index: integer; ShowAbort: Boolean): TModalResult;
begin
  SourceEditorManager.ClearErrorLines;
  Result:=ExternalUserTools.Run(Index,ShowAbort);
  DoCheckFilesOnDisk;
end;

function TMainIDE.DoSaveBuildIDEConfigs(Flags: TBuildLazarusFlags): TModalResult;
var
  InheritedOptionStrings: TInheritedCompOptsStrings;
  FPCVersion, FPCRelease, FPCPatch: integer;
  Builder: TLazarusBuilder;
begin
  // create uses section addition for lazarus.pp
  Result:=PkgBoss.DoSaveAutoInstallConfig;
  if Result<>mrOk then exit;

  // check ambiguous units
  CodeToolBoss.GetFPCVersionForDirectory(
                             EnvironmentOptions.GetParsedLazarusDirectory,
                             FPCVersion,FPCRelease,FPCPatch);
  if (FPCVersion=0) or (FPCRelease=0) or (FPCPatch=0) then ;

  // save extra options
  Builder:=TLazarusBuilder.Create;
  try
    // prepare static auto install packages
    //PkgOptions:='';
    // create inherited compiler options
    Builder.PackageOptions:=PackageGraph.GetIDEInstallPackageOptions(InheritedOptionStrings);

    Result:=Builder.SaveIDEMakeOptions(MiscellaneousOptions.BuildLazProfiles.Current,
                                       Flags+[blfOnlyIDE]);
  finally
    Builder.Free;
  end;
end;

function TMainIDE.DoExampleManager: TModalResult;
begin
  Result:=ShowExampleManagerDlg;
end;

function TMainIDE.DoBuildLazarusSub(Flags: TBuildLazarusFlags): TModalResult;
var
  IDEBuildFlags: TBuildLazarusFlags;
  InheritedOptionStrings: TInheritedCompOptsStrings;
  CompiledUnitExt: String;
  FPCVersion, FPCRelease, FPCPatch: integer;
  PkgCompileFlags: TPkgCompileFlags;
  OldToolStatus: TIDEToolStatus;
begin
  if ToolStatus<>itNone then begin
    IDEMessageDialog(lisNotNow,lisYouCanNotBuildLazarusWhileDebuggingOrCompiling,
                     mtError,[mbCancel]);
    Result:=mrCancel;
    exit;
  end;

  if DoAbortBuild(true)<>mrOK then exit;

  Result:=DoSaveAll([sfDoNotSaveVirtualFiles]);
  if Result<>mrOk then begin
    DebugLn('TMainIDE.DoBuildLazarus: failed because saving failed');
    exit;
  end;

  if fBuilder=Nil then
    fBuilder:=TLazarusBuilder.Create;
  if ExternalTools.RunningCount=0 then
    IDEMessagesWindow.Clear;
  fBuilder.ProfileChanged:=false;
  OldToolStatus:=ToolStatus;
  ToolStatus:=itBuilder;
  with MiscellaneousOptions do
  try
    MainBuildBoss.SetBuildTargetIDE;

    // clean up
    PkgCompileFlags:=[];
    if (not (blfDontClean in Flags))
    and (BuildLazProfiles.Current.IdeBuildMode<>bmBuild) then begin
      PkgCompileFlags:=PkgCompileFlags+[pcfCompileDependenciesClean];
      if BuildLazProfiles.Current.IdeBuildMode=bmCleanAllBuild then begin
        SourceEditorManager.ClearErrorLines;
        fBuilder.PackageOptions:='';
        Result:=fBuilder.MakeLazarus(BuildLazProfiles.Current, [blfDontBuild]);
        if Result<>mrOk then begin
          DebugLn('TMainIDE.DoBuildLazarus: Clean all failed.');
          exit;
        end;
      end;
    end;

    // compile auto install static packages
    Result:=PkgBoss.DoCompileAutoInstallPackages(PkgCompileFlags+[pcfDoNotSaveEditorFiles],false);
    if Result<>mrOk then begin
      DebugLn('TMainIDE.DoBuildLazarusSub: Compile AutoInstall Packages failed.');
      exit;
    end;

    // create uses section addition for lazarus.pp
    Result:=PkgBoss.DoSaveAutoInstallConfig;
    if Result<>mrOk then begin
      DebugLn('TMainIDE.DoBuildLazarus: Save AutoInstall Config failed.');
      exit;
    end;

    // create inherited compiler options
    fBuilder.PackageOptions:=PackageGraph.GetIDEInstallPackageOptions(InheritedOptionStrings);

    // check ambiguous units
    CodeToolBoss.GetFPCVersionForDirectory(EnvironmentOptions.GetParsedLazarusDirectory,
                                           FPCVersion,FPCRelease,FPCPatch);
    if FPCPatch=0 then ;
    CompiledUnitExt:=GetDefaultCompiledUnitExt(FPCVersion,FPCRelease);
    Result:=MainBuildBoss.CheckUnitPathForAmbiguousPascalFiles(
                     EnvironmentOptions.GetParsedLazarusDirectory+PathDelim+'ide',
                     InheritedOptionStrings[icoUnitPath],
                     CompiledUnitExt,'IDE');
    if Result<>mrOk then begin
      DebugLn('TMainIDE.DoBuildLazarus: Check UnitPath for ambiguous pascal files failed.');
      exit;
    end;

    // save extra options
    IDEBuildFlags:=Flags;
    Result:=fBuilder.SaveIDEMakeOptions(BuildLazProfiles.Current,
               IDEBuildFlags-[blfUseMakeIDECfg,blfDontClean]+[blfBackupOldExe]);
    if Result<>mrOk then begin
      DebugLn('TMainIDE.DoBuildLazarus: Save IDEMake options failed.');
      exit;
    end;

    // make lazarus ide
    SourceEditorManager.ClearErrorLines;
    IDEBuildFlags:=IDEBuildFlags+[blfUseMakeIDECfg,blfDontClean];
    Result:=fBuilder.MakeLazarus(BuildLazProfiles.Current, IDEBuildFlags);
    if Result<>mrOk then exit;

    if fBuilder.ProfileChanged then begin
      MiscellaneousOptions.Modified:=true;
      MiscellaneousOptions.Save;
    end;
  finally
    MainBuildBoss.SetBuildTargetProject1(true);
    DoCheckFilesOnDisk;
    ToolStatus:=OldToolStatus;
  end;
end;

function TMainIDE.DoBuildLazarus(Flags: TBuildLazarusFlags): TModalResult;
begin
  Result:=DoBuildLazarusSub(Flags);
  if (Result=mrOK) then begin
    with MiscellaneousOptions do begin
      if BuildLazProfiles.RestartAfterBuild
      and (BuildLazProfiles.Current.TargetDirectory='')
      and MainBuildBoss.BuildTargetIDEIsDefault then
        mnuRestartClicked(nil);
    end;
  end else if Result=mrIgnore then
    Result:=mrOK;
end;

function TMainIDE.DoBuildAdvancedLazarus(ProfileNames: TStringList): TModalResult;
var
  CmdLineDefines: TDefineTemplate;
  LazSrcTemplate: TDefineTemplate;
  LazSrcDirTemplate: TDefineTemplate;
  i, ProfInd, RealCurInd: Integer;
  MayNeedRestart: Boolean;
begin
  Result:=mrOK;
  with MiscellaneousOptions do begin
    MayNeedRestart:=False;
    RealCurInd:=BuildLazProfiles.CurrentIndex;
    try
      for i:=0 to ProfileNames.Count-1 do begin
        ProfInd:=BuildLazProfiles.IndexByName(ProfileNames[i]);
        if ProfInd<>-1 then begin
          // Set current profile temporarily, used by the codetools functions.
          BuildLazProfiles.CurrentIndex:=ProfInd;
          LazSrcTemplate:=
            CodeToolBoss.DefineTree.FindDefineTemplateByName(StdDefTemplLazarusSources,true);
          if Assigned(LazSrcTemplate) then begin
            LazSrcDirTemplate:=LazSrcTemplate.FindChildByName(StdDefTemplLazarusSrcDir);
            if Assigned(LazSrcDirTemplate) then begin
              CmdLineDefines:=CodeToolBoss.DefinePool.CreateFPCCommandLineDefines(
                        StdDefTemplLazarusBuildOpts,
                        BuildLazProfiles.Current.ExtraOptions,true,CodeToolsOpts);
              CodeToolBoss.DefineTree.ReplaceChild(LazSrcDirTemplate,CmdLineDefines,
                                                   StdDefTemplLazarusBuildOpts);
            end;
          end;
          Result:=DoBuildLazarusSub([]);
          if (Result=mrOK) then begin
            if BuildLazProfiles.RestartAfterBuild
            and (BuildLazProfiles.Current.TargetDirectory='')
            and MainBuildBoss.BuildTargetIDEIsDefault then
              MayNeedRestart:=True
          end
          else if Result=mrIgnore then
            Result:=mrOK
          else
            exit;
        end;
      end;
    finally
      BuildLazProfiles.CurrentIndex:=RealCurInd;
    end;
    if MayNeedRestart and BuildLazProfiles.RestartAfterBuild then
      mnuRestartClicked(nil);
  end;
end;

function TMainIDE.DoBuildFile(ShowAbort: Boolean): TModalResult;
var
  ActiveSrcEdit: TSourceEditor;
  ActiveUnitInfo: TUnitInfo;
  DirectiveList: TStringList;
  BuildWorkingDir: String;
  BuildCommand: String;
  BuildScan: TIDEDirBuildScanFlags;
  ProgramFilename: string;
  Params: string;
  ExtTool: TIDEExternalToolOptions;
  Filename: String;
  OldToolStatus: TIDEToolStatus;
begin
  Result:=mrCancel;
  if ToolStatus<>itNone then exit;
  ActiveSrcEdit:=nil;
  if not BeginCodeTool(ActiveSrcEdit,ActiveUnitInfo,[]) then exit;
  Result:=DoSaveProject([]);
  if Result<>mrOk then exit;
  if ExternalTools.RunningCount=0 then
    IDEMessagesWindow.Clear;
  DirectiveList:=TStringList.Create;
  OldToolStatus:=ToolStatus;
  ToolStatus:=itBuilder;
  try
    Result:=GetIDEDirectives(ActiveUnitInfo,DirectiveList);
    if Result<>mrOk then exit;

    // get values from directive list
    // build
    BuildWorkingDir:=GetIDEStringDirective(DirectiveList,
                                         IDEDirectiveNames[idedBuildWorkingDir],
                                         '');
    if BuildWorkingDir='' then
      BuildWorkingDir:=ExtractFilePath(ActiveUnitInfo.Filename);
    if not GlobalMacroList.SubstituteStr(BuildWorkingDir) then begin
      Result:=mrCancel;
      exit;
    end;
    BuildCommand:=GetIDEStringDirective(DirectiveList,
                                      IDEDirectiveNames[idedBuildCommand],
                                      IDEDirDefaultBuildCommand);
    if (not GlobalMacroList.SubstituteStr(BuildCommand))
    or (BuildCommand='') then begin
      Result:=mrCancel;
      exit;
    end;
    BuildScan:=GetIDEDirBuildScanFromString(GetIDEStringDirective(DirectiveList,
                                   IDEDirectiveNames[idedBuildScan],''));

    SourceEditorManager.ClearErrorLines;

    SplitCmdLine(BuildCommand,ProgramFilename,Params);
    if not FilenameIsAbsolute(ProgramFilename) then begin
      Filename:=FindProgram(ProgramFilename,BuildWorkingDir,true);
      if Filename<>'' then ProgramFilename:=Filename;
    end;
    if ProgramFilename='' then begin
      Result:=mrCancel;
      exit;
    end;

    ExtTool:=TIDEExternalToolOptions.Create;
    try
      ExtTool.Title:='Build File '+ActiveUnitInfo.Filename;
      ExtTool.WorkingDirectory:=BuildWorkingDir;
      ExtTool.CmdLineParams:=Params;
      ExtTool.Executable:=ProgramFilename;
      if idedbsfFPC in BuildScan then
        ExtTool.Scanners.Add(SubToolFPC);
      if idedbsfMake in BuildScan then
        ExtTool.Scanners.Add(SubToolMake);
      ExtTool.Scanners.Add(SubToolDefault);
      if RunExternalTool(ExtTool) then
        Result:=mrOk
      else
        Result:=mrCancel;
    finally
      // clean up
      ExtTool.Free;
    end;
  finally
    ToolStatus:=OldToolStatus;
    DirectiveList.Free;
  end;
end;

function TMainIDE.DoRunFile: TModalResult;
var
  ActiveSrcEdit: TSourceEditor;
  ActiveUnitInfo: TUnitInfo;
  FirstLine: String;
  HasShebang: Boolean;
  RunFlags: TIDEDirRunFlags;
  DefRunFlags: TIDEDirRunFlags;
  AlwaysBuildBeforeRun: boolean;
  RunWorkingDir: String;
  DefRunCommand: String;
  RunCommand: String;
  ProgramFilename: string;
  Params: string;
  ExtTool: TIDEExternalToolOptions;
  DirectiveList: TStringList;
begin
  Result:=mrCancel;
  if ToolStatus<>itNone then exit;
  ActiveSrcEdit:=nil;
  if not BeginCodeTool(ActiveSrcEdit,ActiveUnitInfo,[]) then exit;
  if not FilenameIsAbsolute(ActiveUnitInfo.Filename) then begin
    Result:=DoSaveEditorFile(ActiveSrcEdit,[sfCheckAmbiguousFiles]);
    if Result<>mrOk then exit;
  end;
  DirectiveList:=TStringList.Create;
  try
    Result:=GetIDEDirectives(ActiveUnitInfo,DirectiveList);
    if Result<>mrOk then exit;

    if ActiveUnitInfo.Source.LineCount>0 then
      FirstLine:=ActiveUnitInfo.Source.GetLine(0,false)
    else
      FirstLine:='';
    HasShebang:=copy(FirstLine,1,2)='#!';
    DefRunFlags:=IDEDirRunFlagDefValues;
    if HasShebang then Exclude(DefRunFlags,idedrfBuildBeforeRun);
    RunFlags:=GetIDEDirRunFlagFromString(
      GetIDEStringDirective(DirectiveList,IDEDirectiveNames[idedRunFlags],''),
      DefRunFlags);
    AlwaysBuildBeforeRun:=idedrfBuildBeforeRun in RunFlags;
    if AlwaysBuildBeforeRun then begin
      Result:=DoBuildFile(true);
      if Result<>mrOk then exit;
    end;
    RunWorkingDir:=GetIDEStringDirective(DirectiveList,
                                       IDEDirectiveNames[idedRunWorkingDir],'');
    if RunWorkingDir='' then
      RunWorkingDir:=ExtractFilePath(ActiveUnitInfo.Filename);
    if not GlobalMacroList.SubstituteStr(RunWorkingDir) then begin
      Result:=mrCancel;
      exit;
    end;
    if HasShebang then
      DefRunCommand:='instantfpc'+ExeExt+' '+ActiveUnitInfo.Filename
    else
      DefRunCommand:=IDEDirDefaultRunCommand;
    RunCommand:=GetIDEStringDirective(DirectiveList,
                                    IDEDirectiveNames[idedRunCommand],
                                    DefRunCommand);
    if (not GlobalMacroList.SubstituteStr(RunCommand)) then
      exit(mrCancel);
    if (RunCommand='') then
      exit(mrCancel);

    SourceEditorManager.ClearErrorLines;

    SplitCmdLine(RunCommand,ProgramFilename,Params);

    ExtTool:=TIDEExternalToolOptions.Create;
    try
      ExtTool.Title:='Run File '+ActiveUnitInfo.Filename;
      ExtTool.WorkingDirectory:=RunWorkingDir;
      ExtTool.CmdLineParams:=Params;
      ExtTool.Executable:=ProgramFilename;
      if RunExternalTool(ExtTool) then
        Result:=mrOk
      else
        Result:=mrCancel;
    finally
      // clean up
      ExtTool.Free;
    end;
  finally
    DirectiveList.Free;
  end;
end;

function TMainIDE.DoConfigBuildFile: TModalResult;
var
  ActiveSrcEdit: TSourceEditor;
  ActiveUnitInfo: TUnitInfo;
  DirectiveList: TStringList;
  CodeResult: Boolean;
  BuildFileDialog: TBuildFileDialog;
  s: String;
begin
  Result:=mrCancel;
  ActiveSrcEdit:=nil;
  if not BeginCodeTool(ActiveSrcEdit,ActiveUnitInfo,[]) then exit;
  if not FilenameIsAbsolute(ActiveUnitInfo.Filename) then begin
    Result:=DoSaveEditorFile(ActiveSrcEdit,[sfCheckAmbiguousFiles]);
    if Result<>mrOk then exit;
  end;
  DirectiveList:=TStringList.Create;
  try
    Result:=GetIDEDirectives(ActiveUnitInfo,DirectiveList);
    if Result<>mrOk then exit;

    BuildFileDialog:=TBuildFileDialog.Create(nil);
    try
      BuildFileDialog.DirectiveList:=DirectiveList;
      BuildFileDialog.BuildFileIfActive:=ActiveUnitInfo.BuildFileIfActive;
      BuildFileDialog.RunFileIfActive:=ActiveUnitInfo.RunFileIfActive;
      BuildFileDialog.MacroList:=GlobalMacroList;
      BuildFileDialog.Filename:=
        CreateRelativePath(ActiveUnitInfo.Filename,Project1.ProjectDirectory);
      if BuildFileDialog.ShowModal<>mrOk then begin
        DebugLn(['TMainIDE.DoConfigBuildFile cancelled']);
        Result:=mrCancel;
        exit;
      end;
      ActiveUnitInfo.BuildFileIfActive:=BuildFileDialog.BuildFileIfActive;
      ActiveUnitInfo.RunFileIfActive:=BuildFileDialog.RunFileIfActive;
    finally
      BuildFileDialog.Free;
    end;

    //DebugLn(['TMainIDE.DoConfigBuildFile ',ActiveUnitInfo.Filename,' ',DirectiveList.DelimitedText]);

    // save IDE directives
    if FilenameIsPascalSource(ActiveUnitInfo.Filename) then begin
      // parse source for IDE directives (i.e. % comments)
      CodeResult:=CodeToolBoss.SetIDEDirectives(ActiveUnitInfo.Source,
                                                DirectiveList);
      ApplyCodeToolChanges;
      if not CodeResult then begin
        DoJumpToCodeToolBossError;
        exit;
      end;

    end else begin
      s:=StringListToString(DirectiveList,0,DirectiveList.Count-1,true);
      if ActiveUnitInfo.CustomData['IDEDirectives']<>s then begin
        ActiveUnitInfo.CustomData['IDEDirectives']:=s;
        ActiveUnitInfo.Modified:=true;
      end;
    end;

  finally
    DirectiveList.Free;
  end;

  Result:=mrOk;
end;

function TMainIDE.GetIDEDirectives(AnUnitInfo: TUnitInfo;
  DirectiveList: TStrings): TModalResult;
var
  CodeResult: Boolean;
begin
  Result:=mrCancel;
  if FilenameIsPascalSource(AnUnitInfo.Filename) then begin
    // parse source for IDE directives (i.e. % comments)
    CodeResult:=CodeToolBoss.GetIDEDirectives(AnUnitInfo.Source,DirectiveList);
    if not CodeResult then begin
      DoJumpToCodeToolBossError;
      exit;
    end;
  end else begin
    StringToStringList(AnUnitInfo.CustomData['IDEDirectives'],DirectiveList);
    //DebugLn(['TMainIDE.GetIDEDirectives ',dbgstr(DirectiveList.Text)]);
  end;
  Result:=mrOk;
end;

function TMainIDE.DoConvertDFMtoLFM: TModalResult;
var
  OpenDialog: TOpenDialog;
  DFMConverter: TDFMConverter;
  i: integer;
  AFilename: string;
begin
  Result:=mrOk;
  OpenDialog:=TOpenDialog.Create(nil);
  try
    InputHistories.ApplyFileDialogSettings(OpenDialog);
    OpenDialog.Title:=lisSelectDFMFiles;
    OpenDialog.Options:=OpenDialog.Options+[ofAllowMultiSelect];
    OpenDialog.Filter:=rsFormDataFileDfm+'|'+dlgAllFiles+'|'+GetAllFilesMask;
    if OpenDialog.Execute and (OpenDialog.Files.Count>0) then begin
      For I := 0 to OpenDialog.Files.Count-1 do begin
        AFilename:=ExpandFileNameUTF8(OpenDialog.Files.Strings[i]);
        DFMConverter:=TDFMConverter.Create;
        try
          Result:=DFMConverter.Convert(AFilename);
        finally
          DFMConverter.Free;
        end;
      end;
      SaveEnvironment;
    end;
    InputHistories.StoreFileDialogSettings(OpenDialog);
  finally
    OpenDialog.Free;
  end;
  DoCheckFilesOnDisk;
end;

function TMainIDE.DoConvertDelphiProject(const DelphiFilename: string): TModalResult;
var
  OldChange: Boolean;
  Converter: TConvertDelphiProject;
begin
  InputHistories.LastConvertDelphiProject:=DelphiFilename;
  OldChange:=OpenEditorsOnCodeToolChange;
  OpenEditorsOnCodeToolChange:=true;
  Converter := TConvertDelphiProject.Create(DelphiFilename);
  try
    Result:=Converter.Convert;
  finally
    Converter.Free;
    OpenEditorsOnCodeToolChange:=OldChange;
  end;
end;

function TMainIDE.DoConvertDelphiPackage(const DelphiFilename: string): TModalResult;
var
  OldChange: Boolean;
  Converter: TConvertDelphiPackage;
begin
  InputHistories.LastConvertDelphiPackage:=DelphiFilename;
  OldChange:=OpenEditorsOnCodeToolChange;
  OpenEditorsOnCodeToolChange:=true;
  Converter := TConvertDelphiPackage.Create(DelphiFilename);
  try
    Result:=Converter.Convert;
  finally
    Converter.Free;
    OpenEditorsOnCodeToolChange:=OldChange;
  end;
end;

{-------------------------------------------------------------------------------
  procedure TMainIDE.UpdateExternalUserToolsInMenu;

  Creates a TMenuItem for each custom external tool.
-------------------------------------------------------------------------------}
procedure TMainIDE.UpdateExternalUserToolsInMenu;
var
  ToolCount: integer;
  Section: TIDEMenuSection;
  CurMenuItem: TIDEMenuItem;
  i: Integer;
  ExtTool: TExternalUserTool;
begin
  ToolCount:=ExternalUserTools.Count;
  Section:=itmCustomTools;
  Section.BeginUpdate;
  try
    // add enough menuitems
    while Section.Count-1<ToolCount do
      RegisterIDEMenuCommand(Section.GetPath,
                          'itmToolCustomExt'+IntToStr(Section.Count),'');
    // delete unneeded menuitems
    while Section.Count-1>ToolCount do
      Section[Section.Count-1].Free;

    // set caption and command
    for i:=0 to ToolCount-1 do begin
      CurMenuItem:=itmCustomTools[i+1]; // Note: the first menu item is the "Configure"
      ExtTool:=ExternalUserTools[i];
      CurMenuItem.Caption:=ExtTool.Title;
      if CurMenuItem is TIDEMenuCommand then
        TIDEMenuCommand(CurMenuItem).Command:=
          EditorOpts.KeyMap.FindIDECommand(ecExtToolFirst+i);
      CurMenuItem.OnClick:=@mnuExternalUserToolClick;
    end;
  finally
    Section.EndUpdate;
  end;
end;

function TMainIDE.PrepareForCompile: TModalResult;
begin
  Result:=mrOk;
  if ToolStatus=itDebugger then begin
    Result:=IDEQuestionDialog(lisStopDebugging2, lisStopCurrentDebuggingAndRebuildProject,
                              mtConfirmation,[mrYes, mrCancel, lisNo],'');
    if Result<>mrYes then exit;

    Result:=DebugBoss.DoStopProject;
    if Result<>mrOk then exit;
  end;

  // Save the property editor value in Object Inspector
  if Assigned(ObjectInspector1) then
    ObjectInspector1.GetActivePropertyGrid.SaveChanges;

  if MainBuildBoss.CompilerOnDiskChanged then
    MainBuildBoss.RescanCompilerDefines(false,false,false,false);

  if (IDEMessagesWindow<>nil) and (ExternalTools.RunningCount=0) then
    IDEMessagesWindow.Clear;
end;

function TMainIDE.DoCheckSyntax: TModalResult;
var
  ActiveUnitInfo:TUnitInfo;
  ActiveSrcEdit:TSourceEditor;
  NewCode: TCodeBuffer;
  NewX, NewY, NewTopLine: integer;
  ErrorMsg: string;
  Handled: Boolean;
begin
  Result:=mrOk;
  GetCurrentUnit(ActiveSrcEdit,ActiveUnitInfo);
  if (ActiveUnitInfo=nil) or (ActiveUnitInfo.Source=nil)
  or (ActiveSrcEdit=nil) then exit;

  Handled:=false;
  Result:=DoCallModalHandledHandler(lihtQuickSyntaxCheck,Handled);
  if Handled then exit;

  SaveSourceEditorChangesToCodeCache(nil);
  CodeToolBoss.VisibleEditorLines:=ActiveSrcEdit.EditorComponent.LinesInWindow;
  if CodeToolBoss.CheckSyntax(ActiveUnitInfo.Source,NewCode,NewX,NewY,
    NewTopLine,ErrorMsg) then
  begin
    SourceFileMgr.ArrangeSourceEditorAndMessageView(false);
    MessagesView.ClearCustomMessages;
    MessagesView.AddCustomMessage(mluImportant,lisMenuQuickSyntaxCheckOk);
  end else begin
    DoJumpToCodeToolBossError;
  end;
  if (ErrorMsg='') or (NewTopLine=0) or (NewX=0) or (NewY=0) or (NewCode=nil) then ; // avoid compiler hints about parameters not used
end;

//-----------------------------------------------------------------------------

procedure TMainIDE.GetCurrentUnit(out ActiveSourceEditor:TSourceEditor;
  out ActiveUnitInfo:TUnitInfo);
begin
  ActiveSourceEditor := SourceEditorManager.ActiveEditor;
  if ActiveSourceEditor=nil then
    ActiveUnitInfo:=nil
  else
    ActiveUnitInfo := Project1.UnitWithEditorComponent(ActiveSourceEditor);
end;

procedure TMainIDE.GetDesignerUnit(ADesigner: TDesigner;
  var ActiveSourceEditor: TSourceEditor; var ActiveUnitInfo: TUnitInfo);
begin
  if ADesigner<>nil then begin
    GetUnitWithForm(ADesigner.Form,ActiveSourceEditor,ActiveUnitInfo);
  end else begin
    ActiveSourceEditor:=nil;
    ActiveUnitInfo:=nil;
  end;
end;

function TMainIDE.GetProjectFileForProjectEditor(AEditor: TSourceEditorInterface
  ): TLazProjectFile;
begin
  Result := Project1.UnitWithEditorComponent(AEditor);
end;

function TMainIDE.GetDesignerForProjectEditor(AEditor: TSourceEditorInterface;
  LoadForm: boolean): TIDesigner;
var
  AProjectFile: TLazProjectFile;
begin
  AProjectFile := Project1.UnitWithEditorComponent(AEditor);
  if AProjectFile <> nil then
    Result:=LazarusIDE.GetDesignerWithProjectFile(
      Project1.UnitWithEditorComponent(AEditor), LoadForm)
  else
    Result := nil;
end;

function TMainIDE.GetDesignerWithProjectFile(AFile: TLazProjectFile;
  LoadForm: boolean): TIDesigner;
var
  AnUnitInfo: TUnitInfo;
  AForm: TCustomForm;
begin
  AnUnitInfo:=AFile as TUnitInfo;
  AForm:=GetDesignerFormOfSource(AnUnitInfo,LoadForm);
  if AForm<>nil then
    Result:=AForm.Designer
  else
    Result:=nil;
end;

procedure TMainIDE.GetObjectInspectorUnit(
  var ActiveSourceEditor: TSourceEditor; var ActiveUnitInfo: TUnitInfo);
begin
  ActiveSourceEditor:=nil;
  ActiveUnitInfo:=nil;
  if (ObjectInspector1=nil) or (ObjectInspector1.PropertyEditorHook=nil)
  or (ObjectInspector1.PropertyEditorHook.LookupRoot=nil)
  then exit;
  GetUnitWithPersistent(ObjectInspector1.PropertyEditorHook.LookupRoot,
    ActiveSourceEditor,ActiveUnitInfo);
end;

procedure TMainIDE.GetUnitWithForm(AForm: TCustomForm;
  var ActiveSourceEditor: TSourceEditor; var ActiveUnitInfo: TUnitInfo);
var
  AComponent: TComponent;
begin
  if AForm<>nil then begin
    if (AForm.Designer=nil) then
      RaiseException('TMainIDE.GetUnitWithForm AForm.Designer');
    AComponent:=AForm.Designer.LookupRoot;
    if AComponent=nil then
      RaiseException('TMainIDE.GetUnitWithForm AComponent=nil');
    GetUnitWithPersistent(AComponent,ActiveSourceEditor,ActiveUnitInfo);
  end else begin
    ActiveSourceEditor:=nil;
    ActiveUnitInfo:=nil;
  end;
end;

procedure TMainIDE.GetUnitWithPersistent(APersistent: TPersistent;
  var ActiveSourceEditor: TSourceEditor; var ActiveUnitInfo: TUnitInfo);
begin
  if (APersistent<>nil) and (Project1<>nil) then begin
    ActiveUnitInfo:=Project1.FirstUnitWithComponent;
    while ActiveUnitInfo<>nil do begin
      if ActiveUnitInfo.Component=APersistent then begin
        if ActiveUnitInfo.OpenEditorInfoCount > 0 then
          ActiveSourceEditor := TSourceEditor(ActiveUnitInfo.OpenEditorInfo[0].EditorComponent);
        exit;
      end;
      ActiveUnitInfo:=ActiveUnitInfo.NextUnitWithComponent;
    end;
  end;
  ActiveSourceEditor:=nil;
  ActiveUnitInfo:=nil;
end;

function TMainIDE.DoCheckFilesOnDisk(Instantaneous: boolean): TModalResult;
begin
  Result:=SourceFileMgr.CheckFilesOnDisk(Instantaneous);
end;

function TMainIDE.DoPublishModule(Options: TPublishModuleOptions;
  const SrcDirectory, DestDirectory: string): TModalResult;
begin
  Result:=SourceFileMgr.PublishModule(Options, SrcDirectory, DestDirectory);
end;

procedure TMainIDE.PrepareBuildTarget(Quiet: boolean; ScanFPCSrc: TScanModeFPCSources);
begin
  MainBuildBoss.SetBuildTargetProject1(Quiet,ScanFPCSrc);
end;

procedure TMainIDE.AbortBuild;
begin
  ExternalTools.TerminateAll;
end;

procedure TMainIDE.UpdateCaption;

  function AddToCaption(const CurrentCaption, CaptAddition: string): String;
  begin
    if EnvironmentOptions.IDETitleStartsWithProject then
      Result := CaptAddition + ' - ' + CurrentCaption
    else
      Result := CurrentCaption + ' - ' + CaptAddition;
  end;

var
  NewCaption, NewTitle, ProjectName, DirName: String;
begin
  if MainIDEBar = nil then Exit;
  if ToolStatus = itExiting then Exit;
  NewCaption := Format(lisLazarusEditorV, [GetLazarusVersionString]);
  NewTitle := NewCaption;
  if MainBarSubTitle <> '' then
    NewCaption := AddToCaption(NewCaption, MainBarSubTitle)
  else
  begin
    if Project1 <> nil then
    begin
      ProjectName := Project1.GetTitleOrName;
      if ProjectName <> '' then
      begin
        if EnvironmentOptions.IDEProjectDirectoryInIdeTitle then
        begin
          DirName := ExtractFileDir(Project1.ProjectInfoFile);
          if DirName <> '' then
            ProjectName := ProjectName + ' ('+DirName+')';
        end;
      end
      else
        ProjectName := lisnewProject;
      NewTitle := AddToCaption(NewCaption, ProjectName);
      if EnvironmentOptions.IDETitleIncludesBuildMode and (Project1.BuildModes.Count > 1)
      then
        ProjectName:= ProjectName + ' - ' +Project1.ActiveBuildMode.GetCaption;
      NewCaption := AddToCaption(NewCaption, ProjectName);
    end;
  end;
  case ToolStatus of
    itBuilder: NewCaption := Format(liscompiling, [NewCaption]);
    itDebugger:
    begin
      if DebugBoss.Commands - [dcRun, dcStop, dcEnvironment] <> [] then
        NewCaption := Format(lisDebugging, [NewCaption])
      else
        NewCaption := Format(lisRunning, [NewCaption]);
    end;
  end;
  MainIDEBar.Caption := NewCaption;
  Application.Title := NewTitle;
end;

procedure TMainIDE.HideIDE;
var
  i: Integer;
  AForm: TCustomForm;
begin
  {$IFDEF DEBUGHIDEIDEWINDOWSONRUN}
  DebugLn('TMainIDE.HideIDE ENTERED HiddenWindowsOnRun.Count=',dbgs(HiddenWindowsOnRun.Count),
  ' LastFormActivated ',dbgsName(LastFormActivated),
  ' WindowMenuActive ',dbgsName(WindowMenuActiveForm));
  {$ENDIF}

  // hide hints
  Application.HideHint;
  SourceEditorManager.HideHint;

  // hide designer forms
  // CloseUnmodifiedDesigners;

  // collect all windows except the main bar
  for i:=0 to Screen.CustomFormCount-1 do
  begin
    AForm:=Screen.CustomForms[i];
    if (AForm.Parent=nil)                     // ignore nested forms
    and (AForm<>MainIDEBar)                   // ignore the main bar
    and (AForm.IsVisible)                     // ignore hidden forms
    and (not (fsModal in AForm.FormState))    // ignore modal forms
    and (HiddenWindowsOnRun.IndexOf(AForm)<0) // ignore already collected forms
    then
      HiddenWindowsOnRun.Add(AForm);
  end;

  // hide all collected windows
  for i:=0 to HiddenWindowsOnRun.Count-1 do
  begin
    AForm:=TCustomForm(HiddenWindowsOnRun[i]);
    if (AForm.Designer <> nil) or (csDesigning in AForm.ComponentState) then
    begin
      {$IFDEF DEBUGHIDEIDEWINDOWSONRUN}
      DebugLn('TMainIDE.HideIDE: HIDING VIA LCLINTF ',dbgsName(AForm),' WindowState ',dbgs(AForm.WindowState),
      ' IsIconic ',dbgs(LCLIntf.IsIconic(AForm.Handle)));
      {$ENDIF}
      LCLIntf.ShowWindow(AForm.Handle, SW_HIDE);
    end else
    begin
      {$IFDEF DEBUGHIDEIDEWINDOWSONRUN}
      DebugLn('TMainIDE.HideIDE: HIDING NON DESIGNED FORM ',dbgsName(AForm));
      {$ENDIF}
      AForm.Hide;
    end;
  end;

  // minimize IDE
  MainIDEBar.HideIDE;
  {$IFDEF DEBUGHIDEIDEWINDOWSONRUN}
  DebugLn('TMainIDE.HideIDE EXITED ');
  {$ENDIF}
end;

procedure TMainIDE.CloseUnmodifiedDesigners;
var
  AnUnitInfo: TUnitInfo;
  NextUnitInfo: TUnitInfo;
begin
  if Project1=nil then exit;
  AnUnitInfo:=Project1.FirstUnitWithComponent;
  while AnUnitInfo<>nil do begin
    NextUnitInfo:=AnUnitInfo.NextUnitWithComponent;
    if not AnUnitInfo.NeedsSaveToDisk then
      SourceFileMgr.CloseUnitComponent(AnUnitInfo,[]);
    AnUnitInfo:=NextUnitInfo;
  end;
end;

procedure TMainIDE.UnhideIDE;
var
  AForm: TCustomForm;
  i: Integer;
  AActiveForm: TCustomForm;
begin
  {$IFDEF DEBUGHIDEIDEWINDOWSONRUN}
  DebugLn('TMainIDE.UnhideIDE  Active=',dbgsName(WindowMenuActiveForm));
  {$ENDIF}
  AActiveForm := WindowMenuActiveForm;
  // unminimize IDE
  MainIDEBar.UnhideIDE;

  // show other windows but keep order as it was before hiding.
  for i := HiddenWindowsOnRun.Count - 1 downto 0 do
  begin
    AForm:=TCustomForm(HiddenWindowsOnRun[i]);
    if (csDesigning in AForm.ComponentState) or (AForm.Designer <> nil) then
    begin
      {$IFDEF DEBUGHIDEIDEWINDOWSONRUN}
      DebugLn('TMainIDE.UnhideIDE: Showing LCLIntf AForm ',dbgsName(AForm),
      ' WindowState ',dbgs(AForm.WindowState),' LCLIntf.IsIconic ',
        dbgs(LCLIntf.IsIconic(AForm.Handle)));
      {$ENDIF}
      if LCLIntf.IsIconic(AForm.Handle) then
        LCLIntf.ShowWindow(AForm.Handle, SW_SHOWMINIMIZED)
      else
        LCLIntf.ShowWindow(AForm.Handle, SW_SHOWNORMAL);
      // ShowDesignerForm(AForm)
    end else
    begin
      {$IFDEF DEBUGHIDEIDEWINDOWSONRUN}
      DebugLn('TMainIDE.UnhideIDE: Showing AForm ',dbgsName(AForm));
      {$ENDIF}
      AForm.Show;
    end;
  end;
  HiddenWindowsOnRun.Clear;
  {$IFDEF DEBUGHIDEIDEWINDOWSONRUN}
  DebugLn('TMainIDE.UnhideIDE: activating form ',dbgsName(AActiveForm));
  {$ENDIF}
  {activate form or app, must be so because of debugmanager !}
  if Assigned(AActiveForm) then
    AActiveForm.BringToFront
  else
    Application.BringToFront;
end;

procedure TMainIDE.SaveIncludeLinks;
var
  AFilename: string;
begin
  // save include file relationships
  AFilename:=AppendPathDelim(GetPrimaryConfigPath)+CodeToolsIncludeLinkFile;
  CodeToolBoss.SourceCache.SaveIncludeLinksToFile(AFilename,true);
end;

procedure TMainIDE.DoBringToFrontFormOrUnit;
begin
  {$IFDEF VerboseIDEDisplayState}
  debugln(['TMainIDE.DoBringToFrontFormOrUnit ',dbgs(DisplayState)]);
  {$ENDIF}
  if DisplayState <> dsSource then begin
    DoShowSourceOfActiveDesignerForm;
  end else begin
    DoShowDesignerFormOfCurrentSrc;
  end;
end;

procedure TMainIDE.DoBringToFrontFormOrInspector(ForceInspector: boolean);
begin
  if ForceInspector then begin
    DoShowInspector(iwgfShowOnTop);
    exit;
  end;
  {$IFDEF VerboseIDEDisplayState}
  debugln(['TMainIDE.DoBringToFrontFormOrInspector old=',dbgs(DisplayState)]);
  {$ENDIF}
  case DisplayState of
  dsInspector: DoShowDesignerFormOfCurrentSrc;
  dsInspector2: DoShowSourceOfActiveDesignerForm;
  else
    DoShowInspector(iwgfShowOnTop);
  end;
end;

procedure TMainIDE.DoShowDesignerFormOfCurrentSrc;
var
  ActiveSourceEditor: TSourceEditor;
  ActiveUnitInfo: TUnitInfo;
  AForm: TCustomForm;
  UnitCodeBuf: TCodeBuffer;
begin
  {$IFDEF VerboseIDEDisplayState}
  debugln(['TMainIDE.DoShowDesignerFormOfCurrentSrc ']);
  {$ENDIF}
  GetCurrentUnit(ActiveSourceEditor,ActiveUnitInfo);
  if (ActiveUnitInfo = nil) then exit;

  if (ActiveUnitInfo.Component=nil)
  and (ActiveUnitInfo.Source<>nil)
  and (CompareFileExt(ActiveUnitInfo.Filename,'.inc',false)=0) then begin
    // include file => get unit
    UnitCodeBuf:=CodeToolBoss.GetMainCode(ActiveUnitInfo.Source);
    if (UnitCodeBuf<>nil) and (UnitCodeBuf<>ActiveUnitInfo.Source) then begin
      // unit found
      ActiveUnitInfo:=Project1.ProjectUnitWithFilename(UnitCodeBuf.Filename);
      if (ActiveUnitInfo=nil) or (ActiveUnitInfo.OpenEditorInfoCount=0) then begin
        // open unit in source editor and load form
        DoOpenEditorFile(UnitCodeBuf.Filename,-1,-1,
          [ofOnlyIfExists,ofRegularFile,ofVirtualFile,ofDoLoadResource]);
        exit;
      end;
    end;
  end;

  // load the form, if not already done
  AForm:=GetDesignerFormOfSource(ActiveUnitInfo,true);
  if AForm=nil then exit;
  DisplayState:=dsForm;
  LastFormActivated:=AForm;
  ShowDesignerForm(AForm);
  if TheControlSelection.SelectionForm<>AForm then begin
    // select the new form (object inspector, formeditor, control selection)
    TheControlSelection.AssignPersistent(ActiveUnitInfo.Component);
  end;
end;

procedure TMainIDE.DoShowSourceOfActiveDesignerForm;
var
  ActiveUnitInfo: TUnitInfo;
begin
  if SourceEditorManager.SourceEditorCount = 0 then exit;
  if LastFormActivated <> nil then begin
    ActiveUnitInfo := Project1.UnitWithComponent(LastFormActivated.Designer.LookupRoot);
    if (ActiveUnitInfo <> nil) and (ActiveUnitInfo.OpenEditorInfoCount > 0) then
      SourceEditorManager.ActiveEditor :=
                 TSourceEditor(ActiveUnitInfo.OpenEditorInfo[0].EditorComponent);
  end;
  SourceEditorManager.ShowActiveWindowOnTop(False);
  {$IFDEF VerboseIDEDisplayState}
  debugln(['TMainIDE.DoShowSourceOfActiveDesignerForm ']);
  {$ENDIF}
  DisplayState:=dsSource;
end;

procedure TMainIDE.GetIDEFileState(Sender: TObject; const AFilename: string;
  NeededFlags: TIDEFileStateFlags; out ResultFlags: TIDEFileStateFlags);
var
  AnUnitInfo: TUnitInfo;
begin
  ResultFlags:=[];
  AnUnitInfo:=nil;
  if Project1<>nil then
    AnUnitInfo:=Project1.UnitInfoWithFilename(AFilename);
  if AnUnitInfo<>nil then begin
    // readonly
    if (ifsReadOnly in NeededFlags) and AnUnitInfo.ReadOnly then
      Include(ResultFlags,ifsReadOnly);
    // part of project
    if (ifsPartOfProject in NeededFlags) and AnUnitInfo.IsPartOfProject then
      Include(ResultFlags,ifsPartOfProject);
    // open in editor
    if (ifsOpenInEditor in NeededFlags) and (AnUnitInfo.OpenEditorInfoCount > 0) then
      Include(ResultFlags,ifsOpenInEditor);
  end else if FileExistsUTF8(AFilename) then begin
    // readonly
    if (ifsReadOnly in NeededFlags) and (not FileIsWritable(AFilename)) then
      Include(ResultFlags,ifsReadOnly);
  end;
end;

function TMainIDE.DoJumpToCompilerMessage(FocusEditor: boolean;
  Msg: TMessageLine): boolean;
var
  Filename, SearchedFilename: string;
  LogCaretXY: TPoint;
  TopLine: integer;
  SrcEdit: TSourceEditor;
  OpenFlags: TOpenFlags;
  AnUnitInfo: TUnitInfo;
  AnEditorInfo: TUnitEditorInfo;
begin
  Result:=false;

  if Screen.GetCurrentModalForm<>nil then
    exit;

  if Msg=nil then begin
    // first find an error with a source position
    if MessagesView.SelectFirstUrgentMessage(mluError,true) then
      Msg:=MessagesView.GetSelectedLine;
    // then find any error
    if (Msg=nil) and MessagesView.SelectFirstUrgentMessage(mluError,false) then
      Msg:=MessagesView.GetSelectedLine;
    if Msg=nil then exit;
  end else begin
    MessagesView.SelectMsgLine(Msg);
  end;
  Msg:=MessagesView.GetSelectedLine;
  if Msg=nil then exit;

  // first try the plugins
  if IDEQuickFixes.OpenMsg(Msg) then exit;

  Filename:=Msg.GetFullFilename;
  LogCaretXY.Y:=Msg.Line;
  LogCaretXY.X:=Msg.Column;

  OpenFlags:=[ofOnlyIfExists,ofRegularFile];
  if MainBuildBoss.IsTestUnitFilename(Filename) then begin
    SearchedFilename := ExtractFileName(Filename);
    Include(OpenFlags,ofVirtualFile);
  end else begin
    SearchedFilename := FindUnitFile(Filename);
    if not FilenameIsAbsolute(SearchedFilename) then
      Include(OpenFlags,ofVirtualFile);
  end;

  if SearchedFilename<>'' then begin
    // open the file in the source editor
    AnUnitInfo := nil;
    if Project1<>nil then
      AnUnitInfo:=Project1.UnitInfoWithFilename(SearchedFilename);
    AnEditorInfo := nil;
    if AnUnitInfo <> nil then
      AnEditorInfo := GetAvailableUnitEditorInfo(AnUnitInfo, LogCaretXY);
    if AnEditorInfo <> nil then begin
      SourceEditorManager.ActiveEditor := TSourceEditor(AnEditorInfo.EditorComponent);
      Result := True;
    end
    else
      Result:=(DoOpenEditorFile(SearchedFilename,-1,-1,OpenFlags)=mrOk);
    if Result then begin
      // set caret position
      SourceEditorManager.AddJumpPointClicked(Self);
      SrcEdit:=SourceEditorManager.ActiveEditor;
      if LogCaretXY.Y>SrcEdit.EditorComponent.Lines.Count then
        LogCaretXY.Y:=SrcEdit.EditorComponent.Lines.Count;
      if LogCaretXY.X<1 then
        LogCaretXY.X:=1;
      TopLine:=LogCaretXY.Y-(SrcEdit.EditorComponent.LinesInWindow div 2);
      if TopLine<1 then TopLine:=1;
      if FocusEditor then begin
        IDEWindowCreators.ShowForm(MessagesView,true);
        SourceEditorManager.ShowActiveWindowOnTop(True);
      end;
      SrcEdit.EditorComponent.LogicalCaretXY:=LogCaretXY;
      SrcEdit.EditorComponent.TopLine:=TopLine;
      SrcEdit.CenterCursorHoriz(hcmSoftKeepEOL);
      SrcEdit.ErrorLine:=LogCaretXY.Y;
    end;
  end else begin
    if FilenameIsAbsolute(Filename) then begin
      IDEMessageDialog(lisInformation,
        Format(lisUnableToFindFile, [Filename]), mtInformation,[mbOk])
    end else if Filename<>'' then begin
      IDEMessageDialog(lisInformation,
        Format(lisUnableToFindFileCheckSearchPathInProjectCompilerOption,
               [Filename, LineEnding, LineEnding]),
        mtInformation,[mbOk]);
    end;
  end;
end;

procedure TMainIDE.DoJumpToNextError(DirectionDown: boolean);
var
  Msg: TMessageLine;
begin
  if not MessagesView.SelectNextUrgentMessage(mluError,true,DirectionDown) then
    exit;
  Msg:=MessagesView.GetSelectedLine;
  if Msg=nil then exit;
  DoJumpToCompilerMessage(true,Msg);
end;

function TMainIDE.DoJumpToSearchResult(FocusEditor: boolean): boolean;
var
  AFileName: string;
  SearchedFilename: string;
  LogCaretXY: TPoint;
  OpenFlags: TOpenFlags;
  SrcEdit: TSourceEditor;
  AnUnitInfo: TUnitInfo;
  AnEditorInfo: TUnitEditorInfo;
begin
  Result:=false;
  if pos('(',SearchResultsView.GetSelectedText) > 0 then
  begin
    AFileName:= SearchResultsView.GetSourceFileName;
    if AFilename='' then exit;
    LogCaretXY:= SearchResultsView.GetSourcePositon;
    OpenFlags:=[ofOnlyIfExists,ofRegularFile];
    if MainBuildBoss.IsTestUnitFilename(AFilename) then begin
      SearchedFilename := ExtractFileName(AFilename);
      Include(OpenFlags,ofVirtualFile);
    end else begin
      SearchedFilename := FindUnitFile(AFilename);
    end;
    if SearchedFilename<>'' then begin
      // open the file in the source editor
      AnUnitInfo := nil;
      if Project1<>nil then
        AnUnitInfo := Project1.UnitInfoWithFilename(SearchedFilename);
      AnEditorInfo := nil;
      if AnUnitInfo <> nil then
        AnEditorInfo := GetAvailableUnitEditorInfo(AnUnitInfo, LogCaretXY);
      if AnEditorInfo <> nil then begin
        SourceEditorManager.ActiveEditor := TSourceEditor(AnEditorInfo.EditorComponent);
        Result := True;
      end else
        Result:=(DoOpenEditorFile(SearchedFilename,-1,-1,OpenFlags)=mrOk);
      if Result then begin
        // set caret position
        SourceEditorManager.AddJumpPointClicked(Self);
        SrcEdit:=SourceEditorManager.ActiveEditor;
        if LogCaretXY.Y>SrcEdit.EditorComponent.Lines.Count then
          LogCaretXY.Y:=SrcEdit.EditorComponent.Lines.Count;
        if FocusEditor then begin
          IDEWindowCreators.ShowForm(SearchResultsView,true);
          SourceEditorManager.ShowActiveWindowOnTop(True);
        end;
        try
          SrcEdit.BeginUpdate;
          SrcEdit.EditorComponent.LogicalCaretXY:=LogCaretXY;
          if not SrcEdit.IsLocked then begin
            SrcEdit.CenterCursor(True);
            SrcEdit.CenterCursorHoriz(hcmSoftKeepEOL);
          end;
        finally
          SrcEdit.EndUpdate;
        end;
        SrcEdit.ErrorLine:=LogCaretXY.Y;
      end;
    end else if AFilename<>'' then begin
      if FilenameIsAbsolute(AFilename) then begin
        IDEMessageDialog(lisInformation,
          Format(lisUnableToFindFile, [AFilename]), mtInformation,[mbOk]);
      end else if AFileName<>'' then begin
        IDEMessageDialog(lisInformation,
          Format(lisUnableToFindFileCheckSearchPathInProjectCompilerOption,
                 [AFilename, LineEnding, LineEnding]),
          mtInformation,[mbOk]);
      end;
    end;
  end;//if
end;

procedure TMainIDE.DoShowMessagesView(BringToFront: boolean);
begin
  //debugln('TMainIDE.DoShowMessagesView');
  MessagesView.ApplyIDEOptions;

  // don't move the messagesview, if it was already visible.
  IDEWindowCreators.ShowForm(MessagesView,BringToFront);
end;

procedure TMainIDE.DoShowSearchResultsView(State: TIWGetFormState);
begin
  if SearchresultsView=Nil then begin
    IDEWindowCreators.CreateForm(SearchresultsView,TSearchResultsView,
       State=iwgfDisabled,LazarusIDE.OwningComponent);
    SearchresultsView.OnSelectionChanged := OnSearchResultsViewSelectionChanged;
  end else if State=iwgfDisabled then
    SearchResultsView.DisableAutoSizing;
  if State>=iwgfShow then
    IDEWindowCreators.ShowForm(SearchresultsView,State=iwgfShowOnTop);
end;

function TMainIDE.GetTestBuildDirectory: string;
begin
  Result:=MainBuildBoss.GetTestBuildDirectory;
end;

function TMainIDE.GetFPCompilerFilename: string;
begin
  Result:=MainBuildBoss.GetFPCompilerFilename;
end;

function TMainIDE.GetFPCFrontEndOptions: string;
begin
  Result:=MainBuildBoss.GetFPCFrontEndOptions;
end;

function TMainIDE.FindUnitFile(const AFilename: string; TheOwner: TObject;
  Flags: TFindUnitFileFlags): string;
begin
  Result:=SourceFileMgr.FindUnitFile(AFilename, TheOwner, Flags);
end;

{------------------------------------------------------------------------------
  function TMainIDE.FindSourceFile(const AFilename, BaseDirectory: string;
    Flags: TFindSourceFlags): string;

  AFilename can be an absolute or relative filename, of a source file or a
  compiled unit (.ppu).
  Find the source filename (pascal source or include file) and returns
  the absolute path.
  With fsfMapTempToVirtualFiles files in the temp directory are stripped off
  the temporary files resulting in the virtual file name of the CodeTools.

  First it searches in the current projects src path, then its unit path, then
  its include path. Then all used package source directories are searched.
  Finally the fpc sources are searched.
------------------------------------------------------------------------------}
function TMainIDE.FindSourceFile(const AFilename, BaseDirectory: string;
  Flags: TFindSourceFlags): string;
begin
  Result:=SourceFileMgr.FindSourceFile(AFilename, BaseDirectory, Flags);
end;

//------------------------------------------------------------------------------

procedure TMainIDE.OnDesignerGetSelectedComponentClass(Sender: TObject;
  var RegisteredComponent: TRegisteredComponent);
begin
  RegisteredComponent:=IDEComponentPalette.Selected;
end;

procedure TMainIDE.OnDesignerComponentAdded(Sender: TObject);
var
  Grid: TOICustomPropertyGrid;
  Row: TOIPropertyGridRow;
begin
  TComponentPalette(IDEComponentPalette).DoAfterComponentAdded;
  if EnvironmentOptions.CreateComponentFocusNameProperty
  and (ObjectInspector1<>nil) then begin
    if (ObjectInspector1.ShowFavorites) and (EnvironmentOptions.SwitchToFavoritesOITab) then
      Grid:=ObjectInspector1.FavoriteGrid
    else
      Grid:=ObjectInspector1.PropertyGrid;
     ObjectInspector1.ActivateGrid(Grid);
     Row:=Grid.GetRowByPath('Name');
     if Row<>nil then begin
       Grid.ItemIndex:=Row.Index;
       ObjectInspector1.FocusGrid(Grid);
     end;
  end;
end;

procedure TMainIDE.OnDesignerSetDesigning(Sender: TObject;
  Component: TComponent;  Value: boolean);
begin
  SetDesigning(Component,Value);
end;

procedure TMainIDE.OnDesignerShowOptions(Sender: TObject);
begin
  DoOpenIDEOptions(TFormEditorOptionsFrame);
end;

procedure TMainIDE.OnDesignerPasteComponents(Sender: TObject;
  LookupRoot: TComponent; TxtCompStream: TStream; ParentControl: TWinControl;
  var NewComponents: TFPList);
var
  NewClassName: String;
  ARegComp: TRegisteredComponent;
  BinCompStream: TMemoryStream;
  c: Char;
begin
  DebugLn('TMainIDE.OnDesignerPasteComponent A');

  // check the class of the new component
  NewClassName:=FindLFMClassName(TxtCompStream);

  // check if component class is registered
  ARegComp:=IDEComponentPalette.FindComponent(NewClassName);
  if ARegComp=nil then begin
    IDEMessageDialog(lisClassNotFound,
      Format(lisClassIsNotARegisteredComponentClassUnableToPaste,[NewClassName,LineEnding]),
      mtError,[mbCancel]);
    exit;
  end;

  // check if there is a valid parent
  if (ParentControl=nil) and ARegComp.IsTControl then begin
    IDEMessageDialog(lisControlNeedsParent,
      Format(lisTheClassIsATControlAndCanNotBePastedOntoANonContro,[NewClassName,LineEnding]),
      mtError,[mbCancel]);
    exit;
  end;

  // convert text to binary format
  BinCompStream:=TMemoryStream.Create;
  try
    try
      LRSObjectTextToBinary(TxtCompStream,BinCompStream);
      // always append an "object list end"
      c:=#0;
      BinCompStream.Write(c,1);
    except
      on E: Exception do begin
        IDEMessageDialog(lisConversionError,
          Format(lisUnableToConvertComponentTextIntoBinaryFormat,
                [LineEnding, E.Message]),
          mtError,[mbCancel]);
        exit;
      end;
    end;

    BinCompStream.Position:=0;

    // create the component
    FormEditor1.CreateChildComponentsFromStream(BinCompStream,
                ARegComp.ComponentClass,LookupRoot,ParentControl,NewComponents);
    if NewComponents.Count=0 then begin
      DebugLn('TMainIDE.OnDesignerPasteComponent FAILED FormEditor1.CreateChildComponentFromStream');
      exit;
    end;

  finally
    BinCompStream.Free;
  end;
end;

procedure TMainIDE.OnDesignerPastedComponents(Sender: TObject; LookupRoot: TComponent);
begin
  DoFixupComponentReferences(LookupRoot,[]);
end;

procedure TMainIDE.OnDesignerPropertiesChanged(Sender: TObject);
begin
  if ObjectInspector1<>nil then
    ObjectInspector1.RefreshPropertyValues;
end;

procedure TMainIDE.OnDesignerPersistentDeleted(Sender: TObject; APersistent: TPersistent);
// important: APersistent was freed, do not access it
begin
  if dfDestroyingForm in TDesigner(Sender).Flags then exit;
  if ObjectInspector1<>nil then
    ObjectInspector1.FillPersistentComboBox;
end;

procedure TMainIDE.OnPropHookPersistentDeleting(APersistent: TPersistent);
var
  ActiveForm: TCustomForm;
  ActiveUnitInfo: TUnitInfo;
  ActiveSrcEdit: TSourceEditor;
  OwnerClassName: string;
  CurDesigner: TDesigner;
begin
  if not (APersistent is TComponent) then exit;
  //DebugLn(['TMainIDE.OnPropHookPersistentDeleting ',dbgsName(APersistent)]);
  CurDesigner:=TDesigner(FindRootDesigner(TComponent(APersistent)));
  if CurDesigner=nil then exit;

  if dfDestroyingForm in CurDesigner.Flags then exit;

  if not BeginCodeTool(CurDesigner,ActiveSrcEdit,ActiveUnitInfo,
                [ctfSwitchToFormSource]) then exit;
  ActiveForm:=CurDesigner.Form;
  if ActiveForm=nil then
    RaiseException('[TMainIDE.OnPropHookPersistentDeleting] Error: TDesigner without a form');
  // find source for form
  ActiveUnitInfo:=Project1.UnitWithComponent(CurDesigner.LookupRoot);
  if ActiveUnitInfo=nil then begin
    RaiseException('[TMainIDE.OnPropHookPersistentDeleting] Error: form without source');
  end;
  if APersistent is TComponent then begin
    // mark references modified
    if APersistent is TComponent then
      MarkUnitsModifiedUsingSubComponent(TComponent(APersistent));

    // remember cursor position
    SourceEditorManager.AddJumpPointClicked(Self);

    // remove component definition from owner source
    OwnerClassName:=CurDesigner.LookupRoot.ClassName;
    //DebugLn(['TMainIDE.OnPropHookPersistentDeleting ',dbgsName(APersistent),' OwnerClassName=',OwnerClassName]);
    CodeToolBoss.RemovePublishedVariable(ActiveUnitInfo.Source,OwnerClassName,
                                         TComponent(APersistent).Name,false);
  end;
end;

procedure TMainIDE.OnDesignerModified(Sender: TObject);
var
  SrcEdit: TSourceEditor;
  CurDesigner: TDesigner absolute Sender;
  AnUnitInfo: TUnitInfo;
begin
  if dfDestroyingForm in CurDesigner.Flags then Exit;
  AnUnitInfo := Project1.UnitWithComponent(CurDesigner.LookupRoot);
  if AnUnitInfo <> nil then
  begin
    AnUnitInfo.Modified := True;
    if AnUnitInfo.Loaded then
    begin
      if AnUnitInfo.OpenEditorInfoCount > 0 then
      begin
        SrcEdit := TSourceEditor(AnUnitInfo.OpenEditorInfo[0].EditorComponent);
        SrcEdit.Modified := True;
        {$IFDEF VerboseDesignerModified}
        DumpStack;
        {$ENDIF}
      end;
    end;
  end;
end;

procedure TMainIDE.OnControlSelectionChanged(Sender: TObject; ForceUpdate: Boolean);
var
  NewSelection: TPersistentSelectionList;
  i: integer;
begin
  {$IFDEF IDE_DEBUG}
  debugln('[TMainIDE.OnControlSelectionChanged]');
  {$ENDIF}
  if (TheControlSelection = nil) or (FormEditor1 = nil) then Exit;

  NewSelection := TPersistentSelectionList.Create;
  NewSelection.ForceUpdate := ForceUpdate;
  for i := 0 to TheControlSelection.Count - 1 do
    NewSelection.Add(TheControlSelection[i].Persistent);
  FormEditor1.Selection := NewSelection;
  NewSelection.Free;
  {$IFDEF IDE_DEBUG}
  debugln('[TMainIDE.OnControlSelectionChanged] END');
  {$ENDIF}
end;

procedure TMainIDE.OnControlSelectionPropsChanged(Sender: TObject);
begin
  if (TheControlSelection=nil) or (FormEditor1=nil) or (ObjectInspector1=nil) then exit;
  ObjectInspector1.SaveChanges; // Save in any case, PropEditor value may have changed
  ObjectInspector1.RefreshPropertyValues;
end;

procedure TMainIDE.OnControlSelectionFormChanged(Sender: TObject; OldForm,
  NewForm: TCustomForm);
begin
  if (TheControlSelection=nil) or (FormEditor1=nil) or not FIDEStarted then exit;
  if OldForm<>nil then
    OldForm.Invalidate;
  if TheControlSelection.LookupRoot<>nil then
    GlobalDesignHook.LookupRoot:=TheControlSelection.LookupRoot;
  if NewForm<>nil then
    NewForm.Invalidate;
  {$IFDEF VerboseComponentPalette}
  DebugLn('***');
  DebugLn('** TMainIDE.OnControlSelectionFormChanged: Calling UpdateIDEComponentPalette(true)');
  {$ENDIF}
  UpdateIDEComponentPalette(true);
end;

procedure TMainIDE.OnGetDesignerSelection(const ASelection: TPersistentSelectionList);
begin
  if TheControlSelection=nil then exit;
  TheControlSelection.GetSelection(ASelection);
end;

// -----------------------------------------------------------------------------

procedure TMainIDE.OnCodeExplorerGetDirectivesTree(Sender: TObject;
  var ADirectivesTool: TDirectivesTool);
var
  ActiveUnitInfo: TUnitInfo;
  ActiveSrcEdit: TSourceEditor;
begin
  ADirectivesTool:=nil;
  ActiveSrcEdit:=nil;
  if not BeginCodeTool(ActiveSrcEdit,ActiveUnitInfo,[]) then exit;
  CodeToolBoss.ExploreDirectives(ActiveUnitInfo.Source,ADirectivesTool);
end;

procedure TMainIDE.OnCodeExplorerJumpToCode(Sender: TObject;
  const Filename: string; const Caret: TPoint; TopLine: integer);
begin
  DoJumpToSourcePosition(Filename,Caret.X,Caret.Y,TopLine,[jfAddJumpPoint, jfFocusEditor]);
end;

procedure TMainIDE.OnCodeExplorerShowOptions(Sender: TObject);
begin
  DoOpenIDEOptions(TCodeExplorerUpdateOptionsFrame);
end;

procedure TMainIDE.OnCodeToolNeedsExternalChanges(Manager: TCodeToolManager;
  var Abort: boolean);
var
  ActiveSrcEdit: TSourceEditor;
  ActiveUnitInfo: TUnitInfo;
begin
  ActiveSrcEdit:=nil;
  Abort:=not BeginCodeTool(ActiveSrcEdit,ActiveUnitInfo,[]);
end;

// -----------------------------------------------------------------------------

function TMainIDE.InitCodeToolBoss: boolean;
// initialize the CodeToolBoss, which is the frontend for the codetools.
//  - sets a basic set of compiler macros
var
  AFilename: string;
begin
  Result:=true;
  OpenEditorsOnCodeToolChange:=false;

  // load caches
  MainBuildBoss.LoadFPCDefinesCaches;

  CodeToolBoss.DefinePool.OnProgress:=@CodeToolBossProgress;
  CodeToolBoss.SourceCache.ExpirationTimeInDays:=365;
  CodeToolBoss.SourceCache.OnEncodeSaving:=@OnCodeBufferEncodeSaving;
  CodeToolBoss.SourceCache.OnDecodeLoaded:=@OnCodeBufferDecodeLoaded;
  CodeToolBoss.SourceCache.DefaultEncoding:=EncodingUTF8;
  CodeToolBoss.DefineTree.OnGetVirtualDirectoryAlias:=
    @CodeToolBossGetVirtualDirectoryAlias;
  CodeToolBoss.DefineTree.OnGetVirtualDirectoryDefines:=
    @CodeToolBossGetVirtualDirectoryDefines;
  CodeToolBoss.DefineTree.OnPrepareTree:=@CodeToolBossPrepareTree;

  CodeToolBoss.DefineTree.MacroFunctions.AddExtended(
    'PROJECT',nil,@CTMacroFunctionProject);

  CodeToolsOpts.AssignTo(CodeToolBoss);

  // create a test unit needed to get from the compiler all macros and search paths
  CodeToolBoss.FPCDefinesCache.TestFilename:=CreateCompilerTestPascalFilename;
  MainBuildBoss.UpdateEnglishErrorMsgFilename;

  // set global macros
  with CodeToolBoss.GlobalValues do begin
    Variables[ExternalMacroStart+'LazarusDir']:=EnvironmentOptions.GetParsedLazarusDirectory;
    Variables[ExternalMacroStart+'ProjPath']:=VirtualDirectory;
    Variables[ExternalMacroStart+'LCLWidgetType']:=LCLPlatformDirNames[GetDefaultLCLWidgetType];
    Variables[ExternalMacroStart+'FPCSrcDir']:=EnvironmentOptions.GetParsedFPCSourceDirectory;
  end;

  // the first template is the "use default" flag
  CreateUseDefaultsFlagTemplate;

  MainBuildBoss.SetBuildTargetProject1(true);

  // load include file relationships
  AFilename:=AppendPathDelim(GetPrimaryConfigPath)+CodeToolsIncludeLinkFile;
  if FileExistsCached(AFilename) then
    CodeToolBoss.SourceCache.LoadIncludeLinksFromFile(AFilename);

  with CodeToolBoss do begin
    WriteExceptions:=true;
    CatchExceptions:=true;
    OnGatherExternalChanges:=@OnCodeToolNeedsExternalChanges;
    OnBeforeApplyChanges:=@OnBeforeCodeToolBossApplyChanges;
    OnAfterApplyChanges:=@OnAfterCodeToolBossApplyChanges;
    OnSearchUsedUnit:=@OnCodeToolBossSearchUsedUnit;
    OnFindDefineProperty:=@OnCodeToolBossFindDefineProperty;
    OnGetMethodName:=@OnCodeToolBossGetMethodName;
    OnGetIndenterExamples:=@OnCodeToolBossGetIndenterExamples;
    OnScannerInit:=@CodeToolBossScannerInit;
    OnFindFPCMangledSource:=@CodeToolBossFindFPCMangledSource;
  end;

  CodeToolsOpts.AssignGlobalDefineTemplatesToTree(CodeToolBoss.DefineTree);

  CompilerParseStampIncreased:=@OnCompilerParseStampIncreased;

  {$IFDEF CheckNodeTool}
  // codetools consistency check
  CodeToolBoss.ConsistencyCheck;
  {$ENDIF}
end;

function TMainIDE.BeginCodeTools: boolean;
var
  ActiveSrcEdit: TSourceEditor;
  ActiveUnitInfo: TUnitInfo;
begin
  ActiveSrcEdit:=nil;
  Result:=BeginCodeTool(nil,ActiveSrcEdit,ActiveUnitInfo,
                        [ctfSourceEditorNotNeeded]);
end;

procedure TMainIDE.OnBeforeCodeToolBossApplyChanges(Manager: TCodeToolManager;
  var Abort: boolean);
// the CodeToolBoss built a list of Sources that will be modified
// 1. open all of them in the source notebook
// 2. lock the editors to reduce repaints and undo steps
var
  i: integer;
  Flags: TOpenFlags;
  CodeBuf: TCodeBuffer;
begin
  if OpenEditorsOnCodeToolChange then begin
    // open all sources in editor
    for i:=0 to Manager.SourceChangeCache.BuffersToModifyCount-1 do begin
      CodeBuf:=Manager.SourceChangeCache.BuffersToModify[i];

      // do not open lpr file
      if (not OpenMainSourceOnCodeToolChange)
      and (Project1<>nil) and (Project1.MainUnitInfo<>nil)
      and (CompareFilenames(Project1.MainFilename,CodeBuf.Filename)=0) then
        continue;

      //DebugLn(['TMainIDE.OnBeforeCodeToolBossApplyChanges i=',i,' ',CodeBUf.Filename]);
      Flags:=[ofOnlyIfExists,ofDoNotLoadResource,ofRegularFile];
      if CodeBuf.IsVirtual then
        Include(Flags,ofVirtualFile);
      if DoOpenEditorFile(Manager.SourceChangeCache.BuffersToModify[i].Filename,
        -1,-1,Flags)<>mrOk then
      begin
        Abort:=true;
        exit;
      end;
    end;
  end;
  // lock all editors
  SourceEditorManager.LockAllEditorsInSourceChangeCache;
end;

procedure TMainIDE.OnAfterCodeToolBossApplyChanges(Manager: TCodeToolManager);
var
  i: Integer;
  SrcBuf: TCodeBuffer;
  AnUnitInfo: TUnitInfo;
  MsgResult: TModalResult;
begin
  for i:=0 to CodeToolBoss.SourceChangeCache.BuffersToModifyCount-1 do begin
    SrcBuf:=CodeToolBoss.SourceChangeCache.BuffersToModify[i];
    AnUnitInfo:=nil;
    if Project1<>nil then
      AnUnitInfo:=Project1.UnitInfoWithFilename(SrcBuf.Filename);
    if AnUnitInfo<>nil then
      AnUnitInfo.Modified:=true;

    if SaveClosedSourcesOnCodeToolChange
    and (not SrcBuf.IsVirtual)
    and ((AnUnitInfo=nil) or (AnUnitInfo.OpenEditorInfoCount = 0)) then
    begin
      // save closed file (closed = not open in editor)
      MsgResult:=SaveCodeBuffer(SrcBuf);
      if MsgResult=mrAbort then break;
    end;
  end;
  SourceEditorManager.UnlockAllEditorsInSourceChangeCache;
end;

function TMainIDE.OnCodeToolBossSearchUsedUnit(const SrcFilename: string;
  const TheUnitName, TheUnitInFilename: string): TCodeBuffer;
var
  AnUnitInfo: TUnitInfo;
begin
  Result:=nil;
  // check if SrcFilename is project file
  if Project1=nil then exit;
  AnUnitInfo:=Project1.ProjectUnitWithFilename(SrcFilename);
  if AnUnitInfo=nil then exit;
  // SrcFilename is a project file
  // -> search virtual project files
  AnUnitInfo:=Project1.ProjectUnitWithUnitname(TheUnitName);
  if AnUnitInfo=nil then exit;
  // virtual unit found
  Result:=AnUnitInfo.Source;
end;

procedure TMainIDE.CodeToolBossGetVirtualDirectoryAlias(Sender: TObject;
  var RealDir: string);
begin
  if (Project1<>nil) and (Project1.ProjectDirectory<>'') then
    RealDir:=Project1.ProjectDirectory;
end;

procedure TMainIDE.CodeToolBossGetVirtualDirectoryDefines(DefTree: TDefineTree;
  DirDef: TDirectoryDefines);
begin
  if (Project1<>nil) and Project1.IsVirtual then
    Project1.GetVirtualDefines(DefTree,DirDef);
end;

procedure TMainIDE.OnCodeToolBossFindDefineProperty(Sender: TObject;
  const PersistentClassName, AncestorClassName, Identifier: string;
  var IsDefined: boolean);
begin
  FormEditor1.FindDefineProperty(PersistentClassName,AncestorClassName,
                                 Identifier,IsDefined);
end;

procedure TMainIDE.OnCodeBufferDecodeLoaded(Code: TCodeBuffer;
  const Filename: string; var Source, DiskEncoding, MemEncoding: string);
begin
  //DebugLn(['TMainIDE.OnCodeBufferDecodeLoaded Filename=',Filename,' Encoding=',GuessEncoding(Source)]);
  DiskEncoding:='';
  if InputHistories<>nil then
    DiskEncoding:=InputHistories.FileEncodings[Filename];
  if DiskEncoding='' then
    DiskEncoding:=GuessEncoding(Source);
  MemEncoding:=EncodingUTF8;
  if (DiskEncoding<>MemEncoding) then begin
    {$IFDEF VerboseIDEEncoding}
    DebugLn(['TMainIDE.OnCodeBufferDecodeLoaded Filename=',Filename,' Disk=',DiskEncoding,' to Mem=',MemEncoding]);
    {$ENDIF}
    Source:=ConvertEncoding(Source,DiskEncoding,MemEncoding);
    //DebugLn(['TMainIDE.OnCodeBufferDecodeLoaded ',Source]);
  end;
end;

procedure TMainIDE.OnCodeBufferEncodeSaving(Code: TCodeBuffer;
  const Filename: string; var Source: string);
begin
  if (Code.DiskEncoding<>'') and (Code.MemEncoding<>'')
  and (Code.DiskEncoding<>Code.MemEncoding) then begin
    {$IFDEF VerboseIDEEncoding}
    DebugLn(['TMainIDE.OnCodeBufferEncodeSaving Filename=',Code.Filename,' Mem=',Code.MemEncoding,' to Disk=',Code.DiskEncoding]);
    {$ENDIF}
    Source:=ConvertEncoding(Source,Code.MemEncoding,Code.DiskEncoding);
  end;
end;

procedure TMainIDE.CodeToolBossPrepareTree(Sender: TObject);
begin
  if FIDECodeToolsDefines=ctdNeedUpdate then begin
    FIDECodeToolsDefines:=ctdUpdating;
    if Project1<>nil then
      Project1.DefineTemplates.AllChanged;
    PkgBoss.RebuildDefineTemplates;
    FIDECodeToolsDefines:=ctdReady;
    //DebugLn('TMainIDE.CodeToolBossPrepareTree CompilerGraphStamp=',dbgs(CompilerGraphStamp));
    {$IFDEF VerboseAddProjPkg}
    DebugLn(['TMainIDE.CodeToolBossPrepareTree 1 "',CodeToolBoss.GetUnitPathForDirectory('',true),'"']);
    DebugLn(['TMainIDE.CodeToolBossPrepareTree 2 "',CodeToolBoss.GetUnitPathForDirectory('',false),'"']);
    {$ENDIF}
  end;
end;

procedure TMainIDE.CodeToolBossProgress(Sender: TObject; Index,
  MaxIndex: integer; const Msg: string; var Abort: boolean);
begin
  //DebugLn(['TMainIDE.CodeToolBossProgress ',Index,' ',MaxIndex]);
end;

procedure TMainIDE.OnCodeToolBossGetIndenterExamples(Sender: TObject;
  Code: TCodeBuffer; Step: integer; var CodeBuffers: TFPList;
  var ExpandedFilenames: TStrings);
var
  ActiveFilename: string;

  procedure AddCode(Code: TCodeBuffer);
  begin
    if Code=nil then exit;
    if CompareFilenames(ActiveFilename,Code.Filename)=0 then exit;
    if CodeBuffers=nil then CodeBuffers:=TFPList.Create;
    CodeBuffers.Add(Code);
  end;

  procedure AddFile(const Filename: string);
  begin
    if Filename='' then exit;
    if CompareFilenames(ActiveFilename,Filename)=0 then exit;
    if ExpandedFilenames=nil then ExpandedFilenames:=TStringList.Create;
    ExpandedFilenames.Add(Filename);
  end;

  procedure AddUnit(AnUnitInfo: TUnitInfo);
  begin
    if AnUnitInfo.Source<>nil then
      AddCode(AnUnitInfo.Source)
    else
      AddFile(AnUnitInfo.Filename);
  end;

var
  AnUnitInfo: TUnitInfo;
  Owners: TFPList;
  i: Integer;
  AProject: TProject;
  APackage: TLazPackage;
  j: Integer;
  SrcEdit: TSourceEditor;
begin
  if Step>0 then exit;
  ActiveFilename:='';
  SrcEdit:=SourceEditorManager.GetActiveSE;
  if SrcEdit<>nil then
    ActiveFilename:=SrcEdit.FileName;
  if CodeToolsOpts.IndentContextSensitive and (Code<>Nil) then begin
    Owners:=PkgBoss.GetPossibleOwnersOfUnit(Code.Filename,[piosfIncludeSourceDirectories]);
    try
      if Owners<>nil then begin
        for i:=0 to Owners.Count-1 do begin
          if TObject(Owners[i]) is TProject then begin
            AProject:=TProject(Owners[i]);
            if AProject.MainUnitInfo<>nil then
              AddUnit(AProject.MainUnitInfo);
            AnUnitInfo:=AProject.FirstPartOfProject;
            while AnUnitInfo<>nil do begin
              if AnUnitInfo<>AProject.MainUnitInfo then
                AddUnit(AnUnitInfo);
              AnUnitInfo:=AnUnitInfo.NextPartOfProject;
            end;
          end else if TObject(Owners[i]) is TLazPackage then begin
            APackage:=TLazPackage(Owners[i]);
            for j:=0 to APackage.FileCount-1 do begin
              if APackage.Files[j].FileType in PkgFileRealUnitTypes then
                AddFile(APackage.Files[j].GetFullFilename);
            end;
          end;
        end;
      end;
    finally
      Owners.Free;
    end;
  end;
  if FilenameIsAbsolute(CodeToolsOpts.IndentationFileName) then
    AddFile(CodeToolsOpts.IndentationFileName);
end;

function TMainIDE.OnCodeToolBossGetMethodName(const Method: TMethod; PropOwner: TObject): String;
var
  JITMethod: TJITMethod;
  LookupRoot: TPersistent;
begin
  if Method.Code<>nil then begin
    if Method.Data<>nil then
      Result:=TObject(Method.Data).MethodName(Method.Code)
    else
      Result:='';
  end else if IsJITMethod(Method) then begin
    JITMethod:=TJITMethod(Method.Data);
    Result:=JITMethod.TheMethodName;
    if PropOwner is TComponent then begin
      LookupRoot:=GetLookupRootForComponent(TComponent(PropOwner));
      if LookupRoot is TComponent then begin
        //DebugLn(['TMainIDE.OnPropHookGetMethodName ',Result,' ',dbgsName(GlobalDesignHook.LookupRoot),' ',dbgsName(JITMethod.TheClass)]);
        if (LookupRoot.ClassType<>JITMethod.TheClass) then begin
          Result:=JITMethod.TheClass.ClassName+'.'+Result;
        end;
      end;
    end;
  end else
    Result:='';
  {$IFDEF VerboseDanglingComponentEvents}
  if IsJITMethod(Method) then
    DebugLn(['TMainIDE.OnPropHookGetMethodName ',Result,' ',IsJITMethod(Method)]);
  {$ENDIF}
end;

procedure TMainIDE.OnCompilerParseStampIncreased;
begin
  if FIDECodeToolsDefines=ctdUpdating then exit;
  {$IFDEF VerboseAddProjPkg}
  DebugLn(['TMainIDE.OnCompilerParseStampIncreased ']);
  {$ENDIF}
  FIDECodeToolsDefines:=ctdNeedUpdate;
  CodeToolBoss.DefineTree.ClearCache;
end;

procedure TMainIDE.CodeToolBossScannerInit(Self: TCodeToolManager; Scanner: TLinkScanner);
var
  SrcEdit: TSourceEditor;
begin
  if SourceEditorManager=nil then exit;
  SrcEdit:=SourceEditorManager.SourceEditorIntfWithFilename(Scanner.MainFilename);
  //debugln(['TMainIDE.CodeToolBossScannerInit ',Scanner.MainFilename,' ',DbgSName(SrcEdit)]);
  if SrcEdit=nil then exit;
  SrcEdit.ConnectScanner(Scanner);
end;

function TMainIDE.CTMacroFunctionProject(Data: Pointer): boolean;
var
  FuncData: PReadFunctionData;
  Param: String;
begin
  Result:=true;
  if Project1=nil then exit;
  FuncData:=PReadFunctionData(Data);
  Param:=FuncData^.Param;
  //debugln('TMainIDE.MacroFunctionProject A Param="',Param,'"');
  if SysUtils.CompareText(Param,'SrcPath')=0 then
    FuncData^.Result:=Project1.CompilerOptions.GetSrcPath(false)
  else if SysUtils.CompareText(Param,'IncPath')=0 then
    FuncData^.Result:=Project1.CompilerOptions.GetIncludePath(false)
  else if SysUtils.CompareText(Param,'UnitPath')=0 then
    FuncData^.Result:=Project1.CompilerOptions.GetUnitPath(false)
  else begin
    FuncData^.Result:='<unknown parameter for CodeTools Macro project:"'+Param+'">';
    debugln('TMainIDE.MacroFunctionProject WARNING: ',FuncData^.Result);
  end;
end;

function TMainIDE.SaveSourceEditorChangesToCodeCache(AEditor: TSourceEditorInterface): boolean;
// save all open sources to code tools cache
begin
  Result:=SourceFileMgr.SaveSourceEditorChangesToCodeCache(AEditor);
end;

function TMainIDE.DoJumpToSourcePosition(const Filename: string; NewX, NewY,
  NewTopLine: integer; Flags: TJumpToCodePosFlags = [jfFocusEditor]): TModalResult;
var
  CodeBuffer: TCodeBuffer;
  aFilename: String;
begin
  Result:=mrCancel;
  aFilename:=Filename;
  if not (jfDoNotExpandFilename in Flags) then
    aFilename:=TrimAndExpandFilename(aFilename);
  CodeBuffer:=CodeToolBoss.LoadFile(aFilename,true,false);
  if CodeBuffer=nil then exit;
  Result:=DoJumpToCodePosition(nil,nil,CodeBuffer,NewX,NewY,NewTopLine, Flags);
end;

function TMainIDE.DoJumpToCodePosition(ActiveSrcEdit: TSourceEditorInterface;
  ActiveUnitInfo: TUnitInfo; NewSource: TCodeBuffer; NewX, NewY, NewTopLine: integer;
  Flags: TJumpToCodePosFlags): TModalResult;
var
  SrcEdit, NewSrcEdit: TSourceEditor;
  AnEditorInfo: TUnitEditorInfo;
  s: String;
begin
  Result:=mrCancel;
  if NewSource=nil then begin
    DebugLn(['TMainIDE.DoJumpToCodePosition ERROR: missing NewSource']);
    DumpStack;
    exit;
  end;

  if ActiveSrcEdit = nil then
    SrcEdit := nil
  else
    SrcEdit := ActiveSrcEdit as TSourceEditor;

  SourceEditorManager.BeginAutoFocusLock;
  try
    if (SrcEdit=nil) or (ActiveUnitInfo=nil) then
      GetCurrentUnit(SrcEdit,ActiveUnitInfo);

    if (jfAddJumpPoint in Flags) and (ActiveUnitInfo <> nil) and (SrcEdit <> nil)
    and (SrcEdit.EditorComponent<>nil)
    then begin
      if (NewSource<>ActiveUnitInfo.Source)
      or (SrcEdit.EditorComponent.CaretX<>NewX)
      or (SrcEdit.EditorComponent.CaretY<>NewY) then
        SourceEditorManager.AddJumpPointClicked(Self);
    end;

    if (ActiveUnitInfo = nil) or (NewSource<>ActiveUnitInfo.Source)
    then begin
      // jump to other file -> open it
      ActiveUnitInfo := Project1.UnitInfoWithFilename(NewSource.Filename);
      if (ActiveUnitInfo = nil) and (Project1.IsVirtual) and (jfSearchVirtualFullPath in Flags)
      then begin
        s := AppendPathDelim(GetTestBuildDirectory);
        if LazUTF8.UTF8LowerCase(copy(NewSource.Filename, 1, length(s))) = LazUTF8.UTF8LowerCase(s)
        then ActiveUnitInfo := Project1.UnitInfoWithFilename(copy(NewSource.Filename,
                1+length(s), length(NewSource.Filename)), [pfsfOnlyVirtualFiles]);
      end;

      AnEditorInfo := nil;
      if ActiveUnitInfo <> nil then
        AnEditorInfo := GetAvailableUnitEditorInfo(ActiveUnitInfo, Point(NewX,NewY), NewTopLine);
      if AnEditorInfo <> nil then begin
        SourceEditorManager.ActiveEditor := TSourceEditor(AnEditorInfo.EditorComponent);
        Result := mrOK;
      end
      else
        Result:=DoOpenEditorFile(NewSource.Filename,-1,-1,
          [ofOnlyIfExists,ofRegularFile,ofDoNotLoadResource]);
      if Result<>mrOk then begin
        SourceFileMgr.UpdateSourceNames;
        exit;
      end;
      NewSrcEdit := SourceEditorManager.ActiveEditor;
    end
    else begin
      AnEditorInfo := GetAvailableUnitEditorInfo(ActiveUnitInfo, Point(NewX,NewY), NewTopLine);
      if AnEditorInfo <> nil then begin
        NewSrcEdit := TSourceEditor(AnEditorInfo.EditorComponent);
        SourceEditorManager.ActiveEditor := NewSrcEdit;
      end
      else
        NewSrcEdit:=SrcEdit;
    end;
    if NewX<1 then NewX:=1;
    if NewY<1 then NewY:=1;
    if jfMapLineFromDebug in Flags then
      NewY := NewSrcEdit.DebugToSourceLine(NewY);
    //debugln(['[TMainIDE.DoJumpToCodePosition] ',NewX,',',NewY,',',NewTopLine]);

    try
      NewSrcEdit.BeginUpdate;
      NewSrcEdit.EditorComponent.MoveLogicalCaretIgnoreEOL(Point(NewX,NewY));
      if not NewSrcEdit.IsLocked then begin
        if NewTopLine < 1 then
          NewSrcEdit.CenterCursor(True)
        else
          NewSrcEdit.TopLine:=NewTopLine;
      end;
      //DebugLn('TMainIDE.DoJumpToCodePosition NewY=',dbgs(NewY),' ',dbgs(TopLine),' ',dbgs(NewTopLine));
      NewSrcEdit.CenterCursorHoriz(hcmSoftKeepEOL);
    finally
      NewSrcEdit.EndUpdate;
    end;
    if jfMarkLine in Flags then
      NewSrcEdit.ErrorLine := NewY;

    if jfFocusEditor in Flags then
      SourceEditorManager.ShowActiveWindowOnTop(True);
    SourceFileMgr.UpdateSourceNames;
    Result:=mrOk;
  finally
    SourceEditorManager.EndAutoFocusLock;
  end;
end;

function TMainIDE.NeedSaveSourceEditorChangesToCodeCache(AEditor: TSourceEditorInterface): boolean;
// check if any open source needs to be saved to code tools cache
var
  i: integer;

  function NeedSave(SaveEditor: TSourceEditorInterface): boolean;
  var
    AnUnitInfo: TUnitInfo;
  begin
    AnUnitInfo := Project1.UnitWithEditorComponent(SaveEditor);
    if (AnUnitInfo<>nil) and SaveEditor.NeedsUpdateCodeBuffer then
      Result:=true
    else
      Result:=false;
  end;

begin
  Result:=true;
  if AEditor = nil then begin
    for i := 0 to SourceEditorManager.SourceEditorCount - 1 do
      if NeedSave(SourceEditorManager.SourceEditors[i]) then exit;
  end else begin
    if NeedSave(AEditor) then exit;
  end;
  Result:=false;
end;

procedure TMainIDE.ApplyCodeToolChanges;
begin
  // all changes were handled automatically by events, just clear the logs
  CodeToolBoss.SourceCache.ClearAllSourceLogEntries;
end;

procedure TMainIDE.DoJumpToOtherProcedureSection;
var ActiveSrcEdit: TSourceEditor;
  ActiveUnitInfo: TUnitInfo;
  NewSource: TCodeBuffer;
  NewX, NewY, NewTopLine: integer;
  RevertableJump: boolean;
  LogCaret: TPoint;
  Flags: TJumpToCodePosFlags;
begin
  ActiveSrcEdit:=nil;
  if not BeginCodeTool(ActiveSrcEdit,ActiveUnitInfo,[]) then exit;
  {$IFDEF IDE_DEBUG}
  debugln('');
  debugln('[TMainIDE.DoJumpToProcedureSection] ************');
  {$ENDIF}
  LogCaret:=ActiveSrcEdit.EditorComponent.LogicalCaretXY;
  if CodeToolBoss.JumpToMethod(ActiveUnitInfo.Source,
    LogCaret.X,LogCaret.Y,NewSource,NewX,NewY,NewTopLine,RevertableJump) then
  begin
    Flags := [jfFocusEditor];
    if not RevertableJump then include(Flags, jfAddJumpPoint);
    DoJumpToCodePosition(ActiveSrcEdit, ActiveUnitInfo,
      NewSource, NewX, NewY, NewTopLine, Flags);
  end else begin
    DoJumpToCodeToolBossError;
  end;
end;

procedure TMainIDE.DoJumpToCodeToolBossError;
var
  ActiveSrcEdit:TSourceEditor;
  ErrorCaret: TPoint;
  OpenFlags: TOpenFlags;
  ErrorFilename: string;
  ErrorTopLine: integer;
  AnUnitInfo: TUnitInfo;
  AnEditorInfo: TUnitEditorInfo;
  Msg: TMessageLine;
begin
  if (Screen.GetCurrentModalForm<>nil) or (CodeToolBoss.ErrorMessage='') then
  begin
    SourceFileMgr.UpdateSourceNames;
    debugln('TMainIDE.DoJumpToCodeToolBossError No errormessage');
    exit;
  end;
  // syntax error -> show error and jump
  // show error in message view
  SourceFileMgr.ArrangeSourceEditorAndMessageView(false);
  MessagesView.ClearCustomMessages;
  if CodeToolBoss.ErrorCode<>nil then begin
    Msg:=MessagesView.AddCustomMessage(mluError,CodeToolBoss.ErrorMessage,
      CodeToolBoss.ErrorCode.Filename,CodeToolBoss.ErrorLine,CodeToolBoss.ErrorColumn,
      'Codetools');
    Msg.Flags:=Msg.Flags+[mlfLeftToken];
  end else
    MessagesView.AddCustomMessage(mluError,CodeToolBoss.ErrorMessage,'Codetools');

  // jump to error in source editor
  if CodeToolBoss.ErrorCode<>nil then begin
    ErrorCaret:=Point(Max(1,CodeToolBoss.ErrorColumn),Max(1,CodeToolBoss.ErrorLine));
    ErrorFilename:=CodeToolBoss.ErrorCode.Filename;
    ErrorTopLine:=CodeToolBoss.ErrorTopLine;
    SourceEditorManager.AddJumpPointClicked(Self);
    OpenFlags:=[ofOnlyIfExists,ofUseCache];
    if CodeToolBoss.ErrorCode.IsVirtual then
      Include(OpenFlags,ofVirtualFile);

    AnUnitInfo := Project1.UnitInfoWithFilename(ErrorFilename);
    AnEditorInfo := nil;
    ActiveSrcEdit := nil;
    if AnUnitInfo <> nil then
      AnEditorInfo := GetAvailableUnitEditorInfo(AnUnitInfo, ErrorCaret);
    if AnEditorInfo <> nil then begin
      ActiveSrcEdit := TSourceEditor(AnEditorInfo.EditorComponent);
      SourceEditorManager.ActiveEditor := ActiveSrcEdit;
    end else begin
      if DoOpenEditorFile(ErrorFilename,-1,-1,OpenFlags)=mrOk then
        ActiveSrcEdit:=SourceEditorManager.ActiveEditor;
    end;
    if ActiveSrcEdit<> nil then begin
      IDEWindowCreators.ShowForm(MessagesView,true);
      with ActiveSrcEdit.EditorComponent do begin
        LogicalCaretXY:=ErrorCaret;
        if ErrorTopLine>0 then
          TopLine:=ErrorTopLine;
      end;
      SourceEditorManager.ShowActiveWindowOnTop(True);
      SourceEditorManager.ClearErrorLines;
      ActiveSrcEdit.ErrorLine:=ErrorCaret.Y;
    end;
  end;
  SourceFileMgr.UpdateSourceNames;
end;

procedure TMainIDE.DoFindDeclarationAtCursor;
var
  ActiveSrcEdit: TSourceEditor;
  ActiveUnitInfo: TUnitInfo;
begin
  GetCurrentUnit(ActiveSrcEdit,ActiveUnitInfo);
  if ActiveSrcEdit=nil then exit;
  //debugln(['TMainIDE.DoFindDeclarationAtCursor ',ActiveSrcEdit.Filename,' ',GetParentForm(ActiveSrcEdit.EditorComponent).Name]);
  DoFindDeclarationAtCaret(ActiveSrcEdit.EditorComponent.LogicalCaretXY);
end;

procedure TMainIDE.DoFindDeclarationAtCaret(const LogCaretXY: TPoint);
var
  ActiveSrcEdit: TSourceEditor;
  ActiveUnitInfo: TUnitInfo;
  NewSource: TCodeBuffer;
  NewX, NewY, NewTopLine: integer;
  FindFlags: TFindSmartFlags;
begin
  ActiveSrcEdit:=nil;
  if not BeginCodeTool(ActiveSrcEdit,ActiveUnitInfo,[]) then exit;
  {$IFDEF IDE_DEBUG}
  debugln('');
  debugln('[TMainIDE.DoFindDeclarationAtCaret] ************');
  {$ENDIF}
  {$IFDEF IDE_MEM_CHECK}CheckHeapWrtMemCnt('TMainIDE.DoFindDeclarationAtCaret A');{$ENDIF}
  //DebugLn(['TMainIDE.DoFindDeclarationAtCaret LogCaretXY=',dbgs(LogCaretXY),' SynEdit.Log=',dbgs(ActiveSrcEdit.EditorComponent.LogicalCaretXY),' SynEdit.Caret=',dbgs(ActiveSrcEdit.EditorComponent.CaretXY)]);
  FindFlags := DefaultFindSmartFlags;
  if CodeToolsOpts.SkipForwardDeclarations then
    Include(FindFlags, fsfSkipClassForward);
  if CodeToolBoss.FindDeclaration(ActiveUnitInfo.Source,
    LogCaretXY.X, LogCaretXY.Y, NewSource, NewX, NewY, NewTopLine, FindFlags )
  then begin
    //debugln(['TMainIDE.DoFindDeclarationAtCaret ',NewSource.Filename,' NewX=',Newx,',y=',NewY,' ',NewTopLine]);
    DoJumpToCodePosition(ActiveSrcEdit, ActiveUnitInfo,
      NewSource, NewX, NewY, NewTopLine, [jfAddJumpPoint, jfFocusEditor]);
  end else begin
    DoJumpToCodeToolBossError;
  end;
  {$IFDEF IDE_MEM_CHECK}CheckHeapWrtMemCnt('TMainIDE.DoFindDeclarationAtCaret B');{$ENDIF}
end;

function TMainIDE.DoFindRenameIdentifier(Rename: boolean): TModalResult;
var
  Options: TFindRenameIdentifierOptions;

  // TODO: replace Files: TStringsList with a AVL tree

  function AddExtraFiles(Files: TStrings): TModalResult;
  var
    i: Integer;
    CurFileMask: string;
    FileInfo: TSearchRec;
    CurDirectory: String;
    CurFilename: String;
    OnlyPascalSources: Boolean;
  begin
    Result:=mrCancel;
    if (Options.ExtraFiles<>nil) then begin
      for i:=0 to Options.ExtraFiles.Count-1 do begin
        CurFileMask:=Options.ExtraFiles[i];
        if not GlobalMacroList.SubstituteStr(CurFileMask) then exit;
        CurFileMask:=ChompPathDelim(CurFileMask);
        if not FilenameIsAbsolute(CurFileMask) then begin
          if Project1.IsVirtual then continue;
          CurFileMask:=AppendPathDelim(Project1.ProjectDirectory+CurFileMask);
        end;
        CurFileMask:=TrimFilename(CurFileMask);
        OnlyPascalSources:=false;
        if DirPathExistsCached(CurFileMask) then begin
          // a whole directory
          OnlyPascalSources:=true;
          CurFileMask:=AppendPathDelim(CurFileMask)+GetAllFilesMask;
        end else if FileExistsCached(CurFileMask) then begin
          // single file
          Files.Add(CurFileMask);
          continue;
        end else begin
          // a mask
        end;
        if FindFirstUTF8(CurFileMask,faAnyFile,FileInfo)=0
        then begin
          CurDirectory:=AppendPathDelim(ExtractFilePath(CurFileMask));
          repeat
            // check if special file
            if (FileInfo.Name='.') or (FileInfo.Name='..') or (FileInfo.Name='')
            then
              continue;
            if OnlyPascalSources and not FilenameIsPascalSource(FileInfo.Name)
            then
              continue;
            CurFilename:=CurDirectory+FileInfo.Name;
            //debugln(['AddExtraFiles ',CurFilename]);
            if FileIsText(CurFilename) then
              Files.Add(CurFilename);
          until FindNextUTF8(FileInfo)<>0;
        end;
        FindCloseUTF8(FileInfo);
      end;
    end;
    Result:=mrOk;
  end;

var
  TargetSrcEdit, DeclarationSrcEdit: TSourceEditor;
  TargetUnitInfo, DeclarationUnitInfo: TUnitInfo;
  NewSource: TCodeBuffer;
  NewX, NewY, NewTopLine: integer;
  LogCaretXY, DeclarationCaretXY: TPoint;
  OwnerList: TFPList;
  ExtraFiles: TStrings;
  Files: TStringList;
  Identifier: string;
  PascalReferences: TAVLTree;
  ListOfLazFPDocNode: TFPList;
  CurUnitname: String;
  OldChange: Boolean;
begin
  Result:=mrCancel;
  TargetSrcEdit:=nil;
  if not BeginCodeTool(TargetSrcEdit,TargetUnitInfo,[]) then exit;

  // find the main declaration
  LogCaretXY:=TargetSrcEdit.EditorComponent.LogicalCaretXY;
  if not CodeToolBoss.FindMainDeclaration(TargetUnitInfo.Source,
    LogCaretXY.X,LogCaretXY.Y,
    NewSource,NewX,NewY,NewTopLine) then
  begin
    DoJumpToCodeToolBossError;
    exit;
  end;
  DoJumpToCodePosition(TargetSrcEdit, TargetUnitInfo,
    NewSource, NewX, NewY, NewTopLine, [jfFocusEditor]);
  CodeToolBoss.GetIdentifierAt(NewSource,NewX,NewY,Identifier);
  CurUnitname:=ExtractFileNameOnly(NewSource.Filename);

  GetCurrentUnit(DeclarationSrcEdit,DeclarationUnitInfo);
  DeclarationCaretXY:=DeclarationSrcEdit.EditorComponent.LogicalCaretXY;
  //debugln('TMainIDE.DoFindRenameIdentifier A DeclarationCaretXY=x=',dbgs(DeclarationCaretXY.X),' y=',dbgs(DeclarationCaretXY.Y));

  Files:=nil;
  OwnerList:=nil;
  PascalReferences:=nil;
  ListOfLazFPDocNode:=nil;
  try
    // let user choose the search scope
    Result:=ShowFindRenameIdentifierDialog(DeclarationUnitInfo.Source.Filename,
      DeclarationCaretXY,true,Rename,nil);
    if Result<>mrOk then begin
      debugln('TMainIDE.DoFindRenameIdentifier failed: user cancelled dialog');
      exit;
    end;

    // create the file list
    Files:=TStringList.Create;
    Files.Add(TargetUnitInfo.Filename);
    if CompareFilenames(DeclarationUnitInfo.Filename,TargetUnitInfo.Filename)<>0 then
      Files.Add(DeclarationUnitInfo.Filename);

    Options:=MiscellaneousOptions.FindRenameIdentifierOptions;

    // add packages, projects
    case Options.Scope of
    frProject:
      begin
        OwnerList:=TFPList.Create;
        OwnerList.Add(Project1);
      end;
    frOwnerProjectPackage,frAllOpenProjectsAndPackages:
      begin
        OwnerList:=PkgBoss.GetOwnersOfUnit(TargetUnitInfo.Filename);
        if (OwnerList<>nil)
        and (Options.Scope=frAllOpenProjectsAndPackages) then begin
          PkgBoss.ExtendOwnerListWithUsedByOwners(OwnerList);
          ReverseList(OwnerList);
        end;
      end;
    end;

    // get source files of packages and projects
    if OwnerList<>nil then begin
      ExtraFiles:=PkgBoss.GetSourceFilesOfOwners(OwnerList);
      try
        if ExtraFiles<>nil then
          Files.AddStrings(ExtraFiles);
      finally
        ExtraFiles.Free;
      end;
    end;

    // add user defined extra files
    Result:=AddExtraFiles(Files);
    if Result<>mrOk then begin
      debugln('TMainIDE.DoFindRenameIdentifier unable to add user defined extra files');
      exit;
    end;

    // search pascal source references
    Result:=GatherIdentifierReferences(Files,DeclarationUnitInfo.Source,
      DeclarationCaretXY,Options.SearchInComments,PascalReferences);
    if CodeToolBoss.ErrorMessage<>'' then
      DoJumpToCodeToolBossError;
    if Result<>mrOk then begin
      debugln('TMainIDE.DoFindRenameIdentifier GatherIdentifierReferences failed');
      exit;
    end;

    {$IFDEF EnableFPDocRename}
    // search fpdoc references
    Result:=GatherFPDocReferencesForPascalFiles(Files,DeclarationUnitInfo.Source,
                                  DeclarationCaretXY,ListOfLazFPDocNode);
    if Result<>mrOk then begin
      debugln('TMainIDE.DoFindRenameIdentifier GatherFPDocReferences failed');
      exit;
    end;
    {$ENDIF}

    // ToDo: search lfm source references
    // ToDo: search i18n references
    // ToDo: designer references

    // rename identifier
    if Options.Rename then begin
      if CompareIdentifiers(PChar(Identifier),PChar(CurUnitName))=0 then
      begin
        IDEMessageDialog(srkmecRenameIdentifier,
          lisTheIdentifierIsAUnitPleaseUseTheFileSaveAsFunction,
          mtInformation,[mbCancel],'');
        exit(mrCancel);
      end;
      OldChange:=OpenEditorsOnCodeToolChange;
      OpenEditorsOnCodeToolChange:=true;
      try
        if not CodeToolBoss.RenameIdentifier(PascalReferences,
          Identifier,Options.RenameTo, DeclarationUnitInfo.Source, @DeclarationCaretXY)
        then begin
          DoJumpToCodeToolBossError;
          debugln('TMainIDE.DoFindRenameIdentifier unable to commit');
          Result:=mrCancel;
          exit;
        end;
      finally
        OpenEditorsOnCodeToolChange:=OldChange;
      end;
      if Options.RenameShowResult then
        Result:=ShowIdentifierReferences(DeclarationUnitInfo.Source,
          DeclarationCaretXY,PascalReferences);
    end;

    // show result
    if (not Options.Rename) or (not Rename) then begin
      Result:=ShowIdentifierReferences(DeclarationUnitInfo.Source,
        DeclarationCaretXY,PascalReferences);
      if Result<>mrOk then exit;
    end;

  finally
    Files.Free;
    OwnerList.Free;
    CodeToolBoss.FreeTreeOfPCodeXYPosition(PascalReferences);
    FreeListObjects(ListOfLazFPDocNode,true);

    // jump back in source editor
    DoJumpToCodePosition(TargetSrcEdit, TargetUnitInfo,
      TargetUnitInfo.Source, LogCaretXY.X, LogCaretXY.Y, -1, [jfFocusEditor]);
  end;
end;

function TMainIDE.DoFindUsedUnitReferences: boolean;
var
  SrcEdit: TSourceEditor;
  AnUnitInfo: TUnitInfo;
  LogCaretXY: Classes.TPoint;
  ListOfPCodeXYPosition: TFPList;
  UsedUnitFilename: string;
  SearchPageIndex: TTabSheet;
  OldSearchPageIndex: TTabSheet;
  i: Integer;
  CodePos: PCodeXYPosition;
  CurLine: String;
  TrimmedLine: String;
  TrimCnt: Integer;
  Identifier: String;
begin
  Result:=false;
  SrcEdit:=nil;
  if not BeginCodeTool(SrcEdit,AnUnitInfo,[]) then exit;

  ListOfPCodeXYPosition:=nil;
  try
    LogCaretXY:=SrcEdit.EditorComponent.LogicalCaretXY;
    if not CodeToolBoss.FindUsedUnitReferences(AnUnitInfo.Source,
      LogCaretXY.X,LogCaretXY.Y,true,UsedUnitFilename,ListOfPCodeXYPosition) then
    begin
      DoJumpToCodeToolBossError;
      exit;
    end;

    LazarusIDE.DoShowSearchResultsView(iwgfShow);
    // create a search result page
    //debugln(['ShowIdentifierReferences ',DbgSName(SearchResultsView)]);
    SearchPageIndex:=SearchResultsView.AddSearch(
      'Ref: '+ExtractFileName(UsedUnitFilename),
      UsedUnitFilename,
      '',
      ExtractFilePath(UsedUnitFilename),
      '*.pas;*.pp;*.p',
      [fifWholeWord,fifSearchDirectories]);
    if SearchPageIndex = nil then exit;

    // list results
    SearchResultsView.BeginUpdate(SearchPageIndex.PageIndex);
    for i:=0 to ListOfPCodeXYPosition.Count-1 do begin
      CodePos:=PCodeXYPosition(ListOfPCodeXYPosition[i]);
      CurLine:=TrimRight(CodePos^.Code.GetLine(CodePos^.Y-1,false));
      if CodePos^.X<=length(CurLine) then
        Identifier:=GetIdentifier(@CurLine[CodePos^.X])
      else
        Identifier:='';
      TrimmedLine:=Trim(CurLine);
      TrimCnt:=length(CurLine)-length(TrimmedLine);
      //debugln('DoFindUsedUnitReferences x=',dbgs(CodePos^.x),' y=',dbgs(CodePos^.y),' ',CurLine);
      SearchResultsView.AddMatch(SearchPageIndex.PageIndex,
                                 CodePos^.Code.Filename,
                                 Point(CodePos^.X,CodePos^.Y),
                                 Point(CodePos^.X+length(Identifier),CodePos^.Y),
                                 TrimmedLine,
                                 CodePos^.X-TrimCnt, length(Identifier));
    end;

    OldSearchPageIndex:=SearchPageIndex;
    SearchPageIndex:=nil;
    SearchResultsView.EndUpdate(OldSearchPageIndex.PageIndex);
    IDEWindowCreators.ShowForm(SearchResultsView,true);

  finally
    FreeListOfPCodeXYPosition(ListOfPCodeXYPosition);
  end;
end;

function TMainIDE.DoShowAbstractMethods: TModalResult;
begin
  Result:=ShowAbstractMethodsDialog;
end;

function TMainIDE.DoRemoveEmptyMethods: TModalResult;
begin
  Result:=ShowEmptyMethodsDialog;
end;

function TMainIDE.DoRemoveUnusedUnits: TModalResult;
begin
  Result:=ShowUnusedUnitsDialog;
end;

function TMainIDE.DoUseUnit: TModalResult;
begin
  Result:=ShowUseUnitDialog;
end;

function TMainIDE.DoFindOverloads: TModalResult;
begin
  Result:=ShowFindOverloadsDialog;
end;

function TMainIDE.DoInitIdentCompletion(JumpToError: boolean): boolean;
var
  ActiveSrcEdit: TSourceEditor;
  ActiveUnitInfo: TUnitInfo;
  LogCaretXY: TPoint;
begin
  ActiveSrcEdit:=nil;
  if not BeginCodeTool(ActiveSrcEdit,ActiveUnitInfo,[]) then exit(false);
  {$IFDEF IDE_DEBUG}
  debugln('');
  debugln('[TMainIDE.DoInitIdentCompletion] ************');
  {$ENDIF}
  {$IFDEF IDE_MEM_CHECK}CheckHeapWrtMemCnt('TMainIDE.DoInitIdentCompletion A');{$ENDIF}
  LogCaretXY:=ActiveSrcEdit.EditorComponent.LogicalCaretXY;
  Result:=CodeToolBoss.GatherIdentifiers(ActiveUnitInfo.Source,
                                         LogCaretXY.X,LogCaretXY.Y);
  if not Result then begin
    if JumpToError then
      DoJumpToCodeToolBossError;
    exit;
  end;
  {$IFDEF IDE_MEM_CHECK}CheckHeapWrtMemCnt('TMainIDE.DoInitIdentCompletion B');{$ENDIF}
end;

function TMainIDE.DoShowCodeContext(JumpToError: boolean): boolean;
var
  ActiveSrcEdit: TSourceEditor;
  ActiveUnitInfo: TUnitInfo;
begin
  ActiveSrcEdit:=nil;
  if not BeginCodeTool(ActiveSrcEdit,ActiveUnitInfo,[]) then exit(false);
  {$IFDEF IDE_DEBUG}
  debugln('');
  debugln('[TMainIDE.DoShowCodeContext] ************');
  {$ENDIF}
  {$IFDEF IDE_MEM_CHECK}CheckHeapWrtMemCnt('TMainIDE.DoShowCodeContext A');{$ENDIF}
  Result:=ShowCodeContext(ActiveUnitInfo.Source);
  if not Result then begin
    if JumpToError then
      DoJumpToCodeToolBossError;
    exit;
  end;
  {$IFDEF IDE_MEM_CHECK}CheckHeapWrtMemCnt('TMainIDE.DoShowCodeContext B');{$ENDIF}
end;

procedure TMainIDE.DoGoToPascalBlockOtherEnd;
var ActiveSrcEdit: TSourceEditor;
  ActiveUnitInfo: TUnitInfo;
  NewSource: TCodeBuffer;
  NewX, NewY, NewTopLine: integer;
begin
  ActiveSrcEdit:=nil;
  if not BeginCodeTool(ActiveSrcEdit,ActiveUnitInfo,[]) then exit;
  {$IFDEF IDE_DEBUG}
  debugln('');
  debugln('[TMainIDE.DoGoToPascalBlockOtherEnd] ************');
  {$ENDIF}
  if CodeToolBoss.FindBlockCounterPart(ActiveUnitInfo.Source,
    ActiveSrcEdit.EditorComponent.CaretX,
    ActiveSrcEdit.EditorComponent.CaretY,
    NewSource,NewX,NewY,NewTopLine) then
  begin
    DoJumpToCodePosition(ActiveSrcEdit, ActiveUnitInfo,
      NewSource, NewX, NewY, NewTopLine, [jfFocusEditor]);
  end else
    DoJumpToCodeToolBossError;
end;

procedure TMainIDE.DoGoToPascalBlockStart;
var ActiveSrcEdit: TSourceEditor;
  ActiveUnitInfo: TUnitInfo;
  NewSource: TCodeBuffer;
  NewX, NewY, NewTopLine: integer;
  Flags: TJumpToCodePosFlags;
begin
  ActiveSrcEdit:=nil;
  if not BeginCodeTool(ActiveSrcEdit,ActiveUnitInfo,[]) then exit;
  {$IFDEF IDE_DEBUG}
  debugln('');
  debugln('[TMainIDE.DoGoToPascalBlockStart] ************');
  {$ENDIF}
  if CodeToolBoss.FindBlockStart(ActiveUnitInfo.Source,
    ActiveSrcEdit.EditorComponent.CaretX,
    ActiveSrcEdit.EditorComponent.CaretY,
    NewSource,NewX,NewY,NewTopLine,true) then
  begin
    Flags:=[jfFocusEditor];
    if (ActiveSrcEdit.EditorComponent.CaretY<>NewY)
    or (Abs(ActiveSrcEdit.EditorComponent.CaretX-NewX)>10)
    then
      Include(Flags,jfAddJumpPoint);
    DoJumpToCodePosition(ActiveSrcEdit, ActiveUnitInfo,
      NewSource, NewX, NewY, NewTopLine, Flags);
  end else
    DoJumpToCodeToolBossError;
end;

procedure TMainIDE.DoJumpToGuessedUnclosedBlock(FindNextUTF8: boolean);
var ActiveSrcEdit: TSourceEditor;
  ActiveUnitInfo: TUnitInfo;
  NewSource: TCodeBuffer;
  StartX, StartY, NewX, NewY, NewTopLine: integer;
begin
  ActiveSrcEdit:=nil;
  if not BeginCodeTool(ActiveSrcEdit,ActiveUnitInfo,[]) then exit;
  {$IFDEF IDE_DEBUG}
  debugln('');
  debugln('[TMainIDE.DoJumpToGuessedUnclosedBlock] ************');
  {$ENDIF}
  if FindNextUTF8 then begin
    StartX:=ActiveSrcEdit.EditorComponent.CaretX;
    StartY:=ActiveSrcEdit.EditorComponent.CaretY;
  end else begin
    StartX:=1;
    StartY:=1;
  end;
  if CodeToolBoss.GuessUnclosedBlock(ActiveUnitInfo.Source,
    StartX,StartY,NewSource,NewX,NewY,NewTopLine) then
  begin
    DoJumpToCodePosition(ActiveSrcEdit, ActiveUnitInfo,
      NewSource, NewX, NewY, NewTopLine, [jfAddJumpPoint, jfFocusEditor]);
  end else begin
    if CodeToolBoss.ErrorMessage='' then begin
      IDEMessageDialog(lisSuccess, lisAllBlocksLooksOk, mtInformation, [mbOk]);
    end else
      DoJumpToCodeToolBossError;
  end;
end;

procedure TMainIDE.DoJumpToGuessedMisplacedIFDEF(FindNextUTF8: boolean);
var ActiveSrcEdit: TSourceEditor;
  ActiveUnitInfo: TUnitInfo;
  NewSource: TCodeBuffer;
  StartX, StartY, NewX, NewY, NewTopLine: integer;
begin
  ActiveSrcEdit:=nil;
  if not BeginCodeTool(ActiveSrcEdit,ActiveUnitInfo,[]) then exit;
  {$IFDEF IDE_DEBUG}
  debugln('');
  debugln('[TMainIDE.DoJumpToGuessedMisplacedIFDEF] ************');
  {$ENDIF}
  if FindNextUTF8 then begin
    StartX:=ActiveSrcEdit.EditorComponent.CaretX;
    StartY:=ActiveSrcEdit.EditorComponent.CaretY;
  end else begin
    StartX:=1;
    StartY:=1;
  end;
  if CodeToolBoss.GuessMisplacedIfdefEndif(ActiveUnitInfo.Source,
    StartX,StartY,NewSource,NewX,NewY,NewTopLine) then
  begin
    DoJumpToCodePosition(ActiveSrcEdit, ActiveUnitInfo,
      NewSource, NewX, NewY, NewTopLine, [jfAddJumpPoint, jfFocusEditor]);
  end else
    DoJumpToCodeToolBossError;
end;

procedure TMainIDE.DoGotoIncludeDirective;
var ActiveSrcEdit: TSourceEditor;
  ActiveUnitInfo: TUnitInfo;
  NewSource: TCodeBuffer;
  NewX, NewY, NewTopLine: integer;
begin
  ActiveSrcEdit:=nil;
  if not BeginCodeTool(ActiveSrcEdit,ActiveUnitInfo,[]) then exit;
  {$IFDEF IDE_DEBUG}
  debugln('');
  debugln('[TMainIDE.DoGotoIncludeDirective] ************');
  {$ENDIF}
  if CodeToolBoss.FindEnclosingIncludeDirective(ActiveUnitInfo.Source,
    ActiveSrcEdit.EditorComponent.CaretX,
    ActiveSrcEdit.EditorComponent.CaretY,
    NewSource,NewX,NewY,NewTopLine) then
  begin
    DoJumpToCodePosition(ActiveSrcEdit, ActiveUnitInfo,
      NewSource, NewX, NewY, NewTopLine, [jfFocusEditor]);
  end else
    DoJumpToCodeToolBossError;
end;

function TMainIDE.DoMakeResourceString: TModalResult;
var
  ActiveSrcEdit: TSourceEditor;
  ActiveUnitInfo: TUnitInfo;
  StartPos, EndPos: TPoint;
  StartCode, EndCode: TCodeBuffer;
  NewIdentifier, NewIdentValue: string;
  NewSourceLines: string;
  InsertPolicy: TResourcestringInsertPolicy;
  SectionCode: TCodeBuffer;
  SectionCaretXY: TPoint;
  DummyResult: Boolean;
  SelectedStartPos: TPoint;
  SelectedEndPos: TPoint;
  CursorCode: TCodeBuffer;
  CursorXY: TPoint;
  OldChange: Boolean;
begin
  OldChange:=OpenEditorsOnCodeToolChange;
  OpenEditorsOnCodeToolChange:=true;
  try
    Result:=mrCancel;
    ActiveSrcEdit:=nil;
    if not BeginCodeTool(ActiveSrcEdit,ActiveUnitInfo,[]) then exit;
    {$IFDEF IDE_DEBUG}
    debugln('');
    debugln('[TMainIDE.DoMakeResourceString] ************');
    {$ENDIF}
    // calculate start and end of expression in source
    CursorCode:=ActiveUnitInfo.Source;
    if ActiveSrcEdit.EditorComponent.SelAvail then
      CursorXY:=ActiveSrcEdit.EditorComponent.BlockBegin
    else
      CursorXY:=ActiveSrcEdit.EditorComponent.LogicalCaretXY;
    if not CodeToolBoss.GetStringConstBounds(
      CursorCode,CursorXY.X,CursorXY.Y,
      StartCode,StartPos.X,StartPos.Y,
      EndCode,EndPos.X,EndPos.Y,true) then
    begin
      DoJumpToCodeToolBossError;
      exit;
    end;

    // the codetools have calculated the maximum bounds
    if (StartCode=EndCode) and (CompareCaret(StartPos,EndPos)=0) then begin
      IDEMessageDialog(lisNoStringConstantFound,
      Format(lisHintTheMakeResourcestringFunctionExpectsAStringCon, [LineEnding]),
      mtError,[mbCancel]);
      exit;
    end;
    // the user can shorten this range by selecting text
    if (ActiveSrcEdit.EditorComponent.SelText='') then begin
      // the user has not selected text
      // -> check if the string constant is in single file
      // (replacing code that contains an $include directive is ambiguous)
      //debugln('TMainIDE.DoMakeResourceString user has not selected text');
      if (StartCode<>ActiveUnitInfo.Source)
      or (EndCode<>ActiveUnitInfo.Source)
      then begin
        IDEMessageDialog(lisNoStringConstantFound, Format(
          lisInvalidExpressionHintTheMakeResourcestringFunction, [LineEnding]),
        mtError,[mbCancel]);
        exit;
      end;
    end else begin
      // the user has selected text
      // -> check if the selection is only part of the maximum bounds
      SelectedStartPos:=ActiveSrcEdit.EditorComponent.BlockBegin;
      SelectedEndPos:=ActiveSrcEdit.EditorComponent.BlockEnd;
      CodeToolBoss.ImproveStringConstantStart(
                      ActiveSrcEdit.EditorComponent.Lines[SelectedStartPos.Y-1],
                      SelectedStartPos.X);
      CodeToolBoss.ImproveStringConstantEnd(
                        ActiveSrcEdit.EditorComponent.Lines[SelectedEndPos.Y-1],
                        SelectedEndPos.X);
      //debugln('TMainIDE.DoMakeResourceString user has selected text: Selected=',dbgs(SelectedStartPos),'-',dbgs(SelectedEndPos),' Maximum=',dbgs(StartPos),'-',dbgs(EndPos));
      if (CompareCaret(SelectedStartPos,StartPos)>0)
      or (CompareCaret(SelectedEndPos,EndPos)<0)
      then begin
        IDEMessageDialog(lisSelectionExceedsStringConstant,
        Format(lisHintTheMakeResourcestringFunctionExpectsAStringCon, [LineEnding]),
        mtError,[mbCancel]);
        exit;
      end;
      StartPos:=SelectedStartPos;
      EndPos:=SelectedEndPos;
    end;

    // gather all reachable resourcestring sections
    //debugln('TMainIDE.DoMakeResourceString gather all reachable resourcestring sections ...');
    if not CodeToolBoss.GatherResourceStringSections(
      CursorCode,CursorXY.X,CursorXY.Y,nil)
    then begin
      DoJumpToCodeToolBossError;
      exit;
    end;
    if CodeToolBoss.Positions.Count=0 then begin
      IDEMessageDialog(lisNoResourceStringSectionFound,
        lisUnableToFindAResourceStringSectionInThisOrAnyOfThe,
        mtError,[mbCancel]);
      exit;
    end;

    // show make resourcestring dialog
    Result:=ShowMakeResStrDialog(StartPos,EndPos,StartCode,
                                 CodeToolBoss.Positions,
                                 NewIdentifier,NewIdentValue,NewSourceLines,
                                 SectionCode,SectionCaretXY,InsertPolicy);
    if (Result<>mrOk) then exit;

    // replace source
    ActiveSrcEdit.ReplaceLines(StartPos.Y,EndPos.Y,NewSourceLines);

    // add new resourcestring to resourcestring section
    if (InsertPolicy<>rsipNone) then
      DummyResult:=CodeToolBoss.AddResourcestring(
                       CursorCode,CursorXY.X,CursorXY.Y,
                       SectionCode,SectionCaretXY.X,SectionCaretXY.Y,
                       NewIdentifier,''''+NewIdentValue+'''',InsertPolicy)
    else
      DummyResult:=true;
    ApplyCodeToolChanges;
    if not DummyResult then begin
      DoJumpToCodeToolBossError;
      exit;
    end;

    // switch back to source
    ActiveSrcEdit.Activate;
    ActiveSrcEdit.EditorComponent.SetFocus;

    Result:=mrOk;
  finally
    OpenEditorsOnCodeToolChange:=OldChange;
  end;
end;

function TMainIDE.DoDiff: TModalResult;
var
  ActiveSrcEdit: TSourceEditor;
  ActiveUnitInfo: TUnitInfo;
  DiffText: string;
  NewDiffFilename: String;
begin
  Result:=mrCancel;
  GetCurrentUnit(ActiveSrcEdit,ActiveUnitInfo);
  if ActiveSrcEdit=nil then exit;

  Result:=ShowDiffDialog(ActiveSrcEdit.PageIndex, DiffText);
  if Result = mrYes then begin
    NewDiffFilename:=CreateSrcEditPageName('','FileDifference.diff', nil);
    Result:=DoNewEditorFile(FileDescriptorText,NewDiffFilename,DiffText,
                            [nfOpenInEditor,nfIsNotPartOfProject]);
    GetCurrentUnit(ActiveSrcEdit,ActiveUnitInfo);
    if ActiveSrcEdit=nil then exit;
  end;
end;

function TMainIDE.DoFindInFiles: TModalResult;
begin
  Result:=mrOk;
  FindInFilesDialog.FindInFilesPerDialog(Project1);
end;

procedure TMainIDE.DoCompleteCodeAtCursor;
var
  ActiveSrcEdit: TSourceEditor;
  ActiveUnitInfo: TUnitInfo;
  NewSource: TCodeBuffer;
  NewX, NewY, NewTopLine: integer;
  OldChange: Boolean;
begin
  OldChange:=OpenEditorsOnCodeToolChange;
  OpenEditorsOnCodeToolChange:=true;
  try
    ActiveSrcEdit:=nil;
    if not BeginCodeTool(ActiveSrcEdit,ActiveUnitInfo,[]) then exit;
    {$IFDEF IDE_DEBUG}
    debugln('');
    debugln('[TMainIDE.DoCompleteCodeAtCursor] ************');
    {$ENDIF}
    CodeToolBoss.CompleteCode(ActiveUnitInfo.Source,
      ActiveSrcEdit.EditorComponent.CaretX,
      ActiveSrcEdit.EditorComponent.CaretY,
      ActiveSrcEdit.EditorComponent.TopLine,
      NewSource,NewX,NewY,NewTopLine);
    if (CodeToolBoss.ErrorMessage='')
    and (CodeToolBoss.SourceChangeCache.BuffersToModifyCount=0) then
      CodeToolBoss.SetError(nil,0,0,'there is no completion for this code');
    ApplyCodeToolChanges;
    if (CodeToolBoss.ErrorMessage='') and (NewSource<>nil) then
      DoJumpToCodePosition(ActiveSrcEdit, ActiveUnitInfo,
        NewSource, NewX, NewY, NewTopLine, [jfAddJumpPoint, jfFocusEditor])
    else
      DoJumpToCodeToolBossError;
  finally
    OpenEditorsOnCodeToolChange:=OldChange;
  end;
end;

procedure TMainIDE.DoExtractProcFromSelection;
var
  ActiveSrcEdit: TSourceEditor;
  ActiveUnitInfo: TUnitInfo;
  BlockBegin: TPoint;
  BlockEnd: TPoint;
  NewSource: TCodeBuffer;
  NewX, NewY, NewTopLine: integer;
  CTResult: boolean;
  OldChange: Boolean;
begin
  ActiveSrcEdit:=nil;
  if not BeginCodeTool(ActiveSrcEdit,ActiveUnitInfo,[]) then exit;
  {$IFDEF IDE_DEBUG}
  debugln('');
  debugln('[TMainIDE.DoExtractProcFromSelection] ************');
  {$ENDIF}
  BlockBegin:=ActiveSrcEdit.EditorComponent.BlockBegin;
  BlockEnd:=ActiveSrcEdit.EditorComponent.BlockEnd;

  OldChange:=OpenEditorsOnCodeToolChange;
  OpenEditorsOnCodeToolChange:=true;
  try
    CTResult:=ShowExtractProcDialog(ActiveUnitInfo.Source,BlockBegin,BlockEnd,
      NewSource,NewX,NewY,NewTopLine)=mrOk;
    ApplyCodeToolChanges;
    if CodeToolBoss.ErrorMessage<>'' then begin
      DoJumpToCodeToolBossError;
    end else if CTResult then begin
      DoJumpToCodePosition(ActiveSrcEdit,ActiveUnitInfo,
        NewSource,NewX,NewY,NewTopLine,[jfAddJumpPoint, jfFocusEditor]);
    end;
  finally
    OpenEditorsOnCodeToolChange:=OldChange;
  end;
end;

//-----------------------------------------------------------------------------

procedure TMainIDE.SearchResultsViewSelectionChanged(sender: TObject);
begin
  DoJumpToSearchResult(True);
end;

procedure TMainIDE.JumpHistoryViewSelectionChanged(sender : TObject);
begin
  SourceEditorManager.HistoryJump(self, jhaViewWindow);
  SourceEditorManager.ShowActiveWindowOnTop(True);
end;

procedure TMainIDE.OnSrcNotebookEditorActived(Sender: TObject);
var
  ActiveUnitInfo: TUnitInfo;
  ASrcEdit: TSourceEditor;
begin
  ASrcEdit := SourceEditorManager.SenderToEditor(Sender);
  if ASrcEdit=nil then exit;

  {$IFDEF VerboseIDEDisplayState}
  debugln(['TMainIDE.OnSrcNotebookEditorActived']);
  {$ENDIF}
  DisplayState:=dsSource;
  Project1.UpdateVisibleUnit(ASrcEdit, ASrcEdit.SourceNotebook.WindowID);

  ActiveUnitInfo := Project1.UnitWithEditorComponent(ASrcEdit);
  if ActiveUnitInfo = nil then Exit;
  ActiveUnitInfo.SetLastUsedEditor(ASrcEdit);

  UpdateSaveMenuItemsAndButtons(false);
  MainIDEBar.itmViewToggleFormUnit.Enabled := Assigned(ActiveUnitInfo.Component)
                                           or (ActiveUnitInfo.ComponentName<>'');
  MainIDEBar.ToggleFormSpeedBtn.Enabled := MainIDEBar.itmViewToggleFormUnit.Enabled;
end;

procedure TMainIDE.OnSrcNotebookEditorPlaceBookmark(Sender: TObject; var Mark: TSynEditMark);
begin
  Project1.UnitWithEditorComponent(TSourceEditor(Sender)).AddBookmark
    (Mark.Column, Mark.Line, Mark.BookmarkNumber);
end;

procedure TMainIDE.OnSrcNotebookEditorClearBookmark(Sender: TObject; var Mark: TSynEditMark);
begin
  Project1.UnitWithEditorComponent(TSourceEditor(Sender)).DeleteBookmark
    (Mark.BookmarkNumber);
end;

procedure TMainIDE.OnSrcNotebookEditorClearBookmarkId(Sender: TObject;
  ID: Integer);
var
  i: Integer;
  UInfo: TUnitInfo;
begin
  if ID = -1 then begin
    for i := 0 to 9 do begin
      //b := Project1.Bookmarks[i];
      UInfo := TUnitInfo(Project1.Bookmarks.UnitInfoForBookmarkWithIndex(i));
      if UInfo <> nil then begin
        if UInfo.OpenEditorInfoCount > 0 then
          TSourceEditor(UInfo.OpenEditorInfo[0].EditorComponent).EditorComponent.ClearBookMark(i)
        else
          UInfo.DeleteBookmark(i);
      end;
    end;
  end
  else begin
    UInfo := TUnitInfo(Project1.Bookmarks.UnitInfoForBookmarkWithIndex(Id));
    if UInfo <> nil then begin
      if UInfo.OpenEditorInfoCount > 0 then
        TSourceEditor(UInfo.OpenEditorInfo[0].EditorComponent).EditorComponent.ClearBookMark(Id)
      else
        UInfo.DeleteBookmark(Id);
    end;
  end;
end;

procedure TMainIDE.OnSrcNotebookEditorDoSetBookmark(Sender: TObject; ID: Integer; Toggle: Boolean);
var
  ActEdit, OldEdit: TSourceEditor;
  Cmd: TIDEMenuCommand;
  OldX, OldY: integer;
  NewXY: TPoint;
  SetMark: Boolean;
  AnUnitInfo: TUnitInfo;
Begin
  if ID < 0 then begin
    ID := 0;
    while (ID <= 9) and (Project1.Bookmarks.BookmarkWithID(ID) <> nil) do
      inc(ID);
    if ID > 9 then exit;
  end;
  ActEdit := Sender as TSourceEditor;
  NewXY := ActEdit.EditorComponent.CaretXY;

  SetMark:=true;
  OldEdit := nil;
  AnUnitInfo := TUnitInfo(Project1.Bookmarks.UnitInfoForBookmarkWithIndex(ID));
  if (AnUnitInfo <> nil) and (AnUnitInfo.OpenEditorInfoCount > 0) then
    OldEdit := TSourceEditor(AnUnitInfo.OpenEditorInfo[0].EditorComponent);
  if (OldEdit<>nil) and OldEdit.EditorComponent.GetBookMark(ID,OldX,OldY) then
  begin
    if (not Toggle) and (OldX=NewXY.X) and (OldY=NewXY.Y) then
      exit;  // no change
    OldEdit.EditorComponent.ClearBookMark(ID);
    if Toggle and (OldY=NewXY.Y) then
      SetMark:=false;
  end;
  if SetMark then
    ActEdit.EditorComponent.SetBookMark(ID,NewXY.X,NewXY.Y);
  Cmd:=SrcEditSubMenuToggleBookmarks[ID] as TIDEMenuCommand;
  Cmd.Checked := SetMark;
end;

procedure TMainIDE.OnSrcNotebookEditorDoGotoBookmark(Sender: TObject; ID: Integer; Backward: Boolean);
var
  CurWin, CurPage, CurLine: Integer;

  function GetWinForEdit(AEd: TSourceEditor): Integer;
  begin
    Result := SourceEditorManager.IndexOfSourceWindow(AEd.SourceNotebook);
    if (not Backward) and
       ( (Result < CurWin) or ((Result = CurWin) and (AEd.PageIndex < CurPage)) )
    then inc(Result, SourceEditorManager.SourceWindowCount);
    if (Backward) and
       ( (Result > CurWin) or ((Result = CurWin) and (AEd.PageIndex > CurPage)) )
    then dec(Result, SourceEditorManager.SourceWindowCount);
  end;

  function GetSrcEdit(AMark: TProjectBookmark): TSourceEditor;
  var
    UInf: TUnitInfo;
    i, j: Integer;
  begin
    if AMark.UnitInfo is TSourceEditor
    then Result := TSourceEditor(AMark.UnitInfo)
    else begin        // find the nearest open View
      UInf := TUnitInfo(AMark.UnitInfo);
      Result := TSourceEditor(UInf.OpenEditorInfo[0].EditorComponent);
      j := 0;
      while (j < UInf.OpenEditorInfoCount) and
            (Result.IsLocked) and (not Result.IsCaretOnScreen(AMark.CursorPos))
      do begin
        inc(j);
        if j < UInf.OpenEditorInfoCount then
          Result := TSourceEditor(UInf.OpenEditorInfo[j].EditorComponent);
      end;
      if j >= UInf.OpenEditorInfoCount then
        exit(nil);
      for i := j + 1 to UInf.OpenEditorInfoCount - 1 do
      begin
        if (not Backward) and
           (GetWinForEdit(Result) > GetWinForEdit(TSourceEditor(UInf.OpenEditorInfo[i].EditorComponent)) )
        then Result := TSourceEditor(UInf.OpenEditorInfo[i].EditorComponent);
        if (Backward) and
           (GetWinForEdit(Result) < GetWinForEdit(TSourceEditor(UInf.OpenEditorInfo[i].EditorComponent)) )
        then Result := TSourceEditor(UInf.OpenEditorInfo[i].EditorComponent);
      end;
    end;
  end;

  function GetWin(AMark: TProjectBookmark): Integer;
  var
    Ed: TSourceEditor;
  begin
    Ed := GetSrcEdit(AMark);
    Result := SourceEditorManager.IndexOfSourceWindow(Ed.SourceNotebook);
    if (not Backward) and (
        (Result < CurWin) or
        ((Result = CurWin) and (Ed.PageIndex < CurPage)) or
        ((Result = CurWin) and (Ed.PageIndex =  CurPage) and (AMark.CursorPos.y < CurLine))
       )
    then
       inc(Result, SourceEditorManager.SourceWindowCount);
    if (Backward) and (
        (Result > CurWin) or
        ((Result = CurWin) and (Ed.PageIndex > CurPage)) or
        ((Result = CurWin) and (Ed.PageIndex =  CurPage) and (AMark.CursorPos.y > CurLine))
       )
    then
       dec(Result, SourceEditorManager.SourceWindowCount);
  end;

  function CompareBookmarkEditorPos(Mark1, Mark2: TProjectBookmark): integer;
  begin
    // ProjectMarks, only exist for UnitInfo with at least one Editor
    Result := GetWin(Mark2) - GetWin(Mark1);
  if Result = 0 then
      Result := GetSrcEdit(Mark2).PageIndex - GetSrcEdit(Mark1).PageIndex;
  if Result = 0 then
      Result := Mark2.CursorPos.y - Mark1.CursorPos.y;
  end;

var
  AnEditor: TSourceEditor;
  i: Integer;
  CurPos, CurFound: TProjectBookmark;
  AnUnitInfo: TUnitInfo;
  AnEditorInfo: TUnitEditorInfo;
  NewXY: TPoint;
begin
  AnEditor := SourceEditorManager.SenderToEditor(Sender);
  if ID < 0 then begin
    // ID < 0  => next/prev
    if Project1.BookMarks.Count = 0 then exit;
    if AnEditor = nil then exit;

    CurWin := SourceEditorManager.IndexOfSourceWindow(AnEditor.SourceNotebook);
    CurPage := AnEditor.PageIndex;
    CurLine := AnEditor.EditorComponent.CaretY;

    CurPos := TProjectBookmark.Create(1, CurLine, -1, AnEditor);
    try
      CurFound := nil;
      i := 0;
      while (i < Project1.Bookmarks.Count) and
            ( (GetSrcEdit(Project1.Bookmarks[i]) = nil) or
              (CompareBookmarkEditorPos(CurPos, Project1.Bookmarks[i]) = 0) )
      do
        inc(i);
      if i >= Project1.Bookmarks.Count then
        exit; // all on the same line

      CurFound := Project1.Bookmarks[i];
      inc(i);
      while (i < Project1.Bookmarks.Count) do begin
        if (GetSrcEdit(Project1.Bookmarks[i]) <> nil) then begin
          if (CompareBookmarkEditorPos(CurPos, Project1.Bookmarks[i]) <> 0) then begin
            if (not Backward) and
               (CompareBookmarkEditorPos(Project1.Bookmarks[i], CurFound) > 0)
            then
              CurFound := Project1.Bookmarks[i];
            if (Backward) and
               (CompareBookmarkEditorPos(Project1.Bookmarks[i], CurFound) < 0)
            then
              CurFound := Project1.Bookmarks[i];
          end;
        end;
        inc(i);
      end;

      if CurFound = nil then exit;
      ID := CurFound.ID;
      NewXY := CurFound.CursorPos;
    finally
      CurPos.Free;
    end;

    AnEditor := GetSrcEdit(CurFound);
  end
  else begin
    AnEditor := nil;
    AnEditorInfo := nil;
    AnUnitInfo := TUnitInfo(Project1.Bookmarks.UnitInfoForBookmarkWithIndex(ID));
    if (AnUnitInfo <> nil) and (AnUnitInfo.OpenEditorInfoCount > 0) then begin
      NewXY := Project1.Bookmarks.BookmarkWithID(ID).CursorPos;
      AnEditorInfo := GetAvailableUnitEditorInfo(AnUnitInfo, NewXY);
    end;
    if AnEditorInfo <> nil then
      AnEditor := TSourceEditor(AnEditorInfo.EditorComponent);
    if AnEditor = nil then exit;
  end;

  if (AnEditor <> SourceEditorManager.ActiveEditor)
  or (AnEditor.EditorComponent.CaretX <> NewXY.X)
  or (AnEditor.EditorComponent.CaretY <> NewXY.Y)
  then
    SourceEditorManager.AddJumpPointClicked(Self);

  SourceEditorManager.ActiveEditor := AnEditor;
  SourceEditorManager.ShowActiveWindowOnTop(True);
  try
    AnEditor.BeginUpdate;
    AnEditor.EditorComponent.GotoBookMark(ID);
    if not AnEditor.IsLocked then
      AnEditor.CenterCursor(True);
  finally
    AnEditor.EndUpdate;
  end;
end;

//this is fired when the editor is focused, changed, ?.  Anything that causes the status change
procedure TMainIDE.OnSrcNotebookEditorChanged(Sender: TObject);
begin
  if SourceEditorManager.SourceEditorCount = 0 then Exit;
  UpdateSaveMenuItemsAndButtons(false);
end;

procedure TMainIDE.OnSrcNotebookEditorMoved(Sender: TObject);
var
  p: TUnitEditorInfo;
  i: Integer;
  SrcEdit: TSourceEditor;
begin
  SrcEdit := TSourceEditor(Sender);
  p :=Project1.EditorInfoWithEditorComponent(SrcEdit);
  if p <> nil then begin
    p.PageIndex := SrcEdit.PageIndex;
    p.WindowID := SrcEdit.SourceNotebook.WindowID;
    //SourceEditorManager.IndexOfSourceWindow(SrcEdit.SourceNotebook);
    p.IsLocked := SrcEdit.IsLocked;
  end
  else if SrcEdit.IsNewSharedEditor then begin
    // attach to UnitInfo
    SrcEdit.IsNewSharedEditor := False;
    i := 0;
    while (i < SrcEdit.SharedEditorCount) and (SrcEdit.SharedEditors[i] = SrcEdit) do
      inc(i);
    p := Project1.EditorInfoWithEditorComponent(SrcEdit.SharedEditors[i]);
    p := p.UnitInfo.GetClosedOrNewEditorInfo;
    p.EditorComponent := SrcEdit;
    p.SyntaxHighlighter := SrcEdit.SyntaxHighlighterType;
    p.CustomHighlighter := p.SyntaxHighlighter <> p.UnitInfo.DefaultSyntaxHighlighter;
  end;
end;

procedure TMainIDE.OnSrcNotebookEditorClosed(Sender: TObject);
var
  SrcEditor: TSourceEditor;
  p: TUnitEditorInfo;
begin
  SrcEditor := TSourceEditor(Sender);
  p :=Project1.EditorInfoWithEditorComponent(SrcEditor);
  if (p <> nil) then
    p.EditorComponent := nil; // Set EditorIndex := -1
end;

procedure TMainIDE.OnSrcNotebookCurCodeBufferChanged(Sender: TObject);
begin
  if SourceEditorManager.SourceEditorCount = 0 then Exit;
  if CodeExplorerView<>nil then CodeExplorerView.CurrentCodeBufferChanged;
end;

procedure TMainIDE.OnSrcNotebookShowHintForSource(SrcEdit: TSourceEditor;
  ClientPos: TPoint; CaretPos: TPoint);

  function CheckExpressionIsValid(var Expr: String): boolean;
  var
    i: Integer;
    InStr: Boolean;
  begin
    Result := True;
    Expr := Trim(Expr);
    if (Expr <> '') and (Expr[Length(Expr)] = ';') then
      SetLength(Expr, Length(Expr) - 1);
    if (pos(#10, Expr) < 1) and (pos(#13, Expr) < 1) then exit; // single line, assume ok

    Result := False;
    InStr := False;
    for i := 1 to Length(Expr) do begin
      if Expr[i] = '''' then InStr := not InStr;
      if (not InStr) and (Expr[i] in [';', ':']) then exit; // can not be an expression
      // Todo: Maybe check for keywords: If Then Begin End ...
    end;
    Result := True;
  end;

var
  ActiveUnitInfo: TUnitInfo;
  BaseURL, SmartHintStr, Expression, DebugEval, DebugEvalDerefer: String;
  DBGType,DBGTypeDerefer: TDBGType;
  HasHint: Boolean;
  p: SizeInt;
  Opts: TDBGEvaluateFlags;
begin
  //DebugLn(['TMainIDE.OnSrcNotebookShowHintForSource START']);
  if (SrcEdit=nil) then exit;

  if not BeginCodeTool(SrcEdit, ActiveUnitInfo,
    [ctfUseGivenSourceEditor {, ctfActivateAbortMode}]) then exit;

  BaseURL:='';
  SmartHintStr := '';
  {$IFDEF IDE_DEBUG}
  debugln('');
  debugln('[TMainIDE.OnSrcNotebookShowHintForSource] ************ ',ActiveUnitInfo.Source.Filename,' X=',CaretPos.X,' Y=',CaretPos.Y);
  {$ENDIF}
  HasHint:=false;
  if EditorOpts.AutoToolTipSymbTools then begin
    {$IFDEF IDE_MEM_CHECK}CheckHeapWrtMemCnt('TMainIDE.OnSrcNotebookShowHintForSource A');{$ENDIF}
    if TIDEHelpManager(HelpBoss).GetHintForSourcePosition(ActiveUnitInfo.Filename,
                             CaretPos,BaseURL,SmartHintStr,
                             [{$IFDEF EnableFocusHint}ihmchAddFocusHint{$ENDIF}])=shrSuccess
    then
      HasHint:=true;
    {$IFDEF IDE_MEM_CHECK}CheckHeapWrtMemCnt('TMainIDE.OnSrcNotebookShowHintForSource B');{$ENDIF}
  end;
  case ToolStatus of
    itDebugger: begin
      if EditorOpts.AutoToolTipExprEval then begin
        if SrcEdit.SelectionAvailable and SrcEdit.CaretInSelection(CaretPos) then begin
          Expression := SrcEdit.GetText(True);
          if not CheckExpressionIsValid(Expression) then
            Expression := '';
        end
        else
          Expression := SrcEdit.GetOperandFromCaret(CaretPos);
        if Expression='' then exit;
        //DebugLn(['TMainIDE.OnSrcNotebookShowHintForSource Expression="',Expression,'"']);
        DBGType:=nil;
        DBGTypeDerefer:=nil;
        Opts := [];
        if EditorOpts.DbgHintAutoTypeCastClass
        then Opts := [defClassAutoCast];
        if not DebugBoss.Evaluate(Expression, DebugEval, DBGType, Opts) or (DebugEval = '') then
          DebugEval := '???';
        // deference a pointer - maybe it is a class
        if Assigned(DBGType) and (DBGType.Kind in [skPointer]) and
           not( StringCase(Lowercase(DBGType.TypeName), ['char', 'character', 'ansistring']) in [0..2] )
        then
        begin
          if DBGType.Value.AsPointer <> nil then
          begin
            if DebugBoss.Evaluate(Expression + '^', DebugEvalDerefer, DBGTypeDerefer, Opts) then
            begin
              if Assigned(DBGTypeDerefer) and
                ( (DBGTypeDerefer.Kind <> skPointer) or
                  (StringCase(Lowercase(DBGTypeDerefer.TypeName), ['char', 'character', 'ansistring']) in [0..2])
                )
              then
                DebugEval := DebugEval + ' = ' + DebugEvalDerefer;
            end;
          end;
        end;
        FreeAndNil(DBGType);
        FreeAndNil(DBGTypeDerefer);
        HasHint:=true;
        Expression := Expression + ' = ' + DebugEval;
        if SmartHintStr<>'' then begin
          p:=System.Pos('<body>',lowercase(SmartHintStr));
          if p>0 then begin
            Insert('<div class="debuggerhint">'
                   +CodeHelpBoss.TextToHTML(Expression)+'</div><br>',
                   SmartHintStr,p+length('<body>'));
          end else begin
            SmartHintStr:=Expression+LineEnding+LineEnding+SmartHintStr;
          end;
        end else
          SmartHintStr:=Expression;
      end;
    end;
  end;

  if HasHint then
    SrcEdit.ActivateHint(ClientPos, BaseURL, SmartHintStr);
end;

procedure TMainIDE.OnSrcNoteBookActivated(Sender: TObject);
begin
  {$IFDEF VerboseIDEDisplayState}
  debugln(['TMainIDE.OnSrcNoteBookActivated']);
  {$ENDIF}
  DisplayState:=dsSource;
end;

procedure TMainIDE.OnDesignerActivated(Sender: TObject);
begin
  {$IFDEF VerboseIDEDisplayState}
  if DisplayState<>dsForm then begin
    debugln(['TMainIDE.OnDesignerActivated ']);
    DumpStack;
  end;
  {$ENDIF}
  DisplayState:= dsForm;
  LastFormActivated := (Sender as TDesigner).Form;
  {$IFDEF VerboseComponentPalette}
  DebugLn('***');
  DebugLn(['** TMainIDE.OnDesignerActivated: Calling UpdateIDEComponentPalette(true)',
           ', IDEStarted=', FIDEStarted, ' **']);
  {$ENDIF}
  UpdateIDEComponentPalette(true);
end;

procedure TMainIDE.OnDesignerCloseQuery(Sender: TObject);
var
  ADesigner: TDesigner;
  ASrcEdit: TSourceEditor;
  AnUnitInfo: TUnitInfo;
begin
  ADesigner:=TDesigner(Sender);
  GetDesignerUnit(ADesigner,ASrcEdit,AnUnitInfo);
  if AnUnitInfo.NeedsSaveToDisk
  then begin
    case IDEQuestionDialog(lisSaveChanges,
          Format(lisSaveFileBeforeClosingForm,
                 [AnUnitInfo.Filename, LineEnding, ADesigner.LookupRoot.Name]),
          mtConfirmation,[mrYes,mrNoToAll,lisNo,mrCancel],'') of
      mrYes: begin
        if DoSaveEditorFile(ASrcEdit,[sfCheckAmbiguousFiles])<>mrOk
        then Exit;
      end;
      mrNoToAll:;
    else
      Exit;
    end;
  end;
  if FDesignerToBeFreed=nil then
    FDesignerToBeFreed:=TFilenameToStringTree.Create(false);
  FDesignerToBeFreed[AnUnitInfo.Filename]:='1';
end;

procedure TMainIDE.OnDesignerRenameComponent(ADesigner: TDesigner;
  AComponent: TComponent; const NewName: string);
var
  ActiveSrcEdit: TSourceEditor;
  ActiveUnitInfo: TUnitInfo;
  BossResult: boolean;
  OldName: String;
  OldClassName: String;

  procedure ApplyBossResult(const ErrorMsg: string);
  var
    CodeToolBossErrMsg: String;
  begin
    ApplyCodeToolChanges;
    if not BossResult then begin
      CodeToolBossErrMsg:=CodeToolBoss.ErrorMessage;
      DoJumpToCodeToolBossError;
      // raise an exception to stop the rename
      raise Exception.Create(ErrorMsg+LineEnding+LineEnding+lisError
                        +CodeToolBossErrMsg+LineEnding+LineEnding+lisSeeMessages);
    end;
  end;

  procedure CheckInterfaceName(const AName: string);
  var
    i: LongInt;
    RegComp: TRegisteredComponent;
    ConflictingClass: TClass;
    s: string;
  begin
    if SysUtils.CompareText(ActiveUnitInfo.Unit_Name,AName)=0 then
      raise Exception.Create(Format(
        lisTheUnitItselfHasAlreadyTheNamePascalIdentifiersMus, [AName]));
    if ActiveUnitInfo.IsPartOfProject then begin
      // check if component name already exists in project
      i:=Project1.IndexOfUnitWithComponentName(AName,true,ActiveUnitInfo);
      if i>=0 then
        raise Exception.Create(Format(lisThereIsAlreadyAFormWithTheName, [AName]));
      // check if pascal identifier already exists in the units
      i:=Project1.IndexOfUnitWithName(AName,true,nil);
      if i>=0 then
        raise Exception.Create(Format(
          lisThereIsAlreadyAUnitWithTheNamePascalIdentifiersMus, [AName]));
    end;

    // check if classname
    ConflictingClass:=AComponent.ClassType.ClassParent;
    while ConflictingClass<>nil do begin
      if SysUtils.CompareText(AName,ConflictingClass.ClassName)=0 then begin
        s:=Format(lisThisComponentAlreadyContainsAClassWithTheName, [
          ConflictingClass.ClassName]);
        raise EComponentError.Create(s);
      end;
      ConflictingClass:=ConflictingClass.ClassParent;
    end;

    // check if keyword
    if CodeToolBoss.IsKeyWord(ActiveUnitInfo.Source,AName) then
      raise Exception.Create(Format(lisComponentNameIsKeyword, [AName]));

    // check if registered component class
    RegComp:=IDEComponentPalette.FindComponent(AName);
    if RegComp<>nil then begin
      s:=Format(lisThereIsAlreadyAComponentClassWithTheName, [RegComp.
        ComponentClass.ClassName]);
      raise EComponentError.Create(s);
    end;
  end;

  procedure RenameInheritedComponents(RenamedUnit: TUnitInfo;
    Simulate: boolean);
  var
    UsedByDependency: TUnitComponentDependency;
    DependingUnit: TUnitInfo;
    InheritedComponent: TComponent;
    DependingDesigner: TCustomForm;
  begin
    UsedByDependency:=ActiveUnitInfo.FirstUsedByComponent;
    while UsedByDependency<>nil do begin
      DependingUnit:=UsedByDependency.UsedByUnit;
      if (DependingUnit.Component<>nil)
      and (DependingUnit.Component.ClassParent=RenamedUnit.Component.ClassType)
      then begin
        // the root component inherits from the DependingUnit root component
        if DependingUnit.Component.ClassParent=AComponent.ClassType then begin
          if OldClassName<>AComponent.ClassName then begin
            // replace references to classname, ignoring errors
            CodeToolBoss.ReplaceWord(DependingUnit.Source,
                                     OldClassName,AComponent.ClassName,false);
          end;
        end;

        // rename inherited component
        InheritedComponent:=DependingUnit.Component.FindComponent(AComponent.Name);
        if InheritedComponent<>nil then begin
          // inherited component found
          if FRenamingComponents=nil then
            FRenamingComponents:=TFPList.Create;
          FRenamingComponents.Add(InheritedComponent);
          try
            DebugLn(['RenameInheritedComponents ',dbgsName(InheritedComponent),' Owner=',dbgsName(InheritedComponent.Owner)]);
            if Simulate then begin
              // only check if rename is possible
              if (InheritedComponent.Owner<>nil)
              and (InheritedComponent.Owner.FindComponent(NewName)<>nil) then
              begin
                raise EComponentError.Createfmt(lisDuplicateNameAComponentNamedAlreadyExistsInTheInhe,
                       [NewName, dbgsName(InheritedComponent.Owner)]);
              end;
            end else begin
              // rename component and references in code
              InheritedComponent.Name:=NewName;
              DependingDesigner:=GetDesignerFormOfSource(DependingUnit,false);
              if DependingDesigner<>nil then
                DependingUnit.Modified:=true;
              // replace references, ignoring errors
              CodeToolBoss.ReplaceWord(DependingUnit.Source,OldName,NewName,false);
            end;
          finally
            if FRenamingComponents<>nil then begin
              FRenamingComponents.Remove(InheritedComponent);
              if FRenamingComponents.Count=0 then
                FreeThenNil(FRenamingComponents);
            end;
          end;
        end;
        // rename recursively
        RenameInheritedComponents(DependingUnit,Simulate);
      end;
      UsedByDependency:=UsedByDependency.NextUsedByDependency;
    end;
  end;

  procedure RenameMethods;
  var
    PropList: PPropList;
    PropCount: LongInt;
    i: Integer;
    PropInfo: PPropInfo;
    DefaultName: Shortstring;
    CurMethod: TMethod;
    Root: TComponent;
    CurMethodName: Shortstring;
    RootClassName: ShortString;
    NewMethodName: String;
    CTResult: Boolean;
    RenamedMethods: TStringList;
  begin
    PropCount:=GetPropList(PTypeInfo(AComponent.ClassInfo),PropList);
    if PropCount=0 then exit;
    RenamedMethods:=nil;
    try
      Root:=ActiveUnitInfo.Component;
      RootClassName:=Root.ClassName;
      if Root=AComponent then RootClassName:=OldClassName;
      for i:=0 to PropCount-1 do begin
        PropInfo:=PropList^[i];
        if PropInfo^.PropType^.Kind<>tkMethod then continue;
        CurMethod:=GetMethodProp(AComponent,PropInfo);
        if (CurMethod.Data=nil) and (CurMethod.Code=nil) then continue;
        CurMethodName:=GlobalDesignHook.GetMethodName(CurMethod,Root);
        if CurMethodName='' then continue;
        DefaultName:=TMethodPropertyEditor.GetDefaultMethodName(
                          Root,AComponent,RootClassName,OldName,PropInfo^.Name);
        if (DefaultName<>CurMethodName) then continue;
        // this method has the default name (component name + method type name)
        NewMethodName:=TMethodPropertyEditor.GetDefaultMethodName(
                       Root,AComponent,Root.ClassName,NewName,PropInfo^.Name);
        if (CurMethodName=NewMethodName) then continue;
        // auto rename it
        DebugLn(['RenameMethods OldMethodName="',DefaultName,'" NewMethodName="',NewMethodName,'"']);

        // rename/create published method in source
        CTResult:=CodeToolBoss.RenamePublishedMethod(ActiveUnitInfo.Source,
              ActiveUnitInfo.Component.ClassName,CurMethodName,NewMethodName);
        if CTResult then begin
          // renamed in source, now rename in JIT class
          FormEditor1.RenameJITMethod(ActiveUnitInfo.Component,
                                      CurMethodName,NewMethodName);
          // add to the list of renamed methods
          if RenamedMethods=nil then
            RenamedMethods:=TStringList.Create;
          RenamedMethods.Add(CurMethodName);
          RenamedMethods.Add(NewMethodName);
        end else begin
          // unable to rename method in source
          // this is just a nice to have feature -> ignore the error
          DebugLn(['TMainIDE.OnDesignerRenameComponent.RenameMethods failed OldMethodName="',CurMethodName,'" NewMethodName="',NewMethodName,'" Error=',CodeToolBoss.ErrorMessage]);
        end;
      end;
      ApplyCodeToolChanges;
    finally
      FreeMem(PropList);
      if RenamedMethods<>nil then begin
        RenameInheritedMethods(ActiveUnitInfo,RenamedMethods);
        RenamedMethods.Free;
      end;
    end;
  end;

var
  NewClassName: string;
  AncestorRoot: TComponent;
  s: String;
  OldOpenEditorsOnCodeToolChange: Boolean;
begin
  DebugLn('TMainIDE.OnDesignerRenameComponent Old=',AComponent.Name,':',AComponent.ClassName,' New=',NewName,' Owner=',dbgsName(AComponent.Owner));
  if (not IsValidIdent(NewName)) or (NewName='') then
    raise Exception.Create(Format(lisComponentNameIsNotAValidIdentifier, [Newname]));
  if WordIsKeyWord.DoItCaseInsensitive(PChar(NewName))
  or WordIsDelphiKeyWord.DoItCaseInsensitive(PChar(NewName))
  or WordIsPredefinedFPCIdentifier.DoItCaseInsensitive(PChar(NewName))
  or WordIsPredefinedDelphiIdentifier.DoItCaseInsensitive(PChar(NewName))
  then begin
    raise Exception.Create(Format(lisComponentNameIsAPascalKeyword, [NewName]));
  end;
  if AComponent.Name='' then
    exit; // this component was never added to the source. It is a new component.

  if (FRenamingComponents<>nil)
  and (FRenamingComponents.IndexOf(AComponent)>=0) then
    exit; // already validated

  if SysUtils.CompareText(AComponent.Name,'Owner')=0 then
    // 'Owner' is used by TReader/TWriter
    raise EComponentError.Create(lisOwnerIsAlreadyUsedByTReaderTWriterPleaseChooseAnot);

  ActiveSrcEdit:=nil;
  BeginCodeTool(ADesigner,ActiveSrcEdit,ActiveUnitInfo,[ctfSwitchToFormSource]);
  ActiveUnitInfo:=Project1.UnitWithComponent(ADesigner.LookupRoot);

  OldName:=AComponent.Name;
  OldClassName:=AComponent.ClassName;
  NewClassName:='';
  CheckInterfaceName(NewName);
  if AComponent=ADesigner.LookupRoot then begin
    // rename owner component (e.g. the form)
    NewClassName:='T'+NewName;
    CheckInterfaceName(NewClassName);
  end;

  OldOpenEditorsOnCodeToolChange:=OpenEditorsOnCodeToolChange;
  OpenEditorsOnCodeToolChange:=true;
  try

    // check ancestor component
    AncestorRoot:=FormEditor1.GetAncestorLookupRoot(AComponent);
    if AncestorRoot<>nil then begin
      s:=Format(lisTheComponentIsInheritedFromToRenameAnInheritedComp, [dbgsName
        (AComponent), dbgsName(AncestorRoot), LineEnding]);
      raise EComponentError.Create(s);
    end;

    // check inherited components
    RenameInheritedComponents(ActiveUnitInfo,true);

    if AComponent=ADesigner.LookupRoot then begin
      // rename owner component (e.g. the form)

      // rename form component in source
      BossResult:=CodeToolBoss.RenameForm(ActiveUnitInfo.Source,
        AComponent.Name,AComponent.ClassName,
        NewName,NewClassName);
      ApplyBossResult(lisUnableToRenameFormInSource);
      ActiveUnitInfo.ComponentName:=NewName;

      // rename form component class
      FormEditor1.RenameJITComponent(AComponent,NewClassName);

      // change createform statement
      if ActiveUnitInfo.IsPartOfProject and (Project1.MainUnitID>=0)
      then begin
        BossResult:=CodeToolBoss.ChangeCreateFormStatement(
          Project1.MainUnitInfo.Source,
          AComponent.ClassName,AComponent.Name,
          NewClassName,NewName,true);
        Project1.MainUnitInfo.Modified:=true;
        ApplyBossResult(lisUnableToUpdateCreateFormStatementInProjectSource);
      end;
    end else if ADesigner.LookupRoot<>nil then begin
      // rename published variable in form source
      BossResult:=CodeToolBoss.RenamePublishedVariable(ActiveUnitInfo.Source,
        ADesigner.LookupRoot.ClassName,
        AComponent.Name,NewName,AComponent.ClassName,true);
      ApplyBossResult(lisUnableToRenameVariableInSource);
    end else begin
      RaiseException('TMainIDE.OnDesignerRenameComponent internal error:'+AComponent.Name+':'+AComponent.ClassName);
    end;

    // rename inherited components
    RenameInheritedComponents(ActiveUnitInfo,false);
    // mark references modified
    MarkUnitsModifiedUsingSubComponent(AComponent);

    // rename methods
    RenameMethods;
  finally
    OpenEditorsOnCodeToolChange:=OldOpenEditorsOnCodeToolChange;
  end;
end;

procedure TMainIDE.OnDesignerViewLFM(Sender: TObject);
var
  ADesigner: TDesigner;
  ASrcEdit: TSourceEditor;
  AnUnitInfo: TUnitInfo;
  EditorInfo: TUnitEditorInfo;
  LFMFilename: String;
begin
  ADesigner:=TDesigner(Sender);
  GetDesignerUnit(ADesigner,ASrcEdit,AnUnitInfo);
  //debugln('TMainIDE.OnDesignerViewLFM ',AnUnitInfo.Filename);
  OnDesignerCloseQuery(Sender);
  if AnUnitInfo.OpenEditorInfoCount > 0 then
    EditorInfo := AnUnitInfo.OpenEditorInfo[0]
  else
    EditorInfo := AnUnitInfo.EditorInfo[0];
  // ToDo: use UnitResources
  LFMFilename:=ChangeFileExt(AnUnitInfo.Filename, '.lfm');
  if not FileExistsUTF8(LFMFilename) then
    LFMFilename:=ChangeFileExt(AnUnitInfo.Filename, '.dfm');
  OpenEditorFile(LFMFilename, EditorInfo.PageIndex+1, EditorInfo.WindowID, nil, [], True);
end;

procedure TMainIDE.OnDesignerSaveAsXML(Sender: TObject);
var
  SaveDialog: TSaveDialog;
  SaveAsFilename: String;
  SaveAsFileExt: String;
  PkgDefaultDirectory: String;
  Filename: String;
  XMLConfig: TXMLConfig;
  ADesigner: TDesigner;
  ASrcEdit: TSourceEditor;
  AnUnitInfo: TUnitInfo;
begin
  ADesigner:=TDesigner(Sender);
  GetDesignerUnit(ADesigner,ASrcEdit,AnUnitInfo);
  debugln('TMainIDE.OnDesignerViewLFM ',AnUnitInfo.Filename);

  SaveAsFileExt:='.xml';
  SaveAsFilename:=ChangeFileExt(AnUnitInfo.Filename,SaveAsFileExt);
  SaveDialog:=TSaveDialog.Create(nil);
  try
    InputHistories.ApplyFileDialogSettings(SaveDialog);
    SaveDialog.Title:=lisSaveSpace+SaveAsFilename+' (*'+SaveAsFileExt+')';
    SaveDialog.FileName:=SaveAsFilename;
    // if this is a project file, start in project directory
    if AnUnitInfo.IsPartOfProject and (not Project1.IsVirtual)
    and (not FileIsInPath(SaveDialog.InitialDir,Project1.ProjectDirectory)) then
      SaveDialog.InitialDir:=Project1.ProjectDirectory;
    // if this is a package file, then start in package directory
    PkgDefaultDirectory:=PkgBoss.GetDefaultSaveDirectoryForFile(AnUnitInfo.Filename);
    if (PkgDefaultDirectory<>'')
    and (not FileIsInPath(SaveDialog.InitialDir,PkgDefaultDirectory)) then
      SaveDialog.InitialDir:=PkgDefaultDirectory;
    // show save dialog
    if (not SaveDialog.Execute) or (ExtractFileName(SaveDialog.Filename)='') then
      exit;   // user cancels
    Filename:=ExpandFileNameUTF8(SaveDialog.Filename);
  finally
    InputHistories.StoreFileDialogSettings(SaveDialog);
    SaveDialog.Free;
  end;

  try
    XMLConfig:=TXMLConfig.Create(Filename);
    try
      WriteComponentToXMLConfig(XMLConfig,'Component',ADesigner.LookupRoot);
      XMLConfig.Flush;
    finally
      XMLConfig.Free;
    end;
  except
    on E: Exception do begin
      IDEMessageDialog('Error',E.Message,mtError,[mbCancel]);
    end;
  end;
end;

procedure TMainIDE.OnDesignerShowObjectInspector(Sender: TObject);
begin
  DoBringToFrontFormOrInspector(True);
end;

procedure TMainIDE.OnDesignerShowAnchorEditor(Sender: TObject);
begin
  DoViewAnchorEditor;
end;

procedure TMainIDE.OnDesignerShowTabOrderEditor(Sender: TObject);
begin
  DoViewTabOrderEditor;
end;

procedure TMainIDE.OnSrcNoteBookAddJumpPoint(ACaretXY: TPoint;
  ATopLine: integer; AEditor: TSourceEditor; DeleteForwardHistory: boolean);
{off $DEFINE VerboseJumpHistory}
var
  ActiveUnitInfo: TUnitInfo;
  NewJumpPoint: TProjectJumpHistoryPosition;
begin
  {$IFDEF VerboseJumpHistory}
  debugln('');
  debugln('[TMainIDE.OnSrcNoteBookAddJumpPoint] A Line=',ACaretXY.Y,' Col=',ACaretXY.X,' DeleteForwardHistory=',DeleteForwardHistory,' Count=',Project1.JumpHistory.Count,',HistoryIndex=',Project1.JumpHistory.HistoryIndex);
  {$ENDIF}
  ActiveUnitInfo:=Project1.UnitWithEditorComponent(AEditor);
  if (ActiveUnitInfo=nil) then exit;
  NewJumpPoint:=TProjectJumpHistoryPosition.Create(ActiveUnitInfo.Filename,
    ACaretXY,ATopLine);
  {$IFDEF VerboseJumpHistory}
  //Project1.JumpHistory.WriteDebugReport;
  {$ENDIF}
  Project1.JumpHistory.InsertSmart(Project1.JumpHistory.HistoryIndex+1,
                                   NewJumpPoint);
  {$IFDEF VerboseJumpHistory}
  debugln('[TMainIDE.OnSrcNoteBookAddJumpPoint] B INSERTED');
  Project1.JumpHistory.WriteDebugReport;
  {$ENDIF}
  if DeleteForwardHistory then Project1.JumpHistory.DeleteForwardHistory;
  {$IFDEF VerboseJumpHistory}
  debugln('[TMainIDE.OnSrcNoteBookAddJumpPoint] END Line=',ACaretXY.Y,',DeleteForwardHistory=',DeleteForwardHistory,' Count=',Project1.JumpHistory.Count,',HistoryIndex=',Project1.JumpHistory.HistoryIndex);
  Project1.JumpHistory.WriteDebugReport;
  {$ENDIF}
end;

procedure TMainIDE.OnSrcNotebookDeleteLastJumPoint(Sender: TObject);
begin
  Project1.JumpHistory.DeleteLast;
end;

procedure TMainIDE.OnSrcNotebookJumpToHistoryPoint(var NewCaretXY: TPoint;
  var NewTopLine: integer; var DestEditor: TSourceEditor;
  JumpAction: TJumpHistoryAction);
{ How the HistoryIndex works:

  When the user jumps around each time an item is added to the history list
  and the HistoryIndex points to the last added item (i.e. Count-1).

  Jumping back:
    The sourceditor will be repositioned to the item with the HistoryIndex.
    Then the historyindex is moved to the previous item.
    If HistoryIndex is the last item in the history, then this is the first
    back jump and the current sourceeditor position is smart added to the
    history list. Smart means that if the added Item is similar to the last
    item then the last item will be replaced else a new item is added.

  Jumping forward:

}
var DestIndex, UnitIndex: integer;
  ASrcEdit: TSourceEditor;
  AnUnitInfo: TUnitInfo;
  DestJumpPoint: TProjectJumpHistoryPosition;
  CursorPoint, NewJumpPoint: TProjectJumpHistoryPosition;
  JumpHistory : TProjectJumpHistory;
  AnEditorInfo: TUnitEditorInfo;
begin
  DestEditor := nil;
  NewCaretXY.Y:=-1;
  JumpHistory:=Project1.JumpHistory;

  {$IFDEF VerboseJumpHistory}
  debugln('');
  debugln('[TMainIDE.OnSrcNotebookJumpToHistoryPoint] A Back=',JumpAction=jhaBack);
  JumpHistory.WriteDebugReport;
  {$ENDIF}

  // update jump history (e.g. delete jumps to closed editors)
  JumpHistory.DeleteInvalidPositions;

  // get destination jump point
  DestIndex:=JumpHistory.HistoryIndex;

  CursorPoint:=nil;
  // get current cursor position
  GetCurrentUnit(ASrcEdit,AnUnitInfo);
  if (ASrcEdit<>nil) and (AnUnitInfo<>nil) then begin
    CursorPoint:=TProjectJumpHistoryPosition.Create
        (AnUnitInfo.Filename,
         ASrcEdit.EditorComponent.LogicalCaretXY,
         ASrcEdit.EditorComponent.TopLine
        );
    {$IFDEF VerboseJumpHistory}
    debugln('  Current Position: ',CursorPoint.Filename,
            ' ',CursorPoint.CaretXY.X,',',CursorPoint.CaretXY.Y-1);
    {$ENDIF}
  end;

  if (JumpAction=jhaBack) and (JumpHistory.Count=DestIndex+1)
  and (CursorPoint<>nil) then begin
    // this is the first back jump
    // -> insert current source position into history
    {$IFDEF VerboseJumpHistory}
    debugln('  First back jump -> add current cursor position');
    {$ENDIF}
    NewJumpPoint:=TProjectJumpHistoryPosition.Create(CursorPoint);
    JumpHistory.InsertSmart(JumpHistory.HistoryIndex+1, NewJumpPoint);
  end;

  // find the next jump point that is not where the cursor is
  case JumpAction of
    jhaForward : inc(DestIndex);
//    jhaBack : if (CursorPoint<>nil) and (JumpHistory[DestIndex].IsSimilar(CursorPoint))
//        then dec(DestIndex);
    jhaViewWindow : DestIndex := JumpHistoryViewWin.SelectedIndex;
  end;

  while (DestIndex>=0) and (DestIndex<JumpHistory.Count) do begin
    DestJumpPoint:=JumpHistory[DestIndex];
    UnitIndex:=Project1.IndexOfFilename(DestJumpPoint.Filename);
    {$IFDEF VerboseJumpHistory}
    debugln(' DestIndex=',DestIndex,' UnitIndex=',UnitIndex);
    {$ENDIF}
    if (UnitIndex >= 0) and (Project1.Units[UnitIndex].OpenEditorInfoCount > 0)
    and ((CursorPoint=nil) or not DestJumpPoint.IsSimilar(CursorPoint)) then
    begin
      JumpHistory.HistoryIndex:=DestIndex;
      NewCaretXY:=DestJumpPoint.CaretXY;
      NewTopLine:=DestJumpPoint.TopLine;
      AnEditorInfo := GetAvailableUnitEditorInfo(Project1.Units[UnitIndex], NewCaretXY);
      if AnEditorInfo <> nil then
        DestEditor:=TSourceEditor(AnEditorInfo.EditorComponent);
      {$IFDEF VerboseJumpHistory}
      debugln('[TMainIDE.OnSrcNotebookJumpToHistoryPoint] Result Line=',NewCaretXY.Y,' Col=',NewCaretXY.X);
      {$ENDIF}
      break;
    end;
    case JumpAction of
      jhaForward : inc(DestIndex);
      jhaBack : dec(DestIndex);
      jhaViewWindow : break;
    end;
  end;

  CursorPoint.Free;

  {$IFDEF VerboseJumpHistory}
  debugln('[TMainIDE.OnSrcNotebookJumpToHistoryPoint] END Count=',JumpHistory.Count,',HistoryIndex=',JumpHistory.HistoryIndex);
  JumpHistory.WriteDebugReport;
  debugln('');
  {$ENDIF}
end;

procedure TMainIDE.OnSrcNoteBookMouseLink(
  Sender: TObject; X, Y: Integer; var AllowMouseLink: Boolean);
var
  ActiveUnitInfo: TUnitInfo;
  NewSource: TCodeBuffer;
  NewX, NewY, NewTopLine: integer;
  SrcEdit: TSourceEditor;
begin
  SrcEdit:=SourceEditorManager.SenderToEditor(Sender);
  if SrcEdit=nil then begin
    {$IFDEF VerboseFindDeclarationFail}
    debugln(['TMainIDE.OnSrcNoteBookMouseLink SrcEdit=nil']);
    {$ENDIF}
    exit;
  end;
  if not BeginCodeTool(SrcEdit,ActiveUnitInfo,[]) then begin
    {$IFDEF VerboseFindDeclarationFail}
    debugln(['TMainIDE.OnSrcNoteBookMouseLink BeginCodeTool failed ',SrcEdit.FileName,' X=',X,' Y=',Y]);
    {$ENDIF}
    exit;
  end;
  AllowMouseLink := CodeToolBoss.FindDeclaration(
    ActiveUnitInfo.Source,X,Y,NewSource,NewX,NewY,NewTopLine);
end;

function TMainIDE.OnSrcNoteBookGetIndent(Sender: TObject;
  SrcEditor: TSourceEditor; LogCaret, OldLogCaret: TPoint;
  FirstLinePos, LastLinePos: Integer; Reason: TSynEditorCommand;
  SetIndentProc: TSynBeautifierSetIndentProc): Boolean;
begin
  Result := False;
end;

procedure TMainIDE.OnSrcNotebookReadOnlyChanged(Sender: TObject);
var
  ActiveSourceEditor: TSourceEditor;
  ActiveUnitInfo: TUnitInfo;
begin
  GetCurrentUnit(ActiveSourceEditor,ActiveUnitInfo);
  ActiveUnitInfo.UserReadOnly:=ActiveSourceEditor.ReadOnly;
end;

procedure TMainIDE.OnSrcNotebookViewJumpHistory(Sender: TObject);
begin
  DoShowJumpHistory;
end;

procedure TMainIDE.OnSrcNoteBookPopupMenu(const AddMenuItemProc: TAddMenuItemProc);
begin
  PkgBoss.OnSourceEditorPopupMenu(AddMenuItemProc);
end;

procedure TMainIDE.OnSrcNoteBookCloseQuery(Sender: TObject; var CloseAction: TCloseAction);
var
  SrcNB: TSourceNotebook;
begin
  if SourceEditorManager.SourceWindowCount = 1 then
    exit;

  SrcNB := TSourceNotebook(Sender);
  if (SrcNB.EditorCount = 1) then begin
    DoCloseEditorFile(SrcNB.Editors[0], [cfSaveFirst]);
    CloseAction := caFree;
    exit;
  end;

  CloseAction := caHide;
  case IDEQuestionDialog(lisCloseAllTabsTitle, lisCloseAllTabsQuestion, mtConfirmation,
                  [mrYes, lisCloseAllTabsClose, mrNo, lisCloseAllTabsHide, mrCancel])
  of
    mrYes : begin
        SourceEditorManager.IncUpdateLock;
        try
          while (SrcNB.EditorCount > 0) and
                (DoCloseEditorFile(SrcNB.Editors[0], [cfSaveFirst]) = mrOK)
          do ;
          if SrcNB.EditorCount = 0 then
            CloseAction := caFree;
        finally
          SourceEditorManager.DecUpdateLock;
        end;
      end;
    mrNo : CloseAction := caHide;
    mrCancel : CloseAction := caNone;
  end;
end;

procedure TMainIDE.CreateObjectInspector(aDisableAutoSize: boolean);
begin
  if ObjectInspector1<>nil then begin
    if aDisableAutoSize then
      ObjectInspector1.DisableAutoSizing;
    exit;
  end;
  IDEWindowCreators.CreateForm(ObjectInspector1,TObjectInspectorDlg,
     aDisableAutoSize,OwningComponent);
  ObjectInspector1.Name:=DefaultObjectInspectorName;
  ObjectInspector1.ShowFavorites:=True;
  ObjectInspector1.ShowRestricted:=True;
  ObjectInspector1.Favorites:=LoadOIFavoriteProperties;
  ObjectInspector1.OnAddToFavorites:=@OIOnAddToFavorites;
  ObjectInspector1.OnFindDeclarationOfProperty:=@OIOnFindDeclarationOfProperty;
  ObjectInspector1.OnUpdateRestricted := @OIOnUpdateRestricted;
  ObjectInspector1.OnRemainingKeyDown:=@OIRemainingKeyDown;
  ObjectInspector1.OnRemoveFromFavorites:=@OIOnRemoveFromFavorites;
  ObjectInspector1.OnSelectPersistentsInOI:=@OIOnSelectPersistents;
  ObjectInspector1.OnShowOptions:=@OIOnShowOptions;
  ObjectInspector1.OnViewRestricted:=@OIOnViewRestricted;
  ObjectInspector1.OnSelectionChange:=@OIOnSelectionChange;
  ObjectInspector1.OnPropertyHint:=@OIOnPropertyHint;
  ObjectInspector1.OnDestroy:=@OIOnDestroy;
  ObjectInspector1.OnAutoShow:=@OIOnAutoShow;
  ObjectInspector1.EnableHookGetSelection:=false; // the selection is stored in TheControlSelection

  // after OI changes the Info box must be updated. Do that after some idle time
  OIChangedTimer:=TIdleTimer.Create(OwningComponent);
  with OIChangedTimer do begin
    Name:='OIChangedTimer';
    Interval:=50;                  // Info box can be updated with a short delay.
    OnTimer:=@OIChangedTimerTimer;
  end;
  EnvironmentOptions.ObjectInspectorOptions.AssignTo(ObjectInspector1);

  // connect to designers
  ObjectInspector1.PropertyEditorHook:=GlobalDesignHook;
  if FormEditor1<>nil then
    FormEditor1.Obj_Inspector := ObjectInspector1;

  try
    ObjectInspector1.Icon.LoadFromResourceName(HInstance, 'WIN_OBJECTINSPECTOR');
  except
  end;
end;

procedure TMainIDE.OnApplicationUserInput(Sender: TObject; Msg: Cardinal);
begin
  fUserInputSinceLastIdle:=true;
  if ToolStatus=itCodeTools then
    // abort codetools
    ToolStatus:=itCodeToolAborting;
end;

procedure TMainIDE.OnApplicationIdle(Sender: TObject; var Done: Boolean);
var
  SrcEdit: TSourceEditor;
  AnUnitInfo: TUnitInfo;
  AnIDesigner: TIDesigner;
  HasResources: Boolean;
  FileItem: PStringToStringTreeItem;
begin
  if FNeedUpdateHighlighters then begin
    {$IFDEF VerboseIdle}
    debugln(['TMainIDE.OnApplicationIdle FNeedUpdateHighlighters']);
    {$ENDIF}
    UpdateHighlighters(true);
  end;
  if fNeedSaveEnvironment then
    SaveEnvironment(true);

  GetDefaultProcessList.FreeStoppedProcesses;
  if (SplashForm<>nil) then FreeThenNil(SplashForm);

  if Assigned(FDesignerToBeFreed) then begin
    for FileItem in FDesignerToBeFreed do begin
      if Project1=nil then break;
      AnUnitInfo:=Project1.UnitInfoWithFilename(FileItem^.Name);
      if AnUnitInfo=nil then continue;
      if AnUnitInfo.Component=nil then continue;
      SourceFileMgr.CloseUnitComponent(AnUnitInfo,[]);
    end;
    FreeAndNil(FDesignerToBeFreed);
  end;
  if FUserInputSinceLastIdle then
  begin
    {$IFDEF VerboseIdle}
    debugln(['TMainIDE.OnApplicationIdle FUserInputSinceLastIdle']);
    {$ENDIF}
    FUserInputSinceLastIdle:=false;
    FormEditor1.CheckDesignerPositions;
    FormEditor1.PaintAllDesignerItems;
    GetCurrentUnit(SrcEdit,AnUnitInfo);
    UpdateSaveMenuItemsAndButtons(true);
    if Screen.ActiveForm<>nil then
    begin
      AnIDesigner:=Screen.ActiveForm.Designer;
      if AnIDesigner is TDesigner then
        MainIDEBar.itmViewToggleFormUnit.Enabled := true
      else
      begin
        HasResources:=false;
        if AnUnitInfo<>nil then
        begin
          if AnUnitInfo.HasResources then
            HasResources:=true
          else if FilenameIsAbsolute(AnUnitInfo.Filename)
            and FilenameIsPascalSource(AnUnitInfo.Filename)
            and ( FileExistsCached(ChangeFileExt(AnUnitInfo.Filename,'.lfm'))
               or FileExistsCached(ChangeFileExt(AnUnitInfo.Filename,'.dfm')) )
          then
            HasResources:=true;
        end;
        MainIDEBar.itmViewToggleFormUnit.Enabled := HasResources;
      end;
      MainIDEBar.ToggleFormSpeedBtn.Enabled := MainIDEBar.itmViewToggleFormUnit.Enabled;
      DebugBoss.UpdateButtonsAndMenuItems;
    end;
  end;
  if SourceFileMgr.CheckFilesOnDiskNeeded then begin
    {$IFDEF VerboseIdle}
    debugln(['TMainIDE.OnApplicationIdle FCheckFilesOnDiskNeeded']);
    {$ENDIF}
    DoCheckFilesOnDisk(true);
  end;
  if (FRemoteControlTimer=nil) and EnableRemoteControl then begin
    {$IFDEF VerboseIdle}
    debugln(['TMainIDE.OnApplicationIdle EnableRemoteControl']);
    {$ENDIF}
    SetupRemoteControl;
  end;
  if Screen.GetCurrentModalForm=nil then begin
    {$IFDEF VerboseIdle}
    debugln(['TMainIDE.OnApplicationIdle Screen.GetCurrentModalForm']);
    {$ENDIF}
    PkgBoss.OpenHiddenModifiedPackages;
  end;
end;

procedure TMainIDE.OnApplicationDeActivate(Sender: TObject);
var
  i: Integer;
  AForm: TCustomForm;
begin
  if EnvironmentOptions.SingleTaskBarButton and FApplicationIsActivate
    and (MainIDEBar.WindowState=wsNormal) then
  begin
    for i:=Screen.CustomFormCount-1 downto 0 do
    begin
      AForm:=Screen.CustomFormsZOrdered[i];
      if (AForm.Parent=nil) and (AForm<>MainIDEBar) and (AForm.IsVisible)
      and (AForm.Designer=nil) and (not (csDesigning in AForm.ComponentState))
      and not (fsModal in AForm.FormState) then
        LastActivatedWindows.Add(AForm);
    end;
    FApplicationIsActivate:=false;
  end;
end;

procedure TMainIDE.OnMainBarActive(Sender: TObject);
var
  i, FormCount: integer;
  AForm: TCustomForm;
begin
  if EnvironmentOptions.SingleTaskBarButton and not FApplicationIsActivate
  and (MainIDEBar.WindowState=wsNormal) then
  begin
    FApplicationIsActivate:=true;
    FormCount:=0;
    for i:=Screen.CustomFormCount-1 downto 0 do
    begin
      AForm:=Screen.CustomForms[i];
      if (AForm.Parent=nil) and (AForm<>MainIDEBar) and (AForm.IsVisible)
      and (AForm.Designer=nil) and (not (csDesigning in AForm.ComponentState))
      and not (fsModal in AForm.FormState) then
        inc(FormCount);
    end;
    while LastActivatedWindows.Count>0 do
    begin
      AForm:=TCustomForm(LastActivatedWindows[0]);
      if Assigned(AForm) and (not (CsDestroying in AForm.ComponentState)) and
      AForm.IsVisible then
        AForm.BringToFront;
      LastActivatedWindows.Delete(0);
    end;
    MainIDEBar.BringToFront;
  end;
end;

procedure TMainIDE.OnApplicationActivate(Sender: TObject);
begin
  DoCheckFilesOnDisk;
end;

procedure TMainIDE.OnApplicationKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
var
  Command: Word;
  aForm: TCustomForm;
  aControl: TControl;
begin
  //DebugLn('TMainIDE.OnApplicationKeyDown ',dbgs(Key),' ',dbgs(Shift));
  Command := EditorOpts.KeyMap.TranslateKey(Key,Shift,nil);
  //debugln(['TMainIDE.OnApplicationKeyDown ',dbgs(Command),' ',DbgSName(Screen.GetCurrentModalForm)]);
  if Command=ecEditContextHelp then begin
    // show context help editor
    Key:=VK_UNKNOWN;
    ShowContextHelpEditor(Sender);
  end else if (Command=ecContextHelp) and (Sender is TControl) then begin
    // show context help
    Key:=VK_UNKNOWN;
    LazarusHelp.ShowHelpForIDEControl(TControl(Sender));
  end else if (Command=ecClose) then begin
    if Screen.GetCurrentModalForm<>nil then begin
      // close modal window
      Key:=VK_UNKNOWN;
      Screen.GetCurrentModalForm.ModalResult:=mrCancel;
    end else if Sender is TControl then begin
      // close current window
      // Note: when docking: close only an inner window
      // do not close MainIDEBar
      // close only registered windows
      aControl:=TControl(Sender);
      while aControl<>nil do begin
        if aControl is TCustomForm then begin
          aForm:=TCustomForm(aControl);
          if (aForm.Name<>'') and (aForm<>MainIDEBar)
          and (IDEWindowCreators.FindWithName(aForm.Name)=nil) then begin
            aForm.Close;
          end;
        end;
        aControl:=aControl.Parent;
      end;
    end;
  end;
end;

procedure TMainIDE.OnApplicationQueryEndSession(var Cancel: Boolean);
begin
  Cancel := False;
end;

procedure TMainIDE.OnApplicationEndSession(Sender: TObject);
begin
  QuitIDE;
end;

procedure TMainIDE.OnScreenChangedForm(Sender: TObject; Form: TCustomForm);
var
  aForm: TForm;
begin
  aForm:=Screen.ActiveForm;
  if (aForm<>MainIDEBar)
  and (Screen.GetCurrentModalForm=nil)
  and (aForm<>WindowMenuActiveForm) then
    WindowMenuActiveForm := aForm;
end;

procedure TMainIDE.OnScreenRemoveForm(Sender: TObject; AForm: TCustomForm);
begin
  HiddenWindowsOnRun.Remove(AForm);
  LastActivatedWindows.Remove(AForm);
  if WindowMenuActiveForm=AForm then
    WindowMenuActiveForm:=nil;
  if fLastCompPaletteForm=AForm then
    fLastCompPaletteForm:=nil;
end;

procedure TMainIDE.OnRemoteControlTimer(Sender: TObject);
begin
  FRemoteControlTimer.Enabled:=false;
  DoExecuteRemoteControl;
  FRemoteControlTimer.Enabled:=true;
end;

procedure TMainIDE.OnSelectFrame(Sender: TObject; var AComponentClass: TComponentClass);
begin
  AComponentClass := DoSelectFrame;
end;

procedure TMainIDE.OIChangedTimerTimer(Sender: TObject);
var
  OI: TObjectInspectorDlg;
  ARow: TOIPropertyGridRow;
  Code: TCodeBuffer;
  Caret: TPoint;
  i: integer;
  HtmlHint, BaseURL, PropDetails: string;
  CacheWasUsed: Boolean;
  Stream: TStringStream;
begin
  OI:=ObjectInspector1;
  if (OI=nil) or (not OI.IsVisible) then
    Exit;
  OIChangedTimer.AutoEnabled:=false;
  OIChangedTimer.Enabled:=false;

  if not BeginCodeTools or not OI.ShowInfoBox then
    Exit;

  HtmlHint := '';
  BaseURL := '';
  PropDetails := '';

  ARow := OI.GetActivePropertyRow;

  if (ARow <> nil)
  and FindDeclarationOfOIProperty(OI, ARow, Code, Caret, i) then
  begin
    if CodeHelpBoss.GetHTMLHint(Code, Caret.X, Caret.Y, [],
      BaseURL, HtmlHint, PropDetails, CacheWasUsed) <> chprSuccess then
    begin
      HtmlHint := '';
      BaseURL := '';
      PropDetails := '';
    end;
  end;

  if OI.InfoPanel.ControlCount > 0 then
    OI.InfoPanel.Controls[0].Visible := HtmlHint <> '';
  if HtmlHint <> '' then
  begin
    OIHelpProvider.BaseURL := BaseURL;
    Stream := TStringStream.Create(HtmlHint);
    try
      OIHelpProvider.ControlIntf.SetHTMLContent(Stream);
    finally
      Stream.Free;
    end;
  end;
  // Property details always starts with "published property". Get rid of it.
  i:=Pos(' ', PropDetails);
  if i>0 then begin
    i:=PosEx(' ', PropDetails, i+1);
    if i>0 then
      PropDetails:=Copy(PropDetails, i+1, Length(PropDetails));
  end;
  OI.StatusBar.SimpleText:=PropDetails;  // Show in OI StatusBar
end;

function TMainIDE.ProjInspectorAddUnitToProject(Sender: TObject;
  AnUnitInfo: TUnitInfo): TModalresult;
var
  ActiveSourceEditor: TSourceEditor;
  ActiveUnitInfo: TUnitInfo;
  ShortUnitName: String;
  OkToAdd: boolean;
begin
  Result:=mrOk;
  AnUnitInfo.IsPartOfProject:=true;
  //debugln(['TMainIDE.ProjInspectorAddUnitToProject ',AnUnitInfo.Filename]);
  ActiveSourceEditor:=nil;
  BeginCodeTool(ActiveSourceEditor,ActiveUnitInfo,[]);
  OkToAdd:=True;
  if FilenameIsPascalUnit(AnUnitInfo.Filename) then begin
    OkToAdd:=SourceFileMgr.CheckDirIsInSearchPath(AnUnitInfo,False,False);
    if (pfMainUnitHasUsesSectionForAllUnits in Project1.Flags) then begin
      AnUnitInfo.ReadUnitNameFromSource(false);
      ShortUnitName:=AnUnitInfo.Unit_Name;
      if (ShortUnitName<>'') then begin
        if CodeToolBoss.AddUnitToMainUsesSectionIfNeeded(
                       Project1.MainUnitInfo.Source,ShortUnitName,'') then begin
          ApplyCodeToolChanges;
          Project1.MainUnitInfo.Modified:=true;
        end else begin
          DoJumpToCodeToolBossError;
          Result:=mrCancel;
        end;
      end;
    end;
  end
  else if CompareFileExt(AnUnitInfo.Filename,'inc',false)=0 then
    OkToAdd:=SourceFileMgr.CheckDirIsInSearchPath(AnUnitInfo,False,True);
  if OkToAdd then
    ;
  Project1.Modified:=true;
end;

function TMainIDE.ProjInspectorRemoveFile(Sender: TObject; AnUnitInfo: TUnitInfo): TModalresult;
var
  UnitInfos: TFPList;
begin
  if not AnUnitInfo.IsPartOfProject then exit(mrOk);
  UnitInfos:=TFPList.Create;
  try
    UnitInfos.Add(AnUnitInfo);
    Result:=SourceFileMgr.RemoveFilesFromProject(Project1,UnitInfos);
  finally
    UnitInfos.Free;
  end;
end;

procedure TMainIDE.OnCompilerOptionsDialogTest(Sender: TObject);
begin
  DoTestCompilerSettings(Sender as TCompilerOptions);
end;

function TMainIDE.OnCheckCompOptsAndMainSrcForNewUnit(CompOpts: TLazCompilerOptions): TModalResult;
begin
  Result:=CheckCompOptsAndMainSrcForNewUnit(CompOpts);
end;

procedure TMainIDE.FPCMsgFilePoolLoadFile(aFilename: string; out s: string);
// Note: called by any thread
var
  fs: TFileStreamUTF8;
  Encoding: String;
begin
  s:='';
  fs := TFileStreamUTF8.Create(aFilename, fmOpenRead or fmShareDenyNone);
  try
    SetLength(s,fs.Size);
    if s<>'' then
      fs.Read(s[1],length(s));
    Encoding:=GuessEncoding(s);
    s:=ConvertEncoding(s,Encoding,EncodingUTF8);
  finally
    fs.Free;
  end;
end;

procedure TMainIDE.OnGetLayout(Sender: TObject; aFormName: string; out
  aBounds: TRect; out DockSibling: string; out DockAlign: TAlign);
var
  SrcEditWnd: TSourceNotebook;
  ScreenR: TRect;
begin
  DockSibling:='';
  DockAlign:=alNone;
  if (ObjectInspector1<>nil) and (aFormName=ObjectInspector1.Name) then begin
    // place object inspector below main bar
    ScreenR:=IDEWindowCreators.GetScreenrectForDefaults;
    aBounds:=Rect(ScreenR.Left,
       Min(MainIDEBar.Top+MainIDEBar.Height+25,200),230,
       ScreenR.Bottom-ScreenR.Top-150);
    // do not dock object inspector, because this would hide the floating designers
  end
  else if (aFormName=NonModalIDEWindowNames[nmiwMessagesViewName]) then begin
    // place messages below source editor
    ScreenR:=IDEWindowCreators.GetScreenrectForDefaults;
    if SourceEditorManager.SourceWindowCount>0 then begin
      SrcEditWnd:=SourceEditorManager.SourceWindows[0];
      aBounds:=GetParentForm(SrcEditWnd).BoundsRect;
      aBounds.Top:=aBounds.Bottom+25;
      aBounds.Bottom:=aBounds.Top+100;
    end else begin
      aBounds:=Rect(ScreenR.Left+250,ScreenR.Bottom-200,ScreenR.Right-250,100);
    end;
    if IDEDockMaster<>nil then begin
      DockSibling:=NonModalIDEWindowNames[nmiwSourceNoteBookName];
      DockAlign:=alBottom;
    end;
  end;
end;

procedure TMainIDE.RenameInheritedMethods(AnUnitInfo: TUnitInfo; List: TStrings);
var
  UsedByDependency: TUnitComponentDependency;
  DependingUnit: TUnitInfo;
  OldName: string;
  NewName: string;
  i: Integer;
begin
  if List=nil then exit;
  UsedByDependency:=AnUnitInfo.FirstUsedByComponent;
  while UsedByDependency<>nil do begin
    DependingUnit:=UsedByDependency.UsedByUnit;
    if (DependingUnit.Component<>nil)
    and (DependingUnit.Component.ClassParent=AnUnitInfo.Component.ClassType)
    then begin
      // the root component inherits from the DependingUnit root component
      i:=0;
      while i<List.Count-1 do begin
        OldName:=List[i];
        NewName:=List[i+1];
        // replace references, ignoring errors
        if CodeToolBoss.ReplaceWord(DependingUnit.Source,OldName,NewName,false)
        then begin
          // renamed in source, now rename in JIT class
          FormEditor1.RenameJITMethod(DependingUnit.Component,
                                      OldName,NewName);
        end;
        inc(i,2);
      end;
      ApplyCodeToolChanges;
      // rename recursively
      RenameInheritedMethods(DependingUnit,List);
    end;
    UsedByDependency:=UsedByDependency.NextUsedByDependency;
  end;
end;

function TMainIDE.OIHelpProvider: TAbstractIDEHTMLProvider;
var
  HelpControl: TControl;
begin
  if (FOIHelpProvider = nil) and (ObjectInspector1<>nil) then
  begin
    HelpControl := CreateIDEHTMLControl(ObjectInspector1, FOIHelpProvider, [ihcScrollable]);
    HelpControl.Parent := ObjectInspector1.InfoPanel;
    HelpControl.Align := alClient;
    HelpControl.BorderSpacing.Around := 2;
    HelpControl.Color := clForm;
  end;
  Result := FOIHelpProvider;
end;

function TMainIDE.GetDesignerFormOfSource(AnUnitInfo: TUnitInfo; LoadForm: boolean
  ): TCustomForm;
begin
  Result:=nil;

  if AnUnitInfo.Component<>nil then
    Result:=FormEditor1.GetDesignerForm(AnUnitInfo.Component);
  if ((Result=nil) or (Result.Designer=nil)) and LoadForm
  and FilenameIsPascalSource(AnUnitInfo.Filename) then begin
    //DebugLn(['TMainIDE.GetFormOfSource ',AnUnitInfo.Filename,' ',dbgsName(AnUnitInfo.Component)]);
    SourceFileMgr.LoadLFM(AnUnitInfo,[],[]);
  end;
  if (Result=nil) and (AnUnitInfo.Component<>nil) then
    Result:=FormEditor1.GetDesignerForm(AnUnitInfo.Component);
  if (Result<>nil) and (Result.Designer=nil) then
    Result:=nil;
end;

function TMainIDE.GetProjectFileWithRootComponent(AComponent: TComponent
  ): TLazProjectFile;
var
  AnUnitInfo: TUnitInfo;
begin
  if AComponent=nil then exit(nil);
  AnUnitInfo:=Project1.FirstUnitWithComponent;
  while AnUnitInfo<>nil do begin
    if AnUnitInfo.Component=AComponent then begin
      Result:=AnUnitInfo;
      exit;
    end;
    AnUnitInfo:=AnUnitInfo.NextUnitWithComponent;
  end;
  Result:=nil;
end;

function TMainIDE.GetProjectFileWithDesigner(ADesigner: TIDesigner): TLazProjectFile;
var
  AComponent: TComponent;
begin
  AComponent:=ADesigner.LookupRoot;
  if AComponent=nil then
    RaiseException('TMainIDE.GetProjectFileWithDesigner Designer.LookupRoot=nil');
  Result:=GetProjectFileWithRootComponent(AComponent);
end;

function TMainIDE.OnPropHookMethodExists(const AMethodName: String; TypeData: PTypeData;
  var MethodIsCompatible,MethodIsPublished,IdentIsMethod: boolean): boolean;
var
  ActiveSrcEdit: TSourceEditor;
  ActiveUnitInfo: TUnitInfo;
begin
  ActiveSrcEdit:=nil;
  if not BeginCodeTool(ActiveSrcEdit,ActiveUnitInfo,[ctfSwitchToFormSource]) then
    Exit;
  {$IFDEF IDE_DEBUG}
  debugln('');
  debugln('[TMainIDE.OnPropHookMethodExists] ************ ',AMethodName);
  {$ENDIF}
  Result := CodeToolBoss.PublishedMethodExists(ActiveUnitInfo.Source,
                        ActiveUnitInfo.Component.ClassName, AMethodName, TypeData,
                        MethodIsCompatible, MethodIsPublished, IdentIsMethod);
  if CodeToolBoss.ErrorMessage <> '' then
  begin
    DoJumpToCodeToolBossError;
    raise Exception.Create(lisUnableToFindMethod+' '+lisPleaseFixTheErrorInTheMessageWindow);
  end;
end;

function TMainIDE.OnPropHookCreateMethod(const AMethodName: ShortString;
  ATypeInfo: PTypeInfo;
  APersistent: TPersistent; const APropertyPath: string): TMethod;
{ APersistent is the instance that gets the new method, not the lookuproot.
  For example assign 'Button1Click' to Form1.Button1.OnClick:
    APersistent = APersistent
    AMethodName = 'Button1Click'
    APropertyPath = Form1.Button1.OnClick
    ATypeInfo = the typeinfo of the event property
}
{ $DEFINE VerboseOnPropHookCreateMethod}
var
  ActiveSrcEdit: TSourceEditor;
  ActiveUnitInfo: TUnitInfo;

  function GetInheritedMethodPath: string;
  var
    OldJITMethod: TJITMethod;
    OldMethod: TMethod;
    APropName: String;
    p: Integer;
    OldMethodOwner: TComponent;
  begin
    Result:='';
    {$IFDEF VerboseOnPropHookCreateMethod}
    debugln(['  GetInheritedMethodPath APersistent=',DbgSName(APersistent),' APropertyPath="',APropertyPath,'" AMethodName="',AMethodName,'"']);
    {$ENDIF}

    // get old method
    p:=length(APropertyPath);
    while (p>0) and (APropertyPath[p]<>'.') do dec(p);
    if p<1 then exit;
    APropName:=copy(APropertyPath,p+1,length(APropertyPath));
    OldMethod:=GetMethodProp(APersistent,APropName);
    if not GetJITMethod(OldMethod,OldJITMethod) then begin
      {$IFDEF VerboseOnPropHookCreateMethod}
      debugln(['  GetInheritedMethodPath old method is not a jitmethod']);
      {$ENDIF}
      exit;
    end;

    {$IFDEF VerboseOnPropHookCreateMethod}
    debugln(['  GetInheritedMethodPath  OldJITMethod=',DbgSName(OldJITMethod.TheClass),'.',OldJITMethod.TheMethodName]);
    {$ENDIF}

    // there is an old method
    if OldJITMethod.TheClass=ActiveUnitInfo.Component.ClassType then begin
      // old method belongs to same lookup root
      // => do not call the old method
      {$IFDEF VerboseOnPropHookCreateMethod}
      debugln(['  GetInheritedMethodPath old method belongs to same lookuproot (',DbgSName(ActiveUnitInfo.Component),')']);
      {$ENDIF}
      exit;
    end;
    // the old method is from another lookup root (e.g. not the current form)

    if ActiveUnitInfo.Component.InheritsFrom(OldJITMethod.TheClass) then
    begin
      // the old method is from an ancestor
      // => add a statement 'inherited OldMethodName;'
      Result:='inherited';
      {$IFDEF VerboseOnPropHookCreateMethod}
      debugln(['  GetInheritedMethodPath old method is from an ancestor. Result="',Result,'"']);
      {$ENDIF}
      exit;
    end;

    // check for nested components
    // to call a method the instance is needed
    // => create a path from the current component (e.g. the form) to the nested OldMethodOwner
    if APersistent is TComponent then
      OldMethodOwner:=TComponent(APersistent)
    else begin
      {$IFDEF VerboseOnPropHookCreateMethod}
      debugln(['  GetInheritedMethodPath there is no simple way to get the owner of a TPersistent. Not calling old method.']);
      {$ENDIF}
      exit;
    end;
    while (OldMethodOwner<>nil)
    and (not OldMethodOwner.ClassType.InheritsFrom(OldJITMethod.TheClass)) do
      OldMethodOwner:=OldMethodOwner.Owner;
    if OldMethodOwner=nil then begin
      {$IFDEF VerboseOnPropHookCreateMethod}
      debugln(['  GetInheritedMethodPath owner of oldmethod not found.']);
      {$ENDIF}
      exit;
    end;

    {$IFDEF VerboseOnPropHookCreateMethod}
    DebugLn(['  GetInheritedMethodPath OldMethodOwner=',dbgsName(OldMethodOwner)]);
    {$ENDIF}
    // create a path to the nested component
    while (OldMethodOwner<>nil) and (OldMethodOwner<>ActiveUnitInfo.Component) do
    begin
      if Result<>'' then
        Result:='.'+Result;
      Result:=OldMethodOwner.Name+Result;
      OldMethodOwner:=OldMethodOwner.Owner;
    end;
    if (OldMethodOwner=ActiveUnitInfo.Component)
    and (Result<>'') then begin
      Result:=Result+'.'+OldJITMethod.TheMethodName;
      {$IFDEF VerboseOnPropHookCreateMethod}
      DebugLn(['  GetInheritedMethodPath call to nested override: OverrideMethodName=',Result]);
      {$ENDIF}
    end;
    Result:='';
  end;

var
  r: boolean;
  OldChange: Boolean;
  InheritedMethodPath: String;
  UseRTTIForMethods: Boolean;
begin
  Result.Code:=nil;
  Result.Data:=nil;
  ActiveSrcEdit:=nil;
  if not BeginCodeTool(ActiveSrcEdit,ActiveUnitInfo,[ctfSwitchToFormSource])
  then exit;
  {$IFDEF VerboseOnPropHookCreateMethod}
  debugln('');
  debugln('[TMainIDE.OnPropHookCreateMethod] ************ ',AMethodName);
  DebugLn(['  Persistent=',dbgsName(APersistent),' Unit=',GetClassUnitName(APersistent.ClassType),' Path=',APropertyPath]);
  {$ENDIF}
  if ActiveUnitInfo.Component=nil then begin
    {$IFDEF VerboseOnPropHookCreateMethod}
    debugln(['TMainIDE.OnPropHookCreateMethod failed ActiveUnitInfo.Component=nil']);
    {$ENDIF}
  end;

  InheritedMethodPath:=GetInheritedMethodPath;
  OldChange:=OpenEditorsOnCodeToolChange;
  OpenEditorsOnCodeToolChange:=true;
  UseRTTIForMethods:=FormEditor1.ComponentUsesRTTIForMethods(ActiveUnitInfo.Component);
  try
    // create published method
    {$IFDEF VerboseOnPropHookCreateMethod}
    debugln(['TMainIDE.OnPropHookCreateMethod CreatePublishedMethod ',ActiveUnitInfo.Source.Filename,' LookupRoot=',ActiveUnitInfo.Component.ClassName,' AMethodName="',AMethodName,'" PropertyUnit=',GetClassUnitName(APersistent.ClassType),' APropertyPath="',APropertyPath,'" CallInherited=',InheritedMethodPath]);
    {$ENDIF}
    r:=CodeToolBoss.CreatePublishedMethod(ActiveUnitInfo.Source,
        ActiveUnitInfo.Component.ClassName,AMethodName,
        ATypeInfo,UseRTTIForMethods,GetClassUnitName(APersistent.ClassType),APropertyPath,
        InheritedMethodPath);
    {$IFDEF VerboseOnPropHookCreateMethod}
    debugln(['[TMainIDE.OnPropHookCreateMethod] ************ ',dbgs(r),' AMethodName="',AMethodName,'"']);
    {$ENDIF}
    ApplyCodeToolChanges;
    if r then begin
      Result:=FormEditor1.CreateNewJITMethod(ActiveUnitInfo.Component,
                                             AMethodName);
    end else begin
      DebugLn(['TMainIDE.OnPropHookCreateMethod failed adding method "'+AMethodName+'" to source']);
      DoJumpToCodeToolBossError;
      raise Exception.Create(lisUnableToCreateNewMethod+' '+lisPleaseFixTheErrorInTheMessageWindow);
    end;
  finally
    OpenEditorsOnCodeToolChange:=OldChange;
  end;
end;

procedure TMainIDE.OnPropHookShowMethod(const AMethodName: String);
var
  ActiveSrcEdit: TSourceEditor;
  ActiveUnitInfo: TUnitInfo;
  NewSource: TCodeBuffer;
  NewX, NewY, NewTopLine: integer;
  AClassName: string;
  AInheritedMethodName: string;
  AnInheritedClassName: string;
  CurMethodName: String;
begin
  ActiveSrcEdit:=nil;
  if not BeginCodeTool(ActiveSrcEdit,ActiveUnitInfo,[ctfSwitchToFormSource])
  then exit;
  {$IFDEF IDE_DEBUG}
  debugln('');
  debugln('[TMainIDE.OnPropHookShowMethod] ************ "',AMethodName,'" ',ActiveUnitInfo.Filename);
  {$ENDIF}

  AClassName:=ActiveUnitInfo.Component.ClassName;
  CurMethodName:=AMethodName;

  if IsValidIdentPair(AMethodName,AnInheritedClassName,AInheritedMethodName)
  then begin
    ActiveSrcEdit:=nil;
    ActiveUnitInfo:=Project1.UnitWithComponentClassName(AnInheritedClassName);
    if ActiveUnitInfo=nil then begin
      IDEMessageDialog(lisMethodClassNotFound,
        Format(lisClassOfMethodNotFound, [AnInheritedClassName, AInheritedMethodName]),
        mtError,[mbCancel],'');
      exit;
    end;
    AClassName:=AnInheritedClassName;
    CurMethodName:=AInheritedMethodName;
  end;

  if CodeToolBoss.JumpToPublishedMethodBody(ActiveUnitInfo.Source,
    AClassName,CurMethodName,
    NewSource,NewX,NewY,NewTopLine) then
  begin
    DoJumpToCodePosition(ActiveSrcEdit, ActiveUnitInfo,
      NewSource, NewX, NewY, NewTopLine, [jfAddJumpPoint, jfFocusEditor]);
  end else begin
    DebugLn(['TMainIDE.OnPropHookShowMethod failed finding the method in code']);
    DoJumpToCodeToolBossError;
    raise Exception.Create(lisUnableToShowMethod+' '+lisPleaseFixTheErrorInTheMessageWindow);
  end;
end;

procedure TMainIDE.OnPropHookRenameMethod(const CurName, NewName: String);
var ActiveSrcEdit: TSourceEditor;
  ActiveUnitInfo: TUnitInfo;
  BossResult: boolean;
  ErrorMsg: String;
  OldChange: Boolean;
  RenamedMethods: TStringList;
begin
  ActiveSrcEdit:=nil;
  if not BeginCodeTool(ActiveSrcEdit,ActiveUnitInfo,[ctfSwitchToFormSource])
  then exit;
  {$IFDEF IDE_DEBUG}
  debugln('');
  debugln('[TMainIDE.OnPropHookRenameMethod] ************');
  {$ENDIF}
  OldChange:=OpenEditorsOnCodeToolChange;
  OpenEditorsOnCodeToolChange:=true;
  try
    // rename/create published method
    BossResult:=CodeToolBoss.RenamePublishedMethod(ActiveUnitInfo.Source,
                            ActiveUnitInfo.Component.ClassName,CurName,NewName);
    {$IFDEF IDE_DEBUG}
    debugln('');
    debugln('[TMainIDE.OnPropHookRenameMethod] ************2 ');
    {$ENDIF}
    ApplyCodeToolChanges;
    if BossResult then begin
      FormEditor1.RenameJITMethod(ActiveUnitInfo.Component,CurName,NewName);
      RenamedMethods:=TStringList.Create;
      try
        RenamedMethods.Add(CurName);
        RenamedMethods.Add(NewName);
        RenameInheritedMethods(ActiveUnitInfo,RenamedMethods);
      finally
        RenamedMethods.Free;
      end;
    end else begin
      ErrorMsg:=CodeToolBoss.ErrorMessage;
      DoJumpToCodeToolBossError;
      raise Exception.Create(
        lisUnableToRenameMethodPleaseFixTheErrorShownInTheMessag
        +LineEnding+LineEnding+lisError+ErrorMsg);
    end;
  finally
    OpenEditorsOnCodeToolChange:=OldChange;
  end;
end;

function TMainIDE.OnPropHookBeforeAddPersistent(Sender: TObject;
  APersistentClass: TPersistentClass; AParent: TPersistent): boolean;
var
  ActiveSrcEdit: TSourceEditor;
  ActiveUnitInfo: TUnitInfo;
  Code: TCodeBuffer;
  Tool: TCodeTool;
begin
  Result:=false;

  if (not (AParent is TControl))
  and (APersistentClass.InheritsFrom(TControl)) then begin
    IDEMessageDialog(lisCodeToolsDefsInvalidParent,
      Format(lisACanNotHoldTControlsYouCanOnlyPutNonVisualComponen,
             [AParent.ClassName, LineEnding]),
      mtError,[mbCancel]);
    {$IFDEF VerboseComponentPalette}
    DebugLn('***');
    DebugLn('** TMainIDE.OnPropHookBeforeAddPersistent: Calling UpdateIDEComponentPalette(false) **');
    {$ENDIF}
    // make sure the component palette shows only the available components
    UpdateIDEComponentPalette(false);
    exit;
  end;

  // check for syntax errors in unit interface
  ActiveSrcEdit:=nil;
  if not BeginCodeTool(ActiveSrcEdit,ActiveUnitInfo,[])
  then exit;
  Code:=ActiveUnitInfo.Source;
  if not CodeToolBoss.Explore(Code,Tool,false,true) then begin
    if JumpToCodetoolErrorAndAskToAbort(true)=mrAbort then exit;
  end;

  Result:=true;
end;

procedure TMainIDE.OnPropHookComponentRenamed(AComponent: TComponent);
begin
  FormEditor1.UpdateComponentName(AComponent);
  // Component can be renamed in designer and OI must be updated
  if ObjectInspector1<>nil then
    ObjectInspector1.Update;
end;

procedure TMainIDE.OnPropHookModified(Sender: TObject);
begin
  // any change of property can cause a change of a display name
  if ObjectInspector1<>nil then
    ObjectInspector1.FillPersistentComboBox;
end;

{-------------------------------------------------------------------------------
  procedure TMainIDE.OnPropHookPersistentAdded(APersistent: TPersistent;
    Select: boolean);

  This handler is called whenever a new component was added to a designed form
  and should be added to form source
-------------------------------------------------------------------------------}
procedure TMainIDE.OnPropHookPersistentAdded(APersistent: TPersistent; Select: boolean);
var
  RegComp: TRegisteredComponent;
  ADesigner: TDesigner;
  AComponent: TComponent;
  ActiveSrcEdit: TSourceEditor;
  ActiveUnitInfo: TUnitInfo;
  Ancestor: TComponent;
  ComponentClassNames: TStringList;
  ClassUnitInfo: TUnitInfo;
  i: Integer;
begin
  DebugLn('TMainIDE.OnPropHookPersistentAdded A ',dbgsName(APersistent));
  ADesigner:=nil;
  if APersistent is TComponent then
    AComponent:=TComponent(APersistent)
  else
    AComponent:=nil;
  RegComp:=IDEComponentPalette.FindComponent(APersistent.ClassName);
  if (RegComp=nil) and (AComponent<>nil) then begin
    ClassUnitInfo:=Project1.UnitWithComponentClass(TComponentClass(APersistent.ClassType));
    if ClassUnitInfo=nil then begin
      DebugLn('TMainIDE.OnPropHookPersistentAdded ',APersistent.ClassName,
              ' not registered');
      exit;
    end;
  end;
  if AComponent<>nil then begin
    // create unique name
    if AComponent.Name='' then
      AComponent.Name:=FormEditor1.CreateUniqueComponentName(AComponent);
    //debugln('TMainIDE.OnPropHookPersistentAdded B ',AComponent.Name,':',AComponent.ClassName);
    // set component into design mode
    SetDesigning(AComponent,true);
    //debugln('TMainIDE.OnPropHookPersistentAdded C ',AComponent.Name,':',AComponent.ClassName);
    // add to source
    ADesigner:=FindRootDesigner(AComponent) as TDesigner;
  end;

  if (ADesigner<>nil) and ((RegComp<>nil) or (ClassUnitInfo<>nil)) then begin
    ActiveSrcEdit:=nil;
    if not BeginCodeTool(ADesigner,ActiveSrcEdit,ActiveUnitInfo,[ctfSwitchToFormSource])
    then exit;

    // remember cursor position
    SourceEditorManager.AddJumpPointClicked(Self);

    // add needed package to required packages
    if ADesigner.LookupRoot.ComponentCount>0 then
    begin
      ComponentClassNames:=TStringList.Create;
      try
        for i:=0 to ADesigner.LookupRoot.ComponentCount-1 do
          ComponentClassNames.Add(ADesigner.LookupRoot.Components[i].ClassName);
        //DebugLn(['TMainIDE.OnPropHookPersistentAdded ComponentClassNames=',ComponentClassNames.Text]);
        PkgBoss.AddUnitDependenciesForComponentClasses(ActiveUnitInfo.Filename,
          ComponentClassNames,true);
      finally
        ComponentClassNames.Free;
      end;
    end;

    // add component definitions to form source
    Ancestor:=GetAncestorLookupRoot(ActiveUnitInfo);
    CodeToolBoss.CompleteComponent(ActiveUnitInfo.Source,ADesigner.LookupRoot,Ancestor);
  end;

  if ObjectInspector1<>nil then
    ObjectInspector1.FillPersistentComboBox;

  //debugln('TMainIDE.OnPropHookPersistentAdded D ',AComponent.Name,':',AComponent.ClassName,' ',Select);
  // select component
  if Select then begin
    TheControlSelection.AssignPersistent(APersistent);
  end;
  {$IFDEF IDE_DEBUG}
  debugln('TMainIDE.OnPropHookPersistentAdded END ',dbgsName(APersistent),' Select=',Select);
  {$ENDIF}
end;

procedure TMainIDE.OnPropHookDeletePersistent(var APersistent: TPersistent);
var
  ADesigner: TDesigner;
  AComponent: TComponent;
begin
  if APersistent=nil then exit;
  DebugLn('TMainIDE.OnPropHookDeletePersistent A ',dbgsName(APersistent));
  if APersistent is TComponent then begin
    AComponent:=TComponent(APersistent);
    ADesigner:=TDesigner(FindRootDesigner(AComponent));
    if ADesigner=nil then exit;
    ADesigner.RemovePersistentAndChilds(AComponent);
  end else begin
    APersistent.Free;
  end;
  APersistent:=nil;
end;

procedure TMainIDE.OnPropHookObjectPropertyChanged(Sender: TObject;
  NewObject: TPersistent);
var
  AnUnitInfo: TUnitInfo;
  NewComponent: TComponent;
  ReferenceDesigner: TIDesigner;
  ReferenceUnitInfo: TUnitInfo;
begin
  // check if a TPersistentPropertyEditor was changed
  if not (Sender is TPersistentPropertyEditor) then exit;
  if not (GlobalDesignHook.LookupRoot is TComponent) then exit;
  // find the current unit
  AnUnitInfo:=Project1.UnitWithComponent(TComponent(GlobalDesignHook.LookupRoot));
  if AnUnitInfo=nil then begin
    DebugLn(['TMainIDE.OnPropHookObjectPropertyChanged LookupRoot not found']);
    exit;
  end;
  // find the reference unit
  if (NewObject is TComponent) then begin
    NewComponent:=TComponent(NewObject);
    ReferenceDesigner:=FindRootDesigner(NewComponent);
    if ReferenceDesigner=nil then exit;
    ReferenceUnitInfo:=Project1.UnitWithComponent(ReferenceDesigner.LookupRoot);
    if ReferenceUnitInfo=nil then begin
      DebugLn(['TMainIDE.OnPropHookObjectPropertyChanged reference LookupRoot not found']);
      exit;
    end;
    if ReferenceUnitInfo<>AnUnitInfo then begin
      // another unit was referenced
      // ToDo: add CreateForm statement to main unit (.lpr)
      // At the moment the OI+PkgBoss only allow to use valid components,
      // so the CreateForm already exists.
    end;
  end;
end;

procedure TMainIDE.OnPropHookAddDependency(const AClass: TClass;
  const AnUnitName: shortstring);
// add a package dependency to the package/project of the currently active
// designed component.
var
  RequiredUnitName: String;
  AnUnitInfo: TUnitInfo;
begin
  // check input
  if AClass<>nil then begin
    RequiredUnitName:=GetClassUnitName(AClass);
    if (AnUnitName<>'')
    and (SysUtils.CompareText(AnUnitName,RequiredUnitName)<>0) then
      raise Exception.Create(
        'TMainIDE.OnPropHookAddDependency unitname and class do not fit:'
        +'unitname='+AnUnitName
        +' class='+dbgs(AClass)+' class.unitname='+RequiredUnitName);
  end else begin
    RequiredUnitName:=AnUnitName;
  end;
  if RequiredUnitName='' then
    raise Exception.Create('TMainIDE.OnPropHookAddDependency no unitname');

  // find current designer and unit
  if not (GlobalDesignHook.LookupRoot is TComponent) then exit;
  AnUnitInfo:=Project1.UnitWithComponent(TComponent(GlobalDesignHook.LookupRoot));
  if AnUnitInfo=nil then begin
    DebugLn(['TMainIDE.OnPropHookAddDependency LookupRoot not found']);
    exit;
  end;

  PkgBoss.AddDependencyToUnitOwners(AnUnitInfo.Filename,RequiredUnitName);
end;

procedure TMainIDE.OnPropHookGetComponentNames(TypeData: PTypeData; Proc: TGetStrProc);
begin
  PkgBoss.IterateComponentNames(GlobalDesignHook.LookupRoot,TypeData,Proc);
end;

function TMainIDE.OnPropHookGetComponent(const ComponentPath: String): TComponent;
begin
  Result:=PkgBoss.FindUsableComponent(GlobalDesignHook.LookupRoot,ComponentPath);
end;

procedure TMainIDE.mnuEditCopyClicked(Sender: TObject);
var
  ActiveDesigner: TComponentEditorDesigner;
begin
  ActiveDesigner := GetActiveDesignerSkipMainBar;
  if Assigned(ActiveDesigner) then
    ActiveDesigner.CopySelection
  else
    DoSourceEditorCommand(ecCopy);
end;

procedure TMainIDE.mnuEditCutClicked(Sender: TObject);
var
  ActiveDesigner: TComponentEditorDesigner;
begin
  ActiveDesigner := GetActiveDesignerSkipMainBar;
  if Assigned(ActiveDesigner) then
    ActiveDesigner.CutSelection
  else
    DoSourceEditorCommand(ecCut);
end;

procedure TMainIDE.mnuEditPasteClicked(Sender: TObject);
var
  ActiveDesigner: TComponentEditorDesigner;
begin
  ActiveDesigner := GetActiveDesignerSkipMainBar;
  if Assigned(ActiveDesigner) then
    ActiveDesigner.PasteSelection([cpsfFindUniquePositions])
  else
    DoSourceEditorCommand(ecPaste);
end;

procedure TMainIDE.mnuEditRedoClicked(Sender: TObject);
var
  ActiveDesigner: TComponentEditorDesigner;
begin
  ActiveDesigner := GetActiveDesignerSkipMainBar;
  if Assigned(ActiveDesigner) then
    ActiveDesigner.Redo
  else
    DoSourceEditorCommand(ecRedo);
end;

procedure TMainIDE.mnuEditUndoClicked(Sender: TObject);
var
  ActiveDesigner: TComponentEditorDesigner;
begin
  ActiveDesigner := GetActiveDesignerSkipMainBar;
  if Assigned(ActiveDesigner) then
    ActiveDesigner.Undo
  else
    DoSourceEditorCommand(ecUndo);
end;

procedure TMainIDE.mnuEditIndentBlockClicked(Sender: TObject);
begin
  DoSourceEditorCommand(ecBlockIndent);
end;

procedure TMainIDE.mnuEditUnindentBlockClicked(Sender: TObject);
begin
  DoSourceEditorCommand(ecBlockUnindent);
end;

procedure TMainIDE.mnuSourceEncloseBlockClicked(Sender: TObject);
begin
  DoSourceEditorCommand(ecSelectionEnclose);
end;

procedure TMainIDE.mnuEditUpperCaseBlockClicked(Sender: TObject);
begin
  DoSourceEditorCommand(ecSelectionUpperCase);
end;

procedure TMainIDE.mnuEditLowerCaseBlockClicked(Sender: TObject);
begin
  DoSourceEditorCommand(ecSelectionLowerCase);
end;

procedure TMainIDE.mnuEditSwapCaseBlockClicked(Sender: TObject);
begin
  DoSourceEditorCommand(ecSelectionSwapCase);
end;

procedure TMainIDE.mnuEditTabsToSpacesBlockClicked(Sender: TObject);
begin
  DoSourceEditorCommand(ecSelectionTabs2Spaces);
end;

procedure TMainIDE.mnuSourceCommentBlockClicked(Sender: TObject);
begin
  DoSourceEditorCommand(ecSelectionComment);
end;

procedure TMainIDE.mnuSourceUncommentBlockClicked(Sender: TObject);
begin
  DoSourceEditorCommand(ecSelectionUncomment);
end;

procedure TMainIDE.mnuSourceToggleCommentClicked(Sender: TObject);
begin
  DoSourceEditorCommand(ecToggleComment);
end;

procedure TMainIDE.mnuSourceEncloseInIFDEFClicked(Sender: TObject);
begin
  DoSourceEditorCommand(ecSelectionEncloseIFDEF);
end;

procedure TMainIDE.mnuEditSortBlockClicked(Sender: TObject);
begin
  // MG: sometimes the function does nothing
  debugln(['TMainIDE.mnuEditSortBlockClicked ',DbgSName(FindOwnerControl(GetFocus))]);
  DoSourceEditorCommand(ecSelectionSort);
end;

procedure TMainIDE.mnuEditSelectionBreakLinesClicked(Sender: TObject);
begin
  DoSourceEditorCommand(ecSelectionBreakLines);
end;

procedure TMainIDE.mnuEditSelectAllClick(Sender: TObject);
begin
  DoSourceEditorCommand(ecSelectAll);
end;

procedure TMainIDE.mnuEditSelectCodeBlockClick(Sender: TObject);
begin
  DoSourceEditorCommand(ecSelectCodeBlock);
end;

procedure TMainIDE.mnuEditSelectToBraceClick(Sender: TObject);
begin
  DoSourceEditorCommand(ecSelectToBrace);
end;

procedure TMainIDE.mnuEditSelectWordClick(Sender: TObject);
begin
  DoSourceEditorCommand(ecSelectWord);
end;

procedure TMainIDE.mnuEditSelectLineClick(Sender: TObject);
begin
  DoSourceEditorCommand(ecSelectLine);
end;

procedure TMainIDE.mnuEditSelectParagraphClick(Sender: TObject);
begin
  DoSourceEditorCommand(ecSelectParagraph);
end;

procedure TMainIDE.mnuSourceInsertGPLNoticeClick(Sender: TObject);
begin
  DoSourceEditorCommand(ecInsertGPLNotice);
end;

procedure TMainIDE.mnuSourceInsertGPLNoticeTranslatedClick(Sender: TObject);
begin
  DoSourceEditorCommand(ecInsertGPLNoticeTranslated);
end;

procedure TMainIDE.mnuSourceInsertLGPLNoticeClick(Sender: TObject);
begin
  DoSourceEditorCommand(ecInsertLGPLNotice);
end;

procedure TMainIDE.mnuSourceInsertLGPLNoticeTranslatedClick(Sender: TObject);
begin
  DoSourceEditorCommand(ecInsertLGPLNoticeTranslated);
end;

procedure TMainIDE.mnuSourceInsertModifiedLGPLNoticeClick(Sender: TObject);
begin
  DoSourceEditorCommand(ecInsertModifiedLGPLNotice);
end;

procedure TMainIDE.mnuSourceInsertModifiedLGPLNoticeTranslatedClick(
  Sender: TObject);
begin
  DoSourceEditorCommand(ecInsertModifiedLGPLNoticeTranslated);
end;

procedure TMainIDE.mnuSourceInsertMITNoticeClick(Sender: TObject);
begin
  DoSourceEditorCommand(ecInsertMITNotice);
end;

procedure TMainIDE.mnuSourceInsertMITNoticeTranslatedClick(Sender: TObject);
begin
  DoSourceEditorCommand(ecInsertMITNoticeTranslated);
end;

procedure TMainIDE.mnuSourceInsertUsernameClick(Sender: TObject);
begin
  DoSourceEditorCommand(ecInsertUserName);
end;

procedure TMainIDE.mnuSourceInsertDateTimeClick(Sender: TObject);
begin
  DoSourceEditorCommand(ecInsertDateTime);
end;

procedure TMainIDE.mnuSourceInsertChangeLogEntryClick(Sender: TObject);
begin
  DoSourceEditorCommand(ecInsertChangeLogEntry);
end;

procedure TMainIDE.mnuSourceInsertGUID(Sender: TObject);
begin
  DoSourceEditorCommand(ecInsertGUID);
end;

procedure TMainIDE.mnuSourceInsertFilename(Sender: TObject);
begin
  DoSourceEditorCommand(ecInsertFilename);
end;

procedure TMainIDE.mnuSearchFindInFiles(Sender: TObject);
begin
  DoFindInFiles;
end;

procedure TMainIDE.mnuSearchFindIdentifierRefsClicked(Sender: TObject);
begin
  DoFindRenameIdentifier(false);
end;

procedure TMainIDE.mnuEditInsertCharacterClicked(Sender: TObject);
begin
  DoSourceEditorCommand(ecInsertCharacter);
end;

procedure TMainIDE.mnuSourceInsertCVSAuthorClick(Sender: TObject);
begin
  DoSourceEditorCommand(ecInsertCVSAuthor);
end;

procedure TMainIDE.mnuSourceInsertCVSDateClick(Sender: TObject);
begin
  DoSourceEditorCommand(ecInsertCVSDate);
end;

procedure TMainIDE.mnuSourceInsertCVSHeaderClick(Sender: TObject);
begin
  DoSourceEditorCommand(ecInsertCVSHeader);
end;

procedure TMainIDE.mnuSourceInsertCVSIDClick(Sender: TObject);
begin
  DoSourceEditorCommand(ecInsertCVSID);
end;

procedure TMainIDE.mnuSourceInsertCVSLogClick(Sender: TObject);
begin
  DoSourceEditorCommand(ecInsertCVSLog);
end;

procedure TMainIDE.mnuSourceInsertCVSNameClick(Sender: TObject);
begin
  DoSourceEditorCommand(ecInsertCVSName);
end;

procedure TMainIDE.mnuSourceInsertCVSRevisionClick(Sender: TObject);
begin
  DoSourceEditorCommand(ecInsertCVSRevision);
end;

procedure TMainIDE.mnuSourceInsertCVSSourceClick(Sender: TObject);
begin
  DoSourceEditorCommand(ecInsertCVSSource);
end;

procedure TMainIDE.mnuSourceCompleteCodeClicked(Sender: TObject);
begin
  DoCompleteCodeAtCursor;
end;

procedure TMainIDE.mnuSourceUseUnitClicked(Sender: TObject);
begin
  DoSourceEditorCommand(ecUseUnit);
end;

procedure TMainIDE.mnuRefactorRenameIdentifierClicked(Sender: TObject);
begin
  DoFindRenameIdentifier(true);
end;

procedure TMainIDE.mnuRefactorExtractProcClicked(Sender: TObject);
begin
  DoExtractProcFromSelection;
end;

procedure TMainIDE.mnuRefactorInvertAssignmentClicked(Sender: TObject);
begin
  DoSourceEditorCommand(ecInvertAssignment);
end;

procedure TMainIDE.mnuRefactorShowAbstractMethodsClicked(Sender: TObject);
begin
  DoSourceEditorCommand(ecShowAbstractMethods);
end;

procedure TMainIDE.mnuRefactorShowEmptyMethodsClicked(Sender: TObject);
begin
  DoSourceEditorCommand(ecRemoveEmptyMethods);
end;

procedure TMainIDE.mnuRefactorShowUnusedUnitsClicked(Sender: TObject);
begin
  DoSourceEditorCommand(ecRemoveUnusedUnits);
end;

procedure TMainIDE.mnuRefactorFindOverloadsClicked(Sender: TObject);
begin
  DoSourceEditorCommand(ecFindOverloads);
end;

procedure TMainIDE.DoCommand(ACommand: integer);
var
  ActiveSourceEditor: TSourceEditor;
  ActiveUnitInfo: TUnitInfo;
  AForm: TCustomForm;
begin
  // todo: if focus is really on a designer or the source editor
  GetCurrentUnit(ActiveSourceEditor,ActiveUnitInfo);
  case DisplayState of
    dsSource:                // send command to source editor
      if Assigned(ActiveSourceEditor) then
        ActiveSourceEditor.DoEditorExecuteCommand(ACommand);
    dsForm:                  // send command to form editor
      begin
        if LastFormActivated <> nil then
          GetUnitWithForm(LastFormActivated, ActiveSourceEditor, ActiveUnitInfo);
        if Assigned(ActiveUnitInfo) then begin
          AForm:=GetDesignerFormOfSource(ActiveUnitInfo,False);
          if AForm<>nil then ;
          // ToDo: call designer
        end;
      end;
  end;
end;

procedure TMainIDE.DoSourceEditorCommand(EditorCommand: integer;
  CheckFocus: boolean; FocusEditor: boolean);
var
  CurFocusControl: TWinControl;
  ActiveSourceEditor: TSourceEditor;
  ActiveUnitInfo: TUnitInfo;
begin
  CurFocusControl:=Nil;
  ActiveSourceEditor:=Nil;
  // check if focus is on MainIDEBar or on SourceEditor
  if CheckFocus then
  begin
    CurFocusControl:=FindOwnerControl(GetFocus);
    while (CurFocusControl<>nil) and (CurFocusControl<>MainIDEBar)
    and not (CurFocusControl is TSourceNotebook) do
      CurFocusControl:=CurFocusControl.Parent;
  end;
  if Assigned(CurFocusControl) then
  begin    // MainIDEBar or SourceNotebook has focus -> find active source editor
    GetCurrentUnit(ActiveSourceEditor,ActiveUnitInfo);
    if Assigned(ActiveSourceEditor) then begin
      ActiveSourceEditor.DoEditorExecuteCommand(EditorCommand); // pass the command
      if FocusEditor then
        ActiveSourceEditor.EditorControl.SetFocus;
    end;
  end;
  // Some other window has focus -> continue processing shortcut, not handled yet
  if (CurFocusControl=Nil) or (ActiveSourceEditor=Nil) then
    MainIDEBar.mnuMainMenu.ShortcutHandled := false;
end;

procedure TMainIDE.StartProtocol;
begin
  IDEProtocolOpts:=TIDEProtocol.Create;
  IDEProtocolOpts.Load;
end;

procedure TMainIDE.mnuSearchFindBlockOtherEnd(Sender: TObject);
begin
  DoGoToPascalBlockOtherEnd;
end;

procedure TMainIDE.mnuSearchFindBlockStart(Sender: TObject);
begin
  DoGoToPascalBlockStart;
end;

procedure TMainIDE.mnuSearchFindDeclaration(Sender: TObject);
begin
  DoFindDeclarationAtCursor;
end;


initialization
  {$IFDEF IDE_MEM_CHECK}CheckHeapWrtMemCnt('main.pp: initialization');{$ENDIF}
  ShowSplashScreen:=true;
  DebugLogger.ParamForEnabledLogGroups := '--debug-enable=';
end.


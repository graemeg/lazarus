{
 *****************************************************************************
  See the file COPYING.modifiedLGPL.txt, included in this distribution,
  for details about the license.
 *****************************************************************************

  Author: Mattias Gaertner

  Abstract:
    Interface to the general IDE functions.
}
unit LazIDEIntf;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils,
  // LCL
  Forms, Controls, LazHelpHTML,
  // LazUtils
  UITypes, LazMethodList,
  // BuildIntf
  BaseIDEIntf, IDEOptionsIntf, CompOptsIntf, ProjectIntf, IDEExternToolIntf,
  // IdeIntf
  IDEOptEditorIntf, SrcEditorIntf, IDEWindowIntf;

type
  TIDEDirective = (
    idedNone,
    idedBuildCommand,  // Filename plus params to build the file
                       //   default is '$(CompPath) $(EdFile)'
    idedBuildWorkingDir,// Working directory for building. Default is the
                       //   directory of the file
    idedBuildScan,     // Flags controlling what messages should be scanned for
                       //   during building. See TIDEDirBuildScanFlag.
    idedRunCommand,    // Filename plus params to run the file
                       //   default is '$NameOnly($(EdFile))'
    idedRunWorkingDir, // Working directory for building. Default is the
                       //   directory of the file
    idedRunFlags       // Flags for run. See TIDEDirRunFlag
    );
  TIDEDirectives = set of TIDEDirective;

  TIDEDirBuildScanFlag = (
    idedbsfNone,
    idedbsfFPC, // scan for FPC messages. FPC+ means on (default) and FPC- off.
    idedbsfMake // scan for MAKE messages. MAKE- means on (default) and MAKE- off.
    );
  TIDEDirBuildScanFlags = set of TIDEDirBuildScanFlag;

  TIDEDirRunFlag = (
    idedrfNone,
    idedrfBuildBeforeRun, // BUILD+ means on (default for non script), BUILD- means off
    idedrfMessages // show output in Messages window
    );
  TIDEDirRunFlags = set of TIDEDirRunFlag;
const
  IDEDirectiveNames: array[TIDEDirective] of string = (
    '',
    'BuildCommand',
    'BuildWorkingDir',
    'BuildScan',
    'RunCommand',
    'RunWorkingDir',
    'RunFlags'
    );
  IDEDirBuildScanFlagNames: array[TIDEDirBuildScanFlag] of string = (
    '',
    'FPC',
    'MAKE'
    );
  IDEDirRunFlagNames: array[TIDEDirRunFlag] of string = (
    '',
    'BUILD',
    'MESSAGES'
    );

type
  // open file flags
  // Normally you don't need to pass any flags.
  TOpenFlag = (
    ofProjectLoading,// this open is part of opening a whole project
    ofOnlyIfExists,  // do not auto create non existing files
    ofRevert,        // reload file if already open, any user changes are lost without question
    ofQuiet,         // less messages
    ofAddToRecent,   // add file to recent files
    ofRegularFile,   // open as regular file (e.g. do not open projects/packages)
    ofVirtualFile,   // open the virtual file
    ofConvertMacros, // replace macros in filename
    ofUseCache,      // do not update file from disk
    ofMultiOpen,     // set during loading multiple files
    ofDoNotLoadResource,// do not open form, datamodule, ... (overriding default)
    ofDoLoadResource,// do open form, datamodule, ... (overriding default)
    ofLoadHiddenResource,// load component hidden
    ofAddToProject,  // add file to project (if exists)
    ofInternalFile   // opening data from an internal source (e.g. an editor macro (pascal script) from memory)
    );
  TOpenFlags = set of TOpenFlag;

const
  OpnFlagsPlainFile = [ofOnlyIfExists,ofQuiet,ofRegularFile,ofVirtualFile,ofDoNotLoadResource];
type
  // new file flags
  // Normally you don't need to pass any flags.
  TNewFlag = (
    nfIsPartOfProject, // force IsPartOfProject,
                       //   default is to use a heuristic
    nfIsNotPartOfProject,// forbid IsPartOfProject
    nfOpenInEditor,    // open in editor
    nfSave,            // save file instantly
    nfAddToRecent,     // add file to recent files
    nfQuiet,           // less messages
    nfConvertMacros,   // replace macros in filename
    nfBeautifySrc,     // beautify custom source
    nfCreateDefaultSrc,// create initial source based on the type
    nfAskForFilename   // ask for filename
    );
  TNewFlags = set of TNewFlag;

  // save file flags
  // Normally you don't need to pass any flags.
  TSaveFlag = (
    sfSaveAs,
    sfSaveToTestDir,
    sfProjectSaving,
    sfCheckAmbiguousFiles,
    sfSaveNonProjectFiles,
    sfDoNotSaveVirtualFiles,
    sfCanAbort,  // show 'Cancel all' button in error messages
    sfSaveMainSourceAs,  // on sfSaveAs use .lpr file instead of .lpi file
    sfQuietUnitCheck     // don't ask questions when adding unit dependency.
    );
  TSaveFlags = set of TSaveFlag;
  
  // close file flags
  // Normally you don't need to pass any flags.
  TCloseFlag = (
    cfSaveFirst, // check if modified and save
    cfQuiet,
    cfProjectClosing,
    cfCloseDependencies,
    cfSaveDependencies // set cfSaveFirst to close the dependencies
    );
  TCloseFlags = set of TCloseFlag;

  // build project flags
  // Normally you don't need to pass any flags.
  TProjectBuildFlag = (
    pbfDoNotCompileDependencies,
    pbfDoNotCompileProject,
    pbfCompileDependenciesClean,
    pbfDoNotSaveEditorFiles,
    pbfSkipLinking,
    pbfSkipAssembler,
    pbfSkipTools,
    pbfCreateMakefile
    );
  TProjectBuildFlags = set of TProjectBuildFlag;
  
  // new filename flags
  // Normally you don't need to pass any flags.
  TSearchIDEFileFlag = (
    siffDoNotCheckAllPackages, // do not search filename in unrelated packages (e.g. installed but not used by project)
    siffCheckAllProjects, // search filename in all loaded projects
    siffCaseSensitive,  // check case sensitive, otherwise use Pascal case insensitivity (CompareText)
    siffDoNotCheckOpenFiles,  // do not search in files opened in source editor
    siffIgnoreExtension  // compare only filename, ignore file extension
    );
  TSearchIDEFileFlags = set of TSearchIDEFileFlag;

  // find unit flags
  // Normally you don't need to pass any flags.
  TFindUnitFileFlag = (
    fuffIgnoreUninstallPackages
    );
  TFindUnitFileFlags = set of TFindUnitFileFlag;

  // selected part of IDE
  TTabDisplayState = (
    tdsNone,
    tdsCode,     // focussing sourcenotebook or source tab
    tdsDesign,   // focussing designer form/design tab
    tdsOther     // focussing other (user defined) tab assigned to module (like History Tab)
    );

  // find source flags
  // Normally you don't need to pass any flags.
  TFindSourceFlag = (
    fsfSearchForProject,
    fsfUseIncludePaths,
    fsfUseDebugPath,
    fsfMapTempToVirtualFiles,
    fsfSkipPackages
    );
  TFindSourceFlags = set of TFindSourceFlag;

  TFindUnitsOfOwnerFlag = (
    fuooListed, // add units listed in lpi/lpk aka project inspector/package editor
    fuooUsed,   // add units used by main source file (depends on current build mode and environment)
    fuooPackages, // extends fuooListed and fuooUsed by units from used packages
    fuooSourceEditor // add units in source editor
    );
  TFindUnitsOfOwnerFlags = set of TFindUnitsOfOwnerFlag;
  
  TModalResultFunction = function(Sender: TObject): TModalResult of object;
  TLazProjectChangedFunction = function(Sender: TObject;
                                 AProject: TLazProject): TModalResult of object;
  TModalHandledFunction = function(Sender: TObject; var Handled: boolean
                              ): TModalResult of object;
  TGetFPCFrontEndParams = function(Sender: TObject;
    var Params: string // these parameters are passed to fpc.
      // Global options should be prependended, project options should be appended.
    ): boolean of object;

  TSaveEditorFileStep = (
    sefsSaveAs, // called after user selected a new filename and IDE did some sanity checks
    sefsBeforeWrite, // called before writing to disk, aFile.Filename=TargetFilename
    sefsAfterWrite, // called after writing to disk, aFile.Filename=TargetFilename
    sefsSavedAs // see sefsSaveAs, called after writing and cleaning up, TargetFilename is old filename
    );
  TSaveEditorFileEvent = function(Sender: TObject; aFile: TLazProjectFile;
    SaveStep: TSaveEditorFileStep; TargetFilename: string): TModalResult of object;

  TShowDesignerFormOfSourceFunction = procedure(Sender: TObject; AEditor: TSourceEditorInterface;
                                 AComponentPaletteClassSelected: Boolean) of object;
  TGetFPCFrontEndPath = function(Sender: TObject;
    var Path: string // this path is prepended to fpc.
    ): boolean of object;

  TLazarusIDEHandlerType = (
    lihtSavingAll, // called before IDE saves everything
    lihtSavedAll,  // called after IDE saved everything
    lihtSaveEditorFile, // called when IDE saves an editor file to disk
    lihtSaveAsEditorFile, // called after user selected a new filename for an editor file
    lihtIDERestoreWindows, // called when IDE is restoring the windows (before opening the first project)
    lihtIDEClose, // called when IDE is shutting down (after closequery, so no more interactivity)
    lihtProjectOpening,// called before IDE opens a project
    lihtProjectOpened,// called after IDE opened a project
    lihtProjectClose, // called before IDE closes a project
    lihtProjectBuilding, // called before IDE builds the project
    lihtProjectDependenciesCompiling, // called before IDE compiles dependencies of project
    lihtProjectDependenciesCompiled, // called after IDE compiled dependencies of project
    lihtProjectBuildingFinished, // called after IDE builds the project
    lihtLazarusBuilding, // called before IDE builds Lazarus IDE
    lihtLazarusBuildingFinished, // called after IDE builds Lazarus IDE
    lihtQuickSyntaxCheck,  // called when quick syntax check is clicked (menu item or shortcut)
    lihtGetFPCFrontEndParams, // called when the IDE gets the parameters of the 'fpc' front end tool
    lihtGetFPCFrontEndPath, // called when the IDE gets the path of the 'fpc' front end tool
    lihtShowDesignerFormOfSource, // called after showing a designer form for code editor (AEditor can be nil!)
    lihtShowSourceOfActiveDesignerForm, // called after showing a code of designer form
    lihtChangeToolStatus, //called when IDEToolStatus has changed (e.g. itNone->itBuilder etc.)
    lihtRunDebugInit, // called when Run was clicked, after building, before debugger class is initialized
    lihtRunDebug, // called when Run was clicked, after building, after debugger class was initialized, before starting the debugger
    lihtRunWithoutDebugBuilding, // called when Run a project without debugger was clicked, before building
    lihtRunWithoutDebugInit, // called when Run a project without debugger was clicked, after building
    lihtRunFinished //called when ran program finishes
    );
    
  TLazToolStatus = (
    itNone,            // The default mode. All editing allowed.
    itExiting,         // the ide is shutting down
    itBuilder,         // compiling (the project, a package, IDE itself, an external tool)
                       //    Loading/Saving/Debugging is not allowed.
    itDebugger,        // debugging the project.
                       //    Loading/Saving/Compiling is not allowed.
    itCodeTools,       // the CodeToolBoss is working and has called the progress event.
    itCodeToolAborting,// the CodeToolBoss is working and is about to abort
    itCustom           // this state is not used yet.
    );
  TLazToolStatusChangeEvent = procedure(Sender: TObject; OldStatus, NewStatus: TLazToolStatus) of object;

  TLazBuildingFinishedEvent = procedure(Sender: TObject; BuildSuccessful: Boolean) of object;

  { TLazIDEInterface }

  TLazIDEInterface = class(TComponent)
  private
    FToolStatus: TLazToolStatus;
    FMainBarSubTitle: string;
    FOpenEditorsOnCodeToolChange: boolean;
    FOpenMainSourceOnCodeToolChange: boolean;
    FSaveClosedSourcesOnCodeToolChange: boolean;
    FCheckFilesOnDiskEnabled: boolean;
    procedure AddHandler(HandlerType: TLazarusIDEHandlerType;
                         const AMethod: TMethod; AsLast: boolean = false);
    procedure RemoveHandler(HandlerType: TLazarusIDEHandlerType;
                            const AMethod: TMethod);
  protected
    FLazarusIDEHandlers: array[TLazarusIDEHandlerType] of TMethodList;
    FOwningComponent: TComponent;
    FIDEStarted: boolean;
    FIDEIsClosing: Boolean;
    FLastActivatedWindows: TFPList;
    // used to find the last form so you can display the correct tab
    FLastFormActivated: TCustomForm;

    procedure SetToolStatus(const AToolStatus: TLazToolStatus); virtual;
    function GetActiveProject: TLazProject; virtual; abstract;
    procedure DoCallNotifyHandler(HandlerType: TLazarusIDEHandlerType); overload;
    function DoCallModalFunctionHandler(HandlerType: TLazarusIDEHandlerType
                                        ): TModalResult;
    function DoCallModalHandledHandler(HandlerType: TLazarusIDEHandlerType;
                                       var Handled: boolean): TModalResult;
    procedure DoCallNotifyHandler(HandlerType: TLazarusIDEHandlerType;
                                  Sender: TObject); overload;
    procedure DoCallShowDesignerFormOfSourceHandler(Sender: TObject;
      AEditor: TSourceEditorInterface; AComponentPaletteClassSelected: Boolean);
    procedure DoCallBuildingFinishedHandler(HandlerType: TLazarusIDEHandlerType;
      Sender: TObject; BuildSuccessful: Boolean);

    procedure SetMainBarSubTitle(const AValue: string); virtual;
  public
    constructor Create(TheOwner: TComponent); override;
    destructor Destroy; override;
    property OwningComponent: TComponent read FOwningComponent;
    
    property ToolStatus: TLazToolStatus read FToolStatus write SetToolStatus;

    // the main window with the IDE menu
    function GetMainBar: TForm; virtual; abstract;
    property MainBarSubTitle: string read FMainBarSubTitle write SetMainBarSubTitle;

    // find file
    function FindUnitFile(const AFilename: string; TheOwner: TObject = nil;
                          Flags: TFindUnitFileFlags = []): string; virtual; abstract;
    function FindSourceFile(const AFilename, BaseDirectory: string;
                            Flags: TFindSourceFlags): string; virtual; abstract;

    // file
    function DoNewEditorFile(NewFileDescriptor: TProjectFileDescriptor;
                             NewFilename: string; const NewSource: string;
                             NewFlags: TNewFlags): TModalResult;
    function DoNewFile(NewFileDescriptor: TProjectFileDescriptor;
                       var NewFilename: string; NewSource: string;
                       NewFlags: TNewFlags; NewOwner: TObject): TModalResult; virtual; abstract;
    function DoSaveEditorFile(AEditor: TSourceEditorInterface;
                              Flags: TSaveFlags): TModalResult; virtual; abstract;
    function DoSaveEditorFile(const Filename: string;
                              Flags: TSaveFlags): TModalResult; virtual; abstract;
    function DoSaveAll(Flags: TSaveFlags): TModalResult; virtual; abstract;
    function DoCloseEditorFile(AEditor: TSourceEditorInterface;
                               Flags: TCloseFlags):TModalResult; virtual; abstract;
    function DoCloseEditorFile(const Filename: string;
                               Flags: TCloseFlags): TModalResult; virtual; abstract;
    function DoOpenEditorFile(AFileName:string; PageIndex, WindowIndex: integer;
                              Flags: TOpenFlags): TModalResult; virtual; abstract;
    function DoOpenFileAndJumpToIdentifier(const AFilename, AnIdentifier: string;
                       PageIndex, WindowIndex: integer; Flags: TOpenFlags): TModalResult; virtual; abstract;
    function DoOpenFileAndJumpToPos(const AFilename: string;
                       const CursorPosition: TPoint; TopLine: integer;
                       PageIndex, WindowIndex: integer; Flags: TOpenFlags): TModalResult; overload;
    function DoOpenFileAndJumpToPos(const AFilename: string;
                       const CursorPosition: TPoint; TopLine, BlockTopLine, BlockBottomLine: integer;
                       PageIndex, WindowIndex: integer; Flags: TOpenFlags): TModalResult; virtual; abstract; overload;
    function DoRevertEditorFile(const Filename: string): TModalResult; virtual; abstract;
    function DoOpenComponent(const UnitFilename: string; OpenFlags: TOpenFlags;
                       CloseFlags: TCloseFlags;
                       out Component: TComponent): TModalResult; virtual; abstract;
    procedure DoDropFiles(Sender: TObject; const FileNames: array of String;
      WindowIndex: integer = -1); virtual; abstract;
    function DoConfigureBuildFile: TModalResult; virtual; abstract;
    function DoBuildFile({%H-}ShowAbort: Boolean;
      Filename: string = '' // if empty use active source editor file
      ): TModalResult; virtual; abstract;
    function DoRunFile(Filename: string = '' // if empty use active source editor file
      ): TModalResult; virtual; abstract;

    // project
    property ActiveProject: TLazProject read GetActiveProject;
    function DoNewProject(ProjectDesc: TProjectDescriptor): TModalResult; virtual; abstract;
    function DoSaveProject(Flags: TSaveFlags): TModalResult; virtual; abstract;
    function DoCloseProject: TModalResult; virtual; abstract;
    function DoOpenProjectFile(AFileName: string;
                               Flags: TOpenFlags): TModalResult; virtual; abstract;
    function DoPublishProject(Flags: TSaveFlags;
                              ShowDialog: boolean): TModalResult; virtual; abstract;
    function DoBuildProject(const AReason: TCompileReason;
                            Flags: TProjectBuildFlags;
                            FinalizeResources: boolean = True): TModalResult; virtual; abstract;
    function DoRunProject: TModalResult; virtual; abstract;
    function DoRunProjectWithoutDebug: TModalResult; virtual; abstract;
    function GetProjectFileForProjectEditor(AEditor: TSourceEditorInterface): TLazProjectFile; virtual; abstract;
    function DoCallProjectChangedHandler(HandlerType: TLazarusIDEHandlerType;
                                         AProject: TLazProject): TModalResult;
    function DoCallRunDebugInit(var Handled: boolean): TModalResult;
    function DoCallRunDebug(var Handled: boolean): TModalResult;
    function DoCallRunWithoutDebugBuilding(var Handled: boolean): TModalResult;
    function DoCallRunWithoutDebugInit(var Handled: boolean): TModalResult;
    procedure DoCallRunFinishedHandler;
    function DoAddUnitToProject(AEditor: TSourceEditorInterface): TModalResult; virtual; abstract;

    // configs
    class function GetPrimaryConfigPath: String; virtual; abstract;
    class function GetSecondaryConfigPath: String; virtual; abstract;
    procedure CopySecondaryConfigFile(const AFilename: String); virtual; abstract;
    function DoOpenIDEOptions(AEditor: TAbstractIDEOptionsEditorClass = nil;
      ACaption: String = ''): Boolean; overload;
    function DoOpenIDEOptions(AEditor: TAbstractIDEOptionsEditorClass;
      ACaption: String; AOptionsFilter: array of TAbstractIDEOptionsClass;
      ASettings: TIDEOptionsEditorSettings): Boolean; overload; virtual; abstract;

    // filenames, paths
    function CreateNewUniqueFilename(const Prefix, Ext: string;
                          NewOwner: TObject; Flags: TSearchIDEFileFlags;
                          TryWithoutNumber: boolean): string; virtual; abstract;
    function GetTestBuildDirectory: string; virtual; abstract;
    function GetCompilerFilename: string; virtual; abstract;
    function GetFPCompilerFilename: string; virtual; abstract;
    function GetFPCFrontEndOptions: string; virtual; abstract;

    // codetools
    function BeginCodeTools: boolean; virtual; abstract;
    function DoShowCodeToolBossError: TMessageLine; virtual; abstract;
    procedure DoJumpToCodeToolBossError; virtual; abstract;
    function NeedSaveSourceEditorChangesToCodeCache(AEditor: TSourceEditorInterface): boolean; virtual; abstract;
    function SaveSourceEditorChangesToCodeCache(AEditor: TSourceEditorInterface): boolean; virtual; abstract; // true if something was saved
    function FindUnitsOfOwner(TheOwner: TObject; Flags: TFindUnitsOfOwnerFlags): TStrings; virtual; abstract;
    property OpenEditorsOnCodeToolChange: boolean read FOpenEditorsOnCodeToolChange
                                             write FOpenEditorsOnCodeToolChange;
    property SaveClosedSourcesOnCodeToolChange: boolean read FSaveClosedSourcesOnCodeToolChange
                                             write FSaveClosedSourcesOnCodeToolChange;
    property OpenMainSourceOnCodeToolChange: boolean read FOpenMainSourceOnCodeToolChange
                                             write FOpenMainSourceOnCodeToolChange;

    // progress and error messages
    function ShowProgress(const SomeText: string;
      Step, MaxStep: integer): boolean; virtual; abstract; // False if canceled by user
    function GetSelectedCompilerMessage: TMessageLine; virtual; abstract;
    function DoJumpToCompilerMessage(FocusEditor: boolean;
                              Msg: TMessageLine = nil // if nil then it jumps to first message
                              ): boolean; virtual; abstract;
    procedure DoJumpToNextCompilerMessage(aMinUrgency: TMessageLineUrgency; DirectionDown: boolean); virtual; abstract;
    procedure DoJumpToNextError(DirectionDown: boolean);
    procedure DoShowMessagesView(BringToFront: boolean = true); virtual; abstract;
    function DoCheckFilesOnDisk(Instantaneous: boolean = false): TModalResult; virtual; abstract;
    // call this after changing TargetOS/TargetCPU of the ActiveProject
    procedure PrepareBuildTarget(Quiet: boolean;
                     ScanFPCSrc: TScanModeFPCSources = smsfsBackground); virtual; abstract;
    procedure AbortBuild; virtual; abstract;

    // search results
    procedure DoShowSearchResultsView(State: TIWGetFormState = iwgfShowOnTop); virtual; abstract;

    // designer
    function GetDesignerForProjectEditor(AEditor: TSourceEditorInterface;
                              LoadForm: boolean): TIDesigner; virtual; abstract;
    function GetDesignerWithProjectFile(AFile: TLazProjectFile;
                              LoadForm: boolean): TIDesigner; virtual; abstract;
    function GetProjectFileWithRootComponent(AComponent: TComponent): TLazProjectFile; virtual; abstract;
    function GetProjectFileWithDesigner(ADesigner: TIDesigner): TLazProjectFile; virtual; abstract;

    procedure DoShowDesignerFormOfSrc(AEditor: TSourceEditorInterface); virtual; abstract; overload;
    procedure DoShowMethod(AEditor: TSourceEditorInterface; const AMethodName: String); virtual; abstract;
    procedure DoShowDesignerFormOfSrc(AEditor: TSourceEditorInterface; out AForm: TCustomForm); virtual; abstract; overload;

    // events
    procedure RemoveAllHandlersOfObject(AnObject: TObject);
    procedure AddHandlerOnSavingAll(const OnSaveAllEvent: TModalResultFunction;
                                    AsLast: boolean = false);
    procedure RemoveHandlerOnSavingAll(const OnSaveAllEvent: TModalResultFunction);
    procedure AddHandlerOnSavedAll(const OnSaveAllEvent: TModalResultFunction;
                                   AsLast: boolean = false);
    procedure RemoveHandlerOnSavedAll(const OnSaveAllEvent: TModalResultFunction);
    procedure AddHandlerOnSaveEditorFile(const OnSaveEditorFile: TSaveEditorFileEvent;
                                    AsLast: boolean = false);
    procedure RemoveHandlerOnSaveEditorFile(const OnSaveEditorFile: TSaveEditorFileEvent);
    procedure AddHandlerOnIDERestoreWindows(const OnIDERestoreWindowsEvent: TNotifyEvent;
                                   AsLast: boolean = false);
    procedure RemoveHandlerOnIDERestoreWindows(
                                  const OnIDERestoreWindowsEvent: TNotifyEvent);
    procedure AddHandlerOnIDEClose(const OnIDECloseEvent: TNotifyEvent;
                                   AsLast: boolean = false);
    procedure RemoveHandlerOnIDEClose(const OnIDECloseEvent: TNotifyEvent);
    procedure AddHandlerOnProjectOpening(
                         const OnProjectOpeningEvent: TLazProjectChangedFunction;
                         AsLast: boolean = false);
    procedure RemoveHandlerOnProjectOpening(
                        const OnProjectOpeningEvent: TLazProjectChangedFunction);
    procedure AddHandlerOnProjectOpened(
                         const OnProjectOpenedEvent: TLazProjectChangedFunction;
                         AsLast: boolean = false);
    procedure RemoveHandlerOnProjectOpened(
                        const OnProjectOpenedEvent: TLazProjectChangedFunction);
    procedure AddHandlerOnProjectClose(
                          const OnProjectCloseEvent: TLazProjectChangedFunction;
                          AsLast: boolean = false);
    procedure RemoveHandlerOnProjectClose(
                         const OnProjectCloseEvent: TLazProjectChangedFunction);
    procedure AddHandlerOnProjectBuilding(
                                const OnProjBuildingEvent: TModalResultFunction;
                                AsLast: boolean = false);
    procedure RemoveHandlerOnProjectBuilding(
                                const OnProjBuildingEvent: TModalResultFunction);
    procedure AddHandlerOnProjectBuildingFinished(
                           const OnProjBuildingFinishedEvent: TLazBuildingFinishedEvent;
                           AsLast: boolean = false);
    procedure RemoveHandlerOnProjectBuildingFinished(
                               const OnProjBuildingFinishedEvent: TLazBuildingFinishedEvent);
    procedure AddHandlerOnProjectDependenciesCompiling(
                   const OnProjDependenciesCompilingEvent: TModalResultFunction;
                   AsLast: boolean = false);
    procedure RemoveHandlerOnProjectDependenciesCompiling(
                  const OnProjDependenciesCompilingEvent: TModalResultFunction);
    procedure AddHandlerOnProjectDependenciesCompiled(
                    const OnProjDependenciesCompiledEvent: TModalResultFunction;
                    AsLast: boolean = false);
    procedure RemoveHandlerOnProjectDependenciesCompiled(
                   const OnProjDependenciesCompiledEvent: TModalResultFunction);
    procedure AddHandlerOnLazarusBuilding(
                                const OnLazBuildingEvent: TModalResultFunction;
                                AsLast: boolean = false);
    procedure RemoveHandlerOnLazarusBuilding(
                                const OnLazBuildingEvent: TModalResultFunction);
    procedure AddHandlerOnLazarusBuildingFinished(
                           const OnLazBuildingFinishedEvent: TLazBuildingFinishedEvent;
                           AsLast: boolean = false);
    procedure RemoveHandlerOnLazarusBuildingFinished(
                               const OnLazBuildingFinishedEvent: TLazBuildingFinishedEvent);
    procedure AddHandlerOnQuickSyntaxCheck(
                           const OnQuickSyntaxCheckEvent: TModalHandledFunction;
                           AsLast: boolean = false);
    procedure RemoveHandlerOnQuickSyntaxCheck(
                          const OnQuickSyntaxCheckEvent: TModalHandledFunction);
    procedure AddHandlerGetFPCFrontEndParams(
                 const Handler: TGetFPCFrontEndParams; AsLast: boolean = false);
    procedure RemoveHandlerGetFPCFrontEndParams(
                                          const Handler: TGetFPCFrontEndParams);
    function CallHandlerGetFPCFrontEndParams(Sender: TObject; var Params: string): boolean;
    procedure AddHandlerGetFPCFrontEndPath(
                 const Handler: TGetFPCFrontEndPath; AsLast: boolean = false);
    procedure RemoveHandlerGetFPCFrontEndPath(const Handler: TGetFPCFrontEndPath);
    function CallHandlerGetFPCFrontEndPath(Sender: TObject; var Path: string): boolean;
    procedure AddHandlerOnShowDesignerFormOfSource(
                           const OnShowDesignerFormOfSourceEvent: TShowDesignerFormOfSourceFunction;
                           AsLast: boolean = false);
    procedure RemoveHandlerOnShowDesignerFormOfSource(
                               const OnShowDesignerFormOfSourceEvent: TShowDesignerFormOfSourceFunction);
    procedure AddHandlerOnShowSourceOfActiveDesignerForm(
                           const OnShowSourceOfActiveDesignerForm: TNotifyEvent;
                           AsLast: boolean = false);
    procedure RemoveHandlerOnShowSourceOfActiveDesignerForm(
                               const OnShowSourceOfActiveDesignerForm: TNotifyEvent);
    procedure AddHandlerOnChangeToolStatus(
                           const OnChangeToolStatus: TLazToolStatusChangeEvent;
                           AsLast: boolean = false);
    procedure RemoveHandlerOnChangeToolStatus(
                               const OnChangeToolStatus: TLazToolStatusChangeEvent);
    procedure AddHandlerOnRunDebugInit(const Event: TModalHandledFunction;
                                   AsLast: boolean = false);
    procedure RemoveHandlerOnRunDebugInit(const Event: TModalHandledFunction);
    procedure AddHandlerOnRunDebug(const Event: TModalHandledFunction;
                                   AsLast: boolean = false);
    procedure RemoveHandlerOnRunDebug(const Event: TModalHandledFunction);
    procedure AddHandlerOnRunWithoutDebugBuilding(const Event: TModalHandledFunction;
                                      AsLast: boolean = false);
    procedure RemoveHandlerOnRunWithoutDebugBuilding(const Event: TModalHandledFunction);
    procedure AddHandlerOnRunWithoutDebugInit(const Event: TModalHandledFunction;
                                      AsLast: boolean = false);
    procedure RemoveHandlerOnRunWithoutDebugInit(const Event: TModalHandledFunction);
    procedure AddHandlerOnRunFinished(const OnRunFinishedEvent: TNotifyEvent;
                                      AsLast: boolean = false);
    procedure RemoveHandlerOnRunFinished(const OnRunFinishedEvent: TNotifyEvent);

    property IDEStarted: boolean read FIDEStarted;
    property IDEIsClosing: boolean read FIDEIsClosing;
    property LastActivatedWindows: TFPList read FLastActivatedWindows;
    property LastFormActivated: TCustomForm read FLastFormActivated write FLastFormActivated;
    property CheckFilesOnDiskEnabled: boolean read FCheckFilesOnDiskEnabled write FCheckFilesOnDiskEnabled;
  end;

  { TIDETabMaster }

  TIDETabMaster = class
  protected
    function GetTabDisplayState: TTabDisplayState; virtual; abstract;
    function GetTabDisplayStateEditor(Index: TSourceEditorInterface): TTabDisplayState; virtual; abstract;
  public
    function AutoSizeInShowDesigner(AControl: TControl): Boolean; virtual; abstract;
    function GetDesigner(ASourceEditor: TSourceEditorInterface; ATabDisplayState: TTabDisplayState): TIDesigner; virtual;
    procedure ToggleFormUnit; virtual; abstract;
    procedure JumpToCompilerMessage(ASourceEditor: TSourceEditorInterface); virtual; abstract;
    procedure ShowCode(ASourceEditor: TSourceEditorInterface); virtual; abstract;
    procedure ShowDesigner(ASourceEditor: TSourceEditorInterface; AIndex: Integer = 0); virtual; abstract;
    procedure ShowForm(AForm: TCustomForm); virtual; abstract;
  public
    property TabDisplayState: TTabDisplayState read GetTabDisplayState;
    property TabDisplayStateEditor[Index: TSourceEditorInterface]: TTabDisplayState read GetTabDisplayStateEditor;
  end;

var
  LazarusIDE: TLazIDEInterface = nil; // will be set by the IDE
  IDETabMaster: TIDETabMaster = nil;

type
  TLazarusIDEBootHandlerType = (
    libhTransferMacrosCreated,  // called after IDEMacros were created
    libhEnvironmentOptionsLoaded  // called after IDE loaded environment options
    );

procedure AddBootHandler(ht: TLazarusIDEBootHandlerType; const OnBoot: TProcedure);

implementation

type
  TArrayOfProc = array of TProcedure;
var
  BootHandlers: array[TLazarusIDEBootHandlerType] of TArrayOfProc;

procedure AddBootHandler(ht: TLazarusIDEBootHandlerType; const OnBoot: TProcedure);
var
  l: Integer;
begin
  l:=length(BootHandlers[ht]);
  SetLength(BootHandlers[ht],l+1);
  BootHandlers[ht][l]:=OnBoot;
end;

procedure RunBootHandlers(ht: TLazarusIDEBootHandlerType);Public name 'ideintf_LazIDEIntf_RunBootHandlers';
var
  i: Integer;
begin
  for i:=0 to length(BootHandlers[ht])-1 do
    BootHandlers[ht][i]();
end;

{ TIDETabMaster }

function TIDETabMaster.GetDesigner(ASourceEditor: TSourceEditorInterface;
  ATabDisplayState: TTabDisplayState): TIDesigner;
begin
  case ATabDisplayState of
    tdsDesign:
      Result := ASourceEditor.GetDesigner(True);
    else
      Result := nil;
  end;
end;

{ TLazIDEInterface }

procedure TLazIDEInterface.AddHandler(HandlerType: TLazarusIDEHandlerType;
  const AMethod: TMethod; AsLast: boolean);
begin
  if FLazarusIDEHandlers[HandlerType]=nil then
    FLazarusIDEHandlers[HandlerType]:=TMethodList.Create;
  FLazarusIDEHandlers[HandlerType].Add(AMethod,AsLast);
end;

procedure TLazIDEInterface.RemoveHandler(HandlerType: TLazarusIDEHandlerType;
  const AMethod: TMethod);
begin
  FLazarusIDEHandlers[HandlerType].Remove(AMethod);
end;

procedure TLazIDEInterface.SetMainBarSubTitle(const AValue: string);
begin
  if FMainBarSubTitle=AValue then exit;
  FMainBarSubTitle:=AValue;
end;

procedure TLazIDEInterface.SetToolStatus(const AToolStatus: TLazToolStatus);
var
  xMethod: TLazToolStatusChangeEvent;
  I: Integer;
  OldToolStatus: TLazToolStatus;
begin
  if FToolStatus=aToolStatus then Exit;

  OldToolStatus:=FToolStatus;
  FToolStatus:=AToolStatus;

  for I := 0 to FLazarusIDEHandlers[lihtChangeToolStatus].Count-1 do
  begin
    xMethod := TLazToolStatusChangeEvent(FLazarusIDEHandlers[lihtChangeToolStatus][I]);
    xMethod(Self, OldToolStatus, AToolStatus);
  end;
end;

procedure TLazIDEInterface.DoCallNotifyHandler(
  HandlerType: TLazarusIDEHandlerType);
begin
  FLazarusIDEHandlers[HandlerType].CallNotifyEvents(Self);
end;

function TLazIDEInterface.DoCallModalFunctionHandler(
  HandlerType: TLazarusIDEHandlerType): TModalResult;
var
  i: Integer;
  CurResult: TModalResult;
  Handler: TMethodList;
begin
  Result:=mrOk;
  Handler:=FLazarusIDEHandlers[HandlerType];
  i:=Handler.Count;
  while Handler.NextDownIndex(i) do begin
    CurResult:=TModalResultFunction(Handler[i])(Self);
    if CurResult=mrAbort then exit(mrAbort);
    if CurResult<>mrOk then Result:=mrCancel;
  end;
end;

function TLazIDEInterface.DoCallProjectChangedHandler(
  HandlerType: TLazarusIDEHandlerType; AProject: TLazProject): TModalResult;
var
  i: Integer;
  CurResult: TModalResult;
  Handler: TMethodList;
begin
  Result:=mrOk;
  LastActivatedWindows.Clear;               // IDE windows may change.
  Handler:=FLazarusIDEHandlers[HandlerType];
  i:=Handler.Count;
  while Handler.NextDownIndex(i) do begin
    CurResult:=TLazProjectChangedFunction(Handler[i])(Self,AProject);
    if CurResult=mrAbort then exit(mrAbort);
    if CurResult<>mrOk then Result:=mrCancel;
  end;
end;

function TLazIDEInterface.DoCallModalHandledHandler(
  HandlerType: TLazarusIDEHandlerType; var Handled: boolean): TModalResult;
var
  i: longint;
  Handler: TMethodList;
begin
  Handler:=FLazarusIDEHandlers[HandlerType];
  i:=Handler.Count;
  while Handler.NextDownIndex(i) do
  begin
    Handled:=false;
    Result:=TModalHandledFunction(Handler[i])(Self,Handled);
    if Handled then exit;
  end;
  Result:=mrOk;
end;

procedure TLazIDEInterface.DoCallNotifyHandler(HandlerType: TLazarusIDEHandlerType; Sender: TObject);
begin
  FLazarusIDEHandlers[HandlerType].CallNotifyEvents(Sender);
end;

procedure TLazIDEInterface.DoCallShowDesignerFormOfSourceHandler(Sender: TObject;
  AEditor: TSourceEditorInterface; AComponentPaletteClassSelected: Boolean);
var
  i: Integer;
  Handler: TMethodList;
begin
  Handler:=FLazarusIDEHandlers[lihtShowDesignerFormOfSource];
  i := Handler.Count;
  while Handler.NextDownIndex(i) do
    TShowDesignerFormOfSourceFunction(Handler[i])(Sender, AEditor,
                                                 AComponentPaletteClassSelected);
end;

procedure TLazIDEInterface.DoJumpToNextError(DirectionDown: boolean);
begin
  DoJumpToNextCompilerMessage(mluError, DirectionDown);
end;

constructor TLazIDEInterface.Create(TheOwner: TComponent);
begin
  LazarusIDE:=Self;
  FCheckFilesOnDiskEnabled:=True;
  inherited Create(TheOwner);
end;

destructor TLazIDEInterface.Destroy;
var
  HandlerType: TLazarusIDEHandlerType;
begin
  for HandlerType := Low(TLazarusIDEHandlerType) to High(TLazarusIDEHandlerType) do
    FreeAndNil(FLazarusIDEHandlers[HandlerType]);
  inherited Destroy;
  LazarusIDE:=nil;
end;

function TLazIDEInterface.DoNewEditorFile(
  NewFileDescriptor: TProjectFileDescriptor; NewFilename: string;
  const NewSource: string; NewFlags: TNewFlags): TModalResult;
begin
  Result:=DoNewFile(NewFileDescriptor,NewFilename,NewSource,NewFlags,nil);
end;

function TLazIDEInterface.DoOpenFileAndJumpToPos(const AFilename: string;
  const CursorPosition: TPoint; TopLine: integer; PageIndex,
  WindowIndex: integer; Flags: TOpenFlags): TModalResult;
begin
  Result := DoOpenFileAndJumpToPos(AFilename, CursorPosition, TopLine, TopLine, TopLine, PageIndex, WindowIndex, Flags);
end;

function TLazIDEInterface.DoOpenIDEOptions(AEditor: TAbstractIDEOptionsEditorClass;
  ACaption: String): Boolean;
begin
  Result := DoOpenIDEOptions(AEditor, ACaption, [], []);
end;

procedure TLazIDEInterface.DoCallBuildingFinishedHandler(
  HandlerType: TLazarusIDEHandlerType; Sender: TObject; BuildSuccessful: Boolean);
var
  I: Integer;
  xMethod: TLazBuildingFinishedEvent;
begin
  for I := 0 to FLazarusIDEHandlers[HandlerType].Count-1 do
  begin
    xMethod := TLazBuildingFinishedEvent(FLazarusIDEHandlers[HandlerType][I]);
    xMethod(Sender, BuildSuccessful);
  end;
end;

function TLazIDEInterface.DoCallRunDebugInit(var Handled: boolean
  ): TModalResult;
begin
  Result:=DoCallModalHandledHandler(lihtRunDebugInit,Handled);
end;

function TLazIDEInterface.DoCallRunDebug(var Handled: boolean): TModalResult;
begin
  Result:=DoCallModalHandledHandler(lihtRunDebug,Handled);
end;

function TLazIDEInterface.DoCallRunWithoutDebugBuilding(var Handled: boolean
  ): TModalResult;
begin
  Result:=DoCallModalHandledHandler(lihtRunWithoutDebugBuilding,Handled);
end;

function TLazIDEInterface.DoCallRunWithoutDebugInit(var Handled: boolean
  ): TModalResult;
begin
  Result:=DoCallModalHandledHandler(lihtRunWithoutDebugInit,Handled);
end;

procedure TLazIDEInterface.DoCallRunFinishedHandler;
begin
  DoCallNotifyHandler(lihtRunFinished);
end;

procedure TLazIDEInterface.RemoveAllHandlersOfObject(AnObject: TObject);
var
  HandlerType: TLazarusIDEHandlerType;
begin
  for HandlerType:=Low(HandlerType) to High(HandlerType) do
    FLazarusIDEHandlers[HandlerType].RemoveAllMethodsOfObject(AnObject);
end;

procedure TLazIDEInterface.AddHandlerOnSavingAll(
  const OnSaveAllEvent: TModalResultFunction; AsLast: boolean);
begin
  AddHandler(lihtSavingAll,TMethod(OnSaveAllEvent),AsLast);
end;

procedure TLazIDEInterface.RemoveHandlerOnSavingAll(
  const OnSaveAllEvent: TModalResultFunction);
begin
  RemoveHandler(lihtSavingAll,TMethod(OnSaveAllEvent));
end;

procedure TLazIDEInterface.AddHandlerOnSavedAll(
  const OnSaveAllEvent: TModalResultFunction; AsLast: boolean);
begin
  AddHandler(lihtSavedAll,TMethod(OnSaveAllEvent),AsLast);
end;

procedure TLazIDEInterface.RemoveHandlerOnSavedAll(
  const OnSaveAllEvent: TModalResultFunction);
begin
  RemoveHandler(lihtSavedAll,TMethod(OnSaveAllEvent));
end;

procedure TLazIDEInterface.AddHandlerOnSaveEditorFile(
  const OnSaveEditorFile: TSaveEditorFileEvent; AsLast: boolean);
begin
  AddHandler(lihtSaveEditorFile,TMethod(OnSaveEditorFile),AsLast);
end;

procedure TLazIDEInterface.RemoveHandlerOnSaveEditorFile(
  const OnSaveEditorFile: TSaveEditorFileEvent);
begin
  RemoveHandler(lihtSaveEditorFile,TMethod(OnSaveEditorFile));
end;

procedure TLazIDEInterface.AddHandlerOnIDERestoreWindows(
  const OnIDERestoreWindowsEvent: TNotifyEvent; AsLast: boolean);
begin
  AddHandler(lihtIDERestoreWindows,TMethod(OnIDERestoreWindowsEvent),AsLast);
end;

procedure TLazIDEInterface.AddHandlerOnLazarusBuilding(
  const OnLazBuildingEvent: TModalResultFunction; AsLast: boolean);
begin
  AddHandler(lihtLazarusBuilding,TMethod(OnLazBuildingEvent), AsLast);
end;

procedure TLazIDEInterface.AddHandlerOnLazarusBuildingFinished(
  const OnLazBuildingFinishedEvent: TLazBuildingFinishedEvent; AsLast: boolean);
begin
  AddHandler(lihtLazarusBuildingFinished,TMethod(OnLazBuildingFinishedEvent), AsLast);
end;

procedure TLazIDEInterface.RemoveHandlerOnIDERestoreWindows(
  const OnIDERestoreWindowsEvent: TNotifyEvent);
begin
  RemoveHandler(lihtIDERestoreWindows,TMethod(OnIDERestoreWindowsEvent));
end;

procedure TLazIDEInterface.RemoveHandlerOnLazarusBuilding(
  const OnLazBuildingEvent: TModalResultFunction);
begin
  RemoveHandler(lihtLazarusBuilding,TMethod(OnLazBuildingEvent));
end;

procedure TLazIDEInterface.RemoveHandlerOnLazarusBuildingFinished(
  const OnLazBuildingFinishedEvent: TLazBuildingFinishedEvent);
begin
  RemoveHandler(lihtLazarusBuildingFinished,TMethod(OnLazBuildingFinishedEvent));
end;

procedure TLazIDEInterface.AddHandlerOnIDEClose(
  const OnIDECloseEvent: TNotifyEvent; AsLast: boolean);
begin
  AddHandler(lihtIDEClose,TMethod(OnIDECloseEvent),AsLast);
end;

procedure TLazIDEInterface.RemoveHandlerOnIDEClose(
  const OnIDECloseEvent: TNotifyEvent);
begin
  RemoveHandler(lihtIDEClose,TMethod(OnIDECloseEvent));
end;

procedure TLazIDEInterface.AddHandlerOnProjectOpening(
  const OnProjectOpeningEvent: TLazProjectChangedFunction; AsLast: boolean);
begin
  AddHandler(lihtProjectOpening,TMethod(OnProjectOpeningEvent),AsLast);
end;

procedure TLazIDEInterface.RemoveHandlerOnProjectOpening(
  const OnProjectOpeningEvent: TLazProjectChangedFunction);
begin
  RemoveHandler(lihtProjectOpening,TMethod(OnProjectOpeningEvent));
end;

procedure TLazIDEInterface.AddHandlerOnProjectOpened(
  const OnProjectOpenedEvent: TLazProjectChangedFunction; AsLast: boolean);
begin
  AddHandler(lihtProjectOpened,TMethod(OnProjectOpenedEvent),AsLast);
end;

procedure TLazIDEInterface.RemoveHandlerOnProjectOpened(
  const OnProjectOpenedEvent: TLazProjectChangedFunction);
begin
  RemoveHandler(lihtProjectOpened,TMethod(OnProjectOpenedEvent));
end;

procedure TLazIDEInterface.AddHandlerOnProjectClose(
  const OnProjectCloseEvent: TLazProjectChangedFunction; AsLast: boolean);
begin
  AddHandler(lihtProjectClose,TMethod(OnProjectCloseEvent),AsLast);
end;

procedure TLazIDEInterface.RemoveHandlerOnProjectClose(
  const OnProjectCloseEvent: TLazProjectChangedFunction);
begin
  RemoveHandler(lihtProjectClose,TMethod(OnProjectCloseEvent));
end;

procedure TLazIDEInterface.AddHandlerOnProjectBuilding(
  const OnProjBuildingEvent: TModalResultFunction; AsLast: boolean);
begin
  AddHandler(lihtProjectBuilding,TMethod(OnProjBuildingEvent),AsLast);
end;

procedure TLazIDEInterface.RemoveHandlerOnProjectBuilding(
  const OnProjBuildingEvent: TModalResultFunction);
begin
  RemoveHandler(lihtProjectBuilding,TMethod(OnProjBuildingEvent));
end;

procedure TLazIDEInterface.AddHandlerOnProjectDependenciesCompiling(
  const OnProjDependenciesCompilingEvent: TModalResultFunction; AsLast: boolean);
begin
  AddHandler(lihtProjectDependenciesCompiling,
             TMethod(OnProjDependenciesCompilingEvent),AsLast);
end;

procedure TLazIDEInterface.RemoveHandlerOnProjectDependenciesCompiling(
  const OnProjDependenciesCompilingEvent: TModalResultFunction);
begin
  RemoveHandler(lihtProjectDependenciesCompiling,
                TMethod(OnProjDependenciesCompilingEvent));
end;

procedure TLazIDEInterface.AddHandlerOnProjectDependenciesCompiled(
  const OnProjDependenciesCompiledEvent: TModalResultFunction; AsLast: boolean);
begin
  AddHandler(lihtProjectDependenciesCompiled,
             TMethod(OnProjDependenciesCompiledEvent),AsLast);
end;

procedure TLazIDEInterface.RemoveHandlerOnProjectDependenciesCompiled(
  const OnProjDependenciesCompiledEvent: TModalResultFunction);
begin
  RemoveHandler(lihtProjectDependenciesCompiled,
                TMethod(OnProjDependenciesCompiledEvent));
end;

procedure TLazIDEInterface.AddHandlerOnQuickSyntaxCheck(
  const OnQuickSyntaxCheckEvent: TModalHandledFunction; AsLast: boolean);
begin
  AddHandler(lihtQuickSyntaxCheck,TMethod(OnQuickSyntaxCheckEvent),AsLast);
end;

procedure TLazIDEInterface.RemoveHandlerOnQuickSyntaxCheck(
  const OnQuickSyntaxCheckEvent: TModalHandledFunction);
begin
  RemoveHandler(lihtQuickSyntaxCheck,TMethod(OnQuickSyntaxCheckEvent));
end;

procedure TLazIDEInterface.AddHandlerGetFPCFrontEndParams(
  const Handler: TGetFPCFrontEndParams; AsLast: boolean);
begin
  AddHandler(lihtGetFPCFrontEndParams,TMethod(Handler),AsLast);
end;

procedure TLazIDEInterface.RemoveHandlerGetFPCFrontEndParams(
  const Handler: TGetFPCFrontEndParams);
begin
  RemoveHandler(lihtGetFPCFrontEndParams,TMethod(Handler));
end;

function TLazIDEInterface.CallHandlerGetFPCFrontEndParams(Sender: TObject;
  var Params: string): boolean;
var
  i: longint;
begin
  i:=FLazarusIDEHandlers[lihtGetFPCFrontEndParams].Count;
  while FLazarusIDEHandlers[lihtGetFPCFrontEndParams].NextDownIndex(i) do
  begin
    if not TGetFPCFrontEndParams(FLazarusIDEHandlers[lihtGetFPCFrontEndParams][i])(Self,Params)
    then exit(false);
  end;
  Result:=true;
end;

procedure TLazIDEInterface.AddHandlerGetFPCFrontEndPath(
  const Handler: TGetFPCFrontEndPath; AsLast: boolean);
begin
  AddHandler(lihtGetFPCFrontEndPath,TMethod(Handler),AsLast);
end;

procedure TLazIDEInterface.AddHandlerOnProjectBuildingFinished(
  const OnProjBuildingFinishedEvent: TLazBuildingFinishedEvent; AsLast: boolean);
begin
  AddHandler(lihtProjectBuildingFinished,TMethod(OnProjBuildingFinishedEvent),AsLast);
end;

procedure TLazIDEInterface.AddHandlerOnChangeToolStatus(
  const OnChangeToolStatus: TLazToolStatusChangeEvent; AsLast: boolean);
begin
  AddHandler(lihtChangeToolStatus,TMethod(OnChangeToolStatus),AsLast);
end;

procedure TLazIDEInterface.RemoveHandlerGetFPCFrontEndPath(
  const Handler: TGetFPCFrontEndPath);
begin
  RemoveHandler(lihtGetFPCFrontEndPath,TMethod(Handler));
end;

procedure TLazIDEInterface.RemoveHandlerOnProjectBuildingFinished(
  const OnProjBuildingFinishedEvent: TLazBuildingFinishedEvent);
begin
  RemoveHandler(lihtProjectBuildingFinished,TMethod(OnProjBuildingFinishedEvent));
end;

procedure TLazIDEInterface.RemoveHandlerOnChangeToolStatus(
  const OnChangeToolStatus: TLazToolStatusChangeEvent);
begin
  RemoveHandler(lihtChangeToolStatus,TMethod(OnChangeToolStatus));
end;

procedure TLazIDEInterface.AddHandlerOnRunDebugInit(
  const Event: TModalHandledFunction; AsLast: boolean);
begin
  AddHandler(lihtRunDebugInit,TMethod(Event),AsLast);
end;

procedure TLazIDEInterface.RemoveHandlerOnRunDebugInit(
  const Event: TModalHandledFunction);
begin
  RemoveHandler(lihtRunDebugInit,TMethod(Event));
end;

procedure TLazIDEInterface.AddHandlerOnRunDebug(
  const Event: TModalHandledFunction; AsLast: boolean);
begin
  AddHandler(lihtRunDebug,TMethod(Event),AsLast);
end;

procedure TLazIDEInterface.RemoveHandlerOnRunDebug(
  const Event: TModalHandledFunction);
begin
  RemoveHandler(lihtRunDebug,TMethod(Event));
end;

procedure TLazIDEInterface.AddHandlerOnRunWithoutDebugBuilding(
  const Event: TModalHandledFunction; AsLast: boolean);
begin
  AddHandler(lihtRunWithoutDebugBuilding,TMethod(Event),AsLast);
end;

procedure TLazIDEInterface.RemoveHandlerOnRunWithoutDebugBuilding(
  const Event: TModalHandledFunction);
begin
  RemoveHandler(lihtRunWithoutDebugBuilding,TMethod(Event));
end;

procedure TLazIDEInterface.AddHandlerOnRunWithoutDebugInit(
  const Event: TModalHandledFunction; AsLast: boolean);
begin
  AddHandler(lihtRunWithoutDebugInit,TMethod(Event),AsLast);
end;

procedure TLazIDEInterface.RemoveHandlerOnRunWithoutDebugInit(
  const Event: TModalHandledFunction);
begin
  RemoveHandler(lihtRunWithoutDebugInit,TMethod(Event));
end;

procedure TLazIDEInterface.AddHandlerOnRunFinished(
  const OnRunFinishedEvent: TNotifyEvent; AsLast: boolean);
begin
  AddHandler(lihtRunFinished,TMethod(OnRunFinishedEvent),AsLast);
end;

procedure TLazIDEInterface.RemoveHandlerOnRunFinished(
  const OnRunFinishedEvent: TNotifyEvent);
begin
  RemoveHandler(lihtRunFinished,TMethod(OnRunFinishedEvent));
end;

function TLazIDEInterface.CallHandlerGetFPCFrontEndPath(Sender: TObject;
  var Path: string): boolean;
var
  i: longint;
begin
  i:=FLazarusIDEHandlers[lihtGetFPCFrontEndPath].Count;
  while FLazarusIDEHandlers[lihtGetFPCFrontEndPath].NextDownIndex(i) do
  begin
    if not TGetFPCFrontEndPath(FLazarusIDEHandlers[lihtGetFPCFrontEndPath][i])(Self,Path)
    then exit(false);
  end;
  Result:=true;
end;

procedure TLazIDEInterface.AddHandlerOnShowDesignerFormOfSource(
  const OnShowDesignerFormOfSourceEvent: TShowDesignerFormOfSourceFunction; AsLast: boolean);
begin
  AddHandler(lihtShowDesignerFormOfSource,TMethod(OnShowDesignerFormOfSourceEvent),AsLast);
end;

procedure TLazIDEInterface.RemoveHandlerOnShowDesignerFormOfSource(
  const OnShowDesignerFormOfSourceEvent: TShowDesignerFormOfSourceFunction);
begin
  RemoveHandler(lihtShowDesignerFormOfSource,TMethod(OnShowDesignerFormOfSourceEvent));
end;

procedure TLazIDEInterface.AddHandlerOnShowSourceOfActiveDesignerForm(
  const OnShowSourceOfActiveDesignerForm: TNotifyEvent; AsLast: boolean);
begin
  AddHandler(lihtShowSourceOfActiveDesignerForm,TMethod(OnShowSourceOfActiveDesignerForm),AsLast);
end;

procedure TLazIDEInterface.RemoveHandlerOnShowSourceOfActiveDesignerForm(
  const OnShowSourceOfActiveDesignerForm: TNotifyEvent);
begin
  RemoveHandler(lihtShowSourceOfActiveDesignerForm,TMethod(OnShowSourceOfActiveDesignerForm));
end;

end.

